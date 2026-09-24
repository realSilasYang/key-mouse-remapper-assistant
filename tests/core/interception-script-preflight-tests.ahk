#Requires AutoHotkey v2.0 64-bit
#SingleInstance Off
#Warn All, StdOut

#Include ..\..\src\Core\JsonCodec.ahk
#Include ..\..\src\Core\CompositeRemappingRuntime.ahk

try {
    service := InterceptionPreflightStatus()
    direct := InterceptionPreflightBranch()
    scripts := InterceptionPreflightBranch(true)
    intercepted := InterceptionPreflightBranch()
    runtime := CompositeRemappingRuntime({Interception: service}, direct,
        scripts, intercepted)
    dependent := {Id: "interception-script", Mode: "script",
        Spec: Map("code", "DllCall('interception_create_context')")}
    disabled := {Id: "disabled-interception-script", Mode: "script",
        Spec: Map("code", "DllCall('interception_create_context')",
            "enabled", JsonBoolean(false))}
    independent := {Id: "ordinary-script", Mode: "script",
        Spec: Map("code", "Persistent")}
    mappings := [dependent, disabled, independent]

    for code in ["driver_unavailable", "restart_required", "dll_missing",
            "dll_load_failed"] {
        service.SetStatus(code, false)
        report := runtime.ApplyMappings(mappings)
        PreflightAssert(report.ScriptWorkers == 2
                && report.Issues.Length == 1
                && scripts.LastMappings.Length == 2
                && scripts.LastMappings[1].Id == disabled.Id
                && scripts.LastMappings[2].Id == independent.Id,
            "Unavailable state did not block only the dependent script: " code)
    }

    service.SetStatus("ready", true)
    report := runtime.ApplyMappings(mappings)
    PreflightAssert(report.ScriptWorkers == 3
            && report.Issues.Length == 0
            && scripts.LastMappings.Length == 3,
        "A previously blocked script did not start when the driver became ready.")

    service.SetStatus("restart_required", false)
    report := runtime.ApplyMappings(mappings)
    PreflightAssert(report.ScriptWorkers == 2
            && scripts.LastMappings.Length == 2,
        "A running dependent script was not stopped when the driver became unavailable.")

    FileAppend("PASS interception-script-preflight`n", "*")
    ExitApp(0)
} catch as testError {
    FileAppend("FAIL interception-script-preflight: " testError.Message
        "`n" testError.Stack "`n", "*")
    ExitApp(1)
}

PreflightAssert(condition, message) {
    if !condition
        throw Error(message)
}

class InterceptionPreflightStatus {
    __New() {
        this.Status := Map()
    }
    SetStatus(code, available) {
        this.Status := Map("code", code, "available", available,
            "message", "Interception " code)
    }
    GetStatus() => this.Status.Clone()
}

class InterceptionPreflightBranch {
    __New(script := false) {
        this.Script := script
        this.LastMappings := []
    }
    ApplyMappings(mappings) {
        this.LastMappings := mappings.Clone()
        return this.Script
            ? {Applied: mappings.Length, Workers: mappings.Length,
                Issues: []}
            : {Applied: mappings.Length, Registrations: mappings.Length,
                Issues: []}
    }
    GetCapabilities() => Map()
}
