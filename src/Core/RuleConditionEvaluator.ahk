class RuleConditionEvaluator {
    EvaluateNormalizedAllDetailed(conditions, context) {
        if Type(conditions) != "Array"
            throw TypeError("规则条件集合必须是数组。")
        steps := []
        for index, condition in conditions {
            result := this.EvaluateNormalizedNode(condition, context, steps,
                String(index))
            if !result.Matched
                return {Matched: false, Reason: result.Reason,
                    Steps: steps}
        }
        return {Matched: true, Reason: "all_conditions_matched",
            Steps: steps}
    }

    EvaluateNormalizedNode(condition, context, steps, path) {
        conditionType := condition["type"]
        exists := false
        actual := ""
        if conditionType == "all" {
            matched := true
            reason := "all_matched"
            for index, child in condition["conditions"] {
                childResult := this.EvaluateNormalizedNode(child, context, steps,
                    path "." index)
                if !childResult.Matched {
                    matched := false
                    reason := childResult.Reason
                    break
                }
            }
        } else if conditionType == "any" {
            matched := false
            reason := "no_child_matched"
            for index, child in condition["conditions"] {
                childResult := this.EvaluateNormalizedNode(child, context, steps,
                    path "." index)
                if childResult.Matched {
                    matched := true
                    reason := childResult.Reason
                    break
                }
            }
        } else if conditionType == "not" {
            childResult := this.EvaluateNormalizedNode(condition["condition"],
                context, steps, path ".1")
            matched := !childResult.Matched
            reason := matched ? "not_matched" : "not_rejected"
        } else {
            actual := this.ResolveActual(condition, context, &exists)
            matched := this.Compare(actual, exists, condition)
            reason := matched ? conditionType "_matched"
                : conditionType "_rejected"
        }
        if condition.Get("negate", JsonBoolean(false)).Value {
            matched := !matched
            reason := "negated_" reason
        }
        steps.Push(this.BuildStep(condition, path, matched, reason,
            exists, actual))
        return {Matched: matched, Reason: reason,
            Type: conditionType}
    }

    BuildStep(condition, path, matched, reason, exists, actual) {
        step := Map(
            "path", String(path),
            "type", condition["type"],
            "matched", JsonBoolean(matched),
            "reason", reason,
            "negate", RuleSpec.Clone(condition.Get("negate",
                JsonBoolean(false))))
        isPredicate := condition["type"] != "all" && condition["type"] != "any"
            && condition["type"] != "not"
        if isPredicate
            step["operator"] := condition.Get("operator", "equals")
        if condition.Has("field") && condition["field"] != ""
            step["field"] := condition["field"]
        if condition.Has("name")
            step["name"] := condition["name"]
        if condition.Has("value")
            step["expected"] := RuleSpec.Clone(condition["value"])
        if isPredicate {
            step["exists"] := JsonBoolean(exists)
            step["actual"] := exists ? RuleSpec.Clone(actual) : JsonNull()
        }
        return step
    }

    ResolveActual(condition, context, &exists) {
        exists := false
        conditionType := condition["type"]
        actual := this.ReadContext(context, conditionType, &exists)
        if !exists
            return ""
        if condition.Has("field") && condition["field"] != "" {
            fieldName := condition["field"]
            if Type(actual) == "Map" && actual.Has(fieldName)
                return actual[fieldName]
            if IsObject(actual) && actual.HasOwnProp(fieldName)
                return actual.%fieldName%
            exists := false
            return ""
        }
        ; Structured context fields are addressed directly by the current
        ; managed rule format.
        if Type(actual) == "Map" {
            if conditionType == "session" && actual.Has("state")
                return actual["state"]
            if conditionType == "input_source"
                    && actual.Has("language_id")
                return actual["language_id"]
        }
        return actual
    }

    ReadContext(context, key, &exists) {
        exists := false
        if Type(context) == "Map" {
            if context.Has(key) {
                exists := true
                return context[key]
            }
            return ""
        }
        if IsObject(context) && context.HasOwnProp(key) {
            exists := true
            return context.%key%
        }
        return ""
    }

    Compare(actual, exists, condition) {
        operatorName := condition.Get("operator", "equals")
        if operatorName == "exists"
            return exists
        if operatorName == "not_exists"
            return !exists
        if !exists
            return false
        expected := condition["value"]
        caseSensitive := condition.Get("case_sensitive",
            JsonBoolean(false)).Value
        if operatorName == "in" || operatorName == "not_in" {
            matched := false
            for candidate in expected {
                if this.Equals(actual, candidate, caseSensitive) {
                    matched := true
                    break
                }
            }
            return operatorName == "in" ? matched : !matched
        }
        if operatorName == "equals" || operatorName == "not_equals" {
            matched := this.Equals(actual, expected, caseSensitive)
            return operatorName == "equals" ? matched : !matched
        }
        actualText := IsObject(actual)
            ? JsonCodec.Stringify(actual, false, true) : String(actual)
        expectedText := IsObject(expected)
            ? JsonCodec.Stringify(expected, false, true) : String(expected)
        if operatorName == "regex"
            return RegExMatch(actualText,
                this.PrepareRegex(expectedText, caseSensitive)) > 0
        if !caseSensitive {
            actualText := StrLower(actualText)
            expectedText := StrLower(expectedText)
        }
        switch operatorName {
            case "contains": return InStr(actualText, expectedText) > 0
            case "not_contains": return InStr(actualText, expectedText) == 0
            case "starts_with": return SubStr(actualText, 1,
                StrLen(expectedText)) == expectedText
            case "ends_with": return expectedText == ""
                || (StrLen(expectedText) <= StrLen(actualText)
                    && SubStr(actualText, -StrLen(expectedText)) == expectedText)
        }
        return false
    }

    PrepareRegex(pattern, caseSensitive) {
        if caseSensitive
            return pattern
        if RegExMatch(pattern, "^([imsxADJPSUXO-]*)\)", &optionMatch) {
            options := optionMatch[1]
            if !InStr(options, "i", true)
                options := "i" options
            return options ")" SubStr(pattern, optionMatch.Len(0) + 1)
        }
        return "i)" pattern
    }

    Equals(actual, expected, caseSensitive) {
        if IsObject(actual) || IsObject(expected) {
            actualText := JsonCodec.Stringify(actual, false, true)
            expectedText := JsonCodec.Stringify(expected, false, true)
            return caseSensitive ? actualText == expectedText
                : StrLower(actualText) == StrLower(expectedText)
        }
        actualType := Type(actual)
        expectedType := Type(expected)
        if (actualType == "Integer" || actualType == "Float")
                && (expectedType == "Integer" || expectedType == "Float")
            return Number(actual) == Number(expected)
        return caseSensitive ? String(actual) == String(expected)
            : StrLower(String(actual)) == StrLower(String(expected))
    }
}
