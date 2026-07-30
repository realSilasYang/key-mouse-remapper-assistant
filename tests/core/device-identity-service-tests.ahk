#Requires AutoHotkey v2.0.26 64-bit
#SingleInstance Off
#Warn All, StdOut

#Include ..\TestSupport.ahk
#Include ..\..\src\Core\JsonCodec.ahk
#Include ..\..\src\Core\Sha256.ahk
#Include ..\..\src\Core\RuleSpec.ahk
#Include ..\..\src\Core\DeviceIdentityService.ahk

testFailure := ""
try {
    service := DeviceIdentityService()
    firstIdentity := service.Build(Map(
        "path", "\\\\?\\HID#VID_046D&PID_C52B&MI_01#SERIAL123#{GUID}",
        "type", "keyboard", "handle", "0x01",
        "usage_page", 1, "usage", 6,
        "container_id", "8C7ED206-3F8A-4827-B3AB-AE9E1FAEFC6C"))
    replugged := service.Build(Map(
        "path", "\\\\?\\HID#VID_046D&PID_C52B&MI_01#CHANGED#{GUID}",
        "type", "keyboard", "handle", "0x99",
        "usage_page", 1, "usage", 6,
        "container_id", "8c7ed206-3f8a-4827-b3ab-ae9e1faefc6c"))
    AssertTrue(firstIdentity["stable_id"] == replugged["stable_id"]
            && firstIdentity["exact_path_id"] != replugged["exact_path_id"]
            && firstIdentity["stability"] == "container"
            && !firstIdentity["ambiguous"].Value,
        "容器身份没有跨句柄/路径变化保持稳定")
    pathOnly := service.Build(Map(
        "path", "\\\\?\\HID#VID_1234&PID_ABCD#7&ABC&0&0000#{GUID}",
        "type", "mouse", "handle", "0x02",
        "usage_page", 1, "usage", 2))
    AssertTrue(pathOnly["stability"] == "instance"
            && pathOnly["ambiguous"].Value
            && pathOnly["hardware_id"]
                == "mouse:vid=1234:pid=ABCD:rev=unknown:mi=unknown:usage=1:2",
        "无容器设备没有正确声明实例级稳定性与歧义")
    sessionOnly := service.Build(Map("path", "", "type", "keyboard",
        "handle", "0x55", "usage_page", 1, "usage", 6))
    AssertEqual("session", sessionOnly["stability"],
        "缺失路径的设备没有降级为会话身份")

    changes := service.Reconcile([MergeDevice(firstIdentity, "0x01")],
        [MergeDevice(replugged, "0x99"), MergeDevice(pathOnly, "0x02")])
    AssertTrue(changes.Rebound.Length == 1
            && changes.Arrived.Length == 1
            && changes.Removed.Length == 0,
        "设备重插重绑定、到达或移除分类错误")

    WriteTestSuccess("device-identity-service")
} catch as identityTestError {
    testFailure := identityTestError.Message "`n" . identityTestError.Stack
}
if testFailure != "" {
    FileAppend(testFailure "`n", "**")
    ExitApp(1)
}
ExitApp(0)

MergeDevice(identity, handle) {
    result := RuleSpec.Clone(identity)
    result["handle"] := handle
    return result
}
