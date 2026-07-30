#Requires AutoHotkey v2.0.26 64-bit
#SingleInstance Off
#Warn All, StdOut

#Include ..\TestSupport.ahk
#Include ..\PhysicalDeviceEvidenceModel.ahk

MakeDeviceStats(arrival := 0, removal := 0, rebound := 0) {
    return Map("lifecycle", Map(
        "arrival", arrival,
        "removal", removal,
        "rebound", rebound))
}

RunPhysicalDeviceEvidenceModelTests() {
    order := ["keyboard-a", "keyboard-b"]

    startupOnly := Map(
        "keyboard-a", MakeDeviceStats(1, 0, 0),
        "keyboard-b", MakeDeviceStats(1, 0, 0))
    AssertTrue(!PhysicalDeviceEvidenceModel.HasCompletedHotplugCycle(
        startupOnly, order), "启动枚举不得算作热插拔循环")

    splitCycle := Map(
        "keyboard-a", MakeDeviceStats(0, 1, 0),
        "keyboard-b", MakeDeviceStats(1, 0, 0))
    AssertTrue(!PhysicalDeviceEvidenceModel.HasCompletedHotplugCycle(
        splitCycle, order), "不同设备的移除和到达不得拼成热插拔循环")

    reboundCycle := Map(
        "keyboard-a", MakeDeviceStats(0, 1, 1),
        "keyboard-b", MakeDeviceStats())
    AssertTrue(PhysicalDeviceEvidenceModel.HasCompletedHotplugCycle(
        reboundCycle, order), "同一稳定设备的移除和重绑应通过")

    arrivalCycle := Map(
        "keyboard-a", MakeDeviceStats(2, 1, 0),
        "keyboard-b", MakeDeviceStats())
    AssertTrue(PhysicalDeviceEvidenceModel.HasCompletedHotplugCycle(
        arrivalCycle, order), "同一稳定设备的移除和重新到达应通过")
}

RunPhysicalDeviceEvidenceModelTests()
ExitApp(0)
