class KeyCaptureSession {
    static AppCommandCorrelationMs := 30
    static PointerCancellationTimeoutMs := 2000
    static InputDrainRetryMs := 15
    static InputDrainTimeoutMs := 2000
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

    __New(app, inputGuard := "") {
        this.App := app
        this.InputGuard := IsObject(inputGuard)
            ? inputGuard : CaptureInputGuardProcess("", "",
                ObjBindMethod(this, "ObserveGuardInputEvent"))
        this.Active := false
        this.Role := ""
        this.SuspensionOwned := false
        this.InputGuardOwned := false
        this.LastStartError := ""
        this.HeldKeys := Map()
        this.RecordedKeys := Map()
        this.RecordedOrder := []
        this.PendingCapture := ""
        this.CaptureFrozen := false
        this.ObservedHeld := Map()
        this.Draining := false
        this.DrainCapture := ""
        this.DrainCancelled := false
        this.DrainCancelReason := ""
        this.DrainRole := ""
        this.InputDrainDeadline := 0
        this.InputDrainTimer := ObjBindMethod(this, "FinalizeInputDrain")
        this.PointerButtonCancelPending := false
        this.PointerCancelTimer := ObjBindMethod(this,
            "FinalizePointerCancellationTimeout")
        this.PendingAppCommand := ""
        this.AppCommandTimer := ObjBindMethod(this,
            "FinalizePendingAppCommand")
    }

    Start(role) {
        this.Stop(false)
        this.LastStartError := ""
        if this.SuspensionOwned || this.InputGuardOwned {
            this.LastStartError := "上一次按键录制尚未完成清理。"
            return false
        }
        if role != "source" && role != "target" {
            this.LastStartError := "按键录制类型无效。"
            return false
        }
        this.Role := role
        this.HeldKeys.Clear()
        this.RecordedKeys.Clear()
        this.RecordedOrder := []
        this.PendingCapture := ""
        this.CaptureFrozen := false
        this.PointerButtonCancelPending := false
        this.Draining := false
        this.DrainCapture := ""
        this.DrainCancelled := false
        this.DrainCancelReason := ""
        this.DrainRole := ""
        this.InputDrainDeadline := 0
        SetTimer(this.PointerCancelTimer, 0)
        SetTimer(this.AppCommandTimer, 0)
        SetTimer(this.InputDrainTimer, 0)
        this.PendingAppCommand := ""
        try {
            this.InputGuardOwned := true
            if !this.InputGuard.Start()
                throw Error("无法取得录制期间的独占输入状态。")
            ; The helper can already consume and forward input while script
            ; workers acknowledge suspension, so recording must be live before
            ; that wait begins.
            this.Active := true
            this.SuspensionOwned := this.App.SuspendRemappingForCapture()
            if !this.SuspensionOwned
                throw Error("无法取得录制期间的重映射暂停状态。")
            this.SeedObservedModifiers()
            this.Trace("capture_started", {Outcome: role})
            return true
        } catch as startError {
            this.LastStartError := startError.Message
            this.Trace("capture_start_failed", {Outcome: "error",
                Detail: startError.Message})
            this.Stop(false)
            return false
        }
    }

    Stop(notifyCancelled := false, resumeRemapping := true) {
        wasActive := this.Active || this.Draining || this.SuspensionOwned
            || this.InputGuardOwned
        pointerCancellationPending := this.PointerButtonCancelPending
        inputGuardError := ""
        resumeError := ""
        this.Active := false
        this.PendingCapture := ""
        this.CaptureFrozen := false
        this.Draining := false
        this.DrainCapture := ""
        this.DrainCancelled := false
        this.DrainCancelReason := ""
        this.DrainRole := ""
        this.InputDrainDeadline := 0
        this.PointerButtonCancelPending := false
        SetTimer(this.PointerCancelTimer, 0)
        SetTimer(this.AppCommandTimer, 0)
        SetTimer(this.InputDrainTimer, 0)
        this.PendingAppCommand := ""
        this.HeldKeys.Clear()
        this.RecordedKeys.Clear()
        this.RecordedOrder := []
        if this.SuspensionOwned {
            this.SuspensionOwned := false
            if resumeRemapping {
                try this.App.ResumeRemappingAfterCapture(true)
                catch as caughtResumeError {
                    resumeError := caughtResumeError
                    try this.App.OnCaptureResumeFailed(caughtResumeError.Message)
                }
            }
        }
        ; 恢复运行时期间仍保持全局拦截，避免重新注册热键的短暂窗口把
        ; 本次录制末尾或取消按键泄露给规则和其它全局快捷键。
        if this.InputGuardOwned {
            try this.InputGuard.Stop()
            catch as caughtInputGuardError
                inputGuardError := caughtInputGuardError
            this.InputGuardOwned := this.InputGuardHasResources()
        }
        if pointerCancellationPending
            try this.App.FinalizeCapturePointerCancellation()
        if IsObject(inputGuardError) && wasActive {
            try this.App.OnCaptureRejected(inputGuardError.Message)
        } else if notifyCancelled && wasActive {
            this.App.OnCaptureCancelled()
        }
        if IsObject(inputGuardError)
            this.Trace("capture_input_guard_failed", {Outcome: "error",
                Detail: inputGuardError.Message})
        if IsObject(resumeError)
            this.Trace("capture_resume_failed", {Outcome: "error",
                Detail: resumeError.Message})
        return wasActive && !IsObject(inputGuardError)
            && !IsObject(resumeError)
    }

    InputGuardHasResources() {
        try return !!this.InputGuard.HasResources()
        catch
            return false
    }

    Cancel(reason := "generic", *) {
        return this.BeginInputDrain("", true, reason)
    }

    IsInputBlocked() => this.Active || this.Draining || this.InputGuardOwned

    DispatchRawInputEvent(unifiedEvent, runtime) {
        try this.ObserveRawInputEvent(unifiedEvent)
        if this.IsInputBlocked()
            return true
        try runtime.ObserveInputEvent(unifiedEvent)
        return false
    }

    ObserveRawInputEvent(unifiedEvent) {
        if Type(unifiedEvent) != "Map" || !unifiedEvent.Has("identity")
                || !unifiedEvent.Has("phase")
            return false
        if unifiedEvent["origin"] == "raw-input-device" {
            lifecycle := unifiedEvent.Has("metadata")
                ? unifiedEvent["metadata"].Get("lifecycle", "") : ""
            if (unifiedEvent["phase"] == "removal" || lifecycle == "rebound")
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
        tracksPhysicalInput := (identity["kind"] == "keyboard"
                || identity["kind"] == "mouse")
            && unifiedEvent["phase"] != "wheel"
            && unifiedEvent["phase"] != "move"
        if tracksPhysicalInput && unifiedEvent["phase"] == "down"
            this.ObservedHeld[stateKey] := RuleSpec.Clone(unifiedEvent)
        else if tracksPhysicalInput && unifiedEvent["phase"] == "up"
                && this.ObservedHeld.Has(stateKey)
            this.ObservedHeld.Delete(stateKey)
        if this.Active
            return this.HandleRawInputEvent(unifiedEvent)
        if this.Draining
            return this.HandleInputDrainEvent(unifiedEvent)
        return false
    }

    ObserveGuardInputEvent(packet) {
        if !IsObject(packet) || !packet.HasOwnProp("Kind")
            return false
        if packet.Kind == "keyboard"
            return this.ObserveGuardKeyboardEvent(packet)
        if packet.Kind == "mouse"
            return this.ObserveGuardMouseEvent(packet)
        return false
    }

    ObserveGuardKeyboardEvent(packet) {
        flags := Integer(packet.Flags)
        ; The guard must consume injected output as well, but remapping output
        ; racing the pause boundary must never become the user's recording.
        if flags & 0x10 ; LLKHF_INJECTED
            return true
        isUp := packet.Message == 0x0101 || packet.Message == 0x0105
            || (flags & 0x80) ; LLKHF_UP
        rawFlags := (isUp ? 0x0001 : 0)
            | ((flags & 0x01) ? 0x0002 : 0) ; LLKHF_EXTENDED -> RI_KEY_E0
        device := Map("id", "capture-guard-keyboard",
            "handle", "capture-guard-keyboard", "usage_page", 1,
            "usage", 6)
        identity := KeyIdentity.FromRawKeyboard(packet.VK, packet.SC,
            rawFlags, device)
        metadata := Map("raw_type", "keyboard", "message", packet.Message,
            "make_code", packet.SC, "hook_flags", flags,
            "injected_known", JsonBoolean(true),
            "hook_correlation", JsonBoolean(true))
        unifiedEvent := InputEvent.Create(identity, isUp ? "up" : "down",
            false, false, "raw-input", "", metadata)
        return this.ObserveRawInputEvent(unifiedEvent)
    }

    ObserveGuardMouseEvent(packet) {
        flags := Integer(packet.Flags)
        if flags & 0x01 ; LLMHF_INJECTED
            return true
        name := ""
        phase := ""
        switch packet.Message {
            case 0x0201: name := "LButton", phase := "down"
            case 0x0202: name := "LButton", phase := "up"
            case 0x0204: name := "RButton", phase := "down"
            case 0x0205: name := "RButton", phase := "up"
            case 0x0207: name := "MButton", phase := "down"
            case 0x0208: name := "MButton", phase := "up"
            case 0x020B:
                name := packet.MouseData == 2 ? "XButton2" : "XButton1"
                phase := "down"
            case 0x020C:
                name := packet.MouseData == 2 ? "XButton2" : "XButton1"
                phase := "up"
            case 0x020A:
                name := packet.MouseData > 0 ? "WheelUp" : "WheelDown"
                phase := "wheel"
            case 0x020E:
                name := packet.MouseData > 0 ? "WheelRight" : "WheelLeft"
                phase := "wheel"
        }
        if name == ""
            return false
        device := Map("id", "capture-guard-mouse",
            "handle", "capture-guard-mouse", "usage_page", 1,
            "usage", 2)
        identity := KeyIdentity.FromRawPointer(name, device)
        metadata := Map("raw_type", "mouse", "message", packet.Message,
            "button_data", packet.MouseData, "hook_flags", flags,
            "x", packet.X, "y", packet.Y,
            "injected_known", JsonBoolean(true),
            "hook_correlation", JsonBoolean(true))
        unifiedEvent := InputEvent.Create(identity, phase, false, false,
            "raw-input", "", metadata)
        return this.ObserveRawInputEvent(unifiedEvent)
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
        if staleHeld.Length {
            this.Trace("capture_device_lost", {Outcome: "cancelled",
                Detail: String(deviceId)})
            this.Cancel()
        }
        return removed + staleHeld.Length
    }

    HandleRawInputEvent(unifiedEvent) {
        if !this.Active || Type(unifiedEvent) != "Map"
                || unifiedEvent["origin"] != "raw-input"
            return false
        identity := unifiedEvent["identity"]
        if !identity.Has("device_id") || identity["device_id"] == ""
                || unifiedEvent["phase"] == "move"
            return false
        if unifiedEvent["phase"] == "down"
            this.CorrelatePendingAppCommand(identity["name"])
        capturedKey := this.CreateRawKeyInfo(identity)
        switch unifiedEvent["phase"] {
            case "wheel": return this.HandleRawWheel(capturedKey, unifiedEvent)
            case "down": return this.HandleRawDown(capturedKey, unifiedEvent)
            case "up": return this.HandleRawUp(capturedKey, unifiedEvent)
        }
        return false
    }

    HandleInputDrainEvent(unifiedEvent) {
        if !this.Draining || Type(unifiedEvent) != "Map"
                || unifiedEvent["origin"] != "raw-input"
            return false
        ; The low-level guard remains installed during this phase. We only need
        ; Raw Input to learn when every physical key/button has been released.
        if !this.ObservedHeld.Count
            this.ScheduleInputDrainFinalization()
        return true
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
        if identity.Get("app_command", 0) {
            capturedKey.Kind := "app-command"
            capturedKey.AppCommand := identity["app_command"]
            capturedKey.KeySpec := identity["name"]
        }
        capturedKey.DeviceId := String(identity["device_id"])
        return capturedKey
    }

    HandleRawDown(capturedKey, unifiedEvent) {
        if this.PointerButtonCancelPending
            return false
        identityKey := this.GetKeyIdentity(capturedKey)
        this.Trace("raw_key_down", {Source: capturedKey.KeyName,
            Detail: capturedKey.DeviceId, Data: unifiedEvent})
        if capturedKey.KeyName == "Escape"
                && this.EscapeCancelsRecording() {
            ; Arm the GUI Escape consumer immediately. Finalization may be
            ; delayed until every physical key has been released, so waiting
            ; for OnCaptureCancelled would reintroduce a timing race.
            try this.App.PrepareCaptureEscapeCancellation()
            this.Cancel("escape")
            return true
        }
        if capturedKey.KeyName == "LButton"
                && this.ShouldCancelForPointerButton() {
            this.PointerButtonCancelPending := true
            try this.App.PrepareCapturePointerCancellation()
            SetTimer(this.PointerCancelTimer,
                -KeyCaptureSession.PointerCancellationTimeoutMs)
            return true
        }
        if this.HeldKeys.Has(identityKey)
            return true
        this.HeldKeys[identityKey] := capturedKey
        if !this.CaptureFrozen {
            this.AddRecordedKey(capturedKey)
            this.RebuildPendingCapture()
            this.NotifyPreview(this.PendingCapture)
        }
        return true
    }

    HandleRawUp(capturedKey, unifiedEvent) {
        this.Trace("raw_key_up", {Source: capturedKey.KeyName,
            Detail: capturedKey.DeviceId, Data: unifiedEvent})
        if this.PointerButtonCancelPending {
            if capturedKey.KeyName == "LButton"
                this.Cancel("pointer")
            return true
        }
        identityKey := this.FindHeldKeyIdentity(capturedKey)
        if identityKey == ""
            return false
        if !this.CaptureFrozen
            this.FreezeCapture()
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
        this.Trace("raw_wheel", {Source: capturedKey.KeyName,
            Detail: capturedKey.DeviceId, Data: unifiedEvent})
        if !this.CaptureFrozen {
            this.AddRecordedKey(capturedKey)
            this.FreezeCapture(true)
            this.NotifyPreview(this.PendingCapture)
        }
        if !this.HeldKeys.Count
            this.CompletePendingCapture()
        return true
    }

    CompletePendingCapture() {
        if !this.Active || this.PointerButtonCancelPending
                || IsObject(this.PendingAppCommand)
                || this.HeldKeys.Count || !IsObject(this.PendingCapture)
            return false
        capture := this.PendingCapture
        this.PendingCapture := ""
        return this.Complete(capture)
    }

    ShouldCancelForPointerButton() {
        try return !!this.App.ShouldCancelCaptureForPointer()
        catch
            return false
    }

    FinalizePointerCancellationTimeout(*) {
        if !this.Active || !this.PointerButtonCancelPending
            return false
        return this.Cancel()
    }

    CompleteAppCommand(command) {
        if !this.Active || !KeyCaptureSession.AppCommandNames.Has(command)
            return false
        keyName := KeyCaptureSession.AppCommandNames[command]
        if this.HasRecordedAppCommand(command, keyName)
            return true
        if IsObject(this.PendingAppCommand)
            return true
        this.PendingAppCommand := {Command: command, KeyName: keyName}
        SetTimer(this.AppCommandTimer,
            -KeyCaptureSession.AppCommandCorrelationMs)
        return true
    }

    CorrelatePendingAppCommand(keyName) {
        if !IsObject(this.PendingAppCommand)
                || StrLower(this.PendingAppCommand.KeyName)
                    != StrLower(String(keyName))
            return false
        SetTimer(this.AppCommandTimer, 0)
        this.PendingAppCommand := ""
        return true
    }

    FinalizePendingAppCommand(*) {
        if !this.Active || !IsObject(this.PendingAppCommand)
            return false
        pending := this.PendingAppCommand
        this.PendingAppCommand := ""
        command := pending.Command
        keyName := pending.KeyName
        capturedKey := this.CreateKeyInfo("app-command", keyName,
            this.SafeGetKeyVK(keyName), 0, keyName)
        capturedKey.AppCommand := command
        this.Trace("app_command", {Source: keyName,
            Outcome: this.Role, Detail: command})
        this.AddRecordedKey(capturedKey)
        this.FreezeCapture(true)
        this.NotifyPreview(this.PendingCapture)
        if !this.HeldKeys.Count
            this.CompletePendingCapture()
        return true
    }

    HasRecordedAppCommand(command, keyName) {
        for identityKey in this.RecordedOrder {
            if !this.RecordedKeys.Has(identityKey)
                continue
            capturedKey := this.RecordedKeys[identityKey]
            if capturedKey.HasOwnProp("AppCommand")
                    && capturedKey.AppCommand == command
                return true
            if StrLower(capturedKey.KeyName) == StrLower(keyName)
                return true
        }
        return false
    }

    Complete(capture) {
        if !this.Active || this.PointerButtonCancelPending
            return false
        if !IsObject(capture)
            return false
        this.BeginInputDrain(capture)
        return true
    }

    BeginInputDrain(capture := "", notifyCancelled := false,
            cancelReason := "") {
        if !this.Active
            return this.Draining
        this.Active := false
        this.CaptureFrozen := true
        this.PendingCapture := ""
        this.PendingAppCommand := ""
        SetTimer(this.AppCommandTimer, 0)
        SetTimer(this.PointerCancelTimer, 0)
        this.Draining := true
        this.DrainCapture := IsObject(capture) ? capture : ""
        this.DrainCancelled := !!notifyCancelled
        this.DrainCancelReason := this.DrainCancelled
            ? String(cancelReason) : ""
        this.DrainRole := this.Role
        this.InputDrainDeadline := A_TickCount
            + KeyCaptureSession.InputDrainTimeoutMs
        this.Trace("capture_input_draining", {
            Outcome: this.DrainCancelled ? "cancelled" : "completed",
            Detail: this.ObservedHeld.Count
        })
        this.ScheduleInputDrainFinalization()
        return true
    }

    ScheduleInputDrainFinalization() {
        if this.Draining
            SetTimer(this.InputDrainTimer, -1)
        return this.Draining
    }

    FinalizeInputDrain(*) {
        if !this.Draining
            return false
        if this.ObservedHeld.Count {
            if A_TickCount >= this.InputDrainDeadline {
                removed := this.ReconcileObservedHeld()
                if removed
                    this.Trace("capture_input_drain_reconciled", {
                        Outcome: "recovered", Detail: removed
                    })
                this.InputDrainDeadline := A_TickCount
                    + KeyCaptureSession.InputDrainTimeoutMs
            }
            if this.ObservedHeld.Count {
                SetTimer(this.InputDrainTimer,
                    -KeyCaptureSession.InputDrainRetryMs)
                return false
            }
        }
        capture := this.DrainCapture
        cancelled := this.DrainCancelled
        role := this.DrainRole
        this.Draining := false
        this.DrainCapture := ""
        this.DrainCancelled := false
        cancelReason := this.DrainCancelReason
        this.DrainCancelReason := ""
        this.DrainRole := ""
        this.InputDrainDeadline := 0
        if !this.Stop(false)
            return false
        if IsObject(capture)
            this.App.OnCaptureCompleted(role, capture)
        else if cancelled
            this.App.OnCaptureCancelled(cancelReason)
        return true
    }

    ReconcileObservedHeld() {
        released := []
        for stateKey, unifiedEvent in this.ObservedHeld {
            identity := unifiedEvent["identity"]
            virtualKey := identity.Has("vk") ? identity["vk"] : 0
            if !virtualKey {
                try virtualKey := GetKeyVK(identity["name"])
            }
            ; Unknown keys remain guarded until Raw Input or device removal
            ; proves their release. GetAsyncKeyState repairs only a genuinely
            ; missing release packet and never overrides a physically held key.
            if virtualKey && !(DllCall("user32\GetAsyncKeyState", "Int",
                    virtualKey, "Short") & 0x8000)
                released.Push(stateKey)
        }
        for stateKey in released
            this.ObservedHeld.Delete(stateKey)
        return released.Length
    }

    PreviewHeldModifiers() {
        if !this.Active || !this.HeldKeys.Count
            return false
        this.RebuildPendingCapture()
        this.NotifyPreview(this.PendingCapture)
        return true
    }

    AddRecordedKey(capturedKey) {
        identityKey := this.GetRecordedKeyIdentity(capturedKey)
        if this.RecordedKeys.Has(identityKey)
            return false
        this.RecordedKeys[identityKey] := capturedKey
        this.RecordedOrder.Push(identityKey)
        return true
    }

    FreezeCapture(forceRebuild := false) {
        if this.CaptureFrozen && !forceRebuild
            return false
        this.CaptureFrozen := true
        if forceRebuild || !IsObject(this.PendingCapture)
            this.RebuildPendingCapture()
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
        keyInfos := this.CreatePublicKeyInfos(keyInfos)
        if keyInfos.Length == 1
            return this.BuildCaptureFromInfo(keyInfos[1], [])
        modifiers := [], primaryInfo := ""
        nonModifierCount := 0
        for keyInfo in keyInfos {
            if this.IsModifierKey(keyInfo.KeyName)
                modifiers.Push(keyInfo)
            else {
                nonModifierCount++
                primaryInfo := keyInfo
            }
        }
        if nonModifierCount == 1
            return this.BuildCaptureFromInfo(primaryInfo, modifiers)

        rawDisplayParts := [], displayParts := []
        vkParts := [], scParts := [], keyInfoTextParts := []
        sourceKeys := [], modifiers := []
        for capturedKey in keyInfos {
            rawDisplayParts.Push(capturedKey.KeyName)
            displayParts.Push(capturedKey.DisplayName)
            vkParts.Push(this.FormatCodeValue("VK", capturedKey.VKHex))
            scParts.Push(this.FormatCodeValue("SC", capturedKey.SCHex))
            keyInfoTextParts.Push(this.FormatKeyInfo(capturedKey))
            sourceKeys.Push(capturedKey.KeySpec)
            if this.IsModifierKey(capturedKey.KeyName)
                modifiers.Push(capturedKey)
        }
        primaryInfo := this.GetSimultaneousPrimaryInfo(keyInfos)
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
        return capture
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
        return capture
    }

    CreatePublicKeyInfos(keyInfos) {
        result := []
        for keyInfo in keyInfos
            result.Push(this.CreatePublicKeyInfo(keyInfo))
        return result
    }

    CreatePublicKeyInfo(keyInfo) {
        publicInfo := this.CreateKeyInfo(keyInfo.Kind, keyInfo.KeyName,
            keyInfo.VK, keyInfo.SC, keyInfo.KeySpec)
        if keyInfo.HasOwnProp("AppCommand")
            publicInfo.AppCommand := keyInfo.AppCommand
        return publicInfo
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

    GetRecordedKeyIdentity(capturedKey) {
        kind := capturedKey.Kind == "app-command" ? "keyboard"
            : capturedKey.Kind
        return StrLower(kind "|" capturedKey.KeyName "|" capturedKey.VK
            "|" capturedKey.SC)
    }

    GetSimultaneousPrimaryInfo(keyInfos) {
        index := keyInfos.Length
        while index >= 1 {
            if !this.IsModifierKey(keyInfos[index].KeyName)
                return keyInfos[index]
            index--
        }
        return keyInfos[keyInfos.Length]
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
        if capturedKey.HasOwnProp("AppCommand")
            parts.Push("CMD " capturedKey.AppCommand)
        return this.Join(parts, " · ")
    }

    FormatKeyInfo(capturedKey) {
        codes := ["VK " (capturedKey.VKHex == "" ? "--" : capturedKey.VKHex),
            "SC " (capturedKey.SCHex == "" ? "---" : capturedKey.SCHex)]
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
