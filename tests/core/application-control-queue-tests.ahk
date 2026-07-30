#Requires AutoHotkey v2.0 64-bit
#SingleInstance Off
#Warn All, StdOut

#Include ..\TestSupport.ahk
#Include ..\..\src\Core\JsonCodec.ahk
#Include ..\..\src\Core\Sha256.ahk
#Include ..\..\src\Core\CrossProcessWriteLock.ahk
#Include ..\..\src\Core\RuleSpec.ahk
#Include ..\..\src\Core\ApplicationControlQueue.ahk

testRoot := A_Temp "\key-mouse-remapper-assistant-control-" A_TickCount "-"
    . Format("{:08X}", Random(0, 0xFFFFFFFF))
testFailure := ""
DirCreate(testRoot)
try {
    queuePath := testRoot "\control.json"
    firstScript := testRoot "\first.ahk"
    secondScript := testRoot "\second.ahk"
    queue := ApplicationControlQueue(queuePath)
    AssertEqual(CrossProcessWriteLock.NormalizePath(queuePath),
        queue.FilePath, "应用控制队列路径没有在构造时规范化")
    firstRequest := queue.Publish("apply", firstScript,
        Map("reason", "test-first"))
    queue.Publish("apply", secondScript,
        Map("reason", "test-second"))
    firstRequests := queue.ConsumeFor(firstScript)
    AssertTrue(firstRequests.Length == 1
            && firstRequests[1]["id"] == firstRequest["id"]
            && firstRequests[1]["data"]["reason"] == "test-first",
        "应用控制队列没有按目标脚本隔离消费："
            queue.LastRecoveryWarning)
    AssertTrue(FileExist(queuePath),
        "消费一个目标时错误删除了其他目标请求")
    secondRequests := queue.ConsumeFor(secondScript)
    AssertTrue(secondRequests.Length == 1
            && secondRequests[1]["data"]["reason"] == "test-second",
        "应用控制队列丢失了剩余目标请求")
    AssertTrue(!FileExist(queuePath),
        "应用控制队列全部消费后没有清理文件")
    AssertEqual(0, queue.ConsumeFor(firstScript).Length,
        "空应用控制队列返回了伪请求")

    FileAppend("not-json", queuePath, "UTF-8-RAW")
    recoveredRequest := queue.Publish("apply", firstScript,
        Map("reason", "after-corruption"))
    AssertTrue(FileExist(queuePath ".corrupt"),
        "损坏的应用控制队列没有被隔离保留")
    recovered := queue.ConsumeFor(firstScript)
    AssertTrue(recovered.Length == 1
            && recovered[1]["id"] == recoveredRequest["id"],
        "损坏队列阻断了后续有效控制请求")

    validRequest := queue.Publish("apply", secondScript,
        Map("reason", "salvage-valid"))
    mixedDocument := JsonCodec.Parse(FileRead(queuePath, "UTF-8"))
    mixedDocument["requests"].Push(Map(
        "id", "broken", "command", "apply", "script_path", "",
        "created_at", "2026-07-30T00:00:00Z"))
    FileDelete(queuePath)
    FileAppend(JsonCodec.Stringify(mixedDocument, true, true), queuePath,
        "UTF-8-RAW")
    salvaged := queue.ConsumeFor(secondScript)
    AssertTrue(salvaged.Length == 1
            && salvaged[1]["id"] == validRequest["id"],
        "单个畸形条目导致有效控制请求一并丢失")
    AssertTrue(FileExist(queuePath ".corrupt"),
        "含畸形条目的原始控制队列没有被隔离保留")

    validShape := RuleSpec.Clone(validRequest)
    invalidShapeCount := 0
    fractionalPid := RuleSpec.Clone(validShape)
    fractionalPid["process_id"] := 1.5
    try queue.NormalizeRequest(fractionalPid)
    catch
        invalidShapeCount++
    stringPid := RuleSpec.Clone(validShape)
    stringPid["process_id"] := "42"
    try queue.NormalizeRequest(stringPid)
    catch
        invalidShapeCount++
    unknownField := RuleSpec.Clone(validShape)
    unknownField["ignored"] := true
    try queue.NormalizeRequest(unknownField)
    catch
        invalidShapeCount++
    invalidTimestamp := RuleSpec.Clone(validShape)
    invalidTimestamp["created_at"] := "today"
    try queue.NormalizeRequest(invalidTimestamp)
    catch
        invalidShapeCount++
    AssertEqual(4, invalidShapeCount,
        "应用控制请求接受了宽松进程号、未知字段或畸形时间")
    WriteTestSuccess("application-control-queue")
} catch as controlQueueTestError {
    testFailure := controlQueueTestError.Message "`n"
        . controlQueueTestError.Stack
} finally {
    if DirExist(testRoot)
        DirDelete(testRoot, true)
}
if testFailure != "" {
    FileAppend(testFailure "`n", "**")
    ExitApp(1)
}
ExitApp(0)
