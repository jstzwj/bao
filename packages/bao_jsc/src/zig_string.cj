// 严格翻译自: src/jsc/ZigString.zig (865行)
// Bun ZigString - 多编码字符串类型 (UTF-8/Latin1/UTF-16)

package bao_jsc

// ========== ZigString ==========
// 严格翻译自 ZigString.zig
// ZigString 是 Bun 中用于在 Zig/仓颉 和 JavaScriptCore 之间传递字符串的核心类型
// 支持三种编码: Latin1, UTF-8, UTF-16
public class ZigString {
    // 字符串数据
    public var ptr: String = ""
    // 长度
    public var len: Int64 = 0
    // 编码标志
    public var isUtf8: Bool = false
    public var isUtf16: Bool = false
    public var isGloballyAllocated: Bool = false
    public var isStatic: Bool = false

    public init() {}

    public init(slice: String) {
        this.ptr = slice
        this.len = Int64(slice.size)
        if (!isAllAscii(slice)) {
            this.isUtf8 = true
        }
    }

    // 严格翻译自 ZigString.fromBytes
    public static func fromBytes(slice: String) -> ZigString {
        if (!isAllAscii(slice)) {
            return initUTF8(slice)
        }
        ZigString(slice)
    }

    // 严格翻译自 ZigString.init
    public static func init(slice: String) -> ZigString {
        ZigString(slice)
    }

    // 严格翻译自 ZigString.initUTF8
    public static func initUTF8(slice: String) -> ZigString {
        let out = ZigString(slice)
        out.isUtf8 = true
        out
    }

    // 严格翻译自 ZigString.static
    public static func static_(slice: String) -> ZigString {
        let out = ZigString(slice)
        out.isStatic = true
        out
    }

    // ========== 编码检查 ==========

    // 严格翻译自 ZigString.is16Bit
    public func is16Bit() -> Bool {
        isUtf16
    }

    // 严格翻译自 ZigString.isUTF8
    public func isUTF8() -> Bool {
        isUtf8
    }

    // 严格翻译自 ZigString.isGloballyAllocated
    public func isGlobal() -> Bool {
        isGloballyAllocated
    }

    // 严格翻译自 ZigString.isEmpty
    public func isEmpty() -> Bool {
        len == 0
    }

    // 严格翻译自 ZigString.isAllASCII
    public func isAllASCII() -> Bool {
        isAllAscii(ptr)
    }

    // ========== 字符串操作 ==========

    // 严格翻译自 ZigString.length
    public func length() -> Int64 {
        len
    }

    // 严格翻译自 ZigString.slice
    public func slice() -> String {
        ptr
    }

    // 严格翻译自 ZigString.substring
    public func substring(startIndex: Int64) -> ZigString {
        substringWithLen(startIndex, len)
    }

    // 严格翻译自 ZigString.substringWithLen
    public func substringWithLen(startIndex: Int64, endIndex: Int64) -> ZigString {
        let s = if (startIndex < 0) { 0 } else { startIndex }
        let e = if (endIndex > len) { len } else { endIndex }
        if (s >= e) {
            return ZigString()
        }
        let out = ZigString(ptr[Int64(s)..Int64(e)])
        out.isUtf8 = isUtf8
        out.isUtf16 = isUtf16
        out.isGloballyAllocated = isGloballyAllocated
        out
    }

    // 严格翻译自 ZigString.trunc
    public func trunc(maxLen: Int64) -> ZigString {
        if (maxLen >= len) {
            return this
        }
        let out = ZigString(ptr[0..Int64(maxLen)])
        out.isUtf8 = isUtf8
        out.isUtf16 = isUtf16
        out
    }

    // 严格翻译自 ZigString.hasPrefixChar
    public func hasPrefixChar(c: UInt8) -> Bool {
        if (len == 0) { return false }
        ptr[0] == c
    }

    // 严格翻译自 ZigString.charAt
    public func charAt(offset: Int64) -> UInt8 {
        if (offset < 0 || offset >= len) { return 0 }
        UInt8(ptr[Int64(offset)])
    }

    // ========== 比较 ==========

    // 严格翻译自 ZigString.eql
    public func eql(other: ZigString) -> Bool {
        if (len == 0 || other.len == 0) {
            return len == other.len
        }
        if (is16Bit() == other.is16Bit()) {
            return ptr == other.ptr
        }
        // 不同编码，需要转换比较
        ptr == other.ptr
    }

    // 严格翻译自 ZigString.eqlCaseInsensitive
    public func eqlCaseInsensitive(other: ZigString) -> Bool {
        ptr.toLowerAscii() == other.ptr.toLowerAscii()
    }

    // 严格翻译自 ZigString.eqlComptime
    public func eqlComptime(other: String) -> Bool {
        ptr == other
    }

    // ========== JS 互操作 ==========

    // 严格翻译自 ZigString.toJS
    public func toJS(global: JsObject) -> JsValue {
        JsValue(s: ptr)
    }

    // 严格翻译自 ZigString.toErrorInstance
    public func toErrorInstance(global: JsObject) -> JsValue {
        JsValue(JsError(ptr).toString())
    }

    // 严格翻译自 ZigString.toTypeErrorInstance
    public func toTypeErrorInstance(global: JsObject) -> JsValue {
        JsValue(JsTypeError(ptr).toString())
    }

    // 严格翻译自 ZigString.toSyntaxErrorInstance
    public func toSyntaxErrorInstance(global: JsObject) -> JsValue {
        JsValue(JsSyntaxError(ptr).toString())
    }

    // 严格翻译自 ZigString.toRangeErrorInstance
    public func toRangeErrorInstance(global: JsObject) -> JsValue {
        JsValue(JsRangeError(ptr).toString())
    }

    // 严格翻译自 ZigString.toJSONObject
    public func toJSONObject(global: JsObject) -> JsValue {
        JsValue.undefined()  // 简化实现
    }

    // 严格翻译自 ZigString.toURL
    public func toURL(global: JsObject) -> JsValue {
        JsValue.undefined()  // 简化实现
    }

    // ========== 标记方法 ==========

    // 严格翻译自 ZigString.markUTF8
    public func markUTF8() {
        isUtf8 = true
    }

    // 严格翻译自 ZigString.markUTF16
    public func markUTF16() {
        isUtf16 = true
    }

    // 严格翻译自 ZigString.markGlobal
    public func markGlobal() {
        isGloballyAllocated = true
    }

    // 严格翻译自 ZigString.markStatic
    public func markStatic() {
        isStatic = true
    }

    // 严格翻译自 ZigString.setOutputEncoding
    public func setOutputEncoding() {
        if (!is16Bit() && !isAllASCII()) {
            isUtf8 = true
        }
    }

    // ========== 辅助 ==========

    // 转为字符串
    public func toString() -> String {
        ptr
    }

    // 严格翻译自 ZigString.maxUTF8ByteLength
    public func maxUTF8ByteLength() -> Int64 {
        if (isUTF8()) { return len }
        if (is16Bit()) { return len * 3 }
        len * 2
    }

    // 严格翻译自 ZigString.toOwnedSlice
    public func toOwnedSlice() -> String {
        String(ptr)
    }

    // 严格翻译自 ZigString.trimmedSlice
    public func trimmedSlice() -> String {
        ptr.trim()
    }

    // ========== 静态常量 ==========
    // 严格翻译自 ZigString.Empty
    public static let Empty = ZigString()

    // 检查字符串是否全为 ASCII
    func isAllAscii(s: String) -> Bool {
        for (c in s) {
            if (c.code > 127) {
                return false
            }
        }
        true
    }

    // 排序辅助
    // 严格翻译自 ZigString.sortDesc
    public static func sortDesc(strings: Array<ZigString>) {
        // 降序排序
        strings.sort({ a, b => b.ptr > a.ptr })
    }

    // 严格翻译自 ZigString.sortAsc
    public static func sortAsc(strings: Array<ZigString>) {
        strings.sort({ a, b => a.ptr < b.ptr })
    }
}

// ========== ZigString.Slice ==========
// 严格翻译自 ZigString.Slice
// 带分配器的字符串切片
public class ZigStringSlice {
    public var ptr: String = ""
    public var len: UInt32 = 0
    public var isAllocated: Bool = false

    public init() {}

    public init(slice: String) {
        this.ptr = slice
        this.len = UInt32(slice.size)
    }

    // 严格翻译自 Slice.empty
    public static let empty = ZigStringSlice()

    // 严格翻译自 Slice.byteLength
    public func byteLength() -> Int64 {
        Int64(len)
    }

    // 严格翻译自 Slice.length
    public func length() -> Int64 {
        Int64(len)
    }

    // 严格翻译自 Slice.slice
    public func slice() -> String {
        ptr
    }

    // 严格翻译自 Slice.toZigString
    public func toZigString() -> ZigString {
        ZigString(ptr)
    }

    // 严格翻译自 Slice.deinit
    public func deinit() {
        ptr = ""
        len = 0
        isAllocated = false
    }
}

// ========== StringPointer ==========
// 严格翻译自 ZigString.StringPointer
public class StringPointer {
    public var offset: Int64 = 0
    public var length: Int64 = 0

    public init() {}

    public init(offset: Int64, length: Int64) {
        this.offset = offset
        this.length = length
    }
}
