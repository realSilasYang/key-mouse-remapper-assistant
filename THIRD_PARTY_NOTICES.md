# 第三方软件声明

## AutoHotkey

发行包包含 AutoHotkey v2.0.26 64 位运行时，用于执行用户可编辑的映射源码。

- 上游项目：<https://github.com/AutoHotkey/AutoHotkey>
- 锁定提交：`542510fe0eee2358820a1864ec8b4c9d61b39e0b`
- 许可证：GPL-2.0-only 与 BSD-3-Clause 组件，完整文本见发行包
  `runtime/license.txt`
- 对应源码：发行包 `runtime/sources/AutoHotkey_source_542510fe0eee2358820a1864ec8b4c9d61b39e0b.zip`

AutoHotkey 与本项目彼此独立；上游作者不为本项目提供担保或背书。

## resvg

界面 SVG 栅格化使用 resvg 0.47.0 C API，按 MIT 与 Apache-2.0 双许可
分发；许可证、上游来源与固定构建信息位于 `third_party/resvg/`。

## Interception

设备级输入拦截与识别使用 <https://github.com/oblitum/Interception> 的官方库。
发行包中的 `third_party/interception/` 包含 x64/x86 DLL、头文件、官方命令行安装器、
识别样例以及上游许可证。项目动态加载 DLL，并只在用户明确确认后调用随附的官方
安装器请求管理员权限安装或卸载内核驱动。驱动安装、
商业使用和非商业使用必须分别遵守上游许可证，不能由本项目的 MIT 许可证替代。

## Lucide

界面命令与状态图标来自 lucide-static 1.27.0，按 ISC 许可分发；许可证及版本信息位于
`assets/ui-icons/lucide/`。

## Noto Sans 与 Noto Sans CJK

界面内容字体 `NotoSans-Variable.ttf` 与 `NotoSansCJK.ttc` 按 SIL Open Font
License 1.1 分发；字体仅进入独立的 `fonts.zip`，不进入源码包或便携包。许可证、
上游来源、转换方式与固定文件摘要位于字体包的 `assets/fonts/`。
