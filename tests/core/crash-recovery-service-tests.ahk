#Requires AutoHotkey v2.0 64-bit
#SingleInstance Off
#Warn All, StdOut

#Include ..\TestSupport.ahk
#Include ..\..\src\Core\JsonCodec.ahk
#Include ..\..\src\Core\Sha256.ahk
#Include ..\..\src\Core\CrossProcessWriteLock.ahk
#Include ..\..\src\Core\CrashRecoveryService.ahk

testRoot := A_Temp "\key-mouse-remapper-assistant-crash-recovery-" A_TickCount "-"
    . Format("{:08X}", Random(0, 0xFFFFFFFF))
testFailure := ""
DirCreate(testRoot)
try {
    journalPath := testRoot "\crash-diagnostics.json"
    service := CrashRecoveryService(journalPath, 60)
    invalidBoundaryCount := 0
    for invalidAge in [1.5, "60", 0] {
        try CrashRecoveryService(testRoot "\invalid-age.json", invalidAge)
        catch
            invalidBoundaryCount++
    }
    try service.Snapshot(1.5)
    catch
        invalidBoundaryCount++
    try service.CleanupStaleTransactions([], "not-a-time")
    catch
        invalidBoundaryCount++
    AssertEqual(5, invalidBoundaryCount,
        "崩溃诊断接受了宽松期限、条目数或时间")
    targetPath := testRoot "\settings.ini"
    staleTemporary := targetPath ".tmp-stale"
    recentTemporary := targetPath ".tmp-recent"
    unrelatedPath := testRoot "\settings.ini.backup"
    scriptPath := testRoot "\fixture.ahk"
    staleScriptTemporary := scriptPath ".codex-stale"
    FileAppend("stale", staleTemporary, "UTF-8-RAW")
    FileAppend("recent", recentTemporary, "UTF-8-RAW")
    FileAppend("unrelated", unrelatedPath, "UTF-8-RAW")
    FileAppend("stale-script", staleScriptTemporary, "UTF-8-RAW")
    oldTimestamp := DateAdd(A_Now, -120, "Seconds")
    FileSetTime(oldTimestamp, staleTemporary, "M")
    FileSetTime(oldTimestamp, staleScriptTemporary, "M")

    report := service.CleanupStaleTransactions(
        [targetPath, scriptPath], A_Now)
    AssertTrue(!FileExist(staleTemporary)
            && !FileExist(staleScriptTemporary),
        "过期事务残留没有被清理")
    AssertTrue(FileExist(recentTemporary) && FileExist(unrelatedPath),
        "事务清理误删了近期文件或无关文件")
    AssertEqual(2, report.Removed.Length, "事务清理移除计数错误")
    AssertEqual(1, report.SkippedRecent.Length,
        "事务清理近期文件计数错误")

    service.Record("startup_failure", "sensitive local error",
        Map("script_path", "C:\private\fixture.ahk", "attempt", 3))
    snapshot := service.Snapshot()
    AssertEqual(2, snapshot.Length,
        "事务清理与启动失败没有持久记录")
    serviceReloaded := CrashRecoveryService(journalPath, 60)
    reloaded := serviceReloaded.Snapshot()
    AssertEqual("startup_failure", reloaded[2]["category"],
        "崩溃诊断没有跨实例保留")
    diagnosticSummary := serviceReloaded.CreateDiagnosticSummary()
    summaryText := JsonCodec.Stringify(diagnosticSummary, false, true)
    AssertTrue(!InStr(summaryText, "sensitive local error")
            && InStr(summaryText, "message_sha256_prefix"),
        "诊断摘要泄露了本地错误全文或缺少可关联摘要")

    FileDelete(journalPath)
    corruptJournalText := "not-json"
    FileAppend(corruptJournalText, journalPath, "UTF-8-RAW")
    serviceReloaded.Record("after_corruption", "continued", Map())
    recoveredEntries := serviceReloaded.Snapshot()
    AssertEqual(2, recoveredEntries.Length,
        "损坏日志恢复没有同时记录恢复事件与新事件")
    AssertEqual("journal_recovered", recoveredEntries[1]["category"],
        "损坏日志恢复事件类别错误")
    quarantinedJournal := FindMatchingFile(journalPath ".corrupt-*")
    AssertTrue(quarantinedJournal != ""
            && FileRead(quarantinedJournal, "UTF-8") == corruptJournalText,
        "损坏的崩溃诊断日志被覆盖或隔离内容发生变化")

    Loop CrashRecoveryService.MaximumEntries + 12
        serviceReloaded.Record("bounded", "entry " A_Index, Map())
    bounded := serviceReloaded.Snapshot()
    AssertEqual(CrashRecoveryService.MaximumEntries, bounded.Length,
        "崩溃诊断条目数量没有受上限约束")
    AssertTrue(FileGetSize(journalPath)
            <= CrashRecoveryService.MaximumFileBytes,
        "崩溃诊断文件超过大小上限")

    malformedPath := testRoot "\malformed-diagnostics.json"
    malformedDocument := Map(
        "schema", CrashRecoveryService.Schema,
        "updated_at", "2026-07-30T00:00:00Z",
        "entries", [Map("timestamp", "2026-07-30T00:00:00Z",
            "category", "valid-looking", "message", "message",
            "data", Map(), "ignored", true)])
    FileAppend(JsonCodec.Stringify(malformedDocument, true, true),
        malformedPath, "UTF-8-RAW")
    malformedService := CrashRecoveryService(malformedPath, 60)
    malformedSnapshotRejected := false
    try malformedService.Snapshot()
    catch
        malformedSnapshotRejected := true
    AssertTrue(malformedSnapshotRejected && FileExist(malformedPath),
        "畸形崩溃诊断条目被静默丢弃或提前破坏证据")
    malformedService.Record("after_invalid_entry", "continued", Map())
    AssertTrue(FindMatchingFile(malformedPath ".corrupt-*") != ""
            && malformedService.Snapshot().Length == 2,
        "畸形崩溃诊断文档没有整体隔离后继续记录")

    WriteTestSuccess("crash-recovery-service")
} catch as crashRecoveryTestError {
    testFailure := crashRecoveryTestError.Message "`n"
        . crashRecoveryTestError.Stack
} finally {
    if DirExist(testRoot)
        DirDelete(testRoot, true)
}
if testFailure != "" {
    FileAppend(testFailure "`n", "**")
    ExitApp(1)
}
ExitApp(0)

FindMatchingFile(pattern) {
    result := ""
    Loop Files, pattern, "F" {
        if result != ""
            throw Error("测试隔离文件数量超过预期。")
        result := A_LoopFileFullPath
    }
    return result
}
