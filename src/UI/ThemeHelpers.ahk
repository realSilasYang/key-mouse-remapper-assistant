ApplyDarkWindow(hwnd) {
    if !IsThemeableWindow(hwnd)
        return false
    attribute := VerCompare(A_OSVersion, "10.0.18985") >= 0 ? 20 : 19
    darkValue := UiThemeService.IsDark() ? 1 : 0
    titleApplied := false
    try titleApplied := DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hwnd,
        "Int", attribute, "Int*", darkValue, "Int", 4) >= 0
    modeAllowed := AllowDarkModeForWindow(hwnd, darkValue)
    ; 顶层窗口使用各自的 Gui.BackColor。DarkMode_Explorer 会安装系统背景刷，
    ; 覆盖应用调色板；原生子控件在各自的 ApplyDarkControl 中单独设置主题。
    RedrawNativeTheme(hwnd, true)
    return titleApplied || modeAllowed
}

ApplyDarkListView(hwnd) {
    if !IsThemeableWindow(hwnd)
        return false
    themeApplied := ApplyDarkControl(hwnd, DarkExplorerThemeName())
    header := SendMessage(0x101F, 0, 0, , hwnd)
    if header {
        headerApplied := ApplyDarkControl(header, DarkItemsViewThemeName())
        themeApplied := themeApplied && headerApplied
    }
    colors := UiThemeService.GetPalette()
    SendMessage(0x1001, 0, ColorRef(colors.Surface), , hwnd)
    SendMessage(0x1024, 0, ColorRef(colors.Text), , hwnd)
    SendMessage(0x1026, 0, ColorRef(colors.Surface), , hwnd)
    RedrawNativeTheme(hwnd, true)
    return themeApplied
}

ApplyDarkControl(hwnd, themeName := "") {
    if !IsThemeableWindow(hwnd)
        return false
    if themeName == ""
        themeName := DarkExplorerThemeName()
    AllowDarkModeForWindow(hwnd, UiThemeService.IsDark())
    themeApplied := SetNativeWindowTheme(hwnd, themeName)
    ; SetWindowTheme 会同时改变边框、箭头和原生滚动条。重绘完整非客户区，
    ; 避免控件已切为深色但滚动条仍保留创建时的浅色缓存。
    RedrawNativeTheme(hwnd, true)
    return themeApplied
}

IsThemeableWindow(hwnd) {
    return hwnd && VerCompare(A_OSVersion, "10.0.17763") >= 0
        && DllCall("user32\IsWindow", "Ptr", hwnd, "Int")
}

SetNativeWindowTheme(hwnd, themeName) {
    themeApplied := false
    try themeApplied := DllCall("uxtheme\SetWindowTheme", "Ptr", hwnd,
        "Str", themeName, "Ptr", 0, "Int") == 0
    catch
        themeApplied := false
    return themeApplied
}

RedrawNativeTheme(hwnd, includeChildren := false) {
    if !hwnd || !DllCall("user32\IsWindow", "Ptr", hwnd, "Int")
        return false
    ; RDW_INVALIDATE | RDW_ERASE | RDW_FRAME，顶层窗口再包含 RDW_ALLCHILDREN。
    flags := 0x0405 | (includeChildren ? 0x0080 : 0)
    try return !!DllCall("user32\RedrawWindow", "Ptr", hwnd, "Ptr", 0,
        "Ptr", 0, "UInt", flags, "Int")
    catch
        return false
}

BeginStableWindowUpdate(hwnd) {
    if !hwnd || !DllCall("user32\IsWindow", "Ptr", hwnd, "Int")
        return false
    SendMessage(Win32.WM_SETREDRAW, 0, 0, , hwnd)
    return true
}

EndStableWindowUpdate(hwnd, eraseBackground := false) {
    if !hwnd || !DllCall("user32\IsWindow", "Ptr", hwnd, "Int")
        return false
    SendMessage(Win32.WM_SETREDRAW, 1, 0, , hwnd)
    return RedrawStableWindow(hwnd, eraseBackground)
}

RedrawStableWindow(hwnd, eraseBackground := false) {
    if !hwnd || !DllCall("user32\IsWindow", "Ptr", hwnd, "Int")
        return false
    flags := 0x0181 | (eraseBackground ? 0x0004 : 0)
    return !!DllCall("user32\RedrawWindow", "Ptr", hwnd, "Ptr", 0,
        "Ptr", 0, "UInt", flags, "Int")
}

ShowPreparedWindow(guiObj, showOptions, prepareCallback := "") {
    if !IsObject(guiObj)
        return false
    try hwnd := guiObj.Hwnd
    catch
        return false
    if !hwnd || !DllCall("user32\IsWindow", "Ptr", hwnd, "Int")
        return false
    if EnvGet("KEY_MOUSE_REMAPPER_GUI_TEST_OFFSCREEN") == "1"
        showOptions .= " NA x-30000 y-30000"
    if DllCall("user32\IsWindowVisible", "Ptr", hwnd, "Int") {
        return ActivatePreparedWindow(guiObj)
    }

    ; 标题栏主题必须在顶层窗口第一次可见前完成。随后隐藏预布局一次，
    ; 让 Size 回调、滚动条和组合框都按最终尺寸创建，再整树提交首帧。
    if IsObject(prepareCallback)
        prepareCallback.Call()
    BeginStableWindowUpdate(hwnd)
    try {
        guiObj.Show("Hide " showOptions)
        if IsObject(prepareCallback)
            prepareCallback.Call()
    } finally EndStableWindowUpdate(hwnd, true)
    guiObj.Show()
    if IsObject(prepareCallback) {
        BeginStableWindowUpdate(hwnd)
        try prepareCallback.Call()
        finally EndStableWindowUpdate(hwnd)
    } else {
        RedrawStableWindow(hwnd)
    }
    return true
}

ActivatePreparedWindow(guiObj) {
    if !IsObject(guiObj)
        return false
    try hwnd := guiObj.Hwnd
    catch
        return false
    if !hwnd || !DllCall("user32\IsWindow", "Ptr", hwnd, "Int")
        return false
    WindowHierarchy.PrepareChildRestore(hwnd)
    if WindowHierarchy.IsOwnerLocked(guiObj)
            && WindowHierarchy.ActivateTopOwned(guiObj)
        return true
    guiObj.Show()
    try WinActivate("ahk_id " hwnd)
    return true
}

MoveAndRefreshResizableText(control, x := "", y := "", width := "",
        height := "") {
    ; STATIC 扩大后可能不会重绘先前位于裁剪区外的文字。只刷新扩大的
    ; 控件本身，避免窗口缩放期间反复擦除整个客户区。
    if !IsObject(control)
        return false
    try controlHwnd := control.Hwnd
    catch
        return false
    if !controlHwnd || !DllCall("user32\IsWindow", "Ptr", controlHwnd,
            "Int")
        return false
    try control.GetPos(,, &oldWidth, &oldHeight)
    catch
        return false
    try control.Move(x, y, width, height)
    catch
        return false
    try control.GetPos(,, &newWidth, &newHeight)
    catch
        return false
    if newWidth <= oldWidth && newHeight <= oldHeight
        return true

    ; RDW_INVALIDATE | RDW_ERASE | RDW_UPDATENOW
    return DllCall("user32\RedrawWindow", "Ptr", controlHwnd, "Ptr", 0,
        "Ptr", 0, "UInt", 0x0105, "Int") != 0
}

DarkExplorerThemeName() {
    return UiThemeService.IsDark() ? "DarkMode_Explorer" : "Explorer"
}

DarkItemsViewThemeName() {
    return UiThemeService.IsDark() ? "DarkMode_ItemsView" : "ItemsView"
}

EnableDarkProcessMode() {
    return UiThemeService.ApplyProcessPreference()
}

AllowDarkModeForWindow(hwnd, dark := true) {
    return UiThemeService.AllowDarkModeForWindow(hwnd, dark)
}

GetUxThemeFunction(ordinal) {
    return UiThemeService.GetUxThemeFunction(ordinal)
}

ColorRef(hexColor) {
    value := Integer("0x" hexColor)
    return ((value & 0xFF) << 16) | (value & 0xFF00) | ((value >> 16) & 0xFF)
}

GetComboBoxThemeHandles(comboHwnd) {
    handles := {Combo: comboHwnd, Item: 0, List: 0}
    if !comboHwnd || !DllCall("user32\IsWindow", "Ptr", comboHwnd, "Int")
        return handles
    comboInfo := Buffer(40 + 3 * A_PtrSize, 0)
    NumPut("UInt", comboInfo.Size, comboInfo, 0)
    if !DllCall("user32\GetComboBoxInfo", "Ptr", comboHwnd,
            "Ptr", comboInfo, "Int")
        return handles
    returnedCombo := NumGet(comboInfo, 40, "Ptr")
    handles.Combo := returnedCombo ? returnedCombo : comboHwnd
    handles.Item := NumGet(comboInfo, 40 + A_PtrSize, "Ptr")
    handles.List := NumGet(comboInfo, 40 + 2 * A_PtrSize, "Ptr")
    return handles
}

GetComboBoxDisplayPadding() {
    static padding := Chr(0x2002)
    return padding
}

AddComboBoxDisplayPadding(items) {
    paddedItems := []
    padding := GetComboBoxDisplayPadding()
    for item in items
        paddedItems.Push(padding String(item) padding)
    return paddedItems
}

class DarkComboBoxListThemeRegistry {
    static ListHandles := Map()
    static MessageRegistered := false
    static MessageCallback := ""
    static BackgroundColorRef := 0
    static TextColorRef := 0

    static Register(listHwnd, comboHwnd) {
        if !listHwnd || !comboHwnd
            || !DllCall("user32\IsWindow", "Ptr", listHwnd, "Int")
            || !DllCall("user32\IsWindow", "Ptr", comboHwnd, "Int")
            return false
        this.ListHandles[listHwnd] := comboHwnd
        if !this.MessageRegistered {
            this.MessageCallback := ObjBindMethod(this, "HandleListColor")
            try OnMessage(0x0134, this.MessageCallback)
            catch as registrationError {
                this.MessageCallback := ""
                this.ListHandles.Delete(listHwnd)
                throw registrationError
            }
            this.MessageRegistered := true
        }
        return true
    }

    static Unregister(listHwnd) {
        if listHwnd && this.ListHandles.Has(listHwnd)
            this.ListHandles.Delete(listHwnd)
        this.UnregisterMessageIfUnused()
    }

    static UnregisterMessageIfUnused() {
        if this.ListHandles.Count || !this.MessageRegistered
            return false
        if IsObject(this.MessageCallback)
            OnMessage(0x0134, this.MessageCallback, 0)
        this.MessageCallback := ""
        this.MessageRegistered := false
        return true
    }

    static IsRegistered(listHwnd) {
        return listHwnd && this.ListHandles.Has(listHwnd)
    }

    static HandleListColor(deviceContext, listHwnd, *) {
        if !this.ListHandles.Has(listHwnd)
            return
        comboHwnd := this.ListHandles[listHwnd]
        currentHandles := GetComboBoxThemeHandles(comboHwnd)
        if !DllCall("user32\IsWindow", "Ptr", listHwnd, "Int")
                || currentHandles.List != listHwnd {
            this.ListHandles.Delete(listHwnd)
            this.UnregisterMessageIfUnused()
            return
        }
        colors := UiThemeService.GetPalette()
        this.BackgroundColorRef := ColorRef(colors.Surface)
        this.TextColorRef := ColorRef(colors.Text)
        DllCall("gdi32\SetTextColor", "Ptr", deviceContext,
            "UInt", this.TextColorRef)
        DllCall("gdi32\SetBkColor", "Ptr", deviceContext,
            "UInt", this.BackgroundColorRef)
        DllCall("gdi32\SetDCBrushColor", "Ptr", deviceContext,
            "UInt", this.BackgroundColorRef)
        return DllCall("gdi32\GetStockObject", "Int", 18, "Ptr")
    }
}

ApplyDarkComboBoxTheme(comboHwnd) {
    handles := GetComboBoxThemeHandles(comboHwnd)
    if !handles.Combo || !DllCall("user32\IsWindow", "Ptr",
            handles.Combo, "Int")
        return false
    applied := ApplyDarkControl(handles.Combo,
        UiThemeService.GetComboThemeName())
    RemoveComboBoxBorder(handles.Combo)
    if handles.Item
        ApplyDarkControl(handles.Item, UiThemeService.GetComboThemeName())
    if handles.List {
        DarkComboBoxListThemeRegistry.Register(handles.List, handles.Combo)
        ApplyDarkControl(handles.List, DarkExplorerThemeName())
    }
    return applied
}

RemoveComboBoxBorder(comboHwnd) {
    if !comboHwnd || !DllCall("user32\IsWindow", "Ptr", comboHwnd, "Int")
        return false
    style := DllCall("user32\GetWindowLongPtrW", "Ptr", comboHwnd,
        "Int", -16, "Ptr")
    exStyle := DllCall("user32\GetWindowLongPtrW", "Ptr", comboHwnd,
        "Int", -20, "Ptr")
    borderlessStyle := style & ~0x00800000
    borderlessExStyle := exStyle & ~(0x00000001 | 0x00000200 | 0x00020000)
    if borderlessStyle != style
        DllCall("user32\SetWindowLongPtrW", "Ptr", comboHwnd,
            "Int", -16, "Ptr", borderlessStyle, "Ptr")
    if borderlessExStyle != exStyle
        DllCall("user32\SetWindowLongPtrW", "Ptr", comboHwnd,
            "Int", -20, "Ptr", borderlessExStyle, "Ptr")
    DllCall("user32\SetWindowPos", "Ptr", comboHwnd, "Ptr", 0,
        "Int", 0, "Int", 0, "Int", 0, "Int", 0,
        "UInt", 0x0237, "Int")
    return true
}

UnregisterDarkComboBoxTheme(comboHwnd) {
    handles := GetComboBoxThemeHandles(comboHwnd)
    DarkComboBoxListThemeRegistry.Unregister(handles.List)
}

SetEditMargins(hwnd, left, right) {
    if !hwnd
        return false
    marginDpi := DllCall("user32\GetDpiForWindow", "Ptr", hwnd, "UInt")
    if !marginDpi
        marginDpi := 96
    leftPixels := Max(4, Round(left * marginDpi / 96))
    rightPixels := Max(4, Round(right * marginDpi / 96))
    packed := (rightPixels << 16) | (leftPixels & 0xFFFF)
    SendMessage(Win32.EM_SETMARGINS, 0x3, packed, , hwnd)
    return true
}

GetCenteredSingleLineEditHeight(outerHeight) {
    ; 单行 Edit 只保持接近系统原生的文字高度。把一个接近外框高度的
    ; Edit 居中并不会居中文字，反而会让原生文字基线明显偏上。
    return Min(Max(1, outerHeight), Min(22, Max(18, outerHeight - 6)))
}

AddCenteredSingleLineEdit(guiObj, x, y, width, outerHeight,
    backgroundColor, textColor, value := "") {
    innerHeight := GetCenteredSingleLineEditHeight(outerHeight)
    innerY := y + Floor((outerHeight - innerHeight) / 2)
    background := guiObj.Add("Text", "x" x " y" y " w" width
        " h" outerHeight " Background" backgroundColor)
    inputEdit := guiObj.Add("Edit", "x" x " y" innerY " w" width
        " h" innerHeight " Background" backgroundColor " c" textColor
        " -E0x200", value)
    SetEditMargins(inputEdit.Hwnd, 8, 8)
    background.OnEvent("Click",
        PlaceSingleLineEditCaretAtPointer.Bind(inputEdit))
    return {Background: background, Edit: inputEdit}
}

MoveCenteredSingleLineEdit(inputControl, x, y, width, outerHeight) {
    innerHeight := GetCenteredSingleLineEditHeight(outerHeight)
    innerY := y + Floor((outerHeight - innerHeight) / 2)
    inputControl.Background.Move(x, y, width, outerHeight)
    inputControl.Edit.Move(x, innerY, width, innerHeight)
}

SetMultilineEditPadding(hwnd, left := 8, top := 5, right := 8,
        bottom := 5) {
    if !hwnd || !DllCall("user32\IsWindow", "Ptr", hwnd, "Int")
        return false
    clientRect := Buffer(16, 0)
    if !DllCall("user32\GetClientRect", "Ptr", hwnd, "Ptr", clientRect,
            "Int")
        return false
    windowDpi := DllCall("user32\GetDpiForWindow", "Ptr", hwnd, "UInt")
    if !windowDpi
        windowDpi := 96
    leftPx := Max(1, Round(left * windowDpi / 96))
    topPx := Max(1, Round(top * windowDpi / 96))
    rightPx := Max(1, Round(right * windowDpi / 96))
    bottomPx := Max(1, Round(bottom * windowDpi / 96))
    width := NumGet(clientRect, 8, "Int")
    height := NumGet(clientRect, 12, "Int")
    NumPut("Int", leftPx, "Int", topPx,
        "Int", Max(leftPx + 1, width - rightPx),
        "Int", Max(topPx + 1, height - bottomPx), clientRect)
    SendMessage(Win32.EM_SETRECT, 0, clientRect.Ptr, , hwnd)
    return true
}

AddPaddedMultilineEdit(guiObj, x, y, width, outerHeight,
        backgroundColor, textColor, value := "") {
    background := guiObj.Add("Text", "x" x " y" y " w" width
        " h" outerHeight " Background" backgroundColor)
    inputEdit := guiObj.Add("Edit", "x" x " y" (y + 1) " w" width
        " h" Max(1, outerHeight - 2) " Multi WantReturn -VScroll -HScroll"
        " Background" backgroundColor " c" textColor " -E0x200", value)
    SetMultilineEditPadding(inputEdit.Hwnd)
    background.OnEvent("Click",
        PlaceMultilineEditCaretAtPointer.Bind(inputEdit))
    return {Background: background, Edit: inputEdit}
}

MovePaddedMultilineEdit(inputControl, x, y, width, outerHeight) {
    inputControl.Background.Move(x, y, width, outerHeight)
    inputControl.Edit.Move(x, y + 1, width, Max(1, outerHeight - 2))
    SetMultilineEditPadding(inputControl.Edit.Hwnd)
}

PlaceSingleLineEditCaretAtPointer(editControl, *) {
    PlaceEditCaretAtPointer(editControl, false)
}

PlaceMultilineEditCaretAtPointer(editControl, *) {
    PlaceEditCaretAtPointer(editControl, true)
}

PlaceEditCaretAtPointer(editControl, usePointerY := false) {
    if !editControl || !editControl.Hwnd
        return
    cursorPoint := Buffer(8, 0)
    if !DllCall("user32\GetCursorPos", "Ptr", cursorPoint, "Int")
            || !DllCall("user32\ScreenToClient", "Ptr", editControl.Hwnd,
                "Ptr", cursorPoint, "Int")
        return
    pointerY := usePointerY ? NumGet(cursorPoint, 4, "Int") : ""
    PlaceEditCaretAtClientPoint(editControl,
        NumGet(cursorPoint, 0, "Int"), pointerY)
}

PlaceEditCaretAtClientPoint(editControl, pointerX, pointerY := "") {
    if !editControl || !editControl.Hwnd
        return false
    clientRect := Buffer(16, 0)
    if !DllCall("user32\GetClientRect", "Ptr", editControl.Hwnd,
            "Ptr", clientRect, "Int")
        return false
    clientWidth := NumGet(clientRect, 8, "Int")
    clientHeight := NumGet(clientRect, 12, "Int")
    if clientWidth <= 0 || clientHeight <= 0
        return false
    pointerX := Max(0, Min(Integer(pointerX), clientWidth - 1))
    pointerY := pointerY == "" ? Floor(clientHeight / 2)
        : Max(0, Min(Integer(pointerY), clientHeight - 1))
    packedPoint := (pointerX & 0xFFFF) | ((pointerY & 0xFFFF) << 16)
    try {
        ControlFocus(editControl)
        characterIndex := SendMessage(Win32.EM_CHARFROMPOS, 0,
            packedPoint, , editControl.Hwnd) & 0xFFFF
        SendMessage(Win32.EM_SETSEL, characterIndex, characterIndex, ,
            editControl.Hwnd)
        return true
    }
    return false
}
