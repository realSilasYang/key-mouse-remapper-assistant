#Requires AutoHotkey v2.0 64-bit
#SingleInstance Off
#Warn All, StdOut

#Include ..\TestSupport.ahk
#Include ..\..\src\Core\JsonCodec.ahk
#Include ..\..\src\Core\Sha256.ahk
#Include ..\..\src\Core\CrossProcessWriteLock.ahk
#Include ..\..\src\Core\OutputRecoveryJournal.ahk
#Include ..\..\src\Core\OutputLedger.ahk

testRoot := A_Temp "\key-mouse-remapper-assistant-output-recovery-" A_TickCount "-"
    . Format("{:08X}", Random(0, 0xFFFFFFFF))
testFailure := ""
DirCreate(testRoot)
try {
    journalPath := testRoot "\output-recovery.json"
    journal := OutputRecoveryJournal(journalPath)
    journal.Update(["LShift", "lshift", "vk41", "SC01E"])
    normalizedKeys := journal.ReadKeys()
    AssertEqual(3, normalizedKeys.Length,
        "输出恢复日志没有按键名大小写去重")
    AssertEqual("LShift", normalizedKeys[1],
        "输出恢复日志没有保留首个规范名称")

    recoveredKeyNames := []
    releasedCount := journal.Recover(
        (keyName) => recoveredKeyNames.Push(keyName))
    AssertEqual(3, releasedCount, "崩溃恢复没有释放全部遗留输出")
    AssertEqual(3, recoveredKeyNames.Length, "崩溃恢复回调次数错误")
    AssertTrue(!FileExist(journalPath), "成功恢复后没有删除恢复日志")

    journal.Update(["LCtrl", "LAlt", "LShift"])
    partialAttempts := []
    partialFailed := false
    try journal.Recover((keyName) => FailSelectedKeyUp(
        keyName, "LAlt", partialAttempts))
    catch as partialError {
        partialFailed := InStr(partialError.Message, "LAlt") > 0
    }
    AssertTrue(partialFailed, "部分按键抬起失败没有向调用方报告")
    retainedFailedKeys := journal.ReadKeys()
    AssertEqual(1, retainedFailedKeys.Length,
        "部分恢复失败没有精确保留失败按键")
    AssertEqual("LAlt", retainedFailedKeys[1],
        "部分恢复失败保留了错误的按键")

    aggregatePath := testRoot "\aggregate-failure-recovery.json"
    aggregateJournal := FailingRecoveryJournal(aggregatePath)
    aggregateJournal.Update(["LCtrl"])
    aggregateJournal.FailWrites := true
    aggregateFailureReported := false
    try aggregateJournal.Recover((keyName) => ThrowReleaseFailure())
    catch as aggregateError
        aggregateFailureReported := InStr(aggregateError.Message,
            "injected release") > 0 && InStr(aggregateError.Message,
            "injected journal rewrite") > 0
    AssertTrue(aggregateFailureReported && FileExist(aggregatePath),
        "恢复回调和日志回写同时失败时丢失了错误或保守日志")

    orderingPath := testRoot "\ledger-ordering.json"
    orderingJournal := OutputRecoveryJournal(orderingPath)
    orderingLedger := OutputLedger(ObjBindMethod(orderingJournal, "Update"))
    orderingProbe := {DownObservedPersisted: false,
        UpObservedJournal: false}
    orderingLedger.Press("LShift", "rule-a",
        (keyName, phase) => orderingProbe.DownObservedPersisted := phase == "down"
            && FileExist(orderingPath)
            && orderingJournal.ReadKeys().Length == 1)
    AssertTrue(orderingProbe.DownObservedPersisted,
        "输出按下前没有先持久化恢复账本")
    orderingLedger.Release("LShift", "rule-a",
        (keyName, phase) => orderingProbe.UpObservedJournal := phase == "up"
            && FileExist(orderingPath))
    AssertTrue(orderingProbe.UpObservedJournal,
        "输出抬起前恢复日志已被过早清除")
    AssertTrue(!FileExist(orderingPath),
        "输出抬起成功后没有清除恢复日志")

    failingLedger := OutputLedger((keys) => ThrowPersistFailure())
    persistFailed := false
    persistProbe := {SentDown: false}
    try failingLedger.Press("LCtrl", "rule-b",
        (keyName, phase) => persistProbe.SentDown := true)
    catch as caughtPersistError
        persistFailed := InStr(caughtPersistError.Message,
            "injected persist") > 0
    AssertTrue(persistFailed, "持久化失败没有阻止输出按下")
    AssertTrue(!persistProbe.SentDown, "持久化失败后仍发送了输出按下")
    AssertEqual(0, failingLedger.Keys.Count,
        "持久化失败后留下了未发送的内存按键")

    releasePath := testRoot "\release-all.json"
    releaseJournal := OutputRecoveryJournal(releasePath)
    releaseLedger := OutputLedger(ObjBindMethod(releaseJournal, "Update"))
    releaseLedger.Press("LCtrl", "rule-c", (keyName, phase) => 0)
    releaseLedger.Press("LAlt", "rule-c", (keyName, phase) => 0)
    releaseLedger.Press("LShift", "rule-c", (keyName, phase) => 0)
    releaseAttempts := []
    releaseAllFailed := false
    try releaseLedger.ReleaseAll((keyName, phase) =>
        FailSelectedLedgerRelease(keyName, phase, "LAlt", releaseAttempts))
    catch as releaseAllError
        releaseAllFailed := InStr(releaseAllError.Message, "LAlt") > 0
    AssertTrue(releaseAllFailed && releaseAttempts.Length == 3,
        "批量释放失败没有汇报异常或阻止了后续按键释放")
    AssertEqual(1, releaseLedger.Keys.Count,
        "批量释放失败没有精确保留内存按键")
    AssertTrue(releaseLedger.Keys.Has("lalt"),
        "批量释放失败保留了错误的内存按键")
    retainedKeys := releaseJournal.ReadKeys()
    AssertEqual(1, retainedKeys.Length,
        "批量释放失败没有精确保留恢复日志")
    AssertEqual("LAlt", retainedKeys[1],
        "批量释放日志保留了错误的按键")

    retryPath := testRoot "\release-retry.json"
    retryJournal := OutputRecoveryJournal(retryPath)
    retryLedger := OutputLedger(ObjBindMethod(retryJournal, "Update"))
    retryLedger.Press("F2", "rule-retry", (keyName, phase) => 0)
    releaseFailed := false
    try retryLedger.Release("F2", "rule-retry",
        (keyName, phase) => ThrowReleaseFailure())
    catch as retryError
        releaseFailed := InStr(retryError.Message, "injected release") > 0
    AssertTrue(releaseFailed
            && retryLedger.HasOwner("F2", "rule-retry"),
        "输出抬起失败后没有保留可重试的所有权")
    AssertEqual(1, retryJournal.ReadKeys().Length,
        "输出抬起失败后恢复日志没有保留按键")
    AssertTrue(retryLedger.Release("F2", "rule-retry",
            (keyName, phase) => 0),
        "输出抬起失败后同一所有者无法重试")
    AssertTrue(!FileExist(retryPath),
        "输出抬起重试成功后没有清理恢复日志")

    corruptPath := testRoot "\corrupt-recovery.json"
    FileAppend("not-json", corruptPath, "UTF-8-RAW")
    corruptJournal := OutputRecoveryJournal(corruptPath)
    corruptRejected := false
    try corruptJournal.Recover((keyName) => 0)
    catch as corruptError
        corruptRejected := InStr(corruptError.Message, "损坏") > 0
    AssertTrue(corruptRejected && !FileExist(corruptPath)
            && CountMatchingFiles(corruptPath ".corrupt-*") == 1,
        "损坏的输出恢复日志没有被隔离并报告")
    AssertEqual(0, corruptJournal.Recover((keyName) => 0),
        "隔离损坏日志后无法继续启动恢复流程")

    longKey := ""
    Loop OutputRecoveryJournal.MaximumKeyNameLength + 1
        longKey .= "A"
    longKeyPath := testRoot "\long-key-recovery.json"
    FileAppend(JsonCodec.Stringify(Map(
        "schema", OutputRecoveryJournal.Schema,
        "keys", [longKey]), false, true), longKeyPath, "UTF-8-RAW")
    longKeyJournal := OutputRecoveryJournal("  " longKeyPath "  ")
    AssertEqual(CrossProcessWriteLock.NormalizePath(longKeyPath),
        longKeyJournal.FilePath, "输出恢复日志路径没有在构造时规范化")
    releaseProbe := {Calls: 0}
    longKeyRejected := false
    try longKeyJournal.Recover(
        (keyName) => releaseProbe.Calls := releaseProbe.Calls + 1)
    catch as longKeyError
        longKeyRejected := InStr(longKeyError.Message, "损坏") > 0
    AssertTrue(longKeyRejected && releaseProbe.Calls == 0
            && CountMatchingFiles(longKeyPath ".corrupt-*") == 1,
        "超长伪键名进入了输出释放回调或未被隔离")

    stringSchemaPath := testRoot "\string-schema-recovery.json"
    FileAppend(JsonCodec.Stringify(Map("schema", "1",
        "updated_at", "2026-07-30T00:00:00Z", "keys", ["LCtrl"]),
        false, true), stringSchemaPath, "UTF-8-RAW")
    AssertCorruptRecoveryJournalRejected(stringSchemaPath,
        "字符串 schema 被输出恢复日志接受")

    extraFieldPath := testRoot "\extra-field-recovery.json"
    FileAppend(JsonCodec.Stringify(Map(
        "schema", OutputRecoveryJournal.Schema,
        "updated_at", "2026-07-30T00:00:00Z", "keys", ["LCtrl"],
        "ignored", true), false, true), extraFieldPath, "UTF-8-RAW")
    AssertCorruptRecoveryJournalRejected(extraFieldPath,
        "输出恢复日志接受了未知根字段")

    WriteTestSuccess("output-recovery-journal")
} catch as outputRecoveryTestError {
    testFailure := outputRecoveryTestError.Message "`n"
        . outputRecoveryTestError.Stack
} finally {
    if DirExist(testRoot)
        DirDelete(testRoot, true)
}
if testFailure != "" {
    FileAppend(testFailure "`n", "**")
    ExitApp(1)
}
ExitApp(0)

FailSelectedKeyUp(keyName, failedKey, attempts) {
    attempts.Push(keyName)
    if keyName == failedKey
        throw Error("injected release failure")
}

ThrowPersistFailure() {
    throw Error("injected persist failure")
}

ThrowReleaseFailure() {
    throw Error("injected release failure")
}

FailSelectedLedgerRelease(keyName, phase, failedKey, attempts := "") {
    if Type(attempts) == "Array"
        attempts.Push(keyName)
    if phase == "up" && keyName == failedKey
        throw Error("injected ledger release failure")
}

CountMatchingFiles(pattern) {
    count := 0
    Loop Files, pattern, "F"
        count++
    return count
}

AssertCorruptRecoveryJournalRejected(path, message) {
    callbackProbe := {Calls: 0}
    rejected := false
    try OutputRecoveryJournal(path).Recover(
        (keyName) => callbackProbe.Calls := callbackProbe.Calls + 1)
    catch as recoveryError
        rejected := InStr(recoveryError.Message, "损坏") > 0
    AssertTrue(rejected && callbackProbe.Calls == 0
            && CountMatchingFiles(path ".corrupt-*") == 1, message)
}

class FailingRecoveryJournal extends OutputRecoveryJournal {
    __New(filePath) {
        super.__New(filePath)
        this.FailWrites := false
    }

    WriteKeysLocked(normalizedKeys) {
        if this.FailWrites
            throw Error("injected journal rewrite failure")
        return super.WriteKeysLocked(normalizedKeys)
    }
}
