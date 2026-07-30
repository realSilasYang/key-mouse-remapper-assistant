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
SHA256SUMS.txt
```

便携目录包含启动 EXE、可编辑入口源码、CLI、锁定解释器、`app/`、`src/`、唯一
`workers/input-engine-worker.ahk`、资源、文档和第三方许可。

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

测试用多个隔离输出目录重复构建，比较 ZIP 和关键产物哈希。ZIP 使用固定文件顺序、时间、
压缩方式和 UTF-8 路径。

## 发行验证

```powershell
.\tests\release-artifact-tests.ps1 -OutputRoot .\dist
```

验证内容包括文件清单、manifest、运行时摘要、CLI Raw Input 能力、启动自检、ZIP 内容一致、
篡改运行时拒绝以及旧输入基础设施不存在。

项目没有需要签名的内核组件。对 GUI EXE 或 ZIP 做 Authenticode/制品签名属于发布渠道策略，
不改变 Raw Input 的能力边界。
