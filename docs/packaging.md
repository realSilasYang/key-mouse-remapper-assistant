# 发行打包

## 锁定工具链

`tools/toolchain.lock.json` 固定 AutoHotkey `2.0.26`、Ahk2Exe 和相关下载摘要。

```powershell
.\tools\bootstrap-toolchain.ps1
.\tools\build-release.ps1
```

构建在隔离临时目录中完成，不修改工作区源码。输出位于 `dist/`：

```text
key-mouse-remapper-assistant-<version>-windows-x64/
key-mouse-remapper-assistant-<version>-windows-x64.zip
key-mouse-remapper-assistant-<version>-source/
key-mouse-remapper-assistant-<version>-source.zip
```

正式发布只上传两个 ZIP，不生成或上传 `SHA256SUMS.txt`。便携版包含启动 EXE、
AutoHotkey 最新稳定版 `2.0.26` x64 运行时、CLI、运行所需源码模块、资源、文档和
第三方许可，无需另外安装 AutoHotkey。源码版包含仓库的完整可运行源码、测试、工具、
工作流和文档，不夹带编译 EXE、本机工具缓存或便携运行时。

## Manifest

`build-manifest.json` 的输入字段固定为：

```json
{
  "inputBackend": "raw-input",
  "requiresDriver": false,
  "suppressesOriginalInput": false
}
```

发行物不得含 `native/`、`driver/`、旧输入后端或 raw AHK worker。锁定解释器的 SHA-256
同时写入 manifest；GUI 和 CLI 启动器在执行源码前验证该摘要。

## 可复现性

```powershell
.\tests\reproducible-build.ps1
```

测试用多个隔离输出目录重复构建，分别比较便携版和源码版 ZIP 及关键产物哈希。ZIP 使用
固定文件顺序、时间、压缩方式和 UTF-8 路径。

## 发行验证

```powershell
.\tests\release-artifact-tests.ps1 -OutputRoot .\dist
```

验证内容包括两个 ZIP 的唯一性和文件清单、manifest、运行时摘要、CLI Raw Input 能力、
启动自检、归档内容一致、源码包不夹带运行时、篡改运行时拒绝以及旧输入基础设施不存在。

项目没有需要签名的内核组件。对 GUI EXE 或 ZIP 做 Authenticode/制品签名属于发布渠道策略，
不改变 Raw Input 的能力边界。
