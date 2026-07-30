# 迁移指南

## 产品更名

当前产品名为“键鼠重映射小助手”，默认数据目录为
`%APPDATA%\KeyMouseRemapperAssistant`，设置文件为
`key-mouse-remapper-assistant.ini`。

启动时逐文件查找迁移来源，优先级如下：

1. 上一名称目录 `%APPDATA%\KeyMouseRemapper`；
2. 最初名称目录 `%APPDATA%\ShortcutRemapper`。

设置、历史、通知、变量、控制队列、启动健康状态、最后正常配置、输出恢复日志和
崩溃诊断会复制到新目录。新路径已经存在时绝不覆盖；复制失败时该文件继续使用旧路径，
不会静默恢复默认值。

当前规则包 kind 是 `key-mouse-remapper-assistant-rule-package`。导入器仍接受
`key-mouse-remapper-rule-package` 和 `shortcut-remapper-rule-package`，无需手工改写
已有 JSON。

## 规则迁移

当前映射区域只接受 managed RuleSpec。支持的旧 managed schema 会先验证原摘要，再迁移到
schema 2；`format` 或 `migrate` 写回时会重新生成规范 JSON 和 SHA-256。

旧 raw AHK 块不能可靠反编译成结构化设备条件和动作，因此不会猜测式转换，也不会继续
执行。迁移方法是根据原意新建 RuleSpec，明确选择实体设备并验证附加输出，然后删除旧块。
本项目不会抑制原物理输入，迁移时必须把这一语义差异纳入验收。

当前入口中的 15 条内置映射已经转换为 managed RuleSpec v2，源码顺序、显示信息和启用状态
均保留。

当前版本使用单一全局规则集。旧 RuleSpec 的顶层 `profile` 字段会在迁移时删除，规则本身
提升为全局规则；旧 schema 2 规则包中的 `profiles` 和 `profile_write` 仅作为兼容输入忽略，
不会重建分组或自动切换能力。

## 操作建议

```powershell
.\键鼠重映射小助手-CLI.ps1 list --pretty
.\键鼠重映射小助手-CLI.ps1 lint --pretty
.\键鼠重映射小助手-CLI.ps1 migrate --pretty
.\键鼠重映射小助手-CLI.ps1 devices --pretty
```

先备份入口脚本和 AppData，再检查每条规则的 `stable_id`。更换 USB 端口、重装设备或升级
固件后，Windows 设备接口可能变化，应重新录制并确认设备条件。
