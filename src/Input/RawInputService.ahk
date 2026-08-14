class RawInputDecoder {
    static HeaderSize := A_PtrSize == 8 ? 24 : 16
    static KeyboardType := 1
    static MouseType := 0
    static HidType := 2

    static Decode(packet, device := "") {
        if !(packet is Buffer) || packet.Size < this.HeaderSize
            throw ValueError("Raw Input 数据包过短。")
        packetType := NumGet(packet, 0, "UInt")
        packetSize := NumGet(packet, 4, "UInt")
        if packetSize < this.HeaderSize || packetSize != packet.Size
            throw ValueError("Raw Input 数据包长度无效。")
        if packetType == this.KeyboardType {
            keyboardEvent := this.DecodeKeyboard(packet, device, packetSize)
            return IsObject(keyboardEvent) ? [keyboardEvent] : []
        }
        if packetType == this.MouseType
            return this.DecodeMouse(packet, device, packetSize)
        return []
    }

    static DecodeKeyboard(packet, device := "", packetSize := 0) {
        offset := this.HeaderSize
        if !packetSize
            packetSize := packet.Size
        if packetSize < offset + 16 || packet.Size < offset + 16
            throw ValueError("Raw Input 键盘数据包过短。")
        makeCode := NumGet(packet, offset, "UShort")
        flags := NumGet(packet, offset + 2, "UShort")
        virtualKey := NumGet(packet, offset + 6, "UShort")
        ; Windows uses VKey 255 for keyboard overrun/fake-key packets and
        ; explicitly requires applications to discard them.
        if virtualKey == 0xFF
            return ""
        message := NumGet(packet, offset + 8, "UInt")
        phase := (flags & 0x0001) ? "up" : "down"
        identity := KeyIdentity.FromRawKeyboard(virtualKey, makeCode,
            flags, device)
        metadata := Map(
            "raw_type", "keyboard",
            "raw_flags", flags,
            "message", message,
            "make_code", makeCode,
            "injected_known", JsonBoolean(false),
            "hook_correlation", JsonBoolean(false))
        return InputEvent.Create(identity, phase, false, false,
            "raw-input", "", metadata)
    }

    static DecodeMouse(packet, device := "", packetSize := 0) {
        offset := this.HeaderSize
        if !packetSize
            packetSize := packet.Size
        if packetSize < offset + 24 || packet.Size < offset + 24
            throw ValueError("Raw Input 鼠标数据包过短。")
        mouseFlags := NumGet(packet, offset, "UShort")
        buttonFlags := NumGet(packet, offset + 4, "UShort")
        buttonData := NumGet(packet, offset + 6, "Short")
        deltaX := NumGet(packet, offset + 12, "Int")
        deltaY := NumGet(packet, offset + 16, "Int")
        events := []
        buttons := [
            [0x0001, 0x0002, "LButton"],
            [0x0004, 0x0008, "RButton"],
            [0x0010, 0x0020, "MButton"],
            [0x0040, 0x0080, "XButton1"],
            [0x0100, 0x0200, "XButton2"]]
        for button in buttons {
            if buttonFlags & button[1]
                events.Push(this.CreateMouseEvent(button[3], "down", device,
                    mouseFlags, buttonFlags, buttonData, deltaX, deltaY))
            if buttonFlags & button[2]
                events.Push(this.CreateMouseEvent(button[3], "up", device,
                    mouseFlags, buttonFlags, buttonData, deltaX, deltaY))
        }
        if (buttonFlags & 0x0400) && buttonData
            events.Push(this.CreateMouseEvent(buttonData > 0
                ? "WheelUp" : "WheelDown", "wheel", device, mouseFlags,
                buttonFlags, buttonData, deltaX, deltaY))
        if (buttonFlags & 0x0800) && buttonData
            events.Push(this.CreateMouseEvent(buttonData > 0
                ? "WheelRight" : "WheelLeft", "wheel", device, mouseFlags,
                buttonFlags, buttonData, deltaX, deltaY))
        if deltaX || deltaY
            events.Push(this.CreateMouseEvent("MouseMove", "move", device,
                mouseFlags, buttonFlags, buttonData, deltaX, deltaY))
        return events
    }

    static CreateMouseEvent(name, phase, device, mouseFlags, buttonFlags,
            buttonData, deltaX, deltaY) {
        metadata := Map(
            "raw_type", "mouse",
            "mouse_flags", mouseFlags,
            "button_flags", buttonFlags,
            "button_data", buttonData,
            "delta_x", deltaX,
            "delta_y", deltaY,
            "injected_known", JsonBoolean(false),
            "hook_correlation", JsonBoolean(false))
        return InputEvent.Create(KeyIdentity.FromRawPointer(name, device),
            phase, false, false, "raw-input", "", metadata)
    }
}

class ConsumerControlUsage {
    static UsagePage := 0x000C
    static CollectionUsage := 0x0001

    static Resolve(usage) {
        static definitions := Map(
            0x0224, ["Browser_Back", 1],
            0x0225, ["Browser_Forward", 2],
            0x0227, ["Browser_Refresh", 3],
            0x0226, ["Browser_Stop", 4],
            0x0221, ["Browser_Search", 5],
            0x022A, ["Browser_Favorites", 6],
            0x0223, ["Browser_Home", 7],
            0x00E2, ["Volume_Mute", 8],
            0x00EA, ["Volume_Down", 9],
            0x00E9, ["Volume_Up", 10],
            0x00B5, ["Media_Next", 11],
            0x00B6, ["Media_Prev", 12],
            0x00B7, ["Media_Stop", 13],
            0x00CD, ["Media_Play_Pause", 14],
            0x00B0, ["Media_Play_Pause", 14],
            0x00B1, ["Media_Play_Pause", 14],
            0x018A, ["Launch_Mail", 15],
            0x0183, ["Launch_Media", 16],
            0x0194, ["Launch_App1", 17],
            0x0192, ["Launch_App2", 18])
        usage := Max(0, Integer(usage))
        if !definitions.Has(usage)
            return ""
        entry := definitions[usage]
        name := entry[1]
        virtualKey := 0
        try virtualKey := Max(0, GetKeyVK(name))
        return {Usage: usage, Name: name, AppCommand: entry[2],
            VK: virtualKey, SC: 0}
    }

    static CreateEvent(usage, phase, device) {
        definition := this.Resolve(usage)
        if !IsObject(definition)
            return ""
        deviceId := "", deviceHandle := ""
        usagePage := this.UsagePage, collectionUsage := this.CollectionUsage
        if Type(device) == "Map" {
            deviceId := device.Get("id", "")
            deviceHandle := device.Get("handle", "")
            usagePage := device.Get("usage_page", usagePage)
            collectionUsage := device.Get("usage", collectionUsage)
        }
        identity := KeyIdentity.Create("keyboard", definition.Name,
            definition.VK, definition.SC, definition.SC > 0xFF,
            deviceId, deviceHandle, usagePage, collectionUsage,
            definition.AppCommand)
        metadata := Map("raw_type", "hid-consumer",
            "usage_page", this.UsagePage,
            "usage_id", definition.Usage,
            "app_command", definition.AppCommand,
            "injected_known", JsonBoolean(false),
            "hook_correlation", JsonBoolean(false))
        return InputEvent.Create(identity, phase, false, false,
            "raw-input", "", metadata)
    }
}

class RawHidConsumerDecoder {
    static InputReportType := 0
    static SuccessStatus := 0x00110000
    static MaximumUsages := 4096
    static PreparsedDataCommand := 0x20000005

    __New() {
        this.PreparsedData := Map()
        this.HeldUsages := Map()
    }

    Decode(packet, device, handle) {
        if !(packet is Buffer)
                || packet.Size < RawInputDecoder.HeaderSize + 8
            throw ValueError("Raw Input HID 数据包过短。")
        packetType := NumGet(packet, 0, "UInt")
        packetSize := NumGet(packet, 4, "UInt")
        if packetType != RawInputDecoder.HidType
                || packetSize != packet.Size
            throw ValueError("Raw Input HID 数据包无效。")
        offset := RawInputDecoder.HeaderSize
        reportSize := NumGet(packet, offset, "UInt")
        reportCount := NumGet(packet, offset + 4, "UInt")
        dataOffset := offset + 8
        availableBytes := packet.Size - dataOffset
        if !reportSize || !reportCount || reportSize > availableBytes
                || reportCount > availableBytes // reportSize
            throw ValueError("Raw Input HID 报告长度无效。")
        preparsedData := this.GetPreparsedData(handle)
        deviceKey := this.HandleKey(handle)
        events := []
        Loop reportCount {
            reportOffset := dataOffset + (A_Index - 1) * reportSize
            activeUsages := this.ReadActiveUsages(preparsedData,
                packet.Ptr + reportOffset, reportSize)
            for event in this.UpdateHeldUsages(deviceKey, activeUsages,
                    device)
                events.Push(event)
        }
        return events
    }

    ReadActiveUsages(preparsedData, reportAddress, reportSize) {
        maximumUsages := DllCall("hid\HidP_MaxUsageListLength", "Int",
            RawHidConsumerDecoder.InputReportType, "UShort",
            ConsumerControlUsage.UsagePage, "Ptr", preparsedData.Ptr,
            "UInt")
        if maximumUsages > RawHidConsumerDecoder.MaximumUsages
            throw Error("HID Consumer Control Usage 数量超过安全上限。")
        if !maximumUsages
            return []
        usageList := Buffer(maximumUsages * 2, 0)
        usageCount := maximumUsages
        status := DllCall("hid\HidP_GetUsages", "Int",
            RawHidConsumerDecoder.InputReportType, "UShort",
            ConsumerControlUsage.UsagePage, "UShort", 0,
            "Ptr", usageList.Ptr, "UInt*", &usageCount,
            "Ptr", preparsedData.Ptr, "Ptr", reportAddress,
            "UInt", reportSize, "UInt")
        if status != RawHidConsumerDecoder.SuccessStatus
            throw Error("无法解析 HID Consumer Control 报告（状态 "
                Format("0x{:08X}", status) "）。")
        if usageCount > maximumUsages
            throw Error("HID Consumer Control Usage 结果越界。")
        usages := []
        Loop usageCount
            usages.Push(NumGet(usageList, (A_Index - 1) * 2, "UShort"))
        return usages
    }

    UpdateHeldUsages(deviceKey, activeUsages, device) {
        active := Map()
        for usage in activeUsages {
            if IsObject(ConsumerControlUsage.Resolve(usage))
                active[Integer(usage)] := true
        }
        previous := this.HeldUsages.Has(deviceKey)
            ? this.HeldUsages[deviceKey] : Map()
        events := []
        for usage in active {
            if previous.Has(usage)
                continue
            event := ConsumerControlUsage.CreateEvent(usage, "down", device)
            if IsObject(event)
                events.Push(event)
        }
        for usage in previous {
            if active.Has(usage)
                continue
            event := ConsumerControlUsage.CreateEvent(usage, "up", device)
            if IsObject(event)
                events.Push(event)
        }
        if active.Count
            this.HeldUsages[deviceKey] := active
        else if this.HeldUsages.Has(deviceKey)
            this.HeldUsages.Delete(deviceKey)
        return events
    }

    GetPreparsedData(handle) {
        deviceKey := this.HandleKey(handle)
        if this.PreparsedData.Has(deviceKey)
            return this.PreparsedData[deviceKey]
        byteCount := 0
        result := DllCall("user32\GetRawInputDeviceInfoW", "Ptr", handle,
            "UInt", RawHidConsumerDecoder.PreparsedDataCommand,
            "Ptr", 0, "UInt*", &byteCount, "UInt")
        if result == 0xFFFFFFFF || !byteCount
            throw OSError(A_LastError, "无法读取 HID 预解析数据长度。")
        if byteCount > RawInputService.MaximumPacketBytes
            throw Error("HID 预解析数据超过安全上限。")
        preparsedData := Buffer(byteCount, 0)
        copiedBytes := byteCount
        result := DllCall("user32\GetRawInputDeviceInfoW", "Ptr", handle,
            "UInt", RawHidConsumerDecoder.PreparsedDataCommand,
            "Ptr", preparsedData.Ptr, "UInt*", &copiedBytes, "UInt")
        if result == 0xFFFFFFFF || result > byteCount
                || copiedBytes > byteCount
            throw OSError(A_LastError, "无法读取 HID 预解析数据。")
        this.PreparsedData[deviceKey] := preparsedData
        return preparsedData
    }

    DropDevice(handle) {
        return this.DropDeviceKey(this.HandleKey(handle))
    }

    DropDeviceKey(deviceKey) {
        deviceKey := String(deviceKey)
        if this.PreparsedData.Has(deviceKey)
            this.PreparsedData.Delete(deviceKey)
        if this.HeldUsages.Has(deviceKey)
            this.HeldUsages.Delete(deviceKey)
        return true
    }

    Clear() {
        this.PreparsedData := Map()
        this.HeldUsages := Map()
        return true
    }

    HandleKey(handle) => Format("0x{:0" (A_PtrSize * 2) "X}", handle)
}

class RawInputService {
    static InputSink := 0x00000100
    static DeviceNotify := 0x00002000
    static Remove := 0x00000001
    static DeviceNameCommand := 0x20000007
    static DeviceInfoCommand := 0x2000000B
    static Arrival := 1
    static Removal := 2
    static MaximumPacketBytes := 1024 * 1024
    static MaximumDevices := 1024

    __New(targetHwnd, eventCallback, identityProvider := "") {
        if !targetHwnd
            throw ValueError("Raw Input 需要有效的目标窗口。")
        if !IsObject(eventCallback)
            throw TypeError("Raw Input 事件回调无效。")
        this.TargetHwnd := targetHwnd
        this.EventCallback := eventCallback
        this.IdentityService := IsObject(identityProvider)
            ? identityProvider : DeviceIdentityService()
        this.Started := false
        this.DevicesRegistered := false
        this.InputMessageRegistered := false
        this.DeviceMessageRegistered := false
        this.Devices := Map()
        this.HeldKeys := Map()
        this.ConsumerDecoder := RawHidConsumerDecoder()
        this.LastCallbackError := ""
        this.CallbackFailureCount := 0
        this.InputCallback := ObjBindMethod(this, "OnRawInput")
        this.DeviceCallback := ObjBindMethod(this, "OnDeviceChange")
    }

    Start() {
        if this.Started
            return false
        if this.DevicesRegistered || this.InputMessageRegistered
                || this.DeviceMessageRegistered
            throw Error("Raw Input 观察器仍有未清理的注册资源。")
        this.LastCallbackError := ""
        this.RegisterDevices(false)
        this.DevicesRegistered := true
        try {
            OnMessage(Win32.WM_INPUT, this.InputCallback)
            this.InputMessageRegistered := true
            OnMessage(Win32.WM_INPUT_DEVICE_CHANGE, this.DeviceCallback)
            this.DeviceMessageRegistered := true
            this.Started := true
            this.RefreshDevices()
            return true
        } catch as startError {
            this.Started := false
            this.HeldKeys.Clear()
            this.ConsumerDecoder.Clear()
            cleanupErrors := this.ReleaseRegistrationResources()
            if cleanupErrors.Length
                throw Error(startError.Message "；启动回滚失败："
                    this.JoinErrors(cleanupErrors), -1, startError)
            throw startError
        }
    }

    Stop() {
        if !this.Started && !this.DevicesRegistered
                && !this.InputMessageRegistered
                && !this.DeviceMessageRegistered
            return false
        this.Started := false
        this.HeldKeys.Clear()
        this.ConsumerDecoder.Clear()
        cleanupErrors := this.ReleaseRegistrationResources()
        if cleanupErrors.Length
            throw Error("Raw Input 清理失败：" this.JoinErrors(cleanupErrors))
        return true
    }

    ReleaseRegistrationResources() {
        errors := []
        this.ReleaseMessageRegistration("InputMessageRegistered",
            Win32.WM_INPUT, this.InputCallback, "输入消息", errors)
        this.ReleaseMessageRegistration("DeviceMessageRegistered",
            Win32.WM_INPUT_DEVICE_CHANGE, this.DeviceCallback,
            "设备变更消息", errors)
        if this.DevicesRegistered {
            try {
                this.RegisterDevices(true)
                this.DevicesRegistered := false
            } catch as registrationError
                errors.Push("设备注销：" registrationError.Message)
        }
        return errors
    }

    ReleaseMessageRegistration(propertyName, message, callback, label, errors) {
        if !this.%propertyName%
            return
        try {
            OnMessage(message, callback, 0)
            this.%propertyName% := false
        } catch as messageError
            errors.Push(label "：" messageError.Message)
    }

    JoinErrors(errors) {
        result := ""
        for index, message in errors
            result .= (index > 1 ? "；" : "") message
        return result
    }

    RegisterDevices(remove) {
        entrySize := 8 + A_PtrSize
        deviceUsages := [[1, 6], [1, 2],
            [ConsumerControlUsage.UsagePage,
                ConsumerControlUsage.CollectionUsage]]
        registrations := Buffer(entrySize * deviceUsages.Length, 0)
        flags := remove ? RawInputService.Remove
            : RawInputService.InputSink | RawInputService.DeviceNotify
        for registrationIndex, deviceUsage in deviceUsages {
            offset := (registrationIndex - 1) * entrySize
            NumPut("UShort", deviceUsage[1], registrations, offset)
            NumPut("UShort", deviceUsage[2], registrations, offset + 2)
            NumPut("UInt", flags, registrations, offset + 4)
            NumPut("Ptr", remove ? 0 : this.TargetHwnd,
                registrations, offset + 8)
        }
        if !DllCall("user32\RegisterRawInputDevices", "Ptr", registrations,
                "UInt", deviceUsages.Length, "UInt", entrySize, "Int")
            throw OSError(A_LastError, "无法注册 Raw Input 设备。")
        return true
    }

    OnRawInput(wParam, lParam, *) {
        if !this.Started
            return
        try this.ProcessRawInput(lParam)
        catch as inputError {
            this.HeldKeys.Clear()
            this.ConsumerDecoder.Clear()
            this.EmitError("raw_input_callback_failed", 0,
                inputError.Message)
        }
        ; WM_INPUT in foreground mode requires DefWindowProc to perform its
        ; packet cleanup. Leaving this callback without a value lets AHK run
        ; that default path; returning the decoded-event count suppresses it
        ; and can make later packets disappear under a dense key chord.
    }

    ProcessRawInput(lParam) {
        packetSize := 0
        headerSize := RawInputDecoder.HeaderSize
        result := DllCall("user32\GetRawInputData", "Ptr", lParam,
            "UInt", 0x10000003, "Ptr", 0, "UInt*", &packetSize,
            "UInt", headerSize, "UInt")
        if result != 0 || packetSize < headerSize
                || packetSize > RawInputService.MaximumPacketBytes
            return this.EmitError("raw_input_read_failed", A_LastError)
        packet := Buffer(packetSize, 0)
        copiedSize := packetSize
        result := DllCall("user32\GetRawInputData", "Ptr", lParam,
            "UInt", 0x10000003, "Ptr", packet, "UInt*", &copiedSize,
            "UInt", headerSize, "UInt")
        if result == 0xFFFFFFFF || result != packetSize
                || copiedSize != packetSize
            return this.EmitError("raw_input_read_failed", A_LastError)
        handle := NumGet(packet, 8, "Ptr")
        device := this.GetOrReadDevice(handle)
        packetType := NumGet(packet, 0, "UInt")
        try events := packetType == RawInputDecoder.HidType
                && device.Get("usage_page", 0)
                    == ConsumerControlUsage.UsagePage
                && device.Get("usage", 0)
                    == ConsumerControlUsage.CollectionUsage
            ? this.ConsumerDecoder.Decode(packet, device, handle)
            : RawInputDecoder.Decode(packet, device)
        catch as decodeError
            return this.EmitError("raw_input_decode_failed", 0,
                decodeError.Message)
        return this.DispatchDecodedEvents(events)
    }

    DispatchDecodedEvents(events) {
        for unifiedEvent in events {
            try this.ApplyRepeatState(unifiedEvent)
            catch as stateError {
                this.HeldKeys.Clear()
                this.ConsumerDecoder.Clear()
                this.EmitError("raw_input_state_failed", 0,
                    stateError.Message)
            }
            this.Emit(unifiedEvent)
        }
        return events.Length
    }

    ApplyRepeatState(unifiedEvent) {
        if unifiedEvent["identity"]["kind"] != "keyboard"
            return
        signature := unifiedEvent["identity"]["device_id"] "|"
            . KeyIdentity.Signature(unifiedEvent["identity"])
        if unifiedEvent["phase"] == "down" {
            unifiedEvent["repeat"] := JsonBoolean(this.HeldKeys.Has(signature))
            this.HeldKeys[signature] := true
        } else if unifiedEvent["phase"] == "up"
                && this.HeldKeys.Has(signature)
            this.HeldKeys.Delete(signature)
    }

    OnDeviceChange(wParam, lParam, *) {
        if !this.Started
            return
        try return this.ProcessDeviceChange(wParam, lParam)
        catch as deviceError {
            this.HeldKeys.Clear()
            this.ConsumerDecoder.Clear()
            return this.EmitError("raw_input_device_change_failed", 0,
                deviceError.Message)
        }
    }

    ProcessDeviceChange(wParam, lParam) {
        handle := lParam
        handleKey := this.FormatHandle(handle)
        if wParam == RawInputService.Arrival {
            device := this.ReadDevice(handle)
            for existingHandle, existingDevice in this.Devices {
                if existingHandle != handleKey
                        && existingDevice["stable_id"] == device["stable_id"] {
                    this.Devices.Delete(existingHandle)
                    this.ConsumerDecoder.DropDeviceKey(existingHandle)
                    this.ClearDeviceHeldKeys(existingDevice["id"])
                    this.Devices[handleKey] := device
                    this.EmitDeviceLifecycle(device, "rebound")
                    return
                }
            }
            this.Devices[handleKey] := device
            this.EmitDeviceLifecycle(device, "arrival")
            return
        }
        if wParam == RawInputService.Removal {
            if !this.Devices.Has(handleKey)
                return false
            device := this.Devices[handleKey]
            this.Devices.Delete(handleKey)
            this.ConsumerDecoder.DropDevice(handle)
            this.ClearDeviceHeldKeys(device["id"])
            this.EmitDeviceLifecycle(device, "removal")
        }
    }

    EmitDeviceLifecycle(device, phase) {
        eventPhase := phase == "rebound" ? "arrival" : phase
        identity := KeyIdentity.Create("device", device["display_name"],
            0, 0, false, device["id"], device["handle"],
            device["usage_page"], device["usage"])
        metadata := Map("device", RuleSpec.Clone(device),
            "lifecycle", phase,
            "hook_correlation", JsonBoolean(false))
        this.Emit(InputEvent.Create(identity, eventPhase, false, false,
            "raw-input-device", "", metadata))
    }

    Emit(unifiedEvent) {
        try return this.EventCallback.Call(unifiedEvent)
        catch as callbackError {
            this.HeldKeys.Clear()
            this.ConsumerDecoder.Clear()
            this.LastCallbackError := callbackError.Message
            this.CallbackFailureCount++
            return false
        }
    }

    EmitError(eventName, errorCode := 0, detail := "") {
        errorData := Map("service_event", eventName,
            "error_code", Max(0, Integer(errorCode)))
        if detail != ""
            errorData["detail"] := String(detail)
        identity := KeyIdentity.Create("device", "Raw Input")
        this.Emit(InputEvent.Create(identity, "arrival", false, false,
            "raw-input-service", "", errorData))
        return false
    }

    RefreshDevices(emitLifecycle := false) {
        previousDevices := this.GetDevices()
        this.ConsumerDecoder.Clear()
        devices := this.EnumerateDevices()
        refreshed := Map()
        for device in devices
            refreshed[device["handle"]] := device
        this.Devices := refreshed
        if emitLifecycle {
            changes := this.IdentityService.Reconcile(previousDevices, devices)
            for device in changes.Removed {
                this.ClearDeviceHeldKeys(device["id"])
                this.EmitDeviceLifecycle(device, "removal")
            }
            for device in changes.Arrived
                this.EmitDeviceLifecycle(device, "arrival")
            for binding in changes.Rebound
                this.EmitDeviceLifecycle(binding["current"], "rebound")
        }
        return this.GetDevices()
    }

    RecoverAfterResume() {
        if !this.Started
            return false
        this.HeldKeys.Clear()
        this.ConsumerDecoder.Clear()
        this.RegisterDevices(false)
        this.DevicesRegistered := true
        return this.RefreshDevices(true)
    }

    GetDevices() {
        result := []
        for handleKey, device in this.Devices
            result.Push(RuleSpec.Clone(device))
        return result
    }

    EnumerateDevices() {
        count := 0
        entrySize := A_PtrSize == 8 ? 16 : 8
        result := DllCall("user32\GetRawInputDeviceList", "Ptr", 0,
            "UInt*", &count, "UInt", entrySize, "Int")
        if result != 0
            throw OSError(A_LastError, "无法读取 Raw Input 设备数量。")
        if count > RawInputService.MaximumDevices
            throw Error("Raw Input 设备数量超过安全上限。")
        if !count
            return []
        listBuffer := Buffer(count * entrySize, 0)
        actualCount := count
        result := DllCall("user32\GetRawInputDeviceList", "Ptr", listBuffer,
            "UInt*", &actualCount, "UInt", entrySize, "Int")
        if result == -1
            throw OSError(A_LastError, "无法枚举 Raw Input 设备。")
        returnedCount := result
        if returnedCount > actualCount || returnedCount > count
                || returnedCount > RawInputService.MaximumDevices
            throw Error("Raw Input 设备枚举结果超过已分配缓冲区。")
        devices := []
        Loop returnedCount {
            offset := (A_Index - 1) * entrySize
            handle := NumGet(listBuffer, offset, "Ptr")
            deviceType := NumGet(listBuffer, offset + A_PtrSize, "UInt")
            if deviceType == 0 || deviceType == 1 {
                devices.Push(this.ReadDevice(handle, deviceType))
                continue
            }
            if deviceType == RawInputDecoder.HidType {
                device := this.ReadDevice(handle, deviceType)
                if device["usage_page"] == ConsumerControlUsage.UsagePage
                        && device["usage"]
                            == ConsumerControlUsage.CollectionUsage
                    devices.Push(device)
            }
        }
        return devices
    }

    GetOrReadDevice(handle) {
        handleKey := this.FormatHandle(handle)
        if !this.Devices.Has(handleKey)
            this.Devices[handleKey] := this.ReadDevice(handle)
        return this.Devices[handleKey]
    }

    ReadDevice(handle, knownType := -1) {
        path := this.ReadDeviceName(handle)
        info := this.ReadDeviceInfo(handle)
        deviceType := knownType >= 0 ? knownType : info["type"]
        typeName := deviceType == 0 ? "mouse"
            : (deviceType == 1 ? "keyboard" : "hid")
        usagePage := info["usage_page"]
        usage := info["usage"]
        if !usagePage
            usagePage := 1
        if !usage
            usage := deviceType == 1 ? 6 : (deviceType == 0 ? 2 : 0)
        vendorId := this.ExtractHexIdentifier(path, "VID")
        productId := this.ExtractHexIdentifier(path, "PID")
        displayName := typeName == "keyboard" ? "键盘"
            : (typeName == "mouse" ? "鼠标" : "HID 设备")
        if vendorId != "" || productId != ""
            displayName .= " " vendorId ":" productId
        device := Map(
            "handle", this.FormatHandle(handle),
            "type", typeName,
            "display_name", displayName,
            "path", path,
            "vendor_id", vendorId,
            "product_id", productId,
            "version", info["version"],
            "usage_page", usagePage,
            "usage", usage,
            "observation_only", JsonBoolean(true))
        identity := this.IdentityService.Build(device)
        for fieldName, value in identity
            device[fieldName] := value
        return device
    }

    ReadDeviceName(handle) {
        characterCount := 0
        result := DllCall("user32\GetRawInputDeviceInfoW", "Ptr", handle,
            "UInt", RawInputService.DeviceNameCommand, "Ptr", 0,
            "UInt*", &characterCount, "UInt")
        if result == 0xFFFFFFFF || !characterCount
            return ""
        capacity := characterCount
        nameBuffer := Buffer((capacity + 1) * 2, 0)
        result := DllCall("user32\GetRawInputDeviceInfoW", "Ptr", handle,
            "UInt", RawInputService.DeviceNameCommand, "Ptr", nameBuffer,
            "UInt*", &characterCount, "UInt")
        if result == 0xFFFFFFFF || result > capacity
                || characterCount > capacity
            return ""
        return RTrim(StrGet(nameBuffer, result, "UTF-16"), Chr(0))
    }

    ReadDeviceInfo(handle) {
        infoBuffer := Buffer(32, 0)
        NumPut("UInt", infoBuffer.Size, infoBuffer, 0)
        size := infoBuffer.Size
        result := DllCall("user32\GetRawInputDeviceInfoW", "Ptr", handle,
            "UInt", RawInputService.DeviceInfoCommand, "Ptr", infoBuffer,
            "UInt*", &size, "UInt")
        if result == 0xFFFFFFFF || result < 8 || result > infoBuffer.Size
                || size > infoBuffer.Size
            return Map("type", 2, "version", 0,
                "usage_page", 0, "usage", 0)
        deviceType := NumGet(infoBuffer, 4, "UInt")
        if deviceType == 2
                && result >= 24
            return Map("type", deviceType,
                "version", NumGet(infoBuffer, 16, "UInt"),
                "usage_page", NumGet(infoBuffer, 20, "UShort"),
                "usage", NumGet(infoBuffer, 22, "UShort"))
        if deviceType != 0 && deviceType != 1
            return Map("type", 2, "version", 0,
                "usage_page", 0, "usage", 0)
        return Map("type", deviceType, "version", 0,
            "usage_page", 1, "usage", deviceType == 1 ? 6 : 2)
    }

    ExtractHexIdentifier(path, prefix) {
        return RegExMatch(path, "i)(?:^|[#&])" prefix "_([0-9A-F]{4})",
            &match) ? StrUpper(match[1]) : ""
    }

    ClearDeviceHeldKeys(deviceId) {
        prefix := String(deviceId) "|"
        stale := []
        for signature in this.HeldKeys {
            if SubStr(signature, 1, StrLen(prefix)) == prefix
                stale.Push(signature)
        }
        for signature in stale
            this.HeldKeys.Delete(signature)
    }

    FormatHandle(handle) {
        return Format("0x{:0" (A_PtrSize * 2) "X}", handle)
    }

    Shutdown() => this.Stop()
}
