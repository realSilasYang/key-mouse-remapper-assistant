#Requires AutoHotkey v2.0 64-bit
#SingleInstance Off
#Warn All, StdOut

#Include ..\TestSupport.ahk
#Include ..\..\src\Core\JsonCodec.ahk
#Include ..\..\src\Core\Sha256.ahk
#Include ..\..\src\Core\CrossProcessWriteLock.ahk
#Include ..\..\src\Core\EventTraceService.ahk

testRoot := A_Temp "\key-mouse-remapper-assistant-event-trace-" A_TickCount "-"
    . Format("{:08X}", Random(0, 0xFFFFFFFF))
DirCreate(testRoot)
testFailure := ""

try {
    invalidCapacityCount := 0
    for invalidCapacity in ["3", 3.5, 0] {
        try EventTraceService(invalidCapacity)
        catch
            invalidCapacityCount++
    }
    AssertEqual(3, invalidCapacityCount,
        "事件缓冲区接受了字符串、小数或零容量")

    trace := EventTraceService(3)
    received := []
    evictedSequences := []
    subscription := trace.Subscribe(entry => received.Push(entry.Sequence))
    evictionSubscription := trace.Subscribe(entry =>
        evictedSequences.Push(entry.EvictedSequence))
    trace.Record("input", "key_down", {Source: "LShift", Outcome: "observed",
        Data: Map("vk", "A0", "pressed", JsonBoolean(true))})
    trace.Record("runtime", "matched", {RuleId: "rule-one",
        Outcome: "executed", Detail: "F1 -> F2"})
    trace.Record("runtime", "condition", {RuleId: "rule-two",
        Outcome: "rejected"})
    trace.Record("system", "reload", {Outcome: "scheduled"})

    snapshot := trace.Snapshot()
    AssertEqual(3, snapshot.Length, "环形缓冲区没有保持固定容量")
    AssertEqual(2, snapshot[1].Sequence, "溢出后事件顺序错误")
    AssertEqual(1, trace.DroppedCount, "丢弃计数错误")
    AssertEqual(4, received.Length, "订阅者没有接收实时事件")
    AssertEqual(1, evictedSequences[4], "实时事件没有报告被环形缓冲淘汰的序号")
    snapshot[1].Data["mutated"] := true
    AssertTrue(!trace.Snapshot()[1].Data.Has("mutated"),
        "事件快照泄漏了内部可变对象")
    runtimeEvents := trace.Snapshot("runtime")
    AssertEqual(2, runtimeEvents.Length, "类别过滤错误")
    AssertEqual(3, trace.Snapshot("", 2).Length,
        "最小事件序号过滤错误")
    fractionalSequenceRejected := false
    try trace.Snapshot("", 1.5)
    catch
        fractionalSequenceRejected := true
    AssertTrue(fractionalSequenceRejected,
        "事件快照接受了分数最小序号")
    AssertTrue(trace.Unsubscribe(subscription), "订阅无法解除")
    AssertTrue(trace.Unsubscribe(evictionSubscription), "淘汰事件订阅无法解除")
    trace.Record("system", "stopped")
    AssertEqual(4, received.Length, "解除订阅后仍收到事件")

    resizeTrace := EventTraceService(4)
    Loop 4
        resizeTrace.Record("system", "resize-" A_Index)
    resizeState := resizeTrace.CaptureState()
    AssertTrue(resizeTrace.SetCapacity(2), "事件缓冲区容量没有缩小")
    resizedEntries := resizeTrace.Snapshot()
    AssertEqual(2, resizedEntries.Length, "缩小容量后条数错误")
    AssertEqual(3, resizedEntries[1].Sequence, "缩小容量没有保留最新事件")
    AssertEqual(2, resizeTrace.DroppedCount, "缩小容量没有计入丢弃事件")
    AssertTrue(resizeTrace.SetCapacity(6), "事件缓冲区容量没有扩大")
    AssertEqual(2, resizeTrace.Snapshot().Length, "扩大容量破坏了已有事件")
    resizeTrace.RestoreState(resizeState)
    AssertEqual(4, resizeTrace.Capacity, "事件缓冲区状态没有恢复容量")
    AssertEqual(4, resizeTrace.Snapshot().Length,
        "事件缓冲区状态没有恢复内容")
    AssertEqual(0, resizeTrace.DroppedCount,
        "事件缓冲区状态没有恢复丢弃计数")
    stateBeforeInvalidRestore := resizeTrace.CaptureState()
    invalidRestoreState := resizeTrace.CaptureState()
    invalidRestoreState.NextSequence := "5"
    invalidRestoreRejected := false
    try resizeTrace.RestoreState(invalidRestoreState)
    catch
        invalidRestoreRejected := true
    stateAfterInvalidRestore := resizeTrace.CaptureState()
    AssertTrue(invalidRestoreRejected
            && stateAfterInvalidRestore.Capacity
                == stateBeforeInvalidRestore.Capacity
            && stateAfterInvalidRestore.NextSequence
                == stateBeforeInvalidRestore.NextSequence
            && stateAfterInvalidRestore.Entries.Length
                == stateBeforeInvalidRestore.Entries.Length,
        "无效事件状态恢复发生了半提交")

    throwingTrace := EventTraceService(2)
    throwingTrace.Subscribe(ThrowingEventSubscriber)
    throwingTrace.Record("runtime", "safe_publish")
    AssertEqual(0, throwingTrace.Subscribers.Count,
        "异常订阅者没有被隔离并移除")

    longText := ""
    Loop EventTraceService.MaximumTextLength + 100
        longText .= "x"
    limited := trace.Record("input", "large", {Detail: longText})
    AssertEqual(EventTraceService.MaximumTextLength,
        StrLen(limited.Detail), "事件字段没有限长")

    oversizedData := []
    Loop EventTraceService.MaximumDataItems + 1
        oversizedData.Push(A_Index)
    oversizedDataRejected := false
    try trace.Record("input", "oversized_data", {Data: oversizedData})
    catch
        oversizedDataRejected := true
    AssertTrue(oversizedDataRejected,
        "事件数据元素数量没有上限")

    oversizedTextData := []
    Loop EventTraceService.MaximumEntryTextCharacters
            // EventTraceService.MaximumTextLength + 1
        oversizedTextData.Push(longText)
    oversizedTextRejected := false
    try trace.Record("input", "oversized_text", {Data: oversizedTextData})
    catch
        oversizedTextRejected := true
    AssertTrue(oversizedTextRejected,
        "单个事件全部文本的总字符量没有上限")

    exportPath := testRoot "\events.jsonl"
    trace.ExportJsonLines(exportPath)
    exported := Trim(FileRead(exportPath, "UTF-8"), "`r`n")
    lines := StrSplit(exported, "`n", "`r")
    AssertEqual(3, lines.Length, "JSONL 导出条数错误")
    parsed := JsonCodec.Parse(lines[1])
    AssertTrue(parsed.Has("sequence") && parsed.Has("timestamp")
        && parsed.Has("data"), "JSONL 导出缺少稳定字段")

    AssertEqual(3, trace.Clear(), "清空返回的事件数量错误")
    AssertEqual(0, trace.Snapshot().Length, "清空后仍残留事件")

    stressTrace := EventTraceService(EventTraceService.MaximumCapacity)
    Loop EventTraceService.MaximumCapacity + 2500
        stressTrace.Record("runtime", "stress", {RuleId: "rule-" A_Index})
    stressSnapshot := stressTrace.Snapshot()
    AssertEqual(EventTraceService.MaximumCapacity, stressSnapshot.Length,
        "大容量事件压力测试破坏了固定容量")
    AssertEqual(2500, stressTrace.DroppedCount,
        "大容量事件压力测试丢弃计数错误")
    AssertEqual(2501, stressSnapshot[1].Sequence,
        "大容量事件压力测试环形顺序错误")
    WriteTestSuccess("event-trace-service")
} catch as traceTestError {
    testFailure := traceTestError.Message "`n" traceTestError.Stack
} finally {
    if DirExist(testRoot)
        DirDelete(testRoot, true)
}
if testFailure != "" {
    FileAppend(testFailure "`n", "**")
    ExitApp(1)
}
ExitApp(0)

ThrowingEventSubscriber(*) {
    throw Error("subscriber failure")
}
