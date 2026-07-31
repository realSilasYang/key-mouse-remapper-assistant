; it-IT 本地化词条目录。
; 简体中文原文是稳定键；本目录与其它语言保持完全相同的键集合。

class ItalianStrings {
    static Create() {
        catalog := Map()
        catalog.CaseSense := "On"
        catalog.Set("按下", "Premi")
        catalog.Set(
            "键鼠重映射小助手",
                "Assistente di rimappatura tastiera e mouse")
        catalog.Set(
            "新增",
                "Aggiungi")
        catalog.Set(
            "新增映射",
                "Aggiungi mappatura")
        catalog.Set(
            "删除",
                "Elimina")
        catalog.Set(
            "暂停",
                "Pausa")
        catalog.Set(
            "恢复",
                "Riprendi")
        catalog.Set(
            "序号",
                "N.")
        catalog.Set(
            "来源按键",
                "Chiave di origine")
        catalog.Set(
            "映射结果",
                "Risultato mappato")
        catalog.Set(
            "生效范围",
                "Ambito")
        catalog.Set(
            "设计目的",
                "Scopo")
        catalog.Set(
            "新建映射",
                "Nuova mappatura")
        catalog.Set(
            "映射为",
                "Mappa su")
        catalog.Set(
            "点击录制来源按键",
                "Fare clic per registrare le chiavi sorgente")
        catalog.Set(
            "点击录制目标按键",
                "Fare clic per registrare le chiavi di destinazione")
        catalog.Set(
            "保存映射",
                "Salva")
        catalog.Set(
            "清空",
                "Chiaro")
        catalog.Set(
            "准备就绪",
                "Pronto")
        catalog.Set(
            "请按下按键 · Esc 取消",
                "Premere i tasti · Esc per annullare")
        catalog.Set(
            "编辑映射代码",
                "Modifica il codice di mappatura")
        catalog.Set(
            "新增映射代码",
                "Aggiungi il codice di mappatura")
        catalog.Set(
            "元数据说明",
                "Riferimento ai metadati")
        catalog.Set(
            "RuleSpec 外壳版本，当前必须为 2。",
                "Versione dell'involucro RuleSpec; attualmente deve essere 2.")
        catalog.Set(
            "规则模式，当前必须为 managed。",
                "Modalità della regola; attualmente deve essere managed.")
        catalog.Set(
            "映射的唯一编号，必须与 RuleSpec 的 id 一致。",
                "ID univoco della mappatura; deve corrispondere all'id RuleSpec.")
        catalog.Set(
            "结构化 RuleSpec JSON 的开始标记。",
                "Marcatore iniziale del JSON RuleSpec strutturato.")
        catalog.Set(
            "注释化 JSON；可编辑来源、条件、显示信息和输出动作。",
                "JSON commentato; modifica origine, condizioni, dati visualizzati e azioni di output.")
        catalog.Set(
            "结构化 RuleSpec JSON 的结束标记。",
                "Marcatore finale del JSON RuleSpec strutturato.")
        catalog.Set(
            "规范化 RuleSpec JSON 的 SHA-256 摘要。",
                "Digest SHA-256 del JSON RuleSpec normalizzato.")
        catalog.Set(
            "生成区只含说明注释，不包含可执行 AHK。",
                "L'area generata contiene solo commenti esplicativi e nessun AHK eseguibile.")
        catalog.Set(
            "整个映射块只允许注释化 RuleSpec JSON；右侧说明仅供参考，不会保存到代码。",
                "L'intero blocco di mappatura consente solo JSON RuleSpec commentato. La guida a destra non viene salvata.")
        catalog.Set(
            "代码修改尚未保存，确定放弃吗？",
                "Il codice presenta modifiche non salvate. Scartarli?")
        catalog.Set(
            "放弃修改",
                "Annulla modifiche")
        catalog.Set(
            "显示主界面",
                "Mostra la finestra principale")
        catalog.Set(
            "重新加载",
                "Ricarica")
        catalog.Set(
            "以管理员身份重新启动",
                "Riavvia come amministratore")
        catalog.Set(
            "管理员模式（当前）",
                "Modalità amministratore (attiva)")
        catalog.Set(
            "无法以管理员身份重新启动（错误代码 {1}）。",
                "Impossibile riavviare come amministratore (errore {1}).")
        catalog.Set(
            "事件查看器",
                "Eventi")
        catalog.Set("事件详情", "Dettagli evento")
        catalog.Set("事件：{1}", "Evento: {1}")
        catalog.Set("类别：{1}", "Categoria: {1}")
        catalog.Set("时间：{1}", "Ora: {1}")
        catalog.Set("来源：{1}", "Origine: {1}")
        catalog.Set("结果：{1}", "Risultato: {1}")
        catalog.Set("详情：{1}", "Dettagli: {1}")
        catalog.Set("按键名称：{1}", "Nome tasto: {1}")
        catalog.Set("原始观察", "Osservazione input grezzo")
        catalog.Set("退出观察", "Termina osservazione")
        catalog.Set("原始观察中", "Osservazione input grezzo attiva")
        catalog.Set("原始观察切换失败：{1}",
            "Impossibile cambiare l’osservazione input grezzo: {1}")
        catalog.Set("诊断包", "Diagnostica")
        catalog.Set("诊断包预览", "Anteprima pacchetto diagnostico")
        catalog.Set("导出诊断包", "Esporta pacchetto diagnostico")
        catalog.Set("诊断包导出失败：{1}",
            "Impossibile esportare il pacchetto diagnostico: {1}")
        catalog.Set("诊断包已导出：{1}", "Pacchetto diagnostico esportato: {1}")
        catalog.Set("将导出 {1} 条事件；已脱敏窗口标题 {2}、路径 {3}、文本/命令 {4}、代码 {5}、变量值 {6} 项。是否继续？",
            "Esportare {1} eventi? Sono stati oscurati {2} titoli di finestra, {3} percorsi, {4} valori testo/comando, {5} valori di codice e {6} valori di variabili.")
        catalog.Set(
            "导入规则包",
                "Importa pacchetto di regole")
        catalog.Set(
            "导出规则包",
                "Pacchetto di regole di esportazione")
        catalog.Set(
            "规则包导出失败：{1}",
                "Esportazione del pacchetto di regole non riuscita: {1}")
        catalog.Set(
            "已导出 {1} 条规则：{2}",
                "Regole esportate {1}: {2}")
        catalog.Set(
            "规则包导入失败：{1}",
                "Importazione del pacchetto di regole non riuscita: {1}")
        catalog.Set(
            "规则包导入失败，且回滚失败：{1}",
                "Importazione e rollback del pacchetto di regole non riusciti: {1}")
        catalog.Set(
            "规则包导入完成：新增 {1}，替换 {2}，重命名 {3}，跳过 {4}。",
                "Importazione completata: {1} aggiunto, {2} sostituito, {3} rinominato, {4} saltato.")
        catalog.Set("变量", "Variabili")
        catalog.Set("变量快照", "Istantanea variabili")
        catalog.Set("导入规则包预览", "Anteprima importazione pacchetto")
        catalog.Set("来源：{1} · 版本：{2}", "Origine: {1} · Versione: {2}")
        catalog.Set("共 {1} 条规则，默认选中 {2} 条；权限：{3}", "{1} regole; {2} selezionate. Autorizzazioni: {3}")
        catalog.Set("规则编号", "ID regola")
        catalog.Set("模式", "Modalità")
        catalog.Set("权限", "Autorizzazioni")
        catalog.Set("全选", "Seleziona tutto")
        catalog.Set("全部取消", "Deseleziona tutto")
        catalog.Set("导入所选", "Importa selezionate")
        catalog.Set("无额外权限", "Nessuna autorizzazione aggiuntiva")
        catalog.Set("请至少选择一条规则。", "Seleziona almeno una regola.")
        catalog.Set("导入失败，请查看主窗口状态。", "Importazione non riuscita. Controlla lo stato della finestra principale.")
        catalog.Set(
            "筛选：",
                "Filtra:")
        catalog.Set(
            "全部事件",
                "Tutti gli eventi")
        catalog.Set(
            "输入事件",
                "Ingresso")
        catalog.Set(
            "规则运行",
                "Durata")
        catalog.Set(
            "规则仓储",
                "Deposito")
        catalog.Set(
            "撤销历史",
                "Storia")
        catalog.Set(
            "系统事件",
                "Sistema")
        catalog.Set(
            "界面事件",
                "interfaccia utente")
        catalog.Set(
            "暂停刷新",
                "Pausa")
        catalog.Set(
            "恢复刷新",
                "Riprendi")
        catalog.Set(
            "导出事件",
                "Esporta eventi")
        catalog.Set(
            "时间",
                "Tempo")
        catalog.Set(
            "类别",
                "Categoria")
        catalog.Set(
            "事件",
                "Evento")
        catalog.Set(
            "来源 / 规则",
                "Fonte/regola")
        catalog.Set(
            "结果",
                "Risultato")
        catalog.Set(
            "详情",
                "Dettagli")
        catalog.Set(
            "输入",
                "Ingresso")
        catalog.Set(
            "运行时",
                "Durata")
        catalog.Set(
            "仓储",
                "Deposito")
        catalog.Set(
            "历史",
                "Storia")
        catalog.Set(
            "系统",
                "Sistema")
        catalog.Set(
            "界面",
                "interfaccia utente")
        catalog.Set(
            "已暂停刷新",
                "In pausa")
        catalog.Set(
            "实时刷新",
                "Vivi")
        catalog.Set(
            "显示 {1} 条 · 缓冲区 {2}/{3} · 已丢弃 {4} 条 · {5}",
                "Visualizzazione {1} · buffer {2}/{3} · eliminato {4} · {5}")
        catalog.Set(
            "事件导出失败：{1}",
                "Esportazione evento non riuscita: {1}")
        catalog.Set(
            "事件已导出：{1}",
                "Eventi esportati: {1}")
        catalog.Set(
            "无法打开事件查看器：{1}",
                "Impossibile aprire il Visualizzatore eventi: {1}")
        catalog.Set(
            "退出程序",
                "Esci dal programma")
        catalog.Set(
            "设置",
                "Impostazioni")
        catalog.Set(
            "界面语言",
                "Lingua")
        catalog.Set(
            "主题",
                "Tema")
        catalog.Set(
            "界面语言：",
                "Lingua dell'interfaccia:")
        catalog.Set(
            "界面内容字体：",
                "Carattere dei contenuti dell'interfaccia:")
        catalog.Set(
            "主题：",
                "Tema:")
        catalog.Set(
            "跟随系统",
                "Segui il sistema")
        catalog.Set(
            "浅色",
                "Chiaro")
        catalog.Set(
            "深色",
                "Scuro")
        catalog.Set(
            "跟随语言默认（{1}）",
                "Carattere predefinito della lingua ({1})")
        catalog.Set(
            "保存",
                "Salva")
        catalog.Set(
            "取消",
                "Annulla")
        catalog.Set(
            "已暂停",
                "In pausa")
        catalog.Set(
            "已恢复脚本中的自定义顺序。",
                "Ripristinato l'ordine degli script personalizzati.")
        catalog.Set(
            "升序",
                "ascendente")
        catalog.Set(
            "降序",
                "discendente")
        catalog.Set(
            "已临时按“{1}”{2}排列；不会改写脚本顺序。",
                "Ordinato temporaneamente per {1} ({2}); l'ordine degli script è invariato.")
        catalog.Set(
            "无法恢复自定义顺序：{1}",
                "Impossibile ripristinare l'ordine personalizzato: {1}")
        catalog.Set(
            "映射顺序没有变化。",
                "L'ordine di mappatura non è cambiato.")
        catalog.Set(
            "无法启动按键录制，请重试。",
                "Impossibile avviare la registrazione della chiave. Riprova.")
        catalog.Set(
            "正在录制来源按键…",
                "Registrazione delle chiavi della sorgente...")
        catalog.Set(
            "正在录制目标按键…",
                "Registrazione delle chiavi di destinazione...")
        catalog.Set(
            "来源",
                "fonte")
        catalog.Set(
            "目标",
                "bersaglio")
        catalog.Set(
            "正在录制{1}按键：{2}",
                "Registrazione {1} chiavi: {2}")
        catalog.Set(
            "已录制{1}按键：{2}",
                "Chiavi {1} registrate: {2}")
        catalog.Set(
            "已取消按键录制。",
                "Registrazione chiave annullata.")
        catalog.Set(
            "请先完成或取消当前按键录制。",
                "Termina o annulla prima la registrazione corrente.")
        catalog.Set(
            "请先录制来源按键和目标按键。",
                "Registra prima sia la chiave di origine che quella di destinazione.")
        catalog.Set(
            "已清空新建区域。",
                "Cancellata la nuova area di mappatura.")
        catalog.Set(
            "请先选择要删除的映射。",
                "Seleziona prima una mappatura da eliminare.")
        catalog.Set(
            "所选映射缺少代码块编号，无法删除。",
                "La mappatura selezionata non ha un ID di blocco e non può essere eliminata.")
        catalog.Set(
            "请先选择要暂停或恢复的映射。",
                "Seleziona prima una mappatura da mettere in pausa o riprendere.")
        catalog.Set(
            "所选映射缺少代码块编号，无法修改状态。",
                "La mappatura selezionata non ha ID di blocco e non può cambiare stato.")
        catalog.Set(
            "无法打开映射代码：{1}",
                "Impossibile aprire il codice di mappatura: {1}")
        catalog.Set(
            "无法打开代码编辑器：{1}",
                "Impossibile aprire l'editor di codice: {1}")
        catalog.Set(
            "映射 · {1} -> {2}{3}",
                "Mappatura · {1} -> {2}{3}")
        catalog.Set(
            "全局",
                "Globale")
        catalog.Set(
            "按键名称：{1}`n虚拟键码：{2}`n扫描码：{3}",
                "Nome chiave: {1}`nChiave virtuale: {2}`nCodice di scansione: {3}")
        catalog.Set(
            "不适用",
                "n/d")
        catalog.Set(
            "键盘",
                "Tastiera")
        catalog.Set(
            "鼠标",
                "Topo")
        catalog.Set(
            "滚轮",
                "Ruota")
        catalog.Set(
            "多媒体",
                "Media")
        catalog.Set(
            "命名键",
                "Chiave denominata")
        catalog.Set(
            "左侧 Ctrl",
                "Ctrl sinistro")
        catalog.Set(
            "右侧 Ctrl",
                "Ctrl destro")
        catalog.Set(
            "左侧 Shift",
                "Spostamento a sinistra")
        catalog.Set(
            "右侧 Shift",
                "Spostamento a destra")
        catalog.Set(
            "左侧 Alt",
                "Alt. sinistra")
        catalog.Set(
            "右侧 Alt",
                "Alt. destra")
        catalog.Set(
            "左侧 Win",
                "Vittoria a sinistra")
        catalog.Set(
            "右侧 Win",
                "Giusto vincere")
        catalog.Set(
            "读取重映射代码区域失败：{1}",
                "Impossibile leggere la regione di mappatura: {1}")
        catalog.Set(
            "托管规则未应用：{1}",
                "Le regole gestite non sono state applicate: {1}")
        catalog.Set(
            "无法检查现有映射：{1}",
                "Impossibile controllare le mappature esistenti: {1}")
        catalog.Set(
            "为避免失去界面操作，来源按键不能是无修饰的鼠标左键。",
                "Un pulsante sinistro del mouse non modificato non può essere utilizzato come chiave sorgente.")
        catalog.Set(
            "该来源按键已被现有映射占用。",
                "Quella chiave di origine è già utilizzata da un'altra mappatura.")
        catalog.Set(
            "来源按键与目标按键相同，无需建立映射。",
                "Sorgente e destinazione sono identici; non è necessaria alcuna mappatura.")
        catalog.Set(
            "映射未写入脚本：{1}",
                "La mappatura non è stata scritta: {1}")
        catalog.Set(
            "已写入脚本：{1} -> {2}；正在自动应用。",
                "Scritto nello script: {1} -> {2}; applicazione automatica in corso.")
        catalog.Set(
            "删除映射",
                "Elimina la mappatura")
        catalog.Set(
            "映射未删除：{1}",
                "La mappatura non è stata eliminata: {1}")
        catalog.Set(
            "已从脚本删除：{1} -> {2}；正在自动应用。",
                "Eliminato dallo script: {1} -> {2}; applicazione automatica in corso.")
        catalog.Set(
            "调整映射顺序",
                "Riordinare le mappature")
        catalog.Set(
            "顺序未保存：{1}",
                "L'ordine non è stato salvato: {1}")
        catalog.Set(
            "已按拖动结果实时更新脚本顺序。",
                "Aggiornato l'ordine degli script dal risultato trascinato.")
        catalog.Set(
            "暂停映射",
                "Metti in pausa la mappatura")
        catalog.Set(
            "恢复映射",
                "Riprendi la mappatura")
        catalog.Set(
            "映射状态未修改：{1}",
                "Lo stato della mappatura non è stato modificato: {1}")
        catalog.Set(
            "已恢复映射：{1} -> {2}；正在自动应用。",
                "Mappatura ripresa: {1} -> {2}; applicazione automatica in corso.")
        catalog.Set(
            "已暂停映射：{1} -> {2}；正在自动应用。",
                "Mappatura in pausa: {1} -> {2}; applicazione automatica in corso.")
        catalog.Set(
            "映射代码未保存：{1}",
                "Il codice di mappatura non è stato salvato: {1}")
        catalog.Set(
            "映射代码未新增：{1}",
                "Il codice di mappatura non è stato aggiunto: {1}")
        catalog.Set(
            "未保存：{1}",
                "Non salvato: {1}")
        catalog.Set(
            "已保存映射代码：{1} -> {2}；正在自动应用。",
                "Codice di mappatura salvato: {1} -> {2}; applicazione automatica in corso.")
        catalog.Set(
            "已新增映射代码：{1} -> {2}；正在自动应用。",
                "Codice di mappatura aggiunto: {1} -> {2}; applicazione automatica in corso.")
        catalog.Set(
            "无法创建空白映射代码：{1}",
                "Impossibile creare il codice di mappatura vuoto: {1}")
        catalog.Set(
            "无法打开设置：{1}",
                "Impossibile aprire le impostazioni: {1}")
        catalog.Set(
            "设置未保存：{1}",
                "Le impostazioni non sono state salvate: {1}")
        catalog.Set(
            "界面内容字体",
                "Carattere dell'interfaccia utente")
        catalog.Set(
            "撤销失败：{1}",
                "Annullamento non riuscito: {1}")
        catalog.Set(
            "重做失败：{1}",
                "Ripetizione non riuscita: {1}")
        catalog.Set(
            "已撤销：{1}",
                "Annullato: {1}")
        catalog.Set(
            "已重做：{1}",
                "Ripetuto: {1}")
        catalog.Set(
            "映射配置",
                "Configurazione della mappatura")
        catalog.Set(
            "{1} 条重映射正在生效 · 当前为脚本代码顺序",
                "{1} mappature attive · ordine script personalizzato")
        catalog.Set("键鼠重映射小助手设置",
            "Impostazioni dell'assistente di rimappatura tastiera e mouse")
        catalog.Set("通用",
            "Generale")
        catalog.Set("关于",
            "Informazioni")
        catalog.Set("启动时显示主窗口",
            "Mostra la finestra principale all’avvio")
        catalog.Set("单独按 Esc 时取消录制",
            "Premi solo Esc per annullare la registrazione")
        catalog.Set("事件缓冲区容量（条）：",
            "Capacità del buffer eventi:")
        catalog.Set("事件查看器自动跟随最新事件",
            "Segui automaticamente gli eventi più recenti")
        catalog.Set("让每一条键鼠映射都可录制、可审阅、可掌控",
            "Registra, verifica e controlla ogni rimappatura di tastiera e mouse")
        catalog.Set("当前版本",
            "Versione corrente")
        catalog.Set("运行环境",
            "Ambiente di esecuzione")
        catalog.Set("查看最新版本",
            "Visualizza l’ultima versione")
        catalog.Set("开源地址",
            "Repository open source")
        catalog.Set("“{1}”必须是 {2} 到 {3} 之间的整数。",
            "“{1}” deve essere un numero intero compreso tra {2} e {3}.")
        catalog.Set("事件缓冲区容量",
            "Capacità del buffer eventi")
        catalog.Set("未知版本",
            "Versione sconosciuta")
        catalog.Set("{1}（EXE 版）",
            "{1} (versione EXE)")
        catalog.Set("{1}（源码版）",
            "{1} (versione sorgente)")
        catalog.Set("设置没有变化。",
            "Nessuna impostazione modificata.")
        catalog.Set("设置已保存并已应用。",
            "Impostazioni salvate e applicate.")
        catalog.Set("设置",
            "Impostazioni")
        catalog.Set("Esc 取消录制",
            "Esc annulla la registrazione")
        catalog.Set("事件自动跟随",
            "Segui gli eventi più recenti")
        catalog.Set("录制", "Registrazione")
        catalog.Set("事件", "Eventi")
        catalog.Set("{1}（便携版）", "{1} (versione portatile)")
        catalog.Set("帮助信息", "Guida")
        catalog.Set("捐赠", "Dona")
        catalog.Set("使用说明", "Guida all'uso")
        catalog.Set("提交反馈", "Invia feedback")
        catalog.Set("支持开源项目", "Sostieni il progetto open source")
        catalog.Set("微信支付", "WeChat Pay")
        catalog.Set("支付宝", "Alipay")
        catalog.Set("二维码图片未找到", "Immagine del codice QR non trovata")
        catalog.Set("如果小助手为您节省了排查问题和恢复程序的时间，欢迎通过下方二维码打赏作者！`n请选择扶贫方式：", "Se l’assistente ti ha fatto risparmiare tempo nella diagnosi dei problemi e nel ripristino dei programmi, puoi sostenere l’autore tramite i codici QR qui sotto!`nScegli come vuoi contribuire:")
        catalog.Set("无法打开帮助信息：{1}", "Impossibile aprire la Guida: {1}")
        catalog.Set("无法打开使用说明：{1}", "Impossibile aprire la guida all'uso: {1}")
        catalog.Set("无法打开捐赠窗口：{1}", "Impossibile aprire la finestra delle donazioni: {1}")
        catalog.Set("无法打开反馈页面：{1}", "Impossibile aprire la pagina dei feedback: {1}")
        catalog.Set("键鼠重映射小助手用于录制、审阅和维护键盘与鼠标映射。关闭主窗口只会隐藏到系统托盘，已经启用的映射仍会继续生效。", "L'assistente di rimappatura tastiera e mouse consente di registrare, esaminare e gestire le rimappature di tastiera e mouse. Chiudendo la finestra principale, l'app viene solo nascosta nell'area di notifica; le rimappature abilitate restano attive.")
        catalog.Set("一、快速上手", "1. Avvio rapido")
        catalog.Set("• 点击顶部“新增”，会打开已经填好元数据字段的 @mapping 编辑器；也可以在下方分别录制来源按键和目标按键，填写设计目的后保存。", "• Seleziona Aggiungi nella barra superiore per aprire un editor @mapping con i campi dei metadati già predisposti. Puoi anche registrare separatamente l'origine e la destinazione in basso, indicare lo scopo e salvare.")
        catalog.Set("• 录制会实时显示原始规范名称、阅读友好名称、虚拟键码和扫描码，并区分左右 Ctrl、Shift、Alt、Win 以及键盘、鼠标和滚轮输入。", "• La registrazione mostra in tempo reale il nome canonico, il nome leggibile, il codice tasto virtuale e il codice di scansione. Distingue Ctrl, Maiusc, Alt e Win sinistri e destri, oltre agli input di tastiera, mouse e rotellina.")
        catalog.Set("• 同时按下的任意按键会组成一次录制；所有按键释放后结束。录制期间再次点击录制按钮会取消本次录制，不会把该次点击记为 LButton。", "• Tutti i tasti tenuti premuti insieme formano una registrazione, che termina quando vengono rilasciati tutti. Selezionando di nuovo il pulsante di registrazione, l'operazione viene annullata anziché registrare quel clic come LButton.")
        catalog.Set("二、主界面与代码编辑", "2. Finestra principale e modifica del codice")
        catalog.Set("• 单击选择映射；双击条目、悬停时按 F2 或使用右键菜单，可编辑完整 @mapping 代码块。", "• Fai clic una volta per selezionare una rimappatura. Fai doppio clic su una riga, premi F2 mentre la punti oppure usa il menu contestuale per modificare l'intero blocco @mapping.")
        catalog.Set("• 选中条目后可暂停、恢复或删除；直接拖动列表行可调整永久顺序，脚本中的代码块顺序会实时同步。", "• Una rimappatura selezionata può essere sospesa, ripresa o eliminata. Trascina le righe per cambiare l'ordine permanente; l'ordine dei blocchi nello script viene sincronizzato subito.")
        catalog.Set("• 点击伪表头只进行临时排序；字段按升序、降序、自定义顺序循环，序号列按降序、自定义顺序循环，不会改写脚本。", "• L'ordinamento tramite le intestazioni simulate è temporaneo. I campi alternano ordine crescente, decrescente e personalizzato; la colonna del numero alterna ordine decrescente e personalizzato. Lo script non viene riscritto.")
        catalog.Set("• 映射区域只保存注释化 RuleSpec v2，是映射的唯一持久来源。GUI 创建或编辑的托管规则会直接热应用；可执行 AHK 代码不会被接受。", "• L'area di mappatura memorizza solo RuleSpec v2 commentate ed è l'unica origine persistente. Le regole gestite create o modificate nella GUI vengono applicate a caldo; il codice AHK eseguibile viene rifiutato.")
        catalog.Set("四、事件、历史与界面设置", "4. Eventi, cronologia e aspetto")
        catalog.Set("• 事件查看器记录输入、规则匹配、条件拒绝、执行结果、仓储和系统事件，支持筛选、暂停、清空及 JSONL 导出。", "• Il Visualizzatore eventi registra input, corrispondenze di regole, rifiuti delle condizioni, risultati di esecuzione, attività dell'archivio ed eventi di sistema. Supporta filtri, pausa, cancellazione ed esportazione JSONL.")
        catalog.Set("五、后台运行与问题排查", "5. Esecuzione in background e risoluzione dei problemi")
        catalog.Set("• 主窗口关闭后程序仍驻留托盘。托盘可以重新显示主界面、手动重新加载或彻底退出；修改映射规则后通常不需要手动重新加载。", "• L'app resta nell'area di notifica dopo la chiusura della finestra principale. Da lì puoi mostrare la finestra, ricaricare manualmente o uscire del tutto; le modifiche alle regole normalmente non richiedono un ricaricamento manuale.")
        catalog.Set("• 映射对管理员程序无效时，请从托盘选择以管理员身份重新启动。遇到规则冲突或按键未按预期执行时，先在事件查看器中核对输入和规则结果。", "• Se una rimappatura non agisce su un'app con privilegi elevati, riavvia questa app come amministratore dall'area di notifica. In caso di conflitti o input inattesi, controlla prima gli input e i risultati delle regole nel Visualizzatore eventi.")
        catalog.Set("• “帮助信息”还可打开项目反馈页面。提交问题时请说明系统版本、复现步骤、相关 @mapping 代码和事件导出，并在公开前移除敏感路径或应用信息。", "• La Guida apre anche la pagina dei feedback del progetto. Quando segnali un problema, includi la versione di Windows, i passaggi per riprodurlo, il codice @mapping pertinente e un'esportazione degli eventi, rimuovendo prima della pubblicazione percorsi o dati sensibili delle app.")
        catalog.Set("安全模式：已停用所有映射和输入观察。连续启动失败 {1} 次。", "Modalità provvisoria: tutte le rimappature e l'osservazione dell'input sono disattivate dopo {1} avvii non riusciti consecutivi.")
        catalog.Set("恢复最后正常配置", "Ripristina l'ultima configurazione valida")
        catalog.Set("没有可恢复的最后正常配置。", "Non è disponibile alcuna ultima configurazione valida.")
        catalog.Set("最后正常配置恢复失败：{1}", "Impossibile ripristinare l'ultima configurazione valida: {1}")
        catalog.Set("最后正常配置已恢复，正在自动应用。", "L'ultima configurazione valida è stata ripristinata e viene applicata automaticamente.")
        catalog.Set("仅勾选的规则会被导入。", "Verranno importate solo le regole selezionate.")
        catalog.Set("三、规则与生效范围", "3. Regole e ambito")
        catalog.Set("• 所有规则属于同一全局规则集；生效范围和条件可在 @mapping 编辑器中精确调整，保存后会立即重新选择生效规则。", "• Tutte le regole appartengono a un unico insieme globale. Ambito e condizioni possono essere regolati con precisione nell'editor @mapping. Il salvataggio riseleziona subito le regole attive.")
        catalog.Set("• Ctrl+Z 撤销，Ctrl+Shift+Z 或 Ctrl+Y 重做。映射增删、暂停恢复、拖动排序、代码编辑和设置修改都会进入持久历史。", "• Ctrl+Z annulla; Ctrl+Shift+Z o Ctrl+Y ripristina. Aggiunte, eliminazioni, pause, riprese, riordinamenti, modifiche al codice e impostazioni restano nella cronologia persistente.")
        return catalog
    }
}
