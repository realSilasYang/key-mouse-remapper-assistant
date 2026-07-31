class CleanupCollector {
    __New(context) {
        this.Context := String(context)
        this.Failures := []
    }

    Run(label, callback) {
        try {
            callback.Call()
            return true
        } catch as cleanupError {
            this.Failures.Push(String(label) "：" cleanupError.Message)
            return false
        }
    }

    Complete() {
        if !this.Failures.Length
            return true
        message := ""
        for failure in this.Failures
            message .= (message == "" ? "" : "；") failure
        throw Error(this.Context "清理失败：" message)
    }
}
