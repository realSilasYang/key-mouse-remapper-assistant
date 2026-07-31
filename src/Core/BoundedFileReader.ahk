class BoundedFileReader {
    static MaximumSupportedBytes := 64 * 1024 * 1024

    static ReadUtf8(filePath, maximumBytes, maximumCharacters := "",
            label := "文件") {
        maximumBytes := this.NormalizeMaximumBytes(maximumBytes)
        if maximumCharacters == ""
            maximumCharacters := maximumBytes
        if Type(maximumCharacters) != "Integer" || maximumCharacters < 0
            throw ValueError("文件字符上限必须是非负整数。")
        bytes := this.ReadBytes(filePath, maximumBytes, label)
        offset := bytes.Size >= 3
            && NumGet(bytes, 0, "UChar") == 0xEF
            && NumGet(bytes, 1, "UChar") == 0xBB
            && NumGet(bytes, 2, "UChar") == 0xBF ? 3 : 0
        text := this.DecodeUtf8(bytes, offset, label)
        if StrLen(text) > maximumCharacters
            throw BoundedFileLimitError(String(label) "超过读取字符上限。")
        return text
    }

    static ReadBytes(filePath, maximumBytes, label := "文件") {
        maximumBytes := this.NormalizeMaximumBytes(maximumBytes)
        input := FileOpen(filePath, "r")
        if !IsObject(input)
            throw Error("无法打开" String(label) "。")
        try {
            if DllCall("kernel32\GetFileType", "Ptr", input.Handle,
                    "UInt") != 1
                throw BoundedFileFormatError(
                    String(label) "不是普通磁盘文件。")
            expectedBytes := input.Length
            if Type(expectedBytes) != "Integer" || expectedBytes < 0
                throw BoundedFileFormatError(
                    String(label) "长度无效。")
            if expectedBytes > maximumBytes
                throw BoundedFileLimitError(
                    String(label) "超过读取大小上限。")
            readBuffer := Buffer(Min(maximumBytes + 1,
                expectedBytes + 1), 0)
            input.Pos := 0
            bytesRead := input.RawRead(readBuffer)
        } finally input.Close()
        if bytesRead > maximumBytes
            throw BoundedFileLimitError(String(label) "超过读取大小上限。")
        if bytesRead != expectedBytes
            throw BoundedFileFormatError(
                String(label) "在读取期间发生变化或未被完整读取。")
        result := Buffer(bytesRead, 0)
        if bytesRead
            DllCall("kernel32\RtlMoveMemory", "Ptr", result.Ptr,
                "Ptr", readBuffer.Ptr, "UPtr", bytesRead)
        return result
    }

    static NormalizeMaximumBytes(maximumBytes) {
        if Type(maximumBytes) != "Integer" || maximumBytes < 1
                || maximumBytes > BoundedFileReader.MaximumSupportedBytes
            throw ValueError("文件字节上限必须是有效的正整数。")
        return maximumBytes
    }

    static DecodeUtf8(bytes, offset, label) {
        byteCount := bytes.Size - offset
        if byteCount <= 0
            return ""
        if DllCall("msvcrt\memchr", "Ptr", bytes.Ptr + offset,
                "Int", 0, "UPtr", byteCount, "Ptr")
            throw BoundedFileFormatError(
                String(label) "包含不支持的 NUL 字符。")
        characterCount := DllCall("kernel32\MultiByteToWideChar",
            "UInt", 65001, "UInt", 0x8, "Ptr", bytes.Ptr + offset,
            "Int", byteCount, "Ptr", 0, "Int", 0, "Int")
        if !characterCount
            throw BoundedFileFormatError(
                String(label) "不是有效的 UTF-8 文件。")
        textBuffer := Buffer(characterCount * 2, 0)
        converted := DllCall("kernel32\MultiByteToWideChar",
            "UInt", 65001, "UInt", 0x8, "Ptr", bytes.Ptr + offset,
            "Int", byteCount, "Ptr", textBuffer.Ptr,
            "Int", characterCount, "Int")
        if converted != characterCount
            throw BoundedFileFormatError(
                String(label) "无法按 UTF-8 解码。")
        return StrGet(textBuffer, characterCount, "UTF-16")
    }
}

class BoundedFileLimitError extends Error {
}

class BoundedFileFormatError extends Error {
}
