class OutputLedger {
    __New(stateCallback := "") {
        this.Keys := Map()
        this.StateCallback := IsObject(stateCallback) ? stateCallback : ""
    }

    Press(keyName, owner, sendCallback) {
        keyName := String(keyName)
        owner := String(owner)
        normalized := StrLower(keyName)
        if normalized == "" || owner == "" || !IsObject(sendCallback)
            throw ValueError("输出按键账本需要按键、所有者和发送回调。")
        if !this.Keys.Has(normalized)
            this.Keys[normalized] := {Name: keyName, Owners: Map()}
        entry := this.Keys[normalized]
        if entry.Owners.Has(owner)
            return false
        entry.Owners[owner] := true
        try this.Persist()
        catch as persistError {
            entry.Owners.Delete(owner)
            if !entry.Owners.Count
                this.Keys.Delete(normalized)
            throw persistError
        }
        if entry.Owners.Count == 1 {
            try sendCallback.Call(keyName, "down")
            catch as sendError {
                entry.Owners.Delete(owner)
                if !entry.Owners.Count
                    this.Keys.Delete(normalized)
                try this.Persist()
                throw sendError
            }
        }
        return true
    }

    Release(keyName, owner, sendCallback) {
        normalized := StrLower(String(keyName))
        if !this.Keys.Has(normalized)
            return false
        if !IsObject(sendCallback)
            throw ValueError("输出按键账本需要有效的发送回调。")
        entry := this.Keys[normalized]
        owner := String(owner)
        if owner != "" && !entry.Owners.Has(owner)
            return false
        if owner != "" && entry.Owners.Count > 1 {
            entry.Owners.Delete(owner)
            return true
        }
        sendCallback.Call(entry.Name, "up")
        this.Keys.Delete(normalized)
        this.Persist()
        return true
    }

    HasOwner(keyName, owner) {
        normalized := StrLower(String(keyName))
        return this.Keys.Has(normalized)
            && this.Keys[normalized].Owners.Has(String(owner))
    }

    ReleaseOwner(owner, sendCallback) {
        owner := String(owner)
        keys := []
        for normalized, entry in this.Keys {
            if entry.Owners.Has(owner)
                keys.Push(entry.Name)
        }
        for keyName in keys
            this.Release(keyName, owner, sendCallback)
        return keys.Length
    }

    ReleaseOwnerPrefix(prefix, sendCallback) {
        prefix := String(prefix)
        if prefix == ""
            return 0
        releases := []
        for normalized, entry in this.Keys {
            for owner in entry.Owners {
                if SubStr(owner, 1, StrLen(prefix)) == prefix
                    releases.Push({Key: entry.Name, Owner: owner})
            }
        }
        for release in releases
            this.Release(release.Key, release.Owner, sendCallback)
        return releases.Length
    }

    ReleaseAll(sendCallback) {
        if !IsObject(sendCallback)
            throw ValueError("输出按键账本需要有效的发送回调。")
        keys := []
        for normalized, entry in this.Keys
            keys.Push(entry.Name)
        released := 0
        failures := []
        for keyName in keys {
            try {
                sendCallback.Call(keyName, "up")
                this.Keys.Delete(StrLower(keyName))
                this.Persist()
                released++
            } catch as releaseError {
                failures.Push(keyName ": " releaseError.Message)
            }
        }
        if failures.Length
            throw Error("部分输出按键无法释放：" this.Join(failures, "；"))
        return released
    }

    Persist() {
        if !IsObject(this.StateCallback)
            return true
        keyNames := []
        for normalized, entry in this.Keys
            keyNames.Push(entry.Name)
        return this.StateCallback.Call(keyNames)
    }

    Join(values, separator) {
        result := ""
        for index, value in values
            result .= (index > 1 ? separator : "") String(value)
        return result
    }
}
