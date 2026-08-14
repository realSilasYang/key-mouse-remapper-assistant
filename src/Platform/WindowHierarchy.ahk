class WindowHierarchyPlatform {
    __New() {
        this.TaskbarList := ""
    }

    IsGuiAlive(guiObj) {
        if !guiObj || Type(guiObj) != "Gui"
            return false
        try return this.IsWindow(guiObj.Hwnd)
        catch
            return false
    }

    GetHwnd(guiObj) {
        return guiObj.Hwnd
    }

    IsWindow(hwnd) {
        return hwnd && DllCall("user32\IsWindow", "Ptr", hwnd, "Int") != 0
    }

    IsWindowEnabled(hwnd) {
        return DllCall("user32\IsWindowEnabled", "Ptr", hwnd, "Int") != 0
    }

    SetGuiEnabled(guiObj, enabled) {
        guiObj.Opt(enabled ? "-Disabled" : "+Disabled")
    }

    IsWindowVisible(hwnd) {
        return DllCall("user32\IsWindowVisible", "Ptr", hwnd, "Int") != 0
    }

    IsWindowMinimized(hwnd) {
        return DllCall("user32\IsIconic", "Ptr", hwnd, "Int") != 0
    }

    GetNativeOwner(childHwnd) {
        return DllCall("user32\GetWindowLongPtrW", "Ptr", childHwnd,
            "Int", -8, "Ptr") ; GWLP_HWNDPARENT
    }

    SetNativeOwner(childHwnd, ownerHwnd) {
        DllCall("kernel32\SetLastError", "UInt", 0)
        previousOwner := DllCall("user32\SetWindowLongPtrW", "Ptr", childHwnd,
            "Int", -8, "Ptr", ownerHwnd, "Ptr")
        if !previousOwner && A_LastError
            throw OSError(A_LastError, "Unable to change the window owner")
        return previousOwner
    }

    PromoteToTaskbar(childHwnd) {
        originalStyle := DllCall("user32\GetWindowLongPtrW",
            "Ptr", childHwnd, "Int", Win32.GWL_EXSTYLE, "Ptr")
        taskbarStyle := (originalStyle | Win32.WS_EX_APPWINDOW)
            & ~Win32.WS_EX_TOOLWINDOW
        if taskbarStyle != originalStyle {
            DllCall("user32\SetWindowLongPtrW", "Ptr", childHwnd,
                "Int", Win32.GWL_EXSTYLE, "Ptr", taskbarStyle, "Ptr")
            this.RefreshWindowFrame(childHwnd)
        }
        return originalStyle
    }

    RestoreTaskbarStyle(childHwnd, originalStyle) {
        DllCall("user32\SetWindowLongPtrW", "Ptr", childHwnd,
            "Int", Win32.GWL_EXSTYLE, "Ptr", originalStyle, "Ptr")
        this.RefreshWindowFrame(childHwnd)
    }

    RegisterTaskbarTab(childHwnd) {
        if !this.IsWindow(childHwnd)
            return false
        Loop 2 {
            taskbarList := this.GetTaskbarList()
            if !taskbarList
                return false
            try result := ComCall(4, taskbarList, "Ptr", childHwnd, "Int")
            catch
                result := -1
            if result >= 0
                return true
            this.TaskbarList := ""
        }
        return false
    }

    UnregisterTaskbarTab(childHwnd) {
        Loop 2 {
            taskbarList := this.GetTaskbarList()
            if !taskbarList
                return false
            try result := ComCall(5, taskbarList, "Ptr", childHwnd, "Int")
            catch
                result := -1
            if result >= 0
                return true
            this.TaskbarList := ""
        }
        return false
    }

    IsTaskbarShellAvailable(timeoutMs := 250) {
        taskbarHwnd := DllCall("user32\FindWindowW", "Str", "Shell_TrayWnd",
            "Ptr", 0, "Ptr")
        if !taskbarHwnd
            return false
        messageResult := 0
        return !!DllCall("user32\SendMessageTimeoutW", "Ptr", taskbarHwnd,
            "UInt", Win32.WM_NULL, "UPtr", 0, "Ptr", 0,
            "UInt", Win32.SMTO_ABORTIFHUNG,
            "UInt", Max(1, Integer(timeoutMs)),
            "UPtr*", &messageResult, "Ptr")
    }

    GetTaskbarList() {
        if !this.IsTaskbarShellAvailable() {
            this.TaskbarList := ""
            return ""
        }
        if IsObject(this.TaskbarList)
            return this.TaskbarList
        try taskbarList := ComObject(
            "{56FDF344-FD6D-11D0-958A-006097C9A090}",
            "{56FDF342-FD6D-11D0-958A-006097C9A090}")
        catch
            return ""
        try {
            if ComCall(3, taskbarList, "Int") < 0
                return ""
        } catch {
            return ""
        }
        this.TaskbarList := taskbarList
        return taskbarList
    }

    RefreshWindowFrame(hwnd) {
        DllCall("user32\SetWindowPos", "Ptr", hwnd, "Ptr", 0,
            "Int", 0, "Int", 0, "Int", 0, "Int", 0,
            "UInt", 0x0037, "Int") ; NOACTIVATE | FRAMECHANGED | no move/size/z
    }

    MinimizeWindow(hwnd) {
        if !this.IsWindow(hwnd)
            return false
        ; Hiding first discards DWM's last composed surface, leaving only an
        ; application-icon placeholder in the taskbar thumbnail. A standard
        ; minimize preserves the rendered frame used by taskbar preview.
        DllCall("user32\ShowWindow", "Ptr", hwnd,
            "Int", Win32.SW_MINIMIZE, "Int")
        if !this.IsWindowMinimized(hwnd)
            DllCall("user32\ShowWindow", "Ptr", hwnd,
                "Int", Win32.SW_SHOWMINNOACTIVE, "Int")
        return this.IsWindowMinimized(hwnd)
    }

    RestoreWindowFromTaskbar(hwnd, maximize := false) {
        if !this.IsWindow(hwnd)
            return false
        showCommand := maximize ? Win32.SW_SHOWMAXIMIZED : Win32.SW_RESTORE
        return this.RestoreVisibleWindow(hwnd, showCommand, true)
    }

    RestoreOwnerWindow(hwnd) {
        if !this.IsWindow(hwnd)
            return false
        if this.IsWindowVisible(hwnd) && !this.IsWindowMinimized(hwnd)
            return true
        return this.RestoreVisibleWindow(hwnd, Win32.SW_RESTORE, false)
    }

    RestoreOwnedWindow(hwnd) {
        if !this.IsWindow(hwnd)
            return false
        if this.IsWindowVisible(hwnd) && !this.IsWindowMinimized(hwnd)
            return true
        return this.RestoreVisibleWindow(hwnd, Win32.SW_RESTORE, false)
    }

    RestoreVisibleWindow(hwnd, showCommand, activate) {
        if !this.IsWindow(hwnd)
            return false
        DllCall("user32\ShowWindow", "Ptr", hwnd, "Int", showCommand,
            "Int")
        ; A restore issued while the minimize animation is still completing
        ; can be overwritten by that animation. Keep the common path
        ; immediate, but retry briefly until the native state settles.
        Loop 20 {
            if !this.IsWindowMinimized(hwnd) && this.IsWindowVisible(hwnd)
                break
            Sleep(10)
            DllCall("user32\ShowWindow", "Ptr", hwnd, "Int", showCommand,
                "Int")
        }
        if this.IsWindowMinimized(hwnd) || !this.IsWindowVisible(hwnd)
            return false
        if activate {
            DllCall("user32\SetForegroundWindow", "Ptr", hwnd, "Int")
            DllCall("user32\SetActiveWindow", "Ptr", hwnd, "Ptr")
        }
        return true
    }

    GetOwnedWindowOwner(childHwnd) {
        return DllCall("user32\GetWindow", "Ptr", childHwnd,
            "UInt", 4, "Ptr") ; GW_OWNER
    }

    GetLastActivePopup(hwnd) {
        return DllCall("user32\GetLastActivePopup", "Ptr", hwnd, "Ptr")
    }

    ActivateOwnedWindow(hwnd) {
        WinActivate("ahk_id " hwnd)
    }

    ActivateOwnerWindow(hwnd) {
        DllCall("user32\SetForegroundWindow", "Ptr", hwnd, "Int")
        DllCall("user32\SetActiveWindow", "Ptr", hwnd, "Ptr")
    }
}

class WindowHierarchyManager {
    __New(platform) {
        if !IsObject(platform)
            throw TypeError("窗口层级平台适配器无效")
        this.Platform := platform
        this.OwnerLocks := Map()
    }

    IsGuiAlive(guiObj) {
        try return this.Platform.IsGuiAlive(guiObj)
        catch
            return false
    }

    FindOwnerHwnd(childHwnd) {
        if !childHwnd
            return 0
        for ownerHwnd, entry in this.OwnerLocks {
            if entry.Children.Has(childHwnd)
                return ownerHwnd
        }
        return 0
    }

    MinimizeChildIndependently(childHwnd) {
        ownerHwnd := this.FindOwnerHwnd(childHwnd)
        if !ownerHwnd || !this.Platform.IsWindow(childHwnd)
            || !this.Platform.IsWindow(ownerHwnd)
            return false
        entry := this.OwnerLocks[ownerHwnd]
        if entry.SuspendedChildren.Has(childHwnd) {
            this.ActivateAfterChildSuspended(entry, ownerHwnd)
            return true
        }
        if this.Platform.GetNativeOwner(childHwnd) != ownerHwnd
            return false

        detached := false
        try {
            this.Platform.SetNativeOwner(childHwnd, 0)
            if this.Platform.GetNativeOwner(childHwnd) != 0
                throw Error("Unable to detach the child window owner")
            detached := true
            originalStyle := this.Platform.PromoteToTaskbar(childHwnd)
            entry.SuspendedChildren[childHwnd] := {
                ExtendedStyle: originalStyle,
                TaskbarRegistered: false
            }
            entry.SuspendedChildren[childHwnd].TaskbarRegistered :=
                this.Platform.RegisterTaskbarTab(childHwnd)
            if !this.Platform.MinimizeWindow(childHwnd)
                throw Error("Unable to minimize the child window")
        } catch {
            if entry.SuspendedChildren.Has(childHwnd) {
                suspendedState := entry.SuspendedChildren[childHwnd]
                entry.SuspendedChildren.Delete(childHwnd)
                try this.Platform.UnregisterTaskbarTab(childHwnd)
                if IsObject(suspendedState)
                    && suspendedState.HasOwnProp("ExtendedStyle")
                    try this.Platform.RestoreTaskbarStyle(childHwnd,
                        suspendedState.ExtendedStyle)
            }
            if detached && this.Platform.IsWindow(childHwnd)
                    && this.Platform.IsWindow(ownerHwnd)
                try this.Platform.SetNativeOwner(childHwnd, ownerHwnd)
            return false
        }
        this.UpdateOwnerModalState(entry, ownerHwnd)
        this.ActivateAfterChildSuspended(entry, ownerHwnd)
        return true
    }

    PrepareChildRestore(childHwnd) {
        ownerHwnd := this.FindOwnerHwnd(childHwnd)
        if !ownerHwnd || !this.OwnerLocks.Has(ownerHwnd)
            return false
        entry := this.OwnerLocks[ownerHwnd]
        if !entry.SuspendedChildren.Has(childHwnd)
            return false
        if !this.Platform.IsWindow(childHwnd)
                || !this.Platform.IsWindow(ownerHwnd) {
            this.PruneOwner(entry.Gui)
            return false
        }

        suspendedState := entry.SuspendedChildren[childHwnd]
        try {
            this.Platform.SetNativeOwner(childHwnd, ownerHwnd)
            if this.Platform.GetNativeOwner(childHwnd) != ownerHwnd
                throw Error("Unable to restore the child window owner")
            ; Keep APPWINDOW and the explicit taskbar tab until the owner has
            ; been restored successfully. If SetNativeOwner fails, the user
            ; still has a taskbar entry from which to retry.
            this.Platform.UnregisterTaskbarTab(childHwnd)
            if IsObject(suspendedState)
                    && suspendedState.HasOwnProp("ExtendedStyle")
                this.Platform.RestoreTaskbarStyle(childHwnd,
                    suspendedState.ExtendedStyle)
        } catch {
            return false
        }
        entry.SuspendedChildren.Delete(childHwnd)
        this.UpdateOwnerModalState(entry, ownerHwnd)
        return true
    }

    RestoreChildFromTaskbar(childHwnd, maximize := false) {
        ownerHwnd := this.FindOwnerHwnd(childHwnd)
        if !ownerHwnd || !this.OwnerLocks.Has(ownerHwnd)
            return false
        entry := this.OwnerLocks[ownerHwnd]
        if !entry.SuspendedChildren.Has(childHwnd)
            return false
        if !this.Platform.IsWindow(childHwnd)
                || !this.Platform.IsWindow(ownerHwnd) {
            this.PruneOwner(entry.Gui)
            return false
        }

        ; An owned window is hidden whenever its owner remains minimized.
        ; Restore the owner before rebuilding the native relationship so a
        ; taskbar-restored child cannot disappear behind a disabled owner.
        try {
            if !this.Platform.RestoreOwnerWindow(ownerHwnd)
                return false
            if !this.Platform.RestoreWindowFromTaskbar(childHwnd, maximize)
                return false
            if !this.PrepareChildRestore(childHwnd)
                return false
            ; The taskbar click already grants foreground activation. A
            ; subsequent WinActivate can still be rejected by test/offscreen
            ; desktops, but the child has been restored successfully.
            try this.Platform.ActivateOwnedWindow(childHwnd)
            return true
        } catch {
            return false
        }
    }

    Acquire(ownerGui, childHwnd := 0) {
        if !this.IsGuiAlive(ownerGui)
            return ""
        try ownerHwnd := this.Platform.GetHwnd(ownerGui)
        catch
            return ""
        this.PruneOwner(ownerGui)
        if this.OwnerLocks.Has(ownerHwnd) {
            entry := this.OwnerLocks[ownerHwnd]
            if entry.Gui == ownerGui {
                entry.Count++
                this.AddChildReference(entry, childHwnd)
                this.UpdateOwnerModalState(entry, ownerHwnd)
                return this.CreateLease(ownerHwnd, childHwnd)
            }
            this.OwnerLocks.Delete(ownerHwnd)
        }

        wasEnabled := this.Platform.IsWindowEnabled(ownerHwnd)
        entry := {
            Gui: ownerGui,
            Count: 1,
            RestoreEnabled: wasEnabled,
            Children: Map(),
            SuspendedChildren: Map()
        }
        this.AddChildReference(entry, childHwnd)
        this.OwnerLocks[ownerHwnd] := entry
        if wasEnabled {
            try this.Platform.SetGuiEnabled(ownerGui, false)
            catch {
                this.OwnerLocks.Delete(ownerHwnd)
                return ""
            }
        }
        return this.CreateLease(ownerHwnd, childHwnd)
    }

    Release(lease) {
        if !this.IsValidLease(lease) || lease.Released
            return ""
        lease.Released := true
        ownerHwnd := lease.OwnerHwnd
        if !this.OwnerLocks.Has(ownerHwnd)
            return ""

        entry := this.OwnerLocks[ownerHwnd]
        this.RemoveChildReference(entry, lease.ChildHwnd)
        entry.Count--
        if entry.Count > 0 {
            this.UpdateOwnerModalState(entry, ownerHwnd)
            return {Mode: "child", Owner: entry.Gui, OwnerHwnd: ownerHwnd}
        }

        this.OwnerLocks.Delete(ownerHwnd)
        return this.RestoreOwner(entry, ownerHwnd)
    }

    CompleteClose(closeContext) {
        if !IsObject(closeContext) || !closeContext.HasOwnProp("Mode")
            return
        if closeContext.Mode == "child" {
            if closeContext.HasOwnProp("Owner")
                    && !this.ActivateTopOwned(closeContext.Owner)
                    && closeContext.HasOwnProp("OwnerHwnd")
                this.ActivateOwnerIfAvailable(closeContext.OwnerHwnd)
            return
        }
        if closeContext.Mode != "owner"
            return
        if !closeContext.HasOwnProp("Activate") || !closeContext.Activate
            return
        if !closeContext.HasOwnProp("Owner")
            || !this.IsGuiAlive(closeContext.Owner)
            return
        if !closeContext.HasOwnProp("OwnerHwnd")
            return
        ownerHwnd := closeContext.OwnerHwnd
        if !this.Platform.IsWindowVisible(ownerHwnd)
            || this.Platform.IsWindowMinimized(ownerHwnd)
            return
        try this.Platform.ActivateOwnerWindow(ownerHwnd)
    }

    PruneOwner(ownerGui) {
        if !this.IsGuiAlive(ownerGui)
            return false
        try ownerHwnd := this.Platform.GetHwnd(ownerGui)
        catch
            return false
        if !this.OwnerLocks.Has(ownerHwnd)
            return false
        entry := this.OwnerLocks[ownerHwnd]
        if entry.Gui != ownerGui {
            this.OwnerLocks.Delete(ownerHwnd)
            return false
        }

        staleChildren := []
        for childHwnd, referenceCount in entry.Children {
            suspended := entry.SuspendedChildren.Has(childHwnd)
            nativeOwner := this.Platform.IsWindow(childHwnd)
                ? this.Platform.GetOwnedWindowOwner(childHwnd) : 0
            if !this.Platform.IsWindow(childHwnd)
                || (!suspended && nativeOwner != ownerHwnd)
                || (suspended && nativeOwner != 0)
                staleChildren.Push({Hwnd: childHwnd, Count: referenceCount})
        }
        for staleChild in staleChildren {
            entry.Children.Delete(staleChild.Hwnd)
            if entry.SuspendedChildren.Has(staleChild.Hwnd) {
                suspendedState := entry.SuspendedChildren[staleChild.Hwnd]
                if this.Platform.IsWindow(staleChild.Hwnd) {
                    try this.Platform.UnregisterTaskbarTab(staleChild.Hwnd)
                    if IsObject(suspendedState)
                            && suspendedState.HasOwnProp("ExtendedStyle")
                        try this.Platform.RestoreTaskbarStyle(
                            staleChild.Hwnd, suspendedState.ExtendedStyle)
                }
                entry.SuspendedChildren.Delete(staleChild.Hwnd)
            }
            entry.Count -= staleChild.Count
        }
        if entry.Count > 0 {
            this.UpdateOwnerModalState(entry, ownerHwnd)
            return true
        }

        this.OwnerLocks.Delete(ownerHwnd)
        closeContext := this.RestoreOwner(entry, ownerHwnd)
        this.CompleteClose(closeContext)
        return false
    }

    IsOwnerLocked(ownerGui) {
        if !this.IsGuiAlive(ownerGui) || !this.PruneOwner(ownerGui)
            return false
        ownerHwnd := this.Platform.GetHwnd(ownerGui)
        return this.OwnerLocks.Has(ownerHwnd)
            && this.HasActiveChildren(this.OwnerLocks[ownerHwnd])
    }

    ActivateTopOwned(ownerGui) {
        if !this.IsGuiAlive(ownerGui)
            return false
        this.PruneOwner(ownerGui)
        ownerHwnd := this.Platform.GetHwnd(ownerGui)
        currentHwnd := ownerHwnd
        visited := Map()
        Loop 16 {
            if visited.Has(currentHwnd) || !this.OwnerLocks.Has(currentHwnd)
                break
            visited[currentHwnd] := true
            entry := this.OwnerLocks[currentHwnd]
            this.PruneOwner(entry.Gui)
            if !this.OwnerLocks.Has(currentHwnd)
                break
            entry := this.OwnerLocks[currentHwnd]
            nextHwnd := this.FindVisibleChild(entry, currentHwnd)
            if !nextHwnd {
                nextHwnd := this.FindRecoverableChild(entry, currentHwnd)
                if !nextHwnd
                    break
            }
            ; Windows can hide an owned modal after its owner is minimized.
            ; Once the child has been reattached, Windows can refuse to
            ; restore the disabled owner. Detach the hidden child briefly so
            ; the owner can return to its normal position, then rebuild the
            ; exact modal relationship before showing the child.
            ownerNeedsRestore := !this.Platform.IsWindowVisible(currentHwnd)
                || this.Platform.IsWindowMinimized(currentHwnd)
            childNeedsRestore := !this.Platform.IsWindowVisible(nextHwnd)
                || this.Platform.IsWindowMinimized(nextHwnd)
            if (ownerNeedsRestore || childNeedsRestore)
                    && !this.RecoverOwnedChild(currentHwnd, nextHwnd)
                return false
            currentHwnd := nextHwnd
        }
        if currentHwnd == ownerHwnd
            return false
        if !this.Platform.IsWindowVisible(currentHwnd)
            return false
        try this.Platform.ActivateOwnedWindow(currentHwnd)
        return true
    }

    AddChildReference(entry, childHwnd) {
        if childHwnd
            entry.Children[childHwnd] := entry.Children.Get(childHwnd, 0) + 1
    }

    RemoveChildReference(entry, childHwnd) {
        if !childHwnd || !entry.Children.Has(childHwnd)
            return
        referenceCount := entry.Children[childHwnd] - 1
        if referenceCount > 0
            entry.Children[childHwnd] := referenceCount
        else {
            entry.Children.Delete(childHwnd)
            if entry.SuspendedChildren.Has(childHwnd) {
                suspendedState := entry.SuspendedChildren[childHwnd]
                try this.Platform.UnregisterTaskbarTab(childHwnd)
                if this.Platform.IsWindow(childHwnd)
                        && IsObject(suspendedState)
                        && suspendedState.HasOwnProp("ExtendedStyle")
                    try this.Platform.RestoreTaskbarStyle(childHwnd,
                        suspendedState.ExtendedStyle)
                entry.SuspendedChildren.Delete(childHwnd)
            }
        }
    }

    HasActiveChildren(entry) {
        for childHwnd in entry.Children {
            if !entry.SuspendedChildren.Has(childHwnd)
                return true
        }
        return false
    }

    UpdateOwnerModalState(entry, ownerHwnd) {
        if !entry.RestoreEnabled || !this.IsGuiAlive(entry.Gui)
            return
        shouldEnable := !this.HasActiveChildren(entry)
        isEnabled := this.Platform.IsWindowEnabled(ownerHwnd)
        if shouldEnable != isEnabled
            try this.Platform.SetGuiEnabled(entry.Gui, shouldEnable)
    }

    ActivateAfterChildSuspended(entry, ownerHwnd) {
        if this.HasActiveChildren(entry) {
            this.ActivateTopOwned(entry.Gui)
            return
        }
        this.ActivateOwnerIfAvailable(ownerHwnd)
    }

    ActivateOwnerIfAvailable(ownerHwnd) {
        if !this.Platform.IsWindow(ownerHwnd)
                || !this.Platform.IsWindowVisible(ownerHwnd)
                || this.Platform.IsWindowMinimized(ownerHwnd)
                || !this.Platform.IsWindowEnabled(ownerHwnd)
            return false
        try this.Platform.ActivateOwnerWindow(ownerHwnd)
        return true
    }

    CreateLease(ownerHwnd, childHwnd) {
        return {OwnerHwnd: ownerHwnd, ChildHwnd: childHwnd, Released: false}
    }

    IsValidLease(lease) {
        return IsObject(lease)
            && lease.HasOwnProp("OwnerHwnd")
            && lease.HasOwnProp("ChildHwnd")
            && lease.HasOwnProp("Released")
    }

    RestoreOwner(entry, ownerHwnd) {
        wasVisible := this.Platform.IsWindowVisible(ownerHwnd)
        wasMinimized := this.Platform.IsWindowMinimized(ownerHwnd)
        if entry.RestoreEnabled && this.IsGuiAlive(entry.Gui)
            try this.Platform.SetGuiEnabled(entry.Gui, true)
        return {
            Mode: "owner",
            Owner: entry.Gui,
            OwnerHwnd: ownerHwnd,
            Activate: entry.RestoreEnabled && wasVisible && !wasMinimized
        }
    }

    FindVisibleChild(entry, ownerHwnd) {
        activePopup := this.Platform.GetLastActivePopup(ownerHwnd)
        if entry.Children.Has(activePopup)
            && !entry.SuspendedChildren.Has(activePopup)
            && this.Platform.IsWindowVisible(activePopup)
            && !this.Platform.IsWindowMinimized(activePopup)
            return activePopup
        for childHwnd in entry.Children {
            if !entry.SuspendedChildren.Has(childHwnd)
                && this.Platform.IsWindowVisible(childHwnd)
                && !this.Platform.IsWindowMinimized(childHwnd)
                return childHwnd
        }
        return 0
    }

    FindRecoverableChild(entry, ownerHwnd) {
        activePopup := this.Platform.GetLastActivePopup(ownerHwnd)
        if entry.Children.Has(activePopup)
                && !entry.SuspendedChildren.Has(activePopup)
                && this.Platform.IsWindow(activePopup)
            return activePopup
        for childHwnd in entry.Children {
            if !entry.SuspendedChildren.Has(childHwnd)
                    && this.Platform.IsWindow(childHwnd)
                return childHwnd
        }
        return 0
    }

    RecoverOwnedChild(ownerHwnd, childHwnd) {
        if !this.Platform.IsWindow(ownerHwnd)
                || !this.Platform.IsWindow(childHwnd)
            return false
        detached := false
        try {
            this.Platform.SetNativeOwner(childHwnd, 0)
            if this.Platform.GetNativeOwner(childHwnd) != 0
                return false
            detached := true
            if !this.Platform.RestoreOwnerWindow(ownerHwnd)
                return false
            this.Platform.SetNativeOwner(childHwnd, ownerHwnd)
            if this.Platform.GetNativeOwner(childHwnd) != ownerHwnd
                return false
            detached := false
            return this.Platform.RestoreOwnedWindow(childHwnd)
        } catch {
            return false
        } finally {
            if detached && this.Platform.IsWindow(childHwnd)
                    && this.Platform.IsWindow(ownerHwnd)
                try this.Platform.SetNativeOwner(childHwnd, ownerHwnd)
        }
    }
}

class WindowHierarchy {
    static Manager := WindowHierarchyManager(WindowHierarchyPlatform())

    static IsGuiAlive(guiObj) {
        return this.Manager.IsGuiAlive(guiObj)
    }

    static FindOwnerHwnd(childHwnd) {
        return this.Manager.FindOwnerHwnd(childHwnd)
    }

    static Acquire(ownerGui, childHwnd := 0) {
        return this.Manager.Acquire(ownerGui, childHwnd)
    }

    static Release(lease) {
        return this.Manager.Release(lease)
    }

    static CompleteClose(closeContext) {
        this.Manager.CompleteClose(closeContext)
    }

    static PruneOwner(ownerGui) {
        return this.Manager.PruneOwner(ownerGui)
    }

    static IsOwnerLocked(ownerGui) {
        return this.Manager.IsOwnerLocked(ownerGui)
    }

    static ActivateTopOwned(ownerGui) {
        return this.Manager.ActivateTopOwned(ownerGui)
    }

    static MinimizeChildIndependently(childHwnd) {
        return this.Manager.MinimizeChildIndependently(childHwnd)
    }

    static PrepareChildRestore(childHwnd) {
        return this.Manager.PrepareChildRestore(childHwnd)
    }

    static RestoreChildFromTaskbar(childHwnd, maximize := false) {
        return this.Manager.RestoreChildFromTaskbar(childHwnd, maximize)
    }
}
