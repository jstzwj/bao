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

    /// 当前版本
    /// 翻译自: ConfigVersion.current = .v1
    public static let CURRENT: ConfigVersion = ConfigVersion.V1

    /// 从数值解析
    /// 翻译自: ConfigVersion.fromInt
    public static func fromInt(intValue: Int64): ?ConfigVersion {
        match (intValue) {
            case 0 => return V0
            case 1 => return V1
            case _ => {
                if (intValue > 1) {
                    return CURRENT
                }
                return None
            }
        }
    }

    /// 从 JSON 表达式解析
    /// 翻译自: ConfigVersion.fromExpr
    public static func fromExpr(value: ?JsonValue): ?ConfigVersion {
        match (value) {
            case Some(JsonValue.Number(n)) => {
                let intVal = Int64(n)
                return fromInt(intVal)
            }
            case _ => return None
        }
    }

    /// 转为数值
    public func toInt(): Int64 {
        match (this) {
            case V0 => return 0
            case V1 => return 1
        }
    }

    /// 是否为当前版本
    public func isCurrent(): Bool {
        return this == CURRENT
    }

    /// 是否为有效版本
    public func isValid(): Bool {
        match (this) {
            case V0 => return true
            case V1 => return true
        }
    }
}
