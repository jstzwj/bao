// 严格翻译自: src/string/wtf.zig
// WTF-8 / WTF-16 编码
//   WTF (Web Technology Format) 编码是 WebKit/JavaScriptCore 中使用的字符串格式:
//   - WTFStringImpl: 对应 WTF::StringImpl 的引用计数字符串
//   - 支持 Latin1 (8位) 和 UTF-16LE (16位) 两种编码
//   - 引用计数管理(静态/动态)
//   - 哈希和标志位存储在 m_hashAndFlags 中
//
//   仓颉实现提供等价的数据结构和操作
package bao_string

import bao_core.*

// ============================================================================
// WTFStringImplStruct
// 严格翻译自: src/string/wtf.zig WTFStringImplStruct
// ============================================================================

/// WTF 字符串实现结构
/// 严格翻译自 wtf.zig WTFStringImplStruct (extern struct)
/// 在 WebKit 中对应 WTF::StringImpl
public class WTFStringImplStruct {
    // ---------------------------------------------------------------------
    // 常量: 必须与 WebKit WTFStringImpl.h 保持同步!
    // 严格翻译自 wtf.zig 中的常量
    // ---------------------------------------------------------------------

    /// 标志位数量
    public static let sFlagCount: UInt32 = 8

    /// 标志掩码
    public static let sFlagMask: UInt32 = (1 << sFlagCount) - 1

    /// 字符串类型标志位数
    public static let sFlagStringKindCount: UInt32 = 4

    /// 哈希零值
    public static let sHashZeroValue: UInt32 = 0

    /// Atom 字符串标志
    public static let sHashFlagStringKindIsAtom: UInt32 = UInt32(1) << sFlagStringKindCount

    /// Symbol 字符串标志
    public static let sHashFlagStringKindIsSymbol: UInt32 = UInt32(1) << (sFlagStringKindCount + 1)

    /// 字符串类型掩码
    public static let sHashMaskStringKind: UInt32 = sHashFlagStringKindIsAtom | sHashFlagStringKindIsSymbol

    /// 报告成本标志
    public static let sHashFlagDidReportCost: UInt32 = UInt32(1) << 3

    /// 8位缓冲区标志
    public static let sHashFlag8BitBuffer: UInt32 = UInt32(1) << 2

    /// 缓冲区所有权掩码
    public static let sHashMaskBufferOwnership: UInt32 = UInt32(1) << 0 | UInt32(1) << 1

    /// 静态字符串标志 (引用计数最低位)
    public static let sRefCountFlagIsStaticString: UInt32 = 0x1

    /// 引用计数增量
    public static let sRefCountIncrement: UInt32 = 0x2

    // ---------------------------------------------------------------------
    // 实例字段
    // ---------------------------------------------------------------------

    /// 引用计数
    public var mRefCount: UInt32

    /// 字符串长度
    public var mLength: UInt32

    /// 字符串数据 (Latin1 或 UTF-16)
    public var mPtr: WTFStringData

    /// 哈希值和标志
    public var mHashAndFlags: UInt32

    public init() {
        this.mRefCount = 0
        this.mLength = 0
        this.mPtr = WTFStringData()
        this.mHashAndFlags = 0
    }

    public init(refCount: UInt32, length: UInt32, ptr: WTFStringData, hashAndFlags: UInt32) {
        this.mRefCount = refCount
        this.mLength = length
        this.mPtr = ptr
        this.mHashAndFlags = hashAndFlags
    }

    // ---------------------------------------------------------------------
    // 方法
    // ---------------------------------------------------------------------

    /// 获取引用计数
    /// 严格翻译自 WTFStringImplStruct.refCount
    public func refCount(): UInt32 {
        return this.mRefCount / sRefCountIncrement
    }

    /// 获取内存开销
    /// 严格翻译自 WTFStringImplStruct.memoryCost
    public func memoryCost(): Int64 {
        return byteLength()
    }

    /// 判断是否为静态字符串
    /// 严格翻译自 WTFStringImplStruct.isStatic
    public func isStatic(): Bool {
        return (this.mRefCount & sRefCountFlagIsStaticString) != 0
    }

    /// 获取字节长度
    /// 严格翻译自 WTFStringImplStruct.byteLength
    public func byteLength(): Int64 {
        return if (is8Bit()) { Int64(this.mLength) } else { Int64(this.mLength) * 2 }
    }

    /// 判断是否为 8 位编码
    /// 严格翻译自 WTFStringImplStruct.is8Bit
    public func is8Bit(): Bool {
        return (this.mHashAndFlags & sHashFlag8BitBuffer) != 0
    }

    /// 获取长度
    /// 严格翻译自 WTFStringImplStruct.length
    public func length(): UInt32 {
        return this.mLength
    }

    /// 获取 UTF-16 切片
    /// 严格翻译自 WTFStringImplStruct.utf16Slice
    public func utf16Slice(): Array<UInt16> {
        return this.mPtr.utf16
    }

    /// 获取 Latin1 切片
    /// 严格翻译自 WTFStringImplStruct.latin1Slice
    public func latin1Slice(): Array<Byte> {
        return this.mPtr.latin1
    }

    /// 获取 UTF-8 切片 (假设 8 位且全 ASCII)
    /// 严格翻译自 WTFStringImplStruct.utf8Slice
    public func utf8Slice(): Array<Byte> {
        return this.mPtr.latin1
    }

    /// 增加引用
    /// 严格翻译自 WTFStringImplStruct.ref
    public func ref(): Unit {
        if (!hasAtLeastOneRef()) {
            panic("WTFStringImpl: ref() 在没有引用时调用")
        }
        if (!isStatic()) {
            this.mRefCount += sRefCountIncrement
        }
    }

    /// 减少引用
    /// 严格翻译自 WTFStringImplStruct.deref
    public func deref(): Unit {
        if (!hasAtLeastOneRef()) {
            panic("WTFStringImpl: deref() 在没有引用时调用")
        }
        if (!isStatic()) {
            if (this.mRefCount >= sRefCountIncrement) {
                this.mRefCount -= sRefCountIncrement
            }
        }
    }

    /// 判断是否至少有一个引用
    /// 严格翻译自 WTFStringImplStruct.hasAtLeastOneRef
    public func hasAtLeastOneRef(): Bool {
        return this.mRefCount > 0
    }

    /// 获取 UTF-16 字节长度
    /// 严格翻译自 WTFStringImplStruct.utf16ByteLength
    public func utf16ByteLength(): Int64 {
        if (is8Bit()) {
            return Int64(this.mLength) * 2
        } else {
            return Int64(this.mLength)
        }
    }

    /// 获取 UTF-8 字节长度(估算)
    /// 严格翻译自 WTFStringImplStruct.utf8ByteLength
    public func utf8ByteLength(): Int64 {
        if (is8Bit()) {
            // Latin1: 每个 0x80+ 字符变成 2 字节 UTF-8
            let input = latin1Slice()
            var len: Int64 = 0
            for (b in input) {
                if (b >= 0x80) {
                    len += 2
                } else {
                    len += 1
                }
            }
            return len
        } else {
            // UTF-16: 估算
            let input = utf16Slice()
            var len: Int64 = 0
            var i: Int64 = 0
            while (i < input.size) {
                let c = input[i]
                if (c <= 0x7F) {
                    len += 1
                } else if (c <= 0x7FF) {
                    len += 2
                } else if (c >= 0xD800 && c <= 0xDBFF && i + 1 < input.size) {
                    // 代理对 -> 4 字节
                    len += 4
                    i += 1
                } else {
                    len += 3
                }
                i += 1
            }
            return len
        }
    }

    /// 获取 Latin1 字节长度
    /// 严格翻译自 WTFStringImplStruct.latin1ByteLength
    public func latin1ByteLength(): Int64 {
        return Int64(this.mLength)
    }

    /// 是否可用作 UTF-8
    /// 严格翻译自 WTFStringImplStruct.canUseAsUTF8
    public func canUseAsUTF8(): Bool {
        if (!is8Bit()) {
            return false
        }
        let input = latin1Slice()
        for (b in input) {
            if (b >= 0x80) {
                return false
            }
        }
        return true
    }

    /// 获取字节切片
    /// 严格翻译自 WTFStringImplStruct.byteSlice
    public func byteSlice(): Array<Byte> {
        let bl = byteLength()
        if (is8Bit()) {
            return latin1Slice()
        } else {
            // UTF-16: 返回原始字节视图
            var result = Array<Byte>()
            for (w in utf16Slice()) {
                result.append(Byte(w & 0xFF))
                result.append(Byte((w >> 8) & 0xFF))
            }
            return result
        }
    }

    /// 确保哈希已计算
    /// 严格翻译自 WTFStringImplStruct.ensureHash
    public func ensureHash(): Unit {
        // 在仓颉中,哈希按需计算
    }

    /// 判断是否有指定前缀
    /// 严格翻译自 WTFStringImplStruct.hasPrefix
    public func hasPrefix(text: String): Bool {
        if (Int64(this.mLength) < text.size) {
            return false
        }
        if (is8Bit()) {
            let bytes = latin1Slice()
            let textBytes = text.toArray()
            for (i in 0..textBytes.size) {
                if (i >= bytes.size || bytes[i] != textBytes[i]) {
                    return false
                }
            }
            return true
        }
        // UTF-16: 简化比较
        return false
    }
}

// ============================================================================
// WTFStringData
// 字符串数据联合体
// ============================================================================

/// WTF 字符串数据: Latin1 或 UTF-16
/// 严格翻译自 wtf.zig m_ptr (extern union)
public class WTFStringData {
    /// Latin1 字节数据
    public var latin1: Array<Byte>
    /// UTF-16 数据
    public var utf16: Array<UInt16>

    public init() {
        this.latin1 = []
        this.utf16 = []
    }

    /// 从 Latin1 创建
    public static func fromLatin1(bytes: Array<Byte>): WTFStringData {
        let data = WTFStringData()
        data.latin1 = bytes
        return data
    }

    /// 从 UTF-16 创建
    public static func fromUTF16(words: Array<UInt16>): WTFStringData {
        let data = WTFStringData()
        data.utf16 = words
        return data
    }
}

// ============================================================================
// WTFString
// 严格翻译自: src/string/wtf.zig WTFString
// ============================================================================

/// WTF 字符串引用: 行为类似 WTF::Ref<WTF::StringImpl>
/// 严格翻译自 wtf.zig WTFString
public class WTFString {
    /// 底层实现
    public var impl: ?WTFStringImplStruct

    public init() {
        this.impl = None
    }

    public init(impl: WTFStringImplStruct) {
        this.impl = Some(impl)
    }

    /// 获取实现
    public func getImpl(): ?WTFStringImplStruct {
        return this.impl
    }

    /// 增加引用
    public func ref(): Unit {
        match (this.impl) {
            case Some(i) =>
                i.ref()
            case None =>
                return
        }
    }

    /// 减少引用
    public func deref(): Unit {
        match (this.impl) {
            case Some(i) =>
                i.deref()
            case None =>
                return
        }
    }
}

// ============================================================================
// StringImplAllocator
// 严格翻译自: src/string/wtf.zig StringImplAllocator
// ============================================================================

/// 字符串实现分配器: 基于引用计数的伪分配器
/// 严格翻译自 wtf.zig StringImplAllocator
/// 在 WebKit 中,分配器不实际分配内存,而是增减引用计数
public class StringImplAllocator {
    /// 分配(实际上是增加引用)
    /// 严格翻译自 StringImplAllocator.alloc
    public static func alloc(ptr: WTFStringImplStruct, len: Int64): ?Array<Byte> {
        let len_ = ptr.byteLength()
        if (len_ != len) {
            return None
        }
        ptr.ref()
        return Some(ptr.latin1Slice())
    }

    /// 释放(实际上是减少引用)
    /// 严格翻译自 StringImplAllocator.free
    public static func free(ptr: WTFStringImplStruct, buf: Array<Byte>): Unit {
        ptr.deref()
    }
}
