; Windows 的 DT_VCENTER 居中字体行框，但行框上下留白通常不对称。
; 这里测量实际可见字形相对基线的墨迹边界，让按钮文字与 SVG 的几何中心
; 共用同一条视觉中线。
class TextVisualAlignment {
    static InkBoundsCache := Map()
    static InkBoundsCacheLimit := 512

    static MeasureText(hdc, text) {
        if !hdc || text == ""
            return {Width: 0, Height: 0}
        extent := Buffer(8, 0)
        if !DllCall("gdi32\GetTextExtentPoint32W", "Ptr", hdc,
                "Str", text, "Int", StrLen(text), "Ptr", extent, "Int")
            return {Width: 0, Height: 0}
        return {Width: NumGet(extent, 0, "Int"),
            Height: NumGet(extent, 4, "Int")}
    }

    static GetFontCacheKey(hdc, textMetrics) {
        faceName := ""
        faceLength := DllCall("gdi32\GetTextFaceW", "Ptr", hdc,
            "Int", 0, "Ptr", 0, "Int")
        if faceLength > 1 {
            faceBuffer := Buffer(faceLength * 2, 0)
            if DllCall("gdi32\GetTextFaceW", "Ptr", hdc,
                    "Int", faceLength, "Ptr", faceBuffer, "Int")
                faceName := StrGet(faceBuffer)
        }
        return faceName Chr(31)
            . NumGet(textMetrics, 0, "Int") Chr(31)
            . NumGet(textMetrics, 4, "Int") Chr(31)
            . NumGet(textMetrics, 12, "Int") Chr(31)
            . NumGet(textMetrics, 28, "Int")
    }

    static MeasureInkBounds(hdc, text) {
        if !hdc || text == ""
            return false
        textMetrics := Buffer(64, 0)
        if !DllCall("gdi32\GetTextMetricsW", "Ptr", hdc,
                "Ptr", textMetrics, "Int")
            return false
        extent := this.MeasureText(hdc, text)
        lineHeight := extent.Height > 0 ? extent.Height
            : NumGet(textMetrics, 0, "Int")
        if lineHeight <= 0
            return false
        cacheKey := this.GetFontCacheKey(hdc, textMetrics)
            . Chr(30) . text
        if this.InkBoundsCache.Has(cacheKey)
            return this.InkBoundsCache[cacheKey]

        transform := Buffer(16, 0) ; MAT2，16.16 FIXED 单位矩阵。
        NumPut("Short", 1, transform, 2)
        NumPut("Short", 1, transform, 14)
        ascent := NumGet(textMetrics, 4, "Int")
        inkTop := 0x7FFFFFFF
        inkBottom := -0x7FFFFFFF
        foundVisibleGlyph := false
        Loop Parse text {
            codePoint := Ord(A_LoopField)
            if codePoint > 0xFFFF
                continue
            glyphMetrics := Buffer(20, 0)
            result := DllCall("gdi32\GetGlyphOutlineW", "Ptr", hdc,
                "UInt", codePoint, "UInt", 0, "Ptr", glyphMetrics,
                "UInt", 0, "Ptr", 0, "Ptr", transform, "UInt")
            if result == 0xFFFFFFFF
                continue
            blackBoxHeight := NumGet(glyphMetrics, 4, "UInt")
            if blackBoxHeight <= 0
                continue
            originY := NumGet(glyphMetrics, 12, "Int")
            glyphTop := ascent - originY
            inkTop := Min(inkTop, glyphTop)
            inkBottom := Max(inkBottom, glyphTop + blackBoxHeight)
            foundVisibleGlyph := true
        }
        if !foundVisibleGlyph
            return false

        result := {Top: inkTop, Bottom: inkBottom,
            LineHeight: lineHeight,
            CenterDelta: (inkTop + inkBottom - lineHeight) / 2}
        if this.InkBoundsCache.Count >= this.InkBoundsCacheLimit
            this.InkBoundsCache.Clear()
        this.InkBoundsCache[cacheKey] := result
        return result
    }

    static GetTextCenterOffset(hdc, text, containerHeight) {
        bounds := this.MeasureInkBounds(hdc, text)
        if !bounds || containerHeight <= 0
            return 0
        lineTop := Floor((containerHeight - bounds.LineHeight) / 2)
        currentInkCenter := lineTop + (bounds.Top + bounds.Bottom) / 2
        return Round(containerHeight / 2 - currentInkCenter)
    }

    static CreateCenteredTextRect(hdc, text, left, top, right, bottom) {
        offset := this.GetTextCenterOffset(hdc, text, bottom - top)
        rect := Buffer(16, 0)
        NumPut("Int", left, "Int", top + offset,
            "Int", right, "Int", bottom + offset, rect)
        return rect
    }

    static MeasureFontInkCenterDelta(fontName, pointSize, fontWeight,
            dpi, sampleText) {
        try dpi := Max(1, Integer(dpi))
        catch
            dpi := 96
        pixelHeight := Max(1, Round(pointSize * dpi / 72))
        fontHandle := DllCall("gdi32\CreateFontW",
            "Int", -pixelHeight, "Int", 0, "Int", 0, "Int", 0,
            "Int", fontWeight, "UInt", 0, "UInt", 0, "UInt", 0,
            "UInt", 1, "UInt", 0, "UInt", 0, "UInt", 0,
            "UInt", 0, "Str", fontName, "Ptr")
        screenDc := DllCall("user32\GetDC", "Ptr", 0, "Ptr")
        measureDc := screenDc ? DllCall("gdi32\CreateCompatibleDC",
            "Ptr", screenDc, "Ptr") : 0
        previousFont := 0
        try {
            if !fontHandle || !measureDc
                return 0
            previousFont := DllCall("gdi32\SelectObject", "Ptr",
                measureDc, "Ptr", fontHandle, "Ptr")
            bounds := this.MeasureInkBounds(measureDc, sampleText)
            return bounds ? bounds.CenterDelta : 0
        } finally {
            if previousFont
                DllCall("gdi32\SelectObject", "Ptr", measureDc,
                    "Ptr", previousFont, "Ptr")
            if measureDc
                DllCall("gdi32\DeleteDC", "Ptr", measureDc)
            if screenDc
                DllCall("user32\ReleaseDC", "Ptr", 0, "Ptr", screenDc)
            if fontHandle
                DllCall("gdi32\DeleteObject", "Ptr", fontHandle)
        }
    }
}

class RoundedButtonPainter {
    static RadiusDip := 6

    __New(parentColor) {
        this.ParentColor := parentColor
        this.ModuleHandle := 0
        this.Token := 0
        this.Ready := this.Start()
    }

    Start() {
        this.ModuleHandle := DllCall("kernel32\LoadLibraryExW",
            "WStr", "gdiplus.dll", "Ptr", 0, "UInt", 0x00000800, "Ptr")
        if !this.ModuleHandle
            return false
        startupInput := Buffer(A_PtrSize == 8 ? 24 : 16, 0)
        NumPut("UInt", 1, startupInput, 0)
        token := 0
        status := DllCall("gdiplus\GdiplusStartup", "UPtr*", &token,
            "Ptr", startupInput, "Ptr", 0, "UInt")
        if status || !token {
            DllCall("kernel32\FreeLibrary", "Ptr", this.ModuleHandle)
            this.ModuleHandle := 0
            return false
        }
        this.Token := token
        return true
    }

    Shutdown() {
        token := this.Token
        this.Token := 0
        if token
            try DllCall("gdiplus\GdiplusShutdown", "UPtr", token)
        if this.ModuleHandle {
            try DllCall("kernel32\FreeLibrary", "Ptr", this.ModuleHandle)
            this.ModuleHandle := 0
        }
        this.Ready := false
    }

    __Delete() {
        this.Shutdown()
    }

    SetParentColor(color) {
        this.ParentColor := String(color)
    }

    ParseColor(color) {
        normalized := Trim(String(color))
        if SubStr(normalized, 1, 1) == "#"
            normalized := SubStr(normalized, 2)
        if StrLower(SubStr(normalized, 1, 2)) == "0x"
            normalized := SubStr(normalized, 3)
        if !RegExMatch(normalized, "i)^[0-9a-f]{6}$")
            return 0
        return Integer("0x" normalized)
    }

    ColorToArgb(color) {
        return 0xFF000000 | this.ParseColor(color)
    }

    ColorToBgr(color) {
        value := this.ParseColor(color)
        return ((value & 0xFF) << 16) | (value & 0x00FF00)
            | ((value >> 16) & 0xFF)
    }

    CreateRoundedPath(width, height, radius, inset := 0.5,
            offsetX := 0, offsetY := 0) {
        path := 0
        if DllCall("gdiplus\GdipCreatePath", "Int", 0, "Ptr*", &path, "UInt") || !path
            return 0
        pathWidth := Max(1.0, width - inset * 2)
        pathHeight := Max(1.0, height - inset * 2)
        diameter := Max(2.0, Min(radius * 2.0, pathWidth, pathHeight))
        pathLeft := offsetX + inset
        pathTop := offsetY + inset
        try {
            DllCall("gdiplus\GdipAddPathArc", "Ptr", path,
                "Float", pathLeft, "Float", pathTop,
                "Float", diameter, "Float", diameter,
                "Float", 180.0, "Float", 90.0)
            DllCall("gdiplus\GdipAddPathArc", "Ptr", path,
                "Float", pathLeft + pathWidth - diameter, "Float", pathTop,
                "Float", diameter, "Float", diameter, "Float", 270.0, "Float", 90.0)
            DllCall("gdiplus\GdipAddPathArc", "Ptr", path,
                "Float", pathLeft + pathWidth - diameter,
                "Float", pathTop + pathHeight - diameter,
                "Float", diameter, "Float", diameter, "Float", 0.0, "Float", 90.0)
            DllCall("gdiplus\GdipAddPathArc", "Ptr", path,
                "Float", pathLeft, "Float", pathTop + pathHeight - diameter,
                "Float", diameter, "Float", diameter, "Float", 90.0, "Float", 90.0)
            DllCall("gdiplus\GdipClosePathFigure", "Ptr", path)
            return path
        } catch {
            DllCall("gdiplus\GdipDeletePath", "Ptr", path)
            return 0
        }
    }

    FillRoundedRectangle(hdc, left, top, right, bottom, color, radius) {
        width := right - left
        height := bottom - top
        if !this.Ready || !hdc || width <= 0 || height <= 0
            return false
        graphics := 0
        path := 0
        brush := 0
        if DllCall("gdiplus\GdipCreateFromHDC", "Ptr", hdc,
                "Ptr*", &graphics, "UInt") || !graphics
            return false
        try {
            DllCall("gdiplus\GdipSetSmoothingMode", "Ptr", graphics,
                "Int", 4)
            DllCall("gdiplus\GdipSetPixelOffsetMode", "Ptr", graphics,
                "Int", 4)
            DllCall("gdiplus\GdipSetCompositingQuality", "Ptr", graphics,
                "Int", 2)
            path := this.CreateRoundedPath(width, height, radius, 0.5,
                left, top)
            if !path
                return false
            if DllCall("gdiplus\GdipCreateSolidFill", "UInt",
                    this.ColorToArgb(color), "Ptr*", &brush, "UInt") || !brush
                return false
            return DllCall("gdiplus\GdipFillPath", "Ptr", graphics,
                "Ptr", brush, "Ptr", path, "UInt") == 0
        } finally {
            if brush
                DllCall("gdiplus\GdipDeleteBrush", "Ptr", brush)
            if path
                DllCall("gdiplus\GdipDeletePath", "Ptr", path)
            if graphics
                DllCall("gdiplus\GdipDeleteGraphics", "Ptr", graphics)
        }
    }

    MaskOutsideRoundedRectangle(hdc, outerLeft, outerTop, outerRight,
            outerBottom, innerLeft, innerTop, innerRight, innerBottom,
            color, radius) {
        if !this.Ready || !hdc || outerRight <= outerLeft
            || outerBottom <= outerTop || innerRight <= innerLeft
            || innerBottom <= innerTop
            return false
        graphics := 0
        path := 0
        brush := 0
        if DllCall("gdiplus\GdipCreateFromHDC", "Ptr", hdc,
                "Ptr*", &graphics, "UInt") || !graphics
            return false
        if DllCall("gdiplus\GdipCreatePath", "Int", 0,
                "Ptr*", &path, "UInt") || !path {
            DllCall("gdiplus\GdipDeleteGraphics", "Ptr", graphics)
            return false
        }
        try {
            DllCall("gdiplus\GdipSetSmoothingMode", "Ptr", graphics,
                "Int", 4)
            DllCall("gdiplus\GdipSetPixelOffsetMode", "Ptr", graphics,
                "Int", 4)
            DllCall("gdiplus\GdipAddPathRectangle", "Ptr", path,
                "Float", outerLeft, "Float", outerTop,
                "Float", outerRight - outerLeft,
                "Float", outerBottom - outerTop)
            DllCall("gdiplus\GdipStartPathFigure", "Ptr", path)
            inset := 0.5
            innerWidth := innerRight - innerLeft
            innerHeight := innerBottom - innerTop
            diameter := Max(2.0, Min(radius * 2.0,
                innerWidth - inset * 2, innerHeight - inset * 2))
            pathLeft := innerLeft + inset
            pathTop := innerTop + inset
            pathWidth := innerWidth - inset * 2
            pathHeight := innerHeight - inset * 2
            DllCall("gdiplus\GdipAddPathArc", "Ptr", path,
                "Float", pathLeft, "Float", pathTop,
                "Float", diameter, "Float", diameter,
                "Float", 180.0, "Float", 90.0)
            DllCall("gdiplus\GdipAddPathArc", "Ptr", path,
                "Float", pathLeft + pathWidth - diameter,
                "Float", pathTop, "Float", diameter, "Float", diameter,
                "Float", 270.0, "Float", 90.0)
            DllCall("gdiplus\GdipAddPathArc", "Ptr", path,
                "Float", pathLeft + pathWidth - diameter,
                "Float", pathTop + pathHeight - diameter,
                "Float", diameter, "Float", diameter,
                "Float", 0.0, "Float", 90.0)
            DllCall("gdiplus\GdipAddPathArc", "Ptr", path,
                "Float", pathLeft,
                "Float", pathTop + pathHeight - diameter,
                "Float", diameter, "Float", diameter,
                "Float", 90.0, "Float", 90.0)
            DllCall("gdiplus\GdipClosePathFigure", "Ptr", path)
            if DllCall("gdiplus\GdipCreateSolidFill", "UInt",
                    this.ColorToArgb(color), "Ptr*", &brush, "UInt") || !brush
                return false
            ; FillModeAlternate：外矩形减去同一路径中的内圆角矩形。
            return DllCall("gdiplus\GdipFillPath", "Ptr", graphics,
                "Ptr", brush, "Ptr", path, "UInt") == 0
        } finally {
            if brush
                DllCall("gdiplus\GdipDeleteBrush", "Ptr", brush)
            if path
                DllCall("gdiplus\GdipDeletePath", "Ptr", path)
            if graphics
                DllCall("gdiplus\GdipDeleteGraphics", "Ptr", graphics)
        }
    }

    DrawPixelImage(hdc, image, x, y, width, height) {
        if !IsObject(image) || !image.HasOwnProp("Pixels")
            || image.Width <= 0 || image.Height <= 0
            || width <= 0 || height <= 0
            return false
        graphics := 0
        bitmap := 0
        try {
            if DllCall("gdiplus\GdipCreateBitmapFromScan0",
                "Int", image.Width, "Int", image.Height,
                "Int", image.Width * 4, "Int", 0x000E200B,
                "Ptr", image.Pixels.Ptr, "Ptr*", &bitmap, "UInt") || !bitmap
                return false
            if DllCall("gdiplus\GdipCreateFromHDC", "Ptr", hdc,
                    "Ptr*", &graphics, "UInt") || !graphics
                return false
            DllCall("gdiplus\GdipSetCompositingMode", "Ptr", graphics,
                "Int", 0)
            DllCall("gdiplus\GdipSetCompositingQuality", "Ptr", graphics,
                "Int", 2)
            DllCall("gdiplus\GdipSetInterpolationMode", "Ptr", graphics,
                "Int", 7)
            DllCall("gdiplus\GdipSetPixelOffsetMode", "Ptr", graphics,
                "Int", 4)
            return DllCall("gdiplus\GdipDrawImageRectI", "Ptr", graphics,
                "Ptr", bitmap, "Int", x, "Int", y,
                "Int", width, "Int", height, "UInt") == 0
        } finally {
            if graphics
                DllCall("gdiplus\GdipDeleteGraphics", "Ptr", graphics)
            if bitmap
                DllCall("gdiplus\GdipDisposeImage", "Ptr", bitmap)
        }
    }

    DrawSurface(hdc, width, height, state) {
        graphics := 0
        path := 0
        brush := 0
        if DllCall("gdiplus\GdipCreateFromHDC", "Ptr", hdc,
            "Ptr*", &graphics, "UInt") || !graphics
            return false
        try {
            DllCall("gdiplus\GdipSetSmoothingMode", "Ptr", graphics, "Int", 4)
            DllCall("gdiplus\GdipSetPixelOffsetMode", "Ptr", graphics, "Int", 4)
            DllCall("gdiplus\GdipSetCompositingQuality", "Ptr", graphics, "Int", 2)
            DllCall("gdiplus\GdipGraphicsClear", "Ptr", graphics,
                "UInt", this.ColorToArgb(this.ParentColor))
            surfaceDpi := DllCall("user32\GetDpiForWindow", "Ptr",
                state.Control.Hwnd, "UInt")
            if !surfaceDpi
                surfaceDpi := 96
            radius := Max(3,
                Round(RoundedButtonPainter.RadiusDip * surfaceDpi / 96))
            path := this.CreateRoundedPath(width, height, radius)
            if !path
                return false
            if DllCall("gdiplus\GdipCreateSolidFill",
                "UInt", this.ColorToArgb(state.Current), "Ptr*", &brush, "UInt") || !brush
                return false
            return DllCall("gdiplus\GdipFillPath", "Ptr", graphics,
                "Ptr", brush, "Ptr", path, "UInt") == 0
        } finally {
            if brush
                DllCall("gdiplus\GdipDeleteBrush", "Ptr", brush)
            if path
                DllCall("gdiplus\GdipDeletePath", "Ptr", path)
            if graphics
                DllCall("gdiplus\GdipDeleteGraphics", "Ptr", graphics)
        }
    }

    DrawText(hdc, width, height, state) {
        font := DllCall("user32\SendMessageW", "Ptr", state.Control.Hwnd,
            "UInt", 0x0031, "Ptr", 0, "Ptr", 0, "Ptr")
        if !font
            font := DllCall("gdi32\GetStockObject", "Int", 17, "Ptr")
        previousFont := font ? DllCall("gdi32\SelectObject", "Ptr", hdc,
            "Ptr", font, "Ptr") : 0
        try {
            DllCall("gdi32\SetBkMode", "Ptr", hdc, "Int", 1)
            DllCall("gdi32\SetTextColor", "Ptr", hdc,
                "UInt", this.ColorToBgr(state.TextColor))
            textDpi := DllCall("user32\GetDpiForWindow", "Ptr",
                state.Control.Hwnd, "UInt")
            if !textDpi
                textDpi := 96
            inset := Max(4, Round(6 * textDpi / 96))
            textRect := Buffer(16, 0)
            text := ""
            try text := state.Control.Text
            hasLeadingImage := state.HasOwnProp("ButtonImage")
                && IsObject(state.ButtonImage)
            hasTrailingImage := state.HasOwnProp("TrailingButtonImage")
                && IsObject(state.TrailingButtonImage)
            if hasLeadingImage || hasTrailingImage {
                leadingMetrics := hasLeadingImage
                    ? this.GetButtonImageMetrics(state.ButtonImage, textDpi)
                    : {Width: 0, Height: 0, Gap: 0}
                trailingMetrics := hasTrailingImage
                    ? this.GetButtonImageMetrics(state.TrailingButtonImage,
                        textDpi)
                    : {Width: 0, Height: 0, Gap: 0}
                leadingGap := hasLeadingImage && text != ""
                    ? leadingMetrics.Gap : 0
                trailingGap := hasTrailingImage && text != ""
                    ? trailingMetrics.Gap : 0
                availableWidth := Max(1, width - inset * 2)
                multiline := state.HasOwnProp("Multiline") && state.Multiline
                textWidth := 0
                textHeight := 0
                imageAndGapWidth := leadingMetrics.Width + leadingGap
                    + trailingGap + trailingMetrics.Width
                maximumTextWidth := Max(1,
                    availableWidth - imageAndGapWidth)
                if text != "" {
                    if multiline {
                        NumPut("Int", 0, "Int", 0,
                            "Int", maximumTextWidth, "Int", height,
                            textRect)
                        DllCall("user32\DrawTextW", "Ptr", hdc,
                            "Str", text, "Int", -1, "Ptr", textRect,
                            "UInt", 0x00000C10, "Int")
                        textWidth := Min(maximumTextWidth,
                            NumGet(textRect, 8, "Int"))
                        textHeight := NumGet(textRect, 12, "Int")
                            - NumGet(textRect, 4, "Int")
                    } else {
                        extent := TextVisualAlignment.MeasureText(hdc, text)
                        textWidth := Min(maximumTextWidth, extent.Width)
                        textHeight := extent.Height
                    }
                }
                contentWidth := Min(availableWidth,
                    imageAndGapWidth + textWidth)
                contentX := Max(inset, Floor((width - contentWidth) / 2))
                contentHeight := Max(leadingMetrics.Height,
                    trailingMetrics.Height, textHeight)
                contentY := Max(0, Floor((height - contentHeight) / 2))
                if hasLeadingImage {
                    leadingY := multiline
                        ? contentY + Floor((contentHeight
                            - leadingMetrics.Height) / 2)
                        : Floor((height - leadingMetrics.Height) / 2)
                    this.DrawPixelImage(hdc, state.ButtonImage, contentX,
                        leadingY, leadingMetrics.Width,
                        leadingMetrics.Height)
                }
                trailingX := contentX + contentWidth
                    - trailingMetrics.Width
                if hasTrailingImage {
                    trailingY := multiline
                        ? contentY + Floor((contentHeight
                            - trailingMetrics.Height) / 2)
                        : Floor((height - trailingMetrics.Height) / 2)
                    this.DrawPixelImage(hdc, state.TrailingButtonImage,
                        trailingX, trailingY, trailingMetrics.Width,
                        trailingMetrics.Height)
                }
                if text != "" {
                    textLeft := contentX + leadingMetrics.Width + leadingGap
                    textRight := hasTrailingImage
                        ? trailingX - trailingGap : contentX + contentWidth
                    if multiline {
                        textTop := contentY
                            + Floor((contentHeight - textHeight) / 2)
                        NumPut("Int", textLeft, "Int", textTop,
                            "Int", textRight,
                            "Int", textTop + textHeight, textRect)
                    } else {
                        textRect := TextVisualAlignment.CreateCenteredTextRect(
                            hdc, text, textLeft, 0, textRight, height)
                    }
                    DllCall("user32\DrawTextW", "Ptr", hdc, "Str", text,
                        "Int", -1, "Ptr", textRect,
                        "UInt", multiline ? 0x00000810 : 0x00008824,
                        "Int")
                }
                return
            }
            if state.HasOwnProp("Multiline") && state.Multiline {
                NumPut("Int", inset, "Int", 0, "Int", width - inset,
                    "Int", height, textRect)
                DllCall("user32\DrawTextW", "Ptr", hdc, "Str", text,
                    "Int", -1, "Ptr", textRect, "UInt", 0x00000C10, "Int")
                textHeight := NumGet(textRect, 12, "Int")
                    - NumGet(textRect, 4, "Int")
                top := Max(0, (height - textHeight) // 2)
                NumPut("Int", inset, "Int", top, "Int", width - inset,
                    "Int", height, textRect)
                DllCall("user32\DrawTextW", "Ptr", hdc, "Str", text,
                    "Int", -1, "Ptr", textRect, "UInt", 0x00000811, "Int")
            } else {
                textRect := TextVisualAlignment.CreateCenteredTextRect(hdc,
                    text, inset, 0, width - inset, height)
                DllCall("user32\DrawTextW", "Ptr", hdc, "Str", text,
                    "Int", -1, "Ptr", textRect, "UInt", 0x00008825, "Int")
            }
        } finally {
            if previousFont
                DllCall("gdi32\SelectObject", "Ptr", hdc,
                    "Ptr", previousFont, "Ptr")
        }
    }

    GetButtonImageMetrics(image, dpi) {
        imageBox := Max(1, Round(image.SizeDip * dpi / 96))
        aspect := image.Width / image.Height
        imageWidth := aspect >= 1 ? imageBox
            : Max(1, Round(imageBox * aspect))
        imageHeight := aspect >= 1
            ? Max(1, Round(imageBox / aspect)) : imageBox
        return {Width: imageWidth, Height: imageHeight,
            Gap: Round(image.GapDip * dpi / 96)}
    }

    MeasureTextHeight(control, text, width, horizontalInsetDip := 0) {
        hdc := DllCall("user32\GetDC", "Ptr", control.Hwnd, "Ptr")
        if !hdc
            return 0
        font := DllCall("user32\SendMessageW", "Ptr", control.Hwnd,
            "UInt", 0x0031, "Ptr", 0, "Ptr", 0, "Ptr")
        if !font
            font := DllCall("gdi32\GetStockObject", "Int", 17, "Ptr")
        previousFont := font ? DllCall("gdi32\SelectObject", "Ptr", hdc,
            "Ptr", font, "Ptr") : 0
        try {
            measureDpi := DllCall("user32\GetDpiForWindow", "Ptr",
                control.Hwnd, "UInt")
            if !measureDpi
                measureDpi := 96
            inset := Round(horizontalInsetDip * measureDpi / 96)
            pixelWidth := Max(1, Round(width * measureDpi / 96) - inset * 2)
            textRect := Buffer(16, 0)
            NumPut("Int", 0, "Int", 0, "Int", pixelWidth,
                "Int", 0, textRect)
            DllCall("user32\DrawTextW", "Ptr", hdc, "Str", String(text),
                "Int", -1, "Ptr", textRect, "UInt", 0x00000C10, "Int")
            pixelHeight := NumGet(textRect, 12, "Int")
                - NumGet(textRect, 4, "Int")
            return Ceil(pixelHeight * 96 / measureDpi)
        } finally {
            if previousFont
                DllCall("gdi32\SelectObject", "Ptr", hdc,
                    "Ptr", previousFont, "Ptr")
            DllCall("user32\ReleaseDC", "Ptr", control.Hwnd, "Ptr", hdc)
        }
    }

    Draw(hdc, width, height, state) {
        if !this.Ready || width <= 0 || height <= 0
            return false
        memoryDc := DllCall("gdi32\CreateCompatibleDC", "Ptr", hdc, "Ptr")
        if !memoryDc
            return false
        bitmap := DllCall("gdi32\CreateCompatibleBitmap", "Ptr", hdc,
            "Int", width, "Int", height, "Ptr")
        if !bitmap {
            DllCall("gdi32\DeleteDC", "Ptr", memoryDc)
            return false
        }
        previousBitmap := DllCall("gdi32\SelectObject", "Ptr", memoryDc,
            "Ptr", bitmap, "Ptr")
        if !previousBitmap || previousBitmap == -1 {
            DllCall("gdi32\DeleteObject", "Ptr", bitmap)
            DllCall("gdi32\DeleteDC", "Ptr", memoryDc)
            return false
        }
        try {
            if !this.DrawSurface(memoryDc, width, height, state)
                return false
            this.DrawText(memoryDc, width, height, state)
            return !!DllCall("gdi32\BitBlt", "Ptr", hdc,
                "Int", 0, "Int", 0, "Int", width, "Int", height,
                "Ptr", memoryDc, "Int", 0, "Int", 0,
                "UInt", 0x00CC0020, "Int")
        } finally {
            if previousBitmap
                DllCall("gdi32\SelectObject", "Ptr", memoryDc,
                    "Ptr", previousBitmap, "Ptr")
            DllCall("gdi32\DeleteObject", "Ptr", bitmap)
            DllCall("gdi32\DeleteDC", "Ptr", memoryDc)
        }
    }
}
