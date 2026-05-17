// bao_css - CSS URL 值
// 严格翻译自: bun/src/css/values/url.rs
//   对应: values/url.zig - Url { import_record_idx, loc }
package bao_css.values

import bao_core.*

// ============================================================================
// URL 值
// 严格翻译自: values/url.rs Url { import_record_idx: u32, loc: Location }
// ============================================================================

/// CSS url() 值
/// 严格翻译自 Url struct { import_record_idx: u32, loc: Location }
/// URL 值及其源码位置
public class CssUrl {
    /// URL 字符串
    public var url: String
    /// 源码位置 (行号)
    public var line: Int64
    /// 源码位置 (列号)
    public var column: Int64

    public init(url: String) {
        this.url = url
        this.line = 0
        this.column = 0
    }

    public init(url: String, line: Int64, column: Int64) {
        this.url = url
        this.line = line
        this.column = column
    }

    /// 是否为绝对 URL
    /// 严格翻译自 Url::is_absolute
    /// 以 '/' 或 '#' 开头, 或有 scheme (如 http:) 的 URL 为绝对路径
    public func isAbsolute(): Bool {
        if (url.isEmpty()) { return false }

        // 以 '.' 开头为相对路径
        if (url[0] == UInt8(46)) { return false }

        // 以 '/' 开头为绝对路径
        if (url[0] == UInt8(47)) { return true }

        // 以 '#' 开头为片段 URL
        if (url[0] == UInt8(35)) { return true }

        // 检查 scheme
        let first = url[0]
        if (!((first >= UInt8(97) && first <= UInt8(122)) || (first >= UInt8(65) && first <= UInt8(90)))) {
            return false
        }

        for (c in url) {
            if (c == UInt8(58)) {
                return true
            }
            if ((c >= UInt8(97) && c <= UInt8(122)) || (c >= UInt8(65) && c <= UInt8(90)) || (c >= UInt8(48) && c <= UInt8(57)) || c == UInt8(43) || c == UInt8(45) || c == UInt8(46)) {
                continue
            }
            break
        }

        false
    }

    /// 转为 CSS 文本
    /// 严格翻译自 Url::to_css
    public func toCss(): String {
        // 简化版本: 总是使用引号
        let escaped = url
            .replace("\\", "\\\\")
            .replace("'", "\\'")
            .replace("\"", "\\\"")
            .replace("\n", "\\a ")
            .replace("\r", "\\d ")
        "url(\"${escaped}\")"
    }

    /// 深拷贝
    /// 严格翻译自 Url::deep_clone (Copy type)
    public func deepClone(): CssUrl {
        CssUrl(url, line, column)
    }

    /// 相等比较
    /// 严格翻译自 Url::eql
    public func eql(other: CssUrl): Bool {
        url == other.url
    }

    public func toString(): String {
        toCss()
    }
}
