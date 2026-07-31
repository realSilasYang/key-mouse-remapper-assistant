#Requires AutoHotkey v2.0 64-bit
#Warn All, StdOut

#Include ..\TestSupport.ahk
#Include ..\..\src\Core\JsonCodec.ahk
#Include ..\..\src\Core\Sha256.ahk
#Include ..\..\src\Core\RuleSpec.ahk
#Include ..\..\src\Core\RuleTimingResolver.ahk
#Include ..\..\src\Core\RuleSpecMigrationService.ahk
#Include ..\..\src\Core\RuleCompiler.ahk
#Include ..\..\src\Core\RuleConflictAnalyzer.ahk

testJson := '{"z":"中文","enabled":true,"items":[1,false,null,"\u0041"]}'
testDecoded := JsonCodec.Parse(testJson)
AssertEqual("中文", testDecoded["z"], "JSON 中文字符串解析错误")
AssertTrue(testDecoded["enabled"] is JsonBoolean
    && testDecoded["enabled"].Value, "JSON 布尔值解析错误")
AssertTrue(testDecoded["items"][2] is JsonBoolean
    && !testDecoded["items"][2].Value, "JSON false 解析错误")
AssertTrue(testDecoded["items"][3] is JsonNull, "JSON null 解析错误")
AssertEqual("A", testDecoded["items"][4], "JSON Unicode 转义解析错误")
testCanonical := JsonCodec.Stringify(testDecoded, true, true)
AssertTrue(InStr(testCanonical, '"enabled": true')
    && InStr(testCanonical, '"z": "中文"'), "JSON 稳定序列化错误")
AssertEqual('{"only":"value"}',
    JsonCodec.Stringify(Map("only", "value"), false, true),
    "JSON 单字段对象稳定序列化错误")
testHash := Sha256.HexText("abc")
AssertEqual("BA7816BF8F01CFEA414140DE5DAE2223B00361A396177A9CB410FF61F20015AD",
    testHash, "SHA-256 实现错误")

testSpec := Map("schema", 2, "id", "managed-test",
    "enabled", JsonBoolean(true),
    "description", "测试规则",
    "display", Map("source", "LCtrl + A", "target", "F20",
        "scope", "全局", "purpose", "测试"),
    "from", Map("hotkey", "<^a", "event", "down",
        "key", Map("name", "A", "vk", "41", "sc", "01E")),
    "conditions", [],
    "to", [Map("type", "send", "value", "{F20}")])
testNormalized := RuleSpec.Normalize(testSpec)
testDescriptor := RuleCompiler.Compile(testNormalized)
AssertTrue(testNormalized["priority"] == 0
        && testNormalized["stop_processing"].Value,
    "旧规则没有保留源码顺序优先且命中终止的默认语义")
AssertTrue(testNormalized["from"]["modifiers"].Length == 1
        && testNormalized["from"]["modifiers"][1] == "LCtrl",
    "显式 AHK 热键前缀没有进入 Raw Input 修饰键语义")
AssertEqual(JsonCodec.Stringify(testNormalized, false, true),
    JsonCodec.Stringify(RuleSpec.Normalize(testNormalized), false, true),
    "RuleSpec 二次规范化结果不幂等")
AssertEqual("hotkey:<^a", testDescriptor.Signature, "托管规则触发签名错误")
AssertEqual("LCtrl + A", testDescriptor.Source, "托管规则显示来源错误")
reorderedModifierSpec := RuleSpec.Clone(testSpec)
reorderedModifierSpec["id"] := "reordered-modifiers"
reorderedModifierSpec["from"]["hotkey"] := ">+<^A"
canonicalModifierSpec := RuleSpec.Clone(reorderedModifierSpec)
canonicalModifierSpec["id"] := "canonical-modifiers"
canonicalModifierSpec["from"]["hotkey"] := "<^>+A"
AssertEqual(RuleCompiler.Compile(canonicalModifierSpec).Signature,
    RuleCompiler.Compile(reorderedModifierSpec).Signature,
    "语义相同但顺序不同的修饰键没有得到统一触发签名")
AssertEqual(RuleCompiler.Compile(canonicalModifierSpec).DispatchSignature,
    RuleCompiler.Compile(reorderedModifierSpec).DispatchSignature,
    "语义相同但顺序不同的修饰键没有得到统一派发签名")
implicitUpSpec := RuleSpec.Clone(testSpec)
implicitUpSpec["id"] := "implicit-up"
implicitUpSpec["from"].Delete("event")
implicitUpSpec["from"]["hotkey"] := "F8 Up"
implicitUpSpec := RuleSpec.Normalize(implicitUpSpec)
AssertTrue(implicitUpSpec["from"]["event"] == "up"
        && RuleCompiler.Compile(implicitUpSpec).Signature == "hotkey:f8",
    "hotkey 的 Up 后缀没有规范化为独立的 up 阶段")
contradictoryUpSpec := RuleSpec.Clone(testSpec)
contradictoryUpSpec["id"] := "contradictory-up"
contradictoryUpSpec["from"]["hotkey"] := "F8 Up"
failed := false
try RuleSpec.Normalize(contradictoryUpSpec)
catch
    failed := true
AssertTrue(failed, "hotkey Up 后缀与 event=down 的矛盾没有被拒绝")
hotkeyOnlySpec := RuleSpec.Clone(testSpec)
hotkeyOnlySpec["id"] := "hotkey-only"
hotkeyOnlySpec["from"].Delete("key")
failed := false
try RuleSpec.Normalize(hotkeyOnlySpec)
catch
    failed := true
AssertTrue(failed, "当前后端无法执行的 hotkey-only 规则没有被提前拒绝")
for invalidField in ["to_if_alone", "to_if_held_down",
        "to_if_other_key_pressed", "to_delayed_if_invoked"] {
    invalidUpActionSpec := RuleSpec.Clone(testSpec)
    invalidUpActionSpec["id"] := "invalid-up-" invalidField
    invalidUpActionSpec["from"]["event"] := "up"
    invalidUpActionSpec[invalidField] := [
        Map("type", "send", "value", "{F21}")]
    failed := false
    try RuleSpec.Normalize(invalidUpActionSpec)
    catch
        failed := true
    AssertTrue(failed, "up 来源接受了无法执行的 " invalidField)
}
invalidUpRepeatSpec := RuleSpec.Clone(testSpec)
invalidUpRepeatSpec["id"] := "invalid-up-repeat-only"
invalidUpRepeatSpec["from"]["event"] := "up"
invalidUpRepeatSpec["from"]["repeat"] := "only"
failed := false
try RuleSpec.Normalize(invalidUpRepeatSpec)
catch
    failed := true
AssertTrue(failed, "up 来源接受了永远无法命中的 repeat=only")
testBlock := RuleCompiler.BuildManagedBlock(testNormalized)
testRoundTrip := RuleCompiler.ParseManagedSpec(testBlock)
AssertEqual(JsonCodec.Stringify(testNormalized, false, true),
    JsonCodec.Stringify(testRoundTrip, false, true), "托管规则往返不一致")

extensionSpec := RuleSpec.Clone(testSpec)
extensionSpec["x-root"] := Map("owner", "extension")
extensionSpec["display"]["x-display"] := "preserved"
extensionSpec["from"]["x-from"] := 42
extensionSpec["from"]["key"]["x-key"] := Map("usage", 4)
extensionSpec["timing"] := Map("x-timing", "preserved")
extensionSpec["to"][1]["x-action"] := JsonBoolean(true)
extensionSpec["conditions"] := [Map("type", "application",
    "field", "process", "operator", "equals", "value", "Code.exe",
    "x-condition", "preserved")]
extensionNormalized := RuleSpec.Normalize(extensionSpec)
extensionRoundTrip := RuleCompiler.ParseManagedSpec(
    RuleCompiler.BuildManagedBlock(extensionNormalized))
AssertEqual(JsonCodec.Stringify(extensionNormalized, false, true),
    JsonCodec.Stringify(extensionRoundTrip, false, true),
    "RuleSpec 深层未知字段往返丢失")
AssertEqual(4, extensionRoundTrip["from"]["key"]["x-key"]["usage"],
    "from.key 扩展字段没有保留")

prioritySpec := RuleSpec.Clone(testSpec)
prioritySpec["priority"] := 42
prioritySpec["stop_processing"] := JsonBoolean(false)
priorityDescriptor := RuleCompiler.Compile(prioritySpec)
AssertTrue(priorityDescriptor.Priority == 42
        && !priorityDescriptor.StopProcessing,
    "显式优先级或终止策略没有编译到运行时描述符")
invalidPrioritySpec := RuleSpec.Clone(testSpec)
invalidPrioritySpec["priority"] := 100001
failed := false
try RuleSpec.Normalize(invalidPrioritySpec)
catch
    failed := true
AssertTrue(failed, "越界优先级没有被拒绝")

failed := false
try RuleSpec.NormalizeCondition(Map("type", "profile",
    "operator", "equals", "value", "default"))
catch
    failed := true
AssertTrue(failed, "已移除的档案条件仍被接受")
failed := false
try RuleSpec.NormalizeAction(Map("type", "switch_profile", "value", "work"))
catch
    failed := true
AssertTrue(failed, "已移除的档案切换动作仍被接受")
failed := false
try RuleSpec.NormalizeAction(Map("type", "set_variable", "name", "mode",
    "scope", "profile", "value", "work"))
catch
    failed := true
AssertTrue(failed, "已移除的档案变量作用域仍被接受")

legacySpec := RuleSpec.Clone(testSpec)
legacySpec["schema"] := 1
legacySpec.Delete("enabled")
legacySpec["x-legacy"] := "preserved"
legacyMigration := RuleSpecMigrationService.Migrate(legacySpec)
AssertTrue(legacyMigration.Changed && legacyMigration.FromSchema == 1,
    "RuleSpec v1 没有经过显式迁移步骤")
AssertTrue(legacyMigration.Spec["enabled"].Value
        && !legacyMigration.Spec.Has("profile")
        && legacyMigration.Spec["x-legacy"] == "preserved",
    "RuleSpec v1 迁移没有补齐默认值或保留扩展字段")
legacyProfileSpec := RuleSpec.Clone(testSpec)
legacyProfileSpec["profile"] := "work"
legacyProfileMigration := RuleSpecMigrationService.Migrate(legacyProfileSpec)
AssertTrue(legacyProfileMigration.Changed
        && !legacyProfileMigration.Spec.Has("profile"),
    "旧 RuleSpec 档案字段没有迁移到单一全局规则集")
futureSpec := RuleSpec.Clone(testSpec)
futureSpec["schema"] := RuleSpec.CurrentSchema + 1
failed := false
try RuleSpecMigrationService.Migrate(futureSpec)
catch
    failed := true
AssertTrue(failed, "未来 RuleSpec schema 被静默降级")

missingDigestBlock := RegExReplace(testBlock,
    "m)^; @generated-sha256=[^\r\n]*\R?", "")
failed := false
try RuleCompiler.ParseManagedSpec(missingDigestBlock)
catch
    failed := true
AssertTrue(failed, "缺少摘要的托管规则仍被接受")
executableManagedBlock := StrReplace(testBlock, "; @generated-end",
    "F19::Send `"{F20}`"`r`n; @generated-end")
failed := false
try RuleCompiler.ParseManagedSpec(executableManagedBlock)
catch
    failed := true
AssertTrue(failed, "托管规则代码块中的额外可执行 AHK 没有被拒绝")

generatedHotkeySpec := RuleSpec.Clone(testSpec)
generatedHotkeySpec["id"] := "generated-hotkey"
generatedHotkeySpec["from"] := Map("event", "down",
    "key", Map("name", "A"), "modifiers", ["LCtrl"],
    "optional_modifiers", ["any"])
generatedDescriptor := RuleCompiler.Compile(generatedHotkeySpec)
AssertEqual("*<^A", generatedDescriptor.Hotkey,
    "optional_modifiers=any 没有生成通配热键")

recordedModifierSource := {
    RawDisplay: "LCtrl + A", Display: "左侧 Ctrl + A", KeyName: "A",
    SourceSpec: "<^sc01E", Kind: "keyboard", VKHex: "41",
    SCHex: "01E", SC: 0x01E, IsSimultaneous: false,
    Modifiers: [{KeyName: "LCtrl"}]
}
recordedModifierTarget := {
    RawDisplay: "F20", Display: "F20", TargetSend: "{F20}"
}
recordedModifierSpec := RuleSpec.CreateFromCaptures("recorded-modifier",
    recordedModifierSource, recordedModifierTarget, "录制修饰键")
AssertTrue(recordedModifierSpec["from"]["key"]["name"] == "A"
        && recordedModifierSpec["from"]["modifiers"].Length == 1
        && recordedModifierSpec["from"]["modifiers"][1] == "LCtrl",
    "录制组合没有分离主键身份和显示文本或丢失修饰键")

shortCodeSpec := RuleSpec.Clone(testSpec)
shortCodeSpec["id"] := "short-code"
shortCodeSpec["from"]["key"]["sc"] := "1E"
AssertEqual("01E", RuleSpec.Normalize(shortCodeSpec)["from"]["key"]["sc"],
    "短格式扫描码没有规范化为稳定宽度")
extendedCodeSpec := RuleSpec.Clone(testSpec)
extendedCodeSpec["id"] := "extended-code"
extendedCodeSpec["from"]["key"]["sc"] := "1D"
extendedCodeSpec["from"]["key"]["extended"] := JsonBoolean(true)
AssertEqual("11D", RuleSpec.Normalize(extendedCodeSpec)["from"]["key"]["sc"],
    "扩展键标记没有规范化到扫描码身份")
for invalidCode in [
        {Field: "vk", Value: "100"},
        {Field: "sc", Value: "200"}] {
    invalidCodeSpec := RuleSpec.Clone(testSpec)
    invalidCodeSpec["id"] := "invalid-" invalidCode.Field
    invalidCodeSpec["from"]["key"][invalidCode.Field] := invalidCode.Value
    failed := false
    try RuleSpec.Normalize(invalidCodeSpec)
    catch
        failed := true
    AssertTrue(failed, "越界 " invalidCode.Field " 没有被拒绝")
}

recordedSimultaneousSource := {
    RawDisplay: "A + B + RButton", Display: "A + B + 鼠标右键",
    SourceSpec: "sim:rbutton+sc01e+sc030",
    SourceKeys: ["sc01E", "sc030", "RButton"],
    IsSimultaneous: true
}
recordedSimultaneousTarget := {
    RawDisplay: "F20", Display: "F20", TargetSend: "{F20}"
}
recordedSimultaneousSpec := RuleSpec.CreateFromCaptures(
    "recorded-simultaneous", recordedSimultaneousSource,
    recordedSimultaneousTarget, "录制的同时按键")
AssertEqual(3, recordedSimultaneousSpec["from"]["simultaneous"].Length,
    "录制的任意同时按键没有写入 RuleSpec 按键数组")
AssertEqual("sc030",
    recordedSimultaneousSpec["from"]["simultaneous"][2]["name"],
    "RuleSpec 改变了同时按键录制顺序")
AssertEqual(0,
    recordedSimultaneousSpec["timing"]["simultaneous_threshold_ms"],
    "录制规则仍附加了按下时间差限制")
AssertEqual("simultaneous",
    RuleCompiler.Compile(recordedSimultaneousSpec).Mode,
    "录制的多键来源没有编译为同时按键规则")

detailedCaptureSource := {
    RawDisplay: "A + RCtrl", Display: "A + 右侧 Ctrl",
    SourceSpec: "sim:sc01e+sc11d", SourceKeys: ["sc01E", "sc11D"],
    Keys: [
        {KeyName: "A", Kind: "keyboard", VKHex: "41", SCHex: "01E",
            SC: 0x01E},
        {KeyName: "RCtrl", Kind: "keyboard", VKHex: "A3", SCHex: "11D",
            SC: 0x11D}
    ], IsSimultaneous: true
}
detailedSpec := RuleSpec.CreateFromCaptures("detailed-capture",
    detailedCaptureSource, recordedSimultaneousTarget, "完整身份")
AssertTrue(detailedSpec["from"]["simultaneous"][1]["vk"] == "41"
        && detailedSpec["from"]["simultaneous"][1]["sc"] == "01E"
        && !detailedSpec["from"]["simultaneous"][1]["extended"].Value
        && detailedSpec["from"]["simultaneous"][2]["extended"].Value,
    "录制组合没有逐键保留 VK、SC 和 extended 身份")
AssertEqual("sc01E", RuleCompiler.BuildKeyHotkey(
    detailedSpec["from"]["simultaneous"][1]),
    "完整来源身份没有优先编译为扫描码热键")

largeRecordedKeyList := []
Loop 64
    largeRecordedKeyList.Push("vk" Format("{:02X}", A_Index))
largeRecordedSpec := RuleSpec.Clone(recordedSimultaneousSpec)
largeRecordedSpec["id"] := "large-recorded-simultaneous"
largeRecordedSpec["from"]["simultaneous"] := largeRecordedKeyList
AssertEqual(64, RuleSpec.Normalize(largeRecordedSpec)["from"][
    "simultaneous"].Length, "大量同时按键仍受旧的 32 项上限阻挡")

ambiguousSpec := RuleSpec.Clone(testSpec)
ambiguousSpec["from"]["simultaneous"] := ["A", "B"]
failed := false
try RuleSpec.Normalize(ambiguousSpec)
catch
    failed := true
AssertTrue(failed, "hotkey 与 simultaneous 的歧义来源没有被拒绝")

duplicateSimultaneousSpec := RuleSpec.Clone(testSpec)
duplicateSimultaneousSpec["from"] := Map("event", "down",
    "simultaneous", ["A", "a"])
failed := false
try RuleSpec.Normalize(duplicateSimultaneousSpec)
catch
    failed := true
AssertTrue(failed, "simultaneous 重复按键没有被拒绝")

complexUpSpec := RuleSpec.Clone(testSpec)
complexUpSpec["from"] := Map("event", "up",
    "sequence", ["A", "B"])
failed := false
try RuleSpec.Normalize(complexUpSpec)
catch
    failed := true
AssertTrue(failed, "运行时不支持的复杂来源 up 事件没有被拒绝")

complexRepeatOnlySpec := RuleSpec.Clone(recordedSimultaneousSpec)
complexRepeatOnlySpec["id"] := "complex-repeat-only"
complexRepeatOnlySpec["from"]["repeat"] := "only"
failed := false
try RuleSpec.Normalize(complexRepeatOnlySpec)
catch
    failed := true
AssertTrue(failed, "无法定义的复杂来源 repeat=only 没有被明确拒绝")

gestureSpec := RuleSpec.Clone(recordedSimultaneousSpec)
gestureSpec["id"] := "gesture-options"
gestureSpec["from"]["simultaneous_options"] := Map(
    "order", "strict", "release", "all")
gestureSpec["to_if_other_key_pressed"] := [
    Map("type", "send", "value", "{Escape}")]
gestureNormalized := RuleSpec.Normalize(gestureSpec)
AssertTrue(gestureNormalized["from"]["simultaneous_options"]["order"]
        == "strict" && gestureNormalized["from"][
            "simultaneous_options"]["release"] == "all"
        && gestureNormalized["to_if_other_key_pressed"].Length == 1,
    "同时键顺序、释放或 other-key 动作没有规范化")

multiTapSpec := RuleSpec.Clone(testSpec)
multiTapSpec["id"] := "multi-tap"
multiTapSpec["from"]["tap_count"] := 2
multiTapNormalized := RuleSpec.Normalize(multiTapSpec)
AssertTrue(multiTapNormalized["from"]["tap_count"] == 2
        && multiTapNormalized["timing"]["multi_tap_timeout_ms"] == "inherit",
    "多击次数或时间窗口继承标记没有规范化")

timingResolution := RuleTimingResolver.Resolve(
    Map("held_threshold_ms", 350),
    Map("held_threshold_ms", 300, "sequence_timeout_ms", 700,
        "alone_timeout_ms", 400))
AssertTrue(timingResolution.Values["held_threshold_ms"] == 350
        && timingResolution.Sources["held_threshold_ms"] == "rule"
        && timingResolution.Values["sequence_timeout_ms"] == 700
        && timingResolution.Sources["sequence_timeout_ms"] == "global"
        && timingResolution.Values["alone_timeout_ms"] == 400
        && timingResolution.Sources["alone_timeout_ms"] == "global"
        && timingResolution.Values["delayed_action_ms"] == 200
        && timingResolution.Sources["delayed_action_ms"] == "default",
    "两级时间参数覆盖顺序或来源解释错误")

modifierActionSpec := RuleSpec.Clone(testSpec)
modifierActionSpec["id"] := "modifier-actions"
modifierActionSpec["to"] := [
    Map("type", "one_shot_modifier", "value", "LCtrl"),
    Map("type", "sticky_modifier", "value", "RShift")]
modifierActionNormalized := RuleSpec.Normalize(modifierActionSpec)
AssertTrue(modifierActionNormalized["to"][1]["repeat"] == "once"
        && modifierActionNormalized["to"][2]["repeat"] == "once",
    "一次性和粘滞修饰键没有采用防自动连发的默认策略")
fixedRepeatSpec := RuleSpec.Clone(testSpec)
fixedRepeatSpec["id"] := "fixed-repeat-action"
fixedRepeatSpec["to"][1]["repeat_interval_ms"] := 25
AssertEqual(25, RuleSpec.Normalize(fixedRepeatSpec)["to"][1][
    "repeat_interval_ms"], "固定重复间隔没有规范化")
genericModifierSpec := RuleSpec.Clone(modifierActionSpec)
genericModifierSpec["id"] := "generic-modifier-action"
genericModifierSpec["to"][1]["value"] := "Shift"
AssertEqual("Shift", RuleSpec.Normalize(genericModifierSpec)["to"][1][
    "value"], "通用修饰键动作没有被规范化")
invalidModifierSpec := RuleSpec.Clone(genericModifierSpec)
invalidModifierSpec["id"] := "invalid-modifier-action"
invalidModifierSpec["to"][1]["value"] := "Control"
failed := false
try RuleSpec.Normalize(invalidModifierSpec)
catch
    failed := true
AssertTrue(failed, "一次性修饰键接受了未知按键名称")

invalidRepeatSpec := RuleSpec.Clone(testSpec)
invalidRepeatSpec["to"][1]["repeat"] := "sometimes"
failed := false
try RuleSpec.Normalize(invalidRepeatSpec)
catch
    failed := true
AssertTrue(failed, "未知 repeat 策略没有被拒绝")

testSecondSpec := RuleSpec.Clone(testNormalized)
testSecondSpec["id"] := "managed-second"
testFirstMapping := {Mode: "managed", Spec: testNormalized,
    Descriptor: RuleCompiler.Compile(testNormalized)}
testSecondMapping := {Mode: "managed", Spec: testSecondSpec,
    Descriptor: RuleCompiler.Compile(testSecondSpec)}
testIssues := RuleConflictAnalyzer().Analyze(
    [testFirstMapping, testSecondMapping])
AssertTrue(testIssues.Length == 1 && testIssues[1].Code == "unreachable-rule",
    "相同来源和条件没有报告不可达规则")

simultaneousLeftSpec := RuleSpec.Clone(testNormalized)
simultaneousLeftSpec["id"] := "simultaneous-left"
simultaneousLeftSpec["from"] := Map("event", "down",
    "simultaneous", ["A", "B"])
simultaneousRightSpec := RuleSpec.Clone(simultaneousLeftSpec)
simultaneousRightSpec["id"] := "simultaneous-right"
simultaneousRightSpec["from"]["simultaneous"] := ["B", "A"]
simultaneousIssues := RuleConflictAnalyzer().Analyze([
    {Mode: "managed", Spec: RuleSpec.Normalize(simultaneousLeftSpec)},
    {Mode: "managed", Spec: RuleSpec.Normalize(simultaneousRightSpec)}])
AssertTrue(simultaneousIssues.Length == 1
        && simultaneousIssues[1].Code == "unreachable-rule",
    "同时键顺序置换没有识别为同一触发器")

caseLeftSpec := RuleSpec.Clone(testNormalized)
caseLeftSpec["id"] := "case-left"
caseLeftSpec["conditions"] := [Map("type", "application",
    "field", "process", "operator", "equals", "value", "Code.exe")]
caseRightSpec := RuleSpec.Clone(caseLeftSpec)
caseRightSpec["id"] := "case-right"
caseRightSpec["conditions"][1]["value"] := "code.EXE"
caseIssues := RuleConflictAnalyzer().Analyze([
    {Mode: "managed", Spec: RuleSpec.Normalize(caseLeftSpec)},
    {Mode: "managed", Spec: RuleSpec.Normalize(caseRightSpec)}])
AssertTrue(caseIssues.Length == 1
        && caseIssues[1].Code == "unreachable-rule",
    "大小写不敏感的等价条件没有识别为不可达")

disjointLeftSpec := RuleSpec.Clone(caseLeftSpec)
disjointLeftSpec["id"] := "disjoint-left"
disjointLeftSpec["conditions"] := [Map("type", "all", "conditions", [
    Map("type", "application", "field", "process",
        "operator", "equals", "value", "Code.exe")])]
disjointRightSpec := RuleSpec.Clone(disjointLeftSpec)
disjointRightSpec["id"] := "disjoint-right"
disjointRightSpec["conditions"][1]["conditions"][1]["value"] := "notepad.exe"
disjointIssues := RuleConflictAnalyzer().Analyze([
    {Mode: "managed", Spec: RuleSpec.Normalize(disjointLeftSpec)},
    {Mode: "managed", Spec: RuleSpec.Normalize(disjointRightSpec)}])
AssertEqual(0, disjointIssues.Length,
    "嵌套 all 中可证明互斥的条件被误报为冲突")

contradictorySpec := RuleSpec.Clone(caseLeftSpec)
contradictorySpec["id"] := "contradictory"
contradictorySpec["conditions"].Push(Map("type", "application",
    "field", "process", "operator", "equals", "value", "notepad.exe"))
contradictoryIssues := RuleConflictAnalyzer().Analyze([
    {Mode: "managed", Spec: RuleSpec.Normalize(contradictorySpec)}])
AssertTrue(contradictoryIssues.Length == 1
        && contradictoryIssues[1].Code == "unsatisfiable-condition",
    "规则自身的矛盾等值条件没有被阻断")

failed := false
try JsonCodec.Parse('{"a":1,"a":2}')
catch
    failed := true
AssertTrue(failed, "JSON 重复字段没有被拒绝")

deepJson := "0"
Loop JsonParser.MaximumDepth + 1
    deepJson := "[" deepJson "]"
failed := false
try JsonCodec.Parse(deepJson)
catch
    failed := true
AssertTrue(failed, "JSON 解析器没有在规范化前限制嵌套深度")

oversizedActionsSpec := RuleSpec.Clone(testSpec)
oversizedActionsSpec["to"] := []
Loop RuleSpec.MaximumActionsPerField + 1
    oversizedActionsSpec["to"].Push(Map("type", "send", "value", "{F20}"))
failed := false
try RuleSpec.Normalize(oversizedActionsSpec)
catch
    failed := true
AssertTrue(failed, "超出上限的动作数组没有被拒绝")

deepCondition := Map("type", "application", "field", "process",
    "operator", "equals", "value", "Code.exe")
Loop RuleSpec.MaximumConditionDepth
    deepCondition := Map("type", "not", "condition", deepCondition)
deepConditionSpec := RuleSpec.Clone(testSpec)
deepConditionSpec["conditions"] := [deepCondition]
failed := false
try RuleSpec.Normalize(deepConditionSpec)
catch
    failed := true
AssertTrue(failed, "过深的条件树没有被拒绝")

longCommand := ""
Loop RuleSpec.MaximumRunCommandLength + 1
    longCommand .= "x"
longRunSpec := RuleSpec.Clone(testSpec)
longRunSpec["to"] := [Map("type", "run", "value", longCommand)]
failed := false
try RuleSpec.Normalize(longRunSpec)
catch
    failed := true
AssertTrue(failed, "超长 run 命令没有被拒绝")

cyclicCloneValue := Map()
cyclicCloneValue["self"] := cyclicCloneValue
failed := false
try RuleSpec.Clone(cyclicCloneValue)
catch as cloneCycleError
    failed := InStr(cloneCycleError.Message, "循环引用") > 0
AssertTrue(failed, "RuleSpec 克隆没有拒绝循环引用")
sharedCloneChild := Map("value", 1)
sharedCloneResult := RuleSpec.Clone([sharedCloneChild, sharedCloneChild])
AssertTrue(sharedCloneResult.Length == 2
        && ObjPtr(sharedCloneResult[1]) != ObjPtr(sharedCloneResult[2]),
    "RuleSpec 克隆错误保留了共享容器别名")

failed := false
try Sha256.HexBuffer(Buffer(1, 0), 2)
catch as shaRangeError
    failed := InStr(shaRangeError.Message, "缓冲区范围") > 0
AssertTrue(failed, "SHA-256 接受了超出输入缓冲区的字节数")

WriteTestSuccess("rule-spec")
