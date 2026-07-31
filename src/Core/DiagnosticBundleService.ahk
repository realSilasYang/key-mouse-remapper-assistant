class DiagnosticBundleService {
    static SchemaVersion := 1
    static MaximumEvents := 10000
    static MaximumBundleCharacters := 16 * 1024 * 1024
    static MaximumBundleBytes := 32 * 1024 * 1024
    static MaximumValueDepth := 32
    static MaximumValueNodes := 100000

    CreatePreview(context, entries) {
        if Type(context) != "Map" || Type(entries) != "Array"
            throw TypeError("诊断包上下文或事件集合无效。")
        if entries.Length > DiagnosticBundleService.MaximumEvents
            throw ValueError("诊断包事件数量超过上限。")
        counts := Map("window_titles", 0, "paths", 0,
            "text_actions", 0, "run_commands", 0, "raw_code", 0,
            "variable_values", 0)
        redactionState := {Nodes: 0, Active: Map()}
        sanitizedContext := this.RedactValue(context, "context", counts,
            redactionState)
        sanitizedEntries := []
        for entry in entries
            sanitizedEntries.Push(this.RedactValue(entry, "event", counts,
                redactionState))
        bundle := Map(
            "schema", DiagnosticBundleService.SchemaVersion,
            "generated_at", FormatTime(A_NowUTC,
                "yyyy-MM-dd'T'HH:mm:ss'Z'"),
            "privacy", Map(
                "raw_mapping_code_included", JsonBoolean(false),
                "full_window_titles_included", JsonBoolean(false),
                "focused_control_text_included", JsonBoolean(false),
                "full_paths_included", JsonBoolean(false),
                "hook_raw_correlation_claimed", JsonBoolean(false)),
            "context", sanitizedContext,
            "events", sanitizedEntries,
            "redaction_counts", RuleSpec.Clone(counts))
        serialized := JsonCodec.Stringify(bundle, true, true)
        if StrLen(serialized) > DiagnosticBundleService.MaximumBundleCharacters
            throw Error("诊断包超过大小上限。")
        if StrPut(serialized, "UTF-8") - 1
                > DiagnosticBundleService.MaximumBundleBytes
            throw Error("诊断包超过 UTF-8 字节上限。")
        return {Bundle: bundle, Counts: counts,
            EventCount: sanitizedEntries.Length,
            Serialized: serialized}
    }

    ExportPreview(preview, filePath) {
        if !IsObject(preview) || !preview.HasOwnProp("Serialized")
            throw TypeError("诊断包预览无效。")
        filePath := CrossProcessWriteLock.NormalizePath(filePath)
        serialized := String(preview.Serialized)
        if StrLen(serialized)
                > DiagnosticBundleService.MaximumBundleCharacters
                || StrPut(serialized, "UTF-8") - 1
                    > DiagnosticBundleService.MaximumBundleBytes
            throw Error("诊断包预览超过导出大小上限。")
        directory := ""
        SplitPath(filePath, , &directory)
        if directory != "" && !DirExist(directory)
            DirCreate(directory)
        writeLease := CrossProcessWriteLock.Acquire(filePath)
        temporaryPath := filePath ".tmp-" A_TickCount "-"
            . Format("{:08X}", Random(0, 0xFFFFFFFF))
        output := ""
        try {
            output := FileOpen(temporaryPath, "w", "UTF-8-RAW")
            if !IsObject(output)
                throw Error("无法创建诊断包临时文件。")
            output.Write(serialized)
            output.Close()
            output := ""
            FileMove(temporaryPath, filePath, 1)
        } catch as exportError {
            if IsObject(output)
                try output.Close()
            if FileExist(temporaryPath)
                try FileDelete(temporaryPath)
            throw exportError
        } finally writeLease.Release()
        return filePath
    }

    RedactValue(value, keyPath, counts, state := "", depth := 0) {
        if !IsObject(state)
            state := {Nodes: 0, Active: Map()}
        if depth > DiagnosticBundleService.MaximumValueDepth
            throw Error("诊断包值嵌套层级超过上限。")
        state.Nodes++
        if state.Nodes > DiagnosticBundleService.MaximumValueNodes
            throw Error("诊断包值元素数量超过上限。")
        valueType := Type(value)
        if valueType == "Map" {
            pointer := ObjPtr(value)
            if state.Active.Has(pointer)
                return "<redacted:cycle>"
            state.Active[pointer] := true
            try {
                result := Map()
                hasInvalidActionType := value.Has("type")
                    && IsObject(value["type"])
                actionType := value.Has("type")
                        && !IsObject(value["type"])
                    ? StrLower(String(value["type"])) : ""
                for key, item in value {
                    normalizedKey := StrLower(String(key))
                    itemPath := keyPath "." normalizedKey
                    if this.IsRawCodeKey(normalizedKey) {
                        counts["raw_code"]++
                        result[key] := "<redacted:code>"
                    } else if this.IsTitleKey(normalizedKey) {
                        counts["window_titles"]++
                        result[key] := this.RedactTitle(item)
                    } else if this.IsSensitiveTextKey(normalizedKey) {
                        counts["text_actions"]++
                        result[key] := this.RedactText(item)
                    } else if this.IsPathKey(normalizedKey) {
                        counts["paths"]++
                        result[key] := this.RedactPath(item)
                    } else if normalizedKey == "value"
                            && actionType == "text" {
                        counts["text_actions"]++
                        result[key] := this.RedactText(item)
                    } else if normalizedKey == "value"
                            && actionType == "run" {
                        counts["run_commands"]++
                        result[key] := "<redacted:command>"
                    } else if normalizedKey == "value"
                            && hasInvalidActionType {
                        counts["text_actions"]++
                        result[key] := "<redacted:value>"
                    } else if InStr(itemPath, ".variables.") {
                        counts["variable_values"]++
                        result[key] := "<redacted:variable>"
                    } else
                        result[key] := this.RedactValue(item, itemPath,
                            counts, state, depth + 1)
                }
                return result
            } finally state.Active.Delete(pointer)
        }
        if valueType == "Array" {
            pointer := ObjPtr(value)
            if state.Active.Has(pointer)
                return "<redacted:cycle>"
            state.Active[pointer] := true
            try {
                result := []
                for index, item in value
                    result.Push(this.RedactValue(item,
                        keyPath "[" index "]", counts, state, depth + 1))
                return result
            } finally state.Active.Delete(pointer)
        }
        if value is JsonBoolean
            return JsonBoolean(value.Value)
        if value is JsonNull
            return JsonNull()
        if IsObject(value)
            return "<redacted:unsupported-object>"
        return value
    }

    IsTitleKey(key) {
        return key == "title" || key == "window_title"
            || key == "active_window_title"
    }

    IsSensitiveTextKey(key) {
        return key == "focused_text"
    }

    IsPathKey(key) {
        return key == "path" || key == "file_path"
            || key == "device_path" || key == "script_path"
            || key == "process_path" || key == "directory"
    }

    IsRawCodeKey(key) {
        return key == "raw" || key == "raw_code" || key == "code"
            || key == "mapping_code" || key == "script_text"
    }

    RedactTitle(value) {
        if IsObject(value)
            return "<redacted:title>"
        text := String(value)
        return text == "" ? "" : "<redacted:title length=" StrLen(text) ">"
    }

    RedactText(value) {
        if IsObject(value)
            return "<redacted:text>"
        text := String(value)
        return text == "" ? "" : "<redacted:text length=" StrLen(text) ">"
    }

    RedactPath(value) {
        if IsObject(value)
            return "<redacted:path>"
        text := String(value)
        if text == ""
            return ""
        fileName := ""
        try SplitPath(text, &fileName)
        digest := SubStr(StrLower(Sha256.HexText(text)), 1, 16)
        return Map("name", fileName, "sha256_prefix", digest)
    }
}
