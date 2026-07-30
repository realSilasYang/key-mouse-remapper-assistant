class KeyCaptureSession {
    static ModifierOrder := [
        "LCtrl", "RCtrl", "LShift", "RShift",
        "LAlt", "RAlt", "LWin", "RWin"]
    static AppCommandNames := Map(
        1, "Browser_Back", 2, "Browser_Forward", 3, "Browser_Refresh",
        4, "Browser_Stop", 5, "Browser_Search", 6, "Browser_Favorites",
        7, "Browser_Home", 8, "Volume_Mute", 9, "Volume_Down",
        10, "Volume_Up", 11, "Media_Next", 12, "Media_Prev",
        13, "Media_Stop", 14, "Media_Play_Pause", 15, "Launch_Mail",
        16, "Launch_Media", 17, "Launch_App1", 18, "Launch_App2")

    __New(app) {
        this.App := app
        this.Active := false
        this.Role := ""
        this.SuspensionOwned := false
        this.HeldKeys := Map()
        this.RecordedKeys := Map()
        this.RecordedOrder := []
        this.PendingCapture := ""
        this.CaptureDeviceId := ""
        this.ObservedHeld := Map()
        this.PointerButtonCancelPending := false
        this.PointerButtonCancelTick := 0
    }

    Start(role) {
        this.Stop(false)
        if role != "source" && role != "target"
            return false
        this.Role := role
        this.HeldKeys.Clear()
        this.RecordedKeys.Clear()
        this.RecordedOrder := []
        this.PendingCapture := ""
        this.CaptureDeviceId := ""
        this.PointerButtonCancelPending := false
        this.PointerButtonCancelTick := 0
        try {
            this.SuspensionOwned := !this.App.Runtime.Backend.Suspended
            if this.SuspensionOwned
                this.App.Runtime.Backend.Suspend()
            this.Active := true
            this.SeedObservedModifiers()
            this.Trace("capture_started", {Outcome: role})
            return true
        } catch {
            this.Stop(false)
            return false
        }
    }

    Stop(notifyCancelled := false) {
        wasActive := this.Active
        pointerCancellationPending := this.PointerButtonCancelPending
        this.Active := false
        this.PendingCapture := ""
        this.CaptureDeviceId := ""
        this.PointerButtonCancelPending := false
        this.PointerButtonCancelTick := 0
        this.HeldKeys.Clear()
        this.RecordedKeys.Clear()
        this.RecordedOrder := []
        if this.SuspensionOwned {
            this.SuspensionOwned := false
            try this.App.Runtime.Backend.Resume()
        }
        if pointerCancellationPending
            try this.App.FinalizeCapturePointerCancellation()
        if notifyCancelled && wasActive
            this.App.OnCaptureCancelled()
        return wasActive
    }

    Cancel(*) => this.Stop(true)

    ObserveRawInputEvent(unifiedEvent) {
        if Type(unifiedEvent) != "Map" || !unifiedEvent.Has("identity")
                || !unifiedEvent.Has("phase")
            return false
        if unifiedEvent["origin"] == "raw-input-device" {
            if unifiedEvent["phase"] == "removal"
                    && unifiedEvent.Has("metadata")
                    && unifiedEvent["metadata"].Has("device")
                this.HandleDeviceRemoval(
                    unifiedEvent["metadata"]["device"]["id"])
            return false
        }
        if unifiedEvent["origin"] != "raw-input"
            return false
        identity := unifiedEvent["identity"]
        deviceId := identity.Has("device_id")
            ? String(identity["device_id"]) : ""
        if deviceId == ""
            return false
        stateKey := deviceId "|" KeyIdentity.Signature(identity)
        if unifiedEvent["phase"] == "down"
            this.ObservedHeld[stateKey] := RuleSpec.Clone(unifiedEvent)
        else if unifiedEvent["phase"] == "up" && this.ObservedHeld.Has(stateKey)
            this.ObservedHeld.Delete(stateKey)
        return this.Active ? this.HandleRawInputEvent(unifiedEvent) : false
    }

    SeedObservedModifiers() {
        for stateKey, unifiedEvent in this.ObservedHeld {
            identity := unifiedEvent["identity"]
            if identity["kind"] == "keyboard"
                    && this.IsModifierKey(identity["name"])
                this.HandleRawDown(this.CreateRawKeyInfo(identity), unifiedEvent)
        }
    }

    ClearObservedDevice(deviceId) {
        prefix := String(deviceId) "|"
        stale := []
        for stateKey in this.ObservedHeld {
            if SubStr(stateKey, 1, StrLen(prefix)) == prefix
                stale.Push(stateKey)
        }
        for stateKey in stale
            this.ObservedHeld.Delete(stateKey)
        return stale.Length
    }

    HandleDeviceRemoval(deviceId) {
        removed := this.ClearObservedDevice(deviceId)
        if !this.Active
            return removed
        staleHeld := []
        for identityKey, capturedKey in this.HeldKeys {
            if capturedKey.HasOwnProp("DeviceId")
                    && capturedKey.DeviceId == deviceId
                staleHeld.Push(identityKey)
        }
        for identityKey in staleHeld
            this.HeldKeys.Delete(identityKey)
        if this.CaptureDeviceId == deviceId && !this.HeldKeys.Count
                && IsObject(this.PendingCapture)
            this.CompletePendingCapture()
        return removed + staleHeld.Length
    }

    SelectCaptureDevice(deviceId) {
        if this.Role != "source"
            return true
        deviceId := String(deviceId)
        if deviceId == ""
            return false
        if this.CaptureDeviceId != ""
            return this.CaptureDeviceId == deviceId
        this.CaptureDeviceId := deviceId
        staleHeld := []
        for identityKey, capturedKey in this.HeldKeys {
            if capturedKey.HasOwnProp("DeviceId")
                    && capturedKey.DeviceId != deviceId
                staleHeld.Push(identityKey)
        }
        for identityKey in staleHeld
            this.HeldKeys.Delete(identityKey)
        filteredOrder := []
        for identityKey in this.RecordedOrder {
            if !this.RecordedKeys.Has(identityKey)
                continue
            capturedKey := this.RecordedKeys[identityKey]
            if capturedKey.HasOwnProp("DeviceId")
                    && capturedKey.DeviceId == deviceId
                filteredOrder.Push(identityKey)
            else
                this.RecordedKeys.Delete(identityKey)
        }
        this.RecordedOrder := filteredOrder
        if this.RecordedOrder.Length
            this.RebuildPendingCapture()
        else
            this.PendingCapture := ""
        return true
    }

    HandleRawInputEvent(unifiedEvent) {
        if !this.Active || Type(unifiedEvent) != "Map"
                || unifiedEvent["origin"] != "raw-input"
            return false
        identity := unifiedEvent["identity"]
        if !identity.Has("device_id") || identity["device_id"] == ""
                || unifiedEvent["phase"] == "move"
            return false
        capturedKey := this.CreateRawKeyInfo(identity)
        switch unifiedEvent["phase"] {
            case "wheel": return this.HandleRawWheel(capturedKey, unifiedEvent)
            case "down": return this.HandleRawDown(capturedKey, unifiedEvent)
            case "up": return this.HandleRawUp(capturedKey, unifiedEvent)
        }
        return false
    }

    CreateRawKeyInfo(identity) {
        keySpec := identity["sc"]
            ? Format("sc{:03X}", identity["sc"])
            : (identity["vk"] ? Format("vk{:02X}", identity["vk"])
                : identity["name"])
        capturedKey := this.CreateKeyInfo(identity["kind"], identity["name"],
            identity["vk"], identity["sc"], keySpec)
        if capturedKey.Kind == "keyboard"
            this.EnrichKeyboardKeyInfo(capturedKey)
        capturedKey.DeviceId := String(identity["device_id"])
        capturedKey.DeviceHandle := String(identity["device_handle"])
        capturedKey.UsagePage := identity["usage_page"]
        capturedKey.Usage := identity["usage"]
        try {
            for device in this.App.GetInputDevices() {
                if device.Has("id") && device["id"] == capturedKey.DeviceId {
                    capturedKey.DeviceDisplayName := device["display_name"]
                    capturedKey.Device := RuleSpec.Clone(device)
                    break
                }
            }
        }
        if !capturedKey.HasOwnProp("DeviceDisplayName")
            capturedKey.DeviceDisplayName := capturedKey.DeviceId
        return capturedKey
    }

    HandleRawDown(capturedKey, unifiedEvent) {
        if this.PointerButtonCancelPending
            return false
        if this.Role == "source" {
            if this.CaptureDeviceId != ""
                    && capturedKey.DeviceId != this.CaptureDeviceId
                return false
            if !this.IsModifierKey(capturedKey.KeyName)
                    && !this.SelectCaptureDevice(capturedKey.DeviceId)
                return false
        }
        identityKey := this.GetKeyIdentity(capturedKey)
        this.Trace("raw_key_down", {Source: capturedKey.KeyName,
            Detail: capturedKey.DeviceId, Data: unifiedEvent})
        if capturedKey.KeyName == "Escape" && !this.HeldKeys.Count
                && this.EscapeCancelsRecording() {
            this.Cancel()
            return true
        }
        if capturedKey.KeyName == "LButton"
                && this.ShouldCancelForPointerButton() {
            this.PointerButtonCancelPending := true
            this.PointerButtonCancelTick := A_TickCount
            try this.App.PrepareCapturePointerCancellation()
            return true
        }
        if this.HeldKeys.Has(identityKey)
            return true
        this.HeldKeys[identityKey] := capturedKey
        this.AddRecordedKey(capturedKey)
        this.RebuildPendingCapture()
        this.NotifyPreview(this.PendingCapture)
        return true
    }

    HandleRawUp(capturedKey, unifiedEvent) {
        if this.Role == "source"
                && !this.SelectCaptureDevice(capturedKey.DeviceId)
            return false
        this.Trace("raw_key_up", {Source: capturedKey.KeyName,
            Detail: capturedKey.DeviceId, Data: unifiedEvent})
        if this.PointerButtonCancelPending {
            if capturedKey.KeyName == "LButton"
                this.Cancel()
            return true
        }
        identityKey := this.FindHeldKeyIdentity(capturedKey)
        if identityKey == ""
            return false
        this.HeldKeys.Delete(identityKey)
        if this.HeldKeys.Count
            this.NotifyPreview(this.PendingCapture)
        else
            this.CompletePendingCapture()
        return true
    }

    HandleRawWheel(capturedKey, unifiedEvent) {
        if this.PointerButtonCancelPending
            return false
        if !this.SelectCaptureDevice(capturedKey.DeviceId)
            return false
        this.Trace("raw_wheel", {Source: capturedKey.KeyName,
            Detail: capturedKey.DeviceId, Data: unifiedEvent})
        this.AddRecordedKey(capturedKey)
        this.RebuildPendingCapture()
        this.NotifyPreview(this.PendingCapture)
        if !this.HeldKeys.Count
            this.CompletePendingCapture()
        return true
    }

    CompletePendingCapture() {
        if !this.Active || this.PointerButtonCancelPending
                || this.HeldKeys.Count || !IsObject(this.PendingCapture)
            return false
        capture := this.PendingCapture
        this.PendingCapture := ""
        this.Complete(capture)
        return true
    }

    ShouldCancelForPointerButton() {
        try return !!this.App.ShouldCancelCaptureForPointer()
        catch
            return false
    }

    CompleteAppCommand(command) {
        if !this.Active || this.Role != "target"
                || !KeyCaptureSession.AppCommandNames.Has(command)
            return false
        keyName := KeyCaptureSession.AppCommandNames[command]
        capturedKey := this.CreateKeyInfo("app-command", keyName,
            this.SafeGetKeyVK(keyName), this.SafeGetKeySC(keyName), keyName)
        capturedKey.AppCommand := command
        this.AddRecordedKey(capturedKey)
        this.RebuildPendingCapture()
        this.NotifyPreview(this.PendingCapture)
        if !this.HeldKeys.Count
            this.CompletePendingCapture()
        return true
    }

    Complete(capture) {
        if !this.Active || this.PointerButtonCancelPending
            return false
        role := this.Role
        this.Stop(false)
        this.App.OnCaptureCompleted(role, capture)
        return true
    }

    PreviewHeldModifiers() {
        if !this.Active || !this.HeldKeys.Count
            return false
        this.RebuildPendingCapture()
        this.NotifyPreview(this.PendingCapture)
        return true
    }

    AddRecordedKey(capturedKey) {
        identityKey := this.GetKeyIdentity(capturedKey)
        if this.RecordedKeys.Has(identityKey)
            return false
        this.RecordedKeys[identityKey] := capturedKey
        this.RecordedOrder.Push(identityKey)
        return true
    }

    RebuildPendingCapture() {
        keyInfos := []
        for identityKey in this.RecordedOrder {
            if this.RecordedKeys.Has(identityKey)
                keyInfos.Push(this.RecordedKeys[identityKey])
        }
        if !keyInfos.Length
            return false
        this.PendingCapture := this.BuildCaptureFromInfos(keyInfos)
        return true
    }

    FindHeldKeyIdentity(capturedKey) {
        exactIdentity := this.GetKeyIdentity(capturedKey)
        if this.HeldKeys.Has(exactIdentity)
            return exactIdentity
        for identityKey, heldInfo in this.HeldKeys {
            if this.IsSamePhysicalKey(heldInfo, capturedKey)
                return identityKey
        }
        return ""
    }

    IsSamePhysicalKey(left, right) {
        leftDevice := left.HasOwnProp("DeviceId") ? left.DeviceId : ""
        rightDevice := right.HasOwnProp("DeviceId") ? right.DeviceId : ""
        if leftDevice != rightDevice
            return false
        leftKind := left.Kind == "app-command" ? "keyboard" : left.Kind
        rightKind := right.Kind == "app-command" ? "keyboard" : right.Kind
        if leftKind != rightKind
            return false
        if leftKind == "mouse"
            return StrLower(left.KeyName) == StrLower(right.KeyName)
        if left.SC && right.SC
            return (left.SC & 0x1FF) == (right.SC & 0x1FF)
        if left.VK && right.VK && left.VK == right.VK
            return StrLower(left.KeyName) == StrLower(right.KeyName)
        return StrLower(left.KeyName) == StrLower(right.KeyName)
    }

    EscapeCancelsRecording() {
        try return !!this.App.Settings.EscapeCancelsRecording
        catch
            return true
    }

    BuildCaptureFromInfos(keyInfos) {
        if Type(keyInfos) != "Array" || !keyInfos.Length
            throw ValueError("按键录制缺少按键信息")
        if keyInfos.Length == 1
            return this.BuildCaptureFromInfo(keyInfos[1], [])

        rawDisplayParts := [], displayParts := []
        vkParts := [], scParts := [], keyInfoTextParts := []
        sourceKeys := [], modifiers := []
        for index, capturedKey in keyInfos {
            rawDisplayParts.Push(capturedKey.KeyName)
            displayParts.Push(capturedKey.DisplayName)
            vkParts.Push(this.FormatCodeValue("VK", capturedKey.VKHex))
            scParts.Push(this.FormatCodeValue("SC", capturedKey.SCHex))
            keyInfoTextParts.Push(this.FormatKeyInfo(capturedKey))
            sourceKeys.Push(capturedKey.KeySpec)
            if index < keyInfos.Length && this.IsModifierKey(capturedKey.KeyName)
                modifiers.Push(capturedKey)
        }
        primaryInfo := keyInfos[keyInfos.Length]
        display := this.Join(displayParts, " + ")
        capture := {
            Kind: "simultaneous",
            KeyName: primaryInfo.KeyName,
            KeySpec: primaryInfo.KeySpec,
            VK: primaryInfo.VK,
            SC: primaryInfo.SC,
            VKHex: primaryInfo.VKHex,
            SCHex: primaryInfo.SCHex,
            Modifiers: modifiers,
            Keys: keyInfos.Clone(),
            SourceKeys: sourceKeys,
            IsSimultaneous: true,
            SourceSpec: this.BuildSimultaneousSourceSpec(sourceKeys),
            TargetSend: this.BuildSimultaneousTargetSend(keyInfos),
            RawDisplay: this.Join(rawDisplayParts, " + "),
            Display: display,
            Detail: this.Join(keyInfoTextParts, " + "),
            DetailLines: Tr("按键名称：{1}`n虚拟键码：{2}`n扫描码：{3}",
                display, this.Join(vkParts, " + "),
                this.Join(scParts, " + ")),
            KeyInfo: this.Join(keyInfoTextParts, " + ")
        }
        return this.CopyCaptureDevice(capture, primaryInfo)
    }

    BuildCaptureFromInfo(capturedKey, heldModifiers) {
        modifiers := []
        for modifierInfo in heldModifiers {
            if modifierInfo.KeyName != capturedKey.KeyName
                modifiers.Push(modifierInfo)
        }
        hotkeyPrefix := ""
        rawDisplayParts := [], displayParts := []
        vkParts := [], scParts := [], keyInfoTextParts := []
        for modifierInfo in modifiers {
            hotkeyPrefix .= this.GetModifierHotkeyPrefix(modifierInfo.KeyName)
            rawDisplayParts.Push(modifierInfo.KeyName)
            displayParts.Push(modifierInfo.DisplayName)
            vkParts.Push(this.FormatCodeValue("VK", modifierInfo.VKHex))
            scParts.Push(this.FormatCodeValue("SC", modifierInfo.SCHex))
            keyInfoTextParts.Push(this.FormatKeyInfo(modifierInfo))
        }
        rawDisplayParts.Push(capturedKey.KeyName)
        displayParts.Push(capturedKey.DisplayName)
        vkParts.Push(this.FormatCodeValue("VK", capturedKey.VKHex))
        scParts.Push(this.FormatCodeValue("SC", capturedKey.SCHex))
        keyInfoTextParts.Push(this.FormatKeyInfo(capturedKey))
        display := this.Join(displayParts, " + ")
        capture := {
            Kind: capturedKey.Kind,
            KeyName: capturedKey.KeyName,
            KeySpec: capturedKey.KeySpec,
            VK: capturedKey.VK,
            SC: capturedKey.SC,
            VKHex: capturedKey.VKHex,
            SCHex: capturedKey.SCHex,
            Modifiers: modifiers,
            Keys: this.CombineKeyInfos(modifiers, capturedKey),
            SourceKeys: [capturedKey.KeySpec],
            IsSimultaneous: false,
            SourceSpec: hotkeyPrefix capturedKey.KeySpec,
            TargetSend: this.BuildTargetSend(capturedKey.KeySpec, modifiers),
            RawDisplay: this.Join(rawDisplayParts, " + "),
            Display: display,
            Detail: this.BuildCompactDetail(capturedKey),
            DetailLines: Tr("按键名称：{1}`n虚拟键码：{2}`n扫描码：{3}",
                display, this.Join(vkParts, " + ") , this.Join(scParts, " + ")),
            KeyInfo: this.Join(keyInfoTextParts, " + ")
        }
        if capturedKey.HasOwnProp("AppCommand")
            capture.AppCommand := capturedKey.AppCommand
        return this.CopyCaptureDevice(capture, capturedKey)
    }

    CopyCaptureDevice(capture, primaryInfo) {
        if !primaryInfo.HasOwnProp("DeviceId")
            return capture
        capture.DeviceId := String(primaryInfo.DeviceId)
        capture.DeviceDisplayName := primaryInfo.HasOwnProp(
            "DeviceDisplayName") ? primaryInfo.DeviceDisplayName
            : capture.DeviceId
        if primaryInfo.HasOwnProp("Device")
            capture.Device := RuleSpec.Clone(primaryInfo.Device)
        return capture
    }

    NotifyPreview(capture) {
        if this.Active && IsObject(capture)
            try this.App.OnCapturePreview(this.Role, capture)
    }

    CreateKeyInfo(kind, keyName, vk := 0, sc := 0, keySpec := "") {
        keyName := this.CanonicalizeKeyName(keyName)
        vk := Max(0, Integer(vk))
        sc := Max(0, Integer(sc))
        if keySpec == ""
            keySpec := sc ? Format("sc{:03X}", sc) : Format("vk{:02X}", vk)
        return {
            Kind: kind,
            KeyName: keyName,
            DisplayName: this.GetDisplayKeyName(keyName),
            KeySpec: keySpec,
            VK: vk,
            SC: sc,
            VKHex: vk ? Format("{:02X}", vk) : "",
            SCHex: sc ? Format("{:03X}", sc) : ""
        }
    }

    EnrichKeyboardKeyInfo(capturedKey) {
        command := this.GetAppCommandForKeyName(capturedKey.KeyName)
        if command {
            capturedKey.Kind := "app-command"
            capturedKey.AppCommand := command
            capturedKey.KeySpec := capturedKey.KeyName
        }
        return capturedKey
    }

    CanonicalizeKeyName(keyName) {
        keyName := String(keyName)
        if RegExMatch(keyName, "i)^[a-z]$")
            return StrUpper(keyName)
        switch StrLower(keyName) {
            case "control", "ctrl": return "Ctrl"
            case "lcontrol", "lctrl": return "LCtrl"
            case "rcontrol", "rctrl": return "RCtrl"
            case "lshift": return "LShift"
            case "rshift": return "RShift"
            case "lmenu", "lalt": return "LAlt"
            case "rmenu", "ralt": return "RAlt"
            case "lwin": return "LWin"
            case "rwin": return "RWin"
            case "esc", "escape": return "Escape"
            default: return keyName
        }
    }

    CombineKeyInfos(prefixKeys, finalKey) {
        result := prefixKeys.Clone()
        result.Push(finalKey)
        return result
    }

    BuildSimultaneousSourceSpec(sourceKeys) {
        normalized := []
        for keySpec in sourceKeys
            normalized.Push(StrLower(String(keySpec)))
        this.SortStrings(normalized)
        return "sim:" this.Join(normalized, "+")
    }

    SortStrings(values) {
        if values.Length < 2
            return values
        Loop values.Length - 1 {
            leftIndex := A_Index
            Loop values.Length - leftIndex {
                rightIndex := leftIndex + A_Index
                if StrCompare(values[leftIndex], values[rightIndex], true) <= 0
                    continue
                temporary := values[leftIndex]
                values[leftIndex] := values[rightIndex]
                values[rightIndex] := temporary
            }
        }
        return values
    }

    GetKeyIdentity(capturedKey) {
        kind := capturedKey.Kind == "app-command" ? "keyboard"
            : capturedKey.Kind
        return StrLower(kind "|" capturedKey.KeyName "|" capturedKey.VK
            "|" capturedKey.SC "|" (capturedKey.HasOwnProp("DeviceId")
                ? capturedKey.DeviceId : ""))
    }

    GetModifierHotkeyPrefix(keyName) {
        switch keyName {
            case "LCtrl": return "<^"
            case "RCtrl": return ">^"
            case "LShift": return "<+"
            case "RShift": return ">+"
            case "LAlt": return "<!"
            case "RAlt": return ">!"
            case "LWin": return "<#"
            case "RWin": return ">#"
        }
        return ""
    }

    BuildTargetSend(keySpec, modifiers) {
        sendSequence := ""
        for modifierInfo in modifiers
            sendSequence .= "{" modifierInfo.KeyName " down}"
        sendSequence .= "{" keySpec "}"
        index := modifiers.Length
        while index >= 1 {
            sendSequence .= "{" modifiers[index].KeyName " up}"
            index--
        }
        return sendSequence
    }

    BuildSimultaneousTargetSend(keyInfos) {
        sendSequence := ""
        lastIndex := keyInfos.Length
        Loop lastIndex - 1
            sendSequence .= "{" this.GetSendKeySpec(keyInfos[A_Index])
                . " down}"
        sendSequence .= "{" this.GetSendKeySpec(keyInfos[lastIndex]) "}"
        index := lastIndex - 1
        while index >= 1 {
            sendSequence .= "{" this.GetSendKeySpec(keyInfos[index]) " up}"
            index--
        }
        return sendSequence
    }

    GetSendKeySpec(capturedKey) {
        return this.IsModifierKey(capturedKey.KeyName)
            ? capturedKey.KeyName : capturedKey.KeySpec
    }

    BuildCompactDetail(capturedKey) {
        parts := [this.GetKindLabel(capturedKey.Kind)]
        parts.Push("VK " (capturedKey.VKHex == "" ? "--" : capturedKey.VKHex))
        parts.Push("SC " (capturedKey.SCHex == "" ? "---" : capturedKey.SCHex))
        if capturedKey.HasOwnProp("DeviceDisplayName")
            parts.Push(capturedKey.DeviceDisplayName)
        if capturedKey.HasOwnProp("AppCommand")
            parts.Push("CMD " capturedKey.AppCommand)
        return this.Join(parts, " · ")
    }

    FormatKeyInfo(capturedKey) {
        codes := ["VK " (capturedKey.VKHex == "" ? "--" : capturedKey.VKHex),
            "SC " (capturedKey.SCHex == "" ? "---" : capturedKey.SCHex)]
        if capturedKey.HasOwnProp("DeviceDisplayName")
            codes.Push(capturedKey.DeviceDisplayName)
        if capturedKey.HasOwnProp("AppCommand")
            codes.Push("CMD " capturedKey.AppCommand)
        return capturedKey.DisplayName " [" this.Join(codes, " / ") "]"
    }

    FormatCodeValue(prefix, hexValue) {
        return hexValue == "" ? Tr("不适用") : prefix " " hexValue
    }

    GetKindLabel(kind) {
        switch kind {
            case "keyboard": return Tr("键盘")
            case "mouse": return Tr("鼠标")
            case "wheel": return Tr("滚轮")
            case "app-command": return Tr("多媒体")
            default: return Tr("命名键")
        }
    }

    GetAppCommandForKeyName(keyName) {
        keyName := StrLower(String(keyName))
        for command, commandName in KeyCaptureSession.AppCommandNames {
            if StrLower(commandName) == keyName
                return command
        }
        return 0
    }

    SafeGetKeyVK(keyName) {
        try return Max(0, GetKeyVK(keyName))
        catch
            return 0
    }

    SafeGetKeySC(keyName) {
        try return Max(0, GetKeySC(keyName))
        catch
            return 0
    }

    Trace(eventName, fields := "") {
        try return this.App.TraceEvent("input", eventName, fields)
        catch
            return false
    }

    Join(values, separator) {
        result := ""
        for index, value in values
            result .= (index == 1 ? "" : separator) value
        return result
    }

    IsModifierKey(keyName) {
        keyName := this.CanonicalizeKeyName(keyName)
        for modifierName in KeyCaptureSession.ModifierOrder {
            if keyName == modifierName
                return true
        }
        return keyName == "Ctrl" || keyName == "Shift" || keyName == "Alt"
            || keyName == "Win"
    }

    GetDisplayKeyName(keyName) {
        switch StrLower(this.CanonicalizeKeyName(keyName)) {
            case "escape": return "Esc"
            case "space": return "Space"
            case "control", "ctrl": return "Ctrl"
            case "lcontrol", "lctrl": return Tr("左侧 Ctrl")
            case "rcontrol", "rctrl": return Tr("右侧 Ctrl")
            case "lshift": return Tr("左侧 Shift")
            case "rshift": return Tr("右侧 Shift")
            case "lalt": return Tr("左侧 Alt")
            case "ralt": return Tr("右侧 Alt")
            case "lwin": return Tr("左侧 Win")
            case "rwin": return Tr("右侧 Win")
            default: return String(keyName)
        }
    }
}
