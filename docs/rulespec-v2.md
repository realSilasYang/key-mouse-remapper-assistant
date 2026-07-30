# RuleSpec v2

RuleSpec 是键鼠重映射小助手唯一可执行的规则模型。规则以注释化 JSON 保存在入口脚本中；
项目不接受 raw AHK 映射，也不会在映射区域注册 AHK 热键。

## 规则包络

```ahk
; @mapping-begin
; @schema=2
; @mode=managed
; @id=caps-to-escape
; @spec-begin
; { ...规范化 RuleSpec JSON... }
; @spec-end
; @generated-sha256=...
; @generated-begin
; 此规则由托管运行时注册；此区域不包含可手工编辑的 AHK 代码。
; @generated-end
; @mapping-end
```

`@id` 必须与 JSON 中的 `id` 一致。所有包络标记必须恰好出现一次，摘要必须等于规范化
JSON 的 SHA-256。映射区域每一行只能为空或以分号开头；任何可执行 AHK 都会拒绝整个
加载或写入事务。

## 最小规则

```json
{
  "schema": 2,
  "id": "caps-to-escape",
  "enabled": true,
  "description": "CapsLock 追加 Escape",
  "display": {
    "source": "CapsLock",
    "target": "Escape",
    "scope": "指定键盘",
    "purpose": "减少手指移动"
  },
  "from": {
    "event": "down",
    "key": { "kind": "keyboard", "name": "CapsLock" }
  },
  "conditions": [
    { "type": "device", "operator": "equals", "value": "stable-id" }
  ],
  "to": [
    { "type": "send", "value": "{Escape}" }
  ]
}
```

规范化会补齐可选数组、计时、重复策略、优先级和 `stop_processing`。候选规则先按优先级
降序，再按源码块顺序执行；`stop_processing=true` 会在命中后停止处理同一来源的后续规则。

## 输入

`from.event` 为 `down` 或 `up`。`from.key` 描述键盘、鼠标按钮、滚轮或应用命令，并可保存
名称、VK、SC、扩展位和 usage。`modifiers` 支持左右侧明确的 Ctrl、Shift、Alt、Win；通用
修饰键在运行时匹配任一侧，显式侧别仍保持严格。

复杂手势使用：

- `simultaneous`：无序同时键集合；
- `sequence`：有序按键序列；
- `tap_count`：1 到 8 次连续点击；
- `repeat`：`allow`、`ignore` 或 `only`。

同时键和序列至少包含两个键，不能同时存在。时间窗口由 `timing` 控制，字段可写具体毫秒
或 `inherit`，按内建默认、全局、规则逐层覆盖。

每个 Raw Input 事件必须带有效设备 ID。规则状态键为 `ruleId|deviceId`，因此相同规则在两把
键盘上不会共享按住、序列、长按、重复或输出所有权。

## 条件

条件类型包括 `application`、`window`、`variable`、`input_source`、
`session`、`device`、`all`、`any` 和 `not`。普通比较支持 `equals`、`not_equals`、
`contains`、`starts_with`、`ends_with`、`regex`、`in`、`not_in`、`exists` 等操作符。

GUI 录制会把第一台产生有效事件的实体设备设为捕获设备，并在保存时生成 `device` 条件。
其他设备在本次捕获结束前被忽略。

## 动作

动作包括 `send`、`text`、`key_down`、`key_up`、`mouse`、`app_command`、
`set_variable`、`switch_layer`、`one_shot_modifier`、
`sticky_modifier`、窗口动作和 `run`。`run` 默认受安全策略阻止。

动作可以位于 `to`、`to_if_alone`、`to_if_held_down`、`to_if_other_key_pressed`、
`to_after_key_up`、`to_delayed_if_invoked` 和 `to_delayed_if_canceled`。固定间隔重复由共享
调度器管理，并在来源释放、设备移除、规则热应用、挂起或退出时取消。

`key_down` 输出先登记 owner 再发送，释放时先发送 `key_up` 再删除最后 owner。这个顺序和
恢复日志用于降低异常退出后粘键风险，但不能提供实时或安全关键保证。

## 能力边界

Raw Input 能区分实体设备，但不能取消 Windows 原输入，所以所有动作都是附加输出。
设备和资源限制见[安全和限制](security-and-limits.md)，运行时实际能力可用下列命令查看：

```powershell
.\键鼠重映射小助手-CLI.ps1 capabilities --pretty
```
