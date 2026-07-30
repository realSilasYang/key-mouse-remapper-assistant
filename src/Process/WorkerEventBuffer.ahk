class WorkerEventBuffer {
    __New(maximumEvents := 2048) {
        if Type(maximumEvents) != "Integer" || maximumEvents < 1
            throw ValueError("工作进程事件缓冲区上限必须是正整数。")
        this.MaximumEvents := maximumEvents
        this.Items := []
        this.Head := 1
        this.MoveItems := Map()
        this.DroppedCount := 0
        this.CoalescedCount := 0
    }

    Length => Max(0, this.Items.Length - this.Head + 1)

    Push(payload, moveKey := "", priority := false) {
        moveKey := String(moveKey)
        if moveKey != "" && this.MoveItems.Has(moveKey) {
            item := this.MoveItems[moveKey]
            item.Payload := payload
            this.CoalescedCount++
            return true
        }
        if this.Length >= this.MaximumEvents
                && !this.MakeRoom(!!priority) {
            this.DroppedCount++
            return false
        }
        item := {
            Payload: payload,
            MoveKey: moveKey,
            Priority: !!priority
        }
        this.Items.Push(item)
        if moveKey != ""
            this.MoveItems[moveKey] := item
        return true
    }

    Peek() {
        return this.Length ? this.Items[this.Head] : ""
    }

    RemoveFirst() {
        if !this.Length
            return ""
        item := this.Items[this.Head]
        this.ForgetMoveItem(item)
        this.Items[this.Head] := ""
        this.Head++
        this.CompactIfNeeded()
        return item
    }

    RemoveAt(index) {
        if Type(index) != "Integer" || index < 1 || index > this.Length
            throw IndexError("事件缓冲区索引越界。")
        physicalIndex := this.Head + index - 1
        item := this.Items.RemoveAt(physicalIndex)
        this.ForgetMoveItem(item)
        return item
    }

    ForgetMoveItem(item) {
        if item.MoveKey != "" && this.MoveItems.Has(item.MoveKey)
                && ObjPtr(this.MoveItems[item.MoveKey]) == ObjPtr(item)
            this.MoveItems.Delete(item.MoveKey)
    }

    MakeRoom(incomingPriority) {
        candidate := 0
        Loop this.Length {
            index := A_Index
            item := this.Items[this.Head + index - 1]
            if item.MoveKey != "" {
                candidate := index
                break
            }
            if !candidate && !item.Priority
                candidate := index
        }
        if !candidate {
            if !incomingPriority
                return false
            candidate := 1
        }
        this.RemoveAt(candidate)
        this.DroppedCount++
        return true
    }

    Clear() {
        this.Items := []
        this.Head := 1
        this.MoveItems := Map()
    }

    CompactIfNeeded() {
        if this.Head == 1
            return
        if !this.Length {
            this.Items := []
            this.Head := 1
            return
        }
        if this.Head <= 256 || this.Head <= this.Items.Length // 2
            return
        this.Items.RemoveAt(1, this.Head - 1)
        this.Head := 1
    }

    GetHealth() {
        return Map(
            "queued", this.Length,
            "maximum", this.MaximumEvents,
            "dropped", this.DroppedCount,
            "coalesced", this.CoalescedCount)
    }
}
