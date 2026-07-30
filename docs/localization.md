# 本地化

简体中文界面原文同时是稳定翻译键。所有用户可见文本必须通过 `Tr()` 进入
`LocalizationService`；简体中文直接使用稳定键，其余 12 种语言从独立目录文件读取。
缺失翻译会在运行时回退简体中文，但测试把任何生产调用缺项视为失败，因此正式版本
不允许依赖静默回退。

## 支持的语言

语言顺序是公共界面契约，设置下拉框和测试必须保持一致：

| 代码 | 显示名称 | 目录 |
| --- | --- | --- |
| `zh-CN` | 简体中文 | 稳定键原文 |
| `zh-HK` | 繁體中文（香港） | `TraditionalHongKongStrings.ahk` |
| `zh-TW` | 繁體中文（台灣） | `TraditionalTaiwanStrings.ahk` |
| `en-US` | English | `EnglishStrings.ahk` |
| `ja-JP` | 日本語 | `JapaneseStrings.ahk` |
| `vi-VN` | Tiếng Việt | `VietnameseStrings.ahk` |
| `ko-KR` | 한국어 | `KoreanStrings.ahk` |
| `es-ES` | Español | `SpanishStrings.ahk` |
| `fr-FR` | Français | `FrenchStrings.ahk` |
| `pt-BR` | Português（Brasil） | `PortugueseBrazilStrings.ahk` |
| `ru-RU` | Русский | `RussianStrings.ahk` |
| `de-DE` | Deutsch | `GermanStrings.ahk` |
| `it-IT` | Italiano | `ItalianStrings.ahk` |

设置值 `auto` 表示跟随 Windows 用户界面语言。检测先按完整 LCID 区分简体中文、
香港繁体、台湾繁体与澳门繁体，澳门归入 `zh-HK`；再按主语言 ID 识别其它语言。
不受支持的系统语言回退 `en-US`。输入代码允许常见别名，例如 `zh-Hans`、
`zh-Hant`、`zh-MO`、`en-GB`、`es-MX` 和 `pt-PT`，保存前会归一化为上表代码。

## 翻译契约

1. 以完整简体中文句子调用 `Tr()`，不要拼接可翻译句子。
2. 在全部 12 个目录中加入相同、大小写敏感的稳定键。
3. `{1}`、`{2}` 等格式占位符的编号、出现次数和语义必须保持一致。
4. AHK 源码、规则 ID、`VK`、`SC`、事件类型、JSON 字段、路径和原始系统错误属于
   数据或协议，不翻译。
5. 托盘、伪表头、Owner 子窗口、右键浮层、状态栏、撤销/重做气泡与动态运行状态都必须
   支持进程内热切换，不得依赖 `Reload()`。
6. 已经渲染的动态文本需要切换语言时，使用
   `TranslateRenderedTextBetweenLanguages()`；它按完整模板与占位符反向匹配，
   无法唯一识别时原样保留，避免误翻译用户数据。

`tests/core/localization-tests.ahk` 会扫描入口、`app/` 与 `src/` 中所有字面量
`Tr()` 调用，要求生产键与英文目录双向完全一致，并逐目录检查数量、键集合和占位符。
新增调用但遗漏任一目录、保留失去调用点的旧键，或修改占位符契约都会使验证失败。

## 领域术语与语义审校

翻译不能只满足“非空”和占位符数量正确。键鼠领域中的普通单词必须按界面语义解释：

- `mapping` 是按键映射或重新指派，不是地图、制图或地理区域。
- `key` 是键盘按键，不是密码学密钥、门锁钥匙或数据库键。
- `Win` 是 Windows 徽标键，不是“胜利”；`Shift` 是 Shift 键，不是位移。
- `wheel` 是鼠标滚轮。
- `apply` 表示应用或套用设置，不是求职、申请或数学运算。
- `Resume` 在本项目表示从暂停状态恢复，不是履历或简历。

港繁和台繁必须分别审校。两者可以共享技术缩写和部分句式，但不能只替换地区名称：
香港版本使用“記錄、退出程式、管理員”等当地表达，台湾版本使用“紀錄、結束程式、
系統管理員”等当地表达。

`localization-tests.ahk` 除键集和占位符外，还锁定上述高风险术语，拒绝十六进制生成残片，
并要求港繁与台繁目录保留足够的地区差异。

## 布局与热切换

简体中文、香港繁体、台湾繁体、日文和韩文使用紧凑布局，其余语言使用扩展布局。
`UsesCompactLayout()` 是窗口尺寸和按钮宽度的唯一判断入口；不得在窗口中再次硬编码
`language == "zh-CN"`。语言保存后，应用控制器在临界区内依次更新本地化服务、主题、
主窗口、已打开子窗口、气泡和托盘；任一步失败会恢复旧设置。

语言切换只在内容字体选择为 `auto` 时重新解析默认字体。用户明确选择的已安装字体
必须保持不变。设置下拉框每次展开都会重新枚举字体，允许运行期间补回字体资产后重试。

## 字体策略

| 语言 | 随包内容字体 | Windows 系统 UI |
| --- | --- | --- |
| `zh-CN` | Noto Sans CJK SC | Microsoft YaHei UI |
| `zh-HK` | Noto Sans CJK HK | Microsoft JhengHei UI |
| `zh-TW` | Noto Sans CJK TC | Microsoft JhengHei UI |
| `ja-JP` | Noto Sans CJK JP | Yu Gothic UI |
| `ko-KR` | Noto Sans CJK KR | Malgun Gothic |
| 其它语言 | Noto Sans | Segoe UI |

解析顺序为“已安装的对应 Noto、私有加载随包 Noto、Windows 系统字体”。
按钮、标题、表头和状态栏等界面骨架使用当前语言的 Windows 系统 UI 字体；正文、输入框
和列表使用用户选择的内容字体。随包字体通过
`AddFontResourceExW(FR_PRIVATE)` 只加载到当前进程，失败路径会缓存；主动刷新会清除
失败缓存。退出时必须调用 `ShutdownUiFonts()` 逆序卸载所有资源。

字体均采用 OFL 1.1；许可、上游来源、精简转换和摘要见
[`assets/fonts/metadata.json`](../assets/fonts/metadata.json)。

## 文档

根 `README.md` 是唯一产品总览。核心技术文档位于 `docs/`，不复制 12 份难以同步的完整
README。翻译目录只负责运行时界面；文档变更必须保证所有本地 Markdown 链接可解析，且
能力描述与当前 Raw Input 源码一致。
