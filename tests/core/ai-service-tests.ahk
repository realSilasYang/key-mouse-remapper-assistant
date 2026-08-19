#Requires AutoHotkey v2.0 64-bit
#SingleInstance Off
#Warn All, StdOut

#Include ..\..\src\Core\JsonCodec.ahk
#Include ..\..\src\Core\Sha256.ahk
#Include ..\..\src\Core\RuleSpec.ahk
#Include ..\..\src\Core\ScriptRuleSpec.ahk
#Include ..\..\src\Core\RuleCompiler.ahk
#Include ..\..\src\Core\ScriptRuleCompiler.ahk
#Include ..\..\src\Localization\EnglishStrings.ahk
#Include ..\..\src\Localization\TraditionalHongKongStrings.ahk
#Include ..\..\src\Localization\TraditionalTaiwanStrings.ahk
#Include ..\..\src\Localization\JapaneseStrings.ahk
#Include ..\..\src\Localization\VietnameseStrings.ahk
#Include ..\..\src\Localization\KoreanStrings.ahk
#Include ..\..\src\Localization\SpanishStrings.ahk
#Include ..\..\src\Localization\FrenchStrings.ahk
#Include ..\..\src\Localization\PortugueseBrazilStrings.ahk
#Include ..\..\src\Localization\RussianStrings.ahk
#Include ..\..\src\Localization\GermanStrings.ahk
#Include ..\..\src\Localization\ItalianStrings.ahk
#Include ..\..\src\Localization\LocalizationService.ahk
#Include ..\..\src\UI\UiThemeService.ahk
#Include ..\..\src\Core\BoundedFileReader.ahk
#Include ..\..\src\Core\CrossProcessWriteLock.ahk
#Include ..\..\src\Core\AIService.ahk
#Include ..\..\src\UI\UiScaleService.ahk
#Include ..\..\src\Config\AppSettingsService.ahk

OnError(ReportAiTestFailure)

ReportAiTestFailure(error, *) {
    try FileAppend("FAIL ai-service-tests: " error.Message "`n"
        . error.Stack "`n", "*")
    ExitApp(1)
    return true
}

AssertAi(condition, message) {
    if !condition
        throw Error(message)
}

AssertAiTargets(service, address, model, expected, message) {
    actual := service.ResolveTargets(address, model)
    AssertAi(actual.Length == expected.Length,
        message " (target count " actual.Length ", expected " expected.Length ")")
    for index, expectedTarget in expected {
        AssertAi(actual[index].Url == expectedTarget.Url
                && actual[index].Protocol == expectedTarget.Protocol,
            message " (candidate " index ": " actual[index].Protocol " "
                actual[index].Url ")")
    }
}

CaptureAiConnectionResult(store, ok, message, responseText, requestId, *) {
    store.Called := true
    store.Ok := ok
    store.Message := message
    store.ResponseText := responseText
    store.RequestId := requestId
}

CaptureAiRequestStatus(store, status, requestId, *) {
    store.Push({Status: status, RequestId: requestId})
}

class AIServiceProbe extends AIService {
    SendTarget(requestId, targetIndex, compatibilityMode := false) {
        if !this.Requests.Has(requestId)
            return {Ok: false, Message: "missing request"}
        entry := this.Requests[requestId]
        entry.TargetIndex := targetIndex
        entry.Target := entry.Targets[targetIndex]
        entry.CompatibilityMode := !!compatibilityMode
        return {Ok: true}
    }
}

service := AIService()
defaults := service.NormalizeSettings({})
AssertAi(defaults.AIAddress == "" && defaults.AIModel == "",
    "AI address or model still has a prefilled default.")
settings := service.NormalizeSettings({
    AIAddress: "localhost:11434",
    AIKey: "key",
    AIModel: "demo",
    AITimeoutS: 9999,
    AIPrompt: "generate",
    AIOptimizePrompt: "optimize",
    AISystemPrompt: "system {当前类型} {界面语言}",
    RunAsAdministrator: false
})
AssertAi(settings.AITimeoutS == AIService.DefaultTimeoutS,
    "AI timeout normalization is incorrect.")
AssertAi(settings.AIAddress == "localhost:11434",
    "AI address normalization changed the configured value.")
AssertAi(settings.AISystemPrompt == "system {当前类型} {界面语言}",
    "The custom AI system prompt was not retained.")
AssertAi(!settings.RunAsAdministrator,
    "The configured elevation preference was not retained for AI context.")
legacyGeneratePrompt := "生成符合要求的完整键鼠重映射持久化规则块。"
    . "只返回规则块文本，不要 Markdown 代码围栏或解释。"
previousGeneratePrompt := "先把用户目的拆成可验证的触发输入、事件时序、"
    . "穿透行为、生效范围和输出结果，再依据应用能力选择规则块或受托管脚本。"
    . "形式由你决定，不要询问用户；不得为了使用规则块而删减需求，"
    . "也不得用元数据代替实际实现。完成后逐项核对行为与边界情况。"
    . "只返回一个完整持久化规则块，不要 Markdown 代码围栏、判断过程或解释。"
legacyOptimizePrompt := "优化当前键鼠重映射规则，保持用户意图和元数据语义。"
    . "只返回完整规则块文本，不要 Markdown 代码围栏或解释。"
legacySystemPrompt := "你是键鼠重映射小助手的 AutoHotkey v2 规则专家。`n"
    . "当前规则类型：{当前类型}`n当前界面语言：{界面语言}`n"
    . "@generated-sha256`n@类型必须精确为“普通规则块”`n"
    . "@类型必须精确为“受托管独立脚本”`n"
    . "提交前完成检查，然后只返回规则块。"
upgradedPrompts := service.NormalizeSettings({
    AIPrompt: legacyGeneratePrompt,
    AIOptimizePrompt: legacyOptimizePrompt,
    AISystemPrompt: legacySystemPrompt
})
AssertAi(upgradedPrompts.AIPrompt == AIService.DefaultGeneratePrompt
        && upgradedPrompts.AIOptimizePrompt
            == AIService.DefaultOptimizePrompt
        && upgradedPrompts.AISystemPrompt == AIService.DefaultSystemPrompt
        && !InStr(upgradedPrompts.AISystemPrompt, "@generated-sha256")
        && !InStr(upgradedPrompts.AISystemPrompt, "普通规则块"),
    "Published legacy AI prompts were not upgraded to the current contract.")
AssertAi(AIService.NormalizeGeneratePrompt(previousGeneratePrompt)
            == AIService.DefaultGeneratePrompt
        && InStr(AIService.DefaultGeneratePrompt,
            "为 AHK v2 源码添加详细、准确且与实现一致的注释") != 0,
    "The previous generation prompt was not upgraded with code comments.")
customPreviousGeneratePrompt := previousGeneratePrompt " 保留我的自定义要求。"
AssertAi(AIService.NormalizeGeneratePrompt(customPreviousGeneratePrompt)
        == customPreviousGeneratePrompt,
    "A customized generation prompt was overwritten during migration.")
customLegacyLikePrompt := legacySystemPrompt "`n保留我的自定义说明。"
AssertAi(AIService.NormalizeSystemPrompt(customLegacyLikePrompt)
        == customLegacyLikePrompt,
    "A customized system prompt was mistaken for the obsolete bundled contract.")
customSystemPrompt := "我的自定义系统说明包含普通规则块，但不是旧内置合同。"
AssertAi(AIService.NormalizeSystemPrompt(customSystemPrompt)
        == customSystemPrompt,
    "An unrelated custom system prompt was mistaken for a bundled legacy prompt.")
currentBundledSystemPrompt := "你是键鼠重映射小助手的 AutoHotkey v2 规则专家。"
    . "{当前类型}{界面语言}共同输出协议："
    . "规则块（当前规则形式指定规则块"
    . "受托管脚本（当前规则形式然后只返回规则块。"
AssertAi(AIService.NormalizeSystemPrompt(currentBundledSystemPrompt)
        == AIService.DefaultSystemPrompt,
    "The previous bundled system contract was not upgraded.")
customCurrentBundledPrompt := currentBundledSystemPrompt "`n保留自定义说明。"
AssertAi(AIService.NormalizeSystemPrompt(customCurrentBundledPrompt)
        == customCurrentBundledPrompt,
    "A customized previous system contract was overwritten during migration.")
longPrompt := StrReplace(Format("{:20001}", ""), " ", "x")
longPromptSettings := service.NormalizeSettings({AIPrompt: longPrompt})
AssertAi(StrLen(longPromptSettings.AIPrompt) == 20001,
    "AI prompts are still silently truncated by a local character limit.")
LocalizationService.Configure("zh-CN", "")
purposeMessages := service.BuildMessages(settings, "managed", "generate",
    "current rule", "按住 CapsLock 后使用 I、J、K、L 移动光标")
AssertAi(purposeMessages.Length == 2
        && InStr(purposeMessages[2]["content"], "generate")
        && InStr(purposeMessages[2]["content"],
            "按住 CapsLock 后使用 I、J、K、L 移动光标")
        && InStr(purposeMessages[2]["content"], "current rule")
        && InStr(purposeMessages[2]["content"], "不可信任务数据")
        && !InStr(purposeMessages[1]["content"],
            "system 规则块 zh-CN")
        && InStr(purposeMessages[2]["content"],
            '"custom_system_guidance":"system 规则块 zh-CN"')
        && InStr(purposeMessages[2]["content"],
            '"operation_guidance":"generate"')
        && InStr(purposeMessages[2]["content"],
            '"runtime_environment":{')
        && InStr(purposeMessages[2]["content"],
            '"ahk_version":"' A_AhkVersion '"')
        && InStr(purposeMessages[2]["content"],
            '"windows_version":"' A_OSVersion '"')
        && InStr(purposeMessages[2]["content"],
            '"host_process_is_elevated":')
        && InStr(purposeMessages[2]["content"],
            '"run_as_administrator_setting":false')
        && InStr(purposeMessages[1]["content"],
            "即使只有一项也一样")
        && InStr(purposeMessages[1]["content"],
            '"modifiers": ["Ctrl"]')
        && InStr(purposeMessages[1]["content"],
            "ArrowUp、PageUp、MouseWheelUp、KeyA")
        && InStr(purposeMessages[1]["content"],
            "不可变输出外壳")
        && InStr(purposeMessages[1]["content"],
            "; @mapping-begin")
        && InStr(purposeMessages[1]["content"],
            "持久化 @类型必须为受托管独立脚本")
        && InStr(purposeMessages[1]["content"],
            "app_command.value 只能是 Browser_Back")
        && InStr(purposeMessages[1]["content"],
            "application.process 是当前前台程序的可执行文件名")
        && InStr(purposeMessages[2]["content"],
            '"current_editor_content":"current rule"'),
    "The per-request rule purpose is missing from the AI user message.")
reviewMessages := service.BuildMessages(settings, "auto", "generate",
    "current rule", "实现复杂按键行为", "review", "candidate rule")
repairMessages := service.BuildMessages(settings, "script", "generate",
    "current rule", "实现复杂按键行为", "repair", "broken candidate",
    "AHK v2 syntax error on line 4")
AssertAi(InStr(reviewMessages[2]["content"],
            '"phase":"对照用户目的复核并改进候选规则"')
        && InStr(reviewMessages[2]["content"],
            '"candidate_rule":"candidate rule"')
        && InStr(reviewMessages[1]["content"], "行为契约")
        && InStr(reviewMessages[1]["content"], "GetKeyState")
        && InStr(reviewMessages[1]["content"], "InputHook")
        && InStr(reviewMessages[1]["content"], "#HotIf")
        && InStr(reviewMessages[1]["content"], "OnExit")
        && InStr(reviewMessages[1]["content"], "SendLevel")
        && InStr(reviewMessages[1]["content"],
            "规则块根部只允许 enabled、passthrough")
        && InStr(reviewMessages[1]["content"],
            "多个独立热键、序列、多击、跨热键状态")
        && InStr(reviewMessages[1]["content"],
            "宿主分别启动、暂停、恢复和停止")
        && InStr(reviewMessages[1]["content"], "#SingleInstance Force")
        && InStr(reviewMessages[1]["content"], "窗口在按住期间切换")
        && InStr(repairMessages[2]["content"],
            '"phase":"根据本地校验反馈修复候选规则"')
        && InStr(repairMessages[2]["content"],
            '"candidate_rule":"broken candidate"')
        && InStr(repairMessages[2]["content"],
            '"local_validation_feedback":"AHK v2 syntax error on line 4"')
        && InStr(repairMessages[1]["content"], "不要只删除报错字段"),
    "The repair/review prompts lack the candidate, feedback, or AHK v2 behavioral audit contract.")
blankPurpose := service.Request(settings, "managed", "generate",
    "current rule", (*) => 0)
AssertAi(!blankPurpose.Ok && blankPurpose.Message == "请输入规则目的。",
    "AI mapping requests still accept an empty per-request purpose.")
missingReviewCandidate := service.Request(settings, "auto", "generate",
    "current rule", (*) => 0, "实现复杂按键行为", "review")
missingRepairFeedback := service.Request(settings, "script", "generate",
    "current rule", (*) => 0, "实现复杂按键行为", "repair",
    "broken candidate")
oversizedFeedback := StrReplace(Format("{:1048577}", ""), " ", "x")
oversizedRepairFeedback := service.Request(settings, "script", "generate",
    "current rule", (*) => 0, "实现复杂按键行为", "repair",
    "broken candidate", oversizedFeedback)
AssertAi(!missingReviewCandidate.Ok
        && InStr(missingReviewCandidate.Message, "缺少候选规则")
        && !missingRepairFeedback.Ok
        && InStr(missingRepairFeedback.Message, "缺少本地校验反馈")
        && !oversizedRepairFeedback.Ok
        && InStr(oversizedRepairFeedback.Message, "超过大小限制"),
    "Invalid AI repair/review request context was accepted.")
pipelineService := AIServiceProbe()
pipelineStatuses := []
pipelineStart := pipelineService.Request(settings, "auto", "generate",
    "current rule", (*) => 0, "实现复杂按键行为", "review",
    "candidate rule", "", CaptureAiRequestStatus.Bind(pipelineStatuses))
AssertAi(pipelineStart.Ok
        && pipelineService.Requests[pipelineStart.RequestId].Phase == "review"
        && pipelineService.Requests[pipelineStart.RequestId].TimeoutS
            == AIService.MinimumRuleRequestTimeoutS
        && pipelineStatuses.Length == 0,
    "The AI request entry did not retain its pipeline phase or timeout.")
pipelineService.NotifyRequestStatus(pipelineStart.RequestId, "connecting",
    true, pipelineService.Requests[pipelineStart.RequestId].Target)
pipelineService.NotifyRequestStatus(pipelineStart.RequestId, "waiting", true)
AssertAi(pipelineStatuses.Length == 2
        && pipelineStatuses[1].Status.Stage == "connecting"
        && pipelineStatuses[2].Status.Stage == "waiting"
        && pipelineStatuses[2].Status.TimeoutSeconds
            == AIService.MinimumRuleRequestTimeoutS
        && pipelineStatuses[2].RequestId == pipelineStart.RequestId,
    "AI transport status did not expose its concrete stage and timeout.")
pipelineService.Requests.Delete(pipelineStart.RequestId)
defaultSystemPrompt := AIService.DefaultSystemPrompt
autoFormatPrompt := AIService.DefaultAutoFormatSelectionPrompt
immutableSystemPrompt := service.BuildMessages(defaults, "managed",
    "generate", "", "检查固定合同")[1]["content"]
AssertAi(!InStr(defaultSystemPrompt, "@spec-begin")
        && !InStr(defaultSystemPrompt, "to_if_held_down")
        && InStr(immutableSystemPrompt, "@spec-begin") != 0
        && InStr(immutableSystemPrompt, "to_if_held_down") != 0
        && InStr(immutableSystemPrompt, "@script-code-begin") != 0
        && InStr(immutableSystemPrompt, "分号和恰好两个空格") != 0
        && InStr(immutableSystemPrompt, "不是 Windows 文件名") != 0
        && InStr(immutableSystemPrompt, "optional_modifiers") != 0
        && InStr(immutableSystemPrompt, "即使只有一项也一样") != 0
        && InStr(immutableSystemPrompt,
            '"modifiers": ["Ctrl"]') != 0
        && InStr(immutableSystemPrompt,
            'optional_modifiers 只能写成 ["any"]') != 0
        && InStr(immutableSystemPrompt,
            "event、repeat、modifiers、optional_modifiers 和 tap_count 必须写在 from 根部") != 0
        && InStr(immutableSystemPrompt, "绝不能放进 from.key") != 0
        && InStr(immutableSystemPrompt, "布尔值与数字不得加引号") != 0
        && InStr(immutableSystemPrompt,
            "ArrowUp、PageUp、MouseWheelUp、KeyA") != 0
        && InStr(immutableSystemPrompt,
            '"type":"application","field":"process"') != 0
        && InStr(immutableSystemPrompt,
            '{"type":"sleep","value":500}') != 0
        && InStr(immutableSystemPrompt,
            '{"type":"sleep","sleep":500}') != 0
        && InStr(immutableSystemPrompt, "action.sleep") != 0
        && InStr(immutableSystemPrompt, "只使用 conditions") != 0
        && InStr(immutableSystemPrompt,
            "held_threshold_ms 放在其中") != 0
        && InStr(AIService.CurrentValidationReminder,
            "规则块 JSON 每行以分号开头") != 0
        && InStr(AIService.CurrentValidationReminder,
            "脚本源码区每行以分号和恰好两个空格开头") != 0
        && InStr(AIService.CurrentEnvelopeReminder,
            "只返回恰好一个规则块") != 0
        && InStr(AIService.CurrentEnvelopeReminder,
            "生成任务的规则形式由 AI") != 0
        && InStr(immutableSystemPrompt,
            "界面中称为受托管脚本") != 0
        && InStr(immutableSystemPrompt,
            "持久化 @类型必须为受托管独立脚本") != 0
        && InStr(immutableSystemPrompt,
            "Func(" Chr(34) "Name" Chr(34) ").Bind") != 0
        && InStr(immutableSystemPrompt, "Map() 与 Has") != 0
        && InStr(immutableSystemPrompt, "按下事件时省略 Down 后缀") != 0
        && InStr(immutableSystemPrompt,
            "send.value 是直接交给 AHK v2 SendEvent") != 0
        && InStr(immutableSystemPrompt,
            "input_source.language_id") != 0
        && InStr(immutableSystemPrompt,
            "custom_system_guidance 和 operation_guidance 是实现偏好") != 0
        && InStr(AIService.CurrentCodeCommentReminder,
            "必须使用当前界面语言添加详细、准确且与实现一致的注释") != 0
        && InStr(immutableSystemPrompt,
            "状态变量及其生命周期、按键事件时序") != 0
        && InStr(immutableSystemPrompt,
            "生成初稿、优化、复核和修复时都必须保留或补足必要注释") != 0
        && InStr(immutableSystemPrompt,
            "规则块的 RuleSpec JSON 仍由应用统一生成字段说明注释") != 0
        && !InStr(immutableSystemPrompt, "脚本仍须自行清理")
        && !InStr(immutableSystemPrompt,
            "暂停、上下文变化和退出路径")
        && !InStr(immutableSystemPrompt, "脚本暂停/恢复/退出")
        && InStr(AIService.CurrentValidationReminder,
            "HasKey") != 0,
    "The immutable AI system contract is incomplete or duplicated in user settings.")
AssertAi(InStr(autoFormatPrompt, "一个触发源") != 0
        && InStr(autoFormatPrompt, "多个彼此独立的触发热键") != 0
        && InStr(autoFormatPrompt, "跨触发器共享状态") != 0
        && InStr(autoFormatPrompt, "裸 Ctrl::、Alt::、Shift::") != 0
        && InStr(autoFormatPrompt, "单按吞掉") != 0
        && InStr(autoFormatPrompt, "sleep 只表示等待") != 0
        && InStr(autoFormatPrompt,
            "key_up 只释放同一规则先前通过 key_down") != 0
        && InStr(autoFormatPrompt, "按键序列、双击/多击") != 0
        && InStr(autoFormatPrompt, "按固定时间间隔重复动作") != 0
        && InStr(autoFormatPrompt, "没有可观察松开事件的来源") != 0
        && InStr(autoFormatPrompt, "不得为了通过规则块格式而删除") != 0
        && InStr(autoFormatPrompt, "不得要求用户先选择形式") != 0,
    "The AI format-selection guide lacks the information needed to choose a rule type.")
AssertAi(!InStr(immutableSystemPrompt, "@kmra-")
        && !InStr(immutableSystemPrompt, "@script-spec")
        && !InStr(immutableSystemPrompt, "规则级 schema")
        && !InStr(immutableSystemPrompt, "每项上方先用自然、易懂的母语")
        && !InStr(immutableSystemPrompt, "每个 JSON 属性上方"),
    "The immutable AI system contract still describes obsolete data.")
defaultManagedMessages := service.BuildMessages(defaults, "managed",
    "generate", "", "测试规则块")
defaultScriptMessages := service.BuildMessages(defaults, "script",
    "generate", "", "测试受托管脚本")
defaultAutoMessages := service.BuildMessages(defaults, "auto",
    "generate", "当前空白模板", "测试自动判断")
customAutoMessages := service.BuildMessages(settings, "auto",
    "generate", "当前空白模板", "测试自定义提示下的自动判断")
AssertAi(InStr(defaultManagedMessages[1]["content"],
            "当前规则形式：规则块") != 0
        && InStr(defaultScriptMessages[1]["content"],
            "当前规则形式：受托管独立脚本") != 0
        && InStr(defaultAutoMessages[1]["content"],
            "当前规则形式：AI 自动判断：规则块或受托管脚本")
                != 0
        && InStr(defaultAutoMessages[1]["content"],
            "不受当前编辑器空白模板影响") != 0
        && InStr(defaultAutoMessages[2]["content"],
            '"rule_format":"AI 自动判断：规则块或受托管脚本"')
                != 0
        && InStr(defaultAutoMessages[2]["content"],
            '"format_decision":"由 AI 根据用户目的和应用能力边界自动判断，不询问用户"')
                != 0
        && InStr(defaultAutoMessages[2]["content"],
            '"current_editor_content_usage":"可能是空白模板或未保存草稿；不得据此决定规则形式，仅在与用户目的相符时参考"')
                != 0,
    "The AI message context does not match the requested rule mode.")
AssertAi(InStr(customAutoMessages[1]["content"],
            "多个彼此独立的触发热键") != 0
        && InStr(customAutoMessages[1]["content"],
            "区分修饰键的短按/长按") != 0
        && InStr(customAutoMessages[1]["content"],
            "{Blind}{vkE8}") != 0
        && InStr(customAutoMessages[1]["content"],
            "A_PriorKey") != 0
        && InStr(defaultAutoMessages[1]["content"],
            "必须选择受托管脚本并分别处理左右按键") != 0,
    "The immutable system message lacks the automatic format-selection contract.")
AssertAi(!InStr(customAutoMessages[1]["content"],
            "system AI 自动判断")
        && InStr(customAutoMessages[2]["content"],
            '"custom_system_guidance":"system AI 自动判断：规则块或受托管脚本 zh-CN"') != 0
        && InStr(customAutoMessages[2]["content"],
            '"operation_guidance":"generate"') != 0,
    "Custom AI guidance was not isolated from the immutable system contract.")
AssertAi(!InStr(defaultAutoMessages[1]["content"], "{形式判断说明}")
        && !InStr(defaultManagedMessages[1]["content"], "{当前类型}")
        && !InStr(defaultScriptMessages[1]["content"], "{界面语言}"),
    "AI prompt placeholders leaked into the final system message.")
invalidAutoOptimize := service.Request(settings, "auto", "optimize",
    "current rule", (*) => 0, "优化当前规则")
AssertAi(!invalidAutoOptimize.Ok
        && InStr(invalidAutoOptimize.Message, "仅用于生成规则") != 0,
    "AI auto mode was accepted for an optimization request.")
missingSettings := service.Request({}, "managed", "generate", "", (*) => 0)
AssertAi(!missingSettings.Ok
        && missingSettings.Action == "open-ai-settings",
    "Missing AI settings do not expose the settings navigation action.")
missingConnectionSettings := service.TestConnection({}, (*) => 0)
AssertAi(!missingConnectionSettings.Ok,
    "Connection testing accepted missing AI settings.")
targets := service.ResolveTargets("http://localhost:11434", "demo")
AssertAi(targets.Length == 1 && targets[1].Protocol == "ollama",
    "Ollama endpoint inference is incorrect.")
targets := service.ResolveTargets("https://api.openai.com/v1", "demo")
AssertAi(InStr(targets[1].Url, "/v1/chat/completions") != 0
    && targets[1].Protocol == "openai-chat",
    "OpenAI endpoint inference is incorrect.")
targets := service.ResolveTargets("https://api.openai.com/v1/", "demo")
AssertAi(InStr(targets[1].Url, "/v1/chat/completions") != 0,
    "Trailing slash normalization is incorrect.")
targets := service.ResolveTargets("https://api.openai.com?api-version=1", "demo")
AssertAi(InStr(targets[1].Url, "/v1/chat/completions?api-version=1") != 0,
    "Root query preservation is incorrect.")
targets := service.ResolveTargets("https://api.anthropic.com", "claude-sonnet")
AssertAi(targets.Length == 1
    && InStr(targets[1].Url, "/v1/messages") != 0
    && targets[1].Protocol == "anthropic",
    "Anthropic endpoint inference is incorrect.")
targets := service.ResolveTargets(
    "https://us-central1-aiplatform.googleapis.com", "gemini-2.0-flash")
AssertAi(targets.Length >= 1 && targets[1].Protocol == "openai-chat"
    && InStr(targets[1].Url, "/v1/chat/completions") != 0,
    "A non-model Vertex address should remain OpenAI-compatible.")
targets := service.ResolveTargets("https://api.openai.com/v1?api-version=1", "demo")
AssertAi(targets.Length == 2 && InStr(targets[1].Url, "?api-version=1") != 0
    && targets[2].Protocol == "openai-responses",
    "OpenAI endpoint fallback or query preservation is incorrect.")
messages := [Map("role", "system", "content", "system"),
    Map("role", "user", "content", "user")]
targets := service.ResolveTargets(
    "https://demo.openai.azure.com", "deployment-name")
AssertAi(targets.Length == 2
        && InStr(targets[1].Url, "/openai/v1/responses") != 0
        && InStr(targets[2].Url, "/openai/v1/chat/completions") != 0
        && targets[1].Protocol == "openai-responses"
        && targets[2].Protocol == "openai-chat",
    "Azure modern v1 endpoint inference is incorrect.")
azureRequest := service.EncodeRequest(targets[2], messages, "deployment-name",
    "secret")
azurePayload := JsonCodec.Parse(azureRequest.Payload)
AssertAi(azurePayload["model"] == "deployment-name"
        && azureRequest.Headers["api-key"] == "secret",
    "Azure modern v1 request encoding is incorrect.")
targets := service.ResolveTargets(
    "https://demo.openai.azure.com/openai/deployments/deployment-name",
    "ignored")
AssertAi(targets.Length == 1
        && targets[1].Protocol == "openai-chat"
        && InStr(targets[1].Url,
            "/openai/deployments/deployment-name/chat/completions") != 0,
    "An explicit Azure deployments path was not preserved.")
targets := service.ResolveTargets("https://api.openai.com/v1", "demo")
encoded := service.EncodeRequest(targets[1], messages, "demo", "secret")
payload := JsonCodec.Parse(encoded.Payload)
AssertAi(payload["model"] == "demo" && payload["messages"].Length == 2
        && payload["max_completion_tokens"]
            == AIService.MaximumOutputTokens
        && payload["stream"] is JsonBoolean
        && !payload["stream"].Value,
    "OpenAI request encoding is incorrect.")
compatibilityEncoded := service.EncodeRequest(targets[1], messages, "demo",
    "secret", true)
compatibilityPayload := JsonCodec.Parse(compatibilityEncoded.Payload)
AssertAi(!compatibilityPayload.Has("stream")
        && !compatibilityPayload.Has("max_completion_tokens")
        && !compatibilityPayload.Has("max_tokens"),
    "The OpenAI-compatible fallback did not remove optional parameters.")
AssertAi(AIService.ShouldRetryWithoutOptionalParameters(400,
        '{"error":{"message":"Unknown parameter: max_completion_tokens"}}')
        && AIService.ShouldRetryWithoutOptionalParameters(422,
            '{"error":"不支持字段 generationConfig"}')
        && !AIService.ShouldRetryWithoutOptionalParameters(401,
            '{"error":"unknown max_tokens"}')
        && !AIService.ShouldRetryWithoutOptionalParameters(400,
            '{"error":"invalid model"}'),
    "Optional request parameter compatibility retry classification is unsafe.")
response := JsonCodec.Parse('{"choices":[{"message":{"content":"rule"}}]}')
AssertAi(service.DecodeResponse("openai-chat", response) == "rule",
    "OpenAI response decoding is incorrect.")

anthropicEncoded := service.EncodeRequest({
    Url: "https://api.anthropic.com/v1/messages", Protocol: "anthropic"
}, messages, "claude-demo", "secret")
anthropicPayload := JsonCodec.Parse(anthropicEncoded.Payload)
AssertAi(anthropicPayload["max_tokens"] == AIService.MaximumOutputTokens
        && anthropicPayload["stream"] is JsonBoolean
        && !anthropicPayload["stream"].Value,
    "Anthropic output limits or explicit non-streaming mode are missing.")
geminiEncoded := service.EncodeRequest({
    Url: "https://generativelanguage.googleapis.com/v1beta/models/demo:generateContent",
    Protocol: "gemini"
}, messages, "gemini-demo", "secret")
geminiPayload := JsonCodec.Parse(geminiEncoded.Payload)
AssertAi(geminiPayload["generationConfig"]["maxOutputTokens"]
        == AIService.MaximumOutputTokens,
    "Gemini output limits are missing.")
ollamaEncoded := service.EncodeRequest({
    Url: "http://localhost:11434/api/chat", Protocol: "ollama"
}, messages, "demo", "")
ollamaPayload := JsonCodec.Parse(ollamaEncoded.Payload)
AssertAi(ollamaPayload["options"]["num_predict"]
        == AIService.MaximumOutputTokens
        && ollamaPayload["stream"] is JsonBoolean
        && !ollamaPayload["stream"].Value,
    "Ollama output limits or explicit non-streaming mode are missing.")
ollamaCompatibilityEncoded := service.EncodeRequest({
    Url: "http://localhost:11434/api/chat", Protocol: "ollama"
}, messages, "demo", "", true)
ollamaCompatibilityPayload := JsonCodec.Parse(
    ollamaCompatibilityEncoded.Payload)
AssertAi(!ollamaCompatibilityPayload.Has("stream")
        && !ollamaCompatibilityPayload.Has("options"),
    "The Ollama compatibility retry retained rejected optional fields.")
genericCompatibilityEncoded := service.EncodeRequest({
    Url: "http://localhost:9000/chat", Protocol: "generic"
}, messages, "demo", "", true)
genericCompatibilityPayload := JsonCodec.Parse(
    genericCompatibilityEncoded.Payload)
AssertAi(!genericCompatibilityPayload.Has("stream"),
    "The generic compatibility retry retained the rejected stream field.")

multiChoice := JsonCodec.Parse('{"choices":[{"finish_reason":"content_filter","message":{"content":""}},{"finish_reason":"stop","message":{"content":"complete rule"}}]}')
AssertAi(service.DecodeResponse("openai-chat", multiChoice)
        == "complete rule",
    "OpenAI decoding did not fall back to a later valid choice.")
truncatedChoice := service.DecodeResponseResult("openai-chat",
    JsonCodec.Parse('{"choices":[{"finish_reason":"length","message":{"content":"partial"}}]}'))
AssertAi(truncatedChoice.Text == ""
        && InStr(truncatedChoice.Issue, "输出长度上限") != 0,
    "OpenAI length truncation is not rejected explicitly.")
refusedChoice := service.DecodeResponseResult("openai-chat",
    JsonCodec.Parse('{"choices":[{"finish_reason":"stop","message":{"refusal":"blocked","content":null}}]}'))
AssertAi(refusedChoice.Text == ""
        && InStr(refusedChoice.Issue, "模型拒绝") != 0,
    "OpenAI refusals are not classified explicitly.")
toolChoice := service.DecodeResponseResult("openai-chat",
    JsonCodec.Parse('{"choices":[{"finish_reason":"tool_calls","message":{"content":"","tool_calls":[{"id":"1"}]}}]}'))
AssertAi(toolChoice.Text == ""
        && InStr(toolChoice.Issue, "工具调用") != 0,
    "OpenAI tool-call responses are not rejected explicitly.")
incompleteResponse := service.DecodeResponseResult("openai-responses",
    JsonCodec.Parse('{"status":"incomplete","incomplete_details":{"reason":"max_output_tokens"},"output_text":"partial"}'))
AssertAi(incompleteResponse.Text == ""
        && InStr(incompleteResponse.Issue, "输出长度上限") != 0,
    "OpenAI Responses truncation is not rejected explicitly.")
anthropicTruncation := service.DecodeResponseResult("anthropic",
    JsonCodec.Parse('{"stop_reason":"max_tokens","content":[{"type":"text","text":"partial"}]}'))
AssertAi(anthropicTruncation.Text == ""
        && InStr(anthropicTruncation.Issue, "输出长度上限") != 0,
    "Anthropic truncation is not rejected explicitly.")
geminiCandidates := service.DecodeResponseResult("gemini",
    JsonCodec.Parse('{"candidates":[{"finishReason":"SAFETY","content":{"parts":[]}},{"finishReason":"STOP","content":{"parts":[{"thought":true,"text":"hidden"},{"text":"complete rule"}]}}]}'))
AssertAi(geminiCandidates.Text == "complete rule"
        && geminiCandidates.Issue == "",
    "Gemini decoding did not skip a blocked candidate or hidden thought.")
geminiBlocked := service.DecodeResponseResult("gemini",
    JsonCodec.Parse('{"promptFeedback":{"blockReason":"SAFETY"},"candidates":[]}'))
AssertAi(geminiBlocked.Text == ""
        && InStr(geminiBlocked.Issue, "服务策略：") == 1,
    "Gemini prompt blocking is not classified explicitly.")
ollamaTruncation := service.DecodeResponseResult("ollama",
    JsonCodec.Parse('{"done":true,"done_reason":"length","message":{"content":"partial"}}'))
AssertAi(ollamaTruncation.Text == ""
        && InStr(ollamaTruncation.Issue, "输出长度上限") != 0,
    "Ollama truncation is not rejected explicitly.")

providerCases := [
    {Url: "https://api.openai.com/v1/chat/completions", Id: "openai"},
    {Url: "https://demo.openai.azure.com/openai/v1/chat/completions", Id: "azure"},
    {Url: "https://api.anthropic.com/v1/messages", Id: "anthropic"},
    {Url: "https://generativelanguage.googleapis.com/v1beta/models/demo:generateContent", Id: "google-gemini"},
    {Url: "https://us-central1-aiplatform.googleapis.com/v1/models/demo:generateContent", Id: "google-vertex"},
    {Url: "https://bedrock-runtime.us-east-1.amazonaws.com/model/demo/invoke", Id: "aws-bedrock"},
    {Url: "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions", Id: "alibaba-dashscope"},
    {Url: "https://qianfan.baidubce.com/v2/chat/completions", Id: "baidu-qianfan"},
    {Url: "https://api.lkeap.cloud.tencent.com/v1/chat/completions", Id: "tencent-hunyuan"},
    {Url: "https://ark.cn-beijing.volces.com/api/v3/chat/completions", Id: "volcengine-ark"},
    {Url: "https://open.bigmodel.cn/api/paas/v4/chat/completions", Id: "zhipu"},
    {Url: "https://api.deepseek.com/v1/chat/completions", Id: "deepseek"},
    {Url: "https://api.moonshot.cn/v1/chat/completions", Id: "moonshot"},
    {Url: "https://api.siliconflow.cn/v1/chat/completions", Id: "siliconflow"},
    {Url: "https://api.minimaxi.com/v1/chat/completions", Id: "minimax"},
    {Url: "https://api.baichuan-ai.com/v1/chat/completions", Id: "baichuan"},
    {Url: "https://api.lingyiwanwu.com/v1/chat/completions", Id: "lingyi"},
    {Url: "https://api.stepfun.com/v1/chat/completions", Id: "stepfun"},
    {Url: "https://api-inference.modelscope.cn/v1/chat/completions", Id: "modelscope"},
    {Url: "https://api.sensenova.cn/compatible-mode/v1/chat/completions", Id: "sensenova"},
    {Url: "https://openrouter.ai/api/v1/chat/completions", Id: "openrouter"},
    {Url: "https://api.groq.com/openai/v1/chat/completions", Id: "groq"},
    {Url: "https://api.mistral.ai/v1/chat/completions", Id: "mistral"},
    {Url: "https://api.x.ai/v1/chat/completions", Id: "xai"},
    {Url: "https://api.together.xyz/v1/chat/completions", Id: "together"},
    {Url: "https://integrate.api.nvidia.com/v1/chat/completions", Id: "nvidia-nim"},
    {Url: "https://api.cerebras.ai/v1/chat/completions", Id: "cerebras"},
    {Url: "https://api.fireworks.ai/inference/v1/chat/completions", Id: "fireworks"},
    {Url: "https://api.cohere.ai/compatibility/v1/chat/completions", Id: "cohere"},
    {Url: "https://api.perplexity.ai/chat/completions", Id: "perplexity"},
    {Url: "https://models.inference.ai.azure.com/chat/completions", Id: "github-models"},
    {Url: "http://localhost:11434/api/chat", Id: "ollama"}
]
for providerCase in providerCases
    AssertAi(AIService.InferProvider(providerCase.Url) == providerCase.Id
            && AIService.ProviderDisplayName(providerCase.Id) != "",
        "Provider classification is missing for " providerCase.Id ".")

providerRouteCases := [
    {Address: "https://open.bigmodel.cn", Path: "/api/paas/v4/chat/completions"},
    {Address: "https://ark.cn-beijing.volces.com", Path: "/api/v3/chat/completions"},
    {Address: "https://qianfan.baidubce.com", Path: "/v2/chat/completions"},
    {Address: "https://dashscope.aliyuncs.com", Path: "/compatible-mode/v1/chat/completions"},
    {Address: "https://api.perplexity.ai", Path: "/chat/completions"},
    {Address: "https://models.inference.ai.azure.com", Path: "/chat/completions"}
]
for routeCase in providerRouteCases {
    providerTargets := service.ResolveTargets(routeCase.Address, "demo")
    AssertAi(InStr(providerTargets[1].Url, routeCase.Path) != 0,
        "Provider base-path inference is incorrect for " routeCase.Address ".")
}
targets := service.ResolveTargets(
    "<https://api.openai.com/v1/chat/completions/chat/completions>",
    "demo")
AssertAi(targets.Length == 1
        && targets[1].Url == "https://api.openai.com/v1/chat/completions"
        && targets[1].Inference == "explicit",
    "Repeated explicit OpenAI path segments were not canonicalized.")
targets := service.ResolveTargets("https://api.deepseek.com", "demo")
AssertAi(targets.Length == 4
        && InStr(targets[1].Url, "/chat/completions") != 0
        && !InStr(targets[1].Url, "/v1/")
        && InStr(targets[2].Url, "/v1/chat/completions") != 0
        && targets[3].Protocol == "openai-responses",
    "DeepSeek base-path candidates are not ordered correctly.")
targets := service.ResolveTargets(
    "https://generativelanguage.googleapis.com/v1beta", "gemini 2")
AssertAi(targets.Length == 1 && targets[1].Protocol == "gemini"
        && InStr(targets[1].Url, "/gemini%202:generateContent") != 0,
    "Gemini model escaping or endpoint normalization is incorrect.")
targets := service.ResolveTargets(
    "https://generativelanguage.googleapis.com/v1beta/models/gemini-2/streamGenerateContent",
    "ignored")
AssertAi(targets.Length == 1 && targets[1].Protocol == "gemini"
        && InStr(targets[1].Url, "/models/gemini-2:generateContent") != 0,
    "Gemini slash stream action normalization is incorrect.")
targets := service.ResolveTargets("http://ollama.localhost:11434/api", "demo")
AssertAi(targets.Length == 1 && targets[1].Protocol == "ollama"
        && InStr(targets[1].Url, "/api/chat") != 0,
    "Ollama hostname and API path inference is incorrect.")
AssertAiTargets(service, "gateway.localhost:8765", "demo", [
    {Url: "http://gateway.localhost:8765/v1/chat/completions",
        Protocol: "openai-chat"},
    {Url: "http://gateway.localhost:8765/chat/completions",
        Protocol: "openai-chat"},
    {Url: "http://gateway.localhost:8765/v1/responses",
        Protocol: "openai-responses"},
    {Url: "http://gateway.localhost:8765/responses",
        Protocol: "openai-responses"}
], "Local hostname scheme or generic fallback order is incorrect.")
AssertAiTargets(service, "//api.openai.com", "demo", [
    {Url: "https://api.openai.com/v1/chat/completions",
        Protocol: "openai-chat"},
    {Url: "https://api.openai.com/v1/responses",
        Protocol: "openai-responses"}
], "Protocol-relative OpenAI address normalization is incorrect.")
AssertAiTargets(service,
    "https://example.test/custom/api", "demo", [
    {Url: "https://example.test/custom/api/chat/completions",
        Protocol: "openai-chat"},
    {Url: "https://example.test/custom/api/v1/chat/completions",
        Protocol: "openai-chat"},
    {Url: "https://example.test/custom/api/responses",
        Protocol: "openai-responses"},
    {Url: "https://example.test/custom/api/v1/responses",
        Protocol: "openai-responses"}
], "Custom OpenAI-compatible base-path candidates are incorrect.")
AssertAiTargets(service,
    "https://example.test/v1/chat/chat/completions", "demo", [
    {Url: "https://example.test/v1/chat/completions",
        Protocol: "openai-chat"}
], "Repeated Chat path normalization is incorrect.")
AssertAiTargets(service,
    "https://example.test/v1/responses/responses", "demo", [
    {Url: "https://example.test/v1/responses",
        Protocol: "openai-responses"}
], "Repeated Responses path normalization is incorrect.")
AssertAiTargets(service,
    "https://api.anthropic.com/v1/messages/messages", "demo", [
    {Url: "https://api.anthropic.com/v1/messages",
        Protocol: "anthropic"}
], "Repeated Anthropic path normalization is incorrect.")
AssertAiTargets(service,
    "http://localhost:11434/api/chat/api/chat", "demo", [
    {Url: "http://localhost:11434/api/chat", Protocol: "ollama"}
], "Repeated Ollama path normalization is incorrect.")
AssertAiTargets(service,
    "https://generativelanguage.googleapis.com/v1beta/models/gemini-2:generateContent:generateContent",
    "ignored", [
    {Url: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2:generateContent",
        Protocol: "gemini"}
], "Repeated Gemini action normalization is incorrect.")
AssertAiTargets(service,
    "https://example.test/v1/chat/completion", "demo", [
    {Url: "https://example.test/v1/chat/completions",
        Protocol: "openai-chat"}
], "Partial Chat endpoint normalization is incorrect.")
AssertAiTargets(service,
    "https://example.test/v1/response", "demo", [
    {Url: "https://example.test/v1/responses",
        Protocol: "openai-responses"}
], "Partial Responses endpoint normalization is incorrect.")
AssertAiTargets(service,
    "https://us-central1-aiplatform.googleapis.com/v1/projects/p/locations/l/publishers/google/models/gemini-2",
    "ignored", [
    {Url: "https://us-central1-aiplatform.googleapis.com/v1/projects/p/locations/l/publishers/google/models/gemini-2:generateContent",
        Protocol: "gemini"}
], "Vertex model-path routing is incorrect.")
AssertAi(AIService.DescribeConnectionFailure(
        'AI 服务返回 HTTP 401：{"error":{"message":"Invalid API key"}}')
        == "API 密钥：身份验证失败，密钥或访问令牌无效、已过期或未被接受（HTTP 401）。",
    "HTTP authentication failures are not described concretely in Chinese.")
AssertAi(AIService.DescribeConnectionFailure(
        "The operation timed out")
        == "请求超时：AI 服务未在设定时限内完成连接测试。",
    "Transport timeouts are not described concretely in Chinese.")
AssertAi(AIService.DescribeConnectionFailure(
        "Object of type String has no property named Status")
        == "响应协议：AI 服务返回的数据结构与当前协议不一致。",
    "Protocol-shape failures are not described concretely in Chinese.")
AssertAi(AIService.DescribeConnectionFailure(
        "(0x80004002) 不支持此接口")
        == "程序组件：无法读取 WinHTTP 响应接口。",
    "COM interface failures are incorrectly attributed to an AI parameter.")
AssertAi(AIService.DescribeConnectionFailure(
        "程序组件：WinHTTP 请求对象不可用。")
        == "程序组件：WinHTTP 请求对象不可用。",
    "Internal component failures are incorrectly attributed to the address.")
AssertAi(AIService.DescribeConnectionFailure(
        'AI 服务返回 HTTP 404：{"error":{"message":"model demo not found"}}')
        == "模型名称：指定的模型名称不存在（HTTP 404）。",
    "Model failures are not attributed to the model parameter.")
AssertAi(AIService.DescribeConnectionFailure(
        "An unrecognized WinHTTP failure")
        == "API 地址：网络组件无法使用该地址或与其建立连接。",
    "Unknown transport failures are not attributed to the API address.")
AssertAi(AIService.DescribeTransportFailure(12345,
        "An unrecognized WinHTTP failure")
        == "API 地址：网络请求失败，底层错误代码为 12345。",
    "Numbered transport failures do not preserve their concrete error code.")

azureV1Context := {
    Provider: "azure",
    Protocol: "openai-chat",
    TargetUrl: "https://example.openai.azure.com/openai/v1/chat/completions",
    TargetInference: "explicit",
    ConfiguredModel: "gpt-5-min",
    ModelLocation: "body"
}
azureGeneric404 := AIService.DescribeHttpFailure(404,
    '{"error":{"code":"404","message":"Resource not found"}}',
    azureV1Context)
AssertAi(azureGeneric404
        == "模型名称：Azure OpenAI 未找到部署“gpt-5-min”；这里应填写部署名称，不是基础模型名（HTTP 404；错误码 404）。",
    "A generic Azure v1 404 was not attributed to the deployment name.")
AssertAi(AIService.DescribeConnectionFailure(azureGeneric404)
        == azureGeneric404,
    "A classified model failure was reclassified from its embedded HTTP code.")

deploymentFailure := AIService.DescribeHttpFailure(404,
    '{"error":{"code":"DeploymentNotFound","message":"The configured deployment does not exist."}}',
    azureV1Context)
AssertAi(InStr(deploymentFailure, "模型名称：") == 1
        && InStr(deploymentFailure, "错误码 DeploymentNotFound") != 0,
    "DeploymentNotFound was not attributed to the model name.")
modelNotFoundFailure := AIService.DescribeHttpFailure(404,
    '{"error":{"code":"model_not_found","message":"The requested model was not found."}}',
    {ConfiguredModel: "missing-model"})
AssertAi(InStr(modelNotFoundFailure, "模型名称：") == 1
        && InStr(modelNotFoundFailure, "missing-model") != 0,
    "model_not_found was not attributed to the model name.")
modelParamFailure := AIService.DescribeHttpFailure(400,
    '{"error":{"type":"invalid_request_error","param":"model","message":"Invalid value"}}',
    {ConfiguredModel: "bad-model"})
AssertAi(InStr(modelParamFailure, "模型名称：") == 1,
    "error.param=model was not attributed to the model name.")
chineseModelFailure := AIService.DescribeHttpFailure(404,
    '{"error":{"message":"指定的部署不存在"}}',
    {ConfiguredModel: "中文部署"})
AssertAi(InStr(chineseModelFailure, "模型名称：") == 1,
    "A Chinese deployment error was not attributed to the model name.")

routeFailure := AIService.DescribeHttpFailure(404,
    '{"error":{"code":"route_not_found","message":"API route not found"}}',
    {Provider: "azure", Protocol: "openai-chat",
        TargetUrl: "https://example.openai.azure.com/wrong/path",
        TargetInference: "explicit", ConfiguredModel: "demo"})
AssertAi(InStr(routeFailure, "API 地址：") == 1,
    "Concrete route evidence was not attributed to the API address.")
ambiguous404 := AIService.DescribeHttpFailure(404, "Resource not found",
    {Provider: "generic", Protocol: "openai-chat",
        TargetUrl: "https://example.invalid/v1/chat/completions",
        TargetInference: "explicit", ConfiguredModel: "demo"})
AssertAi(InStr(ambiguous404, "AI 服务：") == 1
        && InStr(ambiguous404, "未说明是 API 路径还是模型/部署不存在") != 0,
    "An evidence-free 404 was assigned to a parameter without support.")
AssertAi(InStr(AIService.DescribeHttpFailure(405, "Cannot POST /wrong"),
        "API 地址：") == 1,
    "HTTP method/path failures were not attributed to the API address.")

AssertAi(InStr(AIService.DescribeHttpFailure(403,
        '{"error":{"code":"permission_denied","param":"model"}}'),
        "模型名称：") == 1,
    "Model-specific permission failures were not attributed to the model.")
AssertAi(InStr(AIService.DescribeHttpFailure(403,
        '{"error":{"code":"permission_denied"}}'), "API 密钥：") == 1,
    "General permission failures were not attributed to the API key.")
AssertAi(InStr(AIService.DescribeHttpFailure(400,
        '{"error":{"code":"invalid_api_key"}}'), "API 密钥：") == 1,
    "Provider-specific API-key failures were not attributed to the key.")
AssertAi(InStr(AIService.DescribeHttpFailure(429,
        '{"error":{"code":"insufficient_quota"}}'), "账户额度：") == 1,
    "Quota exhaustion was not classified separately from rate limiting.")
AssertAi(InStr(AIService.DescribeHttpFailure(429,
        '{"error":{"message":"Rate limit exceeded"}}'), "AI 服务：") == 1,
    "Rate limiting was not attributed to the AI service.")
AssertAi(InStr(AIService.DescribeHttpFailure(402,
        '{"error":{"message":"Payment required"}}'), "账户计费：") == 1,
    "Billing failures were not classified concretely.")
AssertAi(InStr(AIService.DescribeHttpFailure(400,
        '{"error":{"code":"context_length_exceeded"}}'), "请求内容：") == 1,
    "Context-length failures were not attributed to request content.")
AssertAi(InStr(AIService.DescribeHttpFailure(400,
        '{"error":{"code":"content_filter"}}'), "服务策略：") == 1,
    "Content-policy failures were not classified separately.")
AssertAi(InStr(AIService.DescribeHttpFailure(400,
        '{"error":{"code":"invalid_request_error"}}'), "请求协议：") == 1,
    "Generic invalid request data was not attributed to the request protocol.")
AssertAi(InStr(AIService.DescribeHttpFailure(503, "upstream unavailable"),
        "AI 服务：") == 1,
    "Server failures were incorrectly attributed to an AI parameter.")
AssertAi(InStr(AIService.DescribeHttpFailure(504, "gateway timeout"),
        "请求超时：") == 1,
    "Gateway timeouts were not classified as timeouts.")

vendorFailureCases := [
    {Name: "Anthropic", Status: 404,
        Body: '{"type":"error","error":{"type":"not_found_error","message":"model claude-demo not found"}}',
        Context: {Provider: "anthropic", ConfiguredModel: "claude-demo"},
        Category: "模型名称：", ProviderText: "Anthropic"},
    {Name: "Google", Status: 404,
        Body: '{"error":{"code":404,"message":"Publisher model not found","status":"NOT_FOUND"}}',
        Context: {Provider: "google-gemini", Protocol: "gemini",
            TargetUrl: "https://generativelanguage.googleapis.com/v1beta/models/gemini-demo:generateContent",
            ConfiguredModel: "gemini-demo"},
        Category: "模型名称：", ProviderText: "Google Gemini"},
    {Name: "Bedrock", Status: 404,
        Body: '{"__type":"ResourceNotFoundException","message":"model identifier was not found"}',
        Context: {Provider: "aws-bedrock", ModelLocation: "path",
            TargetUrl: "https://bedrock-runtime.us-east-1.amazonaws.com/model/demo/invoke",
            ConfiguredModel: "demo"},
        Category: "模型名称：", ProviderText: "AWS Bedrock"},
    {Name: "DashScope", Status: 401,
        Body: '{"code":"InvalidApiKey","message":"Invalid API-key provided"}',
        Context: {Provider: "alibaba-dashscope"},
        Category: "API 密钥：", ProviderText: "阿里云百炼/DashScope"},
    {Name: "Baidu", Status: 401,
        Body: '{"error_code":110,"error_msg":"Access token invalid"}',
        Context: {Provider: "baidu-qianfan"},
        Category: "API 密钥：", ProviderText: "百度智能云千帆"},
    {Name: "Tencent", Status: 403,
        Body: '{"Response":{"Error":{"Code":"AuthFailure.SecretIdNotFound","Message":"credential invalid"},"RequestId":"req-tencent"}}',
        Context: {Provider: "tencent-hunyuan"},
        Category: "API 密钥：", ProviderText: "腾讯云混元/LKEAP"},
    {Name: "Volcengine", Status: 404,
        Body: '{"error":{"code":"InvalidEndpointOrModel.NotFound","message":"model not found"}}',
        Context: {Provider: "volcengine-ark", ConfiguredModel: "ep-demo"},
        Category: "模型名称：", ProviderText: "火山引擎方舟"},
    {Name: "Moonshot", Status: 429,
        Body: '{"error":{"type":"insufficient_balance","message":"insufficient balance"}}',
        Context: {Provider: "moonshot"},
        Category: "账户计费：", ProviderText: "月之暗面 Moonshot"},
    {Name: "OpenRouter", Status: 429,
        Body: '{"error":{"code":"rate_limit_exceeded","message":"rate limit exceeded"}}',
        Context: {Provider: "openrouter"},
        Category: "AI 服务：", ProviderText: "OpenRouter"}
]
for failureCase in vendorFailureCases {
    vendorFailure := AIService.DescribeHttpFailure(failureCase.Status,
        failureCase.Body, failureCase.Context)
    AssertAi(InStr(vendorFailure, failureCase.Category) == 1
            && InStr(vendorFailure, failureCase.ProviderText) != 0,
        failureCase.Name " error classification is incomplete: " vendorFailure)
}

miniMaxError := AIService.ParseServiceError(
    '{"base_resp":{"status_code":1008,"status_msg":"invalid api key"}}')
AssertAi(miniMaxError.Present && miniMaxError.Code == "1008"
        && miniMaxError.Message == "invalid api key",
    "MiniMax HTTP-200 business errors are not parsed.")
tencentError := AIService.ParseServiceError(
    '{"Response":{"Error":{"Code":"InvalidParameter.Model","Message":"invalid model"},"RequestId":"req-123"}}')
AssertAi(tencentError.Present && tencentError.Code == "InvalidParameter.Model"
        && tencentError.RequestId == "req-123",
    "Tencent Cloud nested errors or request IDs are not parsed.")
AssertAi(AIService.ExtractRequestIdFromHeaders(
        "Content-Type: application/json`r`nx-request-id: req-header-456`r`n")
        == "req-header-456",
    "Provider request IDs are not extracted from response headers.")

AssertAi(InStr(AIService.DescribeTransportFailure(12007, ""),
        "API 地址：无法解析") == 1
        && InStr(AIService.DescribeTransportFailure(12029, ""),
            "API 地址：无法建立网络连接") == 1
        && InStr(AIService.DescribeTransportFailure(12175, ""),
            "API 地址：无法建立安全连接") == 1,
    "DNS, connection, or TLS transport errors are not distinguished.")

routeRetryContext := AIService.BuildHttpFailureContext(404,
    '{"error":"missing v1 route"}',
    {TargetInference: "normalized"})
AssertAi(AIService.ShouldRetryTarget(routeRetryContext),
    "A normalized missing route did not permit the protocol fallback.")
azureProtocolRetryContext := AIService.BuildHttpFailureContext(404,
    '{"error":{"code":"404","message":"Resource not found"}}',
    {Provider: "azure", Protocol: "openai-responses",
        TargetUrl: "https://example.openai.azure.com/openai/v1/responses",
        TargetInference: "normalized", ConfiguredModel: "demo"})
AssertAi(AIService.ShouldRetryTarget(azureProtocolRetryContext),
    "An inferred Azure Responses 404 did not allow the Chat fallback.")
modelNoRetryContext := AIService.BuildHttpFailureContext(404,
    '{"error":{"code":"model_not_found"}}',
    {TargetInference: "normalized"})
AssertAi(!AIService.ShouldRetryTarget(modelNoRetryContext),
    "A missing model was incorrectly treated as a missing route.")
unknown404Context := AIService.BuildHttpFailureContext(404,
    '{"error":{"code":"not_found","message":"unknown object"}}',
    {TargetInference: "normalized"})
AssertAi(!AIService.ShouldRetryTarget(unknown404Context),
    "An ambiguous coded 404 was incorrectly treated as a missing route.")
plainRoute404Context := AIService.BuildHttpFailureContext(404,
    '{"error":"not found"}', {TargetInference: "normalized"})
AssertAi(AIService.ShouldRetryTarget(plainRoute404Context),
    "A route-style plain 404 did not permit the endpoint fallback.")

fakeSecret := "test-secret-that-must-not-appear"
secretSafeFailure := AIService.DescribeHttpFailure(401,
    '{"error":{"code":"test-secret-that-must-not-appear","message":"invalid key test-secret-that-must-not-appear"}}',
    {TargetUrl: "https://example.invalid/v1/chat/completions?api_key="
        fakeSecret})
AssertAi(!InStr(secretSafeFailure, fakeSecret)
        && !InStr(secretSafeFailure, "api_key="),
    "AI failure output leaked a key or a URL query parameter.")

connectionService := AIServiceProbe()
connectionResult := {Called: false}
connectionStart := connectionService.TestConnection({
    AIAddress: "https://api.openai.com/v1",
    AIKey: "secret",
    AIModel: "demo",
    AITimeoutS: 12
}, CaptureAiConnectionResult.Bind(connectionResult))
AssertAi(connectionStart.Ok
        && connectionService.Requests.Has(connectionStart.RequestId),
    "Connection testing did not create an asynchronous AI request.")
connectionEntry := connectionService.Requests[connectionStart.RequestId]
AssertAi(connectionEntry.Kind == "connection-test"
        && connectionEntry.Messages.Length == 1
        && connectionEntry.Messages[1]["role"] == "user"
        && connectionEntry.Messages[1]["content"] == "hello",
    "Connection testing did not use the minimal protocol request.")
connectionEntry.Request := {
    Status: 200,
    ResponseText: '{"choices":[{"message":{"content":"hello"}}]}',
    WaitForResponse: (*) => true
}
connectionService.PollRequest(connectionStart.RequestId)
AssertAi(connectionResult.Called && connectionResult.Ok
        && connectionResult.RequestId == connectionStart.RequestId
        && InStr(connectionResult.ResponseText,
            "/v1/chat/completions") != 0
        && !connectionService.Requests.Has(connectionStart.RequestId),
    "Connection testing did not return the working endpoint.")
compatibilityResult := {Called: false}
compatibilityStart := connectionService.TestConnection({
    AIAddress: "https://gateway.example/v1/chat/completions",
    AIKey: "secret",
    AIModel: "demo",
    AITimeoutS: 12
}, CaptureAiConnectionResult.Bind(compatibilityResult))
compatibilityEntry := connectionService.Requests[
    compatibilityStart.RequestId]
compatibilityEntry.Request := {
    Status: 400,
    ResponseText: '{"error":{"message":"Unknown parameter: max_tokens"}}',
    WaitForResponse: (*) => true
}
connectionService.PollRequest(compatibilityStart.RequestId)
AssertAi(!compatibilityResult.Called
        && connectionService.Requests.Has(compatibilityStart.RequestId)
        && compatibilityEntry.CompatibilityMode,
    "An explicitly unsupported optional parameter did not trigger one compatible retry.")
compatibilityEntry.Request := {
    Status: 200,
    ResponseText: '{"choices":[{"finish_reason":"stop","message":{"content":"hello"}}]}',
    WaitForResponse: (*) => true
}
connectionService.PollRequest(compatibilityStart.RequestId)
AssertAi(compatibilityResult.Called && compatibilityResult.Ok
        && !connectionService.Requests.Has(compatibilityStart.RequestId),
    "The compatible request retry did not complete normally.")
failureResult := {Called: false}
failureStart := connectionService.TestConnection({
    AIAddress: "https://api.openai.com/v1",
    AIKey: "invalid",
    AIModel: "demo",
    AITimeoutS: 12
}, CaptureAiConnectionResult.Bind(failureResult))
AssertAi(failureStart.Ok, "The failing connection probe did not start.")
failureEntry := connectionService.Requests[failureStart.RequestId]
failureEntry.Request := {
    Status: 401,
    ResponseText: '{"error":{"message":"Invalid API key"}}',
    WaitForResponse: (*) => true
}
connectionService.PollRequest(failureStart.RequestId)
AssertAi(failureResult.Called && !failureResult.Ok
        && failureResult.Message
            == "API 密钥：OpenAI 身份验证失败，密钥或访问令牌无效、已过期或未被接受（HTTP 401）。"
        && !connectionService.Requests.Has(failureStart.RequestId),
    "The real connection failure path did not retain its concrete cause.")

azureFailureResult := {Called: false}
azureFailureStart := connectionService.TestConnection({
    AIAddress: "https://example.openai.azure.com/openai/v1/chat/completions",
    AIKey: "test-key",
    AIModel: "gpt-5-min",
    AITimeoutS: 12
}, CaptureAiConnectionResult.Bind(azureFailureResult))
AssertAi(azureFailureStart.Ok, "The Azure failure probe did not start.")
azureFailureEntry := connectionService.Requests[azureFailureStart.RequestId]
AssertAi(azureFailureEntry.Targets.Length == 1
        && azureFailureEntry.Target.Inference == "explicit",
    "The explicit Azure v1 endpoint lost its routing context.")
azureFailureEntry.Request := {
    Status: 404,
    ResponseText: '{"error":{"code":"404","message":"Resource not found"}}',
    WaitForResponse: (*) => true
}
connectionService.PollRequest(azureFailureStart.RequestId)
AssertAi(azureFailureResult.Called && !azureFailureResult.Ok
        && InStr(azureFailureResult.Message, "模型名称：") == 1
        && InStr(azureFailureResult.Message, "gpt-5-min") != 0
        && !connectionService.Requests.Has(azureFailureStart.RequestId),
    "The real Azure HTTP path did not identify the invalid deployment name.")

invalidResponseResult := {Called: false}
invalidResponseStart := connectionService.TestConnection({
    AIAddress: "https://api.openai.com/v1/chat/completions",
    AIKey: "test-key",
    AIModel: "demo",
    AITimeoutS: 12
}, CaptureAiConnectionResult.Bind(invalidResponseResult))
invalidResponseEntry := connectionService.Requests[invalidResponseStart.RequestId]
invalidResponseEntry.Request := {
    Status: 200,
    ResponseText: "not-json",
    WaitForResponse: (*) => true
}
connectionService.PollRequest(invalidResponseStart.RequestId)
AssertAi(invalidResponseResult.Called && !invalidResponseResult.Ok
        && InStr(invalidResponseResult.Message, "响应协议：") == 1,
    "A non-JSON success response was incorrectly attributed to the address.")

truncatedResult := {Called: false}
truncatedStart := connectionService.TestConnection({
    AIAddress: "https://api.openai.com/v1/chat/completions",
    AIKey: "test-key",
    AIModel: "demo",
    AITimeoutS: 12
}, CaptureAiConnectionResult.Bind(truncatedResult))
truncatedEntry := connectionService.Requests[truncatedStart.RequestId]
truncatedEntry.Request := {
    Status: 200,
    ResponseText: '{"choices":[{"finish_reason":"length","message":{"content":"partial"}}]}',
    WaitForResponse: (*) => true
}
connectionService.PollRequest(truncatedStart.RequestId)
AssertAi(truncatedResult.Called && !truncatedResult.Ok
        && InStr(truncatedResult.Message, "输出长度上限") != 0,
    "The asynchronous response path accepted a truncated model output.")

embeddedFailureResult := {Called: false}
embeddedFailureStart := connectionService.TestConnection({
    AIAddress: "https://api.minimaxi.com/v1/chat/completions",
    AIKey: "invalid-key",
    AIModel: "MiniMax-demo",
    AITimeoutS: 12
}, CaptureAiConnectionResult.Bind(embeddedFailureResult))
embeddedFailureEntry := connectionService.Requests[
    embeddedFailureStart.RequestId]
embeddedFailureEntry.Request := {
    Status: 200,
    ResponseText: '{"base_resp":{"status_code":1008,"status_msg":"invalid api key"}}',
    WaitForResponse: (*) => true
}
connectionService.PollRequest(embeddedFailureStart.RequestId)
AssertAi(embeddedFailureResult.Called && !embeddedFailureResult.Ok
        && InStr(embeddedFailureResult.Message, "API 密钥：MiniMax") == 1
        && InStr(embeddedFailureResult.Message, "HTTP 200；业务错误码 1008")
            != 0,
    "An HTTP-200 provider business error was treated as a valid response.")
timeoutResult := {Called: false}
timeoutStart := connectionService.TestConnection({
    AIAddress: "https://api.openai.com/v1",
    AIKey: "secret",
    AIModel: "demo",
    AITimeoutS: 1
}, CaptureAiConnectionResult.Bind(timeoutResult))
AssertAi(timeoutStart.Ok, "The timeout connection probe did not start.")
timeoutEntry := connectionService.Requests[timeoutStart.RequestId]
timeoutEntry.Request := {
    WaitForResponse: (*) => false,
    Abort: (*) => true
}
timeoutEntry.StartedAt := A_TickCount - 1001
connectionService.PollRequest(timeoutStart.RequestId)
AssertAi(timeoutResult.Called && !timeoutResult.Ok
        && timeoutResult.Message
            == "请求超时：OpenAI 未在设定时限内完成连接测试。"
        && !connectionService.Requests.Has(timeoutStart.RequestId),
    "Polling did not terminate and clean up a timed-out AI request.")

settingsPath := A_Temp "\kmra-ai-prompt-settings-" A_TickCount "-"
    . Format("{:08X}", Random(0, 0xFFFFFFFF)) ".ini"
try {
    settingsService := AppSettingsService(settingsPath)
    promptSettings := settingsService.Load()
    promptSettings.AIPrompt := "generate line 1`r`ngenerate=line 2\\literal"
    promptSettings.AIOptimizePrompt :=
        "optimize line 1`noptimize=line 2\\literal"
    promptSettings.AISystemPrompt := "system line 1`nsystem=line 2\\literal"
    settingsService.Save(promptSettings)
    promptSnapshot := settingsService.GetSnapshot()
    reloadedPrompts := AppSettingsService(settingsPath).Load()
    AssertAi(reloadedPrompts.AIPrompt == promptSettings.AIPrompt
            && reloadedPrompts.AIOptimizePrompt
                == promptSettings.AIOptimizePrompt
            && reloadedPrompts.AISystemPrompt
                == promptSettings.AISystemPrompt
            && InStr(promptSnapshot, "PromptEscaped=")
            && InStr(promptSnapshot, "OptimizePromptEscaped=")
            && !InStr(promptSnapshot, "`nPrompt="),
        "Multiline AI prompts did not survive a settings restart.")
    settingsService.WriteSnapshot("[AI]`r`n"
        . "Prompt=legacy=generate\\literal`r`n"
        . "OptimizePrompt=legacy=optimize\\literal`r`n")
    legacyPrompts := AppSettingsService(settingsPath).Load()
    AssertAi(legacyPrompts.AIPrompt == "legacy=generate\\literal"
            && legacyPrompts.AIOptimizePrompt
                == "legacy=optimize\\literal",
        "Legacy AI prompt settings no longer load.")
    settingsService.WriteSnapshot("[AI]`r`n"
        . "PromptEscaped=" settingsService.EncodeMultilineValue(
            previousGeneratePrompt) "`r`n"
        . "OptimizePromptEscaped=" settingsService.EncodeMultilineValue(
            legacyOptimizePrompt) "`r`n"
        . "SystemPromptEscaped=" settingsService.EncodeMultilineValue(
            legacySystemPrompt) "`r`n")
    upgradedPersistedPrompts := AppSettingsService(settingsPath).Load()
    AssertAi(upgradedPersistedPrompts.AIPrompt
                == AIService.DefaultGeneratePrompt
            && upgradedPersistedPrompts.AIOptimizePrompt
                == AIService.DefaultOptimizePrompt
            && upgradedPersistedPrompts.AISystemPrompt
                == AIService.DefaultSystemPrompt,
        "Loading settings did not upgrade the obsolete bundled AI prompts.")
} finally {
    if FileExist(settingsPath)
        FileDelete(settingsPath)
}
ExitApp(0)
