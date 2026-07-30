LaunchPackagedSource() {
    runtimePath := A_ScriptDir "\runtime\AutoHotkey64.exe"
    sourcePath := A_ScriptDir "\键鼠重映射小助手.ahk"
    validationOnly := HasCommandLineFlag("--startup-validation")
    if !FileExist(runtimePath) || !FileExist(sourcePath) {
        return ReportPackagedLaunchFailure(
            "发行包不完整。请保留 EXE、源码、runtime、app、src 和 assets 目录的相对位置。",
            validationOnly)
    }

    expectedRuntimeHash := GetPackagedRuntimeSha256()
    if !RegExMatch(expectedRuntimeHash, "^[A-F0-9]{64}$")
        return ReportPackagedLaunchFailure(
            "启动器没有嵌入有效的固定运行时摘要，请使用正式构建脚本重新打包。",
            validationOnly)
    try actualRuntimeHash := ComputeFileSha256(runtimePath)
    catch as hashError
        return ReportPackagedLaunchFailure(
            "无法校验发行包运行时：" hashError.Message, validationOnly)
    if actualRuntimeHash != expectedRuntimeHash
        return ReportPackagedLaunchFailure(
            "发行包运行时的 SHA-256 与构建时锁定值不一致。请重新下载或重新构建完整发行包。",
            validationOnly)

    parameters := QuoteCommandLineArgument(sourcePath) " --packaged"
    if validationOnly {
        parameters .= " --startup-validation"
        try exitCode := RunWait(QuoteCommandLineArgument(runtimePath) " "
            parameters, A_ScriptDir, "Hide")
        catch as validationError
            return ReportPackagedLaunchFailure(
                "发行包启动验证失败：" validationError.Message, true)
        if exitCode
            return ReportPackagedLaunchFailure(
                "包内源码启动验证返回错误代码 " exitCode "。", true)
        return true
    }
    result := DllCall("shell32\ShellExecuteW", "Ptr", 0, "WStr", "open",
        "WStr", runtimePath, "WStr", parameters, "WStr", A_ScriptDir,
        "Int", 1, "Ptr")
    if result > 32
        return true
    return ReportPackagedLaunchFailure(
        "无法启动发行包中的程序（ShellExecuteW 错误代码 " result "）。",
        false)
}

ReportPackagedLaunchFailure(message, validationOnly := false) {
    if validationOnly {
        try FileAppend(String(message) "`n", "**")
    } else
        MsgBox message, "无法启动键鼠重映射小助手", "Iconx"
    return false
}

GetPackagedRuntimeSha256() {
    ; 正式构建只替换暂存副本中的占位符，工作源码保持可审计。
    return "__PACKAGED_RUNTIME_SHA256__"
}

ComputeFileSha256(filePath, maximumBytes := 64 * 1024 * 1024) {
    filePath := String(filePath)
    if !FileExist(filePath)
        throw Error("待校验文件不存在。")
    if FileGetSize(filePath) > maximumBytes
        throw Error("待校验文件超过大小上限。")

    algorithmHandle := 0
    hashHandle := 0
    input := ""
    try {
        status := DllCall("bcrypt\BCryptOpenAlgorithmProvider",
            "Ptr*", &algorithmHandle, "WStr", "SHA256", "Ptr", 0,
            "UInt", 0, "UInt")
        if status
            throw Error("无法打开 SHA-256 提供程序（NTSTATUS "
                Format("0x{:08X}", status) "）。")

        objectLength := GetBCryptDwordProperty(algorithmHandle,
            "ObjectLength")
        digestLength := GetBCryptDwordProperty(algorithmHandle,
            "HashDigestLength")
        if objectLength < 1 || digestLength != 32
            throw Error("SHA-256 提供程序返回了无效参数。")
        hashObject := Buffer(objectLength, 0)
        status := DllCall("bcrypt\BCryptCreateHash", "Ptr", algorithmHandle,
            "Ptr*", &hashHandle, "Ptr", hashObject.Ptr,
            "UInt", hashObject.Size, "Ptr", 0, "UInt", 0,
            "UInt", 0, "UInt")
        if status
            throw Error("无法创建 SHA-256 上下文（NTSTATUS "
                Format("0x{:08X}", status) "）。")

        input := FileOpen(filePath, "r")
        if !IsObject(input)
            throw Error("无法打开待校验文件。")
        if input.Length > maximumBytes
            throw Error("待校验文件超过大小上限。")
        chunk := Buffer(64 * 1024, 0)
        totalBytes := 0
        while bytesRead := input.RawRead(chunk, chunk.Size) {
            totalBytes += bytesRead
            if totalBytes > maximumBytes
                throw Error("待校验文件在读取期间超过大小上限。")
            status := DllCall("bcrypt\BCryptHashData", "Ptr", hashHandle,
                "Ptr", chunk.Ptr, "UInt", bytesRead, "UInt", 0, "UInt")
            if status
                throw Error("SHA-256 数据处理失败（NTSTATUS "
                    Format("0x{:08X}", status) "）。")
        }
        input.Close()
        input := ""

        digest := Buffer(digestLength, 0)
        status := DllCall("bcrypt\BCryptFinishHash", "Ptr", hashHandle,
            "Ptr", digest.Ptr, "UInt", digest.Size, "UInt", 0, "UInt")
        if status
            throw Error("SHA-256 摘要生成失败（NTSTATUS "
                Format("0x{:08X}", status) "）。")
        result := ""
        Loop digest.Size
            result .= Format("{:02X}", NumGet(digest, A_Index - 1, "UChar"))
        return result
    } finally {
        if IsObject(input)
            try input.Close()
        if hashHandle
            DllCall("bcrypt\BCryptDestroyHash", "Ptr", hashHandle, "UInt")
        if algorithmHandle
            DllCall("bcrypt\BCryptCloseAlgorithmProvider",
                "Ptr", algorithmHandle, "UInt", 0, "UInt")
    }
}

GetBCryptDwordProperty(objectHandle, propertyName) {
    value := Buffer(4, 0)
    bytesWritten := 0
    status := DllCall("bcrypt\BCryptGetProperty", "Ptr", objectHandle,
        "WStr", propertyName, "Ptr", value.Ptr, "UInt", value.Size,
        "UInt*", &bytesWritten, "UInt", 0, "UInt")
    if status || bytesWritten != 4
        throw Error("无法读取 SHA-256 提供程序属性 " propertyName
            "（NTSTATUS " Format("0x{:08X}", status) "）。")
    return NumGet(value, 0, "UInt")
}

QuoteCommandLineArgument(value) {
    return Chr(34) StrReplace(String(value), Chr(34), Chr(92) Chr(34)) Chr(34)
}
