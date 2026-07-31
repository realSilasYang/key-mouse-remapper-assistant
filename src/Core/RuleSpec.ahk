class RuleSpec {
    static CurrentSchema := 2
    static ActionFields := ["to", "to_if_alone", "to_if_held_down",
        "to_if_other_key_pressed", "to_after_key_up",
        "to_delayed_if_invoked", "to_delayed_if_canceled"]
    static MaximumDescriptionLength := 2000
    static MaximumDisplayTextLength := 500
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
    static MaximumRunCommandLength := 2048
    static MaximumJsonValueDepth := 8
    static MaximumJsonValueItems := 256
    static MaximumCloneDepth := 64
    static MaximumCloneItems := 100000

    static Normalize(value) {
        if Type(value) != "Map"
            throw TypeError("RuleSpec 根值必须是 JSON 对象。")
        spec := this.Clone(value)
        schema := this.ReadInteger(spec, "schema", this.CurrentSchema)
        if schema != this.CurrentSchema
            throw Error("不支持的 RuleSpec 版本：" schema)
        spec["schema"] := schema
        spec["id"] := this.ReadRequiredString(spec, "id")
        if !RegExMatch(spec["id"], "^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$")
            throw Error("RuleSpec id 只能包含字母、数字、点、下划线和连字符。")
        spec["enabled"] := JsonBoolean(this.ReadBoolean(spec, "enabled", true))
        priority := this.ReadInteger(spec, "priority", 0)
        if priority < -100000 || priority > 100000
            throw Error("RuleSpec priority 必须在 -100000 到 100000 之间。")
        spec["priority"] := priority
        spec["stop_processing"] := JsonBoolean(
            this.ReadBoolean(spec, "stop_processing", true))
        ; 旧版 RuleSpec 的档案字段仅用于分组。迁移到单一全局规则集时
        ; 保留规则本身并丢弃该字段，规范化输出不再写回档案信息。
        if spec.Has("profile")
            spec.Delete("profile")
        spec["description"] := this.RequireMaximumLength(
            this.ReadString(spec, "description", ""),
            this.MaximumDescriptionLength, "RuleSpec description")
        spec["display"] := this.NormalizeDisplay(this.ReadMap(spec, "display"))
        spec["from"] := this.NormalizeFrom(this.ReadMap(spec, "from"))
        conditions := this.ReadArray(spec, "conditions", [])
        normalizedConditions := []
        conditionCount := 0
        for condition in conditions
            normalizedConditions.Push(this.NormalizeConditionNode(condition,
                1, &conditionCount))
        spec["conditions"] := normalizedConditions
        hasAction := false
        hasFixedRepeat := false
        totalActions := 0
        for fieldName in this.ActionFields {
            actions := this.ReadArray(spec, fieldName, [])
            if actions.Length > this.MaximumActionsPerField
                throw Error("RuleSpec " fieldName " 动作数量超过上限。")
            totalActions += actions.Length
            if totalActions > this.MaximumTotalActions
                throw Error("RuleSpec 总动作数量超过上限。")
            normalizedActions := []
            for action in actions {
                normalizedAction := this.NormalizeAction(action)
                normalizedActions.Push(normalizedAction)
                hasFixedRepeat := hasFixedRepeat
                    || normalizedAction["repeat_interval_ms"] > 0
            }
            spec[fieldName] := normalizedActions
            hasAction := hasAction || normalizedActions.Length > 0
        }
        if spec["from"]["event"] == "up" {
            if spec["from"]["repeat"] == "only"
                throw Error("up 来源不支持 repeat=only；松开事件不会产生自动重复。")
            for fieldName in ["to_if_alone", "to_if_held_down",
                    "to_if_other_key_pressed", "to_delayed_if_invoked"] {
                if spec[fieldName].Length
                    throw Error("up 来源不支持 " fieldName
                        "；该动作需要从按下开始跟踪状态。")
            }
        }
        if !hasAction
            throw Error("RuleSpec 至少需要一个输出动作。")
        if hasFixedRepeat && spec["from"]["event"] != "down"
            throw Error("固定间隔重复只支持 down 来源。")
        if hasFixedRepeat && !spec["from"]["simultaneous"].Length
                && !spec["from"]["sequence"].Length {
            repeatSource := spec["from"]["hotkey"] != ""
                ? spec["from"]["hotkey"] : spec["from"]["key"]["name"]
            if RegExMatch(repeatSource, "i)Wheel(?:Up|Down|Left|Right)(?:\s+Up)?$")
                throw Error("没有松开事件的滚轮来源不能使用固定间隔重复。")
        }
        spec["timing"] := this.NormalizeTiming(this.ReadMap(spec, "timing", Map()))
        return spec
    }

    static CreateFromCaptures(id, sourceCapture, targetCapture, purpose) {
        sourceName := sourceCapture.HasOwnProp("RawDisplay")
            ? sourceCapture.RawDisplay : sourceCapture.Display
        sourceIdentityName := sourceCapture.HasOwnProp("KeyName")
            ? sourceCapture.KeyName : sourceName
        targetName := targetCapture.HasOwnProp("RawDisplay")
            ? targetCapture.RawDisplay : targetCapture.Display
        isSimultaneous := sourceCapture.HasOwnProp("IsSimultaneous")
            && sourceCapture.IsSimultaneous
        if isSimultaneous {
            if !sourceCapture.HasOwnProp("SourceKeys")
                    || Type(sourceCapture.SourceKeys) != "Array"
                    || sourceCapture.SourceKeys.Length < 2
                throw ValueError("同时按键录制结果缺少来源按键数组。")
            capturedKeys := sourceCapture.HasOwnProp("Keys")
                ? this.CaptureKeysToIdentities(sourceCapture.Keys)
                : sourceCapture.SourceKeys.Clone()
            from := Map("simultaneous", capturedKeys,
                "event", "down")
        } else {
            from := Map("hotkey", sourceCapture.SourceSpec,
                "event", InStr(sourceCapture.SourceSpec, " Up")
                    ? "up" : "down",
                "key", Map("name", sourceIdentityName))
            if sourceCapture.HasOwnProp("Modifiers") {
                capturedModifiers := this.CaptureModifiersToNames(
                    sourceCapture.Modifiers)
                if capturedModifiers.Length
                    from["modifiers"] := capturedModifiers
            }
            if sourceCapture.HasOwnProp("Kind")
                from["key"]["kind"] := sourceCapture.Kind
            if sourceCapture.HasOwnProp("VKHex") && sourceCapture.VKHex != ""
                from["key"]["vk"] := sourceCapture.VKHex
            if sourceCapture.HasOwnProp("SCHex") && sourceCapture.SCHex != ""
                from["key"]["sc"] := sourceCapture.SCHex
            if sourceCapture.HasOwnProp("SC")
                from["key"]["extended"] := JsonBoolean(
                    (Integer(sourceCapture.SC) & 0x100) != 0)
            if sourceCapture.HasOwnProp("AppCommand")
                from["key"]["command"] := sourceCapture.AppCommand
        }
        action := Map("type", "send", "value", targetCapture.TargetSend,
            "display", targetName)
        conditions := []
        scope := "全局"
        if sourceCapture.HasOwnProp("DeviceId")
                && String(sourceCapture.DeviceId) != "" {
            conditions.Push(Map("type", "device", "field", "stable_id",
                "operator", "equals", "value",
                String(sourceCapture.DeviceId)))
            deviceName := sourceCapture.HasOwnProp("DeviceDisplayName")
                ? String(sourceCapture.DeviceDisplayName)
                : String(sourceCapture.DeviceId)
            scope .= " · " deviceName
        }
        spec := Map("schema", 2, "id", id,
            "enabled", JsonBoolean(true),
            "description", String(purpose),
            "display", Map("source", sourceName, "target", targetName,
                "scope", scope,
                "purpose", String(purpose)),
            "from", from, "conditions", conditions, "to", [action])
        if isSimultaneous
            ; 录制器按连续手势累计按键；0 表示运行时只要求所有键共同
            ; 处于按下状态，不再额外限制各键按下时间差。
            spec["timing"] := Map("simultaneous_threshold_ms", 0)
        return this.Normalize(spec)
    }

    static CreateSimple(id, sourceCapture, targetCapture, purpose) {
        return this.CreateFromCaptures(id, sourceCapture, targetCapture,
            purpose)
    }

    static NormalizeDisplay(display) {
        normalized := this.Clone(display)
        normalized["source"] := this.RequireMaximumLength(
            this.ReadRequiredString(display, "source"),
            this.MaximumDisplayTextLength, "display.source")
        normalized["target"] := this.RequireMaximumLength(
            this.ReadRequiredString(display, "target"),
            this.MaximumDisplayTextLength, "display.target")
        normalized["scope"] := this.RequireMaximumLength(
            this.ReadString(display, "scope", "全局"),
            this.MaximumDisplayTextLength, "display.scope")
        normalized["purpose"] := this.RequireMaximumLength(
            this.ReadString(display, "purpose", ""),
            this.MaximumDescriptionLength, "display.purpose")
        return normalized
    }

    static NormalizeFrom(from) {
        hotkeyName := this.RequireMaximumLength(
            this.ReadString(from, "hotkey", ""),
            this.MaximumHotkeyLength, "from.hotkey")
        key := this.ReadMap(from, "key", Map())
        simultaneous := this.NormalizeKeyArray(
            this.ReadArray(from, "simultaneous", []))
        sequence := this.NormalizeKeyArray(
            this.ReadArray(from, "sequence", []))
        modifiers := this.NormalizeModifiers(
            this.ReadArray(from, "modifiers", []), false)
        optionalModifiers := this.NormalizeModifiers(
            this.ReadArray(from, "optional_modifiers", []), true)
        if hotkeyName != "" {
            parsedHotkey := this.ParseHotkeyModifiers(hotkeyName)
            modifiers := this.ResolveParsedModifiers(modifiers,
                parsedHotkey.Modifiers, "from.modifiers")
            optionalModifiers := this.ResolveParsedModifiers(
                optionalModifiers, parsedHotkey.OptionalModifiers,
                "from.optional_modifiers")
        }
        if hotkeyName == "" && !key.Count && !simultaneous.Length && !sequence.Length
            throw Error("RuleSpec from 必须指定 hotkey、key、simultaneous 或 sequence。")
        if hotkeyName != "" && !key.Count
                && !simultaneous.Length && !sequence.Length
            throw Error("当前输入后端的简单规则必须指定 from.key，"
                . "不能只写 from.hotkey。")
        if simultaneous.Length && sequence.Length
            throw Error("RuleSpec from 不能同时指定 simultaneous 和 sequence。")
        if (simultaneous.Length || sequence.Length) && hotkeyName != ""
            throw Error("复杂来源不能同时指定 hotkey。")
        if (simultaneous.Length || sequence.Length)
                && (modifiers.Length || optionalModifiers.Length)
            throw Error("复杂来源暂不接受独立 modifiers；请把修饰键写入按键数组。")
        if simultaneous.Length == 1 || sequence.Length == 1
            throw Error("simultaneous 和 sequence 至少需要两个按键。")
        eventName := StrLower(this.ReadString(from, "event", "down"))
        if hotkeyName != "" && RegExMatch(hotkeyName, "i)\s+Up$") {
            if from.Has("event") && eventName != "up"
                throw Error("带 Up 后缀的 from.hotkey 必须使用 event=up。")
            eventName := "up"
        }
        normalized := this.Clone(from)
        normalized["hotkey"] := hotkeyName
        normalized["event"] := eventName
        defaultRepeat := simultaneous.Length || sequence.Length
            ? "ignore" : "allow"
        normalized["repeat"] := StrLower(
            this.ReadString(from, "repeat", defaultRepeat))
        normalized["modifiers"] := modifiers
        normalized["optional_modifiers"] := optionalModifiers
        normalized["simultaneous"] := simultaneous
        normalized["sequence"] := sequence
        tapCount := this.ReadInteger(from, "tap_count", 1)
        if tapCount < 1 || tapCount > 8
            throw Error("RuleSpec from.tap_count 必须在 1 到 8 之间。")
        if tapCount > 1 && (simultaneous.Length || sequence.Length
                || normalized["event"] != "down")
            throw Error("多击来源只支持简单按下规则。")
        normalized["tap_count"] := tapCount
        simultaneousOptions := this.ReadMap(from, "simultaneous_options", Map())
        normalizedOptions := this.Clone(simultaneousOptions)
        normalizedOptions["order"] := StrLower(this.ReadString(
            simultaneousOptions, "order", "insensitive"))
        normalizedOptions["release"] := StrLower(this.ReadString(
            simultaneousOptions, "release", "any"))
        if normalizedOptions["order"] != "insensitive"
                && normalizedOptions["order"] != "strict"
            throw Error("simultaneous_options.order 只能是 insensitive 或 strict。")
        if normalizedOptions["release"] != "any"
                && normalizedOptions["release"] != "all"
            throw Error("simultaneous_options.release 只能是 any 或 all。")
        if simultaneous.Length
            normalized["simultaneous_options"] := normalizedOptions
        else if normalized.Has("simultaneous_options")
            normalized.Delete("simultaneous_options")
        if normalized["event"] != "down" && normalized["event"] != "up"
            throw Error("RuleSpec from.event 只能是 down 或 up。")
        if normalized["repeat"] != "allow"
                && normalized["repeat"] != "ignore"
                && normalized["repeat"] != "only"
            throw Error("RuleSpec from.repeat 只能是 allow、ignore 或 only。")
        if (simultaneous.Length || sequence.Length)
                && normalized["repeat"] == "only"
            throw Error("复杂来源不支持 repeat=only；前置按键本身必须是首次按下。")
        if (simultaneous.Length || sequence.Length)
                && normalized["event"] != "down"
            throw Error("当前后端的 simultaneous 和 sequence 仅支持 down 事件。")
        if key.Count {
            normalized["key"] := this.NormalizeKeyIdentity(key,
                "from.key")
        }
        if simultaneous.Length {
            seenKeys := Map()
            for item in simultaneous {
                identity := this.GetKeyIdentitySignature(item)
                if seenKeys.Has(identity)
                    throw Error("simultaneous 不能包含重复按键：" item["name"])
                seenKeys[identity] := true
            }
        }
        return normalized
    }

    static NormalizeCondition(condition) {
        conditionCount := 0
        return this.NormalizeConditionNode(condition, 1, &conditionCount)
    }

    static NormalizeConditionNode(condition, depth, &conditionCount) {
        if depth > this.MaximumConditionDepth
            throw Error("RuleSpec condition 嵌套层级超过上限。")
        conditionCount++
        if conditionCount > this.MaximumConditions
            throw Error("RuleSpec condition 节点数量超过上限。")
        if Type(condition) != "Map"
            throw TypeError("RuleSpec condition 必须是对象。")
        normalized := this.Clone(condition)
        conditionType := StrLower(this.ReadRequiredString(normalized, "type"))
        allowed := Map("application", true, "window", true,
            "variable", true, "input_source", true, "session", true,
            "device", true, "all", true, "any", true, "not", true)
        if !allowed.Has(conditionType)
            throw Error("RuleSpec condition 类型无效：" conditionType)
        normalized["type"] := conditionType
        normalized["negate"] := JsonBoolean(
            this.ReadBoolean(normalized, "negate", false))
        if conditionType == "all" || conditionType == "any" {
            children := this.ReadArray(normalized, "conditions", [])
            if !children.Length
                throw Error(conditionType " 条件至少需要一个子条件。")
            normalizedChildren := []
            for child in children
                normalizedChildren.Push(this.NormalizeConditionNode(child,
                    depth + 1, &conditionCount))
            normalized["conditions"] := normalizedChildren
        } else if conditionType == "not" {
            normalized["condition"] := this.NormalizeConditionNode(
                this.ReadMap(normalized, "condition"), depth + 1,
                &conditionCount)
        } else {
            operatorName := StrLower(
                this.ReadString(normalized, "operator", "equals"))
            allowedOperators := Map("equals", true, "not_equals", true,
                "contains", true, "not_contains", true,
                "starts_with", true, "ends_with", true,
                "regex", true, "in", true, "not_in", true,
                "exists", true, "not_exists", true)
            if !allowedOperators.Has(operatorName)
                throw Error("RuleSpec condition 运算符无效：" operatorName)
            normalized["operator"] := operatorName
            normalized["case_sensitive"] := JsonBoolean(this.ReadBoolean(
                normalized, "case_sensitive", false))
            normalized["field"] := this.ReadString(normalized, "field", "")
            if conditionType == "variable"
                normalized["name"] := this.ReadRequiredString(normalized,
                    "name")
            if operatorName != "exists" && operatorName != "not_exists" {
                normalized["value"] := this.ReadRequiredValue(normalized,
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
        normalized := this.Clone(action)
        actionType := StrLower(this.ReadRequiredString(normalized, "type"))
        allowed := Map("send", true, "key_down", true, "key_up", true,
            "text", true, "mouse", true, "app_command", true,
            "set_variable", true, "unset_variable", true,
            "switch_layer", true, "one_shot_modifier", true,
            "sticky_modifier", true, "run", true, "sleep", true,
            "window_minimize", true, "window_close", true,
            "lock_workstation", true)
        if !allowed.Has(actionType)
            throw Error("RuleSpec action 类型无效：" actionType)
        normalized["type"] := actionType
        if actionType == "set_variable" || actionType == "unset_variable" {
            normalized["name"] := this.RequireMaximumLength(
                this.ReadRequiredString(normalized, "name"), 128,
                actionType ".name")
            scope := StrLower(this.ReadString(normalized, "scope",
                "transient"))
            if scope != "transient" && scope != "persistent"
                throw Error(actionType ".scope 必须是 transient 或 persistent。")
            normalized["scope"] := scope
            if actionType == "set_variable" {
                normalized["value"] := this.ReadRequiredValue(normalized,
                    "value")
                valueItemCount := 0
                this.ValidateJsonValue(normalized["value"], 1,
                    &valueItemCount, "set_variable.value",
                    this.MaximumTextActionLength)
            }
        } else if actionType == "switch_layer" {
            normalized["value"] := this.RequireMaximumLength(
                this.ReadRequiredString(normalized, "value"), 128,
                actionType ".value")
        } else if actionType == "window_minimize"
                || actionType == "window_close"
                || actionType == "lock_workstation" {
            if normalized.Has("value")
                normalized.Delete("value")
        } else {
            value := this.ReadRequiredValue(normalized, "value")
            if IsObject(value)
                throw TypeError(actionType " action.value 必须是标量。")
            maximumLength := actionType == "text"
                ? this.MaximumTextActionLength
                : (actionType == "run" ? this.MaximumRunCommandLength
                    : this.MaximumActionValueLength)
            normalized["value"] := this.RequireMaximumLength(String(value),
                maximumLength, actionType ".value")
        }
        if actionType == "sleep" {
            if !RegExMatch(normalized["value"], "^\d{1,4}$")
                    || Integer(normalized["value"]) > 5000
                throw Error("sleep.value 必须是 0 到 5000 的整数毫秒。")
        }
        if (actionType == "one_shot_modifier"
                || actionType == "sticky_modifier")
                && !this.IsModifierName(normalized["value"])
            throw Error(actionType ".value 必须是明确左右侧的修饰键。")
        defaultRepeat := actionType == "one_shot_modifier"
            || actionType == "sticky_modifier" ? "once" : "inherit"
        normalized["repeat"] := this.RequireMaximumLength(
            this.ReadString(normalized, "repeat", defaultRepeat), 32,
            actionType ".repeat")
        if normalized["repeat"] != "inherit"
                && normalized["repeat"] != "once"
                && normalized["repeat"] != "repeat"
            throw Error(actionType ".repeat 只能是 inherit、once 或 repeat。")
        repeatInterval := this.ReadInteger(normalized, "repeat_interval_ms", 0)
        if repeatInterval < 0 || repeatInterval > 60000
            throw Error(actionType ".repeat_interval_ms 必须在 0 到 60000 之间。")
        if repeatInterval > 0 && normalized["repeat"] == "once"
            throw Error(actionType " 的固定重复间隔不能与 repeat=once 同时使用。")
        normalized["repeat_interval_ms"] := repeatInterval
        return normalized
    }

    static IsModifierName(value) {
        allowed := Map("Ctrl", true, "Shift", true, "Alt", true,
            "Win", true, "LCtrl", true, "RCtrl", true,
            "LShift", true, "RShift", true, "LAlt", true,
            "RAlt", true, "LWin", true, "RWin", true)
        return allowed.Has(String(value))
    }

    static NormalizeTiming(timing) {
        result := this.Clone(timing)
        defaults := Map("alone_timeout_ms", 200, "held_threshold_ms", 200,
            "simultaneous_threshold_ms", 50, "sequence_timeout_ms", 500,
            "multi_tap_timeout_ms", 300, "delayed_action_ms", 200)
        for fieldName, fallback in defaults {
            if !timing.Has(fieldName) {
                result[fieldName] := "inherit"
                continue
            }
            rawValue := timing[fieldName]
            if Type(rawValue) == "String"
                    && StrLower(Trim(rawValue)) == "inherit" {
                result[fieldName] := "inherit"
                continue
            }
            value := this.ReadInteger(timing, fieldName, fallback)
            minimum := fieldName == "simultaneous_threshold_ms" ? 0 : 1
            if value < minimum || value > 60000
                throw Error("RuleSpec timing." fieldName " 必须在 " minimum
                    " 到 60000 之间。")
            result[fieldName] := value
        }
        return result
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
        normalized := this.Clone(value)
        normalized["name"] := this.RequireMaximumLength(
            this.ReadRequiredString(value, "name"),
            this.MaximumHotkeyLength, label ".name")
        kind := StrLower(this.ReadString(value, "kind", "keyboard"))
        allowedKinds := Map("keyboard", true, "mouse", true, "wheel", true,
            "app-command", true, "named", true)
        if !allowedKinds.Has(kind)
            throw Error(label ".kind 无效：" kind)
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
        normalized["extended"] := JsonBoolean(extended)
        if value.Has("command") {
            command := this.ReadInteger(value, "command", 0)
            if command < 0 || command > 0xFFFF
                throw Error(label ".command 必须在 0 到 65535 之间。")
            normalized["command"] := command
        }
        return normalized
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
        if key.Has("sc") && String(key["sc"]) != ""
            return kind ":sc:" StrLower(String(key["sc"])) ":"
                . (key.Has("extended") && key["extended"].Value ? "1" : "0")
        if key.Has("vk") && String(key["vk"]) != ""
            return kind ":vk:" StrLower(String(key["vk"]))
        if key.Has("command")
            return kind ":command:" key["command"]
        return kind ":name:" StrLower(String(key["name"]))
    }

    static CaptureKeysToIdentities(keyInfos) {
        result := []
        for capturedKey in keyInfos {
            identity := Map("name", capturedKey.KeyName, "kind",
                capturedKey.Kind)
            if capturedKey.VKHex != ""
                identity["vk"] := capturedKey.VKHex
            if capturedKey.SCHex != ""
                identity["sc"] := capturedKey.SCHex
            identity["extended"] := JsonBoolean(
                (Integer(capturedKey.SC) & 0x100) != 0)
            if capturedKey.HasOwnProp("AppCommand")
                identity["command"] := capturedKey.AppCommand
            result.Push(identity)
        }
        return result
    }

    static CaptureModifiersToNames(modifierInfos) {
        if Type(modifierInfos) != "Array"
            throw TypeError("录制结果的 Modifiers 必须是数组。")
        result := []
        for modifierInfo in modifierInfos {
            if !IsObject(modifierInfo)
                    || !modifierInfo.HasOwnProp("KeyName")
                throw TypeError("录制结果包含无效修饰键。")
            result.Push(this.CanonicalModifierName(modifierInfo.KeyName))
        }
        return result
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
        return result
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
            OptionalModifiers: optionalModifiers}
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
