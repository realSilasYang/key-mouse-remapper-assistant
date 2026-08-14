class AhkV2ScriptValidator {
    static MaximumReportedIssues := 8

    static Validate(source) {
        source := AhkV2ScriptValidator.Canonicalize(source)
        lexer := AhkV2Lexer(source)
        tokens := lexer.GetTokens()
        commentsMasked := AhkV2ScriptValidator.MaskTokens(source, tokens,
            Map("Comment", true, "CommentTag", true))
        executableOnly := AhkV2ScriptValidator.MaskTokens(commentsMasked,
            tokens, Map("String", true, "Escape", true))
        issues := []
        seen := Map()

        if !RegExMatch(executableOnly,
                "im)^[ `t]*Func[ `t]*\([^\r\n)]*\)[ `t]*\{") {
            AhkV2ScriptValidator.CollectPatternIssues(source,
                executableOnly,
                "i)(?<![\p{L}\p{N}_.])Func[ `t`r`n]*\(",
                "AHK v2 不支持 Func(“函数名”)；请直接引用函数对象，例如 OnDown.Bind(...)。",
                "func", issues, seen)
        }

        if !RegExMatch(executableOnly,
                "im)^[ `t]*HasKey[ `t]*\([^\r\n)]*\)[ `t]*\{") {
            AhkV2ScriptValidator.CollectPatternIssues(source,
                executableOnly, "i)\.[ `t`r`n]*HasKey[ `t`r`n]*\(",
                "AHK v2 的 Map 使用 Has(...)，不支持 v1 的 HasKey(...)。",
                "has-key", issues, seen)
        }

        AhkV2ScriptValidator.CollectInvalidHotkeyDownIssues(source,
            commentsMasked, executableOnly, issues, seen)
        if issues.Length
            throw Error("代码包含会在运行时失败的 AHK v1 或无效写法：`n- "
                . AhkV2ScriptValidator.Join(issues, "`n- "))
        return true
    }

    static CollectPatternIssues(source, searchable, pattern, message,
            issueKind, issues, seen) {
        position := 1
        while RegExMatch(searchable, pattern, &match, position) {
            AhkV2ScriptValidator.AddIssue(source, match.Pos(0), message,
                issueKind, issues, seen)
            if issues.Length >= AhkV2ScriptValidator.MaximumReportedIssues
                return
            position := match.Pos(0) + Max(1, match.Len(0))
        }
    }

    static CollectInvalidHotkeyDownIssues(source, commentsMasked,
            executableOnly, issues, seen) {
        position := 1
        pattern := "i)(?<![\p{L}\p{N}_.])Hotkey[ `t`r`n]*\("
        while RegExMatch(executableOnly, pattern, &match, position) {
            openingPosition := InStr(executableOnly, "(", true,
                match.Pos(0))
            argumentEnd := AhkV2ScriptValidator.FindFirstArgumentEnd(
                executableOnly, openingPosition)
            if argumentEnd {
                argument := SubStr(commentsMasked, openingPosition + 1,
                    argumentEnd - openingPosition - 1)
                doubleQuote := Chr(34)
                downSuffixPattern := "i)(?:" doubleQuote "[^"
                    . doubleQuote "\r\n]*[ `t]+down[ `t]*" doubleQuote
                    . "|'[^'\r\n]*[ `t]+down[ `t]*')"
                if RegExMatch(argument, downSuffixPattern) {
                    AhkV2ScriptValidator.AddIssue(source, match.Pos(0),
                        "Hotkey() 的按下热键不能添加 Down 后缀；按下时省略后缀，只有释放热键使用 Up。",
                        "hotkey-down", issues, seen)
                }
            }
            if issues.Length >= AhkV2ScriptValidator.MaximumReportedIssues
                return
            position := match.Pos(0) + Max(1, match.Len(0))
        }
    }

    static FindFirstArgumentEnd(source, openingPosition) {
        if !openingPosition
            return 0
        parentheses := 1
        brackets := 0
        braces := 0
        position := openingPosition + 1
        sourceLength := StrLen(source)
        while position <= sourceLength {
            character := SubStr(source, position, 1)
            switch character {
                case "(":
                    parentheses++
                case ")":
                    parentheses--
                    if parentheses == 0
                        return position
                case "[":
                    brackets++
                case "]":
                    brackets := Max(0, brackets - 1)
                case "{":
                    braces++
                case "}":
                    braces := Max(0, braces - 1)
                case ",":
                    if parentheses == 1 && brackets == 0 && braces == 0
                        return position
            }
            position++
        }
        return 0
    }

    static AddIssue(source, position, message, issueKind, issues, seen) {
        lineNumber := AhkV2ScriptValidator.GetLineNumber(source, position)
        key := issueKind ":" lineNumber
        if seen.Has(key)
            return false
        seen[key] := true
        issues.Push("第 " lineNumber " 行：" message)
        return true
    }

    static GetLineNumber(source, position) {
        lineNumber := 1
        searchPosition := 1
        while (newlinePosition := InStr(source, "`n", true,
                searchPosition)) && newlinePosition < position {
            lineNumber++
            searchPosition := newlinePosition + 1
        }
        return lineNumber
    }

    static MaskTokens(source, tokens, kinds) {
        result := ""
        cursor := 0
        for token in tokens {
            if !kinds.Has(token.Kind) || token.Start < cursor
                continue
            result .= SubStr(source, cursor + 1, token.Start - cursor)
            fragment := SubStr(source, token.Start + 1,
                token.End - token.Start)
            result .= RegExReplace(fragment, "[^\r\n]", " ")
            cursor := token.End
        }
        return result . SubStr(source, cursor + 1)
    }

    static Canonicalize(source) {
        source := StrReplace(String(source), "`r`n", "`n")
        return StrReplace(source, "`r", "`n")
    }

    static Join(values, separator) {
        result := ""
        for value in values
            result .= (result == "" ? "" : separator) String(value)
        return result
    }
}
