#Requires AutoHotkey v2.0.26 64-bit
#SingleInstance Off
#Warn All, StdOut

#Include ..\TestSupport.ahk
#Include ..\..\src\Core\BoundedFileReader.ahk
#Include ..\..\src\Core\JsonCodec.ahk
#Include ..\..\src\Core\Sha256.ahk
#Include ..\..\src\Core\CrossProcessWriteLock.ahk
#Include ..\..\src\Core\RuleSpec.ahk
#Include ..\..\src\Core\RuleTimingResolver.ahk
#Include ..\..\src\Core\RuleSpecMigrationService.ahk
#Include ..\..\src\Core\RuleCompiler.ahk
#Include ..\..\src\Core\MappingCodeRepository.ahk
#Include ..\..\src\Core\RuleConditionEvaluator.ahk
#Include ..\..\src\Core\RulePackageService.ahk

testRoot := A_Temp "\key-mouse-remapper-assistant-package-" A_TickCount "-"
    . Format("{:08X}", Random(0, 0xFFFFFFFF))
DirCreate(testRoot)

try {
    sourcePath := testRoot "\source.ahk"
    targetPath := testRoot "\target.ahk"
    packagePath := testRoot "\rules.json"
    sourceSpecs := [
        BuildPackageSpec("managed-one", "F13", "F14", "源规则"),
        BuildRunPackageSpec("managed-run", "F15", "notepad.exe")]
    FileAppend(BuildPackageScript(sourceSpecs), sourcePath, "UTF-8-RAW")
    sourceRepository := MappingCodeRepository(sourcePath)
    service := RulePackageService()

    exportResult := service.ExportTo(packagePath, sourceRepository.Load())
    package := service.Read(packagePath)
    AssertTrue(exportResult.Rules == 2
            && package["rules"].Length == 2
            && service.ArrayContains(package["capabilities"],
                "managed_rules")
            && service.ArrayContains(package["capabilities"],
                "run_actions")
            && service.ArrayContains(package["permissions"],
                "generated_input")
            && service.ArrayContains(package["permissions"],
                "execute_process")
            && !service.ArrayContains(package["capabilities"], "raw_ahk")
            && !service.ArrayContains(package["permissions"], "raw_ahk"),
        "managed 规则包能力或权限推导错误")
    preview := service.Preview(package, ["managed-one"])
    AssertTrue(preview["selected_count"] == 1
            && preview["rules"][1]["selected"].Value
            && !preview["rules"][2]["selected"].Value,
        "规则包预览没有保留逐规则选择状态")

    schemaOne := service.Build(sourceRepository.Load())
    schemaOne["schema"] := 1
    for fieldName in ["version", "source", "tags", "capabilities",
            "permissions", "exported_at"]
        schemaOne.Delete(fieldName)
    ResignRulePackage(schemaOne)
    parsedSchemaOne := service.Parse(JsonCodec.Stringify(schemaOne,
        false, true))
    AssertTrue(parsedSchemaOne["source_schema"] == 1
            && parsedSchemaOne["rules"][1]["mode"] == "managed",
        "schema 1 managed 包没有迁移到当前结构")

    schemaTwo := service.Build(sourceRepository.Load())
    schemaTwo["schema"] := 2
    schemaTwo["profiles"] := [Map("id", "work", "name", "Work")]
    schemaTwo["capabilities"].Push("profiles")
    schemaTwo["permissions"].Push("profile_write")
    schemaTwo["rules"][1]["spec"]["profile"] := "work"
    ResignRulePackage(schemaTwo)
    parsedSchemaTwo := service.Parse(JsonCodec.Stringify(schemaTwo,
        false, true))
    AssertTrue(parsedSchemaTwo["source_schema"] == 2
            && !parsedSchemaTwo.Has("profiles")
            && !parsedSchemaTwo["rules"][1]["spec"].Has("profile")
            && !service.ArrayContains(parsedSchemaTwo["capabilities"],
                "profiles")
            && !service.ArrayContains(parsedSchemaTwo["permissions"],
                "profile_write"),
        "schema 2 档案数据没有迁移到单一全局规则集")

    rawPackage := service.Build(sourceRepository.Load())
    rawPackage["rules"] := [Map("mode", "raw", "id", "raw-forbidden",
        "block", "; @mapping-begin`n; @mapping-end",
        "sha256", Sha256.HexText(
            "; @mapping-begin`n; @mapping-end"))]
    ResignRulePackage(rawPackage)
    rawRejected := false
    try service.Parse(JsonCodec.Stringify(rawPackage, false, true))
    catch as rawError
        rawRejected := InStr(rawError.Message, "只支持 managed") > 0
    AssertTrue(rawRejected, "规则包仍接受 raw AHK 规则")

    rawExportRejected := false
    try service.Build([{Mode: "raw", Id: "raw-forbidden", Block: ""}])
    catch as rawExportError
        rawExportRejected := InStr(rawExportError.Message,
            "只能导出 managed") > 0
    AssertTrue(rawExportRejected, "导出路径仍接受 raw AHK 映射")

    targetSpecs := [
        BuildPackageSpec("managed-one", "F17", "F18", "目标旧规则"),
        BuildPackageSpec("target-only", "F19", "F20", "目标独有")]
    FileAppend(BuildPackageScript(targetSpecs), targetPath, "UTF-8-RAW")
    targetRepository := MappingCodeRepository(targetPath)
    skipResult := service.ImportFrom(packagePath, targetRepository, "skip")
    AssertTrue(skipResult.Imported == 1 && skipResult.Skipped == 1
            && targetRepository.Load().Length == 3
            && targetRepository.GetById("managed-one").Target == "F18",
        "skip 冲突策略覆盖了现有 managed 规则")
    replaceResult := service.ImportFrom(packagePath, targetRepository,
        "replace")
    AssertTrue(replaceResult.Replaced == 2
            && targetRepository.GetById("managed-one").Target == "F14"
            && InStr(FileRead(targetPath, "UTF-8"),
                "outside-region-sentinel"),
        "replace 冲突策略没有原位替换 managed 规则")
    renameResult := service.ImportFrom(packagePath, targetRepository,
        "rename")
    AssertTrue(renameResult.Renamed == 2
            && targetRepository.Load().Length == 5,
        "rename 冲突策略没有保留新旧 managed 规则")
    for renamedId in renameResult.Ids
        AssertTrue(renamedId != "managed-one" && renamedId != "managed-run"
                && targetRepository.GetById(renamedId).Mode == "managed",
            "rename 结果编号或模式错误")

    tampered := StrReplace(FileRead(packagePath, "UTF-8"),
        "源规则", "篡改规则")
    tamperRejected := false
    try service.Parse(tampered)
    catch
        tamperRejected := true
    AssertTrue(tamperRejected, "规则包完整性摘要没有阻止篡改")

    unknownManifest := service.Build(sourceRepository.Load())
    unknownManifest["capabilities"].Push("unknown-capability")
    ResignRulePackage(unknownManifest)
    unknownRejected := false
    try service.Parse(JsonCodec.Stringify(unknownManifest, false, true))
    catch
        unknownRejected := true
    AssertTrue(unknownRejected, "规则包接受了未知 capability")

    WriteTestSuccess("rule-package")
} finally {
    if DirExist(testRoot)
        DirDelete(testRoot, true)
}
ExitApp(0)

BuildPackageSpec(id, source, target, purpose) {
    return RuleSpec.Normalize(Map("schema", 2, "id", id,
        "enabled", JsonBoolean(true),
        "description", purpose,
        "display", Map("source", source, "target", target,
            "scope", "全局", "purpose", purpose),
        "from", Map("hotkey", "", "event", "down",
            "key", Map("kind", "keyboard", "name", source)),
        "conditions", [],
        "to", [Map("type", "send", "value", "{" target "}")]))
}

BuildRunPackageSpec(id, source, command) {
    return RuleSpec.Normalize(Map("schema", 2, "id", id,
        "enabled", JsonBoolean(true),
        "description", "运行受控命令",
        "display", Map("source", source, "target", command,
            "scope", "全局", "purpose", "运行受控命令"),
        "from", Map("hotkey", "", "event", "down",
            "key", Map("kind", "keyboard", "name", source)),
        "conditions", [],
        "to", [Map("type", "run", "value", command)]))
}

BuildPackageScript(specs) {
    text := "#Requires AutoHotkey v2.0.26 64-bit`r`n"
        . "if HasCommandLineFlag(`"--syntax-check`")`r`n"
        . "    ExitApp()`r`n"
        . "; outside-region-sentinel`r`n"
        . MappingCodeRepository.RegionStart "`r`n"
        . MappingCodeRepository.RegionNotice "`r`n`r`n"
    for spec in specs
        text .= RuleCompiler.BuildManagedBlock(spec, "`r`n") "`r`n`r`n"
    return text . MappingCodeRepository.RegionEnd "`r`n`r`n"
        . "HasCommandLineFlag(flag) {`r`n"
        . "    for argument in A_Args`r`n"
        . "        if argument == flag`r`n"
        . "            return true`r`n"
        . "    return false`r`n}`r`n"
}

ResignRulePackage(document) {
    payload := RuleSpec.Clone(document)
    payload.Delete("integrity")
    document["integrity"]["digest"] := Sha256.HexText(
        JsonCodec.Stringify(payload, false, true))
}
