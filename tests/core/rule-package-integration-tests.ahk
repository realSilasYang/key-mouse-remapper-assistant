#Requires AutoHotkey v2.0 64-bit
#SingleInstance Force
#NoTrayIcon
#Warn All, StdOut

#Include ..\..\src\Core\BoundedFileReader.ahk
#Include ..\..\src\Core\JsonCodec.ahk
#Include ..\..\src\Core\Sha256.ahk
#Include ..\..\src\Core\CrossProcessWriteLock.ahk
#Include ..\..\src\Core\ApplicationVersionInfo.ahk
#Include ..\..\src\Core\RuleSpec.ahk
#Include ..\..\src\Core\ScriptRuleSpec.ahk
#Include ..\..\src\Core\RuleCompiler.ahk
#Include ..\..\src\Core\ScriptRuleCompiler.ahk
#Include ..\..\src\Core\MappingCodeRepository.ahk
#Include ..\..\src\Core\RulePackageService.ahk

ExitApp(RunRulePackageIntegrationTests() ? 0 : 1)

RunRulePackageIntegrationTests() {
    sourceScript := A_ScriptDir "\..\..\键鼠重映射小助手.ahk"
    temporaryScript := A_Temp "\kmra-rule-package-"
        . DllCall("kernel32\GetCurrentProcessId", "UInt") "-"
        . A_TickCount ".ahk"
    try {
        repository := MappingCodeRepository(sourceScript)
        mappings := repository.Load()
        service := RulePackageService()
        document := service.Build(mappings)
        RulePackageIntegrationAssert(document["schema"]
                == RulePackageService.Schema,
            "Mixed package used the wrong schema.")
        RulePackageIntegrationAssert(
            RulePackageIntegrationContains(document["capabilities"],
                "script_rules")
                && RulePackageIntegrationContains(document["permissions"],
                    "arbitrary_code"),
            "Mixed package omitted script capability or permission.")
        parsed := service.Parse(JsonCodec.Stringify(document, false, true))
        RulePackageIntegrationAssert(parsed["rules"].Length
                == mappings.Length,
            "Mixed package parsing changed the rule count.")
        scriptIds := []
        for mapping in mappings {
            if mapping.Mode == "script"
                scriptIds.Push(mapping.Id)
        }
        RulePackageIntegrationAssert(scriptIds.Length > 0,
            "Mixed package fixture does not contain a script rule.")
        parsedScriptCount := 0
        for rule in parsed["rules"] {
            if rule["mode"] != "script"
                continue
            parsedScriptCount++
            original := RulePackageIntegrationFind(mappings, rule["id"])
            RulePackageIntegrationAssert(IsObject(original)
                    && original.Mode == "script"
                    && rule["spec"]["code"] == original.Spec["code"],
                "Script package parsing changed embedded source: " rule["id"])
        }
        RulePackageIntegrationAssert(parsedScriptCount == scriptIds.Length,
            "Mixed package did not preserve every script rule.")

        FileCopy(sourceScript, temporaryScript)
        targetRepository := MappingCodeRepository(temporaryScript)
        result := service.ImportPackage(parsed, targetRepository, "rename",
            scriptIds)
        RulePackageIntegrationAssert(result.Imported == scriptIds.Length
                && result.Renamed == scriptIds.Length,
            "Script rule collision renaming was not atomic.")
        importedMappings := targetRepository.Load()
        RulePackageIntegrationAssert(importedMappings.Length
                == mappings.Length + scriptIds.Length,
            "Script package import changed the wrong number of rules.")
        for importedId in result.Ids {
            imported := RulePackageIntegrationFind(importedMappings,
                importedId)
            RulePackageIntegrationAssert(IsObject(imported)
                    && imported.Mode == "script"
                    && Trim(imported.Spec["code"]) != "",
                "Renamed script import lost its mode or source.")
        }
        FileAppend("PASS rule package integration`n", "*")
        return true
    } catch as testError {
        FileAppend(testError.Message "`n" testError.Stack "`n", "**")
        return false
    } finally {
        if FileExist(temporaryScript)
            try FileDelete(temporaryScript)
    }
}

RulePackageIntegrationFind(mappings, expectedId) {
    for mapping in mappings {
        if mapping.Id == expectedId
            return mapping
    }
    return ""
}

RulePackageIntegrationContains(values, expected) {
    for value in values {
        if value == expected
            return true
    }
    return false
}

RulePackageIntegrationAssert(value, message) {
    if !value
        throw Error(message)
}
