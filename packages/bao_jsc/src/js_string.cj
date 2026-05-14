// 严格翻译自: src/jsc/JSString.zig
// JavaScriptCore JsString 类型

package bao_jsc

// JsString - JS 字符串包装器
public class JsString {
    public var value: String = ""
    public var length: Int64 = 0

    public init() {}

    public init(value: String) {
        this.value = value
        this.length = Int64(value.size)
    }

    // 从 JsValue 创建
    public static func from(value: JsValue) -> JsString {
        JsString(value: value.toString())
    }

    // 转为 JsValue
    public func toJsValue() -> JsValue {
        JsValue(s: value)
    }

    // valueOf - String.prototype.valueOf
    public func valueOf() -> String {
        value
    }

    // toString - String.prototype.toString
    public func toString() -> String {
        value
    }

    // charAt - String.prototype.charAt
    public func charAt(index: Int64) -> String {
        if (index < 0 || index >= length) {
            return ""
        }
        String(value[Int64(index)])
    }

    // charCodeAt - String.prototype.charCodeAt
    public func charCodeAt(index: Int64) -> Float64 {
        if (index < 0 || index >= length) {
            return Float64.NaN
        }
        Float64(value[Int64(index)].code)
    }

    // codePointAt - String.prototype.codePointAt
    public func codePointAt(index: Int64) -> ?Int64 {
        if (index < 0 || index >= length) {
            return None
        }
        let c = value[Int64(index)]
        Some(Int64(c.code))
    }

    // concat - String.prototype.concat
    public func concat(strings: Array<String>) -> String {
        var result = value
        for (s in strings) {
            result = result + s
        }
        result
    }

    // includes - String.prototype.includes
    public func includes(search: String, position: Int64) -> Bool {
        let pos = if (position < 0) { 0 } else { position }
        let idx = value.indexOf(search, Int64(pos))
        idx >= 0
    }

    // indexOf - String.prototype.indexOf
    public func indexOf(search: String, position: Int64) -> Int64 {
        let pos = if (position < 0) { 0 } else { position }
        let idx = value.indexOf(search, Int64(pos))
        if (idx < 0) { Int64(-1) } else { Int64(idx) }
    }

    // lastIndexOf - String.prototype.lastIndexOf
    public func lastIndexOf(search: String) -> Int64 {
        Int64(value.lastIndexOf(search))
    }

    // slice - String.prototype.slice
    public func slice(start: Int64, end: Int64) -> String {
        let s = normalizeIndex(start)
        let e = if (end < 0) { Int64(length) + end } else { end }
        if (s >= e || s >= length) {
            return ""
        }
        value[Int64(s)..Int64(Math.min(e, length))]
    }

    // substring - String.prototype.substring
    public func substring(start: Int64, end: Int64) -> String {
        let s = Math.max(0, Math.min(start, length))
        let e = Math.max(0, Math.min(end, length))
        if (s > e) {
            return value[Int64(e)..Int64(s)]
        }
        value[Int64(s)..Int64(e)]
    }

    // split - String.prototype.split
    public func split(separator: String, limit: Int64) -> Array<String> {
        if (separator.isEmpty) {
            var result = Array<String>()
            let lim = if (limit <= 0) { length } else { limit }
            for (i in 0..Math.min(length, lim)) {
                result.append(String(value[Int64(i)]))
            }
            return result
        }
        value.split(separator, Int64(limit))
    }

    // toLowerCase - String.prototype.toLowerCase
    public func toLowerCase() -> String {
        value.toLowerAscii()
    }

    // toUpperCase - String.prototype.toUpperCase
    public func toUpperCase() -> String {
        value.toUpperAscii()
    }

    // trim - String.prototype.trim
    public func trim() -> String {
        value.trim()
    }

    // trimStart - String.prototype.trimStart
    public func trimStart() -> String {
        var i = 0
        while (i < value.size && isWhitespace(value[i])) { i++ }
        value[i..]
    }

    // trimEnd - String.prototype.trimEnd
    public func trimEnd() -> String {
        var i = value.size - 1
        while (i >= 0 && isWhitespace(value[i])) { i-- }
        value[0..i + 1]
    }

    // startsWith - String.prototype.startsWith
    public func startsWith(search: String, position: Int64) -> Bool {
        let pos = if (position < 0) { 0 } else { position }
        value[Int64(pos)..].startsWith(search)
    }

    // endsWith - String.prototype.endsWith
    public func endsWith(search: String, endPosition: Int64) -> Bool {
        let pos = if (endPosition < 0) { 0 } else { endPosition }
        let end = Math.min(pos, length)
        value[Int64(end - Int64(search.size))..Int64(end)] == search
    }

    // repeat - String.prototype.repeat
    public func repeat(count: Int64) -> String {
        if (count < 0) {
            throw JsRangeError("Invalid count value")
        }
        if (count == 0) {
            return ""
        }
        var result = StringBuilder()
        for (_ in 0..count) {
            result.append(value)
        }
        result.toString()
    }

    // padStart - String.prototype.padStart
    public func padStart(maxLength: Int64, fillString: String) -> String {
        pad(maxLength, fillString, true)
    }

    // padEnd - String.prototype.padEnd
    public func padEnd(maxLength: Int64, fillString: String) -> String {
        pad(maxLength, fillString, false)
    }

    func pad(maxLen: Int64, fill: String, start: Bool) -> String {
        if (length >= maxLen) { return value }
        let fillStr = if (fill.isEmpty) { " " } else { fill }
        let padLen = maxLen - length
        var padding = StringBuilder()
        while (padding.length < padLen) {
            padding.append(fillStr)
        }
        let padStr = padding.toString()[0..Int64(padLen)]
        if (start) {
            padStr + value
        } else {
            value + padStr
        }
    }

    // replace - String.prototype.replace
    public func replace(search: String, replacement: String) -> String {
        let idx = value.indexOf(search)
        if (idx < 0) { return value }
        value[0..idx] + replacement + value[idx + search.size..]
    }

    // replaceAll - String.prototype.replaceAll
    public func replaceAll(search: String, replacement: String) -> String {
        value.replace(search, replacement)
    }

    // match - String.prototype.match
    public func match(pattern: String) -> ?Array<String> {
        // 简化实现，完整版需要正则引擎
        let idx = value.indexOf(pattern)
        if (idx < 0) { return None }
        Some([pattern])
    }

    // normalize - String.prototype.normalize
    public func normalize(form: String) -> String {
        // NFC/NFD/NFKC/NFKD 标准化桩
        value
    }

    func normalizeIndex(idx: Int64) -> Int64 {
        if (idx < 0) {
            Math.max(0, length + idx)
        } else {
            Math.min(idx, length)
        }
    }

    func isWhitespace(c: UInt8) -> Bool {
        c == ' ' || c == '\t' || c == '\n' || c == '\r' || c == '\u{0b}' || c == '\u{0c}' || c == '\u{00a0}' || c == '\u{feff}'
    }

    // 静态方法 - String.fromCharCode
    public static func fromCharCode(codes: Array<Int64>) -> String {
        var result = StringBuilder()
        for (code in codes) {
            result.append(Char(code))
        }
        result.toString()
    }

    // String.fromCodePoint
    public static func fromCodePoint(codes: Array<Int64>) -> String {
        var result = StringBuilder()
        for (code in codes) {
            if (code < 0 || code > 0x10FFFF) {
                throw JsRangeError("Invalid code point: " + String(code))
            }
            result.append(Char(code))
        }
        result.toString()
    }

    // String.raw
    public static func raw(strings: Array<String>, values: Array<JsValue>) -> String {
        var result = StringBuilder()
        for (i in 0..strings.size) {
            result.append(strings[i])
            if (i < values.size) {
                result.append(values[i].toString())
            }
        }
        result.toString()
    }
}
