; fr-FR 本地化词条目录。
; 简体中文原文是稳定键；本目录与其它语言保持完全相同的键集合。

class FrenchStrings {
    static Create() {
        catalog := Map()
        catalog.CaseSense := "On"
        catalog.Set("按下", "Appuyer")
        catalog.Set(
            "键鼠重映射小助手",
                "Assistant de remappage du clavier et de la souris")
        catalog.Set(
            "新增",
                "Ajouter")
        catalog.Set(
            "新增映射",
                "Ajouter un mappage")
        catalog.Set(
            "删除",
                "Supprimer")
        catalog.Set(
            "暂停",
                "Suspendre")
        catalog.Set(
            "恢复",
                "Reprendre")
        catalog.Set(
            "序号",
                "N°")
        catalog.Set(
            "来源按键",
                "Clé source")
        catalog.Set(
            "映射结果",
                "Résultat mappé")
        catalog.Set(
            "生效范围",
                "Portée")
        catalog.Set(
            "设计目的",
                "Objectif")
        catalog.Set(
            "新建映射",
                "Nouveau mappage")
        catalog.Set(
            "映射为",
                "Mapper vers")
        catalog.Set(
            "点击录制来源按键",
                "Cliquez pour enregistrer les clés source")
        catalog.Set(
            "点击录制目标按键",
                "Cliquez pour enregistrer les clés cibles")
        catalog.Set(
            "保存映射",
                "Enregistrer")
        catalog.Set(
            "清空",
                "Effacer")
        catalog.Set(
            "准备就绪",
                "Prêt")
        catalog.Set(
            "请按下按键 · Esc 取消",
                "Appuyez sur les touches · Echap pour annuler")
        catalog.Set(
            "编辑映射代码",
                "Modifier le code de mappage")
        catalog.Set(
            "新增映射代码",
                "Ajouter du code de mappage")
        catalog.Set(
            "元数据说明",
                "Référence des métadonnées")
        catalog.Set(
            "RuleSpec 外壳版本，当前必须为 2。",
                "Version de l'enveloppe RuleSpec, actuellement obligatoirement 2.")
        catalog.Set(
            "规则模式，当前必须为 managed。",
                "Mode de règle, actuellement obligatoirement managed.")
        catalog.Set(
            "映射的唯一编号，必须与 RuleSpec 的 id 一致。",
                "Identifiant unique du mappage, identique à l'id du RuleSpec.")
        catalog.Set(
            "结构化 RuleSpec JSON 的开始标记。",
                "Marqueur de début du JSON RuleSpec structuré.")
        catalog.Set(
            "注释化 JSON；可编辑来源、条件、显示信息和输出动作。",
                "JSON commenté : modifiez la source, les conditions, l'affichage et les actions de sortie.")
        catalog.Set(
            "结构化 RuleSpec JSON 的结束标记。",
                "Marqueur de fin du JSON RuleSpec structuré.")
        catalog.Set(
            "规范化 RuleSpec JSON 的 SHA-256 摘要。",
                "Empreinte SHA-256 du JSON RuleSpec normalisé.")
        catalog.Set(
            "生成区只含说明注释，不包含可执行 AHK。",
                "La zone générée contient uniquement des commentaires explicatifs, sans AHK exécutable.")
        catalog.Set(
            "整个映射块只允许注释化 RuleSpec JSON；右侧说明仅供参考，不会保存到代码。",
                "Le bloc de mappage entier autorise uniquement du JSON RuleSpec commenté. L'aide à droite est informative et n'est pas enregistrée.")
        catalog.Set(
            "代码修改尚未保存，确定放弃吗？",
                "Le code comporte des modifications non enregistrées. Les jeter ?")
        catalog.Set(
            "放弃修改",
                "Ignorer les modifications")
        catalog.Set(
            "显示主界面",
                "Afficher la fenêtre principale")
        catalog.Set(
            "重新加载",
                "Recharger")
        catalog.Set(
            "以管理员身份重新启动",
                "Redémarrer en tant qu'administrateur")
        catalog.Set(
            "管理员模式（当前）",
                "Mode administrateur (actif)")
        catalog.Set(
            "无法以管理员身份重新启动（错误代码 {1}）。",
                "Impossible de redémarrer en tant qu'administrateur (erreur {1}).")
        catalog.Set(
            "事件查看器",
                "Événements")
        catalog.Set("事件详情", "Détails de l’événement")
        catalog.Set("事件：{1}", "Événement : {1}")
        catalog.Set("类别：{1}", "Catégorie : {1}")
        catalog.Set("时间：{1}", "Heure : {1}")
        catalog.Set("来源：{1}", "Source : {1}")
        catalog.Set("结果：{1}", "Résultat : {1}")
        catalog.Set("详情：{1}", "Détails : {1}")
        catalog.Set("按键名称：{1}", "Nom de la touche : {1}")
        catalog.Set("原始观察", "Observation brute")
        catalog.Set("退出观察", "Arrêter l’observation")
        catalog.Set("原始观察中", "Observation brute active")
        catalog.Set("原始观察切换失败：{1}",
            "Impossible de changer le mode d’observation brute : {1}")
        catalog.Set("诊断包", "Diagnostic")
        catalog.Set("诊断包预览", "Aperçu du paquet de diagnostic")
        catalog.Set("导出诊断包", "Exporter le paquet de diagnostic")
        catalog.Set("诊断包导出失败：{1}",
            "Impossible d’exporter le paquet de diagnostic : {1}")
        catalog.Set("诊断包已导出：{1}", "Paquet de diagnostic exporté : {1}")
        catalog.Set("将导出 {1} 条事件；已脱敏窗口标题 {2}、路径 {3}、文本/命令 {4}、代码 {5}、变量值 {6} 项。是否继续？",
            "Exporter {1} événements ? {2} titres de fenêtre, {3} chemins, {4} valeurs texte/commande, {5} valeurs de code et {6} valeurs de variables ont été masqués.")
        catalog.Set(
            "导入规则包",
                "Package de règles d'importation")
        catalog.Set(
            "导出规则包",
                "Ensemble de règles d'exportation")
        catalog.Set(
            "规则包导出失败：{1}",
                "Échec de l'exportation du package de règles : {1}")
        catalog.Set(
            "已导出 {1} 条规则：{2}",
                "Règles {1} exportées : {2}")
        catalog.Set(
            "规则包导入失败：{1}",
                "Échec de l'importation du package de règles : {1}")
        catalog.Set(
            "规则包导入失败，且回滚失败：{1}",
                "Échec de l'importation et de la restauration du package de règles : {1}")
        catalog.Set(
            "规则包导入完成：新增 {1}，替换 {2}，重命名 {3}，跳过 {4}。",
                "Importation terminée : {1} ajouté, {2} remplacé, {3} renommé, {4} ignoré.")
        catalog.Set("变量", "Variables")
        catalog.Set("变量快照", "Instantané des variables")
        catalog.Set("导入规则包预览", "Aperçu de l'importation du paquet")
        catalog.Set("来源：{1} · 版本：{2}", "Source : {1} · Version : {2}")
        catalog.Set("共 {1} 条规则，默认选中 {2} 条；权限：{3}", "{1} règles, {2} sélectionnées. Autorisations : {3}")
        catalog.Set("规则编号", "ID de règle")
        catalog.Set("模式", "Mode")
        catalog.Set("权限", "Autorisations")
        catalog.Set("全选", "Tout sélectionner")
        catalog.Set("全部取消", "Tout désélectionner")
        catalog.Set("导入所选", "Importer la sélection")
        catalog.Set("无额外权限", "Aucune autorisation supplémentaire")
        catalog.Set("请至少选择一条规则。", "Sélectionnez au moins une règle.")
        catalog.Set("导入失败，请查看主窗口状态。", "Échec de l'importation. Consultez l'état de la fenêtre principale.")
        catalog.Set(
            "筛选：",
                "Filtrer :")
        catalog.Set(
            "全部事件",
                "Tous les événements")
        catalog.Set(
            "输入事件",
                "Entrée")
        catalog.Set(
            "规则运行",
                "Durée d'exécution")
        catalog.Set(
            "规则仓储",
                "Référentiel")
        catalog.Set(
            "撤销历史",
                "Histoire")
        catalog.Set(
            "系统事件",
                "Système")
        catalog.Set(
            "界面事件",
                "Interface utilisateur")
        catalog.Set(
            "暂停刷新",
                "Pause")
        catalog.Set(
            "恢复刷新",
                "Reprendre")
        catalog.Set(
            "导出事件",
                "Exporter des événements")
        catalog.Set(
            "时间",
                "Temps")
        catalog.Set(
            "类别",
                "Catégorie")
        catalog.Set(
            "事件",
                "Événement")
        catalog.Set(
            "来源 / 规则",
                "Source / règle")
        catalog.Set(
            "结果",
                "Résultat")
        catalog.Set(
            "详情",
                "Détails")
        catalog.Set(
            "输入",
                "Entrée")
        catalog.Set(
            "运行时",
                "Durée d'exécution")
        catalog.Set(
            "仓储",
                "Référentiel")
        catalog.Set(
            "历史",
                "Histoire")
        catalog.Set(
            "系统",
                "Système")
        catalog.Set(
            "界面",
                "Interface utilisateur")
        catalog.Set(
            "已暂停刷新",
                "En pause")
        catalog.Set(
            "实时刷新",
                "En direct")
        catalog.Set(
            "显示 {1} 条 · 缓冲区 {2}/{3} · 已丢弃 {4} 条 · {5}",
                "Affichage {1} · tampon {2}/{3} · abandonné {4} · {5}")
        catalog.Set(
            "事件导出失败：{1}",
                "Échec de l'exportation de l'événement : {1}")
        catalog.Set(
            "事件已导出：{1}",
                "Événements exportés : {1}")
        catalog.Set(
            "无法打开事件查看器：{1}",
                "Impossible d'ouvrir l'Observateur d'événements : {1}")
        catalog.Set(
            "退出程序",
                "Quitter le programme")
        catalog.Set(
            "设置",
                "Paramètres")
        catalog.Set(
            "界面语言",
                "Langue")
        catalog.Set(
            "主题",
                "Thème")
        catalog.Set(
            "界面语言：",
                "Langue de l'interface :")
        catalog.Set(
            "界面内容字体：",
                "Police du contenu de l'interface :")
        catalog.Set(
            "主题：",
                "Thème :")
        catalog.Set(
            "跟随系统",
                "Suivre le système")
        catalog.Set(
            "浅色",
                "Clair")
        catalog.Set(
            "深色",
                "Sombre")
        catalog.Set(
            "跟随语言默认（{1}）",
                "Police par défaut de la langue ({1})")
        catalog.Set(
            "保存",
                "Enregistrer")
        catalog.Set(
            "取消",
                "Annuler")
        catalog.Set(
            "已暂停",
                "En pause")
        catalog.Set(
            "已恢复脚本中的自定义顺序。",
                "Restauration de l'ordre des scripts personnalisés.")
        catalog.Set(
            "升序",
                "ascendant")
        catalog.Set(
            "降序",
                "décroissant")
        catalog.Set(
            "已临时按“{1}”{2}排列；不会改写脚本顺序。",
                "Trié temporairement par {1} ({2}) `; l’ordre des scripts est inchangé.")
        catalog.Set(
            "无法恢复自定义顺序：{1}",
                "Impossible de restaurer la commande personnalisée : {1}")
        catalog.Set(
            "映射顺序没有变化。",
                "L'ordre de mappage n'a pas changé.")
        catalog.Set(
            "无法启动按键录制，请重试。",
                "Impossible de démarrer l'enregistrement des touches. Essayer à nouveau.")
        catalog.Set(
            "正在录制来源按键…",
                "Enregistrement des touches source...")
        catalog.Set(
            "正在录制目标按键…",
                "Enregistrement des clés cibles...")
        catalog.Set(
            "来源",
                "source")
        catalog.Set(
            "目标",
                "cible")
        catalog.Set(
            "正在录制{1}按键：{2}",
                "Enregistrement {1} touches : {2}")
        catalog.Set(
            "已录制{1}按键：{2}",
                "Clés {1} enregistrées : {2}")
        catalog.Set(
            "已取消按键录制。",
                "Enregistrement des touches annulé.")
        catalog.Set(
            "请先完成或取消当前按键录制。",
                "Terminez ou annulez d’abord l’enregistrement en cours.")
        catalog.Set(
            "请先录制来源按键和目标按键。",
                "Enregistrez d'abord les clés source et cible.")
        catalog.Set(
            "已清空新建区域。",
                "Nouvelle zone de mappage effacée.")
        catalog.Set(
            "请先选择要删除的映射。",
                "Sélectionnez d’abord un mappage à supprimer.")
        catalog.Set(
            "所选映射缺少代码块编号，无法删除。",
                "Le mappage sélectionné n'a pas d'ID de bloc et ne peut pas être supprimé.")
        catalog.Set(
            "请先选择要暂停或恢复的映射。",
                "Sélectionnez d’abord un mappage à suspendre ou à reprendre.")
        catalog.Set(
            "所选映射缺少代码块编号，无法修改状态。",
                "Le mappage sélectionné n'a pas d'ID de bloc et ne peut pas changer d'état.")
        catalog.Set(
            "无法打开映射代码：{1}",
                "Impossible d'ouvrir le code de mappage : {1}")
        catalog.Set(
            "无法打开代码编辑器：{1}",
                "Impossible d'ouvrir l'éditeur de code : {1}")
        catalog.Set(
            "映射 · {1} -> {2}{3}",
                "Cartographie · {1} -> {2}{3}")
        catalog.Set(
            "全局",
                "Mondial")
        catalog.Set(
            "按键名称：{1}`n虚拟键码：{2}`n扫描码：{3}",
                "Nom de la clé : {1}`nClé virtuelle : {2}`nCode de numérisation : {3}")
        catalog.Set(
            "不适用",
                "n/a")
        catalog.Set(
            "键盘",
                "Clavier")
        catalog.Set(
            "鼠标",
                "Souris")
        catalog.Set(
            "滚轮",
                "Roue")
        catalog.Set(
            "多媒体",
                "Médias")
        catalog.Set(
            "命名键",
                "Clé nommée")
        catalog.Set(
            "左侧 Ctrl",
                "Ctrl gauche")
        catalog.Set(
            "右侧 Ctrl",
                "Ctrl droit")
        catalog.Set(
            "左侧 Shift",
                "Maj gauche")
        catalog.Set(
            "右侧 Shift",
                "Maj droite")
        catalog.Set(
            "左侧 Alt",
                "Alt gauche")
        catalog.Set(
            "右侧 Alt",
                "Alt droite")
        catalog.Set(
            "左侧 Win",
                "Win gauche")
        catalog.Set(
            "右侧 Win",
                "Win droite")
        catalog.Set(
            "读取重映射代码区域失败：{1}",
                "Impossible de lire la zone de mappage : {1}")
        catalog.Set(
            "托管规则未应用：{1}",
                "Les règles gérées n'ont pas été appliquées : {1}")
        catalog.Set(
            "无法检查现有映射：{1}",
                "Impossible d'inspecter les mappages existants : {1}")
        catalog.Set(
            "为避免失去界面操作，来源按键不能是无修饰的鼠标左键。",
                "Un bouton gauche de la souris non modifié ne peut pas être utilisé comme clé source.")
        catalog.Set(
            "该来源按键已被现有映射占用。",
                "Cette clé source est déjà utilisée par un autre mappage.")
        catalog.Set(
            "来源按键与目标按键相同，无需建立映射。",
                "La source et la cible sont identiques ; aucune cartographie n’est nécessaire.")
        catalog.Set(
            "映射未写入脚本：{1}",
                "Le mappage n'a pas été écrit : {1}")
        catalog.Set(
            "已写入脚本：{1} -> {2}；正在自动应用。",
                "Écrit dans le script : {1} -> {2} `; application automatique en cours.")
        catalog.Set(
            "删除映射",
                "Supprimer le mappage")
        catalog.Set(
            "映射未删除：{1}",
                "Le mappage n'a pas été supprimé : {1}")
        catalog.Set(
            "已从脚本删除：{1} -> {2}；正在自动应用。",
                "Supprimé du script : {1} -> {2} `; application automatique en cours.")
        catalog.Set(
            "调整映射顺序",
                "Réorganiser les mappages")
        catalog.Set(
            "顺序未保存：{1}",
                "La commande n'a pas été enregistrée : {1}")
        catalog.Set(
            "已按拖动结果实时更新脚本顺序。",
                "Mise à jour de l'ordre du script à partir du résultat déplacé.")
        catalog.Set(
            "暂停映射",
                "Suspendre le mappage")
        catalog.Set(
            "恢复映射",
                "Reprendre la cartographie")
        catalog.Set(
            "映射状态未修改：{1}",
                "L'état du mappage n'a pas été modifié : {1}")
        catalog.Set(
            "已恢复映射：{1} -> {2}；正在自动应用。",
                "Mappage repris : {1} -> {2} `; application automatique en cours.")
        catalog.Set(
            "已暂停映射：{1} -> {2}；正在自动应用。",
                "Mappage suspendu : {1} -> {2} `; application automatique en cours.")
        catalog.Set(
            "映射代码未保存：{1}",
                "Le code de mappage n'a pas été enregistré : {1}")
        catalog.Set(
            "映射代码未新增：{1}",
                "Le code de mappage n'a pas été ajouté : {1}")
        catalog.Set(
            "未保存：{1}",
                "Non enregistré : {1}")
        catalog.Set(
            "已保存映射代码：{1} -> {2}；正在自动应用。",
                "Code de mappage enregistré : {1} -> {2} `; application automatique en cours.")
        catalog.Set(
            "已新增映射代码：{1} -> {2}；正在自动应用。",
                "Code de mappage ajouté : {1} -> {2} `; application automatique en cours.")
        catalog.Set(
            "无法创建空白映射代码：{1}",
                "Impossible de créer un code de mappage vide : {1}")
        catalog.Set(
            "无法打开设置：{1}",
                "Impossible d'ouvrir les paramètres : {1}")
        catalog.Set(
            "设置未保存：{1}",
                "Les paramètres n'ont pas été enregistrés : {1}")
        catalog.Set(
            "界面内容字体",
                "Police de l'interface utilisateur")
        catalog.Set(
            "撤销失败：{1}",
                "Échec de l'annulation : {1}")
        catalog.Set(
            "重做失败：{1}",
                "Échec de la restauration : {1}")
        catalog.Set(
            "已撤销：{1}",
                "Annulé : {1}")
        catalog.Set(
            "已重做：{1}",
                "Rétabli : {1}")
        catalog.Set(
            "映射配置",
                "Configuration du mappage")
        catalog.Set(
            "{1} 条重映射正在生效 · 当前为脚本代码顺序",
                "{1} mappages actifs · ordre des scripts personnalisés")
        catalog.Set("键鼠重映射小助手设置",
            "Paramètres de l'assistant de remappage du clavier et de la souris")
        catalog.Set("通用",
            "Général")
        catalog.Set("关于",
            "À propos")
        catalog.Set("启动时显示主窗口",
            "Afficher la fenêtre principale au démarrage")
        catalog.Set("单独按 Esc 时取消录制",
            "Appuyer uniquement sur Échap pour annuler l’enregistrement")
        catalog.Set("事件缓冲区容量（条）：",
            "Capacité du tampon d’événements :")
        catalog.Set("事件查看器自动跟随最新事件",
            "Suivre automatiquement les événements les plus récents")
        catalog.Set("让每一条键鼠映射都可录制、可审阅、可掌控",
            "Enregistrer, examiner et maîtriser chaque remappage du clavier et de la souris")
        catalog.Set("当前版本",
            "Version actuelle")
        catalog.Set("运行环境",
            "Environnement d’exécution")
        catalog.Set("查看最新版本",
            "Voir la dernière version")
        catalog.Set("开源地址",
            "Dépôt open source")
        catalog.Set("“{1}”必须是 {2} 到 {3} 之间的整数。",
            "« {1} » doit être un entier compris entre {2} et {3}.")
        catalog.Set("事件缓冲区容量",
            "Capacité du tampon d’événements")
        catalog.Set("未知版本",
            "Version inconnue")
        catalog.Set("{1}（EXE 版）",
            "{1} (version EXE)")
        catalog.Set("{1}（源码版）",
            "{1} (version source)")
        catalog.Set("设置没有变化。",
            "Aucun paramètre n’a changé.")
        catalog.Set("设置已保存并已应用。",
            "Paramètres enregistrés et appliqués.")
        catalog.Set("设置",
            "Paramètres")
        catalog.Set("Esc 取消录制",
            "Échap annule l’enregistrement")
        catalog.Set("事件自动跟随",
            "Suivi des événements récents")
        catalog.Set("录制", "Enregistrement")
        catalog.Set("事件", "Événements")
        catalog.Set("{1}（便携版）", "{1} (version portable)")
        catalog.Set("帮助信息", "Aide")
        catalog.Set("捐赠", "Faire un don")
        catalog.Set("使用说明", "Guide d'utilisation")
        catalog.Set("提交反馈", "Envoyer un commentaire")
        catalog.Set("支持开源项目", "Soutenir le projet open source")
        catalog.Set("微信支付", "WeChat Pay")
        catalog.Set("支付宝", "Alipay")
        catalog.Set("二维码图片未找到", "Image du code QR introuvable")
        catalog.Set("如果这个项目为您带来了帮助，欢迎通过下方二维码支持作者！`n键鼠重映射小助手将持续保持开源，项目的长期维护有赖于您的支持和鼓励。", "Si ce projet vous a été utile, vous pouvez soutenir son auteur à l'aide des codes QR ci-dessous.`nL'assistant de remappage du clavier et de la souris restera open source, et votre soutien contribue à sa maintenance à long terme.")
        catalog.Set("无法打开帮助信息：{1}", "Impossible d'ouvrir l'aide : {1}")
        catalog.Set("无法打开使用说明：{1}", "Impossible d'ouvrir le guide d'utilisation : {1}")
        catalog.Set("无法打开捐赠窗口：{1}", "Impossible d'ouvrir la fenêtre de don : {1}")
        catalog.Set("无法打开反馈页面：{1}", "Impossible d'ouvrir la page de commentaires : {1}")
        catalog.Set("键鼠重映射小助手用于录制、审阅和维护键盘与鼠标映射。关闭主窗口只会隐藏到系统托盘，已经启用的映射仍会继续生效。", "L'assistant de remappage du clavier et de la souris permet d'enregistrer, de vérifier et de gérer les remappages du clavier et de la souris. Fermer la fenêtre principale le masque seulement dans la zone de notification, tandis que les remappages activés restent opérationnels.")
        catalog.Set("一、快速上手", "1. Démarrage rapide")
        catalog.Set("• 点击顶部“新增”，会打开已经填好元数据字段的 @mapping 编辑器；也可以在下方分别录制来源按键和目标按键，填写设计目的后保存。", "• Cliquez sur Ajouter dans la barre supérieure pour ouvrir un éditeur @mapping dont les champs de métadonnées sont prêts. Vous pouvez aussi enregistrer séparément la source et la cible ci-dessous, indiquer l'objectif, puis enregistrer.")
        catalog.Set("• 录制会实时显示原始规范名称、阅读友好名称、虚拟键码和扫描码，并区分左右 Ctrl、Shift、Alt、Win 以及键盘、鼠标和滚轮输入。", "• L'enregistrement affiche en temps réel le nom canonique, le nom lisible, le code de touche virtuelle et le code d'analyse. Il distingue les touches Ctrl, Maj, Alt et Win gauche et droite, ainsi que le clavier, la souris et la molette.")
        catalog.Set("• 同时按下的任意按键会组成一次录制；所有按键释放后结束。录制期间再次点击录制按钮会取消本次录制，不会把该次点击记为 LButton。", "• Toutes les touches maintenues simultanément forment un enregistrement, qui se termine lorsqu'elles sont toutes relâchées. Cliquer de nouveau sur le bouton d'enregistrement annule l'opération au lieu d'enregistrer ce clic comme LButton.")
        catalog.Set("二、主界面与代码编辑", "2. Fenêtre principale et édition du code")
        catalog.Set("• 单击选择映射；双击条目、悬停时按 F2 或使用右键菜单，可编辑完整 @mapping 代码块。", "• Cliquez une fois pour sélectionner un remappage. Double-cliquez sur une ligne, appuyez sur F2 en la survolant ou utilisez le menu contextuel pour modifier le bloc @mapping complet.")
        catalog.Set("• 选中条目后可暂停、恢复或删除；直接拖动列表行可调整永久顺序，脚本中的代码块顺序会实时同步。", "• Un remappage sélectionné peut être suspendu, repris ou supprimé. Faites glisser les lignes pour modifier l'ordre permanent, et l'ordre des blocs du script est synchronisé immédiatement.")
        catalog.Set("• 点击伪表头只进行临时排序；字段按升序、降序、自定义顺序循环，序号列按降序、自定义顺序循环，不会改写脚本。", "• Le tri des pseudo-en-têtes est temporaire. Les champs alternent entre ordre croissant, décroissant et personnalisé, tandis que la colonne de numéro alterne entre ordre décroissant et personnalisé. Le script n'est pas réécrit.")
        catalog.Set("• 映射区域只保存注释化 RuleSpec v2，是映射的唯一持久来源。GUI 创建或编辑的托管规则会直接热应用；可执行 AHK 代码不会被接受。", "• La zone de mappage ne stocke que des RuleSpec v2 commentées et constitue l'unique source persistante. Les règles gérées créées ou modifiées dans l'interface sont appliquées à chaud. Le code AHK exécutable est refusé.")
        catalog.Set("四、事件、历史与界面设置", "4. Événements, historique et apparence")
        catalog.Set("• 事件查看器记录输入、规则匹配、条件拒绝、执行结果、仓储和系统事件，支持筛选、暂停、清空及 JSONL 导出。", "• L'observateur d'événements enregistre les entrées, les correspondances de règles, les rejets de conditions, les résultats d'exécution, l'activité du dépôt et les événements système. Il permet de filtrer, suspendre, effacer et exporter en JSONL.")
        catalog.Set("五、后台运行与问题排查", "5. Exécution en arrière-plan et dépannage")
        catalog.Set("• 主窗口关闭后程序仍驻留托盘。托盘可以重新显示主界面、手动重新加载或彻底退出；修改映射规则后通常不需要手动重新加载。", "• L'application reste dans la zone de notification après la fermeture de la fenêtre principale. Celle-ci permet de réafficher la fenêtre, de recharger manuellement ou de quitter complètement, et les changements de règles ne nécessitent normalement pas de rechargement manuel.")
        catalog.Set("• 映射对管理员程序无效时，请从托盘选择以管理员身份重新启动。遇到规则冲突或按键未按预期执行时，先在事件查看器中核对输入和规则结果。", "• Si un remappage n'agit pas sur une application élevée, redémarrez cette application en tant qu'administrateur depuis la zone de notification. En cas de conflit ou de comportement inattendu, vérifiez d'abord les entrées et les résultats des règles dans l'observateur d'événements.")
        catalog.Set("• “帮助信息”还可打开项目反馈页面。提交问题时请说明系统版本、复现步骤、相关 @mapping 代码和事件导出，并在公开前移除敏感路径或应用信息。", "• L'aide ouvre également la page de commentaires du projet. Pour signaler un problème, indiquez la version de Windows, les étapes de reproduction, le code @mapping concerné et un export d'événements, puis retirez les chemins ou informations d'application sensibles avant publication.")
        catalog.Set("安全模式：已停用所有映射和输入观察。连续启动失败 {1} 次。", "Mode sans échec : tous les remappages et l'observation des entrées sont désactivés après {1} échecs de démarrage consécutifs.")
        catalog.Set("恢复最后正常配置", "Restaurer la dernière configuration valide")
        catalog.Set("没有可恢复的最后正常配置。", "Aucune dernière configuration valide n'est disponible.")
        catalog.Set("最后正常配置恢复失败：{1}", "Échec de la restauration de la dernière configuration valide : {1}")
        catalog.Set("最后正常配置已恢复，正在自动应用。", "La dernière configuration valide a été restaurée et est appliquée automatiquement.")
        catalog.Set("仅勾选的规则会被导入。", "Seules les règles sélectionnées seront importées.")
        catalog.Set("三、规则与生效范围", "3. Règles et portée")
        catalog.Set("• 所有规则属于同一全局规则集；生效范围和条件可在 @mapping 编辑器中精确调整，保存后会立即重新选择生效规则。", "• Toutes les règles appartiennent à un seul ensemble global. La portée et les conditions peuvent être réglées précisément dans l'éditeur @mapping. L'enregistrement resélectionne immédiatement les règles actives.")
        catalog.Set("• Ctrl+Z 撤销，Ctrl+Shift+Z 或 Ctrl+Y 重做。映射增删、暂停恢复、拖动排序、代码编辑和设置修改都会进入持久历史。", "• Ctrl+Z annule. Ctrl+Shift+Z ou Ctrl+Y rétablit. Les ajouts, suppressions, pauses, reprises, réordonnancements, modifications de code et réglages sont conservés dans l'historique persistant.")
        return catalog
    }
}
