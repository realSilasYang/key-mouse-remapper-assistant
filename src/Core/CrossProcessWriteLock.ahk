class CrossProcessWriteLock {
    static Prefix := "Global\KeyMouseRemapperAssistant.Write."
    static DefaultTimeoutMs := 5000

    static Acquire(path, timeoutMs := 5000) {
        return this.AcquireMany([path], timeoutMs)
    }

    static AcquireMany(paths, timeoutMs := 5000) {
        if Type(paths) != "Array" || !paths.Length
            throw ValueError("写锁至少需要一个文件路径。")
        if Type(timeoutMs) != "Integer" || timeoutMs < 0
                || timeoutMs > 0xFFFFFFFE
            throw ValueError("写锁超时必须是 0 到 4294967294 的整数毫秒值。")
        normalized := []
        seen := Map()
        for path in paths {
            fullPath := this.NormalizePath(path)
            key := StrLower(fullPath)
            if !seen.Has(key) {
                seen[key] := true
                normalized.Push(fullPath)
            }
        }
        this.SortStrings(normalized)
        handles := []
        abandonedRecovered := false
        started := this.TickCount64()
        try {
            for fullPath in normalized {
                elapsed := this.TickCount64() - started
                remaining := Max(0, timeoutMs - elapsed)
                name := this.GetMutexName(fullPath)
                handle := DllCall("kernel32\CreateMutexW", "Ptr", 0,
                    "Int", false, "WStr", name, "Ptr")
                if !handle
                    throw OSError(A_LastError, "无法创建跨进程写锁。")
                waitResult := DllCall("kernel32\WaitForSingleObject",
                    "Ptr", handle, "UInt", remaining, "UInt")
                if waitResult == 0 || waitResult == 0x80 {
                    handles.Push(handle)
                    abandonedRecovered := abandonedRecovered
                        || waitResult == 0x80
                    continue
                }
                closeSucceeded := DllCall("kernel32\CloseHandle",
                    "Ptr", handle, "Int")
                closeError := A_LastError
                if waitResult == 0x102
                    throw Error("等待文件写锁超时：" fullPath
                        . (closeSucceeded ? "" : "；关闭等待句柄失败（Win32 "
                            closeError "）"))
                if !closeSucceeded
                    throw Error("无法取得跨进程写锁，且关闭等待句柄失败"
                        . "（Win32 " closeError "）。")
                throw OSError(A_LastError, "无法取得跨进程写锁。")
            }
            return CrossProcessWriteLockLease(handles, normalized,
                abandonedRecovered)
        } catch as lockError {
            try this.ReleaseHandles(handles)
            catch as releaseError
                throw Error(lockError.Message "；清理已取得写锁失败："
                    releaseError.Message, -1, lockError)
            throw
        }
    }

    static NormalizePath(path) {
        path := Trim(String(path))
        if path == ""
            throw ValueError("写锁文件路径不能为空。")
        required := DllCall("kernel32\GetFullPathNameW", "WStr", path,
            "UInt", 0, "Ptr", 0, "Ptr", 0, "UInt")
        if !required
            throw OSError(A_LastError, "无法规范化写锁路径。")
        pathBuffer := Buffer(required * 2, 0)
        result := DllCall("kernel32\GetFullPathNameW", "WStr", path,
            "UInt", required, "Ptr", pathBuffer, "Ptr", 0, "UInt")
        if !result || result >= required
            throw OSError(A_LastError, "无法规范化写锁路径。")
        return StrGet(pathBuffer, result, "UTF-16")
    }

    static GetMutexName(path) {
        return this.Prefix Sha256.HexText(
            StrLower(this.NormalizePath(path)))
    }

    static TickCount64() {
        return DllCall("kernel32\GetTickCount64", "UInt64")
    }

    static ReleaseHandles(handles) {
        failures := []
        index := handles.Length
        while index >= 1 {
            handle := handles[index]
            if !DllCall("kernel32\ReleaseMutex", "Ptr", handle, "Int")
                failures.Push("释放互斥量失败（Win32 " A_LastError "）")
            if !DllCall("kernel32\CloseHandle", "Ptr", handle, "Int")
                failures.Push("关闭互斥量句柄失败（Win32 " A_LastError "）")
            index--
        }
        if failures.Length
            throw Error(this.Join(failures, "；"))
        return true
    }

    static Join(values, separator) {
        result := ""
        for index, value in values
            result .= (index == 1 ? "" : separator) value
        return result
    }

    static SortStrings(values) {
        if values.Length < 2
            return values
        Loop values.Length - 1 {
            leftIndex := A_Index
            Loop values.Length - leftIndex {
                rightIndex := leftIndex + A_Index
                if StrCompare(values[leftIndex], values[rightIndex], true) <= 0
                    continue
                temporary := values[leftIndex]
                values[leftIndex] := values[rightIndex]
                values[rightIndex] := temporary
            }
        }
        return values
    }
}

class CrossProcessWriteLockLease {
    __New(handles, paths, recovered) {
        this.Handles := handles
        this.Paths := paths
        this.Recovered := !!recovered
        this.Released := false
    }

    Release() {
        if this.Released
            return false
        this.Released := true
        handles := this.Handles
        this.Handles := []
        CrossProcessWriteLock.ReleaseHandles(handles)
        return true
    }

    __Delete() {
        try this.Release()
    }
}
