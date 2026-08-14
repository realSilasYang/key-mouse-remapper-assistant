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
            "删除",
                "Löschen")
        catalog.Set(
            "暂停",
                "Pausieren")
        catalog.Set(
            "恢复",
                "Fortsetzen")
        catalog.Set("反转状态", "Status umkehren")
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
            "名称",
                "Name")
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
        catalog.Set("规则块", "Normale Regel")
        catalog.Set("受托管脚本", "Verwaltetes Skript")
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
            "事件查看",
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
            "规则包导入完成：新增 {1}，替换 {2}，重命名 {3}，跳过 {4}。",
                "Import abgeschlossen: {1} hinzugefügt, {2} ersetzt, {3} umbenannt, {4} übersprungen.")
        catalog.Set("导入规则包预览", "Vorschau des Regelpaketimports")
        catalog.Set("来源：{1} · 版本：{2}", "Quelle: {1} · Version: {2}")
        catalog.Set("共 {1} 条规则，默认选中 {2} 条；权限：{3}", "{1} Regeln; {2} vorausgewählt. Berechtigungen: {3}")
        catalog.Set("模式", "Modus")
        catalog.Set("权限", "Berechtigungen")
        catalog.Set("全选", "Alle auswählen")
        catalog.Set("全部取消", "Alle abwählen")
        catalog.Set("导入所选", "Auswahl importieren")
        catalog.Set("无额外权限", "Keine zusätzlichen Berechtigungen")
        catalog.Set("生成键鼠输入", "Tastatur- und Mauseingaben erzeugen")
        catalog.Set("控制活动窗口", "Aktives Fenster steuern")
        catalog.Set("执行系统控制", "Systemsteuerung ausführen")
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
            "系统事件",
                "System")
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
            "退出程序",
                "Programm beenden")
        catalog.Set(
            "设置",
                "Einstellungen")
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
        catalog.Set("无法启动按键录制：{1}", "Die Tastenaufzeichnung konnte nicht gestartet werden: {1}")
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
            "所选映射缺少名称，无法删除。",
                "Das ausgewählte Mapping hat keinen Namen und kann nicht gelöscht werden.")
        catalog.Set(
            "请先选择要暂停或恢复的映射。",
                "Wählen Sie zunächst eine Zuordnung aus, die Sie anhalten oder fortsetzen möchten.")
        catalog.Set(
            "所选映射缺少名称，无法修改状态。",
                "Das ausgewählte Mapping hat keinen Namen und sein Status kann nicht geändert werden.")
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
            "为避免失去界面操作，来源按键不能是无修饰的鼠标左键。",
                "Eine unveränderte linke Maustaste kann nicht als Quelltaste verwendet werden.")
        catalog.Set(
            "映射未写入脚本：{1}",
                "Zuordnung wurde nicht geschrieben: {1}")
        catalog.Set(
            "已写入脚本：{1} -> {2}；已应用。",
                "In das Skript geschrieben: {1} -> {2}; angewendet.")
        catalog.Set(
            "映射未删除：{1}",
                "Zuordnung wurde nicht gelöscht: {1}")
        catalog.Set(
            "已从脚本删除：{1} -> {2}；已应用。",
                "Aus dem Skript gelöscht: {1} -> {2}; angewendet.")
        catalog.Set(
            "顺序未保存：{1}",
                "Bestellung wurde nicht gespeichert: {1}")
        catalog.Set(
            "已按拖动结果实时更新脚本顺序。",
                "Die Skriptreihenfolge wurde anhand des gezogenen Ergebnisses aktualisiert.")
        catalog.Set(
            "映射状态未修改：{1}",
                "Der Zuordnungsstatus wurde nicht geändert: {1}")
        catalog.Set(
            "已恢复映射：{1} -> {2}；已应用。",
                "Zuordnung fortgesetzt: {1} -> {2}; angewendet.")
        catalog.Set(
            "已暂停映射：{1} -> {2}；已应用。",
                "Zuordnung pausiert: {1} -> {2}; angewendet.")
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
            "已保存映射代码：{1} -> {2}；已应用。",
                "Zuordnungscode gespeichert: {1} -> {2}; angewendet.")
        catalog.Set(
            "已新增映射代码：{1} -> {2}；已应用。",
                "Zuordnungscode hinzugefügt: {1} -> {2}; angewendet.")
        catalog.Set("已保存，正在后台应用…",
            "Gespeichert; wird im Hintergrund angewendet...")
        catalog.Set("受托管脚本已应用。", "Verwaltetes Skript angewendet.")
        catalog.Set("映射代码没有变化。", "Der Zuordnungscode wurde nicht geändert.")
        catalog.Set("映射代码已保存，但受托管脚本应用失败：{1}",
            "Der Zuordnungscode wurde gespeichert, aber das verwaltete Skript konnte nicht angewendet werden: {1}")
        catalog.Set(
            "无法创建空白映射代码：{1}",
                "Es konnte kein leerer Zuordnungscode erstellt werden: {1}")
        catalog.Set(
            "设置未保存：{1}",
                "Einstellungen wurden nicht gespeichert: {1}")
        catalog.Set(
            "{1} 条重映射正在生效 · 当前为脚本代码顺序",
                "{1} Zuordnungen aktiv · benutzerdefinierte Skriptreihenfolge")
        catalog.Set("键鼠重映射小助手设置",
            "Einstellungen des Assistenten für Tastatur- und Maus-Neuzuordnung")
        catalog.Set("启动",
            "Start")
        catalog.Set("显示",
            "Anzeige")
        catalog.Set("规则与事件",
            "Regeln und Ereignisse")
        catalog.Set("关于",
            "Info")
        catalog.Set("事件缓冲区容量（条）：",
            "Ereignispufferkapazität:")
        catalog.Set("事件查看自动跟随最新事件",
            "Automatisch den neuesten Ereignissen folgen")
        catalog.Set("让每一条键鼠映射都可录制、可审阅、可掌控",
            "Jede Tastatur- und Mauszuordnung aufzeichnen, prüfen und steuern")
        catalog.Set("当前版本",
            "Aktuelle Version")
        catalog.Set("运行环境",
            "Laufzeitumgebung")
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
        catalog.Set("设置已保存并已应用。",
            "Einstellungen gespeichert und angewendet.")
        catalog.Set("Esc 取消录制",
            "Esc bricht die Aufnahme ab")
        catalog.Set("{1}（便携版）", "{1} (portable Version)")
        catalog.Set("快揭不开锅了（≥Д≤）",
            "Die Kasse ist fast leer（≥Д≤）")
        catalog.Set("使用说明", "Benutzerhandbuch")
        catalog.Set("提交反馈", "Feedback senden")
        catalog.Set("支持开源项目", "Open-Source-Projekt unterstützen")
        catalog.Set("微信支付", "WeChat Pay")
        catalog.Set("支付宝", "Alipay")
        catalog.Set("二维码图片未找到", "QR-Code-Bild nicht gefunden")
        catalog.Set("如果小助手为您节省了配置键鼠映射的时间，欢迎通过下方二维码打赏作者！`n请选择扶贫方式（≥Д≤）", "Wenn Ihnen der Assistent Zeit beim Einrichten von Tastatur- und Mauszuordnungen erspart hat, unterstützen Sie den Autor gern über die QR-Codes unten!`nWählen Sie aus, wie Sie helfen möchten (≥Д≤)")
        catalog.Set("无法打开反馈页面：{1}", "Feedbackseite konnte nicht geöffnet werden: {1}")
        catalog.Set("键鼠重映射小助手用于录制、审阅和维护键盘与鼠标映射。关闭主窗口只会隐藏到系统托盘，已经启用的映射仍会继续生效。", "Der Assistent für Tastatur- und Maus-Neuzuordnung zeichnet Tastatur- und Mauszuordnungen auf und dient ihrer Prüfung und Pflege. Beim Schließen wird das Hauptfenster nur in den Infobereich ausgeblendet; aktivierte Zuordnungen bleiben wirksam.")
        catalog.Set("一、快速上手", "1. Schnellstart")
        catalog.Set("• 点击顶部“新增”，会打开已经填好元数据字段的 @mapping 编辑器；也可以在下方分别录制来源按键和目标按键，填写名称后保存。", "• Mit Hinzufügen in der oberen Leiste öffnen Sie einen @mapping-Editor mit vorbereiteten Metadatenfeldern. Alternativ können Sie unten Quelle und Ziel getrennt aufzeichnen, einen Namen eingeben und speichern.")
        catalog.Set("• 录制会实时显示原始规范名称、阅读友好名称、虚拟键码和扫描码，并区分左右 Ctrl、Shift、Alt、Win 以及键盘、鼠标和滚轮输入。", "• Die Aufzeichnung zeigt kanonischen Namen, lesbaren Namen, virtuellen Tastencode und Scancode in Echtzeit. Linke und rechte Strg-, Umschalt-, Alt- und Win-Tasten sowie Tastatur-, Maus- und Radeingaben werden unterschieden.")
        catalog.Set("二、主界面与代码编辑", "2. Hauptfenster und Codebearbeitung")
        catalog.Set("• 单击选择映射；双击条目、选中后按 F2 或使用右键菜单，可编辑完整 @mapping 代码块。", "• Wählen Sie eine Zuordnung mit einem Klick. Ein Doppelklick auf eine Zeile, F2 bei ausgewählter Zeile oder das Kontextmenü öffnet den vollständigen @mapping-Block zur Bearbeitung.")
        catalog.Set("• 选中条目后可暂停、恢复或删除；直接拖动列表行可调整永久顺序，脚本中的代码块顺序会实时同步。", "• Eine gewählte Zuordnung kann pausiert, fortgesetzt oder gelöscht werden. Ziehen Sie Zeilen, um die dauerhafte Reihenfolge zu ändern; die Blockreihenfolge im Skript wird sofort synchronisiert.")
        catalog.Set("• 点击伪表头只进行临时排序；字段按升序、降序、自定义顺序循环，序号列按降序、自定义顺序循环，不会改写脚本。", "• Die Sortierung über Pseudo-Kopfzeilen ist vorübergehend. Felder wechseln zwischen aufsteigend, absteigend und benutzerdefiniert; die Nummernspalte zwischen absteigend und benutzerdefiniert. Das Skript wird dabei nicht umgeschrieben.")
        catalog.Set("• 事件查看记录输入、规则匹配、条件拒绝、执行结果、仓储和系统事件，支持筛选、暂停、清空及 JSONL 导出。", "• Die Ereignisanzeige protokolliert Eingaben, Regeltreffer, Bedingungsablehnungen, Ausführungsergebnisse, Repository-Aktivität und Systemereignisse. Sie unterstützt Filtern, Pausieren, Leeren und den JSONL-Export.")
        catalog.Set("四、事件查看与设置", "4. Ereignisanzeige und Einstellungen")
        catalog.Set("五、后台运行与问题排查", "5. Hintergrundbetrieb und Problembehandlung")
        catalog.Set("• 主窗口关闭后程序仍驻留托盘。托盘可以重新显示主界面、手动重新加载或彻底退出；修改映射规则后通常不需要手动重新加载。", "• Nach dem Schließen des Hauptfensters bleibt die App im Infobereich. Dort können Sie das Fenster anzeigen, manuell neu laden oder die App vollständig beenden; Regeländerungen erfordern normalerweise kein manuelles Neuladen.")
        catalog.Set("仅勾选的规则会被导入。", "Nur ausgewählte Regeln werden importiert.")
        catalog.Set("三、规则与生效范围", "3. Regeln und Geltungsbereich")
        catalog.Set("• 所有规则属于同一全局规则集；生效范围和条件可在 @mapping 编辑器中精确调整，保存后会立即重新选择生效规则。", "• Alle Regeln gehören zu einem globalen Regelsatz. Geltungsbereich und Bedingungen lassen sich im @mapping-Editor genau festlegen; nach dem Speichern werden die aktiven Regeln sofort neu ausgewählt.")
        catalog.Set("没有可撤销的映射变更。", "Es gibt keine Zuordnungsänderungen zum Rückgängigmachen.")
        catalog.Set("已撤销上一步映射变更。", "Die letzte Zuordnungsänderung wurde rückgängig gemacht.")
        catalog.Set("撤销映射变更失败：{1}", "Die Zuordnungsänderung konnte nicht rückgängig gemacht werden: {1}")
        catalog.Set("没有可重做的映射变更。", "Es gibt keine Zuordnungsänderungen zum Wiederholen.")
        catalog.Set("已重做映射变更。", "Die Zuordnungsänderung wurde wiederholt.")
        catalog.Set("重做映射变更失败：{1}", "Die Zuordnungsänderung konnte nicht wiederholt werden: {1}")
        catalog.Set("录制结束后无法恢复重映射：{1}", "Die Tastenbelegung konnte nach der Aufzeichnung nicht fortgesetzt werden: {1}")
        catalog.Set("• 新增、删除、暂停或恢复、代码编辑、拖动排序和规则包导入均可撤销；Ctrl+Z 撤销，Ctrl+Shift+Z 或 Ctrl+Y 重做。", "• Hinzufügen, Löschen, Pausieren oder Fortsetzen, Codebearbeitung, Sortieren per Ziehen und Regelpaketimporte können rückgängig gemacht werden. Strg+Z macht rückgängig; Strg+Umschalt+Z oder Strg+Y wiederholt.")
        catalog.Set("开机自动启动（计划任务）", "Automatisch beim Anmelden starten（geplante Aufgabe）")
        catalog.Set("检查更新失败：{1}", "Update-Suche fehlgeschlagen: {1}")
        catalog.Set("启动时显示主窗口", "Hauptfenster beim Start anzeigen")
        catalog.Set("更新检查正在进行，请稍候。", "Eine Update-Prüfung wird bereits ausgeführt. Bitte warten.")
        catalog.Set("关闭", "Ausschalten")
        catalog.Set("将下载并校验源码发行包，保留个人配置后替换源码并自动重启。", "Das Quellcodepaket wird heruntergeladen und geprüft. Anschließend wird der Quellcode unter Beibehaltung Ihrer persönlichen Einstellungen ersetzt und der Assistent automatisch neu gestartet.")
        catalog.Set("桌面与开始菜单快捷方式", "Verknüpfungen auf dem Desktop und im Startmenü")
        catalog.Set("创建", "Erstellen")
        catalog.Set("无法检查更新：{1}", "Updates konnten nicht geprüft werden: {1}")
        catalog.Set("提示", "Hinweis")
        catalog.Set("检测到同名计划任务，但它并非当前程序创建；为避免误删，请先在任务计划程序中处理它。", "Eine gleichnamige geplante Aufgabe wurde erkannt, aber nicht von diesem Programm erstellt. Um ein versehentliches Löschen zu vermeiden, bearbeiten Sie sie zunächst in der Aufgabenplanung.")
        catalog.Set("立即更新", "Jetzt aktualisieren")
        catalog.Set("错误", "Fehler")
        catalog.Set("创建成功！", "Erstellt!")
        catalog.Set("无法建立单实例运行锁，小助手将退出。", "Die Sperre für eine einzelne Instanz konnte nicht eingerichtet werden`; der Assistent wird beendet.")
        catalog.Set("重新加载失败，已保留当前实例：{1}", "Neuladen fehlgeschlagen`; die aktuelle Instanz wurde beibehalten: {1}")
        catalog.Set("稍后", "Später")
        catalog.Set("切换", "Umschalten")
        catalog.Set("冲突", "Konflikt")
        catalog.Set("将确认源码仓库没有未提交修改，再快速前进到正式发布标签并自动重启。", "Zunächst wird sichergestellt, dass das Quellcoderepository keine nicht übernommenen Änderungen enthält. Danach wird per Fast-Forward zur offiziellen Veröffentlichungsmarke gewechselt und automatisch neu gestartet.")
        catalog.Set("无法开始更新：{1}", "Update konnte nicht gestartet werden: {1}")
        catalog.Set("正在检查更新…", "Suche nach Updates…")
        catalog.Set("检查更新", "Nach Updates suchen")
        catalog.Set("小助手更新", "Assistentenupdate")
        catalog.Set("将下载并校验完整发行包，退出小助手后替换程序文件并自动重启。", "Das vollständige Veröffentlichungspaket wird heruntergeladen und geprüft. Nach dem Beenden des Assistenten werden die Programmdateien ersetzt und der Assistent automatisch neu gestartet.")
        catalog.Set("创建快捷方式失败：{1}", "Verknüpfung konnte nicht erstellt werden: {1}")
        catalog.Set("当前陪伴您的已经是最新版本的小助手啦！", "Ihr Assistent ist bereits auf dem neuesten Stand!")
        catalog.Set("确定", "OK")
        catalog.Set("没有可安装的应用更新", "Kein installierbares Anwendungsupdate vorhanden")
        catalog.Set("更新检查未返回结果", "Die Update-Prüfung hat kein Ergebnis geliefert")
        catalog.Set("开启", "Einschalten")
        catalog.Set("不可用", "Nicht verfügbar")
        catalog.Set("启动失败", "Start fehlgeschlagen")
        catalog.Set("启动时检查小助手更新", "Beim Start nach Assistentenupdates suchen")
        catalog.Set("以管理员身份运行", "Als Administrator ausführen")
        catalog.Set("操作计划任务时发生错误：{1}", "Beim Bearbeiten der geplanten Aufgabe ist ein Fehler aufgetreten: {1}")
        catalog.Set("发现新版本 {1}，当前版本为 {2}。`n`n{3}`n`n是否立即更新？", "Die neue Version {1} ist verfügbar; aktuell ist Version {2} installiert.`n`n{3}`n`nJetzt aktualisieren?")
        catalog.Set("开机自动启动", "Automatisch bei der Anmeldung starten")
        catalog.Set("输入录制不可用：{1}", "Eingabeaufzeichnung ist nicht verfügbar: {1}")
        catalog.Set("新脚本未通过 AutoHotkey 启动验证。", "Das neue Skript hat die AutoHotkey-Startprüfung nicht bestanden.")
        catalog.Set("保存并运行", "Speichern und ausführen")
        catalog.Set("导入并运行", "Importieren und ausführen")
        catalog.Set("导入自定义 AHK 代码", "Benutzerdefinierten AHK-Code importieren")
        catalog.Set("继续", "Fortfahren")
        catalog.Set("切换规则类型", "Regeltyp wechseln")
        catalog.Set("切换规则类型会清空当前未保存内容，是否继续？", "Beim Wechseln des Regeltyps werden die aktuellen ungespeicherten Inhalte gelöscht. Fortfahren?")
        catalog.Set("所选规则包含可读写文件、启动程序、控制窗口和请求管理员权限的自定义 AHK 代码。确认导入并运行吗？", "Die ausgewählten Regeln enthalten benutzerdefinierten AHK-Code, der Dateien lesen und schreiben, Programme starten, Fenster steuern und Administratorrechte anfordern kann. Importieren und ausführen?")
        catalog.Set("无法创建规则模板：{1}", "Die Regelvorlage konnte nicht erstellt werden: {1}")
        catalog.Set("运行自定义 AHK 代码", "Benutzerdefinierten AHK-Code ausführen")
        catalog.Set("自定义 AHK 代码可读取文件、启动程序、控制窗口并请求管理员权限。确认运行当前代码吗？", "Benutzerdefinierter AHK-Code kann Dateien lesen und schreiben, Programme starten, Fenster steuern und Administratorrechte anfordern. Diesen Code ausführen?")
        catalog.Set("规则未应用：{1}", "Regeln wurden nicht angewendet: {1}")
        catalog.Set("• 映射区域以注释形式保存规则块和受托管脚本。规则块在主进程热应用；受托管脚本的自定义 AHK v2 源码在独立受管进程运行，保存、暂停、恢复、删除和退出均由小助手统一管理。", "• Im Zuordnungsbereich werden normale Regelblöcke und verwaltete Skripte als Kommentare gespeichert. Normale Regelblöcke werden im Hauptprozess direkt angewendet. Benutzerdefinierter AutoHotkey-v2-Code läuft in einem separaten verwalteten Prozess unter Kontrolle des Assistenten.")
        catalog.Set("区分左右修饰键", "Linke/rechte Modifikatoren unterscheiden")
        catalog.Set("帮助", "Hilfe")
        catalog.Set("打赏", "Spenden")
        catalog.Set("打开帮助`n可选择查看使用说明、运行日志或提交反馈", "Hilfe öffnen`nBenutzerhandbuch oder Laufzeitprotokoll öffnen oder Feedback senden")
        catalog.Set("点个 star 吧~", "Schenk uns ein Sternchen~")
        catalog.Set("配置显示、规则包和事件选项", "Anzeige, Regelpakete und Ereignisoptionen konfigurieren")
        catalog.Set("查看版本、运行环境和项目入口", "Version, Laufzeitumgebung und Projektlinks anzeigen")
        catalog.Set("找作者对线", "Mit dem Autor diskutieren")
        catalog.Set("演奏你的和弦！", "Spiele deinen Akkord!")
        catalog.Set("• “帮助”还可打开项目反馈页面。提交问题时请说明系统版本、复现步骤、相关 @mapping 代码和事件导出，并在公开前移除敏感路径或应用信息。", "• Über Hilfe lässt sich auch die Feedbackseite des Projekts öffnen. Nennen Sie bei einem Bericht Windows-Version, Reproduktionsschritte, betroffenen @mapping-Code und einen Ereignisexport und entfernen Sie vor der Veröffentlichung vertrauliche Pfade oder Anwendungsdaten.")
        catalog.Set("AI 设置", "AI settings")
        catalog.Set("API 地址：", "API-Adresse:")
        catalog.Set("API 密钥：", "API-Schlüssel:")
        catalog.Set("模型名称：", "Modellname:")
        catalog.Set("请求超时（秒）：", "Request timeout (seconds):")
        catalog.Set("请求超时（秒）", "Request timeout (seconds)")
        catalog.Set("提示词：", "Prompts:")
        catalog.Set("生成", "Generieren")
        catalog.Set("优化", "Optimieren")
        catalog.Set("系统说明", "Systemanweisungen")
        catalog.Set("编辑", "Edit")
        catalog.Set("AI 提示词", "AI prompts")
        catalog.Set("生成提示词不能为空。", "Generation prompt cannot be empty.")
        catalog.Set("优化提示词不能为空。", "Optimization prompt cannot be empty.")
        catalog.Set("恢复默认", "Restore default")
        catalog.Set("系统说明不能为空。", "System instructions cannot be empty.")
        catalog.Set("生成重映射规则", "Generate remapping rule")
        catalog.Set("优化当前规则", "Optimize current rule")
        catalog.Set("AI 生成规则", "KI Regel erstellen")
        catalog.Set("设置序号圆点", "Nummernpunkt festlegen")
        catalog.Set("清除圆点颜色", "Punktfarbe löschen")
        catalog.Set("雾松绿", "Nebliges Kieferngrün")
        catalog.Set("青灰蓝", "Blaugrau")
        catalog.Set("薰衣草紫", "Lavendel")
        catalog.Set("烟粉", "Altrosa")
        catalog.Set("浅琥珀", "Heller Bernstein")
        catalog.Set("静谧青", "Ruhiges Türkis")
        catalog.Set("珍珠灰", "Perlgrau")
        catalog.Set("已更新 {1} 条规则的序号圆点颜色。", "Die Nummernpunktfarbe wurde für {1} Regeln aktualisiert.")
        catalog.Set("序号圆点颜色未保存：{1}", "Die Nummernpunktfarbe wurde nicht gespeichert: {1}")
        catalog.Set("AI 优化规则", "KI Regel optimieren")
        catalog.Set("请输入规则目的。", "Geben Sie den Zweck der Regel ein.")
        catalog.Set("说点什么吧，我什么都会做的 T_T", "Sag einfach, was du willst. Ich kann alles T_T")
        catalog.Set("我是来帮你的，你要干什么？！", "Ich bin hier, um dir zu helfen. Was willst du tun?!")
        catalog.Set("请先关闭当前代码编辑器，再优化其他映射。", "Schließen Sie den aktuellen Code-Editor, bevor Sie eine andere Zuordnung optimieren.")
        catalog.Set("AI 服务尚未初始化。", "The AI service is not initialized.")
        catalog.Set("AI 参数未保存：{1}", "Die KI-Parameter wurden nicht gespeichert: {1}")
        catalog.Set("无法读取当前映射代码：{1}", "Could not read the current mapping code: {1}")
        catalog.Set("AI 正在生成规则，请稍候...", "AI is generating a rule. Please wait...")
        catalog.Set("AI 正在优化规则，请稍候...", "KI optimiert die Regel. Bitte warten...")
        catalog.Set("AI 请求失败，请检查 AI 设置和网络连接。", "Die KI-Anfrage ist fehlgeschlagen. Prüfen Sie die KI-Einstellungen und die Netzwerkverbindung.")
        catalog.Set("测试连接", "Verbindung testen")
        catalog.Set("正在测试 AI 连接…", "KI-Verbindung wird getestet…")
        catalog.Set("AI 连接测试成功。", "KI-Verbindungstest erfolgreich.")
        catalog.Set("AI 连接测试失败：{1}", "KI-Verbindungstest fehlgeschlagen: {1}")
        catalog.Set("请填写 API 地址。", "Geben Sie die API-Adresse ein.")
        catalog.Set("请填写模型名称。", "Geben Sie den Modellnamen ein.")
        catalog.Set("请求期间编辑器内容已变化，请重新执行 AI 操作。", "The editor changed during the request. Run the AI operation again.")
        catalog.Set("AI 规则已放入编辑器，请检查后保存。", "The AI rule is in the editor. Review it before saving.")
        catalog.Set("状态", "Status")
        catalog.Set("启用", "Aktiviert")
        catalog.Set("无法读取设置文件，已使用默认设置：{1}", "Die Einstellungen konnten nicht gelesen werden`; Standardwerte werden verwendet: {1}")
        catalog.Set("审阅 AI 优化结果", "KI-Optimierung prüfen")
        catalog.Set("已保留原内容，AI 结果未应用。", "Der ursprüngliche Inhalt wurde beibehalten. Das KI-Ergebnis wurde nicht angewendet.")
        catalog.Set("AI 结果无法应用到编辑器，请重试。", "Das KI-Ergebnis konnte nicht im Editor angewendet werden. Versuchen Sie es erneut.")
        catalog.Set("无法打开 AI 结果审阅：{1}", "Die Prüfung des KI-Ergebnisses konnte nicht geöffnet werden: {1}")
        catalog.Set("当前 {1} 行，AI 建议 {2} 行；约 {3} 行有变化。", "Aktuell: {1} Zeilen`; KI-Vorschlag: {2} Zeilen`; etwa {3} Zeilen geändert.")
        catalog.Set("当前内容", "Aktueller Inhalt")
        catalog.Set("AI 建议", "KI-Vorschlag")
        catalog.Set("接受结果", "Ergebnis übernehmen")
        catalog.Set("保留原文", "Original behalten")
        catalog.Set("AI 返回的规则经过自动修复后仍未通过本地校验：{1}", "Die KI-Regel hat die lokale Prüfung auch nach der automatischen Reparatur nicht bestanden: {1}")
        catalog.Set("AI 规则校验结果不完整。", "Das Prüfergebnis der KI-Regel ist unvollständig.")
        catalog.Set("AI 正在复核规则的实际行为，请稍候...", "Die KI prüft das tatsächliche Verhalten der Regel. Bitte warten...")
        catalog.Set("AI 正在根据本地校验结果修复规则，请稍候...", "Die KI repariert die Regel anhand der lokalen Prüfung. Bitte warten...")
        catalog.Set("本地校验失败：{1}", "Lokale Prüfung fehlgeschlagen: {1}")
        catalog.Set("失败发生阶段：{1}", "Fehlerphase: {1}")
        catalog.Set("必须修复根因并重新满足用户原始目的。", "Beheben Sie die Ursache und erfüllen Sie die ursprüngliche Absicht des Benutzers vollständig.")
        catalog.Set("规则块能力不足，必须改用受托管脚本完整实现。", "Ein Standardregelblock reicht nicht aus`; verwenden Sie für die vollständige Umsetzung ein verwaltetes Skript.")
        catalog.Set("未保存：请先用完整的 AHK v2 脚本替换代码占位文字。", "Nicht gespeichert: Ersetzen Sie zuerst den Codeplatzhalter durch ein vollständiges AHK-v2-Skript.")
        catalog.Set("当前等待时间：{1} 秒", "Current wait time: {1} seconds")
        return catalog
    }
}
