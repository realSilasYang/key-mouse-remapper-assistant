#Requires AutoHotkey v2.0 64-bit
#SingleInstance Off
#Warn All, StdOut

#Include ..\TestSupport.ahk
#Include ..\..\src\Platform\PackagedLauncher.ahk

testRoot := A_Temp "\key-mouse-remapper-assistant-launcher-" A_TickCount "-"
    . Format("{:08X}", Random(0, 0xFFFFFFFF))
DirCreate(testRoot)
testFile := testRoot "\abc.bin"

try {
    FileAppend("abc", testFile, "UTF-8-RAW")
    AssertEqual(
        "BA7816BF8F01CFEA414140DE5DAE2223B00361A396177A9CB410FF61F20015AD",
        ComputeFileSha256(testFile), "CNG 文件 SHA-256 结果错误")
    sizeRejected := false
    try ComputeFileSha256(testFile, 2)
    catch
        sizeRejected := true
    AssertTrue(sizeRejected, "运行时摘要校验没有执行预读大小限制")
    AssertTrue(InStr(GetPackagedRuntimeSha256(), "PACKAGED_RUNTIME"),
        "工作源码中的运行时摘要占位符被意外改写")
    WriteTestSuccess("packaged-launcher")
} finally {
    if DirExist(testRoot)
        DirDelete(testRoot, true)
}
ExitApp(0)
