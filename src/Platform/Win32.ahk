; 项目共享的 Win32 常量。业务窗口只引用具名值，避免各模块重复散落魔法数字。

class Win32 {
    static WM_NULL := 0x0000
    static WM_MOVE := 0x0003
    static WM_SETTINGCHANGE := 0x001A
    static WM_POWERBROADCAST := 0x0218
    static WM_WTSSESSION_CHANGE := 0x02B1
    static PBT_APMSUSPEND := 0x0004
    static PBT_APMRESUMESUSPEND := 0x0007
    static PBT_APMRESUMEAUTOMATIC := 0x0012
    static WTS_SESSION_LOCK := 0x0007
    static WTS_SESSION_UNLOCK := 0x0008
    static WM_THEMECHANGED := 0x031A
    static WM_DRAWITEM := 0x002B
    static WM_NCDESTROY := 0x0082
    static WM_SETREDRAW := 0x000B
    static WM_ERASEBKGND := 0x0014
    static WM_GETFONT := 0x0031
    static WM_SETFOCUS := 0x0007
    static WM_KILLFOCUS := 0x0008
    static WM_CANCELMODE := 0x001F
    static WM_KEYDOWN := 0x0100
    static WM_INPUT_DEVICE_CHANGE := 0x00FE
    static WM_INPUT := 0x00FF
    static WM_COMMAND := 0x0111
    static CBN_DROPDOWN := 7
    static CBN_CLOSEUP := 8
    static CB_GETTOPINDEX := 0x015B
    static CB_SETTOPINDEX := 0x015C
    static WM_SYSCOMMAND := 0x0112
    static WM_SETCURSOR := 0x0020
    static WM_MOUSEMOVE := 0x0200
    static WM_LBUTTONDOWN := 0x0201
    static WM_LBUTTONUP := 0x0202
    static WM_LBUTTONDBLCLK := 0x0203
    static WM_RBUTTONDOWN := 0x0204
    static WM_CAPTURECHANGED := 0x0215
    static WM_ENTERSIZEMOVE := 0x0231
    static WM_EXITSIZEMOVE := 0x0232
    static WM_MOUSELEAVE := 0x02A3
    static WM_MOUSEWHEEL := 0x020A
    static WM_MOUSEHWHEEL := 0x020E
    static IDC_ARROW := 32512
    static IDC_IBEAM := 32513
    static HTCLIENT := 1
    static HTHSCROLL := 6
    static HTVSCROLL := 7
    static OBJID_HSCROLL := -6
    static OBJID_VSCROLL := -5
    static STATE_SYSTEM_INVISIBLE := 0x00008000
    static STATE_SYSTEM_OFFSCREEN := 0x00010000
    static EM_GETSEL := 0x00B0
    static EM_SETSEL := 0x00B1
    static EM_GETRECT := 0x00B2
    static EM_SETRECT := 0x00B3
    static EM_LINESCROLL := 0x00B6
    static EM_GETLINECOUNT := 0x00BA
    static EM_GETFIRSTVISIBLELINE := 0x00CE
    static EM_SETMARGINS := 0x00D3
    static EM_CHARFROMPOS := 0x00D7
    static NM_CUSTOMDRAW := -12
    static CDDS_PREPAINT := 0x00000001
    static CDDS_ITEMPREPAINT := 0x00010001
    static CDDS_ITEMPOSTPAINT := 0x00010002
    static CDDS_SUBITEM := 0x00020000
    static CDRF_DODEFAULT := 0x00000000
    static CDRF_SKIPDEFAULT := 0x00000004
    static CDRF_NOTIFYPOSTPAINT := 0x00000010
    static CDRF_NOTIFYITEMDRAW := 0x00000020
    static CDIS_SELECTED := 0x0001
    static CDIS_FOCUS := 0x0010
    static LVM_GETITEMW := 0x104B
    static LVM_SETITEMW := 0x104C
    static LVM_GETITEMRECT := 0x100E
    static LVM_SCROLL := 0x1014
    static LVM_REDRAWITEMS := 0x1015
    static LVM_GETCOLUMNWIDTH := 0x101D
    static LVM_GETITEMSTATE := 0x102C
    static LVM_GETTOPINDEX := 0x1027
    static LVM_GETSUBITEMRECT := 0x1038
    static LVM_SETCOLUMNORDERARRAY := 0x103A
    static LVM_GETCOLUMNORDERARRAY := 0x103B
    static LVIF_IMAGE := 0x00000002
    static LVIF_INDENT := 0x00000010
    static LVIR_BOUNDS := 0
    static LVIS_SELECTED := 0x00000002
    static GWLP_HWNDPARENT := -8
    static GWL_STYLE := -16
    static GWL_EXSTYLE := -20
    static WS_MINIMIZEBOX := 0x00020000
    static WS_EX_TOOLWINDOW := 0x80
    static WS_EX_APPWINDOW := 0x40000
    static SW_HIDE := 0
    static SW_SHOWMAXIMIZED := 3
    static SW_MINIMIZE := 6
    static SW_RESTORE := 9
    static SW_SHOWMINNOACTIVE := 7
    static SMTO_ABORTIFHUNG := 0x0002
    static SC_MINIMIZE := 0xF020
    static SC_MAXIMIZE := 0xF030
    static SC_RESTORE := 0xF120
    static DWMWA_CLOAK := 13
    static DWMWA_CLOAKED := 14
    static RDW_BUTTON_REFRESH := 0x0121
    static RDW_LAYOUT_REFRESH := 0x0185
    static RDW_CONTROL_REFRESH := 0x0105
}

; Present the first real window frame inside a DWM cloak. The caller can
; finish theming and owner-draw work before that fully rendered frame is
; revealed, while later shows continue through the normal native path.
class FirstVisibleWindowPresenter {
    static OptionsKeepWindowHidden(showOptions) {
        return RegExMatch(Trim(String(showOptions)),
            "i)(^|\s)Hide(?:\s|$)") != 0
    }

    static SetCloaked(hwnd, cloaked) {
        if !hwnd || !DllCall("user32\IsWindow", "Ptr", hwnd, "Int")
            return false
        cloakValue := cloaked ? 1 : 0
        try return DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hwnd,
            "Int", Win32.DWMWA_CLOAK, "Int*", cloakValue, "Int", 4,
            "Int") >= 0
        catch
            return false
    }

    static GetCloakState(hwnd) {
        if !hwnd || !DllCall("user32\IsWindow", "Ptr", hwnd, "Int")
            return 0
        cloakState := 0
        try {
            result := DllCall("dwmapi\DwmGetWindowAttribute", "Ptr", hwnd,
                "Int", Win32.DWMWA_CLOAKED, "UInt*", &cloakState,
                "Int", 4, "Int")
            return result >= 0 ? cloakState : 0
        } catch {
            return 0
        }
    }

    static FlushComposition() {
        try return DllCall("dwmapi\DwmFlush", "Int") >= 0
        catch
            return false
    }

    static EnsureWindowNotMinimized(hwnd) {
        if !hwnd || !DllCall("user32\IsWindow", "Ptr", hwnd, "Int")
            return false
        if DllCall("user32\IsIconic", "Ptr", hwnd, "Int") {
            ; AHK's Gui.Show() can honor the process startup show state. A
            ; direct .ahk launch may therefore create the real GUI minimized,
            ; even when the caller requested a normal first display. Normalize
            ; that state at the single presentation boundary instead of
            ; relying on each launch path to compensate independently.
            DllCall("user32\ShowWindow", "Ptr", hwnd,
                "Int", Win32.SW_RESTORE, "Int")
        }
        return !DllCall("user32\IsIconic", "Ptr", hwnd, "Int")
    }

    static Show(guiObj, showOptions, firstVisibleCompleted,
            prepareVisibleSurface, refreshAfterShow := "") {
        keepHidden := this.OptionsKeepWindowHidden(showOptions)
        if keepHidden || firstVisibleCompleted {
            guiObj.Show(showOptions)
            if !keepHidden
                this.EnsureWindowNotMinimized(guiObj.Hwnd)
            if !keepHidden && IsObject(refreshAfterShow)
                refreshAfterShow.Call()
            return {
                Visible: !keepHidden,
                FirstVisibleCompleted: !!firstVisibleCompleted,
                CloakApplied: false,
                Uncloaked: true
            }
        }

        previousCritical := A_IsCritical
        cloakApplied := false
        uncloaked := true
        surfacePrepared := false
        Critical("On")
        try {
            cloakApplied := this.SetCloaked(guiObj.Hwnd, true)
            guiObj.Show(showOptions)
            this.EnsureWindowNotMinimized(guiObj.Hwnd)
            surfacePrepared := !IsObject(prepareVisibleSurface)
                || !!prepareVisibleSurface.Call()
            this.FlushComposition()
        } finally {
            if cloakApplied {
                uncloaked := this.SetCloaked(guiObj.Hwnd, false)
                if !uncloaked {
                    this.FlushComposition()
                    uncloaked := this.SetCloaked(guiObj.Hwnd, false)
                }
            }
            this.EnsureWindowNotMinimized(guiObj.Hwnd)
            this.FlushComposition()
            Critical(previousCritical ? previousCritical : "Off")
        }
        return {
            Visible: true,
            FirstVisibleCompleted: surfacePrepared
                && (!cloakApplied || uncloaked),
            CloakApplied: cloakApplied,
            Uncloaked: !cloakApplied || uncloaked
        }
    }
}
