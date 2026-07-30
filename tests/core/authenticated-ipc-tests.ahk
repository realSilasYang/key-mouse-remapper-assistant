#Requires AutoHotkey v2.0 64-bit
#SingleInstance Off
#Warn All, StdOut

#Include ..\TestSupport.ahk
#Include ..\..\src\Core\JsonCodec.ahk
#Include ..\..\src\Core\Sha256.ahk
#Include ..\..\src\Core\HmacSha256.ahk
#Include ..\..\src\Core\AuthenticatedIpcProtocol.ahk
#Include ..\..\src\Platform\NamedPipeChannel.ahk

testFailure := ""
try {
    sessionId := "00112233445566778899aabbccddeeff"
    secret := "0123456789abcdef0123456789abcdef"
    invalidSkewCount := 0
    for invalidSkew in ["30000", 30000.5, 999, 0x80000000] {
        try AuthenticatedIpcProtocol(sessionId, "gui", "input-worker",
            secret, invalidSkew)
        catch
            invalidSkewCount++
    }
    AssertEqual(4, invalidSkewCount,
        "IPC 协议接受了宽松或越界时钟偏差")

    AssertEqual("F7BC83F430538424B13298E6AA6FB143EF4D59A14946175997479DBC2D1A3CD8",
        HmacSha256.HexText("key",
            "The quick brown fox jumps over the lazy dog"),
        "HMAC-SHA256 标准向量错误")
    nowMs := DllCall("kernel32\GetTickCount64", "UInt64")
    guiProtocol := AuthenticatedIpcProtocol(sessionId, "gui",
        "input-worker", secret)
    workerProtocol := AuthenticatedIpcProtocol(sessionId, "input-worker",
        "gui", secret)
    encodedMessage := guiProtocol.CreateMessage("apply", Map("count", 3),
        nowMs, "11111111111111111111111111111111")
    validated := workerProtocol.ValidateMessage(encodedMessage, nowMs)
    AssertTrue(validated["type"] == "apply"
            && validated["payload"]["count"] == 3,
        "认证 IPC 正常消息无法往返")

    replayRejected := false
    try workerProtocol.ValidateMessage(encodedMessage, nowMs)
    catch as replayError
        replayRejected := InStr(replayError.Message, "序号") > 0
    AssertTrue(replayRejected, "认证 IPC 没有拒绝重放消息")

    tampered := JsonCodec.Parse(guiProtocol.CreateMessage("apply",
        Map("count", 4), nowMs,
        "22222222222222222222222222222222"))
    tampered["payload"]["count"] := 99
    tamperedText := JsonCodec.Stringify(tampered, false, true)
    tamperRejected := false
    try workerProtocol.ValidateMessage(tamperedText, nowMs)
    catch as tamperError
        tamperRejected := InStr(tamperError.Message, "认证") > 0
    AssertTrue(tamperRejected, "认证 IPC 没有拒绝被篡改的负载")

    staleProtocol := AuthenticatedIpcProtocol(sessionId, "input-worker",
        "gui", secret, 1000)
    staleRejected := false
    try staleProtocol.ValidateMessage(guiProtocol.CreateMessage("heartbeat",
        Map(), nowMs - 5000,
        "33333333333333333333333333333333"), nowMs)
    catch as staleError
        staleRejected := InStr(staleError.Message, "过期") > 0
    AssertTrue(staleRejected, "认证 IPC 没有拒绝过期消息")

    wrongSecretProtocol := AuthenticatedIpcProtocol(sessionId,
        "input-worker", "gui",
        "fedcba9876543210fedcba9876543210")
    wrongSecretRejected := false
    try wrongSecretProtocol.ValidateMessage(guiProtocol.CreateMessage(
        "heartbeat", Map(), nowMs,
        "44444444444444444444444444444444"), nowMs)
    catch as secretError
        wrongSecretRejected := InStr(secretError.Message, "认证") > 0
    AssertTrue(wrongSecretRejected, "认证 IPC 没有拒绝错误会话密钥")

    strictSender := AuthenticatedIpcProtocol(sessionId, "gui",
        "input-worker", secret)
    strictReceiver := AuthenticatedIpcProtocol(sessionId, "input-worker",
        "gui", secret)
    looseSchema := JsonCodec.Parse(strictSender.CreateMessage("heartbeat",
        Map(), nowMs, "55555555555555555555555555555555"))
    looseSchema["schema"] := "1"
    looseSchema["mac"] := HmacSha256.HexText(secret,
        strictSender.CanonicalBody(looseSchema))
    looseSchemaRejected := false
    try strictReceiver.ValidateMessage(
        JsonCodec.Stringify(looseSchema, false, true), nowMs)
    catch as looseSchemaError
        looseSchemaRejected := InStr(looseSchemaError.Message, "版本") > 0
    AssertTrue(looseSchemaRejected,
        "认证 IPC 接受了字符串协议版本字段")

    queuedProtocol := AuthenticatedIpcProtocol(sessionId, "gui",
        "input-worker", secret)
    reentrantChannel := ReentrantProtocolChannel(queuedProtocol)
    queuedProtocol.SendMessage(reentrantChannel, "apply", Map("outer", true))
    AssertEqual(2, reentrantChannel.Messages.Length,
        "重入发送队列丢失了 IPC 消息")
    firstQueued := JsonCodec.Parse(reentrantChannel.Messages[1])
    secondQueued := JsonCodec.Parse(reentrantChannel.Messages[2])
    AssertTrue(firstQueued["sequence"] == 1
            && firstQueued["type"] == "apply"
            && secondQueued["sequence"] == 2
            && secondQueued["type"] == "heartbeat",
        "被定时器重入的 IPC 消息没有按生成顺序写入")

    retryProtocol := AuthenticatedIpcProtocol(sessionId, "gui",
        "input-worker", secret)
    retryChannel := BackpressureProtocolChannel()
    AssertTrue(!retryProtocol.TrySendMessage(retryChannel, "heartbeat",
            Map("attempt", 1))
            && retryProtocol.TrySendMessage(retryChannel, "heartbeat",
                Map("attempt", 2))
            && retryChannel.Messages.Length == 1,
        "认证 IPC 没有把暂时写满的发送留给调用方重试")

    invalidHello := Map("type", "hello", "payload", Map(
        "minimum_protocol", 0.5, "maximum_protocol", 1,
        "process_id", 123, "user_sid", "S-1-5-21-test",
        "role", "input-worker", "capabilities", []))
    fractionalProtocolRejected := false
    try workerProtocol.ValidateHello(invalidHello, 123, "S-1-5-21-test")
    catch
        fractionalProtocolRejected := true
    AssertTrue(fractionalProtocolRejected,
        "IPC 握手接受了非整数协议范围")

    invalidHello["payload"]["minimum_protocol"] := "1"
    stringProtocolRejected := false
    try workerProtocol.ValidateHello(invalidHello, 123, "S-1-5-21-test")
    catch
        stringProtocolRejected := true
    AssertTrue(stringProtocolRejected,
        "IPC 握手接受了字符串协议范围")

    invalidHello["payload"]["minimum_protocol"] := 1
    invalidHello["payload"]["process_id"] := 0
    zeroProcessRejected := false
    try workerProtocol.ValidateHello(invalidHello, 123, "S-1-5-21-test")
    catch
        zeroProcessRejected := true
    AssertTrue(zeroProcessRejected,
        "IPC 握手接受了零值进程标识")

    invalidHello["payload"]["process_id"] := "123"
    stringProcessRejected := false
    try workerProtocol.ValidateHello(invalidHello, 123, "S-1-5-21-test")
    catch
        stringProcessRejected := true
    AssertTrue(stringProcessRejected,
        "IPC 握手接受了字符串进程标识")

    invalidHello["payload"]["process_id"] := 123
    invalidHello["payload"]["capabilities"] := ["heartbeat", "heartbeat"]
    duplicateCapabilityRejected := false
    try workerProtocol.ValidateHello(invalidHello, 123, "S-1-5-21-test")
    catch
        duplicateCapabilityRejected := true
    AssertTrue(duplicateCapabilityRejected,
        "IPC 握手接受了重复能力名称")

    invalidHello["payload"]["capabilities"] := [1]
    numericCapabilityRejected := false
    try workerProtocol.ValidateHello(invalidHello, 123, "S-1-5-21-test")
    catch
        numericCapabilityRejected := true
    AssertTrue(numericCapabilityRejected,
        "IPC 握手接受了非字符串能力名称")

    extraFieldSender := AuthenticatedIpcProtocol(sessionId, "gui",
        "input-worker", secret)
    extraFieldReceiver := AuthenticatedIpcProtocol(sessionId,
        "input-worker", "gui", secret)
    extraFieldMessage := JsonCodec.Parse(extraFieldSender.CreateMessage(
        "heartbeat", Map(), nowMs,
        "66666666666666666666666666666666"))
    extraFieldMessage["unsigned_extension"] := "ignored"
    extraFieldMessage["mac"] := HmacSha256.HexText(secret,
        extraFieldSender.CanonicalBody(extraFieldMessage))
    unsignedFieldRejected := false
    try extraFieldReceiver.ValidateMessage(JsonCodec.Stringify(
        extraFieldMessage, false, true), nowMs)
    catch
        unsignedFieldRejected := true
    AssertTrue(unsignedFieldRejected,
        "认证 IPC 接受了未纳入规范签名体的额外字段")

    fractionalPipeTimeoutRejected := false
    try NamedPipeChannel.ConnectClient(
        "00112233445566778899aabbccddeeff", 1.5)
    catch
        fractionalPipeTimeoutRejected := true
    AssertTrue(fractionalPipeTimeoutRejected,
        "命名管道连接超时静默截断了小数")

    stringPipeTimeoutRejected := false
    try NamedPipeChannel.ConnectClient(
        "00112233445566778899aabbccddeeff", "1000")
    catch
        stringPipeTimeoutRejected := true
    AssertTrue(stringPipeTimeoutRejected,
        "命名管道连接超时接受了字符串整数")

    validUtf8 := HmacSha256.Utf8Bytes("严格 UTF-8")
    AssertEqual("严格 UTF-8",
        NamedPipeChannel.DecodeUtf8Strict(validUtf8),
        "命名管道严格 UTF-8 解码拒绝了有效文本")
    invalidUtf8 := Buffer(2, 0)
    NumPut("UChar", 0xC0, invalidUtf8, 0)
    NumPut("UChar", 0xAF, invalidUtf8, 1)
    invalidUtf8Rejected := false
    try NamedPipeChannel.DecodeUtf8Strict(invalidUtf8)
    catch
        invalidUtf8Rejected := true
    nulUtf8Rejected := false
    try NamedPipeChannel.DecodeUtf8Strict(Buffer(1, 0))
    catch
        nulUtf8Rejected := true
    AssertTrue(invalidUtf8Rejected && nulUtf8Rejected,
        "命名管道接受了非法 UTF-8 或原始 NUL 字节")

    pipeId := StrLower(HmacSha256.RandomHex(16))
    server := NamedPipeChannel.CreateServer(pipeId)
    client := ""
    try {
        AssertTrue(InStr(server.SecuritySddl, server.UserSid) > 0
                && InStr(server.SecuritySddl, ";;;SY") > 0,
            "命名管道 ACL 没有限制到当前用户与 SYSTEM")
        client := NamedPipeChannel.ConnectClient(pipeId, 1000)
        AssertTrue(server.PollConnection(), "命名管道服务端无法接受连接")
        serverPeer := server.AssertPeerCurrentUser()
        clientPeer := client.AssertPeerCurrentUser()
        currentProcessId := DllCall("kernel32\GetCurrentProcessId", "UInt")
        AssertTrue(serverPeer.ProcessId == currentProcessId
                && clientPeer.ProcessId == currentProcessId,
            "命名管道双端进程身份校验错误")
        backpressurePayload := ""
        Loop 8192
            backpressurePayload .= "x"
        acceptedWrites := 0
        Loop 64 {
            if !client.TryWrite(backpressurePayload)
                break
            acceptedWrites++
        }
        AssertTrue(acceptedWrites > 0 && acceptedWrites < 64,
            "命名管道非阻塞写入没有暴露可恢复的发送背压")
        while server.TryRead() != ""
            continue
        client.Write("client-message")
        AssertEqual("client-message", ReadPipeWithRetry(server),
            "命名管道客户端到服务端消息丢失")
        server.Write("server-message")
        AssertEqual("server-message", ReadPipeWithRetry(client),
            "命名管道服务端到客户端消息丢失")
        client.Close()
        Sleep(20)
        AssertEqual("", server.TryRead(),
            "命名管道对端关闭被错误报告为读取异常")
        AssertTrue(!server.Connected,
            "命名管道对端关闭后仍被标记为已连接")
    } finally {
        if IsObject(client)
            client.Close()
        server.Close()
    }

    invalidPipeRejected := false
    try NamedPipeChannel.BuildPipeName("unsafe-name")
    catch
        invalidPipeRejected := true
    AssertTrue(invalidPipeRejected, "命名管道接受了不安全的名称")

    WriteTestSuccess("authenticated-ipc")
} catch as ipcTestError {
    testFailure := ipcTestError.Message "`n" . ipcTestError.Stack
}
if testFailure != "" {
    FileAppend(testFailure "`n", "**")
    ExitApp(1)
}
ExitApp(0)

ReadPipeWithRetry(channel, attempts := 50) {
    Loop attempts {
        message := channel.TryRead()
        if message != ""
            return message
        Sleep(10)
    }
    throw Error("命名管道读取超时。")
}

class ReentrantProtocolChannel {
    __New(protocol) {
        this.Protocol := protocol
        this.Messages := []
        this.Interrupted := false
    }

    Write(message) {
        if !this.Interrupted {
            this.Interrupted := true
            this.Protocol.SendMessage(this, "heartbeat", Map("nested", true))
        }
        this.Messages.Push(message)
        return true
    }
}

class BackpressureProtocolChannel {
    __New() {
        this.Attempts := 0
        this.Messages := []
    }

    TryWrite(message) {
        this.Attempts++
        if this.Attempts == 1
            return false
        this.Messages.Push(message)
        return true
    }
}
