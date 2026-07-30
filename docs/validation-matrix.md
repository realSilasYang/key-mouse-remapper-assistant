# 验证矩阵

源码和 Windows Raw Input 行为是设计事实来源；自动化只用于回归已经确认的契约。单元测试
通过不能替代真实桌面、真实热插拔和多实体设备验证。

## 自动化

| 领域 | 源码事实 | 主要验证 |
| --- | --- | --- |
| 唯一输入链路 | `RawInputService`、`RawInputBackend` | Raw Input service/backend 测试、静态检查 |
| 设备身份与生命周期 | `DeviceIdentityService`、`InputEvent` | 设备身份、输入事件、物理设备证据模型测试 |
| 设备隔离状态 | `ManagedRuleRuntime`、`ManagedRuleStateMachine` | managed runtime、规则调度器测试 |
| 捕获绑定 | `KeyCaptureSession` | 捕获会话和 GUI 冒烟测试 |
| RuleSpec 包络与迁移 | `RuleSpec`、`RuleCompiler`、`RuleSpecMigrationService` | RuleSpec、属性和仓储测试 |
| 条件与变量 | 条件求值器、`ScopedVariableStore` | 条件、变量和模拟测试 |
| 输出所有权与恢复 | `OutputLedger`、`OutputRecoveryJournal` | runtime 和恢复日志测试 |
| 单 worker 与认证 IPC | `InputWorkerController`、`WorkerBootstrap`、管道协议 | worker 集成、认证 IPC、事件缓冲测试 |
| 历史与原子持久化 | 仓储、设置、历史和控制队列 | 对应 core 测试与并发负例 |
| 本地化与界面生命周期 | 本地化目录、窗口、无障碍/提示服务和窗口层级 | 本地化、窗口层级、GUI 冒烟和手工回归 |
| CLI 与规则包 | `CommandLineApp`、`RulePackageService` | CLI、规则包和 launcher 测试 |
| 发行命名与内容 | `build-release.ps1`、manifest | 仓库检查、发行制品和可复现构建测试 |

标准非侵入门禁：

```powershell
.\tests\verify.ps1 -SkipGui `
  -AutoHotkeyPath .\.tools\autoHotkey-2.0.26\AutoHotkey64.exe
```

GUI 冒烟：

```powershell
.\tests\verify.ps1 `
  -AutoHotkeyPath .\.tools\autoHotkey-2.0.26\AutoHotkey64.exe
```

发行验证：

```powershell
.\tools\build-release.ps1
.\tests\release-artifact-tests.ps1 -OutputRoot .\dist
.\tests\reproducible-build.ps1
```

工具链只支持 `tools/toolchain.lock.json` 锁定的 AutoHotkey `2.0.26`。

## 必须人工验证

### 多实体设备

至少连接两把键盘和两只鼠标，分别产生输入并核对：

1. 每台设备都得到非空且互不混淆的 `stable_id`；
2. 绑定键盘 A 的规则不会因键盘 B 的同键触发；
3. 两台设备同时按相同键时，按住、长按、序列和重复状态互不污染；
4. 拔出其中一台设备只释放该设备的状态与输出；
5. 重新插入和系统唤醒后重新枚举并能再次匹配；
6. 原物理输入始终到达 Windows，规则只产生附加输出。

仅执行 `devices` 或看到两个枚举项不算通过，必须实际从每台设备输入。

### 桌面与窗口

- 在浅色、深色和高对比度相关系统设置下检查首帧、主题热切换和原生控件；
- 在 100%、150%、200% DPI 及多显示器上检查窗口居中、裁切、Owner 层级和焦点恢复；
- 检查挂起、唤醒、锁屏返回、worker 故障恢复和退出后没有遗留合成按键；
- 检查设置、映射编辑、事件查看和规则包窗口的文本没有重叠或越界。

详细操作清单见 [`tests/gui/MANUAL-REGRESSION.md`](../tests/gui/MANUAL-REGRESSION.md)。

## 完成标准

版本只有在源码检查、自动化、发行验证和与本次变更相关的真实设备/桌面验证均通过后才算
完成。任何驱动、低级钩子、raw AHK worker、第二输入后端或抑制原输入声明重新出现，都应
视为架构回退。
