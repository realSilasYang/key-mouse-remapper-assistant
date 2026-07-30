#Requires AutoHotkey v2.0 64-bit
#SingleInstance Off
#Warn All, StdOut

#Include ..\TestSupport.ahk
#Include ..\..\src\Core\JsonCodec.ahk
#Include ..\..\src\Core\Sha256.ahk
#Include ..\..\src\Core\CrossProcessWriteLock.ahk
#Include ..\..\src\Core\StartupHealthService.ahk

testRoot := A_Temp "\key-mouse-remapper-assistant-health-" A_TickCount "-"
    . Format("{:08X}", Random(0, 0xFFFFFFFF))
testFailure := ""
DirCreate(testRoot)
try {
    statePath := testRoot "\startup-health.json"
    recoveryPath := testRoot "\last-known-good.json"
    scriptPath := testRoot "\fixture.ahk"
    firstHealth := StartupHealthService(statePath, recoveryPath)
    firstState := firstHealth.Begin(scriptPath)
    AssertTrue(!firstState.SafeMode && firstState.ConsecutiveFailures == 0,
        "首次健康启动被误判为安全模式")
    firstFailure := firstHealth.RecordStartupFailure("failure one")
    AssertEqual(1, firstFailure.ConsecutiveFailures,
        "第一次启动失败没有计数")

    secondHealth := StartupHealthService(statePath, recoveryPath)
    secondHealth.Begin(scriptPath)
    secondFailure := secondHealth.RecordStartupFailure("failure two")
    AssertEqual(2, secondFailure.ConsecutiveFailures,
        "第二次启动失败没有连续累计")

    thirdHealth := StartupHealthService(statePath, recoveryPath)
    thirdState := thirdHealth.Begin(scriptPath)
    AssertTrue(!thirdState.SafeMode,
        "第三次启动尚未失败时过早进入安全模式")
    thirdFailure := thirdHealth.RecordStartupFailure("failure three")
    AssertTrue(thirdFailure.SafeMode
            && thirdFailure.ConsecutiveFailures == 3,
        "连续三次启动失败没有进入安全模式")
    safeHealth := StartupHealthService(statePath, recoveryPath)
    AssertTrue(safeHealth.Begin(scriptPath).SafeMode,
        "安全模式没有跨进程启动保留")

    plannedStatePath := testRoot "\planned-health.json"
    plannedRecoveryPath := testRoot "\planned-recovery.json"
    plannedHealth := StartupHealthService(plannedStatePath,
        plannedRecoveryPath)
    plannedHealth.Begin(scriptPath)
    plannedHealth.PrepareRestart()
    restartedHealth := StartupHealthService(plannedStatePath,
        plannedRecoveryPath)
    restartedState := restartedHealth.Begin(scriptPath)
    AssertTrue(!restartedState.SafeMode
            && restartedState.ConsecutiveFailures == 0,
        "计划内重载被计为崩溃")
    restartedHealth.MarkRunning()
    restartedHealth.MarkStable("mapping-good")
    AssertTrue(restartedHealth.HasRecovery(),
        "稳定启动没有保存最后正常配置")

    repository := RecoveryRepository(scriptPath, "mapping-bad")
    AssertTrue(restartedHealth.Restore(repository)
            && repository.Body == "mapping-good",
        "最后正常配置没有恢复映射")
    restartedHealth.MarkClean()
    cleanHealth := StartupHealthService(plannedStatePath,
        plannedRecoveryPath)
    cleanState := cleanHealth.Begin(scriptPath)
    AssertEqual(0, cleanState.ConsecutiveFailures,
        "正常退出后仍保留连续失败计数")
    cleanHealth.MarkClean()

    staleStatePath := testRoot "\stale-session-health.json"
    staleRecoveryPath := testRoot "\stale-session-recovery.json"
    staleFirst := StartupHealthService(staleStatePath, staleRecoveryPath)
    staleFirst.Begin(scriptPath)
    staleSecond := StartupHealthService(staleStatePath, staleRecoveryPath)
    staleSecond.Begin(scriptPath)
    staleStableRejected := false
    try staleFirst.MarkStable("stale-mapping")
    catch
        staleStableRejected := true
    AssertTrue(staleStableRejected && !FileExist(staleRecoveryPath),
        "过期启动会话覆盖了最后正常配置")
    AssertTrue(!staleFirst.PrepareRestart()
            && !staleFirst.RestartPrepared,
        "过期启动会话错误进入计划重启状态")
    staleSecond.MarkClean()

    invalidRecoveryPath := testRoot "\invalid-recovery.json"
    FileAppend(JsonCodec.Stringify(Map(
        "schema", "1", "created_at", "2026-07-30T00:00:00Z",
        "mapping_body", "mapping", "profile_snapshot", "profiles",
        "sha256", Sha256.HexText("mapping" Chr(30) "profiles")),
        true, true), invalidRecoveryPath, "UTF-8-RAW")
    invalidRecoveryHealth := StartupHealthService(
        testRoot "\invalid-recovery-health.json", invalidRecoveryPath)
    AssertTrue(!invalidRecoveryHealth.HasRecovery(),
        "字符串 schema 的最后正常配置被接受")

    corruptStatePath := testRoot "\corrupt-health.json"
    corruptRecoveryPath := testRoot "\corrupt-recovery.json"
    corruptText := "{broken startup health"
    FileAppend(corruptText, corruptStatePath, "UTF-8-RAW")
    corruptHealth := StartupHealthService("  " corruptStatePath "  ",
        "  " corruptRecoveryPath "  ")
    corruptState := corruptHealth.Begin(scriptPath)
    AssertTrue(corruptState.ConsecutiveFailures == 1
            && !corruptState.SafeMode
            && InStr(corruptState.LastError, "隔离") > 0
            && CountMatchingFiles(corruptStatePath ".corrupt-*") == 1,
        "损坏启动状态被当成干净启动或没有保留原始证据")
    corruptHealth.MarkClean()

    invalidSchemaPath := testRoot "\invalid-schema-health.json"
    FileAppend('{"schema":999}', invalidSchemaPath, "UTF-8-RAW")
    invalidSchemaHealth := StartupHealthService(invalidSchemaPath,
        testRoot "\invalid-schema-recovery.json")
    AssertEqual(1, invalidSchemaHealth.Begin(scriptPath).ConsecutiveFailures,
        "未知启动状态 schema 被当成干净启动")
    invalidSchemaHealth.MarkClean()

    oversizedStatePath := testRoot "\oversized-health.json"
    oversizedOutput := FileOpen(oversizedStatePath, "w", "UTF-8-RAW")
    oversizedBlock := Format("{:1024}", "x")
    Loop 129
        oversizedOutput.Write(oversizedBlock)
    oversizedOutput.Close()
    oversizedHealth := StartupHealthService(oversizedStatePath,
        testRoot "\oversized-recovery.json")
    oversizedState := oversizedHealth.Begin(scriptPath)
    AssertTrue(oversizedState.ConsecutiveFailures == 1
            && CountMatchingFiles(oversizedStatePath ".corrupt-*") == 1,
        "超大启动状态没有按不干净启动隔离恢复")
    oversizedHealth.MarkClean()

    WriteTestSuccess("startup-health-service")
} catch as healthTestError {
    testFailure := healthTestError.Message "`n" healthTestError.Stack
} finally {
    if DirExist(testRoot)
        DirDelete(testRoot, true)
}
if testFailure != "" {
    FileAppend(testFailure "`n", "**")
    ExitApp(1)
}
ExitApp(0)

class RecoveryRepository {
    __New(path, body) {
        this.ScriptPath := path
        this.Body := body
    }

    ReadRegionBody() => this.Body

    WriteRegionBody(body, expectedBody?) {
        if IsSet(expectedBody) && this.Body != expectedBody
            throw Error("injected mapping conflict")
        this.Body := String(body)
        return true
    }
}

CountMatchingFiles(pattern) {
    count := 0
    Loop Files, pattern, "F"
        count++
    return count
}
