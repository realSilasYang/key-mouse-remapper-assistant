<div align="center">
  <img src="../assets/app/key-mouse-remapper-assistant.png" width="112" alt="Key Mouse Remapper Assistant logo">

  <p><a href="../README.md">简体中文</a> · <a href="./README.zh-HK.md">繁體中文（香港）</a> · <a href="./README.zh-TW.md">繁體中文（台灣）</a> · <strong>English</strong> · <a href="./README.ja.md">日本語</a> · <a href="./README.vi.md">Tiếng Việt</a> · <a href="./README.ko.md">한국어</a> · <a href="./README.es.md">Español</a> · <a href="./README.fr.md">Français</a> · <a href="./README.pt-BR.md">Português</a> · <a href="./README.ru.md">Русский</a> · <a href="./README.de.md">Deutsch</a> · <a href="./README.it.md">Italiano</a></p>

  <h1>Key Mouse Remapper Assistant</h1>

  <p><strong>Record, write, and manage keyboard and mouse mappings for your own workflow</strong></p>

  <p>
    <a href="https://github.com/realSilasYang/key-mouse-remapper-assistant/releases/latest"><img src="https://img.shields.io/github/v/release/realSilasYang/key-mouse-remapper-assistant?style=flat-square&amp;label=version" alt="Latest release"></a>
    <a href="https://github.com/realSilasYang/key-mouse-remapper-assistant/releases"><img src="https://img.shields.io/github/downloads/realSilasYang/key-mouse-remapper-assistant/total?style=flat-square&amp;label=downloads" alt="GitHub downloads"></a>
    <a href="../LICENSE"><img src="https://img.shields.io/github/license/realSilasYang/key-mouse-remapper-assistant?style=flat-square" alt="License"></a>
    <img src="https://img.shields.io/badge/Windows-10%20%7C%2011-0078D4?style=flat-square" alt="Windows 10 and 11">
    <img src="https://img.shields.io/badge/AutoHotkey-v2-334455?style=flat-square" alt="AutoHotkey v2">
  </p>

  <p>
    <a href="#interface-overview">Interface</a> ·
    <a href="#user-guide">User guide</a> ·
    <a href="#4-rule-blocks-and-managed-scripts">Rule forms</a> ·
    <a href="https://github.com/realSilasYang/key-mouse-remapper-assistant/releases">Releases</a> ·
    <a href="./CHANGELOG.en.md">Changelog</a> ·
    <a href="https://github.com/realSilasYang/key-mouse-remapper-assistant/issues/new">Feedback</a> ·
    <a href="#developer-guide">Developer guide</a>
  </p>
</div>

Key Mouse Remapper Assistant is an AutoHotkey v2 desktop tool for Windows 10 and 11 x64. It brings input capture, rule management, code editing, AI generation and optimization, local validation, and runtime status into one interface. It handles simple key substitutions while still allowing full AHK v2 automation through managed scripts.

Each release ships with the editable built-in rules present in its release commit; the number of rule blocks and managed scripts may vary. Rules live in the comment-only `@mapping` region, where both portable and source users can inspect, back up, and modify them. The application installs no driver or Windows service; enabled mappings work only while the assistant is running.

The interface supports 13 languages, light and dark themes, elevated startup, scheduled startup, application updates, event inspection, and rule-package import and export. Official packages never include the build computer's AI address, API key, model, custom prompts, or other personal settings.

# Interface overview

<p align="center">
  <img src="images/key-mouse-remapper-assistant-overview.png" alt="Key Mouse Remapper Assistant dark main window" width="100%">
</p>
<p align="center">
  <img src="images/key-mouse-remapper-assistant-overview-light.png" alt="Key Mouse Remapper Assistant light main window" width="100%">
</p>

The top command bar adds, pauses or resumes, and deletes rules. The list shows sequence, name, source input, mapped result, scope, and live status. The lower section records a source and target directly. The list supports multi-selection, batch drag reordering, temporary header sorting, overflow tooltips, colored sequence dots, and stable rounded selection feedback.

## Key capabilities

- Capture keyboard keys, mouse buttons, wheels, and common browser, media, and launch keys, including left/right modifier identity.
- Suppress the source input and run key, text, mouse, application-command, window, workstation-lock, and delay actions.
- Apply application, window, input-source, and session conditions, with press, release, repeat, tap, hold, and simultaneous-key behavior.
- Hot-apply declarative rule blocks in the main process and run complete AHK v2 scripts in isolated managed processes.
- Let AI choose between those forms from one generation entry, then normalize and validate the result locally.
- Edit RuleSpec and AHK v2 code with syntax highlighting, changed-line highlighting, undo, redo, line deletion, and fixed two-line wheel scrolling.
- Undo or redo adding, editing, deletion, pause/resume, rule-package import, and drag ordering.
- Inspect input, matching, condition rejection, execution, repository, and system events, with filtering and JSONL export.
- Keep mappings active in the tray and optionally start elevated at sign-in and check for updates.

## Scope and limits

- Windows 10 or 11 x64 is required. Windows 32-bit, macOS, and Linux are not supported.
- No kernel driver is installed. Secure desktop input, `Ctrl+Alt+Delete`, and software that deliberately blocks user-mode hooks remain outside the application's reach.
- A mapping can only affect processes at a compatible integrity level. The default elevated mode lets rule blocks and child managed scripts work with elevated foreground applications.
- AI output still requires human review, especially a managed script that performs file, network, process, or system operations.

---

**[User guide](#user-guide)**<br>
[Installation](#1-installation-and-first-run) · [Managing mappings](#2-adding-and-managing-mappings) · [Capture and status](#3-capture-status-and-events) · [Rules and AI](#4-rule-blocks-managed-scripts-and-ai) · [Settings](#5-settings) · [Privacy](#6-events-diagnostics-and-privacy)

**[Developer guide](#developer-guide)**<br>
[Directories](#1-directories-and-responsibilities) · [Correctness boundaries](#2-correctness-boundaries) · [Verification](#3-verification-commands) · [Releases](#4-releases-and-contribution)

# Support the project

If the assistant improves your daily workflow, you can support its development with either QR code below:

<p align="center">
  <img src="../assets/donate/微信个人收款码.png" width="220" alt="WeChat Pay donation QR code">
  &nbsp;&nbsp;&nbsp;&nbsp;
  <img src="../assets/donate/支付宝个人收款码.png" width="220" alt="Alipay donation QR code">
</p>

# User guide

## 1. Installation and first run

1. Download the complete portable ZIP or complete source ZIP from [Releases](https://github.com/realSilasYang/key-mouse-remapper-assistant/releases).
2. Extract the complete archive to a writable directory. Do not run an isolated file from inside the archive.

| Download | Intended use | How it runs |
| --- | --- | --- |
| Complete portable ZIP (recommended) | Everyday use, manual deployment, and backup | Run `键鼠重映射小助手.exe`; the fixed AutoHotkey v2 x64 runtime is included |
| Complete source ZIP | Review, development, or source execution | Install AutoHotkey v2 x64 and run `键鼠重映射小助手.ahk`; no compiled EXE or portable runtime is included |

Neither program ZIP contains fonts. The optional `fonts.zip` provides Noto fallback families; install the desired fonts into Windows before use. The assistant enumerates only Windows-installed fonts and never loads fonts privately from the ZIP or its application directory. Fonts are not required to run it.

The first launch requests administrator access by default. Closing the main window only hides it to the tray; use “Exit” from the tray to stop all mappings. All built-in rules are editable, pausable, and removable.

The portable edition is not a single-file application. Keep its EXE, editable AHK entry, modules, assets, and runtime together when moving or backing it up.

## 2. Adding and managing mappings

Use Add to open a complete `@mapping` editor or start AI generation. Select one or more rows to pause, resume, delete, drag as a batch, or assign a colored sequence dot. Double-click a row, press F2, or use the context menu to edit it. Header clicks only sort the current view and never rewrite source order.

Use `Ctrl+Z` and `Ctrl+Shift+Z` in the main list to undo and redo mapping transactions. Compare-and-swap writes prevent history replay from overwriting a newer external source edit.

## 3. Capture, status, and events

Record the source, record the target, enter a name, optionally distinguish left and right modifiers, and save. The application temporarily suspends mappings and starts a dedicated input guard so active rules and ordinary desktop shortcuts do not race the capture. Remapping resumes only after physical releases have drained.

Capture reports canonical names, readable names, virtual-key codes, and scan codes. Secure attention sequences and secure desktop input cannot be captured by design.

## 4. Rule blocks, managed scripts, and AI

Every rule is enclosed by `; @mapping-begin` and `; @mapping-end` and carries name, type, source, result, and scope metadata.

| Form | Best for | Runtime |
| --- | --- | --- |
| Rule block | One trigger, modifier chords, tap/hold/release branches, context conditions, and standard action sequences | Parsed from commented JSON and hot-applied in the main process |
| Managed script | Multiple independent hotkeys, shared state, loops, timers, custom functions, external calls, or arbitrary AHK v2 | Started, paused, resumed, and stopped in a separate AutoHotkey process |

Rule blocks suppress their source by default and can opt into passthrough. Managed scripts can execute arbitrary code, so creation and package import require explicit confirmation. Do not duplicate the host's injected directives or use `#SingleInstance Force`, unconditional `ExitApp`, or `Reload` to break the managed lifecycle.

### AI generation and optimization

Configure an API address, key, and model under Settings, then test the connection. The service supports common OpenAI Chat and Responses compatible endpoints and recognized provider variants.

- Generation has one entry. AI receives the current capabilities and decides whether the request needs a rule block or a managed script.
- Generated content opens directly in the editor. Optimization first presents syntax-highlighted, changed-line review.
- The local pipeline removes wrappers, normalizes known aliases and value shapes, validates keys and RuleSpec semantics, and performs AHK v2 syntax or startup validation.
- A failed, rejected, or canceled response never replaces the original rule, and the last request text is retained for the next attempt.
- Progress text identifies connection, response wait, parsing, normalization, and validation stages with elapsed time.

AI is not local. Only an explicit generation, optimization, or connection test sends data to the configured provider. Its pricing, retention, and privacy policy apply.

## 5. Settings

Display settings control language, content font, and system/light/dark theme. Startup settings manage shortcuts, scheduled startup, elevation, update checks, and initial window visibility. Rule and event settings manage packages, capture cancellation, buffer capacity, and live following. AI settings hold the provider connection and prompts.

The event viewer records input, matching, rejected conditions, actions, repository activity, and system events. Exported JSONL can contain application, window, or key information and should be reviewed before sharing.

The updater verifies a formal GitHub Release and a complete package, preserves the current `@mapping` region and unmanaged personal settings, and rolls back on replacement failure.

## 6. Events, diagnostics, and privacy

Rule code lives in `键鼠重映射小助手.ahk` in the actual run directory. AI, display, and startup settings are stored in `%APPDATA%\KeyMouseRemapperAssistant\settings.ini`; appearance and window state are stored alongside it. Back up both the entry AHK file and that application-data directory.

Official portable and source packages:

- contain exactly the built-in rules parsed from the release entry file;
- exclude `settings.ini`, `runtime.ini`, `rule-appearance.json`, and `window-layout.ini`;
- exclude the build computer's AI address, key, model, and custom prompts;
- fail the build if forbidden state or a local AI parameter appears in packaged text.

The project has no account system, telemetry, or automatic upload. AI requests go directly to the provider configured by the user.

# Star History

[![Star History Chart](https://api.star-history.com/svg?repos=realSilasYang/key-mouse-remapper-assistant&type=Date)](https://star-history.com/#realSilasYang/key-mouse-remapper-assistant&Date)

# Developer guide

## 1. Directories and responsibilities

`app/` owns orchestration and windows; `src/Core/` owns rules, runtimes, AI, history, packages, and updates; `src/Input/` owns observation and capture; `src/Localization/` owns 13 UI languages; `src/Platform/` owns Windows integration; `src/UI/` owns themes, SVG rendering, syntax analysis, and common interaction; `tests/` and `tools/` contain verification and release tooling.

## 2. Correctness boundaries

```text
Rule blocks -> DirectHotkeyRuntime -> AutoHotkey Hotkey() -> actions
Managed scripts -> ScriptRuleRuntime -> isolated AutoHotkey v2 process
Raw Input -> EventTraceService -> event viewer
Capture guard -> consumed low-level event copy -> KeyCaptureSession
Consumer Control HID -> browser/media/launch input -> KeyCaptureSession
```

Mapping-region writes use a cross-process lock, snapshot comparison, and atomic replacement. Script workers use named stop, pause, and readiness signals. The capture guard exists only during capture and performs no normal runtime or GUI work. Secure desktop input and secure attention sequences remain outside every user-mode implementation.

## 3. Verification commands

```powershell
.\tools\bootstrap-toolchain.ps1
.\tests\verify.ps1 `
  -AutoHotkeyPath .\.tools\autoHotkey-2.0.26\AutoHotkey64.exe
.\tests\verify.ps1 `
  -AutoHotkeyPath .\.tools\autoHotkey-2.0.26\AutoHotkey64.exe `
  -IncludeGui
```

Two integration tests that physically suppress desktop input are intentionally outside the default unattended run.

## 4. Releases and contribution

```powershell
.\tools\build-release.ps1
```

The build produces a complete portable ZIP, a complete source ZIP, and the optional `fonts.zip`. Both program packages exclude fonts and carry the built-in rules from the release commit, README set, changelogs, and licenses. The source package also carries tests; the portable package carries the compiled EXE, fixed AutoHotkey v2 x64 runtime, and matching source archive. The font package preserves the `assets/fonts` layout for installation into Windows. Packaging rejects personal state and local AI parameters and writes deterministic ZIPs.

Use the [changelog template](changelog-template.md) and [release process](release-process.md) for formal versions. Third-party versions and licenses are listed in [THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md).

### License

The project is licensed under the [MIT License](../LICENSE). AutoHotkey, resvg, Lucide, and Noto assets retain their respective licenses.
