class RawInputBackend extends IInputBackend {
    __New(targetHwnd, eventCallback := "", service := "") {
        if !targetHwnd && !IsObject(service)
            throw ValueError("Raw Input 后端需要有效的目标窗口。")
        if eventCallback != "" && !IsObject(eventCallback)
            throw TypeError("Raw Input 后端事件回调无效。")
        this.EventCallback := eventCallback
        this.Registrations := []
        this.SimpleIndex := Map()
        this.ObserverCallback := ""
        this.CurrentEventDevice := ""
        this.HeldModifiers := Map()
        this.HeldModifierEvents := Map()
        this.Suspended := false
        this.RawInput := IsObject(service) ? service
            : RawInputService(targetHwnd, ObjBindMethod(this, "OnRawInput"))
    }

    GetBackendId() => "raw-input"

    static Describe() {
        return Map(
            "backend", "raw-input",
            "display_name", "Windows Raw Input",
            "available", JsonBoolean(true),
            "activation", "active",
            "requires_driver", JsonBoolean(false),
            "suppresses_simple_hotkeys", JsonBoolean(false),
            "suppresses_sequence_prefixes", JsonBoolean(false),
            "suppresses_simultaneous_prefixes", JsonBoolean(false),
            "device_identification", JsonBoolean(true),
            "device_specific_suppression", JsonBoolean(false),
            "raw_input_hook_correlation", JsonBoolean(false),
            "secure_desktop", JsonBoolean(false),
            "virtual_hid", JsonBoolean(false),
            "nkro_keyboard", JsonBoolean(false),
            "consumer_control", JsonBoolean(false),
            "reason", "Raw Input 可区分实体设备，但不会阻止原始输入。")
    }

    GetCapabilities() => RawInputBackend.Describe()

    Start() => this.RawInput.Start()

    Stop() {
        this.ClearPhysicalState()
        return this.RawInput.Stop()
    }

    Replace(registrations) {
        if Type(registrations) != "Array"
            throw TypeError("Raw Input 注册计划必须是数组。")
        plan := this.BuildPlan(registrations)
        this.Registrations := registrations.Clone()
        this.SimpleIndex := plan.SimpleIndex
        this.ClearPhysicalState()
        return this.Registrations.Length
    }

    BuildPlan(registrations) {
        simpleIndex := Map()
        for registration in registrations {
            if !registration.HasOwnProp("Kind")
                throw Error("Raw Input 后端收到缺少类型的注册项。")
            if registration.Kind == "simple" {
                if !registration.HasOwnProp("Triggers")
                        || Type(registration.Triggers) != "Array"
                        || !registration.Triggers.Length
                    throw Error("Raw Input 后端无法解析缺少 from.key 的规则。")
                for trigger in registration.Triggers
                    this.IndexRegistration(simpleIndex, trigger["key"],
                        registration)
            } else
                throw Error("Raw Input 后端收到未知注册类型："
                    registration.Kind)
        }
        return {SimpleIndex: simpleIndex}
    }

    IndexRegistration(index, key, registration) {
        for signature in RawInputKeyMatcher.GetRuleSignatures(key) {
            if !index.Has(signature)
                index[signature] := []
            index[signature].Push(registration)
        }
    }

    StartObservation(callback) {
        if !IsObject(callback)
            throw TypeError("Raw Input 规则观察回调无效。")
        this.ObserverCallback := callback
        return true
    }

    StopObservation() {
        changed := IsObject(this.ObserverCallback)
        this.ObserverCallback := ""
        return changed
    }

    OnRawInput(unifiedEvent) {
        try {
            if IsObject(this.EventCallback)
                this.EventCallback.Call(unifiedEvent)
        }
        if Type(unifiedEvent) != "Map"
                || !unifiedEvent.Has("identity")
                || !unifiedEvent.Has("phase")
            return false

        if unifiedEvent["origin"] == "raw-input-device"
            return this.HandleDeviceLifecycle(unifiedEvent)
        if this.Suspended || unifiedEvent["origin"] != "raw-input"
            return false

        identity := unifiedEvent["identity"]
        deviceId := identity.Has("device_id")
            ? String(identity["device_id"]) : ""
        if deviceId == ""
            return false

        phase := unifiedEvent["phase"]
        dispatchEvent := unifiedEvent
        momentary := phase == "wheel" || phase == "move"
        if momentary {
            dispatchEvent := RuleSpec.Clone(unifiedEvent)
            dispatchEvent["phase"] := "down"
        }
        eventKey := deviceId "|" KeyIdentity.Signature(identity)
        if dispatchEvent["phase"] == "down"
            this.UpdateHeldModifier(identity, true, eventKey)
        this.CurrentEventDevice := this.RawInput.FindDevice(deviceId)
        try {
            complexMatched := false
            if IsObject(this.ObserverCallback)
                complexMatched := this.ReadMatchedResult(
                    this.ObserverCallback.Call(dispatchEvent))
            simpleMatched := this.DispatchSimple(dispatchEvent)
            return complexMatched || simpleMatched
        } finally {
            if dispatchEvent["phase"] == "up" || momentary
                this.UpdateHeldModifier(identity, false, eventKey)
            this.CurrentEventDevice := ""
        }
    }

    HandleDeviceLifecycle(unifiedEvent) {
        identity := unifiedEvent["identity"]
        deviceId := identity.Has("device_id")
            ? String(identity["device_id"]) : ""
        lifecycle := unifiedEvent.Has("metadata")
                && unifiedEvent["metadata"].Has("lifecycle")
            ? unifiedEvent["metadata"]["lifecycle"] : unifiedEvent["phase"]
        if deviceId == "" || (unifiedEvent["phase"] != "removal"
                && lifecycle != "rebound")
            return false
        this.ClearDevicePhysicalState(deviceId)
        if IsObject(this.ObserverCallback)
            this.ObserverCallback.Call(unifiedEvent)
        return false
    }

    ReadMatchedResult(value) {
        if Type(value) == "Map" {
            if !value.Has("matched")
                throw TypeError("Raw Input 规则回调结果缺少 matched。")
            value := value["matched"]
        }
        if value is JsonBoolean
            return value.Value
        if !IsObject(value) && (value == 0 || value == 1)
            return !!value
        throw TypeError("Raw Input 规则回调必须返回布尔结果。")
    }

    DispatchSimple(unifiedEvent) {
        matched := false
        for registration in this.FindIndexed(this.SimpleIndex,
                unifiedEvent["identity"]) {
            if registration.Phase != unifiedEvent["phase"]
                    || !this.RegistrationModifiersMatch(registration,
                        unifiedEvent["identity"])
                continue
            if registration.Callback.Call(unifiedEvent)
                matched := true
        }
        return matched
    }

    RegistrationModifiersMatch(registration, primaryIdentity) {
        for trigger in registration.Triggers {
            if !RawInputKeyMatcher.RuleMatchesIdentity(trigger["key"],
                    primaryIdentity)
                continue
            required := Map()
            for modifier in trigger["modifiers"]
                required[RawInputKeyMatcher.NormalizeModifierName(
                    modifier)] := true
            actual := Map()
            primaryName := RawInputKeyMatcher.NormalizeModifierName(
                primaryIdentity["name"])
            devicePrefix := String(primaryIdentity["device_id"]) "|"
            for physicalModifier in this.HeldModifiers {
                if SubStr(physicalModifier, 1, StrLen(devicePrefix))
                        != devicePrefix
                    continue
                modifier := SubStr(physicalModifier, StrLen(devicePrefix) + 1)
                if modifier != primaryName
                    actual[modifier] := true
            }
            matchedActual := Map()
            allRequired := true
            for modifier in required {
                matchedModifier := ""
                for candidate in RawInputKeyMatcher.GetModifierCandidates(
                        modifier) {
                    if actual.Has(candidate) && !matchedActual.Has(candidate) {
                        matchedModifier := candidate
                        break
                    }
                }
                if matchedModifier == "" {
                    allRequired := false
                    break
                }
                matchedActual[matchedModifier] := true
            }
            if !allRequired
                continue
            allowExtra := RawInputKeyMatcher.ReadBoolean(
                trigger["allow_extra_modifiers"])
            if allowExtra || actual.Count == matchedActual.Count
                return true
        }
        return false
    }

    FindIndexed(index, identity) {
        result := []
        seen := Map()
        for signature in RawInputKeyMatcher.GetIdentitySignatures(identity) {
            if !index.Has(signature)
                continue
            for registration in index[signature] {
                pointer := ObjPtr(registration)
                if seen.Has(pointer)
                    continue
                seen[pointer] := true
                result.Push(registration)
            }
        }
        return result
    }

    UpdateHeldModifier(identity, held, eventKey) {
        name := RawInputKeyMatcher.NormalizeModifierName(identity["name"])
        if !RawInputKeyMatcher.IsModifier(name)
            return
        physicalModifier := String(identity["device_id"]) "|" name
        if held {
            if this.HeldModifierEvents.Has(eventKey)
                return
            this.HeldModifierEvents[eventKey] := physicalModifier
            this.HeldModifiers[physicalModifier] := this.HeldModifiers.Get(
                physicalModifier, 0) + 1
            return
        }
        if !this.HeldModifierEvents.Has(eventKey)
            return
        trackedName := this.HeldModifierEvents[eventKey]
        this.HeldModifierEvents.Delete(eventKey)
        count := this.HeldModifiers.Get(trackedName, 0) - 1
        if count > 0
            this.HeldModifiers[trackedName] := count
        else if this.HeldModifiers.Has(trackedName)
            this.HeldModifiers.Delete(trackedName)
    }

    ClearPhysicalState() {
        this.HeldModifiers.Clear()
        this.HeldModifierEvents.Clear()
        this.CurrentEventDevice := ""
    }

    ClearDevicePhysicalState(deviceId) {
        prefix := String(deviceId) "|"
        staleModifiers := []
        for physicalModifier in this.HeldModifiers {
            if SubStr(physicalModifier, 1, StrLen(prefix)) == prefix
                staleModifiers.Push(physicalModifier)
        }
        for physicalModifier in staleModifiers
            this.HeldModifiers.Delete(physicalModifier)
        staleEvents := []
        for eventKey, physicalModifier in this.HeldModifierEvents {
            if SubStr(eventKey, 1, StrLen(prefix)) == prefix
                    || SubStr(physicalModifier, 1, StrLen(prefix)) == prefix
                staleEvents.Push(eventKey)
        }
        for eventKey in staleEvents
            this.HeldModifierEvents.Delete(eventKey)
        if Type(this.CurrentEventDevice) == "Map"
                && this.CurrentEventDevice.Has("id")
                && this.CurrentEventDevice["id"] == deviceId
            this.CurrentEventDevice := ""
        return staleModifiers.Length + staleEvents.Length
    }

    Suspend() {
        if this.Suspended
            return false
        this.Suspended := true
        this.ClearPhysicalState()
        return true
    }

    Resume() {
        if !this.Suspended
            return false
        this.ClearPhysicalState()
        this.Suspended := false
        return true
    }

    ReleaseAll() => 0

    GetCurrentEventDevice() {
        return Type(this.CurrentEventDevice) == "Map"
            ? RuleSpec.Clone(this.CurrentEventDevice) : ""
    }

    GetDevices() => this.RawInput.GetDevices()

    RecoverAfterResume() {
        this.ClearPhysicalState()
        return this.RawInput.Started ? this.RawInput.RecoverAfterResume()
            : (this.RawInput.Start(), this.RawInput.GetDevices())
    }

    HealthCheck() {
        return Map("backend", this.GetBackendId(),
            "healthy", JsonBoolean(this.RawInput.Started),
            "started", JsonBoolean(this.RawInput.Started),
            "suspended", JsonBoolean(this.Suspended),
            "registrations", this.Registrations.Length,
            "devices", this.RawInput.GetDevices().Length,
            "detail", this.RawInput.Started ? "" : "Raw Input 尚未启动。")
    }

    Shutdown() {
        this.StopObservation()
        this.Registrations := []
        this.SimpleIndex := Map()
        this.Suspended := false
        this.ClearPhysicalState()
        return this.RawInput.Shutdown()
    }
}

class RawInputKeyMatcher {
    static Modifiers := Map(
        "ctrl", true, "shift", true, "alt", true, "win", true,
        "lctrl", true, "rctrl", true, "lshift", true, "rshift", true,
        "lalt", true, "ralt", true, "lwin", true, "rwin", true)

    static ReadBoolean(value) {
        if value is JsonBoolean
            return value.Value
        if Type(value) == "Integer" && (value == 0 || value == 1)
            return !!value
        throw TypeError("Raw Input 规则字段必须是布尔值。")
    }

    static ReadRuleNumber(key, field) {
        if !key.Has(field) || key[field] == ""
            return 0
        value := key[field]
        return Type(value) == "String" ? Integer("0x" value)
            : Integer(value)
    }

    static GetRuleSignatures(key) {
        result := []
        kind := key.Has("kind") ? StrLower(String(key["kind"])) : "keyboard"
        sc := this.ReadRuleNumber(key, "sc")
        vk := this.ReadRuleNumber(key, "vk")
        extended := key.Has("extended") && this.ReadBoolean(key["extended"])
        if sc
            result.Push(kind ":sc:" Format("{:03x}", sc & 0x1FF)
                ":" ((sc & 0x100) || extended ? "1" : "0"))
        if vk
            result.Push(kind ":vk:" Format("{:02x}", vk))
        if key.Has("name")
            result.Push(kind ":name:" StrLower(String(key["name"])))
        return result
    }

    static GetIdentitySignatures(identity) {
        result := []
        kind := StrLower(identity["kind"])
        if identity["sc"]
            result.Push(kind ":sc:" StrLower(identity["sc_hex"])
                ":" (identity["extended"].Value ? "1" : "0"))
        if identity["vk"]
            result.Push(kind ":vk:" StrLower(identity["vk_hex"]))
        result.Push(kind ":name:" StrLower(identity["name"]))
        return result
    }

    static RuleMatchesIdentity(key, identity) {
        expected := Map()
        for signature in this.GetRuleSignatures(key)
            expected[signature] := true
        for signature in this.GetIdentitySignatures(identity) {
            if expected.Has(signature)
                return true
        }
        return false
    }

    static NormalizeModifierName(name) {
        name := StrLower(String(name))
        switch name {
            case "lcontrol": return "lctrl"
            case "rcontrol": return "rctrl"
            case "control": return "ctrl"
        }
        return name
    }

    static IsModifier(name) => this.Modifiers.Has(
        this.NormalizeModifierName(name))

    static GetModifierCandidates(name) {
        name := this.NormalizeModifierName(name)
        switch name {
            case "ctrl": return ["lctrl", "rctrl"]
            case "shift": return ["lshift", "rshift"]
            case "alt": return ["lalt", "ralt"]
            case "win": return ["lwin", "rwin"]
            default: return [name]
        }
    }
}
