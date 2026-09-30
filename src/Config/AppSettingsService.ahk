class AppSettingsService {
    static MaximumFileBytes := 64 * 1024
    static MaximumSnapshotCharacters := 64 * 1024
    static MinimumEventBufferCapacity := 100
    static MaximumEventBufferCapacity := 10000
    static DefaultKeystrokeOsdPosition := "bottom-left"
    static DefaultKeystrokeOsdOffsetX := 0
    static DefaultKeystrokeOsdOffsetY := 0
    static DefaultKeystrokeOsdOffsetUp := 0
    static DefaultKeystrokeOsdOffsetDown := 0
    static DefaultKeystrokeOsdOffsetLeft := 0
    static DefaultKeystrokeOsdOffsetRight := 0
    static DefaultKeystrokeOsdFontSize := 12
    static DefaultKeystrokeOsdBgColor := "2e3032"
    static DefaultKeystrokeOsdTextColor := "b3aea8"
    static DefaultKeystrokeOsdDisplayTimeMs := 1000

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
                EnableKeystrokeOsd: this.ReadSnapshotValue(values,
                    "Startup", "EnableKeystrokeOsd", "0"),
                CheckInterceptionOnStartup: this.ReadSnapshotValue(values,
                    "Interception", "CheckOnStartup", "1"),
                EscapeCancelsRecording: this.ReadSnapshotValue(values, "Recording",
                    "EscapeCancelsRecording", "1"),
                EventBufferCapacity: this.ReadSnapshotValue(values, "Events",
                    "EventBufferCapacity", "1000"),
                EventViewerAutoScroll: this.ReadSnapshotValue(values, "Events",
                    "EventViewerAutoScroll", "0"),
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
                    AIService.DefaultSystemPrompt),
                KeystrokeOsdPosition: this.ReadSnapshotValue(values, "KeystrokeOsd",
                    "Position", AppSettingsService.DefaultKeystrokeOsdPosition),
                KeystrokeOsdOffsetX: this.ReadSnapshotValue(values, "KeystrokeOsd",
                    "OffsetX", String(Integer(this.ReadSnapshotValue(values, "KeystrokeOsd", "OffsetRight", "0")) - Integer(this.ReadSnapshotValue(values, "KeystrokeOsd", "OffsetLeft", "0")))),
                KeystrokeOsdOffsetY: this.ReadSnapshotValue(values, "KeystrokeOsd",
                    "OffsetY", String(Integer(this.ReadSnapshotValue(values, "KeystrokeOsd", "OffsetDown", "0")) - Integer(this.ReadSnapshotValue(values, "KeystrokeOsd", "OffsetUp", "0")))),
                KeystrokeOsdOffsetUp: this.ReadSnapshotValue(values, "KeystrokeOsd",
                    "OffsetUp", "0"),
                KeystrokeOsdOffsetDown: this.ReadSnapshotValue(values, "KeystrokeOsd",
                    "OffsetDown", "0"),
                KeystrokeOsdOffsetLeft: this.ReadSnapshotValue(values, "KeystrokeOsd",
                    "OffsetLeft", "0"),
                KeystrokeOsdOffsetRight: this.ReadSnapshotValue(values, "KeystrokeOsd",
                    "OffsetRight", "0"),
                KeystrokeOsdFontSize: this.ReadSnapshotValue(values, "KeystrokeOsd",
                    "FontSize", String(AppSettingsService.DefaultKeystrokeOsdFontSize)),
                KeystrokeOsdBgColor: this.ReadSnapshotValue(values, "KeystrokeOsd",
                    "BgColor", AppSettingsService.DefaultKeystrokeOsdBgColor),
                KeystrokeOsdTextColor: this.ReadSnapshotValue(values, "KeystrokeOsd",
                    "TextColor", AppSettingsService.DefaultKeystrokeOsdTextColor),
                KeystrokeOsdDisplayTimeMs: this.ReadSnapshotValue(values, "KeystrokeOsd",
                    "DisplayTimeMs", String(AppSettingsService.DefaultKeystrokeOsdDisplayTimeMs))
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
            EnableKeystrokeOsd: this.NormalizeBoolean(
                this.GetProperty(settings, "EnableKeystrokeOsd", false),
                false),
            CheckInterceptionOnStartup: this.NormalizeBoolean(
                this.GetProperty(settings, "CheckInterceptionOnStartup", true),
                true),
            EscapeCancelsRecording: this.NormalizeBoolean(
                this.GetProperty(settings, "EscapeCancelsRecording", true),
                true),
            EventBufferCapacity: this.NormalizeInteger(
                this.GetProperty(settings, "EventBufferCapacity", 1000),
                AppSettingsService.MinimumEventBufferCapacity,
                AppSettingsService.MaximumEventBufferCapacity, 1000),
            EventViewerAutoScroll: this.NormalizeBoolean(
                this.GetProperty(settings, "EventViewerAutoScroll", false),
                false),
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
                settings, "AISystemPrompt", AIService.DefaultSystemPrompt)),
            KeystrokeOsdPosition: this.NormalizeOsdPosition(
                this.GetProperty(settings, "KeystrokeOsdPosition",
                    AppSettingsService.DefaultKeystrokeOsdPosition)),
            KeystrokeOsdOffsetX: (rawOffsetX := this.NormalizeInteger(
                this.GetProperty(settings, "KeystrokeOsdOffsetX",
                    (this.GetProperty(settings, "KeystrokeOsdOffsetRight", 0) - this.GetProperty(settings, "KeystrokeOsdOffsetLeft", 0))),
                -1000, 1000, AppSettingsService.DefaultKeystrokeOsdOffsetX)),
            KeystrokeOsdOffsetY: (rawOffsetY := this.NormalizeInteger(
                this.GetProperty(settings, "KeystrokeOsdOffsetY",
                    (this.GetProperty(settings, "KeystrokeOsdOffsetDown", 0) - this.GetProperty(settings, "KeystrokeOsdOffsetUp", 0))),
                -1000, 1000, AppSettingsService.DefaultKeystrokeOsdOffsetY)),
            KeystrokeOsdOffsetUp: this.NormalizeInteger(
                this.GetProperty(settings, "KeystrokeOsdOffsetUp",
                    rawOffsetY < 0 ? -rawOffsetY : 0),
                -1000, 1000, AppSettingsService.DefaultKeystrokeOsdOffsetUp),
            KeystrokeOsdOffsetDown: this.NormalizeInteger(
                this.GetProperty(settings, "KeystrokeOsdOffsetDown",
                    rawOffsetY > 0 ? rawOffsetY : 0),
                -1000, 1000, AppSettingsService.DefaultKeystrokeOsdOffsetDown),
            KeystrokeOsdOffsetLeft: this.NormalizeInteger(
                this.GetProperty(settings, "KeystrokeOsdOffsetLeft",
                    rawOffsetX < 0 ? -rawOffsetX : 0),
                -1000, 1000, AppSettingsService.DefaultKeystrokeOsdOffsetLeft),
            KeystrokeOsdOffsetRight: this.NormalizeInteger(
                this.GetProperty(settings, "KeystrokeOsdOffsetRight",
                    rawOffsetX > 0 ? rawOffsetX : 0),
                -1000, 1000, AppSettingsService.DefaultKeystrokeOsdOffsetRight),
            KeystrokeOsdFontSize: this.NormalizeInteger(
                this.GetProperty(settings, "KeystrokeOsdFontSize",
                    AppSettingsService.DefaultKeystrokeOsdFontSize),
                8, 72, AppSettingsService.DefaultKeystrokeOsdFontSize),
            KeystrokeOsdBgColor: this.NormalizeColor(
                this.GetProperty(settings, "KeystrokeOsdBgColor",
                    AppSettingsService.DefaultKeystrokeOsdBgColor),
                AppSettingsService.DefaultKeystrokeOsdBgColor),
            KeystrokeOsdTextColor: this.NormalizeColor(
                this.GetProperty(settings, "KeystrokeOsdTextColor",
                    AppSettingsService.DefaultKeystrokeOsdTextColor),
                AppSettingsService.DefaultKeystrokeOsdTextColor),
            KeystrokeOsdDisplayTimeMs: this.NormalizeInteger(
                this.GetProperty(settings, "KeystrokeOsdDisplayTimeMs",
                    AppSettingsService.DefaultKeystrokeOsdDisplayTimeMs),
                200, 10000, AppSettingsService.DefaultKeystrokeOsdDisplayTimeMs)
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
                . (settings.CheckUpdatesOnStartup ? 1 : 0) "`r`n"
            . "EnableKeystrokeOsd="
                . (settings.EnableKeystrokeOsd ? 1 : 0) "`r`n`r`n"
            . "[Interception]`r`n"
            . "CheckOnStartup="
                . (settings.CheckInterceptionOnStartup ? 1 : 0) "`r`n`r`n"
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
                . this.EncodeMultilineValue(settings.AISystemPrompt) "`r`n`r`n"
            . "[KeystrokeOsd]`r`n"
            . "Position=" settings.KeystrokeOsdPosition "`r`n"
            . "OffsetX=" settings.KeystrokeOsdOffsetX "`r`n"
            . "OffsetY=" settings.KeystrokeOsdOffsetY "`r`n"
            . "OffsetUp=" settings.KeystrokeOsdOffsetUp "`r`n"
            . "OffsetDown=" settings.KeystrokeOsdOffsetDown "`r`n"
            . "OffsetLeft=" settings.KeystrokeOsdOffsetLeft "`r`n"
            . "OffsetRight=" settings.KeystrokeOsdOffsetRight "`r`n"
            . "FontSize=" settings.KeystrokeOsdFontSize "`r`n"
            . "BgColor=" settings.KeystrokeOsdBgColor "`r`n"
            . "TextColor=" settings.KeystrokeOsdTextColor "`r`n"
            . "DisplayTimeMs=" settings.KeystrokeOsdDisplayTimeMs "`r`n"
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

    NormalizeOsdPosition(value) {
        static valid := Map(
            "bottom-left", 1, "bottom-center", 1, "bottom-right", 1,
            "center-left", 1, "center", 1, "center-right", 1,
            "top-left", 1, "top-center", 1, "top-right", 1
        )
        norm := StrLower(Trim(String(value)))
        return valid.Has(norm) ? norm : AppSettingsService.DefaultKeystrokeOsdPosition
    }

    NormalizeColor(value, fallback := "2e3032") => AppSettingsService.NormalizeColor(value, fallback)

    NormalizeHexColor(value, fallback) => AppSettingsService.NormalizeColor(value, fallback)

    static NormalizeColor(value, fallback := "2e3032") {
        cleaned := Trim(String(value))
        if RegExMatch(cleaned, "i)^(?:rgb\s*\(\s*)?(\d{1,3})\s*[, ]\s*(\d{1,3})\s*[, ]\s*(\d{1,3})\s*\)?$", &m) {
            r := Integer(m[1]), g := Integer(m[2]), b := Integer(m[3])
            if r >= 0 && r <= 255 && g >= 0 && g <= 255 && b >= 0 && b <= 255
                return Format("{:02x}{:02x}{:02x}", r, g, b)
        }
        hexStr := RegExReplace(cleaned, "^#")
        if RegExMatch(hexStr, "^[0-9a-fA-F]{6}$")
            return StrLower(hexStr)
        if RegExMatch(hexStr, "^[0-9a-fA-F]{3}$") {
            c1 := SubStr(hexStr, 1, 1), c2 := SubStr(hexStr, 2, 1), c3 := SubStr(hexStr, 3, 1)
            return StrLower(c1 . c1 . c2 . c2 . c3 . c3)
        }
        return StrLower(String(fallback))
    }

    static NormalizeHexColor(value, fallback) => AppSettingsService.NormalizeColor(value, fallback)
}
