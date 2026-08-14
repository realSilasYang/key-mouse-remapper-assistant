class ScriptRuleSpec {
    static MaximumCodeCharacters := 400 * 1024

    static Normalize(value) {
        if Type(value) != "Map"
            throw TypeError("脚本规则必须是 JSON 对象。")
        source := RuleSpec.Clone(value)
        RuleSpec.ValidateKnownFields(source,
            ["id", "enabled", "display", "code"],
            "脚本规则")
        id := RuleSpec.NormalizeId(
            RuleSpec.ReadRequiredString(source, "id"), "脚本规则名称")
        code := ScriptRuleSpec.NormalizeCode(
            RuleSpec.ReadRequiredString(source, "code"))
        if StrLen(code) > ScriptRuleSpec.MaximumCodeCharacters
            throw Error("脚本规则源码超过大小上限。")
        display := source.Has("display")
            ? RuleSpec.NormalizeDisplay(RuleSpec.ReadMap(source, "display"))
            : ScriptRuleSpec.InferDisplay(code)
        spec := Map("id", id, "display", display, "code", code)
        if !RuleSpec.ReadBoolean(source, "enabled", true)
            spec["enabled"] := JsonBoolean(false)
        return spec
    }

    static FromCode(id, code, existingSpec := "") {
        code := ScriptRuleSpec.NormalizeCode(code)
        display := IsObject(existingSpec) && Type(existingSpec) == "Map"
                && existingSpec.Has("display")
            ? RuleSpec.Clone(existingSpec["display"])
            : ScriptRuleSpec.InferDisplay(code)
        spec := Map("id", String(id), "display", display, "code", code)
        if IsObject(existingSpec) && Type(existingSpec) == "Map"
                && existingSpec.Has("enabled")
                && !RuleSpec.ReadBoolean(existingSpec, "enabled", true)
            spec["enabled"] := JsonBoolean(false)
        return ScriptRuleSpec.Normalize(spec)
    }

    static NormalizeCode(code) {
        normalized := StrReplace(String(code), "`r`n", "`n")
        normalized := StrReplace(normalized, "`r", "`n")
        normalized := Trim(normalized, "`n")
        if Trim(normalized, " `t`n") == ""
            throw Error("脚本规则源码不能为空。")
        return normalized
    }

    static InferDisplay(code) {
        hotkeys := ScriptRuleSpec.FindHotkeyLabels(code, 4)
        source := hotkeys.Length ? ScriptRuleSpec.Join(hotkeys, " / ")
            : "AHK v2 脚本"
        return Map("source", source, "target", "自定义 AHK v2 逻辑",
            "scope", "全局")
    }

    static FindHotkeyLabels(code, maximum := 4) {
        labels := []
        seen := Map()
        for declaration in ScriptRuleSpec.FindHotkeyDeclarations(code) {
            signature := StrLower(RegExReplace(declaration.Label, "\s+"))
            if seen.Has(signature)
                continue
            seen[signature] := true
            labels.Push(declaration.Label)
            if maximum > 0 && labels.Length >= maximum
                break
        }
        return labels
    }

    static FindHotkeyDeclarations(code) {
        labels := []
        seen := Map()
        context := ""
        Loop Parse code, "`n" {
            line := Trim(A_LoopField)
            if line == "" || SubStr(line, 1, 1) == ";"
                continue
            if RegExMatch(line, "i)^#HotIf(?:\s+(.*?))?\s*$",
                    &directiveMatch) {
                context := directiveMatch[1] == ""
                    ? "" : Trim(directiveMatch[1])
                continue
            }
            if !RegExMatch(line, "^([^:={}]+?)::", &match)
                continue
            label := Trim(match[1])
            eventName := RegExMatch(label, "i)\s+Up$") ? "up" : "down"
            signature := StrLower(RegExReplace(label, "\s+")) "|"
                . StrLower(RegExReplace(context, "\s+"))
            if seen.Has(signature)
                continue
            seen[signature] := true
            labels.Push({Label: label, Event: eventName, Context: context,
                Line: A_Index})
        }
        return labels
    }

    static Join(values, separator) {
        result := ""
        for value in values
            result .= (result == "" ? "" : separator) String(value)
        return result
    }
}
