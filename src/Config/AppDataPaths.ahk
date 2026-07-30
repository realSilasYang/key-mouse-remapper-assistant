; 产品改名后的默认数据路径及一次性兼容迁移。

class KeyMouseRemapperAssistantDataPaths {
    static CurrentDirectoryName := "KeyMouseRemapperAssistant"
    static PreviousDirectoryName := "KeyMouseRemapper"
    static OriginalDirectoryName := "ShortcutRemapper"

    static Resolve(appDataRoot := "") {
        root := this.NormalizeRoot(appDataRoot)
        currentDirectory := root "\" this.CurrentDirectoryName
        previousDirectory := root "\" this.PreviousDirectoryName
        originalDirectory := root "\" this.OriginalDirectoryName
        return {
            Directory: currentDirectory,
            Settings: this.ResolveFile(currentDirectory,
                "key-mouse-remapper-assistant.ini", [
                    previousDirectory "\key-mouse-remapper.ini",
                    originalDirectory "\key-remapper.ini"]),
            History: this.ResolveFile(currentDirectory, "history.dat",
                [previousDirectory "\history.dat",
                    originalDirectory "\history.dat"]),
            Notification: this.ResolveFile(currentDirectory,
                "pending-notification.txt", [
                    previousDirectory "\pending-notification.txt",
                    originalDirectory "\pending-notification.txt"]),
            Variables: this.ResolveFile(currentDirectory, "variables.json",
                [previousDirectory "\variables.json",
                    originalDirectory "\variables.json"]),
            Control: this.ResolveFile(currentDirectory,
                "control-requests.json", [
                    previousDirectory "\control-requests.json"]),
            StartupHealth: this.ResolveFile(currentDirectory,
                "startup-health.json", [
                    previousDirectory "\startup-health.json"]),
            LastKnownGood: this.ResolveFile(currentDirectory,
                "last-known-good.json", [
                    previousDirectory "\last-known-good.json"]),
            OutputRecovery: this.ResolveFile(currentDirectory,
                "output-recovery.json", [
                    previousDirectory "\output-recovery.json"]),
            CrashDiagnostics: this.ResolveFile(currentDirectory,
                "crash-diagnostics.json", [
                    previousDirectory "\crash-diagnostics.json"])
        }
    }

    static NormalizeRoot(appDataRoot) {
        if appDataRoot == ""
            candidate := A_AppData
        else {
            candidate := Trim(String(appDataRoot), " `t`r`n")
            if candidate == ""
                throw ValueError("应用数据根目录不能只包含空白字符。")
        }
        candidate := StrReplace(candidate, "/", "\")
        if !this.IsAbsolutePath(candidate)
            throw ValueError("应用数据根目录必须是绝对路径。")
        required := DllCall("kernel32\GetFullPathNameW", "WStr", candidate,
            "UInt", 0, "Ptr", 0, "Ptr", 0, "UInt")
        if !required
            throw OSError(A_LastError, "无法规范化应用数据根目录。")
        pathBuffer := Buffer((required + 1) * 2, 0)
        written := DllCall("kernel32\GetFullPathNameW", "WStr", candidate,
            "UInt", required + 1, "Ptr", pathBuffer.Ptr, "Ptr", 0, "UInt")
        if !written || written > required
            throw OSError(A_LastError, "无法规范化应用数据根目录。")
        root := RTrim(StrGet(pathBuffer, written, "UTF-16"), "\")
        if this.IsFileSystemRoot(root)
            throw ValueError("应用数据根目录不能是卷或网络共享根目录。")
        attributes := FileExist(root)
        if attributes != "" && !InStr(attributes, "D")
            throw ValueError("应用数据根目录指向了文件。")
        return root
    }

    static IsAbsolutePath(path) {
        return RegExMatch(path, "i)^[a-z]:\\")
            || RegExMatch(path, "^\\\\[^\\]+\\[^\\]+(?:\\|$)")
            || RegExMatch(path, "i)^\\\\\?\\[a-z]:\\")
            || RegExMatch(path,
                "i)^\\\\\?\\UNC\\[^\\]+\\[^\\]+(?:\\|$)")
    }

    static IsFileSystemRoot(path) {
        return RegExMatch(path, "i)^[a-z]:$")
            || RegExMatch(path, "^\\\\[^\\]+\\[^\\]+$")
            || RegExMatch(path, "i)^\\\\\?\\[a-z]:$")
            || RegExMatch(path,
                "i)^\\\\\?\\UNC\\[^\\]+\\[^\\]+$")
    }

    static ResolveFile(currentDirectory, currentName, legacyPaths) {
        currentPath := currentDirectory "\" currentName
        if FileExist(currentPath)
            return currentPath
        for legacyPath in legacyPaths {
            if !FileExist(legacyPath)
                continue
            try {
                if !DirExist(currentDirectory)
                    DirCreate(currentDirectory)
                FileCopy(legacyPath, currentPath, false)
                return currentPath
            } catch {
                ; 迁移失败时继续使用原文件，不能把已有设置静默回退为默认值。
                return legacyPath
            }
        }
        return currentPath
    }
}
