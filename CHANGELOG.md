# 更新日志

本项目遵循语义化版本。发布前在此记录用户可见变化。

## [0.1.0] - 2026-07-31

### 更名

- 产品中文名统一为“键鼠重映射小助手”，英文名统一为
  “Keyboard & Mouse Remapper Assistant”。
- 入口、应用类、CLI、图标、GitHub 地址、CI 制品和发行目录统一使用
  `KeyMouseRemapperAssistant` / `key-mouse-remapper-assistant` 标识。
- 默认数据目录迁移到 `%APPDATA%\KeyMouseRemapperAssistant`，并按优先级兼容迁移
  上一产品名和最初产品名的数据；已有目标文件不会被覆盖。
- 新规则包 kind 为 `key-mouse-remapper-assistant-rule-package`，导入器继续识别两个旧
  kind，保证已有导出文件可用。

### 输入架构

- 输入链路统一为 Windows Raw Input；移除内核驱动、签名、低级钩子、AHK 热键后端和
  raw AHK worker。
- Raw Input 只区分实体键盘和鼠标，不抑制原输入；规则只产生附加输出。
- GUI 与唯一 `input-worker` 使用同一 `RawInputBackend`，捕获自动绑定首个实体设备的
  `stable_id`。
- `input-worker` 保持受监督的独立后台进程，但不再显示第二个 AutoHotkey 托盘图标。
- 修饰键、按住、重复、同时键、序列、计时和输出 owner 全部按设备隔离；设备移除或重绑
  只清理对应设备。

### 规则与安全

- 生产规则只支持 managed RuleSpec v2；映射区域只允许注释和空行。
- 保留并迁移入口内已有的 15 条映射，旧 managed schema 可升级，任意可执行 AHK 规则不再
  接受。
- 规则包只导入和导出 managed RuleSpec，不再声明 `raw_ahk` 能力或权限。
- 取消多档案及自动切换设计，所有映射统一属于单一全局规则集；旧规则中的分组字段在迁移时
  丢弃，规则本身继续保留。
- CLI 修改规则后通知 GUI 热应用，不再通过脚本重载切换输入实现。

### 清理

- 删除驱动源码、安装与签名工具、原生构建链、重复多语言 README、过期路线图和已移除
  后端的测试。
- 删除主界面重复的事件查看器入口，并修正设置窗口内容区不对称、字段未居中和长标签裁切。
- 发行 manifest 固定声明 `inputBackend: raw-input`、`requiresDriver: false` 和
  `suppressesOriginalInput: false`。
- 公开仓库只保留 OFL 许可的 Noto 界面字体；移除不可随 MIT 源码再授权的商业字体，
  并把 CJK 字体集合从 45 个字体面精简为五个地区 Regular 字体面。
- 补齐开源协作、漏洞报告、CI、可复现构建、第三方许可和发布工作流，清除本地工具链、
  构建产物及已经删除的驱动验证残留。

### 界面一致性

- 共有窗口行为对齐“进程守护小助手”：自绘按钮恢复 Windows 无障碍按钮语义，主工具栏
  和外链按钮使用延迟、无激活、DPI 感知的深浅色悬浮提示。
- 子窗口最小化时获得独立任务栏入口并临时恢复直接上级；还原前重建 Owner 和模态状态，
  避免子窗口带动上级最小化或恢复错误窗口。
- 诊断包预览和未保存代码确认改用统一深浅色模态窗口；按钮按实际语言、字体和 DPI 动态
  测宽，不再依赖原生浅色消息框。
- 主题别名、链接/只读文本颜色和 SVG 动态库加载回退统一进入共享服务；提示测量使用有界
  缓存，没有提示的窗口不登记额外消息回调。
