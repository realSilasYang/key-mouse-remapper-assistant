# CLI

入口：

```powershell
.\键鼠重映射小助手-CLI.ps1 <command> [arguments] [options]
```

全局选项：

```text
--script <path>
--variables-path <path>
--control-path <path>
--pretty
```

## 查询

```text
list
conflicts
capabilities
devices
diagnose [output-path]
version
```

`capabilities` 始终报告 `backend=raw-input`、`device_identification=true`、
`requires_driver=false` 和不抑制原输入。`devices` 返回 Raw Input 当前枚举到的实体接口及
`stable_id`；枚举结果不证明设备已实际产生输入。

## 规则

```text
enable <rule-id>
disable <rule-id>
lint
format
migrate
simulate <event-json> [context-json]
```

`lint` 检查 managed RuleSpec、摘要和冲突。`format` 写回规范 JSON；`migrate` 将受支持的
旧 managed schema 升级到 v2。CLI 不接受或生成可执行 AHK 映射。

## 规则包

```text
validate <package-path>
export <package-path>
import <package-path> [skip|replace|rename]
```

规则包只包含 managed RuleSpec。`skip` 保留本地冲突项，`replace` 在原位置
替换，`rename` 为导入副本生成新 ID。解析会验证严格字段、资源上限和整包 SHA-256。

## 变量

```text
variables [list]
variables set <transient|persistent> <name> <json-value>
variables clear <transient|persistent> <name|--all>
```

`builtin` 变量只读，不能通过 CLI 修改。

成功修改后，CLI 向当前用户的应用控制队列发布 `apply` 请求。正在运行的 GUI 重新读取
变量和全局规则集，并直接热应用到唯一 Raw Input worker。

标准输出是 JSON；参数、验证或持久化错误写入标准错误并返回非零退出码。
