class RuleConflictAnalyzer {
    Analyze(mappings) {
        issues := []
        descriptors := []
        triggerGroups := Map()
        for order, mapping in mappings {
            if !mapping.HasOwnProp("Mode") || mapping.Mode != "managed"
                continue
            descriptor := mapping.HasOwnProp("Descriptor")
                ? mapping.Descriptor : RuleCompiler.Compile(mapping.Spec)
            descriptor.Order := order
            descriptors.Push(descriptor)
            this.AnalyzeSelf(descriptor, issues)
            groupKey := descriptor.DispatchSignature
            if !triggerGroups.Has(groupKey)
                triggerGroups[groupKey] := []
            triggerGroups[groupKey].Push(descriptor)
        }
        if descriptors.Length < 2
            return issues
        for _, group in triggerGroups {
            if group.Length < 2
                continue
            Loop group.Length - 1 {
                leftIndex := A_Index
                Loop group.Length - leftIndex {
                    rightIndex := leftIndex + A_Index
                    this.AnalyzePair(group[leftIndex],
                        group[rightIndex], issues)
                }
            }
        }
        this.AnalyzeGraphRisks(descriptors, issues)
        return issues
    }

    BuildGraph(mappings) {
        descriptors := []
        nodes := []
        bySignature := Map()
        for order, mapping in mappings {
            if !mapping.HasOwnProp("Mode") || mapping.Mode != "managed"
                continue
            descriptor := mapping.HasOwnProp("Descriptor")
                ? mapping.Descriptor : RuleCompiler.Compile(mapping.Spec)
            descriptor.Order := order
            descriptors.Push(descriptor)
            nodes.Push(Map("id", descriptor.Id,
                "signature", descriptor.Signature,
                "dispatch_signature", descriptor.DispatchSignature,
                "priority", descriptor.Priority,
                "enabled", JsonBoolean(descriptor.Enabled)))
            if !descriptor.Enabled
                continue
            if !bySignature.Has(descriptor.Signature)
                bySignature[descriptor.Signature] := []
            bySignature[descriptor.Signature].Push(descriptor)
        }
        edges := []
        seenEdges := Map()
        for source in descriptors {
            if !source.Enabled
                continue
            for outputEvent in this.GetOutputEvents(source) {
                signature := outputEvent.Signature
                if !bySignature.Has(signature)
                    continue
                for target in bySignature[signature] {
                    if !this.OutputCanTrigger(outputEvent, target)
                        continue
                    edgeKey := source.Id "`n" target.Id "`noutput-trigger"
                    if seenEdges.Has(edgeKey)
                        continue
                    seenEdges[edgeKey] := true
                    edges.Push(Map("from", source.Id, "to", target.Id,
                        "kind", "output-trigger", "signature", signature,
                        "phase", outputEvent.Phase))
                }
            }
        }
        cycles := []
        edgeObjects := []
        for edge in edges
            edgeObjects.Push({From: edge["from"], To: edge["to"]})
        for cycle in this.FindDirectedCycles(descriptors, edgeObjects)
            cycles.Push(cycle)
        issues := []
        for issue in this.Analyze(mappings)
            issues.Push(Map("code", issue.Code,
                "severity", issue.Severity, "rule_id", issue.RuleId,
                "related_rule_id", issue.RelatedRuleId,
                "message", issue.Message))
        return Map("nodes", nodes, "edges", edges,
            "cycles", cycles, "issues", issues)
    }

    AnalyzeSelf(descriptor, issues) {
        if !descriptor.Enabled
            return
        reserved := Map("hotkey:^!delete", true, "hotkey:#l", true,
            "hotkey:<#l", true, "hotkey:>#l", true)
        if reserved.Has(descriptor.Signature)
            issues.Push(this.Issue("reserved-trigger", "warning",
                descriptor.Id, "", "该来源组合由 Windows 保留，无法保证拦截。"))
        for outputEvent in this.GetOutputEvents(descriptor) {
            if outputEvent.Signature != descriptor.Signature
                    || !this.OutputCanTrigger(outputEvent, descriptor)
                continue
            issues.Push(this.Issue("self-loop", "error",
                descriptor.Id, "", "规则输出会重新触发自身。"))
            break
        }
        contradiction := this.FindEqualityContradiction(
            descriptor.Spec["conditions"])
        if contradiction != ""
            issues.Push(this.Issue("unsatisfiable-condition", "error",
                descriptor.Id, "", "规则包含互相矛盾的等值条件："
                    contradiction))
        if this.HasStickyModifierAction(descriptor)
            issues.Push(this.Issue("sticky-modifier-risk", "warning",
                descriptor.Id, "",
                "规则会切换粘滞修饰键；异常退出前必须依赖输出账本释放。"))
    }

    AnalyzePair(left, right, issues) {
        if !left.Enabled || !right.Enabled
            return
        if left.DispatchSignature != right.DispatchSignature
            return
        if left.Spec["from"]["event"] != right.Spec["from"]["event"]
            return
        leftRepeat := left.Spec["from"]["repeat"]
        rightRepeat := right.Spec["from"]["repeat"]
        if (leftRepeat == "ignore" && rightRepeat == "only")
                || (leftRepeat == "only" && rightRepeat == "ignore")
            return
        if !this.ConditionsMayOverlap(left.Spec["conditions"],
                right.Spec["conditions"])
            return
        primary := RuleCompiler.HasHigherPrecedence(right, left) ? right : left
        secondary := primary.Id == left.Id ? right : left
        sameConditions := this.ConditionSetSignature(primary.Spec["conditions"])
            == this.ConditionSetSignature(secondary.Spec["conditions"])
        primaryContainsSecondary := this.ConditionSetContains(
            primary.Spec["conditions"], secondary.Spec["conditions"])
        if primaryContainsSecondary && primary.StopProcessing {
            issues.Push(this.Issue("unreachable-rule", "error",
                secondary.Id, primary.Id,
                sameConditions
                    ? "更高优先级规则具有相同来源和条件，并终止后续处理，本规则不可达。"
                    : "更高优先级规则的条件覆盖本规则并终止后续处理，本规则不可达。"))
            return
        }
        if sameConditions {
            issues.Push(this.Issue("chained-trigger", "info", secondary.Id,
                primary.Id, "相同来源和条件将按优先级串联执行。"))
            return
        }
        issues.Push(this.Issue("overlapping-trigger", "warning",
            secondary.Id, primary.Id, primary.StopProcessing
                ? "规则来源和条件可能重叠，将按优先级选择并可能终止后续处理。"
                : "规则来源和条件可能重叠，匹配时将按优先级继续求值。"))
    }

    AnalyzeGraphRisks(descriptors, issues) {
        bySignature := Map()
        for descriptor in descriptors {
            if !descriptor.Enabled
                continue
            if !bySignature.Has(descriptor.Signature)
                bySignature[descriptor.Signature] := []
            bySignature[descriptor.Signature].Push(descriptor)
        }
        edges := []
        adjacency := Map()
        for source in descriptors {
            if !source.Enabled
                continue
            for outputEvent in this.GetOutputEvents(source) {
                signature := outputEvent.Signature
                if !bySignature.Has(signature)
                    continue
                for target in bySignature[signature] {
                    if !this.OutputCanTrigger(outputEvent, target)
                        continue
                    if target.Id == source.Id
                        continue
                    edgeKey := source.Id "`n" target.Id
                    if adjacency.Has(edgeKey)
                        continue
                    adjacency[edgeKey] := true
                    edges.Push({From: source.Id, To: target.Id,
                        Kind: "output-trigger", Signature: signature,
                        Phase: outputEvent.Phase})
                    issues.Push(this.Issue("output-feedback", "warning",
                        source.Id, target.Id,
                        "规则输出会触发另一条托管规则。"))
                }
            }
        }
        for cycle in this.FindDirectedCycles(descriptors, edges) {
            Loop cycle.Length {
                index := A_Index
                relatedIndex := index == cycle.Length ? 1 : index + 1
                issues.Push(this.Issue("output-cycle", "error",
                    cycle[index], cycle[relatedIndex],
                    "规则输出图形成循环，可能导致无限回流。"))
            }
        }
        this.AnalyzeSequencePrefixes(descriptors, issues)
        return edges
    }

    AnalyzeSequencePrefixes(descriptors, issues) {
        root := this.CreatePrefixNode()
        sequences := []
        for descriptor in descriptors {
            if !descriptor.Enabled || descriptor.Mode != "sequence"
                continue
            node := root
            for key in descriptor.Spec["from"]["sequence"] {
                signature := RuleCompiler.GetKeyIdentitySignature(key)
                children := node["children"]
                if !children.Has(signature)
                    children[signature] := this.CreatePrefixNode()
                node := children[signature]
            }
            node["endings"].Push(descriptor)
            sequences.Push(descriptor)
        }
        for longer in sequences {
            node := root
            keys := longer.Spec["from"]["sequence"]
            Loop keys.Length - 1 {
                signature := RuleCompiler.GetKeyIdentitySignature(keys[A_Index])
                node := node["children"][signature]
                for shorter in node["endings"] {
                    if !this.ConditionsMayOverlap(
                            shorter.Spec["conditions"],
                            longer.Spec["conditions"])
                        continue
                    issues.Push(this.Issue("sequence-prefix", "warning",
                        longer.Id, shorter.Id,
                        "一条顺序规则是另一条规则的前缀，短规则可能抢先解析。"))
                }
            }
        }
    }

    CreatePrefixNode() {
        return Map("children", Map(), "endings", [])
    }

    HasStickyModifierAction(descriptor) {
        for actionField in RuleSpec.ActionFields {
            for action in descriptor.Spec[actionField] {
                if action["type"] == "sticky_modifier"
                    return true
            }
        }
        return false
    }

    GetOutputSignatures(descriptor) {
        signatures := []
        seen := Map()
        for outputEvent in this.GetOutputEvents(descriptor) {
            signature := outputEvent.Signature
            if seen.Has(signature)
                continue
            seen[signature] := true
            signatures.Push(signature)
        }
        return signatures
    }

    GetOutputEvents(descriptor) {
        events := []
        seen := Map()
        for actionField in RuleSpec.ActionFields {
            heldModifiers := Map()
            for action in descriptor.Spec[actionField] {
                actionType := action["type"]
                switch actionType {
                    case "send", "mouse":
                        this.AppendSendEvents(String(action["value"]),
                            heldModifiers, events, seen)
                    case "key_down":
                        this.AppendKeyEvent(String(action["value"]), "down",
                            heldModifiers, events, seen)
                    case "key_up":
                        this.AppendKeyEvent(String(action["value"]), "up",
                            heldModifiers, events, seen)
                    case "one_shot_modifier":
                        this.AppendKeyEvent(String(action["value"]), "down",
                            heldModifiers, events, seen)
                    case "sticky_modifier":
                        this.AppendKeyEvent(String(action["value"]), "down",
                            heldModifiers, events, seen)
                        this.AppendKeyEvent(String(action["value"]), "up",
                            heldModifiers, events, seen)
                }
            }
        }
        return events
    }

    AppendSendEvents(value, heldModifiers, events, seen) {
        position := 1
        foundToken := false
        while RegExMatch(value, "\{([^{}]+)\}", &match, position) {
            foundToken := true
            token := Trim(match[1])
            parts := StrSplit(token, " ")
            keyName := parts[1]
            phase := parts.Length > 1 ? StrLower(parts[2]) : "tap"
            if phase == "down" || phase == "up"
                this.AppendKeyEvent(keyName, phase, heldModifiers,
                    events, seen)
            else {
                this.AppendKeyEvent(keyName, "down", heldModifiers,
                    events, seen)
                this.AppendKeyEvent(keyName, "up", heldModifiers,
                    events, seen)
            }
            position := match.Pos + match.Len
        }
        if !foundToken && Trim(value) != "" {
            this.AppendKeyEvent(value, "down", heldModifiers, events, seen)
            this.AppendKeyEvent(value, "up", heldModifiers, events, seen)
        }
    }

    AppendKeyEvent(keyName, phase, heldModifiers, events, seen) {
        keyName := Trim(String(keyName))
        if keyName == ""
            return
        signatureValues := this.BuildOutputHotkeySignatures(keyName,
            heldModifiers)
        for signature in signatureValues {
            eventKey := signature "`n" phase
            if seen.Has(eventKey)
                continue
            seen[eventKey] := true
            events.Push({Signature: signature, Phase: phase})
        }
        modifierName := this.NormalizeModifierName(keyName)
        if modifierName == ""
            return
        if phase == "down"
            heldModifiers[modifierName] := true
        else if heldModifiers.Has(modifierName)
            heldModifiers.Delete(modifierName)
    }

    BuildOutputHotkeySignatures(keyName, heldModifiers) {
        base := RuleCompiler.NormalizeHotkeySignature(keyName)
        if base == ""
            return []
        specific := ""
        generic := ""
        modifierPrefixes := Map("lctrl", ["<^", "^"],
            "rctrl", [">^", "^"], "lshift", ["<+", "+"],
            "rshift", [">+", "+"], "lalt", ["<!", "!"],
            "ralt", [">!", "!"], "lwin", ["<#", "#"],
            "rwin", [">#", "#"])
        for modifierName in ["lctrl", "rctrl", "lshift", "rshift",
                "lalt", "ralt", "lwin", "rwin"] {
            if !heldModifiers.Has(modifierName)
                continue
            specific .= modifierPrefixes[modifierName][1]
            if !InStr(generic, modifierPrefixes[modifierName][2], true)
                generic .= modifierPrefixes[modifierName][2]
        }
        values := []
        seen := Map()
        for prefix in [specific, generic] {
            signature := "hotkey:"
                . RuleCompiler.NormalizeHotkeySignature(prefix base)
            if !seen.Has(signature) {
                seen[signature] := true
                values.Push(signature)
            }
            wildcardSignature := "hotkey:*"
                . RuleCompiler.NormalizeHotkeySignature(prefix base)
            if !seen.Has(wildcardSignature) {
                seen[wildcardSignature] := true
                values.Push(wildcardSignature)
            }
        }
        return values
    }

    NormalizeModifierName(keyName) {
        normalized := StrLower(RegExReplace(String(keyName), "\s+", ""))
        aliases := Map("lcontrol", "lctrl", "rcontrol", "rctrl",
            "lctrl", "lctrl", "rctrl", "rctrl",
            "lshift", "lshift", "rshift", "rshift",
            "lalt", "lalt", "ralt", "ralt",
            "lwin", "lwin", "rwin", "rwin")
        return aliases.Has(normalized) ? aliases[normalized] : ""
    }

    OutputCanTrigger(outputEvent, descriptor) {
        return descriptor.Spec["from"]["event"] == outputEvent.Phase
    }

    FindDirectedCycles(descriptors, edges) {
        adjacency := Map()
        for descriptor in descriptors
            adjacency[descriptor.Id] := []
        for edge in edges {
            if adjacency.Has(edge.From)
                adjacency[edge.From].Push(edge.To)
        }
        state := Map()
        stack := []
        cycles := []
        cycleKeys := Map()
        for descriptor in descriptors {
            if state.Has(descriptor.Id)
                continue
            this.VisitCycleNode(descriptor.Id, adjacency, state,
                stack, cycles, cycleKeys)
        }
        return cycles
    }

    VisitCycleNode(nodeId, adjacency, state, stack, cycles, cycleKeys) {
        frames := []
        positions := Map()
        state[nodeId] := 1
        stack.Push(nodeId)
        positions[nodeId] := stack.Length
        frames.Push({Id: nodeId, Index: 1})
        while frames.Length {
            frame := frames[frames.Length]
            neighbors := adjacency[frame.Id]
            if frame.Index > neighbors.Length {
                frames.Pop()
                state[frame.Id] := 2
                positions.Delete(frame.Id)
                stack.Pop()
                continue
            }
            nextId := neighbors[frame.Index]
            frame.Index++
            if !state.Has(nextId) {
                state[nextId] := 1
                stack.Push(nextId)
                positions[nextId] := stack.Length
                frames.Push({Id: nextId, Index: 1})
                continue
            }
            if state[nextId] != 1
                continue
            cycle := []
            startIndex := positions[nextId]
            Loop stack.Length - startIndex + 1
                cycle.Push(stack[startIndex + A_Index - 1])
            canonical := cycle.Clone()
            this.SortStrings(canonical)
            key := ""
            for id in canonical
                key .= StrLen(id) ":" id
            if !cycleKeys.Has(key) {
                cycleKeys[key] := true
                cycles.Push(cycle)
            }
        }
    }

    ConditionSetContains(containerConditions, containedConditions) {
        if !containerConditions.Length
            return true
        if !containedConditions.Length
            return false
        contained := Map()
        for condition in containedConditions
            contained[this.ConditionSignature(condition)] := true
        for condition in containerConditions {
            if !contained.Has(this.ConditionSignature(condition))
                return false
        }
        return true
    }

    ConditionsMayOverlap(leftConditions, rightConditions) {
        if !leftConditions.Length || !rightConditions.Length
            return true
        leftConstraints := this.CollectEqualityConstraints(leftConditions)
        rightConstraints := this.CollectEqualityConstraints(rightConditions)
        for constraintKey, leftValues in leftConstraints {
            if !rightConstraints.Has(constraintKey)
                continue
            for leftValue in leftValues {
                for rightValue in rightConstraints[constraintKey] {
                    if this.EqualitiesAreDisjoint(leftValue, rightValue)
                        return false
                }
            }
        }
        return true
    }

    FindEqualityContradiction(conditions) {
        constraints := this.CollectEqualityConstraints(conditions)
        for constraintKey, values in constraints {
            if values.Length < 2
                continue
            Loop values.Length - 1 {
                leftIndex := A_Index
                Loop values.Length - leftIndex {
                    if this.EqualitiesAreDisjoint(values[leftIndex],
                            values[leftIndex + A_Index])
                        return constraintKey
                }
            }
        }
        return ""
    }

    CollectEqualityConstraints(conditions) {
        result := Map()
        for condition in conditions
            this.CollectConditionEquality(condition, result)
        return result
    }

    CollectConditionEquality(condition, result) {
        condition := RuleSpec.NormalizeCondition(condition)
        if condition["negate"].Value
            return
        conditionType := condition["type"]
        if conditionType == "all" {
            for child in condition["conditions"]
                this.CollectConditionEquality(child, result)
            return
        }
        if conditionType == "any" || conditionType == "not"
                || condition["operator"] != "equals"
            return
        fieldName := conditionType == "variable"
            ? condition["name"] : condition["field"]
        constraintKey := conditionType ":" StrLower(fieldName)
        if !result.Has(constraintKey)
            result[constraintKey] := []
        result[constraintKey].Push({Value: condition["value"],
            CaseSensitive: condition["case_sensitive"].Value})
    }

    EqualitiesAreDisjoint(left, right) {
        if IsObject(left.Value) || IsObject(right.Value)
            return JsonCodec.Stringify(left.Value, false, true)
                != JsonCodec.Stringify(right.Value, false, true)
        if IsNumber(left.Value) && IsNumber(right.Value)
            return Number(left.Value) != Number(right.Value)
        leftText := String(left.Value)
        rightText := String(right.Value)
        if left.CaseSensitive && right.CaseSensitive
            return leftText != rightText
        return StrLower(leftText) != StrLower(rightText)
    }

    ConditionSetSignature(conditions) {
        signatures := []
        for condition in conditions
            signatures.Push(this.ConditionSignature(condition))
        this.SortStrings(signatures)
        result := ""
        for signature in signatures
            result .= StrLen(signature) ":" signature
        return result
    }

    ConditionSignature(condition) {
        condition := RuleSpec.NormalizeCondition(condition)
        conditionType := condition["type"]
        if conditionType == "all" || conditionType == "any" {
            children := []
            for child in condition["conditions"]
                children.Push(this.ConditionSignature(child))
            this.SortStrings(children)
            joined := ""
            for childSignature in children
                joined .= StrLen(childSignature) ":" childSignature
            return conditionType ":" condition["negate"].Value ":" joined
        }
        if conditionType == "not"
            return "not:" condition["negate"].Value ":"
                . this.ConditionSignature(condition["condition"])
        canonical := RuleSpec.Clone(condition)
        if canonical.Has("value") && !IsObject(canonical["value"])
                && !canonical["case_sensitive"].Value
            canonical["value"] := StrLower(String(canonical["value"]))
        return JsonCodec.Stringify(canonical, false, true)
    }

    SortStrings(values) {
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

    Issue(code, severity, ruleId, relatedRuleId, message) {
        return {Code: code, Severity: severity, RuleId: ruleId,
            RelatedRuleId: relatedRuleId, Message: message}
    }
}
