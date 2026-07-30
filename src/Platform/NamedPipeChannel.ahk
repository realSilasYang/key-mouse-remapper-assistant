class NamedPipeChannel {
    static MaximumMessageBytes := 64 * 1024
    static PipePrefix := "\\.\pipe\KeyMouseRemapperAssistant."

    static CreateServer(pipeId) {
        pipeName := this.BuildPipeName(pipeId)
        userSid := this.GetCurrentUserSid()
        securityDescriptor := 0
        securityAttributes := this.CreateSecurityAttributes(userSid,
            &securityDescriptor, &securitySddl)
        try {
            handle := DllCall("kernel32\CreateNamedPipeW",
                "WStr", pipeName,
                "UInt", 0x00000003 | 0x00080000,
                "UInt", 0x00000008 | 0x00000004 | 0x00000002
                    | 0x00000001,
                "UInt", 1,
                "UInt", NamedPipeChannel.MaximumMessageBytes,
                "UInt", NamedPipeChannel.MaximumMessageBytes,
                "UInt", 0,
                "Ptr", securityAttributes,
                "Ptr")
            if !handle || handle == -1
                throw OSError(A_LastError, "无法创建受限命名管道。")
            return NamedPipeChannel(handle, pipeName, true, userSid,
                securitySddl)
        } finally {
            if securityDescriptor
                DllCall("kernel32\LocalFree", "Ptr", securityDescriptor,
                    "Ptr")
        }
    }

    static ConnectClient(pipeId, timeoutMs := 5000) {
        pipeName := this.BuildPipeName(pipeId)
        if Type(timeoutMs) != "Integer" || timeoutMs < 0
                || timeoutMs > 0xFFFFFFFF
            throw ValueError("命名管道连接超时必须是有效的整数毫秒值。")
        if !DllCall("kernel32\WaitNamedPipeW", "WStr", pipeName,
                "UInt", timeoutMs, "Int")
            throw OSError(A_LastError, "等待输入引擎命名管道失败。")
        handle := DllCall("kernel32\CreateFileW", "WStr", pipeName,
            "UInt", 0x80000000 | 0x40000000,
            "UInt", 0, "Ptr", 0, "UInt", 3,
            "UInt", 0, "Ptr", 0, "Ptr")
        if !handle || handle == -1
            throw OSError(A_LastError, "无法连接输入引擎命名管道。")
        channel := NamedPipeChannel(handle, pipeName, false,
            this.GetCurrentUserSid(), "")
        try {
            channel.SetNonBlockingMessageMode()
            channel.AssertPeerCurrentUser()
            return channel
        } catch as connectError {
            try channel.Close()
            throw connectError
        }
    }

    __New(handle, pipeName, isServer, userSid, securitySddl) {
        this.Handle := handle
        this.PipeName := pipeName
        this.IsServer := !!isServer
        this.UserSid := String(userSid)
        this.SecuritySddl := String(securitySddl)
        this.Connected := !this.IsServer
        this.Closed := false
        this.PeerProcessId := 0
    }

    PollConnection() {
        if this.Closed
            throw Error("命名管道已关闭。")
        if this.Connected
            return true
        connected := DllCall("kernel32\ConnectNamedPipe", "Ptr", this.Handle,
            "Ptr", 0, "Int")
        if connected || A_LastError == 535 {
            this.Connected := true
            try {
                this.SetNonBlockingMessageMode()
                this.AssertPeerCurrentUser()
            } catch as connectionError {
                try DllCall("kernel32\DisconnectNamedPipe", "Ptr",
                    this.Handle)
                this.Connected := false
                this.PeerProcessId := 0
                throw connectionError
            }
            return true
        }
        if A_LastError == 536 || A_LastError == 232
            return false
        throw OSError(A_LastError, "命名管道接受连接失败。")
    }

    Write(message) {
        if !this.TryWrite(message)
            throw Error("命名管道发送缓冲区暂时已满。")
        return true
    }

    TryWrite(message) {
        previousCritical := A_IsCritical
        Critical("On")
        try {
        if this.Closed || !this.Connected
            throw Error("命名管道尚未连接。")
        bytes := HmacSha256.Utf8Bytes(String(message))
        if !bytes.Size || bytes.Size > NamedPipeChannel.MaximumMessageBytes
            throw Error("命名管道消息为空或超过大小上限。")
        written := Buffer(4, 0)
        if !DllCall("kernel32\WriteFile", "Ptr", this.Handle,
                "Ptr", bytes, "UInt", bytes.Size, "Ptr", written,
                "Ptr", 0, "Int") {
            errorCode := A_LastError
            if errorCode == 232 && this.PeerProcessId
                    && ProcessExist(this.PeerProcessId)
                return false
            throw OSError(errorCode, "命名管道写入失败。")
        }
        actualBytes := NumGet(written, 0, "UInt")
        if !actualBytes && this.PeerProcessId
                && ProcessExist(this.PeerProcessId)
            return false
        if actualBytes != bytes.Size
            throw Error("命名管道消息没有完整写入。")
        return true
        } finally Critical(previousCritical ? previousCritical : "Off")
    }

    TryRead() {
        if this.Closed || !this.Connected
            return ""
        available := Buffer(4, 0)
        currentMessageBytes := Buffer(4, 0)
        if !DllCall("kernel32\PeekNamedPipe", "Ptr", this.Handle,
                "Ptr", 0, "UInt", 0, "Ptr", 0, "Ptr", available,
                "Ptr", currentMessageBytes, "Int") {
            if NamedPipeChannel.IsPeerClosedError(A_LastError) {
                this.Connected := false
                return ""
            }
            throw OSError(A_LastError, "命名管道状态读取失败。")
        }
        totalBytes := NumGet(available, 0, "UInt")
        if !totalBytes
            return ""
        byteCount := NumGet(currentMessageBytes, 0, "UInt")
        if !byteCount
            throw Error("命名管道报告了空的当前消息。")
        if byteCount > NamedPipeChannel.MaximumMessageBytes
            throw Error("命名管道消息超过读取上限。")
        bytes := Buffer(byteCount + 1, 0)
        read := Buffer(4, 0)
        if !DllCall("kernel32\ReadFile", "Ptr", this.Handle,
                "Ptr", bytes, "UInt", byteCount, "Ptr", read,
                "Ptr", 0, "Int") {
            if NamedPipeChannel.IsPeerClosedError(A_LastError) {
                this.Connected := false
                return ""
            }
            throw OSError(A_LastError, "命名管道读取失败。")
        }
        actualBytes := NumGet(read, 0, "UInt")
        if !actualBytes
            return ""
        if actualBytes != byteCount
            throw Error("命名管道消息没有完整读取。")
        return NamedPipeChannel.DecodeUtf8Strict(bytes, actualBytes)
    }

    static DecodeUtf8Strict(bytes, byteCount := unset) {
        if Type(bytes) != "Buffer"
            throw TypeError("命名管道 UTF-8 输入必须是缓冲区。")
        if !IsSet(byteCount)
            byteCount := bytes.Size
        if Type(byteCount) != "Integer" || byteCount < 1
                || byteCount > bytes.Size
            throw ValueError("命名管道 UTF-8 输入长度无效。")
        Loop byteCount {
            if NumGet(bytes, A_Index - 1, "UChar") == 0
                throw ValueError("命名管道消息不能包含原始 NUL 字节。")
        }
        decoded := StrGet(bytes, byteCount, "UTF-8")
        roundTrip := HmacSha256.Utf8Bytes(decoded)
        if roundTrip.Size != byteCount
            throw ValueError("命名管道消息不是规范 UTF-8。")
        Loop byteCount {
            if NumGet(bytes, A_Index - 1, "UChar")
                    != NumGet(roundTrip, A_Index - 1, "UChar")
                throw ValueError("命名管道消息不是规范 UTF-8。")
        }
        return decoded
    }

    GetPeerProcessId() {
        if this.Closed || !this.Connected
            return 0
        processId := Buffer(4, 0)
        functionName := this.IsServer ? "GetNamedPipeClientProcessId"
            : "GetNamedPipeServerProcessId"
        if !DllCall("kernel32\" functionName, "Ptr", this.Handle,
                "Ptr", processId, "Int")
            throw OSError(A_LastError, "无法读取命名管道对端进程。")
        return NumGet(processId, 0, "UInt")
    }

    AssertPeerCurrentUser() {
        processId := this.GetPeerProcessId()
        if !processId
            throw Error("命名管道对端进程无效。")
        peerSid := NamedPipeChannel.GetProcessUserSid(processId)
        if StrCompare(peerSid, this.UserSid, false) != 0
            throw Error("拒绝来自其他 Windows 用户的命名管道连接。")
        this.PeerProcessId := processId
        return {ProcessId: processId, UserSid: peerSid}
    }

    RejectServerConnection() {
        if this.Closed || !this.IsServer || !this.Connected
            return false
        if !DllCall("kernel32\DisconnectNamedPipe", "Ptr", this.Handle,
                "Int") && A_LastError != 233
            throw OSError(A_LastError, "无法断开非预期的命名管道对端。")
        this.Connected := false
        this.PeerProcessId := 0
        return true
    }

    SetNonBlockingMessageMode() {
        mode := Buffer(4, 0)
        NumPut("UInt", 0x00000002 | 0x00000001, mode, 0)
        if !DllCall("kernel32\SetNamedPipeHandleState", "Ptr", this.Handle,
                "Ptr", mode, "Ptr", 0, "Ptr", 0, "Int")
            throw OSError(A_LastError, "无法设置命名管道消息模式。")
        return true
    }

    Close() {
        if this.Closed
            return false
        if this.IsServer && this.Connected
            try this.RejectServerConnection()
        if this.Handle && !DllCall("kernel32\CloseHandle", "Ptr",
                this.Handle, "Int")
            throw OSError(A_LastError, "无法关闭命名管道句柄。")
        this.Handle := 0
        this.Connected := false
        this.PeerProcessId := 0
        this.Closed := true
        return true
    }

    __Delete() {
        try this.Close()
    }

    static BuildPipeName(pipeId) {
        pipeId := StrLower(Trim(String(pipeId)))
        if !RegExMatch(pipeId, "^[0-9a-f]{32}$")
            throw ValueError("命名管道标识必须是 128 位十六进制值。")
        return this.PipePrefix pipeId
    }

    static IsPeerClosedError(errorCode) {
        ; ERROR_BROKEN_PIPE, ERROR_NO_DATA and ERROR_PIPE_NOT_CONNECTED all
        ; describe the same peer-close boundary at different pipe states.
        return errorCode == 109 || errorCode == 232 || errorCode == 233
    }

    static CreateSecurityAttributes(userSid, &descriptor, &sddl) {
        sddl := "D:P(A;;GA;;;SY)(A;;GA;;;" userSid ")"
        descriptorPointer := Buffer(A_PtrSize, 0)
        if !DllCall("advapi32\ConvertStringSecurityDescriptorToSecurityDescriptorW",
                "WStr", sddl, "UInt", 1, "Ptr", descriptorPointer,
                "Ptr", 0, "Int")
            throw OSError(A_LastError, "无法创建命名管道安全描述符。")
        descriptor := NumGet(descriptorPointer, 0, "Ptr")
        attributes := Buffer(A_PtrSize == 8 ? 24 : 12, 0)
        NumPut("UInt", attributes.Size, attributes, 0)
        NumPut("Ptr", descriptor, attributes, A_PtrSize == 8 ? 8 : 4)
        NumPut("Int", false, attributes, A_PtrSize == 8 ? 16 : 8)
        return attributes
    }

    static GetCurrentUserSid() {
        return this.GetProcessUserSid(
            DllCall("kernel32\GetCurrentProcessId", "UInt"))
    }

    static GetProcessUserSid(processId) {
        processHandle := DllCall("kernel32\OpenProcess", "UInt", 0x1000,
            "Int", false, "UInt", processId, "Ptr")
        if !processHandle
            throw OSError(A_LastError, "无法打开命名管道对端进程。")
        tokenHandle := Buffer(A_PtrSize, 0)
        try {
            if !DllCall("advapi32\OpenProcessToken", "Ptr", processHandle,
                    "UInt", 0x0008, "Ptr", tokenHandle, "Int")
                throw OSError(A_LastError, "无法读取命名管道对端令牌。")
            token := NumGet(tokenHandle, 0, "Ptr")
            required := Buffer(4, 0)
            DllCall("advapi32\GetTokenInformation", "Ptr", token,
                "Int", 1, "Ptr", 0, "UInt", 0, "Ptr", required, "Int")
            byteCount := NumGet(required, 0, "UInt")
            if !byteCount
                throw OSError(A_LastError, "无法读取用户 SID 大小。")
            tokenUser := Buffer(byteCount, 0)
            if !DllCall("advapi32\GetTokenInformation", "Ptr", token,
                    "Int", 1, "Ptr", tokenUser, "UInt", byteCount,
                    "Ptr", required, "Int")
                throw OSError(A_LastError, "无法读取用户 SID。")
            sidPointer := NumGet(tokenUser, 0, "Ptr")
            sidTextPointer := Buffer(A_PtrSize, 0)
            if !DllCall("advapi32\ConvertSidToStringSidW", "Ptr", sidPointer,
                    "Ptr", sidTextPointer, "Int")
                throw OSError(A_LastError, "无法格式化用户 SID。")
            sidText := NumGet(sidTextPointer, 0, "Ptr")
            try return StrGet(sidText, "UTF-16")
            finally DllCall("kernel32\LocalFree", "Ptr", sidText, "Ptr")
        } finally {
            token := NumGet(tokenHandle, 0, "Ptr")
            if token
                DllCall("kernel32\CloseHandle", "Ptr", token)
            DllCall("kernel32\CloseHandle", "Ptr", processHandle)
        }
    }
}
