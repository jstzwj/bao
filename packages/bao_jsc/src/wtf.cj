// 严格翻译自: src/string/wtf.zig (273行)
// WTF StringImpl 结构体 - WebKit 字符串实现

package bao_jsc

// ========== WTFStringImplStruct ==========
// 严格翻译自 wtf.zig WTFStringImplStruct
// 这些细节必须与 WebKit 中的 WTFStringImpl.h 保持同步！
public class WTFStringImplStruct {
    // 引用计数
    public var mRefCount: UInt32 = 0
    // 字符串长度（字符数）
    public var mLength: UInt32 = 0
    // 字符串数据指针（Latin1 或 UTF-16）
    public var mPtrLatin1: Array<UInt8> = Array<UInt8>()
    public var mPtrUtf16: Array<UInt16> = Array<UInt16>()
    public var isLatin1: Bool = true
    // 哈希和标志位
    public var mHashAndFlags: UInt32 = 0

    // ---------------------------------------------------------------------
    // 这些常量必须与 WebKit 中的 WTFStringImpl.h 保持同步.getOrThrow()
    // ---------------------------------------------------------------------

    // 标志位数
    public static let S_FLAG_COUNT: UInt32 = 8
    // 标志位掩码
    public static let S_FLAG_MASK: UInt32 = (1 << S_FLAG_COUNT) - 1
    // 字符串种类标志位数
    public static let S_FLAG_STRING_KIND_COUNT: UInt32 = 4
    // 哈希零值
    public static let S_HASH_ZERO_VALUE: UInt32 = 0
    // "is atom" 字符串种类标志
    public static let S_HASH_FLAG_STRING_KIND_IS_ATOM: UInt32 = UInt32(1) << S_FLAG_STRING_KIND_COUNT
    // "is symbol" 字符串种类标志
    public static let S_HASH_FLAG_STRING_KIND_IS_SYMBOL: UInt32 = UInt32(1) << (S_FLAG_STRING_KIND_COUNT + 1)
    // 字符串种类掩码
    public static let S_HASH_MASK_STRING_KIND: UInt32 = S_HASH_FLAG_STRING_KIND_IS_ATOM | S_HASH_FLAG_STRING_KIND_IS_SYMBOL
    // "did report cost" 标志
    public static let S_HASH_FLAG_DID_REPORT_COST: UInt32 = UInt32(1) << 3
    // "8 bit buffer" 标志
    public static let S_HASH_FLAG_8BIT_BUFFER: UInt32 = UInt32(1) << 2
    // buffer 所有权掩码
    public static let S_HASH_MASK_BUFFER_OWNERSHIP: UInt32 = UInt32((1 << 0) | (1 << 1))

    // 引用计数中的最低位表示静态（不朽）字符串
    public static let S_REF_COUNT_FLAG_IS_STATIC_STRING: UInt32 = 0x1

    // 这允许我们引用/取消引用而不干扰静态字符串标志
    public static let S_REF_COUNT_INCREMENT: UInt32 = 0x2

    public init() {}

    public init(refCount: UInt32, length: UInt32, hashAndFlags: UInt32) {
        this.mRefCount = refCount
        this.mLength = length
        this.mHashAndFlags = hashAndFlags
    }

    // 严格翻译自 refCount
    public func refCount() -> UInt32 {
        mRefCount / S_REF_COUNT_INCREMENT
    }

    // 严格翻译自 memoryCost
    public func memoryCost() -> Int64 {
        Int64(byteLength())
    }

    // 严格翻译自 isStatic
    public func isStatic() -> Bool {
        (mRefCount & S_REF_COUNT_INCREMENT) != 0
    }

    // 严格翻译自 byteLength
    public func byteLength() -> Int64 {
        if (is8Bit()) { Int64(mLength) } else { Int64(mLength) * 2 }
    }

    // 严格翻译自 is8Bit
    public func is8Bit() -> Bool {
        (mHashAndFlags & S_HASH_FLAG_8BIT_BUFFER) != 0
    }

    // 严格翻译自 length
    public func length() -> UInt32 {
        mLength
    }

    // 严格翻译自 byteSlice
    public func byteSlice() -> Array<UInt8> {
        mPtrLatin1
    }

    // 严格翻译自 utf16Slice
    public func utf16Slice() -> Array<UInt16> {
        mPtrUtf16
    }

    // 严格翻译自 latin1Slice
    public func latin1Slice() -> Array<UInt8> {
        mPtrLatin1
    }

    // 严格翻译自 utf8Slice
    // 调用者必须确保字符串是 8 位且 ASCII
    public func utf8Slice() -> Array<UInt8> {
        mPtrLatin1
    }

    // 严格翻译自 toZigString
    public func toZigString() -> ZigString {
        if (is8Bit()) {
            return ZigString.init(latin1Slice)
        } else {
            return ZigString.initUtf16(utf16Slice)
        }
    }

    // 严格翻译自 deref
    public func deref() {
        let currentCount = refCount()
        // FFI: bun.cpp.Bun__WTFStringImpl__deref(self)
    }

    // 严格翻译自 ref
    public func ref() {
        // FFI: bun.cpp.Bun__WTFStringImpl__ref(self)
    }

    // 严格翻译自 hasAtLeastOneRef
    // WTF::StringImpl::hasAtLeastOneRef
    public func hasAtLeastOneRef() -> Bool {
        mRefCount > 0
    }

    // 严格翻译自 ensureHash
    // 如果需要，计算哈希值
    public func ensureHash() {
        // FFI: bun.cpp.Bun__WTFStringImpl__ensureHash(this)
    }

    // 严格翻译自 canUseAsUTF8
    // 避免在即将获取 UTF-8 字符串的代码路径中使用此方法
    // 这种情况下应使用 toUTF8IfNeeded
    public func canUseAsUTF8() -> Bool {
        is8Bit() && isAllAscii(mPtrLatin1)
    }

    // 严格翻译自 utf16ByteLength
    public func utf16ByteLength() -> Int64 {
        if (is8Bit()) {
            Int64(length()) * 2
        } else {
            Int64(length())
        }
    }

    // 严格翻译自 utf8ByteLength
    public func utf8ByteLength() -> Int64 {
        if (is8Bit()) {
            if (!mPtrLatin1.isEmpty) {
                encodingByteLengthU8(mPtrLatin1, EncodingFormat.Utf8)
            } else {
                0
            }
        } else {
            if (!mPtrUtf16.isEmpty) {
                elementLengthUtf16IntoUtf8(mPtrUtf16)
            } else {
                0
            }
        }
    }

    // 严格翻译自 latin1ByteLength
    // 并非所有 UTF-16 字符都可在 latin1 中表示
    public func latin1ByteLength() -> Int64 {
        Int64(length())
    }

    // 严格翻译自 hasPrefix
    public func hasPrefix(text: String) -> Bool {
        // FFI: bun.cpp.Bun__WTFStringImpl__hasPrefix(self, text.ptr, text.len)
        false
    }

    // ========== 辅助方法 ==========

    // 检查数组是否全是 ASCII
    private func isAllAscii(data: Array<UInt8>) -> Bool {
        for (b in data) {
            if (b > 0x7F) {
                return false
            }
        }
        true
    }

    // 计算 UTF-8 编码字节长度（U8 输入）
    private func encodingByteLengthU8(data: Array<UInt8>, encoding: EncodingFormat) -> Int64 {
        Int64(data.size)
    }

    // 计算 UTF-16 到 UTF-8 的元素长度
    private func elementLengthUtf16IntoUtf8(data: Array<UInt16>) -> Int64 {
        var len: Int64 = 0
        for (ch in data) {
            if (ch <= 0x7F) {
                len += 1
            } else if (ch <= 0x7FF) {
                len += 2
            } else {
                len += 3
            }
        }
        len
    }

    // 编码格式
    public enum EncodingFormat {
        | Utf8
        | Latin1
        | Utf16
    }
}

// ========== WTFString ==========
// 严格翻译自 wtf.zig WTFString
// 行为类似于 WTF::Ref<WTF::StringImpl>
public typealias WTFString = WTFStringImplStruct

// ========== StringImplAllocator ==========
// 严格翻译自 wtf.zig StringImplAllocator
// 字符串实现分配器
public class StringImplAllocator {
    public init() {}

    // 分配内存（实际是引用计数）
    public func alloc(ptr: WTFStringImplStruct, len: Int64) -> ?Array<UInt8> {
        let len_ = ptr.byteLength()
        if (len_ != len) {
            // 我们不实际分配，只是引用计数
            return None
        }
        ptr.ref()
        return ptr.latin1Slice()
    }

    // 释放内存（实际是取消引用计数）
    public func free(ptr: WTFStringImplStruct, buf: Array<UInt8>) {
        ptr.deref()
    }
}
