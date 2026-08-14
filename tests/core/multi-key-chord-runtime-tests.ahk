#Requires AutoHotkey v2.0 64-bit
#SingleInstance Off
#Warn All, StdOut

#Include ..\..\src\Core\JsonCodec.ahk
#Include ..\..\src\Core\Sha256.ahk
#Include ..\..\src\Core\RuleSpec.ahk
#Include ..\..\src\Core\RuleCompiler.ahk
#Include ..\..\src\Core\RuleConditionEvaluator.ahk
#Include ..\..\src\Core\DirectRuntimeSupport.ahk
#Include ..\..\src\Core\DirectHotkeyRuntime.ahk

try RunMultiKeyChordRuntimeTests()
catch as testError {
    FileAppend(testError.Message "`n" testError.Stack "`n", "**")
    ExitApp(1)
}
ExitApp(0)

RunMultiKeyChordRuntimeTests() {
    app := MultiChordTestApp()
    runtime := MultiChordTestRuntime(app)
    chord := MultiChordSpec("a-b", ["A", "B"], "F20")
    chordDescriptor := RuleCompiler.Compile(chord)
    registration := runtime.BuildRegistration(chordDescriptor)
    MultiChordAssertEqual("$B", registration.DownHotkey,
        "A multi-key chord did not use its last ordinary key as trigger.")
    MultiChordAssertEqual("$*B Up", registration.UpHotkey,
        "A multi-key chord did not register a releasable trigger.")

    runtime.SetPhysical("A", true)
    MultiChordAssertTrue(runtime.MatchesSimultaneousSource(chordDescriptor),
        "A chord did not match while every prerequisite key was held.")
    runtime.SetPhysical("A", false)
    MultiChordAssertTrue(!runtime.MatchesSimultaneousSource(chordDescriptor),
        "A chord matched while a prerequisite key was not held.")
    MultiChordAssertTrue(runtime.IsSourceInputEvent(chordDescriptor,
            Map("name", "A", "vk", 0x41, "sc", 0)),
        "A prerequisite chord key was treated as unrelated input.")

    plainB := MultiChordSingleSpec("plain-b", "B", "F21")
    chordC := MultiChordSpec("c-b", ["C", "B"], "F22")
    report := runtime.ApplyMappings([
        {Descriptor: RuleCompiler.Compile(plainB)},
        {Descriptor: chordDescriptor},
        {Descriptor: RuleCompiler.Compile(chordC)}])
    MultiChordAssertEqual(3, report.Applied,
        "Distinct chords sharing one trigger were rejected as duplicates.")
    sourceGroup := ""
    for sourceKey, candidateGroup in runtime.SourceGroups
        if candidateGroup.Hotkey == "$B"
            sourceGroup := candidateGroup
    MultiChordAssertTrue(IsObject(sourceGroup),
        "The shared B trigger group was not created.")
    runtime.SetPhysical("A", true)
    runtime.SetPhysical("C", false)
    MultiChordAssertTrue(runtime.ShouldInterceptDownGroup(sourceGroup)
            && sourceGroup.Pending.RuleIds[1] == "a-b",
        "The more specific held chord did not outrank its plain trigger.")
    MultiChordAssertTrue(runtime.OnDownGroup(sourceGroup)
            && runtime.Active.Has("a-b"),
        "The selected multi-key chord did not enter an active release cycle.")
    released := runtime.ObserveInputEvent(Map("origin", "raw-input",
        "phase", "up", "identity", Map("name", "A", "vk", 0x41,
            "sc", 0)))
    MultiChordAssertTrue(released == 1 && !runtime.Active.Has("a-b"),
        "Releasing a prerequisite key left the chord active.")
    sourceGroup.Held := false
    sourceGroup.ReleaseGroup.Held := false
    sourceGroup.ReleaseGroup.OwnerSourceGroup := ""
    runtime.SetPhysical("A", false)
    MultiChordAssertTrue(runtime.ShouldInterceptDownGroup(sourceGroup)
            && sourceGroup.Pending.RuleIds[1] == "plain-b",
        "The plain trigger did not remain available without chord prerequisites.")

    duplicateRuntime := MultiChordTestRuntime(app)
    duplicateReport := duplicateRuntime.ApplyMappings([
        {Descriptor: chordDescriptor},
        {Descriptor: RuleCompiler.Compile(MultiChordSpec(
            "duplicate-a-b", ["A", "B"], "F23"))}])
    MultiChordAssertEqual(2, duplicateReport.Applied,
        "Static conflict detection still rejected an identical source.")

    modifierChord := MultiChordSpec("modifier-only",
        ["LCtrl", "RCtrl"], "F24")
    MultiChordAssertEqual("<^RCtrl",
        RuleCompiler.Compile(modifierChord).Hotkey,
        "A chord made only of sided modifiers could not be compiled.")
    MultiChordAssertThrows(() => MultiChordSpec("ambiguous-modifiers",
        ["Ctrl", "LCtrl"], "F24"),
        "A generic modifier was combined with a sided key from the same family.")
    MultiChordAssertThrows(() => RuleSpec.Normalize(Map(
        "id", "duplicate-key-alias", "display", Map("source", "A + A",
            "target", "F24"), "from", Map("simultaneous", [
                Map("name", "A"), Map("name", "A", "sc", "01E")]),
        "to", [Map("type", "send", "value", "{F24}")])),
        "One physical key was repeated through named and scan-code aliases.")

    invalidWheelPrefix := MultiChordSpec("wheel-prefix",
        ["WheelUp", "A"], "F24")
    MultiChordAssertThrows(() => runtime.BuildRegistration(
        RuleCompiler.Compile(invalidWheelPrefix)),
        "A wheel was accepted as a prerequisite that can never stay held.")

    registrationRuntime := DirectHotkeyRuntime(app)
    try {
        registrationReport := registrationRuntime.ApplyMappings([
            {Descriptor: RuleCompiler.Compile(MultiChordSpec(
                "register-function-keys", ["F23", "F24"], "F22"))},
            {Descriptor: RuleCompiler.Compile(modifierChord)}])
        MultiChordAssertEqual(2, registrationReport.Applied,
            "AHK rejected a generated multi-key hotkey registration.")
    } finally registrationRuntime.Shutdown()

    FileAppend("PASS multi-key chord runtime`n", "*")
}

MultiChordSpec(id, keyNames, target) {
    keys := []
    for keyName in keyNames
        keys.Push(Map("name", keyName))
    return RuleSpec.Normalize(Map( "id", id,
        "display", Map("source", MultiChordJoin(keyNames, " + "),
            "target", target),
        "from", Map("simultaneous", keys),
        "to", [Map("type", "send", "value", "{" target "}")]))
}

MultiChordSingleSpec(id, keyName, target) {
    return RuleSpec.Normalize(Map( "id", id,
        "display", Map("source", keyName, "target", target),
        "from", Map("key", Map("name", keyName)),
        "to", [Map("type", "send", "value", "{" target "}")]))
}

MultiChordJoin(values, separator) {
    result := ""
    for index, value in values
        result .= (index == 1 ? "" : separator) value
    return result
}

MultiChordAssertTrue(value, message) {
    if !value
        throw Error(message)
}

MultiChordAssertEqual(expected, actual, message) {
    if expected != actual
        throw Error(message " Expected '" expected "', got '" actual "'.")
}

MultiChordAssertThrows(callback, message) {
    try callback()
    catch
        return true
    throw Error(message)
}

class MultiChordTestRuntime extends DirectHotkeyRuntime {
    __New(app) {
        super.__New(app)
        this.Physical := Map()
    }

    SetPhysical(keyName, isDown) {
        this.Physical[StrLower(String(keyName))] := !!isDown
    }

    IsPhysicalSourceDown(primary) {
        return this.Physical.Get(StrLower(String(primary)), false)
    }

    EnableRegistration(*) => true
    DisableRegistration(*) => true
    DispatchKeySequence(*) => true
}

class MultiChordTestApp {
    __New() {
        this.ContextService := {Build: (*) => Map()}
    }

    TraceEvent(*) => true
}
