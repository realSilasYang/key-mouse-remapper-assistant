; pt-BR 本地化词条目录。
; 简体中文原文是稳定键；本目录与其它语言保持完全相同的键集合。

class PortugueseBrazilStrings {
    static Create() {
        catalog := Map()
        catalog.CaseSense := "On"
        catalog.Set("按下", "Pressionar")
        catalog.Set(
            "键鼠重映射小助手",
                "Assistente de remapeamento de teclado e mouse")
        catalog.Set(
            "新增",
                "Adicionar")
        catalog.Set(
            "新增映射",
                "Adicionar mapeamento")
        catalog.Set(
            "删除",
                "Excluir")
        catalog.Set(
            "暂停",
                "Pausar")
        catalog.Set(
            "恢复",
                "Retomar")
        catalog.Set(
            "序号",
                "Nº")
        catalog.Set(
            "来源按键",
                "Chave de origem")
        catalog.Set(
            "映射结果",
                "Resultado mapeado")
        catalog.Set(
            "生效范围",
                "Escopo")
        catalog.Set(
            "设计目的",
                "Objetivo")
        catalog.Set(
            "新建映射",
                "Novo mapeamento")
        catalog.Set(
            "映射为",
                "Mapear para")
        catalog.Set(
            "点击录制来源按键",
                "Clique para gravar chaves de origem")
        catalog.Set(
            "点击录制目标按键",
                "Clique para gravar chaves de destino")
        catalog.Set(
            "保存映射",
                "Salvar")
        catalog.Set(
            "清空",
                "Limpar")
        catalog.Set(
            "准备就绪",
                "Pronto")
        catalog.Set(
            "请按下按键 · Esc 取消",
                "Pressione as teclas · Esc para cancelar")
        catalog.Set(
            "编辑映射代码",
                "Editar código de mapeamento")
        catalog.Set(
            "新增映射代码",
                "Adicionar código de mapeamento")
        catalog.Set(
            "元数据说明",
                "Referência de metadados")
        catalog.Set(
            "RuleSpec 外壳版本，当前必须为 2。",
                "Versão do envelope RuleSpec; atualmente deve ser 2.")
        catalog.Set(
            "规则模式，当前必须为 managed。",
                "Modo da regra; atualmente deve ser managed.")
        catalog.Set(
            "映射的唯一编号，必须与 RuleSpec 的 id 一致。",
                "ID exclusivo do mapeamento; deve coincidir com o id do RuleSpec.")
        catalog.Set(
            "结构化 RuleSpec JSON 的开始标记。",
                "Marcador inicial do JSON RuleSpec estruturado.")
        catalog.Set(
            "注释化 JSON；可编辑来源、条件、显示信息和输出动作。",
                "JSON comentado; edite a origem, as condições, os dados exibidos e as ações de saída.")
        catalog.Set(
            "结构化 RuleSpec JSON 的结束标记。",
                "Marcador final do JSON RuleSpec estruturado.")
        catalog.Set(
            "规范化 RuleSpec JSON 的 SHA-256 摘要。",
                "Resumo SHA-256 do JSON RuleSpec normalizado.")
        catalog.Set(
            "生成区只含说明注释，不包含可执行 AHK。",
                "A área gerada contém apenas comentários explicativos, sem AHK executável.")
        catalog.Set(
            "整个映射块只允许注释化 RuleSpec JSON；右侧说明仅供参考，不会保存到代码。",
                "Todo o bloco de mapeamento aceita apenas JSON RuleSpec comentado. A ajuda à direita não é salva.")
        catalog.Set(
            "代码修改尚未保存，确定放弃吗？",
                "O código tem alterações não salvas. Descartá-los?")
        catalog.Set(
            "放弃修改",
                "Descartar alterações")
        catalog.Set(
            "显示主界面",
                "Mostrar janela principal")
        catalog.Set(
            "重新加载",
                "Recarregar")
        catalog.Set(
            "事件查看器",
                "Eventos")
        catalog.Set("事件详情", "Detalhes do evento")
        catalog.Set("事件：{1}", "Evento: {1}")
        catalog.Set("类别：{1}", "Categoria: {1}")
        catalog.Set("时间：{1}", "Hora: {1}")
        catalog.Set("来源：{1}", "Origem: {1}")
        catalog.Set("结果：{1}", "Resultado: {1}")
        catalog.Set("详情：{1}", "Detalhes: {1}")
        catalog.Set("按键名称：{1}", "Nome da tecla: {1}")
        catalog.Set("原始观察", "Observação bruta")
        catalog.Set("退出观察", "Parar observação")
        catalog.Set("原始观察中", "Observação bruta ativa")
        catalog.Set("原始观察切换失败：{1}",
            "Não foi possível alterar a observação bruta: {1}")
        catalog.Set("诊断包", "Diagnóstico")
        catalog.Set("诊断包预览", "Prévia do pacote de diagnóstico")
        catalog.Set("导出诊断包", "Exportar pacote de diagnóstico")
        catalog.Set("诊断包导出失败：{1}",
            "Não foi possível exportar o pacote de diagnóstico: {1}")
        catalog.Set("诊断包已导出：{1}", "Pacote de diagnóstico exportado: {1}")
        catalog.Set("将导出 {1} 条事件；已脱敏窗口标题 {2}、路径 {3}、文本/命令 {4}、代码 {5}、变量值 {6} 项。是否继续？",
            "Exportar {1} eventos? Foram ocultados {2} títulos de janela, {3} caminhos, {4} valores de texto/comando, {5} valores de código e {6} valores de variáveis.")
        catalog.Set(
            "导入规则包",
                "Pacote de regras de importação")
        catalog.Set(
            "导出规则包",
                "Pacote de regras de exportação")
        catalog.Set(
            "规则包导出失败：{1}",
                "Falha na exportação do pacote de regras: {1}")
        catalog.Set(
            "已导出 {1} 条规则：{2}",
                "Exportado {1} regras: {2}")
        catalog.Set(
            "规则包导入失败：{1}",
                "Falha na importação do pacote de regras: {1}")
        catalog.Set(
            "规则包导入失败，且回滚失败：{1}",
                "Falha na importação e reversão do pacote de regras: {1}")
        catalog.Set(
            "规则包导入完成：新增 {1}，替换 {2}，重命名 {3}，跳过 {4}。",
                "Importação concluída: {1} adicionado, {2} substituído, {3} renomeado, {4} ignorado.")
        catalog.Set("变量", "Variáveis")
        catalog.Set("变量快照", "Instantâneo de variáveis")
        catalog.Set("导入规则包预览", "Prévia da importação do pacote")
        catalog.Set("来源：{1} · 版本：{2}", "Origem: {1} · Versão: {2}")
        catalog.Set("共 {1} 条规则，默认选中 {2} 条；权限：{3}", "{1} regras; {2} selecionadas. Permissões: {3}")
        catalog.Set("规则编号", "ID da regra")
        catalog.Set("模式", "Modo")
        catalog.Set("权限", "Permissões")
        catalog.Set("全选", "Selecionar tudo")
        catalog.Set("全部取消", "Limpar seleção")
        catalog.Set("导入所选", "Importar selecionadas")
        catalog.Set("无额外权限", "Sem permissões adicionais")
        catalog.Set("请至少选择一条规则。", "Selecione pelo menos uma regra.")
        catalog.Set("导入失败，请查看主窗口状态。", "Falha na importação. Veja o status da janela principal.")
        catalog.Set(
            "筛选：",
                "Filtro:")
        catalog.Set(
            "全部事件",
                "Todos os eventos")
        catalog.Set(
            "输入事件",
                "Entrada")
        catalog.Set(
            "规则运行",
                "Tempo de execução")
        catalog.Set(
            "规则仓储",
                "Repositório")
        catalog.Set(
            "撤销历史",
                "História")
        catalog.Set(
            "系统事件",
                "Sistema")
        catalog.Set(
            "界面事件",
                "IU")
        catalog.Set(
            "暂停刷新",
                "Pausa")
        catalog.Set(
            "恢复刷新",
                "Retomar")
        catalog.Set(
            "导出事件",
                "Exportar eventos")
        catalog.Set(
            "时间",
                "Hora")
        catalog.Set(
            "类别",
                "Categoria")
        catalog.Set(
            "事件",
                "Evento")
        catalog.Set(
            "来源 / 规则",
                "Fonte/regra")
        catalog.Set(
            "结果",
                "Resultado")
        catalog.Set(
            "详情",
                "Detalhes")
        catalog.Set(
            "输入",
                "Entrada")
        catalog.Set(
            "运行时",
                "Tempo de execução")
        catalog.Set(
            "仓储",
                "Repositório")
        catalog.Set(
            "历史",
                "História")
        catalog.Set(
            "系统",
                "Sistema")
        catalog.Set(
            "界面",
                "IU")
        catalog.Set(
            "已暂停刷新",
                "Pausado")
        catalog.Set(
            "实时刷新",
                "Ao vivo")
        catalog.Set(
            "显示 {1} 条 · 缓冲区 {2}/{3} · 已丢弃 {4} 条 · {5}",
                "Mostrando {1} · buffer {2}/{3} · descartado {4} · {5}")
        catalog.Set(
            "事件导出失败：{1}",
                "Falha na exportação do evento: {1}")
        catalog.Set(
            "事件已导出：{1}",
                "Eventos exportados: {1}")
        catalog.Set(
            "无法打开事件查看器：{1}",
                "Não foi possível abrir o Visualizador de Eventos: {1}")
        catalog.Set(
            "退出程序",
                "Sair do programa")
        catalog.Set(
            "设置",
                "Configurações")
        catalog.Set(
            "界面语言",
                "Idioma")
        catalog.Set(
            "主题",
                "Tema")
        catalog.Set(
            "界面语言：",
                "Idioma da interface:")
        catalog.Set(
            "界面内容字体：",
                "Fonte do conteúdo da interface:")
        catalog.Set(
            "主题：",
                "Tema:")
        catalog.Set(
            "跟随系统",
                "Acompanhar o sistema")
        catalog.Set(
            "浅色",
                "Claro")
        catalog.Set(
            "深色",
                "Escuro")
        catalog.Set(
            "跟随语言默认（{1}）",
                "Fonte padrão do idioma ({1})")
        catalog.Set(
            "保存",
                "Salvar")
        catalog.Set(
            "取消",
                "Cancelar")
        catalog.Set(
            "已暂停",
                "Pausado")
        catalog.Set(
            "已恢复脚本中的自定义顺序。",
                "Restaurou a ordem do script personalizado.")
        catalog.Set(
            "升序",
                "ascendente")
        catalog.Set(
            "降序",
                "descendo")
        catalog.Set(
            "已临时按“{1}”{2}排列；不会改写脚本顺序。",
                "Classificado temporariamente por {1} ({2}); a ordem do script permanece inalterada.")
        catalog.Set(
            "无法恢复自定义顺序：{1}",
                "Não foi possível restaurar o pedido personalizado: {1}")
        catalog.Set(
            "映射顺序没有变化。",
                "A ordem de mapeamento não mudou.")
        catalog.Set(
            "无法启动按键录制，请重试。",
                "Não foi possível iniciar a gravação da chave. Tente novamente.")
        catalog.Set(
            "正在录制来源按键…",
                "Gravando chaves de origem...")
        catalog.Set(
            "正在录制目标按键…",
                "Gravando chaves de destino...")
        catalog.Set(
            "来源",
                "fonte")
        catalog.Set(
            "目标",
                "alvo")
        catalog.Set(
            "正在录制{1}按键：{2}",
                "Gravando chaves {1}: {2}")
        catalog.Set(
            "已录制{1}按键：{2}",
                "Chaves {1} gravadas: {2}")
        catalog.Set(
            "已取消按键录制。",
                "Gravação de chave cancelada.")
        catalog.Set(
            "请先完成或取消当前按键录制。",
                "Termine ou cancele a gravação atual primeiro.")
        catalog.Set(
            "请先录制来源按键和目标按键。",
                "Grave primeiro as chaves de origem e de destino.")
        catalog.Set(
            "已清空新建区域。",
                "Limpei a nova área de mapeamento.")
        catalog.Set(
            "请先选择要删除的映射。",
                "Selecione um mapeamento para excluir primeiro.")
        catalog.Set(
            "所选映射缺少代码块编号，无法删除。",
                "O mapeamento selecionado não possui ID de bloco e não pode ser excluído.")
        catalog.Set(
            "请先选择要暂停或恢复的映射。",
                "Selecione um mapeamento para pausar ou retomar primeiro.")
        catalog.Set(
            "所选映射缺少代码块编号，无法修改状态。",
                "O mapeamento selecionado não possui ID de bloco e não pode alterar o estado.")
        catalog.Set(
            "无法打开映射代码：{1}",
                "Não foi possível abrir o código de mapeamento: {1}")
        catalog.Set(
            "无法打开代码编辑器：{1}",
                "Não foi possível abrir o editor de código: {1}")
        catalog.Set(
            "映射 · {1} -> {2}{3}",
                "Mapeamento · {1} -> {2}{3}")
        catalog.Set(
            "全局",
                "Globais")
        catalog.Set(
            "按键名称：{1}`n虚拟键码：{2}`n扫描码：{3}",
                "Nome da chave: {1}`nChave virtual: {2}`nCódigo de digitalização: {3}")
        catalog.Set(
            "不适用",
                "n/a")
        catalog.Set(
            "键盘",
                "Teclado")
        catalog.Set(
            "鼠标",
                "Rato")
        catalog.Set(
            "滚轮",
                "Roda")
        catalog.Set(
            "多媒体",
                "Mídia")
        catalog.Set(
            "命名键",
                "Chave nomeada")
        catalog.Set(
            "左侧 Ctrl",
                "Ctrl esquerdo")
        catalog.Set(
            "右侧 Ctrl",
                "Ctrl direito")
        catalog.Set(
            "左侧 Shift",
                "Deslocamento Esquerdo")
        catalog.Set(
            "右侧 Shift",
                "Mudança para a direita")
        catalog.Set(
            "左侧 Alt",
                "Alt esquerdo")
        catalog.Set(
            "右侧 Alt",
                "Alt direito")
        catalog.Set(
            "左侧 Win",
                "Vitória à esquerda")
        catalog.Set(
            "右侧 Win",
                "Vitória certa")
        catalog.Set(
            "读取重映射代码区域失败：{1}",
                "Não foi possível ler a região de mapeamento: {1}")
        catalog.Set(
            "托管规则未应用：{1}",
                "As regras gerenciadas não foram aplicadas: {1}")
        catalog.Set(
            "无法检查现有映射：{1}",
                "Não foi possível inspecionar os mapeamentos existentes: {1}")
        catalog.Set(
            "为避免失去界面操作，来源按键不能是无修饰的鼠标左键。",
                "Um botão esquerdo do mouse não modificado não pode ser usado como chave de origem.")
        catalog.Set(
            "该来源按键已被现有映射占用。",
                "Essa chave de origem já é usada por outro mapeamento.")
        catalog.Set(
            "来源按键与目标按键相同，无需建立映射。",
                "A origem e o destino são idênticos; nenhum mapeamento é necessário.")
        catalog.Set(
            "映射未写入脚本：{1}",
                "O mapeamento não foi escrito: {1}")
        catalog.Set(
            "已写入脚本：{1} -> {2}；正在自动应用。",
                "Escrito no script: {1} -> {2}; aplicando automaticamente.")
        catalog.Set(
            "删除映射",
                "Excluir mapeamento")
        catalog.Set(
            "映射未删除：{1}",
                "O mapeamento não foi excluído: {1}")
        catalog.Set(
            "已从脚本删除：{1} -> {2}；正在自动应用。",
                "Excluído do script: {1} -> {2}; aplicando automaticamente.")
        catalog.Set(
            "调整映射顺序",
                "Reordenar mapeamentos")
        catalog.Set(
            "顺序未保存：{1}",
                "O pedido não foi salvo: {1}")
        catalog.Set(
            "已按拖动结果实时更新脚本顺序。",
                "Atualizada a ordem do script a partir do resultado arrastado.")
        catalog.Set(
            "暂停映射",
                "Pausar mapeamento")
        catalog.Set(
            "恢复映射",
                "Retomar mapeamento")
        catalog.Set(
            "映射状态未修改：{1}",
                "O estado do mapeamento não foi alterado: {1}")
        catalog.Set(
            "已恢复映射：{1} -> {2}；正在自动应用。",
                "Mapeamento retomado: {1} -> {2}; aplicando automaticamente.")
        catalog.Set(
            "已暂停映射：{1} -> {2}；正在自动应用。",
                "Mapeamento pausado: {1} -> {2}; aplicando automaticamente.")
        catalog.Set(
            "映射代码未保存：{1}",
                "O código de mapeamento não foi salvo: {1}")
        catalog.Set(
            "映射代码未新增：{1}",
                "O código de mapeamento não foi adicionado: {1}")
        catalog.Set(
            "未保存：{1}",
                "Não salvo: {1}")
        catalog.Set(
            "已保存映射代码：{1} -> {2}；正在自动应用。",
                "Código de mapeamento salvo: {1} -> {2}; aplicando automaticamente.")
        catalog.Set(
            "已新增映射代码：{1} -> {2}；正在自动应用。",
                "Código de mapeamento adicionado: {1} -> {2}; aplicando automaticamente.")
        catalog.Set(
            "无法创建空白映射代码：{1}",
                "Não foi possível criar o código de mapeamento em branco: {1}")
        catalog.Set(
            "无法打开设置：{1}",
                "Não foi possível abrir as configurações: {1}")
        catalog.Set(
            "设置未保存：{1}",
                "As configurações não foram salvas: {1}")
        catalog.Set(
            "界面内容字体",
                "Fonte da IU")
        catalog.Set(
            "撤销失败：{1}",
                "Falha ao desfazer: {1}")
        catalog.Set(
            "重做失败：{1}",
                "Falha ao refazer: {1}")
        catalog.Set(
            "已撤销：{1}",
                "Desfeito: {1}")
        catalog.Set(
            "已重做：{1}",
                "Refeito: {1}")
        catalog.Set(
            "映射配置",
                "Configuração de mapeamento")
        catalog.Set(
            "{1} 条重映射正在生效 · 当前为脚本代码顺序",
                "{1} mapeamentos ativos · ordem de script personalizada")
        catalog.Set("键鼠重映射小助手设置",
            "Configurações do assistente de remapeamento de teclado e mouse")
        catalog.Set("外观",
            "Aparência")
        catalog.Set("规则包",
            "Pacotes de regras")
        catalog.Set("关于",
            "Sobre")
        catalog.Set("事件缓冲区容量（条）：",
            "Capacidade do buffer de eventos:")
        catalog.Set("事件查看器自动跟随最新事件",
            "Seguir automaticamente os eventos mais recentes")
        catalog.Set("让每一条键鼠映射都可录制、可审阅、可掌控",
            "Grave, revise e controle cada remapeamento de teclado e mouse")
        catalog.Set("当前版本",
            "Versão atual")
        catalog.Set("运行环境",
            "Ambiente de execução")
        catalog.Set("查看最新版本",
            "Ver versão mais recente")
        catalog.Set("开源地址",
            "Repositório de código aberto")
        catalog.Set("“{1}”必须是 {2} 到 {3} 之间的整数。",
            "“{1}” deve ser um inteiro entre {2} e {3}.")
        catalog.Set("事件缓冲区容量",
            "Capacidade do buffer de eventos")
        catalog.Set("未知版本",
            "Versão desconhecida")
        catalog.Set("{1}（EXE 版）",
            "{1} (versão EXE)")
        catalog.Set("{1}（源码版）",
            "{1} (versão de código-fonte)")
        catalog.Set("设置没有变化。",
            "Nenhuma configuração foi alterada.")
        catalog.Set("设置已保存并已应用。",
            "Configurações salvas e aplicadas.")
        catalog.Set("设置",
            "Configurações")
        catalog.Set("Esc 取消录制",
            "Esc cancela a gravação")
        catalog.Set("事件自动跟随",
            "Seguir eventos mais recentes")
        catalog.Set("事件", "Eventos")
        catalog.Set("{1}（便携版）", "{1} (versão portátil)")
        catalog.Set("帮助信息", "Ajuda")
        catalog.Set("捐赠", "Doar")
        catalog.Set("配置外观、规则包、事件`n以及关于选项",
            "Configure Aparência, Pacotes de regras, Eventos`ne Sobre")
        catalog.Set("打开帮助信息`n可选择查看使用说明、运行日志或提交反馈",
            "Abrir Ajuda`nEscolha o guia do usuário, o log de execução ou o envio de feedback")
        catalog.Set("快揭不开锅了（≥Д≤）",
            "O orçamento está quase no fim（≥Д≤）")
        catalog.Set("使用说明", "Guia de uso")
        catalog.Set("提交反馈", "Enviar feedback")
        catalog.Set("支持开源项目", "Apoiar o projeto de código aberto")
        catalog.Set("微信支付", "WeChat Pay")
        catalog.Set("支付宝", "Alipay")
        catalog.Set("二维码图片未找到", "Imagem do código QR não encontrada")
        catalog.Set("如果小助手为您节省了排查问题和恢复程序的时间，欢迎通过下方二维码打赏作者！`n请选择扶贫方式：", "Se o assistente poupou seu tempo ao diagnosticar problemas e restaurar programas, considere apoiar o autor pelos códigos QR abaixo!`nEscolha como deseja contribuir:")
        catalog.Set("无法打开帮助信息：{1}", "Não foi possível abrir a Ajuda: {1}")
        catalog.Set("无法打开使用说明：{1}", "Não foi possível abrir o guia de uso: {1}")
        catalog.Set("无法打开捐赠窗口：{1}", "Não foi possível abrir a janela de doação: {1}")
        catalog.Set("无法打开反馈页面：{1}", "Não foi possível abrir a página de feedback: {1}")
        catalog.Set("键鼠重映射小助手用于录制、审阅和维护键盘与鼠标映射。关闭主窗口只会隐藏到系统托盘，已经启用的映射仍会继续生效。", "O assistente de remapeamento de teclado e mouse registra, revisa e mantém mapeamentos do teclado e do mouse. Fechar a janela principal apenas o oculta na bandeja do sistema; os mapeamentos ativados continuam funcionando.")
        catalog.Set("一、快速上手", "1. Início rápido")
        catalog.Set("• 点击顶部“新增”，会打开已经填好元数据字段的 @mapping 编辑器；也可以在下方分别录制来源按键和目标按键，填写设计目的后保存。", "• Selecione Adicionar na barra superior para abrir um editor @mapping com os campos de metadados preparados. Também é possível gravar abaixo a entrada de origem e a de destino, informar a finalidade e salvar.")
        catalog.Set("• 录制会实时显示原始规范名称、阅读友好名称、虚拟键码和扫描码，并区分左右 Ctrl、Shift、Alt、Win 以及键盘、鼠标和滚轮输入。", "• A gravação mostra em tempo real o nome canônico, o nome legível, o código de tecla virtual e o código de varredura. Ela diferencia Ctrl, Shift, Alt e Win esquerdos e direitos, além de entradas do teclado, mouse e roda.")
        catalog.Set("• 同时按下的任意按键会组成一次录制；所有按键释放后结束。录制期间再次点击录制按钮会取消本次录制，不会把该次点击记为 LButton。", "• Quaisquer teclas mantidas juntas formam uma gravação, encerrada quando todas são soltas. Selecionar novamente o botão de gravação cancela a operação em vez de registrar o clique como LButton.")
        catalog.Set("二、主界面与代码编辑", "2. Janela principal e edição de código")
        catalog.Set("• 单击选择映射；双击条目、悬停时按 F2 或使用右键菜单，可编辑完整 @mapping 代码块。", "• Clique uma vez para selecionar um mapeamento. Clique duas vezes em uma linha, pressione F2 ao apontá-la ou use o menu de contexto para editar todo o bloco @mapping.")
        catalog.Set("• 选中条目后可暂停、恢复或删除；直接拖动列表行可调整永久顺序，脚本中的代码块顺序会实时同步。", "• Um mapeamento selecionado pode ser pausado, retomado ou excluído. Arraste as linhas para alterar a ordem permanente; a ordem dos blocos no script é sincronizada imediatamente.")
        catalog.Set("• 点击伪表头只进行临时排序；字段按升序、降序、自定义顺序循环，序号列按降序、自定义顺序循环，不会改写脚本。", "• A classificação pelos cabeçalhos simulados é temporária. Os campos alternam entre ordem crescente, decrescente e personalizada; a coluna numérica alterna entre decrescente e personalizada. O script não é regravado.")
        catalog.Set("• 映射区域只保存注释化 RuleSpec v2，是映射的唯一持久来源。GUI 创建或编辑的托管规则会直接热应用；可执行 AHK 代码不会被接受。", "• A região de mapeamento armazena apenas RuleSpec v2 comentadas e é a única fonte persistente. Regras gerenciadas criadas ou editadas na interface são aplicadas a quente; código AHK executável é rejeitado.")
        catalog.Set("四、事件、历史与界面设置", "4. Eventos, histórico e aparência")
        catalog.Set("• 事件查看器记录输入、规则匹配、条件拒绝、执行结果、仓储和系统事件，支持筛选、暂停、清空及 JSONL 导出。", "• O Visualizador de Eventos registra entradas, correspondências de regras, rejeições de condições, resultados de execução, atividade do repositório e eventos do sistema. Ele permite filtrar, pausar, limpar e exportar JSONL.")
        catalog.Set("五、后台运行与问题排查", "5. Execução em segundo plano e solução de problemas")
        catalog.Set("• 主窗口关闭后程序仍驻留托盘。托盘可以重新显示主界面、手动重新加载或彻底退出；修改映射规则后通常不需要手动重新加载。", "• O aplicativo permanece na bandeja depois que a janela principal é fechada. Pela bandeja é possível mostrar a janela, recarregar manualmente ou sair por completo; alterações nas regras normalmente não exigem recarga manual.")
        catalog.Set("• “帮助信息”还可打开项目反馈页面。提交问题时请说明系统版本、复现步骤、相关 @mapping 代码和事件导出，并在公开前移除敏感路径或应用信息。", "• A Ajuda também abre a página de feedback do projeto. Ao relatar um problema, inclua a versão do Windows, as etapas de reprodução, o código @mapping relacionado e uma exportação de eventos, removendo caminhos ou dados de aplicativos confidenciais antes de publicar.")
        catalog.Set("安全模式：已停用所有映射和输入观察。连续启动失败 {1} 次。", "Modo de segurança: todos os remapeamentos e a observação de entrada foram desativados após {1} falhas consecutivas na inicialização.")
        catalog.Set("仅勾选的规则会被导入。", "Somente as regras selecionadas serão importadas.")
        catalog.Set("三、规则与生效范围", "3. Regras e escopo")
        catalog.Set("• 所有规则属于同一全局规则集；生效范围和条件可在 @mapping 编辑器中精确调整，保存后会立即重新选择生效规则。", "• Todas as regras pertencem a um único conjunto global. O escopo e as condições podem ser ajustados com precisão no editor @mapping; ao salvar, as regras ativas são selecionadas novamente de imediato.")
        catalog.Set("• Ctrl+Z 撤销，Ctrl+Shift+Z 或 Ctrl+Y 重做。映射增删、暂停恢复、拖动排序、代码编辑和设置修改都会进入持久历史。", "• Ctrl+Z desfaz; Ctrl+Shift+Z ou Ctrl+Y refaz. Adições, exclusões, pausas, retomadas, reordenações, edições de código e configurações ficam no histórico persistente.")
        return catalog
    }
}
