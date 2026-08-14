class RulePackageService {
    static Schema := 4
    static PreviousSchema := 3
    static ProfileSchema := 2
    static LegacySchema := 1
    static Kind := "key-mouse-remapper-assistant-rule-package"
    static LegacyKinds := ["key-mouse-remapper-rule-package",
        "shortcut-remapper-rule-package"]
    static MaximumPackageCharacters := 5 * 1024 * 1024
    static MaximumPackageBytes := 20 * 1024 * 1024 + 4
    static MaximumRules := 1000
    static ManifestCapabilities := ["conditions", "managed_rules",
        "script_rules"]
    static ManifestPermissions := ["generated_input", "system_control",
        "window_control", "arbitrary_code"]
    static PreviousManifestCapabilities := ["conditions", "managed_rules"]
    static PreviousManifestPermissions := ["generated_input",
        "system_control", "window_control"]

    Build(mappings) {
        if Type(mappings) != "Array"
            throw TypeError("导出规则必须是数组。")
        if mappings.Length > RulePackageService.MaximumRules
            throw Error("导出规则数量超过上限。")
        rules := []
        for mapping in mappings {
            if !mapping.HasOwnProp("Mode")
                throw Error("导出规则缺少模式。")
            if mapping.Mode == "managed"
                rules.Push(Map("mode", "managed",
                    "spec", RuleSpec.Normalize(mapping.Spec)))
            else if mapping.Mode == "script"
                rules.Push(Map("mode", "script",
                    "spec", ScriptRuleSpec.Normalize(mapping.Spec)))
            else
                throw Error("不能导出未知模式的规则：" mapping.Mode)
        }
        manifest := this.AnalyzeManifest(rules)
        version := this.ReadApplicationVersion()
        payload := Map("schema", RulePackageService.Schema,
            "kind", RulePackageService.Kind,
            "version", version,
            "source", Map("name", "键鼠重映射小助手", "version", version),
            "tags", ["keyboard", "mouse", "remapping"],
            "capabilities", manifest["capabilities"],
            "permissions", manifest["permissions"],
            "exported_at", FormatTime(A_NowUTC,
                "yyyy-MM-dd'T'HH:mm:ss'Z'"),
            "rules", rules)
        digest := Sha256.HexText(JsonCodec.Stringify(payload, false, true))
        document := RuleSpec.Clone(payload)
        document["integrity"] := Map("algorithm", "sha256",
            "digest", digest)
        return document
    }

    ExportTo(filePath, mappings) {
        document := this.Build(mappings)
        text := JsonCodec.Stringify(document, true, true) "`r`n"
        if StrLen(text) > RulePackageService.MaximumPackageCharacters
            throw Error("导出的规则包超过大小上限。")
        this.WriteAtomic(filePath, text)
        return {Path: String(filePath), Rules: mappings.Length,
            Digest: document["integrity"]["digest"]}
    }

    Parse(text) {
        text := String(text)
        if StrLen(text) > RulePackageService.MaximumPackageCharacters
            throw Error("规则包超过大小上限。")
        document := JsonCodec.Parse(text)
        if Type(document) != "Map"
            throw TypeError("规则包根值必须是对象。")
        if !document.Has("schema")
                || Type(document["schema"]) != "Integer"
            throw Error("不支持的规则包版本。")
        schema := Integer(document["schema"])
        if schema != RulePackageService.Schema
                && schema != RulePackageService.PreviousSchema
                && schema != RulePackageService.ProfileSchema
                && schema != RulePackageService.LegacySchema
            throw Error("不支持的规则包版本。")
        if schema == RulePackageService.Schema
                || schema == RulePackageService.PreviousSchema {
            this.ValidateExactFields(document, ["schema", "kind", "version",
                "source", "tags", "capabilities", "permissions",
                "exported_at", "rules", "integrity"],
                "规则包")
        } else if schema == RulePackageService.ProfileSchema {
            this.ValidateExactFields(document, ["schema", "kind", "version",
                "source", "tags", "capabilities", "permissions",
                "exported_at", "profiles", "rules", "integrity"],
                "规则包")
        }
        if !document.Has("kind")
                || !this.IsSupportedKind(document["kind"])
            throw Error("文件不是键鼠重映射小助手规则包。")
        if !document.Has("rules") || Type(document["rules"]) != "Array"
            throw Error("规则包缺少 rules 数组。")
        if document["rules"].Length > RulePackageService.MaximumRules
            throw Error("规则包中的规则数量超过上限。")
        if !document.Has("integrity")
                || Type(document["integrity"]) != "Map"
                || !document["integrity"].Has("algorithm")
                || Type(document["integrity"]["algorithm"]) != "String"
                || StrLower(document["integrity"]["algorithm"])
                    != "sha256"
                || !document["integrity"].Has("digest")
                || Type(document["integrity"]["digest"]) != "String"
            throw Error("规则包缺少 SHA-256 完整性信息。")
        if schema == RulePackageService.Schema
            this.ValidateExactFields(document["integrity"],
                ["algorithm", "digest"], "规则包 integrity")
        expectedDigest := StrUpper(document["integrity"]["digest"])
        if !RegExMatch(expectedDigest, "^[0-9A-F]{64}$")
            throw Error("规则包 SHA-256 摘要格式无效。")
        payload := RuleSpec.Clone(document)
        payload.Delete("integrity")
        actualDigest := Sha256.HexText(JsonCodec.Stringify(payload,
            false, true))
        if expectedDigest != actualDigest
            throw Error("规则包 SHA-256 完整性校验失败。")

        normalizedRules := []
        seenIds := Map()
        for ruleValue in document["rules"] {
            if Type(ruleValue) != "Map" || !ruleValue.Has("mode")
                    || Type(ruleValue["mode"]) != "String"
                throw Error("规则包包含无效规则条目。")
            mode := StrLower(ruleValue["mode"])
            if !ruleValue.Has("spec")
                throw Error("规则条目缺少 spec。")
            if schema == RulePackageService.Schema
                this.ValidateExactFields(ruleValue, ["mode", "spec"],
                    "规则条目")
            if mode == "managed"
                spec := RuleSpec.Normalize(ruleValue["spec"])
            else if mode == "script" {
                if schema != RulePackageService.Schema
                    throw Error("旧版规则包不能包含 script 规则。")
                spec := ScriptRuleSpec.Normalize(ruleValue["spec"])
            } else
                throw Error("规则包包含未知规则模式：" mode)
            ruleId := spec["id"]
            normalizedRules.Push(Map("mode", mode, "id", ruleId,
                "spec", spec))
            if seenIds.Has(ruleId)
                throw Error("规则包包含重复名称：" ruleId)
            seenIds[ruleId] := true
        }
        if schema == RulePackageService.ProfileSchema
                && Type(document["profiles"]) != "Array"
            throw TypeError("旧规则包 profiles 必须是数组。")
        inferredManifest := this.AnalyzeManifest(normalizedRules)
        if schema == RulePackageService.Schema
                || schema == RulePackageService.PreviousSchema
                || schema == RulePackageService.ProfileSchema {
            version := this.ReadRequiredManifestString(document, "version")
            source := this.NormalizeSource(document)
            tags := this.NormalizeStringArray(document, "tags")
            capabilities := this.NormalizeStringArray(document,
                "capabilities", schema == RulePackageService.Schema
                    ? RulePackageService.ManifestCapabilities
                    : (schema == RulePackageService.PreviousSchema
                        ? RulePackageService.PreviousManifestCapabilities
                        : ""))
            permissions := this.NormalizeStringArray(document,
                "permissions", schema == RulePackageService.Schema
                    ? RulePackageService.ManifestPermissions
                    : (schema == RulePackageService.PreviousSchema
                        ? RulePackageService.PreviousManifestPermissions
                        : ""))
            if schema == RulePackageService.ProfileSchema {
                capabilities := this.RemoveLegacyManifestValue(capabilities,
                    "profiles")
                permissions := this.RemoveLegacyManifestValue(permissions,
                    "profile_write")
            }
            this.ValidateExportedAt(document)
            for requiredCapability in inferredManifest["capabilities"] {
                if !this.ArrayContains(capabilities, requiredCapability)
                    throw Error("规则包能力声明不足：" requiredCapability)
            }
            for requiredPermission in inferredManifest["permissions"] {
                if !this.ArrayContains(permissions, requiredPermission)
                    throw Error("规则包权限声明不足：" requiredPermission)
            }
        } else {
            version := "legacy-1"
            source := Map("name", "legacy-rule-package",
                "version", version)
            tags := []
            capabilities := inferredManifest["capabilities"]
            permissions := inferredManifest["permissions"]
        }
        return Map("schema", RulePackageService.Schema,
            "source_schema", schema,
            "kind", RulePackageService.Kind,
            "version", version, "source", source, "tags", tags,
            "capabilities", capabilities, "permissions", permissions,
            "rules", normalizedRules,
            "digest", actualDigest)
    }

    IsSupportedKind(kind) {
        if Type(kind) != "String"
            return false
        if kind == RulePackageService.Kind
            return true
        for legacyKind in RulePackageService.LegacyKinds {
            if kind == legacyKind
                return true
        }
        return false
    }

    Read(filePath) {
        if !FileExist(filePath)
            throw Error("规则包文件不存在。")
        return this.Parse(BoundedFileReader.ReadUtf8(filePath,
            RulePackageService.MaximumPackageBytes,
            RulePackageService.MaximumPackageCharacters, "规则包"))
    }

    ImportPackage(package, repository, collisionPolicy := "skip",
            selectedRuleIds := "") {
        collisionPolicy := StrLower(Trim(String(collisionPolicy)))
        if collisionPolicy != "skip" && collisionPolicy != "replace"
                && collisionPolicy != "rename"
            throw Error("导入冲突策略必须是 skip、replace 或 rename。")
        snapshot := repository.ReadSnapshot()
        mappings := snapshot.Mappings
        indexById := Map()
        for index, mapping in mappings
            indexById[mapping.Id] := index
        imported := 0
        skipped := 0
        replaced := 0
        renamed := 0
        importedIds := []
        selected := this.NormalizeSelection(selectedRuleIds)
        selectionSkipped := 0
        for rule in package["rules"] {
            ruleId := rule["id"]
            if IsObject(selected) && !selected.Has(ruleId) {
                selectionSkipped++
                continue
            }
            collision := indexById.Has(ruleId)
            if collision && collisionPolicy == "skip" {
                skipped++
                continue
            }
            if collision && collisionPolicy == "rename" {
                newId := repository.CreateMappingName(mappings)
                rule := this.RenameRule(rule, newId, repository)
                ruleId := newId
                collision := false
                renamed++
            }
            mapping := this.BuildMapping(rule, repository,
                snapshot.Region.Eol)
            if collision {
                mappings[indexById[ruleId]] := mapping
                replaced++
            } else {
                mappings.Push(mapping)
                indexById[ruleId] := mappings.Length
                imported++
            }
            importedIds.Push(ruleId)
        }
        if imported || replaced
            repository.Rewrite(mappings, snapshot)
        return {Imported: imported, Replaced: replaced, Renamed: renamed,
            Skipped: skipped, SelectionSkipped: selectionSkipped,
            Ids: importedIds, Digest: package["digest"]}
    }

    Preview(package, selectedRuleIds := "") {
        selected := this.NormalizeSelection(selectedRuleIds)
        items := []
        selectedCount := 0
        aggregatePermissions := Map()
        for rule in package["rules"] {
            ruleManifest := this.AnalyzeManifest([rule])
            isSelected := !IsObject(selected) || selected.Has(rule["id"])
            if isSelected {
                selectedCount++
                for permission in ruleManifest["permissions"]
                    aggregatePermissions[permission] := true
            }
            items.Push(Map("id", rule["id"], "mode", rule["mode"],
                "selected", JsonBoolean(isSelected),
                "permissions", ruleManifest["permissions"],
                "capabilities", ruleManifest["capabilities"]))
        }
        permissions := []
        for permission in package["permissions"] {
            if aggregatePermissions.Has(permission)
                permissions.Push(permission)
        }
        return Map("source", RuleSpec.Clone(package["source"]),
            "version", package["version"], "tags", package["tags"],
            "rules", items, "selected_count", selectedCount,
            "total_count", items.Length, "permissions", permissions,
            "digest", package["digest"])
    }

    ValidateRuleId(ruleId) {
        return RuleSpec.NormalizeId(ruleId, "规则包规则名称")
    }

    BuildMapping(rule, repository, eol) {
        if rule["mode"] == "managed"
            block := RuleCompiler.BuildManagedBlock(rule["spec"], eol)
        else if rule["mode"] == "script"
            block := ScriptRuleCompiler.BuildBlock(rule["spec"], eol)
        else
            throw Error("无法构建未知模式的导入规则。")
        mapping := repository.ParseMappings(block)[1]
        if mapping.Mode != rule["mode"]
            throw Error("导入规则解析模式错误。")
        return mapping
    }

    RenameRule(rule, newId, repository) {
        renamedRule := RuleSpec.Clone(rule)
        renamedRule["id"] := newId
        renamedRule["spec"]["id"] := newId
        renamedRule["spec"] := renamedRule["mode"] == "managed"
            ? RuleSpec.Normalize(renamedRule["spec"])
            : ScriptRuleSpec.Normalize(renamedRule["spec"])
        return renamedRule
    }

    AnalyzeManifest(rules) {
        capabilities := Map()
        permissions := Map()
        for rule in rules {
            mode := rule.Has("mode") ? rule["mode"] : ""
            if !rule.Has("spec")
                continue
            if mode == "script" {
                capabilities["script_rules"] := true
                permissions["arbitrary_code"] := true
                continue
            }
            if mode != "managed"
                continue
            capabilities["managed_rules"] := true
            spec := rule["spec"]
            if spec.Get("conditions", []).Length
                capabilities["conditions"] := true
            for fieldName in RuleSpec.ActionFields {
                for action in spec.Get(fieldName, []) {
                    actionType := action["type"]
                    if actionType == "window_minimize"
                            || actionType == "window_close"
                        permissions["window_control"] := true
                    else if actionType == "lock_workstation"
                        permissions["system_control"] := true
                    else if actionType != "sleep"
                        permissions["generated_input"] := true
                }
            }
        }
        return Map("capabilities", this.SortedMapKeys(capabilities),
            "permissions", this.SortedMapKeys(permissions))
    }

    SortedMapKeys(values) {
        result := []
        for key in values
            result.Push(key)
        RuleCompiler.SortStrings(result)
        return result
    }

    RemoveLegacyManifestValue(values, legacyValue) {
        filtered := []
        for value in values {
            if value != legacyValue
                filtered.Push(value)
        }
        return filtered
    }

    NormalizeSelection(selectedRuleIds) {
        if Type(selectedRuleIds) != "Array"
            return ""
        selected := Map()
        for ruleId in selectedRuleIds {
            ruleId := this.ValidateRuleId(ruleId)
            selected[ruleId] := true
        }
        return selected
    }

    NormalizeSource(document) {
        if !document.Has("source") || Type(document["source"]) != "Map"
            throw Error("规则包缺少 source 来源信息。")
        source := document["source"]
        this.ValidateExactFields(source, ["name", "version"],
            "规则包 source")
        return Map("name", this.ReadRequiredManifestString(source, "name"),
            "version", this.ReadRequiredManifestString(source, "version"))
    }

    NormalizeStringArray(document, fieldName, allowedValues := "") {
        if !document.Has(fieldName) || Type(document[fieldName]) != "Array"
            throw Error("规则包缺少 " fieldName " 数组。")
        result := []
        seen := Map()
        for value in document[fieldName] {
            if Type(value) != "String"
                throw TypeError("规则包 " fieldName " 的值必须是字符串。")
            text := Trim(value)
            if text == "" || StrLen(text) > 128
                throw Error("规则包 " fieldName " 包含无效值。")
            if IsObject(allowedValues) && !this.ArrayContains(allowedValues,
                    text)
                throw Error("规则包 " fieldName " 包含未知值：" text)
            if seen.Has(text)
                throw Error("规则包 " fieldName " 包含重复值：" text)
            seen[text] := true
            result.Push(text)
        }
        return result
    }

    ReadRequiredManifestString(document, fieldName) {
        if !document.Has(fieldName)
            throw Error("规则包缺少 " fieldName "。")
        if Type(document[fieldName]) != "String"
            throw TypeError("规则包 " fieldName " 必须是字符串。")
        value := Trim(document[fieldName])
        if value == "" || StrLen(value) > 256
            throw Error("规则包 " fieldName " 无效。")
        return value
    }

    ValidateExportedAt(document) {
        exportedAt := this.ReadRequiredManifestString(document,
            "exported_at")
        if !RegExMatch(exportedAt,
                "^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})Z$",
                &parts)
            throw Error("规则包 exported_at 必须是 UTC 时间。")
        compact := parts[1] parts[2] parts[3] parts[4] parts[5] parts[6]
        try DateDiff(compact, "16010101000000", "Seconds")
        catch
            throw Error("规则包 exported_at 时间无效。")
        return exportedAt
    }

    ValidateExactFields(document, expectedFields, context) {
        if Type(document) != "Map"
            throw TypeError(context " 必须是对象。")
        expected := Map()
        for fieldName in expectedFields
            expected[fieldName] := true
        for fieldName in document {
            if !expected.Has(fieldName)
                throw Error(context " 包含未知字段：" fieldName)
        }
        for fieldName in expectedFields {
            if !document.Has(fieldName)
                throw Error(context " 缺少 " fieldName "。")
        }
        return true
    }

    ArrayContains(values, expected) {
        for value in values {
            if value == expected
                return true
        }
        return false
    }

    ReadApplicationVersion() {
        try {
            versionPath := A_ScriptDir "\VERSION"
            if !FileExist(versionPath)
                return "unknown"
            version := Trim(BoundedFileReader.ReadUtf8(versionPath,
                128, 128, "版本文件"))
            if RegExMatch(version,
                    "^(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)$")
                return version
        }
        return "unknown"
    }

    WriteAtomic(filePath, text) {
        filePath := CrossProcessWriteLock.NormalizePath(filePath)
        directory := ""
        SplitPath(filePath, , &directory)
        if directory != "" && !DirExist(directory)
            DirCreate(directory)
        writeLease := CrossProcessWriteLock.Acquire(filePath)
        temporaryPath := filePath ".tmp-" A_TickCount "-"
            . Format("{:08X}", Random(0, 0xFFFFFFFF))
        output := ""
        try {
            output := FileOpen(temporaryPath, "w", "UTF-8-RAW")
            if !IsObject(output)
                throw Error("无法创建规则包。")
            output.Write(String(text))
            output.Close()
            output := ""
            FileMove(temporaryPath, filePath, 1)
        } catch as writeError {
            if IsObject(output)
                try output.Close()
            if FileExist(temporaryPath)
                try FileDelete(temporaryPath)
            throw writeError
        } finally writeLease.Release()
        return true
    }
}
