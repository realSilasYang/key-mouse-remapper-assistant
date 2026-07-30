class Sha256 {
    static RoundConstants := [
        0x428A2F98, 0x71374491, 0xB5C0FBCF, 0xE9B5DBA5,
        0x3956C25B, 0x59F111F1, 0x923F82A4, 0xAB1C5ED5,
        0xD807AA98, 0x12835B01, 0x243185BE, 0x550C7DC3,
        0x72BE5D74, 0x80DEB1FE, 0x9BDC06A7, 0xC19BF174,
        0xE49B69C1, 0xEFBE4786, 0x0FC19DC6, 0x240CA1CC,
        0x2DE92C6F, 0x4A7484AA, 0x5CB0A9DC, 0x76F988DA,
        0x983E5152, 0xA831C66D, 0xB00327C8, 0xBF597FC7,
        0xC6E00BF3, 0xD5A79147, 0x06CA6351, 0x14292967,
        0x27B70A85, 0x2E1B2138, 0x4D2C6DFC, 0x53380D13,
        0x650A7354, 0x766A0ABB, 0x81C2C92E, 0x92722C85,
        0xA2BFE8A1, 0xA81A664B, 0xC24B8B70, 0xC76C51A3,
        0xD192E819, 0xD6990624, 0xF40E3585, 0x106AA070,
        0x19A4C116, 0x1E376C08, 0x2748774C, 0x34B0BCB5,
        0x391C0CB3, 0x4ED8AA4A, 0x5B9CCA4F, 0x682E6FF3,
        0x748F82EE, 0x78A5636F, 0x84C87814, 0x8CC70208,
        0x90BEFFFA, 0xA4506CEB, 0xBEF9A3F7, 0xC67178F2]

    static HexText(text) {
        byteCount := StrPut(String(text), "UTF-8") - 1
        bytes := Buffer(Max(1, byteCount + 1), 0)
        if byteCount
            StrPut(String(text), bytes, byteCount + 1, "UTF-8")
        return this.HexBuffer(bytes, byteCount)
    }

    static HexBuffer(inputBuffer, byteCount := unset) {
        if !IsSet(byteCount)
            byteCount := inputBuffer.Size
        if !IsNumber(byteCount) || Integer(byteCount) != byteCount
                || byteCount < 0 || byteCount > inputBuffer.Size
            throw ValueError("SHA-256 输入字节数超出缓冲区范围。")
        byteCount := Integer(byteCount)
        paddedLength := Integer(Ceil((byteCount + 9) / 64) * 64)
        padded := Buffer(paddedLength, 0)
        Loop byteCount
            NumPut("UChar", NumGet(inputBuffer, A_Index - 1, "UChar"),
                padded, A_Index - 1)
        NumPut("UChar", 0x80, padded, byteCount)
        bitLength := byteCount * 8
        Loop 8
            NumPut("UChar", (bitLength >> ((8 - A_Index) * 8)) & 0xFF,
                padded, paddedLength - 8 + A_Index - 1)

        state := [0x6A09E667, 0xBB67AE85, 0x3C6EF372, 0xA54FF53A,
            0x510E527F, 0x9B05688C, 0x1F83D9AB, 0x5BE0CD19]
        offset := 0
        while offset < paddedLength {
            schedule := []
            Loop 16 {
                position := offset + (A_Index - 1) * 4
                schedule.Push((NumGet(padded, position, "UChar") << 24)
                    | (NumGet(padded, position + 1, "UChar") << 16)
                    | (NumGet(padded, position + 2, "UChar") << 8)
                    | NumGet(padded, position + 3, "UChar"))
            }
            Loop 48 {
                index := A_Index + 16
                lower := schedule[index - 15]
                upper := schedule[index - 2]
                sigma0 := this.RotateRight(lower, 7)
                    ^ this.RotateRight(lower, 18) ^ (lower >> 3)
                sigma1 := this.RotateRight(upper, 17)
                    ^ this.RotateRight(upper, 19) ^ (upper >> 10)
                schedule.Push(this.Mask32(schedule[index - 16] + sigma0
                    + schedule[index - 7] + sigma1))
            }

            a := state[1], b := state[2], c := state[3], d := state[4]
            e := state[5], f := state[6], g := state[7], h := state[8]
            Loop 64 {
                sum1 := this.RotateRight(e, 6) ^ this.RotateRight(e, 11)
                    ^ this.RotateRight(e, 25)
                choose := (e & f) ^ ((~e) & g)
                temporary1 := this.Mask32(h + sum1 + choose
                    + this.RoundConstants[A_Index] + schedule[A_Index])
                sum0 := this.RotateRight(a, 2) ^ this.RotateRight(a, 13)
                    ^ this.RotateRight(a, 22)
                majority := (a & b) ^ (a & c) ^ (b & c)
                temporary2 := this.Mask32(sum0 + majority)
                h := g, g := f, f := e
                e := this.Mask32(d + temporary1)
                d := c, c := b, b := a
                a := this.Mask32(temporary1 + temporary2)
            }
            Loop 8
                state[A_Index] := this.Mask32(state[A_Index]
                    + [a, b, c, d, e, f, g, h][A_Index])
            offset += 64
        }
        result := ""
        for value in state
            result .= Format("{:08X}", this.Mask32(value))
        return result
    }

    static RotateRight(value, count) {
        value := this.Mask32(value)
        return this.Mask32((value >> count) | (value << (32 - count)))
    }

    static Mask32(value) {
        return value & 0xFFFFFFFF
    }
}
