#Requires AutoHotkey v2.0.26 64-bit
#SingleInstance Off
#Warn All, StdOut

#Include ..\TestSupport.ahk
#Include ..\..\src\Core\JsonCodec.ahk
#Include ..\..\src\Core\RuleSpec.ahk
#Include ..\..\src\Core\InputEvent.ahk
#Include ..\..\src\Localization\EnglishStrings.ahk
#Include ..\..\src\Localization\TraditionalHongKongStrings.ahk
#Include ..\..\src\Localization\TraditionalTaiwanStrings.ahk
#Include ..\..\src\Localization\JapaneseStrings.ahk
#Include ..\..\src\Localization\VietnameseStrings.ahk
#Include ..\..\src\Localization\KoreanStrings.ahk
#Include ..\..\src\Localization\SpanishStrings.ahk
#Include ..\..\src\Localization\FrenchStrings.ahk
#Include ..\..\src\Localization\PortugueseBrazilStrings.ahk
#Include ..\..\src\Localization\RussianStrings.ahk
#Include ..\..\src\Localization\GermanStrings.ahk
#Include ..\..\src\Localization\ItalianStrings.ahk
#Include ..\..\src\Localization\LocalizationService.ahk
#Include ..\..\src\Input\KeyCaptureSession.ahk

try {
    app := RawCaptureTestApp()
    session := KeyCaptureSession(app)
    AssertTrue(!session.Start("invalid"), "捕获器接受了无效角色")

    session.ObserveRawInputEvent(NewCaptureEvent("keyboard", "LCtrl",
        0xA2, 0x01D, "down", "keyboard-a"))
    session.ObserveRawInputEvent(NewCaptureEvent("keyboard", "LCtrl",
        0xA2, 0x01D, "down", "keyboard-b"))
    AssertTrue(session.Start("source") && app.Runtime.Backend.Suspended,
        "Raw Input 来源捕获没有取得后端暂停所有权")
    session.ObserveRawInputEvent(NewCaptureEvent("keyboard", "A",
        0x41, 0x01E, "down", "keyboard-a"))
    AssertEqual("LCtrl + A", app.LastPreview.RawDisplay,
        "来源捕获没有保留同一设备的预按修饰键")
    AssertEqual(2, app.LastPreview.Keys.Length,
        "来源捕获混入了另一实体键盘的修饰键")
    session.ObserveRawInputEvent(NewCaptureEvent("keyboard", "B",
        0x42, 0x030, "down", "keyboard-b"))
    AssertEqual("LCtrl + A", app.LastPreview.RawDisplay,
        "来源设备确定后仍接受另一实体键盘的输入")
    session.ObserveRawInputEvent(NewCaptureEvent("keyboard", "A",
        0x41, 0x01E, "up", "keyboard-a"))
    session.ObserveRawInputEvent(NewCaptureEvent("keyboard", "LCtrl",
        0xA2, 0x01D, "up", "keyboard-a"))
    session.ObserveRawInputEvent(NewCaptureEvent("keyboard", "B",
        0x42, 0x030, "up", "keyboard-b"))
    session.ObserveRawInputEvent(NewCaptureEvent("keyboard", "LCtrl",
        0xA2, 0x01D, "up", "keyboard-b"))
    AssertTrue(app.CompletedCount == 1 && !session.Active
            && !app.Runtime.Backend.Suspended,
        "同设备组合键释放后没有完成来源捕获并恢复后端")
    sourceCapture := app.CompletedCapture
    AssertEqual("keyboard-a", sourceCapture.DeviceId,
        "来源捕获丢失实体设备身份")
    capturedRule := RuleSpec.CreateFromCaptures("captured-device",
        sourceCapture, NewTargetCapture("C"), "device capture")
    AssertTrue(capturedRule["conditions"].Length == 1
            && capturedRule["conditions"][1]["type"] == "device"
            && capturedRule["conditions"][1]["field"] == "stable_id"
            && capturedRule["conditions"][1]["operator"] == "equals"
            && capturedRule["conditions"][1]["value"] == "keyboard-a",
        "来源录制没有生成稳定实体设备条件")

    AssertTrue(session.Start("target"), "Raw Input 目标捕获无法启动")
    session.ObserveRawInputEvent(NewCaptureEvent("keyboard", "B",
        0x42, 0x030, "down", "keyboard-b"))
    session.ObserveRawInputEvent(NewCaptureEvent("keyboard", "B",
        0x42, 0x030, "up", "keyboard-b"))
    targetCapture := app.CompletedCapture
    targetRule := RuleSpec.CreateFromCaptures("target-not-bound",
        sourceCapture, targetCapture, "target device ignored")
    AssertEqual(1, targetRule["conditions"].Length,
        "目标录制错误增加了第二个设备条件")
    AssertEqual("keyboard-a", targetRule["conditions"][1]["value"],
        "目标录制覆盖了来源实体设备条件")

    completedBeforeMissingDevice := app.CompletedCount
    AssertTrue(session.Start("source"), "缺少设备身份测试无法启动")
    AssertTrue(!session.ObserveRawInputEvent(NewCaptureEvent("keyboard", "D",
            0x44, 0x020, "down", "")),
        "缺少物理设备身份的事件被来源捕获")
    AssertEqual(completedBeforeMissingDevice, app.CompletedCount,
        "缺少物理设备身份的事件完成了捕获")
    session.Cancel()

    AssertTrue(session.Start("source"), "滚轮来源捕获无法启动")
    session.ObserveRawInputEvent(NewCaptureEvent("wheel", "WheelUp",
        0, 0, "wheel", "mouse-a"))
    AssertTrue(!session.Active && app.CompletedCapture.Kind == "wheel"
            && app.CompletedCapture.DeviceId == "mouse-a",
        "Raw Input 滚轮没有作为绑定鼠标的瞬时来源完成")

    app.Settings.EscapeCancelsRecording := true
    cancelledBeforeEscape := app.CancelledCount
    AssertTrue(session.Start("source"), "Esc 取消测试无法启动")
    session.ObserveRawInputEvent(NewCaptureEvent("keyboard", "Escape",
        0x1B, 0x001, "down", "keyboard-a"))
    AssertTrue(!session.Active
            && app.CancelledCount == cancelledBeforeEscape + 1,
        "单独 Esc 没有取消 Raw Input 捕获")

    AssertTrue(session.Start("source"), "设备移除测试无法启动")
    session.ObserveRawInputEvent(NewCaptureEvent("keyboard", "E",
        0x45, 0x012, "down", "keyboard-a"))
    completedBeforeRemoval := app.CompletedCount
    session.ObserveRawInputEvent(NewDeviceRemovalEvent("keyboard-a"))
    AssertTrue(!session.Active && app.CompletedCount == completedBeforeRemoval + 1,
        "捕获设备移除后会话仍卡在按下状态")

    AssertTrue(session.Start("source"), "媒体命令来源拒绝测试无法启动")
    AssertTrue(!session.CompleteAppCommand(10) && session.Active,
        "没有物理身份的 APPCOMMAND 被用作来源")
    session.Cancel()
    AssertTrue(session.Start("target"), "媒体命令目标捕获无法启动")
    AssertTrue(session.CompleteAppCommand(10), "媒体命令目标捕获没有完成")
    AssertTrue(IsObject(app.CompletedCapture)
            && app.CompletedCapture.HasOwnProp("AppCommand")
            && app.CompletedCapture.AppCommand == 10,
        "APPCOMMAND 无法作为不绑定设备的目标")

    WriteTestSuccess("key-capture-session")
} catch as testError {
    FileAppend(testError.Message "`n" testError.Stack, "**")
    ExitApp(1)
}
ExitApp(0)

NewCaptureEvent(kind, name, vk, sc, phase, deviceId) {
    usage := kind == "keyboard" ? 6 : 2
    identity := KeyIdentity.Create(kind, name, vk, sc,
        (sc & 0x100) != 0, deviceId, deviceId, 1, usage)
    return InputEvent.Create(identity, phase, false, false, "raw-input")
}

NewDeviceRemovalEvent(deviceId) {
    device := Map("id", deviceId, "stable_id", deviceId,
        "display_name", deviceId, "type", "keyboard")
    identity := KeyIdentity.Create("device", deviceId)
    return InputEvent.Create(identity, "removal", false, false,
        "raw-input-device", "", Map("device", device))
}

NewTargetCapture(name) {
    return {RawDisplay: name, Display: name, TargetSend: "{" name "}"}
}

class RawCaptureTestBackend {
    __New() {
        this.Suspended := false
        this.SuspendCount := 0
        this.ResumeCount := 0
    }
    Suspend() {
        if this.Suspended
            return false
        this.Suspended := true
        this.SuspendCount++
        return true
    }
    Resume() {
        if !this.Suspended
            return false
        this.Suspended := false
        this.ResumeCount++
        return true
    }
}

class RawCaptureTestApp {
    __New() {
        this.Runtime := {Backend: RawCaptureTestBackend()}
        this.Settings := {EscapeCancelsRecording: true}
        this.CompletedCount := 0
        this.CancelledCount := 0
        this.PreviewCount := 0
        this.LastPreview := ""
        this.CompletedCapture := ""
        this.CompletedRole := ""
        this.Devices := [
            Map("id", "keyboard-a", "stable_id", "keyboard-a",
                "display_name", "Keyboard A", "type", "keyboard"),
            Map("id", "keyboard-b", "stable_id", "keyboard-b",
                "display_name", "Keyboard B", "type", "keyboard"),
            Map("id", "mouse-a", "stable_id", "mouse-a",
                "display_name", "Mouse A", "type", "mouse")]
    }
    GetInputDevices() => RuleSpec.Clone(this.Devices)
    OnCapturePreview(role, capture) {
        this.PreviewCount++
        this.LastPreview := capture
    }
    OnCaptureCompleted(role, capture) {
        this.CompletedCount++
        this.CompletedRole := role
        this.CompletedCapture := capture
    }
    OnCaptureCancelled(*) => this.CancelledCount++
    ShouldCancelCaptureForPointer(*) => false
    PrepareCapturePointerCancellation(*) => true
    FinalizeCapturePointerCancellation(*) => true
    TraceEvent(*) => true
}
