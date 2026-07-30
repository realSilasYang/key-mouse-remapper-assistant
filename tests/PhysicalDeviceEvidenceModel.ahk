#Requires AutoHotkey v2.0.26 64-bit

class PhysicalDeviceEvidenceModel {
    static HasCompletedHotplugCycle(statsByDevice, deviceOrder) {
        for deviceId in deviceOrder {
            if !statsByDevice.Has(deviceId)
                continue
            stats := statsByDevice[deviceId]
            if Type(stats) != "Map" || !stats.Has("lifecycle")
                continue
            lifecycle := stats["lifecycle"]
            if Type(lifecycle) != "Map"
                continue
            removals := lifecycle.Get("removal", 0)
            returns := lifecycle.Get("arrival", 0)
                + lifecycle.Get("rebound", 0)
            if removals > 0 && returns > 0
                return true
        }
        return false
    }
}
