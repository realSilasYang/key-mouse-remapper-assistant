#Requires AutoHotkey v2.0 64-bit
#SingleInstance Off
#Warn All, StdOut

#Include ..\..\src\Platform\Win32.ahk
#Include ..\..\src\Platform\WindowHierarchy.ahk

try {
    platform := WindowHierarchyRecoveryPlatform()
    platform.AddWindow(100, true, true, false, 0)
    platform.AddWindow(200, true, true, false, 100)
    owner := WindowHierarchyRecoveryOwner(100)
    manager := WindowHierarchyManager(platform)
    manager.Acquire(owner, 200)

    WindowHierarchyRecoveryAssert(manager.MinimizeChildIndependently(200),
        "The modal child could not be minimized independently.")
    platform.Windows[100].Minimized := true
    WindowHierarchyRecoveryAssert(manager.RestoreChildFromTaskbar(200)
            && !platform.Windows[100].Minimized
            && platform.Windows[100].Visible
            && !platform.Windows[200].Minimized
            && platform.Windows[200].Visible
            && platform.Windows[200].Owner == 100
            && !platform.Windows[100].Enabled,
        "Restoring a child did not first restore its minimized owner.")

    platform.Windows[100].Minimized := true
    platform.Windows[200].Visible := false
    WindowHierarchyRecoveryAssert(manager.ActivateTopOwned(owner)
            && !platform.Windows[100].Minimized
            && platform.Windows[100].Visible
            && platform.Windows[200].Visible
            && platform.Windows[200].Owner == 100
            && platform.OwnerChanges.Length >= 2
            && platform.OwnerChanges[-2].Owner == 0
            && platform.OwnerChanges[-1].Owner == 100
            && platform.ActivatedChild == 200,
        "Main-window activation did not recover the hidden modal child.")
} catch as testError {
    FileAppend(testError.Message "`n", "**")
    ExitApp(1)
}

FileAppend("PASS window-hierarchy-recovery-tests.ahk`n", "*")
ExitApp(0)

WindowHierarchyRecoveryAssert(condition, message) {
    if !condition
        throw Error(message)
}

class WindowHierarchyRecoveryOwner {
    __New(hwnd) {
        this.Hwnd := hwnd
    }
}

class WindowHierarchyRecoveryPlatform {
    __New() {
        this.Windows := Map()
        this.ActivatedOwner := 0
        this.ActivatedChild := 0
        this.ExtendedStyles := Map()
        this.OwnerChanges := []
    }

    AddWindow(hwnd, enabled, visible, minimized, owner) {
        this.Windows[hwnd] := {Enabled: enabled, Visible: visible,
            Minimized: minimized, Owner: owner}
    }

    IsGuiAlive(guiObj) => IsObject(guiObj) && this.IsWindow(guiObj.Hwnd)
    GetHwnd(guiObj) => guiObj.Hwnd
    IsWindow(hwnd) => this.Windows.Has(hwnd)
    IsWindowEnabled(hwnd) => this.Windows[hwnd].Enabled
    SetGuiEnabled(guiObj, enabled) {
        this.Windows[guiObj.Hwnd].Enabled := enabled
    }
    IsWindowVisible(hwnd) => this.Windows[hwnd].Visible
    IsWindowMinimized(hwnd) => this.Windows[hwnd].Minimized
    GetNativeOwner(hwnd) => this.Windows[hwnd].Owner
    GetOwnedWindowOwner(hwnd) => this.Windows[hwnd].Owner
    SetNativeOwner(hwnd, ownerHwnd) {
        this.Windows[hwnd].Owner := ownerHwnd
        this.OwnerChanges.Push({Hwnd: hwnd, Owner: ownerHwnd})
    }
    PromoteToTaskbar(hwnd) {
        originalStyle := this.ExtendedStyles.Get(hwnd, 0x80)
        this.ExtendedStyles[hwnd] := (originalStyle | 0x40000) & ~0x80
        return originalStyle
    }
    RestoreTaskbarStyle(hwnd, originalStyle) {
        this.ExtendedStyles[hwnd] := originalStyle
    }
    RegisterTaskbarTab(hwnd) => true
    UnregisterTaskbarTab(hwnd) => true
    MinimizeWindow(hwnd) {
        this.Windows[hwnd].Minimized := true
        return true
    }
    RestoreOwnerWindow(hwnd) {
        return this.RestoreWindow(hwnd)
    }
    RestoreOwnedWindow(hwnd) {
        return this.RestoreWindow(hwnd)
    }
    RestoreWindowFromTaskbar(hwnd, maximize := false) {
        return this.RestoreWindow(hwnd)
    }
    RestoreWindow(hwnd) {
        this.Windows[hwnd].Visible := true
        this.Windows[hwnd].Minimized := false
        return true
    }
    GetLastActivePopup(hwnd) => hwnd
    ActivateOwnedWindow(hwnd) {
        this.ActivatedChild := hwnd
    }
    ActivateOwnerWindow(hwnd) {
        this.ActivatedOwner := hwnd
    }
}
