#Requires AutoHotkey v2.0 64-bit
#SingleInstance Off
#Warn All, StdOut

#Include ..\TestSupport.ahk
#Include ..\..\src\Core\Sha256.ahk
#Include ..\..\src\Core\CrossProcessWriteLock.ahk

if A_Args.Length && A_Args[1] == "--lock-child" {
    RunLockChild()
    ExitApp(0)
}

testRoot := A_Temp "\key-mouse-remapper-assistant-lock-" A_TickCount "-"
    . Format("{:08X}", Random(0, 0xFFFFFFFF))
targetPath := testRoot "\state.json"
testFailure := ""
childPid := 0
observerHandle := 0
DirCreate(testRoot)

try {
    AssertTrue(InStr(CrossProcessWriteLock.GetMutexName(targetPath),
            "Global\") == 1,
        "写锁互斥量没有覆盖同一用户的不同 Windows 会话")
    lease := CrossProcessWriteLock.Acquire(targetPath, 1000)
    AssertTrue(lease.Paths.Length == 1 && lease.Paths[1] != "",
        "单文件写锁没有返回规范化路径")
    AssertTrue(!lease.Recovered, "正常写锁被误报为废弃互斥量恢复")
    AssertTrue(lease.Release() && !lease.Release(),
        "写锁租约没有实现幂等释放")

    duplicateLease := CrossProcessWriteLock.AcquireMany([
        targetPath, StrUpper(targetPath)], 1000)
    AssertEqual(1, duplicateLease.Paths.Length,
        "写锁没有按 Windows 路径规则去重")
    duplicateLease.Release()

    rejectedTimeouts := 0
    for invalidTimeout in [1.5, "1000", -1, 0xFFFFFFFF] {
        try CrossProcessWriteLock.Acquire(targetPath, invalidTimeout)
        catch
            rejectedTimeouts++
    }
    AssertEqual(4, rejectedTimeouts,
        "写锁接受了字符串、分数或越界超时值")

    readyPath := testRoot "\ready"
    releasePath := testRoot "\release"
    childPid := StartLockChild(targetPath, readyPath, releasePath)
    WaitForTestFile(readyPath, 5000, "子进程没有取得测试写锁")
    timedOut := false
    try CrossProcessWriteLock.Acquire(targetPath, 80)
    catch as caughtWaitError
        timedOut := InStr(caughtWaitError.Message, "超时") > 0
    AssertTrue(timedOut, "另一进程持锁时没有按期限报告超时")
    FileAppend("release", releasePath, "UTF-8-RAW")
    ProcessWaitClose(childPid, 5)
    AssertTrue(!ProcessExist(childPid), "测试写锁子进程没有正常退出")
    childPid := 0

    abandonedReadyPath := testRoot "\abandoned-ready"
    abandonedReleasePath := testRoot "\abandoned-release"
    childPid := StartLockChild(targetPath, abandonedReadyPath,
        abandonedReleasePath)
    WaitForTestFile(abandonedReadyPath, 5000,
        "废弃恢复测试子进程没有取得写锁")
    observerHandle := DllCall("kernel32\CreateMutexW", "Ptr", 0,
        "Int", false, "WStr", CrossProcessWriteLock.GetMutexName(targetPath),
        "Ptr")
    AssertTrue(observerHandle, "无法保留废弃恢复测试的观察句柄")
    ProcessClose(childPid)
    ProcessWaitClose(childPid, 5)
    AssertTrue(!ProcessExist(childPid), "无法终止废弃恢复测试子进程")
    childPid := 0
    recoveredLease := CrossProcessWriteLock.Acquire(targetPath, 1000)
    AssertTrue(recoveredLease.Recovered,
        "进程异常退出后的废弃互斥量没有被识别")
    recoveredLease.Release()
    DllCall("kernel32\CloseHandle", "Ptr", observerHandle)
    observerHandle := 0

    WriteTestSuccess("cross-process-write-lock")
} catch as lockTestError {
    testFailure := lockTestError.Message "`n" lockTestError.Stack
} finally {
    if childPid && ProcessExist(childPid)
        try ProcessClose(childPid)
    if observerHandle
        try DllCall("kernel32\CloseHandle", "Ptr", observerHandle)
    if DirExist(testRoot)
        DirDelete(testRoot, true)
}
if testFailure != "" {
    FileAppend(testFailure "`n", "**")
    ExitApp(1)
}
ExitApp(0)

StartLockChild(targetPath, readyPath, releasePath) {
    quote := Chr(34)
    command := quote A_AhkPath quote " /ErrorStdOut "
        . quote A_ScriptFullPath quote " --lock-child "
        . quote targetPath quote " " quote readyPath quote " "
        . quote releasePath quote
    Run(command, , "Hide", &spawnedPid)
    return spawnedPid
}

RunLockChild() {
    if A_Args.Length != 4
        throw ValueError("写锁子进程参数数量错误。")
    childLease := CrossProcessWriteLock.Acquire(A_Args[2], 5000)
    FileAppend("ready", A_Args[3], "UTF-8-RAW")
    deadline := A_TickCount + 10000
    while !FileExist(A_Args[4]) && A_TickCount < deadline
        Sleep(10)
    childLease.Release()
}

WaitForTestFile(path, timeoutMs, errorMessage) {
    deadline := A_TickCount + timeoutMs
    while !FileExist(path) && A_TickCount < deadline
        Sleep(10)
    AssertTrue(FileExist(path), errorMessage)
}
