# 键鼠重映射小助手

Windows 10/11 上的 AutoHotkey v2 键鼠映射管理器。项目只使用 Windows Raw Input
区分实体键盘和鼠标，不需要内核驱动、驱动签名或低级输入钩子。

## 关键边界

- Raw Input 能识别事件来自哪一个实体设备。
- 程序不会阻止原按键或鼠标事件；规则产生的是附加输出。
- 规则只能保存为 `@mode=managed` 的 RuleSpec v2 注释块。
- 映射区域禁止任何可执行 AHK 代码，因此不会暗中注册热键或钩子。
- 设备条件使用 Raw Input 设备的 `stable_id`。设备移除、重绑和系统唤醒都会清理该设备的
  修饰键、长按、组合、重复和输出所有权状态。
- GUI 默认把输入处理放在一个经过认证 IPC 监督的 `input-worker` 中；
  `--single-process` 仅供诊断和测试。

Raw Input 适合“识别是哪把键盘/哪只鼠标，并据此追加动作”。如果需求是吞掉、替换或阻止
原始物理输入，Raw Input 本身做不到，本项目也不宣称支持。

## 使用

要求 64 位 Windows 和 AutoHotkey `2.0.26`。

```powershell
# 源码运行
& .\.tools\autoHotkey-2.0.26\AutoHotkey64.exe .\键鼠重映射小助手.ahk

# CLI
.\键鼠重映射小助手-CLI.ps1 capabilities --pretty
.\键鼠重映射小助手-CLI.ps1 devices --pretty
.\键鼠重映射小助手-CLI.ps1 list --pretty
```

GUI 中录制来源按键时，捕获会固定到第一个产生事件的实体设备。保存的规则自动加入该设备
的 `stable_id` 条件。换一把键盘或一只鼠标录制，会得到不同的设备条件。

程序保留当前入口中的 15 条 managed 映射。由于不抑制物理输入，例如 `F1` 的短按仍由
Windows 正常接收；长按规则只额外发送录屏组合键。

## RuleSpec

映射区域是源码中的唯一规则事实来源：

```ahk
; @mapping-begin
; @schema=2
; @mode=managed
; @id=example
; @spec-begin
; { ... RuleSpec v2 JSON ... }
; @spec-end
; @generated-sha256=...
; @generated-begin
; 此规则由托管运行时注册；此区域不包含可手工编辑的 AHK 代码。
; @generated-end
; @mapping-end
```

仓储在写入前执行并发快照检查、RuleSpec 规范化、SHA-256 校验和完整脚本语法检查。
规则包也只接受 managed RuleSpec，并对整个 JSON 包做 SHA-256 完整性校验。
所有规则属于同一个全局规则集，不存在规则分组或自动切换机制。

规则字段、动作、条件和设备匹配见 [RuleSpec v2](docs/rulespec-v2.md)。旧 managed schema
的升级方式见[迁移指南](docs/migration.md)。

## CLI

主要命令：

```text
list
validate <package-path>
export <package-path>
import <package-path> [skip|replace|rename]
enable|disable <rule-id>
conflicts
simulate <event-json> [context-json]
capabilities
devices
lint | format | migrate
diagnose [output-path]
variables ...
version
```

完整参数见 [CLI](docs/cli.md)。CLI 修改规则后会通知正在运行的 GUI 直接热应用，不会重载
脚本。

## 架构

```text
Raw Input -> RawInputService -> RawInputBackend -> ManagedRuleRuntime -> Send/Run/窗口动作
                    |                    |
                 stable_id          按设备隔离状态
```

GUI 进程负责界面、编辑和历史；唯一的无托盘 input worker 负责 Raw Input、规则状态机与输出。
worker 作为受主程序监督的独立后台进程运行，但不会创建第二个托盘入口。
命名管道使用当前用户 SID、随机会话密钥、PID 校验和认证消息。详细设计见
[架构](docs/architecture.md)，安全边界见[安全和限制](docs/security-and-limits.md)。

## 验证

旧测试不是设计依据；实现契约来自源码和 Windows Raw Input 行为。当前自动化用于回归这些
已确认的契约：

```powershell
# 非侵入完整门禁
.\tests\verify.ps1 -SkipGui `
  -AutoHotkeyPath .\.tools\autoHotkey-2.0.26\AutoHotkey64.exe

# 包含 GUI 冒烟
.\tests\verify.ps1 `
  -AutoHotkeyPath .\.tools\autoHotkey-2.0.26\AutoHotkey64.exe

# 可复现发行
.\tests\reproducible-build.ps1
```

物理设备验收需要实际操作至少两把键盘和两只鼠标；枚举到设备不等于已证明设备独立输入。
验证范围见[验证矩阵](docs/validation-matrix.md)。

## 构建

```powershell
.\tools\bootstrap-toolchain.ps1
.\tools\build-release.ps1
```

发行包 manifest 固定声明 `inputBackend: raw-input`、`requiresDriver: false` 和
`suppressesOriginalInput: false`。打包说明见[发行打包](docs/packaging.md)。

## 许可证

项目代码使用 [MIT License](LICENSE)。第三方组件与字体授权见
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) 和 `assets/fonts/` 下的授权文件。
