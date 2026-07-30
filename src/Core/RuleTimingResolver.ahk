class RuleTimingResolver {
    static Defaults() {
        return Map("alone_timeout_ms", 200, "held_threshold_ms", 200,
            "simultaneous_threshold_ms", 50, "sequence_timeout_ms", 500,
            "multi_tap_timeout_ms", 300, "delayed_action_ms", 200)
    }

    static NormalizeOverrides(value, label := "timing") {
        if value == ""
            return Map()
        if Type(value) != "Map"
            throw TypeError(label " 必须是对象。")
        result := RuleSpec.Clone(value)
        defaults := this.Defaults()
        inheritedFields := []
        for fieldName in result {
            if !defaults.Has(fieldName)
                continue
            fieldValue := result[fieldName]
            if Type(fieldValue) == "String"
                    && StrLower(Trim(fieldValue)) == "inherit" {
                inheritedFields.Push(fieldName)
                continue
            }
            if IsObject(fieldValue) || !IsNumber(fieldValue)
                    || Integer(fieldValue) != fieldValue
                throw TypeError(label "." fieldName " 必须是整数。")
            fieldValue := Integer(fieldValue)
            minimum := fieldName == "simultaneous_threshold_ms" ? 0 : 1
            if fieldValue < minimum || fieldValue > 60000
                throw Error(label "." fieldName " 必须在 " minimum
                    " 到 60000 之间。")
            result[fieldName] := fieldValue
        }
        for fieldName in inheritedFields
            result.Delete(fieldName)
        return result
    }

    static Resolve(ruleTiming := "", globalTiming := "") {
        effective := this.Defaults()
        sources := Map()
        for fieldName in effective
            sources[fieldName] := "default"
        this.Apply(effective, sources,
            this.NormalizeOverrides(globalTiming, "global_timing"), "global")
        this.Apply(effective, sources,
            this.NormalizeOverrides(ruleTiming, "rule.timing"), "rule")
        return {Values: effective, Sources: sources}
    }

    static Apply(effective, sources, overrides, sourceName) {
        defaults := this.Defaults()
        for fieldName, fieldValue in overrides {
            if !defaults.Has(fieldName)
                continue
            effective[fieldName] := fieldValue
            sources[fieldName] := sourceName
        }
    }
}
