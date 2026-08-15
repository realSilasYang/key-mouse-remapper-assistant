# 📝 English Changelog Template

[简体中文](../changelog-template.md) | **English**

For a release, copy the block below beneath Unreleased in `docs/CHANGELOG.en.md`, then move released entries into it. Always retain Release Assets and keep only the other categories actually present. The template omits Important Notes by default; add that section only for breaking changes or mandatory upgrade actions.

```markdown
## 🎉 Version [X.Y.Z] - YYYY-MM-DD

### 📦 Release Assets

- **`fonts.zip` (optional font package):** Provides Noto fallback UI fonts for installation into Windows; it is not required to run the application.
- **`key-mouse-remapper-assistant-X.Y.Z-source.zip` (complete source package):** Includes runnable AHK source, application modules, assets other than fonts, all thirteen README languages, bilingual changelogs, tests, and build tools; intended for review, development, or source execution and requires AutoHotkey v2 x64.
- **`key-mouse-remapper-assistant-X.Y.Z-windows-x64.zip` (complete portable package, recommended):** Includes the compiled EXE, editable mapping source, all thirteen README languages, bilingual changelogs, licenses, application modules, UI assets other than fonts, a fixed AutoHotkey v2 x64 runtime, and matching source archive; requires no AutoHotkey installation and is intended for long-term use after full extraction.

---

### ✨ Added

- **Feature name:** Explain what was added, where it applies, and what users gain.

---

### 🚀 Improvements

- **Feature name:** Explain how existing behavior changed and what users can observe.

---

### 🐛 Fixed

- **Problem name:** Explain the previous failure and the correct behavior after the fix.

---

### 🔒 Security

- **Problem name:** Keep only after coordinated disclosure. State affected and fixed versions and whether immediate action is required, without exploitable detail.
```

## 📐 Writing Rules

- Use `📋 Changelog` for the document title and `🎉 Version [X.Y.Z] - YYYY-MM-DD` for release headings. The version must match `VERSION`, the compiled file version, and the Git tag.
- Every formal version retains `📦 Release Assets` and lists all three exact file names, roles, included content, AutoHotkey requirements, and intended use in GitHub's fixed order: optional font ZIP, source ZIP, then portable ZIP.
- `⚠️ Important Notes` is optional. Add it only for incompatible data or configuration, data-loss risk, breaking minimum-environment or privilege changes, risky changed defaults, or mandatory migration, backup, or replacement work.
- Do not classify compatibility, direct-upgrade availability, download recommendations, edition selection, feature summaries, ordinary advice, or validation scope as Important Notes. Remove the heading when no qualifying item exists.
- Standard categories are `✨ Added`, `🚀 Improvements`, and `🐛 Fixed`; remove empty categories. Use `🔒 Security` only after coordinated disclosure.
- Neither changelogs nor Release Notes may contain a `✅ Validation Scope` section or enumerate test counts, build hashes, SHA-256 values, or incomplete manual matrices. Keep evidence in test output, build logs, and GitHub asset digests.
- Start each item with a bold feature or problem phrase, then explain user-visible behavior, scope, and benefit in complete English.
- Combine commits for one feature. Do not list commit subjects, file names, internal classes, variables, or pure refactoring unless it changes reliability, performance, compatibility, or maintenance boundaries.
- Changes to configuration, defaults, privileges, system integration, updates, or minimum environments explain old-data handling, backup needs, and failure recovery.
- Claim only completed GUI, DPI, theme, and multi-monitor coverage.
- After release, point `[Unreleased]` from the latest tag to `HEAD` and each version link to its GitHub Release.

Release Notes use the same CHANGELOG entry as their source of truth but place `📦 Release Assets` last so users select a download after reading the changes. Release Notes and GitHub Release bodies do not publish SHA-256 values.
