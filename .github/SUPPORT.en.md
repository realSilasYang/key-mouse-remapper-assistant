# Support

[简体中文](SUPPORT.md) | **English**

Only the latest release is maintained. The project does not promise a commercial
service level or fixed response time. Before reporting a problem, upgrade to the
latest release and read:

- [README usage](../README.md#使用)
- [RuleSpec v2](../docs/rulespec-v2.md)
- [Migration guide](../docs/migration.md)
- [Security and capability boundaries](../docs/security-and-limits.md)
- [CLI reference](../docs/cli.md)

## Prepare a report

If the problem remains, record:

- Assistant version and distribution: GitHub Release portable package, AHK source, or a self-built EXE.
- Windows version, OS build, and x64 architecture.
- For UI defects, display scale, resolution, monitor count, and the affected monitor.
- The affected area: keyboard, mouse, chord/sequence/hold, device identity, scope, capture, rule packages, CLI, or `input-worker`.
- Physical-device count and connection, target application, and privilege level. Redact device interface paths and `stable_id` values.
- Shortest reproduction, frequency, expected result, and actual result.
- Redacted rules, key events, diagnostics, logs, screenshots, or recordings.

Rules, events, and diagnostics may contain input content, application or window
identity, derived device identifiers, local paths, and environment variables.
Remove anything you do not want to publish. The project does not upload
diagnostics automatically.

## Choose the right form

- Use Bug Report for reproducible mapping errors, device mistakes, leaked output state, CLI failures, or UI problems.
- Use Feature Request for a capability or complete workflow that does not exist today.
- Use Improvement for a change to existing behavior, UI, performance, compatibility, or design.
- See [Contributing](../CONTRIBUTING.md) for development and pull-request requirements.

Raw Input can identify physical devices and produce additive output only. It
cannot consume, replace, or hide original Windows input. The project also does
not provide a kernel driver, system service, secure-desktop input, or cross-user
session input. Confirm that a request stays within those explicit boundaries.

## Security issues

Do not post issues that may disclose input content, cross an authentication
boundary, execute untrusted rules, or affect another user's data. Follow the
[security policy](../SECURITY.md) and use GitHub Private vulnerability reporting.
