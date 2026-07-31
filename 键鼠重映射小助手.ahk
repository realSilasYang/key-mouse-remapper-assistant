/*
================================================================================
    键鼠重映射小助手
    可视化维护 AutoHotkey v2 重映射规则，支持按键录制、代码块编辑与顺序同步。
================================================================================
*/

;@Ahk2Exe-SetName 键鼠重映射小助手
;@Ahk2Exe-SetDescription 键鼠重映射小助手可视化管理器
;@Ahk2Exe-SetVersion 0.1.1.0
;@Ahk2Exe-SetCopyright Copyright (c) 2026 键鼠重映射小助手 contributors
;@Ahk2Exe-SetMainIcon assets\app\key-mouse-remapper-assistant.ico

#Requires AutoHotkey v2.0 64-bit
#SingleInstance Force
#Warn All, StdOut

#Include src\Core\CommandLine.ahk
#Include src\Localization\EnglishStrings.ahk
#Include src\Localization\TraditionalHongKongStrings.ahk
#Include src\Localization\TraditionalTaiwanStrings.ahk
#Include src\Localization\JapaneseStrings.ahk
#Include src\Localization\VietnameseStrings.ahk
#Include src\Localization\KoreanStrings.ahk
#Include src\Localization\SpanishStrings.ahk
#Include src\Localization\FrenchStrings.ahk
#Include src\Localization\PortugueseBrazilStrings.ahk
#Include src\Localization\RussianStrings.ahk
#Include src\Localization\GermanStrings.ahk
#Include src\Localization\ItalianStrings.ahk
#Include src\Localization\LocalizationService.ahk
#Include src\UI\UiThemeService.ahk
#Include src\Config\AppDataPaths.ahk
#Include src\Config\AppSettingsService.ahk
#Include src\Core\BoundedFileReader.ahk
#Include src\Core\JsonCodec.ahk
#Include src\Core\Sha256.ahk
#Include src\Core\HmacSha256.ahk
#Include src\Core\AuthenticatedIpcProtocol.ahk
#Include src\Core\CrossProcessWriteLock.ahk
#Include src\Core\CrashRecoveryService.ahk
#Include src\Core\ApplicationControlQueue.ahk
#Include src\Core\StartupHealthService.ahk
#Include src\Core\OutputRecoveryJournal.ahk
#Include src\Core\ApplicationVersionInfo.ahk
#Include src\Core\RuleSpec.ahk
#Include src\Core\DeviceIdentityService.ahk
#Include src\Core\InputEvent.ahk
#Include src\Core\RuleTimingResolver.ahk
#Include src\Core\RuleSpecMigrationService.ahk
#Include src\Core\RuleCompiler.ahk
#Include src\Core\RuleConflictAnalyzer.ahk
#Include src\Core\RuleSimulationService.ahk
#Include src\Core\EventTraceService.ahk
#Include src\Core\DiagnosticBundleService.ahk
#Include src\Core\ScopedVariableStore.ahk
#Include src\Core\RuleConditionEvaluator.ahk
#Include src\Core\ManagedRuleStateMachine.ahk
#Include src\Core\RuleScheduler.ahk
#Include src\Core\OutputLedger.ahk
#Include src\Core\InputBackend.ahk
#Include src\Platform\Win32.ahk
#Include src\Input\RawInputObservationPolicy.ahk
#Include src\Input\RawInputService.ahk
#Include src\Core\RawInputBackend.ahk
#Include src\Core\ManagedRuleRuntime.ahk
#Include src\Core\RulePackageService.ahk
#Include src\Core\MappingCodeRepository.ahk
#Include src\Core\PersistentHistoryService.ahk
#Include src\Platform\PackagedLauncher.ahk
#Include src\Platform\NamedPipeChannel.ahk
#Include src\Process\WorkerBootstrap.ahk
#Include src\Platform\WindowsContextService.ahk
#Include src\Platform\WindowHierarchy.ahk
#Include src\UI\ThemeHelpers.ahk
#Include src\UI\ApplicationIcon.ahk
#Include src\UI\CleanupCollector.ahk
#Include src\UI\SvgRenderLibrary.ahk
#Include src\UI\RoundedButtonPainter.ahk
#Include src\UI\ControlAccessibilityService.ahk
#Include app\Windows\DarkTooltipWindow.ahk
#Include src\UI\MappingUiInteractions.ahk
#Include app\UI\DarkMessageBox.ahk
#Include src\UI\ListViewPseudoHeader.ahk
#Include src\Input\KeyCaptureSession.ahk
#Include app\UI\ListViewSelectionPresenter.ahk
#Include app\Windows\ListCellTooltipWindow.ahk
#Include app\Windows\HistoryToastWindow.ahk
#Include app\Windows\MappingContextPopupWindow.ahk
#Include app\Windows\EventViewerWindow.ahk
#Include app\Windows\SupportInfoWindow.ahk
#Include app\Windows\HelpWindow.ahk
#Include app\Windows\DonationWindow.ahk
#Include app\Windows\RulePackageImportWindow.ahk
#Include app\Windows\SettingsWindow.ahk
#Include app\Windows\MappingBlockEditor.ahk
#Include app\Windows\MappingWindow.ahk
#Include src\Process\InputWorkerController.ahk
#Include app\KeyMouseRemapperAssistantApp.ahk

if HasCommandLineFlag("--syntax-check")
    ExitApp()

; 编译产物只负责启动发行包内的固定版本解释器与可编辑源码。这样 GUI 对
; @mapping 代码块的保存、排序和任意 AHK 规则编辑在发行版中仍然完整可用。
if A_IsCompiled
    ExitApp(LaunchPackagedSource() ? 0 : 1)

if HasCommandLineFlag("--startup-validation")
    ExitApp()

; 源码模式与便携运行时都由 AutoHotkey64.exe 承载。必须在创建首个 GUI 前
; 声明独立身份，否则 Windows 会把任务栏按钮归入其它 AHK 脚本并继承其图标。
ConfigureApplicationShellIdentity()

; GUI 与 input worker 都只通过 Raw Input 观察实体设备；源码中不注册热键。
global App := KeyMouseRemapperAssistantApp()
EnableDarkProcessMode()
App.Start()

; === 重映射代码区域开始 ===
; 此区域由 GUI 维护；代码块顺序就是 GUI 的默认显示顺序，请勿删除元数据行。

; @mapping-begin
; @schema=2
; @mode=managed
; @id=word-styles
; @spec-begin
; {
;   "conditions": [
;     {
;       "case_sensitive": false,
;       "field": "process",
;       "negate": false,
;       "operator": "equals",
;       "type": "application",
;       "value": "WINWORD.EXE"
;     }
;   ],
;   "description": "快速切换 Word 样式窗格并把焦点交还文档。",
;   "display": {
;     "purpose": "快速切换 Word 样式窗格并把焦点交还文档。",
;     "scope": "Word",
;     "source": "Alt + Z",
;     "target": "样式窗格开关"
;   },
;   "enabled": true,
;   "from": {
;     "event": "down",
;     "hotkey": "",
;     "key": {
;       "extended": false,
;       "kind": "keyboard",
;       "name": "Z"
;     },
;     "modifiers": [
;       "Alt"
;     ],
;     "optional_modifiers": [],
;     "repeat": "ignore",
;     "sequence": [],
;     "simultaneous": [],
;     "tap_count": 1
;   },
;   "id": "word-styles",
;   "priority": 0,
;   "schema": 2,
;   "stop_processing": true,
;   "timing": {
;     "alone_timeout_ms": "inherit",
;     "delayed_action_ms": "inherit",
;     "held_threshold_ms": "inherit",
;     "multi_tap_timeout_ms": "inherit",
;     "sequence_timeout_ms": "inherit",
;     "simultaneous_threshold_ms": "inherit"
;   },
;   "to": [
;     {
;       "repeat": "inherit",
;       "repeat_interval_ms": 0,
;       "type": "send",
;       "value": "!^+s"
;     },
;     {
;       "repeat": "inherit",
;       "repeat_interval_ms": 0,
;       "type": "sleep",
;       "value": "100"
;     },
;     {
;       "repeat": "inherit",
;       "repeat_interval_ms": 0,
;       "type": "send",
;       "value": "{Esc}"
;     }
;   ],
;   "to_after_key_up": [],
;   "to_delayed_if_canceled": [],
;   "to_delayed_if_invoked": [],
;   "to_if_alone": [],
;   "to_if_held_down": [],
;   "to_if_other_key_pressed": []
; }
; @spec-end
; @generated-sha256=C1F751679219BA9D139E7E4A09CE3DC9EAEFC7BD29B150FCFD3A4EFB09C95693
; @generated-begin
; 此规则由托管运行时注册；此区域不包含可手工编辑的 AHK 代码。
; @generated-end
; @mapping-end

; @mapping-begin
; @schema=2
; @mode=managed
; @id=shift-wheel-up
; @spec-begin
; {
;   "conditions": [],
;   "description": "用纵向滚轮向左浏览宽页面。",
;   "display": {
;     "purpose": "用纵向滚轮向左浏览宽页面。",
;     "scope": "全局",
;     "source": "Shift + WheelUp",
;     "target": "WheelLeft"
;   },
;   "enabled": true,
;   "from": {
;     "event": "down",
;     "hotkey": "",
;     "key": {
;       "extended": false,
;       "kind": "wheel",
;       "name": "WheelUp"
;     },
;     "modifiers": [
;       "Shift"
;     ],
;     "optional_modifiers": [],
;     "repeat": "ignore",
;     "sequence": [],
;     "simultaneous": [],
;     "tap_count": 1
;   },
;   "id": "shift-wheel-up",
;   "priority": 0,
;   "schema": 2,
;   "stop_processing": true,
;   "timing": {
;     "alone_timeout_ms": "inherit",
;     "delayed_action_ms": "inherit",
;     "held_threshold_ms": "inherit",
;     "multi_tap_timeout_ms": "inherit",
;     "sequence_timeout_ms": "inherit",
;     "simultaneous_threshold_ms": "inherit"
;   },
;   "to": [
;     {
;       "repeat": "inherit",
;       "repeat_interval_ms": 0,
;       "type": "send",
;       "value": "{WheelLeft}"
;     }
;   ],
;   "to_after_key_up": [],
;   "to_delayed_if_canceled": [],
;   "to_delayed_if_invoked": [],
;   "to_if_alone": [],
;   "to_if_held_down": [],
;   "to_if_other_key_pressed": []
; }
; @spec-end
; @generated-sha256=75A6EBB456610EB4BBA6886B113CDA6C33ACAD8AC75F76C7991C9297BF749B70
; @generated-begin
; 此规则由托管运行时注册；此区域不包含可手工编辑的 AHK 代码。
; @generated-end
; @mapping-end

; @mapping-begin
; @schema=2
; @mode=managed
; @id=shift-wheel-down
; @spec-begin
; {
;   "conditions": [],
;   "description": "用纵向滚轮向右浏览宽页面。",
;   "display": {
;     "purpose": "用纵向滚轮向右浏览宽页面。",
;     "scope": "全局",
;     "source": "Shift + WheelDown",
;     "target": "WheelRight"
;   },
;   "enabled": true,
;   "from": {
;     "event": "down",
;     "hotkey": "",
;     "key": {
;       "extended": false,
;       "kind": "wheel",
;       "name": "WheelDown"
;     },
;     "modifiers": [
;       "Shift"
;     ],
;     "optional_modifiers": [],
;     "repeat": "ignore",
;     "sequence": [],
;     "simultaneous": [],
;     "tap_count": 1
;   },
;   "id": "shift-wheel-down",
;   "priority": 0,
;   "schema": 2,
;   "stop_processing": true,
;   "timing": {
;     "alone_timeout_ms": "inherit",
;     "delayed_action_ms": "inherit",
;     "held_threshold_ms": "inherit",
;     "multi_tap_timeout_ms": "inherit",
;     "sequence_timeout_ms": "inherit",
;     "simultaneous_threshold_ms": "inherit"
;   },
;   "to": [
;     {
;       "repeat": "inherit",
;       "repeat_interval_ms": 0,
;       "type": "send",
;       "value": "{WheelRight}"
;     }
;   ],
;   "to_after_key_up": [],
;   "to_delayed_if_canceled": [],
;   "to_delayed_if_invoked": [],
;   "to_if_alone": [],
;   "to_if_held_down": [],
;   "to_if_other_key_pressed": []
; }
; @spec-end
; @generated-sha256=DE068F6E5C20B4588B1495CC44717C8119023AB9F27E659DC0975BBB66EE900F
; @generated-begin
; 此规则由托管运行时注册；此区域不包含可手工编辑的 AHK 代码。
; @generated-end
; @mapping-end

; @mapping-begin
; @schema=2
; @mode=managed
; @id=office-redo
; @spec-begin
; {
;   "conditions": [
;     {
;       "case_sensitive": false,
;       "field": "process",
;       "negate": false,
;       "operator": "in",
;       "type": "application",
;       "value": [
;         "WINWORD.EXE",
;         "EXCEL.EXE",
;         "POWERPNT.EXE"
;       ]
;     }
;   ],
;   "description": "统一 Office 与常用编辑器的重做手势。",
;   "display": {
;     "purpose": "统一 Office 与常用编辑器的重做手势。",
;     "scope": "Word / Excel / PowerPoint",
;     "source": "Ctrl + Shift + Z",
;     "target": "Ctrl + Y（重做）"
;   },
;   "enabled": true,
;   "from": {
;     "event": "down",
;     "hotkey": "",
;     "key": {
;       "extended": false,
;       "kind": "keyboard",
;       "name": "Z"
;     },
;     "modifiers": [
;       "Ctrl",
;       "Shift"
;     ],
;     "optional_modifiers": [],
;     "repeat": "ignore",
;     "sequence": [],
;     "simultaneous": [],
;     "tap_count": 1
;   },
;   "id": "office-redo",
;   "priority": 0,
;   "schema": 2,
;   "stop_processing": true,
;   "timing": {
;     "alone_timeout_ms": "inherit",
;     "delayed_action_ms": "inherit",
;     "held_threshold_ms": "inherit",
;     "multi_tap_timeout_ms": "inherit",
;     "sequence_timeout_ms": "inherit",
;     "simultaneous_threshold_ms": "inherit"
;   },
;   "to": [
;     {
;       "repeat": "inherit",
;       "repeat_interval_ms": 0,
;       "type": "send",
;       "value": "^y"
;     }
;   ],
;   "to_after_key_up": [],
;   "to_delayed_if_canceled": [],
;   "to_delayed_if_invoked": [],
;   "to_if_alone": [],
;   "to_if_held_down": [],
;   "to_if_other_key_pressed": []
; }
; @spec-end
; @generated-sha256=9EB484361A0B355EDEA31A87914FD880EE591FDF686D842C663793A4A5930E8C
; @generated-begin
; 此规则由托管运行时注册；此区域不包含可手工编辑的 AHK 代码。
; @generated-end
; @mapping-end

; @mapping-begin
; @schema=2
; @mode=managed
; @id=ctrl-space-middle
; @spec-begin
; {
;   "conditions": [],
;   "description": "按住组合键时附加鼠标中键。",
;   "display": {
;     "purpose": "按住组合键时附加鼠标中键。",
;     "scope": "全局",
;     "source": "Ctrl + Space",
;     "target": "MButton（按住）"
;   },
;   "enabled": true,
;   "from": {
;     "event": "down",
;     "hotkey": "",
;     "key": {
;       "extended": false,
;       "kind": "keyboard",
;       "name": "Space"
;     },
;     "modifiers": [
;       "Ctrl"
;     ],
;     "optional_modifiers": [],
;     "repeat": "ignore",
;     "sequence": [],
;     "simultaneous": [],
;     "tap_count": 1
;   },
;   "id": "ctrl-space-middle",
;   "priority": 0,
;   "schema": 2,
;   "stop_processing": true,
;   "timing": {
;     "alone_timeout_ms": "inherit",
;     "delayed_action_ms": "inherit",
;     "held_threshold_ms": "inherit",
;     "multi_tap_timeout_ms": "inherit",
;     "sequence_timeout_ms": "inherit",
;     "simultaneous_threshold_ms": "inherit"
;   },
;   "to": [
;     {
;       "repeat": "inherit",
;       "repeat_interval_ms": 0,
;       "type": "key_down",
;       "value": "MButton"
;     }
;   ],
;   "to_after_key_up": [
;     {
;       "repeat": "inherit",
;       "repeat_interval_ms": 0,
;       "type": "key_up",
;       "value": "MButton"
;     }
;   ],
;   "to_delayed_if_canceled": [],
;   "to_delayed_if_invoked": [],
;   "to_if_alone": [],
;   "to_if_held_down": [],
;   "to_if_other_key_pressed": []
; }
; @spec-end
; @generated-sha256=98F6FCABCF460630C230617DB88369104715772E9309AE192505F5224947238B
; @generated-begin
; 此规则由托管运行时注册；此区域不包含可手工编辑的 AHK 代码。
; @generated-end
; @mapping-end

; @mapping-begin
; @schema=2
; @mode=managed
; @id=f1-bandicam
; @spec-begin
; {
;   "conditions": [],
;   "description": "F1 原输入始终保留，长按时附加录屏组合键。",
;   "display": {
;     "purpose": "F1 原输入始终保留，长按时附加录屏组合键。",
;     "scope": "全局",
;     "source": "F1（按下时长）",
;     "target": "短按保留 F1 / 长按录屏"
;   },
;   "enabled": true,
;   "from": {
;     "event": "down",
;     "hotkey": "",
;     "key": {
;       "extended": false,
;       "kind": "keyboard",
;       "name": "F1"
;     },
;     "modifiers": [],
;     "optional_modifiers": [],
;     "repeat": "ignore",
;     "sequence": [],
;     "simultaneous": [],
;     "tap_count": 1
;   },
;   "id": "f1-bandicam",
;   "priority": 0,
;   "schema": 2,
;   "stop_processing": true,
;   "timing": {
;     "alone_timeout_ms": "inherit",
;     "delayed_action_ms": "inherit",
;     "held_threshold_ms": 250,
;     "multi_tap_timeout_ms": "inherit",
;     "sequence_timeout_ms": "inherit",
;     "simultaneous_threshold_ms": "inherit"
;   },
;   "to": [],
;   "to_after_key_up": [],
;   "to_delayed_if_canceled": [],
;   "to_delayed_if_invoked": [],
;   "to_if_alone": [],
;   "to_if_held_down": [
;     {
;       "repeat": "inherit",
;       "repeat_interval_ms": 0,
;       "type": "send",
;       "value": "^+!{F12}"
;     }
;   ],
;   "to_if_other_key_pressed": []
; }
; @spec-end
; @generated-sha256=81698695692A2439509829095A47808753DEDE0CD0EECC3E3FEFD8B915DCD609
; @generated-begin
; 此规则由托管运行时注册；此区域不包含可手工编辑的 AHK 代码。
; @generated-end
; @mapping-end

; @mapping-begin
; @schema=2
; @mode=managed
; @id=numlock-delete
; @spec-begin
; {
;   "conditions": [],
;   "description": "利用数字区附近的按键快速删除内容。",
;   "display": {
;     "purpose": "利用数字区附近的按键快速删除内容。",
;     "scope": "全局",
;     "source": "NumLock",
;     "target": "Delete"
;   },
;   "enabled": true,
;   "from": {
;     "event": "down",
;     "hotkey": "",
;     "key": {
;       "extended": false,
;       "kind": "keyboard",
;       "name": "NumLock"
;     },
;     "modifiers": [],
;     "optional_modifiers": [],
;     "repeat": "ignore",
;     "sequence": [],
;     "simultaneous": [],
;     "tap_count": 1
;   },
;   "id": "numlock-delete",
;   "priority": 0,
;   "schema": 2,
;   "stop_processing": true,
;   "timing": {
;     "alone_timeout_ms": "inherit",
;     "delayed_action_ms": "inherit",
;     "held_threshold_ms": "inherit",
;     "multi_tap_timeout_ms": "inherit",
;     "sequence_timeout_ms": "inherit",
;     "simultaneous_threshold_ms": "inherit"
;   },
;   "to": [
;     {
;       "repeat": "inherit",
;       "repeat_interval_ms": 0,
;       "type": "send",
;       "value": "{Delete}"
;     }
;   ],
;   "to_after_key_up": [],
;   "to_delayed_if_canceled": [],
;   "to_delayed_if_invoked": [],
;   "to_if_alone": [],
;   "to_if_held_down": [],
;   "to_if_other_key_pressed": []
; }
; @spec-end
; @generated-sha256=5C18F2671B0B78D9932AC5E4E195CD06675EC5CC18B4B5D220FF67A8AFAF7601
; @generated-begin
; 此规则由托管运行时注册；此区域不包含可手工编辑的 AHK 代码。
; @generated-end
; @mapping-end

; @mapping-begin
; @schema=2
; @mode=managed
; @id=browser-search-delete
; @spec-begin
; {
;   "conditions": [],
;   "description": "把浏览器搜索键附加为删除键。",
;   "display": {
;     "purpose": "把浏览器搜索键附加为删除键。",
;     "scope": "全局",
;     "source": "Browser_Search",
;     "target": "Delete"
;   },
;   "enabled": true,
;   "from": {
;     "event": "down",
;     "hotkey": "",
;     "key": {
;       "extended": false,
;       "kind": "keyboard",
;       "name": "Browser_Search"
;     },
;     "modifiers": [],
;     "optional_modifiers": [],
;     "repeat": "ignore",
;     "sequence": [],
;     "simultaneous": [],
;     "tap_count": 1
;   },
;   "id": "browser-search-delete",
;   "priority": 0,
;   "schema": 2,
;   "stop_processing": true,
;   "timing": {
;     "alone_timeout_ms": "inherit",
;     "delayed_action_ms": "inherit",
;     "held_threshold_ms": "inherit",
;     "multi_tap_timeout_ms": "inherit",
;     "sequence_timeout_ms": "inherit",
;     "simultaneous_threshold_ms": "inherit"
;   },
;   "to": [
;     {
;       "repeat": "inherit",
;       "repeat_interval_ms": 0,
;       "type": "send",
;       "value": "{Delete}"
;     }
;   ],
;   "to_after_key_up": [],
;   "to_delayed_if_canceled": [],
;   "to_delayed_if_invoked": [],
;   "to_if_alone": [],
;   "to_if_held_down": [],
;   "to_if_other_key_pressed": []
; }
; @spec-end
; @generated-sha256=80774A1F3087FD34E284CE3635CC885962DD88DB41DBA2D8CB8A4F194B0BF0D1
; @generated-begin
; 此规则由托管运行时注册；此区域不包含可手工编辑的 AHK 代码。
; @generated-end
; @mapping-end

; @mapping-begin
; @schema=2
; @mode=managed
; @id=browser-home-backspace
; @spec-begin
; {
;   "conditions": [],
;   "description": "把浏览器主页键附加为退格键。",
;   "display": {
;     "purpose": "把浏览器主页键附加为退格键。",
;     "scope": "全局",
;     "source": "Browser_Home",
;     "target": "Backspace"
;   },
;   "enabled": true,
;   "from": {
;     "event": "down",
;     "hotkey": "",
;     "key": {
;       "extended": false,
;       "kind": "keyboard",
;       "name": "Browser_Home"
;     },
;     "modifiers": [],
;     "optional_modifiers": [],
;     "repeat": "ignore",
;     "sequence": [],
;     "simultaneous": [],
;     "tap_count": 1
;   },
;   "id": "browser-home-backspace",
;   "priority": 0,
;   "schema": 2,
;   "stop_processing": true,
;   "timing": {
;     "alone_timeout_ms": "inherit",
;     "delayed_action_ms": "inherit",
;     "held_threshold_ms": "inherit",
;     "multi_tap_timeout_ms": "inherit",
;     "sequence_timeout_ms": "inherit",
;     "simultaneous_threshold_ms": "inherit"
;   },
;   "to": [
;     {
;       "repeat": "inherit",
;       "repeat_interval_ms": 0,
;       "type": "send",
;       "value": "{Backspace}"
;     }
;   ],
;   "to_after_key_up": [],
;   "to_delayed_if_canceled": [],
;   "to_delayed_if_invoked": [],
;   "to_if_alone": [],
;   "to_if_held_down": [],
;   "to_if_other_key_pressed": []
; }
; @spec-end
; @generated-sha256=95AC11C06E75E34C305CCE4F7FC66252A40C7A9C61690A631E8BA2FAE34AD305
; @generated-begin
; 此规则由托管运行时注册；此区域不包含可手工编辑的 AHK 代码。
; @generated-end
; @mapping-end

; @mapping-begin
; @schema=2
; @mode=managed
; @id=scrolllock-lock
; @spec-begin
; {
;   "conditions": [],
;   "description": "用低频按键一键锁屏。",
;   "display": {
;     "purpose": "用低频按键一键锁屏。",
;     "scope": "全局",
;     "source": "ScrollLock",
;     "target": "锁定工作站"
;   },
;   "enabled": true,
;   "from": {
;     "event": "down",
;     "hotkey": "",
;     "key": {
;       "extended": false,
;       "kind": "keyboard",
;       "name": "ScrollLock"
;     },
;     "modifiers": [],
;     "optional_modifiers": [],
;     "repeat": "ignore",
;     "sequence": [],
;     "simultaneous": [],
;     "tap_count": 1
;   },
;   "id": "scrolllock-lock",
;   "priority": 0,
;   "schema": 2,
;   "stop_processing": true,
;   "timing": {
;     "alone_timeout_ms": "inherit",
;     "delayed_action_ms": "inherit",
;     "held_threshold_ms": "inherit",
;     "multi_tap_timeout_ms": "inherit",
;     "sequence_timeout_ms": "inherit",
;     "simultaneous_threshold_ms": "inherit"
;   },
;   "to": [
;     {
;       "repeat": "inherit",
;       "repeat_interval_ms": 0,
;       "type": "lock_workstation"
;     }
;   ],
;   "to_after_key_up": [],
;   "to_delayed_if_canceled": [],
;   "to_delayed_if_invoked": [],
;   "to_if_alone": [],
;   "to_if_held_down": [],
;   "to_if_other_key_pressed": []
; }
; @spec-end
; @generated-sha256=39D7EDFAE28666A4CB5B952B2924FA8B01B587682144F0203FD1A892B4EAA190
; @generated-begin
; 此规则由托管运行时注册；此区域不包含可手工编辑的 AHK 代码。
; @generated-end
; @mapping-end

; @mapping-begin
; @schema=2
; @mode=managed
; @id=pause-media
; @spec-begin
; {
;   "conditions": [],
;   "description": "复用 Pause 键控制媒体播放与暂停。",
;   "display": {
;     "purpose": "复用 Pause 键控制媒体播放与暂停。",
;     "scope": "全局",
;     "source": "Pause",
;     "target": "Media_Play_Pause"
;   },
;   "enabled": true,
;   "from": {
;     "event": "down",
;     "hotkey": "",
;     "key": {
;       "extended": false,
;       "kind": "keyboard",
;       "name": "Pause"
;     },
;     "modifiers": [],
;     "optional_modifiers": [],
;     "repeat": "ignore",
;     "sequence": [],
;     "simultaneous": [],
;     "tap_count": 1
;   },
;   "id": "pause-media",
;   "priority": 0,
;   "schema": 2,
;   "stop_processing": true,
;   "timing": {
;     "alone_timeout_ms": "inherit",
;     "delayed_action_ms": "inherit",
;     "held_threshold_ms": "inherit",
;     "multi_tap_timeout_ms": "inherit",
;     "sequence_timeout_ms": "inherit",
;     "simultaneous_threshold_ms": "inherit"
;   },
;   "to": [
;     {
;       "repeat": "inherit",
;       "repeat_interval_ms": 0,
;       "type": "send",
;       "value": "{Media_Play_Pause}"
;     }
;   ],
;   "to_after_key_up": [],
;   "to_delayed_if_canceled": [],
;   "to_delayed_if_invoked": [],
;   "to_if_alone": [],
;   "to_if_held_down": [],
;   "to_if_other_key_pressed": []
; }
; @spec-end
; @generated-sha256=5D9E9149ECC068BF4122C89C22487B0C5BB93A8974070479FDB5B12C0A16E9B4
; @generated-begin
; 此规则由托管运行时注册；此区域不包含可手工编辑的 AHK 代码。
; @generated-end
; @mapping-end

; @mapping-begin
; @schema=2
; @mode=managed
; @id=copilot-doubao
; @spec-begin
; {
;   "conditions": [],
;   "description": "把 Copilot 专用键附加为豆包快捷键。",
;   "display": {
;     "purpose": "把 Copilot 专用键附加为豆包快捷键。",
;     "scope": "全局",
;     "source": "LWin + LShift + F23",
;     "target": "Ctrl + Shift + Space"
;   },
;   "enabled": true,
;   "from": {
;     "event": "down",
;     "hotkey": "",
;     "key": {
;       "extended": false,
;       "kind": "keyboard",
;       "name": "F23"
;     },
;     "modifiers": [
;       "LWin",
;       "LShift"
;     ],
;     "optional_modifiers": [],
;     "repeat": "ignore",
;     "sequence": [],
;     "simultaneous": [],
;     "tap_count": 1
;   },
;   "id": "copilot-doubao",
;   "priority": 0,
;   "schema": 2,
;   "stop_processing": true,
;   "timing": {
;     "alone_timeout_ms": "inherit",
;     "delayed_action_ms": "inherit",
;     "held_threshold_ms": "inherit",
;     "multi_tap_timeout_ms": "inherit",
;     "sequence_timeout_ms": "inherit",
;     "simultaneous_threshold_ms": "inherit"
;   },
;   "to": [
;     {
;       "repeat": "inherit",
;       "repeat_interval_ms": 0,
;       "type": "send",
;       "value": "^+{Space}"
;     }
;   ],
;   "to_after_key_up": [],
;   "to_delayed_if_canceled": [],
;   "to_delayed_if_invoked": [],
;   "to_if_alone": [],
;   "to_if_held_down": [],
;   "to_if_other_key_pressed": []
; }
; @spec-end
; @generated-sha256=312DD64607DC948923E9D33012D39AA87FC19E07EE9AFB2F68A951549114858D
; @generated-begin
; 此规则由托管运行时注册；此区域不包含可手工编辑的 AHK 代码。
; @generated-end
; @mapping-end

; @mapping-begin
; @schema=2
; @mode=managed
; @id=printscreen-alt-tab
; @spec-begin
; {
;   "conditions": [],
;   "description": "PrintScreen 松开时附加最近窗口切换。",
;   "display": {
;     "purpose": "PrintScreen 松开时附加最近窗口切换。",
;     "scope": "全局",
;     "source": "PrintScreen（松开）",
;     "target": "Alt + Tab"
;   },
;   "enabled": true,
;   "from": {
;     "event": "up",
;     "hotkey": "",
;     "key": {
;       "extended": false,
;       "kind": "keyboard",
;       "name": "PrintScreen"
;     },
;     "modifiers": [],
;     "optional_modifiers": [],
;     "repeat": "ignore",
;     "sequence": [],
;     "simultaneous": [],
;     "tap_count": 1
;   },
;   "id": "printscreen-alt-tab",
;   "priority": 0,
;   "schema": 2,
;   "stop_processing": true,
;   "timing": {
;     "alone_timeout_ms": "inherit",
;     "delayed_action_ms": "inherit",
;     "held_threshold_ms": "inherit",
;     "multi_tap_timeout_ms": "inherit",
;     "sequence_timeout_ms": "inherit",
;     "simultaneous_threshold_ms": "inherit"
;   },
;   "to": [
;     {
;       "repeat": "inherit",
;       "repeat_interval_ms": 0,
;       "type": "send",
;       "value": "!{Tab}"
;     }
;   ],
;   "to_after_key_up": [],
;   "to_delayed_if_canceled": [],
;   "to_delayed_if_invoked": [],
;   "to_if_alone": [],
;   "to_if_held_down": [],
;   "to_if_other_key_pressed": []
; }
; @spec-end
; @generated-sha256=C9E6F746230BE463B2AEA1678D4A4DE619A49E77058A8DA609D1E39DDB1C6D06
; @generated-begin
; 此规则由托管运行时注册；此区域不包含可手工编辑的 AHK 代码。
; @generated-end
; @mapping-end

; @mapping-begin
; @schema=2
; @mode=managed
; @id=alt-m-minimize
; @spec-begin
; {
;   "conditions": [],
;   "description": "不移动手位即可收起当前窗口。",
;   "display": {
;     "purpose": "不移动手位即可收起当前窗口。",
;     "scope": "全局",
;     "source": "Alt + M",
;     "target": "最小化当前窗口"
;   },
;   "enabled": true,
;   "from": {
;     "event": "down",
;     "hotkey": "",
;     "key": {
;       "extended": false,
;       "kind": "keyboard",
;       "name": "M"
;     },
;     "modifiers": [
;       "Alt"
;     ],
;     "optional_modifiers": [],
;     "repeat": "ignore",
;     "sequence": [],
;     "simultaneous": [],
;     "tap_count": 1
;   },
;   "id": "alt-m-minimize",
;   "priority": 0,
;   "schema": 2,
;   "stop_processing": true,
;   "timing": {
;     "alone_timeout_ms": "inherit",
;     "delayed_action_ms": "inherit",
;     "held_threshold_ms": "inherit",
;     "multi_tap_timeout_ms": "inherit",
;     "sequence_timeout_ms": "inherit",
;     "simultaneous_threshold_ms": "inherit"
;   },
;   "to": [
;     {
;       "repeat": "inherit",
;       "repeat_interval_ms": 0,
;       "type": "window_minimize"
;     }
;   ],
;   "to_after_key_up": [],
;   "to_delayed_if_canceled": [],
;   "to_delayed_if_invoked": [],
;   "to_if_alone": [],
;   "to_if_held_down": [],
;   "to_if_other_key_pressed": []
; }
; @spec-end
; @generated-sha256=4C03B5DEA41A20F4C08745D2939ECE9909E985CD48716A47FB8B9555EDC09207
; @generated-begin
; 此规则由托管运行时注册；此区域不包含可手工编辑的 AHK 代码。
; @generated-end
; @mapping-end

; @mapping-begin
; @schema=2
; @mode=managed
; @id=alt-w-close
; @spec-begin
; {
;   "conditions": [],
;   "description": "提供统一的当前窗口关闭手势。",
;   "display": {
;     "purpose": "提供统一的当前窗口关闭手势。",
;     "scope": "全局",
;     "source": "Alt + W",
;     "target": "关闭当前窗口"
;   },
;   "enabled": true,
;   "from": {
;     "event": "down",
;     "hotkey": "",
;     "key": {
;       "extended": false,
;       "kind": "keyboard",
;       "name": "W"
;     },
;     "modifiers": [
;       "Alt"
;     ],
;     "optional_modifiers": [],
;     "repeat": "ignore",
;     "sequence": [],
;     "simultaneous": [],
;     "tap_count": 1
;   },
;   "id": "alt-w-close",
;   "priority": 0,
;   "schema": 2,
;   "stop_processing": true,
;   "timing": {
;     "alone_timeout_ms": "inherit",
;     "delayed_action_ms": "inherit",
;     "held_threshold_ms": "inherit",
;     "multi_tap_timeout_ms": "inherit",
;     "sequence_timeout_ms": "inherit",
;     "simultaneous_threshold_ms": "inherit"
;   },
;   "to": [
;     {
;       "repeat": "inherit",
;       "repeat_interval_ms": 0,
;       "type": "window_close"
;     }
;   ],
;   "to_after_key_up": [],
;   "to_delayed_if_canceled": [],
;   "to_delayed_if_invoked": [],
;   "to_if_alone": [],
;   "to_if_held_down": [],
;   "to_if_other_key_pressed": []
; }
; @spec-end
; @generated-sha256=C584FCF25C20A1E33894EF05BCA4C3BAFE56E2FBEAF042EBE77BA72EF8243081
; @generated-begin
; 此规则由托管运行时注册；此区域不包含可手工编辑的 AHK 代码。
; @generated-end
; @mapping-end

; === 重映射代码区域结束 ===

#InputLevel 0
