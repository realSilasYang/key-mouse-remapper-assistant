#Requires AutoHotkey v2.0 64-bit
#SingleInstance Off
#Warn All, StdOut

#Include ..\..\src\Core\DirectRuntimeSupport.ahk
#Include ..\..\src\Platform\SystemIntegrationService.ahk

try {
    service := StartupTaskElevationTestService()
    elevatedTask := StartupTaskElevationMockTask(1)
    standardTask := StartupTaskElevationMockTask(0)

    StartupTaskElevationAssert(service.IsOwnedStartupTask(
            elevatedTask, true),
        "The elevated startup task was not recognized.")
    StartupTaskElevationAssert(!service.IsOwnedStartupTask(
            elevatedTask, false),
        "The elevated startup task matched standard-user mode.")
    StartupTaskElevationAssert(service.IsOwnedStartupTask(
            standardTask, false),
        "The standard-user startup task was not recognized.")
    StartupTaskElevationAssert(!service.IsOwnedStartupTask(
            standardTask, true),
        "The standard-user startup task matched elevated mode.")

    elevatedRoot := StartupTaskElevationMockRoot(elevatedTask)
    StartupTaskElevationAssert(
        service.GetStartupTaskState(elevatedRoot, true).Status == "owned"
            && service.GetStartupTaskState(elevatedRoot, false).Status
                == "switch",
        "The task state did not expose an elevation mismatch.")

    factory := StartupTaskElevationDefinitionFactory()
    launch := service.GetApplicationLaunchSpec()
    elevatedDefinition := service.BuildStartupTaskDefinition(factory,
        launch, true)
    standardDefinition := service.BuildStartupTaskDefinition(factory,
        launch, false)
    StartupTaskElevationAssert(elevatedDefinition.Principal.RunLevel == 1
            && standardDefinition.Principal.RunLevel == 0,
        "New task definitions ignored the administrator setting.")

    FileAppend("PASS startup task elevation`n", "*")
} catch as testError {
    FileAppend(testError.Message "`n" testError.Stack "`n", "**")
    ExitApp(1)
}
ExitApp(0)

StartupTaskElevationAssert(value, message) {
    if !value
        throw Error(message)
}

GetApplicationIconPath() => A_AhkPath
Tr(template, values*) => values.Length ? Format(template, values*) : template

class StartupTaskElevationTestService extends SystemIntegrationService {
    __New() => super.__New("Remapper")

    GetApplicationLaunchSpec() {
        return {
            Executable: false,
            EntryPath: "C:\Program Files\Remapper\app.ahk",
            InterpreterPath: "C:\AutoHotkey.exe",
            Arguments: "--show-main"
        }
    }
}

class StartupTaskElevationMockTask {
    __New(runLevel) {
        this.Name := SystemIntegrationService.StableTaskName
        this.Definition := {
            Actions: StartupTaskElevationExistingActions(),
            RegistrationInfo: {Source: SystemIntegrationService.TaskSource},
            Principal: {RunLevel: runLevel}
        }
    }
}

class StartupTaskElevationExistingActions {
    __New() {
        this.Count := 1
        this.Action := {
            Path: "C:\AutoHotkey.exe",
            Arguments: QuoteRuntimeCommandArgument(
                "C:\Program Files\Remapper\app.ahk") " --show-main"
        }
    }

    Item(index) {
        if index != 1
            throw Error("Unexpected action index.")
        return this.Action
    }
}

class StartupTaskElevationMockRoot {
    __New(task) => this.Task := task

    GetTask(name) {
        if name != this.Task.Name
            throw Error("Task not found.")
        return this.Task
    }

    GetTasks(*) => [this.Task]
}

class StartupTaskElevationDefinitionFactory {
    NewTask(*) => StartupTaskElevationDefinition()
}

class StartupTaskElevationDefinition {
    __New() {
        this.RegistrationInfo := {Description: "", Source: ""}
        this.Triggers := StartupTaskElevationTriggers()
        this.Settings := {
            Enabled: false,
            Hidden: false,
            DisallowStartIfOnBatteries: true,
            StopIfGoingOnBatteries: true,
            ExecutionTimeLimit: "",
            Compatibility: 0
        }
        this.Actions := StartupTaskElevationCreatedActions()
        this.Principal := {RunLevel: -1, LogonType: 0}
    }
}

class StartupTaskElevationTriggers {
    Create(*) => {}
}

class StartupTaskElevationCreatedActions {
    __New() => this.Action := {Path: "", Arguments: "",
        WorkingDirectory: ""}
    Create(*) => this.Action
}
