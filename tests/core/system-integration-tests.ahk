#Requires AutoHotkey v2.0 64-bit
#SingleInstance Off
#Warn All, StdOut

#Include ..\..\src\Core\DirectRuntimeSupport.ahk
#Include ..\..\src\Platform\SystemIntegrationService.ahk

try {
    integrationService := SystemIntegrationService("Remapper")
    IntegrationAssertEqual("KeyMouseRemapperAssistant",
        integrationService.TaskName,
        "The startup task name must not depend on the UI language.")
    IntegrationAssertEqual(integrationService.TaskName,
        SystemIntegrationService("重映射小助手").TaskName,
        "Localized application names produced different startup task names.")
    integrationScriptPath := "C:\Program Files\Remapper\app.ahk"
    quotedIntegrationScript := QuoteRuntimeCommandArgument(
        integrationScriptPath)
    IntegrationAssertEqual(quotedIntegrationScript " --show-main",
        integrationService.BuildStartupTaskArguments(false,
            "C:\AutoHotkey.exe", integrationScriptPath, "--show-main"),
        "The source startup task arguments are incorrect.")
    IntegrationAssertEqual("--show-main",
        integrationService.BuildShortcutArguments(false,
            integrationScriptPath, "--show-main"),
        "The source shortcut included the script path as an argument.")
    IntegrationAssertEqual("--show-main",
        integrationService.BuildStartupTaskArguments(true, "",
            integrationScriptPath,
            "--show-main"),
        "Executable startup arguments include a script path.")
    IntegrationAssertEqual("",
        integrationService.BuildStartupTaskArguments(true, "",
            integrationScriptPath),
        "An executable startup task received spurious arguments.")
    IntegrationAssertTrue(integrationService.PathsEqual(
        "C:/Program Files/Remapper/app.exe",
        "c:\Program Files\Remapper\app.exe"),
        "Equivalent Windows paths did not compare equally.")
    pathAliasRoot := A_Temp "\remapper-path-alias-with-long-name-"
        . A_TickCount
    DirCreate(pathAliasRoot)
    try {
        shortPath := IntegrationGetShortPath(pathAliasRoot)
        if shortPath != pathAliasRoot {
            IntegrationAssertTrue(integrationService.PathsEqual(
                    shortPath, pathAliasRoot),
                "Equivalent short and long Windows paths did not compare equally.")
        }
    } finally DirDelete(pathAliasRoot)
    settingsWindowSource := FileRead(A_ScriptDir
        "\..\..\app\Windows\SettingsWindow.ahk", "UTF-8")
    applicationSource := FileRead(A_ScriptDir
        "\..\..\app\KeyMouseRemapperAssistantApp.ahk", "UTF-8")
    IntegrationAssertTrue(RegExMatch(settingsWindowSource,
            "s)CreateShortcuts\(\*\).*?this\.App\.CreateApplicationShortcuts\(this\.Gui\).*?ShortcutFeedback")
        && RegExMatch(applicationSource,
            "s)CreateApplicationShortcuts\(ownerGui.*?this\.SystemIntegration\.CreateApplicationShortcuts\(\)"),
        "The settings shortcut button is no longer connected to the "
            . "verified transactional shortcut service.")

    realShortcutRoot := A_Temp "\remapper-real-shortcut-" A_TickCount "-"
        . Format("{:08X}", Random(0, 0xFFFFFFFF))
    DirCreate(realShortcutRoot)
    try {
        realShortcut := realShortcutRoot "\source.lnk"
        IntegrationAssertTrue(integrationService.CreateApplicationShortcutFile(
            realShortcut, A_ScriptFullPath, A_ScriptDir, A_AhkPath,
            false, A_AhkPath),
            "The source shortcut could not be created or verified.")
        FileGetShortcut(realShortcut, &realTarget, &realWorkingDirectory,
            &realArguments, , &realIcon)
        IntegrationAssertTrue(realTarget == A_ScriptFullPath
            && realWorkingDirectory == A_ScriptDir
            && realArguments == ""
            && realIcon == A_AhkPath,
            "The source shortcut lost its target, arguments, directory, or icon.")
        IntegrationAssertTrue(!integrationService.PathsEqual(realTarget,
                A_AhkPath) && !InStr(realArguments, A_ScriptFullPath),
            "The source shortcut targets the shared interpreter and could "
                . "contaminate unrelated AutoHotkey taskbar icons.")
        IntegrationAssertEqual(
            SystemIntegrationService.ApplicationUserModelId,
            integrationService.ReadShortcutAppUserModelId(realShortcut),
            "The source shortcut did not receive the product AppUserModelID.")
        ; Recreate the legacy interpreter-target shortcut with an already
        ; correct AppID. Target isolation must still cause a migration.
        IntegrationAssertTrue(integrationService.WriteApplicationShortcut(
                realShortcut, A_AhkPath, A_ScriptDir,
                QuoteRuntimeCommandArgument(A_ScriptFullPath), "test",
                A_AhkPath,
                SystemIntegrationService.ApplicationUserModelId)
            && integrationService.ReadShortcutAppUserModelId(realShortcut)
                == SystemIntegrationService.ApplicationUserModelId,
            "The legacy shared-interpreter shortcut could not be created.")
        IntegrationAssertTrue(
            integrationService.LegacyApplicationShortcutLaunchMatches(
                realShortcut, A_ScriptFullPath, A_ScriptDir, false,
                A_AhkPath),
            "The legacy project shortcut was not recognized for migration.")
        IntegrationAssertEqual(1,
            integrationService.RepairApplicationShortcutIdentities(
                [realShortcut], {
                    Executable: false,
                    EntryPath: A_ScriptFullPath,
                    InterpreterPath: A_AhkPath,
                    Arguments: ""
                }),
            "The existing source shortcut identity was not repaired.")
        IntegrationAssertEqual(
            SystemIntegrationService.ApplicationUserModelId,
            integrationService.ReadShortcutAppUserModelId(realShortcut),
            "The repaired shortcut did not regain the product AppUserModelID.")
        FileGetShortcut(realShortcut, &repairedTarget, ,
            &repairedArguments)
        IntegrationAssertTrue(repairedTarget == A_ScriptFullPath
            && repairedArguments == "",
            "The repaired shortcut still targets the shared interpreter.")

        chainRoot := realShortcutRoot "\button-chain"
        DirCreate(chainRoot)
        probeScript := chainRoot "\shortcut-launch-probe.ahk"
        probeOutput := chainRoot "\shortcut-launch-result.txt"
        FileAppend('#Requires AutoHotkey v2.0`n'
            . 'result := A_WorkingDir "|" A_Args.Length`n'
            . 'for argument in A_Args`n'
            . '    result .= "|" argument`n'
            . 'FileAppend(result, A_ScriptDir '
            . '"\shortcut-launch-result.txt", "UTF-8")`n'
            . 'ExitApp`n', probeScript, "UTF-8")
        chainService := ShortcutChainIntegrationService(chainRoot,
            probeScript)
        chainPaths := chainService.CreateApplicationShortcuts()
        IntegrationAssertTrue(
            chainService.ApplicationShortcutMatches(chainPaths.Desktop,
                probeScript, false, A_AhkPath,
                '--chain "two words"', chainRoot)
            && chainService.ApplicationShortcutMatches(chainPaths.Programs,
                probeScript, false, A_AhkPath,
                '--chain "two words"', chainRoot),
            "The settings-button chain did not create both valid shortcuts.")
        FileGetShortcut(chainPaths.Programs, &programsTarget, ,
            &programsArguments, , &programsIcon)
        IntegrationAssertTrue(chainService.PathsEqual(programsTarget,
                probeScript)
            && !chainService.PathsEqual(programsTarget, A_AhkPath)
            && programsArguments == '--chain "two words"'
            && chainService.PathsEqual(programsIcon, A_AhkPath)
            && chainService.ReadShortcutAppUserModelId(chainPaths.Programs)
                == SystemIntegrationService.ApplicationUserModelId,
            "The Start menu shortcut did not preserve target isolation, "
                . "icon, arguments, or its product AppUserModelID.")
        Run(chainPaths.Desktop, chainRoot)
        deadline := A_TickCount + 10000
        expectedProbeOutput := chainRoot "|2|--chain|two words"
        actualProbeOutput := ""
        while A_TickCount < deadline {
            try actualProbeOutput := FileRead(probeOutput, "UTF-8")
            catch
                actualProbeOutput := ""
            if actualProbeOutput == expectedProbeOutput
                break
            Sleep(50)
        }
        IntegrationAssertTrue(actualProbeOutput == expectedProbeOutput,
            "The source shortcut did not preserve its directory or arguments "
                . "through the system file association.")
    } finally {
        if DirExist(realShortcutRoot)
            DirDelete(realShortcutRoot, true)
    }

    taskService := TestTaskIntegrationService()
    ownedLegacy := TestScheduledTask("旧语言任务", "C:\AutoHotkey.exe",
        quotedIntegrationScript " --show-main",
        SystemIntegrationService.TaskSource)
    manualSameCommand := TestScheduledTask("ManualTask", "C:\AutoHotkey.exe",
        quotedIntegrationScript " --show-main")
    unrelatedLegacy := TestScheduledTask("OtherRemapper", "C:\Other.exe", "")
    canonicalTask := TestScheduledTask(taskService.TaskName,
        "C:\AutoHotkey.exe", quotedIntegrationScript " --show-main")
    taskRoot := TestTaskRoot([ownedLegacy, manualSameCommand,
        unrelatedLegacy, canonicalTask])
    discoveredLegacyTasks := taskService.GetOwnedLegacyStartupTasks(taskRoot)
    IntegrationAssertEqual(1, discoveredLegacyTasks.Length,
        "Legacy task discovery included an unrelated or canonical task.")
    IntegrationAssertEqual("旧语言任务", discoveredLegacyTasks[1].Name,
        "The owned localized task was not discovered.")
    taskRootWithoutCanonical := TestTaskRoot([ownedLegacy,
        manualSameCommand, unrelatedLegacy])
    legacyState := taskService.GetStartupTaskState(taskRootWithoutCanonical)
    IntegrationAssertEqual("owned", legacyState.Status,
        "An owned localized startup task was reported as missing.")
    taskService.DeleteOwnedLegacyStartupTasks(taskRootWithoutCanonical,
        [ownedLegacy, manualSameCommand, unrelatedLegacy])
    IntegrationAssertEqual(1, taskRootWithoutCanonical.DeletedNames.Length,
        "Legacy cleanup did not limit deletion to owned tasks.")
    IntegrationAssertEqual("旧语言任务",
        taskRootWithoutCanonical.DeletedNames[1],
        "Legacy cleanup deleted the wrong task.")
    lookalikeTask := TestScheduledTask(taskService.TaskName,
        "C:\Program Files\Remapper\other.exe",
        "--note C:\Program Files\Remapper\app.ahk")
    IntegrationAssertTrue(!taskService.IsProjectStartupTask(lookalikeTask),
        "A command-line substring was treated as project task ownership.")
    markedReplacementTask := TestScheduledTask(taskService.TaskName,
        "C:\Old\Remapper.exe", "",
        SystemIntegrationService.TaskSource)
    IntegrationAssertTrue(taskService.IsProjectStartupTask(
            markedReplacementTask),
        "A source-marked project task was not eligible for replacement.")
    multiActionTask := TestScheduledTask("ManualMultiAction",
        "C:\AutoHotkey.exe", quotedIntegrationScript " --show-main", "", 2)
    IntegrationAssertTrue(!taskService.IsOwnedStartupTask(multiActionTask),
        "A task with an additional action was treated as an exact owned task.")
    elevatedTask := TestScheduledTask(taskService.TaskName,
        "C:\AutoHotkey.exe", quotedIntegrationScript " --show-main", "", 1,
        1)
    standardTask := TestScheduledTask(taskService.TaskName,
        "C:\AutoHotkey.exe", quotedIntegrationScript " --show-main", "", 1,
        0)
    IntegrationAssertTrue(taskService.IsOwnedStartupTask(elevatedTask, true)
            && !taskService.IsOwnedStartupTask(elevatedTask, false)
            && taskService.IsOwnedStartupTask(standardTask, false)
            && !taskService.IsOwnedStartupTask(standardTask, true),
        "Startup task ownership ignored the requested elevation level.")
    elevatedState := taskService.GetStartupTaskState(
        TestTaskRoot([elevatedTask]), true)
    elevationMismatchState := taskService.GetStartupTaskState(
        TestTaskRoot([elevatedTask]), false)
    IntegrationAssertTrue(elevatedState.Status == "owned"
            && elevationMismatchState.Status == "switch",
        "An elevation mismatch was not exposed as a startup task switch.")

    shortcutRoot := A_Temp "\remapper-shortcut-" A_TickCount "-"
        . Format("{:08X}", Random(0, 0xFFFFFFFF))
    DirCreate(shortcutRoot)
    rollbackService := FailingShortcutIntegrationService(shortcutRoot)
    rollbackPaths := rollbackService.GetApplicationShortcutPaths()
    FileAppend("original", rollbackPaths.Programs, "UTF-8-RAW")
    IntegrationAssertThrows(
        ObjBindMethod(rollbackService, "CreateApplicationShortcuts"),
        "A partial shortcut creation was expected to fail.")
    IntegrationAssertEqual("original",
        FileRead(rollbackPaths.Programs, "UTF-8"),
        "The existing Start menu shortcut was not restored.")
    IntegrationAssertTrue(!FileExist(rollbackPaths.Desktop),
        "The newly-created desktop shortcut was not rolled back.")
    IntegrationAssertEqual(0,
        IntegrationCountFiles(shortcutRoot, "*.backup-*"),
        "Shortcut rollback left backup files behind.")
    DirDelete(shortcutRoot, true)

    FileAppend("PASS system integration`n", "*")
} catch as testError {
    FileAppend(testError.Message "`n" testError.Stack "`n", "**")
    ExitApp(1)
}
ExitApp(0)

IntegrationAssertTrue(value, message) {
    if !value
        throw Error(message)
}

IntegrationAssertEqual(expected, actual, message) {
    if expected != actual
        throw Error(message " Expected '" expected "', got '" actual "'.")
}

IntegrationAssertThrows(callback, message) {
    try callback.Call()
    catch
        return true
    throw Error(message)
}

GetApplicationIconPath() => A_AhkPath

IntegrationCountFiles(directory, pattern) {
    count := 0
    Loop Files directory "\" pattern, "F"
        count++
    return count
}

IntegrationGetShortPath(path) {
    required := DllCall("kernel32\GetShortPathNameW", "WStr", path,
        "Ptr", 0, "UInt", 0, "UInt")
    if !required
        return path
    pathBuffer := Buffer((required + 1) * 2, 0)
    length := DllCall("kernel32\GetShortPathNameW", "WStr", path,
        "Ptr", pathBuffer, "UInt", required + 1, "UInt")
    return length ? StrGet(pathBuffer, length, "UTF-16") : path
}

class FailingShortcutIntegrationService extends SystemIntegrationService {
    __New(shortcutRoot) {
        super.__New("Remapper")
        this.ShortcutRoot := shortcutRoot
        this.CreateCount := 0
    }

    GetApplicationShortcutPaths() {
        return {Desktop: this.ShortcutRoot "\desktop.lnk",
            Programs: this.ShortcutRoot "\programs.lnk"}
    }

    GetApplicationLaunchSpec() {
        return {Executable: true, EntryPath: A_ScriptFullPath,
            InterpreterPath: "", Arguments: ""}
    }

    CreateApplicationShortcutFile(shortcutPath, *) {
        this.CreateCount++
        if FileExist(shortcutPath)
            FileDelete(shortcutPath)
        FileAppend("replacement", shortcutPath, "UTF-8-RAW")
        return this.CreateCount == 1
    }
}

class ShortcutChainIntegrationService extends SystemIntegrationService {
    __New(shortcutRoot, scriptPath) {
        super.__New("Remapper")
        this.ShortcutRoot := shortcutRoot
        this.ScriptPath := scriptPath
    }

    GetApplicationShortcutPaths() {
        return {
            Desktop: this.ShortcutRoot "\desktop.lnk",
            Programs: this.ShortcutRoot "\programs.lnk"
        }
    }

    GetApplicationLaunchSpec() {
        return {
            Executable: false,
            EntryPath: this.ScriptPath,
            InterpreterPath: A_AhkPath,
            Arguments: '--chain "two words"'
        }
    }
}

class TestTaskIntegrationService extends SystemIntegrationService {
    __New() => super.__New("Remapper")

    GetApplicationLaunchSpec() {
        return {Executable: false,
            EntryPath: "C:\Program Files\Remapper\app.ahk",
            InterpreterPath: "C:\AutoHotkey.exe",
            Arguments: "--show-main"}
    }
}

class TestScheduledTask {
    __New(name, actionPath, arguments, source := "", actionCount := 1,
            runLevel := 1) {
        this.Name := name
        this.Definition := {
            Actions: TestTaskActions(actionPath, arguments, actionCount),
            RegistrationInfo: {Source: source},
            Principal: {RunLevel: runLevel}
        }
    }
}

class TestTaskActions {
    __New(actionPath, arguments, count := 1) {
        this.Action := {Path: actionPath, Arguments: arguments}
        this.Count := count
    }

    Item(index) {
        if index != 1
            throw Error("Unexpected action index.")
        return this.Action
    }
}

class TestTaskRoot {
    __New(tasks) {
        this.Tasks := tasks
        this.DeletedNames := []
    }

    GetTasks(*) => this.Tasks

    GetTask(name) {
        for task in this.Tasks
            if StrLower(task.Name) == StrLower(name)
                return task
        throw Error("Task not found.")
    }

    DeleteTask(name, *) {
        task := this.GetTask(name)
        this.DeletedNames.Push(task.Name)
        for index, candidate in this.Tasks {
            if candidate == task {
                this.Tasks.RemoveAt(index)
                break
            }
        }
    }
}

Tr(template, values*) {
    return values.Length ? Format(template, values*) : template
}
