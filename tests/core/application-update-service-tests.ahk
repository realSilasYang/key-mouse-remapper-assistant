#Requires AutoHotkey v2.0 64-bit
#Warn All, StdOut

; 更新服务的纯逻辑回归测试；网络、下载与替换由 PowerShell 脚本的发布测试覆盖。

#Include ..\..\src\Core\ApplicationUpdateService.ahk

AssertApplicationUpdate(value, message) {
    if !value
        throw Error(message)
}

ApplicationUpdateTestText(template, values*) {
    return values.Length ? Format(template, values*) : template
}

CreateApplicationUpdateTestService(root, compiled := false) {
    return ApplicationUpdateService({
        Repository: "owner/repository",
        CurrentVersion: "1.2.3",
        HelperPath: A_ScriptFullPath,
        HelperLocalizationPath: A_ScriptFullPath,
        InstallRoot: root,
        EntryPath: A_ScriptFullPath,
        EditableSourcePath: A_ScriptFullPath,
        InterpreterPath: A_AhkPath,
        Compiled: compiled,
        UiLanguage: "zh-CN",
        Log: (*) => "",
        Localize: ApplicationUpdateTestText,
        OnResult: (*) => "",
        Now: () => 1,
        Quote: (value) => '"' value '"'
    })
}

CreateAvailableUpdateResult(currentVersion := "1.2.3",
    targetVersion := "1.2.4") {
    releaseBase := "https://github.com/owner/repository/releases"
    downloadBase := releaseBase "/download/v" targetVersion "/"
    return {
        Status: "available",
        CurrentVersion: currentVersion,
        Version: targetVersion,
        Tag: "v" targetVersion,
        ReleaseUrl: releaseBase "/tag/v" targetVersion,
        BinaryUrl: downloadBase "key-mouse-remapper-assistant-"
            targetVersion "-windows-x64.zip",
        SourceUrl: downloadBase "key-mouse-remapper-assistant-"
            targetVersion "-source.zip",
        BinarySha256: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
        SourceSha256: "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB",
        ChecksumsUrl: "",
        Error: ""
    }
}

CreateCurrentUpdateResult() {
    return {
        Status: "current",
        CurrentVersion: "1.2.3",
        Version: "1.2.3",
        Tag: "v1.2.3",
        ReleaseUrl: "https://example.invalid/release",
        BinaryUrl: "",
        SourceUrl: "",
        BinarySha256: "",
        SourceSha256: "",
        ChecksumsUrl: "",
        Error: ""
    }
}

RunApplicationUpdateServiceTests() {
    AssertApplicationUpdate(ApplicationUpdateService.CompareVersions(
        "1.0.1", "1.0.0") == 1, "补丁版本比较错误")
    AssertApplicationUpdate(ApplicationUpdateService.CompareVersions(
        "1.10.0", "1.9.9") == 1, "版本号被按字符串比较")
    AssertApplicationUpdate(ApplicationUpdateService.CompareVersions(
        "2.0.0", "2.0.0") == 0, "相同版本比较错误")
    AssertApplicationUpdate(ApplicationUpdateService.CompareVersions(
        "1.0.0", "2.0.0") == -1, "主版本比较错误")
    rejected := false
    try ApplicationUpdateService.CompareVersions("1.0", "1.0.0")
    catch
        rejected := true
    AssertApplicationUpdate(rejected, "无效语义版本没有被拒绝")
    rejected := false
    try ApplicationUpdateService.CompareVersions("01.0.0", "1.0.0")
    catch
        rejected := true
    AssertApplicationUpdate(rejected, "带前导零的非规范版本没有被拒绝")

    testRoot := A_Temp "\KeyMouseRemapperUpdateServiceTest-"
        DllCall("kernel32\GetCurrentProcessId", "UInt") "-" A_TickCount
    DirCreate(testRoot)
    try {
        AssertApplicationUpdate(ApplicationUpdateService.DeterminePackageKind(
            true, testRoot) == "compiled", "编译版运行形态判断错误")
        AssertApplicationUpdate(ApplicationUpdateService.DeterminePackageKind(
            false, testRoot) == "source", "普通源码版运行形态判断错误")

        gitMarker := testRoot "\.git"
        FileAppend("gitdir: ..\worktrees\test", gitMarker, "UTF-8")
        AssertApplicationUpdate(ApplicationUpdateService.DeterminePackageKind(
            false, testRoot) == "source-git",
            "git worktree 的 .git 文件被误判为非 Git 源码")

        service := CreateApplicationUpdateTestService(testRoot)
        validResult := CreateAvailableUpdateResult()
        AssertApplicationUpdate(service.ValidateCheckResult(validResult,
            true) == validResult, "有效更新结果没有通过二次校验")

        invalidDigestResult := CreateAvailableUpdateResult()
        invalidDigestResult.SourceSha256 := "not-a-sha256"
        rejected := false
        try service.ValidateCheckResult(invalidDigestResult, true)
        catch
            rejected := true
        AssertApplicationUpdate(rejected,
            "格式错误的 GitHub 发行附件摘要没有被拒绝")

        untrustedUrlResult := CreateAvailableUpdateResult()
        untrustedUrlResult.SourceUrl := "https://example.invalid/source.zip"
        rejected := false
        try service.ValidateCheckResult(untrustedUrlResult, true)
        catch
            rejected := true
        AssertApplicationUpdate(rejected,
            "非固定 GitHub 发行附件地址没有被拒绝")

        oversizedResultPath := testRoot "\oversized-result.ini"
        FileAppend("[Update]`nError="
            . Format("{:70000}", "x"), oversizedResultPath, "UTF-8")
        rejected := false
        try service.ReadResult(oversizedResultPath)
        catch
            rejected := true
        AssertApplicationUpdate(rejected,
            "超过大小上限的更新结果文件没有被拒绝")

        currentResult := CreateCurrentUpdateResult()
        AssertApplicationUpdate(service.ValidateCheckResult(currentResult)
            == currentResult, "最新版本结果被误判为更新失败")
        olderCurrentResult := CreateCurrentUpdateResult()
        olderCurrentResult.Version := "1.2.2"
        olderCurrentResult.Tag := "v1.2.2"
        normalizedOlderCurrent := service.ValidateCheckResult(
            olderCurrentResult)
        AssertApplicationUpdate(normalizedOlderCurrent.Status == "current"
            && normalizedOlderCurrent.CurrentVersion == "1.2.3"
            && normalizedOlderCurrent.Version == "1.2.3",
            "远端旧版本结果没有归一化为当前版本")
        legacyNoUpdateResult := service.ErrorResult(
            "没有可安装的应用更新")
        normalizedCurrent := service.ValidateCheckResult(
            legacyNoUpdateResult)
        AssertApplicationUpdate(normalizedCurrent.Status == "current"
            && normalizedCurrent.CurrentVersion == "1.2.3"
            && normalizedCurrent.Version == "1.2.3",
            "旧检查器的无更新结果没有归一化为最新版本")
        actualErrorResult := service.ErrorResult("网络连接失败")
        AssertApplicationUpdate(service.ValidateCheckResult(
            actualErrorResult) == actualErrorResult,
            "真正的更新检查错误被误判为最新版本")

        AssertApplicationUpdate(service.ShouldWaitForResultPublication(
            false, 1000) && service.WorkerExitObserved
                && service.WorkerExitObservedTicks == 1000,
            "更新子进程刚退出时没有等待结果文件发布")
        AssertApplicationUpdate(service.ShouldWaitForResultPublication(
            false, 2499), "结果文件发布宽限期提前结束")
        AssertApplicationUpdate(!service.ShouldWaitForResultPublication(
            false, 2500), "结果文件发布宽限期没有按时结束")
        AssertApplicationUpdate(!service.ShouldWaitForResultPublication(
            true, 2600) && !service.WorkerExitObserved,
            "更新子进程恢复运行后没有清除退出观察状态")

        mismatchedResult := CreateAvailableUpdateResult("1.2.2")
        rejected := false
        try service.ValidateCheckResult(mismatchedResult, true)
        catch
            rejected := true
        AssertApplicationUpdate(rejected,
            "来自其他当前版本的陈旧检查结果没有被拒绝")

        downgradeResult := CreateAvailableUpdateResult("1.2.3", "1.2.2")
        rejected := false
        try service.ValidateCheckResult(downgradeResult, true)
        catch
            rejected := true
        AssertApplicationUpdate(rejected, "可用更新结果允许降级安装")

        FileDelete(gitMarker)
        sourceService := CreateApplicationUpdateTestService(testRoot)
        missingSourceResult := CreateAvailableUpdateResult()
        missingSourceResult.SourceUrl := ""
        rejected := false
        try sourceService.ValidateCheckResult(missingSourceResult, true)
        catch
            rejected := true
        AssertApplicationUpdate(rejected,
            "普通源码版接受了缺少源码包的更新结果")

        rejected := false
        try ApplicationUpdateService({
            Repository: "owner/repository/extra",
            CurrentVersion: "1.2.3",
            HelperPath: A_ScriptFullPath,
            InstallRoot: testRoot,
            EntryPath: A_ScriptFullPath,
            InterpreterPath: A_AhkPath,
            Compiled: false,
            UiLanguage: "zh-CN",
            Log: (*) => "", Localize: ApplicationUpdateTestText,
            OnResult: (*) => "", Now: () => 1,
            Quote: (value) => '"' value '"'
        })
        catch
            rejected := true
        AssertApplicationUpdate(rejected, "无效更新仓库标识没有被拒绝")
    } finally {
        try DirDelete(testRoot, true)
    }
}

try {
    RunApplicationUpdateServiceTests()
    ExitApp(0)
} catch as testError {
    FileAppend(testError.Message "`n" testError.Stack "`n", "**")
    ExitApp(1)
}
