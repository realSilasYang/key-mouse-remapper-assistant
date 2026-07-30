#Requires AutoHotkey v2.0.26 64-bit
#SingleInstance Off
#Warn All, StdOut

#Include ..\TestSupport.ahk
#Include ..\..\src\Process\WorkerEventBuffer.ahk

testFailure := ""
try {
    eventBuffer := WorkerEventBuffer(3)
    firstMove := Map("sequence", 1)
    latestMove := Map("sequence", 2)
    AssertTrue(eventBuffer.Push(firstMove, "raw|mouse-one")
            && eventBuffer.Push(latestMove, "raw|mouse-one")
            && eventBuffer.Length == 1
            && eventBuffer.Peek().Payload["sequence"] == 2
            && eventBuffer.CoalescedCount == 1,
        "同一设备的连续鼠标移动没有合并为最新事件")

    eventBuffer.Push(Map("sequence", 3), "raw|mouse-two")
    eventBuffer.Push(Map("sequence", 4), "")
    eventBuffer.Push(Map("sequence", 5), "", true)
    remaining := []
    while eventBuffer.Length
        remaining.Push(eventBuffer.RemoveFirst().Payload["sequence"])
    AssertTrue(remaining.Length == 3
            && remaining[1] == 3
            && remaining[2] == 4
            && remaining[3] == 5
            && eventBuffer.DroppedCount == 1,
        "缓冲区满时没有优先淘汰最旧鼠标移动并保留关键事件")

    priorityBuffer := WorkerEventBuffer(2)
    priorityBuffer.Push(Map("sequence", 1), "", true)
    priorityBuffer.Push(Map("sequence", 2), "", true)
    accepted := priorityBuffer.Push(Map("sequence", 3))
    AssertTrue(!accepted && priorityBuffer.Length == 2
            && priorityBuffer.DroppedCount == 1,
        "普通观察事件覆盖了已排队的关键控制事件")
    priorityBuffer.Push(Map("sequence", 4), "", true)
    AssertTrue(priorityBuffer.Length == 2
            && priorityBuffer.Peek().Payload["sequence"] == 2
            && priorityBuffer.GetHealth()["maximum"] == 2,
        "新的关键事件没有在满缓冲区中取得有界空间")

    stressBuffer := WorkerEventBuffer(2048)
    Loop 2048
        stressBuffer.Push(Map("sequence", A_Index))
    Loop 1800
        AssertEqual(A_Index, stressBuffer.RemoveFirst().Payload["sequence"],
            "逻辑队首弹出破坏了事件顺序")
    AssertTrue(stressBuffer.Length == 248
            && stressBuffer.Items.Length < 512,
        "逻辑队首没有周期压缩，物理缓冲区持续保留已消费槽位")

    for invalidCapacity in [1.5, "2", 0] {
        invalidCapacityRejected := false
        try WorkerEventBuffer(invalidCapacity)
        catch
            invalidCapacityRejected := true
        AssertTrue(invalidCapacityRejected,
            "事件缓冲区接受了非正整数容量")
    }

    WriteTestSuccess("worker-event-buffer")
} catch as bufferTestError {
    testFailure := bufferTestError.Message "`n" bufferTestError.Stack
}
if testFailure != "" {
    FileAppend(testFailure "`n", "**")
    ExitApp(1)
}
ExitApp(0)
