#Requires AutoHotkey v2.0.26 64-bit
#SingleInstance Off
#Warn All, StdOut

#Include ..\TestSupport.ahk
#Include ..\..\src\Core\JsonCodec.ahk
#Include ..\..\src\Core\Sha256.ahk
#Include ..\..\src\Core\RuleSpec.ahk
#Include ..\..\src\Core\DeviceIdentityService.ahk
#Include ..\..\src\Core\InputEvent.ahk
#Include ..\..\src\Core\InputBackend.ahk
#Include ..\..\src\Platform\Win32.ahk
#Include ..\..\src\Input\RawInputService.ahk
#Include ..\..\src\Core\RawInputBackend.ahk

try {
    hostGui := Gui("+ToolWindow -Caption")
    hostGui.Show("Hide w1 h1")
    realServiceBackend := RawInputBackend(hostGui.Hwnd)
    AssertTrue(realServiceBackend.RawInput is RawInputService,
        "未注入测试服务时没有构造真实 RawInputService")
    realServiceBackend.Shutdown()
    hostGui.Destroy()

    testDevices := [NewBackendDevice("keyboard-a", "Keyboard A", "keyboard"),
        NewBackendDevice("keyboard-b", "Keyboard B", "keyboard"),
        NewBackendDevice("mouse-a", "Mouse A", "mouse")]
    service := RawInputBackendTestService(testDevices)
    forwarded := []
    backend := RawInputBackend(0, (event) => forwarded.Push(event), service)
    capture := RawInputBackendTestCapture(backend)

    keyA := Map("kind", "keyboard", "name", "A", "vk", "41",
        "sc", "01E", "extended", JsonBoolean(false))
    ctrl := Map("kind", "keyboard", "name", "LCtrl", "vk", "A2",
        "sc", "01D", "extended", JsonBoolean(false))
    simple := {Kind: "simple", Phase: "down",
        Callback: ObjBindMethod(capture, "MatchSimple"),
        Triggers: [Map("key", keyA, "modifiers", ["LCtrl"],
            "allow_extra_modifiers", JsonBoolean(false))]}
    backend.Replace([simple])
    backend.StartObservation(ObjBindMethod(capture, "ObserveComplex"))

    backend.OnRawInput(NewBackendKeyEvent("LCtrl", 0xA2, 0x01D,
        "down", "keyboard-a"))
    backend.OnRawInput(NewBackendKeyEvent("A", 0x41, 0x01E,
        "down", "keyboard-b"))
    AssertEqual(0, capture.SimpleCount,
        "一把键盘的修饰键错误匹配了另一把键盘的主键")
    AssertEqual(2, capture.ComplexCount,
        "Raw Input 规则观察器没有收到完整物理事件流")

    backend.OnRawInput(NewBackendKeyEvent("A", 0x41, 0x01E,
        "down", "keyboard-a"))
    AssertEqual(1, capture.SimpleCount,
        "同一实体键盘的修饰组合没有匹配")
    AssertEqual("keyboard-a", capture.LastDeviceId,
        "规则回调期间没有暴露当前实体设备")
    AssertTrue(backend.GetCurrentEventDevice() == "",
        "规则回调结束后仍泄露上一事件设备")

    backend.OnRawInput(NewBackendKeyEvent("LCtrl", 0xA2, 0x01D,
        "up", "keyboard-a"))
    backend.OnRawInput(NewBackendKeyEvent("A", 0x41, 0x01E,
        "down", "keyboard-a"))
    AssertEqual(1, capture.SimpleCount,
        "修饰键释放后仍被视为按住")

    backend.OnRawInput(NewBackendKeyEvent("LCtrl", 0xA2, 0x01D,
        "down", "keyboard-a"))
    removedIdentity := KeyIdentity.Create("device", "Keyboard A",
        0, 0, false, "keyboard-a", "keyboard-a")
    backend.OnRawInput(InputEvent.Create(removedIdentity, "removal",
        false, false, "raw-input-device", "",
        Map("lifecycle", "removal")))
    backend.OnRawInput(NewBackendKeyEvent("A", 0x41, 0x01E,
        "down", "keyboard-a"))
    AssertEqual(1, capture.SimpleCount,
        "设备拔出后仍残留该设备的修饰键状态")

    beforeSuspend := capture.ComplexCount
    backend.Suspend()
    backend.OnRawInput(NewBackendKeyEvent("A", 0x41, 0x01E,
        "down", "keyboard-a"))
    AssertEqual(beforeSuspend, capture.ComplexCount,
        "暂停的 Raw Input 后端仍执行规则")
    AssertTrue(forwarded.Length >= 5,
        "暂停规则执行时 Raw Input 观察流被错误停止")
    backend.Resume()

    noDevice := NewBackendKeyEvent("A", 0x41, 0x01E, "down", "")
    backend.OnRawInput(noDevice)
    AssertEqual(beforeSuspend, capture.ComplexCount,
        "没有物理设备身份的输入触发了规则")

    wheelRule := {Kind: "simple", Phase: "down",
        Callback: ObjBindMethod(capture, "MatchWheel"),
        Triggers: [Map("key", Map("kind", "wheel", "name", "WheelUp"),
            "modifiers", [], "allow_extra_modifiers", JsonBoolean(false))]}
    backend.Replace([wheelRule])
    backend.OnRawInput(InputEvent.Create(KeyIdentity.Create("wheel", "WheelUp",
        0, 0, false, "mouse-a"), "wheel", false, false, "raw-input"))
    AssertEqual(1, capture.WheelCount,
        "Raw Input 滚轮没有按瞬时按下事件执行")

    sourceCapture := {RawDisplay: "LCtrl + A", Display: "左侧 Ctrl + A",
        KeyName: "A", Modifiers: [{KeyName: "LCtrl"}],
        IsSimultaneous: false, SourceSpec: "<^sc01E", Kind: "keyboard",
        VKHex: "41", SCHex: "01E", SC: 0x01E,
        DeviceId: "keyboard-a", DeviceDisplayName: "Keyboard A"}
    targetCapture := {RawDisplay: "B", Display: "B", TargetSend: "{B}"}
    capturedRule := RuleSpec.CreateFromCaptures("device-capture",
        sourceCapture, targetCapture, "device rule")
    AssertTrue(capturedRule["conditions"].Length == 1
            && capturedRule["conditions"][1]["type"] == "device"
            && capturedRule["conditions"][1]["field"] == "stable_id"
            && capturedRule["conditions"][1]["value"] == "keyboard-a",
        "来源录制没有生成稳定实体设备条件")

    capture.SimpleCount := 0
    capturedFrom := capturedRule["from"]
    capturedRegistration := {Kind: "simple", Phase: "down",
        Callback: ObjBindMethod(capture, "MatchSimple"),
        Triggers: [Map("key", capturedFrom["key"],
            "modifiers", capturedFrom["modifiers"],
            "allow_extra_modifiers", JsonBoolean(false))]}
    backend.Replace([capturedRegistration])
    backend.OnRawInput(NewBackendKeyEvent("A", 0x41, 0x01E,
        "down", "keyboard-a"))
    AssertEqual(0, capture.SimpleCount,
        "录制的 Ctrl+A 被裸 A 错误触发")
    backend.OnRawInput(NewBackendKeyEvent("LCtrl", 0xA2, 0x01D,
        "down", "keyboard-a"))
    backend.OnRawInput(NewBackendKeyEvent("A", 0x41, 0x01E,
        "down", "keyboard-a"))
    AssertEqual(1, capture.SimpleCount,
        "录制的 Ctrl+A 没有按修饰键语义触发")

    capture.SimpleCount := 0
    backend.Replace([{Kind: "simple", Phase: "down",
        Callback: ObjBindMethod(capture, "MatchSimple"),
        Triggers: [Map("key", keyA, "modifiers", [],
            "allow_extra_modifiers", JsonBoolean(false))]}])
    backend.OnRawInput(NewBackendKeyEvent("A", 0x41, 0x030,
        "down", "keyboard-a"))
    AssertEqual(0, capture.SimpleCount,
        "SC 规则被同 VK 或同名称的另一实体键旁路匹配")
    invalidIdentityRejected := false
    try RawInputKeyMatcher.GetRuleSignature(Map("kind", "keyboard",
        "name", "invalid", "sc", "FFFF"))
    catch
        invalidIdentityRejected := true
    AssertTrue(invalidIdentityRejected,
        "Raw Input 直接注册路径接受了越界扫描码")

    backend.Shutdown()
    AssertTrue(service.ShutdownCount == 1,
        "Raw Input 后端没有关闭其服务")
    WriteTestSuccess("raw-input-backend")
} catch as testError {
    FileAppend(testError.Message "`n" testError.Stack, "**")
    ExitApp(1)
}
ExitApp(0)

NewBackendDevice(id, name, type) {
    return Map("id", id, "stable_id", id, "display_name", name,
        "type", type, "handle", id, "path", "test:" id,
        "usage_page", 1, "usage", type == "keyboard" ? 6 : 2)
}

NewBackendKeyEvent(name, vk, sc, phase, deviceId) {
    identity := KeyIdentity.Create("keyboard", name, vk, sc, false,
        deviceId, deviceId)
    return InputEvent.Create(identity, phase, false, false, "raw-input")
}

class RawInputBackendTestService {
    __New(devices) {
        this.Devices := RuleSpec.Clone(devices)
        this.Started := true
        this.ShutdownCount := 0
    }

    Start() {
        this.Started := true
        return true
    }

    Stop() {
        this.Started := false
        return true
    }

    Shutdown() {
        this.ShutdownCount++
        this.Started := false
        return true
    }

    GetDevices() => RuleSpec.Clone(this.Devices)

    FindDevice(deviceId) {
        for device in this.Devices {
            if device["id"] == deviceId
                return RuleSpec.Clone(device)
        }
        return ""
    }

    RecoverAfterResume() => this.GetDevices()
}

class RawInputBackendTestCapture {
    __New(backend) {
        this.Backend := backend
        this.SimpleCount := 0
        this.ComplexCount := 0
        this.WheelCount := 0
        this.LastDeviceId := ""
    }

    MatchSimple(*) {
        this.SimpleCount++
        device := this.Backend.GetCurrentEventDevice()
        this.LastDeviceId := Type(device) == "Map" ? device["id"] : ""
        return true
    }

    ObserveComplex(*) {
        this.ComplexCount++
        return false
    }

    MatchWheel(*) {
        this.WheelCount++
        return true
    }
}
