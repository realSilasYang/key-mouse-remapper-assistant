#Include ..\src\Core\BoundedFileReader.ahk

OnError(HandleUnhandledTestError)

HandleUnhandledTestError(error, mode) {
    message := "UNHANDLED TEST ERROR (" mode "): " error.Message
    if error.Stack != ""
        message .= "`n" error.Stack
    try FileAppend(message "`n", "**")
    ExitApp(1)
}

AssertTrue(value, message := "断言失败") {
    if !value
        throw Error(message)
}

AssertEqual(expected, actual, message := "值不相等") {
    if expected != actual
        throw Error(message "：期望 [" expected "]，实际 [" actual "]")
}

WriteTestSuccess(name) {
    FileAppend("PASS " name "`n", "*")
}

GetOffscreenTestWindowOptions(width := "", height := "") {
    options := "NA x-30000 y-30000"
    if width != ""
        options .= " w" width
    if height != ""
        options .= " h" height
    return options
}

ShowOffscreenTestMappingWindow(window, width := "", height := "",
        visible := true) {
    window.ShowWithOptions(GetOffscreenTestWindowOptions(width, height))
    if !visible
        window.Gui.Show("Hide")
}

AssertTestWindowOffscreen(hwnd, context := "GUI 测试窗口") {
    windowRect := Buffer(16, 0)
    AssertTrue(DllCall("user32\GetWindowRect", "Ptr", hwnd,
        "Ptr", windowRect, "Int"), context "：无法读取窗口位置")
    virtualLeft := DllCall("user32\GetSystemMetrics", "Int", 76, "Int")
    virtualTop := DllCall("user32\GetSystemMetrics", "Int", 77, "Int")
    virtualRight := virtualLeft
        + DllCall("user32\GetSystemMetrics", "Int", 78, "Int")
    virtualBottom := virtualTop
        + DllCall("user32\GetSystemMetrics", "Int", 79, "Int")
    windowLeft := NumGet(windowRect, 0, "Int")
    windowTop := NumGet(windowRect, 4, "Int")
    windowRight := NumGet(windowRect, 8, "Int")
    windowBottom := NumGet(windowRect, 12, "Int")
    AssertTrue(windowRight <= virtualLeft || windowLeft >= virtualRight
            || windowBottom <= virtualTop || windowTop >= virtualBottom,
        context " 泄露到了可见虚拟桌面")
}

ReadTestClientPixel(hwnd, x, y) {
    windowDpi := DllCall("user32\GetDpiForWindow", "Ptr", hwnd, "UInt")
    if !windowDpi
        windowDpi := 96
    pixelX := Round(x * windowDpi / 96)
    pixelY := Round(y * windowDpi / 96)
    clientRect := Buffer(16, 0)
    AssertTrue(DllCall("user32\GetClientRect", "Ptr", hwnd,
        "Ptr", clientRect, "Int"), "无法读取测试窗口客户区")
    clientWidth := NumGet(clientRect, 8, "Int")
    clientHeight := NumGet(clientRect, 12, "Int")
    AssertTrue(pixelX >= 0 && pixelX < clientWidth
            && pixelY >= 0 && pixelY < clientHeight,
        "测试像素坐标超出窗口客户区")

    screenDc := DllCall("user32\GetDC", "Ptr", 0, "Ptr")
    targetDc := screenDc ? DllCall("gdi32\CreateCompatibleDC",
        "Ptr", screenDc, "Ptr") : 0
    bitmap := targetDc ? DllCall("gdi32\CreateCompatibleBitmap",
        "Ptr", screenDc, "Int", clientWidth, "Int", clientHeight, "Ptr") : 0
    AssertTrue(screenDc && targetDc && bitmap,
        "无法创建测试窗口离屏渲染画布")
    previousBitmap := DllCall("gdi32\SelectObject", "Ptr", targetDc,
        "Ptr", bitmap, "Ptr")
    try {
        ; The first PrintWindow initializes the backing surface on some
        ; Windows builds and can leave the supplied bitmap black even though
        ; it reports success. Repaint the same DC before sampling.
        DllCall("user32\PrintWindow", "Ptr", hwnd, "Ptr", targetDc,
            "UInt", 3, "Int") ; CLIENTONLY | FULLCONTENT warm-up
        rendered := DllCall("user32\PrintWindow", "Ptr", hwnd,
            "Ptr", targetDc, "UInt", 3, "Int")
        if !rendered
            SendMessage(0x0318, targetDc, 0x001C, , hwnd) ; WM_PRINT
        return DllCall("gdi32\GetPixel", "Ptr", targetDc,
            "Int", pixelX, "Int", pixelY, "UInt")
    } finally {
        if previousBitmap
            DllCall("gdi32\SelectObject", "Ptr", targetDc,
                "Ptr", previousBitmap)
        DllCall("gdi32\DeleteObject", "Ptr", bitmap)
        DllCall("gdi32\DeleteDC", "Ptr", targetDc)
        DllCall("user32\ReleaseDC", "Ptr", 0, "Ptr", screenDc)
    }
}

AssertColorRefNear(expected, actual, message, channelTolerance := 1) {
    for shift in [0, 8, 16] {
        expectedChannel := (expected >> shift) & 0xFF
        actualChannel := (actual >> shift) & 0xFF
        AssertTrue(Abs(expectedChannel - actualChannel) <= channelTolerance,
            message "：期望 [" expected "]，实际 [" actual "]")
    }
}

GetControlFontFace(controlOrHwnd) {
    try hwnd := controlOrHwnd.Hwnd
    catch
        hwnd := controlOrHwnd
    fontHandle := SendMessage(0x0031, 0, 0, , hwnd) ; WM_GETFONT
    if !fontHandle
        return ""
    logFont := Buffer(92, 0)
    if !DllCall("gdi32\GetObjectW", "Ptr", fontHandle, "Int",
            logFont.Size, "Ptr", logFont, "Int")
        return ""
    return StrGet(logFont.Ptr + 28, 32, "UTF-16")
}
