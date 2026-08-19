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
            "删除",
                "Delete")
        catalog.Set(
            "暂停",
                "Pause")
        catalog.Set(
            "恢复",
                "Resume")
        catalog.Set("反转状态", "Toggle States")
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
            "名称",
                "Name")
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
        catalog.Set("规则块", "Standard rule")
        catalog.Set("受托管脚本", "Managed script")
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
            "事件查看",
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
            "规则包导入完成：新增 {1}，替换 {2}，重命名 {3}，跳过 {4}。",
                "Import complete: {1} added, {2} replaced, {3} renamed, {4} skipped.")
        catalog.Set("导入规则包预览", "Rule package import preview")
        catalog.Set("来源：{1} · 版本：{2}", "Source: {1} · Version: {2}")
        catalog.Set("共 {1} 条规则，默认选中 {2} 条；权限：{3}", "{1} rules; {2} selected by default. Permissions: {3}")
        catalog.Set("模式", "Mode")
        catalog.Set("权限", "Permissions")
        catalog.Set("全选", "Select all")
        catalog.Set("全部取消", "Clear all")
        catalog.Set("导入所选", "Import selected")
        catalog.Set("无额外权限", "No additional permissions")
        catalog.Set("生成键鼠输入", "Generate keyboard and mouse input")
        catalog.Set("控制活动窗口", "Control the active window")
        catalog.Set("执行系统控制", "Perform system control")
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
            "系统事件",
                "System")
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
            "退出程序",
                "Exit")
        catalog.Set(
            "设置",
                "Settings")
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
        catalog.Set("无法启动按键录制：{1}", "Could not start key recording: {1}")
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
            "所选映射缺少名称，无法删除。",
                "The selected mapping has no name and cannot be deleted.")
        catalog.Set(
            "请先选择要暂停或恢复的映射。",
                "Select a mapping to pause or resume first.")
        catalog.Set(
            "所选映射缺少名称，无法修改状态。",
                "The selected mapping has no name and cannot change state.")
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
            "为避免失去界面操作，来源按键不能是无修饰的鼠标左键。",
                "An unmodified left mouse button cannot be used as a source key.")
        catalog.Set(
            "映射未写入脚本：{1}",
                "Mapping was not written: {1}")
        catalog.Set(
            "已写入脚本：{1} -> {2}；已应用。",
                "Written to script: {1} -> {2}; applied.")
        catalog.Set(
            "映射未删除：{1}",
                "Mapping was not deleted: {1}")
        catalog.Set(
            "已从脚本删除：{1} -> {2}；已应用。",
                "Deleted from script: {1} -> {2}; applied.")
        catalog.Set(
            "顺序未保存：{1}",
                "Order was not saved: {1}")
        catalog.Set(
            "已按拖动结果实时更新脚本顺序。",
                "Updated the script order from the dragged result.")
        catalog.Set(
            "映射状态未修改：{1}",
                "Mapping state was not changed: {1}")
        catalog.Set(
            "已恢复映射：{1} -> {2}；已应用。",
                "Resumed mapping: {1} -> {2}; applied.")
        catalog.Set(
            "已暂停映射：{1} -> {2}；已应用。",
                "Paused mapping: {1} -> {2}; applied.")
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
            "已保存映射代码：{1} -> {2}；已应用。",
                "Saved mapping code: {1} -> {2}; applied.")
        catalog.Set(
            "已新增映射代码：{1} -> {2}；已应用。",
                "Added mapping code: {1} -> {2}; applied.")
        catalog.Set("已保存，正在后台应用…",
            "Saved; applying in the background...")
        catalog.Set("受托管脚本已应用。", "Managed script applied.")
        catalog.Set("映射代码没有变化。", "Mapping code did not change.")
        catalog.Set("映射代码已保存，但受托管脚本应用失败：{1}",
            "Mapping code was saved, but the managed script could not be applied: {1}")
        catalog.Set(
            "无法创建空白映射代码：{1}",
                "Could not create blank mapping code: {1}")
        catalog.Set(
            "设置未保存：{1}",
                "Settings were not saved: {1}")
        catalog.Set(
            "{1} 条重映射正在生效 · 当前为脚本代码顺序",
                "{1} mappings active · custom script order")
        catalog.Set("键鼠重映射小助手设置",
            "Keyboard & Mouse Remapper Assistant settings")
        catalog.Set("启动",
            "Startup")
        catalog.Set("显示",
            "Display")
        catalog.Set("规则与事件",
            "Rules and events")
        catalog.Set("关于",
            "About")
        catalog.Set("事件缓冲区容量（条）：",
            "Event buffer capacity:")
        catalog.Set("事件查看自动跟随最新事件",
            "Automatically follow the latest events")
        catalog.Set("让每一条键鼠映射都可录制、可审阅、可掌控",
            "Record, review, and control every keyboard and mouse mapping")
        catalog.Set("当前版本",
            "Current version")
        catalog.Set("运行环境",
            "Runtime")
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
        catalog.Set("设置已保存并已应用。",
            "Settings saved and applied.")
        catalog.Set("Esc 取消录制",
            "Esc cancels recording")
        catalog.Set("{1}（便携版）", "{1} (portable build)")
        catalog.Set("快揭不开锅了（≥Д≤）",
            "The budget's almost gone（≥Д≤）")
        catalog.Set("使用说明", "User guide")
        catalog.Set("提交反馈", "Send feedback")
        catalog.Set("支持开源项目", "Support the open-source project")
        catalog.Set("微信支付", "WeChat Pay")
        catalog.Set("支付宝", "Alipay")
        catalog.Set("二维码图片未找到", "QR code image not found")
        catalog.Set("如果小助手为您节省了配置键鼠映射的时间，欢迎通过下方二维码打赏作者！`n请选择扶贫方式（≥Д≤）", "If the assistant has saved you time configuring keyboard and mouse mappings, please consider supporting the author through one of the QR codes below!`nChoose how you'd like to help (≥Д≤)")
        catalog.Set("无法打开反馈页面：{1}", "Could not open the feedback page: {1}")
        catalog.Set("键鼠重映射小助手用于录制、审阅和维护键盘与鼠标映射。关闭主窗口只会隐藏到系统托盘，已经启用的映射仍会继续生效。", "Keyboard & Mouse Remapper Assistant records, reviews, and maintains keyboard and mouse mappings. Closing the main window only hides it in the system tray; enabled mappings remain active.")
        catalog.Set("一、快速上手", "1. Quick start")
        catalog.Set("• 点击顶部“新增”，会打开已经填好元数据字段的 @mapping 编辑器；也可以在下方分别录制来源按键和目标按键，填写名称后保存。", "• Select Add in the top bar to open an @mapping editor with the metadata fields already prepared. You can also record the source and target below, enter a name, and save the mapping.")
        catalog.Set("• 录制会实时显示原始规范名称、阅读友好名称、虚拟键码和扫描码，并区分左右 Ctrl、Shift、Alt、Win 以及键盘、鼠标和滚轮输入。", "• Recording shows the canonical name, readable name, virtual-key code, and scan code in real time. It distinguishes left and right Ctrl, Shift, Alt, and Win, as well as keyboard, mouse, and wheel input.")
        catalog.Set("二、主界面与代码编辑", "2. Main window and code editing")
        catalog.Set("• 单击选择映射；双击条目、选中后按 F2 或使用右键菜单，可编辑完整 @mapping 代码块。", "• Select a mapping with one click. Double-click a row, press F2 after selecting it, or use the context menu to edit the complete @mapping block.")
        catalog.Set("• 选中条目后可暂停、恢复或删除；直接拖动列表行可调整永久顺序，脚本中的代码块顺序会实时同步。", "• A selected mapping can be paused, resumed, or deleted. Drag rows to change the permanent order; the script's block order is synchronized immediately.")
        catalog.Set("• 点击伪表头只进行临时排序；字段按升序、降序、自定义顺序循环，序号列按降序、自定义顺序循环，不会改写脚本。", "• Pseudo-header sorting is temporary. Fields cycle through ascending, descending, and custom order; the number column cycles through descending and custom order. Neither rewrites the script.")
        catalog.Set("• 事件查看记录输入、规则匹配、条件拒绝、执行结果、仓储和系统事件，支持筛选、暂停、清空及 JSONL 导出。", "• Event Viewer records input, rule matches, condition rejections, execution results, repository activity, and system events. It supports filtering, pausing, clearing, and JSONL export.")
        catalog.Set("四、事件查看与设置", "4. Event viewer and settings")
        catalog.Set("五、后台运行与问题排查", "5. Background operation and troubleshooting")
        catalog.Set("• 主窗口关闭后程序仍驻留托盘。托盘可以重新显示主界面、手动重新加载或彻底退出；修改映射规则后通常不需要手动重新加载。", "• The app remains in the tray after the main window closes. The tray can show the window, reload manually, or exit completely; mapping changes normally do not require a manual reload.")
        catalog.Set("仅勾选的规则会被导入。", "Only selected rules will be imported.")
        catalog.Set("三、规则与生效范围", "3. Rules and scope")
        catalog.Set("• 所有规则属于同一全局规则集；生效范围和条件可在 @mapping 编辑器中精确调整，保存后会立即重新选择生效规则。", "• All rules belong to one global rule set. Scope and conditions can be adjusted precisely in the @mapping editor, and saving immediately reselects the active rules.")
        catalog.Set("没有可撤销的映射变更。", "There are no mapping changes to undo.")
        catalog.Set("已撤销上一步映射变更。", "Undid the last mapping change.")
        catalog.Set("撤销映射变更失败：{1}", "Could not undo the mapping change: {1}")
        catalog.Set("没有可重做的映射变更。", "There are no mapping changes to redo.")
        catalog.Set("已重做映射变更。", "Redid the mapping change.")
        catalog.Set("重做映射变更失败：{1}", "Could not redo the mapping change: {1}")
        catalog.Set("录制结束后无法恢复重映射：{1}", "Could not resume remapping after recording: {1}")
        catalog.Set("• 新增、删除、暂停或恢复、代码编辑、拖动排序和规则包导入均可撤销；Ctrl+Z 撤销，Ctrl+Shift+Z 或 Ctrl+Y 重做。", "• Adding, deleting, pausing or resuming, code editing, drag reordering, and rule-package imports can all be undone. Use Ctrl+Z to undo and Ctrl+Shift+Z or Ctrl+Y to redo.")
        catalog.Set("操作计划任务时发生错误：{1}", "An error occurred while working with the scheduled task: {1}")
        catalog.Set("冲突", "Conflict")
        catalog.Set("创建", "Create")
        catalog.Set("创建成功！", "Created successfully!")
        catalog.Set("创建快捷方式失败：{1}", "Could not create shortcuts: {1}")
        catalog.Set("错误", "Error")
        catalog.Set("当前陪伴您的已经是最新版本的小助手啦！", "You already have the latest version of the assistant!")
        catalog.Set("发现新版本 {1}，当前版本为 {2}。`n`n{3}`n`n是否立即更新？", "Version {1} is available; the current version is {2}.`n`n{3}`n`nUpdate now?")
        catalog.Set("更新检查未返回结果", "The update check returned no result")
        catalog.Set("更新检查正在进行，请稍候。", "An update check is already in progress. Please wait.")
        catalog.Set("关闭", "Close")
        catalog.Set("检测到同名计划任务，但它并非当前程序创建；为避免误删，请先在任务计划程序中处理它。", "A scheduled task with the same name exists, but it was not created by this program. To avoid deleting it accidentally, handle it in Task Scheduler first.")
        catalog.Set("检查更新", "Check for updates")
        catalog.Set("检查更新失败：{1}", "Update check failed: {1}")
        catalog.Set("将确认源码仓库没有未提交修改，再快速前进到正式发布标签并自动重启。", "The source repository will be checked for uncommitted changes, fast-forwarded to the official release tag, and then restarted automatically.")
        catalog.Set("将下载并校验完整发行包，退出小助手后替换程序文件并自动重启。", "The full release package will be downloaded and verified. After the assistant exits, its files will be replaced and it will restart automatically.")
        catalog.Set("将下载并校验源码发行包，保留个人配置后替换源码并自动重启。", "The source release package will be downloaded and verified. Your personal configuration will be kept while the source files are replaced, and the assistant will restart automatically.")
        catalog.Set("开机自动启动", "Start automatically at sign-in")
        catalog.Set("开机自动启动（计划任务）", "Start automatically at sign-in (scheduled task)")
        catalog.Set("开启", "Enable")
        catalog.Set("不可用", "Unavailable")
        catalog.Set("立即更新", "Update now")
        catalog.Set("没有可安装的应用更新", "No application update is available")
        catalog.Set("启动失败", "Startup failed")
        catalog.Set("启动时检查小助手更新", "Check for assistant updates at startup")
        catalog.Set("以管理员身份运行", "Run as administrator")
        catalog.Set("启动时显示主窗口", "Show the main window at startup")
        catalog.Set("切换", "Toggle")
        catalog.Set("确定", "OK")
        catalog.Set("稍后", "Later")
        catalog.Set("输入录制不可用：{1}", "Input recording is unavailable: {1}")
        catalog.Set("提示", "Notice")
        catalog.Set("无法检查更新：{1}", "Could not check for updates: {1}")
        catalog.Set("无法建立单实例运行锁，小助手将退出。", "Could not acquire the single-instance lock. The assistant will exit.")
        catalog.Set("无法开始更新：{1}", "Could not start the update: {1}")
        catalog.Set("小助手更新", "Assistant update")
        catalog.Set("新脚本未通过 AutoHotkey 启动验证。", "The new script did not pass the AutoHotkey startup check.")
        catalog.Set("正在检查更新…", "Checking for updates…")
        catalog.Set("重新加载失败，已保留当前实例：{1}", "Reload failed; the current instance has been kept: {1}")
        catalog.Set("桌面与开始菜单快捷方式", "Desktop and Start menu shortcuts")
        catalog.Set("保存并运行", "Save and run")
        catalog.Set("导入并运行", "Import and run")
        catalog.Set("导入自定义 AHK 代码", "Import custom AHK code")
        catalog.Set("继续", "Continue")
        catalog.Set("切换规则类型", "Switch rule type")
        catalog.Set("切换规则类型会清空当前未保存内容，是否继续？", "Switching rule type clears the current unsaved content. Continue?")
        catalog.Set("所选规则包含可读写文件、启动程序、控制窗口和请求管理员权限的自定义 AHK 代码。确认导入并运行吗？", "The selected rules contain custom AHK code that can read and write files, launch programs, control windows, and request administrator privileges. Import and run it?")
        catalog.Set("无法创建规则模板：{1}", "Could not create the rule template: {1}")
        catalog.Set("运行自定义 AHK 代码", "Run custom AHK code")
        catalog.Set("自定义 AHK 代码可读取文件、启动程序、控制窗口并请求管理员权限。确认运行当前代码吗？", "Custom AHK code can read and write files, launch programs, control windows, and request administrator privileges. Run this code?")
        catalog.Set("规则未应用：{1}", "Rules were not applied: {1}")
        catalog.Set("• 映射区域以注释形式保存规则块和受托管脚本。规则块在主进程热应用；受托管脚本的自定义 AHK v2 源码在独立受管进程运行，保存、暂停、恢复、删除和退出均由小助手统一管理。", "• The mapping region stores standard rule blocks and managed scripts as comments. Standard rule blocks are hot-applied in the main process. Custom AutoHotkey v2 source runs in an isolated managed process controlled by the assistant.")
        catalog.Set("区分左右修饰键", "Distinguish left/right modifier keys")
        catalog.Set("帮助", "Help")
        catalog.Set("打赏", "Donate")
        catalog.Set("打开帮助`n可选择查看使用说明、运行日志或提交反馈", "Open Help`nChoose the user guide, runtime log, or feedback page")
        catalog.Set("点个 star 吧~", "Give us a little star~")
        catalog.Set("配置显示、规则包和事件选项", "Configure display, rule packages, and event options")
        catalog.Set("查看版本、运行环境和项目入口", "View version, runtime, and project links")
        catalog.Set("找作者对线", "Talk to the author")
        catalog.Set("演奏你的和弦！", "Play your chord!")
        catalog.Set("• “帮助”还可打开项目反馈页面。提交问题时请说明系统版本、复现步骤、相关 @mapping 代码和事件导出，并在公开前移除敏感路径或应用信息。", "• Help also opens the project's feedback page. When reporting an issue, include the Windows version, reproduction steps, relevant @mapping code, and an event export, and remove sensitive paths or app information before posting.")
        catalog.Set("AI 设置", "AI settings")
        catalog.Set("API 地址：", "API address:")
        catalog.Set("API 密钥：", "API key:")
        catalog.Set("模型名称：", "Model name:")
        catalog.Set("请求超时（秒）：", "Request timeout (seconds):")
        catalog.Set("请求超时（秒）", "Request timeout (seconds)")
        catalog.Set("提示词：", "Prompts:")
        catalog.Set("生成", "Generate")
        catalog.Set("优化", "Optimize")
        catalog.Set("系统说明", "System instructions")
        catalog.Set("编辑", "Edit")
        catalog.Set("AI 提示词", "AI prompts")
        catalog.Set("生成提示词不能为空。", "Generation prompt cannot be empty.")
        catalog.Set("优化提示词不能为空。", "Optimization prompt cannot be empty.")
        catalog.Set("恢复默认", "Restore default")
        catalog.Set("系统说明不能为空。", "System instructions cannot be empty.")
        catalog.Set("生成重映射规则", "Generate remapping rule")
        catalog.Set("优化当前规则", "Optimize current rule")
        catalog.Set("AI 生成规则", "AI Generate")
        catalog.Set("设置序号圆点", "Set sequence dot")
        catalog.Set("清除圆点颜色", "Clear dot color")
        catalog.Set("雾松绿", "Misty pine")
        catalog.Set("青灰蓝", "Blue gray")
        catalog.Set("薰衣草紫", "Lavender")
        catalog.Set("烟粉", "Dusty rose")
        catalog.Set("浅琥珀", "Light amber")
        catalog.Set("静谧青", "Quiet teal")
        catalog.Set("珍珠灰", "Pearl gray")
        catalog.Set("已更新 {1} 条规则的序号圆点颜色。", "Updated sequence dot colors for {1} rules.")
        catalog.Set("序号圆点颜色未保存：{1}", "Sequence dot colors were not saved: {1}")
        catalog.Set("AI 优化规则", "AI Optimize")
        catalog.Set("请输入规则目的。", "Enter the rule's purpose.")
        catalog.Set("说点什么吧，我什么都会做的 T_T", "Say whatever you want. I can do anything T_T")
        catalog.Set("我是来帮你的，你要干什么？！", "I'm here to help. What do you need?!")
        catalog.Set("请先关闭当前代码编辑器，再优化其他映射。", "Close the current code editor before optimizing another mapping.")
        catalog.Set("AI 服务尚未初始化。", "The AI service is not initialized.")
        catalog.Set("无法读取当前映射代码：{1}", "Could not read the current mapping code: {1}")
        catalog.Set("AI 正在生成规则，请稍候...", "AI is generating a rule. Please wait...")
        catalog.Set("AI 正在优化规则，请稍候...", "AI is optimizing the rule. Please wait...")
        catalog.Set("AI 请求失败，请检查 AI 设置和网络连接。", "The AI request failed. Check the AI settings and network connection.")
        catalog.Set("测试连接", "Test connection")
        catalog.Set("正在测试 AI 连接…", "Testing the AI connection…")
        catalog.Set("AI 连接测试成功。", "AI connection test succeeded.")
        catalog.Set("AI 连接测试失败：{1}", "AI connection test failed: {1}")
        catalog.Set("请填写 API 地址。", "Enter the API address.")
        catalog.Set("请填写模型名称。", "Enter the model name.")
        catalog.Set("请求期间编辑器内容已变化，请重新执行 AI 操作。", "The editor changed during the request. Run the AI operation again.")
        catalog.Set("AI 规则已放入编辑器，请检查后保存。", "The AI rule is in the editor. Review it before saving.")
        catalog.Set("状态", "Status")
        catalog.Set("启用", "Enabled")
        catalog.Set("无法读取设置文件，已使用默认设置：{1}", "Settings could not be read, so defaults are being used: {1}")
        catalog.Set("审阅 AI 优化结果", "Review AI optimization")
        catalog.Set("已保留原内容，AI 结果未应用。", "The original content was kept. The AI result was not applied.")
        catalog.Set("AI 结果无法应用到编辑器，请重试。", "The AI result could not be applied to the editor. Try again.")
        catalog.Set("无法打开 AI 结果审阅：{1}", "Could not open the AI result review: {1}")
        catalog.Set("当前 {1} 行，AI 建议 {2} 行；约 {3} 行有变化。", "Current: {1} lines`; AI suggestion: {2} lines`; about {3} lines changed.")
        catalog.Set("当前内容", "Current content")
        catalog.Set("AI 建议", "AI suggestion")
        catalog.Set("接受结果", "Accept result")
        catalog.Set("保留原文", "Keep original")
        catalog.Set("AI 返回的规则经过自动修复后仍未通过本地校验：{1}", "The AI rule still failed local validation after automatic repair: {1}")
        catalog.Set("AI 规则校验结果不完整。", "The AI rule validation result is incomplete.")
        catalog.Set("AI 正在复核规则的实际行为，请稍候...", "AI is reviewing the rule's actual behavior. Please wait...")
        catalog.Set("AI 正在根据本地校验结果修复规则，请稍候...", "AI is repairing the rule based on local validation. Please wait...")
        catalog.Set("本地校验失败：{1}", "Local validation failed: {1}")
        catalog.Set("失败发生阶段：{1}", "Failure stage: {1}")
        catalog.Set("必须修复根因并重新满足用户原始目的。", "Fix the root cause and fully satisfy the user's original intent.")
        catalog.Set("规则块能力不足，必须改用受托管脚本完整实现。", "A standard rule block is insufficient`; use a managed script for the complete implementation.")
        catalog.Set("未保存：请先用完整的 AHK v2 脚本替换代码占位文字。", "Not saved: replace the code placeholder with a complete AHK v2 script first.")
        catalog.Set("当前等待时间：{1} 秒", "Current wait time: {1} seconds")
        catalog.Set("界面缩放：", "Interface scaling:")
        catalog.Set("界面缩放已保存，正在重新加载…", "Interface scaling was saved. Reloading…")
        return catalog
    }
}
