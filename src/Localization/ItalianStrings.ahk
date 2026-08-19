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
            "删除",
                "Elimina")
        catalog.Set(
            "暂停",
                "Pausa")
        catalog.Set(
            "恢复",
                "Riprendi")
        catalog.Set("反转状态", "Inverti stato")
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
            "名称",
                "Nome")
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
        catalog.Set("规则块", "Regola normale")
        catalog.Set("受托管脚本", "Script gestito")
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
            "事件查看",
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
            "规则包导入完成：新增 {1}，替换 {2}，重命名 {3}，跳过 {4}。",
                "Importazione completata: {1} aggiunto, {2} sostituito, {3} rinominato, {4} saltato.")
        catalog.Set("导入规则包预览", "Anteprima importazione pacchetto")
        catalog.Set("来源：{1} · 版本：{2}", "Origine: {1} · Versione: {2}")
        catalog.Set("共 {1} 条规则，默认选中 {2} 条；权限：{3}", "{1} regole; {2} selezionate. Autorizzazioni: {3}")
        catalog.Set("模式", "Modalità")
        catalog.Set("权限", "Autorizzazioni")
        catalog.Set("全选", "Seleziona tutto")
        catalog.Set("全部取消", "Deseleziona tutto")
        catalog.Set("导入所选", "Importa selezionate")
        catalog.Set("无额外权限", "Nessuna autorizzazione aggiuntiva")
        catalog.Set("生成键鼠输入", "Generare input da tastiera e mouse")
        catalog.Set("控制活动窗口", "Controllare la finestra attiva")
        catalog.Set("执行系统控制", "Eseguire un controllo di sistema")
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
            "系统事件",
                "Sistema")
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
            "退出程序",
                "Esci dal programma")
        catalog.Set(
            "设置",
                "Impostazioni")
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
        catalog.Set("无法启动按键录制：{1}", "Impossibile avviare la registrazione dei tasti: {1}")
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
            "所选映射缺少名称，无法删除。",
                "La mappatura selezionata non ha un nome e non può essere eliminata.")
        catalog.Set(
            "请先选择要暂停或恢复的映射。",
                "Seleziona prima una mappatura da mettere in pausa o riprendere.")
        catalog.Set(
            "所选映射缺少名称，无法修改状态。",
                "La mappatura selezionata non ha un nome e non può cambiare stato.")
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
            "为避免失去界面操作，来源按键不能是无修饰的鼠标左键。",
                "Un pulsante sinistro del mouse non modificato non può essere utilizzato come chiave sorgente.")
        catalog.Set(
            "映射未写入脚本：{1}",
                "La mappatura non è stata scritta: {1}")
        catalog.Set(
            "已写入脚本：{1} -> {2}；已应用。",
                "Scritto nello script: {1} -> {2}; applicato.")
        catalog.Set(
            "映射未删除：{1}",
                "La mappatura non è stata eliminata: {1}")
        catalog.Set(
            "已从脚本删除：{1} -> {2}；已应用。",
                "Eliminato dallo script: {1} -> {2}; applicato.")
        catalog.Set(
            "顺序未保存：{1}",
                "L'ordine non è stato salvato: {1}")
        catalog.Set(
            "已按拖动结果实时更新脚本顺序。",
                "Aggiornato l'ordine degli script dal risultato trascinato.")
        catalog.Set(
            "映射状态未修改：{1}",
                "Lo stato della mappatura non è stato modificato: {1}")
        catalog.Set(
            "已恢复映射：{1} -> {2}；已应用。",
                "Mappatura ripresa: {1} -> {2}; applicata.")
        catalog.Set(
            "已暂停映射：{1} -> {2}；已应用。",
                "Mappatura in pausa: {1} -> {2}; applicata.")
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
            "已保存映射代码：{1} -> {2}；已应用。",
                "Codice di mappatura salvato: {1} -> {2}; applicato.")
        catalog.Set(
            "已新增映射代码：{1} -> {2}；已应用。",
                "Codice di mappatura aggiunto: {1} -> {2}; applicato.")
        catalog.Set("已保存，正在后台应用…",
            "Salvato; applicazione in background...")
        catalog.Set("受托管脚本已应用。", "Script gestito applicato.")
        catalog.Set("映射代码没有变化。", "Il codice di mappatura non è cambiato.")
        catalog.Set("映射代码已保存，但受托管脚本应用失败：{1}",
            "Il codice di mappatura è stato salvato, ma lo script gestito non è stato applicato: {1}")
        catalog.Set(
            "无法创建空白映射代码：{1}",
                "Impossibile creare il codice di mappatura vuoto: {1}")
        catalog.Set(
            "设置未保存：{1}",
                "Le impostazioni non sono state salvate: {1}")
        catalog.Set(
            "{1} 条重映射正在生效 · 当前为脚本代码顺序",
                "{1} mappature attive · ordine script personalizzato")
        catalog.Set("键鼠重映射小助手设置",
            "Impostazioni dell'assistente di rimappatura tastiera e mouse")
        catalog.Set("启动",
            "Avvio")
        catalog.Set("显示",
            "Visualizzazione")
        catalog.Set("规则与事件",
            "Regole ed eventi")
        catalog.Set("关于",
            "Informazioni")
        catalog.Set("事件缓冲区容量（条）：",
            "Capacità del buffer eventi:")
        catalog.Set("事件查看自动跟随最新事件",
            "Segui automaticamente gli eventi più recenti")
        catalog.Set("让每一条键鼠映射都可录制、可审阅、可掌控",
            "Registra, verifica e controlla ogni rimappatura di tastiera e mouse")
        catalog.Set("当前版本",
            "Versione corrente")
        catalog.Set("运行环境",
            "Ambiente di esecuzione")
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
        catalog.Set("设置已保存并已应用。",
            "Impostazioni salvate e applicate.")
        catalog.Set("Esc 取消录制",
            "Esc annulla la registrazione")
        catalog.Set("{1}（便携版）", "{1} (versione portatile)")
        catalog.Set("快揭不开锅了（≥Д≤）",
            "La cassa è quasi vuota（≥Д≤）")
        catalog.Set("使用说明", "Guida all'uso")
        catalog.Set("提交反馈", "Invia feedback")
        catalog.Set("支持开源项目", "Sostieni il progetto open source")
        catalog.Set("微信支付", "WeChat Pay")
        catalog.Set("支付宝", "Alipay")
        catalog.Set("二维码图片未找到", "Immagine del codice QR non trovata")
        catalog.Set("如果小助手为您节省了配置键鼠映射的时间，欢迎通过下方二维码打赏作者！`n请选择扶贫方式（≥Д≤）", "Se l’assistente ti ha fatto risparmiare tempo nella configurazione delle mappature di tastiera e mouse, puoi sostenere l’autore tramite i codici QR qui sotto!`nScegli come vuoi contribuire (≥Д≤)")
        catalog.Set("无法打开反馈页面：{1}", "Impossibile aprire la pagina dei feedback: {1}")
        catalog.Set("键鼠重映射小助手用于录制、审阅和维护键盘与鼠标映射。关闭主窗口只会隐藏到系统托盘，已经启用的映射仍会继续生效。", "L'assistente di rimappatura tastiera e mouse consente di registrare, esaminare e gestire le rimappature di tastiera e mouse. Chiudendo la finestra principale, l'app viene solo nascosta nell'area di notifica; le rimappature abilitate restano attive.")
        catalog.Set("一、快速上手", "1. Avvio rapido")
        catalog.Set("• 点击顶部“新增”，会打开已经填好元数据字段的 @mapping 编辑器；也可以在下方分别录制来源按键和目标按键，填写名称后保存。", "• Seleziona Aggiungi nella barra superiore per aprire un editor @mapping con i campi dei metadati già predisposti. Puoi anche registrare separatamente l'origine e la destinazione in basso, inserire un nome e salvare.")
        catalog.Set("• 录制会实时显示原始规范名称、阅读友好名称、虚拟键码和扫描码，并区分左右 Ctrl、Shift、Alt、Win 以及键盘、鼠标和滚轮输入。", "• La registrazione mostra in tempo reale il nome canonico, il nome leggibile, il codice tasto virtuale e il codice di scansione. Distingue Ctrl, Maiusc, Alt e Win sinistri e destri, oltre agli input di tastiera, mouse e rotellina.")
        catalog.Set("二、主界面与代码编辑", "2. Finestra principale e modifica del codice")
        catalog.Set("• 单击选择映射；双击条目、选中后按 F2 或使用右键菜单，可编辑完整 @mapping 代码块。", "• Fai clic una volta per selezionare una rimappatura. Fai doppio clic su una riga, premi F2 dopo averla selezionata oppure usa il menu contestuale per modificare l'intero blocco @mapping.")
        catalog.Set("• 选中条目后可暂停、恢复或删除；直接拖动列表行可调整永久顺序，脚本中的代码块顺序会实时同步。", "• Una rimappatura selezionata può essere sospesa, ripresa o eliminata. Trascina le righe per cambiare l'ordine permanente; l'ordine dei blocchi nello script viene sincronizzato subito.")
        catalog.Set("• 点击伪表头只进行临时排序；字段按升序、降序、自定义顺序循环，序号列按降序、自定义顺序循环，不会改写脚本。", "• L'ordinamento tramite le intestazioni simulate è temporaneo. I campi alternano ordine crescente, decrescente e personalizzato; la colonna del numero alterna ordine decrescente e personalizzato. Lo script non viene riscritto.")
        catalog.Set("• 事件查看记录输入、规则匹配、条件拒绝、执行结果、仓储和系统事件，支持筛选、暂停、清空及 JSONL 导出。", "• Il Visualizzatore eventi registra input, corrispondenze di regole, rifiuti delle condizioni, risultati di esecuzione, attività dell'archivio ed eventi di sistema. Supporta filtri, pausa, cancellazione ed esportazione JSONL.")
        catalog.Set("四、事件查看与设置", "4. Visualizzatore eventi e impostazioni")
        catalog.Set("五、后台运行与问题排查", "5. Esecuzione in background e risoluzione dei problemi")
        catalog.Set("• 主窗口关闭后程序仍驻留托盘。托盘可以重新显示主界面、手动重新加载或彻底退出；修改映射规则后通常不需要手动重新加载。", "• L'app resta nell'area di notifica dopo la chiusura della finestra principale. Da lì puoi mostrare la finestra, ricaricare manualmente o uscire del tutto; le modifiche alle regole normalmente non richiedono un ricaricamento manuale.")
        catalog.Set("仅勾选的规则会被导入。", "Verranno importate solo le regole selezionate.")
        catalog.Set("三、规则与生效范围", "3. Regole e ambito")
        catalog.Set("• 所有规则属于同一全局规则集；生效范围和条件可在 @mapping 编辑器中精确调整，保存后会立即重新选择生效规则。", "• Tutte le regole appartengono a un unico insieme globale. Ambito e condizioni possono essere regolati con precisione nell'editor @mapping. Il salvataggio riseleziona subito le regole attive.")
        catalog.Set("没有可撤销的映射变更。", "Non ci sono modifiche di mappatura da annullare.")
        catalog.Set("已撤销上一步映射变更。", "L’ultima modifica di mappatura è stata annullata.")
        catalog.Set("撤销映射变更失败：{1}", "Impossibile annullare la modifica di mappatura: {1}")
        catalog.Set("没有可重做的映射变更。", "Non ci sono modifiche di mappatura da ripetere.")
        catalog.Set("已重做映射变更。", "La modifica di mappatura è stata ripetuta.")
        catalog.Set("重做映射变更失败：{1}", "Impossibile ripetere la modifica di mappatura: {1}")
        catalog.Set("录制结束后无法恢复重映射：{1}", "Impossibile riprendere la rimappatura dopo la registrazione: {1}")
        catalog.Set("• 新增、删除、暂停或恢复、代码编辑、拖动排序和规则包导入均可撤销；Ctrl+Z 撤销，Ctrl+Shift+Z 或 Ctrl+Y 重做。", "• Aggiunta, eliminazione, pausa o ripresa, modifica del codice, riordino mediante trascinamento e importazione di pacchetti di regole possono essere annullati. Ctrl+Z annulla; Ctrl+Maiusc+Z o Ctrl+Y ripete.")
        catalog.Set("开机自动启动（计划任务）", "Avvio automatico all'accesso（attività pianificata）")
        catalog.Set("检查更新失败：{1}", "Controllo degli aggiornamenti non riuscito: {1}")
        catalog.Set("启动时显示主窗口", "Mostra la finestra principale all'avvio")
        catalog.Set("更新检查正在进行，请稍候。", "È già in corso un controllo degli aggiornamenti. Attendere.")
        catalog.Set("关闭", "Disattiva")
        catalog.Set("将下载并校验源码发行包，保留个人配置后替换源码并自动重启。", "Il pacchetto del codice sorgente verrà scaricato e verificato. Il codice verrà quindi sostituito conservando le impostazioni personali e l'assistente si riavvierà automaticamente.")
        catalog.Set("桌面与开始菜单快捷方式", "Collegamenti sul desktop e nel menu Start")
        catalog.Set("创建", "Crea")
        catalog.Set("无法检查更新：{1}", "Impossibile controllare gli aggiornamenti: {1}")
        catalog.Set("提示", "Avviso")
        catalog.Set("检测到同名计划任务，但它并非当前程序创建；为避免误删，请先在任务计划程序中处理它。", "È stata rilevata un'attività pianificata con lo stesso nome, ma non è stata creata da questo programma. Per evitare di eliminarla per errore, gestirla prima nell'Utilità di pianificazione.")
        catalog.Set("立即更新", "Aggiorna ora")
        catalog.Set("错误", "Errore")
        catalog.Set("创建成功！", "Creati!")
        catalog.Set("无法建立单实例运行锁，小助手将退出。", "Impossibile ottenere il blocco per l'istanza singola`; l'assistente verrà chiuso.")
        catalog.Set("重新加载失败，已保留当前实例：{1}", "Ricaricamento non riuscito`; l'istanza corrente è stata mantenuta: {1}")
        catalog.Set("稍后", "Più tardi")
        catalog.Set("切换", "Cambia")
        catalog.Set("冲突", "Conflitto")
        catalog.Set("将确认源码仓库没有未提交修改，再快速前进到正式发布标签并自动重启。", "Verrà verificato che il repository del codice sorgente non contenga modifiche non sottoposte a commit, quindi verrà eseguito un avanzamento rapido fino al tag di pubblicazione ufficiale seguito dal riavvio automatico.")
        catalog.Set("无法开始更新：{1}", "Impossibile avviare l'aggiornamento: {1}")
        catalog.Set("正在检查更新…", "Ricerca di aggiornamenti…")
        catalog.Set("检查更新", "Controlla aggiornamenti")
        catalog.Set("小助手更新", "Aggiornamento dell'assistente")
        catalog.Set("将下载并校验完整发行包，退出小助手后替换程序文件并自动重启。", "Il pacchetto di distribuzione completo verrà scaricato e verificato. Dopo la chiusura dell'assistente, i file del programma verranno sostituiti e l'assistente si riavvierà automaticamente.")
        catalog.Set("创建快捷方式失败：{1}", "Impossibile creare il collegamento: {1}")
        catalog.Set("当前陪伴您的已经是最新版本的小助手啦！", "L'assistente che ti accompagna è già aggiornato all'ultima versione!")
        catalog.Set("确定", "OK")
        catalog.Set("没有可安装的应用更新", "Nessun aggiornamento dell'applicazione disponibile per l'installazione")
        catalog.Set("更新检查未返回结果", "Il controllo degli aggiornamenti non ha restituito alcun risultato")
        catalog.Set("开启", "Attiva")
        catalog.Set("不可用", "Non disponibile")
        catalog.Set("启动失败", "Avvio non riuscito")
        catalog.Set("启动时检查小助手更新", "Controlla gli aggiornamenti dell'assistente all'avvio")
        catalog.Set("以管理员身份运行", "Esegui come amministratore")
        catalog.Set("操作计划任务时发生错误：{1}", "Si è verificato un errore durante la gestione dell’attività pianificata: {1}")
        catalog.Set("发现新版本 {1}，当前版本为 {2}。`n`n{3}`n`n是否立即更新？", "È disponibile la nuova versione {1}; la versione corrente è {2}.`n`n{3}`n`nAggiornare ora?")
        catalog.Set("开机自动启动", "Avvio automatico all’accesso")
        catalog.Set("输入录制不可用：{1}", "La registrazione dell’input non è disponibile: {1}")
        catalog.Set("新脚本未通过 AutoHotkey 启动验证。", "Il nuovo script non ha superato la verifica di avvio di AutoHotkey.")
        catalog.Set("保存并运行", "Salva ed esegui")
        catalog.Set("导入并运行", "Importa ed esegui")
        catalog.Set("导入自定义 AHK 代码", "Importa codice AHK personalizzato")
        catalog.Set("继续", "Continua")
        catalog.Set("切换规则类型", "Cambia tipo di regola")
        catalog.Set("切换规则类型会清空当前未保存内容，是否继续？", "Il cambio del tipo di regola cancellerà il contenuto corrente non salvato. Continuare?")
        catalog.Set("所选规则包含可读写文件、启动程序、控制窗口和请求管理员权限的自定义 AHK 代码。确认导入并运行吗？", "Le regole selezionate contengono codice AHK personalizzato che può leggere e scrivere file, avviare programmi, controllare finestre e richiedere privilegi di amministratore. Importare ed eseguire?")
        catalog.Set("无法创建规则模板：{1}", "Impossibile creare il modello della regola: {1}")
        catalog.Set("运行自定义 AHK 代码", "Esegui codice AHK personalizzato")
        catalog.Set("自定义 AHK 代码可读取文件、启动程序、控制窗口并请求管理员权限。确认运行当前代码吗？", "Il codice AHK personalizzato può leggere e scrivere file, avviare programmi, controllare finestre e richiedere privilegi di amministratore. Eseguire questo codice?")
        catalog.Set("规则未应用：{1}", "Le regole non sono state applicate: {1}")
        catalog.Set("• 映射区域以注释形式保存规则块和受托管脚本。规则块在主进程热应用；受托管脚本的自定义 AHK v2 源码在独立受管进程运行，保存、暂停、恢复、删除和退出均由小助手统一管理。", "• L’area di mappatura archivia blocchi regola normali e script gestiti sotto forma di commenti. I blocchi normali vengono applicati nel processo principale. Il codice AutoHotkey v2 personalizzato viene eseguito in un processo gestito separato controllato dall’assistente.")
        catalog.Set("区分左右修饰键", "Distingui i modificatori sinistri/destri")
        catalog.Set("帮助", "Aiuto")
        catalog.Set("打赏", "Dona")
        catalog.Set("打开帮助`n可选择查看使用说明、运行日志或提交反馈", "Apri Aiuto`nScegli la guida utente, il registro di esecuzione o l’invio di feedback")
        catalog.Set("点个 star 吧~", "Regalaci una stellina~")
        catalog.Set("配置显示、规则包和事件选项", "Configura visualizzazione, pacchetti di regole ed eventi")
        catalog.Set("查看版本、运行环境和项目入口", "Visualizza versione, ambiente runtime e link del progetto")
        catalog.Set("找作者对线", "Parla con autore")
        catalog.Set("演奏你的和弦！", "Suona il tuo accordo!")
        catalog.Set("• “帮助”还可打开项目反馈页面。提交问题时请说明系统版本、复现步骤、相关 @mapping 代码和事件导出，并在公开前移除敏感路径或应用信息。", "• La Guida apre anche la pagina dei feedback del progetto. Quando segnali un problema, includi la versione di Windows, i passaggi per riprodurlo, il codice @mapping pertinente e un'esportazione degli eventi, rimuovendo prima della pubblicazione percorsi o dati sensibili delle app.")
        catalog.Set("AI 设置", "AI settings")
        catalog.Set("API 地址：", "Indirizzo API:")
        catalog.Set("API 密钥：", "Chiave API:")
        catalog.Set("模型名称：", "Nome modello:")
        catalog.Set("请求超时（秒）：", "Request timeout (seconds):")
        catalog.Set("请求超时（秒）", "Request timeout (seconds)")
        catalog.Set("提示词：", "Prompt:")
        catalog.Set("生成", "Genera")
        catalog.Set("优化", "Ottimizza")
        catalog.Set("系统说明", "Istruzioni di sistema")
        catalog.Set("编辑", "Edit")
        catalog.Set("AI 提示词", "AI prompts")
        catalog.Set("生成提示词不能为空。", "Generation prompt cannot be empty.")
        catalog.Set("优化提示词不能为空。", "Optimization prompt cannot be empty.")
        catalog.Set("恢复默认", "Restore default")
        catalog.Set("系统说明不能为空。", "System instructions cannot be empty.")
        catalog.Set("生成重映射规则", "Generate remapping rule")
        catalog.Set("优化当前规则", "Optimize current rule")
        catalog.Set("AI 生成规则", "IA Genera regola")
        catalog.Set("设置序号圆点", "Imposta punto numerico")
        catalog.Set("清除圆点颜色", "Cancella colore del punto")
        catalog.Set("雾松绿", "Verde pino nebbia")
        catalog.Set("青灰蓝", "Blu grigiastro")
        catalog.Set("薰衣草紫", "Lavanda")
        catalog.Set("烟粉", "Rosa polvere")
        catalog.Set("浅琥珀", "Ambra chiara")
        catalog.Set("静谧青", "Verde acqua tenue")
        catalog.Set("珍珠灰", "Grigio perla")
        catalog.Set("已更新 {1} 条规则的序号圆点颜色。", "Colore del punto aggiornato per {1} regole.")
        catalog.Set("序号圆点颜色未保存：{1}", "Il colore del punto non è stato salvato: {1}")
        catalog.Set("AI 优化规则", "IA Ottimizza regola")
        catalog.Set("请输入规则目的。", "Inserisci lo scopo della regola.")
        catalog.Set("说点什么吧，我什么都会做的 T_T", "Dimmi pure quello che vuoi, so fare tutto T_T")
        catalog.Set("我是来帮你的，你要干什么？！", "Sono qui per aiutarti. Cosa vuoi fare?!")
        catalog.Set("请先关闭当前代码编辑器，再优化其他映射。", "Chiudi l'editor di codice corrente prima di ottimizzare un'altra mappatura.")
        catalog.Set("AI 服务尚未初始化。", "The AI service is not initialized.")
        catalog.Set("无法读取当前映射代码：{1}", "Could not read the current mapping code: {1}")
        catalog.Set("AI 正在生成规则，请稍候...", "AI is generating a rule. Please wait...")
        catalog.Set("AI 正在优化规则，请稍候...", "L'IA sta ottimizzando la regola. Attendere...")
        catalog.Set("AI 请求失败，请检查 AI 设置和网络连接。", "La richiesta IA non è riuscita. Controlla le impostazioni IA e la connessione di rete.")
        catalog.Set("测试连接", "Testa connessione")
        catalog.Set("正在测试 AI 连接…", "Test della connessione IA…")
        catalog.Set("AI 连接测试成功。", "Test della connessione IA riuscito.")
        catalog.Set("AI 连接测试失败：{1}", "Test della connessione IA non riuscito: {1}")
        catalog.Set("请填写 API 地址。", "Inserisci l’indirizzo API.")
        catalog.Set("请填写模型名称。", "Inserisci il nome del modello.")
        catalog.Set("请求期间编辑器内容已变化，请重新执行 AI 操作。", "The editor changed during the request. Run the AI operation again.")
        catalog.Set("AI 规则已放入编辑器，请检查后保存。", "The AI rule is in the editor. Review it before saving.")
        catalog.Set("状态", "Stato")
        catalog.Set("启用", "Attivata")
        catalog.Set("无法读取设置文件，已使用默认设置：{1}", "Impossibile leggere le impostazioni`; sono usati i valori predefiniti: {1}")
        catalog.Set("审阅 AI 优化结果", "Rivedi l’ottimizzazione AI")
        catalog.Set("已保留原内容，AI 结果未应用。", "Il contenuto originale è stato mantenuto. Il risultato AI non è stato applicato.")
        catalog.Set("AI 结果无法应用到编辑器，请重试。", "Impossibile applicare il risultato AI all’editor. Riprova.")
        catalog.Set("无法打开 AI 结果审阅：{1}", "Impossibile aprire la revisione del risultato AI: {1}")
        catalog.Set("当前 {1} 行，AI 建议 {2} 行；约 {3} 行有变化。", "Attuale: {1} righe`; proposta AI: {2} righe`; circa {3} righe modificate.")
        catalog.Set("当前内容", "Contenuto attuale")
        catalog.Set("AI 建议", "Proposta AI")
        catalog.Set("接受结果", "Accetta risultato")
        catalog.Set("保留原文", "Mantieni originale")
        catalog.Set("AI 返回的规则经过自动修复后仍未通过本地校验：{1}", "La regola AI non ha superato la convalida locale neanche dopo la riparazione automatica: {1}")
        catalog.Set("AI 规则校验结果不完整。", "Il risultato della convalida della regola AI è incompleto.")
        catalog.Set("AI 正在复核规则的实际行为，请稍候...", "L’AI sta verificando il comportamento effettivo della regola. Attendi...")
        catalog.Set("AI 正在根据本地校验结果修复规则，请稍候...", "L’AI sta riparando la regola in base alla convalida locale. Attendi...")
        catalog.Set("本地校验失败：{1}", "Convalida locale non riuscita: {1}")
        catalog.Set("失败发生阶段：{1}", "Fase dell’errore: {1}")
        catalog.Set("必须修复根因并重新满足用户原始目的。", "Correggi la causa principale e soddisfa pienamente l’intento originale dell’utente.")
        catalog.Set("规则块能力不足，必须改用受托管脚本完整实现。", "Un blocco di regole standard non è sufficiente`; usa uno script gestito per l’implementazione completa.")
        catalog.Set("未保存：请先用完整的 AHK v2 脚本替换代码占位文字。", "Non salvato: sostituisci prima il segnaposto con uno script AHK v2 completo.")
        catalog.Set("当前等待时间：{1} 秒", "Current wait time: {1} seconds")
        catalog.Set("界面缩放：", "Ridimensionamento interfaccia:")
        catalog.Set("界面缩放已保存，正在重新加载…", "Il ridimensionamento dell’interfaccia è stato salvato. Ricaricamento…")
        return catalog
    }
}
