; 开源项目打赏窗口。
; 二维码直接读取发行包内的 PNG 资源，不创建临时文件或外部进程；缺少
; 单张资源时仍保留另一种支付方式，并在原位置显示明确的缺失提示。

class DonationWindow {
    __New(ownerWindow) {
        this.OwnerWindow := ownerWindow
        this.App := ownerWindow.App
        this.Gui := ""
        this.OwnerLease := ""
        this.IconHandles := []
        this.MessageText := ""
        this.QrLabels := []
        this.QrPictures := []
        this.QrPictureSpecs := []
        this.MissingQrTexts := []
        this.Disposed := false
        try this.Build()
        catch as buildError {
            try this.Dispose()
            throw buildError
        }
    }

    Build() {
        colors := UiThemeService.GetPalette()
        compactLayout := LocalizationService.UsesCompactLayout()
        this.WindowWidth := compactLayout ? 570 : 680
        contentMargin := compactLayout ? 34 : 38
        this.QrSize := compactLayout ? 180 : 190
        qrGap := compactLayout ? 36 : 52
        firstQrX := (this.WindowWidth - this.QrSize * 2 - qrGap) // 2
        secondQrX := firstQrX + this.QrSize + qrGap

        this.Gui := Gui("+Owner" this.OwnerWindow.Gui.Hwnd
            " +OwnDialogs -MinimizeBox -MaximizeBox",
            Tr("支持开源项目"))
        this.IconHandles := ApplyApplicationWindowIcon(this.Gui.Hwnd)
        this.OwnerLease := WindowHierarchy.Acquire(this.OwnerWindow.Gui,
            this.Gui.Hwnd)
        if !this.OwnerLease
            throw Error("无法建立打赏窗口层级。")
        this.Gui.BackColor := colors.Window
        this.Gui.MarginX := 0
        this.Gui.MarginY := 0
        this.Gui.SetFont("norm s10 c" colors.Text,
            LocalizationService.GetUiFontName())

        this.MessageText := this.Gui.Add("Text", "x" contentMargin
            " y22 w" (this.WindowWidth - contentMargin * 2)
            " Center +0x80 BackgroundTrans c" colors.Text,
            Tr("如果小助手为您节省了配置键鼠映射的时间，欢迎通过下方二维码打赏作者！`n请选择扶贫方式（≥Д≤）"))
        this.MessageText.GetPos(, &messageY, , &messageHeight)
        qrLabelY := messageY + messageHeight + 10

        this.AddQrCode(firstQrX, qrLabelY, Tr("微信支付"),
            "微信个人收款码")
        this.AddQrCode(secondQrX, qrLabelY, Tr("支付宝"),
            "支付宝个人收款码")
        this.WindowHeight := qrLabelY + 24 + this.QrSize + 22

        this.Gui.OnEvent("Close", ObjBindMethod(this, "RequestClose"))
        this.Gui.OnEvent("Escape", ObjBindMethod(this, "RequestClose"))
    }

    AddQrCode(x, y, label, assetStem) {
        colors := UiThemeService.GetPalette()
        imagePath := this.ResolveQrImagePath(assetStem)
        if FileExist(imagePath) {
            picture := this.Gui.Add("Picture", "x" x " y" (y + 24)
                " w" this.QrSize " h" this.QrSize, imagePath)
            this.QrPictures.Push(picture)
            this.QrPictureSpecs.Push({Control: picture,
                AssetStem: assetStem, CurrentPath: imagePath})
        } else {
            missingText := this.Gui.Add("Text", "x" x " y" (y + 24)
                " w" this.QrSize " h" this.QrSize
                " Center 0x200 Background" colors.Surface
                " c" colors.Muted, Tr("二维码图片未找到"))
            this.MissingQrTexts.Push(missingText)
        }
        labelControl := this.Gui.Add("Text", "x" x " y" y
            " w" this.QrSize " h20 Center BackgroundTrans c"
            colors.Muted, label)
        labelControl.SetFont("s10 c" colors.Muted,
            LocalizationService.GetUiFontName())
        this.QrLabels.Push(labelControl)
    }

    ResolveQrImagePath(assetStem) {
        preferredSuffix := UiThemeService.IsDark()
            ? "-界面.png" : "-浅色界面.png"
        fallbackSuffix := UiThemeService.IsDark()
            ? "-浅色界面.png" : "-界面.png"
        preferredPath := GetApplicationAssetPath(
            "donate\" assetStem preferredSuffix)
        if FileExist(preferredPath)
            return preferredPath
        fallbackPath := GetApplicationAssetPath(
            "donate\" assetStem fallbackSuffix)
        return FileExist(fallbackPath) ? fallbackPath : preferredPath
    }

    ApplyQrAppearance() {
        for spec in this.QrPictureSpecs {
            imagePath := this.ResolveQrImagePath(spec.AssetStem)
            if imagePath == spec.CurrentPath || !FileExist(imagePath)
                continue
            spec.Control.Value := imagePath
            spec.CurrentPath := imagePath
        }
        return true
    }

    Show() {
        if this.Disposed
            return false
        return ShowPreparedWindow(this.Gui,
            "w" this.WindowWidth " h" this.WindowHeight,
            ObjBindMethod(this, "ApplyNativeThemes"))
    }

    Activate() {
        if this.Disposed
            return false
        return ActivatePreparedWindow(this.Gui)
    }

    ApplyNativeThemes(*) {
        if this.Disposed
            return false
        return ApplyDarkWindow(this.Gui.Hwnd)
    }

    ApplyAppearance() {
        if this.Disposed
            return false
        BeginStableWindowUpdate(this.Gui.Hwnd)
        try {
            colors := UiThemeService.GetPalette()
            fontName := LocalizationService.GetUiFontName()
            this.Gui.Title := Tr("支持开源项目")
            this.Gui.BackColor := colors.Window
            this.MessageText.Text := Tr("如果小助手为您节省了配置键鼠映射的时间，欢迎通过下方二维码打赏作者！`n请选择扶贫方式（≥Д≤）")
            this.MessageText.SetFont("norm s10 c" colors.Text, fontName)
            this.ApplyQrAppearance()
            labels := [Tr("微信支付"), Tr("支付宝")]
            for index, labelControl in this.QrLabels {
                labelControl.Text := labels[index]
                labelControl.SetFont("s10 c" colors.Muted, fontName)
            }
            for missingText in this.MissingQrTexts {
                missingText.Text := Tr("二维码图片未找到")
                missingText.Opt("Background" colors.Surface)
                missingText.SetFont("s10 c" colors.Muted, fontName)
            }
            this.ApplyNativeThemes()
        } finally EndStableWindowUpdate(this.Gui.Hwnd, true)
        return true
    }

    RequestClose(*) => this.Dispose()

    Dispose(activateOwner := true) {
        if this.Disposed
            return
        this.Disposed := true
        cleanup := CleanupCollector("打赏窗口")
        closeContext := ""
        if this.OwnerLease {
            try {
                closeContext := WindowHierarchy.Release(this.OwnerLease)
                this.OwnerLease := ""
            } catch as ownerError {
                cleanup.Failures.Push("释放父窗口关系：" ownerError.Message)
            }
        }
        if IsObject(this.Gui)
                && cleanup.Run("销毁窗口", () => this.Gui.Destroy())
            this.Gui := ""
        if cleanup.Run("释放窗口图标",
                () => ReleaseApplicationWindowIcons(this.IconHandles))
            this.IconHandles := []
        this.MessageText := ""
        this.QrLabels := []
        this.QrPictures := []
        this.QrPictureSpecs := []
        this.MissingQrTexts := []
        cleanup.Run("通知父窗口",
            () => this.OwnerWindow.OnDonationClosed(this))
        if activateOwner
            cleanup.Run("恢复父窗口", () =>
                WindowHierarchy.CompleteClose(closeContext))
        cleanup.Complete()
        return true
    }
}
