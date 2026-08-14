# 发布流程

**简体中文** | [English](en/release-process.md)

正式版本以 `VERSION`、更新日志、独立 Release Notes、完整验证和确定性发行包为一组不可拆分的交付。普通开发提交不得提前创建版本标签，发布物不得携带本机用户状态或 AI 参数。

1. 按[更新日志模板](changelog-template.md)整理面向用户的版本条目，并创建 `docs/release-notes/v<版本>.md`。同步更新 `VERSION`、中文更新日志和英文镜像日志。版本标题必须使用 `## 🎉 版本 [X.Y.Z] - YYYY-MM-DD`。
2. `⚠️ 重要说明` 默认省略，只有不兼容数据或配置、数据丢失风险、破坏性的最低环境／权限／默认行为变化，或用户必须迁移、备份、替换时才加入，并明确受影响对象、风险和必要操作。
3. 每个 CHANGELOG 版本必须保留 `📦 发布物说明`，按 GitHub 展示顺序列出完整源码 ZIP 和完整便携 ZIP，并写清文件名、内容、AutoHotkey 要求和适用场景。Release Notes 使用同一条目作为事实源，但把发布物说明放在正文最后。
4. CHANGELOG、Release Notes 和 GitHub Release 正文不得加入“✅ 验证范围”，不得列测试数量、构建哈希、SHA-256 或未完成的人工矩阵。验证证据和摘要只保存在测试输出、构建日志与 GitHub 资产摘要中。
5. 确认仓库已取得完整历史与标签，工作树只包含本次发布内容。检查 README 的 13 个语言入口、界面图、下载说明、功能边界、隐私说明和开发命令与当前代码一致。
6. 准备锁定工具链并运行完整验证：

   ```powershell
   .\tools\bootstrap-toolchain.ps1
   .\tests\verify.ps1 `
     -AutoHotkeyPath .\.tools\autoHotkey-2.0.26\AutoHotkey64.exe `
     -IncludeGui
   ```

   两项会真实拦截桌面输入的集成测试不属于无人值守发布门禁，只有在明确可控制本机输入时才单独运行。
7. 运行 `.\tools\build-release.ps1`。构建必须恰好生成两个公开附件：完整源码 ZIP 和完整便携 ZIP；两个包都包含当前 18 条规则、13 语 README、双语更新日志和许可证，源码版额外包含测试，便携版额外包含编译 EXE、固定运行时及对应源码归档。
8. 解压检查两个 ZIP：`builtInRuleCount` 必须为 18，`bundlesUserSettings` 必须为 `false`；不得出现 `settings.ini`、`runtime.ini`、`rule-appearance.json` 或 `window-layout.ini`。再确认发行文本不含本机 AI 地址、密钥、模型或自定义提示词，并用便携 EXE 运行 `--startup-validation`。
9. 提交全部源码、测试和文档并推送 `main`。全部检查通过后才创建 `v<版本>` 标签；标签必须指向 `main` 历史中的发布提交。除非发布者明确要求修订仍处于维护中的同一版本，否则不要移动已公开标签，而应发布新的补丁版本。
10. GitHub Release 标题使用“键鼠重映射小助手 X.Y.Z”，正文原样采用 `docs/release-notes/v<版本>.md`，只上传模板规定的两个 ZIP。上传后重新下载附件，核对 GitHub 资产摘要、文件名、包内清单、启动验证和标签提交。

发布包不签名。若以后加入代码签名，应先完成确定性未签名构建，再单独记录签名产物与证书信息；不得用签名步骤掩盖基础构建不一致。
