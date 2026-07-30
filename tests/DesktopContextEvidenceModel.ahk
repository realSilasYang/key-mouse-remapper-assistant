class DesktopContextEvidenceModel {
    static MinimumDurationMs := 60000

    static Evaluate(samples, events, requirements, collectorIntegrityRid,
            errorCount := 0, durationMs := 0) {
        samples := Type(samples) == "Array" ? samples : []
        events := Type(events) == "Array" ? events : []
        lockedSessions := Map()
        unlockedSessions := Map()
        layouts := Map()
        hasRdp := false
        hasElevatedFocus := false
        hasSecureDesktop := false

        for sample in samples {
            if Type(sample) != "Map"
                continue
            session := this.ReadMap(sample, "session")
            sessionId := this.ReadScalar(session, "session_id", "")
            lockKnown := this.ReadBoolean(session, "lock_known", false)
            lockedValue := session.Has("locked") ? session["locked"] : ""
            if sessionId != "" && lockKnown
                    && lockedValue is JsonBoolean {
                if lockedValue.Value
                    lockedSessions[String(sessionId)] := true
                else
                    unlockedSessions[String(sessionId)] := true
            }
            if this.ReadBoolean(session, "remote", false)
                    && StrLower(String(this.ReadScalar(session,
                        "protocol", ""))) == "rdp"
                hasRdp := true

            inputSource := this.ReadMap(sample, "input_source")
            layout := Trim(String(this.ReadScalar(inputSource, "layout", "")))
            if layout != ""
                layouts[layout] := true

            foreground := this.ReadMap(sample, "foreground")
            integrityKnown := this.ReadBoolean(foreground,
                "integrity_known", false)
            integrityRid := this.ReadInteger(foreground,
                "integrity_rid", 0)
            focusedHwnd := this.ReadInteger(foreground,
                "focused_hwnd", 0)
            if integrityKnown && integrityRid >= 0x3000
                    && integrityRid > collectorIntegrityRid && focusedHwnd
                hasElevatedFocus := true

            desktopState := StrLower(String(this.ReadScalar(session,
                "desktop_state", "")))
            desktopError := this.ReadInteger(session, "desktop_error", 0)
            if lockKnown && lockedValue is JsonBoolean
                    && !lockedValue.Value && desktopState == "unavailable"
                    && desktopError == 5
                hasSecureDesktop := true
        }

        hasLockCycle := false
        for sessionId in lockedSessions {
            if unlockedSessions.Has(sessionId) {
                hasLockCycle := true
                break
            }
        }
        hasSleepResume := this.HasOrderedPowerCycle(events)
        hasLayoutSwitch := layouts.Count >= 2
        passed := errorCount == 0
            && durationMs >= DesktopContextEvidenceModel.MinimumDurationMs
            && (!this.RequirementEnabled(requirements, "lock_cycle")
                || hasLockCycle)
            && (!this.RequirementEnabled(requirements, "rdp") || hasRdp)
            && (!this.RequirementEnabled(requirements, "sleep_resume")
                || hasSleepResume)
            && (!this.RequirementEnabled(requirements, "elevated_focus")
                || hasElevatedFocus)
            && (!this.RequirementEnabled(requirements, "secure_desktop")
                || hasSecureDesktop)
            && (!this.RequirementEnabled(requirements, "layout_switch")
                || hasLayoutSwitch)
        return {
            Passed: passed,
            LockCycle: hasLockCycle,
            Rdp: hasRdp,
            SleepResume: hasSleepResume,
            ElevatedFocus: hasElevatedFocus,
            SecureDesktop: hasSecureDesktop,
            LayoutSwitch: hasLayoutSwitch,
            DistinctLayouts: layouts.Count,
            SampleCount: samples.Length,
            EventCount: events.Length
        }
    }

    static HasOrderedPowerCycle(events) {
        suspendTick := -1
        for event in events {
            if Type(event) != "Map"
                continue
            if StrLower(String(this.ReadScalar(event, "type", "")))
                    != "power"
                continue
            phase := StrLower(String(this.ReadScalar(event, "phase", "")))
            tick := this.ReadInteger(event, "tick_ms", -1)
            if phase == "suspend" && tick >= 0
                suspendTick := tick
            else if phase == "resume" && suspendTick >= 0
                    && tick > suspendTick
                return true
        }
        return false
    }

    static RequirementEnabled(requirements, name) {
        if Type(requirements) != "Map" || !requirements.Has(name)
            return false
        value := requirements[name]
        return value is JsonBoolean ? value.Value : !!value
    }

    static ReadMap(container, name) {
        return Type(container) == "Map" && container.Has(name)
                && Type(container[name]) == "Map"
            ? container[name] : Map()
    }

    static ReadScalar(container, name, fallback := "") {
        if Type(container) != "Map" || !container.Has(name)
            return fallback
        value := container[name]
        return IsObject(value) ? fallback : value
    }

    static ReadInteger(container, name, fallback := 0) {
        value := this.ReadScalar(container, name, fallback)
        try return Integer(value)
        return fallback
    }

    static ReadBoolean(container, name, fallback := false) {
        if Type(container) != "Map" || !container.Has(name)
            return fallback
        value := container[name]
        if value is JsonBoolean
            return value.Value
        return IsObject(value) ? fallback : !!value
    }
}
