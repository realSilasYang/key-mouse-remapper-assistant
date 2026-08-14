class SystemIntegrationService {
    static TaskSource := "realSilasYang/key-mouse-remapper-assistant"
    static StableTaskName := "KeyMouseRemapperAssistant"
    static ApplicationUserModelId := "realSilasYang.KeyMouseRemapperAssistant"

    __New(applicationName := "") {
        this.ApplicationName := applicationName == ""
            ? Tr("键鼠重映射小助手") : String(applicationName)
        this.TaskName := SystemIntegrationService.StableTaskName
    }

    CreateApplicationShortcuts() {
        launch := this.GetApplicationLaunchSpec()
        paths := this.GetApplicationShortcutPaths()
        desktopPath := paths.Desktop
        programsPath := paths.Programs
        scriptPath := launch.EntryPath
        workingDirectory := this.GetApplicationWorkingDirectory(launch)
        iconPath := GetApplicationIconPath()
        extraArguments := launch.Arguments
        programsExisted := !!FileExist(programsPath)
        desktopExisted := !!FileExist(desktopPath)
        backups := []
        preserveBackups := false
        try {
            backups.Push(this.BackupShortcutFile(programsPath))
            backups.Push(this.BackupShortcutFile(desktopPath))
            if !this.CreateApplicationShortcutFile(programsPath, scriptPath,
                    workingDirectory, iconPath, launch.Executable,
                    launch.InterpreterPath, extraArguments)
                throw Error(programsPath)
            if !this.CreateApplicationShortcutFile(desktopPath, scriptPath,
                    workingDirectory, iconPath, launch.Executable,
                    launch.InterpreterPath, extraArguments)
                throw Error(desktopPath)
        } catch as shortcutError {
            rollbackErrors := this.RestoreShortcutBackups(backups)
            for backup in backups
                this.NotifyShellShortcutChanged(backup.Target,
                    backup.Existed)
            if rollbackErrors != "" {
                preserveBackups := true
                throw Error(shortcutError.Message "；回滚快捷方式失败："
                    rollbackErrors)
            }
            throw shortcutError
        } finally {
            if !preserveBackups
                this.DeleteShortcutBackups(backups)
        }
        this.NotifyShellShortcutChanged(programsPath, programsExisted)
        this.NotifyShellShortcutChanged(desktopPath, desktopExisted)
        return {Desktop: desktopPath, Programs: programsPath}
    }

    RepairApplicationShortcutIdentities(shortcutPaths := "",
            launch := "") {
        if !IsObject(shortcutPaths) {
            paths := this.GetApplicationShortcutPaths()
            shortcutPaths := [paths.Programs, paths.Desktop]
        }
        if !IsObject(launch)
            launch := this.GetApplicationLaunchSpec()
        workingDirectory := this.GetApplicationWorkingDirectory(launch)
        repaired := 0
        for shortcutPath in shortcutPaths {
            canonicalLaunch := this.ApplicationShortcutLaunchMatches(
                shortcutPath, launch.EntryPath, workingDirectory,
                launch.Executable, launch.InterpreterPath,
                launch.Arguments)
            legacyLaunch := this.LegacyApplicationShortcutLaunchMatches(
                shortcutPath, launch.EntryPath, workingDirectory,
                launch.Executable, launch.InterpreterPath,
                launch.Arguments)
            if !canonicalLaunch && !legacyLaunch
                continue
            if canonicalLaunch && this.ReadShortcutAppUserModelId(shortcutPath)
                == SystemIntegrationService.ApplicationUserModelId
                continue
            repairSuffix := ".identity-" ProcessExist() "-" A_TickCount
                . ".lnk"
            repairPath := shortcutPath repairSuffix
            arguments := this.BuildShortcutArguments(launch.Executable,
                launch.EntryPath, launch.Arguments)
            try {
                if !this.WriteApplicationShortcut(repairPath,
                        launch.EntryPath,
                        workingDirectory, arguments, this.ApplicationName,
                        GetApplicationIconPath(),
                        SystemIntegrationService.ApplicationUserModelId)
                    continue
                if !this.ApplicationShortcutMatches(repairPath,
                        launch.EntryPath, launch.Executable,
                        launch.InterpreterPath, launch.Arguments,
                        workingDirectory)
                    continue
                FileMove(repairPath, shortcutPath, true)
                this.NotifyShellShortcutChanged(shortcutPath, true)
                repaired++
            } finally {
                if FileExist(repairPath)
                    try FileDelete(repairPath)
            }
        }
        return repaired
    }

    GetApplicationShortcutPaths() {
        shortcutName := this.ApplicationName ".lnk"
        return {Desktop: A_Desktop "\" shortcutName,
            Programs: A_Programs "\" shortcutName}
    }

    GetApplicationWorkingDirectory(launch := "") {
        if !IsObject(launch)
            launch := this.GetApplicationLaunchSpec()
        SplitPath(launch.EntryPath, , &workingDirectory)
        return workingDirectory
    }

    BackupShortcutFile(shortcutPath) {
        if DirExist(shortcutPath)
            throw Error("快捷方式路径被目录占用：" shortcutPath)
        if !FileExist(shortcutPath)
            return {Target: shortcutPath, Existed: false, Backup: ""}
        backupPath := shortcutPath ".backup-" A_TickCount "-"
            . Format("{:08X}", Random(0, 0xFFFFFFFF))
        FileCopy(shortcutPath, backupPath, false)
        return {Target: shortcutPath, Existed: true, Backup: backupPath}
    }

    RestoreShortcutBackups(backups) {
        failures := []
        for backup in backups {
            try {
                if backup.Existed
                    FileCopy(backup.Backup, backup.Target, true)
                else if FileExist(backup.Target)
                    FileDelete(backup.Target)
            } catch as rollbackError
                failures.Push(backup.Target "：" rollbackError.Message)
        }
        return failures.Length ? this.JoinMessages(failures) : ""
    }

    DeleteShortcutBackups(backups) {
        for backup in backups
            if backup.Backup != "" && FileExist(backup.Backup)
                try FileDelete(backup.Backup)
    }

    JoinMessages(messages) {
        result := ""
        for message in messages
            result .= (result == "" ? "" : "；") message
        return result
    }

    CreateApplicationShortcutFile(shortcutPath, scriptPath, workingDirectory,
            iconPath, compiled, interpreterPath, extraArguments := "") {
        arguments := this.BuildShortcutArguments(compiled, scriptPath,
            extraArguments)
        ; 源码快捷方式直接以 .ahk 文件为 Shell 目标，交由文件关联启动。
        ; 避免产品图标被反向缓存到所有脚本共享的 AutoHotkey64.exe。
        if !this.WriteApplicationShortcut(shortcutPath, scriptPath,
                workingDirectory, arguments, this.ApplicationName, iconPath,
                SystemIntegrationService.ApplicationUserModelId)
            return false
        return this.ApplicationShortcutMatches(shortcutPath, scriptPath,
            compiled, interpreterPath, extraArguments, workingDirectory)
    }

    WriteApplicationShortcut(shortcutPath, targetPath, workingDirectory,
            arguments, description, iconPath, appUserModelId) {
        try {
            shellLink := ComObject(
                "{00021401-0000-0000-C000-000000000046}",
                "{000214F9-0000-0000-C000-000000000046}")
            if ComCall(20, shellLink, "WStr", targetPath, "Int") < 0
                return false
            if ComCall(11, shellLink, "WStr", arguments, "Int") < 0
                return false
            if ComCall(9, shellLink, "WStr", workingDirectory, "Int") < 0
                return false
            if ComCall(7, shellLink, "WStr", description, "Int") < 0
                return false
            if iconPath != ""
                && ComCall(17, shellLink, "WStr", iconPath, "Int", 0,
                    "Int") < 0
                return false
            if ComCall(15, shellLink, "Int", 1, "Int") < 0
                return false
            if !this.SetShellLinkAppUserModelId(shellLink, appUserModelId)
                return false
            persistFile := ComObjQuery(shellLink,
                "{0000010B-0000-0000-C000-000000000046}")
            return ComCall(6, persistFile, "WStr", shortcutPath, "Int",
                true, "Int") >= 0
        } catch {
            return false
        }
    }

    ApplicationShortcutMatches(shortcutPath, scriptPath, compiled,
            interpreterPath, extraArguments := "", workingDirectory := "") {
        return this.ApplicationShortcutLaunchMatches(shortcutPath, scriptPath,
                workingDirectory, compiled, interpreterPath, extraArguments)
            && this.ReadShortcutAppUserModelId(shortcutPath)
                == SystemIntegrationService.ApplicationUserModelId
    }

    ApplicationShortcutLaunchMatches(shortcutPath, scriptPath,
            workingDirectory, compiled, interpreterPath,
            extraArguments := "") {
        if !FileExist(shortcutPath) || DirExist(shortcutPath)
            return false
        try FileGetShortcut(shortcutPath, &targetPath,
            &actualWorkingDirectory, &arguments)
        catch
            return false
        if !this.PathsEqual(targetPath, scriptPath)
            return false
        if workingDirectory != ""
            && !this.PathsEqual(actualWorkingDirectory, workingDirectory)
            return false
        expectedArguments := this.BuildShortcutArguments(compiled,
            scriptPath, extraArguments)
        return Trim(arguments) == expectedArguments
    }

    LegacyApplicationShortcutLaunchMatches(shortcutPath, scriptPath,
            workingDirectory, compiled, interpreterPath,
            extraArguments := "") {
        if compiled || !FileExist(shortcutPath) || DirExist(shortcutPath)
            return false
        try FileGetShortcut(shortcutPath, &targetPath,
            &actualWorkingDirectory, &arguments)
        catch
            return false
        if !this.PathsEqual(targetPath, interpreterPath)
            return false
        if workingDirectory != ""
            && !this.PathsEqual(actualWorkingDirectory, workingDirectory)
            return false
        expectedArguments := QuoteRuntimeCommandArgument(scriptPath)
        extraArguments := Trim(String(extraArguments))
        if extraArguments != ""
            expectedArguments .= " " extraArguments
        return Trim(arguments) == expectedArguments
    }

    GetShortcutAppUserModelIdPropertyKey() {
        static propertyKey := ""
        if IsObject(propertyKey)
            return propertyKey
        propertyKey := Buffer(20, 0)
        result := DllCall("ole32\IIDFromString", "WStr",
            "{9F4C2855-9F79-4B39-A8D0-E1D42DE1D5F3}", "Ptr",
            propertyKey, "Int")
        if result < 0 {
            propertyKey := ""
            throw Error("Could not resolve the shortcut identity property.")
        }
        NumPut("UInt", 5, propertyKey, 16)
        return propertyKey
    }

    OpenShortcutShellLink(shortcutPath) {
        shellLink := ComObject(
            "{00021401-0000-0000-C000-000000000046}",
            "{000214F9-0000-0000-C000-000000000046}")
        persistFile := ComObjQuery(shellLink,
            "{0000010B-0000-0000-C000-000000000046}")
        if ComCall(5, persistFile, "WStr", shortcutPath, "UInt", 0,
                "Int") < 0
            throw Error("Could not load shortcut: " shortcutPath)
        return {Link: shellLink, PersistFile: persistFile}
    }

    SetShellLinkAppUserModelId(shellLink, appUserModelId) {
        properties := ComObjQuery(shellLink,
            "{886D8EEB-8CF2-4446-8D02-CDBA1DBDCF99}")
        propertyValue := Buffer(24, 0)
        propertyReference := ComValue(0x400C, propertyValue.Ptr)
        propertyReference[] := String(appUserModelId)
        try return ComCall(6, properties, "Ptr",
            this.GetShortcutAppUserModelIdPropertyKey(), "Ptr",
            propertyValue, "Int") >= 0
        finally propertyReference[] := 0
    }

    ReadShortcutAppUserModelId(shortcutPath) {
        if !FileExist(shortcutPath) || DirExist(shortcutPath)
            return ""
        propertyValue := Buffer(24, 0)
        try {
            shortcut := this.OpenShortcutShellLink(shortcutPath)
            properties := ComObjQuery(shortcut.Link,
                "{886D8EEB-8CF2-4446-8D02-CDBA1DBDCF99}")
            if ComCall(5, properties, "Ptr",
                    this.GetShortcutAppUserModelIdPropertyKey(), "Ptr",
                    propertyValue, "Int") < 0
                return ""
            valueType := NumGet(propertyValue, 0, "UShort")
            valuePointer := NumGet(propertyValue, 8, "Ptr")
            return ((valueType == 8 || valueType == 31) && valuePointer)
                ? StrGet(valuePointer, "UTF-16") : ""
        } catch {
            return ""
        } finally {
            try DllCall("ole32\PropVariantClear", "Ptr", propertyValue)
        }
    }

    BuildShortcutArguments(compiled, scriptPath, extraArguments := "") {
        return Trim(String(extraArguments))
    }

    NotifyShellShortcutChanged(shortcutPath, existedBefore := false) {
        if shortcutPath == ""
            return false
        try {
            pathFlags := 0x0005 | 0x1000 ; SHCNF_PATHW | SHCNF_FLUSH
            itemEvent := existedBefore ? 0x2000 : 0x0002
            DllCall("shell32\SHChangeNotify", "UInt", itemEvent,
                "UInt", pathFlags, "WStr", shortcutPath, "Ptr", 0)
            SplitPath(shortcutPath, , &shortcutDirectory)
            if shortcutDirectory != ""
                DllCall("shell32\SHChangeNotify", "UInt", 0x1000,
                    "UInt", pathFlags, "WStr", shortcutDirectory, "Ptr", 0)
            return true
        } catch
            return false
    }

    GetStartupTaskState(rootFolder := "", runAsAdministrator := true) {
        if !rootFolder
            rootFolder := this.GetTaskSchedulerRootFolder()
        task := this.GetStartupTask(rootFolder)
        legacyTasks := this.GetOwnedLegacyStartupTasks(rootFolder)
        if !task {
            for legacyTask in legacyTasks {
                if this.StartupTaskRunLevelMatches(legacyTask,
                        runAsAdministrator)
                    return {Status: "owned", Task: legacyTask}
            }
            if legacyTasks.Length
                return {Status: "switch", Task: legacyTasks[1]}
            return {Status: "missing", Task: ""}
        }
        if this.IsOwnedStartupTask(task, runAsAdministrator)
            return {Status: "owned", Task: task}
        if this.IsProjectStartupTask(task)
            return {Status: "switch", Task: task}
        return {Status: "conflict", Task: task}
    }

    ToggleStartupTask(runAsAdministrator := true) {
        launch := this.GetApplicationLaunchSpec()
        service := ComObject("Schedule.Service")
        service.Connect()
        rootFolder := service.GetFolder("\")
        existingTask := this.GetStartupTask(rootFolder)
        legacyTasks := this.GetOwnedLegacyStartupTasks(rootFolder)
        ownedByCurrentEntry := existingTask
            && this.IsOwnedStartupTask(existingTask, runAsAdministrator)
        ownedByProject := existingTask
            && this.IsProjectStartupTask(existingTask)
        if existingTask && !ownedByProject {
            throw Error(Tr("检测到同名计划任务，但它并非当前程序创建；为避免误删，请先在任务计划程序中处理它。"))
        }
        legacyUsesRequestedRunLevel := false
        for legacyTask in legacyTasks {
            if this.StartupTaskRunLevelMatches(legacyTask,
                    runAsAdministrator) {
                legacyUsesRequestedRunLevel := true
                break
            }
        }
        if ownedByCurrentEntry || (!existingTask
                && legacyUsesRequestedRunLevel) {
            this.DeleteOwnedLegacyStartupTasks(rootFolder, legacyTasks)
            if ownedByCurrentEntry
                rootFolder.DeleteTask(this.TaskName, 0)
            return {Action: "deleted"}
        }
        taskDef := this.BuildStartupTaskDefinition(service, launch,
            runAsAdministrator)
        rootFolder.RegisterTaskDefinition(this.TaskName, taskDef, 6, "",
            "", 3)
        this.DeleteOwnedLegacyStartupTasks(rootFolder, legacyTasks)
        return {Action: (ownedByProject || legacyTasks.Length)
            ? "switched" : "created"}
    }

    BuildStartupTaskDefinition(service, launch,
            runAsAdministrator := true) {
        taskDef := service.NewTask(0)
        taskDef.RegistrationInfo.Description := this.ApplicationName
            . " - " . Tr("开机自动启动")
        taskDef.RegistrationInfo.Source := SystemIntegrationService.TaskSource

        taskDef.Triggers.Create(9) ; TASK_TRIGGER_LOGON
        settings := taskDef.Settings
        settings.Enabled := true
        settings.Hidden := false
        settings.DisallowStartIfOnBatteries := false
        settings.StopIfGoingOnBatteries := false
        settings.ExecutionTimeLimit := "PT0S"
        settings.Compatibility := 6

        action := taskDef.Actions.Create(0) ; TASK_ACTION_EXEC
        action.Path := launch.Executable ? launch.EntryPath
            : launch.InterpreterPath
        action.Arguments := this.BuildStartupTaskArguments(
            launch.Executable, launch.InterpreterPath, launch.EntryPath,
            launch.Arguments)
        action.WorkingDirectory := A_ScriptDir

        principal := taskDef.Principal
        principal.RunLevel := runAsAdministrator ? 1 : 0
        principal.LogonType := 3
        return taskDef
    }

    SynchronizeStartupTaskElevation(runAsAdministrator := true) {
        state := this.GetStartupTaskState("", runAsAdministrator)
        if state.Status != "switch"
            return {Action: state.Status}
        result := this.ToggleStartupTask(runAsAdministrator)
        return {Action: "updated", Result: result}
    }

    GetStartupTask(rootFolder := "") {
        try {
            if !rootFolder
                rootFolder := this.GetTaskSchedulerRootFolder()
            return this.GetStartupTaskByName(rootFolder, this.TaskName)
        } catch
            return ""
    }

    GetTaskSchedulerRootFolder() {
        service := ComObject("Schedule.Service")
        service.Connect()
        return service.GetFolder("\")
    }

    GetStartupTaskByName(rootFolder, taskName) {
        try return rootFolder.GetTask(taskName)
        catch
            return ""
    }

    GetOwnedLegacyStartupTasks(rootFolder) {
        legacyTasks := []
        try scheduledTasks := rootFolder.GetTasks(1)
        catch
            return legacyTasks
        for task in scheduledTasks {
            try taskName := String(task.Name)
            catch
                continue
            if StrLower(taskName) == StrLower(this.TaskName)
                continue
            if this.IsOwnedLegacyStartupTask(task)
                legacyTasks.Push(task)
        }
        return legacyTasks
    }

    DeleteOwnedLegacyStartupTasks(rootFolder, tasks) {
        deleted := 0
        for task in tasks {
            try taskName := String(task.Name)
            catch
                continue
            if StrLower(taskName) == StrLower(this.TaskName)
                continue
            currentTask := this.GetStartupTaskByName(rootFolder, taskName)
            if !currentTask || !this.IsOwnedLegacyStartupTask(currentTask)
                continue
            rootFolder.DeleteTask(taskName, 0)
            deleted++
        }
        return deleted
    }

    IsOwnedLegacyStartupTask(task) {
        if !this.StartupTaskLaunchMatches(task)
            return false
        try return task.Definition.RegistrationInfo.Source
            == SystemIntegrationService.TaskSource
        catch
            return false
    }

    IsOwnedStartupTask(task, runAsAdministrator := true) {
        return this.StartupTaskLaunchMatches(task)
            && this.StartupTaskRunLevelMatches(task, runAsAdministrator)
    }

    StartupTaskLaunchMatches(task) {
        try {
            launch := this.GetApplicationLaunchSpec()
            if task.Definition.Actions.Count != 1
                return false
            action := task.Definition.Actions.Item(1)
            expectedPath := launch.Executable ? launch.EntryPath
                : launch.InterpreterPath
            expectedArguments := this.BuildStartupTaskArguments(
                launch.Executable, launch.InterpreterPath,
                launch.EntryPath, launch.Arguments)
            return this.PathsEqual(action.Path, expectedPath)
                && Trim(String(action.Arguments)) == expectedArguments
        } catch
            return false
    }

    StartupTaskRunLevelMatches(task, runAsAdministrator := true) {
        try return Integer(task.Definition.Principal.RunLevel)
            == (runAsAdministrator ? 1 : 0)
        catch
            return false
    }

    IsProjectStartupTask(task) {
        if !task
            return false
        if this.StartupTaskLaunchMatches(task)
            return true
        try {
            return task.Definition.RegistrationInfo.Source
                == SystemIntegrationService.TaskSource
        }
        catch
            return false
    }

    BuildStartupTaskArguments(compiled, interpreterPath, scriptPath,
            extraArguments := "") {
        launchArguments := compiled ? "" : QuoteRuntimeCommandArgument(
            scriptPath)
        extraArguments := Trim(String(extraArguments))
        if extraArguments != ""
            launchArguments .= (launchArguments == "" ? "" : " ")
                . extraArguments
        return launchArguments
    }

    GetApplicationLaunchSpec() {
        if HasCommandLineFlag("--packaged") {
            return {
                Executable: true,
                EntryPath: GetApplicationRootFilePath(
                    "键鼠重映射小助手.exe"),
                InterpreterPath: "",
                Arguments: ""
            }
        }
        return {
            Executable: A_IsCompiled,
            EntryPath: A_ScriptFullPath,
            InterpreterPath: A_AhkPath,
            Arguments: ""
        }
    }

    PathsEqual(left, right) {
        return StrLower(StrReplace(Trim(String(left)), "/", "\"))
            == StrLower(StrReplace(Trim(String(right)), "/", "\"))
    }
}
