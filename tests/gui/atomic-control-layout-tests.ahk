#Requires AutoHotkey v2.0 64-bit
#SingleInstance Off
#Warn All, StdOut

#Include ..\..\src\UI\AtomicControlLayout.ahk

atomicLayoutExitCode := RunAtomicControlLayoutTests()
ExitApp(IsNumber(atomicLayoutExitCode) ? atomicLayoutExitCode : 0)

RunAtomicControlLayoutTests() {
    guiObj := ""
    exitCode := 0
    try {
        backgroundColor := "202020"
        guiObj := Gui("+Resize", "atomic-layout-test")
        guiObj.Opt("+AlwaysOnTop")
        guiObj.MarginX := 0
        guiObj.MarginY := 0
        guiObj.BackColor := backgroundColor
        moved := guiObj.Add("Text",
            "x10 y20 w80 h30 BackgroundA04040")
        unchanged := guiObj.Add("Text",
            "x210 y20 w90 h30 Background4060A0")

        hiddenResult := AtomicControlLayout.Apply(guiObj, [
            {Control: moved, X: 20, Y: 30, Width: 80, Height: 30},
            {Control: unchanged, X: 210, Y: 20, Width: 90, Height: 30}
        ], {ParentColor: backgroundColor, ClearMargin: 2})
        AtomicLayoutAssert(hiddenResult.Status == AtomicControlLayout.Applied
                && hiddenResult.Mode == AtomicControlLayout.ModeDirect
                && hiddenResult.Changed && !hiddenResult.Repainted
                && AtomicControlLayoutEraseGuard.AttachedHwnds.Count == 0,
            "Hidden initialization did not use the direct no-guard path.")

        guiObj.Show("NA x80 y80 w420 h220")
        Sleep(60)
        redrawTransaction := AtomicControlRedrawTransaction.Begin(
            [moved, unchanged])
        nestedRedrawTransaction := AtomicControlRedrawTransaction.Begin(
            [moved, unchanged], false)
        AtomicLayoutAssert(redrawTransaction.Active
                && redrawTransaction.Hwnds.Length == 2
                && nestedRedrawTransaction.Active
                && nestedRedrawTransaction.Hwnds.Length == 2
                && AtomicControlRedrawTransaction.ActiveHwndCounts.Count == 2
                && !DllCall("user32\IsWindowVisible", "Ptr", moved.Hwnd,
                    "Int")
                && !DllCall("user32\IsWindowVisible", "Ptr",
                    unchanged.Hwnd, "Int"),
            "The child redraw transaction did not suspend every leaf.")
        AtomicLayoutAssert(AtomicControlRedrawTransaction.End(
                nestedRedrawTransaction)
                && !DllCall("user32\IsWindowVisible", "Ptr", moved.Hwnd,
                    "Int")
                && AtomicControlRedrawTransaction.ActiveHwndCounts.Count == 2,
            "Ending a nested child transaction resumed its outer surface.")
        AtomicLayoutAssert(AtomicControlRedrawTransaction.End(
                redrawTransaction)
                && !redrawTransaction.Active
                && AtomicControlRedrawTransaction.ActiveHwndCounts.Count == 0
                && DllCall("user32\IsWindowVisible", "Ptr", moved.Hwnd,
                    "Int")
                && DllCall("user32\IsWindowVisible", "Ptr",
                    unchanged.Hwnd, "Int")
                && !AtomicControlRedrawTransaction.End(redrawTransaction),
            "The child redraw transaction did not resume exactly once.")
        moved.GetPos(&movedX, &movedY, &movedWidth, &movedHeight)
        unchanged.GetPos(&unchangedX, &unchangedY, &unchangedWidth,
            &unchangedHeight)
        AtomicLayoutProbe.Reset()
        deferredResult := AtomicLayoutProbe.Apply(guiObj, [
            {Control: moved, X: movedX + 70, Y: movedY + 35,
                Width: movedWidth + 25, Height: movedHeight + 10},
            {Control: unchanged, X: unchangedX, Y: unchangedY,
                Width: unchangedWidth, Height: unchangedHeight}
        ], {ParentColor: backgroundColor, ClearMargin: 2})
        AtomicLayoutAssert(deferredResult.Status == AtomicControlLayout.Applied
                && deferredResult.Mode == AtomicControlLayout.ModeDeferred
                && deferredResult.Repainted
                && AtomicLayoutProbe.DpiReadCount == 1
                && AtomicLayoutProbe.DeferredCount == 1
                && AtomicLayoutProbe.RepaintCount == 1
                && deferredResult.OldRects.Length == 1
                && deferredResult.NewRects.Length == 1
                && deferredResult.ActualRects.Count == 2,
            "Visible layout did not use one verified deferred transaction.")
        AtomicLayoutAssert(
            AtomicControlLayoutEraseGuard.AttachedHwnds.Has(moved.Hwnd)
                && !AtomicControlLayoutEraseGuard.AttachedHwnds.Has(
                    unchanged.Hwnd)
                && AtomicControlLayoutEraseGuard.ActiveHwndCounts.Count == 0,
            "Erase protection was not limited to the moved leaf control.")
        oldRect := deferredResult.OldRects[1]
        oldPositionPixel := ReadAtomicLayoutPixel(guiObj.Hwnd,
            oldRect.Left + 4, oldRect.Top + 4)
        expectedBackgroundPixel := AtomicLayoutColorRef(backgroundColor)
        AtomicLayoutAssert(oldPositionPixel == expectedBackgroundPixel,
            Format("The old control position retained surface {1:06X}; expected {2:06X}.",
                oldPositionPixel, expectedBackgroundPixel))

        moved.GetPos(&movedX, &movedY, &movedWidth, &movedHeight)
        unchanged.GetPos(&unchangedX, &unchangedY, &unchangedWidth,
            &unchangedHeight)
        AtomicLayoutProbe.Reset()
        unchangedResult := AtomicLayoutProbe.Apply(guiObj, [
            {Control: moved, X: movedX, Y: movedY,
                Width: movedWidth, Height: movedHeight},
            {Control: unchanged, X: unchangedX, Y: unchangedY,
                Width: unchangedWidth, Height: unchangedHeight}
        ], {ParentColor: backgroundColor, ClearMargin: 2})
        AtomicLayoutAssert(unchangedResult.Status
                == AtomicControlLayout.Unchanged
                && !unchangedResult.Changed && !unchangedResult.Repainted
                && AtomicLayoutProbe.DpiReadCount == 1
                && AtomicLayoutProbe.DeferredCount == 0
                && AtomicLayoutProbe.RepaintCount == 0
                && AtomicControlLayoutEraseGuard.ActiveHwndCounts.Count == 0,
            "Unchanged layout installed protection or requested painting.")
        AtomicLayoutProbe.Reset()
        sharedRound := AtomicLayoutProbe.BeginRound(guiObj)
        sharedRoundResult := AtomicLayoutProbe.Apply(guiObj, [
            {Control: moved, X: movedX, Y: movedY,
                Width: movedWidth, Height: movedHeight},
            {Control: unchanged, X: unchangedX, Y: unchangedY,
                Width: unchangedWidth, Height: unchangedHeight}
        ], {ParentColor: backgroundColor, ClearMargin: 2,
            Round: sharedRound})
        AtomicLayoutAssert(sharedRoundResult.Status
                == AtomicControlLayout.Unchanged
                && AtomicLayoutProbe.DpiReadCount == 1,
            "A shared layout round read DPI more than once.")

        blockedBefore := AtomicControlLayoutEraseGuard.BlockedEraseCount
        fallbackResult := AtomicLayoutFallbackProbe.Apply(guiObj, [
            {Control: moved, X: movedX + 45, Y: movedY,
                Width: movedWidth, Height: movedHeight},
            {Control: unchanged, X: unchangedX, Y: unchangedY,
                Width: unchangedWidth, Height: unchangedHeight}
        ], {ParentColor: backgroundColor, ClearMargin: 2})
        AtomicLayoutAssert(fallbackResult.Status
                == AtomicControlLayout.Applied
                && fallbackResult.Mode == AtomicControlLayout.ModeFallback
                && fallbackResult.Repainted
                && AtomicLayoutFallbackProbe.DpiReadCount == 1
                && AtomicLayoutFallbackProbe.DeferredCount == 1
                && AtomicLayoutFallbackProbe.RepaintCount == 1
                && AtomicControlLayoutEraseGuard.BlockedEraseCount
                    > blockedBefore
                && AtomicControlLayoutEraseGuard.ActiveHwndCounts.Count == 0,
            Format("Deferred failure fallback mismatch: status={1}, mode={2}, repaint={3}, dpi={4}, deferred={5}, repaintCalls={6}, blocked={7}/{8}, active={9}.",
                fallbackResult.Status, fallbackResult.Mode,
                fallbackResult.Repainted,
                AtomicLayoutFallbackProbe.DpiReadCount,
                AtomicLayoutFallbackProbe.DeferredCount,
                AtomicLayoutFallbackProbe.RepaintCount,
                AtomicControlLayoutEraseGuard.BlockedEraseCount,
                blockedBefore + 1,
                AtomicControlLayoutEraseGuard.ActiveHwndCounts.Count))

        ReportAtomicLayoutResult("PASS atomic-control-layout`n")
    } catch as testError {
        ReportAtomicLayoutResult(testError.Message "`n"
            testError.Stack "`n", true)
        exitCode := 1
    } finally {
        if IsObject(guiObj)
            try guiObj.Destroy()
    }
    return exitCode
}

ReportAtomicLayoutResult(message, isError := false) {
    try {
        FileAppend(message, isError ? "**" : "*")
        return true
    } catch {
        return false
    }
}

class AtomicLayoutProbe extends AtomicControlLayout {
    static DpiReadCount := 0
    static DeferredCount := 0
    static RepaintCount := 0

    static Reset() {
        this.DpiReadCount := 0
        this.DeferredCount := 0
        this.RepaintCount := 0
    }

    static GetDpi(parentHwnd) {
        this.DpiReadCount++
        return AtomicControlLayout.GetDpi(parentHwnd)
    }

    static TryApplyDeferred(entries) {
        this.DeferredCount++
        return AtomicControlLayout.TryApplyDeferred(entries)
    }

    static Repaint(parentHwnd, oldRects, newRects, color, margin,
            changedHwnds := "") {
        this.RepaintCount++
        return AtomicControlLayout.Repaint(parentHwnd, oldRects, newRects,
            color, margin, changedHwnds)
    }
}

class AtomicLayoutFallbackProbe extends AtomicControlLayout {
    static DpiReadCount := 0
    static DeferredCount := 0
    static RepaintCount := 0

    static GetDpi(parentHwnd) {
        this.DpiReadCount++
        return AtomicControlLayout.GetDpi(parentHwnd)
    }

    static TryApplyDeferred(entries) {
        this.DeferredCount++
        DllCall("user32\SendMessageW", "Ptr", entries[1].Hwnd,
            "UInt", 0x0014, "Ptr", 0, "Ptr", 0, "Ptr")
        return false
    }

    static Repaint(parentHwnd, oldRects, newRects, color, margin,
            changedHwnds := "") {
        this.RepaintCount++
        return AtomicControlLayout.Repaint(parentHwnd, oldRects, newRects,
            color, margin, changedHwnds)
    }
}

ReadAtomicLayoutPixel(hwnd, x, y) {
    hdc := DllCall("user32\GetDC", "Ptr", hwnd, "Ptr")
    if !hdc
        return 0xFFFFFFFF
    try return DllCall("gdi32\GetPixel", "Ptr", hdc,
        "Int", x, "Int", y, "UInt")
    finally DllCall("user32\ReleaseDC", "Ptr", hwnd, "Ptr", hdc)
}

AtomicLayoutColorRef(color) {
    value := Integer("0x" color)
    return ((value & 0xFF) << 16) | (value & 0x00FF00)
        | ((value >> 16) & 0xFF)
}

AtomicLayoutAssert(value, message) {
    if !value
        throw Error(message)
}
