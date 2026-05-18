// bao_core - 环境变量定义 (Bun 风格类型安全访问器)
// 严格翻译自: src/bun_core/env_var.rs
//   new!(pub PATH: string, "PATH", {});
//   new!(pub HOME: string, "HOME", {});
//   platform_specific_new!(pub HOME: string, posix = "HOME", windows = "USERPROFILE", {});
//   new_feature_flag!(pub BUN_BE_BUN, "BUN_BE_BUN", {});
// Bun: 使用 Rust 宏实现 Zig comptime 类型生成器的等价
//   每个环境变量生成一个模块, 包含 get()/key()/platform_get() 等方法
// 仓颉: 使用 EnvVarDefinition 类 + 全局注册表实现等价语义
package bao_core

import std.sync.*
import std.collection.*
import std.convert.*

// ============================================================================
// CacheOutput<V> - 缓存状态
// 严格翻译自: src/bun_core/env_var.rs CacheOutput
//   pub(crate) enum CacheOutput<V> { Unknown, NotSet, Value(V) }
// ============================================================================

/// 缓存输出状态 - 对应 Bun CacheOutput
public enum CacheOutput<V> {
    | Unknown      // 环境变量未加载
    | NotSet       // 环境变量已加载但未设置
    | Value(V)     // 环境变量已加载且有值
}

// ============================================================================
// EnvVarKind - 环境变量类型
// 严格翻译自: src/bun_core/env_var.rs kind 模块
//   kind::string, kind::boolean, kind::unsigned
// ============================================================================

/// 环境变量类型 - 对应 Bun kind
public enum EnvVarKind {
    | String      // 字符串类型
    | Boolean     // 布尔类型
    | Unsigned    // 无符号整数 (u64)
}

// ============================================================================
// EnvVarDefinition - 单个环境变量定义
// 严格翻译自: src/bun_core/env_var.rs New! / PlatformSpecificNew! 宏生成的类型
//   Zig: fn New(comptime VariantType, comptime key, comptime opts) type
//   每个环境变量有自己的 static cache
// ============================================================================

/// 缓存状态统一体
private enum EnvVarCacheState {
    | Unknown
    | NotSet
    | StringValue(String)
    | BoolValue(Bool)
    | UnsignedValue(UInt64)
}

/// 环境变量定义 - 对应 Bun New!/PlatformSpecificNew! 生成的模块
public class EnvVarDefinition {
    /// POSIX 键名
    public let posixKey: ?String
    /// Windows 键名
    public let windowsKey: ?String
    /// 运行时键名 (当前平台)
    public let key: String
    /// 变量类型
    public let kind: EnvVarKind
    /// 字符串默认值
    public let defaultString: ?String
    /// 布尔默认值
    public let defaultBool: ?Bool
    /// 无符号整数默认值
    public let defaultUnsigned: ?UInt64
    /// 缓存状态
    private var cache: EnvVarCacheState


    /// 创建字符串类型 - 对应 Bun new!(NAME: string, "KEY", {})
    public init(key: String, kind: EnvVarKind, default: ?String) {
        this.posixKey = Some(key)
        this.windowsKey = Some(key)
        this.key = key
        this.kind = kind
        this.defaultString = default
        this.defaultBool = Option<Bool>.None
        this.defaultUnsigned = Option<UInt64>.None
        this.cache = EnvVarCacheState.Unknown
    }

    /// 创建布尔类型 - 对应 Bun new!(NAME: boolean, "KEY", { default: false })
    public init(key: String, default: Bool) {
        this.posixKey = Some(key)
        this.windowsKey = Some(key)
        this.key = key
        this.kind = EnvVarKind.Boolean
        this.defaultString = Option<String>.None
        this.defaultBool = Some(default)
        this.defaultUnsigned = Option<UInt64>.None
        this.cache = EnvVarCacheState.Unknown
    }

    /// 创建无符号整数类型 - 对应 Bun new!(NAME: unsigned, "KEY", { default: 30 })
    public init(key: String, default: UInt64) {
        this.posixKey = Some(key)
        this.windowsKey = Some(key)
        this.key = key
        this.kind = EnvVarKind.Unsigned
        this.defaultString = Option<String>.None
        this.defaultBool = Option<Bool>.None
        this.defaultUnsigned = Some(default)
        this.cache = EnvVarCacheState.Unknown
    }

    /// 平台特定创建 - 对应 Bun platform_specific_new!
    public init(posixKey: ?String, windowsKey: ?String, kind: EnvVarKind) {
        this.posixKey = posixKey
        this.windowsKey = windowsKey
        // 使用 POSIX 键作为默认
        this.key = match (posixKey) {
            case Some(k) => k
            case Option<String>.None => match (windowsKey) {
                case Some(k) => k
                case Option<String>.None => ""
            }
        }
        this.kind = kind
        this.defaultString = Option<String>.None
        this.defaultBool = Option<Bool>.None
        this.defaultUnsigned = Option<UInt64>.None
        this.cache = EnvVarCacheState.Unknown
    }

    // ========================================================================
    // 获取方法 - 对应 Bun .get() / .platform_get()
    // ========================================================================

    /// 获取值 - 对应 Bun get()
    /// 返回根据类型解析的值
    public func getString(): ?String {
        match (cache) {
            case EnvVarCacheState.StringValue(v) => return Some(v)
            case EnvVarCacheState.NotSet => return defaultString
            case EnvVarCacheState.Unknown =>
                let raw = EnvVar.getRawEnv(key)
                if (raw.size > 0) {
                    cache = EnvVarCacheState.StringValue(raw)
                    return Some(raw)
                }
                let exists = EnvVar.envExists(key)
                if (exists) {
                    cache = EnvVarCacheState.StringValue("")
                    return Some("")
                }
                cache = EnvVarCacheState.NotSet
                return defaultString
            case _ => return defaultString
        }
    }

    /// 获取非空字符串 - 对应 Bun get_not_empty()
    public func getStringNotEmpty(): ?String {
        match (getString()) {
            case Some(v) =>
                if (v.size == 0) { return Option<String>.None }
                return Some(v)
            case Option<String>.None => return Option<String>.None
        }
    }

    /// 获取布尔值 - 对应 Bun .get() for boolean
    public func getBool(): ?Bool {
        match (cache) {
            case EnvVarCacheState.BoolValue(v) => return Some(v)
            case EnvVarCacheState.NotSet => return defaultBool
            case EnvVarCacheState.Unknown =>
                let raw = EnvVar.getRawEnv(key)
                if (raw.size > 0) {
                    let truthy = stringIsTruthy(raw)
                    cache = EnvVarCacheState.BoolValue(truthy)
                    return Some(truthy)
                }
                let exists = EnvVar.envExists(key)
                if (exists) {
                    let truthy = stringIsTruthy("")
                    cache = EnvVarCacheState.BoolValue(truthy)
                    return Some(truthy)
                }
                cache = EnvVarCacheState.NotSet
                return defaultBool
            case _ => return defaultBool
        }
    }

    /// 获取无符号整数值 - 对应 Bun .get() for unsigned
    public func getUnsigned(): ?UInt64 {
        match (cache) {
            case EnvVarCacheState.UnsignedValue(v) => return Some(v)
            case EnvVarCacheState.NotSet => return defaultUnsigned
            case EnvVarCacheState.Unknown =>
                let raw = EnvVar.getRawEnv(key)
                if (raw.size > 0) {
                    try {
                        let value = UInt64.parse(raw)
                        cache = EnvVarCacheState.UnsignedValue(value)
                        return Some(value)
                    } catch (_: Exception) {
                        cache = EnvVarCacheState.NotSet
                        return defaultUnsigned
                    }
                }
                cache = EnvVarCacheState.NotSet
                return defaultUnsigned
            case _ => return defaultUnsigned
        }
    }

    /// 强制重新加载 - 对应 Bun get_force_reload()
    public func forceReload(): Unit {
        cache = EnvVarCacheState.Unknown
    }

    /// 获取键名 - 对应 Bun .key()
    public func getKey(): String {
        return key
    }

    /// 获取平台键名 - 对应 Bun .platform_key()
    public func platformKey(): ?String {
        // Linux/POSIX 使用 posixKey
        return posixKey
    }

    /// 是否为真 - 对应 Bun boolean::string_is_truthy
    /// "", "0", "false", "no", "off" → false; 其他 → true
    public static func stringIsTruthy(s: String): Bool {
        let lower = s.toAsciiLower()
        if (lower == "" || lower == "0" || lower == "false" || lower == "no" || lower == "off") {
            return false
        }
        return true
    }
}

// ============================================================================
// BunEnvVar - Bun 的所有环境变量定义
// 严格翻译自: src/bun_core/env_var.rs 中的 new!/platform_specific_new! 声明
//   对应 Bun 的 ~130 个环境变量定义
// ============================================================================

/// Bun 环境变量注册表 - 对应 Bun env_var 模块导出
public class BunEnvVar {
    // 字符串类型
    public static let AGENT = EnvVarDefinition("AGENT", EnvVarKind.String, Option<String>.None)
    public static let BUN_INSTALL = EnvVarDefinition("BUN_INSTALL", EnvVarKind.String, Option<String>.None)
    public static let BUN_DEBUG = EnvVarDefinition("BUN_DEBUG", EnvVarKind.String, Option<String>.None)
    public static let BUN_INSPECT = EnvVarDefinition("BUN_INSPECT", EnvVarKind.String, Some(""))
    public static let BUN_INSPECT_CONNECT_TO = EnvVarDefinition("BUN_INSPECT_CONNECT_TO", EnvVarKind.String, Some(""))
    public static let BUN_CRASH_REPORT_URL = EnvVarDefinition("BUN_CRASH_REPORT_URL", EnvVarKind.String, Option<String>.None)
    public static let PATH = EnvVarDefinition("PATH", EnvVarKind.String, Option<String>.None)
    public static let HOME = EnvVarDefinition(Some("HOME"), Some("USERPROFILE"), EnvVarKind.String)
    public static let USER = EnvVarDefinition(Some("USER"), Some("USERNAME"), EnvVarKind.String)
    public static let SHELL = EnvVarDefinition(Some("SHELL"), Option<String>.None, EnvVarKind.String)
    public static let TERM = EnvVarDefinition("TERM", EnvVarKind.String, Option<String>.None)
    public static let TERM_PROGRAM = EnvVarDefinition("TERM_PROGRAM", EnvVarKind.String, Option<String>.None)
    public static let TMPDIR = EnvVarDefinition(Some("TMPDIR"), Some("TMPDIR"), EnvVarKind.String)
    public static let NODE_ENV = EnvVarDefinition("NODE_ENV", EnvVarKind.String, Option<String>.None)
    public static let COLORTERM = EnvVarDefinition("COLORTERM", EnvVarKind.String, Option<String>.None)
    public static let XDG_CACHE_HOME = EnvVarDefinition("XDG_CACHE_HOME", EnvVarKind.String, Option<String>.None)
    public static let XDG_CONFIG_HOME = EnvVarDefinition("XDG_CONFIG_HOME", EnvVarKind.String, Option<String>.None)
    public static let XDG_DATA_HOME = EnvVarDefinition("XDG_DATA_HOME", EnvVarKind.String, Option<String>.None)
    public static let EDITOR = EnvVarDefinition("EDITOR", EnvVarKind.String, Option<String>.None)
    public static let LANG = EnvVarDefinition("LANG", EnvVarKind.String, Option<String>.None)
    public static let BUN_OPTIONS = EnvVarDefinition("BUN_OPTIONS", EnvVarKind.String, Option<String>.None)
    public static let GIT_SHA = EnvVarDefinition("GIT_SHA", EnvVarKind.String, Option<String>.None)
    public static let TMUX = EnvVarDefinition("TMUX", EnvVarKind.String, Option<String>.None)
    public static let ZDOTDIR = EnvVarDefinition("ZDOTDIR", EnvVarKind.String, Option<String>.None)

    // 布尔类型
    public static let CI = EnvVarDefinition("CI", false)
    public static let NO_COLOR = EnvVarDefinition("NO_COLOR", false)
    public static let GITHUB_ACTIONS = EnvVarDefinition("GITHUB_ACTIONS", false)
    public static let DO_NOT_TRACK = EnvVarDefinition("DO_NOT_TRACK", false)
    public static let BUN_ENABLE_CRASH_REPORTING = EnvVarDefinition("BUN_ENABLE_CRASH_REPORTING", false)
    public static let BUN_DEBUG_ALL = EnvVarDefinition("BUN_DEBUG_ALL", false)
    public static let BUN_DEBUG_QUIET_LOGS = EnvVarDefinition("BUN_DEBUG_QUIET_LOGS", false)
    public static let BUN_DEBUG_CSS_ORDER = EnvVarDefinition("BUN_DEBUG_CSS_ORDER", false)
    public static let IS_BUN_AUTO_UPDATE = EnvVarDefinition("IS_BUN_AUTO_UPDATE", false)
    public static let MI_VERBOSE = EnvVarDefinition("MI_VERBOSE", false)
    public static let REPL_ID = EnvVarDefinition("REPL_ID", false)
    public static let RUNNER_DEBUG = EnvVarDefinition("RUNNER_DEBUG", false)
    public static let WANTS_LOUD = EnvVarDefinition("WANTS_LOUD", false)

    // 无符号整数类型
    public static let FORCE_COLOR = EnvVarDefinition("FORCE_COLOR", UInt64(0))
    public static let BUN_CONFIG_DNS_TIME_TO_LIVE_SECONDS = EnvVarDefinition("BUN_CONFIG_DNS_TIME_TO_LIVE_SECONDS", UInt64(30))
    public static let BUN_CONFIG_HTTP_IDLE_TIMEOUT = EnvVarDefinition("BUN_CONFIG_HTTP_IDLE_TIMEOUT", UInt64(300))
    public static let BUN_INOTIFY_COALESCE_INTERVAL = EnvVarDefinition("BUN_INOTIFY_COALESCE_INTERVAL", UInt64(100_000))
    public static let BUN_INSTALL_STREAMING_MIN_SIZE = EnvVarDefinition("BUN_INSTALL_STREAMING_MIN_SIZE", UInt64(2 * 1024 * 1024))
    public static let BUN_DEBUG_HASH_RANDOM_SEED = EnvVarDefinition("BUN_DEBUG_HASH_RANDOM_SEED", UInt64(0))

    // ========================================================================
    // Feature Flags - 对应 Bun feature_flag 模块
    // ========================================================================

    /// 特性标志 - 对应 Bun new_feature_flag!
    public static let BUN_BE_BUN = EnvVarDefinition("BUN_BE_BUN", false)
    public static let BUN_FEATURE_FLAG_EXPERIMENTAL_BAKE = EnvVarDefinition("BUN_FEATURE_FLAG_EXPERIMENTAL_BAKE", false)
    public static let BUN_FEATURE_FLAG_EXPERIMENTAL_HTTP2_CLIENT = EnvVarDefinition("BUN_FEATURE_FLAG_EXPERIMENTAL_HTTP2_CLIENT", false)
    public static let BUN_FEATURE_FLAG_EXPERIMENTAL_HTTP3_CLIENT = EnvVarDefinition("BUN_FEATURE_FLAG_EXPERIMENTAL_HTTP3_CLIENT", false)
    public static let BUN_FEATURE_FLAG_DISABLE_STREAMING_INSTALL = EnvVarDefinition("BUN_FEATURE_FLAG_DISABLE_STREAMING_INSTALL", false)
    public static let BUN_FEATURE_FLAG_DISABLE_DNS_CACHE = EnvVarDefinition("BUN_FEATURE_FLAG_DISABLE_DNS_CACHE", false)
    public static let BUN_FEATURE_FLAG_DISABLE_IO_POOL = EnvVarDefinition("BUN_FEATURE_FLAG_DISABLE_IO_POOL", false)
    public static let BUN_FEATURE_FLAG_FORCE_IO_POOL = EnvVarDefinition("BUN_FEATURE_FLAG_FORCE_IO_POOL", false)
    public static let BUN_ENABLE_EXPERIMENTAL_SHELL_BUILTINS = EnvVarDefinition("BUN_ENABLE_EXPERIMENTAL_SHELL_BUILTINS", false)
    public static let NODE_NO_WARNINGS = EnvVarDefinition("NODE_NO_WARNINGS", false)
    public static let BUN_TRACE = EnvVarDefinition("BUN_TRACE", false)
}
