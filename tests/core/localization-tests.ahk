#Requires AutoHotkey v2.0 64-bit
#SingleInstance Off
#Warn All, StdOut

#Include ..\TestSupport.ahk
#Include ..\..\src\Localization\EnglishStrings.ahk
#Include ..\..\src\Localization\TraditionalHongKongStrings.ahk
#Include ..\..\src\Localization\TraditionalTaiwanStrings.ahk
#Include ..\..\src\Localization\JapaneseStrings.ahk
#Include ..\..\src\Localization\VietnameseStrings.ahk
#Include ..\..\src\Localization\KoreanStrings.ahk
#Include ..\..\src\Localization\SpanishStrings.ahk
#Include ..\..\src\Localization\FrenchStrings.ahk
#Include ..\..\src\Localization\PortugueseBrazilStrings.ahk
#Include ..\..\src\Localization\RussianStrings.ahk
#Include ..\..\src\Localization\GermanStrings.ahk
#Include ..\..\src\Localization\ItalianStrings.ahk
#Include ..\..\src\Localization\LocalizationService.ahk

DecodeAhkString(rawText) {
    decoded := ""
    index := 1
    while index <= StrLen(rawText) {
        character := SubStr(rawText, index, 1)
        if character != "``" {
            decoded .= character
            index++
            continue
        }
        index++
        if index > StrLen(rawText) {
            decoded .= "``"
            break
        }
        escaped := SubStr(rawText, index, 1)
        switch escaped {
            case "n": decoded .= "`n"
            case "r": decoded .= "`r"
            case "t": decoded .= "`t"
            case "b": decoded .= "`b"
            case "v": decoded .= "`v"
            case "a": decoded .= "`a"
            case "f": decoded .= "`f"
            default: decoded .= escaped
        }
        index++
    }
    return decoded
}

ReadAhkLiteral(sourceText, &cursor) {
    if SubStr(sourceText, cursor, 1) != '"'
        throw Error("本地化字符串表达式必须以双引号开始")
    cursor++
    rawText := ""
    while cursor <= StrLen(sourceText) {
        character := SubStr(sourceText, cursor, 1)
        if character == '"' {
            if SubStr(sourceText, cursor + 1, 1) == '"' {
                rawText .= '"'
                cursor += 2
                continue
            }
            cursor++
            return DecodeAhkString(rawText)
        }
        if character == "``" && cursor < StrLen(sourceText) {
            rawText .= character SubStr(sourceText, cursor + 1, 1)
            cursor += 2
            continue
        }
        rawText .= character
        cursor++
    }
    throw Error("本地化调用中存在未闭合的字符串")
}

CollectLiteralLocalizationTemplates(sourceText, templates) {
    searchPosition := 1
    while RegExMatch(sourceText, 'i)\bTr\s*\(\s*"', &match,
        searchPosition) {
        cursor := match.Pos(0) + match.Len(0) - 1
        template := ""
        loop {
            template .= ReadAhkLiteral(sourceText, &cursor)
            while cursor <= StrLen(sourceText)
                    && RegExMatch(SubStr(sourceText, cursor, 1), "\s")
                cursor++
            if SubStr(sourceText, cursor, 1) != "."
                break
            cursor++
            while cursor <= StrLen(sourceText)
                    && RegExMatch(SubStr(sourceText, cursor, 1), "\s")
                cursor++
            if SubStr(sourceText, cursor, 1) != '"'
                throw Error("Tr() 的稳定键不得与动态表达式拼接")
        }
        if template != ""
            templates[template] := true
        searchPosition := cursor
    }
}

CollectProductionTemplates(projectRoot) {
    templates := Map()
    templates.CaseSense := "On"
    CollectLiteralLocalizationTemplates(
        FileRead(projectRoot "\键鼠重映射小助手.ahk", "UTF-8"), templates)
    for sourceRoot in [projectRoot "\app", projectRoot "\src"] {
        Loop Files, sourceRoot "\*.ahk", "FR" {
            if InStr(A_LoopFileFullPath, "\Localization\")
                continue
            CollectLiteralLocalizationTemplates(
                FileRead(A_LoopFileFullPath, "UTF-8"), templates)
        }
    }
    return templates
}

PlaceholderCounts(template) {
    counts := Map()
    position := 1
    while RegExMatch(template, "\{(\d+)(?::[^}]*)?\}", &match,
        position) {
        key := match[1]
        counts[key] := counts.Has(key) ? counts[key] + 1 : 1
        position := match.Pos(0) + match.Len(0)
    }
    return counts
}

PlaceholderContractsMatch(sourceTemplate, translatedTemplate) {
    sourceCounts := PlaceholderCounts(sourceTemplate)
    translatedCounts := PlaceholderCounts(translatedTemplate)
    if sourceCounts.Count != translatedCounts.Count
        return false
    for key, count in sourceCounts {
        if !translatedCounts.Has(key) || translatedCounts[key] != count
            return false
    }
    return true
}

RunLocalizationTests() {
    projectRoot := A_ScriptDir "\..\.."
    expectedCodes := ["zh-CN", "zh-HK", "zh-TW", "en-US", "ja-JP",
        "vi-VN", "ko-KR", "es-ES", "fr-FR", "pt-BR", "ru-RU",
        "de-DE", "it-IT"]
    actualCodes := LocalizationService.GetSupportedLanguageCodes()
    AssertEqual(expectedCodes.Length, actualCodes.Length,
        "支持的语言数量错误")
    for index, expectedCode in expectedCodes
        AssertEqual(expectedCode, actualCodes[index],
            "语言顺序错误：" index)

    choices := LocalizationService.GetLanguageChoices()
    AssertEqual(expectedCodes.Length + 1, choices.Length,
        "语言下拉框没有包含跟随系统和全部语言")
    AssertEqual("auto", choices[1].Code, "语言下拉框首项错误")
    for index, expectedCode in expectedCodes
        AssertEqual(expectedCode, choices[index + 1].Code,
            "语言下拉框代码错误：" index)

    aliases := Map(
        "zh-Hans", "zh-CN", "zh-Hant-HK", "zh-HK",
        "zh-MO", "zh-HK", "zh-Hant", "zh-TW", "zh-TW", "zh-TW",
        "en-GB", "en-US", "ja", "ja-JP", "vi", "vi-VN",
        "ko", "ko-KR", "es-MX", "es-ES", "fr-CA", "fr-FR",
        "pt-PT", "pt-BR", "ru", "ru-RU", "de-AT", "de-DE",
        "it-CH", "it-IT")
    for alias, expected in aliases
        AssertEqual(expected,
            LocalizationService.NormalizeLanguage(alias, "invalid"),
            "语言别名归一化错误：" alias)
    AssertEqual("auto", LocalizationService.NormalizeLanguage("xx-YY"),
        "未知语言没有回退 auto")

    englishCatalog := EnglishStrings.Create()
    productionTemplates := CollectProductionTemplates(projectRoot)
    missingTemplates := []
    staleTemplates := []
    for template in productionTemplates {
        if !englishCatalog.Has(template)
            missingTemplates.Push(template)
    }
    for template in englishCatalog {
        if !productionTemplates.Has(template)
            staleTemplates.Push(template)
    }
    AssertTrue(!missingTemplates.Length,
        "英文目录缺少：" (missingTemplates.Length
            ? missingTemplates[1] : ""))
    AssertTrue(!staleTemplates.Length,
        "英文目录包含已失去调用点的旧键：" (staleTemplates.Length
            ? staleTemplates[1] : ""))

    for sourceTemplate, englishTemplate in englishCatalog {
        AssertTrue(!RegExMatch(englishTemplate, "[\x{3400}-\x{9FFF}]"),
            "英文词条仍含中文：" sourceTemplate)
        AssertTrue(PlaceholderContractsMatch(sourceTemplate,
            englishTemplate), "英文占位符不一致：" sourceTemplate)
    }

    for language in expectedCodes {
        catalog := LocalizationService.GetCatalog(language)
        if language == "zh-CN" {
            AssertEqual(0, catalog.Count, "简体中文目录应直接使用稳定键")
            continue
        }
        AssertEqual(englishCatalog.Count, catalog.Count,
            language " 目录条目数量错误")
        for sourceTemplate in englishCatalog {
            AssertTrue(catalog.Has(sourceTemplate),
                language " 缺少词条：" sourceTemplate)
            AssertTrue(PlaceholderContractsMatch(sourceTemplate,
                catalog[sourceTemplate]),
                language " 占位符不一致：" sourceTemplate)
            AssertTrue(!RegExMatch(catalog[sourceTemplate],
                "__[0-9A-Fa-f]{6,}|[0-9A-Fa-f]{6,}__"),
                language " 词条含生成残片：" sourceTemplate)
        }
    }

    criticalTranslations := Map(
        "zh-HK", Map("序号", "序號", "跟随系统", "跟隨系統",
            "浅色", "淺色", "深色", "深色", "右侧 Win", "右側 Win"),
        "zh-TW", Map("序号", "序號", "跟随系统", "跟隨系統",
            "浅色", "淺色", "深色", "深色", "右侧 Win", "右側 Win"),
        "fr-FR", Map("新建映射", "Nouveau mappage",
            "右侧 Win", "Win droite"),
        "de-DE", Map("全部事件", "Alle Ereignisse",
            "左侧 Shift", "Linke Umschalttaste"),
        "it-IT", Map("浅色", "Chiaro", "深色", "Scuro"),
        "ja-JP", Map("序号", "番号", "右侧 Win", "右 Win"),
        "ko-KR", Map("序号", "번호", "右侧 Win", "오른쪽 Win"),
        "pt-BR", Map("序号", "Nº", "浅色", "Claro"),
        "ru-RU", Map("新建映射", "Новое сопоставление",
            "右侧 Win", "Правая Win"),
        "es-ES", Map("左侧 Shift", "Shift izquierdo",
            "右侧 Shift", "Shift derecho"),
        "vi-VN", Map("序号", "STT", "滚轮", "Con lăn chuột"))
    for language, expectedTerms in criticalTranslations {
        catalog := LocalizationService.GetCatalog(language)
        for sourceTemplate, expectedTranslation in expectedTerms
            AssertEqual(expectedTranslation, catalog[sourceTemplate],
                language " 高风险术语回退：" sourceTemplate)
    }

    hongKongCatalog := LocalizationService.GetCatalog("zh-HK")
    taiwanCatalog := LocalizationService.GetCatalog("zh-TW")
    regionalDifferenceCount := 0
    for sourceTemplate, hongKongTranslation in hongKongCatalog {
        if hongKongTranslation != taiwanCatalog[sourceTemplate]
            regionalDifferenceCount++
    }
    AssertTrue(regionalDifferenceCount >= 20,
        "港繁与台繁目录没有保持足够的地区用语差异")

    fontSpecs := Map(
        "zh-CN", ["Noto Sans CJK SC", "NotoSansCJK.ttc", "Microsoft YaHei UI"],
        "zh-HK", ["Noto Sans CJK HK", "NotoSansCJK.ttc", "Microsoft JhengHei UI"],
        "zh-TW", ["Noto Sans CJK TC", "NotoSansCJK.ttc", "Microsoft JhengHei UI"],
        "ja-JP", ["Noto Sans CJK JP", "NotoSansCJK.ttc", "Yu Gothic UI"],
        "ko-KR", ["Noto Sans CJK KR", "NotoSansCJK.ttc", "Malgun Gothic"],
        "en-US", ["Noto Sans", "NotoSans-Variable.ttf", "Segoe UI"])
    for language, expected in fontSpecs {
        spec := LocalizationService.GetLanguageUiFontSpec(language)
        AssertEqual(expected[1], spec.Primary,
            language " 首选内容字体错误")
        AssertEqual(expected[2], spec.Asset,
            language " 随包字体资源错误")
        AssertEqual(expected[3], spec.System,
            language " 系统界面字体错误")
    }
    for language in ["zh-CN", "zh-HK", "zh-TW", "ja-JP", "ko-KR"] {
        LocalizationService.Configure(language, "auto")
        AssertTrue(LocalizationService.UsesCompactLayout(),
            language " 没有使用紧凑布局")
    }
    LocalizationService.Configure("de-DE", "auto")
    AssertTrue(!LocalizationService.UsesCompactLayout(),
        "德语不应使用紧凑布局")
    AssertEqual("Assistent für Tastatur- und Maus-Neuzuordnung",
        Tr("键鼠重映射小助手"),
        "德语主标题翻译错误")

    LocalizationService.Configure("en-US", "auto")
    rendered := Tr("已导出 {1} 条规则：{2}", 3, "rules.json")
    LocalizationService.Configure("ja-JP")
    AssertEqual(Tr("已导出 {1} 条规则：{2}", 3, "rules.json"),
        LocalizationService.TranslateRenderedTextBetweenLanguages(
            rendered, "en-US", "ja-JP"),
        "带占位符动态文案没有从英文热切换为日文")

    LocalizationService.ShutdownUiFonts()
    AssertEqual(0,
        LocalizationService.GetLoadedPrivateUiFontResourceCount(),
        "退出后仍保留私有字体资源")
    WriteTestSuccess("localization")
}

try {
    RunLocalizationTests()
    ExitApp(0)
} catch as testError {
    FileAppend(testError.Message "`n" testError.Stack "`n", "**")
    ExitApp(1)
}
