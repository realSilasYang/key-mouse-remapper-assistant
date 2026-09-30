#Requires AutoHotkey v2.0 64-bit
#SingleInstance Off
#Warn All, StdOut

#Include ..\..\src\UI\KeystrokeOsdService.ahk

Assert(condition, message) {
    if !condition
        throw Error("Assertion failed: " message)
}

testApp := {Capture: {Active: false}}
service := KeystrokeOsdService(testApp)

Assert(!service.Active, "Initial state should be inactive")

; Test Start and Stop idempotency
Assert(service.Start(), "Service should start successfully")
Assert(service.Active, "Service should be active after start")

; Test key name mappings
Assert(service.KeyMap["Space"] == "Space", "Space key mapping incorrect")
Assert(service.KeyMap["Up"] == "↑", "Up key mapping incorrect")
Assert(service.KeyMap["Down"] == "↓", "Down key mapping incorrect")
Assert(service.KeyMap["Left"] == "←", "Left key mapping incorrect")
Assert(service.KeyMap["Right"] == "→", "Right key mapping incorrect")
Assert(service.KeyMap["LControl"] == "Ctrl", "LControl key mapping incorrect")
Assert(service.KeyMap["AppsKey"] == "Menu", "AppsKey key mapping incorrect")
Assert(service.KeyMap["Escape"] == "Esc", "Escape key mapping incorrect")
Assert(service.KeyMap["NumpadEnter"] == "Enter", "NumpadEnter key mapping incorrect")

; Test IsSingleDigitOrLetter
Assert(KeystrokeOsdService.IsSingleDigitOrLetter("a"), "'a' should be digit/letter")
Assert(KeystrokeOsdService.IsSingleDigitOrLetter("Z"), "'Z' should be digit/letter")
Assert(KeystrokeOsdService.IsSingleDigitOrLetter("0"), "'0' should be digit/letter")
Assert(KeystrokeOsdService.IsSingleDigitOrLetter("9"), "'9' should be digit/letter")
Assert(KeystrokeOsdService.IsSingleDigitOrLetter("Numpad0"), "'Numpad0' should be digit/letter")
Assert(KeystrokeOsdService.IsSingleDigitOrLetter("Numpad9"), "'Numpad9' should be digit/letter")
Assert(!KeystrokeOsdService.IsSingleDigitOrLetter("Space"), "'Space' should NOT be digit/letter")
Assert(!KeystrokeOsdService.IsSingleDigitOrLetter(","), "',' should NOT be digit/letter")

; Test IsSinglePunctuationOrSymbol
Assert(KeystrokeOsdService.IsSinglePunctuationOrSymbol(","), "',' should be punctuation/symbol")
Assert(KeystrokeOsdService.IsSinglePunctuationOrSymbol("."), "'.' should be punctuation/symbol")
Assert(KeystrokeOsdService.IsSinglePunctuationOrSymbol("/"), "'/' should be punctuation/symbol")
Assert(KeystrokeOsdService.IsSinglePunctuationOrSymbol(";"), "';' should be punctuation/symbol")
Assert(KeystrokeOsdService.IsSinglePunctuationOrSymbol("'"), "''' should be punctuation/symbol")
Assert(KeystrokeOsdService.IsSinglePunctuationOrSymbol("["), "'[' should be punctuation/symbol")
Assert(KeystrokeOsdService.IsSinglePunctuationOrSymbol("]"), "']' should be punctuation/symbol")
Assert(KeystrokeOsdService.IsSinglePunctuationOrSymbol("\"), "'\' should be punctuation/symbol")
Assert(KeystrokeOsdService.IsSinglePunctuationOrSymbol("-"), "'-' should be punctuation/symbol")
Assert(KeystrokeOsdService.IsSinglePunctuationOrSymbol("="), "'=' should be punctuation/symbol")
Assert(KeystrokeOsdService.IsSinglePunctuationOrSymbol("``"), "'``' should be punctuation/symbol")
Assert(KeystrokeOsdService.IsSinglePunctuationOrSymbol("NumpadDot"), "'NumpadDot' should be punctuation/symbol")
Assert(KeystrokeOsdService.IsSinglePunctuationOrSymbol("NumpadAdd"), "'NumpadAdd' should be punctuation/symbol")
Assert(KeystrokeOsdService.IsSinglePunctuationOrSymbol("NumpadSub"), "'NumpadSub' should be punctuation/symbol")
Assert(KeystrokeOsdService.IsSinglePunctuationOrSymbol("NumpadMult"), "'NumpadMult' should be punctuation/symbol")
Assert(KeystrokeOsdService.IsSinglePunctuationOrSymbol("NumpadDiv"), "'NumpadDiv' should be punctuation/symbol")

Assert(!KeystrokeOsdService.IsSinglePunctuationOrSymbol("Space"), "'Space' should NOT be punctuation/symbol")
Assert(!KeystrokeOsdService.IsSinglePunctuationOrSymbol("Enter"), "'Enter' should NOT be punctuation/symbol")
Assert(!KeystrokeOsdService.IsSinglePunctuationOrSymbol("F1"), "'F1' should NOT be punctuation/symbol")
Assert(!KeystrokeOsdService.IsSinglePunctuationOrSymbol("Up"), "'Up' should NOT be punctuation/symbol")
Assert(!KeystrokeOsdService.IsSinglePunctuationOrSymbol("LControl"), "'LControl' should NOT be punctuation/symbol")

; Test ShouldShowKeys - single punctuation & symbols should be filtered out
Assert(!KeystrokeOsdService.ShouldShowKeys([","]), "Single comma should not show")
Assert(!KeystrokeOsdService.ShouldShowKeys(["."]), "Single dot should not show")
Assert(!KeystrokeOsdService.ShouldShowKeys(["/"]), "Single slash should not show")
Assert(!KeystrokeOsdService.ShouldShowKeys([";"]), "Single semicolon should not show")
Assert(!KeystrokeOsdService.ShouldShowKeys(["'"]), "Single quote should not show")
Assert(!KeystrokeOsdService.ShouldShowKeys(["["]), "Single '[' should not show")
Assert(!KeystrokeOsdService.ShouldShowKeys(["]"]), "Single ']' should not show")
Assert(!KeystrokeOsdService.ShouldShowKeys(["\"]), "Single '\' should not show")
Assert(!KeystrokeOsdService.ShouldShowKeys(["-"]), "Single '-' should not show")
Assert(!KeystrokeOsdService.ShouldShowKeys(["="]), "Single '=' should not show")
Assert(!KeystrokeOsdService.ShouldShowKeys(["``"]), "Single '``' should not show")
Assert(!KeystrokeOsdService.ShouldShowKeys(["NumpadAdd"]), "Single NumpadAdd should not show")
Assert(!KeystrokeOsdService.ShouldShowKeys(["NumpadDot"]), "Single NumpadDot should not show")

; Test ShouldShowKeys - single letters & numbers should be filtered out
Assert(!KeystrokeOsdService.ShouldShowKeys(["a"]), "Single letter 'a' should not show")
Assert(!KeystrokeOsdService.ShouldShowKeys(["Z"]), "Single letter 'Z' should not show")
Assert(!KeystrokeOsdService.ShouldShowKeys(["1"]), "Single digit '1' should not show")
Assert(!KeystrokeOsdService.ShouldShowKeys(["Numpad5"]), "Single numpad digit should not show")

; Test ShouldShowKeys - single editing / functional / navigation / modifier keys should show
Assert(KeystrokeOsdService.ShouldShowKeys(["Space"]), "Single Space should show")
Assert(KeystrokeOsdService.ShouldShowKeys(["Enter"]), "Single Enter should show")
Assert(KeystrokeOsdService.ShouldShowKeys(["Tab"]), "Single Tab should show")
Assert(KeystrokeOsdService.ShouldShowKeys(["Backspace"]), "Single Backspace should show")
Assert(KeystrokeOsdService.ShouldShowKeys(["Delete"]), "Single Delete should show")
Assert(KeystrokeOsdService.ShouldShowKeys(["Escape"]), "Single Escape should show")
Assert(KeystrokeOsdService.ShouldShowKeys(["Up"]), "Single Up arrow should show")
Assert(KeystrokeOsdService.ShouldShowKeys(["F5"]), "Single F5 should show")
Assert(KeystrokeOsdService.ShouldShowKeys(["LControl"]), "Single LControl should show")
Assert(KeystrokeOsdService.ShouldShowKeys(["LWin"]), "Single LWin should show")
Assert(KeystrokeOsdService.ShouldShowKeys(["CapsLock"]), "Single CapsLock should show")

; Test ShouldShowKeys - combination keys must start with a modifier key (and not limited to 2 keys!)
Assert(KeystrokeOsdService.ShouldShowKeys(["LControl", "/"]), "Ctrl+/ combination should show")
Assert(KeystrokeOsdService.ShouldShowKeys(["LControl", "["]), "Ctrl+[ combination should show")
Assert(KeystrokeOsdService.ShouldShowKeys(["LWin", "."]), "Win+. combination should show")
Assert(KeystrokeOsdService.ShouldShowKeys(["LControl", "c"]), "2-key combination (Ctrl+C) should show")
Assert(KeystrokeOsdService.ShouldShowKeys(["LAlt", "1"]), "2-key combination with number (Alt+1) should show")
Assert(KeystrokeOsdService.ShouldShowKeys(["LControl", "LShift", "="]), "3-key combination with symbol (Ctrl+Shift+=) should show")
Assert(KeystrokeOsdService.ShouldShowKeys(["LControl", "LShift", "a"]), "3-key combination (Ctrl+Shift+A) should show")
Assert(KeystrokeOsdService.ShouldShowKeys(["LWin", "LShift", "s"]), "3-key combination (Win+Shift+S) should show")
Assert(KeystrokeOsdService.ShouldShowKeys(["LControl", "LShift", "LAlt", "s"]), "4-key combination should show")
Assert(KeystrokeOsdService.ShouldShowKeys(["LControl", "LShift", "LAlt", "LWin", "k"]), "5-key combination should show")
Assert(KeystrokeOsdService.ShouldShowKeys(["LControl", "a", "b"]), "3-key combination starting with modifier should show")

; Test ShouldShowKeys - simultaneous letters/digits/punctuation and chords not starting with modifier must NOT show
Assert(!KeystrokeOsdService.ShouldShowKeys(["a", "b"]), "Simultaneous letters (A+B) should NOT show as combination")
Assert(!KeystrokeOsdService.ShouldShowKeys(["1", "2"]), "Simultaneous digits (1+2) should NOT show as combination")
Assert(!KeystrokeOsdService.ShouldShowKeys([",", "."]), "Simultaneous punctuation (,+.) should NOT show as combination")
Assert(!KeystrokeOsdService.ShouldShowKeys(["a", "."]), "Simultaneous letter+punctuation (A+.) should NOT show as combination")
Assert(!KeystrokeOsdService.ShouldShowKeys(["Space", "j"]), "Chord not starting with modifier (Space+J) should NOT show")
Assert(!KeystrokeOsdService.ShouldShowKeys(["a", "b", "c"]), "Multi-letter chord (A+B+C) should NOT show")
Assert(!KeystrokeOsdService.ShouldShowKeys(["Space", "j", "k"]), "Chord not starting with modifier (Space+J+K) should NOT show")
Assert(!KeystrokeOsdService.ShouldShowKeys(["a", "b", "c", "d"]), "Multi-letter chord (A+B+C+D) should NOT show")
Assert(!KeystrokeOsdService.ShouldShowKeys(["a", "LControl"]), "Chord not starting with modifier (A+Ctrl) should NOT show")

; Test key sorting and formatting
Assert(service.FormatKeys(service.SortKeys(["LControl", "c"])) == "Ctrl + C", "Ctrl+C format incorrect")
Assert(service.FormatKeys(service.SortKeys(["LControl", "/"])) == "Ctrl + /", "Ctrl+/ format incorrect")
Assert(service.FormatKeys(service.SortKeys(["a", "LControl", "LShift"])) == "Ctrl + Shift + A", "Ctrl+Shift+A ranking format incorrect")
Assert(service.FormatKeys(service.SortKeys(["a", "b", "c"])) == "A + B + C", "A+B+C format incorrect")
Assert(service.FormatKeys(service.SortKeys(["Space", "j", "k"])) == "Space + J + K", "Space+J+K format incorrect")
Assert(service.FormatKeys(service.SortKeys(["LControl", "RControl"])) == "Ctrl", "Duplicate Ctrl should be deduplicated")
Assert(service.FormatKeys(service.SortKeys(["LControl", "LShift", "LAlt", "LWin", "k"])) == "Ctrl + Alt + Shift + Win + K", "5-key combination format incorrect")

; Test allowed single keys backward compatibility
Assert(service.AllowedSingleKeys.Has("Escape"), "Escape should be allowed")
Assert(service.AllowedSingleKeys.Has("Space"), "Space should be allowed")
Assert(service.AllowedSingleKeys.Has("Enter"), "Enter should be allowed")
Assert(service.AllowedSingleKeys.Has("F1"), "F1 should be allowed")
Assert(!service.AllowedSingleKeys.Has("A"), "Normal key 'A' should not be allowed single key")
Assert(!service.AllowedSingleKeys.Has("1"), "Normal digit '1' should not be allowed single key")
Assert(!service.AllowedSingleKeys.Has(","), "Comma should not be allowed single key")
Assert(!service.AllowedSingleKeys.Has("["), "'[' should not be allowed single key")

; Test custom fine-tuning offsets in four directions
customCfg := service.GetEffectiveConfig({
    OffsetUp: 25,
    OffsetDown: 10,
    OffsetLeft: 30,
    OffsetRight: 50
})
Assert(customCfg.OffsetUp == 25, "OffsetUp should be 25")
Assert(customCfg.OffsetDown == 10, "OffsetDown should be 10")
Assert(customCfg.OffsetLeft == 30, "OffsetLeft should be 30")
Assert(customCfg.OffsetRight == 50, "OffsetRight should be 50")
Assert(customCfg.OffsetX == 20, "OffsetX should be 50 - 30 = 20")
Assert(customCfg.OffsetY == -15, "OffsetY should be 10 - 25 = -15")

; Test OffsetX and OffsetY directly
customCfgXY := service.GetEffectiveConfig({
    Position: "center-left",
    OffsetX: 42,
    OffsetY: -35
})
Assert(customCfgXY.Position == "center-left", "Position should be center-left")
Assert(customCfgXY.OffsetX == 42, "OffsetX should be 42")
Assert(customCfgXY.OffsetY == -35, "OffsetY should be -35")
Assert(customCfgXY.OffsetRight == 42, "OffsetRight should be 42")
Assert(customCfgXY.OffsetUp == 35, "OffsetUp should be 35")

; Test IsPureModifierText
Assert(KeystrokeOsdService.IsPureModifierText("Ctrl"), "'Ctrl' should be pure modifier")
Assert(KeystrokeOsdService.IsPureModifierText("Ctrl + Shift"), "'Ctrl + Shift' should be pure modifier")
Assert(KeystrokeOsdService.IsPureModifierText("Alt + Win"), "'Alt + Win' should be pure modifier")
Assert(!KeystrokeOsdService.IsPureModifierText("Ctrl + A"), "'Ctrl + A' should NOT be pure modifier")
Assert(!KeystrokeOsdService.IsPureModifierText("F2"), "'F2' should NOT be pure modifier")
Assert(!KeystrokeOsdService.IsPureModifierText(""), "Empty string should NOT be pure modifier")

; Test multi-card stacking queue and upward movement
service.DestroyGui()
service.ShowOSD("F2")
Assert(service.Cards.Length == 1, "Should have 1 active card after first ShowOSD")
card1 := service.Cards[1]
Assert(card1.Text == "F2", "First card text should be F2")
card1InitialY := card1.Y

; Show second keystroke while first hasn't disappeared
service.ShowOSD("Ctrl + Shift + A")
Assert(service.Cards.Length == 2, "Should have 2 active cards without destroying first")
card1Updated := service.Cards[1]
card2 := service.Cards[2]
Assert(card1Updated.Text == "F2", "Card 1 should still be F2")
Assert(card2.Text == "Ctrl + Shift + A", "Card 2 should be Ctrl + Shift + A")
; Card 1 TargetY should be shifted UP above Card 2 TargetY
Assert(card1Updated.TargetY < card2.TargetY, "Card 1 should have moved UP above Card 2")
Assert(card2.TargetY > card1Updated.TargetY, "Card 2 should appear below Card 1")
Assert(card1Updated.DisplayEndTime <= card2.DisplayEndTime, "Each card should have its own expiration schedule")

; Show third keystroke
service.ShowOSD("Enter")
Assert(service.Cards.Length == 3, "Should have 3 stacked cards")
Assert(service.Cards[1].TargetY < service.Cards[2].TargetY, "Card 1 should be highest")
Assert(service.Cards[2].TargetY < service.Cards[3].TargetY, "Card 2 should be above Card 3")

; Test DestroyGui / DestroyAllCards cleanup
service.DestroyGui()
Assert(service.Cards.Length == 0, "DestroyGui should clear all stacked cards")
Assert(service.Gui == "", "service.Gui should be cleared")

; Test Stop
Assert(service.Stop(), "Service should stop successfully")
Assert(!service.Active, "Service should be inactive after stop")

; Test Shutdown
service.Shutdown()
Assert(!service.Active, "Service should be inactive after shutdown")

ExitApp(0)
