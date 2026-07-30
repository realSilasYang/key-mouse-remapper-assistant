# 贡献指南

键鼠重映射小助手面向 64 位 Windows 10/11，开发和验证统一使用锁定的
AutoHotkey `2.0.26`。提交变更前应先从源码确认行为边界，不把已有测试当作设计依据；
测试用于防止已经确认的契约回退。

## 架构约束

- `RawInputBackend` 是唯一输入后端，输入只能来自 Windows Raw Input。
- Raw Input 只识别实体设备，不抑制、替换或隐藏 Windows 原输入。
- 映射区域只允许 `@mode=managed` 的 RuleSpec v2 注释块，禁止可执行 AHK。
- 不得重新引入驱动、低级钩子、AHK 热键后端或第二套输入 worker。
- 输入事件没有 `stable_id` 时不得执行规则；运行时状态和输出 owner 必须按设备隔离。
- 设备移除、重绑、规则热应用、挂起和退出必须释放对应状态与合成输出。
- GUI 对象、消息回调、计时器、子类化、图标和 GDI 资源必须有明确的生命周期所有者。
- 表头排序只影响视图；只有列表拖动排序可以写回规则顺序。
- 持久文件读取必须有字节与字符上限，写入必须保留并发快照和原子替换语义。
- 不提交 `.tools/`、`.build/` 或 `dist/`。

## 更名约束

产品中文名统一为“键鼠重映射小助手”，英文名统一为
“Keyboard & Mouse Remapper Assistant”。代码标识、入口和发行前缀分别使用
`KeyMouseRemapperAssistant`、`键鼠重映射小助手` 和
`key-mouse-remapper-assistant`。旧名称只能出现在明确的迁移兼容列表和迁移文档中。

## 验证

```powershell
./tests/verify.ps1 -SkipGui `
  -AutoHotkeyPath ./.tools/autoHotkey-2.0.26/AutoHotkey64.exe

./tests/verify.ps1 `
  -AutoHotkeyPath ./.tools/autoHotkey-2.0.26/AutoHotkey64.exe

./tests/reproducible-build.ps1
```

GUI 测试需要已解锁的交互式桌面；涉及真实设备身份时，还要按
[`tests/gui/MANUAL-REGRESSION.md`](tests/gui/MANUAL-REGRESSION.md) 使用至少两把键盘和
两只鼠标验证。拉取请求应说明执行过的验证和仍未覆盖的风险。
