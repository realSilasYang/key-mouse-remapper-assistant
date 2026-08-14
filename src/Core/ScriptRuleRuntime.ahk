class ScriptRuleRuntime {
    static SyntaxCheckFlag := "--kmra-script-syntax-check"
    static SignalPollMilliseconds := 50
    static StartTimeoutMilliseconds := 3000
    static StopTimeoutMilliseconds := 1500
    static PauseTimeoutMilliseconds := 3000
    static CapturePauseConfirmationMilliseconds := 250
    static MaximumDiagnosticBytes := 1024 * 1024

    __New(app, runtimeDirectory := "") {
        this.App := app
        this.InterpreterPath := app.HasOwnProp("InterpreterPath")
                && Trim(String(app.InterpreterPath)) != ""
            ? String(app.InterpreterPath) : A_AhkPath
        this.RuntimeDirectory := runtimeDirectory != ""
            ? String(runtimeDirectory)
            : app.DataDirectory "\script-rules"
        this.Workers := Map()
        this.Mappings := []
        this.Suspended := false
        this.ShuttingDown := false
        this.EnsureRuntimeDirectory()
        this.CleanupRuntimeDirectory()
    }

    ApplyMappings(mappings) {
        if Type(mappings) != "Array"
            throw TypeError("脚本规则必须是数组。")
        desired := Map()
        normalizedMappings := []
        for mapping in mappings {
            if !mapping.HasOwnProp("Mode") || mapping.Mode != "script"
                throw Error("脚本运行时收到了非 script 规则。")
            spec := ScriptRuleSpec.Normalize(mapping.Spec)
            normalized := ScriptRuleRuntime.CloneMapping(mapping, spec)
            normalizedMappings.Push(normalized)
            if !spec.Get("enabled", JsonBoolean(true)).Value
                continue
            if desired.Has(spec["id"])
                throw Error("脚本规则名称重复：" spec["id"])
            digest := this.GetSpecDigest(spec)
            desired[spec["id"]] := {Mapping: normalized, Digest: digest}
            if !this.Workers.Has(spec["id"])
                    || this.Workers[spec["id"]].Digest != digest
                this.ValidateSpec(spec)
        }

        previousMappings := this.Mappings
        previousWorkers := this.Workers
        nextWorkers := Map()
        startedWorkers := []
        stoppedWorkers := []
        try {
            for ruleId, entry in desired {
                mapping := entry.Mapping
                digest := entry.Digest
                if previousWorkers.Has(ruleId)
                        && previousWorkers[ruleId].Digest == digest {
                    worker := previousWorkers[ruleId]
                    nextWorkers[ruleId] := worker
                    continue
                }
                if previousWorkers.Has(ruleId) {
                    oldWorker := previousWorkers[ruleId]
                    this.StopWorker(oldWorker)
                    stoppedWorkers.Push({Worker: oldWorker,
                        Mapping: this.FindMapping(previousMappings, ruleId)})
                }
                worker := this.StartWorker(mapping, digest)
                nextWorkers[ruleId] := worker
                startedWorkers.Push(worker)
            }
            for ruleId, worker in previousWorkers {
                if desired.Has(ruleId)
                    continue
                this.StopWorker(worker)
                stoppedWorkers.Push({Worker: worker,
                    Mapping: this.FindMapping(previousMappings, ruleId)})
            }
        } catch as applyError {
            for worker in startedWorkers
                try this.StopWorker(worker)
            restoredWorkers := Map()
            restoreMessages := []
            for ruleId, worker in previousWorkers {
                if !this.WorkerWasStopped(stoppedWorkers, ruleId) {
                    restoredWorkers[ruleId] := worker
                    continue
                }
                mapping := this.FindMapping(previousMappings, ruleId)
                if !IsObject(mapping)
                    continue
                try restoredWorkers[ruleId] := this.StartWorker(mapping,
                    this.GetSpecDigest(mapping.Spec))
                catch as restoreError
                    restoreMessages.Push(ruleId "：" restoreError.Message)
            }
            this.Workers := restoredWorkers
            this.Mappings := previousMappings
            if restoreMessages.Length
                throw Error(applyError.Message "；恢复原脚本规则失败："
                    ScriptRuleSpec.Join(restoreMessages, "；"), -1,
                    applyError)
            throw applyError
        }
        this.Workers := nextWorkers
        this.Mappings := normalizedMappings
        this.Trace("script_rules_applied", {Outcome: "ok", Data: Map(
            "rules", normalizedMappings.Length,
            "workers", nextWorkers.Count)})
        return {Applied: nextWorkers.Count, Workers: nextWorkers.Count}
    }

    ValidateSpec(spec) {
        spec := ScriptRuleSpec.Normalize(spec)
        AhkV2ScriptValidator.Validate(spec["code"])
        validationToken := this.CreateToken(spec["id"] "-validation")
        source := this.BuildWorkerSource(spec, validationToken,
            validationToken "-stop", validationToken "-pause",
            validationToken "-ready")
        this.EnsureRuntimeDirectory()
        path := this.RuntimeDirectory "\.validate-" validationToken ".ahk"
        diagnosticPath := path ".diagnostic"
        this.WriteTextFile(path, source)
        try {
            exitCode := this.RunSyntaxCheck(path, diagnosticPath)
            diagnostic := this.ReadDiagnostic(diagnosticPath)
            if exitCode != 0 || this.DiagnosticContainsError(diagnostic)
                throw Error("自定义 AHK v2 代码未通过语法检查。"
                    . (diagnostic == "" ? "" : "`n" diagnostic))
        } finally {
            if FileExist(path)
                try FileDelete(path)
            if FileExist(diagnosticPath)
                try FileDelete(diagnosticPath)
        }
        return true
    }

    RunSyntaxCheck(path, diagnosticPath) {
        outputHandle := 0
        inputHandle := 0
        processHandle := 0
        threadHandle := 0
        jobHandle := 0
        processCompleted := false
        try {
            securityAttributes := Buffer(A_PtrSize == 8 ? 24 : 12, 0)
            NumPut("UInt", securityAttributes.Size, securityAttributes, 0)
            NumPut("Int", true, securityAttributes,
                A_PtrSize == 8 ? 16 : 8)
            outputHandle := DllCall("kernel32\CreateFileW", "WStr",
                diagnosticPath, "UInt", 0x40000000, "UInt", 0x00000003,
                "Ptr", securityAttributes.Ptr, "UInt", 2, "UInt", 0x80,
                "Ptr", 0, "Ptr")
            if outputHandle == -1
                throw OSError(A_LastError, "无法创建脚本语法诊断文件。")
            inputHandle := DllCall("kernel32\CreateFileW", "WStr", "NUL",
                "UInt", 0x80000000, "UInt", 0x00000003,
                "Ptr", securityAttributes.Ptr, "UInt", 3, "UInt", 0x80,
                "Ptr", 0, "Ptr")
            if inputHandle == -1
                throw OSError(A_LastError, "无法打开脚本语法校验输入。")

            startupInfo := Buffer(A_PtrSize == 8 ? 104 : 68, 0)
            NumPut("UInt", startupInfo.Size, startupInfo, 0)
            NumPut("UInt", 0x00000101, startupInfo,
                A_PtrSize == 8 ? 60 : 44)
            NumPut("UShort", 0, startupInfo,
                A_PtrSize == 8 ? 64 : 48)
            stdinOffset := A_PtrSize == 8 ? 80 : 56
            NumPut("Ptr", inputHandle, startupInfo, stdinOffset)
            NumPut("Ptr", outputHandle, startupInfo,
                stdinOffset + A_PtrSize)
            NumPut("Ptr", outputHandle, startupInfo,
                stdinOffset + A_PtrSize * 2)

            command := QuoteRuntimeCommandArgument(this.InterpreterPath)
                . " /ErrorStdOut " . QuoteRuntimeCommandArgument(path)
                . " " ScriptRuleRuntime.SyntaxCheckFlag
            commandBuffer := Buffer(StrPut(command, "UTF-16") * 2, 0)
            StrPut(command, commandBuffer, "UTF-16")
            processInformation := Buffer(A_PtrSize == 8 ? 24 : 16, 0)
            jobHandle := this.CreateWorkerJob("Local\KMRA-"
                . this.CreateToken("syntax-validation") "-job")
            if !DllCall("kernel32\CreateProcessW",
                    "WStr", this.InterpreterPath,
                    "Ptr", commandBuffer.Ptr,
                    "Ptr", 0, "Ptr", 0, "Int", true,
                    "UInt", 0x08000004, "Ptr", 0,
                    "WStr", this.RuntimeDirectory,
                    "Ptr", startupInfo.Ptr,
                    "Ptr", processInformation.Ptr, "Int")
                throw OSError(A_LastError,
                    "无法启动脚本语法校验进程。")
            processHandle := NumGet(processInformation, 0, "Ptr")
            threadHandle := NumGet(processInformation, A_PtrSize, "Ptr")
            if !DllCall("kernel32\AssignProcessToJobObject", "Ptr",
                    jobHandle, "Ptr", processHandle, "Int")
                throw OSError(A_LastError,
                    "无法管理脚本语法校验进程。")
            if DllCall("kernel32\ResumeThread", "Ptr", threadHandle,
                    "UInt") == 0xFFFFFFFF
                throw OSError(A_LastError,
                    "无法恢复脚本语法校验进程。")
            waitResult := DllCall("kernel32\WaitForSingleObject", "Ptr",
                processHandle, "UInt",
                ScriptRuleRuntime.StartTimeoutMilliseconds, "UInt")
            if waitResult == 0x00000102 {
                DllCall("kernel32\TerminateJobObject", "Ptr", jobHandle,
                    "UInt", 1, "Int")
                DllCall("kernel32\WaitForSingleObject", "Ptr",
                    processHandle, "UInt", 1000, "UInt")
                throw Error("自定义 AHK v2 代码语法检查超时。")
            }
            if waitResult != 0
                throw OSError(A_LastError,
                    "等待脚本语法校验进程失败。")
            processCompleted := true
            exitCode := 0
            if !DllCall("kernel32\GetExitCodeProcess", "Ptr",
                    processHandle, "UInt*", &exitCode, "Int")
                throw OSError(A_LastError,
                    "无法读取脚本语法校验退出码。")
            return exitCode
        } finally {
            if processHandle && !processCompleted {
                DllCall("kernel32\TerminateProcess", "Ptr", processHandle,
                    "UInt", 1, "Int")
                DllCall("kernel32\WaitForSingleObject", "Ptr",
                    processHandle, "UInt", 1000, "UInt")
            }
            if jobHandle
                DllCall("kernel32\CloseHandle", "Ptr", jobHandle)
            if threadHandle
                DllCall("kernel32\CloseHandle", "Ptr", threadHandle)
            if processHandle
                DllCall("kernel32\CloseHandle", "Ptr", processHandle)
            if inputHandle && inputHandle != -1
                DllCall("kernel32\CloseHandle", "Ptr", inputHandle)
            if outputHandle && outputHandle != -1
                DllCall("kernel32\CloseHandle", "Ptr", outputHandle)
        }
    }

    StartWorker(mapping, digest) {
        spec := ScriptRuleSpec.Normalize(mapping.Spec)
        this.EnsureRuntimeDirectory()
        token := this.CreateToken(spec["id"])
        stopName := "Local\KMRA-" token "-stop"
        pauseName := "Local\KMRA-" token "-pause"
        readyName := "Local\KMRA-" token "-ready"
        pauseAppliedName := "Local\KMRA-" token "-pause-applied"
        jobName := "Local\KMRA-" token "-job"
        path := this.RuntimeDirectory "\worker-" token ".ahk"
        worker := {Id: spec["id"], Digest: digest, Path: path,
            StopHandle: 0, PauseHandle: 0, PauseAppliedHandle: 0,
            ReadyHandle: 0, JobHandle: 0, ProcessHandle: 0,
            ProcessId: 0, Token: token}
        try {
            worker.JobHandle := this.CreateWorkerJob(jobName)
            worker.StopHandle := this.CreateSignal(stopName, false)
            worker.PauseHandle := this.CreateSignal(pauseName, this.Suspended)
            worker.PauseAppliedHandle := this.CreateSignal(
                pauseAppliedName, false)
            worker.ReadyHandle := this.CreateSignal(readyName, false)
            source := this.BuildWorkerSource(spec, token, stopName, pauseName,
                readyName, 0, jobName, pauseAppliedName)
            this.WriteTextFile(path, source)
            command := QuoteRuntimeCommandArgument(this.InterpreterPath) " "
                . QuoteRuntimeCommandArgument(path)
            Run(command, this.RuntimeDirectory, "Hide", &processId)
            worker.ProcessId := processId
            worker.ProcessHandle := DllCall("kernel32\OpenProcess", "UInt",
                0x00100001, "Int", false, "UInt", processId, "Ptr")
            if !worker.ProcessHandle
                throw OSError(A_LastError,
                    "无法取得脚本规则进程句柄：" spec["id"])
            waitResult := DllCall("kernel32\WaitForSingleObject", "Ptr",
                worker.ReadyHandle, "UInt",
                ScriptRuleRuntime.StartTimeoutMilliseconds, "UInt")
            if waitResult != 0
                throw Error("脚本规则启动超时：" spec["id"])
            if !this.WaitForWorkerPauseState(worker, this.Suspended,
                    ScriptRuleRuntime.PauseTimeoutMilliseconds)
                throw Error("脚本规则未确认初始暂停状态：" spec["id"])
            this.Trace("script_rule_started", {RuleId: spec["id"],
                Outcome: "ok", Data: Map("pid", processId)})
            return worker
        } catch as startError {
            if worker.StopHandle
                try DllCall("kernel32\SetEvent", "Ptr",
                    worker.StopHandle, "Int")
            if worker.JobHandle {
                try DllCall("kernel32\TerminateJobObject", "Ptr",
                    worker.JobHandle, "UInt", 1, "Int")
            } else if worker.ProcessHandle {
                try DllCall("kernel32\TerminateProcess", "Ptr",
                    worker.ProcessHandle, "UInt", 1, "Int")
            } else if worker.ProcessId {
                try ProcessClose(worker.ProcessId)
            }
            this.CloseWorkerHandles(worker)
            if FileExist(path)
                try FileDelete(path)
            throw startError
        }
    }

    StopWorker(worker) {
        if !IsObject(worker)
            return false
        forced := false
        if worker.StopHandle
            DllCall("kernel32\SetEvent", "Ptr", worker.StopHandle, "Int")
        if worker.HasOwnProp("JobHandle") && worker.JobHandle {
            waitResult := DllCall("kernel32\WaitForSingleObject", "Ptr",
                worker.JobHandle, "UInt",
                ScriptRuleRuntime.StopTimeoutMilliseconds, "UInt")
            if waitResult == 0x00000102 {
                if !DllCall("kernel32\TerminateJobObject", "Ptr",
                        worker.JobHandle, "UInt", 1, "Int")
                    throw OSError(A_LastError,
                        "无法强制停止脚本规则作业：" worker.Id)
                forced := true
                waitResult := DllCall("kernel32\WaitForSingleObject", "Ptr",
                    worker.JobHandle, "UInt", 1000, "UInt")
                if waitResult != 0
                    throw Error("无法停止脚本规则作业：" worker.Id)
            } else if waitResult != 0 {
                throw OSError(A_LastError,
                    "等待脚本规则作业退出失败：" worker.Id)
            }
        } else if worker.HasOwnProp("ProcessHandle")
                && worker.ProcessHandle {
            waitResult := DllCall("kernel32\WaitForSingleObject", "Ptr",
                worker.ProcessHandle, "UInt",
                ScriptRuleRuntime.StopTimeoutMilliseconds, "UInt")
            if waitResult == 0x00000102 {
                terminated := DllCall("kernel32\TerminateProcess", "Ptr",
                    worker.ProcessHandle, "UInt", 1, "Int")
                if !terminated && DllCall("kernel32\WaitForSingleObject",
                        "Ptr", worker.ProcessHandle, "UInt", 0, "UInt") != 0
                    throw OSError(A_LastError,
                        "无法强制停止脚本规则进程：" worker.Id)
                forced := !!terminated
                waitResult := DllCall("kernel32\WaitForSingleObject", "Ptr",
                    worker.ProcessHandle, "UInt", 1000, "UInt")
                if waitResult != 0
                    throw Error("无法停止脚本规则进程：" worker.Id)
            } else if waitResult != 0
                throw OSError(A_LastError,
                    "等待脚本规则进程退出失败：" worker.Id)
        } else if worker.ProcessId && ProcessExist(worker.ProcessId) {
            ProcessWaitClose(worker.ProcessId,
                ScriptRuleRuntime.StopTimeoutMilliseconds / 1000)
            if ProcessExist(worker.ProcessId)
                throw Error("无法停止脚本规则进程：" worker.Id)
        }
        this.CloseWorkerHandles(worker)
        if FileExist(worker.Path)
            try FileDelete(worker.Path)
        this.Trace("script_rule_stopped", {RuleId: worker.Id,
            Outcome: forced ? "forced" : "ok"})
        return true
    }

    Suspend() {
        if this.Suspended
            return false
        changed := []
        try {
            for ruleId, worker in this.Workers {
                if !DllCall("kernel32\SetEvent", "Ptr", worker.PauseHandle,
                        "Int")
                    throw OSError(A_LastError, "无法暂停脚本规则：" ruleId)
                changed.Push(worker)
            }
            ; Broadcast first so every worker can acknowledge on the same
            ; manager-timer cycle instead of accumulating one poll per rule.
            for worker in changed {
                if !this.WaitForWorkerPauseState(worker, true,
                        ScriptRuleRuntime.PauseTimeoutMilliseconds)
                    throw Error("脚本规则未确认暂停状态：" worker.Id)
            }
        } catch as suspendError {
            rollbackFailures := []
            Loop changed.Length {
                worker := changed[changed.Length - A_Index + 1]
                if !DllCall("kernel32\ResetEvent", "Ptr",
                        worker.PauseHandle, "Int")
                        || !this.WaitForWorkerPauseState(worker, false,
                            ScriptRuleRuntime.PauseTimeoutMilliseconds)
                    rollbackFailures.Push(worker.Id)
            }
            if rollbackFailures.Length
                throw Error(suspendError.Message "；恢复暂停信号失败："
                    . ScriptRuleSpec.Join(rollbackFailures, "、"), -1,
                    suspendError)
            throw suspendError
        }
        this.Suspended := true
        return true
    }

    SuspendForCapture() {
        if this.Suspended
            return false
        changed := []
        try {
            for ruleId, worker in this.Workers {
                if !DllCall("kernel32\SetEvent", "Ptr", worker.PauseHandle,
                        "Int")
                    throw OSError(A_LastError, "无法暂停脚本规则：" ruleId)
                changed.Push(worker)
            }
            unconfirmed := []
            confirmationStarted := A_TickCount
            for worker in changed {
                remaining := Max(0, ScriptRuleRuntime
                    .CapturePauseConfirmationMilliseconds
                    - (A_TickCount - confirmationStarted))
                if !this.WaitForWorkerPauseState(worker, true, remaining)
                    unconfirmed.Push(worker.Id)
            }
        } catch as suspendError {
            rollbackFailures := []
            Loop changed.Length {
                worker := changed[changed.Length - A_Index + 1]
                if !DllCall("kernel32\ResetEvent", "Ptr",
                        worker.PauseHandle, "Int")
                    rollbackFailures.Push(worker.Id)
            }
            if rollbackFailures.Length
                throw Error(suspendError.Message "；恢复暂停信号失败："
                    . ScriptRuleSpec.Join(rollbackFailures, "、"), -1,
                    suspendError)
            throw suspendError
        }
        this.Suspended := true
        if unconfirmed.Length {
            this.Trace("script_capture_pause_unconfirmed", {
                Outcome: "warning", Data: Map("rules", unconfirmed)})
        }
        return true
    }

    ResumeForCapture() {
        if !this.Suspended
            return false
        changed := []
        try {
            for ruleId, worker in this.Workers {
                if !DllCall("kernel32\ResetEvent", "Ptr", worker.PauseHandle,
                        "Int")
                    throw OSError(A_LastError, "无法恢复脚本规则：" ruleId)
                changed.Push(worker)
            }
            unconfirmed := []
            confirmationStarted := A_TickCount
            for worker in changed {
                remaining := Max(0, ScriptRuleRuntime
                    .CapturePauseConfirmationMilliseconds
                    - (A_TickCount - confirmationStarted))
                if !this.WaitForWorkerPauseState(worker, false, remaining)
                    unconfirmed.Push(worker.Id)
            }
        } catch as resumeError {
            rollbackFailures := []
            Loop changed.Length {
                worker := changed[changed.Length - A_Index + 1]
                if !DllCall("kernel32\SetEvent", "Ptr", worker.PauseHandle,
                        "Int")
                    rollbackFailures.Push(worker.Id)
            }
            if rollbackFailures.Length
                throw Error(resumeError.Message "；恢复运行信号失败："
                    . ScriptRuleSpec.Join(rollbackFailures, "、"), -1,
                    resumeError)
            throw resumeError
        }
        this.Suspended := false
        if unconfirmed.Length {
            this.Trace("script_capture_resume_unconfirmed", {
                Outcome: "warning", Data: Map("rules", unconfirmed)})
        }
        return true
    }

    Resume() {
        if !this.Suspended
            return false
        changed := []
        try {
            for ruleId, worker in this.Workers {
                if !DllCall("kernel32\ResetEvent", "Ptr", worker.PauseHandle,
                        "Int")
                    throw OSError(A_LastError, "无法恢复脚本规则：" ruleId)
                changed.Push(worker)
            }
            for worker in changed {
                if !this.WaitForWorkerPauseState(worker, false,
                        ScriptRuleRuntime.PauseTimeoutMilliseconds)
                    throw Error("脚本规则未确认恢复状态：" worker.Id)
            }
        } catch as resumeError {
            rollbackFailures := []
            Loop changed.Length {
                worker := changed[changed.Length - A_Index + 1]
                if !DllCall("kernel32\SetEvent", "Ptr", worker.PauseHandle,
                        "Int")
                        || !this.WaitForWorkerPauseState(worker, true,
                            ScriptRuleRuntime.PauseTimeoutMilliseconds)
                    rollbackFailures.Push(worker.Id)
            }
            if rollbackFailures.Length
                throw Error(resumeError.Message "；恢复运行信号失败："
                    . ScriptRuleSpec.Join(rollbackFailures, "、"), -1,
                    resumeError)
            throw resumeError
        }
        this.Suspended := false
        return true
    }

    RecoverAfterResume() {
        failures := []
        for ruleId, worker in this.Workers {
            succeeded := this.Suspended
                ? DllCall("kernel32\SetEvent", "Ptr", worker.PauseHandle,
                    "Int")
                : DllCall("kernel32\ResetEvent", "Ptr", worker.PauseHandle,
                    "Int")
            if !succeeded
                failures.Push(ruleId)
        }
        if failures.Length
            throw Error("无法恢复脚本规则控制信号："
                . ScriptRuleSpec.Join(failures, "、"))
        return true
    }

    Shutdown() {
        if this.ShuttingDown
            return true
        this.ShuttingDown := true
        workers := this.Workers
        remaining := Map()
        failures := []
        for ruleId, worker in workers {
            try this.StopWorker(worker)
            catch as stopError {
                remaining[ruleId] := worker
                failures.Push(ruleId "：" stopError.Message)
            }
        }
        this.Workers := remaining
        if failures.Length {
            this.ShuttingDown := false
            throw Error("一个或多个脚本规则无法停止："
                . ScriptRuleSpec.Join(failures, "；"))
        }
        this.Mappings := []
        this.CleanupRuntimeDirectory()
        return true
    }

    BuildWorkerSource(spec, token, stopName, pauseName, readyName,
            parentProcessId := 0, jobName := "", pauseAppliedName := "") {
        poll := ScriptRuleRuntime.SignalPollMilliseconds
        syntaxFlag := ScriptRuleRuntime.SyntaxCheckFlag
        identifier := RegExReplace(token, "[^A-Za-z0-9_]", "_")
        parentPid := parentProcessId ? Integer(parentProcessId)
            : DllCall("kernel32\GetCurrentProcessId", "UInt")
        jobSetup := this.BuildWorkerJobSetup(identifier, jobName)
        pauseAppliedSetup := this.BuildWorkerPauseAppliedSetup(identifier,
            pauseAppliedName)
        pauseAppliedSignal := pauseAppliedName == "" ? ""
            : "        DllCall(" Chr(34) "kernel32\SetEvent" Chr(34)
                . ", " Chr(34) "Ptr" Chr(34) ", __kmra_" identifier
                . "_pause_applied_signal)`r`n"
        pauseAppliedReset := pauseAppliedName == "" ? ""
            : "        DllCall(" Chr(34) "kernel32\ResetEvent" Chr(34)
                . ", " Chr(34) "Ptr" Chr(34) ", __kmra_" identifier
                . "_pause_applied_signal)`r`n"
        prefix := "#Requires AutoHotkey v2.0 64-bit`r`n"
            . "#NoTrayIcon`r`n"
            . "global __kmra_" identifier "_stop := 0`r`n"
            . "global __kmra_" identifier "_pause := 0`r`n"
            . "global __kmra_" identifier "_parent := 0`r`n"
            . "global __kmra_" identifier "_pause_applied_signal := 0`r`n"
            . "global __kmra_" identifier "_manager_paused := false`r`n"
            . "global __kmra_" identifier "_pause_applied := false`r`n"
            . "for __kmra_" identifier "_arg in A_Args {`r`n"
            . "    if __kmra_" identifier "_arg == " Chr(34) syntaxFlag Chr(34)
            . "`r`n        ExitApp(0)`r`n}`r`n"
            . "__kmra_" identifier "_stop := DllCall(" Chr(34)
            . "kernel32\OpenEventW" Chr(34) ", " Chr(34) "UInt" Chr(34)
            . ", 0x00100000, " Chr(34) "Int" Chr(34) ", false, " Chr(34)
            . "WStr" Chr(34) ", " Chr(34) stopName Chr(34) ", " Chr(34)
            . "Ptr" Chr(34) ")`r`n"
            . "__kmra_" identifier "_pause := DllCall(" Chr(34)
            . "kernel32\OpenEventW" Chr(34) ", " Chr(34) "UInt" Chr(34)
            . ", 0x00100000, " Chr(34) "Int" Chr(34) ", false, " Chr(34)
            . "WStr" Chr(34) ", " Chr(34) pauseName Chr(34) ", " Chr(34)
            . "Ptr" Chr(34) ")`r`n"
            . "__kmra_" identifier "_ready := DllCall(" Chr(34)
            . "kernel32\OpenEventW" Chr(34) ", " Chr(34) "UInt" Chr(34)
            . ", 0x0002, " Chr(34) "Int" Chr(34) ", false, " Chr(34)
            . "WStr" Chr(34) ", " Chr(34) readyName Chr(34) ", " Chr(34)
            . "Ptr" Chr(34) ")`r`n"
            . "if !__kmra_" identifier "_stop || !__kmra_" identifier
            . "_pause || !__kmra_" identifier "_ready`r`n    ExitApp(91)`r`n"
            . pauseAppliedSetup
            . jobSetup
            . "__kmra_" identifier "_parent := DllCall(" Chr(34)
            . "kernel32\OpenProcess" Chr(34) ", " Chr(34) "UInt" Chr(34)
            . ", 0x00100000, " Chr(34) "Int" Chr(34) ", false, " Chr(34)
            . "UInt" Chr(34) ", " parentPid ", " Chr(34) "Ptr" Chr(34)
            . ")`r`n"
            . "if !__kmra_" identifier "_parent`r`n    ExitApp(92)`r`n"
            . "__kmra_" identifier "_check(*) {`r`n"
            . "    global __kmra_" identifier "_stop, __kmra_" identifier
            . "_pause, __kmra_" identifier "_parent, __kmra_" identifier
            . "_manager_paused, __kmra_" identifier "_pause_applied, __kmra_"
            . identifier "_pause_applied_signal`r`n"
            . "    if DllCall(" Chr(34) "kernel32\WaitForSingleObject"
            . Chr(34) ", " Chr(34) "Ptr" Chr(34) ", __kmra_" identifier
            . "_stop, " Chr(34) "UInt" Chr(34) ", 0, " Chr(34) "UInt"
            . Chr(34) ") == 0`r`n        ExitApp(0)`r`n"
            . "    if DllCall(" Chr(34) "kernel32\WaitForSingleObject"
            . Chr(34) ", " Chr(34) "Ptr" Chr(34) ", __kmra_" identifier
            . "_parent, " Chr(34) "UInt" Chr(34) ", 0, " Chr(34) "UInt"
            . Chr(34) ") == 0`r`n        ExitApp(0)`r`n"
            . "    shouldPause := DllCall(" Chr(34)
            . "kernel32\WaitForSingleObject" Chr(34) ", " Chr(34) "Ptr"
            . Chr(34) ", __kmra_" identifier "_pause, " Chr(34) "UInt"
            . Chr(34) ", 0, " Chr(34) "UInt" Chr(34) ") == 0`r`n"
            . "    if shouldPause {`r`n"
            . "        if !A_IsSuspended {`r`n"
            . "            Suspend(true)`r`n"
            . "            __kmra_" identifier "_pause_applied := true`r`n"
            . "        }`r`n"
            . "        __kmra_" identifier "_manager_paused := true`r`n"
            . pauseAppliedSignal
            . "    } else if __kmra_" identifier "_manager_paused {`r`n"
            . "        if __kmra_" identifier
            . "_pause_applied && A_IsSuspended`r`n"
            . "            Suspend(false)`r`n"
            . "        __kmra_" identifier "_manager_paused := false`r`n"
            . "        __kmra_" identifier "_pause_applied := false`r`n"
            . pauseAppliedReset
            . "    }`r`n}`r`n"
            . "__kmra_" identifier "_check()`r`n"
            . "DllCall(" Chr(34) "kernel32\SetEvent" Chr(34) ", "
            . Chr(34) "Ptr" Chr(34) ", __kmra_" identifier "_ready)`r`n"
            . "DllCall(" Chr(34) "kernel32\CloseHandle" Chr(34) ", "
            . Chr(34) "Ptr" Chr(34) ", __kmra_" identifier "_ready)`r`n"
            . "SetTimer(__kmra_" identifier "_check, " poll ")`r`n`r`n"
        return prefix . StrReplace(spec["code"], "`n", "`r`n")
            . "`r`n#Warn All, StdOut`r`n"
    }

    BuildWorkerJobSetup(identifier, jobName) {
        if jobName == ""
            return ""
        return "__kmra_" identifier "_job := DllCall(" Chr(34)
            . "kernel32\OpenJobObjectW" Chr(34) ", " Chr(34) "UInt"
            . Chr(34) ", 0x0001, " Chr(34) "Int" Chr(34)
            . ", false, " Chr(34) "WStr" Chr(34) ", " Chr(34)
            . jobName Chr(34) ", " Chr(34) "Ptr" Chr(34) ")`r`n"
            . "if !__kmra_" identifier "_job`r`n    ExitApp(93)`r`n"
            . "__kmra_" identifier "_self := DllCall(" Chr(34)
            . "kernel32\GetCurrentProcess" Chr(34) ", " Chr(34)
            . "Ptr" Chr(34) ")`r`n"
            . "if !DllCall(" Chr(34) "kernel32\AssignProcessToJobObject"
            . Chr(34) ", " Chr(34) "Ptr" Chr(34) ", __kmra_"
            . identifier "_job, " Chr(34) "Ptr" Chr(34) ", __kmra_"
            . identifier "_self, " Chr(34) "Int" Chr(34) ") {`r`n"
            . "    DllCall(" Chr(34) "kernel32\CloseHandle" Chr(34)
            . ", " Chr(34) "Ptr" Chr(34) ", __kmra_" identifier
            . "_job)`r`n    ExitApp(94)`r`n}`r`n"
            . "DllCall(" Chr(34) "kernel32\CloseHandle" Chr(34) ", "
            . Chr(34) "Ptr" Chr(34) ", __kmra_" identifier
            . "_job)`r`n"
    }

    BuildWorkerPauseAppliedSetup(identifier, pauseAppliedName) {
        if pauseAppliedName == ""
            return ""
        return "__kmra_" identifier "_pause_applied_signal := DllCall("
            . Chr(34) "kernel32\OpenEventW" Chr(34) ", " Chr(34) "UInt"
            . Chr(34) ", 0x00100002, " Chr(34) "Int" Chr(34)
            . ", false, " Chr(34) "WStr" Chr(34) ", " Chr(34)
            . pauseAppliedName Chr(34) ", " Chr(34) "Ptr" Chr(34) ")`r`n"
            . "if !__kmra_" identifier
            . "_pause_applied_signal`r`n    ExitApp(95)`r`n"
    }

    WaitForWorkerPauseState(worker, paused, timeoutMilliseconds) {
        if !IsObject(worker) || !worker.HasOwnProp("PauseAppliedHandle")
                || !worker.PauseAppliedHandle
            return true
        started := A_TickCount
        loop {
            waitResult := DllCall("kernel32\WaitForSingleObject", "Ptr",
                worker.PauseAppliedHandle, "UInt", 0, "UInt")
            if paused ? waitResult == 0 : waitResult == 0x00000102
                return true
            if waitResult != 0 && waitResult != 0x00000102
                throw OSError(A_LastError,
                    "无法读取脚本规则暂停确认状态：" worker.Id)
            if worker.HasOwnProp("ProcessHandle") && worker.ProcessHandle
                    && DllCall("kernel32\WaitForSingleObject", "Ptr",
                        worker.ProcessHandle, "UInt", 0, "UInt") == 0
                return false
            if A_TickCount - started >= Max(0, Integer(timeoutMilliseconds))
                return false
            Sleep(10)
        }
    }

    CreateSignal(name, signaled) {
        handle := DllCall("kernel32\CreateEventW", "Ptr", 0, "Int", true,
            "Int", !!signaled, "WStr", name, "Ptr")
        if !handle
            throw OSError(A_LastError, "无法创建脚本规则控制信号。")
        return handle
    }

    CreateWorkerJob(name) {
        handle := DllCall("kernel32\CreateJobObjectW", "Ptr", 0,
            "WStr", name, "Ptr")
        if !handle
            throw OSError(A_LastError, "无法创建脚本规则作业。")
        informationSize := A_PtrSize == 8 ? 144 : 108
        information := Buffer(informationSize, 0)
        ; Managed script instances rejoin explicitly; ordinary programs
        ; launched by user code keep an independent lifetime.
        NumPut("UInt", 0x00003000, information, 16)
        if !DllCall("kernel32\SetInformationJobObject", "Ptr", handle,
                "Int", 9, "Ptr", information.Ptr,
                "UInt", information.Size, "Int") {
            errorCode := A_LastError
            DllCall("kernel32\CloseHandle", "Ptr", handle)
            throw OSError(errorCode, "无法配置脚本规则作业。")
        }
        return handle
    }

    GetWorkerProcessCount(worker) {
        if !IsObject(worker) || !worker.HasOwnProp("JobHandle")
                || !worker.JobHandle
            return worker.HasOwnProp("ProcessId")
                    && worker.ProcessId && ProcessExist(worker.ProcessId)
                ? 1 : 0
        information := Buffer(48, 0)
        bytesWritten := 0
        if !DllCall("kernel32\QueryInformationJobObject",
                "Ptr", worker.JobHandle, "Int", 1,
                "Ptr", information.Ptr, "UInt", information.Size,
                "UInt*", &bytesWritten, "Int")
            throw OSError(A_LastError, "无法读取脚本规则作业状态。")
        if bytesWritten < 44
            throw Error("脚本规则作业状态结构不完整。")
        return NumGet(information, 40, "UInt")
    }

    CloseWorkerHandles(worker) {
        for propertyName in ["StopHandle", "PauseHandle",
                "PauseAppliedHandle", "ReadyHandle", "ProcessHandle",
                "JobHandle"] {
            if !worker.HasOwnProp(propertyName)
                continue
            handle := worker.%propertyName%
            if handle {
                DllCall("kernel32\CloseHandle", "Ptr", handle)
                worker.%propertyName% := 0
            }
        }
        return true
    }

    GetSpecDigest(spec) {
        canonical := JsonCodec.Stringify(ScriptRuleSpec.Normalize(spec),
            false, true)
        return Sha256.HexText(canonical)
    }

    CreateToken(label) {
        labelDigest := SubStr(Sha256.HexText(String(label)), 1, 16)
        return labelDigest "-" DllCall("kernel32\GetCurrentProcessId", "UInt")
            . "-" A_TickCount "-" Format("{:08X}", Random(0, 0xFFFFFFFF))
    }

    EnsureRuntimeDirectory() {
        if !DirExist(this.RuntimeDirectory)
            DirCreate(this.RuntimeDirectory)
        return true
    }

    CleanupRuntimeDirectory() {
        if !DirExist(this.RuntimeDirectory)
            return true
        Loop Files this.RuntimeDirectory "\*.ahk", "F"
            try FileDelete(A_LoopFileFullPath)
        return true
    }

    WriteTextFile(path, text) {
        output := FileOpen(path, "w", "UTF-8-RAW")
        if !IsObject(output)
            throw Error("无法写入脚本规则运行文件。")
        try output.Write(text)
        finally output.Close()
        return true
    }

    ReadDiagnostic(path) {
        if !FileExist(path) || DirExist(path)
            return ""
        input := FileOpen(path, "r")
        if !IsObject(input)
            return ""
        try {
            text := input.Length > ScriptRuleRuntime.MaximumDiagnosticBytes
                ? input.Read(3000) : input.Read()
            text := Trim(text, " `t`r`n")
            return StrLen(text) > 3000 ? SubStr(text, 1, 3000) "..." : text
        } finally input.Close()
    }

    DiagnosticContainsError(diagnostic) {
        return RegExMatch(String(diagnostic),
            "m)^.+\(\d+\)\s*:\s*==>(?![ `t]*Warning:)[ `t]*")
    }

    FindMapping(mappings, ruleId) {
        for mapping in mappings {
            if mapping.Id == ruleId
                return mapping
        }
        return ""
    }

    WorkerWasStopped(stoppedWorkers, ruleId) {
        for item in stoppedWorkers {
            if item.Worker.Id == ruleId
                return true
        }
        return false
    }

    Trace(eventName, fields) {
        try this.App.TraceEvent("runtime", eventName, fields)
    }

    static CloneMapping(mapping, spec) {
        clone := {}
        for propertyName, value in mapping.OwnProps()
            clone.%propertyName% := value
        clone.Spec := RuleSpec.Clone(spec)
        return clone
    }
}
