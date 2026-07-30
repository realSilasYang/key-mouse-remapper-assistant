; es-ES 本地化词条目录。
; 简体中文原文是稳定键；本目录与其它语言保持完全相同的键集合。

class SpanishStrings {
    static Create() {
        catalog := Map()
        catalog.CaseSense := "On"
        catalog.Set("按下", "Pulsar")
        catalog.Set(
            "键鼠重映射小助手",
                "Asistente de reasignación de teclado y mouse")
        catalog.Set(
            "新增",
                "Añadir")
        catalog.Set(
            "新增映射",
                "Agregar mapeo")
        catalog.Set(
            "删除",
                "Eliminar")
        catalog.Set(
            "暂停",
                "Pausar")
        catalog.Set(
            "恢复",
                "Reanudar")
        catalog.Set(
            "序号",
                "N.º")
        catalog.Set(
            "来源按键",
                "Clave fuente")
        catalog.Set(
            "映射结果",
                "Resultado mapeado")
        catalog.Set(
            "生效范围",
                "Alcance")
        catalog.Set(
            "设计目的",
                "Propósito")
        catalog.Set(
            "新建映射",
                "Nuevo mapeo")
        catalog.Set(
            "映射为",
                "Mapa a")
        catalog.Set(
            "点击录制来源按键",
                "Haga clic para registrar las claves fuente")
        catalog.Set(
            "点击录制目标按键",
                "Haga clic para registrar las claves de destino")
        catalog.Set(
            "保存映射",
                "Guardar")
        catalog.Set(
            "清空",
                "Borrar")
        catalog.Set(
            "准备就绪",
                "Listo")
        catalog.Set(
            "请按下按键 · Esc 取消",
                "Presione las teclas · Esc para cancelar")
        catalog.Set(
            "编辑映射代码",
                "Editar código de mapeo")
        catalog.Set(
            "新增映射代码",
                "Agregar código de mapeo")
        catalog.Set(
            "元数据说明",
                "Referencia de metadatos")
        catalog.Set(
            "RuleSpec 外壳版本，当前必须为 2。",
                "Versión de la envoltura RuleSpec; actualmente debe ser 2.")
        catalog.Set(
            "规则模式，当前必须为 managed。",
                "Modo de regla; actualmente debe ser managed.")
        catalog.Set(
            "映射的唯一编号，必须与 RuleSpec 的 id 一致。",
                "ID único de la asignación; debe coincidir con el id de RuleSpec.")
        catalog.Set(
            "结构化 RuleSpec JSON 的开始标记。",
                "Marcador inicial del JSON RuleSpec estructurado.")
        catalog.Set(
            "注释化 JSON；可编辑来源、条件、显示信息和输出动作。",
                "JSON comentado; edite el origen, las condiciones, la información visible y las acciones de salida.")
        catalog.Set(
            "结构化 RuleSpec JSON 的结束标记。",
                "Marcador final del JSON RuleSpec estructurado.")
        catalog.Set(
            "规范化 RuleSpec JSON 的 SHA-256 摘要。",
                "Resumen SHA-256 del JSON RuleSpec normalizado.")
        catalog.Set(
            "生成区只含说明注释，不包含可执行 AHK。",
                "La zona generada solo contiene comentarios explicativos, sin AHK ejecutable.")
        catalog.Set(
            "整个映射块只允许注释化 RuleSpec JSON；右侧说明仅供参考，不会保存到代码。",
                "Todo el bloque de asignación solo admite JSON RuleSpec comentado. La ayuda de la derecha no se guarda.")
        catalog.Set(
            "代码修改尚未保存，确定放弃吗？",
                "El código tiene cambios no guardados. ¿Descartarlos?")
        catalog.Set(
            "放弃修改",
                "Descartar cambios")
        catalog.Set(
            "显示主界面",
                "Mostrar ventana principal")
        catalog.Set(
            "重新加载",
                "Recargar")
        catalog.Set(
            "以管理员身份重新启动",
                "Reiniciar como administrador")
        catalog.Set(
            "管理员模式（当前）",
                "Modo administrador (activo)")
        catalog.Set(
            "无法以管理员身份重新启动（错误代码 {1}）。",
                "No se pudo reiniciar como administrador (error {1}).")
        catalog.Set(
            "事件查看器",
                "Eventos")
        catalog.Set("事件详情", "Detalles del evento")
        catalog.Set("事件：{1}", "Evento: {1}")
        catalog.Set("类别：{1}", "Categoría: {1}")
        catalog.Set("时间：{1}", "Hora: {1}")
        catalog.Set("来源：{1}", "Origen: {1}")
        catalog.Set("结果：{1}", "Resultado: {1}")
        catalog.Set("详情：{1}", "Detalles: {1}")
        catalog.Set("按键名称：{1}", "Nombre de tecla: {1}")
        catalog.Set("原始观察", "Observación sin procesar")
        catalog.Set("退出观察", "Detener observación")
        catalog.Set("原始观察中", "Observación sin procesar activa")
        catalog.Set("原始观察切换失败：{1}",
            "No se pudo cambiar la observación sin procesar: {1}")
        catalog.Set("诊断包", "Diagnóstico")
        catalog.Set("诊断包预览", "Vista previa del paquete de diagnóstico")
        catalog.Set("导出诊断包", "Exportar paquete de diagnóstico")
        catalog.Set("诊断包导出失败：{1}",
            "No se pudo exportar el paquete de diagnóstico: {1}")
        catalog.Set("诊断包已导出：{1}", "Paquete de diagnóstico exportado: {1}")
        catalog.Set("将导出 {1} 条事件；已脱敏窗口标题 {2}、路径 {3}、文本/命令 {4}、代码 {5}、变量值 {6} 项。是否继续？",
            "¿Exportar {1} eventos? Se ocultaron {2} títulos de ventana, {3} rutas, {4} valores de texto/comando, {5} valores de código y {6} valores de variables.")
        catalog.Set(
            "导入规则包",
                "Importar paquete de reglas")
        catalog.Set(
            "导出规则包",
                "Paquete de reglas de exportación")
        catalog.Set(
            "规则包导出失败：{1}",
                "Error al exportar el paquete de reglas: {1}")
        catalog.Set(
            "已导出 {1} 条规则：{2}",
                "Exportado {1} reglas: {2}")
        catalog.Set(
            "规则包导入失败：{1}",
                "Error al importar el paquete de reglas: {1}")
        catalog.Set(
            "规则包导入失败，且回滚失败：{1}",
                "Error al importar y revertir el paquete de reglas: {1}")
        catalog.Set(
            "规则包导入完成：新增 {1}，替换 {2}，重命名 {3}，跳过 {4}。",
                "Importación completa: {1} agregado, {2} reemplazado, {3} renombrado, {4} omitido.")
        catalog.Set("变量", "Variables")
        catalog.Set("变量快照", "Instantánea de variables")
        catalog.Set("导入规则包预览", "Vista previa de importación del paquete")
        catalog.Set("来源：{1} · 版本：{2}", "Origen: {1} · Versión: {2}")
        catalog.Set("共 {1} 条规则，默认选中 {2} 条；权限：{3}", "{1} reglas; {2} seleccionadas. Permisos: {3}")
        catalog.Set("规则编号", "ID de regla")
        catalog.Set("模式", "Modo")
        catalog.Set("权限", "Permisos")
        catalog.Set("全选", "Seleccionar todo")
        catalog.Set("全部取消", "Quitar selección")
        catalog.Set("导入所选", "Importar selección")
        catalog.Set("无额外权限", "Sin permisos adicionales")
        catalog.Set("请至少选择一条规则。", "Selecciona al menos una regla.")
        catalog.Set("导入失败，请查看主窗口状态。", "Error de importación. Revisa el estado de la ventana principal.")
        catalog.Set(
            "筛选：",
                "Filtro:")
        catalog.Set(
            "全部事件",
                "Todos los eventos")
        catalog.Set(
            "输入事件",
                "Entrada")
        catalog.Set(
            "规则运行",
                "Tiempo de ejecución")
        catalog.Set(
            "规则仓储",
                "Repositorio")
        catalog.Set(
            "撤销历史",
                "Historia")
        catalog.Set(
            "系统事件",
                "Sistema")
        catalog.Set(
            "界面事件",
                "interfaz de usuario")
        catalog.Set(
            "暂停刷新",
                "Pausa")
        catalog.Set(
            "恢复刷新",
                "Reanudar")
        catalog.Set(
            "导出事件",
                "Exportar eventos")
        catalog.Set(
            "时间",
                "tiempo")
        catalog.Set(
            "类别",
                "categoría")
        catalog.Set(
            "事件",
                "Evento")
        catalog.Set(
            "来源 / 规则",
                "Fuente / regla")
        catalog.Set(
            "结果",
                "Resultado")
        catalog.Set(
            "详情",
                "Detalles")
        catalog.Set(
            "输入",
                "Entrada")
        catalog.Set(
            "运行时",
                "Tiempo de ejecución")
        catalog.Set(
            "仓储",
                "Repositorio")
        catalog.Set(
            "历史",
                "Historia")
        catalog.Set(
            "系统",
                "Sistema")
        catalog.Set(
            "界面",
                "interfaz de usuario")
        catalog.Set(
            "已暂停刷新",
                "En pausa")
        catalog.Set(
            "实时刷新",
                "en vivo")
        catalog.Set(
            "显示 {1} 条 · 缓冲区 {2}/{3} · 已丢弃 {4} 条 · {5}",
                "Mostrando {1} · buffer {2}/{3} · eliminado {4} · {5}")
        catalog.Set(
            "事件导出失败：{1}",
                "Error al exportar el evento: {1}")
        catalog.Set(
            "事件已导出：{1}",
                "Eventos exportados: {1}")
        catalog.Set(
            "无法打开事件查看器：{1}",
                "No se pudo abrir el Visor de eventos: {1}")
        catalog.Set(
            "退出程序",
                "Salir del programa")
        catalog.Set(
            "设置",
                "Configuración")
        catalog.Set(
            "界面语言",
                "Idioma")
        catalog.Set(
            "主题",
                "Tema")
        catalog.Set(
            "界面语言：",
                "Idioma de la interfaz:")
        catalog.Set(
            "界面内容字体：",
                "Fuente del contenido de la interfaz:")
        catalog.Set(
            "主题：",
                "Tema:")
        catalog.Set(
            "跟随系统",
                "Seguir el sistema")
        catalog.Set(
            "浅色",
                "Claro")
        catalog.Set(
            "深色",
                "Oscuro")
        catalog.Set(
            "跟随语言默认（{1}）",
                "Fuente predeterminada del idioma ({1})")
        catalog.Set(
            "保存",
                "Guardar")
        catalog.Set(
            "取消",
                "Cancelar")
        catalog.Set(
            "已暂停",
                "En pausa")
        catalog.Set(
            "已恢复脚本中的自定义顺序。",
                "Se restableció el orden del script personalizado.")
        catalog.Set(
            "升序",
                "ascendiendo")
        catalog.Set(
            "降序",
                "descendiendo")
        catalog.Set(
            "已临时按“{1}”{2}排列；不会改写脚本顺序。",
                "Ordenado temporalmente por {1} ({2}); El orden del guión no se modifica.")
        catalog.Set(
            "无法恢复自定义顺序：{1}",
                "No se pudo restaurar el orden personalizado: {1}")
        catalog.Set(
            "映射顺序没有变化。",
                "El orden del mapeo no cambió.")
        catalog.Set(
            "无法启动按键录制，请重试。",
                "No se pudo iniciar la grabación de claves. Intentar otra vez.")
        catalog.Set(
            "正在录制来源按键…",
                "Grabando claves de fuente...")
        catalog.Set(
            "正在录制目标按键…",
                "Grabando claves de destino...")
        catalog.Set(
            "来源",
                "fuente")
        catalog.Set(
            "目标",
                "objetivo")
        catalog.Set(
            "正在录制{1}按键：{2}",
                "Grabación de claves {1}: {2}")
        catalog.Set(
            "已录制{1}按键：{2}",
                "Claves registradas {1}: {2}")
        catalog.Set(
            "已取消按键录制。",
                "Grabación de clave cancelada.")
        catalog.Set(
            "请先完成或取消当前按键录制。",
                "Termine o cancele la grabación actual primero.")
        catalog.Set(
            "请先录制来源按键和目标按键。",
                "Registre primero las claves de origen y de destino.")
        catalog.Set(
            "已清空新建区域。",
                "Se despejó la nueva área de mapeo.")
        catalog.Set(
            "请先选择要删除的映射。",
                "Seleccione una asignación para eliminar primero.")
        catalog.Set(
            "所选映射缺少代码块编号，无法删除。",
                "La asignación seleccionada no tiene ID de bloque y no se puede eliminar.")
        catalog.Set(
            "请先选择要暂停或恢复的映射。",
                "Seleccione una asignación para pausarla o reanudarla primero.")
        catalog.Set(
            "所选映射缺少代码块编号，无法修改状态。",
                "La asignación seleccionada no tiene ID de bloque y no puede cambiar de estado.")
        catalog.Set(
            "无法打开映射代码：{1}",
                "No se pudo abrir el código de mapeo: {1}")
        catalog.Set(
            "无法打开代码编辑器：{1}",
                "No se pudo abrir el editor de código: {1}")
        catalog.Set(
            "映射 · {1} -> {2}{3}",
                "Mapeo · {1} -> {2}{3}")
        catalog.Set(
            "全局",
                "Mundial")
        catalog.Set(
            "按键名称：{1}`n虚拟键码：{2}`n扫描码：{3}",
                "Nombre de clave: {1}`nClave virtual: {2}`nCódigo de escaneo: {3}")
        catalog.Set(
            "不适用",
                "n/a")
        catalog.Set(
            "键盘",
                "Teclado")
        catalog.Set(
            "鼠标",
                "ratón")
        catalog.Set(
            "滚轮",
                "Rueda del ratón")
        catalog.Set(
            "多媒体",
                "Medios")
        catalog.Set(
            "命名键",
                "Tecla con nombre")
        catalog.Set(
            "左侧 Ctrl",
                "Ctrl izquierdo")
        catalog.Set(
            "右侧 Ctrl",
                "Ctrl derecho")
        catalog.Set(
            "左侧 Shift",
                "Shift izquierdo")
        catalog.Set(
            "右侧 Shift",
                "Shift derecho")
        catalog.Set(
            "左侧 Alt",
                "Alt izquierda")
        catalog.Set(
            "右侧 Alt",
                "Alt derecha")
        catalog.Set(
            "左侧 Win",
                "Victoria izquierda")
        catalog.Set(
            "右侧 Win",
                "Victoria correcta")
        catalog.Set(
            "读取重映射代码区域失败：{1}",
                "No se pudo leer la región de mapeo: {1}")
        catalog.Set(
            "托管规则未应用：{1}",
                "No se aplicaron reglas administradas: {1}")
        catalog.Set(
            "无法检查现有映射：{1}",
                "No se pudieron inspeccionar las asignaciones existentes: {1}")
        catalog.Set(
            "为避免失去界面操作，来源按键不能是无修饰的鼠标左键。",
                "Un botón izquierdo del mouse sin modificar no se puede utilizar como clave fuente.")
        catalog.Set(
            "该来源按键已被现有映射占用。",
                "Esa clave fuente ya la utiliza otra asignación.")
        catalog.Set(
            "来源按键与目标按键相同，无需建立映射。",
                "El origen y el destino son idénticos; no se necesita ningún mapeo.")
        catalog.Set(
            "映射未写入脚本：{1}",
                "El mapeo no fue escrito: {1}")
        catalog.Set(
            "已写入脚本：{1} -> {2}；正在自动应用。",
                "Escrito en script: {1} -> {2}; aplicándose automáticamente.")
        catalog.Set(
            "删除映射",
                "Eliminar mapeo")
        catalog.Set(
            "映射未删除：{1}",
                "La asignación no se eliminó: {1}")
        catalog.Set(
            "已从脚本删除：{1} -> {2}；正在自动应用。",
                "Eliminado del script: {1} -> {2}; aplicándose automáticamente.")
        catalog.Set(
            "调整映射顺序",
                "Reordenar asignaciones")
        catalog.Set(
            "顺序未保存：{1}",
                "El pedido no se guardó: {1}")
        catalog.Set(
            "已按拖动结果实时更新脚本顺序。",
                "Se actualizó el orden del script a partir del resultado arrastrado.")
        catalog.Set(
            "暂停映射",
                "Pausar mapeo")
        catalog.Set(
            "恢复映射",
                "Reanudar mapeo")
        catalog.Set(
            "映射状态未修改：{1}",
                "El estado del mapeo no fue cambiado: {1}")
        catalog.Set(
            "已恢复映射：{1} -> {2}；正在自动应用。",
                "Mapeo reanudado: {1} -> {2}; aplicándose automáticamente.")
        catalog.Set(
            "已暂停映射：{1} -> {2}；正在自动应用。",
                "Mapeo en pausa: {1} -> {2}; aplicándose automáticamente.")
        catalog.Set(
            "映射代码未保存：{1}",
                "El código de mapeo no se guardó: {1}")
        catalog.Set(
            "映射代码未新增：{1}",
                "No se agregó el código de mapeo: {1}")
        catalog.Set(
            "未保存：{1}",
                "No guardado: {1}")
        catalog.Set(
            "已保存映射代码：{1} -> {2}；正在自动应用。",
                "Código de mapeo guardado: {1} -> {2}; aplicándose automáticamente.")
        catalog.Set(
            "已新增映射代码：{1} -> {2}；正在自动应用。",
                "Código de mapeo agregado: {1} -> {2}; aplicándose automáticamente.")
        catalog.Set(
            "无法创建空白映射代码：{1}",
                "No se pudo crear un código de asignación en blanco: {1}")
        catalog.Set(
            "无法打开设置：{1}",
                "No se pudo abrir la configuración: {1}")
        catalog.Set(
            "设置未保存：{1}",
                "La configuración no se guardó: {1}")
        catalog.Set(
            "界面内容字体",
                "fuente de interfaz de usuario")
        catalog.Set(
            "撤销失败：{1}",
                "Error al deshacer: {1}")
        catalog.Set(
            "重做失败：{1}",
                "Rehacer falló: {1}")
        catalog.Set(
            "已撤销：{1}",
                "Deshecho: {1}")
        catalog.Set(
            "已重做：{1}",
                "Rehecho: {1}")
        catalog.Set(
            "映射配置",
                "Configuración de mapeo")
        catalog.Set(
            "{1} 条重映射正在生效 · 当前为脚本代码顺序",
                "{1} asignaciones activas · orden de script personalizado")
        catalog.Set("键鼠重映射小助手设置",
            "Configuración del asistente de reasignación de teclado y ratón")
        catalog.Set("通用",
            "General")
        catalog.Set("关于",
            "Acerca de")
        catalog.Set("启动时显示主窗口",
            "Mostrar la ventana principal al iniciar")
        catalog.Set("单独按 Esc 时取消录制",
            "Pulsar solo Esc para cancelar la grabación")
        catalog.Set("事件缓冲区容量（条）：",
            "Capacidad del búfer de eventos:")
        catalog.Set("事件查看器自动跟随最新事件",
            "Seguir automáticamente los eventos más recientes")
        catalog.Set("让每一条键鼠映射都可录制、可审阅、可掌控",
            "Graba, revisa y controla cada reasignación de teclado y ratón")
        catalog.Set("当前版本",
            "Versión actual")
        catalog.Set("运行环境",
            "Entorno de ejecución")
        catalog.Set("查看最新版本",
            "Ver la última versión")
        catalog.Set("开源地址",
            "Repositorio de código abierto")
        catalog.Set("“{1}”必须是 {2} 到 {3} 之间的整数。",
            "“{1}” debe ser un entero entre {2} y {3}.")
        catalog.Set("事件缓冲区容量",
            "Capacidad del búfer de eventos")
        catalog.Set("未知版本",
            "Versión desconocida")
        catalog.Set("{1}（EXE 版）",
            "{1} (versión EXE)")
        catalog.Set("{1}（源码版）",
            "{1} (versión de código fuente)")
        catalog.Set("设置没有变化。",
            "No hay cambios en la configuración.")
        catalog.Set("设置已保存并已应用。",
            "Configuración guardada y aplicada.")
        catalog.Set("设置",
            "Configuración")
        catalog.Set("Esc 取消录制",
            "Esc cancela la grabación")
        catalog.Set("事件自动跟随",
            "Seguir los eventos más recientes")
        catalog.Set("录制", "Grabación")
        catalog.Set("事件", "Eventos")
        catalog.Set("{1}（便携版）", "{1} (versión portátil)")
        catalog.Set("帮助信息", "Ayuda")
        catalog.Set("捐赠", "Donar")
        catalog.Set("使用说明", "Guía de uso")
        catalog.Set("提交反馈", "Enviar comentarios")
        catalog.Set("支持开源项目", "Apoyar el proyecto de código abierto")
        catalog.Set("微信支付", "WeChat Pay")
        catalog.Set("支付宝", "Alipay")
        catalog.Set("二维码图片未找到", "No se encontró la imagen del código QR")
        catalog.Set("如果这个项目为您带来了帮助，欢迎通过下方二维码支持作者！`n键鼠重映射小助手将持续保持开源，项目的长期维护有赖于您的支持和鼓励。", "Si este proyecto le ha resultado útil, puede apoyar al autor mediante los códigos QR de abajo.`nEl asistente de reasignación de teclado y ratón seguirá siendo de código abierto; su apoyo ayuda a mantener el proyecto a largo plazo.")
        catalog.Set("无法打开帮助信息：{1}", "No se pudo abrir Ayuda: {1}")
        catalog.Set("无法打开使用说明：{1}", "No se pudo abrir la guía de uso: {1}")
        catalog.Set("无法打开捐赠窗口：{1}", "No se pudo abrir la ventana de donación: {1}")
        catalog.Set("无法打开反馈页面：{1}", "No se pudo abrir la página de comentarios: {1}")
        catalog.Set("键鼠重映射小助手用于录制、审阅和维护键盘与鼠标映射。关闭主窗口只会隐藏到系统托盘，已经启用的映射仍会继续生效。", "El asistente de reasignación de teclado y ratón permite grabar, revisar y mantener asignaciones de teclado y ratón. Al cerrar la ventana principal solo se oculta en la bandeja del sistema; las asignaciones activadas siguen funcionando.")
        catalog.Set("一、快速上手", "1. Inicio rápido")
        catalog.Set("• 点击顶部“新增”，会打开已经填好元数据字段的 @mapping 编辑器；也可以在下方分别录制来源按键和目标按键，填写设计目的后保存。", "• Seleccione Añadir en la barra superior para abrir un editor @mapping con los campos de metadatos ya preparados. También puede grabar abajo la entrada de origen y la de destino, indicar su propósito y guardar.")
        catalog.Set("• 录制会实时显示原始规范名称、阅读友好名称、虚拟键码和扫描码，并区分左右 Ctrl、Shift、Alt、Win 以及键盘、鼠标和滚轮输入。", "• La grabación muestra en tiempo real el nombre canónico, el nombre legible, el código de tecla virtual y el código de exploración. Distingue Ctrl, Shift, Alt y Win izquierdos y derechos, además del teclado, el ratón y la rueda.")
        catalog.Set("• 同时按下的任意按键会组成一次录制；所有按键释放后结束。录制期间再次点击录制按钮会取消本次录制，不会把该次点击记为 LButton。", "• Cualquier tecla mantenida al mismo tiempo forma una grabación, que termina al soltar todas las teclas. Volver a pulsar el botón de grabación cancela la operación en vez de registrar ese clic como LButton.")
        catalog.Set("二、主界面与代码编辑", "2. Ventana principal y edición de código")
        catalog.Set("• 单击选择映射；双击条目、悬停时按 F2 或使用右键菜单，可编辑完整 @mapping 代码块。", "• Seleccione una asignación con un clic. Haga doble clic en una fila, pulse F2 al señalarla o use el menú contextual para editar el bloque @mapping completo.")
        catalog.Set("• 选中条目后可暂停、恢复或删除；直接拖动列表行可调整永久顺序，脚本中的代码块顺序会实时同步。", "• Una asignación seleccionada se puede pausar, reanudar o eliminar. Arrastre las filas para cambiar el orden permanente; el orden de los bloques del script se sincroniza de inmediato.")
        catalog.Set("• 点击伪表头只进行临时排序；字段按升序、降序、自定义顺序循环，序号列按降序、自定义顺序循环，不会改写脚本。", "• La ordenación de los encabezados simulados es temporal. Los campos alternan entre orden ascendente, descendente y personalizado; la columna de número alterna entre descendente y personalizado. No se reescribe el script.")
        catalog.Set("• 映射区域只保存注释化 RuleSpec v2，是映射的唯一持久来源。GUI 创建或编辑的托管规则会直接热应用；可执行 AHK 代码不会被接受。", "• La región de asignaciones solo almacena RuleSpec v2 comentadas y es la única fuente persistente. Las reglas administradas creadas o editadas en la interfaz se aplican en caliente; se rechaza el código AHK ejecutable.")
        catalog.Set("四、事件、历史与界面设置", "4. Eventos, historial y apariencia")
        catalog.Set("• 事件查看器记录输入、规则匹配、条件拒绝、执行结果、仓储和系统事件，支持筛选、暂停、清空及 JSONL 导出。", "• El Visor de eventos registra entradas, coincidencias de reglas, rechazos por condiciones, resultados de ejecución, actividad del repositorio y eventos del sistema. Permite filtrar, pausar, borrar y exportar JSONL.")
        catalog.Set("五、后台运行与问题排查", "5. Ejecución en segundo plano y solución de problemas")
        catalog.Set("• 主窗口关闭后程序仍驻留托盘。托盘可以重新显示主界面、手动重新加载或彻底退出；修改映射规则后通常不需要手动重新加载。", "• La aplicación permanece en la bandeja al cerrar la ventana principal. Desde la bandeja puede mostrarla, recargarla manualmente o salir por completo; los cambios en las reglas normalmente no requieren una recarga manual.")
        catalog.Set("• 映射对管理员程序无效时，请从托盘选择以管理员身份重新启动。遇到规则冲突或按键未按预期执行时，先在事件查看器中核对输入和规则结果。", "• Si una asignación no afecta a una aplicación elevada, reinicie esta aplicación como administrador desde la bandeja. Ante conflictos o entradas inesperadas, compruebe primero las entradas y los resultados de las reglas en el Visor de eventos.")
        catalog.Set("• “帮助信息”还可打开项目反馈页面。提交问题时请说明系统版本、复现步骤、相关 @mapping 代码和事件导出，并在公开前移除敏感路径或应用信息。", "• Ayuda también abre la página de comentarios del proyecto. Al informar de un problema, incluya la versión de Windows, los pasos de reproducción, el código @mapping relacionado y una exportación de eventos; elimine antes de publicar rutas o datos de aplicaciones confidenciales.")
        catalog.Set("安全模式：已停用所有映射和输入观察。连续启动失败 {1} 次。", "Modo seguro: se desactivaron todas las asignaciones y la observación de entrada tras {1} fallos de inicio consecutivos.")
        catalog.Set("恢复最后正常配置", "Restaurar la última configuración válida")
        catalog.Set("没有可恢复的最后正常配置。", "No hay una última configuración válida disponible.")
        catalog.Set("最后正常配置恢复失败：{1}", "No se pudo restaurar la última configuración válida: {1}")
        catalog.Set("最后正常配置已恢复，正在自动应用。", "Se restauró la última configuración válida y se está aplicando automáticamente.")
        catalog.Set("仅勾选的规则会被导入。", "Solo se importarán las reglas seleccionadas.")
        catalog.Set("三、规则与生效范围", "3. Reglas y ámbito")
        catalog.Set("• 所有规则属于同一全局规则集；生效范围和条件可在 @mapping 编辑器中精确调整，保存后会立即重新选择生效规则。", "• Todas las reglas pertenecen a un único conjunto global. El ámbito y las condiciones se pueden ajustar con precisión en el editor @mapping; al guardar se vuelven a seleccionar de inmediato las reglas activas.")
        catalog.Set("• Ctrl+Z 撤销，Ctrl+Shift+Z 或 Ctrl+Y 重做。映射增删、暂停恢复、拖动排序、代码编辑和设置修改都会进入持久历史。", "• Ctrl+Z deshace; Ctrl+Shift+Z o Ctrl+Y rehace. Las altas, eliminaciones, pausas, reanudaciones, reordenaciones, ediciones de código y cambios de configuración se guardan en el historial persistente.")
        return catalog
    }
}
