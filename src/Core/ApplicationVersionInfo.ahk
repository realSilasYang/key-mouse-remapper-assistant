ReadApplicationVersion() {
    if A_IsCompiled {
        try {
            compiledVersion := FileGetVersion(A_ScriptFullPath)
            if RegExMatch(compiledVersion,
                    "^((?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\."
                    . "(?:0|[1-9]\d*))(?:\.0)?$", &versionMatch)
                return versionMatch[1]
        }
    }
    versionPath := GetApplicationRootFilePath("VERSION")
    try {
        if !FileExist(versionPath)
            return "unknown"
        version := Trim(BoundedFileReader.ReadUtf8(versionPath, 128, 128,
            "版本文件"))
        if RegExMatch(version,
                "^(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)$")
            return version
    }
    return "unknown"
}

GetApplicationEditionSummary() {
    version := ReadApplicationVersion()
    versionText := version == "unknown" ? Tr("未知版本") : "v" version
    if HasCommandLineFlag("--packaged")
        return Tr("{1}（便携版）", versionText)
    return A_IsCompiled ? Tr("{1}（EXE 版）", versionText)
        : Tr("{1}（源码版）", versionText)
}

GetAutoHotkeyRuntimeSummary() {
    version := A_AhkVersion == "" ? Tr("未知版本") : A_AhkVersion
    return "AutoHotkey " version " x64"
}
