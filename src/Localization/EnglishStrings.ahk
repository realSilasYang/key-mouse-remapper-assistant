; en-US 本地化词条目录。
; 简体中文原文是稳定键；本目录与其它语言保持完全相同的键集合。

class EnglishStrings {
    static Create() {
        catalog := Map()
        catalog.CaseSense := "On"
        catalog.Set("按下", "Press")
        catalog.Set(
            "键鼠重映射小助手",
                "Keyboard & Mouse Remapper Assistant")
        catalog.Set(
            "新增",
                "Add")
        catalog.Set(
            "新增映射",
                "Add mapping")
        catalog.Set(
            "删除",
                "Delete")
        catalog.Set(
            "暂停",
                "Pause")
        catalog.Set(
            "恢复",
                "Resume")
        catalog.Set(
            "序号",
                "No.")
        catalog.Set(
            "来源按键",
                "Source key")
        catalog.Set(
            "映射结果",
                "Mapped result")
        catalog.Set(
            "生效范围",
                "Scope")
        catalog.Set(
            "设计目的",
                "Purpose")
        catalog.Set(
            "新建映射",
                "New mapping")
        catalog.Set(
            "映射为",
                "Map to")
        catalog.Set(
            "点击录制来源按键",
                "Click to record source keys")
        catalog.Set(
            "点击录制目标按键",
                "Click to record target keys")
        catalog.Set(
            "保存映射",
                "Save mapping")
        catalog.Set(
            "清空",
                "Clear")
        catalog.Set(
            "准备就绪",
                "Ready")
        catalog.Set(
            "请按下按键 · Esc 取消",
                "Press keys · Esc to cancel")
        catalog.Set(
            "编辑映射代码",
                "Edit mapping code")
        catalog.Set(
            "新增映射代码",
                "Add mapping code")
        catalog.Set(
            "元数据说明",
                "Metadata reference")
        catalog.Set(
            "RuleSpec 外壳版本，当前必须为 2。",
                "RuleSpec envelope version; it must currently be 2.")
        catalog.Set(
            "规则模式，当前必须为 managed。",
                "Rule mode; it must currently be managed.")
        catalog.Set(
            "映射的唯一编号，必须与 RuleSpec 的 id 一致。",
                "Unique mapping ID; it must match the RuleSpec id.")
        catalog.Set(
            "结构化 RuleSpec JSON 的开始标记。",
                "Start marker for the structured RuleSpec JSON.")
        catalog.Set(
            "注释化 JSON；可编辑来源、条件、显示信息和输出动作。",
                "Commented JSON; edit the source, conditions, display data, and output actions.")
        catalog.Set(
            "结构化 RuleSpec JSON 的结束标记。",
                "End marker for the structured RuleSpec JSON.")
        catalog.Set(
            "规范化 RuleSpec JSON 的 SHA-256 摘要。",
                "SHA-256 digest of the normalized RuleSpec JSON.")
        catalog.Set(
            "生成区只含说明注释，不包含可执行 AHK。",
                "The generated section contains explanatory comments only, with no executable AHK.")
        catalog.Set(
            "整个映射块只允许注释化 RuleSpec JSON；右侧说明仅供参考，不会保存到代码。",
                "The entire mapping block allows only commented RuleSpec JSON. This reference is display-only and is not saved.")
        catalog.Set(
            "代码修改尚未保存，确定放弃吗？",
                "The code has unsaved changes. Discard them?")
        catalog.Set(
            "放弃修改",
                "Discard changes")
        catalog.Set(
            "显示主界面",
                "Show main window")
        catalog.Set(
            "重新加载",
                "Reload")
        catalog.Set(
            "以管理员身份重新启动",
                "Restart as administrator")
        catalog.Set(
            "管理员模式（当前）",
                "Administrator mode (active)")
        catalog.Set(
            "无法以管理员身份重新启动（错误代码 {1}）。",
                "Could not restart as administrator (error {1}).")
        catalog.Set(
            "事件查看器",
                "Event Viewer")
        catalog.Set("事件详情", "Event details")
        catalog.Set("事件：{1}", "Event: {1}")
        catalog.Set("类别：{1}", "Category: {1}")
        catalog.Set("时间：{1}", "Time: {1}")
        catalog.Set("来源：{1}", "Source: {1}")
        catalog.Set("结果：{1}", "Outcome: {1}")
        catalog.Set("详情：{1}", "Details: {1}")
        catalog.Set("按键名称：{1}", "Key name: {1}")
        catalog.Set("原始观察", "Raw observation")
        catalog.Set("退出观察", "Stop observing")
        catalog.Set("原始观察中", "Raw observation active")
        catalog.Set("原始观察切换失败：{1}",
            "Could not change raw observation mode: {1}")
        catalog.Set("诊断包", "Diagnostics")
        catalog.Set("诊断包预览", "Diagnostic bundle preview")
        catalog.Set("导出诊断包", "Export diagnostic bundle")
        catalog.Set("诊断包导出失败：{1}",
            "Could not export diagnostic bundle: {1}")
        catalog.Set("诊断包已导出：{1}", "Diagnostic bundle exported: {1}")
        catalog.Set("将导出 {1} 条事件；已脱敏窗口标题 {2}、路径 {3}、文本/命令 {4}、代码 {5}、变量值 {6} 项。是否继续？",
            "Export {1} events? Redaction covers {2} window titles, {3} paths, {4} text/command values, {5} code values, and {6} variable values.")
        catalog.Set(
            "导入规则包",
                "Import rule package")
        catalog.Set(
            "导出规则包",
                "Export rule package")
        catalog.Set(
            "规则包导出失败：{1}",
                "Rule package export failed: {1}")
        catalog.Set(
            "已导出 {1} 条规则：{2}",
                "Exported {1} rules: {2}")
        catalog.Set(
            "规则包导入失败：{1}",
                "Rule package import failed: {1}")
        catalog.Set(
            "规则包导入失败，且回滚失败：{1}",
                "Rule package import and rollback failed: {1}")
        catalog.Set(
            "规则包导入完成：新增 {1}，替换 {2}，重命名 {3}，跳过 {4}。",
                "Import complete: {1} added, {2} replaced, {3} renamed, {4} skipped.")
        catalog.Set("变量", "Variables")
        catalog.Set("变量快照", "Variable snapshot")
        catalog.Set("导入规则包预览", "Rule package import preview")
        catalog.Set("来源：{1} · 版本：{2}", "Source: {1} · Version: {2}")
        catalog.Set("共 {1} 条规则，默认选中 {2} 条；权限：{3}", "{1} rules; {2} selected by default. Permissions: {3}")
        catalog.Set("规则编号", "Rule ID")
        catalog.Set("模式", "Mode")
        catalog.Set("权限", "Permissions")
        catalog.Set("全选", "Select all")
        catalog.Set("全部取消", "Clear all")
        catalog.Set("导入所选", "Import selected")
        catalog.Set("无额外权限", "No additional permissions")
        catalog.Set("请至少选择一条规则。", "Select at least one rule.")
        catalog.Set("导入失败，请查看主窗口状态。", "Import failed. See the main-window status.")
        catalog.Set(
            "筛选：",
                "Filter:")
        catalog.Set(
            "全部事件",
                "All events")
        catalog.Set(
            "输入事件",
                "Input")
        catalog.Set(
            "规则运行",
                "Runtime")
        catalog.Set(
            "规则仓储",
                "Repository")
        catalog.Set(
            "撤销历史",
                "History")
        catalog.Set(
            "系统事件",
                "System")
        catalog.Set(
            "界面事件",
                "UI")
        catalog.Set(
            "暂停刷新",
                "Pause")
        catalog.Set(
            "恢复刷新",
                "Resume")
        catalog.Set(
            "导出事件",
                "Export events")
        catalog.Set(
            "时间",
                "Time")
        catalog.Set(
            "类别",
                "Category")
        catalog.Set(
            "事件",
                "Event")
        catalog.Set(
            "来源 / 规则",
                "Source / rule")
        catalog.Set(
            "结果",
                "Outcome")
        catalog.Set(
            "详情",
                "Details")
        catalog.Set(
            "输入",
                "Input")
        catalog.Set(
            "运行时",
                "Runtime")
        catalog.Set(
            "仓储",
                "Repository")
        catalog.Set(
            "历史",
                "History")
        catalog.Set(
            "系统",
                "System")
        catalog.Set(
            "界面",
                "UI")
        catalog.Set(
            "已暂停刷新",
                "Paused")
        catalog.Set(
            "实时刷新",
                "Live")
        catalog.Set(
            "显示 {1} 条 · 缓冲区 {2}/{3} · 已丢弃 {4} 条 · {5}",
                "Showing {1} · buffer {2}/{3} · dropped {4} · {5}")
        catalog.Set(
            "事件导出失败：{1}",
                "Event export failed: {1}")
        catalog.Set(
            "事件已导出：{1}",
                "Events exported: {1}")
        catalog.Set(
            "无法打开事件查看器：{1}",
                "Could not open Event Viewer: {1}")
        catalog.Set(
            "退出程序",
                "Exit")
        catalog.Set(
            "设置",
                "Settings")
        catalog.Set(
            "界面语言",
                "UI language")
        catalog.Set(
            "主题",
                "Theme")
        catalog.Set(
            "界面语言：",
                "Language:")
        catalog.Set(
            "界面内容字体：",
                "Content font:")
        catalog.Set(
            "主题：",
                "Theme:")
        catalog.Set(
            "跟随系统",
                "Follow system")
        catalog.Set(
            "浅色",
                "Light")
        catalog.Set(
            "深色",
                "Dark")
        catalog.Set(
            "跟随语言默认（{1}）",
                "Language default ({1})")
        catalog.Set(
            "保存",
                "Save")
        catalog.Set(
            "取消",
                "Cancel")
        catalog.Set(
            "已暂停",
                "Paused")
        catalog.Set(
            "已恢复脚本中的自定义顺序。",
                "Restored the custom script order.")
        catalog.Set(
            "升序",
                "ascending")
        catalog.Set(
            "降序",
                "descending")
        catalog.Set(
            "已临时按“{1}”{2}排列；不会改写脚本顺序。",
                "Temporarily sorted by {1} ({2}); script order is unchanged.")
        catalog.Set(
            "无法恢复自定义顺序：{1}",
                "Could not restore custom order: {1}")
        catalog.Set(
            "映射顺序没有变化。",
                "The mapping order did not change.")
        catalog.Set(
            "无法启动按键录制，请重试。",
                "Could not start key recording. Try again.")
        catalog.Set(
            "正在录制来源按键…",
                "Recording source keys...")
        catalog.Set(
            "正在录制目标按键…",
                "Recording target keys...")
        catalog.Set(
            "来源",
                "source")
        catalog.Set(
            "目标",
                "target")
        catalog.Set(
            "正在录制{1}按键：{2}",
                "Recording {1} keys: {2}")
        catalog.Set(
            "已录制{1}按键：{2}",
                "Recorded {1} keys: {2}")
        catalog.Set(
            "已取消按键录制。",
                "Key recording cancelled.")
        catalog.Set(
            "请先完成或取消当前按键录制。",
                "Finish or cancel the current recording first.")
        catalog.Set(
            "请先录制来源按键和目标按键。",
                "Record both the source and target keys first.")
        catalog.Set(
            "已清空新建区域。",
                "Cleared the new mapping area.")
        catalog.Set(
            "请先选择要删除的映射。",
                "Select a mapping to delete first.")
        catalog.Set(
            "所选映射缺少代码块编号，无法删除。",
                "The selected mapping has no block ID and cannot be deleted.")
        catalog.Set(
            "请先选择要暂停或恢复的映射。",
                "Select a mapping to pause or resume first.")
        catalog.Set(
            "所选映射缺少代码块编号，无法修改状态。",
                "The selected mapping has no block ID and cannot change state.")
        catalog.Set(
            "无法打开映射代码：{1}",
                "Could not open mapping code: {1}")
        catalog.Set(
            "无法打开代码编辑器：{1}",
                "Could not open code editor: {1}")
        catalog.Set(
            "映射 · {1} -> {2}{3}",
                "Mapping · {1} -> {2}{3}")
        catalog.Set(
            "全局",
                "Global")
        catalog.Set(
            "按键名称：{1}`n虚拟键码：{2}`n扫描码：{3}",
                "Key name: {1}`nVirtual key: {2}`nScan code: {3}")
        catalog.Set(
            "不适用",
                "n/a")
        catalog.Set(
            "键盘",
                "Keyboard")
        catalog.Set(
            "鼠标",
                "Mouse")
        catalog.Set(
            "滚轮",
                "Wheel")
        catalog.Set(
            "多媒体",
                "Media")
        catalog.Set(
            "命名键",
                "Named key")
        catalog.Set(
            "左侧 Ctrl",
                "Left Ctrl")
        catalog.Set(
            "右侧 Ctrl",
                "Right Ctrl")
        catalog.Set(
            "左侧 Shift",
                "Left Shift")
        catalog.Set(
            "右侧 Shift",
                "Right Shift")
        catalog.Set(
            "左侧 Alt",
                "Left Alt")
        catalog.Set(
            "右侧 Alt",
                "Right Alt")
        catalog.Set(
            "左侧 Win",
                "Left Win")
        catalog.Set(
            "右侧 Win",
                "Right Win")
        catalog.Set(
            "读取重映射代码区域失败：{1}",
                "Could not read mapping region: {1}")
        catalog.Set(
            "托管规则未应用：{1}",
                "Managed rules were not applied: {1}")
        catalog.Set(
            "无法检查现有映射：{1}",
                "Could not inspect existing mappings: {1}")
        catalog.Set(
            "为避免失去界面操作，来源按键不能是无修饰的鼠标左键。",
                "An unmodified left mouse button cannot be used as a source key.")
        catalog.Set(
            "该来源按键已被现有映射占用。",
                "That source key is already used by another mapping.")
        catalog.Set(
            "来源按键与目标按键相同，无需建立映射。",
                "Source and target are identical; no mapping is needed.")
        catalog.Set(
            "映射未写入脚本：{1}",
                "Mapping was not written: {1}")
        catalog.Set(
            "已写入脚本：{1} -> {2}；正在自动应用。",
                "Written to script: {1} -> {2}; applying automatically.")
        catalog.Set(
            "删除映射",
                "Delete mapping")
        catalog.Set(
            "映射未删除：{1}",
                "Mapping was not deleted: {1}")
        catalog.Set(
            "已从脚本删除：{1} -> {2}；正在自动应用。",
                "Deleted from script: {1} -> {2}; applying automatically.")
        catalog.Set(
            "调整映射顺序",
                "Reorder mappings")
        catalog.Set(
            "顺序未保存：{1}",
                "Order was not saved: {1}")
        catalog.Set(
            "已按拖动结果实时更新脚本顺序。",
                "Updated the script order from the dragged result.")
        catalog.Set(
            "暂停映射",
                "Pause mapping")
        catalog.Set(
            "恢复映射",
                "Resume mapping")
        catalog.Set(
            "映射状态未修改：{1}",
                "Mapping state was not changed: {1}")
        catalog.Set(
            "已恢复映射：{1} -> {2}；正在自动应用。",
                "Resumed mapping: {1} -> {2}; applying automatically.")
        catalog.Set(
            "已暂停映射：{1} -> {2}；正在自动应用。",
                "Paused mapping: {1} -> {2}; applying automatically.")
        catalog.Set(
            "映射代码未保存：{1}",
                "Mapping code was not saved: {1}")
        catalog.Set(
            "映射代码未新增：{1}",
                "Mapping code was not added: {1}")
        catalog.Set(
            "未保存：{1}",
                "Not saved: {1}")
        catalog.Set(
            "已保存映射代码：{1} -> {2}；正在自动应用。",
                "Saved mapping code: {1} -> {2}; applying automatically.")
        catalog.Set(
            "已新增映射代码：{1} -> {2}；正在自动应用。",
                "Added mapping code: {1} -> {2}; applying automatically.")
        catalog.Set(
            "无法创建空白映射代码：{1}",
                "Could not create blank mapping code: {1}")
        catalog.Set(
            "无法打开设置：{1}",
                "Could not open settings: {1}")
        catalog.Set(
            "设置未保存：{1}",
                "Settings were not saved: {1}")
        catalog.Set(
            "界面内容字体",
                "UI font")
        catalog.Set(
            "撤销失败：{1}",
                "Undo failed: {1}")
        catalog.Set(
            "重做失败：{1}",
                "Redo failed: {1}")
        catalog.Set(
            "已撤销：{1}",
                "Undone: {1}")
        catalog.Set(
            "已重做：{1}",
                "Redone: {1}")
        catalog.Set(
            "映射配置",
                "Mapping configuration")
        catalog.Set(
            "{1} 条重映射正在生效 · 当前为脚本代码顺序",
                "{1} mappings active · custom script order")
        catalog.Set("键鼠重映射小助手设置",
            "Keyboard & Mouse Remapper Assistant settings")
        catalog.Set("通用",
            "General")
        catalog.Set("关于",
            "About")
        catalog.Set("启动时显示主窗口",
            "Show the main window at startup")
        catalog.Set("单独按 Esc 时取消录制",
            "Press Esc alone to cancel recording")
        catalog.Set("事件缓冲区容量（条）：",
            "Event buffer capacity:")
        catalog.Set("事件查看器自动跟随最新事件",
            "Automatically follow the latest events")
        catalog.Set("让每一条键鼠映射都可录制、可审阅、可掌控",
            "Record, review, and control every keyboard and mouse mapping")
        catalog.Set("当前版本",
            "Current version")
        catalog.Set("运行环境",
            "Runtime")
        catalog.Set("查看最新版本",
            "View latest release")
        catalog.Set("开源地址",
            "Open-source repository")
        catalog.Set("“{1}”必须是 {2} 到 {3} 之间的整数。",
            "“{1}” must be an integer from {2} to {3}.")
        catalog.Set("事件缓冲区容量",
            "Event buffer capacity")
        catalog.Set("未知版本",
            "Unknown version")
        catalog.Set("{1}（EXE 版）",
            "{1} (EXE build)")
        catalog.Set("{1}（源码版）",
            "{1} (source build)")
        catalog.Set("设置没有变化。",
            "No settings changed.")
        catalog.Set("设置已保存并已应用。",
            "Settings saved and applied.")
        catalog.Set("设置",
            "Settings")
        catalog.Set("Esc 取消录制",
            "Esc cancels recording")
        catalog.Set("事件自动跟随",
            "Follow latest events")
        catalog.Set("录制", "Recording")
        catalog.Set("事件", "Events")
        catalog.Set("{1}（便携版）", "{1} (portable build)")
        catalog.Set("帮助信息", "Help")
        catalog.Set("捐赠", "Donate")
        catalog.Set("使用说明", "User guide")
        catalog.Set("提交反馈", "Send feedback")
        catalog.Set("支持开源项目", "Support the open-source project")
        catalog.Set("微信支付", "WeChat Pay")
        catalog.Set("支付宝", "Alipay")
        catalog.Set("二维码图片未找到", "QR code image not found")
        catalog.Set("如果这个项目为您带来了帮助，欢迎通过下方二维码支持作者！`n键鼠重映射小助手将持续保持开源，项目的长期维护有赖于您的支持和鼓励。", "If this project has helped you, you can support the author with one of the QR codes below.`nKeyboard & Mouse Remapper Assistant will remain open source, and your support helps sustain its long-term maintenance.")
        catalog.Set("无法打开帮助信息：{1}", "Could not open Help: {1}")
        catalog.Set("无法打开使用说明：{1}", "Could not open the user guide: {1}")
        catalog.Set("无法打开捐赠窗口：{1}", "Could not open the donation window: {1}")
        catalog.Set("无法打开反馈页面：{1}", "Could not open the feedback page: {1}")
        catalog.Set("键鼠重映射小助手用于录制、审阅和维护键盘与鼠标映射。关闭主窗口只会隐藏到系统托盘，已经启用的映射仍会继续生效。", "Keyboard & Mouse Remapper Assistant records, reviews, and maintains keyboard and mouse mappings. Closing the main window only hides it in the system tray; enabled mappings remain active.")
        catalog.Set("一、快速上手", "1. Quick start")
        catalog.Set("• 点击顶部“新增”，会打开已经填好元数据字段的 @mapping 编辑器；也可以在下方分别录制来源按键和目标按键，填写设计目的后保存。", "• Select Add in the top bar to open an @mapping editor with the metadata fields already prepared. You can also record the source and target below, describe the purpose, and save the mapping.")
        catalog.Set("• 录制会实时显示原始规范名称、阅读友好名称、虚拟键码和扫描码，并区分左右 Ctrl、Shift、Alt、Win 以及键盘、鼠标和滚轮输入。", "• Recording shows the canonical name, readable name, virtual-key code, and scan code in real time. It distinguishes left and right Ctrl, Shift, Alt, and Win, as well as keyboard, mouse, and wheel input.")
        catalog.Set("• 同时按下的任意按键会组成一次录制；所有按键释放后结束。录制期间再次点击录制按钮会取消本次录制，不会把该次点击记为 LButton。", "• Any keys held together form one recording, which ends after every key is released. Selecting the recording button again cancels the recording instead of recording that click as LButton.")
        catalog.Set("二、主界面与代码编辑", "2. Main window and code editing")
        catalog.Set("• 单击选择映射；双击条目、悬停时按 F2 或使用右键菜单，可编辑完整 @mapping 代码块。", "• Select a mapping with one click. Double-click a row, press F2 while hovering, or use the context menu to edit the complete @mapping block.")
        catalog.Set("• 选中条目后可暂停、恢复或删除；直接拖动列表行可调整永久顺序，脚本中的代码块顺序会实时同步。", "• A selected mapping can be paused, resumed, or deleted. Drag rows to change the permanent order; the script's block order is synchronized immediately.")
        catalog.Set("• 点击伪表头只进行临时排序；字段按升序、降序、自定义顺序循环，序号列按降序、自定义顺序循环，不会改写脚本。", "• Pseudo-header sorting is temporary. Fields cycle through ascending, descending, and custom order; the number column cycles through descending and custom order. Neither rewrites the script.")
        catalog.Set("• 映射区域只保存注释化 RuleSpec v2，是映射的唯一持久来源。GUI 创建或编辑的托管规则会直接热应用；可执行 AHK 代码不会被接受。", "• The mapping region stores only commented RuleSpec v2 and is the sole persistent source of mappings. Managed rules created or edited in the GUI are hot-applied; executable AHK code is rejected.")
        catalog.Set("四、事件、历史与界面设置", "4. Events, history, and appearance settings")
        catalog.Set("• 事件查看器记录输入、规则匹配、条件拒绝、执行结果、仓储和系统事件，支持筛选、暂停、清空及 JSONL 导出。", "• Event Viewer records input, rule matches, condition rejections, execution results, repository activity, and system events. It supports filtering, pausing, clearing, and JSONL export.")
        catalog.Set("五、后台运行与问题排查", "5. Background operation and troubleshooting")
        catalog.Set("• 主窗口关闭后程序仍驻留托盘。托盘可以重新显示主界面、手动重新加载或彻底退出；修改映射规则后通常不需要手动重新加载。", "• The app remains in the tray after the main window closes. The tray can show the window, reload manually, or exit completely; mapping changes normally do not require a manual reload.")
        catalog.Set("• 映射对管理员程序无效时，请从托盘选择以管理员身份重新启动。遇到规则冲突或按键未按预期执行时，先在事件查看器中核对输入和规则结果。", "• If a mapping does not affect an elevated app, restart this app as administrator from the tray. For conflicts or unexpected input, inspect the input and rule outcomes in Event Viewer first.")
        catalog.Set("• “帮助信息”还可打开项目反馈页面。提交问题时请说明系统版本、复现步骤、相关 @mapping 代码和事件导出，并在公开前移除敏感路径或应用信息。", "• Help also opens the project's feedback page. When reporting an issue, include the Windows version, reproduction steps, relevant @mapping code, and an event export, and remove sensitive paths or app information before posting.")
        catalog.Set("安全模式：已停用所有映射和输入观察。连续启动失败 {1} 次。", "Safe mode: all mappings and input observation are disabled after {1} consecutive startup failures.")
        catalog.Set("恢复最后正常配置", "Restore last known good configuration")
        catalog.Set("没有可恢复的最后正常配置。", "No last known good configuration is available.")
        catalog.Set("最后正常配置恢复失败：{1}", "Failed to restore the last known good configuration: {1}")
        catalog.Set("最后正常配置已恢复，正在自动应用。", "The last known good configuration was restored and is being applied automatically.")
        catalog.Set("仅勾选的规则会被导入。", "Only selected rules will be imported.")
        catalog.Set("三、规则与生效范围", "3. Rules and scope")
        catalog.Set("• 所有规则属于同一全局规则集；生效范围和条件可在 @mapping 编辑器中精确调整，保存后会立即重新选择生效规则。", "• All rules belong to one global rule set. Scope and conditions can be adjusted precisely in the @mapping editor, and saving immediately reselects the active rules.")
        catalog.Set("• Ctrl+Z 撤销，Ctrl+Shift+Z 或 Ctrl+Y 重做。映射增删、暂停恢复、拖动排序、代码编辑和设置修改都会进入持久历史。", "• Ctrl+Z undoes; Ctrl+Shift+Z or Ctrl+Y redoes. Mapping additions and deletions, pause and resume actions, drag reordering, code edits, and settings changes are stored in persistent history.")
        return catalog
    }
}
