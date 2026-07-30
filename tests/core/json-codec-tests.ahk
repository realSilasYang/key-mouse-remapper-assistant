#Requires AutoHotkey v2.0.26 64-bit
#SingleInstance Off
#Warn All, StdOut

#Include ..\TestSupport.ahk
#Include ..\..\src\Core\JsonCodec.ahk

testFailure := ""
try {
    unsorted := Map()
    Loop 2048 {
        index := 2049 - A_Index
        unsorted[Format("key-{:04}", index)] := index
    }
    started := DllCall("kernel32\GetTickCount64", "UInt64")
    encoded := JsonCodec.Stringify(unsorted, false, true)
    elapsed := DllCall("kernel32\GetTickCount64", "UInt64") - started
    AssertTrue(InStr(encoded, '"key-0001":1') == 2
            && InStr(encoded, '"key-2048":2048') > 0
            && elapsed < 2000,
        "JSON 大对象没有按稳定键序高效写出：" elapsed " ms")

    cyclic := Map()
    cyclic["self"] := cyclic
    cycleRejected := false
    try JsonCodec.Stringify(cyclic)
    catch as cycleError
        cycleRejected := InStr(cycleError.Message, "循环") > 0
    AssertTrue(cycleRejected, "JSON 写出器没有拒绝循环引用")

    shared := Map("value", 1)
    sharedEncoded := JsonCodec.Stringify(Map("left", shared,
        "right", shared), false, true)
    AssertTrue(InStr(sharedEncoded, '"left":{"value":1}') > 0
            && InStr(sharedEncoded, '"right":{"value":1}') > 0,
        "JSON 写出器把合法的共享子对象误判为循环")

    nested := []
    cursor := nested
    Loop JsonParser.MaximumDepth + 1 {
        child := []
        cursor.Push(child)
        cursor := child
    }
    depthRejected := false
    try JsonCodec.Stringify(nested)
    catch as depthError
        depthRejected := InStr(depthError.Message, "层级") > 0
    AssertTrue(depthRejected, "JSON 写出器没有限制嵌套深度")

    WriteTestSuccess("json-codec")
} catch as jsonTestError {
    testFailure := jsonTestError.Message "`n" jsonTestError.Stack
}
if testFailure != "" {
    FileAppend(testFailure "`n", "**")
    ExitApp(1)
}
ExitApp(0)
