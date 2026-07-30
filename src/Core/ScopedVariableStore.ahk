class ScopedVariableStore {
    static Schema := 1
    static MaximumFileBytes := 512 * 1024
    static MaximumVariablesPerScope := 512

    __New(filePath := "") {
        filePath := Trim(String(filePath))
        this.FilePath := filePath == ""
            ? "" : CrossProcessWriteLock.NormalizePath(filePath)
        this.TransientValues := Map("layer", "default")
        this.PersistentValues := Map()
        this.LoadWarning := ""
        if this.FilePath != ""
            this.Load()
    }

    Load() {
        if this.FilePath == ""
            return this.LoadLocked()
        readLease := CrossProcessWriteLock.Acquire(this.FilePath)
        try return this.LoadLocked()
        finally readLease.Release()
    }

    LoadLocked() {
        this.LoadWarning := ""
        this.PersistentValues := Map()
        if this.FilePath == "" || !FileExist(this.FilePath)
            return this.GetPersistentSnapshot()
        try {
            document := JsonCodec.Parse(BoundedFileReader.ReadUtf8(
                this.FilePath, ScopedVariableStore.MaximumFileBytes,
                ScopedVariableStore.MaximumFileBytes, "持久变量文件"))
            if Type(document) != "Map" || document.Count != 2
                    || !document.Has("schema")
                    || Type(document["schema"]) != "Integer"
                    || document["schema"] != ScopedVariableStore.Schema
                    || !document.Has("values")
                    || Type(document["values"]) != "Map"
                throw Error("持久变量文件格式无效。")
            this.PersistentValues := this.NormalizeValues(document["values"])
        } catch as loadError {
            this.LoadWarning := loadError.Message
            this.PersistentValues := Map()
        }
        return this.GetPersistentSnapshot()
    }

    Set(name, value, scope := "transient") {
        name := this.NormalizeName(name)
        scope := this.NormalizeWritableScope(scope)
        normalizedValue := this.NormalizeValue(value)
        if scope == "persistent"
            return this.SetPersistent(name, normalizedValue)
        target := this.GetWritableScope(scope)
        if !target.Has(name)
                && target.Count >= ScopedVariableStore.MaximumVariablesPerScope
            throw Error("变量作用域条目数量超过上限。")
        target[name] := normalizedValue
        return RuleSpec.Clone(target[name])
    }

    Clear(name, scope := "transient") {
        name := this.NormalizeName(name)
        scope := this.NormalizeWritableScope(scope)
        if scope == "persistent"
            return this.ClearPersistent(name)
        target := this.GetWritableScope(scope)
        if !IsObject(target) || !target.Has(name)
            return false
        target.Delete(name)
        return true
    }

    ClearScope(scope) {
        scope := this.NormalizeWritableScope(scope)
        if scope == "transient"
            this.TransientValues := Map("layer", "default")
        else
            return this.ClearPersistentScope()
        return true
    }

    SetPersistent(name, normalizedValue) {
        writeLease := CrossProcessWriteLock.Acquire(this.FilePath)
        try {
            this.LoadLocked()
            this.EnsureLoadedForMutation()
            if !this.PersistentValues.Has(name)
                    && this.PersistentValues.Count
                        >= ScopedVariableStore.MaximumVariablesPerScope
                throw Error("变量作用域条目数量超过上限。")
            beforeValues := RuleSpec.Clone(this.PersistentValues)
            this.PersistentValues[name] := RuleSpec.Clone(normalizedValue)
            try this.SavePersistentLocked()
            catch as persistError {
                this.PersistentValues := beforeValues
                throw persistError
            }
            return RuleSpec.Clone(this.PersistentValues[name])
        } finally writeLease.Release()
    }

    ClearPersistent(name) {
        writeLease := CrossProcessWriteLock.Acquire(this.FilePath)
        try {
            this.LoadLocked()
            this.EnsureLoadedForMutation()
            if !this.PersistentValues.Has(name)
                return false
            beforeValues := RuleSpec.Clone(this.PersistentValues)
            this.PersistentValues.Delete(name)
            try this.SavePersistentLocked()
            catch as persistError {
                this.PersistentValues := beforeValues
                throw persistError
            }
            return true
        } finally writeLease.Release()
    }

    ClearPersistentScope() {
        writeLease := CrossProcessWriteLock.Acquire(this.FilePath)
        try {
            this.LoadLocked()
            this.EnsureLoadedForMutation()
            beforeValues := RuleSpec.Clone(this.PersistentValues)
            this.PersistentValues := Map()
            try this.SavePersistentLocked()
            catch as persistError {
                this.PersistentValues := beforeValues
                throw persistError
            }
            return true
        } finally writeLease.Release()
    }

    BuildContext(builtins := "") {
        builtinValues := Type(builtins) == "Map"
            ? RuleSpec.Clone(builtins) : Map()
        flat := Map()
        for name, value in this.PersistentValues
            flat[name] := RuleSpec.Clone(value)
        for name, value in this.TransientValues
            flat[name] := RuleSpec.Clone(value)
        scopes := Map(
            "transient", RuleSpec.Clone(this.TransientValues),
            "persistent", RuleSpec.Clone(this.PersistentValues),
            "builtin", builtinValues)
        flat["_scopes"] := scopes
        for scopeName, values in scopes {
            for name, value in values
                flat[scopeName "." name] := RuleSpec.Clone(value)
        }
        return flat
    }

    GetSnapshot(builtins := "") {
        context := this.BuildContext(builtins)
        return RuleSpec.Clone(context["_scopes"])
    }

    GetPersistentSnapshot() => RuleSpec.Clone(this.PersistentValues)

    GetWritableScope(scope) {
        if scope == "transient"
            return this.TransientValues
        if scope == "persistent"
            return this.PersistentValues
        throw ValueError("未知变量作用域：" scope)
    }

    NormalizeWritableScope(scope) {
        scope := StrLower(Trim(String(scope)))
        if scope != "transient" && scope != "persistent"
            throw ValueError("变量作用域必须是 transient 或 persistent。")
        return scope
    }

    NormalizeName(name) {
        name := Trim(String(name))
        if !RegExMatch(name, "^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$")
            throw ValueError("变量名称格式无效。")
        if SubStr(StrLower(name), 1, 8) == "builtin."
            throw Error("builtin 变量只读。")
        return name
    }

    NormalizeValues(values) {
        if Type(values) != "Map"
            throw TypeError("变量集合必须是对象。")
        if values.Count > ScopedVariableStore.MaximumVariablesPerScope
            throw Error("变量作用域条目数量超过上限。")
        result := Map()
        for name, value in values
            result[this.NormalizeName(name)] := this.NormalizeValue(value)
        return result
    }

    NormalizeValue(value) {
        cloned := RuleSpec.Clone(value)
        ; JSON 往返同时拒绝任意 AHK 对象并限制为稳定数据类型。
        return JsonCodec.Parse(JsonCodec.Stringify(cloned, false, true))
    }

    SavePersistentLocked() {
        document := Map("schema", ScopedVariableStore.Schema,
                "values", RuleSpec.Clone(this.PersistentValues))
        text := JsonCodec.Stringify(document, true, true) "`r`n"
        if StrPut(text, "UTF-8") - 1
                > ScopedVariableStore.MaximumFileBytes
            throw Error("持久变量文件超过大小上限。")
        directory := ""
        SplitPath(this.FilePath, , &directory)
        if directory != "" && !DirExist(directory)
            DirCreate(directory)
        temporaryPath := this.FilePath ".tmp-" A_TickCount "-"
            . Format("{:08X}", Random(0, 0xFFFFFFFF))
        output := ""
        try {
            output := FileOpen(temporaryPath, "w", "UTF-8-RAW")
            if !IsObject(output)
                throw Error("无法写入持久变量文件。")
            output.Write(text)
            output.Close()
            output := ""
            FileMove(temporaryPath, this.FilePath, 1)
        } catch as saveError {
            if IsObject(output)
                try output.Close()
            if FileExist(temporaryPath)
                try FileDelete(temporaryPath)
            throw saveError
        }
        return true
    }

    EnsureLoadedForMutation() {
        if this.LoadWarning != ""
            throw Error("持久变量文件无法安全修改：" this.LoadWarning)
        return true
    }
}
