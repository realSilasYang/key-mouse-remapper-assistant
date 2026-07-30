#Requires AutoHotkey v2.0 64-bit
#SingleInstance Off
#Warn All, StdOut

#Include ..\TestSupport.ahk
#Include ..\..\src\Core\JsonCodec.ahk
#Include ..\..\src\Core\Sha256.ahk
#Include ..\..\src\Core\RuleSpec.ahk
#Include ..\..\src\Core\RuleTimingResolver.ahk
#Include ..\..\src\Core\RuleSpecMigrationService.ahk
#Include ..\..\src\Core\RuleCompiler.ahk
#Include ..\..\src\Core\RuleConditionEvaluator.ahk
#Include ..\..\src\Core\CrossProcessWriteLock.ahk
#Include ..\..\src\Core\RuleConflictAnalyzer.ahk
#Include ..\..\src\Core\RuleSimulationService.ahk

try {
    high := SimulationMapping("high", "F1", "F2", 100, true,
        [Map("type", "application", "field", "process",
            "operator", "equals", "value", "Code.exe")])
    low := SimulationMapping("low", "F1", "F3", 0, false)
    simulator := RuleSimulationService()
    matchedSimulation := simulator.Simulate([low, high],
        Map("trigger", "F1", "phase", "down"),
        Map("application", Map("process", "Code.exe")))
    AssertTrue(matchedSimulation["matched_rules"].Length == 1
            && matchedSimulation["matched_rules"][1] == "high"
            && matchedSimulation["stopped_by"] == "high"
            && matchedSimulation["candidates"][2]["reason"]
                == "stopped_by_rule",
        "模拟器没有按优先级、条件和终止策略形成决策链")
    unrelated := SimulationMapping("unrelated", "F9", "F10", 50, false)
    scopedStop := simulator.Simulate([low, unrelated, high],
        Map("trigger", "F1", "phase", "down"),
        Map("application", Map("process", "Code.exe")))
    AssertTrue(scopedStop["candidates"][2]["reason"] == "trigger_mismatch"
            && scopedStop["candidates"][3]["reason"] == "stopped_by_rule",
        "stop_processing 错误遮蔽了不同来源规则的真实拒绝原因")
    fallbackSimulation := simulator.Simulate([low, high], Map("trigger", "F1"),
        Map("application", Map("process", "Notepad.exe")))
    AssertTrue(fallbackSimulation["matched_rules"].Length == 1
            && fallbackSimulation["matched_rules"][1] == "low"
            && fallbackSimulation["candidates"][1]["reason"]
                == "conditions_rejected",
        "高优先级条件拒绝后没有继续模拟低优先级规则")

    upRule := SimulationMapping("up-rule", "F6", "F7")
    upRule.Spec["from"]["event"] := "up"
    upRule.Spec["to_after_key_up"] := [Map("type", "send", "value", "{F8}")]
    upRule.Spec := RuleSpec.Normalize(upRule.Spec)
    upRule.Descriptor := RuleCompiler.Compile(upRule.Spec)
    upSimulation := simulator.Simulate([upRule],
        Map("trigger", "F6", "phase", "up"))
    AssertTrue(upSimulation["matched_rules"].Length == 1
            && upSimulation["candidates"][1]["actions"].Has("to")
            && upSimulation["candidates"][1]["actions"].Has(
                "to_after_key_up"),
        "up 规则模拟遗漏了运行时会执行的 to 或 to_after_key_up")
    canonicalTrigger := SimulationMapping("canonical-trigger", "<^>+A",
        "F11")
    canonicalSimulation := simulator.Simulate([canonicalTrigger],
        Map("trigger", ">+<^A"))
    AssertTrue(canonicalSimulation["matched_rules"].Length == 1,
        "模拟事件没有使用与编译器一致的热键规范化")
    looseRepeatRejected := false
    try simulator.Simulate([canonicalTrigger],
        Map("trigger", "A", "repeat", "false"))
    catch
        looseRepeatRejected := true
    AssertTrue(looseRepeatRejected,
        "模拟事件把字符串 false 当成了重复事件布尔值")

    cycleA := SimulationMapping("cycle-a", "A", "B")
    cycleB := SimulationMapping("cycle-b", "B", "A")
    prefixShort := SequenceSimulationMapping("seq-short", ["A", "B"])
    prefixLong := SequenceSimulationMapping("seq-long", ["A", "B", "C"])
    sticky := SimulationMapping("sticky", "F4", "LShift", 0, false,
        [], "sticky_modifier")
    graph := RuleConflictAnalyzer().BuildGraph(
        [cycleA, cycleB, prefixShort, prefixLong, sticky])
    AssertTrue(graph["nodes"].Length == 5
            && graph["edges"].Length >= 2
            && graph["cycles"].Length >= 1
            && GraphHasIssue(graph, "output-cycle")
            && GraphHasIssue(graph, "sequence-prefix")
            && GraphHasIssue(graph, "sticky-modifier-risk"),
        "冲突图缺少输出循环、顺序前缀或粘滞风险")

    downRule := SimulationMapping("phase-down", "F12", "F13")
    upPhaseRule := SimulationMapping("phase-up", "F12", "F14")
    upPhaseRule.Spec["from"]["event"] := "up"
    upPhaseRule.Spec := RuleSpec.Normalize(upPhaseRule.Spec)
    upPhaseRule.Descriptor := RuleCompiler.Compile(upPhaseRule.Spec)
    phaseGraph := RuleConflictAnalyzer().BuildGraph([downRule, upPhaseRule])
    AssertTrue(!GraphHasIssue(phaseGraph, "unreachable-rule")
            && !GraphHasIssue(phaseGraph, "chained-trigger"),
        "同一按键的 down/up 规则被错误当成相互冲突")

    compositeA := SimulationMapping("composite-a", "<^A", "{B}")
    compositeB := SimulationMapping("composite-b", "B",
        "{LCtrl down}{A}{LCtrl up}")
    compositeGraph := RuleConflictAnalyzer().BuildGraph(
        [compositeA, compositeB])
    AssertTrue(GraphHasIssue(compositeGraph, "output-cycle")
            && GraphHasEdge(compositeGraph, "composite-b", "composite-a"),
        "复合发送序列中的修饰键组合没有进入输出反馈图")

    keyUpSource := SimulationMapping("key-up-source", "F15", "F16",
        0, false, [], "key_up")
    keyUpTarget := SimulationMapping("key-up-target", "F16", "F17")
    keyUpTarget.Spec["from"]["event"] := "up"
    keyUpTarget.Spec := RuleSpec.Normalize(keyUpTarget.Spec)
    keyUpTarget.Descriptor := RuleCompiler.Compile(keyUpTarget.Spec)
    keyUpGraph := RuleConflictAnalyzer().BuildGraph(
        [keyUpSource, keyUpTarget])
    AssertTrue(GraphHasEdge(keyUpGraph, "key-up-source", "key-up-target"),
        "key_up 输出没有连接到 up 来源规则")

    disabledA := SimulationMapping("disabled-a", "X", "Y")
    disabledB := SimulationMapping("disabled-b", "Y", "X")
    for disabledRule in [disabledA, disabledB] {
        disabledRule.Spec["enabled"] := JsonBoolean(false)
        disabledRule.Descriptor := RuleCompiler.Compile(disabledRule.Spec)
    }
    disabledGraph := RuleConflictAnalyzer().BuildGraph([disabledA, disabledB])
    AssertTrue(disabledGraph["edges"].Length == 0
            && disabledGraph["cycles"].Length == 0,
        "禁用规则仍出现在活动输出边或循环中")
    WriteTestSuccess("rule-simulation")
} catch as simulationError {
    FileAppend(simulationError.Message "`n" simulationError.Stack, "**")
    ExitApp(1)
}
ExitApp(0)

SimulationMapping(id, trigger, output, priority := 0,
        stopProcessing := false, conditions := "", actionType := "send") {
    if Type(conditions) != "Array"
        conditions := []
    spec := Map("schema", 2, "id", id,
        "enabled", JsonBoolean(true),
        "priority", priority, "stop_processing", JsonBoolean(stopProcessing),
        "description", id,
        "display", Map("source", trigger, "target", output,
            "scope", "default", "purpose", "test"),
        "from", Map("hotkey", trigger, "event", "down",
            "key", Map("name", trigger)),
        "conditions", conditions,
        "to", [Map("type", actionType, "value", output)])
    spec := RuleSpec.Normalize(spec)
    return {Mode: "managed", Enabled: true, Spec: spec,
        Descriptor: RuleCompiler.Compile(spec)}
}

SequenceSimulationMapping(id, names) {
    keys := []
    for name in names
        keys.Push(Map("name", name))
    spec := Map("schema", 2, "id", id,
        "enabled", JsonBoolean(true),
        "description", id,
        "display", Map("source", id, "target", "F12",
            "scope", "default", "purpose", "test"),
        "from", Map("sequence", keys, "event", "down"),
        "conditions", [],
        "to", [Map("type", "send", "value", "F12")])
    spec := RuleSpec.Normalize(spec)
    return {Mode: "managed", Enabled: true, Spec: spec,
        Descriptor: RuleCompiler.Compile(spec)}
}

GraphHasIssue(graph, code) {
    for issue in graph["issues"] {
        if issue["code"] == code
            return true
    }
    return false
}

GraphHasEdge(graph, fromId, toId) {
    for edge in graph["edges"] {
        if edge["from"] == fromId && edge["to"] == toId
            return true
    }
    return false
}
