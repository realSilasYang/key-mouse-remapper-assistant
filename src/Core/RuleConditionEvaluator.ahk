class RuleConditionEvaluator {
    EvaluateAll(conditions, context) {
        detailed := this.EvaluateAllDetailed(conditions, context)
        return {Matched: detailed.Matched, Reason: detailed.Reason}
    }

    EvaluateAllDetailed(conditions, context) {
        if Type(conditions) != "Array"
            throw TypeError("规则条件集合必须是数组。")
        steps := []
        for index, condition in conditions {
            result := this.EvaluateNode(condition, context, steps,
                String(index))
            if !result.Matched
                return {Matched: false, Reason: result.Reason,
                    Steps: steps}
        }
        return {Matched: true, Reason: "all_conditions_matched",
            Steps: steps}
    }

    Evaluate(condition, context) {
        steps := []
        return this.EvaluateNode(condition, context, steps, "1")
    }

    EvaluateNode(condition, context, steps, path) {
        condition := RuleSpec.NormalizeCondition(condition)
        conditionType := condition["type"]
        exists := false
        actual := ""
        if conditionType == "all" {
            matched := true
            reason := "all_matched"
            for index, child in condition["conditions"] {
                childResult := this.EvaluateNode(child, context, steps,
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
                childResult := this.EvaluateNode(child, context, steps,
                    path "." index)
                if childResult.Matched {
                    matched := true
                    reason := childResult.Reason
                    break
                }
            }
        } else if conditionType == "not" {
            childResult := this.EvaluateNode(condition["condition"],
                context, steps, path ".1")
            matched := !childResult.Matched
            reason := matched ? "not_matched" : "not_rejected"
        } else if conditionType == "device" {
            deviceResult := this.EvaluateDevice(condition, context)
            actual := deviceResult.Actual
            exists := deviceResult.Exists
            matched := deviceResult.Matched
            reason := matched ? "device_matched" : "device_rejected"
        } else {
            actual := this.ResolveActual(condition, context, &exists)
            matched := this.Compare(actual, exists, condition)
            reason := matched ? conditionType "_matched"
                : conditionType "_rejected"
        }
        if condition["negate"].Value {
            matched := !matched
            reason := "negated_" reason
        }
        steps.Push(this.BuildStep(condition, path, matched, reason,
            exists, actual))
        return {Matched: matched, Reason: reason,
            Type: conditionType}
    }

    EvaluateDevice(condition, context) {
        deviceContext := this.ReadContext(context, "device", &hasDevice)
        items := []
        if hasDevice {
            if Type(deviceContext) == "Map" && deviceContext.Has("current")
                    && !(deviceContext["current"] is JsonNull)
                    && IsObject(deviceContext["current"])
                items := [deviceContext["current"]]
            else if Type(deviceContext) == "Array"
                items := deviceContext
            else if Type(deviceContext) == "Map"
                    && deviceContext.Has("items")
                    && Type(deviceContext["items"]) == "Array"
                items := deviceContext["items"]
            else
                items.Push(deviceContext)
        }
        actualValues := []
        for item in items {
            actual := this.ResolveDeviceValue(item, condition,
                &candidateExists)
            if candidateExists
                actualValues.Push(RuleSpec.Clone(actual))
        }
        exists := actualValues.Length > 0
        operatorName := condition["operator"]
        if operatorName == "exists"
            return {Matched: exists, Exists: exists, Actual: actualValues}
        if operatorName == "not_exists"
            return {Matched: !exists, Exists: exists, Actual: actualValues}
        if !exists
            return {Matched: false, Exists: false, Actual: actualValues}

        positiveOperator := operatorName
        isNegative := false
        switch operatorName {
            case "not_equals": positiveOperator := "equals", isNegative := true
            case "not_contains": positiveOperator := "contains", isNegative := true
            case "not_in": positiveOperator := "in", isNegative := true
        }
        positiveCondition := RuleSpec.Clone(condition)
        positiveCondition["operator"] := positiveOperator
        anyMatched := false
        for actual in actualValues {
            if this.Compare(actual, true, positiveCondition) {
                anyMatched := true
                break
            }
        }
        return {Matched: isNegative ? !anyMatched : anyMatched,
            Exists: true, Actual: actualValues}
    }

    ResolveDeviceValue(item, condition, &exists) {
        exists := false
        if condition.Has("field") && condition["field"] != "" {
            fieldName := condition["field"]
            if Type(item) == "Map" && item.Has(fieldName) {
                value := item[fieldName]
                if !IsObject(value) && String(value) == ""
                    return ""
                exists := true
                return value
            }
            if IsObject(item) && item.HasOwnProp(fieldName) {
                value := item.%fieldName%
                if !IsObject(value) && String(value) == ""
                    return ""
                exists := true
                return value
            }
            return ""
        }
        if Type(item) == "Map" {
            for fallbackField in ["stable_id", "id"] {
                if item.Has(fallbackField)
                        && String(item[fallbackField]) != "" {
                    exists := true
                    return item[fallbackField]
                }
            }
        }
        exists := !IsObject(item) || Type(item) == "Map"
        return item
    }

    BuildStep(condition, path, matched, reason, exists, actual) {
        step := Map(
            "path", String(path),
            "type", condition["type"],
            "matched", JsonBoolean(matched),
            "reason", reason,
            "negate", RuleSpec.Clone(condition["negate"]))
        if condition.Has("operator")
            step["operator"] := condition["operator"]
        if condition.Has("field") && condition["field"] != ""
            step["field"] := condition["field"]
        if condition.Has("name")
            step["name"] := condition["name"]
        if condition.Has("value")
            step["expected"] := RuleSpec.Clone(condition["value"])
        if condition.Has("operator") {
            step["exists"] := JsonBoolean(exists)
            step["actual"] := exists ? RuleSpec.Clone(actual) : JsonNull()
        }
        return step
    }

    ResolveActual(condition, context, &exists) {
        exists := false
        conditionType := condition["type"]
        if conditionType == "variable" {
            variables := this.ReadContext(context, "variables", &hasVariables)
            if !hasVariables || Type(variables) != "Map"
                return ""
            name := condition["name"]
            if !variables.Has(name)
                return ""
            exists := true
            return variables[name]
        }
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
        ; Schema 1 rules compared these contexts as scalars. Keep those rules
        ; working while allowing schema 2 rules to address structured fields.
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
        operatorName := condition["operator"]
        if operatorName == "exists"
            return exists
        if operatorName == "not_exists"
            return !exists
        if !exists
            return false
        expected := condition["value"]
        caseSensitive := condition["case_sensitive"].Value
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
        if RegExMatch(pattern, "^([imsxADJPSUX]*)\)", &optionMatch) {
            options := optionMatch[1]
            if !InStr(options, "i", true)
                options := "i" options
            return options ")" SubStr(pattern, optionMatch.Len(0) + 1)
        }
        return "i)" pattern
    }

    Equals(actual, expected, caseSensitive) {
        if IsObject(actual) || IsObject(expected)
            return JsonCodec.Stringify(actual, false, true)
                == JsonCodec.Stringify(expected, false, true)
        if IsNumber(actual) && IsNumber(expected)
            return Number(actual) == Number(expected)
        return caseSensitive ? String(actual) == String(expected)
            : StrLower(String(actual)) == StrLower(String(expected))
    }
}
