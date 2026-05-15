// BundleEnums - 打包格式与 Windows 选项
// 严格翻译自: bun/src/options_types/BundleEnums.zig
package bao_options

import bao_core.*

// ============================================================================
// Format - 输出格式
// 严格翻译自: BundleEnums.zig - Format
//   pub const Format = enum { esm, iife, cjs, internal_bake_dev };
// ============================================================================

/// 输出格式 - 对应 Bun Format
public enum BundleFormat {
    | Esm
    | Iife
    | Cjs
    | InternalBakeDev
    | this
}

    /// 是否为 ESM 格式
    public func isESM(): Bool {
        this == BundleFormat.Esm
    }

    /// 是否始终使用严格模式
    public func isAlwaysStrictMode(): Bool {
        this == BundleFormat.Esm
    }

    /// 从字符串解析格式
    public static func fromString(slice: String): ?BundleFormat {
        match (slice) {
            case "esm" => BundleFormat.Esm
            case "cjs" => BundleFormat.Cjs
            case "iife" => BundleFormat.Iife
            case "internal_bake_dev" => BundleFormat.InternalBakeDev
            case _ => None
        }
    }

    /// 转换为字符串
    public func toString(): String {
        match (this) {
            case Esm => "esm"
            case Iife => "iife"
            case Cjs => "cjs"
            case InternalBakeDev => "internal_bake_dev"
        }
    }
}

// ============================================================================
// WindowsOptions - Windows 可执行文件选项
// 严格翻译自: BundleEnums.zig - WindowsOptions
//   pub const WindowsOptions = struct {
//       hide_console: bool = false,
//       icon: ?[]const u8 = null,
//       title: ?[]const u8 = null,
//       publisher: ?[]const u8 = null,
//       version: ?[]const u8 = null,
//       description: ?[]const u8 = null,
//       copyright: ?[]const u8 = null,
//   };
// ============================================================================

/// Windows 可执行文件选项 - 对应 Bun WindowsOptions
public class WindowsOptions {
    public var hideConsole: Bool
    public var icon: ?String
    public var title: ?String
    public var publisher: ?String
    public var version: ?String
    public var description: ?String
    public var copyright: ?String

    public init() {
        hideConsole = false
        icon = None
        title = None
        publisher = None
        version = None
        description = None
        copyright = None
    }
}

// ============================================================================
// BundlePackage - 包打包策略
// 严格翻译自: BundleEnums.zig - BundlePackage
//   pub const BundlePackage = enum { always, never };
// ============================================================================

/// 包打包策略 - 对应 Bun BundlePackage
public enum BundlePackage {
    | Always
    | Never
}
