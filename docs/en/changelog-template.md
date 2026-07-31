# 📝 English Changelog Template

[简体中文](../changelog-template.md) | **English**

For a release, copy the block below beneath Unreleased in `docs/CHANGELOG.en.md`,
then move released entries into it. Always keep Release Assets; retain only the
other categories that are actually present. The template does not generate
Important Notes by default; add that section manually only for breaking changes
or mandatory upgrade actions.

```markdown
## 🎉 Version [X.Y.Z] - YYYY-MM-DD

### 📦 Release Assets

- **`key-mouse-remapper-assistant-X.Y.Z-windows-x64.zip` (complete portable package, recommended):** Includes the compiled EXE, the latest stable AutoHotkey v2 x64 runtime, GUI and PowerShell CLIs, runtime modules, documentation, fonts, and licenses. No separate AutoHotkey installation is required; fully extract it before use.
- **`key-mouse-remapper-assistant-X.Y.Z-source.zip` (complete source package):** Includes the AHK source, CLIs, modules, tests, build tools, GitHub workflows, documentation, and assets for review, development, or local builds. It contains neither the compiled EXE nor the portable runtime.

---

### ✨ Added

- **Feature name:** Explain what was added, which device or mapping scenarios it covers, and what users gain.

---

### 🚀 Improvements

- **Feature name:** Explain how existing behavior changed and what users can observe.

---

### 🐛 Fixed

- **Problem name:** Explain the previous failure and the correct behavior after the fix.

---

### 🔒 Security

- **Problem name:** Keep only after coordinated disclosure. State affected and fixed versions and whether immediate action is required, without exploitable details.
```

## 📐 Writing Rules

- Use `📋 Changelog` for the document title and `🎉 Version [X.Y.Z] - YYYY-MM-DD` for release headings. The version must match `VERSION`, the Ahk2Exe file version, and the Git tag.
- Every formal version keeps `📦 Release Assets` and lists only the portable ZIP and source ZIP actually uploaded by the workflow, with exact names, included content, AutoHotkey requirements, and intended use. Do not document a standalone EXE, `SHA256SUMS.txt`, or any other unpublished asset.
- `⚠️ Important Notes` is an optional warning section and is omitted by default. Add it only when existing data or rules are incompatible, data may be lost, minimum-environment or privilege changes are breaking, changed defaults create upgrade risk, or users must migrate, back up, or fully replace files.
- Do not classify unchanged compatibility, direct-upgrade availability, download recommendations, edition selection, feature summaries, ordinary usage advice, or validation scope as Important Notes. When the section exists, every item states who is affected, the concrete risk, and the required action, and the section precedes standard categories. Remove the heading when no item qualifies.
- Standard categories are `✨ Added`, `🚀 Improvements`, and `🐛 Fixed`; remove empty categories. `🔒 Security` appears only after coordinated disclosure.
- Neither changelogs nor Release notes may contain a `✅ Validation Scope` section or enumerate test counts, build hashes, or incomplete manual matrices. Keep that evidence in dedicated validation records, CI/Release Actions logs, and complete build artifacts.
- Start each item with a bold feature or problem phrase, then explain the user-visible change, scope, and benefit in complete English.
- Combine commits for one feature. Do not list commit subjects, filenames, internal classes, variable names, or pure refactoring. Mention internal work only when it changes reliability, performance, compatibility, or maintenance boundaries.
- Changes to configuration, RuleSpec, rule packages, defaults, privileges, input boundaries, device bindings, or minimum environment must explain old-data handling, backup needs, and failure recovery.
- For GUI, DPI, dark mode, multi-monitor, or physical-device work, claim only the verified range. Keep untested combinations in the manual regression matrix rather than claiming complete support.
- Put Release Assets first within each `CHANGELOG.md` version. In `docs/release-notes/v<version>.md`, Release Assets must be the final level-two section so readers can select a download after reviewing changes.
- After release, update comparison links: `[Unreleased]` points from the latest tag to `HEAD`, and the version link points to the GitHub Release.

## Pre-release Example

```markdown
## 🚧 [Unreleased]

### 🚀 Improvements

- **Issue intake:** Bug reports now collect Windows, display scale, physical-device, mapping-type, and runtime context, reducing follow-up caused by missing environment details.

## 🎉 Version [0.1.1] - YYYY-MM-DD

### 📦 Release Assets

- **`key-mouse-remapper-assistant-0.1.1-windows-x64.zip` (complete portable package, recommended):** Includes the compiled EXE, the latest stable AutoHotkey v2 x64 runtime, CLIs, runtime modules, documentation, fonts, and licenses. No separate AutoHotkey installation is required; fully extract it before use.
- **`key-mouse-remapper-assistant-0.1.1-source.zip` (complete source package):** Includes the AHK source, CLIs, modules, tests, build tools, GitHub workflows, documentation, and assets. It contains neither the compiled EXE nor the portable runtime.

---

### 🐛 Fixed

- **Background focus:** Clicking empty main-window space no longer leaves the main list receiving keyboard commands, while the current selection remains intact.
```
