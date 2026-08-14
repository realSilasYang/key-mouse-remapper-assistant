#Requires AutoHotkey v2.0 64-bit
#SingleInstance Off
#Warn All, StdOut

#Include ..\..\src\UI\UiThemeService.ahk
#Include ..\..\app\KeyMouseRemapperAssistantApp.ahk

try {
    service := RuleColorServiceProbe()
    window := RuleColorWindowProbe()
    app := RuleColorAppProbe(service, window)

    RuleColorAppAssert(app.SetRuleColors(["rule-a", "rule-b", "rule-a"],
            "rose"),
        "The batch sequence-dot update failed.")
    RuleColorAppAssert(service.SaveCount == 1
            && app.RuleColors.Count == 2
            && app.RuleColors["rule-a"] == "rose"
            && app.RuleColors["rule-b"] == "rose"
            && window.RefreshCount == 1
            && window.LastRefreshedIds.Length == 2,
        "The batch sequence-dot update did not save and redraw once.")
    RuleColorAppAssert(app.GetCommonRuleColor(["rule-a", "rule-b"])
            == "rose",
        "A common sequence-dot color was not detected.")

    RuleColorAppAssert(app.SetRuleColors(["rule-b"], "teal")
            && app.GetCommonRuleColor(["rule-a", "rule-b"]) == "",
        "Mixed sequence-dot colors incorrectly reported a common color.")
    RuleColorAppAssert(app.SetRuleColors(["rule-a", "rule-b"], "")
            && app.RuleColors.Count == 0 && service.SaveCount == 3,
        "The batch clear command did not remove both colors in one save.")

    app.RuleColors["old-name"] := "sage"
    RuleColorAppAssert(app.MigrateRuleColor("old-name", "new-name")
            && !app.RuleColors.Has("old-name")
            && app.RuleColors["new-name"] == "sage",
        "A renamed rule did not migrate its sequence-dot color.")
    RuleColorAppAssert(app.ForgetRuleColors(["new-name"])
            && !app.RuleColors.Has("new-name"),
        "A deleted rule retained its sequence-dot color.")
    FileAppend("PASS rule color app`n", "*")
} catch as testError {
    FileAppend(testError.Message "`n" testError.Stack "`n", "**")
    ExitApp(1)
}
ExitApp(0)

Tr(text, arguments*) {
    return arguments.Length ? Format(text, arguments*) : String(text)
}

RuleColorAppAssert(value, message) {
    if !value
        throw Error(message)
}

class RuleColorAppProbe extends KeyMouseRemapperAssistantApp {
    __New(service, window) {
        this.RuleAppearanceService := service
        this.RuleColors := Map()
        this.Window := window
    }
}

class RuleColorServiceProbe {
    __New() {
        this.SaveCount := 0
    }

    Save(colors) {
        this.SaveCount++
        return colors.Clone()
    }
}

class RuleColorWindowProbe {
    __New() {
        this.RefreshCount := 0
        this.LastRefreshedIds := []
        this.LastStatus := ""
    }

    RefreshMappingColors(mappingIds) {
        this.RefreshCount++
        this.LastRefreshedIds := mappingIds.Clone()
        return mappingIds.Length
    }

    SetStatus(text, isError := false) {
        this.LastStatus := String(text)
        return true
    }
}
