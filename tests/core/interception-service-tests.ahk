#Requires AutoHotkey v2.0 64-bit
#SingleInstance Off
#Warn All, StdOut

#Include ..\..\src\Core\InterceptionService.ahk

GetApplicationRootFilePath(relativePath) => A_ScriptDir "\" relativePath
GetCanonicalPath(filePath) => filePath

InterceptionAssert(condition, message) {
    if !condition
        throw Error(message)
}

class MissingInterceptionService extends InterceptionService {
    ResolveLibraryPath() => ""
}

class InstallerInterceptionService extends InterceptionService {
    __New() {
        super.__New()
        this.ExecutedCommand := ""
        this.ExecutedDirectory := ""
    }
    GetInstallerPath() => "C:\Package\install-interception.exe"
    ExecuteInstaller(commandLine, workingDirectory) {
        this.ExecutedCommand := commandLine
        this.ExecutedDirectory := workingDirectory
        return 0
    }
}

class UnavailableRegisteredInterceptionService extends InterceptionService {
    EnsureLibrary() => true
    Call(*) => 0
    HasInstalledDriverRegistration() => true
}

class UnavailableUnregisteredInterceptionService extends UnavailableRegisteredInterceptionService {
    HasInstalledDriverRegistration() => false
}

class ConsumerContextFailureService extends InterceptionService {
    EnsureReady() => true
    Call(*) => 0
}

try {
    missing := MissingInterceptionService()
    status := missing.GetStatus()
    InterceptionAssert(!status["available"]
        && status["code"] == "dll_missing",
        "A missing Interception DLL did not produce a diagnostic status.")
    installer := InstallerInterceptionService()
    installResult := installer.InstallDriver()
    InterceptionAssert(installer.ExecutedCommand
            == '"C:\Package\install-interception.exe" /install'
            && installer.ExecutedDirectory == "C:\Package"
            && installResult["restart_required"]
            && installer.Status["code"] == "restart_required",
        "The one-click installer did not build the expected elevated command.")
    pendingRestartStatus := installer.GetStatus()
    InterceptionAssert(pendingRestartStatus["code"] == "restart_required"
            && !pendingRestartStatus["available"],
        "The successful driver installation did not remain pending restart.")
    registeredServiceProbe := UnavailableRegisteredInterceptionService()
    registeredStatus := registeredServiceProbe.GetStatus()
    InterceptionAssert(registeredStatus["code"] == "restart_required"
            && !registeredStatus["available"]
            && InStr(registeredStatus["message"], "重启"),
        "Registered filters with a failed context were not diagnosed as needing restart: "
            registeredStatus["code"] " / " registeredStatus["message"])
    unregistered := UnavailableUnregisteredInterceptionService()
    unregisteredStatus := unregistered.GetStatus()
    InterceptionAssert(unregisteredStatus["code"] == "driver_unavailable",
        "An unregistered driver was incorrectly diagnosed as needing restart.")
    consumerFailure := ConsumerContextFailureService()
    try {
        consumerFailure.StartRuntime([1])
        throw Error("A failed runtime context did not throw.")
    } catch as contextError {
        InterceptionAssert(InStr(contextError.Message,
                "Interception runtime"),
            "A failed runtime context lost its diagnostic message.")
    }

    service := InterceptionService()
    devices := service.BuildUnavailableDevices()
    InterceptionAssert(devices.Length == 20,
        "The unavailable device table must cover all 20 Interception slots.")
    InterceptionAssert(devices[1]["number"] == 1
        && devices[1]["official_index"] == 0
        && devices[1]["type"] == "keyboard",
        "Keyboard project/official device numbering is incorrect.")
    InterceptionAssert(devices[10]["number"] == 10
        && devices[10]["official_index"] == 9,
        "The last keyboard device number is incorrect.")
    InterceptionAssert(devices[11]["number"] == 11
        && devices[11]["official_index"] == 0
        && devices[11]["type"] == "mouse",
        "Mouse project/official device numbering is incorrect.")
    InterceptionAssert(devices[20]["number"] == 20
        && devices[20]["official_index"] == 9,
        "The last mouse device number is incorrect.")
    readyStatus := service.GetStatus()
    InterceptionAssert(readyStatus["code"] == "ready"
        || readyStatus["code"] == "driver_unavailable"
        || readyStatus["code"] == "restart_required"
        || readyStatus["code"] == "dll_missing"
        || readyStatus["code"] == "dll_load_failed",
        "Interception startup did not return a recognized diagnostic code.")
    FileAppend("Actual Interception status: " readyStatus["code"] "`n", "*")
    missing.Shutdown()
    registeredServiceProbe.Shutdown()
    unregistered.Shutdown()
    consumerFailure.Shutdown()
    service.Shutdown()
    installer.Shutdown()
    ExitApp(0)
} catch as testError {
    FileAppend("FAIL interception-service-tests: " testError.Message "`n"
        . testError.Stack "`n", "*")
    ExitApp(1)
}
