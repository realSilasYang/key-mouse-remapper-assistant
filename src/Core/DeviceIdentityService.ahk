class DeviceIdentityService {
    Build(descriptor) {
        if Type(descriptor) != "Map"
            throw TypeError("设备身份描述必须是 Map。")
        path := descriptor.Has("path") ? String(descriptor["path"]) : ""
        normalizedPath := this.NormalizePath(path)
        parsed := this.ParseRawInputPath(normalizedPath)
        typeName := descriptor.Has("type")
            ? StrLower(String(descriptor["type"])) : "unknown"
        usagePage := descriptor.Has("usage_page")
            ? Max(0, Integer(descriptor["usage_page"])) : 0
        usage := descriptor.Has("usage")
            ? Max(0, Integer(descriptor["usage"])) : 0
        vendorId := this.NormalizeHexId(descriptor.Has("vendor_id")
            ? descriptor["vendor_id"] : parsed["vendor_id"])
        productId := this.NormalizeHexId(descriptor.Has("product_id")
            ? descriptor["product_id"] : parsed["product_id"])
        revision := this.NormalizeHexId(descriptor.Has("revision")
            ? descriptor["revision"] : parsed["revision"])
        interfaceNumber := this.NormalizeHexId(descriptor.Has(
            "interface_number") ? descriptor["interface_number"]
            : parsed["interface_number"], 2)
        containerId := this.NormalizeGuid(descriptor.Has("container_id")
            ? descriptor["container_id"] : "")
        serial := this.NormalizeToken(descriptor.Has("serial")
            ? descriptor["serial"] : parsed["serial"])
        instanceId := this.NormalizeToken(descriptor.Has("instance_id")
            ? descriptor["instance_id"] : parsed["instance_id"])
        hardwareId := this.BuildHardwareId(typeName, vendorId, productId,
            revision, interfaceNumber, usagePage, usage)

        if containerId != "" {
            stability := "container"
            stableSource := "container:" . containerId . "|usage:"
                . usagePage . ":" . usage
        } else if serial != "" {
            stability := "serial"
            stableSource := "serial:" . hardwareId . "|" . serial
        } else if instanceId != "" {
            stability := "instance"
            stableSource := "instance:" . hardwareId . "|" . instanceId
        } else if normalizedPath != "" {
            stability := "path"
            stableSource := "path:" . normalizedPath
        } else {
            stability := "session"
            handle := descriptor.Has("handle")
                ? String(descriptor["handle"]) : "unknown"
            stableSource := "session:" . typeName . "|" . handle
        }
        stableId := "device-" SubStr(StrLower(Sha256.HexText(stableSource)),
            1, 32)
        exactPathId := normalizedPath == "" ? ""
            : "path-" SubStr(StrLower(Sha256.HexText(normalizedPath)), 1, 32)
        matchKeys := ["stable:" stableId, "hardware:" hardwareId]
        if exactPathId != ""
            matchKeys.Push("path:" exactPathId)
        if containerId != ""
            matchKeys.Push("container:" containerId)
        if serial != ""
            matchKeys.Push("serial:" serial)
        return Map(
            "id", stableId,
            "stable_id", stableId,
            "exact_path_id", exactPathId,
            "stability", stability,
            "ambiguous", JsonBoolean(stability != "container"
                && stability != "serial"),
            "hardware_id", hardwareId,
            "container_id", containerId,
            "serial", serial,
            "instance_id", instanceId,
            "interface_number", interfaceNumber,
            "revision", revision,
            "normalized_path", normalizedPath,
            "match_keys", matchKeys)
    }

    Reconcile(previousDevices, currentDevices) {
        if Type(previousDevices) != "Array" || Type(currentDevices) != "Array"
            throw TypeError("设备重绑定集合必须是数组。")
        previousById := this.IndexByStableId(previousDevices)
        currentById := this.IndexByStableId(currentDevices)
        arrived := [], removed := [], rebound := [], unchanged := []
        for stableId, current in currentById {
            if !previousById.Has(stableId) {
                arrived.Push(RuleSpec.Clone(current))
                continue
            }
            previous := previousById[stableId]
            previousHandle := previous.Has("handle")
                ? String(previous["handle"]) : ""
            currentHandle := current.Has("handle")
                ? String(current["handle"]) : ""
            if previousHandle != currentHandle
                rebound.Push(Map("previous", RuleSpec.Clone(previous),
                    "current", RuleSpec.Clone(current)))
            else
                unchanged.Push(RuleSpec.Clone(current))
        }
        for stableId, previous in previousById {
            if !currentById.Has(stableId)
                removed.Push(RuleSpec.Clone(previous))
        }
        return {Arrived: arrived, Removed: removed, Rebound: rebound,
            Unchanged: unchanged}
    }

    IndexByStableId(devices) {
        result := Map()
        for device in devices {
            if Type(device) != "Map" || !device.Has("stable_id")
                continue
            stableId := String(device["stable_id"])
            if result.Has(stableId)
                throw Error("设备稳定身份发生碰撞：" stableId)
            result[stableId] := device
        }
        return result
    }

    NormalizePath(path) {
        path := StrLower(Trim(String(path)))
        path := StrReplace(path, "/", "\")
        path := RegExReplace(path, "\\+$")
        return path
    }

    ParseRawInputPath(normalizedPath) {
        result := Map("vendor_id", "", "product_id", "",
            "revision", "", "interface_number", "", "instance_id", "",
            "serial", "")
        if normalizedPath == ""
            return result
        result["vendor_id"] := this.Extract(normalizedPath,
            "(?:^|[#&])vid_([0-9a-f]{4})")
        result["product_id"] := this.Extract(normalizedPath,
            "(?:^|[#&])pid_([0-9a-f]{4})")
        result["revision"] := this.Extract(normalizedPath,
            "(?:^|[#&])rev_([0-9a-f]{4})")
        result["interface_number"] := this.Extract(normalizedPath,
            "(?:^|[#&])mi_([0-9a-f]{2})")
        parts := StrSplit(RegExReplace(normalizedPath, "^\\\\\?\\", ""),
            "#")
        if parts.Length >= 3 {
            instanceId := this.NormalizeToken(parts[3])
            result["instance_id"] := instanceId
            if !RegExMatch(instanceId, "i)^\d+&[0-9a-f]+&")
                    && !InStr(instanceId, "&")
                result["serial"] := instanceId
        }
        return result
    }

    BuildHardwareId(typeName, vendorId, productId, revision,
            interfaceNumber, usagePage, usage) {
        return typeName . ":vid="
            . (vendorId == "" ? "unknown" : vendorId)
            . ":pid=" . (productId == "" ? "unknown" : productId)
            . ":rev=" . (revision == "" ? "unknown" : revision)
            . ":mi=" . (interfaceNumber == "" ? "unknown"
                : interfaceNumber)
            . ":usage=" . usagePage . ":" . usage
    }

    Extract(text, pattern) {
        return RegExMatch(text, "i)" pattern, &match)
            ? StrUpper(match[1]) : ""
    }

    NormalizeHexId(value, width := 4) {
        value := StrUpper(Trim(String(value)))
        return RegExMatch(value, "^[0-9A-F]{" width "}$") ? value : ""
    }

    NormalizeGuid(value) {
        value := StrLower(Trim(String(value), "{} `t`r`n"))
        return RegExMatch(value,
            "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$")
            ? value : ""
    }

    NormalizeToken(value) {
        value := StrLower(Trim(String(value)))
        return RegExMatch(value, "^[a-z0-9_.&-]{1,256}$") ? value : ""
    }
}
