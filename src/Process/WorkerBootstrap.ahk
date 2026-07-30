class WorkerBootstrap {
    static Schema := 1
    static MaximumFileBytes := 128 * 1024
    static MaximumEnvironmentEntries := 16
    static MaximumValueBytes := 32 * 1024
    static MaximumAgeMs := 10 * 60 * 1000
    static FutureToleranceMs := 30 * 1000
    static EntropyText := "KeyMouseRemapperAssistant.WorkerBootstrap.v1"

    static Create(directory, role, sessionId, environment) {
        directory := RTrim(Trim(String(directory)), "\/")
        role := StrLower(Trim(String(role)))
        sessionId := StrLower(Trim(String(sessionId)))
        if directory == ""
            throw ValueError("工作进程启动信封目录不能为空。")
        if !RegExMatch(role, "^[a-z][a-z0-9-]{1,31}$")
            throw ValueError("工作进程启动角色无效。")
        if !RegExMatch(sessionId, "^[0-9a-f]{32}$")
            throw ValueError("工作进程启动会话标识无效。")
        normalizedEnvironment := this.NormalizeEnvironment(environment)
        document := Map(
            "schema", WorkerBootstrap.Schema,
            "role", role,
            "session_id", sessionId,
            "created_at_ms", this.UnixTimeMilliseconds(),
            "environment", normalizedEnvironment)
        protectedBytes := ""
        try {
            protectedBytes := this.ProtectText(
                JsonCodec.Stringify(document, false, true))
            if protectedBytes.Size > WorkerBootstrap.MaximumFileBytes
                throw Error("工作进程启动信封超过大小上限。")
            if !DirExist(directory)
                DirCreate(directory)
            path := directory "\" role "-worker-bootstrap-" sessionId ".bin"
            this.WriteBytesAtomically(path, protectedBytes)
            return path
        } finally {
            if IsObject(protectedBytes)
                this.ZeroBuffer(protectedBytes)
        }
    }

    static ApplyFromArguments(arguments) {
        if Type(arguments) != "Array"
            throw TypeError("工作进程启动参数必须是数组。")
        bootstrapPath := ""
        index := 1
        while index <= arguments.Length {
            if arguments[index] == "--worker-bootstrap" {
                if bootstrapPath != ""
                    throw ValueError("工作进程启动信封参数不能重复。")
                if index == arguments.Length
                    throw ValueError("工作进程启动信封参数缺少路径。")
                bootstrapPath := String(arguments[index + 1])
                index += 2
                continue
            }
            index += 1
        }
        if bootstrapPath == ""
            return false
        this.LoadAndApply(bootstrapPath)
        return true
    }

    static LoadAndApply(path) {
        path := Trim(String(path))
        if path == ""
            throw ValueError("工作进程启动信封路径不能为空。")
        claimedPath := path ".claimed"
        if FileExist(claimedPath)
            throw Error("工作进程启动信封已被其他进程认领。")
        FileMove(path, claimedPath, false)
        accepted := false
        try {
            protectedBytes := BoundedFileReader.ReadBytes(claimedPath,
                WorkerBootstrap.MaximumFileBytes, "工作进程启动信封")
            if protectedBytes.Size <= 0
                throw Error("工作进程启动信封大小无效。")
            try plainText := this.UnprotectText(protectedBytes)
            finally this.ZeroBuffer(protectedBytes)
            try document := JsonCodec.Parse(plainText)
            finally plainText := ""
            normalizedEnvironment := this.ValidateDocument(document)
            savedEnvironment := Map()
            try {
                for name, value in normalizedEnvironment {
                    savedEnvironment[name] := EnvGet(name)
                    EnvSet(name, value)
                }
            } catch as environmentError {
                for name, previousValue in savedEnvironment
                    EnvSet(name, previousValue)
                throw environmentError
            }
            accepted := true
            return normalizedEnvironment.Count
        } finally {
            if accepted {
                if FileExist(claimedPath)
                    FileDelete(claimedPath)
            } else if FileExist(claimedPath) && !FileExist(path)
                FileMove(claimedPath, path, false)
        }
    }

    static ValidateDocument(document) {
        if Type(document) != "Map"
                || document.Count != 5
                || !document.Has("schema")
                || Type(document["schema"]) != "Integer"
                || document["schema"] != WorkerBootstrap.Schema
                || !document.Has("role")
                || Type(document["role"]) != "String"
                || !RegExMatch(document["role"],
                    "^[a-z][a-z0-9-]{1,31}$")
                || !document.Has("session_id")
                || Type(document["session_id"]) != "String"
                || !RegExMatch(document["session_id"],
                    "^[0-9a-f]{32}$")
                || !document.Has("created_at_ms")
                || Type(document["created_at_ms"]) != "Integer"
                || !document.Has("environment")
            throw Error("工作进程启动信封格式无效。")
        now := this.UnixTimeMilliseconds()
        createdAt := document["created_at_ms"]
        if createdAt > now + WorkerBootstrap.FutureToleranceMs
                || now - createdAt > WorkerBootstrap.MaximumAgeMs
            throw Error("工作进程启动信封已过期或时间无效。")
        environment := this.NormalizeEnvironment(document["environment"], true)
        if !environment.Has("KMR_WORKER_ROLE")
            throw Error("工作进程启动环境缺少 KMR_WORKER_ROLE。")
        expectedRole := environment["KMR_WORKER_ROLE"]
        if expectedRole != document["role"]
                || !environment.Has("KMR_IPC_SESSION_ID")
                || environment["KMR_IPC_SESSION_ID"]
                    != document["session_id"]
            throw Error("工作进程启动信封身份字段不一致。")
        return environment
    }

    static NormalizeEnvironment(environment, requireStringValues := false) {
        if Type(environment) != "Map"
            throw TypeError("工作进程启动环境必须是 Map。")
        if environment.Count < 5
                || environment.Count > WorkerBootstrap.MaximumEnvironmentEntries
            throw Error("工作进程启动环境条目数量无效。")
        required := ["KMR_IPC_PIPE_ID", "KMR_IPC_SESSION_ID",
            "KMR_IPC_SECRET", "KMR_PARENT_PROCESS_ID",
            "KMR_WORKER_ERROR_PATH"]
        normalized := Map()
        for name, value in environment {
            if requireStringValues && Type(value) != "String"
                throw Error("工作进程启动环境变量值必须是字符串。")
            name := String(name)
            value := String(value)
            if !RegExMatch(name, "^KMR_[A-Z0-9_]{1,60}$")
                throw Error("工作进程启动环境变量名称无效。")
            if StrPut(value, "UTF-8") - 1
                    > WorkerBootstrap.MaximumValueBytes
                throw Error("工作进程启动环境变量值超过大小上限。")
            normalized[name] := value
        }
        for name in required {
            if !normalized.Has(name) || normalized[name] == ""
                throw Error("工作进程启动环境缺少字段：" name)
        }
        if !RegExMatch(normalized["KMR_IPC_PIPE_ID"], "^[0-9a-f]{32}$")
                || !RegExMatch(normalized["KMR_IPC_SESSION_ID"],
                    "^[0-9a-f]{32}$")
                || !RegExMatch(normalized["KMR_IPC_SECRET"],
                    "^[0-9A-Fa-f]{64}$")
                || !RegExMatch(normalized["KMR_PARENT_PROCESS_ID"],
                    "^[1-9][0-9]{0,9}$")
            throw Error("工作进程启动环境的认证字段无效。")
        if Integer(normalized["KMR_PARENT_PROCESS_ID"]) > 0xFFFFFFFF
            throw Error("工作进程启动环境的父进程标识超出范围。")
        return normalized
    }

    static ProtectText(text) {
        textBytes := this.Utf8Buffer(text)
        entropyBytes := this.Utf8Buffer(WorkerBootstrap.EntropyText)
        inputBlob := this.CreateDataBlob(textBytes, textBytes.Size - 1)
        entropyBlob := this.CreateDataBlob(entropyBytes,
            entropyBytes.Size - 1)
        outputBlob := Buffer((A_PtrSize == 8 ? 8 : 4) + A_PtrSize, 0)
        try {
            if !DllCall("crypt32\CryptProtectData", "Ptr", inputBlob.Ptr,
                    "WStr", "KeyMouseRemapperAssistant worker bootstrap",
                    "Ptr", entropyBlob.Ptr, "Ptr", 0, "Ptr", 0,
                    "UInt", 0x1, "Ptr", outputBlob.Ptr, "Int")
                throw OSError(A_LastError, "无法加密工作进程启动信封。")
            return this.CopyLocalBlob(outputBlob)
        } finally {
            this.ZeroBuffer(textBytes)
            this.ZeroBuffer(entropyBytes)
        }
    }

    static UnprotectText(protectedBytes) {
        entropyBytes := this.Utf8Buffer(WorkerBootstrap.EntropyText)
        inputBlob := this.CreateDataBlob(protectedBytes, protectedBytes.Size)
        entropyBlob := this.CreateDataBlob(entropyBytes,
            entropyBytes.Size - 1)
        outputBlob := Buffer((A_PtrSize == 8 ? 8 : 4) + A_PtrSize, 0)
        descriptionPointer := 0
        plainBytes := ""
        terminated := ""
        try {
            if !DllCall("crypt32\CryptUnprotectData", "Ptr", inputBlob.Ptr,
                    "Ptr*", &descriptionPointer, "Ptr", entropyBlob.Ptr,
                    "Ptr", 0, "Ptr", 0, "UInt", 0x1,
                    "Ptr", outputBlob.Ptr, "Int")
                throw OSError(A_LastError, "无法解密工作进程启动信封。")
            plainBytes := this.CopyLocalBlob(outputBlob)
            terminated := Buffer(plainBytes.Size + 1, 0)
            if plainBytes.Size
                DllCall("ntdll\RtlMoveMemory", "Ptr", terminated.Ptr,
                    "Ptr", plainBytes.Ptr, "UPtr", plainBytes.Size)
            return StrGet(terminated, "UTF-8")
        } finally {
            if IsObject(plainBytes)
                this.ZeroBuffer(plainBytes)
            if IsObject(terminated)
                this.ZeroBuffer(terminated)
            this.ZeroBuffer(entropyBytes)
            if descriptionPointer
                DllCall("kernel32\LocalFree", "Ptr", descriptionPointer,
                    "Ptr")
        }
    }

    static CreateDataBlob(bytes, byteCount) {
        pointerOffset := A_PtrSize == 8 ? 8 : 4
        blob := Buffer(pointerOffset + A_PtrSize, 0)
        NumPut("UInt", byteCount, blob, 0)
        NumPut("Ptr", bytes.Ptr, blob, pointerOffset)
        return blob
    }

    static CopyLocalBlob(blob) {
        pointerOffset := A_PtrSize == 8 ? 8 : 4
        byteCount := NumGet(blob, 0, "UInt")
        pointer := NumGet(blob, pointerOffset, "Ptr")
        if !pointer || !byteCount
            throw Error("Windows 数据保护 API 返回了空数据。")
        result := Buffer(byteCount, 0)
        try DllCall("ntdll\RtlMoveMemory", "Ptr", result.Ptr,
            "Ptr", pointer, "UPtr", byteCount)
        finally {
            DllCall("ntdll\RtlZeroMemory", "Ptr", pointer,
                "UPtr", byteCount)
            DllCall("kernel32\LocalFree", "Ptr", pointer, "Ptr")
        }
        return result
    }

    static Utf8Buffer(text) {
        byteCount := StrPut(String(text), "UTF-8")
        byteBuffer := Buffer(byteCount, 0)
        StrPut(String(text), byteBuffer, "UTF-8")
        return byteBuffer
    }

    static ZeroBuffer(byteBuffer) {
        if byteBuffer.Size
            DllCall("ntdll\RtlZeroMemory", "Ptr", byteBuffer.Ptr,
                "UPtr", byteBuffer.Size)
        return true
    }

    static WriteBytesAtomically(path, bytes) {
        temporaryPath := path ".tmp-" A_TickCount "-"
            . Format("{:08X}", Random(0, 0xFFFFFFFF))
        output := ""
        try {
            output := FileOpen(temporaryPath, "w")
            if !IsObject(output)
                throw Error("无法写入工作进程启动信封。")
            output.RawWrite(bytes)
            output.Close()
            output := ""
            FileMove(temporaryPath, path, false)
        } catch as writeError {
            if IsObject(output)
                try output.Close()
            if FileExist(temporaryPath)
                try FileDelete(temporaryPath)
            throw writeError
        }
        return true
    }

    static Delete(path) {
        path := Trim(String(path))
        if path == ""
            return false
        deleted := false
        for candidate in [path, path ".claimed"] {
            if FileExist(candidate) {
                FileDelete(candidate)
                deleted := true
            }
        }
        return deleted
    }

    static UnixTimeMilliseconds() {
        fileTime := Buffer(8, 0)
        DllCall("kernel32\GetSystemTimeAsFileTime", "Ptr", fileTime.Ptr)
        return (NumGet(fileTime, 0, "UInt64")
            - 116444736000000000) // 10000
    }
}
