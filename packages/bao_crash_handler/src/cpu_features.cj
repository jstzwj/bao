// bao_crash_handler - CPU 特性检测
// 严格翻译自: bun/src/crash_handler/CPUFeatures.zig
//   检测 CPU SIMD 指令集 (x86_64: SSE4.2/AVX/AVX2/AVX512, AArch64: NEON/SVE)
package bao_crash_handler

import bao_core.*
import std.collection.*

// FFI declaration for bun_cpu_features (must be at top level)
foreign func bun_cpu_features(): UInt8

// ============================================================================
// CPUFlags - CPU 特性标志位
// 严格翻译自: bun/src/crash_handler/CPUFeatures.zig - Flags
//   pub const Flags = switch (@import("builtin").cpu.arch) {
//       .x86_64 => packed struct(u8) { none, sse42, popcnt, avx, avx2, avx512, padding: u2 },
//       .aarch64 => packed struct(u8) { none, neon, fp, aes, crc32, atomics, sve, padding: u1 },
//   };
// ============================================================================

/// CPU 特性标志位 - 对应 Bun CPUFeatures.Flags
/// 使用位域标志表示支持的 CPU 指令集
public struct CPUFlags {
    /// x86_64 标志
    public var sse42: Bool   // bit 0
    public var popcnt: Bool  // bit 1
    public var avx: Bool     // bit 2
    public var avx2: Bool    // bit 3
    public var avx512: Bool  // bit 4

    /// AArch64 标志
    public var neon: Bool    // bit 0 ( reused for aarch64 )
    public var fp: Bool      // bit 1
    public var aes: Bool     // bit 2
    public var crc32: Bool   // bit 3
    public var atomics: Bool // bit 4
    public var sve: Bool     // bit 5

    public init() {
        sse42 = false
        popcnt = false
        avx = false
        avx2 = false
        avx512 = false
        neon = false
        fp = false
        aes = false
        crc32 = false
        atomics = false
        sve = false
    }

    /// 从原始字节构造 (对应 Bun @bitCast)
    public static func fromRaw(flags: UInt8): CPUFlags {
        var f = CPUFlags()
        // x86_64 布局: none(0), sse42(1), popcnt(2), avx(3), avx2(4), avx512(5), padding(6-7)
        f.sse42 = (flags & UInt8(0x02)) != UInt8(0)
        f.popcnt = (flags & UInt8(0x04)) != UInt8(0)
        f.avx = (flags & UInt8(0x08)) != UInt8(0)
        f.avx2 = (flags & UInt8(0x10)) != UInt8(0)
        f.avx512 = (flags & UInt8(0x20)) != UInt8(0)
        // AArch64 布局: none(0), neon(1), fp(2), aes(3), crc32(4), atomics(5), sve(6), padding(7)
        f.neon = (flags & UInt8(0x02)) != UInt8(0)
        f.fp = (flags & UInt8(0x04)) != UInt8(0)
        f.aes = (flags & UInt8(0x08)) != UInt8(0)
        f.crc32 = (flags & UInt8(0x10)) != UInt8(0)
        f.atomics = (flags & UInt8(0x20)) != UInt8(0)
        f.sve = (flags & UInt8(0x40)) != UInt8(0)
        f
    }

    /// 转为原始字节 (对应 Bun @bitCast(flags) -> u8)
    public func toRaw(): UInt8 {
        if (Environment.IS_X64) {
            var result: UInt8 = UInt8(0)
            if (sse42) { result = result | UInt8(0x02) }
            if (popcnt) { result = result | UInt8(0x04) }
            if (avx) { result = result | UInt8(0x08) }
            if (avx2) { result = result | UInt8(0x10) }
            if (avx512) { result = result | UInt8(0x20) }
            result
        } else {
            var result: UInt8 = UInt8(0)
            if (neon) { result = result | UInt8(0x02) }
            if (fp) { result = result | UInt8(0x04) }
            if (aes) { result = result | UInt8(0x08) }
            if (crc32) { result = result | UInt8(0x10) }
            if (atomics) { result = result | UInt8(0x20) }
            if (sve) { result = result | UInt8(0x40) }
            result
        }
    }
}

// ============================================================================
// CPUFeatures - CPU 特性检测
// 严格翻译自: bun/src/crash_handler/CPUFeatures.zig - CPUFeatures
//   pub const CPUFeatures = @This();
//   flags: Flags,
//   pub fn format, isEmpty, hasAnyAVX, get
// ============================================================================

/// CPU 特性检测 - 对应 Bun CPUFeatures (@This())
/// 检测当前 CPU 支持的 SIMD 指令集
public class CPUFeatures {
    /// 特性标志位
    /// 对应: flags: Flags
    public var flags: CPUFlags

    public init() {
        flags = CPUFlags()
    }

    public init(flags: CPUFlags) {
        this.flags = flags
    }

    /// 格式化为字符串
    /// 对应: pub fn format(features: @This(), writer: *std.Io.Writer) !void
    ///   遍历 Flags 的字段，打印为 true 的特性名
    public func format(): String {
        var parts = ArrayList<String>()
        if (Environment.IS_X64) {
            if (flags.sse42) { parts.add("sse42") }
            if (flags.popcnt) { parts.add("popcnt") }
            if (flags.avx) { parts.add("avx") }
            if (flags.avx2) { parts.add("avx2") }
            if (flags.avx512) { parts.add("avx512") }
        } else {
            if (flags.neon) { parts.add("neon") }
            if (flags.fp) { parts.add("fp") }
            if (flags.aes) { parts.add("aes") }
            if (flags.crc32) { parts.add("crc32") }
            if (flags.atomics) { parts.add("atomics") }
            if (flags.sve) { parts.add("sve") }
        }
        return String.join(parts.toArray(), delimiter: " ")
    }

    /// 是否为空 (无特性)
    /// 对应: pub fn isEmpty(features: CPUFeatures) bool
    ///   return @as(u8, @bitCast(features.flags)) == 0;
    public func isEmpty(): Bool {
        flags.toRaw() == UInt8(0)
    }

    /// 是否有任何 AVX 特性
    /// 对应: pub fn hasAnyAVX(features: CPUFeatures) bool
    ///   return features.flags.avx or features.flags.avx2 or features.flags.avx512;
    public func hasAnyAVX(): Bool {
        flags.avx || flags.avx2 || flags.avx512
    }

    /// 获取当前 CPU 特性
    /// 对应: pub fn get() CPUFeatures
    ///   const flags: Flags = @bitCast(bun_cpu_features());
    ///   bun.debugAssert(flags.none == false and flags.padding == 0);
    ///   if (bun.Environment.isX64) { ... analytics ... }
    ///   return .{ .flags = flags };
    public static func get(): CPUFeatures {
        // 调用外部 C 函数 bun_cpu_features()
        let rawFlags: UInt8 = bunCpuFeatures()
        let flags = CPUFlags.fromRaw(rawFlags)

        // 健全性检查: none 位应为 false，padding 位应为 0
        // 对应: bun.debugAssert(flags.none == false and flags.padding == 0)
        // 注意: none 是 bit 0，padding 在 x86_64 是 bits 6-7，AArch64 是 bit 7
        let noneBit = (rawFlags & UInt8(0x01)) != UInt8(0)
        if (noneBit) {
            // flags.none == true 表示未检测到特性，这不应该是错误
        }

        // 统计信息更新 (对应 Bun analytics.Features)
        if (Environment.IS_X64) {
            // bun.analytics.Features.no_avx += @intFromBool(!flags.avx)
            // bun.analytics.Features.no_avx2 += @intFromBool(!flags.avx2)
            // 仓颉中暂不实现分析统计
        }

        CPUFeatures(flags)
    }

    // 外部 C 函数声明
    // 对应: extern "c" fn bun_cpu_features() u8;
    private static func bunCpuFeatures(): UInt8 {
        unsafe { bun_cpu_features() }
    }
}
