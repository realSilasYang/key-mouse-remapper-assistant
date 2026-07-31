class RuleScheduler {
    __New(clockCallback := "", armCallback := "") {
        this.ClockCallback := IsObject(clockCallback)
            ? clockCallback
            : (() => DllCall("kernel32\GetTickCount64", "UInt64"))
        this.ArmCallback := IsObject(armCallback) ? armCallback : ""
        this.Entries := Map()
        this.WakeCallback := ObjBindMethod(this, "OnWake")
        this.Armed := false
        this.LastRawClock := ""
        this.ClockEpoch := 0
    }

    Schedule(id, delayMs, callback) {
        id := String(id)
        if Type(delayMs) != "Integer" || delayMs < 0
                || id == "" || !IsObject(callback)
            throw ValueError("调度任务需要编号、非负延迟和回调。")
        hadPrevious := this.Entries.Has(id)
        previous := hadPrevious ? this.Entries[id] : ""
        this.Entries[id] := {Id: id,
            Deadline: this.ReadClock() + delayMs,
            Callback: callback}
        try this.ArmNext()
        catch as armError {
            if hadPrevious
                this.Entries[id] := previous
            else
                this.Entries.Delete(id)
            try this.ArmNext()
            throw armError
        }
        return id
    }

    Cancel(id) {
        id := String(id)
        if !this.Entries.Has(id)
            return false
        this.Entries.Delete(id)
        this.ArmNext()
        return true
    }

    CancelPrefix(prefix) {
        prefix := String(prefix)
        ids := []
        for id in this.Entries {
            if SubStr(id, 1, StrLen(prefix)) == prefix
                ids.Push(id)
        }
        for id in ids
            this.Entries.Delete(id)
        if ids.Length
            this.ArmNext()
        return ids.Length
    }

    CancelAll() {
        count := this.Entries.Count
        this.Entries.Clear()
        this.Disarm()
        return count
    }

    RunDue(now := "") {
        now := now == "" ? this.ReadClock() : Integer(now)
        if now < 0
            throw ValueError("调度器时钟不能为负数。")
        due := []
        for id, entry in this.Entries {
            if entry.Deadline <= now
                due.Push(entry)
        }
        this.SortEntries(due)
        executed := 0
        try {
            for entry in due {
                if !this.Entries.Has(entry.Id)
                        || this.Entries[entry.Id] != entry
                    continue
                this.Entries.Delete(entry.Id)
                executed++
                entry.Callback.Call(entry.Id)
            }
        } finally this.ArmNext()
        return executed
    }

    OnWake(*) {
        this.Armed := false
        this.RunDue()
    }

    ArmNext() {
        if !this.Entries.Count {
            this.Disarm()
            return false
        }
        earliest := ""
        for id, entry in this.Entries {
            if !IsObject(earliest) || entry.Deadline < earliest.Deadline
                earliest := entry
        }
        delayMs := Max(1, earliest.Deadline - this.ReadClock())
        wasArmed := this.Armed
        try {
            if IsObject(this.ArmCallback)
                this.ArmCallback.Call(delayMs)
            else
                SetTimer(this.WakeCallback, -delayMs)
        } catch as armError {
            this.Armed := wasArmed
            throw armError
        }
        this.Armed := true
        return true
    }

    Disarm() {
        if !this.Armed
            return false
        if IsObject(this.ArmCallback)
            this.ArmCallback.Call(0)
        else
            SetTimer(this.WakeCallback, 0)
        this.Armed := false
        return true
    }

    SortEntries(entries) {
        if entries.Length < 2
            return entries
        source := entries.Clone()
        width := 1
        while width < source.Length {
            merged := []
            blockStart := 1
            while blockStart <= source.Length {
                left := blockStart
                leftEnd := Min(blockStart + width - 1, source.Length)
                right := leftEnd + 1
                rightEnd := Min(blockStart + width * 2 - 1, source.Length)
                while left <= leftEnd || right <= rightEnd {
                    if right > rightEnd || (left <= leftEnd
                            && this.EntryComesFirst(source[left],
                                source[right])) {
                        merged.Push(source[left])
                        left++
                    } else {
                        merged.Push(source[right])
                        right++
                    }
                }
                blockStart += width * 2
            }
            source := merged
            width *= 2
        }
        for index, entry in source
            entries[index] := entry
        return entries
    }

    EntryComesFirst(left, right) {
        return left.Deadline < right.Deadline
            || (left.Deadline == right.Deadline
                && StrCompare(left.Id, right.Id, true) <= 0)
    }

    ReadClock(rawValue := "") {
        raw := Integer(rawValue == "" ? this.ClockCallback.Call() : rawValue)
        if raw < 0
            throw ValueError("调度器时钟不能为负数。")
        if this.LastRawClock == "" {
            this.LastRawClock := raw
            return raw
        }
        if raw < this.LastRawClock {
            if raw <= 0xFFFFFFFF && this.LastRawClock <= 0xFFFFFFFF
                    && this.LastRawClock - raw > 0x80000000
                this.ClockEpoch += 0x100000000
            else
                throw Error("调度器时钟发生非回绕倒退。")
        }
        this.LastRawClock := raw
        return this.ClockEpoch + raw
    }

    Shutdown() => this.CancelAll()
}
