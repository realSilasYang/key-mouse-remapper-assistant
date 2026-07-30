; Theme-aware, non-activating hover tooltip shared by owner-drawn buttons.
class DarkTooltipWindow {
    __New(ownerGui) {
        this.OwnerGui := ownerGui
        this.Gui := ""
        this.TextControl := ""
        this.PendingHwnd := 0
        this.VisibleHwnd := 0
        this.PendingText := ""
        this.MeasurementCache := Map()
        this.Disposed := false
        this.ShowTimer := ObjBindMethod(this, "ShowPending")
        this.WheelCallback := ObjBindMethod(this, "OnMouseWheel")
        this.ShowWindowCallback := ObjBindMethod(this, "OnOwnerShowWindow")
        this.ActivateCallback := ObjBindMethod(this, "OnOwnerActivate")
        try {
            OnMessage(0x020A, this.WheelCallback) ; WM_MOUSEWHEEL
            OnMessage(0x0018, this.ShowWindowCallback) ; WM_SHOWWINDOW
            OnMessage(0x0006, this.ActivateCallback) ; WM_ACTIVATE
        } catch as registrationError {
            this.Dispose()
            throw registrationError
        }
    }

    Schedule(hwnd, text, delayMs := 500) {
        if this.Disposed || !this.IsOwnerVisible()
            return false
        text := RTrim(String(text), "`r`n")
        if !hwnd || text == ""
            return this.Hide()
        if this.PendingHwnd == hwnd && this.PendingText == text
            return true
        this.Hide()
        this.PendingHwnd := hwnd
        this.PendingText := text
        SetTimer(this.ShowTimer, -Max(1, Integer(delayMs)))
        return true
    }

    ShowPending(*) {
        if this.Disposed || !this.PendingHwnd || this.PendingText == ""
            return false
        hwnd := this.PendingHwnd
        text := this.PendingText
        if !this.IsOwnerVisible() || !this.IsPointerInside(hwnd)
            return this.Hide()
        this.EnsureWindow(text)
        if !IsObject(this.Gui)
            return false

        windowDpi := DllCall("user32\GetDpiForWindow", "Ptr", hwnd, "UInt")
        if !windowDpi
            windowDpi := 96
        point := Buffer(8, 0)
        DllCall("user32\GetCursorPos", "Ptr", point)
        x := NumGet(point, 0, "Int") + Round(12 * windowDpi / 96)
        y := NumGet(point, 4, "Int") + Round(20 * windowDpi / 96)
        workArea := this.GetWorkArea(x, y)
        maximumTextWidth := Max(80,
            Floor((workArea.Right - workArea.Left - 32) * 96 / windowDpi))
        size := this.MeasureText(text, Min(440, maximumTextWidth), windowDpi)
        this.TextControl.Move(, , size.Width, size.Height)
        this.Gui.Show("Hide AutoSize")
        this.Gui.GetPos(, , &tooltipWidth, &tooltipHeight)
        tooltipWidth := Min(tooltipWidth,
            Max(1, workArea.Right - workArea.Left - 8))
        tooltipHeight := Min(tooltipHeight,
            Max(1, workArea.Bottom - workArea.Top - 8))
        this.ConstrainToWorkArea(&x, &y, tooltipWidth, tooltipHeight,
            workArea)
        this.VisibleHwnd := hwnd
        this.Gui.Show("x" x " y" y " w" tooltipWidth " h" tooltipHeight
            " NoActivate")
        return true
    }

    EnsureWindow(text) {
        colors := UiThemeService.GetPalette()
        if !IsObject(this.Gui) {
            this.Gui := Gui("-Caption +ToolWindow +AlwaysOnTop +E0x08000020")
            this.Gui.BackColor := colors.Tooltip
            this.Gui.MarginX := 12
            this.Gui.MarginY := 8
            this.Gui.SetFont("s9 c" colors.TooltipText,
                LocalizationService.GetUiFontName())
            this.TextControl := this.Gui.Add("Text", "Background"
                colors.Tooltip " c" colors.TooltipText " +Wrap", text)
            if VerCompare(A_OSVersion, "10.0.22000") >= 0
                try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr",
                    this.Gui.Hwnd, "Int", 33, "Int*", 2, "Int", 4)
        } else {
            this.TextControl.Text := text
        }
    }

    MeasureText(text, maximumWidthDip, windowDpi) {
        cacheKey := windowDpi ":" maximumWidthDip ":" text
        if this.MeasurementCache.Has(cacheKey)
            return this.MeasurementCache[cacheKey]
        deviceContext := DllCall("user32\GetDC", "Ptr",
            this.TextControl.Hwnd, "Ptr")
        if !deviceContext
            return {Width: maximumWidthDip, Height: 20}
        fontHandle := SendMessage(0x0031, 0, 0, , this.TextControl.Hwnd)
        previousFont := fontHandle ? DllCall("gdi32\SelectObject", "Ptr",
            deviceContext, "Ptr", fontHandle, "Ptr") : 0
        try {
            maximumWidthPx := Max(1,
                Round(maximumWidthDip * windowDpi / 96))
            naturalWidthPx := 1
            Loop Parse, text, "`n", "`r" {
                lineText := A_LoopField != "" ? A_LoopField : " "
                extent := Buffer(8, 0)
                if DllCall("gdi32\GetTextExtentPoint32W", "Ptr",
                    deviceContext, "Str", lineText, "Int", StrLen(lineText),
                    "Ptr", extent, "Int")
                    naturalWidthPx := Max(naturalWidthPx,
                        NumGet(extent, 0, "Int"))
            }
            textWidthPx := Min(naturalWidthPx, maximumWidthPx)
            measureRect := Buffer(16, 0)
            NumPut("Int", textWidthPx, measureRect, 8)
            DllCall("user32\DrawTextW", "Ptr", deviceContext, "Str", text,
                "Int", -1, "Ptr", measureRect, "UInt", 0x0C50, "Int")
            textHeightPx := Max(1, NumGet(measureRect, 12, "Int"))
            size := {
                Width: Max(1, Ceil(textWidthPx * 96 / windowDpi)),
                Height: Max(1, Ceil(textHeightPx * 96 / windowDpi))
            }
            if this.MeasurementCache.Count >= 64
                this.MeasurementCache.Clear()
            this.MeasurementCache[cacheKey] := size
            return size
        } finally {
            if previousFont
                DllCall("gdi32\SelectObject", "Ptr", deviceContext,
                    "Ptr", previousFont, "Ptr")
            DllCall("user32\ReleaseDC", "Ptr", this.TextControl.Hwnd,
                "Ptr", deviceContext)
        }
    }

    IsOwnerVisible() {
        if !IsObject(this.OwnerGui)
            return false
        try ownerHwnd := this.OwnerGui.Hwnd
        catch
            return false
        return ownerHwnd
            && DllCall("user32\IsWindowVisible", "Ptr", ownerHwnd, "Int")
            && !DllCall("user32\IsIconic", "Ptr", ownerHwnd, "Int")
    }

    IsPointerInside(hwnd) {
        if !hwnd || !DllCall("user32\IsWindow", "Ptr", hwnd, "Int")
            return false
        point := Buffer(8, 0)
        rect := Buffer(16, 0)
        DllCall("user32\GetCursorPos", "Ptr", point)
        DllCall("user32\GetWindowRect", "Ptr", hwnd, "Ptr", rect)
        x := NumGet(point, 0, "Int")
        y := NumGet(point, 4, "Int")
        return x >= NumGet(rect, 0, "Int") && x < NumGet(rect, 8, "Int")
            && y >= NumGet(rect, 4, "Int") && y < NumGet(rect, 12, "Int")
    }

    GetWorkArea(x, y) {
        target := 0
        Loop MonitorGetCount() {
            MonitorGetWorkArea(A_Index, &left, &top, &right, &bottom)
            if x >= left && x < right && y >= top && y < bottom {
                target := A_Index
                break
            }
        }
        if !target
            target := MonitorGetPrimary()
        MonitorGetWorkArea(target, &left, &top, &right, &bottom)
        return {Left: left, Top: top, Right: right, Bottom: bottom}
    }

    ConstrainToWorkArea(&x, &y, width, height, workArea) {
        maximumX := Max(workArea.Left + 4, workArea.Right - width - 4)
        maximumY := Max(workArea.Top + 4, workArea.Bottom - height - 4)
        x := Min(Max(x, workArea.Left + 4), maximumX)
        y := Min(Max(y, workArea.Top + 4), maximumY)
    }

    OnMouseWheel(*) {
        this.Hide()
    }

    OnOwnerShowWindow(wParam, lParam, msg, hwnd) {
        try ownerHwnd := this.OwnerGui.Hwnd
        catch
            return
        if hwnd == ownerHwnd && !wParam
            this.Hide()
    }

    OnOwnerActivate(wParam, lParam, msg, hwnd) {
        try ownerHwnd := this.OwnerGui.Hwnd
        catch
            return
        if hwnd == ownerHwnd && (wParam & 0xFFFF) == 0
            this.Hide()
    }

    InvalidateTheme() {
        this.Hide()
        this.MeasurementCache.Clear()
        if IsObject(this.Gui)
            try this.Gui.Destroy()
        this.Gui := ""
        this.TextControl := ""
    }

    Hide(*) {
        try SetTimer(this.ShowTimer, 0)
        this.PendingHwnd := 0
        this.VisibleHwnd := 0
        this.PendingText := ""
        if IsObject(this.Gui)
            try this.Gui.Hide()
        return false
    }

    Dispose() {
        if this.Disposed
            return
        this.Disposed := true
        this.Hide()
        try OnMessage(0x020A, this.WheelCallback, 0)
        try OnMessage(0x0018, this.ShowWindowCallback, 0)
        try OnMessage(0x0006, this.ActivateCallback, 0)
        if IsObject(this.Gui)
            try this.Gui.Destroy()
        this.Gui := ""
        this.TextControl := ""
        this.OwnerGui := ""
        this.ShowTimer := ""
        this.WheelCallback := ""
        this.ShowWindowCallback := ""
        this.ActivateCallback := ""
        this.MeasurementCache.Clear()
    }
}
