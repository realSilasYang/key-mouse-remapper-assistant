#Requires AutoHotkey v2.0 64-bit
#SingleInstance Off
#Warn All, StdOut

#Include ..\TestSupport.ahk
#Include ..\..\src\UI\CleanupCollector.ahk
#Include ..\..\src\UI\ApplicationIcon.ahk
#Include ..\..\src\UI\SvgRenderLibrary.ahk
#Include ..\..\src\UI\RoundedButtonPainter.ahk

CreatePainterCanvas(width, height) {
    screenDc := DllCall("user32\GetDC", "Ptr", 0, "Ptr")
    targetDc := screenDc ? DllCall("gdi32\CreateCompatibleDC",
        "Ptr", screenDc, "Ptr") : 0
    bitmap := targetDc ? DllCall("gdi32\CreateCompatibleBitmap",
        "Ptr", screenDc, "Int", width, "Int", height, "Ptr") : 0
    AssertTrue(screenDc && targetDc && bitmap,
        "无法创建圆角绘制像素画布")
    previousBitmap := DllCall("gdi32\SelectObject", "Ptr", targetDc,
        "Ptr", bitmap, "Ptr")
    return {ScreenDc: screenDc, TargetDc: targetDc, Bitmap: bitmap,
        PreviousBitmap: previousBitmap}
}

DestroyPainterCanvas(canvas) {
    if canvas.PreviousBitmap
        DllCall("gdi32\SelectObject", "Ptr", canvas.TargetDc,
            "Ptr", canvas.PreviousBitmap)
    if canvas.Bitmap
        DllCall("gdi32\DeleteObject", "Ptr", canvas.Bitmap)
    if canvas.TargetDc
        DllCall("gdi32\DeleteDC", "Ptr", canvas.TargetDc)
    if canvas.ScreenDc
        DllCall("user32\ReleaseDC", "Ptr", 0, "Ptr", canvas.ScreenDc)
}

FillCanvas(hdc, width, height, colorRef) {
    brush := DllCall("gdi32\CreateSolidBrush", "UInt", colorRef, "Ptr")
    rect := Buffer(16, 0)
    NumPut("Int", width, rect, 8)
    NumPut("Int", height, rect, 12)
    try return DllCall("user32\FillRect", "Ptr", hdc, "Ptr", rect,
        "Ptr", brush, "Int") != 0
    finally DllCall("gdi32\DeleteObject", "Ptr", brush)
}

AssertRoundedMask(painter) {
    canvas := CreatePainterCanvas(120, 40)
    selectionColor := painter.ColorToBgr("264F78")
    surfaceColor := painter.ColorToBgr("F8FAFC")
    try {
        AssertTrue(FillCanvas(canvas.TargetDc, 120, 40, selectionColor),
            "无法填充圆角选中态测试画布")
        AssertTrue(painter.MaskOutsideRoundedRectangle(canvas.TargetDc,
            0, 0, 120, 40, 4, 2, 116, 38, "F8FAFC", 7),
            "GDI+ ListView 圆角遮罩绘制失败")
        AssertEqual(surfaceColor, DllCall("gdi32\GetPixel", "Ptr",
            canvas.TargetDc, "Int", 1, "Int", 1, "UInt"),
            "圆角遮罩没有擦除矩形选中态外角")
        AssertEqual(selectionColor, DllCall("gdi32\GetPixel", "Ptr",
            canvas.TargetDc, "Int", 60, "Int", 20, "UInt"),
            "圆角遮罩覆盖了选中态中央内容")
        blendedPixels := 0
        Loop 12 {
            y := A_Index
            Loop 14 {
                x := A_Index + 2
                color := DllCall("gdi32\GetPixel", "Ptr", canvas.TargetDc,
                    "Int", x, "Int", y, "UInt")
                if color != selectionColor && color != surfaceColor
                    blendedPixels++
            }
        }
        AssertTrue(blendedPixels > 0,
            "圆角遮罩边缘没有生成 GDI+ 抗锯齿混合像素")
    } finally DestroyPainterCanvas(canvas)
}

AssertSvgComposition(painter) {
    renderer := SvgRenderLibrary(A_ScriptDir
        "\..\..\third_party\resvg\resvg.dll")
    testGui := Gui("+ToolWindow")
    button := testGui.Add("Text", "w120 h40", "设置")
    canvas := CreatePainterCanvas(120, 40)
    try {
        snapshot := renderer.RenderFile(A_ScriptDir
            "\..\..\assets\ui-icons\lucide\settings.svg", 96, 128)
        AssertTrue(IsObject(snapshot) && snapshot.Width == 128
            && snapshot.Height == 128, "Lucide 设置图标无法渲染")
        state := {Control: button, Current: "D0DEEC",
            TextColor: "334155", ButtonImage: {
                Width: snapshot.Width, Height: snapshot.Height,
                Pixels: snapshot.Pixels, SizeDip: 15, GapDip: 6}}
        AssertTrue(painter.Draw(canvas.TargetDc, 120, 40, state),
            "带 SVG 图标的圆角按钮绘制失败")
        backgroundColor := painter.ColorToBgr("D0DEEC")
        blackPixels := 0
        changedPixels := 0
        Loop 18 {
            y := 11 + A_Index
            Loop 20 {
                x := 35 + A_Index
                color := DllCall("gdi32\GetPixel", "Ptr", canvas.TargetDc,
                    "Int", x, "Int", y, "UInt")
                if color != backgroundColor
                    changedPixels++
                if color == 0
                    blackPixels++
            }
        }
        AssertTrue(changedPixels > 0, "SVG 设置图标没有绘制到按钮表面")
        AssertEqual(0, blackPixels, "SVG 透明合成产生了黑色底板或黑边")
    } finally {
        DestroyPainterCanvas(canvas)
        renderer.Shutdown()
        testGui.Destroy()
    }
}

AssertDualSvgComposition(painter) {
    renderer := SvgRenderLibrary(A_ScriptDir
        "\..\..\third_party\resvg\resvg.dll")
    testGui := Gui("+ToolWindow")
    button := testGui.Add("Text", "w280 h52", "点击录制来源按键")
    canvas := CreatePainterCanvas(280, 52)
    try {
        keyboardSnapshot := renderer.RenderFile(A_ScriptDir
            "\..\..\assets\ui-icons\lucide\keyboard.svg", 96, 128)
        mouseSnapshot := renderer.RenderFile(A_ScriptDir
            "\..\..\assets\ui-icons\lucide\mouse.svg", 96, 128)
        AssertTrue(IsObject(keyboardSnapshot) && IsObject(mouseSnapshot),
            "录制按钮的键盘或鼠标 Lucide 图标无法渲染")
        state := {Control: button, Current: "333333", TextColor: "FFFFFF",
            ButtonImage: {
                Width: keyboardSnapshot.Width, Height: keyboardSnapshot.Height,
                Pixels: keyboardSnapshot.Pixels, SizeDip: 17, GapDip: 8},
            TrailingButtonImage: {
                Width: mouseSnapshot.Width, Height: mouseSnapshot.Height,
                Pixels: mouseSnapshot.Pixels, SizeDip: 17, GapDip: 8}}
        AssertTrue(painter.Draw(canvas.TargetDc, 280, 52, state),
            "键盘、文字、鼠标双图标组合绘制失败")
        backgroundColor := painter.ColorToBgr("333333")
        leftChangedPixels := 0
        rightChangedPixels := 0
        Loop 52 {
            y := A_Index - 1
            Loop 70 {
                leftColor := DllCall("gdi32\GetPixel", "Ptr",
                    canvas.TargetDc, "Int", A_Index - 1, "Int", y, "UInt")
                rightColor := DllCall("gdi32\GetPixel", "Ptr",
                    canvas.TargetDc, "Int", 210 + A_Index - 1,
                    "Int", y, "UInt")
                if leftColor != backgroundColor
                    leftChangedPixels++
                if rightColor != backgroundColor
                    rightChangedPixels++
            }
        }
        AssertTrue(leftChangedPixels > 0 && rightChangedPixels > 0,
            "双图标组合没有在文字左右两侧同时绘制图像")
    } finally {
        DestroyPainterCanvas(canvas)
        renderer.Shutdown()
        testGui.Destroy()
    }
}

MeasureLeadingCommandSymbolPixels(painter, symbol) {
    width := 40
    height := 30
    canvas := CreatePainterCanvas(width, height)
    try {
        AssertTrue(FillCanvas(canvas.TargetDc, width, height, 0),
            "无法填充状态按钮符号像素画布")
        AssertTrue(painter.DrawLeadingCommandSymbol(canvas.TargetDc, symbol,
            10, 0, 30, height, "FFFFFF", 10),
            "无法绘制状态按钮符号：" symbol)
        minimumX := width
        minimumY := height
        maximumX := -1
        maximumY := -1
        visiblePixels := 0
        Loop height {
            y := A_Index - 1
            Loop width {
                x := A_Index - 1
                if DllCall("gdi32\GetPixel", "Ptr", canvas.TargetDc,
                        "Int", x, "Int", y, "UInt") == 0
                    continue
                minimumX := Min(minimumX, x)
                minimumY := Min(minimumY, y)
                maximumX := Max(maximumX, x)
                maximumY := Max(maximumY, y)
                visiblePixels++
            }
        }
        AssertTrue(visiblePixels > 0,
            "状态按钮符号没有可见像素：" symbol)
        return {Width: maximumX - minimumX + 1,
            Height: maximumY - minimumY + 1,
            CenterX: (minimumX + maximumX) / 2,
            CenterY: (minimumY + maximumY) / 2,
            PixelCount: visiblePixels}
    } finally DestroyPainterCanvas(canvas)
}

AssertLeadingCommandSymbolGeometry(painter) {
    referenceBounds := MeasureLeadingCommandSymbolPixels(painter, "▶")
    pauseBounds := MeasureLeadingCommandSymbolPixels(painter, "⏸")
    weightRatio := pauseBounds.PixelCount / referenceBounds.PixelCount
    AssertTrue(Abs(pauseBounds.Width - referenceBounds.Width) <= 1
            && Abs(pauseBounds.Height - referenceBounds.Height) <= 1,
        "暂停与恢复符号的外接尺寸不一致")
    AssertTrue(Abs(pauseBounds.CenterX - referenceBounds.CenterX) <= 0.5
            && Abs(pauseBounds.CenterY - referenceBounds.CenterY) <= 0.5,
        "暂停与恢复符号的可见中心不一致")
    AssertTrue(weightRatio >= 0.7 && weightRatio <= 1.4,
        "暂停与恢复符号的视觉重量差异过大：" weightRatio)
}

AssertSvgInputBounds() {
    renderer := SvgRenderLibrary("missing-resvg.dll")
    try {
        AssertTrue(renderer.IsValidSourceBuffer(Buffer(1), 1),
            "SVG 实际读取缓冲区的有效大小被拒绝")
        AssertTrue(!renderer.IsValidSourceBuffer(Buffer(1), 2),
            "SVG 文件检查与实际读取大小不一致时仍被接受")
        oversized := Buffer(SvgRenderLibrary.MaximumInputBytes + 1)
        AssertTrue(!renderer.IsValidSourceBuffer(oversized, oversized.Size),
            "SVG 实际读取缓冲区绕过了最大输入限制")
    } finally renderer.Shutdown()
}

AssertVisualTextCenter(fontName, pointSize, fontWeight, dpi, text) {
    width := Max(160, Round(160 * dpi / 96))
    height := Max(40, Round(40 * dpi / 96))
    pixelHeight := Max(1, Round(pointSize * dpi / 72))
    canvas := CreatePainterCanvas(width, height)
    fontHandle := DllCall("gdi32\CreateFontW",
        "Int", -pixelHeight, "Int", 0, "Int", 0, "Int", 0,
        "Int", fontWeight, "UInt", 0, "UInt", 0, "UInt", 0,
        "UInt", 1, "UInt", 0, "UInt", 0, "UInt", 0,
        "UInt", 0, "Str", fontName, "Ptr")
    previousFont := 0
    try {
        AssertTrue(fontHandle, "无法创建字形视觉中心验证字体")
        previousFont := DllCall("gdi32\SelectObject", "Ptr",
            canvas.TargetDc, "Ptr", fontHandle, "Ptr")
        DllCall("gdi32\PatBlt", "Ptr", canvas.TargetDc,
            "Int", 0, "Int", 0, "Int", width, "Int", height,
            "UInt", 0x00000042, "Int")
        DllCall("gdi32\SetBkMode", "Ptr", canvas.TargetDc, "Int", 1)
        DllCall("gdi32\SetTextColor", "Ptr", canvas.TargetDc,
            "UInt", 0x00FFFFFF)
        textRect := TextVisualAlignment.CreateCenteredTextRect(
            canvas.TargetDc, text, 0, 0, width, height)
        DllCall("user32\DrawTextW", "Ptr", canvas.TargetDc,
            "Str", text, "Int", -1, "Ptr", textRect,
            "UInt", 0x00000825, "Int")

        minimumY := height
        maximumY := -1
        Loop height {
            y := A_Index - 1
            Loop width {
                x := A_Index - 1
                if DllCall("gdi32\GetPixel", "Ptr", canvas.TargetDc,
                        "Int", x, "Int", y, "UInt") != 0 {
                    minimumY := Min(minimumY, y)
                    maximumY := Max(maximumY, y)
                }
            }
        }
        AssertTrue(maximumY >= minimumY,
            "视觉中心验证没有绘制出文字像素：" text)
        visibleCenter := (minimumY + maximumY + 1) / 2
        AssertTrue(Abs(visibleCenter - height / 2) <= 1,
            "文字可见墨迹未居中：DPI=" dpi "，偏差="
                Round(visibleCenter - height / 2, 2))
    } finally {
        if previousFont
            DllCall("gdi32\SelectObject", "Ptr", canvas.TargetDc,
                "Ptr", previousFont)
        if fontHandle
            DllCall("gdi32\DeleteObject", "Ptr", fontHandle)
        DestroyPainterCanvas(canvas)
    }
}

AssertTextVisualAlignment() {
    TextVisualAlignment.InkBoundsCache.Clear()
    AssertVisualTextCenter("Microsoft YaHei UI", 10, 700, 96,
        "界面设置")
    AssertVisualTextCenter("Microsoft YaHei UI", 10, 700, 288,
        "界面设置")
    AssertVisualTextCenter("Segoe UI", 10, 700, 96, "Settings")
    cachedCount := TextVisualAlignment.InkBoundsCache.Count
    delta := TextVisualAlignment.MeasureFontInkCenterDelta(
        "Segoe UI", 10, 700, 96, "Settings")
    AssertTrue(IsNumber(delta) && cachedCount > 0
            && TextVisualAlignment.InkBoundsCache.Count >= cachedCount,
        "文字视觉中心测量或缓存契约失效")
}

AssertSemanticLucideColors() {
    expectedColors := Map(
        "arrow-right.svg", "93A8EA",
        "circle-check-big.svg", "03C078",
        "circle-pause.svg", "F4A71D",
        "eraser.svg", "EF4444",
        "file-output.svg", "5DD4E8",
        "keyboard.svg", "93A8EA",
        "logs.svg", "5DD4E8",
        "mouse.svg", "60A5FA",
        "pencil.svg", "B9A3FF",
        "play.svg", "69D19A",
        "refresh-cw-action.svg", "DCEBFF",
        "settings.svg", "BABABC",
        "square-plus.svg", "93A8EA",
        "target.svg", "60A5FA",
        "trash-2.svg", "EF4444",
        "x.svg", "EF4444")
    iconDirectory := A_ScriptDir "\..\..\assets\ui-icons\lucide"
    for fileName, color in expectedColors {
        filePath := iconDirectory "\" fileName
        AssertTrue(FileExist(filePath)
                && InStr(FileRead(filePath, "UTF-8"),
                    'stroke="#' color '"'),
            "Lucide 图标缺少预期语义色：" fileName " -> #" color)
    }
}

painter := RoundedButtonPainter("F1F5F9")
testFailure := ""
try {
    AssertTrue(painter.Ready && painter.Token && painter.ModuleHandle,
        "GDI+ 圆角绘制器初始化失败")
    AssertRoundedMask(painter)
    AssertSvgComposition(painter)
    AssertDualSvgComposition(painter)
    AssertLeadingCommandSymbolGeometry(painter)
    AssertSvgInputBounds()
    AssertTextVisualAlignment()
    AssertSemanticLucideColors()
    WriteTestSuccess("rounded-button-painter")
} catch as painterError {
    testFailure := painterError.Message "`n" painterError.Stack
} finally painter.Shutdown()

AssertEqual(0, painter.Token, "GDI+ 关闭后仍持有令牌")
AssertEqual(0, painter.ModuleHandle, "GDI+ 关闭后仍持有模块引用")
if testFailure != "" {
    FileAppend(testFailure "`n", "**")
    ExitApp(1)
}
ExitApp(0)
