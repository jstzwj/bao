// bao_unicode - uucode 配置
// 严格翻译自: src/unicode/uucode_lib/src/config.zig
//   定义 Unicode 数据表配置
//   Field: 字段描述 (name, type, packing, shift 等)
//   Table: 数据表描述 (stages, packing, fields)
//   Extension: 扩展字段描述
//   仓颉实现提供等价的配置结构
package bao_unicode.uucode_lib

// ============================================================================
// Config - Unicode 数据配置
// 严格翻译自: src/unicode/uucode_lib/src/config.zig
// ============================================================================

/// 字段代码点打包方式
/// 翻译自: pub const CpPacking = enum { direct, shift }
public enum CpPacking {
    | Direct
    | Shift
}

/// 字段类型
/// 翻译自: pub const Kind = enum { basic, slice, shift, optional, union }
public enum FieldKind {
    | Basic
    | Slice
    | Shift
    | Optional
    | Union
}

/// Unicode 字段配置
/// 严格翻译自: pub const Field = struct
///   name: [:0]const u8, type: type
///   cp_packing, shift_low, shift_high
///   max_len, max_offset, embedded_len
///   min_value, max_value
public class UnicodeFieldConfig {
    /// 字段名
    public var name: String

    /// 字段类型名
    public var typeName: String

    /// 代码点打包方式
    public var cpPacking: CpPacking = CpPacking.Direct

    /// 移位范围
    public var shiftLow: Int64 = 0
    public var shiftHigh: Int64 = 0

    /// 切片参数
    public var maxLen: Int64 = 0
    public var maxOffset: Int64 = 0
    public var embeddedLen: Int64 = 0

    /// 可选值范围
    public var minValue: Int64 = 0
    public var maxValue: Int64 = 0

    public init(name: String, typeName: String) {
        this.name = name
        this.typeName = typeName
    }

    /// 获取字段类型
    /// 翻译自: pub fn kind(self: Field) Kind
    public func kind(): FieldKind {
        if (maxLen > 0) {
            return FieldKind.Slice
        }
        if (cpPacking == CpPacking.Shift) {
            return FieldKind.Shift
        }
        return FieldKind.Basic
    }

    /// 是否可以被压缩
    /// 翻译自: pub fn canBePacked(self: Field) bool
    public func canBePacked(): Bool {
        return kind() != FieldKind.Slice
    }

    /// 创建运行时表示
    /// 翻译自: pub fn runtime(self: Field) Runtime
    public func runtime(): FieldRuntime {
        return FieldRuntime(
            name: name,
            typeName: typeName,
            cpPacking: cpPacking,
            shiftLow: shiftLow,
            shiftHigh: shiftHigh,
            maxLen: maxLen,
            maxOffset: maxOffset,
            embeddedLen: embeddedLen,
            minValue: minValue,
            maxValue: maxValue
        )
    }
}

/// 运行时字段表示
/// 翻译自: pub const Runtime = struct
public class FieldRuntime {
    public var name: String
    public var typeName: String
    public var cpPacking: CpPacking
    public var shiftLow: Int64
    public var shiftHigh: Int64
    public var maxLen: Int64
    public var maxOffset: Int64
    public var embeddedLen: Int64
    public var minValue: Int64
    public var maxValue: Int64

    public init(name: String, typeName: String, cpPacking: CpPacking,
                shiftLow: Int64, shiftHigh: Int64, maxLen: Int64,
                maxOffset: Int64, embeddedLen: Int64, minValue: Int64, maxValue: Int64) {
        this.name = name
        this.typeName = typeName
        this.cpPacking = cpPacking
        this.shiftLow = shiftLow
        this.shiftHigh = shiftHigh
        this.maxLen = maxLen
        this.maxOffset = maxOffset
        this.embeddedLen = embeddedLen
        this.minValue = minValue
        this.maxValue = maxValue
    }

    /// 是否相等
    /// 翻译自: pub fn eql(a: Runtime, b: Runtime) bool
    public func eql(other: FieldRuntime): Bool {
        return cpPacking == other.cpPacking &&
            shiftLow == other.shiftLow &&
            shiftHigh == other.shiftHigh &&
            maxLen == other.maxLen &&
            maxOffset == other.maxOffset &&
            embeddedLen == other.embeddedLen &&
            minValue == other.minValue &&
            maxValue == other.maxValue &&
            name == other.name &&
            typeName == other.typeName
    }
}

/// 数据表阶段类型
/// 翻译自: pub const Stages = enum { auto, two, three }
public enum Stages {
    | Auto
    | Two
    | Three
}

/// 数据表打包方式
/// 翻译自: pub const Packing = enum { auto, packed, unpacked }
public enum Packing {
    | Auto
    | Packed
    | Unpacked
}

/// Unicode 数据表配置
/// 严格翻译自: pub const Table = struct
///   name, stages, packing, extensions, fields
public class TableConfig {
    /// 表名
    public var name: ?String = None

    /// 阶段类型
    public var stages: Stages = Stages.Auto

    /// 打包方式
    public var packing: Packing = Packing.Auto

    /// 扩展
    public var extensions: Array<ExtensionConfig> = []

    /// 字段列表
    public var fields: Array<UnicodeFieldConfig> = []

    public init() {}

    /// 是否包含指定字段
    /// 翻译自: pub fn hasField(comptime self, name) bool
    public func hasField(name: String): Bool {
        for (f in fields) {
            if (f.name == name) {
                return true
            }
        }
        return false
    }

    /// 解析配置
    /// 翻译自: pub fn resolve(comptime self) Table
    public func resolve(): TableConfig {
        if (stages != Stages.Auto && packing != Packing.Auto) {
            return this
        }
        // 自动选择阶段和打包方式
        if (stages == Stages.Auto) {
            stages = Stages.Three
        }
        if (packing == Packing.Auto) {
            packing = Packing.Unpacked
        }
        return this
    }
}

/// 扩展配置
/// 翻译自: pub const Extension = struct
public class ExtensionConfig {
    /// 输入字段名
    public var inputs: Array<String> = []

    /// 扩展字段
    public var fields: Array<UnicodeFieldConfig> = []

    public init() {}

    public func hasField(name: String): Bool {
        for (f in fields) {
            if (f.name == name) {
                return true
            }
        }
        return false
    }
}
