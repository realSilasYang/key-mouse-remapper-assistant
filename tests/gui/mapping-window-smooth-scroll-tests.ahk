#Requires AutoHotkey v2.0 64-bit
#SingleInstance Off
#Warn All, StdOut

#Include ..\..\src\Localization\EnglishStrings.ahk
#Include ..\..\src\Localization\TraditionalHongKongStrings.ahk
#Include ..\..\src\Localization\TraditionalTaiwanStrings.ahk
#Include ..\..\src\Localization\JapaneseStrings.ahk
#Include ..\..\src\Localization\VietnameseStrings.ahk
#Include ..\..\src\Localization\KoreanStrings.ahk
#Include ..\..\src\Localization\SpanishStrings.ahk
#Include ..\..\src\Localization\FrenchStrings.ahk
#Include ..\..\src\Localization\PortugueseBrazilStrings.ahk
#Include ..\..\src\Localization\RussianStrings.ahk
#Include ..\..\src\Localization\GermanStrings.ahk
#Include ..\..\src\Localization\ItalianStrings.ahk
#Include ..\..\src\Localization\LocalizationService.ahk
#Include ..\..\src\UI\UiThemeService.ahk
#Include ..\..\src\UI\AhkV2Lexer.ahk
#Include ..\..\src\Core\BoundedFileReader.ahk
#Include ..\..\src\Core\JsonCodec.ahk
#Include ..\..\src\Core\Sha256.ahk
#Include ..\..\src\Core\CrossProcessWriteLock.ahk
#Include ..\..\src\Core\RuleSpec.ahk
#Include ..\..\src\Core\ScriptRuleSpec.ahk
#Include ..\..\src\Core\RuleCompiler.ahk
#Include ..\..\src\Core\ScriptRuleCompiler.ahk
#Include ..\..\src\Core\MappingCodeRepository.ahk
#Include ..\..\src\Platform\Win32.ahk
#Include ..\..\src\Platform\WindowHierarchy.ahk
#Include ..\..\src\UI\ThemeHelpers.ahk
#Include ..\..\src\UI\AtomicControlLayout.ahk
class SystemIntegrationService {
    static ApplicationUserModelId := "realSilasYang.KeyMouseRemapperAssistant"
}
#Include ..\..\src\UI\ApplicationIcon.ahk
#Include ..\..\src\UI\CleanupCollector.ahk
#Include ..\..\src\UI\SvgRenderLibrary.ahk
#Include ..\..\src\UI\RoundedButtonPainter.ahk
#Include ..\..\src\UI\ControlAccessibilityService.ahk
#Include ..\..\app\Windows\DarkTooltipWindow.ahk
#Include ..\..\src\UI\MappingUiInteractions.ahk
#Include ..\..\app\UI\DarkMessageBox.ahk
#Include ..\..\src\UI\ListViewPseudoHeader.ahk
#Include ..\..\app\UI\ListViewSelectionPresenter.ahk
#Include ..\..\app\Windows\ListCellTooltipWindow.ahk
#Include ..\..\app\Windows\MappingContextPopupWindow.ahk
#Include ..\..\app\Windows\MappingBlockEditor.ahk
#Include ..\..\app\Windows\MappingWindow.ahk

ExitApp(RunMappingWindowSmoothScrollTests() ? 0 : 1)

RunMappingWindowSmoothScrollTests() {
    window := ""
    try {
        LocalizationService.Configure("zh-CN", "")
        UiThemeService.Configure("dark")
        app := MappingWindowSmoothScrollTestApp()
        window := MappingWindowSmoothScrollProbe(app)
        app.Window := window
        mappings := BuildSmoothScrollMappings()
        window.LoadRows(mappings)
        window.SetInitialClientSize(1040, 650)
        window.ShowWithOptions("x40 y40 NA")
        Sleep(100)

        ResetSmoothScrollList(window)
        wheelDownWParam := ((-MappingWindow.WheelDelta & 0xFFFF) << 16)
        SendMessage(Win32.WM_MOUSEWHEEL, wheelDownWParam, 0, ,
            window.List.Hwnd)
        immediateTop := GetSmoothScrollTopIndex(window)
        SmoothScrollAssert(immediateTop == 1
                && window.PendingListScrollLines == 2,
            Format("A wheel notch was not split into an immediate line and a queue: top={1}, pending={2}, remainder={3}.",
                immediateTop, window.PendingListScrollLines,
                window.ListWheelDeltaRemainder))
        singleGestureInterval := window.LastSmoothListScrollIntervalMs
        SmoothScrollAssert(WaitForSmoothScrollTopIndex(window, 3),
            "The queued wheel lines did not finish scrolling.")

        ResetSmoothScrollList(window)
        window.QueueSmoothListScroll(12)
        fastGestureInterval := window.LastSmoothListScrollIntervalMs
        SmoothScrollAssert(fastGestureInterval
                < singleGestureInterval,
            Format("Scroll speed did not accelerate with input intensity: single={1}, fast={2}.",
                singleGestureInterval, fastGestureInterval))

        ResetSmoothScrollList(window)
        window.WheelMessageCallCount := 0
        listRect := Buffer(16, 0)
        SmoothScrollAssert(DllCall("user32\GetWindowRect", "Ptr",
                window.List.Hwnd, "Ptr", listRect, "Int"),
            "The list screen bounds could not be read.")
        screenX := NumGet(listRect, 0, "Int") + 10
        screenY := NumGet(listRect, 4, "Int") + 10
        packedScreenPoint := (screenX & 0xFFFF)
            | ((screenY & 0xFFFF) << 16)
        PostMessage(Win32.WM_MOUSEWHEEL, wheelDownWParam,
            packedScreenPoint, , window.List.Hwnd)
        SmoothScrollAssert(WaitForSmoothScrollTopIndex(window, 3)
                && window.WheelMessageCallCount == 1,
            "The queued hardware-wheel path was not intercepted exactly once.")

        window.QueueSmoothListScroll(3)
        window.QueueSmoothListScroll(3)
        SmoothScrollAssert(GetSmoothScrollTopIndex(window) == 5
                && window.PendingListScrollLines == 4,
            "Consecutive wheel motion was not merged into the active queue.")
        SmoothScrollAssert(WaitForSmoothScrollTopIndex(window, 9),
            "The merged smooth-scroll queue did not finish.")

        window.QueueSmoothListScroll(3)
        window.QueueSmoothListScroll(-3)
        SmoothScrollAssert(GetSmoothScrollTopIndex(window) == 9
                && window.PendingListScrollLines == -2,
            "Reverse wheel motion did not change direction immediately.")
        SmoothScrollAssert(WaitForSmoothScrollTopIndex(window, 7),
            "The reversed smooth-scroll queue did not finish.")

        ResetSmoothScrollList(window)
        smallDeltaWParam := ((-40 & 0xFFFF) << 16)
        SendMessage(Win32.WM_MOUSEWHEEL, smallDeltaWParam, 0, ,
            window.List.Hwnd)
        SendMessage(Win32.WM_MOUSEWHEEL, smallDeltaWParam, 0, ,
            window.List.Hwnd)
        SmoothScrollAssert(GetSmoothScrollTopIndex(window) == 0,
            "Partial precision-wheel deltas scrolled before one notch.")
        SendMessage(Win32.WM_MOUSEWHEEL, smallDeltaWParam, 0, ,
            window.List.Hwnd)
        SmoothScrollAssert(GetSmoothScrollTopIndex(window) == 1,
            "Precision-wheel deltas were not accumulated to one notch.")

        window.QueueSmoothListScroll(3)
        SmoothScrollAssert(window.PendingListScrollLines > 0,
            "The replacement test did not start a scroll queue.")
        window.ReplaceRows(mappings)
        SmoothScrollAssert(window.PendingListScrollLines == 0,
            "Replacing rows did not cancel queued scrolling.")
        Sleep(100)
        SmoothScrollAssert(GetSmoothScrollTopIndex(window) == 0,
            "A stale scroll timer moved the replacement rows.")
        return true
    } catch as testError {
        FileAppend(testError.Message "`n" testError.Stack "`n", "**")
        return false
    } finally {
        if IsObject(window)
            try window.Dispose()
    }
}

BuildSmoothScrollMappings() {
    mappings := []
    Loop 30 {
        mappings.Push({Id: "平滑滚动规则 " A_Index,
            Source: "F" A_Index, Target: "F" (A_Index + 1),
            Scope: "全局", Enabled: true})
    }
    return mappings
}

ResetSmoothScrollList(window) {
    window.StopSmoothListScroll(true)
    SendMessage(Win32.LVM_SCROLL, 0, -100000, , window.List.Hwnd)
    Sleep(20)
    SmoothScrollAssert(GetSmoothScrollTopIndex(window) == 0,
        "The test list could not return to its first row.")
}

GetSmoothScrollTopIndex(window) {
    return SendMessage(Win32.LVM_GETTOPINDEX, 0, 0, , window.List.Hwnd)
}

WaitForSmoothScrollTopIndex(window, expected, timeoutMs := 1000) {
    deadline := A_TickCount + timeoutMs
    while A_TickCount < deadline {
        if GetSmoothScrollTopIndex(window) == expected
                && !window.PendingListScrollLines
            return true
        Sleep(10)
    }
    return false
}

SmoothScrollAssert(condition, message) {
    if !condition
        throw Error(message)
}

class MappingWindowSmoothScrollProbe extends MappingWindow {
    GetSystemWheelScrollLines() => 3

    HandleListMouseWheel(wParam, lParam, msg, hwnd) {
        if this.HasOwnProp("WheelMessageCallCount")
            this.WheelMessageCallCount++
        return super.HandleListMouseWheel(wParam, lParam, msg, hwnd)
    }
}

class MappingWindowSmoothScrollTestApp {
    __New() {
        this.SvgRenderer := SvgRenderLibrary(GetApplicationRootFilePath(
            "third_party\resvg\resvg.dll"))
        this.Capture := MappingWindowSmoothScrollCapture()
        this.Window := ""
    }

    OpenSettings(*) => true
    OpenHelpInfo(*) => true
    OpenAbout(*) => true
    UndoMappingChange(*) => true
    RedoMappingChange(*) => true
    GetSummaryText() => "30 条规则"
    TrySaveMainWindowLayout(*) => true
}

class MappingWindowSmoothScrollCapture {
    __New() {
        this.Active := false
    }

    Stop(*) => false
    IsInputBlocked() => false
}
