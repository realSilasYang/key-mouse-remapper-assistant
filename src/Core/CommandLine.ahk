HasCommandLineFlag(expectedFlag) {
    for argument in A_Args {
        if argument == expectedFlag
            return true
    }
    return false
}

class CommandLineApp {
    __New(outputCallback := "", errorCallback := "") {
        this.OutputCallback := IsObject(outputCallback)
            ? outputCallback : (text => FileAppend(String(text) "`n", "*"))
        this.ErrorCallback := IsObject(errorCallback)
            ? errorCallback : (text => FileAppend(String(text) "`n", "**"))
    }

    Run(arguments, defaultScriptPath, defaultVariablePath := "") {
        try {
            parsed := this.ParseArguments(arguments, defaultScriptPath,
                defaultVariablePath)
            if !parsed.Command.Length {
                this.WriteHelp()
                return 0
            }
            command := StrLower(parsed.Command[1])
            switch command {
                case "help", "--help", "-h":
                    this.RequireArguments(parsed.Command, 1, "help")
                    this.WriteHelp()
                    return 0
                case "list": return this.ListRules(parsed)
                case "validate": return this.ValidatePackage(parsed)
                case "export": return this.ExportRules(parsed)
                case "import": return this.ImportRules(parsed)
                case "enable", "disable":
                    return this.SetRuleEnabled(parsed, command == "enable")
                case "conflicts": return this.ShowConflicts(parsed)
                case "simulate": return this.SimulateRules(parsed)
                case "capabilities": return this.ShowCapabilities(parsed)
                case "devices": return this.ShowDevices(parsed)
                case "lint": return this.LintRules(parsed)
                case "format": return this.FormatRules(parsed, false)
                case "migrate": return this.FormatRules(parsed, true)
                case "diagnose": return this.Diagnose(parsed)
                case "version": return this.ShowVersion(parsed)
                case "variables": return this.ManageVariables(parsed)
                default: throw Error("未知 CLI 命令：" command)
            }
        } catch as commandError {
            this.ErrorCallback.Call(commandError.Message)
            return 1
        }
    }

    ParseArguments(arguments, defaultScriptPath,
            defaultVariablePath := "") {
        command := []
        scriptPath := String(defaultScriptPath)
        variablePath := String(defaultVariablePath)
        controlPath := ""
        controlExplicit := false
        pretty := false
        seenOptions := Map()
        index := 1
        while index <= arguments.Length {
            argument := String(arguments[index])
            if argument == "--script" || argument == "--variables-path"
                    || argument == "--control-path" {
                if seenOptions.Has(argument)
                    throw Error("全局选项不能重复：" argument)
                seenOptions[argument] := true
                if index >= arguments.Length
                    throw Error(argument " 缺少路径参数。")
                if argument == "--script"
                    scriptPath := String(arguments[index + 1])
                else if argument == "--variables-path"
                    variablePath := String(arguments[index + 1])
                else {
                    controlPath := String(arguments[index + 1])
                    controlExplicit := true
                }
                index += 2
                continue
            }
            if argument == "--pretty" {
                if seenOptions.Has(argument)
                    throw Error("全局选项不能重复：" argument)
                seenOptions[argument] := true
                pretty := true
                index++
                continue
            }
            command.Push(argument)
            index++
        }
        dataDirectory := ""
        if variablePath != ""
            SplitPath(variablePath, , &dataDirectory)
        else {
            SplitPath(scriptPath, , &dataDirectory)
            variablePath := (dataDirectory == "" ? ""
                : RTrim(dataDirectory, "\/") "\") "variables.json"
        }
        if !controlExplicit
            controlPath := (dataDirectory == "" ? ""
                : RTrim(dataDirectory, "\/") "\") "control-requests.json"
        return {Command: command, ScriptPath: scriptPath,
            VariablePath: variablePath,
            ControlPath: controlPath, Pretty: pretty}
    }

    ListRules(parsed) {
        this.RequireArguments(parsed.Command, 1, "list")
        repository := MappingCodeRepository(parsed.ScriptPath)
        rows := []
        for order, mapping in repository.Load() {
            rows.Push(Map("order", order, "id", mapping.Id,
                "mode", mapping.Mode, "enabled", JsonBoolean(mapping.Enabled),
                "source", mapping.Source, "target", mapping.Target,
                "scope", mapping.Scope, "purpose", mapping.Purpose))
        }
        this.WriteJson(Map("rules", rows, "count", rows.Length),
            parsed.Pretty)
        return 0
    }

    ValidatePackage(parsed) {
        this.RequireArguments(parsed.Command, 2,
            "validate <package-path>")
        package := RulePackageService().Read(parsed.Command[2])
        this.WriteJson(Map("valid", JsonBoolean(true),
            "rules", package["rules"].Length,
            "digest", package["digest"]), parsed.Pretty)
        return 0
    }

    ExportRules(parsed) {
        this.RequireArguments(parsed.Command, 2, "export <package-path>")
        repository := MappingCodeRepository(parsed.ScriptPath)
        result := RulePackageService().ExportTo(parsed.Command[2],
            repository.Load())
        this.WriteJson(Map("path", result.Path, "rules", result.Rules,
            "digest", result.Digest), parsed.Pretty)
        return 0
    }

    ImportRules(parsed) {
        this.RequireArguments(parsed.Command, 2,
            "import <package-path> [skip|replace|rename]", 3)
        policy := parsed.Command.Length >= 3 ? parsed.Command[3] : "skip"
        repository := MappingCodeRepository(parsed.ScriptPath)
        packageService := RulePackageService()
        package := packageService.Read(parsed.Command[2])
        mappingLease := CrossProcessWriteLock.Acquire(repository.ScriptPath)
        try {
            beforeMapping := repository.ReadRegionBody()
            try {
                result := packageService.ImportPackage(package, repository,
                    policy)
            } catch as importError {
                rollbackMessage := this.RestoreImportState(repository,
                    beforeMapping)
                if rollbackMessage != ""
                    throw Error("规则包导入失败，且回滚失败："
                        importError.Message "；" rollbackMessage)
                throw importError
            }
        } finally mappingLease.Release()
        this.WriteJson(Map("imported", result.Imported,
            "replaced", result.Replaced, "renamed", result.Renamed,
            "skipped", result.Skipped, "ids", result.Ids,
            "digest", result.Digest,
            "notification", this.NotifyApplication(parsed,
                "package_import")), parsed.Pretty)
        return 0
    }

    SetRuleEnabled(parsed, enabled) {
        this.RequireArguments(parsed.Command, 2,
            (enabled ? "enable" : "disable") " <rule-id>")
        repository := MappingCodeRepository(parsed.ScriptPath)
        mapping := repository.GetById(parsed.Command[2])
        changed := mapping.Enabled != !!enabled
        if changed
            mapping := repository.ToggleEnabled(mapping.Id)
        notification := changed
            ? this.NotifyApplication(parsed,
                enabled ? "rule_enabled" : "rule_disabled")
            : Map("queued", JsonBoolean(false), "reason", "unchanged")
        this.WriteJson(Map("id", mapping.Id,
            "enabled", JsonBoolean(mapping.Enabled),
            "changed", JsonBoolean(changed),
            "mode", mapping.Mode, "notification", notification),
            parsed.Pretty)
        return 0
    }

    RestoreImportState(repository, mappingState) {
        failures := []
        try {
            currentMapping := repository.ReadRegionBody()
            if currentMapping != mappingState
                repository.WriteRegionBody(mappingState, currentMapping)
        } catch as mappingRestoreError {
            failures.Push("映射代码回滚失败：" mappingRestoreError.Message)
        }
        message := ""
        for failure in failures
            message .= (message == "" ? "" : "；") failure
        return message
    }

    ShowConflicts(parsed) {
        this.RequireArguments(parsed.Command, 1, "conflicts")
        repository := MappingCodeRepository(parsed.ScriptPath)
        graph := RuleConflictAnalyzer().BuildGraph(repository.Load())
        graph["count"] := graph["issues"].Length
        this.WriteJson(graph, parsed.Pretty)
        return graph["issues"].Length ? 3 : 0
    }

    SimulateRules(parsed) {
        this.RequireArguments(parsed.Command, 2,
            "simulate <event-json> [context-json]", 3)
        event := JsonCodec.Parse(parsed.Command[2])
        context := parsed.Command.Length >= 3
            ? JsonCodec.Parse(parsed.Command[3]) : Map()
        if Type(context) != "Map"
            throw Error("simulate context-json 必须是对象。")
        result := RuleSimulationService().Simulate(
            MappingCodeRepository(parsed.ScriptPath).Load(), event, context)
        this.WriteJson(result, parsed.Pretty)
        return 0
    }

    ShowCapabilities(parsed) {
        this.RequireArguments(parsed.Command, 1, "capabilities")
        capabilities := this.ResolveBackendCapabilities()
        this.WriteJson(capabilities, parsed.Pretty)
        return 0
    }

    ShowDevices(parsed) {
        this.RequireArguments(parsed.Command, 1, "devices")
        service := RawInputService(A_ScriptHwnd, (*) => 0)
        devices := service.EnumerateDevices()
        this.WriteJson(Map("devices", devices, "count", devices.Length,
            "identity_scope", "raw-input",
            "selective_suppression", JsonBoolean(false)), parsed.Pretty)
        return 0
    }

    ResolveBackendCapabilities() {
        return RawInputBackend.Describe()
    }

    LintRules(parsed) {
        this.RequireArguments(parsed.Command, 1, "lint")
        repository := MappingCodeRepository(parsed.ScriptPath)
        repository.ValidateScriptSyntax(parsed.ScriptPath)
        snapshot := repository.ReadSnapshot()
        analysis := this.AnalyzeManagedFormatting(snapshot)
        graph := RuleConflictAnalyzer().BuildGraph(snapshot.Mappings)
        warnings := []
        if analysis.MigrationCount
            warnings.Push(Map("code", "migration_required",
                "count", analysis.MigrationCount))
        if analysis.FormatCount
            warnings.Push(Map("code", "format_required",
                "count", analysis.FormatCount))
        issueCount := graph["issues"].Length + warnings.Length
        this.WriteJson(Map("valid", JsonBoolean(issueCount == 0),
            "rules", snapshot.Mappings.Length,
            "conflicts", graph["issues"], "warnings", warnings,
            "issue_count", issueCount), parsed.Pretty)
        return issueCount ? 3 : 0
    }

    FormatRules(parsed, migrateOnly) {
        this.RequireArguments(parsed.Command, 1,
            migrateOnly ? "migrate" : "format")
        repository := MappingCodeRepository(parsed.ScriptPath)
        snapshot := repository.ReadSnapshot()
        changed := 0
        migrated := 0
        for index, mapping in snapshot.Mappings {
            if mapping.Mode != "managed"
                continue
            migration := RuleCompiler.ParseManagedSpecDetailed(mapping.Block)
            canonicalBlock := RuleCompiler.BuildManagedBlock(migration.Spec,
                snapshot.Region.Eol)
            needsChange := migrateOnly ? migration.Changed
                : canonicalBlock != mapping.Block
            if !needsChange
                continue
            snapshot.Mappings[index] := repository.ParseMappings(
                canonicalBlock)[1]
            changed++
            if migration.Changed
                migrated++
        }
        if changed
            repository.Rewrite(snapshot.Mappings, snapshot)
        notification := changed
            ? this.NotifyApplication(parsed,
                migrateOnly ? "rules_migrated" : "rules_formatted")
            : Map("queued", JsonBoolean(false), "reason", "unchanged")
        this.WriteJson(Map("changed", changed, "migrated", migrated,
            "mode", migrateOnly ? "migrate" : "format",
            "notification", notification), parsed.Pretty)
        return 0
    }

    AnalyzeManagedFormatting(snapshot) {
        migrationCount := 0
        formatCount := 0
        for mapping in snapshot.Mappings {
            if mapping.Mode != "managed"
                continue
            migration := RuleCompiler.ParseManagedSpecDetailed(mapping.Block)
            if migration.Changed
                migrationCount++
            canonicalBlock := RuleCompiler.BuildManagedBlock(migration.Spec,
                snapshot.Region.Eol)
            if canonicalBlock != mapping.Block
                formatCount++
        }
        return {MigrationCount: migrationCount, FormatCount: formatCount}
    }

    Diagnose(parsed) {
        this.RequireArguments(parsed.Command, 1,
            "diagnose [output-path]", 2)
        repository := MappingCodeRepository(parsed.ScriptPath)
        variables := ScopedVariableStore(parsed.VariablePath)
        mappings := repository.Load()
        devices := RawInputService(A_ScriptHwnd, (*) => 0).EnumerateDevices()
        capabilities := this.ResolveBackendCapabilities()
        conflicts := RuleConflictAnalyzer().BuildGraph(mappings)
        desktopContext := WindowsContextService().Build(variables, devices)
        context := Map(
            "application", Map("version", this.ReadVersion(parsed),
                "runtime", A_AhkVersion, "compiled", JsonBoolean(A_IsCompiled)),
            "configuration", Map("script_path", parsed.ScriptPath,
                "variables_path", parsed.VariablePath,
                "rule_count", mappings.Length,
                "conflict_count", conflicts["issues"].Length),
            "backend", capabilities, "devices", devices,
            "desktop", desktopContext)
        preview := DiagnosticBundleService().CreatePreview(context, [])
        if parsed.Command.Length >= 2 {
            outputPath := parsed.Command[2]
            DiagnosticBundleService().ExportPreview(preview, outputPath)
            this.WriteJson(Map("path", outputPath,
                "event_count", preview.EventCount,
                "redaction_counts", preview.Counts), parsed.Pretty)
        } else
            this.WriteJson(preview.Bundle, parsed.Pretty)
        return 0
    }

    ShowVersion(parsed) {
        this.RequireArguments(parsed.Command, 1, "version")
        this.WriteJson(Map("name", "KeyMouseRemapperAssistant",
            "version", this.ReadVersion(parsed),
            "runtime", A_AhkVersion,
            "rulespec_schema", RuleSpec.CurrentSchema,
            "package_schema", RulePackageService.Schema,
            "compiled", JsonBoolean(A_IsCompiled)), parsed.Pretty)
        return 0
    }

    ReadVersion(parsed) {
        scriptDirectory := ""
        SplitPath(parsed.ScriptPath, , &scriptDirectory)
        candidates := [scriptDirectory "\VERSION", A_WorkingDir "\VERSION",
            A_ScriptDir "\VERSION", A_ScriptDir "\..\..\VERSION"]
        for versionPath in candidates {
            try {
                if !FileExist(versionPath)
                    continue
                version := Trim(BoundedFileReader.ReadUtf8(versionPath,
                    128, 128, "版本文件"))
            }
            catch
                continue
            if RegExMatch(version,
                    "^(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)$")
                return version
        }
        return "unknown"
    }

    NotifyApplication(parsed, reason) {
        try {
            request := ApplicationControlQueue(parsed.ControlPath).Publish(
                "apply", parsed.ScriptPath, Map(
                    "reason", String(reason)))
            return Map("queued", JsonBoolean(true),
                "request_id", request["id"])
        } catch as notificationError {
            return Map("queued", JsonBoolean(false),
                "error", notificationError.Message)
        }
    }

    ManageVariables(parsed) {
        store := ScopedVariableStore(parsed.VariablePath)
        operation := parsed.Command.Length >= 2
            ? StrLower(parsed.Command[2]) : "list"
        changed := operation != "list"
        switch operation {
            case "list":
                this.RequireArguments(parsed.Command, 1,
                    "variables [list]", 2)
            case "set":
                this.RequireArguments(parsed.Command, 5,
                    "variables set <transient|persistent> <name> <json-value>")
                scope := parsed.Command[3]
                name := parsed.Command[4]
                value := JsonCodec.Parse(parsed.Command[5])
                store.Set(name, value, scope)
            case "clear":
                this.RequireArguments(parsed.Command, 4,
                    "variables clear <transient|persistent> <name|--all>")
                scope := parsed.Command[3]
                name := parsed.Command[4]
                if name == "--all"
                    store.ClearScope(scope)
                else
                    store.Clear(name, scope)
            default: throw Error("未知 variables 操作：" operation)
        }
        document := Map("scopes", store.GetSnapshot(),
            "effective", store.BuildContext())
        if changed
            document["notification"] := this.NotifyApplication(parsed,
                "variables_changed")
        this.WriteJson(document, parsed.Pretty)
        return 0
    }

    RequireArguments(arguments, minimumLength, usage,
            maximumLength := minimumLength) {
        if arguments.Length < minimumLength
                || arguments.Length > maximumLength
            throw Error("用法：" usage)
    }

    WriteJson(value, pretty := false) {
        this.OutputCallback.Call(JsonCodec.Stringify(value, !!pretty, true))
    }

    WriteHelp() {
        this.OutputCallback.Call(
            "Keyboard & Mouse Remapper Assistant CLI`n"
            . "  list [--pretty]`n"
            . "  validate <package-path>`n"
            . "  export <package-path>`n"
            . "  import <package-path> [skip|replace|rename]`n"
            . "  enable|disable <rule-id>`n"
            . "  conflicts`n"
            . "  simulate <event-json> [context-json]`n"
            . "  capabilities`n"
            . "  devices`n"
            . "  lint | format | migrate`n"
            . "  diagnose [output-path]`n"
            . "  version`n"
            . "  variables [list|set|clear]`n"
            . "Global options: --script <path> --variables-path <path> "
            . "--control-path <path> --pretty")
    }
}
