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
#Include ..\..\src\Core\DirectHotkeyRuntime.ahk
#Include ..\..\src\Core\MappingCodeRepository.ahk
#Include ..\..\src\Core\MappingHistoryService.ahk
#Include ..\..\src\Platform\Win32.ahk
#Include ..\..\src\UI\CleanupCollector.ahk
#Include ..\..\app\KeyMouseRemapperAssistantApp.ahk

ExitApp(RunMappingHistoryIntegrationTests() ? 0 : 1)

RunMappingHistoryIntegrationTests() {
    projectRoot := A_ScriptDir "\..\.."
    sourceScript := projectRoot "\键鼠重映射小助手.ahk"
    testScript := projectRoot "\.mapping-history-integration-"
        . DllCall("kernel32\GetCurrentProcessId", "UInt") "-" A_TickCount "-"
        . Format("{:08X}", Random(0, 0xFFFFFFFF)) ".ahk"
    try {
        FileCopy(sourceScript, testScript)
        app := MappingHistoryIntegrationApp(testScript)
        app.MappingCount := 99
        app.RuntimeReport := {Applied: 2}
        MappingHistoryIntegrationAssert(InStr(app.GetSummaryText(), "2")
                && !InStr(app.GetSummaryText(), "99"),
            "The status summary reported total rules as active rules.")
        app.SettingsService := {LastLoadWarning:
            "无法读取设置文件，已使用默认设置：access denied"}
        MappingHistoryIntegrationAssert(InStr(
                app.GetSettingsLoadWarningText(), "access denied")
                && InStr(app.GetSettingsLoadWarningText(), "默认设置"),
            "The settings-load warning could not be prepared for the main status.")
        beforeBody := app.Repository.ReadRegionBody()
        repositorySnapshot := app.Repository.ReadSnapshot()
        scriptRule := ""
        for candidateMapping in repositorySnapshot.Mappings {
            if candidateMapping.Mode == "script" {
                scriptRule := candidateMapping
                break
            }
        }
        MappingHistoryIntegrationAssert(IsObject(scriptRule),
            "The integration fixture does not contain a script rule.")
        if EnvGet("DEFERRED_SCRIPT_SAVE_ONLY") == "1" {
            deferredScriptBlock := RegExReplace(scriptRule.EditorText,
                "m)^; @名称=.*$", "; @名称=后台脚本保存回归", , 1)
            applyCountBeforeDeferredSave := app.Runtime.ApplyCount
            deferredResult := app.UpdateMappingEditorText(scriptRule.Id,
                deferredScriptBlock, "script")
            SetTimer(app.PendingScriptApplyTimer, 0)
            MappingHistoryIntegrationAssert(deferredResult.Ok
                    && app.Runtime.ApplyCount == applyCountBeforeDeferredSave
                    && app.Window.LastPreviousId == scriptRule.Id
                    && app.Window.LastUpdatedId == "后台脚本保存回归"
                    && app.Repository.GetById("后台脚本保存回归").Id
                        == "后台脚本保存回归"
                    && IsObject(app.PendingScriptApply)
                    && app.Window.LastStatus == "已保存，正在后台应用…"
                    && app.PendingScriptApply.ProgressText
                        == app.Window.LastStatus
                    && app.PendingScriptApply.StatusRevision
                        == app.Window.GetStatusRevision(),
                "A script edit did not persist and update its row before runtime apply.")
            MappingHistoryIntegrationAssert(app.ApplyPendingScriptMappings()
                    && app.Runtime.ApplyCount
                        == applyCountBeforeDeferredSave + 1
                    && !IsObject(app.PendingScriptApply)
                    && app.Window.LastStatus == "受托管脚本已应用。",
                "The deferred script edit was not applied in the background.")
            staleStatusBlock := StrReplace(deferredScriptBlock,
                "; @来源按键=", "; @来源按键=后台状态隔离-", true, , 1)
            staleStatusResult := app.UpdateMappingEditorText(
                "后台脚本保存回归", staleStatusBlock, "script")
            SetTimer(app.PendingScriptApplyTimer, 0)
            app.Window.SetStatus("newer user-visible status")
            MappingHistoryIntegrationAssert(staleStatusResult.Ok
                    && app.ApplyPendingScriptMappings()
                    && app.Window.LastStatus == "newer user-visible status",
                "A completed background apply overwrote a newer window status.")
            repeatedStatusBlock := StrReplace(staleStatusBlock,
                "后台状态隔离-", "重复后台状态-", true, , 1)
            repeatedStatusResult := app.UpdateMappingEditorText(
                "后台脚本保存回归", repeatedStatusBlock, "script")
            SetTimer(app.PendingScriptApplyTimer, 0)
            repeatedProgress := app.Window.LastStatus
            app.Window.SetStatus(repeatedProgress)
            MappingHistoryIntegrationAssert(repeatedStatusResult.Ok
                    && app.ApplyPendingScriptMappings()
                    && app.Window.LastStatus == repeatedProgress,
                "An older background apply completed a newer identical progress status.")
            failedScriptBlock := StrReplace(deferredScriptBlock,
                "; @来源按键=", "; @来源按键=后台失败-", true, , 1)
            app.Runtime.FailNextApply := true
            failedResult := app.UpdateMappingEditorText("后台脚本保存回归",
                failedScriptBlock, "script")
            SetTimer(app.PendingScriptApplyTimer, 0)
            MappingHistoryIntegrationAssert(failedResult.Ok
                    && !app.ApplyPendingScriptMappings()
                    && InStr(app.Repository.GetById("后台脚本保存回归")
                        .Source, "后台失败-")
                    && app.Window.LastStatusIsError
                    && InStr(app.Window.LastStatus, "已保存"),
                "A failed background apply discarded the saved script or hid its failure.")
            FileAppend("PASS deferred script save`n", "*")
            return true
        }
        editedScriptBlock := RegExReplace(scriptRule.EditorText,
            "m)^; @名称=.*$", "; @名称=完整脚本块保存回归", , 1)
        editedScriptMapping := app.Repository.ReplaceEditorText(
            scriptRule.Id, editedScriptBlock, "script")
        MappingHistoryIntegrationAssert(editedScriptMapping.Mode == "script"
                && editedScriptMapping.Id == "完整脚本块保存回归"
                && InStr(editedScriptMapping.EditorText,
                    "; @类型=受托管独立脚本")
                && InStr(editedScriptMapping.EditorText,
                    "; @名称=完整脚本块保存回归")
                && InStr(editedScriptMapping.EditorText,
                    "; @script-code-begin")
                && !InStr(editedScriptMapping.EditorText,
                    "@script-spec-"),
            "Saving a complete script block did not preserve its envelope.")
        app.Repository.WriteRegionBody(beforeBody)
        cachedParseCount := app.Repository.ParseCalls
        app.Repository.ReadSnapshot()
        MappingHistoryIntegrationAssert(
            app.Repository.ParseCalls == cachedParseCount,
            "An unchanged script reparsed the entire mapping region.")
        isolatedSnapshot := app.Repository.ReadSnapshot()
        isolatedSnapshot.Mappings[1].Spec["id"] := "mutated-cache-copy"
        MappingHistoryIntegrationAssert(app.Repository.ReadSnapshot()
                .Mappings[1].Spec["id"] != "mutated-cache-copy",
            "A caller mutation leaked into the cached mapping snapshot.")
        externalSourceText := app.Repository.ReadScriptText()
        externalOutput := FileOpen(testScript, "a", "UTF-8-RAW")
        try externalOutput.Write("`r`n; external cache invalidation probe`r`n")
        finally externalOutput.Close()
        try {
            externalParseCount := app.Repository.ParseCalls
            app.Repository.ReadSnapshot()
            MappingHistoryIntegrationAssert(app.Repository.ParseCalls
                    == externalParseCount + 1,
                "An external script edit did not invalidate the mapping cache.")
        } finally {
            restoreOutput := FileOpen(testScript, "w", "UTF-8-RAW")
            try restoreOutput.Write(externalSourceText)
            finally restoreOutput.Close()
        }
        encodedName := RuleCompiler.EncodeMetadataValue(
            repositorySnapshot.Mappings[1].Id)
        missingNameBlock := StrReplace(repositorySnapshot.Mappings[1].Block,
            "; @名称=" encodedName "`r`n", "", true, , 1)
        if missingNameBlock == repositorySnapshot.Mappings[1].Block
            missingNameBlock := StrReplace(repositorySnapshot.Mappings[1].Block,
                "; @名称=" encodedName "`n", "", true,
                , 1)
        MappingHistoryIntegrationAssertThrows(() => app.Repository
            .ParseMappings(missingNameBlock),
            "A managed block without @名称 metadata was accepted.")
        mismatchedSchemaBlock := StrReplace(
            repositorySnapshot.Mappings[1].Block, "; @类型=规则块",
            "; @schema=1`n; @类型=规则块", true, , 1)
        schemaMapping := app.Repository.ParseMappings(
            mismatchedSchemaBlock)[1]
        MappingHistoryIntegrationAssert(
            repositorySnapshot.Mappings[1].Id == schemaMapping.Id,
            "Harmless schema metadata changed or invalidated the rule.")
        MappingHistoryIntegrationAssertThrows(() => app.Repository
            .ParseMappings("MsgBox(123)"),
            "Executable text was accepted inside the comment-only region.")
        escapedCode := "; " . MappingHistoryRepeatText("\",
            ScriptRuleSpec.MaximumCodeCharacters - 2)
        escapedSpec := ScriptRuleSpec.FromCode("escaped-size-boundary",
            escapedCode)
        escapedBlock := ScriptRuleCompiler.BuildBlock(escapedSpec)
        MappingHistoryIntegrationAssert(
                StrLen(escapedBlock) > ScriptRuleSpec.MaximumCodeCharacters
                && StrLen(escapedBlock)
                    <= MappingCodeRepository.MaximumBlockCharacters,
            "The script block limit does not cover readable source framing.")
        escapedMappings := app.Repository.ParseMappings(escapedBlock)
        MappingHistoryIntegrationAssert(escapedMappings.Length == 1
                && escapedMappings[1].Spec["code"] == escapedCode,
            "An escaped script at the source-size boundary did not round-trip.")
        expandedMappings := repositorySnapshot.Mappings.Clone()
        expandedMappings.Push(repositorySnapshot.Mappings[1])
        previousMaximumMappings := MappingCodeRepository.MaximumMappings
        MappingCodeRepository.MaximumMappings := repositorySnapshot
            .Mappings.Length
        rewriteRejected := false
        try app.Repository.Rewrite(expandedMappings, repositorySnapshot)
        catch
            rewriteRejected := true
        finally MappingCodeRepository.MaximumMappings := previousMaximumMappings
        MappingHistoryIntegrationAssert(rewriteRejected
                && app.Repository.ReadRegionBody() == beforeBody,
            "Rewrite published an over-limit region before validation.")
        executableMappings := repositorySnapshot.Mappings.Clone()
        executableMapping := app.Repository.CloneMapping(executableMappings[1])
        executableMapping.Block := "MsgBox(123)"
        executableMappings[1] := executableMapping
        MappingHistoryIntegrationAssertThrows(() => app.Repository.Rewrite(
            executableMappings, repositorySnapshot, true),
            "Trusted assembly accepted executable text in a mapping block.")
        MappingHistoryIntegrationAssert(
            app.Repository.ReadRegionBody() == beforeBody,
            "Rejected executable text changed the mapping region.")
        MappingHistoryIntegrationAssert(!app.RunMappingMutation(() => false)
                && app.Runtime.ApplyCount == 0
                && app.MappingHistory.GetUndoCount() == 0,
            "An unchanged mutation reloaded hotkeys or created history.")
        unchangedFailureObserved := false
        try app.RunMappingMutation(PlannedMutationFailure)
        catch
            unchangedFailureObserved := true
        MappingHistoryIntegrationAssert(unchangedFailureObserved
                && app.Runtime.ApplyCount == 0
                && app.Repository.ReadRegionBody() == beforeBody,
            "A pre-write mutation failure unnecessarily reloaded hotkeys.")
        app.Runtime.FailNextApply := true
        emptyRollbackFailed := false
        try app.RunMappingMutation(
            () => app.Repository.WriteRegionBody(""), {Kind: "delete"})
        catch
            emptyRollbackFailed := true
        MappingHistoryIntegrationAssert(emptyRollbackFailed
                && app.Repository.ReadRegionBody() == beforeBody
                && app.Runtime.ApplyCount == 2
                && app.MappingHistory.GetUndoCount() == 0,
            "A failed last-rule deletion did not restore an empty region body.")

        editableMapping := app.Repository.Load()[1]
        renamedMappingId := "编辑保存后立即同步回归"
        renamedEditorText := RegExReplace(editableMapping.EditorText,
            "m)^; @名称=.*$", "; @名称=" renamedMappingId, , 1)
        applyCountBeforeRename := app.Runtime.ApplyCount
        updateCountBeforeRename := app.Window.UpdateCount
        renameResult := app.UpdateMappingEditorText(editableMapping.Id,
            renamedEditorText, editableMapping.Mode)
        reopenedMapping := app.Repository.GetById(renamedMappingId)
        MappingHistoryIntegrationAssert(renameResult.Ok
                && renameResult.Mapping.Id == renamedMappingId
                && reopenedMapping.Id == renamedMappingId
                && app.Runtime.ApplyCount == applyCountBeforeRename + 1
                && app.Window.UpdateCount == updateCountBeforeRename + 1
                && app.Window.LastPreviousId == editableMapping.Id
                && app.Window.LastUpdatedId == renamedMappingId,
            "Renaming an edited rule did not hot-apply, update its existing row, or remain reopenable.")
        MappingHistoryIntegrationAssert(app.UndoMappingChange()
                && app.Repository.ReadRegionBody() == beforeBody,
            "The edited-name synchronization probe could not restore its fixture.")

        changedMapping := app.RunMappingMutation(ObjBindMethod(
            app.Repository, "ToggleEnabled",
                "F1 长按录屏"),
            {Kind: "toggle", Id: "F1 长按录屏"})
        afterBody := app.Repository.ReadRegionBody()
        MappingHistoryIntegrationAssert(changedMapping.Id
                == "F1 长按录屏"
                && beforeBody != afterBody
                && app.MappingHistory.GetUndoCount() == 1,
            "A real repository mutation did not create one history entry.")

        MappingHistoryIntegrationAssert(app.UndoMappingChange()
                && app.Repository.ReadRegionBody() == beforeBody
                && app.MappingHistory.GetRedoCount() == 1
                && app.Window.PreferredId
                    == "F1 长按录屏",
            "Undo did not restore the real mapping region and selection.")
        MappingHistoryIntegrationAssert(app.RedoMappingChange()
                && app.Repository.ReadRegionBody() == afterBody
                && app.MappingHistory.GetRedoCount() == 0,
            "Redo did not restore the real changed mapping region.")

        batchMappings := app.Repository.Load()
        MappingHistoryIntegrationAssert(batchMappings.Length >= 2,
            "The integration fixture cannot exercise batch mapping commands.")
        batchIds := [batchMappings[1].Id, batchMappings[2].Id]
        batchHistoryCount := app.MappingHistory.GetUndoCount()
        batchApplyCount := app.Runtime.ApplyCount
        batchLoadCount := app.Repository.LoadCalls
        batchUpdateCount := app.Window.UpdateCount
        toggledMappings := app.ToggleMappingsEnabled(batchIds)
        batchToggleBody := app.Repository.ReadRegionBody()
        MappingHistoryIntegrationAssert(Type(toggledMappings) == "Array"
                && toggledMappings.Length == 2
                && batchToggleBody != afterBody
                && app.MappingHistory.GetUndoCount()
                    == batchHistoryCount + 1
                && app.Runtime.ApplyCount == batchApplyCount + 1
                && app.Repository.LoadCalls == batchLoadCount
                && app.Window.UpdateCount == batchUpdateCount + 2,
            "Batch toggle reparsed rules or broke its atomic transaction.")
        MappingHistoryIntegrationAssert(app.UndoMappingChange()
                && app.Repository.ReadRegionBody() == afterBody,
            "Undo did not restore the atomic batch toggle.")

        batchHistoryCount := app.MappingHistory.GetUndoCount()
        batchApplyCount := app.Runtime.ApplyCount
        batchLoadCount := app.Repository.LoadCalls
        batchReplaceCount := app.Window.ReplaceCount
        removedMappings := app.DeleteMappings(batchIds)
        postDeleteLoadCount := app.Repository.LoadCalls
        remainingMappingCount := app.Repository.Load().Length
        MappingHistoryIntegrationAssert(Type(removedMappings) == "Array"
                && removedMappings.Length == 2
                && remainingMappingCount == batchMappings.Length - 2
                && app.MappingHistory.GetUndoCount()
                    == batchHistoryCount + 1
                && app.Runtime.ApplyCount == batchApplyCount + 1
                && postDeleteLoadCount == batchLoadCount
                && app.Window.RemoveCount == 2
                && app.Window.ReplaceCount == batchReplaceCount,
            "Batch delete was not one atomic apply with incremental UI removal.")
        MappingHistoryIntegrationAssert(app.UndoMappingChange()
                && app.Repository.ReadRegionBody() == afterBody,
            "Undo did not restore the atomic batch delete.")

        ; Simulate an external editor replacing the exact region before undo.
        app.Repository.WriteRegionBody(beforeBody, afterBody)
        undoCount := app.MappingHistory.GetUndoCount()
        MappingHistoryIntegrationAssert(!app.UndoMappingChange()
                && app.MappingHistory.GetUndoCount() == undoCount
                && app.Repository.ReadRegionBody() == beforeBody
                && app.Window.LastStatusIsError,
            "A conflicting external edit was overwritten or lost history.")

        trackingRepository := SyntaxTrackingMappingCodeRepository(testScript)
        trackingId := trackingRepository.Load()[1].Id
        trackingRepository.ToggleEnabled(trackingId)
        trackingRepository.ToggleEnabled(trackingId)
        MappingHistoryIntegrationAssert(
            trackingRepository.SyntaxValidationCalls == 0,
            "Comment-only mapping edits launched redundant syntax checks.")

        settingsApp := SettingsTransactionApp()
        MappingHistoryIntegrationAssert(!settingsApp.SaveSettings(
                {Theme: "fail"})
                && settingsApp.Settings.Theme == "old"
                && settingsApp.SettingsService.Snapshot == "old snapshot"
                && settingsApp.ApplyCalls.Length == 2
                && settingsApp.ApplyCalls[2] == "old"
                && settingsApp.Window.LastStatusIsError,
            "A failed runtime settings apply was not rolled back.")
        MappingHistoryIntegrationAssert(settingsApp.SaveSettings(
                {Theme: "new"})
                && settingsApp.Settings.Theme == "new"
                && settingsApp.SettingsService.Snapshot == "snapshot:new"
                && !settingsApp.Window.LastStatusIsError,
            "A successful settings transaction was not committed.")
        aiConnectionSettings := {
            AIAddress: "https://example.test/v1",
            AIKey: "secret-key",
            AIModel: "demo-model",
            AITimeoutS: 37
        }
        MappingHistoryIntegrationAssert(
            settingsApp.SaveAIConnectionSettings(aiConnectionSettings)
                && settingsApp.Settings.Theme == "new"
                && settingsApp.Settings.AIAddress
                    == aiConnectionSettings.AIAddress
                && settingsApp.Settings.AIKey == aiConnectionSettings.AIKey
                && settingsApp.Settings.AIModel
                    == aiConnectionSettings.AIModel
                && settingsApp.Settings.AITimeoutS
                    == aiConnectionSettings.AITimeoutS
                && settingsApp.SettingsService.LastSaved.Theme == "new",
            "Saving AI parameters did not preserve unrelated settings.")

        lifecycleApp := AppLifecycleTestApp()
        openedWindow := AppLifecycleWindow()
        MappingHistoryIntegrationAssert(lifecycleApp.OpenAuxiliaryWindow(
                "EventViewer", () => openedWindow, "viewer")
                && lifecycleApp.EventViewer == openedWindow
                && openedWindow.ShowCount == 1,
            "A successfully shown auxiliary window was not retained.")
        MappingHistoryIntegrationAssert(lifecycleApp.OpenAuxiliaryWindow(
                "EventViewer", () => AppLifecycleWindow(), "viewer")
                && openedWindow.ActivateCount == 1,
            "Opening an existing auxiliary window did not activate it.")
        lifecycleApp.EventViewer := ""
        failedWindow := AppLifecycleWindow(true)
        MappingHistoryIntegrationAssert(!lifecycleApp.OpenAuxiliaryWindow(
                "EventViewer", () => failedWindow, "viewer")
                && !IsObject(lifecycleApp.EventViewer)
                && failedWindow.DisposeCount == 1
                && failedWindow.LastActivateOwner == false,
            "A failed auxiliary-window show leaked its owned resources.")
        lifecycleApp.RegisterCallbacks()
        try MappingHistoryIntegrationAssert(lifecycleApp.CallbacksRegistered,
            "Application callbacks were not registered as one group.")
        finally lifecycleApp.UnregisterCallbacks()
        MappingHistoryIntegrationAssert(!lifecycleApp.CallbacksRegistered,
            "Application callbacks were not unregistered as one group.")
        reloadMarkerApp := ReloadMarkerTestApp()
        MappingHistoryIntegrationAssert(reloadMarkerApp
                .ConsumeShowAfterReloadMarker()
                && !reloadMarkerApp.MarkerPresent
                && reloadMarkerApp.WriteCount == 1,
            "A reload marker was not consumed exactly once.")
        reloadMarkerApp := ReloadMarkerTestApp(true)
        MappingHistoryIntegrationAssert(!reloadMarkerApp
                .ConsumeShowAfterReloadMarker()
                && reloadMarkerApp.MarkerPresent
                && reloadMarkerApp.WriteCount == 1,
            "A failed reload-marker cleanup was reported as successful.")
        cleanupOrder := []
        constructionApp := ConstructionCleanupTestApp(cleanupOrder)
        MappingHistoryIntegrationAssert(!constructionApp
                .CleanupConstructionResources().Length
                && constructionApp.OrderIsExpected(cleanupOrder)
                && constructionApp.AllResourcesCleanedOnce(),
            "Construction rollback omitted, duplicated, or reordered resources.")
        try FileAppend("PASS mapping history integration`n", "*")
    } catch as testError {
        diagnostic := testError.Message "`n" testError.Stack "`n"
        try FileAppend(diagnostic, "**")
        catch
            MsgBox(diagnostic, "mapping-history-integration-tests.ahk",
                "Iconx")
        succeeded := false
    } finally {
        if FileExist(testScript)
            try FileDelete(testScript)
    }
    return !IsSet(succeeded)
}

MappingHistoryIntegrationAssert(value, message) {
    if !value
        throw Error(message)
}

MappingHistoryIntegrationAssertThrows(callback, message) {
    try callback.Call()
    catch
        return true
    throw Error(message)
}

Tr(template, values*) {
    return values.Length ? Format(template, values*) : template
}

TrDiagnostic(value) => String(value)

PlannedMutationFailure() {
    throw Error("planned pre-write mutation failure")
}

MappingHistoryRepeatText(value, count) {
    result := ""
    chunk := String(value)
    remaining := Integer(count)
    while remaining > 0 {
        if remaining & 1
            result .= chunk
        remaining := remaining >> 1
        if remaining
            chunk .= chunk
    }
    return result
}

class MappingHistoryIntegrationApp extends KeyMouseRemapperAssistantApp {
    __New(scriptPath) {
        this.Repository := MutationTrackingMappingCodeRepository(scriptPath)
        this.MappingHistory := MappingHistoryService(20)
        this.Runtime := MappingHistoryRuntimeStub()
        this.Window := MappingHistoryWindowStub()
        this.RuleColors := Map()
        this.MappingCount := 0
        this.RuntimeReport := ""
        this.PendingScriptApply := ""
        this.PendingScriptApplyTimer := ObjBindMethod(this,
            "ApplyPendingScriptMappings")
        this.ShuttingDown := false
    }

    TraceEvent(*) => true
}

class MutationTrackingMappingCodeRepository extends MappingCodeRepository {
    __New(scriptPath) {
        super.__New(scriptPath)
        this.LoadCalls := 0
        this.ParseCalls := 0
    }

    Load() {
        this.LoadCalls++
        return super.Load()
    }

    ParseMappings(regionBody, firstLineNumber := 1) {
        this.ParseCalls++
        return super.ParseMappings(regionBody, firstLineNumber)
    }
}

class MappingHistoryRuntimeStub {
    __New() {
        this.ApplyCount := 0
        this.FailNextApply := false
    }

    ApplyMappings(mappings) {
        this.ApplyCount++
        if this.FailNextApply {
            this.FailNextApply := false
            throw Error("planned empty-body apply failure")
        }
        return {Applied: mappings.Length, Registrations: mappings.Length}
    }
}

class MappingHistoryWindowStub {
    __New() {
        this.LastStatus := ""
        this.LastStatusIsError := false
        this.StatusRevision := 0
        this.PreferredId := ""
        this.UpdateCount := 0
        this.RemoveCount := 0
        this.ReplaceCount := 0
        this.LastPreviousId := ""
        this.LastUpdatedId := ""
    }

    SetStatus(message, isError := false) {
        this.StatusRevision++
        this.LastStatus := String(message)
        this.LastStatusIsError := !!isError
    }

    GetStatusRevision() => this.StatusRevision

    IsCurrentStatus(message, isError := false, revision := 0) {
        return this.LastStatus == String(message)
            && this.LastStatusIsError == !!isError
            && (!revision || this.StatusRevision == Integer(revision))
    }

    ReplaceRows(mappings, preferredId := "") {
        this.ReplaceCount++
        this.PreferredId := String(preferredId)
        return mappings.Length
    }

    UpdateMappingRow(mapping, previousId := "") {
        this.UpdateCount++
        this.LastPreviousId := String(previousId)
        this.LastUpdatedId := String(mapping.Id)
        return true
    }

    RemoveMappingRow(*) {
        this.RemoveCount++
        return true
    }
}

class SyntaxTrackingMappingCodeRepository extends MappingCodeRepository {
    __New(scriptPath) {
        super.__New(scriptPath)
        this.SyntaxValidationCalls := 0
    }

    ValidateScriptSyntax(*) {
        this.SyntaxValidationCalls++
        return true
    }
}

class SettingsTransactionApp extends KeyMouseRemapperAssistantApp {
    __New() {
        this.Settings := {Theme: "old"}
        this.SettingsService := SettingsTransactionServiceStub()
        this.Window := MappingHistoryWindowStub()
        this.ApplyCalls := []
    }

    ApplySettingsRuntime(settings) {
        this.ApplyCalls.Push(settings.Theme)
        if settings.Theme == "fail"
            throw Error("planned appearance failure")
        return true
    }
}

class SettingsTransactionServiceStub {
    __New() {
        this.Snapshot := "old snapshot"
        this.LastSaved := ""
    }

    GetSnapshot() => this.Snapshot

    Normalize(settings) {
        return {
            Theme: settings.HasOwnProp("Theme") ? settings.Theme : "old",
            AIAddress: settings.HasOwnProp("AIAddress")
                ? settings.AIAddress : "",
            AIKey: settings.HasOwnProp("AIKey") ? settings.AIKey : "",
            AIModel: settings.HasOwnProp("AIModel") ? settings.AIModel : "",
            AITimeoutS: settings.HasOwnProp("AITimeoutS")
                ? settings.AITimeoutS : 600
        }
    }

    Save(candidate, expectedSnapshot) {
        if expectedSnapshot != this.Snapshot
            throw Error("settings conflict")
        normalized := this.Normalize(candidate)
        this.LastSaved := normalized
        this.Snapshot := this.BuildSnapshot(normalized)
        return normalized
    }

    BuildSnapshot(settings) => "snapshot:" settings.Theme

    WriteSnapshot(snapshot, expectedSnapshot) {
        if this.Snapshot != expectedSnapshot
            throw Error("settings rollback conflict")
        this.Snapshot := snapshot
        return true
    }
}

class AppLifecycleTestApp extends KeyMouseRemapperAssistantApp {
    __New() {
        this.ShuttingDown := false
        this.CallbacksRegistered := false
        this.EventViewer := ""
        this.Window := MappingHistoryWindowStub()
        this.AppCommandCallback := ObjBindMethod(this, "IgnoreMessage")
        this.SystemCommandCallback := ObjBindMethod(this, "IgnoreMessage")
        this.SettingChangeCallback := ObjBindMethod(this, "IgnoreMessage")
        this.PowerBroadcastCallback := ObjBindMethod(this, "IgnoreMessage")
        this.SessionChangeCallback := ObjBindMethod(this, "IgnoreMessage")
        this.ShowApplicationMessage := 0
        this.ShowApplicationCallback := ObjBindMethod(this, "IgnoreMessage")
        this.ExitCallback := ObjBindMethod(this, "IgnoreMessage")
    }

    IgnoreMessage(*) => 0
}

class AppLifecycleWindow {
    __New(failShow := false) {
        this.FailShow := !!failShow
        this.Disposed := false
        this.ShowCount := 0
        this.ActivateCount := 0
        this.DisposeCount := 0
        this.LastActivateOwner := true
    }

    Show() {
        this.ShowCount++
        if this.FailShow
            throw Error("planned show failure")
        return true
    }

    Activate() {
        this.ActivateCount++
        return true
    }

    Dispose(activateOwner := true) {
        this.DisposeCount++
        this.LastActivateOwner := !!activateOwner
        this.Disposed := true
        return true
    }
}

class ReloadMarkerTestApp extends KeyMouseRemapperAssistantApp {
    __New(failWrite := false) {
        this.MarkerPresent := true
        this.FailWrite := !!failWrite
        this.WriteCount := 0
    }

    ReadShowAfterReloadMarker() => this.MarkerPresent

    WriteShowAfterReloadMarker(enabled) {
        this.WriteCount++
        if this.FailWrite
            throw Error("planned marker write failure")
        this.MarkerPresent := !!enabled
        return true
    }
}

class ConstructionCleanupTestApp extends KeyMouseRemapperAssistantApp {
    __New(order) {
        this.UpdateService := ConstructionCleanupResource(order, "update")
        this.Capture := ConstructionCleanupResource(order, "capture")
        this.RawInput := ConstructionCleanupResource(order, "raw")
        this.Runtime := ConstructionCleanupResource(order, "runtime")
        this.Window := ConstructionCleanupResource(order, "window")
        this.SvgRenderer := ConstructionCleanupResource(order, "svg")
        this.LocalizationConfigured := false
    }

    AllResourcesCleanedOnce() {
        for resource in [this.UpdateService, this.Capture, this.RawInput,
                this.Runtime, this.Window, this.SvgRenderer] {
            if resource.CleanupCount != 1
                return false
        }
        return true
    }

    OrderIsExpected(order) {
        expected := ["update", "capture", "raw", "runtime", "window", "svg"]
        if order.Length != expected.Length
            return false
        for index, name in expected {
            if order[index] != name
                return false
        }
        return true
    }
}

class ConstructionCleanupResource {
    __New(order, name) {
        this.Order := order
        this.Name := name
        this.CleanupCount := 0
    }

    Record() {
        this.CleanupCount++
        this.Order.Push(this.Name)
        return true
    }

    Shutdown(*) => this.Record()
    Stop(*) => this.Record()
    Dispose(*) => this.Record()
}
