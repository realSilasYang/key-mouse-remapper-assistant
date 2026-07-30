#Requires AutoHotkey v2.0.26 64-bit
#SingleInstance Off
#Warn All, StdOut

#Include ..\TestSupport.ahk
#Include ..\..\src\Core\BoundedFileReader.ahk
#Include ..\..\src\Core\JsonCodec.ahk
#Include ..\..\src\Core\Sha256.ahk
#Include ..\..\src\Core\CrossProcessWriteLock.ahk
#Include ..\..\src\Core\RuleSpec.ahk
#Include ..\..\src\Core\RuleSpecMigrationService.ahk
#Include ..\..\src\Core\RuleCompiler.ahk
#Include ..\..\src\Core\MappingCodeRepository.ahk

testRoot := A_Temp "\key-mouse-remapper-assistant-repository-" A_TickCount "-"
    . Format("{:08X}", Random(0, 0xFFFFFFFF))
scriptPath := testRoot "\fixture.ahk"
DirCreate(testRoot)

try {
    firstSpec := BuildRepositorySpec("first", "F13", "F14", "第一条")
    secondSpec := BuildRepositorySpec("second", "F14", "F13", "第二条")
    FileAppend(BuildRepositoryScript([firstSpec, secondSpec]), scriptPath,
        "UTF-8-RAW")
    repository := MappingCodeRepository(scriptPath)

    mappings := repository.Load()
    AssertTrue(mappings.Length == 2
            && mappings[1].Id == "first"
            && mappings[2].Id == "second"
            && mappings[1].Mode == "managed"
            && mappings[1].Schema == 2,
        "仓储没有按源码顺序读取 managed RuleSpec")
    AssertTrue(mappings[1].StartLine > 0
            && repository.GetAppendStartLine() > mappings[2].StartLine,
        "仓储没有记录真实源码行号")

    AssertTrue(repository.Move("second", -1)
            && repository.Load()[1].Id == "second",
        "managed 规则顺序没有写回")
    invalidMoveRejected := false
    try repository.MoveTo("second", 1.5)
    catch
        invalidMoveRejected := true
    AssertTrue(invalidMoveRejected, "仓储接受了小数目标位置")

    editedSpec := RuleSpec.Clone(repository.GetById("second").Spec)
    editedSpec["display"]["purpose"] := "编辑后的用途"
    editedSpec["description"] := "编辑后的用途"
    repository.ReplaceManagedSpec("second", editedSpec)
    AssertEqual("编辑后的用途", repository.GetById("second").Purpose,
        "RuleSpec 编辑没有写回")

    paused := repository.ToggleEnabled("second")
    AssertTrue(!paused.Enabled && !paused.Spec["enabled"].Value
            && !RegExMatch(paused.Block, "m)^\s*[^;\s]"),
        "暂停状态没有只通过 RuleSpec 数据表达")
    resumed := repository.ToggleEnabled("second")
    AssertTrue(resumed.Enabled && resumed.Spec["enabled"].Value,
        "恢复状态没有同步 RuleSpec")

    thirdSpec := BuildRepositorySpec("third", "F15", "F16", "第三条")
    third := repository.AppendManagedSpec(thirdSpec)
    AssertTrue(third.Mode == "managed" && repository.Load().Length == 3,
        "新增 managed RuleSpec 没有写回")
    blankBlock := repository.CreateBlankBlock()
    blankMappings := repository.ParseMappings(blankBlock)
    AssertTrue(blankMappings.Length == 1
            && blankMappings[1].Mode == "managed"
            && InStr(blankBlock, "; @schema=2")
            && InStr(blankBlock, "; @mode=managed"),
        "代码编辑器模板不是有效 managed RuleSpec")
    editorAdded := repository.AppendBlock(blankBlock)
    AssertTrue(editorAdded.Mode == "managed"
            && repository.Load().Length == 4,
        "代码编辑器 managed 模块没有追加")

    duplicateRejected := false
    try repository.AppendManagedSpec(firstSpec)
    catch
        duplicateRejected := true
    AssertTrue(duplicateRejected, "重复规则编号被静默接受")

    rawBlock := "; @mapping-begin`r`n; @schema=1`r`n; @mode=raw"
        . "`r`n; @id=raw-forbidden`r`n; @mapping-end"
    rawRejected := false
    try repository.ParseMappings(rawBlock)
    catch as rawError
        rawRejected := InStr(rawError.Message, "@mode=managed") > 0
    AssertTrue(rawRejected, "仓储仍接受 raw AHK 规则")

    executableRegion := repository.ReadRegionBody()
        . "`r`nF20::Send `"{F21}`"`r`n"
    executableRejected := false
    try repository.WriteRegionBody(executableRegion)
    catch as executableError
        executableRejected := InStr(executableError.Message,
            "不允许可执行 AHK") > 0
    AssertTrue(executableRejected,
        "映射区域仍允许注册可执行 AHK 热键")

    beforeRegion := repository.ReadRegionBody()
    repository.Remove("first")
    AssertTrue(repository.Load().Length == 3
            && InStr(FileRead(scriptPath, "UTF-8"),
                "outside-region-sentinel"),
        "删除规则覆盖了映射区域外源码")
    repository.WriteRegionBody(beforeRegion)
    AssertTrue(repository.GetById("first").Mode == "managed",
        "映射区域快照没有完整恢复")

    concurrentRepository := ConcurrentManagedRepository(scriptPath)
    concurrentMappings := concurrentRepository.Load()
    concurrentRejected := false
    try concurrentRepository.MoveTo(concurrentMappings[1].Id,
        concurrentMappings.Length)
    catch
        concurrentRejected := true
    AssertTrue(concurrentRejected
            && InStr(FileRead(scriptPath, "UTF-8"),
                "; concurrent external edit"),
        "仓储覆盖或丢失了并发外部编辑")

    WriteTestSuccess("mapping-code-repository")
} finally {
    if DirExist(testRoot)
        DirDelete(testRoot, true)
}
ExitApp(0)

BuildRepositorySpec(id, source, target, purpose) {
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

BuildRepositoryScript(specs) {
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

class ConcurrentManagedRepository extends MappingCodeRepository {
    __New(scriptPath) {
        super.__New(scriptPath)
        this.Injected := false
    }

    BeforeReplace(expectedText, updatedText) {
        if this.Injected
            return
        this.Injected := true
        FileAppend("`r`n; concurrent external edit`r`n", this.ScriptPath,
            "UTF-8-RAW")
    }
}
