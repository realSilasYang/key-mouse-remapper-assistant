class InterceptionMappingRuntime extends DirectHotkeyRuntime {
    static PollIntervalMs := 5
    static MaximumStrokesPerPoll := 64

    __New(app, service) {
        super.__New(app)
        this.Service := service
        this.DeviceRules := Map()
        this.DeviceNumbers := []
        this.HeldByDevice := Map()
        this.PendingStrokesByDevice := Map()
        this.OutputDeviceByKey := Map()
        this.ActiveSources := Map()
        this.SuppressedSources := Map()
        this.CurrentDevice := 0
        this.LastSelectedRuleIds := []
        this.PollTimer := ObjBindMethod(this, "Poll")
        this.UnavailableCallbackTimer := ObjBindMethod(this,
            "NotifyRuntimeUnavailable")
        this.UnavailableCallbackPending := false
        this.ContextActive := false
    }

    ApplyMappings(mappings) {
        if Type(mappings) != "Array"
            throw TypeError("Interception rules must be an array.")
        rules := Map()
        deviceRules := Map()
        deviceNumbers := []
        seenDevices := Map()
        for order, mapping in mappings {
            descriptor := mapping.HasOwnProp("Descriptor")
                ? mapping.Descriptor : RuleCompiler.Compile(mapping.Spec)
            descriptor.Order := order
            if !descriptor.Enabled
                continue
            if rules.Has(descriptor.Id)
                throw Error("Interception 规则名称重复：" descriptor.Id)
            this.ValidateDescriptor(descriptor)
            deviceNumber := descriptor.Spec["from"]["device"]["number"]
            if !deviceRules.Has(deviceNumber)
                deviceRules[deviceNumber] := []
            deviceRules[deviceNumber].Push(descriptor.Id)
            if !seenDevices.Has(deviceNumber) {
                seenDevices[deviceNumber] := true
                deviceNumbers.Push(deviceNumber)
            }
            rules[descriptor.Id] := descriptor
        }
        for deviceNumber, ruleIds in deviceRules
            this.SortRuleIds(ruleIds, rules)

        this.StopContext()
        this.CancelAllActive()
        this.HeldByDevice.Clear()
        this.ActiveSources.Clear()
        this.SuppressedSources.Clear()
        this.Rules := rules
        this.DeviceRules := deviceRules
        this.DeviceNumbers := deviceNumbers
        if !this.Suspended && rules.Count {
            try this.StartContext()
            catch as startError {
                this.Rules := Map()
                this.DeviceRules := Map()
                this.DeviceNumbers := []
                this.Trace("interception_start_failed", {
                    Outcome: "error", Detail: startError.Message})
                this.Rules := rules
                this.DeviceRules := deviceRules
                this.DeviceNumbers := deviceNumbers
                this.ScheduleUnavailableNotification()
                return {Applied: rules.Count, Registrations: deviceRules.Count,
                    Issues: [{Severity: "error", Code: "interception-unavailable",
                        RuleIds: this.GetRuleIds(rules),
                        Message: startError.Message}],
                    Capabilities: this.GetCapabilities()}
            }
        }
        return {Applied: rules.Count, Registrations: deviceRules.Count,
            Issues: [], Capabilities: this.GetCapabilities()}
    }

    ValidateDescriptor(descriptor) {
        from := descriptor.Spec["from"]
        if !from.Has("device")
                || from["device"].Get("backend", "") != "interception"
            throw Error("设备规则缺少 from.device interception 条件。")
        if !from.Has("key") && !from.Get("simultaneous", []).Length
            throw Error("Interception 设备规则必须指定 key 或 simultaneous。")
        if from.Get("repeat", "allow") == "only"
            throw Error("Interception 设备规则暂不支持 repeat=only。")
        if descriptor.Spec.Get("to_if_alone", []).Length
                || descriptor.Spec.Get("to_if_held_down", []).Length
            throw Error("Interception 设备规则暂不支持短按/长按分支。")
        return true
    }

    GetRuleIds(rules) {
        ids := []
        for ruleId in rules
            ids.Push(ruleId)
        return ids
    }

    StartContext() {
        if this.ContextActive || !this.Rules.Count
            return false
        this.Service.StartRuntime(this.DeviceNumbers)
        this.ContextActive := true
        SetTimer(this.PollTimer, InterceptionMappingRuntime.PollIntervalMs)
        return true
    }

    ScheduleUnavailableNotification() {
        if this.UnavailableCallbackPending
            return false
        this.UnavailableCallbackPending := true
        SetTimer(this.UnavailableCallbackTimer, -20)
        return true
    }

    NotifyRuntimeUnavailable(*) {
        this.UnavailableCallbackPending := false
        if !this.Rules.Count || !IsObject(this.App)
            return false
        try ObjBindMethod(this.App,
            "OnInterceptionRuntimeUnavailable").Call()
        catch as notifyError
            this.Trace("interception_unavailable_notification_failed", {
                Outcome: "error", Detail: notifyError.Message})
        return true
    }

    StopContext() {
        SetTimer(this.PollTimer, 0)
        this.FlushAllPendingStrokes()
        wasActive := this.ContextActive
        this.ContextActive := false
        if wasActive
            this.Service.StopRuntime()
        return wasActive
    }

    Poll(*) {
        if this.Suspended || !this.ContextActive
            return false
        Loop InterceptionMappingRuntime.MaximumStrokesPerPoll {
            try stroke := this.Service.PollRuntime(0)
            catch as pollError {
                this.Trace("interception_poll_failed", {Outcome: "error",
                    Detail: pollError.Message})
                this.StopContext()
                return false
            }
            if !IsObject(stroke)
                break
            try this.ProcessStroke(stroke)
            catch as strokeError {
                this.Trace("interception_stroke_failed", {Outcome: "error",
                    Detail: strokeError.Message})
                currentWasQueued := this.HasPendingStroke(
                    stroke["device"], stroke)
                try this.FlushPendingStrokes(stroke["device"])
                if !currentWasQueued
                    try this.Service.SendRuntimeStroke(stroke)
            }
        }
        return true
    }

    ProcessStroke(stroke) {
        events := this.DecodeStroke(stroke)
        if !events.Length {
            this.FlushPendingStrokes(stroke["device"])
            return this.Service.SendRuntimeStroke(stroke)
        }
        suppress := false
        currentStrokeQueued := false
        for event in events
        {
            deviceNumber := stroke["device"]
            identity := event["identity"]
            signature := KeyIdentity.Signature(identity)
            wasStagedDown := event["phase"] == "up"
                && this.HasPendingDown(deviceNumber, signature)
            eventSuppress := this.ProcessEvent(deviceNumber, event)
            suppress := eventSuppress || suppress
            matchedRule := this.LastSelectedRuleIds.Length > 0
            if !matchedRule && (wasStagedDown
                    || (event["phase"] == "down"
                        && this.ShouldStageModifier(deviceNumber, identity))) {
                this.QueuePendingStroke(deviceNumber, stroke, identity,
                    event["phase"])
                currentStrokeQueued := true
                if (event["phase"] == "up" && wasStagedDown)
                        || !this.HasPotentialModifierPrefix(deviceNumber)
                    this.FlushPendingStrokes(deviceNumber)
            } else if this.PendingStrokesByDevice.Has(deviceNumber) {
                ; A non-prefix event ends the opportunity to form a chord.
                ; Forward queued physical strokes before this one.
                this.FlushPendingStrokes(deviceNumber)
            }
        }
        if !suppress && !currentStrokeQueued
            this.Service.SendRuntimeStroke(stroke)
        return suppress
    }

    DecodeStroke(stroke) {
        deviceNumber := stroke["device"]
        device := Map("id", "interception:" deviceNumber,
            "handle", "interception:" deviceNumber,
            "usage_page", 1, "usage", stroke["type"] == "keyboard" ? 6 : 2)
        if stroke["type"] == "keyboard" {
            state := stroke["state"]
            code := stroke["code"]
            mapCode := code | ((state & 0x02) ? 0xE000
                : ((state & 0x04) ? 0xE100 : 0))
            vk := DllCall("user32\MapVirtualKeyW", "UInt", mapCode,
                "UInt", 3, "UInt")
            identity := KeyIdentity.FromRawKeyboard(vk, code,
                state & 0x06, device)
            return [InputEvent.Create(identity,
                (state & 0x01) ? "up" : "down", false, false,
                "interception")]
        }
        definitions := [
            [0x001, "LButton", "down"], [0x002, "LButton", "up"],
            [0x004, "RButton", "down"], [0x008, "RButton", "up"],
            [0x010, "MButton", "down"], [0x020, "MButton", "up"],
            [0x040, "XButton1", "down"], [0x080, "XButton1", "up"],
            [0x100, "XButton2", "down"], [0x200, "XButton2", "up"]]
        events := []
        state := stroke["state"]
        for definition in definitions
            if state & definition[1]
                events.Push(InputEvent.Create(KeyIdentity.FromRawPointer(
                    definition[2], device), definition[3], false, false,
                    "interception"))
        if state & 0x400
            events.Push(InputEvent.Create(KeyIdentity.FromRawPointer(
                stroke["rolling"] > 0 ? "WheelUp" : "WheelDown", device),
                "wheel", false, false, "interception"))
        if state & 0x800
            events.Push(InputEvent.Create(KeyIdentity.FromRawPointer(
                stroke["rolling"] > 0 ? "WheelRight" : "WheelLeft", device),
                "wheel", false, false, "interception"))
        return events
    }

    ProcessEvent(deviceNumber, event) {
        identity := event["identity"]
        phase := event["phase"]
        token := deviceNumber "|" KeyIdentity.Signature(identity)
        held := this.GetHeldMap(deviceNumber)
        wasHeld := held.Has(KeyIdentity.Signature(identity))
        if phase == "down"
            held[KeyIdentity.Signature(identity)] := identity
        this.CurrentDevice := deviceNumber
        this.LastSelectedRuleIds := []
        try {
            if phase == "up"
                return this.ProcessUp(deviceNumber, identity, token, held)
            if phase != "down" && phase != "wheel"
                return false
            this.CancelAloneForOtherInput(event)
            return this.ProcessDown(deviceNumber, identity, token,
                phase == "down" && wasHeld)
        } finally {
            this.CurrentDevice := 0
            if phase == "up" && held.Has(KeyIdentity.Signature(identity))
                held.Delete(KeyIdentity.Signature(identity))
        }
    }

    ProcessDown(deviceNumber, identity, token, isRepeat) {
        selection := this.SelectRules(deviceNumber, identity, "down", isRepeat)
        this.LastSelectedRuleIds := selection
        if selection.Length && this.PendingStrokesByDevice.Has(deviceNumber)
            this.ResolvePendingStrokesForSelection(deviceNumber, selection)
        suppress := this.SuppressedSources.Has(token)
        for ruleId in selection {
            descriptor := this.Rules[ruleId]
            if !descriptor.Spec.Get("passthrough", JsonBoolean(false)).Value
                suppress := true
            if !isRepeat
                this.ActiveSources[ruleId] := token
            this.HandleDown(ruleId, isRepeat, true)
        }
        if suppress && !isRepeat
            this.SuppressedSources[token] := true
        return suppress
    }

    ProcessUp(deviceNumber, identity, token, held) {
        suppress := this.SuppressedSources.Has(token)
        selection := this.SelectRules(deviceNumber, identity, "up", false)
        this.LastSelectedRuleIds := selection
        if selection.Length && this.PendingStrokesByDevice.Has(deviceNumber)
            this.ResolvePendingStrokesForSelection(deviceNumber, selection)
        releaseIds := []
        for ruleId, activeToken in this.ActiveSources {
            if activeToken == token {
                releaseIds.Push(ruleId)
                continue
            }
            if InStr(activeToken, deviceNumber "|") != 1
                    || !this.Rules.Has(ruleId)
                continue
            from := this.Rules[ruleId].Spec["from"]
            for sourceKey in from.Get("simultaneous", [])
                if this.KeyMatchesIdentity(sourceKey, identity) {
                    releaseIds.Push(ruleId)
                    break
                }
        }
        for ruleId in releaseIds {
            this.OnUp(ruleId)
            this.ActiveSources.Delete(ruleId)
        }
        for ruleId in selection {
            descriptor := this.Rules[ruleId]
            if !descriptor.Spec.Get("passthrough", JsonBoolean(false)).Value
                suppress := true
            this.HandleUpOnly(ruleId, true)
        }
        if this.SuppressedSources.Has(token)
            this.SuppressedSources.Delete(token)
        return suppress
    }

    SelectRules(deviceNumber, identity, phase, isRepeat) {
        selected := []
        if !this.DeviceRules.Has(deviceNumber)
            return selected
        context := ""
        contextLoaded := false
        for ruleId in this.DeviceRules[deviceNumber] {
            descriptor := this.Rules[ruleId]
            from := descriptor.Spec["from"]
            if from.Get("event", "down") != phase
                    || !this.PrimaryMatches(from, identity)
                    || !this.MatchesSourceState(from, deviceNumber)
                continue
            repeatPolicy := from.Get("repeat", "allow")
            if isRepeat && repeatPolicy == "ignore" {
                if this.Active.Has(ruleId)
                    selected.Push(ruleId)
                if descriptor.StopProcessing
                    break
                continue
            }
            if !this.MatchesSelectionContext(descriptor, &context,
                    &contextLoaded)
                continue
            selected.Push(ruleId)
            if descriptor.StopProcessing
                break
        }
        return selected
    }

    PrimaryMatches(from, identity) {
        key := from.Has("key") ? from["key"]
            : from["simultaneous"][RuleCompiler.GetSimultaneousPrimaryIndex(
                from["simultaneous"])]
        return this.KeyMatchesIdentity(key, identity)
    }

    MatchesSourceState(from, deviceNumber) {
        held := this.GetHeldMap(deviceNumber)
        for key in from.Get("simultaneous", [])
            if !this.HeldContainsKey(held, key)
                return false
        required := from.Get("modifiers", [])
        for modifier in required
            if !this.HeldContainsModifier(held, modifier)
                return false
        optional := from.Get("optional_modifiers", [])
        if this.ArrayContains(optional, "any")
            return true
        for signature, identity in held {
            if this.GetModifierFamily(identity["name"]) == ""
                continue
            if this.ModifierListContains(required, identity["name"])
                    || this.ModifierListContains(optional, identity["name"])
                continue
            key := from.Has("key") ? from["key"] : Map()
            if key.Count && this.KeyMatchesIdentity(key, identity)
                continue
            return false
        }
        return true
    }

    MatchesSimultaneousSource(descriptor) {
        return !this.CurrentDevice
            || this.MatchesSourceState(descriptor.Spec["from"],
                this.CurrentDevice)
    }

    KeyMatchesIdentity(key, identity) {
        if key.Has("sc") && key["sc"] != ""
            return Integer("0x" key["sc"]) == identity.Get("sc", 0)
        if key.Has("vk") && key["vk"] != ""
            return Integer("0x" key["vk"]) == identity.Get("vk", 0)
        expected := String(key["name"])
        actual := String(identity["name"])
        if this.IsGenericModifier(expected)
            return this.GetModifierFamily(expected)
                == this.GetModifierFamily(actual)
        return StrLower(expected) == StrLower(actual)
    }

    HeldContainsKey(held, key) {
        for signature, identity in held
            if this.KeyMatchesIdentity(key, identity)
                return true
        return false
    }

    HeldContainsModifier(held, modifier) {
        for signature, identity in held
            if this.ModifierNameMatches(modifier, identity["name"])
                return true
        return false
    }

    ModifierListContains(values, actualName) {
        for value in values
            if this.ModifierNameMatches(value, actualName)
                return true
        return false
    }

    ModifierNameMatches(expected, actual) {
        if this.IsGenericModifier(expected)
            return this.GetModifierFamily(expected)
                == this.GetModifierFamily(actual)
        expectedIdentity := this.GetSidedModifierIdentity(expected)
        actualIdentity := this.GetSidedModifierIdentity(actual)
        return expectedIdentity != "" && expectedIdentity == actualIdentity
    }

    GetSidedModifierIdentity(value) {
        value := StrLower(String(value))
        family := this.GetModifierFamily(value)
        if family == ""
            return ""
        side := SubStr(value, 1, 1)
        if side != "l" && side != "r"
            return family
        return side ":" family
    }

    IsGenericModifier(value) {
        return Map("ctrl", true, "shift", true, "alt", true, "win", true)
            .Has(StrLower(String(value)))
    }

    GetModifierFamily(value) {
        value := StrLower(String(value))
        if InStr(value, "ctrl") || InStr(value, "control")
            return "ctrl"
        if InStr(value, "shift")
            return "shift"
        if InStr(value, "alt") || InStr(value, "menu")
            return "alt"
        if InStr(value, "win")
            return "win"
        return ""
    }

    ArrayContains(values, expected) {
        for value in values
            if StrLower(String(value)) == StrLower(String(expected))
                return true
        return false
    }

    GetHeldMap(deviceNumber) {
        if !this.HeldByDevice.Has(deviceNumber)
            this.HeldByDevice[deviceNumber] := Map()
        return this.HeldByDevice[deviceNumber]
    }

    ShouldStageModifier(deviceNumber, identity) {
        if !this.DeviceRules.Has(deviceNumber)
                || this.GetModifierFamily(identity["name"]) == ""
            return false
        for ruleId in this.DeviceRules[deviceNumber] {
            from := this.Rules[ruleId].Spec["from"]
            if from.Get("event", "down") != "down"
                    || this.SourcePrimaryMatchesIdentity(from, identity)
                continue
            for modifier in this.GetRequiredModifierNames(from)
                if this.ModifierNameMatches(modifier, identity["name"])
                    return true
        }
        return false
    }

    SourcePrimaryMatchesIdentity(from, identity) {
        key := from.Has("key") ? from["key"]
            : from["simultaneous"][RuleCompiler.GetSimultaneousPrimaryIndex(
                from["simultaneous"])]
        return this.KeyMatchesIdentity(key, identity)
    }

    GetRequiredModifierNames(from) {
        names := []
        for modifier in from.Get("modifiers", [])
            names.Push(String(modifier))
        for key in from.Get("simultaneous", []) {
            if Type(key) != "Map" || !key.Has("name")
                continue
            name := String(key["name"])
            if this.GetModifierFamily(name) != ""
                names.Push(name)
        }
        return names
    }

    QueuePendingStroke(deviceNumber, stroke, identity, phase) {
        if !this.PendingStrokesByDevice.Has(deviceNumber)
            this.PendingStrokesByDevice[deviceNumber] := []
        this.PendingStrokesByDevice[deviceNumber].Push({Stroke: stroke,
            Signature: KeyIdentity.Signature(identity), Identity: identity,
            Phase: phase})
        return true
    }

    HasPendingDown(deviceNumber, signature) {
        if !this.PendingStrokesByDevice.Has(deviceNumber)
            return false
        heldPending := false
        for pending in this.PendingStrokesByDevice[deviceNumber]
            if pending.Signature == signature
                heldPending := pending.Phase == "down"
        return heldPending
    }

    HasPotentialModifierPrefix(deviceNumber) {
        if !this.DeviceRules.Has(deviceNumber)
                || !this.PendingStrokesByDevice.Has(deviceNumber)
            return false
        held := this.GetHeldMap(deviceNumber)
        optionalAny := false
        for ruleId in this.DeviceRules[deviceNumber] {
            from := this.Rules[ruleId].Spec["from"]
            if from.Get("event", "down") != "down"
                continue
            required := this.GetRequiredModifierNames(from)
            if !required.Length
                continue
            optional := from.Get("optional_modifiers", [])
            optionalAny := this.ArrayContains(optional, "any")
            hasStagedRequiredModifier := false
            viable := true
            for signature, identity in held {
                if this.GetModifierFamily(identity["name"]) == ""
                    continue
                requiredMatch := this.ModifierListContains(required,
                    identity["name"])
                if requiredMatch && this.HasPendingDown(deviceNumber,
                        signature)
                    hasStagedRequiredModifier := true
                if !requiredMatch && !optionalAny
                        && !this.ModifierListContains(optional,
                            identity["name"]) {
                    viable := false
                    break
                }
            }
            if viable && hasStagedRequiredModifier
                return true
        }
        return false
    }

    ResolvePendingStrokesForSelection(deviceNumber, ruleIds) {
        if !this.PendingStrokesByDevice.Has(deviceNumber)
            return false
        consumed := Map()
        held := this.GetHeldMap(deviceNumber)
        for ruleId in ruleIds {
            descriptor := this.Rules[ruleId]
            if descriptor.Spec.Get("passthrough", JsonBoolean(false)).Value
                continue
            required := this.GetRequiredModifierNames(
                descriptor.Spec["from"])
            for signature, identity in held {
                if this.GetModifierFamily(identity["name"]) == ""
                        || !this.ModifierListContains(required,
                            identity["name"])
                        || !this.HasPendingDown(deviceNumber, signature)
                    continue
                consumed[signature] := true
            }
        }
        pending := this.PendingStrokesByDevice[deviceNumber]
        for stroke in pending {
            if consumed.Has(stroke.Signature)
                continue
            if stroke.HasOwnProp("Forwarded") && stroke.Forwarded
                continue
            if !this.Service.SendRuntimeStroke(stroke.Stroke)
                throw Error("Interception 无法回送暂存的输入 stroke。")
            stroke.Forwarded := true
        }
        this.PendingStrokesByDevice.Delete(deviceNumber)
        for signature in consumed
            this.SuppressedSources[deviceNumber "|" signature] := true
        return true
    }

    FlushPendingStrokes(deviceNumber) {
        if !this.PendingStrokesByDevice.Has(deviceNumber)
            return false
        pending := this.PendingStrokesByDevice[deviceNumber]
        for stroke in pending {
            if stroke.HasOwnProp("Forwarded") && stroke.Forwarded
                continue
            if !this.Service.SendRuntimeStroke(stroke.Stroke)
                throw Error("Interception 无法回送暂存的输入 stroke。")
            stroke.Forwarded := true
        }
        this.PendingStrokesByDevice.Delete(deviceNumber)
        return true
    }

    HasPendingStroke(deviceNumber, stroke) {
        if !this.PendingStrokesByDevice.Has(deviceNumber)
            return false
        for pending in this.PendingStrokesByDevice[deviceNumber]
            if pending.Stroke == stroke
                return true
        return false
    }

    FlushAllPendingStrokes() {
        deviceNumbers := []
        for deviceNumber in this.PendingStrokesByDevice
            deviceNumbers.Push(deviceNumber)
        for deviceNumber in deviceNumbers
            this.FlushPendingStrokes(deviceNumber)
        return deviceNumbers.Length
    }

    CancelAloneForOtherInput(event) {
        if !this.Active.Count
            return 0
        forwarded := RuleSpec.Clone(event)
        forwarded["origin"] := "raw-input"
        return this.ObserveInputEvent(forwarded)
    }

    Suspend() {
        if this.Suspended
            return false
        this.Suspended := true
        this.StopContext()
        this.CancelAllActive()
        this.HeldByDevice.Clear()
        this.ActiveSources.Clear()
        this.SuppressedSources.Clear()
        return true
    }

    Resume() {
        if !this.Suspended
            return false
        this.Suspended := false
        try this.StartContext()
        catch as resumeError {
            this.Suspended := true
            throw resumeError
        }
        return true
    }

    RecoverAfterResume() {
        return this.EnsureRunning("resume")
    }

    EnsureRunning(reason := "lifecycle") {
        if this.Suspended
            return true
        this.FlushAllPendingStrokes()
        cleaned := this.CancelAllActive()
        this.HeldByDevice.Clear()
        this.ActiveSources.Clear()
        this.SuppressedSources.Clear()
        if !this.Rules.Count
            return cleaned
        try {
            if !this.ContextActive
                this.StartContext()
            else
                SetTimer(this.PollTimer,
                    InterceptionMappingRuntime.PollIntervalMs)
        } catch as ensureError {
            this.ScheduleUnavailableNotification()
            this.Trace("interception_runtime_recovery_failed", {
                Outcome: "error", Detail: ensureError.Message,
                Data: Map("reason", reason)})
            return false
        }
        this.Trace("interception_runtime_recovered", {
            Outcome: "ok", Data: Map("reason", reason,
                "devices", this.DeviceNumbers.Length)})
        return cleaned
    }

    GetCapabilities() {
        return Map("backend", "interception",
            "available", JsonBoolean(this.ContextActive),
            "device_filtering", JsonBoolean(true),
            "suppresses_original_input", JsonBoolean(true),
            "recording", JsonBoolean(true))
    }

    Shutdown() {
        SetTimer(this.UnavailableCallbackTimer, 0)
        this.UnavailableCallbackPending := false
        this.StopContext()
        cleaned := this.CancelAllActive()
        SetTimer(this.OutputCleanupTimer, 0)
        this.Rules.Clear()
        this.DeviceRules.Clear()
        this.DeviceNumbers := []
        this.PendingStrokesByDevice.Clear()
        this.OutputDeviceByKey.Clear()
        return cleaned
    }

    SendKeyEvent(keyName, phase) {
        keyName := String(keyName)
        phase := StrLower(String(phase))
        isWinKey := keyName == "LWin" || keyName == "RWin"
        if isWinKey && this.Service.HasMethod("SendRuntimeKey") {
            deviceNumber := 0
            if phase == "up" && this.OutputDeviceByKey.Has(keyName)
                deviceNumber := this.OutputDeviceByKey[keyName]
            if !deviceNumber && this.CurrentDevice
                deviceNumber := this.CurrentDevice
            runtimeActive := !this.Service.HasOwnProp("ConsumerMode")
                || this.Service.ConsumerMode == "runtime"
            if deviceNumber && runtimeActive {
                if phase == "down" && !this.OutputDeviceByKey.Has(keyName)
                    this.OutputDeviceByKey[keyName] := deviceNumber
                result := this.Service.SendRuntimeKey(deviceNumber, keyName,
                    phase)
                if !result
                    throw Error("Interception 无法发送输出按键 " keyName " " phase "。")
                if phase == "up" && this.OutputDeviceByKey.Has(keyName)
                    this.OutputDeviceByKey.Delete(keyName)
                return true
            }
        }
        result := super.SendKeyEvent(keyName, phase)
        if phase == "up" && this.OutputDeviceByKey.Has(keyName)
            this.OutputDeviceByKey.Delete(keyName)
        return result
    }
}
