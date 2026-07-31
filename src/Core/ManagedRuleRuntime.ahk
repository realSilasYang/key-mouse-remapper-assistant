class ManagedRuleRuntime {
    __New(app, backend, enableObserver := true, globalTiming := "") {
        this.App := app
        this.Backend := InputBackendContract.Validate(backend)
        this.EnableObserver := !!enableObserver
        this.GlobalTiming := RuleTimingResolver.NormalizeOverrides(
            globalTiming, "global_timing")
        this.ConditionEvaluator := RuleConditionEvaluator()
        this.ConflictAnalyzer := RuleConflictAnalyzer()
        this.VariableStore := app.HasOwnProp("VariableStore")
            && IsObject(app.VariableStore) ? app.VariableStore
            : ScopedVariableStore()
        ; 兼容现有调用方；事实来源已经迁移到分作用域存储。
        this.Variables := this.VariableStore.TransientValues
        this.Rules := Map()
        this.Groups := Map()
        this.ComplexRules := []
        this.ComplexHeld := Map()
        this.SimultaneousStarted := Map()
        this.SequenceStates := Map()
        this.ComplexActiveKeys := Map()
        this.ComplexDownOrder := []
        this.MatchedComplexPatterns := []
        this.SimpleHeld := Map()
        this.TapStates := Map()
        ledgerCallback := app.HasOwnProp("OutputRecoveryJournal")
                && IsObject(app.OutputRecoveryJournal)
            ? ObjBindMethod(app.OutputRecoveryJournal, "Update") : ""
        this.OutputLedger := OutputLedger(ledgerCallback)
        this.PressedOutputKeys := this.OutputLedger.Keys
        this.Scheduler := RuleScheduler()
        this.RepeatActive := Map()
        this.OneShotOwners := Map()
        this.Observer := ""
        this.AllowRunActions := false
        this.StateMachine := ManagedRuleStateMachine(
            ObjBindMethod(this, "ExecuteActions"),
            ObjBindMethod(this, "TraceState"))
    }

    ApplyMappings(mappings) {
        if Type(mappings) != "Array"
            throw TypeError("托管规则运行时需要映射数组。")
        for mapping in mappings {
            if !mapping.HasOwnProp("Mode") || mapping.Mode != "managed"
                throw Error("托管规则运行时只接受 managed RuleSpec 映射。")
        }
        issues := this.ConflictAnalyzer.Analyze(mappings)
        blockedIds := Map()
        for issue in issues {
            if issue.Severity == "error"
                blockedIds[issue.RuleId] := true
        }
        rules := Map()
        groups := Map()
        complexRules := []
        for order, mapping in mappings {
            descriptor := mapping.HasOwnProp("Descriptor")
                ? mapping.Descriptor : RuleCompiler.Compile(mapping.Spec)
            descriptor.Order := order
            timingResolution := this.ResolveTiming(descriptor)
            descriptor.EffectiveTiming := timingResolution.Values
            descriptor.TimingSources := timingResolution.Sources
            if descriptor.Mode == "sequence"
                this.PrepareSequenceMatcher(descriptor)
            if !descriptor.Enabled || blockedIds.Has(descriptor.Id)
                continue
            rules[descriptor.Id] := descriptor
            if descriptor.Mode == "hotkey"
                this.AddSimpleDescriptor(groups, descriptor, issues)
            else {
                complexRules.Push(descriptor)
            }
        }
        for groupKey, group in groups {
            RuleCompiler.SortDescriptors(group.Down)
            RuleCompiler.SortDescriptors(group.Up)
        }
        RuleCompiler.SortDescriptors(complexRules)
        registrations := this.BuildRegistrations(groups)

        previousRules := this.Rules
        previousGroups := this.Groups
        previousComplexRules := this.ComplexRules
        this.Rules := rules
        this.Groups := groups
        this.ComplexRules := complexRules
        try this.Backend.Replace(registrations)
        catch as applyError {
            this.Rules := previousRules
            this.Groups := previousGroups
            this.ComplexRules := previousComplexRules
            throw Error("托管规则热应用失败，已恢复上一组注册："
                applyError.Message)
        }
        this.ResetActiveState("rules_replaced")
        if rules.Count && this.EnableObserver
            this.StartObserver()
        else
            this.StopObserver()
        this.Trace("rules_applied", {Outcome: "ok",
            Detail: rules.Count " managed rules",
            Data: Map("rules", rules.Count,
                "registrations", registrations.Length,
                "issues", issues.Length)})
        for issue in issues
            this.Trace("conflict_detected", {
                RuleId: issue.RuleId,
                Source: issue.RelatedRuleId,
                Outcome: issue.Severity,
                Detail: issue.Code ": " issue.Message,
                Data: Map("code", issue.Code,
                    "related_rule_id", issue.RelatedRuleId)})
        return {Applied: rules.Count, Registrations: registrations.Length,
            Issues: issues, Capabilities: this.Backend.GetCapabilities()}
    }

    AddSimpleDescriptor(groups, descriptor, issues) {
        hotkeyName := Trim(descriptor.Hotkey)
        eventName := descriptor.Spec["from"]["event"]
        if RegExMatch(hotkeyName, "i)\s+Up$") {
            hotkeyName := RegExReplace(hotkeyName, "i)\s+Up$")
            eventName := "up"
        }
        if hotkeyName == ""
            return
        registrationName := this.EnsureHookHotkey(hotkeyName)
        groupKey := this.GetSimpleGroupKey(registrationName, descriptor)
        if !groups.Has(groupKey)
            groups[groupKey] := {Name: registrationName,
                Down: [], Up: [], Release: [], RepeatRelease: [],
                TrackRelease: false}
        group := groups[groupKey]
        if eventName == "up"
            group.Up.Push(descriptor)
        else {
            group.Down.Push(descriptor)
            if this.HasOnceAction(descriptor.Spec["to"])
                group.TrackRelease := true
            if descriptor.Spec["from"]["repeat"] != "allow"
                group.TrackRelease := true
            if this.HasFixedRepeatAction(descriptor) {
                group.TrackRelease := true
                group.RepeatRelease.Push(descriptor.Id)
            }
            if this.NeedsState(descriptor) {
                if this.IsReleasable(hotkeyName)
                    group.Release.Push(descriptor.Id)
                else
                    issues.Push(this.ConflictAnalyzer.Issue(
                        "missing-key-up", "warning", descriptor.Id, "",
                        "该来源没有可观察的松开事件，松开/单击/长按动作不可用。"))
            }
        }
    }

    BuildRegistrations(groups) {
        registrations := []
        for groupKey, group in groups {
            triggers := this.GetGroupTriggers(group)
            if group.Down.Length
                registrations.Push({Name: group.Name,
                    Callback: ObjBindMethod(this, "HandleSimpleGroup",
                        groupKey, "down"), Kind: "simple",
                    GroupKey: groupKey, Phase: "down", Triggers: triggers})
            if group.Up.Length || group.Release.Length
                    || group.RepeatRelease.Length || group.TrackRelease
                registrations.Push({Name: group.Name " Up",
                    Callback: ObjBindMethod(this, "HandleSimpleGroup",
                        groupKey, "up"), Kind: "simple",
                    GroupKey: groupKey, Phase: "up", Triggers: triggers})
        }
        return registrations
    }

    GetGroupTriggers(group) {
        triggers := [], seen := Map()
        for descriptors in [group.Down, group.Up] {
            for descriptor in descriptors {
                from := descriptor.Spec["from"]
                if !from.Has("key") || Type(from["key"]) != "Map"
                    continue
                trigger := Map("key", RuleSpec.Clone(from["key"]),
                    "modifiers", RuleSpec.Clone(from["modifiers"]),
                    "allow_extra_modifiers",
                        JsonBoolean(from["optional_modifiers"].Length > 0))
                signature := JsonCodec.Stringify(trigger, true, true)
                if seen.Has(signature)
                    continue
                seen[signature] := true
                triggers.Push(trigger)
            }
        }
        return triggers
    }

    GetSimpleGroupKey(registrationName, descriptor) {
        return StrLower(RegExReplace(registrationName, "\s+", ""))
            . "|" descriptor.DispatchSignature
    }

    HandleSimpleGroup(groupKey, phase, unifiedEvent := "", *) {
        if !this.Groups.Has(groupKey)
            return false
        group := this.Groups[groupKey]
        deviceScope := this.GetEventDeviceScope(unifiedEvent)
        heldKey := deviceScope "|" groupKey
        triggerIdentity := "key:" deviceScope ":"
            . this.GetPrimaryKeyName(group.Name)
        if phase == "down" {
            isRepeat := Type(unifiedEvent) == "Map"
                    && unifiedEvent.Has("repeat")
                ? unifiedEvent["repeat"].Value
                : (group.TrackRelease && this.SimpleHeld.Has(heldKey))
            this.TraceInputEvent(Type(unifiedEvent) == "Map" ? unifiedEvent
                : InputEvent.Create(KeyIdentity.Create("named",
                    this.GetPrimaryKeyName(group.Name)), "down", isRepeat,
                    false, "runtime-synthetic"))
            if group.TrackRelease
                this.SimpleHeld[heldKey] := true
            this.StateMachine.Interrupt(triggerIdentity, deviceScope)
            descriptors := this.FindEligibleChain(group.Down, isRepeat,
                deviceScope)
            if !descriptors.Length
                return false
            for descriptor in descriptors {
                stateId := this.RuleDeviceKey(descriptor.Id, deviceScope)
                if this.NeedsState(descriptor) {
                    if this.StateMachine.Begin(descriptor, triggerIdentity,
                            stateId, deviceScope)
                        this.ScheduleTimers(descriptor, stateId)
                } else {
                    if this.HasFixedRepeatAction(descriptor)
                        this.RepeatActive[stateId] := true
                    this.ExecuteActions(descriptor.Spec["to"], descriptor, "to",
                        isRepeat, stateId)
                }
                this.Trace("rule_matched", {Source: descriptor.Source,
                    RuleId: descriptor.Id, Outcome: "down",
                    Data: Map("priority", descriptor.Priority,
                        "stop_processing", descriptor.StopProcessing)})
            }
            return true
        }
        if this.SimpleHeld.Has(heldKey)
            this.SimpleHeld.Delete(heldKey)
        this.TraceInputEvent(Type(unifiedEvent) == "Map" ? unifiedEvent
            : InputEvent.Create(KeyIdentity.Create("named",
                this.GetPrimaryKeyName(group.Name)), "up", false,
                false, "runtime-synthetic"))
        for ruleId in group.Release {
            stateId := this.RuleDeviceKey(ruleId, deviceScope)
            if this.StateMachine.States.Has(stateId) {
                this.CancelTimers(stateId)
                this.StateMachine.Release(stateId)
            }
        }
        for ruleId in group.RepeatRelease
            this.CancelActionRepeats(this.RuleDeviceKey(ruleId, deviceScope))
        matched := false
        for descriptor in this.FindEligibleChain(group.Up, false, deviceScope) {
            matched := true
            stateId := this.RuleDeviceKey(descriptor.Id, deviceScope)
            this.ExecuteActions(descriptor.Spec["to"], descriptor, "to",
                false, stateId)
            this.ExecuteActions(descriptor.Spec["to_after_key_up"],
                descriptor, "to_after_key_up", false, stateId)
            this.ExecuteActions(descriptor.Spec["to_delayed_if_canceled"],
                descriptor, "to_delayed_if_canceled", false, stateId)
            this.Trace("rule_matched", {Source: descriptor.Source,
                RuleId: descriptor.Id, Outcome: "up",
                Data: Map("priority", descriptor.Priority,
                    "stop_processing", descriptor.StopProcessing)})
        }
        return matched || group.Release.Length || group.RepeatRelease.Length
    }

    HandleComplexKey(normalizedKey, phase, deviceScope := "", *) {
        normalizedKey := this.NormalizeComplexIdentity(normalizedKey)
        deviceScope := this.NormalizeDeviceScope(deviceScope)
        stateKey := deviceScope "|" normalizedKey
        now := A_TickCount
        triggerIdentity := "key:" stateKey
        if phase == "down" {
            matchedAny := false
            isRepeat := this.ComplexHeld.Has(stateKey)
            if !isRepeat {
                this.StateMachine.Interrupt(triggerIdentity, deviceScope)
                this.ComplexHeld[stateKey] := now
                this.ComplexDownOrder.Push(stateKey)
            }
            matchedSignatures := Map()
            for descriptor in this.ComplexRules {
                if !this.DescriptorContainsKey(descriptor, normalizedKey)
                    continue
                repeatPolicy := descriptor.Spec["from"]["repeat"]
                if isRepeat && repeatPolicy == "ignore"
                    continue
                allowMatch := !matchedSignatures.Has(descriptor.Signature)
                    || !matchedSignatures[descriptor.Signature]
                if descriptor.Mode == "simultaneous"
                    matched := this.TrySimultaneous(descriptor, now,
                        allowMatch, isRepeat, deviceScope)
                else
                    matched := this.AdvanceSequence(descriptor, normalizedKey,
                        now, allowMatch, deviceScope)
                if matched
                    matchedSignatures[descriptor.Signature] :=
                        descriptor.StopProcessing
                if matched
                    matchedAny := true
            }
            ; 滚轮和鼠标移动没有对应的物理 Up 事件，只在它发生的这一刻
            ; 参与共同按下判断，并立即清理状态。
            if !isRepeat && !this.IsReleasable(normalizedKey)
                this.ReleaseComplexKey(normalizedKey, deviceScope)
            return matchedAny
        }
        return this.ReleaseComplexKey(normalizedKey, deviceScope) > 0
    }

    HandleInputEvent(unifiedEvent) {
        if Type(unifiedEvent) != "Map" || !unifiedEvent.Has("identity")
                || !unifiedEvent.Has("phase")
            throw TypeError("统一输入事件无效。")
        this.TraceInputEvent(unifiedEvent)
        identity := unifiedEvent["identity"]
        if identity["kind"] == "device" {
            lifecycle := unifiedEvent.Has("metadata")
                    && unifiedEvent["metadata"].Has("lifecycle")
                ? unifiedEvent["metadata"]["lifecycle"]
                : unifiedEvent["phase"]
            if unifiedEvent["phase"] == "removal" || lifecycle == "rebound"
                this.ReleaseDeviceState(identity["device_id"], lifecycle)
            return false
        }
        if unifiedEvent["phase"] == "down"
            this.ReleaseOneShotModifiers()
        this.MatchedComplexPatterns := []
        matched := this.HandleComplexKey(KeyIdentity.Signature(
            identity), unifiedEvent["phase"],
            this.GetEventDeviceScope(unifiedEvent))
        if !matched
            return false
        return Map("matched", JsonBoolean(true), "consumed_patterns",
            RuleSpec.Clone(this.MatchedComplexPatterns))
    }

    TraceInputEvent(unifiedEvent) {
        identity := unifiedEvent["identity"]
        this.Trace("input_event", {Source: identity["name"],
            Outcome: unifiedEvent["phase"],
            Detail: "VK " identity["vk_hex"] " / SC " identity["sc_hex"],
            Data: unifiedEvent})
    }

    ReleaseComplexKey(normalizedKey, deviceScope := "") {
        deviceScope := this.NormalizeDeviceScope(deviceScope)
        stateKey := deviceScope "|" normalizedKey
        if this.ComplexHeld.Has(stateKey)
            this.ComplexHeld.Delete(stateKey)
        this.RemoveComplexDownOrder(stateKey)
        activeOwners := []
        for ownerKey, active in this.ComplexActiveKeys {
            if active.DeviceScope != deviceScope
                continue
            ruleId := active.RuleId
            descriptor := this.Rules.Has(ruleId) ? this.Rules[ruleId] : ""
            if !IsObject(descriptor)
                continue
            if descriptor.Mode == "simultaneous"
                    && this.DescriptorContainsKey(descriptor, normalizedKey) {
                releasePolicy := descriptor.Spec["from"][
                    "simultaneous_options"]["release"]
                if releasePolicy == "any"
                        || !this.HasHeldDescriptorKey(descriptor, deviceScope)
                    activeOwners.Push(ownerKey)
            }
            else if descriptor.Mode == "sequence"
                    && active.Key == normalizedKey
                activeOwners.Push(ownerKey)
        }
        for ownerKey in activeOwners {
            active := this.ComplexActiveKeys[ownerKey]
            ruleId := active.RuleId
            this.CancelTimers(ownerKey)
            this.CancelActionRepeats(ownerKey)
            this.StateMachine.Release(ownerKey)
            this.ComplexActiveKeys.Delete(ownerKey)
            if this.SimultaneousStarted.Has(ownerKey)
                this.SimultaneousStarted.Delete(ownerKey)
        }
        return activeOwners.Length
    }

    TrySimultaneous(descriptor, now, allowMatch := true, isRepeat := false,
            deviceScope := "") {
        deviceScope := this.NormalizeDeviceScope(deviceScope)
        ownerKey := this.RuleDeviceKey(descriptor.Id, deviceScope)
        if this.SimultaneousStarted.Has(ownerKey) {
            if !isRepeat || !allowMatch || !this.IsEligible(descriptor)
                return false
            this.ExecuteActions(descriptor.Spec["to"], descriptor, "to", true,
                ownerKey)
            this.Trace("rule_matched", {Source: descriptor.Source,
                RuleId: descriptor.Id, Outcome: "simultaneous_repeat"})
            return true
        }
        if isRepeat
            return false
        earliest := now
        latest := 0
        for key in this.GetComplexKeys(descriptor) {
            normalizedKey := RuleCompiler.GetKeyIdentitySignature(key)
            stateKey := deviceScope "|" normalizedKey
            if !this.ComplexHeld.Has(stateKey)
                return false
            tick := this.ComplexHeld[stateKey]
            earliest := Min(earliest, tick)
            latest := Max(latest, tick)
        }
        threshold := this.GetTiming(descriptor)["simultaneous_threshold_ms"]
        if threshold > 0 && this.Elapsed(earliest, latest) > threshold
            return false
        if descriptor.Spec["from"]["simultaneous_options"]["order"]
                == "strict" && !this.MatchesStrictSimultaneousOrder(descriptor,
                    deviceScope)
            return false
        if !allowMatch
            return false
        if !this.IsEligible(descriptor)
            return false
        this.SimultaneousStarted[ownerKey] := true
        if this.StateMachine.Begin(descriptor, "sim:" ownerKey, ownerKey,
                deviceScope) {
            this.RecordMatchedComplexPattern(descriptor)
            this.ComplexActiveKeys[ownerKey] := {RuleId: descriptor.Id,
                DeviceScope: deviceScope, Key: ""}
            this.ScheduleTimers(descriptor, ownerKey)
            this.Trace("rule_matched", {Source: descriptor.Source,
                RuleId: descriptor.Id, Outcome: "simultaneous"})
            return true
        }
        return false
    }

    AdvanceSequence(descriptor, normalizedKey, now, allowMatch := true,
            deviceScope := "") {
        deviceScope := this.NormalizeDeviceScope(deviceScope)
        ownerKey := this.RuleDeviceKey(descriptor.Id, deviceScope)
        if !descriptor.HasOwnProp("SequencePattern")
            this.PrepareSequenceMatcher(descriptor)
        pattern := descriptor.SequencePattern
        prefix := descriptor.SequencePrefix
        state := this.SequenceStates.Has(ownerKey)
            ? this.SequenceStates[ownerKey] : {Index: 1, LastTick: now}
        matchedCount := state.Index - 1
        if state.Index > 1 && this.Elapsed(state.LastTick, now)
                > this.GetTiming(descriptor)["sequence_timeout_ms"]
            matchedCount := 0
        while matchedCount > 0
                && normalizedKey != pattern[matchedCount + 1]
            matchedCount := prefix[matchedCount]
        if normalizedKey == pattern[matchedCount + 1]
            matchedCount++
        state.Index := matchedCount + 1
        state.LastTick := now
        if matchedCount < pattern.Length {
            this.SequenceStates[ownerKey] := state
            return false
        }
        this.SequenceStates[ownerKey] := {
            Index: prefix[pattern.Length] + 1, LastTick: now}
        if !allowMatch
            return false
        if !this.IsEligible(descriptor)
            return false
        if this.StateMachine.Begin(descriptor, "seq:" ownerKey, ownerKey,
                deviceScope) {
            this.RecordMatchedComplexPattern(descriptor)
            this.ComplexActiveKeys[ownerKey] := {RuleId: descriptor.Id,
                DeviceScope: deviceScope, Key: normalizedKey}
            this.ScheduleTimers(descriptor, ownerKey)
            this.Trace("rule_matched", {Source: descriptor.Source,
                RuleId: descriptor.Id, Outcome: "sequence"})
            return true
        }
        return false
    }

    PrepareSequenceMatcher(descriptor) {
        pattern := []
        for key in this.GetComplexKeys(descriptor)
            pattern.Push(RuleCompiler.GetKeyIdentitySignature(key))
        if !pattern.Length
            throw Error("序列规则至少需要一个来源键：" descriptor.Id)
        prefix := [0]
        matchedCount := 0
        index := 2
        while index <= pattern.Length {
            while matchedCount > 0
                    && pattern[index] != pattern[matchedCount + 1]
                matchedCount := prefix[matchedCount]
            if pattern[index] == pattern[matchedCount + 1]
                matchedCount++
            prefix.Push(matchedCount)
            index++
        }
        descriptor.SequencePattern := pattern
        descriptor.SequencePrefix := prefix
        return descriptor
    }

    RecordMatchedComplexPattern(descriptor) {
        pattern := []
        for key in this.GetComplexKeys(descriptor)
            pattern.Push(RuleCompiler.GetKeyIdentitySignature(key))
        if pattern.Length
            this.MatchedComplexPatterns.Push(pattern)
        return pattern.Length
    }

    FindEligibleChain(descriptors, isRepeat := false, deviceScope := "") {
        result := []
        for descriptor in descriptors {
            repeatPolicy := descriptor.Spec["from"]["repeat"]
            if (isRepeat && repeatPolicy == "ignore")
                    || (!isRepeat && repeatPolicy == "only")
                continue
            if !this.IsEligible(descriptor)
                continue
            if !this.IsTapReady(descriptor, isRepeat, deviceScope)
                continue
            result.Push(descriptor)
            if descriptor.StopProcessing
                break
        }
        return result
    }

    IsTapReady(descriptor, isRepeat, deviceScope := "") {
        required := descriptor.Spec["from"]["tap_count"]
        if required <= 1
            return true
        if isRepeat
            return false
        now := A_TickCount
        stateKey := this.RuleDeviceKey(descriptor.Id,
            this.NormalizeDeviceScope(deviceScope))
        state := this.TapStates.Has(stateKey)
            ? this.TapStates[stateKey] : {Count: 0, LastTick: now}
        if state.Count && this.Elapsed(state.LastTick, now)
                > this.GetTiming(descriptor)["multi_tap_timeout_ms"]
            state.Count := 0
        state.Count++
        state.LastTick := now
        if state.Count < required {
            this.TapStates[stateKey] := state
            this.Trace("multi_tap_progress", {RuleId: descriptor.Id,
                Outcome: state.Count "/" required})
            return false
        }
        this.TapStates.Delete(stateKey)
        return true
    }

    MatchesStrictSimultaneousOrder(descriptor, deviceScope := "") {
        deviceScope := this.NormalizeDeviceScope(deviceScope)
        keys := this.GetComplexKeys(descriptor)
        prefix := deviceScope "|"
        expectedIndex := keys.Length
        index := this.ComplexDownOrder.Length
        while index >= 1 && expectedIndex >= 1 {
            stateKey := this.ComplexDownOrder[index]
            index--
            if SubStr(stateKey, 1, StrLen(prefix)) != prefix
                continue
            if stateKey != prefix
                    . RuleCompiler.GetKeyIdentitySignature(keys[expectedIndex])
                return false
            expectedIndex--
        }
        return expectedIndex == 0
    }

    HasHeldDescriptorKey(descriptor, deviceScope := "") {
        deviceScope := this.NormalizeDeviceScope(deviceScope)
        for key in this.GetComplexKeys(descriptor) {
            if this.ComplexHeld.Has(deviceScope "|"
                    . RuleCompiler.GetKeyIdentitySignature(key))
                return true
        }
        return false
    }

    RemoveComplexDownOrder(stateKey) {
        index := this.ComplexDownOrder.Length
        while index >= 1 {
            if this.ComplexDownOrder[index] == stateKey
                this.ComplexDownOrder.RemoveAt(index)
            index--
        }
    }

    GetEventDeviceScope(unifiedEvent) {
        if Type(unifiedEvent) == "Map" && unifiedEvent.Has("identity") {
            identity := unifiedEvent["identity"]
            if Type(identity) == "Map" && identity.Has("device_id")
                return this.NormalizeDeviceScope(identity["device_id"])
        }
        return this.NormalizeDeviceScope("")
    }

    NormalizeDeviceScope(value) {
        value := Trim(String(value))
        return value == "" ? "global" : value
    }

    RuleDeviceKey(ruleId, deviceScope) {
        return String(ruleId) "|" this.NormalizeDeviceScope(deviceScope)
    }

    ReleaseDeviceState(deviceScope, reason := "removal") {
        deviceScope := this.NormalizeDeviceScope(deviceScope)
        if deviceScope == "global"
            return 0
        stateIds := Map()
        for stateId in this.StateMachine.CancelScope(deviceScope)
            stateIds[stateId] := true
        for stateId in this.RepeatActive {
            if this.StateBelongsToDevice(stateId, deviceScope)
                stateIds[stateId] := true
        }
        for stateId, active in this.ComplexActiveKeys {
            if active.DeviceScope == deviceScope
                stateIds[stateId] := true
        }

        releasedOutputs := 0
        for stateId in stateIds {
            this.CancelTimers(stateId)
            this.CancelActionRepeats(stateId)
            releasedOutputs += this.OutputLedger.ReleaseOwner(stateId,
                ObjBindMethod(this, "SendKeyEvent"))
            releasedOutputs += this.OutputLedger.ReleaseOwnerPrefix(
                "one-shot:" stateId ":", ObjBindMethod(this, "SendKeyEvent"))
            releasedOutputs += this.OutputLedger.ReleaseOwnerPrefix(
                "sticky:" stateId ":", ObjBindMethod(this, "SendKeyEvent"))
        }

        this.DeleteMapKeysByPrefix(this.SimpleHeld, deviceScope "|")
        this.DeleteMapKeysByPrefix(this.ComplexHeld, deviceScope "|")
        this.DeleteMapKeysBySuffix(this.SimultaneousStarted,
            "|" deviceScope)
        this.DeleteMapKeysBySuffix(this.SequenceStates, "|" deviceScope)
        this.DeleteMapKeysBySuffix(this.TapStates, "|" deviceScope)
        for stateId in stateIds {
            if this.ComplexActiveKeys.Has(stateId)
                this.ComplexActiveKeys.Delete(stateId)
        }
        index := this.ComplexDownOrder.Length
        while index >= 1 {
            if SubStr(this.ComplexDownOrder[index], 1,
                    StrLen(deviceScope) + 1) == deviceScope "|"
                this.ComplexDownOrder.RemoveAt(index)
            index--
        }
        staleOneShots := []
        for owner in this.OneShotOwners {
            for stateId in stateIds {
                if InStr(owner, ":" stateId ":") {
                    staleOneShots.Push(owner)
                    break
                }
            }
        }
        for owner in staleOneShots
            this.OneShotOwners.Delete(owner)
        this.Trace("device_state_released", {Outcome: String(reason),
            Source: deviceScope, Data: Map("states", stateIds.Count,
                "released_outputs", releasedOutputs)})
        return stateIds.Count + releasedOutputs
    }

    StateBelongsToDevice(stateId, deviceScope) {
        suffix := "|" String(deviceScope)
        stateId := String(stateId)
        return StrLen(stateId) > StrLen(suffix)
            && SubStr(stateId, 1 - StrLen(suffix)) == suffix
    }

    DeleteMapKeysByPrefix(values, prefix) {
        stale := []
        for key in values {
            if SubStr(key, 1, StrLen(prefix)) == prefix
                stale.Push(key)
        }
        for key in stale
            values.Delete(key)
        return stale.Length
    }

    DeleteMapKeysBySuffix(values, suffix) {
        stale := []
        for key in values {
            if StrLen(key) >= StrLen(suffix)
                    && SubStr(key, 1 - StrLen(suffix)) == suffix
                stale.Push(key)
        }
        for key in stale
            values.Delete(key)
        return stale.Length
    }

    IsEligible(descriptor) {
        startedAt := this.ReadPerformanceCounter()
        context := this.BuildContext()
        this.Trace("rule_candidate", {RuleId: descriptor.Id,
            Source: descriptor.Source, Outcome: "evaluating",
            Data: Map("priority", descriptor.Priority,
                "order", descriptor.Order,
                "context", RuleSpec.Clone(context))})
        result := this.ConditionEvaluator.EvaluateAllDetailed(
            descriptor.Spec["conditions"], context)
        decisionData := Map(
            "steps", result.Steps,
            "context", RuleSpec.Clone(context),
            "variables", this.VariableStore.GetSnapshot(
                context.Has("builtin") ? context["builtin"] : ""),
            "duration_us", this.ElapsedMicroseconds(startedAt))
        if !result.Matched {
            this.Trace("condition_rejected", {RuleId: descriptor.Id,
                Outcome: "rejected", Detail: result.Reason,
                Data: decisionData})
            return false
        }
        this.Trace("candidate_accepted", {RuleId: descriptor.Id,
            Source: descriptor.Source, Outcome: "accepted",
            Data: decisionData})
        return true
    }

    ReadPerformanceCounter() {
        value := 0
        try DllCall("QueryPerformanceCounter", "Int64*", &value)
        return value
    }

    ElapsedMicroseconds(startedAt) {
        if !startedAt
            return 0
        completedAt := this.ReadPerformanceCounter()
        frequency := 0
        try DllCall("QueryPerformanceFrequency", "Int64*", &frequency)
        return frequency > 0 && completedAt >= startedAt
            ? Round((completedAt - startedAt) * 1000000 / frequency) : 0
    }

    ResolveTiming(descriptor) {
        return RuleTimingResolver.Resolve(descriptor.Spec["timing"],
            this.GlobalTiming)
    }

    GetTiming(descriptor) {
        return descriptor.HasOwnProp("EffectiveTiming")
            ? descriptor.EffectiveTiming
            : RuleTimingResolver.Resolve(descriptor.Spec["timing"]).Values
    }

    BuildContext() {
        if this.App.HasOwnProp("ContextService")
                && IsObject(this.App.ContextService) {
            devices := []
            try devices := this.App.GetInputDevices()
            eventDevice := ""
            try eventDevice := this.Backend.GetCurrentEventDevice()
            return this.App.ContextService.Build(
                this.VariableStore, devices, eventDevice)
        }
        keyboardLayout := DllCall("user32\GetKeyboardLayout", "UInt", 0,
            "UPtr")
        builtins := Map()
        return Map("application", Map(), "window", Map(),
            "variables", this.VariableStore.BuildContext(builtins),
            "input_source", Format("{:04X}", keyboardLayout & 0xFFFF),
            "session", "active", "builtin", builtins)
    }

    ExecuteActions(actions, descriptor, fieldName, isRepeat := false,
            actionOwner := "") {
        if Type(actions) != "Array" || !actions.Length
            return true
        for actionIndex, action in actions {
            if isRepeat && action["repeat"] == "once"
                continue
            try {
                actionStartedAt := this.ReadPerformanceCounter()
                actionType := action["type"]
                value := action.Has("value") ? action["value"] : ""
                owner := actionOwner == "" ? descriptor.Id : actionOwner
                switch actionType {
                    case "send", "mouse", "text", "app_command", "sleep",
                            "window_minimize", "window_close",
                            "lock_workstation":
                        this.Backend.EmitAction(actionType, value)
                    case "key_down":
                        this.OutputLedger.Press(value,
                            owner,
                            ObjBindMethod(this, "SendKeyEvent"))
                    case "key_up":
                        if this.OutputLedger.HasOwner(value, owner)
                            this.OutputLedger.Release(value, owner,
                                ObjBindMethod(this, "SendKeyEvent"))
                    case "set_variable":
                        this.VariableStore.Set(action["name"], value,
                            action["scope"])
                    case "unset_variable":
                        this.VariableStore.Clear(action["name"],
                            action["scope"])
                    case "switch_layer":
                        this.VariableStore.Set("layer", String(value),
                            "transient")
                    case "one_shot_modifier":
                        modifierOwner := "one-shot:" owner ":" String(value)
                        this.OutputLedger.Press(value, modifierOwner,
                            ObjBindMethod(this, "SendKeyEvent"))
                        this.OneShotOwners[modifierOwner] := String(value)
                    case "sticky_modifier":
                        modifierOwner := "sticky:" owner ":" String(value)
                        if this.OutputLedger.HasOwner(value, modifierOwner)
                            this.OutputLedger.Release(value, modifierOwner,
                                ObjBindMethod(this, "SendKeyEvent"))
                        else
                            this.OutputLedger.Press(value, modifierOwner,
                                ObjBindMethod(this, "SendKeyEvent"))
                    case "run":
                        if !this.AllowRunActions
                            throw Error("run 动作被安全策略阻止。")
                        Run(String(value))
                }
                this.Trace("action_executed", {RuleId: descriptor.Id,
                    Outcome: actionType, Detail: fieldName,
                    Data: Map("action_index", actionIndex,
                        "action", RuleSpec.Clone(action),
                        "variables", this.VariableStore.GetSnapshot(),
                        "duration_us", this.ElapsedMicroseconds(
                            actionStartedAt))})
                if !isRepeat && action["repeat_interval_ms"] > 0
                    this.ScheduleActionRepeat(descriptor, fieldName,
                        actionIndex, action["repeat_interval_ms"], owner)
            } catch as actionError {
                this.Trace("action_failed", {RuleId: descriptor.Id,
                    Outcome: "error", Detail: actionError.Message,
                    Data: Map("action_index", actionIndex,
                        "duration_us", IsSet(actionStartedAt)
                            ? this.ElapsedMicroseconds(actionStartedAt) : 0)})
                return false
            }
        }
        return true
    }

    HasOnceAction(actions) {
        for action in actions {
            if action["repeat"] == "once"
                return true
        }
        return false
    }

    HasFixedRepeatAction(descriptor) {
        for fieldName in RuleSpec.ActionFields {
            for action in descriptor.Spec[fieldName] {
                if action["repeat_interval_ms"] > 0
                    return true
            }
        }
        return false
    }

    ScheduleActionRepeat(descriptor, fieldName, actionIndex, intervalMs,
            stateId := "") {
        if stateId == ""
            stateId := descriptor.Id
        taskId := "repeat:" stateId ":" fieldName ":" actionIndex
        this.Scheduler.Schedule(taskId, intervalMs,
            ObjBindMethod(this, "OnActionRepeat", descriptor.Id,
                fieldName, actionIndex, intervalMs, stateId))
    }

    OnActionRepeat(ruleId, fieldName, actionIndex, intervalMs, stateId,
            taskId := "") {
        if !this.Rules.Has(ruleId)
            return false
        if !this.RepeatActive.Has(stateId)
                && !this.StateMachine.States.Has(stateId)
            return false
        descriptor := this.Rules[ruleId]
        actions := descriptor.Spec[fieldName]
        if actionIndex < 1 || actionIndex > actions.Length
            return false
        if !this.ExecuteActions([actions[actionIndex]], descriptor,
                fieldName, true, stateId) {
            this.CancelActionRepeats(stateId)
            return false
        }
        this.ScheduleActionRepeat(descriptor, fieldName, actionIndex,
            intervalMs, stateId)
        return true
    }

    CancelActionRepeats(stateId) {
        if this.RepeatActive.Has(stateId)
            this.RepeatActive.Delete(stateId)
        return this.Scheduler.CancelPrefix("repeat:" stateId ":")
    }

    ReleasePressedOutputKeys() {
        this.OneShotOwners.Clear()
        return this.OutputLedger.ReleaseAll(
            ObjBindMethod(this, "SendKeyEvent"))
    }

    ResetActiveState(reason := "context_changed") {
        releasedOutputs := 0
        backendReleased := 0
        releaseErrors := []
        try releasedOutputs := this.ReleasePressedOutputKeys()
        catch as outputReleaseError
            releaseErrors.Push("output ledger: " outputReleaseError.Message)
        try backendReleased := this.Backend.ReleaseAll()
        catch as backendReleaseError
            releaseErrors.Push("input backend: " backendReleaseError.Message)
        try this.CancelAllTimers()
        catch as timerCancelError
            releaseErrors.Push("scheduler: " timerCancelError.Message)
        this.RepeatActive.Clear()
        this.OneShotOwners.Clear()
        this.StateMachine.CancelAll()
        this.ComplexHeld.Clear()
        this.SimultaneousStarted.Clear()
        this.SequenceStates.Clear()
        this.ComplexActiveKeys.Clear()
        this.ComplexDownOrder := []
        this.SimpleHeld.Clear()
        this.TapStates.Clear()
        this.Trace("active_state_reset", {Outcome: String(reason),
            Data: Map("released_outputs", releasedOutputs,
                "backend_released", backendReleased,
                "release_errors", releaseErrors)})
        if releaseErrors.Length
            throw Error("活动输入状态清理失败："
                . this.JoinCleanupErrors(releaseErrors))
        return releasedOutputs + backendReleased
    }

    SendKeyEvent(keyName, phase) {
        return this.Backend.EmitAction("key", keyName, phase)
    }

    NeedsState(descriptor) {
        for fieldName in ["to_if_alone", "to_if_held_down",
                "to_if_other_key_pressed",
                "to_after_key_up", "to_delayed_if_invoked",
                "to_delayed_if_canceled"] {
            if descriptor.Spec[fieldName].Length
                return true
        }
        return false
    }

    ScheduleTimers(descriptor, stateId := "") {
        if stateId == ""
            stateId := descriptor.Id
        timing := this.GetTiming(descriptor)
        if descriptor.Spec["to_if_held_down"].Length {
            this.Scheduler.Schedule("held:" stateId,
                timing["held_threshold_ms"],
                ObjBindMethod(this, "OnHeldTimer", stateId))
        }
        if descriptor.Spec["to_delayed_if_invoked"].Length
                || descriptor.Spec["to_delayed_if_canceled"].Length {
            this.Scheduler.Schedule("delayed:" stateId,
                timing["delayed_action_ms"],
                ObjBindMethod(this, "OnDelayedTimer", stateId))
        }
    }

    OnHeldTimer(stateId, *) {
        this.StateMachine.FireHeld(stateId)
    }

    OnDelayedTimer(stateId, *) {
        this.StateMachine.ResolveDelayed(stateId)
    }

    CancelTimers(stateId) {
        return this.Scheduler.Cancel("held:" stateId)
            + this.Scheduler.Cancel("delayed:" stateId) > 0
    }

    CancelAllTimers() {
        this.RepeatActive.Clear()
        return this.Scheduler.CancelAll()
    }

    StartObserver() {
        if IsObject(this.Observer)
            return true
        try {
            if this.Backend.StartObservation(
                    ObjBindMethod(this, "HandleInputEvent")) {
                this.Observer := {BackendOwned: true}
                return true
            }
        } catch as backendObserverError {
            this.Trace("observer_failed", {Outcome: "warning",
                Detail: backendObserverError.Message})
        }
        this.Observer := ""
        return false
    }

    StopObserver() {
        if IsObject(this.Observer) && this.Observer.HasOwnProp("BackendOwned") {
            try this.Backend.StopObservation()
        }
        this.Observer := ""
    }

    ReleaseOneShotModifiers() {
        owners := []
        for owner in this.OneShotOwners
            owners.Push(owner)
        for owner in owners {
            this.OutputLedger.ReleaseOwner(owner,
                ObjBindMethod(this, "SendKeyEvent"))
            this.OneShotOwners.Delete(owner)
        }
        return owners.Length
    }

    GetComplexKeys(descriptor) {
        return descriptor.Mode == "simultaneous"
            ? descriptor.Spec["from"]["simultaneous"]
            : descriptor.Spec["from"]["sequence"]
    }

    DescriptorContainsKey(descriptor, normalizedKey) {
        for key in this.GetComplexKeys(descriptor) {
            if RuleCompiler.GetKeyIdentitySignature(key) == normalizedKey
                return true
        }
        return false
    }

    NormalizeComplexIdentity(identity) {
        identity := StrLower(String(identity))
        if InStr(identity, ":")
            return identity
        return "keyboard:name:" identity
    }

    EnsureHookHotkey(hotkeyName) {
        return InStr(hotkeyName, "$") ? hotkeyName : "$" hotkeyName
    }

    GetPrimaryKeyName(hotkeyName) {
        name := RegExReplace(String(hotkeyName), "[~*$<>^+!#]", "")
        name := RegExReplace(name, "i)\s+Up$")
        return StrLower(Trim(name))
    }

    IsReleasable(hotkeyName) {
        return !RegExMatch(hotkeyName,
            "i)(?:Wheel(?:Up|Down|Left|Right)|MouseMove)$")
    }

    Elapsed(startTick, endTick) {
        return endTick >= startTick ? endTick - startTick
            : (0x100000000 - startTick) + endTick
    }

    TraceState(eventName, descriptor, triggerIdentity) {
        this.Trace(eventName, {RuleId: descriptor.Id,
            Source: descriptor.Source, Outcome: triggerIdentity})
    }

    Trace(eventName, fields := "") {
        try return this.App.TraceEvent("runtime", eventName, fields)
        catch
            return false
    }

    Shutdown() {
        cleanupErrors := []
        this.CollectCleanupError(cleanupErrors, "observer",
            () => this.StopObserver())
        this.CollectCleanupError(cleanupErrors, "active state",
            () => this.ResetActiveState("shutdown"))
        this.CollectCleanupError(cleanupErrors, "input backend",
            () => this.Backend.Shutdown())
        this.CollectCleanupError(cleanupErrors, "scheduler",
            () => this.Scheduler.Shutdown())
        this.Rules.Clear()
        this.Groups.Clear()
        this.ComplexRules := []
        this.ComplexDownOrder := []
        this.SimpleHeld.Clear()
        this.TapStates.Clear()
        if cleanupErrors.Length
            throw Error("托管规则运行时清理失败："
                . this.JoinCleanupErrors(cleanupErrors))
        return true
    }

    CollectCleanupError(errors, label, callback) {
        try callback.Call()
        catch as cleanupError
            errors.Push(String(label) ": " cleanupError.Message)
    }

    JoinCleanupErrors(errors) {
        message := ""
        for cleanupError in errors
            message .= (message == "" ? "" : "；") cleanupError
        return message
    }
}
