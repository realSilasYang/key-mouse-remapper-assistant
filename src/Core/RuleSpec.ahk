class RuleSpec {
    static ActionFields := ["to", "to_if_alone", "to_if_held_down",
        "to_after_key_up"]
    static MaximumIdLength := 128
    static MaximumDescriptionLength := 2000
    ; A full simultaneous Windows input set can exceed 500 characters even
    ; though every individual key name is valid.
    static MaximumDisplayTextLength := 4096
    static MaximumHotkeyLength := 256
    ; 覆盖 Windows 可报告的完整键鼠空间，同时保留针对异常规则包的
    ; 明确资源边界。
    static MaximumKeyListItems := 512
    static MaximumConditions := 128
    static MaximumConditionDepth := 8
    static MaximumActionsPerField := 64
    static MaximumTotalActions := 128
    static MaximumActionValueLength := 4096
    static MaximumTextActionLength := 32768
    static MaximumJsonValueDepth := 8
    static MaximumJsonValueItems := 256
    static MaximumCloneDepth := 64
    static MaximumCloneItems := 100000

    static Normalize(value) {
        if Type(value) != "Map"
            throw TypeError("RuleSpec 根值必须是 JSON 对象。")
        source := this.Clone(value)
        this.ValidateKnownFields(source, ["id", "enabled",
            "passthrough", "priority", "stop_processing", "description",
            "display", "from", "conditions", "to",
            "to_if_alone", "to_if_held_down", "to_after_key_up",
            "to_if_other_key_pressed", "to_delayed_if_invoked",
            "to_delayed_if_canceled", "timing"], "RuleSpec")
        id := this.NormalizeId(this.ReadRequiredString(source, "id"))
        spec := Map("id", id)
        if !this.ReadBoolean(source, "enabled", true)
            spec["enabled"] := JsonBoolean(false)
        preserveSourceInput := this.ReadBoolean(source, "passthrough", false)
        if preserveSourceInput
            spec["passthrough"] := JsonBoolean(true)
        priority := this.ReadInteger(source, "priority", 0)
        if priority < -100000 || priority > 100000
            throw Error("RuleSpec priority 必须在 -100000 到 100000 之间。")
        if priority
            spec["priority"] := priority
        if !this.ReadBoolean(source, "stop_processing", true)
            spec["stop_processing"] := JsonBoolean(false)
        description := this.RequireMaximumLength(
            this.ReadString(source, "description", ""),
            this.MaximumDescriptionLength, "description")
        if description != ""
            spec["description"] := description
        ; 旧版 RuleSpec 的档案字段仅用于分组。迁移到单一全局规则集时
        ; 由迁移服务显式丢弃该字段，规范化器不再静默接受它。
        spec["display"] := this.NormalizeDisplay(this.ReadMap(source,
            "display"))
        spec["from"] := this.NormalizeFrom(this.ReadMap(source, "from"),
            preserveSourceInput)
        conditions := this.ReadArray(source, "conditions", [])
        normalizedConditions := []
        conditionCount := 0
        for condition in conditions
            normalizedConditions.Push(this.NormalizeConditionNode(condition,
                1, &conditionCount))
        if normalizedConditions.Length
            spec["conditions"] := normalizedConditions
        hasAction := false
        totalActions := 0
        for fieldName in this.ActionFields {
            actions := this.ReadArray(source, fieldName, [])
            if actions.Length > this.MaximumActionsPerField
                throw Error("RuleSpec " fieldName " 动作数量超过上限。")
            totalActions += actions.Length
            if totalActions > this.MaximumTotalActions
                throw Error("RuleSpec 总动作数量超过上限。")
            normalizedActions := []
            for action in actions {
                normalizedAction := this.NormalizeAction(action)
                normalizedActions.Push(normalizedAction)
            }
            if normalizedActions.Length
                spec[fieldName] := normalizedActions
            hasAction := hasAction || normalizedActions.Length > 0
        }
        this.RejectLegacyActionFields(source)
        if spec["from"].Get("event", "down") == "up" {
            if spec["from"].Get("repeat", "allow") == "only"
                throw Error("up 来源不支持 repeat=only；松开事件不会产生自动重复。")
            for fieldName in ["to_if_alone", "to_if_held_down"] {
                if this.ReadArray(spec, fieldName, []).Length
                    throw Error("up 来源不支持 " fieldName
                        "；该动作需要从按下开始跟踪状态。")
            }
            for fieldName in this.ActionFields
                for action in spec.Get(fieldName, [])
                    if action["type"] == "key_down"
                        throw Error("Key-up source rules cannot leave a key pressed.")
        }
        if !hasAction
            throw Error("RuleSpec 至少需要一个输出动作。")
        timing := this.NormalizeTiming(this.ReadMap(source, "timing", Map()))
        if timing.Count
            spec["timing"] := timing
        return spec
    }

    static CreateFromCaptures(id, sourceCapture, targetCapture,
            distinguishModifierSides := true) {
        sourceName := sourceCapture.HasOwnProp("RawDisplay")
            ? sourceCapture.RawDisplay : sourceCapture.Display
        targetName := targetCapture.HasOwnProp("RawDisplay")
            ? targetCapture.RawDisplay : targetCapture.Display
        isSimultaneous := sourceCapture.HasOwnProp("IsSimultaneous")
            && sourceCapture.IsSimultaneous
        if isSimultaneous {
            if !distinguishModifierSides
                sourceName := this.NormalizeCapturedSourceDisplay(sourceName)
            sourceKeys := this.CaptureKeyInfosToSpecs(sourceCapture.Keys,
                distinguishModifierSides)
            from := Map("event", "down")
            if sourceKeys.Length == 1
                from["key"] := sourceKeys[1]
            else
                from["simultaneous"] := sourceKeys
        } else {
            sourceIdentityName := sourceCapture.HasOwnProp("KeyName")
                ? sourceCapture.KeyName : sourceName
            sourcePrimaryWasGenericized := false
            if !distinguishModifierSides {
                try {
                    canonicalSourceName := this.CanonicalModifierName(
                        sourceIdentityName)
                    genericSourceName := this.GenericModifierName(
                        canonicalSourceName)
                    sourcePrimaryWasGenericized := canonicalSourceName
                        != genericSourceName
                    sourceIdentityName := genericSourceName
                }
                sourceName := this.NormalizeCapturedSourceDisplay(sourceName)
            }
            from := Map("event", InStr(sourceCapture.SourceSpec, " Up")
                ? "up" : "down", "key", Map("name", sourceIdentityName))
            if sourceCapture.HasOwnProp("Modifiers") {
                capturedModifiers := this.CaptureModifiersToNames(
                    sourceCapture.Modifiers, distinguishModifierSides)
                if sourcePrimaryWasGenericized && capturedModifiers.Length {
                    primaryFamily := this.GetModifierFamily(sourceIdentityName)
                    filteredModifiers := []
                    for modifierName in capturedModifiers
                        if this.GetModifierFamily(modifierName) != primaryFamily
                            filteredModifiers.Push(modifierName)
                    capturedModifiers := filteredModifiers
                }
                if capturedModifiers.Length
                    from["modifiers"] := capturedModifiers
            }
            if !sourcePrimaryWasGenericized
                    && sourceCapture.HasOwnProp("VKHex")
                    && sourceCapture.VKHex != ""
                from["key"]["vk"] := sourceCapture.VKHex
            if !sourcePrimaryWasGenericized
                    && sourceCapture.HasOwnProp("SCHex")
                    && sourceCapture.SCHex != ""
                from["key"]["sc"] := sourceCapture.SCHex
        }
        action := Map("type", "send", "value", targetCapture.TargetSend)
        conditions := []
        scope := "全局"
        spec := Map("id", id,
            "display", Map("source", sourceName, "target", targetName,
                "scope", scope),
            "from", from, "conditions", conditions, "to", [action])
        return this.Normalize(spec)
    }

    static CaptureKeyInfosToSpecs(keyInfos,
            distinguishModifierSides := true) {
        if Type(keyInfos) != "Array" || !keyInfos.Length
            throw TypeError("录制结果的 Keys 必须是非空数组。")
        result := []
        seen := Map()
        for keyInfo in keyInfos {
            if !IsObject(keyInfo) || !keyInfo.HasOwnProp("KeyName")
                throw TypeError("录制结果包含无效按键信息。")
            keyName := String(keyInfo.KeyName)
            genericized := false
            if this.IsModifierName(keyName) {
                keyName := this.CanonicalModifierName(keyName)
                if !distinguishModifierSides {
                    keyName := this.GenericModifierName(keyName)
                    genericized := true
                }
            }
            key := Map("name", keyName)
            kind := keyInfo.HasOwnProp("Kind")
                ? StrLower(String(keyInfo.Kind)) : "keyboard"
            if kind != "keyboard"
                key["kind"] := kind
            if !genericized && keyInfo.HasOwnProp("VKHex")
                    && keyInfo.VKHex != ""
                key["vk"] := keyInfo.VKHex
            if !genericized && keyInfo.HasOwnProp("SCHex")
                    && keyInfo.SCHex != ""
                key["sc"] := keyInfo.SCHex
            if keyInfo.HasOwnProp("AppCommand")
                key["command"] := keyInfo.AppCommand
            normalized := this.NormalizeKeyIdentity(key, "captured key")
            identity := this.GetKeyIdentitySignature(normalized)
            if seen.Has(identity)
                continue
            seen[identity] := true
            result.Push(normalized)
        }
        return result
    }

    static NormalizeDisplay(display) {
        this.ValidateKnownFields(display, ["source", "target", "scope"],
            "display")
        normalized := Map("source", this.RequireMaximumLength(
            this.ReadRequiredString(display, "source"),
            this.MaximumDisplayTextLength, "display.source"),
            "target", this.RequireMaximumLength(
            this.ReadRequiredString(display, "target"),
            this.MaximumDisplayTextLength, "display.target"))
        scope := this.RequireMaximumLength(
            this.ReadString(display, "scope", "全局"),
            this.MaximumDisplayTextLength, "display.scope")
        if scope != "全局"
            normalized["scope"] := scope
        return normalized
    }

    static NormalizeFrom(from, passthrough := false) {
        this.ValidateKnownFields(from, ["hotkey", "key", "simultaneous",
            "modifiers", "optional_modifiers", "sequence", "event",
            "repeat", "tap_count"], "from")
        hotkeyName := this.RequireMaximumLength(
            this.ReadString(from, "hotkey", ""),
            this.MaximumHotkeyLength, "from.hotkey")
        if hotkeyName != "" && RegExMatch(Trim(hotkeyName), "^[~*$]*~")
                && !passthrough
            throw Error("from.hotkey 的 ~ 前缀必须同时设置 passthrough=true。")
        key := this.ReadMap(from, "key", Map())
        simultaneous := this.NormalizeKeyArray(
            this.ReadArray(from, "simultaneous", []))
        modifiers := this.NormalizeModifiers(
            this.ReadArray(from, "modifiers", []), false)
        optionalModifiers := this.NormalizeModifiers(
            this.ReadArray(from, "optional_modifiers", []), true)
        parsedHotkey := ""
        if hotkeyName != "" {
            parsedHotkey := this.ParseHotkeyModifiers(hotkeyName)
            modifiers := this.ResolveParsedModifiers(modifiers,
                parsedHotkey.Modifiers, "from.modifiers")
            optionalModifiers := this.ResolveParsedModifiers(
                optionalModifiers, parsedHotkey.OptionalModifiers,
                "from.optional_modifiers")
        }
        if hotkeyName == "" && !key.Count && !simultaneous.Length
            throw Error("RuleSpec from must specify hotkey, key, or simultaneous.")
        if hotkeyName != "" && !key.Count
                && !simultaneous.Length
            throw Error("当前输入后端的简单规则必须指定 from.key，"
                . "不能只写 from.hotkey。")
        if from.Has("sequence") && this.ReadArray(from, "sequence", []).Length
            throw Error("Sequences are not supported by the direct AHK runtime.")
        if simultaneous.Length && hotkeyName != ""
            throw Error("复杂来源不能同时指定 hotkey。")
        if simultaneous.Length && key.Count
            throw Error("复杂来源不能同时指定 key 和 simultaneous。")
        if simultaneous.Length
                && (modifiers.Length || optionalModifiers.Length)
            throw Error("复杂来源暂不接受独立 modifiers；请把修饰键写入按键数组。")
        if simultaneous.Length == 1
            throw Error("A simultaneous source needs at least two keys.")
        eventName := StrLower(this.ReadString(from, "event", "down"))
        if hotkeyName != "" && RegExMatch(hotkeyName, "i)\s+Up$") {
            if from.Has("event") && eventName != "up"
                throw Error("带 Up 后缀的 from.hotkey 必须使用 event=up。")
            eventName := "up"
        }
        normalized := Map()
        if eventName != "down"
            normalized["event"] := eventName
        if key.Count {
            normalized["key"] := this.NormalizeKeyIdentity(key,
                "from.key")
            if IsObject(parsedHotkey) && !this.HotkeyPrimaryMatchesKey(
                    parsedHotkey.Primary, normalized["key"])
                throw Error("from.hotkey 与 from.key 的主键不一致。")
            if modifiers.Length && this.IsModifierName(
                    normalized["key"]["name"]) {
                primaryFamily := this.GetModifierFamily(
                    normalized["key"]["name"])
                for modifierName in modifiers
                    if this.GetModifierFamily(modifierName) == primaryFamily
                        throw Error("来源主键不能同时要求同族修饰键："
                            modifierName)
            }
        }
        if simultaneous.Length
            normalized["simultaneous"] := simultaneous
        if modifiers.Length
            normalized["modifiers"] := modifiers
        if optionalModifiers.Length
            normalized["optional_modifiers"] := optionalModifiers
        defaultRepeat := simultaneous.Length ? "ignore" : "allow"
        repeatPolicy := StrLower(
            this.ReadString(from, "repeat", defaultRepeat))
        tapCount := this.ReadInteger(from, "tap_count", 1)
        if tapCount < 1 || tapCount > 8
            throw Error("RuleSpec from.tap_count 必须在 1 到 8 之间。")
        if tapCount != 1
            throw Error("Multi-tap rules are not supported by the direct AHK runtime.")
        if eventName != "down" && eventName != "up"
            throw Error("RuleSpec from.event 只能是 down 或 up。")
        if repeatPolicy != "allow" && repeatPolicy != "ignore"
                && repeatPolicy != "only"
            throw Error("RuleSpec from.repeat 只能是 allow、ignore 或 only。")
        if simultaneous.Length && repeatPolicy == "only"
            throw Error("复杂来源不支持 repeat=only；前置按键本身必须是首次按下。")
        if simultaneous.Length
                && eventName != "down"
            throw Error("Direct simultaneous rules support only down events.")
        if eventName == "up" && (modifiers.Length
                || optionalModifiers.Length)
            throw Error("Key-up rules with modifiers are not supported by the direct AHK runtime.")
        if repeatPolicy == "only" && this.IsNonReleasableSource(
                key, simultaneous, hotkeyName)
            throw Error("repeat=only requires a source key with an observable release event.")
        if repeatPolicy != "allow"
            normalized["repeat"] := repeatPolicy
        if simultaneous.Length {
            seenKeys := Map()
            seenNames := Map()
            genericModifierFamilies := Map()
            sidedModifierFamilies := Map()
            for item in simultaneous {
                identity := this.GetKeyIdentitySignature(item)
                if seenKeys.Has(identity)
                    throw Error("simultaneous 不能包含重复按键：" item["name"])
                seenKeys[identity] := true
                kind := item.Get("kind", "keyboard")
                nameIdentity := StrLower(kind ":" item["name"])
                if seenNames.Has(nameIdentity)
                    throw Error("simultaneous 不能用不同编码重复同一按键："
                        item["name"])
                seenNames[nameIdentity] := true
                if !this.IsModifierName(item["name"])
                    continue
                modifierName := item["name"]
                family := this.GetModifierFamily(modifierName)
                isGeneric := modifierName == "Ctrl"
                    || modifierName == "Shift" || modifierName == "Alt"
                    || modifierName == "Win"
                if isGeneric {
                    if sidedModifierFamilies.Has(family)
                        throw Error("simultaneous 不能混用通用修饰键与同族侧键："
                            modifierName)
                    genericModifierFamilies[family] := true
                } else {
                    if genericModifierFamilies.Has(family)
                        throw Error("simultaneous 不能混用通用修饰键与同族侧键："
                            modifierName)
                    sidedModifierFamilies[family] := true
                }
            }
        }
        return normalized
    }

    static IsNonReleasableSource(key, simultaneous, hotkeyName) {
        primaryName := ""
        if key.Count
            primaryName := key["name"]
        else if simultaneous.Length {
            index := simultaneous.Length
            while index >= 1 {
                candidate := simultaneous[index]
                if !this.IsModifierName(candidate["name"]) {
                    primaryName := candidate["name"]
                    break
                }
                index--
            }
            if primaryName == ""
                primaryName := simultaneous[simultaneous.Length]["name"]
        } else {
            primaryName := RegExReplace(String(hotkeyName),
                "i)^[~*$<>^+!#]+|\\s+Up$")
        }
        return RegExMatch(primaryName,
            "i)^(?:WheelUp|WheelDown|WheelLeft|WheelRight|MouseMove)$")
    }

    static HotkeyPrimaryMatchesKey(primaryName, key) {
        expected := this.BuildKeyHotkey(key)
        normalizedPrimary := StrLower(RegExReplace(Trim(String(primaryName)),
            "\s+"))
        normalizedExpected := StrLower(expected)
        if normalizedPrimary == normalizedExpected
            return true
        if key.Has("sc") && key["sc"] != "" {
            try {
                if GetKeySC(primaryName) == Integer("0x" key["sc"])
                    return true
            }
            return false
        }
        if key.Has("vk") && key["vk"] != "" {
            try {
                if GetKeyVK(primaryName) == Integer("0x" key["vk"])
                    return true
            }
            return false
        }
        try {
            actualName := GetKeyName(primaryName)
            expectedName := GetKeyName(expected)
            if actualName != "" && expectedName != ""
                return StrLower(actualName) == StrLower(expectedName)
        }
        return false
    }

    static BuildKeyHotkey(key) {
        if key.Has("sc") && key["sc"] != ""
            return "sc" key["sc"]
        if key.Has("vk") && key["vk"] != ""
            return "vk" key["vk"]
        return key["name"]
    }

    static NormalizeConditionNode(condition, depth, &conditionCount) {
        if depth > this.MaximumConditionDepth
            throw Error("RuleSpec condition 嵌套层级超过上限。")
        conditionCount++
        if conditionCount > this.MaximumConditions
            throw Error("RuleSpec condition 节点数量超过上限。")
        if Type(condition) != "Map"
            throw TypeError("RuleSpec condition 必须是对象。")
        source := this.Clone(condition)
        this.ValidateKnownFields(source, ["type", "negate", "conditions",
            "condition", "operator", "case_sensitive", "field", "value"],
            "condition")
        conditionType := StrLower(this.ReadRequiredString(source, "type"))
        allowed := Map("application", true, "window", true,
            "input_source", true, "session", true, "all", true,
            "any", true, "not", true)
        if !allowed.Has(conditionType)
            throw Error("RuleSpec condition 类型无效：" conditionType)
        normalized := Map("type", conditionType)
        negate := this.ReadBoolean(source, "negate", false)
        if negate
            normalized["negate"] := JsonBoolean(true)
        if conditionType == "all" || conditionType == "any" {
            this.ValidateKnownFields(source,
                ["type", "negate", "conditions"], conditionType " condition")
            children := this.ReadArray(source, "conditions", [])
            if !children.Length
                throw Error(conditionType " 条件至少需要一个子条件。")
            normalizedChildren := []
            for child in children
                normalizedChildren.Push(this.NormalizeConditionNode(child,
                    depth + 1, &conditionCount))
            normalized["conditions"] := normalizedChildren
        } else if conditionType == "not" {
            this.ValidateKnownFields(source,
                ["type", "negate", "condition"], "not condition")
            normalized["condition"] := this.NormalizeConditionNode(
                this.ReadMap(source, "condition"), depth + 1,
                &conditionCount)
        } else {
            this.ValidateKnownFields(source, ["type", "negate", "operator",
                "case_sensitive", "field", "value"],
                conditionType " condition")
            operatorName := StrLower(
                this.ReadString(source, "operator", "equals"))
            allowedOperators := Map("equals", true, "not_equals", true,
                "contains", true, "not_contains", true,
                "starts_with", true, "ends_with", true,
                "regex", true, "in", true, "not_in", true,
                "exists", true, "not_exists", true)
            if !allowedOperators.Has(operatorName)
                throw Error("RuleSpec condition 运算符无效：" operatorName)
            if operatorName != "equals"
                normalized["operator"] := operatorName
            caseSensitive := this.ReadBoolean(source, "case_sensitive", false)
            if caseSensitive
                normalized["case_sensitive"] := JsonBoolean(true)
            fieldName := this.ReadString(source, "field", "")
            if fieldName != "" {
                this.ValidateConditionField(conditionType, fieldName)
                normalized["field"] := fieldName
            }
            if operatorName == "exists" || operatorName == "not_exists" {
                if source.Has("value") || source.Has("case_sensitive")
                    throw Error(operatorName
                        . " 条件不接受 value 或 case_sensitive。")
            } else {
                normalized["value"] := this.ReadRequiredValue(source,
                    "value")
                valueItemCount := 0
                this.ValidateJsonValue(normalized["value"], 1,
                    &valueItemCount, "condition.value")
                if (operatorName == "in" || operatorName == "not_in")
                        && Type(normalized["value"]) != "Array"
                    throw TypeError(operatorName " 条件的 value 必须是数组。")
                if operatorName == "regex" {
                    if IsObject(normalized["value"])
                        throw TypeError("regex 条件的 value 必须是字符串。")
                    this.RequireMaximumLength(String(normalized["value"]),
                        this.MaximumActionValueLength,
                        "condition regex value")
                    try RegExMatch("", String(normalized["value"]))
                    catch as patternError
                        throw Error("RuleSpec condition 正则表达式无效："
                            patternError.Message)
                }
            }
        }
        return normalized
    }

    static NormalizeAction(action) {
        if Type(action) != "Map"
            throw TypeError("RuleSpec action 必须是对象。")
        source := this.Clone(action)
        this.ValidateKnownFields(source, ["type", "value", "repeat",
            "repeat_interval_ms"], "action")
        actionType := StrLower(this.ReadRequiredString(source, "type"))
        allowed := Map("send", true, "key_down", true, "key_up", true,
            "text", true, "mouse", true, "app_command", true,
            "sleep", true, "window_minimize", true,
            "window_close", true, "lock_workstation", true)
        if !allowed.Has(actionType)
            throw Error("RuleSpec action 类型无效：" actionType)
        normalized := Map("type", actionType)
        if actionType == "window_minimize"
                || actionType == "window_close"
                || actionType == "lock_workstation" {
            if source.Has("value")
                throw Error(actionType " action 不接受 value。")
        } else {
            value := this.ReadRequiredValue(source, "value")
            if IsObject(value)
                throw TypeError(actionType " action.value 必须是标量。")
            maximumLength := actionType == "text"
                ? this.MaximumTextActionLength : this.MaximumActionValueLength
            normalized["value"] := this.RequireMaximumLength(String(value),
                maximumLength, actionType ".value")
            if actionType == "key_down" || actionType == "key_up"
                normalized["value"] := this.NormalizeOutputKeyName(
                    normalized["value"], actionType ".value")
        }
        if actionType == "sleep" {
            if !RegExMatch(normalized["value"], "^\d{1,4}$")
                    || Integer(normalized["value"]) > 5000
                throw Error("sleep.value 必须是 0 到 5000 的整数毫秒。")
        }
        repeatPolicy := this.RequireMaximumLength(
            this.ReadString(source, "repeat", "inherit"), 32,
            actionType ".repeat")
        if repeatPolicy != "inherit" && repeatPolicy != "once"
                && repeatPolicy != "repeat"
            throw Error(actionType ".repeat 只能是 inherit、once 或 repeat。")
        repeatInterval := this.ReadInteger(source, "repeat_interval_ms", 0)
        if repeatInterval != 0
            throw Error("Timed action repetition is not supported by the direct AHK runtime.")
        if repeatPolicy != "inherit"
            normalized["repeat"] := repeatPolicy
        return normalized
    }

    static NormalizeOutputKeyName(value, label) {
        keyName := Trim(String(value))
        if keyName == "" || !RegExMatch(keyName, "^[A-Za-z0-9_]+$")
            throw Error(label " 必须是单个 AHK 按键名称。")
        canonicalName := ""
        try {
            canonicalName := GetKeyName(keyName)
            if canonicalName != ""
                keyName := canonicalName
        }
        if canonicalName == ""
            throw Error(label " 不是当前 AHK 运行时支持的按键：“"
                keyName "”。")
        return keyName
    }

    static IsModifierName(value) {
        allowed := Map("Ctrl", true, "Shift", true, "Alt", true,
            "Win", true, "LCtrl", true, "RCtrl", true,
            "LShift", true, "RShift", true, "LAlt", true,
            "RAlt", true, "LWin", true, "RWin", true)
        return allowed.Has(String(value))
    }

    static NormalizeTiming(timing) {
        this.ValidateKnownFields(timing, ["held_threshold_ms"], "timing")
        result := Map()
        if !timing.Has("held_threshold_ms")
            return result
        rawValue := timing["held_threshold_ms"]
        if Type(rawValue) == "String"
                && StrLower(Trim(rawValue)) == "inherit"
            return result
        value := this.ReadInteger(timing, "held_threshold_ms", 200)
        if value < 1 || value > 60000
            throw Error("RuleSpec timing.held_threshold_ms must be between 1 and 60000.")
        result["held_threshold_ms"] := value
        return result
    }

    static RejectLegacyActionFields(spec) {
        for fieldName in ["to_if_other_key_pressed",
                "to_delayed_if_invoked", "to_delayed_if_canceled"] {
            if spec.Has(fieldName) && this.ReadArray(spec, fieldName, []).Length
                throw Error("RuleSpec " fieldName
                    " is not supported by the direct AHK runtime.")
            if spec.Has(fieldName)
                spec.Delete(fieldName)
        }
        return true
    }

    static NormalizeKeyArray(values) {
        if values.Length > this.MaximumKeyListItems
            throw Error("按键数组数量超过上限。")
        result := []
        for value in values {
            if Type(value) == "String"
                result.Push(this.NormalizeKeyIdentity(Map("name", value),
                    "key"))
            else if Type(value) == "Map"
                result.Push(this.NormalizeKeyIdentity(value, "key"))
            else
                throw TypeError("按键数组只能包含字符串或对象。")
        }
        return result
    }

    static NormalizeKeyIdentity(value, label := "key") {
        this.ValidateKnownFields(value, ["name", "kind", "vk", "sc",
            "extended", "command"], label)
        normalized := Map("name", this.RequireMaximumLength(
            this.ReadRequiredString(value, "name"),
            this.MaximumHotkeyLength, label ".name"))
        kind := StrLower(this.ReadString(value, "kind", "keyboard"))
        allowedKinds := Map("keyboard", true, "mouse", true, "wheel", true,
            "app-command", true, "named", true)
        if !allowedKinds.Has(kind)
            throw Error(label ".kind 无效：" kind)
        if kind != "keyboard"
            normalized["kind"] := kind
        if value.Has("vk")
            normalized["vk"] := this.NormalizeHexCode(value["vk"], 4,
                label ".vk", 0xFF, 2)
        if value.Has("sc")
            normalized["sc"] := this.NormalizeHexCode(value["sc"], 4,
                label ".sc", 0x1FF, 3)
        inferredExtended := normalized.Has("sc")
            && Integer("0x" normalized["sc"]) > 0xFF
        extended := this.ReadBoolean(value, "extended", inferredExtended)
        if inferredExtended && !extended
            throw Error(label ".extended 不能与扩展扫描码冲突。")
        if normalized.Has("sc") && extended {
            scValue := Integer("0x" normalized["sc"]) | 0x100
            normalized["sc"] := Format("{:03X}", scValue)
        }
        if extended && !normalized.Has("sc")
            normalized["extended"] := JsonBoolean(true)
        if value.Has("command") {
            command := this.ReadInteger(value, "command", 0)
            if command < 0 || command > 0xFFFF
                throw Error(label ".command 必须在 0 到 65535 之间。")
            normalized["command"] := command
        }
        if (normalized.Has("sc") || normalized.Has("vk"))
                && !this.HotkeyPrimaryMatchesKey(normalized["name"],
                    normalized)
            throw Error(label ".name 与实际触发码不一致。")
        if !normalized.Has("sc") && !normalized.Has("vk") {
            resolvedName := ""
            try resolvedName := GetKeyName(normalized["name"])
            if resolvedName == "" {
                shownName := StrReplace(StrReplace(normalized["name"],
                    "`r", "\r"), "`n", "\n")
                throw Error(label ".name 不是当前 AHK 运行时支持的按键：“"
                    shownName "”。")
            }
        }
        return normalized
    }

    static ValidateConditionField(conditionType, fieldName) {
        allowedFields := Map(
            "application", Map("process", true, "path", true),
            "window", Map("title", true, "class", true, "hwnd", true),
            "input_source", Map("language_id", true),
            "session", Map("state", true))
        fieldName := this.RequireMaximumLength(Trim(String(fieldName)),
            128, conditionType ".field")
        if fieldName == "" || !allowedFields.Has(conditionType)
                || !allowedFields[conditionType].Has(fieldName)
            throw Error(conditionType " 条件字段无效：" fieldName)
        return fieldName
    }

    static NormalizeHexCode(value, maximumDigits, label,
            maximumValue := "", outputDigits := 0) {
        text := Trim(String(value))
        text := RegExReplace(text, "i)^(?:vk|sc|0x)")
        if text == "" || !RegExMatch(text,
                "i)^[0-9a-f]{1," maximumDigits "}$")
            throw Error(label " 必须是 1 到 " maximumDigits " 位十六进制数。")
        numericValue := Integer("0x" text)
        if maximumValue != "" && numericValue > maximumValue
            throw Error(label " 超出支持的取值范围。")
        return outputDigits > 0
            ? Format("{:0" outputDigits "X}", numericValue) : StrUpper(text)
    }

    static GetKeyIdentitySignature(key) {
        kind := key.Has("kind") ? StrLower(String(key["kind"])) : "keyboard"
        if key.Has("sc") && String(key["sc"]) != "" {
            extended := Integer("0x" key["sc"]) > 0xFF
                || (key.Has("extended") && key["extended"].Value)
            return kind ":sc:" StrLower(String(key["sc"])) ":"
                . (extended ? "1" : "0")
        }
        if key.Has("vk") && String(key["vk"]) != ""
            return kind ":vk:" StrLower(String(key["vk"]))
        if key.Has("command")
            return kind ":command:" key["command"]
        return kind ":name:" StrLower(String(key["name"]))
    }

    static CaptureModifiersToNames(modifierInfos,
            distinguishModifierSides := true) {
        if Type(modifierInfos) != "Array"
            throw TypeError("录制结果的 Modifiers 必须是数组。")
        result := []
        seen := Map()
        for modifierInfo in modifierInfos {
            if !IsObject(modifierInfo)
                    || !modifierInfo.HasOwnProp("KeyName")
                throw TypeError("录制结果包含无效修饰键。")
            modifierName := this.CanonicalModifierName(modifierInfo.KeyName)
            if !distinguishModifierSides
                modifierName := this.GenericModifierName(modifierName)
            if seen.Has(modifierName)
                continue
            seen[modifierName] := true
            result.Push(modifierName)
        }
        return result
    }

    static NormalizeCapturedSourceDisplay(value) {
        parts := StrSplit(String(value), " + ")
        normalizedParts := []
        seenModifierFamilies := Map()
        for part in parts {
            normalizedPart := Trim(part)
            try {
                modifierName := this.CanonicalModifierName(normalizedPart)
                normalizedPart := this.GenericModifierName(modifierName)
                family := this.GetModifierFamily(normalizedPart)
                if seenModifierFamilies.Has(family)
                    continue
                seenModifierFamilies[family] := true
            }
            normalizedParts.Push(normalizedPart)
        }
        result := ""
        for index, part in normalizedParts
            result .= (index == 1 ? "" : " + ") part
        return result
    }

    static GenericModifierName(value) {
        canonical := this.CanonicalModifierName(value)
        switch this.GetModifierFamily(canonical) {
            case "ctrl": return "Ctrl"
            case "shift": return "Shift"
            case "alt": return "Alt"
            case "win": return "Win"
        }
        throw Error("未知修饰键：" value)
    }

    static NormalizeStringArray(values) {
        if values.Length > this.MaximumKeyListItems
            throw Error("字符串数组数量超过上限。")
        result := []
        for value in values {
            text := Trim(String(value))
            if text == ""
                throw Error("字符串数组不能包含空值。")
            this.RequireMaximumLength(text, 128, "字符串数组条目")
            result.Push(text)
        }
        return result
    }

    static NormalizeModifiers(values, optional := false) {
        values := this.NormalizeStringArray(values)
        seen := Map()
        result := []
        for value in values {
            canonical := optional && StrLower(value) == "any"
                ? "any" : this.CanonicalModifierName(value)
            if optional && canonical != "any"
                throw Error("当前后端的 optional_modifiers 仅支持 any。")
            if seen.Has(canonical)
                throw Error("修饰键重复：" canonical)
            seen[canonical] := true
            result.Push(canonical)
        }
        if !optional {
            genericFamilies := Map()
            sidedFamilies := Map()
            for modifierName in result {
                family := this.GetModifierFamily(modifierName)
                isGeneric := modifierName == "Ctrl" || modifierName == "Shift"
                    || modifierName == "Alt" || modifierName == "Win"
                if isGeneric {
                    if sidedFamilies.Has(family)
                        throw Error("通用修饰键不能与同族左右修饰键并用："
                            modifierName)
                    genericFamilies[family] := true
                } else {
                    if genericFamilies.Has(family)
                        throw Error("左右修饰键不能与同族通用修饰键并用："
                            modifierName)
                    sidedFamilies[family] := true
                }
            }
        }
        return result
    }

    static GetModifierFamily(value) {
        value := StrLower(String(value))
        if InStr(value, "ctrl")
            return "ctrl"
        if InStr(value, "shift")
            return "shift"
        if InStr(value, "alt")
            return "alt"
        if InStr(value, "win")
            return "win"
        return value
    }

    static CanonicalModifierName(value) {
        value := StrLower(Trim(String(value)))
        switch value {
            case "control", "ctrl": return "Ctrl"
            case "shift": return "Shift"
            case "alt", "menu": return "Alt"
            case "win": return "Win"
            case "lcontrol", "lctrl": return "LCtrl"
            case "rcontrol", "rctrl": return "RCtrl"
            case "lshift": return "LShift"
            case "rshift": return "RShift"
            case "lalt", "lmenu": return "LAlt"
            case "ralt", "rmenu": return "RAlt"
            case "lwin": return "LWin"
            case "rwin": return "RWin"
        }
        throw Error("未知修饰键：" value)
    }

    static ParseHotkeyModifiers(hotkeyName) {
        name := RegExReplace(Trim(String(hotkeyName)), "i)\s+Up$")
        position := 1
        modifiers := []
        optionalModifiers := []
        while position <= StrLen(name) {
            character := SubStr(name, position, 1)
            if character == "$" || character == "~" {
                position++
                continue
            }
            if character == "*" {
                if !optionalModifiers.Length
                    optionalModifiers.Push("any")
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
            modifiers.Push(this.HotkeyPrefixToModifier(prefix))
        }
        primaryName := Trim(SubStr(name, position))
        if primaryName == ""
            throw Error("from.hotkey 缺少主键。")
        if InStr(primaryName, "&")
            throw Error("当前输入后端不支持 from.hotkey 自定义组合键；"
                . "请使用 simultaneous 或 sequence。")
        modifiers := this.NormalizeModifiers(modifiers)
        return {Modifiers: modifiers,
            OptionalModifiers: optionalModifiers, Primary: primaryName}
    }

    static HotkeyPrefixToModifier(prefix) {
        switch prefix {
            case "^": return "Ctrl"
            case "+": return "Shift"
            case "!": return "Alt"
            case "#": return "Win"
            case "<^": return "LCtrl"
            case ">^": return "RCtrl"
            case "<+": return "LShift"
            case ">+": return "RShift"
            case "<!": return "LAlt"
            case ">!": return "RAlt"
            case "<#": return "LWin"
            case ">#": return "RWin"
        }
        throw Error("未知热键修饰前缀：" prefix)
    }

    static ResolveParsedModifiers(explicitValues, parsedValues, label) {
        if !explicitValues.Length
            return parsedValues.Clone()
        if !parsedValues.Length
            return explicitValues
        if explicitValues.Length != parsedValues.Length
            throw Error(label " 与 from.hotkey 的修饰键不一致。")
        parsedSet := Map()
        for value in parsedValues
            parsedSet[value] := parsedSet.Get(value, 0) + 1
        for value in explicitValues {
            if !parsedSet.Has(value) || parsedSet[value] < 1
                throw Error(label " 与 from.hotkey 的修饰键不一致。")
            parsedSet[value]--
        }
        return explicitValues
    }

    static ReadMap(container, key, fallback?) {
        if !container.Has(key) {
            if IsSet(fallback)
                return fallback
            throw Error("RuleSpec 缺少对象字段：" key)
        }
        if Type(container[key]) != "Map"
            throw TypeError("RuleSpec 字段必须是对象：" key)
        return container[key]
    }

    static ValidateKnownFields(container, allowedFields, label) {
        if Type(container) != "Map"
            throw TypeError(label " 必须是对象。")
        allowed := Map()
        for fieldName in allowedFields
            allowed[fieldName] := true
        for fieldName in container {
            if !allowed.Has(fieldName)
                throw Error(label " 包含未知字段：" fieldName)
        }
        return true
    }

    static ReadArray(container, key, fallback?) {
        if !container.Has(key) {
            if IsSet(fallback)
                return fallback
            throw Error("RuleSpec 缺少数组字段：" key)
        }
        if Type(container[key]) != "Array"
            throw TypeError("RuleSpec 字段必须是数组：" key)
        return container[key]
    }

    static ReadRequiredString(container, key) {
        value := this.ReadString(container, key, "")
        if value == ""
            throw Error("RuleSpec 缺少必填字段：" key)
        return value
    }

    static NormalizeId(value, label := "规则名称") {
        if IsObject(value)
            throw TypeError(label "必须是字符串。")
        normalized := this.NormalizeUnicodeNfc(String(value), label)
        normalized := RegExReplace(normalized,
            "^[\p{Zs}\t]+|[\p{Zs}\t]+$", "")
        if normalized == ""
            throw Error(label "不能为空。")
        if StrLen(normalized) > this.MaximumIdLength
            throw Error(label "长度超过上限 " this.MaximumIdLength "。")
        if RegExMatch(normalized, "[\p{C}\p{Zl}\p{Zp}]")
            throw Error(label "不能包含控制字符、换行符或无效 Unicode 字符。")
        return normalized
    }

    static NormalizeUnicodeNfc(value, label := "文本") {
        value := String(value)
        if value == ""
            return ""
        DllCall("kernel32\SetLastError", "UInt", 0)
        required := DllCall("normaliz\NormalizeString", "Int", 1,
            "WStr", value, "Int", StrLen(value), "Ptr", 0, "Int", 0,
            "Int")
        if required <= 0
            throw OSError(A_LastError, label "无法进行 Unicode NFC 规范化。")
        output := Buffer(required * 2, 0)
        DllCall("kernel32\SetLastError", "UInt", 0)
        written := DllCall("normaliz\NormalizeString", "Int", 1,
            "WStr", value, "Int", StrLen(value), "Ptr", output,
            "Int", required, "Int")
        if written <= 0
            throw OSError(A_LastError, label "无法进行 Unicode NFC 规范化。")
        return StrGet(output, written, "UTF-16")
    }

    static ReadString(container, key, fallback) {
        if !container.Has(key)
            return fallback
        value := container[key]
        if IsObject(value)
            throw TypeError("RuleSpec 字段必须是字符串：" key)
        return String(value)
    }

    static ReadInteger(container, key, fallback) {
        if !container.Has(key)
            return fallback
        value := container[key]
        if IsObject(value) || !IsNumber(value)
            throw TypeError("RuleSpec 字段必须是整数：" key)
        integerValue := Integer(value)
        if integerValue != value
            throw TypeError("RuleSpec 字段必须是整数：" key)
        return integerValue
    }

    static ReadBoolean(container, key, fallback) {
        if !container.Has(key)
            return fallback
        value := container[key]
        if value is JsonBoolean
            return value.Value
        if !IsObject(value) && (value == 0 || value == 1)
            return !!value
        throw TypeError("RuleSpec 字段必须是布尔值：" key)
    }

    static ReadRequiredValue(container, key) {
        if !container.Has(key) || container[key] is JsonNull
            throw Error("RuleSpec 缺少必填字段：" key)
        return container[key]
    }

    static RequireMaximumLength(value, maximumLength, label) {
        value := String(value)
        if StrLen(value) > maximumLength
            throw Error(label " 长度超过上限 " maximumLength "。")
        return value
    }

    static ValidateJsonValue(value, depth, &itemCount, label,
            maximumStringLength := 4096) {
        if depth > this.MaximumJsonValueDepth
            throw Error(label " 嵌套层级超过上限。")
        itemCount++
        if itemCount > this.MaximumJsonValueItems
            throw Error(label " 元素数量超过上限。")
        valueType := Type(value)
        if valueType == "Map" {
            for key, item in value {
                this.RequireMaximumLength(key, 256, label " key")
                this.ValidateJsonValue(item, depth + 1, &itemCount,
                    label, maximumStringLength)
            }
            return true
        }
        if valueType == "Array" {
            for item in value
                this.ValidateJsonValue(item, depth + 1, &itemCount,
                    label, maximumStringLength)
            return true
        }
        if value is JsonBoolean || value is JsonNull
            return true
        this.RequireMaximumLength(value, maximumStringLength, label)
        return true
    }

    static Clone(value) {
        state := {Items: 0, Active: Map()}
        return this.CloneNode(value, 0, state)
    }

    static CloneNode(value, depth, state) {
        if depth > this.MaximumCloneDepth
            throw Error("JSON 值克隆嵌套层级超过上限。")
        state.Items++
        if state.Items > this.MaximumCloneItems
            throw Error("JSON 值克隆元素数量超过上限。")
        valueType := Type(value)
        if valueType == "Map" {
            pointer := ObjPtr(value)
            if state.Active.Has(pointer)
                throw Error("JSON 值克隆检测到循环引用。")
            state.Active[pointer] := true
            try {
                result := Map()
                for key, item in value
                    result[String(key)] := this.CloneNode(item, depth + 1,
                        state)
                return result
            } finally state.Active.Delete(pointer)
        }
        if valueType == "Array" {
            pointer := ObjPtr(value)
            if state.Active.Has(pointer)
                throw Error("JSON 值克隆检测到循环引用。")
            state.Active[pointer] := true
            try {
                result := []
                for item in value
                    result.Push(this.CloneNode(item, depth + 1, state))
                return result
            } finally state.Active.Delete(pointer)
        }
        if value is JsonBoolean
            return JsonBoolean(value.Value)
        if value is JsonNull
            return JsonNull()
        return value
    }
}
