; 界面主题服务。主题请求值与实际值分离，auto 始终跟随 Windows 应用主题。

class UiThemeService {
    static RequestedTheme := "auto"
    static ActualTheme := "light"

    static Configure(theme := "auto") {
        this.RequestedTheme := this.NormalizeTheme(theme)
        this.ActualTheme := this.ResolveActualTheme(this.RequestedTheme)
        this.ApplyProcessPreference()
        return this.ActualTheme
    }

    static NormalizeTheme(theme, fallback := "auto") {
        return this.NormalizeRequestedTheme(theme, fallback)
    }

    static NormalizeRequestedTheme(theme, fallback := "auto") {
        if this.TryNormalizeRequestedTheme(theme, &normalized)
            return normalized
        return fallback
    }

    static TryNormalizeRequestedTheme(theme, &normalized) {
        normalized := ""
        try value := StrLower(Trim(String(theme)))
        catch
            return false
        switch value {
            case "", "auto", "system", "follow-system":
                normalized := "auto"
            case "light", "白", "浅色":
                normalized := "light"
            case "dark", "黑", "深色":
                normalized := "dark"
            default:
                return false
        }
        return true
    }

    static ResolveActualTheme(requestedTheme := "") {
        requestedTheme := this.NormalizeTheme(
            requestedTheme == "" ? this.RequestedTheme : requestedTheme,
            "auto")
        return requestedTheme == "auto" ? this.ReadSystemTheme()
            : requestedTheme
    }

    static GetRequestedTheme() => this.RequestedTheme
    static IsDark() => this.ActualTheme == "dark"

    static ReadSystemTheme() {
        try value := Integer(RegRead(
            "HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize",
            "AppsUseLightTheme", 1))
        catch
            return "light"
        return value == 0 ? "dark" : "light"
    }

    static HandleSystemSettingChange() {
        if this.RequestedTheme != "auto"
            return false
        newTheme := this.ReadSystemTheme()
        if newTheme == this.ActualTheme
            return false
        this.ActualTheme := newTheme
        this.ApplyProcessPreference()
        return true
    }

    static ApplyProcessPreference() {
        if VerCompare(A_OSVersion, "10.0.17763") < 0
            return false
        callback := this.GetUxThemeFunction(135)
        if !callback
            return false
        mode := VerCompare(A_OSVersion, "10.0.18362") >= 0
            ? (this.IsDark() ? 2 : 3) : (this.IsDark() ? 1 : 0)
        try DllCall(callback, "Int", mode)
        catch
            return false
        return true
    }

    static GetUxThemeFunction(ordinal) {
        static moduleHandle := 0
        static callbacks := Map()
        if callbacks.Has(ordinal)
            return callbacks[ordinal]
        if !moduleHandle {
            try moduleHandle := DllCall("kernel32\GetModuleHandleW",
                "WStr", "uxtheme.dll", "Ptr")
            if !moduleHandle
                try moduleHandle := DllCall("kernel32\LoadLibraryExW",
                    "WStr", "uxtheme.dll", "Ptr", 0, "UInt", 0x00000800,
                    "Ptr")
            if !moduleHandle
                try moduleHandle := DllCall("kernel32\LoadLibraryW",
                    "WStr", "uxtheme.dll", "Ptr")
        }
        callback := 0
        if moduleHandle
            try callback := DllCall("kernel32\GetProcAddress",
                "Ptr", moduleHandle, "Ptr", ordinal, "Ptr")
        callbacks[ordinal] := callback
        return callback
    }

    static AllowDarkModeForWindow(hwnd, dark := "") {
        if !hwnd || VerCompare(A_OSVersion, "10.0.17763") < 0
            return false
        if dark == ""
            dark := this.IsDark()
        callback := this.GetUxThemeFunction(133)
        if !callback
            return false
        try return !!DllCall(callback, "Ptr", hwnd, "Int", dark ? 1 : 0,
            "Int")
        catch
            return false
    }

    static GetPalette() {
        palette := this.IsDark() ? this.DarkPalette() : this.LightPalette()
        return {
            Window: palette["Window"], Surface: palette["Surface"],
            Input: palette["Input"], Toolbar: palette["Toolbar"],
            Divider: palette["Divider"], Text: palette["Text"],
            Muted: palette["MutedText"], Hint: palette["HintText"],
            Link: palette["Link"], ReadonlyText: palette["ReadonlyText"],
            Primary: palette["Primary"], Save: palette["Save"],
            Add: palette["Add"],
            Delete: palette["Delete"],
            AI: palette["AI"],
            AIButton: palette["AIButton"],
            AIButtonText: palette["AIButtonText"],
            Success: palette["Success"], Danger: palette["Danger"],
            Warning: palette["Warning"],
            DeleteDisabled: palette["DeleteDisabled"],
            Disabled: palette["DeleteDisabled"], Pause: palette["Pause"],
            PauseDisabled: palette["PauseDisabled"],
            Tooltip: palette["Tooltip"], TooltipText: palette["TooltipText"],
            Error: palette["Error"], ButtonText: palette["ButtonText"],
            ToolbarText: palette["ToolbarText"],
            DisabledButtonText: palette["DisabledButtonText"],
            DividerAccent: palette["DividerAccent"],
            DisplayIcon: palette["DisplayIcon"],
            LanguageIcon: palette["LanguageIcon"],
            FontIcon: palette["FontIcon"],
            ThemeIcon: palette["ThemeIcon"],
            StartupIcon: palette["StartupIcon"],
            RulesEventIcon: palette["RulesEventIcon"],
            AIIcon: palette["AIIcon"],
            StatusEnabledIcon: palette["StatusEnabledIcon"],
            StatusPausedIcon: palette["StatusPausedIcon"],
            CodeGutter: palette["CodeGutter"],
            CodeLineNumber: palette["CodeLineNumber"],
            CodeComment: palette["CodeComment"],
            CodeVariable: palette["CodeVariable"],
            CodeValue: palette["CodeValue"],
            CodeKeyword: palette["CodeKeyword"],
            CodeDirective: palette["CodeDirective"],
            CodeString: palette["CodeString"],
            CodeNumber: palette["CodeNumber"],
            CodeFunction: palette["CodeFunction"],
            CodeType: palette["CodeType"],
            CodeProperty: palette["CodeProperty"],
            CodeOperator: palette["CodeOperator"],
            CodePunctuation: palette["CodePunctuation"],
            CodeHotkey: palette["CodeHotkey"],
            CodeLabel: palette["CodeLabel"],
            CodeBuiltin: palette["CodeBuiltin"],
            CodeLiteral: palette["CodeLiteral"],
            CodeEscape: palette["CodeEscape"],
            CodeDiffRemoved: palette["CodeDiffRemoved"],
            CodeDiffAdded: palette["CodeDiffAdded"]
        }
    }

    static Color(name) {
        palette := this.IsDark() ? this.DarkPalette() : this.LightPalette()
        key := String(name)
        return palette.Has(key) ? palette[key] : "000000"
    }

    static ButtonIconColor(lightColor) {
        return this.IsDark() ? "none" : lightColor
    }

    static GetTooltipStyle() {
        return {
            Background: this.Color("Tooltip"),
            Text: this.Color("TooltipText"),
            FontSize: 10,
            MarginX: 12,
            MarginY: 8
        }
    }

    static DarkPalette() {
        static palette := Map(
            "Window", "1E1E1E", "Surface", "252526", "Input", "252526",
            "Toolbar", "333333", "Divider", "3A3A3A", "Tab", "2D2D30",
            "TabActive", "005A9E", "TabText", "E5E5E5",
            "TabActiveText", "FFFFFF",
            "Menu", "2B2B2B", "MenuHover", "414141",
            "Text", "FFFFFF", "MutedText", "B8BAB9", "HintText", "AFAFAF",
            "Link", "4EA1FF", "ReadonlyText", "D8D8D8",
            "Primary", "0078D7", "Save", "3F6B5B",
            "Add", "3F6B5B", "Delete", "6B4B4B",
            "AI", "F2C14E", "AIButton", "5A4610",
            "AIButtonText", "FFFFFF",
            "Success", "6ED7A0", "Danger", "FF8A8A",
            "Warning", "FBBF24",
            "DeleteDisabled", "554B4B", "Pause", "6B6244",
            "PauseDisabled", "555148", "Tooltip", "202020",
            "TooltipText", "E5E5E5", "Error", "FFB4AB",
            "DisabledText", "B8BAB9", "ButtonText", "FFFFFF",
            "ToolbarText", "FFFFFF", "DisabledButtonText", "D8D8D8",
            "DividerAccent", "AFAFAF", "DisplayIcon", "59B7FF",
            "LanguageIcon", "3B82F6", "FontIcon", "22C55E",
            "ThemeIcon", "F59E0B", "StartupIcon", "22C55E",
            "RulesEventIcon", "818CF8", "AIIcon", "EAB308",
            "StatusEnabledIcon", "03C078", "StatusPausedIcon", "F4A71D",
            "CodeGutter", "202020", "CodeLineNumber", "858585",
            "CodeComment", "858585", "CodeVariable", "D17A2A",
            "CodeValue", "6A8754", "CodeKeyword", "C586C0",
            "CodeDirective", "C586C0", "CodeString", "CE9178",
            "CodeNumber", "B5CEA8", "CodeFunction", "DCDCAA",
            "CodeType", "4EC9B0", "CodeProperty", "9CDCFE",
            "CodeOperator", "D4D4D4", "CodePunctuation", "D4D4D4",
            "CodeHotkey", "4FC1FF", "CodeLabel", "D7BA7D",
            "CodeBuiltin", "4EC9B0", "CodeLiteral", "569CD6",
            "CodeEscape", "D7BA7D", "CodeDiffRemoved", "4B2D32",
            "CodeDiffAdded", "244D3A")
        return palette
    }

    static LightPalette() {
        static palette := Map(
            "Window", "F1F5F9", "Surface", "F8FAFC", "Input", "FFFFFF",
            "Toolbar", "D0DEEC", "Divider", "C9D5E3", "Tab", "E1EAF4",
            "TabActive", "0F6CBD", "TabText", "334155",
            "TabActiveText", "FFFFFF",
            "Menu", "F8FAFC", "MenuHover", "DFEAF5",
            "Text", "1E293B", "MutedText", "526170", "HintText", "5F6F7F",
            "Link", "0969DA", "ReadonlyText", "334155",
            "Primary", "0F6CBD", "Save", "3F6B5B",
            "Add", "4B7F6B", "Delete", "A95F5F",
            "AI", "A15C00", "AIButton", "765600",
            "AIButtonText", "FFFFFF",
            "Success", "157A50", "Danger", "C23B3B",
            "Warning", "B45309",
            "DeleteDisabled", "787676", "Pause", "8C7138",
            "PauseDisabled", "777671", "Tooltip", "E2E8F0",
            "TooltipText", "0F172A", "Error", "B42318",
            "DisabledText", "667085", "ButtonText", "FFFFFF",
            "ToolbarText", "334155", "DisabledButtonText", "FFFFFF",
            "DividerAccent", "64748B", "DisplayIcon", "0369A1",
            "LanguageIcon", "1D4ED8", "FontIcon", "15803D",
            "ThemeIcon", "B45309", "StartupIcon", "15803D",
            "RulesEventIcon", "5B21B6", "AIIcon", "FDE68A",
            "StatusEnabledIcon", "157A50", "StatusPausedIcon", "B45309",
            "CodeGutter", "E8EDF2", "CodeLineNumber", "626A76",
            "CodeComment", "6B7280", "CodeVariable", "B45309",
            "CodeValue", "4D7C0F", "CodeKeyword", "AF00DB",
            "CodeDirective", "800080", "CodeString", "A31515",
            "CodeNumber", "087C50", "CodeFunction", "795E26",
            "CodeType", "21758D", "CodeProperty", "001080",
            "CodeOperator", "1E293B", "CodePunctuation", "1E293B",
            "CodeHotkey", "0070C1", "CodeLabel", "8F4E00",
            "CodeBuiltin", "21758D", "CodeLiteral", "0000FF",
            "CodeEscape", "8F4E00", "CodeDiffRemoved", "FFE1E3",
            "CodeDiffAdded", "DDF5E5")
        return palette
    }

    static GetComboThemeName() {
        return this.IsDark() ? "DarkMode_CFD" : "CFD"
    }

}

class RuleColorPalette {
    static Presets() {
        return [
            {Key: "sage", Name: "雾松绿"},
            {Key: "mist", Name: "青灰蓝"},
            {Key: "lavender", Name: "薰衣草紫"},
            {Key: "rose", Name: "烟粉"},
            {Key: "amber", Name: "浅琥珀"},
            {Key: "teal", Name: "静谧青"},
            {Key: "pearl", Name: "珍珠灰"}
        ]
    }

    static IsValidKey(key) {
        key := StrLower(Trim(String(key)))
        for preset in this.Presets() {
            if preset.Key == key
                return true
        }
        return false
    }

    static NormalizeKey(key) {
        key := StrLower(Trim(String(key)))
        return this.IsValidKey(key) ? key : ""
    }

    static Color(key) {
        key := this.NormalizeKey(key)
        if key == ""
            return UiThemeService.Color("Surface")
        palette := UiThemeService.IsDark() ? this.DarkColors()
            : this.LightColors()
        return palette[key]
    }

    static DarkColors() {
        static colors := Map(
            "sage", "496B59", "mist", "41647D",
            "lavender", "62567D", "rose", "7A5060",
            "amber", "76633F", "teal", "3F6D70",
            "pearl", "5D5E58")
        return colors
    }

    static LightColors() {
        static colors := Map(
            "sage", "D8EBDD", "mist", "D9E9F5",
            "lavender", "E5DDF3", "rose", "F1DDE2",
            "amber", "F2E5C8", "teal", "D5EBEA",
            "pearl", "E4E5E1")
        return colors
    }
}
