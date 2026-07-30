; 跨 Reload 保存映射区域与显示设置的撤销/重做记录。

class PersistentHistoryService {
    static Signature := "KEY_MOUSE_REMAPPER_HISTORY_V2"
    static LegacyBase64Signature := "SHORTCUT_REMAPPER_HISTORY_V2"
    static LegacySignature := "SHORTCUT_REMAPPER_HISTORY_V1"
    static MaximumNotificationBytes := 64 * 1024
    static MaximumNotificationCharacters := 16 * 1024
    static MaximumEntries := 1000
    static MaximumStorageBytes := 256 * 1024 * 1024

    __New(historyPath, notificationPath, maxEntries := 20,
            maxStorageBytes := 8 * 1024 * 1024) {
        this.HistoryPath := CrossProcessWriteLock.NormalizePath(historyPath)
        this.NotificationPath := CrossProcessWriteLock.NormalizePath(
            notificationPath)
        if StrLower(this.HistoryPath) == StrLower(this.NotificationPath)
            throw ValueError("操作历史与通知路径不能相同。")
        if Type(maxEntries) != "Integer" || maxEntries < 1
                || maxEntries > PersistentHistoryService.MaximumEntries
            throw ValueError("操作历史容量必须是 1 到 "
                PersistentHistoryService.MaximumEntries " 的整数。")
        if Type(maxStorageBytes) != "Integer" || maxStorageBytes < 4096
                || maxStorageBytes
                    > PersistentHistoryService.MaximumStorageBytes
            throw ValueError("操作历史存储上限必须是 4096 到 "
                PersistentHistoryService.MaximumStorageBytes " 的整数字节值。")
        this.MaxEntries := maxEntries
        this.MaxStorageBytes := maxStorageBytes
        this.UndoEntries := []
        this.RedoEntries := []
        this.Busy := false
        this.LoadWarning := ""
        this.Load()
    }

    Commit(kind, beforeState, afterState, action) {
        if this.Busy || String(beforeState) == String(afterState)
            return false
        kind := this.NormalizeKind(kind)
        normalizedAction := this.NormalizeAction(action)
        writeLease := CrossProcessWriteLock.Acquire(this.HistoryPath)
        try {
            this.LoadLocked()
            nextUndo := this.CloneStack(this.UndoEntries)
            nextRedo := []
            nextUndo.Push({
                Kind: kind, Before: String(beforeState),
                After: String(afterState), Action: normalizedAction,
                Label: this.GetCompatibilityLabel(normalizedAction)
            })
            while nextUndo.Length > this.MaxEntries
                nextUndo.RemoveAt(1)
            this.PersistStacksLocked(nextUndo, nextRedo)
            this.UndoEntries := nextUndo
            this.RedoEntries := nextRedo
            return true
        } finally writeLease.Release()
    }

    Undo(applyCallback, &appliedEntry := "") {
        appliedEntry := ""
        if this.Busy
            return false
        this.Busy := true
        writeLease := ""
        try {
            writeLease := CrossProcessWriteLock.Acquire(this.HistoryPath)
            this.LoadLocked()
            if !this.UndoEntries.Length
                return false
            historyEntry := this.UndoEntries[this.UndoEntries.Length]
            nextUndo := this.CloneStack(this.UndoEntries)
            nextRedo := this.CloneStack(this.RedoEntries)
            nextUndo.Pop()
            nextRedo.Push(historyEntry)
            applyCallback.Call(historyEntry.Before, historyEntry.After,
                historyEntry.Kind)
            try this.PersistStacksLocked(nextUndo, nextRedo)
            catch as persistError {
                this.RollBackAppliedState(applyCallback, historyEntry.After,
                    historyEntry.Before, historyEntry.Kind, persistError)
                throw persistError
            }
            this.UndoEntries := nextUndo
            this.RedoEntries := nextRedo
            appliedEntry := historyEntry
            return true
        } finally {
            if IsObject(writeLease)
                writeLease.Release()
            this.Busy := false
        }
    }

    Redo(applyCallback, &appliedEntry := "") {
        appliedEntry := ""
        if this.Busy
            return false
        this.Busy := true
        writeLease := ""
        try {
            writeLease := CrossProcessWriteLock.Acquire(this.HistoryPath)
            this.LoadLocked()
            if !this.RedoEntries.Length
                return false
            historyEntry := this.RedoEntries[this.RedoEntries.Length]
            nextUndo := this.CloneStack(this.UndoEntries)
            nextRedo := this.CloneStack(this.RedoEntries)
            nextRedo.Pop()
            nextUndo.Push(historyEntry)
            applyCallback.Call(historyEntry.After, historyEntry.Before,
                historyEntry.Kind)
            try this.PersistStacksLocked(nextUndo, nextRedo)
            catch as persistError {
                this.RollBackAppliedState(applyCallback, historyEntry.Before,
                    historyEntry.After, historyEntry.Kind, persistError)
                throw persistError
            }
            this.UndoEntries := nextUndo
            this.RedoEntries := nextRedo
            appliedEntry := historyEntry
            return true
        } finally {
            if IsObject(writeLease)
                writeLease.Release()
            this.Busy := false
        }
    }

    CanUndo() => !this.Busy && this.UndoEntries.Length > 0
    CanRedo() => !this.Busy && this.RedoEntries.Length > 0

    CloneStack(entries) {
        clone := []
        for historyEntry in entries
            clone.Push(historyEntry)
        return clone
    }

    RollBackAppliedState(applyCallback, desiredState, expectedState, kind,
            persistError) {
        try applyCallback.Call(desiredState, expectedState, kind)
        catch as rollbackError {
            throw Error("历史记录保存失败，且状态回滚失败："
                persistError.Message "；" rollbackError.Message)
        }
    }

    Load() {
        readLease := CrossProcessWriteLock.Acquire(this.HistoryPath)
        try return this.LoadLocked()
        finally readLease.Release()
    }

    LoadLocked() {
        this.UndoEntries := []
        this.RedoEntries := []
        this.LoadWarning := ""
        if !FileExist(this.HistoryPath)
            return true
        try content := BoundedFileReader.ReadUtf8(this.HistoryPath,
            this.MaxStorageBytes, this.MaxStorageBytes, "操作历史")
        catch as readError {
            if readError is BoundedFileLimitError {
                this.QuarantineCorruptHistory(readError.Message)
                return
            }
            this.LoadWarning := "无法读取操作历史：" readError.Message
            return
        }
        lines := StrSplit(StrReplace(content, "`r"), "`n")
        if !lines.Length
            return
        encoding := lines[1] == PersistentHistoryService.Signature
                || lines[1]
                    == PersistentHistoryService.LegacyBase64Signature
            ? "base64" : (lines[1] == PersistentHistoryService.LegacySignature
                ? "hex" : "")
        if encoding == "" {
            this.QuarantineCorruptHistory("无法识别操作历史格式。")
            return
        }
        if lines.Length < 2
            return
        try {
            Loop lines.Length - 1 {
                line := lines[A_Index + 1]
                if line == ""
                    continue
                parts := StrSplit(line, "|")
                if parts.Length != 6 || parts[6] != "1"
                        || (parts[1] != "U" && parts[1] != "R")
                    throw Error("操作历史记录结构损坏。")
                action := this.DeserializeAction(
                    this.Decode(parts[3], encoding), encoding)
                historyEntry := {
                    Kind: this.NormalizeKind(parts[2]), Action: action,
                    Label: this.GetCompatibilityLabel(action),
                    Before: this.Decode(parts[4], encoding),
                    After: this.Decode(parts[5], encoding)
                }
                target := parts[1] == "U" ? this.UndoEntries : this.RedoEntries
                target.Push(historyEntry)
                while target.Length > this.MaxEntries
                    target.RemoveAt(1)
            }
        } catch as parseError {
            this.UndoEntries := []
            this.RedoEntries := []
            this.QuarantineCorruptHistory(parseError.Message)
        }
        return this.LoadWarning == ""
    }

    Persist() {
        writeLease := CrossProcessWriteLock.Acquire(this.HistoryPath)
        try this.PersistStacksLocked(this.UndoEntries, this.RedoEntries)
        finally writeLease.Release()
    }

    PersistStacksLocked(undoEntries, redoEntries) {
        this.EnforceStorageLimit(undoEntries, redoEntries)
        text := this.BuildPersistText(undoEntries, redoEntries)
        this.WriteAtomic(this.HistoryPath, text)
    }

    BuildPersistText(undoEntries, redoEntries) {
        text := PersistentHistoryService.Signature "`n"
        for historyEntry in undoEntries
            text .= this.SerializeEntry("U", historyEntry)
        for historyEntry in redoEntries
            text .= this.SerializeEntry("R", historyEntry)
        return text
    }

    EnforceStorageLimit(undoEntries, redoEntries) {
        Loop {
            text := this.BuildPersistText(undoEntries, redoEntries)
            if StrPut(text, "UTF-8") - 1 <= this.MaxStorageBytes
                return true
            if undoEntries.Length > 1 {
                undoEntries.RemoveAt(1)
                continue
            }
            if redoEntries.Length > 0 && undoEntries.Length > 0 {
                redoEntries.RemoveAt(1)
                continue
            }
            if redoEntries.Length > 1 {
                redoEntries.RemoveAt(1)
                continue
            }
            throw Error("单条操作历史超过存储容量限制。")
        }
    }

    SerializeEntry(stackName, entry) {
        ; 末尾版本字段让格式以后可扩展，同时保持每条记录严格单行。
        action := entry.HasOwnProp("Action")
            ? entry.Action : this.NormalizeAction(entry.Label)
        return stackName "|" this.NormalizeKind(entry.Kind) "|" this.Encode(
            this.SerializeAction(action)) "|"
            . this.Encode(entry.Before) "|" this.Encode(entry.After) "|1`n"
    }

    NormalizeAction(action) {
        if !IsObject(action) || !action.HasOwnProp("Kind")
            return {Kind: "legacy", Target: String(action), Fields: []}
        fields := []
        if action.HasOwnProp("Fields") && Type(action.Fields) == "Array" {
            for field in action.Fields
                fields.Push(String(field))
        }
        return {
            Kind: String(action.Kind),
            Target: action.HasOwnProp("Target") ? String(action.Target) : "",
            Fields: fields
        }
    }

    NormalizeKind(kind) {
        kind := Trim(String(kind))
        if !RegExMatch(kind, "^[A-Za-z0-9._-]{1,32}$")
            throw ValueError("操作历史类型格式无效。")
        return kind
    }

    SerializeAction(action) {
        action := this.NormalizeAction(action)
        fieldsText := ""
        for index, field in action.Fields
            fieldsText .= (index > 1 ? Chr(30) : "") field
        return "A2|" this.Encode(action.Kind) "|" this.Encode(action.Target)
            . "|" this.Encode(fieldsText)
    }

    DeserializeAction(serialized, encoding := "base64") {
        serialized := String(serialized)
        parts := StrSplit(serialized, "|")
        if parts.Length != 4 || parts[1] != "A2"
            return this.NormalizeAction(serialized)
        kind := this.Decode(parts[2], encoding)
        target := this.Decode(parts[3], encoding)
        fieldsText := this.Decode(parts[4], encoding)
        fields := fieldsText == "" ? [] : StrSplit(fieldsText, Chr(30))
        return this.NormalizeAction({Kind: kind, Target: target, Fields: fields})
    }

    GetCompatibilityLabel(action) {
        action := this.NormalizeAction(action)
        return action.Target
    }

    Encode(text) {
        text := String(text)
        if text == ""
            return ""
        byteCount := StrPut(text, "UTF-8") - 1
        byteBuffer := Buffer(byteCount + 1, 0)
        StrPut(text, byteBuffer, "UTF-8")
        characterCount := 0
        flags := 0x40000001 ; CRYPT_STRING_BASE64 | CRYPT_STRING_NOCRLF
        if !DllCall("crypt32\CryptBinaryToStringW", "Ptr", byteBuffer.Ptr,
                "UInt", byteCount, "UInt", flags, "Ptr", 0,
                "UInt*", &characterCount, "Int")
            throw Error("无法编码操作历史。")
        encodedBuffer := Buffer(characterCount * 2, 0)
        if !DllCall("crypt32\CryptBinaryToStringW", "Ptr", byteBuffer.Ptr,
                "UInt", byteCount, "UInt", flags, "Ptr", encodedBuffer.Ptr,
                "UInt*", &characterCount, "Int")
            throw Error("无法编码操作历史。")
        return StrGet(encodedBuffer, "UTF-16")
    }

    Decode(encoded, encoding := "base64") {
        if encoding == "hex"
            return this.DecodeHex(encoded)
        encoded := String(encoded)
        if encoded == ""
            return ""
        byteCount := 0
        if !DllCall("crypt32\CryptStringToBinaryW", "Str", encoded,
                "UInt", 0, "UInt", 0x1, "Ptr", 0, "UInt*", &byteCount,
                "Ptr", 0, "Ptr", 0, "Int")
            throw Error("历史记录编码损坏。")
        byteBuffer := Buffer(byteCount + 1, 0)
        if !DllCall("crypt32\CryptStringToBinaryW", "Str", encoded,
                "UInt", 0, "UInt", 0x1, "Ptr", byteBuffer.Ptr,
                "UInt*", &byteCount, "Ptr", 0, "Ptr", 0, "Int")
            throw Error("历史记录编码损坏。")
        return StrGet(byteBuffer, byteCount, "UTF-8")
    }

    DecodeHex(encoded) {
        if Mod(StrLen(encoded), 2)
            throw Error("历史记录编码损坏。")
        byteCount := StrLen(encoded) // 2
        byteBuffer := Buffer(byteCount + 1, 0)
        Loop byteCount
            NumPut("UChar", Integer("0x" SubStr(encoded, A_Index * 2 - 1, 2)),
                byteBuffer, A_Index - 1)
        return StrGet(byteBuffer, byteCount, "UTF-8")
    }

    SetPendingNotification(text) {
        text := String(text)
        if StrLen(text) > PersistentHistoryService.MaximumNotificationCharacters
            throw Error("待显示通知超过字符上限。")
        if StrPut(text, "UTF-8") - 1
                > PersistentHistoryService.MaximumNotificationBytes
            throw Error("待显示通知超过字节上限。")
        writeLease := CrossProcessWriteLock.Acquire(this.NotificationPath)
        try this.WriteAtomic(this.NotificationPath, text)
        finally writeLease.Release()
    }

    ConsumePendingNotification() {
        notificationLease := CrossProcessWriteLock.Acquire(
            this.NotificationPath)
        try {
            if !FileExist(this.NotificationPath)
                return ""
            claimedPath := this.NotificationPath ".consuming-" A_TickCount "-"
                . Format("{:08X}", Random(0, 0xFFFFFFFF))
            try FileMove(this.NotificationPath, claimedPath)
            catch
                return ""
        } finally notificationLease.Release()
        try {
            try text := BoundedFileReader.ReadUtf8(claimedPath,
                PersistentHistoryService.MaximumNotificationBytes,
                PersistentHistoryService.MaximumNotificationCharacters,
                "待显示通知")
            catch
                return ""
            return text
        }
        finally {
            if FileExist(claimedPath)
                try FileDelete(claimedPath)
        }
    }

    QuarantineCorruptHistory(reason) {
        this.LoadWarning := "操作历史已损坏并被隔离：" reason
        if !FileExist(this.HistoryPath)
            return false
        quarantinePath := this.HistoryPath ".corrupt-" A_NowUTC "-"
            . Format("{:08X}", Random(0, 0xFFFFFFFF))
        try {
            FileMove(this.HistoryPath, quarantinePath)
            return true
        }
        return false
    }

    WriteAtomic(path, text) {
        directory := ""
        SplitPath(path, , &directory)
        if directory != "" && !DirExist(directory)
            DirCreate(directory)
        temporaryPath := path ".tmp-" A_TickCount "-"
            . Format("{:08X}", Random(0, 0xFFFFFFFF))
        output := ""
        try {
            output := FileOpen(temporaryPath, "w", "UTF-8-RAW")
            if !IsObject(output)
                throw Error("无法写入操作历史。")
            output.Write(text)
            output.Close()
            output := ""
            FileMove(temporaryPath, path, 1)
        }
        catch as writeError {
            if IsObject(output)
                try output.Close()
            if FileExist(temporaryPath)
                try FileDelete(temporaryPath)
            throw writeError
        }
    }
}
