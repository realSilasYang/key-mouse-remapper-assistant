#Requires AutoHotkey v2.0.26 64-bit
#NoTrayIcon
#SingleInstance Off
#Warn All, StdOut

#Include ..\src\Core\BoundedFileReader.ahk
#Include ..\src\Core\JsonCodec.ahk
#Include ..\src\Core\Sha256.ahk
#Include ..\src\Core\HmacSha256.ahk
#Include ..\src\Core\AuthenticatedIpcProtocol.ahk
#Include ..\src\Core\CrossProcessWriteLock.ahk
#Include ..\src\Core\OutputRecoveryJournal.ahk
#Include ..\src\Core\RuleSpec.ahk
#Include ..\src\Core\DeviceIdentityService.ahk
#Include ..\src\Core\InputEvent.ahk
#Include ..\src\Core\RuleTimingResolver.ahk
#Include ..\src\Core\RuleSpecMigrationService.ahk
#Include ..\src\Core\RuleCompiler.ahk
#Include ..\src\Core\RuleConflictAnalyzer.ahk
#Include ..\src\Core\ScopedVariableStore.ahk
#Include ..\src\Core\RuleConditionEvaluator.ahk
#Include ..\src\Core\ManagedRuleStateMachine.ahk
#Include ..\src\Core\RuleScheduler.ahk
#Include ..\src\Core\OutputLedger.ahk
#Include ..\src\Core\InputBackend.ahk
#Include ..\src\Platform\Win32.ahk
#Include ..\src\Input\RawInputObservationPolicy.ahk
#Include ..\src\Input\RawInputService.ahk
#Include ..\src\Core\RawInputBackend.ahk
#Include ..\src\Core\ManagedRuleRuntime.ahk
#Include ..\src\Core\MappingCodeRepository.ahk
#Include ..\src\Platform\NamedPipeChannel.ahk
#Include ..\src\Process\WorkerBootstrap.ahk
#Include ..\src\Process\WorkerEventBuffer.ahk
#Include ..\src\Platform\WindowsContextService.ahk
#Include ..\src\Workers\InputEngineWorker.ahk

for argument in A_Args {
    if argument == "--syntax-check"
        ExitApp()
}

if !WorkerBootstrap.ApplyFromArguments(A_Args) {
    FileAppend("KMR_WORKER_BOOTSTRAP_REQUIRED: "
        . "输入工作进程必须通过一次性启动信封启动。`n", "**")
    ExitApp(1)
}
global Worker := InputEngineWorker.RunFromEnvironment()
