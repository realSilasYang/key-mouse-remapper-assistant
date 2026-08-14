; 重映射代码区域的事务撤销与重做历史。

class MappingHistoryService {
    static DefaultMaximumCharacters := 32 * 1024 * 1024

    __New(maxEntries := 20,
            maxCharacters := MappingHistoryService.DefaultMaximumCharacters) {
        this.MaxEntries := maxEntries > 0 ? Floor(maxEntries) : 20
        this.MaxCharacters := maxCharacters > 0
            ? Floor(maxCharacters)
            : MappingHistoryService.DefaultMaximumCharacters
        this.UndoEntries := []
        this.RedoEntries := []
        this.TotalCharacters := 0
        this.Busy := false
    }

    Commit(beforeState, afterState, action := "") {
        if this.Busy
            return false
        beforeState := String(beforeState)
        afterState := String(afterState)
        if beforeState == afterState
            return false
        this.ClearEntries(this.RedoEntries)
        entry := {Before: beforeState, After: afterState,
            Action: IsObject(action) ? action : {Kind: "mapping"},
            Characters: StrLen(beforeState) + StrLen(afterState)}
        this.UndoEntries.Push(entry)
        this.TotalCharacters += entry.Characters
        while this.UndoEntries.Length > this.MaxEntries
                || (this.TotalCharacters > this.MaxCharacters
                    && this.UndoEntries.Length > 1)
            this.RemoveOldestUndoEntry()
        return true
    }

    RemoveOldestUndoEntry() {
        if !this.UndoEntries.Length
            return false
        removed := this.UndoEntries.RemoveAt(1)
        this.TotalCharacters := Max(0,
            this.TotalCharacters - removed.Characters)
        return true
    }

    ClearEntries(entries) {
        for entry in entries
            this.TotalCharacters := Max(0,
                this.TotalCharacters - entry.Characters)
        entries.Length := 0
        return true
    }

    Undo(applyCallback, &appliedEntry := "") {
        return this.ApplyFrom(this.UndoEntries, this.RedoEntries, true,
            applyCallback, &appliedEntry)
    }

    Redo(applyCallback, &appliedEntry := "") {
        return this.ApplyFrom(this.RedoEntries, this.UndoEntries, false,
            applyCallback, &appliedEntry)
    }

    ApplyFrom(sourceEntries, targetEntries, undo, applyCallback,
            &appliedEntry) {
        appliedEntry := ""
        if this.Busy || !sourceEntries.Length || !IsObject(applyCallback)
            return false
        this.Busy := true
        try {
            entry := sourceEntries[sourceEntries.Length]
            if undo
                applyCallback.Call(entry.Before, entry.After)
            else
                applyCallback.Call(entry.After, entry.Before)
            sourceEntries.Pop()
            targetEntries.Push(entry)
            appliedEntry := entry
            return true
        } finally this.Busy := false
    }

    CanUndo() => !this.Busy && this.UndoEntries.Length > 0
    CanRedo() => !this.Busy && this.RedoEntries.Length > 0
    GetUndoCount() => this.UndoEntries.Length
    GetRedoCount() => this.RedoEntries.Length
    GetStoredCharacterCount() => this.TotalCharacters

    Clear() {
        if this.Busy
            return false
        this.UndoEntries := []
        this.RedoEntries := []
        this.TotalCharacters := 0
        return true
    }
}
