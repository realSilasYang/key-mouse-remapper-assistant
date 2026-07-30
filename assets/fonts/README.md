# 界面字体资源

本目录仅保存可随开源项目再分发的 Noto 字体。字体通过 `AddFontResourceExW` 以
`FR_PRIVATE` 方式加载，只在键鼠重映射小助手进程内可见，不会安装到 Windows 或修改
系统字体配置。

- `NotoSans-Variable.ttf`：Noto Sans 2.015 可变字体，覆盖英文、越南文、西班牙文、
  法文、葡萄牙文、俄文、德文和意大利文。
- `NotoSansCJK.ttc`：从 Noto Sans CJK 2.004 官方 45 面集合中提取的五个 Regular
  字体面，分别保留简体中文、香港繁体、台湾繁体、日文和韩文家族。没有对子形进行
  子集化或改名，因而各地区字形仍保持上游定义。

两个文件均采用 SIL Open Font License 1.1，完整许可证见 `OFL-1.1.txt`。来源、版本、
转换方式和 SHA-256 记录在 `metadata.json`。字体作为外置资源进入完整发行包，不嵌入
单个 EXE。
