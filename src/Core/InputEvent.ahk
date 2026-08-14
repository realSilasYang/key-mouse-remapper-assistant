class KeyIdentity {
    static Create(kind, name, vk := 0, sc := 0, extended := false,
            deviceId := "", deviceHandle := "", usagePage := 0,
            usage := 0, appCommand := 0) {
        kind := StrLower(Trim(String(kind)))
        name := Trim(String(name))
        if kind == "" || name == ""
            throw ValueError("按键身份必须包含类型和名称。")
        vk := Integer(vk)
        sc := Integer(sc)
        if vk < 0 || vk > 0xFF
            throw ValueError("虚拟键码必须在 0x00 到 0xFF 之间。")
        if sc < 0 || sc > 0x1FF
            throw ValueError("扫描码必须在 0x000 到 0x1FF 之间。")
        if sc > 0xFF
            extended := true
        return Map(
            "kind", kind,
            "name", name,
            "vk", vk,
            "vk_hex", vk ? Format("{:02X}", vk) : "",
            "sc", sc,
            "sc_hex", sc ? Format("{:03X}", sc) : "",
            "extended", JsonBoolean(!!extended),
            "device_id", String(deviceId),
            "device_handle", String(deviceHandle),
            "usage_page", Max(0, Integer(usagePage)),
            "usage", Max(0, Integer(usage)),
            "app_command", Max(0, Integer(appCommand)))
    }

    static FromRuleKey(key) {
        if Type(key) != "Map"
            throw TypeError("规则按键身份必须是对象。")
        vk := key.Has("vk") ? this.ReadCode(key["vk"]) : 0
        sc := key.Has("sc") ? this.ReadCode(key["sc"]) : 0
        extended := key.Has("extended")
            && this.ReadBoolean(key["extended"])
        return this.Create(key.Has("kind") ? key["kind"] : "keyboard",
            key["name"], vk, sc, extended, "", "", 0, 0,
            key.Has("command") ? key["command"] : 0)
    }

    static FromKeyInfo(keyInfo) {
        if !IsObject(keyInfo)
            throw TypeError("录制按键身份无效。")
        command := keyInfo.HasOwnProp("AppCommand") ? keyInfo.AppCommand : 0
        return this.Create(keyInfo.Kind, keyInfo.KeyName,
            keyInfo.VK, keyInfo.SC, (keyInfo.SC & 0x100) != 0,
            "", "", 0, 0, command)
    }

    static FromRawKeyboard(vk, makeCode, flags, device := "") {
        vk := this.NormalizeRawKeyboardVirtualKey(vk, makeCode, flags)
        ; AHK encodes the E0 prefix in bit 0x100 of a scan code. E1 is a
        ; different Raw Input prefix (notably Pause) and must not be folded
        ; into the E0 namespace, where it would collide with NumLock.
        extended := (flags & 0x0002) != 0
        resolvedScanCode := Max(0, Integer(makeCode)) | (extended ? 0x100 : 0)
        keyName := ""
        ; Browser, media and launch keys have dedicated virtual keys. Some
        ; drivers attach a legacy or zero scan code which otherwise resolves
        ; to an unrelated function key, so their VK identity is authoritative.
        if vk >= 0xA6 && vk <= 0xB7
            try keyName := GetKeyName(Format("vk{:02X}", vk))
        if keyName == ""
            try keyName := GetKeyName(Format("vk{:02X}sc{:03X}", vk,
                resolvedScanCode))
        if keyName == "" && vk
            try keyName := GetKeyName(Format("vk{:02X}", vk))
        if keyName == "" && resolvedScanCode
            try keyName := GetKeyName(Format("sc{:03X}", resolvedScanCode))
        if keyName == ""
            keyName := Format("vk{:02X}sc{:03X}", vk, resolvedScanCode)
        deviceId := "", deviceHandle := "", usagePage := 0, usage := 0
        if Type(device) == "Map" {
            deviceId := device.Has("id") ? device["id"] : ""
            deviceHandle := device.Has("handle") ? device["handle"] : ""
            usagePage := device.Has("usage_page") ? device["usage_page"] : 0
            usage := device.Has("usage") ? device["usage"] : 0
        }
        return this.Create("keyboard", keyName, vk, resolvedScanCode, extended,
            deviceId, deviceHandle, usagePage, usage)
    }

    static NormalizeRawKeyboardVirtualKey(vk, makeCode, flags) {
        vk := Max(0, Integer(vk))
        makeCode := Max(0, Integer(makeCode)) & 0xFF
        isExtended := (flags & 0x0002) != 0
        switch vk {
            case 0x10:
                mapped := DllCall("user32\MapVirtualKeyW", "UInt", makeCode,
                    "UInt", 3, "UInt")
                if mapped == 0xA0 || mapped == 0xA1
                    return mapped
                return makeCode == 0x36 ? 0xA1 : 0xA0
            case 0x11:
                return isExtended ? 0xA3 : 0xA2
            case 0x12:
                return isExtended ? 0xA5 : 0xA4
        }
        return vk
    }

    static FromRawPointer(name, device := "") {
        deviceId := "", deviceHandle := "", usagePage := 1, usage := 2
        if Type(device) == "Map" {
            deviceId := device.Has("id") ? device["id"] : ""
            deviceHandle := device.Has("handle") ? device["handle"] : ""
            usagePage := device.Has("usage_page") && device["usage_page"]
                ? device["usage_page"] : usagePage
            usage := device.Has("usage") && device["usage"]
                ? device["usage"] : usage
        }
        kind := RegExMatch(String(name), "i)^Wheel") ? "wheel" : "mouse"
        return this.Create(kind, name, 0, 0, false, deviceId,
            deviceHandle, usagePage, usage)
    }

    static ReadBoolean(value) {
        if value is JsonBoolean
            return value.Value
        if !IsObject(value) && (value == 0 || value == 1)
            return !!value
        throw TypeError("按键身份字段必须是布尔值。")
    }

    static ReadCode(value) {
        return Type(value) == "String" ? Integer("0x" value)
            : Integer(value)
    }

    static Signature(identity) {
        if Type(identity) != "Map"
            throw TypeError("按键身份签名输入必须是对象。")
        kind := StrLower(identity["kind"])
        if identity["sc"]
            return kind ":sc:" StrLower(identity["sc_hex"]) ":"
                . (identity["extended"].Value ? "1" : "0")
        if identity["vk"]
            return kind ":vk:" StrLower(identity["vk_hex"])
        if identity["app_command"]
            return kind ":command:" identity["app_command"]
        return kind ":name:" StrLower(identity["name"])
    }
}

class InputEvent {
    static Create(identity, phase, repeat := false, injected := false,
            origin := "unknown", tick := "", metadata := "") {
        phase := StrLower(Trim(String(phase)))
        allowed := Map("down", true, "up", true, "wheel", true,
            "move", true,
            "arrival", true, "removal", true)
        if !allowed.Has(phase)
            throw ValueError("输入事件阶段无效：" phase)
        if tick == ""
            tick := A_TickCount
        qpc := 0
        frequency := 0
        try DllCall("QueryPerformanceCounter", "Int64*", &qpc)
        try DllCall("QueryPerformanceFrequency", "Int64*", &frequency)
        result := Map(
            "identity", RuleSpec.Clone(identity),
            "phase", phase,
            "repeat", JsonBoolean(!!repeat),
            "injected", JsonBoolean(!!injected),
            "origin", String(origin),
            "tick", Integer(tick),
            "qpc", qpc,
            "qpc_frequency", frequency)
        if metadata != "" {
            if Type(metadata) != "Map"
                throw TypeError("输入事件元数据必须是对象。")
            result["metadata"] := RuleSpec.Clone(metadata)
        }
        return result
    }

    static FromKeyInfo(keyInfo, phase, repeat := false,
            injected := false, origin := "capture") {
        return this.Create(KeyIdentity.FromKeyInfo(keyInfo), phase,
            repeat, injected, origin)
    }

    static FromRuleKey(key, phase, repeat := false,
            origin := "rule-simulation") {
        return this.Create(KeyIdentity.FromRuleKey(key), phase,
            repeat, false, origin)
    }

    static FormatDiagnosticDetail(event, devices := []) {
        if Type(event) != "Map" || !event.Has("identity")
            return ""
        identity := event["identity"]
        parts := []
        if identity.Get("vk_hex", "") != ""
            parts.Push("VK " identity["vk_hex"])
        if identity.Get("sc_hex", "") != ""
            parts.Push("SC " identity["sc_hex"])
        deviceId := String(identity.Get("device_id", ""))
        if deviceId != ""
            parts.Push("来源设备：" this.FormatDeviceDiagnostic(
                this.FindDevice(devices, deviceId), deviceId))
        return this.JoinDiagnosticParts(parts)
    }

    static FindDevice(devices, deviceId) {
        if Type(devices) != "Array"
            return ""
        for device in devices {
            if Type(device) != "Map"
                continue
            if String(device.Get("id", "")) == deviceId
                    || String(device.Get("stable_id", "")) == deviceId
                return device
        }
        return ""
    }

    static FormatDeviceDiagnostic(device, fallbackId) {
        if Type(device) != "Map"
            return String(fallbackId)
        label := Trim(String(device.Get("display_name", "")))
        if label == ""
            label := String(fallbackId)
        identifiers := []
        vendorId := Trim(String(device.Get("vendor_id", "")))
        productId := Trim(String(device.Get("product_id", "")))
        if vendorId != ""
            identifiers.Push("VID " vendorId)
        if productId != ""
            identifiers.Push("PID " productId)
        stableId := Trim(String(device.Get("stable_id", fallbackId)))
        if stableId != ""
            identifiers.Push("设备 ID " stableId)
        return label (identifiers.Length
            ? "（" this.JoinDiagnosticParts(identifiers) "）" : "")
    }

    static JoinDiagnosticParts(parts) {
        result := ""
        for index, part in parts
            result .= (index == 1 ? "" : "；") part
        return result
    }
}
