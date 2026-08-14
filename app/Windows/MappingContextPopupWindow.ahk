; 不激活、不进入原生模态菜单循环的映射条目快捷操作窗。
; 主列表继续拥有键盘焦点，切换到其它程序时弹窗自动收起。

class MappingContextPopupWindow {
    static MinWindowWidth := 140
    static MaxWindowWidth := 320
    static ItemHeight := 30
    static Padding := 6
    static ItemGap := 2
    static TextInsetDip := 12
    static IconSizeDip := 14
    static IconGapDip := 6
    static WindowRadiusDip := 9
    static RowRadiusDip := 6
    static ColorLabelHeight := 18
    static ColorSectionTopGap := 6
    static SwatchSize := 24
    static SwatchGap := 6
    static SwatchTopGap := 8
    static SelectedMarkFontSize := 13
    static ClearMarkFontSize := 18

    __New(ownerWindow) {
        this.OwnerWindow := ownerWindow
        this.Gui := ""
        this.Interactions := ""
        this.MappingId := ""
        this.MappingIds := []
        this.Disposed := false
        this.VisibilityTimer := ObjBindMethod(this, "MonitorVisibility")
        this.PointerDownCallback := ObjBindMethod(this, "OnPointerDown")
        try this.Build()
        catch as buildError {
            try this.Dispose()
            throw buildError
        }
    }

    Build() {
        colors := UiThemeService.GetPalette()
        menuColor := UiThemeService.Color("Menu")
        menuHoverColor := UiThemeService.Color("MenuHover")
        this.Gui := Gui("+Owner" this.OwnerWindow.Gui.Hwnd
            " -Caption +ToolWindow +AlwaysOnTop -MinimizeBox -MaximizeBox"
            " +E0x08000000")
        this.Gui.BackColor := menuColor
        this.Gui.MarginX := 0
        this.Gui.MarginY := 0
        this.Gui.SetFont("s10 c" colors.Text,
            LocalizationService.GetLanguageSystemUiFontName())
        this.MeasureControl := this.Gui.Add("Text",
            "x-10000 y-10000 w1 h1", "")
        this.WindowWidth := this.ResolveWindowWidth(this.GetMenuTexts())
        swatchRowWidth := (RuleColorPalette.Presets().Length + 1)
            * MappingContextPopupWindow.SwatchSize
            + RuleColorPalette.Presets().Length
                * MappingContextPopupWindow.SwatchGap
        this.WindowWidth := Max(this.WindowWidth,
            MappingContextPopupWindow.Padding * 2 + swatchRowWidth)
        this.WindowHeight := MappingContextPopupWindow.Padding * 2
            + MappingContextPopupWindow.ItemHeight * 2
            + MappingContextPopupWindow.ItemGap
            + MappingContextPopupWindow.ColorSectionTopGap
            + MappingContextPopupWindow.ColorLabelHeight
            + MappingContextPopupWindow.SwatchTopGap
            + MappingContextPopupWindow.SwatchSize
        contentWidth := this.WindowWidth
            - MappingContextPopupWindow.Padding * 2
        this.Interactions := MappingUiInteractions(this.Gui, menuColor,
            this.OwnerWindow.App.SvgRenderer)
        this.EditButton := this.AddMenuButton(0, contentWidth,
            this.GetEditText(), "pencil.svg", ObjBindMethod(this,
                "InvokeEdit"), colors.Text)
        this.OptimizeButton := this.AddMenuButton(1, contentWidth,
            this.GetOptimizeText(), "pencil-sparkles.svg",
            ObjBindMethod(this, "InvokeOptimize"), colors.AI)
        this.MenuButtons := [this.EditButton, this.OptimizeButton]
        colorLabelY := MappingContextPopupWindow.Padding
            + MappingContextPopupWindow.ItemHeight * 2
            + MappingContextPopupWindow.ItemGap
            + MappingContextPopupWindow.ColorSectionTopGap
        this.ColorLabel := this.Gui.Add("Text",
            "x" MappingContextPopupWindow.Padding " y" colorLabelY
                " w" contentWidth " h"
                MappingContextPopupWindow.ColorLabelHeight
                " Center 0x200 Background" menuColor " c" colors.Text,
            this.GetColorLabelText())
        this.ColorLabel.SetFont("s10 norm bold",
            LocalizationService.GetLanguageSystemUiFontName())
        this.Interactions.RegisterIconSurface(this.ColorLabel, menuColor,
            colors.Text)
        this.Interactions.SetControlLucideIcon(this.ColorLabel,
            "palette.svg", MappingContextPopupWindow.IconSizeDip,
            MappingContextPopupWindow.IconGapDip, colors.ThemeIcon)
        this.SwatchButtons := []
        swatchY := colorLabelY + MappingContextPopupWindow.ColorLabelHeight
            + MappingContextPopupWindow.SwatchTopGap
        for index, preset in RuleColorPalette.Presets() {
            button := this.AddColorSwatch(index - 1, swatchY, preset.Key,
                this.GetPresetTooltip(preset.Key))
            this.SwatchButtons.Push({Control: button, Key: preset.Key})
        }
        clearButton := this.AddColorSwatch(RuleColorPalette.Presets().Length,
            swatchY, "", Tr("清除圆点颜色"))
        this.Interactions.SetButtonClearMark(clearButton, 16, 2)
        this.SwatchButtons.Push({Control: clearButton, Key: ""})
        this.RefreshSwatchSelection()
        OnMessage(Win32.WM_LBUTTONDOWN, this.PointerDownCallback)
        OnMessage(Win32.WM_RBUTTONDOWN, this.PointerDownCallback)
    }

    IsVisible() {
        return !this.Disposed && IsObject(this.Gui) && this.Gui.Hwnd
            && DllCall("user32\IsWindowVisible", "Ptr", this.Gui.Hwnd,
                "Int") != 0
    }

    ShowForMapping(mappingId, mappingIds := "") {
        if this.Disposed || Trim(String(mappingId)) == ""
            return false
        ownerFocus := DllCall("user32\GetFocus", "Ptr")
        foregroundHwnd := DllCall("user32\GetForegroundWindow", "Ptr")
        this.MappingId := String(mappingId)
        this.MappingIds := this.NormalizeMappingIds(mappingIds)
        if !this.MappingIds.Length
            this.MappingIds := [this.MappingId]
        this.RefreshSwatchSelection()
        this.Gui.Show("Hide NoActivate w" this.WindowWidth
            " h" this.WindowHeight)
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
        this.MappingIds := []
        return true
    }

    GetEditText() => Tr("编辑映射代码") "（F2）"

    GetOptimizeText() => Tr("AI 优化规则")

    GetColorLabelText() => Tr("设置序号圆点")

    GetMenuTexts() {
        return [this.GetEditText(), this.GetOptimizeText(),
            this.GetColorLabelText()]
    }

    AddColorSwatch(index, y, presetKey, tooltipText) {
        menuColor := UiThemeService.Color("Menu")
        x := MappingContextPopupWindow.Padding + index
            * (MappingContextPopupWindow.SwatchSize
                + MappingContextPopupWindow.SwatchGap)
        color := presetKey == "" ? menuColor
            : RuleColorPalette.Color(presetKey)
        button := this.Gui.Add("Text", "x" x " y" y " w"
            MappingContextPopupWindow.SwatchSize " h"
            MappingContextPopupWindow.SwatchSize " Background" color, "")
        callback := ObjBindMethod(this, "InvokeColor", presetKey)
        if !this.Interactions.RegisterButton(button, color, callback,
                color, color, true)
            button.OnEvent("Click", callback)
        this.Interactions.SetButtonTextLayout(button, "center", 0, 5)
        this.Interactions.SetButtonTooltip(button, tooltipText)
        return button
    }

    GetPresetTooltip(presetKey) {
        switch RuleColorPalette.NormalizeKey(presetKey) {
            case "sage": return Tr("雾松绿")
            case "mist": return Tr("青灰蓝")
            case "lavender": return Tr("薰衣草紫")
            case "rose": return Tr("烟粉")
            case "amber": return Tr("浅琥珀")
            case "teal": return Tr("静谧青")
            case "pearl": return Tr("珍珠灰")
            default: return Tr("清除圆点颜色")
        }
    }

    NormalizeMappingIds(mappingIds) {
        if Type(mappingIds) != "Array"
            return []
        result := []
        seen := Map()
        for mappingId in mappingIds {
            mappingId := Trim(String(mappingId))
            if mappingId == "" || seen.Has(mappingId)
                continue
            seen[mappingId] := true
            result.Push(mappingId)
        }
        return result
    }

    AddMenuButton(index, contentWidth, text, iconName, callback,
            iconColor, textColor := "") {
        colors := UiThemeService.GetPalette()
        menuColor := UiThemeService.Color("Menu")
        menuHoverColor := UiThemeService.Color("MenuHover")
        if textColor == ""
            textColor := colors.Text
        y := MappingContextPopupWindow.Padding
            + index * (MappingContextPopupWindow.ItemHeight
                + MappingContextPopupWindow.ItemGap)
        button := this.Gui.Add("Text",
            "x" MappingContextPopupWindow.Padding " y" y
                " w" contentWidth " h" MappingContextPopupWindow.ItemHeight
                " 0x200 Background" menuColor " c" textColor, text)
        button.SetFont("s10",
            LocalizationService.GetLanguageSystemUiFontName())
        if !this.Interactions.RegisterButton(button, menuColor, callback,
                menuHoverColor, menuHoverColor, false, textColor)
            button.OnEvent("Click", callback)
        this.Interactions.SetButtonTextLayout(button, "left",
            MappingContextPopupWindow.TextInsetDip,
            MappingContextPopupWindow.RowRadiusDip)
        this.Interactions.SetButtonLucideIcon(button, iconName,
            MappingContextPopupWindow.IconSizeDip,
            MappingContextPopupWindow.IconGapDip, iconColor)
        return button
    }

    ResolveWindowWidth(texts) {
        this.MeasureControl.SetFont("s10 norm",
            LocalizationService.GetLanguageSystemUiFontName())
        textWidth := 0
        hdc := DllCall("user32\GetDC", "Ptr", this.Gui.Hwnd, "Ptr")
        if hdc {
            font := DllCall("user32\SendMessageW", "Ptr",
                this.MeasureControl.Hwnd,
                "UInt", Win32.WM_GETFONT, "Ptr", 0, "Ptr", 0, "Ptr")
            previousFont := font ? DllCall("gdi32\SelectObject", "Ptr",
                hdc, "Ptr", font, "Ptr") : 0
            try {
                for text in texts {
                    size := Buffer(8, 0)
                    if DllCall("gdi32\GetTextExtentPoint32W", "Ptr", hdc,
                            "Str", text, "Int", StrLen(text), "Ptr", size,
                            "Int")
                        textWidth := Max(textWidth, NumGet(size, 0, "Int"))
                }
            } finally {
                if previousFont
                    DllCall("gdi32\SelectObject", "Ptr", hdc,
                        "Ptr", previousFont, "Ptr")
                DllCall("user32\ReleaseDC", "Ptr", this.Gui.Hwnd,
                    "Ptr", hdc)
            }
        }
        dpi := DllCall("user32\GetDpiForWindow", "Ptr", this.Gui.Hwnd,
            "UInt")
        if !dpi
            dpi := 96
        measuredWidth := MappingContextPopupWindow.Padding * 2
            + MappingContextPopupWindow.TextInsetDip * 2
            + MappingContextPopupWindow.IconSizeDip
            + MappingContextPopupWindow.IconGapDip
            + Round(textWidth * 96 / dpi)
        return Min(Max(measuredWidth,
            MappingContextPopupWindow.MinWindowWidth),
            MappingContextPopupWindow.MaxWindowWidth)
    }

    InvokeEdit(*) {
        mappingId := this.MappingId
        this.Hide()
        if mappingId != ""
            this.OwnerWindow.OpenEditorForId(mappingId)
    }

    InvokeOptimize(*) {
        mappingId := this.MappingId
        this.Hide()
        if mappingId != ""
            this.OwnerWindow.OptimizeMappingById(mappingId)
    }

    InvokeColor(presetKey, *) {
        mappingIds := this.MappingIds.Clone()
        this.Hide()
        if mappingIds.Length
                && HasMethod(this.OwnerWindow.App, "SetRuleColors")
            this.OwnerWindow.App.SetRuleColors(mappingIds, presetKey)
    }

    RefreshSwatchSelection() {
        activeKey := HasMethod(this.OwnerWindow.App, "GetCommonRuleColor")
            ? this.OwnerWindow.App.GetCommonRuleColor(this.MappingIds) : ""
        colors := UiThemeService.GetPalette()
        fontName := LocalizationService.GetLanguageSystemUiFontName()
        for swatch in this.SwatchButtons {
            color := swatch.Key == "" ? UiThemeService.Color("Menu")
                : RuleColorPalette.Color(swatch.Key)
            textColor := swatch.Key == "" ? colors.Muted : colors.Text
            this.Interactions.SetButtonAppearance(swatch.Control, color,
                textColor, true, color, color)
            this.Interactions.ClearButtonIcon(swatch.Control)
            if swatch.Key == "" {
                swatch.Control.SetFont("s"
                    MappingContextPopupWindow.ClearMarkFontSize " bold",
                    fontName)
                this.Interactions.SetTextNoErase(swatch.Control, "✕")
            } else if swatch.Key == activeKey {
                swatch.Control.SetFont("s"
                    MappingContextPopupWindow.SelectedMarkFontSize
                    " bold", fontName)
                this.Interactions.SetTextNoErase(swatch.Control, "✓")
            } else {
                swatch.Control.SetFont("s"
                    MappingContextPopupWindow.SelectedMarkFontSize
                    " bold", fontName)
                this.Interactions.SetTextNoErase(swatch.Control, "")
            }
        }
        return true
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
        texts := [this.GetEditText(), this.GetOptimizeText()]
        icons := ["pencil.svg", "pencil-sparkles.svg"]
        iconColors := [colors.Text, colors.AI]
        textColors := [colors.Text, colors.Text]
        for index, button in this.MenuButtons {
            this.Interactions.SetTextNoErase(button, texts[index])
            this.Interactions.SetButtonAppearance(button, menuColor,
                textColors[index], true, menuHoverColor, menuHoverColor)
            this.Interactions.ClearButtonIcon(button)
            this.Interactions.SetButtonTextLayout(button, "left",
                MappingContextPopupWindow.TextInsetDip,
                MappingContextPopupWindow.RowRadiusDip)
            this.Interactions.SetButtonLucideIcon(button, icons[index],
                MappingContextPopupWindow.IconSizeDip,
                MappingContextPopupWindow.IconGapDip, iconColors[index])
            button.SetFont("s10",
                LocalizationService.GetLanguageSystemUiFontName())
        }
        this.ColorLabel.Text := this.GetColorLabelText()
        this.ColorLabel.Opt("Background" menuColor)
        this.ColorLabel.SetFont("s10 norm bold c" colors.Text,
            LocalizationService.GetLanguageSystemUiFontName())
        this.Interactions.SetIconSurfaceAppearance(this.ColorLabel,
            menuColor, colors.Text)
        this.Interactions.ClearControlIcon(this.ColorLabel)
        this.Interactions.SetControlLucideIcon(this.ColorLabel,
            "palette.svg", MappingContextPopupWindow.IconSizeDip,
            MappingContextPopupWindow.IconGapDip, colors.ThemeIcon)
        for swatch in this.SwatchButtons
            this.Interactions.SetButtonTooltip(swatch.Control,
                swatch.Key == "" ? Tr("清除圆点颜色")
                    : this.GetPresetTooltip(swatch.Key))
        this.RefreshSwatchSelection()
        swatchRowWidth := (RuleColorPalette.Presets().Length + 1)
            * MappingContextPopupWindow.SwatchSize
            + RuleColorPalette.Presets().Length
                * MappingContextPopupWindow.SwatchGap
        newWidth := Max(this.ResolveWindowWidth(this.GetMenuTexts()),
            MappingContextPopupWindow.Padding * 2 + swatchRowWidth)
        if newWidth != this.WindowWidth {
            this.WindowWidth := newWidth
            contentWidth := this.WindowWidth
                - MappingContextPopupWindow.Padding * 2
            for index, button in this.MenuButtons
                button.Move(MappingContextPopupWindow.Padding,
                    MappingContextPopupWindow.Padding + (index - 1)
                        * (MappingContextPopupWindow.ItemHeight
                            + MappingContextPopupWindow.ItemGap),
                    contentWidth, MappingContextPopupWindow.ItemHeight)
            this.ColorLabel.Move(MappingContextPopupWindow.Padding, ,
                contentWidth)
            if this.IsVisible()
                DllCall("user32\SetWindowPos", "Ptr", this.Gui.Hwnd,
                    "Ptr", 0, "Int", 0, "Int", 0,
                    "Int", this.WindowWidth, "Int", this.WindowHeight,
                    "UInt", 0x0016, "Int")
        }
        if this.IsVisible()
            this.ApplyRoundedRegion()
        return true
    }

    Dispose(*) {
        if this.Disposed
            return
        this.Disposed := true
        cleanup := CleanupCollector("映射右键菜单")
        if cleanup.Run("停止可见性计时器",
                () => SetTimer(this.VisibilityTimer, 0))
            this.VisibilityTimer := ""
        leftReleased := cleanup.Run("注销左键消息", () =>
            OnMessage(Win32.WM_LBUTTONDOWN, this.PointerDownCallback, 0))
        rightReleased := cleanup.Run("注销右键消息", () =>
            OnMessage(Win32.WM_RBUTTONDOWN, this.PointerDownCallback, 0))
        if IsObject(this.Interactions)
                && cleanup.Run("释放交互服务",
                    () => this.Interactions.Dispose())
            this.Interactions := ""
        if IsObject(this.Gui)
                && cleanup.Run("销毁窗口", () => this.Gui.Destroy())
            this.Gui := ""
        this.MappingId := ""
        this.MappingIds := []
        if leftReleased && rightReleased
            this.PointerDownCallback := ""
        cleanup.Complete()
        return true
    }
}
