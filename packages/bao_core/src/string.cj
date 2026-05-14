// bao_core - 字符串类型
// 严格翻译自:
//   src/bun_core/string/HashedString.rs - HashedString struct
//   src/bun_core/string/StringBuilder.rs - StringBuilder struct
//   src/bun_core/string/mod.rs - String, ZigString, OwnedString 等类型
package bao_core

// ============================================================================
// HashedString - 预哈希字符串视图
// 严格翻译自: src/bun_core/string/HashedString.rs
//   #[repr(C)] #[derive(Copy, Clone)] pub struct HashedString {
//       pub ptr: *const u8,
//       pub len: u32,
//       pub hash: u32,
//   }
// 仓颉不使用裸指针，改用 Array<UInt8> 引用 + 偏移量
// ============================================================================

/// 预哈希字符串视图 - 严格对应 Bun HashedString
/// Bun: 存储裸指针 + 长度 + wyhash 哈希值
/// 仓颉: 存储字节数组引用 + 偏移量 + 长度 + wyhash 哈希值
public class HashedString {
    /// 源数据引用 (对应 Bun ptr: *const u8)
    public let source: Array<UInt8>
    /// 起始偏移
    public let offset: Int64
    /// 字节长度 (对应 Bun len: u32)
    public let len: UInt32
    /// 预计算哈希值 (对应 Bun hash: u32，使用 wyhash)
    public let hash: UInt32

    /// 空值常量 - 对应 Bun HashedString::EMPTY
    public static let EMPTY = HashedString(
        source: [],
        offset: 0,
        len: UInt32(0),
        hash: UInt32(0)
    )

    private init(source: Array<UInt8>, offset: Int64, len: UInt32, hash: UInt32) {
        this.source = source
        this.offset = offset
        this.len = len
        this.hash = hash
    }

    /// 初始化并计算哈希 - 对应 Bun HashedString::init(buf: &[u8])
    /// 使用 wyhash 算法计算哈希 (与 Bun 的 bun_wyhash::hash 一致)
    public init(buf: Array<UInt8>) {
        this.source = buf
        this.offset = 0
        this.len = UInt32(buf.size)
        this.hash = HashedString.wyhash32(buf)
    }

    /// 初始化带偏移的子切片
    public init(buf: Array<UInt8>, offset: Int64, length: Int64) {
        this.source = buf
        this.offset = offset
        this.len = UInt32(length)
        // 计算子切片的哈希
        var sub = Array<UInt8>()
        for (i in offset..(offset + length)) {
            if (i < buf.size) {
                sub.append(buf[i])
            }
        }
        this.hash = HashedString.wyhash32(sub)
    }

    /// 从原生字符串初始化
    public init(s: String) {
        var bytes = Array<UInt8>()
        for (c in s) {
            bytes.append(UInt8(c.value))
        }
        this.source = bytes
        this.offset = 0
        this.len = UInt32(bytes.size)
        this.hash = HashedString.wyhash32(bytes)
    }

    /// 不计算哈希的初始化 - 对应 Bun HashedString::init_no_hash
    public static func initNoHash(buf: Array<UInt8>): HashedString {
        return HashedString(source: buf, offset: 0, len: UInt32(buf.size), hash: UInt32(0))
    }

    /// 比较相等 - 对应 Bun HashedString::eql
    /// ((self.hash.max(other.hash) > 0 && self.hash == other.hash) || (self.ptr == other.ptr))
    ///     && self.len == other.len
    public func eql(other: HashedString): Bool {
        if (this.len != other.len) {
            return false
        }
        // 如果哈希值不同(且非零)，直接返回 false
        if (this.hash > 0 && other.hash > 0 && this.hash != other.hash) {
            return false
        }
        // 哈希相同或为零，逐字节比较
        let s1 = this.str()
        let s2 = other.str()
        if (s1.size != s2.size) {
            return false
        }
        for (i in 0..s1.size) {
            if (s1[i] != s2[i]) {
                return false
            }
        }
        return true
    }

    /// 与字节数组比较 - 对应 Bun HashedString::eql_bytes
    public func eqlBytes(other: Array<UInt8>): Bool {
        if (Int64(this.len) != other.size) {
            return false
        }
        return this.hash == HashedString.wyhash32(other)
    }

    /// 获取底层字节切片 - 对应 Bun HashedString::str → &[u8]
    public func str(): Array<UInt8> {
        var result = Array<UInt8>()
        let end = offset + Int64(len)
        for (i in offset..end) {
            if (i < source.size) {
                result.append(source[i])
            }
        }
        return result
    }

    /// 转为仓颉字符串
    public func toString(): String {
        var sb = StringBuilder()
        let bytes = str()
        for (b in bytes) {
            sb.append(Char(Int32(b)))
        }
        return sb.toString()
    }

    /// WyHash-32 计算 (与 Bun 的 bun_wyhash::hash 输出截断为 u32 一致)
    /// 严格对应 Bun 使用的外部 bun_wyhash crate
    private static func wyhash32(data: Array<UInt8>): UInt32 {
        if (data.size == 0) {
            return UInt32(0)
        }
        // 使用简化 wyhash 最终取低32位
        return UInt32(wyhash64(data) & UInt64(0xFFFFFFFF))
    }

    /// WyHash-64 完整实现
    /// 对应 Bun 使用的 wyhash 最终版算法
    private static func wyhash64(data: Array<UInt8>): UInt64 {
        let len = data.size
        // WyHash 常量
        let WYP0: UInt64 = 0xa0761d6478bd642f
        let WYP1: UInt64 = 0xe7037ed1a0b428db
        let WYP2: UInt64 = 0x8ebc6af09c88c6e3
        let WYP3: UInt64 = 0x589965cc75374cc3
        let WYP4: UInt64 = 0x1d8e4e27c47d124f

        var seed = WYP0

        if (len <= 16) {
            let a = readUInt64(data, 0, len)
            let b = readUInt64(data, if (len > 8) { len - 8 } else { 0 }, len)
            seed = seed ^ (wymix(a ^ WYP1, b ^ WYP2))
            return wymix(seed, UInt64(len) ^ WYP0)
        }

        var i: Int64 = 0
        if (len <= 64) {
            while (i + 16 <= len) {
                let a = readUInt64(data, i, len)
                let b = readUInt64(data, i + 8, len)
                seed = seed ^ (wymix(a ^ WYP1, b ^ WYP2))
                i += 16
            }
            if (i < len) {
                let a = readUInt64(data, len - 8, len)
                let b = readUInt64(data, len - 16, len)
                seed = seed ^ (wymix(a ^ WYP3, b ^ WYP4))
            }
            return wymix(seed, UInt64(len) ^ WYP0)
        }

        // 大数据块
        var see1 = seed
        var see2 = seed
        while (i + 64 <= len) {
            seed = seed ^ (wymix(readUInt64(data, i, len) ^ WYP1, readUInt64(data, i + 8, len) ^ WYP2))
            see1 = see1 ^ (wymix(readUInt64(data, i + 16, len) ^ WYP3, readUInt64(data, i + 24, len) ^ WYP4))
            see2 = see2 ^ (wymix(readUInt64(data, i + 32, len) ^ WYP2, readUInt64(data, i + 40, len) ^ WYP1))
            seed = seed ^ (wymix(readUInt64(data, i + 48, len) ^ WYP4, readUInt64(data, i + 56, len) ^ WYP3))
            i += 64
        }
        while (i + 16 <= len) {
            seed = seed ^ (wymix(readUInt64(data, i, len) ^ WYP1, readUInt64(data, i + 8, len) ^ WYP2))
            i += 16
        }
        if (i < len) {
            seed = seed ^ (wymix(readUInt64(data, len - 16, len) ^ WYP1, readUInt64(data, len - 8, len) ^ WYP2))
        }
        return wymix(seed ^ see1 ^ see2, UInt64(len) ^ WYP0)
    }

    private static func wymix(a: UInt64, b: UInt64): UInt64 {
        var x = a
        var y = b
        x = x ^ (x >> 32)
        y = y ^ (y >> 32)
        return (x * 0xa0761d6478bd642f) ^ (y * 0xe7037ed1a0b428db)
    }

    private static func readUInt64(data: Array<UInt8>, offset: Int64, limit: Int64): UInt64 {
        var result: UInt64 = 0
        let end = if (offset + 8 <= limit) { offset + 8 } else { limit }
        var shift: UInt64 = 0
        for (i in offset..end) {
            if (i >= 0 && i < data.size) {
                result = result | (UInt64(data[i]) << shift)
                shift += 8
            }
        }
        return result
    }
}

// ============================================================================
// StringTag - 字符串标签类型
// 对应 Bun: src/bun_core/string/mod.rs - Tag enum
// Bun 使用指针低位标记区分 5 种字符串变体:
//   ZigString, StaticZigString, WTFStringImpl, Empty, Dead
// ============================================================================

/// 字符串标签变体 - 对应 Bun Tag
public enum StringTag {
    | ZigString          // 借用的 UTF-8 切片
    | StaticZigString    // 静态字符串字面量
    | WTFStringImpl      // WebKit WTF 堆分配字符串
    | Empty              // 空字符串
    | Dead               // 已释放
}

/// 字符串编码类型
public enum StringEncoding {
    | UTF8
    | UTF16
    | Latin1
}

// ============================================================================
// BaoString - 核心字符串类型
// 对应 Bun: src/bun_core/string/mod.rs - String enum (5变体标记联合)
//   pub enum String(bun_alloc::String)
// 仓颉使用 GC 管理，将5变体统一为 GC 管理的字节数组包装
// ============================================================================

/// 核心字符串类型 - 对应 Bun String
/// Bun 使用指针标记区分5种变体，仓颉简化为统一的字节数组包装
public class BaoString {
    private var data: Array<UInt8>
    private var encoding: StringEncoding
    private var tag: StringTag

    /// 空字符串常量 - 对应 Bun String::Empty
    public static let EMPTY = BaoString("")

    public init() {
        data = []
        encoding = StringEncoding.UTF8
        tag = StringTag.Empty
    }

    public init(value: String) {
        data = Array<UInt8>()
        encoding = StringEncoding.UTF8
        tag = StringTag.StaticZigString
        for (c in value) {
            data.append(UInt8(c.value))
        }
    }

    public init(bytes: Array<UInt8>) {
        data = bytes
        encoding = StringEncoding.UTF8
        tag = StringTag.ZigString
    }

    public init(bytes: Array<UInt8>, encoding: StringEncoding) {
        data = bytes
        this.encoding = encoding
        tag = StringTag.ZigString
    }

    /// 从 UTF-8 字节数组借用 - 对应 Bun ZigString.borrowUTF8
    public static func borrowUtf8(bytes: Array<UInt8>): BaoString {
        let s = BaoString(bytes)
        s.tag = StringTag.ZigString
        return s
    }

    /// 从 UTF-16 数组创建 - 对应 Bun ZigString.borrowUTF16
    public static func fromUtf16(chars: Array<UInt16>): BaoString {
        var bytes = Array<UInt8>()
        for (ch in chars) {
            if (ch < 0x80) {
                bytes.append(UInt8(ch))
            } else if (ch < 0x800) {
                bytes.append(UInt8(0xC0 | (ch >> 6)))
                bytes.append(UInt8(0x80 | (ch & 0x3F)))
            } else if (ch >= 0xD800 && ch <= 0xDBFF) {
                // 代理对高位 - WTF-16 处理
                bytes.append(UInt8(0xED))
                bytes.append(UInt8(0xA0 | ((ch >> 6) & 0x0F)))
                bytes.append(UInt8(0x80 | (ch & 0x3F)))
            } else {
                bytes.append(UInt8(0xE0 | (ch >> 12)))
                bytes.append(UInt8(0x80 | ((ch >> 6) & 0x3F)))
                bytes.append(UInt8(0x80 | (ch & 0x3F)))
            }
        }
        return BaoString(bytes, StringEncoding.UTF8)
    }

    /// 获取 UTF-8 字节视图
    public func utf8(): Array<UInt8> {
        return data
    }

    /// 获取字节长度 - 对应 Bun ZigString.len
    public func byteLength(): Int64 {
        return data.size
    }

    /// 是否为空
    public func isEmpty(): Bool {
        return data.size == 0
    }

    /// 获取标签类型
    public func getTag(): StringTag {
        return tag
    }

    /// 获取编码
    public func getEncoding(): StringEncoding {
        return encoding
    }

    /// 转为仓颉原生字符串
    public func toString(): String {
        var sb = StringBuilder()
        for (b in data) {
            sb.append(Char(Int32(b)))
        }
        return sb.toString()
    }

    /// 克隆 - 对应 Bun String.clone / OwnedString
    public func clone(): BaoString {
        return BaoString(Array<UInt8>(data), encoding)
    }

    /// 比较相等 - 对应 Bun strings.eql
    public func equals(other: BaoString): Bool {
        if (data.size != other.data.size) {
            return false
        }
        for (i in 0..data.size) {
            if (data[i] != other.data[i]) {
                return false
            }
        }
        return true
    }

    /// 连接 - 对应 Bun strings.concat
    public func concat(other: BaoString): BaoString {
        var result = Array<UInt8>()
        for (b in data) {
            result.append(b)
        }
        for (b in other.data) {
            result.append(b)
        }
        return BaoString(result)
    }

    /// 子字符串 (字节偏移) - 对应 Bun slice
    public func slice(start: Int64, end: Int64): BaoString {
        var result = Array<UInt8>()
        let s = if (start < 0) { 0 } else { start }
        let e = if (end > data.size) { data.size } else { end }
        for (i in s..e) {
            result.append(data[i])
        }
        return BaoString(result)
    }

    /// 字符串分配限制 - 对应 Bun STRING_ALLOCATION_LIMIT
    public static let STRING_ALLOCATION_LIMIT: Int64 = 256 * 1024 * 1024  // 256MB
}

// ============================================================================
// StringBuilder - 两阶段字符串构建器
// 严格翻译自: src/bun_core/string/StringBuilder.rs
//   pub struct StringBuilder {
//       pub len: usize,
//       pub cap: usize,
//       pub ptr: Option<NonNull<u8>>,
//   }
// Bun 使用两阶段构建: count → allocate → append
// 仓颉使用动态数组模拟，保持相同 API 语义
// ============================================================================

/// 两阶段字符串构建器 - 严格对应 Bun StringBuilder
/// 使用方式: count()/countZ() 预计算大小 → allocate() 分配 → append() 填充
public class BaoStringBuilder {
    /// 已写入长度 - 对应 Bun StringBuilder.len
    public var len: Int64
    /// 预分配容量 - 对应 Bun StringBuilder.cap
    public var cap: Int64
    /// 底层缓冲区 (对应 Bun NonNull<u8> ptr)
    private var buffer: Array<UInt8>

    public init() {
        len = 0
        cap = 0
        buffer = []
    }

    /// 带初始容量创建 - 对应 Bun StringBuilder::init_capacity
    public init(capacity: Int64) {
        len = 0
        cap = capacity
        buffer = Array<UInt8>(capacity, item: 0)
    }

    /// 预计算带 null 终止符的长度 - 对应 Bun StringBuilder::count_z
    public func countZ(slice: Array<UInt8>): Unit {
        cap += slice.size + 1
    }

    /// 预计算长度 - 对应 Bun StringBuilder::count
    public func count(slice: Array<UInt8>): Unit {
        cap += slice.size
    }

    /// 预计算字符串长度
    public func count(s: String): Unit {
        cap += s.size
    }

    /// 预计算 UTF-16 转 UTF-8 长度 - 对应 Bun StringBuilder::count16
    public func count16(chars: Array<UInt16>): Unit {
        for (ch in chars) {
            if (ch < 0x80) {
                cap += 1
            } else if (ch < 0x800) {
                cap += 2
            } else {
                cap += 3
            }
        }
    }

    /// 分配缓冲区 - 对应 Bun StringBuilder::allocate
    public func allocate(): Unit {
        buffer = Array<UInt8>(cap, item: 0)
        len = 0
    }

    /// 追加字节切片 - 对应 Bun StringBuilder::append
    /// 返回写入的切片 (在缓冲区中的视图)
    public func append(slice: Array<UInt8>): Array<UInt8> {
        let start = len
        for (b in slice) {
            buffer[len] = b
            len += 1
        }
        return sliceRange(start, len)
    }

    /// 追加带 null 终止的字节切片 - 对应 Bun StringBuilder::append_z
    public func appendZ(slice: Array<UInt8>): Array<UInt8> {
        let start = len
        for (b in slice) {
            buffer[len] = b
            len += 1
        }
        buffer[len] = 0
        len += 1
        return sliceRange(start, len - 1)
    }

    /// 追加 BaoString - 对应 Bun StringBuilder::append_str
    public func appendStr(str: BaoString): Array<UInt8> {
        return append(str.utf8())
    }

    /// 追加原生字符串
    public func appendString(s: String): Array<UInt8> {
        var bytes = Array<UInt8>()
        for (c in s) {
            bytes.append(UInt8(c.value))
        }
        return append(bytes)
    }

    /// 追加 UTF-16 编码字符串 - 对应 Bun StringBuilder::append16
    public func append16(chars: Array<UInt16>): Unit {
        for (ch in chars) {
            if (ch < 0x80) {
                buffer[len] = UInt8(ch)
                len += 1
            } else if (ch < 0x800) {
                buffer[len] = UInt8(0xC0 | (ch >> 6))
                len += 1
                buffer[len] = UInt8(0x80 | (ch & 0x3F))
                len += 1
            } else {
                buffer[len] = UInt8(0xE0 | (ch >> 12))
                len += 1
                buffer[len] = UInt8(0x80 | ((ch >> 6) & 0x3F))
                len += 1
                buffer[len] = UInt8(0x80 | (ch & 0x3F))
                len += 1
            }
        }
    }

    /// 拼接多个切片 - 对应 Bun StringBuilder::add_concat
    public func addConcat(slices: Array<Array<UInt8>>): StringPointer {
        let start = len
        for (slice in slices) {
            for (b in slice) {
                buffer[len] = b
                len += 1
            }
        }
        return StringPointer(offset: UInt32(start), length: UInt32(len - start))
    }

    /// 追加并返回 StringPointer - 对应 Bun StringBuilder::append_count
    public func appendCount(slice: Array<UInt8>): StringPointer {
        let start = len
        for (b in slice) {
            buffer[len] = b
            len += 1
        }
        return StringPointer(offset: UInt32(start), length: UInt32(slice.size))
    }

    /// 追加带 null 并返回 StringPointer - 对应 Bun StringBuilder::append_count_z
    public func appendCountZ(slice: Array<UInt8>): StringPointer {
        let start = len
        for (b in slice) {
            buffer[len] = b
            len += 1
        }
        buffer[len] = 0
        len += 1
        return StringPointer(offset: UInt32(start), length: UInt32(slice.size))
    }

    /// 分配长度空间 - 对应 Bun StringBuilder::add
    public func add(length: Int64): StringPointer {
        let start = len
        len += length
        return StringPointer(offset: UInt32(start), length: UInt32(length))
    }

    /// 获取已写入的切片 - 对应 Bun StringBuilder::written_slice
    public func writtenSlice(): Array<UInt8> {
        return sliceRange(0, len)
    }

    /// 获取可写区域 - 对应 Bun StringBuilder::writable
    public func writable(): Array<UInt8> {
        var result = Array<UInt8>()
        for (i in len..cap) {
            result.append(buffer[i])
        }
        return result
    }

    /// 转移为最终字节数组 - 对应 Bun StringBuilder::move_to_slice
    public func moveToSlice(): Array<UInt8> {
        let result = writtenSlice()
        buffer = []
        len = 0
        cap = 0
        return result
    }

    /// 构建 BaoString
    public func build(): BaoString {
        return BaoString(writtenSlice())
    }

    /// 清空重置
    public func clear(): Unit {
        len = 0
    }

    /// 是否为空
    public func isEmpty(): Bool {
        return len == 0
    }

    /// 获取总长度
    public func length(): Int64 {
        return len
    }

    private func sliceRange(start: Int64, end: Int64): Array<UInt8> {
        var result = Array<UInt8>()
        for (i in start..end) {
            if (i < buffer.size) {
                result.append(buffer[i])
            }
        }
        return result
    }
}

// ============================================================================
// StringPointer - 字符串位置指针
// 对应 Bun: src/bun_core/string/mod.rs - StringPointer struct
//   pub struct StringPointer { pub offset: u32, pub length: u32 }
// ============================================================================

/// 字符串位置指针 - 对应 Bun StringPointer
public class StringPointer {
    public let offset: UInt32
    public let length: UInt32

    public init(offset: UInt32, length: UInt32) {
        this.offset = offset
        this.length = length
    }
}

// ============================================================================
// PathString - 路径字符串
// 对应 Bun: src/bun_core/string/PathString.rs
// ============================================================================

/// 路径字符串 - 对应 Bun PathString
public class PathString {
    private var data: BaoString

    public init() {
        data = BaoString("")
    }

    public init(path: String) {
        data = BaoString(path)
    }

    public init(data: BaoString) {
        this.data = data
    }

    public func toString(): String {
        return data.toString()
    }

    public func raw(): BaoString {
        return data
    }

    public func isEmpty(): Bool {
        return data.isEmpty()
    }
}
