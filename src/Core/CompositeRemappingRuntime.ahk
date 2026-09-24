class CompositeRemappingRuntime {
    __New(app, directRuntime := "", scriptRuntime := "",
            interceptionRuntime := "") {
        this.App := app
        this.Direct := IsObject(directRuntime)
            ? directRuntime : DirectHotkeyRuntime(app)
        this.Scripts := IsObject(scriptRuntime)
            ? scriptRuntime : ScriptRuleRuntime(app)
        this.Interception := IsObject(interceptionRuntime)
            ? interceptionRuntime : CompositeInactiveRuntime()
        this.Mappings := []
        this.DirectReport := ""
        this.ScriptReport := ""
        this.InterceptionReport := ""
        this.AppliedScripts := []
        this.HasAppliedMappings := false
        this.Suspended := false
    }

    ApplyMappings(mappings) {
        if Type(mappings) != "Array"
            throw TypeError("规则必须是数组。")
        managed := []
        intercepted := []
        scripts := []
        blockedInterceptionScripts := []
        preflightIssues := []
        for mapping in mappings {
            mode := mapping.HasOwnProp("Mode") ? mapping.Mode : "managed"
            if mode == "managed" {
                from := mapping.Spec.Get("from", Map())
                if from.Has("device")
                        && from["device"].Get("backend", "")
                            == "interception"
                    intercepted.Push(mapping)
                else
                    managed.Push(mapping)
            }
            else if mode == "script"
                scripts.Push(mapping)
            else
                throw Error("未知规则模式：" mode)
        }
        interceptionStatus := ""
        blockedInterceptionScripts := this.FindScriptsBlockedByInterception(
            scripts, &interceptionStatus)
        if blockedInterceptionScripts.Length {
            blockedIds := Map()
            for mapping in blockedInterceptionScripts
                blockedIds[mapping.Id] := true
            runnableScripts := []
            for mapping in scripts
                if !blockedIds.Has(mapping.Id)
                    runnableScripts.Push(mapping)
            scripts := runnableScripts
            preflightIssues.Push(interceptionStatus.Get("message",
                "Interception driver unavailable."))
        }
        previousMappings := this.Mappings
        previousManaged := this.FilterManaged(previousMappings, false)
        previousIntercepted := this.FilterManaged(previousMappings, true)
        previousScripts := this.AppliedScripts
        managedChanged := !this.HasAppliedMappings
            || !this.MappingsEquivalent(previousManaged, managed)
        scriptsChanged := !this.HasAppliedMappings
            || !this.MappingsEquivalent(previousScripts, scripts)
        interceptionChanged := !this.HasAppliedMappings
            || !this.MappingsEquivalent(previousIntercepted, intercepted)
        directReport := managedChanged
            ? this.Direct.ApplyMappings(managed) : this.DirectReport
        try interceptionReport := interceptionChanged
            ? this.Interception.ApplyMappings(intercepted)
            : this.InterceptionReport
        catch as interceptionError {
            if managedChanged {
                try this.Direct.ApplyMappings(previousManaged)
                catch as restoreError
                    throw Error(interceptionError.Message
                        "；恢复原托管规则失败：" restoreError.Message,
                        -1, interceptionError)
            }
            throw interceptionError
        }
        try scriptReport := scriptsChanged
            ? this.Scripts.ApplyMappings(scripts) : this.ScriptReport
        catch as scriptError {
            if interceptionChanged
                try this.InterceptionReport :=
                    this.Interception.ApplyMappings(previousIntercepted)
            if managedChanged
                try this.Direct.ApplyMappings(previousManaged)
            throw scriptError
        }
        this.Mappings := mappings.Clone()
        this.DirectReport := directReport
        this.ScriptReport := scriptReport
        this.InterceptionReport := interceptionReport
        this.AppliedScripts := scripts.Clone()
        this.HasAppliedMappings := true
        return {Applied: directReport.Applied + interceptionReport.Applied
                + scriptReport.Applied,
            Registrations: directReport.Registrations
                + interceptionReport.Registrations,
            InterceptionRules: interceptionReport.Applied,
            ScriptWorkers: scriptReport.Workers,
            Issues: this.MergeIssues(directReport, interceptionReport,
                scriptReport, {Issues: preflightIssues}),
            Capabilities: this.GetCapabilities()}
    }

    FindScriptsBlockedByInterception(scripts, &status := "") {
        if !scripts.Length || !IsObject(this.App)
                || !this.App.HasOwnProp("Interception")
            return []
        dependent := []
        for mapping in scripts {
            spec := mapping.Spec
            enabled := spec.Get("enabled", JsonBoolean(true))
            if enabled is JsonBoolean && !enabled.Value
                continue
            code := spec.Get("code", "")
            normalizedCode := StrLower(RegExReplace(String(code), "[^a-z]", ""))
            if InStr(normalizedCode, "interception")
                    && InStr(normalizedCode, "createcontext")
                dependent.Push(mapping)
        }
        if !dependent.Length
            return []
        status := this.App.Interception.GetStatus()
        return status.Get("available", false) ? [] : dependent
    }

    MergeIssues(reports*) {
        issues := []
        for report in reports
            if IsObject(report) && report.HasOwnProp("Issues")
                for issue in report.Issues
                    issues.Push(issue)
        return issues
    }

    Suspend() {
        if this.Suspended
            return false
        this.Direct.Suspend()
        try this.Interception.Suspend()
        catch as interceptionError {
            try this.Direct.Resume()
            throw interceptionError
        }
        try this.Scripts.Suspend()
        catch as scriptError {
            try this.Interception.Resume()
            try this.Direct.Resume()
            throw scriptError
        }
        this.Suspended := true
        return true
    }

    SuspendForCapture() {
        if this.Suspended
            return false
        this.Direct.Suspend()
        try this.Interception.Suspend()
        catch as interceptionError {
            try this.Direct.Resume()
            throw interceptionError
        }
        try this.Scripts.SuspendForCapture()
        catch as scriptError {
            try this.Interception.Resume()
            try this.Direct.Resume()
            throw scriptError
        }
        this.Suspended := true
        return true
    }

    Resume() {
        if !this.Suspended
            return false
        this.Scripts.Resume()
        try this.Interception.Resume()
        catch as interceptionError {
            try this.Scripts.Suspend()
            throw interceptionError
        }
        try this.Direct.Resume()
        catch as directError {
            try this.Interception.Suspend()
            try this.Scripts.Suspend()
            throw directError
        }
        this.Suspended := false
        return true
    }

    ResumeAfterCapture() {
        if !this.Suspended
            return false
        this.Scripts.ResumeForCapture()
        try this.Interception.Resume()
        catch as interceptionError {
            try this.Scripts.SuspendForCapture()
            throw interceptionError
        }
        try this.Direct.Resume()
        catch as directError {
            try this.Interception.Suspend()
            try this.Scripts.SuspendForCapture()
            throw directError
        }
        this.Suspended := false
        return true
    }

    RecoverAfterResume() {
        directRecovered := this.Direct.RecoverAfterResume()
        interceptionRecovered := this.Interception.RecoverAfterResume()
        scriptRecovered := this.Scripts.RecoverAfterResume()
        return directRecovered && interceptionRecovered && scriptRecovered
    }

    GetCapabilities() {
        capabilities := this.Direct.GetCapabilities()
        capabilities["script_rules"] := JsonBoolean(true)
        capabilities["script_isolation"] := JsonBoolean(true)
        capabilities["interception_device_filtering"] := JsonBoolean(true)
        return capabilities
    }

    Shutdown() {
        failures := []
        scriptsStopped := false
        interceptionStopped := false
        directStopped := false
        try scriptsStopped := this.Scripts.Shutdown()
        catch as scriptError
            failures.Push("脚本规则：" scriptError.Message)
        try interceptionStopped := this.Interception.Shutdown()
        catch as interceptionError
            failures.Push("Interception 规则：" interceptionError.Message)
        try directStopped := this.Direct.Shutdown()
        catch as directError
            failures.Push("托管规则：" directError.Message)
        this.Mappings := []
        this.DirectReport := ""
        this.ScriptReport := ""
        this.InterceptionReport := ""
        this.AppliedScripts := []
        this.HasAppliedMappings := false
        if failures.Length
            throw Error("重映射运行时关闭不完整："
                . ScriptRuleSpec.Join(failures, "；"))
        return scriptsStopped && interceptionStopped && directStopped
    }

    Filter(mappings, expectedMode) {
        result := []
        for mapping in mappings {
            mode := mapping.HasOwnProp("Mode") ? mapping.Mode : "managed"
            if mode == expectedMode
                result.Push(mapping)
        }
        return result
    }

    FilterManaged(mappings, intercepted) {
        result := []
        for mapping in mappings {
            mode := mapping.HasOwnProp("Mode") ? mapping.Mode : "managed"
            if mode != "managed"
                continue
            from := mapping.Spec.Get("from", Map())
            isIntercepted := from.Has("device")
                && from["device"].Get("backend", "") == "interception"
            if isIntercepted == intercepted
                result.Push(mapping)
        }
        return result
    }

    GetUnavailableInterceptionRuleIds() {
        ids := []
        if !IsObject(this.InterceptionReport)
                || !this.InterceptionReport.HasOwnProp("Issues")
            return ids
        for issue in this.InterceptionReport.Issues {
            if !IsObject(issue) || !issue.HasOwnProp("RuleIds")
                continue
            for ruleId in issue.RuleIds
                ids.Push(String(ruleId))
        }
        return ids
    }

    MappingsEquivalent(leftMappings, rightMappings) {
        if leftMappings.Length != rightMappings.Length
            return false
        for index, leftMapping in leftMappings {
            rightMapping := rightMappings[index]
            leftMode := leftMapping.HasOwnProp("Mode")
                ? leftMapping.Mode : "managed"
            rightMode := rightMapping.HasOwnProp("Mode")
                ? rightMapping.Mode : "managed"
            if leftMode != rightMode || leftMapping.Id != rightMapping.Id
                    || JsonCodec.Stringify(leftMapping.Spec, false, true)
                        != JsonCodec.Stringify(rightMapping.Spec, false, true)
                return false
        }
        return true
    }

}

class CompositeInactiveRuntime {
    __New() {
        this.Suspended := false
    }
    ApplyMappings(mappings) => {Applied: 0, Registrations: 0,
        Issues: [], Capabilities: this.GetCapabilities()}
    Suspend() {
        if this.Suspended
            return false
        this.Suspended := true
        return true
    }
    Resume() {
        if !this.Suspended
            return false
        this.Suspended := false
        return true
    }
    RecoverAfterResume() => true
    GetCapabilities() => Map()
    Shutdown() => true
}
