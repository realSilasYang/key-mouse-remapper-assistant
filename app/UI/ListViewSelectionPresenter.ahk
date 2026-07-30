; 保留原生 ListView 语义，只把矩形选中底色的外角遮罩成圆角。

class ListViewSelectionPresenter {
    static HorizontalInsetDip := 4
    static VerticalInsetDip := 2
    static RadiusDip := 7

    __New(listView, painter) {
        this.ListView := listView
        this.Painter := painter
        this.NotifyCallback := ObjBindMethod(this, "HandleCustomDraw")
        this.Attached := false
        if IsObject(listView) && listView.Hwnd && IsObject(painter) {
            listView.OnNotify(Win32.NM_CUSTOMDRAW, this.NotifyCallback)
            this.Attached := true
        }
    }

    Dispose(*) {
        if !this.Attached
            return
        this.Attached := false
        try this.ListView.OnNotify(Win32.NM_CUSTOMDRAW,
            this.NotifyCallback, -1)
        this.ListView := ""
        this.Painter := ""
        this.NotifyCallback := ""
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
        if stage != Win32.CDDS_ITEMPREPAINT
            && stage != Win32.CDDS_ITEMPOSTPAINT
            return
        stateOffset := A_PtrSize == 8 ? 64 : 40
        itemState := NumGet(lParam, stateOffset, "UInt")
        if !this.IsSelected(listView, lParam, itemState)
            return
        if stage == Win32.CDDS_ITEMPREPAINT
            return Win32.CDRF_NOTIFYPOSTPAINT

        hdcOffset := A_PtrSize == 8 ? 32 : 16
        rectOffset := A_PtrSize == 8 ? 40 : 20
        hdc := NumGet(lParam, hdcOffset, "Ptr")
        left := NumGet(lParam, rectOffset, "Int")
        top := NumGet(lParam, rectOffset + 4, "Int")
        right := NumGet(lParam, rectOffset + 8, "Int")
        bottom := NumGet(lParam, rectOffset + 12, "Int")
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
        this.Painter.MaskOutsideRoundedRectangle(hdc,
            left, top, right, bottom,
            left + horizontalInset, top + verticalInset,
            right - horizontalInset, bottom - verticalInset,
            UiThemeService.Color("Surface"), radius)
        return Win32.CDRF_DODEFAULT
    }
}
