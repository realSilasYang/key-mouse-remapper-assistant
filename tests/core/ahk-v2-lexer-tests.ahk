#Requires AutoHotkey v2.0 64-bit
#SingleInstance Off
#Warn All, StdOut

#Include ..\..\src\UI\AhkV2Lexer.ahk

ExitApp(RunAhkV2LexerTests() ? 0 : 1)

RunAhkV2LexerTests() {
try {
    source := "
(
#Requires AutoHotkey v2.0
class Worker extends Object {
    static Count := 0x2A
    Run(value := true) => MsgBox("value; still string") ; comment
}
+WheelUp::Send("{WheelLeft}")
:::Send(":")
:X:run::MsgBox("executed")
:*:btw::by the way
retry:
goto destination
item.Length += A_Index
if item contains 42
class Derived extends Namespace.Base
object.Method()
config := {Name: "Codex"}
MsgBox("line``nnext")
FileAppend('single-quoted')
; TODO: verify syntax colors
; looks like a hotkey F24::F23 but remains a comment
)"
    lexer := AhkV2Lexer(source)
    tokens := lexer.GetTokens(, 0, StrLen(source))
    LexerAssertToken(source, tokens, "#Requires", "Directive")
    LexerAssertToken(source, tokens, "AutoHotkey v2.0", "DirectiveValue")
    LexerAssertToken(source, tokens, "class", "Keyword")
    LexerAssertToken(source, tokens, "Worker", "Type")
    LexerAssertToken(source, tokens, "Object", "Type")
    LexerAssertToken(source, tokens, "Count", "Identifier")
    LexerAssertToken(source, tokens, "item", "Identifier")
    LexerAssertToken(source, tokens, "0x2A", "Number")
    LexerAssertToken(source, tokens, "true", "Literal")
    LexerAssertToken(source, tokens, "MsgBox", "Function")
    LexerAssertToken(source, tokens, '"value; still string"',
        "String")
    LexerAssertToken(source, tokens, "; comment", "Comment")
    LexerAssertToken(source, tokens, "+WheelUp::", "Hotkey")
    LexerAssertToken(source, tokens, ":::", "Hotkey")
    LexerAssertToken(source, tokens, ":X:run::", "Hotstring")
    LexerAssertToken(source, tokens, ":*:btw::", "Hotstring")
    LexerAssertToken(source, tokens, "by the way", "String")
    LexerAssertToken(source, tokens, "retry:", "Label")
    LexerAssertToken(source, tokens, "destination", "Label")
    LexerAssertToken(source, tokens, "Length", "Property")
    LexerAssertToken(source, tokens, "A_Index", "Builtin")
    LexerAssertToken(source, tokens, "contains", "Operator")
    LexerAssertToken(source, tokens, "Namespace", "Type")
    LexerAssertToken(source, tokens, "Base", "Type")
    LexerAssertToken(source, tokens, "Method", "Function")
    LexerAssertToken(source, tokens, "Name", "Property")
    LexerAssertToken(source, tokens, "``n", "Escape")
    LexerAssertToken(source, tokens, "'single-quoted'", "String")
    LexerAssertToken(source, tokens, "TODO:", "CommentTag")
    LexerAssertToken(source, tokens,
        "; looks like a hotkey F24::F23 but remains a comment", "Comment")
    LexerAssert(!LexerHasToken(source, tokens, "F24::", "Hotkey"),
        "Hotkey-like text inside a line comment was highlighted as a hotkey.")

    strictSource := "unknown := A_MadeUp`nliteral := null"
        . "`nbinary := 0b1010`nstrict := left === right"
        . "`noptional := left?.Value"
    strictLexer := AhkV2Lexer(strictSource)
    strictTokens := strictLexer.GetTokens(, 0, StrLen(strictSource))
    LexerAssert(!LexerHasToken(strictSource, strictTokens,
            "A_MadeUp", "Builtin"),
        "An unknown A_ variable was misclassified as a built-in variable.")
    LexerAssert(!LexerHasToken(strictSource, strictTokens, "null", "Literal"),
        "The non-AHK null literal was accepted.")
    LexerAssert(!LexerHasToken(strictSource, strictTokens,
            "0b1010", "Number"),
        "The non-AHK binary-number syntax was accepted.")
    LexerAssert(!LexerHasToken(strictSource, strictTokens,
            "===", "Operator"),
        "The non-AHK strict-equality operator was accepted.")
    LexerAssert(!LexerHasToken(strictSource, strictTokens,
            "?.", "Operator"),
        "The non-AHK optional-chain operator was accepted.")

    semicolon := Chr(59)
    boundarySource := "value := left /" . "* right`nvalue" . semicolon
        . "suffix`nvalue " . semicolon . " comment"
    boundaryLexer := AhkV2Lexer(boundarySource)
    boundaryTokens := boundaryLexer.GetTokens(, 0, StrLen(boundarySource))
    LexerAssert(!LexerHasToken(boundarySource, boundaryTokens,
            "/* right", "Comment"),
        "An inline slash-star expression was misclassified as a block comment.")
    LexerAssert(!LexerHasToken(boundarySource, boundaryTokens,
            ";suffix", "Comment"),
        "A semicolon without leading whitespace was treated as a comment.")
    LexerAssertToken(boundarySource, boundaryTokens, "; comment", "Comment")

    blockSource := "value := 1`n/* block`ncomment `; still block */"
        . "`nvalue := 2"
    blockLexer := AhkV2Lexer(blockSource)
    blockTokens := blockLexer.GetTokens(, 0, StrLen(blockSource))
    LexerAssertToken(blockSource, blockTokens, "/* block", "Comment")
    LexerAssertToken(blockSource, blockTokens,
        "comment `; still block */", "Comment")
    LexerAssert(blockLexer.GetLineState(2).Out
            == AhkV2Lexer.StateBlockComment,
        "Block-comment state did not cross the line boundary.")
    LexerAssert(blockLexer.GetLineState(3).Out
            == AhkV2Lexer.StateNormal,
        "Block-comment state did not close on the terminating line.")

    blockBoundarySource := "/* block`nignored */ value := 2"
        . "`nstill ignored`n*/ value := 3`nMsgBox(value)"
    blockBoundaryLexer := AhkV2Lexer(blockBoundarySource)
    LexerAssert(blockBoundaryLexer.GetLineState(2).Out
            == AhkV2Lexer.StateBlockComment
            && blockBoundaryLexer.GetLineState(3).Out
                == AhkV2Lexer.StateBlockComment,
        "A block-comment terminator in the middle of a line closed the block.")
    LexerAssert(blockBoundaryLexer.GetLineState(4).Out
            == AhkV2Lexer.StateNormal,
        "A leading block-comment terminator did not close the block.")

    quote := Chr(34)
    continuationSource := "text := " . quote . "`n(`nliteral `; not a comment"
        . "`n)" . quote . "`nMsgBox(text)"
    continuationLexer := AhkV2Lexer(continuationSource)
    continuationTokens := continuationLexer.GetTokens(, 0,
        StrLen(continuationSource))
    LexerAssertToken(continuationSource, continuationTokens,
        "literal `; not a comment", "String")
    LexerAssert(!LexerHasToken(continuationSource, continuationTokens,
            "; not a comment", "Comment"),
        "Continuation text was misclassified as a comment.")
    LexerAssert(continuationLexer.GetLineState(3).In
            == AhkV2Lexer.StateContinuation,
        "Continuation-section state did not cross the line boundary.")

    commentedContinuationSource := "text := " . quote
        . "`n(Comments`ntext `; comment`n)" . quote
    commentedContinuationLexer := AhkV2Lexer(commentedContinuationSource)
    commentedContinuationTokens := commentedContinuationLexer.GetTokens(,
        0, StrLen(commentedContinuationSource))
    LexerAssert(commentedContinuationLexer.GetLineState(3).In
            == AhkV2Lexer.StateContinuationComments,
        "The Comments option did not produce its own continuation state.")
    LexerAssertToken(commentedContinuationSource,
        commentedContinuationTokens, "; comment", "Comment")

    hotstringContinuationSource := "::signature::`n(`nreplacement`n)"
    hotstringContinuationLexer := AhkV2Lexer(hotstringContinuationSource)
    LexerAssert(hotstringContinuationLexer.GetLineState(3).In
            == AhkV2Lexer.StateContinuation,
        "A multiline replacement hotstring did not enter continuation state.")

    metadataSource := "; @类型=受托管独立脚本`n; @来源按键=LShift / RShift"
        . "`n; @映射结果=左 Shift 中文 / 右 Shift 英文`n; regular comment"
        . "`n;@Ahk2Exe-SetName Assistant"
    metadataLexer := AhkV2Lexer(metadataSource)
    metadataTokens := metadataLexer.GetTokens(, 0, StrLen(metadataSource))
    LexerAssertToken(metadataSource, metadataTokens, "; @类型",
        "MetadataKey")
    LexerAssertToken(metadataSource, metadataTokens, "=受托管独立脚本",
        "MetadataValue")
    LexerAssertToken(metadataSource, metadataTokens, "; @来源按键",
        "MetadataKey")
    LexerAssertToken(metadataSource, metadataTokens, "=LShift / RShift",
        "MetadataValue")
    LexerAssertToken(metadataSource, metadataTokens, "; @映射结果",
        "MetadataKey")
    LexerAssertToken(metadataSource, metadataTokens, "; regular comment",
        "Comment")
    LexerAssertToken(metadataSource, metadataTokens,
        ";@Ahk2Exe-SetName", "Directive")
    LexerAssertToken(metadataSource, metadataTokens,
        " Assistant", "DirectiveValue")

    specSource := "; @mapping-begin`n; @名称=规格测试"
        . "`n; @来源按键=F24`n; @spec-begin`n; {"
        . "`n;   " quote "display" quote ": {`n;     "
        . quote "source" quote ": " quote "F24" quote ","
        . "`n;     " quote "enabled" quote ": true,`n;     "
        . quote "count" quote ": 2"
        . "`n;   }`n; }`n; @spec-end`n; @mapping-end"
    specLexer := AhkV2Lexer(specSource)
    specTokens := specLexer.GetTokens(, 0, StrLen(specSource))
    LexerAssertToken(specSource, specTokens, "; @spec-begin",
        "MetadataKey")
    LexerAssertToken(specSource, specTokens, quote "display" quote,
        "Property")
    LexerAssertToken(specSource, specTokens, quote "source" quote,
        "Property")
    LexerAssertToken(specSource, specTokens, quote "F24" quote, "String")
    LexerAssertToken(specSource, specTokens, "true", "Literal")
    LexerAssertToken(specSource, specTokens, "2", "Number")
    LexerAssertToken(specSource, specTokens, "{", "Punctuation")
    LexerAssertToken(specSource, specTokens, "; @spec-end",
        "MetadataKey")

    scriptBlockSource := "; @mapping-begin`n; @名称=脚本词法测试`n"
        . "; @类型=受托管独立脚本`n; @来源按键=WheelUp`n"
        . "; @映射结果=WheelLeft`n; @生效范围=全局`n`n"
        . "; @script-code-begin`n"
        . ";  #Requires AutoHotkey v2.0`n;  class Worker {`n"
        . ";      Run() => MsgBox('ready')`n;  }`n"
        . ";  +WheelUp::Send(" quote "{WheelLeft}" quote ")`n"
        . Chr(59) "  " Chr(59) " TODO: readable source`n"
        . Chr(59) "  " Chr(59) " @script-code-begin`n"
        . ";  MsgBox('after marker-like comment')`n"
        . "; @script-code-end`n; @mapping-end"
    scriptBlockLexer := AhkV2Lexer(scriptBlockSource)
    scriptBlockTokens := scriptBlockLexer.GetTokens(, 0,
        StrLen(scriptBlockSource))
    LexerAssertToken(scriptBlockSource, scriptBlockTokens,
        "; @名称", "MetadataKey")
    LexerAssertToken(scriptBlockSource, scriptBlockTokens,
        "; @类型", "MetadataKey")
    LexerAssertToken(scriptBlockSource, scriptBlockTokens,
        "=受托管独立脚本", "MetadataValue")
    LexerAssertToken(scriptBlockSource, scriptBlockTokens,
        "#Requires", "Directive")
    LexerAssertToken(scriptBlockSource, scriptBlockTokens,
        "AutoHotkey v2.0", "DirectiveValue")
    LexerAssertToken(scriptBlockSource, scriptBlockTokens, "class", "Keyword")
    LexerAssertToken(scriptBlockSource, scriptBlockTokens, "Worker", "Type")
    LexerAssertToken(scriptBlockSource, scriptBlockTokens, "MsgBox", "Function")
    LexerAssertToken(scriptBlockSource, scriptBlockTokens,
        "+WheelUp::", "Hotkey")
    LexerAssertToken(scriptBlockSource, scriptBlockTokens,
        "TODO:", "CommentTag")
    LexerAssertToken(scriptBlockSource, scriptBlockTokens,
        "'after marker-like comment'", "String")
    LexerAssertToken(scriptBlockSource, scriptBlockTokens,
        "; @script-code-end", "MetadataKey")

    incrementalText := "value := 1`nMsgBox(value)`nreturn"
    incrementalLexer := AhkV2Lexer(incrementalText)
    initialLexed := incrementalLexer.TotalLexedLineCount
    LexerAssert(incrementalLexer.Update(
            "value := 2`nMsgBox(value)`nreturn"),
        "Changed text was not accepted by the incremental lexer.")
    LexerAssert(incrementalLexer.LastRelexedLineCount == 1,
        "A single-line edit re-lexed stable following lines.")
    LexerAssert(incrementalLexer.TotalLexedLineCount == initialLexed + 1,
        "Incremental lexing statistics did not match the changed range.")
    incrementalRange := incrementalLexer.GetLastChangedRange()
    LexerAssert(incrementalRange.Start == 0
            && incrementalRange.End > incrementalRange.Start
            && incrementalRange.End
                < StrLen("value := 2`nMsgBox(value)`nreturn"),
        "A single-line edit reported the whole document as changed.")
    LexerAssert(!incrementalLexer.Update(
            "value := 2`nMsgBox(value)`nreturn")
            && incrementalLexer.LastRelexedLineCount == 0
            && incrementalLexer.GetLastChangedRange().Start == 0
            && incrementalLexer.GetLastChangedRange().End == 0,
        "Unchanged text was lexed repeatedly.")

    statefulText := "text := " . quote . "`n(`n`; none`n)" . quote
        . "`nMsgBox(text)"
    statefulLexer := AhkV2Lexer(statefulText)
    statefulChangedText := StrReplace(statefulText, "`n(`n",
        "`n(Comments`n")
    statefulLexer.Update(statefulChangedText)
    statefulTokens := statefulLexer.GetTokens(, 0,
        StrLen(statefulChangedText))
    LexerAssert(statefulLexer.LastRelexedLineCount == 3,
        "A state change did not stop re-lexing at the first stable line.")
    LexerAssertToken(statefulChangedText, statefulTokens,
        "; none", "Comment")

    largeText := ""
    Loop 7000
        largeText .= (A_Index == 1 ? "" : "`n")
            . "line" . A_Index . ' := Format("{:04}", '
            . A_Index . ")"
    largeLexer := AhkV2Lexer(largeText)
    lines := StrSplit(largeText, "`n")
    lines[3500] := "line3500 := 0xBEEF"
    changedLargeText := LexerJoin(lines, "`n")
    largeLexer.Update(changedLargeText)
    LexerAssert(largeLexer.LastRelexedLineCount == 1,
        "A middle-line edit re-lexed the unchanged large-document suffix.")
    largeChangedRange := largeLexer.GetLastChangedRange()
    LexerAssert(largeChangedRange.Start > 0
            && largeChangedRange.End < StrLen(changedLargeText),
        "A middle-line edit reported the whole large document as changed.")

    FileAppend("PASS AHK v2 lexer`n", "*")
    return true
} catch as testError {
    FileAppend(testError.Message "`n" testError.Stack "`n", "**")
    return false
}
}

LexerAssertToken(source, tokens, text, kind) {
    if LexerHasToken(source, tokens, text, kind)
        return true
    throw Error("Missing " kind " token: " text)
}

LexerHasToken(source, tokens, text, kind) {
    for token in tokens {
        if token.Kind == kind && SubStr(source, token.Start + 1,
                token.End - token.Start) == text
            return true
    }
    return false
}

LexerJoin(values, separator) {
    result := ""
    for index, value in values
        result .= (index == 1 ? "" : separator) value
    return result
}

LexerAssert(value, message) {
    if !value
        throw Error(message)
}
