// 严格翻译自: src/bun_core/feature_flags.zig
//   pub const breaking_changes_1_4 = false;
//   pub const store_file_descriptors = !env.isBrowser;
//   pub const tracing = true;
//   ... (约 50 个功能标志)
//   pub fn isLibdeflateEnabled() bool { ... }
//   pub fn bake() bool { ... }
package bao_core

// ============================================================================
// FeatureFlags - 功能标志
// 严格翻译自: src/bun_core/feature_flags.zig:1-145
//   所有 pub const 布尔常量和函数
// 仓颉: 使用静态常量和静态函数实现
// ============================================================================

/// 功能标志 - 对应 Bun feature_flags.zig
/// Bun 使用编译时常量, 仓颉使用运行时常量
/// 大多数功能标志在编译时确定, 少数可在运行时通过环境变量控制
public class FeatureFlags {
    // ========================================================================
    // 编译时功能标志 - 对应 Bun pub const
    // ========================================================================

    /// 启用 1.4 版本的破坏性更改 - 对应 Bun breaking_changes_1_4
    /// pub const breaking_changes_1_4 = false;
    public static let BREAKING_CHANGES_1_4: Bool = false

    /// 存储和复用文件描述符 - 对应 Bun store_file_descriptors
    /// pub const store_file_descriptors = !env.isBrowser;
    public static let STORE_FILE_DESCRIPTORS: Bool = true

    /// 追踪 - 对应 Bun tracing
    /// pub const tracing = true;
    public static let TRACING: Bool = true

    /// CSS 支持 fence - 对应 Bun css_supports_fence
    /// pub const css_supports_fence = true;
    public static let CSS_SUPPORTS_FENCE: Bool = true

    /// 启用入口缓存 - 对应 Bun enable_entry_cache
    /// pub const enable_entry_cache = true;
    public static let ENABLE_ENTRY_CACHE: Bool = true

    /// 详细文件系统日志 - 对应 Bun verbose_fs
    /// pub const verbose_fs = false;
    public static let VERBOSE_FS: Bool = false

    /// 监视目录 - 对应 Bun watch_directories
    /// pub const watch_directories = true;
    public static let WATCH_DIRECTORIES: Bool = true

    /// JSON 允许单引号 - 对应 Bun allow_json_single_quotes
    /// pub const allow_json_single_quotes = true;
    public static let ALLOW_JSON_SINGLE_QUOTES: Bool = true

    /// 宏是否启用 - 对应 Bun is_macro_enabled
    /// pub const is_macro_enabled = !env.isWasm and !env.isWasi;
    public static let IS_MACRO_ENABLED: Bool = true

    /// 禁用 HTTP 客户端压缩 - 对应 Bun disable_compression_in_http_client
    /// pub const disable_compression_in_http_client = false;
    public static let DISABLE_COMPRESSION_IN_HTTP_CLIENT: Bool = false

    /// 启用 keepalive - 对应 Bun enable_keepalive
    /// pub const enable_keepalive = true;
    public static let ENABLE_KEEPALIVE: Bool = true

    /// 原子文件监视 - 对应 Bun atomic_file_watcher
    /// pub const atomic_file_watcher = env.isLinux;
    public static let ATOMIC_FILE_WATCHER: Bool = true

    /// HTTP 缓冲池化 - 对应 Bun http_buffer_pooling
    /// pub const http_buffer_pooling = true;
    public static let HTTP_BUFFER_POOLING: Bool = true

    /// 禁用 lolhtml - 对应 Bun disable_lolhtml
    /// pub const disable_lolhtml = false;
    public static let DISABLE_LOLHTML: Bool = false

    /// 硬编码 localhost 到 127.0.0.1 - 对应 Bun hardcode_localhost_to_127_0_0_1
    /// pub const hardcode_localhost_to_127_0_0_1 = false;
    public static let HARDCODE_LOCALHOST: Bool = false

    /// JSX transform 中支持 jsxs - 对应 Bun support_jsxs_in_jsx_transform
    /// pub const support_jsxs_in_jsx_transform = true;
    public static let SUPPORT_JSXS_IN_JSX_TRANSFORM: Bool = true

    /// 使用 simdutf - 对应 Bun use_simdutf
    /// pub const use_simdutf = bun.Environment.isNative;
    public static let USE_SIMDUTF: Bool = true

    /// 转译器中内联属性 - 对应 Bun inline_properties_in_transpiler
    /// pub const inline_properties_in_transpiler = true;
    public static let INLINE_PROPERTIES_IN_TRANSPILER: Bool = true

    /// 同目标变为解构 - 对应 Bun same_target_becomes_destructuring
    /// pub const same_target_becomes_destructuring = true;
    public static let SAME_TARGET_BECOMES_DESTRUCTURING: Bool = true

    /// 帮助捕获内存问题 - 对应 Bun help_catch_memory_issues
    /// pub const help_catch_memory_issues = bun.Environment.enable_asan or bun.Environment.isDebug;
    public static let HELP_CATCH_MEMORY_ISSUES: Bool = false

    /// 解包 CommonJS 到 ESM - 对应 Bun unwrap_commonjs_to_esm
    /// pub const unwrap_commonjs_to_esm = true;
    public static let UNWRAP_COMMONJS_TO_ESM: Bool = true

    /// Source map debug ID - 对应 Bun source_map_debug_id
    /// pub const source_map_debug_id = true;
    public static let SOURCE_MAP_DEBUG_ID: Bool = true

    /// 导出星号重定向 - 对应 Bun export_star_redirect
    /// pub const export_star_redirect = false;
    public static let EXPORT_STAR_REDIRECT: Bool = false

    /// HTTP 客户端流式文件上传 - 对应 Bun streaming_file_uploads_for_http_client
    /// pub const streaming_file_uploads_for_http_client = true;
    public static let STREAMING_FILE_UPLOADS_FOR_HTTP_CLIENT: Bool = true

    /// 并发转译器 - 对应 Bun concurrent_transpiler
    /// pub const concurrent_transpiler = true;
    public static let CONCURRENT_TRANSPILER: Bool = true

    /// 禁用 node_modules 中自动 JS 到 TS - 对应 Bun disable_auto_js_to_ts_in_node_modules
    /// pub const disable_auto_js_to_ts_in_node_modules = true;
    public static let DISABLE_AUTO_JS_TO_TS_IN_NODE_MODULES: Bool = true

    /// 运行时转译器缓存 - 对应 Bun runtime_transpiler_cache
    /// pub const runtime_transpiler_cache = true;
    public static let RUNTIME_TRANSPILER_CACHE: Bool = true

    /// Windows bunx 快速路径 - 对应 Bun windows_bunx_fast_path
    /// pub const windows_bunx_fast_path = true;
    public static let WINDOWS_BUNX_FAST_PATH: Bool = true

    /// Fetch 预连接是否支持 - 对应 Bun is_fetch_preconnect_supported
    /// pub const is_fetch_preconnect_supported = env.isPosix;
    public static let IS_FETCH_PRECONNECT_SUPPORTED: Bool = true

    /// libdeflate 支持 - 对应 Bun libdeflate_supported
    /// pub const libdeflate_supported = env.isNative;
    public static let LIBDEFLATE_SUPPORTED: Bool = true

    /// Bake 调试功能 - 对应 Bun bake_debugging_features
    /// pub const bake_debugging_features = env.is_canary or env.isDebug;
    public static let BAKE_DEBUGGING_FEATURES: Bool = false

    // ========================================================================
    // 运行时功能标志 (可通过环境变量控制)
    // ========================================================================

    /// 是否启用 libdeflate - 对应 Bun isLibdeflateEnabled()
    /// pub fn isLibdeflateEnabled() bool {
    ///     if (!libdeflate_supported) return false;
    ///     return !bun.feature_flag.BUN_FEATURE_FLAG_NO_LIBDEFLATE.get();
    /// }
    public static func isLibdeflateEnabled(): Bool {
        if (!LIBDEFLATE_SUPPORTED) {
            return false
        }
        let noLibdeflate = Env.getBool("BAO_FEATURE_FLAG_NO_LIBDEFLATE", false)
        return !noLibdeflate
    }

    /// 是否启用 bake - 对应 Bun bake()
    /// pub fn bake() bool {
    ///     return env.is_canary or env.isDebug or bun.feature_flag.BUN_FEATURE_FLAG_EXPERIMENTAL_BAKE.get();
    /// }
    public static func bake(): Bool {
        let experimentalBake = Env.getBool("BAO_FEATURE_FLAG_EXPERIMENTAL_BAKE", false)
        return Env.isDebug() || experimentalBake
    }

    // ========================================================================
    // Feature Flag 环境变量访问器
    // 对应 Bun env_var.feature_flag 命名空间
    //   pub const BUN_ASSUME_PERFECT_INCREMENTAL = newFeatureFlag(...)
    //   pub const BUN_BE_BUN = newFeatureFlag(...)
    //   ... 约 40 个 feature flag
    // ========================================================================

    /// 读取布尔类型 feature flag
    public static func getFlag(name: String, defaultValue: Bool): Bool {
        return Env.getBool(name, defaultValue)
    }

    /// 禁用原生依赖链接器 - 对应 Bun BUN_FEATURE_FLAG_DISABLE_NATIVE_DEPENDENCY_LINKER
    public static func isDisableNativeDependencyLinker(): Bool {
        return getFlag("BAO_FEATURE_FLAG_DISABLE_NATIVE_DEPENDENCY_LINKER", false)
    }

    /// 禁用忽略脚本 - 对应 Bun BUN_FEATURE_FLAG_DISABLE_IGNORE_SCRIPTS
    public static func isDisableIgnoreScripts(): Bool {
        return getFlag("BAO_FEATURE_FLAG_DISABLE_IGNORE_SCRIPTS", false)
    }

    /// 禁用地址配置 - 对应 Bun BUN_FEATURE_FLAG_DISABLE_ADDRCONFIG
    public static func isDisableAddrConfig(): Bool {
        return getFlag("BAO_FEATURE_FLAG_DISABLE_ADDRCONFIG", false)
    }

    /// 禁用异步转译器 - 对应 Bun BUN_FEATURE_FLAG_DISABLE_ASYNC_TRANSPILER
    public static func isDisableAsyncTranspiler(): Bool {
        return getFlag("BAO_FEATURE_FLAG_DISABLE_ASYNC_TRANSPILER", false)
    }

    /// 禁用 DNS 缓存 - 对应 Bun BUN_FEATURE_FLAG_DISABLE_DNS_CACHE
    public static func isDisableDnsCache(): Bool {
        return getFlag("BAO_FEATURE_FLAG_DISABLE_DNS_CACHE", false)
    }

    /// 禁用安装索引 - 对应 Bun BUN_FEATURE_FLAG_DISABLE_INSTALL_INDEX
    public static func isDisableInstallIndex(): Bool {
        return getFlag("BAO_FEATURE_FLAG_DISABLE_INSTALL_INDEX", false)
    }

    /// 禁用流式安装 - 对应 Bun BUN_FEATURE_FLAG_DISABLE_STREAMING_INSTALL
    public static func isDisableStreamingInstall(): Bool {
        return getFlag("BAO_FEATURE_FLAG_DISABLE_STREAMING_INSTALL", false)
    }

    /// 禁用 IO 池 - 对应 Bun BUN_FEATURE_FLAG_DISABLE_IO_POOL
    public static func isDisableIoPool(): Bool {
        return getFlag("BAO_FEATURE_FLAG_DISABLE_IO_POOL", false)
    }

    /// 强制 IO 池 - 对应 Bun BUN_FEATURE_FLAG_FORCE_IO_POOL
    public static func isForceIoPool(): Bool {
        return getFlag("BAO_FEATURE_FLAG_FORCE_IO_POOL", false)
    }

    /// 禁用 Redis 自动管道 - 对应 Bun BUN_FEATURE_FLAG_DISABLE_REDIS_AUTO_PIPELINING
    public static func isDisableRedisAutoPipelining(): Bool {
        return getFlag("BAO_FEATURE_FLAG_DISABLE_REDIS_AUTO_PIPELINING", false)
    }

    /// 禁用 SQL 自动管道 - 对应 Bun BUN_FEATURE_FLAG_DISABLE_SQL_AUTO_PIPELINING
    public static func isDisableSqlAutoPipelining(): Bool {
        return getFlag("BAO_FEATURE_FLAG_DISABLE_SQL_AUTO_PIPELINING", false)
    }

    /// 实验性 HTTP/2 客户端 - 对应 Bun BUN_FEATURE_FLAG_EXPERIMENTAL_HTTP2_CLIENT
    public static func isExperimentalHttp2Client(): Bool {
        return getFlag("BAO_FEATURE_FLAG_EXPERIMENTAL_HTTP2_CLIENT", false)
    }

    /// 实验性 HTTP/3 客户端 - 对应 Bun BUN_FEATURE_FLAG_EXPERIMENTAL_HTTP3_CLIENT
    public static func isExperimentalHttp3Client(): Bool {
        return getFlag("BAO_FEATURE_FLAG_EXPERIMENTAL_HTTP3_CLIENT", false)
    }

    /// 禁用 Source Maps - 对应 Bun BUN_FEATURE_FLAG_DISABLE_SOURCE_MAPS
    public static func isDisableSourceMaps(): Bool {
        return getFlag("BAO_FEATURE_FLAG_DISABLE_SOURCE_MAPS", false)
    }

    /// 禁用 spawnSync 快速路径 - 对应 Bun BUN_FEATURE_FLAG_DISABLE_SPAWNSYNC_FAST_PATH
    public static func isDisableSpawnSyncFastPath(): Bool {
        return getFlag("BAO_FEATURE_FLAG_DISABLE_SPAWNSYNC_FAST_PATH", false)
    }

    /// 禁用隔离源缓存 - 对应 Bun BUN_FEATURE_FLAG_DISABLE_ISOLATION_SOURCE_CACHE
    public static func isDisableIsolationSourceCache(): Bool {
        return getFlag("BAO_FEATURE_FLAG_DISABLE_ISOLATION_SOURCE_CACHE", false)
    }

    /// 禁用源代码预览 - 对应 Bun BUN_DISABLE_SOURCE_CODE_PREVIEW
    public static func isDisableSourceCodePreview(): Bool {
        return getFlag("BAO_DISABLE_SOURCE_CODE_PREVIEW", false)
    }

    /// 禁用转译后的源代码预览 - 对应 Bun BUN_DISABLE_TRANSPILED_SOURCE_CODE_PREVIEW
    public static func isDisableTranspiledSourceCodePreview(): Bool {
        return getFlag("BAO_DISABLE_TRANSPILED_SOURCE_CODE_PREVIEW", false)
    }

    /// Node 不显示警告 - 对应 Bun NODE_NO_WARNINGS
    public static func isNodeNoWarnings(): Bool {
        return getFlag("NODE_NO_WARNINGS", false)
    }

    /// 启用跟踪 - 对应 Bun BUN_TRACE
    public static func isTrace(): Bool {
        return getFlag("BAO_TRACE", false)
    }

    /// 启用实验性 shell 内建命令 - 对应 Bun BUN_ENABLE_EXPERIMENTAL_SHELL_BUILTINS
    public static func isEnableExperimentalShellBuiltins(): Bool {
        return getFlag("BAO_ENABLE_EXPERIMENTAL_SHELL_BUILTINS", false)
    }

    /// 转储崩溃状态 - 对应 Bun BUN_DUMP_STATE_ON_CRASH
    public static func isDumpStateOnCrash(): Bool {
        return getFlag("BAO_DUMP_STATE_ON_CRASH", false)
    }

    /// 假定完美增量 - 对应 Bun BUN_ASSUME_PERFECT_INCREMENTAL
    public static func isAssumePerfectIncremental(): Bool {
        return getFlag("BAO_ASSUME_PERFECT_INCREMENTAL", false)
    }
}
