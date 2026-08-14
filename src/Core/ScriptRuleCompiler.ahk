class ScriptRuleCompiler {
    static ScriptCodePlaceholder := "<请在这里编写完整的 AHK v2 脚本>"

    static BuildBlock(specValue, eol := "`r`n") {
        spec := ScriptRuleSpec.Normalize(specValue)
        code := spec["code"]
        display := spec["display"]
        lines := ["; @mapping-begin",
            RuleCompiler.MetadataCommentLine("名称"),
            "; @名称=" RuleCompiler.EncodeMetadataValue(spec["id"]),
            RuleCompiler.MetadataCommentLine("类型"),
            "; @类型=" RuleCompiler.TypeNameFromMode("script"),
            RuleCompiler.MetadataCommentLine("来源按键"),
            "; @来源按键=" RuleCompiler.EncodeMetadataValue(
                display["source"]),
            RuleCompiler.MetadataCommentLine("映射结果"),
            "; @映射结果=" RuleCompiler.EncodeMetadataValue(
                display["target"]),
            RuleCompiler.MetadataCommentLine("生效范围"),
            "; @生效范围=" RuleCompiler.EncodeMetadataValue(
                display.Get("scope", "全局"))]
        if !spec.Get("enabled", JsonBoolean(true)).Value
            lines.Push("; 只有暂停规则时才需要这一项；false 表示暂停，删除此项即可重新启用。",
                "; @enabled=false")
        lines.Push("", "; 下面是一份完整的 AHK v2 脚本；小助手会单独启动和停止它。",
            "; @script-code-begin")
        Loop Parse code, "`n", "`r"
            lines.Push(";  " A_LoopField)
        lines.Push("; @script-code-end", "", "; @mapping-end")
        result := ""
        for index, line in lines
            result .= (index > 1 ? eol : "") line
        return result
    }

    static BuildBlankScriptBlock(eol := "`r`n") {
        lines := ["; @mapping-begin",
            RuleCompiler.MetadataCommentLine("名称"),
            "; @名称=<请填写规则名称>",
            RuleCompiler.MetadataCommentLine("类型"),
            "; @类型=" RuleCompiler.ScriptTypeName,
            RuleCompiler.MetadataCommentLine("来源按键"),
            "; @来源按键=<请填写来源按键>",
            RuleCompiler.MetadataCommentLine("映射结果"),
            "; @映射结果=<请填写映射结果>",
            RuleCompiler.MetadataCommentLine("生效范围"),
            "; @生效范围=<请填写生效范围>", "",
            "; 下面填写一份完整的 AHK v2 脚本。请替换代码占位文字。",
            "; @script-code-begin",
            ";  " this.ScriptCodePlaceholder,
            "; @script-code-end", "", "; @mapping-end"]
        return RuleCompiler.JoinLines(lines, eol)
    }

    static ParseSpec(blockText) {
        ScriptRuleCompiler.ValidateEnvelope(blockText)
        fields := ScriptRuleCompiler.ParseMetadata(blockText)
        if ScriptRuleCompiler.RequiredMetadata(fields, "类型")
                != RuleCompiler.ScriptTypeName
            throw Error("受托管独立脚本的 @类型 必须为“"
                RuleCompiler.ScriptTypeName "”。")
        codePattern := "ms)^; @script-code-begin\R(.*?)\R"
            . "^; @script-code-end[ \t]*$"
        if !RegExMatch(blockText, codePattern, &codeMatch)
            throw Error("受托管独立脚本的 @script-code 源码区不完整。")
        codeText := ""
        Loop Parse codeMatch[1], "`n", "`r" {
            if !RegExMatch(A_LoopField, "^;  (.*)$", &codeLine)
                throw Error("脚本源码行缺少持久化注释前缀。")
            codeText .= (A_Index > 1 ? "`n" : "") codeLine[1]
        }
        if Trim(codeText) == this.ScriptCodePlaceholder
            throw Error("请先用完整的 AHK v2 脚本替换代码占位文字。")
        specValue := Map(
            "id", ScriptRuleCompiler.RequiredMetadata(fields, "名称"),
            "display", Map(
                "source", ScriptRuleCompiler.RequiredMetadata(
                    fields, "来源按键"),
                "target", ScriptRuleCompiler.RequiredMetadata(
                    fields, "映射结果"),
                "scope", ScriptRuleCompiler.RequiredMetadata(
                    fields, "生效范围", true)),
            "code", codeText)
        if fields.Has("enabled") {
            enabledText := StrLower(Trim(fields["enabled"]))
            if enabledText != "true" && enabledText != "false"
                throw Error("受托管独立脚本的 @enabled 只能是 true 或 false。")
            if enabledText == "false"
                specValue["enabled"] := JsonBoolean(false)
        }
        return ScriptRuleSpec.Normalize(specValue)
    }

    static ValidateEnvelope(blockText) {
        for marker in ["; @mapping-begin", "; @mapping-end",
                "; @script-code-begin", "; @script-code-end"] {
            if RuleCompiler.CountExactLines(blockText, marker) != 1
                throw Error("受托管独立脚本标记必须恰好出现一次：" marker)
        }
        if RuleCompiler.CountMatchingLines(blockText,
                "^; @script-spec-(?:begin|end)")
            throw Error("受托管独立脚本不再支持 @script-spec 模块。")
        Loop Parse blockText, "`n", "`r" {
            trimmed := LTrim(A_LoopField, " `t")
            if trimmed != "" && SubStr(trimmed, 1, 1) != ";"
                throw Error("受托管独立脚本持久块不能包含未编码的可执行代码。")
        }
        return true
    }

    static ParseMetadata(blockText) {
        fields := Map()
        Loop Parse blockText, "`n", "`r" {
            if !RegExMatch(A_LoopField,
                    "^; @([\p{L}\p{N}_-]+)=(.*)$", &fieldMatch)
                continue
            name := fieldMatch[1]
            if fields.Has(name)
                throw Error("受托管独立脚本包含重复元数据：" name)
            fields[name] := ScriptRuleCompiler.DecodeMetadataValue(
                fieldMatch[2])
        }
        return fields
    }

    static RequiredMetadata(fields, name, allowEmpty := false) {
        if !fields.Has(name) || (!allowEmpty && fields[name] == "")
            throw Error("受托管独立脚本缺少 @" name " 元数据。")
        if RuleCompiler.IsPlaceholderValue(fields[name])
            throw Error("请先填写 @" name "。")
        return fields[name]
    }

    static DecodeMetadataValue(value) {
        decoded := StrReplace(String(value), "%0D", "`r")
        decoded := StrReplace(decoded, "%0A", "`n")
        return StrReplace(decoded, "%25", "%")
    }
}
