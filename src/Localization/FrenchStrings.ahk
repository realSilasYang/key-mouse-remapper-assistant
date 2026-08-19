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
            "删除",
                "Supprimer")
        catalog.Set(
            "暂停",
                "Suspendre")
        catalog.Set(
            "恢复",
                "Reprendre")
        catalog.Set("反转状态", "Inverser l'état")
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
            "名称",
                "Nom")
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
        catalog.Set("规则块", "Règle standard")
        catalog.Set("受托管脚本", "Script géré")
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
            "事件查看",
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
            "规则包导入完成：新增 {1}，替换 {2}，重命名 {3}，跳过 {4}。",
                "Importation terminée : {1} ajouté, {2} remplacé, {3} renommé, {4} ignoré.")
        catalog.Set("导入规则包预览", "Aperçu de l'importation du paquet")
        catalog.Set("来源：{1} · 版本：{2}", "Source : {1} · Version : {2}")
        catalog.Set("共 {1} 条规则，默认选中 {2} 条；权限：{3}", "{1} règles, {2} sélectionnées. Autorisations : {3}")
        catalog.Set("模式", "Mode")
        catalog.Set("权限", "Autorisations")
        catalog.Set("全选", "Tout sélectionner")
        catalog.Set("全部取消", "Tout désélectionner")
        catalog.Set("导入所选", "Importer la sélection")
        catalog.Set("无额外权限", "Aucune autorisation supplémentaire")
        catalog.Set("生成键鼠输入", "Générer des entrées clavier et souris")
        catalog.Set("控制活动窗口", "Contrôler la fenêtre active")
        catalog.Set("执行系统控制", "Exécuter une commande système")
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
            "系统事件",
                "Système")
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
            "退出程序",
                "Quitter le programme")
        catalog.Set(
            "设置",
                "Paramètres")
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
        catalog.Set("无法启动按键录制：{1}", "Impossible de démarrer l'enregistrement des touches : {1}")
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
            "所选映射缺少名称，无法删除。",
                "Le mappage sélectionné n'a pas de nom et ne peut pas être supprimé.")
        catalog.Set(
            "请先选择要暂停或恢复的映射。",
                "Sélectionnez d’abord un mappage à suspendre ou à reprendre.")
        catalog.Set(
            "所选映射缺少名称，无法修改状态。",
                "Le mappage sélectionné n'a pas de nom et ne peut pas changer d'état.")
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
            "为避免失去界面操作，来源按键不能是无修饰的鼠标左键。",
                "Un bouton gauche de la souris non modifié ne peut pas être utilisé comme clé source.")
        catalog.Set(
            "映射未写入脚本：{1}",
                "Le mappage n'a pas été écrit : {1}")
        catalog.Set(
            "已写入脚本：{1} -> {2}；已应用。",
                "Écrit dans le script : {1} -> {2} `; appliqué.")
        catalog.Set(
            "映射未删除：{1}",
                "Le mappage n'a pas été supprimé : {1}")
        catalog.Set(
            "已从脚本删除：{1} -> {2}；已应用。",
                "Supprimé du script : {1} -> {2} `; appliqué.")
        catalog.Set(
            "顺序未保存：{1}",
                "La commande n'a pas été enregistrée : {1}")
        catalog.Set(
            "已按拖动结果实时更新脚本顺序。",
                "Mise à jour de l'ordre du script à partir du résultat déplacé.")
        catalog.Set(
            "映射状态未修改：{1}",
                "L'état du mappage n'a pas été modifié : {1}")
        catalog.Set(
            "已恢复映射：{1} -> {2}；已应用。",
                "Mappage repris : {1} -> {2} `; appliqué.")
        catalog.Set(
            "已暂停映射：{1} -> {2}；已应用。",
                "Mappage suspendu : {1} -> {2} `; appliqué.")
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
            "已保存映射代码：{1} -> {2}；已应用。",
                "Code de mappage enregistré : {1} -> {2} `; appliqué.")
        catalog.Set(
            "已新增映射代码：{1} -> {2}；已应用。",
                "Code de mappage ajouté : {1} -> {2} `; appliqué.")
        catalog.Set("已保存，正在后台应用…",
            "Enregistré `; application en arrière-plan...")
        catalog.Set("受托管脚本已应用。", "Script géré appliqué.")
        catalog.Set("映射代码没有变化。", "Le code de mappage n'a pas changé.")
        catalog.Set("映射代码已保存，但受托管脚本应用失败：{1}",
            "Le code de mappage a été enregistré, mais le script géré n'a pas pu être appliqué : {1}")
        catalog.Set(
            "无法创建空白映射代码：{1}",
                "Impossible de créer un code de mappage vide : {1}")
        catalog.Set(
            "设置未保存：{1}",
                "Les paramètres n'ont pas été enregistrés : {1}")
        catalog.Set(
            "{1} 条重映射正在生效 · 当前为脚本代码顺序",
                "{1} mappages actifs · ordre des scripts personnalisés")
        catalog.Set("键鼠重映射小助手设置",
            "Paramètres de l'assistant de remappage du clavier et de la souris")
        catalog.Set("启动",
            "Démarrage")
        catalog.Set("显示",
            "Affichage")
        catalog.Set("规则与事件",
            "Règles et événements")
        catalog.Set("关于",
            "À propos")
        catalog.Set("事件缓冲区容量（条）：",
            "Capacité du tampon d’événements :")
        catalog.Set("事件查看自动跟随最新事件",
            "Suivre automatiquement les événements les plus récents")
        catalog.Set("让每一条键鼠映射都可录制、可审阅、可掌控",
            "Enregistrer, examiner et maîtriser chaque remappage du clavier et de la souris")
        catalog.Set("当前版本",
            "Version actuelle")
        catalog.Set("运行环境",
            "Environnement d’exécution")
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
        catalog.Set("设置已保存并已应用。",
            "Paramètres enregistrés et appliqués.")
        catalog.Set("Esc 取消录制",
            "Échap annule l’enregistrement")
        catalog.Set("{1}（便携版）", "{1} (version portable)")
        catalog.Set("快揭不开锅了（≥Д≤）",
            "La caisse est presque vide（≥Д≤）")
        catalog.Set("使用说明", "Guide d'utilisation")
        catalog.Set("提交反馈", "Envoyer un commentaire")
        catalog.Set("支持开源项目", "Soutenir le projet open source")
        catalog.Set("微信支付", "WeChat Pay")
        catalog.Set("支付宝", "Alipay")
        catalog.Set("二维码图片未找到", "Image du code QR introuvable")
        catalog.Set("如果小助手为您节省了配置键鼠映射的时间，欢迎通过下方二维码打赏作者！`n请选择扶贫方式（≥Д≤）", "Si l’assistant vous a fait gagner du temps dans la configuration des mappages clavier-souris, n’hésitez pas à soutenir l’auteur à l’aide des codes QR ci-dessous !`nChoisissez votre façon de contribuer (≥Д≤)")
        catalog.Set("无法打开反馈页面：{1}", "Impossible d'ouvrir la page de commentaires : {1}")
        catalog.Set("键鼠重映射小助手用于录制、审阅和维护键盘与鼠标映射。关闭主窗口只会隐藏到系统托盘，已经启用的映射仍会继续生效。", "L'assistant de remappage du clavier et de la souris permet d'enregistrer, de vérifier et de gérer les remappages du clavier et de la souris. Fermer la fenêtre principale le masque seulement dans la zone de notification, tandis que les remappages activés restent opérationnels.")
        catalog.Set("一、快速上手", "1. Démarrage rapide")
        catalog.Set("• 点击顶部“新增”，会打开已经填好元数据字段的 @mapping 编辑器；也可以在下方分别录制来源按键和目标按键，填写名称后保存。", "• Cliquez sur Ajouter dans la barre supérieure pour ouvrir un éditeur @mapping dont les champs de métadonnées sont prêts. Vous pouvez aussi enregistrer séparément la source et la cible ci-dessous, saisir un nom, puis enregistrer.")
        catalog.Set("• 录制会实时显示原始规范名称、阅读友好名称、虚拟键码和扫描码，并区分左右 Ctrl、Shift、Alt、Win 以及键盘、鼠标和滚轮输入。", "• L'enregistrement affiche en temps réel le nom canonique, le nom lisible, le code de touche virtuelle et le code d'analyse. Il distingue les touches Ctrl, Maj, Alt et Win gauche et droite, ainsi que le clavier, la souris et la molette.")
        catalog.Set("二、主界面与代码编辑", "2. Fenêtre principale et édition du code")
        catalog.Set("• 单击选择映射；双击条目、选中后按 F2 或使用右键菜单，可编辑完整 @mapping 代码块。", "• Cliquez une fois pour sélectionner un remappage. Double-cliquez sur une ligne, appuyez sur F2 après l’avoir sélectionnée ou utilisez le menu contextuel pour modifier le bloc @mapping complet.")
        catalog.Set("• 选中条目后可暂停、恢复或删除；直接拖动列表行可调整永久顺序，脚本中的代码块顺序会实时同步。", "• Un remappage sélectionné peut être suspendu, repris ou supprimé. Faites glisser les lignes pour modifier l'ordre permanent, et l'ordre des blocs du script est synchronisé immédiatement.")
        catalog.Set("• 点击伪表头只进行临时排序；字段按升序、降序、自定义顺序循环，序号列按降序、自定义顺序循环，不会改写脚本。", "• Le tri des pseudo-en-têtes est temporaire. Les champs alternent entre ordre croissant, décroissant et personnalisé, tandis que la colonne de numéro alterne entre ordre décroissant et personnalisé. Le script n'est pas réécrit.")
        catalog.Set("• 事件查看记录输入、规则匹配、条件拒绝、执行结果、仓储和系统事件，支持筛选、暂停、清空及 JSONL 导出。", "• L'observateur d'événements enregistre les entrées, les correspondances de règles, les rejets de conditions, les résultats d'exécution, l'activité du dépôt et les événements système. Il permet de filtrer, suspendre, effacer et exporter en JSONL.")
        catalog.Set("四、事件查看与设置", "4. Visionneuse d’événements et paramètres")
        catalog.Set("五、后台运行与问题排查", "5. Exécution en arrière-plan et dépannage")
        catalog.Set("• 主窗口关闭后程序仍驻留托盘。托盘可以重新显示主界面、手动重新加载或彻底退出；修改映射规则后通常不需要手动重新加载。", "• L'application reste dans la zone de notification après la fermeture de la fenêtre principale. Celle-ci permet de réafficher la fenêtre, de recharger manuellement ou de quitter complètement, et les changements de règles ne nécessitent normalement pas de rechargement manuel.")
        catalog.Set("仅勾选的规则会被导入。", "Seules les règles sélectionnées seront importées.")
        catalog.Set("三、规则与生效范围", "3. Règles et portée")
        catalog.Set("• 所有规则属于同一全局规则集；生效范围和条件可在 @mapping 编辑器中精确调整，保存后会立即重新选择生效规则。", "• Toutes les règles appartiennent à un seul ensemble global. La portée et les conditions peuvent être réglées précisément dans l'éditeur @mapping. L'enregistrement resélectionne immédiatement les règles actives.")
        catalog.Set("没有可撤销的映射变更。", "Aucune modification de mappage à annuler.")
        catalog.Set("已撤销上一步映射变更。", "La dernière modification de mappage a été annulée.")
        catalog.Set("撤销映射变更失败：{1}", "Impossible d’annuler la modification de mappage : {1}")
        catalog.Set("没有可重做的映射变更。", "Aucune modification de mappage à rétablir.")
        catalog.Set("已重做映射变更。", "La modification de mappage a été rétablie.")
        catalog.Set("重做映射变更失败：{1}", "Impossible de rétablir la modification de mappage : {1}")
        catalog.Set("录制结束后无法恢复重映射：{1}", "Impossible de reprendre le remappage après l’enregistrement : {1}")
        catalog.Set("• 新增、删除、暂停或恢复、代码编辑、拖动排序和规则包导入均可撤销；Ctrl+Z 撤销，Ctrl+Shift+Z 或 Ctrl+Y 重做。", "• L’ajout, la suppression, la pause ou la reprise, la modification du code, le réordonnancement par glisser-déposer et l’importation de paquets de règles peuvent tous être annulés. Utilisez Ctrl+Z pour annuler et Ctrl+Maj+Z ou Ctrl+Y pour rétablir.")
        catalog.Set("操作计划任务时发生错误：{1}", "Une erreur s’est produite lors de l’utilisation de la tâche planifiée : {1}")
        catalog.Set("开机自动启动（计划任务）", "Démarrage automatique à l'ouverture de session（tâche planifiée）")
        catalog.Set("检查更新失败：{1}", "Échec de la recherche des mises à jour : {1}")
        catalog.Set("启动时显示主窗口", "Afficher la fenêtre principale au démarrage")
        catalog.Set("更新检查正在进行，请稍候。", "Une recherche de mises à jour est déjà en cours. Veuillez patienter.")
        catalog.Set("关闭", "Désactiver")
        catalog.Set("将下载并校验源码发行包，保留个人配置后替换源码并自动重启。", "L'archive du code source sera téléchargée et vérifiée. Le code sera ensuite remplacé et l'assistant redémarrera automatiquement, tout en conservant votre configuration personnelle.")
        catalog.Set("桌面与开始菜单快捷方式", "Raccourcis du bureau et du menu Démarrer")
        catalog.Set("创建", "Créer")
        catalog.Set("无法检查更新：{1}", "Impossible de rechercher les mises à jour : {1}")
        catalog.Set("提示", "Information")
        catalog.Set("检测到同名计划任务，但它并非当前程序创建；为避免误删，请先在任务计划程序中处理它。", "Une tâche planifiée portant le même nom a été détectée, mais elle n'a pas été créée par ce programme. Afin d'éviter de la supprimer par erreur, gérez-la d'abord dans le Planificateur de tâches.")
        catalog.Set("立即更新", "Mettre à jour maintenant")
        catalog.Set("错误", "Erreur")
        catalog.Set("创建成功！", "Créés !")
        catalog.Set("无法建立单实例运行锁，小助手将退出。", "Impossible d'obtenir le verrou d'instance unique `; l'assistant va quitter.")
        catalog.Set("重新加载失败，已保留当前实例：{1}", "Échec du rechargement `; l'instance actuelle a été conservée : {1}")
        catalog.Set("稍后", "Plus tard")
        catalog.Set("切换", "Basculer")
        catalog.Set("冲突", "Conflit")
        catalog.Set("将确认源码仓库没有未提交修改，再快速前进到正式发布标签并自动重启。", "L'absence de modifications non validées dans le dépôt source sera vérifiée, puis le dépôt avancera directement jusqu'à l'étiquette de publication officielle avant le redémarrage automatique.")
        catalog.Set("无法开始更新：{1}", "Impossible de démarrer la mise à jour : {1}")
        catalog.Set("正在检查更新…", "Recherche de mises à jour…")
        catalog.Set("检查更新", "Rechercher les mises à jour")
        catalog.Set("小助手更新", "Mise à jour de l'assistant")
        catalog.Set("将下载并校验完整发行包，退出小助手后替换程序文件并自动重启。", "Le paquet de distribution complet sera téléchargé et vérifié. Une fois l'assistant fermé, les fichiers du programme seront remplacés et l'assistant redémarrera automatiquement.")
        catalog.Set("创建快捷方式失败：{1}", "Échec de la création du raccourci : {1}")
        catalog.Set("当前陪伴您的已经是最新版本的小助手啦！", "L'assistant qui vous accompagne est déjà à jour !")
        catalog.Set("确定", "OK")
        catalog.Set("没有可安装的应用更新", "Aucune mise à jour d'application ne peut être installée")
        catalog.Set("更新检查未返回结果", "La recherche des mises à jour n'a renvoyé aucun résultat")
        catalog.Set("开启", "Activer")
        catalog.Set("不可用", "Indisponible")
        catalog.Set("启动失败", "Échec du démarrage")
        catalog.Set("启动时检查小助手更新", "Rechercher les mises à jour de l'assistant au démarrage")
        catalog.Set("以管理员身份运行", "Exécuter en tant qu’administrateur")
        catalog.Set("发现新版本 {1}，当前版本为 {2}。`n`n{3}`n`n是否立即更新？", "Une nouvelle version {1} est disponible. La version actuelle est {2}.`n`n{3}`n`nMettre à jour maintenant ?")
        catalog.Set("开机自动启动", "Démarrage automatique à l’ouverture de session")
        catalog.Set("输入录制不可用：{1}", "L’enregistrement des entrées n’est pas disponible : {1}")
        catalog.Set("新脚本未通过 AutoHotkey 启动验证。", "Le nouveau script n’a pas réussi la vérification de démarrage AutoHotkey.")
        catalog.Set("保存并运行", "Enregistrer et exécuter")
        catalog.Set("导入并运行", "Importer et exécuter")
        catalog.Set("导入自定义 AHK 代码", "Importer du code AHK personnalisé")
        catalog.Set("继续", "Continuer")
        catalog.Set("切换规则类型", "Changer le type de règle")
        catalog.Set("切换规则类型会清空当前未保存内容，是否继续？", "Changer le type de règle effacera le contenu non enregistré. Continuer ?")
        catalog.Set("所选规则包含可读写文件、启动程序、控制窗口和请求管理员权限的自定义 AHK 代码。确认导入并运行吗？", "Les règles sélectionnées contiennent du code AHK personnalisé capable de lire et écrire des fichiers, lancer des programmes, contrôler des fenêtres et demander des privilèges administrateur. Importer et exécuter ?")
        catalog.Set("无法创建规则模板：{1}", "Impossible de créer le modèle de règle : {1}")
        catalog.Set("运行自定义 AHK 代码", "Exécuter du code AHK personnalisé")
        catalog.Set("自定义 AHK 代码可读取文件、启动程序、控制窗口并请求管理员权限。确认运行当前代码吗？", "Le code AHK personnalisé peut lire et écrire des fichiers, lancer des programmes, contrôler des fenêtres et demander des privilèges administrateur. Exécuter ce code ?")
        catalog.Set("规则未应用：{1}", "Les règles n’ont pas été appliquées : {1}")
        catalog.Set("• 映射区域以注释形式保存规则块和受托管脚本。规则块在主进程热应用；受托管脚本的自定义 AHK v2 源码在独立受管进程运行，保存、暂停、恢复、删除和退出均由小助手统一管理。", "• La zone de mappage stocke les blocs de règle standard et les scripts gérés sous forme de commentaires. Les premiers sont appliqués à chaud dans le processus principal. Le code AutoHotkey v2 personnalisé s’exécute dans un processus géré indépendant contrôlé par l’assistant.")
        catalog.Set("区分左右修饰键", "Distinguer les modificateurs gauche/droite")
        catalog.Set("帮助", "Aide")
        catalog.Set("打赏", "Donner")
        catalog.Set("打开帮助`n可选择查看使用说明、运行日志或提交反馈", "Ouvrir l’aide`nChoisissez le guide d’utilisation, le journal d’exécution ou l’envoi d’un commentaire")
        catalog.Set("点个 star 吧~", "Offrez-nous une petite étoile~")
        catalog.Set("配置显示、规则包和事件选项", "Configurer l’affichage, les paquets de règles et les événements")
        catalog.Set("查看版本、运行环境和项目入口", "Voir la version, environnement et liens du projet")
        catalog.Set("找作者对线", "Contacter auteur")
        catalog.Set("演奏你的和弦！", "Jouez votre accord !")
        catalog.Set("• “帮助”还可打开项目反馈页面。提交问题时请说明系统版本、复现步骤、相关 @mapping 代码和事件导出，并在公开前移除敏感路径或应用信息。", "• L'aide ouvre également la page de commentaires du projet. Pour signaler un problème, indiquez la version de Windows, les étapes de reproduction, le code @mapping concerné et un export d'événements, puis retirez les chemins ou informations d'application sensibles avant publication.")
        catalog.Set("AI 设置", "AI settings")
        catalog.Set("API 地址：", "Adresse API :")
        catalog.Set("API 密钥：", "Clé API :")
        catalog.Set("模型名称：", "Nom du modèle :")
        catalog.Set("请求超时（秒）：", "Request timeout (seconds):")
        catalog.Set("请求超时（秒）", "Request timeout (seconds)")
        catalog.Set("提示词：", "Invites :")
        catalog.Set("生成", "Générer")
        catalog.Set("优化", "Optimiser")
        catalog.Set("系统说明", "Instructions système")
        catalog.Set("编辑", "Edit")
        catalog.Set("AI 提示词", "AI prompts")
        catalog.Set("生成提示词不能为空。", "Generation prompt cannot be empty.")
        catalog.Set("优化提示词不能为空。", "Optimization prompt cannot be empty.")
        catalog.Set("恢复默认", "Restore default")
        catalog.Set("系统说明不能为空。", "System instructions cannot be empty.")
        catalog.Set("生成重映射规则", "Generate remapping rule")
        catalog.Set("优化当前规则", "Optimize current rule")
        catalog.Set("AI 生成规则", "IA Générer règle")
        catalog.Set("设置序号圆点", "Définir le point du numéro")
        catalog.Set("清除圆点颜色", "Effacer la couleur du point")
        catalog.Set("雾松绿", "Vert pin brumeux")
        catalog.Set("青灰蓝", "Bleu-gris")
        catalog.Set("薰衣草紫", "Lavande")
        catalog.Set("烟粉", "Rose poudré")
        catalog.Set("浅琥珀", "Ambre clair")
        catalog.Set("静谧青", "Bleu sarcelle doux")
        catalog.Set("珍珠灰", "Gris perle")
        catalog.Set("已更新 {1} 条规则的序号圆点颜色。", "Couleur du point mise à jour pour {1} règles.")
        catalog.Set("序号圆点颜色未保存：{1}", "La couleur du point n'a pas été enregistrée : {1}")
        catalog.Set("AI 优化规则", "IA Optimiser règle")
        catalog.Set("请输入规则目的。", "Indiquez l’objectif de la règle.")
        catalog.Set("说点什么吧，我什么都会做的 T_T", "Dites tout ce que vous voulez, je sais tout faire T_T")
        catalog.Set("我是来帮你的，你要干什么？！", "Je suis là pour vous aider. Que voulez-vous faire ?!")
        catalog.Set("请先关闭当前代码编辑器，再优化其他映射。", "Fermez l’éditeur de code actuel avant d’optimiser un autre mappage.")
        catalog.Set("AI 服务尚未初始化。", "The AI service is not initialized.")
        catalog.Set("无法读取当前映射代码：{1}", "Could not read the current mapping code: {1}")
        catalog.Set("AI 正在生成规则，请稍候...", "AI is generating a rule. Please wait...")
        catalog.Set("AI 正在优化规则，请稍候...", "L'IA optimise la règle. Veuillez patienter...")
        catalog.Set("AI 请求失败，请检查 AI 设置和网络连接。", "Échec de la requête IA. Vérifiez les paramètres IA et la connexion réseau.")
        catalog.Set("测试连接", "Tester la connexion")
        catalog.Set("正在测试 AI 连接…", "Test de la connexion à l’IA…")
        catalog.Set("AI 连接测试成功。", "Test de connexion à l’IA réussi.")
        catalog.Set("AI 连接测试失败：{1}", "Échec du test de connexion à l’IA : {1}")
        catalog.Set("请填写 API 地址。", "Saisissez l’adresse API.")
        catalog.Set("请填写模型名称。", "Saisissez le nom du modèle.")
        catalog.Set("请求期间编辑器内容已变化，请重新执行 AI 操作。", "The editor changed during the request. Run the AI operation again.")
        catalog.Set("AI 规则已放入编辑器，请检查后保存。", "The AI rule is in the editor. Review it before saving.")
        catalog.Set("状态", "État")
        catalog.Set("启用", "Activé")
        catalog.Set("无法读取设置文件，已使用默认设置：{1}", "Les paramètres n’ont pas pu être lus `; les valeurs par défaut sont utilisées : {1}")
        catalog.Set("审阅 AI 优化结果", "Vérifier l’optimisation de l’IA")
        catalog.Set("已保留原内容，AI 结果未应用。", "Le contenu d’origine a été conservé. Le résultat de l’IA n’a pas été appliqué.")
        catalog.Set("AI 结果无法应用到编辑器，请重试。", "Le résultat de l’IA n’a pas pu être appliqué à l’éditeur. Réessayez.")
        catalog.Set("无法打开 AI 结果审阅：{1}", "Impossible d’ouvrir la vérification du résultat de l’IA : {1}")
        catalog.Set("当前 {1} 行，AI 建议 {2} 行；约 {3} 行有变化。", "Actuel : {1} lignes `; suggestion IA : {2} lignes `; environ {3} lignes modifiées.")
        catalog.Set("当前内容", "Contenu actuel")
        catalog.Set("AI 建议", "Suggestion de l’IA")
        catalog.Set("接受结果", "Accepter")
        catalog.Set("保留原文", "Conserver l’original")
        catalog.Set("AI 返回的规则经过自动修复后仍未通过本地校验：{1}", "La règle de l’IA échoue encore à la validation locale après réparation automatique : {1}")
        catalog.Set("AI 规则校验结果不完整。", "Le résultat de validation de la règle IA est incomplet.")
        catalog.Set("AI 正在复核规则的实际行为，请稍候...", "L’IA vérifie le comportement réel de la règle. Veuillez patienter...")
        catalog.Set("AI 正在根据本地校验结果修复规则，请稍候...", "L’IA répare la règle d’après la validation locale. Veuillez patienter...")
        catalog.Set("本地校验失败：{1}", "Échec de la validation locale : {1}")
        catalog.Set("失败发生阶段：{1}", "Étape de l’échec : {1}")
        catalog.Set("必须修复根因并重新满足用户原始目的。", "Corrigez la cause première et répondez entièrement à l’objectif initial de l’utilisateur.")
        catalog.Set("规则块能力不足，必须改用受托管脚本完整实现。", "Un bloc de règle standard ne suffit pas `; utilisez un script géré pour l’implémentation complète.")
        catalog.Set("未保存：请先用完整的 AHK v2 脚本替换代码占位文字。", "Non enregistré : remplacez d’abord le texte réservé par un script AHK v2 complet.")
        catalog.Set("当前等待时间：{1} 秒", "Current wait time: {1} seconds")
        catalog.Set("界面缩放：", "Mise à l’échelle de l’interface :")
        catalog.Set("界面缩放已保存，正在重新加载…", "La mise à l’échelle de l’interface a été enregistrée. Rechargement…")
        return catalog
    }
}
