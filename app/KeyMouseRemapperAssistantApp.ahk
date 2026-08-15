class KeyMouseRemapperAssistantApp {
    __New() {
        this.UpdateService := ""
        this.Capture := ""
        this.RawInput := ""
        this.Runtime := ""
        this.Window := ""
        this.SvgRenderer := ""
        this.LocalizationConfigured := false
        try {
        this.DataDirectory := A_AppData "\KeyMouseRemapperAssistant"
        this.RuntimeStatePath := this.DataDirectory "\runtime.ini"
        this.SettingsService := AppSettingsService(this.DataDirectory
            "\settings.ini")
        this.Settings := this.SettingsService.Load()
        this.RuleAppearanceService := RuleAppearanceService(
            this.DataDirectory "\rule-appearance.json")
        try this.RuleColors := this.RuleAppearanceService.Load()
        catch
            this.RuleColors := Map()
        this.AIService := AIService()
        LocalizationService.Configure(this.Settings.UiLanguage,
            this.Settings.UiFont)
        this.LocalizationConfigured := true
        UiThemeService.Configure(this.Settings.Theme)
        MappingWindow.Colors := UiThemeService.GetPalette()
        this.SystemIntegration := SystemIntegrationService(
            Tr("键鼠重映射小助手"))
        if HasCommandLineFlag("--elevation-handoff")
            try this.SystemIntegration.SynchronizeStartupTaskElevation(
                this.Settings.RunAsAdministrator)
        ; 只补写严格匹配当前入口的既有快捷方式身份，保留专属 Logo，
        ; 避免 Windows 把它持久关联到公共 AutoHotkey64.exe。
        try this.SystemIntegration.RepairApplicationShortcutIdentities()

        this.Repository := MappingCodeRepository(A_ScriptFullPath)
        this.MappingHistory := MappingHistoryService(20)
        this.PackageService := RulePackageService()
        this.Trace := EventTraceService(this.Settings.EventBufferCapacity)
        this.ContextService := DirectContextService()
        this.SvgRenderer := SvgRenderLibrary(GetApplicationRootFilePath(
            "third_party\resvg\resvg.dll"))
        this.Runtime := CompositeRemappingRuntime(this)
        this.Window := MappingWindow(this)
        this.WindowLayoutService := WindowLayoutService(this.DataDirectory
            "\window-layout.ini", MappingWindow.DefaultClientWidth,
            MappingWindow.DefaultClientHeight,
            this.Window.MinClientWidth, MappingWindow.BaseMinClientHeight)
        this.WindowLayout := this.WindowLayoutService.Load()
        this.Window.SetInitialClientSize(this.WindowLayout.Width,
            this.WindowLayout.Height)
        this.RawInput := RawInputService(this.Window.Gui.Hwnd,
            ObjBindMethod(this, "OnRawInputEvent"))
        this.Capture := KeyCaptureSession(this)

        this.MappingCount := 0
        this.RuntimeReport := ""
        this.PendingScriptApply := ""
        this.PendingScriptApplyTimer := ObjBindMethod(this,
            "ApplyPendingScriptMappings")
        this.ElevationRestartTimer := ObjBindMethod(this,
            "RestartWithConfiguredElevation")
        this.RawObservationDepth := 0
        this.ShuttingDown := false
        this.CallbacksRegistered := false
        this.MainWindowRegistered := false
        this.SessionNotificationsRegistered := false
        this.EventViewer := ""
        this.SupportInfo := ""
        this.Help := ""
        this.Donation := ""
        this.About := ""
        this.SettingsWindow := ""
        this.PackageImportPreview := ""
        packagedEdition := HasCommandLineFlag("--packaged")
        updateEntryPath := packagedEdition
            ? GetApplicationRootFilePath("键鼠重映射小助手.exe")
            : A_ScriptFullPath
        this.UpdateService := ApplicationUpdateService({
            Repository: "realSilasYang/key-mouse-remapper-assistant",
            CurrentVersion: ReadApplicationVersion(),
            HelperPath: GetApplicationRootFilePath(
                "runtime\application-update.ps1"),
            HelperLocalizationPath: GetApplicationRootFilePath(
                "runtime\application-update.strings.json"),
            InstallRoot: A_ScriptDir,
            EntryPath: updateEntryPath,
            EditableSourcePath: A_IsCompiled ? "" : A_ScriptFullPath,
            InterpreterPath: A_AhkPath,
            Compiled: A_IsCompiled || packagedEdition,
            UiLanguage: LocalizationService.GetLanguage(),
            Log: ObjBindMethod(this, "LogUpdateServiceMessage"),
            Localize: Tr,
            OnResult: ObjBindMethod(this, "HandleUpdateCheckResult"),
            Now: () => DllCall("kernel32\GetTickCount64", "UInt64"),
            Quote: QuoteRuntimeCommandArgument
        })
        this.AppCommandCallback := ObjBindMethod(this, "OnAppCommand")
        this.SystemCommandCallback := ObjBindMethod(this, "OnSystemCommand")
        this.SettingChangeCallback := ObjBindMethod(this,
            "OnSystemSettingChange")
        this.PowerBroadcastCallback := ObjBindMethod(this,
            "OnPowerBroadcast")
        this.SessionChangeCallback := ObjBindMethod(this,
            "OnSessionChange")
        this.ShowApplicationMessage := GetApplicationShowMessage()
        this.ShowApplicationCallback := ObjBindMethod(this,
            "OnShowApplicationRequest")
        this.ExitCallback := ObjBindMethod(this, "HandleExit")
        this.StartupUpdateTimer := ObjBindMethod(this,
            "BeginApplicationUpdateCheck")
        this.ExternalTakeoverTimer := ObjBindMethod(this,
            "ExitForExternalLaunch")
        this.SourceRevision := ReadApplicationSourceRevision()
        } catch as constructionError {
            cleanupFailures := this.CleanupConstructionResources()
            if cleanupFailures.Length
                throw Error(constructionError.Message
                    . "；初始化回滚失败："
                    . this.JoinMessages(cleanupFailures), -1,
                    constructionError)
            throw constructionError
        }
    }

    CleanupConstructionResources() {
        failures := []
        if IsObject(this.UpdateService)
            this.RunConstructionCleanup(failures, "更新服务",
                () => this.UpdateService.Shutdown())
        if IsObject(this.Capture)
            this.RunConstructionCleanup(failures, "录制会话",
                () => this.Capture.Stop(false, false))
        if IsObject(this.RawInput)
            this.RunConstructionCleanup(failures, "Raw Input",
                () => this.RawInput.Shutdown())
        if IsObject(this.Runtime)
            this.RunConstructionCleanup(failures, "热键运行时",
                () => this.Runtime.Shutdown())
        if IsObject(this.Window)
            this.RunConstructionCleanup(failures, "主窗口",
                () => this.Window.Dispose())
        if IsObject(this.SvgRenderer)
            this.RunConstructionCleanup(failures, "SVG 渲染器",
                () => this.SvgRenderer.Shutdown())
        if this.LocalizationConfigured {
            if this.RunConstructionCleanup(failures, "本地化字体",
                    () => LocalizationService.ShutdownUiFonts())
                this.LocalizationConfigured := false
        }
        return failures
    }

    RunConstructionCleanup(failures, label, callback) {
        try {
            callback.Call()
            return true
        } catch as cleanupError {
            failures.Push(label "：" cleanupError.Message)
            return false
        }
    }

    Start() {
        global LaunchShowMain
        reloadMarkerPresent := this.ReadShowAfterReloadMarker()
        reloadMarkerConsumed := !reloadMarkerPresent
            || this.ConsumeShowAfterReloadMarker()
        showAfterReload := LaunchShowMain || HasCommandLineFlag("--show-main")
            || reloadMarkerPresent
        this.RegisterCallbacks()
        this.RegisterSessionNotifications()
        this.ConfigureTray()
        recordingError := ""
        loadError := ""
        runtimeError := ""
        try this.RawInput.Start()
        catch as rawError
            recordingError := rawError.Message
        mappings := []
        try mappings := this.Repository.Load()
        catch as repositoryError
            loadError := repositoryError.Message
        this.MappingCount := mappings.Length
        if loadError == "" {
            try this.RuntimeReport := this.Runtime.ApplyMappings(mappings)
            catch as applyError
                runtimeError := applyError.Message
        }
        this.Window.LoadRows(mappings)
        fatalError := loadError != "" ? loadError : runtimeError
        settingsWarning := this.GetSettingsLoadWarningText()
        detail := fatalError != "" ? fatalError
            : (settingsWarning != "" ? settingsWarning : recordingError)
        this.TraceEvent("system", "startup", {Outcome: fatalError == ""
            ? "ok" : "error", Detail: detail,
            Data: Map("rules", this.MappingCount)})
        if settingsWarning != ""
            this.TraceEvent("system", "settings_load_warning", {
                Outcome: "warning", Detail: settingsWarning})
        if reloadMarkerPresent && !reloadMarkerConsumed
            this.TraceEvent("system", "reload_marker_cleanup_failed", {
                Outcome: "error",
                Detail: "ShowAfterReload remained set after startup."})
        if loadError != ""
            this.Window.SetStatus(Tr("读取重映射代码区域失败：{1}",
                loadError), true)
        else if runtimeError != ""
            this.Window.SetStatus(Tr("规则未应用：{1}",
                runtimeError), true)
        else if settingsWarning != ""
            this.Window.SetStatus(settingsWarning, true)
        else if recordingError != ""
            this.Window.SetStatus(this.GetSummaryText() " · "
                Tr("输入录制不可用：{1}", recordingError), true)
        else
            this.Window.SetStatus(this.GetSummaryText())
        if showAfterReload
            this.ShowMainWindowAfterReload()
        else
            this.Window.ShowWithOptions(this.Settings.ShowAtStartup
                ? "" : "Hide")
        if !RegisterApplicationMainWindow(this.Window.Gui.Hwnd) {
            this.Shutdown()
            throw Error("无法注册主窗口单实例唤醒入口。")
        }
        this.MainWindowRegistered := true
        if this.Settings.CheckUpdatesOnStartup
            SetTimer(this.StartupUpdateTimer, -1500)
        return fatalError == ""
    }

    ConfigureTray() {
        A_TrayMenu.Delete()
        A_TrayMenu.Add(Tr("显示主界面"), ObjBindMethod(this.Window, "Activate"))
        A_TrayMenu.Add(Tr("重新加载"), ObjBindMethod(this, "ReloadFromTray"))
        A_TrayMenu.Add(Tr("退出程序"), (*) => ExitApp())
        A_TrayMenu.Default := Tr("显示主界面")
        A_TrayMenu.ClickCount := 1
        A_IconHidden := true
        Sleep(50)
        A_IconHidden := false
        A_IconTip := Tr("键鼠重映射小助手")
        iconPath := GetApplicationIconPath()
        if FileExist(iconPath)
            TraySetIcon(iconPath)
        return true
    }

    NormalizeSignature(displayName) {
        normalized := StrLower(RegExReplace(String(displayName), "\s+"))
        normalized := RegExReplace(normalized, "（[^）]*）|\([^)]*\)")
        ; 左右修饰键具有不同的物理扫描码，冲突检测也必须保留侧别。
        normalized := StrReplace(normalized, "左侧", "l")
        normalized := StrReplace(normalized, "右侧", "r")
        normalized := StrReplace(normalized, "左", "l")
        normalized := StrReplace(normalized, "右", "r")
        normalized := StrReplace(normalized, "lcontrol", "lctrl")
        normalized := StrReplace(normalized, "rcontrol", "rctrl")
        if normalized == "control"
            normalized := "ctrl"
        return normalized
    }

    AddMapping(sourceCapture, targetCapture, name,
            distinguishModifierSides := true) {
        if this.NormalizeSignature(sourceCapture.Display) == "lbutton" {
            this.Window.SetStatus(Tr(
                "为避免失去界面操作，来源按键不能是无修饰的鼠标左键。"), true)
            return false
        }
        try {
            callback := ObjBindMethod(this, "AppendCapturedMapping",
                sourceCapture, targetCapture, name,
                distinguishModifierSides)
            mapping := this.RunMappingMutation(callback, {Kind: "add"})
            this.Window.AddMappingRow(mapping, this.MappingCount)
            this.Window.SetStatus(Tr(
                "已写入脚本：{1} -> {2}；已应用。",
                mapping.Source, mapping.Target))
            return mapping
        } catch as addError {
            this.Window.SetStatus(Tr("映射未写入脚本：{1}",
                addError.Message), true)
            return false
        }
    }

    AppendCapturedMapping(sourceCapture, targetCapture, name,
            distinguishModifierSides := true) {
        mappings := this.Repository.Load()
        name := RuleSpec.NormalizeId(name)
        spec := RuleSpec.CreateFromCaptures(name, sourceCapture,
            targetCapture, distinguishModifierSides)
        return this.Repository.AppendManagedSpec(spec)
    }

    DeleteMapping(mappingId) {
        try {
            mapping := this.RunMappingMutation(
                ObjBindMethod(this.Repository, "Remove", mappingId),
                {Kind: "delete", Id: mappingId})
            this.ForgetRuleColors([mapping.Id])
            this.Window.RemoveMappingRow(mapping.Id)
            this.Window.SetStatus(Tr(
                "已从脚本删除：{1} -> {2}；已应用。",
                mapping.Source, mapping.Target))
            return true
        } catch as deleteError {
            this.Window.SetStatus(Tr("映射未删除：{1}",
                deleteError.Message), true)
            return false
        }
    }

    DeleteMappings(mappingIds) {
        try {
            removedMappings := this.RunMappingMutation(
                ObjBindMethod(this.Repository, "RemoveMany", mappingIds),
                {Kind: "delete-many", Id: mappingIds[1],
                    Ids: mappingIds.Clone()})
            removedIds := []
            for mapping in removedMappings
                removedIds.Push(mapping.Id)
            this.ForgetRuleColors(removedIds)
            for mapping in removedMappings
                this.Window.RemoveMappingRow(mapping.Id)
            this.Window.SetStatus(this.GetSummaryText())
            return removedMappings
        } catch as deleteError {
            this.Window.SetStatus(Tr("映射未删除：{1}",
                deleteError.Message), true)
            return false
        }
    }

    MoveMappingTo(mappingId, targetIndex) {
        try {
            moved := this.RunMappingMutation(
                ObjBindMethod(this.Repository, "MoveTo", mappingId,
                    targetIndex), {Kind: "reorder", Id: mappingId})
            if moved {
                this.RefreshMappingRows(mappingId)
                this.Window.SetStatus(Tr("已按拖动结果实时更新脚本顺序。"))
            } else {
                this.Window.SetStatus(Tr("映射顺序没有变化。"))
            }
            return moved
        } catch as moveError {
            this.Window.SetStatus(Tr("顺序未保存：{1}",
                moveError.Message), true)
            return false
        }
    }

    MoveMappingsTo(mappingIds, targetIndex) {
        try {
            moved := this.RunMappingMutation(
                ObjBindMethod(this.Repository, "MoveManyTo", mappingIds,
                    targetIndex), {Kind: "reorder-many", Id: mappingIds[1],
                    Ids: mappingIds.Clone()})
            if moved {
                this.RefreshMappingRows(mappingIds)
                this.Window.SetStatus(Tr(
                    "已按拖动结果实时更新脚本顺序。"))
            } else {
                this.Window.SetStatus(Tr("映射顺序没有变化。"))
            }
            return moved
        } catch as moveError {
            this.Window.SetStatus(Tr("顺序未保存：{1}",
                moveError.Message), true)
            return false
        }
    }

    GetRuleColor(mappingId) {
        mappingId := String(mappingId)
        return Type(this.RuleColors) == "Map"
                && this.RuleColors.Has(mappingId)
            ? RuleColorPalette.NormalizeKey(this.RuleColors[mappingId]) : ""
    }

    GetCommonRuleColor(mappingIds) {
        mappingIds := this.NormalizeRuleColorMappingIds(mappingIds)
        if !mappingIds.Length
            return ""
        commonKey := this.GetRuleColor(mappingIds[1])
        for index, mappingId in mappingIds {
            if index > 1 && this.GetRuleColor(mappingId) != commonKey
                return ""
        }
        return commonKey
    }

    SetRuleColors(mappingIds, presetKey) {
        mappingIds := this.NormalizeRuleColorMappingIds(mappingIds)
        if !mappingIds.Length
            return false
        requestedKey := StrLower(Trim(String(presetKey)))
        presetKey := RuleColorPalette.NormalizeKey(requestedKey)
        if requestedKey != "" && presetKey == ""
            return false
        candidate := this.RuleColors.Clone()
        changed := false
        for mappingId in mappingIds {
            currentKey := candidate.Has(mappingId)
                ? RuleColorPalette.NormalizeKey(candidate[mappingId]) : ""
            if currentKey == presetKey
                continue
            changed := true
            if presetKey == "" {
                if candidate.Has(mappingId)
                    candidate.Delete(mappingId)
            } else
                candidate[mappingId] := presetKey
        }
        if changed {
            try this.RuleColors := this.RuleAppearanceService.Save(candidate)
            catch as saveError {
                this.Window.SetStatus(Tr("序号圆点颜色未保存：{1}",
                    saveError.Message), true)
                return false
            }
            this.Window.RefreshMappingColors(mappingIds)
        }
        this.Window.SetStatus(Tr("已更新 {1} 条规则的序号圆点颜色。",
            mappingIds.Length))
        return true
    }

    NormalizeRuleColorMappingIds(mappingIds) {
        if Type(mappingIds) != "Array"
            mappingIds := [mappingIds]
        result := []
        seen := Map()
        for mappingId in mappingIds {
            mappingId := Trim(String(mappingId))
            if mappingId == "" || seen.Has(mappingId)
                continue
            seen[mappingId] := true
            result.Push(mappingId)
        }
        return result
    }

    MigrateRuleColor(previousId, mappingId) {
        previousId := String(previousId)
        mappingId := String(mappingId)
        if previousId == mappingId || !this.RuleColors.Has(previousId)
            return false
        candidate := this.RuleColors.Clone()
        if !candidate.Has(mappingId)
            candidate[mappingId] := candidate[previousId]
        candidate.Delete(previousId)
        try {
            this.RuleColors := this.RuleAppearanceService.Save(candidate)
            return true
        } catch {
            return false
        }
    }

    ForgetRuleColors(mappingIds) {
        mappingIds := this.NormalizeRuleColorMappingIds(mappingIds)
        candidate := this.RuleColors.Clone()
        changed := false
        for mappingId in mappingIds {
            if candidate.Has(mappingId) {
                candidate.Delete(mappingId)
                changed := true
            }
        }
        if !changed
            return true
        try {
            this.RuleColors := this.RuleAppearanceService.Save(candidate)
            return true
        } catch {
            return false
        }
    }

    ToggleMappingEnabled(mappingId) {
        try {
            mapping := this.RunMappingMutation(
                ObjBindMethod(this.Repository, "ToggleEnabled", mappingId),
                {Kind: "toggle", Id: mappingId})
            this.Window.UpdateMappingRow(mapping)
            this.Window.SetStatus(mapping.Enabled
                ? Tr("已恢复映射：{1} -> {2}；已应用。",
                    mapping.Source, mapping.Target)
                : Tr("已暂停映射：{1} -> {2}；已应用。",
                    mapping.Source, mapping.Target))
            return mapping
        } catch as toggleError {
            this.Window.SetStatus(Tr("映射状态未修改：{1}",
                toggleError.Message), true)
            return false
        }
    }

    ToggleMappingsEnabled(mappingIds) {
        try {
            toggledMappings := this.RunMappingMutation(
                ObjBindMethod(this.Repository, "ToggleEnabledMany",
                    mappingIds),
                {Kind: "toggle-many", Id: mappingIds[1],
                    Ids: mappingIds.Clone()})
            for mapping in toggledMappings
                this.Window.UpdateMappingRow(mapping)
            this.Window.SetStatus(this.GetSummaryText())
            return toggledMappings
        } catch as toggleError {
            this.Window.SetStatus(Tr("映射状态未修改：{1}",
                toggleError.Message), true)
            return false
        }
    }

    UpdateMappingBlock(mappingId, blockText) {
        return this.UpdateMappingEditorText(mappingId, blockText, "managed")
    }

    UpdateMappingEditorText(mappingId, editorText, mode := "managed") {
        try {
            deferredScriptApply := StrLower(Trim(String(mode))) == "script"
            if deferredScriptApply {
                mutation := this.RunDeferredMappingMutation(
                    ObjBindMethod(this.Repository, "ReplaceEditorText",
                        mappingId, editorText, mode),
                    {Kind: "edit", Id: mappingId})
                mapping := mutation.Result
            } else {
                mapping := this.RunMappingMutation(
                    ObjBindMethod(this.Repository, "ReplaceEditorText",
                        mappingId, editorText, mode),
                    {Kind: "edit", Id: mappingId})
            }
            ; @名称也是规则标识。编辑后名称可能变化，此时列表里仍保存旧标识，
            ; 必须用旧标识定位原行，再将整行替换为写回后的最新数据。
            this.MigrateRuleColor(mappingId, mapping.Id)
            if !this.Window.UpdateMappingRow(mapping, mappingId)
                this.RefreshMappingRows(mapping.Id)
            if deferredScriptApply {
                if mutation.Changed {
                    progressText := Tr("已保存，正在后台应用…")
                    this.Window.SetStatus(progressText)
                    this.QueueDeferredScriptApply(mutation.Mappings,
                        mutation.Body, mapping.Id, progressText,
                        this.Window.GetStatusRevision())
                } else {
                    this.Window.SetStatus(Tr("映射代码没有变化。"))
                }
            } else {
                this.Window.SetStatus(Tr(
                    "已保存映射代码：{1} -> {2}；已应用。",
                    mapping.Source, mapping.Target))
            }
            return {Ok: true, Mapping: mapping,
                DeferredApply: deferredScriptApply && mutation.Changed}
        } catch as updateError {
            this.Window.SetStatus(Tr("映射代码未保存：{1}",
                updateError.Message), true)
            return {Ok: false, Message: updateError.Message}
        }
    }

    AddMappingBlock(blockText) {
        return this.AddMappingEditorText(blockText, "managed")
    }

    AddMappingEditorText(editorText, mode := "managed") {
        try {
            mapping := this.RunMappingMutation(
                ObjBindMethod(this.Repository, "AppendEditorText", editorText,
                    mode),
                {Kind: "add"})
            this.Window.AddMappingRow(mapping, this.MappingCount)
            this.Window.SetStatus(Tr(
                "已新增映射代码：{1} -> {2}；已应用。",
                mapping.Source, mapping.Target))
            return {Ok: true, Mapping: mapping}
        } catch as addError {
            this.Window.SetStatus(Tr("映射代码未新增：{1}",
                addError.Message), true)
            return {Ok: false, Message: addError.Message}
        }
    }

    RunMappingMutation(callback, historyAction := "") {
        mutationLease := CrossProcessWriteLock.Acquire(
            this.Repository.ScriptPath)
        try {
            before := this.Repository.ReadRegionBody()
            writtenBody := ""
            writtenBodyKnown := false
            this.Repository.ResetLastWriteResult()
            try {
                result := callback.Call()
                writeResult := this.Repository.TakeLastWriteResult()
                writtenBody := IsObject(writeResult)
                    ? writeResult.Body : this.Repository.ReadRegionBody()
                writtenBodyKnown := true
                if writtenBody == before
                    return result
                this.ApplyMappingsHot(IsObject(writeResult)
                    ? writeResult.Mappings : "")
                if IsObject(historyAction)
                        && (!historyAction.HasOwnProp("Id")
                            || historyAction.Id == "")
                        && IsObject(result) && result.HasOwnProp("Id")
                    historyAction.Id := result.Id
                this.MappingHistory.Commit(before, writtenBody, historyAction)
                this.TraceEvent("repository", "rules_changed",
                    {Outcome: "ok"})
                return result
            } catch as mutationError {
                rollbackError := ""
                try {
                    ; 空正文是“删除最后一条规则”后的合法状态，不能用它表示尚未
                    ; 读取写后快照。回调本身抛错时也重新读取，覆盖“已替换文件但
                    ; 返回前失败”的事务边界。
                    if !writtenBodyKnown
                        writtenBody := this.Repository.ReadRegionBody()
                    if writtenBody != before {
                        this.Repository.ResetLastWriteResult()
                        this.Repository.WriteRegionBody(before, writtenBody)
                        rollbackWrite := this.Repository.TakeLastWriteResult()
                        this.ApplyMappingsHot(IsObject(rollbackWrite)
                            ? rollbackWrite.Mappings : "")
                    }
                } catch as caughtRollbackError
                    rollbackError := caughtRollbackError
                if IsObject(rollbackError)
                    throw Error(mutationError.Message "；回滚失败："
                        rollbackError.Message, -1, mutationError)
                throw mutationError
            }
        } finally {
            mutationLease.Release()
        }
    }

    RunDeferredMappingMutation(callback, historyAction := "") {
        mutationLease := CrossProcessWriteLock.Acquire(
            this.Repository.ScriptPath)
        try {
            before := this.Repository.ReadRegionBody()
            this.Repository.ResetLastWriteResult()
            result := callback.Call()
            writeResult := this.Repository.TakeLastWriteResult()
            writtenBody := IsObject(writeResult)
                ? writeResult.Body : this.Repository.ReadRegionBody()
            changed := writtenBody != before
            mappings := IsObject(writeResult)
                ? writeResult.Mappings : this.Repository.Load()
            if changed {
                if IsObject(historyAction)
                        && (!historyAction.HasOwnProp("Id")
                            || historyAction.Id == "")
                        && IsObject(result) && result.HasOwnProp("Id")
                    historyAction.Id := result.Id
                this.MappingHistory.Commit(before, writtenBody,
                    historyAction)
                this.TraceEvent("repository", "rules_changed",
                    {Outcome: "pending"})
            }
            this.MappingCount := mappings.Length
            return {Result: result, Changed: changed, Body: writtenBody,
                Mappings: mappings}
        } finally mutationLease.Release()
    }

    QueueDeferredScriptApply(mappings, body, mappingId, progressText,
            statusRevision) {
        this.PendingScriptApply := {Mappings: mappings, Body: String(body),
            MappingId: String(mappingId), ProgressText: String(progressText),
            StatusRevision: Integer(statusRevision)}
        ; 编辑器会在销毁并释放父窗口后把它提前到 50ms。这个较晚的兜底
        ; 负责非编辑器调用，避免已持久化的脚本长期不进入运行时。
        SetTimer(this.PendingScriptApplyTimer, -500)
        return true
    }

    StartPendingScriptApply(*) {
        if this.ShuttingDown || !IsObject(this.PendingScriptApply)
            return false
        SetTimer(this.PendingScriptApplyTimer, -50)
        return true
    }

    ApplyPendingScriptMappings(*) {
        if this.ShuttingDown || !IsObject(this.PendingScriptApply)
            return false
        pending := this.PendingScriptApply
        this.PendingScriptApply := ""
        try {
            currentBody := this.Repository.ReadRegionBody()
            mappings := currentBody == pending.Body
                ? pending.Mappings : this.Repository.Load()
            this.ApplyMappingsHot(mappings)
            if this.Window.IsCurrentStatus(pending.ProgressText, false,
                    pending.StatusRevision)
                this.Window.SetStatus(Tr("受托管脚本已应用。"))
            this.TraceEvent("repository", "deferred_script_apply",
                {Outcome: "ok", RuleId: pending.MappingId})
            return true
        } catch as applyError {
            this.Window.SetStatus(Tr(
                "映射代码已保存，但受托管脚本应用失败：{1}",
                applyError.Message), true)
            this.TraceEvent("repository", "deferred_script_apply",
                {Outcome: "error", RuleId: pending.MappingId,
                    Detail: applyError.Message})
            return false
        }
    }

    ApplyMappingsHot(mappings := "") {
        if this.HasOwnProp("PendingScriptApply")
                && IsObject(this.PendingScriptApply) {
            if this.HasOwnProp("PendingScriptApplyTimer")
                    && IsObject(this.PendingScriptApplyTimer)
                SetTimer(this.PendingScriptApplyTimer, 0)
            this.PendingScriptApply := ""
        }
        if Type(mappings) != "Array"
            mappings := this.Repository.Load()
        report := this.Runtime.ApplyMappings(mappings)
        this.MappingCount := mappings.Length
        this.RuntimeReport := report
        return report
    }

    RefreshMappingRows(preferredId := "") {
        mappings := this.Repository.Load()
        this.MappingCount := mappings.Length
        return this.Window.ReplaceRows(mappings, preferredId)
    }

    UndoMappingChange(*) {
        if !this.MappingHistory.CanUndo() {
            this.Window.SetStatus(Tr("没有可撤销的映射变更。"))
            return false
        }
        try {
            if !this.MappingHistory.Undo(
                    ObjBindMethod(this, "ApplyMappingHistoryState"), &entry)
                return false
            this.RefreshMappingRows(this.GetHistoryMappingId(entry))
            this.Window.SetStatus(Tr("已撤销上一步映射变更。"))
            this.TraceEvent("repository", "history_undo", {Outcome: "ok"})
            return true
        } catch as undoError {
            this.Window.SetStatus(Tr("撤销映射变更失败：{1}",
                undoError.Message), true)
            this.TraceEvent("repository", "history_undo", {Outcome: "error",
                Detail: undoError.Message})
            return false
        }
    }

    RedoMappingChange(*) {
        if !this.MappingHistory.CanRedo() {
            this.Window.SetStatus(Tr("没有可重做的映射变更。"))
            return false
        }
        try {
            if !this.MappingHistory.Redo(
                    ObjBindMethod(this, "ApplyMappingHistoryState"), &entry)
                return false
            this.RefreshMappingRows(this.GetHistoryMappingId(entry))
            this.Window.SetStatus(Tr("已重做映射变更。"))
            this.TraceEvent("repository", "history_redo", {Outcome: "ok"})
            return true
        } catch as redoError {
            this.Window.SetStatus(Tr("重做映射变更失败：{1}",
                redoError.Message), true)
            this.TraceEvent("repository", "history_redo", {Outcome: "error",
                Detail: redoError.Message})
            return false
        }
    }

    ApplyMappingHistoryState(targetBody, sourceBody) {
        mutationLease := CrossProcessWriteLock.Acquire(
            this.Repository.ScriptPath)
        try {
            this.Repository.WriteRegionBody(targetBody, sourceBody)
            try {
                this.ApplyMappingsHot()
            } catch as applyError {
                rollbackError := ""
                try {
                    this.Repository.WriteRegionBody(sourceBody, targetBody)
                    this.ApplyMappingsHot()
                } catch as caughtRollbackError
                    rollbackError := caughtRollbackError
                if IsObject(rollbackError)
                    throw Error(applyError.Message "；回滚失败："
                        rollbackError.Message, -1, applyError)
                throw applyError
            }
        } finally mutationLease.Release()
        return true
    }

    GetHistoryMappingId(entry) {
        if !IsObject(entry) || !entry.HasOwnProp("Action")
                || !IsObject(entry.Action)
                || !entry.Action.HasOwnProp("Id")
            return ""
        return String(entry.Action.Id)
    }

    ChooseExportRulePackage(*) {
        suggested := A_Desktop "\key-mouse-remapper-assistant-rules-"
            . FormatTime(, "yyyyMMdd-HHmmss") ".json"
        filePath := FileSelect("S16", suggested, Tr("导出规则包"),
            "Rule package (*.json)")
        return filePath == "" ? false : this.ExportRulePackageTo(filePath)
    }

    ExportRulePackageTo(filePath) {
        try result := this.PackageService.ExportTo(filePath,
            this.Repository.Load())
        catch as exportError {
            this.Window.SetStatus(Tr("规则包导出失败：{1}",
                exportError.Message), true)
            return false
        }
        this.Window.SetStatus(Tr("已导出 {1} 条规则：{2}",
            result.Rules, result.Path))
        return result
    }

    ChooseImportRulePackage(ownerWindow := "", *) {
        filePath := FileSelect("1", "", Tr("导入规则包"),
            "Rule package (*.json)")
        return filePath == "" ? false
            : this.ImportRulePackageFrom(filePath, "rename", ownerWindow)
    }

    ImportRulePackageFrom(filePath, collisionPolicy := "rename",
            ownerWindow := "") {
        try package := this.PackageService.Read(filePath)
        catch as packageError {
            this.Window.SetStatus(Tr("规则包导入失败：{1}",
                packageError.Message), true)
            return false
        }
        if IsObject(this.PackageImportPreview) {
            try this.PackageImportPreview.Dispose(false)
            catch as closeError {
                this.Window.SetStatus(Tr("规则包导入失败：{1}",
                    closeError.Message), true)
                return false
            }
            this.PackageImportPreview := ""
        }
        owner := IsObject(ownerWindow) ? ownerWindow : this.Window
        candidate := ""
        try {
            candidate := RulePackageImportWindow(owner,
                filePath, package, collisionPolicy)
            this.PackageImportPreview := candidate
            candidate.Show()
            return true
        } catch as previewError {
            if IsObject(candidate)
                try candidate.Dispose(false)
            if IsObject(this.PackageImportPreview)
                    && this.PackageImportPreview == candidate
                this.PackageImportPreview := ""
            this.Window.SetStatus(Tr("规则包导入失败：{1}",
                previewError.Message), true)
            return false
        }
    }

    CompleteRulePackageImport(filePath, package, collisionPolicy,
            selectedRuleIds) {
        try {
            result := this.RunMappingMutation(() => this.PackageService
                .ImportPackage(package, this.Repository, collisionPolicy,
                    selectedRuleIds), {Kind: "import"})
            this.RefreshMappingRows()
            this.Window.SetStatus(Tr(
                "规则包导入完成：新增 {1}，替换 {2}，重命名 {3}，跳过 {4}。",
                result.Imported, result.Replaced, result.Renamed,
                result.Skipped + result.SelectionSkipped))
            return result
        } catch as importError {
            this.Window.SetStatus(Tr("规则包导入失败：{1}",
                importError.Message), true)
            return false
        }
    }

    OnRulePackageImportClosed(previewWindow) {
        if IsObject(this.PackageImportPreview)
                && this.PackageImportPreview == previewWindow
            this.PackageImportPreview := ""
    }

    TraceEvent(category, eventName, fields := "") {
        try return this.Trace.Record(category, eventName, fields)
        catch
            return false
    }

    OnRawInputEvent(unifiedEvent) {
        ; Recording owns Raw Input dispatch as soon as its guard starts and
        ; through the final release drain. The runtime must never observe the
        ; same event first, even at suspend/resume boundaries.
        this.Capture.DispatchRawInputEvent(unifiedEvent, this.Runtime)
        if !RawInputObservationPolicy.ShouldForwardToGui(unifiedEvent,
                this.RawObservationDepth > 0)
            return false
        identity := unifiedEvent["identity"]
        return this.TraceEvent("input", "raw_input", {
            Source: identity["name"], Outcome: unifiedEvent["phase"],
            Detail: this.FormatRawInputDetail(unifiedEvent),
            Data: unifiedEvent})
    }

    FormatRawInputDetail(event) {
        return InputEvent.FormatDiagnosticDetail(event, this.GetInputDevices())
    }

    GetInputDevices() {
        try return this.RawInput.GetDevices()
        catch
            return []
    }

    BeginRawObservation() {
        this.RawObservationDepth++
        return true
    }

    EndRawObservation(force := false) {
        if this.RawObservationDepth < 1
            return false
        this.RawObservationDepth := force ? 0 : this.RawObservationDepth - 1
        return true
    }

    SuspendRemappingForCapture() => this.Runtime.SuspendForCapture()

    ResumeRemappingAfterCapture(changed) => changed
        ? this.Runtime.ResumeAfterCapture() : false

    OpenEventViewer(*) {
        return this.OpenAuxiliaryWindow("EventViewer",
            () => EventViewerWindow(this.Window), Tr("事件查看"))
    }

    OnEventViewerClosed(viewer) {
        if IsObject(this.EventViewer) && this.EventViewer == viewer
            this.EventViewer := ""
    }

    OpenHelpInfo(*) {
        return this.OpenAuxiliaryWindow("SupportInfo",
            () => SupportInfoWindow(this.Window), Tr("帮助"))
    }

    OnSupportInfoClosed(window) {
        if IsObject(this.SupportInfo) && this.SupportInfo == window
            this.SupportInfo := ""
    }

    OpenHelp(*) {
        return this.OpenAuxiliaryWindow("Help",
            () => HelpWindow(this.Window), Tr("使用说明"))
    }

    OnHelpClosed(window) {
        if IsObject(this.Help) && this.Help == window
            this.Help := ""
    }

    OpenDonation(ownerWindow := "", *) {
        if !IsObject(ownerWindow)
                || !ownerWindow.HasOwnProp("Gui")
                || !IsObject(ownerWindow.Gui)
            ownerWindow := this.Window
        return this.OpenAuxiliaryWindow("Donation",
            () => DonationWindow(ownerWindow), Tr("支持开源项目"))
    }

    OnDonationClosed(window) {
        if IsObject(this.Donation) && this.Donation == window
            this.Donation := ""
    }

    OpenAbout(*) {
        return this.OpenAuxiliaryWindow("About",
            () => AboutWindow(this.Window), Tr("关于"))
    }

    OnAboutClosed(window) {
        if IsObject(this.About) && this.About == window
            this.About := ""
    }

    OpenSettings(*) {
        return this.OpenAuxiliaryWindow("SettingsWindow",
            () => SettingsWindow(this.Window), Tr("键鼠重映射小助手设置"))
    }

    OpenAISettings(ownerWindow := "", *) {
        if !IsObject(ownerWindow) || !ownerWindow.HasOwnProp("Gui")
                || !IsObject(ownerWindow.Gui)
            ownerWindow := this.Window
        currentWindow := this.SettingsWindow
        if IsObject(currentWindow) && !currentWindow.Disposed {
            currentWindow.SwitchTab(3)
            return currentWindow.Activate()
        }
        return this.OpenAuxiliaryWindow("SettingsWindow",
            () => this.CreateAISettingsWindow(ownerWindow),
            Tr("键鼠重映射小助手设置"))
    }

    CreateAISettingsWindow(ownerWindow) {
        return SettingsWindow(ownerWindow, 3)
    }

    OpenAuxiliaryWindow(propertyName, factory, label) {
        if this.ShuttingDown
            return false
        currentWindow := this.%propertyName%
        if IsObject(currentWindow) {
            if !currentWindow.Disposed
                return currentWindow.Activate()
            this.%propertyName% := ""
        }
        candidate := ""
        try {
            candidate := factory.Call()
            this.%propertyName% := candidate
            candidate.Show()
            return true
        } catch as openError {
            if IsObject(candidate)
                try candidate.Dispose(false)
            if IsObject(this.%propertyName%)
                    && this.%propertyName% == candidate
                this.%propertyName% := ""
            this.Window.SetStatus(label "：" TrDiagnostic(openError.Message),
                true)
            return false
        }
    }

    OnSettingsClosed(window) {
        if IsObject(this.SettingsWindow) && this.SettingsWindow == window
            this.SettingsWindow := ""
    }

    SaveAIConnectionSettings(aiSettings) {
        candidate := this.SettingsService.Normalize(this.Settings)
        candidate.AIAddress := aiSettings.AIAddress
        candidate.AIKey := aiSettings.AIKey
        candidate.AIModel := aiSettings.AIModel
        candidate.AITimeoutS := aiSettings.AITimeoutS
        previousSnapshot := this.SettingsService.GetSnapshot()
        this.Settings := this.SettingsService.Save(candidate, previousSnapshot)
        return true
    }

    SaveSettings(candidate) {
        previousSettings := this.Settings
        try {
            previousSnapshot := this.SettingsService.GetSnapshot()
            nextSettings := this.SettingsService.Save(candidate, previousSnapshot)
        } catch as settingsError {
            this.Window.SetStatus(Tr("设置未保存：{1}",
                settingsError.Message), true)
            return false
        }
        nextSnapshot := this.SettingsService.BuildSnapshot(nextSettings)
        this.Settings := nextSettings
        try {
            this.ApplySettingsRuntime(nextSettings)
            previousRunAsAdministrator := previousSettings.HasOwnProp(
                "RunAsAdministrator")
                    ? !!previousSettings.RunAsAdministrator : false
            nextRunAsAdministrator := nextSettings.HasOwnProp(
                "RunAsAdministrator")
                    ? !!nextSettings.RunAsAdministrator : false
            elevationSettingChanged := previousRunAsAdministrator
                != nextRunAsAdministrator
            if elevationSettingChanged
                    && this.HasOwnProp("SystemIntegration")
                    && IsObject(this.SystemIntegration)
                    && (A_IsAdmin || !nextRunAsAdministrator)
                this.SystemIntegration.SynchronizeStartupTaskElevation(
                    nextRunAsAdministrator)
        }
        catch as applyError {
            rollbackErrors := []
            try this.SettingsService.WriteSnapshot(previousSnapshot,
                nextSnapshot)
            catch as fileRollbackError
                rollbackErrors.Push(fileRollbackError.Message)
            this.Settings := previousSettings
            try this.ApplySettingsRuntime(previousSettings)
            catch as runtimeRollbackError
                rollbackErrors.Push(runtimeRollbackError.Message)
            detail := applyError.Message
            if rollbackErrors.Length
                detail .= "；回滚失败：" this.JoinMessages(rollbackErrors)
            this.Window.SetStatus(Tr("设置未保存：{1}", detail), true)
            return false
        }
        this.Window.SetStatus(Tr("设置已保存并已应用。"))
        return true
    }

    ApplySettingsRuntime(settings) {
        appearanceChanged := LocalizationService.RequestedLanguage
                != settings.UiLanguage
            || LocalizationService.RequestedUiFont != settings.UiFont
            || UiThemeService.GetRequestedTheme() != settings.Theme
        if appearanceChanged {
            LocalizationService.Configure(settings.UiLanguage,
                settings.UiFont)
            UiThemeService.Configure(settings.Theme)
            this.ApplyOpenWindowAppearances()
        }
        this.ConfigureTray()
        if IsObject(this.UpdateService)
            this.UpdateService.UiLanguage := LocalizationService.GetLanguage()
        capacityChanged := this.Trace.SetCapacity(settings.EventBufferCapacity)
        if capacityChanged && IsObject(this.EventViewer)
            this.EventViewer.OnTraceCapacityChanged()
        if settings.RunAsAdministrator && !A_IsAdmin
            SetTimer(this.ElevationRestartTimer, -1)
        else
            SetTimer(this.ElevationRestartTimer, 0)
        return true
    }

    ApplyOpenWindowAppearances() {
        this.Window.ApplyAppearance()
        for propertyName in ["SettingsWindow", "PackageImportPreview",
                "EventViewer", "SupportInfo", "Help", "Donation", "About"] {
            window := this.%propertyName%
            if IsObject(window) && !window.Disposed
                window.ApplyAppearance()
        }
        return true
    }

    JoinMessages(messages) {
        result := ""
        for message in messages
            result .= (result == "" ? "" : "；") String(message)
        return result
    }

    LogUpdateServiceMessage(message) {
        return this.TraceEvent("system", "update", {
            Outcome: "error", Detail: String(message)})
    }

    BeginApplicationUpdateCheck(interactive := false, ownerGui := "", *) {
        if this.ShuttingDown
            return false
        try {
            started := this.UpdateService.BeginCheck(interactive, ownerGui)
            if !started && interactive {
                ShowDarkMsgBox(Tr("更新检查正在进行，请稍候。"),
                    Tr("检查更新"), "Info", ownerGui)
            }
            return started
        }
        catch as updateError {
            this.TraceEvent("system", "update_check", {
                Outcome: "error", Detail: updateError.Message})
            if interactive
                ShowDarkMsgBox(Tr("无法检查更新：{1}",
                    TrDiagnostic(updateError.Message)), Tr("检查更新"),
                    "Error", ownerGui)
            return false
        }
    }

    HandleUpdateCheckResult(result, interactive := false, ownerGui := "") {
        if IsObject(this.About)
            try this.About.SetUpdateCheckActive(false)
        if !IsObject(result)
            return false
        activeOwner := this.ResolveUpdateDialogOwner(ownerGui)
        if result.Status == "error" {
            noUpdateText := result.HasOwnProp("Error") ? result.Error : ""
            if noUpdateText == "没有可安装的应用更新"
                    || noUpdateText == Tr("没有可安装的应用更新")
                result := this.UpdateService.CurrentResult()
        }
        if result.Status == "current" {
            this.TraceEvent("system", "update_check",
                {Outcome: "current", Detail: result.CurrentVersion})
            if interactive
                ShowDarkMsgBox(Tr("当前陪伴您的已经是最新版本的小助手啦！"),
                    Tr("检查更新"), "Info", activeOwner)
            return true
        }
        if result.Status == "available" {
            this.TraceEvent("system", "update_check", {
                Outcome: "available", Detail: result.Version})
            if !interactive
                return true
            updateMethod := A_IsCompiled
                ? Tr("将下载并校验完整发行包，退出小助手后替换程序文件并自动重启。")
                : (FileExist(A_ScriptDir "\.git")
                    ? Tr("将确认源码仓库没有未提交修改，再快速前进到正式发布标签并自动重启。")
                    : Tr("将下载并校验源码发行包，保留个人配置后替换源码并自动重启。"))
            message := Tr(
                "发现新版本 {1}，当前版本为 {2}。`n`n{3}`n`n是否立即更新？",
                result.Version, result.CurrentVersion, updateMethod)
            if !ShowDarkConfirmBox(message, Tr("小助手更新"),
                    Tr("立即更新"), Tr("稍后"), activeOwner)
                return true
            try {
                this.UpdateService.BeginInstall(result)
                this.TraceEvent("system", "update_install", {
                    Outcome: "started", Detail: result.Version})
                this.Shutdown()
                ExitApp(0)
            } catch as installError {
                this.TraceEvent("system", "update_install", {
                    Outcome: "error", Detail: installError.Message})
                ShowDarkMsgBox(Tr("无法开始更新：{1}",
                    TrDiagnostic(installError.Message)), Tr("小助手更新"),
                    "Error", activeOwner)
                return false
            }
            return true
        }
        errorText := result.HasOwnProp("Error") ? result.Error
            : Tr("更新检查未返回结果")
        this.TraceEvent("system", "update_check",
            {Outcome: "error", Detail: errorText})
        if interactive
            ShowDarkMsgBox(Tr("检查更新失败：{1}",
                TrDiagnostic(errorText)), Tr("检查更新"), "Error",
                activeOwner)
        return false
    }

    ResolveUpdateDialogOwner(ownerGui := "") {
        if IsObject(ownerGui) && Type(ownerGui) == "Gui" {
            try {
                if WinExist(ownerGui.Hwnd)
                    return ownerGui
            }
        }
        return this.Window.Gui
    }

    CreateApplicationShortcuts(ownerGui := "") {
        try return this.SystemIntegration.CreateApplicationShortcuts()
        catch as shortcutError {
            ShowDarkMsgBox(Tr("创建快捷方式失败：{1}",
                TrDiagnostic(shortcutError.Message)), Tr("错误"),
                "Error", ownerGui)
            return false
        }
    }

    GetStartupTaskState(runAsAdministrator := "") {
        if runAsAdministrator == ""
            runAsAdministrator := this.Settings.RunAsAdministrator
        try return this.SystemIntegration.GetStartupTaskState("",
            runAsAdministrator)
        catch
            return {Status: "error", Task: ""}
    }

    ToggleStartupTask(ownerGui := "", runAsAdministrator := "") {
        if runAsAdministrator == ""
            runAsAdministrator := this.Settings.RunAsAdministrator
        try return this.SystemIntegration.ToggleStartupTask(
            runAsAdministrator)
        catch as taskError {
            ShowDarkMsgBox(Tr("操作计划任务时发生错误：{1}",
                TrDiagnostic(taskError.Message)), Tr("错误"),
                "Error", ownerGui)
            return false
        }
    }

    GetSummaryText() {
        return Tr("{1} 条重映射正在生效 · 当前为脚本代码顺序",
            this.GetAppliedMappingCount())
    }

    GetSettingsLoadWarningText() {
        try warning := Trim(String(this.SettingsService.LastLoadWarning))
        catch
            return ""
        if warning == ""
            return ""
        prefix := "无法读取设置文件，已使用默认设置："
        detail := InStr(warning, prefix) == 1
            ? SubStr(warning, StrLen(prefix) + 1) : warning
        return Tr("无法读取设置文件，已使用默认设置：{1}",
            TrDiagnostic(detail))
    }

    GetAppliedMappingCount() {
        if !IsObject(this.RuntimeReport)
                || !this.RuntimeReport.HasOwnProp("Applied")
            return 0
        try return Max(0, Integer(this.RuntimeReport.Applied))
        catch
            return 0
    }

    OnCaptureCompleted(role, capture) {
        this.TraceEvent("input", "capture_completed", {Outcome: role,
            Source: capture.RawDisplay})
        this.Window.AcceptCapture(role, capture)
    }

    OnCapturePreview(role, capture) {
        if this.Capture.Active && this.Capture.Role == role
            this.Window.PreviewCapture(role, capture)
    }

    OnCaptureCancelled(reason := "", *) {
        this.TraceEvent("input", "capture_cancelled", {Outcome: "cancelled"})
        if StrLower(String(reason)) == "escape"
            try this.Window.SuppressEscapeAfterCapture(3000)
        this.Window.CancelCaptureState()
    }

    OnCaptureRejected(reason) {
        this.TraceEvent("input", "capture_rejected", {Outcome: "rejected",
            Detail: reason})
        this.Window.RejectCapture(TrDiagnostic(reason))
    }

    OnCaptureResumeFailed(message) {
        this.TraceEvent("input", "capture_resume_failed", {Outcome: "error",
            Detail: message})
        this.Window.SetStatus(Tr("录制结束后无法恢复重映射：{1}",
            message), true)
    }

    ShouldCancelCaptureForPointer(*) => this.Window.IsPointerOverCaptureButton()
    PrepareCaptureEscapeCancellation(*) => this.Window.SuppressEscapeAfterCapture(3000)
    PrepareCapturePointerCancellation(*) => this.Window.SuppressNextPointerButtonActivation()
    FinalizeCapturePointerCancellation(*) => this.Window.FinalizePointerButtonCancellation()

    OnAppCommand(wParam, lParam, *) {
        if !this.Capture.IsInputBlocked()
            return
        if this.Capture.Active
            this.Capture.CompleteAppCommand((lParam >> 16) & 0x0FFF)
        ; WM_APPCOMMAND is a second input path used by media/browser keys.
        ; Mark every command handled while the low-level capture guard owns
        ; input, including the short drain after recording has ended.
        return 1
    }

    OnSystemCommand(wParam, lParam, msg, hwnd) {
        command := wParam & 0xFFF0
        if command == Win32.SC_MINIMIZE
                && WindowHierarchy.MinimizeChildIndependently(hwnd)
            return 0
        if command == Win32.SC_RESTORE || command == Win32.SC_MAXIMIZE {
            if WindowHierarchy.RestoreChildFromTaskbar(hwnd,
                    command == Win32.SC_MAXIMIZE)
                return 0
            WindowHierarchy.PrepareChildRestore(hwnd)
        }
    }

    OnSystemSettingChange(*) {
        if UiThemeService.GetRequestedTheme() == "auto"
                && UiThemeService.HandleSystemSettingChange() {
            try this.ApplyOpenWindowAppearances()
            catch as appearanceError
                this.TraceEvent("ui", "system_theme_refresh_failed", {
                    Outcome: "error", Detail: appearanceError.Message})
        }
    }

    OnPowerBroadcast(wParam, *) {
        if this.ShuttingDown
            return
        if wParam == Win32.PBT_APMSUSPEND
            return this.RecoverInterruptedInputState("power_suspend")
        if wParam != Win32.PBT_APMRESUMEAUTOMATIC
                && wParam != Win32.PBT_APMRESUMESUSPEND
            return
        this.RecoverInterruptedInputState("power_resume")
        try {
            devices := this.RawInput.RecoverAfterResume()
            this.TraceEvent("system", "input_devices_recovered", {
                Outcome: "ok", Data: Map("devices", devices.Length)})
        } catch as recoveryError {
            this.TraceEvent("system", "input_devices_recovery_failed", {
                Outcome: "error", Detail: recoveryError.Message})
        }
        return true
    }

    OnSessionChange(wParam, sessionId, message, hwnd) {
        if this.ShuttingDown || hwnd != this.Window.Gui.Hwnd
            return false
        if wParam == Win32.WTS_SESSION_LOCK
                || wParam == Win32.WTS_SESSION_UNLOCK
            return this.RecoverInterruptedInputState(
                wParam == Win32.WTS_SESSION_LOCK
                    ? "session_lock" : "session_unlock", sessionId)
        return false
    }

    RecoverInterruptedInputState(eventName, sessionId := "") {
        try {
            recovered := this.Runtime.RecoverAfterResume()
            fields := {Outcome: recovered ? "ok" : "error"}
            if sessionId != ""
                fields.Source := String(sessionId)
            this.TraceEvent("system", eventName, fields)
            return recovered
        } catch as recoveryError {
            this.TraceEvent("system", eventName "_failed", {
                Outcome: "error", Detail: recoveryError.Message})
            return false
        }
    }

    RegisterSessionNotifications() {
        if this.SessionNotificationsRegistered
            return true
        if DllCall("wtsapi32\WTSRegisterSessionNotification", "Ptr",
                this.Window.Gui.Hwnd, "UInt", 0, "Int") {
            this.SessionNotificationsRegistered := true
            return true
        }
        this.TraceEvent("system", "session_notification_registration_failed",
            {Outcome: "error", Detail: "Win32 " A_LastError})
        return false
    }

    UnregisterSessionNotifications() {
        if !this.SessionNotificationsRegistered
            return true
        if !DllCall("wtsapi32\WTSUnRegisterSessionNotification", "Ptr",
                this.Window.Gui.Hwnd, "Int")
            return false
        this.SessionNotificationsRegistered := false
        return true
    }

    RegisterCallbacks() {
        if this.CallbacksRegistered
            return true
        registrations := [
            {Message: 0x0319, Callback: this.AppCommandCallback},
            {Message: 0x0112, Callback: this.SystemCommandCallback},
            {Message: Win32.WM_SETTINGCHANGE,
                Callback: this.SettingChangeCallback},
            {Message: Win32.WM_POWERBROADCAST,
                Callback: this.PowerBroadcastCallback},
            {Message: Win32.WM_WTSSESSION_CHANGE,
                Callback: this.SessionChangeCallback}
        ]
        if this.ShowApplicationMessage
            registrations.Push({Message: this.ShowApplicationMessage,
                Callback: this.ShowApplicationCallback})
        completed := []
        exitRegistered := false
        try {
            for registration in registrations {
                OnMessage(registration.Message, registration.Callback)
                completed.Push(registration)
            }
            OnExit(this.ExitCallback)
            exitRegistered := true
            this.CallbacksRegistered := true
        } catch as registrationError {
            if exitRegistered
                try OnExit(this.ExitCallback, 0)
            Loop completed.Length {
                registration := completed[completed.Length - A_Index + 1]
                try OnMessage(registration.Message, registration.Callback, 0)
            }
            throw registrationError
        }
        return true
    }

    UnregisterCallbacks() {
        if !this.CallbacksRegistered
            return true
        cleanup := CleanupCollector("应用消息回调")
        cleanup.Run("注销应用命令", () =>
            OnMessage(0x0319, this.AppCommandCallback, 0))
        cleanup.Run("注销系统命令", () =>
            OnMessage(0x0112, this.SystemCommandCallback, 0))
        cleanup.Run("注销系统设置消息", () => OnMessage(
            Win32.WM_SETTINGCHANGE, this.SettingChangeCallback, 0))
        cleanup.Run("注销电源消息", () => OnMessage(
            Win32.WM_POWERBROADCAST, this.PowerBroadcastCallback, 0))
        cleanup.Run("注销会话消息", () => OnMessage(
            Win32.WM_WTSSESSION_CHANGE, this.SessionChangeCallback, 0))
        if this.ShowApplicationMessage
            cleanup.Run("注销单实例唤醒消息", () => OnMessage(
                this.ShowApplicationMessage, this.ShowApplicationCallback, 0))
        cleanup.Run("注销退出回调", () => OnExit(this.ExitCallback, 0))
        if !cleanup.Failures.Length
            this.CallbacksRegistered := false
        cleanup.Complete()
        return true
    }

    ConsumeShowAfterReloadMarker() {
        if !this.ReadShowAfterReloadMarker()
            return false
        try {
            this.WriteShowAfterReloadMarker(false)
            return !this.ReadShowAfterReloadMarker()
        } catch {
            return false
        }
    }

    ReadShowAfterReloadMarker() {
        try return IniRead(this.RuntimeStatePath, "Runtime",
            "ShowAfterReload", "0") == "1"
        catch
            return false
    }

    WriteShowAfterReloadMarker(enabled) {
        if !DirExist(this.DataDirectory)
            DirCreate(this.DataDirectory)
        IniWrite(enabled ? "1" : "0", this.RuntimeStatePath, "Runtime",
            "ShowAfterReload")
        return true
    }

    ShowMainWindowAfterReload(*) {
        if this.ShuttingDown
            return false
        return this.Window.Activate()
    }

    OnShowApplicationRequest(sourceModified, sourceSize, message, hwnd) {
        if this.ShuttingDown || hwnd != this.Window.Gui.Hwnd
            return 0
        diskRevision := ReadApplicationSourceRevision()
        incomingRevision := {Modified: sourceModified, Size: sourceSize}
        if ApplicationSourceReloadRequired(this.SourceRevision,
                diskRevision, incomingRevision) {
            SetTimer(this.ExternalTakeoverTimer, -1)
            return 2
        }
        return this.ShowMainWindowAfterReload() ? 1 : 0
    }

    ExitForExternalLaunch(*) {
        if this.ShuttingDown
            return false
        this.Shutdown()
        ExitApp(0)
        return true
    }

    SaveMainWindowLayout() {
        if !IsObject(this.Window) || !IsObject(this.WindowLayoutService)
            return false
        size := this.Window.GetPersistableClientSize()
        if !IsObject(size)
            return false
        this.WindowLayout := this.WindowLayoutService.Save(size)
        return true
    }

    TrySaveMainWindowLayout() {
        try return this.SaveMainWindowLayout()
        catch as layoutError {
            try this.TraceEvent("system", "window_layout_save_failed", {
                Outcome: "error", Detail: layoutError.Message})
            return false
        }
    }

    ReloadFromTray(*) {
        return this.ReloadApplication(this.Settings.RunAsAdministrator
            && !A_IsAdmin)
    }

    RestartWithConfiguredElevation(*) {
        if this.ShuttingDown || A_IsAdmin
                || !this.Settings.RunAsAdministrator
            return false
        return this.ReloadApplication(true)
    }

    ReloadApplication(runElevated := false) {
        if this.ShuttingDown
            return false
        previousCritical := A_IsCritical
        reloadMarkerWritten := false
        try {
            Critical("On")
            if !A_IsCompiled {
                validationCommand := BuildReloadValidationCommand(A_AhkPath,
                    A_ScriptFullPath)
                if RunWait(validationCommand, A_ScriptDir, "Hide") != 0
                    throw Error(Tr("新脚本未通过 AutoHotkey 启动验证。"))
            }
            this.WriteShowAfterReloadMarker(true)
            reloadMarkerWritten := true
            currentPid := DllCall("kernel32\GetCurrentProcessId", "UInt")
            handoffCommand := runElevated
                ? BuildApplicationElevationCommand(currentPid,
                    A_IsCompiled, A_AhkPath, A_ScriptFullPath, A_Args)
                : BuildReloadHandoffCommand(currentPid, A_IsCompiled,
                    A_AhkPath, A_ScriptFullPath)
            Run((runElevated ? "*RunAs " : "") handoffCommand,
                A_ScriptDir)
        } catch as reloadError {
            if reloadMarkerWritten
                try this.WriteShowAfterReloadMarker(false)
            Critical(previousCritical ? previousCritical : "Off")
            this.Window.SetStatus(Tr("重新加载失败，已保留当前实例：{1}",
                reloadError.Message), true)
            this.Window.Show()
            return false
        }
        this.Shutdown()
        ExitApp(0)
        return true
    }

    HandleExit(*) {
        try this.Shutdown()
        return 0
    }

    Shutdown(*) {
        if this.ShuttingDown
            return
        this.ShuttingDown := true
        if IsObject(this.PendingScriptApplyTimer)
            try SetTimer(this.PendingScriptApplyTimer, 0)
        if IsObject(this.ElevationRestartTimer)
            try SetTimer(this.ElevationRestartTimer, 0)
        this.PendingScriptApply := ""
        this.TrySaveMainWindowLayout()
        ; Runtime shutdown may wait for isolated script-rule processes. Hide
        ; the fully rendered window before any painter, font, theme or child
        ; process resources are released, so takeover/reload can never expose
        ; an old instance while its visual surface is being dismantled.
        try this.Window.HideForShutdown()
        if this.MainWindowRegistered {
            try UnregisterApplicationMainWindow(this.Window.Gui.Hwnd)
            this.MainWindowRegistered := false
        }
        try this.UnregisterSessionNotifications()
        try this.UnregisterCallbacks()
        try SetTimer(this.StartupUpdateTimer, 0)
        try SetTimer(this.ExternalTakeoverTimer, 0)
        try this.UpdateService.Shutdown()
        try this.AIService.Shutdown()
        try this.Capture.Stop(false, false)
        try this.RawInput.Shutdown()
        try this.Runtime.Shutdown()
        for windowName in ["PackageImportPreview", "SettingsWindow",
                "EventViewer", "SupportInfo", "Help", "Donation", "About"] {
            window := this.%windowName%
            if IsObject(window)
                try window.Dispose(false)
        }
        try this.Window.Dispose()
        try this.SvgRenderer.Shutdown()
        try LocalizationService.ShutdownUiFonts()
    }
}
