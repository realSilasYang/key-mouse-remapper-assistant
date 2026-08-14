; 主窗口正常状态尺寸的独立持久化服务。
; 布局状态不属于用户功能设置，单独保存可避免设置窗口用旧快照覆盖刚调整的尺寸。
class WindowLayoutService {
    static MaximumFileBytes := 4096
    static MaximumSnapshotCharacters := 2048
    static MaximumDimension := 32767

    __New(layoutPath, defaultWidth, defaultHeight, minimumWidth,
            minimumHeight) {
        layoutPath := Trim(String(layoutPath))
        if layoutPath == ""
            throw ValueError("窗口布局文件路径不能为空。")
        this.LayoutPath := CrossProcessWriteLock.NormalizePath(layoutPath)
        this.DefaultWidth := this.RequireConfiguredDimension(defaultWidth,
            "默认宽度")
        this.DefaultHeight := this.RequireConfiguredDimension(defaultHeight,
            "默认高度")
        this.MinimumWidth := this.RequireConfiguredDimension(minimumWidth,
            "最小宽度")
        this.MinimumHeight := this.RequireConfiguredDimension(minimumHeight,
            "最小高度")
        if this.DefaultWidth < this.MinimumWidth
                || this.DefaultHeight < this.MinimumHeight
            throw ValueError("窗口默认尺寸不能小于最小尺寸。")
    }

    Load() {
        readLease := CrossProcessWriteLock.Acquire(this.LayoutPath)
        try {
            values := this.ParseSnapshot(this.GetSnapshot())
            return this.Normalize({
                Width: this.ReadSnapshotValue(values, "MainWindow", "Width",
                    this.DefaultWidth),
                Height: this.ReadSnapshotValue(values, "MainWindow", "Height",
                    this.DefaultHeight)
            })
        } finally readLease.Release()
    }

    Save(layout) {
        normalized := this.Normalize(layout)
        this.WriteSnapshot(this.BuildSnapshot(normalized))
        return normalized
    }

    Normalize(layout) {
        return {
            Width: this.NormalizeDimension(this.GetProperty(layout, "Width",
                this.DefaultWidth), this.MinimumWidth, this.DefaultWidth),
            Height: this.NormalizeDimension(this.GetProperty(layout, "Height",
                this.DefaultHeight), this.MinimumHeight, this.DefaultHeight)
        }
    }

    NormalizeDimension(value, minimum, fallback) {
        try {
            text := Trim(String(value))
            if !RegExMatch(text, "^\d+$")
                return fallback
            value := Integer(text)
        } catch {
            return fallback
        }
        return value >= minimum && value <= WindowLayoutService.MaximumDimension
            ? value : fallback
    }

    RequireConfiguredDimension(value, label) {
        try value := Integer(value)
        catch
            throw ValueError(label "不是有效整数。")
        if value < 1 || value > WindowLayoutService.MaximumDimension
            throw ValueError(label "超出有效范围。")
        return value
    }

    GetProperty(object, propertyName, fallback) {
        return IsObject(object) && object.HasOwnProp(propertyName)
            ? object.%propertyName% : fallback
    }

    ParseSnapshot(snapshot) {
        values := Map()
        currentSection := ""
        for line in StrSplit(StrReplace(String(snapshot), "`r"), "`n") {
            trimmed := Trim(line, " `t")
            if trimmed == "" || SubStr(trimmed, 1, 1) == ";"
                    || SubStr(trimmed, 1, 1) == "#"
                continue
            if RegExMatch(trimmed, "^\[([^\]`r`n]+)\]$", &sectionMatch) {
                currentSection := StrLower(Trim(sectionMatch[1], " `t"))
                continue
            }
            separator := InStr(line, "=")
            if currentSection == "" || !separator
                continue
            key := StrLower(Trim(SubStr(line, 1, separator - 1), " `t"))
            if key != ""
                values[currentSection Chr(31) key] := Trim(
                    SubStr(line, separator + 1), " `t")
        }
        return values
    }

    ReadSnapshotValue(values, section, key, fallback) {
        lookupKey := StrLower(String(section)) Chr(31) StrLower(String(key))
        return values.Has(lookupKey) ? values[lookupKey] : fallback
    }

    GetSnapshot() {
        if !FileExist(this.LayoutPath)
            return ""
        return BoundedFileReader.ReadUtf8(this.LayoutPath,
            WindowLayoutService.MaximumFileBytes,
            WindowLayoutService.MaximumSnapshotCharacters, "窗口布局文件")
    }

    BuildSnapshot(layout) {
        return "[MainWindow]`r`n"
            . "Width=" layout.Width "`r`n"
            . "Height=" layout.Height "`r`n"
    }

    WriteSnapshot(snapshot) {
        snapshot := String(snapshot)
        if StrLen(snapshot) > WindowLayoutService.MaximumSnapshotCharacters
                || StrPut(snapshot, "UTF-8") - 1
                    > WindowLayoutService.MaximumFileBytes
            throw Error("窗口布局快照超过大小上限。")
        writeLease := CrossProcessWriteLock.Acquire(this.LayoutPath)
        try {
            directory := ""
            SplitPath(this.LayoutPath, , &directory)
            if directory != "" && !DirExist(directory)
                DirCreate(directory)
            temporaryPath := this.LayoutPath ".tmp-" A_TickCount "-"
                . Format("{:08X}", Random(0, 0xFFFFFFFF))
            output := ""
            try {
                output := FileOpen(temporaryPath, "w", "UTF-8-RAW")
                if !IsObject(output)
                    throw Error("无法写入窗口布局。")
                output.Write(snapshot)
                output.Close()
                output := ""
                FileMove(temporaryPath, this.LayoutPath, 1)
            } catch as writeError {
                if IsObject(output)
                    try output.Close()
                if FileExist(temporaryPath)
                    try FileDelete(temporaryPath)
                throw writeError
            }
        } finally writeLease.Release()
        return true
    }
}
