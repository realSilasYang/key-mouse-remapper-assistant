class MappingCodeRepository {
    static RegionStart := "; === 重映射代码区域开始 ==="
    static RegionEnd := "; === 重映射代码区域结束 ==="
    static RegionNotice := "; 此区域由 GUI 维护；代码块顺序就是 GUI 的默认显示顺序，请勿删除元数据行。"
    static MaximumRegionCharacters := 10 * 1024 * 1024
    static MaximumBlockCharacters := 3 * 1024 * 1024
    static MaximumMappings := 2000
    static MaximumScriptBytes := 48 * 1024 * 1024
    static MaximumScriptCharacters := 12 * 1024 * 1024
    static MaximumSyntaxDiagnosticBytes := 1024 * 1024

    __New(scriptPath) {
        scriptPath := Trim(String(scriptPath))
        if scriptPath == ""
            throw ValueError("重映射脚本路径不能为空。")
        this.ScriptPath := CrossProcessWriteLock.NormalizePath(scriptPath)
        this.LastWriteResult := ""
        this.CachedSnapshot := ""
    }

    Load() {
        return this.ReadSnapshot().Mappings
    }

    ReadSnapshot() {
        sourceText := this.ReadScriptText()
        if IsObject(this.CachedSnapshot)
                && this.CachedSnapshot.SourceText == sourceText
            return this.CloneSnapshot(this.CachedSnapshot)
        region := this.GetRegion(sourceText)
        snapshot := {
            SourceText: sourceText,
            Region: region,
            Mappings: this.ParseMappings(region.Body, region.BodyStartLine)
        }
        this.CachedSnapshot := snapshot
        return this.CloneSnapshot(snapshot)
    }

    GetById(mappingId) {
        for mapping in this.Load() {
            if mapping.Id == mappingId
                return mapping
        }
        throw Error("找不到要编辑的映射代码块。")
    }

    ReplaceBlock(mappingId, blockText, expectedMode := "") {
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
        editedMappings := this.ParseMappings(candidateText)
        if editedMappings.Length != 1
            throw Error("编辑内容必须恰好包含一个完整的映射代码块。")
        editedMapping := editedMappings[1]
        if expectedMode != "" && editedMapping.Mode != expectedMode
            throw Error("编辑器类型与规则块的 @类型 不一致。")
        if editedMapping.Block != candidateText
            throw Error("@mapping-begin 与 @mapping-end 之外不能包含其他内容。")
        for index, mapping in mappings {
            if index != sourceIndex && mapping.Id == editedMapping.Id
                throw Error("映射名称重复：" editedMapping.Id)
        }

        candidateText := this.BuildMappingBlock(editedMapping, region.Eol)
        editedMapping.Block := candidateText
        editedMapping.EditorText := candidateText
        mappings[sourceIndex] := editedMapping
        this.Rewrite(mappings, snapshot, true)
        return editedMapping
    }

    CreateBlankBlock() {
        region := this.GetRegion(this.ReadScriptText())
        return RuleCompiler.BuildBlankManagedBlock(region.Eol)
    }

    CreateBlankScriptCode() {
        return ScriptRuleCompiler.ScriptCodePlaceholder
    }

    CreateBlankScriptBlock() {
        region := this.GetRegion(this.ReadScriptText())
        return ScriptRuleCompiler.BuildBlankScriptBlock(region.Eol)
    }

    CreateBlankEditorText(mode := "managed") {
        mode := StrLower(Trim(String(mode)))
        if mode == "managed"
            return this.CreateBlankBlock()
        if mode == "script"
            return this.CreateBlankScriptBlock()
        throw Error("未知规则编辑模式：" mode)
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

    AppendBlock(blockText, expectedMode := "") {
        snapshot := this.ReadSnapshot()
        region := snapshot.Region
        mappings := snapshot.Mappings
        candidateText := Trim(String(blockText), "`r`n")
        if candidateText == ""
            throw Error("映射代码块不能为空。")
        addedMappings := this.ParseMappings(candidateText)
        if addedMappings.Length != 1
            throw Error("新增内容必须恰好包含一个完整的映射代码块。")
        addedMapping := addedMappings[1]
        if expectedMode != "" && addedMapping.Mode != expectedMode
            throw Error("编辑器类型与规则块的 @类型 不一致。")
        if addedMapping.Block != candidateText
            throw Error("@mapping-begin 与 @mapping-end 之外不能包含其他内容。")
        for mapping in mappings {
            if mapping.Id == addedMapping.Id
                throw Error("映射名称重复：" addedMapping.Id)
        }
        candidateText := this.BuildMappingBlock(addedMapping, region.Eol)
        addedMapping.Block := candidateText
        addedMapping.EditorText := candidateText
        mappings.Push(addedMapping)
        this.Rewrite(mappings, snapshot, true)
        return addedMapping
    }

    AppendEditorText(editorText, mode := "managed") {
        mode := StrLower(Trim(String(mode)))
        if mode != "managed" && mode != "script"
            throw Error("未知规则编辑模式：" mode)
        return this.AppendBlock(editorText, mode)
    }

    ReplaceEditorText(mappingId, editorText, mode := "managed") {
        mode := StrLower(Trim(String(mode)))
        if mode != "managed" && mode != "script"
            throw Error("未知规则编辑模式：" mode)
        return this.ReplaceBlock(mappingId, editorText, mode)
    }

    AppendManagedSpec(specValue) {
        snapshot := this.ReadSnapshot()
        spec := RuleSpec.Normalize(specValue)
        for mapping in snapshot.Mappings {
            if mapping.Id == spec["id"]
                throw Error("映射名称重复：" spec["id"])
        }
        block := RuleCompiler.BuildManagedBlock(spec, snapshot.Region.Eol)
        mapping := this.ParseMappings(block)[1]
        snapshot.Mappings.Push(mapping)
        this.Rewrite(snapshot.Mappings, snapshot, true)
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

    ParseMappings(regionBody, firstLineNumber := 1) {
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
                if RegExMatch(A_LoopField,
                        "^; @([\p{L}\p{N}_-]+)=(.*)$", &fieldMatch) {
                    metadataName := fieldMatch[1]
                    if fields.Has(metadataName)
                        throw Error("映射代码块包含重复元数据：" metadataName)
                    fields[metadataName] := this.DecodeMetadataValue(fieldMatch[2])
                }
            }
            if !fields.Has("类型") || fields["类型"] == ""
                throw Error("规则代码块缺少 @类型 元数据。")
            mode := RuleCompiler.ModeFromTypeName(fields["类型"])
            startLine := firstLineNumber + this.CountLineBreaks(
                SubStr(regionBody, 1, blockMatch.Pos(0) - 1))
            if mode == "managed" {
                spec := RuleCompiler.ParseManagedSpec(blockMatch[0])
                editorText := RuleCompiler.BuildManagedBlock(spec,
                    InStr(blockMatch[0], "`r`n") ? "`r`n" : "`n")
                compiled := RuleCompiler.Compile(spec)
                if !fields.Has("名称") || fields["名称"] == ""
                    throw Error("规则块缺少 @名称 元数据。")
                metadataName := RuleSpec.NormalizeId(fields["名称"])
                if metadataName != compiled.Id
                    throw Error("规则块的 @名称 与内部名称不一致。")
                mapping := {
                    Id: compiled.Id, Source: compiled.Source,
                    Target: compiled.Target, Scope: compiled.Scope,
                    Enabled: compiled.Enabled,
                    SourceSpec: compiled.Hotkey, TargetSend: "",
                    SourceKind: "managed", SourceVK: "", SourceSC: "",
                    SourceCommand: "", SourceKeyInfo: "",
                    TargetKind: "managed", TargetVK: "", TargetSC: "",
                    TargetCommand: "", TargetKeyInfo: "",
                    Mode: "managed", Spec: spec,
                    Descriptor: compiled, StartLine: startLine,
                    EditorText: editorText, Block: blockMatch[0]
                }
            } else if mode == "script" {
                spec := ScriptRuleCompiler.ParseSpec(blockMatch[0])
                editorText := ScriptRuleCompiler.BuildBlock(spec,
                    InStr(blockMatch[0], "`r`n") ? "`r`n" : "`n")
                if !fields.Has("名称") || fields["名称"] == ""
                    throw Error("受托管独立脚本缺少 @名称 元数据。")
                metadataName := RuleSpec.NormalizeId(fields["名称"])
                if metadataName != spec["id"]
                    throw Error("受托管独立脚本的 @名称 与内部名称不一致。")
                display := spec["display"]
                mapping := {
                    Id: spec["id"], Source: display["source"],
                    Target: display["target"],
                    Scope: display.Get("scope", "全局"),
                    Enabled: spec.Get("enabled", JsonBoolean(true)).Value,
                    SourceSpec: ScriptRuleSpec.Join(
                        ScriptRuleSpec.FindHotkeyLabels(spec["code"]), " / "),
                    TargetSend: "", SourceKind: "script", SourceVK: "",
                    SourceSC: "", SourceCommand: "", SourceKeyInfo: "",
                    TargetKind: "script", TargetVK: "", TargetSC: "",
                    TargetCommand: "", TargetKeyInfo: "", Mode: "script",
                    Spec: spec, StartLine: startLine,
                    EditorText: editorText,
                    Block: blockMatch[0]
                }
            } else {
                throw Error("不支持的内部规则类型：" mode)
            }
            if seenIds.Has(mapping.Id)
                throw Error("映射名称重复：" mapping.Id)
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
                throw Error("重映射代码区域只允许注释化规则块，不允许直接执行 AHK 代码。")
        }
        return true
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
        ; Prefix 截止于开始标记末尾，Suffix 从结束标记开头起算。即使调用方
        ; 提交空规则集，也必须保留两个标记各自独占一行；非标准正文同样在
        ; 解析和发布前归一化边界，避免生成语法合法但仓库无法再次读取的脚本。
        if SubStr(normalizedBody, 1, StrLen(region.Eol)) != region.Eol
            normalizedBody := region.Eol . normalizedBody
        if SubStr(normalizedBody, -StrLen(region.Eol)) != region.Eol
            normalizedBody .= region.Eol
        ; 先解析快照中的全部代码块，再让完整脚本通过解释器校验。
        validatedMappings := this.ParseMappings(normalizedBody)
        ; ParseMappings proves every replacement line is a comment and fully
        ; validates every managed block. Prefix and suffix come unchanged from
        ; the current snapshot, so no executable AHK text needs re-validation.
        this.WriteValidatedFile(region.Prefix . normalizedBody . region.Suffix,
            snapshot.SourceText, true)
        this.LastWriteResult := {Body: normalizedBody,
            Mappings: validatedMappings}
        this.CacheCommittedSnapshot(region.Prefix . normalizedBody
            . region.Suffix, region, normalizedBody, validatedMappings)
        return true
    }

    Remove(mappingId) {
        snapshot := this.ReadSnapshot()
        mappings := snapshot.Mappings
        for index, mapping in mappings {
            if mapping.Id != mappingId
                continue
            removed := mappings.RemoveAt(index)
            this.Rewrite(mappings, snapshot, true)
            return removed
        }
        throw Error("找不到要删除的映射代码块。")
    }

    RemoveMany(mappingIds) {
        requestedIds := this.NormalizeMappingIds(mappingIds)
        snapshot := this.ReadSnapshot()
        retainedMappings := []
        removedMappings := []
        for mapping in snapshot.Mappings {
            if requestedIds.Has(mapping.Id)
                removedMappings.Push(mapping)
            else
                retainedMappings.Push(mapping)
        }
        if removedMappings.Length != requestedIds.Count
            throw Error("找不到一个或多个要删除的映射代码块。")
        this.Rewrite(retainedMappings, snapshot, true)
        return removedMappings
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
        this.Rewrite(mappings, snapshot, true)
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
        this.Rewrite(mappings, snapshot, true)
        return true
    }

    MoveManyTo(mappingIds, targetIndex) {
        requestedIds := this.NormalizeMappingIds(mappingIds)
        snapshot := this.ReadSnapshot()
        mappings := snapshot.Mappings
        if Type(targetIndex) != "Integer"
            throw TypeError("映射目标位置必须是整数。")
        targetIndex := Max(1, Min(mappings.Length + 1, targetIndex))

        movingMappings := []
        retainedMappings := []
        selectedBeforeTarget := 0
        originalIds := []
        for index, mapping in mappings {
            originalIds.Push(mapping.Id)
            if requestedIds.Has(mapping.Id) {
                movingMappings.Push(mapping)
                if index < targetIndex
                    selectedBeforeTarget++
            } else {
                retainedMappings.Push(mapping)
            }
        }
        if movingMappings.Length != requestedIds.Count
            throw Error("找不到一个或多个要调整顺序的映射代码块。")
        insertIndex := Max(1, Min(retainedMappings.Length + 1,
            targetIndex - selectedBeforeTarget))
        reorderedMappings := []
        for index, mapping in retainedMappings {
            if index == insertIndex {
                for movingMapping in movingMappings
                    reorderedMappings.Push(movingMapping)
            }
            reorderedMappings.Push(mapping)
        }
        if insertIndex == retainedMappings.Length + 1 {
            for movingMapping in movingMappings
                reorderedMappings.Push(movingMapping)
        }

        changed := false
        for index, mapping in reorderedMappings {
            if mapping.Id != originalIds[index] {
                changed := true
                break
            }
        }
        if !changed
            return false
        this.Rewrite(reorderedMappings, snapshot, true)
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
        mapping.Block := this.BuildMappingBlock(mapping, region.Eol)
        mapping := this.ParseMappings(mapping.Block)[1]
        mappings[sourceIndex] := mapping
        this.Rewrite(mappings, snapshot, true)
        return mapping
    }

    ToggleEnabledMany(mappingIds) {
        requestedIds := this.NormalizeMappingIds(mappingIds)
        snapshot := this.ReadSnapshot()
        region := snapshot.Region
        toggledMappings := []
        for index, mapping in snapshot.Mappings {
            if !requestedIds.Has(mapping.Id)
                continue
            mapping.Enabled := !mapping.Enabled
            mapping.Spec["enabled"] := JsonBoolean(mapping.Enabled)
            mapping.Block := this.BuildMappingBlock(mapping, region.Eol)
            mapping := this.ParseMappings(mapping.Block)[1]
            snapshot.Mappings[index] := mapping
            toggledMappings.Push(mapping)
        }
        if toggledMappings.Length != requestedIds.Count
            throw Error("找不到一个或多个要暂停或恢复的映射代码块。")
        this.Rewrite(snapshot.Mappings, snapshot, true)
        return toggledMappings
    }

    NormalizeMappingIds(mappingIds) {
        if Type(mappingIds) != "Array"
            throw TypeError("映射名称集合必须是数组。")
        normalizedIds := Map()
        for mappingId in mappingIds {
            mappingId := Trim(String(mappingId))
            if mappingId != ""
                normalizedIds[mappingId] := true
        }
        if !normalizedIds.Count
            throw ValueError("映射名称集合不能为空。")
        return normalizedIds
    }

    BuildMappingBlock(mapping, eol) {
        mode := mapping.HasOwnProp("Mode") ? mapping.Mode : "managed"
        if mode == "managed"
            return RuleCompiler.BuildManagedBlock(mapping.Spec, eol)
        if mode == "script"
            return ScriptRuleCompiler.BuildBlock(mapping.Spec, eol)
        throw Error("未知内部规则类型：" mode)
    }

    Rewrite(mappings, snapshot?, mappingsValidated := false) {
        if !IsSet(snapshot)
            snapshot := this.ReadSnapshot()
        if Type(mappings) != "Array"
            throw TypeError("映射重写输入必须是数组。")
        if mappings.Length > MappingCodeRepository.MaximumMappings
            throw Error("重映射代码区域中的映射数量超过上限。")
        region := snapshot.Region
        blockText := ""
        for mapping in mappings
            blockText .= RTrim(mapping.Block, "`r`n") region.Eol region.Eol
        updatedBody := region.Eol
            . MappingCodeRepository.RegionNotice . region.Eol . region.Eol
            . blockText
        if mappingsValidated
            this.ValidateAssembledRegion(updatedBody, mappings.Length)
        else
            this.ParseMappings(updatedBody)
        updatedText := region.Prefix . updatedBody . region.Suffix
        this.WriteValidatedFile(updatedText, snapshot.SourceText, true)
        this.LastWriteResult := {Body: updatedBody,
            Mappings: mappings.Clone()}
        this.CacheCommittedSnapshot(updatedText, region, updatedBody, mappings)
        return true
    }

    CacheCommittedSnapshot(sourceText, region, regionBody, mappings) {
        committedRegion := this.CloneRegion(region)
        committedRegion.Body := regionBody
        this.CachedSnapshot := {SourceText: sourceText,
            Region: committedRegion, Mappings: this.CloneMappings(mappings)}
        return true
    }

    CloneSnapshot(snapshot) {
        return {SourceText: snapshot.SourceText,
            Region: this.CloneRegion(snapshot.Region),
            Mappings: this.CloneMappings(snapshot.Mappings)}
    }

    CloneRegion(region) {
        return {Prefix: region.Prefix, Body: region.Body,
            Suffix: region.Suffix, Eol: region.Eol,
            BodyStartLine: region.BodyStartLine}
    }

    CloneMappings(mappings) {
        clones := []
        for mapping in mappings
            clones.Push(this.CloneMapping(mapping))
        return clones
    }

    CloneMapping(mapping) {
        clone := {}
        for propertyName, value in mapping.OwnProps()
            clone.%propertyName% := value
        if mapping.HasOwnProp("Spec")
            clone.Spec := RuleSpec.Clone(mapping.Spec)
        if mapping.HasOwnProp("Descriptor") {
            descriptor := {}
            for propertyName, value in mapping.Descriptor.OwnProps()
                descriptor.%propertyName% := value
            if clone.HasOwnProp("Spec")
                descriptor.Spec := clone.Spec
            clone.Descriptor := descriptor
        }
        return clone
    }

    ValidateAssembledRegion(regionBody, expectedMappings) {
        this.ValidateCommentOnlyRegion(regionBody)
        beginCount := this.CountMarkerLines(regionBody, "; @mapping-begin")
        endCount := this.CountMarkerLines(regionBody, "; @mapping-end")
        if beginCount != expectedMappings || endCount != expectedMappings
            throw Error("The assembled mapping region is structurally incomplete.")
        return true
    }

    ResetLastWriteResult() {
        this.LastWriteResult := ""
        return true
    }

    TakeLastWriteResult() {
        result := this.LastWriteResult
        this.LastWriteResult := ""
        return result
    }

    CreateMappingName(existingMappings := "") {
        existingIds := Map()
        if Type(existingMappings) == "Array" {
            for mapping in existingMappings
                existingIds[mapping.Id] := true
        }
        Loop 16 {
            candidate := "新建映射-" A_NowUTC "-"
                . Format("{:08X}", Random(0, 0xFFFFFFFF))
            if !existingIds.Has(candidate)
                return candidate
        }
        throw Error("无法生成唯一的映射名称。")
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

    WriteValidatedFile(updatedText, expectedText?, skipSyntaxCheck := false) {
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
                if !skipSyntaxCheck
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
        sourceText := String(sourceText)
        if StrLen(sourceText)
                > MappingCodeRepository.MaximumScriptCharacters
            throw Error("脚本文本超过字符上限。")
        if StrPut(sourceText, "UTF-8") - 1
                > MappingCodeRepository.MaximumScriptBytes
            throw Error("脚本文本超过 UTF-8 字节上限。")
        return true
    }

    ValidateScriptSyntax(temporaryPath) {
        diagnosticPath := temporaryPath ".syntax-output-"
            . Format("{:08X}", Random(0, 0xFFFFFFFF))
        innerCommand := Chr(34) A_AhkPath Chr(34) " /ErrorStdOut "
            . Chr(34) temporaryPath Chr(34) " --syntax-check > "
            . Chr(34) diagnosticPath Chr(34) " 2>&1"
        command := Chr(34) A_ComSpec Chr(34) " /D /S /C "
            . Chr(34) innerCommand Chr(34)
        shell := ComObject("WScript.Shell")
        try exitCode := shell.Run(command, 0, true)
        finally {
            diagnostic := this.ReadSyntaxDiagnostic(diagnosticPath)
            if FileExist(diagnosticPath)
                try FileDelete(diagnosticPath)
        }
        if exitCode == 0
            return true
        if StrLen(diagnostic) > 3000
            diagnostic := SubStr(diagnostic, 1, 3000) "..."
        throw Error("生成后的重映射脚本未通过语法检查，原文件未改动。"
            . (diagnostic == "" ? "" : "`n" diagnostic))
    }

    ReadSyntaxDiagnostic(diagnosticPath) {
        if !FileExist(diagnosticPath) || DirExist(diagnosticPath)
            return ""
        input := FileOpen(diagnosticPath, "r")
        if !IsObject(input)
            return ""
        try {
            if input.Length > MappingCodeRepository.MaximumSyntaxDiagnosticBytes
                return Trim(input.Read(3000), " `t`r`n")
            return Trim(input.Read(), " `t`r`n")
        } finally input.Close()
    }

    BeforeReplace(expectedText, updatedText) {
    }
}
