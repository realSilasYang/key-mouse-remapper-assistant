class RuleCompiler {
    static ManagedTypeName := "规则块"
    static ScriptTypeName := "受托管独立脚本"
    static ManagedSpecPlaceholder := "<请在这里填写 RuleSpec JSON>"

    static TypeNameFromMode(mode) {
        mode := StrLower(Trim(String(mode)))
        if mode == "managed"
            return this.ManagedTypeName
        if mode == "script"
            return this.ScriptTypeName
        throw Error("未知内部规则类型：" mode)
    }

    static ModeFromTypeName(typeName) {
        typeName := String(typeName)
        if typeName == this.ManagedTypeName
            return "managed"
        if typeName == this.ScriptTypeName
            return "script"
        throw Error("不支持的规则类型：" typeName)
    }

    static Compile(specValue) {
        spec := RuleSpec.Normalize(specValue)
        from := spec["from"]
        hotkeyName := from.Get("hotkey", "")
        if hotkeyName == ""
            hotkeyName := this.BuildHotkeyName(from)
        return {
            Id: spec["id"], Enabled: spec.Get("enabled", JsonBoolean(true)).Value,
            Priority: spec.Get("priority", 0),
            StopProcessing: spec.Get("stop_processing",
                JsonBoolean(true)).Value,
            Hotkey: hotkeyName,
            Source: spec["display"]["source"],
            Target: spec["display"]["target"],
            Scope: spec["display"].Get("scope", "全局"),
            Spec: spec
        }
    }

    static BuildHotkeyName(from) {
        if !from.Has("key")
            return from.Get("simultaneous", []).Length
                ? this.BuildSimultaneousHotkey(from["simultaneous"]) : ""
        prefixes := Map("Ctrl", "^", "Shift", "+", "Alt", "!", "Win", "#",
            "LCtrl", "<^", "RCtrl", ">^",
            "LShift", "<+", "RShift", ">+", "LAlt", "<!", "RAlt", ">!",
            "LWin", "<#", "RWin", ">#")
        result := from.Get("optional_modifiers", []).Length ? "*" : ""
        modifiers := from.Get("modifiers", []).Clone()
        this.SortModifiers(modifiers)
        for modifier in modifiers {
            if !prefixes.Has(modifier)
                throw Error("无法生成热键，未知修饰键：" modifier)
            result .= prefixes[modifier]
        }
        result .= this.BuildKeyHotkey(from["key"])
        if from.Get("event", "down") == "up"
            result .= " Up"
        return result
    }

    static BuildSimultaneousHotkey(keys) {
        if Type(keys) != "Array" || keys.Length < 2
            throw Error("A simultaneous source needs at least two keys.")
        prefixes := Map("Ctrl", "^", "Shift", "+", "Alt", "!", "Win", "#",
            "LCtrl", "<^", "RCtrl", ">^", "LShift", "<+", "RShift", ">+",
            "LAlt", "<!", "RAlt", ">!", "LWin", "<#", "RWin", ">#")
        primaryIndex := this.GetSimultaneousPrimaryIndex(keys)
        modifierNames := []
        for index, key in keys {
            if index == primaryIndex
                continue
            name := key["name"]
            if this.IsModifierName(name)
                modifierNames.Push(name)
        }
        this.SortModifiers(modifierNames)
        result := ""
        for modifierName in modifierNames {
            if !prefixes.Has(modifierName)
                throw Error("Unknown simultaneous modifier: " modifierName)
            result .= prefixes[modifierName]
        }
        return result this.BuildKeyHotkey(keys[primaryIndex])
    }

    static GetSimultaneousPrimaryIndex(keys) {
        index := keys.Length
        while index >= 1 {
            if !this.IsModifierName(keys[index]["name"])
                return index
            index--
        }
        return keys.Length
    }

    static IsModifierName(name) {
        return Map("Ctrl", true, "Shift", true, "Alt", true, "Win", true,
            "LCtrl", true, "RCtrl", true, "LShift", true, "RShift", true,
            "LAlt", true, "RAlt", true, "LWin", true, "RWin", true)
            .Has(String(name))
    }

    static GetManagedScriptRequirement(descriptor) {
        if !IsObject(descriptor) || !descriptor.HasOwnProp("Spec")
            return ""
        from := descriptor.Spec.Get("from", Map())
        if Type(from) != "Map" || !from.Has("key")
                || Type(from["key"]) != "Map"
            return ""
        keyName := from["key"].Get("name", "")
        if keyName == ""
            return ""
        keyName := String(keyName)
        if RegExMatch(keyName, "i)^(?:Ctrl|Control|Alt|Shift)$")
                && from.Get("event", "down") != "up"
            return "通用修饰键“" keyName
                . "”的裸热键会被 AHK 延后到松开时触发，无法作为可靠的按下事件；请改用受托管脚本并分别处理左右修饰键。"
        if StrLower(keyName) == "win"
            return "AHK 没有可同时代表左右 Win 键的中性来源键；请分别处理 LWin/RWin，或改用受托管脚本。"
        if this.IsModifierName(keyName)
                && (descriptor.Spec.Get("to_if_alone", []).Length
                    || descriptor.Spec.Get("to_if_held_down", []).Length)
            return "修饰键本身的短按/长按或组合放行需要按后续物理输入决定事件时序，规则块运行时无法可靠执行；请改用受托管脚本。"
        return ""
    }

    static SpecNeedsRelease(spec) {
        for fieldName in RuleSpec.ActionFields {
            actions := spec.Get(fieldName, [])
            if fieldName != "to" && actions.Length
                return true
            if fieldName == "to" {
                for action in actions
                    if action["type"] == "key_down"
                        return true
            }
        }
        return false
    }

    static SortModifiers(values) {
        ranks := Map("LCtrl", 1, "RCtrl", 2, "Ctrl", 3,
            "LShift", 4, "RShift", 5, "Shift", 6,
            "LAlt", 7, "RAlt", 8, "Alt", 9,
            "LWin", 10, "RWin", 11, "Win", 12)
        if values.Length < 2
            return values
        Loop values.Length - 1 {
            leftIndex := A_Index
            Loop values.Length - leftIndex {
                rightIndex := leftIndex + A_Index
                if ranks[values[leftIndex]] <= ranks[values[rightIndex]]
                    continue
                temporary := values[leftIndex]
                values[leftIndex] := values[rightIndex]
                values[rightIndex] := temporary
            }
        }
        return values
    }

    static NormalizeHotkeySignature(hotkeyName) {
        name := RegExReplace(Trim(String(hotkeyName)), "i)\s+Up$")
        name := RegExReplace(name, "\s+", "")
        wildcard := ""
        modifiers := []
        position := 1
        while position <= StrLen(name) {
            character := SubStr(name, position, 1)
            if character == "$" || character == "~" {
                position++
                continue
            }
            if character == "*" {
                wildcard := "*"
                position++
                continue
            }
            prefix := ""
            if (character == "<" || character == ">")
                    && position < StrLen(name) {
                nextCharacter := SubStr(name, position + 1, 1)
                if InStr("^+!#", nextCharacter, true) {
                    prefix := character nextCharacter
                    position += 2
                }
            }
            if prefix == "" && InStr("^+!#", character, true) {
                prefix := character
                position++
            }
            if prefix == ""
                break
            modifiers.Push(prefix)
        }
        ranks := Map("<^", 1, ">^", 2, "^", 3,
            "<+", 4, ">+", 5, "+", 6,
            "<!", 7, ">!", 8, "!", 9,
            "<#", 10, ">#", 11, "#", 12)
        if modifiers.Length > 1 {
            Loop modifiers.Length - 1 {
                leftIndex := A_Index
                Loop modifiers.Length - leftIndex {
                    rightIndex := leftIndex + A_Index
                    if ranks[modifiers[leftIndex]]
                            <= ranks[modifiers[rightIndex]]
                        continue
                    temporary := modifiers[leftIndex]
                    modifiers[leftIndex] := modifiers[rightIndex]
                    modifiers[rightIndex] := temporary
                }
            }
        }
        result := wildcard
        for modifier in modifiers
            result .= modifier
        return StrLower(result SubStr(name, position))
    }

    static BuildKeyHotkey(key) {
        if key.Has("sc") && key["sc"] != ""
            return "sc" key["sc"]
        if key.Has("vk") && key["vk"] != ""
            return "vk" key["vk"]
        return key["name"]
    }

    static SortStrings(values) {
        if values.Length < 2
            return
        Loop values.Length - 1 {
            leftIndex := A_Index
            Loop values.Length - leftIndex {
                rightIndex := leftIndex + A_Index
                if StrCompare(values[leftIndex], values[rightIndex], true) <= 0
                    continue
                temporary := values[leftIndex]
                values[leftIndex] := values[rightIndex]
                values[rightIndex] := temporary
            }
        }
    }

    static BuildManagedBlock(specValue, eol := "`r`n") {
        spec := RuleSpec.Normalize(specValue)
        persistedSpec := RuleSpec.Clone(spec)
        persistedSpec.Delete("id")
        persistedSpec.Delete("display")
        canonical := JsonCodec.Stringify(persistedSpec, true, true)
        display := spec["display"]
        lines := ["; @mapping-begin",
            this.MetadataCommentLine("名称"),
            "; @名称=" this.EncodeMetadataValue(spec["id"]),
            this.MetadataCommentLine("类型"),
            "; @类型=" this.TypeNameFromMode("managed"),
            this.MetadataCommentLine("来源按键"),
            "; @来源按键=" this.EncodeMetadataValue(display["source"]),
            this.MetadataCommentLine("映射结果"),
            "; @映射结果=" this.EncodeMetadataValue(display["target"]),
            this.MetadataCommentLine("生效范围"),
            "; @生效范围=" this.EncodeMetadataValue(
                display.Get("scope", "全局")),
            "; 下面是规则的详细设置，包括触发方式、生效条件、时间判定和执行动作。",
            "; @spec-begin"]
        for annotatedLine in this.BuildAnnotatedSpecLines(canonical)
            lines.Push("; " annotatedLine)
        lines.Push("; @spec-end", "; @generated-begin",
            "; 请让开头的内容摘要与上面的详细设置保持一致。",
            "; 小助手会直接读取并运行这些设置，不需要另写 AHK 脚本。",
            "; @generated-end", "; @mapping-end")
        result := ""
        for index, line in lines
            result .= (index > 1 ? eol : "") line
        return result
    }

    static BuildBlankManagedBlock(eol := "`r`n") {
        lines := ["; @mapping-begin",
            this.MetadataCommentLine("名称"),
            "; @名称=<请填写规则名称>",
            this.MetadataCommentLine("类型"),
            "; @类型=" this.ManagedTypeName,
            this.MetadataCommentLine("来源按键"),
            "; @来源按键=<请填写来源按键>",
            this.MetadataCommentLine("映射结果"),
            "; @映射结果=<请填写映射结果>",
            this.MetadataCommentLine("生效范围"),
            "; @生效范围=<请填写生效范围>",
            "; 下面填写规则的详细设置。请用完整的 RuleSpec JSON 替换占位文字。",
            "; @spec-begin",
            "; " this.ManagedSpecPlaceholder,
            "; @spec-end", "; @generated-begin",
            "; 小助手会直接读取并运行上面的设置，不需要另写 AHK 脚本。",
            "; @generated-end", "; @mapping-end"]
        return this.JoinLines(lines, eol)
    }

    static JoinLines(lines, eol := "`r`n") {
        result := ""
        for index, line in lines
            result .= (index > 1 ? eol : "") line
        return result
    }

    static MetadataCommentLine(name) {
        static comments := Map(
            "名称", "给这条规则起一个容易辨认的名称；它会显示在主界面中。",
            "类型", "选择规则的写法；请保留下方已有的类型名称。",
            "来源按键", "写清楚按下什么键或鼠标按键会触发这条规则。",
            "映射结果", "写清楚触发后会执行什么按键、鼠标操作或命令。",
            "生效范围", "写清楚规则在哪里有效，例如“全局”或某个程序。")
        if !comments.Has(name)
            throw ValueError("未知元数据注释字段：" name)
        return "; " comments[name]
    }

    static BuildAnnotatedSpecLines(canonicalJson) {
        lines := []
        Loop Parse canonicalJson, "`n", "`r" {
            line := A_LoopField
            if RegExMatch(line, '^(\s*)"([a-z_]+)"\s*:', &fieldMatch)
                lines.Push(fieldMatch[1] "// "
                    . this.SpecFieldComment(fieldMatch[2]))
            lines.Push(line)
        }
        return lines
    }

    static SpecFieldComment(name) {
        static comments := Map(
            "enabled", "控制规则是否生效：true 为启用，false 为暂停。",
            "passthrough", "设为 true 后，来源按键原本的输入仍会传给系统。",
            "priority", "多条规则同时符合时，数值越大越先处理。",
            "stop_processing", "设为 true 后，匹配成功便不再检查优先级更低的规则。",
            "description", "留给维护者的补充说明，不参与规则判断。",
            "from", "说明什么键盘或鼠标输入会触发这条规则。",
            "conditions", "列出这一层包含的生效条件。",
            "to", "来源按键触发时，立即执行这些动作。",
            "to_if_alone", "来源按键单独短按时，执行这些动作。",
            "to_if_held_down", "来源按键按住达到判定时间后，执行这些动作。",
            "to_after_key_up", "来源按键松开后，执行这些动作。",
            "timing", "设置长按等需要计时判断的参数。",
            "hotkey", "用 AHK 热键写法表示触发按键或组合键。",
            "key", "指定作为主要触发来源的单个按键。",
            "simultaneous", "列出必须一起按下才能触发的多个按键。",
            "modifiers", "列出触发时必须按住的 Ctrl、Shift、Alt 或 Win 键。",
            "optional_modifiers", "列出允许同时按住、但不作为触发条件的修饰键。",
            "sequence", "列出需要按先后顺序输入的按键。",
            "event", "选择按下（down）还是松开（up）时触发。",
            "repeat", "决定长按产生自动重复时，是允许、忽略还是只响应重复。",
            "tap_count", "指定连续按几次才触发。",
            "name", "填写 AHK 能识别的按键名称。",
            "kind", "说明输入来自键盘、鼠标、滚轮还是应用命令。",
            "vk", "填写 Windows 虚拟键码，用于精确识别按键。",
            "sc", "填写键盘扫描码，用于区分物理位置不同的按键。",
            "extended", "说明该按键是否带有 Windows 扩展键标记。",
            "command", "填写浏览器、媒体键等按键对应的应用命令编号。",
            "type", "选择这一项属于哪一种条件或执行动作。",
            "negate", "设为 true 后，条件成立与不成立的结果会对调。",
            "condition", "填写需要由 not 取反的那一个条件。",
            "operator", "选择条件值如何比较，例如相等、包含或正则匹配。",
            "case_sensitive", "设为 true 后，文字比较会区分大小写。",
            "field", "指定要检查的程序、窗口、输入法或会话信息。",
            "value", "填写要比较的内容，或动作实际使用的参数。",
            "repeat_interval_ms", "填写动作重复执行的间隔，单位为毫秒。",
            "held_threshold_ms", "按住达到这个时长后才算长按，单位为毫秒。")
        return comments.Has(name) ? comments[name]
            : "填写 “" name "” 在这条规则中需要使用的值。"
    }

    static EncodeMetadataValue(value) {
        encoded := StrReplace(String(value), "%", "%25")
        encoded := StrReplace(encoded, "`r", "%0D")
        return StrReplace(encoded, "`n", "%0A")
    }

    static ParseManagedSpec(blockText) {
        return RuleSpec.Normalize(this.ParseManagedSpecValue(blockText))
    }

    static ParseManagedSpecValue(blockText,
            rejectConflictingEmbeddedMetadata := false) {
        this.ValidateManagedBlockEnvelope(blockText)
        pattern := "ms)^; @spec-begin\R(.*?)^; @spec-end[^\r\n]*"
        if !RegExMatch(blockText, pattern, &match)
            throw Error("规则块缺少 @spec-begin/@spec-end。")
        if InStr(match[1], this.ManagedSpecPlaceholder)
            throw Error("请先用完整的 RuleSpec JSON 替换规则设置占位文字。")
        jsonText := ""
        Loop Parse match[1], "`n", "`r" {
            line := RegExReplace(A_LoopField, "^; ?")
            if RegExMatch(line, "^\s*//(?:\s|$)")
                continue
            jsonText .= (A_Index > 1 ? "`n" : "") line
        }
        parsedSpec := JsonCodec.Parse(jsonText)
        if Type(parsedSpec) != "Map"
            throw TypeError("规则块的 RuleSpec 正文必须是 JSON 对象。")
        fields := this.ParseMetadata(blockText)
        if this.RequiredMetadata(fields, "类型") != this.ManagedTypeName
            throw Error("规则块的 @类型 必须为“"
                this.ManagedTypeName "”。")
        metadataId := this.RequiredMetadata(fields, "名称")
        metadataDisplay := Map(
            "source", this.RequiredMetadata(fields, "来源按键"),
            "target", this.RequiredMetadata(fields, "映射结果"),
            "scope", this.RequiredMetadata(fields, "生效范围", true))
        if rejectConflictingEmbeddedMetadata
            this.ValidateEmbeddedMetadata(parsedSpec, metadataId,
                metadataDisplay)
        parsedSpec["id"] := metadataId
        parsedSpec["display"] := metadataDisplay
        return parsedSpec
    }

    static ValidateEmbeddedMetadata(parsedSpec, metadataId, metadataDisplay) {
        if parsedSpec.Has("id") && (IsObject(parsedSpec["id"])
                || String(parsedSpec["id"]) != metadataId)
            throw Error("规则正文中的 id 与顶部 @名称 不一致。")
        if !parsedSpec.Has("display")
            return true
        embeddedDisplay := parsedSpec["display"]
        if Type(embeddedDisplay) != "Map"
            throw TypeError("规则正文中的 display 必须是 JSON 对象。")
        for fieldName in ["source", "target", "scope"] {
            if embeddedDisplay.Has(fieldName)
                    && (IsObject(embeddedDisplay[fieldName])
                        || String(embeddedDisplay[fieldName])
                            != metadataDisplay[fieldName])
                throw Error("规则正文中的 display." fieldName
                    . " 与顶部元数据不一致。")
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
                throw Error("规则块包含重复元数据：" name)
            fields[name] := this.DecodeMetadataValue(fieldMatch[2])
        }
        return fields
    }

    static DecodeMetadataValue(value) {
        decoded := StrReplace(String(value), "%0D", "`r")
        decoded := StrReplace(decoded, "%0A", "`n")
        return StrReplace(decoded, "%25", "%")
    }

    static RequiredMetadata(fields, name, allowEmpty := false) {
        if !fields.Has(name) || (!allowEmpty && fields[name] == "")
            throw Error("规则块缺少 @" name " 元数据。")
        if this.IsPlaceholderValue(fields[name])
            throw Error("请先填写 @" name "。")
        return fields[name]
    }

    static IsPlaceholderValue(value) {
        return RegExMatch(String(value), "^<请填写[^<>]+>$")
    }

    static ValidateManagedBlockEnvelope(blockText) {
        for marker in ["; @spec-begin", "; @spec-end",
                "; @generated-begin", "; @generated-end"] {
            if this.CountExactLines(blockText, marker) != 1
                throw Error("规则块标记必须恰好出现一次：" marker)
        }
        Loop Parse blockText, "`n", "`r" {
            trimmed := LTrim(A_LoopField, " `t")
            if trimmed != "" && SubStr(trimmed, 1, 1) != ";"
                throw Error("规则块不能包含额外可执行 AHK 代码。")
        }
        return true
    }

    static CountExactLines(text, expected) {
        count := 0
        Loop Parse text, "`n", "`r" {
            if A_LoopField == expected
                count++
        }
        return count
    }

    static CountMatchingLines(text, pattern) {
        count := 0
        Loop Parse text, "`n", "`r" {
            if RegExMatch(A_LoopField, pattern)
                count++
        }
        return count
    }
}
