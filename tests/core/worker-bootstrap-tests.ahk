#Requires AutoHotkey v2.0.26 64-bit
#SingleInstance Off
#Warn All, StdOut

#Include ..\TestSupport.ahk
#Include ..\..\src\Core\JsonCodec.ahk
#Include ..\..\src\Process\WorkerBootstrap.ahk

testRoot := A_Temp "\key-mouse-remapper-assistant-worker-bootstrap-" A_TickCount
    . "-" Format("{:08X}", Random(0, 0xFFFFFFFF))
testFailure := ""
bootstrapVariableNames := ["KMR_IPC_PIPE_ID", "KMR_IPC_SESSION_ID", "KMR_IPC_SECRET",
    "KMR_PARENT_PROCESS_ID", "KMR_WORKER_ERROR_PATH", "KMR_WORKER_ROLE"]
previousBootstrapVariables := Map()
for bootstrapVariableName in bootstrapVariableNames
    previousBootstrapVariables[bootstrapVariableName] := EnvGet(
        bootstrapVariableName)
DirCreate(testRoot)
try {
    sessionId := "0123456789abcdef0123456789abcdef"
    secret := "0123456789abcdef0123456789abcdef"
        . "0123456789abcdef0123456789abcdef"
    bootstrapEnvironment := Map(
        "KMR_IPC_PIPE_ID", "abcdef0123456789abcdef0123456789",
        "KMR_IPC_SESSION_ID", sessionId,
        "KMR_IPC_SECRET", secret,
        "KMR_PARENT_PROCESS_ID", "1234",
        "KMR_WORKER_ERROR_PATH", testRoot "\启动错误.txt",
        "KMR_WORKER_ROLE", "input-worker")
    createdBootstrapPath := WorkerBootstrap.Create(testRoot, "input-worker",
        sessionId, bootstrapEnvironment)
    AssertTrue(FileExist(createdBootstrapPath)
            && FileGetSize(createdBootstrapPath) > 0,
        "没有创建 DPAPI 工作进程启动信封")
    for bootstrapVariableName in bootstrapVariableNames
        EnvSet(bootstrapVariableName, "")
    AssertTrue(WorkerBootstrap.ApplyFromArguments(
        ["--worker-bootstrap", createdBootstrapPath]),
        "启动信封参数没有被应用")
    AssertEqual(sessionId, EnvGet("KMR_IPC_SESSION_ID"),
        "启动信封丢失了会话标识")
    AssertEqual(secret, EnvGet("KMR_IPC_SECRET"),
        "启动信封丢失了认证密钥")
    AssertEqual(testRoot "\启动错误.txt", EnvGet("KMR_WORKER_ERROR_PATH"),
        "启动信封破坏了 Unicode 路径")
    AssertTrue(!FileExist(createdBootstrapPath)
            && !FileExist(createdBootstrapPath ".claimed"),
        "一次性启动信封在成功消费后仍然存在")

    duplicateRejected := false
    try WorkerBootstrap.ApplyFromArguments([
        "--worker-bootstrap", "first", "--worker-bootstrap", "second"])
    catch as duplicateError
        duplicateRejected := InStr(duplicateError.Message, "不能重复") > 0
    AssertTrue(duplicateRejected, "重复的启动信封参数没有被拒绝")

    invalidPath := testRoot "\input-worker-worker-bootstrap-"
        . sessionId ".bin"
    FileAppend("not-dpapi", invalidPath, "UTF-8-RAW")
    invalidRejected := false
    try WorkerBootstrap.LoadAndApply(invalidPath)
    catch
        invalidRejected := true
    AssertTrue(invalidRejected && FileExist(invalidPath),
        "无效启动信封没有被拒绝并恢复原文件")
    WorkerBootstrap.Delete(invalidPath)

    validDocument := Map(
        "schema", WorkerBootstrap.Schema,
        "role", "input-worker",
        "session_id", sessionId,
        "created_at_ms", WorkerBootstrap.UnixTimeMilliseconds(),
        "environment", bootstrapEnvironment)
    for invalidSchema in [1.0, "1"] {
        invalidDocument := JsonCodec.Parse(JsonCodec.Stringify(
            validDocument, false, true))
        invalidDocument["schema"] := invalidSchema
        strictSchemaRejected := false
        try WorkerBootstrap.ValidateDocument(invalidDocument)
        catch
            strictSchemaRejected := true
        AssertTrue(strictSchemaRejected,
            "启动信封接受了非整数 schema 类型")
    }
    for invalidCreatedAt in [1.0, String(validDocument["created_at_ms"])] {
        invalidDocument := JsonCodec.Parse(JsonCodec.Stringify(
            validDocument, false, true))
        invalidDocument["created_at_ms"] := invalidCreatedAt
        strictTimestampRejected := false
        try WorkerBootstrap.ValidateDocument(invalidDocument)
        catch
            strictTimestampRejected := true
        AssertTrue(strictTimestampRejected,
            "启动信封接受了非整数 created_at_ms 类型")
    }
    invalidDocument := JsonCodec.Parse(JsonCodec.Stringify(
        validDocument, false, true))
    invalidDocument["environment"]["KMR_PARENT_PROCESS_ID"] :=
        "4294967296"
    oversizedPidRejected := false
    try WorkerBootstrap.ValidateDocument(invalidDocument)
    catch
        oversizedPidRejected := true
    AssertTrue(oversizedPidRejected, "启动信封接受了超出 UInt32 的父进程标识")

    invalidDocument := JsonCodec.Parse(JsonCodec.Stringify(
        validDocument, false, true))
    invalidDocument["environment"]["KMR_PARENT_PROCESS_ID"] := 1234
    numericEnvironmentRejected := false
    try WorkerBootstrap.ValidateDocument(invalidDocument)
    catch
        numericEnvironmentRejected := true
    AssertTrue(numericEnvironmentRejected,
        "启动信封接受了非字符串环境变量值")

    oversizedEnvironment := Map()
    for name, value in bootstrapEnvironment
        oversizedEnvironment[name] := value
    Loop 4
        oversizedEnvironment["KMR_PADDING_" A_Index] := Format("{:32768}", "x")
    oversizedEnvelopeRejected := false
    try WorkerBootstrap.Create(testRoot, "input-worker", sessionId,
        oversizedEnvironment)
    catch as oversizedEnvelopeError
        oversizedEnvelopeRejected := InStr(oversizedEnvelopeError.Message,
            "大小上限") > 0
    AssertTrue(oversizedEnvelopeRejected,
        "创建端写出了自身读取端无法接受的超大启动信封")
    WriteTestSuccess("worker-bootstrap")
} catch as bootstrapTestError {
    testFailure := bootstrapTestError.Message "`n" bootstrapTestError.Stack
} finally {
    for bootstrapVariableName, previousBootstrapValue
            in previousBootstrapVariables
        EnvSet(bootstrapVariableName, previousBootstrapValue)
    if DirExist(testRoot)
        DirDelete(testRoot, true)
}
if testFailure != "" {
    FileAppend(testFailure "`n", "**")
    ExitApp(1)
}
ExitApp(0)
