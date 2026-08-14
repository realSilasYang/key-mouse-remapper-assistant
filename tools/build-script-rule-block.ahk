#Requires AutoHotkey v2.0 64-bit
#SingleInstance Force
#NoTrayIcon
#Warn All, StdOut

#Include ..\src\Core\JsonCodec.ahk
#Include ..\src\Core\RuleSpec.ahk
#Include ..\src\Core\ScriptRuleSpec.ahk
#Include ..\src\Core\RuleCompiler.ahk
#Include ..\src\Core\ScriptRuleCompiler.ahk

if A_Args.Length != 6 {
    FileAppend("Usage: build-script-rule-block <name> <source-file> "
        . "<display-source> <display-target> <output-file> "
        . "<enabled>`n", "**")
    ExitApp(2)
}

builderRuleName := A_Args[1]
builderSourcePath := A_Args[2]
builderDisplaySource := A_Args[3]
builderDisplayTarget := A_Args[4]
builderOutputPath := A_Args[5]
builderEnabled := StrLower(A_Args[6]) != "false"
builderCode := FileRead(builderSourcePath, "UTF-8")
builderSpec := Map(
    "id", builderRuleName,
    "display", Map("source", builderDisplaySource,
        "target", builderDisplayTarget,
        "scope", "全局"),
    "code", builderCode)
if !builderEnabled
    builderSpec["enabled"] := JsonBoolean(false)
builderBlock := ScriptRuleCompiler.BuildBlock(
    ScriptRuleSpec.Normalize(builderSpec))
builderOutput := FileOpen(builderOutputPath, "w", "UTF-8-RAW")
if !IsObject(builderOutput)
    throw Error("无法创建输出文件。")
try builderOutput.Write(builderBlock)
finally builderOutput.Close()
ExitApp(0)
