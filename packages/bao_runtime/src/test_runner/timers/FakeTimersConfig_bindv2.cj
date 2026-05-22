// FakeTimersConfig_bindv2.cj - 假定时器配置 bindgenv2 元数据
// 严格翻译自 bun/src/runtime/test_runner/timers/FakeTimersConfig.bindv2.ts

package bao_runtime.test_runner.timers

import std.collection.*

/// bindgenv2 字段描述。
public class BindV2FieldDef {
    public var name: String
    public var typeName: String
    public var internalName: String

    public init(name: String, typeName: String, internalName: String) {
        this.name = name
        this.typeName = typeName
        this.internalName = internalName
    }
}

/// bindgenv2 dictionary 描述。
public class BindV2DictionaryDef {
    public var name: String
    public var userFacingName: String
    public var generateConversionFunction: Bool
    public var fields: ArrayList<BindV2FieldDef>

    public init(name: String, userFacingName: String, generateConversionFunction: Bool, fields: ArrayList<BindV2FieldDef>) {
        this.name = name
        this.userFacingName = userFacingName
        this.generateConversionFunction = generateConversionFunction
        this.fields = fields
    }
}

/// FakeTimersConfig = b.dictionary(...)
/// 运行时转换函数由 FakeTimers.cj 中 FakeTimersConfig.fromJS 提供。
public let FakeTimersConfigBindV2: BindV2DictionaryDef = BindV2DictionaryDef(
    "FakeTimersConfig",
    "FakeTimersOptions",
    true,
    ArrayList<BindV2FieldDef>([
        BindV2FieldDef("now", "RawAny", "now")
    ])
)
