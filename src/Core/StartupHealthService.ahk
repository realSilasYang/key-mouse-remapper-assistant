class StartupHealthService {
    static Schema := 1
    static RecoverySchema := 1
    static MaximumStateBytes := 128 * 1024
    static MaximumRecoveryBytes := 16 * 1024 * 1024

    __New(statePath, recoveryPath) {
        statePath := Trim(String(statePath))
        recoveryPath := Trim(String(recoveryPath))
        if statePath == "" || recoveryPath == ""
            throw ValueError("启动健康状态路径不能为空。")
        this.StatePath := CrossProcessWriteLock.NormalizePath(statePath)
        this.RecoveryPath := CrossProcessWriteLock.NormalizePath(recoveryPath)
        this.SessionId := ""
        this.SafeMode := false
        this.RestartPrepared := false
    }

    Begin(scriptPath) {
        stateLease := CrossProcessWriteLock.Acquire(this.StatePath)
        try {
            this.RestartPrepared := false
            state := this.ReadState()
            failures := state["consecutive_failures"]
            if this.IsUncleanStatus(state["status"])
                failures := Min(1000, failures + 1)
            this.SessionId := FormatTime(A_NowUTC, "yyyyMMddHHmmss") "-"
                . Format("{:08X}", Random(0, 0xFFFFFFFF))
            this.SafeMode := failures >= 3
            nextState := Map(
                "schema", StartupHealthService.Schema,
                "session_id", this.SessionId,
                "status", this.SafeMode ? "safe_mode" : "starting",
                "consecutive_failures", failures,
                "script_path", CrossProcessWriteLock.NormalizePath(scriptPath),
                "started_at", this.Timestamp(),
                "updated_at", this.Timestamp(),
                "last_error", state["last_error"],
                "last_stable_at", state["last_stable_at"])
            this.WriteState(nextState)
            return {SafeMode: this.SafeMode,
                ConsecutiveFailures: failures,
                SessionId: this.SessionId,
                LastError: nextState["last_error"]}
        } finally stateLease.Release()
    }

    MarkRunning() {
        return this.UpdateCurrentSession("running", "", false)
    }

    RecordStartupFailure(message) {
        stateLease := CrossProcessWriteLock.Acquire(this.StatePath)
        try {
            state := this.ReadState()
            if state["session_id"] != this.SessionId
                return {SafeMode: this.SafeMode,
                    ConsecutiveFailures: state["consecutive_failures"]}
            if state["status"] != "failed"
                state["consecutive_failures"] := Min(1000,
                    state["consecutive_failures"] + 1)
            state["status"] := "failed"
            state["last_error"] := SubStr(String(message), 1, 4000)
            state["updated_at"] := this.Timestamp()
            this.SafeMode := state["consecutive_failures"] >= 3
            if this.SafeMode
                state["status"] := "safe_mode"
            this.WriteState(state)
            return {SafeMode: this.SafeMode,
                ConsecutiveFailures: state["consecutive_failures"]}
        } finally stateLease.Release()
    }

    MarkStable(mappingBody) {
        mappingBody := String(mappingBody)
        payloadDigest := Sha256.HexText(mappingBody)
        recovery := Map(
            "schema", StartupHealthService.RecoverySchema,
            "created_at", this.Timestamp(),
            "mapping_body", mappingBody,
            "sha256", payloadDigest)
        recoveryText := JsonCodec.Stringify(recovery, true, true) "`r`n"
        if StrPut(recoveryText, "UTF-8") - 1
                > StartupHealthService.MaximumRecoveryBytes
            throw Error("最后正常配置超过存储上限。")
        combinedLease := CrossProcessWriteLock.AcquireMany([
            this.StatePath, this.RecoveryPath])
        try {
            state := this.ReadState()
            if state["session_id"] != this.SessionId
                throw Error("启动健康会话已变化，未更新最后正常配置。")
            this.WriteAtomic(this.RecoveryPath, recoveryText,
                StartupHealthService.MaximumRecoveryBytes)
            state["status"] := "stable"
            state["consecutive_failures"] := 0
            state["last_error"] := ""
            state["last_stable_at"] := recovery["created_at"]
            state["updated_at"] := this.Timestamp()
            this.WriteState(state)
            this.SafeMode := false
            return true
        } finally combinedLease.Release()
    }

    PrepareRestart() {
        prepared := this.UpdateCurrentSession("planned_restart", "", false)
        this.RestartPrepared := !!prepared
        return prepared
    }

    MarkClean() {
        if this.RestartPrepared
            return true
        stateLease := CrossProcessWriteLock.Acquire(this.StatePath)
        try {
            state := this.ReadState()
            if state["session_id"] != this.SessionId
                return false
            state["status"] := "clean"
            state["consecutive_failures"] := 0
            state["last_error"] := ""
            state["updated_at"] := this.Timestamp()
            this.WriteState(state)
            return true
        } finally stateLease.Release()
    }

    HasRecovery() {
        try return IsObject(this.ReadRecovery())
        catch
            return false
    }

    Restore(repository) {
        recovery := this.ReadRecovery()
        mappingLease := CrossProcessWriteLock.Acquire(repository.ScriptPath)
        try {
            beforeMapping := repository.ReadRegionBody()
            try {
                repository.WriteRegionBody(recovery["mapping_body"],
                    beforeMapping)
            } catch as restoreError {
                rollbackFailures := []
                try {
                    currentMapping := repository.ReadRegionBody()
                    if currentMapping != beforeMapping
                        repository.WriteRegionBody(beforeMapping,
                            currentMapping)
                } catch as mappingRollbackError
                    rollbackFailures.Push(mappingRollbackError.Message)
                if rollbackFailures.Length
                    throw Error("最后正常配置恢复失败，且回滚不完整："
                        restoreError.Message "；" this.Join(
                            rollbackFailures, "；"))
                throw restoreError
            }
            return true
        } finally mappingLease.Release()
    }

    ReadRecovery() {
        readLease := CrossProcessWriteLock.Acquire(this.RecoveryPath)
        try return this.ReadRecoveryLocked()
        finally readLease.Release()
    }

    ReadRecoveryLocked() {
        if !FileExist(this.RecoveryPath)
            throw Error("没有可恢复的最后正常配置。")
        document := JsonCodec.Parse(BoundedFileReader.ReadUtf8(
            this.RecoveryPath, StartupHealthService.MaximumRecoveryBytes,
            StartupHealthService.MaximumRecoveryBytes, "最后正常配置"))
        if Type(document) != "Map"
                || (document.Count != 4 && document.Count != 5)
                || (document.Count == 5 && !document.Has("profile_snapshot"))
                || !document.Has("schema")
                || Type(document["schema"]) != "Integer"
                || document["schema"] != StartupHealthService.RecoverySchema
                || !document.Has("mapping_body")
                || Type(document["mapping_body"]) != "String"
                || !document.Has("created_at")
                || Type(document["created_at"]) != "String"
                || !RegExMatch(document["created_at"],
                    "^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$")
                || !document.Has("sha256")
                || Type(document["sha256"]) != "String"
                || !RegExMatch(document["sha256"], "i)^[0-9A-F]{64}$")
            throw Error("最后正常配置格式无效。")
        mappingBody := document["mapping_body"]
        isLegacyRecovery := document.Has("profile_snapshot")
        if isLegacyRecovery && Type(document["profile_snapshot"]) != "String"
            throw Error("最后正常配置格式无效。")
        expectedDigest := isLegacyRecovery
            ? Sha256.HexText(mappingBody Chr(30) document["profile_snapshot"])
            : Sha256.HexText(mappingBody)
        if StrUpper(document["sha256"]) != expectedDigest
            throw Error("最后正常配置完整性校验失败。")
        return Map("mapping_body", mappingBody,
            "created_at", document["created_at"])
    }

    UpdateCurrentSession(status, message, resetFailures) {
        stateLease := CrossProcessWriteLock.Acquire(this.StatePath)
        try {
            state := this.ReadState()
            if state["session_id"] != this.SessionId
                return false
            state["status"] := String(status)
            state["last_error"] := SubStr(String(message), 1, 4000)
            if resetFailures
                state["consecutive_failures"] := 0
            state["updated_at"] := this.Timestamp()
            this.WriteState(state)
            return true
        } finally stateLease.Release()
    }

    ReadState() {
        if !FileExist(this.StatePath)
            return this.DefaultState()
        try document := JsonCodec.Parse(BoundedFileReader.ReadUtf8(
            this.StatePath, StartupHealthService.MaximumStateBytes,
            StartupHealthService.MaximumStateBytes, "启动健康状态"))
        catch as parseError
            return this.RecoverCorruptState(
                "启动健康状态无法解析：" parseError.Message)
        if Type(document) != "Map"
                || (document.Count != 9 && document.Count != 10)
                || (document.Count == 10 && !document.Has("profile_path"))
                || !document.Has("schema")
                || Type(document["schema"]) != "Integer"
                || document["schema"] != StartupHealthService.Schema
            return this.RecoverCorruptState("启动健康状态格式无效。")
        state := this.DefaultState()
        for fieldName in ["session_id", "status", "script_path",
                "started_at", "updated_at", "last_error",
                "last_stable_at"] {
            if !document.Has(fieldName)
                    || Type(document[fieldName]) != "String"
                return this.RecoverCorruptState(
                    "启动健康状态缺少有效字段：" fieldName)
            state[fieldName] := document[fieldName]
        }
        if !document.Has("consecutive_failures")
                || Type(document["consecutive_failures"]) != "Integer"
                || document["consecutive_failures"] < 0
                || document["consecutive_failures"] > 1000
            return this.RecoverCorruptState(
                "启动健康状态的连续失败计数无效。")
        if !this.IsKnownStatus(state["status"])
            return this.RecoverCorruptState("启动健康状态值无效。")
        state["consecutive_failures"] := document["consecutive_failures"]
        return state
    }

    RecoverCorruptState(reason) {
        quarantinePath := this.QuarantineCorruptState()
        state := this.DefaultState()
        state["status"] := "running"
        state["last_error"] := SubStr(String(reason)
            . (quarantinePath == "" ? ""
                : " 原文件已隔离到 " quarantinePath), 1, 4000)
        return state
    }

    QuarantineCorruptState() {
        if !FileExist(this.StatePath)
            return ""
        quarantinePath := this.StatePath ".corrupt-"
            . FormatTime(A_NowUTC, "yyyyMMddHHmmss") "-"
            . Format("{:08X}", Random(0, 0xFFFFFFFF))
        FileMove(this.StatePath, quarantinePath)
        return quarantinePath
    }

    DefaultState() {
        return Map("schema", StartupHealthService.Schema,
            "session_id", "", "status", "clean",
            "consecutive_failures", 0, "script_path", "",
            "started_at", "", "updated_at", "",
            "last_error", "", "last_stable_at", "")
    }

    WriteState(state) {
        text := JsonCodec.Stringify(state, true, true) "`r`n"
        return this.WriteAtomic(this.StatePath, text,
            StartupHealthService.MaximumStateBytes)
    }

    WriteAtomic(path, text, maximumBytes) {
        if StrPut(text, "UTF-8") - 1 > maximumBytes
            throw Error("恢复状态超过写入上限。")
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
                throw Error("无法写入启动恢复状态。")
            output.Write(text)
            output.Close()
            output := ""
            FileMove(temporaryPath, path, 1)
        } catch as writeError {
            if IsObject(output)
                try output.Close()
            if FileExist(temporaryPath)
                try FileDelete(temporaryPath)
            throw writeError
        }
        return true
    }

    IsUncleanStatus(status) {
        status := StrLower(String(status))
        return status == "starting" || status == "running"
            || status == "stable"
    }

    IsKnownStatus(status) {
        status := StrLower(String(status))
        return status == "clean" || status == "starting"
            || status == "running" || status == "stable"
            || status == "failed" || status == "safe_mode"
            || status == "planned_restart"
    }

    Timestamp() => FormatTime(A_NowUTC, "yyyy-MM-dd'T'HH:mm:ss'Z'")

    Join(values, separator) {
        result := ""
        for index, value in values
            result .= (index > 1 ? separator : "") String(value)
        return result
    }
}
