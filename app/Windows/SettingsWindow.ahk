class SettingsWindow {
    static CompactWidth := 520
    static ExpandedWidth := 680
    static ClientHeight := 330
    static ProjectHomeUrl :=
        "https://github.com/realSilasYang/key-mouse-remapper-assistant"
    static ReleasesUrl := SettingsWindow.ProjectHomeUrl "/releases/latest"

    __New(ownerWindow) {
        this.OwnerWindow := ownerWindow
        this.App := ownerWindow.App
        this.Gui := ""
        this.OwnerLease := ""
        this.IconHandles := []
        this.Interactions := ""
        this.Disposed := false
        this.Original := ownerWindow.App.Settings
        this.TabButtons := []
        this.TabButtonPages := []
        this.TabControls := []
        this.TabBuilt := []
        this.ActiveTab := 0
        this.FontDropDownCommandHandler := ObjBindMethod(this,
            "OnFontDropDownCommand")
        this.FontDropDownCommandRegistered := false
        this.FontRefreshInProgress := false
        try this.Build()
        catch as buildError {
            try this.Dispose()
            throw buildError
        }
    }

    Build() {
        colors := UiThemeService.GetPalette()
        fontName := LocalizationService.GetUiFontName()
        isCompact := LocalizationService.UsesCompactLayout()
        this.WindowWidth := isCompact
            ? SettingsWindow.CompactWidth : SettingsWindow.ExpandedWidth
        this.WindowHeight := SettingsWindow.ClientHeight
        this.Gui := Gui("+Owner" this.OwnerWindow.Gui.Hwnd
            " +OwnDialogs -MinimizeBox -MaximizeBox", Tr("键鼠重映射小助手设置"))
        this.IconHandles := ApplyApplicationWindowIcon(this.Gui.Hwnd)
        this.OwnerLease := WindowHierarchy.Acquire(this.OwnerWindow.Gui,
            this.Gui.Hwnd)
        if !this.OwnerLease
            throw Error("无法建立设置窗口层级。")
        this.Gui.BackColor := colors.Window
        this.Gui.MarginX := 0
        this.Gui.MarginY := 0
        this.Gui.SetFont("norm s10 c" colors.Text, fontName)
        this.Interactions := MappingUiInteractions(this.Gui, colors.Window,
            this.OwnerWindow.App.SvgRenderer)

        Loop 4 {
            this.TabControls.Push([])
            this.TabBuilt.Push(false)
        }
        this.Gui.SetFont("norm " (isCompact ? "s9" : "s8") " c"
            UiThemeService.Color("TabText"), fontName)
        tabLabels := [Tr("外观"), Tr("规则包"), Tr("事件"), Tr("关于")]
        tabIcons := ["sliders-horizontal.svg", "file-output.svg", "logs.svg",
            "circle-info.svg"]
        tabGap := 8
        tabWidths := this.GetTabButtonWidths(tabLabels,
            this.WindowWidth - 30, isCompact, tabGap)
        tabGroupWidth := tabGap * (tabLabels.Length - 1)
        for tabWidth in tabWidths
            tabGroupWidth += tabWidth
        tabX := 15 + Floor(((this.WindowWidth - 30) - tabGroupWidth) / 2)
        for tabIndex, tabLabel in tabLabels {
            this.CreateTabButton(tabIndex, tabX, tabWidths[tabIndex],
                tabLabel, tabIcons[tabIndex])
            tabX += tabWidths[tabIndex] + tabGap
        }
        this.Gui.Add("Text", "x15 y46 w" (this.WindowWidth - 30)
            " h1 Background" colors.Divider)

        contentX := isCompact ? 30 : 40
        contentRight := this.WindowWidth - contentX
        contentWidth := contentRight - contentX
        this.Layout := {
            IsCompact: isCompact, FontName: fontName,
            WindowWidth: this.WindowWidth, ContentX: contentX,
            ContentRight: contentRight, ContentWidth: contentWidth
        }
        this.BuildAppearanceTab()

        this.ValidationStatus := this.Gui.Add("Text", "x25 y255 w"
            (this.WindowWidth - 50) " h22 Center 0x200 BackgroundTrans c"
                colors.Error, "")
        actionGroupX := Floor((this.WindowWidth - 170) / 2)
        this.SaveButton := this.AddActionButton(actionGroupX, 286,
            Tr("保存"), colors.Primary, colors.ButtonText,
            ObjBindMethod(this, "Save"))
        this.CancelButton := this.AddActionButton(actionGroupX + 90, 286,
            Tr("取消"), colors.Toolbar, colors.ToolbarText,
            ObjBindMethod(this, "RequestClose"))
        this.Gui.OnEvent("Close", ObjBindMethod(this, "RequestClose"))
        this.Gui.OnEvent("Escape", ObjBindMethod(this, "RequestClose"))
        this.SwitchTab(1)
    }

    BuildAppearanceTab() {
        layout := this.Layout
        colors := UiThemeService.GetPalette()
        this.Gui.SetFont("norm s10 c" colors.Text, layout.FontName)

        languageLabelWidth := layout.IsCompact ? 132 : 210
        languageInputX := layout.ContentX + languageLabelWidth + 12
        inputWidth := layout.ContentRight - languageInputX
        this.LanguageLabel := this.AddTabControl(1,
            this.AddFieldLabel(layout.ContentX, 106, languageLabelWidth,
                Tr("界面语言：")))
        languageLabels := []
        this.LanguageValues := []
        selectedLanguage := 1
        for index, choice in LocalizationService.GetLanguageChoices() {
            languageLabels.Push(choice.Label)
            this.LanguageValues.Push(choice.Code)
            if choice.Code == this.Original.UiLanguage
                selectedLanguage := index
        }
        this.LanguageDropDown := this.AddTabControl(1,
            this.AddDropDown(languageInputX, 108, inputWidth,
                languageLabels, selectedLanguage))

        this.FontLabel := this.AddTabControl(1,
            this.AddFieldLabel(layout.ContentX, 144, languageLabelWidth,
                Tr("界面内容字体：")))
        this.FontValues := ["auto"]
        fontLabels := [Tr("跟随语言默认（{1}）",
            LocalizationService.GetLanguageDefaultUiFontName())]
        selectedFontIndex := 1
        for installedFont in LocalizationService.GetInstalledUiFontNames() {
            this.FontValues.Push(installedFont)
            fontLabels.Push(installedFont)
            if StrLower(installedFont) == StrLower(this.Original.UiFont)
                selectedFontIndex := this.FontValues.Length
        }
        this.FontDropDown := this.AddTabControl(1,
            this.AddDropDown(languageInputX, 146, inputWidth,
                fontLabels, selectedFontIndex))
        OnMessage(Win32.WM_COMMAND, this.FontDropDownCommandHandler)
        this.FontDropDownCommandRegistered := true

        this.ThemeLabel := this.AddTabControl(1,
            this.AddFieldLabel(layout.ContentX, 182, languageLabelWidth,
                Tr("主题：")))
        this.ThemeValues := ["auto", "light", "dark"]
        themeLabels := [Tr("跟随系统"), Tr("浅色"), Tr("深色")]
        selectedTheme := 1
        for index, value in this.ThemeValues {
            if value == this.Original.Theme
                selectedTheme := index
        }
        this.ThemeDropDown := this.AddTabControl(1,
            this.AddDropDown(languageInputX, 184, inputWidth,
                themeLabels, selectedTheme))
        for controls in [[this.LanguageLabel, this.LanguageDropDown],
                [this.FontLabel, this.FontDropDown],
                [this.ThemeLabel, this.ThemeDropDown]]
            this.AlignControlCentersVertically(controls[1], controls[2])
        this.TabBuilt[1] := true
    }

    BuildRulePackageTab() {
        layout := this.Layout
        colors := UiThemeService.GetPalette()
        this.Gui.SetFont("norm s10 c" colors.Text, layout.FontName)
        buttonWidth := layout.IsCompact ? 150 : 190
        buttonGap := 16
        groupX := Floor((layout.WindowWidth - buttonWidth * 2
            - buttonGap) / 2)
        this.ImportRulePackageButton := this.AddTabControl(2,
            this.AddActionButton(groupX, 134, Tr("导入规则包"),
                colors.Primary, colors.ButtonText,
                ObjBindMethod(this, "ChooseImportRulePackage"),
                buttonWidth, 34))
        this.ExportRulePackageButton := this.AddTabControl(2,
            this.AddActionButton(groupX + buttonWidth + buttonGap, 134,
                Tr("导出规则包"), colors.Toolbar, colors.ToolbarText,
                ObjBindMethod(this, "ChooseExportRulePackage"),
                buttonWidth, 34))
        this.Interactions.SetButtonLucideIcon(this.ImportRulePackageButton,
            "square-plus.svg", 15, 6)
        this.Interactions.SetButtonLucideIcon(this.ExportRulePackageButton,
            "file-output.svg", 15, 6)
        this.TabBuilt[2] := true
    }

    BuildEventTab() {
        layout := this.Layout
        colors := UiThemeService.GetPalette()
        this.Gui.SetFont("norm s10 c" colors.Text, layout.FontName)
        labelWidth := layout.IsCompact ? 240 : 330
        inputWidth := 96
        fieldGap := 12
        fieldX := Floor((layout.WindowWidth - labelWidth - fieldGap
            - inputWidth) / 2)
        this.EventCapacityLabel := this.AddTabControl(3,
            this.AddFieldLabel(fieldX, 116, labelWidth,
                Tr("事件缓冲区容量（条）：")))
        this.EventCapacityInput := this.AddSettingsEdit(3,
            fieldX + labelWidth + fieldGap, 116, inputWidth,
            this.Original.EventBufferCapacity, "Number")
        this.AlignControlCentersVertically(this.EventCapacityLabel,
            this.EventCapacityInput.Edit)
        this.EventAutoScrollCheck := this.AddTabControl(3,
            this.Gui.Add("CheckBox", "x0 y164 h26 c" colors.Text,
                Tr("事件查看器自动跟随最新事件")))
        this.CenterControlHorizontally(this.EventAutoScrollCheck,
            layout.WindowWidth)
        this.EventAutoScrollCheck.Value :=
            this.Original.EventViewerAutoScroll ? 1 : 0
        ApplyDarkControl(this.EventCapacityInput.Edit.Hwnd)
        ApplyDarkControl(this.EventAutoScrollCheck.Hwnd)
        if !this.Interactions.RegisterTextInput(this.EventCapacityInput.Edit,
                this.EventCapacityInput.Background)
            throw Error("无法注册事件设置输入框交互。")
        this.Interactions.RegisterHandCursor(this.EventAutoScrollCheck)
        this.TabBuilt[3] := true
    }

    BuildAboutTab() {
        layout := this.Layout
        colors := UiThemeService.GetPalette()
        windowWidth := layout.WindowWidth
        contentX := layout.ContentX
        contentRight := layout.ContentRight
        fontName := layout.FontName
        logoSize := 44
        this.AboutLogo := this.AddTabControl(4, this.Gui.Add("Picture",
            "x" Floor((windowWidth - logoSize) / 2) " y62 w" logoSize
                " h" logoSize, GetApplicationIconPath()))
        this.Gui.SetFont("norm s14 c" colors.Text,
            LocalizationService.GetLanguageSystemUiFontName())
        this.AboutName := this.AddTabControl(4, this.Gui.Add("Text",
            "x" contentX " y112 w" (windowWidth - 2 * contentX)
                " h30 Center 0x280 BackgroundTrans", Tr("键鼠重映射小助手")))
        this.AboutName.SetFont("bold")
        this.Gui.SetFont("norm s9 c" colors.Muted, fontName)
        this.AboutSubtitle := this.AddTabControl(4, this.Gui.Add("Text",
            "x" contentX " y148 w" (windowWidth - 2 * contentX)
                " h22 Center 0x200 BackgroundTrans c" colors.Muted,
            Tr("让每一条键鼠映射都可录制、可审阅、可掌控")))
        dividerWidth := windowWidth - 2 * contentX
        this.AddTabControl(4, this.Gui.Add("Text", "x" contentX
            " y182 w" dividerWidth " h1 Background" colors.Divider))
        infoCenterX := Floor(windowWidth / 2)
        infoGap := layout.IsCompact ? 14 : 20
        leftInfoWidth := infoCenterX - infoGap - contentX
        rightInfoX := infoCenterX + infoGap
        rightInfoWidth := contentRight - rightInfoX
        this.Gui.SetFont("norm s10 c" colors.Muted, fontName)
        this.VersionLabel := this.AddTabControl(4, this.Gui.Add("Text",
            "x" contentX " y195 w" leftInfoWidth
                " h22 Center 0x200 BackgroundTrans c" colors.Muted,
            Tr("当前版本")))
        this.RuntimeLabel := this.AddTabControl(4, this.Gui.Add("Text",
            "x" rightInfoX " y195 w" rightInfoWidth
                " h22 Center 0x200 BackgroundTrans c" colors.Muted,
            Tr("运行环境")))
        this.Gui.SetFont("norm s11 c" colors.Text, fontName)
        this.VersionValue := this.AddTabControl(4, this.Gui.Add("Text",
            "x" contentX " y222 w" leftInfoWidth
                " h28 Center 0x200 BackgroundTrans",
            GetApplicationEditionSummary()))
        this.RuntimeValue := this.AddTabControl(4, this.Gui.Add("Text",
            "x" rightInfoX " y222 w" rightInfoWidth
                " h28 Center 0x200 BackgroundTrans",
            GetAutoHotkeyRuntimeSummary()))
        this.AddTabControl(4, this.Gui.Add("Text", "x" infoCenterX
            " y195 w1 h55 Background" colors.Divider))
        this.AddTabControl(4, this.Gui.Add("Text", "x" contentX
            " y263 w" dividerWidth " h1 Background" colors.Divider))
        releasesWidth := layout.IsCompact ? 126 : 205
        projectWidth := layout.IsCompact ? 112 : 175
        actionGap := 12
        actionX := Floor((windowWidth - releasesWidth - actionGap
            - projectWidth) / 2)
        this.ReleasesButton := this.AddTabControl(4,
            this.AddActionButton(actionX, 279, Tr("查看最新版本"),
                colors.Primary, colors.ButtonText,
                ObjBindMethod(this, "OpenLatestRelease"), releasesWidth, 36))
        this.ProjectButton := this.AddTabControl(4,
            this.AddActionButton(actionX + releasesWidth + actionGap, 279,
                Tr("开源地址"), colors.Toolbar, colors.ToolbarText,
                ObjBindMethod(this, "OpenProjectHomepage"), projectWidth, 36))
        this.Interactions.SetButtonLucideIcon(this.ReleasesButton,
            "refresh-cw-action.svg", 15, 7)
        this.Interactions.SetButtonSvgIcon(this.ProjectButton,
            GetApplicationAssetPath("ui-icons\external-link.svg"), 14, 7)
        this.Interactions.SetButtonTooltip(this.ProjectButton,
            SettingsWindow.ProjectHomeUrl)
        this.TabBuilt[4] := true
    }

    GetTabButtonWidths(tabLabels, availableWidth, isCompact, tabGap) {
        tabWidths := []
        desiredTotal := 0
        for tabLabel in tabLabels {
            labelLength := StrLen(tabLabel)
            tabWidth := isCompact
                ? Min(132, Max(70, 42 + labelLength * 14))
                : Min(210, Max(78, 42 + labelLength * 7))
            tabWidths.Push(tabWidth)
            desiredTotal += tabWidth
        }
        contentWidth := availableWidth - tabGap * (tabLabels.Length - 1)
        if desiredTotal <= contentWidth
            return tabWidths
        minWidth := isCompact ? 64 : 72
        adjustedTotal := 0
        scale := contentWidth / desiredTotal
        for tabIndex, tabWidth in tabWidths {
            tabWidths[tabIndex] := Max(minWidth, Floor(tabWidth * scale))
            adjustedTotal += tabWidths[tabIndex]
        }
        while adjustedTotal > contentWidth {
            for tabIndex, tabWidth in tabWidths {
                if adjustedTotal <= contentWidth
                    break
                if tabWidth > minWidth {
                    tabWidths[tabIndex] := tabWidth - 1
                    adjustedTotal--
                }
            }
        }
        return tabWidths
    }

    CreateTabButton(index, x, width, text, iconName) {
        button := this.Gui.Add("Text", "x" x " y12 w" width
            " h28 Center 0x200 Background" UiThemeService.Color("Tab")
                " c" UiThemeService.Color("TabText"), text)
        this.TabButtons.Push(button)
        this.TabButtonPages.Push(index)
        this.Interactions.RegisterButton(button, UiThemeService.Color("Tab"),
            ObjBindMethod(this, "SwitchTab", index), "", "", false,
            UiThemeService.Color("TabText"))
        this.Interactions.SetButtonLucideIcon(button, iconName, 14, 6)
        return button
    }

    AddTabControl(index, control) {
        this.TabControls[index].Push(control)
        if this.ActiveTab && index != this.ActiveTab
            try control.Visible := false
        return control
    }

    AddFieldLabel(x, y, width, text) {
        return this.Gui.Add("Text", "x" x " y" y " w" width
            " h30 Right 0x200 BackgroundTrans", text)
    }

    AddDropDown(x, y, width, labels, selectedIndex) {
        colors := UiThemeService.GetPalette()
        dropDown := this.Gui.Add("DropDownList", "x" x " y" y " w" width
            " Choose" selectedIndex " Background" colors.Input
            " c" colors.Text " -Border -E0x200",
            AddComboBoxDisplayPadding(labels))
        ApplyDarkComboBoxTheme(dropDown.Hwnd)
        return dropDown
    }

    AddSettingsEdit(index, x, y, width, value, extraOptions := "") {
        colors := UiThemeService.GetPalette()
        input := AddCenteredSingleLineEdit(this.Gui, x, y, width, 30,
            colors.Input, colors.Text, value)
        if extraOptions != ""
            input.Edit.Opt(extraOptions)
        this.AddTabControl(index, input.Background)
        this.AddTabControl(index, input.Edit)
        return input
    }

    AddActionButton(x, y, text, color, textColor, callback,
            width := 80, height := 28) {
        button := this.Gui.Add("Text", "x" x " y" y " w" width " h"
            height " Center 0x200 Background" color " c" textColor, text)
        button.SetFont("s10 bold",
            LocalizationService.GetLanguageSystemUiFontName())
        pressedColor := this.Interactions.DarkenColor(color)
        if !this.Interactions.RegisterButton(button, color, callback,
                "", pressedColor, false, textColor)
            button.OnEvent("Click", callback)
        return button
    }

    CenterControlHorizontally(control, windowWidth) {
        control.GetPos(, , &controlWidth)
        control.Move(Max(15, Floor((windowWidth - controlWidth) / 2)))
    }

    AlignControlCentersVertically(labelControl, inputControl) {
        labelControl.GetPos(, , , &labelHeight)
        inputControl.GetPos(, &inputY, , &inputHeight)
        labelControl.Move(, Round(inputY + (inputHeight - labelHeight) / 2))
    }

    EnsureTabBuilt(index) {
        if index < 1 || index > this.TabBuilt.Length
            return false
        if this.TabBuilt[index]
            return true
        switch index {
            case 2: this.BuildRulePackageTab()
            case 3: this.BuildEventTab()
            case 4: this.BuildAboutTab()
            default: return false
        }
        return this.TabBuilt[index]
    }

    SuspendTabRedraw() {
        transaction := {Active: false, Hwnd: 0}
        if this.Disposed || !this.Gui
            return transaction
        hwnd := this.Gui.Hwnd
        if !DllCall("user32\IsWindowVisible", "Ptr", hwnd, "Int")
            return transaction
        transaction.Hwnd := hwnd
        transaction.Active := true
        try SendMessage(Win32.WM_SETREDRAW, 0, 0, , hwnd)
        catch as suspendError {
            this.ResumeTabRedraw(transaction)
            throw suspendError
        }
        return transaction
    }

    ResumeTabRedraw(transaction) {
        if !IsObject(transaction) || !transaction.Active
            return
        transaction.Active := false
        hwnd := transaction.Hwnd
        if !DllCall("user32\IsWindow", "Ptr", hwnd, "Int")
            return
        SendMessage(Win32.WM_SETREDRAW, 1, 0, , hwnd)
        DllCall("user32\RedrawWindow", "Ptr", hwnd, "Ptr", 0,
            "Ptr", 0, "UInt", Win32.RDW_LAYOUT_REFRESH, "Int")
    }

    SwitchTab(index, *) {
        if index < 1 || index > this.TabControls.Length
            return false
        if this.ActiveTab == index
            return true
        redrawTransaction := this.SuspendTabRedraw()
        try {
            if !this.EnsureTabBuilt(index)
                return false
            for tabIndex, controls in this.TabControls {
                visible := tabIndex == index
                for control in controls
                    try control.Visible := visible
            }
            for buttonIndex, button in this.TabButtons {
                active := this.TabButtonPages[buttonIndex] == index
                this.Interactions.SetButtonAppearance(button,
                    UiThemeService.Color(active ? "TabActive" : "Tab"),
                    UiThemeService.Color(active
                        ? "TabActiveText" : "TabText"), true)
            }
            this.ActiveTab := index
            showActions := index == 1 || index == 3
            this.SaveButton.Visible := showActions
            this.CancelButton.Visible := showActions
            this.ValidationStatus.Visible := showActions
            return true
        } finally this.ResumeTabRedraw(redrawTransaction)
    }

    Show() {
        if this.Disposed
            return
        ShowPreparedWindow(this.Gui,
            "w" this.WindowWidth " h" this.WindowHeight,
            ObjBindMethod(this, "PrepareWindow"))
    }

    PrepareWindow(*) {
        this.ApplyNativeThemes()
        this.CenterOverOwner()
        return true
    }

    CenterOverOwner(*) {
        if this.Disposed || EnvGet("KEY_MOUSE_REMAPPER_GUI_TEST_OFFSCREEN")
                == "1"
            return true
        windowRect := Buffer(16, 0)
        ownerRect := Buffer(16, 0)
        if !DllCall("user32\GetWindowRect", "Ptr", this.Gui.Hwnd,
                "Ptr", windowRect.Ptr, "Int")
                || !DllCall("user32\GetWindowRect", "Ptr",
                    this.OwnerWindow.Gui.Hwnd, "Ptr", ownerRect.Ptr, "Int")
            return false
        windowWidth := NumGet(windowRect, 8, "Int")
            - NumGet(windowRect, 0, "Int")
        windowHeight := NumGet(windowRect, 12, "Int")
            - NumGet(windowRect, 4, "Int")
        if windowWidth <= 0 || windowHeight <= 0
            return false

        monitor := DllCall("user32\MonitorFromWindow", "Ptr",
            this.OwnerWindow.Gui.Hwnd, "UInt", 2, "Ptr")
        monitorInfo := Buffer(40, 0)
        NumPut("UInt", 40, monitorInfo, 0)
        if !monitor || !DllCall("user32\GetMonitorInfoW", "Ptr", monitor,
                "Ptr", monitorInfo.Ptr, "Int")
            return false
        workLeft := NumGet(monitorInfo, 20, "Int")
        workTop := NumGet(monitorInfo, 24, "Int")
        workRight := NumGet(monitorInfo, 28, "Int")
        workBottom := NumGet(monitorInfo, 32, "Int")
        parentLeft := NumGet(ownerRect, 0, "Int")
        parentTop := NumGet(ownerRect, 4, "Int")
        parentRight := NumGet(ownerRect, 8, "Int")
        parentBottom := NumGet(ownerRect, 12, "Int")
        position := SettingsWindow.CalculateCenteredPosition(windowWidth,
            windowHeight, parentLeft, parentTop, parentRight, parentBottom,
            workLeft, workTop, workRight, workBottom)
        return !!DllCall("user32\SetWindowPos", "Ptr", this.Gui.Hwnd,
            "Ptr", 0, "Int", position.X, "Int", position.Y,
            "Int", 0, "Int", 0,
            "UInt", 0x0015, "Int")
    }

    static CalculateCenteredPosition(windowWidth, windowHeight,
            parentLeft, parentTop, parentRight, parentBottom,
            workLeft, workTop, workRight, workBottom) {
        x := Round((parentLeft + parentRight - windowWidth) / 2)
        y := Round((parentTop + parentBottom - windowHeight) / 2)
        workWidth := Max(0, workRight - workLeft)
        workHeight := Max(0, workBottom - workTop)
        x := windowWidth >= workWidth ? workLeft
            : Max(workLeft, Min(x, workRight - windowWidth))
        y := windowHeight >= workHeight ? workTop
            : Max(workTop, Min(y, workBottom - windowHeight))
        return {X: x, Y: y}
    }

    ApplyNativeThemes(*) {
        if this.Disposed
            return false
        ApplyDarkWindow(this.Gui.Hwnd)
        this.ApplyComboBoxThemes()
        for controlName in ["EventAutoScrollCheck"] {
            if this.HasOwnProp(controlName) && this.%controlName%
                ApplyDarkControl(this.%controlName%.Hwnd)
        }
        for inputName in ["EventCapacityInput"] {
            if this.HasOwnProp(inputName) && IsObject(this.%inputName%)
                ApplyDarkControl(this.%inputName%.Edit.Hwnd)
        }
        return true
    }

    ApplyComboBoxThemes() {
        for dropDownName in ["LanguageDropDown", "FontDropDown",
                "ThemeDropDown"] {
            if this.HasOwnProp(dropDownName) && this.%dropDownName%
                ApplyDarkComboBoxTheme(this.%dropDownName%.Hwnd)
        }
    }

    OnFontDropDownCommand(wParam, lParam, *) {
        if this.Disposed || !this.FontDropDownCommandRegistered
            || lParam != this.FontDropDown.Hwnd
            || ((wParam >> 16) & 0xFFFF) != Win32.CBN_DROPDOWN
            return
        this.RefreshFontDropDown()
    }

    RefreshFontDropDown(*) {
        if this.Disposed || this.FontRefreshInProgress
            return false
        this.FontRefreshInProgress := true
        try {
            selectedFontValue := "auto"
            selectedIndex := this.FontDropDown.Value
            if selectedIndex >= 1 && selectedIndex <= this.FontValues.Length
                selectedFontValue := this.FontValues[selectedIndex]
            LocalizationService.RefreshInstalledUiFontNames()
            defaultFontName := LocalizationService
                .GetLanguageDefaultUiFontName()
            refreshedFonts := LocalizationService.GetInstalledUiFontNames()
            fontLabels := [Tr("跟随语言默认（{1}）", defaultFontName)]
            refreshedValues := ["auto"]
            refreshedSelection := 1
            for installedFont in refreshedFonts {
                refreshedValues.Push(installedFont)
                fontLabels.Push(installedFont)
                if StrLower(installedFont) == StrLower(selectedFontValue)
                    refreshedSelection := refreshedValues.Length
            }
            UnregisterDarkComboBoxTheme(this.FontDropDown.Hwnd)
            this.FontDropDown.Delete()
            this.FontDropDown.Add(AddComboBoxDisplayPadding(fontLabels))
            this.FontValues := refreshedValues
            this.FontDropDown.Value := refreshedSelection
            ApplyDarkComboBoxTheme(this.FontDropDown.Hwnd)
            return true
        } finally this.FontRefreshInProgress := false
    }

    ParseRangedInteger(value, fieldName, minimum, maximum) {
        text := Trim(String(value))
        if !RegExMatch(text, "^\d+$")
            throw ValueError(Tr("“{1}”必须是 {2} 到 {3} 之间的整数。",
                fieldName, minimum, maximum))
        try parsedNumber := Integer(text)
        catch
            throw ValueError(Tr("“{1}”必须是 {2} 到 {3} 之间的整数。",
                fieldName, minimum, maximum))
        if parsedNumber < minimum || parsedNumber > maximum
            throw ValueError(Tr("“{1}”必须是 {2} 到 {3} 之间的整数。",
                fieldName, minimum, maximum))
        return parsedNumber
    }

    GetCandidate() {
        eventCapacity := this.Original.EventBufferCapacity
        if this.TabBuilt[3]
            eventCapacity := this.ParseRangedInteger(
                this.EventCapacityInput.Edit.Value, Tr("事件缓冲区容量"),
                AppSettingsService.MinimumEventBufferCapacity,
                AppSettingsService.MaximumEventBufferCapacity)
        return {
            UiLanguage: this.LanguageValues[this.LanguageDropDown.Value],
            UiFont: this.FontValues[this.FontDropDown.Value],
            Theme: this.ThemeValues[this.ThemeDropDown.Value],
            EventBufferCapacity: eventCapacity,
            EventViewerAutoScroll: this.TabBuilt[3]
                ? this.EventAutoScrollCheck.Value != 0
                : this.Original.EventViewerAutoScroll
        }
    }

    Save(*) {
        if this.Disposed
            return false
        this.ValidationStatus.Text := ""
        try candidate := this.GetCandidate()
        catch as validationError {
            this.ValidationStatus.Text := validationError.Message
            return false
        }
        if this.OwnerWindow.App.SaveSettings(candidate) {
            this.Dispose()
            return true
        }
        try this.ValidationStatus.Text := this.OwnerWindow.Status.Text
        return false
    }

    OpenLatestRelease(*) {
        if !this.Disposed
            try Run(SettingsWindow.ReleasesUrl)
    }

    OpenProjectHomepage(*) {
        if !this.Disposed
            try Run(SettingsWindow.ProjectHomeUrl)
    }

    ChooseImportRulePackage(*) {
        if this.Disposed
            return false
        return this.OwnerWindow.App.ChooseImportRulePackage(this)
    }

    ChooseExportRulePackage(*) {
        if this.Disposed
            return false
        return this.OwnerWindow.App.ChooseExportRulePackage()
    }

    OnRulePackageImportClosed(previewWindow) {
        return this.OwnerWindow.OnRulePackageImportClosed(previewWindow)
    }

    RequestClose(*) {
        this.Dispose()
    }

    Activate() {
        if this.Disposed
            return
        return ActivatePreparedWindow(this.Gui)
    }

    Dispose(activateOwner := true) {
        if this.Disposed
            return
        this.Disposed := true
        cleanup := CleanupCollector("设置窗口")
        if this.FontDropDownCommandRegistered {
            if cleanup.Run("注销字体下拉框消息", () =>
                    OnMessage(Win32.WM_COMMAND,
                        this.FontDropDownCommandHandler, 0))
                this.FontDropDownCommandRegistered := false
        }
        for dropDownName in ["LanguageDropDown", "FontDropDown",
                "ThemeDropDown"] {
            if this.HasOwnProp(dropDownName) && this.%dropDownName% {
                dropDown := this.%dropDownName%
                cleanup.Run("注销下拉框主题",
                    UnregisterDarkComboBoxTheme.Bind(dropDown.Hwnd))
            }
        }
        closeContext := ""
        if this.OwnerLease {
            try {
                closeContext := WindowHierarchy.Release(this.OwnerLease)
                this.OwnerLease := ""
            } catch as ownerError {
                cleanup.Failures.Push("释放父窗口关系：" ownerError.Message)
            }
        }
        if IsObject(this.Interactions)
                && cleanup.Run("释放交互服务",
                    () => this.Interactions.Dispose())
            this.Interactions := ""
        if IsObject(this.Gui)
                && cleanup.Run("销毁窗口", () => this.Gui.Destroy())
            this.Gui := ""
        if cleanup.Run("释放窗口图标",
                () => ReleaseApplicationWindowIcons(this.IconHandles))
            this.IconHandles := []
        this.TabButtons := []
        this.TabButtonPages := []
        this.TabControls := []
        this.TabBuilt := []
        if !this.FontDropDownCommandRegistered
            this.FontDropDownCommandHandler := ""
        cleanup.Run("通知父窗口",
            () => this.OwnerWindow.OnSettingsClosed(this))
        if activateOwner
            cleanup.Run("恢复父窗口", () =>
                WindowHierarchy.CompleteClose(closeContext))
        cleanup.Complete()
        return true
    }
}
