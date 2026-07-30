#Requires AutoHotkey v2.0 64-bit
#SingleInstance Off
#Warn All, StdOut

#Include ..\TestSupport.ahk
#Include ..\..\src\Platform\Win32.ahk
#Include ..\..\src\Platform\WindowHierarchy.ahk

platform := FakeWindowPlatform()
owner := FakeOwnerGui(100)
platform.Windows[100] := {Enabled: true, Visible: true, Minimized: false, Owner: 0}
platform.Windows[200] := {Enabled: true, Visible: true, Minimized: false, Owner: 100}
platform.Windows[201] := {Enabled: true, Visible: true, Minimized: false, Owner: 100}
manager := WindowHierarchyManager(platform)

firstLease := manager.Acquire(owner, 200)
secondLease := manager.Acquire(owner, 201)
AssertTrue(IsObject(firstLease) && IsObject(secondLease), "应建立两份窗口租约")
AssertTrue(!platform.Windows[100].Enabled, "首个子窗口应禁用上级窗口")
AssertEqual(100, manager.FindOwnerHwnd(201), "子窗口归属错误")

firstContext := manager.Release(firstLease)
AssertEqual("child", firstContext.Mode, "仍有子窗口时不应恢复上级")
AssertTrue(!platform.Windows[100].Enabled, "仍有租约时上级不应恢复")

secondContext := manager.Release(secondLease)
AssertEqual("owner", secondContext.Mode, "最后一份租约应恢复上级")
AssertTrue(platform.Windows[100].Enabled, "上级窗口没有恢复")
manager.CompleteClose(secondContext)
AssertEqual(100, platform.ActivatedOwner, "恢复后应激活可见上级")
AssertEqual("", manager.Release(firstLease), "重复释放租约不应再次改变窗口状态")

platform.Windows[300] := {Enabled: false, Visible: true,
    Minimized: false, Owner: 0}
platform.Windows[301] := {Enabled: true, Visible: true,
    Minimized: false, Owner: 300}
disabledOwner := FakeOwnerGui(300)
disabledLease := manager.Acquire(disabledOwner, 301)
disabledContext := manager.Release(disabledLease)
AssertTrue(!platform.Windows[300].Enabled,
    "原本禁用的上级在租约结束后被错误启用")
manager.CompleteClose(disabledContext)
AssertTrue(platform.ActivatedOwner != 300,
    "原本禁用的上级在关闭子窗口后被错误激活")

platform.Windows[400] := {Enabled: true, Visible: true,
    Minimized: false, Owner: 0}
platform.Windows[401] := {Enabled: true, Visible: true,
    Minimized: false, Owner: 400}
staleOwner := FakeOwnerGui(400)
manager.Acquire(staleOwner, 401)
platform.Windows.Delete(401)
AssertTrue(!manager.IsOwnerLocked(staleOwner)
        && platform.Windows[400].Enabled,
    "原生子窗口意外销毁后没有清理租约并恢复上级")

platform.Windows[500] := {Enabled: true, Visible: true,
    Minimized: false, Owner: 0}
platform.Windows[501] := {Enabled: true, Visible: true,
    Minimized: false, Owner: 500}
minimizeOwner := FakeOwnerGui(500)
minimizeLease := manager.Acquire(minimizeOwner, 501)
AssertTrue(manager.MinimizeChildIndependently(501)
        && platform.Windows[501].Minimized
        && platform.Windows[501].Owner == 0
        && platform.Windows[500].Enabled
        && platform.TaskbarRegistrations[-1] == 501,
    "子窗口独立最小化没有挂起 Owner、恢复上级并登记任务栏入口")
AssertTrue(!manager.IsOwnerLocked(minimizeOwner),
    "只有已最小化子窗口时仍把直接上级报告为模态锁定")
AssertTrue(manager.PrepareChildRestore(501)
        && platform.Windows[501].Owner == 500
        && !platform.Windows[500].Enabled
        && platform.TaskbarUnregistrations[-1] == 501,
    "子窗口恢复前没有重建 Owner 和模态状态")
AssertTrue(manager.IsOwnerLocked(minimizeOwner),
    "恢复子窗口后没有重新建立模态锁")
platform.Windows[501].Minimized := false
AssertTrue(manager.MinimizeChildIndependently(501),
    "恢复后的子窗口无法再次独立最小化")
minimizedClose := manager.Release(minimizeLease)
manager.CompleteClose(minimizedClose)
AssertTrue(platform.Windows[500].Enabled
        && platform.TaskbarUnregistrations[-1] == 501,
    "关闭已最小化子窗口后没有清理任务栏状态并恢复上级")

platform.Windows[600] := {Enabled: true, Visible: true,
    Minimized: false, Owner: 0}
platform.Windows[601] := {Enabled: true, Visible: true,
    Minimized: false, Owner: 600}
platform.FailOwnerRestoreFor := 601
failedRestoreOwner := FakeOwnerGui(600)
failedRestoreLease := manager.Acquire(failedRestoreOwner, 601)
AssertTrue(manager.MinimizeChildIndependently(601)
        && platform.Windows[601].Minimized
        && platform.Windows[601].Owner == 0,
    "子窗口最小化时不应立即恢复原生 Owner")
AssertTrue(!manager.PrepareChildRestore(601)
        && platform.Windows[601].Owner == 0,
    "原生 Owner 恢复失败被错误报告为成功")
platform.FailOwnerRestoreFor := 0
AssertTrue(manager.PrepareChildRestore(601)
        && platform.Windows[601].Owner == 600,
    "恢复条件修复后仍无法重建窗口层级")
manager.Release(failedRestoreLease)
WriteTestSuccess("window-hierarchy")
ExitApp(0)

class FakeOwnerGui {
    __New(hwnd) {
        this.Hwnd := hwnd
    }
}

class FakeWindowPlatform {
    __New() {
        this.Windows := Map()
        this.ActivatedOwner := 0
        this.ActivatedChild := 0
        this.FailOwnerRestoreFor := 0
        this.ExtendedStyles := Map()
        this.TaskbarRegistrations := []
        this.TaskbarUnregistrations := []
    }

    IsGuiAlive(guiObj) => IsObject(guiObj) && this.IsWindow(guiObj.Hwnd)
    GetHwnd(guiObj) => guiObj.Hwnd
    IsWindow(hwnd) => this.Windows.Has(hwnd)
    IsWindowEnabled(hwnd) => this.Windows[hwnd].Enabled
    SetGuiEnabled(guiObj, enabled) => this.Windows[guiObj.Hwnd].Enabled := enabled
    IsWindowVisible(hwnd) => this.Windows[hwnd].Visible
    IsWindowMinimized(hwnd) => this.Windows[hwnd].Minimized
    GetNativeOwner(hwnd) => this.Windows[hwnd].Owner
    SetNativeOwner(hwnd, ownerHwnd) {
        if hwnd == this.FailOwnerRestoreFor && ownerHwnd
            return this.Windows[hwnd].Owner
        return this.Windows[hwnd].Owner := ownerHwnd
    }
    PromoteToTaskbar(hwnd) {
        originalStyle := this.ExtendedStyles.Get(hwnd, 0x80)
        this.ExtendedStyles[hwnd] := (originalStyle | 0x40000) & ~0x80
        return originalStyle
    }
    RestoreTaskbarStyle(hwnd, originalStyle) {
        this.ExtendedStyles[hwnd] := originalStyle
    }
    RegisterTaskbarTab(hwnd) {
        this.TaskbarRegistrations.Push(hwnd)
        return true
    }
    UnregisterTaskbarTab(hwnd) {
        this.TaskbarUnregistrations.Push(hwnd)
        return true
    }
    MinimizeWindow(hwnd) => this.Windows[hwnd].Minimized := true
    GetOwnedWindowOwner(hwnd) => this.Windows[hwnd].Owner
    GetLastActivePopup(hwnd) => hwnd
    ActivateOwnedWindow(hwnd) => this.ActivatedChild := hwnd
    ActivateOwnerWindow(hwnd) => this.ActivatedOwner := hwnd
}
