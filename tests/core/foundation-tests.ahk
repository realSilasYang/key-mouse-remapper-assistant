#Requires AutoHotkey v2.0 64-bit
#SingleInstance Off
#Warn All, StdOut

#Include ..\..\src\Core\BoundedFileReader.ahk
#Include ..\..\src\Core\JsonCodec.ahk
#Include ..\..\src\Core\Sha256.ahk
#Include ..\..\src\Core\CrossProcessWriteLock.ahk
#Include ..\..\src\Core\RuleSpec.ahk
#Include ..\..\src\Core\ScriptRuleSpec.ahk
#Include ..\..\src\Core\RuleCompiler.ahk
#Include ..\..\src\Core\ScriptRuleCompiler.ahk
#Include ..\..\src\Core\MappingCodeRepository.ahk
#Include ..\..\src\Core\RuleConditionEvaluator.ahk
#Include ..\..\src\Core\DeviceIdentityService.ahk
#Include ..\..\src\Core\InputEvent.ahk
#Include ..\..\src\Core\EventTraceService.ahk
#Include ..\..\src\Core\RulePackageService.ahk
#Include ..\..\src\Platform\Win32.ahk
#Include ..\..\src\Input\RawInputService.ahk

try {
    FoundationAssertEqual(
        "BA7816BF8F01CFEA414140DE5DAE2223B00361A396177A9CB410FF61F20015AD",
        Sha256.HexText("abc"), "SHA-256 text hashing is incorrect.")
    FoundationAssertEqual(
        "E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855",
        Sha256.HexText(""), "SHA-256 empty-input hashing is incorrect.")
    parsed := JsonCodec.Parse('{"text":"\u4F60\u597D","number":3}')
    FoundationAssertEqual("你好", parsed["text"],
        "JSON Unicode escapes were decoded incorrectly.")
    parsedSurrogate := JsonCodec.Parse('{"text":"\uD83D\uDE00"}')
    FoundationAssertEqual(Chr(0x1F600), parsedSurrogate["text"],
        "JSON Unicode surrogate pairs were decoded incorrectly.")
    parsedLiteralEscape := JsonCodec.Parse('{"text":"\\u0041"}')
    FoundationAssertEqual("\u0041", parsedLiteralEscape["text"],
        "An escaped backslash was misread as a Unicode escape.")
    FoundationAssertThrows(() => JsonCodec.Parse(
        '{"text":"\uD83D"}'),
        "An unpaired JSON high surrogate was accepted.")
    FoundationAssertThrows(() => JsonCodec.Parse('{"id":1,"id":2}'),
        "Duplicate JSON object keys must be rejected.")

    hotkeyDeclarations := ScriptRuleSpec.FindHotkeyDeclarations(
        "#HotIf WinActive(" Chr(34) "editor" Chr(34) ")`n"
        . "~*LShift::return`n"
        . "~*LShift Up::return`n#HotIf`n#d::return")
    FoundationAssertEqual(3, hotkeyDeclarations.Length,
        "Script hotkey declarations were not fully discovered.")
    FoundationAssertEqual("down", hotkeyDeclarations[1].Event,
        "A script down hotkey was classified incorrectly.")
    FoundationAssertEqual("up", hotkeyDeclarations[2].Event,
        "A script up hotkey was classified incorrectly.")
    FoundationAssertEqual("", hotkeyDeclarations[3].Context,
        "A bare #HotIf did not restore the global context.")

    scriptCode := "#Requires AutoHotkey v2.0`n#NoTrayIcon`nF24::F23"
    scriptSpec := ScriptRuleSpec.Normalize(Map(
        "id", "脚本元数据显示",
        "display", Map("source", "旧触发键", "target", "旧目标键",
            "scope", "指定窗口"),
        "code", scriptCode))
    scriptBlock := ScriptRuleCompiler.BuildBlock(scriptSpec,
        "`r`n")
    expectedMetadata := "; @mapping-begin`r`n"
        . "; 给这条规则起一个容易辨认的名称；它会显示在主界面中。`r`n"
        . "; @名称=脚本元数据显示`r`n"
        . "; 选择规则的写法；请保留下方已有的类型名称。`r`n"
        . "; @类型=受托管独立脚本`r`n"
        . "; 写清楚按下什么键或鼠标按键会触发这条规则。`r`n"
        . "; @来源按键=旧触发键`r`n"
        . "; 写清楚触发后会执行什么按键、鼠标操作或命令。`r`n"
        . "; @映射结果=旧目标键`r`n"
        . "; 写清楚规则在哪里有效，例如“全局”或某个程序。`r`n"
        . "; @生效范围=指定窗口`r`n"
    FoundationAssertTrue(InStr(scriptBlock, expectedMetadata) == 1,
        "Script metadata was not emitted in canonical order.")
    FoundationAssertTrue(!InStr(scriptBlock, "@script-spec-"),
        "Script persistence still exposed a script-spec module.")
    FoundationAssertTrue(!InStr(scriptBlock, "@generated-sha256"),
        "Script persistence still emitted a generated SHA-256 digest.")
    FoundationAssertTrue(InStr(scriptBlock,
            "; @script-code-begin`r`n;  #Requires AutoHotkey v2.0`r`n"
            . ";  #NoTrayIcon`r`n;  F24::F23`r`n; @script-code-end"),
        "Script source was not persisted as readable comment-prefixed lines.")
    scriptRepository := MappingCodeRepository(
        A_Temp "\unused-script-metadata-foundation.ahk")
    parsedScript := scriptRepository.ParseMappings(scriptBlock)[1]
    FoundationAssertTrue(InStr(parsedScript.EditorText,
            expectedMetadata) == 1 && !InStr(parsedScript.EditorText,
                "@script-spec-"),
        "The complete script persistence block was not exposed in the editor.")
    FoundationAssertEqual(scriptCode,
        ScriptRuleCompiler.ParseSpec(parsedScript.EditorText)["code"],
        "Opening the complete script block changed the executable source.")
    editedScriptText := StrReplace(parsedScript.EditorText,
        "; @名称=脚本元数据显示", "; @名称=脚本元数据新名称")
    editedScriptText := StrReplace(editedScriptText,
        "; @来源按键=旧触发键", "; @来源按键=新触发键")
    editedScriptText := StrReplace(editedScriptText,
        "; @映射结果=旧目标键", "; @映射结果=新目标键")
    editedScriptText := StrReplace(editedScriptText,
        "; @生效范围=指定窗口", "; @生效范围=全局")
    editedScriptSpec := scriptRepository.ParseMappings(
        editedScriptText)[1].Spec
    FoundationAssertTrue(editedScriptSpec["id"] == "脚本元数据新名称"
            && editedScriptSpec["display"]["source"] == "新触发键"
            && editedScriptSpec["display"]["target"] == "新目标键"
            && editedScriptSpec["display"].Get("scope", "全局") == "全局",
        "Editing script metadata did not update all list display columns.")
    roundTripScriptText := ScriptRuleCompiler.BuildBlock(editedScriptSpec)
    for expectedScriptMetadataName in ["名称", "类型", "来源按键", "映射结果",
            "生效范围"] {
        FoundationAssertEqual(1, FoundationCountSubstring(roundTripScriptText,
            "; @" expectedScriptMetadataName "="),
            "The complete script block duplicated reserved metadata.")
    }
    FoundationAssertEqual(scriptCode,
        ScriptRuleCompiler.ParseSpec(roundTripScriptText)["code"],
        "Script metadata round-trip changed the executable source.")
    disabledScriptSpec := RuleSpec.Clone(scriptSpec)
    disabledScriptSpec["enabled"] := JsonBoolean(false)
    disabledScriptBlock := ScriptRuleCompiler.BuildBlock(disabledScriptSpec,
        "`n")
    FoundationAssertTrue(InStr(disabledScriptBlock,
            "; @生效范围=指定窗口`n"
                . "; 只有暂停规则时才需要这一项；false 表示暂停，删除此项即可重新启用。`n"
                . "; @enabled=false`n`n"
                . "; 下面是一份完整的 AHK v2 脚本；小助手会单独启动和停止它。`n"
                . "; @script-code-begin"),
        "A paused script did not persist its enabled state after metadata.")
    FoundationAssertTrue(!ScriptRuleCompiler.ParseSpec(
            disabledScriptBlock)["enabled"].Value,
        "A paused script was restored as enabled.")
    inferredScriptSpec := ScriptRuleSpec.FromCode(
        "inline-metadata-is-inert",
        "; @来源按键=不应生效`nF24::F23")
    FoundationAssertEqual("F24", inferredScriptSpec["display"]["source"],
        "An AHK source comment overrode the authoritative outer metadata.")

    baseSpec := Map("id", "foundation-rule",
        "display", Map("source", "F24", "target", "F23"),
        "from", Map("key", Map("name", "F24")),
        "to", [Map("type", "send", "value", "{F23}")])
    managedBlock := RuleCompiler.BuildManagedBlock(baseSpec, "`n")
    scalarModifierSpec := RuleSpec.Clone(baseSpec)
    scalarModifierSpec["from"]["modifiers"] := "Ctrl"
    scalarModifierBlock := FoundationReplaceManagedSpecBody(managedBlock,
        scalarModifierSpec)
    FoundationAssertEqual("Ctrl",
        RuleCompiler.ParseManagedSpecValue(
            scalarModifierBlock)["from"]["modifiers"],
        "The raw managed parser changed an invalid AI field before validation.")
    FoundationAssertThrows(() => RuleCompiler.ParseManagedSpec(
        scalarModifierBlock),
        "Persisted managed rules must still reject scalar modifiers.")
    embeddedMetadataBlock := FoundationReplaceManagedSpecBody(managedBlock,
        baseSpec, true)
    compatibleEmbeddedSpec := RuleCompiler.ParseManagedSpecValue(
        embeddedMetadataBlock)
    FoundationAssertTrue(compatibleEmbeddedSpec["id"] == "foundation-rule"
            && compatibleEmbeddedSpec["display"]["source"] == "F24",
        "Outer metadata did not override redundant embedded metadata.")
    conflictingEmbeddedSpec := RuleSpec.Clone(baseSpec)
    conflictingEmbeddedSpec["id"] := "different-name"
    conflictingEmbeddedBlock := FoundationReplaceManagedSpecBody(managedBlock,
        conflictingEmbeddedSpec, true)
    reconciledEmbeddedSpec := RuleCompiler.ParseManagedSpecValue(
        conflictingEmbeddedBlock)
    FoundationAssertEqual("foundation-rule", reconciledEmbeddedSpec["id"],
        "Redundant embedded metadata overrode the authoritative outer name.")
    FoundationAssertThrows(() => RuleCompiler.ParseManagedSpecValue(
        conflictingEmbeddedBlock, true),
        "Strict AI parsing accepted conflicting embedded metadata.")
    metadataCommentPairs := [
        ["名称", "给这条规则起一个容易辨认的名称；它会显示在主界面中。"],
        ["类型", "选择规则的写法；请保留下方已有的类型名称。"],
        ["来源按键", "写清楚按下什么键或鼠标按键会触发这条规则。"],
        ["映射结果", "写清楚触发后会执行什么按键、鼠标操作或命令。"],
        ["生效范围", "写清楚规则在哪里有效，例如“全局”或某个程序。"]]
    for commentPair in metadataCommentPairs
        FoundationAssertTrue(InStr(managedBlock, "; " commentPair[2]
                . "`n; @" commentPair[1] "="),
            "Managed metadata field lacks its preceding explanation: @"
                . commentPair[1])
    FoundationAssertTrue(!InStr(managedBlock, "@generated-sha256"),
        "Managed persistence still emitted a generated SHA-256 digest.")
    FoundationAssertTrue(InStr(managedBlock,
        "; @mapping-begin`n"
            . "; 给这条规则起一个容易辨认的名称；它会显示在主界面中。`n"
            . "; @名称=foundation-rule`n"
            . "; 选择规则的写法；请保留下方已有的类型名称。`n"
            . "; @类型=规则块`n") == 1
        && InStr(managedBlock,
        "; @来源按键=F24") && InStr(managedBlock,
        "; @映射结果=F23") && InStr(managedBlock,
        "; @生效范围=全局") && InStr(managedBlock,
        "; 下面是规则的详细设置，包括触发方式、生效条件、时间判定和执行动作。`n"
            . "; @spec-begin"),
        "Managed blocks did not expose Chinese display metadata.")

    blankManagedBlock := RuleCompiler.BuildBlankManagedBlock("`n")
    FoundationAssertTrue(InStr(blankManagedBlock,
            "; @名称=<请填写规则名称>")
            && InStr(blankManagedBlock,
                "; @来源按键=<请填写来源按键>")
            && InStr(blankManagedBlock,
                "; <请在这里填写 RuleSpec JSON>")
            && !InStr(blankManagedBlock, "F24")
            && !InStr(blankManagedBlock, "F23"),
        "The blank managed editor still contains a concrete example rule.")
    FoundationAssertThrows(() => RuleCompiler.ParseManagedSpec(
        blankManagedBlock),
        "The managed placeholder template was accepted as a real rule.")
    blankScriptBlock := ScriptRuleCompiler.BuildBlankScriptBlock("`n")
    FoundationAssertTrue(InStr(blankScriptBlock,
            ";  <请在这里编写完整的 AHK v2 脚本>")
            && !InStr(blankScriptBlock, "#Requires")
            && !InStr(blankScriptBlock, "F24")
            && !InStr(blankScriptBlock, "F23"),
        "The blank script editor still contains concrete AHK code.")
    FoundationAssertThrows(() => ScriptRuleCompiler.ParseSpec(
        blankScriptBlock),
        "The script placeholder template was accepted as a real rule.")
    FoundationAssertTrue(RegExMatch(managedBlock,
            "ms)^; @spec-begin\R(.*?)^; @spec-end", &managedSpecMatch),
        "The managed RuleSpec JSON section could not be found.")
    previousSpecLine := ""
    annotatedSpecFieldCount := 0
    Loop Parse managedSpecMatch[1], "`n", "`r" {
        specLine := A_LoopField
        if RegExMatch(specLine, '^; (\s*)"([a-z_]+)"\s*:',
                &annotatedField) {
            annotatedSpecFieldCount++
            FoundationAssertTrue(InStr(previousSpecLine,
                    "; " annotatedField[1] "// ") == 1,
                "RuleSpec JSON field lacks its preceding explanation: "
                    . annotatedField[2])
        }
        previousSpecLine := specLine
    }
    FoundationAssertTrue(annotatedSpecFieldCount > 0,
        "The managed RuleSpec JSON did not expose annotated fields.")
    FoundationAssertTrue(!InStr(managedSpecMatch[1], '"id"')
            && !InStr(managedSpecMatch[1], '"display"'),
        "Managed RuleSpec JSON still exposed id or display.")
    managedRepository := MappingCodeRepository(
        A_Temp "\\managed-display-foundation.ahk")
    managedMapping := managedRepository.ParseMappings(managedBlock)[1]
    FoundationAssertEqual("F24", managedMapping.Source,
        "Managed source display metadata was not parsed.")
    editedManagedBlock := StrReplace(managedBlock,
        "; @名称=foundation-rule", "; @名称=新名称")
    editedManagedBlock := StrReplace(editedManagedBlock,
        "; @来源按键=F24", "; @来源按键=新来源")
    editedManagedBlock := StrReplace(editedManagedBlock,
        "; @映射结果=F23", "; @映射结果=新结果")
    editedManagedBlock := StrReplace(editedManagedBlock,
        "; @生效范围=全局", "; @生效范围=指定窗口")
    editedManagedMapping := managedRepository.ParseMappings(
        editedManagedBlock)[1]
    FoundationAssertTrue(editedManagedMapping.Id == "新名称"
            && editedManagedMapping.Source == "新来源"
            && editedManagedMapping.Target == "新结果"
            && editedManagedMapping.Scope == "指定窗口",
        "Editing authoritative managed metadata did not update the mapping.")
    incompleteManagedBlock := RegExReplace(managedBlock,
        "m)^; @(?:来源按键|映射结果|生效范围)=.*(?:\R|$)", "")
    FoundationAssertThrows(() => managedRepository.ParseMappings(
        incompleteManagedBlock),
        "Managed blocks without authoritative display metadata were accepted.")
    extraMetadataBlock := StrReplace(managedBlock, "; @类型=规则块",
        "; @类型=规则块`n; @schema=1`n; @id=old-id"
            . "`n; @mode=managed`n; @设计目的=保留说明")
    extraMetadataMapping := managedRepository.ParseMappings(
        extraMetadataBlock)[1]
    FoundationAssertEqual("foundation-rule", extraMetadataMapping.Id,
        "Harmless extra metadata changed or invalidated the rule.")

    localizedNames := [
        "简体中文规则名称", "繁體中文香港規則名稱", "繁體中文台灣規則名稱",
        "English rule name", "日本語のルール名", "Tên quy tắc tiếng Việt",
        "한국어 규칙 이름", "Nombre de regla en español",
        "Nom de règle française", "Nome da regra em português",
        "Имя правила на русском", "Deutscher Regelname",
        "Nome della regola italiana"]
    FoundationAssertEqual(13, localizedNames.Length,
        "The localized name matrix must cover all 13 UI languages.")
    for localizedName in localizedNames {
        FoundationAssertEqual(localizedName,
            RuleSpec.NormalizeId(localizedName),
            "A supported UI language name was changed or rejected: "
                . localizedName)
    }
    decomposedName := "Cafe" Chr(0x0301)
    FoundationAssertEqual("Café", RuleSpec.NormalizeId(decomposedName),
        "Rule names were not normalized to Unicode NFC.")
    percentNameSpec := RuleSpec.Clone(baseSpec)
    percentNameSpec["id"] := "百分之百%规则"
    percentNameBlock := RuleCompiler.BuildManagedBlock(percentNameSpec)
    FoundationAssertTrue(InStr(percentNameBlock, "; @名称=百分之百%25规则"),
        "A percent sign in a rule name was not metadata-encoded.")
    FoundationAssertEqual("百分之百%规则",
        managedRepository.ParseMappings(percentNameBlock)[1].Id,
        "A percent sign in a rule name did not round-trip.")
    windowsFilePunctuationName := "窗口<>:" Chr(34) "/\|?*规则."
    FoundationAssertEqual(windowsFilePunctuationName,
        RuleSpec.NormalizeId(windowsFilePunctuationName),
        "Rule names still reject punctuation reserved only for file names.")
    punctuationNameSpec := RuleSpec.Clone(baseSpec)
    punctuationNameSpec["id"] := windowsFilePunctuationName
    punctuationNameBlock := RuleCompiler.BuildManagedBlock(
        punctuationNameSpec)
    FoundationAssertEqual(windowsFilePunctuationName,
        managedRepository.ParseMappings(punctuationNameBlock)[1].Id,
        "File-name punctuation in a rule name did not round-trip.")
    paddedName := "`t" Chr(0x00A0) " 规则名称 " Chr(0x00A0)
    FoundationAssertEqual("规则名称", RuleSpec.NormalizeId(paddedName),
        "Harmless surrounding whitespace in a rule name was not trimmed.")
    paddedNameSpec := RuleSpec.Clone(baseSpec)
    paddedNameSpec["id"] := paddedName
    paddedNameBlock := RuleCompiler.BuildManagedBlock(paddedNameSpec)
    FoundationAssertTrue(InStr(paddedNameBlock, "; @名称=规则名称")
            && managedRepository.ParseMappings(paddedNameBlock)[1].Id
                == "规则名称",
        "A padded rule name did not persist in canonical form.")
    for invalidName in ["非法" Chr(1) "名称", "换行`n名称",
            Chr(0x2028) "行分隔符", " `t" Chr(0x00A0)] {
        FoundationAssertThrows(() => RuleSpec.NormalizeId(invalidName),
            "An unsafe rule name was accepted.")
    }
    unknownFieldSpec := RuleSpec.Clone(baseSpec)
    unknownFieldSpec["conditionz"] := []
    FoundationAssertThrows(() => RuleSpec.Normalize(unknownFieldSpec),
        "Unknown RuleSpec fields must not silently broaden a rule.")
    unknownActionSpec := RuleSpec.Clone(baseSpec)
    unknownActionSpec["to"][1]["repeet"] := "once"
    FoundationAssertThrows(() => RuleSpec.Normalize(unknownActionSpec),
        "Unknown action fields must not be discarded silently.")
    ignoredValueActionSpec := RuleSpec.Clone(baseSpec)
    ignoredValueActionSpec["to"] := [Map("type", "window_close",
        "value", "ignored")]
    FoundationAssertThrows(() => RuleSpec.Normalize(ignoredValueActionSpec),
        "Valueless actions must reject a silently ignored value.")
    appCommandSpec := RuleSpec.Clone(baseSpec)
    appCommandSpec["to"] := [Map("type", "app_command",
        "value", "VolumeUp")]
    FoundationAssertEqual("Volume_Up",
        RuleSpec.Normalize(appCommandSpec)["to"][1]["value"],
        "App-command aliases were not normalized to an executable AHK name.")
    unknownAppCommandSpec := RuleSpec.Clone(baseSpec)
    unknownAppCommandSpec["to"] := [Map("type", "app_command",
        "value", "Open_Settings")]
    FoundationAssertThrows(() => RuleSpec.Normalize(unknownAppCommandSpec),
        "Unknown app commands were accepted and deferred to runtime.")
    invalidGroupConditionSpec := RuleSpec.Clone(baseSpec)
    invalidGroupConditionSpec["conditions"] := [Map("type", "all",
        "operator", "equals", "conditions", [Map("type", "session",
            "field", "state", "value", "active")])]
    FoundationAssertThrows(() => RuleSpec.Normalize(
        invalidGroupConditionSpec),
        "Logical conditions must reject predicate-only fields.")
    invalidExistsConditionSpec := RuleSpec.Clone(baseSpec)
    invalidExistsConditionSpec["conditions"] := [Map("type", "window",
        "field", "title", "operator", "exists", "value", "ignored")]
    FoundationAssertThrows(() => RuleSpec.Normalize(
        invalidExistsConditionSpec),
        "Existence conditions must reject an ignored comparison value.")
    unknownConditionFieldSpec := RuleSpec.Clone(baseSpec)
    unknownConditionFieldSpec["conditions"] := [Map("type", "application",
        "field", "proces", "operator", "not_exists")]
    FoundationAssertThrows(() => RuleSpec.Normalize(
        unknownConditionFieldSpec),
        "Unknown condition fields must not turn not_exists into a match.")
    conflictingModifiers := RuleSpec.Clone(baseSpec)
    conflictingModifiers["from"]["modifiers"] := ["Ctrl", "LCtrl"]
    FoundationAssertThrows(() => RuleSpec.Normalize(conflictingModifiers),
        "Generic and sided modifiers from one family must be rejected.")
    describedSpec := RuleSpec.Clone(baseSpec)
    describedSpec["description"] := "Preserve this rule description."
    normalizedDescription := RuleSpec.Normalize(describedSpec)
    FoundationAssertEqual("Preserve this rule description.",
        normalizedDescription["description"],
        "RuleSpec silently discarded its description.")
    legacyProfileSpec := RuleSpec.Clone(baseSpec)
    legacyProfileSpec["profile"] := "legacy"
    FoundationAssertThrows(() => RuleSpec.Normalize(legacyProfileSpec),
        "RuleSpec.Normalize silently discarded a legacy profile field.")
    unknownSourceKey := RuleSpec.Clone(baseSpec)
    unknownSourceKey["from"]["key"]["name"] := "DefinitelyNotAKey"
    FoundationAssertThrows(() => RuleSpec.Normalize(unknownSourceKey),
        "An unknown source key reached runtime hotkey registration.")
    webAliasSourceKey := RuleSpec.Clone(baseSpec)
    webAliasSourceKey["from"]["key"]["name"] := "ArrowUp"
    FoundationAssertThrows(() => RuleSpec.Normalize(webAliasSourceKey),
        "Strict persisted RuleSpec parsing accepted an AI-only key alias.")
    unknownOutputKey := RuleSpec.Clone(baseSpec)
    unknownOutputKey["to"] := [Map("type", "key_down",
        "value", "DefinitelyNotAKey")]
    FoundationAssertThrows(() => RuleSpec.Normalize(unknownOutputKey),
        "An unknown output key reached runtime Send().")

    evaluator := RuleConditionEvaluator()
    FoundationAssertTrue(!evaluator.Compare("0409", true,
        Map("operator", "equals", "value", 409)),
        "Numeric-looking strings must retain string comparison semantics.")
    FoundationAssertTrue(evaluator.Compare(409, true,
        Map("operator", "equals", "value", 409.0)),
        "Integer and floating-point condition values should compare numerically.")
    structuredActual := Map("process", "WINWORD.EXE",
        "identity", Map("publisher", "Microsoft"))
    structuredExpected := Map("identity", Map("publisher", "microsoft"),
        "process", "winword.exe")
    FoundationAssertTrue(evaluator.Compare(structuredActual, true,
        Map("operator", "equals", "value", structuredExpected)),
        "Structured conditions ignored default case-insensitive comparison.")
    FoundationAssertTrue(!evaluator.Compare(structuredActual, true,
        Map("operator", "equals", "value", structuredExpected,
            "case_sensitive", JsonBoolean(true))),
        "Structured conditions ignored explicit case-sensitive comparison.")

    fakeKeyboardPacket := Buffer(RawInputDecoder.HeaderSize + 16, 0)
    NumPut("UInt", RawInputDecoder.KeyboardType, fakeKeyboardPacket, 0)
    NumPut("UInt", fakeKeyboardPacket.Size, fakeKeyboardPacket, 4)
    NumPut("UShort", 0xFF, fakeKeyboardPacket,
        RawInputDecoder.HeaderSize + 6)
    FoundationAssertEqual(0,
        RawInputDecoder.Decode(fakeKeyboardPacket).Length,
        "Raw Input fake-key packets with VKey 255 must be ignored.")

    validKeyboardPacket := Buffer(RawInputDecoder.HeaderSize + 16, 0)
    NumPut("UInt", RawInputDecoder.KeyboardType, validKeyboardPacket, 0)
    NumPut("UInt", validKeyboardPacket.Size, validKeyboardPacket, 4)
    NumPut("UShort", 0x1E, validKeyboardPacket,
        RawInputDecoder.HeaderSize)
    NumPut("UShort", 0x41, validKeyboardPacket,
        RawInputDecoder.HeaderSize + 6)
    keyboardEvents := RawInputDecoder.Decode(validKeyboardPacket)
    FoundationAssertEqual(1, keyboardEvents.Length,
        "A valid Raw Input keyboard packet was not decoded.")
    FoundationAssertEqual("down", keyboardEvents[1]["phase"],
        "A valid Raw Input make packet has the wrong phase.")
    rightControlPacket := Buffer(RawInputDecoder.HeaderSize + 16, 0)
    NumPut("UInt", RawInputDecoder.KeyboardType, rightControlPacket, 0)
    NumPut("UInt", rightControlPacket.Size, rightControlPacket, 4)
    NumPut("UShort", 0x1D, rightControlPacket,
        RawInputDecoder.HeaderSize)
    NumPut("UShort", 0x0002, rightControlPacket,
        RawInputDecoder.HeaderSize + 2)
    NumPut("UShort", 0x11, rightControlPacket,
        RawInputDecoder.HeaderSize + 6)
    rightControlEvents := RawInputDecoder.Decode(rightControlPacket)
    FoundationAssertEqual("RControl",
        rightControlEvents[1]["identity"]["name"],
        "Raw Input did not resolve the right Control key.")
    FoundationAssertEqual(0xA3,
        rightControlEvents[1]["identity"]["vk"],
        "Raw Input retained the generic Control virtual key.")
    rightShiftPacket := Buffer(RawInputDecoder.HeaderSize + 16, 0)
    NumPut("UInt", RawInputDecoder.KeyboardType, rightShiftPacket, 0)
    NumPut("UInt", rightShiftPacket.Size, rightShiftPacket, 4)
    NumPut("UShort", 0x36, rightShiftPacket,
        RawInputDecoder.HeaderSize)
    NumPut("UShort", 0x10, rightShiftPacket,
        RawInputDecoder.HeaderSize + 6)
    rightShiftEvents := RawInputDecoder.Decode(rightShiftPacket)
    FoundationAssertEqual("RShift",
        rightShiftEvents[1]["identity"]["name"],
        "Raw Input did not resolve the right Shift key.")
    FoundationAssertEqual(0xA1,
        rightShiftEvents[1]["identity"]["vk"],
        "Raw Input retained the generic Shift virtual key.")
    pausePacket := Buffer(RawInputDecoder.HeaderSize + 16, 0)
    NumPut("UInt", RawInputDecoder.KeyboardType, pausePacket, 0)
    NumPut("UInt", pausePacket.Size, pausePacket, 4)
    NumPut("UShort", 0x45, pausePacket, RawInputDecoder.HeaderSize)
    NumPut("UShort", 0x0004, pausePacket,
        RawInputDecoder.HeaderSize + 2)
    NumPut("UShort", 0x13, pausePacket,
        RawInputDecoder.HeaderSize + 6)
    pauseEvents := RawInputDecoder.Decode(pausePacket)
    FoundationAssertEqual("Pause", pauseEvents[1]["identity"]["name"],
        "Raw Input confused Pause with NumLock.")
    FoundationAssertEqual(0x045, pauseEvents[1]["identity"]["sc"],
        "The E1 Pause prefix was encoded as an E0 scan code.")
    numLockPacket := Buffer(RawInputDecoder.HeaderSize + 16, 0)
    NumPut("UInt", RawInputDecoder.KeyboardType, numLockPacket, 0)
    NumPut("UInt", numLockPacket.Size, numLockPacket, 4)
    NumPut("UShort", 0x45, numLockPacket, RawInputDecoder.HeaderSize)
    NumPut("UShort", 0x0002, numLockPacket,
        RawInputDecoder.HeaderSize + 2)
    NumPut("UShort", 0x90, numLockPacket,
        RawInputDecoder.HeaderSize + 6)
    numLockEvents := RawInputDecoder.Decode(numLockPacket)
    FoundationAssertEqual("Numlock",
        numLockEvents[1]["identity"]["name"],
        "Raw Input confused NumLock with Pause.")
    FoundationAssertEqual(0x145, numLockEvents[1]["identity"]["sc"],
        "The E0 NumLock prefix was not preserved.")
    oversizedKeyboardPacket := Buffer(validKeyboardPacket.Size + 1, 0)
    NumPut("UInt", RawInputDecoder.KeyboardType, oversizedKeyboardPacket, 0)
    NumPut("UInt", validKeyboardPacket.Size, oversizedKeyboardPacket, 4)
    FoundationAssertThrows(() => RawInputDecoder.Decode(
        oversizedKeyboardPacket),
        "Raw Input packets with a mismatched header length must be rejected.")

    zeroWheelPacket := Buffer(RawInputDecoder.HeaderSize + 24, 0)
    NumPut("UInt", RawInputDecoder.MouseType, zeroWheelPacket, 0)
    NumPut("UInt", zeroWheelPacket.Size, zeroWheelPacket, 4)
    NumPut("UShort", 0x0400, zeroWheelPacket,
        RawInputDecoder.HeaderSize + 4)
    FoundationAssertEqual(0, RawInputDecoder.Decode(zeroWheelPacket).Length,
        "A zero wheel delta must not be reported as WheelDown.")

    consumerDefinitions := Map(
        0x0224, ["Browser_Back", 1],
        0x0225, ["Browser_Forward", 2],
        0x0227, ["Browser_Refresh", 3],
        0x0226, ["Browser_Stop", 4],
        0x0221, ["Browser_Search", 5],
        0x022A, ["Browser_Favorites", 6],
        0x0223, ["Browser_Home", 7],
        0x00E2, ["Volume_Mute", 8],
        0x00EA, ["Volume_Down", 9],
        0x00E9, ["Volume_Up", 10],
        0x00B5, ["Media_Next", 11],
        0x00B6, ["Media_Prev", 12],
        0x00B7, ["Media_Stop", 13],
        0x00CD, ["Media_Play_Pause", 14],
        0x018A, ["Launch_Mail", 15],
        0x0183, ["Launch_Media", 16],
        0x0194, ["Launch_App1", 17],
        0x0192, ["Launch_App2", 18])
    for consumerUsageId, consumerExpectedDefinition in consumerDefinitions {
        consumerResolvedDefinition := ConsumerControlUsage.Resolve(
            consumerUsageId)
        FoundationAssertTrue(IsObject(consumerResolvedDefinition)
                && consumerResolvedDefinition.Name
                    == consumerExpectedDefinition[1]
                && consumerResolvedDefinition.AppCommand
                    == consumerExpectedDefinition[2]
                && consumerResolvedDefinition.VK > 0,
            "A standard Consumer Control key is not recordable: "
                consumerExpectedDefinition[1])
    }
    consumerDevice := Map("id", "consumer-a", "handle", "consumer-a",
        "usage_page", 0x0C, "usage", 1)
    consumerDecoder := RawHidConsumerDecoder()
    consumerEvents := consumerDecoder.UpdateHeldUsages("consumer-a",
        [0x0221], consumerDevice)
    FoundationAssertTrue(consumerEvents.Length == 1
            && consumerEvents[1]["phase"] == "down"
            && consumerEvents[1]["identity"]["name"] == "Browser_Search"
            && consumerEvents[1]["identity"]["app_command"] == 5,
        "HID AC Search was not decoded as Browser_Search.")
    FoundationAssertEqual(0, consumerDecoder.UpdateHeldUsages("consumer-a",
        [0x0221], consumerDevice).Length,
        "An unchanged Consumer Control report repeated its held key.")
    consumerEvents := consumerDecoder.UpdateHeldUsages("consumer-a",
        [0x0223], consumerDevice)
    FoundationAssertTrue(consumerEvents.Length == 2
            && consumerEvents[1]["phase"] == "down"
            && consumerEvents[1]["identity"]["name"] == "Browser_Home"
            && consumerEvents[2]["phase"] == "up"
            && consumerEvents[2]["identity"]["name"] == "Browser_Search",
        "HID Consumer Control state did not transition between browser keys.")
    consumerEvents := consumerDecoder.UpdateHeldUsages("consumer-a", [],
        consumerDevice)
    FoundationAssertTrue(consumerEvents.Length == 1
            && consumerEvents[1]["phase"] == "up"
            && consumerEvents[1]["identity"]["name"] == "Browser_Home",
        "HID AC Home release was not decoded.")

    browserSearchIdentity := KeyIdentity.FromRawKeyboard(0xAA, 0x65, 0)
    browserHomeIdentity := KeyIdentity.FromRawKeyboard(0xAC, 0x32, 0)
    FoundationAssertTrue(browserSearchIdentity["name"] == "Browser_Search"
            && browserHomeIdentity["name"] == "Browser_Home",
        "Dedicated browser virtual keys were shadowed by legacy scan codes.")

    rawInputProbe := RawInputService(
        DllCall("user32\GetDesktopWindow", "Ptr"), (*) => false)
    rawInputProbe.Started := true
    rawInputCallbackResult := rawInputProbe.OnRawInput(0, 0)
    rawInputProbe.Started := false
    FoundationAssertTrue(Type(rawInputCallbackResult) == "String"
            && rawInputCallbackResult == "",
        "The WM_INPUT callback suppressed the required default cleanup path.")

    rawInputRegistrationGui := Gui("+ToolWindow")
    rawInputRegistrationService := RawInputService(
        rawInputRegistrationGui.Hwnd, (*) => false)
    try {
        FoundationAssertTrue(rawInputRegistrationService.Start()
                && rawInputRegistrationService.DevicesRegistered,
            "Keyboard, mouse and Consumer Control Raw Input registration failed.")
        FoundationAssertTrue(rawInputRegistrationService.Stop()
                && !rawInputRegistrationService.DevicesRegistered,
            "Raw Input registrations were not completely released.")
    } finally {
        try rawInputRegistrationService.Stop()
        rawInputRegistrationGui.Destroy()
    }

    identityService := DeviceIdentityService()
    firstIdentity := identityService.Build(Map("type", "keyboard",
        "path", "\\\\?\\HID#VID_1234&PID_5678#SERIAL01#{00000000-0000-0000-0000-000000000000}",
        "usage_page", 1, "usage", 6))
    secondIdentity := identityService.Build(Map("type", "keyboard",
        "path", "\\\\?\\hid#vid_1234&pid_5678#serial01#{11111111-1111-1111-1111-111111111111}",
        "usage_page", 1, "usage", 6))
    FoundationAssertEqual(firstIdentity["stable_id"],
        secondIdentity["stable_id"],
        "Device identity changed when only the interface class GUID changed.")

    trace := EventTraceService(2)
    trace.Record("runtime", "one")
    trace.Record("runtime", "two")
    trace.Record("runtime", "three")
    snapshot := trace.Snapshot()
    FoundationAssertEqual(2, snapshot.Length,
        "The event ring buffer exceeded its capacity.")
    FoundationAssertEqual(2, snapshot[1].Sequence,
        "The event ring buffer did not evict the oldest entry.")
    FoundationAssertEqual(1, trace.DroppedCount,
        "The event ring buffer drop count is incorrect.")
    trace.Subscribe(FoundationFailingSubscriber)
    trace.Record("runtime", "subscriber-failure")
    FoundationAssertEqual(0, trace.Subscribers.Count,
        "A failing event subscriber was not detached.")
    reentrantTrace := EventTraceService(4)
    firstSubscriberEvents := []
    secondSubscriberEvents := []
    reentrantTrace.Subscribe(FoundationReentrantSubscriber.Bind(
        reentrantTrace, firstSubscriberEvents))
    reentrantTrace.Subscribe(FoundationCollectTraceEvent.Bind(
        secondSubscriberEvents))
    reentrantTrace.Record("runtime", "outer")
    FoundationAssertEqual("outer,nested",
        FoundationJoin(firstSubscriberEvents),
        "A reentrant subscriber received events out of sequence.")
    FoundationAssertEqual("outer,nested",
        FoundationJoin(secondSubscriberEvents),
        "A later subscriber observed a nested event before its parent.")

    conditionalSpec := RuleSpec.Clone(baseSpec)
    conditionalSpec["conditions"] := [Map("type", "application",
        "field", "process", "value", "notepad.exe")]
    packageService := RulePackageService()
    packageDocument := packageService.Build([{
        Mode: "managed", Spec: RuleSpec.Normalize(conditionalSpec)}])
    capabilities := packageDocument["capabilities"]
    for index, capability in capabilities {
        if capability == "conditions" {
            capabilities.RemoveAt(index)
            break
        }
    }
    packagePayload := RuleSpec.Clone(packageDocument)
    packagePayload.Delete("integrity")
    packageDocument["integrity"]["digest"] := Sha256.HexText(
        JsonCodec.Stringify(packagePayload, false, true))
    FoundationAssertThrows(() => packageService.Parse(
        JsonCodec.Stringify(packageDocument, false, true)),
        "A rule package must declare every capability its rules require.")

    windowControlSpec := RuleSpec.Clone(baseSpec)
    windowControlSpec["id"] := "window-control-permission"
    windowControlSpec["to"] := [Map("type", "window_close")]
    windowPackage := packageService.Build([{
        Mode: "managed", Spec: RuleSpec.Normalize(windowControlSpec)}])
    FoundationAssertTrue(FoundationArrayContains(
        windowPackage["permissions"], "window_control"),
        "Window actions must declare window_control permission.")
    FoundationAssertTrue(!FoundationArrayContains(
        windowPackage["permissions"], "generated_input"),
        "Window-only actions must not claim generated_input permission.")
    systemControlSpec := RuleSpec.Clone(baseSpec)
    systemControlSpec["id"] := "system-control-permission"
    systemControlSpec["to"] := [Map("type", "lock_workstation")]
    systemPackage := packageService.Build([{
        Mode: "managed", Spec: RuleSpec.Normalize(systemControlSpec)}])
    FoundationAssertTrue(FoundationArrayContains(
        systemPackage["permissions"], "system_control"),
        "System actions must declare system_control permission.")

    scriptSpec := ScriptRuleSpec.FromCode("package-script-rule",
        "#Requires AutoHotkey v2.0`n#NoTrayIcon`nF24::F23")
    scriptPackage := packageService.Build([{
        Mode: "script", Spec: scriptSpec}])
    FoundationAssertTrue(FoundationArrayContains(
        scriptPackage["capabilities"], "script_rules"),
        "Script packages must declare script_rules capability.")
    FoundationAssertTrue(FoundationArrayContains(
        scriptPackage["permissions"], "arbitrary_code"),
        "Script packages must declare arbitrary_code permission.")
    parsedScriptPackage := packageService.Parse(
        JsonCodec.Stringify(scriptPackage, false, true))
    FoundationAssertEqual("script",
        parsedScriptPackage["rules"][1]["mode"],
        "Script package mode did not survive parsing.")
    FoundationAssertEqual(scriptSpec["code"],
        parsedScriptPackage["rules"][1]["spec"]["code"],
        "Script package source did not survive parsing.")
    scriptPackage["permissions"] := []
    scriptPayload := RuleSpec.Clone(scriptPackage)
    scriptPayload.Delete("integrity")
    scriptPackage["integrity"]["digest"] := Sha256.HexText(
        JsonCodec.Stringify(scriptPayload, false, true))
    FoundationAssertThrows(() => packageService.Parse(
        JsonCodec.Stringify(scriptPackage, false, true)),
        "A script package without arbitrary_code permission was accepted.")

    FileAppend("PASS foundation`n", "*")
} catch as testError {
    FileAppend(testError.Message "`n" testError.Stack "`n", "**")
    ExitApp(1)
}
ExitApp(0)

FoundationAssertTrue(value, message) {
    if !value
        throw Error(message)
}

FoundationAssertEqual(expected, actual, message) {
    if expected != actual
        throw Error(message " Expected '" expected "', got '" actual "'.")
}

FoundationAssertThrows(callback, message) {
    try callback.Call()
    catch
        return true
    throw Error(message)
}

FoundationArrayContains(values, expected) {
    for value in values
        if value == expected
            return true
    return false
}

FoundationFailingSubscriber(*) {
    throw Error("planned subscriber failure")
}

FoundationReentrantSubscriber(trace, received, entry) {
    received.Push(entry.Event)
    if entry.Event == "outer"
        trace.Record("runtime", "nested")
}

FoundationCollectTraceEvent(received, entry) {
    received.Push(entry.Event)
}

FoundationJoin(values) {
    result := ""
    for value in values
        result .= (result == "" ? "" : ",") value
    return result
}

FoundationCountSubstring(text, needle) {
    count := 0
    position := 1
    while position := InStr(text, needle, true, position) {
        count++
        position += StrLen(needle)
    }
    return count
}

FoundationReplaceManagedSpecBody(blockText, specValue,
        includeEmbeddedMetadata := false) {
    persistedSpec := RuleSpec.Clone(specValue)
    if !includeEmbeddedMetadata {
        persistedSpec.Delete("id")
        persistedSpec.Delete("display")
    }
    jsonText := JsonCodec.Stringify(persistedSpec, true, true)
    commentedJson := ""
    Loop Parse jsonText, "`n", "`r"
        commentedJson .= (A_Index > 1 ? "`n" : "") "; " A_LoopField
    beginMarker := "; @spec-begin`n"
    beginPosition := InStr(blockText, beginMarker, true)
    endPosition := InStr(blockText, "; @spec-end", true,
        beginPosition + StrLen(beginMarker))
    if !beginPosition || !endPosition
        throw Error("Test fixture does not contain a managed spec section.")
    contentStart := beginPosition + StrLen(beginMarker)
    return SubStr(blockText, 1, contentStart - 1) commentedJson "`n"
        . SubStr(blockText, endPosition)
}
