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
            "删除",
                "Eliminar")
        catalog.Set(
            "暂停",
                "Pausar")
        catalog.Set(
            "恢复",
                "Reanudar")
        catalog.Set("反转状态", "Invertir estado")
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
            "名称",
                "Nombre")
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
        catalog.Set("规则块", "Regla normal")
        catalog.Set("受托管脚本", "Script administrado")
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
            "事件查看",
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
            "规则包导入完成：新增 {1}，替换 {2}，重命名 {3}，跳过 {4}。",
                "Importación completa: {1} agregado, {2} reemplazado, {3} renombrado, {4} omitido.")
        catalog.Set("导入规则包预览", "Vista previa de importación del paquete")
        catalog.Set("来源：{1} · 版本：{2}", "Origen: {1} · Versión: {2}")
        catalog.Set("共 {1} 条规则，默认选中 {2} 条；权限：{3}", "{1} reglas; {2} seleccionadas. Permisos: {3}")
        catalog.Set("模式", "Modo")
        catalog.Set("权限", "Permisos")
        catalog.Set("全选", "Seleccionar todo")
        catalog.Set("全部取消", "Quitar selección")
        catalog.Set("导入所选", "Importar selección")
        catalog.Set("无额外权限", "Sin permisos adicionales")
        catalog.Set("生成键鼠输入", "Generar entrada de teclado y ratón")
        catalog.Set("控制活动窗口", "Controlar la ventana activa")
        catalog.Set("执行系统控制", "Ejecutar un control del sistema")
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
            "系统事件",
                "Sistema")
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
            "退出程序",
                "Salir del programa")
        catalog.Set(
            "设置",
                "Configuración")
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
        catalog.Set("无法启动按键录制：{1}", "No se pudo iniciar la grabación de teclas: {1}")
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
            "所选映射缺少名称，无法删除。",
                "La asignación seleccionada no tiene nombre y no se puede eliminar.")
        catalog.Set(
            "请先选择要暂停或恢复的映射。",
                "Seleccione una asignación para pausarla o reanudarla primero.")
        catalog.Set(
            "所选映射缺少名称，无法修改状态。",
                "La asignación seleccionada no tiene nombre y no puede cambiar de estado.")
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
            "为避免失去界面操作，来源按键不能是无修饰的鼠标左键。",
                "Un botón izquierdo del mouse sin modificar no se puede utilizar como clave fuente.")
        catalog.Set(
            "映射未写入脚本：{1}",
                "El mapeo no fue escrito: {1}")
        catalog.Set(
            "已写入脚本：{1} -> {2}；已应用。",
                "Escrito en el script: {1} -> {2}; aplicado.")
        catalog.Set(
            "映射未删除：{1}",
                "La asignación no se eliminó: {1}")
        catalog.Set(
            "已从脚本删除：{1} -> {2}；已应用。",
                "Eliminado del script: {1} -> {2}; aplicado.")
        catalog.Set(
            "顺序未保存：{1}",
                "El pedido no se guardó: {1}")
        catalog.Set(
            "已按拖动结果实时更新脚本顺序。",
                "Se actualizó el orden del script a partir del resultado arrastrado.")
        catalog.Set(
            "映射状态未修改：{1}",
                "El estado del mapeo no fue cambiado: {1}")
        catalog.Set(
            "已恢复映射：{1} -> {2}；已应用。",
                "Mapeo reanudado: {1} -> {2}; aplicado.")
        catalog.Set(
            "已暂停映射：{1} -> {2}；已应用。",
                "Mapeo en pausa: {1} -> {2}; aplicado.")
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
            "已保存映射代码：{1} -> {2}；已应用。",
                "Código de mapeo guardado: {1} -> {2}; aplicado.")
        catalog.Set(
            "已新增映射代码：{1} -> {2}；已应用。",
                "Código de mapeo agregado: {1} -> {2}; aplicado.")
        catalog.Set("已保存，正在后台应用…", "Guardado; aplicando en segundo plano...")
        catalog.Set("受托管脚本已应用。", "Script administrado aplicado.")
        catalog.Set("映射代码没有变化。", "El código de mapeo no cambió.")
        catalog.Set("映射代码已保存，但受托管脚本应用失败：{1}",
            "El código de mapeo se guardó, pero no se pudo aplicar el script administrado: {1}")
        catalog.Set(
            "无法创建空白映射代码：{1}",
                "No se pudo crear un código de asignación en blanco: {1}")
        catalog.Set(
            "设置未保存：{1}",
                "La configuración no se guardó: {1}")
        catalog.Set(
            "{1} 条重映射正在生效 · 当前为脚本代码顺序",
                "{1} asignaciones activas · orden de script personalizado")
        catalog.Set("键鼠重映射小助手设置",
            "Configuración del asistente de reasignación de teclado y ratón")
        catalog.Set("启动",
            "Inicio")
        catalog.Set("显示",
            "Visualización")
        catalog.Set("规则与事件",
            "Reglas y eventos")
        catalog.Set("关于",
            "Acerca de")
        catalog.Set("事件缓冲区容量（条）：",
            "Capacidad del búfer de eventos:")
        catalog.Set("事件查看自动跟随最新事件",
            "Seguir automáticamente los eventos más recientes")
        catalog.Set("让每一条键鼠映射都可录制、可审阅、可掌控",
            "Graba, revisa y controla cada reasignación de teclado y ratón")
        catalog.Set("当前版本",
            "Versión actual")
        catalog.Set("运行环境",
            "Entorno de ejecución")
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
        catalog.Set("设置已保存并已应用。",
            "Configuración guardada y aplicada.")
        catalog.Set("Esc 取消录制",
            "Esc cancela la grabación")
        catalog.Set("{1}（便携版）", "{1} (versión portátil)")
        catalog.Set("快揭不开锅了（≥Д≤）",
            "Ya casi no queda presupuesto（≥Д≤）")
        catalog.Set("使用说明", "Guía de uso")
        catalog.Set("提交反馈", "Enviar comentarios")
        catalog.Set("支持开源项目", "Apoyar el proyecto de código abierto")
        catalog.Set("微信支付", "WeChat Pay")
        catalog.Set("支付宝", "Alipay")
        catalog.Set("二维码图片未找到", "No se encontró la imagen del código QR")
        catalog.Set("如果小助手为您节省了配置键鼠映射的时间，欢迎通过下方二维码打赏作者！`n请选择扶贫方式（≥Д≤）", "Si el asistente le ha ahorrado tiempo al configurar mapeos de teclado y ratón, puede apoyar al autor mediante los códigos QR de abajo.`nElija cómo desea colaborar (≥Д≤)")
        catalog.Set("无法打开反馈页面：{1}", "No se pudo abrir la página de comentarios: {1}")
        catalog.Set("键鼠重映射小助手用于录制、审阅和维护键盘与鼠标映射。关闭主窗口只会隐藏到系统托盘，已经启用的映射仍会继续生效。", "El asistente de reasignación de teclado y ratón permite grabar, revisar y mantener asignaciones de teclado y ratón. Al cerrar la ventana principal solo se oculta en la bandeja del sistema; las asignaciones activadas siguen funcionando.")
        catalog.Set("一、快速上手", "1. Inicio rápido")
        catalog.Set("• 点击顶部“新增”，会打开已经填好元数据字段的 @mapping 编辑器；也可以在下方分别录制来源按键和目标按键，填写名称后保存。", "• Seleccione Añadir en la barra superior para abrir un editor @mapping con los campos de metadatos ya preparados. También puede grabar abajo la entrada de origen y la de destino, indicar un nombre y guardar.")
        catalog.Set("• 录制会实时显示原始规范名称、阅读友好名称、虚拟键码和扫描码，并区分左右 Ctrl、Shift、Alt、Win 以及键盘、鼠标和滚轮输入。", "• La grabación muestra en tiempo real el nombre canónico, el nombre legible, el código de tecla virtual y el código de exploración. Distingue Ctrl, Shift, Alt y Win izquierdos y derechos, además del teclado, el ratón y la rueda.")
        catalog.Set("二、主界面与代码编辑", "2. Ventana principal y edición de código")
        catalog.Set("• 单击选择映射；双击条目、选中后按 F2 或使用右键菜单，可编辑完整 @mapping 代码块。", "• Seleccione una asignación con un clic. Haga doble clic en una fila, pulse F2 con la fila seleccionada o use el menú contextual para editar el bloque @mapping completo.")
        catalog.Set("• 选中条目后可暂停、恢复或删除；直接拖动列表行可调整永久顺序，脚本中的代码块顺序会实时同步。", "• Una asignación seleccionada se puede pausar, reanudar o eliminar. Arrastre las filas para cambiar el orden permanente; el orden de los bloques del script se sincroniza de inmediato.")
        catalog.Set("• 点击伪表头只进行临时排序；字段按升序、降序、自定义顺序循环，序号列按降序、自定义顺序循环，不会改写脚本。", "• La ordenación de los encabezados simulados es temporal. Los campos alternan entre orden ascendente, descendente y personalizado; la columna de número alterna entre descendente y personalizado. No se reescribe el script.")
        catalog.Set("• 事件查看记录输入、规则匹配、条件拒绝、执行结果、仓储和系统事件，支持筛选、暂停、清空及 JSONL 导出。", "• El Visor de eventos registra entradas, coincidencias de reglas, rechazos por condiciones, resultados de ejecución, actividad del repositorio y eventos del sistema. Permite filtrar, pausar, borrar y exportar JSONL.")
        catalog.Set("四、事件查看与设置", "4. Visor de eventos y configuración")
        catalog.Set("五、后台运行与问题排查", "5. Ejecución en segundo plano y solución de problemas")
        catalog.Set("• 主窗口关闭后程序仍驻留托盘。托盘可以重新显示主界面、手动重新加载或彻底退出；修改映射规则后通常不需要手动重新加载。", "• La aplicación permanece en la bandeja al cerrar la ventana principal. Desde la bandeja puede mostrarla, recargarla manualmente o salir por completo; los cambios en las reglas normalmente no requieren una recarga manual.")
        catalog.Set("仅勾选的规则会被导入。", "Solo se importarán las reglas seleccionadas.")
        catalog.Set("三、规则与生效范围", "3. Reglas y ámbito")
        catalog.Set("• 所有规则属于同一全局规则集；生效范围和条件可在 @mapping 编辑器中精确调整，保存后会立即重新选择生效规则。", "• Todas las reglas pertenecen a un único conjunto global. El ámbito y las condiciones se pueden ajustar con precisión en el editor @mapping; al guardar se vuelven a seleccionar de inmediato las reglas activas.")
        catalog.Set("没有可撤销的映射变更。", "No hay cambios de asignación que deshacer.")
        catalog.Set("已撤销上一步映射变更。", "Se deshizo el último cambio de asignación.")
        catalog.Set("撤销映射变更失败：{1}", "No se pudo deshacer el cambio de asignación: {1}")
        catalog.Set("没有可重做的映射变更。", "No hay cambios de asignación que rehacer.")
        catalog.Set("已重做映射变更。", "Se rehízo el cambio de asignación.")
        catalog.Set("重做映射变更失败：{1}", "No se pudo rehacer el cambio de asignación: {1}")
        catalog.Set("录制结束后无法恢复重映射：{1}", "No se pudo reanudar la reasignación tras la grabación: {1}")
        catalog.Set("• 新增、删除、暂停或恢复、代码编辑、拖动排序和规则包导入均可撤销；Ctrl+Z 撤销，Ctrl+Shift+Z 或 Ctrl+Y 重做。", "• Se pueden deshacer la adición, eliminación, pausa o reanudación, edición de código, reordenación mediante arrastre e importación de paquetes de reglas. Use Ctrl+Z para deshacer y Ctrl+Shift+Z o Ctrl+Y para rehacer.")
        catalog.Set("开机自动启动（计划任务）", "Inicio automático al encender（tarea programada）")
        catalog.Set("检查更新失败：{1}", "No se pudieron buscar actualizaciones: {1}")
        catalog.Set("启动时显示主窗口", "Mostrar la ventana principal al iniciar")
        catalog.Set("更新检查正在进行，请稍候。", "Hay una búsqueda de actualizaciones en curso. Espere.")
        catalog.Set("关闭", "Desactivar")
        catalog.Set("将下载并校验源码发行包，保留个人配置后替换源码并自动重启。", "Se descargará y verificará el paquete de código fuente. Después se sustituirá el código y se reiniciará automáticamente, conservando la configuración personal.")
        catalog.Set("桌面与开始菜单快捷方式", "Accesos directos del escritorio y del menú Inicio")
        catalog.Set("创建", "Crear")
        catalog.Set("无法检查更新：{1}", "No se pudo buscar actualizaciones: {1}")
        catalog.Set("提示", "Aviso")
        catalog.Set("检测到同名计划任务，但它并非当前程序创建；为避免误删，请先在任务计划程序中处理它。", "Se detectó una tarea programada con el mismo nombre, pero no fue creada por este programa. Para evitar borrarla por error, gestiónela primero en el Programador de tareas.")
        catalog.Set("立即更新", "Actualizar ahora")
        catalog.Set("错误", "Error")
        catalog.Set("创建成功！", "¡Creados!")
        catalog.Set("无法建立单实例运行锁，小助手将退出。", "No se pudo obtener el bloqueo de instancia única`; el asistente se cerrará.")
        catalog.Set("重新加载失败，已保留当前实例：{1}", "No se pudo recargar`; se ha conservado la instancia actual: {1}")
        catalog.Set("稍后", "Más tarde")
        catalog.Set("切换", "Cambiar")
        catalog.Set("冲突", "Conflicto")
        catalog.Set("将确认源码仓库没有未提交修改，再快速前进到正式发布标签并自动重启。", "Se comprobará que el repositorio de código fuente no tenga cambios sin confirmar`; después se avanzará directamente hasta la etiqueta de publicación oficial y se reiniciará automáticamente.")
        catalog.Set("无法开始更新：{1}", "No se pudo iniciar la actualización: {1}")
        catalog.Set("正在检查更新…", "Buscando actualizaciones…")
        catalog.Set("检查更新", "Buscar actualizaciones")
        catalog.Set("小助手更新", "Actualización del asistente")
        catalog.Set("将下载并校验完整发行包，退出小助手后替换程序文件并自动重启。", "Se descargará y verificará el paquete de distribución completo. Después de cerrar el asistente, se sustituirán los archivos del programa y se reiniciará automáticamente.")
        catalog.Set("创建快捷方式失败：{1}", "No se pudo crear el acceso directo: {1}")
        catalog.Set("当前陪伴您的已经是最新版本的小助手啦！", "¡El asistente que te acompaña ya está actualizado a la última versión!")
        catalog.Set("确定", "Aceptar")
        catalog.Set("没有可安装的应用更新", "No hay ninguna actualización de la aplicación para instalar")
        catalog.Set("更新检查未返回结果", "La búsqueda de actualizaciones no devolvió ningún resultado")
        catalog.Set("开启", "Activar")
        catalog.Set("不可用", "No disponible")
        catalog.Set("启动失败", "No se pudo iniciar")
        catalog.Set("启动时检查小助手更新", "Buscar actualizaciones del asistente al iniciar")
        catalog.Set("以管理员身份运行", "Ejecutar como administrador")
        catalog.Set("操作计划任务时发生错误：{1}", "Se produjo un error al operar la tarea programada: {1}")
        catalog.Set("发现新版本 {1}，当前版本为 {2}。`n`n{3}`n`n是否立即更新？", "Hay una nueva versión {1}; la versión actual es {2}.`n`n{3}`n`n¿Actualizar ahora?")
        catalog.Set("开机自动启动", "Iniciar automáticamente al iniciar sesión")
        catalog.Set("输入录制不可用：{1}", "La grabación de entradas no está disponible: {1}")
        catalog.Set("新脚本未通过 AutoHotkey 启动验证。", "El nuevo script no superó la verificación de inicio de AutoHotkey.")
        catalog.Set("保存并运行", "Guardar y ejecutar")
        catalog.Set("导入并运行", "Importar y ejecutar")
        catalog.Set("导入自定义 AHK 代码", "Importar código AHK personalizado")
        catalog.Set("继续", "Continuar")
        catalog.Set("切换规则类型", "Cambiar tipo de regla")
        catalog.Set("切换规则类型会清空当前未保存内容，是否继续？", "Cambiar el tipo de regla borrará el contenido actual no guardado. ¿Continuar?")
        catalog.Set("所选规则包含可读写文件、启动程序、控制窗口和请求管理员权限的自定义 AHK 代码。确认导入并运行吗？", "Las reglas seleccionadas contienen código AHK personalizado que puede leer y escribir archivos, iniciar programas, controlar ventanas y solicitar privilegios de administrador. ¿Importarlo y ejecutarlo?")
        catalog.Set("无法创建规则模板：{1}", "No se pudo crear la plantilla de regla: {1}")
        catalog.Set("运行自定义 AHK 代码", "Ejecutar código AHK personalizado")
        catalog.Set("自定义 AHK 代码可读取文件、启动程序、控制窗口并请求管理员权限。确认运行当前代码吗？", "El código AHK personalizado puede leer y escribir archivos, iniciar programas, controlar ventanas y solicitar privilegios de administrador. ¿Ejecutar este código?")
        catalog.Set("规则未应用：{1}", "No se aplicaron las reglas: {1}")
        catalog.Set("• 映射区域以注释形式保存规则块和受托管脚本。规则块在主进程热应用；受托管脚本的自定义 AHK v2 源码在独立受管进程运行，保存、暂停、恢复、删除和退出均由小助手统一管理。", "• La región de asignaciones guarda bloques de regla normales y scripts administrados como comentarios. Los bloques normales se aplican en el proceso principal. El código AutoHotkey v2 personalizado se ejecuta en un proceso administrado independiente controlado por el asistente.")
        catalog.Set("区分左右修饰键", "Distinguir modificadores izquierdos/derechos")
        catalog.Set("帮助", "Ayuda")
        catalog.Set("打赏", "Donar")
        catalog.Set("打开帮助`n可选择查看使用说明、运行日志或提交反馈", "Abrir Ayuda`nElige la guía de uso, el registro de ejecución o el envío de comentarios")
        catalog.Set("点个 star 吧~", "Regálanos una estrellita~")
        catalog.Set("配置显示、规则包和事件选项", "Configurar visualización, paquetes de reglas y eventos")
        catalog.Set("查看版本、运行环境和项目入口", "Ver versión, entorno de ejecución y enlaces del proyecto")
        catalog.Set("找作者对线", "Habla con el autor")
        catalog.Set("演奏你的和弦！", "¡Toca tu acorde!")
        catalog.Set("• “帮助”还可打开项目反馈页面。提交问题时请说明系统版本、复现步骤、相关 @mapping 代码和事件导出，并在公开前移除敏感路径或应用信息。", "• Ayuda también abre la página de comentarios del proyecto. Al informar de un problema, incluya la versión de Windows, los pasos de reproducción, el código @mapping relacionado y una exportación de eventos; elimine antes de publicar rutas o datos de aplicaciones confidenciales.")
        catalog.Set("AI 设置", "AI settings")
        catalog.Set("API 地址：", "Dirección de API:")
        catalog.Set("API 密钥：", "Clave de API:")
        catalog.Set("模型名称：", "Nombre del modelo:")
        catalog.Set("请求超时（秒）：", "Request timeout (seconds):")
        catalog.Set("请求超时（秒）", "Request timeout (seconds)")
        catalog.Set("提示词：", "Indicaciones:")
        catalog.Set("生成", "Generar")
        catalog.Set("优化", "Optimizar")
        catalog.Set("系统说明", "Instrucciones del sistema")
        catalog.Set("编辑", "Edit")
        catalog.Set("AI 提示词", "AI prompts")
        catalog.Set("生成提示词不能为空。", "Generation prompt cannot be empty.")
        catalog.Set("优化提示词不能为空。", "Optimization prompt cannot be empty.")
        catalog.Set("恢复默认", "Restore default")
        catalog.Set("系统说明不能为空。", "System instructions cannot be empty.")
        catalog.Set("生成重映射规则", "Generate remapping rule")
        catalog.Set("优化当前规则", "Optimize current rule")
        catalog.Set("AI 生成规则", "IA Generar regla")
        catalog.Set("设置序号圆点", "Configurar punto numérico")
        catalog.Set("清除圆点颜色", "Borrar color del punto")
        catalog.Set("雾松绿", "Verde pino brumoso")
        catalog.Set("青灰蓝", "Azul grisáceo")
        catalog.Set("薰衣草紫", "Lavanda")
        catalog.Set("烟粉", "Rosa empolvado")
        catalog.Set("浅琥珀", "Ámbar claro")
        catalog.Set("静谧青", "Verde azulado suave")
        catalog.Set("珍珠灰", "Gris perla")
        catalog.Set("已更新 {1} 条规则的序号圆点颜色。", "Se actualizó el color del punto para {1} reglas.")
        catalog.Set("序号圆点颜色未保存：{1}", "No se guardó el color del punto: {1}")
        catalog.Set("AI 优化规则", "IA Optimizar regla")
        catalog.Set("请输入规则目的。", "Introduce el propósito de la regla.")
        catalog.Set("说点什么吧，我什么都会做的 T_T", "Di lo que quieras, sé hacer de todo T_T")
        catalog.Set("我是来帮你的，你要干什么？！", "Estoy aquí para ayudarte. ¿Qué quieres hacer?!")
        catalog.Set("请先关闭当前代码编辑器，再优化其他映射。", "Cierra el editor de código actual antes de optimizar otra asignación.")
        catalog.Set("AI 服务尚未初始化。", "The AI service is not initialized.")
        catalog.Set("AI 参数未保存：{1}", "No se guardaron los parámetros de IA: {1}")
        catalog.Set("无法读取当前映射代码：{1}", "Could not read the current mapping code: {1}")
        catalog.Set("AI 正在生成规则，请稍候...", "AI is generating a rule. Please wait...")
        catalog.Set("AI 正在优化规则，请稍候...", "La IA está optimizando la regla. Espere...")
        catalog.Set("AI 请求失败，请检查 AI 设置和网络连接。", "La solicitud de IA falló. Compruebe la configuración de IA y la conexión de red.")
        catalog.Set("测试连接", "Probar conexión")
        catalog.Set("正在测试 AI 连接…", "Probando la conexión con la IA…")
        catalog.Set("AI 连接测试成功。", "La prueba de conexión con la IA se completó correctamente.")
        catalog.Set("AI 连接测试失败：{1}", "La prueba de conexión con la IA falló: {1}")
        catalog.Set("请填写 API 地址。", "Introduzca la dirección de la API.")
        catalog.Set("请填写模型名称。", "Introduzca el nombre del modelo.")
        catalog.Set("请求期间编辑器内容已变化，请重新执行 AI 操作。", "The editor changed during the request. Run the AI operation again.")
        catalog.Set("AI 规则已放入编辑器，请检查后保存。", "The AI rule is in the editor. Review it before saving.")
        catalog.Set("状态", "Estado")
        catalog.Set("启用", "Activada")
        catalog.Set("无法读取设置文件，已使用默认设置：{1}", "No se pudo leer la configuración`; se usarán los valores predeterminados: {1}")
        catalog.Set("审阅 AI 优化结果", "Revisar optimización de IA")
        catalog.Set("已保留原内容，AI 结果未应用。", "Se conservó el contenido original. El resultado de la IA no se aplicó.")
        catalog.Set("AI 结果无法应用到编辑器，请重试。", "No se pudo aplicar el resultado de la IA al editor. Inténtalo de nuevo.")
        catalog.Set("无法打开 AI 结果审阅：{1}", "No se pudo abrir la revisión del resultado de la IA: {1}")
        catalog.Set("当前 {1} 行，AI 建议 {2} 行；约 {3} 行有变化。", "Actual: {1} líneas`; sugerencia de IA: {2} líneas`; unas {3} líneas cambiaron.")
        catalog.Set("当前内容", "Contenido actual")
        catalog.Set("AI 建议", "Sugerencia de IA")
        catalog.Set("接受结果", "Aceptar resultado")
        catalog.Set("保留原文", "Conservar original")
        catalog.Set("AI 返回的规则经过自动修复后仍未通过本地校验：{1}", "La regla de IA aún no superó la validación local después de la reparación automática: {1}")
        catalog.Set("AI 规则校验结果不完整。", "El resultado de validación de la regla de IA está incompleto.")
        catalog.Set("AI 正在复核规则的实际行为，请稍候...", "La IA está revisando el comportamiento real de la regla. Espera...")
        catalog.Set("AI 正在根据本地校验结果修复规则，请稍候...", "La IA está reparando la regla según la validación local. Espera...")
        catalog.Set("本地校验失败：{1}", "Falló la validación local: {1}")
        catalog.Set("失败发生阶段：{1}", "Etapa del fallo: {1}")
        catalog.Set("必须修复根因并重新满足用户原始目的。", "Corrige la causa raíz y satisface por completo la intención original del usuario.")
        catalog.Set("规则块能力不足，必须改用受托管脚本完整实现。", "Un bloque de reglas estándar no es suficiente`; usa un script administrado para la implementación completa.")
        catalog.Set("未保存：请先用完整的 AHK v2 脚本替换代码占位文字。", "No guardado: primero reemplaza el marcador de código por un script AHK v2 completo.")
        catalog.Set("当前等待时间：{1} 秒", "Current wait time: {1} seconds")
        return catalog
    }
}
