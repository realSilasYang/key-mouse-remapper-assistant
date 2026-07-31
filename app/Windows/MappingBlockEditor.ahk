class MappingBlockEditor {
    static NewEditorWidth := 1040
    static NewEditorHeight := 600
    static NewEditorMinimumWidth := 880
    static NewEditorMinimumHeight := 500
    static EditEditorWidth := 780
    static EditEditorHeight := 560
    static EditEditorMinimumWidth := 640
    static EditEditorMinimumHeight := 440
    static MetadataPanelWidth := 326
    static MetadataPanelGap := 20
    static GutterSeparatorWidth := 1

    __New(ownerWindow, mapping, isNew := false) {
        this.OwnerWindow := ownerWindow
        this.IsNew := isNew
        this.MappingId := isNew ? "" : mapping.Id
        this.OriginalText := this.Canonicalize(mapping.Block)
        this.StartLine := this.ResolveStartLine(mapping)
        this.Disposed := false
        this.Formatting := false
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
        this.KeyDownCallback := ""
        this.NativeDestroyCallback := ""
        this.CodeEditHwnd := 0
        this.LineNumberEditHwnd := 0
        this.LineNumberCount := 0
        this.GutterWidth := this.CalculateGutterWidth(
            this.GetLineCount(this.OriginalText))
        this.NativeDestroying := false
        this.NativeCloseContext := ""
        this.NativeFinalizeTimer := ObjBindMethod(this, "FinishNativeDestroy")
        this.ThemeTimer := ObjBindMethod(this, "ApplyNativeThemes")
        this.EditorHwnd := 0
        this.MetadataTitle := ""
        this.MetadataRows := []
        this.MetadataNote := ""
        this.RichEditModule := DllCall("kernel32\LoadLibraryExW",
            "WStr", "Msftedit.dll", "Ptr", 0, "UInt", 0x00000800, "Ptr")
        if !this.RichEditModule
            throw Error("无法加载代码编辑控件。")
        try {
            windowTitle := isNew ? Tr("新增映射代码") : Tr("编辑映射代码")
            if isNew
                minimumSize := " +MinSize"
                    . MappingBlockEditor.NewEditorMinimumWidth "x"
                    . MappingBlockEditor.NewEditorMinimumHeight
            else
                minimumSize := " +MinSize"
                    . MappingBlockEditor.EditEditorMinimumWidth "x"
                    . MappingBlockEditor.EditEditorMinimumHeight
            this.Gui := Gui("+Owner" ownerWindow.Gui.Hwnd
                " +Resize" minimumSize " +OwnDialogs", windowTitle)
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
            this.ScrollTimer := ObjBindMethod(this, "SyncLineNumberScroll")
            this.CommandCallback := ObjBindMethod(this, "OnCommand")
            this.BuildControls(mapping)
            this.KeyDownCallback := ObjBindMethod(this, "OnKeyDown")
            this.NativeDestroyCallback := ObjBindMethod(this, "OnNativeDestroy")
            OnMessage(0x0100, this.KeyDownCallback)
            OnMessage(0x0111, this.CommandCallback)
            OnMessage(0x0002, this.NativeDestroyCallback)
            OnMessage(0x0082, this.NativeDestroyCallback)
            this.Gui.OnEvent("Size", ObjBindMethod(this, "OnResize"))
            this.Gui.OnEvent("Close", ObjBindMethod(this, "RequestClose"))
            this.Gui.OnEvent("Escape", ObjBindMethod(this, "RequestClose"))
        } catch as createError {
            this.Dispose(false)
            throw createError
        }
    }

    BuildControls(mapping) {
        colors := MappingWindow.Colors
        titleText := this.IsNew ? Tr("新增映射代码")
            : mapping.Source "  ->  " mapping.Target
        this.Title := this.Gui.Add("Text",
            "x14 y14 w752 h24 BackgroundTrans c" colors.Text,
            titleText)
        this.Title.SetFont("s11 bold",
            LocalizationService.GetLanguageSystemUiFontName())
        this.LineNumberEdit := this.Gui.Add("Custom",
            "ClassRICHEDIT50W x14 y46 w" this.GutterWidth
                " h402 +0x00000886 -E0x200 -TabStop")
        this.LineNumberEditHwnd := this.LineNumberEdit.Hwnd
        SendMessage(0x00CF, 1, 0, , this.LineNumberEdit.Hwnd)
        this.LineNumberDivider := this.Gui.Add("Text",
            "x" (14 + this.GutterWidth) " y46 w1 h402 Background"
                colors.Divider)
        codeX := 14 + this.GutterWidth
            + MappingBlockEditor.GutterSeparatorWidth
        initialCodeWidth := 752 - this.GutterWidth
            - MappingBlockEditor.GutterSeparatorWidth
        this.CodeEdit := this.Gui.Add("Custom",
            "ClassRICHEDIT50W x" codeX " y46 w" initialCodeWidth
                " h402 +0x003111C4 -E0x200")
        this.CodeEditHwnd := this.CodeEdit.Hwnd
        ControlSetText(mapping.Block, this.CodeEdit)
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
        if !this.Interactions.RegisterFocusRedirect(this.LineNumberEdit,
                this.CodeEdit)
            throw Error("无法注册源码行号焦点重定向。")
        this.UpdateLineNumbers(mapping.Block, false)
        this.ApplyEditorFonts(true)
        if this.IsNew
            this.BuildMetadataReference()
        this.Status := this.Gui.Add("Text",
            "x14 y518 w500 h24 BackgroundTrans c" colors.Muted,
            this.IsNew ? Tr("新增映射代码") : Tr("编辑映射代码"))
        this.SaveButton := this.AddCommandButton(534, 512, 112,
            Tr("保存"), colors.Primary, ObjBindMethod(this, "Save"))
        this.CancelButton := this.AddCommandButton(654, 512, 112,
            Tr("取消"), colors.Toolbar, ObjBindMethod(this, "RequestClose"))
        this.Interactions.SetFocusSink(this.SaveButton)
    }

    BuildMetadataReference() {
        colors := MappingWindow.Colors
        this.MetadataTitle := this.Gui.Add("Text",
            "x698 y46 w326 h24 BackgroundTrans c" colors.Text,
            Tr("元数据说明"))
        this.MetadataTitle.SetFont("s10 bold",
            LocalizationService.GetLanguageSystemUiFontName())
        for definition in this.GetMetadataDefinitions() {
            nameControl := this.Gui.Add("Text",
                "x698 y76 w112 h36 BackgroundTrans c" colors.Text,
                definition.Name)
            nameControl.SetFont("s10 bold", this.CodeFontName)
            descriptionControl := this.Gui.Add("Text",
                "x814 y76 w210 h36 BackgroundTrans c" colors.Muted,
                definition.Description)
            descriptionControl.SetFont("s9",
                LocalizationService.GetUiFontName())
            this.MetadataRows.Push({
                Name: definition.Name,
                NameControl: nameControl,
                DescriptionControl: descriptionControl
            })
        }
        this.MetadataNote := this.Gui.Add("Text",
            "x698 y390 w326 h58 BackgroundTrans c" colors.Hint,
            Tr("整个映射块只允许注释化 RuleSpec JSON；右侧说明仅供参考，不会保存到代码。"))
        this.MetadataNote.SetFont("s9",
            LocalizationService.GetUiFontName())
    }

    GetMetadataDefinitions() {
        return [
            {Name: "@schema", Description: Tr("RuleSpec 外壳版本，当前必须为 2。")},
            {Name: "@mode", Description: Tr("规则模式，当前必须为 managed。")},
            {Name: "@id", Description: Tr("映射的唯一编号，必须与 RuleSpec 的 id 一致。")},
            {Name: "@spec-begin", Description: Tr("结构化 RuleSpec JSON 的开始标记。")},
            {Name: "RuleSpec JSON", Description: Tr("注释化 JSON；可编辑来源、条件、显示信息和输出动作。")},
            {Name: "@spec-end", Description: Tr("结构化 RuleSpec JSON 的结束标记。")},
            {Name: "@generated-sha256", Description: Tr("规范化 RuleSpec JSON 的 SHA-256 摘要。")},
            {Name: "@generated-begin/end", Description: Tr("生成区只含说明注释，不包含可执行 AHK。")}
        ]
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
        width := this.IsNew ? MappingBlockEditor.NewEditorWidth
            : MappingBlockEditor.EditEditorWidth
        height := this.IsNew ? MappingBlockEditor.NewEditorHeight
            : MappingBlockEditor.EditEditorHeight
        ShowPreparedWindow(this.Gui, "w" width " h" height,
            ObjBindMethod(this, "ApplyNativeThemes", false))
        this.UpdateLineNumbers()
        this.ApplyEditorFonts(true)
        SetTimer(this.FormatTimer, -80)
        SetTimer(this.ThemeTimer, -120)
        try ControlFocus(this.CodeEdit)
        SendMessage(0x00B1, 0, 0, , this.CodeEdit.Hwnd)
        SendMessage(0x00B7, 0, 0, , this.CodeEdit.Hwnd)
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
        if this.IsNew
            this.ApplyMetadataAppearance()
        SendMessage(0x0443, 0, ColorRef(colors.Surface), ,
            this.CodeEdit.Hwnd)
        SendMessage(0x0443, 0, ColorRef(colors.CodeGutter), ,
            this.LineNumberEdit.Hwnd)
        this.LineNumberDivider.Opt("+Background" colors.Divider)
        this.Interactions.SetTextNoErase(this.SaveButton, Tr("保存"))
        this.Interactions.SetTextNoErase(this.CancelButton, Tr("取消"))
        this.Interactions.SetButtonAppearance(this.SaveButton,
            colors.Primary, colors.ButtonText, true)
        this.Interactions.SetButtonAppearance(this.CancelButton,
            colors.Toolbar, colors.ToolbarText, true)
        this.Status.SetFont("s10 c" (this.StatusIsError
            ? colors.Error : colors.Muted),
            LocalizationService.GetUiFontName())
        this.ApplyNativeThemes(false)
        this.ApplyLineNumberAppearance()
        this.ApplyEditorFonts(true)
        DllCall("user32\RedrawWindow", "Ptr", this.Gui.Hwnd,
            "Ptr", 0, "Ptr", 0, "UInt", Win32.RDW_LAYOUT_REFRESH, "Int")
        } finally EndStableWindowUpdate(this.Gui.Hwnd, true)
        return true
    }

    ApplyMetadataAppearance() {
        if !IsObject(this.MetadataTitle)
            return
        colors := MappingWindow.Colors
        this.MetadataTitle.Text := Tr("元数据说明")
        this.MetadataTitle.SetFont("s10 bold c" colors.Text,
            LocalizationService.GetLanguageSystemUiFontName())
        definitions := this.GetMetadataDefinitions()
        for index, row in this.MetadataRows {
            row.DescriptionControl.Text := definitions[index].Description
            row.NameControl.SetFont("s10 bold c" colors.Text,
                this.CodeFontName)
            row.DescriptionControl.SetFont("s9 c" colors.Muted,
                LocalizationService.GetUiFontName())
        }
        this.MetadataNote.Text := Tr(
            "整个映射块只允许注释化 RuleSpec JSON；右侧说明仅供参考，不会保存到代码。")
        this.MetadataNote.SetFont("s9 c" colors.Hint,
            LocalizationService.GetUiFontName())
    }

    Activate() {
        if this.Disposed
            return
        return ActivatePreparedWindow(this.Gui)
    }

    Save(*) {
        if this.Disposed
            return
        result := this.IsNew
            ? this.OwnerWindow.App.AddMappingBlock(this.GetCodeText())
            : this.OwnerWindow.App.UpdateMappingBlock(this.MappingId,
                this.GetCodeText())
        if !result.Ok {
            this.SetStatus(Tr("未保存：{1}", result.Message), true)
            return
        }
        this.OriginalText := this.Canonicalize(this.GetCodeText())
        this.Dispose()
    }

    RequestClose(*) {
        if this.Disposed
            return
        if this.IsDirty() {
            if !ShowDarkConfirmBox(
                    Tr("代码修改尚未保存，确定放弃吗？"), Tr("放弃修改"),
                    Tr("放弃修改"), Tr("取消"), this.Gui)
                return
        }
        this.Dispose()
    }

    IsDirty() {
        return this.Canonicalize(this.GetCodeText()) != this.OriginalText
    }

    GetCodeText() {
        return ControlGetText(this.CodeEdit)
    }

    SetCodeText(text) {
        if this.Disposed || !this.CodeEditHwnd
            return false
        if IsObject(this.FormatTimer)
            SetTimer(this.FormatTimer, 0)
        BeginStableWindowUpdate(this.Gui.Hwnd)
        try {
            ; ControlSetText 会把 RichEdit 全文暂时恢复为系统默认黑字。把写入、
            ; 行号和完整高亮放在同一重绘事务中，避免深色界面泄露中间帧。
            this.Formatting := true
            try ControlSetText(String(text), this.CodeEdit)
            finally this.Formatting := false
            this.UpdateLineNumbers(text)
            this.ApplyEditorFonts(true)
            this.SyncLineNumberScroll()
        } finally {
            this.Formatting := false
            EndStableWindowUpdate(this.Gui.Hwnd)
        }
        return true
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
        return StrSplit(this.Canonicalize(text), "`n").Length
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
        if this.Disposed || !this.LineNumberEditHwnd
            return false
        if !IsSet(text)
            text := this.GetCodeText()
        lineCount := this.GetLineCount(text)
        newWidth := this.CalculateGutterWidth(lineCount)
        widthChanged := newWidth != this.GutterWidth
        if lineCount != this.LineNumberCount {
            this.LineNumberCount := lineCount
            this.LineNumberText := this.BuildLineNumberText(lineCount)
            ControlSetText(this.LineNumberText, this.LineNumberEdit)
            this.ApplyLineNumberAppearance()
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
        if this.Disposed || !this.LineNumberEditHwnd
            return false
        colors := MappingWindow.Colors
        selection := Buffer(8, 0)
        scrollPosition := Buffer(8, 0)
        SendMessage(0x0434, 0, selection.Ptr, ,
            this.LineNumberEdit.Hwnd)
        SendMessage(0x04DD, 0, scrollPosition.Ptr, ,
            this.LineNumberEdit.Hwnd)
        SendMessage(0x000B, 0, 0, , this.LineNumberEdit.Hwnd)
        try {
            this.SetRichTextFont(0, StrLen(this.LineNumberText),
                this.CodeFontName, 1, colors.CodeLineNumber,
                this.LineNumberEdit.Hwnd)
        } finally {
            SendMessage(0x0437, 0, selection.Ptr, ,
                this.LineNumberEdit.Hwnd)
            SendMessage(0x000B, 1, 0, , this.LineNumberEdit.Hwnd)
            SendMessage(0x04DE, 0, scrollPosition.Ptr, ,
                this.LineNumberEdit.Hwnd)
            DllCall("user32\InvalidateRect", "Ptr",
                this.LineNumberEdit.Hwnd, "Ptr", 0, "Int", 0)
        }
        return true
    }

    RefreshEditorPresentation(*) {
        if this.Disposed
            return
        this.UpdateLineNumbers()
        this.ApplyEditorFonts()
        this.SyncLineNumberScroll()
    }

    SyncLineNumberScroll(*) {
        if this.Disposed || !this.CodeEditHwnd || !this.LineNumberEditHwnd
            return false
        editorFirstLine := SendMessage(0x00CE, 0, 0, ,
            this.CodeEdit.Hwnd)
        gutterFirstLine := SendMessage(0x00CE, 0, 0, ,
            this.LineNumberEdit.Hwnd)
        lineDelta := editorFirstLine - gutterFirstLine
        if lineDelta
            SendMessage(0x00B6, 0, lineDelta, , this.LineNumberEdit.Hwnd)
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
        this.Status.SetFont("c" (isError ? MappingWindow.Colors.Error
            : MappingWindow.Colors.Muted))
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
        if wParam == 0x53 && GetKeyState("Ctrl", "P") {
            this.Save()
            return 0
        }
    }

    OnCommand(wParam, lParam, msg, hwnd) {
        if this.Disposed || lParam != this.CodeEditHwnd
            return
        notificationCode := (wParam >> 16) & 0xFFFF
        if notificationCode == 0x0300 {
            if this.Formatting
                return
            this.UpdateLineNumbers()
            SetTimer(this.FormatTimer, -140)
            return
        }
        if notificationCode == 0x0400 || notificationCode == 0x0601
            || notificationCode == 0x0602
            SetTimer(this.ScrollTimer, -1)
    }

    ResolveCodeFontName() {
        for fontName in ["JetBrains Mono", "Cascadia Mono", "Consolas"] {
            if LocalizationService.IsFontInstalled(fontName)
                return fontName
        }
        return LocalizationService.GetUiFontName()
    }

    ApplyEditorFonts(fullDocument := false, *) {
        if this.Disposed || this.Formatting
            return
        this.Formatting := true
        selection := Buffer(8, 0)
        scrollPosition := Buffer(8, 0)
        SendMessage(0x0434, 0, selection.Ptr, , this.CodeEdit.Hwnd)
        SendMessage(0x04DD, 0, scrollPosition.Ptr, , this.CodeEdit.Hwnd)
        SendMessage(0x000B, 0, 0, , this.CodeEdit.Hwnd)
        try {
            ; WM_GETTEXT 返回 CRLF，而 RichEdit 选区把每个段落标记计为一个字符。
            ; 先折叠换行，避免中文字体选区随行数逐行向后偏移。
            text := this.Canonicalize(this.GetCodeText())
            formatRange := this.GetFormatRange(text, fullDocument)
            this.SetRichTextFont(formatRange.Start, formatRange.End,
                this.CodeFontName, 1)
            rangeText := SubStr(text, formatRange.Start + 1,
                formatRange.End - formatRange.Start)
            position := 1
            cjkPattern := "[\x{2E80}-\x{2FFF}\x{3000}-\x{303F}"
                . "\x{3400}-\x{4DBF}\x{4E00}-\x{9FFF}"
                . "\x{F900}-\x{FAFF}\x{FF00}-\x{FFEF}]+"
            while RegExMatch(rangeText, cjkPattern, &cjkMatch, position) {
                startPosition := formatRange.Start + cjkMatch.Pos(0) - 1
                endPosition := startPosition + cjkMatch.Len(0)
                this.SetRichTextFont(startPosition, endPosition,
                    this.CjkFontName, 134)
                position := cjkMatch.Pos(0) + cjkMatch.Len(0)
            }
            this.ApplySyntaxHighlighting(text, formatRange)
        } finally {
            SendMessage(0x0437, 0, selection.Ptr, , this.CodeEdit.Hwnd)
            SendMessage(0x000B, 1, 0, , this.CodeEdit.Hwnd)
            SendMessage(0x04DE, 0, scrollPosition.Ptr, , this.CodeEdit.Hwnd)
            try DllCall("user32\InvalidateRect", "Ptr", this.CodeEdit.Hwnd,
                "Ptr", 0, "Int", 0)
            this.Formatting := false
            this.SyncLineNumberScroll()
        }
    }

    ApplySyntaxHighlighting(text, formatRange) {
        colors := MappingWindow.Colors
        lineStart := 0
        Loop Parse text, "`n" {
            line := A_LoopField
            lineEnd := lineStart + StrLen(line)
            if lineEnd >= formatRange.Start && lineStart <= formatRange.End
                this.ApplySyntaxLine(line, lineStart, lineEnd,
                    formatRange, colors)
            lineStart := lineEnd + 1
        }
    }

    ApplySyntaxLine(line, lineStart, lineEnd, formatRange, colors) {
        if RegExMatch(line,
            "^([ `t]*;[ `t]*)(@[A-Za-z0-9-]+)(=)?(.*)$", &metadata) {
            this.SetSyntaxColor(lineStart, lineEnd, colors.CodeComment,
                formatRange)
            semicolonOffset := InStr(metadata[1], ";") - 1
            variableEnd := lineStart + metadata.Pos(2) - 1
                + metadata.Len(2)
            this.SetSyntaxColor(lineStart + semicolonOffset, variableEnd,
                colors.CodeVariable, formatRange)
            if metadata[3] != "" {
                valueStart := lineStart + metadata.Pos(3) - 1
                this.SetSyntaxColor(valueStart, lineEnd, colors.CodeValue,
                    formatRange)
            }
            return
        }
        commentPosition := this.FindCommentStart(line)
        if commentPosition
            this.SetSyntaxColor(lineStart + commentPosition - 1, lineEnd,
                colors.CodeComment, formatRange)
    }

    FindCommentStart(line) {
        quote := Chr(34)
        inString := false
        position := 1
        length := StrLen(line)
        while position <= length {
            character := SubStr(line, position, 1)
            if character == quote {
                if inString && position < length
                    && SubStr(line, position + 1, 1) == quote {
                    position += 2
                    continue
                }
                inString := !inString
            } else if character == ";" && !inString {
                return position
            }
            position++
        }
        return 0
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
        if fullDocument || textLength <= 32768
            return {Start: 0, End: textLength}
        firstLine := SendMessage(0x00CE, 0, 0, , this.CodeEdit.Hwnd)
        startPosition := SendMessage(0x00BB, firstLine, 0, , this.CodeEdit.Hwnd)
        endPosition := SendMessage(0x00BB, firstLine + 120, 0, ,
            this.CodeEdit.Hwnd)
        if startPosition < 0
            startPosition := 0
        if endPosition < 0
            endPosition := textLength
        return {Start: Min(textLength, startPosition),
            End: Min(textLength, Max(startPosition, endPosition))}
    }

    SetRichTextFont(startPosition, endPosition, faceName, characterSet,
        color := "", controlHwnd := 0) {
        if color == ""
            color := MappingWindow.Colors.Text
        if !controlHwnd
            controlHwnd := this.CodeEdit.Hwnd
        selection := Buffer(8, 0)
        NumPut("Int", startPosition, selection, 0)
        NumPut("Int", endPosition, selection, 4)
        SendMessage(0x0437, 0, selection.Ptr, , controlHwnd)
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
        return SendMessage(0x0444, 1, characterFormat.Ptr, , controlHwnd)
    }

    SetRichTextColor(startPosition, endPosition, color) {
        selection := Buffer(8, 0)
        NumPut("Int", startPosition, selection, 0)
        NumPut("Int", endPosition, selection, 4)
        SendMessage(0x0437, 0, selection.Ptr, , this.CodeEdit.Hwnd)
        characterFormat := Buffer(116, 0)
        NumPut("UInt", 116, characterFormat, 0)
        NumPut("UInt", 0x40000000, characterFormat, 4) ; CFM_COLOR
        NumPut("UInt", ColorRef(color), characterFormat, 20)
        return SendMessage(0x0444, 1, characterFormat.Ptr, ,
            this.CodeEdit.Hwnd)
    }

    OnResize(guiObj, minMax, width, height) {
        if minMax == -1 || this.Disposed
            return
        contentWidth := Max(612, width - 28)
        this.Title.Move(14, 14, contentWidth, 24)
        editorHeight := Max(260, height - 112)
        if this.IsNew {
            panelWidth := MappingBlockEditor.MetadataPanelWidth
            panelGap := MappingBlockEditor.MetadataPanelGap
            codeWidth := Max(480, contentWidth - panelGap - panelWidth)
            panelX := 14 + codeWidth + panelGap
            actualPanelWidth := Max(250, width - 14 - panelX)
            this.LayoutCodeEditor(14, 46, codeWidth, editorHeight)
            this.LayoutMetadataReference(panelX, actualPanelWidth,
                editorHeight)
        } else {
            this.LayoutCodeEditor(14, 46, contentWidth, editorHeight)
        }
        commandY := height - 48
        this.SaveButton.Move(width - 246, commandY, 112, 32)
        this.CancelButton.Move(width - 126, commandY, 112, 32)
        this.Status.Move(14, commandY + 6, Max(280, width - 280), 24)
    }

    LayoutCodeEditor(x, y, width, height) {
        separatorWidth := MappingBlockEditor.GutterSeparatorWidth
        codeX := x + this.GutterWidth + separatorWidth
        codeWidth := Max(240, width - this.GutterWidth - separatorWidth)
        this.LineNumberEdit.Move(x, y, this.GutterWidth, height)
        this.LineNumberDivider.Move(x + this.GutterWidth, y,
            separatorWidth, height)
        this.CodeEdit.Move(codeX, y, codeWidth, height)
        SetTimer(this.ScrollTimer, -1)
    }

    LayoutMetadataReference(x, width, availableHeight) {
        if !IsObject(this.MetadataTitle)
            return
        this.MetadataTitle.Move(x, 46, width, 24)
        rowTop := 76
        rowHeight := 37
        nameWidth := Min(112, Max(98, Floor(width * 0.35)))
        descriptionX := x + nameWidth + 4
        descriptionWidth := Max(130, width - nameWidth - 4)
        for row in this.MetadataRows {
            row.NameControl.Move(x, rowTop, nameWidth, rowHeight)
            row.DescriptionControl.Move(descriptionX, rowTop,
                descriptionWidth, rowHeight)
            rowTop += rowHeight
        }
        noteY := rowTop + 8
        noteHeight := Max(44, 46 + availableHeight - noteY)
        this.MetadataNote.Move(x, noteY, width, noteHeight)
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
        this.Disposed := true
        this.NativeDestroying := true
        this.NativeCloseContext := this.ReleaseOwner()
        this.StopEditorCallbacks(false)
    }

    FinishNativeDestroy(*) {
        if !this.NativeDestroying
            return
        this.NativeDestroying := false
        closeContext := this.NativeCloseContext
        this.NativeCloseContext := ""
        this.StopEditorCallbacks(true)
        if IsObject(this.Interactions)
            try this.Interactions.Dispose()
        this.Interactions := ""
        this.Gui := ""
        this.EditorHwnd := 0
        this.CodeEditHwnd := 0
        this.LineNumberEditHwnd := 0
        this.ReleaseRichEditModule()
        if this.HasOwnProp("IconHandles") {
            ReleaseApplicationWindowIcons(this.IconHandles)
            this.IconHandles := []
        }
        this.ReleaseCallbackReferences()
        this.OwnerWindow.OnBlockEditorClosed(this)
        WindowHierarchy.CompleteClose(closeContext)
    }

    StopEditorCallbacks(includeNativeDestroy := true) {
        if IsObject(this.ThemeTimer)
            try SetTimer(this.ThemeTimer, 0)
        if IsObject(this.FormatTimer)
            try SetTimer(this.FormatTimer, 0)
        if IsObject(this.ScrollTimer)
            try SetTimer(this.ScrollTimer, 0)
        if IsObject(this.KeyDownCallback)
            try OnMessage(0x0100, this.KeyDownCallback, 0)
        if IsObject(this.CommandCallback)
            try OnMessage(0x0111, this.CommandCallback, 0)
        if includeNativeDestroy && IsObject(this.NativeDestroyCallback) {
            try OnMessage(0x0002, this.NativeDestroyCallback, 0)
            try OnMessage(0x0082, this.NativeDestroyCallback, 0)
        }
    }

    ReleaseCallbackReferences() {
        this.NativeFinalizeTimer := ""
        this.ThemeTimer := ""
        this.FormatTimer := ""
        this.ScrollTimer := ""
        this.CommandCallback := ""
        this.KeyDownCallback := ""
        this.NativeDestroyCallback := ""
    }

    ReleaseRichEditModule() {
        if this.RichEditModule {
            DllCall("kernel32\FreeLibrary", "Ptr", this.RichEditModule)
            this.RichEditModule := 0
        }
    }

    ReleaseOwner() {
        if !this.OwnerLease
            return ""
        ownerLease := this.OwnerLease
        this.OwnerLease := ""
        return WindowHierarchy.Release(ownerLease)
    }

    Dispose(activateOwner := true, destroyGui := true) {
        if this.Disposed
            return
        this.Disposed := true
        closeContext := this.ReleaseOwner()
        try {
            this.StopEditorCallbacks(true)
            if IsObject(this.Interactions)
                try this.Interactions.Dispose()
            this.Interactions := ""
            if destroyGui && this.Gui {
                try editorHwnd := this.Gui.Hwnd
                catch
                    editorHwnd := 0
                if editorHwnd && DllCall("user32\IsWindow", "Ptr", editorHwnd, "Int")
                    try this.Gui.Destroy()
            }
            this.Gui := ""
            this.EditorHwnd := 0
            this.CodeEditHwnd := 0
            this.LineNumberEditHwnd := 0
        } finally {
            this.ReleaseRichEditModule()
            if this.HasOwnProp("IconHandles") {
                ReleaseApplicationWindowIcons(this.IconHandles)
                this.IconHandles := []
            }
            this.ReleaseCallbackReferences()
            this.OwnerWindow.OnBlockEditorClosed(this)
            if activateOwner
                WindowHierarchy.CompleteClose(closeContext)
        }
    }
}
