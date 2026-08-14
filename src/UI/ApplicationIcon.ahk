GetApplicationRootFilePath(relativePath) {
    relativePath := LTrim(String(relativePath), "\/")
    packagedPath := A_ScriptDir "\" relativePath
    if FileExist(packagedPath)
        return packagedPath
    SplitPath(A_LineFile, , &moduleDirectory)
    return moduleDirectory "\..\..\" relativePath
}

GetApplicationAssetPath(relativePath) {
    return GetApplicationRootFilePath("assets\" relativePath)
}

GetCanonicalPath(filePath) {
    try {
        Loop Files String(filePath), "F"
            return A_LoopFileFullPath
    }
    return String(filePath)
}

GetApplicationIconPath() {
    return GetApplicationAssetPath("app\key-mouse-remapper-assistant.ico")
}

GetApplicationUserModelId() {
    ; 不包含语言、版本或进程号，确保任务栏固定项和窗口分组跨升级稳定。
    return SystemIntegrationService.ApplicationUserModelId
}

ConfigureApplicationShellIdentity() {
    try result := DllCall(
        "shell32\SetCurrentProcessExplicitAppUserModelID",
        "WStr", GetApplicationUserModelId(), "Int")
    catch
        return false
    return result >= 0
}

GetApplicationIconMetrics() {
    smallSize := DllCall("user32\GetSystemMetrics", "Int", 49, "Int")
    largeSize := DllCall("user32\GetSystemMetrics", "Int", 11, "Int")
    return {
        Small: Max(16, smallSize),
        Large: Max(32, largeSize)
    }
}

ApplyApplicationWindowIcon(hwnd) {
    iconPath := GetApplicationIconPath()
    if !hwnd || !FileExist(iconPath)
        return []

    handles := []
    metrics := GetApplicationIconMetrics()
    for spec in [{Slot: 0, Size: metrics.Small},
            {Slot: 1, Size: metrics.Large}] {
        imageType := 0
        try iconHandle := LoadPicture(iconPath,
            "Icon1 w" spec.Size " h" spec.Size, &imageType)
        catch
            iconHandle := 0
        if !iconHandle
            continue
        SendMessage(0x0080, spec.Slot, iconHandle, , hwnd) ; WM_SETICON
        handles.Push(iconHandle)
    }
    return handles
}

ReleaseApplicationWindowIcons(handles) {
    if !IsObject(handles)
        return true
    failures := []
    initialHandleCount := handles.Length
    Loop initialHandleCount {
        index := initialHandleCount - A_Index + 1
        iconHandle := handles[index]
        if !iconHandle {
            handles.RemoveAt(index)
            continue
        }
        try {
            if DllCall("user32\DestroyIcon", "Ptr", iconHandle, "Int")
                handles.RemoveAt(index)
            else
                failures.Push("Win32 " A_LastError)
        } catch as iconError
            failures.Push(iconError.Message)
    }
    if failures.Length {
        message := ""
        for failure in failures
            message .= (message == "" ? "" : "；") failure
        throw Error("无法释放窗口图标：" message)
    }
    return true
}
