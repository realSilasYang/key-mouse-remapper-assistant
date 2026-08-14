class Sha256 {
    static HexText(text) {
        text := String(text)
        byteCount := StrPut(text, "UTF-8") - 1
        bytes := Buffer(Max(1, byteCount + 1), 0)
        if byteCount
            StrPut(text, bytes, byteCount + 1, "UTF-8")
        return this.HexBuffer(bytes, byteCount)
    }

    static HexBuffer(inputBuffer, byteCount := unset) {
        if !(inputBuffer is Buffer)
            throw TypeError("SHA-256 输入必须是缓冲区。")
        if !IsSet(byteCount)
            byteCount := inputBuffer.Size
        if !IsNumber(byteCount) || Integer(byteCount) != byteCount
                || byteCount < 0 || byteCount > inputBuffer.Size
                || byteCount > 0xFFFFFFFF
            throw ValueError("SHA-256 输入字节数超出缓冲区范围。")
        byteCount := Integer(byteCount)

        algorithmHandle := 0
        hashHandle := 0
        try {
            this.CheckStatus(DllCall(
                "bcrypt.dll\BCryptOpenAlgorithmProvider",
                "Ptr*", &algorithmHandle, "WStr", "SHA256",
                "Ptr", 0, "UInt", 0, "Int"),
                "打开 SHA-256 算法提供程序")
            objectLength := this.ReadUIntProperty(algorithmHandle,
                "ObjectLength")
            digestLength := this.ReadUIntProperty(algorithmHandle,
                "HashDigestLength")
            if digestLength != 32
                throw Error("系统 SHA-256 摘要长度无效。")
            hashObject := Buffer(Max(1, objectLength), 0)
            this.CheckStatus(DllCall("bcrypt.dll\BCryptCreateHash",
                "Ptr", algorithmHandle, "Ptr*", &hashHandle,
                "Ptr", hashObject.Ptr, "UInt", objectLength,
                "Ptr", 0, "UInt", 0, "UInt", 0, "Int"),
                "创建 SHA-256 哈希")
            if byteCount
                this.CheckStatus(DllCall("bcrypt.dll\BCryptHashData",
                    "Ptr", hashHandle, "Ptr", inputBuffer.Ptr,
                    "UInt", byteCount, "UInt", 0, "Int"),
                    "写入 SHA-256 数据")
            digest := Buffer(digestLength, 0)
            this.CheckStatus(DllCall("bcrypt.dll\BCryptFinishHash",
                "Ptr", hashHandle, "Ptr", digest.Ptr,
                "UInt", digest.Size, "UInt", 0, "Int"),
                "完成 SHA-256 哈希")
            result := ""
            VarSetStrCapacity(&result, digest.Size * 2)
            Loop digest.Size
                result .= Format("{:02X}",
                    NumGet(digest, A_Index - 1, "UChar"))
            return result
        } finally {
            if hashHandle
                DllCall("bcrypt.dll\BCryptDestroyHash",
                    "Ptr", hashHandle, "Int")
            if algorithmHandle
                DllCall("bcrypt.dll\BCryptCloseAlgorithmProvider",
                    "Ptr", algorithmHandle, "UInt", 0, "Int")
        }
    }

    static ReadUIntProperty(algorithmHandle, propertyName) {
        value := Buffer(4, 0)
        bytesWritten := 0
        this.CheckStatus(DllCall("bcrypt.dll\BCryptGetProperty",
            "Ptr", algorithmHandle, "WStr", propertyName,
            "Ptr", value.Ptr, "UInt", value.Size,
            "UInt*", &bytesWritten, "UInt", 0, "Int"),
            "读取 SHA-256 属性 " propertyName)
        if bytesWritten != value.Size
            throw Error("系统 SHA-256 属性长度无效：" propertyName)
        return NumGet(value, 0, "UInt")
    }

    static CheckStatus(status, operation) {
        if status != 0
            throw Error("系统加密服务无法" operation
                "（NTSTATUS " Format("0x{:08X}", status & 0xFFFFFFFF) "）。")
        return true
    }
}
