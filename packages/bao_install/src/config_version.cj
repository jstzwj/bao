// bao_install - 配置版本
// 严格翻译自: src/install/ConfigVersion.zig
//   ConfigVersion.zig 定义了 bunfig.toml 配置文件的版本号
package bao_install

import bao_core.*
import bao_collections.*
import bao_io.*
import bao_hash.*
import bao_path.*
import bao_http.*

// ============================================================================
// 配置版本
// 严格翻译自: src/install/ConfigVersion.zig
//   pub const ConfigVersion = enum {
//       v0,
//       v1,
//       pub const current: ConfigVersion = .v1;
//   }
// ============================================================================

/// 配置版本
/// 对应 Bun: ConfigVersion
public enum ConfigVersion {
    | V0
    | V1

    public operator func ==(other: ConfigVersion): Bool {
        match (this) {
            case V0 => match (other) { case V0 => true case _ => false }
            case V1 => match (other) { case V1 => true case _ => false }
        }
    }

    public operator func !=(other: ConfigVersion): Bool {
        return !(this == other)
    }
}

/// 当前版本
/// 翻译自: ConfigVersion.current = .v1
public let CONFIG_VERSION_CURRENT: ConfigVersion = ConfigVersion.V1

/// ConfigVersion 辅助类
/// 翻译自: ConfigVersion (Zig enum with methods)
public class ConfigVersionHelper {
    /// 从数值解析
    /// 翻译自: ConfigVersion.fromInt
    public static func fromInt(intValue: Int64): ?ConfigVersion {
        if (intValue == 0) {
            return ConfigVersion.V0
        }
        if (intValue == 1) {
            return ConfigVersion.V1
        }
        if (intValue > 1) {
            return CONFIG_VERSION_CURRENT
        }
        return None
    }

    /// 从 JSON 表达式解析
    /// 翻译自: ConfigVersion.fromExpr
    public static func fromExpr(value: ?JsonValue): ?ConfigVersion {
        match (value) {
            case Some(JsonValue.Number(n)) => fromInt(Int64(n))
            case _ => None
        }
    }

    /// 转为数值
    public static func toInt(v: ConfigVersion): Int64 {
        match (v) {
            case ConfigVersion.V0 => 0
            case ConfigVersion.V1 => 1
        }
    }

    /// 是否为当前版本
    public static func isCurrent(v: ConfigVersion): Bool {
        return v == CONFIG_VERSION_CURRENT
    }

    /// 是否为有效版本
    public static func isValid(v: ConfigVersion): Bool {
        match (v) {
            case ConfigVersion.V0 => true
            case ConfigVersion.V1 => true
        }
    }
}
