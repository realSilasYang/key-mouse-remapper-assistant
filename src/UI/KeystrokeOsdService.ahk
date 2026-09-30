/*
================================================================================
    按键实时可视化服务 (Keystroke OSD Service)
    监听物理按键与组合键并在屏幕边缘显示平滑淡出的悬浮卡片。
================================================================================
*/

class KeystrokeOsdService {
    static DefaultGuiColor := "2e3032"
    static DefaultFontColor := "b3aea8"
    static DefaultFontSize := 12
    static DefaultFontType := "Segoe UI"
    static DefaultPosition := "bottom-left"
    static DefaultRoundness := 60
    static DefaultDisplayTime := 1000
    static DefaultFadeDuration := 200
    static DefaultBottomMargin := 0
    static DefaultLeftMargin := 0
    static DefaultWidthPadding := 20
    static DefaultHeightPadding := 10
    static MaxCards := 5
    static CardGap := 8
    static MoveAnimDuration := 100
    static TickIntervalMs := 10

    __New(app) {
        this.App := app
        this.Active := false
        this.Hook := ""
        this.Gui := ""
        this.Cards := []
        this.LastText := ""
        this.PendingText := ""
        this.CurrentAlpha := 255
        this.OrderedKeys := []
        this.TimerResolutionActive := false

        this.KeyMap := Map(
            "Space", "Space", "Enter", "Enter", "Tab", "Tab", "Backspace", "Backspace",
            "Delete", "Delete", "Insert", "Insert", "Home", "Home", "End", "End",
            "PgUp", "PgUp", "PgDn", "PgDn", "Up", "↑", "Down", "↓",
            "Left", "←", "Right", "→", "Escape", "Esc", "Esc", "Esc",
            "CapsLock", "CapsLock", "PrintScreen", "PrtSc", "Pause", "Pause",
            "ScrollLock", "ScrollLock", "NumLock", "NumLock",
            "LControl", "Ctrl", "RControl", "Ctrl", "Control", "Ctrl", "Ctrl", "Ctrl",
            "LShift", "Shift", "RShift", "Shift", "Shift", "Shift",
            "LAlt", "Alt", "RAlt", "Alt", "Alt", "Alt",
            "LWin", "Win", "RWin", "Win", "Win", "Win",
            "AppsKey", "Menu",
            "NumpadEnter", "Enter",
            "NumpadDot", ".",
            "NumpadDiv", "/",
            "NumpadMult", "*",
            "NumpadAdd", "+",
            "NumpadSub", "-",
            "NumpadIns", "Insert",
            "NumpadDel", "Delete",
            "NumpadEnd", "End",
            "NumpadDown", "↓",
            "NumpadPgDn", "PgDn",
            "NumpadLeft", "←",
            "NumpadClear", "Clear",
            "NumpadRight", "→",
            "NumpadHome", "Home",
            "NumpadUp", "↑",
            "NumpadPgUp", "PgUp",
            "Volume_Mute", "Mute",
            "Volume_Up", "Vol+",
            "Volume_Down", "Vol-",
            "Media_Play_Pause", "Play/Pause",
            "Media_Next", "Next",
            "Media_Prev", "Prev",
            "Media_Stop", "Stop"
        )
        Loop 10 {
            this.KeyMap["Numpad" (A_Index - 1)] := "Num " (A_Index - 1)
        }

        this.StartFadeOutTimer := ObjBindMethod(this, "StartFadeOut")
        this.AnimateFadeTimer := ObjBindMethod(this, "AnimateFade")
        this.TriggerOSDUpdateTimer := ObjBindMethod(this, "TriggerOSDUpdate")
        this.CheckReleaseTimer := ObjBindMethod(this, "CheckRelease")
        this.TickTimer := ObjBindMethod(this, "OnTick")
    }

    SetHighPrecisionTimer(enable) {
        if enable {
            if !this.TimerResolutionActive {
                try this.TimerResolutionActive := (DllCall("winmm\timeBeginPeriod", "uint", 1, "uint") == 0)
                catch
                    this.TimerResolutionActive := false
            }
        } else {
            if this.TimerResolutionActive {
                this.TimerResolutionActive := false
                try DllCall("winmm\timeEndPeriod", "uint", 1, "uint")
            }
        }
    }

    AllowedSingleKeys => {
        Has: (thisObj, key) => !KeystrokeOsdService.IsFilteredSingleKey(key)
    }

    static IsPureModifierText(text) {
        if text == ""
            return false
        tokens := StrSplit(text, " + ")
        for tok in tokens {
            t := StrLower(Trim(tok))
            if t != "ctrl" && t != "alt" && t != "shift" && t != "win"
                return false
        }
        return true
    }

    static IsSingleDigitOrLetter(keyName) {
        if StrLen(keyName) == 1
            return !!RegExMatch(keyName, "^[\p{L}\p{N}]$")
        return !!RegExMatch(keyName, "^(?i)Numpad\d$")
    }

    static IsSinglePunctuationOrSymbol(keyName) {
        if StrLen(keyName) == 1
            return !!RegExMatch(keyName, "^[\p{P}\p{S}]$")
        return !!RegExMatch(keyName, "^(?i)Numpad(Dot|Add|Sub|Mult|Div)$")
    }

    static IsFilteredSingleKey(keyName) {
        return KeystrokeOsdService.IsSingleDigitOrLetter(keyName)
            || KeystrokeOsdService.IsSinglePunctuationOrSymbol(keyName)
    }

    static IsModifierKey(keyName) {
        return KeystrokeOsdService.GetKeyRank(keyName) < 10
    }

    static ShouldShowKeys(keys) {
        if !IsObject(keys) || keys.Length == 0
            return false
        if keys.Length == 1
            return !KeystrokeOsdService.IsFilteredSingleKey(keys[1])
        ; 组合键仅限以修饰键开头，同时输入的字母/数字/标点不要被算作组合键，不予显示
        return KeystrokeOsdService.IsModifierKey(keys[1])
    }

    static GetKeyRank(keyName) {
        norm := StrLower(keyName)
        if norm == "lcontrol" || norm == "rcontrol" || norm == "control" || norm == "ctrl"
            return 1
        if norm == "lalt" || norm == "ralt" || norm == "alt"
            return 2
        if norm == "lshift" || norm == "rshift" || norm == "shift"
            return 3
        if norm == "lwin" || norm == "rwin" || norm == "win"
            return 4
        return 10
    }

    SortKeys(keys) {
        if !IsObject(keys) || keys.Length <= 1
            return keys

        indexed := []
        for idx, k in keys
            indexed.Push({Key: k, Rank: KeystrokeOsdService.GetKeyRank(k), Index: idx})

        n := indexed.Length
        Loop n {
            i := A_Index
            j := i + 1
            while j <= n {
                if indexed[i].Rank > indexed[j].Rank {
                    temp := indexed[i]
                    indexed[i] := indexed[j]
                    indexed[j] := temp
                }
                j++
            }
        }

        sorted := []
        for item in indexed
            sorted.Push(item.Key)
        return sorted
    }

    FormatKeys(keys) {
        displayText := ""
        seenTokens := Map()
        for kName in keys {
            token := this.KeyMap.Has(kName) ? this.KeyMap[kName]
                : (StrLen(kName) == 1 ? StrUpper(kName) : StrTitle(kName))
            if seenTokens.Has(token)
                continue
            seenTokens[token] := true
            if displayText != ""
                displayText .= " + "
            displayText .= token
        }
        return displayText
    }

    Start() {
        if this.Active
            return true

        this.OrderedKeys := []
        this.PendingText := ""
        this.LastText := ""

        this.Hook := InputHook("V I2")
        this.Hook.OnKeyDown := ObjBindMethod(this, "OnKeyDown")
        this.Hook.OnKeyUp := ObjBindMethod(this, "OnKeyUp")
        this.Hook.KeyOpt("{All}", "N")
        try this.Hook.Start()
        catch as hookError {
            this.Hook := ""
            return false
        }

        this.Active := true
        return true
    }

    Stop() {
        if !this.Active
            return true

        if IsObject(this.Hook) {
            try this.Hook.Stop()
            this.Hook := ""
        }

        SetTimer(this.StartFadeOutTimer, 0)
        SetTimer(this.AnimateFadeTimer, 0)
        SetTimer(this.TriggerOSDUpdateTimer, 0)
        SetTimer(this.CheckReleaseTimer, 0)
        SetTimer(this.TickTimer, 0)
        this.SetHighPrecisionTimer(false)

        this.DestroyGui()
        this.OrderedKeys := []
        this.PendingText := ""
        this.LastText := ""
        this.Active := false
        return true
    }

    Toggle() {
        return this.Active ? this.Stop() : this.Start()
    }

    OnKeyDown(ih, VK, SC) {
        if !this.Active
            return

        if IsObject(this.App) && this.App.HasOwnProp("Capture")
                && IsObject(this.App.Capture) && this.App.Capture.Active
            return

        rawKeyName := GetKeyName(Format("vk{:x}sc{:x}", VK, SC))
        if rawKeyName == ""
            rawKeyName := GetKeyName(Format("vk{:x}", VK))
        if rawKeyName == ""
            return

        isMediaKey := InStr(rawKeyName, "Media") || InStr(rawKeyName, "Volume")
            || InStr(rawKeyName, "Browser") || InStr(rawKeyName, "Launch")
            || rawKeyName == "PrintScreen"
        if !isMediaKey && !GetKeyState(rawKeyName, "P")
            return

        ; Clean up keys in OrderedKeys that are no longer physically held down
        i := 1
        while i <= this.OrderedKeys.Length {
            k := this.OrderedKeys[i]
            if k != rawKeyName && !GetKeyState(k, "P")
                this.OrderedKeys.RemoveAt(i)
            else
                i++
        }

        alreadyInList := false
        Loop this.OrderedKeys.Length {
            if this.OrderedKeys[A_Index] == rawKeyName {
                alreadyInList := true
                break
            }
        }
        if !alreadyInList
            this.OrderedKeys.Push(rawKeyName)

        if !KeystrokeOsdService.ShouldShowKeys(this.OrderedKeys)
            return

        sortedKeys := this.SortKeys(this.OrderedKeys)
        displayText := this.FormatKeys(sortedKeys)

        SetTimer(this.StartFadeOutTimer, 0)
        SetTimer(this.AnimateFadeTimer, 0)

        this.PendingText := displayText

        SetTimer(this.TriggerOSDUpdateTimer, 0)
        SetTimer(this.TriggerOSDUpdateTimer, -60)
    }

    TriggerOSDUpdate() {
        if !this.Active
            return

        if this.PendingText == ""
            return

        ; If newest card already shows this exact text and is not yet fading, simply refresh its timer
        if this.Cards.Length > 0 {
            newest := this.Cards[this.Cards.Length]
            if newest.Text == this.PendingText {
                config := this.GetEffectiveConfig()
                newest.DisplayEndTime := A_TickCount + config.DisplayTimeMs
                newest.IsFading := false
                try WinSetTransparent(255, newest.Hwnd)
                return
            }
        }

        this.LastText := this.PendingText
        this.ShowOSD(this.PendingText)
    }

    OnKeyUp(ih, VK, SC) {
        rawKeyName := GetKeyName(Format("vk{:x}sc{:x}", VK, SC))
        if rawKeyName == ""
            rawKeyName := GetKeyName(Format("vk{:x}", VK))
        if rawKeyName != "" {
            Loop this.OrderedKeys.Length {
                if this.OrderedKeys[A_Index] == rawKeyName {
                    this.OrderedKeys.RemoveAt(A_Index)
                    break
                }
            }
        }
        SetTimer(this.CheckReleaseTimer, -50)
    }

    IsAnyKeyHeld() {
        if !this.Active
            return false

        for kName in this.OrderedKeys {
            if GetKeyState(kName, "P")
                return true
        }

        if (GetKeyState("Ctrl", "P") || GetKeyState("Alt", "P")
            || GetKeyState("Shift", "P") || GetKeyState("LWin", "P")
            || GetKeyState("RWin", "P"))
            return true

        return false
    }

    CheckRelease() {
        if !this.Active
            return

        ; If any key is still physically held down, do not mark newest card for release fade
        if this.IsAnyKeyHeld()
            return

        ; When keys are released, newest card counts down from now
        if this.Cards.Length > 0 {
            newest := this.Cards[this.Cards.Length]
            if !newest.IsFading {
                config := this.GetEffectiveConfig()
                newest.DisplayEndTime := A_TickCount + config.DisplayTimeMs
            }
        }
    }

    StartFadeOut() {
        if this.Cards.Length > 0 {
            newest := this.Cards[this.Cards.Length]
            if !newest.IsFading {
                newest.IsFading := true
                newest.FadeStartTime := A_TickCount
            }
        }
    }

    AnimateFade() {
        ; Legacy handler - animation and fading are now handled by OnTick
    }

    OnTick() {
        if !this.Active && this.Cards.Length == 0 {
            SetTimer(this.TickTimer, 0)
            this.SetHighPrecisionTimer(false)
            return
        }

        now := A_TickCount
        isAnyHeld := this.IsAnyKeyHeld()

        ; If newest card's key is still held down, continuously extend its display time
        if isAnyHeld && this.Cards.Length > 0 {
            newest := this.Cards[this.Cards.Length]
            if !newest.IsFading {
                config := this.GetEffectiveConfig()
                newest.DisplayEndTime := now + config.DisplayTimeMs
            }
        }

        anyAnimating := false
        anyFading := false

        i := this.Cards.Length
        while i >= 1 {
            card := this.Cards[i]

            ; 1. Smooth movement towards TargetY and TargetX with Ease-Out Cubic
            if card.IsAnimating {
                elapsed := now - card.AnimStartTime
                if elapsed >= card.AnimDuration {
                    card.X := card.TargetX
                    card.Y := card.TargetY
                    card.IsAnimating := false
                } else {
                    t := elapsed / card.AnimDuration
                    inv := 1.0 - t
                    ease := 1.0 - inv * inv * inv
                    card.X := Round(card.StartX + (card.TargetX - card.StartX) * ease)
                    card.Y := Round(card.StartY + (card.TargetY - card.StartY) * ease)
                    anyAnimating := true
                }
                ; High performance window repositioning without resize, z-order or activation overhead:
                ; SWP_NOSIZE (0x0001) | SWP_NOZORDER (0x0004) | SWP_NOACTIVATE (0x0010) | SWP_NOOWNERZORDER (0x0200) = 0x0215
                DllCall("SetWindowPos", "ptr", card.Hwnd, "ptr", 0, "int", card.X, "int", card.Y, "int", 0, "int", 0, "uint", 0x0215)
            }

            ; 2. Expiration and fading:
            ; Older cards expire on their own schedule; newest card only expires once keys released
            if !card.IsFading {
                if now >= card.DisplayEndTime {
                    if i < this.Cards.Length || !isAnyHeld {
                        card.IsFading := true
                        card.FadeStartTime := now
                    }
                }
            }

            if card.IsFading {
                fadeElapsed := now - card.FadeStartTime
                if fadeElapsed >= card.FadeDuration {
                    try card.Gui.Destroy()
                    this.Cards.RemoveAt(i)
                    i--
                    continue
                } else {
                    alpha := Round(255 * (1 - fadeElapsed / card.FadeDuration))
                    card.Alpha := Max(0, Min(255, alpha))
                    try WinSetTransparent(card.Alpha, card.Hwnd)
                    anyFading := true
                }
            }

            i--
        }

        if this.Cards.Length == 0 {
            this.Gui := ""
            this.LastText := ""
            SetTimer(this.TickTimer, 0)
            this.SetHighPrecisionTimer(false)
        } else {
            this.Gui := this.Cards[this.Cards.Length].Gui
            if anyAnimating || anyFading {
                this.SetHighPrecisionTimer(true)
                SetTimer(this.TickTimer, KeystrokeOsdService.TickIntervalMs)
            } else {
                this.SetHighPrecisionTimer(false)
                SetTimer(this.TickTimer, 40)
            }
        }
    }

    ShowOSD(textContent, customConfig := "") {
        if textContent == ""
            return

        ; If current newest card was only modifiers (e.g. "Ctrl") and the new key is completing
        ; the combination (e.g. "Ctrl + A"), replace the modifier-only card in place
        if this.Cards.Length > 0 {
            lastCard := this.Cards[this.Cards.Length]
            if !lastCard.IsFading && KeystrokeOsdService.IsPureModifierText(lastCard.Text) {
                try lastCard.Gui.Destroy()
                this.Cards.Pop()
            }
        }

        config := this.GetEffectiveConfig(customConfig)
        guiColor := config.BgColor
        fontColor := config.TextColor
        fontSize := config.FontSize
        fontType := KeystrokeOsdService.DefaultFontType
        roundness := KeystrokeOsdService.DefaultRoundness

        cardGui := Gui("+AlwaysOnTop -Caption +ToolWindow +LastFound +E0x20 -DPIScale")
        cardGui.BackColor := guiColor
        cardGui.SetFont("s" fontSize " c" fontColor " w600", fontType)

        cardGui.MarginX := 0
        cardGui.MarginY := 0

        ; IMPORTANT: Do NOT specify -Wrap here! In Win32, -Wrap sets SS_LEFTNOWORDWRAP (0xC) which
        ; overrides SS_CENTER (0x1) and forces left alignment.
        ; Center (0x1) + 0x200 (SS_CENTERIMAGE) = 0x201, providing true horizontal and vertical text centering.
        lbl := cardGui.Add("Text", "x0 y0 Center 0x200", textContent)

        cardGui.Show("AutoSize NoActivate Hide")
        WinGetPos(,, &tightWidth, &tightHeight, cardGui.Hwnd)

        widthPadding := KeystrokeOsdService.DefaultWidthPadding + (fontSize > 14 ? (fontSize - 14) * 2 : 0)
        heightPadding := KeystrokeOsdService.DefaultHeightPadding + (fontSize > 14 ? (fontSize - 14) : 0)

        finalHeight := tightHeight + heightPadding
        ; Provide comfortable pill width so curved caps do not crowd the text
        finalWidth := Max(tightWidth + widthPadding + 10, Round(finalHeight * 1.25))

        ; Visual vertical center compensation for font ascent/descent metrics
        visualYOffset := -Max(1, Round(fontSize * 0.06))
        lbl.Move(0, visualYOffset, finalWidth, finalHeight)

        try MonitorGet(1, &mL, &mT, &mR, &mB)
        catch {
            mL := 0
            mT := 0
            mR := A_ScreenWidth
            mB := A_ScreenHeight
        }

        availW := mR - mL
        availH := mB - mT
        margin := 20

        switch config.Position {
            case "top-left":
                baseX := mL + margin
                baseY := mT + margin
            case "top-center":
                baseX := mL + Floor((availW - finalWidth) / 2)
                baseY := mT + margin
            case "top-right":
                baseX := mR - finalWidth - margin
                baseY := mT + margin
            case "center-left":
                baseX := mL + margin
                baseY := mT + Floor((availH - finalHeight) / 2)
            case "center":
                baseX := mL + Floor((availW - finalWidth) / 2)
                baseY := mT + Floor((availH - finalHeight) / 2)
            case "center-right":
                baseX := mR - finalWidth - margin
                baseY := mT + Floor((availH - finalHeight) / 2)
            case "bottom-center":
                baseX := mL + Floor((availW - finalWidth) / 2)
                baseY := mB - finalHeight - margin
            case "bottom-right":
                baseX := mR - finalWidth - margin
                baseY := mB - finalHeight - margin
            default: ; "bottom-left"
                baseX := mL + margin
                baseY := mB - finalHeight - margin
        }

        ; Apply custom fine-tuning offsets (OffsetX/OffsetY or OffsetUp/Down/Left/Right)
        offsetX := config.HasOwnProp("OffsetX") ? config.OffsetX : 0
        offsetY := config.HasOwnProp("OffsetY") ? config.OffsetY : 0
        if offsetX == 0 && (config.HasOwnProp("OffsetRight") || config.HasOwnProp("OffsetLeft"))
            offsetX := (config.HasOwnProp("OffsetRight") ? config.OffsetRight : 0) - (config.HasOwnProp("OffsetLeft") ? config.OffsetLeft : 0)
        if offsetY == 0 && (config.HasOwnProp("OffsetDown") || config.HasOwnProp("OffsetUp"))
            offsetY := (config.HasOwnProp("OffsetDown") ? config.OffsetDown : 0) - (config.HasOwnProp("OffsetUp") ? config.OffsetUp : 0)

        baseX += offsetX
        baseY += offsetY

        baseX := Max(mL + 10, Min(baseX, mR - finalWidth - 10))
        baseY := Max(mT + 10, Min(baseY, mB - finalHeight - 10))

        WinSetRegion("0-0 w" finalWidth " h" finalHeight " R" roundness "-" roundness, cardGui.Hwnd)
        WinSetTransparent(255, cardGui.Hwnd)
        cardGui.Show("NoActivate x" baseX " y" baseY " w" finalWidth " h" finalHeight)

        newCard := {
            Gui: cardGui,
            Hwnd: cardGui.Hwnd,
            Text: textContent,
            Width: finalWidth,
            Height: finalHeight,
            X: baseX,
            Y: baseY,
            StartX: baseX,
            StartY: baseY,
            TargetX: baseX,
            TargetY: baseY,
            Alpha: 255,
            DisplayEndTime: A_TickCount + config.DisplayTimeMs,
            FadeDuration: KeystrokeOsdService.DefaultFadeDuration,
            IsFading: false,
            FadeStartTime: 0,
            AnimStartTime: 0,
            AnimDuration: KeystrokeOsdService.MoveAnimDuration,
            IsAnimating: false
        }

        this.Cards.Push(newCard)
        this.Gui := cardGui

        this.UpdateCardTargets(config, mL, mT, mR, mB)
        this.SetHighPrecisionTimer(true)
        SetTimer(this.TickTimer, KeystrokeOsdService.TickIntervalMs)
    }

    UpdateCardTargets(config, mL, mT, mR, mB) {
        gap := KeystrokeOsdService.CardGap
        n := this.Cards.Length
        if n == 0
            return

        isTopPosition := InStr(config.Position, "top-")
        now := A_TickCount

        i := n - 1
        while i >= 1 {
            card := this.Cards[i]
            belowCard := this.Cards[i + 1]

            newTargetY := card.TargetY
            if !isTopPosition {
                newTargetY := belowCard.TargetY - card.Height - gap
            } else {
                if belowCard.TargetY - card.Height - gap >= mT + 10 {
                    newTargetY := belowCard.TargetY - card.Height - gap
                } else {
                    newTargetY := belowCard.TargetY + belowCard.Height + gap
                }
            }

            newTargetX := card.TargetX
            if InStr(config.Position, "right") {
                newTargetX := (belowCard.TargetX + belowCard.Width) - card.Width
            } else if InStr(config.Position, "center") {
                newTargetX := belowCard.TargetX + Floor((belowCard.Width - card.Width) / 2)
            } else {
                newTargetX := belowCard.TargetX
            }

            newTargetX := Max(mL + 10, Min(newTargetX, mR - card.Width - 10))

            if newTargetX != card.TargetX || newTargetY != card.TargetY {
                card.StartX := card.X
                card.StartY := card.Y
                card.TargetX := newTargetX
                card.TargetY := newTargetY
                card.AnimStartTime := now
                card.AnimDuration := KeystrokeOsdService.MoveAnimDuration
                card.IsAnimating := true
            }

            if card.TargetY < mT + 10 {
                if !card.IsFading {
                    card.IsFading := true
                    card.FadeStartTime := A_TickCount
                    card.FadeDuration := 100
                }
            }

            i--
        }

        while this.Cards.Length > KeystrokeOsdService.MaxCards {
            oldest := this.Cards.RemoveAt(1)
            try oldest.Gui.Destroy()
        }
    }

    Preview(customConfig := "") {
        config := this.GetEffectiveConfig(customConfig)
        this.ShowOSD("Ctrl + Shift + A", config)
    }

    GetEffectiveConfig(customConfig := "") {
        position := KeystrokeOsdService.DefaultPosition
        offsetX := 0
        offsetY := 0
        offsetUp := 0
        offsetDown := 0
        offsetLeft := 0
        offsetRight := 0
        fontSize := KeystrokeOsdService.DefaultFontSize
        bgColor := KeystrokeOsdService.DefaultGuiColor
        textColor := KeystrokeOsdService.DefaultFontColor
        displayTimeMs := KeystrokeOsdService.DefaultDisplayTime

        if IsObject(this.App) && this.App.HasOwnProp("Settings")
                && IsObject(this.App.Settings) {
            settings := this.App.Settings
            if settings.HasOwnProp("KeystrokeOsdPosition")
                position := settings.KeystrokeOsdPosition
            if settings.HasOwnProp("KeystrokeOsdOffsetX")
                offsetX := settings.KeystrokeOsdOffsetX
            if settings.HasOwnProp("KeystrokeOsdOffsetY")
                offsetY := settings.KeystrokeOsdOffsetY
            if settings.HasOwnProp("KeystrokeOsdOffsetUp")
                offsetUp := settings.KeystrokeOsdOffsetUp
            if settings.HasOwnProp("KeystrokeOsdOffsetDown")
                offsetDown := settings.KeystrokeOsdOffsetDown
            if settings.HasOwnProp("KeystrokeOsdOffsetLeft")
                offsetLeft := settings.KeystrokeOsdOffsetLeft
            if settings.HasOwnProp("KeystrokeOsdOffsetRight")
                offsetRight := settings.KeystrokeOsdOffsetRight
            if settings.HasOwnProp("KeystrokeOsdFontSize")
                fontSize := settings.KeystrokeOsdFontSize
            if settings.HasOwnProp("KeystrokeOsdBgColor")
                bgColor := settings.KeystrokeOsdBgColor
            if settings.HasOwnProp("KeystrokeOsdTextColor")
                textColor := settings.KeystrokeOsdTextColor
            if settings.HasOwnProp("KeystrokeOsdDisplayTimeMs")
                displayTimeMs := settings.KeystrokeOsdDisplayTimeMs
        }

        if IsObject(customConfig) {
            if customConfig.HasOwnProp("Position")
                position := customConfig.Position
            if customConfig.HasOwnProp("OffsetX")
                offsetX := customConfig.OffsetX
            if customConfig.HasOwnProp("OffsetY")
                offsetY := customConfig.OffsetY
            if customConfig.HasOwnProp("OffsetUp")
                offsetUp := customConfig.OffsetUp
            if customConfig.HasOwnProp("OffsetDown")
                offsetDown := customConfig.OffsetDown
            if customConfig.HasOwnProp("OffsetLeft")
                offsetLeft := customConfig.OffsetLeft
            if customConfig.HasOwnProp("OffsetRight")
                offsetRight := customConfig.OffsetRight
            if customConfig.HasOwnProp("FontSize")
                fontSize := customConfig.FontSize
            if customConfig.HasOwnProp("BgColor")
                bgColor := customConfig.BgColor
            if customConfig.HasOwnProp("TextColor")
                textColor := customConfig.TextColor
            if customConfig.HasOwnProp("DisplayTimeMs")
                displayTimeMs := customConfig.DisplayTimeMs
        }

        if offsetX == 0 && (offsetRight != 0 || offsetLeft != 0)
            offsetX := offsetRight - offsetLeft
        else if offsetX != 0 && offsetRight == 0 && offsetLeft == 0 {
            offsetRight := offsetX > 0 ? offsetX : 0
            offsetLeft := offsetX < 0 ? -offsetX : 0
        }

        if offsetY == 0 && (offsetDown != 0 || offsetUp != 0)
            offsetY := offsetDown - offsetUp
        else if offsetY != 0 && offsetDown == 0 && offsetUp == 0 {
            offsetDown := offsetY > 0 ? offsetY : 0
            offsetUp := offsetY < 0 ? -offsetY : 0
        }

        return {
            Position: position,
            FontSize: fontSize,
            BgColor: bgColor,
            TextColor: textColor,
            DisplayTimeMs: displayTimeMs,
            OffsetX: offsetX,
            OffsetY: offsetY,
            OffsetUp: offsetUp,
            OffsetDown: offsetDown,
            OffsetLeft: offsetLeft,
            OffsetRight: offsetRight
        }
    }

    DestroyAllCards() {
        SetTimer(this.TickTimer, 0)
        this.SetHighPrecisionTimer(false)
        if IsObject(this.Cards) {
            for card in this.Cards {
                try card.Gui.Destroy()
            }
        }
        this.Cards := []
        this.Gui := ""
        this.LastText := ""
    }

    DestroyGui() {
        this.DestroyAllCards()
    }

    Shutdown() {
        this.Stop()
    }
}
