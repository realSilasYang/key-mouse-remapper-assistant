; Application-level scaling layered on top of the monitor DPI. All public
; geometry methods accept or return the application's 96-DPI design units.

class UiScaleService {
    static DefaultPercent := 100
    static SupportedPercents := [100, 110, 125, 150, 175, 200]
    static Percent := 100
    static Factor := 1.0
    static PreparedGuis := Map()
    static DestroyHandler := ""

    static Configure(percent) {
        this.Percent := this.NormalizePercent(percent)
        this.Factor := this.Percent / 100
        return this.Percent
    }

    static NormalizePercent(value) {
        try {
            text := Trim(String(value))
            if SubStr(text, -1) == "%"
                text := Trim(SubStr(text, 1, -1))
            if !RegExMatch(text, "^\d+$")
                return this.DefaultPercent
            percent := Integer(text)
        } catch {
            return this.DefaultPercent
        }
        for supported in this.SupportedPercents {
            if percent == supported
                return percent
        }
        return this.DefaultPercent
    }

    static GetPercent() => this.Percent

    static GetFactor() => this.Factor

    static Scale(value) {
        try {
            return Round(Number(value) * this.Factor)
        } catch {
            return value
        }
    }

    static ToDesign(value) {
        try {
            return Number(value) / this.Factor
        } catch {
            return value
        }
    }

    static GetEffectiveDpi(hwnd := 0) {
        dpi := 96
        if hwnd {
            try dpi := DllCall("user32\GetDpiForWindow", "Ptr", hwnd,
                "UInt")
            catch
                dpi := 96
        }
        if !dpi
            dpi := 96
        return Max(1, Round(dpi * this.Factor))
    }

    static GetDesignMeasurementDpi(hwnd) {
        actualDpi := 96
        try actualDpi := DllCall("user32\GetDpiForWindow", "Ptr", hwnd,
            "UInt")
        if !actualDpi
            actualDpi := 96
        try parentHwnd := DllCall("user32\GetParent", "Ptr", hwnd, "Ptr")
        catch
            return actualDpi
        if !parentHwnd || !this.PreparedGuis.Has(parentHwnd)
            return actualDpi
        state := this.PreparedGuis[parentHwnd]
        if !state.Controls.Has(hwnd)
            return actualDpi
        record := state.Controls[hwnd]
        if !record.ScaledFont
            return actualDpi
        currentFont := SendMessage(0x0031, 0, 0, , hwnd)
        return currentFont == record.ScaledFont
            ? this.GetEffectiveDpi(hwnd) : actualDpi
    }

    static ScaleShowOptions(options) {
        result := String(options)
        for dimension in ["w", "h"]
            result := this.ScaleShowDimension(result, dimension)
        return result
    }

    static ScaleShowDimension(options, dimension) {
        if this.Factor == 1
            return options
        result := options
        start := 1
        pattern := "i)(^|\s)(" dimension ")(\d+(?:\.\d+)?)"
        while RegExMatch(result, pattern, &match, start) {
            replacement := match[1] match[2] this.Scale(match[3])
            result := SubStr(result, 1, match.Pos - 1) replacement
                . SubStr(result, match.Pos + match.Len)
            start := match.Pos + StrLen(replacement)
        }
        return result
    }

    static ScaleMinSizeOptions(width, height) {
        return "+MinSize" this.Scale(width) "x" this.Scale(height)
    }

    static IsPrepared(guiObj) {
        try hwnd := guiObj.Hwnd
        catch
            return false
        return hwnd && this.PreparedGuis.Has(hwnd)
    }

    static PrepareGui(guiObj, scaleGeometry := true) {
        if !IsObject(guiObj)
            return false
        try guiHwnd := guiObj.Hwnd
        catch
            return false
        if !guiHwnd || !DllCall("user32\IsWindow", "Ptr", guiHwnd, "Int")
            return false
        state := this.PreparedGuis.Has(guiHwnd)
            ? this.PreparedGuis[guiHwnd]
            : {Controls: Map(), MarginsScaled: false}
        this.PreparedGuis[guiHwnd] := state
        this.EnsureDestroyHandler()
        for controlHwnd, control in guiObj {
            if !controlHwnd || !DllCall("user32\IsWindow", "Ptr",
                    controlHwnd, "Int")
                continue
            isNewControl := !state.Controls.Has(controlHwnd)
            if isNewControl
                state.Controls[controlHwnd] := {ScaledFont: 0,
                    BaseFont: "", GeometryScaled: false}
            record := state.Controls[controlHwnd]
            if scaleGeometry && !record.GeometryScaled {
                record.GeometryScaled := true
                if this.Factor != 1 {
                    try {
                        control.GetPos(&x, &y, &width, &height)
                        control.Move(this.Scale(x), this.Scale(y),
                            this.Scale(width), this.Scale(height))
                    }
                }
            }
            this.ApplyScaledFont(controlHwnd, record)
        }
        if !state.MarginsScaled {
            state.MarginsScaled := true
            try {
            guiObj.MarginX := this.Scale(guiObj.MarginX)
            guiObj.MarginY := this.Scale(guiObj.MarginY)
            }
        }
        return true
    }

    static RefreshGuiFonts(guiObj) {
        return this.PrepareGui(guiObj, false)
    }

    static GetControlDesignPos(control, &x?, &y?, &width?, &height?) {
        try {
            control.GetPos(&currentX, &currentY, &currentWidth,
                &currentHeight)
            parentHwnd := DllCall("user32\GetParent", "Ptr", control.Hwnd,
                "Ptr")
            prepared := parentHwnd && this.PreparedGuis.Has(parentHwnd)
            x := prepared ? this.ToDesign(currentX) : currentX
            y := prepared ? this.ToDesign(currentY) : currentY
            width := prepared ? this.ToDesign(currentWidth) : currentWidth
            height := prepared ? this.ToDesign(currentHeight) : currentHeight
            return true
        } catch {
            return false
        }
    }

    static MoveControl(control, x := unset, y := unset, width := unset,
            height := unset) {
        try parentHwnd := DllCall("user32\GetParent", "Ptr", control.Hwnd,
            "Ptr")
        catch
            return false
        prepared := parentHwnd && this.PreparedGuis.Has(parentHwnd)
        try {
            control.GetPos(&currentX, &currentY, &currentWidth,
                &currentHeight)
            targetX := IsSet(x) ? (prepared ? this.Scale(x) : x) : currentX
            targetY := IsSet(y) ? (prepared ? this.Scale(y) : y) : currentY
            targetWidth := IsSet(width)
                ? (prepared ? this.Scale(width) : width) : currentWidth
            targetHeight := IsSet(height)
                ? (prepared ? this.Scale(height) : height) : currentHeight
            control.Move(targetX, targetY, targetWidth, targetHeight)
            return true
        } catch {
            return false
        }
    }

    static ApplyScaledFont(hwnd, record) {
        currentFont := SendMessage(0x0031, 0, 0, , hwnd) ; WM_GETFONT
        if !currentFont
            return false
        if record.ScaledFont && currentFont == record.ScaledFont
            return true
        if !record.ScaledFont || currentFont != record.ScaledFont {
            baseFont := Buffer(92, 0) ; LOGFONTW
            if DllCall("gdi32\GetObjectW", "Ptr", currentFont, "Int",
                    baseFont.Size, "Ptr", baseFont.Ptr, "Int") <= 0
                return false
            record.BaseFont := baseFont
        }
        if this.Factor == 1
            return true
        if !IsObject(record.BaseFont)
            return false
        scaledFontSpec := Buffer(record.BaseFont.Size, 0)
        DllCall("kernel32\RtlMoveMemory", "Ptr", scaledFontSpec.Ptr,
            "Ptr", record.BaseFont.Ptr, "UPtr", record.BaseFont.Size)
        baseHeight := NumGet(scaledFontSpec, 0, "Int")
        if baseHeight
            NumPut("Int", Round(baseHeight * this.Factor), scaledFontSpec, 0)
        scaledFont := DllCall("gdi32\CreateFontIndirectW", "Ptr",
            scaledFontSpec.Ptr, "Ptr")
        if !scaledFont
            return false
        previousScaledFont := record.ScaledFont
        SendMessage(0x0030, scaledFont, 1, , hwnd) ; WM_SETFONT
        record.ScaledFont := scaledFont
        if previousScaledFont && previousScaledFont != scaledFont
            DllCall("gdi32\DeleteObject", "Ptr", previousScaledFont, "Int")
        return true
    }

    static EnsureDestroyHandler() {
        if IsObject(this.DestroyHandler)
            return true
        this.DestroyHandler := ObjBindMethod(this, "OnWindowDestroyed")
        OnMessage(0x0082, this.DestroyHandler) ; WM_NCDESTROY
        return true
    }

    static OnWindowDestroyed(wParam, lParam, message, hwnd) {
        if !this.PreparedGuis.Has(hwnd)
            return
        state := this.PreparedGuis[hwnd]
        this.PreparedGuis.Delete(hwnd)
        for controlHwnd, record in state.Controls {
            if record.ScaledFont
                DllCall("gdi32\DeleteObject", "Ptr", record.ScaledFont,
                    "Int")
        }
    }
}
