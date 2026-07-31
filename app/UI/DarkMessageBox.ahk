; Blocking confirmation dialog using the application's theme, button painter,
; accessibility semantics, icon identity, and modal ownership rules.
ShowDarkConfirmBox(message, title, confirmText, cancelText, ownerGui := "") {
    dialog := DarkConfirmDialog(message, title, confirmText, cancelText,
        ownerGui)
    return dialog.Show()
}

class DarkConfirmDialog {
    __New(message, title, confirmText, cancelText, ownerGui) {
        this.Message := String(message)
        this.Title := String(title)
        this.ConfirmText := String(confirmText)
        this.CancelText := String(cancelText)
        this.OwnerGui := ownerGui
        this.Gui := ""
        this.OwnerLease := ""
        this.Interactions := ""
        this.IconHandles := []
        this.Accepted := false
        this.Disposed := false
        try this.Build()
        catch as buildError {
            try this.Dispose(false)
            throw buildError
        }
    }

    Build() {
        colors := UiThemeService.GetPalette()
        windowWidth := LocalizationService.UsesCompactLayout() ? 420 : 520
        guiOptions := "-MinimizeBox -MaximizeBox +OwnDialogs"
        if this.IsOwnerAlive() {
            guiOptions .= " +Owner" this.OwnerGui.Hwnd
        }
        this.Gui := Gui(guiOptions, this.Title)
        this.IconHandles := ApplyApplicationWindowIcon(this.Gui.Hwnd)
        if this.IsOwnerAlive() {
            this.OwnerLease := WindowHierarchy.Acquire(this.OwnerGui,
                this.Gui.Hwnd)
            if !this.OwnerLease
                throw Error("无法建立确认窗口层级。")
        }
        this.Gui.BackColor := colors.Window
        this.Gui.MarginX := 0
        this.Gui.MarginY := 0
        this.Interactions := MappingUiInteractions(this.Gui, colors.Window)

        contentTop := 22
        iconX := 22
        iconWidth := 34
        messageX := 70
        messageWidth := windowWidth - messageX - 24
        this.Gui.SetFont("s18 c" colors.Text, "Segoe UI Emoji")
        this.TypeIcon := this.Gui.Add("Text", "x" iconX " y" contentTop
            " w" iconWidth " h34 Center 0x200 BackgroundTrans", "⚠️")
        this.Gui.SetFont("norm s10 c" colors.Text,
            LocalizationService.GetUiFontName())
        this.MessageText := this.Gui.Add("Text", "x" messageX " y"
            contentTop " w" messageWidth " +Wrap BackgroundTrans",
            this.Message)
        this.MessageText.GetPos(, , , &messageHeight)
        rowHeight := Max(34, messageHeight)
        this.TypeIcon.Move(, contentTop + Floor((rowHeight - 34) / 2))
        this.MessageText.Move(, contentTop
            + Floor((rowHeight - messageHeight) / 2))

        minimumButtonWidth := LocalizationService.UsesCompactLayout()
            ? 116 : 148
        buttonGap := 12
        buttonY := contentTop + rowHeight + 22
        this.ConfirmButton := this.AddButton(0, buttonY, minimumButtonWidth,
            this.ConfirmText, colors.Primary, colors.ButtonText,
            ObjBindMethod(this, "Confirm"))
        this.CancelButton := this.AddButton(0, buttonY, minimumButtonWidth,
            this.CancelText, colors.Toolbar,
            colors.ToolbarText, ObjBindMethod(this, "Cancel"))
        primaryButtonWidth := this.MeasureRequiredButtonWidth(
            this.ConfirmButton,
            minimumButtonWidth)
        secondaryButtonWidth := this.MeasureRequiredButtonWidth(
            this.CancelButton,
            minimumButtonWidth)
        buttonGroupWidth := primaryButtonWidth + buttonGap
            + secondaryButtonWidth
        if buttonGroupWidth > windowWidth - 40 {
            windowWidth := buttonGroupWidth + 40
            this.MessageText.Move(, , windowWidth - messageX - 24)
        }
        firstX := Floor((windowWidth - buttonGroupWidth) / 2)
        this.ConfirmButton.Move(firstX, , primaryButtonWidth)
        this.CancelButton.Move(firstX + primaryButtonWidth + buttonGap,
            , secondaryButtonWidth)
        this.WindowWidth := windowWidth
        this.WindowHeight := buttonY + 30 + 18
        this.Gui.OnEvent("Close", ObjBindMethod(this, "Cancel"))
        this.Gui.OnEvent("Escape", ObjBindMethod(this, "Cancel"))
    }

    AddButton(x, y, width, text, color, textColor, callback) {
        button := this.Gui.Add("Text", "x" x " y" y " w" width
            " h30 Center 0x200 Background" color " c" textColor, text)
        button.SetFont("s10 bold",
            LocalizationService.GetLanguageSystemUiFontName())
        if !this.Interactions.RegisterButton(button, color, callback,
                "", "", false, textColor)
            button.OnEvent("Click", callback)
        return button
    }

    MeasureRequiredButtonWidth(button, minimumWidthDip) {
        deviceContext := DllCall("user32\GetDC", "Ptr", button.Hwnd, "Ptr")
        if !deviceContext
            return minimumWidthDip
        fontHandle := SendMessage(Win32.WM_GETFONT, 0, 0, , button.Hwnd)
        previousFont := fontHandle ? DllCall("gdi32\SelectObject", "Ptr",
            deviceContext, "Ptr", fontHandle, "Ptr") : 0
        extent := Buffer(8, 0)
        try {
            if !DllCall("gdi32\GetTextExtentPoint32W", "Ptr", deviceContext,
                    "Str", button.Text, "Int", StrLen(button.Text),
                    "Ptr", extent, "Int")
                return minimumWidthDip
            windowDpi := DllCall("user32\GetDpiForWindow", "Ptr",
                button.Hwnd, "UInt")
            if !windowDpi
                windowDpi := 96
            textWidthDip := Ceil(NumGet(extent, 0, "Int") * 96 / windowDpi)
            return Max(minimumWidthDip, textWidthDip + 24)
        } finally {
            if previousFont
                DllCall("gdi32\SelectObject", "Ptr", deviceContext,
                    "Ptr", previousFont, "Ptr")
            DllCall("user32\ReleaseDC", "Ptr", button.Hwnd,
                "Ptr", deviceContext)
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

    ApplyNativeThemes(*) {
        if this.Disposed
            return false
        return ApplyDarkWindow(this.Gui.Hwnd)
    }

    Confirm(*) {
        this.Accepted := true
        this.Dispose()
    }

    Cancel(*) {
        this.Accepted := false
        this.Dispose()
    }

    IsOwnerAlive() {
        return IsObject(this.OwnerGui) && Type(this.OwnerGui) == "Gui"
            && WindowHierarchy.IsGuiAlive(this.OwnerGui)
    }

    Dispose(activateOwner := true) {
        if this.Disposed
            return
        this.Disposed := true
        cleanup := CleanupCollector("确认窗口")
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
        if !this.OwnerLease
            this.OwnerGui := ""
        cleanup.Complete()
        return true
    }
}
