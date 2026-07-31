#Requires AutoHotkey v2.0.26 64-bit
#SingleInstance Off
#Warn All, StdOut

#Include ..\TestSupport.ahk
#Include ..\..\src\Core\JsonCodec.ahk
#Include ..\..\src\Core\Sha256.ahk
#Include ..\..\src\Core\RuleSpec.ahk
#Include ..\..\src\Core\DeviceIdentityService.ahk
#Include ..\..\src\Core\InputEvent.ahk
#Include ..\..\src\Platform\Win32.ahk
#Include ..\..\src\Input\RawInputObservationPolicy.ahk
#Include ..\..\src\Input\RawInputService.ahk

try {
    keyboardPacket := Buffer(RawInputDecoder.HeaderSize + 16, 0)
    NumPut("UInt", RawInputDecoder.KeyboardType, keyboardPacket, 0)
    NumPut("UInt", keyboardPacket.Size, keyboardPacket, 4)
    NumPut("UShort", 0x11D, keyboardPacket,
        RawInputDecoder.HeaderSize)
    NumPut("UShort", 0x0002, keyboardPacket,
        RawInputDecoder.HeaderSize + 2)
    NumPut("UShort", 0xA3, keyboardPacket,
        RawInputDecoder.HeaderSize + 6)
    NumPut("UInt", 0x0100, keyboardPacket,
        RawInputDecoder.HeaderSize + 8)
    testDevice := Map("id", "raw-test", "handle", "0x01",
        "usage_page", 1, "usage", 6)
    keyboardEvents := RawInputDecoder.Decode(keyboardPacket, testDevice)
    AssertEqual(1, keyboardEvents.Length,
        "Raw Input 键盘包没有生成单一事件")
    keyboardEvent := keyboardEvents[1]
    AssertTrue(keyboardEvent["phase"] == "down"
            && keyboardEvent["identity"]["vk"] == 0xA3
            && keyboardEvent["identity"]["sc"] == 0x11D
            && keyboardEvent["identity"]["extended"].Value
            && keyboardEvent["identity"]["device_id"] == "raw-test"
            && !keyboardEvent["metadata"]["hook_correlation"].Value,
        "Raw Input 键盘身份、阶段或关联边界错误")

    mousePacket := Buffer(RawInputDecoder.HeaderSize + 24, 0)
    NumPut("UInt", RawInputDecoder.MouseType, mousePacket, 0)
    NumPut("UInt", mousePacket.Size, mousePacket, 4)
    NumPut("UShort", 0x0001 | 0x0400, mousePacket,
        RawInputDecoder.HeaderSize + 4)
    NumPut("Short", 120, mousePacket,
        RawInputDecoder.HeaderSize + 6)
    NumPut("Int", 12, mousePacket, RawInputDecoder.HeaderSize + 12)
    NumPut("Int", -7, mousePacket, RawInputDecoder.HeaderSize + 16)
    mouseEvents := RawInputDecoder.Decode(mousePacket, Map(
        "id", "mouse-test", "handle", "0x02",
        "usage_page", 1, "usage", 2))
    AssertEqual(3, mouseEvents.Length,
        "组合鼠标包没有保留按钮、滚轮和移动事件")
    AssertTrue(mouseEvents[1]["identity"]["name"] == "LButton"
            && mouseEvents[1]["phase"] == "down"
            && mouseEvents[2]["identity"]["name"] == "WheelUp"
            && mouseEvents[2]["phase"] == "wheel"
            && mouseEvents[3]["phase"] == "move"
            && mouseEvents[3]["metadata"]["delta_x"] == 12
            && mouseEvents[3]["metadata"]["delta_y"] == -7,
        "Raw Input 鼠标事件拆分错误")
    AssertTrue(RawInputObservationPolicy.ShouldForwardToGui(
            keyboardEvent, false)
        && RawInputObservationPolicy.ShouldForwardToGui(
            mouseEvents[1], false)
        && RawInputObservationPolicy.ShouldForwardToGui(
            mouseEvents[2], false)
        && !RawInputObservationPolicy.ShouldForwardToGui(
            mouseEvents[3], false)
        && RawInputObservationPolicy.ShouldForwardToGui(
            mouseEvents[3], true),
        "GUI 观察策略没有默认过滤鼠标移动或原始观察未恢复完整事件流")

    malformedRejected := false
    try RawInputDecoder.Decode(Buffer(8, 0))
    catch
        malformedRejected := true
    AssertTrue(malformedRejected, "过短 Raw Input 数据包未被拒绝")
    declaredShortKeyboard := Buffer(RawInputDecoder.HeaderSize + 16, 0)
    NumPut("UInt", RawInputDecoder.KeyboardType, declaredShortKeyboard, 0)
    NumPut("UInt", RawInputDecoder.HeaderSize, declaredShortKeyboard, 4)
    declaredShortRejected := false
    try RawInputDecoder.Decode(declaredShortKeyboard)
    catch
        declaredShortRejected := true
    AssertTrue(declaredShortRejected,
        "Raw Input 键盘正文越过报文头声明长度仍被解码")
    declaredShortMouse := Buffer(RawInputDecoder.HeaderSize + 24, 0)
    NumPut("UInt", RawInputDecoder.MouseType, declaredShortMouse, 0)
    NumPut("UInt", RawInputDecoder.HeaderSize + 8, declaredShortMouse, 4)
    declaredShortRejected := false
    try RawInputDecoder.Decode(declaredShortMouse)
    catch
        declaredShortRejected := true
    AssertTrue(declaredShortRejected,
        "Raw Input 鼠标正文越过报文头声明长度仍被解码")
    rawWindow := Gui("+ToolWindow")
    observedRawEvents := []
    rawObserver := RawInputService(rawWindow.Hwnd,
        event => observedRawEvents.Push(event))

    isolatedUp := RuleSpec.Clone(keyboardEvent)
    isolatedUp["phase"] := "up"
    isolatedUp["identity"]["device_id"] := "raw-isolated"
    AssertEqual(1, rawObserver.DispatchDecodedEvents([isolatedUp]),
        "孤立释放事件没有继续分派")
    AssertTrue(rawObserver.HeldKeys.Count == 0
            && observedRawEvents.Length == 1
            && observedRawEvents[1]["phase"] == "up",
        "未见过按下事件的释放不应丢失或残留状态")
    rawObserver.DispatchDecodedEvents([RuleSpec.Clone(isolatedUp)])
    AssertTrue(rawObserver.HeldKeys.Count == 0
            && observedRawEvents.Length == 2,
        "重复释放事件不应抛错或停止分派")

    firstDeviceDown := RuleSpec.Clone(keyboardEvent)
    firstDeviceDown["identity"]["device_id"] := "raw-device-a"
    secondDeviceDown := RuleSpec.Clone(keyboardEvent)
    secondDeviceDown["identity"]["device_id"] := "raw-device-b"
    rawObserver.DispatchDecodedEvents([firstDeviceDown, secondDeviceDown])
    AssertTrue(rawObserver.HeldKeys.Count == 2,
        "不同设备的同一按键没有独立维护按下状态")
    firstDeviceUp := RuleSpec.Clone(firstDeviceDown)
    firstDeviceUp["phase"] := "up"
    rawObserver.DispatchDecodedEvents([firstDeviceUp])
    AssertTrue(rawObserver.HeldKeys.Count == 1,
        "一个设备的释放错误清除了另一设备的按下状态")
    rawObserver.HeldKeys.Clear()
    staleUp := RuleSpec.Clone(secondDeviceDown)
    staleUp["phase"] := "up"
    rawObserver.DispatchDecodedEvents([staleUp])
    AssertTrue(rawObserver.HeldKeys.Count == 0,
        "停止或恢复清空状态后的旧释放事件不应恢复残留状态")

    malformedEvent := RuleSpec.Clone(keyboardEvent)
    malformedEvent.Delete("identity")
    beforeMalformed := observedRawEvents.Length
    rawObserver.DispatchDecodedEvents([malformedEvent])
    AssertTrue(observedRawEvents.Length == beforeMalformed + 2
            && observedRawEvents[beforeMalformed + 1]["origin"]
                == "raw-input-service"
            && observedRawEvents[beforeMalformed + 2] == malformedEvent,
        "状态处理异常没有转为诊断事件并继续分派原事件")

    failingObserver := RawInputService(rawWindow.Hwnd,
        (*) => ThrowRawInputCallbackFailure())
    failingObserver.DispatchDecodedEvents([RuleSpec.Clone(firstDeviceDown)])
    AssertTrue(failingObserver.CallbackFailureCount == 1
            && InStr(failingObserver.LastCallbackError, "注入的分发失败") > 0
            && failingObserver.HeldKeys.Count == 0,
        "Raw Input 分发回调异常被静默吞掉或留下了重复键状态")

    AssertTrue(rawObserver.Start(), "Raw Input 观察器无法启动")
    enumeratedDevices := rawObserver.GetDevices()
    AssertTrue(Type(enumeratedDevices) == "Array",
        "Raw Input 设备枚举没有返回数组")
    AssertTrue(rawObserver.Stop(), "Raw Input 观察器无法停止")
    retryObserver := RetryableRawInputService(rawWindow.Hwnd, (*) => 0)
    AssertTrue(retryObserver.Start(), "可重试 Raw Input 观察器无法启动")
    retryObserver.FailNextRemoval := true
    removalFailed := false
    try retryObserver.Stop()
    catch as removalError
        removalFailed := InStr(removalError.Message, "设备注销") > 0
    AssertTrue(removalFailed && !retryObserver.Started
            && retryObserver.DevicesRegistered
            && !retryObserver.InputMessageRegistered
            && !retryObserver.DeviceMessageRegistered,
        "Raw Input 注销失败没有保留可重试设备状态或清理消息回调")
    AssertTrue(retryObserver.Stop() && !retryObserver.DevicesRegistered,
        "Raw Input 注销失败后的第二次停止没有完成清理")
    rawWindow.Destroy()
    WriteTestSuccess("raw-input-service")
} catch as testError {
    FileAppend(testError.Message "`n" testError.Stack, "**")
    ExitApp(1)
}
ExitApp(0)

class RetryableRawInputService extends RawInputService {
    __New(targetHwnd, eventCallback) {
        this.FailNextRemoval := false
        this.RegistrationCalls := []
        super.__New(targetHwnd, eventCallback)
    }

    RegisterDevices(remove) {
        this.RegistrationCalls.Push(remove ? "remove" : "add")
        if remove && this.FailNextRemoval {
            this.FailNextRemoval := false
            throw Error("注入的设备注销失败")
        }
        return true
    }
}

ThrowRawInputCallbackFailure() {
    throw Error("注入的分发失败")
}
