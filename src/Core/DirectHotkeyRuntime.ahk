class DirectHotkeyRuntime {
    static OutputCleanupRetryDelayMs := 50
    static MaximumOutputCleanupRetries := 3
    static OutputKeyDelayMs := 10
    static OutputPressDurationMs := 10

    __New(app) {
        this.App := app
        this.ConditionEvaluator := RuleConditionEvaluator()
        this.Rules := Map()
        this.Registrations := []
        this.SourceGroups := Map()
        this.ReleaseGroups := Map()
        this.Active := Map()
        this.OutputOwners := Map()
        this.OutputCleanupTimer := ObjBindMethod(this, "RetryOutputCleanup")
        this.OutputCleanupScheduled := false
        this.OutputCleanupRetryCount := 0
        this.Suspended := false
    }

    ApplyMappings(mappings) {
        if Type(mappings) != "Array"
            throw TypeError("Rules must be an array.")
        rules := Map()
        registrations := []
        issues := []
        sourceGroups := Map()
        releaseGroups := Map()
        for order, mapping in mappings {
            descriptor := mapping.HasOwnProp("Descriptor")
                ? mapping.Descriptor : RuleCompiler.Compile(mapping.Spec)
            descriptor.Order := order
            if !descriptor.Enabled
                continue
            if rules.Has(descriptor.Id) {
                issues.Push({RuleId: descriptor.Id, Severity: "error",
                    Code: "duplicate-id", Message:
                        "The rule name is already in use."})
                continue
            }
            try registration := this.BuildRegistration(descriptor)
            catch as ruleError {
                issues.Push({RuleId: descriptor.Id, Severity: "error",
                    Code: "unsupported-rule", Message: ruleError.Message})
                continue
            }
            sourceGroup := ""
            if registration.DownHotkey != "" {
                sourceKey := this.GetHotkeyVariantSignature(
                    registration.DownHotkey)
                if !sourceGroups.Has(sourceKey) {
                    sourceGroups[sourceKey] := {Key: sourceKey,
                        Hotkey: registration.DownHotkey, RuleIds: [],
                        TracksRelease: registration.UpHotkey != "",
                        Held: false, Pending: "", RepeatIgnoreRules: Map(),
                        ReleaseGroup: ""}
                }
                sourceGroup := sourceGroups[sourceKey]
                if registration.UpHotkey != ""
                    sourceGroup.TracksRelease := true
            }
            releaseSignature := registration.UpHotkey == "" ? ""
                : this.GetReleaseVariantSignature(registration.UpHotkey)
            rules[descriptor.Id] := descriptor
            if IsObject(sourceGroup)
                sourceGroup.RuleIds.Push(descriptor.Id)
            if registration.UpHotkey != "" {
                if !releaseGroups.Has(releaseSignature)
                    releaseGroups[releaseSignature] := {Hotkey:
                        registration.UpHotkey, RuleIds: [], SourceGroups: Map(),
                        Pending: "", Held: false, OwnerSourceGroup: "",
                        SuppressUntilRelease: false}
                releaseGroup := releaseGroups[releaseSignature]
                if this.HasWildcard(registration.UpHotkey)
                        && !this.HasWildcard(releaseGroup.Hotkey)
                    releaseGroup.Hotkey := registration.UpHotkey
                releaseGroup.RuleIds.Push(descriptor.Id)
                if IsObject(sourceGroup) {
                    releaseGroup.SourceGroups[sourceGroup.Key] := sourceGroup
                    sourceGroup.ReleaseGroup := releaseGroup
                }
            }
        }
        if issues.Length
            throw Error(this.FormatIssues(issues))
        for sourceKey, sourceGroup in sourceGroups {
            this.SortRuleIds(sourceGroup.RuleIds, rules)
            registrations.Push({Descriptor: "", DownGroup: sourceGroup,
                DownHotkey: sourceGroup.Hotkey, UpHotkey: "",
                DownCallback: ObjBindMethod(this, "OnDownGroup",
                    sourceGroup), UpCallback: "",
                DownCriterion: ObjBindMethod(this,
                    "ShouldInterceptDownGroup", sourceGroup),
                UpCriterion: ""})
        }
        for releaseSignature, group in releaseGroups {
            this.SortRuleIds(group.RuleIds, rules)
            if this.NeedsCycleBlocker(group) {
                registrations.Push({Descriptor: "", DownGroup: "",
                    DownHotkey: this.BuildCycleBlockerHotkey(group),
                    UpHotkey: "", DownCallback: ObjBindMethod(this,
                        "OnBlockedCycleRepeat", group), UpCallback: "",
                    DownCriterion: ObjBindMethod(this,
                        "ShouldInterceptBlockedCycleRepeat", group),
                    UpCriterion: "", CycleBlocker: true})
            }
            registrations.Push({Descriptor: "", DownHotkey: "",
                UpHotkey: group.Hotkey, DownCallback: "",
                UpCallback: ObjBindMethod(this, "OnReleased", group),
                DownCriterion: "", UpCriterion: ObjBindMethod(this,
                    "ShouldInterceptReleased", group)})
        }
        previousRules := this.Rules
        previousRegistrations := this.Registrations
        previousSourceGroups := this.SourceGroups
        previousReleaseGroups := this.ReleaseGroups
        keepSuspended := this.Suspended
        this.DisableAll()
        this.Rules := rules
        this.Registrations := registrations
        this.SourceGroups := sourceGroups
        this.ReleaseGroups := releaseGroups
        this.ArmPhysicallyHeldSources()
        try {
            if !keepSuspended {
                for registration in registrations
                    this.EnableRegistration(registration)
            }
        } catch as applyError {
            this.DisableAll()
            this.Rules := previousRules
            this.Registrations := previousRegistrations
            this.SourceGroups := previousSourceGroups
            this.ReleaseGroups := previousReleaseGroups
            this.ArmPhysicallyHeldSources()
            try {
                if !keepSuspended {
                    for registration in previousRegistrations
                        this.EnableRegistration(registration)
                }
            } catch as restoreError {
                throw Error("Could not register remapping hotkeys: "
                    . applyError.Message "; previous rules also could not be restored: "
                    . restoreError.Message)
            }
            throw Error("Could not register remapping hotkeys: "
                . applyError.Message)
        }
        this.Trace("rules_applied", {Outcome: "ok", Data: Map(
            "rules", rules.Count, "registrations", registrations.Length,
            "issues", issues.Length)})
        return {Applied: rules.Count, Registrations: registrations.Length,
            Issues: issues, Capabilities: this.GetCapabilities()}
    }

    BuildRegistration(descriptor) {
        from := descriptor.Spec["from"]
        this.ValidateDescriptor(descriptor)
        if from.Get("tap_count", 1) > 1
            throw Error("Multi-tap rules are not supported by the direct AHK runtime.")
        preserveOriginal := this.PreservesOriginalInput(descriptor)
        immediatePassthrough := preserveOriginal
            && !this.DefersOriginalInput(descriptor)
        hotkeyName := this.BuildHotkeyName(from, immediatePassthrough)
        if hotkeyName == ""
            throw Error("The rule has no usable source hotkey.")
        if from.Get("event", "down") == "up"
            return {Descriptor: descriptor, DownHotkey: "",
                UpHotkey: hotkeyName " Up", DownCallback: "",
                UpCallback: ObjBindMethod(this, "OnUpOnly", descriptor.Id),
                DownCriterion: "", UpCriterion: ObjBindMethod(this,
                    "ShouldInterceptUpOnly", descriptor.Id)}
        needsRelease := this.IsReleasable(descriptor)
        return {Descriptor: descriptor, DownHotkey: hotkeyName,
            UpHotkey: needsRelease
                ? this.BuildReleaseHotkeyName(from, immediatePassthrough) : "",
            DownCallback: ObjBindMethod(this, "OnDown", descriptor.Id),
            UpCallback: needsRelease
                ? ObjBindMethod(this, "OnUp", descriptor.Id) : "",
            DownCriterion: ObjBindMethod(this, "ShouldInterceptDown",
                descriptor.Id), UpCriterion: ""}
    }

    BuildHotkeyName(from, preserveOriginal := false) {
        hotkeyName := Trim(String(from.Get("hotkey", "")))
        if hotkeyName == "" && from.Get("simultaneous", []).Length
            hotkeyName := this.BuildModifierChordHotkey(from["simultaneous"])
        if hotkeyName == ""
            hotkeyName := RuleCompiler.BuildHotkeyName(from)
        allowExtraModifiers := from.Get("optional_modifiers", []).Length > 0
        hotkeyName := RegExReplace(hotkeyName, "i)\s+Up$")
        if RegExMatch(hotkeyName, "^[~*$]*\*")
            allowExtraModifiers := true
        hotkeyName := RegExReplace(hotkeyName, "^[~*$]+")
        return hotkeyName == "" ? "" : "$" (preserveOriginal ? "~" : "")
            . (allowExtraModifiers ? "*" : "") hotkeyName
    }

    BuildReleaseHotkeyName(from, preserveOriginal := false) {
        key := this.GetPrimarySourceKey(from)
        return "$" (preserveOriginal ? "~" : "") "*"
            . RuleCompiler.BuildKeyHotkey(key) " Up"
    }

    PreservesOriginalInput(descriptor) {
        return descriptor.Spec.Get("passthrough", JsonBoolean(false)).Value
    }

    DefersOriginalInput(descriptor) {
        return this.PreservesOriginalInput(descriptor)
            && descriptor.Spec.Get("from", Map()).Get("event", "down") == "down"
            && this.GetActions(descriptor, "to_if_held_down").Length > 0
    }

    BuildModifierChordHotkey(keys) {
        return RuleCompiler.BuildSimultaneousHotkey(keys)
    }

    EnableRegistration(registration) {
        this.SetRegistrationHotkeyState(registration.DownHotkey,
            registration.DownCallback, registration.DownCriterion, true)
        this.SetRegistrationHotkeyState(registration.UpHotkey,
            registration.UpCallback, registration.UpCriterion, true)
        return true
    }

    DisableRegistration(registration) {
        this.SetRegistrationHotkeyState(registration.DownHotkey, "",
            registration.DownCriterion, false)
        this.SetRegistrationHotkeyState(registration.UpHotkey, "",
            registration.UpCriterion, false)
        return true
    }

    SetRegistrationHotkeyState(hotkeyName, callback, criterion, enabled) {
        if hotkeyName == ""
            return false
        try {
            if IsObject(criterion)
                HotIf(criterion)
            else
                HotIf()
            if enabled
                Hotkey(hotkeyName, callback, "On")
            else
                Hotkey(hotkeyName, "Off")
        } finally HotIf()
        return true
    }

    DisableAll() {
        for registration in this.Registrations
            try this.DisableRegistration(registration)
        this.CancelAllActive()
        this.ResetSourceCycleState()
        this.Registrations := []
        this.SourceGroups := Map()
        this.ReleaseGroups := Map()
        this.Rules := Map()
        return true
    }

    ResetSourceCycleState() {
        for sourceKey, sourceGroup in this.SourceGroups {
            sourceGroup.Held := false
            sourceGroup.Pending := ""
            sourceGroup.RepeatIgnoreRules.Clear()
        }
        for releaseKey, releaseGroup in this.ReleaseGroups {
            releaseGroup.Held := false
            releaseGroup.OwnerSourceGroup := ""
            releaseGroup.Pending := ""
            releaseGroup.SuppressUntilRelease := false
        }
        return true
    }

    ArmPhysicallyHeldSources() {
        armed := 0
        for releaseKey, releaseGroup in this.ReleaseGroups {
            model := this.ParseHotkeyMatchModel(releaseGroup.Hotkey)
            if !this.IsPhysicalSourceDown(model.Primary)
                continue
            if !releaseGroup.SuppressUntilRelease
                armed++
            releaseGroup.Held := true
            releaseGroup.OwnerSourceGroup := ""
            releaseGroup.SuppressUntilRelease := true
        }
        return armed
    }

    IsPhysicalSourceDown(primary) {
        try return GetKeyState(String(primary), "P")
        catch
            return false
    }

    OnDown(ruleId, *) {
        if this.Suspended || !this.Rules.Has(ruleId)
            return false
        return this.HandleDown(ruleId, this.Active.Has(ruleId), false)
    }

    OnDownGroup(sourceGroup, *) {
        pending := sourceGroup.Pending
        sourceGroup.Pending := ""
        if this.Suspended || !IsObject(pending)
            return false
        if pending.HasOwnProp("BlockedCycle") && pending.BlockedCycle {
            outcome := pending.HasOwnProp("BlockReason")
                ? pending.BlockReason : "modifier_change"
            this.Trace("cycle_repeat_suppressed", {Outcome: outcome,
                Detail: sourceGroup.Hotkey})
            return true
        }
        if !pending.IsRepeat {
            sourceGroup.RepeatIgnoreRules.Clear()
            for ruleId in pending.RuleIds {
                if this.Rules.Has(ruleId)
                        && this.Rules[ruleId].Spec["from"].Get("repeat",
                            "allow") == "ignore"
                    sourceGroup.RepeatIgnoreRules[ruleId] := true
            }
        }
        sourceGroup.Held := sourceGroup.TracksRelease
        if sourceGroup.TracksRelease && IsObject(sourceGroup.ReleaseGroup)
                && !sourceGroup.ReleaseGroup.Held {
            sourceGroup.ReleaseGroup.Held := true
            sourceGroup.ReleaseGroup.OwnerSourceGroup := sourceGroup
        }
        handled := pending.ArmOnly
        for ruleId in pending.RuleIds
            handled := this.HandleDown(ruleId, pending.IsRepeat, true)
                || handled
        return handled
    }

    HandleDown(ruleId, isRepeat, eligibilityConfirmed := false) {
        if this.Suspended || !this.Rules.Has(ruleId)
            return false
        descriptor := this.Rules[ruleId]
        repeatPolicy := descriptor.Spec["from"].Get("repeat", "allow")
        if isRepeat && repeatPolicy == "ignore"
            return false
        if !eligibilityConfirmed && !this.IsEligible(descriptor)
            return false
        if eligibilityConfirmed
            this.TraceRuleMatched(descriptor)
        needsRelease := this.IsReleasable(descriptor)
            && (this.NeedsRelease(descriptor) || repeatPolicy != "allow")
        if !isRepeat && repeatPolicy == "only" {
            return false
        }
        if needsRelease && !this.Active.Has(ruleId) {
            state := this.CreateActiveState(descriptor)
            this.Active[ruleId] := state
            try {
                this.ExecuteActions(this.GetActions(descriptor, "to"),
                    descriptor, "to", isRepeat, state, true)
                if !this.IsCurrentActiveState(ruleId, state)
                    return true
                if this.GetActions(descriptor, "to_if_held_down").Length {
                    threshold := this.GetTiming(
                        descriptor)["held_threshold_ms"]
                    elapsed := Max(0, this.GetMonotonicTick()
                        - state.PressedAt)
                    if elapsed >= threshold {
                        this.OnHeld(ruleId)
                    } else {
                        timer := ObjBindMethod(this, "OnHeld", ruleId)
                        state.HeldTimer := timer
                        SetTimer(timer, -(threshold - elapsed))
                    }
                }
            } catch as actionError {
                this.CancelActiveRule(ruleId, state)
                this.TraceActionFailure(ruleId, "to", actionError)
                return false
            }
        } else {
            state := this.Active.Has(ruleId) ? this.Active[ruleId] : ""
            try this.ExecuteActions(this.GetActions(descriptor, "to"),
                descriptor, "to", isRepeat, state, IsObject(state))
            catch as actionError {
                this.TraceActionFailure(ruleId, "to", actionError)
                return false
            }
        }
        return true
    }

    OnUpOnly(ruleId, *) {
        if this.Suspended || !this.Rules.Has(ruleId)
            return false
        return this.HandleUpOnly(ruleId, false)
    }

    HandleUpOnly(ruleId, eligibilityConfirmed := false) {
        if this.Suspended || !this.Rules.Has(ruleId)
            return false
        descriptor := this.Rules[ruleId]
        if !eligibilityConfirmed && !this.IsEligible(descriptor)
            return false
        if eligibilityConfirmed
            this.TraceRuleMatched(descriptor, "up")
        try {
            this.ExecuteActions(this.GetActions(descriptor, "to"), descriptor,
                "to")
            this.ExecuteActions(this.GetActions(descriptor, "to_after_key_up"),
                descriptor, "to_after_key_up")
            return true
        } catch as actionError {
            this.TraceActionFailure(ruleId, "up", actionError)
            return false
        }
    }

    OnUp(ruleId, *) {
        if !this.Active.Has(ruleId)
            return false
        state := this.Active[ruleId]
        descriptor := state.Descriptor
        failurePhase := "up"
        this.StopStateTimers(state)
        state.HeldTimer := ""
        if !state.HeldFired
                && this.GetActions(descriptor, "to_if_held_down").Length
                && this.GetMonotonicTick() - state.PressedAt
                    >= this.GetTiming(descriptor)["held_threshold_ms"]
            this.OnHeld(ruleId)
        if !this.IsCurrentActiveState(ruleId, state)
            return false
        try {
            if !this.IsCurrentActiveState(ruleId, state)
                return false
            this.Active.Delete(ruleId)
            if !state.HeldFired {
                if !state.AloneCancelled
                    this.ExecuteActions(this.GetActions(descriptor,
                        "to_if_alone"), descriptor, "to_if_alone", false,
                        state)
                if this.DefersOriginalInput(descriptor)
                    this.SendOriginalInput(descriptor, state)
            }
            this.ExecuteActions(this.GetActions(descriptor, "to_after_key_up"),
                descriptor, "to_after_key_up", false, state)
        } catch as actionError {
            this.TraceActionFailure(ruleId, failurePhase, actionError)
        } finally {
            this.CancelActiveRule(ruleId, state)
        }
        this.Trace("rule_released", {RuleId: ruleId, Outcome: "up"})
        return true
    }

    OnReleased(releaseGroup, *) {
        pending := releaseGroup.Pending
        releaseGroup.Pending := ""
        selectedUpRules := Map()
        if IsObject(pending) {
            for ruleId in pending.RuleIds
                selectedUpRules[ruleId] := true
        }
        for sourceKey, sourceGroup in releaseGroup.SourceGroups {
            sourceGroup.Held := false
            sourceGroup.Pending := ""
            sourceGroup.RepeatIgnoreRules.Clear()
        }
        releaseGroup.Held := false
        releaseGroup.OwnerSourceGroup := ""
        releaseGroup.SuppressUntilRelease := false
        for ruleId in releaseGroup.RuleIds {
            if !this.Rules.Has(ruleId)
                continue
            descriptor := this.Rules[ruleId]
            if descriptor.Spec["from"].Get("event", "down") == "up" {
                if selectedUpRules.Has(ruleId)
                    this.HandleUpOnly(ruleId, true)
            }
            else
                this.OnUp(ruleId)
        }
        return true
    }

    NeedsCycleBlocker(releaseGroup) {
        for sourceKey, sourceGroup in releaseGroup.SourceGroups {
            if this.HasWildcard(sourceGroup.Hotkey)
                return false
            model := this.ParseHotkeyMatchModel(sourceGroup.Hotkey)
            if this.GetPrimaryModifierFamily(model.Primary) != ""
                return false
        }
        return releaseGroup.SourceGroups.Count > 0
    }

    BuildCycleBlockerHotkey(releaseGroup) {
        return RegExReplace(String(releaseGroup.Hotkey), "i)\s+Up$")
    }

    ShouldInterceptBlockedCycleRepeat(releaseGroup, *) {
        if this.Suspended || !releaseGroup.Held
            return false
        modifierState := this.GetPhysicalModifierState()
        for sourceKey, sourceGroup in releaseGroup.SourceGroups {
            model := this.ParseHotkeyMatchModel(sourceGroup.Hotkey)
            if this.MatchesModifierState(model, modifierState)
                return false
        }
        return true
    }

    OnBlockedCycleRepeat(releaseGroup, *) {
        if !this.ShouldInterceptBlockedCycleRepeat(releaseGroup)
            return false
        outcome := releaseGroup.SuppressUntilRelease
            ? "held_during_reconfigure" : "modifier_change"
        this.Trace("cycle_repeat_suppressed", {Outcome: outcome,
            Detail: releaseGroup.Hotkey})
        return true
    }

    ShouldInterceptDown(ruleId, *) {
        if this.Suspended || !this.Rules.Has(ruleId)
            return false
        if this.Active.Has(ruleId)
            return true
        return this.MatchesCurrentContext(this.Rules[ruleId])
    }

    ShouldInterceptDownGroup(sourceGroup, *) {
        if this.Suspended
            return false
        releaseGroup := sourceGroup.ReleaseGroup
        if IsObject(releaseGroup) && releaseGroup.SuppressUntilRelease {
            sourceGroup.Pending := {RuleIds: [], IsRepeat: true,
                ArmOnly: true, BlockedCycle: true,
                BlockReason: "held_during_reconfigure"}
            return true
        }
        if IsObject(releaseGroup) && releaseGroup.Held
                && IsObject(releaseGroup.OwnerSourceGroup)
                && releaseGroup.OwnerSourceGroup != sourceGroup {
            sourceGroup.Pending := {RuleIds: [], IsRepeat: true,
                ArmOnly: true, BlockedCycle: true}
            return true
        }
        isRepeat := sourceGroup.Held
        selection := this.FindEligibleRules(sourceGroup.RuleIds, isRepeat,
            sourceGroup.RepeatIgnoreRules)
        if !selection.RuleIds.Length && !selection.ArmOnly {
            sourceGroup.Pending := ""
            return false
        }
        sourceGroup.Pending := {RuleIds: selection.RuleIds,
            IsRepeat: isRepeat, ArmOnly: selection.ArmOnly}
        return true
    }

    ShouldInterceptReleased(releaseGroup, *) {
        if this.Suspended
            return false
        if releaseGroup.SuppressUntilRelease {
            releaseGroup.Pending := {RuleIds: []}
            return true
        }
        hasHeldSource := releaseGroup.Held
        for sourceKey, sourceGroup in releaseGroup.SourceGroups {
            if sourceGroup.Held {
                hasHeldSource := true
                break
            }
        }
        upOnlyRuleIds := []
        for ruleId in releaseGroup.RuleIds {
            if !this.Rules.Has(ruleId)
                continue
            descriptor := this.Rules[ruleId]
            if descriptor.Spec["from"].Get("event", "down") == "up"
                upOnlyRuleIds.Push(ruleId)
        }
        selection := this.FindEligibleRules(upOnlyRuleIds, false)
        releaseGroup.Pending := {RuleIds: selection.RuleIds}
        return hasHeldSource || selection.RuleIds.Length > 0
    }

    ShouldInterceptUpOnly(ruleId, *) {
        if this.Suspended || !this.Rules.Has(ruleId)
            return false
        return this.MatchesCurrentContext(this.Rules[ruleId])
    }

    OnHeld(ruleId, *) {
        if !this.Active.Has(ruleId) || this.Suspended
            return false
        state := this.Active[ruleId]
        state.HeldTimer := ""
        if state.HeldFired
            return false
        state.HeldFired := true
        try {
            if !this.ExecuteActions(
                    this.GetActions(state.Descriptor, "to_if_held_down"),
                    state.Descriptor, "to_if_held_down", false, state, true)
                return false
        }
        catch as actionError {
            this.CancelActiveRule(ruleId, state)
            this.TraceActionFailure(ruleId, "to_if_held_down", actionError)
            return false
        }
        this.Trace("rule_held", {RuleId: ruleId, Outcome: "held"})
        return true
    }

    SendOriginalInput(descriptor, state := "") {
        return this.SendKeySequence(
            this.BuildOriginalInputSend(descriptor, state))
    }

    ObserveInputEvent(unifiedEvent) {
        if this.Suspended || Type(unifiedEvent) != "Map"
                || unifiedEvent.Get("origin", "") != "raw-input"
                || !unifiedEvent.Has("identity")
            return 0
        phase := unifiedEvent.Get("phase", "")
        if phase == "up"
            return this.ReleaseActiveSimultaneousSources(
                unifiedEvent["identity"])
        if phase != "down" && phase != "wheel"
            return 0
        cancelled := 0
        for ruleId, state in this.Active {
            if state.HeldFired || state.AloneCancelled
                    || !this.GetActions(state.Descriptor,
                        "to_if_alone").Length
                    || this.IsSourceInputEvent(state.Descriptor,
                        unifiedEvent["identity"])
                continue
            state.AloneCancelled := true
            cancelled++
            this.Trace("rule_alone_cancelled", {RuleId: ruleId,
                Outcome: "other_input",
                Detail: unifiedEvent["identity"]["name"]})
        }
        return cancelled
    }

    ReleaseActiveSimultaneousSources(identity) {
        releaseIds := []
        for ruleId, state in this.Active {
            if state.Descriptor.Spec["from"].Get("simultaneous", []).Length
                    && this.IsSourceInputEvent(state.Descriptor, identity)
                releaseIds.Push(ruleId)
        }
        released := 0
        for ruleId in releaseIds
            released += this.OnUp(ruleId) ? 1 : 0
        return released
    }

    IsSourceInputEvent(descriptor, identity) {
        if Type(identity) != "Map" || !identity.Has("name")
            return false
        from := descriptor.Spec["from"]
        if from.Get("simultaneous", []).Length {
            eventPrimary := identity.Get("sc", 0)
                ? Format("sc{:03X}", identity["sc"])
                : (identity.Get("vk", 0)
                    ? Format("vk{:02X}", identity["vk"])
                    : String(identity["name"]))
            for sourceKey in from["simultaneous"]
                if this.PrimaryKeysOverlap(
                        RuleCompiler.BuildKeyHotkey(sourceKey), eventPrimary)
                    return true
            return false
        }
        sourcePrimary := this.GetDescriptorPrimaryHotkey(descriptor)
        if sourcePrimary == ""
            return false
        eventPrimary := identity.Get("sc", 0)
            ? Format("sc{:03X}", identity["sc"])
            : (identity.Get("vk", 0)
                ? Format("vk{:02X}", identity["vk"])
                : String(identity["name"]))
        return this.PrimaryKeysOverlap(sourcePrimary, eventPrimary)
    }

    GetDescriptorPrimaryHotkey(descriptor) {
        from := descriptor.Spec["from"]
        if from.Has("key")
            return RuleCompiler.BuildKeyHotkey(from["key"])
        if from.Get("simultaneous", []).Length
            return RuleCompiler.BuildKeyHotkey(this.GetPrimarySourceKey(from))
        try return this.ParseHotkeyMatchModel(descriptor.Hotkey).Primary
        catch
            return ""
    }

    BuildOriginalInputSend(descriptor, state := "") {
        from := descriptor.Spec["from"]
        key := this.GetPrimarySourceKey(from)
        keyName := RuleCompiler.BuildKeyHotkey(key)
        if keyName == ""
            throw Error("Deferred passthrough requires a named source key.")
        result := "{Blind}"
        missingModifiers := []
        if IsObject(state) {
            replayModifiers := state.HasOwnProp("ReplayModifiers")
                ? state.ReplayModifiers : []
            for modifier in replayModifiers {
                if !GetKeyState(modifier, "P")
                    missingModifiers.Push(modifier)
            }
        }
        for modifier in missingModifiers
            result .= "{" modifier " down}"
        result .= "{" keyName "}"
        Loop missingModifiers.Length {
            modifier := missingModifiers[missingModifiers.Length - A_Index + 1]
            result .= "{" modifier " up}"
        }
        return result
    }

    GetPrimarySourceKey(from) {
        key := from.Has("key") ? from["key"] : ""
        if !IsObject(key) && from.Get("simultaneous", []).Length
            key := from["simultaneous"][RuleCompiler
                .GetSimultaneousPrimaryIndex(from["simultaneous"])]
        if !IsObject(key)
            throw Error("The rule has no releasable primary key.")
        return key
    }

    ExecuteActions(actions, descriptor, fieldName, isRepeat := false,
            activeState := "", requireActive := false) {
        for action in actions {
            if requireActive && !this.IsCurrentActiveState(descriptor.Id,
                    activeState)
                return false
            if isRepeat && action.Get("repeat", "inherit") == "once"
                continue
            actionType := action["type"]
            value := action.Has("value") ? action["value"] : ""
            switch actionType {
                case "send", "mouse": this.SendKeySequence(String(value))
                case "app_command": this.SendKeySequence(
                    this.BuildAppCommandSend(value))
                case "text": SendText(String(value))
                case "sleep": Sleep(Integer(value))
                case "window_minimize":
                    if hwnd := WinExist("A")
                        DllCall("user32\ShowWindow", "Ptr", hwnd,
                            "Int", 6)
                case "window_close":
                    if hwnd := WinExist("A")
                        WinClose("ahk_id " hwnd)
                case "lock_workstation":
                    if !DllCall("user32\LockWorkStation", "Int")
                        throw OSError(A_LastError, "LockWorkStation")
                case "key_down": this.PressOutputKey(descriptor.Id, value,
                    activeState)
                case "key_up": this.ReleaseOutputKey(descriptor.Id, value,
                    activeState)
                default: throw Error("Unsupported direct runtime action: "
                    . actionType)
            }
            this.Trace("action_executed", {RuleId: descriptor.Id,
                Outcome: actionType, Detail: fieldName})
        }
        return true
    }

    IsEligible(descriptor) {
        if !this.MatchesSimultaneousSource(descriptor)
            return false
        if !descriptor.Spec.Get("conditions", []).Length
            return this.TraceRuleMatched(descriptor)
        result := this.EvaluateCurrentContext(descriptor)
        if !result.Matched {
            this.Trace("condition_rejected", {RuleId: descriptor.Id,
                Outcome: "rejected", Detail: result.Reason})
            return false
        }
        return this.TraceRuleMatched(descriptor)
    }

    FindEligibleRules(ruleIds, isRepeat, repeatIgnoreRules := "") {
        selected := []
        armOnly := false
        context := ""
        contextLoaded := false
        for ruleId in ruleIds {
            if !this.Rules.Has(ruleId)
                continue
            descriptor := this.Rules[ruleId]
            repeatPolicy := descriptor.Spec["from"].Get("repeat", "allow")
            if isRepeat && repeatPolicy == "ignore" {
                ; A matched ignore rule must keep suppressing the physical
                ; auto-repeat even if its action failed and cleared Active.
                if (IsObject(repeatIgnoreRules)
                        && repeatIgnoreRules.Has(ruleId))
                        || this.Active.Has(ruleId) {
                    armOnly := true
                    stopProcessing := descriptor.HasOwnProp("StopProcessing")
                        ? descriptor.StopProcessing : true
                    if stopProcessing
                        break
                }
                continue
            }
            if !isRepeat && repeatPolicy == "only" {
                if this.MatchesSelectionContext(descriptor, &context,
                        &contextLoaded)
                    armOnly := true
                continue
            }
            if !this.MatchesSelectionContext(descriptor, &context,
                    &contextLoaded)
                continue
            selected.Push(ruleId)
            stopProcessing := descriptor.HasOwnProp("StopProcessing")
                ? descriptor.StopProcessing : true
            if stopProcessing
                break
        }
        return {RuleIds: selected, ArmOnly: armOnly}
    }

    MatchesSelectionContext(descriptor, &context, &contextLoaded) {
        if !this.MatchesSimultaneousSource(descriptor)
            return false
        conditions := descriptor.Spec.Get("conditions", [])
        if !conditions.Length
            return true
        if !contextLoaded {
            try context := this.App.ContextService.Build()
            catch as contextError {
                contextLoaded := true
                this.Trace("condition_failed", {RuleId: descriptor.Id,
                    Outcome: "error", Detail: contextError.Message})
                return false
            }
            contextLoaded := true
        }
        try result := this.ConditionEvaluator
            .EvaluateNormalizedAllDetailed(conditions, context)
        catch as conditionError {
            this.Trace("condition_failed", {RuleId: descriptor.Id,
                Outcome: "error", Detail: conditionError.Message})
            return false
        }
        if result.Matched
            return true
        this.Trace("condition_rejected", {RuleId: descriptor.Id,
            Outcome: "rejected", Detail: result.Reason})
        return false
    }

    TraceRuleMatched(descriptor, outcome := "down") {
        this.Trace("rule_matched", {RuleId: descriptor.Id,
            Source: descriptor.Source, Outcome: outcome})
        return true
    }

    MatchesCurrentContext(descriptor) {
        try return this.MatchesSimultaneousSource(descriptor)
            && this.EvaluateCurrentContext(descriptor).Matched
        catch
            return false
    }

    MatchesSimultaneousSource(descriptor) {
        keys := descriptor.Spec["from"].Get("simultaneous", [])
        if !keys.Length
            return true
        primaryIndex := RuleCompiler.GetSimultaneousPrimaryIndex(keys)
        for index, key in keys {
            if index == primaryIndex
                continue
            if !this.IsPhysicalSourceDown(RuleCompiler.BuildKeyHotkey(key))
                return false
        }
        return true
    }

    EvaluateCurrentContext(descriptor) {
        conditions := descriptor.Spec.Get("conditions", [])
        if !conditions.Length
            return {Matched: true, Reason: "all_conditions_matched"}
        context := this.App.ContextService.Build()
        return this.ConditionEvaluator.EvaluateNormalizedAllDetailed(
            conditions, context)
    }

    NeedsRelease(descriptor) {
        for fieldName in RuleSpec.ActionFields {
            if fieldName == "to" {
                for action in this.GetActions(descriptor, fieldName) {
                    if action["type"] == "key_down"
                        return true
                }
                continue
            }
            if this.GetActions(descriptor, fieldName).Length
                return true
        }
        return false
    }

    IsReleasable(descriptor) {
        from := descriptor.Spec["from"]
        key := from.Has("key") ? from["key"] : Map()
        if !key.Count && from.Get("simultaneous", []).Length
            key := this.GetPrimarySourceKey(from)
        name := key.Has("name") ? String(key["name"]) : descriptor.Hotkey
        return !RegExMatch(name,
            "i)^(?:WheelUp|WheelDown|WheelLeft|WheelRight|MouseMove)$")
    }

    GetTiming(descriptor) {
        return Map("held_threshold_ms",
            descriptor.Spec.Get("timing", Map()).Get("held_threshold_ms", 200))
    }

    GetActions(descriptor, fieldName) => descriptor.Spec.Get(fieldName, [])

    BuildAppCommandSend(value) => "{" String(value) "}"

    StopStateTimers(state) {
        if IsObject(state.HeldTimer)
            SetTimer(state.HeldTimer, 0)
    }

    CancelAllActive() {
        activeStates := []
        for ruleId, state in this.Active
            activeStates.Push({RuleId: ruleId, State: state})
        for activeState in activeStates
            this.CancelActiveRule(activeState.RuleId, activeState.State)
        this.Active.Clear()
        return this.RetryOutputCleanup()
    }

    CancelActiveRule(ruleId, state) {
        this.StopStateTimers(state)
        cleaned := true
        try this.ReleasePressedKeys(state)
        catch as cleanupError {
            cleaned := false
            state.CleanupPending := true
            this.TraceActionFailure(ruleId, "output_cleanup", cleanupError)
            this.ScheduleOutputCleanupRetry()
        }
        finally {
            if this.IsCurrentActiveState(ruleId, state)
                this.Active.Delete(ruleId)
        }
        return cleaned
    }

    ReleasePressedKeys(state) {
        if !state.HasOwnProp("PressedKeys")
            return 0
        keyNames := []
        for keyName in state.PressedKeys
            keyNames.Push(keyName)
        released := 0
        errors := []
        for keyName in keyNames {
            try {
                if this.ReleaseOwnedOutput(state.Descriptor.Id, keyName, state)
                    released++
            } catch as releaseError
                errors.Push(keyName ": " releaseError.Message)
        }
        if errors.Length
            throw Error("Could not release every owned output key: "
                . this.Join(errors, "; "))
        return released
    }

    PressOutputKey(ruleId, keyName, state := "") {
        if !IsObject(state) {
            if !this.Active.Has(ruleId)
                throw Error("A key_down action requires an active source state.")
            state := this.Active[ruleId]
        }
        if state.Descriptor.Id != ruleId
            throw Error("The output owner does not match the active rule.")
        keyName := String(keyName)
        if state.PressedKeys.Has(keyName)
            return false
        if this.OutputOwners.Has(keyName) {
            owners := this.OutputOwners[keyName]
            cleanupPending := owners.Count > 0
            for ownerState in owners {
                if !ownerState.HasOwnProp("CleanupPending")
                        || !ownerState.CleanupPending {
                    cleanupPending := false
                    break
                }
            }
            if cleanupPending {
                this.RetryOutputCleanup()
                if this.OutputOwners.Has(keyName)
                    this.ScheduleOutputCleanupRetry(true)
            }
        }
        if !this.OutputOwners.Has(keyName)
            this.OutputOwners[keyName] := Map()
        owners := this.OutputOwners[keyName]
        shouldPress := owners.Count == 0
        owners[state] := true
        state.PressedKeys[keyName] := true
        if shouldPress {
            try this.SendKeyEvent(keyName, "down")
            catch as pressError {
                compensated := false
                try {
                    this.SendKeyEvent(keyName, "up")
                    compensated := true
                }
                if compensated {
                    owners.Delete(state)
                    state.PressedKeys.Delete(keyName)
                    if !owners.Count {
                        this.OutputOwners.Delete(keyName)
                        if !this.OutputOwners.Count
                            this.ResetOutputCleanupRetryState()
                    }
                } else {
                    this.ScheduleOutputCleanupRetry()
                }
                throw pressError
            }
        }
        return true
    }

    ReleaseOutputKey(ruleId, keyName, state := "") {
        keyName := String(keyName)
        if !IsObject(state) && this.Active.Has(ruleId)
            state := this.Active[ruleId]
        if IsObject(state) && state.Descriptor.Id == ruleId
                && state.PressedKeys.Has(keyName)
            return this.ReleaseOwnedOutput(ruleId, keyName, state)
        return false
    }

    ReleaseOwnedOutput(ruleId, keyName, state) {
        keyName := String(keyName)
        if !state.PressedKeys.Has(keyName)
            return false
        if !this.OutputOwners.Has(keyName) {
            state.PressedKeys.Delete(keyName)
            return false
        }
        owners := this.OutputOwners[keyName]
        if !owners.Has(state) {
            state.PressedKeys.Delete(keyName)
            return false
        }
        if owners.Count > 1 {
            owners.Delete(state)
            state.PressedKeys.Delete(keyName)
            return false
        }
        ; Keep the final owner in both ledgers until KeyUp succeeds. A failed
        ; send can then be retried instead of leaving an untracked stuck key.
        this.SendKeyEvent(keyName, "up")
        owners.Delete(state)
        state.PressedKeys.Delete(keyName)
        this.OutputOwners.Delete(keyName)
        if !this.OutputOwners.Count
            this.ResetOutputCleanupRetryState()
        return true
    }

    ScheduleOutputCleanupRetry(startNewCycle := false) {
        if this.OutputCleanupScheduled || !this.OutputOwners.Count
            return false
        if this.OutputCleanupRetryCount
                >= DirectHotkeyRuntime.MaximumOutputCleanupRetries {
            if startNewCycle
                this.OutputCleanupRetryCount := 0
            else {
                this.Trace("output_cleanup_abandoned", {Outcome: "error",
                    Detail: this.OutputOwners.Count})
                return false
            }
        }
        this.OutputCleanupRetryCount++
        this.OutputCleanupScheduled := true
        SetTimer(this.OutputCleanupTimer,
            -DirectHotkeyRuntime.OutputCleanupRetryDelayMs)
        return true
    }

    RetryOutputCleanup(*) {
        SetTimer(this.OutputCleanupTimer, 0)
        this.OutputCleanupScheduled := false
        keyNames := []
        for keyName in this.OutputOwners
            keyNames.Push(keyName)
        errors := []
        for keyName in keyNames {
            if !this.OutputOwners.Has(keyName)
                continue
            owners := this.OutputOwners[keyName]
            if !owners.Count {
                this.OutputOwners.Delete(keyName)
                continue
            }
            staleOwners := []
            hasCurrentOwner := false
            for state in owners {
                if this.IsCurrentActiveState(state.Descriptor.Id, state)
                    hasCurrentOwner := true
                else
                    staleOwners.Push(state)
            }
            if hasCurrentOwner {
                for state in staleOwners {
                    owners.Delete(state)
                    if state.PressedKeys.Has(keyName)
                        state.PressedKeys.Delete(keyName)
                }
                continue
            }
            try this.SendKeyEvent(keyName, "up")
            catch as releaseError {
                errors.Push(keyName ": " releaseError.Message)
                continue
            }
            for state in owners {
                if state.PressedKeys.Has(keyName)
                    state.PressedKeys.Delete(keyName)
            }
            this.OutputOwners.Delete(keyName)
        }
        if errors.Length {
            this.Trace("output_cleanup_failed", {Outcome: "error",
                Detail: this.Join(errors, "; ")})
            this.ScheduleOutputCleanupRetry()
            return false
        }
        this.OutputCleanupRetryCount := 0
        return true
    }

    ResetOutputCleanupRetryState() {
        if this.OutputCleanupScheduled
            SetTimer(this.OutputCleanupTimer, 0)
        this.OutputCleanupScheduled := false
        this.OutputCleanupRetryCount := 0
        return true
    }

    IsCurrentActiveState(ruleId, state) {
        return IsObject(state) && this.Active.Has(ruleId)
            && this.Active[ruleId] == state
    }

    SendKeyEvent(keyName, phase) {
        return this.SendKeySequence("{" String(keyName) " " phase "}")
    }

    SendKeySequence(sequence) {
        previousCritical := A_IsCritical
        previousDelay := A_KeyDelay
        previousDuration := A_KeyDuration
        Critical("On")
        try {
            SetKeyDelay(DirectHotkeyRuntime.OutputKeyDelayMs,
                DirectHotkeyRuntime.OutputPressDurationMs)
            this.DispatchKeySequence(String(sequence))
        } finally {
            SetKeyDelay(previousDelay, previousDuration)
            Critical(previousCritical ? previousCritical : "Off")
        }
        return true
    }

    DispatchKeySequence(sequence) {
        SendEvent(String(sequence))
        return true
    }

    HasWildcard(hotkeyName) => InStr(String(hotkeyName), "*") > 0

    Suspend() {
        if this.Suspended
            return false
        this.Suspended := true
        this.CancelAllActive()
        this.ResetSourceCycleState()
        disabled := []
        try {
            for registration in this.Registrations {
                this.DisableRegistration(registration)
                disabled.Push(registration)
            }
        } catch as suspendError {
            this.Suspended := false
            rollbackFailures := 0
            Loop disabled.Length {
                registration := disabled[disabled.Length - A_Index + 1]
                try this.EnableRegistration(registration)
                catch
                    rollbackFailures++
            }
            if rollbackFailures
                throw Error(suspendError.Message
                    . "; one or more hotkeys could not be restored.", -1,
                    suspendError)
            throw suspendError
        }
        return true
    }

    Resume() {
        if !this.Suspended
            return false
        this.ResetSourceCycleState()
        this.ArmPhysicallyHeldSources()
        try {
            for registration in this.Registrations
                this.EnableRegistration(registration)
            this.Suspended := false
        } catch as resumeError {
            for registration in this.Registrations
                try this.DisableRegistration(registration)
            throw resumeError
        }
        return true
    }

    RecoverAfterResume() {
        cleaned := this.CancelAllActive()
        this.ResetSourceCycleState()
        this.ArmPhysicallyHeldSources()
        this.Trace("resume_state_recovered", {Outcome: cleaned ? "ok" : "error",
            Data: Map("pending_outputs", this.OutputOwners.Count)})
        return cleaned
    }

    GetCapabilities() {
        return Map("backend", "direct-ahk-hotkeys",
            "available", JsonBoolean(true),
            "suppresses_original_input", JsonBoolean(true),
            "recording", JsonBoolean(true))
    }

    Shutdown() {
        result := this.DisableAll()
        SetTimer(this.OutputCleanupTimer, 0)
        this.OutputCleanupScheduled := false
        Loop DirectHotkeyRuntime.MaximumOutputCleanupRetries {
            if !this.OutputOwners.Count
                break
            Sleep(DirectHotkeyRuntime.OutputCleanupRetryDelayMs)
            this.RetryOutputCleanup()
        }
        SetTimer(this.OutputCleanupTimer, 0)
        this.OutputCleanupScheduled := false
        return result && !this.OutputOwners.Count
    }

    CreateActiveState(descriptor) {
        return {Descriptor: descriptor, HeldFired: false, HeldTimer: "",
            AloneCancelled: false,
            CleanupPending: false,
            PressedKeys: Map(), ReplayModifiers: this.CaptureReplayModifiers(
                descriptor),
            PressedAt: this.GetMonotonicTick()}
    }

    GetMonotonicTick() => DllCall("kernel32\GetTickCount64", "UInt64")

    CaptureReplayModifiers(descriptor) {
        from := descriptor.Spec["from"]
        result := []
        primaryName := ""
        if from.Has("key")
            primaryName := from["key"]["name"]
        else if from.Get("simultaneous", []).Length
            primaryName := this.GetPrimarySourceKey(from)["name"]
        for modifier in ["LCtrl", "RCtrl", "LShift", "RShift",
                "LAlt", "RAlt", "LWin", "RWin"] {
            if this.IsSourcePrimaryModifier(primaryName, modifier)
                continue
            if GetKeyState(modifier, "P")
                result.Push(modifier)
        }
        return result
    }

    IsSourcePrimaryModifier(primaryName, physicalModifier) {
        primaryName := StrLower(String(primaryName))
        physicalModifier := StrLower(String(physicalModifier))
        if primaryName == physicalModifier
            return true
        families := Map("ctrl", "ctrl", "shift", "shift", "alt", "alt",
            "win", "win")
        for family, label in families {
            if primaryName == family
                    && InStr(physicalModifier, label)
                return true
        }
        return false
    }

    ValidateDescriptor(descriptor) {
        from := descriptor.Spec["from"]
        if from.Get("simultaneous", []).Length {
            this.BuildModifierChordHotkey(from["simultaneous"])
            primaryIndex := RuleCompiler.GetSimultaneousPrimaryIndex(
                from["simultaneous"])
            for index, key in from["simultaneous"] {
                if index != primaryIndex && RegExMatch(key["name"],
                        "i)^(?:WheelUp|WheelDown|WheelLeft|WheelRight|MouseMove)$")
                    throw Error("A non-releasable input cannot precede the simultaneous trigger key.")
            }
        }
        if from.Get("event", "down") == "up" && (from.Get("modifiers", []).Length
                || from.Get("optional_modifiers", []).Length)
            throw Error("Key-up rules with modifiers are not supported by the direct AHK runtime.")
        if from.Get("repeat", "allow") == "only" && !this.IsReleasable(descriptor)
            throw Error("repeat=only requires a source key with an observable release event.")
        if !this.IsReleasable(descriptor) && this.NeedsRelease(descriptor)
            throw Error("Sources without an up event cannot use held, release, or key-down actions.")
        for fieldName in RuleSpec.ActionFields {
            for action in this.GetActions(descriptor, fieldName) {
                actionType := action["type"]
                if actionType != "send" && actionType != "mouse"
                        && actionType != "app_command" && actionType != "text"
                        && actionType != "sleep" && actionType != "window_minimize"
                        && actionType != "window_close" && actionType != "lock_workstation"
                        && actionType != "key_down" && actionType != "key_up"
                    throw Error("Action '" actionType
                        . "' is not supported by the direct AHK runtime.")
                if action.Get("repeat_interval_ms", 0) > 0
                    throw Error("Timed action repetition is not supported by the direct AHK runtime.")
            }
        }
        return true
    }

    TraceActionFailure(ruleId, phase, actionError) {
        detail := IsObject(actionError) ? actionError.Message
            : String(actionError)
        this.Trace("action_failed", {RuleId: ruleId, Outcome: phase,
            Detail: detail})
        return false
    }

    GetHotkeyVariantSignature(hotkeyName) {
        name := String(hotkeyName)
        passthrough := RegExMatch(name, "^[~*$]*~") ? "~" : ""
        return passthrough RuleCompiler.NormalizeHotkeySignature(name)
    }

    GetReleaseVariantSignature(hotkeyName) {
        signature := this.GetHotkeyVariantSignature(hotkeyName)
        if SubStr(signature, 1, 1) == "~"
            return "~" LTrim(SubStr(signature, 2), "*")
        return LTrim(signature, "*")
    }

    ParseHotkeyMatchModel(hotkeyName) {
        name := RegExReplace(Trim(String(hotkeyName)), "i)\s+Up$")
        model := {Primary: "", Wildcard: false, Required: []}
        position := 1
        while position <= StrLen(name) {
            character := SubStr(name, position, 1)
            if character == "$" || character == "~" {
                position++
                continue
            }
            if character == "*" {
                model.Wildcard := true
                position++
                continue
            }
            prefix := ""
            if (character == "<" || character == ">")
                    && position < StrLen(name) {
                nextCharacter := SubStr(name, position + 1, 1)
                if InStr("^+!#", nextCharacter, true) {
                    prefix := character nextCharacter
                    position += 2
                }
            }
            if prefix == "" && InStr("^+!#", character, true) {
                prefix := character
                position++
            }
            if prefix == ""
                break
            model.Required.Push(prefix)
        }
        model.Primary := StrLower(Trim(SubStr(name, position)))
        if model.Primary == ""
            throw Error("A hotkey match model requires a primary key.")
        return model
    }

    PrimaryKeysOverlap(leftPrimary, rightPrimary) {
        left := this.BuildPrimaryKeyMatchModel(leftPrimary)
        right := this.BuildPrimaryKeyMatchModel(rightPrimary)
        if left.ModifierFamily != "" || right.ModifierFamily != ""
            return left.ModifierFamily != ""
                && left.ModifierFamily == right.ModifierFamily
                && (left.ModifierSide == "" || right.ModifierSide == ""
                    || left.ModifierSide == right.ModifierSide)
        if left.VirtualKeyOnly || right.VirtualKeyOnly
            return left.VK && right.VK && left.VK == right.VK
        if left.SC && right.SC
            return left.SC == right.SC
        leftAliases := this.GetPrimaryKeyAliases(leftPrimary)
        rightAliases := this.GetPrimaryKeyAliases(rightPrimary)
        for alias in leftAliases
            if rightAliases.Has(alias)
                return true
        return false
    }

    BuildPrimaryKeyMatchModel(primary) {
        primary := StrLower(Trim(String(primary)))
        virtualKeyOnly := RegExMatch(primary,
            "i)^vk([0-9a-f]{1,2})$", &vkMatch) > 0
        vk := 0
        sc := 0
        if virtualKeyOnly
            vk := Integer("0x" vkMatch[1])
        else if RegExMatch(primary, "i)^sc([0-9a-f]{1,3})$", &scMatch)
            sc := Integer("0x" scMatch[1])
        try {
            if !vk
                vk := GetKeyVK(primary)
        }
        try {
            if !sc && !virtualKeyOnly
                sc := GetKeySC(primary)
        }
        modifierFamily := this.GetPrimaryModifierFamily(primary)
        modifierSide := this.GetPrimaryModifierSide(primary)
        return {VK: vk, SC: sc, VirtualKeyOnly: virtualKeyOnly,
            ModifierFamily: modifierFamily, ModifierSide: modifierSide}
    }

    GetPrimaryModifierFamily(primary) {
        primary := StrLower(Trim(String(primary)))
        try {
            canonical := StrLower(String(GetKeyName(primary)))
            if canonical != ""
                primary := canonical
        }
        switch primary {
            case "ctrl", "control", "lctrl", "lcontrol", "rctrl", "rcontrol":
                return "ctrl"
            case "shift", "lshift", "rshift": return "shift"
            case "alt", "lalt", "ralt": return "alt"
            case "win", "lwin", "rwin": return "win"
        }
        return ""
    }

    GetPrimaryModifierSide(primary) {
        primary := StrLower(Trim(String(primary)))
        try {
            canonical := StrLower(String(GetKeyName(primary)))
            if canonical != ""
                primary := canonical
        }
        switch primary {
            case "lctrl", "lcontrol", "lshift", "lalt", "lwin": return "left"
            case "rctrl", "rcontrol", "rshift", "ralt", "rwin": return "right"
        }
        return ""
    }

    GetPhysicalModifierState() {
        modifierBits := Map("LCtrl", 0x01, "RCtrl", 0x02,
            "LShift", 0x04, "RShift", 0x08, "LAlt", 0x10,
            "RAlt", 0x20, "LWin", 0x40, "RWin", 0x80)
        state := 0
        for modifier, bit in modifierBits
            if GetKeyState(modifier, "P")
                state |= bit
        return state
    }

    GetGenericPrimaryModifierFamily(primary) {
        primary := StrLower(Trim(String(primary)))
        try {
            canonical := StrLower(String(GetKeyName(primary)))
            if canonical != ""
                primary := canonical
        }
        switch primary {
            case "ctrl", "control": return "ctrl"
            case "shift": return "shift"
            case "alt": return "alt"
            case "win": return "win"
        }
        return ""
    }

    GetPrimaryKeyAliases(primary) {
        primary := StrLower(Trim(String(primary)))
        aliases := Map("name:" primary, true)
        try {
            canonicalName := StrLower(String(GetKeyName(primary)))
            if canonicalName != ""
                aliases["name:" canonicalName] := true
        }
        try {
            virtualKey := GetKeyVK(primary)
            if virtualKey
                aliases["vk:" Format("{:02x}", virtualKey)] := true
        }
        try {
            scanCode := GetKeySC(primary)
            if scanCode
                aliases["sc:" Format("{:03x}", scanCode)] := true
        }
        return aliases
    }

    MatchesModifierState(model, state) {
        modifierBits := Map("<^", 0x01, ">^", 0x02,
            "<+", 0x04, ">+", 0x08, "<!", 0x10, ">!", 0x20,
            "<#", 0x40, ">#", 0x80)
        familyBits := Map("^", 0x03, "+", 0x0C, "!", 0x30,
            "#", 0xC0)
        requiredFamilies := Map()
        for prefix in model.Required {
            family := SubStr(prefix, StrLen(prefix), 1)
            requiredFamilies[family] := true
            if modifierBits.Has(prefix) {
                if !(state & modifierBits[prefix])
                    return false
            } else if familyBits.Has(prefix) {
                if !(state & familyBits[prefix])
                    return false
            } else {
                throw Error("Unsupported hotkey modifier prefix: " prefix)
            }
        }
        if model.Wildcard
            return true
        for family, bits in familyBits
            if !requiredFamilies.Has(family) && (state & bits)
                return false
        return true
    }

    CompareRulePrecedence(left, right) {
        leftPriority := left.HasOwnProp("Priority") ? left.Priority : 0
        rightPriority := right.HasOwnProp("Priority") ? right.Priority : 0
        if leftPriority != rightPriority
            return leftPriority > rightPriority ? -1 : 1
        leftSpecificity := this.GetSourceSpecificity(left)
        rightSpecificity := this.GetSourceSpecificity(right)
        if leftSpecificity != rightSpecificity
            return leftSpecificity > rightSpecificity ? -1 : 1
        leftOrder := left.HasOwnProp("Order") ? left.Order : 0
        rightOrder := right.HasOwnProp("Order") ? right.Order : 0
        if leftOrder == rightOrder
            return 0
        return leftOrder < rightOrder ? -1 : 1
    }

    GetSourceSpecificity(descriptor) {
        return descriptor.Spec["from"].Get("simultaneous", []).Length
    }

    SortRuleIds(ruleIds, rules) {
        if ruleIds.Length < 2
            return ruleIds
        Loop ruleIds.Length - 1 {
            leftIndex := A_Index
            Loop ruleIds.Length - leftIndex {
                rightIndex := leftIndex + A_Index
                if this.CompareRulePrecedence(rules[ruleIds[leftIndex]],
                        rules[ruleIds[rightIndex]]) <= 0
                    continue
                temporary := ruleIds[leftIndex]
                ruleIds[leftIndex] := ruleIds[rightIndex]
                ruleIds[rightIndex] := temporary
            }
        }
        return ruleIds
    }

    FormatIssues(issues) {
        lines := ["Rules were not applied:"]
        for issue in issues
            lines.Push(issue.RuleId ": " issue.Message)
        return this.Join(lines, "`n")
    }

    IsModifierName(name) {
        return Map("Ctrl", true, "Shift", true, "Alt", true, "Win", true,
            "LCtrl", true, "RCtrl", true, "LShift", true, "RShift", true,
            "LAlt", true, "RAlt", true, "LWin", true, "RWin", true).Has(name)
    }

    Join(values, separator) {
        result := ""
        for index, value in values
            result .= (index == 1 ? "" : separator) value
        return result
    }

    Trace(eventName, fields := "") {
        try return this.App.TraceEvent("runtime", eventName, fields)
        catch
            return false
    }
}
