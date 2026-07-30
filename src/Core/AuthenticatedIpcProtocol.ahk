class AuthenticatedIpcProtocol {
    static Schema := 1
    static ProtocolVersion := 1
    static MaximumMessageBytes := 64 * 1024
    static MaximumClockSkewMs := 30 * 1000
    static MaximumRememberedNonces := 1024
    static MaximumCapabilities := 64
    static MaximumSequence := 0x7FFFFFFFFFFFFFFF

    __New(sessionId, localRole, peerRole, secret,
            maximumClockSkewMs := AuthenticatedIpcProtocol.MaximumClockSkewMs) {
        this.SessionId := StrLower(Trim(String(sessionId)))
        this.LocalRole := StrLower(Trim(String(localRole)))
        this.PeerRole := StrLower(Trim(String(peerRole)))
        this.Secret := String(secret)
        if !RegExMatch(this.SessionId, "^[0-9a-f]{32}$")
            throw ValueError("IPC 会话标识必须是 128 位十六进制值。")
        if !this.IsValidRole(this.LocalRole) || !this.IsValidRole(this.PeerRole)
                || this.LocalRole == this.PeerRole
            throw ValueError("IPC 角色无效或两端角色相同。")
        if StrLen(this.Secret) < 32
            throw ValueError("IPC 会话密钥过短。")
        if Type(maximumClockSkewMs) != "Integer"
                || maximumClockSkewMs < 1000
                || maximumClockSkewMs > 0x7FFFFFFF
            throw ValueError("IPC 最大时钟偏差必须是 1000 到 2147483647 的整数毫秒值。")
        this.MaximumClockSkewMs := maximumClockSkewMs
        this.SendSequence := 0
        this.ReceiveSequence := 0
        this.SeenNonces := Map()
        this.NonceOrder := []
        this.SendQueue := []
        this.Sending := false
    }

    CreateMessage(messageType, payload := "", issuedAtMs := "",
            nonce := "") {
        previousCritical := A_IsCritical
        Critical("On")
        try {
        messageType := StrLower(Trim(String(messageType)))
        if !RegExMatch(messageType, "^[a-z][a-z0-9_.-]{0,63}$")
            throw ValueError("IPC 消息类型无效。")
        if payload == ""
            payload := Map()
        if Type(payload) != "Map"
            throw TypeError("IPC 消息负载必须是 Map。")
        if issuedAtMs == ""
            issuedAtMs := this.TickCount64()
        else if Type(issuedAtMs) != "Integer" || issuedAtMs < 0
            throw ValueError("IPC 消息时间戳必须是非负整数。")
        nonce := nonce == "" ? StrLower(HmacSha256.RandomHex(16))
            : StrLower(String(nonce))
        if !RegExMatch(nonce, "^[0-9a-f]{32}$")
            throw ValueError("IPC 消息 nonce 无效。")
        if this.SendSequence >= AuthenticatedIpcProtocol.MaximumSequence
            throw Error("IPC 发送序号已耗尽。")
        this.SendSequence++
        body := Map(
            "schema", AuthenticatedIpcProtocol.Schema,
            "protocol", AuthenticatedIpcProtocol.ProtocolVersion,
            "session_id", this.SessionId,
            "sender", this.LocalRole,
            "sequence", this.SendSequence,
            "issued_at_ms", issuedAtMs,
            "nonce", nonce,
            "type", messageType,
            "payload", this.CloneJson(payload))
        body["mac"] := HmacSha256.HexText(this.Secret,
            this.CanonicalBody(body))
        encoded := JsonCodec.Stringify(body, false, true)
        if StrPut(encoded, "UTF-8") - 1
                > AuthenticatedIpcProtocol.MaximumMessageBytes
            throw Error("IPC 消息超过大小上限。")
        return encoded
        } finally Critical(previousCritical ? previousCritical : "Off")
    }

    ValidateMessage(encoded, nowMs := "") {
        previousCritical := A_IsCritical
        Critical("On")
        try {
        encoded := String(encoded)
        if StrPut(encoded, "UTF-8") - 1
                > AuthenticatedIpcProtocol.MaximumMessageBytes
            throw Error("IPC 消息超过读取上限。")
        try message := JsonCodec.Parse(encoded)
        catch as parseError
            throw Error("IPC 消息不是有效 JSON：" parseError.Message)
        if Type(message) != "Map" || message.Count != 10
            throw Error("IPC 消息必须是对象。")
        for fieldName in ["schema", "protocol", "session_id", "sender",
                "sequence", "issued_at_ms", "nonce", "type", "payload",
                "mac"] {
            if !message.Has(fieldName)
                throw Error("IPC 消息缺少字段：" fieldName)
        }
        if Type(message["schema"]) != "Integer"
                || Type(message["protocol"]) != "Integer"
                || message["schema"] != AuthenticatedIpcProtocol.Schema
                || message["protocol"]
                    != AuthenticatedIpcProtocol.ProtocolVersion
            throw Error("IPC 协议版本不兼容。")
        if Type(message["session_id"]) != "String"
                || StrLower(message["session_id"]) != this.SessionId
            throw Error("IPC 会话标识不匹配。")
        if Type(message["sender"]) != "String"
                || StrLower(message["sender"]) != this.PeerRole
            throw Error("IPC 消息发送角色不匹配。")
        if Type(message["sequence"]) != "Integer"
            throw Error("IPC 消息序号无效。")
        sequence := Integer(message["sequence"])
        if sequence <= this.ReceiveSequence
                || sequence > AuthenticatedIpcProtocol.MaximumSequence
            throw Error("IPC 消息序号重复或逆序：收到 " sequence
                "，已接受 " this.ReceiveSequence "。")
        if Type(message["issued_at_ms"]) != "Integer"
            throw Error("IPC 消息时间戳无效。")
        if nowMs == ""
            nowMs := this.TickCount64()
        else if Type(nowMs) != "Integer"
            throw Error("IPC 校验时间必须是整数。")
        if Integer(message["issued_at_ms"]) < 0 || nowMs < 0
            throw Error("IPC 消息时间戳无效。")
        if Abs(nowMs - Integer(message["issued_at_ms"]))
                > this.MaximumClockSkewMs
            throw Error("IPC 消息已过期或来自异常时钟。")
        if Type(message["nonce"]) != "String"
            throw Error("IPC 消息 nonce 重复或无效。")
        nonce := StrLower(message["nonce"])
        if !RegExMatch(nonce, "^[0-9a-f]{32}$")
                || this.SeenNonces.Has(nonce)
            throw Error("IPC 消息 nonce 重复或无效。")
        if Type(message["type"]) != "String"
            throw Error("IPC 消息类型无效。")
        messageType := StrLower(message["type"])
        if !RegExMatch(messageType, "^[a-z][a-z0-9_.-]{0,63}$")
            throw Error("IPC 消息类型无效。")
        if Type(message["payload"]) != "Map"
            throw Error("IPC 消息负载必须是对象。")
        if Type(message["mac"]) != "String"
            throw Error("IPC 消息认证码格式无效。")
        suppliedMac := StrUpper(message["mac"])
        if !RegExMatch(suppliedMac, "^[0-9A-F]{64}$")
            throw Error("IPC 消息认证码格式无效。")
        expectedMac := HmacSha256.HexText(this.Secret,
            this.CanonicalBody(message))
        if !HmacSha256.ConstantTimeEquals(suppliedMac, expectedMac)
            throw Error("IPC 消息认证失败。")
        this.ReceiveSequence := sequence
        this.RememberNonce(nonce)
        return Map(
            "type", messageType,
            "payload", this.CloneJson(message["payload"]),
            "sequence", sequence,
            "issued_at_ms", Integer(message["issued_at_ms"]),
            "nonce", nonce)
        } finally Critical(previousCritical ? previousCritical : "Off")
    }

    CreateHello(processId, userSid, capabilities := "") {
        return this.CreateMessage("hello", this.BuildHelloPayload(processId,
            userSid, capabilities))
    }

    SendMessage(channel, messageType, payload := "") {
        previousCritical := A_IsCritical
        ownsDrain := false
        Critical("On")
        try {
            this.SendQueue.Push({Channel: channel, Type: messageType,
                Payload: payload})
            if this.Sending
                return true
            this.Sending := true
            ownsDrain := true
            while this.SendQueue.Length {
                item := this.SendQueue.RemoveAt(1)
                item.Channel.Write(this.CreateMessage(item.Type,
                    item.Payload))
            }
            return true
        } catch as sendError {
            if ownsDrain
                this.SendQueue := []
            throw sendError
        } finally {
            if ownsDrain
                this.Sending := false
            Critical(previousCritical ? previousCritical : "Off")
        }
    }

    TrySendMessage(channel, messageType, payload := "") {
        previousCritical := A_IsCritical
        ownsSend := false
        Critical("On")
        try {
            if this.Sending
                return false
            this.Sending := true
            ownsSend := true
            return channel.TryWrite(this.CreateMessage(messageType, payload))
        } finally {
            if ownsSend
                this.Sending := false
            Critical(previousCritical ? previousCritical : "Off")
        }
    }

    SendHello(channel, processId, userSid, capabilities := "") {
        return this.SendMessage(channel, "hello", this.BuildHelloPayload(
            processId, userSid, capabilities))
    }

    ValidateHello(message, expectedProcessId, expectedUserSid) {
        if Type(message) != "Map" || !message.Has("type")
                || !message.Has("payload") || message["type"] != "hello"
            throw Error("IPC 首条消息不是握手。")
        payload := message["payload"]
        if Type(payload) != "Map" || payload.Count != 6
            throw Error("IPC 握手负载无效。")
        for fieldName in ["minimum_protocol", "maximum_protocol",
                "process_id", "user_sid", "role", "capabilities"] {
            if !payload.Has(fieldName)
                throw Error("IPC 握手缺少字段：" fieldName)
        }
        if Type(payload["minimum_protocol"]) != "Integer"
                || Type(payload["maximum_protocol"]) != "Integer"
                || payload["minimum_protocol"] < 1
                || payload["maximum_protocol"] < 1
                || payload["minimum_protocol"]
                    > AuthenticatedIpcProtocol.ProtocolVersion
                || payload["maximum_protocol"]
                    < AuthenticatedIpcProtocol.ProtocolVersion
            throw Error("IPC 握手没有兼容的协议版本。")
        processId := this.NormalizeProcessId(payload["process_id"])
        expectedProcessId := this.NormalizeProcessId(expectedProcessId)
        if processId != expectedProcessId
            throw Error("IPC 握手进程标识与管道对端不一致。")
        if Type(payload["user_sid"]) != "String"
                || StrCompare(payload["user_sid"], String(expectedUserSid),
                false) != 0
            throw Error("IPC 握手用户 SID 与管道对端不一致。")
        if Type(payload["role"]) != "String"
                || StrLower(payload["role"]) != this.PeerRole
            throw Error("IPC 握手角色不一致。")
        capabilities := this.NormalizeCapabilities(payload["capabilities"])
        normalized := this.CloneJson(payload)
        normalized["process_id"] := processId
        normalized["capabilities"] := capabilities
        return normalized
    }

    CanonicalBody(message) {
        body := Map()
        for fieldName in ["schema", "protocol", "session_id", "sender",
                "sequence", "issued_at_ms", "nonce", "type", "payload"]
            body[fieldName] := message[fieldName]
        return JsonCodec.Stringify(body, false, true)
    }

    RememberNonce(nonce) {
        this.SeenNonces[nonce] := true
        this.NonceOrder.Push(nonce)
        while this.NonceOrder.Length
                > AuthenticatedIpcProtocol.MaximumRememberedNonces {
            oldest := this.NonceOrder.RemoveAt(1)
            this.SeenNonces.Delete(oldest)
        }
    }

    CloneJson(value) {
        return JsonCodec.Parse(JsonCodec.Stringify(value, false, true))
    }

    BuildHelloPayload(processId, userSid, capabilities) {
        userSid := String(userSid)
        if userSid == ""
            throw ValueError("IPC 握手用户 SID 不能为空。")
        return Map(
            "minimum_protocol", AuthenticatedIpcProtocol.ProtocolVersion,
            "maximum_protocol", AuthenticatedIpcProtocol.ProtocolVersion,
            "process_id", this.NormalizeProcessId(processId),
            "user_sid", userSid,
            "role", this.LocalRole,
            "capabilities", this.NormalizeCapabilities(capabilities))
    }

    NormalizeProcessId(value) {
        if Type(value) != "Integer"
            throw ValueError("IPC 握手进程标识必须是整数。")
        if value < 1 || value > 0xFFFFFFFF
            throw ValueError("IPC 握手进程标识超出范围。")
        return value
    }

    NormalizeCapabilities(capabilities) {
        if capabilities == ""
            capabilities := []
        if Type(capabilities) != "Array"
            throw TypeError("IPC 能力列表必须是数组。")
        if capabilities.Length > AuthenticatedIpcProtocol.MaximumCapabilities
            throw Error("IPC 能力列表超过数量上限。")
        result := [], seen := Map()
        for capability in capabilities {
            if Type(capability) != "String"
                throw Error("IPC 能力名称必须是字符串。")
            capability := StrLower(Trim(capability))
            if !RegExMatch(capability, "^[a-z][a-z0-9_.-]{0,63}$")
                throw Error("IPC 能力名称无效。")
            if seen.Has(capability)
                throw Error("IPC 能力列表包含重复项。")
            seen[capability] := true
            result.Push(capability)
        }
        return result
    }

    IsValidRole(role) {
        return RegExMatch(role, "^[a-z][a-z0-9-]{1,31}$")
    }

    TickCount64() => DllCall("kernel32\GetTickCount64", "UInt64")
}
