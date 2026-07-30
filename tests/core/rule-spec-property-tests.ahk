#Requires AutoHotkey v2.0 64-bit
#SingleInstance Off
#Warn All, StdOut

#Include ..\TestSupport.ahk
#Include ..\..\src\Core\JsonCodec.ahk
#Include ..\..\src\Core\Sha256.ahk
#Include ..\..\src\Core\RuleSpec.ahk
#Include ..\..\src\Core\RuleTimingResolver.ahk
#Include ..\..\src\Core\RuleSpecMigrationService.ahk
#Include ..\..\src\Core\RuleCompiler.ahk

RunRuleSpecPropertyTests()

RunRuleSpecPropertyTests() {
try {
    validCases := 10000
    rejectedCases := 0
    Loop validCases {
        caseNumber := A_Index
        sourceCode := 1 + Mod(caseNumber * 73, 0x1FE)
        sourceHex := Format("{:03X}", sourceCode)
        actionKind := Mod(caseNumber, 3)
        action := actionKind == 0
            ? Map("type", "send", "value", "{F" 13 + Mod(caseNumber, 11) "}")
            : (actionKind == 1
                ? Map("type", "text", "value", "值-" caseNumber)
                : Map("type", "set_variable", "name",
                    "property_" Mod(caseNumber, 29), "scope", "transient",
                    "value", Map("case", caseNumber,
                        "flags", [JsonBoolean(Mod(caseNumber, 2) == 0),
                            "保留"])))
        action["x-action"] := Map("seed", caseNumber,
            "variant", Mod(caseNumber, 17))
        condition := Map("type", "variable", "name", "mode",
            "operator", "equals", "value", Mod(caseNumber, 7),
            "x-condition", Map("case", caseNumber))
        spec := Map(
            "schema", 2,
            "id", "property-" caseNumber,
            "enabled", JsonBoolean(Mod(caseNumber, 11) != 0),
            "priority", Mod(caseNumber * 97, 200001) - 100000,
            "stop_processing", JsonBoolean(Mod(caseNumber, 5) != 0),
            "description", "property case " caseNumber,
            "display", Map("source", "SC " sourceHex,
                "target", "target " caseNumber, "scope", "测试",
                "purpose", "属性测试", "x-display", caseNumber),
            "from", Map("event", Mod(caseNumber, 4) == 0 ? "up" : "down",
                "key", Map("name", "sc" sourceHex, "sc", sourceHex,
                    "extended", JsonBoolean(sourceCode > 0xFF),
                    "x-key", Map("usage", Mod(caseNumber, 256))),
                "repeat", Mod(caseNumber, 6) == 0 ? "ignore" : "allow",
                "x-from", "preserved-" caseNumber),
            "conditions", [condition],
            "to", [action],
            "timing", Map("alone_timeout_ms", 1 + Mod(caseNumber, 60000),
                "x-timing", Map("case", caseNumber)),
            "x-root", Map("case", caseNumber,
                "values", [caseNumber, "中文", JsonBoolean(true)]))

        normalized := RuleSpec.Normalize(spec)
        canonical := JsonCodec.Stringify(normalized, false, true)
        normalizedAgain := RuleSpec.Normalize(normalized)
        AssertEqual(canonical,
            JsonCodec.Stringify(normalizedAgain, false, true),
            "RuleSpec 规范化不幂等，case=" caseNumber)

        jsonRoundTrip := RuleSpec.Normalize(JsonCodec.Parse(canonical))
        AssertEqual(canonical,
            JsonCodec.Stringify(jsonRoundTrip, false, true),
            "RuleSpec JSON 往返丢失字段，case=" caseNumber)

        if Mod(caseNumber, 50) == 0 {
            managedRoundTrip := RuleCompiler.ParseManagedSpec(
                RuleCompiler.BuildManagedBlock(normalized))
            AssertEqual(canonical,
                JsonCodec.Stringify(managedRoundTrip, false, true),
                "managed block 往返丢失字段，case=" caseNumber)
        }
        AssertTrue(jsonRoundTrip["x-root"]["case"] == caseNumber
                && jsonRoundTrip["display"]["x-display"] == caseNumber
                && jsonRoundTrip["from"]["key"]["x-key"]["usage"]
                    == Mod(caseNumber, 256)
                && jsonRoundTrip["to"][1]["x-action"]["seed"]
                    == caseNumber
                && jsonRoundTrip["conditions"][1]["x-condition"]["case"]
                    == caseNumber,
            "RuleSpec 深层扩展字段被静默丢弃，case=" caseNumber)

        if Mod(caseNumber, 4) == 0 {
            invalid := RuleSpec.Clone(normalized)
            switch Mod(caseNumber, 5) {
                case 0: invalid["id"] := "invalid id"
                case 1: invalid["priority"] := 100001
                case 2:
                    invalid["from"]["hotkey"] := "F20"
                    invalid["from"]["simultaneous"] := ["A", "B"]
                case 3: invalid["conditions"] := [Map("type", "window",
                    "operator", "regex", "value", "[")]
                case 4:
                    for fieldName in RuleSpec.ActionFields
                        invalid[fieldName] := []
            }
            rejected := false
            try RuleSpec.Normalize(invalid)
            catch
                rejected := true
            AssertTrue(rejected,
                "故障注入规则未被拒绝，case=" caseNumber)
            rejectedCases++
        }
    }
    AssertEqual(2500, rejectedCases, "故障注入用例数量错误")
    WriteTestSuccess("rule-spec-property-tests.ahk (10000 valid, 2500 rejected)")
} catch as caughtError {
    FileAppend(caughtError.Message "`n", "**")
    ExitApp(1)
}
}
