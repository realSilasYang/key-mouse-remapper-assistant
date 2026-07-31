#Requires AutoHotkey v2.0 64-bit
#SingleInstance Off
#Warn All, StdOut

#Include ..\TestSupport.ahk
#Include ..\..\src\Core\JsonCodec.ahk
#Include ..\..\src\Core\Sha256.ahk
#Include ..\..\src\Core\CrossProcessWriteLock.ahk
#Include ..\..\src\Core\RuleSpec.ahk
#Include ..\..\src\Core\ScopedVariableStore.ahk

testRoot := A_Temp "\key-mouse-remapper-assistant-variables-" A_TickCount "-"
    . Format("{:08X}", Random(0, 0xFFFFFFFF))
DirCreate(testRoot)
testFailure := ""
try {
    variablePath := testRoot "\variables.json"
    store := ScopedVariableStore("  " variablePath "  ")
    AssertEqual(CrossProcessWriteLock.NormalizePath(variablePath),
        store.FilePath, "持久变量路径没有在构造时规范化")
    store.Set("mode", "persistent-value", "persistent")
    store.Set("mode", "transient-value")
    store.Set("theme", "persistent-value", "persistent")
    variableContext := store.BuildContext(Map("administrator",
        JsonBoolean(true)))
    AssertTrue(variableContext["mode"] == "transient-value"
            && variableContext["transient.mode"] == "transient-value"
            && variableContext["persistent.mode"] == "persistent-value"
            && variableContext["persistent.theme"] == "persistent-value"
            && variableContext["builtin.administrator"].Value,
        "变量作用域、兼容扁平视图或内建变量错误")
    AssertTrue(store.Clear("mode", "transient"), "瞬时变量无法清除")
    fallbackContext := store.BuildContext()
    AssertEqual("persistent-value", fallbackContext["mode"],
        "清除高优先级作用域后没有回退持久变量")
    reloadedStore := ScopedVariableStore(variablePath)
    AssertEqual("persistent-value",
        reloadedStore.BuildContext()["theme"],
        "持久变量重启后丢失")
    concurrentStore := ScopedVariableStore(variablePath)
    store.Set("first-writer", 1, "persistent")
    concurrentStore.Set("second-writer", 2, "persistent")
    mergedStore := ScopedVariableStore(variablePath)
    mergedPersistent := mergedStore.GetPersistentSnapshot()
    AssertTrue(mergedPersistent["first-writer"] == 1
            && mergedPersistent["second-writer"] == 2,
        "两个持久变量存储实例发生顺序丢更新")
    builtinRejected := false
    try store.Set("builtin.administrator", false)
    catch
        builtinRejected := true
    AssertTrue(builtinRejected, "只读 builtin 变量可以被写入")
    unsupportedScopeRejected := false
    try store.Set("x", 1, "global")
    catch
        unsupportedScopeRejected := true
    AssertTrue(unsupportedScopeRejected, "未知变量作用域未被拒绝")
    removedScopeRejected := false
    try store.ClearScope("profile")
    catch
        removedScopeRejected := true
    AssertTrue(removedScopeRejected, "已移除的档案变量作用域仍可清理")
    unconfiguredStore := ScopedVariableStore()
    unconfiguredPersistenceRejected := false
    try unconfiguredStore.Set("x", 1, "persistent")
    catch as unconfiguredError
        unconfiguredPersistenceRejected := InStr(unconfiguredError.Message,
            "未配置持久变量文件") > 0
    AssertTrue(unconfiguredPersistenceRejected,
        "未配置文件的变量存储没有明确拒绝 persistent 写入")
    corruptVariablePath := testRoot "\corrupt-variables.json"
    corruptVariableText := "{broken persistent variables"
    FileAppend(corruptVariableText, corruptVariablePath, "UTF-8-RAW")
    corruptStore := ScopedVariableStore(corruptVariablePath)
    corruptMutationRejected := false
    try corruptStore.Set("must-not-overwrite", 1, "persistent")
    catch
        corruptMutationRejected := true
    AssertTrue(corruptMutationRejected
            && FileRead(corruptVariablePath, "UTF-8") == corruptVariableText,
        "损坏的持久变量文件被后续变量动作静默覆盖")

    malformedSchemaPath := testRoot "\string-schema-variables.json"
    AssertMalformedVariableDocumentRejected(malformedSchemaPath, Map(
        "schema", "1", "values", Map("unsafe", 1)))
    extraFieldPath := testRoot "\extra-field-variables.json"
    AssertMalformedVariableDocumentRejected(extraFieldPath, Map(
        "schema", ScopedVariableStore.Schema,
        "values", Map("unsafe", 1), "ignored", true))
    WriteTestSuccess("scoped-variable-store")
} catch as variableTestError {
    testFailure := variableTestError.Message "`n" variableTestError.Stack
} finally {
    if DirExist(testRoot)
        DirDelete(testRoot, true)
}
if testFailure != "" {
    FileAppend(testFailure "`n", "**")
    ExitApp(1)
}
ExitApp(0)

AssertMalformedVariableDocumentRejected(path, document) {
    FileAppend(JsonCodec.Stringify(document, false, true), path,
        "UTF-8-RAW")
    malformedStore := ScopedVariableStore(path)
    AssertTrue(malformedStore.LoadWarning != ""
            && malformedStore.GetPersistentSnapshot().Count == 0,
        "畸形持久变量文档被接受")
    mutationRejected := false
    try malformedStore.Set("must-not-overwrite", 1, "persistent")
    catch
        mutationRejected := true
    AssertTrue(mutationRejected,
        "畸形持久变量文档可被持久变量动作覆盖")
}
