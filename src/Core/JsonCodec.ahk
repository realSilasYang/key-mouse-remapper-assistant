class JsonBoolean {
    __New(value) {
        this.Value := !!value
    }
}

class JsonNull {
}

class JsonCodec {
    static Parse(text) {
        parser := JsonParser(String(text))
        return parser.ParseDocument()
    }

    static Stringify(value, pretty := true, sortKeys := true) {
        writer := JsonWriter(pretty, sortKeys)
        return writer.Write(value)
    }
}

class JsonParser {
    static MaximumDepth := 64
    static MaximumValues := 500000

    __New(text) {
        this.Text := text
        this.TextBuffer := Buffer(StrPut(text, "UTF-16") * 2, 0)
        StrPut(text, this.TextBuffer, "UTF-16")
        this.Pointer := this.TextBuffer.Ptr
        this.Position := 1
        this.Length := StrLen(text)
        this.ValueCount := 0
    }

    ParseDocument() {
        value := this.ParseValue(0)
        this.SkipWhitespace()
        if this.Position <= this.Length
            this.Fail("JSON 根值之后存在多余内容。")
        return value
    }

    ParseValue(depth := 0) {
        if depth > JsonParser.MaximumDepth
            this.Fail("JSON 嵌套层级超过上限。")
        this.ValueCount++
        if this.ValueCount > JsonParser.MaximumValues
            this.Fail("JSON 值数量超过上限。")
        position := this.Position
        pointer := this.Pointer
        while position <= this.Length {
            characterCode := NumGet(pointer + (position - 1) * 2, "UShort")
            if characterCode != 0x20 && characterCode != 0x09
                    && characterCode != 0x0D && characterCode != 0x0A
                break
            position++
        }
        this.Position := position
        if position > this.Length
            this.Fail("JSON 值意外结束。")
        switch characterCode {
            case 0x7B: return this.ParseObject(depth) ; {
            case 0x5B: return this.ParseArray(depth) ; [
            case 0x22: return this.ParseString() ; "
            case 0x74: return this.ParseLiteral("true", JsonBoolean(true))
            case 0x66: return this.ParseLiteral("false", JsonBoolean(false))
            case 0x6E: return this.ParseLiteral("null", JsonNull())
        }
        if characterCode == 0x2D
                || (characterCode >= 0x30 && characterCode <= 0x39)
            return this.ParseNumber()
        this.Fail("无法识别的 JSON 值。")
    }

    ParseObject(depth) {
        result := Map()
        this.Position++ ; ParseValue already identified {
        if this.SkipWhitespace() == 0x7D {
            this.Position++
            return result
        }
        loop {
            if this.SkipWhitespace() != 0x22
                this.Fail("JSON 对象键必须是字符串。")
            key := this.ParseString()
            colonCode := this.PeekCode()
            if colonCode != 0x3A
                colonCode := this.SkipWhitespace()
            if colonCode != 0x3A
                this.Fail("JSON 对象字段缺少冒号。")
            this.Position++
            if result.Has(key)
                this.Fail("JSON 对象包含重复字段：" key)
            result[key] := this.ParseValue(depth + 1)
            delimiterCode := this.SkipWhitespace()
            if delimiterCode == 0x7D {
                this.Position++
                break
            }
            if delimiterCode != 0x2C
                this.Fail("JSON 对象字段之间缺少逗号。")
            this.Position++
        }
        return result
    }

    ParseArray(depth) {
        result := []
        this.Position++ ; ParseValue already identified [
        if this.SkipWhitespace() == 0x5D {
            this.Position++
            return result
        }
        loop {
            result.Push(this.ParseValue(depth + 1))
            delimiterCode := this.SkipWhitespace()
            if delimiterCode == 0x5D {
                this.Position++
                break
            }
            if delimiterCode != 0x2C
                this.Fail("JSON 数组元素之间缺少逗号。")
            this.Position++
        }
        return result
    }

    ParseString() {
        if this.PeekCode() != 0x22
            this.Fail("JSON 缺少预期字符：" Chr(34))
        this.Position++
        tokenStart := this.Position
        closingPosition := this.FindStringClosingQuote(tokenStart)
        token := SubStr(this.Text, tokenStart,
            closingPosition - tokenStart)
        this.Position := closingPosition + 1
        if RegExMatch(token, '[\x00-\x1F]')
            this.Fail("JSON 字符串包含未转义控制字符。")

        escapedBackslashMarker := Chr(1)
        decoded := StrReplace(token, "\\", escapedBackslashMarker)
        if RegExMatch(decoded, '\\(?!["/bfnrtu])')
            this.Fail("JSON 字符串包含无效转义。")
        if RegExMatch(decoded, '\\u(?![0-9A-Fa-f]{4})')
            this.Fail("JSON Unicode 转义无效。")
        decoded := StrReplace(decoded, '\"', '"')
        decoded := StrReplace(decoded, "\/", "/")
        decoded := StrReplace(decoded, "\b", Chr(8))
        decoded := StrReplace(decoded, "\f", Chr(12))
        decoded := StrReplace(decoded, "\n", "`n")
        decoded := StrReplace(decoded, "\r", "`r")
        decoded := StrReplace(decoded, "\t", "`t")
        if InStr(decoded, "\u")
            return this.DecodeUnicodeEscapes(decoded,
                escapedBackslashMarker)
        decoded := StrReplace(decoded, escapedBackslashMarker, "\")
        return decoded
    }

    FindStringClosingQuote(position) {
        pointer := this.Pointer
        delimiters := this.StringDelimiterCharacters()
        backslashes := this.StringBackslashCharacters()
        while position <= this.Length {
            span := DllCall("msvcrt\wcscspn",
                "Ptr", pointer + (position - 1) * 2,
                "Ptr", delimiters.Ptr, "UPtr")
            position += span
            if position > this.Length
                break
            if NumGet(pointer + (position - 1) * 2, "UShort") == 0x22
                return position
            slashCount := DllCall("msvcrt\wcsspn",
                "Ptr", pointer + (position - 1) * 2,
                "Ptr", backslashes.Ptr, "UPtr")
            position += slashCount
            if slashCount & 1
                position++
        }
        this.Position := position
        this.Fail("JSON 字符串缺少结束引号。")
    }

    StringDelimiterCharacters() {
        static characters := 0
        if !IsObject(characters) {
            characters := Buffer(3 * 2, 0)
            NumPut("UShort", 0x22, characters, 0)
            NumPut("UShort", 0x5C, characters, 2)
        }
        return characters
    }

    StringBackslashCharacters() {
        static characters := 0
        if !IsObject(characters) {
            characters := Buffer(2 * 2, 0)
            NumPut("UShort", 0x5C, characters, 0)
        }
        return characters
    }

    DecodeUnicodeEscapes(text, escapedBackslashMarker) {
        result := ""
        VarSetStrCapacity(&result, StrLen(text))
        sourcePosition := 1
        searchPosition := 1
        pattern := "\\u([0-9A-Fa-f]{4})"
        while RegExMatch(text, pattern, &unicodeMatch, searchPosition) {
            result .= StrReplace(SubStr(text, sourcePosition,
                unicodeMatch.Pos(0) - sourcePosition),
                escapedBackslashMarker, "\")
            firstCodeUnit := Integer("0x" unicodeMatch[1])
            searchPosition := unicodeMatch.Pos(0) + unicodeMatch.Len(0)
            if firstCodeUnit >= 0xD800 && firstCodeUnit <= 0xDBFF {
                if !RegExMatch(text, "\G" pattern, &lowMatch,
                        searchPosition)
                    this.Fail("JSON 高代理项缺少低代理项。")
                secondCodeUnit := Integer("0x" lowMatch[1])
                if secondCodeUnit < 0xDC00 || secondCodeUnit > 0xDFFF
                    this.Fail("JSON 低代理项无效。")
                result .= Chr(0x10000 + ((firstCodeUnit - 0xD800) << 10)
                    + secondCodeUnit - 0xDC00)
                searchPosition := lowMatch.Pos(0) + lowMatch.Len(0)
            } else {
                result .= Chr(firstCodeUnit)
            }
            sourcePosition := searchPosition
        }
        result .= StrReplace(SubStr(text, sourcePosition),
            escapedBackslashMarker, "\")
        return result
    }

    ReadHexCodeUnit() {
        if this.Position + 3 > this.Length
            this.Fail("JSON Unicode 转义不完整。")
        digits := SubStr(this.Text, this.Position, 4)
        if !RegExMatch(digits, "^[0-9A-Fa-f]{4}$")
            this.Fail("JSON Unicode 转义无效。")
        this.Position += 4
        return Integer("0x" digits)
    }

    ParseNumber() {
        start := this.Position
        position := start
        pointer := this.Pointer
        length := this.Length
        if this.CodeAt(position) == 0x2D {
            position++
            if position > length {
                this.Position := position
                this.Fail("JSON 数字格式无效。")
            }
        }

        code := NumGet(pointer + (position - 1) * 2, "UShort")
        if code == 0x30 {
            position++
            if position <= length {
                nextCode := NumGet(pointer + (position - 1) * 2, "UShort")
                if nextCode >= 0x30 && nextCode <= 0x39 {
                    this.Position := position
                    this.Fail("JSON 数字不允许前导零。")
                }
            }
        } else if code >= 0x31 && code <= 0x39 {
            position++
            while position <= length {
                code := NumGet(pointer + (position - 1) * 2, "UShort")
                if code < 0x30 || code > 0x39
                    break
                position++
            }
        } else {
            this.Position := position
            this.Fail("JSON 数字格式无效。")
        }

        hasFractionOrExponent := false
        if position <= length
                && NumGet(pointer + (position - 1) * 2, "UShort") == 0x2E {
            hasFractionOrExponent := true
            position++
            if position > length {
                this.Position := position
                this.Fail("JSON 小数点后缺少数字。")
            }
            code := NumGet(pointer + (position - 1) * 2, "UShort")
            if code < 0x30 || code > 0x39 {
                this.Position := position
                this.Fail("JSON 小数点后缺少数字。")
            }
            while position <= length {
                code := NumGet(pointer + (position - 1) * 2, "UShort")
                if code < 0x30 || code > 0x39
                    break
                position++
            }
        }

        if position <= length {
            code := NumGet(pointer + (position - 1) * 2, "UShort")
            if code == 0x65 || code == 0x45 {
                hasFractionOrExponent := true
                position++
                if position <= length {
                    code := NumGet(pointer + (position - 1) * 2, "UShort")
                    if code == 0x2B || code == 0x2D
                        position++
                }
                if position > length {
                    this.Position := position
                    this.Fail("JSON 指数部分缺少数字。")
                }
                code := NumGet(pointer + (position - 1) * 2, "UShort")
                if code < 0x30 || code > 0x39 {
                    this.Position := position
                    this.Fail("JSON 指数部分缺少数字。")
                }
                while position <= length {
                    code := NumGet(pointer + (position - 1) * 2, "UShort")
                    if code < 0x30 || code > 0x39
                        break
                    position++
                }
            }
        }

        token := SubStr(this.Text, start, position - start)
        this.Position := position
        return hasFractionOrExponent ? Float(token) : Integer(token)
    }

    ParseLiteral(expected, value) {
        if SubStr(this.Text, this.Position, StrLen(expected)) != expected
            this.Fail("JSON 字面量无效。")
        this.Position += StrLen(expected)
        return value
    }

    SkipWhitespace() {
        pointer := this.Pointer
        while this.Position <= this.Length {
            code := NumGet(pointer + (this.Position - 1) * 2, "UShort")
            if code != 0x20 && code != 0x09 && code != 0x0D && code != 0x0A
                return code
            this.Position++
        }
        return 0
    }

    PeekCode() {
        return this.Position <= this.Length
            ? NumGet(this.Pointer + (this.Position - 1) * 2, "UShort") : 0
    }

    Fail(message) {
        throw Error(message "（位置 " this.Position "）")
    }

    CodeAt(position) {
        return NumGet(this.Pointer + (position - 1) * 2, "UShort")
    }
}

class JsonWriter {
    __New(pretty, sortKeys) {
        this.Pretty := !!pretty
        this.SortKeys := !!sortKeys
        this.ValueCount := 0
        this.ActiveContainers := Map()
    }

    Write(value, depth := 0) {
        if depth > JsonParser.MaximumDepth
            throw Error("JSON 嵌套层级超过上限。")
        this.ValueCount++
        if this.ValueCount > JsonParser.MaximumValues
            throw Error("JSON 值数量超过上限。")
        if value is JsonBoolean
            return value.Value ? "true" : "false"
        if value is JsonNull
            return "null"
        valueType := Type(value)
        switch valueType {
            case "Map": return this.WriteMap(value, depth)
            case "Array": return this.WriteArray(value, depth)
            case "String": return this.WriteString(value)
            case "Integer", "Float": return this.WriteNumber(value)
        }
        throw TypeError("JSON 不支持值类型：" valueType)
    }

    WriteMap(value, depth) {
        pointer := ObjPtr(value)
        this.EnterContainer(pointer)
        try {
            if !value.Count
                return "{}"
            keys := []
            for key in value
                keys.Push(String(key))
            if this.SortKeys
                this.SortStrings(keys)
            parts := []
            for key in keys {
                if !value.Has(key)
                    throw Error("JSON 对象键必须是字符串。")
                separator := this.Pretty ? ": " : ":"
                parts.Push(this.WriteString(key) separator
                    . this.Write(value[key], depth + 1))
            }
            return this.JoinContainer("{", "}", parts, depth)
        } finally this.LeaveContainer(pointer)
    }

    WriteArray(value, depth) {
        pointer := ObjPtr(value)
        this.EnterContainer(pointer)
        try {
            if !value.Length
                return "[]"
            parts := []
            for item in value
                parts.Push(this.Write(item, depth + 1))
            return this.JoinContainer("[", "]", parts, depth)
        } finally this.LeaveContainer(pointer)
    }

    JoinContainer(opening, closing, parts, depth) {
        if !this.Pretty {
            text := ""
            for index, part in parts
                text .= (index > 1 ? "," : "") part
            return opening text closing
        }
        indentation := this.Indent(depth + 1)
        text := ""
        for index, part in parts
            text .= (index > 1 ? ",`n" : "") indentation part
        return opening "`n" text "`n" this.Indent(depth) closing
    }

    WriteString(value) {
        text := String(value)
        result := ""
        VarSetStrCapacity(&result, StrLen(text) * 2 + 2)
        result .= '"'
        Loop StrLen(text) {
            character := SubStr(text, A_Index, 1)
            switch character {
                case '"': result .= '\"'
                case "\": result .= "\\"
                case Chr(8): result .= "\b"
                case Chr(12): result .= "\f"
                case "`n": result .= "\n"
                case "`r": result .= "\r"
                case "`t": result .= "\t"
                default:
                    codePoint := Ord(character)
                    result .= codePoint < 0x20
                        ? Format("\u{:04X}", codePoint) : character
            }
        }
        return result '"'
    }

    WriteNumber(value) {
        if Type(value) == "Float" && (value != value
                || Abs(value) > 1.7976931348623157e308)
            throw ValueError("JSON 不支持非有限数字。")
        return String(value)
    }

    Indent(depth) {
        return Format("{:" depth * 2 "}", "")
    }

    SortStrings(values) {
        if values.Length < 2
            return
        count := values.Length
        source := values.Clone()
        target := []
        Loop count
            target.Push("")
        width := 1
        while width < count {
            start := 1
            while start <= count {
                middle := Min(start + width, count + 1)
                limit := Min(start + width * 2, count + 1)
                left := start
                right := middle
                output := start
                while output < limit {
                    if right >= limit || (left < middle
                            && StrCompare(source[left], source[right], true)
                                <= 0) {
                        target[output] := source[left]
                        left++
                    } else {
                        target[output] := source[right]
                        right++
                    }
                    output++
                }
                start := limit
            }
            temporary := source
            source := target
            target := temporary
            width *= 2
        }
        Loop count
            values[A_Index] := source[A_Index]
    }

    EnterContainer(pointer) {
        if this.ActiveContainers.Has(pointer)
            throw Error("JSON 不支持循环引用。")
        this.ActiveContainers[pointer] := true
    }

    LeaveContainer(pointer) {
        if this.ActiveContainers.Has(pointer)
            this.ActiveContainers.Delete(pointer)
    }
}
