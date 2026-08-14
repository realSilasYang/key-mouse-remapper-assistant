# 📋 Changelog

[简体中文](../CHANGELOG.md) | **English**

This project follows [Semantic Versioning](https://semver.org/) and uses change
categories based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## 🚧 [Unreleased]

## 🎉 Version [1.0.0] - 2026-08-14

### 📦 Release Assets

- **`key-mouse-remapper-assistant-1.0.0-source.zip` (complete source package):** Includes runnable AHK source, application modules, assets, all thirteen README languages, bilingual changelogs, tests, and build tools; intended for review, development, or source execution and requires AutoHotkey v2 x64.
- **`key-mouse-remapper-assistant-1.0.0-windows-x64.zip` (complete portable package, recommended):** Includes the compiled EXE, editable mapping source, all thirteen README languages, bilingual changelogs, licenses, application modules, UI assets, fixed AutoHotkey v2.0.26 x64 runtime, and matching source archive; requires no AutoHotkey installation and is intended for long-term use after full extraction.

---

### ⚠️ Important Notes

- **Upgrading from 0.x:** Version 1.0.0 replaces the execution core with in-process rule blocks and isolated managed scripts and tightens accepted RuleSpec fields. Back up `键鼠重映射小助手.ahk` and `%APPDATA%\KeyMouseRemapperAssistant` before upgrading. The updater preserves the existing `@mapping` region, but a legacy structure that fails validation must be adjusted or regenerated in the 1.0.0 editor; the backup remains available for manual recovery.

---

### ✨ Added

- **Two rule runtime forms:** Added 18 built-in rules comprising 13 rule blocks and 5 managed scripts. Rule blocks hot-apply through AutoHotkey `Hotkey()` in the main process; managed scripts run in isolated AHK v2 processes and can use multiple hotkeys, state, timers, custom functions, and external calls.
- **Unified AI generation and optimization:** Generation no longer asks users to choose a form. AI receives the real rule-block boundary and full AHK v2 capability and decides the form itself. Optimization reviews syntax-highlighted code with changed-line highlighting, while generated content opens directly in the editor.
- **Local AI-result safeguards:** Added wrapper extraction, common field-alias and value-shape normalization, key-name correction, unknown-field checks, RuleSpec semantic validation, and AHK v2 syntax and startup validation for managed scripts. Failures retain the original rule and last request.
- **Dedicated input-capture path:** Added a capture-only input-guard process that suppresses keyboard, system-key, mouse-button, and wheel input and forwards a private event copy to the capture session. Consumer Control HID decoding makes common browser, media, volume, and launch keys recordable.
- **Complete rule management:** Added multi-selection batch drag ordering, pause/resume, deletion, code editing, rule-package import and export, transactional history, undo and redo, and seven sequence-dot colors.
- **Code editor:** Added RuleSpec and AHK v2 syntax highlighting, changed-line highlighting, error navigation, `Ctrl+Z` undo, `Ctrl+Shift+Z` redo, `Ctrl+Y` line deletion, and fixed two-line wheel scrolling.
- **Localization and themes:** Added Simplified Chinese, Traditional Chinese for Hong Kong and Taiwan, English, Japanese, Vietnamese, Korean, Spanish, French, Brazilian Portuguese, Russian, German, and Italian, plus Follow system, light, and dark themes.
- **System integration and updates:** Added desktop and Start Menu shortcuts, scheduled startup, elevated execution by default, startup update checks, manual updates, and rollback flows for portable, Git source, and ordinary source editions.
- **Events and help:** Added event viewing, filters, pause, clear, JSONL export, an in-app guide, About, issue feedback, and donation entry points.

---

### 🚀 Improvements

- **Visible response first:** Saving an edited managed script now closes the editor and updates the list before applying the worker in the background. A new script checks that placeholder text was replaced before showing execution confirmation.
- **Stable main-list updates:** Selection, tray activation, pause, save, and background application update only affected rows and status text, reducing full-window repaint, native rectangular selection fallback, stale text, and indefinitely pending application status.
- **List interaction:** Sequence, status, and scope columns center their content; left-aligned columns use consistent padding. Overflow tooltips use actual text width, and wheel scrolling interpolates smoothly according to input speed.
- **Code persistence:** Mapping writes now share cross-process locking, snapshot comparison, atomic replacement, and transactional history; deletion, ordering, pause, editing, and imports no longer own conflicting refresh paths.
- **AI progress:** Request timeouts are substantially longer, while status text identifies connection, response wait, parsing, normalization, and validation stages with current elapsed time.
- **Release privacy boundary:** Portable and source editions carry exactly the 18 current rules but reject `settings.ini`, `runtime.ini`, `rule-appearance.json`, `window-layout.ini`, and the build computer's AI address, key, model, and custom prompts.

---

### 🐛 Fixed

- **Immediate rule application:** Fixed transient incorrect list content after save, rules stuck in an applying state, a second edit reporting missing mapping code, and stale background callbacks overwriting newer state.
- **Window recovery and selection painting:** Fixed tray activation of an already visible window reverting selection to a native rectangle, occasional inability to restore from the taskbar or tray, and row content disappearing until hovered.
- **Input capture:** Fixed capture-guard startup failure, active mappings racing the recorder, mappings resuming too early, and failure to drain physical key releases.
- **Rule execution edges:** Fixed risks around chords, holds, releases, source suppression, deferred passthrough, left/right modifiers, and script pause or exit cleanup that could cause stuck keys, duplicate execution, or ineffective release.
- **AI compatibility:** Fixed common model output such as scalar array fields, `condition.application`, `from.key.event`, action shorthands, and non-AHK key names being rejected immediately. Unambiguous cases are normalized before genuinely unsupported behavior is blocked.
- **Light and dark UI:** Fixed insufficient light-theme contrast in buttons, icons, tooltips, previews, QR codes, and warning icons, and prevented light-theme work from turning dark-theme icons white.
- **Editor interaction:** Fixed select-all flashes while opening, RichEdit formatting entering the undo stack, unexpected shortcut behavior, ignored mouse-wheel input, and expanded error text hiding action buttons.

## 🎉 Version [0.1.1] - 2026-07-31

### 📦 Release Assets

- **`key-mouse-remapper-assistant-0.1.1-source.zip` (complete source package):** Includes the AHK source, modules, tests, build tools, documentation, and assets from that release and requires AutoHotkey v2 x64.
- **`key-mouse-remapper-assistant-0.1.1-windows-x64.zip` (complete portable package):** Includes the compiled EXE, AutoHotkey v2.0.26 x64 runtime, source, modules, documentation, assets, and licenses from that release.

---

### 🚀 Improvements

- **Two-edition releases:** Standardized formal releases on complete portable and source ZIPs.
- **Main window and tray:** Added quiet tray startup and instance handoff for Show, Reload, and Exit actions.
- **Event-stream performance:** Stopped recording high-frequency mouse-move packets by default while preserving keyboard, button, wheel, and device events.

---

### 🐛 Fixed

- **Local time and window state:** Fixed event timestamps, reload handoff, list focus, and Settings layout.
- **Persistence and cleanup:** Bounded persistent reads, retained atomic writes, and aggregated window-resource cleanup errors.

## 🎉 Version [0.1.0] - 2026-07-31

### 📦 Release Assets

- **`key-mouse-remapper-assistant-0.1.0-windows-x64.zip` (complete Windows x64 package):** Includes the original compiled application, editable source, runtime modules, documentation, assets, licenses, and fixed AutoHotkey v2.0.26 x64 runtime.
- **`SHA256SUMS.txt` (checksum list):** Records the 0.1.0 Windows ZIP and packaged main EXE digests; it is not an executable program.

---

### ✨ Added

- **Initial rule system:** Added Raw Input device observation, RuleSpec v2 rules, a supervised input process, rule packages, event recording, and diagnostics.
- **Initial GUI:** Added the main list, input capture, Settings, tray behavior, light/dark controls, and basic Chinese and English documentation.

---

### 🚀 Improvements

- **Product and data location:** Standardized product identifiers and `%APPDATA%\KeyMouseRemapperAssistant`.
- **Release compatibility:** Locked AutoHotkey and build tools and aligned UTF-8 behavior across Windows PowerShell 5.1 and PowerShell 7.

[Unreleased]: https://github.com/realSilasYang/key-mouse-remapper-assistant/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/realSilasYang/key-mouse-remapper-assistant/releases/tag/v1.0.0
[0.1.1]: https://github.com/realSilasYang/key-mouse-remapper-assistant/releases/tag/v0.1.1
[0.1.0]: https://github.com/realSilasYang/key-mouse-remapper-assistant/releases/tag/v0.1.0
