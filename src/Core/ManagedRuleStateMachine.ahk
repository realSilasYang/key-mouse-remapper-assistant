class ManagedRuleStateMachine {
    __New(executeCallback, traceCallback := "", clockCallback := "") {
        if !IsObject(executeCallback)
            throw TypeError("托管规则状态机缺少动作回调。")
        this.ExecuteCallback := executeCallback
        this.TraceCallback := traceCallback
        this.ClockCallback := IsObject(clockCallback)
            ? clockCallback : (() => A_TickCount)
        this.States := Map()
    }

    Begin(descriptor, triggerIdentity, stateId := "", scope := "global") {
        if stateId == ""
            stateId := descriptor.Id
        stateId := String(stateId)
        if this.States.Has(stateId)
            return false
        state := {
            StateId: stateId,
            Scope: String(scope),
            Descriptor: descriptor,
            Trigger: String(triggerIdentity),
            StartedAt: this.ClockCallback.Call(),
            Interrupted: false,
            OtherKeyFired: false,
            HeldFired: false,
            DelayedResolved: false
        }
        this.States[stateId] := state
        try this.ExecuteGroup(state, "to")
        catch as beginError {
            this.States.Delete(stateId)
            throw beginError
        }
        this.Trace("state_begin", state)
        return true
    }

    Interrupt(triggerIdentity, scope := "") {
        triggerIdentity := String(triggerIdentity)
        scope := String(scope)
        interruptedCount := 0
        for stateId, state in this.States {
            if scope != "" && state.Scope != scope
                continue
            if state.Trigger == triggerIdentity || state.Interrupted
                continue
            state.Interrupted := true
            if !state.OtherKeyFired {
                state.OtherKeyFired := true
                this.ExecuteGroup(state, "to_if_other_key_pressed")
            }
            interruptedCount++
            this.Trace("state_interrupted", state)
        }
        return interruptedCount
    }

    FireHeld(ruleId) {
        if !this.States.Has(ruleId)
            return false
        state := this.States[ruleId]
        if state.HeldFired
            return false
        state.HeldFired := true
        this.ExecuteGroup(state, "to_if_held_down")
        this.Trace("held_threshold", state)
        return true
    }

    ResolveDelayed(ruleId) {
        if !this.States.Has(ruleId)
            return false
        state := this.States[ruleId]
        if state.DelayedResolved
            return false
        state.DelayedResolved := true
        fieldName := state.Interrupted
            ? "to_delayed_if_canceled" : "to_delayed_if_invoked"
        this.ExecuteGroup(state, fieldName)
        this.Trace(state.Interrupted ? "delayed_canceled"
            : "delayed_invoked", state)
        return true
    }

    Release(ruleId) {
        if !this.States.Has(ruleId)
            return false
        state := this.States[ruleId]
        try {
            elapsed := this.Elapsed(state.StartedAt, this.ClockCallback.Call())
            timing := state.Descriptor.HasOwnProp("EffectiveTiming")
                ? state.Descriptor.EffectiveTiming
                : RuleTimingResolver.Resolve(
                    state.Descriptor.Spec["timing"]).Values
            if !state.Interrupted && !state.HeldFired
                    && elapsed <= timing["alone_timeout_ms"]
                this.ExecuteGroup(state, "to_if_alone")
            if !state.DelayedResolved
                    && state.Descriptor.Spec[
                        "to_delayed_if_canceled"].Length {
                state.DelayedResolved := true
                this.ExecuteGroup(state, "to_delayed_if_canceled")
                this.Trace("delayed_canceled", state)
            }
            this.ExecuteGroup(state, "to_after_key_up")
        } finally {
            this.States.Delete(ruleId)
            this.Trace("state_release", state)
        }
        return true
    }

    CancelAll() {
        count := this.States.Count
        this.States.Clear()
        return count
    }

    CancelScope(scope) {
        scope := String(scope)
        stateIds := []
        for stateId, state in this.States {
            if state.Scope == scope
                stateIds.Push(stateId)
        }
        for stateId in stateIds
            this.States.Delete(stateId)
        return stateIds
    }

    ExecuteGroup(state, fieldName) {
        actions := state.Descriptor.Spec[fieldName]
        if actions.Length
            this.ExecuteCallback.Call(actions, state.Descriptor, fieldName,
                false, state.StateId)
    }

    Trace(eventName, state) {
        if IsObject(this.TraceCallback)
            try this.TraceCallback.Call(eventName, state.Descriptor,
                state.Trigger)
    }

    Elapsed(startTick, endTick) {
        return endTick >= startTick ? endTick - startTick
            : (0x100000000 - startTick) + endTick
    }
}
