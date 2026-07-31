class KeyMouseRemapperAssistantApp {
    __New(settingsPath := "", historyPath := "", notificationPath := "",
            variablePath := "", controlPath := "",
            healthPath := "", recoveryPath := "", outputRecoveryPath := "",
            crashDiagnosticPath := "") {
        this.WakeUpDelay := 2000
        this.MappingCount := 0
        settingsUsesDefaultPath := settingsPath == ""
        needsDefaultPaths := settingsUsesDefaultPath || historyPath == ""
            || notificationPath == "" || variablePath == ""
            || controlPath == "" || healthPath == "" || recoveryPath == ""
            || outputRecoveryPath == "" || crashDiagnosticPath == ""
        defaultPaths := needsDefaultPaths
            ? KeyMouseRemapperAssistantDataPaths.Resolve() : ""
        if settingsUsesDefaultPath
            settingsPath := defaultPaths.Settings
        if historyPath == ""
            historyPath := defaultPaths.History
        if notificationPath == ""
            notificationPath := defaultPaths.Notification
        if variablePath == "" && settingsUsesDefaultPath
            variablePath := defaultPaths.Variables
        else if variablePath == "" {
            settingsDirectory := ""
            SplitPath(settingsPath, , &settingsDirectory)
            variablePath := settingsDirectory "\variables.json"
        }
        if controlPath == "" && settingsUsesDefaultPath
            controlPath := defaultPaths.Control
        else if controlPath == "" {
            settingsDirectory := ""
            SplitPath(settingsPath, , &settingsDirectory)
            controlPath := settingsDirectory "\control-requests.json"
        }
        if healthPath == "" && settingsUsesDefaultPath
            healthPath := defaultPaths.StartupHealth
        else if healthPath == "" {
            settingsDirectory := ""
            SplitPath(settingsPath, , &settingsDirectory)
            healthPath := settingsDirectory "\startup-health.json"
        }
        if recoveryPath == "" && settingsUsesDefaultPath
            recoveryPath := defaultPaths.LastKnownGood
        else if recoveryPath == "" {
            settingsDirectory := ""
            SplitPath(settingsPath, , &settingsDirectory)
            recoveryPath := settingsDirectory "\last-known-good.json"
        }
        if outputRecoveryPath == "" && settingsUsesDefaultPath
            outputRecoveryPath := defaultPaths.OutputRecovery
        else if outputRecoveryPath == "" {
            settingsDirectory := ""
            SplitPath(settingsPath, , &settingsDirectory)
            outputRecoveryPath := settingsDirectory "\output-recovery.json"
        }
        if crashDiagnosticPath == "" && settingsUsesDefaultPath
            crashDiagnosticPath := defaultPaths.CrashDiagnostics
        else if crashDiagnosticPath == "" {
            settingsDirectory := ""
            SplitPath(settingsPath, , &settingsDirectory)
            crashDiagnosticPath := settingsDirectory
                . "\crash-diagnostics.json"
        }
        this.CrashRecovery := CrashRecoveryService(crashDiagnosticPath)
        this.StartupCleanupReport := {Removed: [], SkippedRecent: [],
            Failures: []}
        this.StartupCleanupError := ""
        try this.StartupCleanupReport :=
            this.CrashRecovery.CleanupStaleTransactions([
                settingsPath, historyPath, notificationPath,
                variablePath, controlPath, healthPath, recoveryPath,
                outputRecoveryPath, crashDiagnosticPath, A_ScriptFullPath])
        catch as cleanupError {
            this.StartupCleanupError := cleanupError.Message
            try this.CrashRecovery.Record("transaction_cleanup_failure",
                cleanupError.Message, Map())
        }
        this.Health := StartupHealthService(healthPath, recoveryPath)
        this.StartupState := this.Health.Begin(A_ScriptFullPath)
        this.SafeMode := this.StartupState.SafeMode
        this.StartupSucceeded := false
        this.SettingsService := AppSettingsService(settingsPath)
        this.Settings := this.SettingsService.Load()
        if this.SettingsService.LastLoadWarning != "" {
            try this.CrashRecovery.Record("settings_load_fallback",
                this.SettingsService.LastLoadWarning,
                Map("path", this.SettingsService.SettingsPath))
        }
        LocalizationService.Configure(this.Settings.UiLanguage,
            this.Settings.UiFont)
        UiThemeService.Configure(this.Settings.Theme)
        MappingWindow.Colors := UiThemeService.GetPalette()
        this.SvgRenderer := SvgRenderLibrary(GetApplicationRootFilePath(
            "third_party\resvg\resvg.dll"))
        this.Repository := MappingCodeRepository(A_ScriptFullPath)
        this.History := PersistentHistoryService(historyPath,
            notificationPath, 20)
        this.Trace := EventTraceService(this.Settings.EventBufferCapacity)
        this.Diagnostics := DiagnosticBundleService()
        this.VariableStore := ScopedVariableStore(variablePath)
        this.ControlQueue := ApplicationControlQueue(controlPath)
        this.OutputRecoveryJournal := OutputRecoveryJournal(
            outputRecoveryPath)
        this.ContextService := WindowsContextService()
        this.PackageService := RulePackageService()
        this.Window := MappingWindow(this)
        this.Capture := KeyCaptureSession(this)
        this.UseWorkerProcesses := EnvGet(
            "KEY_MOUSE_REMAPPER_GUI_TEST_OFFSCREEN") == ""
            && !HasCommandLineFlag("--single-process")
        this.ProcessController := this.UseWorkerProcesses
            ? InputWorkerController(this) : ""
        if this.UseWorkerProcesses {
            this.Runtime := RemoteManagedRuleRuntime(this.ProcessController)
            this.RawInput := RemoteRawInputService(this.ProcessController)
        } else {
            backend := RawInputBackend(this.Window.Gui.Hwnd,
                ObjBindMethod(this, "OnRawInputEvent"))
            this.Runtime := ManagedRuleRuntime(this, backend)
            this.RawInput := backend.RawInput
        }
        this.RuntimeReport := ""
        this.Toast := HistoryToastWindow(this.Window)
        this.SettingsWindow := ""
        this.EventViewer := ""
        this.SupportInfo := ""
        this.Help := ""
        this.Donation := ""
        this.PackageImportPreview := ""
        this.PowerCallback := ObjBindMethod(this, "OnPowerEvent")
        this.SessionChangeCallback := ObjBindMethod(this, "OnSessionChange")
        this.SessionNotificationsRegistered := false
        this.PowerRecoveryTimer := ObjBindMethod(this,
            "PerformPowerRecovery")
        this.AppCommandCallback := ObjBindMethod(this, "OnAppCommand")
        this.SystemCommandCallback := ObjBindMethod(this, "OnSystemCommand")
        this.KeyDownCallback := ObjBindMethod(this, "OnGlobalKeyDown")
        this.SettingChangeCallback := ObjBindMethod(this,
            "OnSystemSettingChange")
        this.WindowMoveCallback := ObjBindMethod(this, "OnWindowMove")
        this.SystemThemeTimer := ObjBindMethod(this,
            "ApplySystemThemeChange")
        this.ExitCallback := ObjBindMethod(this, "HandleExit")
        this.ExitCallbackRegistered := false
        this.ApplicationCallbacksRegistered := false
        this.MessageRegistrations := []
        this.ReloadTimer := ObjBindMethod(this, "PerformScheduledReload")
        this.ControlPollTimer := ObjBindMethod(this,
            "PollExternalControlQueue")
        this.StartupStableTimer := ObjBindMethod(this,
            "MarkStartupStable")
        this.ReloadPending := false
        this.ShuttingDown := false
        this.RawObservationDepth := 0
        this.RawObservationState := ""
        this.ControlQueueErrorFingerprint := ""
        this.PowerSuspended := false
        this.PowerScriptWasSuspended := false
        this.PowerBackendWasSuspended := false
    }

    Start() {
        showAfterReload := (EnvGet(
            "KEY_MOUSE_REMAPPER_SHOW_AFTER_RELOAD") == "1")
        if showAfterReload
            try EnvSet("KEY_MOUSE_REMAPPER_SHOW_AFTER_RELOAD", "")
        this.RegisterApplicationCallbacks()
        this.RegisterSessionNotifications()
        this.ConfigureTray()
        rawInputError := ""
        workerProcessError := ""
        outputRecoveryError := ""
        recoveredOutputCount := 0
        try recoveredOutputCount := this.OutputRecoveryJournal.Recover(
            ObjBindMethod(this, "ReleaseRecoveredOutputKey"))
        catch as recoveredOutputError {
            outputRecoveryError := recoveredOutputError.Message
            try this.CrashRecovery.Record("output_recovery_failure",
                recoveredOutputError.Message, Map(
                    "file_path", this.OutputRecoveryJournal.FilePath))
        }
        if this.SafeMode {
            try this.CrashRecovery.Record("safe_mode_entered",
                this.StartupState.LastError, Map(
                    "consecutive_failures",
                        this.StartupState.ConsecutiveFailures,
                    "session_id", this.StartupState.SessionId))
        }
        if !this.SafeMode {
            if this.UseWorkerProcesses {
                try this.ProcessController.Start()
                catch as workerStartError {
                    workerProcessError := workerStartError.Message
                    rawInputError := workerProcessError
                }
            } else {
                try this.RawInput.Start()
                catch as rawStartError
                    rawInputError := rawStartError.Message
            }
        }
        mappings := []
        loadError := ""
        try mappings := this.Repository.Load()
        catch as repositoryError
            loadError := repositoryError.Message
        this.MappingCount := mappings.Length
        runtimeError := ""
        if loadError == "" && !this.SafeMode && workerProcessError == "" {
            try this.RuntimeReport := this.Runtime.ApplyMappings(mappings)
            catch as managedRuntimeError
                runtimeError := managedRuntimeError.Message
        }
        this.TraceEvent("system", "startup", {Outcome: loadError == ""
            ? "ok" : "error", Detail: loadError,
            Data: Map("mapping_count", this.MappingCount,
                "raw_input", rawInputError == "" ? "active" : "failed",
                "raw_input_error", rawInputError,
                "recovered_output_keys", recoveredOutputCount,
                "output_recovery_error", outputRecoveryError)})
        this.Window.LoadRows(mappings)
        historyWarning := this.History.LoadWarning
        startupError := loadError != "" ? loadError
            : (runtimeError != "" ? runtimeError
                : (outputRecoveryError != "" ? outputRecoveryError
                    : (workerProcessError != "" ? workerProcessError
                        : rawInputError)))
        if startupError != "" && !this.SafeMode {
            try this.CrashRecovery.Record("startup_failure", startupError,
                Map("session_id", this.StartupState.SessionId,
                    "mapping_count", this.MappingCount))
            failureState := this.Health.RecordStartupFailure(startupError)
            this.StartupState := failureState
            if failureState.SafeMode {
                this.SafeMode := true
                try this.Runtime.Shutdown()
                try this.RawInput.Shutdown()
            }
        } else if !this.SafeMode {
            this.Health.MarkRunning()
            this.StartupSucceeded := true
            SetTimer(this.StartupStableTimer, -10000)
        }
        statusError := this.SafeMode || startupError != ""
            || historyWarning != ""
        statusText := this.SafeMode
            ? Tr("安全模式：已停用所有映射和输入观察。连续启动失败 {1} 次。",
                this.StartupState.ConsecutiveFailures)
            : (loadError != ""
            ? Tr("读取重映射代码区域失败：{1}", loadError)
            : (startupError != "" ? Tr("托管规则未应用：{1}", startupError)
                : (historyWarning != "" ? historyWarning
                    : this.GetSummaryText())))
        this.Window.SetStatus(statusText, statusError)
        SetTimer(this.ControlPollTimer, 250)
        if showAfterReload
            this.Window.Show()
    }

    ConfigureTray() {
        A_IconTip := Tr("键鼠重映射小助手")
        iconPath := GetApplicationIconPath()
        if FileExist(iconPath)
            try TraySetIcon(iconPath)
        A_TrayMenu.Delete()
        A_TrayMenu.Add(Tr("显示主界面"), ObjBindMethod(this.Window, "Show"))
        A_TrayMenu.Add(Tr("重新加载"),
            ObjBindMethod(this, "ReloadNow", true))
        A_TrayMenu.Add(Tr("退出程序"), (*) => ExitApp())
        A_TrayMenu.Default := Tr("显示主界面")
        A_TrayMenu.ClickCount := 1
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

    NormalizeSourceSpec(sourceSpec) {
        return LTrim(StrLower(RegExReplace(String(sourceSpec), "\s+")), "$")
    }

    IsSourceAvailable(capture) {
        signature := this.NormalizeSignature(capture.Display)
        sourceSpec := this.NormalizeSourceSpec(capture.SourceSpec)
        try mappings := this.Repository.Load()
        catch as repositoryError {
            this.Window.SetStatus(Tr("无法检查现有映射：{1}",
                repositoryError.Message), true)
            return false
        }
        for mapping in mappings {
            mappingSourceSpec := mapping.SourceSpec
            if mapping.HasOwnProp("Descriptor")
                    && IsObject(mapping.Descriptor)
                    && mapping.Descriptor.HasOwnProp("Signature")
                mappingSourceSpec := mapping.Descriptor.Signature
            if this.NormalizeSignature(mapping.Source) == signature
                || (sourceSpec != "" && this.NormalizeSourceSpec(
                    mappingSourceSpec) == sourceSpec)
                return false
        }
        return true
    }

    AddMapping(sourceCapture, targetCapture, purpose) {
        if this.NormalizeSignature(sourceCapture.Display) == "lbutton" {
            this.Window.SetStatus(Tr(
                "为避免失去界面操作，来源按键不能是无修饰的鼠标左键。"), true)
            return false
        }
        if !this.IsSourceAvailable(sourceCapture) {
            this.Window.SetStatus(Tr("该来源按键已被现有映射占用。"), true)
            return false
        }
        if this.NormalizeSignature(sourceCapture.Display)
            == this.NormalizeSignature(targetCapture.Display) {
            this.Window.SetStatus(Tr("来源按键与目标按键相同，无需建立映射。"), true)
            return false
        }
        try existingMappings := this.Repository.Load()
        catch as repositoryError {
            this.Window.SetStatus(Tr("映射未写入脚本：{1}",
                repositoryError.Message), true)
            return false
        }
        mappingId := this.Repository.CreateMappingId(existingMappings)
        spec := RuleSpec.CreateFromCaptures(mappingId, sourceCapture,
            targetCapture,
            Trim(purpose) == "" ? "用户建立的按键映射。" : Trim(purpose))
        try mapping := this.RunMappingMutation("",
            ObjBindMethod(this.Repository, "AppendManagedSpec", spec),
            mapping => this.CreateHistoryAction("add",
                mapping.Source " -> " mapping.Target, ["managed"]))
        catch as repositoryError {
            this.Window.SetStatus(Tr("映射未写入脚本：{1}",
                repositoryError.Message), true)
            return false
        }
        message := Tr("已写入脚本：{1} -> {2}；正在自动应用。",
            mapping.Source, mapping.Target)
        this.MappingCount++
        this.Window.AddMappingRow(mapping, this.MappingCount)
        this.Window.SetStatus(message)
        return mapping
    }

    DeleteMapping(mappingId) {
        try mapping := this.RunMappingMutation("",
            ObjBindMethod(this.Repository, "Remove", mappingId),
            mapping => this.CreateHistoryAction("delete",
                mapping.Source " -> " mapping.Target,
                ["managed"]))
        catch as repositoryError {
            this.Window.SetStatus(Tr("映射未删除：{1}",
                repositoryError.Message), true)
            return false
        }
        message := Tr("已从脚本删除：{1} -> {2}；正在自动应用。",
            mapping.Source, mapping.Target)
        this.MappingCount := Max(0, this.MappingCount - 1)
        this.Window.RemoveMappingRow(mapping.Id)
        this.Window.SetStatus(message)
        return true
    }

    MoveMappingTo(mappingId, targetIndex) {
        try mapping := this.Repository.GetById(mappingId)
        catch as repositoryError {
            this.Window.SetStatus(Tr("顺序未保存：{1}",
                repositoryError.Message), true)
            return false
        }
        action := this.CreateHistoryAction("reorder",
            mapping.Source " -> " mapping.Target,
            ["managed"])
        try moved := this.RunMappingMutation(action,
            ObjBindMethod(this.Repository, "MoveTo", mappingId, targetIndex))
        catch as repositoryError {
            this.Window.SetStatus(Tr("顺序未保存：{1}",
                repositoryError.Message), true)
            return false
        }
        if !moved {
            this.Window.SetStatus(Tr("映射顺序没有变化。"))
            return false
        }
        message := Tr("已按拖动结果实时更新脚本顺序。")
        this.Window.SetStatus(message)
        return true
    }

    ToggleMappingEnabled(mappingId) {
        try mapping := this.RunMappingMutation("",
            ObjBindMethod(this.Repository, "ToggleEnabled", mappingId),
            mapping => this.CreateHistoryAction(
                mapping.Enabled ? "resume" : "pause",
                mapping.Source " -> " mapping.Target,
                ["managed"]))
        catch as repositoryError {
            this.Window.SetStatus(Tr("映射状态未修改：{1}",
                repositoryError.Message), true)
            return false
        }
        message := mapping.Enabled
            ? Tr("已恢复映射：{1} -> {2}；正在自动应用。",
                mapping.Source, mapping.Target)
            : Tr("已暂停映射：{1} -> {2}；正在自动应用。",
                mapping.Source, mapping.Target)
        this.Window.SetStatus(message)
        return mapping
    }

    UpdateMappingBlock(mappingId, blockText) {
        try mapping := this.RunMappingMutation("",
            ObjBindMethod(this.Repository, "ReplaceBlock", mappingId, blockText),
            mapping => this.CreateHistoryAction("edit-code",
                mapping.Source " -> " mapping.Target,
                ["managed"]))
        catch as repositoryError {
            message := repositoryError.Message
            this.Window.SetStatus(Tr("映射代码未保存：{1}", message), true)
            return {Ok: false, Message: message}
        }
        message := Tr("已保存映射代码：{1} -> {2}；正在自动应用。",
            mapping.Source, mapping.Target)
        this.Window.UpdateMappingRow(mapping)
        this.Window.SetStatus(message)
        return {Ok: true, Mapping: mapping}
    }

    AddMappingBlock(blockText) {
        try mapping := this.RunMappingMutation("",
            ObjBindMethod(this.Repository, "AppendBlock", blockText),
            mapping => this.CreateHistoryAction("add",
                mapping.Source " -> " mapping.Target, ["managed"]))
        catch as repositoryError {
            message := repositoryError.Message
            this.Window.SetStatus(Tr("映射代码未新增：{1}", message), true)
            return {Ok: false, Message: message}
        }
        this.MappingCount++
        this.Window.AddMappingRow(mapping, this.MappingCount)
        message := Tr("已新增映射代码：{1} -> {2}；正在自动应用。",
            mapping.Source, mapping.Target)
        this.Window.SetStatus(message)
        return {Ok: true, Mapping: mapping}
    }

    ScheduleReload(delayMs := 180) {
        if this.ShuttingDown
            return false
        try SetTimer(this.ReloadTimer, 0)
        this.ReloadPending := true
        this.TraceEvent("system", "reload_scheduled", {
            Outcome: "pending", Data: Map("delay_ms", Floor(delayMs))})
        SetTimer(this.ReloadTimer, -Max(1, Floor(delayMs)))
        return true
    }

    PerformScheduledReload(*) {
        if this.ShuttingDown || !this.ReloadPending
            return
        this.ReloadPending := false
        this.ReloadNow(false)
    }

    ReloadNow(showAfterReload := true, *) {
        if this.ShuttingDown
            return false
        try this.Health.PrepareRestart()
        if showAfterReload
            try EnvSet("KEY_MOUSE_REMAPPER_SHOW_AFTER_RELOAD", "1")
        Reload()
        return true
    }

    ReleaseRecoveredOutputKey(keyName) {
        Send("{" String(keyName) " up}")
        return true
    }

    MarkStartupStable(*) {
        if this.ShuttingDown || this.SafeMode || !this.StartupSucceeded
            return false
        try {
            this.Health.MarkStable(this.Repository.ReadRegionBody())
            this.TraceEvent("system", "startup_stable", {Outcome: "ok"})
            return true
        } catch as stableError {
            this.TraceEvent("system", "startup_stable_failed", {
                Outcome: "error", Detail: stableError.Message})
            return false
        }
    }

    PollExternalControlQueue(*) {
        if this.ShuttingDown
            return false
        try requests := this.ControlQueue.ConsumeFor(A_ScriptFullPath)
        catch as queueError {
            fingerprint := queueError.Message
            if fingerprint != this.ControlQueueErrorFingerprint {
                this.ControlQueueErrorFingerprint := fingerprint
                this.TraceEvent("ipc", "control_queue_failed", {
                    Outcome: "error", Detail: queueError.Message})
            }
            return false
        }
        this.ControlQueueErrorFingerprint := ""
        if !requests.Length
            return false
        reasons := []
        for request in requests {
            data := request["data"]
            if data.Has("reason")
                reasons.Push(String(data["reason"]))
            this.TraceEvent("ipc", "external_change_received", {
                Source: String(request["process_id"]), Outcome: "accepted",
                Data: request})
        }
        try {
            this.VariableStore.Load()
            this.ApplyManagedRulesHot()
            this.RefreshMappingRows()
            this.ConfigureTray()
            this.Window.SetStatus(this.GetSummaryText())
            return true
        } catch as applyError {
            this.Window.SetStatus(Tr("读取重映射代码区域失败：{1}",
                applyError.Message), true)
            this.TraceEvent("ipc", "external_change_apply_failed", {
                Outcome: "error", Detail: applyError.Message,
                Data: Map("reasons", reasons)})
            return false
        }
    }

    RunMappingMutation(action, callback, actionBuilder := "") {
        mappingLease := CrossProcessWriteLock.Acquire(
            this.Repository.ScriptPath)
        try {
            beforeState := this.Repository.ReadRegionBody()
            try {
                result := callback.Call()
                afterState := this.Repository.ReadRegionBody()
                if IsObject(actionBuilder)
                    action := actionBuilder.Call(result)
            } catch as mutationError {
                rollbackFailure := this.RestoreMappingState(beforeState)
                if rollbackFailure != ""
                    throw Error("映射修改失败，且状态回滚失败："
                        mutationError.Message "；" rollbackFailure)
                throw mutationError
            }
            try this.ApplyManagedRulesHot()
            catch as runtimeError {
                rollbackFailure := this.RestoreMappingState(beforeState)
                if rollbackFailure != ""
                    throw Error("托管规则热应用失败，且映射代码回滚失败："
                        runtimeError.Message "；" rollbackFailure)
                throw Error("托管规则热应用失败，本次映射修改已回滚："
                    runtimeError.Message)
            }
            try this.History.Commit("mapping", beforeState, afterState, action)
            catch as historyError {
                rollbackFailure := this.RestoreMappingState(beforeState)
                if rollbackFailure != ""
                    throw Error("操作历史未保存，且映射代码回滚失败："
                        historyError.Message "；" rollbackFailure)
                throw Error("操作历史未保存，本次映射修改已回滚："
                    historyError.Message)
            }
            normalizedAction := this.History.NormalizeAction(action)
            this.TraceEvent("repository", normalizedAction.Kind, {
                Source: normalizedAction.Target, Outcome: "committed"})
            return result
        } finally mappingLease.Release()
    }

    ApplyManagedRulesHot() {
        mappings := this.Repository.Load()
        if this.SafeMode {
            this.RuntimeReport := {SafeMode: true,
                MappingCount: mappings.Length, RegistrationCount: 0}
            return this.RuntimeReport
        }
        this.RuntimeReport := this.Runtime.ApplyMappings(mappings)
        return this.RuntimeReport
    }

    ChooseExportRulePackage(*) {
        suggested := A_Desktop "\key-mouse-remapper-assistant-rules-"
            . FormatTime(, "yyyyMMdd-HHmmss") ".json"
        filePath := FileSelect("S16", suggested, Tr("导出规则包"),
            "Keyboard & Mouse Remapper Assistant package (*.json)")
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
        this.TraceEvent("repository", "package_exported", {
            Outcome: "ok", Detail: result.Path,
            Data: Map("rules", result.Rules, "digest", result.Digest)})
        return result
    }

    ChooseImportRulePackage(ownerWindow := "", *) {
        filePath := FileSelect("1", "", Tr("导入规则包"),
            "Keyboard & Mouse Remapper Assistant package (*.json)")
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
        if IsObject(this.PackageImportPreview)
            try this.PackageImportPreview.Dispose(false)
        previewOwner := IsObject(ownerWindow) ? ownerWindow : this.Window
        try {
            this.PackageImportPreview := RulePackageImportWindow(previewOwner,
                filePath, package, collisionPolicy)
            return this.PackageImportPreview.Show()
        } catch as previewError {
            this.PackageImportPreview := ""
            this.Window.SetStatus(Tr("规则包导入失败：{1}",
                previewError.Message), true)
            return false
        }
    }

    CompleteRulePackageImport(filePath, package, collisionPolicy,
            selectedRuleIds) {
        action := this.CreateHistoryAction("import-package", filePath,
            ["managed"])
        try mappingLease := CrossProcessWriteLock.Acquire(
            this.Repository.ScriptPath)
        catch as lockError {
            this.Window.SetStatus(Tr("规则包导入失败：{1}",
                lockError.Message), true)
            return false
        }
        try {
            beforeMapping := this.Repository.ReadRegionBody()
        } catch as snapshotError {
            mappingLease.Release()
            this.Window.SetStatus(Tr("规则包导入失败：{1}",
                snapshotError.Message), true)
            return false
        }
        try {
            result := this.PackageService.ImportPackage(package,
                this.Repository, collisionPolicy, selectedRuleIds)
            afterMapping := this.Repository.ReadRegionBody()
            this.ApplyManagedRulesHot()
            this.History.Commit("mapping", beforeMapping, afterMapping, action)
        } catch as importError {
            rollbackFailure := this.RestoreMappingState(beforeMapping)
            statusMessage := rollbackFailure != ""
                ? Tr("规则包导入失败，且回滚失败：{1}",
                    importError.Message "；" rollbackFailure)
                : Tr("规则包导入失败：{1}", importError.Message)
            this.Window.SetStatus(statusMessage, true)
            return false
        } finally mappingLease.Release()
        this.RefreshMappingRows()
        this.Window.SetStatus(Tr("规则包导入完成：新增 {1}，替换 {2}，"
            . "重命名 {3}，跳过 {4}。", result.Imported,
            result.Replaced, result.Renamed, result.Skipped))
        return result
    }

    OnRulePackageImportClosed(previewWindow) {
        if IsObject(this.PackageImportPreview)
                && this.PackageImportPreview == previewWindow
            this.PackageImportPreview := ""
    }

    RestoreMappingState(mappingState) {
        failures := []
        try {
            currentMapping := this.Repository.ReadRegionBody()
            if currentMapping != mappingState
                this.Repository.WriteRegionBody(mappingState,
                    currentMapping)
        } catch as mappingRestoreError {
            failures.Push("映射代码回滚失败：" mappingRestoreError.Message)
        }
        try this.ApplyManagedRulesHot()
        catch as runtimeRestoreError
            failures.Push("托管运行时回滚失败：" runtimeRestoreError.Message)
        return this.JoinFailureMessages(failures)
    }

    JoinFailureMessages(failures) {
        message := ""
        for failure in failures
            message .= (message == "" ? "" : "；") failure
        return message
    }

    RefreshMappingRows(preferredId := "") {
        try mappings := this.Repository.Load()
        catch
            return false
        this.MappingCount := mappings.Length
        return this.Window.ReplaceRows(mappings, preferredId)
    }

    TraceEvent(category, eventName, fields := "") {
        try return this.Trace.Record(category, eventName, fields)
        catch
            return false
    }

    OnRawInputEvent(unifiedEvent) {
        if Type(unifiedEvent) != "Map" || !unifiedEvent.Has("identity")
            return false
        if !RawInputObservationPolicy.ShouldForwardToGui(unifiedEvent,
                this.RawObservationDepth > 0)
            return false
        try this.Capture.ObserveRawInputEvent(unifiedEvent)
        identity := unifiedEvent["identity"]
        origin := unifiedEvent["origin"]
        eventName := origin == "raw-input-device"
            ? "raw_device_" unifiedEvent["phase"] : "raw_input"
        if origin == "raw-input-service" && unifiedEvent.Has("metadata")
                && unifiedEvent["metadata"].Has("service_event")
            eventName := unifiedEvent["metadata"]["service_event"]
        detail := this.FormatRawInputDetail(unifiedEvent)
        return this.TraceEvent("input", eventName, {
            Source: identity["name"], Outcome: unifiedEvent["phase"],
            Detail: detail, Data: unifiedEvent})
    }

    FormatRawInputDetail(unifiedEvent) {
        identity := unifiedEvent["identity"]
        parts := []
        if identity["vk_hex"] != ""
            parts.Push("VK " identity["vk_hex"])
        if identity["sc_hex"] != ""
            parts.Push("SC " identity["sc_hex"])
        if identity["device_id"] != ""
            parts.Push(identity["device_id"])
        if unifiedEvent.Has("metadata") {
            metadata := unifiedEvent["metadata"]
            if metadata.Has("delta_x") || metadata.Has("delta_y")
                parts.Push("Δ " (metadata.Has("delta_x")
                    ? metadata["delta_x"] : 0) ", "
                    . (metadata.Has("delta_y") ? metadata["delta_y"] : 0))
            if metadata.Has("device")
                    && metadata["device"].Has("path")
                    && metadata["device"]["path"] != ""
                parts.Push(metadata["device"]["path"])
        }
        return this.JoinFailureMessages(parts)
    }

    GetInputDevices() {
        try return this.RawInput.GetDevices()
        catch
            return []
    }

    CreateDiagnosticPreview() {
        settings := Map(
            "theme", this.Settings.Theme,
            "ui_language", this.Settings.UiLanguage,
            "ui_font", this.Settings.UiFont,
                "input_backend", "raw-input",
            "event_buffer_capacity", this.Settings.EventBufferCapacity,
            "event_auto_scroll", JsonBoolean(
                this.Settings.EventViewerAutoScroll))
        context := Map(
            "application", Map(
                "name", "Keyboard & Mouse Remapper Assistant",
                "version", ReadApplicationVersion(),
                "script_path", A_ScriptFullPath,
                "compiled", JsonBoolean(A_IsCompiled),
                "administrator", JsonBoolean(A_IsAdmin)),
            "runtime", Map("autohotkey", A_AhkVersion,
                "architecture", A_PtrSize == 8 ? "x64" : "x86"),
            "windows", Map("version", A_OSVersion,
                "language", A_Language),
            "settings", settings,
            "backend", Map(
                "capabilities", this.Runtime.Backend.GetCapabilities(),
                "health", this.Runtime.Backend.HealthCheck()),
            "recovery", this.GetRecoveryDiagnosticContext(),
            "devices", this.GetInputDevices())
        entries := []
        for entry in this.Trace.Snapshot()
            entries.Push(this.Trace.EntryToMap(entry))
        return this.Diagnostics.CreatePreview(context, entries)
    }

    GetRecoveryDiagnosticContext() {
        persistentEntries := []
        persistentReadError := ""
        try persistentEntries := this.CrashRecovery.CreateDiagnosticSummary()
        catch as diagnosticReadError
            persistentReadError := diagnosticReadError.Message
        return Map(
            "safe_mode", JsonBoolean(this.SafeMode),
            "consecutive_failures",
                this.StartupState.ConsecutiveFailures,
            "startup_cleanup", Map(
                "removed_count", this.StartupCleanupReport.Removed.Length,
                "skipped_recent_count",
                    this.StartupCleanupReport.SkippedRecent.Length,
                "failure_count",
                    this.StartupCleanupReport.Failures.Length,
                "error", this.GetDiagnosticTextSignature(
                    this.StartupCleanupError)),
            "persistent_entries", persistentEntries,
            "persistent_read_error", this.GetDiagnosticTextSignature(
                persistentReadError))
    }

    GetDiagnosticTextSignature(text) {
        text := String(text)
        return Map("length", StrLen(text), "sha256_prefix",
            text == "" ? "" : SubStr(Sha256.HexText(text), 1, 16))
    }

    ExportDiagnosticPreview(preview, filePath) {
        return this.Diagnostics.ExportPreview(preview, filePath)
    }

    BeginRawObservation() {
        if this.RawObservationDepth > 0 {
            this.RawObservationDepth++
            return true
        }
        scriptWasSuspended := !!A_IsSuspended
        backendWasSuspended := false
        try backendWasSuspended := !!this.Runtime.Backend.Suspended
        state := {ScriptWasSuspended: scriptWasSuspended,
            BackendWasSuspended: backendWasSuspended,
            ScriptChanged: false, BackendChanged: false,
            FullObservationChanged: false}
        try {
            if !scriptWasSuspended {
                Suspend(true)
                state.ScriptChanged := true
            }
            if !backendWasSuspended {
                this.Runtime.Backend.Suspend()
                state.BackendChanged := true
            }
            if this.UseWorkerProcesses {
                this.ProcessController.SetRawObservation(true)
                state.FullObservationChanged := true
            }
        } catch as observationError {
            if state.FullObservationChanged
                try this.ProcessController.SetRawObservation(false)
            if state.BackendChanged
                try this.Runtime.Backend.Resume()
            if state.ScriptChanged
                try Suspend(false)
            throw observationError
        }
        this.RawObservationState := state
        this.RawObservationDepth := 1
        this.TraceEvent("system", "raw_observation_started", {
            Outcome: "active", Data: Map(
                "script_was_suspended", JsonBoolean(scriptWasSuspended),
                "backend_was_suspended", JsonBoolean(backendWasSuspended))})
        return true
    }

    EndRawObservation(force := false) {
        if this.RawObservationDepth < 1
            return false
        if !force && this.RawObservationDepth > 1 {
            this.RawObservationDepth--
            return true
        }
        state := this.RawObservationState
        failures := []
        if IsObject(state) && state.FullObservationChanged {
            try this.ProcessController.SetRawObservation(false)
            catch as forwardingStopError
                failures.Push(forwardingStopError.Message)
        }
        if IsObject(state) && state.BackendChanged {
            try this.Runtime.Backend.Resume()
            catch as backendResumeError
                failures.Push(backendResumeError.Message)
        }
        if IsObject(state) && state.ScriptChanged {
            try Suspend(false)
            catch as scriptResumeError
                failures.Push(scriptResumeError.Message)
        }
        this.RawObservationDepth := 0
        this.RawObservationState := ""
        outcome := failures.Length ? "error" : "restored"
        this.TraceEvent("system", "raw_observation_stopped", {
            Outcome: outcome,
            Detail: failures.Length ? this.JoinFailureMessages(failures) : ""})
        if failures.Length
            throw Error("原始观察模式恢复失败："
                this.JoinFailureMessages(failures))
        return true
    }

    OpenEventViewer(*) {
        if IsObject(this.EventViewer) {
            this.EventViewer.Activate()
            return true
        }
        try {
            this.EventViewer := EventViewerWindow(this.Window)
            this.EventViewer.Show()
            this.TraceEvent("ui", "event_viewer_opened", {Outcome: "ok"})
            return true
        } catch as viewerError {
            this.EventViewer := ""
            this.Window.SetStatus(Tr("无法打开事件查看器：{1}",
                viewerError.Message), true)
            return false
        }
    }

    OnEventViewerClosed(viewer) {
        if IsObject(this.EventViewer) && this.EventViewer == viewer
            this.EventViewer := ""
    }

    OpenHelpInfo(*) {
        if IsObject(this.SupportInfo) {
            this.SupportInfo.Activate()
            return true
        }
        try this.Toast.Hide()
        try {
            this.SupportInfo := SupportInfoWindow(this.Window)
            this.SupportInfo.Show()
            this.TraceEvent("ui", "help_info_opened", {Outcome: "ok"})
            return true
        } catch as supportError {
            this.SupportInfo := ""
            this.Window.SetStatus(Tr("无法打开帮助信息：{1}",
                supportError.Message), true)
            return false
        }
    }

    OnSupportInfoClosed(supportInfo) {
        if IsObject(this.SupportInfo) && this.SupportInfo == supportInfo
            this.SupportInfo := ""
    }

    OpenHelp(*) {
        if IsObject(this.Help) {
            this.Help.Activate()
            return true
        }
        try this.Toast.Hide()
        try {
            this.Help := HelpWindow(this.Window)
            this.Help.Show()
            this.TraceEvent("ui", "help_opened", {Outcome: "ok"})
            return true
        } catch as helpError {
            this.Help := ""
            this.Window.SetStatus(Tr("无法打开使用说明：{1}",
                helpError.Message), true)
            return false
        }
    }

    OnHelpClosed(helpWindow) {
        if IsObject(this.Help) && this.Help == helpWindow
            this.Help := ""
    }

    OpenDonation(*) {
        if IsObject(this.Donation) {
            this.Donation.Activate()
            return true
        }
        try this.Toast.Hide()
        try {
            this.Donation := DonationWindow(this.Window)
            this.Donation.Show()
            this.TraceEvent("ui", "donation_opened", {Outcome: "ok"})
            return true
        } catch as donationError {
            this.Donation := ""
            this.Window.SetStatus(Tr("无法打开捐赠窗口：{1}",
                donationError.Message), true)
            return false
        }
    }

    OnDonationClosed(donationWindow) {
        if IsObject(this.Donation) && this.Donation == donationWindow
            this.Donation := ""
    }

    OpenSettings(*) {
        if IsObject(this.SettingsWindow) {
            this.SettingsWindow.Activate()
            return
        }
        try this.Toast.Hide()
        try {
            this.SettingsWindow := SettingsWindow(this.Window)
            this.SettingsWindow.Show()
        } catch as settingsError {
            this.SettingsWindow := ""
            this.Window.SetStatus(Tr("无法打开设置：{1}",
                settingsError.Message), true)
        }
    }

    OnSettingsClosed(settingsWindow) {
        if IsObject(this.SettingsWindow) && this.SettingsWindow == settingsWindow
            this.SettingsWindow := ""
    }

    SaveSettings(candidate) {
        oldSettings := this.Settings
        candidate := this.CompleteSettingsCandidate(candidate)
        try beforeState := this.SettingsService.GetSnapshot()
        catch as snapshotError {
            this.Window.SetStatus(Tr("设置未保存：{1}",
                snapshotError.Message), true)
            return false
        }
        try normalized := this.SettingsService.Save(candidate, beforeState)
        catch as settingsError {
            this.Window.SetStatus(Tr("设置未保存：{1}",
                settingsError.Message), true)
            return false
        }
        afterState := this.SettingsService.GetSnapshot()
        if beforeState == afterState {
            this.Window.SetStatus(Tr("设置没有变化。"))
            return true
        }
        fields := this.GetSettingsHistoryFields(this.Settings, normalized)
        try this.ApplySettingsHot(normalized)
        catch as displayError {
            rollbackFailure := this.RollbackSettingsChange(beforeState,
                afterState, oldSettings)
            detail := displayError.Message
            if rollbackFailure != ""
                detail .= "；设置回滚不完整：" rollbackFailure
            this.Window.SetStatus(Tr("设置未保存：{1}", detail), true)
            return false
        }
        try this.History.Commit("settings", beforeState, afterState,
            this.CreateHistoryAction("settings", "", fields))
        catch as historyError {
            rollbackFailure := this.RollbackSettingsChange(beforeState,
                afterState, oldSettings)
            detail := rollbackFailure == ""
                ? ("操作历史写入失败，本次设置修改已回滚："
                    . historyError.Message)
                : ("操作历史写入失败，且设置回滚不完整："
                    . historyError.Message "；" rollbackFailure)
            this.Window.SetStatus(Tr("设置未保存：{1}", detail), true)
            return false
        }
        message := Tr("设置已保存并已应用。")
        this.Window.SetStatus(message)
        return true
    }

    CompleteSettingsCandidate(candidate) {
        merged := {
            UiLanguage: this.Settings.UiLanguage,
            UiFont: this.Settings.UiFont,
            Theme: this.Settings.Theme,
            EscapeCancelsRecording: this.Settings.EscapeCancelsRecording,
            EventBufferCapacity: this.Settings.EventBufferCapacity,
            EventViewerAutoScroll: this.Settings.EventViewerAutoScroll
        }
        if !IsObject(candidate)
            return merged
        for propertyName in ["UiLanguage", "UiFont", "Theme",
                "EscapeCancelsRecording", "EventBufferCapacity",
                "EventViewerAutoScroll"] {
            if candidate.HasOwnProp(propertyName)
                merged.%propertyName% := candidate.%propertyName%
        }
        return merged
    }

    RollbackSettingsChange(beforeState, afterState, oldSettings) {
        failures := []
        try this.SettingsService.WriteSnapshot(beforeState, afterState)
        catch as settingsRollbackError
            failures.Push("设置文件回滚失败：" settingsRollbackError.Message)
        try this.ApplySettingsHot(oldSettings)
        catch as displayRollbackError
            failures.Push("界面回滚失败：" displayRollbackError.Message)
        message := ""
        for failure in failures
            message .= (message == "" ? "" : "；") failure
        return message
    }

    ApplySettingsHot(settings) {
        previousSettings := this.Settings
        traceState := this.Trace.CaptureState()
        previousCritical := A_IsCritical
        Critical("On")
        try {
            this.ApplySettingsState(settings)
            return true
        } catch as settingsError {
            rollbackError := ""
            try {
                this.Trace.RestoreState(traceState)
                this.ApplySettingsState(previousSettings)
            } catch as caughtRollbackError {
                rollbackError := caughtRollbackError
            }
            if IsObject(rollbackError)
                throw Error("设置热应用失败，且回滚失败："
                    settingsError.Message "；" rollbackError.Message)
            throw settingsError
        } finally Critical(previousCritical ? previousCritical : "Off")
    }

    ApplySettingsState(settings) {
        LocalizationService.Configure(settings.UiLanguage, settings.UiFont)
        UiThemeService.Configure(settings.Theme)
        this.Settings := settings
        this.Trace.SetCapacity(settings.EventBufferCapacity)
        this.Window.ApplyAppearance()
        if IsObject(this.Window.BlockEditor)
            this.Window.BlockEditor.ApplyAppearance()
        if IsObject(this.EventViewer) {
            this.EventViewer.ApplyAppearance()
            this.EventViewer.ApplyBehaviorSettings()
        }
        if IsObject(this.SupportInfo)
            this.SupportInfo.ApplyAppearance()
        if IsObject(this.Help)
            this.Help.ApplyAppearance()
        if IsObject(this.Donation)
            this.Donation.ApplyAppearance()
        this.Toast.RefreshAppearance()
        this.ConfigureTray()
        return true
    }

    CreateHistoryAction(kind, target := "", fields := "") {
        normalizedFields := []
        if Type(fields) == "Array" {
            for field in fields
                normalizedFields.Push(String(field))
        }
        return {Kind: String(kind), Target: String(target),
            Fields: normalizedFields}
    }

    GetSettingsHistoryFields(beforeSettings, afterSettings) {
        fields := []
        for field in [
            {Property: "UiLanguage", Key: "ui-language"},
            {Property: "UiFont", Key: "ui-font"},
            {Property: "Theme", Key: "theme"},
            {Property: "EscapeCancelsRecording", Key: "escape-cancel"},
            {Property: "EventBufferCapacity", Key: "event-capacity"},
            {Property: "EventViewerAutoScroll", Key: "event-auto-scroll"}
        ] {
            propertyName := field.Property
            if beforeSettings.%propertyName% != afterSettings.%propertyName%
                fields.Push(field.Key)
        }
        return fields
    }

    FormatHistoryAction(action) {
        action := this.History.NormalizeAction(action)
        if action.Kind == "legacy"
            return action.Target
        targetText := action.Target
        switch action.Kind {
            case "add": label := Tr("新增映射")
            case "delete": label := Tr("删除映射")
            case "reorder": label := Tr("调整映射顺序")
            case "pause": label := Tr("暂停映射")
            case "resume": label := Tr("恢复映射")
            case "edit-code": label := Tr("编辑映射代码")
            case "import-package": label := Tr("导入规则包")
            case "settings":
                label := Tr("设置")
                fieldLabels := []
                for fieldKey in action.Fields {
                    switch fieldKey {
                        case "ui-language": fieldLabels.Push(Tr("界面语言"))
                        case "ui-font": fieldLabels.Push(Tr("界面内容字体"))
                        case "theme": fieldLabels.Push(Tr("主题"))
                        case "escape-cancel":
                            fieldLabels.Push(Tr("Esc 取消录制"))
                        case "event-capacity":
                            fieldLabels.Push(Tr("事件缓冲区容量"))
                        case "event-auto-scroll":
                            fieldLabels.Push(Tr("事件自动跟随"))
                    }
                }
                language := LocalizationService.GetLanguage()
                separator := LocalizationService.IsChinese()
                    || language == "ja-JP" ? "、" : ", "
                targetText := ""
                for index, fieldLabel in fieldLabels
                    targetText .= (index > 1 ? separator : "") fieldLabel
            default: label := Tr("映射配置")
        }
        return targetText != "" ? label "：" targetText : label
    }

    FormatHistoryResult(action, isUndo) {
        detail := this.FormatHistoryAction(action)
        return isUndo ? Tr("已撤销：{1}", detail) : Tr("已重做：{1}", detail)
    }

    BuildHistoryNotification(entry, isUndo) {
        action := entry.HasOwnProp("Action")
            ? entry.Action : this.History.NormalizeAction(entry.Label)
        return "H2|" (isUndo ? "U" : "R") "|"
            . this.History.SerializeAction(action)
    }

    ParseHistoryNotification(payload) {
        payload := String(payload)
        if SubStr(payload, 1, 3) != "H2|" || StrLen(payload) < 6
            return payload
        direction := SubStr(payload, 4, 1)
        if (direction != "U" && direction != "R")
            || SubStr(payload, 5, 1) != "|"
            return payload
        try action := this.History.DeserializeAction(SubStr(payload, 6))
        catch
            return payload
        return this.FormatHistoryResult(action, direction == "U")
    }

    PerformUndo(*) {
        try applied := this.History.Undo(
            ObjBindMethod(this, "ApplyHistoryState"), &entry)
        catch as historyError {
            this.Window.SetStatus(Tr("撤销失败：{1}", historyError.Message), true)
            return false
        }
        if !applied
            return false
        if entry.Kind == "settings"
                || (entry.Kind == "mapping"
                    && this.HistoryActionHasField(entry.Action, "managed")) {
            if entry.Kind == "mapping"
                this.RefreshMappingRows()
            this.ShowToast(this.FormatHistoryResult(entry.Action, true))
            return true
        }
        this.NotifyAfterReload(this.BuildHistoryNotification(entry, true))
        this.ScheduleReload()
        return true
    }

    PerformRedo(*) {
        try applied := this.History.Redo(
            ObjBindMethod(this, "ApplyHistoryState"), &entry)
        catch as historyError {
            this.Window.SetStatus(Tr("重做失败：{1}", historyError.Message), true)
            return false
        }
        if !applied
            return false
        if entry.Kind == "settings"
                || (entry.Kind == "mapping"
                    && this.HistoryActionHasField(entry.Action, "managed")) {
            if entry.Kind == "mapping"
                this.RefreshMappingRows()
            this.ShowToast(this.FormatHistoryResult(entry.Action, false))
            return true
        }
        this.NotifyAfterReload(this.BuildHistoryNotification(entry, false))
        this.ScheduleReload()
        return true
    }

    ApplyHistoryState(desiredState, expectedState, kind) {
        if kind == "mapping" {
            currentState := this.Repository.ReadRegionBody()
            if currentState != expectedState
                throw Error("映射代码区域已被其他操作修改，旧历史没有覆盖当前内容。")
            this.Repository.WriteRegionBody(desiredState, expectedState)
            try this.ApplyManagedRulesHot()
            catch as runtimeError {
                rollbackError := ""
                try {
                    this.Repository.WriteRegionBody(expectedState,
                        desiredState)
                    this.ApplyManagedRulesHot()
                } catch as caughtRollbackError {
                    rollbackError := caughtRollbackError
                }
                if IsObject(rollbackError)
                    throw Error("历史映射热应用失败，且回滚失败："
                        runtimeError.Message "；" rollbackError.Message)
                throw runtimeError
            }
            return
        }
        if kind == "settings" {
            currentState := this.SettingsService.GetSnapshot()
            if currentState != expectedState
                throw Error("界面设置已被其他操作修改，旧历史没有覆盖当前内容。")
            this.SettingsService.WriteSnapshot(desiredState, expectedState)
            try this.ApplySettingsHot(this.SettingsService.Load())
            catch as displayError {
                rollbackError := ""
                try this.SettingsService.WriteSnapshot(expectedState,
                    desiredState)
                catch as caughtRollbackError
                    rollbackError := caughtRollbackError
                if IsObject(rollbackError)
                    throw Error("历史设置热应用失败，且设置文件回滚失败："
                        displayError.Message "；" rollbackError.Message)
                throw displayError
            }
            return
        }
        throw Error("无法识别历史记录类型：" kind)
    }

    HistoryActionHasField(action, expectedField) {
        action := this.History.NormalizeAction(action)
        for field in action.Fields {
            if field == expectedField
                return true
        }
        return false
    }

    OnGlobalKeyDown(wParam, lParam, msg, hwnd) {
        if !this.IsGlobalModifierDown("Ctrl")
            return
        controlClass := ""
        try controlClass := WinGetClass("ahk_id " hwnd)
        if RegExMatch(controlClass, "i)(?:^Edit$|RichEdit)")
            return
        rootHwnd := DllCall("user32\GetAncestor", "Ptr", hwnd, "UInt", 2,
            "Ptr")
        rootClass := ""
        try rootClass := WinGetClass("ahk_id " rootHwnd)
        if rootClass != "AutoHotkeyGUI"
            return
        if wParam == 0x5A {
            if this.IsGlobalModifierDown("Shift")
                this.PerformRedo()
            else
                this.PerformUndo()
            return 0
        }
        if wParam == 0x59 {
            this.PerformRedo()
            return 0
        }
    }

    IsGlobalModifierDown(keyName) {
        ; WM_KEYDOWN already proves that the target GUI received input. Use the
        ; logical modifier state so injected, remote and physical input share
        ; the same undo/redo path.
        return GetKeyState(keyName)
    }

    ShowPendingToast(*) {
        payload := this.History.ConsumePendingNotification()
        if payload != ""
            this.ShowToast(this.ParseHistoryNotification(payload))
    }

    NotifyAfterReload(text) {
        try return this.History.SetPendingNotification(text)
        catch as notificationError {
            this.Window.SetStatus("操作已完成，但结果气泡无法跨热重载保存："
                notificationError.Message, true)
            return false
        }
    }

    ShowToast(text) {
        if Trim(String(text)) != ""
            return this.Toast.Show(text)
        return false
    }

    GetSummaryText() {
        return Tr("{1} 条重映射正在生效 · 当前为脚本代码顺序",
            this.MappingCount)
    }

    OnCaptureCompleted(role, capture) {
        this.TraceEvent("input", "capture_completed", {
            Source: capture.RawDisplay, Outcome: role,
            Detail: capture.KeyInfo})
        this.Window.AcceptCapture(role, capture)
    }

    OnCapturePreview(role, capture) {
        this.TraceEvent("input", "capture_preview", {
            Source: capture.RawDisplay, Outcome: role,
            Detail: capture.Detail})
        previousCritical := A_IsCritical
        Critical("On")
        try {
            if !this.Capture.Active || this.Capture.Role != role
                return false
            pendingCapture := this.Capture.PendingCapture
            if !IsObject(pendingCapture) || !IsObject(capture)
                    || ObjPtr(pendingCapture) != ObjPtr(capture)
                return false
            this.Window.PreviewCapture(role, capture)
            return true
        } finally Critical(previousCritical ? previousCritical : "Off")
    }

    OnCaptureCancelled(*) {
        this.TraceEvent("input", "capture_cancelled", {Outcome: "cancelled"})
        this.Window.CancelCaptureState()
    }

    ShouldCancelCaptureForPointer(*) {
        return IsObject(this.Window)
            && this.Window.IsPointerOverButton()
    }

    PrepareCapturePointerCancellation(*) {
        return IsObject(this.Window)
            && this.Window.SuppressNextPointerButtonActivation()
    }

    FinalizeCapturePointerCancellation(*) {
        return IsObject(this.Window)
            && this.Window.FinalizePointerButtonCancellation()
    }

    OnAppCommand(wParam, lParam, msg, hwnd) {
        if !this.Capture.Active
            return
        command := (lParam >> 16) & 0x0FFF
        if this.Capture.CompleteAppCommand(command)
            return 1
    }

    OnSystemCommand(wParam, lParam, msg, hwnd) {
        command := wParam & 0xFFF0
        if command == Win32.SC_MINIMIZE
            && WindowHierarchy.MinimizeChildIndependently(hwnd)
            return 0
        if command == Win32.SC_RESTORE || command == Win32.SC_MAXIMIZE
            WindowHierarchy.PrepareChildRestore(hwnd)
    }

    OnPowerEvent(wParam, lParam, msg, hwnd) {
        if wParam == 0x4 {
            if this.PowerSuspended
                return true
            SetTimer(this.PowerRecoveryTimer, 0)
            this.PowerSuspended := true
            if this.UseWorkerProcesses {
                try this.ProcessController.HandlePowerTransition("suspend")
            } else
                this.PrepareSingleProcessSuspend()
            this.TraceEvent("system", "power_suspend", {Outcome: "prepared"})
            return true
        }
        if wParam == 0x12 || wParam == 0x7 {
            if this.UseWorkerProcesses
                try this.ProcessController.HandlePowerTransition("resume")
            SetTimer(this.PowerRecoveryTimer, -this.WakeUpDelay)
            return true
        }
    }

    RegisterSessionNotifications() {
        if this.SessionNotificationsRegistered
            return true
        if this.RegisterSessionNotificationNative(this.Window.Gui.Hwnd) {
            this.SessionNotificationsRegistered := true
            return true
        }
        this.TraceEvent("system", "session_notification_registration_failed",
            {Outcome: "error", Detail: "Win32 " A_LastError})
        return false
    }

    UnregisterSessionNotifications() {
        if !this.SessionNotificationsRegistered
            return false
        if this.UnregisterSessionNotificationNative(this.Window.Gui.Hwnd) {
            this.SessionNotificationsRegistered := false
            return true
        }
        this.TraceEvent("system", "session_notification_unregistration_failed",
            {Outcome: "error", Detail: "Win32 " A_LastError})
        return false
    }

    RegisterSessionNotificationNative(hwnd) {
        return DllCall("wtsapi32\WTSRegisterSessionNotification", "Ptr",
            hwnd, "UInt", 0, "Int") != 0
    }

    UnregisterSessionNotificationNative(hwnd) {
        return DllCall("wtsapi32\WTSUnRegisterSessionNotification", "Ptr",
            hwnd, "Int") != 0
    }

    RegisterApplicationCallbacks() {
        if this.ApplicationCallbacksRegistered
            return true
        if this.MessageRegistrations.Length || this.ExitCallbackRegistered {
            if !this.UnregisterApplicationCallbacks()
                throw Error("无法清理先前未完成的应用回调注册。")
        }
        registrations := [
            {Message: 0x0218, Callback: this.PowerCallback},
            {Message: 0x02B1, Callback: this.SessionChangeCallback},
            {Message: 0x0319, Callback: this.AppCommandCallback},
            {Message: 0x0112, Callback: this.SystemCommandCallback},
            {Message: 0x0100, Callback: this.KeyDownCallback},
            {Message: Win32.WM_SETTINGCHANGE,
                Callback: this.SettingChangeCallback},
            {Message: Win32.WM_MOVE, Callback: this.WindowMoveCallback}
        ]
        try {
            for registration in registrations {
                OnMessage(registration.Message, registration.Callback)
                this.MessageRegistrations.Push(registration)
            }
            OnExit(this.ExitCallback)
            this.ExitCallbackRegistered := true
            this.ApplicationCallbacksRegistered := true
            return true
        } catch as registrationError {
            this.UnregisterApplicationCallbacks()
            throw registrationError
        }
    }

    UnregisterApplicationCallbacks() {
        succeeded := true
        if this.ExitCallbackRegistered {
            try {
                OnExit(this.ExitCallback, 0)
                this.ExitCallbackRegistered := false
            } catch {
                succeeded := false
            }
        }
        remaining := []
        Loop this.MessageRegistrations.Length {
            registration := this.MessageRegistrations[
                this.MessageRegistrations.Length - A_Index + 1]
            try OnMessage(registration.Message, registration.Callback, 0)
            catch {
                remaining.InsertAt(1, registration)
                succeeded := false
            }
        }
        this.MessageRegistrations := remaining
        if succeeded && !this.ExitCallbackRegistered && !remaining.Length
            this.ApplicationCallbacksRegistered := false
        return succeeded && !this.ExitCallbackRegistered && !remaining.Length
    }

    OnSessionChange(wParam, sessionId, msg, hwnd) {
        if this.ShuttingDown || hwnd != this.Window.Gui.Hwnd
            return false
        eventName := this.SessionChangeEventName(wParam)
        session := this.ContextService.GetSessionState()
        this.TraceEvent("system", eventName, {
            Source: String(sessionId),
            Outcome: "observed",
            Data: Map(
                "notification", Integer(wParam),
                "session_id", Integer(sessionId),
                "state", session["state"],
                "locked", RuleSpec.Clone(session["locked"]),
                "lock_known", RuleSpec.Clone(session["lock_known"]),
                "remote", RuleSpec.Clone(session["remote"]),
                "protocol", session["protocol"])})
        return true
    }

    SessionChangeEventName(notification) {
        switch notification {
            case 1: return "session_console_connect"
            case 2: return "session_console_disconnect"
            case 3: return "session_remote_connect"
            case 4: return "session_remote_disconnect"
            case 5: return "session_logon"
            case 6: return "session_logoff"
            case 7: return "session_lock"
            case 8: return "session_unlock"
            case 9: return "session_remote_control"
            case 10: return "session_create"
            case 11: return "session_terminate"
        }
        return "session_change_unknown"
    }

    PrepareSingleProcessSuspend() {
        if !this.PowerSuspended || this.SafeMode
            return false
        this.PowerScriptWasSuspended := !!A_IsSuspended
        this.PowerBackendWasSuspended := !!this.Runtime.Backend.Suspended
        try this.Capture.Stop(false)
        try this.Runtime.ResetActiveState("system_suspend")
        if !this.PowerBackendWasSuspended
            try this.Runtime.Backend.Suspend()
        try this.RawInput.Shutdown()
        Suspend(true)
        return true
    }

    PerformPowerRecovery(*) {
        if this.ShuttingDown || this.SafeMode
            return false
        try {
            if this.UseWorkerProcesses {
                result := this.ProcessController.RecoverAfterResume()
                if result.Has("input") && result["input"].Has("mapping_count")
                    this.MappingCount := result["input"]["mapping_count"]
            } else {
                if this.RawInput.Started
                    this.RawInput.RecoverAfterResume()
                else
                    this.RawInput.Start()
                this.ApplyManagedRulesHot()
                if this.PowerBackendWasSuspended {
                    if !this.Runtime.Backend.Suspended
                        this.Runtime.Backend.Suspend()
                } else if this.Runtime.Backend.Suspended
                    this.Runtime.Backend.Resume()
                Suspend(this.PowerScriptWasSuspended)
            }
            this.PowerSuspended := false
            this.Window.SetStatus(this.GetSummaryText())
            this.TraceEvent("system", "power_resume", {Outcome: "recovered",
                Data: Map("devices", this.GetInputDevices())})
            return true
        } catch as recoveryError {
            this.TraceEvent("system", "power_resume_failed", {
                Outcome: "error", Detail: recoveryError.Message})
            this.Window.SetStatus("唤醒后输入恢复失败："
                recoveryError.Message, true)
            if this.UseWorkerProcesses
                this.ProcessController.HandleWorkerFailure("",
                    "唤醒恢复失败：" recoveryError.Message)
            return false
        }
    }

    OnSystemSettingChange(*) {
        if UiThemeService.GetRequestedTheme() == "auto"
            SetTimer(this.SystemThemeTimer, -250)
    }

    ApplySystemThemeChange(*) {
        if this.ShuttingDown || !UiThemeService.HandleSystemSettingChange()
            return false
        this.Window.ApplyAppearance()
        if IsObject(this.Window.BlockEditor)
            this.Window.BlockEditor.ApplyAppearance()
        if IsObject(this.EventViewer)
            this.EventViewer.ApplyAppearance()
        if IsObject(this.SupportInfo)
            this.SupportInfo.ApplyAppearance()
        if IsObject(this.Help)
            this.Help.ApplyAppearance()
        if IsObject(this.Donation)
            this.Donation.ApplyAppearance()
        this.Toast.RefreshAppearance()
        return true
    }

    OnWindowMove(wParam, lParam, msg, hwnd) {
        if !this.ShuttingDown && hwnd == this.Window.Gui.Hwnd
            try this.Toast.Reposition()
    }

    HandleExit(*) {
        try this.Shutdown()
        catch {
            ; Exit must proceed even if best-effort cleanup itself faults.
        }
        ; OnExit callbacks use a non-zero return value to cancel process exit.
        return 0
    }

    Shutdown(*) {
        if this.ShuttingDown
            return
        this.ShuttingDown := true
        shutdownFailures := []
        if !this.UnregisterApplicationCallbacks()
            shutdownFailures.Push(Map("component", "application_callbacks",
                "error", "应用消息或退出回调注销失败。"))
        this.TryShutdownComponent(shutdownFailures, "reload_timer",
            () => SetTimer(this.ReloadTimer, 0))
        this.TryShutdownComponent(shutdownFailures, "power_recovery_timer",
            () => SetTimer(this.PowerRecoveryTimer, 0))
        this.TryShutdownComponent(shutdownFailures, "system_theme_timer",
            () => SetTimer(this.SystemThemeTimer, 0))
        this.TryShutdownComponent(shutdownFailures, "control_poll_timer",
            () => SetTimer(this.ControlPollTimer, 0))
        this.TryShutdownComponent(shutdownFailures, "startup_stable_timer",
            () => SetTimer(this.StartupStableTimer, 0))
        this.ReloadPending := false
        if this.SessionNotificationsRegistered
                && !this.UnregisterSessionNotifications()
            shutdownFailures.Push(Map("component", "session_notifications",
                "error", "WTS 会话通知注销失败。"))
        try this.Capture.Stop(false)
        catch as captureShutdownError
            shutdownFailures.Push(Map("component", "capture",
                "error", captureShutdownError.Message))
        try this.EndRawObservation(true)
        catch as observationShutdownError
            shutdownFailures.Push(Map("component", "raw_observation",
                "error", observationShutdownError.Message))
        try this.RawInput.Shutdown()
        catch as rawInputShutdownError
            shutdownFailures.Push(Map("component", "raw_input",
                "error", rawInputShutdownError.Message))
        try this.Runtime.Shutdown()
        catch as runtimeShutdownError
            shutdownFailures.Push(Map("component", "runtime",
                "error", runtimeShutdownError.Message))
        remainingOutputKeys := 0
        try remainingOutputKeys := this.Runtime.OutputLedger.Keys.Count
        catch as outputInspectionError
            shutdownFailures.Push(Map("component", "output_ledger",
                "error", outputInspectionError.Message))
        if IsObject(this.SettingsWindow)
            this.TryShutdownComponent(shutdownFailures, "settings_window",
                ObjBindMethod(this.SettingsWindow, "Dispose", false))
        if IsObject(this.EventViewer)
            this.TryShutdownComponent(shutdownFailures, "event_viewer",
                ObjBindMethod(this.EventViewer, "Dispose"))
        if IsObject(this.SupportInfo)
            this.TryShutdownComponent(shutdownFailures, "support_window",
                ObjBindMethod(this.SupportInfo, "Dispose", false))
        if IsObject(this.Help)
            this.TryShutdownComponent(shutdownFailures, "help_window",
                ObjBindMethod(this.Help, "Dispose", false))
        if IsObject(this.Donation)
            this.TryShutdownComponent(shutdownFailures, "donation_window",
                ObjBindMethod(this.Donation, "Dispose", false))
        if IsObject(this.PackageImportPreview)
            this.TryShutdownComponent(shutdownFailures,
                "package_import_window",
                ObjBindMethod(this.PackageImportPreview, "Dispose", false))
        this.TryShutdownComponent(shutdownFailures, "toast_window",
            ObjBindMethod(this.Toast, "Dispose"))
        this.TryShutdownComponent(shutdownFailures, "mapping_window",
            ObjBindMethod(this.Window, "Dispose"))
        this.TryShutdownComponent(shutdownFailures, "accessibility",
            () => ControlAccessibilityService.Shutdown())
        this.TryShutdownComponent(shutdownFailures, "svg_renderer",
            () => this.SvgRenderer.Shutdown())
        this.TryShutdownComponent(shutdownFailures, "ui_fonts",
            () => LocalizationService.ShutdownUiFonts())
        if shutdownFailures.Length || remainingOutputKeys {
            try this.CrashRecovery.Record("shutdown_incomplete",
                "退出清理没有完整完成。", Map(
                    "remaining_output_keys", remainingOutputKeys,
                    "failures", shutdownFailures))
        } else if this.StartupSucceeded
            try this.Health.MarkClean()
        return !shutdownFailures.Length && !remainingOutputKeys
    }

    TryShutdownComponent(failures, component, callback) {
        try {
            callback.Call()
            return true
        } catch as shutdownError {
            failures.Push(Map("component", String(component),
                "error", shutdownError.Message))
            return false
        }
    }
}
