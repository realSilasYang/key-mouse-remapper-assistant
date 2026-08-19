; 同级子控件的原子布局事务。调用方只提供 96-DPI 逻辑坐标和父背景色。

class AtomicControlLayoutEraseGuard {
    static SubclassId := 0x4B4D4C47
    static CallbackPointer := 0
    static AttachedHwnds := Map()
    static ActiveHwndCounts := Map()
    static BlockedEraseCount := 0

    static Begin(controls) {
        transaction := {Hwnds: []}
        if Type(controls) != "Array" || !controls.Length
            return transaction
        if !this.EnsureCallback()
            throw Error("无法创建控件擦除保护。")
        try {
            for control in controls {
                try hwnd := control.Hwnd
                catch
                    continue
                if !hwnd || !DllCall("user32\IsWindow", "Ptr", hwnd, "Int")
                    continue
                if !this.AttachedHwnds.Has(hwnd) {
                    if !DllCall("comctl32\SetWindowSubclass", "Ptr", hwnd,
                            "Ptr", this.CallbackPointer, "UPtr",
                            this.SubclassId, "UPtr", 0, "Int")
                        throw Error("无法安装控件擦除保护。")
                    this.AttachedHwnds[hwnd] := true
                }
                count := this.ActiveHwndCounts.Has(hwnd)
                    ? this.ActiveHwndCounts[hwnd] : 0
                this.ActiveHwndCounts[hwnd] := count + 1
                transaction.Hwnds.Push(hwnd)
            }
        } catch as installError {
            this.End(transaction)
            throw installError
        }
        return transaction
    }

    static End(transaction) {
        if !IsObject(transaction) || !transaction.HasOwnProp("Hwnds")
            return false
        for hwnd in transaction.Hwnds {
            if !this.ActiveHwndCounts.Has(hwnd)
                continue
            count := this.ActiveHwndCounts[hwnd] - 1
            if count > 0
                this.ActiveHwndCounts[hwnd] := count
            else
                this.ActiveHwndCounts.Delete(hwnd)
        }
        return true
    }

    static EnsureCallback() {
        if this.CallbackPointer
            return true
        this.CallbackPointer := CallbackCreate(ObjBindMethod(this,
            "WindowProc"),, 6)
        return this.CallbackPointer != 0
    }

    static WindowProc(hwnd, message, wParam, lParam, subclassId,
            referenceData) {
        if message == 0x0082 {
            if this.AttachedHwnds.Has(hwnd)
                this.AttachedHwnds.Delete(hwnd)
            if this.ActiveHwndCounts.Has(hwnd)
                this.ActiveHwndCounts.Delete(hwnd)
        }
        if message == 0x0014 && this.ActiveHwndCounts.Has(hwnd) {
            this.BlockedEraseCount++
            return 1
        }
        return DllCall("comctl32\DefSubclassProc", "Ptr", hwnd,
            "UInt", message, "UPtr", wParam, "Ptr", lParam, "Ptr")
    }
}

class AtomicControlLayout {
    static Unchanged := "Unchanged"
    static Applied := "Applied"
    static Unavailable := "Unavailable"
    static Failed := "Failed"
    static ModeDeferred := "Deferred"
    static ModeDirect := "Direct"
    static ModeFallback := "Fallback"
    static SwpFlags := 0x031C
    static DcxClipChildren := 0x000A
    static RdwRefreshNoErase := 0x01A1
    static RdwParentRefreshNoErase := 0x0161
    static RdwChildRefreshNoErase := 0x0121

    static BeginRound(parentGui) {
        parentHwnd := this.GetHwnd(parentGui)
        if !parentHwnd || !DllCall("user32\IsWindow", "Ptr", parentHwnd,
                "Int")
            return false
        dpi := this.GetDpi(parentHwnd)
        effectiveDpi := UiScaleService.GetEffectiveDpi(parentHwnd)
        return {ParentHwnd: parentHwnd, Dpi: effectiveDpi,
            WindowDpi: dpi, Scale: effectiveDpi / 96}
    }

    static Apply(parentGui, entries, options := "") {
        result := {Status: this.Failed, Mode: "None", Changed: false,
            Repainted: false, Reason: "", OldRects: [], NewRects: [],
            ActualRects: Map(), ChangedHwnds: Map()}
        parentHwnd := this.GetHwnd(parentGui)
        if !parentHwnd || !DllCall("user32\IsWindow", "Ptr", parentHwnd,
                "Int") {
            result.Status := this.Unavailable
            result.Reason := "父窗口不可用。"
            return result
        }
        normalized := this.NormalizeEntries(entries)
        if !normalized.Ok {
            result.Reason := normalized.Reason
            return result
        }
        parentColor := this.GetOption(options, "ParentColor", "")
        if parentColor == "" {
            try parentColor := parentGui.BackColor
            catch
                parentColor := ""
        }
        if parentColor == "" {
            result.Reason := "必须提供父窗口背景色。"
            return result
        }
        try clearMargin := Max(0,
            Number(this.GetOption(options, "ClearMargin", 0)))
        catch {
            result.Reason := "圆角清理边距无效。"
            return result
        }

        layoutRound := this.GetOption(options, "Round", "")
        if IsObject(layoutRound)
                && layoutRound.HasOwnProp("ParentHwnd")
                && layoutRound.HasOwnProp("Scale")
                && layoutRound.ParentHwnd == parentHwnd {
            scale := layoutRound.Scale
        } else {
            scale := this.GetDpiScale(parentHwnd)
        }
        physicalEntries := []
        changedEntries := []
        changedControls := []
        seenHwnds := Map()
        for logical in normalized.Entries {
            hwnd := this.GetHwnd(logical.Control)
            if !hwnd || !DllCall("user32\IsWindow", "Ptr", hwnd, "Int") {
                result.Status := this.Unavailable
                result.Reason := "子控件不可用。"
                return result
            }
            if DllCall("user32\GetParent", "Ptr", hwnd, "Ptr")
                    != parentHwnd {
                result.Reason := "布局条目不是父窗口的同级直属子控件。"
                return result
            }
            if seenHwnds.Has(hwnd) {
                result.Reason := "布局条目包含重复 HWND。"
                return result
            }
            seenHwnds[hwnd] := true
            oldRect := this.GetControlBounds(hwnd, parentHwnd)
            if !oldRect {
                result.Status := this.Unavailable
                result.Reason := "无法读取子控件旧矩形。"
                return result
            }
            target := {Control: logical.Control, Logical: logical,
                Hwnd: hwnd, X: Round(logical.X * scale),
                Y: Round(logical.Y * scale),
                Width: Round(logical.Width * scale),
                Height: Round(logical.Height * scale), OldRect: oldRect}
            physicalEntries.Push(target)
            result.ActualRects[hwnd] := oldRect
            if this.RectMatchesTarget(oldRect, target)
                continue
            changedEntries.Push(target)
            changedControls.Push(logical.Control)
            result.ChangedHwnds[hwnd] := true
            result.OldRects.Push(oldRect)
        }
        if !changedEntries.Length {
            result.Status := this.Unchanged
            return result
        }
        result.Changed := true

        if !DllCall("user32\IsWindowVisible", "Ptr", parentHwnd, "Int")
            return this.ApplyHidden(parentHwnd, physicalEntries,
                changedEntries, result)

        eraseGuard := ""
        try {
            eraseGuard := AtomicControlLayoutEraseGuard.Begin(
                changedControls)
            if this.TryApplyDeferred(changedEntries) {
                result.Mode := this.ModeDeferred
            } else {
                result.Mode := this.ModeFallback
                result.Reason := "批量布局提交不可用，已进入受保护回退。"
                this.MovePhysicalDirect(changedEntries)
            }
            verification := this.ReadAndValidateTargets(physicalEntries,
                changedEntries, parentHwnd)
            if !verification.Ok
                throw Error(verification.Reason)
            result.ActualRects := verification.ActualRects
            result.NewRects := verification.ChangedRects
            result.Repainted := this.Repaint(parentHwnd, result.OldRects,
                result.NewRects, parentColor, Round(clearMargin * scale),
                result.ChangedHwnds)
            if !result.Repainted
                throw Error("无法完成父表面局部收尾。")
            result.Status := this.Applied
            return result
        } catch as layoutError {
            result.Mode := this.ModeFallback
            result.Reason := layoutError.Message
            try {
                if !IsObject(eraseGuard)
                    eraseGuard := AtomicControlLayoutEraseGuard.Begin(
                        changedControls)
                this.MovePhysicalDirect(changedEntries)
                verification := this.ReadAndValidateTargets(
                    physicalEntries, changedEntries, parentHwnd)
                if !verification.Ok
                    throw Error(verification.Reason)
                result.ActualRects := verification.ActualRects
                result.NewRects := verification.ChangedRects
                result.Repainted := this.Repaint(parentHwnd,
                    result.OldRects, result.NewRects, parentColor,
                    Round(clearMargin * scale), result.ChangedHwnds)
                if !result.Repainted
                    throw Error("受保护回退无法完成父表面局部收尾。")
                result.Status := this.Applied
            } catch as fallbackError {
                result.Reason := layoutError.Message "; fallback: "
                    fallbackError.Message
            }
            return result
        } finally {
            if IsObject(eraseGuard)
                AtomicControlLayoutEraseGuard.End(eraseGuard)
        }
    }

    static ApplyHidden(parentHwnd, physicalEntries, changedEntries,
            result) {
        try {
            this.MovePhysicalDirect(changedEntries)
            verification := this.ReadAndValidateTargets(physicalEntries,
                changedEntries, parentHwnd)
            if !verification.Ok
                throw Error(verification.Reason)
            result.ActualRects := verification.ActualRects
            result.NewRects := verification.ChangedRects
            result.Status := this.Applied
            result.Mode := this.ModeDirect
        } catch as moveError {
            result.Reason := moveError.Message
        }
        return result
    }

    static GetHwnd(value) {
        try return value.Hwnd
        catch
            return 0
    }

    static GetOption(options, name, defaultValue) {
        return IsObject(options) && options.HasOwnProp(name)
            ? options.%name% : defaultValue
    }

    static NormalizeEntries(entries) {
        if Type(entries) != "Array" || !entries.Length
            return {Ok: false, Reason: "至少需要一个布局条目。"}
        normalized := []
        for spec in entries {
            if !IsObject(spec)
                return {Ok: false, Reason: "布局条目不是对象。"}
            try {
                control := spec.Control
                x := Number(spec.X)
                y := Number(spec.Y)
                width := Number(spec.Width)
                height := Number(spec.Height)
            } catch {
                return {Ok: false, Reason: "布局条目不完整。"}
            }
            if !control || width < 0 || height < 0
                return {Ok: false, Reason: "布局条目的几何尺寸无效。"}
            normalized.Push({Control: control, X: x, Y: y,
                Width: width, Height: height})
        }
        return {Ok: true, Entries: normalized}
    }

    static GetDpiScale(parentHwnd) {
        return Round(this.GetDpi(parentHwnd)
            * UiScaleService.GetFactor()) / 96
    }

    static GetDpi(parentHwnd) {
        dpi := DllCall("user32\GetDpiForWindow", "Ptr", parentHwnd,
            "UInt")
        return dpi ? dpi : 96
    }

    static TryApplyDeferred(entries) {
        deferred := DllCall("user32\BeginDeferWindowPos", "Int",
            entries.Length, "Ptr")
        if !deferred
            return false
        for item in entries {
            deferred := DllCall("user32\DeferWindowPos", "Ptr", deferred,
                "Ptr", item.Hwnd, "Ptr", 0, "Int", item.X,
                "Int", item.Y, "Int", item.Width, "Int", item.Height,
                "UInt", this.SwpFlags, "Ptr")
            if !deferred
                return false
        }
        return DllCall("user32\EndDeferWindowPos", "Ptr", deferred,
            "Int") != 0
    }

    static MoveLogicalDirect(entries) {
        for item in entries
            item.Logical.Control.Move(item.Logical.X, item.Logical.Y,
                item.Logical.Width, item.Logical.Height)
    }

    static MovePhysicalDirect(entries) {
        for item in entries {
            if !DllCall("user32\SetWindowPos", "Ptr", item.Hwnd,
                    "Ptr", 0, "Int", item.X, "Int", item.Y,
                    "Int", item.Width, "Int", item.Height,
                    "UInt", this.SwpFlags, "Int")
                throw OSError(A_LastError, "受保护回退定位控件失败。")
        }
        return true
    }

    static ReadAndValidateTargets(entries, changedEntries, parentHwnd) {
        actualRects := Map()
        for item in entries {
            rect := this.GetControlBounds(item.Hwnd, parentHwnd)
            if !rect
                return {Ok: false, Reason: "提交后无法读取控件实际矩形。"}
            actualRects[item.Hwnd] := rect
            if !this.RectMatchesTarget(rect, item)
                return {Ok: false, Reason: "提交后的控件矩形与目标不一致。"}
        }
        changedRects := []
        for item in changedEntries
            changedRects.Push(actualRects[item.Hwnd])
        return {Ok: true, ActualRects: actualRects,
            ChangedRects: changedRects}
    }

    static RectMatchesTarget(rect, target) {
        return rect.Left == target.X && rect.Top == target.Y
            && rect.Right - rect.Left == target.Width
            && rect.Bottom - rect.Top == target.Height
    }

    static GetControlBounds(hwnd, parentHwnd) {
        rect := Buffer(16, 0)
        if !DllCall("user32\GetWindowRect", "Ptr", hwnd, "Ptr", rect,
                "Int")
            return false
        DllCall("kernel32\SetLastError", "UInt", 0)
        mapped := DllCall("user32\MapWindowPoints", "Ptr", 0, "Ptr",
            parentHwnd, "Ptr", rect, "UInt", 2, "Int")
        if !mapped && A_LastError
            return false
        return {Left: NumGet(rect, 0, "Int"),
            Top: NumGet(rect, 4, "Int"), Right: NumGet(rect, 8, "Int"),
            Bottom: NumGet(rect, 12, "Int")}
    }

    static Repaint(parentHwnd, oldRects, newRects, color, margin,
            changedHwnds := "") {
        if !oldRects.Length || !newRects.Length
            return false
        refreshRects := []
        for rect in oldRects
            refreshRects.Push(rect)
        for rect in newRects
            refreshRects.Push(rect)
        refreshRect := this.CreateUnionRect(parentHwnd, refreshRects, margin)
        if !IsObject(refreshRect)
            return false
        if !this.PaintParentClientBackground(parentHwnd, refreshRect,
                color)
            return false
        rect := Buffer(16, 0)
        NumPut("Int", refreshRect.Left, "Int", refreshRect.Top,
            "Int", refreshRect.Right, "Int", refreshRect.Bottom, rect)
        parentRedrawn := DllCall("user32\RedrawWindow", "Ptr", parentHwnd,
            "Ptr", rect, "Ptr", 0, "UInt", this.RdwParentRefreshNoErase,
            "Int") != 0
        return parentRedrawn && this.RefreshChangedChildren(changedHwnds)
    }

    static RefreshChangedChildren(changedHwnds) {
        if !IsObject(changedHwnds)
            return true
        for hwnd, _ in changedHwnds {
            if !hwnd || !DllCall("user32\IsWindow", "Ptr", hwnd, "Int")
                    || !DllCall("user32\IsWindowVisible", "Ptr", hwnd,
                        "Int")
                continue
            refreshed := false
            Loop 2 {
                if !DllCall("user32\InvalidateRect", "Ptr", hwnd,
                        "Ptr", 0, "Int", 0)
                    continue
                if DllCall("user32\RedrawWindow", "Ptr", hwnd,
                        "Ptr", 0, "Ptr", 0, "UInt",
                        this.RdwChildRefreshNoErase, "Int") {
                    refreshed := true
                    break
                }
            }
            if !refreshed
                return false
        }
        ; Owner-drawn children finish through WM_DRAWITEM on this thread.
        ; Commit that one GDI batch before WM_SIZE returns so callers never
        ; observe a partially copied child surface between resize frames.
        return DllCall("gdi32\GdiFlush", "Int") != 0
    }

    static PaintParentClientBackground(parentHwnd, rect, color) {
        try colorValue := Integer("0x" RegExReplace(String(color),
            "i)^(#|0x)"))
        catch
            return false
        hdc := 0
        brush := 0
        try {
            hdc := DllCall("user32\GetDCEx", "Ptr", parentHwnd,
                "Ptr", 0, "UInt", this.DcxClipChildren, "Ptr")
            brush := DllCall("gdi32\CreateSolidBrush", "UInt",
                ((colorValue & 0xFF) << 16) | (colorValue & 0x00FF00)
                    | ((colorValue >> 16) & 0xFF), "Ptr")
            if !hdc || !brush
                return false
            rectBuffer := Buffer(16, 0)
            NumPut("Int", rect.Left, "Int", rect.Top,
                "Int", rect.Right, "Int", rect.Bottom, rectBuffer)
            painted := DllCall("user32\FillRect", "Ptr", hdc,
                "Ptr", rectBuffer, "Ptr", brush, "Int") != 0
            if painted
                DllCall("gdi32\GdiFlush", "Int")
            return painted
        } finally {
            if brush
                DllCall("gdi32\DeleteObject", "Ptr", brush, "Int")
            if hdc
                DllCall("user32\ReleaseDC", "Ptr", parentHwnd,
                    "Ptr", hdc)
        }
    }

    static CreateUnionRect(parentHwnd, rects, margin) {
        clientRect := Buffer(16, 0)
        if !DllCall("user32\GetClientRect", "Ptr", parentHwnd,
                "Ptr", clientRect, "Int")
            return false
        clientRight := NumGet(clientRect, 8, "Int")
        clientBottom := NumGet(clientRect, 12, "Int")
        bounds := false
        for rect in rects {
            left := Max(0, rect.Left - margin)
            top := Max(0, rect.Top - margin)
            right := Min(clientRight, rect.Right + margin)
            bottom := Min(clientBottom, rect.Bottom + margin)
            if right <= left || bottom <= top
                continue
            if !IsObject(bounds) {
                bounds := {Left: left, Top: top,
                    Right: right, Bottom: bottom}
                continue
            }
            bounds.Left := Min(bounds.Left, left)
            bounds.Top := Min(bounds.Top, top)
            bounds.Right := Max(bounds.Right, right)
            bounds.Bottom := Max(bounds.Bottom, bottom)
        }
        return bounds
    }

    static CreateUnionRegion(parentHwnd, rects, margin) {
        clientRect := Buffer(16, 0)
        if !DllCall("user32\GetClientRect", "Ptr", parentHwnd,
                "Ptr", clientRect, "Int")
            return 0
        clientRight := NumGet(clientRect, 8, "Int")
        clientBottom := NumGet(clientRect, 12, "Int")
        region := DllCall("gdi32\CreateRectRgn", "Int", 0, "Int", 0,
            "Int", 0, "Int", 0, "Ptr")
        if !region
            return 0
        try {
            for rect in rects {
                left := Max(0, rect.Left - margin)
                top := Max(0, rect.Top - margin)
                right := Min(clientRight, rect.Right + margin)
                bottom := Min(clientBottom, rect.Bottom + margin)
                if right <= left || bottom <= top
                    continue
                part := DllCall("gdi32\CreateRectRgn", "Int", left,
                    "Int", top, "Int", right, "Int", bottom, "Ptr")
                if !part
                    throw Error("无法创建布局重绘区域。")
                try {
                    if DllCall("gdi32\CombineRgn", "Ptr", region,
                            "Ptr", region, "Ptr", part, "Int", 2,
                            "Int") == 0
                        throw Error("无法合并布局重绘区域。")
                } finally DllCall("gdi32\DeleteObject", "Ptr", part,
                    "Int")
            }
            return region
        } catch {
            DllCall("gdi32\DeleteObject", "Ptr", region, "Int")
            return 0
        }
    }

    static RegionHasArea(region) {
        bounds := Buffer(16, 0)
        return DllCall("gdi32\GetRgnBox", "Ptr", region,
            "Ptr", bounds, "Int") > 1
    }
}

; Native controls such as ListView and RichEdit can repaint their own client
; surfaces in response to WM_SIZE even when sibling geometry uses SWP_NOREDRAW.
; This child-only transaction keeps those internal surfaces closed until the
; outer geometry and control-specific mutations have both been committed.
class AtomicControlRedrawTransaction {
    static SetRedrawMessage := 0x000B
    static ActiveHwndCounts := Map()

    static Begin(controls, visibleOnly := true) {
        transaction := {Active: false, Hwnds: []}
        if Type(controls) != "Array" || !controls.Length
            return transaction
        try {
            seenHwnds := Map()
            for control in controls {
                hwnd := AtomicControlLayout.GetHwnd(control)
                if !hwnd || !DllCall("user32\IsWindow", "Ptr", hwnd,
                        "Int")
                    continue
                if visibleOnly && !DllCall("user32\IsWindowVisible",
                        "Ptr", hwnd, "Int")
                    continue
                if seenHwnds.Has(hwnd)
                    continue
                seenHwnds[hwnd] := true
                activeCount := this.ActiveHwndCounts.Has(hwnd)
                    ? this.ActiveHwndCounts[hwnd] : 0
                transaction.Hwnds.Push(hwnd)
                transaction.Active := true
                this.ActiveHwndCounts[hwnd] := activeCount + 1
                if !activeCount
                    DllCall("user32\SendMessageW", "Ptr", hwnd,
                        "UInt", this.SetRedrawMessage, "Ptr", 0, "Ptr", 0,
                        "Ptr")
            }
            return transaction
        } catch as suspendError {
            this.End(transaction)
            throw suspendError
        }
    }

    static End(transaction) {
        if !IsObject(transaction) || !transaction.Active
            return false
        transaction.Active := false
        resumed := true
        for hwnd in transaction.Hwnds {
            if !hwnd || !this.ActiveHwndCounts.Has(hwnd)
                continue
            activeCount := this.ActiveHwndCounts[hwnd] - 1
            if activeCount > 0 {
                this.ActiveHwndCounts[hwnd] := activeCount
                continue
            }
            this.ActiveHwndCounts.Delete(hwnd)
            if !DllCall("user32\IsWindow", "Ptr", hwnd, "Int")
                continue
            try DllCall("user32\SendMessageW", "Ptr", hwnd,
                "UInt", this.SetRedrawMessage, "Ptr", 1, "Ptr", 0,
                "Ptr")
            catch {
                resumed := false
                continue
            }
            if DllCall("user32\IsWindowVisible", "Ptr", hwnd, "Int") {
                try resumed := DllCall("user32\RedrawWindow", "Ptr", hwnd,
                    "Ptr", 0, "Ptr", 0,
                    "UInt", AtomicControlLayout.RdwRefreshNoErase,
                    "Int") != 0 && resumed
                catch
                    resumed := false
            }
        }
        return resumed
    }
}
