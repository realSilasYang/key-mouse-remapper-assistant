; 不激活、不进入原生模态菜单循环的映射条目快捷操作窗。
; 主列表继续拥有键盘焦点，切换到其它程序时弹窗自动收起。

class MappingContextPopupWindow {
    static WindowWidth := 248
    static WindowHeight := 44
    static WindowRadiusDip := 9

    __New(ownerWindow) {
        this.OwnerWindow := ownerWindow
        this.Gui := ""
        this.Interactions := ""
        this.MappingId := ""
        this.Disposed := false
        this.VisibilityTimer := ObjBindMethod(this, "MonitorVisibility")
        this.PointerDownCallback := ObjBindMethod(this, "OnPointerDown")
        try this.Build()
        catch as buildError {
            this.Dispose()
            throw buildError
        }
    }

    Build() {
        colors := UiThemeService.GetPalette()
        menuColor := UiThemeService.Color("Menu")
        menuHoverColor := UiThemeService.Color("MenuHover")
        this.Gui := Gui("+Owner" this.OwnerWindow.Gui.Hwnd
            " -Caption +ToolWindow +AlwaysOnTop +E0x08000000")
        this.Gui.BackColor := menuColor
        this.Gui.MarginX := 0
        this.Gui.MarginY := 0
        this.Gui.SetFont("s10 c" colors.Text,
            LocalizationService.GetLanguageSystemUiFontName())
        this.Interactions := MappingUiInteractions(this.Gui, menuColor,
            this.OwnerWindow.App.SvgRenderer)
        this.EditButton := this.Gui.Add("Text",
            "x6 y6 w236 h32 Center 0x200 Background" menuColor
                " c" colors.Text,
            Tr("编辑映射代码") "  F2")
        this.EditButton.SetFont("s10",
            LocalizationService.GetLanguageSystemUiFontName())
        if !this.Interactions.RegisterButton(this.EditButton, menuColor,
                ObjBindMethod(this, "InvokeEdit"), menuHoverColor,
                menuHoverColor, false, colors.Text)
            this.EditButton.OnEvent("Click", ObjBindMethod(this,
                "InvokeEdit"))
        this.Interactions.SetButtonLucideIcon(this.EditButton,
            "pencil.svg", 15, 7)
        OnMessage(Win32.WM_LBUTTONDOWN, this.PointerDownCallback)
        OnMessage(Win32.WM_RBUTTONDOWN, this.PointerDownCallback)
    }

    IsVisible() {
        return !this.Disposed && IsObject(this.Gui) && this.Gui.Hwnd
            && DllCall("user32\IsWindowVisible", "Ptr", this.Gui.Hwnd,
                "Int") != 0
    }

    ShowForMapping(mappingId) {
        if this.Disposed || Trim(String(mappingId)) == ""
            return false
        ownerFocus := DllCall("user32\GetFocus", "Ptr")
        foregroundHwnd := DllCall("user32\GetForegroundWindow", "Ptr")
        this.MappingId := String(mappingId)
        this.Gui.Show("Hide NoActivate w" MappingContextPopupWindow.WindowWidth
            " h" MappingContextPopupWindow.WindowHeight)
        this.ApplyRoundedRegion()
        point := Buffer(8, 0)
        if !DllCall("user32\GetCursorPos", "Ptr", point, "Int")
            return false
        x := NumGet(point, 0, "Int")
        y := NumGet(point, 4, "Int") + 4
        windowRect := Buffer(16, 0)
        DllCall("user32\GetWindowRect", "Ptr", this.Gui.Hwnd,
            "Ptr", windowRect)
        width := NumGet(windowRect, 8, "Int")
            - NumGet(windowRect, 0, "Int")
        height := NumGet(windowRect, 12, "Int")
            - NumGet(windowRect, 4, "Int")
        this.ConstrainToWorkArea(&x, &y, width, height)
        shown := DllCall("user32\SetWindowPos", "Ptr", this.Gui.Hwnd,
            "Ptr", -1, "Int", x, "Int", y, "Int", 0, "Int", 0,
            "UInt", 0x0051, "Int") != 0 ; NOSIZE | NOACTIVATE | SHOWWINDOW
        if shown {
            if ownerFocus
                    && DllCall("user32\IsWindow", "Ptr", ownerFocus, "Int")
                    && foregroundHwnd
                        == DllCall("user32\GetForegroundWindow", "Ptr")
                    && DllCall("user32\GetFocus", "Ptr") != ownerFocus
                DllCall("user32\SetFocus", "Ptr", ownerFocus, "Ptr")
            SetTimer(this.VisibilityTimer, 50)
        }
        return shown
    }

    Hide(*) {
        try SetTimer(this.VisibilityTimer, 0)
        if this.IsVisible()
            try this.Gui.Hide()
        this.MappingId := ""
        return true
    }

    InvokeEdit(*) {
        mappingId := this.MappingId
        this.Hide()
        if mappingId != ""
            this.OwnerWindow.OpenEditorForId(mappingId)
    }

    OnPointerDown(wParam, lParam, msg, hwnd) {
        if !this.IsVisible() || !hwnd
            return
        rootHwnd := DllCall("user32\GetAncestor", "Ptr", hwnd,
            "UInt", 2, "Ptr") ; GA_ROOT
        if rootHwnd != this.Gui.Hwnd
            this.Hide()
    }

    MonitorVisibility(*) {
        if !this.IsVisible() {
            SetTimer(this.VisibilityTimer, 0)
            return
        }
        foregroundHwnd := DllCall("user32\GetForegroundWindow", "Ptr")
        if foregroundHwnd != this.OwnerWindow.Gui.Hwnd
                && foregroundHwnd != this.Gui.Hwnd
            this.Hide()
    }

    ConstrainToWorkArea(&x, &y, width, height) {
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
        x := Min(Max(x, left + 4), Max(left + 4, right - width - 4))
        y := Min(Max(y, top + 4), Max(top + 4, bottom - height - 4))
    }

    ApplyRoundedRegion() {
        if this.Disposed || !IsObject(this.Gui) || !this.Gui.Hwnd
            return false
        windowRect := Buffer(16, 0)
        if !DllCall("user32\GetWindowRect", "Ptr", this.Gui.Hwnd,
                "Ptr", windowRect, "Int")
            return false
        width := NumGet(windowRect, 8, "Int")
            - NumGet(windowRect, 0, "Int")
        height := NumGet(windowRect, 12, "Int")
            - NumGet(windowRect, 4, "Int")
        windowDpi := DllCall("user32\GetDpiForWindow", "Ptr", this.Gui.Hwnd,
            "UInt")
        if !windowDpi
            windowDpi := 96
        radius := Max(4, Round(MappingContextPopupWindow.WindowRadiusDip
            * windowDpi / 96))
        region := DllCall("gdi32\CreateRoundRectRgn",
            "Int", 0, "Int", 0, "Int", width + 1, "Int", height + 1,
            "Int", radius * 2, "Int", radius * 2, "Ptr")
        if !region
            return false
        if !DllCall("user32\SetWindowRgn", "Ptr", this.Gui.Hwnd,
                "Ptr", region, "Int", true, "Int") {
            DllCall("gdi32\DeleteObject", "Ptr", region)
            return false
        }
        if VerCompare(A_OSVersion, "10.0.22000") >= 0
            try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", this.Gui.Hwnd,
                "Int", 33, "Int*", 2, "Int", 4)
        return true
    }

    ApplyAppearance(*) {
        if this.Disposed
            return false
        colors := UiThemeService.GetPalette()
        menuColor := UiThemeService.Color("Menu")
        menuHoverColor := UiThemeService.Color("MenuHover")
        this.Gui.BackColor := menuColor
        this.Interactions.SetParentColor(menuColor)
        this.Interactions.SetTextNoErase(this.EditButton,
            Tr("编辑映射代码") "  F2")
        this.Interactions.SetButtonAppearance(this.EditButton, menuColor,
            colors.Text, true, menuHoverColor, menuHoverColor)
        this.Interactions.SetButtonLucideIcon(this.EditButton,
            "pencil.svg", 15, 7)
        this.EditButton.SetFont("s10",
            LocalizationService.GetLanguageSystemUiFontName())
        if this.IsVisible()
            this.ApplyRoundedRegion()
        return true
    }

    Dispose(*) {
        if this.Disposed
            return
        this.Disposed := true
        try SetTimer(this.VisibilityTimer, 0)
        try OnMessage(Win32.WM_LBUTTONDOWN, this.PointerDownCallback, 0)
        try OnMessage(Win32.WM_RBUTTONDOWN, this.PointerDownCallback, 0)
        if IsObject(this.Interactions)
            try this.Interactions.Dispose()
        if IsObject(this.Gui)
            try this.Gui.Destroy()
        this.Interactions := ""
        this.Gui := ""
        this.MappingId := ""
        this.VisibilityTimer := ""
        this.PointerDownCallback := ""
    }
}
