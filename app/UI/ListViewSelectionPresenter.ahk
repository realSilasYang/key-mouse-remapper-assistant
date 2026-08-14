; 保留原生 ListView 语义，只把矩形选中底色的外角遮罩成圆角。

class ListViewSelectionPresenter {
    static HorizontalInsetDip := 4
    static VerticalInsetDip := 2
    static RadiusDip := 7

    __New(listView, painter, subItemDrawCallback := "") {
        this.ListView := listView
        this.Painter := painter
        this.SubItemDrawCallback := IsObject(subItemDrawCallback)
            ? subItemDrawCallback : ""
        this.NotifyCallback := ObjBindMethod(this, "HandleCustomDraw")
        this.Attached := false
        if IsObject(listView) && listView.Hwnd && IsObject(painter) {
            listView.OnNotify(Win32.NM_CUSTOMDRAW, this.NotifyCallback)
            this.Attached := true
        }
    }

    Dispose(*) {
        if !this.Attached
            return true
        this.ListView.OnNotify(Win32.NM_CUSTOMDRAW,
            this.NotifyCallback, -1)
        this.Attached := false
        this.ListView := ""
        this.Painter := ""
        this.SubItemDrawCallback := ""
        this.NotifyCallback := ""
        return true
    }

    IsSelected(listView, lParam, itemState) {
        if itemState & Win32.CDIS_SELECTED
            return true
        itemSpecOffset := A_PtrSize == 8 ? 56 : 36
        itemIndex := NumGet(lParam, itemSpecOffset, "UPtr")
        return (SendMessage(Win32.LVM_GETITEMSTATE, itemIndex,
            Win32.LVIS_SELECTED, listView.Hwnd) & Win32.LVIS_SELECTED) != 0
    }

    RefreshItem(row) {
        if !this.Attached || row <= 0 || row > this.ListView.GetCount()
            return false
        result := SendMessage(Win32.LVM_REDRAWITEMS, row - 1, row - 1,
            this.ListView.Hwnd)
        DllCall("user32\UpdateWindow", "Ptr", this.ListView.Hwnd, "Int")
        return result != 0
    }

    HandleCustomDraw(listView, lParam) {
        if !lParam || !this.Attached || listView.Hwnd != this.ListView.Hwnd
            return
        stageOffset := A_PtrSize == 8 ? 24 : 12
        stage := NumGet(lParam, stageOffset, "UInt")
        if stage == Win32.CDDS_PREPAINT
            return Win32.CDRF_NOTIFYITEMDRAW
        if stage == (Win32.CDDS_ITEMPREPAINT | Win32.CDDS_SUBITEM) {
            if IsObject(this.SubItemDrawCallback) {
                result := this.SubItemDrawCallback.Call(listView, lParam)
                if result != "" {
                    stateOffset := A_PtrSize == 8 ? 64 : 40
                    itemState := NumGet(lParam, stateOffset, "UInt")
                    if this.IsSelected(listView, lParam, itemState)
                        this.MaskSelectedRow(listView, lParam)
                }
                return result
            }
            return
        }
        if stage != Win32.CDDS_ITEMPREPAINT
                && stage != Win32.CDDS_ITEMPOSTPAINT
            return
        stateOffset := A_PtrSize == 8 ? 64 : 40
        itemState := NumGet(lParam, stateOffset, "UInt")
        if stage == Win32.CDDS_ITEMPREPAINT
                && itemState & Win32.CDIS_FOCUS {
            itemState &= ~Win32.CDIS_FOCUS
            NumPut("UInt", itemState, lParam, stateOffset)
        }
        selected := this.IsSelected(listView, lParam, itemState)
        if stage == Win32.CDDS_ITEMPREPAINT {
            flags := IsObject(this.SubItemDrawCallback)
                ? Win32.CDRF_NOTIFYITEMDRAW : Win32.CDRF_DODEFAULT
            return selected && !IsObject(this.SubItemDrawCallback)
                ? flags | Win32.CDRF_NOTIFYPOSTPAINT : flags
        }
        if !selected
            return
        this.MaskSelectedRow(listView, lParam)
        return Win32.CDRF_DODEFAULT
    }

    MaskSelectedRow(listView, lParam) {
        itemSpecOffset := A_PtrSize == 8 ? 56 : 36
        itemIndex := NumGet(lParam, itemSpecOffset, "UPtr")
        rowRect := Buffer(16, 0)
        NumPut("Int", Win32.LVIR_BOUNDS, rowRect, 0)
        if !SendMessage(Win32.LVM_GETITEMRECT, itemIndex, rowRect.Ptr, ,
                listView.Hwnd)
            return false
        hdcOffset := A_PtrSize == 8 ? 32 : 16
        hdc := NumGet(lParam, hdcOffset, "Ptr")
        left := NumGet(rowRect, 0, "Int")
        top := NumGet(rowRect, 4, "Int")
        right := NumGet(rowRect, 8, "Int")
        bottom := NumGet(rowRect, 12, "Int")
        windowDpi := DllCall("user32\GetDpiForWindow", "Ptr", listView.Hwnd,
            "UInt")
        if !windowDpi
            windowDpi := 96
        horizontalInset := Max(2, Round(
            ListViewSelectionPresenter.HorizontalInsetDip * windowDpi / 96))
        verticalInset := Max(1, Round(
            ListViewSelectionPresenter.VerticalInsetDip * windowDpi / 96))
        radius := Max(3, Round(
            ListViewSelectionPresenter.RadiusDip * windowDpi / 96))
        return this.Painter.MaskOutsideRoundedRectangle(hdc,
            left, top, right, bottom,
            left + horizontalInset, top + verticalInset,
            right - horizontalInset, bottom - verticalInset,
            UiThemeService.Color("Surface"), radius)
    }
}
