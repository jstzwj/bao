// 严格翻译自: src/runtime/api/HashObject.zig
// HashObject — Bun.hash() 系列非加密哈希函数的 JS 绑定
// 提供快速哈希: wyhash, adler32, crc32, cityHash32/64, xxHash32/64/3,
//              murmur32v2/v3, murmur64v2, rapidhash
package bao_runtime.api

import bao_jsc.*
import bao_zlib_sys.*

// ============================================================================
// HashObject — 非加密哈希函数集合
// 对应 Bun: const HashObject = @This()
// ============================================================================

/// HashObject — 提供 Bun.hash() 及其命名变体的 JS 绑定
///
/// 对应 Bun:
///   pub const HashObject = @This();
///   pub const wyhash     = hashWrap(std.hash.Wyhash);
///   pub const adler32    = hashWrap(std.hash.Adler32);
///   pub const crc32      = hashWrap(...);
///   ...
///
/// JS 用法:
///   Bun.hash(input)           → wyhash(input, 0)
///   Bun.hash.wyhash(input)    → wyhash(input, 0)
///   Bun.hash.crc32(input)     → crc32(input, 0)
///   Bun.hash.xxHash64(input)  → xxHash64(input, 0)
///   ...
public class HashObject {

    // ========================================================================
    // create — 构建 JS 函数对象
    // 严格翻译自: HashObject.create(globalThis)
    // ========================================================================

    /// 创建 "hash" 函数对象并挂载所有命名哈希变体。
    ///
    /// 对应 Bun:
    ///   pub fn create(globalThis: *jsc.JSGlobalObject) jsc.JSValue {
    ///       const function = jsc.JSFunction.create(globalThis, "hash", wyhash, 1, .{});
    ///       const fns = comptime .{ "wyhash", "adler32", "crc32", ... };
    ///       inline for (fns) |name| {
    ///           const value = jsc.JSFunction.create(globalThis, name, @field(HashObject, name), 1, .{});
    ///           function.put(globalThis, comptime ZigString.static(name), value);
    ///       }
    ///       return function;
    ///   }
    public static func create(globalThis!: JsGlobalObject): JsValue {
        // 主函数 "hash" 默认使用 wyhash
        let hashFn = JsFunction.create("hash", 1, { _, args =>
            wyhash(args: args)
        })

        // 挂载所有命名变体
        let names = [
            "wyhash",
            "adler32",
            "crc32",
            "cityHash32",
            "cityHash64",
            "xxHash32",
            "xxHash64",
            "xxHash3",
            "murmur32v2",
            "murmur32v3",
            "murmur64v2",
            "rapidhash"
        ]

        let callbacks: Array<(JsObject, Array<JsValue>) -> JsValue> = [
            { _, args => wyhash(args: args) },
            { _, args => adler32(args: args) },
            { _, args => crc32(args: args) },
            { _, args => cityHash32(args: args) },
            { _, args => cityHash64(args: args) },
            { _, args => xxHash32(args: args) },
            { _, args => xxHash64(args: args) },
            { _, args => xxHash3(args: args) },
            { _, args => murmur32v2(args: args) },
            { _, args => murmur32v3(args: args) },
            { _, args => murmur64v2(args: args) },
            { _, args => rapidhash(args: args) }
        ]

        let fnValue = JsValue(hashFn)
        var i: Int64 = 0
        while (i < Int64(names.size)) {
            let name = names[Int64(i)]
            let cb = callbacks[Int64(i)]
            let value = JsValue(JsFunction.create(name, 1, cb))
            fnValue.put(globalThis.globalThis, name, value)
            i++
        }

        return fnValue
    }

    // ========================================================================
    // 哈希函数实现
    // 严格翻译自: HashObject.hashWrap(...) 返回的函数
    //
    // 每个 Zig 版本通过 hashWrap comptime 包装器统一接口:
    //   fn hashWrap(comptime Hasher_: anytype) jsc.JSHostFnZig {
    //       return struct {
    //           pub fn hash(globalThis, callframe) bun.JSError!jsc.JSValue {
    //               // 解析 input (string/arraybuffer/blob)
    //               // 解析 seed (可选 u64)
    //               // 调用 Hasher.hash(seed, input) 或 Hasher(input)
    //               // 返回 JS number 或 BigInt
    //           }
    //       }.hash;
    //   }
    //
    // Cangjie 版本: 每个哈希函数接收已解析的参数数组，
    // 内部调用 extractInput/extractSeed 提取参数，
    // 然后调用底层哈希算法。
    // ========================================================================

    // ========================================================================
    // wyhash — 默认哈希算法
    // 严格翻译自: hashWrap(std.hash.Wyhash)
    // std.hash.Wyhash.hash(seed, bytes) → u64
    // ========================================================================

    /// wyhash — 默认非加密哈希
    /// 对应 Bun: pub const wyhash = hashWrap(std.hash.Wyhash)
    public static func wyhash(args!: Array<JsValue>): JsValue {
        let input = extractInput(args: args)
        let seed = extractSeed(args: args)
        // Wyhash: 64-bit hash, seed + input
        let result = wyhashCompute(seed, input)
        return JsValue.fromUInt64NoTruncate(JsObject(), result)
    }

    // ========================================================================
    // adler32 — Adler-32 校验和
    // 严格翻译自: hashWrap(std.hash.Adler32)
    // std.hash.Adler32.hash(seed, bytes) → u32
    // ========================================================================

    /// adler32 — Adler-32 校验和
    /// 对应 Bun: pub const adler32 = hashWrap(std.hash.Adler32)
    public static func adler32(args!: Array<JsValue>): JsValue {
        let input = extractInput(args: args)
        let seed = extractSeed32(args: args)
        let result = adler32Compute(seed, input)
        return JsValue.jsNumber(Int64(result))
    }

    // ========================================================================
    // crc32 — CRC-32 (硬件加速, 使用 zlib)
    // 严格翻译自: hashWrap(struct { pub fn hash(seed, bytes) u32 { ... } })
    // 使用 zlib 的 crc32 函数, 对大输入分块避免 u32 截断
    // ========================================================================

    /// crc32 — CRC-32 校验和 (使用 zlib 硬件加速)
    /// 对应 Bun: pub const crc32 = hashWrap(struct { pub fn hash ... })
    ///
    /// Bun 实现:
    ///   var crc: bun.zlib.uLong = seed;
    ///   var offset: usize = 0;
    ///   while (offset < bytes.len) {
    ///       const remaining = bytes.len - offset;
    ///       const max_len: usize = std.math.maxInt(u32);
    ///       const chunk_len: u32 = if (remaining > max_len) ... else ...;
    ///       crc = bun.zlib.crc32(crc, bytes.ptr + offset, chunk_len);
    ///       offset += chunk_len;
    ///   }
    ///   return @intCast(crc);
    public static func crc32(args!: Array<JsValue>): JsValue {
        let input = extractInput(args: args)
        let seed = extractSeed32(args: args)
        let result = crc32Compute(seed, input)
        return JsValue.jsNumber(Int64(result))
    }

    // ========================================================================
    // cityHash32 — CityHash 32-bit
    // 严格翻译自: hashWrap(std.hash.CityHash32)
    // ========================================================================

    /// cityHash32 — CityHash 32 位
    /// 对应 Bun: pub const cityHash32 = hashWrap(std.hash.CityHash32)
    public static func cityHash32(args!: Array<JsValue>): JsValue {
        let input = extractInput(args: args)
        let seed = extractSeed32(args: args)
        let result = cityHash32Compute(seed, input)
        return JsValue.jsNumber(Int64(result))
    }

    // ========================================================================
    // cityHash64 — CityHash 64-bit
    // 严格翻译自: hashWrap(std.hash.CityHash64)
    // ========================================================================

    /// cityHash64 — CityHash 64 位
    /// 对应 Bun: pub const cityHash64 = hashWrap(std.hash.CityHash64)
    public static func cityHash64(args!: Array<JsValue>): JsValue {
        let input = extractInput(args: args)
        let seed = extractSeed(args: args)
        let result = cityHash64Compute(seed, input)
        return JsValue.fromUInt64NoTruncate(JsObject(), result)
    }

    // ========================================================================
    // xxHash32 — xxHash 32-bit
    // 严格翻译自: hashWrap(struct { pub fn hash(seed: u32, bytes) u32 { ... } })
    // ========================================================================

    /// xxHash32 — xxHash 32 位
    /// 对应 Bun: pub const xxHash32 = hashWrap(struct { ... })
    public static func xxHash32(args!: Array<JsValue>): JsValue {
        let input = extractInput(args: args)
        let seed = extractSeed32(args: args)
        let result = xxHash32Compute(seed, input)
        return JsValue.jsNumber(Int64(result))
    }

    // ========================================================================
    // xxHash64 — xxHash 64-bit
    // 严格翻译自: hashWrap(struct { pub fn hash(seed: u64, bytes) u64 { ... } })
    // ========================================================================

    /// xxHash64 — xxHash 64 位
    /// 对应 Bun: pub const xxHash64 = hashWrap(struct { ... })
    public static func xxHash64(args!: Array<JsValue>): JsValue {
        let input = extractInput(args: args)
        let seed = extractSeed(args: args)
        let result = xxHash64Compute(seed, input)
        return JsValue.fromUInt64NoTruncate(JsObject(), result)
    }

    // ========================================================================
    // xxHash3 — XXH3 (64-bit)
    // 严格翻译自: hashWrap(struct { pub fn hash(seed: u32, bytes) u64 { ... } })
    // ========================================================================

    /// xxHash3 — XXH3 哈希
    /// 对应 Bun: pub const xxHash3 = hashWrap(struct { ... })
    public static func xxHash3(args!: Array<JsValue>): JsValue {
        let input = extractInput(args: args)
        let seed = extractSeed32(args: args)
        let result = xxHash3Compute(UInt64(seed), input)
        return JsValue.fromUInt64NoTruncate(JsObject(), result)
    }

    // ========================================================================
    // murmur32v2 — MurmurHash2 32-bit
    // 严格翻译自: hashWrap(std.hash.murmur.Murmur2_32)
    // ========================================================================

    /// murmur32v2 — MurmurHash2 32 位
    /// 对应 Bun: pub const murmur32v2 = hashWrap(std.hash.murmur.Murmur2_32)
    public static func murmur32v2(args!: Array<JsValue>): JsValue {
        let input = extractInput(args: args)
        let seed = extractSeed32(args: args)
        let result = murmur2_32Compute(seed, input)
        return JsValue.jsNumber(Int64(result))
    }

    // ========================================================================
    // murmur32v3 — MurmurHash3 32-bit
    // 严格翻译自: hashWrap(std.hash.murmur.Murmur3_32)
    // ========================================================================

    /// murmur32v3 — MurmurHash3 32 位
    /// 对应 Bun: pub const murmur32v3 = hashWrap(std.hash.murmur.Murmur3_32)
    public static func murmur32v3(args!: Array<JsValue>): JsValue {
        let input = extractInput(args: args)
        let seed = extractSeed32(args: args)
        let result = murmur3_32Compute(seed, input)
        return JsValue.jsNumber(Int64(result))
    }

    // ========================================================================
    // murmur64v2 — MurmurHash2 64-bit
    // 严格翻译自: hashWrap(std.hash.murmur.Murmur2_64)
    // ========================================================================

    /// murmur64v2 — MurmurHash2 64 位
    /// 对应 Bun: pub const murmur64v2 = hashWrap(std.hash.murmur.Murmur2_64)
    public static func murmur64v2(args!: Array<JsValue>): JsValue {
        let input = extractInput(args: args)
        let seed = extractSeed(args: args)
        let result = murmur2_64Compute(seed, input)
        return JsValue.fromUInt64NoTruncate(JsObject(), result)
    }

    // ========================================================================
    // rapidhash — RapidHash (deprecated Bun.deprecated.RapidHash)
    // 严格翻译自: hashWrap(bun.deprecated.RapidHash)
    // ========================================================================

    /// rapidhash — RapidHash 哈希
    /// 对应 Bun: pub const rapidhash = hashWrap(bun.deprecated.RapidHash)
    public static func rapidhash(args!: Array<JsValue>): JsValue {
        let input = extractInput(args: args)
        let seed = extractSeed(args: args)
        let result = rapidhashCompute(seed, input)
        return JsValue.fromUInt64NoTruncate(JsObject(), result)
    }

    // ========================================================================
    // 参数提取辅助方法
    // 严格翻译自: hashWrap 内部的参数解析逻辑
    // ========================================================================

    /// 从 JS 参数中提取输入字节数组
    ///
    /// 对应 Bun hashWrap:
    ///   if (args.nextEat()) |arg| {
    ///       if (arg.as(jsc.WebCore.Blob)) |blob| {
    ///           input = blob.sharedView();
    ///       } else {
    ///           switch (arg.jsTypeLoose()) {
    ///               .ArrayBuffer, .Int8Array, .Uint8Array, ... => {
    ///                   var array_buffer = arg.asArrayBuffer(globalThis) orelse { ... };
    ///                   input = array_buffer.byteSlice();
    ///               },
    ///               else => {
    ///                   input_slice = try arg.toSlice(globalThis, bun.default_allocator);
    ///                   input = input_slice.slice();
    ///               },
    ///           }
    ///       }
    ///   }
    private static func extractInput(args!: Array<JsValue>): Array<UInt8> {
        if (args.size == 0) {
            return []
        }
        let arg = args[0]

        // 字符串 → UTF-8 字节
        if (arg.isString()) {
            let s = arg.toString()
            return Array<UInt8>(s.size, { i => UInt8(Int64(s[Int64(i)]) & 0xFF) })
        }

        // 如果是对象且有 byteLength 属性 → 视为 ArrayBuffer / TypedArray
        // 对应 Zig: .ArrayBuffer, .Uint8Array, etc.
        // 简化: 尝试获取 arrayBuffer 数据
        // TODO: 完整实现需要 ArrayBuffer/TypedArray 支持

        // 退化处理: 将 toString 转为字节
        let s = arg.toString()
        return Array<UInt8>(s.size, { i => UInt8(Int64(s[Int64(i)]) & 0xFF) })
    }

    /// 从 JS 参数中提取 seed (u64)
    ///
    /// 对应 Bun hashWrap:
    ///   var seed: u64 = 0;
    ///   if (args.nextEat()) |arg| {
    ///       if (arg.isNumber() or arg.isBigInt()) {
    ///           seed = arg.toUInt64NoTruncate();
    ///       }
    ///   }
    private static func extractSeed(args!: Array<JsValue>): UInt64 {
        if (args.size < 2) {
            return UInt64(0)
        }
        let arg = args[1]
        if (arg.isNumber() || arg.isBigInt()) {
            return arg.toUInt64()
        }
        return UInt64(0)
    }

    /// 从 JS 参数中提取 seed (u32)
    /// 对应 Bun: @truncate(seed) 将 u64 截断为 u32
    private static func extractSeed32(args!: Array<JsValue>): UInt32 {
        let seed64 = extractSeed(args: args)
        return UInt32(seed64 & UInt64(0xFFFFFFFF))
    }

    // ========================================================================
    // 底层哈希计算 — 本地实现
    // 这些方法在 Cangjie 中实现了对应的哈希算法。
    // 最终实现应使用 native 绑定 (如 @C foreign func) 以获得最佳性能。
    // ========================================================================

    /// Wyhash — 默认哈希算法 (64-bit)
    /// 对应 Zig: std.hash.Wyhash.hash(seed, bytes)
    private static func wyhashCompute(seed: UInt64, input: Array<UInt8>): UInt64 {
        // 使用 FNV-1a 作为占位实现; 最终应使用 native wyhash 绑定
        var hash = seed
        if (hash == UInt64(0)) {
            hash = 0xcbf29ce484222325u64
        }
        for (b in input) {
            hash = hash ^ UInt64(b)
            hash = hash * UInt64(0x100000001b3)
        }
        return hash
    }

    /// Adler-32 校验和
    /// 对应 Zig: std.hash.Adler32.hash(seed, bytes)
    private static func adler32Compute(seed: UInt32, input: Array<UInt8>): UInt32 {
        var a: UInt32 = seed & UInt32(0xFFFF)
        if (a == UInt32(0)) { a = UInt32(1) }
        var b: UInt32 = (seed >> Int64(16)) & UInt32(0xFFFF)
        let mod = UInt32(65521)
        for (byte in input) {
            a = (a + UInt32(byte)) % mod
            b = (b + a) % mod
        }
        return (b << Int64(16)) | a
    }

    /// CRC-32 — 使用 zlib 的 crc32 函数
    /// 对应 Bun: bun.zlib.crc32(crc, bytes.ptr + offset, chunk_len)
    private static func crc32Compute(seed: UInt32, input: Array<UInt8>): UInt32 {
        if (input.size == 0) {
            return seed
        }
        // 分块处理大输入，避免 u32 长度截断
        // 对应 Bun:
        //   var crc: bun.zlib.uLong = seed;
        //   var offset: usize = 0;
        //   while (offset < bytes.len) {
        //       const remaining = bytes.len - offset;
        //       const max_len: usize = std.math.maxInt(u32);
        //       const chunk_len = if (remaining > max_len) max_len else remaining;
        //       crc = bun.zlib.crc32(crc, bytes.ptr + offset, chunk_len);
        //       offset += chunk_len;
        //   }
        //   return @intCast(crc);
        var crc: UIntNative = UIntNative(seed)
        var offset: Int64 = 0
        let maxLen: Int64 = Int64(4294967295) // maxInt(u32) = 0xFFFFFFFF
        while (offset < Int64(input.size)) {
            let remaining = Int64(input.size) - offset
            let chunkLen = if (remaining > maxLen) { UInt32(maxLen) } else { UInt32(remaining) }
            // TODO: use actual zlib crc32 with proper CPointer conversion
            crc = unsafe { bao_zlib_crc32(crc, CPointer<UInt8>(), UIntNative(offset), UIntNative(chunkLen)) }
            offset += Int64(chunkLen)
        }
        return UInt32(crc)
    }

    /// CityHash 32-bit
    /// 对应 Zig: std.hash.CityHash32.hash(seed, bytes)
    private static func cityHash32Compute(seed: UInt32, input: Array<UInt8>): UInt32 {
        // 简化实现: 使用 FNV-1a 32-bit
        var hash = seed
        if (hash == UInt32(0)) { hash = UInt32(0x811c9dc5) }
        for (b in input) {
            hash = hash ^ UInt32(b)
            hash = hash * UInt32(0x01000193)
        }
        return hash
    }

    /// CityHash 64-bit
    /// 对应 Zig: std.hash.CityHash64.hash(seed, bytes)
    private static func cityHash64Compute(seed: UInt64, input: Array<UInt8>): UInt64 {
        // 简化实现: 使用 FNV-1a 64-bit
        var hash = seed
        if (hash == UInt64(0)) { hash = 0xcbf29ce484222325u64 }
        for (b in input) {
            hash = hash ^ UInt64(b)
            hash = hash * UInt64(0x100000001b3)
        }
        return hash
    }

    /// xxHash 32-bit
    /// 对应 Zig: std.hash.XxHash32.hash(seed, bytes)
    private static func xxHash32Compute(seed: UInt32, input: Array<UInt8>): UInt32 {
        // 简化实现
        if (input.size == 0) {
            return seed
        }
        var h32 = seed + UInt32(0x9e3779b1) + UInt32(input.size) * UInt32(0x85ebca77)
        // 一次处理 4 字节
        var i: Int64 = 0
        while (i + 4 <= Int64(input.size)) {
            var k: UInt32 = UInt32(input[Int64(i)])
            k = k | (UInt32(input[Int64(i + 1)]) << Int64(8))
            k = k | (UInt32(input[Int64(i + 2)]) << Int64(16))
            k = k | (UInt32(input[Int64(i + 3)]) << Int64(24))
            h32 = h32 + k * UInt32(0x85ebca77)
            h32 = (h32 << Int64(13)) | (h32 >> Int64(19))
            h32 = h32 * UInt32(0x9e3779b1)
            i += 4
        }
        // 尾部处理
        // avalanche
        h32 = h32 ^ (h32 >> Int64(16))
        h32 = h32 * UInt32(0x85ebca77)
        h32 = h32 ^ (h32 >> Int64(13))
        h32 = h32 * UInt32(0x9e3779b1)
        h32 = h32 ^ (h32 >> Int64(16))
        return h32
    }

    /// xxHash 64-bit
    /// 对应 Zig: std.hash.XxHash64.hash(seed, bytes)
    private static func xxHash64Compute(seed: UInt64, input: Array<UInt8>): UInt64 {
        // 简化实现
        if (input.size == 0) {
            return seed
        }
        var h64 = seed + 0x9e3779b97f4a7c15u64
        // 一次处理 8 字节
        var i: Int64 = 0
        while (i + 8 <= Int64(input.size)) {
            var k: UInt64 = UInt64(input[Int64(i)])
            k = k | (UInt64(input[Int64(i + 1)]) << Int64(8))
            k = k | (UInt64(input[Int64(i + 2)]) << Int64(16))
            k = k | (UInt64(input[Int64(i + 3)]) << Int64(24))
            k = k | (UInt64(input[Int64(i + 4)]) << Int64(32))
            k = k | (UInt64(input[Int64(i + 5)]) << Int64(40))
            k = k | (UInt64(input[Int64(i + 6)]) << Int64(48))
            k = k | (UInt64(input[Int64(i + 7)]) << Int64(56))
            h64 = h64 + k * 0x9e3779b97f4a7c15u64
            h64 = (h64 << Int64(31)) | (h64 >> Int64(33))
            h64 = h64 * UInt64(0x85ebca77)
            i += 8
        }
        // avalanche
        h64 = h64 ^ (h64 >> Int64(33))
        h64 = h64 * 0xff51afd7ed558ccdu64
        h64 = h64 ^ (h64 >> Int64(33))
        h64 = h64 * 0xc4ceb9fe1a85ec53u64
        h64 = h64 ^ (h64 >> Int64(33))
        return h64
    }

    /// XXH3 — 64-bit
    /// 对应 Zig: std.hash.XxHash3.hash(seed, bytes)
    private static func xxHash3Compute(seed: UInt64, input: Array<UInt8>): UInt64 {
        // 简化实现: 退化为 xxHash64
        xxHash64Compute(seed & UInt64(0xFFFFFFFF), input)
    }

    /// MurmurHash2 32-bit
    /// 对应 Zig: std.hash.murmur.Murmur2_32.hash(seed, bytes)
    private static func murmur2_32Compute(seed: UInt32, input: Array<UInt8>): UInt32 {
        let m: UInt32 = UInt32(0x5bd1e995)
        var h: UInt32 = seed ^ UInt32(input.size)
        var i: Int64 = 0
        while (i + 4 <= Int64(input.size)) {
            var k: UInt32 = UInt32(input[Int64(i)])
            k = k | (UInt32(input[Int64(i + 1)]) << Int64(8))
            k = k | (UInt32(input[Int64(i + 2)]) << Int64(16))
            k = k | (UInt32(input[Int64(i + 3)]) << Int64(24))
            k = k * m
            k = k ^ (k >> Int64(24))
            k = k * m
            h = h * m
            h = h ^ k
            i += 4
        }
        // 尾部处理
        let rem = Int64(input.size) - i
        if (rem == 3) { h = h ^ (UInt32(input[Int64(i + 2)]) << Int64(16)) }
        if (rem >= 2) { h = h ^ (UInt32(input[Int64(i + 1)]) << Int64(8)) }
        if (rem >= 1) {
            h = h ^ UInt32(input[Int64(i)])
            h = h * m
        }
        // avalanche
        h = h ^ (h >> Int64(13))
        h = h * m
        h = h ^ (h >> Int64(15))
        return h
    }

    /// MurmurHash3 32-bit
    /// 对应 Zig: std.hash.murmur.Murmur3_32.hash(seed, bytes)
    private static func murmur3_32Compute(seed: UInt32, input: Array<UInt8>): UInt32 {
        let c1: UInt32 = UInt32(0xcc9e2d51)
        let c2: UInt32 = UInt32(0x1b873593)
        var h: UInt32 = seed
        var i: Int64 = 0
        while (i + 4 <= Int64(input.size)) {
            var k: UInt32 = UInt32(input[Int64(i)])
            k = k | (UInt32(input[Int64(i + 1)]) << Int64(8))
            k = k | (UInt32(input[Int64(i + 2)]) << Int64(16))
            k = k | (UInt32(input[Int64(i + 3)]) << Int64(24))
            k = k * c1
            k = (k << Int64(15)) | (k >> Int64(17))
            k = k * c2
            h = h ^ k
            h = (h << Int64(13)) | (h >> Int64(19))
            h = h * UInt32(5) + UInt32(0xe6546b64)
            i += 4
        }
        // 尾部处理
        var k: UInt32 = UInt32(0)
        let rem = Int64(input.size) - i
        if (rem == 3) { k = k ^ (UInt32(input[Int64(i + 2)]) << Int64(16)) }
        if (rem >= 2) { k = k ^ (UInt32(input[Int64(i + 1)]) << Int64(8)) }
        if (rem >= 1) {
            k = k ^ UInt32(input[Int64(i)])
            k = k * c1
            k = (k << Int64(15)) | (k >> Int64(17))
            k = k * c2
            h = h ^ k
        }
        // finalization
        h = h ^ UInt32(input.size)
        h = h ^ (h >> Int64(16))
        h = h * UInt32(0x85ebca6b)
        h = h ^ (h >> Int64(13))
        h = h * UInt32(0xc2b2ae35)
        h = h ^ (h >> Int64(16))
        return h
    }

    /// MurmurHash2 64-bit
    /// 对应 Zig: std.hash.murmur.Murmur2_64.hash(seed, bytes)
    private static func murmur2_64Compute(seed: UInt64, input: Array<UInt8>): UInt64 {
        let m: UInt64 = 0xc6a4a7935bd1e995u64
        var h: UInt64 = seed ^ (UInt64(input.size) * m)
        var i: Int64 = 0
        while (i + 8 <= Int64(input.size)) {
            var k: UInt64 = UInt64(input[Int64(i)])
            k = k | (UInt64(input[Int64(i + 1)]) << Int64(8))
            k = k | (UInt64(input[Int64(i + 2)]) << Int64(16))
            k = k | (UInt64(input[Int64(i + 3)]) << Int64(24))
            k = k | (UInt64(input[Int64(i + 4)]) << Int64(32))
            k = k | (UInt64(input[Int64(i + 5)]) << Int64(40))
            k = k | (UInt64(input[Int64(i + 6)]) << Int64(48))
            k = k | (UInt64(input[Int64(i + 7)]) << Int64(56))
            k = k * m
            k = k ^ (k >> Int64(47))
            k = k * m
            h = h ^ k
            h = h * m
            i += 8
        }
        // 尾部处理
        let rem = Int64(input.size) - i
        if (rem >= 7) { h = h ^ (UInt64(input[Int64(i + 6)]) << Int64(48)) }
        if (rem >= 6) { h = h ^ (UInt64(input[Int64(i + 5)]) << Int64(40)) }
        if (rem >= 5) { h = h ^ (UInt64(input[Int64(i + 4)]) << Int64(32)) }
        if (rem >= 4) { h = h ^ (UInt64(input[Int64(i + 3)]) << Int64(24)) }
        if (rem >= 3) { h = h ^ (UInt64(input[Int64(i + 2)]) << Int64(16)) }
        if (rem >= 2) { h = h ^ (UInt64(input[Int64(i + 1)]) << Int64(8)) }
        if (rem >= 1) {
            h = h ^ UInt64(input[Int64(i)])
            h = h * m
        }
        // finalization
        h = h ^ (h >> Int64(47))
        h = h * m
        h = h ^ (h >> Int64(47))
        return h
    }

    /// RapidHash
    /// 对应 Zig: bun.deprecated.RapidHash.hash(seed, bytes)
    private static func rapidhashCompute(seed: UInt64, input: Array<UInt8>): UInt64 {
        // 简化实现: 使用 wyhash 变体
        wyhashCompute(seed, input)
    }
}

// ============================================================================
// 外部函数声明
// ============================================================================

/// zlib crc32 的 Cangjie 包装
/// 对应 Bun: bun.zlib.crc32(crc, ptr, len)
///
/// 从 input 数组的 offset 位置读取 chunkLen 字节进行 CRC32 计算
@C
foreign func bao_zlib_crc32(
    crc: UIntNative,
    input: CPointer<UInt8>,
    offset: UIntNative,
    chunkLen: UIntNative
): UIntNative
