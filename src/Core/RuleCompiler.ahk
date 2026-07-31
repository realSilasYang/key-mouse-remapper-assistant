class RuleCompiler {
    static Compile(specValue) {
        spec := RuleSpec.Normalize(specValue)
        from := spec["from"]
        hotkeyName := from["hotkey"]
        mode := "hotkey"
        if from["simultaneous"].Length
            mode := "simultaneous"
        else if from["sequence"].Length
            mode := "sequence"
        else if hotkeyName == ""
            hotkeyName := this.BuildHotkeyName(from)
        return {
            Id: spec["id"], Enabled: spec["enabled"].Value,
            Priority: spec["priority"],
            StopProcessing: spec["stop_processing"].Value,
            Mode: mode, Hotkey: hotkeyName,
            Source: spec["display"]["source"],
            Target: spec["display"]["target"],
            Scope: spec["display"]["scope"],
            Purpose: spec["display"]["purpose"],
            Spec: spec, Signature: this.GetTriggerSignature(spec),
            DispatchSignature: this.GetDispatchSignature(spec)
        }
    }

    static BuildHotkeyName(from) {
        if !from.Has("key")
            return ""
        prefixes := Map("Ctrl", "^", "Shift", "+", "Alt", "!", "Win", "#",
            "LCtrl", "<^", "RCtrl", ">^",
            "LShift", "<+", "RShift", ">+", "LAlt", "<!", "RAlt", ">!",
            "LWin", "<#", "RWin", ">#")
        result := from["optional_modifiers"].Length ? "*" : ""
        for modifier in from["modifiers"] {
            if !prefixes.Has(modifier)
                throw Error("无法生成热键，未知修饰键：" modifier)
            result .= prefixes[modifier]
        }
        result .= this.BuildKeyHotkey(from["key"])
        if from["event"] == "up"
            result .= " Up"
        return result
    }

    static GetTriggerSignature(specValue) {
        spec := RuleSpec.Normalize(specValue)
        from := spec["from"]
        if from["simultaneous"].Length
            return "sim:" this.JoinKeyNames(from["simultaneous"], true)
        if from["sequence"].Length
            return "seq:" this.JoinKeyNames(from["sequence"])
        hotkeyName := from["hotkey"] != ""
            ? from["hotkey"] : this.BuildHotkeyName(from)
        return "hotkey:" this.NormalizeHotkeySignature(hotkeyName)
    }

    static GetDispatchSignature(specValue) {
        spec := RuleSpec.Normalize(specValue)
        from := spec["from"]
        if from["simultaneous"].Length || from["sequence"].Length
            return this.GetTriggerSignature(spec)
        modifiers := from["modifiers"].Clone()
        this.SortStrings(modifiers)
        trigger := Map(
            "key", this.GetKeyIdentitySignature(from["key"]),
            "modifiers", modifiers,
            "allow_extra_modifiers",
                JsonBoolean(from["optional_modifiers"].Length > 0))
        return "simple:" JsonCodec.Stringify(trigger, false, true)
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
            if (character == "<" || character == ">")
                    && position < StrLen(name) {
                modifier := SubStr(name, position + 1, 1)
                if InStr("^+!#", modifier, true) {
                    modifiers.Push(character modifier)
                    position += 2
                    continue
                }
            }
            if InStr("^+!#", character, true) {
                modifiers.Push(character)
                position++
                continue
            }
            break
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

    static GetHotkeyPhase(hotkeyName, defaultPhase := "down") {
        return RegExMatch(Trim(String(hotkeyName)), "i)\s+Up$")
            ? "up" : StrLower(String(defaultPhase))
    }

    static JoinKeyNames(keys, sortNames := false) {
        names := []
        for key in keys
            names.Push(this.GetKeyIdentitySignature(key))
        if sortNames
            this.SortStrings(names)
        result := ""
        for index, name in names
            result .= (index > 1 ? "+" : "") name
        return result
    }

    static BuildKeyHotkey(key) {
        if key.Has("sc") && key["sc"] != ""
            return "sc" key["sc"]
        if key.Has("vk") && key["vk"] != ""
            return "vk" key["vk"]
        return key["name"]
    }

    static GetKeyIdentitySignature(key) {
        return RuleSpec.GetKeyIdentitySignature(key)
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

    static SortDescriptors(descriptors) {
        if descriptors.Length < 2
            return descriptors
        count := descriptors.Length
        source := descriptors.Clone()
        width := 1
        while width < count {
            target := []
            blockStart := 1
            while blockStart <= count {
                left := blockStart
                leftEnd := Min(blockStart + width - 1, count)
                right := leftEnd + 1
                rightEnd := Min(blockStart + 2 * width - 1, count)
                while left <= leftEnd || right <= rightEnd {
                    if right > rightEnd || (left <= leftEnd
                            && !this.HasHigherPrecedence(source[right],
                                source[left])) {
                        target.Push(source[left])
                        left++
                    } else {
                        target.Push(source[right])
                        right++
                    }
                }
                blockStart += 2 * width
            }
            source := target
            width *= 2
        }
        Loop count
            descriptors[A_Index] := source[A_Index]
        return descriptors
    }

    static HasHigherPrecedence(left, right) {
        if left.Priority != right.Priority
            return left.Priority > right.Priority
        leftOrder := left.HasOwnProp("Order") ? left.Order : 0
        rightOrder := right.HasOwnProp("Order") ? right.Order : 0
        return leftOrder < rightOrder
    }

    static BuildManagedBlock(specValue, eol := "`r`n") {
        spec := RuleSpec.Normalize(specValue)
        canonical := JsonCodec.Stringify(spec, true, true)
        digest := Sha256.HexText(canonical)
        lines := ["; @mapping-begin", "; @schema=2", "; @mode=managed",
            "; @id=" spec["id"], "; @spec-begin"]
        Loop Parse canonical, "`n", "`r"
            lines.Push("; " A_LoopField)
        lines.Push("; @spec-end", "; @generated-sha256=" digest,
            "; @generated-begin",
            "; 此规则由托管运行时注册；此区域不包含可手工编辑的 AHK 代码。",
            "; @generated-end", "; @mapping-end")
        result := ""
        for index, line in lines
            result .= (index > 1 ? eol : "") line
        return result
    }

    static ParseManagedSpec(blockText) {
        return this.ParseManagedSpecDetailed(blockText).Spec
    }

    static ParseManagedSpecDetailed(blockText) {
        this.ValidateManagedBlockEnvelope(blockText)
        pattern := "ms)^; @spec-begin\R(.*?)^; @spec-end[^\r\n]*"
        if !RegExMatch(blockText, pattern, &match)
            throw Error("托管规则缺少 @spec-begin/@spec-end。")
        jsonText := ""
        Loop Parse match[1], "`n", "`r" {
            line := RegExReplace(A_LoopField, "^; ?")
            jsonText .= (A_Index > 1 ? "`n" : "") line
        }
        parsedSpec := JsonCodec.Parse(jsonText)
        canonical := JsonCodec.Stringify(parsedSpec, true, true)
        if !RegExMatch(blockText,
                "m)^; @generated-sha256=([A-Fa-f0-9]{64})$", &hashMatch)
            throw Error("托管规则缺少有效的 @generated-sha256。")
        actual := Sha256.HexText(canonical)
        if StrUpper(hashMatch[1]) != actual
            throw Error("托管规则结构化内容的 SHA-256 校验失败。")
        return RuleSpecMigrationService.Migrate(parsedSpec)
    }

    static ValidateManagedBlockEnvelope(blockText) {
        for marker in ["; @spec-begin", "; @spec-end",
                "; @generated-begin", "; @generated-end"] {
            if this.CountExactLines(blockText, marker) != 1
                throw Error("托管规则标记必须恰好出现一次：" marker)
        }
        if this.CountMatchingLines(blockText,
                "^; @generated-sha256=") != 1
            throw Error("托管规则摘要标记必须恰好出现一次。")
        Loop Parse blockText, "`n", "`r" {
            trimmed := LTrim(A_LoopField, " `t")
            if trimmed != "" && SubStr(trimmed, 1, 1) != ";"
                throw Error("托管规则代码块不能包含额外可执行 AHK 代码。")
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
