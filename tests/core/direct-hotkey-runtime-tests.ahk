#Requires AutoHotkey v2.0 64-bit
#SingleInstance Off
#Warn All, StdOut

#Include ..\..\src\Core\BoundedFileReader.ahk
#Include ..\..\src\Core\JsonCodec.ahk
#Include ..\..\src\Core\Sha256.ahk
#Include ..\..\src\Core\CrossProcessWriteLock.ahk
#Include ..\..\src\Core\RuleSpec.ahk
#Include ..\..\src\Core\ScriptRuleSpec.ahk
#Include ..\..\src\Core\RuleCompiler.ahk
#Include ..\..\src\Core\ScriptRuleCompiler.ahk
#Include ..\..\src\Core\RuleConditionEvaluator.ahk
#Include ..\..\src\Core\InputEvent.ahk
#Include ..\..\src\Core\DirectRuntimeSupport.ahk
#Include ..\..\src\Core\DirectHotkeyRuntime.ahk
#Include ..\..\src\Core\CompositeRemappingRuntime.ahk
#Include ..\..\src\Core\MappingCodeRepository.ahk

try {
    repository := MappingCodeRepository(A_ScriptDir
        "\..\..\键鼠重映射小助手.ahk")
    mappings := repository.Load()
    AssertTrue(mappings.Length > 0, "No built-in mappings were loaded.")
    managedMappings := []
    scriptMappings := []
    for mapping in mappings {
        if mapping.Mode == "managed"
            managedMappings.Push(mapping)
        else if mapping.Mode == "script"
            scriptMappings.Push(mapping)
    }
    AssertEqual(mappings.Length,
        managedMappings.Length + scriptMappings.Length,
        "A built-in mapping has an unknown mode.")
    branchDirect := CompositeBranchDirectProbe()
    branchScripts := CompositeBranchScriptProbe()
    branchRuntime := CompositeRemappingRuntime({}, branchDirect,
        branchScripts)
    branchManaged := repository.CloneMapping(managedMappings[1])
    branchManaged.Spec["enabled"] := JsonBoolean(false)
    branchManaged.Descriptor := RuleCompiler.Compile(branchManaged.Spec)
    branchScript := repository.CloneMapping(scriptMappings[1])
    branchScript.Spec["enabled"] := JsonBoolean(false)
    branchRuntime.ApplyMappings([branchManaged, branchScript])
    branchRuntime.ApplyMappings([branchManaged, branchScript])
    AssertTrue(branchDirect.ApplyCount == 1
            && branchScripts.ApplyCount == 1,
        "An unchanged composite runtime branch was applied twice.")
    changedBranchManaged := repository.CloneMapping(branchManaged)
    changedBranchManaged.Spec["description"] := "branch changed"
    changedBranchManaged.Descriptor := RuleCompiler.Compile(
        changedBranchManaged.Spec)
    branchRuntime.ApplyMappings([changedBranchManaged, branchScript])
    AssertTrue(branchDirect.ApplyCount == 2
            && branchScripts.ApplyCount == 1,
        "Editing a managed rule unnecessarily reapplied script workers.")
    changedBranchScript := repository.CloneMapping(branchScript)
    changedBranchScript.Spec["code"] .= "`n; branch changed"
    branchRuntime.ApplyMappings([changedBranchManaged,
        changedBranchScript])
    AssertTrue(branchDirect.ApplyCount == 2
            && branchScripts.ApplyCount == 2,
        "Editing a script unnecessarily reregistered managed hotkeys.")
    if EnvGet("COMPOSITE_BRANCH_ONLY") == "1" {
        FileAppend("PASS composite runtime branch isolation`n", "*")
        ExitApp(0)
    }
    suspendFailureProbe := SuspendFailureRuntime({})
    firstSuspendRegistration := {Id: "first", Disabled: false}
    secondSuspendRegistration := {Id: "second", Disabled: false}
    suspendFailureProbe.Registrations := [firstSuspendRegistration,
        secondSuspendRegistration]
    AssertThrows(() => suspendFailureProbe.Suspend(),
        "A partial direct-runtime suspend failure was hidden.")
    AssertTrue(!suspendFailureProbe.Suspended
            && !firstSuspendRegistration.Disabled
            && !secondSuspendRegistration.Disabled
            && suspendFailureProbe.EnableCalls == 1,
        "A partial direct-runtime suspend was not rolled back.")
    wordStyles := FindManagedMappingBySource(mappings, "Z", ["Alt"])
    AssertTrue(!wordStyles.Spec.Has("enabled"),
        "Enabled=true should be omitted from normalized RuleSpec.")
    AssertTrue(!wordStyles.Spec["from"].Has("event"),
        "event=down should be omitted from normalized RuleSpec.")
    AssertTrue(!wordStyles.Spec["from"]["key"].Has("kind"),
        "kind=keyboard should be omitted from normalized key identity.")
    AssertTrue(!wordStyles.Spec["from"]["key"].Has("extended"),
        "extended=false should be omitted from normalized key identity.")
    AssertTrue(!wordStyles.Spec["from"].Has("optional_modifiers")
            && !wordStyles.Spec["from"].Has("simultaneous")
            && !wordStyles.Spec["from"].Has("tap_count"),
        "Empty/default source fields should be omitted.")
    condition := wordStyles.Spec["conditions"][1]
    AssertTrue(!condition.Has("operator")
            && !condition.Has("case_sensitive")
            && !condition.Has("negate"),
        "Default condition fields should be omitted.")
    AssertTrue(!wordStyles.Spec["to"][1].Has("repeat")
            && !wordStyles.Spec["to"][1].Has("repeat_interval_ms"),
        "Default action repetition fields should be omitted.")

    app := DirectRuntimeTestApp()
    runtime := DirectHotkeyRuntime(app)
    liveContext := DirectContextService().Build()
    AssertTrue(Type(liveContext) == "Map"
            && liveContext.Has("application")
            && liveContext.Has("window")
            && liveContext.Has("input_source")
            && liveContext.Has("session")
            && !liveContext.Has("variables"),
        "The direct runtime context could not be built from the live desktop.")
    registrations := Map()
    for mapping in managedMappings {
        registration := runtime.BuildRegistration(mapping.Descriptor)
        registrations[mapping.Id] := registration
        AssertTrue(registration.DownHotkey != ""
                || registration.UpHotkey != "",
            "A built-in rule has no hotkey registration: " mapping.Id)
        preservesOriginal := mapping.Descriptor.Spec.Get("passthrough",
            JsonBoolean(false)).Value
        expectsImmediatePassthrough := preservesOriginal
            && !runtime.DefersOriginalInput(mapping.Descriptor)
        AssertEqual(expectsImmediatePassthrough, InStr(
            registration.DownHotkey " " registration.UpHotkey, "~") > 0,
            "Hotkey passthrough mode did not match the rule: " mapping.Id)
    }
    printScreen := FindManagedMappingBySource(mappings, "PrintScreen")
    ctrlSpace := FindManagedMappingBySource(mappings, "Space", ["Ctrl"])
    f1 := FindManagedMappingBySource(mappings, "F1")
    AssertEqual("$PrintScreen Up",
        registrations[printScreen.Id].UpHotkey,
        "PrintScreen should register exactly one Up suffix.")
    AssertEqual("$^Space",
        registrations[ctrlSpace.Id].DownHotkey,
        "Ctrl+Space hotkey changed unexpectedly.")
    AssertEqual("$*Space Up",
        registrations[ctrlSpace.Id].UpHotkey,
        "Ctrl+Space must release even after Ctrl is lifted.")
    AssertTrue(f1.Spec["passthrough"].Value,
        "F1 short presses must explicitly preserve their original input.")
    AssertEqual("$F1", registrations[f1.Id].DownHotkey,
        "F1 must suppress its physical key-down until hold detection finishes.")
    AssertEqual("$*F1 Up", registrations[f1.Id].UpHotkey,
        "F1 must suppress its physical release until hold detection finishes.")
    AssertEqual("{Browser_Back}", runtime.BuildAppCommandSend("Browser_Back"),
        "App-command actions must use AHK key-sequence syntax.")
    outputDispatchRuntime := OutputDispatchRecordingRuntime(app)
    previousKeyDelay := A_KeyDelay
    previousKeyDuration := A_KeyDuration
    previousCritical := A_IsCritical
    try {
        Critical("Off")
        SetKeyDelay(23, 31)
        AssertTrue(outputDispatchRuntime.SendKeySequence("^+!{F24}"),
            "A complex shortcut was not dispatched.")
        dispatch := outputDispatchRuntime.Dispatches[1]
        AssertEqual("^+!{F24}", dispatch.Sequence,
            "The complex shortcut changed before dispatch.")
        AssertTrue(dispatch.Critical,
            "A complex shortcut remained interruptible during dispatch.")
        AssertEqual(DirectHotkeyRuntime.OutputKeyDelayMs, dispatch.Delay,
            "Complex shortcut key spacing was not applied.")
        AssertEqual(DirectHotkeyRuntime.OutputPressDurationMs,
            dispatch.Duration,
            "Complex shortcut press duration was not applied.")
        AssertTrue(!A_IsCritical && A_KeyDelay == 23 && A_KeyDuration == 31,
            "Successful output dispatch did not restore thread settings.")
        outputDispatchRuntime.FailDispatch := true
        AssertThrows(() => outputDispatchRuntime.SendKeySequence("{F24}"),
            "A failed output dispatch did not propagate its error.")
        AssertTrue(!A_IsCritical && A_KeyDelay == 23 && A_KeyDuration == 31,
            "Failed output dispatch did not restore thread settings.")
    } finally {
        SetKeyDelay(previousKeyDelay, previousKeyDuration)
        Critical(previousCritical ? previousCritical : "Off")
    }
    expectedValidationCommand := Chr(34) A_AhkPath Chr(34)
        . " /ErrorStdOut " Chr(34) A_ScriptFullPath Chr(34)
        . " --startup-validation"
    expectedSourceHandoffCommand := Chr(34) A_AhkPath Chr(34) " "
        . Chr(34) A_ScriptFullPath Chr(34)
        . " --reload-handoff 1234 --show-main"
    expectedCompiledHandoffCommand := Chr(34) A_ScriptFullPath Chr(34)
        . " --reload-handoff 1234 --show-main"
    elevationReadyPath := A_Temp "\elevation ready.signal"
    expectedElevationCommand := Chr(34) A_AhkPath Chr(34) " "
        . Chr(34) A_ScriptFullPath Chr(34) " "
        . Chr(34) "--packaged" Chr(34) " "
        . Chr(34) "--update-ready" Chr(34) " "
        . Chr(34) elevationReadyPath Chr(34)
        . " --reload-handoff 1234 --elevation-handoff --show-main"
    AssertEqual(expectedValidationCommand,
        BuildReloadValidationCommand(A_AhkPath, A_ScriptFullPath),
        "Reload validation command changed unexpectedly.")
    AssertEqual(expectedSourceHandoffCommand,
        BuildReloadHandoffCommand(1234, false, A_AhkPath, A_ScriptFullPath),
        "Source reload handoff command changed unexpectedly.")
    AssertEqual(expectedCompiledHandoffCommand,
        BuildReloadHandoffCommand(1234, true, A_AhkPath, A_ScriptFullPath),
        "Compiled reload handoff command changed unexpectedly.")
    AssertEqual(expectedElevationCommand,
        BuildApplicationElevationCommand(1234, false, A_AhkPath,
            A_ScriptFullPath, ["--packaged", "--reload-handoff", "77",
                "--show-main", "--update-ready", elevationReadyPath]),
        "Elevation handoff did not replace stale process arguments safely.")

    minimal := RuleSpec.Normalize(Map( "id", "minimal-rule",
        "display", Map("source", "F24", "target", "F23"),
        "from", Map("key", Map("name", "F24")),
        "to", [Map("type", "send", "value", "{F23}")]))
    minimalDescriptor := RuleCompiler.Compile(minimal)
    AssertTrue(minimalDescriptor.Enabled,
        "Missing enabled must default to true.")
    AssertEqual("$F24",
        runtime.BuildRegistration(minimalDescriptor).DownHotkey,
        "Minimal defaulted RuleSpec did not produce a usable hotkey.")
    AssertTrue(!minimal.Has("passthrough"),
        "Suppression must remain the default for remapping rules.")

    sameKeySource := {Display: "F24", KeyName: "F24", Kind: "keyboard",
        SourceSpec: "F24", VKHex: "", SCHex: ""}
    sameKeyTarget := {Display: "F24", TargetSend: "{F24}"}
    sameKeySpec := RuleSpec.CreateFromCaptures("same-key-rule",
        sameKeySource, sameKeyTarget)
    AssertEqual("F24", sameKeySpec["display"]["source"],
        "Same-key mappings must retain the captured source.")
    AssertEqual("F24", sameKeySpec["display"]["target"],
        "Same-key mappings must retain the captured target.")
    sameKeyDescriptor := RuleCompiler.Compile(sameKeySpec)
    AssertEqual("$F24", runtime.BuildRegistration(sameKeyDescriptor).DownHotkey,
        "Same-key mappings must remain valid runtime rules.")

    leftCtrlInfo := {KeyName: "LCtrl"}
    rightCtrlInfo := {KeyName: "RCtrl"}
    sidedSourceCapture := {Display: "LCtrl + A", RawDisplay: "LCtrl + A",
        KeyName: "A", SourceSpec: "<^sc01E", VKHex: "41", SCHex: "01E",
        Modifiers: [leftCtrlInfo], IsSimultaneous: false}
    sidedTargetCapture := {Display: "LCtrl + F12",
        RawDisplay: "LCtrl + F12",
        TargetSend: "{LCtrl down}{F12}{LCtrl up}"}
    sidedModifierSpec := RuleSpec.CreateFromCaptures("sided-modifier-rule",
        sidedSourceCapture, sidedTargetCapture, true)
    genericModifierSpec := RuleSpec.CreateFromCaptures(
        "generic-modifier-rule", sidedSourceCapture, sidedTargetCapture,
        false)
    AssertEqual("LCtrl", sidedModifierSpec["from"]["modifiers"][1],
        "The enabled side distinction discarded the recorded modifier side.")
    AssertEqual("Ctrl", genericModifierSpec["from"]["modifiers"][1],
        "The disabled side distinction retained a sided modifier.")
    AssertEqual("Ctrl + A", genericModifierSpec["display"]["source"],
        "The generic source display did not match its trigger semantics.")
    AssertEqual("^sc01E", RuleCompiler.Compile(genericModifierSpec).Hotkey,
        "A generic captured modifier did not compile for either side.")
    AssertEqual("{LCtrl down}{F12}{LCtrl up}",
        genericModifierSpec["to"][1]["value"],
        "Source-side normalization changed the recorded target output.")

    bothCtrlSourceCapture := {Display: "LCtrl + RCtrl + A",
        RawDisplay: "LCtrl + RCtrl + A", KeyName: "A",
        SourceSpec: "<^>^sc01E", VKHex: "41", SCHex: "01E",
        Modifiers: [leftCtrlInfo, rightCtrlInfo], IsSimultaneous: false}
    bothCtrlGenericSpec := RuleSpec.CreateFromCaptures(
        "generic-both-ctrl-rule", bothCtrlSourceCapture, sidedTargetCapture,
        false)
    AssertEqual(1, bothCtrlGenericSpec["from"]["modifiers"].Length,
        "Generic modifier capture retained duplicate family requirements.")
    AssertEqual("Ctrl + A", bothCtrlGenericSpec["display"]["source"],
        "Generic modifier display retained duplicate family labels.")

    leftCtrlSourceCapture := {Display: "LCtrl", RawDisplay: "LCtrl",
        KeyName: "LCtrl", SourceSpec: "sc01D", VKHex: "A2", SCHex: "01D",
        Modifiers: [], IsSimultaneous: false}
    genericCtrlPrimarySpec := RuleSpec.CreateFromCaptures(
        "generic-ctrl-primary-rule", leftCtrlSourceCapture,
        sidedTargetCapture, false)
    AssertEqual("Ctrl", genericCtrlPrimarySpec["from"]["key"]["name"],
        "A primary sided modifier was not converted to a generic key.")
    AssertTrue(!genericCtrlPrimarySpec["from"]["key"].Has("vk")
            && !genericCtrlPrimarySpec["from"]["key"].Has("sc"),
        "A generic primary modifier retained side-specific key codes.")
    AssertEqual("Ctrl", RuleCompiler.Compile(genericCtrlPrimarySpec).Hotkey,
        "A generic primary modifier did not compile as a generic key.")
    genericPrimaryRuntime := DirectHotkeyRuntime(app)
    genericPrimaryReport := genericPrimaryRuntime.ApplyMappings([
        {Descriptor: RuleCompiler.Compile(genericCtrlPrimarySpec)}])
    AssertEqual(1, genericPrimaryReport.Applied,
        "A generic primary modifier could not be registered by AutoHotkey.")
    genericPrimaryRuntime.Shutdown()
    neutralAltTapHold := RuleSpec.Normalize(Map(
        "id", "neutral-alt-tap-hold",
        "display", Map("source", "Alt", "target", "tap suppressed"),
        "from", Map("key", Map("name", "Alt"), "repeat", "ignore"),
        "to_if_alone", [Map("type", "sleep", "value", 1)],
        "to_if_held_down", [Map("type", "key_down", "value", "Alt")],
        "to_after_key_up", [Map("type", "key_up", "value", "Alt")],
        "timing", Map("held_threshold_ms", 180)))
    AssertTrue(RuleCompiler.GetManagedScriptRequirement(
            RuleCompiler.Compile(neutralAltTapHold)) != "",
        "A neutral Alt tap/hold rule was considered suitable for AI-managed output.")

    neutralCtrlDown := RuleSpec.Clone(minimal)
    neutralCtrlDown["id"] := "neutral-ctrl-down"
    neutralCtrlDown["display"]["source"] := "Ctrl"
    neutralCtrlDown["from"]["key"]["name"] := "Ctrl"
    AssertTrue(RuleCompiler.GetManagedScriptRequirement(
            RuleCompiler.Compile(neutralCtrlDown)) != "",
        "A neutral modifier down rule was considered suitable for AI-managed output.")

    sidedAltTapHold := RuleSpec.Clone(neutralAltTapHold)
    sidedAltTapHold["id"] := "left-alt-tap-hold"
    sidedAltTapHold["display"]["source"] := "LAlt"
    sidedAltTapHold["from"]["key"]["name"] := "LAlt"
    AssertTrue(RuleCompiler.GetManagedScriptRequirement(
            RuleCompiler.Compile(sidedAltTapHold)) != "",
        "A sided modifier tap/hold rule was considered suitable for AI-managed output.")

    passthrough := RuleSpec.Normalize(Map(
        "id", "passthrough-rule", "passthrough", JsonBoolean(true),
        "display", Map("source", "F22", "target", "F21"),
        "from", Map("key", Map("name", "F22"), "repeat", "ignore"),
        "to_if_alone", [Map("type", "send", "value", "{F22}")],
        "to_if_held_down", [Map("type", "send", "value", "{F21}")]))
    passthroughRegistration := runtime.BuildRegistration(
        RuleCompiler.Compile(passthrough))
    AssertEqual("$F22", passthroughRegistration.DownHotkey,
        "Held passthrough rules must defer the original key-down event.")
    AssertEqual("$*F22 Up", passthroughRegistration.UpHotkey,
        "Held passthrough rules must defer release tracking as well.")

    immediatePassthrough := RuleSpec.Normalize(Map(
        "id", "immediate-passthrough-rule", "passthrough", JsonBoolean(true),
        "display", Map("source", "F23", "target", "F22"),
        "from", Map("key", Map("name", "F23")),
        "to", [Map("type", "send", "value", "{F22}")] ))
    immediateRegistration := runtime.BuildRegistration(
        RuleCompiler.Compile(immediatePassthrough))
    AssertEqual("$~F23", immediateRegistration.DownHotkey,
        "Passthrough rules without hold detection should remain immediate.")

    modifierPassthrough := RuleSpec.Normalize(Map(
        "id", "modifier-passthrough-rule", "passthrough", JsonBoolean(true),
        "display", Map("source", "Ctrl + F20", "target", "F19"),
        "from", Map("key", Map("name", "F20"), "modifiers", ["Ctrl"],
            "repeat", "ignore"),
        "to_if_held_down", [Map("type", "send", "value", "{F19}")]))
    modifierDescriptor := RuleCompiler.Compile(modifierPassthrough)
    AssertEqual("{Blind}{LCtrl down}{F20}{LCtrl up}",
        runtime.BuildOriginalInputSend(modifierDescriptor,
            {ReplayModifiers: ["LCtrl"]}),
        "Deferred passthrough must replay an ordinary modifier rule too.")
    AssertEqual("{Blind}{LShift down}{F20}{LShift up}",
        runtime.BuildOriginalInputSend(modifierDescriptor,
            {ReplayModifiers: ["LShift"]}),
        "Deferred passthrough must preserve optional modifier state too.")

    conditionalApp := DirectRuntimeTestApp()
    conditionalRuntime := DirectHotkeyRuntime(conditionalApp)
    officeRedo := FindManagedMappingBySource(mappings, "Z",
        ["Ctrl", "Shift"])
    conditionalRuntime.Rules[officeRedo.Id] := officeRedo.Descriptor
    conditionalApp.ContextService := FixedContextService(Map("application",
        Map("process", "WINWORD.EXE")))
    AssertTrue(conditionalRuntime.ShouldInterceptDown(officeRedo.Id),
        "Scoped rules must intercept their source when the condition matches.")
    conditionalApp.ContextService := FixedContextService(Map("application",
        Map("process", "notepad.exe")))
    AssertTrue(!conditionalRuntime.ShouldInterceptDown(officeRedo.Id),
        "Scoped rules must leave the source input untouched outside scope.")
    AssertTrue(runtime.GetCapabilities()["suppresses_original_input"].Value,
        "Direct runtime must report original-input suppression.")

    tempScript := A_ScriptDir "\..\..\.syntax-check-repo-edit-"
        . A_TickCount "-" Format("{:08X}", Random(0, 0xFFFFFFFF)) ".ahk"
    try {
        FileCopy(repository.ScriptPath, tempScript, true)
        tempRepository := MappingCodeRepository(tempScript)
        editableSpec := Map("id", tempRepository.CreateMappingName(
                tempRepository.Load()),
            "display", Map("source", "F24", "target", "F23",
                "scope", "全局"),
            "from", Map("key", Map("name", "F24")),
            "to", [Map("type", "send", "value", "{F23}")])
        editableBlock := RuleCompiler.BuildManagedBlock(editableSpec)
        editableBlock := StrReplace(editableBlock,
            "; @映射结果=F23", "; @映射结果=F22")
        editableBlock := StrReplace(editableBlock, '"value": "{F23}"',
            '"value": "{F22}"')
        editedSpec := RuleCompiler.ParseManagedSpec(editableBlock)
        AssertEqual("F22", editedSpec["display"]["target"],
            "Directly edited blocks should parse without a digest.")
        addedMapping := tempRepository.AppendBlock(editableBlock)
        AssertEqual("F22", addedMapping.Target,
            "Edited blocks should preserve metadata changes on append.")
        AssertEqual("{F22}", addedMapping.Spec["to"][1]["value"],
            "Edited action value was not preserved while rebuilding.")
        AssertEqual(mappings.Length + 1, tempRepository.Load().Length,
            "Appending the edited block did not add exactly one rule.")
    } finally {
        if FileExist(tempScript)
            FileDelete(tempScript)
    }

    report := runtime.ApplyMappings(managedMappings)
    enabledManagedCount := 0
    for mapping in managedMappings {
        if mapping.Enabled
            enabledManagedCount++
    }
    AssertEqual(enabledManagedCount, report.Applied,
        "Not every enabled built-in mapping registered through Hotkey().")

    suspendedRuntime := SuspendedDirectHotkeyRuntime(app)
    suspendedRuntime.Suspend()
    suspendedReport := suspendedRuntime.ApplyMappings(managedMappings)
    AssertEqual(0, suspendedRuntime.EnableCalls,
        "Applying rules during capture must keep the runtime suspended.")
    suspendedRuntime.Resume()
    AssertEqual(suspendedReport.Registrations, suspendedRuntime.EnableCalls,
        "Resuming after a suspended apply did not register every hotkey.")

    f1Descriptor := RuleCompiler.Compile(f1.Spec)
    timerRuntime := RecordingDirectHotkeyRuntime(app)
    timerRuntime.Rules[f1Descriptor.Id] := f1Descriptor
    AssertTrue(timerRuntime.OnDown(f1Descriptor.Id),
        "F1 long-press timing did not accept the initial key-down.")
    repeatCallback := (*) => timerRuntime.HandleDown(
        f1Descriptor.Id, true, true)
    SetTimer(repeatCallback, 10)
    try Sleep(350)
    finally SetTimer(repeatCallback, 0)
    AssertTrue(timerRuntime.Active.Has(f1Descriptor.Id)
            && timerRuntime.Active[f1Descriptor.Id].HeldFired
            && timerRuntime.Events.Length == 1,
        "F1 long-press output did not run exactly once at the hold threshold.")
    timerRuntime.OnUp(f1Descriptor.Id)
    AssertTrue(!timerRuntime.Active.Has(f1Descriptor.Id)
            && timerRuntime.Events.Length == 1,
        "F1 long-press output was lost, duplicated, or left active after release.")

    stressRuntime := LongPressStressDirectHotkeyRuntime(app)
    stressRuntime.Rules[f1Descriptor.Id] := f1Descriptor
    Loop 100 {
        AssertTrue(stressRuntime.OnDown(f1Descriptor.Id),
            "A long-press stress cycle rejected its initial F1 down event.")
        Loop 20
            stressRuntime.HandleDown(f1Descriptor.Id, true, true)
        AssertTrue(stressRuntime.OnHeld(f1Descriptor.Id),
            "A long-press stress cycle did not recognize held F1.")
        Loop 20
            stressRuntime.HandleDown(f1Descriptor.Id, true, true)
        AssertTrue(stressRuntime.OnUp(f1Descriptor.Id),
            "A long-press stress cycle did not finish its F1 release.")
    }
    AssertTrue(stressRuntime.Events.Length == 100
            && stressRuntime.OriginalInputs.Length == 0
            && stressRuntime.Active.Count == 0,
        "Repeated F1 long presses were lost, duplicated, or left active state.")

    heldPassthroughDescriptor := RuleCompiler.Compile(passthrough)
    deferredRuntime := DeferredPassthroughRuntime(app)
    deferredRuntime.Rules[heldPassthroughDescriptor.Id] :=
        heldPassthroughDescriptor
    deferredRuntime.OnDown(heldPassthroughDescriptor.Id)
    AssertTrue(deferredRuntime.Active.Has(heldPassthroughDescriptor.Id),
        "A held passthrough rule did not create held state.")
    deferredRuntime.OnHeld(heldPassthroughDescriptor.Id)
    AssertEqual(0, deferredRuntime.OriginalInputs.Length,
        "A recognized long press must not replay the original input.")
    deferredRuntime.OnUp(heldPassthroughDescriptor.Id)
    AssertTrue(!deferredRuntime.Active.Has(heldPassthroughDescriptor.Id),
        "Held passthrough release did not clear held state.")

    deferredRuntime.OnDown(heldPassthroughDescriptor.Id)
    deferredRuntime.OnUp(heldPassthroughDescriptor.Id)
    AssertEqual(1, deferredRuntime.OriginalInputs.Length,
        "A short passthrough press must replay the original input once.")
    AssertEqual(heldPassthroughDescriptor.Id,
        deferredRuntime.OriginalInputs[1],
        "The deferred original input was replayed for the wrong rule.")

    f1PassthroughRuntime := DeferredPassthroughRuntime(app)
    f1PassthroughRuntime.Rules[f1Descriptor.Id] := f1Descriptor
    f1PassthroughRuntime.OnDown(f1Descriptor.Id)
    f1PassthroughRuntime.OnHeld(f1Descriptor.Id)
    f1PassthroughRuntime.OnUp(f1Descriptor.Id)
    AssertEqual(0, f1PassthroughRuntime.OriginalInputs.Length,
        "A recognized F1 long press replayed the suppressed short press.")
    f1PassthroughRuntime.OnDown(f1Descriptor.Id)
    f1PassthroughRuntime.OnUp(f1Descriptor.Id)
    AssertEqual(1, f1PassthroughRuntime.OriginalInputs.Length,
        "An F1 short press was not replayed exactly once on release.")
    AssertEqual(f1Descriptor.Id, f1PassthroughRuntime.OriginalInputs[1],
        "The deferred F1 short press was attributed to the wrong rule.")

    failureRuntime := FailingDirectHotkeyRuntime(app)
    downFailure := RuleCompiler.Compile(RuleSpec.Normalize(Map(
        "id", "down-failure",
        "display", Map("source", "F22", "target", "F23"),
        "from", Map("key", Map("name", "F22"), "repeat", "ignore"),
        "to", [Map("type", "send", "value", "{F23}")])) )
    failureRuntime.Rules[downFailure.Id] := downFailure
    failureRuntime.FailField := "to"
    AssertTrue(!failureRuntime.OnDown(downFailure.Id),
        "A failed down action should return false.")
    AssertTrue(!failureRuntime.Active.Has(downFailure.Id),
        "A failed down action left an active rule behind.")

    upFailure := RuleCompiler.Compile(RuleSpec.Normalize(Map(
        "id", "up-failure",
        "display", Map("source", "F21", "target", "F20"),
        "from", Map("key", Map("name", "F21"), "repeat", "ignore"),
        "to_after_key_up", [Map("type", "send", "value", "{F20}")])) )
    failureRuntime.Rules[upFailure.Id] := upFailure
    failureRuntime.FailField := "to_after_key_up"
    AssertTrue(failureRuntime.OnDown(upFailure.Id),
        "The setup down event for up failure did not run.")
    AssertTrue(failureRuntime.Active.Has(upFailure.Id),
        "The setup down event for up failure did not create active state.")
    AssertTrue(failureRuntime.OnUp(upFailure.Id),
        "A failed up action should still finish release handling.")
    AssertTrue(!failureRuntime.Active.Has(upFailure.Id),
        "A failed up action left an active rule behind.")

    heldFailure := RuleCompiler.Compile(RuleSpec.Normalize(Map(
        "id", "held-failure",
        "display", Map("source", "F20", "target", "F19"),
        "from", Map("key", Map("name", "F20"), "repeat", "ignore"),
        "to_if_held_down", [Map("type", "send", "value", "{F19}")])) )
    failureRuntime.Rules[heldFailure.Id] := heldFailure
    failureRuntime.FailField := "to_if_held_down"
    AssertTrue(failureRuntime.OnDown(heldFailure.Id),
        "The setup down event for held failure did not run.")
    AssertTrue(failureRuntime.Active.Has(heldFailure.Id),
        "The setup down event for held failure did not create active state.")
    AssertTrue(!failureRuntime.OnHeld(heldFailure.Id),
        "A failed one-shot held action should fail at the hold threshold.")
    AssertTrue(!failureRuntime.Active.Has(heldFailure.Id),
        "A failed one-shot held action left an active rule behind.")
    AssertTrue(!failureRuntime.OnUp(heldFailure.Id),
        "A failed held action retained stale release handling.")

    statefulHeldFailure := RuleCompiler.Compile(RuleSpec.Normalize(Map(
         "id", "stateful-held-failure",
        "display", Map("source", "F18", "target", "F17"),
        "from", Map("key", Map("name", "F18"), "repeat", "ignore"),
        "to_if_held_down", [Map("type", "key_down", "value", "F17")])) )
    failureRuntime.Rules[statefulHeldFailure.Id] := statefulHeldFailure
    AssertTrue(failureRuntime.OnDown(statefulHeldFailure.Id),
        "The stateful held failure did not create source state.")
    AssertTrue(!failureRuntime.OnHeld(statefulHeldFailure.Id),
        "A failed stateful held action should run and fail at the threshold.")
    AssertTrue(!failureRuntime.Active.Has(statefulHeldFailure.Id),
        "A failed stateful held action left an active rule behind.")

    heldOwnershipRuntime := OwnershipDirectHotkeyRuntime(app)
    heldOwnershipSpec := RuleSpec.Normalize(Map(
        "id", "stateful-held-ownership",
        "display", Map("source", "F16", "target", "F15"),
        "from", Map("key", Map("name", "F16"), "repeat", "ignore"),
        "to_if_held_down", [Map("type", "key_down", "value", "F15")]))
    heldOwnershipDescriptor := RuleCompiler.Compile(heldOwnershipSpec)
    heldOwnershipRuntime.Rules[heldOwnershipDescriptor.Id] :=
        heldOwnershipDescriptor
    heldOwnershipRuntime.OnDown(heldOwnershipDescriptor.Id)
    AssertTrue(heldOwnershipRuntime.OnHeld(heldOwnershipDescriptor.Id)
            && heldOwnershipRuntime.Events.Length == 1
            && heldOwnershipRuntime.Events[1] == "F15 down",
        "A stateful held action was incorrectly deferred until release.")
    heldOwnershipRuntime.OnUp(heldOwnershipDescriptor.Id)
    AssertTrue(heldOwnershipRuntime.Events.Length == 2
            && heldOwnershipRuntime.Events[2] == "F15 up",
        "A stateful held output was not released with its source.")

    ownershipRuntime := OwnershipDirectHotkeyRuntime(app)
    ownershipRules := []
    for sourceName in ["F18", "F19"] {
        ownershipSpec := RuleSpec.Normalize(Map(
            "id", "owner-" sourceName,
            "display", Map("source", sourceName, "target", "F17"),
            "from", Map("key", Map("name", sourceName), "repeat", "ignore"),
            "to", [Map("type", "key_down", "value", "F17")]))
        ownershipDescriptor := RuleCompiler.Compile(ownershipSpec)
        ownershipRuntime.Rules[ownershipDescriptor.Id] := ownershipDescriptor
        ownershipRules.Push(ownershipDescriptor)
    }
    ownershipRuntime.OnDown(ownershipRules[1].Id)
    ownershipRuntime.OnDown(ownershipRules[2].Id)
    AssertEqual("F17 down", ownershipRuntime.Events[1],
        "The first output owner did not press the target key.")
    AssertEqual(1, ownershipRuntime.Events.Length,
        "A second output owner should not press an already-held target key.")
    ownershipRuntime.OnUp(ownershipRules[1].Id)
    AssertEqual(1, ownershipRuntime.Events.Length,
        "Releasing one owner must not release a shared target key.")
    ownershipRuntime.OnUp(ownershipRules[2].Id)
    AssertEqual("F17 up", ownershipRuntime.Events[2],
        "The final output owner did not release the target key.")
    AssertTrue(!ownershipRuntime.ReleaseOutputKey(ownershipRules[1].Id,
            "F17"), "An unowned key_up action should not send an output event.")
    AssertEqual(2, ownershipRuntime.Events.Length,
        "An unowned key_up action emitted a spurious key release.")

    resumeRuntime := RecoveryDirectHotkeyRuntime(app)
    resumeSpec := RuleSpec.Normalize(Map(
        "id", "resume-output-recovery",
        "display", Map("source", "F7", "target", "F6"),
        "from", Map("key", Map("name", "F7"), "repeat", "ignore"),
        "to", [Map("type", "key_down", "value", "F6")]))
    resumeRuntime.ApplyMappings([{Descriptor: RuleCompiler.Compile(
        resumeSpec)}])
    for sourceKey, sourceGroup in resumeRuntime.SourceGroups {
        resumeRuntime.ShouldInterceptDownGroup(sourceGroup)
        resumeRuntime.OnDownGroup(sourceGroup)
        AssertTrue(sourceGroup.Held && sourceGroup.ReleaseGroup.Held
                && resumeRuntime.Active.Count == 1
                && resumeRuntime.OutputOwners.Has("F6"),
            "The resume-recovery setup did not retain an active output.")
        AssertTrue(resumeRuntime.RecoverAfterResume()
                && !sourceGroup.Held && !sourceGroup.ReleaseGroup.Held
                && !resumeRuntime.Active.Count
                && !resumeRuntime.OutputOwners.Count,
            "Resume recovery left a source cycle or output key active.")
    }
    AssertEqual("F6 down", resumeRuntime.Events[1],
        "The resume-recovery setup did not press its output key.")
    AssertEqual("F6 up", resumeRuntime.Events[2],
        "Resume recovery did not release the interrupted output key.")

    cycleDescriptor := ownershipRules[1]
    firstCycle := ownershipRuntime.CreateActiveState(cycleDescriptor)
    secondCycle := ownershipRuntime.CreateActiveState(cycleDescriptor)
    ownershipRuntime.Active[cycleDescriptor.Id] := firstCycle
    ownershipRuntime.PressOutputKey(cycleDescriptor.Id, "F16", firstCycle)
    ownershipRuntime.Active[cycleDescriptor.Id] := secondCycle
    ownershipRuntime.PressOutputKey(cycleDescriptor.Id, "F16", secondCycle)
    ownershipRuntime.CancelActiveRule(cycleDescriptor.Id, firstCycle)
    AssertTrue(ownershipRuntime.Active.Has(cycleDescriptor.Id)
            && ownershipRuntime.Active[cycleDescriptor.Id] == secondCycle,
        "Finishing an old press cycle deleted the next active cycle.")
    AssertEqual(3, ownershipRuntime.Events.Length,
        "Releasing an old cycle released output still owned by the next cycle.")
    ownershipRuntime.CancelActiveRule(cycleDescriptor.Id, secondCycle)
    AssertEqual("F16 up", ownershipRuntime.Events[4],
        "The final press cycle did not release its output key.")

    cleanupRuntime := FlakyOutputDirectHotkeyRuntime(app)
    cleanupSpec := RuleSpec.Normalize(Map(
        "id", "output-cleanup-retry",
        "display", Map("source", "F14", "target", "F13"),
        "from", Map("key", Map("name", "F14"), "repeat", "ignore"),
        "to", [Map("type", "key_down", "value", "F13")]))
    cleanupDescriptor := RuleCompiler.Compile(cleanupSpec)
    cleanupRuntime.Rules[cleanupDescriptor.Id] := cleanupDescriptor
    cleanupRuntime.OnDown(cleanupDescriptor.Id)
    cleanupState := cleanupRuntime.Active[cleanupDescriptor.Id]
    cleanupRuntime.Failures["F13 up"] := 1
    AssertTrue(cleanupRuntime.OnUp(cleanupDescriptor.Id)
            && !cleanupRuntime.Active.Has(cleanupDescriptor.Id)
            && cleanupRuntime.OutputOwners.Has("F13")
            && cleanupState.PressedKeys.Has("F13"),
        "A failed output KeyUp discarded the ownership needed for retry.")
    AssertTrue(cleanupRuntime.RetryOutputCleanup()
            && !cleanupRuntime.OutputOwners.Count
            && !cleanupState.PressedKeys.Count,
        "A transient output KeyUp failure was not recovered.")

    multiCleanupRuntime := FlakyOutputDirectHotkeyRuntime(app)
    multiCleanupSpec := RuleSpec.Normalize(Map(
        "id", "output-cleanup-continue",
        "display", Map("source", "F12", "target", "F11 + F10"),
        "from", Map("key", Map("name", "F12"), "repeat", "ignore"),
        "to", [Map("type", "key_down", "value", "F11"),
            Map("type", "key_down", "value", "F10")]))
    multiCleanupDescriptor := RuleCompiler.Compile(multiCleanupSpec)
    multiCleanupRuntime.Rules[multiCleanupDescriptor.Id] := multiCleanupDescriptor
    multiCleanupRuntime.OnDown(multiCleanupDescriptor.Id)
    multiCleanupRuntime.Failures["F11 up"] := 1
    multiCleanupRuntime.OnUp(multiCleanupDescriptor.Id)
    AssertTrue(multiCleanupRuntime.OutputOwners.Has("F11")
            && !multiCleanupRuntime.OutputOwners.Has("F10"),
        "One failed KeyUp prevented later output keys from being released.")
    AssertTrue(multiCleanupRuntime.RetryOutputCleanup()
            && !multiCleanupRuntime.OutputOwners.Count,
        "The remaining multi-output cleanup could not be retried.")

    shutdownCleanupRuntime := FlakyOutputDirectHotkeyRuntime(app)
    shutdownCleanupRuntime.Rules[cleanupDescriptor.Id] := cleanupDescriptor
    shutdownCleanupRuntime.OnDown(cleanupDescriptor.Id)
    shutdownCleanupRuntime.Failures["F13 up"] := 2
    AssertTrue(shutdownCleanupRuntime.Shutdown()
            && !shutdownCleanupRuntime.OutputOwners.Count,
        "Shutdown cancelled output cleanup before transient KeyUp failures recovered.")

    abandonedRuntime := FlakyOutputDirectHotkeyRuntime(app)
    abandonedRuntime.Rules[cleanupDescriptor.Id] := cleanupDescriptor
    abandonedRuntime.OnDown(cleanupDescriptor.Id)
    abandonedState := abandonedRuntime.Active[cleanupDescriptor.Id]
    abandonedRuntime.Failures["F13 up"] := 4
    abandonedRuntime.OnUp(cleanupDescriptor.Id)
    Loop DirectHotkeyRuntime.MaximumOutputCleanupRetries
        abandonedRuntime.RetryOutputCleanup()
    AssertTrue(abandonedRuntime.OutputOwners.Has("F13")
            && abandonedRuntime.OutputCleanupRetryCount
                == DirectHotkeyRuntime.MaximumOutputCleanupRetries,
        "The bounded cleanup retry setup did not reach abandonment.")
    replacementState := abandonedRuntime.CreateActiveState(cleanupDescriptor)
    abandonedRuntime.Active[cleanupDescriptor.Id] := replacementState
    AssertTrue(abandonedRuntime.PressOutputKey(cleanupDescriptor.Id,
            "F13", replacementState)
            && abandonedRuntime.OutputCleanupRetryCount == 0
            && abandonedRuntime.OutputOwners["F13"].Count == 1,
        "A later press could not recover ownership abandoned by an old cycle.")
    abandonedRuntime.CancelActiveRule(cleanupDescriptor.Id, replacementState)
    AssertTrue(!abandonedRuntime.OutputOwners.Count,
        "The replacement output cycle did not release after recovery.")

    downCleanupRuntime := FlakyOutputDirectHotkeyRuntime(app)
    downCleanupSpec := RuleSpec.Normalize(Map(
        "id", "output-down-rollback",
        "display", Map("source", "F9", "target", "F8"),
        "from", Map("key", Map("name", "F9"), "repeat", "ignore"),
        "to", [Map("type", "key_down", "value", "F8")]))
    downCleanupDescriptor := RuleCompiler.Compile(downCleanupSpec)
    downCleanupRuntime.Rules[downCleanupDescriptor.Id] := downCleanupDescriptor
    downCleanupRuntime.Failures["F8 down"] := 1
    AssertTrue(!downCleanupRuntime.OnDown(downCleanupDescriptor.Id)
            && !downCleanupRuntime.Active.Has(downCleanupDescriptor.Id)
            && !downCleanupRuntime.OutputOwners.Count,
        "A failed output KeyDown left stale ownership after compensation.")

    reentrantRuntime := ReentrantReleaseDirectHotkeyRuntime(app)
    reentrantSpec := RuleSpec.Normalize(Map(
        "id", "release-reentry",
        "display", Map("source", "F15", "target", "F14"),
        "from", Map("key", Map("name", "F15"), "repeat", "ignore"),
        "to_after_key_up", [Map("type", "send", "value", "{F14}")]))
    reentrantDescriptor := RuleCompiler.Compile(reentrantSpec)
    reentrantRuntime.Rules[reentrantDescriptor.Id] := reentrantDescriptor
    reentrantRuntime.OnDown(reentrantDescriptor.Id)
    releasedState := reentrantRuntime.Active[reentrantDescriptor.Id]
    reentrantRuntime.OnUp(reentrantDescriptor.Id)
    AssertTrue(reentrantRuntime.Active.Has(reentrantDescriptor.Id)
            && reentrantRuntime.Active[reentrantDescriptor.Id]
                != releasedState,
        "Release completion discarded a new press that arrived during release actions.")
    reentrantRuntime.CancelActiveRule(reentrantDescriptor.Id,
        reentrantRuntime.Active[reentrantDescriptor.Id])

    chord := RuleSpec.Normalize(Map( "id", "modifier-chord",
        "enabled", JsonBoolean(true), "description", "test",
        "display", Map("source", "Ctrl + F24", "target", "F23",
            "scope", "global"),
        "from", Map("event", "down", "simultaneous", [
            Map("name", "Ctrl"), Map("name", "F24")]),
        "conditions", [], "to", [Map("type", "send", "value", "{F23}")]))
    chordRegistration := runtime.BuildRegistration(RuleCompiler.Compile(chord))
    AssertEqual("$^F24", chordRegistration.DownHotkey,
        "Modifier chord did not normalize to an AHK hotkey.")

    AssertThrows(() => RuleSpec.Normalize(Map(
        "id", "ambiguous-chord-source",
        "display", Map("source", "Ctrl + F24", "target", "F23"),
        "from", Map("key", Map("name", "F22"), "simultaneous", [
            Map("name", "Ctrl"), Map("name", "F24")]),
        "to_after_key_up", [Map("type", "send", "value", "{F23}")])),
        "A rule must not register a chord down event and another key-up event.")

    AssertThrows(() => RuleSpec.Normalize(Map(
        "id", "unsupported", "enabled", JsonBoolean(true),
        "description", "test", "display", Map("source", "F24",
            "target", "F23", "scope", "global"),
        "from", Map("event", "down", "key", Map("name", "F24")),
        "conditions", [], "to", [Map("type", "run", "value", "cmd")])),
        "Unsupported actions must be rejected before a rule is saved.")

    AssertThrows(() => RuleSpec.Normalize(Map(
        "id", "wheel-repeat-only",
        "display", Map("source", "WheelUp", "target", "F23"),
        "from", Map("key", Map("kind", "wheel", "name", "WheelUp"),
            "repeat", "only"),
        "to", [Map("type", "send", "value", "{F23}")])),
        "repeat=only must reject sources without a release event.")

    AssertThrows(() => RuleSpec.Normalize(Map(
        "id", "mismatched-hotkey",
        "display", Map("source", "F24", "target", "F23"),
        "from", Map("hotkey", "F24", "key", Map("name", "F23")),
        "to", [Map("type", "send", "value", "{F22}")])),
        "A hotkey and key mismatch must not silently register another key.")
    AssertThrows(() => RuleSpec.Normalize(Map(
        "id", "mismatched-key-code",
        "display", Map("source", "F24", "target", "F23"),
        "from", Map("key", Map("name", "F24", "sc", "03B")),
        "to", [Map("type", "send", "value", "{F23}")])),
        "A key name and scan code mismatch must not register another key.")
    AssertThrows(() => RuleSpec.Normalize(Map(
        "id", "self-modified-source",
        "display", Map("source", "Ctrl", "target", "F23"),
        "from", Map("key", Map("name", "Ctrl"),
            "modifiers", ["LCtrl"]),
        "to", [Map("type", "send", "value", "{F23}")])),
        "A modifier source must not require its own modifier family.")

    AssertThrows(() => RuleSpec.Normalize(Map(
        "id", "implicit-passthrough-hotkey",
        "display", Map("source", "F24", "target", "F23"),
        "from", Map("hotkey", "~F24", "key", Map("name", "F24")),
        "to", [Map("type", "send", "value", "{F23}")])),
        "A tilde hotkey must not silently lose its passthrough behavior.")
    explicitTildePassthrough := RuleSpec.Normalize(Map(
        "id", "explicit-passthrough-hotkey",
        "passthrough", JsonBoolean(true),
        "display", Map("source", "F24", "target", "F23"),
        "from", Map("hotkey", "~F24", "key", Map("name", "F24")),
        "to", [Map("type", "send", "value", "{F23}")]))
    AssertEqual("$~F24", runtime.BuildRegistration(RuleCompiler.Compile(
        explicitTildePassthrough)).DownHotkey,
        "An explicit passthrough hotkey did not preserve the source input.")

    AssertThrows(() => RuleSpec.Normalize(Map(
        "id", "invalid-key-action",
        "display", Map("source", "F24", "target", "F23"),
        "from", Map("key", Map("name", "F24")),
        "to", [Map("type", "key_down", "value", "F23} {F22")])),
        "key_down must reject multi-key Send syntax.")

    duplicateUpMappings := []
    for ruleId in ["duplicate-up-one", "duplicate-up-two"] {
        duplicateUpSpec := RuleSpec.Normalize(Map(
            "id", ruleId,
            "display", Map("source", "F19 Up", "target", "F18"),
            "from", Map("event", "up", "key", Map("name", "F19")),
            "to", [Map("type", "send", "value", "{F18}")]))
        duplicateUpMappings.Push({Descriptor: RuleCompiler.Compile(
            duplicateUpSpec)})
    }
    duplicateUpRuntime := RecordingDirectHotkeyRuntime(app)
    duplicateUpReport := duplicateUpRuntime.ApplyMappings(duplicateUpMappings)
    AssertEqual(2, duplicateUpReport.Applied,
        "Static conflict detection still rejected duplicate key-up sources.")

    groupedReleaseRuntime := SuspendedDirectHotkeyRuntime(app)
    groupedReleaseRuntime.Suspend()
    groupedReleaseMappings := []
    upOnlySpec := RuleSpec.Normalize(Map(
        "id", "grouped-up-only",
        "display", Map("source", "F16 Up", "target", "F15"),
        "from", Map("event", "up", "key", Map("name", "F16")),
        "to", [Map("type", "send", "value", "{F15}")]))
    heldSpec := RuleSpec.Normalize(Map(
        "id", "grouped-held",
        "display", Map("source", "F16", "target", "F14"),
        "from", Map("key", Map("name", "F16"), "repeat", "ignore"),
        "to_if_held_down", [Map("type", "send", "value", "{F14}")]))
    groupedReleaseMappings.Push({Descriptor: RuleCompiler.Compile(upOnlySpec)})
    groupedReleaseMappings.Push({Descriptor: RuleCompiler.Compile(heldSpec)})
    groupedReleaseRuntime.ApplyMappings(groupedReleaseMappings)
    groupedUpHotkey := ""
    for registration in groupedReleaseRuntime.Registrations {
        if registration.UpHotkey != ""
            groupedUpHotkey := registration.UpHotkey
    }
    AssertEqual("$*F16 Up", groupedUpHotkey,
        "A grouped release must retain the wildcard release hotkey.")

    canonicalModifiers := RuleSpec.Normalize(Map(
        "id", "canonical-modifiers",
        "display", Map("source", "Shift + Ctrl + F15", "target", "F14"),
        "from", Map("key", Map("name", "F15"),
            "modifiers", ["Shift", "Ctrl"]),
        "to", [Map("type", "send", "value", "{F14}")]))
    AssertEqual("^+F15", RuleCompiler.Compile(canonicalModifiers).Hotkey,
        "Equivalent modifier sets must compile to one canonical hotkey.")

    overlapRuntime := RecordingDirectHotkeyRuntime(app)
    AssertEqual(2, overlapRuntime.ApplyMappings([
        CreateRuntimeMapping("wildcard-f20", "F20", "F19", [], true),
        CreateRuntimeMapping("ctrl-f20", "F20", "F18", ["Ctrl"])]).Applied,
        "Static conflict detection still rejected modifier variants.")
    AssertEqual(2, overlapRuntime.ApplyMappings([
        CreateRuntimeMapping("ctrl-f19", "F19", "F18", ["Ctrl"]),
        CreateRuntimeMapping("left-ctrl-f19", "F19", "F17", ["LCtrl"])]).Applied,
        "Static conflict detection still rejected sided modifier variants.")
    namedAliasSpec := RuleSpec.Normalize(Map(
        "id", "named-a", "display", Map("source", "A", "target", "F18"),
        "from", Map("key", Map("name", "A")),
        "to", [Map("type", "send", "value", "{F18}")]))
    scanCodeAliasSpec := RuleSpec.Normalize(Map(
        "id", "scan-code-a", "display", Map("source", "sc01E",
            "target", "F17"),
        "from", Map("key", Map("name", "A", "sc", "01E")),
        "to", [Map("type", "send", "value", "{F17}")]))
    AssertEqual(2, overlapRuntime.ApplyMappings([
        {Descriptor: RuleCompiler.Compile(namedAliasSpec)},
        {Descriptor: RuleCompiler.Compile(scanCodeAliasSpec)}]).Applied,
        "Static conflict detection still rejected equivalent key aliases.")
    numpadHomeSpec := RuleSpec.Normalize(Map(
        "id", "numpad-home", "display", Map("source", "NumpadHome",
            "target", "F16"),
        "from", Map("key", Map("name", "NumpadHome", "vk", "24",
            "sc", "047")),
        "to", [Map("type", "send", "value", "{F16}")]))
    homeSpec := RuleSpec.Normalize(Map(
        "id", "navigation-home", "display", Map("source", "Home",
            "target", "F15"),
        "from", Map("key", Map("name", "Home", "vk", "24",
            "sc", "147")),
        "to", [Map("type", "send", "value", "{F15}")]))
    distinctPhysicalRuntime := RecordingDirectHotkeyRuntime(app)
    distinctPhysicalReport := distinctPhysicalRuntime.ApplyMappings([
        {Descriptor: RuleCompiler.Compile(numpadHomeSpec)},
        {Descriptor: RuleCompiler.Compile(homeSpec)}])
    AssertEqual(2, distinctPhysicalReport.Applied,
        "Distinct scan-code keys sharing one VK were rejected as aliases.")
    homeDescriptor := RuleCompiler.Compile(homeSpec)
    AssertTrue(distinctPhysicalRuntime.IsSourceInputEvent(homeDescriptor,
            KeyIdentity.Create("keyboard", "Home", 0x24, 0x147)),
        "A source scan code did not match its own Raw Input event.")
    AssertTrue(!distinctPhysicalRuntime.IsSourceInputEvent(homeDescriptor,
            KeyIdentity.Create("keyboard", "NumpadHome", 0x24, 0x047)),
        "A different physical key sharing the source VK was treated as the source.")

    dispatchApp := DirectRuntimeTestApp()
    dispatchRuntime := RecordingDirectHotkeyRuntime(dispatchApp)
    conditionalMappings := []
    for definition in [
            {Id: "conditional-word", Process: "WINWORD.EXE", Priority: 20},
            {Id: "conditional-notepad", Process: "notepad.exe", Priority: 0}] {
        conditionalSpec := RuleSpec.Normalize(Map(
            "id", definition.Id, "priority", definition.Priority,
            "display", Map("source", "F15", "target", definition.Id),
            "from", Map("key", Map("name", "F15")),
            "conditions", [Map("type", "application", "field", "process",
                "value", definition.Process)],
            "to", [Map("type", "send", "value", "{F14}")]))
        conditionalMappings.Push({Descriptor: RuleCompiler.Compile(
            conditionalSpec)})
    }
    conditionalReport := dispatchRuntime.ApplyMappings(conditionalMappings)
    AssertEqual(2, conditionalReport.Applied,
        "Mutually scoped rules with one source must both be applied.")
    AssertEqual(1, dispatchRuntime.SourceGroups.Count,
        "Equivalent sources were not grouped into one dispatch hotkey.")
    for sourceKey, sourceGroup in dispatchRuntime.SourceGroups {
        dispatchApp.ContextService := FixedContextService(Map("application",
            Map("process", "WINWORD.EXE")))
        AssertTrue(dispatchRuntime.ShouldInterceptDownGroup(sourceGroup),
            "The matching high-priority conditional rule was not selected.")
        dispatchRuntime.OnDownGroup(sourceGroup)
        sourceGroup.Held := false
        dispatchApp.ContextService := FixedContextService(Map("application",
            Map("process", "notepad.exe")))
        AssertTrue(dispatchRuntime.ShouldInterceptDownGroup(sourceGroup),
            "Conditional dispatch did not fall through to the next rule.")
        dispatchRuntime.OnDownGroup(sourceGroup)
        sourceGroup.Held := false
    }
    AssertEqual("conditional-word", dispatchRuntime.Events[1],
        "Conditional dispatch ignored rule priority.")
    AssertEqual("conditional-notepad", dispatchRuntime.Events[2],
        "Conditional dispatch selected the wrong fallback rule.")

    chainedRuntime := RecordingDirectHotkeyRuntime(app)
    chainedMappings := []
    for definition in [
            {Id: "chain-first", Stop: JsonBoolean(false)},
            {Id: "chain-second", Stop: JsonBoolean(true)}] {
        chainedSpec := Map( "id", definition.Id,
            "display", Map("source", "F14", "target", definition.Id),
            "from", Map("key", Map("name", "F14")),
            "to", [Map("type", "send", "value", "{F13}")])
        if !definition.Stop.Value
            chainedSpec["stop_processing"] := definition.Stop
        chainedMappings.Push({Descriptor: RuleCompiler.Compile(
            RuleSpec.Normalize(chainedSpec))})
    }
    chainedRuntime.ApplyMappings(chainedMappings)
    for sourceKey, sourceGroup in chainedRuntime.SourceGroups {
        AssertTrue(chainedRuntime.ShouldInterceptDownGroup(sourceGroup),
            "A chained source was not intercepted.")
        chainedRuntime.OnDownGroup(sourceGroup)
    }
    AssertEqual(2, chainedRuntime.Events.Length,
        "stop_processing=false did not execute the following matching rule.")

    modifierCycleRuntime := ControlledModifierStateRuntime(app)
    modifierCycleMappings := [
        CreateRuntimeMapping("plain-cycle", "F14", "F13"),
        CreateRuntimeMapping("ctrl-cycle", "F14", "F12", ["Ctrl"])]
    modifierCycleRuntime.ApplyMappings(modifierCycleMappings)
    plainCycleGroup := ""
    ctrlCycleGroup := ""
    for sourceKey, sourceGroup in modifierCycleRuntime.SourceGroups {
        if InStr(sourceGroup.Hotkey, "^")
            ctrlCycleGroup := sourceGroup
        else
            plainCycleGroup := sourceGroup
    }
    AssertTrue(IsObject(plainCycleGroup) && IsObject(ctrlCycleGroup),
        "Modifier variants of one physical key were not kept as distinct groups.")
    modifierCycleRuntime.ModifierState := 0x01
    AssertTrue(modifierCycleRuntime.ShouldInterceptDownGroup(ctrlCycleGroup),
        "The initial modified press was not intercepted.")
    modifierCycleRuntime.OnDownGroup(ctrlCycleGroup)
    modifierCycleRuntime.ModifierState := 0
    AssertTrue(modifierCycleRuntime.ShouldInterceptDownGroup(plainCycleGroup),
        "A modifier-change repeat was allowed to leak through.")
    modifierCycleRuntime.OnDownGroup(plainCycleGroup)
    AssertEqual(1, modifierCycleRuntime.Events.Length,
        "Changing modifiers while the primary key was held switched rules.")
    modifierReleaseGroup := ctrlCycleGroup.ReleaseGroup
    modifierCycleRuntime.OnReleased(modifierReleaseGroup)
    AssertTrue(!modifierReleaseGroup.Held,
        "Physical release did not reset modifier-cycle ownership.")
    AssertTrue(modifierCycleRuntime.ShouldInterceptDownGroup(plainCycleGroup),
        "A new press was still owned by the preceding modifier cycle.")
    modifierCycleRuntime.OnDownGroup(plainCycleGroup)
    AssertEqual("plain-cycle", modifierCycleRuntime.Events[2],
        "The post-release unmodified rule did not re-arm.")

    heldApplyRuntime := HeldSourceDirectHotkeyRuntime(app)
    heldApplyRuntime.ApplyMappings([
        CreateRuntimeMapping("held-during-apply", "F12", "F11")])
    for sourceKey, sourceGroup in heldApplyRuntime.SourceGroups {
        AssertTrue(sourceGroup.ReleaseGroup.SuppressUntilRelease,
            "A physically held source was armed as a new cycle during apply.")
        heldApplyRuntime.SourceDown := false
        AssertTrue(heldApplyRuntime.ShouldInterceptDownGroup(sourceGroup),
            "A held-during-apply repeat was allowed through.")
        heldApplyRuntime.OnDownGroup(sourceGroup)
        AssertEqual(0, heldApplyRuntime.Events.Length,
            "A held source executed a newly applied rule before release.")
        AssertTrue(heldApplyRuntime.ShouldInterceptReleased(
                sourceGroup.ReleaseGroup),
            "The held-during-apply release was not intercepted for re-arming.")
        heldApplyRuntime.OnReleased(sourceGroup.ReleaseGroup)
        heldApplyRuntime.ShouldInterceptDownGroup(sourceGroup)
        heldApplyRuntime.OnDownGroup(sourceGroup)
        AssertEqual("held-during-apply", heldApplyRuntime.Events[1],
            "The applied rule did not arm after a real release.")
    }

    heldUpRuntime := HeldSourceDirectHotkeyRuntime(app)
    heldUpSpec := RuleSpec.Normalize(Map(
        "id", "held-up-during-apply",
        "display", Map("source", "F11 Up", "target", "F10"),
        "from", Map("key", Map("name", "F11"), "event", "up",
            "repeat", "ignore"),
        "to", [Map("type", "send", "value", "{F10}")]))
    heldUpRuntime.ApplyMappings([{Descriptor: RuleCompiler.Compile(
        heldUpSpec)}])
    for releaseKey, releaseGroup in heldUpRuntime.ReleaseGroups {
        AssertTrue(heldUpRuntime.ShouldInterceptReleased(releaseGroup),
            "An up-only held-during-apply cycle could not be cleared.")
        heldUpRuntime.OnReleased(releaseGroup)
        AssertEqual(0, heldUpRuntime.Events.Length,
            "A newly applied up-only rule fired for a pre-existing press.")
        heldUpRuntime.SourceDown := false
        AssertTrue(heldUpRuntime.ShouldInterceptReleased(releaseGroup),
            "The up-only rule did not arm after the old cycle cleared.")
        heldUpRuntime.OnReleased(releaseGroup)
        AssertEqual("held-up-during-apply", heldUpRuntime.Events[1],
            "The up-only rule did not fire on the next real release.")
    }

    unmatchedModifierRuntime := ControlledModifierStateRuntime(app)
    unmatchedModifierRuntime.ApplyMappings([
        CreateRuntimeMapping("ctrl-only-cycle", "F13", "F12", ["Ctrl"])])
    for sourceKey, sourceGroup in unmatchedModifierRuntime.SourceGroups {
        unmatchedModifierRuntime.ModifierState := 0x01
        unmatchedModifierRuntime.ShouldInterceptDownGroup(sourceGroup)
        unmatchedModifierRuntime.OnDownGroup(sourceGroup)
        unmatchedModifierRuntime.ModifierState := 0
        AssertTrue(unmatchedModifierRuntime
                .ShouldInterceptBlockedCycleRepeat(sourceGroup.ReleaseGroup),
            "No wildcard blocker covered an unmatched modifier state.")
    }

    repeatRuntime := RecordingDirectHotkeyRuntime(app)
    repeatSpec := RuleSpec.Normalize(Map( "id", "repeat-once",
        "display", Map("source", "F13", "target", "F12"),
        "from", Map("key", Map("name", "F13")),
        "to", [Map("type", "send", "value", "{F12}",
            "repeat", "once")]))
    repeatRuntime.ApplyMappings([{Descriptor: RuleCompiler.Compile(
        repeatSpec)}])
    for sourceKey, sourceGroup in repeatRuntime.SourceGroups {
        repeatRuntime.ShouldInterceptDownGroup(sourceGroup)
        repeatRuntime.OnDownGroup(sourceGroup)
        repeatRuntime.ShouldInterceptDownGroup(sourceGroup)
        repeatRuntime.OnDownGroup(sourceGroup)
        sourceGroup.Held := false
        repeatRuntime.ShouldInterceptDownGroup(sourceGroup)
        repeatRuntime.OnDownGroup(sourceGroup)
    }
    AssertEqual(2, repeatRuntime.Events.Length,
        "repeat=once did not suppress auto-repeat within one press cycle.")

    ignoredRepeatRuntime := RecordingDirectHotkeyRuntime(app)
    ignoredRepeatSpec := RuleSpec.Normalize(Map(
        "id", "repeat-ignore",
        "display", Map("source", "F11", "target", "F10"),
        "from", Map("key", Map("name", "F11"), "repeat", "ignore"),
        "to", [Map("type", "send", "value", "{F10}")]))
    ignoredRepeatRuntime.ApplyMappings([{Descriptor: RuleCompiler.Compile(
        ignoredRepeatSpec)}])
    for sourceKey, sourceGroup in ignoredRepeatRuntime.SourceGroups {
        AssertTrue(ignoredRepeatRuntime.ShouldInterceptDownGroup(sourceGroup),
            "The initial repeat=ignore press was not intercepted.")
        ignoredRepeatRuntime.OnDownGroup(sourceGroup)
        AssertTrue(ignoredRepeatRuntime.ShouldInterceptDownGroup(sourceGroup),
            "A repeat=ignore auto-repeat leaked through to the application.")
        ignoredRepeatRuntime.OnDownGroup(sourceGroup)
        AssertEqual(1, ignoredRepeatRuntime.Events.Length,
            "repeat=ignore executed actions during auto-repeat.")
        ignoredRepeatRuntime.OnUp("repeat-ignore")
        sourceGroup.Held := false
        ignoredRepeatRuntime.ShouldInterceptDownGroup(sourceGroup)
        ignoredRepeatRuntime.OnDownGroup(sourceGroup)
    }
    AssertEqual(2, ignoredRepeatRuntime.Events.Length,
        "repeat=ignore did not re-arm after physical release.")

    failedIgnoreRuntime := FailingGroupedDirectHotkeyRuntime(app)
    failedIgnoreSpec := RuleSpec.Normalize(Map(
        "id", "repeat-ignore-failed-action",
        "display", Map("source", "F7", "target", "F6"),
        "from", Map("key", Map("name", "F7"), "repeat", "ignore"),
        "to", [Map("type", "send", "value", "{F6}")]))
    failedIgnoreRuntime.ApplyMappings([{Descriptor: RuleCompiler.Compile(
        failedIgnoreSpec)}])
    failedIgnoreRuntime.FailField := "to"
    for sourceKey, sourceGroup in failedIgnoreRuntime.SourceGroups {
        AssertTrue(failedIgnoreRuntime.ShouldInterceptDownGroup(sourceGroup),
            "The initial failing repeat=ignore press was not intercepted.")
        failedIgnoreRuntime.OnDownGroup(sourceGroup)
        AssertTrue(!failedIgnoreRuntime.Active.Has(
                "repeat-ignore-failed-action")
                && sourceGroup.RepeatIgnoreRules.Has(
                    "repeat-ignore-failed-action"),
            "A failed action discarded the press-cycle repeat policy.")
        AssertTrue(failedIgnoreRuntime.ShouldInterceptDownGroup(sourceGroup),
            "Auto-repeat leaked after a repeat=ignore action failed.")
        failedIgnoreRuntime.OnDownGroup(sourceGroup)
    }

    wheelRuntime := RecordingDirectHotkeyRuntime(app)
    wheelSpec := RuleSpec.Normalize(Map(
        "id", "repeat-ignore-wheel",
        "display", Map("source", "WheelUp", "target", "WheelLeft"),
        "from", Map("key", Map("kind", "wheel", "name", "WheelUp"),
            "repeat", "ignore"),
        "to", [Map("type", "send", "value", "{WheelLeft}")]))
    wheelRuntime.ApplyMappings([{Descriptor: RuleCompiler.Compile(
        wheelSpec)}])
    for sourceKey, sourceGroup in wheelRuntime.SourceGroups {
        Loop 2 {
            AssertTrue(wheelRuntime.ShouldInterceptDownGroup(sourceGroup),
                "A later wheel event was mistaken for key auto-repeat.")
            wheelRuntime.OnDownGroup(sourceGroup)
        }
        AssertTrue(!sourceGroup.Held,
            "A wheel source remained held without a release event.")
    }
    AssertEqual(2, wheelRuntime.Events.Length,
        "A repeat=ignore wheel mapping stopped after its first event.")

    timerRuntime := TimerStateDirectHotkeyRuntime(app)
    timerSpec := RuleSpec.Normalize(Map(
        "id", "release-timer-race",
        "display", Map("source", "F12", "target", "F11"),
        "from", Map("key", Map("name", "F12"), "repeat", "ignore"),
        "timing", Map("held_threshold_ms", 60000),
        "to_if_alone", [Map("type", "send", "value", "{F11}")],
        "to_if_held_down", [Map("type", "send", "value", "{F10}")]))
    timerDescriptor := RuleCompiler.Compile(timerSpec)
    timerRuntime.Rules[timerDescriptor.Id] := timerDescriptor
    timerRuntime.OnDown(timerDescriptor.Id)
    timerRuntime.OnUp(timerDescriptor.Id)
    AssertTrue(timerRuntime.TimerWasStopped,
        "Release actions ran while the held timer could still fire.")

    elapsedHeldRuntime := ElapsedHeldDirectHotkeyRuntime(app)
    elapsedHeldSpec := RuleSpec.Normalize(Map(
        "id", "elapsed-held-threshold",
        "display", Map("source", "F10", "target", "F9"),
        "from", Map("key", Map("name", "F10"), "repeat", "ignore"),
        "timing", Map("held_threshold_ms", 200),
        "to_if_held_down", [Map("type", "send", "value", "{F9}")]))
    elapsedHeldDescriptor := RuleCompiler.Compile(elapsedHeldSpec)
    elapsedHeldRuntime.Rules[elapsedHeldDescriptor.Id] :=
        elapsedHeldDescriptor
    elapsedHeldRuntime.OnDown(elapsedHeldDescriptor.Id)
    AssertTrue(elapsedHeldRuntime.Active[elapsedHeldDescriptor.Id].HeldFired,
        "Held timing started after immediate actions instead of source down.")
    AssertEqual(1, elapsedHeldRuntime.Events.Length,
        "An already elapsed held threshold did not run output immediately.")
    elapsedHeldRuntime.OnUp(elapsedHeldDescriptor.Id)
    AssertEqual(1, elapsedHeldRuntime.Events.Length,
        "Release duplicated an already recognized held action.")

    releaseFallbackRuntime := ControlledTickDirectHotkeyRuntime(app)
    releaseFallbackSpec := RuleSpec.Normalize(Map(
        "id", "release-held-fallback",
        "display", Map("source", "F8", "target", "F7"),
        "from", Map("key", Map("name", "F8"), "repeat", "ignore"),
        "timing", Map("held_threshold_ms", 200),
        "to_if_alone", [Map("type", "send", "value", "{F7}")],
        "to_if_held_down", [Map("type", "send", "value", "{F6}")]))
    releaseFallbackDescriptor := RuleCompiler.Compile(releaseFallbackSpec)
    releaseFallbackRuntime.Rules[releaseFallbackDescriptor.Id] :=
        releaseFallbackDescriptor
    releaseFallbackRuntime.Tick := 1000
    releaseFallbackRuntime.OnDown(releaseFallbackDescriptor.Id)
    releaseFallbackState := releaseFallbackRuntime.Active[
        releaseFallbackDescriptor.Id]
    releaseFallbackRuntime.Tick := 1200
    releaseFallbackRuntime.OnUp(releaseFallbackDescriptor.Id)
    AssertTrue(releaseFallbackState.HeldFired,
        "A delayed held timer lost a long press when release arrived first.")
    AssertEqual(1, releaseFallbackRuntime.Events.Length,
        "Release-time held recovery also executed the alone action.")

    aloneRuntime := RecordingDirectHotkeyRuntime(app)
    aloneSpec := RuleSpec.Normalize(Map(
        "id", "alone-other-input",
        "display", Map("source", "F5", "target", "F4"),
        "from", Map("key", Map("name", "F5"), "repeat", "ignore"),
        "to_if_alone", [Map("type", "send", "value", "{F4}")]))
    aloneDescriptor := RuleCompiler.Compile(aloneSpec)
    aloneRuntime.Rules[aloneDescriptor.Id] := aloneDescriptor
    aloneRuntime.OnDown(aloneDescriptor.Id)
    aloneState := aloneRuntime.Active[aloneDescriptor.Id]
    aloneRuntime.ObserveInputEvent(InputEvent.Create(KeyIdentity.Create(
        "keyboard", "F5", 0x74, 0x03F), "down", false, false,
        "raw-input"))
    AssertTrue(!aloneState.AloneCancelled,
        "The source Raw Input event cancelled its own alone action.")
    aloneRuntime.ObserveInputEvent(InputEvent.Create(KeyIdentity.Create(
        "keyboard", "F3", 0x72, 0x03D), "down", false, false,
        "raw-input"))
    aloneRuntime.OnUp(aloneDescriptor.Id)
    AssertTrue(aloneState.AloneCancelled && !aloneRuntime.Events.Length,
        "to_if_alone still ran after another physical key was pressed.")

    runtime.Shutdown()

    FileAppend("PASS direct-hotkey-runtime`n", "*")
} catch as testError {
    FileAppend(testError.Message "`n" testError.Stack "`n", "**")
    ExitApp(1)
}
ExitApp(0)

FindManagedMappingBySource(mappings, expectedKeyName,
        expectedModifiers := []) {
    for mapping in mappings {
        if mapping.Mode != "managed" || !mapping.Spec.Has("from")
            continue
        from := mapping.Spec["from"]
        if !from.Has("key") || from["key"]["name"] != expectedKeyName
            continue
        modifiers := from.Has("modifiers") ? from["modifiers"] : []
        if modifiers.Length != expectedModifiers.Length
            continue
        matched := true
        for index, modifier in expectedModifiers {
            if modifiers[index] == modifier
                continue
            matched := false
            break
        }
        if matched
            return mapping
    }
    throw Error("Missing managed mapping source: " expectedKeyName)
}

CreateRuntimeMapping(id, source, target, modifiers := [], wildcard := false) {
    from := Map("key", Map("name", source))
    if modifiers.Length
        from["modifiers"] := modifiers
    if wildcard
        from["optional_modifiers"] := ["any"]
    spec := RuleSpec.Normalize(Map( "id", id,
        "display", Map("source", source, "target", target),
        "from", from,
        "to", [Map("type", "send", "value", "{" target "}")]))
    return {Descriptor: RuleCompiler.Compile(spec)}
}

AssertTrue(value, message) {
    if !value
        throw Error(message)
}

AssertEqual(expected, actual, message) {
    if expected != actual
        throw Error(message " Expected '" expected "', got '" actual "'.")
}

AssertThrows(callback, message) {
    try callback.Call()
    catch
        return true
    throw Error(message)
}

class SuspendFailureRuntime extends DirectHotkeyRuntime {
    __New(app) {
        super.__New(app)
        this.DisableCalls := 0
        this.EnableCalls := 0
    }

    DisableRegistration(registration) {
        this.DisableCalls++
        if this.DisableCalls == 2
            throw Error("planned suspend failure")
        registration.Disabled := true
        return true
    }

    EnableRegistration(registration) {
        this.EnableCalls++
        registration.Disabled := false
        return true
    }
}

class DirectRuntimeTestApp {
    __New() {
        this.ContextService := DirectContextService()
        this.Events := []
    }

    TraceEvent(category, eventName, fields := "") {
        this.Events.Push({Category: category, Event: eventName, Fields: fields})
        return true
    }
}

class CompositeBranchDirectProbe {
    __New() {
        this.ApplyCount := 0
    }

    ApplyMappings(mappings) {
        this.ApplyCount++
        return {Applied: mappings.Length, Registrations: mappings.Length,
            Issues: []}
    }

    BuildRegistration(*) => {DownHotkey: "", UpHotkey: ""}
    HotkeyVariantsOverlap(*) => false
    GetCapabilities() => Map()
}

class CompositeBranchScriptProbe {
    __New() {
        this.ApplyCount := 0
    }

    ApplyMappings(mappings) {
        this.ApplyCount++
        return {Applied: mappings.Length, Workers: mappings.Length}
    }
}

class OutputDispatchRecordingRuntime extends DirectHotkeyRuntime {
    __New(app) {
        super.__New(app)
        this.Dispatches := []
        this.FailDispatch := false
    }

    DispatchKeySequence(sequence) {
        this.Dispatches.Push({Sequence: String(sequence),
            Critical: A_IsCritical, Delay: A_KeyDelay,
            Duration: A_KeyDuration})
        if this.FailDispatch
            throw Error("planned dispatch failure")
        return true
    }
}

class FixedContextService {
    __New(context) {
        this.Context := context
    }

    Build(*) => RuleSpec.Clone(this.Context)
}

class FailingDirectHotkeyRuntime extends DirectHotkeyRuntime {
    __New(app) {
        super.__New(app)
        this.FailField := ""
    }

    ExecuteActions(actions, descriptor, fieldName, isRepeat := false,
            activeState := "", requireActive := false) {
        if fieldName == this.FailField
            throw Error("planned failure")
        return true
    }
}

class SuspendedDirectHotkeyRuntime extends DirectHotkeyRuntime {
    __New(app) {
        super.__New(app)
        this.EnableCalls := 0
    }

    EnableRegistration(registration) {
        this.EnableCalls++
        return true
    }
}

class FailingGroupedDirectHotkeyRuntime extends FailingDirectHotkeyRuntime {
    EnableRegistration(*) => true
    DisableRegistration(*) => true
}

class OwnershipDirectHotkeyRuntime extends DirectHotkeyRuntime {
    __New(app) {
        super.__New(app)
        this.Events := []
    }

    SendKeyEvent(keyName, phase) {
        this.Events.Push(String(keyName) " " phase)
        return true
    }
}

class FlakyOutputDirectHotkeyRuntime extends OwnershipDirectHotkeyRuntime {
    __New(app) {
        super.__New(app)
        this.Failures := Map()
    }

    SendKeyEvent(keyName, phase) {
        signature := String(keyName) " " phase
        this.Events.Push(signature)
        remaining := this.Failures.Get(signature, 0)
        if remaining > 0 {
            this.Failures[signature] := remaining - 1
            throw Error("planned output failure")
        }
        return true
    }
}

class RecoveryDirectHotkeyRuntime extends OwnershipDirectHotkeyRuntime {
    EnableRegistration(*) => true
    DisableRegistration(*) => true
}

class DeferredPassthroughRuntime extends DirectHotkeyRuntime {
    __New(app) {
        super.__New(app)
        this.OriginalInputs := []
    }

    ExecuteActions(*) => true

    SendOriginalInput(descriptor, state := "") {
        this.OriginalInputs.Push(descriptor.Id)
        return true
    }
}

class RecordingDirectHotkeyRuntime extends DirectHotkeyRuntime {
    __New(app) {
        super.__New(app)
        this.Events := []
    }

    EnableRegistration(*) => true
    DisableRegistration(*) => true

    ExecuteActions(actions, descriptor, fieldName, isRepeat := false,
            activeState := "", requireActive := false) {
        for action in actions {
            if isRepeat && action.Get("repeat", "inherit") == "once"
                continue
            this.Events.Push(descriptor.Id)
        }
        return true
    }
}

class LongPressStressDirectHotkeyRuntime extends RecordingDirectHotkeyRuntime {
    __New(app) {
        super.__New(app)
        this.OriginalInputs := []
    }

    SendOriginalInput(descriptor, state := "") {
        this.OriginalInputs.Push(descriptor.Id)
        return true
    }
}

class TimerStateDirectHotkeyRuntime extends RecordingDirectHotkeyRuntime {
    __New(app) {
        super.__New(app)
        this.TimerWasStopped := false
    }

    ExecuteActions(actions, descriptor, fieldName, isRepeat := false,
            activeState := "", requireActive := false) {
        if fieldName == "to_if_alone" && IsObject(activeState)
            this.TimerWasStopped := activeState.HeldTimer == ""
        return super.ExecuteActions(actions, descriptor, fieldName, isRepeat,
            activeState, requireActive)
    }
}

class ReentrantReleaseDirectHotkeyRuntime extends RecordingDirectHotkeyRuntime {
    __New(app) {
        super.__New(app)
        this.Reentered := false
    }

    ExecuteActions(actions, descriptor, fieldName, isRepeat := false,
            activeState := "", requireActive := false) {
        if fieldName == "to_after_key_up" && !this.Reentered {
            this.Reentered := true
            this.HandleDown(descriptor.Id, false, true)
        }
        return super.ExecuteActions(actions, descriptor, fieldName, isRepeat,
            activeState, requireActive)
    }
}

class ElapsedHeldDirectHotkeyRuntime extends RecordingDirectHotkeyRuntime {
    __New(app) {
        super.__New(app)
        this.TickCalls := 0
    }

    GetMonotonicTick() {
        this.TickCalls++
        return this.TickCalls == 1 ? 1000 : 1300
    }
}

class ControlledTickDirectHotkeyRuntime extends RecordingDirectHotkeyRuntime {
    __New(app) {
        super.__New(app)
        this.Tick := 0
    }

    GetMonotonicTick() => this.Tick
}

class ControlledModifierStateRuntime extends RecordingDirectHotkeyRuntime {
    __New(app) {
        super.__New(app)
        this.ModifierState := 0
    }

    GetPhysicalModifierState() => this.ModifierState
}

class HeldSourceDirectHotkeyRuntime extends RecordingDirectHotkeyRuntime {
    __New(app) {
        super.__New(app)
        this.SourceDown := true
    }

    IsPhysicalSourceDown(*) => this.SourceDown
}
