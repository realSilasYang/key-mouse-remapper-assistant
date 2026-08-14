class CompositeRemappingRuntime {
    __New(app, directRuntime := "", scriptRuntime := "") {
        this.App := app
        this.Direct := IsObject(directRuntime)
            ? directRuntime : DirectHotkeyRuntime(app)
        this.Scripts := IsObject(scriptRuntime)
            ? scriptRuntime : ScriptRuleRuntime(app)
        this.Mappings := []
        this.DirectReport := ""
        this.ScriptReport := ""
        this.HasAppliedMappings := false
        this.Suspended := false
    }

    ApplyMappings(mappings) {
        if Type(mappings) != "Array"
            throw TypeError("规则必须是数组。")
        managed := []
        scripts := []
        for mapping in mappings {
            mode := mapping.HasOwnProp("Mode") ? mapping.Mode : "managed"
            if mode == "managed"
                managed.Push(mapping)
            else if mode == "script"
                scripts.Push(mapping)
            else
                throw Error("未知规则模式：" mode)
        }
        previousMappings := this.Mappings
        previousManaged := this.Filter(previousMappings, "managed")
        previousScripts := this.Filter(previousMappings, "script")
        managedChanged := !this.HasAppliedMappings
            || !this.MappingsEquivalent(previousManaged, managed)
        scriptsChanged := !this.HasAppliedMappings
            || !this.MappingsEquivalent(previousScripts, scripts)
        directReport := managedChanged
            ? this.Direct.ApplyMappings(managed) : this.DirectReport
        try scriptReport := scriptsChanged
            ? this.Scripts.ApplyMappings(scripts) : this.ScriptReport
        catch as scriptError {
            if managedChanged {
                try this.Direct.ApplyMappings(previousManaged)
                catch as restoreError
                    throw Error(scriptError.Message "；恢复原托管规则失败："
                        restoreError.Message, -1, scriptError)
            }
            throw scriptError
        }
        this.Mappings := mappings.Clone()
        this.DirectReport := directReport
        this.ScriptReport := scriptReport
        this.HasAppliedMappings := true
        return {Applied: directReport.Applied + scriptReport.Applied,
            Registrations: directReport.Registrations,
            ScriptWorkers: scriptReport.Workers,
            Issues: directReport.Issues,
            Capabilities: this.GetCapabilities()}
    }

    Suspend() {
        if this.Suspended
            return false
        this.Direct.Suspend()
        try this.Scripts.Suspend()
        catch as scriptError {
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
        try this.Scripts.SuspendForCapture()
        catch as scriptError {
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
        try this.Direct.Resume()
        catch as directError {
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
        try this.Direct.Resume()
        catch as directError {
            try this.Scripts.SuspendForCapture()
            throw directError
        }
        this.Suspended := false
        return true
    }

    RecoverAfterResume() {
        directRecovered := this.Direct.RecoverAfterResume()
        scriptRecovered := this.Scripts.RecoverAfterResume()
        return directRecovered && scriptRecovered
    }

    GetCapabilities() {
        capabilities := this.Direct.GetCapabilities()
        capabilities["script_rules"] := JsonBoolean(true)
        capabilities["script_isolation"] := JsonBoolean(true)
        return capabilities
    }

    Shutdown() {
        failures := []
        scriptsStopped := false
        directStopped := false
        try scriptsStopped := this.Scripts.Shutdown()
        catch as scriptError
            failures.Push("脚本规则：" scriptError.Message)
        try directStopped := this.Direct.Shutdown()
        catch as directError
            failures.Push("托管规则：" directError.Message)
        this.Mappings := []
        this.DirectReport := ""
        this.ScriptReport := ""
        this.HasAppliedMappings := false
        if failures.Length
            throw Error("重映射运行时关闭不完整："
                . ScriptRuleSpec.Join(failures, "；"))
        return scriptsStopped && directStopped
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
