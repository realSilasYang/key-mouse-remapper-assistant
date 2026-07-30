; 撤销与重做结果气泡。
; 不拥有或激活主窗口；按真实字体测量，贴在状态栏上方，从上方下滑淡入，
; 三秒后向上淡出。

class HistoryToastWindow {
    __New(ownerWindow) {
        this.OwnerWindow := ownerWindow
        this.Gui := ""
        this.TextControl := ""
        this.HideTimer := ObjBindMethod(this, "BeginHide")
        this.AnimationTimer := ObjBindMethod(this, "AdvanceAnimation")
        this.AnimationPhase := "idle"
        this.AnimationStartedTicks := 0
        this.AnimationDurationMs := 0
        this.AnimationFromY := 0
        this.AnimationToY := 0
        this.AnimationFromAlpha := 255
        this.AnimationToAlpha := 255
        this.CurrentY := 0
        this.CurrentAlpha := 255
        this.CurrentX := 0
        this.ToastWidth := 0
        this.ToastHeight := 0
        this.TargetY := 0
        this.AnimationDpi := 96
        this.HideDeadlineTicks := 0
        this.Disposed := false
    }

    GetOwnerGui() {
        if this.Disposed || !IsObject(this.OwnerWindow)
            return false
        try ownerGui := this.OwnerWindow.Gui
        catch
            return false
        try ownerHwnd := ownerGui.Hwnd
        catch
            return false
        return ownerHwnd && DllCall("user32\IsWindow", "Ptr", ownerHwnd,
            "Int") ? ownerGui : false
    }

    IsOpen() {
        if !IsObject(this.Gui)
            return false
        try hwnd := this.Gui.Hwnd
        catch
            hwnd := 0
        if hwnd && DllCall("user32\IsWindow", "Ptr", hwnd, "Int")
            return true
        this.Gui := ""
        this.TextControl := ""
        this.CancelTimers()
        return false
    }

    EnsureCreated() {
        if this.IsOpen()
            return true
        colors := UiThemeService.GetPalette()
        ; WS_EX_NOACTIVATE 保持主窗口焦点，WS_EX_LAYERED 只用于整窗淡入淡出。
        this.Gui := Gui("-Caption +ToolWindow +AlwaysOnTop +E0x08080000")
        this.Gui.BackColor := colors.Tooltip
        this.Gui.MarginX := 14
        this.Gui.MarginY := 9
        this.Gui.SetFont("s9 bold c" colors.TooltipText,
            LocalizationService.GetLanguageSystemUiFontName())
        this.TextControl := this.Gui.Add("Text", "x14 y9 w1 h1 Background"
            colors.Tooltip " c" colors.TooltipText, "")
        if VerCompare(A_OSVersion, "10.0.22000") >= 0
            try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", this.Gui.Hwnd,
                "Int", 33, "Int*", 2, "Int", 4)
        return true
    }

    NormalizeText(text) {
        text := String(text)
        if LocalizationService.IsChinese()
            text := RegExReplace(text, "\h+\(([^()\r\n]*)\)", "（$1）")
        return RTrim(text, "`r`n")
    }

    Show(text, *) {
        text := this.NormalizeText(text)
        ownerGui := this.GetOwnerGui()
        if text == "" || !IsObject(ownerGui) || !this.EnsureCreated()
            return false

        wasVisible := DllCall("user32\IsWindowVisible", "Ptr",
            this.Gui.Hwnd, "Int") != 0
        oldText := this.TextControl.Text
        displayText := this.BreakLongRuns(text)
        this.TextControl.Text := displayText
        if !this.LayoutText(displayText, ownerGui, &windowWidthDip,
                &windowHeightDip) {
            this.TextControl.Text := oldText
            return false
        }
        this.CancelTimers()
        this.Gui.Show((wasVisible ? "" : "Hide ")
            "NoActivate w" windowWidthDip " h" windowHeightDip)
        this.ApplyRoundedRegion()
        if !this.GetTargetBounds(ownerGui, &targetX, &targetY, &toastWidth,
                &toastHeight, &windowDpi) {
            this.HideNow()
            return false
        }

        this.TargetY := targetY
        this.CurrentX := targetX
        this.ToastWidth := toastWidth
        this.ToastHeight := toastHeight
        this.AnimationDpi := windowDpi
        startOffset := Round((wasVisible ? 4 : 10) * windowDpi / 96)
        startY := targetY - startOffset
        startAlpha := wasVisible ? 176 : 0
        this.SetWindowAlpha(startAlpha)
        if !this.SetWindowBounds(targetX, startY, toastWidth, toastHeight,
                true) {
            this.HideNow()
            return false
        }
        this.BeginAnimation("show", startY, targetY, startAlpha, 255, 160)
        return true
    }

    BreakLongRuns(text) {
        result := ""
        runLength := 0
        Loop Parse String(text) {
            character := A_LoopField
            result .= character
            if RegExMatch(character, "[\s,.;:!?/\\\-，。；：！？、]")
                runLength := 0
            else
                runLength++
            if runLength >= 48 {
                result .= Chr(0x200B)
                runLength := 0
            }
        }
        return result
    }

    LayoutText(text, ownerGui, &windowWidthDip, &windowHeightDip) {
        if !this.IsOpen()
            return false
        mainRect := Buffer(16, 0)
        if !DllCall("user32\GetClientRect", "Ptr", ownerGui.Hwnd,
                "Ptr", mainRect, "Int")
            return false
        windowDpi := DllCall("user32\GetDpiForWindow", "Ptr", ownerGui.Hwnd,
            "UInt")
        if !windowDpi
            windowDpi := 96
        clientWidthPx := NumGet(mainRect, 8, "Int")
        clientHeightPx := NumGet(mainRect, 12, "Int")
        maximumWindowWidthDip := Min(480,
            Max(120, Floor(clientWidthPx * 96 / windowDpi) - 24))
        maximumTextWidthPx := Max(1,
            Round((maximumWindowWidthDip - 28) * windowDpi / 96))

        deviceContext := DllCall("user32\GetDC", "Ptr",
            this.TextControl.Hwnd, "Ptr")
        if !deviceContext
            return false
        fontHandle := SendMessage(0x0031, 0, 0, this.TextControl.Hwnd)
        previousFont := fontHandle
            ? DllCall("gdi32\SelectObject", "Ptr", deviceContext,
                "Ptr", fontHandle, "Ptr") : 0
        try {
            naturalWidthPx := 1
            Loop Parse, text, "`n", "`r" {
                lineText := A_LoopField != "" ? A_LoopField : " "
                extent := Buffer(8, 0)
                if DllCall("gdi32\GetTextExtentPoint32W", "Ptr",
                        deviceContext, "Str", lineText, "Int",
                        StrLen(lineText), "Ptr", extent, "Int")
                    naturalWidthPx := Max(naturalWidthPx,
                        NumGet(extent, 0, "Int"))
            }
            textWidthPx := Min(naturalWidthPx, maximumTextWidthPx)
            measureRect := Buffer(16, 0)
            NumPut("Int", textWidthPx, measureRect, 8)
            ; DT_CALCRECT | DT_WORDBREAK | DT_EXPANDTABS | DT_NOPREFIX。
            DllCall("user32\DrawTextW", "Ptr", deviceContext, "Str", text,
                "Int", -1, "Ptr", measureRect, "UInt", 0x0C50, "Int")
            maximumTextHeightPx := Max(1,
                clientHeightPx - Round(42 * windowDpi / 96))
            textHeightPx := Min(maximumTextHeightPx,
                Max(1, NumGet(measureRect, 12, "Int")))
            textWidthDip := Max(1, Ceil(textWidthPx * 96 / windowDpi))
            textHeightDip := Max(1, Ceil(textHeightPx * 96 / windowDpi))
            this.TextControl.Move(14, 9, textWidthDip, textHeightDip)
            windowWidthDip := textWidthDip + 28
            windowHeightDip := textHeightDip + 18
            return true
        } finally {
            if previousFont
                DllCall("gdi32\SelectObject", "Ptr", deviceContext,
                    "Ptr", previousFont)
            DllCall("user32\ReleaseDC", "Ptr", this.TextControl.Hwnd,
                "Ptr", deviceContext)
        }
    }

    GetTargetBounds(ownerGui, &x, &y, &width, &height, &dpi) {
        if !this.IsOpen()
            return false
        mainHwnd := ownerGui.Hwnd
        if !DllCall("user32\IsWindowVisible", "Ptr", mainHwnd, "Int")
            || DllCall("user32\IsIconic", "Ptr", mainHwnd, "Int")
            return false
        clientRect := Buffer(16, 0)
        clientOrigin := Buffer(8, 0)
        boundsRect := Buffer(16, 0)
        if !DllCall("user32\GetClientRect", "Ptr", mainHwnd, "Ptr",
                clientRect, "Int")
            || !DllCall("user32\ClientToScreen", "Ptr", mainHwnd,
                "Ptr", clientOrigin, "Int")
            || !DllCall("user32\GetWindowRect", "Ptr", this.Gui.Hwnd,
                "Ptr", boundsRect, "Int")
            return false
        dpi := DllCall("user32\GetDpiForWindow", "Ptr", mainHwnd, "UInt")
        if !dpi
            dpi := 96
        width := NumGet(boundsRect, 8, "Int") - NumGet(boundsRect, 0, "Int")
        height := NumGet(boundsRect, 12, "Int") - NumGet(boundsRect, 4, "Int")
        statusRect := Buffer(16, 0)
        gap := Max(1, Round(3 * dpi / 96))
        statusHwnd := 0
        try statusHwnd := this.OwnerWindow.Status.Hwnd
        if statusHwnd && DllCall("user32\IsWindow", "Ptr", statusHwnd,
                "Int") && DllCall("user32\GetWindowRect", "Ptr",
                    statusHwnd, "Ptr", statusRect, "Int") {
            x := NumGet(statusRect, 0, "Int")
            y := NumGet(statusRect, 4, "Int") - height - gap
        } else {
            inset := Round(10 * dpi / 96)
            statusHeight := Round(20 * dpi / 96)
            x := NumGet(clientOrigin, 0, "Int") + inset
            y := NumGet(clientOrigin, 4, "Int")
                + NumGet(clientRect, 12, "Int") - statusHeight
                - height - gap
        }
        return width > 0 && height > 0
    }

    Reposition(*) {
        if !this.IsOpen() || !DllCall("user32\IsWindowVisible", "Ptr",
                this.Gui.Hwnd, "Int")
            return false
        ownerGui := this.GetOwnerGui()
        if !IsObject(ownerGui)
            return false
        hadTarget := this.ToastWidth > 0 && this.ToastHeight > 0
        previousTargetY := this.TargetY
        if !this.GetTargetBounds(ownerGui, &targetX, &targetY, &toastWidth,
                &toastHeight, &windowDpi)
            return false
        this.TargetY := targetY
        this.CurrentX := targetX
        this.ToastWidth := toastWidth
        this.ToastHeight := toastHeight
        this.AnimationDpi := windowDpi
        if hadTarget && (this.AnimationPhase == "show"
                || this.AnimationPhase == "hide") {
            deltaY := targetY - previousTargetY
            this.AnimationFromY += deltaY
            this.AnimationToY += deltaY
            this.CurrentY += deltaY
        } else {
            this.CurrentY := targetY
        }
        return this.SetWindowBounds(targetX, this.CurrentY, toastWidth,
            toastHeight)
    }

    SetWindowBounds(x, y, width, height, showWindow := false) {
        flags := 0x0010 | (showWindow ? 0x0040 : 0)
        return !!DllCall("user32\SetWindowPos", "Ptr", this.Gui.Hwnd,
            "Ptr", -1, "Int", x, "Int", y, "Int", width, "Int", height,
            "UInt", flags, "Int")
    }

    SetWindowPosition(x, y) {
        return !!DllCall("user32\SetWindowPos", "Ptr", this.Gui.Hwnd,
            "Ptr", -1, "Int", x, "Int", y, "Int", 0, "Int", 0,
            "UInt", 0x0011, "Int")
    }

    SetWindowAlpha(alpha) {
        if !this.IsOpen()
            return false
        alpha := Max(0, Min(255, Round(alpha)))
        if !DllCall("user32\SetLayeredWindowAttributes", "Ptr",
                this.Gui.Hwnd, "UInt", 0, "UChar", alpha, "UInt", 0x2,
                "Int")
            return false
        this.CurrentAlpha := alpha
        return true
    }

    BeginAnimation(phase, fromY, toY, fromAlpha, toAlpha, durationMs) {
        try SetTimer(this.AnimationTimer, 0)
        this.AnimationPhase := phase
        this.AnimationStartedTicks := DllCall("kernel32\GetTickCount64",
            "UInt64")
        this.AnimationDurationMs := Max(1, durationMs)
        this.AnimationFromY := fromY
        this.AnimationToY := toY
        this.AnimationFromAlpha := fromAlpha
        this.AnimationToAlpha := toAlpha
        this.CurrentY := fromY
        this.CurrentAlpha := fromAlpha
        SetTimer(this.AnimationTimer, 15)
    }

    AdvanceAnimation(*) {
        if this.AnimationPhase == "idle" || !this.IsOpen() {
            try SetTimer(this.AnimationTimer, 0)
            return
        }
        elapsed := DllCall("kernel32\GetTickCount64", "UInt64")
            - this.AnimationStartedTicks
        progress := Min(1, elapsed / this.AnimationDurationMs)
        easedProgress := 1 - ((1 - progress) ** 3)
        nextY := Round(this.AnimationFromY
            + (this.AnimationToY - this.AnimationFromY) * easedProgress)
        nextAlpha := Round(this.AnimationFromAlpha
            + (this.AnimationToAlpha - this.AnimationFromAlpha)
                * easedProgress)
        this.SetWindowPosition(this.CurrentX, nextY)
        this.SetWindowAlpha(nextAlpha)
        this.CurrentY := nextY

        if progress < 1
            return
        try SetTimer(this.AnimationTimer, 0)
        completedPhase := this.AnimationPhase
        this.AnimationPhase := "idle"
        if completedPhase == "show" {
            this.SetWindowAlpha(255)
            this.CurrentY := this.TargetY
            this.HideDeadlineTicks := DllCall("kernel32\GetTickCount64",
                "UInt64") + 3000
            SetTimer(this.HideTimer, -3000)
        } else {
            this.HideNow()
        }
    }

    ApplyRoundedRegion() {
        if !this.IsOpen()
            return false
        windowRect := Buffer(16, 0)
        if !DllCall("user32\GetWindowRect", "Ptr", this.Gui.Hwnd,
                "Ptr", windowRect, "Int")
            return false
        width := NumGet(windowRect, 8, "Int") - NumGet(windowRect, 0, "Int")
        height := NumGet(windowRect, 12, "Int") - NumGet(windowRect, 4, "Int")
        windowDpi := DllCall("user32\GetDpiForWindow", "Ptr", this.Gui.Hwnd,
            "UInt")
        radius := Max(8, Round(10 * (windowDpi ? windowDpi : 96) / 96))
        cornerDiameter := radius * 2
        region := DllCall("gdi32\CreateRoundRectRgn", "Int", 0, "Int", 0,
            "Int", width + 1, "Int", height + 1, "Int", cornerDiameter,
            "Int", cornerDiameter, "Ptr")
        if !region
            return false
        if DllCall("user32\SetWindowRgn", "Ptr", this.Gui.Hwnd, "Ptr",
                region, "Int", true, "Int")
            return true
        DllCall("gdi32\DeleteObject", "Ptr", region)
        return false
    }

    BeginHide(*) {
        try SetTimer(this.HideTimer, 0)
        this.HideDeadlineTicks := 0
        if !this.IsOpen() || !DllCall("user32\IsWindowVisible", "Ptr",
                this.Gui.Hwnd, "Int")
            return
        try SetTimer(this.AnimationTimer, 0)
        fromY := this.CurrentY ? this.CurrentY : this.TargetY
        fromAlpha := this.CurrentAlpha
        hideOffset := Round(8 * this.AnimationDpi / 96)
        this.BeginAnimation("hide", fromY, this.TargetY - hideOffset,
            fromAlpha, 0, 140)
    }

    Hide(*) {
        this.BeginHide()
    }

    HideNow() {
        try SetTimer(this.HideTimer, 0)
        try SetTimer(this.AnimationTimer, 0)
        this.HideDeadlineTicks := 0
        this.AnimationPhase := "idle"
        if this.IsOpen() {
            try this.Gui.Hide()
            try this.SetWindowAlpha(255)
        }
        this.CurrentAlpha := 255
        this.CurrentY := 0
        this.CurrentX := 0
        this.ToastWidth := 0
        this.ToastHeight := 0
    }

    CancelTimers() {
        try SetTimer(this.HideTimer, 0)
        try SetTimer(this.AnimationTimer, 0)
        this.HideDeadlineTicks := 0
        this.AnimationPhase := "idle"
    }

    RefreshAppearance(*) {
        if this.Disposed || !this.IsOpen()
            return false
        wasVisible := DllCall("user32\IsWindowVisible", "Ptr",
            this.Gui.Hwnd, "Int") != 0
        text := this.TextControl.Text
        this.CancelTimers()
        guiObj := this.Gui
        this.Gui := ""
        this.TextControl := ""
        try guiObj.Destroy()
        if wasVisible && text != ""
            return this.Show(text)
        return true
    }

    Dispose() {
        if this.Disposed
            return
        this.Disposed := true
        this.CancelTimers()
        if this.IsOpen() {
            guiObj := this.Gui
            this.Gui := ""
            this.TextControl := ""
            try guiObj.Destroy()
        }
        this.OwnerWindow := ""
        this.HideTimer := ""
        this.AnimationTimer := ""
    }
}
