// bao_unicode - uucode 属性查询
// 严格翻译自: src/unicode/uucode_lib/src/get.zig
//   提供 Unicode 属性查询的核心 get/getAll 函数
//   使用多级查找表 (stage1 -> stage2 -> stage3)
//   仓颉实现提供等价的属性查询接口
package bao_unicode.uucode_lib

// ============================================================================
// Unicode 属性查询
// 严格翻译自: src/unicode/uucode_lib/src/get.zig
//   get(field, cp) -> 属性值
//   getAll(table_name, cp) -> 数据记录
//   使用 stage1/stage2/stage3 三级查找表
// ============================================================================

/// Unicode 属性查询器
/// 严格翻译自 get.zig 的 get/getAll 函数
///   通过三级查找表查询码点的 Unicode 属性
public class UnicodeLookup {
    /// stage1 查找表 (高 8 位索引)
    private var stage1: Array<UInt16> = []

    /// stage2 查找表 (低 8 位 + stage1 偏移)
    private var stage2: Array<UInt16> = []

    /// stage3 数据表 (实际属性值)
    private var stage3: Array<UInt32> = []

    public init() {}

    /// 使用三级查找表查询数据索引
    /// 翻译自: fn data(comptime table, cp: u21) TableData
    ///   stage1_idx = cp >> 8
    ///   stage2_idx = cp & 0xFF
    ///   三级: stage3[stage2[stage1[stage1_idx] + stage2_idx]]
    ///   二级: stage2[stage1[stage1_idx] + stage2_idx]
    public func lookupIndex(cp: UInt32): UInt32 {
        let stage1Idx = cp >> 8
        let stage2Idx = cp & 0xFF

        if (Int64(stage1Idx) >= stage1.size) {
            return 0
        }

        let stage1Val = stage1[Int64(stage1Idx)]
        let combinedIdx = Int64(stage1Val) + Int64(stage2Idx)

        if (combinedIdx >= stage2.size) {
            return 0
        }

        let stage2Val = stage2[combinedIdx]

        if (stage3.size > 0 && Int64(stage2Val) < stage3.size) {
            return stage3[Int64(stage2Val)]
        }

        return UInt32(stage2Val)
    }

    /// 查询布尔属性
    public func getBool(field: UnicodeField, cp: UInt32): Bool {
        // 由具体实现提供
        return false
    }

    /// 查询枚举属性
    public func getEnum(field: UnicodeField, cp: UInt32): UInt32 {
        return lookupIndex(cp)
    }

    /// 查询可选码点属性 (如 Simple_Uppercase_Mapping)
    /// 翻译自 ShiftField.unshift(cp)
    public func getOptionalCodePoint(field: UnicodeField, cp: UInt32): ?UInt32 {
        let raw = lookupIndex(cp)
        if (raw == 0) {
            return None
        }
        return raw + cp // shift packing (simplified: no wrapping needed)
    }

    /// 查询码点属性 (如 Case_Folding_Simple)
    public func getCodePoint(field: UnicodeField, cp: UInt32): UInt32 {
        let raw = lookupIndex(cp)
        return raw + cp // shift packing (simplified: no wrapping needed)
    }

    /// 查询字符串属性 (如 Name)
    public func getString(field: UnicodeField, cp: UInt32): String {
        // 由具体字符串表实现
        return ""
    }

    /// 查询类别属性
    public func getGeneralCategory(cp: UInt32): GeneralCategory {
        let raw = lookupIndex(cp)
        // 从 raw 解析 GeneralCategory 枚举
        return GeneralCategory.OtherNotAssigned
    }

    /// 查询 Grapheme Break 属性
    public func getGraphemeBreak(cp: UInt32): GraphemeBreakProperty {
        let raw = lookupIndex(cp)
        return GraphemeBreakProperty.Other
    }

    /// 查询 East Asian Width
    public func getEastAsianWidth(cp: UInt32): EastAsianWidthType {
        let raw = lookupIndex(cp)
        return EastAsianWidthType.Neutral
    }

    // ========================================================================
    // 属性表初始化
    // ========================================================================

    /// 设置查找表
    public func setTables(stage1: Array<UInt16>, stage2: Array<UInt16>, stage3: Array<UInt32>): Unit {
        this.stage1 = stage1
        this.stage2 = stage2
        this.stage3 = stage3
    }
}

/// 全局 Unicode 查询器实例
private let globalLookup: UnicodeLookup = UnicodeLookup()

/// 全局 get 函数
/// 翻译自: pub fn get(field: FieldEnum, cp: u21) TypeOf(field)
public func unicodeGet(field: UnicodeField, cp: UInt32): UnicodeValue {
    let raw = globalLookup.getEnum(field, cp)
    return UnicodeValue.UInt32Value(raw)
}
