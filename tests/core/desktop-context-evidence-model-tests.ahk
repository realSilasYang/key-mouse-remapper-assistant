#Requires AutoHotkey v2.0.26 64-bit
#SingleInstance Off
#Warn All, StdOut

#Include ..\TestSupport.ahk
#Include ..\..\src\Core\JsonCodec.ahk
#Include ..\DesktopContextEvidenceModel.ahk

FullDesktopRequirements() {
    return Map(
        "lock_cycle", JsonBoolean(true),
        "rdp", JsonBoolean(true),
        "sleep_resume", JsonBoolean(true),
        "elevated_focus", JsonBoolean(true),
        "secure_desktop", JsonBoolean(true),
        "layout_switch", JsonBoolean(true))
}

DesktopSample(sessionId, locked, remote, protocol, layout,
        integrityRid := 0x2000, focusedHwnd := 100,
        desktopState := "accessible", desktopError := 0) {
    return Map(
        "session", Map(
            "session_id", sessionId,
            "lock_known", JsonBoolean(true),
            "locked", JsonBoolean(locked),
            "remote", JsonBoolean(remote),
            "protocol", protocol,
            "desktop_state", desktopState,
            "desktop_error", desktopError),
        "input_source", Map("layout", layout),
        "foreground", Map(
            "integrity_known", JsonBoolean(true),
            "integrity_rid", integrityRid,
            "focused_hwnd", focusedHwnd))
}

try {
    requirements := FullDesktopRequirements()
    validSamples := [
        DesktopSample(1, false, false, "console", "00000409"),
        DesktopSample(1, true, false, "console", "00000409"),
        DesktopSample(1, false, true, "rdp", "00000804"),
        DesktopSample(1, false, false, "console", "00000804",
            0x3000, 200),
        DesktopSample(1, false, false, "console", "00000804",
            0x2000, 100, "unavailable", 5)]
    validEvents := [
        Map("type", "power", "phase", "suspend", "tick_ms", 1000),
        Map("type", "power", "phase", "resume", "tick_ms", 5000)]
    valid := DesktopContextEvidenceModel.Evaluate(validSamples, validEvents,
        requirements, 0x2000, 0, 60000)
    AssertTrue(valid.Passed && valid.LockCycle && valid.Rdp
            && valid.SleepResume && valid.ElevatedFocus
            && valid.SecureDesktop && valid.LayoutSwitch
            && valid.DistinctLayouts == 2,
        "完整真实桌面证据模型没有通过")

    splitSamples := [
        DesktopSample(1, true, false, "console", "00000409"),
        DesktopSample(2, false, true, "rdp", "00000804"),
        DesktopSample(2, false, false, "console", "00000804",
            0x3000, 200),
        DesktopSample(2, false, false, "console", "00000804",
            0x2000, 100, "unavailable", 5)]
    split := DesktopContextEvidenceModel.Evaluate(splitSamples, validEvents,
        requirements, 0x2000, 0, 60000)
    AssertTrue(!split.Passed && !split.LockCycle,
        "不同 session 的锁定和解锁被拼接为同一循环")

    reversedEvents := [
        Map("type", "power", "phase", "resume", "tick_ms", 1000),
        Map("type", "power", "phase", "suspend", "tick_ms", 5000)]
    reversed := DesktopContextEvidenceModel.Evaluate(validSamples,
        reversedEvents, requirements, 0x2000, 0, 60000)
    AssertTrue(!reversed.Passed && !reversed.SleepResume,
        "乱序电源事件被当成睡眠恢复证据")

    lockedSecureSamples := validSamples.Clone()
    lockedSecureSamples[5] := DesktopSample(1, true, false, "console",
        "00000804", 0x2000, 100, "unavailable", 5)
    lockedSecure := DesktopContextEvidenceModel.Evaluate(lockedSecureSamples,
        validEvents, requirements, 0x2000, 0, 60000)
    AssertTrue(!lockedSecure.Passed && !lockedSecure.SecureDesktop,
        "锁屏桌面不可访问被误当成 UAC 安全桌面")

    sameIntegritySamples := validSamples.Clone()
    sameIntegritySamples[4] := DesktopSample(1, false, false, "console",
        "00000804", 0x2000, 200)
    sameIntegrity := DesktopContextEvidenceModel.Evaluate(
        sameIntegritySamples, validEvents, requirements, 0x2000, 0, 60000)
    AssertTrue(!sameIntegrity.Passed && !sameIntegrity.ElevatedFocus,
        "与采集器同完整性级别的窗口被当成高权限焦点")

    shortRun := DesktopContextEvidenceModel.Evaluate(validSamples,
        validEvents, requirements, 0x2000, 0, 59999)
    AssertTrue(!shortRun.Passed, "不足一分钟的桌面证据被接受")
    WriteTestSuccess("desktop-context-evidence-model")
} catch as evidenceModelError {
    FileAppend(evidenceModelError.Message "`n" evidenceModelError.Stack,
        "**")
    ExitApp(1)
}
ExitApp(0)
