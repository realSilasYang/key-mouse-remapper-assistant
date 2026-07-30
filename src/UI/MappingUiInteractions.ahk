class MappingUiInteractions {
    static SubclassId := 0x524D50
    static ClickMessage := 0x8052

    __New(guiObj, parentColor, svgRenderer := "") {
        this.Gui := guiObj
        this.Controls := Map()
        this.AttachedHwnds := Map()
        this.HoveredHwnd := 0
        this.PressedHwnd := 0
        this.PendingButtonClicks := Map()
        this.TextInputTargets := Map()
        this.FocusSinkHwnd := 0
        this.HandCursor := 0
        this.TextCursor := 0
        this.ArrowCursor := 0
        this.Disposed := false
        this.Painter := RoundedButtonPainter(parentColor)
        this.SvgRenderer := IsObject(svgRenderer) ? svgRenderer : ""
        this.Tooltip := ""
        this.SubclassMethod := ""
        this.SubclassCallback := 0
        this.DrawCallback := ""
        this.ClickCallback := ""
        this.PointerDownCallback := ""
        try {
            this.SubclassMethod := ObjBindMethod(this, "SubclassProc")
            this.SubclassCallback := CallbackCreate(this.SubclassMethod, "", 6)
            this.DrawCallback := ObjBindMethod(this, "OnDrawItem")
            this.ClickCallback := ObjBindMethod(this, "OnDeferredClick")
            this.PointerDownCallback := ObjBindMethod(this,
                "OnGlobalPointerDown")
            OnMessage(0x002B, this.DrawCallback)
            OnMessage(MappingUiInteractions.ClickMessage, this.ClickCallback)
            OnMessage(Win32.WM_LBUTTONDOWN, this.PointerDownCallback)
            OnMessage(Win32.WM_LBUTTONDBLCLK, this.PointerDownCallback)
        } catch as registrationError {
            this.Dispose()
            throw registrationError
        }
    }

    RegisterButton(control, normalColor, callback,
        hoverColor := "", pressedColor := "", multiline := false,
        textColor := "") {
        hwnd := control.Hwnd
        if !hwnd || !this.Painter.Ready
            return false
        ; Text 控件默认会把鼠标命中透传给父窗口。SS_NOTIFY(0x100)
        ; 必须在子类化前启用，否则自绘成功但永远收不到按下/松开消息。
        try control.Opt("+0x100 +0x10000") ; SS_NOTIFY | WS_TABSTOP
        catch
            return false
        if hoverColor == ""
            hoverColor := this.LightenColor(normalColor)
        if pressedColor == ""
            pressedColor := this.LightenColor(hoverColor, 0.08)
        if textColor == ""
            textColor := MappingWindow.Colors.Text
        state := {
            Kind: "button", Control: control, Callback: callback,
            Normal: normalColor, Hover: hoverColor, Pressed: pressedColor,
            Current: normalColor, TextColor: textColor,
            Multiline: multiline, Interactive: true,
            KeyboardGeneration: 0, SuppressNextActivation: false,
            TooltipText: ""
        }
        this.Controls[hwnd] := state
        if !this.Attach(hwnd) || !this.EnableOwnerDraw(control) {
            this.Detach(hwnd)
            ControlAccessibilityService.ClearButton(hwnd)
            this.Controls.Delete(hwnd)
            return false
        }
        ControlAccessibilityService.RegisterButton(hwnd, Tr("按下"))
        this.Redraw(hwnd)
        return true
    }

    SetButtonTooltip(control, text) {
        try hwnd := control.Hwnd
        catch
            return false
        if !this.Controls.Has(hwnd)
            return false
        state := this.Controls[hwnd]
        if state.Kind != "button"
            return false
        state.TooltipText := String(text)
        if state.TooltipText != ""
            this.EnsureTooltip()
        else if IsObject(this.Tooltip)
                && (this.HoveredHwnd == hwnd
                    || this.Tooltip.PendingHwnd == hwnd
                    || this.Tooltip.VisibleHwnd == hwnd)
            this.HideTooltip()
        return true
    }

    EnsureTooltip() {
        if !IsObject(this.Tooltip)
            this.Tooltip := DarkTooltipWindow(this.Gui)
        return this.Tooltip
    }

    HideTooltip() {
        if IsObject(this.Tooltip)
            this.Tooltip.Hide()
    }

    RegisterIconSurface(control, backgroundColor, iconColor := "") {
        hwnd := control.Hwnd
        if !hwnd || !this.Painter.Ready
            return false
        if iconColor == ""
            iconColor := MappingWindow.Colors.Hint
        state := {
            Kind: "icon", Control: control,
            Normal: backgroundColor, Hover: backgroundColor,
            Pressed: backgroundColor, Current: backgroundColor,
            TextColor: iconColor, Multiline: false, Interactive: false
        }
        this.Controls[hwnd] := state
        if !this.Attach(hwnd) || !this.EnableOwnerDraw(control) {
            this.Detach(hwnd)
            this.Controls.Delete(hwnd)
            return false
        }
        this.Redraw(hwnd)
        return true
    }

    RegisterHandCursor(control) {
        return this.RegisterCursorControl(control, "hand")
    }

    RegisterTextCursor(control) {
        return this.RegisterCursorControl(control, "text")
    }

    RegisterTextInput(inputControl, hitTarget := "") {
        try inputHwnd := inputControl.Hwnd
        catch
            return false
        if !inputHwnd
            return false
        this.Controls[inputHwnd] := {
            Kind: "text", Control: inputControl, TextInput: true
        }
        this.TextInputTargets[inputHwnd] := inputHwnd
        if !this.Attach(inputHwnd) {
            this.Controls.Delete(inputHwnd)
            this.TextInputTargets.Delete(inputHwnd)
            return false
        }
        if IsObject(hitTarget) {
            try hitTargetHwnd := hitTarget.Hwnd
            catch {
                this.Detach(inputHwnd)
                this.Controls.Delete(inputHwnd)
                this.TextInputTargets.Delete(inputHwnd)
                return false
            }
            if !hitTargetHwnd || !this.RegisterTextCursor(hitTarget) {
                this.Detach(inputHwnd)
                this.Controls.Delete(inputHwnd)
                this.TextInputTargets.Delete(inputHwnd)
                return false
            }
            this.TextInputTargets[hitTargetHwnd] := inputHwnd
        }
        return true
    }

    RegisterFocusRedirect(control, targetControl) {
        try hwnd := control.Hwnd
        catch
            return false
        try targetHwnd := targetControl.Hwnd
        catch
            return false
        if !hwnd || !targetHwnd
            return false
        this.Controls[hwnd] := {
            Kind: "focusRedirect", Control: control, TargetHwnd: targetHwnd
        }
        this.TextInputTargets[hwnd] := targetHwnd
        if this.Attach(hwnd)
            return true
        this.Controls.Delete(hwnd)
        this.TextInputTargets.Delete(hwnd)
        return false
    }

    SetFocusSink(control) {
        try hwnd := control.Hwnd
        catch
            return false
        if !hwnd
            return false
        this.FocusSinkHwnd := hwnd
        return true
    }

    RegisterCursorControl(control, cursorKind) {
        hwnd := control.Hwnd
        if !hwnd
            return false
        this.Controls[hwnd] := {Kind: cursorKind, Control: control}
        if this.Attach(hwnd)
            return true
        this.Controls.Delete(hwnd)
        return false
    }

    Attach(hwnd) {
        attached := !!DllCall("comctl32\SetWindowSubclass", "Ptr", hwnd,
            "Ptr", this.SubclassCallback, "UPtr", MappingUiInteractions.SubclassId,
            "UPtr", 0, "Int")
        if attached
            this.AttachedHwnds[hwnd] := true
        return attached
    }

    Detach(hwnd) {
        if !hwnd || !this.SubclassCallback || !this.AttachedHwnds.Has(hwnd)
            return true
        if !DllCall("user32\IsWindow", "Ptr", hwnd, "Int") {
            this.AttachedHwnds.Delete(hwnd)
            return true
        }
        detached := false
        try detached := !!DllCall("comctl32\RemoveWindowSubclass", "Ptr", hwnd,
            "Ptr", this.SubclassCallback, "UPtr", MappingUiInteractions.SubclassId,
            "Int")
        if detached
            this.AttachedHwnds.Delete(hwnd)
        return detached
    }

    EnableOwnerDraw(control) {
        hwnd := control.Hwnd
        style := DllCall("user32\GetWindowLongW", "Ptr", hwnd, "Int", -16, "Int")
        ownerDrawStyle := (style & ~0x1F) | 0x0D
        if ownerDrawStyle != style {
            DllCall("kernel32\SetLastError", "UInt", 0)
            previousStyle := DllCall("user32\SetWindowLongW", "Ptr", hwnd,
                "Int", -16, "Int", ownerDrawStyle, "Int")
            if !previousStyle && A_LastError
                return false
            DllCall("user32\SetWindowPos", "Ptr", hwnd, "Ptr", 0,
                "Int", 0, "Int", 0, "Int", 0, "Int", 0,
                "UInt", 0x0037, "Int")
        }
        return true
    }

    OnDrawItem(wParam, lParam, msg, hwnd) {
        if this.Disposed || !lParam
            return
        itemHwndOffset := A_PtrSize == 8 ? 24 : 20
        itemHwnd := NumGet(lParam, itemHwndOffset, "Ptr")
        if !this.Controls.Has(itemHwnd)
            return
        state := this.Controls[itemHwnd]
        if state.Kind != "button" && state.Kind != "icon"
            return
        hdcOffset := itemHwndOffset + A_PtrSize
        rectOffset := hdcOffset + A_PtrSize
        hdc := NumGet(lParam, hdcOffset, "Ptr")
        width := NumGet(lParam, rectOffset + 8, "Int")
            - NumGet(lParam, rectOffset, "Int")
        height := NumGet(lParam, rectOffset + 12, "Int")
            - NumGet(lParam, rectOffset + 4, "Int")
        if this.Painter.Draw(hdc, width, height, state)
            return 1
    }

    SubclassProc(hwnd, message, wParam, lParam, subclassId, referenceData) {
        try {
            if message == 0x0082 { ; WM_NCDESTROY
                this.RemoveControl(hwnd)
                if this.Disposed && !this.AttachedHwnds.Count
                    SetTimer(ObjBindMethod(this,
                        "ReleaseSubclassCallbackIfUnused"), -1)
                return this.DefSubclassProc(hwnd, message, wParam, lParam)
            }
            if !this.Controls.Has(hwnd)
                return this.DefSubclassProc(hwnd, message, wParam, lParam)
            state := this.Controls[hwnd]
            switch message {
                case Win32.WM_SETFOCUS:
                    if state.Kind == "focusRedirect" {
                        this.MoveKeyboardFocus(state.TargetHwnd)
                        return 0
                    }
                    if state.HasOwnProp("TextInput") && state.TextInput {
                        result := this.DefSubclassProc(hwnd, message,
                            wParam, lParam)
                        this.EnsureTextInputCaret(hwnd)
                        return result
                    }
                case Win32.WM_KILLFOCUS:
                    if state.HasOwnProp("TextInput") && state.TextInput {
                        result := this.DefSubclassProc(hwnd, message,
                            wParam, lParam)
                        try DllCall("user32\HideCaret", "Ptr", hwnd, "Int")
                        try DllCall("user32\DestroyCaret", "Int")
                        return result
                    }
                case 0x0200:
                    if state.Kind == "button" && state.Interactive
                        this.UpdateHover(hwnd)
                case 0x02A3:
                    if state.Kind == "button"
                        this.HandleMouseLeave(hwnd)
                case 0x0201, 0x0203:
                    if state.Kind == "focusRedirect" {
                        this.MoveKeyboardFocus(state.TargetHwnd)
                        return 0
                    }
                    if state.Kind == "icon"
                        return 0
                    if state.Kind != "text"
                        this.MoveKeyboardFocus(hwnd)
                    if state.Kind == "button" {
                        if !state.Interactive
                            return 0
                        this.BeginPress(hwnd)
                        return 0
                    }
                case 0x0202:
                    if state.Kind == "focusRedirect" {
                        this.MoveKeyboardFocus(state.TargetHwnd)
                        return 0
                    }
                    if state.Kind == "header" {
                        if this.IsClientPointInside(hwnd, lParam)
                            this.QueueClick(hwnd)
                        return 0
                    }
                    if state.Kind == "button" {
                        if !state.Interactive
                            return 0
                        this.EndPress(hwnd, lParam)
                        return 0
                    }
                case Win32.WM_KEYDOWN:
                    if state.Kind == "button" && state.Interactive
                            && (wParam == 0x0D || wParam == 0x20) {
                        ; bit 30 表示按键此前已按下；屏蔽自动重复，单次键盘操作
                        ; 与鼠标抬起一样只执行一次并保留 50ms 反馈。
                        if !(lParam & 0x40000000)
                            this.ActivateButtonFromKeyboard(hwnd)
                        return 0
                    }
                case 0x007B, 0x0301: ; WM_CONTEXTMENU / WM_COPY
                    if state.Kind == "header" || state.Kind == "focusRedirect"
                        return 0
                case 0x0020:
                    if state.Kind == "icon"
                        return this.DefSubclassProc(hwnd, message,
                            wParam, lParam)
                    if DllCall("user32\IsWindowEnabled", "Ptr", hwnd, "Int")
                            && (state.Kind != "button" || state.Interactive) {
                        this.SetCursor(state.Kind)
                        return 1
                    }
                case 0x001F:
                    if this.PressedHwnd == hwnd
                        this.CancelPress()
                case 0x0215:
                    if this.PressedHwnd == hwnd
                        this.CancelPress(false)
            }
        } catch {
            ; 原生窗口过程边界不允许 AHK 异常向外传播。
        }
        return this.DefSubclassProc(hwnd, message, wParam, lParam)
    }

    DefSubclassProc(hwnd, message, wParam, lParam) {
        return DllCall("comctl32\DefSubclassProc", "Ptr", hwnd,
            "UInt", message, "Ptr", wParam, "Ptr", lParam, "Ptr")
    }

    UpdateHover(hwnd) {
        if !this.Controls.Has(hwnd)
            return
        state := this.Controls[hwnd]
        if this.PressedHwnd {
            if this.PressedHwnd != hwnd
                return
            inside := this.IsPointerInside(hwnd)
            this.HoveredHwnd := inside ? hwnd : 0
            state.Current := inside ? state.Pressed : state.Normal
            this.Redraw(hwnd)
            return
        }
        if this.HoveredHwnd == hwnd
            return
        this.RestoreHovered()
        this.HoveredHwnd := hwnd
        state.Current := state.Hover
        this.TrackMouseLeave(hwnd)
        this.Redraw(hwnd)
        if state.TooltipText != ""
            this.EnsureTooltip().Schedule(hwnd, state.TooltipText)
        else
            this.HideTooltip()
    }

    HandleMouseLeave(hwnd) {
        if !this.Controls.Has(hwnd)
            return
        state := this.Controls[hwnd]
        if this.PressedHwnd == hwnd {
            if !this.IsPointerInside(hwnd) {
                this.HideTooltip()
                this.HoveredHwnd := 0
                state.Current := state.Normal
                this.Redraw(hwnd)
            }
            return
        }
        if this.HoveredHwnd == hwnd {
            this.HideTooltip()
            this.HoveredHwnd := 0
            state.Current := state.Normal
            this.Redraw(hwnd)
        }
    }

    BeginPress(hwnd) {
        if !this.Controls.Has(hwnd)
            return
        if this.PressedHwnd && this.PressedHwnd != hwnd
            this.CancelPress()
        this.HideTooltip()
        state := this.Controls[hwnd]
        this.PressedHwnd := hwnd
        this.HoveredHwnd := hwnd
        state.Current := state.Pressed
        this.TrackMouseLeave(hwnd)
        this.Redraw(hwnd)
        DllCall("user32\SetCapture", "Ptr", hwnd, "Ptr")
    }

    EndPress(hwnd, lParam) {
        if this.PressedHwnd != hwnd
            return
        this.PressedHwnd := 0
        inside := this.IsClientPointInside(hwnd, lParam)
        if DllCall("user32\GetCapture", "Ptr") == hwnd
            DllCall("user32\ReleaseCapture", "Int")
        if !this.Controls.Has(hwnd)
            return
        state := this.Controls[hwnd]
        if !inside {
            this.HideTooltip()
            this.HoveredHwnd := 0
            state.Current := state.Normal
            this.Redraw(hwnd)
            return
        }
        this.HoveredHwnd := hwnd
        state.Current := state.Hover
        this.TrackMouseLeave(hwnd)
        this.Redraw(hwnd)
        this.QueueClick(hwnd)
    }

    EnsureTextInputCaret(hwnd) {
        if !hwnd || DllCall("user32\GetFocus", "Ptr") != hwnd
            return false
        ; 原生 Edit 通常已建立 caret；ShowCaret 成功时只需沿用其形状与位置。
        if DllCall("user32\ShowCaret", "Ptr", hwnd, "Int")
            return true
        clientRect := Buffer(16, 0)
        if !DllCall("user32\GetClientRect", "Ptr", hwnd,
                "Ptr", clientRect, "Int")
            return false
        clientHeight := NumGet(clientRect, 12, "Int")
        caretHeight := this.GetTextInputCaretHeight(hwnd, clientHeight)
        if !DllCall("user32\CreateCaret", "Ptr", hwnd, "Ptr", 0,
                "Int", 1, "Int", caretHeight, "Int")
            return false
        selectionStart := Buffer(4, 0)
        selectionEnd := Buffer(4, 0)
        SendMessage(Win32.EM_GETSEL, selectionStart.Ptr,
            selectionEnd.Ptr, , hwnd)
        characterIndex := NumGet(selectionEnd, 0, "UInt")
        packedPosition := SendMessage(0x00D6, characterIndex, 0, , hwnd)
        caretX := packedPosition & 0xFFFF
        caretY := (packedPosition >> 16) & 0xFFFF
        if caretX & 0x8000
            caretX -= 0x10000
        if caretY & 0x8000
            caretY -= 0x10000
        DllCall("user32\SetCaretPos", "Int", Max(0, caretX),
            "Int", Max(0, caretY), "Int")
        return !!DllCall("user32\ShowCaret", "Ptr", hwnd, "Int")
    }

    GetTextInputCaretHeight(hwnd, clientHeight) {
        style := DllCall("user32\GetWindowLongW", "Ptr", hwnd,
            "Int", -16, "Int")
        if !(style & 0x0004) ; ES_MULTILINE
            return Max(1, clientHeight - 4)
        deviceContext := DllCall("user32\GetDC", "Ptr", hwnd, "Ptr")
        if !deviceContext
            return Max(1, Min(clientHeight - 2, 18))
        fontHandle := SendMessage(Win32.WM_GETFONT, 0, 0, , hwnd)
        previousFont := fontHandle ? DllCall("gdi32\SelectObject", "Ptr",
            deviceContext, "Ptr", fontHandle, "Ptr") : 0
        textMetrics := Buffer(60, 0)
        try {
            if DllCall("gdi32\GetTextMetricsW", "Ptr", deviceContext,
                    "Ptr", textMetrics, "Int")
                return Max(1, Min(clientHeight - 2,
                    NumGet(textMetrics, 0, "Int")))
            return Max(1, Min(clientHeight - 2, 18))
        } finally {
            if previousFont
                DllCall("gdi32\SelectObject", "Ptr", deviceContext,
                    "Ptr", previousFont, "Ptr")
            DllCall("user32\ReleaseDC", "Ptr", hwnd,
                "Ptr", deviceContext)
        }
    }

    OnGlobalPointerDown(wParam, lParam, msg, hwnd) {
        if this.Disposed || !hwnd || !this.Gui || !this.Gui.Hwnd
            return
        rootHwnd := DllCall("user32\GetAncestor", "Ptr", hwnd,
            "UInt", 2, "Ptr") ; GA_ROOT
        if rootHwnd != this.Gui.Hwnd || this.IsTextInputTarget(hwnd)
            return
        focusedHwnd := DllCall("user32\GetFocus", "Ptr")
        if !this.IsTextInputTarget(focusedHwnd)
            return
        focusTarget := this.FocusSinkHwnd
        if !focusTarget || !DllCall("user32\IsWindow", "Ptr", focusTarget,
                "Int") || !DllCall("user32\IsWindowEnabled", "Ptr",
                focusTarget, "Int")
            focusTarget := hwnd != this.Gui.Hwnd ? hwnd : this.Gui.Hwnd
        DllCall("user32\SetFocus", "Ptr", focusTarget, "Ptr")
    }

    IsTextInputTarget(hwnd) {
        if !hwnd || !this.TextInputTargets.Has(hwnd)
            return false
        targetHwnd := this.TextInputTargets[hwnd]
        if DllCall("user32\IsWindow", "Ptr", hwnd, "Int")
                && DllCall("user32\IsWindow", "Ptr", targetHwnd, "Int")
            return true
        this.TextInputTargets.Delete(hwnd)
        return false
    }

    QueueClick(hwnd) {
        if this.Controls.Has(hwnd)
                && this.Controls[hwnd].Kind == "button" {
            state := this.Controls[hwnd]
            if state.SuppressNextActivation {
                state.SuppressNextActivation := false
                if this.PendingButtonClicks.Has(hwnd)
                    this.PendingButtonClicks.Delete(hwnd)
                return false
            }
            if this.PendingButtonClicks.Has(hwnd)
                return
            this.PendingButtonClicks[hwnd] := true
        }
        if !DllCall("user32\PostMessageW", "Ptr", this.Gui.Hwnd,
                "UInt", MappingUiInteractions.ClickMessage, "Ptr", hwnd,
                "Ptr", 0, "Int")
            SetTimer(ObjBindMethod(this, "RunQueuedClick", hwnd), -1)
        return true
    }

    SuppressNextButtonActivation(hwnd) {
        if this.Disposed || !this.Controls.Has(hwnd)
            return false
        state := this.Controls[hwnd]
        if state.Kind != "button"
            return false
        state.SuppressNextActivation := true
        return true
    }

    ScheduleSuppressedButtonActivationReset(delayMs := 100) {
        if this.Disposed
            return false
        delayMs := Max(1, Integer(delayMs))
        SetTimer(ObjBindMethod(this, "ResetSuppressedButtonActivations"),
            -delayMs)
        return true
    }

    ResetSuppressedButtonActivations(*) {
        if this.Disposed
            return false
        for hwnd, state in this.Controls {
            if state.Kind == "button"
                    && state.HasOwnProp("SuppressNextActivation")
                state.SuppressNextActivation := false
        }
        return true
    }

    IsClientPointInside(hwnd, lParam) {
        clientRect := Buffer(16, 0)
        if !DllCall("user32\GetClientRect", "Ptr", hwnd, "Ptr", clientRect, "Int")
            return false
        x := lParam & 0xFFFF
        y := (lParam >> 16) & 0xFFFF
        if x & 0x8000
            x -= 0x10000
        if y & 0x8000
            y -= 0x10000
        return x >= 0 && y >= 0
            && x < NumGet(clientRect, 8, "Int")
            && y < NumGet(clientRect, 12, "Int")
    }

    OnDeferredClick(wParam, lParam, msg, hwnd) {
        if this.Disposed || hwnd != this.Gui.Hwnd
            return
        this.RunQueuedClick(wParam)
        return 0
    }

    RunQueuedClick(hwnd, *) {
        if this.PendingButtonClicks.Has(hwnd)
            this.PendingButtonClicks.Delete(hwnd)
        this.RunClick(hwnd)
    }

    RunClick(hwnd, *) {
        if this.Disposed || !this.Controls.Has(hwnd)
            return
        state := this.Controls[hwnd]
        if state.Kind == "button" && !state.Interactive
            return
        if state.Kind == "button"
            && DllCall("user32\IsWindowEnabled", "Ptr", hwnd, "Int") {
            this.MoveKeyboardFocus(hwnd)
            state.Callback.Call()
        }
    }

    ActivateButtonFromKeyboard(hwnd) {
        if this.Disposed || !this.Controls.Has(hwnd)
            return false
        state := this.Controls[hwnd]
        if state.Kind != "button" || !state.Interactive
            return false
        state.KeyboardGeneration++
        generation := state.KeyboardGeneration
        state.Current := state.Pressed
        this.Redraw(hwnd)
        this.QueueClick(hwnd)
        SetTimer(ObjBindMethod(this, "ResetKeyboardFeedback", hwnd,
            generation), -50)
        return true
    }

    ResetKeyboardFeedback(hwnd, generation, *) {
        if this.Disposed || !this.Controls.Has(hwnd)
            return
        state := this.Controls[hwnd]
        if state.Kind != "button" || state.KeyboardGeneration != generation
            return
        state.Current := state.Interactive && this.IsPointerInside(hwnd)
            ? state.Hover : state.Normal
        this.Redraw(hwnd)
    }

    SetTextNoErase(control, text) {
        text := String(text)
        if control.Text == text
            return false
        DllCall("user32\SendMessageW", "Ptr", control.Hwnd,
            "UInt", 0x000B, "UPtr", 0, "Ptr", 0, "Ptr") ; WM_SETREDRAW
        try control.Text := text
        finally DllCall("user32\SendMessageW", "Ptr", control.Hwnd,
            "UInt", 0x000B, "UPtr", 1, "Ptr", 0, "Ptr")
        this.Redraw(control.Hwnd) ; RDW_INVALIDATE | RDW_NOERASE | RDW_UPDATENOW
        return true
    }

    MoveKeyboardFocus(hwnd) {
        if hwnd && DllCall("user32\GetFocus", "Ptr") != hwnd
            DllCall("user32\SetFocus", "Ptr", hwnd, "Ptr")
    }

    CancelPress(releaseCapture := true) {
        this.HideTooltip()
        hwnd := this.PressedHwnd
        this.PressedHwnd := 0
        if !hwnd
            return
        if this.Controls.Has(hwnd) {
            state := this.Controls[hwnd]
            state.Current := state.Normal
            this.Redraw(hwnd)
        }
        if this.HoveredHwnd == hwnd
            this.HoveredHwnd := 0
        if releaseCapture && DllCall("user32\GetCapture", "Ptr") == hwnd
            DllCall("user32\ReleaseCapture", "Int")
    }

    RestoreHovered() {
        this.HideTooltip()
        hwnd := this.HoveredHwnd
        this.HoveredHwnd := 0
        if hwnd && this.Controls.Has(hwnd) {
            state := this.Controls[hwnd]
            if state.Kind == "button" {
                state.Current := state.Normal
                this.Redraw(hwnd)
            }
        }
    }

    SetButtonColor(control, normalColor) {
        return this.SetButtonAppearance(control, normalColor)
    }

    SetButtonAppearance(control, normalColor, textColor := "",
            interactive := true, hoverColor := "", pressedColor := "") {
        hwnd := control.Hwnd
        if !this.Controls.Has(hwnd)
            return false
        state := this.Controls[hwnd]
        if state.Kind != "button"
            return false
        state.Normal := normalColor
        state.Hover := interactive
            ? (hoverColor != "" ? hoverColor : this.LightenColor(normalColor))
            : normalColor
        state.Pressed := interactive
            ? (pressedColor != "" ? pressedColor
                : this.LightenColor(state.Hover, 0.08))
            : normalColor
        state.Interactive := !!interactive
        if textColor != "" {
            state.TextColor := textColor
            this.RefreshAutomaticIconTint(state)
        }
        if !state.Interactive {
            if this.PressedHwnd == hwnd
                this.CancelPress()
            if this.HoveredHwnd == hwnd {
                this.HideTooltip()
                this.HoveredHwnd := 0
            }
        }
        state.Current := this.PressedHwnd == hwnd ? state.Pressed
            : (this.HoveredHwnd == hwnd ? state.Hover : state.Normal)
        this.Redraw(hwnd)
        return true
    }

    SetParentColor(color) {
        this.Painter.SetParentColor(color)
        if IsObject(this.Tooltip)
            this.Tooltip.InvalidateTheme()
    }

    SetControlSvgIcon(control, svgPath, sizeDip := 14, gapDip := 7,
            tintColor := "none") {
        image := this.BuildControlSvgImage(control, svgPath, sizeDip, gapDip,
            tintColor)
        if !IsObject(image)
            return false
        state := this.Controls[control.Hwnd]
        state.ButtonImage := image
        this.Redraw(control.Hwnd)
        return true
    }

    BuildControlSvgImage(control, svgPath, sizeDip := 14, gapDip := 7,
            tintColor := "none") {
        hwnd := control.Hwnd
        if !this.Controls.Has(hwnd) || !IsObject(this.SvgRenderer)
            return 0
        state := this.Controls[hwnd]
        if (state.Kind != "button" && state.Kind != "icon")
                || !FileExist(svgPath)
            return 0
        windowDpi := DllCall("user32\GetDpiForWindow", "Ptr", hwnd, "UInt")
        if !windowDpi
            windowDpi := 96
        targetPixels := Max(1, Round(sizeDip * windowDpi / 96))
        snapshot := this.SvgRenderer.RenderFile(svgPath, windowDpi,
            Max(64, Min(512, targetPixels * 4)))
        if !snapshot
            return 0
        tintMode := StrLower(Trim(String(tintColor)))
        resolvedTint := tintMode == "auto" ? state.TextColor : tintColor
        displaySnapshot := tintMode == "none"
            ? snapshot : this.TintIconSnapshot(snapshot, resolvedTint)
        if !displaySnapshot
            return 0
        return {
            Width: displaySnapshot.Width, Height: displaySnapshot.Height,
            Pixels: displaySnapshot.Pixels, SizeDip: sizeDip,
            GapDip: gapDip, SourcePath: svgPath,
            SourceSnapshot: snapshot, TintMode: tintMode
        }
    }

    SetIconSurfaceAppearance(control, backgroundColor, iconColor := "") {
        hwnd := control.Hwnd
        if !this.Controls.Has(hwnd)
            return false
        state := this.Controls[hwnd]
        if state.Kind != "icon"
            return false
        state.Normal := backgroundColor
        state.Hover := backgroundColor
        state.Pressed := backgroundColor
        state.Current := backgroundColor
        if iconColor != "" {
            state.TextColor := iconColor
            this.RefreshAutomaticIconTint(state)
        }
        this.Redraw(hwnd)
        return true
    }

    SetButtonSvgIcon(control, svgPath, sizeDip := 14, gapDip := 7,
            tintColor := "none") {
        return this.SetControlSvgIcon(control, svgPath, sizeDip, gapDip,
            tintColor)
    }

    SetControlTrailingSvgIcon(control, svgPath, sizeDip := 14, gapDip := 7,
            tintColor := "none") {
        image := this.BuildControlSvgImage(control, svgPath, sizeDip, gapDip,
            tintColor)
        if !IsObject(image)
            return false
        state := this.Controls[control.Hwnd]
        state.TrailingButtonImage := image
        this.Redraw(control.Hwnd)
        return true
    }

    SetButtonTrailingSvgIcon(control, svgPath, sizeDip := 14, gapDip := 7,
            tintColor := "none") {
        return this.SetControlTrailingSvgIcon(control, svgPath, sizeDip,
            gapDip, tintColor)
    }

    SetControlLucideIcon(control, iconName, sizeDip := 14, gapDip := 7,
            tintColor := "none") {
        iconName := String(iconName)
        if iconName == "" || InStr(iconName, "\") || InStr(iconName, "/")
            return false
        return this.SetControlSvgIcon(control, GetApplicationAssetPath(
            "ui-icons\lucide\" iconName), sizeDip, gapDip, tintColor)
    }

    SetButtonLucideIcon(control, iconName, sizeDip := 14, gapDip := 7,
            tintColor := "none") {
        return this.SetControlLucideIcon(control, iconName, sizeDip, gapDip,
            tintColor)
    }

    SetControlTrailingLucideIcon(control, iconName, sizeDip := 14,
            gapDip := 7, tintColor := "none") {
        iconName := String(iconName)
        if iconName == "" || InStr(iconName, "\") || InStr(iconName, "/")
            return false
        return this.SetControlTrailingSvgIcon(control, GetApplicationAssetPath(
            "ui-icons\lucide\" iconName), sizeDip, gapDip, tintColor)
    }

    SetButtonTrailingLucideIcon(control, iconName, sizeDip := 14,
            gapDip := 7, tintColor := "none") {
        return this.SetControlTrailingLucideIcon(control, iconName, sizeDip,
            gapDip, tintColor)
    }

    SetButtonLucideIcons(control, leadingIconName, trailingIconName,
            sizeDip := 14, gapDip := 7, leadingTintColor := "none",
            trailingTintColor := "none") {
        if !this.Controls.Has(control.Hwnd)
                || this.Controls[control.Hwnd].Kind != "button"
            return false
        leadingIconName := String(leadingIconName)
        trailingIconName := String(trailingIconName)
        if leadingIconName == "" || trailingIconName == ""
                || InStr(leadingIconName, "\") || InStr(leadingIconName, "/")
                || InStr(trailingIconName, "\") || InStr(trailingIconName, "/")
            return false
        leadingImage := this.BuildControlSvgImage(control,
            GetApplicationAssetPath("ui-icons\lucide\" leadingIconName),
            sizeDip, gapDip, leadingTintColor)
        trailingImage := this.BuildControlSvgImage(control,
            GetApplicationAssetPath("ui-icons\lucide\" trailingIconName),
            sizeDip, gapDip, trailingTintColor)
        if !IsObject(leadingImage) || !IsObject(trailingImage)
            return false
        state := this.Controls[control.Hwnd]
        state.ButtonImage := leadingImage
        state.TrailingButtonImage := trailingImage
        this.Redraw(control.Hwnd)
        return true
    }

    ClearControlIcon(control) {
        hwnd := control.Hwnd
        if !this.Controls.Has(hwnd)
            return false
        state := this.Controls[hwnd]
        cleared := false
        for propertyName in ["ButtonImage", "TrailingButtonImage"] {
            if state.HasOwnProp(propertyName) {
                state.DeleteProp(propertyName)
                cleared := true
            }
        }
        if !cleared
            return false
        this.Redraw(hwnd)
        return true
    }

    ClearButtonIcon(control) => this.ClearControlIcon(control)

    ClearControlTrailingIcon(control) {
        hwnd := control.Hwnd
        if !this.Controls.Has(hwnd)
            return false
        state := this.Controls[hwnd]
        if !state.HasOwnProp("TrailingButtonImage")
            return false
        state.DeleteProp("TrailingButtonImage")
        this.Redraw(hwnd)
        return true
    }

    ClearButtonTrailingIcon(control) => this.ClearControlTrailingIcon(control)

    RefreshAutomaticIconTint(state) {
        refreshed := false
        for propertyName in ["ButtonImage", "TrailingButtonImage"] {
            if !state.HasOwnProp(propertyName)
                continue
            image := state.%propertyName%
            if !image.HasOwnProp("TintMode") || image.TintMode != "auto"
                continue
            tinted := this.TintIconSnapshot(image.SourceSnapshot,
                state.TextColor)
            if !tinted
                continue
            image.Width := tinted.Width
            image.Height := tinted.Height
            image.Pixels := tinted.Pixels
            refreshed := true
        }
        return refreshed
    }

    TintIconSnapshot(snapshot, color) {
        normalized := Trim(String(color))
        if SubStr(normalized, 1, 1) == "#"
            normalized := SubStr(normalized, 2)
        if StrLower(SubStr(normalized, 1, 2)) == "0x"
            normalized := SubStr(normalized, 3)
        if !RegExMatch(normalized, "i)^[0-9a-f]{6}$")
            return 0
        value := Integer("0x" normalized)
        red := (value >> 16) & 0xFF
        green := (value >> 8) & 0xFF
        blue := value & 0xFF
        pixels := Buffer(snapshot.Width * snapshot.Height * 4, 0)
        Loop snapshot.Width * snapshot.Height {
            offset := (A_Index - 1) * 4
            alpha := NumGet(snapshot.Pixels, offset + 3, "UChar")
            if !alpha
                continue
            NumPut("UChar", Round(blue * alpha / 255), pixels, offset)
            NumPut("UChar", Round(green * alpha / 255), pixels, offset + 1)
            NumPut("UChar", Round(red * alpha / 255), pixels, offset + 2)
            NumPut("UChar", alpha, pixels, offset + 3)
        }
        return {Width: snapshot.Width, Height: snapshot.Height,
            Pixels: pixels}
    }

    LightenColor(color, ratio := 0.12) {
        value := Integer("0x" color)
        red := Round(((value >> 16) & 0xFF) * (1 - ratio) + 255 * ratio)
        green := Round(((value >> 8) & 0xFF) * (1 - ratio) + 255 * ratio)
        blue := Round((value & 0xFF) * (1 - ratio) + 255 * ratio)
        return Format("{:02X}{:02X}{:02X}", red, green, blue)
    }

    DarkenColor(color, factor := 0.86) {
        value := Integer("0x" color)
        red := Round(((value >> 16) & 0xFF) * factor)
        green := Round(((value >> 8) & 0xFF) * factor)
        blue := Round((value & 0xFF) * factor)
        return Format("{:02X}{:02X}{:02X}", red, green, blue)
    }

    SetCursor(kind) {
        if kind == "text" {
            if !this.TextCursor
                this.TextCursor := DllCall("user32\LoadCursor", "Ptr", 0,
                    "Ptr", 32513, "Ptr")
            cursor := this.TextCursor
        } else if kind == "focusRedirect" {
            if !this.ArrowCursor
                this.ArrowCursor := DllCall("user32\LoadCursor", "Ptr", 0,
                    "Ptr", 32512, "Ptr")
            cursor := this.ArrowCursor
        } else {
            if !this.HandCursor
                this.HandCursor := DllCall("user32\LoadCursor", "Ptr", 0,
                    "Ptr", 32649, "Ptr")
            cursor := this.HandCursor
        }
        if cursor
            DllCall("user32\SetCursor", "Ptr", cursor)
    }

    IsPointerInside(hwnd) {
        point := Buffer(8, 0)
        rect := Buffer(16, 0)
        if !DllCall("user32\GetCursorPos", "Ptr", point, "Int")
            || !DllCall("user32\GetWindowRect", "Ptr", hwnd, "Ptr", rect, "Int")
            return false
        x := NumGet(point, 0, "Int")
        y := NumGet(point, 4, "Int")
        return x >= NumGet(rect, 0, "Int") && x < NumGet(rect, 8, "Int")
            && y >= NumGet(rect, 4, "Int") && y < NumGet(rect, 12, "Int")
    }

    TrackMouseLeave(hwnd) {
        size := A_PtrSize == 8 ? 24 : 16
        tracking := Buffer(size, 0)
        NumPut("UInt", size, tracking, 0)
        NumPut("UInt", 0x00000002, tracking, 4)
        NumPut("Ptr", hwnd, tracking, 8)
        try DllCall("user32\TrackMouseEvent", "Ptr", tracking)
    }

    Redraw(hwnd) {
        if hwnd && DllCall("user32\IsWindow", "Ptr", hwnd, "Int")
            DllCall("user32\RedrawWindow", "Ptr", hwnd,
                "Ptr", 0, "Ptr", 0, "UInt", 0x0121, "Int")
    }

    RemoveControl(hwnd) {
        if IsObject(this.Tooltip)
                && (this.Tooltip.PendingHwnd == hwnd
                    || this.Tooltip.VisibleHwnd == hwnd)
            this.HideTooltip()
        if this.PressedHwnd == hwnd
            this.PressedHwnd := 0
        if this.HoveredHwnd == hwnd
            this.HoveredHwnd := 0
        if this.Controls.Has(hwnd)
            this.Controls.Delete(hwnd)
        if this.TextInputTargets.Has(hwnd)
            this.TextInputTargets.Delete(hwnd)
        if this.PendingButtonClicks.Has(hwnd)
            this.PendingButtonClicks.Delete(hwnd)
        ControlAccessibilityService.ClearButton(hwnd)
        if this.AttachedHwnds.Has(hwnd)
            this.AttachedHwnds.Delete(hwnd)
    }

    Dispose() {
        if !this.Disposed {
            this.Disposed := true
            this.CancelPress()
            try OnMessage(0x002B, this.DrawCallback, 0)
            try OnMessage(MappingUiInteractions.ClickMessage, this.ClickCallback, 0)
            try OnMessage(Win32.WM_LBUTTONDOWN, this.PointerDownCallback, 0)
            try OnMessage(Win32.WM_LBUTTONDBLCLK, this.PointerDownCallback, 0)
            this.DrawCallback := ""
            this.ClickCallback := ""
            this.PointerDownCallback := ""
            if IsObject(this.Tooltip)
                this.Tooltip.Dispose()
            this.Tooltip := ""
            for controlHwnd, state in this.Controls {
                if state.Kind == "button"
                    ControlAccessibilityService.ClearButton(controlHwnd)
            }
            this.Controls.Clear()
            this.TextInputTargets.Clear()
            this.PendingButtonClicks.Clear()
            this.FocusSinkHwnd := 0
            this.Painter.Shutdown()
            this.Painter := ""
            this.SvgRenderer := ""
            this.Gui := ""
        }
        attachedHwnds := []
        for hwnd, attachmentState in this.AttachedHwnds
            attachedHwnds.Push(hwnd)
        for hwnd in attachedHwnds
            this.Detach(hwnd)
        this.ReleaseSubclassCallbackIfUnused()
        return !this.AttachedHwnds.Count
    }

    ReleaseSubclassCallbackIfUnused(*) {
        if this.AttachedHwnds.Count || !this.SubclassCallback
            return false
        CallbackFree(this.SubclassCallback)
        this.SubclassCallback := 0
        this.SubclassMethod := ""
        return true
    }
}
