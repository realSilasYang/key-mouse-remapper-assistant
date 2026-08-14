; Raw Input always remains available to recording. This policy only controls
; which observation events cross into the GUI event trace.
class RawInputObservationPolicy {
    static ShouldForwardToGui(unifiedEvent, fullObservation := false) {
        return !!fullObservation || !this.IsMouseMove(unifiedEvent)
    }

    static IsMouseMove(unifiedEvent) {
        if Type(unifiedEvent) != "Map" || !unifiedEvent.Has("phase")
                || String(unifiedEvent["phase"]) != "move"
                || !unifiedEvent.Has("identity")
                || Type(unifiedEvent["identity"]) != "Map"
            return false
        identity := unifiedEvent["identity"]
        return identity.Has("kind") && String(identity["kind"]) == "mouse"
    }
}
