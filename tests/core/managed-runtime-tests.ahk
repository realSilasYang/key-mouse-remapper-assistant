#Requires AutoHotkey v2.0 64-bit
#SingleInstance Off
#Warn All, StdOut

#Include ..\TestSupport.ahk
#Include ..\..\src\Core\JsonCodec.ahk
#Include ..\..\src\Core\Sha256.ahk
#Include ..\..\src\Core\RuleSpec.ahk
#Include ..\..\src\Core\InputEvent.ahk
#Include ..\..\src\Core\RuleTimingResolver.ahk
#Include ..\..\src\Core\RuleSpecMigrationService.ahk
#Include ..\..\src\Core\RuleCompiler.ahk
#Include ..\..\src\Core\RuleConflictAnalyzer.ahk
#Include ..\..\src\Core\RuleConditionEvaluator.ahk
#Include ..\..\src\Core\ManagedRuleStateMachine.ahk
#Include ..\..\src\Core\RuleScheduler.ahk
#Include ..\..\src\Core\OutputLedger.ahk
#Include ..\..\src\Core\CrossProcessWriteLock.ahk
#Include ..\..\src\Core\ScopedVariableStore.ahk
#Include ..\..\src\Core\InputBackend.ahk
#Include ..\..\src\Core\ManagedRuleRuntime.ahk

testFailure := ""
try {
    clock := TestRuntimeClock()
    executedGroups := []
    stateMachine := ManagedRuleStateMachine(
        (actions, descriptor, fieldName, *) => executedGroups.Push(fieldName),
        "", ObjBindMethod(clock, "Now"))
    stateDescriptor := BuildRuntimeDescriptor("state-rule", "F20",
        Map("to", [VariableAction("down", 1)],
            "to_if_alone", [VariableAction("alone", 1)],
            "to_if_held_down", [VariableAction("held", 1)],
            "to_after_key_up", [VariableAction("up", 1)],
            "to_delayed_if_invoked", [VariableAction("invoked", 1)],
            "to_delayed_if_canceled", [VariableAction("canceled", 1)]))
    AssertTrue(stateMachine.Begin(stateDescriptor, "key:f20"),
        "状态机无法开始")
    AssertEqual("to", executedGroups[1], "按下动作没有立即执行")
    stateMachine.Interrupt("key:a")
    clock.Tick := 220
    AssertTrue(stateMachine.FireHeld("state-rule"), "长按动作没有触发")
    AssertTrue(stateMachine.ResolveDelayed("state-rule"),
        "延迟分支没有解析")
    stateMachine.Release("state-rule")
    AssertEqual("to_if_held_down", executedGroups[2],
        "被打断的长按动作错误")
    AssertEqual("to_delayed_if_canceled", executedGroups[3],
        "被打断后没有执行延迟取消分支")
    AssertEqual("to_after_key_up", executedGroups[4],
        "松开动作没有执行")
    AssertEqual(4, executedGroups.Length,
        "被打断或长按后仍错误执行单击动作")

    otherGroups := []
    otherStateMachine := ManagedRuleStateMachine(
        (actions, descriptor, fieldName, *) => otherGroups.Push(fieldName),
        "", ObjBindMethod(clock, "Now"))
    otherDescriptor := BuildRuntimeDescriptor("other-key-rule", "F19",
        Map("to_if_other_key_pressed", [VariableAction("other", 1)]))
    otherStateMachine.Begin(otherDescriptor, "key:f19")
    otherStateMachine.Interrupt("key:a")
    otherStateMachine.Interrupt("key:b")
    AssertTrue(otherGroups.Length == 2
            && otherGroups[2] == "to_if_other_key_pressed",
        "按下其他键分支没有执行一次且仅一次")
    otherStateMachine.CancelAll()

    failingStateMachine := ManagedRuleStateMachine(
        (actions, descriptor, fieldName, *) => ThrowManagedStateAction(fieldName),
        "", ObjBindMethod(clock, "Now"))
    beginFailed := false
    try failingStateMachine.Begin(stateDescriptor, "key:f20")
    catch
        beginFailed := true
    AssertTrue(beginFailed && !failingStateMachine.States.Count,
        "按下动作失败后状态机残留了无法再次触发的活动状态")

    executedGroups := []
    clock.Tick := 1000
    stateMachine.Begin(stateDescriptor, "key:f20")
    clock.Tick := 1100
    stateMachine.Release("state-rule")
    AssertEqual("to_if_alone", executedGroups[2],
        "短按没有执行 alone 分支")
    AssertEqual("to_delayed_if_canceled", executedGroups[3],
        "提前松开没有执行延迟取消分支")
    AssertEqual("to_after_key_up", executedGroups[4],
        "短按松开动作错误")

    app := TestRuntimeApp()
    backend := TestManagedBackend()
    runtime := ManagedRuleRuntime(app, backend, false)
    managedOne := BuildManagedMapping("managed-one", "F22",
        [VariableAction("simple", 1)])
    report := runtime.ApplyMappings([managedOne])
    AssertEqual(1, report.Applied, "简单托管规则没有应用")
    AssertTrue(report.Registrations >= 1, "简单托管规则没有动态注册")
    for testGroupKey, testGroup in runtime.Groups {
        if testGroup.Down.Length {
            runtime.HandleSimpleGroup(testGroupKey, "down")
            break
        }
    }
    AssertEqual(1, runtime.Variables["simple"],
        "简单规则动作没有执行")
    candidateEvent := FindRuntimeEvent(app.Events, "candidate_accepted",
        "managed-one")
    actionEvent := FindRuntimeEvent(app.Events, "action_executed",
        "managed-one")
    AssertTrue(IsObject(candidateEvent)
            && candidateEvent.Fields.Data.Has("context")
            && candidateEvent.Fields.Data.Has("steps")
            && candidateEvent.Fields.Data.Has("duration_us")
            && IsObject(actionEvent)
            && actionEvent.Fields.Data.Has("action")
            && actionEvent.Fields.Data.Has("variables")
            && actionEvent.Fields.Data.Has("duration_us"),
        "规则候选、条件、上下文、变量或阶段耗时诊断不完整")

    lowPriority := BuildManagedMapping("priority-low", "F21",
        [VariableAction("priority_low", 1)])
    lowPriority.Spec["priority"] := 1
    lowPriority.Descriptor := RuleCompiler.Compile(lowPriority.Spec)
    highPriority := BuildManagedMapping("priority-high", "F21", [
        VariableAction("priority_high", 1)])
    highPriority.Spec["priority"] := 50
    highPriority.Spec["stop_processing"] := JsonBoolean(false)
    highPriority.Descriptor := RuleCompiler.Compile(highPriority.Spec)
    priorityReport := runtime.ApplyMappings([lowPriority, highPriority])
    AssertTrue(priorityReport.Applied == 2
            && HasIssue(priorityReport.Issues, "chained-trigger"),
        "允许继续处理的同来源规则被错误判定为不可达")
    for priorityGroupKey, priorityGroup in runtime.Groups {
        if priorityGroup.Down.Length {
            AssertEqual("priority-high", priorityGroup.Down[1].Id,
                "同来源规则没有按显式优先级排序")
            runtime.HandleSimpleGroup(priorityGroupKey, "down")
            break
        }
    }
    AssertTrue(runtime.Variables.Has("priority_high")
            && runtime.Variables.Has("priority_low"),
        "stop_processing=false 没有继续执行后续匹配规则")

    stoppingHigh := BuildManagedMapping("stopping-high", "F21", [
        VariableAction("stopping_high", 1)])
    stoppingHigh.Spec["priority"] := 100
    stoppingHigh.Descriptor := RuleCompiler.Compile(stoppingHigh.Spec)
    stoppedLow := BuildManagedMapping("stopped-low", "F21", [
        VariableAction("stopped_low", 1)])
    stoppingReport := runtime.ApplyMappings([stoppedLow, stoppingHigh])
    AssertTrue(stoppingReport.Applied == 1
            && HasIssue(stoppingReport.Issues, "unreachable-rule"),
        "高优先级终止规则没有阻止不可达的后续规则")
    for stoppingGroupKey, stoppingGroup in runtime.Groups {
        if stoppingGroup.Down.Length {
            runtime.HandleSimpleGroup(stoppingGroupKey, "down")
            break
        }
    }
    AssertTrue(runtime.Variables.Has("stopping_high")
            && !runtime.Variables.Has("stopped_low"),
        "stop_processing=true 仍执行了后续匹配规则")

    ignoreRepeat := BuildManagedMapping("repeat-ignore", "F18", [
        VariableAction("repeat_ignore", 1)])
    ignoreRepeat.Spec["from"]["repeat"] := "ignore"
    ignoreRepeat.Descriptor := RuleCompiler.Compile(ignoreRepeat.Spec)
    onlyRepeat := BuildManagedMapping("repeat-only", "F18", [
        VariableAction("repeat_only", 1)])
    onlyRepeat.Spec["from"]["repeat"] := "only"
    onlyRepeat.Descriptor := RuleCompiler.Compile(onlyRepeat.Spec)
    repeatPolicyReport := runtime.ApplyMappings([ignoreRepeat, onlyRepeat])
    AssertEqual(2, repeatPolicyReport.Applied,
        "互斥的来源重复策略被错误判定为冲突")
    for policyGroupKey, policyGroup in runtime.Groups {
        if policyGroup.Down.Length {
            runtime.HandleSimpleGroup(policyGroupKey, "down")
            runtime.HandleSimpleGroup(policyGroupKey, "down")
            runtime.HandleSimpleGroup(policyGroupKey, "up")
            break
        }
    }
    AssertTrue(runtime.Variables.Has("repeat_ignore")
            && runtime.Variables.Has("repeat_only"),
        "来源 ignore/only 重复策略没有分别匹配首次和重复回调")

    multiTap := BuildManagedMapping("double-tap", "F17", [
        VariableAction("double_tap", 1)])
    multiTap.Spec["from"]["tap_count"] := 2
    multiTap.Descriptor := RuleCompiler.Compile(multiTap.Spec)
    runtime.ApplyMappings([multiTap])
    for tapGroupKey, tapGroup in runtime.Groups {
        if tapGroup.Down.Length {
            runtime.HandleSimpleGroup(tapGroupKey, "down")
            AssertTrue(!runtime.Variables.Has("double_tap"),
                "多击规则在达到次数前提前执行")
            runtime.HandleSimpleGroup(tapGroupKey, "down")
            break
        }
    }
    AssertEqual(1, runtime.Variables["double_tap"],
        "多击规则达到次数后没有执行")

    fixedRepeat := BuildManagedMapping("fixed-repeat", "F16", [
        Map("type", "set_variable", "name", "fixed_repeat", "value", 1,
            "repeat", "repeat", "repeat_interval_ms", 20)])
    repeatRuntime := TestableManagedRuleRuntime(app, TestManagedBackend(), false)
    repeatRuntime.ApplyMappings([fixedRepeat])
    for fixedGroupKey, fixedGroup in repeatRuntime.Groups {
        if fixedGroup.Down.Length {
            repeatRuntime.HandleSimpleGroup(fixedGroupKey, "down")
            break
        }
    }
    initialRepeatEvents := CountRuleEvents(app.Events, "action_executed",
        "fixed-repeat")
    repeatRuntime.Scheduler.RunDue(
        DllCall("kernel32\GetTickCount64", "UInt64") + 50)
    AssertTrue(CountRuleEvents(app.Events, "action_executed", "fixed-repeat")
            > initialRepeatEvents, "固定重复间隔没有由统一调度器执行")
    for fixedGroupKey, fixedGroup in repeatRuntime.Groups {
        if fixedGroup.Down.Length {
            repeatRuntime.HandleSimpleGroup(fixedGroupKey, "up")
            break
        }
    }
    AssertTrue(!repeatRuntime.RepeatActive.Count
            && !repeatRuntime.Scheduler.Entries.Count,
        "来源松开后固定重复任务仍残留")
    repeatRuntime.Shutdown()

    repeatFailureBackend := FailingRepeatBackend()
    failingRepeatRuntime := TestableManagedRuleRuntime(app,
        repeatFailureBackend, false)
    failingRepeatMapping := BuildManagedMapping("failing-repeat", "F12", [
        Map("type", "send", "value", "{F1}", "repeat", "repeat",
            "repeat_interval_ms", 20)])
    failingRepeatRuntime.ApplyMappings([failingRepeatMapping])
    for failingGroupKey, failingGroup in failingRepeatRuntime.Groups {
        if failingGroup.Down.Length {
            failingRepeatRuntime.HandleSimpleGroup(failingGroupKey, "down")
            break
        }
    }
    failingRepeatRuntime.Scheduler.RunDue(
        DllCall("kernel32\GetTickCount64", "UInt64") + 50)
    AssertTrue(repeatFailureBackend.ActionCalls == 2
            && !failingRepeatRuntime.RepeatActive.Count
            && !failingRepeatRuntime.Scheduler.Entries.Count,
        "固定重复动作失败后仍被重新排队")
    failingRepeatRuntime.Shutdown()

    modifierRuntime := TestableManagedRuleRuntime(app, TestManagedBackend(), false)
    stickyMapping := BuildManagedMapping("sticky-modifier", "F15", [
        Map("type", "sticky_modifier", "value", "LShift")])
    oneShotMapping := BuildManagedMapping("one-shot-modifier", "F14", [
        Map("type", "one_shot_modifier", "value", "LCtrl")])
    modifierRuntime.ApplyMappings([stickyMapping, oneShotMapping])
    for modifierGroupKey, modifierGroup in modifierRuntime.Groups {
        if !modifierGroup.Down.Length
            continue
        if InStr(StrLower(modifierGroup.Name), "f15")
            modifierRuntime.HandleSimpleGroup(modifierGroupKey, "down")
        else if InStr(StrLower(modifierGroup.Name), "f14")
            modifierRuntime.HandleSimpleGroup(modifierGroupKey, "down")
    }
    AssertTrue(modifierRuntime.OutputLedger.HasOwner("LShift",
            "sticky:sticky-modifier|global:LShift")
            && modifierRuntime.OutputLedger.HasOwner("LCtrl",
                "one-shot:one-shot-modifier|global:LCtrl"),
        "一次性或粘滞修饰键没有登记输出所有者")
    modifierRuntime.ReleaseOneShotModifiers()
    AssertTrue(!modifierRuntime.OutputLedger.HasOwner("LCtrl",
            "one-shot:one-shot-modifier|global:LCtrl")
            && modifierRuntime.OutputLedger.HasOwner("LShift",
                "sticky:sticky-modifier|global:LShift"),
        "一次性修饰键没有释放或误释放了粘滞键")
    modifierRuntime.Shutdown()

    nonManagedRejected := false
    try runtime.ApplyMappings([{Mode: "raw", Enabled: true,
        Id: "raw-forbidden", SourceSpec: "F22"}])
    catch as nonManagedError
        nonManagedRejected := InStr(nonManagedError.Message,
            "只接受 managed") > 0
    AssertTrue(nonManagedRejected,
        "托管运行时仍接受非 RuleSpec 映射")

    runtime.ApplyMappings([managedOne])
    previousRegistrationCount := backend.Registrations.Length
    backend.FailNext := true
    managedTwo := BuildManagedMapping("managed-two", "F23",
        [VariableAction("second", 1)])
    applyFailed := false
    try runtime.ApplyMappings([managedTwo])
    catch
        applyFailed := true
    AssertTrue(applyFailed, "后端失败没有中止热应用")
    AssertTrue(runtime.Rules.Has("managed-one")
            && !runtime.Rules.Has("managed-two")
            && backend.Registrations.Length == previousRegistrationCount,
        "热应用失败没有恢复旧运行时与注册")

    sequenceSpec := BuildRuntimeSpec("sequence-rule", "", [
        VariableAction("sequence", 1)])
    sequenceSpec["from"] := Map("sequence", ["A", "B"],
        "event", "down")
    sequenceMapping := {Mode: "managed", Enabled: true,
        Spec: RuleSpec.Normalize(sequenceSpec)}
    sequenceMapping.Descriptor := RuleCompiler.Compile(sequenceMapping.Spec)
    runtime.ApplyMappings([sequenceMapping])
    runtime.HandleComplexKey("a", "down")
    runtime.HandleComplexKey("a", "up")
    runtime.HandleComplexKey("b", "down")
    AssertEqual(1, runtime.Variables["sequence"],
        "序列规则没有在完整序列后执行")
    runtime.HandleComplexKey("b", "up")

    overlappingSequenceSpec := BuildRuntimeSpec("overlapping-sequence", "", [
        VariableAction("overlapping_sequence", 1)])
    overlappingSequenceSpec["from"] := Map("sequence", ["A", "A", "B"],
        "event", "down")
    overlappingSequenceMapping := {Mode: "managed", Enabled: true,
        Spec: RuleSpec.Normalize(overlappingSequenceSpec)}
    overlappingSequenceMapping.Descriptor := RuleCompiler.Compile(
        overlappingSequenceMapping.Spec)
    runtime.ApplyMappings([overlappingSequenceMapping])
    Loop 3 {
        runtime.HandleComplexKey("a", "down")
        runtime.HandleComplexKey("a", "up")
    }
    runtime.HandleComplexKey("b", "down")
    AssertEqual(1, runtime.Variables["overlapping_sequence"],
        "序列失配后没有保留可重叠的最长前缀")
    runtime.HandleComplexKey("b", "up")

    physicalSpec := BuildRuntimeSpec("physical-scan-codes", "", [
        VariableAction("physical_scan_codes", 1)])
    physicalSpec["from"] := Map("simultaneous", [
        Map("name", "A", "kind", "keyboard", "vk", "41", "sc", "01E"),
        Map("name", "B", "kind", "keyboard", "vk", "42", "sc", "030")],
        "event", "down")
    physicalMapping := {Mode: "managed", Enabled: true,
        Spec: RuleSpec.Normalize(physicalSpec)}
    physicalMapping.Descriptor := RuleCompiler.Compile(physicalMapping.Spec)
    runtime.ApplyMappings([physicalMapping])
    AssertEqual(0, backend.Registrations.Length,
        "复杂来源不应创建 Raw Input 之外的热键注册")
    runtime.HandleComplexKey("keyboard:sc:01e:0", "down")
    runtime.HandleComplexKey("keyboard:sc:030:0", "down")
    AssertEqual(1, runtime.Variables["physical_scan_codes"],
        "扫描码身份事件没有命中对应复杂规则")
    runtime.HandleComplexKey("keyboard:sc:01e:0", "up")
    runtime.HandleComplexKey("keyboard:sc:030:0", "up")
    inputEventCount := CountRuleEvents(app.Events, "input_event", "")
    runtime.HandleInputEvent(InputEvent.FromRuleKey(
        physicalMapping.Spec["from"]["simultaneous"][1], "down"))
    AssertTrue(CountRuleEvents(app.Events, "input_event", "")
            > inputEventCount,
        "统一输入事件没有进入运行时事件流")
    runtime.HandleInputEvent(InputEvent.FromRuleKey(
        physicalMapping.Spec["from"]["simultaneous"][1], "up"))

    deviceRuntime := TestableManagedRuleRuntime(app, backend, false)
    deviceStateSpec := BuildRuntimeSpec("device-state", "F18", [
        Map("type", "key_down", "value", "MButton")])
    deviceStateSpec["to_after_key_up"] := [
        Map("type", "key_up", "value", "MButton")]
    deviceStateMapping := {Mode: "managed", Enabled: true,
        Spec: RuleSpec.Normalize(deviceStateSpec)}
    deviceStateMapping.Descriptor := RuleCompiler.Compile(
        deviceStateMapping.Spec)
    deviceRuntime.ApplyMappings([deviceStateMapping])
    deviceGroupKey := ""
    for candidateGroupKey, candidateGroup in deviceRuntime.Groups {
        if candidateGroup.Down.Length {
            deviceGroupKey := candidateGroupKey
            break
        }
    }
    deviceAEvent := InputEvent.Create(KeyIdentity.Create("keyboard", "F18",
        0x81, 0x069, false, "device-a"), "down", false, false,
        "raw-input")
    deviceBEvent := InputEvent.Create(KeyIdentity.Create("keyboard", "F18",
        0x81, 0x069, false, "device-b"), "down", false, false,
        "raw-input")
    deviceRuntime.HandleSimpleGroup(deviceGroupKey, "down", deviceAEvent)
    deviceRuntime.HandleSimpleGroup(deviceGroupKey, "down", deviceBEvent)
    deviceAState := deviceRuntime.RuleDeviceKey("device-state", "device-a")
    deviceBState := deviceRuntime.RuleDeviceKey("device-state", "device-b")
    AssertTrue(deviceRuntime.StateMachine.States.Has(deviceAState)
            && deviceRuntime.StateMachine.States.Has(deviceBState)
            && !deviceRuntime.StateMachine.States[deviceAState].Interrupted,
        "同一规则在不同实体设备上的状态没有隔离")
    AssertTrue(deviceRuntime.OutputLedger.Keys["mbutton"].Owners.Count == 2
            && deviceRuntime.SentKeyEvents.Length == 1,
        "不同设备没有取得独立输出所有权")
    removalEvent := InputEvent.Create(KeyIdentity.Create("device", "Device A",
        0, 0, false, "device-a"), "removal", false, false,
        "raw-input-device", "", Map("lifecycle", "removal"))
    deviceRuntime.HandleInputEvent(removalEvent)
    AssertTrue(!deviceRuntime.StateMachine.States.Has(deviceAState)
            && deviceRuntime.StateMachine.States.Has(deviceBState)
            && deviceRuntime.OutputLedger.Keys["mbutton"].Owners.Count == 1
            && deviceRuntime.SentKeyEvents.Length == 1,
        "设备拔出错误清理了其他设备的活动状态或输出")
    deviceBUp := InputEvent.Create(deviceBEvent["identity"], "up", false,
        false, "raw-input")
    deviceRuntime.HandleSimpleGroup(deviceGroupKey, "up", deviceBUp)
    AssertTrue(!deviceRuntime.OutputLedger.Keys.Count
            && deviceRuntime.SentKeyEvents.Length == 2
            && deviceRuntime.SentKeyEvents[2] == "MButton:up",
        "最后一个设备松开后没有释放共享输出")
    deviceRuntime.Shutdown()

    strictSpec := BuildRuntimeSpec("strict-release-all", "", [
        VariableAction("strict_match", 1)])
    strictSpec["from"] := Map("simultaneous", ["F6", "F7"],
        "event", "down", "simultaneous_options", Map(
            "order", "strict", "release", "all"))
    strictSpec["to_after_key_up"] := [VariableAction("strict_released", 1)]
    strictMapping := {Mode: "managed", Enabled: true,
        Spec: RuleSpec.Normalize(strictSpec)}
    strictMapping.Descriptor := RuleCompiler.Compile(strictMapping.Spec)
    runtime.ApplyMappings([strictMapping])
    runtime.HandleComplexKey("f7", "down")
    runtime.HandleComplexKey("f6", "down")
    AssertTrue(!runtime.Variables.Has("strict_match"),
        "严格同时键顺序错误时仍命中")
    runtime.HandleComplexKey("f7", "up")
    runtime.HandleComplexKey("f6", "up")
    runtime.HandleComplexKey("f6", "down")
    runtime.HandleComplexKey("f7", "down")
    AssertEqual(1, runtime.Variables["strict_match"],
        "严格同时键正确顺序没有命中")
    runtime.HandleComplexKey("f6", "up")
    AssertTrue(runtime.StateMachine.States.Has(
            runtime.RuleDeviceKey("strict-release-all", "global"))
            && !runtime.Variables.Has("strict_released"),
        "release=all 在首个成员松开时提前结束")
    runtime.HandleComplexKey("f7", "up")
    AssertTrue(!runtime.StateMachine.States.Has(
            runtime.RuleDeviceKey("strict-release-all", "global"))
            && runtime.Variables.Has("strict_released"),
        "release=all 没有在所有成员松开后结束")
    AssertTrue(!runtime.StateMachine.States.Count,
        "序列最后一键松开后仍残留状态")

    firstSimSpec := BuildRuntimeSpec("first-sim", "", [
        VariableAction("first_sim", 1)])
    firstSimSpec["from"] := Map("simultaneous", ["A", "B"],
        "event", "down")
    secondSimSpec := BuildRuntimeSpec("second-sim", "", [
        VariableAction("second_sim", 1)])
    secondSimSpec["from"] := Map("simultaneous", ["B", "A"],
        "event", "down")
    secondSimSpec["conditions"] := [Map("type", "application",
        "field", "process", "operator", "equals", "value", "never.exe")]
    firstSimMapping := {Mode: "managed", Enabled: true,
        Spec: RuleSpec.Normalize(firstSimSpec)}
    secondSimMapping := {Mode: "managed", Enabled: true,
        Spec: RuleSpec.Normalize(secondSimSpec)}
    runtime.ApplyMappings([firstSimMapping, secondSimMapping])
    runtime.HandleComplexKey("a", "down")
    runtime.HandleComplexKey("b", "down")
    AssertTrue(runtime.Variables.Has("first_sim")
            && !runtime.Variables.Has("second_sim"),
        "同一复杂手势执行了多条重叠规则而非代码顺序中的第一条")
    runtime.HandleComplexKey("a", "up")
    runtime.HandleComplexKey("b", "up")

    overlapOnlySpec := BuildRuntimeSpec("overlap-only", "", [
        VariableAction("overlap_only", 1)])
    overlapOnlySpec["from"] := Map("simultaneous", ["F1", "F2", "F3"],
        "event", "down")
    overlapOnlySpec["timing"] := Map("simultaneous_threshold_ms", 0)
    overlapOnlyMapping := {Mode: "managed", Enabled: true,
        Spec: RuleSpec.Normalize(overlapOnlySpec)}
    overlapOnlyMapping.Descriptor := RuleCompiler.Compile(
        overlapOnlyMapping.Spec)
    runtime.ApplyMappings([overlapOnlyMapping])
    runtime.HandleComplexKey("f1", "down")
    Sleep(70)
    runtime.HandleComplexKey("f2", "down")
    Sleep(70)
    runtime.HandleComplexKey("f3", "down")
    AssertEqual(1, runtime.Variables["overlap_only"],
        "阈值为 0 的同时按键仍错误限制了按下时间差")
    runtime.HandleComplexKey("f1", "up")
    runtime.HandleComplexKey("f2", "up")
    runtime.HandleComplexKey("f3", "up")

    wheelSimSpec := BuildRuntimeSpec("wheel-sim", "", [
        VariableAction("wheel_sim", 1)])
    wheelSimSpec["from"] := Map("simultaneous", ["A", "WheelUp"],
        "event", "down")
    wheelSimSpec["timing"] := Map("simultaneous_threshold_ms", 0)
    wheelSimMapping := {Mode: "managed", Enabled: true,
        Spec: RuleSpec.Normalize(wheelSimSpec)}
    wheelSimMapping.Descriptor := RuleCompiler.Compile(wheelSimMapping.Spec)
    runtime.ApplyMappings([wheelSimMapping])
    hasWheelUpRegistration := false
    for registration in backend.Registrations {
        if StrLower(registration.Name) == "$~*wheelup up"
            hasWheelUpRegistration := true
    }
    AssertTrue(!hasWheelUpRegistration,
        "复杂滚轮来源注册了永远不会到达的 Up 热键")
    runtime.HandleComplexKey("a", "down")
    runtime.HandleComplexKey("wheelup", "down")
    AssertEqual(1, runtime.Variables["wheel_sim"],
        "滚轮没有在发生时参与同时按键匹配")
    AssertTrue(!runtime.ComplexHeld.Has("wheelup"),
        "瞬时滚轮事件残留在按下状态集合中")
    runtime.HandleComplexKey("a", "up")
    AssertTrue(!runtime.StateMachine.States.Count,
        "滚轮同时规则完成后仍残留运行状态")

    repeatedSequenceSpec := BuildRuntimeSpec("repeat-sequence", "", [
        VariableAction("repeat_sequence", 1)])
    repeatedSequenceSpec["from"] := Map("sequence", ["A", "A"],
        "event", "down")
    repeatedSequenceMapping := {Mode: "managed", Enabled: true,
        Spec: RuleSpec.Normalize(repeatedSequenceSpec)}
    repeatedSequenceMapping.Descriptor := RuleCompiler.Compile(
        repeatedSequenceMapping.Spec)
    runtime.ApplyMappings([repeatedSequenceMapping])
    runtime.HandleComplexKey("a", "down")
    runtime.HandleComplexKey("a", "down")
    AssertTrue(!runtime.Variables.Has("repeat_sequence"),
        "按键自动连发被错误计为新的序列步骤")
    runtime.HandleComplexKey("a", "up")
    runtime.HandleComplexKey("a", "down")
    AssertEqual(1, runtime.Variables["repeat_sequence"],
        "真实松开后再次按下没有完成重复键序列")
    runtime.HandleComplexKey("a", "up")

    repeatOnceSpec := BuildRuntimeSpec("repeat-once", "F26", [
        Map("type", "set_variable", "name", "repeat_once", "value", 1,
            "repeat", "once")])
    repeatOnceMapping := {Mode: "managed", Enabled: true,
        Spec: RuleSpec.Normalize(repeatOnceSpec)}
    repeatOnceMapping.Descriptor := RuleCompiler.Compile(
        repeatOnceMapping.Spec)
    runtime.ApplyMappings([repeatOnceMapping])
    repeatGroupKey := ""
    for candidateGroupKey, candidateGroup in runtime.Groups {
        if candidateGroup.Down.Length {
            repeatGroupKey := candidateGroupKey
            break
        }
    }
    runtime.HandleSimpleGroup(repeatGroupKey, "down")
    runtime.HandleSimpleGroup(repeatGroupKey, "down")
    runtime.HandleSimpleGroup(repeatGroupKey, "up")
    runtime.HandleSimpleGroup(repeatGroupKey, "down")
    AssertEqual(2, CountRuleEvents(app.Events, "action_executed",
        "repeat-once"), "repeat=once 没有抑制同一次按住期间的自动连发")
    runtime.HandleSimpleGroup(repeatGroupKey, "up")
    transactionalBackend := TransactionalTestBackend()
    oldRegistrations := [
        {Name: "F13", Callback: (*) => 0},
        {Name: "F14", Callback: (*) => 0}
    ]
    transactionalBackend.Replace(oldRegistrations)
    transactionalBackend.FailDisableName := "F14"
    disableFailed := false
    try transactionalBackend.Replace([
        {Name: "F15", Callback: (*) => 0}])
    catch
        disableFailed := true
    AssertTrue(disableFailed
            && transactionalBackend.Registrations.Length == 2
            && transactionalBackend.EnabledNames.Has("f13")
            && transactionalBackend.EnabledNames.Has("f14"),
        "撤销旧热键失败后没有恢复完整旧注册计划")

    runMapping := BuildManagedMapping("run-blocked", "F24",
        [Map("type", "run", "value", "notepad.exe")])
    runtime.ApplyMappings([runMapping])
    for runGroupKey, runGroup in runtime.Groups {
        if runGroup.Down.Length {
            runtime.HandleSimpleGroup(runGroupKey, "down")
            break
        }
    }
    AssertTrue(HasRuntimeEvent(app.Events, "action_failed",
            "安全策略阻止"),
        "run 动作默认安全策略被绕过")

    stressMappings := []
    Loop 300
        stressMappings.Push(BuildManagedMapping("stress-" A_Index,
            "StressKey" A_Index, [VariableAction("stress", A_Index)]))
    stressReport := runtime.ApplyMappings(stressMappings)
    AssertTrue(stressReport.Applied == 300
            && stressReport.Registrations == 300,
        "大规则集压力测试没有完整编译和注册")

    trackingBackend := TestManagedBackend()
    trackingRuntime := TestableManagedRuleRuntime(app, trackingBackend, false)
    keyDownMapping := BuildManagedMapping("tracked-key-down", "F27",
        [Map("type", "key_down", "value", "F13")])
    trackingRuntime.ApplyMappings([keyDownMapping])
    selectedTrackingGroupKey := ""
    for trackingGroupKey, trackingGroup in trackingRuntime.Groups {
        if trackingGroup.Down.Length {
            selectedTrackingGroupKey := trackingGroupKey
            trackingRuntime.HandleSimpleGroup(trackingGroupKey, "down")
            break
        }
    }
    AssertTrue(trackingRuntime.PressedOutputKeys.Has("f13")
            && trackingRuntime.SentKeyEvents[1] == "F13:down",
        "key_down 动作没有登记待释放输出键")
    trackingRuntime.ResetActiveState("rules_reloaded")
    AssertTrue(!trackingRuntime.PressedOutputKeys.Count
            && trackingRuntime.SentKeyEvents[2] == "F13:up"
            && HasRuntimeEvent(app.Events, "active_state_reset"),
        "状态重置没有释放输出键或记录事件")
    trackingRuntime.HandleSimpleGroup(selectedTrackingGroupKey, "down")
    trackingRuntime.ApplyMappings([])
    AssertTrue(!trackingRuntime.PressedOutputKeys.Count
            && trackingRuntime.SentKeyEvents[4] == "F13:up",
        "规则重应用没有释放托管运行时按住的输出键")
    trackingRuntime.Shutdown()
    runtime.Shutdown()
    WriteTestSuccess("managed-runtime")
} catch as runtimeTestError {
    testFailure := runtimeTestError.Message "`n" runtimeTestError.Stack
}
if testFailure != "" {
    FileAppend(testFailure "`n", "**")
    ExitApp(1)
}
ExitApp(0)

BuildRuntimeDescriptor(id, hotkeyName, overrides) {
    spec := BuildRuntimeSpec(id, hotkeyName, [VariableAction("base", 1)])
    for fieldName, actions in overrides
        spec[fieldName] := actions
    return RuleCompiler.Compile(RuleSpec.Normalize(spec))
}

BuildManagedMapping(id, hotkeyName, actions) {
    spec := RuleSpec.Normalize(BuildRuntimeSpec(id, hotkeyName, actions))
    return {Mode: "managed", Enabled: true, Spec: spec,
        Descriptor: RuleCompiler.Compile(spec)}
}

BuildRuntimeSpec(id, hotkeyName, actions) {
    return Map("schema", 2, "id", id,
        "enabled", JsonBoolean(true),
        "description", "runtime test",
        "display", Map("source", hotkeyName == "" ? id : hotkeyName,
            "target", "variable", "scope", "default", "purpose", "test"),
        "from", Map("hotkey", hotkeyName, "event", "down",
            "key", Map("name", hotkeyName == "" ? "A" : hotkeyName)),
        "conditions", [], "to", actions)
}

VariableAction(name, value) {
    return Map("type", "set_variable", "name", name, "value", value)
}

HasIssue(issues, code) {
    for issue in issues {
        if issue.Code == code
            return true
    }
    return false
}

HasRuntimeEvent(events, eventName, detailFragment := "") {
    for event in events {
        if event.Event != eventName
            continue
        if detailFragment == "" || (IsObject(event.Fields)
                && event.Fields.HasOwnProp("Detail")
                && InStr(event.Fields.Detail, detailFragment))
            return true
    }
    return false
}

FindRuntimeEvent(events, eventName, ruleId := "") {
    for eventEntry in events {
        if eventEntry.Event != eventName
            continue
        if ruleId == "" || (IsObject(eventEntry.Fields)
                && eventEntry.Fields.HasOwnProp("RuleId")
                && eventEntry.Fields.RuleId == ruleId)
            return eventEntry
    }
    return false
}

CountRuleEvents(events, eventName, ruleId) {
    count := 0
    for event in events {
        if event.Event != eventName
            continue
        if ruleId == "" {
            count++
            continue
        }
        if IsObject(event.Fields) && event.Fields.HasOwnProp("RuleId")
                && event.Fields.RuleId == ruleId
            count++
    }
    return count
}

class TestRuntimeClock {
    __New() => this.Tick := 0
    Now() => this.Tick
}

class TestRuntimeApp {
    __New() {
        this.Events := []
    }
    TraceEvent(category, eventName, fields := "") {
        this.Events.Push({Category: category, Event: eventName, Fields: fields})
    }
}

ThrowManagedStateAction(fieldName) {
    throw Error("injected state action failure: " fieldName)
}

class TestManagedBackend extends IInputBackend {
    __New() {
        this.Registrations := []
        this.FailNext := false
    }
    Replace(registrations) {
        if this.FailNext {
            this.FailNext := false
            throw Error("injected registration failure")
        }
        this.Registrations := registrations.Clone()
        return registrations.Length
    }
    GetBackendId() => "test"
    GetCapabilities() {
        return Map("backend", "test",
            "available", JsonBoolean(true),
            "suppresses_simple_hotkeys", JsonBoolean(true),
            "suppresses_sequence_prefixes", JsonBoolean(false),
            "suppresses_simultaneous_prefixes", JsonBoolean(false),
            "device_specific_suppression", JsonBoolean(false),
            "secure_desktop", JsonBoolean(false))
    }
    Shutdown() => this.Registrations := []
}

class FailingRepeatBackend extends TestManagedBackend {
    __New() {
        super.__New()
        this.ActionCalls := 0
    }
    EmitAction(actionType, value, phase := "") {
        this.ActionCalls++
        if this.ActionCalls > 1
            throw Error("injected repeat action failure")
        return true
    }
}

class TransactionalTestBackend extends TestManagedBackend {
    __New() {
        super.__New()
        this.EnabledNames := Map()
        this.FailDisableName := ""
    }
    Replace(registrations) {
        previous := this.Registrations.Clone()
        try {
            for registration in previous
                this.SetOne(registration, false)
            for registration in registrations
                this.SetOne(registration, true)
            this.Registrations := registrations.Clone()
            return registrations.Length
        } catch as replaceError {
            this.EnabledNames.Clear()
            for registration in previous
                this.SetOne(registration, true)
            this.Registrations := previous
            throw replaceError
        }
    }
    SetOne(registration, enabled) {
        normalized := StrLower(registration.Name)
        if !enabled && registration.Name == this.FailDisableName {
            this.FailDisableName := ""
            throw Error("injected disable failure")
        }
        if enabled
            this.EnabledNames[normalized] := true
        else if this.EnabledNames.Has(normalized)
            this.EnabledNames.Delete(normalized)
    }
}

class TestableManagedRuleRuntime extends ManagedRuleRuntime {
    __New(app, backend, enableObserver := false) {
        this.SentKeyEvents := []
        super.__New(app, backend, enableObserver)
    }
    SendKeyEvent(keyName, phase) {
        this.SentKeyEvents.Push(String(keyName) ":" phase)
    }
}
