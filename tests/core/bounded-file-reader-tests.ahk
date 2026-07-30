#Requires AutoHotkey v2.0 64-bit
#SingleInstance Off
#Warn All, StdOut

#Include ..\TestSupport.ahk

testRoot := A_Temp "\key-mouse-remapper-assistant-bounded-read-" A_TickCount "-"
    . Format("{:08X}", Random(0, 0xFFFFFFFF))
DirCreate(testRoot)
testFailure := ""
try {
    exactPath := testRoot "\exact.txt"
    FileAppend("12345678", exactPath, "UTF-8-RAW")
    AssertEqual("12345678", BoundedFileReader.ReadUtf8(exactPath, 8, 8),
        "精确达到上限的 UTF-8 文件无法读取")

    oversizedPath := testRoot "\oversized.txt"
    FileAppend("123456789", oversizedPath, "UTF-8-RAW")
    AssertReadFails(ObjBindMethod(BoundedFileReader, "ReadUtf8"),
        [oversizedPath, 8, 8], "超限 UTF-8 文件未被拒绝")

    multibytePath := testRoot "\multibyte.txt"
    FileAppend("测试", multibytePath, "UTF-8-RAW")
    AssertReadFails(ObjBindMethod(BoundedFileReader, "ReadUtf8"),
        [multibytePath, 5, 2], "多字节 UTF-8 文件绕过了字节上限")

    characterPath := testRoot "\characters.txt"
    FileAppend("abcd", characterPath, "UTF-8-RAW")
    AssertReadFails(ObjBindMethod(BoundedFileReader, "ReadUtf8"),
        [characterPath, 4, 3], "UTF-8 文件绕过了字符上限")

    bomPath := testRoot "\bom.txt"
    bomOutput := FileOpen(bomPath, "w")
    bomOutput.RawWrite(BufferFromBytes([0xEF, 0xBB, 0xBF, 0x6F, 0x6B]))
    bomOutput.Close()
    AssertEqual("ok", BoundedFileReader.ReadUtf8(bomPath, 5, 2),
        "UTF-8 BOM 没有被正确剥离")

    exactBytes := BoundedFileReader.ReadBytes(exactPath, 8)
    AssertEqual(8, exactBytes.Size, "二进制读取返回了错误长度")
    AssertReadFails(ObjBindMethod(BoundedFileReader, "ReadBytes"),
        [oversizedPath, 8], "超限二进制文件未被拒绝")
    AssertReadFails(ObjBindMethod(BoundedFileReader, "ReadBytes"),
        ["NUL", 8], "Windows 设备路径被当作普通磁盘文件读取")

    AssertReadFails(ObjBindMethod(BoundedFileReader, "ReadUtf8"),
        [exactPath, "8", 8], "字符串字节上限被接受")
    AssertReadFails(ObjBindMethod(BoundedFileReader, "ReadUtf8"),
        [exactPath, 8, 8.0], "浮点字符上限被接受")

    invalidUtf8Path := testRoot "\invalid-utf8.txt"
    invalidUtf8Output := FileOpen(invalidUtf8Path, "w")
    invalidUtf8Output.RawWrite(BufferFromBytes([0xC3, 0x28]))
    invalidUtf8Output.Close()
    AssertReadFails(ObjBindMethod(BoundedFileReader, "ReadUtf8"),
        [invalidUtf8Path, 2, 2], "非法 UTF-8 字节序列被接受")

    nulPath := testRoot "\nul.txt"
    nulOutput := FileOpen(nulPath, "w")
    nulOutput.RawWrite(BufferFromBytes([0x61, 0x00, 0x62]))
    nulOutput.Close()
    AssertReadFails(ObjBindMethod(BoundedFileReader, "ReadUtf8"),
        [nulPath, 3, 3], "NUL 字符绕过了文本解析边界")
} catch as testError {
    testFailure := testError.Message "`n" testError.Stack
} finally {
    if DirExist(testRoot)
        try DirDelete(testRoot, true)
}
if testFailure != "" {
    FileAppend(testFailure "`n", "**")
    ExitApp(1)
}
WriteTestSuccess("bounded-file-reader-tests.ahk")
ExitApp(0)

AssertReadFails(callback, arguments, message) {
    failed := false
    try callback.Call(arguments*)
    catch
        failed := true
    AssertTrue(failed, message)
}

BufferFromBytes(values) {
    result := Buffer(values.Length, 0)
    for index, value in values
        NumPut("UChar", value, result, index - 1)
    return result
}
