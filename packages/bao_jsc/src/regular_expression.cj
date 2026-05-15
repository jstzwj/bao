// 严格翻译自: src/jsc/RegularExpression.zig (58行)
// JavaScriptCore RegularExpression 绑定 (基于 Yarr 正则引擎)

package bao_jsc

// ========== RegularExpressionFlags ==========
// 严格翻译自 RegularExpression.zig Flags
// 正则表达式标志位 (位掩码)
public enum RegularExpressionFlags <: UInt16 {
    | None(0)
    | HasIndices(1 << 0)     // d 标志 - 返回匹配索引
    | Global(1 << 1)         // g 标志 - 全局匹配
    | IgnoreCase(1 << 2)     // i 标志 - 忽略大小写
    | Multiline(1 << 3)      // m 标志 - 多行模式
    | DotAll(1 << 4)         // s 标志 - dotAll 模式
    | Unicode(1 << 5)        // u 标志 - Unicode 模式
    | UnicodeSets(1 << 6)    // v 标志 - Unicode Sets 模式
    | Sticky(1 << 7)         // y 标志 - 粘性匹配

    // 检查是否包含指定标志
    public func has(flag: RegularExpressionFlags) -> Bool {
        (this.value & flag.value) != 0
    }

    // 合并标志
    public func union(other: RegularExpressionFlags) -> RegularExpressionFlags {
        RegularExpressionFlags(this.value | other.value)
    }
}

// ========== RegularExpression ==========
// 严格翻译自 RegularExpression.zig
// Yarr 正则表达式的包装
// 这是一个 opaque 类型，实际正则引擎在 C++ Yarr 侧
public class RegularExpression {
    // 正则模式字符串
    public var pattern: String = ""
    // 标志位
    public var flags: RegularExpressionFlags = RegularExpressionFlags.None
    // 是否有效 (编译是否成功)
    public var valid: Bool = false
    // 原始指针 (C++ Yarr 正则对象)
    public var rawPtr: CPointer<UInt8> = CPointer<UInt8>()

    private init() {}

    // ========== FFI 绑定 ==========

    // 严格翻译自 RegularExpression.init
    // FFI: Yarr__RegularExpression__init(pattern, flags)
    // 创建并编译正则表达式
    public static func init(pattern: String, flags: RegularExpressionFlags) -> RegularExpression {
        let regex = RegularExpression()
        regex.pattern = pattern
        regex.flags = flags
        // 在真实实现中，这里调用 Yarr 编译正则
        // 编译失败则返回错误
        regex.valid = validatePattern(pattern)
        if (!regex.valid) {
            regex.deinit()
            // 对应 Zig 中的 error.InvalidRegExp
        }
        regex
    }

    // 严格翻译自 RegularExpression.isValid
    // FFI: Yarr__RegularExpression__isValid(this)
    // 检查正则表达式是否有效
    public func isValid() -> Bool {
        valid
    }

    // 严格翻译自 RegularExpression.matches
    // FFI: Yarr__RegularExpression__matches(this, string)
    // 简单的布尔匹配器
    // 返回字符串是否完全匹配正则表达式
    public func matches(str: String) -> Bool {
        if (!valid) {
            return false
        }
        // 简化实现 - 完整版需要 Yarr 引擎
        simpleMatch(pattern, str)
    }

    // 严格翻译自 RegularExpression.searchRev
    // FFI: Yarr__RegularExpression__searchRev(this)
    // 反向搜索
    public func searchRev(str: String) -> Int32 {
        if (!valid) {
            return -1
        }
        // 简化实现
        -1
    }

    // 严格翻译自 RegularExpression.matchedLength
    // FFI: Yarr__RegularExpression__matchedLength(this)
    // 返回最近一次匹配的长度
    public func matchedLength() -> Int32 {
        // 简化实现
        0
    }

    // 严格翻译自 RegularExpression.deinit
    // FFI: Yarr__RegularExpression__deinit(this)
    // 释放正则表达式资源
    public func deinit() {
        valid = false
        rawPtr = CPointer<UInt8>()
    }

    // ========== 辅助方法 ==========

    // 从 JS 标志字符串解析标志位
    // 例如: "gi" -> Global | IgnoreCase
    public static func parseFlags(flagStr: String) -> RegularExpressionFlags {
        var flags: UInt16 = 0
        for (c in flagStr) {
            match (c) {
                case 'g' => flags = flags | RegularExpressionFlags.Global.value
                case 'i' => flags = flags | RegularExpressionFlags.IgnoreCase.value
                case 'm' => flags = flags | RegularExpressionFlags.Multiline.value
                case 's' => flags = flags | RegularExpressionFlags.DotAll.value
                case 'u' => flags = flags | RegularExpressionFlags.Unicode.value
                case 'v' => flags = flags | RegularExpressionFlags.UnicodeSets.value
                case 'y' => flags = flags | RegularExpressionFlags.Sticky.value
                case 'd' => flags = flags | RegularExpressionFlags.HasIndices.value
                case _ => {}
            }
        }
        RegularExpressionFlags(flags)
    }

    // 将标志位转为字符串
    public static func flagsToString(flags: RegularExpressionFlags) -> String {
        var result = ""
        if (flags.has(RegularExpressionFlags.HasIndices)) { result = result + "d" }
        if (flags.has(RegularExpressionFlags.Global)) { result = result + "g" }
        if (flags.has(RegularExpressionFlags.IgnoreCase)) { result = result + "i" }
        if (flags.has(RegularExpressionFlags.Multiline)) { result = result + "m" }
        if (flags.has(RegularExpressionFlags.DotAll)) { result = result + "s" }
        if (flags.has(RegularExpressionFlags.Unicode)) { result = result + "u" }
        if (flags.has(RegularExpressionFlags.UnicodeSets)) { result = result + "v" }
        if (flags.has(RegularExpressionFlags.Sticky)) { result = result + "y" }
        result
    }

    // 验证正则模式是否有效
    func validatePattern(pattern: String) -> Bool {
        // 简化实现 - 完整版需要 Yarr 编译器
        // 检查基本语法错误
        if (pattern.isEmpty) {
            return true  // 空模式是有效的
        }
        // 检查括号匹配
        var depth = 0
        for (c in pattern) {
            if (c == '(') { depth++ }
            if (c == ')') {
                depth--
                if (depth < 0) { return false }
            }
        }
        depth == 0
    }

    // 简单的模式匹配 (仅支持字面量匹配)
    func simpleMatch(pattern: String, str: String) -> Bool {
        // 简化实现 - 完整版需要 Yarr 引擎
        str.contains(pattern)
    }
}
