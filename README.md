# Key Mouse Remapper Assistant

A Windows AutoHotkey v2 application for two things only:

- maintaining keyboard and mouse remapping rules through the existing GUI;
- recording keyboard and mouse input for rule capture and the event viewer.

The normal remapping backend runs in the application process. Each enabled
RuleSpec is compiled into an AutoHotkey `Hotkey()` callback. A `script` rule
stores complete AutoHotkey v2 source in the same comment-only mapping region
and runs it in an isolated managed process. Ordinary keyboard and mouse Raw
Input is observation-only and is used for device diagnostics and the event
viewer. During exclusive key capture, the input-guard process forwards a
private copy of each consumed low-level event to `KeyCaptureSession`.
Consumer Control HID reports supplement that path for browser, media, volume
and launch keys which some devices do not expose as ordinary keyboard packets.
Device identity never enters RuleSpec
or a completed key-capture result.

## Runtime model

```text
RuleSpec blocks -> DirectHotkeyRuntime -> AutoHotkey Hotkey() -> actions
Script blocks -> ScriptRuleRuntime -> isolated AutoHotkey v2 process
Raw Input -> EventTraceService
Capture guard -> consumed low-level event copy -> KeyCaptureSession
Consumer Control HID -> browser/media key event -> KeyCaptureSession
```

Key capture starts a dedicated input-guard process before remapping is
suspended. Its low-level keyboard and mouse hooks consume keyboard, system-key,
mouse-button, and wheel input without passthrough. The helper does no runtime
or GUI work and starts from a minimal worker entry, so hook acquisition does
not parse the application or its mapping blocks. Script-rule pause/resume
signals are broadcast before acknowledgements are collected, keeping the hook
message loop responsive without accumulating one polling interval per rule.
Each consumed event is posted back to the recorder through a private
application message, because suppressed input is no longer available through
ordinary keyboard or mouse Raw Input. Consumer Control Usage Page `0x0C` is
decoded separately so all 18 standard Windows browser/media/launch commands
remain recordable. The guard stays installed through the final physical
release drain and remapping resume, preventing active rules and ordinary
desktop global shortcuts from racing the recorder. Windows secure attention
sequences and the secure desktop remain outside every user-mode input hook by
design.

Script workers use named stop, pause, and readiness signals. Their generated
runtime files live in the application data directory and are removed when the
rule stops. User source remains persisted only in the SHA-256 protected,
comment-encoded script rule block.

Remapping hotkeys suppress their source input by default, so an application
cannot race the remapped action with its own shortcut handling. A rule can set
`passthrough: true` when the original input must also be preserved. Passthrough
with a `to_if_held_down` action defers the source input: a short press is
replayed on release, while a recognized long press consumes it. One-shot held
actions such as `send`, mouse, text, application-command, and window actions
also wait for the physical source release before they execute. Stateful
`key_down`/`key_up` batches still execute at the held threshold so their output
remains pressed for the rest of the source-key cycle. Pressing another physical
key cancels `to_if_alone` without cancelling deferred passthrough.
Sequences, multi-tap triggers, persistent variables, and process-launch
actions remain outside the declarative RuleSpec runtime. Complete AutoHotkey
v2 scripts can implement those behaviors in script mode without sharing state
or directives with the main UI process. Script-rule packages declare the
`arbitrary_code` permission
and require explicit confirmation before import and execution.
The current built-in mappings are the `@mapping` blocks in
`键鼠重映射小助手.ahk`. They remain the single source of truth.

All mapping-region mutations are transactional and retained in a bounded
in-memory history. Add, delete, pause/resume, block editing, drag reordering,
and package import can be undone with `Ctrl+Z` and redone with
`Ctrl+Shift+Z` or `Ctrl+Y`. History replay uses compare-and-swap writes so it
will not overwrite an external script edit.

## Run

AutoHotkey v2 x64 is required.

```powershell
& .\.tools\autoHotkey-2.0.26\AutoHotkey64.exe .\键鼠重映射小助手.ahk
```

## Verify

```powershell
.\tests\verify.ps1 `
  -AutoHotkeyPath .\.tools\autoHotkey-2.0.26\AutoHotkey64.exe
```

GUI visual tests are non-interactive and opt-in:

```powershell
.\tests\verify.ps1 -IncludeGui
```

The verification reads the current RuleSpec blocks and checks that every
built-in rule has a valid direct hotkey registration, including long-hold and
key-release behavior.

## Package

Both release editions contain the current 18 `@mapping` blocks as their
built-in rules. Personal state remains under
`%APPDATA%\KeyMouseRemapperAssistant`; AI address, key, model, prompts, and
other user settings are never copied into a release artifact.

```powershell
.\tools\bootstrap-toolchain.ps1
.\tools\build-release.ps1
```
