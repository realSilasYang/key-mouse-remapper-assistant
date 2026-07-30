#Requires AutoHotkey v2.0.26 64-bit
#SingleInstance Off
#Warn All, StdOut
FileEncoding "UTF-8-RAW"

#Include src\Core\CommandLine.ahk
#Include src\Core\BoundedFileReader.ahk
#Include src\Core\JsonCodec.ahk
#Include src\Core\Sha256.ahk
#Include src\Core\CrossProcessWriteLock.ahk
#Include src\Core\ApplicationControlQueue.ahk
#Include src\Core\RuleSpec.ahk
#Include src\Core\DeviceIdentityService.ahk
#Include src\Core\InputEvent.ahk
#Include src\Core\RuleTimingResolver.ahk
#Include src\Core\RuleSpecMigrationService.ahk
#Include src\Core\RuleCompiler.ahk
#Include src\Core\RuleConflictAnalyzer.ahk
#Include src\Core\RuleConditionEvaluator.ahk
#Include src\Core\RuleSimulationService.ahk
#Include src\Core\MappingCodeRepository.ahk
#Include src\Config\AppDataPaths.ahk
#Include src\Core\ScopedVariableStore.ahk
#Include src\Core\InputBackend.ahk
#Include src\Platform\Win32.ahk
#Include src\Input\RawInputService.ahk
#Include src\Core\RawInputBackend.ahk
#Include src\Core\RulePackageService.ahk
#Include src\Core\DiagnosticBundleService.ahk
#Include src\Platform\WindowsContextService.ahk

defaultPaths := KeyMouseRemapperAssistantDataPaths.Resolve()
ExitApp(CommandLineApp().Run(A_Args,
    A_ScriptDir "\键鼠重映射小助手.ahk", defaultPaths.Variables))
