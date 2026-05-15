// bao_core - CPU 特性检测
// 严格翻译自: src/crash_handler/CPUFeatures.zig
//   Bun 的 CPU 特性检测:
//   - x86_64: sse42, popcnt, avx, avx2, avx512
//   - aarch64: neon, fp, aes, crc32, atomics, sve
//   - 通过 C FFI bun_cpu_features() 获取
//   - 用于崩溃报告中的 CPU 信息
package bao_core

// ============================================================================
// C FFI 声明
// 严格翻译自: CPUFeatures.zig extern "c" fn bun_cpu_features() u8
// ============================================================================

@C
foreign func bun_cpu_features(): UInt8

// ============================================================================
// CPU 特性标志
// 严格翻译自: CPUFeatures.zig Flags = packed struct(u8)
//   x86_64: { none, sse42, popcnt, avx, avx2, avx512, padding: u2 }
//   aarch64: { none, neon, fp, aes, crc32, atomics, sve, padding: u1 }
// ============================================================================

/// CPU 特性标志 (x86_64 布局)
/// 对应 Bun: Flags packed struct(u8) for x86_64
public class CpuFlagsX86 {
    /// 无特性
    public var none: Bool
    /// SSE4.2
    public var sse42: Bool
    /// POPCNT
    public var popcnt: Bool
    /// AVX
    public var avx: Bool
    /// AVX2
    public var avx2: Bool
    /// AVX-512
    public var avx512: Bool

    public init() {
        none = true
        sse42 = false
        popcnt = false
        avx = false
        avx2 = false
        avx512 = false
    }

    public init(sse42: Bool, popcnt: Bool, avx: Bool,
                avx2: Bool, avx512: Bool) {
        this.none = false
        this.sse42 = sse42
        this.popcnt = popcnt
        this.avx = avx
        this.avx2 = avx2
        this.avx512 = avx512
    }

    /// 是否为空 (无任何特性)
    /// 对应 Bun: isEmpty() -> @as(u8, @bitCast(flags)) == 0
    public func isEmpty(): Bool {
        return !sse42 && !popcnt && !avx && !avx2 && !avx512
    }

    /// 是否有任何 AVX 支持
    /// 对应 Bun: hasAnyAVX() -> flags.avx or flags.avx2 or flags.avx512
    public func hasAnyAVX(): Bool {
        return avx || avx2 || avx512
    }

    /// 格式化为字符串
    /// 对应 Bun: format(features, writer) - 输出空格分隔的特性名
    public func format(): String {
        let sb = StringBuilder()
        var isFirst = true
        if (sse42) {
            if (!isFirst) { sb.append(" ") }
            sb.append("sse42")
            isFirst = false
        }
        if (popcnt) {
            if (!isFirst) { sb.append(" ") }
            sb.append("popcnt")
            isFirst = false
        }
        if (avx) {
            if (!isFirst) { sb.append(" ") }
            sb.append("avx")
            isFirst = false
        }
        if (avx2) {
            if (!isFirst) { sb.append(" ") }
            sb.append("avx2")
            isFirst = false
        }
        if (avx512) {
            if (!isFirst) { sb.append(" ") }
            sb.append("avx512")
            isFirst = false
        }
        return sb.toString()
    }
}

/// CPU 特性标志 (ARM64 布局)
/// 对应 Bun: Flags packed struct(u8) for aarch64
public class CpuFlagsArm {
    /// 无特性
    public var none: Bool
    /// NEON
    public var neon: Bool
    /// 浮点
    public var fp: Bool
    /// AES 硬件加速
    public var aes: Bool
    /// CRC32 硬件加速
    public var crc32: Bool
    /// 原子指令
    public var atomics: Bool
    /// SVE (可伸缩向量扩展)
    public var sve: Bool

    public init() {
        none = true
        neon = false
        fp = false
        aes = false
        crc32 = false
        atomics = false
        sve = false
    }

    public init(neon: Bool, fp: Bool, aes: Bool, crc32: Bool,
                atomics: Bool, sve: Bool) {
        this.none = false
        this.neon = neon
        this.fp = fp
        this.aes = aes
        this.crc32 = crc32
        this.atomics = atomics
        this.sve = sve
    }

    /// 是否为空
    public func isEmpty(): Bool {
        return !neon && !fp && !aes && !crc32 && !atomics && !sve
    }

    /// 格式化为字符串
    public func format(): String {
        let sb = StringBuilder()
        var isFirst = true
        if (neon) {
            if (!isFirst) { sb.append(" ") }
            sb.append("neon")
            isFirst = false
        }
        if (fp) {
            if (!isFirst) { sb.append(" ") }
            sb.append("fp")
            isFirst = false
        }
        if (aes) {
            if (!isFirst) { sb.append(" ") }
            sb.append("aes")
            isFirst = false
        }
        if (crc32) {
            if (!isFirst) { sb.append(" ") }
            sb.append("crc32")
            isFirst = false
        }
        if (atomics) {
            if (!isFirst) { sb.append(" ") }
            sb.append("atomics")
            isFirst = false
        }
        if (sve) {
            if (!isFirst) { sb.append(" ") }
            sb.append("sve")
            isFirst = false
        }
        return sb.toString()
    }
}

// ============================================================================
// CPUFeatures - CPU 特性检测
// 严格翻译自: CPUFeatures.zig 的顶层函数
//   get() CPUFeatures: 通过 bun_cpu_features() 获取标志位
//   format(): 格式化为字符串
//   isEmpty(): 检查是否有任何特性
//   hasAnyAVX(): 检查是否有 AVX 支持
// ============================================================================

/// CPU 特性检测
/// 对应 Bun: CPUFeatures = @This() { flags: Flags }
public class CPUFeatures {
    /// x86_64 特性标志
    public var x86Flags: CpuFlagsX86
    /// ARM64 特性标志
    public var armFlags: CpuFlagsArm
    /// 是否为 x86 架构
    public var isX86: Bool

    public init() {
        x86Flags = CpuFlagsX86()
        armFlags = CpuFlagsArm()
        isX86 = true  // 默认 x86
    }

    /// 获取当前 CPU 特性
    /// 对应 Bun: pub fn get() CPUFeatures
    ///   const flags: Flags = @bitCast(bun_cpu_features());
    ///   bun.debugAssert(flags.none == false and flags.padding == 0);
    ///   更新 analytics 中的 no_avx/no_avx2 计数
    public static func get(): CPUFeatures {
        let features = CPUFeatures()
        let rawFlags = bun_cpu_features()

        // 解析 flags 字节
        // x86_64 布局: bit0=none, bit1=sse42, bit2=popcnt, bit3=avx, bit4=avx2, bit5=avx512, bit6-7=padding
        // arm64 布局:  bit0=none, bit1=neon, bit2=fp, bit3=aes, bit4=crc32, bit5=atomics, bit6=sve, bit7=padding
        if (features.isX86) {
            let f = Int64(rawFlags)
            features.x86Flags = CpuFlagsX86(
                sse42: (f & 0x02) != 0,
                popcnt: (f & 0x04) != 0,
                avx: (f & 0x08) != 0,
                avx2: (f & 0x10) != 0,
                avx512: (f & 0x20) != 0
            )
        } else {
            let f = Int64(rawFlags)
            features.armFlags = CpuFlagsArm(
                neon: (f & 0x02) != 0,
                fp: (f & 0x04) != 0,
                aes: (f & 0x08) != 0,
                crc32: (f & 0x10) != 0,
                atomics: (f & 0x20) != 0,
                sve: (f & 0x40) != 0
            )
        }
        return features
    }

    /// 是否为空 (无任何 CPU 特性)
    /// 对应 Bun: isEmpty() -> @as(u8, @bitCast(flags)) == 0
    public func isEmpty(): Bool {
        if (isX86) {
            return x86Flags.isEmpty()
        }
        return armFlags.isEmpty()
    }

    /// 是否有任何 AVX 支持 (仅 x86)
    /// 对应 Bun: hasAnyAVX() -> flags.avx or flags.avx2 or flags.avx512
    public func hasAnyAVX(): Bool {
        if (isX86) {
            return x86Flags.hasAnyAVX()
        }
        return false
    }

    /// 格式化为字符串
    /// 对应 Bun: format(features, writer) - 输出空格分隔的特性名
    public func format(): String {
        if (isX86) {
            return x86Flags.format()
        }
        return armFlags.format()
    }

    public func toString(): String {
        return format()
    }
}
