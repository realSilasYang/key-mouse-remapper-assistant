#Requires AutoHotkey v2.0 64-bit
#SingleInstance Off
#Warn All, StdOut

#Include ..\TestSupport.ahk
#Include ..\..\src\Core\Sha256.ahk
#Include ..\..\src\Core\CrossProcessWriteLock.ahk
#Include ..\..\src\Core\PersistentHistoryService.ahk

testRoot := A_Temp "\key-mouse-remapper-assistant-history-" A_TickCount "-"
    . Format("{:08X}", Random(0, 0xFFFFFFFF))
DirCreate(testRoot)
historyPath := testRoot "\history.dat"
notificationPath := testRoot "\notification.txt"

try {
    relativeHistory := PersistentHistoryService("relative-history.dat",
        "relative-notification.txt", 2)
    AssertEqual(CrossProcessWriteLock.NormalizePath("relative-history.dat"),
        relativeHistory.HistoryPath, "操作历史没有固定相对路径的绝对位置")
    sameHistoryPathRejected := false
    try PersistentHistoryService(historyPath, historyPath, 2)
    catch
        sameHistoryPathRejected := true
    AssertTrue(sameHistoryPathRejected, "操作历史与通知文件允许使用同一路径")
    invalidLimitCount := 0
    for invalidLimit in [1.5, "2", 0] {
        try PersistentHistoryService(testRoot "\invalid-limit.dat",
            testRoot "\invalid-limit-note.txt", invalidLimit)
        catch
            invalidLimitCount++
    }
    AssertEqual(3, invalidLimitCount,
        "操作历史接受了字符串、小数或零容量")

    concurrentPath := testRoot "\concurrent-history.dat"
    concurrentFirst := PersistentHistoryService(concurrentPath,
        testRoot "\concurrent-first-note.txt", 4)
    concurrentSecond := PersistentHistoryService(concurrentPath,
        testRoot "\concurrent-second-note.txt", 4)
    concurrentFirst.Commit("mapping", "zero", "one", "first")
    concurrentSecond.Commit("mapping", "one", "two", "second")
    concurrentReload := PersistentHistoryService(concurrentPath,
        testRoot "\concurrent-reload-note.txt", 4)
    AssertEqual(2, concurrentReload.UndoEntries.Length,
        "两个历史实例发生顺序丢更新")

    history := PersistentHistoryService(historyPath, notificationPath, 2)
    AssertTrue(history.Commit("mapping", "甲`nA", "乙`nB", "新增第一条"),
        "有效变化没有写入历史")
    AssertTrue(!history.Commit("mapping", "same", "same", "无变化"),
        "相同快照错误写入历史")
    AssertTrue(history.Commit("settings", "old", "new", "修改设置"),
        "设置变化没有写入历史")
    AssertTrue(history.Commit("mapping", "before-3", "after-3", "第三条"),
        "第三条变化没有写入历史")
    AssertEqual(2, history.UndoEntries.Length, "历史容量没有按上限裁剪")
    currentHistoryText := FileRead(historyPath, "UTF-8")
    AssertTrue(InStr(currentHistoryText,
        PersistentHistoryService.Signature "`n") == 1,
        "新历史仍在写入旧项目签名")
    legacyBase64Path := testRoot "\legacy-base64.dat"
    FileAppend(StrReplace(currentHistoryText,
        PersistentHistoryService.Signature,
        PersistentHistoryService.LegacyBase64Signature, , , 1),
        legacyBase64Path, "UTF-8-RAW")
    legacyBase64History := PersistentHistoryService(legacyBase64Path,
        testRoot "\legacy-base64-note.txt", 2)
    AssertEqual(2, legacyBase64History.UndoEntries.Length,
        "旧项目 V2 历史签名不再兼容")

    reloaded := PersistentHistoryService(historyPath, notificationPath, 2)
    AssertEqual(2, reloaded.UndoEntries.Length, "Reload 后撤销栈没有恢复")
    applier := TestHistoryApplier("after-3")
    AssertTrue(reloaded.Undo(ObjBindMethod(applier, "Apply"), &entry),
        "持久化历史无法撤销")
    AssertEqual("before-3", applier.Current, "撤销没有应用 Before 快照")
    AssertEqual("第三条", entry.Label, "撤销记录标签损坏")

    reloadedAgain := PersistentHistoryService(historyPath, notificationPath, 2)
    AssertTrue(reloadedAgain.CanRedo(), "Reload 后重做栈没有恢复")
    AssertTrue(reloadedAgain.Redo(ObjBindMethod(applier, "Apply"), &entry),
        "持久化历史无法重做")
    AssertEqual("after-3", applier.Current, "重做没有应用 After 快照")

    structuredAction := {Kind: "add", Target: "LShift -> F23", Fields: []}
    AssertTrue(reloadedAgain.Commit("mapping", "after-3", "after-4",
        structuredAction), "结构化映射动作没有写入历史")
    settingsAction := {Kind: "settings", Target: "",
        Fields: ["ui-language", "theme"]}
    AssertTrue(reloadedAgain.Commit("settings", "settings-1", "settings-2",
        settingsAction), "结构化设置动作没有写入历史")
    structuredReload := PersistentHistoryService(historyPath, notificationPath, 2)
    AssertEqual("add", structuredReload.UndoEntries[1].Action.Kind,
        "结构化映射动作类型没有跨 Reload 保存")
    AssertEqual("LShift -> F23", structuredReload.UndoEntries[1].Action.Target,
        "结构化映射目标没有跨 Reload 保存")
    AssertEqual("settings", structuredReload.UndoEntries[2].Action.Kind,
        "结构化设置动作类型没有跨 Reload 保存")
    AssertEqual("ui-language|theme",
        structuredReload.UndoEntries[2].Action.Fields[1] "|"
            structuredReload.UndoEntries[2].Action.Fields[2],
        "结构化设置字段没有跨 Reload 保存")

    reloadedAgain.SetPendingNotification("H2|U|structured-action")
    AssertEqual("H2|U|structured-action",
        reloadedAgain.ConsumePendingNotification(), "跨 Reload 气泡文字损坏")
    AssertEqual("", reloadedAgain.ConsumePendingNotification(),
        "待显示气泡没有在读取后清除")

    oversizedNotification := ""
    Loop PersistentHistoryService.MaximumNotificationCharacters + 1
        oversizedNotification .= "x"
    oversizedNotificationRejected := false
    try reloadedAgain.SetPendingNotification(oversizedNotification)
    catch
        oversizedNotificationRejected := true
    AssertTrue(oversizedNotificationRejected
            && !FileExist(notificationPath),
        "通知写入 API 没有拒绝超大文本")

    oversizedNotificationFile := FileOpen(notificationPath, "w", "UTF-8-RAW")
    AssertTrue(IsObject(oversizedNotificationFile),
        "无法建立超大通知文件测试夹具")
    notificationChunk := Format("{:1024}", "x")
    Loop PersistentHistoryService.MaximumNotificationBytes // 1024 + 1
        oversizedNotificationFile.Write(notificationChunk)
    oversizedNotificationFile.Close()
    AssertEqual("", reloadedAgain.ConsumePendingNotification(),
        "外部超大通知文件在完整读取前没有被拒绝")
    AssertTrue(!FileExist(notificationPath),
        "被拒绝的外部超大通知文件没有在领取后清理")

    transactionPath := testRoot "\transaction.dat"
    failingHistory := FailingHistoryService(transactionPath,
        testRoot "\transaction-note.txt", 4)
    failingHistory.FailHistoryWrites := true
    commitFailed := false
    try failingHistory.Commit("mapping", "before", "after", "失败提交")
    catch
        commitFailed := true
    AssertTrue(commitFailed && failingHistory.UndoEntries.Length == 0,
        "提交落盘失败后仍污染了内存撤销栈")

    failingHistory.FailHistoryWrites := false
    AssertTrue(failingHistory.Commit("mapping", "before", "after", "可撤销"),
        "事务测试历史无法建立")
    rollbackApplier := TestHistoryApplier("after")
    failingHistory.FailHistoryWrites := true
    undoFailed := false
    try failingHistory.Undo(ObjBindMethod(rollbackApplier, "Apply"))
    catch
        undoFailed := true
    AssertTrue(undoFailed && rollbackApplier.Current == "after",
        "撤销栈落盘失败后没有恢复已应用的真实状态")
    AssertTrue(failingHistory.CanUndo() && !failingHistory.CanRedo(),
        "撤销落盘失败后内存栈发生了半提交")

    compactHistory := PersistentHistoryService(testRoot "\compact.dat",
        testRoot "\compact-note.txt", 2)
    compactEncoded := compactHistory.Encode("一段用于比较编码体积的中文文本")
    utf8Bytes := StrPut("一段用于比较编码体积的中文文本", "UTF-8") - 1
    AssertTrue(StrLen(compactEncoded) < utf8Bytes * 2,
        "历史记录仍使用体积翻倍的十六进制编码")
    oversizedHistory := PersistentHistoryService(testRoot "\oversized.dat",
        testRoot "\oversized-note.txt", 2, 4096)
    oversizedRejected := false
    try oversizedHistory.Commit("mapping", "", Format("{:6000}", "x"),
        "超大记录")
    catch
        oversizedRejected := true
    AssertTrue(oversizedRejected && oversizedHistory.UndoEntries.Length == 0,
        "超过总容量的历史记录没有被拒绝或污染了栈")

    invalidKindRejected := false
    try compactHistory.Commit("mapping|corrupt", "before", "after", "非法类型")
    catch
        invalidKindRejected := true
    AssertTrue(invalidKindRejected && compactHistory.UndoEntries.Length == 0,
        "操作历史类型允许破坏单行记录结构")

    oversizedLoadPath := testRoot "\oversized-load.dat"
    FileAppend(Format("{:5000}", "x"), oversizedLoadPath, "UTF-8-RAW")
    oversizedLoadHistory := PersistentHistoryService(oversizedLoadPath,
        testRoot "\oversized-load-note.txt", 2, 4096)
    AssertTrue(oversizedLoadHistory.LoadWarning != ""
            && !FileExist(oversizedLoadPath)
            && HasQuarantinedHistory(testRoot,
                "oversized-load.dat.corrupt-"),
        "超大历史文件在读取前没有被拒绝并隔离")

    corruptPath := testRoot "\corrupt.dat"
    FileAppend(PersistentHistoryService.Signature "`nBROKEN`n",
        corruptPath, "UTF-8-RAW")
    corruptHistory := PersistentHistoryService(corruptPath,
        testRoot "\corrupt-note.txt", 2)
    AssertTrue(corruptHistory.LoadWarning != ""
        && !FileExist(corruptPath), "损坏历史没有报告并隔离")
    AssertTrue(HasQuarantinedHistory(testRoot, "corrupt.dat.corrupt-"),
        "损坏历史隔离文件没有保留诊断证据")
    WriteTestSuccess("persistent-history-service")
} finally {
    if DirExist(testRoot)
        DirDelete(testRoot, true)
}
ExitApp(0)

class TestHistoryApplier {
    __New(initialState) {
        this.Current := initialState
    }

    Apply(desiredState, expectedState, kind) {
        if this.Current != expectedState
            throw Error("测试状态与历史预期不一致")
        this.Current := desiredState
    }
}

class FailingHistoryService extends PersistentHistoryService {
    __New(historyPath, notificationPath, maxEntries) {
        this.FailHistoryWrites := false
        super.__New(historyPath, notificationPath, maxEntries)
    }

    WriteAtomic(path, text) {
        if this.FailHistoryWrites && path == this.HistoryPath
            throw Error("注入的历史写入失败")
        return super.WriteAtomic(path, text)
    }
}

HasQuarantinedHistory(directory, prefix) {
    Loop Files directory "\*", "F" {
        if SubStr(A_LoopFileName, 1, StrLen(prefix)) == prefix
            return true
    }
    return false
}
