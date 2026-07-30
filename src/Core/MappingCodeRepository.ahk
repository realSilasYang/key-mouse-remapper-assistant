class MappingCodeRepository {
    static RegionStart := "; === 重映射代码区域开始 ==="
    static RegionEnd := "; === 重映射代码区域结束 ==="
    static RegionNotice := "; 此区域由 GUI 维护；代码块顺序就是 GUI 的默认显示顺序，请勿删除元数据行。"
    static MaximumRegionCharacters := 10 * 1024 * 1024
    static MaximumBlockCharacters := 512 * 1024
    static MaximumMappings := 2000
    static MaximumScriptBytes := 48 * 1024 * 1024
    static MaximumScriptCharacters := 12 * 1024 * 1024

    __New(scriptPath) {
        scriptPath := Trim(String(scriptPath))
        if scriptPath == ""
            throw ValueError("重映射脚本路径不能为空。")
        this.ScriptPath := CrossProcessWriteLock.NormalizePath(scriptPath)
    }

    Load() {
        return this.ReadSnapshot().Mappings
    }

    ReadSnapshot() {
        sourceText := this.ReadScriptText()
        region := this.GetRegion(sourceText)
        return {
            SourceText: sourceText,
            Region: region,
            Mappings: this.ParseMappings(region.Body, true,
                region.BodyStartLine)
        }
    }

    GetById(mappingId) {
        for mapping in this.Load() {
            if mapping.Id == mappingId
                return mapping
        }
        throw Error("找不到要编辑的映射代码块。")
    }

    ReplaceBlock(mappingId, blockText) {
        snapshot := this.ReadSnapshot()
        region := snapshot.Region
        mappings := snapshot.Mappings
        sourceIndex := 0
        for index, mapping in mappings {
            if mapping.Id == mappingId {
                sourceIndex := index
                break
            }
        }
        if !sourceIndex
            throw Error("找不到要编辑的映射代码块。")

        candidateText := Trim(String(blockText), "`r`n")
        if candidateText == ""
            throw Error("映射代码块不能为空。")
        editedMappings := this.ParseMappings(candidateText, false)
        if editedMappings.Length != 1
            throw Error("编辑内容必须恰好包含一个完整的映射代码块。")
        editedMapping := editedMappings[1]
        if editedMapping.Block != candidateText
            throw Error("@mapping-begin 与 @mapping-end 之外不能包含其他内容。")
        for index, mapping in mappings {
            if index != sourceIndex && mapping.Id == editedMapping.Id
                throw Error("映射代码块编号重复：" editedMapping.Id)
        }

        candidateText := this.NormalizeCandidateBlock(candidateText, region.Eol)
        editedMapping := this.ParseMappings(candidateText)[1]
        editedMapping.Block := candidateText
        mappings[sourceIndex] := editedMapping
        this.Rewrite(mappings, snapshot)
        return editedMapping
    }

    CreateBlankBlock() {
        region := this.GetRegion(this.ReadScriptText())
        spec := Map("schema", 2, "id", this.CreateMappingId(this.Load()),
            "enabled", JsonBoolean(true),
            "description", "请编辑此 RuleSpec。",
            "display", Map("source", "F24", "target", "F23",
                "scope", "全局", "purpose", "请编辑此 RuleSpec。"),
            "from", Map("hotkey", "", "event", "down",
                "key", Map("kind", "keyboard", "name", "F24")),
            "conditions", [],
            "to", [Map("type", "send", "value", "{F23}")])
        return RuleCompiler.BuildManagedBlock(RuleSpec.Normalize(spec),
            region.Eol)
    }

    GetAppendStartLine() {
        snapshot := this.ReadSnapshot()
        region := snapshot.Region
        textBeforeBlock := region.Prefix . region.Eol
            . MappingCodeRepository.RegionNotice . region.Eol . region.Eol
        for mapping in snapshot.Mappings
            textBeforeBlock .= RTrim(mapping.Block, "`r`n")
                . region.Eol . region.Eol
        return this.CountLineBreaks(textBeforeBlock) + 1
    }

    AppendBlock(blockText) {
        snapshot := this.ReadSnapshot()
        region := snapshot.Region
        mappings := snapshot.Mappings
        candidateText := Trim(String(blockText), "`r`n")
        if candidateText == ""
            throw Error("映射代码块不能为空。")
        addedMappings := this.ParseMappings(candidateText, false)
        if addedMappings.Length != 1
            throw Error("新增内容必须恰好包含一个完整的映射代码块。")
        addedMapping := addedMappings[1]
        if addedMapping.Block != candidateText
            throw Error("@mapping-begin 与 @mapping-end 之外不能包含其他内容。")
        for mapping in mappings {
            if mapping.Id == addedMapping.Id
                throw Error("映射代码块编号重复：" addedMapping.Id)
        }
        candidateText := this.NormalizeCandidateBlock(candidateText, region.Eol)
        addedMapping := this.ParseMappings(candidateText)[1]
        addedMapping.Block := candidateText
        mappings.Push(addedMapping)
        this.Rewrite(mappings, snapshot)
        return addedMapping
    }

    AppendManagedSpec(specValue) {
        snapshot := this.ReadSnapshot()
        spec := RuleSpec.Normalize(specValue)
        for mapping in snapshot.Mappings {
            if mapping.Id == spec["id"]
                throw Error("映射代码块编号重复：" spec["id"])
        }
        block := RuleCompiler.BuildManagedBlock(spec, snapshot.Region.Eol)
        mapping := this.ParseMappings(block)[1]
        snapshot.Mappings.Push(mapping)
        this.Rewrite(snapshot.Mappings, snapshot)
        return mapping
    }

    ReplaceManagedSpec(mappingId, specValue) {
        snapshot := this.ReadSnapshot()
        spec := RuleSpec.Normalize(specValue)
        sourceIndex := 0
        for index, mapping in snapshot.Mappings {
            if mapping.Id == mappingId
                sourceIndex := index
            else if mapping.Id == spec["id"]
                throw Error("映射代码块编号重复：" spec["id"])
        }
        if !sourceIndex
            throw Error("找不到要编辑的托管规则。")
        block := RuleCompiler.BuildManagedBlock(spec, snapshot.Region.Eol)
        mapping := this.ParseMappings(block)[1]
        snapshot.Mappings[sourceIndex] := mapping
        this.Rewrite(snapshot.Mappings, snapshot)
        return mapping
    }

    GetRegion(sourceText) {
        startCount := this.CountMarkerLines(sourceText,
            MappingCodeRepository.RegionStart)
        endCount := this.CountMarkerLines(sourceText,
            MappingCodeRepository.RegionEnd)
        if startCount != 1
            throw Error("重映射代码区域的开始标记必须恰好出现一次。")
        if endCount != 1
            throw Error("重映射代码区域的结束标记必须恰好出现一次。")
        RegExMatch(sourceText, "m)^" MappingCodeRepository.RegionStart
            . "\r?$", &startMatch)
        startPosition := startMatch.Pos(0)
        contentStart := startPosition + StrLen(MappingCodeRepository.RegionStart)
        RegExMatch(sourceText, "m)^" MappingCodeRepository.RegionEnd
            . "\r?$", &endMatch, contentStart)
        endPosition := endMatch.Pos(0)
        if endPosition < contentStart
            throw Error("重映射代码区域标记顺序错误。")
        return {
            Prefix: SubStr(sourceText, 1, contentStart - 1),
            Body: SubStr(sourceText, contentStart, endPosition - contentStart),
            Suffix: SubStr(sourceText, endPosition),
            Eol: InStr(sourceText, "`r`n") ? "`r`n" : "`n",
            BodyStartLine: this.CountLineBreaks(
                SubStr(sourceText, 1, contentStart - 1)) + 1
        }
    }

    ParseMappings(regionBody, validateEnabledState := true,
        firstLineNumber := 1) {
        regionBody := String(regionBody)
        if StrLen(regionBody) > MappingCodeRepository.MaximumRegionCharacters
            throw Error("重映射代码区域超过大小上限。")
        this.ValidateCommentOnlyRegion(regionBody)
        mappings := []
        seenIds := Map()
        position := 1
        pattern := "ms)^; @mapping-begin\R(.*?)^; @mapping-end[^\r\n]*"
        while RegExMatch(regionBody, pattern, &blockMatch, position) {
            if blockMatch.Len(0) > MappingCodeRepository.MaximumBlockCharacters
                throw Error("映射代码块超过大小上限。")
            fields := Map()
            Loop Parse blockMatch[1], "`n", "`r" {
                if RegExMatch(A_LoopField, "^; @([a-z-]+)=(.*)$", &fieldMatch) {
                    metadataName := fieldMatch[1]
                    if fields.Has(metadataName)
                        throw Error("映射代码块包含重复元数据：" metadataName)
                    fields[metadataName] := this.DecodeMetadataValue(fieldMatch[2])
                }
            }
            mode := StrLower(this.OptionalField(fields, "mode"))
            schemaValue := this.OptionalField(fields, "schema")
            if mode != "managed" || (schemaValue != "1" && schemaValue != "2")
                throw Error("仅支持 @mode=managed 的 Raw Input RuleSpec 规则。")
            spec := RuleCompiler.ParseManagedSpec(blockMatch[0])
            compiled := RuleCompiler.Compile(spec)
            if fields.Has("id") && fields["id"] != compiled.Id
                throw Error("托管规则的 @id 与 RuleSpec id 不一致。")
            mapping := {
                Id: compiled.Id, Source: compiled.Source,
                Target: compiled.Target, Scope: compiled.Scope,
                Purpose: compiled.Purpose, Enabled: compiled.Enabled,
                SourceSpec: compiled.Hotkey, TargetSend: "",
                SourceKind: "managed", SourceVK: "", SourceSC: "",
                SourceCommand: "", SourceKeyInfo: "",
                TargetKind: "managed", TargetVK: "", TargetSC: "",
                TargetCommand: "", TargetKeyInfo: "",
                Mode: "managed", Schema: 2, Spec: spec,
                Descriptor: compiled,
                StartLine: firstLineNumber + this.CountLineBreaks(
                    SubStr(regionBody, 1, blockMatch.Pos(0) - 1)),
                Block: blockMatch[0]
            }
            if seenIds.Has(mapping.Id)
                throw Error("映射代码块编号重复：" mapping.Id)
            seenIds[mapping.Id] := true
            mappings.Push(mapping)
            if mappings.Length > MappingCodeRepository.MaximumMappings
                throw Error("重映射代码区域中的映射数量超过上限。")
            position := blockMatch.Pos(0) + blockMatch.Len(0)
        }
        beginCount := this.CountMarkerLines(regionBody, "; @mapping-begin")
        endCount := this.CountMarkerLines(regionBody, "; @mapping-end")
        if beginCount != endCount || mappings.Length != beginCount
            throw Error("重映射代码区域存在不完整或无法解析的代码块。")
        return mappings
    }

    ValidateCommentOnlyRegion(regionBody) {
        Loop Parse this.NormalizeLineEndings(regionBody, "`n"), "`n" {
            line := LTrim(A_LoopField, " `t")
            if line != "" && SubStr(line, 1, 1) != ";"
                throw Error("重映射代码区域只允许 RuleSpec 注释块，不允许可执行 AHK 代码。")
        }
        return true
    }

    NormalizeCandidateBlock(blockText, eol) {
        normalized := this.NormalizeLineEndings(blockText, eol)
        this.ParseMappings(normalized)
        return normalized
    }

    CountMarkerLines(text, marker) {
        count := 0
        Loop Parse text, "`n", "`r" {
            if A_LoopField == marker
                count++
        }
        return count
    }

    CountLineBreaks(text) {
        count := 0
        position := 1
        while position := InStr(String(text), "`n", , position) {
            count++
            position++
        }
        return count
    }

    RequireField(fields, fieldName, requireValue := true) {
        if !fields.Has(fieldName)
            throw Error("映射代码块缺少元数据：" fieldName)
        value := fields[fieldName]
        if requireValue && value == ""
            throw Error("映射代码块的元数据不能为空：" fieldName)
        return value
    }

    ReadRegionBody() {
        return this.GetRegion(this.ReadScriptText()).Body
    }

    WriteRegionBody(regionBody, expectedBody?) {
        snapshot := this.ReadSnapshot()
        region := snapshot.Region
        if IsSet(expectedBody) && region.Body != String(expectedBody)
            throw Error("映射代码区域已被其他操作修改，未覆盖新内容。")
        normalizedBody := this.NormalizeLineEndings(String(regionBody),
            region.Eol)
        ; 先解析快照中的全部代码块，再让完整脚本通过解释器校验。
        this.ParseMappings(normalizedBody)
        this.WriteValidatedFile(region.Prefix . normalizedBody . region.Suffix,
            snapshot.SourceText)
        return true
    }

    OptionalField(fields, fieldName) {
        return fields.Has(fieldName) ? fields[fieldName] : ""
    }

    Remove(mappingId) {
        snapshot := this.ReadSnapshot()
        mappings := snapshot.Mappings
        for index, mapping in mappings {
            if mapping.Id != mappingId
                continue
            removed := mappings.RemoveAt(index)
            this.Rewrite(mappings, snapshot)
            return removed
        }
        throw Error("找不到要删除的映射代码块。")
    }

    Move(mappingId, direction) {
        snapshot := this.ReadSnapshot()
        mappings := snapshot.Mappings
        sourceIndex := 0
        for index, mapping in mappings {
            if mapping.Id == mappingId {
                sourceIndex := index
                break
            }
        }
        if !sourceIndex
            throw Error("找不到要调整顺序的映射代码块。")
        if Type(direction) != "Integer"
                || (direction != -1 && direction != 1)
            throw ValueError("映射移动方向必须是 -1 或 1。")
        targetIndex := sourceIndex + direction
        if targetIndex < 1 || targetIndex > mappings.Length
            return false
        movingMapping := mappings.RemoveAt(sourceIndex)
        mappings.InsertAt(targetIndex, movingMapping)
        this.Rewrite(mappings, snapshot)
        return true
    }

    MoveTo(mappingId, targetIndex) {
        snapshot := this.ReadSnapshot()
        mappings := snapshot.Mappings
        sourceIndex := 0
        for index, mapping in mappings {
            if mapping.Id == mappingId {
                sourceIndex := index
                break
            }
        }
        if !sourceIndex
            throw Error("找不到要调整顺序的映射代码块。")
        if Type(targetIndex) != "Integer"
            throw TypeError("映射目标位置必须是整数。")
        targetIndex := Max(1, Min(mappings.Length, targetIndex))
        if targetIndex == sourceIndex
            return false
        movingMapping := mappings.RemoveAt(sourceIndex)
        mappings.InsertAt(targetIndex, movingMapping)
        this.Rewrite(mappings, snapshot)
        return true
    }

    ToggleEnabled(mappingId) {
        snapshot := this.ReadSnapshot()
        mappings := snapshot.Mappings
        sourceIndex := 0
        for index, mapping in mappings {
            if mapping.Id == mappingId {
                sourceIndex := index
                break
            }
        }
        if !sourceIndex
            throw Error("找不到要暂停或恢复的映射代码块。")
        region := snapshot.Region
        mapping := mappings[sourceIndex]
        mapping.Enabled := !mapping.Enabled
        mapping.Spec["enabled"] := JsonBoolean(mapping.Enabled)
        mapping.Block := RuleCompiler.BuildManagedBlock(mapping.Spec,
            region.Eol)
        mapping := this.ParseMappings(mapping.Block)[1]
        mappings[sourceIndex] := mapping
        this.Rewrite(mappings, snapshot)
        return mapping
    }

    Rewrite(mappings, snapshot?) {
        if !IsSet(snapshot)
            snapshot := this.ReadSnapshot()
        region := snapshot.Region
        blockText := ""
        for mapping in mappings
            blockText .= RTrim(mapping.Block, "`r`n") region.Eol region.Eol
        updatedText := region.Prefix . region.Eol
            . MappingCodeRepository.RegionNotice . region.Eol . region.Eol
            . blockText . region.Suffix
        this.WriteValidatedFile(updatedText, snapshot.SourceText)
    }

    CreateMappingId(existingMappings := "") {
        existingIds := Map()
        if Type(existingMappings) == "Array" {
            for mapping in existingMappings
                existingIds[mapping.Id] := true
        }
        Loop 16 {
            candidate := "user-" A_NowUTC "-"
                . Format("{:08X}", Random(0, 0xFFFFFFFF))
            if !existingIds.Has(candidate)
                return candidate
        }
        throw Error("无法生成唯一的映射代码块编号。")
    }

    EncodeMetadataValue(value) {
        encoded := StrReplace(String(value), "%", "%25")
        encoded := StrReplace(encoded, "`r", "%0D")
        return StrReplace(encoded, "`n", "%0A")
    }

    DecodeMetadataValue(value) {
        decoded := StrReplace(String(value), "%0D", "`r")
        decoded := StrReplace(decoded, "%0A", "`n")
        return StrReplace(decoded, "%25", "%")
    }

    NormalizeLineEndings(text, eol) {
        normalized := StrReplace(String(text), "`r`n", "`n")
        normalized := StrReplace(normalized, "`r", "`n")
        return eol == "`n" ? normalized : StrReplace(normalized, "`n", eol)
    }

    WriteValidatedFile(updatedText, expectedText?) {
        writeLease := CrossProcessWriteLock.Acquire(this.ScriptPath)
        try {
            this.ValidateScriptTextSize(updatedText)
            temporaryPath := this.ScriptPath . ".codex-" . A_TickCount . "-"
                . Format("{:08X}", Random(0, 0xFFFFFFFF)) . ".ahk"
            outputFile := ""
            try {
                outputFile := FileOpen(temporaryPath, "w", "UTF-8-RAW")
                if !IsObject(outputFile)
                    throw Error("无法创建脚本临时文件。")
                outputFile.Write(updatedText)
                outputFile.Close()
                outputFile := ""
                this.ValidateScriptSyntax(temporaryPath)
                this.BeforeReplace(IsSet(expectedText) ? expectedText : "",
                    updatedText)
                if IsSet(expectedText)
                        && this.ReadScriptText() != expectedText
                    throw Error("脚本已被其他程序修改，本次操作未覆盖外部更改。")
                DllCall("kernel32\SetLastError", "UInt", 0)
                if !DllCall("kernel32\ReplaceFileW", "WStr", this.ScriptPath,
                    "WStr", temporaryPath, "Ptr", 0, "UInt", 0,
                    "Ptr", 0, "Ptr", 0, "Int")
                    throw Error("无法替换脚本文件（Win32 " A_LastError "）。")
            } catch as writeError {
                if IsObject(outputFile)
                    try outputFile.Close()
                if FileExist(temporaryPath)
                    try FileDelete(temporaryPath)
                throw writeError
            }
        } finally writeLease.Release()
    }

    ReadScriptText() {
        if !FileExist(this.ScriptPath)
            throw Error("脚本文件不存在。")
        return BoundedFileReader.ReadUtf8(this.ScriptPath,
            MappingCodeRepository.MaximumScriptBytes,
            MappingCodeRepository.MaximumScriptCharacters, "脚本文件")
    }

    ValidateScriptTextSize(sourceText) {
        if StrLen(String(sourceText))
                > MappingCodeRepository.MaximumScriptCharacters
            throw Error("脚本文本超过字符上限。")
        return true
    }

    ValidateScriptSyntax(temporaryPath) {
        command := Chr(34) A_AhkPath Chr(34) " /ErrorStdOut "
            . Chr(34) temporaryPath Chr(34) " --syntax-check"
        shell := ComObject("WScript.Shell")
        process := shell.Exec(command)
        standardOutput := process.StdOut.ReadAll()
        standardError := process.StdErr.ReadAll()
        if process.ExitCode == 0
            return true
        diagnostic := Trim(standardError "`n" standardOutput, " `t`r`n")
        if StrLen(diagnostic) > 3000
            diagnostic := SubStr(diagnostic, 1, 3000) "..."
        throw Error("生成后的重映射脚本未通过语法检查，原文件未改动。"
            . (diagnostic == "" ? "" : "`n" diagnostic))
    }

    BeforeReplace(expectedText, updatedText) {
    }
}
