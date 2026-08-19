class AppSettingsService {
    static MaximumFileBytes := 64 * 1024
    static MaximumSnapshotCharacters := 64 * 1024
    static MinimumEventBufferCapacity := 100
    static MaximumEventBufferCapacity := 10000

    __New(settingsPath) {
        settingsPath := Trim(String(settingsPath))
        if settingsPath == ""
            throw ValueError("设置文件路径不能为空。")
        this.SettingsPath := CrossProcessWriteLock.NormalizePath(settingsPath)
        this.LastLoadWarning := ""
    }

    Load() {
        readLease := CrossProcessWriteLock.Acquire(this.SettingsPath)
        try {
            this.LastLoadWarning := ""
            snapshot := ""
            try snapshot := this.GetSnapshot()
            catch as readError {
                this.LastLoadWarning := "无法读取设置文件，已使用默认设置："
                    . readError.Message
                snapshot := ""
            }
            values := this.ParseSnapshot(snapshot)
            return this.Normalize({
                UiLanguage: this.ReadSnapshotValue(values, "Appearance",
                    "UiLanguage", "auto"),
                UiFont: this.ReadSnapshotValue(values, "Appearance",
                    "UiFont", "auto"),
                Theme: this.ReadSnapshotValue(values, "Appearance",
                    "Theme", "auto"),
                UiScalePercent: this.ReadSnapshotValue(values, "Appearance",
                    "UiScalePercent", "100"),
                ShowAtStartup: this.ReadSnapshotValue(values, "Startup",
                    "ShowAtStartup", "0"),
                RunAsAdministrator: this.ReadSnapshotValue(values,
                    "Startup", "RunAsAdministrator", "1"),
                CheckUpdatesOnStartup: this.ReadSnapshotValue(values,
                    "Startup", "CheckUpdatesOnStartup", "1"),
                EscapeCancelsRecording: this.ReadSnapshotValue(values, "Recording",
                    "EscapeCancelsRecording", "1"),
                EventBufferCapacity: this.ReadSnapshotValue(values, "Events",
                    "EventBufferCapacity", "1000"),
                EventViewerAutoScroll: this.ReadSnapshotValue(values, "Events",
                    "EventViewerAutoScroll", "1"),
                AIAddress: this.ReadSnapshotValue(values, "AI", "Address",
                    ""),
                AIKey: this.ReadSnapshotValue(values, "AI", "Key", ""),
                AIModel: this.ReadSnapshotValue(values, "AI", "Model", ""),
                AITimeoutS: this.ReadSnapshotValue(values, "AI", "TimeoutS",
                    "600"),
                AIPrompt: this.ReadMultilineSnapshotValue(values, "AI",
                    "PromptEscaped", "Prompt",
                    AIService.DefaultGeneratePrompt),
                AIOptimizePrompt: this.ReadMultilineSnapshotValue(values,
                    "AI", "OptimizePromptEscaped", "OptimizePrompt",
                    AIService.DefaultOptimizePrompt),
                AISystemPrompt: this.ReadMultilineSnapshotValue(values,
                    "AI", "SystemPromptEscaped", "SystemPrompt",
                    AIService.DefaultSystemPrompt)
            })
        } finally readLease.Release()
    }

    Save(settings, expectedSnapshot?) {
        normalized := this.Normalize(settings)
        if IsSet(expectedSnapshot)
            this.WriteSnapshot(this.BuildSnapshot(normalized), expectedSnapshot)
        else
            this.WriteSnapshot(this.BuildSnapshot(normalized))
        return normalized
    }

    Normalize(settings) {
        return {
            UiLanguage: LocalizationService.NormalizeLanguage(
                this.GetProperty(settings, "UiLanguage", "auto")),
            UiFont: LocalizationService.NormalizeRequestedUiFont(
                this.GetProperty(settings, "UiFont", "auto")),
            Theme: UiThemeService.NormalizeTheme(
                this.GetProperty(settings, "Theme", "auto")),
            UiScalePercent: UiScaleService.NormalizePercent(
                this.GetProperty(settings, "UiScalePercent", 100)),
            ShowAtStartup: this.NormalizeBoolean(
                this.GetProperty(settings, "ShowAtStartup", false), false),
            RunAsAdministrator: this.NormalizeBoolean(
                this.GetProperty(settings, "RunAsAdministrator", true),
                true),
            CheckUpdatesOnStartup: this.NormalizeBoolean(
                this.GetProperty(settings, "CheckUpdatesOnStartup", true),
                true),
            EscapeCancelsRecording: this.NormalizeBoolean(
                this.GetProperty(settings, "EscapeCancelsRecording", true),
                true),
            EventBufferCapacity: this.NormalizeInteger(
                this.GetProperty(settings, "EventBufferCapacity", 1000),
                AppSettingsService.MinimumEventBufferCapacity,
                AppSettingsService.MaximumEventBufferCapacity, 1000),
            EventViewerAutoScroll: this.NormalizeBoolean(
                this.GetProperty(settings, "EventViewerAutoScroll", true),
                true),
            AIAddress: Trim(String(this.GetProperty(settings, "AIAddress",
                ""))),
            AIKey: Trim(String(this.GetProperty(settings, "AIKey", ""))),
            AIModel: Trim(String(this.GetProperty(settings, "AIModel",
                ""))),
            AITimeoutS: this.NormalizeInteger(
                this.GetProperty(settings, "AITimeoutS",
                AIService.DefaultTimeoutS), 1,
                    AIService.MaximumTimeoutS, AIService.DefaultTimeoutS),
            AIPrompt: AIService.NormalizeGeneratePrompt(this.GetProperty(
                settings, "AIPrompt", AIService.DefaultGeneratePrompt)),
            AIOptimizePrompt: AIService.NormalizeOptimizePrompt(
                this.GetProperty(settings, "AIOptimizePrompt",
                    AIService.DefaultOptimizePrompt)),
            AISystemPrompt: AIService.NormalizeSystemPrompt(this.GetProperty(
                settings, "AISystemPrompt", AIService.DefaultSystemPrompt))
        }
    }

    GetProperty(settings, propertyName, fallback) {
        if IsObject(settings) && settings.HasOwnProp(propertyName)
            return settings.%propertyName%
        return fallback
    }

    NormalizeBoolean(value, fallback) {
        try normalized := StrLower(Trim(String(value)))
        catch
            return !!fallback
        switch normalized {
            case "1", "true", "yes", "on": return true
            case "0", "false", "no", "off": return false
            default: return !!fallback
        }
    }

    NormalizeInteger(value, minimum, maximum, fallback) {
        try {
            text := Trim(String(value))
            if !RegExMatch(text, "^-?\d+$")
                return fallback
            normalized := Integer(text)
        } catch
            return fallback
        return normalized >= minimum && normalized <= maximum
            ? normalized : fallback
    }

    EncodeMultilineValue(value) {
        text := StrReplace(String(value), "\", "\\")
        text := StrReplace(text, "`r", "\r")
        return StrReplace(text, "`n", "\n")
    }

    DecodeMultilineValue(value) {
        text := String(value)
        result := ""
        index := 1
        while index <= StrLen(text) {
            character := SubStr(text, index, 1)
            if character != "\" || index == StrLen(text) {
                result .= character
                index++
                continue
            }
            escaped := SubStr(text, index + 1, 1)
            switch escaped {
                case "r": result .= "`r"
                case "n": result .= "`n"
                case "\": result .= "\"
                default: result .= "\" escaped
            }
            index += 2
        }
        return result
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
            if key == ""
                continue
            values[currentSection Chr(31) key] := Trim(
                SubStr(line, separator + 1), " `t")
        }
        return values
    }

    ReadSnapshotValue(values, section, key, fallback) {
        lookupKey := StrLower(String(section)) Chr(31) StrLower(String(key))
        return values.Has(lookupKey) ? values[lookupKey] : fallback
    }

    ReadMultilineSnapshotValue(values, section, escapedKey, legacyKey,
            fallback) {
        lookupKey := StrLower(String(section)) Chr(31)
            . StrLower(String(escapedKey))
        if values.Has(lookupKey)
            return this.DecodeMultilineValue(values[lookupKey])
        return this.ReadSnapshotValue(values, section, legacyKey, fallback)
    }

    GetSnapshot() {
        if !FileExist(this.SettingsPath)
            return ""
        return BoundedFileReader.ReadUtf8(this.SettingsPath,
            AppSettingsService.MaximumFileBytes,
            AppSettingsService.MaximumSnapshotCharacters, "设置文件")
    }

    BuildSnapshot(settings) {
        return "[Appearance]`r`n"
            . "UiLanguage=" settings.UiLanguage "`r`n"
            . "UiFont=" settings.UiFont "`r`n"
            . "Theme=" settings.Theme "`r`n"
            . "UiScalePercent=" settings.UiScalePercent "`r`n`r`n"
            . "[Startup]`r`n"
            . "ShowAtStartup=" (settings.ShowAtStartup ? 1 : 0) "`r`n"
            . "RunAsAdministrator="
                . (settings.RunAsAdministrator ? 1 : 0) "`r`n"
            . "CheckUpdatesOnStartup="
                . (settings.CheckUpdatesOnStartup ? 1 : 0) "`r`n`r`n"
            . "[Recording]`r`n"
            . "EscapeCancelsRecording="
                . (settings.EscapeCancelsRecording ? 1 : 0) "`r`n`r`n"
            . "[Events]`r`n"
            . "EventBufferCapacity=" settings.EventBufferCapacity "`r`n"
            . "EventViewerAutoScroll="
                . (settings.EventViewerAutoScroll ? 1 : 0) "`r`n"
            . "`r`n[AI]`r`n"
            . "Address=" settings.AIAddress "`r`n"
            . "Key=" settings.AIKey "`r`n"
            . "Model=" settings.AIModel "`r`n"
            . "TimeoutS=" settings.AITimeoutS "`r`n"
            . "PromptEscaped="
                . this.EncodeMultilineValue(settings.AIPrompt) "`r`n"
            . "OptimizePromptEscaped="
                . this.EncodeMultilineValue(settings.AIOptimizePrompt) "`r`n"
            . "SystemPromptEscaped="
                . this.EncodeMultilineValue(settings.AISystemPrompt) "`r`n"
    }

    WriteSnapshot(snapshot, expectedSnapshot?) {
        snapshot := String(snapshot)
        this.ValidateSnapshotSize(snapshot)
        writeLease := CrossProcessWriteLock.Acquire(this.SettingsPath)
        try {
            if IsSet(expectedSnapshot)
                    && this.GetSnapshot() != String(expectedSnapshot)
                throw Error("设置已被其他操作修改，未覆盖新内容。")
            directory := ""
            SplitPath(this.SettingsPath, , &directory)
            if directory != "" && !DirExist(directory)
                DirCreate(directory)
            temporaryPath := this.SettingsPath ".tmp-" A_TickCount "-"
                . Format("{:08X}", Random(0, 0xFFFFFFFF))
            output := ""
            try {
                output := FileOpen(temporaryPath, "w", "UTF-8-RAW")
                if !IsObject(output)
                    throw Error("无法写入设置。")
                output.Write(snapshot)
                output.Close()
                output := ""
                if IsSet(expectedSnapshot)
                        && this.GetSnapshot() != String(expectedSnapshot)
                    throw Error("设置已被其他操作修改，未覆盖新内容。")
                FileMove(temporaryPath, this.SettingsPath, 1)
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

    ValidateSnapshotSize(snapshot) {
        if StrLen(String(snapshot))
                > AppSettingsService.MaximumSnapshotCharacters
            throw Error("设置快照超过大小上限。")
        if StrPut(String(snapshot), "UTF-8") - 1
                > AppSettingsService.MaximumFileBytes
            throw Error("设置快照超过 UTF-8 字节上限。")
        return true
    }
}
