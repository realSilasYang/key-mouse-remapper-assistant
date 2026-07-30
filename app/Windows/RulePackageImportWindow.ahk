class RulePackageImportWindow {
    static WindowWidth := 760
    static WindowHeight := 540

    __New(ownerWindow, filePath, package, collisionPolicy := "rename") {
        this.OwnerWindow := ownerWindow
        this.App := ownerWindow.App
        this.FilePath := String(filePath)
        this.Package := package
        this.CollisionPolicy := String(collisionPolicy)
        this.Preview := this.App.PackageService.Preview(package)
        this.Gui := ""
        this.OwnerLease := ""
        this.IconHandles := []
        this.Interactions := ""
        this.ListSelection := ""
        this.Disposed := false
        try this.Build()
        catch as buildError {
            this.Dispose(false)
            throw buildError
        }
    }

    Build() {
        colors := UiThemeService.GetPalette()
        fontName := LocalizationService.GetUiFontName()
        systemFont := LocalizationService.GetLanguageSystemUiFontName()
        this.Gui := Gui("+Owner" this.OwnerWindow.Gui.Hwnd
            " +OwnDialogs -MinimizeBox -MaximizeBox",
            Tr("导入规则包预览"))
        this.IconHandles := ApplyApplicationWindowIcon(this.Gui.Hwnd)
        this.OwnerLease := WindowHierarchy.Acquire(this.OwnerWindow.Gui,
            this.Gui.Hwnd)
        if !this.OwnerLease
            throw Error("无法建立规则包预览窗口层级。")
        this.Gui.BackColor := colors.Window
        this.Gui.MarginX := 0
        this.Gui.MarginY := 0
        this.Gui.SetFont("norm s10 c" colors.Text, fontName)
        this.Interactions := MappingUiInteractions(this.Gui, colors.Window,
            this.App.SvgRenderer)

        source := this.Preview["source"]
        this.SourceText := this.Gui.Add("Text",
            "x16 y16 w728 h28 0x200 BackgroundTrans c" colors.Text,
            Tr("来源：{1} · 版本：{2}", source["name"],
                this.Preview["version"]))
        this.SummaryText := this.Gui.Add("Text",
            "x16 y48 w728 h42 +Wrap BackgroundTrans c" colors.Muted,
            Tr("共 {1} 条规则，默认选中 {2} 条；权限：{3}",
                this.Preview["total_count"],
                this.Preview["selected_count"],
                this.FormatPermissions(this.Preview["permissions"])))

        this.List := this.Gui.Add("ListView",
            "x16 y122 w728 h286 Report Checked +ReadOnly -Multi -Hdr"
            " +LV0x10000 -Border -E0x200 Background" colors.Surface
            " c" colors.Text, [Tr("规则编号"), Tr("模式"), Tr("权限")])
        this.List.SetFont("s10 c" colors.Text, fontName)
        this.ListSelection := ListViewSelectionPresenter(this.List,
            this.Interactions.Painter)
        this.Interactions.SetFocusSink(this.List)
        this.Header := ListViewPseudoHeader(this.Gui, this.List, [
            {Column: 1, Label: Tr("规则编号"), SortOptions: "Logical"},
            {Column: 2, Label: Tr("模式"), Align: "Center",
                SortOptions: "Logical"},
            {Column: 3, Label: Tr("权限"), SortOptions: "Logical"}
        ], {BackgroundColor: colors.Toolbar, TextColor: colors.Muted,
            FontName: systemFont,
            CursorRegistrar: ObjBindMethod(this.Interactions,
                "RegisterHandCursor")})
        this.ColumnWidths := [270, 110, 348]
        this.Header.SetBounds(16, 94, this.ColumnWidths, 728)
        for item in this.Preview["rules"]
            this.List.Add(item["selected"].Value ? "Check" : "",
                item["id"], item["mode"],
                this.FormatPermissions(item["permissions"]))
        for index, width in this.ColumnWidths
            this.List.ModifyCol(index, width (index == 2 ? " Center" : ""))

        this.SelectAllButton := this.AddButton(16, 430, 112,
            Tr("全选"), colors.Toolbar, ObjBindMethod(this, "SelectAll"),
            colors.ToolbarText)
        this.ClearButton := this.AddButton(138, 430, 112,
            Tr("全部取消"), colors.Toolbar,
            ObjBindMethod(this, "ClearSelection"), colors.ToolbarText)
        this.ImportButton := this.AddButton(500, 430, 112,
            Tr("导入所选"), colors.Primary,
            ObjBindMethod(this, "ImportSelected"))
        this.CancelButton := this.AddButton(622, 430, 112,
            Tr("取消"), colors.Toolbar, ObjBindMethod(this, "RequestClose"),
            colors.ToolbarText)
        this.Interactions.SetButtonLucideIcon(this.SelectAllButton,
            "circle-check-big.svg", 15, 6)
        this.Interactions.SetButtonLucideIcon(this.ClearButton,
            "x.svg", 15, 6)
        this.Interactions.SetButtonLucideIcon(this.ImportButton,
            "file-output.svg", 15, 6)
        this.Interactions.SetButtonLucideIcon(this.CancelButton,
            "x.svg", 15, 6)
        this.Status := this.Gui.Add("Text",
            "x16 y478 w718 h36 +Wrap Background" colors.Window
            " c" colors.Muted, Tr("仅勾选的规则会被导入。"))
        this.Gui.OnEvent("Close", ObjBindMethod(this, "RequestClose"))
        this.Gui.OnEvent("Escape", ObjBindMethod(this, "RequestClose"))
    }

    AddButton(x, y, width, text, color, callback, textColor := "") {
        if textColor == ""
            textColor := UiThemeService.GetPalette().ButtonText
        button := this.Gui.Add("Text", "x" x " y" y " w" width
            " h30 Center 0x200 Background" color " c" textColor, text)
        button.SetFont("s10 bold",
            LocalizationService.GetLanguageSystemUiFontName())
        if !this.Interactions.RegisterButton(button, color, callback,
                "", "", false, textColor)
            button.OnEvent("Click", callback)
        return button
    }

    FormatPermissions(permissions) {
        if !permissions.Length
            return Tr("无额外权限")
        text := ""
        for permission in permissions
            text .= (text == "" ? "" : ", ") permission
        return text
    }

    SelectAll(*) {
        Loop this.List.GetCount()
            this.List.Modify(A_Index, "Check")
    }

    ClearSelection(*) {
        Loop this.List.GetCount()
            this.List.Modify(A_Index, "-Check")
    }

    GetSelectedIds() {
        ids := []
        row := 0
        while row := this.List.GetNext(row, "Checked")
            ids.Push(this.List.GetText(row, 1))
        return ids
    }

    ImportSelected(*) {
        selectedIds := this.GetSelectedIds()
        if !selectedIds.Length {
            this.Status.Opt("c" UiThemeService.GetPalette().Error)
            this.Status.Text := Tr("请至少选择一条规则。")
            return false
        }
        result := this.App.CompleteRulePackageImport(this.FilePath,
            this.Package, this.CollisionPolicy, selectedIds)
        if !IsObject(result) {
            this.Status.Opt("c" UiThemeService.GetPalette().Error)
            this.Status.Text := Tr("导入失败，请查看主窗口状态。")
            return false
        }
        this.Dispose()
        return true
    }

    Show() {
        if this.Disposed
            return false
        ShowPreparedWindow(this.Gui,
            "w" RulePackageImportWindow.WindowWidth
                " h" RulePackageImportWindow.WindowHeight,
            ObjBindMethod(this, "ApplyNativeThemes"))
        return true
    }

    ApplyNativeThemes(*) {
        if this.Disposed
            return false
        ApplyDarkWindow(this.Gui.Hwnd)
        ApplyDarkListView(this.List.Hwnd)
        return true
    }

    Activate() {
        if this.Disposed
            return false
        return ActivatePreparedWindow(this.Gui)
    }

    RequestClose(*) => this.Dispose()

    Dispose(activateOwner := true) {
        if this.Disposed
            return
        this.Disposed := true
        closeContext := ""
        if this.OwnerLease {
            closeContext := WindowHierarchy.Release(this.OwnerLease)
            this.OwnerLease := ""
        }
        if IsObject(this.Interactions)
            try this.Interactions.Dispose()
        if IsObject(this.ListSelection)
            try this.ListSelection.Dispose()
        this.ListSelection := ""
        if this.HasOwnProp("Header") && IsObject(this.Header)
            try this.Header.Dispose()
        this.Header := ""
        if IsObject(this.Gui)
            try this.Gui.Destroy()
        ReleaseApplicationWindowIcons(this.IconHandles)
        this.IconHandles := []
        this.Gui := ""
        this.OwnerWindow.OnRulePackageImportClosed(this)
        if activateOwner
            WindowHierarchy.CompleteClose(closeContext)
    }
}
