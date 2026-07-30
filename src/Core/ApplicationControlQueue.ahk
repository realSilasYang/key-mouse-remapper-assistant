class ApplicationControlQueue {
    static Schema := 1
    static MaximumFileBytes := 512 * 1024
    static MaximumRequests := 128

    __New(filePath) {
        filePath := Trim(String(filePath))
        if filePath == ""
            throw ValueError("应用控制队列路径不能为空。")
        this.FilePath := CrossProcessWriteLock.NormalizePath(filePath)
        this.LastRecoveryWarning := ""
    }

    Publish(command, scriptPath, data := "") {
        command := StrLower(Trim(String(command)))
        if command != "apply"
            throw ValueError("不支持的应用控制命令：" command)
        targetPath := CrossProcessWriteLock.NormalizePath(scriptPath)
        request := Map(
            "id", FormatTime(A_NowUTC, "yyyyMMddHHmmss") "-"
                . Format("{:08X}", Random(0, 0xFFFFFFFF)),
            "command", command,
            "script_path", targetPath,
            "created_at", FormatTime(A_NowUTC,
                "yyyy-MM-dd'T'HH:mm:ss'Z'"),
            "process_id", DllCall("kernel32\GetCurrentProcessId", "UInt"),
            "data", Type(data) == "Map" ? RuleSpec.Clone(data) : Map())
        writeLease := CrossProcessWriteLock.Acquire(this.FilePath)
        try {
            document := this.ReadDocument(true)
            requests := document["requests"]
            while requests.Length >= ApplicationControlQueue.MaximumRequests
                requests.RemoveAt(1)
            requests.Push(request)
            this.WriteDocument(document)
        } finally writeLease.Release()
        return RuleSpec.Clone(request)
    }

    ConsumeFor(scriptPath) {
        targetPath := CrossProcessWriteLock.NormalizePath(scriptPath)
        writeLease := CrossProcessWriteLock.Acquire(this.FilePath)
        try {
            document := this.ReadDocument(true)
            matched := []
            remaining := []
            for request in document["requests"] {
                if StrLower(request["script_path"]) == StrLower(targetPath)
                    matched.Push(RuleSpec.Clone(request))
                else
                    remaining.Push(request)
            }
            if matched.Length {
                if remaining.Length {
                    document["requests"] := remaining
                    this.WriteDocument(document)
                } else if FileExist(this.FilePath)
                    FileDelete(this.FilePath)
            }
            return matched
        } finally writeLease.Release()
    }

    ReadDocument(recoverInvalid := false) {
        this.LastRecoveryWarning := ""
        if !FileExist(this.FilePath)
            return Map("schema", ApplicationControlQueue.Schema,
                "requests", [])
        try sourceText := this.ReadSourceText()
        catch as readError {
            if !recoverInvalid || (!(readError is BoundedFileLimitError)
                    && !(readError is BoundedFileFormatError))
                throw
            this.QuarantineInvalidDocument()
            this.LastRecoveryWarning := readError.Message
            return Map("schema", ApplicationControlQueue.Schema,
                "requests", [])
        }
        try {
            document := JsonCodec.Parse(sourceText)
            if Type(document) != "Map" || document.Count != 2
                    || !document.Has("schema")
                    || Type(document["schema"]) != "Integer"
                    || document["schema"] != ApplicationControlQueue.Schema
                    || !document.Has("requests")
                    || Type(document["requests"]) != "Array"
                throw Error("应用控制队列格式无效。")
            if document["requests"].Length
                    > ApplicationControlQueue.MaximumRequests
                throw Error("应用控制队列条目数量超过上限。")
        } catch as documentError {
            if !recoverInvalid
                throw documentError
            this.QuarantineInvalidDocument()
            this.LastRecoveryWarning := documentError.Message
            return Map("schema", ApplicationControlQueue.Schema,
                "requests", [])
        }
        normalized := []
        requestIds := Map()
        invalidRequestFound := false
        for request in document["requests"] {
            try {
                normalizedRequest := this.NormalizeRequest(request)
                if requestIds.Has(normalizedRequest["id"])
                    throw Error("应用控制请求编号重复。")
                requestIds[normalizedRequest["id"]] := true
                normalized.Push(normalizedRequest)
            }
            catch as requestError {
                if !recoverInvalid
                    throw requestError
                invalidRequestFound := true
                this.LastRecoveryWarning .= (this.LastRecoveryWarning == ""
                    ? "" : "；") requestError.Message
            }
        }
        if invalidRequestFound {
            this.QuarantineInvalidDocument()
            if normalized.Length
                this.WriteDocument(Map(
                    "schema", ApplicationControlQueue.Schema,
                    "requests", normalized))
        }
        return Map("schema", ApplicationControlQueue.Schema,
            "requests", normalized)
    }

    ReadSourceText() {
        lastReadError := ""
        Loop 3 {
            try return BoundedFileReader.ReadUtf8(this.FilePath,
                ApplicationControlQueue.MaximumFileBytes,
                ApplicationControlQueue.MaximumFileBytes, "应用控制队列")
            catch as readError {
                if readError is BoundedFileLimitError
                        || readError is BoundedFileFormatError
                    throw
                lastReadError := readError
                if A_Index < 3
                    Sleep(10)
            }
        }
        throw lastReadError
    }

    QuarantineInvalidDocument() {
        if !FileExist(this.FilePath)
            return false
        quarantinePath := this.FilePath ".corrupt"
        if FileExist(quarantinePath)
            quarantinePath .= "-" FormatTime(A_NowUTC, "yyyyMMddHHmmss")
                . "-" Format("{:08X}", Random(0, 0xFFFFFFFF))
        FileMove(this.FilePath, quarantinePath, 1)
        return quarantinePath
    }

    NormalizeRequest(request) {
        if Type(request) != "Map"
            throw Error("应用控制请求必须是对象。")
        allowedFields := Map("id", true, "command", true,
            "script_path", true, "created_at", true,
            "process_id", true, "data", true)
        for fieldName in request {
            if !allowedFields.Has(fieldName)
                throw Error("应用控制请求包含未知字段：" fieldName)
        }
        for fieldName in ["id", "command", "script_path", "created_at"] {
            if !request.Has(fieldName) || Type(request[fieldName]) != "String"
                    || Trim(request[fieldName]) == ""
                throw Error("应用控制请求缺少字段：" fieldName)
        }
        requestId := request["id"]
        if !RegExMatch(requestId, "^\d{14}-[0-9A-F]{8}$")
            throw Error("应用控制请求编号无效。")
        command := StrLower(request["command"])
        if command != "apply"
            throw Error("应用控制请求命令无效。")
        createdAt := request["created_at"]
        if !RegExMatch(createdAt,
                "^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$")
            throw Error("应用控制请求时间无效。")
        if request.Has("process_id")
                && (Type(request["process_id"]) != "Integer"
                    || request["process_id"] < 0
                    || request["process_id"] > 0xFFFFFFFF)
            throw Error("应用控制请求进程编号无效。")
        if request.Has("data") && Type(request["data"]) != "Map"
            throw Error("应用控制请求数据必须是对象。")
        data := request.Has("data") ? RuleSpec.Clone(request["data"]) : Map()
        return Map("id", requestId, "command", command,
            "script_path", CrossProcessWriteLock.NormalizePath(
                request["script_path"]),
            "created_at", createdAt,
            "process_id", request.Has("process_id")
                ? request["process_id"] : 0,
            "data", data)
    }

    WriteDocument(document) {
        text := JsonCodec.Stringify(document, true, true) "`r`n"
        if StrPut(text, "UTF-8") - 1
                > ApplicationControlQueue.MaximumFileBytes
            throw Error("应用控制队列超过写入大小上限。")
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
                throw Error("无法写入应用控制队列。")
            output.Write(text)
            output.Close()
            output := ""
            FileMove(temporaryPath, this.FilePath, 1)
        } catch as writeError {
            if IsObject(output)
                try output.Close()
            if FileExist(temporaryPath)
                try FileDelete(temporaryPath)
            throw writeError
        }
        return true
    }
}
