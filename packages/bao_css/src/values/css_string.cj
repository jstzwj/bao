// bao_css - CSS 字符串值
// 严格翻译自: bun/src/css/values/css_string.rs
//   对应: values/css_string.zig - CssString, CssStringFns
package bao_css.values

import bao_core.*

// ============================================================================
// CSS 字符串
// 严格翻译自: values/css_string.rs CssString = *const [u8]
// ============================================================================

/// CSS 引用字符串
/// 严格翻译自 CssString (arena-borrowed byte slice pointer)
/// 在仓颉中用 String 表示; arena 生命周期由调用方管理
public class CssString {
    public var value: String

    public init(value: String) {
        this.value = value
    }

    /// 解析 CSS 字符串
    /// 严格翻译自 CssStringFns.parse
    public static func parse(input: CssParser): Result<CssString> {
        let str = input.expectString()
        match (str) {
            case Some(s) => Result<CssString>.ok(CssString(s))
            case None => Result<CssString>.err(CssParseError.invalidValue)
        }
    }

    /// 转为 CSS 文本
    /// 严格翻译自 CssStringFns.to_css -> serialize_string
    public func toCss(): String {
        // 序列化字符串: 添加引号并转义
        var sb = StringBuilder()
        sb.append('"')
        for (c in value) {
            match (c) {
                case '"' => sb.append("\\\"")
                case '\\' => sb.append("\\\\")
                case '\n' => sb.append("\\a ")
                case '\r' => sb.append("\\d ")
                case '\t' => sb.append("\\9 ")
                case _ => sb.append(c)
            }
        }
        sb.append('"')
        sb.toString()
    }

    /// 深拷贝
    public func deepClone(): CssString {
        CssString(value)
    }

    /// 相等比较
    public func eql(other: CssString): Bool {
        value == other.value
    }

    /// 获取原始字符串
    public func asStr(): String {
        value
    }

    public func toString(): String {
        toCss()
    }
}
