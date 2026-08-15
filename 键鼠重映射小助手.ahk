/*
================================================================================
    键鼠重映射小助手
    可视化维护 AutoHotkey v2 重映射规则，支持按键录制、代码块编辑与顺序同步。
================================================================================
*/

;@Ahk2Exe-SetName 键鼠重映射小助手
;@Ahk2Exe-SetDescription 键鼠重映射小助手可视化管理器
;@Ahk2Exe-SetVersion 1.0.1
;@Ahk2Exe-SetCopyright Copyright (c) 2026 键鼠重映射小助手 contributors
;@Ahk2Exe-SetMainIcon assets\app\key-mouse-remapper-assistant.ico

#Requires AutoHotkey v2.0 64-bit
#SingleInstance Off
#Warn All, StdOut

#Include src\Localization\EnglishStrings.ahk
#Include src\Localization\TraditionalHongKongStrings.ahk
#Include src\Localization\TraditionalTaiwanStrings.ahk
#Include src\Localization\JapaneseStrings.ahk
#Include src\Localization\VietnameseStrings.ahk
#Include src\Localization\KoreanStrings.ahk
#Include src\Localization\SpanishStrings.ahk
#Include src\Localization\FrenchStrings.ahk
#Include src\Localization\PortugueseBrazilStrings.ahk
#Include src\Localization\RussianStrings.ahk
#Include src\Localization\GermanStrings.ahk
#Include src\Localization\ItalianStrings.ahk
#Include src\Localization\LocalizationService.ahk
#Include src\UI\UiThemeService.ahk
#Include src\UI\AhkV2Lexer.ahk
#Include src\Core\AhkV2ScriptValidator.ahk
#Include src\Config\AppSettingsService.ahk
#Include src\Config\WindowLayoutService.ahk
#Include src\Core\BoundedFileReader.ahk
#Include src\Core\JsonCodec.ahk
#Include src\Config\RuleAppearanceService.ahk
#Include src\Core\AIService.ahk
#Include src\Core\Sha256.ahk
#Include src\Core\CrossProcessWriteLock.ahk
#Include src\Core\ApplicationVersionInfo.ahk
#Include src\Core\RuleSpec.ahk
#Include src\Core\ScriptRuleSpec.ahk
#Include src\Core\DeviceIdentityService.ahk
#Include src\Core\InputEvent.ahk
#Include src\Core\RuleCompiler.ahk
#Include src\Core\ScriptRuleCompiler.ahk
#Include src\Core\DirectRuntimeSupport.ahk
#Include src\Core\DirectHotkeyRuntime.ahk
#Include src\Core\ScriptRuleRuntime.ahk
#Include src\Core\CompositeRemappingRuntime.ahk
#Include src\Core\EventTraceService.ahk
#Include src\Core\RuleConditionEvaluator.ahk
#Include src\Platform\Win32.ahk
#Include src\Platform\SystemIntegrationService.ahk
#Include src\Input\RawInputObservationPolicy.ahk
#Include src\Input\RawInputService.ahk
#Include src\Core\RulePackageService.ahk
#Include src\Core\MappingCodeRepository.ahk
#Include src\Core\MappingHistoryService.ahk
#Include src\Core\ApplicationUpdateService.ahk
#Include src\Platform\PackagedLauncher.ahk
#Include src\Platform\WindowHierarchy.ahk
#Include src\UI\ThemeHelpers.ahk
#Include src\UI\AtomicControlLayout.ahk
#Include src\UI\ApplicationIcon.ahk
#Include src\UI\CleanupCollector.ahk
#Include src\UI\SvgRenderLibrary.ahk
#Include src\UI\RoundedButtonPainter.ahk
#Include src\UI\ControlAccessibilityService.ahk
#Include app\Windows\DarkTooltipWindow.ahk
#Include src\UI\MappingUiInteractions.ahk
#Include app\UI\DarkMessageBox.ahk
#Include src\UI\ListViewPseudoHeader.ahk
#Include src\Input\CaptureInputGuard.ahk
#Include src\Input\KeyCaptureSession.ahk
#Include app\UI\ListViewSelectionPresenter.ahk
#Include app\Windows\ListCellTooltipWindow.ahk
#Include app\Windows\MappingContextPopupWindow.ahk
#Include app\Windows\EventViewerWindow.ahk
#Include app\Windows\SupportInfoWindow.ahk
#Include app\Windows\HelpWindow.ahk
#Include app\Windows\DonationWindow.ahk
#Include app\Windows\AboutWindow.ahk
#Include app\Windows\RulePackageImportWindow.ahk
#Include app\Windows\SettingsWindow.ahk
#Include app\Windows\MappingBlockEditor.ahk
#Include app\Windows\MappingWindow.ahk
#Include app\KeyMouseRemapperAssistantApp.ahk

if HasCommandLineFlag("--syntax-check")
    ExitApp()

; 编译产物只负责启动发行包内的固定版本解释器与可编辑源码。这样 GUI 对
; @mapping 代码块的保存、排序和任意 AHK 规则编辑在发行版中仍然完整可用。
if A_IsCompiled
    ExitApp(LaunchPackagedSource() ? 0 : 1)

if HasCommandLineFlag("--startup-validation")
    ExitApp()

if !A_IsAdmin {
    startupRunAsAdministrator := true
    try {
        startupSettingsService := AppSettingsService(A_AppData
            "\KeyMouseRemapperAssistant\settings.ini")
        startupRunAsAdministrator := startupSettingsService.Load()
            .RunAsAdministrator
    }
    if startupRunAsAdministrator {
        elevationCommand := BuildApplicationElevationCommand(
            DllCall("kernel32\GetCurrentProcessId", "UInt"), false,
            A_AhkPath, A_ScriptFullPath, A_Args)
        try {
            Run("*RunAs " elevationCommand, A_ScriptDir)
            ExitApp()
        }
    }
}

global ApplicationMutexHandle := 0
global LaunchShowMain := false
startupHandoffPid := GetReloadHandoffPid()
if startupHandoffPid
    try ProcessWaitClose(startupHandoffPid, 60)
startupMutexExists := false
ApplicationMutexHandle := AcquireApplicationMutex(&startupMutexExists)
if !ApplicationMutexHandle {
    MsgBox Tr("无法建立单实例运行锁，小助手将退出。"),
        Tr("启动失败"), "Iconx"
    ExitApp(1)
}
OnExit(ReleaseApplicationMutexOnExit)
if startupMutexExists {
    existingWindow := FindRunningApplicationWindow(10000)
    if existingWindow {
        existingProcessId := GetWindowProcessId(existingWindow)
        requestRevision := ReadApplicationSourceRevision()
        ; 直接执行可编辑源码必须由本次已重新解析源码的进程接管。否则旧进程
        ; 可能只被唤醒，继续使用内存中的旧类定义；发行包入口仍保持普通唤醒。
        if (!HasCommandLineFlag("--packaged") && !startupHandoffPid)
                || HasCommandLineFlag("--elevation-handoff")
            requestRevision := BuildForcedApplicationTakeoverRevision(
                requestRevision)
        handoffResult := ShowExistingApplicationWindow(existingWindow,
            requestRevision)
        if handoffResult != 2
            ExitApp()
        if !WaitForApplicationProcessExit(existingProcessId, 15000)
            ExitApp(1)
        LaunchShowMain := true
    } else {
        legacyScriptWindow := FindLegacyApplicationScriptWindow(
            A_ScriptFullPath)
        if !legacyScriptWindow
            ExitApp()
        legacyProcessId := GetWindowProcessId(legacyScriptWindow)
        if !CloseLegacyApplicationInstance(legacyScriptWindow) {
            ExitApp()
        }
    }
}

; 源码模式与便携运行时都由 AutoHotkey64.exe 承载。必须在创建首个 GUI 前
; 声明独立身份，否则 Windows 会把任务栏按钮归入其它 AHK 脚本并继承其图标。
ConfigureApplicationShellIdentity()

; GUI 通过 Raw Input 记录实体设备事件；重映射由本进程直接注册 AHK 热键。
EnableDarkProcessMode()
global App := KeyMouseRemapperAssistantApp()
applicationStarted := App.Start()
applicationUpdateReadyPath := GetApplicationUpdateReadyPath()
if applicationUpdateReadyPath {
    if !applicationStarted
            || !WriteApplicationUpdateReadySignal(applicationUpdateReadyPath,
                ReadApplicationVersion())
        ExitApp(1)
}

ReleaseApplicationMutexOnExit(*) {
    global ApplicationMutexHandle
    ReleaseApplicationMutexHandle(ApplicationMutexHandle)
    ApplicationMutexHandle := 0
    return 0
}

; === 重映射代码区域开始 ===
; 此区域由 GUI 维护；代码块顺序就是 GUI 的默认显示顺序，请勿删除元数据行。

; @mapping-begin
; 给这条规则起一个容易辨认的名称；它会显示在主界面中。
; @名称=左/右Shift键：中/英文输入
; 选择规则的写法；请保留下方已有的类型名称。
; @类型=受托管独立脚本
; 写清楚按下什么键或鼠标按键会触发这条规则。
; @来源按键=单独按下并释放 LShift / RShift
; 写清楚触发后会执行什么按键、鼠标操作或命令。
; @映射结果=左 Shift 切换中文，右 Shift 切换英文，低延迟执行
; 写清楚规则在哪里有效，例如“全局”或某个程序。
; @生效范围=全局

; 下面是一份完整的 AHK v2 脚本；小助手会单独启动和停止它。
; @script-code-begin
;  InstallMouseHook()
;  ;
;  shiftTapState := Map(
;      "LShift", Map("blocked", false),
;      "RShift", Map("blocked", false)
;  )
;  ;
;  #HotIf true
;  ~*LShift::StartShiftTap("LShift")
;  ~*LShift Up::FinishShiftTap("LShift", true)
;  ~*RShift::StartShiftTap("RShift")
;  ~*RShift Up::FinishShiftTap("RShift", false)
;  #HotIf
;  ;
;  StartShiftTap(key, *) {
;      global shiftTapState
;      shiftTapState[key]["blocked"] := IsOtherInputActive(key)
;  }
;  ;
;  FinishShiftTap(key, chinese, *) {
;      global shiftTapState
;      state := shiftTapState[key]
;      canSwitch := !state["blocked"]
;          && A_PriorKey == key
;          && !IsOtherInputActive(key)
;      state["blocked"] := false
;  ;
;      if !canSwitch
;          return
;  ;
;      target := GetFocusedTarget()
;      Sleep(10)
;      SetInputMode(chinese, target)
;  }
;  ;
;  IsOtherInputActive(shiftKey) {
;      static inputs := [
;          "Ctrl", "Alt", "LWin", "RWin",
;          "LButton", "RButton", "MButton", "XButton1", "XButton2"
;      ]
;  ;
;      for key in inputs {
;          if GetKeyState(key, "P")
;              return true
;      }
;  ;
;      otherShift := shiftKey == "LShift" ? "RShift" : "LShift"
;      return GetKeyState(otherShift, "P")
;  }
;  ;
;  SetInputMode(chinese, target) {
;      Critical("On")
;      try {
;          if !target["hwnd"]
;              return false
;  ;
;          Loop 2 {
;              if EnsureChineseLayout(target, A_Index > 1)
;                  && ApplyImeMode(target, chinese)
;                  return true
;              if A_Index == 1
;                  Sleep(15)
;          }
;          return false
;      } finally {
;          Critical("Off")
;      }
;  }
;  ;
;  EnsureChineseLayout(target, refreshLayout) {
;      hwnd := target["hwnd"]
;      if !DllCall("IsWindow", "ptr", hwnd, "int")
;          return false
;  ;
;      currentHkl := DllCall(
;          "GetKeyboardLayout",
;          "uint", target["threadId"],
;          "ptr"
;      )
;      if IsChineseLayout(currentHkl)
;          return true
;  ;
;      hkl := GetChineseKeyboardLayout(refreshLayout)
;      if !hkl
;          return false
;  ;
;      if !SendTimedMessage(hwnd, 0x50, 1, hkl, &result, 100)
;          return false
;  ;
;      started := A_TickCount
;      loop {
;          if !DllCall("IsWindow", "ptr", hwnd, "int")
;              return false
;  ;
;          currentHkl := DllCall(
;              "GetKeyboardLayout",
;              "uint", target["threadId"],
;              "ptr"
;          )
;          if IsChineseLayout(currentHkl)
;              return true
;          if A_TickCount - started >= 75
;              return false
;          Sleep(5)
;      }
;  }
;  ;
;  ApplyImeMode(target, chinese) {
;      imeHwnd := DllCall(
;          "imm32\ImmGetDefaultIMEWnd",
;          "ptr", target["hwnd"],
;          "ptr"
;      )
;      if !imeHwnd && target["hwnd"] != target["topHwnd"]
;          imeHwnd := DllCall(
;              "imm32\ImmGetDefaultIMEWnd",
;              "ptr", target["topHwnd"],
;              "ptr"
;          )
;      if !imeHwnd
;          return false
;  ;
;      if chinese {
;          openSent := SetImeValue(imeHwnd, 0x6, 1)
;          modeSent := SetImeValue(imeHwnd, 0x2, 1025)
;      } else {
;          modeSent := SetImeValue(imeHwnd, 0x2, 0)
;          openSent := SetImeValue(imeHwnd, 0x6, 0)
;      }
;  ;
;      if !openSent && !modeSent
;          return false
;  ;
;      started := A_TickCount
;      matchedSince := 0
;      loop {
;          openRead := GetImeValue(imeHwnd, 0x5, &opened)
;          modeRead := GetImeValue(imeHwnd, 0x1, &conversionMode)
;          if ImeModeMatches(
;              chinese,
;              openRead,
;              opened,
;              modeRead,
;              conversionMode
;          ) {
;              if !matchedSince
;                  matchedSince := A_TickCount
;              if A_TickCount - matchedSince >= 15
;                  return true
;          } else {
;              matchedSince := 0
;          }
;  ;
;          if A_TickCount - started >= 75
;              return false
;          Sleep(5)
;      }
;  }
;  ;
;  ImeModeMatches(chinese, openRead, opened, modeRead, conversionMode) {
;      if !openRead && !modeRead
;          return false
;  ;
;      openMatches := !openRead
;          || (chinese ? opened != 0 : opened == 0)
;      modeMatches := !modeRead
;          || (chinese ? conversionMode & 1 : !(conversionMode & 1))
;      return openMatches && modeMatches
;  }
;  ;
;  SetImeValue(imeHwnd, command, value) {
;      return SendTimedMessage(
;          imeHwnd,
;          0x283,
;          command,
;          value,
;          &result,
;          100
;      )
;  }
;  ;
;  GetImeValue(imeHwnd, command, &value) {
;      return SendTimedMessage(
;          imeHwnd,
;          0x283,
;          command,
;          0,
;          &value,
;          100
;      )
;  }
;  ;
;  SendTimedMessage(hwnd, message, wParam, lParam, &result, timeout) {
;      result := 0
;      try {
;          return DllCall(
;              "SendMessageTimeoutW",
;              "ptr", hwnd,
;              "uint", message,
;              "ptr", wParam,
;              "ptr", lParam,
;              "uint", 0x2,
;              "uint", timeout,
;              "ptr*", &result,
;              "ptr"
;          ) != 0
;      } catch {
;          return false
;      }
;  }
;  ;
;  GetChineseKeyboardLayout(refresh := false) {
;      static cachedHkl := 0
;      if cachedHkl && !refresh
;          return cachedHkl
;  ;
;      cachedHkl := 0
;      fallback := 0
;      count := DllCall(
;          "GetKeyboardLayoutList",
;          "int", 0,
;          "ptr", 0
;      )
;      if count {
;          layouts := Buffer(count * A_PtrSize)
;          count := DllCall(
;              "GetKeyboardLayoutList",
;              "int", count,
;              "ptr", layouts
;          )
;          Loop count {
;              hkl := NumGet(
;                  layouts,
;                  (A_Index - 1) * A_PtrSize,
;                  "ptr"
;              )
;              langId := hkl & 0xFFFF
;              if langId == 0x0804
;                  return cachedHkl := hkl
;              if !fallback && IsChineseLayout(hkl)
;                  fallback := hkl
;          }
;      }
;  ;
;      if fallback
;          return cachedHkl := fallback
;  ;
;      try {
;          cachedHkl := DllCall(
;              "LoadKeyboardLayoutW",
;              "str", "00000804",
;              "uint", 0x101,
;              "ptr"
;          )
;      } catch {
;          cachedHkl := 0
;      }
;      return cachedHkl
;  }
;  ;
;  IsChineseLayout(hkl) {
;      return ((hkl & 0xFFFF) & 0x03FF) == 0x04
;  }
;  ;
;  GetFocusedTarget() {
;      info := Buffer(A_PtrSize == 8 ? 72 : 48, 0)
;      topHwnd := WinExist("A")
;      if !topHwnd
;          return Map("hwnd", 0, "topHwnd", 0, "threadId", 0)
;  ;
;      topThreadId := DllCall(
;          "GetWindowThreadProcessId",
;          "ptr", topHwnd,
;          "ptr", 0,
;          "uint"
;      )
;      hwnd := topHwnd
;      NumPut("uint", info.Size, info)
;  ;
;      if DllCall("GetGUIThreadInfo", "uint", topThreadId, "ptr", info) {
;          focusedHwnd := NumGet(
;              info,
;              A_PtrSize == 8 ? 16 : 12,
;              "ptr"
;          )
;          if focusedHwnd
;              hwnd := focusedHwnd
;      }
;  ;
;      threadId := DllCall(
;          "GetWindowThreadProcessId",
;          "ptr", hwnd,
;          "ptr", 0,
;          "uint"
;      )
;      return Map(
;          "hwnd", hwnd,
;          "topHwnd", topHwnd,
;          "threadId", threadId
;      )
;  }
; @script-code-end

; @mapping-end

; @mapping-begin
; 给这条规则起一个容易辨认的名称；它会显示在主界面中。
; @名称=F1 长按录屏
; 选择规则的写法；请保留下方已有的类型名称。
; @类型=规则块
; 写清楚按下什么键或鼠标按键会触发这条规则。
; @来源按键=F1 长按
; 写清楚触发后会执行什么按键、鼠标操作或命令。
; @映射结果=Ctrl+Shift+Alt+F12
; 写清楚规则在哪里有效，例如“全局”或某个程序。
; @生效范围=全局
; 下面是规则的详细设置，包括触发方式、生效条件、时间判定和执行动作。
; @spec-begin
; {
;   // 说明什么键盘或鼠标输入会触发这条规则。
;   "from": {
;     // 指定作为主要触发来源的单个按键。
;     "key": {
;       // 填写 AHK 能识别的按键名称。
;       "name": "F1"
;     },
;     // 决定长按产生自动重复时，是允许、忽略还是只响应重复。
;     "repeat": "ignore"
;   },
;   // 设为 true 后，来源按键原本的输入仍会传给系统。
;   "passthrough": true,
;   // 设置长按等需要计时判断的参数。
;   "timing": {
;     // 按住达到这个时长后才算长按，单位为毫秒。
;     "held_threshold_ms": 250
;   },
;   // 来源按键按住达到判定时间后，执行这些动作。
;   "to_if_held_down": [
;     {
;       // 选择这一项属于哪一种条件或执行动作。
;       "type": "send",
;       // 填写要比较的内容，或动作实际使用的参数。
;       "value": "^+!{F12}"
;     }
;   ]
; }
; @spec-end
; @generated-begin
; 请让开头的内容摘要与上面的详细设置保持一致。
; 小助手会直接读取并运行这些设置，不需要另写 AHK 脚本。
; @generated-end
; @mapping-end

; @mapping-begin
; 给这条规则起一个容易辨认的名称；它会显示在主界面中。
; @名称=Shift+滚轮 水平滚动
; 选择规则的写法；请保留下方已有的类型名称。
; @类型=受托管独立脚本
; 写清楚按下什么键或鼠标按键会触发这条规则。
; @来源按键=Shift + WheelUp / WheelDown
; 写清楚触发后会执行什么按键、鼠标操作或命令。
; @映射结果=WheelLeft / WheelRight
; 写清楚规则在哪里有效，例如“全局”或某个程序。
; @生效范围=全局

; 下面是一份完整的 AHK v2 脚本；小助手会单独启动和停止它。
; @script-code-begin
;  #Requires AutoHotkey v2.0
;  #SingleInstance Force
;  #NoTrayIcon
;  #Warn All
;  ;
;  ; 0.5秒内允许最多100次热键触发
;  A_MaxHotkeysPerInterval := 100
;  A_HotkeyInterval := 500
;  ;
;  +WheelUp::Send("{WheelLeft}")
;  +WheelDown::Send("{WheelRight}")
; @script-code-end

; @mapping-end

; @mapping-begin
; 给这条规则起一个容易辨认的名称；它会显示在主界面中。
; @名称=Win+D 最小化与恢复窗口
; 选择规则的写法；请保留下方已有的类型名称。
; @类型=受托管独立脚本
; 写清楚按下什么键或鼠标按键会触发这条规则。
; @来源按键=Win + D
; 写清楚触发后会执行什么按键、鼠标操作或命令。
; @映射结果=按当前可见窗口栈最小化 / 恢复
; 写清楚规则在哪里有效，例如“全局”或某个程序。
; @生效范围=全局

; 下面是一份完整的 AHK v2 脚本；小助手会单独启动和停止它。
; @script-code-begin
;  #Requires AutoHotkey v2.0
;  #SingleInstance Force
;  #NoTrayIcon
;  #Warn All
;  ;
;  ; ========================================================
;  ; 1. 防休眠失效机制 (上一题的经验)
;  ; ========================================================
;  if not A_IsAdmin {
;      try Run "*RunAs `"" A_ScriptFullPath "`""
;      ExitApp
;  }
;  InstallKeybdHook
;  OnMessage(0x218, OnPowerEvent) ; 监听电源消息
;  OnPowerEvent(wParam, lParam, msg, hwnd) {
;      if (wParam = 0x12 || wParam = 0x7) { ; 唤醒事件
;          Sleep 2000
;          Reload
;      }
;  }
;  ;
;  ; ========================================================
;  ; 2. 全局变量
;  ; ========================================================
;  ; 用于存储被脚本最小化的窗口列表
;  global MinimizedStack := []
;  ;
;  #d::
;  {
;      ; 防止开始菜单弹出
;      Send "{Blind}{vkE8}"
;  ;
;      ; 获取所有“应该被最小化”的当前可见窗口
;      currentVisibleWins := GetActiveWindowList()
;  ;
;      ; ============================================================
;      ; 核心逻辑变更：基于“当前屏幕是否有窗口”来决定动作
;      ; ============================================================
;  ;
;      if (currentVisibleWins.Length > 0)
;      {
;          ; --- 场景 A：屏幕上有窗口 ---> 执行最小化 ---
;  ;
;          ; 将当前发现的这些窗口加入堆栈
;          ; (使用 Push 而不是直接覆盖，是为了处理“分批最小化”的情况：
;          ;  比如先Win+D最小化了一批，又手动打开一个，再Win+D，希望恢复时能全部恢复)
;          for winObj in currentVisibleWins {
;              MinimizedStack.Push(winObj)
;              WinMinimize(winObj.id)
;          }
;      }
;      else
;      {
;          ; --- 场景 B：屏幕上无窗口 (干净的桌面) ---> 执行恢复 ---
;  ;
;          if (MinimizedStack.Length > 0) {
;              ; 倒序循环，恢复最近最小化的窗口
;              Loop MinimizedStack.Length {
;                  index := MinimizedStack.Length - A_Index + 1
;                  savedWin := MinimizedStack[index]
;  ;
;                  if WinExist(savedWin.id) {
;                      ; 只有当窗口确实处于最小化状态时才恢复，防止重复操作
;                      if (WinGetMinMax(savedWin.id) == -1) {
;                          WinRestore(savedWin.id)
;                      }
;                  }
;              }
;              ; 清空记录
;              global MinimizedStack := []
;          }
;      }
;  }
;  ;
;  ; ========================================================
;  ; 辅助函数：获取当前屏幕上所有“有效的”、“非最小化”的窗口
;  ; ========================================================
;  GetActiveWindowList() {
;      validWindows := []
;      idList := WinGetList()
;  ;
;      for this_id in idList {
;          ; 1. 过滤桌面和任务栏 (保留你的原始逻辑)
;          this_class := WinGetClass(this_id)
;          if (this_class = "Shell_TrayWnd" || this_class = "Progman" || this_class = "WorkerW")
;              continue
;  ;
;          ; 2. 过滤完全不可见窗口
;          if !(WinGetStyle(this_id) & 0x10000000)
;              continue
;  ;
;          ; 3. 【关键】过滤已经是最小化状态的窗口
;          ; 我们只关心现在“显示着”的窗口
;          if (WinGetMinMax(this_id) == -1)
;              continue
;  ;
;          ; 4. 严格的任务栏存在性检测 (保留你的原始逻辑)
;          exStyle := WinGetExStyle(this_id)
;          ownerID := DllCall("GetWindow", "Ptr", this_id, "UInt", 4, "Ptr")
;          isAppWindow := (exStyle & 0x00040000)
;          isToolWindow := (exStyle & 0x00000080)
;  ;
;          if (isToolWindow && !isAppWindow)
;              continue
;  ;
;          if (ownerID != 0 && !isAppWindow)
;              continue
;  ;
;          if (WinGetTitle(this_id) = "")
;              continue
;  ;
;          ; 通过所有检查，加入列表
;          validWindows.Push({id: this_id})
;      }
;      return validWindows
;  }
; @script-code-end

; @mapping-end

; @mapping-begin
; @名称=NumLock 映射为 Delete
; @类型=规则块
; @来源按键=NumLock
; @映射结果=Delete
; @生效范围=全局
; @spec-begin
; {
;   "from": {
;     "key": {
;       "name": "NumLock"
;     },
;     "repeat": "ignore"
;   },
;   "to": [
;     {
;       "type": "send",
;       "value": "{Delete}"
;     }
;   ]
; }
; @spec-end
; @generated-begin
; 此规则由托管运行时注册；此区域不包含可手工编辑的 AHK 代码。
; @generated-end
; @mapping-end

; @mapping-begin
; 给这条规则起一个容易辨认的名称；它会显示在主界面中。
; @名称=ScrollLock 锁屏
; 选择规则的写法；请保留下方已有的类型名称。
; @类型=规则块
; 写清楚按下什么键或鼠标按键会触发这条规则。
; @来源按键=ScrollLock
; 写清楚触发后会执行什么按键、鼠标操作或命令。
; @映射结果=锁屏
; 写清楚规则在哪里有效，例如“全局”或某个程序。
; @生效范围=全局
; 下面是规则的详细设置，包括触发方式、生效条件、时间判定和执行动作。
; @spec-begin
; {
;   // 说明什么键盘或鼠标输入会触发这条规则。
;   "from": {
;     // 指定作为主要触发来源的单个按键。
;     "key": {
;       // 填写 AHK 能识别的按键名称。
;       "name": "ScrollLock"
;     },
;     // 决定长按产生自动重复时，是允许、忽略还是只响应重复。
;     "repeat": "ignore"
;   },
;   // 来源按键触发时，立即执行这些动作。
;   "to": [
;     {
;       // 选择这一项属于哪一种条件或执行动作。
;       "type": "lock_workstation"
;     }
;   ]
; }
; @spec-end
; @generated-begin
; 请让开头的内容摘要与上面的详细设置保持一致。
; 小助手会直接读取并运行这些设置，不需要另写 AHK 脚本。
; @generated-end
; @mapping-end

; @mapping-begin
; 给这条规则起一个容易辨认的名称；它会显示在主界面中。
; @名称=Pause 控制媒体播放与暂停
; 选择规则的写法；请保留下方已有的类型名称。
; @类型=规则块
; 写清楚按下什么键或鼠标按键会触发这条规则。
; @来源按键=Pause
; 写清楚触发后会执行什么按键、鼠标操作或命令。
; @映射结果=Media_Play_Pause
; 写清楚规则在哪里有效，例如“全局”或某个程序。
; @生效范围=全局
; 下面是规则的详细设置，包括触发方式、生效条件、时间判定和执行动作。
; @spec-begin
; {
;   // 说明什么键盘或鼠标输入会触发这条规则。
;   "from": {
;     // 指定作为主要触发来源的单个按键。
;     "key": {
;       // 填写 AHK 能识别的按键名称。
;       "name": "Pause"
;     },
;     // 决定长按产生自动重复时，是允许、忽略还是只响应重复。
;     "repeat": "ignore"
;   },
;   // 来源按键触发时，立即执行这些动作。
;   "to": [
;     {
;       // 选择这一项属于哪一种条件或执行动作。
;       "type": "send",
;       // 填写要比较的内容，或动作实际使用的参数。
;       "value": "{Media_Play_Pause}"
;     }
;   ]
; }
; @spec-end
; @generated-begin
; 请让开头的内容摘要与上面的详细设置保持一致。
; 小助手会直接读取并运行这些设置，不需要另写 AHK 脚本。
; @generated-end
; @mapping-end

; @mapping-begin
; 给这条规则起一个容易辨认的名称；它会显示在主界面中。
; @名称=PrintScreen 恢复最近使用的窗口（适用于桌面、任务栏等抢占焦点后快速返回）
; 选择规则的写法；请保留下方已有的类型名称。
; @类型=规则块
; 写清楚按下什么键或鼠标按键会触发这条规则。
; @来源按键=PrintScreen
; 写清楚触发后会执行什么按键、鼠标操作或命令。
; @映射结果=Alt + Tab
; 写清楚规则在哪里有效，例如“全局”或某个程序。
; @生效范围=全局
; 下面是规则的详细设置，包括触发方式、生效条件、时间判定和执行动作。
; @spec-begin
; {
;   // 说明什么键盘或鼠标输入会触发这条规则。
;   "from": {
;     // 选择按下（down）还是松开（up）时触发。
;     "event": "up",
;     // 指定作为主要触发来源的单个按键。
;     "key": {
;       // 填写 AHK 能识别的按键名称。
;       "name": "PrintScreen"
;     },
;     // 决定长按产生自动重复时，是允许、忽略还是只响应重复。
;     "repeat": "ignore"
;   },
;   // 来源按键触发时，立即执行这些动作。
;   "to": [
;     {
;       // 选择这一项属于哪一种条件或执行动作。
;       "type": "send",
;       // 填写要比较的内容，或动作实际使用的参数。
;       "value": "!{Tab}"
;     }
;   ]
; }
; @spec-end
; @generated-begin
; 请让开头的内容摘要与上面的详细设置保持一致。
; 小助手会直接读取并运行这些设置，不需要另写 AHK 脚本。
; @generated-end
; @mapping-end

; @mapping-begin
; 给这条规则起一个容易辨认的名称；它会显示在主界面中。
; @名称=Ctrl+空格 映射为 鼠标中键
; 选择规则的写法；请保留下方已有的类型名称。
; @类型=规则块
; 写清楚按下什么键或鼠标按键会触发这条规则。
; @来源按键=Ctrl + Space
; 写清楚触发后会执行什么按键、鼠标操作或命令。
; @映射结果=MButton
; 写清楚规则在哪里有效，例如“全局”或某个程序。
; @生效范围=全局
; 下面是规则的详细设置，包括触发方式、生效条件、时间判定和执行动作。
; @spec-begin
; {
;   // 说明什么键盘或鼠标输入会触发这条规则。
;   "from": {
;     // 指定作为主要触发来源的单个按键。
;     "key": {
;       // 填写 AHK 能识别的按键名称。
;       "name": "Space"
;     },
;     // 列出触发时必须按住的 Ctrl、Shift、Alt 或 Win 键。
;     "modifiers": [
;       "Ctrl"
;     ],
;     // 决定长按产生自动重复时，是允许、忽略还是只响应重复。
;     "repeat": "ignore"
;   },
;   // 来源按键触发时，立即执行这些动作。
;   "to": [
;     {
;       // 选择这一项属于哪一种条件或执行动作。
;       "type": "key_down",
;       // 填写要比较的内容，或动作实际使用的参数。
;       "value": "MButton"
;     }
;   ],
;   // 来源按键松开后，执行这些动作。
;   "to_after_key_up": [
;     {
;       // 选择这一项属于哪一种条件或执行动作。
;       "type": "key_up",
;       // 填写要比较的内容，或动作实际使用的参数。
;       "value": "MButton"
;     }
;   ]
; }
; @spec-end
; @generated-begin
; 请让开头的内容摘要与上面的详细设置保持一致。
; 小助手会直接读取并运行这些设置，不需要另写 AHK 脚本。
; @generated-end
; @mapping-end

; @mapping-begin
; 给这条规则起一个容易辨认的名称；它会显示在主界面中。
; @名称=浏览器主页键 映射为 退格键
; 选择规则的写法；请保留下方已有的类型名称。
; @类型=规则块
; 写清楚按下什么键或鼠标按键会触发这条规则。
; @来源按键=Browser_Home
; 写清楚触发后会执行什么按键、鼠标操作或命令。
; @映射结果=Backspace
; 写清楚规则在哪里有效，例如“全局”或某个程序。
; @生效范围=全局
; 下面是规则的详细设置，包括触发方式、生效条件、时间判定和执行动作。
; @spec-begin
; {
;   // 说明什么键盘或鼠标输入会触发这条规则。
;   "from": {
;     // 指定作为主要触发来源的单个按键。
;     "key": {
;       // 填写 AHK 能识别的按键名称。
;       "name": "Browser_Home"
;     },
;     // 决定长按产生自动重复时，是允许、忽略还是只响应重复。
;     "repeat": "ignore"
;   },
;   // 来源按键触发时，立即执行这些动作。
;   "to": [
;     {
;       // 选择这一项属于哪一种条件或执行动作。
;       "type": "send",
;       // 填写要比较的内容，或动作实际使用的参数。
;       "value": "{Backspace}"
;     }
;   ]
; }
; @spec-end
; @generated-begin
; 请让开头的内容摘要与上面的详细设置保持一致。
; 小助手会直接读取并运行这些设置，不需要另写 AHK 脚本。
; @generated-end
; @mapping-end

; @mapping-begin
; 给这条规则起一个容易辨认的名称；它会显示在主界面中。
; @名称=浏览器搜索键 映射为 Delete
; 选择规则的写法；请保留下方已有的类型名称。
; @类型=规则块
; 写清楚按下什么键或鼠标按键会触发这条规则。
; @来源按键=Browser_Search
; 写清楚触发后会执行什么按键、鼠标操作或命令。
; @映射结果=Delete
; 写清楚规则在哪里有效，例如“全局”或某个程序。
; @生效范围=全局
; 下面是规则的详细设置，包括触发方式、生效条件、时间判定和执行动作。
; @spec-begin
; {
;   // 说明什么键盘或鼠标输入会触发这条规则。
;   "from": {
;     // 指定作为主要触发来源的单个按键。
;     "key": {
;       // 填写 AHK 能识别的按键名称。
;       "name": "Browser_Search"
;     },
;     // 决定长按产生自动重复时，是允许、忽略还是只响应重复。
;     "repeat": "ignore"
;   },
;   // 来源按键触发时，立即执行这些动作。
;   "to": [
;     {
;       // 选择这一项属于哪一种条件或执行动作。
;       "type": "send",
;       // 填写要比较的内容，或动作实际使用的参数。
;       "value": "{Delete}"
;     }
;   ]
; }
; @spec-end
; @generated-begin
; 请让开头的内容摘要与上面的详细设置保持一致。
; 小助手会直接读取并运行这些设置，不需要另写 AHK 脚本。
; @generated-end
; @mapping-end

; @mapping-begin
; 给这条规则起一个容易辨认的名称；它会显示在主界面中。
; @名称=Copilot键 唤出豆包
; 选择规则的写法；请保留下方已有的类型名称。
; @类型=规则块
; 写清楚按下什么键或鼠标按键会触发这条规则。
; @来源按键=LWin + LShift + F23
; 写清楚触发后会执行什么按键、鼠标操作或命令。
; @映射结果=Ctrl + Shift + Space
; 写清楚规则在哪里有效，例如“全局”或某个程序。
; @生效范围=全局
; 下面是规则的详细设置，包括触发方式、生效条件、时间判定和执行动作。
; @spec-begin
; {
;   // 说明什么键盘或鼠标输入会触发这条规则。
;   "from": {
;     // 指定作为主要触发来源的单个按键。
;     "key": {
;       // 填写 AHK 能识别的按键名称。
;       "name": "F23"
;     },
;     // 列出触发时必须按住的 Ctrl、Shift、Alt 或 Win 键。
;     "modifiers": [
;       "LWin",
;       "LShift"
;     ],
;     // 决定长按产生自动重复时，是允许、忽略还是只响应重复。
;     "repeat": "ignore"
;   },
;   // 来源按键触发时，立即执行这些动作。
;   "to": [
;     {
;       // 选择这一项属于哪一种条件或执行动作。
;       "type": "send",
;       // 填写要比较的内容，或动作实际使用的参数。
;       "value": "^+{Space}"
;     }
;   ]
; }
; @spec-end
; @generated-begin
; 请让开头的内容摘要与上面的详细设置保持一致。
; 小助手会直接读取并运行这些设置，不需要另写 AHK 脚本。
; @generated-end
; @mapping-end

; @mapping-begin
; 给这条规则起一个容易辨认的名称；它会显示在主界面中。
; @名称=Alt+M 最小化当前窗口
; 选择规则的写法；请保留下方已有的类型名称。
; @类型=规则块
; 写清楚按下什么键或鼠标按键会触发这条规则。
; @来源按键=Alt + M
; 写清楚触发后会执行什么按键、鼠标操作或命令。
; @映射结果=最小化当前窗口
; 写清楚规则在哪里有效，例如“全局”或某个程序。
; @生效范围=全局
; 下面是规则的详细设置，包括触发方式、生效条件、时间判定和执行动作。
; @spec-begin
; {
;   // 说明什么键盘或鼠标输入会触发这条规则。
;   "from": {
;     // 指定作为主要触发来源的单个按键。
;     "key": {
;       // 填写 AHK 能识别的按键名称。
;       "name": "M"
;     },
;     // 列出触发时必须按住的 Ctrl、Shift、Alt 或 Win 键。
;     "modifiers": [
;       "Alt"
;     ],
;     // 决定长按产生自动重复时，是允许、忽略还是只响应重复。
;     "repeat": "ignore"
;   },
;   // 来源按键触发时，立即执行这些动作。
;   "to": [
;     {
;       // 选择这一项属于哪一种条件或执行动作。
;       "type": "window_minimize"
;     }
;   ]
; }
; @spec-end
; @generated-begin
; 请让开头的内容摘要与上面的详细设置保持一致。
; 小助手会直接读取并运行这些设置，不需要另写 AHK 脚本。
; @generated-end
; @mapping-end

; @mapping-begin
; 给这条规则起一个容易辨认的名称；它会显示在主界面中。
; @名称=Alt+W 关闭当前窗口
; 选择规则的写法；请保留下方已有的类型名称。
; @类型=规则块
; 写清楚按下什么键或鼠标按键会触发这条规则。
; @来源按键=Alt + W
; 写清楚触发后会执行什么按键、鼠标操作或命令。
; @映射结果=关闭当前窗口
; 写清楚规则在哪里有效，例如“全局”或某个程序。
; @生效范围=全局
; 下面是规则的详细设置，包括触发方式、生效条件、时间判定和执行动作。
; @spec-begin
; {
;   // 说明什么键盘或鼠标输入会触发这条规则。
;   "from": {
;     // 指定作为主要触发来源的单个按键。
;     "key": {
;       // 填写 AHK 能识别的按键名称。
;       "name": "W"
;     },
;     // 列出触发时必须按住的 Ctrl、Shift、Alt 或 Win 键。
;     "modifiers": [
;       "Alt"
;     ],
;     // 决定长按产生自动重复时，是允许、忽略还是只响应重复。
;     "repeat": "ignore"
;   },
;   // 来源按键触发时，立即执行这些动作。
;   "to": [
;     {
;       // 选择这一项属于哪一种条件或执行动作。
;       "type": "window_close"
;     }
;   ]
; }
; @spec-end
; @generated-begin
; 请让开头的内容摘要与上面的详细设置保持一致。
; 小助手会直接读取并运行这些设置，不需要另写 AHK 脚本。
; @generated-end
; @mapping-end

; @mapping-begin
; 给这条规则起一个容易辨认的名称；它会显示在主界面中。
; @名称=Office 禁用单按 Alt
; 选择规则的写法；请保留下方已有的类型名称。
; @类型=受托管独立脚本
; 写清楚按下什么键或鼠标按键会触发这条规则。
; @来源按键=左 Alt 或右 Alt
; 写清楚触发后会执行什么按键、鼠标操作或命令。
; @映射结果=静默吞掉单独 Alt，同时保留 Alt 组合键的原有功能
; 写清楚规则在哪里有效，例如“全局”或某个程序。
; @生效范围=Word、PowerPoint 和 Excel

; 下面是一份完整的 AHK v2 脚本；小助手会单独启动和停止它。
; @script-code-begin
;  OfficeWindowActive() {
;      return WinActive("ahk_exe WINWORD.EXE")
;          || WinActive("ahk_exe POWERPNT.EXE")
;          || WinActive("ahk_exe EXCEL.EXE")
;  }
;  #HotIf OfficeWindowActive()
;  ~*LAlt::SendEvent("{Blind}{vkE8}")
;  ~*RAlt::SendEvent("{Blind}{vkE8}")
;  #HotIf
; @script-code-end

; @mapping-end

; @mapping-begin
; 给这条规则起一个容易辨认的名称；它会显示在主界面中。
; @名称=Office 重做快捷键
; 选择规则的写法；请保留下方已有的类型名称。
; @类型=规则块
; 写清楚按下什么键或鼠标按键会触发这条规则。
; @来源按键=Ctrl + Shift + Z
; 写清楚触发后会执行什么按键、鼠标操作或命令。
; @映射结果=Ctrl + Y
; 写清楚规则在哪里有效，例如“全局”或某个程序。
; @生效范围=Word / Excel / PowerPoint
; 下面是规则的详细设置，包括触发方式、生效条件、时间判定和执行动作。
; @spec-begin
; {
;   // 列出这一层包含的生效条件。
;   "conditions": [
;     {
;       // 指定要检查的程序、窗口、输入法或会话信息。
;       "field": "process",
;       // 选择条件值如何比较，例如相等、包含或正则匹配。
;       "operator": "in",
;       // 选择这一项属于哪一种条件或执行动作。
;       "type": "application",
;       // 填写要比较的内容，或动作实际使用的参数。
;       "value": [
;         "WINWORD.EXE",
;         "EXCEL.EXE",
;         "POWERPNT.EXE"
;       ]
;     }
;   ],
;   // 说明什么键盘或鼠标输入会触发这条规则。
;   "from": {
;     // 指定作为主要触发来源的单个按键。
;     "key": {
;       // 填写 AHK 能识别的按键名称。
;       "name": "Z"
;     },
;     // 列出触发时必须按住的 Ctrl、Shift、Alt 或 Win 键。
;     "modifiers": [
;       "Ctrl",
;       "Shift"
;     ],
;     // 决定长按产生自动重复时，是允许、忽略还是只响应重复。
;     "repeat": "ignore"
;   },
;   // 来源按键触发时，立即执行这些动作。
;   "to": [
;     {
;       // 选择这一项属于哪一种条件或执行动作。
;       "type": "send",
;       // 填写要比较的内容，或动作实际使用的参数。
;       "value": "^y"
;     }
;   ]
; }
; @spec-end
; @generated-begin
; 请让开头的内容摘要与上面的详细设置保持一致。
; 小助手会直接读取并运行这些设置，不需要另写 AHK 脚本。
; @generated-end
; @mapping-end

; @mapping-begin
; 给这条规则起一个容易辨认的名称；它会显示在主界面中。
; @名称=Alt + Z 打开 Word 样式窗格
; 选择规则的写法；请保留下方已有的类型名称。
; @类型=规则块
; 写清楚按下什么键或鼠标按键会触发这条规则。
; @来源按键=Alt + Z
; 写清楚触发后会执行什么按键、鼠标操作或命令。
; @映射结果=样式窗格
; 写清楚规则在哪里有效，例如“全局”或某个程序。
; @生效范围=Word
; 下面是规则的详细设置，包括触发方式、生效条件、时间判定和执行动作。
; @spec-begin
; {
;   // 列出这一层包含的生效条件。
;   "conditions": [
;     {
;       // 指定要检查的程序、窗口、输入法或会话信息。
;       "field": "process",
;       // 选择这一项属于哪一种条件或执行动作。
;       "type": "application",
;       // 填写要比较的内容，或动作实际使用的参数。
;       "value": "WINWORD.EXE"
;     }
;   ],
;   // 说明什么键盘或鼠标输入会触发这条规则。
;   "from": {
;     // 指定作为主要触发来源的单个按键。
;     "key": {
;       // 填写 AHK 能识别的按键名称。
;       "name": "Z"
;     },
;     // 列出触发时必须按住的 Ctrl、Shift、Alt 或 Win 键。
;     "modifiers": [
;       "Alt"
;     ],
;     // 决定长按产生自动重复时，是允许、忽略还是只响应重复。
;     "repeat": "ignore"
;   },
;   // 来源按键触发时，立即执行这些动作。
;   "to": [
;     {
;       // 选择这一项属于哪一种条件或执行动作。
;       "type": "send",
;       // 填写要比较的内容，或动作实际使用的参数。
;       "value": "!^+s"
;     },
;     {
;       // 选择这一项属于哪一种条件或执行动作。
;       "type": "sleep",
;       // 填写要比较的内容，或动作实际使用的参数。
;       "value": "100"
;     },
;     {
;       // 选择这一项属于哪一种条件或执行动作。
;       "type": "send",
;       // 填写要比较的内容，或动作实际使用的参数。
;       "value": "{Esc}"
;     }
;   ]
; }
; @spec-end
; @generated-begin
; 请让开头的内容摘要与上面的详细设置保持一致。
; 小助手会直接读取并运行这些设置，不需要另写 AHK 脚本。
; @generated-end
; @mapping-end

; @mapping-begin
; 给这条规则起一个容易辨认的名称；它会显示在主界面中。
; @名称=修饰键长按时自动释放
; 选择规则的写法；请保留下方已有的类型名称。
; @类型=受托管独立脚本
; 写清楚按下什么键或鼠标按键会触发这条规则。
; @来源按键=LWin、RWin、LCtrl、RCtrl、LShift、RShift、LAlt、RAlt 长按 2000 毫秒
; 写清楚触发后会执行什么按键、鼠标操作或命令。
; @映射结果=长按超过阈值后发送对应修饰键的逻辑释放，使后续按键不再带有该修饰键，并保留组合中的其他按键
; 写清楚规则在哪里有效，例如“全局”或某个程序。
; @生效范围=全局

; 下面是一份完整的 AHK v2 脚本；小助手会单独启动和停止它。
; @script-code-begin
;  heldThresholdMs := 2000
;  monitoredKeys := ["LWin", "RWin", "LCtrl", "RCtrl", "LShift", "RShift", "LAlt", "RAlt"]
;  keyStates := Map()
;  timerCallbacks := Map()
;  ;
;  for key in monitoredKeys {
;      keyStates[key] := Map("down", false, "releasedByScript", false)
;      timerCallbacks[key] := HandleHeldKey.Bind(key)
;  }
;  ;
;  OnExit(Cleanup)
;  ;
;  #HotIf true
;  ~*$LWin::HandleKeyDown("LWin")
;  ~*$LWin Up::HandleKeyUp("LWin")
;  ~*$RWin::HandleKeyDown("RWin")
;  ~*$RWin Up::HandleKeyUp("RWin")
;  ~*$LCtrl::HandleKeyDown("LCtrl")
;  ~*$LCtrl Up::HandleKeyUp("LCtrl")
;  ~*$RCtrl::HandleKeyDown("RCtrl")
;  ~*$RCtrl Up::HandleKeyUp("RCtrl")
;  ~*$LShift::HandleKeyDown("LShift")
;  ~*$LShift Up::HandleKeyUp("LShift")
;  ~*$RShift::HandleKeyDown("RShift")
;  ~*$RShift Up::HandleKeyUp("RShift")
;  ~*$LAlt::HandleKeyDown("LAlt")
;  ~*$LAlt Up::HandleKeyUp("LAlt")
;  ~*$RAlt::HandleKeyDown("RAlt")
;  ~*$RAlt Up::HandleKeyUp("RAlt")
;  #HotIf
;  ;
;  HandleKeyDown(key, *) {
;      global keyStates, timerCallbacks, heldThresholdMs
;  ;
;      if !keyStates.Has(key)
;          return
;  ;
;      state := keyStates[key]
;      if state["down"]
;          return
;  ;
;      state["down"] := true
;      state["releasedByScript"] := false
;      SetTimer(timerCallbacks[key], -heldThresholdMs)
;  }
;  ;
;  HandleHeldKey(key, *) {
;      global keyStates, timerCallbacks
;  ;
;      if !keyStates.Has(key)
;          return
;  ;
;      state := keyStates[key]
;      if !state["down"] || state["releasedByScript"]
;          return
;  ;
;      if !GetKeyState(key, "P") {
;          state["down"] := false
;          return
;      }
;  ;
;      SendEvent("{Blind}{" . key . " up}")
;      state["releasedByScript"] := true
;      SetTimer(timerCallbacks[key], 0)
;  }
;  ;
;  HandleKeyUp(key, *) {
;      global keyStates, timerCallbacks
;  ;
;      if !keyStates.Has(key)
;          return
;  ;
;      SetTimer(timerCallbacks[key], 0)
;      state := keyStates[key]
;      state["down"] := false
;      state["releasedByScript"] := false
;  }
;  ;
;  Cleanup(*) {
;      global monitoredKeys, keyStates, timerCallbacks
;  ;
;      for key in monitoredKeys {
;          if timerCallbacks.Has(key)
;              SetTimer(timerCallbacks[key], 0)
;          if keyStates.Has(key) {
;              state := keyStates[key]
;              state["down"] := false
;              state["releasedByScript"] := false
;          }
;      }
;  }
; @script-code-end

; @mapping-end

; === 重映射代码区域结束 ===

#InputLevel 0
