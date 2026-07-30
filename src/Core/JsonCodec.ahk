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
        this.SkipWhitespace()
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
        this.SkipWhitespace()
        if this.Position > this.Length
            this.Fail("JSON 值意外结束。")
        characterCode := this.CodeAt(this.Position)
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
        this.SkipWhitespace()
        if this.PeekCode() == 0x7D {
            this.Position++
            return result
        }
        loop {
            this.SkipWhitespace()
            if this.PeekCode() != 0x22
                this.Fail("JSON 对象键必须是字符串。")
            key := this.ParseString()
            if this.PeekCode() != 0x3A
                this.SkipWhitespace()
            if this.PeekCode() != 0x3A
                this.Fail("JSON 对象字段缺少冒号。")
            this.Position++
            if result.Has(key)
                this.Fail("JSON 对象包含重复字段：" key)
            result[key] := this.ParseValue(depth + 1)
            delimiterCode := this.PeekCode()
            if delimiterCode == 0x20 || delimiterCode == 0x09
                    || delimiterCode == 0x0D || delimiterCode == 0x0A {
                this.SkipWhitespace()
                delimiterCode := this.PeekCode()
            }
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
        this.SkipWhitespace()
        if this.PeekCode() == 0x5D {
            this.Position++
            return result
        }
        loop {
            result.Push(this.ParseValue(depth + 1))
            delimiterCode := this.PeekCode()
            if delimiterCode == 0x20 || delimiterCode == 0x09
                    || delimiterCode == 0x0D || delimiterCode == 0x0A {
                this.SkipWhitespace()
                delimiterCode := this.PeekCode()
            }
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
        result := ""
        segmentStart := this.Position
        pointer := this.Pointer
        while this.Position <= this.Length {
            characterCode := NumGet(pointer + (this.Position - 1) * 2,
                "UShort")
            if characterCode == 0x22 {
                result .= SubStr(this.Text, segmentStart,
                    this.Position - segmentStart)
                this.Position++
                return result
            }
            if characterCode != 0x5C {
                if characterCode < 0x20
                    this.Fail("JSON 字符串包含未转义控制字符。")
                this.Position++
                continue
            }
            result .= SubStr(this.Text, segmentStart,
                this.Position - segmentStart)
            this.Position++
            if this.Position > this.Length
                this.Fail("JSON 字符串转义意外结束。")
            escapedCode := NumGet(pointer + (this.Position - 1) * 2,
                "UShort")
            this.Position++
            switch escapedCode {
                case 0x22, 0x5C, 0x2F: result .= Chr(escapedCode)
                case 0x62: result .= Chr(8)
                case 0x66: result .= Chr(12)
                case 0x6E: result .= "`n"
                case 0x72: result .= "`r"
                case 0x74: result .= "`t"
                case 0x75: result .= this.ParseUnicodeEscape()
                default: this.Fail("JSON 字符串包含无效转义。")
            }
            segmentStart := this.Position
        }
        this.Fail("JSON 字符串缺少结束引号。")
    }

    ParseUnicodeEscape() {
        first := this.ReadHexCodeUnit()
        if first < 0xD800 || first > 0xDBFF
            return Chr(first)
        if SubStr(this.Text, this.Position, 2) != "\u"
            this.Fail("JSON 高代理项缺少低代理项。")
        this.Position += 2
        second := this.ReadHexCodeUnit()
        if second < 0xDC00 || second > 0xDFFF
            this.Fail("JSON 低代理项无效。")
        return Chr(0x10000 + ((first - 0xD800) << 10) + second - 0xDC00)
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
                break
            this.Position++
        }
    }

    Peek() {
        return this.Position <= this.Length
            ? Chr(this.CodeAt(this.Position)) : ""
    }

    PeekCode() {
        return this.Position <= this.Length
            ? NumGet(this.Pointer + (this.Position - 1) * 2, "UShort") : 0
    }

    Expect(expected) {
        if this.PeekCode() != Ord(expected)
            this.Fail("JSON 缺少预期字符：" expected)
        this.Position++
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
        result := '"'
        text := String(value)
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
