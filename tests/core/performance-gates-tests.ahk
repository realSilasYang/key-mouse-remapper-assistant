#Requires AutoHotkey v2.0 64-bit
#SingleInstance Off
#Warn All, StdOut

#Include ..\TestSupport.ahk
#Include ..\..\src\Core\JsonCodec.ahk
#Include ..\..\src\Core\Sha256.ahk
#Include ..\..\src\Core\RuleSpec.ahk
#Include ..\..\src\Core\InputEvent.ahk
#Include ..\..\src\Core\RuleTimingResolver.ahk
#Include ..\..\src\Core\RuleSpecMigrationService.ahk
#Include ..\..\src\Core\RuleCompiler.ahk
#Include ..\..\src\Core\RuleConflictAnalyzer.ahk
#Include ..\..\src\Core\RuleConditionEvaluator.ahk
#Include ..\..\src\Core\ManagedRuleStateMachine.ahk
#Include ..\..\src\Core\RuleScheduler.ahk
#Include ..\..\src\Core\OutputLedger.ahk
#Include ..\..\src\Core\CrossProcessWriteLock.ahk
#Include ..\..\src\Core\ScopedVariableStore.ahk
#Include ..\..\src\Core\InputBackend.ahk
#Include ..\..\src\Core\ManagedRuleRuntime.ahk

RunPerformanceGates()

RunPerformanceGates() {
try {
    ruleCount := 500
    maximumJsonParseMs := 650
    maximumApplyMs := 200
    sourceSpecs := []
    Loop ruleCount
        sourceSpecs.Push(BuildPerformanceSpec(A_Index))
    packageJson := JsonCodec.Stringify(sourceSpecs, false, true)

    parseStarted := ReadPerformanceCounter()
    parsedSpecs := JsonCodec.Parse(packageJson)
    jsonParseMs := ElapsedMilliseconds(parseStarted)
    normalizeStarted := ReadPerformanceCounter()
    normalizedSpecs := []
    for parsedSpec in parsedSpecs
        normalizedSpecs.Push(RuleSpec.Normalize(parsedSpec))
    normalizeMs := ElapsedMilliseconds(normalizeStarted)
    compileStarted := ReadPerformanceCounter()
    mappings := []
    for normalizedSpec in normalizedSpecs {
        mappings.Push({Mode: "managed", Spec: normalizedSpec,
            Descriptor: RuleCompiler.Compile(normalizedSpec)})
    }
    compileMs := ElapsedMilliseconds(compileStarted)
    parseMs := jsonParseMs
    FileAppend("PERF stages json=" Format("{:.3f}", jsonParseMs)
        "ms normalize=" Format("{:.3f}", normalizeMs)
        "ms compile=" Format("{:.3f}", compileMs) "ms`n", "*")
    AssertTrue(mappings.Length == ruleCount,
        "性能门禁没有解析完整的 500 条规则")
    AssertTrue(parseMs < maximumJsonParseMs,
        "500 条规则 JSON 解析超过 " maximumJsonParseMs " ms："
            Format("{:.3f}", parseMs) " ms")

    app := PerformanceTestApp()
    backend := PerformanceTestBackend()
    runtime := ManagedRuleRuntime(app, backend, false)
    applyStarted := ReadPerformanceCounter()
    report := runtime.ApplyMappings(mappings)
    applyMs := ElapsedMilliseconds(applyStarted)
    AssertTrue(report.Applied == ruleCount
            && backend.Registrations.Length == ruleCount,
        "500 条规则热应用结果不完整")
    AssertTrue(applyMs < maximumApplyMs,
        "500 条规则热应用超过 " maximumApplyMs " ms："
            Format("{:.3f}", applyMs) " ms")

    eventKey := mappings[251].Spec["from"]["key"]
    downEvent := InputEvent.FromRuleKey(eventKey, "down")
    upEvent := InputEvent.FromRuleKey(eventKey, "up")
    Loop 100 {
        runtime.HandleInputEvent(downEvent)
        runtime.HandleInputEvent(upEvent)
    }
    samples := []
    Loop 2000 {
        eventStarted := ReadPerformanceCounter()
        runtime.HandleInputEvent(Mod(A_Index, 2) ? downEvent : upEvent)
        samples.Push(ElapsedMicroseconds(eventStarted))
    }
    p95Us := Percentile(samples, 95)
    AssertTrue(p95Us < 2000,
        "事件处理 P95 超过 2 ms：" Format("{:.3f}", p95Us / 1000) " ms")
    runtime.Shutdown()

    FileAppend("PERF parse500=" Format("{:.3f}", parseMs)
        "ms apply500=" Format("{:.3f}", applyMs)
        "ms eventP95=" Format("{:.3f}", p95Us / 1000) "ms`n", "*")
    WriteTestSuccess("performance-gates-tests.ahk")
} catch as caughtError {
    FileAppend(caughtError.Message "`n", "**")
    ExitApp(1)
}
}

BuildPerformanceSpec(index) {
    scanCode := Format("{:03X}", index)
    return Map("schema", 2, "id", "perf-" index,
        "enabled", JsonBoolean(true),
        "description", "performance rule " index,
        "display", Map("source", "SC " scanCode,
            "target", "state " index, "scope", "全局", "purpose", "性能门禁"),
        "from", Map("event", "down", "repeat", "allow",
            "key", Map("name", "sc" scanCode, "sc", scanCode)),
        "conditions", [],
        "to", [Map("type", "set_variable", "name", "perf_value",
            "scope", "transient", "value", index)])
}

ReadPerformanceCounter() {
    value := 0
    if !DllCall("QueryPerformanceCounter", "Int64*", &value)
        throw OSError()
    return value
}

ElapsedMicroseconds(startedAt) {
    static frequency := 0
    if !frequency && !DllCall("QueryPerformanceFrequency", "Int64*", &frequency)
        throw OSError()
    return (ReadPerformanceCounter() - startedAt) * 1000000 / frequency
}

ElapsedMilliseconds(startedAt) {
    return ElapsedMicroseconds(startedAt) / 1000
}

Percentile(samples, percentile) {
    text := ""
    for value in samples
        text .= Format("{:.6f}", value) "`n"
    sorted := StrSplit(Trim(Sort(text, "N")), "`n")
    index := Max(1, Min(sorted.Length,
        Ceil(sorted.Length * percentile / 100)))
    return Number(sorted[index])
}

class PerformanceTestApp {
    TraceEvent(category, eventName, fields := "") {
    }
}

class PerformanceTestBackend extends IInputBackend {
    __New() => this.Registrations := []
    GetBackendId() => "performance-test"
    GetCapabilities() {
        return Map("backend", this.GetBackendId(),
            "available", JsonBoolean(true))
    }
    Replace(registrations) {
        this.Registrations := registrations.Clone()
        return registrations.Length
    }
    Shutdown() => this.Registrations := []
}
