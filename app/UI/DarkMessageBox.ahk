; Blocking themed dialogs. Layout intentionally follows the watchdog helper:
; fixed icon column, measured message row, centered button group.
ShowDarkMsgBox(message, title := "", type := "Info", ownerGui := "") {
    dialog := DarkMessageDialog(message, title, type, ownerGui)
    return dialog.Show()
}

ShowDarkConfirmBox(message, title, confirmText, cancelText, ownerGui := "") {
    dialog := DarkConfirmDialog(message, title, confirmText, cancelText,
        ownerGui)
    return dialog.Show()
}

ShowDarkTextInputBox(message, title, confirmText, cancelText, emptyMessage,
        ownerGui := "", initialValue := "") {
    dialog := DarkTextInputDialog(message, title, confirmText, cancelText,
        emptyMessage, ownerGui, initialValue)
    return dialog.Show()
}

ShowDarkTextComparisonDialog(currentText, proposedText, title,
        ownerGui := "") {
    dialog := DarkTextComparisonDialog(currentText, proposedText, title,
        ownerGui)
    return dialog.Show()
}

CalculateDarkDialogLayout(windowWidth, messageHeight, buttonWidths,
        buttonTopGap := 20) {
    contentTop := 20
    iconHeight := 30
    buttonHeight := 30
    buttonGap := 12
    rowHeight := Max(iconHeight, Max(1, Integer(messageHeight)))
    groupWidth := 0
    for buttonWidth in buttonWidths
        groupWidth += buttonWidth
    if buttonWidths.Length > 1
        groupWidth += buttonGap * (buttonWidths.Length - 1)
    nextButtonX := Floor((windowWidth - groupWidth) / 2)
    buttonXs := []
    for buttonWidth in buttonWidths {
        buttonXs.Push(nextButtonX)
        nextButtonX += buttonWidth + buttonGap
    }
    buttonY := contentTop + rowHeight + buttonTopGap
    return {
        IconY: contentTop + Floor((rowHeight - iconHeight) / 2),
        MessageY: contentTop + Floor((rowHeight - messageHeight) / 2),
        ButtonY: buttonY,
        ButtonXs: buttonXs,
        WindowHeight: buttonY + buttonHeight + 15
    }
}

MeasureDarkDialogButtonWidth(button, minimumWidthDip) {
    deviceContext := DllCall("user32\GetDC", "Ptr", button.Hwnd, "Ptr")
    if !deviceContext
        return minimumWidthDip
    fontHandle := SendMessage(Win32.WM_GETFONT, 0, 0, , button.Hwnd)
    previousFont := fontHandle ? DllCall("gdi32\SelectObject", "Ptr",
        deviceContext, "Ptr", fontHandle, "Ptr") : 0
    extent := Buffer(8, 0)
    try {
        text := button.Text
        if !DllCall("gdi32\GetTextExtentPoint32W", "Ptr", deviceContext,
                "Str", text, "Int", StrLen(text), "Ptr", extent, "Int")
            return minimumWidthDip
        windowDpi := DllCall("user32\GetDpiForWindow", "Ptr", button.Hwnd,
            "UInt")
        if !windowDpi
            windowDpi := 96
        textWidthDip := Ceil(NumGet(extent, 0, "Int") * 96 / windowDpi)
        return Max(minimumWidthDip, textWidthDip + 24)
    } finally {
        if previousFont
            DllCall("gdi32\SelectObject", "Ptr", deviceContext,
                "Ptr", previousFont, "Ptr")
        DllCall("user32\ReleaseDC", "Ptr", button.Hwnd, "Ptr",
            deviceContext)
    }
}

class DarkDialogBase {
    static IconX := 20
    static IconWidth := 30
    static MessageX := 60
    static ButtonHeight := 30

    InitializeWindow(title, ownerGui) {
        this.OwnerGui := ownerGui
        guiOptions := "-MinimizeBox -MaximizeBox +OwnDialogs"
        if this.IsOwnerAlive()
            guiOptions .= " +Owner" this.OwnerGui.Hwnd
        this.Gui := Gui(guiOptions, title)
        this.IconHandles := ApplyApplicationWindowIcon(this.Gui.Hwnd)
        if this.IsOwnerAlive() {
            this.OwnerLease := WindowHierarchy.Acquire(this.OwnerGui,
                this.Gui.Hwnd)
            if !this.OwnerLease
                throw Error("无法建立提示窗口层级。")
        }
        colors := UiThemeService.GetPalette()
        this.Gui.BackColor := colors.Window
        this.Gui.MarginX := 0
        this.Gui.MarginY := 0
        this.Interactions := MappingUiInteractions(this.Gui, colors.Window)
        return colors
    }

    AddIcon(iconText, iconColor := "", fontName := "Segoe UI Emoji") {
        colors := UiThemeService.GetPalette()
        if iconColor == ""
            iconColor := colors.Text
        this.Gui.SetFont("s18 c" iconColor, fontName)
        return this.Gui.Add("Text", "x" DarkDialogBase.IconX
            " y20 w" DarkDialogBase.IconWidth " h30 BackgroundTrans",
            iconText)
    }

    AddMessage(message, width) {
        colors := UiThemeService.GetPalette()
        this.Gui.SetFont("s10 c" colors.Text,
            LocalizationService.GetUiFontName())
        return this.Gui.Add("Text", "x" DarkDialogBase.MessageX
            " y20 w" width " BackgroundTrans", String(message))
    }

    AddButton(x, y, width, text, color, textColor, callback) {
        button := this.Gui.Add("Text", "x" x " y" y " w" width
            " h" DarkDialogBase.ButtonHeight
            " Center 0x200 Background" color " c" textColor, text)
        if !this.Interactions.RegisterButton(button, color, callback,
                "", "", false, textColor)
            button.OnEvent("Click", callback)
        return button
    }

    IsOwnerAlive() {
        return IsObject(this.OwnerGui) && Type(this.OwnerGui) == "Gui"
            && WindowHierarchy.IsGuiAlive(this.OwnerGui)
    }

    ApplyNativeThemes(*) {
        if this.Disposed
            return false
        return ApplyDarkWindow(this.Gui.Hwnd)
    }

    Dispose(activateOwner := true) {
        if this.Disposed
            return
        this.Disposed := true
        cleanup := CleanupCollector("提示窗口")
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
        this.OwnerGui := ""
        cleanup.Complete()
        return true
    }
}

class DarkMessageDialog extends DarkDialogBase {
    __New(message, title, type, ownerGui) {
        this.Message := String(message)
        this.Title := title == "" ? Tr("提示") : String(title)
        this.Type := StrLower(String(type))
        this.OwnerLease := ""
        this.IconHandles := []
        this.Disposed := false
        try this.Build(ownerGui)
        catch as buildError {
            try this.Dispose(false)
            throw buildError
        }
    }

    Build(ownerGui) {
        colors := this.InitializeWindow(this.Title, ownerGui)
        windowWidth := 300
        messageWidth := 220
        this.TypeIcon := this.AddIcon(this.Type == "error" ? "❌" : "ℹ️")
        this.MessageText := this.AddMessage(this.Message, messageWidth)
        this.MessageText.GetPos(, , , &messageHeight)
        this.OkButton := this.AddButton(0, 0, 70, Tr("确定"),
            colors.Primary, colors.ButtonText, ObjBindMethod(this, "Close"))
        buttonWidth := MeasureDarkDialogButtonWidth(this.OkButton, 70)
        if buttonWidth > 70 {
            windowWidth := buttonWidth + 40
            messageWidth := windowWidth - DarkDialogBase.MessageX - 20
            this.MessageText.Move(, , messageWidth)
            this.MessageText.GetPos(, , , &messageHeight)
        }
        layout := CalculateDarkDialogLayout(windowWidth, messageHeight,
            [buttonWidth])
        this.TypeIcon.Move(, layout.IconY)
        this.MessageText.Move(, layout.MessageY)
        this.OkButton.Move(layout.ButtonXs[1], layout.ButtonY, buttonWidth)
        this.WindowWidth := windowWidth
        this.WindowHeight := layout.WindowHeight
        this.Gui.OnEvent("Close", ObjBindMethod(this, "Close"))
        this.Gui.OnEvent("Escape", ObjBindMethod(this, "Close"))
    }

    Show() {
        if this.Disposed
            return false
        hwnd := this.Gui.Hwnd
        ShowPreparedWindow(this.Gui, "Center w" this.WindowWidth " h"
            this.WindowHeight, ObjBindMethod(this, "ApplyNativeThemes"))
        WinWaitClose("ahk_id " hwnd)
        return true
    }

    Close(*) => this.Dispose()
}

class DarkConfirmDialog extends DarkDialogBase {
    __New(message, title, confirmText, cancelText, ownerGui) {
        this.Message := String(message)
        this.Title := String(title)
        this.ConfirmText := String(confirmText)
        this.CancelText := String(cancelText)
        this.OwnerLease := ""
        this.IconHandles := []
        this.Accepted := false
        this.Disposed := false
        this.AcceptEnter := this.ConfirmText == Tr("保存并运行")
        this.KeyDownCallback := ""
        try this.Build(ownerGui)
        catch as buildError {
            try this.Dispose(false)
            throw buildError
        }
    }

    Build(ownerGui) {
        colors := this.InitializeWindow(this.Title, ownerGui)
        windowWidth := this.AcceptEnter ? 365 : 360
        messageWidth := windowWidth - DarkDialogBase.MessageX - 20
        this.WarningIconColor := colors.Warning
        this.TypeIcon := this.AddIcon(Chr(0x26A0), this.WarningIconColor,
            LocalizationService.GetLanguageSystemUiFontName())
        this.MessageText := this.AddMessage(this.Message, messageWidth)
        this.MessageText.GetPos(, , , &messageHeight)
        confirmColor := this.ConfirmText == Tr("保存")
                || this.ConfirmText == Tr("保存并运行")
            ? colors.Save : colors.Primary
        this.ConfirmButton := this.AddButton(0, 0, 80, this.ConfirmText,
            confirmColor, colors.ButtonText, ObjBindMethod(this, "Confirm"))
        this.CancelButton := this.AddButton(0, 0, 80, this.CancelText,
            colors.Toolbar, colors.ToolbarText, ObjBindMethod(this, "Cancel"))
        primaryWidth := MeasureDarkDialogButtonWidth(this.ConfirmButton, 80)
        secondaryWidth := MeasureDarkDialogButtonWidth(this.CancelButton, 80)
        buttonGroupWidth := primaryWidth + 12 + secondaryWidth
        if buttonGroupWidth > windowWidth - 40 {
            windowWidth := buttonGroupWidth + 40
            messageWidth := windowWidth - DarkDialogBase.MessageX - 20
            this.MessageText.Move(, , messageWidth)
            this.MessageText.GetPos(, , , &messageHeight)
        }
        layout := CalculateDarkDialogLayout(windowWidth, messageHeight,
            [primaryWidth, secondaryWidth], 22)
        this.TypeIcon.Move(, layout.IconY)
        this.MessageText.Move(, layout.MessageY)
        this.ConfirmButton.Move(layout.ButtonXs[1], layout.ButtonY,
            primaryWidth)
        this.CancelButton.Move(layout.ButtonXs[2], layout.ButtonY,
            secondaryWidth)
        this.WindowWidth := windowWidth
        this.WindowHeight := layout.WindowHeight
        this.Gui.OnEvent("Close", ObjBindMethod(this, "Cancel"))
        this.Gui.OnEvent("Escape", ObjBindMethod(this, "Cancel"))
        if this.AcceptEnter {
            this.KeyDownCallback := ObjBindMethod(this, "OnKeyDown")
            OnMessage(Win32.WM_KEYDOWN, this.KeyDownCallback)
        }
    }

    Show() {
        if this.Disposed
            return false
        hwnd := this.Gui.Hwnd
        ShowPreparedWindow(this.Gui, "Center w" this.WindowWidth " h"
            this.WindowHeight, ObjBindMethod(this, "ApplyNativeThemes"))
        WinWaitClose("ahk_id " hwnd)
        return this.Accepted
    }

    Confirm(*) {
        this.Accepted := true
        this.Dispose()
    }

    OnKeyDown(wParam, lParam, msg, hwnd) {
        if this.Disposed || !this.AcceptEnter || wParam != 0x0D
                || GetKeyState("Ctrl", "P")
                || GetKeyState("Shift", "P")
                || GetKeyState("Alt", "P")
            return
        rootHwnd := DllCall("user32\GetAncestor", "Ptr", hwnd,
            "UInt", 2, "Ptr")
        if rootHwnd != this.Gui.Hwnd
            return
        this.Confirm()
        return 0
    }

    Cancel(*) {
        this.Accepted := false
        this.Dispose()
    }

    Dispose(activateOwner := true) {
        if IsObject(this.KeyDownCallback) {
            OnMessage(Win32.WM_KEYDOWN, this.KeyDownCallback, 0)
            this.KeyDownCallback := ""
        }
        return super.Dispose(activateOwner)
    }
}

class DarkTextInputDialog extends DarkDialogBase {
    static WindowWidth := 460
    static WindowHeight := 220
    static ErrorWindowHeight := 252
    static EditorHeight := 108
    static CompactButtonY := 170
    static ErrorButtonY := 202

    __New(message, title, confirmText, cancelText, emptyMessage, ownerGui,
            initialValue := "") {
        this.Message := String(message)
        this.Title := String(title)
        this.ConfirmText := String(confirmText)
        this.CancelText := String(cancelText)
        this.EmptyMessage := String(emptyMessage)
        this.InitialValue := String(initialValue)
        this.OwnerLease := ""
        this.IconHandles := []
        this.Accepted := false
        this.Value := ""
        this.CurrentWindowHeight := DarkTextInputDialog.WindowHeight
        this.Disposed := false
        try this.Build(ownerGui)
        catch as buildError {
            try this.Dispose(false)
            throw buildError
        }
    }

    Build(ownerGui) {
        colors := this.InitializeWindow(this.Title, ownerGui)
        this.Gui.SetFont("s10 c" colors.Text,
            LocalizationService.GetUiFontName())
        this.MessageText := this.Gui.Add("Text",
            "x20 y18 w420 h24 BackgroundTrans", this.Message)
        this.TextEdit := this.Gui.Add("Edit",
            "x20 y48 w420 h" DarkTextInputDialog.EditorHeight
                " Multi WantReturn Wrap -HScroll"
                . " -E0x200 Background" colors.Input " c" colors.Text,
            this.InitialValue)
        SetEditMargins(this.TextEdit.Hwnd, 8, 8)
        SendMessage(0x00C5, 0, 0, ,
            this.TextEdit.Hwnd) ; EM_SETLIMITTEXT: native maximum
        ApplyDarkControl(this.TextEdit.Hwnd)
        if !this.Interactions.RegisterTextInput(this.TextEdit)
            throw Error("无法注册文本输入窗口交互。")
        this.TextEdit.OnEvent("Change", ObjBindMethod(this, "OnTextChanged"))
        this.Status := this.Gui.Add("Text",
            "x20 y168 w420 h22 BackgroundTrans c" colors.Error " Hidden", "")
        this.ConfirmButton := this.AddButton(144,
            DarkTextInputDialog.CompactButtonY, 80,
            this.ConfirmText, colors.Primary, colors.ButtonText,
            ObjBindMethod(this, "Confirm"))
        this.CancelButton := this.AddButton(236,
            DarkTextInputDialog.CompactButtonY, 80,
            this.CancelText, colors.Toolbar, colors.ToolbarText,
            ObjBindMethod(this, "Cancel"))
        this.Gui.OnEvent("Close", ObjBindMethod(this, "Cancel"))
        this.Gui.OnEvent("Escape", ObjBindMethod(this, "Cancel"))
    }

    Show() {
        if this.Disposed
            return {Accepted: false, Value: ""}
        hwnd := this.Gui.Hwnd
        shown := ShowPreparedWindow(this.Gui,
            "Center w" DarkTextInputDialog.WindowWidth
                " h" this.CurrentWindowHeight,
            ObjBindMethod(this, "ApplyNativeThemes"))
        if shown
            ControlFocus(this.TextEdit)
        WinWaitClose("ahk_id " hwnd)
        return {Accepted: this.Accepted, Value: this.Value}
    }

    ApplyNativeThemes(*) {
        if this.Disposed
            return false
        return ApplyDarkWindow(this.Gui.Hwnd)
            && ApplyDarkControl(this.TextEdit.Hwnd)
    }

    Confirm(*) {
        value := Trim(this.TextEdit.Value)
        if value == "" {
            this.ShowValidationError()
            ControlFocus(this.TextEdit)
            return false
        }
        this.Accepted := true
        this.Value := value
        this.Dispose()
        return true
    }

    ShowValidationError() {
        this.Status.Text := this.EmptyMessage
        this.Status.Visible := true
        this.ConfirmButton.Move(, DarkTextInputDialog.ErrorButtonY)
        this.CancelButton.Move(, DarkTextInputDialog.ErrorButtonY)
        return this.SetWindowHeight(DarkTextInputDialog.ErrorWindowHeight)
    }

    ClearValidationError() {
        if this.Status.Text == "" && !this.Status.Visible
            return false
        this.Status.Text := ""
        this.Status.Visible := false
        this.ConfirmButton.Move(, DarkTextInputDialog.CompactButtonY)
        this.CancelButton.Move(, DarkTextInputDialog.CompactButtonY)
        this.SetWindowHeight(DarkTextInputDialog.WindowHeight)
        return true
    }

    OnTextChanged(*) {
        if Trim(this.TextEdit.Value) != ""
            this.ClearValidationError()
    }

    SetWindowHeight(height) {
        height := Integer(height)
        if height == this.CurrentWindowHeight
            return false
        this.CurrentWindowHeight := height
        if DllCall("user32\IsWindowVisible", "Ptr", this.Gui.Hwnd, "Int")
            this.Gui.Show("NA h" height)
        return true
    }

    Cancel(*) {
        this.Accepted := false
        this.Value := ""
        this.Dispose()
    }
}

class DarkTextComparisonDialog extends DarkDialogBase {
    static WindowWidth := 860
    static WindowHeight := 560
    static MinimumWidth := 680
    static MinimumHeight := 420
    static Margin := 16
    static PaneGap := 12
    static ButtonWidth := 108
    static ButtonGap := 12
    static MaximumLcsCells := 250000
    static RichEditModule := 0

    __New(currentText, proposedText, title, ownerGui) {
        this.CurrentText := String(currentText)
        this.ProposedText := String(proposedText)
        this.Title := String(title)
        this.OwnerLease := ""
        this.IconHandles := []
        this.Accepted := false
        this.Disposed := false
        try this.Build(ownerGui)
        catch as buildError {
            try this.Dispose(false)
            throw buildError
        }
    }

    Build(ownerGui) {
        DarkTextComparisonDialog.EnsureRichEditModule()
        colors := this.InitializeWindow(this.Title, ownerGui)
        this.Gui.Opt("+Resize +MinSize" DarkTextComparisonDialog.MinimumWidth
            "x" DarkTextComparisonDialog.MinimumHeight)
        fontName := LocalizationService.GetUiFontName()
        this.Gui.SetFont("s10 c" colors.Text, fontName)
        this.LineDiff := DarkTextComparisonDialog.CalculateLineDiff(
            this.CurrentText, this.ProposedText)
        stats := this.LineDiff.Stats
        this.Summary := this.Gui.Add("Text",
            "x16 y14 w828 h24 BackgroundTrans c" colors.Muted,
            Tr("当前 {1} 行，AI 建议 {2} 行；约 {3} 行有变化。",
                stats.CurrentLines, stats.ProposedLines, stats.ChangedLines))
        this.CurrentLabel := this.Gui.Add("Text",
            "x16 y46 w410 h22 BackgroundTrans c" colors.Text,
            Tr("当前内容"))
        this.ProposedLabel := this.Gui.Add("Text",
            "x438 y46 w406 h22 BackgroundTrans c" colors.Text,
            Tr("AI 建议"))
        this.CurrentLabel.SetFont("s10 bold",
            LocalizationService.GetLanguageSystemUiFontName())
        this.ProposedLabel.SetFont("s10 bold",
            LocalizationService.GetLanguageSystemUiFontName())
        editOptions := "ClassRICHEDIT50W +0x003119C4 -E0x200 -TabStop"
        this.CurrentEdit := this.Gui.Add("Custom",
            "x16 y70 w410 h430 " editOptions)
        this.ProposedEdit := this.Gui.Add("Custom",
            "x438 y70 w406 h430 " editOptions)
        ControlSetText(this.CurrentText, this.CurrentEdit)
        ControlSetText(this.ProposedText, this.ProposedEdit)
        for editControl in [this.CurrentEdit, this.ProposedEdit] {
            SetEditMargins(editControl.Hwnd, 8, 8)
            SendMessage(0x0443, 0, ColorRef(colors.Surface), ,
                editControl.Hwnd) ; EM_SETBKGNDCOLOR
            ApplyDarkControl(editControl.Hwnd)
            if !this.Interactions.RegisterTextInput(editControl)
                throw Error("无法注册 AI 结果审阅文本交互。")
        }
        this.CurrentSyntaxTokenCount := this.FormatComparisonControl(
            this.CurrentEdit, this.CurrentText,
            this.LineDiff.CurrentRanges, colors.CodeDiffRemoved, colors)
        this.ProposedSyntaxTokenCount := this.FormatComparisonControl(
            this.ProposedEdit, this.ProposedText,
            this.LineDiff.ProposedRanges, colors.CodeDiffAdded, colors)
        this.AcceptButton := this.AddButton(0, 514,
            DarkTextComparisonDialog.ButtonWidth, Tr("接受结果"),
            colors.Save, colors.ButtonText, ObjBindMethod(this, "Accept"))
        this.KeepButton := this.AddButton(0, 514,
            DarkTextComparisonDialog.ButtonWidth, Tr("保留原文"),
            colors.Toolbar, colors.ToolbarText, ObjBindMethod(this, "Cancel"))
        this.Gui.OnEvent("Size", ObjBindMethod(this, "OnResize"))
        this.Gui.OnEvent("Close", ObjBindMethod(this, "Cancel"))
        this.Gui.OnEvent("Escape", ObjBindMethod(this, "Cancel"))
        this.OnResize(this.Gui, 0, DarkTextComparisonDialog.WindowWidth,
            DarkTextComparisonDialog.WindowHeight)
    }

    Show() {
        if this.Disposed
            return false
        hwnd := this.Gui.Hwnd
        ShowPreparedWindow(this.Gui,
            "Center w" DarkTextComparisonDialog.WindowWidth
                . " h" DarkTextComparisonDialog.WindowHeight,
            ObjBindMethod(this, "ApplyNativeThemes"))
        WinWaitClose("ahk_id " hwnd)
        return this.Accepted
    }

    ApplyNativeThemes(*) {
        if this.Disposed
            return false
        return ApplyDarkWindow(this.Gui.Hwnd)
            && ApplyDarkControl(this.CurrentEdit.Hwnd)
            && ApplyDarkControl(this.ProposedEdit.Hwnd)
    }

    OnResize(guiObj, minMax, width, height) {
        if this.Disposed || minMax == -1 || width <= 0 || height <= 0
            return false
        margin := DarkTextComparisonDialog.Margin
        gap := DarkTextComparisonDialog.PaneGap
        paneWidth := Max(280, Floor((width - margin * 2 - gap) / 2))
        rightX := margin + paneWidth + gap
        rightWidth := Max(280, width - margin - rightX)
        buttonY := height - 46
        editHeight := Max(260, buttonY - 82)
        groupWidth := DarkTextComparisonDialog.ButtonWidth * 2
            + DarkTextComparisonDialog.ButtonGap
        firstButtonX := Floor((width - groupWidth) / 2)
        this.Summary.Move(margin, 14, width - margin * 2, 24)
        this.CurrentLabel.Move(margin, 46, paneWidth, 22)
        this.ProposedLabel.Move(rightX, 46, rightWidth, 22)
        this.CurrentEdit.Move(margin, 70, paneWidth, editHeight)
        this.ProposedEdit.Move(rightX, 70, rightWidth, editHeight)
        this.AcceptButton.Move(firstButtonX, buttonY,
            DarkTextComparisonDialog.ButtonWidth, 30)
        this.KeepButton.Move(firstButtonX
            + DarkTextComparisonDialog.ButtonWidth
            + DarkTextComparisonDialog.ButtonGap, buttonY,
            DarkTextComparisonDialog.ButtonWidth, 30)
        return true
    }

    Accept(*) {
        this.Accepted := true
        this.Dispose()
    }

    Cancel(*) {
        this.Accepted := false
        this.Dispose()
    }

    FormatComparisonControl(editControl, text, changedRanges,
            differenceColor, colors) {
        hwnd := editControl.Hwnd
        textLength := StrLen(text)
        lexer := AhkV2Lexer(text)
        tokens := lexer.GetTokens()
        selection := Buffer(8, 0)
        scrollPosition := Buffer(8, 0)
        SendMessage(0x0434, 0, selection.Ptr, , hwnd) ; EM_EXGETSEL
        SendMessage(0x04DD, 0, scrollPosition.Ptr, , hwnd) ; EM_GETSCROLLPOS
        SendMessage(0x000B, 0, 0, , hwnd) ; WM_SETREDRAW
        try {
            editControl.SetFont("s10", "Cascadia Mono")
            this.SetComparisonCharacterFormat(hwnd, 0, textLength,
                colors.Text)
            for token in tokens {
                color := this.ResolveSyntaxColor(token.Kind, colors)
                if color != ""
                    this.SetComparisonCharacterFormat(hwnd, token.Start,
                        token.End, color)
            }
            for range in changedRanges
                this.SetComparisonCharacterFormat(hwnd, range.Start,
                    range.End, "", differenceColor)
        } finally {
            SendMessage(0x0437, 0, selection.Ptr, , hwnd) ; EM_EXSETSEL
            SendMessage(0x04DE, 0, scrollPosition.Ptr, , hwnd)
            SendMessage(0x000B, 1, 0, , hwnd)
            DllCall("user32\InvalidateRect", "Ptr", hwnd, "Ptr", 0,
                "Int", 0)
        }
        return tokens.Length
    }

    SetComparisonCharacterFormat(hwnd, startPosition, endPosition,
            textColor := "", backgroundColor := "") {
        if endPosition <= startPosition
            return false
        selection := Buffer(8, 0)
        NumPut("Int", startPosition, selection, 0)
        NumPut("Int", endPosition, selection, 4)
        SendMessage(0x0437, 0, selection.Ptr, , hwnd) ; EM_EXSETSEL
        characterFormat := Buffer(116, 0) ; CHARFORMAT2W
        NumPut("UInt", characterFormat.Size, characterFormat, 0)
        mask := 0
        if textColor != "" {
            mask |= 0x40000000 ; CFM_COLOR
            NumPut("UInt", ColorRef(textColor), characterFormat, 20)
        }
        if backgroundColor != "" {
            mask |= 0x04000000 ; CFM_BACKCOLOR
            NumPut("UInt", ColorRef(backgroundColor), characterFormat, 96)
        }
        if !mask
            return false
        NumPut("UInt", mask, characterFormat, 4)
        return !!SendMessage(0x0444, 1, characterFormat.Ptr, , hwnd)
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
            case "Hotkey", "Hotstring": return colors.CodeHotkey
            case "Label": return colors.CodeLabel
            case "Builtin": return colors.CodeBuiltin
            case "Literal": return colors.CodeLiteral
            case "Escape": return colors.CodeEscape
            default: return ""
        }
    }

    static CalculateLineStats(currentText, proposedText) {
        return this.CalculateLineDiff(currentText, proposedText).Stats
    }

    static CalculateLineDiff(currentText, proposedText) {
        currentLines := this.SplitLineEntries(currentText)
        proposedLines := this.SplitLineEntries(proposedText)
        currentChanged := this.CreateLineFlags(currentLines.Length)
        proposedChanged := this.CreateLineFlags(proposedLines.Length)
        if currentLines.Length * proposedLines.Length
                <= DarkTextComparisonDialog.MaximumLcsCells
            this.MarkLcsDifferences(currentLines, proposedLines,
                currentChanged, proposedChanged)
        else
            this.MarkMiddleDifferences(currentLines, proposedLines,
                currentChanged, proposedChanged)
        currentChangedCount := this.CountLineFlags(currentChanged)
        proposedChangedCount := this.CountLineFlags(proposedChanged)
        return {
            CurrentRanges: this.BuildChangedLineRanges(currentLines,
                currentChanged),
            ProposedRanges: this.BuildChangedLineRanges(proposedLines,
                proposedChanged),
            Stats: {
                CurrentLines: currentLines.Length,
                ProposedLines: proposedLines.Length,
                ChangedLines: Max(currentChangedCount, proposedChangedCount)
            }
        }
    }

    static SplitLineEntries(text) {
        text := StrReplace(String(text), "`r", "")
        result := []
        textLength := StrLen(text)
        startPosition := 0
        searchPosition := 1
        loop {
            newlinePosition := InStr(text, "`n", true, searchPosition)
            if !newlinePosition {
                result.Push({Text: SubStr(text, startPosition + 1),
                    Start: startPosition, End: textLength})
                break
            }
            result.Push({Text: SubStr(text, startPosition + 1,
                    newlinePosition - startPosition - 1),
                Start: startPosition, End: newlinePosition})
            startPosition := newlinePosition
            searchPosition := newlinePosition + 1
            if searchPosition == textLength + 1 {
                result.Push({Text: "", Start: textLength, End: textLength})
                break
            }
        }
        return result
    }

    static CreateLineFlags(count) {
        flags := []
        Loop count
            flags.Push(false)
        return flags
    }

    static MarkLcsDifferences(currentLines, proposedLines,
            currentChanged, proposedChanged) {
        currentCount := currentLines.Length
        proposedCount := proposedLines.Length
        lengths := []
        Loop currentCount + 1 {
            row := []
            Loop proposedCount + 1
                row.Push(0)
            lengths.Push(row)
        }
        Loop currentCount {
            currentIndex := currentCount - A_Index + 1
            Loop proposedCount {
                proposedIndex := proposedCount - A_Index + 1
                lengths[currentIndex][proposedIndex] :=
                    currentLines[currentIndex].Text
                        == proposedLines[proposedIndex].Text
                    ? lengths[currentIndex + 1][proposedIndex + 1] + 1
                    : Max(lengths[currentIndex + 1][proposedIndex],
                        lengths[currentIndex][proposedIndex + 1])
            }
        }
        currentIndex := 1
        proposedIndex := 1
        while currentIndex <= currentCount
                && proposedIndex <= proposedCount {
            if currentLines[currentIndex].Text
                    == proposedLines[proposedIndex].Text {
                currentIndex++
                proposedIndex++
            } else if lengths[currentIndex + 1][proposedIndex]
                    >= lengths[currentIndex][proposedIndex + 1] {
                currentChanged[currentIndex] := true
                currentIndex++
            } else {
                proposedChanged[proposedIndex] := true
                proposedIndex++
            }
        }
        while currentIndex <= currentCount {
            currentChanged[currentIndex] := true
            currentIndex++
        }
        while proposedIndex <= proposedCount {
            proposedChanged[proposedIndex] := true
            proposedIndex++
        }
    }

    static MarkMiddleDifferences(currentLines, proposedLines,
            currentChanged, proposedChanged) {
        commonCount := Min(currentLines.Length, proposedLines.Length)
        prefixCount := 0
        while prefixCount < commonCount
                && currentLines[prefixCount + 1].Text
                    == proposedLines[prefixCount + 1].Text
            prefixCount++
        suffixCount := 0
        while suffixCount < currentLines.Length - prefixCount
                && suffixCount < proposedLines.Length - prefixCount
                && currentLines[currentLines.Length - suffixCount].Text
                    == proposedLines[proposedLines.Length - suffixCount].Text
            suffixCount++
        Loop currentLines.Length - prefixCount - suffixCount
            currentChanged[prefixCount + A_Index] := true
        Loop proposedLines.Length - prefixCount - suffixCount
            proposedChanged[prefixCount + A_Index] := true
    }

    static BuildChangedLineRanges(lines, flags) {
        ranges := []
        rangeStart := -1
        rangeEnd := -1
        for index, changed in flags {
            if changed {
                if rangeStart < 0
                    rangeStart := lines[index].Start
                rangeEnd := lines[index].End
            } else if rangeStart >= 0 {
                if rangeEnd > rangeStart
                    ranges.Push({Start: rangeStart, End: rangeEnd})
                rangeStart := -1
                rangeEnd := -1
            }
        }
        if rangeStart >= 0 && rangeEnd > rangeStart
            ranges.Push({Start: rangeStart, End: rangeEnd})
        return ranges
    }

    static CountLineFlags(flags) {
        count := 0
        for changed in flags
            if changed
                count++
        return count
    }

    static EnsureRichEditModule() {
        if DarkTextComparisonDialog.RichEditModule
            return DarkTextComparisonDialog.RichEditModule
        DarkTextComparisonDialog.RichEditModule := DllCall(
            "kernel32\LoadLibraryExW", "WStr", "Msftedit.dll", "Ptr", 0,
            "UInt", 0x00000800, "Ptr")
        if !DarkTextComparisonDialog.RichEditModule
            throw Error("无法加载 AI 结果审阅代码控件。")
        return DarkTextComparisonDialog.RichEditModule
    }
}
