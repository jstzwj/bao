// bao_core - 小字符串优化类型
// 严格翻译自: src/string/SmolStr.zig
//   pub const SmolStr = packed struct(u128) {
//       __len: u32, cap: u32, __ptr: [*]u8,
//   };
//   pub const Inlined = packed struct(u128) {
//       data: u120, __len: u7, _tag: u1,
//   };
// Bun: <=15 字节内联存储 (Inlined), >15 字节堆分配
// 仓颉: 使用 struct + 内联数组模拟, 阈值保持 <=22 字节
package bao_core
import std.collection.*

/// 小字符串优化 - 严格对应 Bun SmolStr
/// Bun: 15 字节内联 (u120 data), 超过则堆分配
/// 仓颉: 22 字节内联 (适配仓颉值类型), 超过则使用 String
/// 对应 Bun SmolStr 的核心语义:
///   - 短字符串内联存储，零堆分配
///   - 长字符串自动降级为堆存储
///   - append 操作自动从内联升级到堆
public struct SmolStr {
    /// 内联存储的最大字节数 - 对应 Bun Inlined.max_len = 15
    /// 仓颉使用 22 字节 (3 * UInt64 + UInt8 对齐)
    public static let MAX_INLINE_LEN: Int64 = 22

    /// 内联数据缓冲区
    private var inlineData: Array<UInt8>
    /// 堆分配的字符串 (当超过内联阈值时)
    private var heapData: ?String
    /// 字节长度
    private var byteLen: Int64
    /// 是否使用内联存储
    private var isInlinedFlag: Bool

    /// 空值 - 对应 Bun SmolStr.empty()
    /// pub fn empty() SmolStr { return SmolStr.fromInlined(Inlined.empty); }
    public init() {
        inlineData = Array<UInt8>(SmolStr.MAX_INLINE_LEN, { _ => UInt8(0) })
        heapData = None
        byteLen = 0
        isInlinedFlag = true
    }

    /// 从字符串创建 - 对应 Bun SmolStr.fromSlice
    /// pub fn fromSlice(allocator, values) !SmolStr {
    ///     if (values.len > Inlined.max_len) {
    ///         var baby_list = try BabyList(u8).initCapacity(allocator, values.len);
    ///         baby_list.appendSliceAssumeCapacity(values);
    ///         return SmolStr.fromBabyList(baby_list);
    ///     }
    ///     const inlined = Inlined.init(values) catch unreachable;
    ///     return SmolStr.fromInlined(inlined);
    /// }
    public init(s: String) {
        let bytes = stringToBytes(s)
        byteLen = bytes.size
        if (bytes.size <= SmolStr.MAX_INLINE_LEN) {
            inlineData = Array<UInt8>(SmolStr.MAX_INLINE_LEN, { _ => UInt8(0) })
            for (i in 0..bytes.size) {
                inlineData[Int64(i)] = bytes[Int64(i)]
            }
            heapData = None
            isInlinedFlag = true
        } else {
            inlineData = Array<UInt8>(SmolStr.MAX_INLINE_LEN, { _ => UInt8(0) })
            heapData = Some(s)
            isInlinedFlag = false
        }
    }

    /// 从字节数组创建 - 对应 Bun SmolStr.fromSlice
    public init(bytes: Array<UInt8>) {
        byteLen = bytes.size
        if (bytes.size <= SmolStr.MAX_INLINE_LEN) {
            inlineData = Array<UInt8>(SmolStr.MAX_INLINE_LEN, { _ => UInt8(0) })
            for (i in 0..bytes.size) {
                inlineData[Int64(i)] = bytes[Int64(i)]
            }
            heapData = None
            isInlinedFlag = true
        } else {
            inlineData = Array<UInt8>(SmolStr.MAX_INLINE_LEN, { _ => UInt8(0) })
            heapData = Some(bytesToString(bytes))
            isInlinedFlag = false
        }
    }

    /// 从单个字符创建 - 对应 Bun SmolStr.fromChar
    /// pub fn fromRune(char: u8) SmolStr {
    ///     var inlined = Inlined{ .data = 0, .__len = 1, ._tag = 1 };
    ///     inlined.allChars()[0] = char;
    ///     return SmolStr.fromInlined(inlined);
    /// }
    public init(char: UInt8) {
        inlineData = Array<UInt8>(SmolStr.MAX_INLINE_LEN, { _ => UInt8(0) })
        inlineData[0] = char
        heapData = None
        byteLen = 1
        isInlinedFlag = true
    }

    /// 是否内联存储 - 对应 Bun SmolStr.isInlined
    /// pub fn isInlined(this: *const SmolStr) bool {
    ///     return @as(usize, @intFromPtr(this.__ptr)) & Tag != 0;
    /// }
    public func isInlined(): Bool {
        return isInlinedFlag
    }

    /// 长度 - 对应 Bun SmolStr.len
    /// pub fn len(this: *const SmolStr) u32
    public func len(): Int64 {
        return byteLen
    }

    /// 是否为空
    public func isEmpty(): Bool {
        return byteLen == 0
    }

    /// 获取字节切片 - 对应 Bun SmolStr.slice
    /// pub fn slice(this: *const SmolStr) []const u8 {
    ///     if (this.isInlined()) {
    ///         const bytes: [*]const u8 = @ptrCast(this);
    ///         return bytes[0..this.len()];
    ///     }
    ///     return this.ptrConst()[0..this.__len];
    /// }
    public func bytes(): Array<UInt8> {
        if (isInlinedFlag) {
            var result = ArrayList<UInt8>()
            for (i in 0..byteLen) {
                if (i < inlineData.size) {
                    result.add(inlineData[Int64(i)])
                }
            }
            return result.toArray()
        }
        match (heapData) {
            case Some(s) => return stringToBytes(s)
            case None => return []
        }
    }

    /// 转为字符串
    public func toString(): String {
        if (isInlinedFlag) {
            var sb = StringBuilder()
            for (i in 0..byteLen) {
                if (i < inlineData.size) {
                    sb.append(Rune(Int32(inlineData[Int64(i)])))
                }
            }
            return sb.toString()
        }
        match (heapData) {
            case Some(s) => return s
            case None => return ""
        }
    }

    /// 追加字符 - 对应 Bun SmolStr.appendChar
    /// pub fn appendRune(this: *SmolStr, allocator, char) !void {
    ///     if (this.isInlined()) {
    ///         if (inlined.len() + 1 > Inlined.max_len) {
    ///             // 升级为堆分配
    ///             var baby_list = try BabyList(u8).initCapacity(allocator, inlined.len() + 1);
    ///             baby_list.appendSliceAssumeCapacity(inlined.slice());
    ///             try baby_list.append(allocator, char);
    ///             this.* = SmolStr.fromBabyList(baby_list);
    ///             return;
    ///         }
    ///         inlined.allChars()[inlined.len()] = char;
    ///         inlined.setLen(@intCast(inlined.len() + 1));
    ///         this.* = @bitCast(inlined);
    ///         this.markInlined();
    ///     }
    ///     // 堆分配路径: append to baby_list
    /// }
    public func appendRune(char: UInt8): SmolStr {
        let newLen = byteLen + 1
        if (isInlinedFlag && newLen <= SmolStr.MAX_INLINE_LEN) {
            // 仍在内联范围内
            var newData = Array<UInt8>(SmolStr.MAX_INLINE_LEN, { _ => UInt8(0) })
            for (i in 0..byteLen) {
                newData[Int64(i)] = inlineData[Int64(i)]
            }
            newData[Int64(byteLen)] = char
            // Build string from inline data and create new SmolStr
            var sb = StringBuilder()
            for (i in 0..newLen) {
                sb.append(Rune(Int32(newData[Int64(i)])))
            }
            return SmolStr(sb.toString())
        }
        // 升级为堆分配
        var existing = bytes()
        var newBytes = ArrayList<UInt8>()
        for (b in existing) {
            newBytes.add(b)
        }
        newBytes.add(char)
        return SmolStr(newBytes.toArray())
    }

    /// 追加字节切片 - 对应 Bun SmolStr.appendSlice
    /// pub fn appendSlice(this: *SmolStr, allocator, values) !void
    public func appendSlice(other: Array<UInt8>): SmolStr {
        let newLen = byteLen + other.size
        if (isInlinedFlag && newLen <= SmolStr.MAX_INLINE_LEN) {
            var newData = Array<UInt8>(SmolStr.MAX_INLINE_LEN, { _ => UInt8(0) })
            for (i in 0..byteLen) {
                newData[Int64(i)] = inlineData[Int64(i)]
            }
            for (i in 0..other.size) {
                newData[Int64(byteLen + i)] = other[Int64(i)]
            }
            var sb = StringBuilder()
            for (i in 0..newLen) {
                sb.append(Rune(Int32(newData[Int64(i)])))
            }
            return SmolStr(sb.toString())
        }
        var newBytes = ArrayList<UInt8>()
        let existing = bytes()
        for (b in existing) {
            newBytes.add(b)
        }
        for (b in other) {
            newBytes.add(b)
        }
        return SmolStr(newBytes.toArray())
    }

    /// 追加字符串
    public func appendString(other: String): SmolStr {
        return appendSlice(stringToBytes(other))
    }

    /// 比较相等
    public func eql(other: SmolStr): Bool {
        if (this.byteLen != other.byteLen) {
            return false
        }
        let a = this.bytes()
        let b = other.bytes()
        for (i in 0..a.size) {
            if (a[Int64(i)] != b[Int64(i)]) {
                return false
            }
        }
        return true
    }

    /// 与字符串比较
    public func eqlString(s: String): Bool {
        if (this.byteLen != s.size) {
            return false
        }
        let b = this.bytes()
        let chars = s.toArray()
        for (i in 0..b.size) {
            if (b[Int64(i)] != chars[Int64(i)]) {
                return false
            }
        }
        return true
    }

    private static func stringToBytes(s: String): Array<UInt8> {
        var bytes = ArrayList<UInt8>()
        for (c in s) {
            bytes.add(c)
        }
        return bytes.toArray()
    }

    private static func bytesToString(bytes: Array<UInt8>): String {
        var sb = StringBuilder()
        for (b in bytes) {
            sb.append(Rune(Int32(b)))
        }
        return sb.toString()
    }
}
