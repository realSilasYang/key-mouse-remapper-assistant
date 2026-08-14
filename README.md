<div align="center">
  <img src="./assets/app/key-mouse-remapper-assistant.png" width="112" alt="键鼠重映射小助手 Logo">

  <p><strong>简体中文</strong> · <a href="./docs/README.zh-HK.md">繁體中文（香港）</a> · <a href="./docs/README.zh-TW.md">繁體中文（台灣）</a> · <a href="./docs/README.en.md">English</a> · <a href="./docs/README.ja.md">日本語</a> · <a href="./docs/README.vi.md">Tiếng Việt</a> · <a href="./docs/README.ko.md">한국어</a> · <a href="./docs/README.es.md">Español</a> · <a href="./docs/README.fr.md">Français</a> · <a href="./docs/README.pt-BR.md">Português</a> · <a href="./docs/README.ru.md">Русский</a> · <a href="./docs/README.de.md">Deutsch</a> · <a href="./docs/README.it.md">Italiano</a></p>

  <h1>键鼠重映射小助手</h1>

  <p><strong>录制、编写和管理真正适合自己工作流的键盘与鼠标映射</strong></p>

  <p>
    <a href="https://github.com/realSilasYang/key-mouse-remapper-assistant/releases/latest"><img src="https://img.shields.io/github/v/release/realSilasYang/key-mouse-remapper-assistant?style=flat-square&amp;label=version" alt="最新版本"></a>
    <a href="https://github.com/realSilasYang/key-mouse-remapper-assistant/releases"><img src="https://img.shields.io/github/downloads/realSilasYang/key-mouse-remapper-assistant/total?style=flat-square&amp;label=downloads" alt="GitHub 下载量"></a>
    <a href="./LICENSE"><img src="https://img.shields.io/github/license/realSilasYang/key-mouse-remapper-assistant?style=flat-square" alt="开源许可证"></a>
    <img src="https://img.shields.io/badge/Windows-10%20%7C%2011-0078D4?style=flat-square" alt="支持 Windows 10 和 Windows 11">
    <img src="https://img.shields.io/badge/AutoHotkey-v2-334455?style=flat-square" alt="基于 AutoHotkey v2">
  </p>

  <p>
    <a href="#界面概览">界面概览</a> ·
    <a href="#用户使用指南">用户指南</a> ·
    <a href="#4-规则块与受托管脚本">规则形式</a> ·
    <a href="https://github.com/realSilasYang/key-mouse-remapper-assistant/releases">版本发布</a> ·
    <a href="./CHANGELOG.md">更新日志</a> ·
    <a href="https://github.com/realSilasYang/key-mouse-remapper-assistant/issues/new">问题反馈</a> ·
    <a href="#开发者指南">开发者指南</a>
  </p>
</div>

键鼠重映射小助手是一款面向 Windows 10／11 x64 的 AutoHotkey v2 桌面工具。它把按键录制、规则管理、代码编辑、AI 生成与优化、语法校验和运行状态集中在同一个界面中，既能快速完成普通键位替换，也允许通过受托管脚本实现复杂的 AHK v2 自动化。

当前版本内置 18 条可直接使用和修改的规则，其中 13 条为规则块、5 条为受托管脚本。规则保存在可编辑的 `@mapping` 注释区域中；便携版和源码版都能查看、备份和修改这些内容。项目不安装驱动或 Windows 服务，启用的规则只在小助手运行期间生效。

程序提供 13 种界面语言、浅色／深色主题、管理员运行、开机启动、自动更新、事件查看、规则包导入与导出，以及面向规则块和受托管脚本的本地校验。AI 地址、密钥、模型、自定义提示词和其他本机用户设置绝不会写入正式发行包。

# 界面概览

<p align="center">
  <img src="docs/images/key-mouse-remapper-assistant-overview.png" alt="键鼠重映射小助手主界面" width="100%">
</p>

主窗口上方用于新增、批量暂停／恢复和删除规则，中间列表集中显示序号、名称、来源按键、映射结果、生效范围和实时状态，下方可以直接录制来源按键与目标按键。列表支持多选、批量拖动排序、临时表头排序、悬浮完整内容、序号彩色圆点和圆角选中状态；底部状态栏只显示当前操作或所选规则的结果。

## 主要能力

- 录制键盘、鼠标按键、滚轮和常见浏览器／媒体／启动键，并区分左右 Ctrl、Shift、Alt 和 Win。
- 直接抑制来源输入后执行按键、文本、鼠标、应用命令、窗口、锁屏和延时等动作。
- 使用应用、窗口、输入法和会话条件限制生效范围，并支持短按、长按、松开、重复和同时按键。
- 在主进程热应用结构化规则块；在独立受管 AutoHotkey v2 进程中运行完整脚本。
- 通过同一入口让 AI 自行判断应使用规则块还是受托管脚本；结果经过格式归一化、本地结构校验、按键能力校验和 AHK v2 启动验证。
- 代码编辑器提供 AHK v2／RuleSpec 语法高亮、差异行高亮、撤销、重做、删除行、固定两行滚动和错误定位。
- 新增、编辑、删除、暂停／恢复、规则包导入和拖动排序均进入映射历史，可撤销或重做。
- 事件查看器记录输入、规则匹配、条件拒绝、执行、仓储和系统事件，支持筛选、暂停、清空及 JSONL 导出。
- 关闭主窗口后继续驻留托盘；支持计划任务开机启动、默认管理员运行、启动时检查更新和手动更新。
- 支持简体中文、繁体中文（香港）、繁体中文（台湾）、英语、日语、越南语、韩语、西班牙语、法语、葡萄牙语（巴西）、俄语、德语和意大利语。

## 适用范围

适合把常用按键改成另一组按键、为应用增加快捷键、按窗口或进程限定映射，以及使用 AHK v2 完成带状态、计时器、多个热键或外部调用的桌面自动化。以下边界需要提前了解：

- 只支持 Windows 10／11 x64；不支持 32 位 Windows、macOS 或 Linux。
- 不安装内核驱动，无法处理 Windows 安全桌面、`Ctrl+Alt+Delete` 等安全注意序列，也不能绕过游戏或安全软件的底层输入保护。
- 映射能否作用于某个高权限程序取决于完整性级别；默认的“以管理员身份运行”会让规则块和受托管脚本随小助手一起提权。
- AI 输出在本地校验通过后仍应由用户审阅，尤其是包含文件、网络、进程或系统操作的受托管脚本。

---

**[用户使用指南](#用户使用指南)**<br>
[安装与首次运行](#1-安装与首次运行) · [添加和管理映射](#2-添加和管理映射) · [录制、状态与事件](#3-录制状态与事件) · [规则形式与 AI](#4-规则块受托管脚本与-ai) · [设置](#5-设置) · [诊断与隐私](#6-事件诊断和隐私)

**[开发者指南](#开发者指南)**<br>
[目录与职责](#1-目录与职责) · [正确性边界](#2-正确性边界) · [验证命令](#3-验证命令) · [发布与贡献](#4-发布与贡献)

# 打赏

如果小助手确实改善了您的日常操作，欢迎通过下方二维码打赏作者。请选择扶贫方式（≥Д≤）：

<p align="center">
  <img src="assets/donate/微信个人收款码.png" width="220" alt="微信支付打赏二维码">
  &nbsp;&nbsp;&nbsp;&nbsp;
  <img src="assets/donate/支付宝个人收款码.png" width="220" alt="支付宝打赏二维码">
</p>

# 用户使用指南

## 1. 安装与首次运行

1. 从 [Releases](https://github.com/realSilasYang/key-mouse-remapper-assistant/releases) 下载完整便携 ZIP 或完整源码 ZIP。
2. 两个版本必须完整解压到可写目录后使用，不要只从压缩包中运行单个文件：

| 下载 | 适用场景 | 运行方式 |
| --- | --- | --- |
| 完整便携 ZIP（推荐） | 日常使用、手动部署和备份 | 运行 `键鼠重映射小助手.exe`；内含固定的 AutoHotkey v2 x64 运行时，无需另行安装 |
| 完整源码 ZIP | 审阅、开发或从源码运行 | 安装 AutoHotkey v2 x64 后运行 `键鼠重映射小助手.ahk`；不含编译 EXE 和便携运行时 |

3. 首次启动默认请求管理员权限。若选择不提权，映射通常无法影响以管理员身份运行的前台程序。
4. 主窗口关闭按钮只会隐藏界面，启用的映射仍继续运行；需要彻底停止时使用托盘菜单中的“退出程序”。
5. 当前 18 条内置规则会随完整发行包提供。建议先暂停不需要的规则，再逐条调整为自己的工作流。

便携版不是单文件程序：EXE 会启动同目录中的可编辑 AHK 源码和固定运行时。移动或备份时应保留完整目录。源码版可以双击已关联的 `.ahk` 文件，也可以显式运行：

```powershell
& "C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe" `
  ".\键鼠重映射小助手.ahk"
```

## 2. 添加和管理映射

| 操作 | 作用 |
| --- | --- |
| 新增 | 打开带完整元数据和规则结构的代码编辑器；也可选择 AI 生成 |
| 暂停／恢复 | 批量切换选中规则的启用状态，不删除规则代码 |
| 删除 | 删除选中规则；误操作可立即撤销 |
| 双击／F2 | 编辑选中规则的完整 `@mapping` 代码 |
| 右键 | 编辑代码、AI 优化，以及批量设置或清除序号圆点颜色 |
| 拖动 | 单条或多条规则一起调整永久顺序，并同步改写脚本中的代码块顺序 |
| 点击表头 | 只改变当前显示顺序，不改写脚本；再次点击可切换方向或回到自定义顺序 |

主列表可用 `Ctrl+Z` 撤销，使用 `Ctrl+Shift+Z` 重做。列表重排、暂停、恢复、删除、编辑和导入规则包都使用同一事务历史；若脚本已被外部程序改动，小助手不会无条件覆盖新内容。

列表中的长文本只有在实际被截断时才显示完整悬浮提示。序号圆点只用于视觉分组，不参与优先级、条件或运行逻辑。

## 3. 录制、状态与事件

1. 点击“录制来源按键”，按下要被替换的键或组合键。
2. 点击“录制目标按键”，按下希望发送的键或组合键。
3. 填写名称，按需勾选“区分左右修饰键”，然后保存映射。

录制期间，小助手会先暂停当前重映射并启动专用输入保护进程，避免启用中的规则或系统快捷键抢走正在录制的输入。界面会显示规范按键名、阅读友好名称、虚拟键码和扫描码。`Esc` 是否取消录制可在设置中调整；所有物理按键释放后才恢复映射，降低卡键和误触发风险。

## 4. 规则块、受托管脚本与 AI

每条规则都保存在一对 `; @mapping-begin` 与 `; @mapping-end` 标记之间，并带有名称、类型、来源按键、映射结果和生效范围五项元数据。

| 形式 | 适合 | 运行方式 |
| --- | --- | --- |
| 规则块 | 单一触发源、组合键、短按／长按／松开分支、条件和标准动作序列 | 解析注释化 JSON 后，在小助手主进程中注册并热应用 |
| 受托管脚本 | 多个独立热键、共享状态、循环、定时器、自定义函数、外部调用或任意 AHK v2 能力 | 由小助手在独立 AutoHotkey v2 进程中启动、暂停、恢复和停止 |

规则块默认抑制来源输入；需要保留原按键时可以设置 `passthrough`。多个同时满足的规则按优先级和脚本顺序处理。受托管脚本拥有任意代码能力，新增或导入时会单独确认，保存前还会检查占位文字是否已经替换。

完整 AHK v2 脚本不应重复宿主已经注入的 `#Requires AutoHotkey v2.0 64-bit`、`#NoTrayIcon` 和管理代码，也不应使用 `#SingleInstance Force`、无条件 `ExitApp` 或 `Reload` 干扰托管生命周期。

### AI 生成与优化

在“设置 → AI 设置”中填写 API 地址、密钥和模型，并先测试连接。小助手支持常见 OpenAI Chat／Responses 兼容接口及其可识别变体；具体可用能力、费用、隐私政策和内容限制由您选择的服务提供方决定。

- “AI 生成规则”只有一个入口。AI 会先根据完整的规则块能力边界和 AHK v2 脚本能力判断形式，不要求用户预选。
- 生成结果直接进入代码编辑器，不再经过单独预览页；用户审阅后才保存。
- “AI 优化规则”会显示带语法高亮和差异行高亮的审阅窗口，接受后再写回编辑器。
- 返回内容会经过代码围栏清理、字段别名归一化、数组和标量修正、按键名称规范化、未知字段检查、RuleSpec 语义校验和 AHK v2 语法／启动验证。
- 请求失败、格式不合格或用户取消时，原规则不会被覆盖，下次打开会保留上次输入。
- 等待界面会显示正在连接、等待响应、解析、规范化或验证等具体阶段和当前等待时间。

AI 不是本地模型。只有在用户主动生成、优化或测试连接时，相关提示、当前规则和必要的能力说明才会发送到配置的服务地址。请不要把不希望交给该服务商的敏感路径、账号、密钥或业务内容放入请求。

## 5. 设置

| 设置页 | 内容 |
| --- | --- |
| 显示 | 界面语言、内容字体、跟随系统／浅色／深色主题 |
| 启动 | 桌面和开始菜单快捷方式、计划任务开机启动、管理员运行、启动检查更新、启动显示主窗口 |
| AI 设置 | API 地址、密钥、模型、最长等待时间和生成／优化／系统提示词 |
| 规则与事件 | 导入或导出规则包、事件缓冲区容量、Esc 取消录制、自动跟随最新事件 |

“帮助”可以打开使用说明、事件查看或问题反馈。“关于”显示小助手版本、实际运行形态和 AutoHotkey 版本，可手动检查更新或打开项目地址。更新程序会校验正式 Release 和完整发行包，保留当前 `@mapping` 区域以及不属于发行包管理范围的个人设置；失败时回滚旧文件。

事件查看适合判断“来源输入是否被录到”“哪条规则匹配”“条件为何拒绝”“动作是否执行”以及脚本运行是否失败。导出的 JSONL 可能包含应用、窗口或按键信息，公开前应自行检查并删除敏感内容。

## 6. 事件、诊断和隐私

规则代码保存在实际运行目录的 `键鼠重映射小助手.ahk` 中。AI 设置、显示与启动设置位于 `%APPDATA%\KeyMouseRemapperAssistant\settings.ini`；规则圆点、窗口布局和运行辅助状态也保存在同一应用数据目录。建议同时备份入口 AHK 文件和该应用数据目录。

正式便携版与源码版均执行以下隐私边界：

- 固定包含当前 18 条内置规则，但不包含构建电脑后来产生的个人规则版本。
- 不包含本机 `settings.ini`、`runtime.ini`、`rule-appearance.json` 或 `window-layout.ini`。
- 不包含本机 AI 地址、API 密钥、模型名称、自定义生成提示词、自定义优化提示词或自定义系统提示词。
- 构建会扫描文本发行内容；一旦发现本机 AI 参数或禁止的用户状态文件便直接失败。

项目本身不提供云端账号、遥测或自动上传。使用 AI 时，请求会直接发往用户配置的第三方服务；使用“提交反馈”或手动分享事件文件时，上传行为由用户主动完成。

# Star History

[![Star History Chart](https://api.star-history.com/svg?repos=realSilasYang/key-mouse-remapper-assistant&type=Date)](https://star-history.com/#realSilasYang/key-mouse-remapper-assistant&Date)

# 开发者指南

## 1. 目录与职责

| 路径 | 职责 |
| --- | --- |
| `键鼠重映射小助手.ahk` | 固定入口与 18 条内置 `@mapping` 规则 |
| `app/` | 应用编排、主窗口、编辑器、设置、帮助和事件界面 |
| `src/Core/` | 规则解析、编译、运行、AI、历史、规则包和应用更新 |
| `src/Input/` | Raw Input 观察、输入录制与录制保护 |
| `src/Localization/` | 13 种界面语言及字体解析 |
| `src/Platform/` | Win32、窗口层级、系统集成和便携启动 |
| `src/UI/` | 主题、SVG、圆角按钮、语法分析和通用交互 |
| `runtime/` | 应用更新辅助脚本及本地化文本 |
| `tests/` | 核心、静态和非交互 GUI 回归测试 |
| `tools/` | 锁定工具链、构建和发布包安全检查 |

## 2. 正确性边界

```text
规则块 -> DirectHotkeyRuntime -> AutoHotkey Hotkey() -> 标准动作
受托管脚本 -> ScriptRuleRuntime -> 独立 AutoHotkey v2 进程
Raw Input -> EventTraceService -> 事件查看
录制保护进程 -> 被抑制的低级输入副本 -> KeyCaptureSession
Consumer Control HID -> 浏览器／媒体／启动键 -> KeyCaptureSession
```

规则块在应用进程内注册热键；受托管脚本通过命名停止、暂停和就绪信号管理独立进程。录制保护只在录制期间拦截输入，不承担规则执行或 GUI 工作。映射区域写入采用跨进程锁、快照比较和原子替换，避免编辑器、拖动和外部修改互相覆盖。安全桌面和安全注意序列始终位于用户模式程序的能力边界之外。

## 3. 验证命令

先准备仓库锁定的 AutoHotkey 和 Ahk2Exe 工具链：

```powershell
.\tools\bootstrap-toolchain.ps1
```

运行默认验证：

```powershell
.\tests\verify.ps1 `
  -AutoHotkeyPath .\.tools\autoHotkey-2.0.26\AutoHotkey64.exe
```

加入非交互 GUI 视觉和布局测试：

```powershell
.\tests\verify.ps1 `
  -AutoHotkeyPath .\.tools\autoHotkey-2.0.26\AutoHotkey64.exe `
  -IncludeGui
```

两项会真实拦截桌面输入的集成测试不属于默认验证，不能在无人值守或远程环境中贸然运行。

## 4. 发布与贡献

```powershell
.\tools\build-release.ps1
```

构建固定生成完整便携 ZIP 和完整源码 ZIP。两者都包含当前 18 条内置规则、README、更新日志和许可证；源码版额外包含测试，便携版额外包含编译 EXE、固定 AutoHotkey v2 x64 运行时及对应源码归档。发布脚本拒绝用户状态文件和本机 AI 参数，并为同一输入生成确定性 ZIP。

版本条目遵循[更新日志模板](docs/changelog-template.md)，正式说明保存在 `docs/release-notes/v<版本>.md`。完整步骤见[发布流程](docs/release-process.md)。第三方组件、固定版本和许可证见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。

### 许可证

本项目使用 [MIT License](LICENSE)。AutoHotkey、resvg、Lucide 和 Noto 字体分别按各自许可证分发，详见第三方声明和发行包内对应许可证文件。
