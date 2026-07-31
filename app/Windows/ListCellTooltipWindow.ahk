; 只在 ListView 单元格文本确实被列宽截断时显示完整内容。

class ListCellTooltipWindow {
    __New(listView, minimumColumn := 1, maximumColumn := 0) {
        this.List := listView
        this.MinimumColumn := Max(1, Integer(minimumColumn))
        this.MaximumColumn := maximumColumn > 0
            ? Integer(maximumColumn) : listView.GetCount("Column")
        this.Gui := ""
        this.TextControl := ""
        this.PendingCell := ""
        this.VisibleCell := ""
        this.PendingText := ""
        this.WidthCache := Map()
        this.Disposed := false
        this.ShowTimer := ObjBindMethod(this, "ShowPending")
        this.MouseMoveCallback := ObjBindMethod(this, "OnMouseMove")
        this.MouseLeaveCallback := ObjBindMethod(this, "OnMouseLeave")
        this.MouseWheelCallback := ObjBindMethod(this, "OnMouseWheel")
        try {
            OnMessage(0x0200, this.MouseMoveCallback) ; WM_MOUSEMOVE
            OnMessage(0x02A3, this.MouseLeaveCallback) ; WM_MOUSELEAVE
            OnMessage(0x020A, this.MouseWheelCallback) ; WM_MOUSEWHEEL
        } catch as registrationError {
            try this.Dispose()
            throw registrationError
        }
    }

    OnMouseMove(wParam, lParam, msg, hwnd) {
        if this.Disposed
            return
        if hwnd != this.List.Hwnd {
            this.Hide()
            return
        }
        this.TrackMouseLeave()
        cell := this.HitTestCell(lParam)
        if !IsObject(cell) || cell.Column < this.MinimumColumn
                || cell.Column > this.MaximumColumn {
            this.Hide()
            return
        }
        text := this.List.GetText(cell.Row, cell.Column)
        cellKey := cell.Row ":" cell.Column ":" text
        if cellKey == this.PendingCell || cellKey == this.VisibleCell
            return
        if text == "" || !this.IsCellClipped(cell.Row, cell.Column, text) {
            this.Hide()
            return
        }
        this.Hide()
        this.PendingCell := cellKey
        this.PendingText := text
        SetTimer(this.ShowTimer, -350)
    }

    HitTestCell(lParam) {
        hitTest := Buffer(24, 0)
        NumPut("Int", this.SignedWord(lParam), hitTest, 0)
        NumPut("Int", this.SignedWord(lParam >> 16), hitTest, 4)
        itemIndex := SendMessage(0x1039, 0, hitTest.Ptr, , this.List.Hwnd)
        flags := NumGet(hitTest, 8, "UInt")
        if itemIndex < 0 || !(flags & 0x0E)
            return false
        return {Row: itemIndex + 1,
            Column: NumGet(hitTest, 16, "Int") + 1}
    }

    IsCellClipped(row, column, text) {
        rect := Buffer(16, 0)
        NumPut("Int", 2, rect, 0) ; LVIR_LABEL
        NumPut("Int", column - 1, rect, 4)
        if !SendMessage(0x1038, row - 1, rect.Ptr, , this.List.Hwnd)
            return false
        availableWidth := NumGet(rect, 8, "Int") - NumGet(rect, 0, "Int") - 8
        if availableWidth <= 0
            return false
        return this.MeasureTextWidth(text) > availableWidth
    }

    MeasureTextWidth(text) {
        fontHandle := SendMessage(0x0031, 0, 0, , this.List.Hwnd)
        cacheKey := fontHandle ":" text
        if this.WidthCache.Has(cacheKey)
            return this.WidthCache[cacheKey]
        deviceContext := DllCall("user32\GetDC", "Ptr", this.List.Hwnd, "Ptr")
        if !deviceContext
            return 0
        previousFont := fontHandle
            ? DllCall("gdi32\SelectObject", "Ptr", deviceContext,
                "Ptr", fontHandle, "Ptr") : 0
        extent := Buffer(8, 0)
        try DllCall("gdi32\GetTextExtentPoint32W", "Ptr", deviceContext,
            "Str", text, "Int", StrLen(text), "Ptr", extent, "Int")
        finally {
            if previousFont
                DllCall("gdi32\SelectObject", "Ptr", deviceContext,
                    "Ptr", previousFont, "Ptr")
            DllCall("user32\ReleaseDC", "Ptr", this.List.Hwnd,
                "Ptr", deviceContext)
        }
        width := NumGet(extent, 0, "Int")
        if this.WidthCache.Count >= 256
            this.WidthCache.Clear()
        this.WidthCache[cacheKey] := width
        return width
    }

    ShowPending(*) {
        if this.Disposed || this.PendingCell == "" || this.PendingText == ""
            return
        if !DllCall("user32\IsWindowVisible", "Ptr", this.List.Hwnd, "Int")
            return this.Hide()
        colors := UiThemeService.GetPalette()
        if !IsObject(this.Gui) {
            this.Gui := Gui("-Caption +ToolWindow +AlwaysOnTop +E0x08000020")
            this.Gui.BackColor := colors.Tooltip
            this.Gui.MarginX := 12
            this.Gui.MarginY := 8
            this.Gui.SetFont("s10 c" colors.TooltipText,
                LocalizationService.GetUiFontName())
            this.TextControl := this.Gui.Add("Text", "w420 +Wrap Background"
                colors.Tooltip " c" colors.TooltipText, this.PendingText)
            if VerCompare(A_OSVersion, "10.0.22000") >= 0
                try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", this.Gui.Hwnd,
                    "Int", 33, "Int*", 2, "Int", 4)
        } else {
            this.TextControl.Text := this.PendingText
        }
        this.VisibleCell := this.PendingCell
        point := Buffer(8, 0)
        DllCall("user32\GetCursorPos", "Ptr", point)
        x := NumGet(point, 0, "Int") + 12
        y := NumGet(point, 4, "Int") + 20
        workArea := this.GetWorkArea(x, y)
        tooltipDpi := DllCall("user32\GetDpiForWindow", "Ptr",
            this.List.Hwnd, "UInt")
        if !tooltipDpi
            tooltipDpi := 96
        maximumTextWidth := Max(80,
            Floor((workArea.Right - workArea.Left - 32) * 96 / tooltipDpi))
        this.TextControl.Move(, , Min(420, maximumTextWidth))
        this.Gui.Show("Hide AutoSize")
        this.Gui.GetPos(, , &tooltipWidth, &tooltipHeight)
        maximumWidth := Max(1, workArea.Right - workArea.Left - 8)
        maximumHeight := Max(1, workArea.Bottom - workArea.Top - 8)
        tooltipWidth := Min(tooltipWidth, maximumWidth)
        tooltipHeight := Min(tooltipHeight, maximumHeight)
        this.ConstrainToWorkArea(&x, &y, tooltipWidth, tooltipHeight, workArea)
        this.Gui.Show("x" x " y" y " w" tooltipWidth " h" tooltipHeight
            " NoActivate")
    }

    GetWorkArea(x, y) {
        monitorCount := MonitorGetCount()
        target := 0
        Loop monitorCount {
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

    ConstrainToWorkArea(&x, &y, width, height, workArea := "") {
        if !IsObject(workArea)
            workArea := this.GetWorkArea(x, y)
        maximumX := Max(workArea.Left + 4, workArea.Right - width - 4)
        maximumY := Max(workArea.Top + 4, workArea.Bottom - height - 4)
        x := Min(Max(x, workArea.Left + 4), maximumX)
        y := Min(Max(y, workArea.Top + 4), maximumY)
    }

    TrackMouseLeave() {
        size := A_PtrSize == 8 ? 24 : 16
        tracking := Buffer(size, 0)
        NumPut("UInt", size, tracking, 0)
        NumPut("UInt", 0x00000002, tracking, 4)
        NumPut("Ptr", this.List.Hwnd, tracking, 8)
        try DllCall("user32\TrackMouseEvent", "Ptr", tracking)
    }

    OnMouseLeave(wParam, lParam, msg, hwnd) {
        if hwnd == this.List.Hwnd
            this.Hide()
    }

    OnMouseWheel(*) {
        this.Hide()
    }

    SignedWord(value) {
        value &= 0xFFFF
        return value & 0x8000 ? value - 0x10000 : value
    }

    Hide(*) {
        SetTimer(this.ShowTimer, 0)
        this.PendingCell := ""
        this.PendingText := ""
        this.VisibleCell := ""
        if IsObject(this.Gui)
            this.Gui.Hide()
    }

    InvalidateMeasurements() {
        this.WidthCache.Clear()
        this.Hide()
    }

    Dispose() {
        if this.Disposed
            return
        this.Disposed := true
        cleanup := CleanupCollector("列表单元格提示")
        hidden := cleanup.Run("隐藏窗口", () => this.Hide())
        moveReleased := cleanup.Run("注销移动消息",
            () => OnMessage(0x0200, this.MouseMoveCallback, 0))
        leaveReleased := cleanup.Run("注销离开消息",
            () => OnMessage(0x02A3, this.MouseLeaveCallback, 0))
        wheelReleased := cleanup.Run("注销滚轮消息",
            () => OnMessage(0x020A, this.MouseWheelCallback, 0))
        if IsObject(this.Gui)
                && cleanup.Run("销毁窗口", () => this.Gui.Destroy())
            this.Gui := ""
        this.TextControl := ""
        this.List := ""
        if hidden
            this.ShowTimer := ""
        if moveReleased
            this.MouseMoveCallback := ""
        if leaveReleased
            this.MouseLeaveCallback := ""
        if wheelReleased
            this.MouseWheelCallback := ""
        this.WidthCache.Clear()
        cleanup.Complete()
        return true
    }
}
