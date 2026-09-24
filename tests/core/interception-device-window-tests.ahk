#Requires AutoHotkey v2.0 64-bit
#SingleInstance Off
#Warn All, StdOut

#Include ..\..\src\UI\CleanupCollector.ahk

class UiThemeService {
}

class LocalizationService {
}

class UiScaleService {
}

class WindowHierarchy {
}

class MappingUiInteractions {
}

ApplyApplicationWindowIcon(*) => []
ShowPreparedWindow(*) => true
ActivatePreparedWindow(*) => true
ApplyDarkWindow(*) => true
ApplyDarkListView(*) => true
ApplyDarkControl(*) => true
ReleaseApplicationWindowIcons(*) => true

#Include ..\..\app\Windows\InterceptionDeviceWindow.ahk

InterceptionDeviceWindowAssert(condition, message) {
    if !condition
        throw Error(message)
}

class InterceptionDeviceWindowRuntimeProbe {
    __New() => this.ResumeCount := 0

    Resume() {
        this.ResumeCount++
        return true
    }
}

class InterceptionDeviceWindowServiceProbe {
    __New() => this.StopIdentifyCount := 0

    StopIdentify() {
        this.StopIdentifyCount++
        return true
    }
}

class InterceptionDeviceWindowOwnerProbe {
    __New() => this.ClosedCount := 0

    OnInterceptionDevicesClosed(*) {
        this.ClosedCount++
        return true
    }
}

class InterceptionDeviceWindowDisposeProbe extends InterceptionDeviceWindow {
    __New(runtime, service, owner) {
        this.OwnerWindow := owner
        this.App := {Runtime: {Interception: runtime}}
        this.Service := service
        this.Gui := ""
        this.OwnerLease := ""
        this.IconHandles := []
        this.Interactions := ""
        this.IdentifyTimer := ""
        this.Identifying := true
        this.RuntimeSuspensionOwned := true
        this.Disposed := false
    }
}

try {
    runtime := InterceptionDeviceWindowRuntimeProbe()
    service := InterceptionDeviceWindowServiceProbe()
    owner := InterceptionDeviceWindowOwnerProbe()
    window := InterceptionDeviceWindowDisposeProbe(runtime, service, owner)
    window.Dispose(false)
    InterceptionDeviceWindowAssert(runtime.ResumeCount == 1
            && service.StopIdentifyCount == 1
            && owner.ClosedCount == 1
            && !window.RuntimeSuspensionOwned,
        "Closing the identify window did not resume device-specific rules.")
    ExitApp(0)
} catch as testError {
    FileAppend("FAIL interception-device-window-tests: "
        . testError.Message "`n" testError.Stack "`n", "*")
    ExitApp(1)
}
