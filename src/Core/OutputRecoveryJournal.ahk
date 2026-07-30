class OutputRecoveryJournal {
    static Schema := 1
    static MaximumFileBytes := 128 * 1024
    static MaximumKeys := 128
    static MaximumKeyNameLength := 128

    __New(filePath) {
        filePath := Trim(String(filePath))
        if filePath == ""
            throw ValueError("输出恢复日志路径不能为空。")
        this.FilePath := CrossProcessWriteLock.NormalizePath(filePath)
    }

    Update(keyNames) {
        normalized := this.NormalizeKeys(keyNames)
        writeLease := CrossProcessWriteLock.Acquire(this.FilePath)
        try {
            return this.WriteKeysLocked(normalized)
        } finally writeLease.Release()
    }

    Recover(sendKeyUpCallback) {
        if !IsObject(sendKeyUpCallback)
            throw TypeError("输出恢复回调无效。")
        writeLease := CrossProcessWriteLock.Acquire(this.FilePath)
        try {
            try keys := this.ReadKeysLocked()
            catch as readError {
                quarantinePath := this.QuarantineCorruptJournal()
                detail := quarantinePath
                    ? "，原文件已隔离到 " quarantinePath : ""
                throw Error("输出恢复日志损坏" detail "："
                    readError.Message)
            }
            if !keys.Length
                return 0
            released := 0
            failures := []
            failedKeys := []
            for keyName in keys {
                try {
                    sendKeyUpCallback.Call(keyName)
                    released++
                } catch as releaseError {
                    failures.Push(keyName ": " releaseError.Message)
                    failedKeys.Push(keyName)
                }
            }
            if failures.Length {
                persistFailure := ""
                try this.WriteKeysLocked(failedKeys)
                catch as persistError
                    persistFailure := persistError.Message
                detail := "部分遗留输出按键无法释放："
                    . this.Join(failures, "；")
                if persistFailure != ""
                    detail .= "；无法更新恢复日志：" persistFailure
                throw Error(detail)
            }
            if FileExist(this.FilePath)
                FileDelete(this.FilePath)
            return released
        } finally writeLease.Release()
    }

    QuarantineCorruptJournal() {
        if !FileExist(this.FilePath)
            return ""
        quarantinePath := this.FilePath ".corrupt-"
            . FormatTime(A_NowUTC, "yyyyMMddHHmmss") "-"
            . Format("{:08X}", Random(0, 0xFFFFFFFF))
        FileMove(this.FilePath, quarantinePath)
        return quarantinePath
    }

    ReadKeys() {
        readLease := CrossProcessWriteLock.Acquire(this.FilePath)
        try return this.ReadKeysLocked()
        finally readLease.Release()
    }

    ReadKeysLocked() {
        if !FileExist(this.FilePath)
            return []
        document := JsonCodec.Parse(BoundedFileReader.ReadUtf8(this.FilePath,
            OutputRecoveryJournal.MaximumFileBytes,
            OutputRecoveryJournal.MaximumFileBytes, "输出恢复日志"))
        if Type(document) != "Map" || document.Count != 3
                || !document.Has("schema")
                || Type(document["schema"]) != "Integer"
                || document["schema"] != OutputRecoveryJournal.Schema
                || !document.Has("updated_at")
                || Type(document["updated_at"]) != "String"
                || !RegExMatch(document["updated_at"],
                    "^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$")
                || !document.Has("keys")
            throw Error("输出恢复日志格式无效。")
        return this.NormalizeKeys(document["keys"])
    }

    NormalizeKeys(keyNames) {
        if Type(keyNames) != "Array"
            throw TypeError("输出恢复按键必须是数组。")
        if keyNames.Length > OutputRecoveryJournal.MaximumKeys
            throw Error("输出恢复按键数量超过上限。")
        result := []
        seen := Map()
        for keyNameValue in keyNames {
            keyName := Trim(String(keyNameValue))
            if StrLen(keyName) > OutputRecoveryJournal.MaximumKeyNameLength
                    || !RegExMatch(keyName,
                    "i)^(?:[A-Z0-9_]+|vk[0-9A-F]{2}|sc[0-9A-F]{3})$")
                throw Error("输出恢复日志包含不安全的按键名称。")
            normalized := StrLower(keyName)
            if !seen.Has(normalized) {
                seen[normalized] := true
                result.Push(keyName)
            }
        }
        return result
    }

    WriteKeysLocked(normalizedKeys) {
        if !normalizedKeys.Length {
            if FileExist(this.FilePath)
                FileDelete(this.FilePath)
            return true
        }
        document := Map("schema", OutputRecoveryJournal.Schema,
            "updated_at", FormatTime(A_NowUTC,
                "yyyy-MM-dd'T'HH:mm:ss'Z'"), "keys", normalizedKeys)
        this.WriteAtomic(JsonCodec.Stringify(document, true, true)
            . "`r`n")
        return true
    }

    WriteAtomic(text) {
        if StrPut(text, "UTF-8") - 1
                > OutputRecoveryJournal.MaximumFileBytes
            throw Error("输出恢复日志超过写入上限。")
        directory := ""
        SplitPath(this.FilePath, , &directory)
        if directory != "" && !DirExist(directory)
            DirCreate(directory)
        temporaryPath := this.FilePath ".tmp-" A_TickCount "-"
            . Format("{:08X}", Random(0, 0xFFFFFFFF))
        output := ""
        try {
            output := FileOpen(temporaryPath, "w", "UTF-8-RAW")
            if !IsObject(output)
                throw Error("无法写入输出恢复日志。")
            output.Write(text)
            output.Close()
            output := ""
            FileMove(temporaryPath, this.FilePath, 1)
        } catch as writeError {
            if IsObject(output)
                try output.Close()
            if FileExist(temporaryPath)
                try FileDelete(temporaryPath)
            throw writeError
        }
        return true
    }

    Join(values, separator) {
        result := ""
        for index, value in values
            result .= (index > 1 ? separator : "") String(value)
        return result
    }
}
