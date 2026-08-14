class AhkV2Lexer {
    static StateNormal := "normal"
    static StateBlockComment := "block-comment"
    static StatePendingContinuation := "pending-continuation"
    static StateContinuation := "continuation"
    static StateContinuationComments := "continuation-comments"
    static StateSpecJson := "spec-json"
    static StateScriptCodePrefix := "script-code:"

    __New(text := "") {
        this.Text := ""
        this.Lines := []
        this.LastRelexedLineCount := 0
        this.TotalLexedLineCount := 0
        this.LastChangedStart := 0
        this.LastChangedEnd := 0
        this.Update(text)
    }

    Update(text) {
        text := this.Canonicalize(text)
        if text == this.Text && this.Lines.Length {
            this.LastRelexedLineCount := 0
            this.LastChangedStart := 0
            this.LastChangedEnd := 0
            return false
        }

        newLines := this.SplitLines(text)
        oldLines := this.Lines
        oldCount := oldLines.Length
        newCount := newLines.Length
        prefixCount := 0
        commonLimit := Min(oldCount, newCount)
        while prefixCount < commonLimit
                && oldLines[prefixCount + 1].Text
                    == newLines[prefixCount + 1].Text
            prefixCount++

        suffixCount := 0
        while suffixCount < oldCount - prefixCount
                && suffixCount < newCount - prefixCount
                && oldLines[oldCount - suffixCount].Text
                    == newLines[newCount - suffixCount].Text
            suffixCount++

        nextLines := []
        Loop prefixCount
            nextLines.Push(this.ReuseLine(oldLines[A_Index],
                newLines[A_Index].Start))

        state := prefixCount ? oldLines[prefixCount].StateOut
            : AhkV2Lexer.StateNormal
        newSuffixStart := newCount - suffixCount + 1
        oldSuffixStart := oldCount - suffixCount + 1
        lineIndex := prefixCount + 1
        relexed := 0
        while lineIndex <= newCount {
            if suffixCount && lineIndex >= newSuffixStart {
                oldIndex := oldSuffixStart + lineIndex - newSuffixStart
                oldLine := oldLines[oldIndex]
                if state == oldLine.StateIn {
                    while lineIndex <= newCount {
                        oldIndex := oldSuffixStart
                            + lineIndex - newSuffixStart
                        nextLines.Push(this.ReuseLine(oldLines[oldIndex],
                            newLines[lineIndex].Start))
                        lineIndex++
                    }
                    break
                }
            }
            entry := this.LexLine(newLines[lineIndex].Text, state)
            entry.Start := newLines[lineIndex].Start
            nextLines.Push(entry)
            state := entry.StateOut
            relexed++
            lineIndex++
        }

        this.Text := text
        this.Lines := nextLines
        this.LastRelexedLineCount := relexed
        this.TotalLexedLineCount += relexed
        firstChangedLine := prefixCount + 1
        this.LastChangedStart := firstChangedLine <= nextLines.Length
            ? nextLines[firstChangedLine].Start : StrLen(text)
        if relexed {
            lastChangedLine := firstChangedLine + relexed - 1
            this.LastChangedEnd := lastChangedLine < nextLines.Length
                ? nextLines[lastChangedLine + 1].Start : StrLen(text)
        } else
            this.LastChangedEnd := this.LastChangedStart
        return true
    }

    GetLastChangedRange() {
        return {Start: this.LastChangedStart, End: this.LastChangedEnd}
    }

    GetTokens(text?, rangeStart := 0, rangeEnd := -1) {
        if IsSet(text)
            this.Update(text)
        textLength := StrLen(this.Text)
        rangeStart := Max(0, Min(textLength, Integer(rangeStart)))
        if rangeEnd < 0
            rangeEnd := textLength
        rangeEnd := Max(rangeStart, Min(textLength, Integer(rangeEnd)))
        result := []
        if rangeEnd <= rangeStart || !this.Lines.Length
            return result
        lineIndex := this.FindLineIndex(rangeStart)
        while lineIndex <= this.Lines.Length {
            line := this.Lines[lineIndex]
            if line.Start > rangeEnd
                break
            for token in line.Tokens {
                startPosition := line.Start + token.Start
                endPosition := line.Start + token.End
                if endPosition <= rangeStart
                    continue
                if startPosition >= rangeEnd
                    break
                result.Push({Start: Max(rangeStart, startPosition),
                    End: Min(rangeEnd, endPosition), Kind: token.Kind})
            }
            lineIndex++
        }
        return result
    }

    GetLineState(lineNumber) {
        if lineNumber < 1 || lineNumber > this.Lines.Length
            return ""
        line := this.Lines[lineNumber]
        return {In: line.StateIn, Out: line.StateOut}
    }

    FindLineIndex(position) {
        low := 1
        high := this.Lines.Length
        result := 1
        while low <= high {
            middle := Floor((low + high) / 2)
            if this.Lines[middle].Start <= position {
                result := middle
                low := middle + 1
            } else
                high := middle - 1
        }
        return result
    }

    SplitLines(text) {
        lines := []
        textLength := StrLen(text)
        startPosition := 1
        loop {
            newlinePosition := InStr(text, "`n", true, startPosition)
            if !newlinePosition {
                lines.Push({Start: startPosition - 1,
                    Text: SubStr(text, startPosition)})
                break
            }
            lines.Push({Start: startPosition - 1,
                Text: SubStr(text, startPosition,
                    newlinePosition - startPosition)})
            startPosition := newlinePosition + 1
            if startPosition == textLength + 1 {
                lines.Push({Start: textLength, Text: ""})
                break
            }
        }
        return lines
    }

    ReuseLine(line, startPosition) {
        return {Start: startPosition, Text: line.Text,
            StateIn: line.StateIn, StateOut: line.StateOut,
            Tokens: line.Tokens}
    }

    LexLine(line, stateIn, updatePersistenceState := true) {
        tokens := []
        state := stateIn
        position := 1
        lineLength := StrLen(line)

        if this.IsScriptCodeState(stateIn) {
            if line == "; @script-code-end" {
                state := AhkV2Lexer.StateNormal
                this.TryLexMetadata(line, tokens, &state)
                return this.CreateLine(line, stateIn, state, tokens)
            }
            return this.LexScriptCodeLine(line, stateIn)
        }

        if state == AhkV2Lexer.StatePendingContinuation {
            if RegExMatch(line, "^[ `t]*\(", &continuationStart) {
                continuationState := this.ContinuationAllowsComments(line)
                    ? AhkV2Lexer.StateContinuationComments
                    : AhkV2Lexer.StateContinuation
                commentStart := this.FindLineCommentStart(line,
                    continuationStart.Pos(0))
                contentEnd := commentStart ? commentStart : lineLength + 1
                this.AddStringTokens(tokens, line,
                    continuationStart.Pos(0), contentEnd)
                if commentStart
                    this.AddCommentTokens(tokens, line, commentStart - 1,
                        lineLength)
                return this.CreateLine(line, stateIn,
                    continuationState, tokens)
            }
            state := AhkV2Lexer.StateNormal
        }

        if state == AhkV2Lexer.StateContinuation
                || state == AhkV2Lexer.StateContinuationComments {
            if RegExMatch(line, "^[ `t]*\)(?:[ `t]*['\x22])?",
                    &continuationEnd) {
                this.AddToken(tokens, 0, continuationEnd.Len(0), "String")
                position := continuationEnd.Len(0) + 1
                state := AhkV2Lexer.StateNormal
            } else {
                this.LexContinuationContent(line, tokens,
                    state == AhkV2Lexer.StateContinuationComments)
                return this.CreateLine(line, stateIn, state, tokens)
            }
        }

        if state == AhkV2Lexer.StateBlockComment {
            commentEnd := this.FindBlockCommentEnd(line, position)
            if !commentEnd {
                this.AddCommentTokens(tokens, line, position - 1,
                    lineLength)
                return this.CreateLine(line, stateIn, state, tokens)
            }
            nextPosition := commentEnd + 2
            this.AddCommentTokens(tokens, line, position - 1,
                nextPosition - 1)
            position := nextPosition
            state := AhkV2Lexer.StateNormal
        }

        if state == AhkV2Lexer.StateSpecJson {
            if this.TryLexMetadata(line, tokens, &state,
                    updatePersistenceState)
                return this.CreateLine(line, stateIn, state, tokens)
            this.LexSpecJsonComment(line, tokens)
            return this.CreateLine(line, stateIn, state, tokens)
        }

        if position == 1 {
            if this.TryLexBlockCommentStart(line, tokens, &position,
                    &state) && state == AhkV2Lexer.StateBlockComment
                return this.CreateLine(line, stateIn, state, tokens)
            if this.TryLexMetadata(line, tokens, &state,
                    updatePersistenceState)
                return this.CreateLine(line, stateIn, state, tokens)
            leadingPosition := this.NextNonWhitespacePosition(line, 1)
            if leadingPosition
                    && SubStr(line, leadingPosition, 1) == ";"
                    && this.IsLineCommentStart(line, leadingPosition) {
                this.AddCommentTokens(tokens, line,
                    leadingPosition - 1, lineLength)
                return this.CreateLine(line, stateIn, state, tokens)
            }
            leading := this.LexLeadingConstruct(line, tokens)
            position := leading.Position
            if leading.Kind == "Hotstring" && !leading.Execute {
                commentStart := this.FindLineCommentStart(line, position)
                replacementEnd := commentStart ? commentStart
                    : lineLength + 1
                if replacementEnd > position
                    this.AddStringTokens(tokens, line, position,
                        replacementEnd)
                if commentStart
                    this.AddCommentTokens(tokens, line, commentStart - 1,
                        lineLength)
                if Trim(SubStr(line, position,
                        replacementEnd - position), " `t") == ""
                    state := AhkV2Lexer.StatePendingContinuation
                return this.CreateLine(line, stateIn, state, tokens)
            }
        }

        expectType := false
        expectLabel := false
        while position <= lineLength {
            character := SubStr(line, position, 1)
            if character == " " || character == "`t" {
                position++
                continue
            }
            if character == ";" && this.IsLineCommentStart(line, position) {
                this.AddCommentTokens(tokens, line, position - 1,
                    lineLength)
                break
            }
            if character == Chr(34) || character == "'" {
                position := this.LexQuotedString(line, position, tokens,
                    &closed)
                if !closed
                    state := AhkV2Lexer.StatePendingContinuation
                continue
            }
            if this.IsNumberStart(line, position)
                    && RegExMatch(SubStr(line, position),
                        "i)^(?:0x[0-9a-f]+|\d+(?:\.\d*)?"
                        . "(?:e[+-]?\d+)?|\.\d+(?:e[+-]?\d+)?)",
                        &numberMatch) {
                tokenEnd := position + numberMatch.Len(0) - 1
                this.AddToken(tokens, position - 1, tokenEnd, "Number")
                position := tokenEnd + 1
                expectType := false
                expectLabel := false
                continue
            }
            if RegExMatch(SubStr(line, position),
                    "^[\p{L}_][\p{L}\p{N}_]*", &identifierMatch) {
                identifier := identifierMatch[0]
                tokenEnd := position + identifierMatch.Len(0) - 1
                kind := expectLabel ? "Label"
                    : this.ClassifyIdentifier(line, position, tokenEnd,
                        identifier, expectType)
                this.AddToken(tokens, position - 1, tokenEnd, kind)
                lowerName := StrLower(identifier)
                nextPosition := this.NextNonWhitespacePosition(line,
                    tokenEnd + 1)
                continuesType := expectType && nextPosition
                    && SubStr(line, nextPosition, 1) == "."
                expectType := lowerName == "class"
                    || lowerName == "extends" || lowerName == "is"
                    || lowerName == "catch" || continuesType
                expectLabel := lowerName == "goto" || lowerName == "break"
                    || lowerName == "continue"
                position := tokenEnd + 1
                continue
            }
            operator := this.MatchOperator(line, position)
            if operator != "" {
                tokenEnd := position + StrLen(operator) - 1
                this.AddToken(tokens, position - 1, tokenEnd, "Operator")
                position := tokenEnd + 1
                continue
            }
            if InStr("()[]{} ,", character) {
                if character != " "
                    this.AddToken(tokens, position - 1, position,
                        "Punctuation")
                position++
                continue
            }
            if character == Chr(96) {
                tokenEnd := Min(lineLength, position + 1)
                this.AddToken(tokens, position - 1, tokenEnd, "Escape")
                position := tokenEnd + 1
                continue
            }
            position++
        }
        return this.CreateLine(line, stateIn, state, tokens)
    }

    TryLexBlockCommentStart(line, tokens, &position, &state) {
        if !RegExMatch(line, "^[ `t]*/\*", &blockStart)
            return false
        commentStart := InStr(line, "/*", true, blockStart.Pos(0))
        commentEnd := this.FindBlockCommentEnd(line, commentStart + 2)
        if !commentEnd {
            this.AddCommentTokens(tokens, line, commentStart - 1,
                StrLen(line))
            position := StrLen(line) + 1
            state := AhkV2Lexer.StateBlockComment
            return true
        }
        position := commentEnd + 2
        this.AddCommentTokens(tokens, line, commentStart - 1,
            position - 1)
        state := AhkV2Lexer.StateNormal
        return true
    }

    FindBlockCommentEnd(line, startPosition := 1) {
        if RegExMatch(line, "^[ `t]*\*/", &leadingEnd) {
            position := InStr(line, "*/", true, leadingEnd.Pos(0))
            if position >= startPosition
                return position
        }
        if RegExMatch(line, "\*/[ `t]*$", &trailingEnd)
                && trailingEnd.Pos(0) >= startPosition
            return trailingEnd.Pos(0)
        return 0
    }

    LexQuotedString(line, position, tokens, &closed) {
        lineLength := StrLen(line)
        segmentStart := position
        quote := SubStr(line, position, 1)
        escapeCharacter := Chr(96)
        closed := false
        position++
        while position <= lineLength {
            character := SubStr(line, position, 1)
            if character == escapeCharacter {
                this.AddToken(tokens, segmentStart - 1, position - 1,
                    "String")
                escapeEnd := Min(lineLength, position + 1)
                this.AddToken(tokens, position - 1, escapeEnd, "Escape")
                position := escapeEnd + 1
                segmentStart := position
                continue
            }
            if character == quote {
                position++
                this.AddToken(tokens, segmentStart - 1, position - 1,
                    "String")
                closed := true
                return position
            }
            position++
        }
        this.AddToken(tokens, segmentStart - 1, lineLength, "String")
        return lineLength + 1
    }

    AddStringTokens(tokens, line, startPosition, endPosition) {
        segmentStart := startPosition
        position := startPosition
        escapeCharacter := Chr(96)
        while position < endPosition {
            if SubStr(line, position, 1) != escapeCharacter {
                position++
                continue
            }
            this.AddToken(tokens, segmentStart - 1, position - 1,
                "String")
            escapeEnd := Min(endPosition, position + 2)
            this.AddToken(tokens, position - 1, escapeEnd - 1, "Escape")
            position := escapeEnd
            segmentStart := position
        }
        this.AddToken(tokens, segmentStart - 1, endPosition - 1,
            "String")
    }

    LexContinuationContent(line, tokens, commentsEnabled) {
        lineLength := StrLen(line)
        commentStart := commentsEnabled
            ? this.FindLineCommentStart(line) : 0
        contentEnd := commentStart ? commentStart : lineLength + 1
        this.AddStringTokens(tokens, line, 1, contentEnd)
        if commentStart
            this.AddCommentTokens(tokens, line, commentStart - 1,
                lineLength)
    }

    ContinuationAllowsComments(line) {
        openingPosition := InStr(line, "(", true)
        if !openingPosition
            return false
        options := SubStr(line, openingPosition + 1)
        return RegExMatch(options,
            "i)(?:^|[ `t])c(?:om(?:ments?)?)?(?=[ `t;]|$)")
    }

    TryLexMetadata(line, tokens, &state, updatePersistenceState := true) {
        if !RegExMatch(line,
                "^([ `t]*;[ `t]*)(@[\p{L}\p{N}_-]+)(=)?(.*)$", &match)
            return false
        semicolonPosition := InStr(match[1], ";")
        keyStart := semicolonPosition - 1
        keyEnd := match.Pos(2) - 1 + match.Len(2)
        compilerDirective := this.IsCompilerDirective(match[2])
        this.AddToken(tokens, keyStart, keyEnd,
            compilerDirective ? "Directive" : "MetadataKey")
        if match[3] != "" {
            valueStart := match.Pos(3) - 1
            this.AddToken(tokens, valueStart, StrLen(line),
                compilerDirective ? "DirectiveValue" : "MetadataValue")
        } else if keyEnd < StrLen(line) {
            this.AddToken(tokens, keyEnd, StrLen(line),
                compilerDirective ? "DirectiveValue" : "Comment")
        }
        lowerKey := StrLower(String(match[2]))
        if !updatePersistenceState
            return true
        if lowerKey == "@spec-begin"
            state := AhkV2Lexer.StateSpecJson
        else if lowerKey == "@spec-end"
            state := AhkV2Lexer.StateNormal
        else if lowerKey == "@script-code-begin"
            state := AhkV2Lexer.StateScriptCodePrefix
                . AhkV2Lexer.StateNormal
        return true
    }

    IsScriptCodeState(state) {
        return SubStr(state, 1, StrLen(AhkV2Lexer.StateScriptCodePrefix))
            == AhkV2Lexer.StateScriptCodePrefix
    }

    LexScriptCodeLine(line, stateIn) {
        tokens := []
        innerState := SubStr(stateIn,
            StrLen(AhkV2Lexer.StateScriptCodePrefix) + 1)
        if !RegExMatch(line, "^([ `t]*;  )(.*)$", &prefixMatch) {
            this.AddCommentTokens(tokens, line, 0, StrLen(line))
            return this.CreateLine(line, stateIn, stateIn, tokens)
        }
        contentStart := prefixMatch.Pos(2) - 1
        this.AddCommentTokens(tokens, line, 0, contentStart)
        innerLine := prefixMatch[2]
        innerEntry := this.LexLine(innerLine, innerState, false)
        for token in innerEntry.Tokens
            this.AddToken(tokens, token.Start + contentStart,
                token.End + contentStart, token.Kind)
        stateOut := AhkV2Lexer.StateScriptCodePrefix
            . innerEntry.StateOut
        return this.CreateLine(line, stateIn, stateOut, tokens)
    }

    LexSpecJsonComment(line, tokens) {
        if !RegExMatch(line, "^([ `t]*;[ `t]*)(.*)$", &prefixMatch) {
            this.AddCommentTokens(tokens, line, 0, StrLen(line))
            return false
        }
        jsonStart := prefixMatch.Pos(2)
        if jsonStart > 1
            this.AddCommentTokens(tokens, line, 0, jsonStart - 1)
        position := jsonStart
        lineLength := StrLen(line)
        while position <= lineLength {
            character := SubStr(line, position, 1)
            if character == " " || character == "`t" {
                position++
                continue
            }
            if character == Chr(34) {
                startPosition := position
                position++
                while position <= lineLength {
                    character := SubStr(line, position, 1)
                    if character == Chr(92) {
                        position += 2
                        continue
                    }
                    position++
                    if character == Chr(34)
                        break
                }
                nextPosition := this.NextNonWhitespacePosition(line,
                    position)
                kind := nextPosition && SubStr(line, nextPosition, 1) == ":"
                    ? "Property" : "String"
                this.AddToken(tokens, startPosition - 1, position - 1, kind)
                continue
            }
            remaining := SubStr(line, position)
            if RegExMatch(remaining,
                    "^-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?",
                    &numberMatch) {
                tokenEnd := position + numberMatch.Len(0) - 1
                this.AddToken(tokens, position - 1, tokenEnd, "Number")
                position := tokenEnd + 1
                continue
            }
            if RegExMatch(remaining, "^(?:true|false|null)\b",
                    &literalMatch) {
                tokenEnd := position + literalMatch.Len(0) - 1
                this.AddToken(tokens, position - 1, tokenEnd, "Literal")
                position := tokenEnd + 1
                continue
            }
            if InStr("{}[],:", character, true) {
                this.AddToken(tokens, position - 1, position,
                    "Punctuation")
                position++
                continue
            }
            startPosition := position
            while position <= lineLength {
                character := SubStr(line, position, 1)
                if character == " " || character == "`t"
                        || character == Chr(34)
                        || InStr("{}[],:", character, true)
                    break
                position++
            }
            this.AddToken(tokens, startPosition - 1, position - 1,
                "Comment")
        }
        return true
    }

    IsCompilerDirective(key) {
        lowerKey := StrLower(String(key))
        if SubStr(lowerKey, 1, 9) == "@ahk2exe-"
                || SubStr(lowerKey, 1, 7) == "@debug-"
            return true
        return AhkV2Lexer.CompilerDirectives().Has(lowerKey)
    }

    LexLeadingConstruct(line, tokens) {
        if RegExMatch(line, "^[ `t]*(#[A-Za-z][A-Za-z0-9]*)",
                &directive) {
            startPosition := directive.Pos(1) - 1
            endPosition := startPosition + directive.Len(1)
            this.AddToken(tokens, startPosition, endPosition, "Directive")
            if AhkV2Lexer.RawValueDirectives().Has(
                    StrLower(directive[1])) {
                valueStart := this.NextNonWhitespacePosition(line,
                    endPosition + 1)
                commentStart := this.FindLineCommentStart(line,
                    endPosition + 1)
                valueEnd := commentStart ? commentStart - 1 : StrLen(line)
                if valueStart && valueEnd >= valueStart
                    this.AddToken(tokens, valueStart - 1, valueEnd,
                        "DirectiveValue")
                if commentStart
                    this.AddCommentTokens(tokens, line, commentStart - 1,
                        StrLen(line))
                return {Position: StrLen(line) + 1, Kind: "Directive",
                    Execute: false}
            }
            return {Position: endPosition + 1, Kind: "Directive",
                Execute: false}
        }

        escapeCharacter := Chr(96)
        hotstringPattern := "^[ `t]*(:([^:\r\n]*):((?:"
            . escapeCharacter . ".|[^:\r\n])*?)::)"
        if RegExMatch(line, hotstringPattern, &hotstringMatch) {
            startPosition := hotstringMatch.Pos(1) - 1
            endPosition := startPosition + hotstringMatch.Len(1)
            this.AddToken(tokens, startPosition, endPosition, "Hotstring")
            return {Position: endPosition + 1, Kind: "Hotstring",
                Execute: RegExMatch(hotstringMatch[2], "i)x(?!0)")}
        }

        leadingStart := this.NextNonWhitespacePosition(line, 1)
        separatorPosition := leadingStart
            ? this.FindHotkeySeparator(line, leadingStart) : 0
        if separatorPosition > leadingStart {
            endPosition := separatorPosition + 1
            this.AddToken(tokens, leadingStart - 1, endPosition, "Hotkey")
            return {Position: endPosition + 1, Kind: "Hotkey",
                Execute: true}
        }
        if RegExMatch(line,
                "^[ `t]*([\p{L}_][\p{L}\p{N}_]*[ `t]*:)"
                    . "(?=[ `t]*(?:;|$))",
                &label) {
            startPosition := label.Pos(1) - 1
            endPosition := startPosition + label.Len(1)
            this.AddToken(tokens, startPosition, endPosition, "Label")
            return {Position: endPosition + 1, Kind: "Label",
                Execute: false}
        }
        return {Position: 1, Kind: "", Execute: false}
    }

    FindHotkeySeparator(line, startPosition) {
        position := startPosition
        while position < StrLen(line) {
            if position == startPosition
                    && SubStr(line, position, 3) == ":::"
                return position + 1
            if SubStr(line, position, 2) == "::"
                    && !this.IsEscapedPosition(line, position)
                return position
            position++
        }
        return 0
    }

    IsEscapedPosition(line, position) {
        escapeCount := 0
        position--
        while position >= 1 && SubStr(line, position, 1) == Chr(96) {
            escapeCount++
            position--
        }
        return Mod(escapeCount, 2) != 0
    }

    IsLineCommentStart(line, position) {
        if position <= 1
            return true
        previousCharacter := SubStr(line, position - 1, 1)
        return previousCharacter == " " || previousCharacter == "`t"
    }

    FindLineCommentStart(line, startPosition := 1) {
        position := InStr(line, ";", true, Max(1, startPosition))
        while position {
            if this.IsLineCommentStart(line, position)
                return position
            position := InStr(line, ";", true, position + 1)
        }
        return 0
    }

    AddCommentTokens(tokens, line, startPosition, endPosition) {
        if endPosition <= startPosition
            return false
        searchPosition := startPosition + 1
        segmentStart := startPosition
        while searchPosition <= endPosition
                && RegExMatch(SubStr(line, searchPosition,
                    endPosition - searchPosition + 1),
                    "i)\b(?:TODO|FIXME|NOTE)\b:?", &tagMatch) {
            tagStart := searchPosition + tagMatch.Pos(0) - 2
            tagEnd := tagStart + tagMatch.Len(0)
            this.AddToken(tokens, segmentStart, tagStart, "Comment")
            this.AddToken(tokens, tagStart, tagEnd, "CommentTag")
            segmentStart := tagEnd
            searchPosition := tagEnd + 1
        }
        this.AddToken(tokens, segmentStart, endPosition, "Comment")
        return true
    }

    ClassifyIdentifier(line, startPosition, endPosition, identifier,
            expectType) {
        lowerName := StrLower(identifier)
        if AhkV2Lexer.Literals().Has(lowerName)
            return "Literal"
        if AhkV2Lexer.WordOperators().Has(lowerName)
            return "Operator"
        if AhkV2Lexer.Keywords().Has(lowerName)
            return "Keyword"
        if AhkV2Lexer.BuiltinVariables().Has(lowerName)
            return "Builtin"
        if expectType || AhkV2Lexer.BuiltinTypes().Has(lowerName)
            return "Type"
        nextPosition := this.NextNonWhitespacePosition(line, endPosition + 1)
        if nextPosition && SubStr(line, nextPosition, 1) == "("
            return "Function"
        previousCharacter := this.PreviousNonWhitespace(line,
            startPosition - 1)
        if previousCharacter == "." || previousCharacter == "?"
            return "Property"
        if nextPosition && SubStr(line, nextPosition, 1) == ":"
                && SubStr(line, nextPosition, 2) != ":="
                && (previousCharacter == "{" || previousCharacter == ",")
            return "Property"
        return "Identifier"
    }

    PreviousNonWhitespace(line, position) {
        while position >= 1 {
            character := SubStr(line, position, 1)
            if character != " " && character != "`t"
                return character
            position--
        }
        return ""
    }

    NextNonWhitespacePosition(line, position) {
        lineLength := StrLen(line)
        while position <= lineLength {
            character := SubStr(line, position, 1)
            if character != " " && character != "`t"
                return position
            position++
        }
        return 0
    }

    IsNumberStart(line, position) {
        character := SubStr(line, position, 1)
        if RegExMatch(character, "\d")
            return true
        return character == "." && position < StrLen(line)
            && RegExMatch(SubStr(line, position + 1, 1), "\d")
    }

    MatchOperator(line, position) {
        remainder := SubStr(line, position)
        for operator in AhkV2Lexer.Operators() {
            if SubStr(remainder, 1, StrLen(operator)) == operator
                return operator
        }
        return ""
    }

    AddToken(tokens, startPosition, endPosition, kind) {
        if endPosition <= startPosition
            return false
        if tokens.Length {
            previous := tokens[tokens.Length]
            if previous.End == startPosition && previous.Kind == kind
                    && (kind == "Comment" || kind == "String") {
                previous.End := endPosition
                return true
            }
        }
        tokens.Push({Start: startPosition, End: endPosition, Kind: kind})
        return true
    }

    CreateLine(text, stateIn, stateOut, tokens) {
        return {Start: 0, Text: text, StateIn: stateIn,
            StateOut: stateOut, Tokens: tokens}
    }

    Canonicalize(text) {
        normalized := StrReplace(String(text), "`r`n", "`n")
        return StrReplace(normalized, "`r", "`n")
    }

    static Keywords() {
        static values := AhkV2Lexer.CreateWordSet([
            "and", "as", "break", "case", "catch", "class", "continue",
            "default", "else", "extends", "finally", "for", "global",
            "goto", "if", "local", "loop", "return", "static", "switch",
            "throw", "try", "until", "while"
        ])
        return values
    }

    static WordOperators() {
        static values := AhkV2Lexer.CreateWordSet([
            "and", "contains", "in", "is", "not", "or"
        ])
        return values
    }

    static CompilerDirectives() {
        static values := AhkV2Lexer.CreateWordSet([
            "@region", "@endregion", "@include-winapi", "@lint",
            "@format", "@format-disable", "@format-enable", "@reference"
        ])
        return values
    }

    static RawValueDirectives() {
        static values := AhkV2Lexer.CreateWordSet([
            "#dllload", "#errorstdout", "#hotstring", "#include",
            "#includeagain", "#requires", "#singleinstance", "#warn"
        ])
        return values
    }

    static Literals() {
        static values := AhkV2Lexer.CreateWordSet([
            "false", "true", "unset"
        ])
        return values
    }

    static BuiltinVariables() {
        static values := AhkV2Lexer.CreateWordSet([
            "this", "super", "value",
            "a_ahkpath", "a_ahkversion", "a_allowmainwindow",
            "a_appdata", "a_appdatacommon", "a_args", "a_clipboard",
            "a_comspec", "a_computername", "a_controldelay",
            "a_coordmodecaret", "a_coordmodemenu", "a_coordmodemouse",
            "a_coordmodepixel", "a_coordmodetooltip", "a_cursor", "a_dd",
            "a_ddd", "a_dddd", "a_defaultmousespeed", "a_desktop",
            "a_desktopcommon", "a_detecthiddentext",
            "a_detecthiddenwindows", "a_endchar", "a_eventinfo",
            "a_fileencoding", "a_hotkeymodifiertimeout",
            "a_hotkeyinterval", "a_hotif", "a_hour", "a_iconfile",
            "a_iconhidden", "a_iconnumber", "a_icontip", "a_index",
            "a_initialworkingdir", "a_is64bitos", "a_isadmin",
            "a_iscompiled", "a_iscritical", "a_ispaused", "a_issuspended",
            "a_keybdhookinstalled", "a_keydelay", "a_keydelayplay",
            "a_keyduration", "a_keydurationplay", "a_language",
            "a_lasterror", "a_linefile", "a_linenumber", "a_listlines",
            "a_loopfield", "a_loopfileattrib", "a_loopfiledir",
            "a_loopfileext", "a_loopfilefullpath", "a_loopfilename",
            "a_loopfilepath", "a_loopfileshortname", "a_loopfileshortpath",
            "a_loopfilesize", "a_loopfilesizekb", "a_loopfilesizemb",
            "a_loopfiletimeaccessed", "a_loopfiletimecreated",
            "a_loopfiletimemodified", "a_loopreadline", "a_loopregkey",
            "a_loopregname", "a_loopregtimemodified", "a_loopregtype",
            "a_maxhotkeysperinterval", "a_mday", "a_menumaskkey", "a_mm",
            "a_mmm", "a_mmmm", "a_msec", "a_min", "a_mon",
            "a_mousedelay", "a_mousedelayplay", "a_mousehookinstalled",
            "a_mydocuments", "a_now", "a_nowutc", "a_osversion",
            "a_priorhotkey", "a_priorkey", "a_programfiles", "a_programs",
            "a_programscommon", "a_ptrsize", "a_regview", "a_screendpi",
            "a_screenheight", "a_screenwidth", "a_scriptdir",
            "a_scriptfullpath", "a_scripthwnd", "a_scriptname", "a_sec",
            "a_sendlevel", "a_sendmode", "a_space", "a_startmenu",
            "a_startmenucommon", "a_startup", "a_startupcommon",
            "a_storecapslockmode", "a_tab", "a_temp", "a_thisfunc",
            "a_thishotkey", "a_tickcount", "a_timeidle",
            "a_timeidlekeyboard", "a_timeidlemouse", "a_timeidlephysical",
            "a_timesincepriorhotkey", "a_timesincethishotkey",
            "a_titlematchmode", "a_titlematchmodespeed", "a_traymenu",
            "a_username", "a_wday", "a_windelay", "a_windir",
            "a_workingdir", "a_yday", "a_yweek", "a_yyyy", "a_year"
        ])
        return values
    }

    static BuiltinTypes() {
        static values := AhkV2Lexer.CreateWordSet([
            "any", "array", "boundfunc", "buffer", "class",
            "clipboardall", "closure", "comobjarray", "comobject",
            "comvalue", "comvalueref", "enumerator", "error", "file",
            "float", "func", "gui", "guicontrol", "indexerror",
            "inputhook", "integer", "keyerror", "map", "membererror",
            "memoryerror", "menu", "menubar", "methoderror", "number",
            "object", "oserror", "primitive", "propertyerror",
            "regexmatchinfo", "string", "targeterror", "timeouterror",
            "typeerror", "unsetitemerror", "unsetpropertyerror",
            "valueerror", "varref", "zerodivisionerror"
        ])
        return values
    }

    static Operators() {
        static values := [">>>=", "<<=", ">>=", "//=", "=>",
            "++", "--", "**", "//",
            "<<", ">>>", ">>", "<=", ">=", "==", "!=", "<>", "~=",
            "&&", "||", "??", ":=", "+=", "-=", "*=", "/=", ".=",
            "|=", "&=", "^=", "+", "-", "*", "/", "%", ".", "!",
            "~", "&", "|", "^", "<", ">", "=", "?", ":"]
        return values
    }

    static CreateWordSet(words) {
        result := Map()
        for word in words
            result[StrLower(word)] := true
        return result
    }
}
