# 📋 Changelog

[简体中文](../CHANGELOG.md) | **English**

This project follows [Semantic Versioning](https://semver.org/) and uses change
categories based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## 🚧 [Unreleased]

## 🎉 Version [0.1.1] - 2026-07-31

### 📦 Release Assets

- **`key-mouse-remapper-assistant-0.1.1-windows-x64.zip` (complete portable package, recommended):** Includes the compiled EXE, the latest stable AutoHotkey v2.0.26 x64 runtime, GUI and PowerShell CLIs, runtime modules, documentation, fonts, and licenses. No separate AutoHotkey installation is required; fully extract it before use.
- **`key-mouse-remapper-assistant-0.1.1-source.zip` (complete source package):** Includes the AHK source, CLIs, modules, tests, build tools, GitHub workflows, documentation, and assets for review, development, or local builds. It contains neither the compiled EXE nor the portable runtime.

---

### 🚀 Improvements

- **Two-edition releases:** Formal releases now contain exactly two ZIPs, portable and source, with no standalone EXE, `SHA256SUMS.txt`, or other asset. The portable package integrates the latest stable AutoHotkey runtime, while the source package preserves the complete repository layout.
- **Main window and tray:** Normal startup is silent to the tray, and one tray click shows the main window. The tray contains only Show Main Window, Reload, and Exit; Reload uses a one-shot handoff marker to show the replacement instance.
- **Settings and rule packages:** General is renamed Appearance and its first Escape option is removed. The Recording tab is removed, while rule-package import and export move to a dedicated Rule Packages tab.
- **Consistent command bar:** Add, Pause/Resume, and Delete use the same fixed symbol slot as Process Watchdog Assistant. Settings, Help, and Donate use matching hover text and donation interaction.
- **Event-stream performance:** High-frequency mouse movement is not recorded or forwarded across processes by default. The full Raw Input stream, including movement packets, reaches the GUI only during Raw Observation; keyboard, button, wheel, and device events remain available.

---

### 🐛 Fixed

- **Event timestamps:** The event viewer's time column now uses the active Windows local time zone, while event details and JSONL exports remain in UTC to preserve portable ordering and interchange semantics.
- **Reload handoff:** Exit callbacks explicitly allow the previous instance to terminate after cleanup, preventing Reload from leaving the single-instance lock occupied or failing to show the replacement window.
- **Main-list focus:** Clicking empty main-window space or ordinary text makes the ListView fully lose focus while preserving the current selection.
- **Settings layout:** Fixed asymmetric settings content, uncentered fields, clipped long labels, and unrelated save controls on the Rule Packages page.
- **Persistence and cleanup:** Persistent reads enforce byte and character bounds, while writes retain concurrent-snapshot and atomic-replacement semantics. Window destruction aggregates incomplete callback, subclass, icon, GDI, and input/output cleanup failures.

## 🎉 Version [0.1.0] - 2026-07-31

### 📦 Release Assets

- **`key-mouse-remapper-assistant-0.1.0-windows-x64.zip` (complete portable package, recommended):** Includes the compiled EXE, editable AHK source, GUI and PowerShell CLIs, the pinned AutoHotkey v2.0.26 x64 runtime and its source, application modules, documentation, fonts, and licenses. No separate AutoHotkey installation is required; fully extract it before use. It is also suitable for source review or manual deployment.
- **`SHA256SUMS.txt` (integrity file):** Records SHA-256 digests for the portable ZIP and its main EXE so both the download and extracted program can be checked for corruption or replacement. It is not an executable program.

---

### ✨ Added

- **Physical-device mappings:** The input path uses Windows Raw Input and distinguishes which physical keyboard or mouse produced an event. Recording a source input binds the first active device's `stable_id`.
- **Managed rule runtime:** RuleSpec v2 describes keyboard, mouse, modifier, hold, repeat, simultaneous-key, sequence, timing, window, and application conditions. Mapping regions contain managed comment blocks only and never execute AHK code supplied by a rule package or user.
- **Device-isolated state:** Modifiers, held inputs, repeats, chords, sequences, timers, and synthetic-output ownership are isolated per device. Device removal, rebinding, system resume, rule hot-apply, suspension, and shutdown release the affected state and output.
- **Supervised input process:** The GUI supervises one trayless `input-worker` over an authenticated named pipe by default. CLI rule changes notify a running GUI for hot application without reloading the input implementation.
- **Rule packages and diagnostics:** Managed RuleSpec packages support import, conflict preview, export, and integrity validation. Device, capability, simulation, diagnostics-bundle, and event-recording entry points are included.

---

### 🚀 Improvements

- **Product identity and data migration:** The product names are standardized as “键鼠重映射小助手” and “Keyboard & Mouse Remapper Assistant”; code, entry points, icons, GitHub, CI, and artifacts consistently use `KeyMouseRemapperAssistant` or `key-mouse-remapper-assistant`. The default data directory moves to `%APPDATA%\KeyMouseRemapperAssistant`, with non-overwriting migration from former product names.
- **Explicit input boundary:** Raw Input identifies physical devices and produces additive output only. The project installs no driver, low-level hook, or system service and does not claim to suppress, replace, or hide original Windows input.
- **Main window and tray:** Normal startup is silent to the tray, and one tray click shows the main window. The tray contains only Show Main Window, Reload, and Exit; Reload uses a one-shot handoff so the new instance displays the interface.
- **Settings and rule packages:** General is renamed Appearance and its first Escape option is removed. The Recording tab is removed, while rule-package import and export move to a dedicated Rule Packages tab.
- **Consistent command bar:** Add, Pause/Resume, and Delete use the same fixed symbol slot as Process Watchdog Assistant. Settings, Help, and Donate use matching hover text, including the same donation wording and interaction.
- **Window and theme consistency:** Custom-drawn buttons expose native Windows accessibility semantics. Toolbar and external-link buttons use delayed, nonactivating, DPI-aware light/dark tooltips. Child minimization, ownership, modality, icons, GDI resources, message callbacks, and timers have explicit owners.
- **Fonts and localization:** Public releases contain only OFL-licensed Noto interface fonts, with CJK coverage reduced to five regional Regular faces. CLI stdout is BOM-less UTF-8, and builds and validation support Windows PowerShell 5.1 and PowerShell 7.
- **Reproducible releases:** The release manifest fixes `inputBackend: raw-input`, `requiresDriver: false`, and `suppressesOriginalInput: false`; automated gates cover the pinned toolchain, runtime digest, ZIP contents, and third-party licenses.

---

### 🐛 Fixed

- **Reload handoff:** Exit callbacks explicitly allow the previous instance to terminate after cleanup, preventing Reload from leaving the single-instance lock occupied or failing to show the replacement window.
- **Main-list focus:** Clicking empty main-window space or ordinary text moves keyboard focus to a noninteractive status label. The ListView fully loses focus while preserving the current selection.
- **Settings layout:** Removed the duplicate Event Viewer entry from the main window and fixed asymmetric settings content, uncentered fields, clipped long labels, and unrelated save controls on the Rule Packages page.
- **Persistence and cleanup:** Persistent reads enforce byte and character bounds, while writes retain concurrent-snapshot and atomic-replacement semantics. Window destruction aggregates incomplete callback, subclass, icon, GDI, and input/output cleanup failures.

[Unreleased]: https://github.com/realSilasYang/key-mouse-remapper-assistant/compare/v0.1.1...HEAD
[0.1.1]: https://github.com/realSilasYang/key-mouse-remapper-assistant/releases/tag/v0.1.1
[0.1.0]: https://github.com/realSilasYang/key-mouse-remapper-assistant/releases/tag/v0.1.0
