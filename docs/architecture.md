# 架构

## 输入链路

项目只有一条物理输入观察链：

```text
WM_INPUT / WM_INPUT_DEVICE_CHANGE
        -> RawInputService
        -> InputEvent + stable_id
        -> RawInputBackend
        -> ManagedRuleRuntime
        -> OutputLedger / InputBackend.EmitAction
```

`RawInputService` 注册键盘和鼠标 Raw Input，解析扫描码、扩展位、按钮、滚轮以及设备生命周期。
`DeviceIdentityService` 从设备接口路径生成稳定身份。事件没有有效设备 ID 时不会执行规则。

`RawInputBackend` 是唯一 `IInputBackend` 实现。它维护每个设备自己的修饰键和重复状态，
将简单来源与复杂来源都送入同一个托管运行时。通用 `Ctrl/Shift/Alt/Win` 可匹配左右任一侧，
显式 `LCtrl/RShift` 等仍保留侧别。

Raw Input 只观察，不抑制 Windows 原事件。`device_specific_suppression` 和
`selective_suppression` 始终为 false。

## 规则运行时

`MappingCodeRepository` 只解析 `@mode=managed` 的 RuleSpec 注释块，并拒绝映射区域内任何
非注释行。所有规则属于同一个全局规则集；`RuleCompiler` 生成描述符，
`RuleConflictAnalyzer` 找出全局静态冲突，
`ManagedRuleRuntime` 按优先级和源码顺序执行可用规则。

状态键使用 `ruleId|deviceId`。以下状态都按设备分区：

- 简单键按住和自动重复；
- 左右/通用修饰键；
- 同时键、序列、多击、单击/长按；
- 定时动作与固定间隔重复；
- 输出按键所有权。

设备移除或重绑时，运行时只取消该设备的状态并释放该设备 owner，其他设备上的同一规则
继续运行。`OutputLedger` 采用先登记 owner 再发送按下、先发送抬起再删除最后 owner 的顺序，
并把持有键写入 `OutputRecoveryJournal` 供异常退出后的下次启动恢复。

## 进程模型

普通启动包含两个进程：

- GUI：编辑、历史、事件展示和进程监督；
- `input-worker`：无托盘的独立后台进程，负责 Raw Input、托管规则状态机和输出。

`InputWorkerController` 创建一次性 DPAPI 启动信封和命名管道。IPC 验证当前用户 SID、双方
PID、随机 session、HMAC、消息序号和心跳。worker 崩溃时记录角色明确的诊断并重启唯一
输入 worker。

`--single-process` 让 GUI 窗口句柄直接承载 Raw Input，用于诊断和 GUI 测试；输入语义不变。

## 捕获

`KeyCaptureSession` 不安装 `InputHook`、热键或系统钩子。它临时观察 Raw Input 流，第一条
有效按下事件选择捕获设备，之后忽略其他设备，直到已记录按键全部释放。设备拔出会终止并
清理捕获。保存时 `RuleSpec.CreateFromCaptures` 自动添加该设备 `stable_id` 条件。

捕获期间托管后端会挂起，避免正在录制的输入额外触发映射；Windows 原输入仍然存在。

## 持久化

规则直接保存在入口脚本的映射区域。写入事务：

1. 读取有界源码快照；
2. 解析所有 managed 块并验证摘要；
3. 规范化 RuleSpec；
4. 生成临时完整脚本并用锁定解释器检查语法；
5. 再次比较原快照，拒绝并发覆盖；
6. 使用 `ReplaceFileW` 原子替换。

设置、变量、历史、控制队列和恢复日志都有独立大小上限与原子写入。CLI 修改后通过
`ApplicationControlQueue` 通知 GUI 热应用。

## 电源和热插拔

休眠前停止捕获、取消活动状态并暂停后端；唤醒后重新注册 Raw Input、枚举设备、重新应用
规则，并恢复用户此前的挂起状态。进程心跳在系统电源挂起期间不判定超时。
