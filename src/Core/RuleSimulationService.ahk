class RuleSimulationService {
    __New() {
        this.ConditionEvaluator := RuleConditionEvaluator()
        this.ConflictAnalyzer := RuleConflictAnalyzer()
    }

    Simulate(mappings, eventValue, contextValue := "") {
        if Type(mappings) != "Array"
            throw TypeError("规则模拟器需要映射数组。")
        event := this.NormalizeEvent(eventValue)
        context := Type(contextValue) == "Map"
            ? RuleSpec.Clone(contextValue) : Map()
        descriptors := []
        rawSkipped := 0
        for order, mapping in mappings {
            if !mapping.HasOwnProp("Mode") || mapping.Mode != "managed" {
                rawSkipped++
                continue
            }
            descriptor := mapping.HasOwnProp("Descriptor")
                ? mapping.Descriptor : RuleCompiler.Compile(mapping.Spec)
            descriptor.Order := order
            descriptors.Push(descriptor)
        }
        RuleCompiler.SortDescriptors(descriptors)
        candidates := []
        matchedRules := []
        stoppedBy := ""
        for descriptor in descriptors {
            result := this.EvaluateDescriptor(descriptor, event, context,
                stoppedBy)
            candidates.Push(result)
            if !result["accepted"].Value
                continue
            matchedRules.Push(descriptor.Id)
            if descriptor.StopProcessing
                stoppedBy := descriptor.Id
        }
        return Map("event", event, "context", context,
            "candidates", candidates, "matched_rules", matchedRules,
            "stopped_by", stoppedBy, "raw_rules_skipped", rawSkipped,
            "conflict_graph", this.ConflictAnalyzer.BuildGraph(mappings))
    }

    EvaluateDescriptor(descriptor, event, context, stoppedBy) {
        base := Map("rule_id", descriptor.Id,
            "signature", descriptor.Signature,
            "priority", descriptor.Priority,
            "order", descriptor.Order,
            "stop_processing", JsonBoolean(descriptor.StopProcessing),
            "accepted", JsonBoolean(false), "reason", "",
            "condition_steps", [], "actions", Map())
        if !descriptor.Enabled
            return this.Reject(base, "disabled")
        if descriptor.Signature != event["signature"]
            return this.Reject(base, "trigger_mismatch")
        from := descriptor.Spec["from"]
        expectedPhase := from["event"]
        if expectedPhase != "any" && expectedPhase != event["phase"]
            return this.Reject(base, "phase_mismatch", expectedPhase)
        repeatPolicy := from["repeat"]
        if event["repeat"].Value && repeatPolicy == "ignore"
            return this.Reject(base, "repeat_ignored")
        if !event["repeat"].Value && repeatPolicy == "only"
            return this.Reject(base, "repeat_required")
        if stoppedBy != ""
            return this.Reject(base, "stopped_by_rule", stoppedBy)
        conditionResult := this.ConditionEvaluator.EvaluateAllDetailed(
            descriptor.Spec["conditions"], context)
        base["condition_steps"] := conditionResult.Steps
        if !conditionResult.Matched
            return this.Reject(base, "conditions_rejected",
                conditionResult.Reason)
        base["accepted"] := JsonBoolean(true)
        base["reason"] := "matched"
        base["actions"] := this.BuildActionPlan(descriptor.Spec,
            event["phase"])
        return base
    }

    Reject(result, reason, detail := "") {
        result["reason"] := String(reason)
        if detail != ""
            result["detail"] := String(detail)
        return result
    }

    BuildActionPlan(spec, phase) {
        plan := Map()
        if phase == "down" {
            for fieldName in ["to", "to_if_alone", "to_if_held_down",
                    "to_if_other_key_pressed", "to_delayed_if_invoked"] {
                if spec[fieldName].Length
                    plan[fieldName] := RuleSpec.Clone(spec[fieldName])
            }
        } else {
            if spec["to"].Length
                plan["to"] := RuleSpec.Clone(spec["to"])
            for fieldName in ["to_after_key_up", "to_delayed_if_canceled"] {
                if spec[fieldName].Length
                    plan[fieldName] := RuleSpec.Clone(spec[fieldName])
            }
        }
        return plan
    }

    NormalizeEvent(value) {
        if Type(value) != "Map"
            throw TypeError("模拟事件必须是 JSON 对象。")
        trigger := value.Has("signature") ? String(value["signature"])
            : (value.Has("trigger") ? String(value["trigger"]) : "")
        trigger := Trim(trigger)
        if trigger == ""
            throw Error("模拟事件缺少 trigger 或 signature。")
        if !RegExMatch(trigger, "i)^(?:hotkey|seq|sim):")
            trigger := "hotkey:"
                . RuleCompiler.NormalizeHotkeySignature(trigger)
        else {
            separator := InStr(trigger, ":")
            prefix := StrLower(SubStr(trigger, 1, separator))
            triggerValue := SubStr(trigger, separator + 1)
            trigger := prefix == "hotkey:"
                ? prefix RuleCompiler.NormalizeHotkeySignature(triggerValue)
                : prefix StrLower(RegExReplace(triggerValue, "\s+", ""))
        }
        phase := value.Has("phase")
            ? StrLower(Trim(String(value["phase"]))) : "down"
        if phase != "down" && phase != "up"
            throw Error("模拟事件 phase 必须是 down 或 up。")
        repeatValue := value.Has("repeat") ? value["repeat"] : false
        if repeatValue is JsonBoolean
            repeat := repeatValue.Value
        else if !IsObject(repeatValue)
                && (repeatValue == 0 || repeatValue == 1)
            repeat := !!repeatValue
        else
            throw TypeError("模拟事件 repeat 必须是布尔值。")
        return Map("signature", trigger, "phase", phase,
            "repeat", JsonBoolean(repeat))
    }
}
