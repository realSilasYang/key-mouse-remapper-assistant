class CrashRecoveryService {
    static Schema := 1
    static MaximumEntries := 128
    static MaximumFileBytes := 512 * 1024
    static MaximumEntryBytes := 64 * 1024
    static DefaultStaleAgeSeconds := 10 * 60

    __New(journalPath,
            staleAgeSeconds := CrashRecoveryService.DefaultStaleAgeSeconds) {
        journalPath := Trim(String(journalPath))
        if journalPath == ""
            throw ValueError("崩溃诊断日志路径不能为空。")
        this.JournalPath := CrossProcessWriteLock.NormalizePath(journalPath)
        if Type(staleAgeSeconds) != "Integer" || staleAgeSeconds < 1
            throw ValueError("事务残留安全期限必须是正整数秒。")
        this.StaleAgeSeconds := staleAgeSeconds
    }

    CleanupStaleTransactions(targetPaths, nowTimestamp := "") {
        if Type(targetPaths) != "Array"
            throw TypeError("事务清理目标必须是数组。")
        if nowTimestamp == ""
            nowTimestamp := A_Now
        else if Type(nowTimestamp) != "String"
                || !RegExMatch(nowTimestamp, "^\d{14}$")
            throw ValueError("事务清理时间必须是 yyyyMMddHHmmss。")
        try FormatTime(nowTimestamp, "yyyyMMddHHmmss")
        catch
            throw ValueError("事务清理时间无效。")
        cleanupReport := {Removed: [], SkippedRecent: [], Failures: []}
        patterns := []
        seenPatterns := Map()
        for targetPathValue in targetPaths {
            normalizedTargetPath := CrossProcessWriteLock.NormalizePath(
                targetPathValue)
            this.AddCleanupPattern(patterns, seenPatterns,
                normalizedTargetPath ".tmp-*")
            if RegExMatch(normalizedTargetPath, "i)\.ahk$")
                this.AddCleanupPattern(patterns, seenPatterns,
                    normalizedTargetPath ".codex-*")
        }
        for pattern in patterns {
            patternPrefix := SubStr(pattern, 1, -1)
            Loop Files, pattern, "F" {
                candidatePath := A_LoopFileFullPath
                try {
                    normalizedCandidate := CrossProcessWriteLock.NormalizePath(
                        candidatePath)
                    if !this.StartsWithPath(normalizedCandidate,
                            patternPrefix)
                        throw Error("事务临时文件超出允许的路径前缀。")
                    attributes := FileGetAttrib(normalizedCandidate)
                    if InStr(attributes, "L")
                        throw Error("不清理符号链接事务文件。")
                    modifiedAt := FileGetTime(normalizedCandidate, "M")
                    ageSeconds := DateDiff(nowTimestamp, modifiedAt,
                        "Seconds")
                    if ageSeconds < this.StaleAgeSeconds {
                        cleanupReport.SkippedRecent.Push(normalizedCandidate)
                        continue
                    }
                    FileDelete(normalizedCandidate)
                    cleanupReport.Removed.Push(normalizedCandidate)
                } catch as cleanupError {
                    cleanupReport.Failures.Push(Map(
                        "file_path", candidatePath,
                        "error", cleanupError.Message))
                }
            }
        }
        if cleanupReport.Removed.Length || cleanupReport.Failures.Length {
            data := Map(
                "removed_count", cleanupReport.Removed.Length,
                "skipped_recent_count", cleanupReport.SkippedRecent.Length,
                "failure_count", cleanupReport.Failures.Length,
                "removed_files", this.PathMaps(cleanupReport.Removed),
                "failures", cleanupReport.Failures)
            try this.Record("transaction_cleanup",
                cleanupReport.Failures.Length
                    ? "事务残留清理部分失败。"
                    : "已清理过期事务残留。", data)
        }
        return cleanupReport
    }

    Record(category, message, data := "") {
        category := Trim(String(category))
        message := SubStr(String(message), 1, 8192)
        if category == ""
            throw ValueError("崩溃诊断类别不能为空。")
        if data == ""
            data := Map()
        if Type(data) != "Map"
            throw TypeError("崩溃诊断数据必须是 Map。")
        entry := Map(
            "timestamp", this.Timestamp(),
            "category", SubStr(category, 1, 128),
            "message", message,
            "data", this.CloneJsonValue(data))
        entryText := JsonCodec.Stringify(entry, false, true)
        if StrPut(entryText, "UTF-8") - 1
                > CrashRecoveryService.MaximumEntryBytes
            throw Error("单条崩溃诊断超过大小上限。")
        writeLease := CrossProcessWriteLock.Acquire(this.JournalPath)
        try {
            readWarning := ""
            document := this.ReadDocumentLocked(&readWarning, true)
            entries := document["entries"]
            if readWarning != "" {
                entries.Push(Map(
                    "timestamp", this.Timestamp(),
                    "category", "journal_recovered",
                    "message", SubStr(readWarning, 1, 8192),
                    "data", Map()))
            }
            entries.Push(entry)
            while entries.Length > CrashRecoveryService.MaximumEntries
                entries.RemoveAt(1)
            document["updated_at"] := this.Timestamp()
            this.WriteBoundedDocument(document)
            return this.CloneJsonValue(entry)
        } finally writeLease.Release()
    }

    Snapshot(maximumEntries := CrashRecoveryService.MaximumEntries) {
        if Type(maximumEntries) != "Integer" || maximumEntries < 0
                || maximumEntries > CrashRecoveryService.MaximumEntries
            throw ValueError("崩溃诊断快照条目数必须是 0 到 "
                CrashRecoveryService.MaximumEntries " 的整数。")
        readLease := CrossProcessWriteLock.Acquire(this.JournalPath)
        try {
            readWarning := ""
            document := this.ReadDocumentLocked(&readWarning)
            if readWarning != ""
                throw Error(readWarning)
            entries := document["entries"]
            startIndex := Max(1, entries.Length - maximumEntries + 1)
            result := []
            if maximumEntries > 0 {
                Loop entries.Length - startIndex + 1
                    result.Push(this.CloneJsonValue(
                        entries[startIndex + A_Index - 1]))
            }
            return result
        } finally readLease.Release()
    }

    CreateDiagnosticSummary(maximumEntries := 32) {
        result := []
        for entry in this.Snapshot(maximumEntries) {
            message := String(entry["message"])
            result.Push(Map(
                "timestamp", entry["timestamp"],
                "category", entry["category"],
                "message_length", StrLen(message),
                "message_sha256_prefix", SubStr(
                    Sha256.HexText(message), 1, 16),
                "data", this.SummarizeDiagnosticData(entry["data"])))
        }
        return result
    }

    SummarizeDiagnosticData(value, keyName := "") {
        valueType := Type(value)
        if valueType == "Map" {
            result := Map()
            for key, item in value {
                normalizedKey := StrLower(String(key))
                if normalizedKey == "error" || normalizedKey == "message"
                        || InStr(normalizedKey, "_error") {
                    text := String(item)
                    result[key] := Map(
                        "length", StrLen(text),
                        "sha256_prefix", SubStr(Sha256.HexText(text), 1, 16))
                } else
                    result[key] := this.SummarizeDiagnosticData(item,
                        normalizedKey)
            }
            return result
        }
        if valueType == "Array" {
            result := []
            for item in value
                result.Push(this.SummarizeDiagnosticData(item, keyName))
            return result
        }
        if value is JsonBoolean
            return JsonBoolean(value.Value)
        if value is JsonNull
            return JsonNull()
        return IsObject(value) ? "<unsupported-object>" : value
    }

    AddCleanupPattern(patterns, seenPatterns, pattern) {
        normalizedKey := StrLower(String(pattern))
        if seenPatterns.Has(normalizedKey)
            return false
        seenPatterns[normalizedKey] := true
        patterns.Push(String(pattern))
        return true
    }

    StartsWithPath(path, prefix) {
        return StrCompare(SubStr(path, 1, StrLen(prefix)), prefix, false) == 0
    }

    PathMaps(paths) {
        result := []
        for path in paths
            result.Push(Map("file_path", path))
        return result
    }

    ReadDocumentLocked(&warning, quarantineInvalid := false) {
        warning := ""
        if !FileExist(this.JournalPath)
            return this.EmptyDocument()
        try document := JsonCodec.Parse(BoundedFileReader.ReadUtf8(
            this.JournalPath, CrashRecoveryService.MaximumFileBytes,
            CrashRecoveryService.MaximumFileBytes, "崩溃诊断日志"))
        catch as parseError {
            warning := this.CorruptJournalWarning(
                "原崩溃诊断日志无法解析：" parseError.Message,
                quarantineInvalid)
            return this.EmptyDocument()
        }
        if Type(document) != "Map" || document.Count != 3
                || !document.Has("schema")
                || Type(document["schema"]) != "Integer"
                || document["schema"] != CrashRecoveryService.Schema
                || !document.Has("updated_at")
                || Type(document["updated_at"]) != "String"
                || !this.IsTimestamp(document["updated_at"])
                || !document.Has("entries")
                || Type(document["entries"]) != "Array" {
            warning := this.CorruptJournalWarning(
                "原崩溃诊断日志格式无效", quarantineInvalid)
            return this.EmptyDocument()
        }
        if document["entries"].Length > CrashRecoveryService.MaximumEntries {
            warning := this.CorruptJournalWarning(
                "原崩溃诊断日志条目数量超过上限", quarantineInvalid)
            return this.EmptyDocument()
        }
        normalizedEntries := []
        for entry in document["entries"] {
            if !this.IsValidEntry(entry) {
                warning := this.CorruptJournalWarning(
                    "原崩溃诊断日志包含无效条目", quarantineInvalid)
                return this.EmptyDocument()
            }
            normalizedEntries.Push(entry)
        }
        document["entries"] := normalizedEntries
        return document
    }

    CorruptJournalWarning(reason, quarantineInvalid) {
        if !quarantineInvalid
            return String(reason) "。"
        quarantinePath := this.QuarantineCorruptJournal()
        return String(reason) "，原文件已隔离到 " quarantinePath
            . "，已从新文档继续记录。"
    }

    QuarantineCorruptJournal() {
        if !FileExist(this.JournalPath)
            throw Error("待隔离的崩溃诊断日志不存在。")
        quarantinePath := this.JournalPath ".corrupt-"
            . FormatTime(A_NowUTC, "yyyyMMddHHmmss") "-"
            . Format("{:08X}", Random(0, 0xFFFFFFFF))
        FileMove(this.JournalPath, quarantinePath)
        return quarantinePath
    }

    EmptyDocument() {
        return Map(
            "schema", CrashRecoveryService.Schema,
            "updated_at", this.Timestamp(),
            "entries", [])
    }

    IsValidEntry(entry) {
        if Type(entry) != "Map" || entry.Count != 4
                || !entry.Has("timestamp")
                || Type(entry["timestamp"]) != "String"
                || !this.IsTimestamp(entry["timestamp"])
                || !entry.Has("category")
                || Type(entry["category"]) != "String"
                || entry["category"] == "" || StrLen(entry["category"]) > 128
                || !entry.Has("message")
                || Type(entry["message"]) != "String"
                || StrLen(entry["message"]) > 8192
                || !entry.Has("data") || Type(entry["data"]) != "Map"
            return false
        try entryText := JsonCodec.Stringify(entry, false, true)
        catch
            return false
        return StrPut(entryText, "UTF-8") - 1
            <= CrashRecoveryService.MaximumEntryBytes
    }

    IsTimestamp(value) {
        return RegExMatch(value,
            "^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$") > 0
    }

    WriteBoundedDocument(document) {
        while true {
            text := JsonCodec.Stringify(document, true, true) "`r`n"
            if StrPut(text, "UTF-8") - 1
                    <= CrashRecoveryService.MaximumFileBytes
                break
            if document["entries"].Length <= 1
                throw Error("崩溃诊断日志超过写入上限。")
            document["entries"].RemoveAt(1)
        }
        return this.WriteAtomic(text)
    }

    WriteAtomic(text) {
        directory := ""
        SplitPath(this.JournalPath, , &directory)
        if directory != "" && !DirExist(directory)
            DirCreate(directory)
        temporaryPath := this.JournalPath ".tmp-" A_TickCount "-"
            . Format("{:08X}", Random(0, 0xFFFFFFFF))
        output := ""
        try {
            output := FileOpen(temporaryPath, "w", "UTF-8-RAW")
            if !IsObject(output)
                throw Error("无法写入崩溃诊断日志。")
            output.Write(text)
            output.Close()
            output := ""
            FileMove(temporaryPath, this.JournalPath, 1)
        } catch as writeError {
            if IsObject(output)
                try output.Close()
            if FileExist(temporaryPath)
                try FileDelete(temporaryPath)
            throw writeError
        }
        return true
    }

    CloneJsonValue(value) {
        return JsonCodec.Parse(JsonCodec.Stringify(value, false, true))
    }

    Timestamp() => FormatTime(A_NowUTC, "yyyy-MM-dd'T'HH:mm:ss'Z'")
}
