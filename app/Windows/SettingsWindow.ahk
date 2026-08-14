class SettingsWindow {
    static CompactWidth := 520
    static ExpandedWidth := 680
    static ClientHeight := 420
    static SparseMenuTopOffset := 24
    static AIConnectionStatusGap := 24
    static AIConnectionStatusRightMargin := 12
    static AIConnectionStatusTop := 48
    static AIConnectionStatusBottom := 296
    __New(ownerWindow, initialTab := 1) {
        this.OwnerWindow := ownerWindow
        this.App := ownerWindow.App
        initialTab := Integer(initialTab)
        if initialTab < 1 || initialTab > 4
            throw ValueError("设置窗口初始选项卡无效。")
        this.InitialTab := initialTab
        this.Gui := ""
        this.OwnerLease := ""
        this.IconHandles := []
        this.Interactions := ""
        this.Disposed := false
        this.Original := ownerWindow.App.Settings
        this.AIPromptDraft := this.Original.HasOwnProp("AIPrompt")
            ? this.Original.AIPrompt : AIService.DefaultGeneratePrompt
        this.AIOptimizePromptDraft := this.Original.HasOwnProp(
            "AIOptimizePrompt") ? this.Original.AIOptimizePrompt
                : AIService.DefaultOptimizePrompt
        this.AISystemPromptDraft := this.Original.HasOwnProp("AISystemPrompt")
            ? this.Original.AISystemPrompt : AIService.DefaultSystemPrompt
        this.TabButtons := []
        this.TabButtonPages := []
        this.TabControls := []
        this.TabBuilt := []
        this.ActiveTab := 0
        this.FontDropDownCommandHandler := ObjBindMethod(this,
            "OnFontDropDownCommand")
        this.FontDropDownCommandRegistered := false
        this.FontRefreshInProgress := false
        this.FontDropDownTopIndex := 0
        this.ShortcutFeedbackTimer := 0
        this.ShortcutFeedbackGeneration := 0
        this.AIConnectionStatusColorName := "Muted"
        this.StartupTaskButtonReady := false
        this.SelectableTextControls := []
        this.AIConnectionRequestId := 0
        this.AIConnectionTestBusy := false
        this.ValidationStatusColorName := "Error"
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
        tabLabels := [Tr("显示"), Tr("启动"), Tr("AI 设置"),
            Tr("规则与事件")]
        tabIcons := ["monitor.svg", "power.svg",
            "pencil-sparkles.svg", "file-output.svg"]
        tabGap := 8
        tabWidths := this.GetTabButtonWidths(tabLabels,
            this.WindowWidth - 30, isCompact, tabGap)
        tabGroupWidth := tabGap * (tabLabels.Length - 1)
        for tabWidth in tabWidths
            tabGroupWidth += tabWidth
        tabX := 15 + Floor(((this.WindowWidth - 30) - tabGroupWidth) / 2)
        for tabIndex, tabLabel in tabLabels {
            this.CreateTabButton(tabIndex, tabX, tabWidths[tabIndex],
                tabLabel, tabIcons[tabIndex], this.GetTabIconColor(tabIndex))
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
        this.ValidationStatus := this.Gui.Add("Text", "x25 y352 w"
            (this.WindowWidth - 50) " h18 Center 0x200 BackgroundTrans c"
                colors.Error, "")
        actionGroupX := Floor((this.WindowWidth - 170) / 2)
        this.SaveButton := this.AddActionButton(actionGroupX, 376,
            Tr("保存"), colors.Save, colors.ButtonText,
            ObjBindMethod(this, "Save"))
        this.CancelButton := this.AddActionButton(actionGroupX + 90, 376,
            Tr("取消"), colors.Toolbar, colors.ToolbarText,
            ObjBindMethod(this, "RequestClose"))
        this.Gui.OnEvent("Close", ObjBindMethod(this, "RequestClose"))
        this.Gui.OnEvent("Escape", ObjBindMethod(this, "RequestClose"))
        this.SwitchTab(this.InitialTab)
    }

    BuildStartupTab() {
        pageIndex := 2
        layout := this.Layout
        colors := UiThemeService.GetPalette()
        this.Gui.SetFont("norm s10 c" colors.Text, layout.FontName)
        this.ShortcutLabel := this.AddSelectableMenuText(pageIndex,
            layout.ContentX, 62, Tr("桌面与开始菜单快捷方式"))
        this.StartupTaskLabel := this.AddSelectableMenuText(pageIndex,
            layout.ContentX, 98, Tr("开机自动启动（计划任务）"))
        this.ShortcutLabel.GetPos(, , &shortcutLabelWidth)
        this.StartupTaskLabel.GetPos(, , &taskLabelWidth)
        integrationLabelWidth := Max(shortcutLabelWidth, taskLabelWidth)
        integrationGap := 18
        integrationButtonWidth := 72
        integrationGroupWidth := integrationLabelWidth + integrationGap
            + integrationButtonWidth
        integrationGroupX := Max(15,
            Floor((layout.WindowWidth - integrationGroupWidth) / 2))
        integrationActionX := integrationGroupX + integrationLabelWidth
            + integrationGap
        this.ShortcutLabel.Move(integrationGroupX)
        this.StartupTaskLabel.Move(integrationGroupX)
        this.ShortcutButton := this.AddTabControl(pageIndex,
            this.AddActionButton(integrationActionX, 58, Tr("创建"),
                colors.Toolbar, colors.ToolbarText,
                ObjBindMethod(this, "CreateShortcuts"), 72, 28))
        this.ShortcutLabel.SetFont("norm s10", layout.FontName)
        this.StartupTaskLabel.SetFont("norm s10", layout.FontName)
        this.ShortcutButton.SetFont("norm s10", layout.FontName)
        this.ShortcutFeedback := this.AddSelectableMenuText(pageIndex,
            integrationActionX, 62, Tr("创建成功！"), 1, 20, "Center")
        this.ShortcutFeedback.SetFont("norm s10", layout.FontName)
        this.ShortcutFeedback.GetPos(, , &shortcutFeedbackWidth)
        shortcutFeedbackX := integrationActionX
            + Floor((integrationButtonWidth - shortcutFeedbackWidth) / 2)
        shortcutFeedbackX := Max(integrationActionX - integrationGap + 4,
            Min(shortcutFeedbackX,
                layout.ContentRight - shortcutFeedbackWidth))
        this.ShortcutFeedback.Move(shortcutFeedbackX, ,
            shortcutFeedbackWidth)
        this.ShortcutFeedback.Visible := false
        this.Interactions.SetButtonLucideIcon(this.ShortcutButton,
            "square-plus.svg", 14, 6,
            UiThemeService.ButtonIconColor(colors.DisplayIcon))
        this.StartupTaskButton := this.AddTabControl(pageIndex,
            this.AddActionButton(integrationActionX, 94, "…", colors.Toolbar,
                colors.ToolbarText, ObjBindMethod(this, "ToggleStartupTask"),
                72, 28))
        this.StartupTaskButton.SetFont("norm s10", layout.FontName)
        this.Interactions.SetButtonLucideIcon(this.StartupTaskButton,
            "loader-circle.svg", 14, 6,
            UiThemeService.ButtonIconColor(colors.DisplayIcon))
        this.Interactions.SetButtonAppearance(this.StartupTaskButton,
            colors.Toolbar, colors.ToolbarText, false)
        runAsAdministratorText := Tr("以管理员身份运行")
        checkUpdatesText := Tr("启动时检查小助手更新")
        showAtStartupText := Tr("启动时显示主窗口")
        runAsAdministratorWidth := this.MeasureControlTextWidth(
            this.ShortcutLabel, runAsAdministratorText) + 34
        checkUpdatesWidth := this.MeasureControlTextWidth(
            this.ShortcutLabel, checkUpdatesText) + 34
        showAtStartupWidth := this.MeasureControlTextWidth(
            this.ShortcutLabel, showAtStartupText) + 34
        startupGroupWidth := Min(layout.ContentWidth,
            Max(runAsAdministratorWidth, checkUpdatesWidth,
                showAtStartupWidth))
        runAsAdministratorWidth := Min(runAsAdministratorWidth,
            startupGroupWidth)
        checkUpdatesWidth := Min(checkUpdatesWidth, startupGroupWidth)
        showAtStartupWidth := Min(showAtStartupWidth, startupGroupWidth)
        startupGroupX := Floor((layout.WindowWidth - startupGroupWidth) / 2)
        startupGroupX := Max(layout.ContentX,
            Min(startupGroupX, layout.ContentRight - startupGroupWidth))
        this.RunAsAdministratorCheck := this.AddTabControl(pageIndex,
            this.Gui.Add("CheckBox", "x" startupGroupX " y144 w"
                runAsAdministratorWidth " h24 c" colors.Text,
                runAsAdministratorText))
        this.RunAsAdministratorCheck.Value :=
            this.Original.RunAsAdministrator ? 1 : 0
        this.CheckUpdatesOnStartupCheck := this.AddTabControl(pageIndex,
            this.Gui.Add("CheckBox", "x" startupGroupX " y176 w"
                checkUpdatesWidth " h24 c" colors.Text, checkUpdatesText))
        this.CheckUpdatesOnStartupCheck.Value :=
            this.Original.CheckUpdatesOnStartup ? 1 : 0
        this.ShowAtStartupCheck := this.AddTabControl(pageIndex,
            this.Gui.Add("CheckBox", "x" startupGroupX
                " y208 w" showAtStartupWidth " h24 c" colors.Text,
                showAtStartupText))
        this.ShowAtStartupCheck.Value := this.Original.ShowAtStartup ? 1 : 0
        for checkControl in [this.RunAsAdministratorCheck,
                this.CheckUpdatesOnStartupCheck, this.ShowAtStartupCheck] {
            ApplyDarkControl(checkControl.Hwnd)
            this.Interactions.RegisterHandCursor(checkControl)
        }
        this.ApplySparseMenuTopSpacing(pageIndex)
        this.TabBuilt[pageIndex] := true
    }

    BuildAppearanceTab() {
        pageIndex := 1
        layout := this.Layout
        colors := UiThemeService.GetPalette()
        this.Gui.SetFont("norm s10 c" colors.Text, layout.FontName)
        menuControlWidth := layout.ContentRight
            - Floor(layout.WindowWidth / 2) - 12
        this.LanguageIcon := this.AddMenuIcon(pageIndex, 68,
            "languages.svg", colors.LanguageIcon)
        this.LanguageLabel := this.AddMenuLabel(pageIndex, 68,
            Tr("界面语言："))
        languageLabels := []
        this.LanguageValues := []
        selectedLanguage := 1
        for index, choice in LocalizationService.GetLanguageChoices() {
            languageLabels.Push(choice.Label)
            this.LanguageValues.Push(choice.Code)
            if choice.Code == this.Original.UiLanguage
                selectedLanguage := index
        }
        this.LanguageDropDown := this.AddTabControl(pageIndex,
            this.AddDropDown(0, 92, menuControlWidth,
                languageLabels, selectedLanguage))

        this.FontIcon := this.AddMenuIcon(pageIndex, 136,
            "type.svg", colors.FontIcon)
        this.FontLabel := this.AddMenuLabel(pageIndex, 136,
            Tr("界面内容字体："))
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
        fontDropDownRows := 12
        this.FontDropDown := this.AddTabControl(pageIndex,
            this.AddDropDown(0, 160, menuControlWidth,
                fontLabels, selectedFontIndex, fontDropDownRows))
        OnMessage(Win32.WM_COMMAND, this.FontDropDownCommandHandler)
        this.FontDropDownCommandRegistered := true

        this.ThemeIcon := this.AddMenuIcon(pageIndex, 204,
            "palette.svg", colors.ThemeIcon)
        this.ThemeLabel := this.AddMenuLabel(pageIndex, 204,
            Tr("主题："))
        this.ThemeValues := ["auto", "light", "dark"]
        themeLabels := [Tr("跟随系统"), Tr("浅色"), Tr("深色")]
        selectedTheme := 1
        for index, value in this.ThemeValues {
            if value == this.Original.Theme
                selectedTheme := index
        }
        this.ThemeDropDown := this.AddTabControl(pageIndex,
            this.AddDropDown(0, 228, menuControlWidth,
                themeLabels, selectedTheme))
        this.AlignAppearanceTabControls()
        this.ApplySparseMenuTopSpacing(pageIndex)
        this.TabBuilt[pageIndex] := true
    }

    BuildRulesAndEventTab() {
        layout := this.Layout
        colors := UiThemeService.GetPalette()
        this.Gui.SetFont("norm s10 c" colors.Text, layout.FontName)
        buttonWidth := layout.IsCompact ? 150 : 190
        groupX := Floor((layout.WindowWidth - buttonWidth) / 2)
        this.ImportRulePackageButton := this.AddTabControl(4,
            this.AddActionButton(groupX, 68, Tr("导入规则包"),
                colors.Primary, colors.ButtonText,
                ObjBindMethod(this, "ChooseImportRulePackage"),
                buttonWidth, 34))
        this.ExportRulePackageButton := this.AddTabControl(4,
            this.AddActionButton(groupX, 108, Tr("导出规则包"),
                colors.Toolbar, colors.ToolbarText,
                ObjBindMethod(this, "ChooseExportRulePackage"),
                buttonWidth, 34))
        this.Interactions.SetButtonLucideIcon(this.ImportRulePackageButton,
            "square-plus.svg", 15, 6,
            UiThemeService.ButtonIconColor(colors.ButtonText))
        this.Interactions.SetButtonLucideIcon(this.ExportRulePackageButton,
            "file-output.svg", 15, 6, colors.RulesEventIcon)
        this.RuleEventDivider := this.AddTabControl(4,
            this.Gui.Add("Text", "x" layout.ContentX " y162 w"
                layout.ContentWidth " h1 Background" colors.Divider))
        inputWidth := 96
        this.EventCapacityLabel := this.AddMenuLabel(4, 182,
            Tr("事件缓冲区容量（条）："))
        this.EventCapacityInput := this.AddSettingsEdit(4, 0, 206, inputWidth,
            this.Original.EventBufferCapacity, "Number")
        this.EscapeCancelCheck := this.AddTabControl(4,
            this.Gui.Add("CheckBox", "x0 y242 h26 c" colors.Text,
                Tr("Esc 取消录制")))
        this.EscapeCancelCheck.Value :=
            this.Original.EscapeCancelsRecording ? 1 : 0
        this.EventAutoScrollCheck := this.AddTabControl(4,
            this.Gui.Add("CheckBox", "x0 y274 h26 c" colors.Text,
                Tr("事件查看自动跟随最新事件")))
        this.EventAutoScrollCheck.Value :=
            this.Original.EventViewerAutoScroll ? 1 : 0
        this.AlignEventTabControls()
        ApplyDarkControl(this.EventCapacityInput.Edit.Hwnd)
        for checkControl in [this.EscapeCancelCheck,
                this.EventAutoScrollCheck] {
            ApplyDarkControl(checkControl.Hwnd)
            this.Interactions.RegisterHandCursor(checkControl)
        }
        if !this.Interactions.RegisterTextInput(this.EventCapacityInput.Edit,
                this.EventCapacityInput.Background)
            throw Error("无法注册事件设置输入框交互。")
        this.ApplySparseMenuTopSpacing(4)
        this.TabBuilt[4] := true
    }

    BuildAITab() {
        layout := this.Layout
        colors := UiThemeService.GetPalette()
        this.Gui.SetFont("norm s10 c" colors.Text, layout.FontName)
        inputWidth := layout.ContentRight
            - Floor(layout.WindowWidth / 2) - 12
        editButtonWidth := 80
        testButtonWidth := layout.IsCompact ? 96 : 132
        fields := [
            {Name: "AIAddressLabel", Text: Tr("API 地址："), Y: 56},
            {Name: "AIKeyLabel", Text: Tr("API 密钥："), Y: 118},
            {Name: "AIModelLabel", Text: Tr("模型名称："), Y: 180},
            {Name: "AITimeoutLabel", Text: Tr("请求超时（秒）："), Y: 242},
            {Name: "AIPromptsLabel", Text: Tr("提示词："), Y: 322}
        ]
        for field in fields
            this.%field.Name% := this.AddMenuLabel(3, field.Y, field.Text)
        this.AIAddressInput := this.AddSettingsEdit(3, 0, 80,
            inputWidth, this.Original.AIAddress)
        this.AIKeyInput := this.AddSettingsEdit(3, 0, 142,
            inputWidth, this.Original.AIKey)
        this.AIModelInput := this.AddSettingsEdit(3, 0, 204,
            inputWidth, this.Original.AIModel)
        this.AITimeoutInput := this.AddSettingsEdit(3, 0, 266,
            96, this.Original.AITimeoutS, "Number")
        for input in [this.AIAddressInput, this.AIKeyInput,
                this.AIModelInput, this.AITimeoutInput] {
            ApplyDarkControl(input.Edit.Hwnd)
            if !this.Interactions.RegisterTextInput(input.Edit,
                    input.Background)
                throw Error("无法注册 AI 设置输入框交互。")
        }
        this.AITestConnectionButton := this.AddActionButton(0, 266,
            Tr("测试连接"), colors.Toolbar, colors.ToolbarText,
            ObjBindMethod(this, "TestAIConnection"), testButtonWidth, 30)
        testButtonWidth := Min(layout.ContentWidth - 108,
            this.MeasureRequiredIconButtonWidth(
                this.AITestConnectionButton, [Tr("测试连接")],
                testButtonWidth))
        this.AITestConnectionButton.Move(, , testButtonWidth)
        this.AddTabControl(3, this.AITestConnectionButton)
        this.AIConnectionStatus := this.AddTabControl(3,
            this.Gui.Add("Edit", "x0 y266 w1 h30 ReadOnly Multi Wrap"
                " -TabStop -Border -VScroll -HScroll -E0x200 Background"
                colors.Window " c" colors.Muted, ""))
        ApplyDarkControl(this.AIConnectionStatus.Hwnd)
        if !this.Interactions.RegisterTextInput(this.AIConnectionStatus)
            throw Error("无法注册 AI 连接测试结果复制交互。")
        this.AIParametersDivider := this.AddTabControl(3,
            this.Gui.Add("Text", "x" layout.ContentX " y308 w"
                layout.ContentWidth " h1 Background" colors.Divider))
        this.AIPromptsButton := this.AddActionButton(0, 319,
            Tr("编辑"), colors.Toolbar, colors.ToolbarText,
            ObjBindMethod(this, "EditAIPrompts"), editButtonWidth, 26)
        this.AddTabControl(3, this.AIPromptsButton)
        this.AlignAITabControls()
        this.ApplySparseMenuTopSpacing(3)
        this.TabBuilt[3] := true
    }

    ApplySparseMenuTopSpacing(index) {
        if index < 1 || index > this.TabControls.Length
            return false
        controls := this.TabControls[index]
        if controls.Length == 0
            return false
        top := 0
        bottom := 0
        for controlIndex, control in controls {
            control.GetPos(, &controlY, , &controlHeight)
            if controlIndex == 1 || controlY < top
                top := controlY
            bottom := Max(bottom, controlY + controlHeight)
        }
        if bottom - top >= Floor(this.WindowHeight / 2)
            return false
        for control in controls {
            control.GetPos(, &controlY)
            control.Move(, controlY + SettingsWindow.SparseMenuTopOffset)
        }
        return true
    }

    MoveSettingsInput(input, x, width := 0) {
        input.Background.GetPos(, &inputY, &currentWidth, &inputHeight)
        if width <= 0
            width := currentWidth
        input.Edit.GetPos(, , , &editHeight)
        input.Background.Move(x, inputY, width, inputHeight)
        input.Edit.Move(x, inputY + Floor((inputHeight - editHeight) / 2),
            width, editHeight)
        return true
    }

    GetActualClientWidth() {
        width := this.WindowWidth
        try this.Gui.GetClientPos(,, &clientWidth)
        catch
            clientWidth := 0
        if clientWidth > 0
            width := clientWidth
        return width
    }

    AlignAppearanceTabControls() {
        if !this.HasOwnProp("LanguageLabel")
            return false
        iconSlotWidth := 28
        labels := [this.LanguageLabel, this.FontLabel, this.ThemeLabel]
        this.LanguageDropDown.GetPos(, , &languageWidth)
        this.FontDropDown.GetPos(, , &fontWidth)
        this.ThemeDropDown.GetPos(, , &themeWidth)
        itemWidths := [languageWidth, fontWidth, themeWidth]
        for label in labels
            itemWidths.Push(this.MeasureControlTextWidth(label, label.Text)
                + iconSlotWidth + 2)
        layout := this.AlignMenuColumn(labels, itemWidths)
        for spec in [
                {Icon: this.LanguageIcon, Label: this.LanguageLabel},
                {Icon: this.FontIcon, Label: this.FontLabel},
                {Icon: this.ThemeIcon, Label: this.ThemeLabel}] {
            spec.Icon.Move(layout.X)
            spec.Label.Move(layout.X + iconSlotWidth, ,
                this.GetSelectableTextWidth(spec.Label))
        }
        this.LanguageDropDown.Move(layout.X)
        this.FontDropDown.Move(layout.X)
        this.ThemeDropDown.Move(layout.X)
        return true
    }

    AlignEventTabControls() {
        if !this.HasOwnProp("EventCapacityLabel")
            return false
        this.EventCapacityInput.Background.GetPos(, , &inputWidth)
        this.EscapeCancelCheck.GetPos(, , &escapeWidth)
        this.EventAutoScrollCheck.GetPos(, , &autoScrollWidth)
        layout := this.AlignMenuColumn([this.EventCapacityLabel],
            [inputWidth, escapeWidth, autoScrollWidth])
        this.MoveSettingsInput(this.EventCapacityInput, layout.X, inputWidth)
        this.EscapeCancelCheck.Move(layout.X)
        this.EventAutoScrollCheck.Move(layout.X)
        return true
    }

    AlignAITabControls() {
        if !this.HasOwnProp("AIAddressLabel")
            return false
        clientWidth := this.GetActualClientWidth()
        labels := [this.AIAddressLabel, this.AIKeyLabel, this.AIModelLabel,
            this.AITimeoutLabel]
        this.AIAddressInput.Background.GetPos(, , &wideInputWidth)
        this.AITestConnectionButton.GetPos(, , &testButtonWidth)
        timeoutRowWidth := 96 + 12 + testButtonWidth
        layout := this.AlignMenuColumn(labels,
            [wideInputWidth, timeoutRowWidth], clientWidth)
        this.MoveSettingsInput(this.AIAddressInput, layout.X,
            wideInputWidth)
        this.MoveSettingsInput(this.AIKeyInput, layout.X, wideInputWidth)
        this.MoveSettingsInput(this.AIModelInput, layout.X, wideInputWidth)
        this.MoveSettingsInput(this.AITimeoutInput, layout.X, 96)
        testButtonX := layout.X + 108
        this.AITestConnectionButton.Move(testButtonX)
        statusX := testButtonX + testButtonWidth
            + SettingsWindow.AIConnectionStatusGap
        statusWidth := Max(1,
            clientWidth - SettingsWindow.AIConnectionStatusRightMargin
                - statusX)
        this.AIConnectionStatus.Move(statusX, 266, statusWidth, 30)
        this.LayoutAIConnectionStatus(this.AIConnectionStatus.Text)
        promptLabelWidth := this.GetSelectableTextWidth(
            this.AIPromptsLabel)
        promptRowWidth := promptLabelWidth + 12 + 80
        promptRowX := Max(this.Layout.ContentX,
            Floor((clientWidth - promptRowWidth) / 2))
        this.AIPromptsLabel.Move(promptRowX, , promptLabelWidth)
        this.AIPromptsButton.Move(promptRowX + promptLabelWidth + 12)
        return true
    }

    EditAIPrompts(*) {
        if this.Disposed
            return false
        editor := AIPromptsEditor(this, this.AIPromptDraft,
            this.AIOptimizePromptDraft, this.AISystemPromptDraft)
        result := editor.Show()
        if result.Accepted {
            this.AIPromptDraft := result.GeneratePrompt
            this.AIOptimizePromptDraft := result.OptimizePrompt
            this.AISystemPromptDraft := result.SystemPrompt
        }
        return result.Accepted
    }

    TestAIConnection(*) {
        if this.Disposed || this.AIConnectionTestBusy
            return false
        try settings := this.GetAIConnectionSettings()
        catch as validationError {
            this.SetAIConnectionStatus(validationError.Message, "Error")
            return false
        }
        try {
            this.App.SaveAIConnectionSettings(settings)
            this.Original := this.App.Settings
        } catch as saveError {
            this.SetAIConnectionStatus(Tr("AI 参数未保存：{1}",
                TrDiagnostic(saveError.Message)), "Error")
            return false
        }
        if !IsObject(this.App.AIService) {
            this.SetAIConnectionStatus(Tr("AI 服务尚未初始化。"), "Error")
            return false
        }
        this.AIConnectionTestBusy := true
        this.RefreshAIConnectionTestButton()
        this.SetAIConnectionStatus(Tr("正在测试 AI 连接…"), "Muted")
        try result := this.App.AIService.TestConnection(settings,
            ObjBindMethod(this, "HandleAIConnectionTestResult"))
        catch as requestError {
            this.AIConnectionTestBusy := false
            this.RefreshAIConnectionTestButton()
            this.SetAIConnectionStatus(this.FormatAIConnectionFailure(
                requestError.Message), "Error")
            return false
        }
        if !result.Ok {
            this.AIConnectionTestBusy := false
            this.RefreshAIConnectionTestButton()
            this.SetAIConnectionStatus(this.FormatAIConnectionFailure(
                result.Message), "Error")
            return false
        }
        this.AIConnectionRequestId := result.RequestId
        return true
    }

    GetAIConnectionSettings() {
        address := Trim(String(this.AIAddressInput.Edit.Value))
        model := Trim(String(this.AIModelInput.Edit.Value))
        if address == ""
            throw ValueError(Tr("请填写 API 地址。"))
        if model == ""
            throw ValueError(Tr("请填写模型名称。"))
        return {
            AIAddress: address,
            AIKey: Trim(String(this.AIKeyInput.Edit.Value)),
            AIModel: model,
            AITimeoutS: this.ParseRangedInteger(
                this.AITimeoutInput.Edit.Value,
                Tr("请求超时（秒）"), 1, AIService.MaximumTimeoutS)
        }
    }

    HandleAIConnectionTestResult(ok, message, successfulAddress,
            requestId, *) {
        if this.Disposed || requestId != this.AIConnectionRequestId
            return false
        this.AIConnectionRequestId := 0
        this.AIConnectionTestBusy := false
        this.RefreshAIConnectionTestButton()
        if !ok {
            this.SetAIConnectionStatus(this.FormatAIConnectionFailure(message),
                "Error")
            return false
        }
        this.SetAIConnectionStatus(Tr("AI 连接测试成功。"), "Success")
        return true
    }

    FormatAIConnectionFailure(message) {
        return Tr("AI 连接测试失败：{1}",
            AIService.DescribeConnectionFailure(message))
    }

    SetAIConnectionStatus(message, colorName := "Error") {
        if this.Disposed || !this.HasOwnProp("AIConnectionStatus")
            return false
        this.AIConnectionStatusColorName := colorName
        this.AIConnectionStatus.SetFont("c"
            this.ResolveAIConnectionStatusColor(colorName),
            LocalizationService.GetUiFontName())
        this.AIConnectionStatus.Text := String(message)
        this.LayoutAIConnectionStatus(message)
        return true
    }

    LayoutAIConnectionStatus(message) {
        if !this.HasOwnProp("AIConnectionStatus")
                || !this.AIConnectionStatus
            return false
        this.AIConnectionStatus.GetPos(&statusX, , &statusWidth)
        statusWidth := Max(1, statusWidth)
        SetMultilineEditPadding(this.AIConnectionStatus.Hwnd, 1, 2, 1, 2)
        textHeight := message == "" ? 0
            : this.Interactions.Painter.MeasureTextHeight(
                this.AIConnectionStatus, message, Max(1, statusWidth - 2))
        if message != "" {
            wrappedLineCount := Max(1, SendMessage(0x00BA, 0, 0, ,
                this.AIConnectionStatus.Hwnd)) ; EM_GETLINECOUNT
            lineHeight := this.Interactions.Painter.MeasureTextHeight(
                this.AIConnectionStatus, "中Ag", Max(1, statusWidth - 2))
            textHeight := Max(textHeight, wrappedLineCount * lineHeight)
        }
        requiredHeight := message == "" ? 30 : Max(30, textHeight + 4)
        maximumHeight := SettingsWindow.AIConnectionStatusBottom
            - SettingsWindow.AIConnectionStatusTop
        statusHeight := Min(maximumHeight, requiredHeight)
        this.AIConnectionStatus.Move(statusX,
            SettingsWindow.AIConnectionStatusBottom - statusHeight,
            statusWidth, statusHeight)
        if statusHeight == 30 && message != "" {
            verticalPadding := Max(1,
                Floor((statusHeight - textHeight) / 2))
            SetMultilineEditPadding(this.AIConnectionStatus.Hwnd, 1,
                verticalPadding, 1, verticalPadding)
        } else
            SetMultilineEditPadding(this.AIConnectionStatus.Hwnd, 1, 2, 1, 2)
        return true
    }

    ResolveAIConnectionStatusColor(colorName) {
        colors := UiThemeService.GetPalette()
        return colors.HasOwnProp(colorName)
            ? colors.%colorName% : colors.Text
    }

    RefreshAIConnectionTestButton() {
        if !this.HasOwnProp("AITestConnectionButton")
                || !this.AITestConnectionButton
            return false
        colors := UiThemeService.GetPalette()
        this.Interactions.SetButtonAppearance(this.AITestConnectionButton,
            colors.Toolbar, colors.ToolbarText,
            !this.AIConnectionTestBusy)
        return true
    }

    SetValidationMessage(message, colorName := "Error") {
        this.ValidationStatusColorName := colorName
        this.ValidationStatus.SetFont("c" UiThemeService.Color(colorName),
            LocalizationService.GetUiFontName())
        this.ValidationStatus.Text := String(message)
        return true
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

    CreateTabButton(index, x, width, text, iconName, iconColor := "none") {
        button := this.Gui.Add("Text", "x" x " y12 w" width
            " h28 Center 0x200 Background" UiThemeService.Color("Tab")
                " c" UiThemeService.Color("TabText"), text)
        this.TabButtons.Push(button)
        this.TabButtonPages.Push(index)
        this.Interactions.RegisterButton(button, UiThemeService.Color("Tab"),
            ObjBindMethod(this, "SwitchTab", index), "", "", false,
            UiThemeService.Color("TabText"))
        this.Interactions.SetButtonLucideIcon(button, iconName, 14, 6,
            iconColor)
        return button
    }

    GetTabIconName(pageIndex) {
        switch pageIndex {
            case 1: return "monitor.svg"
            case 2: return "power.svg"
            case 3: return "pencil-sparkles.svg"
            case 4: return "file-output.svg"
        }
        return ""
    }

    GetTabIconColor(pageIndex, active := false) {
        if active && !UiThemeService.IsDark()
            return UiThemeService.Color("TabActiveText")
        switch pageIndex {
            case 1: return UiThemeService.Color("DisplayIcon")
            case 2: return UiThemeService.Color("StartupIcon")
            case 3: return UiThemeService.Color("AI")
            case 4: return UiThemeService.Color("RulesEventIcon")
        }
        return UiThemeService.Color("TabText")
    }

    ApplyTabButtonAppearance(buttonIndex, button, active) {
        pageIndex := this.TabButtonPages[buttonIndex]
        this.Interactions.SetButtonAppearance(button,
            UiThemeService.Color(active ? "TabActive" : "Tab"),
            UiThemeService.Color(active ? "TabActiveText" : "TabText"),
            true)
        iconName := this.GetTabIconName(pageIndex)
        if iconName != ""
            this.Interactions.SetButtonLucideIcon(button, iconName, 14, 6,
                this.GetTabIconColor(pageIndex, active))
        return true
    }

    AddTabControl(index, control) {
        this.TabControls[index].Push(control)
        if this.ActiveTab && index != this.ActiveTab
            try control.Visible := false
        return control
    }

    AddMenuLabel(index, y, text) {
        text := RegExReplace(RTrim(String(text)), "[:：]$")
        return this.AddSelectableMenuText(index, 0, y, text)
    }

    AddSelectableMenuText(index, x, y, text, width := 1, height := 20,
            alignment := "Left") {
        colors := UiThemeService.GetPalette()
        control := this.Gui.Add("Edit", "x" x " y" y " w" width
            " h" height " " alignment
            " ReadOnly -TabStop -Border -E0x200 -VScroll -HScroll"
            " Background" colors.Window " c" colors.Text, String(text))
        ApplyDarkControl(control.Hwnd)
        if !this.Interactions.RegisterTextInput(control, "", "arrow")
            throw Error("无法注册可选择菜单文字。")
        if width <= 1
            control.Move(, , this.MeasureControlTextWidth(control,
                control.Text) + 2)
        this.SelectableTextControls.Push(control)
        return index > 0 ? this.AddTabControl(index, control) : control
    }

    AddMenuIcon(index, y, iconName, iconColor) {
        colors := UiThemeService.GetPalette()
        icon := this.AddTabControl(index, this.Gui.Add("Text",
            "x0 y" y " w20 h20 Background" colors.Window, ""))
        if !this.Interactions.RegisterIconSurface(icon, colors.Window,
                iconColor)
            throw Error("无法注册设置菜单图标。")
        if !this.Interactions.SetControlLucideIcon(icon, iconName, 18, 0,
                iconColor)
            throw Error("无法加载设置菜单图标：" iconName)
        return icon
    }

    AlignMenuColumn(labels, itemWidths, clientWidth := 0) {
        if !IsObject(labels) || labels.Length == 0
            return false
        if clientWidth <= 0
            clientWidth := this.GetActualClientWidth()
        menuWidth := 1
        for label in labels
            menuWidth := Max(menuWidth,
                this.MeasureControlTextWidth(label, label.Text) + 2)
        if IsObject(itemWidths) {
            for itemWidth in itemWidths
                menuWidth := Max(menuWidth, itemWidth)
        }
        menuWidth := Min(menuWidth,
            clientWidth - this.Layout.ContentX * 2)
        menuX := Max(this.Layout.ContentX,
            Floor((clientWidth - menuWidth) / 2))
        for label in labels
            label.Move(menuX, , this.GetSelectableTextWidth(label), 20)
        return {X: menuX, Width: menuWidth}
    }

    GetSelectableTextWidth(control) {
        return Max(1, this.MeasureControlTextWidth(control, control.Text) + 2)
    }

    AddDropDown(x, y, width, labels, selectedIndex, rows := 0) {
        colors := UiThemeService.GetPalette()
        rowOptions := rows > 0 ? " r" rows : ""
        dropDown := this.Gui.Add("DropDownList", "x" x " y" y " w" width
            rowOptions " Choose" selectedIndex " Background" colors.Input
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

    MeasureRequiredIconButtonWidth(control, texts, minimumWidth,
            iconSizeDip := 0, gapDip := 0) {
        requiredWidth := minimumWidth
        for text in texts {
            textWidth := this.MeasureControlTextWidth(control, text)
            requiredWidth := Max(requiredWidth, textWidth + iconSizeDip
                + gapDip + 20)
        }
        return requiredWidth
    }

    MeasureControlTextWidth(control, text) {
        deviceContext := DllCall("user32\GetDC", "Ptr", control.Hwnd, "Ptr")
        if !deviceContext
            return StrLen(String(text)) * 12
        fontHandle := SendMessage(0x0031, 0, 0, , control.Hwnd) ; WM_GETFONT
        previousFont := fontHandle ? DllCall("gdi32\SelectObject", "Ptr",
            deviceContext, "Ptr", fontHandle, "Ptr") : 0
        extent := Buffer(8, 0)
        try {
            text := String(text)
            if !DllCall("gdi32\GetTextExtentPoint32W", "Ptr",
                    deviceContext, "Str", text, "Int", StrLen(text),
                    "Ptr", extent, "Int")
                return StrLen(text) * 12
            windowDpi := DllCall("user32\GetDpiForWindow", "Ptr",
                control.Hwnd, "UInt")
            if !windowDpi
                windowDpi := 96
            return Ceil(NumGet(extent, 0, "Int") * 96 / windowDpi)
        } finally {
            if previousFont
                DllCall("gdi32\SelectObject", "Ptr", deviceContext,
                    "Ptr", previousFont, "Ptr")
            DllCall("user32\ReleaseDC", "Ptr", control.Hwnd,
                "Ptr", deviceContext)
        }
    }

    EnsureTabBuilt(index) {
        if index < 1 || index > this.TabBuilt.Length
            return false
        if this.TabBuilt[index]
            return true
        switch index {
            case 1: this.BuildAppearanceTab()
            case 2: this.BuildStartupTab()
            case 3: this.BuildAITab()
            case 4: this.BuildRulesAndEventTab()
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
                for control in controls {
                    controlVisible := visible
                    if this.HasOwnProp("ShortcutFeedback")
                            && control == this.ShortcutFeedback
                        controlVisible := visible
                            && !!this.ShortcutFeedbackTimer
                    else if this.HasOwnProp("ShortcutButton")
                            && control == this.ShortcutButton
                        controlVisible := visible
                            && !this.ShortcutFeedbackTimer
                    try control.Visible := controlVisible
                }
            }
            for buttonIndex, button in this.TabButtons {
                active := this.TabButtonPages[buttonIndex] == index
                this.ApplyTabButtonAppearance(buttonIndex, button, active)
            }
            this.ActiveTab := index
            if index == 1
                this.AlignAppearanceTabControls()
            else if index == 3
                this.AlignAITabControls()
            else if index == 4
                this.AlignEventTabControls()
            if index == 2
                this.RefreshStartupTaskStatus()
            showActions := true
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
        this.AlignAppearanceTabControls()
        this.AlignAITabControls()
        this.AlignEventTabControls()
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
        for controlName in ["EscapeCancelCheck", "EventAutoScrollCheck"] {
            if this.HasOwnProp(controlName) && this.%controlName%
                ApplyDarkControl(this.%controlName%.Hwnd)
        }
        for controlName in ["RunAsAdministratorCheck",
                "CheckUpdatesOnStartupCheck", "ShowAtStartupCheck"] {
            if this.HasOwnProp(controlName) && this.%controlName%
                ApplyDarkControl(this.%controlName%.Hwnd)
        }
        for inputName in ["EventCapacityInput", "AIAddressInput",
                "AIKeyInput", "AIModelInput", "AITimeoutInput"] {
            if this.HasOwnProp(inputName) && IsObject(this.%inputName%)
                ApplyDarkControl(this.%inputName%.Edit.Hwnd)
        }
        if this.HasOwnProp("AIConnectionStatus") && this.AIConnectionStatus
            ApplyDarkControl(this.AIConnectionStatus.Hwnd)
        return true
    }

    ApplyAppearance() {
        if this.Disposed
            return false
        BeginStableWindowUpdate(this.Gui.Hwnd)
        try {
            colors := UiThemeService.GetPalette()
            fontName := LocalizationService.GetUiFontName()
            systemFont := LocalizationService.GetLanguageSystemUiFontName()
            this.Gui.Title := Tr("键鼠重映射小助手设置")
            this.Gui.BackColor := colors.Window
            this.Gui.SetFont("norm s10 c" colors.Text, fontName)
            this.Interactions.SetParentColor(colors.Window)

            for controlHwnd, control in this.Gui {
                try control.GetPos(, , &controlWidth, &controlHeight)
                catch
                    continue
                if controlWidth == 1 || controlHeight == 1
                    try control.Opt("Background" colors.Divider)
            }

            textControls := ["ShortcutLabel", "StartupTaskLabel",
                "ShortcutFeedback", "LanguageLabel", "FontLabel",
                "ThemeLabel", "EventCapacityLabel", "EscapeCancelCheck",
                "EventAutoScrollCheck", "CheckUpdatesOnStartupCheck",
                "RunAsAdministratorCheck", "ShowAtStartupCheck",
                "AIAddressLabel", "AIKeyLabel",
                "AIModelLabel", "AITimeoutLabel", "AIPromptsLabel"]
            for controlName in textControls {
                if this.HasOwnProp(controlName) && this.%controlName%
                    this.%controlName%.SetFont("c" colors.Text, fontName)
            }
            for control in this.SelectableTextControls {
                control.Opt("Background" colors.Window " c" colors.Text)
                ApplyDarkControl(control.Hwnd)
            }
            for spec in [
                    {Name: "LanguageIcon",
                        Icon: "languages.svg", Color: colors.LanguageIcon},
                    {Name: "FontIcon", Icon: "type.svg",
                        Color: colors.FontIcon},
                    {Name: "ThemeIcon", Icon: "palette.svg",
                        Color: colors.ThemeIcon}] {
                if this.HasOwnProp(spec.Name) && this.%spec.Name% {
                    this.Interactions.SetIconSurfaceAppearance(
                        this.%spec.Name%, colors.Window, spec.Color)
                    this.Interactions.SetControlLucideIcon(
                        this.%spec.Name%, spec.Icon, 18, 0, spec.Color)
                }
            }
            this.ValidationStatus.SetFont("c"
                UiThemeService.Color(this.ValidationStatusColorName),
                fontName)
            if this.HasOwnProp("AIConnectionStatus")
                    && this.AIConnectionStatus {
                this.AIConnectionStatus.Opt("Background" colors.Window)
                this.AIConnectionStatus.SetFont("c"
                    this.ResolveAIConnectionStatusColor(
                        this.AIConnectionStatusColorName), fontName)
                ApplyDarkControl(this.AIConnectionStatus.Hwnd)
            }
            if this.HasOwnProp("AIConnectionStatus")
                    && this.AIConnectionStatus
                this.LayoutAIConnectionStatus(this.AIConnectionStatus.Text)

            for dropDownName in ["LanguageDropDown", "FontDropDown",
                    "ThemeDropDown"] {
                if this.HasOwnProp(dropDownName) && this.%dropDownName%
                    this.%dropDownName%.Opt("Background" colors.Input
                        " c" colors.Text)
            }
            if this.TabBuilt[4] && IsObject(this.EventCapacityInput) {
                this.EventCapacityInput.Background.Opt(
                    "Background" colors.Input)
                this.EventCapacityInput.Edit.Opt("Background" colors.Input
                    " c" colors.Text)
            }
            for inputName in ["AIAddressInput", "AIKeyInput", "AIModelInput",
                    "AITimeoutInput"] {
                if this.HasOwnProp(inputName) && IsObject(this.%inputName%) {
                    this.%inputName%.Background.Opt("Background" colors.Input)
                    this.%inputName%.Edit.Opt("Background" colors.Input
                        " c" colors.Text)
                }
            }

            for buttonIndex, button in this.TabButtons {
                active := this.TabButtonPages[buttonIndex] == this.ActiveTab
                this.ApplyTabButtonAppearance(buttonIndex, button, active)
                button.SetFont("bold", systemFont)
            }
            buttonSpecs := [
                {Name: "ShortcutButton", Color: colors.Toolbar,
                    TextColor: colors.ToolbarText, Interactive: true},
                {Name: "StartupTaskButton", Color: colors.Toolbar,
                    TextColor: colors.ToolbarText,
                    Interactive: this.StartupTaskButtonReady},
                {Name: "ImportRulePackageButton", Color: colors.Primary,
                    TextColor: colors.ButtonText, Interactive: true},
                {Name: "ExportRulePackageButton", Color: colors.Toolbar,
                    TextColor: colors.ToolbarText, Interactive: true},
                {Name: "AIPromptsButton", Color: colors.Toolbar,
                    TextColor: colors.ToolbarText, Interactive: true},
                {Name: "AITestConnectionButton", Color: colors.Toolbar,
                    TextColor: colors.ToolbarText,
                    Interactive: !this.AIConnectionTestBusy},
                {Name: "SaveButton", Color: colors.Save,
                    TextColor: colors.ButtonText, Interactive: true},
                {Name: "CancelButton", Color: colors.Toolbar,
                    TextColor: colors.ToolbarText, Interactive: true}
            ]
            for spec in buttonSpecs {
                if !this.HasOwnProp(spec.Name) || !this.%spec.Name%
                    continue
                button := this.%spec.Name%
                if spec.Name == "AIPromptsButton"
                    this.Interactions.SetTextNoErase(button, Tr("编辑"))
                else if spec.Name == "AITestConnectionButton"
                    this.Interactions.SetTextNoErase(button, Tr("测试连接"))
                this.Interactions.SetButtonAppearance(button, spec.Color,
                    spec.TextColor, spec.Interactive)
                button.SetFont("s10 bold", systemFont)
            }
            if this.HasOwnProp("ImportRulePackageButton")
                    && this.ImportRulePackageButton
                this.Interactions.SetButtonLucideIcon(
                    this.ImportRulePackageButton, "square-plus.svg", 15, 6,
                    UiThemeService.ButtonIconColor(colors.ButtonText))
            if this.HasOwnProp("ExportRulePackageButton")
                    && this.ExportRulePackageButton
                this.Interactions.SetButtonLucideIcon(
                    this.ExportRulePackageButton, "file-output.svg", 15, 6,
                    colors.RulesEventIcon)
            this.AlignAppearanceTabControls()
            this.AlignAITabControls()
            this.AlignEventTabControls()
            this.ApplyNativeThemes()
            this.Gui.BackColor := colors.Window
        } finally EndStableWindowUpdate(this.Gui.Hwnd, true)
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
        ; 只处理字体控件的展开和关闭通知，避免其它下拉框触发字体枚举。
        if this.Disposed || !this.FontDropDownCommandRegistered
            || !this.FontDropDown || lParam != this.FontDropDown.Hwnd
            return
        notificationCode := (wParam >> 16) & 0xFFFF
        if notificationCode == Win32.CBN_CLOSEUP {
            this.CaptureFontDropDownTopIndex()
            return
        }
        if notificationCode != Win32.CBN_DROPDOWN
            return
        this.RefreshFontDropDown()
        this.RestoreFontDropDownTopIndex()
    }

    CaptureFontDropDownTopIndex() {
        if !this.FontDropDown
            return this.FontDropDownTopIndex
        topIndex := SendMessage(Win32.CB_GETTOPINDEX, 0, 0,
            this.FontDropDown.Hwnd)
        if topIndex >= 0
            this.FontDropDownTopIndex := topIndex
        return this.FontDropDownTopIndex
    }

    RestoreFontDropDownTopIndex() {
        if !this.FontDropDown || !this.FontValues.Length
            return false
        topIndex := Max(0, Min(this.FontDropDownTopIndex,
            this.FontValues.Length - 1))
        SendMessage(Win32.CB_SETTOPINDEX, topIndex, 0,
            this.FontDropDown.Hwnd)
        return true
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
        uiLanguage := this.Original.UiLanguage
        uiFont := this.Original.UiFont
        theme := this.Original.Theme
        showAtStartup := this.Original.ShowAtStartup
        runAsAdministrator := this.Original.RunAsAdministrator
        checkUpdatesOnStartup := this.Original.CheckUpdatesOnStartup
        if this.TabBuilt[1] {
            uiLanguage := this.LanguageValues[this.LanguageDropDown.Value]
            uiFont := this.FontValues[this.FontDropDown.Value]
            theme := this.ThemeValues[this.ThemeDropDown.Value]
        }
        if this.TabBuilt[2] {
            showAtStartup := this.ShowAtStartupCheck.Value != 0
            runAsAdministrator := this.RunAsAdministratorCheck.Value != 0
            checkUpdatesOnStartup :=
                this.CheckUpdatesOnStartupCheck.Value != 0
        }
        eventCapacity := this.Original.EventBufferCapacity
        if this.TabBuilt[4]
            eventCapacity := this.ParseRangedInteger(
                this.EventCapacityInput.Edit.Value, Tr("事件缓冲区容量"),
                AppSettingsService.MinimumEventBufferCapacity,
                AppSettingsService.MaximumEventBufferCapacity)
        aiAddress := this.Original.AIAddress
        aiKey := this.Original.AIKey
        aiModel := this.Original.AIModel
        aiTimeout := this.Original.AITimeoutS
        if this.TabBuilt[3] {
            aiAddress := this.AIAddressInput.Edit.Value
            aiKey := this.AIKeyInput.Edit.Value
            aiModel := this.AIModelInput.Edit.Value
            aiTimeout := this.ParseRangedInteger(this.AITimeoutInput.Edit.Value,
                Tr("请求超时（秒）"), 1, AIService.MaximumTimeoutS)
        }
        return {
            UiLanguage: uiLanguage, UiFont: uiFont, Theme: theme,
            ShowAtStartup: showAtStartup,
            RunAsAdministrator: runAsAdministrator,
            CheckUpdatesOnStartup: checkUpdatesOnStartup,
            EscapeCancelsRecording: this.TabBuilt[4]
                ? this.EscapeCancelCheck.Value != 0
                : this.Original.EscapeCancelsRecording,
            EventBufferCapacity: eventCapacity,
            EventViewerAutoScroll: this.TabBuilt[4]
                ? this.EventAutoScrollCheck.Value != 0
                : this.Original.EventViewerAutoScroll,
            AIAddress: aiAddress, AIKey: aiKey, AIModel: aiModel,
            AITimeoutS: aiTimeout, AIPrompt: this.AIPromptDraft,
            AIOptimizePrompt: this.AIOptimizePromptDraft,
            AISystemPrompt: this.AISystemPromptDraft
        }
    }

    Save(*) {
        if this.Disposed
            return false
        this.SetValidationMessage("", "Error")
        try candidate := this.GetCandidate()
        catch as validationError {
            this.SetValidationMessage(validationError.Message, "Error")
            return false
        }
        if this.OwnerWindow.App.SaveSettings(candidate) {
            this.Dispose()
            return true
        }
        try this.SetValidationMessage(this.OwnerWindow.Status.Text, "Error")
        return false
    }

    CreateShortcuts(*) {
        if this.Disposed
            return false
        result := this.App.CreateApplicationShortcuts(this.Gui)
        if !result
            return false
        this.ShortcutButton.Visible := false
        this.ShortcutFeedback.Visible := this.ActiveTab == 2
        this.ShortcutFeedbackGeneration++
        generation := this.ShortcutFeedbackGeneration
        if this.ShortcutFeedbackTimer
            try SetTimer(this.ShortcutFeedbackTimer, 0)
        this.ShortcutFeedbackTimer := ObjBindMethod(this,
            "RestoreShortcutButton", generation)
        SetTimer(this.ShortcutFeedbackTimer, -3000)
        return true
    }

    RestoreShortcutButton(generation, *) {
        if this.Disposed || generation != this.ShortcutFeedbackGeneration
            return
        this.ShortcutFeedbackTimer := 0
        this.ShortcutFeedback.Visible := false
        this.ShortcutButton.Visible := this.ActiveTab == 2
    }

    ToggleStartupTask(*) {
        if this.Disposed
            return false
        result := this.App.ToggleStartupTask(this.Gui,
            this.RunAsAdministratorCheck.Value != 0)
        if !result
            return false
        this.RefreshStartupTaskStatus()
        return true
    }

    RefreshStartupTaskStatus() {
        if this.Disposed || !this.TabBuilt[2]
            return false
        state := this.App.GetStartupTaskState(
            this.RunAsAdministratorCheck.Value != 0)
        if !IsObject(state) || state.Status == "error" {
            this.StartupTaskButtonReady := false
            this.Interactions.SetTextNoErase(this.StartupTaskButton,
                Tr("不可用"))
            this.Interactions.SetButtonLucideIcon(this.StartupTaskButton,
                "triangle-alert.svg", 14, 6,
                UiThemeService.ButtonIconColor(
                    UiThemeService.Color("Warning")))
            this.Interactions.SetButtonAppearance(this.StartupTaskButton,
                UiThemeService.Color("Toolbar"),
                UiThemeService.Color("ToolbarText"), false)
            this.StartupTaskButton.Visible := this.ActiveTab == 2
            return false
        }
        if state.Status == "missing" {
            buttonText := Tr("开启")
            iconName := "play.svg"
        } else if state.Status == "owned" {
            buttonText := Tr("关闭")
            iconName := "power.svg"
        } else if state.Status == "switch" {
            buttonText := Tr("切换")
            iconName := "repeat-2.svg"
        } else {
            buttonText := Tr("冲突")
            iconName := "triangle-alert.svg"
        }
        this.Interactions.SetTextNoErase(this.StartupTaskButton, buttonText)
        lightIconColor := state.Status == "missing"
            ? UiThemeService.Color("StatusEnabledIcon")
            : (state.Status == "owned" ? UiThemeService.Color("Danger")
                : (state.Status == "switch"
                    ? UiThemeService.Color("RulesEventIcon")
                    : UiThemeService.Color("Warning")))
        this.Interactions.SetButtonLucideIcon(this.StartupTaskButton,
            iconName, 14, 6,
            UiThemeService.ButtonIconColor(lightIconColor))
        this.StartupTaskButtonReady := true
        this.Interactions.SetButtonAppearance(this.StartupTaskButton,
            UiThemeService.Color("Toolbar"),
            UiThemeService.Color("ToolbarText"), true)
        ; Updating text/icon can cause a hidden owner-drawn control to repaint.
        ; Reassert page visibility after the startup-task refresh.
        this.StartupTaskButton.Visible := this.ActiveTab == 2
        return true
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
        if this.ShortcutFeedbackTimer {
            cleanup.Run("停止快捷方式反馈计时器",
                () => SetTimer(this.ShortcutFeedbackTimer, 0))
            this.ShortcutFeedbackTimer := 0
        }
        if this.AIConnectionRequestId && IsObject(this.App.AIService) {
            requestId := this.AIConnectionRequestId
            this.AIConnectionRequestId := 0
            cleanup.Run("取消 AI 连接测试",
                () => this.App.AIService.Cancel(requestId))
        }
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
        this.SelectableTextControls := []
        this.ShortcutLabel := ""
        this.ShortcutButton := ""
        this.ShortcutFeedback := ""
        this.StartupTaskLabel := ""
        this.StartupTaskButton := ""
        this.RunAsAdministratorCheck := ""
        this.CheckUpdatesOnStartupCheck := ""
        this.ShowAtStartupCheck := ""
        this.EscapeCancelCheck := ""
        this.LanguageIcon := ""
        this.FontIcon := ""
        this.ThemeIcon := ""
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

class AIPromptsEditor {
    static WindowWidth := 620
    static WindowHeight := 440

    __New(ownerWindow, generatePrompt, optimizePrompt, systemPrompt) {
        this.OwnerWindow := ownerWindow
        this.GeneratePrompt := String(generatePrompt)
        this.OptimizePrompt := String(optimizePrompt)
        this.SystemPrompt := String(systemPrompt)
        this.ActivePromptTab := 0
        this.PromptTabButtons := []
        this.Accepted := false
        this.Disposed := false
        this.OwnerLease := ""
        this.IconHandles := []
        this.Gui := ""
        this.Interactions := ""
        try this.Build()
        catch as buildError {
            try this.Dispose(false)
            throw buildError
        }
    }

    Build() {
        colors := UiThemeService.GetPalette()
        this.Gui := Gui("+Owner" this.OwnerWindow.Gui.Hwnd
            " +OwnDialogs -MinimizeBox -MaximizeBox", Tr("AI 提示词"))
        this.IconHandles := ApplyApplicationWindowIcon(this.Gui.Hwnd)
        this.OwnerLease := WindowHierarchy.Acquire(this.OwnerWindow.Gui,
            this.Gui.Hwnd)
        if !this.OwnerLease
            throw Error("无法建立 AI 提示词窗口层级。")
        this.Gui.BackColor := colors.Window
        this.Gui.MarginX := 0
        this.Gui.MarginY := 0
        this.Gui.SetFont("s11 c" colors.Text,
            LocalizationService.GetUiFontName())
        this.Interactions := MappingUiInteractions(this.Gui, colors.Window,
            this.OwnerWindow.App.SvgRenderer)

        tabLabels := [Tr("生成"), Tr("优化"), Tr("系统说明")]
        tabWidth := 160
        tabGap := 8
        tabGroupWidth := tabWidth * tabLabels.Length
            + tabGap * (tabLabels.Length - 1)
        tabX := Floor((AIPromptsEditor.WindowWidth - tabGroupWidth) / 2)
        tabColor := UiThemeService.Color("Tab")
        tabTextColor := UiThemeService.Color("TabText")
        for index, label in tabLabels {
            tabButton := this.Gui.Add("Text", "x" tabX " y14 w" tabWidth
                " h30 Center 0x200 Background" tabColor " c"
                    tabTextColor, label)
            tabButton.SetFont("s10 bold",
                LocalizationService.GetLanguageSystemUiFontName())
            if !this.Interactions.RegisterButton(tabButton, tabColor,
                    ObjBindMethod(this, "SwitchPromptTab", index), "", "",
                    false, tabTextColor)
                throw Error("无法注册 AI 提示词标签交互。")
            this.PromptTabButtons.Push(tabButton)
            tabX += tabWidth + tabGap
        }
        this.GenerateEdit := this.Gui.Add("Edit",
            "x16 y56 w588 h316 Multi WantTab Wrap VScroll -HScroll"
                . " -TabStop"
                . " -Border -E0x200 Background"
                . colors.Input " c" colors.Text,
            this.GeneratePrompt)
        this.OptimizeEdit := this.Gui.Add("Edit",
            "x16 y56 w588 h316 Multi WantTab Wrap VScroll -HScroll"
                . " -TabStop -Border -E0x200 Background"
                . colors.Input " c" colors.Text,
            this.OptimizePrompt)
        this.SystemEdit := this.Gui.Add("Edit",
            "x16 y56 w588 h316 Multi WantTab Wrap VScroll -HScroll"
                . " -TabStop -Border -E0x200 Background"
                . colors.Input " c" colors.Text,
            this.SystemPrompt)
        for editControl in [this.GenerateEdit, this.OptimizeEdit,
                this.SystemEdit] {
            SetEditMargins(editControl.Hwnd, 10, 10)
            SendMessage(0x00C5, 0, 0, ,
                editControl.Hwnd) ; EM_SETLIMITTEXT: native maximum
            SendMessage(Win32.EM_SETSEL, 0, 0, , editControl.Hwnd)
            ApplyDarkControl(editControl.Hwnd)
            if !this.Interactions.RegisterTextInput(editControl)
                throw Error("无法注册 AI 提示词输入区交互。")
        }

        this.Status := this.Gui.Add("Text",
            "x132 y395 w288 h24 BackgroundTrans c" colors.Error, "")
        this.ResetButton := this.AddButton(16, 388, 104, Tr("恢复默认"),
            colors.Toolbar, colors.ToolbarText,
            ObjBindMethod(this, "ResetToDefault"))
        this.SaveButton := this.AddButton(432, 388, 80, Tr("保存"),
            colors.Save, colors.ButtonText, ObjBindMethod(this, "Save"))
        this.CancelButton := this.AddButton(524, 388, 80, Tr("取消"),
            colors.Toolbar, colors.ToolbarText,
            ObjBindMethod(this, "Cancel"))
        this.Interactions.SetButtonLucideIcon(this.ResetButton,
            "repeat-2.svg", 14, 6,
            UiThemeService.ButtonIconColor(colors.DisplayIcon))
        this.Gui.OnEvent("Close", ObjBindMethod(this, "Cancel"))
        this.Gui.OnEvent("Escape", ObjBindMethod(this, "Cancel"))
        this.SwitchPromptTab(1)
    }

    AddButton(x, y, width, text, color, textColor, callback) {
        button := this.Gui.Add("Text", "x" x " y" y " w" width
            " h32 Center 0x200 Background" color " c" textColor, text)
        button.SetFont("s10 bold",
            LocalizationService.GetLanguageSystemUiFontName())
        if !this.Interactions.RegisterButton(button, color, callback,
                "", "", false, textColor)
            button.OnEvent("Click", callback)
        return button
    }

    Show() {
        if this.Disposed
            return {Accepted: false, GeneratePrompt: this.GeneratePrompt,
                OptimizePrompt: this.OptimizePrompt,
                SystemPrompt: this.SystemPrompt}
        hwnd := this.Gui.Hwnd
        shown := ShowPreparedWindow(this.Gui, "Center w" AIPromptsEditor.WindowWidth
            " h" AIPromptsEditor.WindowHeight,
            ObjBindMethod(this, "ApplyNativeThemes"))
        if shown
            this.ReleaseEditorFocus()
        WinWaitClose("ahk_id " hwnd)
        return {Accepted: this.Accepted, GeneratePrompt: this.GeneratePrompt,
            OptimizePrompt: this.OptimizePrompt,
            SystemPrompt: this.SystemPrompt}
    }

    ApplyNativeThemes(*) {
        ApplyDarkWindow(this.Gui.Hwnd)
        ApplyDarkControl(this.GenerateEdit.Hwnd)
        ApplyDarkControl(this.OptimizeEdit.Hwnd)
        ApplyDarkControl(this.SystemEdit.Hwnd)
        return true
    }

    ReleaseEditorFocus() {
        DllCall("user32\SetFocus", "Ptr",
            this.PromptTabButtons[this.ActivePromptTab].Hwnd, "Ptr")
        return true
    }

    SwitchPromptTab(index, *) {
        if this.Disposed || index < 1 || index > 3
            return false
        hwnd := this.Gui.Hwnd
        stabilize := DllCall("user32\IsWindowVisible", "Ptr", hwnd, "Int")
        if stabilize
            BeginStableWindowUpdate(hwnd)
        try {
            this.GenerateEdit.Visible := index == 1
            this.OptimizeEdit.Visible := index == 2
            this.SystemEdit.Visible := index == 3
            for buttonIndex, button in this.PromptTabButtons {
                active := buttonIndex == index
                this.Interactions.SetButtonAppearance(button,
                    UiThemeService.Color(active ? "TabActive" : "Tab"),
                    UiThemeService.Color(active
                        ? "TabActiveText" : "TabText"), true)
            }
            this.ActivePromptTab := index
            this.Status.Text := ""
        } finally {
            if stabilize
                EndStableWindowUpdate(hwnd)
        }
        return true
    }

    ResetToDefault(*) {
        if this.Disposed
            return false
        switch this.ActivePromptTab {
            case 1: this.GenerateEdit.Value := AIService.DefaultGeneratePrompt
            case 2: this.OptimizeEdit.Value := AIService.DefaultOptimizePrompt
            case 3: this.SystemEdit.Value := AIService.DefaultSystemPrompt
        }
        this.Status.Text := ""
        return true
    }

    Save(*) {
        if this.Disposed
            return false
        generatePrompt := Trim(this.GenerateEdit.Value)
        optimizePrompt := Trim(this.OptimizeEdit.Value)
        systemPrompt := Trim(this.SystemEdit.Value)
        if generatePrompt == "" {
            this.SwitchPromptTab(1)
            this.Status.Text := Tr("生成提示词不能为空。")
            return false
        }
        if optimizePrompt == "" {
            this.SwitchPromptTab(2)
            this.Status.Text := Tr("优化提示词不能为空。")
            return false
        }
        if systemPrompt == "" {
            this.SwitchPromptTab(3)
            this.Status.Text := Tr("系统说明不能为空。")
            return false
        }
        this.GeneratePrompt := generatePrompt
        this.OptimizePrompt := optimizePrompt
        this.SystemPrompt := systemPrompt
        this.Accepted := true
        this.Dispose()
        return true
    }

    Cancel(*) {
        this.Accepted := false
        this.Dispose()
        return true
    }

    Dispose(activateOwner := true) {
        if this.Disposed
            return
        this.Disposed := true
        cleanup := CleanupCollector("AI 提示词窗口")
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
        if activateOwner
            cleanup.Run("恢复父窗口", () =>
                WindowHierarchy.CompleteClose(closeContext))
        cleanup.Complete()
        return true
    }
}
