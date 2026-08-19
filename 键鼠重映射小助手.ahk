/*
================================================================================
    键鼠重映射小助手
    可视化维护 AutoHotkey v2 重映射规则，支持按键录制、代码块编辑与顺序同步。
================================================================================
*/

;@Ahk2Exe-SetName 键鼠重映射小助手
;@Ahk2Exe-SetDescription 键鼠重映射小助手可视化管理器
;@Ahk2Exe-SetVersion 1.0.2
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
#Include src\UI\UiScaleService.ahk
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
#Include src\UI\WindowWheelPropagationGuard.ahk
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
; @映射结果=依次最小化可见应用窗口；桌面无可见窗口时按原层叠顺序逐个确认还原，并恢复置顶状态
; 写清楚规则在哪里有效，例如“全局”或某个程序。
; @生效范围=全局

; 下面是一份完整的 AHK v2 脚本；小助手会单独启动和停止它。
; @script-code-begin
;  #Warn All
;  ;
;  ; 此脚本完全接管 Win+D，不把原组合键传给 Windows。桌面仍有可见应用窗口时，
;  ; 按当前 Z 序记录窗口并从底层到顶层逐个最小化；桌面没有可见应用窗口时，
;  ; 从快照底层开始逐个还原。每一步必须确认目标状态后才会继续处理下一个窗口。
;  ;
;  ; Snapshot 跨多次 Win+D 保存仍由本规则管理的窗口。若最小化后出现新窗口，
;  ; 下一次 Win+D 会把新窗口并入快照，避免遗失此前已经最小化的窗口。
;  ; Phase 和 WorkRecords 描述当前异步流程；索引与请求时间只在该流程内有效。
;  global Snapshot := []
;  global Phase := "idle"
;  global WorkRecords := []
;  global WorkIndex := 0
;  global LastRequestAt := 0
;  global ItemStartedAt := 0
;  global OrderStartedAt := 0
;  ;
;  OnExit(Cleanup)
;  ;
;  ; $ 防止脚本产生的合成输入递归触发；没有使用 ~，所以 Windows 原生 Win+D
;  ; 不会同时执行。KeyWait 等待物理 D 松开，使一次长按只产生一次操作。
;  ; 窗口处理由一次性定时器推进，因此等待松键不会阻塞状态机。
;  $#d::HandleWinD()
;  ;
;  HandleWinD(*) {
;      global Phase
;      global Snapshot
;  ;
;      ; 上一批窗口尚未处理完时忽略新的切换请求，避免两个流程同时修改快照、
;      ; 层叠顺序或同一个窗口。仍等待本次 D 松开，以屏蔽长按重复。
;      if Phase != "idle" {
;          KeyWait("d")
;          return
;      }
;  ;
;      visibleRecords := GetVisibleApplicationWindows()
;  ;
;      if visibleRecords.Length > 0 {
;          ; 只要桌面仍存在可见应用窗口，本次操作就是最小化。当前窗口优先并入
;          ; 快照；此前已被本规则最小化且仍有效的窗口继续保留，供以后统一还原。
;          Snapshot := MergeSnapshots(visibleRecords, Snapshot)
;          BeginMinimize(visibleRecords)
;      } else if Snapshot.Length > 0 {
;          BeginRestore()
;      }
;  ;
;      KeyWait("d")
;  }
;  ;
;  BeginMinimize(records) {
;      global Phase
;      global WorkRecords
;      global WorkIndex
;      global LastRequestAt
;      global ItemStartedAt
;  ;
;      WorkRecords := records
;      ; WinGetList 返回从顶层到底层的顺序。最小化从数组末尾开始，可减少处理
;      ; 过程中前台窗口连续切换造成的视觉干扰。
;      WorkIndex := WorkRecords.Length
;      LastRequestAt := 0
;      ItemStartedAt := 0
;      Phase := "minimizing"
;      AdvanceWork()
;  }
;  ;
;  BeginRestore() {
;      global Snapshot
;      global Phase
;      global WorkRecords
;      global WorkIndex
;      global LastRequestAt
;      global ItemStartedAt
;  ;
;      WorkRecords := GetValidRecords(Snapshot)
;      if WorkRecords.Length = 0 {
;          Snapshot := []
;          FinishWork()
;          return
;      }
;  ;
;      ; 从快照最底层向顶层逐个还原。AdvanceRestore 只有确认当前窗口已可见且
;      ; 不再最小化后才递减索引，因此不会越过尚未完成还原的前一个窗口。
;      WorkIndex := WorkRecords.Length
;      LastRequestAt := 0
;      ItemStartedAt := 0
;      Phase := "restoring"
;      AdvanceWork()
;  }
;  ;
;  AdvanceWork(*) {
;      global Phase
;  ;
;      if Phase = "minimizing"
;          AdvanceMinimize()
;      else if Phase = "restoring"
;          AdvanceRestore()
;      else if Phase = "ordering"
;          AdvanceOrderRestoration()
;  }
;  ;
;  AdvanceMinimize() {
;      global WorkRecords
;      global WorkIndex
;      global LastRequestAt
;      global ItemStartedAt
;  ;
;      static ITEM_TIMEOUT_MS := 5000
;  ;
;      while WorkIndex >= 1 {
;          record := WorkRecords[WorkIndex]
;  ;
;          ; 已关闭或身份不再匹配的窗口不能继续操作。HWND 可能被 Windows
;          ; 复用，因此不能仅凭数值句柄认定它仍是原窗口。
;          if !IsRecordedWindow(record) {
;              MoveToNextRecord()
;              continue
;          }
;  ;
;          if IsWindowMinimizedOrHidden(record["hwnd"]) {
;              MoveToNextRecord()
;              continue
;          }
;  ;
;          if ItemStartedAt = 0
;              ItemStartedAt := A_TickCount
;  ;
;          ; 某些挂起或拒绝状态变更的窗口可能永远不响应。达到上限后终止本批
;          ; 流程并保留快照，避免留下永久运行的定时器；不会越过失败窗口继续
;          ; 最小化后续窗口。
;          if A_TickCount - ItemStartedAt >= ITEM_TIMEOUT_MS {
;              FinishWork()
;              return
;          }
;  ;
;          if LastRequestAt = 0 || A_TickCount - LastRequestAt >= 250 {
;              RequestMinimize(record)
;              LastRequestAt := A_TickCount
;          }
;  ;
;          SetTimer(AdvanceWork, -50)
;          return
;      }
;  ;
;      FinishWork()
;  }
;  ;
;  AdvanceRestore() {
;      global WorkRecords
;      global WorkIndex
;      global LastRequestAt
;      global ItemStartedAt
;      global Phase
;      global OrderStartedAt
;  ;
;      static ITEM_TIMEOUT_MS := 5000
;  ;
;      while WorkIndex >= 1 {
;          record := WorkRecords[WorkIndex]
;  ;
;          if !IsRecordedWindow(record) {
;              MoveToNextRecord()
;              continue
;          }
;  ;
;          if IsWindowRestored(record["hwnd"]) {
;              MoveToNextRecord()
;              continue
;          }
;  ;
;          if ItemStartedAt = 0
;              ItemStartedAt := A_TickCount
;  ;
;          ; 若当前窗口无法还原，则停止本批流程且不处理更高层窗口，从而严格
;          ; 保持“前一个确认还原后才还原下一个”的时序。快照仍会保留。
;          if A_TickCount - ItemStartedAt >= ITEM_TIMEOUT_MS {
;              FinishWork()
;              return
;          }
;  ;
;          if LastRequestAt = 0 || A_TickCount - LastRequestAt >= 250 {
;              RequestRestore(record)
;              LastRequestAt := A_TickCount
;          }
;  ;
;          SetTimer(AdvanceWork, -50)
;          return
;      }
;  ;
;      Phase := "ordering"
;      OrderStartedAt := A_TickCount
;      SetTimer(AdvanceWork, -25)
;  }
;  ;
;  MoveToNextRecord() {
;      global WorkIndex
;      global LastRequestAt
;      global ItemStartedAt
;  ;
;      WorkIndex -= 1
;      LastRequestAt := 0
;      ItemStartedAt := 0
;  }
;  ;
;  AdvanceOrderRestoration() {
;      global Snapshot
;      global Phase
;      global WorkRecords
;      global WorkIndex
;      global LastRequestAt
;      global ItemStartedAt
;      global OrderStartedAt
;  ;
;      static ORDER_TIMEOUT_MS := 5000
;  ;
;      validRecords := GetValidRecords(Snapshot)
;      if validRecords.Length = 0 {
;          Snapshot := []
;          FinishWork()
;          return
;      }
;  ;
;      ; 层叠恢复期间若窗口再次最小化或隐藏，则重新进入逐个还原阶段。
;      ; 这可处理应用在收到恢复请求后又自行改变显示状态的情况。
;      if !AreAllRecordsRestored(validRecords) {
;          WorkRecords := validRecords
;          WorkIndex := WorkRecords.Length
;          LastRequestAt := 0
;          ItemStartedAt := 0
;          Phase := "restoring"
;          SetTimer(AdvanceWork, -25)
;          return
;      }
;  ;
;      ApplyRecordedZOrder(validRecords)
;  ;
;      ; SetWindowPos 使用异步标志，返回成功仅代表请求已提交。实际 Z 序和每个
;      ; 窗口的置顶属性都匹配快照后，才清除快照并结束本次还原。
;      if IsRecordedOrderApplied(validRecords) {
;          Snapshot := []
;          FinishWork()
;          return
;      }
;  ;
;      ; 外部程序可能持续抢占 Z 序。为避免形成永久定时器，超过上限后停止
;      ; 重试；所有窗口此时均已还原，仅层叠顺序可能受到外部程序竞争影响。
;      if A_TickCount - OrderStartedAt >= ORDER_TIMEOUT_MS {
;          Snapshot := []
;          FinishWork()
;          return
;      }
;  ;
;      SetTimer(AdvanceWork, -100)
;  }
;  ;
;  FinishWork() {
;      global Phase
;      global WorkRecords
;      global WorkIndex
;      global LastRequestAt
;      global ItemStartedAt
;      global OrderStartedAt
;  ;
;      SetTimer(AdvanceWork, 0)
;      Phase := "idle"
;      WorkRecords := []
;      WorkIndex := 0
;      LastRequestAt := 0
;      ItemStartedAt := 0
;      OrderStartedAt := 0
;  }
;  ;
;  RequestMinimize(record) {
;      if !IsRecordedWindow(record)
;          return
;  ;
;      ; SW_MINIMIZE=6。使用异步版本避免目标窗口线程无响应时阻塞热键线程。
;      try DllCall(
;          "user32\ShowWindowAsync",
;          "Ptr", record["hwnd"],
;          "Int", 6,
;          "Int"
;      )
;  }
;  ;
;  RequestRestore(record) {
;      if !IsRecordedWindow(record)
;          return
;  ;
;      ; SW_RESTORE=9 会恢复窗口原来的正常或最大化状态，而不是强制改成普通大小。
;      try DllCall(
;          "user32\ShowWindowAsync",
;          "Ptr", record["hwnd"],
;          "Int", 9,
;          "Int"
;      )
;  }
;  ;
;  IsWindowMinimizedOrHidden(hwnd) {
;      return !DllCall("user32\IsWindowVisible", "Ptr", hwnd, "Int")
;          || DllCall("user32\IsIconic", "Ptr", hwnd, "Int")
;  }
;  ;
;  IsWindowRestored(hwnd) {
;      return DllCall("user32\IsWindowVisible", "Ptr", hwnd, "Int")
;          && !DllCall("user32\IsIconic", "Ptr", hwnd, "Int")
;  }
;  ;
;  AreAllRecordsRestored(records) {
;      for record in records {
;          if IsRecordedWindow(record) && !IsWindowRestored(record["hwnd"])
;              return false
;      }
;  ;
;      return true
;  }
;  ;
;  MergeSnapshots(visibleRecords, previousRecords) {
;      merged := []
;      seen := Map()
;  ;
;      ; 当前可见窗口的顺序和置顶属性是最新状态，因此优先采用；旧快照中仍
;      ; 有效且本次不可见的窗口随后补入，防止已最小化窗口失去还原记录。
;      for record in visibleRecords {
;          hwnd := record["hwnd"]
;          if !seen.Has(hwnd) {
;              merged.Push(record)
;              seen[hwnd] := true
;          }
;      }
;  ;
;      for record in previousRecords {
;          if !IsRecordedWindow(record)
;              continue
;  ;
;          hwnd := record["hwnd"]
;          if !seen.Has(hwnd) {
;              merged.Push(record)
;              seen[hwnd] := true
;          }
;      }
;  ;
;      return CanonicalizeRecords(merged)
;  }
;  ;
;  CanonicalizeRecords(records) {
;      topmostRecords := []
;      normalRecords := []
;  ;
;      ; Windows 要求所有置顶窗口整体位于普通窗口之前。跨多次操作合并快照后，
;      ; 按这一系统约束重新分组，同时保持各组内部原有的从上到下顺序。
;      for record in records {
;          if record["topmost"]
;              topmostRecords.Push(record)
;          else
;              normalRecords.Push(record)
;      }
;  ;
;      result := []
;      for record in topmostRecords
;          result.Push(record)
;      for record in normalRecords
;          result.Push(record)
;  ;
;      return result
;  }
;  ;
;  GetValidRecords(records) {
;      validRecords := []
;  ;
;      for record in records {
;          if IsRecordedWindow(record)
;              validRecords.Push(record)
;      }
;  ;
;      return validRecords
;  }
;  ;
;  ApplyRecordedZOrder(records) {
;      static HWND_NOTOPMOST := -2
;      static HWND_TOPMOST := -1
;      static ORDER_FLAGS := 0x4213
;  ;
;      normalRecords := []
;      topmostRecords := []
;  ;
;      for record in records {
;          if record["topmost"]
;              topmostRecords.Push(record)
;          else
;              normalRecords.Push(record)
;      }
;  ;
;      ; 每组从底向顶插入。ORDER_FLAGS 包含不移动、不缩放、不激活、
;      ; 不改变所有者层级及异步定位，恢复顺序时不会主动抢走输入焦点。
;      RestoreZOrderGroup(normalRecords, HWND_NOTOPMOST, ORDER_FLAGS)
;      RestoreZOrderGroup(topmostRecords, HWND_TOPMOST, ORDER_FLAGS)
;  }
;  ;
;  RestoreZOrderGroup(records, insertAfter, flags) {
;      Loop records.Length {
;          index := records.Length - A_Index + 1
;          record := records[index]
;  ;
;          if !IsRecordedWindow(record)
;              continue
;  ;
;          try DllCall(
;              "user32\SetWindowPos",
;              "Ptr", record["hwnd"],
;              "Ptr", insertAfter,
;              "Int", 0,
;              "Int", 0,
;              "Int", 0,
;              "Int", 0,
;              "UInt", flags,
;              "Int"
;          )
;      }
;  }
;  ;
;  IsRecordedOrderApplied(records) {
;      positions := Map()
;      position := 0
;  ;
;      for hwnd in WinGetList() {
;          position += 1
;          positions[hwnd] := position
;      }
;  ;
;      previousPosition := 0
;      for record in records {
;          if !IsRecordedWindow(record)
;              continue
;  ;
;          hwnd := record["hwnd"]
;          if !positions.Has(hwnd) || !IsWindowRestored(hwnd)
;              return false
;  ;
;          try currentTopmost := (WinGetExStyle("ahk_id " hwnd) & 0x00000008) != 0
;          catch
;              return false
;  ;
;          if currentTopmost != record["topmost"]
;              return false
;  ;
;          currentPosition := positions[hwnd]
;          if currentPosition <= previousPosition
;              return false
;  ;
;          previousPosition := currentPosition
;      }
;  ;
;      return true
;  }
;  ;
;  IsRecordedWindow(record) {
;      if !record.Has("hwnd")
;          || !record.Has("pid")
;          || !record.Has("tid")
;          || !record.Has("class")
;          return false
;  ;
;      hwnd := record["hwnd"]
;      if !DllCall("user32\IsWindow", "Ptr", hwnd, "Int")
;          return false
;  ;
;      ; HWND 可能被系统复用。进程、窗口线程和窗口类必须同时匹配，才把当前
;      ; 对象视为快照中的原窗口，避免误操作后来获得相同句柄的其他窗口。
;      pid := 0
;      tid := DllCall(
;          "user32\GetWindowThreadProcessId",
;          "Ptr", hwnd,
;          "UInt*", &pid,
;          "UInt"
;      )
;  ;
;      if pid != record["pid"] || tid != record["tid"]
;          return false
;  ;
;      try return WinGetClass("ahk_id " hwnd) = record["class"]
;      catch
;          return false
;  }
;  ;
;  GetVisibleApplicationWindows() {
;      windows := []
;  ;
;      ; WinGetList 按当前 Z 序从上到下返回顶层窗口。这里只收集可见、非最小化、
;      ; 未被 DWM 隐藏且可作为应用任务窗口的对象，并排除桌面与任务栏外壳。
;      for hwnd in WinGetList() {
;          try {
;              className := WinGetClass("ahk_id " hwnd)
;              if className = "Shell_TrayWnd"
;                  || className = "Shell_SecondaryTrayWnd"
;                  || className = "Progman"
;                  || className = "WorkerW"
;                  continue
;  ;
;              if !DllCall("user32\IsWindowVisible", "Ptr", hwnd, "Int")
;                  || DllCall("user32\IsIconic", "Ptr", hwnd, "Int")
;                  continue
;  ;
;              cloaked := 0
;              try DllCall(
;                  "dwmapi\DwmGetWindowAttribute",
;                  "Ptr", hwnd,
;                  "UInt", 14,
;                  "UInt*", &cloaked,
;                  "UInt", 4,
;                  "Int"
;              )
;              if cloaked
;                  continue
;  ;
;              style := WinGetStyle("ahk_id " hwnd)
;              if style & 0x40000000
;                  continue
;  ;
;              exStyle := WinGetExStyle("ahk_id " hwnd)
;              ownerHwnd := DllCall(
;                  "user32\GetWindow",
;                  "Ptr", hwnd,
;                  "UInt", 4,
;                  "Ptr"
;              )
;  ;
;              isAppWindow := (exStyle & 0x00040000) != 0
;              isToolWindow := (exStyle & 0x00000080) != 0
;  ;
;              if isToolWindow && !isAppWindow
;                  continue
;              if ownerHwnd != 0 && !isAppWindow
;                  continue
;              if WinGetTitle("ahk_id " hwnd) = ""
;                  continue
;  ;
;              pid := 0
;              tid := DllCall(
;                  "user32\GetWindowThreadProcessId",
;                  "Ptr", hwnd,
;                  "UInt*", &pid,
;                  "UInt"
;              )
;  ;
;              windows.Push(Map(
;                  "hwnd", hwnd,
;                  "pid", pid,
;                  "tid", tid,
;                  "class", className,
;                  "topmost", (exStyle & 0x00000008) != 0
;              ))
;          }
;      }
;  ;
;      return windows
;  }
;  ;
;  Cleanup(*) {
;      global Snapshot
;      global WorkRecords
;  ;
;      ; 宿主停止脚本或进程退出时取消状态机定时器，并同步尽力还原仍在快照中
;      ; 的有效窗口。这样不会因规则被停止而永久留下由本规则最小化的窗口。
;      SetTimer(AdvanceWork, 0)
;  ;
;      records := Snapshot.Length > 0 ? Snapshot : WorkRecords
;      validRecords := GetValidRecords(records)
;  ;
;      Loop validRecords.Length {
;          index := validRecords.Length - A_Index + 1
;          record := validRecords[index]
;  ;
;          try DllCall(
;              "user32\ShowWindow",
;              "Ptr", record["hwnd"],
;              "Int", 9,
;              "Int"
;          )
;      }
;  ;
;      ; 退出清理使用同步 ShowWindow 后再尽力恢复原 Z 序与置顶分组，不启动
;      ; 新定时器，也不会覆盖宿主注册的其他退出处理函数。
;      ApplyRecordedZOrder(validRecords)
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

; === 重映射代码区域结束 ===

#InputLevel 0
