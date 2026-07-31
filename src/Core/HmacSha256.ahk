class HmacSha256 {
    static BlockSize := 64

    static HexText(secret, message) {
        keyBytes := ""
        messageBytes := ""
        inner := ""
        outer := ""
        innerDigest := ""
        try {
            keyBytes := this.Utf8Bytes(String(secret))
            messageBytes := this.Utf8Bytes(String(message))
            if keyBytes.Size > HmacSha256.BlockSize {
                shortenedKey := this.HexToBuffer(Sha256.HexBuffer(keyBytes))
                this.ZeroBuffer(keyBytes)
                keyBytes := shortenedKey
            }

            inner := Buffer(HmacSha256.BlockSize + messageBytes.Size, 0)
            outer := Buffer(HmacSha256.BlockSize + 32, 0)
            Loop HmacSha256.BlockSize {
                keyByte := A_Index <= keyBytes.Size
                    ? NumGet(keyBytes, A_Index - 1, "UChar") : 0
                NumPut("UChar", keyByte ^ 0x36, inner, A_Index - 1)
                NumPut("UChar", keyByte ^ 0x5C, outer, A_Index - 1)
            }
            this.CopyBytes(messageBytes, inner, HmacSha256.BlockSize)
            innerDigest := this.HexToBuffer(Sha256.HexBuffer(inner))
            this.CopyBytes(innerDigest, outer, HmacSha256.BlockSize)
            return Sha256.HexBuffer(outer)
        } finally {
            for byteBuffer in [keyBytes, messageBytes, inner, outer,
                    innerDigest] {
                if byteBuffer is Buffer
                    this.ZeroBuffer(byteBuffer)
            }
        }
    }

    static RandomHex(byteCount := 32) {
        byteCount := Integer(byteCount)
        if byteCount < 16 || byteCount > 1024
            throw ValueError("随机密钥长度必须在 16 到 1024 字节之间。")
        randomBytes := Buffer(byteCount, 0)
        status := DllCall("bcrypt\BCryptGenRandom", "Ptr", 0,
            "Ptr", randomBytes, "UInt", byteCount, "UInt", 0x00000002,
            "UInt")
        if status != 0
            throw Error(Format("无法生成加密随机数（NTSTATUS 0x{:08X}）。",
                status))
        try return this.BufferToHex(randomBytes)
        finally this.ZeroBuffer(randomBytes)
    }

    static ConstantTimeEquals(left, right) {
        left := String(left)
        right := String(right)
        difference := StrLen(left) ^ StrLen(right)
        comparisonLength := Max(StrLen(left), StrLen(right))
        Loop comparisonLength {
            leftCode := A_Index <= StrLen(left) ? Ord(SubStr(left, A_Index, 1))
                : 0
            rightCode := A_Index <= StrLen(right)
                ? Ord(SubStr(right, A_Index, 1)) : 0
            difference |= leftCode ^ rightCode
        }
        return difference == 0
    }

    static Utf8Bytes(text) {
        byteCount := StrPut(text, "UTF-8") - 1
        encoded := Buffer(byteCount + 1, 0)
        try {
            if byteCount
                StrPut(text, encoded, byteCount + 1, "UTF-8")
            result := Buffer(byteCount, 0)
            if byteCount
                DllCall("kernel32\RtlMoveMemory", "Ptr", result,
                    "Ptr", encoded, "UPtr", byteCount)
            return result
        } finally this.ZeroBuffer(encoded)
    }

    static HexToBuffer(hexText) {
        hexText := String(hexText)
        if Mod(StrLen(hexText), 2) || !RegExMatch(hexText, "i)^[0-9a-f]*$")
            throw ValueError("十六进制数据格式无效。")
        result := Buffer(StrLen(hexText) // 2, 0)
        Loop result.Size
            NumPut("UChar", Integer("0x" SubStr(hexText,
                (A_Index - 1) * 2 + 1, 2)), result, A_Index - 1)
        return result
    }

    static BufferToHex(bytes) {
        result := ""
        Loop bytes.Size
            result .= Format("{:02X}", NumGet(bytes, A_Index - 1, "UChar"))
        return result
    }

    static CopyBytes(source, destination, destinationOffset := 0) {
        if destinationOffset < 0
                || destinationOffset + source.Size > destination.Size
            throw ValueError("字节复制超出目标缓冲区。")
        if source.Size
            DllCall("kernel32\RtlMoveMemory", "Ptr",
                destination.Ptr + destinationOffset, "Ptr", source.Ptr,
                "UPtr", source.Size)
    }

    static ZeroBuffer(byteBuffer) {
        if byteBuffer.Size
            DllCall("ntdll\RtlZeroMemory", "Ptr", byteBuffer.Ptr,
                "UPtr", byteBuffer.Size)
        return true
    }
}
