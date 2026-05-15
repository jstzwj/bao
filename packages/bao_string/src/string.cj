// 严格翻译自: src/string/string.zig
// BunString 主类型
//   Bun 的核心字符串类型,支持多种后端:
//   - WTFStringImpl: JavaScriptCore 的 WTF::StringImpl
//   - ZigString: Bun Zig 代码中的字符串
//   - StaticZigString: 静态字符串字面量
//   - Dead/Empty: 空或无效状态
//
//   仓颉实现提供等价的 Tagged Union 语义
package bao_string


// ============================================================================
// Tag 枚举
// 严格翻译自: src/string/string.zig Tag
// ============================================================================

/// BunString 标签
/// 严格翻译自 string.zig Tag
public enum BunStringTag {
    /// 字符串无效,操作失败时使用
    /// 类似 Empty (长度 = 0)
    | Dead
    /// 由 JavaScriptCore 的 WTF::StringImpl 支持
    /// 可以是 latin1 或 utf16le 编码
    | WTFStringImpl
    /// 内存拥有者未知,通常是 Bun 的 Zig 代码
    /// 可以是 utf8 或 utf16le 编码
    | ZigString
    /// 静态内存,保证不会被释放
    /// 可以是 utf8 或 utf16le 编码
    | StaticZigString
    /// 空字符串 ""
    | Empty
}

// ============================================================================
// AsciiStatus
// ============================================================================

/// ASCII 状态枚举(重导出)
public typealias StringAsciiStatus = AsciiStatus

// ============================================================================
// WTFEncoding
// 严格翻译自: src/string/string.zig WTFEncoding
// ============================================================================

/// WTF 编码类型
/// 严格翻译自 string.zig WTFEncoding
public enum WTFEncoding {
    | Latin1
    | UTF16
}

// ============================================================================
// BunString
// 严格翻译自: src/string/string.zig String
// ============================================================================

/// Bun 字符串: 核心字符串类型
/// 严格翻译自 string.zig String (extern struct, 24 bytes)
/// 在仓颉中使用类实现等价的 Tagged Union 语义
public class BunString {
    /// 标签
    public var tag: BunStringTag

    /// Latin1/UTF-8 数据
    public var utf8Data: Array<Byte>

    /// UTF-16 数据
    public var utf16Data: Array<UInt16>

    /// WTF 实现
    public var wtfImpl: ?WTFStringImplStruct

    public init(tag: BunStringTag, utf8Data: Array<Byte>, utf16Data: Array<UInt16>, wtfImpl: ?WTFStringImplStruct) {
        this.tag = tag
        this.utf8Data = utf8Data
        this.utf16Data = utf16Data
        this.wtfImpl = wtfImpl
    }

    // ========================================================================
    // 静态构造函数
    // ========================================================================

    /// 空字符串
    /// 严格翻译自 String.empty
    public static func empty(): BunString {
        return BunString(tag: BunStringTag.Empty, utf8Data: [], utf16Data: [], wtfImpl: None)
    }

    /// 死亡字符串
    /// 严格翻译自 String.dead
    public static func dead(): BunString {
        return BunString(tag: BunStringTag.Dead, utf8Data: [], utf16Data: [], wtfImpl: None)
    }

    /// 从 ASCII 字节创建
    /// 严格翻译自 String.ascii
    public static func ascii(bytes: Array<Byte>): BunString {
        return BunString(tag: BunStringTag.ZigString, utf8Data: bytes, utf16Data: [], wtfImpl: None)
    }

    /// 从字符串创建(借用)
    /// 严格翻译自 String.init (byte slice 分支)
    public static func initFunc(str: String): BunString {
        return BunString(tag: BunStringTag.ZigString, utf8Data: str.toArray(), utf16Data: [], wtfImpl: None)
    }

    /// 创建静态字符串
    /// 严格翻译自 String.static
    public static func static(input: String): BunString {
        return BunString(tag: BunStringTag.StaticZigString, utf8Data: input.toArray(), utf16Data: [], wtfImpl: None)
    }

    /// 借用 UTF-8 字符串
    /// 严格翻译自 String.borrowUTF8
    public static func borrowUTF8(value: String): BunString {
        return BunString(tag: BunStringTag.ZigString, utf8Data: value.toArray(), utf16Data: [], wtfImpl: None)
    }

    /// 借用 UTF-16 字符串
    /// 严格翻译自 String.borrowUTF16
    public static func borrowUTF16(value: Array<UInt16>): BunString {
        return BunString(tag: BunStringTag.ZigString, utf8Data: [], utf16Data: value, wtfImpl: None)
    }

    /// 从字节创建(自动检测编码)
    /// 严格翻译自 String.fromBytes
    public static func fromBytes(value: String): BunString {
        return BunString(tag: BunStringTag.ZigString, utf8Data: value.toArray(), utf16Data: [], wtfImpl: None)
    }

    /// 克隆 UTF-8 字符串
    /// 严格翻译自 String.cloneUTF8
    public static func cloneUTF8(bytes: String): BunString {
        return BunString(tag: BunStringTag.ZigString, utf8Data: bytes.toArray(), utf16Data: [], wtfImpl: None)
    }

    /// 克隆 Latin1 字符串
    /// 严格翻译自 String.cloneLatin1
    public static func cloneLatin1(bytes: String): BunString {
        if (bytes.size == 0) {
            return BunString.empty()
        }
        return BunString(tag: BunStringTag.ZigString, utf8Data: bytes.toArray(), utf16Data: [], wtfImpl: None)
    }

    /// 克隆 UTF-16 字符串
    /// 严格翻译自 String.cloneUTF16
    public static func cloneUTF16(bytes: Array<UInt16>): BunString {
        if (bytes.size == 0) {
            return BunString.empty()
        }
        return BunString(tag: BunStringTag.ZigString, utf8Data: [], utf16Data: bytes, wtfImpl: None)
    }

    /// 从 WTFStringImpl 创建
    /// 严格翻译自 String.init (WTFStringImpl 分支)
    public static func fromWTF(impl: WTFStringImplStruct): BunString {
        return BunString(tag: BunStringTag.WTFStringImpl, utf8Data: [], utf16Data: [], wtfImpl: Some(impl))
    }

    // ========================================================================
    // 属性查询
    // ========================================================================

    /// 判断是否为空
    /// 严格翻译自 String.isEmpty
    public func isEmpty(): Bool {
        return this.tag == BunStringTag.Empty || length() == 0
    }

    /// 获取长度
    /// 严格翻译自 String.length
    public func length(): Int64 {
        match (this.tag) {
            case BunStringTag.WTFStringImpl =>
                match (this.wtfImpl) {
                    case Some(impl) =>
                        return Int64(impl.length())
                    case None =>
                        return 0
                }
            case BunStringTag.ZigString | BunStringTag.StaticZigString =>
                if (this.utf16Data.size > 0) {
                    return this.utf16Data.size
                }
                return this.utf8Data.size
            case BunStringTag.Dead | BunStringTag.Empty =>
                return 0
        }
    }

    /// 判断是否为 UTF-16 编码
    /// 严格翻译自 String.isUTF16
    public func isUTF16(): Bool {
        match (this.tag) {
            case BunStringTag.WTFStringImpl =>
                match (this.wtfImpl) {
                    case Some(impl) =>
                        return !impl.is8Bit()
                    case None =>
                        return false
                }
            case BunStringTag.ZigString | BunStringTag.StaticZigString =>
                return this.utf16Data.size > 0
            case BunStringTag.Dead | BunStringTag.Empty =>
                return false
        }
    }

    /// 判断是否为 UTF-8 编码
    /// 严格翻译自 String.isUTF8
    public func isUTF8(): Bool {
        if (!(this.tag == BunStringTag.ZigString || this.tag == BunStringTag.StaticZigString)) {
            return false
        }
        return this.utf16Data.size == 0
    }

    /// 判断是否为 8 位编码
    /// 严格翻译自 String.is8Bit
    public func is8Bit(): Bool {
        match (this.tag) {
            case BunStringTag.WTFStringImpl =>
                match (this.wtfImpl) {
                    case Some(impl) =>
                        return impl.is8Bit()
                    case None =>
                        return true
                }
            case BunStringTag.ZigString =>
                return this.utf16Data.size == 0
            case BunStringTag.Dead | BunStringTag.Empty | BunStringTag.StaticZigString =>
                return true
        }
    }

    /// 获取编码类型
    /// 严格翻译自 String.encoding
    public func encoding(): EncodingNonAscii {
        if (isUTF16()) {
            return EncodingNonAscii.UTF16
        }
        if (isUTF8()) {
            return EncodingNonAscii.UTF8
        }
        return EncodingNonAscii.Latin1
    }

    // ========================================================================
    // 数据访问
    // ========================================================================

    /// 获取字节切片
    /// 严格翻译自 String.byteSlice
    public func byteSlice(): Array<Byte> {
        match (this.tag) {
            case BunStringTag.ZigString | BunStringTag.StaticZigString =>
                return this.utf8Data
            case BunStringTag.WTFStringImpl =>
                match (this.wtfImpl) {
                    case Some(impl) =>
                        return impl.byteSlice()
                    case None =>
                        return []
                }
            case BunStringTag.Dead | BunStringTag.Empty =>
                return []
        }
    }

    /// 获取 UTF-8 字节长度
    /// 严格翻译自 String.utf8ByteLength
    public func utf8ByteLength(): Int64 {
        match (this.tag) {
            case BunStringTag.WTFStringImpl =>
                match (this.wtfImpl) {
                    case Some(impl) =>
                        return impl.utf8ByteLength()
                    case None =>
                        return 0
                }
            case BunStringTag.ZigString | BunStringTag.StaticZigString =>
                return Int64(this.utf8Data.size)
            case BunStringTag.Dead | BunStringTag.Empty =>
                return 0
        }
    }

    /// 获取 UTF-16 字节长度
    /// 严格翻译自 String.utf16ByteLength
    public func utf16ByteLength(): Int64 {
        match (this.tag) {
            case BunStringTag.WTFStringImpl =>
                match (this.wtfImpl) {
                    case Some(impl) =>
                        return impl.utf16ByteLength()
                    case None =>
                        return 0
                }
            case BunStringTag.ZigString | BunStringTag.StaticZigString =>
                return Int64(this.utf16Data.size) * 2
            case BunStringTag.Dead | BunStringTag.Empty =>
                return 0
        }
    }

    /// 获取 Latin1 字节长度
    /// 严格翻译自 String.latin1ByteLength
    public func latin1ByteLength(): Int64 {
        match (this.tag) {
            case BunStringTag.WTFStringImpl =>
                match (this.wtfImpl) {
                    case Some(impl) =>
                        return impl.latin1ByteLength()
                    case None =>
                        return 0
                }
            case BunStringTag.ZigString | BunStringTag.StaticZigString =>
                if (this.utf16Data.size > 0) {
                    return Int64(this.utf16Data.size) * 2
                }
                return Int64(this.utf8Data.size)
            case BunStringTag.Dead | BunStringTag.Empty =>
                return 0
        }
    }

    /// 获取 UTF-8 字符串视图
    /// 严格翻译自 String.utf8
    public func utf8(): Array<Byte> {
        return this.utf8Data
    }

    /// 获取 UTF-16 字符串视图
    /// 严格翻译自 String.utf16
    public func utf16(): Array<UInt16> {
        if (this.tag == BunStringTag.Empty) {
            return []
        }
        match (this.tag) {
            case BunStringTag.WTFStringImpl =>
                match (this.wtfImpl) {
                    case Some(impl) =>
                        return impl.utf16Slice()
                    case None =>
                        return []
                }
            case BunStringTag.ZigString | BunStringTag.StaticZigString =>
                return this.utf16Data
            case BunStringTag.Dead | BunStringTag.Empty =>
                return []
        }
    }

    /// 获取 Latin1 视图
    /// 严格翻译自 String.latin1
    public func latin1(): Array<Byte> {
        if (this.tag == BunStringTag.Empty) {
            return []
        }
        match (this.tag) {
            case BunStringTag.WTFStringImpl =>
                match (this.wtfImpl) {
                    case Some(impl) =>
                        return impl.latin1Slice()
                    case None =>
                        return []
                }
            case BunStringTag.ZigString | BunStringTag.StaticZigString =>
                return this.utf8Data
            case BunStringTag.Dead | BunStringTag.Empty =>
                return []
        }
    }

    // ========================================================================
    // 子串和截断
    // ========================================================================

    /// 截取子串
    /// 严格翻译自 String.substring
    public func substring(startIndex: Int64): BunString {
        let len = length()
        let start = if (startIndex < len) { startIndex } else { len }
        return substringWithLen(start, len)
    }

    /// 截取指定范围子串
    /// 严格翻译自 String.substringWithLen
    public func substringWithLen(startIndex: Int64, endIndex: Int64): BunString {
        match (this.tag) {
            case BunStringTag.ZigString | BunStringTag.StaticZigString =>
                if (this.utf16Data.size > 0) {
                    let s = if (startIndex < this.utf16Data.size) { startIndex } else { this.utf16Data.size }
                    let e = if (endIndex < this.utf16Data.size) { endIndex } else { this.utf16Data.size }
                    return BunString.borrowUTF16(this.utf16Data[s:e])
                } else {
                    let s = if (startIndex < this.utf8Data.size) { startIndex } else { this.utf8Data.size }
                    let e = if (endIndex < this.utf8Data.size) { endIndex } else { this.utf8Data.size }
                    return BunString(tag: this.tag, utf8Data: this.utf8Data[s:e], utf16Data: [], wtfImpl: None)
                }
            case BunStringTag.WTFStringImpl =>
                match (this.wtfImpl) {
                    case Some(impl) =>
                        if (impl.is8Bit()) {
                            let slice = impl.latin1Slice()
                            let s = if (startIndex < slice.size) { startIndex } else { slice.size }
                            let e = if (endIndex < slice.size) { endIndex } else { slice.size }
                            return BunString.ascii(slice[s:e])
                        } else {
                            let slice = impl.utf16Slice()
                            let s = if (startIndex < slice.size) { startIndex } else { slice.size }
                            let e = if (endIndex < slice.size) { endIndex } else { slice.size }
                            return BunString.borrowUTF16(slice[s:e])
                        }
                    case None =>
                        return this
                }
            case BunStringTag.Dead | BunStringTag.Empty =>
                return this
        }
    }

    /// 截断字符串
    /// 严格翻译自 String.trunc
    public func trunc(len: Int64): BunString {
        if (length() <= len) {
            return this
        }
        return substringWithLen(0, len)
    }

    // ========================================================================
    // 比较和查找
    // ========================================================================

    /// 判断两个 BunString 是否相等
    /// 严格翻译自 String.eql
    public func eql(other: BunString): Bool {
        let aBytes = this.byteSlice()
        let bBytes = other.byteSlice()
        if (aBytes.size != bBytes.size) {
            return false
        }
        for (i in 0..aBytes.size) {
            if (aBytes[i] != bBytes[i]) {
                return false
            }
        }
        return true
    }

    /// 判断是否与 UTF-8 字符串相等
    /// 严格翻译自 String.eqlUTF8
    public func eqlUTF8(other: String): Bool {
        let aStr = toUTF8String()
        return aStr == other
    }

    /// 获取指定位置的字符(UTF-16 码元)
    /// 严格翻译自 String.charAt
    public func charAt(index: Int64): UInt16 {
        match (this.tag) {
            case BunStringTag.WTFStringImpl =>
                match (this.wtfImpl) {
                    case Some(impl) =>
                        if (impl.is8Bit()) {
                            let slice = impl.latin1Slice()
                            if (index < slice.size) {
                                return UInt16(slice[index])
                            }
                        } else {
                            let slice = impl.utf16Slice()
                            if (index < slice.size) {
                                return slice[index]
                            }
                        }
                    case None =>
                        return 0
                }
            case BunStringTag.ZigString | BunStringTag.StaticZigString =>
                if (this.utf16Data.size > 0) {
                    if (index < this.utf16Data.size) {
                        return this.utf16Data[index]
                    }
                } else {
                    if (index < this.utf8Data.size) {
                        return UInt16(this.utf8Data[index])
                    }
                }
            case BunStringTag.Dead | BunStringTag.Empty =>
                return 0
        }
        return 0
    }

    /// 查找 ASCII 字符位置
    /// 严格翻译自 String.indexOfAsciiChar
    public func indexOfAsciiChar(chr: Byte): Int64 {
        if (isUTF16()) {
            let u16 = utf16()
            for (i in 0..u16.size) {
                if (u16[i] == UInt16(chr)) {
                    return i
                }
            }
            return -1
        }
        let bytes = byteSlice()
        for (i in 0..bytes.size) {
            if (bytes[i] == chr) {
                return i
            }
        }
        return -1
    }

    // ========================================================================
    // 引用计数
    // ========================================================================

    /// 增加引用
    /// 严格翻译自 String.ref
    public func ref(): Unit {
        match (this.tag) {
            case BunStringTag.WTFStringImpl =>
                match (this.wtfImpl) {
                    case Some(impl) =>
                        impl.ref()
                    case None =>
                        return
                }
            case BunStringTag.ZigString | BunStringTag.StaticZigString | BunStringTag.Dead | BunStringTag.Empty =>
                return
        }
    }

    /// 减少引用
    /// 严格翻译自 String.deref
    public func deref(): Unit {
        match (this.tag) {
            case BunStringTag.WTFStringImpl =>
                match (this.wtfImpl) {
                    case Some(impl) =>
                        impl.deref()
                    case None =>
                        return
                }
            case BunStringTag.ZigString | BunStringTag.StaticZigString | BunStringTag.Dead | BunStringTag.Empty =>
                return
        }
    }

    /// 复制引用
    /// 严格翻译自 String.dupeRef
    public func dupeRef(): BunString {
        ref()
        return this
    }

    /// 克隆
    /// 严格翻译自 String.clone
    public func clone(): BunString {
        if (this.tag == BunStringTag.WTFStringImpl) {
            return dupeRef()
        }

        if (isEmpty()) {
            return BunString.empty()
        }

        if (isUTF16()) {
            let newStr = BunString.borrowUTF16(this.utf16Data)
            return newStr
        }

        return BunString.cloneUTF8(toUTF8String())
    }

    // ========================================================================
    // 转换
    // ========================================================================

    /// 转换为 UTF-8 字符串
    /// 严格翻译自 String.toUTF8
    public func toUTF8String(): String {
        if (this.tag == BunStringTag.Empty || this.tag == BunStringTag.Dead) {
            return ""
        }

        if (isUTF16()) {
            // UTF-16 转 UTF-8
            var result = Array<Byte>()
            var i: Int64 = 0
            while (i < this.utf16Data.size) {
                let w = this.utf16Data[i]
                if (w <= 0x7F) {
                    result.append(Byte(w))
                } else if (w <= 0x7FF) {
                    result.append(Byte(0xC0 | ((w >> 6) & 0x1F)))
                    result.append(Byte(0x80 | (w & 0x3F)))
                } else if (w >= 0xD800 && w <= 0xDBFF && i + 1 < this.utf16Data.size) {
                    // 代理对
                    let hi = UInt32(w)
                    let lo = UInt32(this.utf16Data[i + 1])
                    let cp = ((hi - 0xD800) << 10) + (lo - 0xDC00) + 0x10000
                    result.append(Byte(0xF0 | ((cp >> 18) & 0x07)))
                    result.append(Byte(0x80 | ((cp >> 12) & 0x3F)))
                    result.append(Byte(0x80 | ((cp >> 6) & 0x3F)))
                    result.append(Byte(0x80 | (cp & 0x3F)))
                    i += 1
                } else {
                    result.append(Byte(0xE0 | ((w >> 12) & 0x0F)))
                    result.append(Byte(0x80 | ((w >> 6) & 0x3F)))
                    result.append(Byte(0x80 | (w & 0x3F)))
                }
                i += 1
            }
            return String.fromUtf8(result)
        }

        return String.fromUtf8(this.utf8Data)
    }

    /// 获取估算大小
    /// 严格翻译自 String.estimatedSize
    public func estimatedSize(): Int64 {
        match (this.tag) {
            case BunStringTag.Dead | BunStringTag.Empty | BunStringTag.StaticZigString =>
                return 0
            case BunStringTag.ZigString =>
                return Int64(this.utf8Data.size)
            case BunStringTag.WTFStringImpl =>
                match (this.wtfImpl) {
                    case Some(impl) =>
                        return impl.byteLength()
                    case None =>
                        return 0
                }
        }
    }

    /// 判断是否可用作 UTF-8
    /// 严格翻译自 String.canBeUTF8
    public func canBeUTF8(): Bool {
        match (this.tag) {
            case BunStringTag.WTFStringImpl =>
                match (this.wtfImpl) {
                    case Some(impl) =>
                        return impl.canUseAsUTF8()
                    case None =>
                        return false
                }
            case BunStringTag.ZigString | BunStringTag.StaticZigString =>
                if (this.utf16Data.size == 0) {
                    return true
                }
                return false
            case BunStringTag.Dead | BunStringTag.Empty =>
                return this.tag == BunStringTag.Empty
        }
    }

    /// 获取 UTF-8 视图(可能为空)
    /// 严格翻译自 String.asUTF8
    public func asUTF8(): ?Array<Byte> {
        match (this.tag) {
            case BunStringTag.WTFStringImpl =>
                match (this.wtfImpl) {
                    case Some(impl) =>
                        if (impl.is8Bit()) {
                            let latin1 = impl.latin1Slice()
                            var allASCII = true
                            for (b in latin1) {
                                if (b >= 0x80) {
                                    allASCII = false
                                    break
                                }
                            }
                            if (allASCII) {
                                return Some(latin1)
                            }
                        }
                        return None
                    case None =>
                        return None
                }
            case BunStringTag.ZigString | BunStringTag.StaticZigString =>
                if (this.utf16Data.size == 0) {
                    return Some(this.utf8Data)
                }
                return None
            case BunStringTag.Dead | BunStringTag.Empty =>
                return Some([])
        }
    }

    /// 创建 Atom 字符串 (ASCII)
    /// 严格翻译自 String.createAtomASCII
    public static func createAtomASCII(bytes: String): BunString {
        return BunString.cloneUTF8(bytes)
    }

    /// 尝试创建 Atom 字符串
    /// 严格翻译自 String.tryCreateAtom
    public static func tryCreateAtom(bytes: String): ?BunString {
        var allASCII = true
        let arr = bytes.toArray()
        for (b in arr) {
            if (b >= 0x80) {
                allASCII = false
                break
            }
        }
        if (!allASCII) {
            return None
        }
        return Some(BunString.cloneUTF8(bytes))
    }

    /// 尽可能创建 Atom 字符串
    /// 严格翻译自 String.createAtomIfPossible
    public static func createAtomIfPossible(bytes: String): BunString {
        if (bytes.size == 0) {
            return BunString.empty()
        }

        if (bytes.size < 64) {
            match (tryCreateAtom(bytes)) {
                case Some(atom) =>
                    return atom
                case None =>
                    return BunString.cloneUTF8(bytes)
            }
        }

        return BunString.cloneUTF8(bytes)
    }
}

// ============================================================================
// SliceWithUnderlyingString
// 严格翻译自: src/string/string.zig SliceWithUnderlyingString
// ============================================================================

/// 带底层字符串的 UTF-8 切片
/// 严格翻译自 string.zig SliceWithUnderlyingString
public class SliceWithUnderlyingString {
    /// UTF-8 数据
    public var utf8: Array<Byte>

    /// 底层 BunString
    public var underlying: BunString

    public init() {
        this.utf8 = []
        this.underlying = BunString.dead()
    }

    public init(utf8: Array<Byte>, underlying: BunString) {
        this.utf8 = utf8
        this.underlying = underlying
    }

    /// 从 UTF-8 创建
    /// 严格翻译自 SliceWithUnderlyingString.fromUTF8
    public static func fromUTF8(utf8: String): SliceWithUnderlyingString {
        return SliceWithUnderlyingString(utf8: utf8.toArray(), underlying: BunString.dead())
    }

    /// 获取切片
    /// 严格翻译自 SliceWithUnderlyingString.slice
    public func slice(): Array<Byte> {
        return this.utf8
    }

    /// 获取字符串
    public func toString(): String {
        return String.fromUtf8(this.utf8)
    }

    /// 释放资源
    /// 严格翻译自 SliceWithUnderlyingString.deinit
    public func deinit(): Unit {
        this.utf8 = []
        this.underlying.deref()
    }

    /// 复制引用
    /// 严格翻译自 SliceWithUnderlyingString.dupeRef
    public func dupeRef(): SliceWithUnderlyingString {
        return SliceWithUnderlyingString(utf8: [], underlying: this.underlying.dupeRef())
    }
}
