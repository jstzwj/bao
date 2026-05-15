// CompileTarget - 编译目标
// 严格翻译自: bun/src/options_types/CompileTarget.zig
//   用于 `bun build --compile` 的编译目标配置
package bao_options

import bao_core.*

// ============================================================================
// OperatingSystem - 操作系统
// 严格翻译自: CompileTarget.zig 中引用的 Environment.OperatingSystem
// ============================================================================

/// 操作系统枚举
public enum OperatingSystem {
    | Linux
    | Mac
    | Windows
    | FreeBSD
    | Wasm

    /// NPM 包名中的操作系统标识
    public func npmName(): String {
        match (this) {
            case Linux => "linux"
            case Mac => "darwin"
            case Windows => "windows"
            case FreeBSD => "freebsd"
            case Wasm => "wasm"
        }
    }

    /// 显示名称
    public func nameString(): String {
        npmName()
    }

    /// 从字符串解析
    public static func fromString(s: String): ?OperatingSystem {
        match (s) {
            case "linux" => OperatingSystem.Linux
            case "darwin" | "mac" | "macos" => OperatingSystem.Mac
            case "windows" | "win32" => OperatingSystem.Windows
            case "freebsd" => OperatingSystem.FreeBSD
            case "wasm" => OperatingSystem.Wasm
            case _ => None
        }
    }
}

// ============================================================================
// Architecture - CPU 架构
// 严格翻译自: CompileTarget.zig 中引用的 Environment.Architecture
// ============================================================================

/// CPU 架构枚举
public enum Architecture {
    | X64
    | Arm64
    | Wasm

    /// NPM 包名中的架构标识
    public func npmName(): String {
        match (this) {
            case X64 => "x64"
            case Arm64 => "arm64"
            case Wasm => "wasm"
        }
    }

    /// 从字符串解析
    public static func fromString(s: String): ?Architecture {
        match (s) {
            case "x64" | "x86_64" => Architecture.X64
            case "arm64" | "aarch64" => Architecture.Arm64
            case "wasm" => Architecture.Wasm
            case _ => None
        }
    }
}

// ============================================================================
// Libc - C 标准库类型
// 严格翻译自: CompileTarget.zig - Libc
//   const Libc = enum { default, musl, android };
// ============================================================================

/// C 标准库类型 - 对应 Bun Libc
public enum Libc {
    | Default   // 默认 libc (Linux 上为 glibc)
    | Musl      // musl libc
    | Android   // bionic (Android)

    /// NPM 包名后缀
    public func npmName(): String {
        match (this) {
            case Default => ""
            case Musl => "-musl"
            case Android => "-android"
        }
    }
}

// ============================================================================
// CompileTarget - 编译目标
// 严格翻译自: CompileTarget.zig
//   const CompileTarget = @This();
//   os: Environment.OperatingSystem = Environment.os,
//   arch: Environment.Architecture = Environment.arch,
//   baseline: bool = !Environment.enableSIMD,
//   version: bun.Semver.Version = ...,
//   libc: Libc = ...
// ============================================================================

/// 编译目标 - 对应 Bun CompileTarget
/// 用于 `bun build --compile` 指定目标平台
public class CompileTarget {
    /// 目标操作系统
    public var os: OperatingSystem
    /// 目标 CPU 架构
    public var arch: Architecture
    /// 是否使用基线指令集 (不使用 SIMD)
    public var baseline: Bool
    /// Bun 版本号
    public var major: Int64
    public var minor: Int64
    public var patch: Int64
    /// C 标准库类型
    public var libc: Libc

    public init() {
        os = OperatingSystem.Linux
        arch = Architecture.X64
        baseline = false
        major = 1
        minor = 0
        patch = 0
        libc = Libc.Default
    }

    public init(os: OperatingSystem, arch: Architecture, baseline: Bool,
                major: Int64, minor: Int64, patch: Int64, libc: Libc) {
        this.os = os
        this.arch = arch
        this.baseline = baseline
        this.major = major
        this.minor = minor
        this.patch = patch
        this.libc = libc
    }

    /// 判断是否与另一个编译目标相等
    /// 对应 Bun CompileTarget.eql()
    public func eql(other: CompileTarget): Bool {
        os == other.os && arch == other.arch && baseline == other.baseline &&
        major == other.major && minor == other.minor && patch == other.patch &&
        libc == other.libc
    }

    /// 是否为默认编译目标
    /// 对应 Bun CompileTarget.isDefault()
    public func isDefault(): Bool {
        let default = CompileTarget()
        eql(default)
    }

    /// 是否为支持的目标平台
    /// 对应 Bun CompileTarget.isSupported()
    public func isSupported(): Bool {
        match (os) {
            case Windows => arch == Architecture.X64 || arch == Architecture.Arm64
            case Mac => true
            case Linux => true
            case FreeBSD => true
            case Wasm => false
        }
    }

    /// 格式化为字符串 (如 "bun-darwin-x64-baseline-v1.0.0")
    /// 对应 Bun CompileTarget.format()
    public func toString(): String {
        let baselineStr = if (baseline) "-baseline" else ""
        let libcStr = libc.npmName()
        "bun-${os.npmName()}-${arch.npmName()}${libcStr}${baselineStr}-v${major}.${minor}.${patch}"
    }

    /// 从字符串解析编译目标
    /// 对应 Bun CompileTarget.tryFrom()
    /// 格式: "bun-darwin-x64-musl-baseline-v1.0.0" (顺序无关)
    public static func tryFrom(input: String): ?CompileTarget {
        var target = CompileTarget()
        let trimmed = input.trim()

        if (trimmed.size == 0) {
            return target
        }

        var foundOs = false
        var foundArch = false
        var foundBaseline = false
        var foundLibc = false

        // 按 '-' 分割并解析每个 token
        let parts = trimmed.split("-")
        for (part in parts) {
            if (part.size == 0) {
                continue
            }

            // 尝试解析为架构
            let archOpt = Architecture.fromString(part)
            if (archOpt.isSome()) {
                target.arch = archOpt.getOrThrow()
                foundArch = true
                continue
            }

            // 尝试解析为操作系统
            let osOpt = OperatingSystem.fromString(part)
            if (osOpt.isSome()) {
                target.os = osOpt.getOrThrow()
                foundOs = true
                continue
            }

            // 基线指令集
            if (part == "modern") {
                target.baseline = false
                foundBaseline = true
                continue
            }
            if (part == "baseline") {
                target.baseline = true
                foundBaseline = true
                continue
            }

            // 版本号 (v1.x.x 或 v0.x.x)
            if (part.startsWith("v1.") || part.startsWith("v0.")) {
                let versionStr = part.subString(1)
                let versionParts = versionStr.split(".")
                if (versionParts.size >= 3) {
                    let maj = Int64(versionParts[0])
                    let min = Int64(versionParts[1])
                    let pat = Int64(versionParts[2])
                    if (maj >= 0 && min >= 0 && pat >= 0) {
                        target.major = maj
                        target.minor = min
                        target.patch = pat
                        continue
                    }
                }
            }

            // C 标准库
            if (part == "musl") {
                target.libc = Libc.Musl
                foundLibc = true
                continue
            }
            if (part == "android") {
                target.libc = Libc.Android
                foundLibc = true
                continue
            }

            // 未知 token
            return None
        }

        // 如果指定了 OS 但没指定架构，默认为 x64
        if (foundOs && !foundArch) {
            target.arch = Architecture.X64
        }

        // arm64 没有 baseline
        if (target.baseline && target.arch == Architecture.Arm64) {
            target.baseline = false
        }

        // 非 Linux 不支持 musl/android
        if (target.libc != Libc.Default && target.os != OperatingSystem.Linux) {
            return None
        }

        // wasm 不支持
        if (target.arch == Architecture.Wasm || target.os == OperatingSystem.Wasm) {
            return None
        }

        return target
    }

    /// 获取定义键 (process.platform, process.arch, process.versions.bun)
    /// 对应 Bun CompileTarget.defineKeys()
    public func defineKeys(): ArrayList<String> {
        let keys = ArrayList<String>()
        keys.append("process.platform")
        keys.append("process.arch")
        keys.append("process.versions.bun")
        keys
    }

    /// 获取定义值
    /// 对应 Bun CompileTarget.defineValues()
    public func defineValues(): ArrayList<String> {
        let values = ArrayList<String>()
        // process.platform
        if (libc == Libc.Android) {
            values.append("\"android\"")
        } else {
            values.append("\"${os.npmName()}\"")
        }
        // process.arch
        match (arch) {
            case X64 => values.append("\"x64\"")
            case Arm64 => values.append("\"arm64\"")
            case _ => values.append("\"unknown\"")
        }
        // process.versions.bun
        values.append("\"${major}.${minor}.${patch}\"")
        values
    }
}
