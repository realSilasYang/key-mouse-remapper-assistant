# Release Process

[简体中文](../release-process.md) | **English**

A formal version treats `VERSION`, changelogs, standalone Release Notes, complete verification, and deterministic packages as one indivisible delivery. Ordinary development commits do not create version tags early, and release artifacts never carry local user state or AI parameters.

1. Use the [changelog template](changelog-template.md) to prepare the user-facing entry and create `docs/release-notes/v<version>.md`. Update `VERSION`, the Chinese changelog, and its English mirror together. Release headings use `## 🎉 Version [X.Y.Z] - YYYY-MM-DD`.
2. Omit `⚠️ Important Notes` by default. Add it only for incompatible data or configuration, data-loss risk, breaking minimum-environment／privilege／default changes, or mandatory migration, backup, or replacement work. State the affected users, concrete risk, and required action.
3. Every CHANGELOG version retains `📦 Release Assets`, listing the complete source ZIP and complete portable ZIP in GitHub's display order with exact names, contents, AutoHotkey requirements, and intended use. Release Notes use the same entry as their source of truth but place the asset section last.
4. CHANGELOG, Release Notes, and GitHub Release bodies do not include a `✅ Validation Scope` section, test counts, build hashes, SHA-256 values, or incomplete manual matrices. Evidence and digests remain in test output, build logs, and GitHub asset metadata.
5. Confirm complete Git history and tags are available and that the worktree contains only release work. Check all thirteen README language links, the interface image, downloads, capability boundaries, privacy text, and developer commands against current code.
6. Prepare the locked toolchain and run complete verification:

   ```powershell
   .\tools\bootstrap-toolchain.ps1
   .\tests\verify.ps1 `
     -AutoHotkeyPath .\.tools\autoHotkey-2.0.26\AutoHotkey64.exe `
     -IncludeGui
   ```

   Two integration tests physically suppress desktop input and remain outside unattended release gates. Run them separately only with explicit control of local input.
7. Run `.\tools\build-release.ps1`. The build produces exactly two public assets: the complete source ZIP and complete portable ZIP. Both contain the 18 current rules, all thirteen README languages, bilingual changelogs, and licenses. Source additionally carries tests; portable additionally carries the compiled EXE, fixed runtime, and matching source archive.
8. Extract and inspect both ZIPs. `builtInRuleCount` is 18 and `bundlesUserSettings` is `false`; `settings.ini`, `runtime.ini`, `rule-appearance.json`, and `window-layout.ini` are absent. Confirm packaged text contains no local AI address, key, model, or custom prompt, then run the portable EXE with `--startup-validation`.
9. Commit all source, tests, and documentation and push `main`. Create `v<version>` only after every check passes, and point it to a release commit in `main` history. Unless the publisher explicitly requests a revision of the same maintained version, do not move a public tag; publish a patch version instead.
10. Title the GitHub Release “键鼠重映射小助手 X.Y.Z”, use `docs/release-notes/v<version>.md` verbatim as the body, and upload only the two template assets. Download them again and audit GitHub digests, names, manifests, startup validation, and tag commit.

Packages are unsigned. If code signing is added later, first complete the deterministic unsigned build and record signed artifacts and certificate data separately; signing must not hide a base-build mismatch.
