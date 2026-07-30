#Requires AutoHotkey v2.0 64-bit
#SingleInstance Off
#Warn All, StdOut

#Include ..\TestSupport.ahk
#Include ..\..\src\Core\JsonCodec.ahk
#Include ..\..\src\Core\Sha256.ahk
#Include ..\..\src\Core\CrossProcessWriteLock.ahk
#Include ..\..\src\Core\RuleSpec.ahk
#Include ..\..\src\Core\DiagnosticBundleService.ahk

testRoot := A_Temp "\key-mouse-remapper-assistant-diagnostic-" A_TickCount "-"
    . Format("{:08X}", Random(0, 0xFFFFFFFF))
DirCreate(testRoot)
testFailure := ""
try {
    service := DiagnosticBundleService()
    context := Map("application", Map("script_path",
        "C:\Users\person\private\键鼠重映射小助手.ahk"),
        "window", Map("title", "Confidential document",
            "focused_text", "Sensitive focused control text"),
        "variables", Map("secret", "token"))
    entries := [Map("event", "action_executed", "data", Map(
        "action", Map("type", "text", "value", "private text"),
        "raw_code", "F1::F2"))]
    preview := service.CreatePreview(context, entries)
    serializedBundle := preview.Serialized
    AssertTrue(!InStr(serializedBundle, "Confidential document")
            && !InStr(serializedBundle, "Sensitive focused control text")
            && !InStr(serializedBundle, "private text")
            && !InStr(serializedBundle, "F1::F2")
            && !InStr(serializedBundle, "C:\\Users\\person")
            && preview.Counts["window_titles"] == 1
            && preview.Counts["paths"] == 1
            && preview.Counts["text_actions"] == 2
            && preview.Counts["raw_code"] == 1
            && preview.Counts["variable_values"] == 1,
        "诊断包没有完整脱敏或计数错误")
    parsed := JsonCodec.Parse(serializedBundle)
    AssertTrue(!parsed["privacy"]["raw_mapping_code_included"].Value
            && !parsed["privacy"]["focused_control_text_included"].Value
            && parsed["events"].Length == 1,
        "诊断包隐私声明或事件内容错误")
    exportPath := testRoot "\diagnostic.json"
    service.ExportPreview(preview, exportPath)
    AssertEqual(serializedBundle, FileRead(exportPath, "UTF-8"),
        "诊断包原子导出内容错误")

    cyclicContext := Map("name", "cycle")
    cyclicContext["self"] := cyclicContext
    cyclicPreview := service.CreatePreview(cyclicContext, [])
    AssertTrue(InStr(cyclicPreview.Serialized, "redacted:cycle") > 0,
        "诊断包脱敏没有安全终止循环引用")
    deepValue := Map()
    deepCursor := deepValue
    Loop DiagnosticBundleService.MaximumValueDepth + 2 {
        nextValue := Map()
        deepCursor["next"] := nextValue
        deepCursor := nextValue
    }
    deepRejected := false
    try service.CreatePreview(deepValue, [])
    catch as deepError
        deepRejected := InStr(deepError.Message, "嵌套层级") > 0
    AssertTrue(deepRejected, "诊断包脱敏没有拒绝过深数据")
    WriteTestSuccess("diagnostic-bundle")
} catch as diagnosticError {
    testFailure := diagnosticError.Message "`n" diagnosticError.Stack
} finally {
    if DirExist(testRoot)
        DirDelete(testRoot, true)
}
if testFailure != "" {
    FileAppend(testFailure "`n", "**")
    ExitApp(1)
}
ExitApp(0)
