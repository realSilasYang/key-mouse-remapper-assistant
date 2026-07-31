; de-DE 本地化词条目录。
; 简体中文原文是稳定键；本目录与其它语言保持完全相同的键集合。

class GermanStrings {
    static Create() {
        catalog := Map()
        catalog.CaseSense := "On"
        catalog.Set("按下", "Drücken")
        catalog.Set(
            "键鼠重映射小助手",
                "Assistent für Tastatur- und Maus-Neuzuordnung")
        catalog.Set(
            "新增",
                "Hinzufügen")
        catalog.Set(
            "新增映射",
                "Zuordnung hinzufügen")
        catalog.Set(
            "删除",
                "Löschen")
        catalog.Set(
            "暂停",
                "Pausieren")
        catalog.Set(
            "恢复",
                "Fortsetzen")
        catalog.Set(
            "序号",
                "Nr.")
        catalog.Set(
            "来源按键",
                "Quellschlüssel")
        catalog.Set(
            "映射结果",
                "Zugeordnetes Ergebnis")
        catalog.Set(
            "生效范围",
                "Umfang")
        catalog.Set(
            "设计目的",
                "Zweck")
        catalog.Set(
            "新建映射",
                "Neue Zuordnung")
        catalog.Set(
            "映射为",
                "Zuordnen zu")
        catalog.Set(
            "点击录制来源按键",
                "Klicken Sie hier, um Quellschlüssel aufzuzeichnen")
        catalog.Set(
            "点击录制目标按键",
                "Klicken Sie, um Zielschlüssel aufzuzeichnen")
        catalog.Set(
            "保存映射",
                "Speichern")
        catalog.Set(
            "清空",
                "Klar")
        catalog.Set(
            "准备就绪",
                "Bereit")
        catalog.Set(
            "请按下按键 · Esc 取消",
                "Drücken Sie zum Abbrechen die Tasten · Esc")
        catalog.Set(
            "编辑映射代码",
                "Zuordnungscode bearbeiten")
        catalog.Set(
            "新增映射代码",
                "Zuordnungscode hinzufügen")
        catalog.Set(
            "元数据说明",
                "Metadatenreferenz")
        catalog.Set(
            "RuleSpec 外壳版本，当前必须为 2。",
                "Version der RuleSpec-Hülle; sie muss derzeit 2 sein.")
        catalog.Set(
            "规则模式，当前必须为 managed。",
                "Regelmodus; er muss derzeit managed sein.")
        catalog.Set(
            "映射的唯一编号，必须与 RuleSpec 的 id 一致。",
                "Eindeutige Zuordnungs-ID; sie muss mit der RuleSpec-id übereinstimmen.")
        catalog.Set(
            "结构化 RuleSpec JSON 的开始标记。",
                "Startmarkierung des strukturierten RuleSpec-JSON.")
        catalog.Set(
            "注释化 JSON；可编辑来源、条件、显示信息和输出动作。",
                "Auskommentiertes JSON; Quelle, Bedingungen, Anzeige und Ausgaben können bearbeitet werden.")
        catalog.Set(
            "结构化 RuleSpec JSON 的结束标记。",
                "Endmarkierung des strukturierten RuleSpec-JSON.")
        catalog.Set(
            "规范化 RuleSpec JSON 的 SHA-256 摘要。",
                "SHA-256-Prüfsumme des normalisierten RuleSpec-JSON.")
        catalog.Set(
            "生成区只含说明注释，不包含可执行 AHK。",
                "Der generierte Bereich enthält nur Erläuterungen und kein ausführbares AHK.")
        catalog.Set(
            "整个映射块只允许注释化 RuleSpec JSON；右侧说明仅供参考，不会保存到代码。",
                "Der gesamte Zuordnungsblock erlaubt nur auskommentiertes RuleSpec-JSON. Die Hinweise rechts werden nicht gespeichert.")
        catalog.Set(
            "代码修改尚未保存，确定放弃吗？",
                "Der Code enthält nicht gespeicherte Änderungen. Sie wegwerfen?")
        catalog.Set(
            "放弃修改",
                "Änderungen verwerfen")
        catalog.Set(
            "显示主界面",
                "Hauptfenster anzeigen")
        catalog.Set(
            "重新加载",
                "Neu laden")
        catalog.Set(
            "以管理员身份重新启动",
                "Starten Sie als Administrator neu")
        catalog.Set(
            "管理员模式（当前）",
                "Administratormodus (aktiv)")
        catalog.Set(
            "无法以管理员身份重新启动（错误代码 {1}）。",
                "Konnte nicht als Administrator neu gestartet werden (Fehler {1}).")
        catalog.Set(
            "事件查看器",
                "Ereignisse")
        catalog.Set("事件详情", "Ereignisdetails")
        catalog.Set("事件：{1}", "Ereignis: {1}")
        catalog.Set("类别：{1}", "Kategorie: {1}")
        catalog.Set("时间：{1}", "Zeit: {1}")
        catalog.Set("来源：{1}", "Quelle: {1}")
        catalog.Set("结果：{1}", "Ergebnis: {1}")
        catalog.Set("详情：{1}", "Details: {1}")
        catalog.Set("按键名称：{1}", "Tastenname: {1}")
        catalog.Set("原始观察", "Rohdaten beobachten")
        catalog.Set("退出观察", "Beobachtung beenden")
        catalog.Set("原始观察中", "Rohdatenbeobachtung aktiv")
        catalog.Set("原始观察切换失败：{1}",
            "Rohdatenbeobachtung konnte nicht geändert werden: {1}")
        catalog.Set("诊断包", "Diagnose")
        catalog.Set("诊断包预览", "Vorschau des Diagnosepakets")
        catalog.Set("导出诊断包", "Diagnosepaket exportieren")
        catalog.Set("诊断包导出失败：{1}",
            "Diagnosepaket konnte nicht exportiert werden: {1}")
        catalog.Set("诊断包已导出：{1}", "Diagnosepaket exportiert: {1}")
        catalog.Set("将导出 {1} 条事件；已脱敏窗口标题 {2}、路径 {3}、文本/命令 {4}、代码 {5}、变量值 {6} 项。是否继续？",
            "{1} Ereignisse exportieren? Maskiert wurden {2} Fenstertitel, {3} Pfade, {4} Text-/Befehlswerte, {5} Codewerte und {6} Variablenwerte.")
        catalog.Set(
            "导入规则包",
                "Regelpaket importieren")
        catalog.Set(
            "导出规则包",
                "Regelpaket exportieren")
        catalog.Set(
            "规则包导出失败：{1}",
                "Der Export des Regelpakets ist fehlgeschlagen: {1}")
        catalog.Set(
            "已导出 {1} 条规则：{2}",
                "Exportierte {1} Regeln: {2}")
        catalog.Set(
            "规则包导入失败：{1}",
                "Der Import des Regelpakets ist fehlgeschlagen: {1}")
        catalog.Set(
            "规则包导入失败，且回滚失败：{1}",
                "Import und Rollback des Regelpakets fehlgeschlagen: {1}")
        catalog.Set(
            "规则包导入完成：新增 {1}，替换 {2}，重命名 {3}，跳过 {4}。",
                "Import abgeschlossen: {1} hinzugefügt, {2} ersetzt, {3} umbenannt, {4} übersprungen.")
        catalog.Set("变量", "Variablen")
        catalog.Set("变量快照", "Variablenübersicht")
        catalog.Set("导入规则包预览", "Vorschau des Regelpaketimports")
        catalog.Set("来源：{1} · 版本：{2}", "Quelle: {1} · Version: {2}")
        catalog.Set("共 {1} 条规则，默认选中 {2} 条；权限：{3}", "{1} Regeln; {2} vorausgewählt. Berechtigungen: {3}")
        catalog.Set("规则编号", "Regel-ID")
        catalog.Set("模式", "Modus")
        catalog.Set("权限", "Berechtigungen")
        catalog.Set("全选", "Alle auswählen")
        catalog.Set("全部取消", "Alle abwählen")
        catalog.Set("导入所选", "Auswahl importieren")
        catalog.Set("无额外权限", "Keine zusätzlichen Berechtigungen")
        catalog.Set("请至少选择一条规则。", "Mindestens eine Regel auswählen.")
        catalog.Set("导入失败，请查看主窗口状态。", "Import fehlgeschlagen. Status im Hauptfenster prüfen.")
        catalog.Set(
            "筛选：",
                "Filter:")
        catalog.Set(
            "全部事件",
                "Alle Ereignisse")
        catalog.Set(
            "输入事件",
                "Eingabe")
        catalog.Set(
            "规则运行",
                "Laufzeit")
        catalog.Set(
            "规则仓储",
                "Repository")
        catalog.Set(
            "撤销历史",
                "Geschichte")
        catalog.Set(
            "系统事件",
                "System")
        catalog.Set(
            "界面事件",
                "Benutzeroberfläche")
        catalog.Set(
            "暂停刷新",
                "Pause")
        catalog.Set(
            "恢复刷新",
                "Fortsetzen")
        catalog.Set(
            "导出事件",
                "Ereignisse exportieren")
        catalog.Set(
            "时间",
                "Zeit")
        catalog.Set(
            "类别",
                "Kategorie")
        catalog.Set(
            "事件",
                "Ereignis")
        catalog.Set(
            "来源 / 规则",
                "Quelle/Regel")
        catalog.Set(
            "结果",
                "Ergebnis")
        catalog.Set(
            "详情",
                "Einzelheiten")
        catalog.Set(
            "输入",
                "Eingabe")
        catalog.Set(
            "运行时",
                "Laufzeit")
        catalog.Set(
            "仓储",
                "Repository")
        catalog.Set(
            "历史",
                "Geschichte")
        catalog.Set(
            "系统",
                "System")
        catalog.Set(
            "界面",
                "Benutzeroberfläche")
        catalog.Set(
            "已暂停刷新",
                "Angehalten")
        catalog.Set(
            "实时刷新",
                "Lebe")
        catalog.Set(
            "显示 {1} 条 · 缓冲区 {2}/{3} · 已丢弃 {4} 条 · {5}",
                "Zeigt {1} · Puffer {2}/{3} · gelöscht {4} · {5}")
        catalog.Set(
            "事件导出失败：{1}",
                "Ereignisexport fehlgeschlagen: {1}")
        catalog.Set(
            "事件已导出：{1}",
                "Exportierte Ereignisse: {1}")
        catalog.Set(
            "无法打开事件查看器：{1}",
                "Die Ereignisanzeige konnte nicht geöffnet werden: {1}")
        catalog.Set(
            "退出程序",
                "Programm beenden")
        catalog.Set(
            "设置",
                "Einstellungen")
        catalog.Set(
            "界面语言",
                "Sprache")
        catalog.Set(
            "主题",
                "Thema")
        catalog.Set(
            "界面语言：",
                "Oberflächensprache:")
        catalog.Set(
            "界面内容字体：",
                "Schriftart für Oberflächeninhalte:")
        catalog.Set(
            "主题：",
                "Design:")
        catalog.Set(
            "跟随系统",
                "Systemeinstellung übernehmen")
        catalog.Set(
            "浅色",
                "Hell")
        catalog.Set(
            "深色",
                "Dunkel")
        catalog.Set(
            "跟随语言默认（{1}）",
                "Standardschrift der Sprache ({1})")
        catalog.Set(
            "保存",
                "Speichern")
        catalog.Set(
            "取消",
                "Abbrechen")
        catalog.Set(
            "已暂停",
                "Angehalten")
        catalog.Set(
            "已恢复脚本中的自定义顺序。",
                "Die benutzerdefinierte Skriptreihenfolge wurde wiederhergestellt.")
        catalog.Set(
            "升序",
                "aufsteigend")
        catalog.Set(
            "降序",
                "absteigend")
        catalog.Set(
            "已临时按“{1}”{2}排列；不会改写脚本顺序。",
                "Vorübergehend sortiert nach {1} ({2}); Die Skriptreihenfolge bleibt unverändert.")
        catalog.Set(
            "无法恢复自定义顺序：{1}",
                "Benutzerdefinierte Reihenfolge konnte nicht wiederhergestellt werden: {1}")
        catalog.Set(
            "映射顺序没有变化。",
                "Die Zuordnungsreihenfolge hat sich nicht geändert.")
        catalog.Set(
            "无法启动按键录制，请重试。",
                "Die Tastenaufzeichnung konnte nicht gestartet werden. Versuchen Sie es erneut.")
        catalog.Set(
            "正在录制来源按键…",
                "Aufnahmequellentasten...")
        catalog.Set(
            "正在录制目标按键…",
                "Zieltasten aufzeichnen...")
        catalog.Set(
            "来源",
                "Quelle")
        catalog.Set(
            "目标",
                "Ziel")
        catalog.Set(
            "正在录制{1}按键：{2}",
                "{1}-Tasten werden aufgezeichnet: {2}")
        catalog.Set(
            "已录制{1}按键：{2}",
                "{1}-Tasten aufgezeichnet: {2}")
        catalog.Set(
            "已取消按键录制。",
                "Tastenaufzeichnung abgebrochen.")
        catalog.Set(
            "请先完成或取消当前按键录制。",
                "Beenden oder brechen Sie zunächst die aktuelle Aufnahme ab.")
        catalog.Set(
            "请先录制来源按键和目标按键。",
                "Notieren Sie zunächst sowohl den Quell- als auch den Zielschlüssel.")
        catalog.Set(
            "已清空新建区域。",
                "Der neue Zuordnungsbereich wurde gelöscht.")
        catalog.Set(
            "请先选择要删除的映射。",
                "Wählen Sie zunächst eine Zuordnung zum Löschen aus.")
        catalog.Set(
            "所选映射缺少代码块编号，无法删除。",
                "Das ausgewählte Mapping hat keine Block-ID und kann nicht gelöscht werden.")
        catalog.Set(
            "请先选择要暂停或恢复的映射。",
                "Wählen Sie zunächst eine Zuordnung aus, die Sie anhalten oder fortsetzen möchten.")
        catalog.Set(
            "所选映射缺少代码块编号，无法修改状态。",
                "Die ausgewählte Zuordnung hat keine Block-ID und kann ihren Status nicht ändern.")
        catalog.Set(
            "无法打开映射代码：{1}",
                "Zuordnungscode konnte nicht geöffnet werden: {1}")
        catalog.Set(
            "无法打开代码编辑器：{1}",
                "Der Code-Editor konnte nicht geöffnet werden: {1}")
        catalog.Set(
            "映射 · {1} -> {2}{3}",
                "Zuordnung · {1} -> {2}{3}")
        catalog.Set(
            "全局",
                "Global")
        catalog.Set(
            "按键名称：{1}`n虚拟键码：{2}`n扫描码：{3}",
                "Tastenname: {1}`nVirtueller Tastencode: {2}`nScan-Code: {3}")
        catalog.Set(
            "不适用",
                "n/a")
        catalog.Set(
            "键盘",
                "Tastatur")
        catalog.Set(
            "鼠标",
                "Maus")
        catalog.Set(
            "滚轮",
                "Mausrad")
        catalog.Set(
            "多媒体",
                "Medien")
        catalog.Set(
            "命名键",
                "Benannte Taste")
        catalog.Set(
            "左侧 Ctrl",
                "Linke Strg-Taste")
        catalog.Set(
            "右侧 Ctrl",
                "Rechte Strg-Taste")
        catalog.Set(
            "左侧 Shift",
                "Linke Umschalttaste")
        catalog.Set(
            "右侧 Shift",
                "Rechte Umschalttaste")
        catalog.Set(
            "左侧 Alt",
                "Links Alt")
        catalog.Set(
            "右侧 Alt",
                "Rechts Alt")
        catalog.Set(
            "左侧 Win",
                "Linker Sieg")
        catalog.Set(
            "右侧 Win",
                "Richtiger Sieg")
        catalog.Set(
            "读取重映射代码区域失败：{1}",
                "Zuordnungsregion konnte nicht gelesen werden: {1}")
        catalog.Set(
            "托管规则未应用：{1}",
                "Verwaltete Regeln wurden nicht angewendet: {1}")
        catalog.Set(
            "无法检查现有映射：{1}",
                "Vorhandene Zuordnungen konnten nicht überprüft werden: {1}")
        catalog.Set(
            "为避免失去界面操作，来源按键不能是无修饰的鼠标左键。",
                "Eine unveränderte linke Maustaste kann nicht als Quelltaste verwendet werden.")
        catalog.Set(
            "该来源按键已被现有映射占用。",
                "Dieser Quellschlüssel wird bereits von einer anderen Zuordnung verwendet.")
        catalog.Set(
            "来源按键与目标按键相同，无需建立映射。",
                "Quelle und Ziel sind identisch; Es ist keine Zuordnung erforderlich.")
        catalog.Set(
            "映射未写入脚本：{1}",
                "Zuordnung wurde nicht geschrieben: {1}")
        catalog.Set(
            "已写入脚本：{1} -> {2}；正在自动应用。",
                "In das Skript geschrieben: {1} -> {2}; wird automatisch angewendet.")
        catalog.Set(
            "删除映射",
                "Zuordnung löschen")
        catalog.Set(
            "映射未删除：{1}",
                "Zuordnung wurde nicht gelöscht: {1}")
        catalog.Set(
            "已从脚本删除：{1} -> {2}；正在自动应用。",
                "Aus dem Skript gelöscht: {1} -> {2}; wird automatisch angewendet.")
        catalog.Set(
            "调整映射顺序",
                "Zuordnungen neu anordnen")
        catalog.Set(
            "顺序未保存：{1}",
                "Bestellung wurde nicht gespeichert: {1}")
        catalog.Set(
            "已按拖动结果实时更新脚本顺序。",
                "Die Skriptreihenfolge wurde anhand des gezogenen Ergebnisses aktualisiert.")
        catalog.Set(
            "暂停映射",
                "Pausieren Sie die Zuordnung")
        catalog.Set(
            "恢复映射",
                "Kartierung fortsetzen")
        catalog.Set(
            "映射状态未修改：{1}",
                "Der Zuordnungsstatus wurde nicht geändert: {1}")
        catalog.Set(
            "已恢复映射：{1} -> {2}；正在自动应用。",
                "Zuordnung fortgesetzt: {1} -> {2}; wird automatisch angewendet.")
        catalog.Set(
            "已暂停映射：{1} -> {2}；正在自动应用。",
                "Zuordnung pausiert: {1} -> {2}; wird automatisch angewendet.")
        catalog.Set(
            "映射代码未保存：{1}",
                "Zuordnungscode wurde nicht gespeichert: {1}")
        catalog.Set(
            "映射代码未新增：{1}",
                "Zuordnungscode wurde nicht hinzugefügt: {1}")
        catalog.Set(
            "未保存：{1}",
                "Nicht gespeichert: {1}")
        catalog.Set(
            "已保存映射代码：{1} -> {2}；正在自动应用。",
                "Zuordnungscode gespeichert: {1} -> {2}; wird automatisch angewendet.")
        catalog.Set(
            "已新增映射代码：{1} -> {2}；正在自动应用。",
                "Zuordnungscode hinzugefügt: {1} -> {2}; wird automatisch angewendet.")
        catalog.Set(
            "无法创建空白映射代码：{1}",
                "Es konnte kein leerer Zuordnungscode erstellt werden: {1}")
        catalog.Set(
            "无法打开设置：{1}",
                "Einstellungen konnten nicht geöffnet werden: {1}")
        catalog.Set(
            "设置未保存：{1}",
                "Einstellungen wurden nicht gespeichert: {1}")
        catalog.Set(
            "界面内容字体",
                "UI-Schriftart")
        catalog.Set(
            "撤销失败：{1}",
                "Rückgängig machen fehlgeschlagen: {1}")
        catalog.Set(
            "重做失败：{1}",
                "Wiederherstellung fehlgeschlagen: {1}")
        catalog.Set(
            "已撤销：{1}",
                "Rückgängig gemacht: {1}")
        catalog.Set(
            "已重做：{1}",
                "Wiederholt: {1}")
        catalog.Set(
            "映射配置",
                "Mapping-Konfiguration")
        catalog.Set(
            "{1} 条重映射正在生效 · 当前为脚本代码顺序",
                "{1} Zuordnungen aktiv · benutzerdefinierte Skriptreihenfolge")
        catalog.Set("键鼠重映射小助手设置",
            "Einstellungen des Assistenten für Tastatur- und Maus-Neuzuordnung")
        catalog.Set("通用",
            "Allgemein")
        catalog.Set("关于",
            "Info")
        catalog.Set("启动时显示主窗口",
            "Hauptfenster beim Start anzeigen")
        catalog.Set("单独按 Esc 时取消录制",
            "Aufnahme mit einzeln gedrückter Esc-Taste abbrechen")
        catalog.Set("事件缓冲区容量（条）：",
            "Ereignispufferkapazität:")
        catalog.Set("事件查看器自动跟随最新事件",
            "Automatisch den neuesten Ereignissen folgen")
        catalog.Set("让每一条键鼠映射都可录制、可审阅、可掌控",
            "Jede Tastatur- und Mauszuordnung aufzeichnen, prüfen und steuern")
        catalog.Set("当前版本",
            "Aktuelle Version")
        catalog.Set("运行环境",
            "Laufzeitumgebung")
        catalog.Set("查看最新版本",
            "Neueste Version anzeigen")
        catalog.Set("开源地址",
            "Open-Source-Repository")
        catalog.Set("“{1}”必须是 {2} 到 {3} 之间的整数。",
            "„{1}“ muss eine Ganzzahl zwischen {2} und {3} sein.")
        catalog.Set("事件缓冲区容量",
            "Ereignispufferkapazität")
        catalog.Set("未知版本",
            "Unbekannte Version")
        catalog.Set("{1}（EXE 版）",
            "{1} (EXE-Version)")
        catalog.Set("{1}（源码版）",
            "{1} (Quellcodeversion)")
        catalog.Set("设置没有变化。",
            "Keine Einstellungen geändert.")
        catalog.Set("设置已保存并已应用。",
            "Einstellungen gespeichert und angewendet.")
        catalog.Set("设置",
            "Einstellungen")
        catalog.Set("Esc 取消录制",
            "Esc bricht die Aufnahme ab")
        catalog.Set("事件自动跟随",
            "Neueste Ereignisse verfolgen")
        catalog.Set("录制", "Aufnahme")
        catalog.Set("事件", "Ereignisse")
        catalog.Set("{1}（便携版）", "{1} (portable Version)")
        catalog.Set("帮助信息", "Hilfe")
        catalog.Set("捐赠", "Spenden")
        catalog.Set("使用说明", "Benutzerhandbuch")
        catalog.Set("提交反馈", "Feedback senden")
        catalog.Set("支持开源项目", "Open-Source-Projekt unterstützen")
        catalog.Set("微信支付", "WeChat Pay")
        catalog.Set("支付宝", "Alipay")
        catalog.Set("二维码图片未找到", "QR-Code-Bild nicht gefunden")
        catalog.Set("如果小助手为您节省了排查问题和恢复程序的时间，欢迎通过下方二维码打赏作者！`n请选择扶贫方式：", "Wenn Ihnen der Assistent Zeit bei der Fehlersuche und Wiederherstellung von Programmen erspart hat, unterstützen Sie den Autor gern über die QR-Codes unten!`nWählen Sie aus, wie Sie helfen möchten:")
        catalog.Set("无法打开帮助信息：{1}", "Hilfe konnte nicht geöffnet werden: {1}")
        catalog.Set("无法打开使用说明：{1}", "Benutzerhandbuch konnte nicht geöffnet werden: {1}")
        catalog.Set("无法打开捐赠窗口：{1}", "Spendenfenster konnte nicht geöffnet werden: {1}")
        catalog.Set("无法打开反馈页面：{1}", "Feedbackseite konnte nicht geöffnet werden: {1}")
        catalog.Set("键鼠重映射小助手用于录制、审阅和维护键盘与鼠标映射。关闭主窗口只会隐藏到系统托盘，已经启用的映射仍会继续生效。", "Der Assistent für Tastatur- und Maus-Neuzuordnung zeichnet Tastatur- und Mauszuordnungen auf und dient ihrer Prüfung und Pflege. Beim Schließen wird das Hauptfenster nur in den Infobereich ausgeblendet; aktivierte Zuordnungen bleiben wirksam.")
        catalog.Set("一、快速上手", "1. Schnellstart")
        catalog.Set("• 点击顶部“新增”，会打开已经填好元数据字段的 @mapping 编辑器；也可以在下方分别录制来源按键和目标按键，填写设计目的后保存。", "• Mit Hinzufügen in der oberen Leiste öffnen Sie einen @mapping-Editor mit vorbereiteten Metadatenfeldern. Alternativ können Sie unten Quelle und Ziel getrennt aufzeichnen, den Zweck angeben und speichern.")
        catalog.Set("• 录制会实时显示原始规范名称、阅读友好名称、虚拟键码和扫描码，并区分左右 Ctrl、Shift、Alt、Win 以及键盘、鼠标和滚轮输入。", "• Die Aufzeichnung zeigt kanonischen Namen, lesbaren Namen, virtuellen Tastencode und Scancode in Echtzeit. Linke und rechte Strg-, Umschalt-, Alt- und Win-Tasten sowie Tastatur-, Maus- und Radeingaben werden unterschieden.")
        catalog.Set("• 同时按下的任意按键会组成一次录制；所有按键释放后结束。录制期间再次点击录制按钮会取消本次录制，不会把该次点击记为 LButton。", "• Alle gleichzeitig gehaltenen Tasten bilden eine Aufzeichnung, die nach dem Loslassen aller Tasten endet. Ein erneuter Klick auf die Aufzeichnungsschaltfläche bricht ab, statt den Klick als LButton aufzuzeichnen.")
        catalog.Set("二、主界面与代码编辑", "2. Hauptfenster und Codebearbeitung")
        catalog.Set("• 单击选择映射；双击条目、悬停时按 F2 或使用右键菜单，可编辑完整 @mapping 代码块。", "• Wählen Sie eine Zuordnung mit einem Klick. Ein Doppelklick auf eine Zeile, F2 beim Zeigen oder das Kontextmenü öffnet den vollständigen @mapping-Block zur Bearbeitung.")
        catalog.Set("• 选中条目后可暂停、恢复或删除；直接拖动列表行可调整永久顺序，脚本中的代码块顺序会实时同步。", "• Eine gewählte Zuordnung kann pausiert, fortgesetzt oder gelöscht werden. Ziehen Sie Zeilen, um die dauerhafte Reihenfolge zu ändern; die Blockreihenfolge im Skript wird sofort synchronisiert.")
        catalog.Set("• 点击伪表头只进行临时排序；字段按升序、降序、自定义顺序循环，序号列按降序、自定义顺序循环，不会改写脚本。", "• Die Sortierung über Pseudo-Kopfzeilen ist vorübergehend. Felder wechseln zwischen aufsteigend, absteigend und benutzerdefiniert; die Nummernspalte zwischen absteigend und benutzerdefiniert. Das Skript wird dabei nicht umgeschrieben.")
        catalog.Set("• 映射区域只保存注释化 RuleSpec v2，是映射的唯一持久来源。GUI 创建或编辑的托管规则会直接热应用；可执行 AHK 代码不会被接受。", "• Der Zuordnungsbereich speichert nur auskommentierte RuleSpec-v2-Daten und ist die einzige dauerhafte Quelle. In der Oberfläche erstellte oder bearbeitete verwaltete Regeln werden sofort angewendet; ausführbarer AHK-Code wird abgelehnt.")
        catalog.Set("四、事件、历史与界面设置", "4. Ereignisse, Verlauf und Darstellung")
        catalog.Set("• 事件查看器记录输入、规则匹配、条件拒绝、执行结果、仓储和系统事件，支持筛选、暂停、清空及 JSONL 导出。", "• Die Ereignisanzeige protokolliert Eingaben, Regeltreffer, Bedingungsablehnungen, Ausführungsergebnisse, Repository-Aktivität und Systemereignisse. Sie unterstützt Filtern, Pausieren, Leeren und den JSONL-Export.")
        catalog.Set("五、后台运行与问题排查", "5. Hintergrundbetrieb und Problembehandlung")
        catalog.Set("• 主窗口关闭后程序仍驻留托盘。托盘可以重新显示主界面、手动重新加载或彻底退出；修改映射规则后通常不需要手动重新加载。", "• Nach dem Schließen des Hauptfensters bleibt die App im Infobereich. Dort können Sie das Fenster anzeigen, manuell neu laden oder die App vollständig beenden; Regeländerungen erfordern normalerweise kein manuelles Neuladen.")
        catalog.Set("• 映射对管理员程序无效时，请从托盘选择以管理员身份重新启动。遇到规则冲突或按键未按预期执行时，先在事件查看器中核对输入和规则结果。", "• Wirkt eine Zuordnung nicht in einer erhöhten Anwendung, starten Sie diese App über den Infobereich als Administrator neu. Prüfen Sie bei Konflikten oder unerwarteten Eingaben zuerst Eingaben und Regelergebnisse in der Ereignisanzeige.")
        catalog.Set("• “帮助信息”还可打开项目反馈页面。提交问题时请说明系统版本、复现步骤、相关 @mapping 代码和事件导出，并在公开前移除敏感路径或应用信息。", "• Über Hilfe lässt sich auch die Feedbackseite des Projekts öffnen. Nennen Sie bei einem Bericht Windows-Version, Reproduktionsschritte, betroffenen @mapping-Code und einen Ereignisexport und entfernen Sie vor der Veröffentlichung vertrauliche Pfade oder Anwendungsdaten.")
        catalog.Set("安全模式：已停用所有映射和输入观察。连续启动失败 {1} 次。", "Abgesicherter Modus: Nach {1} aufeinanderfolgenden Startfehlern sind alle Zuordnungen und die Eingabebeobachtung deaktiviert.")
        catalog.Set("恢复最后正常配置", "Letzte funktionierende Konfiguration wiederherstellen")
        catalog.Set("没有可恢复的最后正常配置。", "Es ist keine letzte funktionierende Konfiguration verfügbar.")
        catalog.Set("最后正常配置恢复失败：{1}", "Die letzte funktionierende Konfiguration konnte nicht wiederhergestellt werden: {1}")
        catalog.Set("最后正常配置已恢复，正在自动应用。", "Die letzte funktionierende Konfiguration wurde wiederhergestellt und wird automatisch angewendet.")
        catalog.Set("仅勾选的规则会被导入。", "Nur ausgewählte Regeln werden importiert.")
        catalog.Set("三、规则与生效范围", "3. Regeln und Geltungsbereich")
        catalog.Set("• 所有规则属于同一全局规则集；生效范围和条件可在 @mapping 编辑器中精确调整，保存后会立即重新选择生效规则。", "• Alle Regeln gehören zu einem globalen Regelsatz. Geltungsbereich und Bedingungen lassen sich im @mapping-Editor genau festlegen; nach dem Speichern werden die aktiven Regeln sofort neu ausgewählt.")
        catalog.Set("• Ctrl+Z 撤销，Ctrl+Shift+Z 或 Ctrl+Y 重做。映射增删、暂停恢复、拖动排序、代码编辑和设置修改都会进入持久历史。", "• Ctrl+Z macht rückgängig; Ctrl+Shift+Z oder Ctrl+Y stellt wieder her. Hinzufügen, Löschen, Pausieren, Fortsetzen, Sortieren, Codeänderungen und Einstellungen werden dauerhaft im Verlauf gespeichert.")
        return catalog
    }
}
