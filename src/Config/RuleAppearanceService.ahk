class RuleAppearanceService {
    static MaximumFileBytes := 256 * 1024
    static MaximumCharacters := 256 * 1024

    __New(path) {
        path := Trim(String(path))
        if path == ""
            throw ValueError("规则外观设置路径不能为空。")
        this.Path := CrossProcessWriteLock.NormalizePath(path)
    }

    Load() {
        lease := CrossProcessWriteLock.Acquire(this.Path)
        try {
            if !FileExist(this.Path)
                return Map()
            text := BoundedFileReader.ReadUtf8(this.Path,
                RuleAppearanceService.MaximumFileBytes,
                RuleAppearanceService.MaximumCharacters, "规则外观设置")
            parsed := JsonCodec.Parse(text)
            if Type(parsed) != "Map"
                throw Error("规则外观设置根值必须是对象。")
            source := parsed.Has("colors") ? parsed["colors"] : Map()
            if Type(source) != "Map"
                throw Error("规则外观设置 colors 必须是对象。")
            return this.Normalize(source)
        } finally lease.Release()
    }

    Save(colors) {
        normalized := this.Normalize(colors)
        document := Map("version", 1, "colors", normalized)
        text := JsonCodec.Stringify(document, true, true) "`r`n"
        if StrLen(text) > RuleAppearanceService.MaximumCharacters
                || StrPut(text, "UTF-8") - 1
                    > RuleAppearanceService.MaximumFileBytes
            throw Error("规则外观设置超过大小上限。")
        lease := CrossProcessWriteLock.Acquire(this.Path)
        try this.WriteAtomically(text)
        finally lease.Release()
        return normalized
    }

    Normalize(colors) {
        result := Map()
        if Type(colors) != "Map"
            return result
        for mappingId, presetKey in colors {
            mappingId := Trim(String(mappingId))
            presetKey := RuleColorPalette.NormalizeKey(presetKey)
            if mappingId != "" && presetKey != ""
                result[mappingId] := presetKey
        }
        return result
    }

    WriteAtomically(text) {
        directory := ""
        SplitPath(this.Path, , &directory)
        if directory != "" && !DirExist(directory)
            DirCreate(directory)
        temporaryPath := this.Path ".tmp-" A_TickCount "-"
            . Format("{:08X}", Random(0, 0xFFFFFFFF))
        output := ""
        try {
            output := FileOpen(temporaryPath, "w", "UTF-8-RAW")
            if !IsObject(output)
                throw Error("无法写入规则外观设置。")
            output.Write(text)
            output.Close()
            output := ""
            FileMove(temporaryPath, this.Path, 1)
        } catch as writeError {
            if IsObject(output)
                try output.Close()
            if FileExist(temporaryPath)
                try FileDelete(temporaryPath)
            throw writeError
        }
        return true
    }
}
