class MappingBlockEditor {
    static EditorWidth := 780
    static EditorHeight := 560
    static EditorMinimumWidth := 640
    static EditorMinimumHeight := 440
    static GutterSeparatorWidth := 1
    static MaximumLineNumberCharacters := 32 * 1024 * 1024
    static DetailedFormattingVisibleLines := 48
    static DetailedFormattingMaximumCharacters := 32 * 1024
    static AIButtonWidth := 144
    static AIButtonGap := 8
    static AIMaximumRepairAttempts := 2
    static AIMaximumSemanticReviewAttempts := 1
    static ModeButtonMinimumWidth := 104
    static ModeButtonMaximumWidth := 184
    static ModeButtonHorizontalPadding := 28
    static ModeButtonGap := 8
    static ModeSelectorRightMargin := 18
    static ModeSelectorBottomGap := 14
    static TitleTop := 14
    static TitleMinimumHeight := 24
    static TitleBottomGap := 16
    static CodeEditorTop := 54
    static EditorLineSpacingTwips := 340

    __New(ownerWindow, mapping, isNew := false, confirmCallback := "",
            purposePromptCallback := "", aiReviewCallback := "") {
        this.OwnerWindow := ownerWindow
        this.App := ownerWindow.App
        if confirmCallback != "" && !IsObject(confirmCallback)
            throw TypeError("编辑器确认回调无效。")
        if purposePromptCallback != "" && !IsObject(purposePromptCallback)
            throw TypeError("AI 规则目的输入回调无效。")
        if aiReviewCallback != "" && !IsObject(aiReviewCallback)
            throw TypeError("AI 结果审阅回调无效。")
        this.ConfirmCallback := IsObject(confirmCallback)
            ? confirmCallback : ShowDarkConfirmBox.Bind()
        this.PurposePromptCallback := IsObject(purposePromptCallback)
            ? purposePromptCallback : ShowDarkTextInputBox.Bind()
        this.AiReviewCallback := IsObject(aiReviewCallback)
            ? aiReviewCallback : ShowDarkTextComparisonDialog.Bind()
        this.IsNew := isNew
        this.EditorMode := mapping.HasOwnProp("Mode")
            ? StrLower(String(mapping.Mode)) : "managed"
        this.MappingId := isNew ? "" : mapping.Id
        initialText := mapping.HasOwnProp("EditorText")
            ? mapping.EditorText : mapping.Block
        this.OriginalText := this.Canonicalize(initialText)
        this.StartLine := this.ResolveStartLine(mapping)
        this.Disposed := false
        this.Formatting := false
        this.SuppressEditorChange := false
        this.StatusIsError := false
        this.Gui := ""
        this.Interactions := ""
        this.OwnerLease := ""
        this.FormatTimer := ""
        this.ScrollTimer := ""
        this.CodeFontName := this.ResolveCodeFontName()
        ; RichEdit/GDI 可按字体链接解析 SimSun，即使枚举器在非中文系统区域
        ; 没有列出该家族；这里保持用户要求的中英文分治。
        this.CjkFontName := "SimSun"
        this.CommandCallback := ""
        this.AISettingsLinkMouseCallback := ""
        this.AISettingsLinkHovered := false
        this.AISettingsLinkPreferredWidth := 1
        this.KeyDownCallback := ""
        this.ImeCompositionCallback := ""
        this.ImeComposing := false
        this.NativeDestroyCallback := ""
        this.CodeEditHwnd := 0
        this.LineNumberEditHwnd := 0
        this.LineNumberCount := 0
        this.EditorRevision := 0
        this.CachedCanonicalText := this.OriginalText
        this.CachedTextRevision := 0
        this.EditorTextReadCount := 0
        this.SyntaxLexer := AhkV2Lexer(this.OriginalText)
        this.RichTextColorFormats := Map()
        this.LastFormattedRevision := -1
        this.LastFormattedStart := 0
        this.LastFormattedEnd := 0
        this.PendingFormatStart := -1
        this.PendingFormatEnd := -1
        this.FormattingPassCount := 0
        this.GutterWidth := this.CalculateGutterWidth(
            this.GetLineCount(this.OriginalText))
        this.NativeDestroying := false
        this.NativeCloseContext := ""
        this.NativeCleanup := ""
        this.NativeCallbacksReleased := true
        this.NativeFinalizeTimer := ObjBindMethod(this, "FinishNativeDestroy")
        this.EditorHwnd := 0
        this.LastLayoutResult := ""
        this.LastChangedLayoutResult := ""
        this.LastLayoutSignature := ""
        this.ManagedModeButton := ""
        this.ScriptModeButton := ""
        this.ModeButtonWidth := MappingBlockEditor.ModeButtonMinimumWidth
        this.AiButton := ""
        this.AISettingsLink := ""
        this.AiRequestId := 0
        this.AiRequestRevision := 0
        this.AiBusy := false
        this.AiRequestPurpose := ""
        this.AiPurposeRetryText := ""
        this.AiRequestEditorText := ""
        this.AiRequiredResponseMode := ""
        this.AiFormatFallbackAttempted := false
        this.AiPipelinePhase := "draft"
        this.AiCandidateText := ""
        this.AiRepairAttempts := 0
        this.AiReviewAttempts := 0
        this.RichEditModule := DllCall("kernel32\LoadLibraryExW",
            "WStr", "Msftedit.dll", "Ptr", 0, "UInt", 0x00000800, "Ptr")
        if !this.RichEditModule
            throw Error("无法加载代码编辑控件。")
        try {
            windowTitle := isNew ? Tr("新增映射代码") : Tr("编辑映射代码")
            minimumSize := " +MinSize"
                . MappingBlockEditor.EditorMinimumWidth "x"
                . MappingBlockEditor.EditorMinimumHeight
            this.Gui := Gui("+Owner" ownerWindow.Gui.Hwnd
                " +Resize +MinimizeBox" minimumSize " +OwnDialogs",
                windowTitle)
            this.EditorHwnd := this.Gui.Hwnd
            this.IconHandles := ApplyApplicationWindowIcon(this.EditorHwnd)
            this.OwnerLease := WindowHierarchy.Acquire(ownerWindow.Gui,
                this.Gui.Hwnd)
            if !this.OwnerLease
                throw Error("无法建立代码编辑器的窗口层级。")
            this.Gui.BackColor := MappingWindow.Colors.Window
            this.Gui.MarginX := 0
            this.Gui.MarginY := 0
            this.Gui.SetFont("s10 c" MappingWindow.Colors.Text,
                LocalizationService.GetUiFontName())
            this.Interactions := MappingUiInteractions(this.Gui,
                MappingWindow.Colors.Window, ownerWindow.App.SvgRenderer)
            this.FormatTimer := ObjBindMethod(this,
                "RefreshEditorPresentation")
            this.ScrollTimer := ObjBindMethod(this,
                "RefreshEditorViewport")
            this.CommandCallback := ObjBindMethod(this, "OnCommand")
            this.BuildControls(mapping)
            this.AISettingsLinkMouseCallback := ObjBindMethod(this,
                "OnAISettingsLinkMouse")
            this.KeyDownCallback := ObjBindMethod(this, "OnKeyDown")
            this.ImeCompositionCallback := ObjBindMethod(this,
                "OnImeComposition")
            this.NativeDestroyCallback := ObjBindMethod(this, "OnNativeDestroy")
            OnMessage(0x0100, this.KeyDownCallback)
            OnMessage(0x010D, this.ImeCompositionCallback)
            OnMessage(0x010E, this.ImeCompositionCallback)
            OnMessage(0x0111, this.CommandCallback)
            OnMessage(Win32.WM_MOUSEMOVE,
                this.AISettingsLinkMouseCallback)
            OnMessage(Win32.WM_MOUSELEAVE,
                this.AISettingsLinkMouseCallback)
            OnMessage(0x0002, this.NativeDestroyCallback)
            OnMessage(0x0082, this.NativeDestroyCallback)
            this.Gui.OnEvent("Size", ObjBindMethod(this, "OnResize"))
            this.Gui.OnEvent("Close", ObjBindMethod(this, "RequestClose"))
            this.Gui.OnEvent("Escape", ObjBindMethod(this, "RequestClose"))
        } catch as createError {
            try this.Dispose(false)
            throw createError
        }
    }

    BuildControls(mapping) {
        colors := MappingWindow.Colors
        titleText := this.IsNew ? Tr("新增映射代码")
            : String(mapping.Id)
        this.Title := this.Gui.Add("Text",
            "x14 y" MappingBlockEditor.TitleTop
                " w752 h" MappingBlockEditor.TitleMinimumHeight
                " Wrap BackgroundTrans c" colors.Text,
            titleText)
        this.Title.SetFont("s11 bold",
            LocalizationService.GetLanguageSystemUiFontName())
        titleHeight := this.GetTitleHeight(752)
        this.Title.Move(, , , titleHeight)
        codeEditorTop := this.GetCodeEditorTop(752)
        initialCodeEditorHeight := 448 - codeEditorTop
        this.LineNumberEdit := this.Gui.Add("Custom",
            "ClassRICHEDIT50W x14 y" codeEditorTop " w" this.GutterWidth
                " h" initialCodeEditorHeight
                " +0x00000886 -E0x200 -TabStop")
        this.LineNumberEditHwnd := this.LineNumberEdit.Hwnd
        SendMessage(0x0435, 0,
            MappingBlockEditor.MaximumLineNumberCharacters, ,
            this.LineNumberEditHwnd)
        SendMessage(0x00CF, 1, 0, , this.LineNumberEdit.Hwnd)
        this.LineNumberDivider := this.Gui.Add("Text",
            "x" (14 + this.GutterWidth) " y" codeEditorTop
                " w1 h" initialCodeEditorHeight " Background" colors.Divider)
        codeX := 14 + this.GutterWidth
            + MappingBlockEditor.GutterSeparatorWidth
        initialCodeWidth := 752 - this.GutterWidth
            - MappingBlockEditor.GutterSeparatorWidth
        this.CodeEdit := this.Gui.Add("Custom",
            "ClassRICHEDIT50W x" codeX " y" codeEditorTop
                " w" initialCodeWidth " h" initialCodeEditorHeight
                " +0x003111C4 -E0x200 -TabStop")
        this.CodeEditHwnd := this.CodeEdit.Hwnd
        this.ApplyEditorTextLimit()
        initialText := mapping.HasOwnProp("EditorText")
            ? mapping.EditorText : mapping.Block
        ControlSetText(initialText, this.CodeEdit)
        eventMask := SendMessage(0x043B, 0, 0, , this.CodeEdit.Hwnd)
        SendMessage(0x0445, 0, eventMask | 0x00000007, ,
            this.CodeEdit.Hwnd)
        SendMessage(0x0443, 0, ColorRef(colors.Surface), , this.CodeEdit.Hwnd)
        SendMessage(0x0443, 0, ColorRef(colors.CodeGutter), ,
            this.LineNumberEdit.Hwnd)
        SetEditMargins(this.CodeEdit.Hwnd, 10, 10)
        SetEditMargins(this.LineNumberEdit.Hwnd, 4, 8)
        ApplyDarkControl(this.CodeEdit.Hwnd)
        ApplyDarkControl(this.LineNumberEdit.Hwnd)
        if !this.Interactions.RegisterTextInput(this.CodeEdit)
            throw Error("无法注册映射代码输入区交互。")
        if !this.Interactions.EnableHiddenVerticalWheelScroll(
                this.CodeEdit, 2,
                ObjBindMethod(this, "OnEditorWheelScroll"))
            throw Error("无法注册代码编辑器滚轮滚动。")
        if !this.Interactions.RegisterFocusRedirect(this.LineNumberEdit,
                this.CodeEdit)
            throw Error("无法注册源码行号焦点重定向。")
        this.UpdateLineNumbers(initialText, false)
        this.ApplyEditorFonts(true)
        this.PrepareInitialCodeCaret()
        this.SetCodeSelectionHighlightVisible(false)
        if this.IsNew
            this.BuildModeSelector()
        this.Status := this.Gui.Add("Edit",
            "x14 y518 w380 h24 ReadOnly Multi Wrap -TabStop -Border"
                . " -VScroll -HScroll -E0x200 Background" colors.Window
                . " c" colors.Muted,
            this.IsNew ? Tr("新增映射代码") : Tr("编辑映射代码"))
        ApplyDarkControl(this.Status.Hwnd)
        if !this.Interactions.RegisterTextInput(this.Status, "", "text", true)
            throw Error("无法注册映射编辑器状态复制交互。")
        this.Interactions.EnableHiddenVerticalWheelScroll(this.Status)
        this.AISettingsLink := this.Gui.Add("Text",
            "x14 y518 w1 h24 BackgroundTrans c" colors.Error " Hidden",
            "")
        this.ApplyAISettingsLinkAppearance(false)
        this.AISettingsLink.OnEvent("Click",
            ObjBindMethod(this, "OpenAISettings"))
        this.Interactions.RegisterHandCursor(this.AISettingsLink)
        this.SaveButton := this.AddCommandButton(598, 512, 80,
            Tr("保存"), colors.Save, ObjBindMethod(this, "Save"))
        this.CancelButton := this.AddCommandButton(686, 512, 80,
            Tr("取消"), colors.Toolbar, ObjBindMethod(this, "RequestClose"))
        this.AiButton := this.AddCommandButton(446, 512,
            MappingBlockEditor.AIButtonWidth,
            this.GetAiButtonText(), colors.AIButton,
            ObjBindMethod(this, "StartAiRequest"))
        this.Interactions.SetButtonLucideIcon(this.AiButton,
            "pencil-sparkles.svg", 14, 6, colors.AIIcon)
        this.Interactions.SetFocusSink(this.SaveButton)
    }

    BuildModeSelector() {
        managedText := Tr("规则块")
        scriptText := Tr("受托管脚本")
        initialWidth := MappingBlockEditor.ModeButtonMaximumWidth
        scriptX := MappingBlockEditor.EditorWidth
            - MappingBlockEditor.ModeSelectorRightMargin
            - initialWidth
        managedX := scriptX - MappingBlockEditor.ModeButtonGap
            - initialWidth
        this.ManagedModeButton := this.AddModeButton(
            managedX, managedText, "managed", initialWidth)
        this.ScriptModeButton := this.AddModeButton(
            scriptX, scriptText, "script", initialWidth)
        measuredWidth := Max(
            this.MeasureControlTextWidth(this.ManagedModeButton, managedText),
            this.MeasureControlTextWidth(this.ScriptModeButton, scriptText))
                + MappingBlockEditor.ModeButtonHorizontalPadding
        this.ModeButtonWidth := Max(MappingBlockEditor.ModeButtonMinimumWidth,
            Min(MappingBlockEditor.ModeButtonMaximumWidth,
                Ceil(measuredWidth)))
        scriptX := MappingBlockEditor.EditorWidth
            - MappingBlockEditor.ModeSelectorRightMargin
            - this.ModeButtonWidth
        managedX := scriptX - MappingBlockEditor.ModeButtonGap
            - this.ModeButtonWidth
        this.ManagedModeButton.Move(managedX, , this.ModeButtonWidth)
        this.ScriptModeButton.Move(scriptX, , this.ModeButtonWidth)
        this.RefreshModeSelectorAppearance()
    }

    AddModeButton(x, text, mode, width) {
        colors := MappingWindow.Colors
        button := this.Gui.Add("Text", "x" x " y10 w"
            width " h30 Center 0x200 "
            . "Background" colors.Toolbar " c" colors.ToolbarText, text)
        button.SetFont("s9 bold",
            LocalizationService.GetLanguageSystemUiFontName())
        callback := ObjBindMethod(this, "SwitchEditorMode", mode)
        if !this.Interactions.RegisterButton(button, colors.Toolbar,
                callback, "", "", false, colors.ToolbarText)
            button.OnEvent("Click", callback)
        return button
    }

    SwitchEditorMode(mode, *) {
        mode := StrLower(String(mode))
        if !this.IsNew || mode == this.EditorMode
            return false
        if this.IsDirty() && !this.Confirm(
                Tr("切换规则类型会清空当前未保存内容，是否继续？"),
                Tr("切换规则类型"), Tr("继续"), Tr("取消"), this.Gui)
            return false
        try text := this.OwnerWindow.App.Repository.CreateBlankEditorText(mode)
        catch as templateError {
            this.SetStatus(Tr("无法创建规则模板：{1}", templateError.Message),
                true)
            return false
        }
        previousMode := this.EditorMode
        previousText := this.GetCodeText()
        previousStartLine := this.StartLine
        this.EditorMode := mode
        this.ApplyEditorTextLimit()
        this.StartLine := this.OwnerWindow.App.Repository.GetAppendStartLine()
        if !this.ReplaceEditorTextAtomically(text) {
            this.EditorMode := previousMode
            this.StartLine := previousStartLine
            this.ReplaceEditorTextAtomically(previousText)
            this.RefreshModeSelectorAppearance()
            this.SetStatus(Tr("映射代码未保存：{1}",
                "无法完成编辑器格式化。"), true)
            return false
        }
        this.OriginalText := this.Canonicalize(text)
        this.RefreshModeSelectorAppearance()
        ControlFocus(this.CodeEdit)
        return true
    }

    ReplaceEditorTextAtomically(text) {
        codeHwnd := this.CodeEditHwnd
        if this.Disposed || !this.IsLiveControl(codeHwnd)
            return false
        this.CancelPresentationTimers()
        canonicalText := this.Canonicalize(text)
        redrawSuspended := false
        this.SendControlMessage(0x000B, 0, 0, codeHwnd) ; WM_SETREDRAW
        redrawSuspended := true
        try {
            this.SuppressEditorChange := true
            try ControlSetText(text, this.CodeEdit)
            finally this.SuppressEditorChange := false
            this.EditorRevision++
            this.CachedCanonicalText := canonicalText
            this.CachedTextRevision := this.EditorRevision
            this.LastFormattedRevision := -1
            this.PendingFormatStart := -1
            this.PendingFormatEnd := -1
            this.LineNumberCount := 0
            this.UpdateLineNumbers(text)
            return this.ApplyEditorTextFormatting(canonicalText, true, false)
        } finally {
            this.SuppressEditorChange := false
            if redrawSuspended && this.IsLiveControl(codeHwnd) {
                this.SendControlMessage(0x000B, 1, 0, codeHwnd)
                DllCall("user32\InvalidateRect", "Ptr", codeHwnd,
                    "Ptr", 0, "Int", 0)
            }
        }
    }

    RefreshModeSelectorAppearance() {
        if !IsObject(this.ManagedModeButton)
            return false
        colors := MappingWindow.Colors
        this.Interactions.SetTextNoErase(this.ManagedModeButton,
            Tr("规则块"))
        this.Interactions.SetTextNoErase(this.ScriptModeButton,
            Tr("受托管脚本"))
        this.Interactions.SetButtonAppearance(this.ManagedModeButton,
            this.EditorMode == "managed" ? colors.Primary : colors.Toolbar,
            this.EditorMode == "managed" ? colors.ButtonText
                : colors.ToolbarText, true)
        this.Interactions.SetButtonAppearance(this.ScriptModeButton,
            this.EditorMode == "script" ? colors.Primary : colors.Toolbar,
            this.EditorMode == "script" ? colors.ButtonText
                : colors.ToolbarText, true)
        return true
    }

    ApplyEditorTextLimit() {
        if !this.CodeEditHwnd
            return false
        limit := MappingCodeRepository.MaximumBlockCharacters
        SendMessage(0x0435, 0, limit, , this.CodeEditHwnd)
        return true
    }

    AddCommandButton(x, y, width, text, color, callback) {
        button := this.Gui.Add("Text", "x" x " y" y " w" width
            " h32 Center 0x200 Background" color " c" MappingWindow.Colors.Text,
            text)
        button.SetFont("s10 bold",
            LocalizationService.GetLanguageSystemUiFontName())
        if !this.Interactions.RegisterButton(button, color, callback)
            button.OnEvent("Click", callback)
        return button
    }

    Show() {
        if this.Disposed
            return
        this.CodeEdit.Opt("-TabStop")
        this.PrepareInitialCodeCaret()
        this.SetCodeSelectionHighlightVisible(false)
        ShowPreparedWindow(this.Gui, "w" MappingBlockEditor.EditorWidth
            " h" MappingBlockEditor.EditorHeight,
            ObjBindMethod(this, "PrepareFirstVisibleEditorSurface"))
        this.UpdateLineNumbers()
        this.CodeEdit.Opt("+TabStop")
        this.PrepareInitialCodeCaret()
        try ControlFocus(this.CodeEdit)
        this.PrepareInitialCodeCaret()
        this.SetCodeSelectionHighlightVisible(true)
    }

    PrepareFirstVisibleEditorSurface(*) {
        this.ApplyNativeThemes(false)
        this.PrepareInitialCodeCaret()
        if DllCall("user32\IsWindowVisible", "Ptr", this.Gui.Hwnd, "Int") {
            this.CodeEdit.Opt("+TabStop")
            try ControlFocus(this.CodeEdit)
            this.PrepareInitialCodeCaret()
            this.SetCodeSelectionHighlightVisible(true)
        }
        return true
    }

    PrepareInitialCodeCaret() {
        if this.Disposed || !this.IsLiveControl(this.CodeEditHwnd)
            return false
        selection := Buffer(8, 0)
        this.SendControlMessage(0x0437, 0, selection.Ptr,
            this.CodeEditHwnd) ; EM_EXSETSEL
        this.SendControlMessage(0x00B7, 0, 0,
            this.CodeEditHwnd) ; EM_SCROLLCARET
        return true
    }

    SetCodeSelectionHighlightVisible(visible := true) {
        if this.Disposed || !this.IsLiveControl(this.CodeEditHwnd)
            return false
        this.SendControlMessage(0x043F, visible ? 0 : 1, 0,
            this.CodeEditHwnd) ; EM_HIDESELECTION
        return true
    }

    ApplyNativeThemes(stabilize := true, *) {
        if this.Disposed
            return false
        if stabilize
            BeginStableWindowUpdate(this.Gui.Hwnd)
        try {
            windowApplied := ApplyDarkWindow(this.Gui.Hwnd)
            codeApplied := ApplyDarkControl(this.CodeEdit.Hwnd)
            gutterApplied := ApplyDarkControl(this.LineNumberEdit.Hwnd)
        } finally {
            if stabilize
                EndStableWindowUpdate(this.Gui.Hwnd)
        }
        return windowApplied && codeApplied && gutterApplied
    }

    ApplyAppearance(*) {
        if this.Disposed
            return false
        BeginStableWindowUpdate(this.Gui.Hwnd)
        try {
        colors := MappingWindow.Colors
        this.Gui.Title := this.IsNew ? Tr("新增映射代码")
            : Tr("编辑映射代码")
        this.Gui.BackColor := colors.Window
        this.Gui.SetFont("s10 c" colors.Text,
            LocalizationService.GetUiFontName())
        this.Interactions.SetParentColor(colors.Window)
        if this.IsNew
            this.Title.Text := Tr("新增映射代码")
        this.Title.SetFont("s11 bold c" colors.Text,
            LocalizationService.GetLanguageSystemUiFontName())
        SendMessage(0x0443, 0, ColorRef(colors.Surface), ,
            this.CodeEdit.Hwnd)
        SendMessage(0x0443, 0, ColorRef(colors.CodeGutter), ,
            this.LineNumberEdit.Hwnd)
        this.LineNumberDivider.Opt("+Background" colors.Divider)
        this.Interactions.SetTextNoErase(this.SaveButton, Tr("保存"))
        this.Interactions.SetTextNoErase(this.CancelButton, Tr("取消"))
        this.Interactions.SetTextNoErase(this.AiButton,
            this.GetAiButtonText())
        this.Interactions.SetButtonAppearance(this.SaveButton,
            colors.Save, colors.ButtonText, true)
        this.Interactions.SetButtonAppearance(this.CancelButton,
            colors.Toolbar, colors.ToolbarText, true)
        this.Interactions.SetButtonAppearance(this.AiButton,
            colors.AIButton, colors.AIButtonText, !this.AiBusy)
        this.Interactions.SetButtonLucideIcon(this.AiButton,
            "pencil-sparkles.svg", 14, 6, colors.AIIcon)
        this.Status.SetFont("s10 c" (this.StatusIsError
            ? colors.Error : colors.Muted),
            LocalizationService.GetUiFontName())
        this.ApplyAISettingsLinkAppearance(this.AISettingsLinkHovered)
        this.RefreshAISettingsLinkBounds()
        this.ApplyNativeThemes(false)
        this.ApplyLineNumberAppearance()
        if this.IsNew
            this.RefreshModeSelectorAppearance()
        this.ApplyEditorFonts(true)
        this.RelayoutCurrentSize()
        DllCall("user32\RedrawWindow", "Ptr", this.Gui.Hwnd,
            "Ptr", 0, "Ptr", 0, "UInt", Win32.RDW_LAYOUT_REFRESH, "Int")
        } finally EndStableWindowUpdate(this.Gui.Hwnd, true)
        return true
    }

    Activate() {
        if this.Disposed
            return
        return ActivatePreparedWindow(this.Gui)
    }

    Save(*) {
        if this.Disposed
            return
        editorText := this.GetCodeText()
        if this.IsNew && this.EditorMode == "script" {
            if !this.ValidateNewScriptBeforeConfirmation(editorText)
                return
            if !this.Confirm(
                    Tr("自定义 AHK 代码可读取文件、启动程序、控制窗口并请求管理员权限。确认运行当前代码吗？"),
                    Tr("运行自定义 AHK 代码"), Tr("保存并运行"), Tr("取消"),
                    this.Gui)
                return
        }
        this.CancelPresentationTimers()
        result := this.IsNew
            ? this.OwnerWindow.App.AddMappingEditorText(editorText,
                this.EditorMode)
            : this.OwnerWindow.App.UpdateMappingEditorText(this.MappingId,
                editorText, this.EditorMode)
        if !result.Ok {
            this.SetStatus(Tr("未保存：{1}", result.Message), true)
            return
        }
        startDeferredApply := result.HasOwnProp("DeferredApply")
            && result.DeferredApply
        this.OriginalText := this.Canonicalize(editorText)
        this.Dispose()
        if startDeferredApply
            this.OwnerWindow.App.StartPendingScriptApply()
    }

    ValidateNewScriptBeforeConfirmation(editorText) {
        if InStr(String(editorText),
                ScriptRuleCompiler.ScriptCodePlaceholder) {
            this.SetStatus(Tr("未保存：请先用完整的 AHK v2 脚本替换代码占位文字。"),
                true)
            return false
        }
        try ScriptRuleCompiler.ParseSpec(editorText)
        catch as validationError {
            this.SetStatus(Tr("未保存：{1}", validationError.Message), true)
            return false
        }
        return true
    }

    ResolveAiOperation() => this.IsNew ? "generate" : "optimize"

    ResolveAiRequestMode(operation) {
        return StrLower(String(operation)) == "generate"
            ? "auto" : this.EditorMode
    }

    GetAiButtonText() {
        return this.IsNew ? Tr("AI 生成规则") : Tr("AI 优化规则")
    }

    StartAiRequest(*) {
        if this.Disposed || this.AiBusy
            return false
        operation := this.ResolveAiOperation()
        if !this.OwnerWindow.App.HasOwnProp("AIService")
                || !IsObject(this.OwnerWindow.App.AIService)
            return this.SetStatus(Tr("AI 服务尚未初始化。"), true)
        service := this.OwnerWindow.App.AIService
        settings := service.NormalizeSettings(this.OwnerWindow.App.Settings)
        if settings.AIAddress == "" {
            this.SetAISettingsLink(Tr("请填写 API 地址。"))
            return false
        }
        if settings.AIModel == "" {
            this.SetAISettingsLink(Tr("请填写模型名称。"))
            return false
        }
        purposeResult := this.PromptForAiPurpose(operation)
        if !purposeResult.Accepted
            return false
        try currentText := this.GetCodeText()
        catch as readError {
            this.SetStatus(Tr("无法读取当前映射代码：{1}",
                readError.Message), true)
            return false
        }
        this.AiBusy := true
        this.AiRequestRevision := this.EditorRevision
        this.AiRequestPurpose := purposeResult.Value
        this.AiRequestEditorText := currentText
        this.AiRequiredResponseMode := ""
        this.AiFormatFallbackAttempted := false
        this.AiPipelinePhase := "draft"
        this.AiCandidateText := ""
        this.AiRepairAttempts := 0
        this.AiReviewAttempts := 0
        requestMode := this.ResolveAiRequestMode(operation)
        return this.StartAiPipelineRequest(requestMode, "draft")
    }

    SetAiFailureStatus(message := "") {
        message := Trim(String(message))
        if message == ""
            message := Tr("AI 请求失败，请检查 AI 设置和网络连接。")
        this.SetStatus(message, true)
        return false
    }

    PromptForAiPurpose(operation) {
        operation := StrLower(String(operation))
        question := this.GetAiPurposeQuestion(operation)
        title := operation == "optimize"
            ? Tr("优化当前规则") : Tr("生成重映射规则")
        confirmText := operation == "optimize" ? Tr("优化") : Tr("生成")
        try result := this.PurposePromptCallback.Call(question, title,
            confirmText, Tr("取消"), Tr("请输入规则目的。"), this.Gui,
            this.AiPurposeRetryText)
        catch {
            this.SetStatus(Tr("请输入规则目的。"), true)
            return {Accepted: false, Value: ""}
        }
        if !IsObject(result) || !result.HasOwnProp("Accepted")
                || !result.Accepted
            return {Accepted: false, Value: ""}
        purpose := result.HasOwnProp("Value")
            ? Trim(String(result.Value)) : ""
        if purpose == "" {
            this.SetStatus(Tr("请输入规则目的。"), true)
            return {Accepted: false, Value: ""}
        }
        this.AiPurposeRetryText := purpose
        return {Accepted: true, Value: purpose}
    }

    GetAiPurposeQuestion(operation) {
        if StrLower(String(operation)) == "optimize"
            return Tr("说点什么吧，我什么都会做的 T_T")
        return Tr("我是来帮你的，你要干什么？！")
    }

    HandleAiResult(ok, message, responseText, requestId, *) {
        if this.Disposed || requestId != this.AiRequestId
            return false
        phase := this.AiPipelinePhase
        this.AiRequestId := 0
        if !ok {
            return this.FinishAiPipelineFailure(message)
        }
        if this.EditorRevision != this.AiRequestRevision {
            return this.FinishAiPipelineFailure(
                Tr("请求期间编辑器内容已变化，请重新执行 AI 操作。"))
        }
        operation := this.ResolveAiOperation()
        requiredMode := operation == "optimize" ? this.EditorMode
            : this.AiRequiredResponseMode
        failedCandidate := responseText
        try {
            aiRule := this.NormalizeAiRuleResult(responseText, requiredMode)
            failedCandidate := aiRule.Text
            this.ValidateAiRuleResult(aiRule)
        }
        catch as validationError {
            return this.HandleAiValidationFailure(validationError,
                failedCandidate, phase)
        }
        this.AiCandidateText := aiRule.Text
        if phase != "review" && this.AiReviewAttempts
                < MappingBlockEditor.AIMaximumSemanticReviewAttempts
            return this.StartAiSemanticReview(aiRule)
        return this.ApplyValidatedAiRule(aiRule)
    }

    StartAiPipelineRequest(mode, phase, candidateText := "",
            validationFeedback := "") {
        if this.Disposed
            return false
        if !this.OwnerWindow.App.HasOwnProp("AIService")
                || !IsObject(this.OwnerWindow.App.AIService)
            return this.FinishAiPipelineFailure(
                Tr("AI 服务尚未初始化。"))
        operation := this.ResolveAiOperation()
        this.AiBusy := true
        this.AiPipelinePhase := phase
        this.AiCandidateText := candidateText
        this.SetStatus(this.GetAiPhaseStatus(phase, operation))
        colors := MappingWindow.Colors
        this.Interactions.SetButtonAppearance(this.AiButton,
            colors.AIButton, colors.AIButtonText, false)
        try result := this.OwnerWindow.App.AIService.Request(
            this.OwnerWindow.App.Settings, mode, operation,
            this.AiRequestEditorText, ObjBindMethod(this, "HandleAiResult"),
            this.AiRequestPurpose, phase, candidateText,
            validationFeedback,
            ObjBindMethod(this, "HandleAiRequestStatus"))
        catch as requestError {
            return this.FinishAiPipelineFailure(requestError.Message)
        }
        if !result.Ok {
            if result.HasOwnProp("Action")
                    && result.Action == "open-ai-settings" {
                this.FinishAiPipeline(false)
                this.SetAISettingsLink(Tr(result.Message))
                return false
            }
            return this.FinishAiPipelineFailure(
                result.HasOwnProp("Message") ? result.Message : "")
        }
        this.AiRequestId := result.RequestId
        return true
    }

    HandleAiRequestStatus(status, requestId, *) {
        if this.Disposed || !this.AiBusy || !IsObject(status)
            return false
        if this.AiRequestId && requestId != this.AiRequestId
            return false
        operation := this.ResolveAiOperation()
        phase := status.HasOwnProp("Phase") ? status.Phase : this.AiPipelinePhase
        phaseStatus := this.GetAiPhaseStatus(phase, operation)
        elapsedS := status.HasOwnProp("ElapsedSeconds")
            ? status.ElapsedSeconds : 0
        this.SetStatus(phaseStatus "`n"
            Tr("当前等待时间：{1} 秒", elapsedS))
        return true
    }

    GetAiPhaseStatus(phase, operation := "") {
        status := phase == "review"
            ? Tr("AI 正在复核规则的实际行为，请稍候...")
            : phase == "repair"
                ? Tr("AI 正在根据本地校验结果修复规则，请稍候...")
                : operation == "generate"
                    ? Tr("AI 正在生成规则，请稍候...")
                    : Tr("AI 正在优化规则，请稍候...")
        return RegExReplace(status, "\.{3}$", "…")
    }

    StartAiSemanticReview(aiRule) {
        if !IsObject(aiRule) || !aiRule.HasOwnProp("Text")
            return this.FinishAiPipelineFailure(
                Tr("AI 规则校验结果不完整。"))
        this.AiReviewAttempts++
        operation := this.ResolveAiOperation()
        reviewMode := operation == "optimize" ? this.EditorMode
            : this.AiRequiredResponseMode != ""
                ? this.AiRequiredResponseMode : "auto"
        return this.StartAiPipelineRequest(reviewMode, "review",
            aiRule.Text)
    }

    HandleAiValidationFailure(validationError, candidateText, phase) {
        message := validationError.HasOwnProp("Message")
            ? validationError.Message : String(validationError)
        try candidateText := String(candidateText)
        catch
            candidateText := ""
        if Trim(candidateText) == ""
            candidateText := this.AiCandidateText != ""
                ? this.AiCandidateText : this.AiRequestEditorText
        operation := this.ResolveAiOperation()
        requiresScript := operation == "generate"
            && Type(validationError.Extra) == "String"
            && validationError.Extra == "ai-requires-script"
            && !this.AiFormatFallbackAttempted
        if requiresScript {
            this.AiFormatFallbackAttempted := true
            this.AiRequiredResponseMode := "script"
        }
        if this.AiRepairAttempts
                >= MappingBlockEditor.AIMaximumRepairAttempts
            return this.FinishAiPipelineFailure(
                Tr("AI 返回的规则经过自动修复后仍未通过本地校验：{1}",
                    message) "`n"
                . Tr("已保留原内容，AI 结果未应用。"))
        this.AiRepairAttempts++
        repairMode := operation == "optimize" ? this.EditorMode
            : this.AiRequiredResponseMode != ""
                ? this.AiRequiredResponseMode : "auto"
        feedback := Tr("本地校验失败：{1}", message)
            . "`n" Tr("失败发生阶段：{1}", phase)
            . "`n" Tr("必须修复根因并重新满足用户原始目的。")
        if requiresScript
            feedback .= "`n" Tr("规则块能力不足，必须改用受托管脚本完整实现。")
        return this.StartAiPipelineRequest(repairMode, "repair",
            candidateText, feedback)
    }

    ApplyValidatedAiRule(aiRule) {
        normalizedText := aiRule.Text
        operation := this.ResolveAiOperation()
        if operation == "optimize" {
            try currentText := this.GetCodeText()
            catch as readError {
                return this.FinishAiPipelineFailure(
                    Tr("无法读取当前映射代码：{1}", readError.Message))
            }
            review := this.ReviewAiResult(currentText, normalizedText)
            if !review.Completed {
                this.FinishAiPipeline(false)
                return false
            }
            if !review.Accepted {
                this.FinishAiPipeline(false)
                this.SetStatus(Tr("已保留原内容，AI 结果未应用。"))
                return false
            }
            if this.Disposed {
                this.FinishAiPipeline(false)
                return false
            }
            if this.EditorRevision != this.AiRequestRevision {
                return this.FinishAiPipelineFailure(Tr(
                    "请求期间编辑器内容已变化，请重新执行 AI 操作。"))
            }
        }
        previousMode := this.EditorMode
        if aiRule.Mode != this.EditorMode {
            this.EditorMode := aiRule.Mode
            this.ApplyEditorTextLimit()
            this.RefreshModeSelectorAppearance()
        }
        if !this.ReplaceEditorTextAtomically(normalizedText) {
            this.EditorMode := previousMode
            this.ApplyEditorTextLimit()
            this.RefreshModeSelectorAppearance()
            return this.FinishAiPipelineFailure(
                Tr("AI 结果无法应用到编辑器，请重试。"))
        }
        this.AiPurposeRetryText := ""
        this.FinishAiPipeline(false)
        this.SetStatus(Tr("AI 规则已放入编辑器，请检查后保存。"))
        return true
    }

    RetryAiGenerationAsScript(reason) {
        validationError := Error(reason, -1, "ai-requires-script")
        return this.HandleAiValidationFailure(validationError,
            this.AiCandidateText, this.AiPipelinePhase)
    }

    FinishAiPipelineFailure(message := "") {
        this.FinishAiPipeline(false)
        return this.SetAiFailureStatus(message)
    }

    FinishAiPipeline(clearPurpose := false) {
        this.AiRequestId := 0
        this.AiBusy := false
        if clearPurpose
            this.AiPurposeRetryText := ""
        if !this.Disposed && IsObject(this.AiButton) {
            colors := MappingWindow.Colors
            this.Interactions.SetButtonAppearance(this.AiButton,
                colors.AIButton, colors.AIButtonText, true)
        }
        return true
    }

    ReviewAiResult(currentText, proposedText) {
        title := Tr("审阅 AI 优化结果")
        try return {Completed: true, Accepted: !!this.AiReviewCallback.Call(
            currentText, proposedText, title, this.Gui)}
        catch as reviewError {
            this.SetStatus(Tr("无法打开 AI 结果审阅：{1}",
                reviewError.Message), true)
            return {Completed: false, Accepted: false}
        }
    }

    NormalizeAiRule(responseText) {
        return this.NormalizeAiRuleResult(responseText).Text
    }

    NormalizeAiRuleResult(responseText, requiredMode := "") {
        text := this.ExtractAiRuleBlock(responseText)
        fields := RuleCompiler.ParseMetadata(text)
        typeName := RuleCompiler.RequiredMetadata(fields, "类型")
        mode := RuleCompiler.ModeFromTypeName(typeName)
        requiredMode := StrLower(Trim(String(requiredMode)))
        if requiredMode != "" && mode != requiredMode
            throw Error("AI 返回的规则类型与当前编辑器类型不一致。")
        if mode == "managed" {
            specValue := RuleCompiler.ParseManagedSpecValue(text, true)
            try spec := this.NormalizeAiManagedSpec(specValue)
            catch as normalizationError {
                if this.IsAiManagedCapabilityError(normalizationError)
                    throw Error("规则块无法完整表达该需求："
                        normalizationError.Message, -1,
                        "ai-requires-script")
                throw
            }
            return {Text: RuleCompiler.BuildManagedBlock(spec), Mode: mode,
                Spec: spec}
        }
        spec := ScriptRuleCompiler.ParseSpec(text)
        return {Text: ScriptRuleCompiler.BuildBlock(spec), Mode: mode,
            Spec: spec}
    }

    ValidateAiRuleResult(aiRule) {
        if !IsObject(aiRule) || !aiRule.HasOwnProp("Mode")
                || !aiRule.HasOwnProp("Spec")
            throw TypeError("AI 规则校验结果不完整。")
        mode := StrLower(String(aiRule.Mode))
        runtime := this.App.HasOwnProp("Runtime")
            && IsObject(this.App.Runtime) ? this.App.Runtime : ""
        if mode == "managed" {
            descriptor := RuleCompiler.Compile(aiRule.Spec)
            scriptRequirement := RuleCompiler
                .GetManagedScriptRequirement(descriptor)
            if scriptRequirement != ""
                throw Error("规则块无法由当前运行时正确执行："
                    scriptRequirement, -1, "ai-requires-script")
            if IsObject(runtime) && runtime.HasOwnProp("Direct")
                    && IsObject(runtime.Direct) {
                try runtime.Direct.BuildRegistration(descriptor)
                catch as runtimeError {
                    if (Type(runtimeError.Extra) == "String"
                            && runtimeError.Extra == "ai-requires-script")
                            || this.IsAiManagedCapabilityError(runtimeError)
                        throw Error("规则块无法由当前运行时正确执行："
                            runtimeError.Message, -1, "ai-requires-script")
                    throw Error("规则块无法由当前运行时执行："
                        runtimeError.Message, -1, runtimeError)
                }
            }
            return true
        }
        if mode != "script"
            throw Error("AI 返回了未知规则形式：" mode)
        spec := ScriptRuleSpec.Normalize(aiRule.Spec)
        if !this.HasAiScriptExecutableContent(spec["code"])
            throw Error("受托管脚本没有可执行语句或热键；"
                . "请检查源码是否被错误地全部注释。")
        this.ValidateAiScriptBehavior(spec["code"])
        if !IsObject(runtime) || !runtime.HasOwnProp("Scripts")
                || !IsObject(runtime.Scripts)
            throw Error("AHK v2 脚本校验器当前不可用；为避免应用未经校验的代码，已拒绝本次 AI 结果。")
        try runtime.Scripts.ValidateSpec(spec)
        catch as validationError
            throw Error("受托管脚本无法通过 AHK v2 语法与兼容性检查："
                validationError.Message, -1, validationError)
        return true
    }

    ValidateAiScriptBehavior(code) {
        code := this.Canonicalize(code)
        for directive in ["#Requires", "#NoTrayIcon", "#SingleInstance"] {
            if RegExMatch(code, "im)^[ `t]*" directive "(?:[ `t]|$)")
                throw Error("受托管脚本不应包含 " directive
                    . "；该指令由宿主 worker 统一添加或管理。")
        }
        hasPassthroughAltDown := RegExMatch(code,
            "im)^[ `t]*~[^\r\n:]*\b(?:LAlt|RAlt|Alt)[ `t]*::")
        hasAltUpHotkey := RegExMatch(code,
            "im)^[ `t]*[^\r\n:]*\b(?:LAlt|RAlt|Alt)[ `t]+Up[ `t]*::")
        sendCallPattern := "i)(?:Send|SendEvent|SendInput|SendPlay|SendText)"
            . "[ `t]*\([^\r\n]*"
        quoteClass := "[" Chr(34) Chr(39) "]"
        sendsAltUp := RegExMatch(code, sendCallPattern
            . "(?:\{(?:LAlt|RAlt|Alt)[ `t]+up\}|\{" quoteClass
            . "[ `t]+[A-Za-z_]\w*[ `t]+" quoteClass "[ `t]+up\})")
        if hasPassthroughAltDown && hasAltUpHotkey && sendsAltUp
            throw Error("脚本先让物理 Alt 穿透，再在松开时发送 Alt Up；"
                . "这无法撤销 Office 已经激活的菜单或 KeyTips。"
                . "请在 Alt 按下且仍处于按住状态时发送 {Blind}{vkE8}，"
                . "并保留物理 Alt 以继续支持组合键。")
        return true
    }

    IsAiManagedCapabilityError(validationError) {
        if !IsObject(validationError) || !validationError.HasOwnProp("Message")
            return false
        if Type(validationError.Extra) == "String"
                && validationError.Extra == "ai-requires-script"
            return true
        message := Trim(String(validationError.Message))
        static exactMessages := Map(
            "Sequences are not supported by the direct AHK runtime.", true,
            "Multi-tap rules are not supported by the direct AHK runtime.", true,
            "Timed action repetition is not supported by the direct AHK runtime.", true,
            "Key-up rules with modifiers are not supported by the direct AHK runtime.", true,
            "Direct simultaneous rules support only down events.", true,
            "Key-up source rules cannot leave a key pressed.", true,
            "Sources without an up event cannot use held, release, or key-down actions.", true)
        if exactMessages.Has(message)
            return true
        if RegExMatch(message,
                "^RuleSpec (?:to_if_other_key_pressed|to_delayed_if_invoked|to_delayed_if_canceled) is not supported by the direct AHK runtime\.$")
            return true
        return RegExMatch(message,
            "^up 来源不支持 (?:repeat=only|to_if_alone|to_if_held_down)；") != 0
    }

    HasAiScriptExecutableContent(code) {
        Loop Parse String(code), "`n", "`r" {
            line := Trim(A_LoopField)
            if line == "" || SubStr(line, 1, 1) == ";"
                    || SubStr(line, 1, 1) == "#"
                continue
            return true
        }
        return false
    }

    ExtractAiRuleBlock(responseText) {
        try text := String(responseText)
        catch
            throw TypeError("AI 返回内容必须是文本。")
        text := StrReplace(StrReplace(text, "`r`n", "`n"), "`r", "`n")
        text := Trim(text)
        if SubStr(text, 1, 1) == Chr(0xFEFF)
            text := Trim(SubStr(text, 2))
        if text == ""
            throw Error("AI 没有返回规则内容。")
        if RegExMatch(text, "is)^```[^\r\n]*\R(.*?)\R```[ \t]*$", &fence)
            text := Trim(fence[1])
        if !RegExMatch(text, "i)^;[ \t]*@mapping-begin") {
            try parsed := JsonCodec.Parse(text)
            catch
                parsed := ""
            wrappedText := this.ExtractAiWrappedRuleText(parsed)
            if wrappedText != ""
                text := wrappedText
        }
        text := this.NormalizeAiRuleBlockLines(Trim(text))
        beginCount := RuleCompiler.CountExactLines(text,
            "; @mapping-begin")
        endCount := RuleCompiler.CountExactLines(text, "; @mapping-end")
        if beginCount != 1 || endCount != 1
            throw Error("AI 必须返回恰好一个完整的 @mapping-begin/@mapping-end 规则块。")
        beginPosition := RegExMatch(text,
            "m)^; @mapping-begin$")
        if beginPosition > 1
            text := SubStr(text, beginPosition)
        endPosition := RegExMatch(text,
            "m)^; @mapping-end$")
        if endPosition {
            nextLine := InStr(text, "`n", false, endPosition)
            text := nextLine ? SubStr(text, 1, nextLine - 1) : text
        }
        if StrLen(text) > MappingCodeRepository.MaximumBlockCharacters
            throw Error("AI 返回的规则块超过大小上限。")
        return text
    }

    ExtractAiWrappedRuleText(parsed) {
        if Type(parsed) != "Map"
            return ""
        for key in ["rule", "block", "content", "text", "result"] {
            if !parsed.Has(key) || IsObject(parsed[key])
                continue
            candidate := Trim(String(parsed[key]))
            if RegExMatch(candidate,
                    "im)^[ \t]*;[ \t]*@mapping-begin[ \t]*$")
                return candidate
        }
        return ""
    }

    NormalizeAiRuleBlockLines(text) {
        static markers := Map(
            "@mapping-begin", "; @mapping-begin",
            "@mapping-end", "; @mapping-end",
            "@spec-begin", "; @spec-begin",
            "@spec-end", "; @spec-end",
            "@generated-begin", "; @generated-begin",
            "@generated-end", "; @generated-end",
            "@script-code-begin", "; @script-code-begin",
            "@script-code-end", "; @script-code-end")
        result := ""
        region := ""
        Loop Parse text, "`n", "`r" {
            line := RegExReplace(A_LoopField, "^[ \t]+(?=;)")
            markerKey := RegExReplace(StrLower(Trim(line, " `t")),
                "^(?:;|//)[ \t]*")
            if markers.Has(markerKey) {
                line := markers[markerKey]
            } else if RegExMatch(line,
                    "i)^[ \t]*(?:;|//)?[ \t]*@([^=]+?)[ \t]*=(.*)$",
                    &metadata) {
                metadataName := this.NormalizeAiMetadataName(metadata[1])
                if metadataName != "" {
                    metadataValue := metadata[2]
                    if metadataName == "类型"
                        metadataValue := this.NormalizeAiTypeMetadataValue(
                            metadataValue)
                    line := "; @" metadataName "=" metadataValue
                }
            } else if region == "spec" {
                if SubStr(LTrim(line, " `t"), 1, 1) != ";"
                    line := "; " line
            } else if region == "script" {
                if RegExMatch(Trim(line, " `t"),
                        "^\x60{3}[^\x60]*$")
                    continue
                if !RegExMatch(line, "^;  ")
                    line := ";  " line
            }
            result .= (A_Index > 1 ? "`n" : "") line
            if markerKey == "@spec-begin"
                region := "spec"
            else if markerKey == "@script-code-begin"
                region := "script"
            else if markerKey == "@spec-end"
                    || markerKey == "@script-code-end"
                region := ""
        }
        return result
    }

    NormalizeAiMetadataName(value) {
        identity := StrLower(RegExReplace(Trim(String(value)),
            "[\s_-]+"))
        static aliases := Map(
            "名称", "名称", "规则名称", "名称", "name", "名称",
            "类型", "类型", "规则类型", "类型", "type", "类型",
            "来源按键", "来源按键", "来源", "来源按键",
            "source", "来源按键", "sourcekey", "来源按键",
            "映射结果", "映射结果", "目标", "映射结果",
            "target", "映射结果", "result", "映射结果",
            "mappingresult", "映射结果",
            "生效范围", "生效范围", "范围", "生效范围",
            "scope", "生效范围", "enabled", "enabled")
        return aliases.Get(identity, "")
    }

    NormalizeAiTypeMetadataValue(value) {
        text := Trim(String(value))
        identity := StrLower(RegExReplace(text, "[\s_-]+"))
        static managedAliases := Map(
            "规则块", true, "managed", true,
            "managedrule", true, "rulespec", true)
        static scriptAliases := Map(
            "受托管独立脚本", true, "受托管脚本", true,
            "受托管脚本（ahkv2）", true, "受托管脚本(ahkv2)", true,
            "独立脚本", true, "独立脚本（ahkv2）", true,
            "独立脚本(ahkv2)", true, "script", true,
            "managedscript", true)
        if managedAliases.Has(identity)
            return RuleCompiler.ManagedTypeName
        if scriptAliases.Has(identity)
            return RuleCompiler.ScriptTypeName
        return text
    }

    NormalizeAiManagedSpec(specValue) {
        if Type(specValue) != "Map"
            return RuleSpec.Normalize(specValue)
        spec := RuleSpec.Clone(specValue)
        this.NormalizeAiManagedRoot(spec)
        for fieldName in ["enabled", "passthrough", "stop_processing"]
            this.NormalizeAiBooleanField(spec, fieldName)
        this.NormalizeAiIntegerField(spec, "priority")

        if spec.Has("from") && Type(spec["from"]) == "Map"
            this.NormalizeAiFrom(spec["from"])

        if spec.Has("conditions") {
            if Type(spec["conditions"]) == "Map"
                spec["conditions"] := [spec["conditions"]]
            if Type(spec["conditions"]) == "Array"
                for condition in spec["conditions"]
                    this.NormalizeAiCondition(condition)
        }

        for fieldName in RuleSpec.ActionFields {
            if !spec.Has(fieldName)
                continue
            if Type(spec[fieldName]) == "Map"
                spec[fieldName] := [spec[fieldName]]
            if Type(spec[fieldName]) == "Array"
                for action in spec[fieldName]
                    this.NormalizeAiAction(action)
        }

        if spec.Has("timing") && Type(spec["timing"]) == "Map"
            this.NormalizeAiTiming(spec["timing"])
        scriptRequirement := this.GetAiManagedScriptRequirement(spec)
        if scriptRequirement != ""
            throw Error(scriptRequirement, -1, "ai-requires-script")
        return RuleSpec.Normalize(spec)
    }

    GetAiManagedScriptRequirement(spec) {
        if Type(spec) != "Map"
            return ""
        from := spec.Get("from", Map())
        ; RuleSpec checks for a primary direct-runtime source before it checks
        ; sequence support. Recognize only this valid outer shape early; every
        ; other capability decision waits for full schema/value validation.
        if Type(from) == "Map" && from.Has("sequence")
                && Type(from["sequence"]) == "Array"
                && from["sequence"].Length {
            RuleSpec.NormalizeKeyArray(from["sequence"])
            return "按键序列需要由受托管脚本跟踪输入顺序。"
        }
        return ""
    }

    NormalizeAiManagedRoot(spec) {
        for aliases in [
                ["stopProcessing", "stop_processing"],
                ["toIfAlone", "to_if_alone"],
                ["toIfHeldDown", "to_if_held_down"],
                ["toAfterKeyUp", "to_after_key_up"]]
            this.MoveAiFieldIfUnambiguous(spec, aliases[1], aliases[2])
        this.MoveAiFieldIfUnambiguous(spec, "condition", "conditions")
        this.MoveAiFieldIfUnambiguous(spec, "action", "to")
        this.MoveAiFieldIfUnambiguous(spec, "actions", "to")
        if spec.Has("from") && Type(spec["from"]) == "String"
                && Trim(spec["from"]) != ""
            spec["from"] := Map("key", Trim(spec["from"]))
        if spec.Has("timing") && !IsObject(spec["timing"])
            spec["timing"] := Map("held_threshold_ms", spec["timing"])
        for aliasName in ["heldThresholdMs", "held_threshold_ms",
                "held_threshold", "held_ms", "hold_ms"] {
            if !spec.Has(aliasName)
                continue
            if !spec.Has("timing") {
                spec["timing"] := Map("held_threshold_ms", spec[aliasName])
                spec.Delete(aliasName)
                continue
            }
            if Type(spec["timing"]) != "Map"
                continue
            if !spec["timing"].Has("held_threshold_ms") {
                spec["timing"]["held_threshold_ms"] := spec[aliasName]
                spec.Delete(aliasName)
            } else if this.AreAiValuesEquivalent(
                    spec["timing"]["held_threshold_ms"], spec[aliasName])
                spec.Delete(aliasName)
        }
        return true
    }

    NormalizeAiTiming(timing) {
        for aliasName in ["heldThresholdMs", "held_threshold", "held_ms",
                "hold_ms"]
            this.MoveAiFieldIfUnambiguous(timing, aliasName,
                "held_threshold_ms")
        this.NormalizeAiIntegerField(timing, "held_threshold_ms")
        return true
    }

    NormalizeAiFrom(from) {
        for aliases in [["optionalModifiers", "optional_modifiers"],
                ["tapCount", "tap_count"]]
            this.MoveAiFieldIfUnambiguous(from, aliases[1], aliases[2])
        if from.Has("key") && Type(from["key"]) == "String"
                && Trim(from["key"]) != ""
            from["key"] := Map("name", Trim(from["key"]))
        this.NormalizeAiFlattenedSourceKey(from)
        if from.Has("key") && Type(from["key"]) == "Map"
            this.NormalizeAiKeyIdentityAliases(from["key"])
        this.NormalizeAiMisplacedSourceFields(from)
        for fieldName in ["modifiers", "optional_modifiers"]
            this.NormalizeAiModifierField(from, fieldName)
        if from.Has("simultaneous")
                && Type(from["simultaneous"]) == "String" {
            simultaneousValues := this.SplitAiList(from["simultaneous"])
            if simultaneousValues.Length >= 2
                from["simultaneous"] := simultaneousValues
        }
        if from.Has("simultaneous")
                && Type(from["simultaneous"]) == "Array" {
            for index, keyValue in from["simultaneous"] {
                if Type(keyValue) == "String" && Trim(keyValue) != "" {
                    keyValue := Map("name", Trim(keyValue))
                    from["simultaneous"][index] := keyValue
                    this.NormalizeAiKey(keyValue)
                } else if Type(keyValue) == "Map"
                    this.NormalizeAiKey(keyValue)
            }
        }
        if from.Has("key") && Type(from["key"]) == "Map"
            this.NormalizeAiSourceKey(from)
        for fieldName in ["event", "repeat"] {
            if from.Has(fieldName) && !IsObject(from[fieldName])
                from[fieldName] := StrLower(Trim(String(from[fieldName])))
        }
        this.NormalizeAiIntegerField(from, "tap_count")
    }

    NormalizeAiFlattenedSourceKey(from) {
        if Type(from) != "Map" || from.Has("key")
            return false
        keyValue := Map()
        for fieldName in ["name", "kind", "vk", "sc", "extended",
                "command", "virtualKey", "scanCode", "appCommand",
                "key_name", "keyName", "code"] {
            if !from.Has(fieldName)
                continue
            keyValue[fieldName] := from[fieldName]
            from.Delete(fieldName)
        }
        if !keyValue.Count
            return false
        this.NormalizeAiKeyIdentityAliases(keyValue)
        from["key"] := keyValue
        return true
    }

    NormalizeAiKeyIdentityAliases(keyValue) {
        if Type(keyValue) != "Map"
            return false
        for aliases in [["virtualKey", "vk"], ["scanCode", "sc"],
                ["appCommand", "command"]]
            this.MoveAiFieldIfUnambiguous(keyValue, aliases[1], aliases[2])
        for aliasName in ["key", "key_name", "keyName", "code"]
            this.MoveAiFieldIfUnambiguous(keyValue, aliasName, "name")
        if keyValue.Has("kind") && !IsObject(keyValue["kind"]) {
            kindName := StrLower(Trim(String(keyValue["kind"])))
            if kindName == "app_command" || kindName == "appcommand"
                kindName := "app-command"
            keyValue["kind"] := kindName
        }
        return true
    }

    NormalizeAiModifierField(from, fieldName) {
        if Type(from) != "Map" || !from.Has(fieldName)
                || Type(from[fieldName]) != "String"
            return false
        text := Trim(from[fieldName])
        if text == "" {
            from[fieldName] := []
            return true
        }
        try {
            RuleSpec.CanonicalModifierName(text)
            from[fieldName] := [text]
            return true
        }
        parts := this.SplitAiList(text)
        from[fieldName] := parts.Length ? parts : [text]
        return true
    }

    SplitAiList(value) {
        text := Trim(String(value))
        if !RegExMatch(text, "[,|+/]")
            return []
        normalized := RegExReplace(text, "[ \t]*(?:,|\||\+|/)[ \t]*",
            "`n")
        result := []
        Loop Parse normalized, "`n" {
            item := Trim(A_LoopField)
            if item == ""
                return []
            result.Push(item)
        }
        return result
    }

    NormalizeAiMisplacedSourceFields(from) {
        if Type(from) != "Map" || !from.Has("key")
                || Type(from["key"]) != "Map"
            return false
        keyValue := from["key"]
        for aliases in [["optionalModifiers", "optional_modifiers"],
                ["tapCount", "tap_count"]]
            this.MoveAiFieldIfUnambiguous(keyValue, aliases[1], aliases[2])
        changed := false
        for fieldName in ["event", "repeat", "tap_count", "modifiers",
                "optional_modifiers"] {
            if !keyValue.Has(fieldName)
                continue
            if !from.Has(fieldName) {
                from[fieldName] := keyValue[fieldName]
                keyValue.Delete(fieldName)
                changed := true
            } else if this.AreAiSourceValuesEquivalent(fieldName,
                    from[fieldName], keyValue[fieldName]) {
                keyValue.Delete(fieldName)
                changed := true
            }
        }
        return changed
    }

    AreAiSourceValuesEquivalent(fieldName, left, right) {
        if (fieldName == "event" || fieldName == "repeat")
                && !IsObject(left) && !IsObject(right)
            return StrLower(Trim(String(left)))
                == StrLower(Trim(String(right)))
        return this.AreAiValuesEquivalent(left, right)
    }

    NormalizeAiSourceKey(from) {
        keyValue := from["key"]
        if keyValue.Has("name") && Type(keyValue["name"]) == "String"
                && !keyValue.Has("vk") && !keyValue.Has("sc") {
            combination := this.ParseAiKeyCombination(keyValue["name"])
            if IsObject(combination) {
                if combination.Kind == "modifiers" {
                    keyValue["name"] := combination.Primary
                    this.MergeAiRequiredModifiers(from,
                        combination.Modifiers)
                } else if combination.Kind == "simultaneous"
                    return this.ApplyAiSimultaneousCombination(from,
                        combination.Keys)
            }
        }
        return this.NormalizeAiKey(keyValue)
    }

    NormalizeAiKey(keyValue) {
        if keyValue.Has("name") && Type(keyValue["name"]) == "String" {
            keyValue["name"] := this.NormalizeAiKeyName(keyValue["name"])
            if !keyValue.Has("kind") {
                inferredKind := this.InferAiKeyKind(keyValue["name"])
                if inferredKind != ""
                    keyValue["kind"] := inferredKind
            }
        }
        if keyValue.Has("kind") && !IsObject(keyValue["kind"]) {
            kindName := StrLower(Trim(String(keyValue["kind"])))
            if kindName == "app_command" || kindName == "appcommand"
                kindName := "app-command"
            keyValue["kind"] := kindName
        }
        this.NormalizeAiBooleanField(keyValue, "extended")
        this.NormalizeAiIntegerField(keyValue, "command")
        return true
    }

    ParseAiKeyCombination(value) {
        text := Trim(String(value))
        if !InStr(text, "+")
            return ""
        parts := StrSplit(text, "+")
        if parts.Length < 2
            return ""
        primary := Trim(parts[parts.Length])
        if primary == ""
            return ""
        modifiers := []
        hasOnlyModifierPrefixes := true
        Loop parts.Length - 1 {
            token := Trim(parts[A_Index])
            if token == ""
                return ""
            try modifiers.Push(RuleSpec.CanonicalModifierName(token))
            catch {
                hasOnlyModifierPrefixes := false
                break
            }
        }
        primaryIsModifier := false
        try {
            RuleSpec.CanonicalModifierName(primary)
            primaryIsModifier := true
        }
        if hasOnlyModifierPrefixes && !primaryIsModifier
            return {Kind: "modifiers", Primary: primary,
                Modifiers: modifiers}
        keys := []
        for part in parts {
            normalizedName := this.NormalizeAiKeyName(Trim(part))
            resolvedName := ""
            try resolvedName := GetKeyName(normalizedName)
            if resolvedName == ""
                return ""
            keyValue := Map("name", normalizedName)
            this.NormalizeAiKey(keyValue)
            keys.Push(keyValue)
        }
        return {Kind: "simultaneous", Keys: keys}
    }

    ApplyAiSimultaneousCombination(from, keys) {
        if from.Has("simultaneous") || from.Has("hotkey")
            return false
        if from.Has("optional_modifiers") {
            if Type(from["optional_modifiers"]) != "Array"
                    || from["optional_modifiers"].Length
                return false
            from.Delete("optional_modifiers")
        }
        if from.Has("modifiers") {
            if Type(from["modifiers"]) != "Array"
                return false
            for modifier in from["modifiers"] {
                if IsObject(modifier)
                    return false
                try modifierName := RuleSpec.CanonicalModifierName(modifier)
                catch
                    return false
                modifierKey := Map("name", modifierName)
                this.NormalizeAiKey(modifierKey)
                keys.Push(modifierKey)
            }
            from.Delete("modifiers")
        }
        from.Delete("key")
        from["simultaneous"] := keys
        return true
    }

    MergeAiRequiredModifiers(from, additions) {
        if !from.Has("modifiers")
            from["modifiers"] := []
        if Type(from["modifiers"]) != "Array"
            return false
        seen := Map()
        for value in from["modifiers"] {
            if IsObject(value)
                continue
            try seen[RuleSpec.CanonicalModifierName(value)] := true
        }
        for value in additions {
            if seen.Has(value)
                continue
            from["modifiers"].Push(value)
            seen[value] := true
        }
        return true
    }

    NormalizeAiKeyName(value) {
        name := Trim(String(value))
        if RegExMatch(name, "^\{([^{}]+)\}$", &wrapped)
            name := Trim(wrapped[1])
        try {
            if GetKeyName(name) != ""
                return name
        }
        identity := StrLower(RegExReplace(name, "[\s_-]+"))
        static aliases := Map(
            "arrowup", "Up", "uparrow", "Up",
            "arrowdown", "Down", "downarrow", "Down",
            "arrowleft", "Left", "leftarrow", "Left",
            "arrowright", "Right", "rightarrow", "Right",
            "pageup", "PgUp", "pagedown", "PgDn",
            "spacebar", "Space", "return", "Enter",
            "contextmenu", "AppsKey",
            "controlleft", "LCtrl", "leftcontrol", "LCtrl",
            "controlright", "RCtrl", "rightcontrol", "RCtrl",
            "shiftleft", "LShift", "leftshift", "LShift",
            "shiftright", "RShift", "rightshift", "RShift",
            "altleft", "LAlt", "leftalt", "LAlt",
            "altright", "RAlt", "rightalt", "RAlt",
            "metaleft", "LWin", "osleft", "LWin", "winleft", "LWin",
            "metaright", "RWin", "osright", "RWin", "winright", "RWin",
            "leftmousebutton", "LButton", "mouseleftbutton", "LButton",
            "rightmousebutton", "RButton", "mouserightbutton", "RButton",
            "middlemousebutton", "MButton", "mousemiddlebutton", "MButton",
            "mousewheelup", "WheelUp", "scrollup", "WheelUp",
            "mousewheeldown", "WheelDown", "scrolldown", "WheelDown",
            "mousewheelleft", "WheelLeft", "scrollleft", "WheelLeft",
            "mousewheelright", "WheelRight", "scrollright", "WheelRight",
            "audiovolumeup", "Volume_Up", "volumeup", "Volume_Up",
            "audiovolumedown", "Volume_Down", "volumedown", "Volume_Down",
            "audiovolumemute", "Volume_Mute", "volumemute", "Volume_Mute",
            "mediatracknext", "Media_Next", "medianext", "Media_Next",
            "mediatrackprevious", "Media_Prev", "mediaprevious", "Media_Prev",
            "mediaplaypause", "Media_Play_Pause", "playpause", "Media_Play_Pause",
            "mediastop", "Media_Stop", "browserback", "Browser_Back",
            "browserforward", "Browser_Forward", "launchmail", "Launch_Mail",
            "numpaddecimal", "NumpadDot", "numpadsubtract", "NumpadSub",
            "numpadmultiply", "NumpadMult",
            "上方向键", "Up", "向上键", "Up", "上箭头", "Up",
            "下方向键", "Down", "向下键", "Down", "下箭头", "Down",
            "左方向键", "Left", "向左键", "Left", "左箭头", "Left",
            "右方向键", "Right", "向右键", "Right", "右箭头", "Right",
            "空格", "Space", "空格键", "Space",
            "回车", "Enter", "回车键", "Enter",
            "退格", "Backspace", "退格键", "Backspace",
            "删除", "Delete", "删除键", "Delete",
            "插入", "Insert", "插入键", "Insert",
            "鼠标左键", "LButton", "鼠标右键", "RButton",
            "鼠标中键", "MButton", "滚轮向上", "WheelUp",
            "滚轮向下", "WheelDown", "滚轮向左", "WheelLeft",
            "滚轮向右", "WheelRight")
        if aliases.Has(identity)
            return aliases[identity]
        if RegExMatch(identity, "^key([a-z])$", &letter)
            return StrUpper(letter[1])
        if RegExMatch(identity, "^digit([0-9])$", &digit)
            return digit[1]
        if RegExMatch(identity, "^(?:f|function)0*(\d{1,2})$", &functionKey) {
            functionNumber := Integer(functionKey[1])
            if functionNumber >= 1 && functionNumber <= 24
                return "F" functionNumber
        }
        return name
    }

    InferAiKeyKind(name) {
        if RegExMatch(name,
                "i)^(?:WheelUp|WheelDown|WheelLeft|WheelRight)$")
            return "wheel"
        if RegExMatch(name, "i)^(?:LButton|RButton|MButton|XButton1|XButton2)$")
            return "mouse"
        return ""
    }

    NormalizeAiCondition(condition) {
        if Type(condition) != "Map"
            return false
        this.MoveAiFieldIfUnambiguous(condition, "caseSensitive",
            "case_sensitive")
        this.NormalizeAiConditionShorthand(condition)
        this.NormalizeAiBooleanField(condition, "negate")
        this.NormalizeAiBooleanField(condition, "case_sensitive")
        conditionType := condition.Has("type") && !IsObject(condition["type"])
            ? this.NormalizeAiConditionType(condition["type"]) : ""
        if conditionType != ""
            condition["type"] := conditionType
        if (conditionType == "all" || conditionType == "any")
                && !condition.Has("conditions") && condition.Has("condition") {
            condition["conditions"] := condition["condition"]
            condition.Delete("condition")
        } else if conditionType == "not" && !condition.Has("condition")
                && condition.Has("conditions")
                && Type(condition["conditions"]) == "Array"
                && condition["conditions"].Length == 1 {
            condition["condition"] := condition["conditions"][1]
            condition.Delete("conditions")
        }
        if (conditionType == "all" || conditionType == "any")
                && condition.Has("conditions") {
            if Type(condition["conditions"]) == "Map"
                condition["conditions"] := [condition["conditions"]]
            if Type(condition["conditions"]) == "Array"
                for child in condition["conditions"]
                    this.NormalizeAiCondition(child)
        } else if conditionType == "not" && condition.Has("condition")
                && Type(condition["condition"]) == "Map" {
            this.NormalizeAiCondition(condition["condition"])
        }
        operatorName := condition.Has("operator")
                && !IsObject(condition["operator"])
            ? this.NormalizeAiConditionOperator(condition["operator"]) : ""
        if operatorName != ""
            condition["operator"] := operatorName
        if condition.Has("field") && !IsObject(condition["field"])
            condition["field"] := StrLower(RegExReplace(
                Trim(String(condition["field"])), "[ -]+", "_"))
        if operatorName == "exists" || operatorName == "not_exists" {
            if condition.Has("value") && condition["value"] is JsonNull
                condition.Delete("value")
            if condition.Has("case_sensitive")
                    && this.IsAiFalseLike(condition["case_sensitive"])
                condition.Delete("case_sensitive")
        }
        if (operatorName == "in" || operatorName == "not_in")
                && condition.Has("value")
                && Type(condition["value"]) != "Array"
                && !(condition["value"] is JsonNull)
                && (condition["value"] is JsonBoolean
                    || !IsObject(condition["value"]))
            condition["value"] := [condition["value"]]
        return true
    }

    NormalizeAiConditionType(value) {
        identity := StrLower(RegExReplace(Trim(String(value)), "[ -]+", "_"))
        if identity == "inputsource"
            return "input_source"
        return identity
    }

    NormalizeAiConditionOperator(value) {
        identity := StrLower(RegExReplace(Trim(String(value)), "[ -]+", "_"))
        static aliases := Map(
            "=", "equals", "==", "equals", "eq", "equals",
            "equal", "equals", "!=", "not_equals", "<>", "not_equals",
            "neq", "not_equals", "not_equal", "not_equals",
            "matches", "regex", "match", "regex",
            "startswith", "starts_with", "endswith", "ends_with",
            "notcontains", "not_contains", "notin", "not_in",
            "notexists", "not_exists")
        return aliases.Get(identity, identity)
    }

    IsAiFalseLike(value) {
        if value is JsonBoolean
            return !value.Value
        if Type(value) == "String"
            return StrLower(Trim(value)) == "false"
        return false
    }

    NormalizeAiConditionShorthand(condition) {
        conditionType := condition.Has("type")
                && !IsObject(condition["type"])
            ? this.NormalizeAiConditionType(condition["type"]) : ""
        shorthandType := ""
        for candidateType in ["application", "window", "input_source",
                "session"] {
            if !condition.Has(candidateType)
                continue
            if shorthandType != ""
                return false
            shorthandType := candidateType
        }
        if shorthandType != "" {
            if conditionType != "" && conditionType != shorthandType
                return false
            conditionType := shorthandType
        }
        fieldNames := this.GetAiConditionFieldNames(conditionType)
        if !fieldNames.Length || condition.Has("field")
                || condition.Has("value")
            return false

        candidates := []
        shorthandIsMap := false
        if shorthandType != "" {
            shorthandValue := condition[shorthandType]
            shorthandIsMap := Type(shorthandValue) == "Map"
            if shorthandIsMap {
                if !shorthandValue.Count
                    return false
                shorthandFields := Map()
                for fieldName, fieldValue in shorthandValue {
                    if !this.IsAiConditionFieldName(fieldNames, fieldName)
                        return false
                    normalizedFieldName := StrLower(Trim(String(fieldName)))
                    if shorthandFields.Has(normalizedFieldName)
                        return false
                    shorthandFields[normalizedFieldName] := fieldValue
                }
                for fieldName in fieldNames {
                    if shorthandFields.Has(fieldName)
                        candidates.Push({Field: fieldName,
                            Value: shorthandFields[fieldName]})
                }
            } else {
                candidates.Push({Field: fieldNames[1], Value: shorthandValue})
            }
        }
        directFieldKeys := []
        for sourceFieldName, sourceFieldValue in condition {
            if !this.IsAiConditionFieldName(fieldNames, sourceFieldName)
                continue
            normalizedFieldName := StrLower(Trim(String(sourceFieldName)))
            candidates.Push({Field: normalizedFieldName,
                Value: sourceFieldValue})
            directFieldKeys.Push(sourceFieldName)
        }
        if !candidates.Length || (shorthandType != "" && !shorthandIsMap
                && candidates.Length > 1)
            return false

        seenFields := Map()
        for candidate in candidates {
            if seenFields.Has(candidate.Field)
                return false
            seenFields[candidate.Field] := true
        }
        if candidates.Length > 1 {
            allowedKeys := Map("type", true, "negate", true,
                "operator", true, "case_sensitive", true)
            if shorthandType != ""
                allowedKeys[shorthandType] := true
            for fieldName in fieldNames
                allowedKeys[fieldName] := true
            for sourceFieldName in directFieldKeys
                allowedKeys[sourceFieldName] := true
            for fieldName in condition {
                if !allowedKeys.Has(fieldName)
                    return false
            }
        }

        if shorthandType != ""
            condition.Delete(shorthandType)
        for sourceFieldName in directFieldKeys
            if condition.Has(sourceFieldName)
                condition.Delete(sourceFieldName)
        if candidates.Length == 1 {
            condition["type"] := conditionType
            condition["field"] := candidates[1].Field
            condition["value"] := candidates[1].Value
            return true
        }

        children := []
        for candidate in candidates {
            child := Map("type", conditionType, "field", candidate.Field,
                "value", candidate.Value)
            for sharedField in ["operator", "case_sensitive"] {
                if condition.Has(sharedField)
                    child[sharedField] := condition[sharedField]
            }
            children.Push(child)
        }
        hasNegate := condition.Has("negate")
        negateValue := hasNegate ? condition["negate"] : ""
        condition.Clear()
        condition["type"] := "all"
        if hasNegate
            condition["negate"] := negateValue
        condition["conditions"] := children
        return true
    }

    GetAiConditionFieldNames(conditionType) {
        switch conditionType {
            case "application": return ["process", "path"]
            case "window": return ["title", "class", "hwnd"]
            case "input_source": return ["language_id"]
            case "session": return ["state"]
            default: return []
        }
    }

    IsAiConditionFieldName(fieldNames, candidate) {
        candidate := StrLower(Trim(String(candidate)))
        for fieldName in fieldNames {
            if candidate == fieldName
                return true
        }
        return false
    }

    NormalizeAiAction(action) {
        if Type(action) != "Map"
            return false
        this.MoveAiFieldIfUnambiguous(action, "repeatIntervalMs",
            "repeat_interval_ms")
        this.NormalizeAiActionType(action)
        this.NormalizeAiActionValueAlias(action)
        this.NormalizeAiActionShorthand(action)
        this.NormalizeAiIntegerField(action, "repeat_interval_ms")
        actionType := action.Has("type") && !IsObject(action["type"])
            ? StrLower(Trim(String(action["type"]))) : ""
        if actionType != ""
            action["type"] := actionType
        if (actionType == "window_minimize" || actionType == "window_close"
                || actionType == "lock_workstation")
                && action.Has("value")
                && this.IsAiCommandActionMarker(action["value"])
            action.Delete("value")
        if action.Has("repeat") && !IsObject(action["repeat"])
            action["repeat"] := StrLower(Trim(String(action["repeat"])))
        if action.Has("value") && Type(action["value"]) == "String" {
            if actionType == "key_down" || actionType == "key_up"
                action["value"] := this.NormalizeAiKeyName(action["value"])
            else if actionType == "send"
                action["value"] := this.NormalizeAiSendKeyTokens(
                    action["value"])
        }
        return true
    }

    NormalizeAiActionType(action) {
        if Type(action) != "Map" || !action.Has("type")
                || IsObject(action["type"])
            return false
        identity := StrLower(RegExReplace(Trim(String(action["type"])),
            "[\s_-]+"))
        static aliases := Map(
            "send", "send", "sendkeys", "send",
            "keydown", "key_down", "keyup", "key_up",
            "text", "text", "mouse", "mouse",
            "appcommand", "app_command", "sleep", "sleep",
            "delay", "sleep", "wait", "sleep",
            "windowminimize", "window_minimize",
            "minimizewindow", "window_minimize",
            "windowclose", "window_close",
            "closewindow", "window_close",
            "lockworkstation", "lock_workstation")
        if aliases.Has(identity) {
            action["type"] := aliases[identity]
            return true
        }
        return false
    }

    NormalizeAiActionValueAlias(action) {
        if Type(action) != "Map" || !action.Has("type")
                || IsObject(action["type"])
            return false
        actionType := StrLower(Trim(String(action["type"])))
        aliases := []
        switch actionType {
            case "send": aliases := ["send", "keys"]
            case "key_down": aliases := ["key_down", "key"]
            case "key_up": aliases := ["key_up", "key"]
            case "text": aliases := ["text", "content"]
            case "mouse": aliases := ["mouse", "command"]
            case "app_command": aliases := ["app_command", "command"]
            case "sleep": aliases := ["sleep", "milliseconds",
                "duration_ms", "durationMs", "delay_ms", "delayMs",
                "delay", "wait", "ms"]
        }
        changed := false
        for aliasName in aliases {
            if !action.Has(aliasName)
                continue
            aliasValue := action[aliasName]
            if action.Has("value") {
                if IsObject(action["value"]) || IsObject(aliasValue)
                        || String(action["value"]) != String(aliasValue)
                    continue
            } else
                action["value"] := aliasValue
            action.Delete(aliasName)
            changed := true
        }
        return changed
    }

    NormalizeAiActionShorthand(action) {
        explicitType := ""
        if action.Has("type") {
            if IsObject(action["type"])
                return false
            explicitType := StrLower(Trim(String(action["type"])))
        }
        shorthandKey := ""
        shorthandType := ""
        static shorthandTypes := Map(
            "send", "send", "send_keys", "send", "sendKeys", "send",
            "key_down", "key_down", "keyDown", "key_down",
            "key_up", "key_up", "keyUp", "key_up",
            "text", "text", "mouse", "mouse",
            "app_command", "app_command", "appCommand", "app_command",
            "sleep", "sleep",
            "delay", "sleep", "wait", "sleep",
            "window_minimize", "window_minimize",
            "windowMinimize", "window_minimize",
            "minimize_window", "window_minimize",
            "window_close", "window_close",
            "windowClose", "window_close",
            "close_window", "window_close",
            "lock_workstation", "lock_workstation",
            "lockWorkstation", "lock_workstation")
        for candidateKey, candidateType in shorthandTypes {
            if !action.Has(candidateKey)
                continue
            if shorthandType != ""
                return false
            shorthandKey := candidateKey
            shorthandType := candidateType
        }
        if shorthandType == "" || (explicitType != ""
                && explicitType != shorthandType)
            return false

        shorthandValue := action[shorthandKey]
        valueRequired := shorthandType != "window_minimize"
            && shorthandType != "window_close"
            && shorthandType != "lock_workstation"
        if valueRequired {
            if Type(shorthandValue) == "Map"
                    && shorthandValue.Count == 1
                    && shorthandValue.Has("value")
                shorthandValue := shorthandValue["value"]
            if action.Has("value") {
                if IsObject(action["value"]) || IsObject(shorthandValue)
                        || String(action["value"]) != String(shorthandValue)
                    return false
            } else
                action["value"] := shorthandValue
        } else if action.Has("value")
                || !this.IsAiCommandActionMarker(shorthandValue) {
            return false
        }
        action.Delete(shorthandKey)
        action["type"] := shorthandType
        return true
    }

    IsAiCommandActionMarker(value) {
        if value is JsonNull
            return true
        if value is JsonBoolean
            return value.Value
        if Type(value) == "String"
            return Trim(value) == ""
        return Type(value) == "Map" && value.Count == 0
    }

    NormalizeAiSendKeyTokens(value) {
        text := String(value)
        result := ""
        cursor := 1
        while matchPosition := RegExMatch(text,
                "\{([^{}\s]+)([^{}]*)\}", &token, cursor) {
            result .= SubStr(text, cursor, matchPosition - cursor)
            keyName := token[1]
            normalizedName := this.NormalizeAiKeyName(keyName)
            if normalizedName != keyName {
                resolvedName := ""
                try resolvedName := GetKeyName(normalizedName)
                if resolvedName != ""
                    keyName := normalizedName
            }
            result .= "{" keyName token[2] "}"
            cursor := matchPosition + token.Len(0)
        }
        return result SubStr(text, cursor)
    }

    MoveAiFieldIfUnambiguous(container, sourceKey, targetKey) {
        if Type(container) != "Map" || !container.Has(sourceKey)
            return false
        if container.Has(targetKey) {
            if !this.AreAiValuesEquivalent(container[sourceKey],
                    container[targetKey])
                return false
            container.Delete(sourceKey)
            return true
        }
        container[targetKey] := container[sourceKey]
        container.Delete(sourceKey)
        return true
    }

    AreAiValuesEquivalent(left, right) {
        if left is JsonBoolean {
            if right is JsonBoolean
                return left.Value == right.Value
            if IsObject(right)
                return false
            rightText := StrLower(Trim(String(right)))
            return rightText == (left.Value ? "true" : "false")
        }
        if right is JsonBoolean
            return this.AreAiValuesEquivalent(right, left)
        if IsObject(left) != IsObject(right)
            return false
        if !IsObject(left)
            return String(left) == String(right)
        try {
            return JsonCodec.Stringify(left, false, false)
                == JsonCodec.Stringify(right, false, false)
        } catch
            return false
    }

    NormalizeAiBooleanField(container, key) {
        if Type(container) != "Map" || !container.Has(key)
                || Type(container[key]) != "String"
            return false
        value := StrLower(Trim(container[key]))
        if value != "true" && value != "false"
            return false
        container[key] := JsonBoolean(value == "true")
        return true
    }

    NormalizeAiIntegerField(container, key) {
        if Type(container) != "Map" || !container.Has(key)
                || Type(container[key]) != "String"
            return false
        value := Trim(container[key])
        if !RegExMatch(value, "^-?\d+$")
            return false
        try container[key] := Integer(value)
        catch
            return false
        return true
    }

    CancelPresentationTimers() {
        if IsObject(this.FormatTimer)
            SetTimer(this.FormatTimer, 0)
        if IsObject(this.ScrollTimer)
            SetTimer(this.ScrollTimer, 0)
        return true
    }

    RequestClose(*) {
        if this.Disposed
            return
        if this.IsDirty() {
            if !this.Confirm(
                    Tr("代码修改尚未保存，确定放弃吗？"), Tr("放弃修改"),
                    Tr("放弃修改"), Tr("取消"), this.Gui)
                return
        }
        this.Dispose()
    }

    IsDirty() {
        return this.Canonicalize(this.GetCodeText()) != this.OriginalText
    }

    Confirm(message, title, confirmText, cancelText, ownerGui) {
        return !!this.ConfirmCallback.Call(message, title, confirmText,
            cancelText, ownerGui)
    }

    GetCodeText() {
        if this.TryGetCodeText(&text)
            return text
        if this.Disposed
            return ""
        throw Error("代码编辑器已经不可用。")
    }

    TryGetCodeText(&text) {
        text := ""
        if !this.IsLiveControl(this.CodeEditHwnd)
            return false
        try {
            text := ControlGetText(this.CodeEdit)
            this.EditorTextReadCount++
            return true
        } catch {
            return false
        }
    }

    TryGetCanonicalText(&text) {
        text := ""
        if this.CachedTextRevision == this.EditorRevision {
            text := this.CachedCanonicalText
            return true
        }
        if !this.TryGetCodeText(&rawText)
            return false
        text := this.Canonicalize(rawText)
        this.CachedCanonicalText := text
        this.CachedTextRevision := this.EditorRevision
        return true
    }

    IsLiveControl(hwnd) {
        return hwnd && DllCall("user32\IsWindow", "Ptr", hwnd, "Int")
    }

    SendControlMessage(message, wParam, lParam, hwnd, fallback := 0) {
        if !this.IsLiveControl(hwnd)
            return fallback
        try return SendMessage(message, wParam, lParam, , hwnd)
        catch
            return fallback
    }

    Canonicalize(text) {
        normalized := StrReplace(String(text), "`r`n", "`n")
        return StrReplace(normalized, "`r", "`n")
    }

    ResolveStartLine(mapping) {
        if !IsObject(mapping) || !mapping.HasOwnProp("StartLine")
            return 1
        try return Max(1, Integer(mapping.StartLine))
        catch
            return 1
    }

    GetLineCount(text) {
        StrReplace(String(text), "`n", "", false, &lineBreakCount)
        return lineBreakCount + 1
    }

    CalculateGutterWidth(lineCount) {
        lastLine := this.StartLine + Max(1, lineCount) - 1
        digitCount := StrLen(String(lastLine))
        return Max(48, 18 + digitCount * 9)
    }

    BuildLineNumberText(lineCount) {
        text := ""
        Loop lineCount
            text .= (A_Index == 1 ? "" : "`r`n")
                . (this.StartLine + A_Index - 1)
        return text
    }

    UpdateLineNumbers(text?, relayout := true) {
        if this.Disposed || !this.IsLiveControl(this.LineNumberEditHwnd)
            return false
        if !IsSet(text)
            if !this.TryGetCodeText(&text)
                return false
        lineCount := this.GetLineCount(text)
        newWidth := this.CalculateGutterWidth(lineCount)
        widthChanged := newWidth != this.GutterWidth
        if lineCount != this.LineNumberCount {
            this.LineNumberCount := lineCount
            this.LineNumberText := this.BuildLineNumberText(lineCount)
            gutterHwnd := this.LineNumberEditHwnd
            this.SendControlMessage(0x000B, 0, 0, gutterHwnd)
            try {
                if !this.IsLiveControl(gutterHwnd)
                    return false
                try ControlSetText(this.LineNumberText,
                    this.LineNumberEdit)
                catch
                    return false
                this.ApplyLineNumberAppearance()
            } finally {
                if this.IsLiveControl(gutterHwnd) {
                    this.SendControlMessage(0x000B, 1, 0, gutterHwnd)
                    DllCall("user32\InvalidateRect", "Ptr", gutterHwnd,
                        "Ptr", 0, "Int", 0)
                }
            }
        }
        if widthChanged {
            this.GutterWidth := newWidth
            if relayout
                this.RelayoutCurrentSize()
        }
        this.SyncLineNumberScroll()
        return true
    }

    ApplyLineNumberAppearance(*) {
        gutterHwnd := this.LineNumberEditHwnd
        if this.Disposed || !this.IsLiveControl(gutterHwnd)
            return false
        colors := MappingWindow.Colors
        selection := Buffer(8, 0)
        scrollPosition := Buffer(8, 0)
        this.SendControlMessage(0x0434, 0, selection.Ptr, gutterHwnd)
        this.SendControlMessage(0x04DD, 0, scrollPosition.Ptr, gutterHwnd)
        this.SendControlMessage(0x000B, 0, 0, gutterHwnd)
        try {
            this.SetRichTextFont(0, StrLen(this.LineNumberText),
                this.CodeFontName, 1, colors.CodeLineNumber,
                gutterHwnd)
        } finally {
            if this.IsLiveControl(gutterHwnd) {
                this.SendControlMessage(0x0437, 0, selection.Ptr,
                    gutterHwnd)
                this.SendControlMessage(0x000B, 1, 0, gutterHwnd)
                this.SendControlMessage(0x04DE, 0, scrollPosition.Ptr,
                    gutterHwnd)
                DllCall("user32\InvalidateRect", "Ptr", gutterHwnd,
                    "Ptr", 0, "Int", 0)
            }
        }
        return true
    }

    RefreshEditorPresentation(*) {
        if this.Disposed || this.ImeComposing
            return false
        if !this.TryGetCanonicalText(&text)
            return false
        this.UpdateLineNumbers(text)
        if this.LastFormattedRevision == this.EditorRevision
                && this.PendingFormatStart < 0
                && this.SyntaxLexer.Text == text
            return false
        return this.ApplyEditorTextFormatting(text)
    }

    RefreshEditorViewport(*) {
        if this.Disposed || this.ImeComposing
            return false
        return this.ApplyEditorFonts()
    }

    OnEditorWheelScroll(*) {
        if this.Disposed
            return false
        this.SyncLineNumberScroll()
        SetTimer(this.ScrollTimer, -1)
        return true
    }

    SyncLineNumberScroll(*) {
        codeHwnd := this.CodeEditHwnd
        gutterHwnd := this.LineNumberEditHwnd
        if this.Disposed || !this.IsLiveControl(codeHwnd)
                || !this.IsLiveControl(gutterHwnd)
            return false
        editorFirstLine := this.SendControlMessage(0x00CE, 0, 0, codeHwnd)
        gutterFirstLine := this.SendControlMessage(0x00CE, 0, 0,
            gutterHwnd)
        lineDelta := editorFirstLine - gutterFirstLine
        if lineDelta
            this.SendControlMessage(0x00B6, 0, lineDelta, gutterHwnd)
        return true
    }

    RelayoutCurrentSize() {
        if this.Disposed || !this.Gui
            return false
        try this.Gui.GetClientPos(, , &width, &height)
        catch
            return false
        this.OnResize(this.Gui, 0, width, height)
        return true
    }

    SetStatus(text, isError := false) {
        this.StatusIsError := !!isError
        this.Status.Text := text
        SendMessage(0x00B6, 0, -0x7FFF, , this.Status.Hwnd) ; EM_LINESCROLL
        this.AISettingsLinkHovered := false
        this.AISettingsLink.Visible := false
        this.Status.Visible := true
        this.Status.SetFont("c" (isError ? MappingWindow.Colors.Error
            : MappingWindow.Colors.Muted),
            LocalizationService.GetUiFontName())
        this.Interactions.HideTextInputCaret(this.Status.Hwnd)
        this.RelayoutCurrentSize()
        return true
    }

    SetAISettingsLink(text) {
        this.StatusIsError := true
        this.Status.Visible := false
        this.AISettingsLink.Text := text
        this.AISettingsLinkHovered := false
        this.AISettingsLink.Visible := true
        this.ApplyAISettingsLinkAppearance(false)
        this.RefreshAISettingsLinkBounds()
        this.RelayoutCurrentSize()
        return false
    }

    ApplyAISettingsLinkAppearance(hovered) {
        if !IsObject(this.AISettingsLink)
            return false
        options := "norm s10 c" MappingWindow.Colors.Error
        if hovered
            options .= " underline"
        this.AISettingsLink.SetFont(options,
            LocalizationService.GetUiFontName())
        return true
    }

    RefreshAISettingsLinkBounds() {
        if !IsObject(this.AISettingsLink)
            return false
        this.AISettingsLinkPreferredWidth :=
            this.MeasureControlTextWidth(this.AISettingsLink,
                this.AISettingsLink.Text) + 1
        try {
            this.Gui.GetClientPos(, , &clientWidth)
            availableWidth := Max(1, clientWidth - 336)
            this.AISettingsLink.GetPos(&x, &y, , &height)
            this.AISettingsLink.Move(x, y,
                Min(availableWidth, this.AISettingsLinkPreferredWidth),
                height)
        }
        return true
    }

    MeasureControlTextWidth(control, text) {
        text := String(text)
        if text == ""
            return 0
        deviceContext := DllCall("user32\GetDC", "Ptr", control.Hwnd,
            "Ptr")
        if !deviceContext
            return StrLen(text) * 12
        fontHandle := SendMessage(Win32.WM_GETFONT, 0, 0, , control.Hwnd)
        previousFont := fontHandle ? DllCall("gdi32\SelectObject", "Ptr",
            deviceContext, "Ptr", fontHandle, "Ptr") : 0
        extent := Buffer(8, 0)
        try {
            if !DllCall("gdi32\GetTextExtentPoint32W", "Ptr", deviceContext,
                    "Str", text, "Int", StrLen(text), "Ptr", extent,
                    "Int")
                return StrLen(text) * 12
            dpi := DllCall("user32\GetDpiForWindow", "Ptr", control.Hwnd,
                "UInt")
            if !dpi
                dpi := 96
            return Ceil(NumGet(extent, 0, "Int") * 96 / dpi)
        } finally {
            if previousFont
                DllCall("gdi32\SelectObject", "Ptr", deviceContext,
                    "Ptr", previousFont, "Ptr")
            DllCall("user32\ReleaseDC", "Ptr", control.Hwnd,
                "Ptr", deviceContext)
        }
    }

    OnAISettingsLinkMouse(wParam, lParam, msg, hwnd) {
        if this.Disposed || !IsObject(this.AISettingsLink)
                || hwnd != this.AISettingsLink.Hwnd
            return
        if msg == Win32.WM_MOUSEMOVE {
            if this.AISettingsLinkHovered
                return
            this.AISettingsLinkHovered := true
            this.ApplyAISettingsLinkAppearance(true)
            tracking := Buffer(A_PtrSize == 8 ? 24 : 16, 0)
            NumPut("UInt", tracking.Size, tracking, 0)
            NumPut("UInt", 0x00000002, tracking, 4) ; TME_LEAVE
            NumPut("Ptr", hwnd, tracking, 8)
            DllCall("user32\TrackMouseEvent", "Ptr", tracking, "Int")
            return
        }
        if msg == Win32.WM_MOUSELEAVE && this.AISettingsLinkHovered {
            this.AISettingsLinkHovered := false
            this.ApplyAISettingsLinkAppearance(false)
        }
    }

    OpenAISettings(*) {
        if this.Disposed
            return false
        return this.App.OpenAISettings(this)
    }

    OnSettingsClosed(window) {
        return this.OwnerWindow.OnSettingsClosed(window)
    }

    OnKeyDown(wParam, lParam, msg, hwnd) {
        if this.Disposed
            return
        rootHwnd := DllCall("user32\GetAncestor", "Ptr", hwnd,
            "UInt", 2, "Ptr")
        if rootHwnd != this.Gui.Hwnd
            return
        if wParam == 0x1B {
            this.RequestClose()
            return 0
        }
        if wParam == 0x09 && hwnd == this.CodeEdit.Hwnd {
            DllCall("user32\SendMessageW", "Ptr", this.CodeEdit.Hwnd,
                "UInt", 0x00C2, "Ptr", 1, "WStr", "`t", "Ptr")
            return 0
        }
        ctrlDown := GetKeyState("Ctrl", "P")
        shiftDown := GetKeyState("Shift", "P")
        altDown := GetKeyState("Alt", "P")
        if hwnd == this.CodeEdit.Hwnd {
            shortcutResult := this.HandleCodeEditorShortcut(wParam,
                ctrlDown, shiftDown, altDown)
            if shortcutResult >= 0
                return shortcutResult
        }
        if wParam == 0x53 && ctrlDown && !shiftDown && !altDown {
            this.Save()
            return 0
        }
    }

    HandleCodeEditorShortcut(wParam, ctrlDown, shiftDown, altDown) {
        if !ctrlDown || altDown
            return -1
        if wParam == 0x59 && !shiftDown { ; Ctrl+Y: delete line
            this.DeleteSelectedLines()
            return 0
        }
        if wParam == 0x5A && shiftDown { ; Ctrl+Shift+Z: redo
            this.SendControlMessage(0x0454, 0, 0,
                this.CodeEditHwnd) ; EM_REDO
            return 0
        }
        return -1
    }

    DeleteSelectedLines() {
        codeHwnd := this.CodeEditHwnd
        if this.Disposed || !this.IsLiveControl(codeHwnd)
            return false
        selection := Buffer(8, 0)
        this.SendControlMessage(0x0434, 0, selection.Ptr,
            codeHwnd) ; EM_EXGETSEL
        selectionStart := NumGet(selection, 0, "Int")
        selectionEnd := NumGet(selection, 4, "Int")
        firstLine := this.SendControlMessage(0x00C9,
            selectionStart, 0, codeHwnd) ; EM_LINEFROMCHAR
        endProbe := selectionEnd > selectionStart
            ? selectionEnd - 1 : selectionEnd
        lastLine := this.SendControlMessage(0x00C9,
            endProbe, 0, codeHwnd)
        if firstLine < 0 || lastLine < firstLine
            return false
        deleteStart := this.SendControlMessage(0x00BB,
            firstLine, 0, codeHwnd, -1) ; EM_LINEINDEX
        deleteEnd := this.SendControlMessage(0x00BB,
            lastLine + 1, 0, codeHwnd, -1)
        if deleteStart < 0
            return false
        if deleteEnd < 0 {
            deleteEnd := this.SendControlMessage(0x000E,
                0, 0, codeHwnd) ; WM_GETTEXTLENGTH
            ; Deleting the final line must also remove its preceding paragraph
            ; mark, otherwise Ctrl+Y leaves an unexpected blank last line.
            if deleteStart > 0
                deleteStart--
        }
        deleteSelection := Buffer(8, 0)
        NumPut("Int", deleteStart, deleteSelection, 0)
        NumPut("Int", Max(deleteStart, deleteEnd), deleteSelection, 4)
        this.SendControlMessage(0x0437, 0, deleteSelection.Ptr,
            codeHwnd) ; EM_EXSETSEL
        DllCall("user32\SendMessageW", "Ptr", codeHwnd,
            "UInt", 0x00C2, "Ptr", 1, "WStr", "", "Ptr") ; EM_REPLACESEL
        return true
    }

    OnCommand(wParam, lParam, msg, hwnd) {
        if this.Disposed || lParam != this.CodeEditHwnd
            return
        notificationCode := (wParam >> 16) & 0xFFFF
        if notificationCode == 0x0300 {
            if this.Formatting || this.SuppressEditorChange
                return
            this.EditorRevision++
            this.CachedTextRevision := -1
            this.LastFormattedRevision := -1
            if !this.ImeComposing
                SetTimer(this.FormatTimer, -140)
            return
        }
        if notificationCode == 0x0601 || notificationCode == 0x0602 {
            if this.Formatting || this.ImeComposing
                return
            this.SyncLineNumberScroll()
            SetTimer(this.ScrollTimer, -120)
        }
    }

    OnImeComposition(wParam, lParam, msg, hwnd) {
        if this.Disposed || hwnd != this.CodeEditHwnd
            return
        if msg == 0x010D {
            this.ImeComposing := true
            this.CancelPresentationTimers()
            return
        }
        if msg == 0x010E {
            this.ImeComposing := false
            ; RichEdit may coalesce EN_CHANGE while an IME owns composition.
            ; The composition boundary is authoritative: force the next pass
            ; to read the committed text instead of reusing the old snapshot.
            this.EditorRevision++
            this.CachedTextRevision := -1
            this.LastFormattedRevision := -1
            SetTimer(this.FormatTimer, -140)
        }
    }

    ResolveCodeFontName() {
        for fontName in ["JetBrains Mono", "Cascadia Mono", "Consolas"] {
            if LocalizationService.IsFontInstalled(fontName)
                return fontName
        }
        return LocalizationService.GetUiFontName()
    }

    ApplyEditorFonts(fullDocument := false, *) {
        if this.Disposed || this.Formatting || this.ImeComposing
            return false
        if fullDocument {
            if !this.TryGetCodeText(&rawText)
                return false
            text := this.Canonicalize(rawText)
            this.CachedCanonicalText := text
            this.CachedTextRevision := this.EditorRevision
        } else if !this.TryGetCanonicalText(&text) {
            return false
        }
        return this.ApplyEditorTextFormatting(text, fullDocument)
    }

    ApplyEditorTextFormatting(text, fullDocument := false,
            manageRedraw := true) {
        codeHwnd := this.CodeEditHwnd
        if this.Disposed || this.Formatting || this.ImeComposing
                || !this.IsLiveControl(codeHwnd)
            return false
        this.SyntaxLexer.Update(text)
        changedRange := this.SyntaxLexer.GetLastChangedRange()
        if changedRange.End > changedRange.Start {
            if this.PendingFormatStart < 0 {
                this.PendingFormatStart := changedRange.Start
                this.PendingFormatEnd := changedRange.End
            } else {
                this.PendingFormatStart := Min(this.PendingFormatStart,
                    changedRange.Start)
                this.PendingFormatEnd := Max(this.PendingFormatEnd,
                    changedRange.End)
            }
        }
        if fullDocument
            detailRange := this.GetFormatRange(text, true)
        else if this.PendingFormatStart >= 0
            detailRange := {Start: this.PendingFormatStart,
                End: this.PendingFormatEnd}
        else
            detailRange := this.GetFormatRange(text, false)
        baseRange := detailRange
        if !fullDocument
                && this.LastFormattedRevision == this.EditorRevision
                && detailRange.Start >= this.LastFormattedStart
                && detailRange.End <= this.LastFormattedEnd
            return false
        this.Formatting := true
        selection := Buffer(8, 0)
        scrollPosition := Buffer(8, 0)
        completed := false
        undoDocument := this.SuspendRichEditUndo(codeHwnd)
        this.SendControlMessage(0x0434, 0, selection.Ptr, codeHwnd)
        this.SendControlMessage(0x04DD, 0, scrollPosition.Ptr, codeHwnd)
        if manageRedraw
            this.SendControlMessage(0x000B, 0, 0, codeHwnd)
        try {
            ; WM_GETTEXT 返回 CRLF，而 RichEdit 选区把每个段落标记计为一个字符。
            ; 先折叠换行，避免中文字体选区随行数逐行向后偏移。
            if !this.SetRichTextFont(baseRange.Start, baseRange.End,
                    this.CodeFontName, 1, "", codeHwnd)
                return false
            spacingRange := fullDocument
                ? {Start: 0, End: StrLen(text)} : baseRange
            this.ApplySynchronizedLineSpacing(spacingRange)
            rangeText := SubStr(text, detailRange.Start + 1,
                detailRange.End - detailRange.Start)
            position := 1
            cjkPattern := "[\x{2E80}-\x{2FFF}\x{3000}-\x{303F}"
                . "\x{3400}-\x{4DBF}\x{4E00}-\x{9FFF}"
                . "\x{F900}-\x{FAFF}\x{FF00}-\x{FFEF}]+"
            while RegExMatch(rangeText, cjkPattern, &cjkMatch, position) {
                if this.Disposed || !this.IsLiveControl(codeHwnd)
                    return false
                startPosition := detailRange.Start + cjkMatch.Pos(0) - 1
                endPosition := startPosition + cjkMatch.Len(0)
                this.SetRichTextFont(startPosition, endPosition,
                    this.CjkFontName, 134)
                position := cjkMatch.Pos(0) + cjkMatch.Len(0)
            }
            this.ApplySyntaxHighlighting(text, detailRange)
            completed := this.IsLiveControl(codeHwnd) && !this.Disposed
            return completed
        } finally {
            try {
                if this.IsLiveControl(codeHwnd) {
                    this.SendControlMessage(0x0437, 0, selection.Ptr,
                        codeHwnd)
                    if manageRedraw
                        this.SendControlMessage(0x000B, 1, 0, codeHwnd)
                    this.SendControlMessage(0x04DE, 0,
                        scrollPosition.Ptr, codeHwnd)
                    if manageRedraw
                        DllCall("user32\InvalidateRect", "Ptr", codeHwnd,
                            "Ptr", 0, "Int", 0)
                }
                this.Formatting := false
                if completed {
                    this.LastFormattedRevision := this.EditorRevision
                    this.LastFormattedStart := detailRange.Start
                    this.LastFormattedEnd := detailRange.End
                    this.PendingFormatStart := -1
                    this.PendingFormatEnd := -1
                    this.FormattingPassCount++
                }
                if !this.Disposed
                    this.SyncLineNumberScroll()
            } finally this.ResumeRichEditUndo(undoDocument)
        }
    }

    SuspendRichEditUndo(controlHwnd) {
        document := this.GetRichEditTextDocument(controlHwnd)
        if !document
            return 0
        affectedActions := 0
        try {
            ; ITextDocument::Undo(tomSuspend) keeps syntax-only character and
            ; paragraph formatting out of the user's native undo history.
            if ComCall(22, document, "Int", -9999995,
                    "Int*", &affectedActions, "Int") < 0 {
                this.ReleaseComInterface(document)
                return 0
            }
            return document
        } catch {
            this.ReleaseComInterface(document)
            return 0
        }
    }

    ResumeRichEditUndo(document) {
        if !document
            return true
        affectedActions := 0
        resumed := false
        try resumed := ComCall(22, document, "Int", -9999994,
            "Int*", &affectedActions, "Int") >= 0
        catch
            resumed := false
        finally this.ReleaseComInterface(document)
        return resumed
    }

    GetRichEditTextDocument(controlHwnd) {
        if !this.IsLiveControl(controlHwnd)
            return 0
        richEditOleBuffer := Buffer(A_PtrSize, 0)
        if !this.SendControlMessage(0x043C, 0, richEditOleBuffer.Ptr,
                controlHwnd) ; EM_GETOLEINTERFACE
            return 0
        richEditOle := NumGet(richEditOleBuffer, 0, "Ptr")
        if !richEditOle
            return 0
        document := 0
        iid := Buffer(16, 0)
        try {
            if DllCall("ole32\CLSIDFromString", "WStr",
                    "{8CC497C0-A1DF-11CE-8098-00AA0047BE5D}",
                    "Ptr", iid.Ptr, "Int") < 0
                return 0
            vtable := NumGet(richEditOle, 0, "Ptr")
            queryInterface := NumGet(vtable, 0, "Ptr")
            if DllCall(queryInterface, "Ptr", richEditOle, "Ptr", iid.Ptr,
                    "Ptr*", &document, "Int") < 0
                return 0
            return document
        } finally this.ReleaseComInterface(richEditOle)
    }

    ReleaseComInterface(interfacePointer) {
        if !interfacePointer
            return 0
        vtable := NumGet(interfacePointer, 0, "Ptr")
        release := NumGet(vtable, 2 * A_PtrSize, "Ptr")
        return DllCall(release, "Ptr", interfacePointer, "UInt")
    }

    ApplySyntaxHighlighting(text, formatRange) {
        colors := MappingWindow.Colors
        tokens := this.SyntaxLexer.GetTokens(text, formatRange.Start,
            formatRange.End)
        for token in tokens {
            if this.Disposed || !this.IsLiveControl(this.CodeEditHwnd)
                return false
            color := this.ResolveSyntaxColor(token.Kind, colors)
            if color != ""
                this.SetSyntaxColor(token.Start, token.End, color,
                    formatRange)
        }
        return true
    }

    ApplySynchronizedLineSpacing(formatRange) {
        codeHwnd := this.CodeEditHwnd
        gutterHwnd := this.LineNumberEditHwnd
        if !this.IsLiveControl(codeHwnd)
                || !this.IsLiveControl(gutterHwnd)
            return false
        firstLine := this.SendControlMessage(0x00C9,
            formatRange.Start, 0, codeHwnd) ; EM_LINEFROMCHAR
        lastCharacter := Max(formatRange.Start, formatRange.End - 1)
        lastLine := this.SendControlMessage(0x00C9,
            lastCharacter, 0, codeHwnd)
        if firstLine < 0 || lastLine < firstLine
            return false
        codeStart := this.SendControlMessage(0x00BB, firstLine, 0,
            codeHwnd, -1) ; EM_LINEINDEX
        codeEnd := this.SendControlMessage(0x00BB, lastLine + 1, 0,
            codeHwnd, -1)
        gutterStart := this.SendControlMessage(0x00BB, firstLine, 0,
            gutterHwnd, -1)
        gutterEnd := this.SendControlMessage(0x00BB, lastLine + 1, 0,
            gutterHwnd, -1)
        if codeStart < 0 || gutterStart < 0
            return false
        if codeEnd < 0
            codeEnd := this.SendControlMessage(0x000E, 0, 0, codeHwnd)
        if gutterEnd < 0
            gutterEnd := this.SendControlMessage(0x000E, 0, 0,
                gutterHwnd)
        gutterSelection := Buffer(8, 0)
        gutterScroll := Buffer(8, 0)
        this.SendControlMessage(0x0434, 0, gutterSelection.Ptr,
            gutterHwnd)
        this.SendControlMessage(0x04DD, 0, gutterScroll.Ptr,
            gutterHwnd)
        try {
            codeApplied := this.SetRichTextLineSpacing(codeStart,
                codeEnd, codeHwnd)
            gutterApplied := this.SetRichTextLineSpacing(gutterStart,
                gutterEnd, gutterHwnd)
            return codeApplied && gutterApplied
        } finally {
            if this.IsLiveControl(gutterHwnd) {
                this.SendControlMessage(0x0437, 0,
                    gutterSelection.Ptr, gutterHwnd)
                this.SendControlMessage(0x04DE, 0,
                    gutterScroll.Ptr, gutterHwnd)
            }
        }
    }

    ResolveSyntaxColor(kind, colors) {
        switch kind {
            case "Comment": return colors.CodeComment
            case "CommentTag": return colors.CodeDirective
            case "MetadataKey": return colors.CodeVariable
            case "MetadataValue": return colors.CodeValue
            case "Identifier": return colors.CodeVariable
            case "Keyword": return colors.CodeKeyword
            case "Directive": return colors.CodeDirective
            case "DirectiveValue": return colors.CodeString
            case "String": return colors.CodeString
            case "Number": return colors.CodeNumber
            case "Function": return colors.CodeFunction
            case "Type": return colors.CodeType
            case "Property": return colors.CodeProperty
            case "Operator": return colors.CodeOperator
            case "Punctuation": return colors.CodePunctuation
            case "Hotkey": return colors.CodeHotkey
            case "Hotstring": return colors.CodeHotkey
            case "Label": return colors.CodeLabel
            case "Builtin": return colors.CodeBuiltin
            case "Literal": return colors.CodeLiteral
            case "Escape": return colors.CodeEscape
            default: return ""
        }
    }

    SetSyntaxColor(startPosition, endPosition, color, formatRange) {
        clippedStart := Max(startPosition, formatRange.Start)
        clippedEnd := Min(endPosition, formatRange.End)
        if clippedEnd <= clippedStart
            return false
        return this.SetRichTextColor(clippedStart, clippedEnd, color)
    }

    GetFormatRange(text, fullDocument) {
        textLength := StrLen(text)
        ; A forced refresh must always reread and re-lex the complete text,
        ; but formatting a large document token by token would block the GUI
        ; thread during paste, resize, and theme changes. Small documents keep
        ; full-document highlighting; large ones are detailed by viewport and
        ; receive the remaining colors as the user scrolls.
        if fullDocument
                && textLength
                    <= MappingBlockEditor.DetailedFormattingMaximumCharacters
            return {Start: 0, End: textLength}
        codeHwnd := this.CodeEditHwnd
        if !this.IsLiveControl(codeHwnd)
            return {Start: 0, End: 0}
        firstLine := this.SendControlMessage(0x00CE, 0, 0, codeHwnd)
        startPosition := this.SendControlMessage(0x00BB, firstLine, 0,
            codeHwnd, -1)
        endPosition := this.SendControlMessage(0x00BB,
            firstLine + MappingBlockEditor.DetailedFormattingVisibleLines,
            0, codeHwnd, -1)
        if startPosition < 0
            startPosition := 0
        if endPosition < 0
            endPosition := startPosition
                + MappingBlockEditor.DetailedFormattingMaximumCharacters
        else
            endPosition := Min(endPosition, startPosition
                + MappingBlockEditor.DetailedFormattingMaximumCharacters)
        return {Start: Min(textLength, startPosition),
            End: Min(textLength, Max(startPosition, endPosition))}
    }

    SetRichTextFont(startPosition, endPosition, faceName, characterSet,
        color := "", controlHwnd := 0) {
        if color == ""
            color := MappingWindow.Colors.Text
        if !controlHwnd
            controlHwnd := this.CodeEditHwnd
        if !this.IsLiveControl(controlHwnd)
            return false
        selection := Buffer(8, 0)
        NumPut("Int", startPosition, selection, 0)
        NumPut("Int", endPosition, selection, 4)
        this.SendControlMessage(0x0437, 0, selection.Ptr, controlHwnd)
        characterFormat := Buffer(116, 0)
        NumPut("UInt", 116, characterFormat, 0)
        ; CFM_SIZE | CFM_COLOR | CFM_FACE | CFM_CHARSET | CFM_WEIGHT |
        ; CFM_BOLD。显式清除粗体并固定 400 字重，避免继承 GUI 标题字体。
        NumPut("UInt", 0xE8400001, characterFormat, 4)
        NumPut("UInt", 0, characterFormat, 8)
        NumPut("Int", 13 * 20, characterFormat, 12)
        NumPut("UInt", ColorRef(color), characterFormat, 20)
        NumPut("UChar", characterSet, characterFormat, 24)
        StrPut(faceName, characterFormat.Ptr + 26, 32, "UTF-16")
        NumPut("UShort", 400, characterFormat, 90)
        return !!this.SendControlMessage(0x0444, 1,
            characterFormat.Ptr, controlHwnd)
    }

    SetRichTextColor(startPosition, endPosition, color) {
        codeHwnd := this.CodeEditHwnd
        if !this.IsLiveControl(codeHwnd)
            return false
        selection := Buffer(8, 0)
        NumPut("Int", startPosition, selection, 0)
        NumPut("Int", endPosition, selection, 4)
        this.SendControlMessage(0x0437, 0, selection.Ptr, codeHwnd)
        colorKey := StrUpper(String(color))
        if !this.RichTextColorFormats.Has(colorKey) {
            characterFormat := Buffer(116, 0)
            NumPut("UInt", 116, characterFormat, 0)
            NumPut("UInt", 0x40000000, characterFormat, 4) ; CFM_COLOR
            NumPut("UInt", ColorRef(colorKey), characterFormat, 20)
            this.RichTextColorFormats[colorKey] := characterFormat
        }
        characterFormat := this.RichTextColorFormats[colorKey]
        return !!this.SendControlMessage(0x0444, 1,
            characterFormat.Ptr, codeHwnd)
    }

    SetRichTextLineSpacing(startPosition, endPosition,
            controlHwnd := 0) {
        if !controlHwnd
            controlHwnd := this.CodeEditHwnd
        if !this.IsLiveControl(controlHwnd)
            return false
        selection := Buffer(8, 0)
        NumPut("Int", startPosition, selection, 0)
        NumPut("Int", Max(startPosition, endPosition), selection, 4)
        this.SendControlMessage(0x0437, 0, selection.Ptr, controlHwnd)
        paragraphFormat := Buffer(188, 0) ; PARAFORMAT2
        NumPut("UInt", paragraphFormat.Size, paragraphFormat, 0)
        NumPut("UInt", 0x00000100, paragraphFormat, 4) ; PFM_LINESPACING
        NumPut("Int", MappingBlockEditor.EditorLineSpacingTwips,
            paragraphFormat, 164)
        NumPut("UChar", 4, paragraphFormat, 170) ; 精确 twips 行距
        return !!this.SendControlMessage(0x0447, 0,
            paragraphFormat.Ptr, controlHwnd) ; EM_SETPARAFORMAT
    }

    OnResize(guiObj, minMax, width, height) {
        if minMax == -1 || this.Disposed || width <= 0 || height <= 0
            return
        layoutRound := AtomicControlLayout.BeginRound(this.Gui)
        if !IsObject(layoutRound)
            return false
        contentWidth := Max(612, width - 28)
        entries := []
        titleWidth := contentWidth
        if this.IsNew && IsObject(this.ManagedModeButton) {
            scriptModeX := width - MappingBlockEditor.ModeSelectorRightMargin
                - this.ModeButtonWidth
            managedModeX := scriptModeX - MappingBlockEditor.ModeButtonGap
                - this.ModeButtonWidth
            titleWidth := Max(220, managedModeX - 22)
            entries.Push({Control: this.ManagedModeButton,
                X: managedModeX, Y: 10,
                Width: this.ModeButtonWidth, Height: 30})
            entries.Push({Control: this.ScriptModeButton,
                X: scriptModeX, Y: 10,
                Width: this.ModeButtonWidth, Height: 30})
        }
        titleHeight := this.GetTitleHeight(titleWidth, layoutRound)
        codeEditorTop := this.GetCodeEditorTop(titleWidth, layoutRound)
        entries.Push({Control: this.Title, X: 14,
            Y: MappingBlockEditor.TitleTop,
            Width: titleWidth, Height: titleHeight})
        commandY := height - 48
        aiButtonX := width - 182 - MappingBlockEditor.AIButtonGap
            - MappingBlockEditor.AIButtonWidth
        statusLayout := this.GetStatusLayout(height, aiButtonX,
            codeEditorTop, layoutRound)
        editorHeight := statusLayout.EditorHeight
        for entry in this.BuildCodeEditorLayoutEntries(14,
                codeEditorTop,
                contentWidth, editorHeight)
            entries.Push(entry)
        entries.Push({Control: this.AiButton, X: aiButtonX,
            Y: commandY, Width: MappingBlockEditor.AIButtonWidth, Height: 32})
        entries.Push({Control: this.SaveButton, X: width - 182,
            Y: commandY, Width: 80, Height: 32})
        entries.Push({Control: this.CancelButton, X: width - 94,
            Y: commandY, Width: 80, Height: 32})
        statusWidth := statusLayout.Width
        entries.Push({Control: this.Status, X: 14, Y: statusLayout.Y,
            Width: statusWidth, Height: statusLayout.Height})
        entries.Push({Control: this.AISettingsLink, X: 14,
            Y: commandY + 6,
            Width: Min(statusWidth, this.AISettingsLinkPreferredWidth),
            Height: 24})
        signature := layoutRound.Dpi "|" width "|" height "|"
            . contentWidth "|" editorHeight
            . "|" titleWidth "|" titleHeight "|" codeEditorTop
            . "|" this.GutterWidth "|" this.IsNew
            . "|" this.EditorMode "|" statusLayout.Height
            . "|" LocalizationService.GetLanguage()
        richEditRedrawSuspended := signature != this.LastLayoutSignature
            ? this.SuspendResizeRichEditRedraw() : ""
        try {
            result := AtomicControlLayout.Apply(this.Gui, entries, {
                ParentColor: MappingWindow.Colors.Window, ClearMargin: 2,
                Round: layoutRound
            })
            this.LastLayoutResult := result
            if result.Status == AtomicControlLayout.Applied && result.Changed
                this.LastChangedLayoutResult := result
            if result.Status == AtomicControlLayout.Applied
                    && !this.Disposed && IsObject(this.ScrollTimer)
                SetTimer(this.ScrollTimer, -120)
            if result.Status == AtomicControlLayout.Applied
                    || result.Status == AtomicControlLayout.Unchanged
                this.LastLayoutSignature := signature
            if result.Status == AtomicControlLayout.Applied
                    || result.Status == AtomicControlLayout.Unchanged {
                SetMultilineEditPadding(this.Status.Hwnd, 1, 2, 1, 2)
                this.Interactions.HideTextInputCaret(this.Status.Hwnd)
            }
            if result.Status == AtomicControlLayout.Applied && result.Changed
                this.RefreshCommandButtons()
            return result
        } finally this.ResumeResizeRichEditRedraw(richEditRedrawSuspended)
    }

    RefreshCommandButtons(*) {
        for button in [this.AiButton, this.SaveButton, this.CancelButton]
            if IsObject(button) && button.Hwnd
                this.Interactions.Redraw(button.Hwnd)
        return true
    }

    GetTitleHeight(width, layoutRound := "") {
        textHeight := this.Interactions.Painter.MeasureTextHeight(
            this.Title, this.Title.Text, width, 0, 0, layoutRound)
        return Max(MappingBlockEditor.TitleMinimumHeight, textHeight)
    }

    GetCodeEditorTop(titleWidth, layoutRound := "") {
        return MappingBlockEditor.TitleTop
            + this.GetTitleHeight(titleWidth, layoutRound)
            + MappingBlockEditor.TitleBottomGap
    }

    GetStatusLayout(height, aiButtonX, codeEditorTop := "",
            layoutRound := "") {
        statusWidth := Max(280, aiButtonX - 26)
        statusHeight := 24
        if this.Status.Visible && this.Status.Text != "" {
            textHeight := this.Interactions.Painter.MeasureTextHeight(
                this.Status, this.Status.Text, statusWidth, 1, 0, layoutRound)
            statusHeight := Max(statusHeight, textHeight + 4)
        }
        statusBottom := height - 18
        if codeEditorTop == ""
            codeEditorTop := MappingBlockEditor.CodeEditorTop
        maximumHeight := Max(24, statusBottom - (codeEditorTop + 260 + 8))
        statusHeight := Min(statusHeight, maximumHeight)
        statusY := statusBottom - statusHeight
        editorBottom := Min(height - 66, statusY - 8)
        return {
            Width: statusWidth,
            Height: statusHeight,
            Y: statusY,
            EditorHeight: Max(260, editorBottom - codeEditorTop)
        }
    }

    SuspendResizeRichEditRedraw() {
        if this.Disposed
            return false
        return AtomicControlRedrawTransaction.Begin(
            [this.LineNumberEdit, this.CodeEdit])
    }

    ResumeResizeRichEditRedraw(transaction) {
        return AtomicControlRedrawTransaction.End(transaction)
    }

    BuildCodeEditorLayoutEntries(x, y, width, height) {
        separatorWidth := MappingBlockEditor.GutterSeparatorWidth
        codeX := x + this.GutterWidth + separatorWidth
        codeWidth := Max(240, width - this.GutterWidth - separatorWidth)
        return [
            {Control: this.LineNumberEdit, X: x, Y: y,
                Width: this.GutterWidth, Height: height},
            {Control: this.LineNumberDivider, X: x + this.GutterWidth,
                Y: y, Width: separatorWidth, Height: height},
            {Control: this.CodeEdit, X: codeX, Y: y,
                Width: codeWidth, Height: height}
        ]
    }

    OnNativeDestroy(wParam, lParam, msg, hwnd) {
        if !this.EditorHwnd || hwnd != this.EditorHwnd
            return
        if msg == 0x0002 {
            this.BeginNativeDestroy()
            return
        }
        if msg == 0x0082 && this.NativeDestroying
            SetTimer(this.NativeFinalizeTimer, -1)
    }

    BeginNativeDestroy() {
        if this.Disposed
            return
        if this.AiRequestId
                && this.OwnerWindow.App.HasOwnProp("AIService")
                && IsObject(this.OwnerWindow.App.AIService) {
            requestId := this.AiRequestId
            this.AiRequestId := 0
            this.AiBusy := false
            try this.OwnerWindow.App.AIService.Cancel(requestId)
        }
        this.Disposed := true
        this.NativeDestroying := true
        this.NativeCleanup := CleanupCollector("映射代码编辑器")
        if this.OwnerLease
            this.NativeCleanup.Run("释放父窗口关系", () =>
                this.NativeCloseContext := this.ReleaseOwner())
        this.NativeCallbacksReleased := this.StopEditorCallbacks(false,
            this.NativeCleanup)
    }

    FinishNativeDestroy(*) {
        if !this.NativeDestroying
            return
        this.NativeDestroying := false
        closeContext := this.NativeCloseContext
        this.NativeCloseContext := ""
        cleanup := IsObject(this.NativeCleanup) ? this.NativeCleanup
            : CleanupCollector("映射代码编辑器")
        this.NativeCleanup := ""
        finalCallbacksReleased := this.StopEditorCallbacks(true, cleanup)
        callbacksReleased := this.NativeCallbacksReleased
            && finalCallbacksReleased
        if IsObject(this.Interactions)
                && cleanup.Run("释放交互服务",
                    () => this.Interactions.Dispose())
            this.Interactions := ""
        this.Gui := ""
        this.EditorHwnd := 0
        this.CodeEditHwnd := 0
        this.LineNumberEditHwnd := 0
        cleanup.Run("释放 RichEdit 模块",
            () => this.ReleaseRichEditModule())
        if this.HasOwnProp("IconHandles") {
            if cleanup.Run("释放窗口图标", () =>
                    ReleaseApplicationWindowIcons(this.IconHandles))
                this.IconHandles := []
        }
        if callbacksReleased
            this.ReleaseCallbackReferences()
        this.AiButton := ""
        this.AISettingsLink := ""
        cleanup.Run("通知父窗口",
            () => this.OwnerWindow.OnBlockEditorClosed(this))
        cleanup.Run("恢复父窗口",
            () => WindowHierarchy.CompleteClose(closeContext))
        cleanup.Complete()
    }

    StopEditorCallbacks(includeNativeDestroy := true, cleanup := "") {
        ownsCleanup := !IsObject(cleanup)
        if ownsCleanup
            cleanup := CleanupCollector("映射代码编辑器回调")
        initialFailures := cleanup.Failures.Length
        if IsObject(this.FormatTimer)
            cleanup.Run("停止格式计时器",
                () => SetTimer(this.FormatTimer, 0))
        if IsObject(this.ScrollTimer)
            cleanup.Run("停止滚动计时器",
                () => SetTimer(this.ScrollTimer, 0))
        if IsObject(this.KeyDownCallback)
            cleanup.Run("注销按键消息",
                () => OnMessage(0x0100, this.KeyDownCallback, 0))
        if IsObject(this.ImeCompositionCallback) {
            cleanup.Run("注销输入法开始消息",
                () => OnMessage(0x010D, this.ImeCompositionCallback, 0))
            cleanup.Run("注销输入法结束消息",
                () => OnMessage(0x010E, this.ImeCompositionCallback, 0))
        }
        if IsObject(this.CommandCallback)
            cleanup.Run("注销命令消息",
                () => OnMessage(0x0111, this.CommandCallback, 0))
        if IsObject(this.AISettingsLinkMouseCallback) {
            cleanup.Run("注销 AI 设置链接鼠标移动消息", () =>
                OnMessage(Win32.WM_MOUSEMOVE,
                    this.AISettingsLinkMouseCallback, 0))
            cleanup.Run("注销 AI 设置链接鼠标离开消息", () =>
                OnMessage(Win32.WM_MOUSELEAVE,
                    this.AISettingsLinkMouseCallback, 0))
        }
        if includeNativeDestroy && IsObject(this.NativeDestroyCallback) {
            cleanup.Run("注销销毁消息",
                () => OnMessage(0x0002, this.NativeDestroyCallback, 0))
            cleanup.Run("注销最终销毁消息",
                () => OnMessage(0x0082, this.NativeDestroyCallback, 0))
            cleanup.Run("停止销毁完成计时器",
                () => SetTimer(this.NativeFinalizeTimer, 0))
        }
        succeeded := cleanup.Failures.Length == initialFailures
        if ownsCleanup
            cleanup.Complete()
        return succeeded
    }

    ReleaseCallbackReferences() {
        this.NativeFinalizeTimer := ""
        this.FormatTimer := ""
        this.ScrollTimer := ""
        this.CommandCallback := ""
        this.AISettingsLinkMouseCallback := ""
        this.KeyDownCallback := ""
        this.ImeCompositionCallback := ""
        this.NativeDestroyCallback := ""
    }

    ReleaseRichEditModule() {
        if this.RichEditModule {
            if !DllCall("kernel32\FreeLibrary", "Ptr", this.RichEditModule,
                    "Int")
                throw OSError(A_LastError, "无法释放 RichEdit 模块。")
            this.RichEditModule := 0
        }
        return true
    }

    ReleaseOwner() {
        if !this.OwnerLease
            return ""
        ownerLease := this.OwnerLease
        closeContext := WindowHierarchy.Release(ownerLease)
        this.OwnerLease := ""
        return closeContext
    }

    Dispose(activateOwner := true) {
        if this.Disposed {
            if !IsObject(this.Gui)
                return
            try editorStillAlive := DllCall("user32\IsWindow", "Ptr",
                this.Gui.Hwnd, "Int") != 0
            catch
                editorStillAlive := false
            if !editorStillAlive
                return
        }
        this.Disposed := true
        cleanup := CleanupCollector("映射代码编辑器")
        if this.AiRequestId
                && this.OwnerWindow.App.HasOwnProp("AIService")
                && IsObject(this.OwnerWindow.App.AIService) {
            requestId := this.AiRequestId
            this.AiRequestId := 0
            this.AiBusy := false
            cleanup.Run("取消 AI 请求",
                () => this.OwnerWindow.App.AIService.Cancel(requestId))
        }
        closeContext := ""
        if this.OwnerLease {
            try closeContext := this.ReleaseOwner()
            catch as ownerError
                cleanup.Failures.Push("释放父窗口关系：" ownerError.Message)
        }
        callbacksReleased := this.StopEditorCallbacks(true, cleanup)
        if IsObject(this.Interactions)
                && cleanup.Run("释放交互服务",
                    () => this.Interactions.Dispose())
            this.Interactions := ""
        guiReleased := !this.Gui
        if this.Gui {
            editorHwnd := 0
            try editorHwnd := this.Gui.Hwnd
            catch as hwndError
                cleanup.Failures.Push("读取窗口句柄：" hwndError.Message)
            if !editorHwnd || !DllCall("user32\IsWindow", "Ptr",
                    editorHwnd, "Int")
                guiReleased := true
            else
                guiReleased := cleanup.Run("销毁窗口",
                    () => this.Gui.Destroy())
        }
        if guiReleased {
            this.Gui := ""
            this.EditorHwnd := 0
            this.CodeEditHwnd := 0
            this.LineNumberEditHwnd := 0
            cleanup.Run("释放 RichEdit 模块",
                () => this.ReleaseRichEditModule())
            if this.HasOwnProp("IconHandles") {
                if cleanup.Run("释放窗口图标", () =>
                        ReleaseApplicationWindowIcons(this.IconHandles))
                    this.IconHandles := []
            }
        }
        if callbacksReleased
            this.ReleaseCallbackReferences()
        this.AiButton := ""
        this.AISettingsLink := ""
        if guiReleased {
            cleanup.Run("通知父窗口",
                () => this.OwnerWindow.OnBlockEditorClosed(this))
            if activateOwner
                cleanup.Run("恢复父窗口",
                    () => WindowHierarchy.CompleteClose(closeContext))
        }
        cleanup.Complete()
        return true
    }
}
