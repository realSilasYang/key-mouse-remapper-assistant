#Requires AutoHotkey v2.0 64-bit
#Warn All, StdOut

#Include ..\TestSupport.ahk
#Include ..\..\src\Core\JsonCodec.ahk
#Include ..\..\src\Core\RuleSpec.ahk
#Include ..\..\src\Core\InputEvent.ahk

try {
    looseExtendedRejected := false
    try KeyIdentity.FromRuleKey(Map("kind", "keyboard", "name", "A",
        "extended", "false"))
    catch
        looseExtendedRejected := true
    AssertTrue(looseExtendedRejected,
        "规则按键身份把字符串 false 当成了扩展键布尔值")

    rightControl := KeyIdentity.FromRuleKey(Map(
        "name", "RCtrl", "kind", "keyboard",
        "vk", "A3", "sc", "11D",
        "extended", JsonBoolean(true)))
    AssertTrue(rightControl["vk"] == 0xA3
            && rightControl["sc"] == 0x11D
            && rightControl["extended"].Value,
        "规则键身份没有保留 VK、SC 或 extended")
    AssertEqual("keyboard:sc:11d:1",
        KeyIdentity.Signature(rightControl),
        "扩展扫描码身份签名错误")

    rejectedRanges := 0
    for invalidIdentity in [
            {VK: 0x100, SC: 0},
            {VK: 0, SC: 0x200},
            {VK: -1, SC: 0}] {
        try KeyIdentity.Create("keyboard", "invalid",
            invalidIdentity.VK, invalidIdentity.SC)
        catch
            rejectedRanges++
    }
    AssertEqual(3, rejectedRanges,
        "KeyIdentity 接受了越界或负数 VK/SC")

    createdEvent := InputEvent.Create(rightControl, "down", true, true,
        "test-hook", 1234)
    AssertTrue(createdEvent["phase"] == "down"
            && createdEvent["repeat"].Value
            && createdEvent["injected"].Value
            && createdEvent["origin"] == "test-hook"
            && createdEvent["tick"] == 1234
            && createdEvent["qpc_frequency"] > 0,
        "统一输入事件缺少阶段、标志、来源或高精度时间")
    cloned := RuleSpec.Clone(createdEvent)
    AssertEqual(JsonCodec.Stringify(createdEvent, false, true),
        JsonCodec.Stringify(cloned, false, true),
        "统一输入事件不是稳定 JSON 数据结构")

    capturedInfo := {Kind: "keyboard", KeyName: "LShift",
        VK: 0xA0, SC: 0x02A}
    captured := InputEvent.FromKeyInfo(capturedInfo, "up", false, false,
        "capture-hook")
    AssertEqual("keyboard:sc:02a:0",
        KeyIdentity.Signature(captured["identity"]),
        "录制键身份没有进入统一事件模型")
    WriteTestSuccess("input-event")
} catch as testError {
    FileAppend(testError.Message "`n" testError.Stack, "**")
    ExitApp(1)
}
ExitApp(0)
