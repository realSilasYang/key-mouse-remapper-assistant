; 隐藏原生表头后的可点击伪表头。排序只改变当前 ListView 投影，不修改源码顺序。

class ListViewPseudoHeader {
    static DefaultHeight := 28
    static InputGuardSubclassId := 0x4C565048
    static InputGuardCallback := 0
    static PressedCellHwnd := 0

    static EnsureInputGuardCallback() {
        if this.InputGuardCallback
            return true
        try this.InputGuardCallback := CallbackCreate(
            ListViewPseudoHeaderCellProc, "", 6)
        catch
            this.InputGuardCallback := 0
        return this.InputGuardCallback != 0
    }

    static AttachInputGuard(cellHwnd, listHwnd) {
        if !cellHwnd || !listHwnd || !this.EnsureInputGuardCallback()
            return false
        return !!DllCall("comctl32\SetWindowSubclass", "Ptr", cellHwnd,
            "Ptr", this.InputGuardCallback, "UPtr", this.InputGuardSubclassId,
            "UPtr", listHwnd, "Int")
    }

    __New(guiObj, listView, columns, options := "") {
        if !guiObj || Type(guiObj) != "Gui"
            throw TypeError("伪表头所属 GUI 无效")
        if !IsObject(listView) || Type(columns) != "Array" || !columns.Length
            throw TypeError("伪表头缺少 ListView 或列定义")
        this.Gui := guiObj
        this.List := listView
        this.Columns := []
        this.Cells := []
        this.CellCallbacks := Map()
        this.Disposed := false
        this.SortDisplayColumn := 0
        this.SortDescending := false
        this.OnBeforeSort := this.GetOption(options, "OnBeforeSort", "")
        this.OnSortChanged := this.GetOption(options, "OnSortChanged", "")
        try this.RestoreColumn := Max(0, Integer(this.GetOption(options,
            "RestoreColumn", 0)))
        catch
            throw ValueError("伪表头恢复顺序列无效")
        this.RestoreSortOptions := Trim(String(this.GetOption(options,
            "RestoreSortOptions", "Integer")))
        this.CursorRegistrar := this.GetOption(options, "CursorRegistrar", "")
        this.BackgroundColor := this.GetOption(options, "BackgroundColor",
            UiThemeService.Color("Toolbar"))
        this.TextColor := this.GetOption(options, "TextColor",
            UiThemeService.Color("MutedText"))
        this.FontName := this.GetOption(options, "FontName",
            LocalizationService.GetLanguageSystemUiFontName())
        this.FontSize := this.GetOption(options, "FontSize", 9)
        this.Height := Max(1, Integer(this.GetOption(options, "Height",
            ListViewPseudoHeader.DefaultHeight)))

        try {
        this.Background := guiObj.Add("Text", "x0 y0 w1 h" this.Height
            " Background" this.BackgroundColor)
        for displayColumn, columnSpec in columns {
            if !IsObject(columnSpec) || !columnSpec.HasOwnProp("Column")
                throw TypeError("伪表头列定义无效")
            columnIndex := Integer(columnSpec.Column)
            if columnIndex < 1
                throw ValueError("伪表头列索引无效")
            alignment := columnSpec.HasOwnProp("Align")
                ? String(columnSpec.Align) : "Left"
            padding := columnSpec.HasOwnProp("Padding")
                ? String(columnSpec.Padding)
                : (StrLower(alignment) == "left" ? "  " : "")
            this.Columns.Push({
                Column: columnIndex,
                Label: columnSpec.HasOwnProp("Label")
                    ? String(columnSpec.Label) : "",
                Align: alignment,
                Padding: padding,
                SortOptions: columnSpec.HasOwnProp("SortOptions")
                    ? Trim(String(columnSpec.SortOptions)) : "",
                SkipAscending: columnSpec.HasOwnProp("SkipAscending")
                    && !!columnSpec.SkipAscending
            })
            alignOption := StrLower(alignment) == "center" ? " Center"
                : (StrLower(alignment) == "right" ? " Right" : "")
            cell := guiObj.Add("Text", "x0 y0 w1 h" this.Height
                " -Tabstop 0x200" alignOption " Background"
                this.BackgroundColor " c" this.TextColor, "")
            if !ListViewPseudoHeader.AttachInputGuard(cell.Hwnd, listView.Hwnd)
                throw Error("伪表头输入保护安装失败")
            callback := ObjBindMethod(this, "SortByDisplayColumn", displayColumn)
            this.Cells.Push(cell)
            this.CellCallbacks[cell.Hwnd] := callback
            cell.OnEvent("Click", callback)
            cell.OnEvent("DoubleClick", callback)
            if IsObject(this.CursorRegistrar)
                this.CursorRegistrar.Call(cell)
        }
        this.ApplyAppearance(this.BackgroundColor, this.TextColor,
            this.FontName, this.FontSize)
        this.RefreshLabels()
        } catch as constructionError {
            this.Dispose()
            throw constructionError
        }
    }

    GetOption(options, name, defaultValue) {
        return IsObject(options) && options.HasOwnProp(name)
            ? options.%name% : defaultValue
    }

    SetBounds(x, y, columnWidths, totalWidth := "") {
        if Type(columnWidths) != "Array"
            || columnWidths.Length != this.Cells.Length
            return false
        widths := []
        summedWidth := 0
        for width in columnWidths {
            try width := Max(0, Integer(width))
            catch
                return false
            widths.Push(width)
            summedWidth += width
        }
        if totalWidth == ""
            totalWidth := summedWidth
        try totalWidth := Max(summedWidth, Integer(totalWidth))
        catch
            return false
        this.Background.Move(x, y, totalWidth, this.Height)
        cellX := x
        for displayColumn, cell in this.Cells {
            cell.Move(cellX, y, widths[displayColumn], this.Height)
            cellX += widths[displayColumn]
        }
        return true
    }

    SetLabels(labels) {
        if Type(labels) != "Array" || labels.Length != this.Columns.Length
            return false
        for displayColumn, label in labels
            this.Columns[displayColumn].Label := String(label)
        this.RefreshLabels()
        return true
    }

    ApplyAppearance(backgroundColor, textColor, fontName := "",
        fontSize := "") {
        this.BackgroundColor := String(backgroundColor)
        this.TextColor := String(textColor)
        if fontName != ""
            this.FontName := String(fontName)
        if fontSize != ""
            this.FontSize := fontSize
        this.Background.Opt("Background" this.BackgroundColor)
        for cell in this.Cells {
            cell.Opt("Background" this.BackgroundColor)
            cell.SetFont("s" this.FontSize " bold c" this.TextColor,
                this.FontName)
        }
        this.Background.Redraw()
        for cell in this.Cells
            cell.Redraw()
    }

    SortByDisplayColumn(displayColumn, *) {
        if displayColumn < 1 || displayColumn > this.Columns.Length
            return false
        previousDisplayColumn := this.SortDisplayColumn
        previousDescending := this.SortDescending
        if previousDisplayColumn == displayColumn {
            if this.SortDescending
                return this.RestoreOrder()
        }
        try {
            if previousDisplayColumn {
                previousColumn := this.Columns[previousDisplayColumn].Column
                this.List.ModifyCol(previousColumn, "NoSort")
            }
            this.SortDisplayColumn := displayColumn
            this.SortDescending := previousDisplayColumn == displayColumn
                ? true : this.Columns[displayColumn].SkipAscending
            this.NotifyBeforeSort()
            if !this.ApplyCurrentSort()
                throw Error("Unable to apply the pseudo-header sort")
        } catch {
            try {
                if this.HasActiveSort()
                    this.List.ModifyCol(this.GetSortColumn(), "NoSort")
            }
            this.SortDisplayColumn := previousDisplayColumn
            this.SortDescending := previousDescending
            if this.HasActiveSort()
                try this.ApplyCurrentSort()
            this.RefreshLabels()
            return false
        }
        this.RefreshLabels()
        this.NotifySortChanged(this.GetSortColumn(), this.SortDescending)
        return true
    }

    NotifyBeforeSort() {
        if this.HasActiveSort() && IsObject(this.OnBeforeSort)
            this.OnBeforeSort.Call(this, this.GetSortColumn(),
                this.SortDescending)
    }

    ApplyCurrentSort() {
        if !this.HasActiveSort()
            return false
        columnSpec := this.Columns[this.SortDisplayColumn]
        direction := this.SortDescending ? "SortDesc" : "Sort"
        this.List.ModifyCol(columnSpec.Column,
            Trim(columnSpec.SortOptions " " columnSpec.Align " " direction))
        return true
    }

    ClearSort() {
        if this.HasActiveSort() {
            try this.List.ModifyCol(this.GetSortColumn(), "NoSort")
            catch
                return false
        }
        this.SortDisplayColumn := 0
        this.SortDescending := false
        this.RefreshLabels()
        return true
    }

    RestoreOrder() {
        previousDisplayColumn := this.SortDisplayColumn
        previousDescending := this.SortDescending
        this.NotifyBeforeSort()
        if !this.ClearSort()
            return false
        if this.RestoreColumn {
            try {
                options := Trim(this.RestoreSortOptions " Sort")
                this.List.ModifyCol(this.RestoreColumn, options)
                this.List.ModifyCol(this.RestoreColumn, "NoSort")
            } catch {
                this.SortDisplayColumn := previousDisplayColumn
                this.SortDescending := previousDescending
                try this.ApplyCurrentSort()
                this.RefreshLabels()
                return false
            }
        }
        this.NotifySortChanged(0, false)
        return true
    }

    NotifySortChanged(column, descending) {
        if IsObject(this.OnSortChanged)
            this.OnSortChanged.Call(this, column, descending)
    }

    HasActiveSort() {
        return this.SortDisplayColumn >= 1
            && this.SortDisplayColumn <= this.Columns.Length
    }

    GetSortColumn() {
        return this.HasActiveSort()
            ? this.Columns[this.SortDisplayColumn].Column : 0
    }

    RefreshLabels() {
        for displayColumn, cell in this.Cells {
            spec := this.Columns[displayColumn]
            indicator := displayColumn == this.SortDisplayColumn
                ? (this.SortDescending ? " ↓" : " ↑") : ""
            this.SetCellTextNoErase(cell, spec.Padding spec.Label indicator)
        }
    }

    SetCellTextNoErase(cell, text) {
        text := String(text)
        if cell.Text == text
            return false
        DllCall("user32\SendMessageW", "Ptr", cell.Hwnd,
            "UInt", Win32.WM_SETREDRAW, "UPtr", 0, "Ptr", 0, "Ptr")
        try cell.Text := text
        finally DllCall("user32\SendMessageW", "Ptr", cell.Hwnd,
            "UInt", Win32.WM_SETREDRAW, "UPtr", 1, "Ptr", 0, "Ptr")
        DllCall("user32\RedrawWindow", "Ptr", cell.Hwnd,
            "Ptr", 0, "Ptr", 0, "UInt", Win32.RDW_BUTTON_REFRESH, "Int")
        return true
    }

    Dispose() {
        if this.Disposed
            return true
        this.Disposed := true
        for cell in this.Cells {
            hwnd := 0
            try hwnd := cell.Hwnd
            if hwnd && this.CellCallbacks.Has(hwnd) {
                callback := this.CellCallbacks[hwnd]
                try cell.OnEvent("Click", callback, 0)
                try cell.OnEvent("DoubleClick", callback, 0)
            }
            if hwnd && ListViewPseudoHeader.PressedCellHwnd == hwnd {
                ListViewPseudoHeader.PressedCellHwnd := 0
                if DllCall("user32\GetCapture", "Ptr") == hwnd
                    try DllCall("user32\ReleaseCapture", "Int")
            }
            if hwnd && ListViewPseudoHeader.InputGuardCallback
                    && DllCall("user32\IsWindow", "Ptr", hwnd, "Int") {
                try DllCall("comctl32\RemoveWindowSubclass", "Ptr", hwnd,
                    "Ptr", ListViewPseudoHeader.InputGuardCallback,
                    "UPtr", ListViewPseudoHeader.InputGuardSubclassId, "Int")
            }
        }
        this.CellCallbacks.Clear()
        this.Cells := []
        this.Columns := []
        this.OnBeforeSort := ""
        this.OnSortChanged := ""
        this.CursorRegistrar := ""
        this.Background := ""
        this.List := ""
        this.Gui := ""
        return true
    }
}

ListViewPseudoHeaderCellProc(hWnd, message, wParam, lParam, subclassId,
    listHwnd) {
    try {
        switch message {
            case Win32.WM_SETFOCUS:
                if listHwnd && DllCall("user32\IsWindow", "Ptr", listHwnd,
                        "Int")
                    DllCall("user32\SetFocus", "Ptr", listHwnd, "Ptr")
                return 0
            case Win32.WM_LBUTTONDOWN, Win32.WM_LBUTTONDBLCLK:
                if listHwnd && DllCall("user32\IsWindow", "Ptr", listHwnd,
                        "Int")
                    DllCall("user32\SetFocus", "Ptr", listHwnd, "Ptr")
                ListViewPseudoHeader.PressedCellHwnd := hWnd
                DllCall("user32\SetCapture", "Ptr", hWnd, "Ptr")
                return 0
            case Win32.WM_LBUTTONUP:
                if ListViewPseudoHeader.PressedCellHwnd != hWnd
                    return 0
                ListViewPseudoHeader.PressedCellHwnd := 0
                if DllCall("user32\GetCapture", "Ptr") == hWnd
                    DllCall("user32\ReleaseCapture", "Int")
                rect := Buffer(16, 0)
                if !DllCall("user32\GetClientRect", "Ptr", hWnd,
                        "Ptr", rect, "Int")
                    return 0
                x := lParam & 0xFFFF
                y := (lParam >> 16) & 0xFFFF
                if x & 0x8000
                    x -= 0x10000
                if y & 0x8000
                    y -= 0x10000
                if x < 0 || y < 0 || x >= NumGet(rect, 8, "Int")
                    || y >= NumGet(rect, 12, "Int")
                    return 0
                parentHwnd := DllCall("user32\GetParent", "Ptr", hWnd, "Ptr")
                controlId := DllCall("user32\GetDlgCtrlID", "Ptr", hWnd, "Int")
                if parentHwnd
                    DllCall("user32\SendMessageW", "Ptr", parentHwnd,
                        "UInt", Win32.WM_COMMAND, "UPtr", controlId & 0xFFFF,
                        "Ptr", hWnd, "Ptr")
                return 0
            case Win32.WM_CANCELMODE:
                if ListViewPseudoHeader.PressedCellHwnd == hWnd {
                    ListViewPseudoHeader.PressedCellHwnd := 0
                    if DllCall("user32\GetCapture", "Ptr") == hWnd
                        DllCall("user32\ReleaseCapture", "Int")
                }
                return 0
            case Win32.WM_CAPTURECHANGED:
                if ListViewPseudoHeader.PressedCellHwnd == hWnd
                    ListViewPseudoHeader.PressedCellHwnd := 0
            case 0x007B, 0x0301:
                return 0
            case Win32.WM_NCDESTROY:
                if ListViewPseudoHeader.PressedCellHwnd == hWnd
                    ListViewPseudoHeader.PressedCellHwnd := 0
                if ListViewPseudoHeader.InputGuardCallback
                    DllCall("comctl32\RemoveWindowSubclass", "Ptr", hWnd,
                        "Ptr", ListViewPseudoHeader.InputGuardCallback,
                        "UPtr", subclassId, "Int")
        }
    } catch {
    }
    return DllCall("comctl32\DefSubclassProc", "Ptr", hWnd,
        "UInt", message, "UPtr", wParam, "Ptr", lParam, "Ptr")
}
