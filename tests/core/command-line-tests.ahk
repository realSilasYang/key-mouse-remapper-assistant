#Requires AutoHotkey v2.0.26 64-bit
#SingleInstance Off
#Warn All, StdOut

#Include ..\TestSupport.ahk
#Include ..\..\src\Core\CommandLine.ahk
#Include ..\..\src\Core\JsonCodec.ahk
#Include ..\..\src\Core\Sha256.ahk
#Include ..\..\src\Core\CrossProcessWriteLock.ahk
#Include ..\..\src\Core\ApplicationControlQueue.ahk
#Include ..\..\src\Core\RuleSpec.ahk
#Include ..\..\src\Core\DeviceIdentityService.ahk
#Include ..\..\src\Core\InputEvent.ahk
#Include ..\..\src\Core\RuleTimingResolver.ahk
#Include ..\..\src\Core\RuleSpecMigrationService.ahk
#Include ..\..\src\Core\RuleCompiler.ahk
#Include ..\..\src\Core\RuleConflictAnalyzer.ahk
#Include ..\..\src\Core\RuleConditionEvaluator.ahk
#Include ..\..\src\Core\RuleSimulationService.ahk
#Include ..\..\src\Core\MappingCodeRepository.ahk
#Include ..\..\src\Core\ScopedVariableStore.ahk
#Include ..\..\src\Core\InputBackend.ahk
#Include ..\..\src\Platform\Win32.ahk
#Include ..\..\src\Input\RawInputService.ahk
#Include ..\..\src\Core\RawInputBackend.ahk
#Include ..\..\src\Core\RulePackageService.ahk
#Include ..\..\src\Core\DiagnosticBundleService.ahk
#Include ..\..\src\Platform\WindowsContextService.ahk

testRoot := A_Temp "\key-mouse-remapper-assistant-cli-" A_TickCount "-"
    . Format("{:08X}", Random(0, 0xFFFFFFFF))
testFixtureScript := testRoot "\fixture.ahk"
testVariableFile := testRoot "\variables.json"
testPackageFile := testRoot "\rules.json"
DirCreate(testRoot)
testFailure := ""

try {
    FileAppend(BuildCliFixture(), testFixtureScript, "UTF-8-RAW")
    cliOutputs := []
    cliErrors := []
    cli := CommandLineApp(text => cliOutputs.Push(text),
        text => cliErrors.Push(text))

    relativePaths := cli.ParseArguments(["list", "--variables-path",
        "variables.json"], testFixtureScript, testVariableFile)
    AssertTrue(relativePaths.VariablePath == "variables.json"
            && relativePaths.ControlPath == "control-requests.json",
        "无目录变量路径错误派生到当前盘根目录")
    duplicateOptionExit := cli.Run(["version", "--script",
        testFixtureScript, "--script", testFixtureScript],
        testFixtureScript, testVariableFile)
    AssertTrue(duplicateOptionExit == 1 && cliErrors.Pop()
            == "全局选项不能重复：--script",
        "CLI 接受了重复的单值全局选项")
    extraArgumentExit := cli.Run(["version", "unexpected"],
        testFixtureScript, testVariableFile)
    AssertTrue(extraArgumentExit == 1 && InStr(cliErrors.Pop(), "用法："),
        "无参数 CLI 命令接受了多余位置参数")

    cliExit := cli.Run(["list", "--script", testFixtureScript],
        testFixtureScript, testVariableFile)
    AssertEqual(0, cliExit, "CLI list 退出码错误")
    testListDocument := JsonCodec.Parse(cliOutputs.Pop())
    AssertTrue(testListDocument["count"] == 1
        && testListDocument["rules"][1]["id"] == "cli-managed",
        "CLI list 输出错误")

    cliExit := cli.Run(["export", testPackageFile, "--script",
        testFixtureScript], testFixtureScript, testVariableFile)
    AssertTrue(cliExit == 0 && FileExist(testPackageFile),
        "CLI export 失败")
    testExportDocument := JsonCodec.Parse(cliOutputs.Pop())
    AssertEqual(1, testExportDocument["rules"],
        "CLI export 规则数量错误")

    cliExit := cli.Run(["validate", testPackageFile],
        testFixtureScript, testVariableFile)
    testValidationDocument := JsonCodec.Parse(cliOutputs.Pop())
    AssertTrue(cliExit == 0 && testValidationDocument["valid"].Value,
        "CLI validate 没有确认有效规则包")

    packageDocument := RulePackageService().Build(
        MappingCodeRepository(testFixtureScript).Load())
    FileDelete(testPackageFile)
    FileAppend(JsonCodec.Stringify(packageDocument, true, true) "`r`n",
        testPackageFile, "UTF-8-RAW")

    importTargetScript := testRoot "\import-target.ahk"
    FileAppend(BuildCliFixture(), importTargetScript, "UTF-8-RAW")
    cliExit := cli.Run(["import", testPackageFile, "rename", "--script",
        importTargetScript], importTargetScript, testVariableFile)
    if cliExit != 0
        throw Error("CLI import 失败：" (cliErrors.Length
            ? cliErrors.Pop() : "unknown"))
    testImportDocument := JsonCodec.Parse(cliOutputs.Pop())
    AssertTrue(cliExit == 0 && testImportDocument["imported"] >= 1,
        "CLI import 没有导入规则")

    cliExit := cli.Run(["capabilities"], testFixtureScript,
        testVariableFile)
    testCapabilityDocument := JsonCodec.Parse(cliOutputs.Pop())
    AssertTrue(cliExit == 0
        && testCapabilityDocument["backend"] == "raw-input"
        && testCapabilityDocument["available"].Value
        && testCapabilityDocument["device_identification"].Value
        && !testCapabilityDocument["requires_driver"].Value
        && !testCapabilityDocument["device_specific_suppression"].Value
        && !testCapabilityDocument["consumer_control"].Value
        && !testCapabilityDocument["suppresses_simple_hotkeys"].Value,
        "CLI capabilities 输出错误")

    cliExit := cli.Run(["variables", "set", "persistent", "mode",
        '"gaming"',
        "--variables-path", testVariableFile], testFixtureScript,
        testVariableFile)
    AssertEqual(0, cliExit, "CLI variables set 失败")
    variableDocument := JsonCodec.Parse(cliOutputs.Pop())
    AssertTrue(variableDocument["scopes"]["persistent"]["mode"]
            == "gaming", "CLI variables set 没有返回持久作用域")
    cliExit := cli.Run(["variables", "clear", "persistent", "mode",
        "--variables-path", testVariableFile], testFixtureScript,
        testVariableFile)
    AssertEqual(0, cliExit, "CLI variables clear 失败")
    variableDocument := JsonCodec.Parse(cliOutputs.Pop())
    AssertTrue(!variableDocument["scopes"]["persistent"].Has("mode"),
        "CLI variables clear 没有清理持久作用域")

    cliExit := cli.Run(["conflicts", "--script", testFixtureScript],
        testFixtureScript, testVariableFile)
    testConflictDocument := JsonCodec.Parse(cliOutputs.Pop())
    AssertTrue(cliExit == 0 && testConflictDocument["count"] == 0,
        "CLI conflicts 对无冲突规则返回错误")

    cliExit := cli.Run(["disable", "cli-managed", "--script",
        testFixtureScript], testFixtureScript, testVariableFile)
    disableDocument := JsonCodec.Parse(cliOutputs.Pop())
    AssertTrue(cliExit == 0 && disableDocument["changed"].Value
            && !disableDocument["enabled"].Value
            && disableDocument["notification"]["queued"].Value
            && !MappingCodeRepository(testFixtureScript).GetById(
                "cli-managed").Enabled,
        "CLI disable 没有暂停 managed 规则或排队热应用")
    cliExit := cli.Run(["enable", "cli-managed", "--script",
        testFixtureScript], testFixtureScript, testVariableFile)
    enableDocument := JsonCodec.Parse(cliOutputs.Pop())
    AssertTrue(cliExit == 0 && enableDocument["changed"].Value
            && enableDocument["enabled"].Value,
        "CLI enable 没有恢复 managed 规则")

    cliExit := cli.Run(["devices"], testFixtureScript, testVariableFile)
    deviceDocument := JsonCodec.Parse(cliOutputs.Pop())
    AssertTrue(cliExit == 0 && Type(deviceDocument["devices"]) == "Array"
            && !deviceDocument["selective_suppression"].Value,
        "CLI devices 没有返回诚实的观察设备能力")

    cliExit := cli.Run(["format", "--script", testFixtureScript],
        testFixtureScript, testVariableFile)
    formatDocument := JsonCodec.Parse(cliOutputs.Pop())
    AssertTrue(cliExit == 0 && formatDocument["changed"] == 0,
        "CLI format 错误改写规范 managed 脚本")

    legacyScript := testRoot "\legacy-managed.ahk"
    FileAppend(BuildLegacyManagedCliFixture(), legacyScript, "UTF-8-RAW")
    cliExit := cli.Run(["lint", "--script", legacyScript], legacyScript,
        testVariableFile)
    legacyLintDocument := JsonCodec.Parse(cliOutputs.Pop())
    AssertTrue(cliExit == 3 && !legacyLintDocument["valid"].Value
            && legacyLintDocument["warnings"][1]["code"]
                == "migration_required",
        "CLI lint 没有报告旧 RuleSpec")
    cliExit := cli.Run(["migrate", "--script", legacyScript], legacyScript,
        testVariableFile)
    migrationDocument := JsonCodec.Parse(cliOutputs.Pop())
    AssertTrue(cliExit == 0 && migrationDocument["changed"] == 1
            && migrationDocument["migrated"] == 1,
        "CLI migrate 没有迁移旧 RuleSpec")
    cliExit := cli.Run(["lint", "--script", legacyScript], legacyScript,
        testVariableFile)
    migratedLintDocument := JsonCodec.Parse(cliOutputs.Pop())
    AssertTrue(cliExit == 0 && migratedLintDocument["valid"].Value,
        "CLI migrate 后 lint 仍报告结构问题")

    cliExit := cli.Run(["diagnose", "--script", testFixtureScript,
        "--variables-path", testVariableFile], testFixtureScript,
        testVariableFile)
    diagnosticDocument := JsonCodec.Parse(cliOutputs.Pop())
    AssertTrue(cliExit == 0
            && !diagnosticDocument["privacy"]["full_paths_included"].Value
            && diagnosticDocument["context"]["configuration"]
                ["script_path"] is Map,
        "CLI diagnose 没有返回脱敏诊断包")

    cliExit := cli.Run(["version"], testFixtureScript, testVariableFile)
    versionDocument := JsonCodec.Parse(cliOutputs.Pop())
    AssertTrue(cliExit == 0 && versionDocument["name"]
            == "KeyMouseRemapperAssistant"
            && versionDocument["runtime"] == A_AhkVersion
            && versionDocument["rulespec_schema"] == RuleSpec.CurrentSchema,
        "CLI version 输出错误")

    controlQueue := ApplicationControlQueue(testRoot
        "\control-requests.json")
    controlRequests := controlQueue.ConsumeFor(testFixtureScript)
    AssertTrue(controlRequests.Length >= 2,
        "CLI 写命令没有生成目标脚本控制请求")

    failingRepository := FailingRollbackRepository()
    rollbackFailure := cli.RestoreImportState(failingRepository,
        "before-mapping")
    AssertTrue(failingRepository.WriteAttempted
            && InStr(rollbackFailure, "映射代码回滚失败"),
        "CLI 映射回滚没有返回错误")

    cliExit := cli.Run(["unknown-command"], testFixtureScript,
        testVariableFile)
    AssertTrue(cliExit == 1 && cliErrors.Length == 1,
        "CLI 未知命令没有返回结构化失败")
    WriteTestSuccess("command-line")
} catch as cliTestError {
    testFailure := cliTestError.Message "`n" cliTestError.Stack
} finally {
    if DirExist(testRoot)
        DirDelete(testRoot, true)
}
if testFailure != "" {
    FileAppend(testFailure "`n", "**")
    ExitApp(1)
}
ExitApp(0)

class FailingRollbackRepository {
    __New() {
        this.WriteAttempted := false
    }

    ReadRegionBody() => "changed-mapping"

    WriteRegionBody(*) {
        this.WriteAttempted := true
        throw Error("injected mapping rollback failure")
    }
}

BuildCliFixture() {
    spec := RuleSpec.Normalize(Map("schema", 2,
        "id", "cli-managed", "enabled", JsonBoolean(true),
        "description", "CLI 测试",
        "display", Map("source", "F13", "target", "F14",
            "scope", "全局", "purpose", "CLI 测试"),
        "from", Map("hotkey", "", "event", "down",
            "key", Map("kind", "keyboard", "name", "F13")),
        "conditions", [],
        "to", [Map("type", "send", "value", "{F14}")]))
    return "#Requires AutoHotkey v2.0`r`n"
        . "if HasCommandLineFlag(`"--syntax-check`")`r`n    ExitApp()`r`n"
        . MappingCodeRepository.RegionStart "`r`n"
        . MappingCodeRepository.RegionNotice "`r`n`r`n"
        . RuleCompiler.BuildManagedBlock(spec, "`r`n") "`r`n`r`n"
        . MappingCodeRepository.RegionEnd "`r`n"
        . "HasCommandLineFlag(flag) {`r`n"
        . "    for argument in A_Args`r`n"
        . "        if argument == flag`r`n            return true`r`n"
        . "    return false`r`n}`r`n"
}

BuildLegacyManagedCliFixture() {
    spec := RuleSpec.Normalize(Map(
        "schema", 2, "id", "legacy-managed",
        "enabled", JsonBoolean(true), "priority", 0,
        "stop_processing", JsonBoolean(true),
        "description", "legacy",
        "display", Map("source", "F16", "target", "F17",
            "scope", "全局", "purpose", "CLI migration test"),
        "from", Map("hotkey", "F16", "key", Map("name", "F16"),
            "modifiers", [], "optional_modifiers", [], "event", "down",
            "simultaneous", [], "sequence", []),
        "to", [Map("type", "send", "value", "{F17}")],
        "to_if_alone", [], "to_if_held_down", [],
        "to_after_key_up", [], "conditions", []))
    legacySpec := RuleSpec.Clone(spec)
    legacySpec["schema"] := 1
    for fieldName in ["enabled", "description", "conditions"]
        legacySpec.Delete(fieldName)
    canonical := JsonCodec.Stringify(legacySpec, true, true)
    digest := Sha256.HexText(canonical)
    block := "; @mapping-begin`r`n; @schema=1`r`n; @mode=managed"
        . "`r`n; @id=legacy-managed`r`n; @spec-begin`r`n"
    Loop Parse canonical, "`n", "`r"
        block .= "; " A_LoopField "`r`n"
    block .= "; @spec-end`r`n; @generated-sha256=" digest
        . "`r`n; @generated-begin`r`n; legacy generated"
        . "`r`n; @generated-end`r`n; @mapping-end"
    return "#Requires AutoHotkey v2.0`r`n"
        . "if HasCommandLineFlag(`"--syntax-check`")`r`n    ExitApp()`r`n"
        . MappingCodeRepository.RegionStart "`r`n"
        . MappingCodeRepository.RegionNotice "`r`n`r`n"
        . block "`r`n`r`n" MappingCodeRepository.RegionEnd "`r`n"
        . "HasCommandLineFlag(flag) {`r`n"
        . "    for argument in A_Args`r`n"
        . "        if argument == flag`r`n            return true`r`n"
        . "    return false`r`n}`r`n"
}
