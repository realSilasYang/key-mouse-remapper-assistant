class RuleSpecMigrationService {
    static OldestSupportedSchema := 1

    static Migrate(value) {
        if Type(value) != "Map"
            throw TypeError("RuleSpec 迁移输入必须是 JSON 对象。")
        original := RuleSpec.Clone(value)
        schema := original.Has("schema") ? original["schema"]
            : RuleSpec.CurrentSchema
        if IsObject(schema) || !IsNumber(schema)
                || Integer(schema) != schema
            throw TypeError("RuleSpec schema 必须是整数。")
        schema := Integer(schema)
        if schema > RuleSpec.CurrentSchema
            throw Error("RuleSpec 来自更高版本，当前程序不能安全迁移："
                schema)
        if schema < this.OldestSupportedSchema
            throw Error("RuleSpec 版本过旧，无法迁移：" schema)

        migrated := RuleSpec.Clone(original)
        hadLegacyProfile := migrated.Has("profile")
        if hadLegacyProfile
            migrated.Delete("profile")
        fromSchema := schema
        while schema < RuleSpec.CurrentSchema {
            switch schema {
                case 1:
                    migrated := this.MigrateV1ToV2(migrated)
                    schema := 2
                default:
                    throw Error("缺少 RuleSpec 迁移步骤：" schema)
            }
        }
        return {
            Spec: RuleSpec.Normalize(migrated),
            FromSchema: fromSchema,
            Changed: fromSchema != RuleSpec.CurrentSchema || hadLegacyProfile
        }
    }

    static MigrateToCurrent(value) {
        return this.Migrate(value).Spec
    }

    static MigrateV1ToV2(value) {
        migrated := RuleSpec.Clone(value)
        migrated["schema"] := 2
        if !migrated.Has("enabled")
            migrated["enabled"] := JsonBoolean(true)
        if !migrated.Has("description")
            migrated["description"] := ""
        if !migrated.Has("conditions")
            migrated["conditions"] := []
        return migrated
    }
}
