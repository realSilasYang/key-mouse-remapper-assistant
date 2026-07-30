class WindowsContextService {
    __New(platform := "") {
        this.Platform := IsObject(platform) ? platform
            : WindowsContextPlatform()
    }

    Build(variableStore := "", devices := "", eventDevice := "") {
        foreground := this.Platform.GetForegroundContext()
        processId := foreground["process_id"]
        applicationId := processId
            ? this.GetApplicationUserModelId(processId) : ""
        keyboardLayout := this.Platform.GetKeyboardLayout(
            foreground["thread_id"])
        layoutText := keyboardLayout
            ? Format("{:08X}", keyboardLayout & 0xFFFFFFFF) : ""
        languageText := keyboardLayout
            ? Format("{:04X}", keyboardLayout & 0xFFFF) : ""
        sessionState := this.GetSessionState()
        deviceContext := this.BuildDeviceContext(devices, eventDevice)
        builtins := Map(
            "administrator", JsonBoolean(A_IsAdmin),
            "remote_session", RuleSpec.Clone(sessionState["remote"]),
            "remote_session_known", RuleSpec.Clone(
                sessionState["remote_known"]),
            "session_locked", RuleSpec.Clone(sessionState["locked"]),
            "session_lock_known", RuleSpec.Clone(
                sessionState["lock_known"]),
            "input_language", languageText,
            "device_count", deviceContext["items"].Length)
        variables := IsObject(variableStore)
            ? variableStore.BuildContext(builtins) : builtins
        return Map(
            "application", Map("process", foreground["process"],
                "path", foreground["process_path"], "pid", processId,
                "aumid", applicationId),
            "window", Map("title", foreground["title"],
                "class", foreground["class"],
                "hwnd", foreground["hwnd"],
                "thread_id", foreground["thread_id"],
                "focused_control", foreground["focused_control"],
                "focused_text", foreground["focused_text"],
                "focused_hwnd", foreground["focused_hwnd"],
                "focused_class", foreground["focused_class"],
                "focus_source", foreground["focus_source"]),
            "variables", variables,
            "input_source", Map("layout", layoutText,
                "language_id", languageText,
                "available", JsonBoolean(keyboardLayout != 0),
                "thread_id", foreground["thread_id"]),
            "session", sessionState,
            "device", deviceContext,
            "builtin", builtins)
    }

    BuildDeviceContext(devices, eventDevice := "") {
        items := Type(devices) == "Array" ? RuleSpec.Clone(devices) : []
        indexes := Map(
            "ids", Map(),
            "stable_ids", Map(),
            "exact_path_ids", Map(),
            "hardware_ids", Map(),
            "container_ids", Map(),
            "serials", Map(),
            "instance_ids", Map(),
            "types", Map(),
            "vendor_ids", Map(),
            "product_ids", Map(),
            "match_keys", Map())
        for item in items {
            if Type(item) != "Map"
                continue
            this.AddDeviceIndex(indexes["ids"], item, "id")
            this.AddDeviceIndex(indexes["ids"], item, "stable_id")
            this.AddDeviceIndex(indexes["stable_ids"], item, "stable_id")
            this.AddDeviceIndex(indexes["exact_path_ids"], item,
                "exact_path_id")
            this.AddDeviceIndex(indexes["hardware_ids"], item,
                "hardware_id")
            this.AddDeviceIndex(indexes["container_ids"], item,
                "container_id")
            this.AddDeviceIndex(indexes["serials"], item, "serial")
            this.AddDeviceIndex(indexes["instance_ids"], item,
                "instance_id")
            this.AddDeviceIndex(indexes["types"], item, "type")
            this.AddDeviceIndex(indexes["vendor_ids"], item, "vendor_id")
            this.AddDeviceIndex(indexes["product_ids"], item, "product_id")
            if item.Has("match_keys") && Type(item["match_keys"]) == "Array" {
                for matchKey in item["match_keys"]
                    this.AddIndexValue(indexes["match_keys"], matchKey)
            }
        }
        hasCurrent := Type(eventDevice) == "Map" || (IsObject(eventDevice)
            && !(eventDevice is JsonNull))
        result := Map("items", items, "count", items.Length,
            "present", JsonBoolean(items.Length > 0),
            "current", hasCurrent ? RuleSpec.Clone(eventDevice) : JsonNull(),
            "scope", hasCurrent ? "event_source" : "present_devices")
        presence := Map()
        for indexName, index in indexes {
            result[indexName] := index
            presence[indexName] := RuleSpec.Clone(index)
        }
        result["presence"] := presence
        return result
    }

    AddDeviceIndex(index, item, fieldName) {
        if item.Has(fieldName)
            this.AddIndexValue(index, item[fieldName])
    }

    AddIndexValue(index, value) {
        if IsObject(value)
            return false
        text := Trim(String(value))
        if text == ""
            return false
        index[text] := JsonBoolean(true)
        return true
    }

    GetApplicationUserModelId(processId) {
        return this.Platform.GetApplicationUserModelId(processId)
    }

    GetSessionState() {
        return this.Platform.GetSessionState()
    }
}

class WindowsContextPlatform {
    static WtsActive := 0
    static WtsConnected := 1
    static WtsDisconnected := 4
    static WtsIdle := 5

    GetForegroundContext() {
        Loop 3 {
            hwnd := DllCall("user32\GetForegroundWindow", "Ptr")
            result := this.NewForegroundContext(hwnd)
            if !hwnd
                return result

            processId := 0
            threadId := DllCall("user32\GetWindowThreadProcessId", "Ptr", hwnd,
                "UInt*", &processId, "UInt")
            if !threadId || !processId
                continue
            result["thread_id"] := threadId
            result["process_id"] := processId
            try result["process"] := WinGetProcessName("ahk_id " hwnd)
            try result["process_path"] := WinGetProcessPath("ahk_id " hwnd)
            try result["title"] := WinGetTitle("ahk_id " hwnd)
            try result["class"] := WinGetClass("ahk_id " hwnd)

            focus := this.GetFocusedControl(hwnd, threadId)
            for name, value in focus
                result[name] := value

            currentHwnd := DllCall("user32\GetForegroundWindow", "Ptr")
            currentProcessId := 0
            currentThreadId := currentHwnd == hwnd
                ? DllCall("user32\GetWindowThreadProcessId", "Ptr", hwnd,
                    "UInt*", &currentProcessId, "UInt") : 0
            if currentHwnd == hwnd && currentThreadId == threadId
                    && currentProcessId == processId
                return result
        }
        result := this.NewForegroundContext()
        result["focus_source"] := "unstable_foreground"
        return result
    }

    NewForegroundContext(hwnd := 0) {
        return Map(
            "hwnd", hwnd,
            "thread_id", 0,
            "process_id", 0,
            "process", "",
            "process_path", "",
            "title", "",
            "class", "",
            "focused_control", "",
            "focused_text", "",
            "focused_hwnd", 0,
            "focused_class", "",
            "focus_source", "none")
    }

    GetFocusedControl(hwnd, threadId) {
        focusedHwnd := 0
        source := "none"
        if threadId {
            info := Buffer(A_PtrSize == 8 ? 72 : 48, 0)
            NumPut("UInt", info.Size, info, 0)
            if DllCall("user32\GetGUIThreadInfo", "UInt", threadId,
                    "Ptr", info, "Int") {
                focusedHwnd := NumGet(info,
                    A_PtrSize == 8 ? 16 : 12, "Ptr")
                source := "get_gui_thread_info"
            }
        }
        focusControl := ""
        if !focusedHwnd && hwnd {
            try focusControl := ControlGetFocus("ahk_id " hwnd)
            if focusControl != "" {
                try focusedHwnd := ControlGetHwnd(focusControl,
                    "ahk_id " hwnd)
                if focusedHwnd
                    source := "control_get_focus"
                else
                    focusControl := ""
            }
        }

        focusClass := ""
        focusText := ""
        if focusedHwnd {
            focusedRoot := DllCall("user32\GetAncestor", "Ptr", focusedHwnd,
                "UInt", 2, "Ptr")
            if focusedRoot != hwnd {
                focusedHwnd := 0
                focusControl := ""
                source := "unrelated_focus"
            }
        }
        if focusedHwnd {
            try focusClass := WinGetClass("ahk_id " focusedHwnd)
            if focusControl == ""
                try focusControl := ControlGetClassNN(focusedHwnd)
            try focusText := ControlGetText(focusedHwnd)
        }
        return Map(
            "focused_control", focusControl,
            "focused_text", focusText,
            "focused_hwnd", focusedHwnd,
            "focused_class", focusClass,
            "focus_source", source)
    }

    GetKeyboardLayout(threadId) {
        if !threadId
            return 0
        return DllCall("user32\GetKeyboardLayout", "UInt", threadId,
            "UPtr")
    }

    GetApplicationUserModelId(processId) {
        processHandle := DllCall("kernel32\OpenProcess", "UInt", 0x1000,
            "Int", false, "UInt", processId, "Ptr")
        if !processHandle
            return ""
        try {
            length := 0
            result := DllCall("kernel32\GetApplicationUserModelId",
                "Ptr", processHandle, "UInt*", &length, "Ptr", 0, "UInt")
            if result != 122 || length < 2 || length > 65536
                return ""
            aumidBuffer := Buffer(length * 2, 0)
            result := DllCall("kernel32\GetApplicationUserModelId",
                "Ptr", processHandle, "UInt*", &length, "Ptr", aumidBuffer,
                "UInt")
            return result == 0 ? StrGet(aumidBuffer, "UTF-16") : ""
        } finally DllCall("kernel32\CloseHandle", "Ptr", processHandle)
    }

    GetSessionState() {
        session := this.GetCurrentProcessSession()
        sessionId := session["known"] ? session["value"] : 0
        connection := session["known"]
            ? this.QueryConnectionState(sessionId)
            : Map("known", false, "value", -1, "error", session["error"])
        protocol := session["known"]
            ? this.QueryClientProtocol(sessionId)
            : Map("known", false, "value", -1, "error", session["error"])
        lock := session["known"]
            ? this.QueryLockState(sessionId)
            : Map("known", false, "locked", false,
                "source", "unavailable", "error", session["error"])
        desktop := this.ProbeInputDesktop()

        if protocol["known"] {
            remote := JsonBoolean(protocol["value"] != 0)
            remoteKnown := JsonBoolean(true)
            remoteSource := "wts_client_protocol"
        } else {
            remote := JsonBoolean(this.GetRemoteSessionMetric())
            remoteKnown := JsonBoolean(true)
            remoteSource := "sm_remote_session_fallback"
        }
        locked := lock["known"] ? JsonBoolean(lock["locked"])
            : JsonNull()
        state := this.ResolveSessionState(connection, lock, desktop)
        return Map(
            "state", state,
            "locked", locked,
            "lock_known", JsonBoolean(lock["known"]),
            "lock_source", lock["source"],
            "lock_error", lock["error"],
            "remote", remote,
            "remote_known", remoteKnown,
            "remote_source", remoteSource,
            "protocol", protocol["known"]
                ? this.ProtocolName(protocol["value"]) : "unknown",
            "protocol_type", protocol["known"]
                ? protocol["value"] : JsonNull(),
            "connection_state", connection["known"]
                ? this.ConnectionStateName(connection["value"]) : "unknown",
            "connection_state_code", connection["known"]
                ? connection["value"] : JsonNull(),
            "desktop_state", desktop["state"],
            "desktop_error", desktop["error"],
            "session_id", session["known"] ? sessionId : JsonNull(),
            "session_id_known", JsonBoolean(session["known"]),
            "session_error", session["error"])
    }

    GetCurrentProcessSession() {
        processId := DllCall("kernel32\GetCurrentProcessId", "UInt")
        sessionId := 0
        if DllCall("kernel32\ProcessIdToSessionId", "UInt", processId,
                "UInt*", &sessionId, "Int")
            return Map("known", true, "value", sessionId, "error", 0)
        return Map("known", false, "value", 0, "error", A_LastError)
    }

    QueryConnectionState(sessionId) {
        return this.QueryWtsScalar(sessionId, 8, 4, "Int")
    }

    QueryClientProtocol(sessionId) {
        return this.QueryWtsScalar(sessionId, 16, 2, "UShort")
    }

    QueryLockState(sessionId) {
        bufferPointer := 0
        byteCount := 0
        if !DllCall("wtsapi32\WTSQuerySessionInformationW", "Ptr", 0,
                "UInt", sessionId, "Int", 25, "Ptr*", &bufferPointer,
                "UInt*", &byteCount, "Int")
            return Map("known", false, "locked", false,
                "source", "wts_session_info_ex", "error", A_LastError)
        try {
            ; This project is 64-bit only. WTSINFOEX.Level is followed by an
            ; aligned WTSINFOEX_LEVEL1; SessionFlags is at byte offset 16.
            if !bufferPointer || byteCount < 20
                return Map("known", false, "locked", false,
                    "source", "wts_session_info_ex", "error", 13)
            level := NumGet(bufferPointer, 0, "UInt")
            flags := NumGet(bufferPointer, 16, "Int")
            if level != 1 || (flags != 0 && flags != 1)
                return Map("known", false, "locked", false,
                    "source", "wts_session_info_ex", "error", 13)
            return Map("known", true, "locked", flags == 0,
                "source", "wts_session_info_ex", "error", 0)
        } finally DllCall("wtsapi32\WTSFreeMemory", "Ptr", bufferPointer)
    }

    QueryWtsScalar(sessionId, infoClass, minimumBytes, valueType) {
        bufferPointer := 0
        byteCount := 0
        if !DllCall("wtsapi32\WTSQuerySessionInformationW", "Ptr", 0,
                "UInt", sessionId, "Int", infoClass,
                "Ptr*", &bufferPointer, "UInt*", &byteCount, "Int")
            return Map("known", false, "value", -1,
                "error", A_LastError)
        try {
            if !bufferPointer || byteCount < minimumBytes
                return Map("known", false, "value", -1, "error", 13)
            return Map("known", true,
                "value", NumGet(bufferPointer, 0, valueType), "error", 0)
        } finally DllCall("wtsapi32\WTSFreeMemory", "Ptr", bufferPointer)
    }

    ProbeInputDesktop() {
        desktopHandle := DllCall("user32\OpenInputDesktop", "UInt", 0,
            "Int", false, "UInt", 0x0001, "Ptr")
        if !desktopHandle
            return Map("state", "unavailable", "error", A_LastError)
        DllCall("user32\CloseDesktop", "Ptr", desktopHandle)
        return Map("state", "accessible", "error", 0)
    }

    GetRemoteSessionMetric() {
        return DllCall("user32\GetSystemMetrics", "Int", 0x1000, "Int")
            != 0
    }

    ResolveSessionState(connection, lock, desktop) {
        if connection["known"]
                && connection["value"] != WindowsContextPlatform.WtsActive
            return this.ConnectionStateName(connection["value"])
        if lock["known"]
            return lock["locked"] ? "locked" : "active"
        return "unknown"
    }

    ConnectionStateName(state) {
        switch state {
            case 0: return "active"
            case 1: return "connected"
            case 2: return "connect_query"
            case 3: return "shadow"
            case 4: return "disconnected"
            case 5: return "idle"
            case 6: return "listen"
            case 7: return "reset"
            case 8: return "down"
            case 9: return "init"
        }
        return "unknown"
    }

    ProtocolName(protocol) {
        switch protocol {
            case 0: return "console"
            case 2: return "rdp"
        }
        return protocol > 0 ? "remote" : "unknown"
    }
}
