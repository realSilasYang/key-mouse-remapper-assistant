class EventTraceService {
    static DefaultCapacity := 1000
    static MaximumCapacity := 10000
    static MaximumTextLength := 4096
    static MaximumEntryTextCharacters := 16 * 1024
    static MaximumDepth := 12
    static MaximumDataItems := 512

    __New(capacity := EventTraceService.DefaultCapacity) {
        this.Capacity := this.NormalizeCapacity(capacity)
        this.Buffer := []
        this.StartIndex := 1
        this.Count := 0
        this.NextSequence := 1
        this.Subscribers := Map()
        this.NextSubscriptionId := 1
        this.DroppedCount := 0
    }

    Record(category, eventName, fields := "") {
        entry := this.NormalizeEntry(category, eventName, fields)
        if this.Count < this.Capacity {
            this.Buffer.Push(entry)
            this.Count++
        } else {
            entry.EvictedSequence := this.Buffer[this.StartIndex].Sequence
            this.Buffer[this.StartIndex] := entry
            this.StartIndex := Mod(this.StartIndex, this.Capacity) + 1
            this.DroppedCount++
        }
        this.Publish(entry)
        return this.CloneEntry(entry)
    }

    NormalizeEntry(category, eventName, fields) {
        textCharacters := 0
        category := this.NormalizeRequiredText(category, "事件类别",
            &textCharacters)
        eventName := this.NormalizeRequiredText(eventName, "事件名称",
            &textCharacters)
        normalizedFields := this.NormalizeFields(fields, &textCharacters)
        sequence := this.NextSequence++
        return {
            Sequence: sequence,
            EvictedSequence: 0,
            Timestamp: FormatTime(A_NowUTC, "yyyy-MM-dd'T'HH:mm:ss")
                . "." Format("{:03}", A_MSec) "Z",
            Tick: A_TickCount,
            Category: category,
            Event: eventName,
            Source: normalizedFields.Source,
            RuleId: normalizedFields.RuleId,
            Outcome: normalizedFields.Outcome,
            Detail: normalizedFields.Detail,
            Data: normalizedFields.Data
        }
    }

    NormalizeFields(fields, &textCharacters) {
        result := {Source: "", RuleId: "", Outcome: "", Detail: "",
            Data: Map()}
        if fields == ""
            return result
        if !IsObject(fields)
            throw TypeError("事件字段必须是对象。")
        for propertyName in ["Source", "RuleId", "Outcome", "Detail"] {
            if fields.HasOwnProp(propertyName) {
                fieldText := this.LimitText(fields.%propertyName%)
                this.AddTextCharacters(fieldText, &textCharacters)
                result.%propertyName% := fieldText
            } else if Type(fields) == "Map" && fields.Has(propertyName) {
                fieldText := this.LimitText(fields[propertyName])
                this.AddTextCharacters(fieldText, &textCharacters)
                result.%propertyName% := fieldText
            }
        }
        if fields.HasOwnProp("Data")
            result.Data := this.CloneJsonValueWithBudget(fields.Data,
                &textCharacters)
        else if Type(fields) == "Map" && fields.Has("Data")
            result.Data := this.CloneJsonValueWithBudget(fields["Data"],
                &textCharacters)
        return result
    }

    Snapshot(category := "", minimumSequence := 0) {
        category := Trim(String(category))
        if Type(minimumSequence) != "Integer" || minimumSequence < 0
            throw ValueError("最小事件序号必须是非负整数。")
        result := []
        Loop this.Count {
            index := Mod(this.StartIndex - 2 + A_Index, this.Capacity) + 1
            entry := this.Buffer[index]
            if entry.Sequence < minimumSequence
                continue
            if category != "" && entry.Category != category
                continue
            result.Push(this.CloneEntry(entry))
        }
        return result
    }

    Clear() {
        clearedCount := this.Count
        this.Buffer := []
        this.StartIndex := 1
        this.Count := 0
        return clearedCount
    }

    SetCapacity(capacity) {
        capacity := this.NormalizeCapacity(capacity)
        if capacity == this.Capacity
            return false
        entries := this.Snapshot()
        removedCount := Max(0, entries.Length - capacity)
        if removedCount
            entries.RemoveAt(1, removedCount)
        this.Capacity := capacity
        this.Buffer := entries
        this.StartIndex := 1
        this.Count := entries.Length
        this.DroppedCount += removedCount
        return true
    }

    CaptureState() {
        return {
            Capacity: this.Capacity,
            Entries: this.Snapshot(),
            NextSequence: this.NextSequence,
            DroppedCount: this.DroppedCount
        }
    }

    RestoreState(state) {
        if !IsObject(state) || !state.HasOwnProp("Capacity")
                || !state.HasOwnProp("Entries")
                || !state.HasOwnProp("NextSequence")
                || !state.HasOwnProp("DroppedCount")
                || Type(state.Entries) != "Array"
            throw TypeError("事件缓冲区状态无效。")
        capacity := this.NormalizeCapacity(state.Capacity)
        if state.Entries.Length > capacity
            throw ValueError("事件缓冲区状态超过目标容量。")
        if Type(state.NextSequence) != "Integer" || state.NextSequence < 1
                || Type(state.DroppedCount) != "Integer"
                || state.DroppedCount < 0
            throw ValueError("事件缓冲区计数器状态无效。")
        restoredEntries := []
        previousSequence := 0
        for entry in state.Entries {
            normalizedEntry := this.NormalizeRestoredEntry(entry)
            if normalizedEntry.Sequence <= previousSequence
                throw ValueError("事件缓冲区状态序号没有严格递增。")
            previousSequence := normalizedEntry.Sequence
            restoredEntries.Push(normalizedEntry)
        }
        if state.NextSequence <= previousSequence
            throw ValueError("事件缓冲区下一序号没有领先于已有事件。")
        this.Capacity := capacity
        this.Buffer := restoredEntries
        this.StartIndex := 1
        this.Count := this.Buffer.Length
        this.NextSequence := state.NextSequence
        this.DroppedCount := state.DroppedCount
        return true
    }

    NormalizeCapacity(capacity) {
        if Type(capacity) != "Integer"
            throw TypeError("事件缓冲区容量必须是整数。")
        if capacity < 1 || capacity > EventTraceService.MaximumCapacity
            throw ValueError("事件缓冲区容量必须在 1 到 "
                EventTraceService.MaximumCapacity " 之间。")
        return capacity
    }

    NormalizeRestoredEntry(entry) {
        requiredFields := ["Sequence", "EvictedSequence", "Timestamp",
            "Tick", "Category", "Event", "Source", "RuleId", "Outcome",
            "Detail", "Data"]
        if !IsObject(entry)
            throw TypeError("事件缓冲区条目无效。")
        for fieldName in requiredFields {
            if !entry.HasOwnProp(fieldName)
                throw TypeError("事件缓冲区条目缺少字段：" fieldName)
        }
        if Type(entry.Sequence) != "Integer" || entry.Sequence < 1
                || Type(entry.EvictedSequence) != "Integer"
                || entry.EvictedSequence < 0
                || Type(entry.Tick) != "Integer" || entry.Tick < 0
            throw ValueError("事件缓冲区条目计数器无效。")
        if Type(entry.Timestamp) != "String"
                || !RegExMatch(entry.Timestamp,
                    "^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$")
            throw ValueError("事件缓冲区条目时间无效。")
        textCharacters := 0
        normalizedText := Map()
        for fieldName in ["Category", "Event", "Source", "RuleId",
                "Outcome", "Detail"] {
            value := entry.%fieldName%
            if Type(value) != "String"
                throw TypeError("事件缓冲区文本字段必须是字符串。")
            if StrLen(value) > EventTraceService.MaximumTextLength
                throw ValueError("事件缓冲区文本字段超过上限。")
            if (fieldName == "Category" || fieldName == "Event")
                    && Trim(value) == ""
                throw ValueError("事件缓冲区类别和名称不能为空。")
            this.AddTextCharacters(value, &textCharacters)
            normalizedText[fieldName] := value
        }
        normalizedData := this.CloneJsonValueWithBudget(entry.Data,
            &textCharacters)
        return {
            Sequence: entry.Sequence,
            EvictedSequence: entry.EvictedSequence,
            Timestamp: entry.Timestamp,
            Tick: entry.Tick,
            Category: normalizedText["Category"],
            Event: normalizedText["Event"],
            Source: normalizedText["Source"],
            RuleId: normalizedText["RuleId"],
            Outcome: normalizedText["Outcome"],
            Detail: normalizedText["Detail"],
            Data: normalizedData
        }
    }

    Subscribe(callback) {
        if !IsObject(callback)
            throw TypeError("事件订阅回调无效。")
        subscriptionId := this.NextSubscriptionId++
        this.Subscribers[subscriptionId] := callback
        return subscriptionId
    }

    Unsubscribe(subscriptionId) {
        if !this.Subscribers.Has(subscriptionId)
            return false
        this.Subscribers.Delete(subscriptionId)
        return true
    }

    Publish(entry) {
        pending := []
        for subscriptionId, callback in this.Subscribers
            pending.Push({Id: subscriptionId, Callback: callback})
        staleSubscriptions := []
        for pendingSubscription in pending {
            if !this.Subscribers.Has(pendingSubscription.Id)
                continue
            try pendingSubscription.Callback.Call(this.CloneEntry(entry))
            catch
                staleSubscriptions.Push(pendingSubscription.Id)
        }
        for subscriptionId in staleSubscriptions
            if this.Subscribers.Has(subscriptionId)
                this.Subscribers.Delete(subscriptionId)
    }

    ExportJsonLines(filePath, category := "") {
        filePath := CrossProcessWriteLock.NormalizePath(filePath)
        directory := ""
        SplitPath(filePath, , &directory)
        if directory != "" && !DirExist(directory)
            DirCreate(directory)
        writeLease := CrossProcessWriteLock.Acquire(filePath)
        temporaryPath := filePath ".tmp-" A_TickCount "-"
            . Format("{:08X}", Random(0, 0xFFFFFFFF))
        output := ""
        try {
            output := FileOpen(temporaryPath, "w", "UTF-8-RAW")
            if !IsObject(output)
                throw Error("无法创建事件导出文件。")
            for entry in this.Snapshot(category)
                output.Write(JsonCodec.Stringify(this.EntryToMap(entry),
                    false, true) "`n")
            output.Close()
            output := ""
            FileMove(temporaryPath, filePath, 1)
        } catch as exportError {
            if IsObject(output)
                try output.Close()
            if FileExist(temporaryPath)
                try FileDelete(temporaryPath)
            throw exportError
        } finally writeLease.Release()
        return filePath
    }

    EntryToMap(entry) {
        return Map(
            "sequence", entry.Sequence,
            "timestamp", entry.Timestamp,
            "tick", entry.Tick,
            "category", entry.Category,
            "event", entry.Event,
            "source", entry.Source,
            "rule_id", entry.RuleId,
            "outcome", entry.Outcome,
            "detail", entry.Detail,
            "data", this.CloneJsonValue(entry.Data))
    }

    CloneEntry(entry) {
        return {
            Sequence: entry.Sequence,
            EvictedSequence: entry.HasOwnProp("EvictedSequence")
                ? entry.EvictedSequence : 0,
            Timestamp: entry.Timestamp,
            Tick: entry.Tick,
            Category: entry.Category,
            Event: entry.Event,
            Source: entry.Source,
            RuleId: entry.RuleId,
            Outcome: entry.Outcome,
            Detail: entry.Detail,
            Data: this.CloneJsonValue(entry.Data)
        }
    }

    NormalizeRequiredText(value, label, &textCharacters) {
        text := Trim(this.LimitText(value))
        if text == ""
            throw ValueError(label "不能为空。")
        this.AddTextCharacters(text, &textCharacters)
        return text
    }

    AddTextCharacters(text, &textCharacters) {
        textCharacters += StrLen(text)
        if textCharacters > EventTraceService.MaximumEntryTextCharacters
            throw ValueError("单个事件文本总量超过上限。")
    }

    LimitText(value) {
        if IsObject(value)
            throw TypeError("事件文本字段不能是对象。")
        text := String(value)
        if StrLen(text) > EventTraceService.MaximumTextLength
            text := SubStr(text, 1,
                EventTraceService.MaximumTextLength - 1) "…"
        return text
    }

    CloneJsonValue(value) {
        textCharacters := 0
        return this.CloneJsonValueWithBudget(value, &textCharacters)
    }

    CloneJsonValueWithBudget(value, &textCharacters) {
        itemCount := 0
        return this.CloneJsonValueNode(value, 0, &itemCount,
            &textCharacters)
    }

    CloneJsonValueNode(value, depth, &itemCount, &textCharacters) {
        if depth > EventTraceService.MaximumDepth
            throw ValueError("事件数据嵌套层级过深。")
        itemCount++
        if itemCount > EventTraceService.MaximumDataItems
            throw ValueError("事件数据元素数量超过上限。")
        valueType := Type(value)
        if valueType == "Map" {
            result := Map()
            for key, item in value {
                normalizedKey := this.LimitText(key)
                this.AddTextCharacters(normalizedKey, &textCharacters)
                result[normalizedKey] := this.CloneJsonValueNode(item,
                    depth + 1, &itemCount, &textCharacters)
            }
            return result
        }
        if valueType == "Array" {
            result := []
            for item in value
                result.Push(this.CloneJsonValueNode(item, depth + 1,
                    &itemCount, &textCharacters))
            return result
        }
        if value is JsonBoolean
            return JsonBoolean(value.Value)
        if value is JsonNull
            return JsonNull()
        if IsObject(value)
            throw TypeError("事件数据只能包含 JSON 兼容值。")
        if valueType == "String" {
            normalizedText := this.LimitText(value)
            this.AddTextCharacters(normalizedText, &textCharacters)
            return normalizedText
        }
        if valueType == "Float" && (value != value
                || Abs(value) > 1.7976931348623157e308)
            throw ValueError("事件数据不支持非有限数字。")
        if valueType != "Integer" && valueType != "Float"
            throw TypeError("事件数据只能包含 JSON 兼容值。")
        return value
    }
}
