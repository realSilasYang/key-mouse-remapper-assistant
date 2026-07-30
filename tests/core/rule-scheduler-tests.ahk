#Requires AutoHotkey v2.0 64-bit
#Warn All, StdOut

#Include ..\TestSupport.ahk
#Include ..\..\src\Core\RuleScheduler.ahk
#Include ..\..\src\Core\OutputLedger.ahk

try {
    clock := SchedulerTestClock()
    armed := []
    scheduler := RuleScheduler(ObjBindMethod(clock, "Now"),
        (delay) => armed.Push(delay))
    events := []
    scheduler.Schedule("late", 20, (id) => events.Push(id))
    scheduler.Schedule("early", 10, (id) => events.Push(id))
    clock.Tick := 10
    AssertEqual(1, scheduler.RunDue(), "调度器没有执行到期任务")
    AssertEqual("early", events[1], "调度器没有按截止时间执行")
    clock.Tick := 20
    AssertEqual(1, scheduler.RunDue(), "调度器没有执行第二个到期任务")
    AssertEqual("late", events[2], "调度器第二个任务顺序错误")
    scheduler.Schedule("cancel-me", 50, (id) => events.Push(id))
    AssertTrue(scheduler.Cancel("cancel-me"), "调度器取消任务失败")
    clock.Tick := 100
    AssertEqual(0, scheduler.RunDue(), "已取消调度任务仍被执行")

    wrapClock := SchedulerTestClock()
    wrapClock.Tick := 0xFFFFFFFA
    wrapEvents := []
    wrapScheduler := RuleScheduler(ObjBindMethod(wrapClock, "Now"),
        (delay) => false)
    wrapScheduler.Schedule("after-wrap", 20,
        (id) => wrapEvents.Push(id))
    wrapClock.Tick := 5
    AssertEqual(0, wrapScheduler.RunDue(),
        "32 位时钟回绕后任务提前执行")
    wrapClock.Tick := 15
    AssertEqual(1, wrapScheduler.RunDue(),
        "32 位时钟回绕后到期任务没有执行")
    AssertEqual("after-wrap", wrapEvents[1],
        "回绕边界执行了错误的调度任务")

    cancellationClock := SchedulerTestClock()
    cancellationEvents := []
    cancellationScheduler := RuleScheduler(
        ObjBindMethod(cancellationClock, "Now"), (delay) => false)
    cancellationScheduler.Schedule("a", 10, (id) => (
        cancellationEvents.Push(id), cancellationScheduler.Cancel("b")))
    cancellationScheduler.Schedule("b", 10,
        (id) => cancellationEvents.Push(id))
    cancellationClock.Tick := 10
    AssertTrue(cancellationScheduler.RunDue() == 1
            && cancellationEvents.Length == 1
            && cancellationEvents[1] == "a",
        "调度器把回调取消的到期任务计入已执行数量")

    recoveryClock := SchedulerTestClock()
    recoveryArms := []
    recoveryScheduler := RuleScheduler(ObjBindMethod(recoveryClock, "Now"),
        (delay) => recoveryArms.Push(delay))
    recoveryScheduler.Schedule("throws", 10,
        (id) => SchedulerThrow(id))
    recoveryScheduler.Schedule("later", 20, (id) => true)
    recoveryClock.Tick := 10
    callbackFailed := false
    try recoveryScheduler.RunDue()
    catch
        callbackFailed := true
    AssertTrue(callbackFailed && recoveryScheduler.Armed
            && recoveryScheduler.Entries.Has("later")
            && recoveryArms[recoveryArms.Length] == 10,
        "到期回调失败后调度器没有重新武装剩余任务")

    failedArmScheduler := RuleScheduler(ObjBindMethod(recoveryClock, "Now"),
        (delay) => SchedulerThrow("arm"))
    armFailed := false
    try failedArmScheduler.Schedule("never-armed", 1, (id) => true)
    catch
        armFailed := true
    AssertTrue(armFailed && !failedArmScheduler.Armed,
        "调度器武装失败后仍报告计时器有效")
    AssertTrue(!failedArmScheduler.Entries.Has("never-armed"),
        "首次武装失败后残留了永远无法唤醒的任务")

    fractionalDelayRejected := false
    try scheduler.Schedule("fractional", 1.5, (id) => true)
    catch
        fractionalDelayRejected := true
    AssertTrue(fractionalDelayRejected
            && !scheduler.Entries.Has("fractional"),
        "调度器将小数延迟静默截断为整数")

    transientArm := FailingSchedulerArm()
    resilientClock := SchedulerTestClock()
    resilientScheduler := RuleScheduler(ObjBindMethod(resilientClock, "Now"),
        ObjBindMethod(transientArm, "Arm"))
    resilientScheduler.Schedule("existing", 20, (id) => true)
    transientArm.FailNext := true
    replacementFailed := false
    try resilientScheduler.Schedule("new", 10, (id) => true)
    catch
        replacementFailed := true
    AssertTrue(replacementFailed && resilientScheduler.Armed
            && resilientScheduler.Entries.Has("existing")
            && !resilientScheduler.Entries.Has("new"),
        "重新武装失败后丢失了旧任务或留下未承诺的新任务")

    ledger := OutputLedger()
    output := []
    sendCallback := (name, phase) => output.Push(name ":" phase)
    AssertTrue(ledger.Press("LShift", "owner-a", sendCallback),
        "输出账本首次按下没有登记")
    AssertTrue(ledger.Press("LShift", "owner-b", sendCallback),
        "同一物理输出键的第二个所有者没有登记")
    AssertEqual(1, output.Length, "输出账本重复发送了 down")
    AssertTrue(ledger.Release("LShift", "owner-a", sendCallback),
        "释放第一个输出所有者失败")
    AssertEqual(1, output.Length, "仍有所有者时错误发送 up")
    AssertTrue(ledger.Release("LShift", "owner-b", sendCallback),
        "释放最后一个输出所有者失败")
    AssertEqual("LShift:up", output[2], "最后所有者释放没有发送 up")
    ledger.Press("LCtrl", "owner-c", sendCallback)
    ledger.Press("RShift", "owner-c", sendCallback)
    AssertEqual(2, ledger.ReleaseOwner("owner-c", sendCallback),
        "按所有者释放输出键数量错误")
    AssertEqual(6, output.Length, "按所有者释放输出事件数量错误")
    WriteTestSuccess("rule-scheduler")
} catch as testError {
    FileAppend(testError.Message "`n" testError.Stack, "**")
    ExitApp(1)
}
ExitApp(0)

class SchedulerTestClock {
    __New() => this.Tick := 0
    Now() => this.Tick
}

class FailingSchedulerArm {
    __New() => this.FailNext := false

    Arm(delay) {
        if this.FailNext {
            this.FailNext := false
            throw Error("injected transient arm failure")
        }
        return delay
    }
}

SchedulerThrow(detail) {
    throw Error("injected scheduler failure: " detail)
}
