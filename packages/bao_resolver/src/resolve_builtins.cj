// 内建模块解析
// 严格翻译自: src/resolve_builtins/resolve_builtins.zig
//   src/resolve_builtins/HardcodedModule.zig - HardcodedModule 枚举与 Alias 查找表
//   src/resolve_builtins/node_builtins.rs - Node.js 内建模块名称列表
//   src/resolve_builtins/HardcodedModule.rs - Rust 端口对应实现
//
// Bun 的 resolve_builtins 是模块解析系统的前置阶段，负责:
//   1. 判断模块说明符是否为 Node.js 内建模块 (fs, path, http 等)
//   2. 判断模块说明符是否为 Bun 专有内建模块 (bun:sqlite, bun:test 等)
//   3. 维护内建模块的别名映射 (如 "sys" -> "node:util")
//   4. 剥离 "node:" 前缀以获取裸模块名
//   5. 为 bundler 提供内建模块分类 (Node/Bun/Internal)
//
// Bun 源码结构:
//   HardcodedModule.zig:
//     pub const HardcodedModule = enum { bun, @"bun:app", @"node:fs", ... }
//     pub const map = bun.ComptimeStringMap(HardcodedModule, ...)
//     pub const Alias = struct { path, tag, node_builtin, node_only_prefix }
//     pub const Alias.common_alias_kvs = [...]  // Node.js 内建模块别名
//     pub const Alias.bun_extra_alias_kvs = [...] // Bun 额外别名
//     pub const Alias.bun_test_extra_alias_kvs = [...] // 测试框架别名
//     pub const Alias.node_aliases / bun_aliases / bun_test_aliases
//
//   node_builtins.rs:
//     NODE_BUILTIN_PATTERNS_RAW - 57 个 Node.js 核心模块裸名
//     NODE_BUILTIN_PATTERNS - RAW + "node:" 前缀版本 (114 个)
//     BUN_NODE_BUILTIN_PATTERNS_COMPAT - 52 个 Bun 兼容子集 (排除 buffer/fs/path/process/test)
package bao_resolver

import bao_core.*
import bao_collections.*

// ============================================================================
// BuiltinCategory - 内建模块分类
// 严格翻译自: Bun 对内建模块的分类逻辑
// Bun 通过 Alias.tag 和前缀隐式分类:
//   - "bun:" 前缀 -> Bun 专有
//   - "node:" 前缀或 Node.js 核心模块名 -> Node.js
//   - 内部模块 (下划线前缀) -> Internal
// ============================================================================

/// 内建模块分类 - 对应 Bun 中通过前缀和 tag 隐式分类的逻辑
/// Bun: 通过 Alias.tag (.builtin vs .bun) 和路径前缀判断
public enum BuiltinCategory {
    | Node      // Node.js 核心模块 (fs, path, http, node:fs 等)
    | Bun       // Bun 专有模块 (bun, bun:sqlite, bun:test 等)
    | Internal  // 内部模块 (以 _ 开头的模块，如 _http_agent)
    | ThirdParty // 第三方覆盖包 (undici, ws, node-fetch 等)

    /// 分类标签
    public func label(): String {
        match (this) {
            case Node => "node"
            case Bun => "bun"
            case Internal => "internal"
            case ThirdParty => "third-party"
        }
    }
}

// ============================================================================
// ImportTag - 导入记录标签
// 严格翻译自: src/options_types/import_record.zig ImportRecord.Tag
// Bun:
//   pub const Tag = enum {
//       none,
//       builtin,     // Node.js 内建模块
//       commonjs,    // CommonJS 模块
//       esm,         // ES Module
//       bun,         // Bun 模块 (tag = .bun 仅用于 "bun" 本身)
//       ...
//   }
// ============================================================================

/// 导入记录标签 - 对应 Bun ImportRecord.Tag
public enum ImportTag {
    | None       // 无标签
    | Builtin    // 内建模块 (Node.js 内建 + 大多数 Bun 内建)
    | Bun        // Bun 模块 (仅 "bun" 本身使用此标签)
    | CommonJS   // CommonJS 模块
    | ESM        // ES Module

    public func label(): String {
        match (this) {
            case None => "none"
            case Builtin => "builtin"
            case Bun => "bun"
            case CommonJS => "commonjs"
            case ESM => "esm"
        }
    }
}

// ============================================================================
// BuiltinAlias - 内建模块别名
// 严格翻译自: HardcodedModule.zig Alias struct
// Bun:
//   pub const Alias = struct {
//       path: [:0]const u8,
//       tag: ImportRecord.Tag = .builtin,
//       node_builtin: bool = false,
//       node_only_prefix: bool = false,
//   }
//
// 别名用于将模块说明符映射到实际解析路径:
//   "sys" -> BuiltinAlias(path="node:util", node_builtin=true)
//   "ffi" -> BuiltinAlias(path="bun:ffi")
//   "node:fs" -> BuiltinAlias(path="node:fs", node_builtin=true)
// ============================================================================

/// 内建模块别名 - 对应 Bun HardcodedModule.Alias
/// Bun: path 是解析后的标准路径名
/// node_builtin: 是否为 Node.js 内建模块
/// node_only_prefix: 是否只能通过 "node:" 前缀解析 (如 node:test)
public class BuiltinAlias {
    /// 解析后的标准路径 - 对应 Bun Alias.path
    /// 例如 "node:util", "bun:ffi", "node:fs"
    public var path: String
    /// 导入标签 - 对应 Bun Alias.tag
    public var tag: ImportTag
    /// 是否为 Node.js 内建模块 - 对应 Bun Alias.node_builtin
    public var nodeBuiltin: Bool
    /// 是否仅支持 node: 前缀 - 对应 Bun Alias.node_only_prefix
    /// 例如 node:test 只能通过 "node:test" 解析，不能通过 "test" 解析
    public var nodeOnlyPrefix: Bool

    public init() {
        path = ""
        tag = ImportTag.Builtin
        nodeBuiltin = false
        nodeOnlyPrefix = false
    }

    public init(path: String, tag: ImportTag, nodeBuiltin: Bool, nodeOnlyPrefix: Bool) {
        this.path = path
        this.tag = tag
        this.nodeBuiltin = nodeBuiltin
        this.nodeOnlyPrefix = nodeOnlyPrefix
    }
}

// ============================================================================
// HardcodedModule - 硬编码模块枚举
// 严格翻译自: HardcodedModule.zig
// Bun:
//   pub const HardcodedModule = enum {
//       bun,
//       @"bun:app",
//       @"bun:ffi",
//       @"bun:jsc",
//       @"bun:main",
//       @"bun:test",
//       @"bun:wrap",
//       @"bun:sqlite",
//       @"node:assert",
//       @"node:assert/strict",
//       ... (所有 Node.js 内建模块)
//       undici,
//       ws,
//       @"isomorphic-fetch",
//       @"node-fetch",
//       vercel_fetch,
//       @"utf-8-validate",
//       @"abort-controller",
//       @"bun:internal-for-testing",
//   }
//
// Bun 使用 ComptimeStringMap 进行 O(1) 查找:
//   pub const map = bun.ComptimeStringMap(HardcodedModule, ...)
// ============================================================================

/// 硬编码模块枚举 - 对应 Bun HardcodedModule
/// 每个变体代表一个已知的内建或覆盖模块
/// 用于模块加载器在查找文件系统前识别模块
public enum HardcodedModule {
    // ===== Bun 专有模块 =====
    | Bun                       // "bun"
    | BunApp                    // "bun:app"
    | BunFfi                    // "bun:ffi"
    | BunJsc                    // "bun:jsc"
    | BunMain                   // "bun:main"
    | BunTest                   // "bun:test"
    | BunWrap                   // "bun:wrap"
    | BunSqlite                 // "bun:sqlite"
    | BunInternalForTesting     // "bun:internal-for-testing" - 需要 --expose-internals

    // ===== Node.js 核心模块 (带 node: 前缀) =====
    | NodeAssert                // "node:assert"
    | NodeAssertStrict          // "node:assert/strict"
    | NodeAsyncHooks            // "node:async_hooks"
    | NodeBuffer                // "node:buffer"
    | NodeChildProcess          // "node:child_process"
    | NodeCluster               // "node:cluster"
    | NodeConsole               // "node:console"
    | NodeConstants             // "node:constants"
    | NodeCrypto                // "node:crypto"
    | NodeDgram                 // "node:dgram"
    | NodeDiagnosticsChannel    // "node:diagnostics_channel"
    | NodeDns                   // "node:dns"
    | NodeDnsPromises           // "node:dns/promises"
    | NodeDomain                // "node:domain"
    | NodeEvents                // "node:events"
    | NodeFs                    // "node:fs"
    | NodeFsPromises            // "node:fs/promises"
    | NodeHttp                  // "node:http"
    | NodeHttp2                 // "node:http2"
    | NodeHttps                 // "node:https"
    | NodeInspector             // "node:inspector"
    | NodeInspectorPromises     // "node:inspector/promises"
    | NodeModule                // "node:module"
    | NodeNet                   // "node:net"
    | NodeOs                    // "node:os"
    | NodePath                  // "node:path"
    | NodePathPosix             // "node:path/posix"
    | NodePathWin32             // "node:path/win32"
    | NodePerfHooks             // "node:perf_hooks"
    | NodeProcess               // "node:process"
    | NodePunycode              // "node:punycode"
    | NodeQuerystring           // "node:querystring"
    | NodeReadline              // "node:readline"
    | NodeReadlinePromises      // "node:readline/promises"
    | NodeRepl                  // "node:repl"
    | NodeStream                // "node:stream"
    | NodeStreamConsumers       // "node:stream/consumers"
    | NodeStreamPromises        // "node:stream/promises"
    | NodeStreamWeb             // "node:stream/web"
    | NodeStringDecoder         // "node:string_decoder"
    | NodeTest                  // "node:test"
    | NodeTimers                // "node:timers"
    | NodeTimersPromises        // "node:timers/promises"
    | NodeTls                   // "node:tls"
    | NodeTraceEvents           // "node:trace_events"
    | NodeTty                   // "node:tty"
    | NodeUrl                   // "node:url"
    | NodeUtil                  // "node:util"
    | NodeUtilTypes             // "node:util/types"
    | NodeV8                    // "node:v8"
    | NodeVm                    // "node:vm"
    | NodeWasi                  // "node:wasi"
    | NodeWorkerThreads         // "node:worker_threads"
    | NodeZlib                  // "node:zlib"

    // ===== Node.js 内部模块 =====
    | NodeStreamDuplexInternal       // "node:_stream_duplex"
    | NodeStreamPassthroughInternal  // "node:_stream_passthrough"
    | NodeStreamReadableInternal     // "node:_stream_readable"
    | NodeStreamTransformInternal    // "node:_stream_transform"
    | NodeStreamWrapInternal         // "node:_stream_wrap"
    | NodeStreamWritableInternal     // "node:_stream_writable"
    | NodeTlsCommonInternal          // "node:_tls_common"
    | NodeHttpAgentInternal          // "node:_http_agent"
    | NodeHttpClientInternal         // "node:_http_client"
    | NodeHttpCommonInternal         // "node:_http_common"
    | NodeHttpIncomingInternal       // "node:_http_incoming"
    | NodeHttpOutgoingInternal       // "node:_http_outgoing"
    | NodeHttpServerInternal         // "node:_http_server"

    // ===== 第三方覆盖包 =====
    | AbortController           // "abort-controller"
    | Undici                    // "undici"
    | Ws                        // "ws"
    | IsomorphicFetch           // "isomorphic-fetch"
    | NodeFetch                 // "node-fetch"
    | VercelFetch               // "@vercel/fetch"
    | Utf8Validate              // "utf-8-validate"

    /// 获取模块的标准名称字符串
    /// 对应 Bun HardcodedModule 枚举值的序列化名
    public func canonicalName(): String {
        match (this) {
            // Bun 专有
            case Bun => "bun"
            case BunApp => "bun:app"
            case BunFfi => "bun:ffi"
            case BunJsc => "bun:jsc"
            case BunMain => "bun:main"
            case BunTest => "bun:test"
            case BunWrap => "bun:wrap"
            case BunSqlite => "bun:sqlite"
            case BunInternalForTesting => "bun:internal-for-testing"
            // Node.js 核心
            case NodeAssert => "node:assert"
            case NodeAssertStrict => "node:assert/strict"
            case NodeAsyncHooks => "node:async_hooks"
            case NodeBuffer => "node:buffer"
            case NodeChildProcess => "node:child_process"
            case NodeCluster => "node:cluster"
            case NodeConsole => "node:console"
            case NodeConstants => "node:constants"
            case NodeCrypto => "node:crypto"
            case NodeDgram => "node:dgram"
            case NodeDiagnosticsChannel => "node:diagnostics_channel"
            case NodeDns => "node:dns"
            case NodeDnsPromises => "node:dns/promises"
            case NodeDomain => "node:domain"
            case NodeEvents => "node:events"
            case NodeFs => "node:fs"
            case NodeFsPromises => "node:fs/promises"
            case NodeHttp => "node:http"
            case NodeHttp2 => "node:http2"
            case NodeHttps => "node:https"
            case NodeInspector => "node:inspector"
            case NodeInspectorPromises => "node:inspector/promises"
            case NodeModule => "node:module"
            case NodeNet => "node:net"
            case NodeOs => "node:os"
            case NodePath => "node:path"
            case NodePathPosix => "node:path/posix"
            case NodePathWin32 => "node:path/win32"
            case NodePerfHooks => "node:perf_hooks"
            case NodeProcess => "node:process"
            case NodePunycode => "node:punycode"
            case NodeQuerystring => "node:querystring"
            case NodeReadline => "node:readline"
            case NodeReadlinePromises => "node:readline/promises"
            case NodeRepl => "node:repl"
            case NodeStream => "node:stream"
            case NodeStreamConsumers => "node:stream/consumers"
            case NodeStreamPromises => "node:stream/promises"
            case NodeStreamWeb => "node:stream/web"
            case NodeStringDecoder => "node:string_decoder"
            case NodeTest => "node:test"
            case NodeTimers => "node:timers"
            case NodeTimersPromises => "node:timers/promises"
            case NodeTls => "node:tls"
            case NodeTraceEvents => "node:trace_events"
            case NodeTty => "node:tty"
            case NodeUrl => "node:url"
            case NodeUtil => "node:util"
            case NodeUtilTypes => "node:util/types"
            case NodeV8 => "node:v8"
            case NodeVm => "node:vm"
            case NodeWasi => "node:wasi"
            case NodeWorkerThreads => "node:worker_threads"
            case NodeZlib => "node:zlib"
            // Node.js 内部
            case NodeStreamDuplexInternal => "node:_stream_duplex"
            case NodeStreamPassthroughInternal => "node:_stream_passthrough"
            case NodeStreamReadableInternal => "node:_stream_readable"
            case NodeStreamTransformInternal => "node:_stream_transform"
            case NodeStreamWrapInternal => "node:_stream_wrap"
            case NodeStreamWritableInternal => "node:_stream_writable"
            case NodeTlsCommonInternal => "node:_tls_common"
            case NodeHttpAgentInternal => "node:_http_agent"
            case NodeHttpClientInternal => "node:_http_client"
            case NodeHttpCommonInternal => "node:_http_common"
            case NodeHttpIncomingInternal => "node:_http_incoming"
            case NodeHttpOutgoingInternal => "node:_http_outgoing"
            case NodeHttpServerInternal => "node:_http_server"
            // 第三方覆盖
            case AbortController => "abort-controller"
            case Undici => "undici"
            case Ws => "ws"
            case IsomorphicFetch => "isomorphic-fetch"
            case NodeFetch => "node-fetch"
            case VercelFetch => "@vercel/fetch"
            case Utf8Validate => "utf-8-validate"
        }
    }

    /// 获取分类 - 对应 Bun 中通过前缀隐式判断的分类
    public func category(): BuiltinCategory {
        match (this) {
            // Bun 专有模块
            case Bun | BunApp | BunFfi | BunJsc | BunMain |
                 BunTest | BunWrap | BunSqlite | BunInternalForTesting => BuiltinCategory.Bun
            // Node.js 内部模块 (下划线前缀)
            case NodeStreamDuplexInternal | NodeStreamPassthroughInternal |
                 NodeStreamReadableInternal | NodeStreamTransformInternal |
                 NodeStreamWrapInternal | NodeStreamWritableInternal |
                 NodeTlsCommonInternal |
                 NodeHttpAgentInternal | NodeHttpClientInternal |
                 NodeHttpCommonInternal | NodeHttpIncomingInternal |
                 NodeHttpOutgoingInternal | NodeHttpServerInternal => BuiltinCategory.Internal
            // 第三方覆盖
            case AbortController | Undici | Ws |
                 IsomorphicFetch | NodeFetch | VercelFetch | Utf8Validate => BuiltinCategory.ThirdParty
            // Node.js 核心模块
            case _ => BuiltinCategory.Node
        }
    }
}

// ============================================================================
// NodeBuiltinPatterns - Node.js 内建模块名称列表
// 严格翻译自: node_builtins.rs
//
// Bun 维护三个常量:
//   NODE_BUILTIN_PATTERNS_RAW: 57 个 Node.js 核心模块裸名
//     (不含 "node:" 前缀)
//   NODE_BUILTIN_PATTERNS: RAW + 每个加 "node:" 前缀版本 (114 个)
//   BUN_NODE_BUILTIN_PATTERNS_COMPAT: 52 个 Bun 兼容子集
//     (排除 buffer, fs, path, process, test 这 5 个)
//
// compat 和 node_only 的区别:
//   compat (52 个): 这些模块在 --target=bun 时可解析为外部依赖
//   node_only (5 个): buffer, fs, path, process, test
//     在 --target=bun 时 Bun 提供自己的实现，不标记为外部
// ============================================================================

/// Node.js 内建模块名称 - 对应 Bun NODE_BUILTIN_PATTERNS_RAW
/// 57 个 Node.js 核心模块的裸名 (不含 "node:" 前缀)
/// 每个名称在列表中只出现一次
public let NODE_BUILTIN_PATTERNS_RAW: Array<String> = [
    // ===== compat 组 (52 个): Bun 兼容子集 =====
    // 这些模块在 --target=bun 时可被标记为外部依赖
    "_http_agent",
    "_http_client",
    "_http_common",
    "_http_incoming",
    "_http_outgoing",
    "_http_server",
    "_stream_duplex",
    "_stream_passthrough",
    "_stream_readable",
    "_stream_transform",
    "_stream_wrap",
    "_stream_writable",
    "_tls_common",
    "_tls_wrap",
    "assert",
    "async_hooks",
    "child_process",
    "cluster",
    "console",
    "constants",
    "crypto",
    "dgram",
    "diagnostics_channel",
    "dns",
    "domain",
    "events",
    "http",
    "http2",
    "https",
    "inspector",
    "module",
    "net",
    "os",
    "perf_hooks",
    "punycode",
    "querystring",
    "readline",
    "repl",
    "stream",
    "string_decoder",
    "sys",
    "timers",
    "tls",
    "trace_events",
    "tty",
    "url",
    "util",
    "v8",
    "vm",
    "wasi",
    "worker_threads",
    "zlib",

    // ===== node_only 组 (5 个): Bun 提供自己的实现 =====
    // 这些在 --target=bun 时保持可解析，不标记为外部
    "buffer",
    "fs",
    "path",
    "process",
    "test",
]

/// Node.js 内建模块名称 (含 node: 前缀版本)
/// 对应 Bun NODE_BUILTIN_PATTERNS
/// 57 个裸名 + 57 个 "node:" 前缀版本 = 114 个
public let NODE_BUILTIN_PATTERNS: Array<String> = [
    // RAW 部分 (57 个裸名)
    "_http_agent",
    "_http_client",
    "_http_common",
    "_http_incoming",
    "_http_outgoing",
    "_http_server",
    "_stream_duplex",
    "_stream_passthrough",
    "_stream_readable",
    "_stream_transform",
    "_stream_wrap",
    "_stream_writable",
    "_tls_common",
    "_tls_wrap",
    "assert",
    "async_hooks",
    "child_process",
    "cluster",
    "console",
    "constants",
    "crypto",
    "dgram",
    "diagnostics_channel",
    "dns",
    "domain",
    "events",
    "http",
    "http2",
    "https",
    "inspector",
    "module",
    "net",
    "os",
    "perf_hooks",
    "punycode",
    "querystring",
    "readline",
    "repl",
    "stream",
    "string_decoder",
    "sys",
    "timers",
    "tls",
    "trace_events",
    "tty",
    "url",
    "util",
    "v8",
    "vm",
    "wasi",
    "worker_threads",
    "zlib",
    "buffer",
    "fs",
    "path",
    "process",
    "test",
    // "node:" 前缀版本 (57 个)
    "node:_http_agent",
    "node:_http_client",
    "node:_http_common",
    "node:_http_incoming",
    "node:_http_outgoing",
    "node:_http_server",
    "node:_stream_duplex",
    "node:_stream_passthrough",
    "node:_stream_readable",
    "node:_stream_transform",
    "node:_stream_wrap",
    "node:_stream_writable",
    "node:_tls_common",
    "node:_tls_wrap",
    "node:assert",
    "node:async_hooks",
    "node:child_process",
    "node:cluster",
    "node:console",
    "node:constants",
    "node:crypto",
    "node:dgram",
    "node:diagnostics_channel",
    "node:dns",
    "node:domain",
    "node:events",
    "node:http",
    "node:http2",
    "node:https",
    "node:inspector",
    "node:module",
    "node:net",
    "node:os",
    "node:perf_hooks",
    "node:punycode",
    "node:querystring",
    "node:readline",
    "node:repl",
    "node:stream",
    "node:string_decoder",
    "node:sys",
    "node:timers",
    "node:tls",
    "node:trace_events",
    "node:tty",
    "node:url",
    "node:util",
    "node:v8",
    "node:vm",
    "node:wasi",
    "node:worker_threads",
    "node:zlib",
    "node:buffer",
    "node:fs",
    "node:path",
    "node:process",
    "node:test",
]

/// Bun 兼容的 Node.js 内建模块子集
/// 对应 Bun BUN_NODE_BUILTIN_PATTERNS_COMPAT
/// 52 个模块 (排除 buffer, fs, path, process, test)
/// 这些模块在 --target=bun 时可被标记为外部依赖
public let BUN_NODE_BUILTIN_PATTERNS_COMPAT: Array<String> = [
    "_http_agent",
    "_http_client",
    "_http_common",
    "_http_incoming",
    "_http_outgoing",
    "_http_server",
    "_stream_duplex",
    "_stream_passthrough",
    "_stream_readable",
    "_stream_transform",
    "_stream_wrap",
    "_stream_writable",
    "_tls_common",
    "_tls_wrap",
    "assert",
    "async_hooks",
    "child_process",
    "cluster",
    "console",
    "constants",
    "crypto",
    "dgram",
    "diagnostics_channel",
    "dns",
    "domain",
    "events",
    "http",
    "http2",
    "https",
    "inspector",
    "module",
    "net",
    "os",
    "perf_hooks",
    "punycode",
    "querystring",
    "readline",
    "repl",
    "stream",
    "string_decoder",
    "sys",
    "timers",
    "tls",
    "trace_events",
    "tty",
    "url",
    "util",
    "v8",
    "vm",
    "wasi",
    "worker_threads",
    "zlib",
]

// ============================================================================
// ResolveBuiltins - 内建模块解析器
// 严格翻译自: HardcodedModule.zig 中 HardcodedModule.map + Alias 查找表
//
// Bun 使用 ComptimeStringMap (编译时完美哈希表) 进行 O(1) 查找:
//   pub const map = bun.ComptimeStringMap(HardcodedModule, [_]struct { []const u8, HardcodedModule }{ ... })
//
// Alias 查找表分为三组:
//   common_alias_kvs: Node.js 内建模块 (同时用于 --target=bun 和 --target=node)
//   bun_extra_alias_kvs: Bun 额外模块 (仅 --target=bun)
//   bun_test_extra_alias_kvs: 测试框架别名 (仅 --target=bun 且启用 jest 重写)
//
// 组合为三个查找表:
//   node_aliases = common
//   bun_aliases = common + bun_extra
//   bun_test_aliases = common + bun_extra + bun_test_extra
//
// 查找逻辑:
//   Alias.get(name, target, cfg) -> ?Alias
//     if target.isBun():
//       if cfg.rewrite_jest_for_tests: bun_test_aliases.get(name)
//       else: bun_aliases.get(name)
//     elif target.isNode():
//       node_aliases.get(name)
//     else: null
// ============================================================================

/// 内建模块解析器 - 对应 Bun HardcodedModule + Alias 查找系统
/// 提供内建模块判断、解析和分类功能
public class ResolveBuiltins {
    /// HardcodedModule 查找表 - 对应 Bun ComptimeStringMap
    /// 键为模块说明符字符串，值为 HardcodedModule 枚举
    /// Bun 在编译时生成完美哈希表，此处使用 HashMap
    private static var hardcodedMap: HashMap<String, HardcodedModule> = initHardcodedMap()

    /// Node.js 别名查找表 - 对应 Bun Alias.node_aliases
    /// 仅包含 common_alias_kvs
    private static var nodeAliasMap: HashMap<String, BuiltinAlias> = initNodeAliases()

    /// Bun 别名查找表 - 对应 Bun Alias.bun_aliases
    /// 包含 common + bun_extra
    private static var bunAliasMap: HashMap<String, BuiltinAlias> = initBunAliases()

    /// Bun 测试别名查找表 - 对应 Bun Alias.bun_test_aliases
    /// 包含 common + bun_extra + bun_test_extra
    private static var bunTestAliasMap: HashMap<String, BuiltinAlias> = initBunTestAliases()

    /// Node.js 内建模块快速查找集合 (裸名)
    /// 对应 Bun 中用于 isBuiltinModule 的判断
    private static var nodeBuiltinSet: HashSet<String> = initNodeBuiltinSet()

    /// "node:" 前缀长度常量
    private static let NODE_PREFIX: String = "node:"
    private static let NODE_PREFIX_LEN: Int64 = 5

    // ========================================================================
    // HardcodedModule 查找表初始化
    // 严格对应 Bun HardcodedModule.map
    // ========================================================================

    /// 初始化 HardcodedModule 查找表
    /// 对应 Bun: pub const map = bun.ComptimeStringMap(HardcodedModule, ...)
    private static func initHardcodedMap(): HashMap<String, HardcodedModule> {
        let m = HashMap<String, HardcodedModule>()

        // Bun 专有模块
        m.put("bun", HardcodedModule.Bun)
        m.put("bun:app", HardcodedModule.BunApp)
        m.put("bun:ffi", HardcodedModule.BunFfi)
        m.put("bun:jsc", HardcodedModule.BunJsc)
        m.put("bun:main", HardcodedModule.BunMain)
        m.put("bun:test", HardcodedModule.BunTest)
        m.put("bun:sqlite", HardcodedModule.BunSqlite)
        m.put("bun:wrap", HardcodedModule.BunWrap)
        m.put("bun:internal-for-testing", HardcodedModule.BunInternalForTesting)

        // Node.js 核心模块 (带 node: 前缀)
        m.put("node:assert", HardcodedModule.NodeAssert)
        m.put("node:assert/strict", HardcodedModule.NodeAssertStrict)
        m.put("node:async_hooks", HardcodedModule.NodeAsyncHooks)
        m.put("node:buffer", HardcodedModule.NodeBuffer)
        m.put("node:child_process", HardcodedModule.NodeChildProcess)
        m.put("node:cluster", HardcodedModule.NodeCluster)
        m.put("node:console", HardcodedModule.NodeConsole)
        m.put("node:constants", HardcodedModule.NodeConstants)
        m.put("node:crypto", HardcodedModule.NodeCrypto)
        m.put("node:dgram", HardcodedModule.NodeDgram)
        m.put("node:diagnostics_channel", HardcodedModule.NodeDiagnosticsChannel)
        m.put("node:dns", HardcodedModule.NodeDns)
        m.put("node:dns/promises", HardcodedModule.NodeDnsPromises)
        m.put("node:domain", HardcodedModule.NodeDomain)
        m.put("node:events", HardcodedModule.NodeEvents)
        m.put("node:fs", HardcodedModule.NodeFs)
        m.put("node:fs/promises", HardcodedModule.NodeFsPromises)
        m.put("node:http", HardcodedModule.NodeHttp)
        m.put("node:http2", HardcodedModule.NodeHttp2)
        m.put("node:https", HardcodedModule.NodeHttps)
        m.put("node:inspector", HardcodedModule.NodeInspector)
        m.put("node:inspector/promises", HardcodedModule.NodeInspectorPromises)
        m.put("node:module", HardcodedModule.NodeModule)
        m.put("node:net", HardcodedModule.NodeNet)
        m.put("node:os", HardcodedModule.NodeOs)
        m.put("node:path", HardcodedModule.NodePath)
        m.put("node:path/posix", HardcodedModule.NodePathPosix)
        m.put("node:path/win32", HardcodedModule.NodePathWin32)
        m.put("node:perf_hooks", HardcodedModule.NodePerfHooks)
        m.put("node:process", HardcodedModule.NodeProcess)
        m.put("node:punycode", HardcodedModule.NodePunycode)
        m.put("node:querystring", HardcodedModule.NodeQuerystring)
        m.put("node:readline", HardcodedModule.NodeReadline)
        m.put("node:readline/promises", HardcodedModule.NodeReadlinePromises)
        m.put("node:repl", HardcodedModule.NodeRepl)
        m.put("node:stream", HardcodedModule.NodeStream)
        m.put("node:stream/consumers", HardcodedModule.NodeStreamConsumers)
        m.put("node:stream/promises", HardcodedModule.NodeStreamPromises)
        m.put("node:stream/web", HardcodedModule.NodeStreamWeb)
        m.put("node:string_decoder", HardcodedModule.NodeStringDecoder)
        m.put("node:test", HardcodedModule.NodeTest)
        m.put("node:timers", HardcodedModule.NodeTimers)
        m.put("node:timers/promises", HardcodedModule.NodeTimersPromises)
        m.put("node:tls", HardcodedModule.NodeTls)
        m.put("node:trace_events", HardcodedModule.NodeTraceEvents)
        m.put("node:tty", HardcodedModule.NodeTty)
        m.put("node:url", HardcodedModule.NodeUrl)
        m.put("node:util", HardcodedModule.NodeUtil)
        m.put("node:util/types", HardcodedModule.NodeUtilTypes)
        m.put("node:v8", HardcodedModule.NodeV8)
        m.put("node:vm", HardcodedModule.NodeVm)
        m.put("node:wasi", HardcodedModule.NodeWasi)
        m.put("node:worker_threads", HardcodedModule.NodeWorkerThreads)
        m.put("node:zlib", HardcodedModule.NodeZlib)

        // Node.js 内部模块
        m.put("node:_stream_duplex", HardcodedModule.NodeStreamDuplexInternal)
        m.put("node:_stream_passthrough", HardcodedModule.NodeStreamPassthroughInternal)
        m.put("node:_stream_readable", HardcodedModule.NodeStreamReadableInternal)
        m.put("node:_stream_transform", HardcodedModule.NodeStreamTransformInternal)
        m.put("node:_stream_wrap", HardcodedModule.NodeStreamWrapInternal)
        m.put("node:_stream_writable", HardcodedModule.NodeStreamWritableInternal)
        m.put("node:_tls_common", HardcodedModule.NodeTlsCommonInternal)
        m.put("node:_http_agent", HardcodedModule.NodeHttpAgentInternal)
        m.put("node:_http_client", HardcodedModule.NodeHttpClientInternal)
        m.put("node:_http_common", HardcodedModule.NodeHttpCommonInternal)
        m.put("node:_http_incoming", HardcodedModule.NodeHttpIncomingInternal)
        m.put("node:_http_outgoing", HardcodedModule.NodeHttpOutgoingInternal)
        m.put("node:_http_server", HardcodedModule.NodeHttpServerInternal)

        // 第三方覆盖包
        m.put("node-fetch", HardcodedModule.NodeFetch)
        m.put("isomorphic-fetch", HardcodedModule.IsomorphicFetch)
        m.put("undici", HardcodedModule.Undici)
        m.put("ws", HardcodedModule.Ws)
        m.put("@vercel/fetch", HardcodedModule.VercelFetch)
        m.put("utf-8-validate", HardcodedModule.Utf8Validate)
        m.put("abort-controller", HardcodedModule.AbortController)

        return m
    }

    // ========================================================================
    // Alias 查找表初始化
    // 严格对应 Bun HardcodedModule.Alias 中各别名表
    //
    // Bun 使用 comptime concat (++) 组合别名表:
    //   node_aliases = ComptimeStringMap(Alias, common_alias_kvs)
    //   bun_aliases = ComptimeStringMap(Alias, common_alias_kvs ++ bun_extra_alias_kvs)
    //   bun_test_aliases = ComptimeStringMap(Alias, common ++ bun_extra ++ bun_test_extra)
    // ========================================================================

    /// 创建 Node.js 内建模块条目 - 对应 Bun Alias.nodeEntry()
    /// 自动确保路径以 "node:" 前缀开头
    private static func nodeEntry(path: String): Tuple2<String, BuiltinAlias> {
        let resolvedPath = ensureNodePrefix(path)
        return Tuple2(
            path,
            BuiltinAlias(
                path: resolvedPath,
                tag: ImportTag.Builtin,
                nodeBuiltin: true,
                nodeOnlyPrefix: false
            )
        )
    }

    /// 创建仅 node: 前缀的条目 - 对应 Bun Alias.nodeEntryOnlyPrefix()
    /// 某些模块只能通过 "node:" 前缀解析 (如 node:test)
    private static func nodeEntryOnlyPrefix(path: String): Tuple2<String, BuiltinAlias> {
        let resolvedPath = ensureNodePrefix(path)
        return Tuple2(
            path,
            BuiltinAlias(
                path: resolvedPath,
                tag: ImportTag.Builtin,
                nodeBuiltin: true,
                nodeOnlyPrefix: true
            )
        )
    }

    /// 创建普通条目 - 对应 Bun Alias.entry()
    private static func entry(path: String): Tuple2<String, BuiltinAlias> {
        return Tuple2(
            path,
            BuiltinAlias(
                path: path,
                tag: ImportTag.Builtin,
                nodeBuiltin: false,
                nodeOnlyPrefix: false
            )
        )
    }

    /// 确保 "node:" 前缀 - 对应 Bun ensure_node_prefix! 宏
    /// Zig: if (path.len > 5 and std.mem.eql(u8, path[0..5], "node:")) path else "node:" ++ path
    private static func ensureNodePrefix(path: String): String {
        if (path.length > NODE_PREFIX_LEN && path.substring(Int64(0), NODE_PREFIX_LEN) == NODE_PREFIX) {
            return path
        }
        return NODE_PREFIX + path
    }

    // ========================================================================
    // common_alias_kvs - 公共别名表
    // 严格对应 Bun HardcodedModule.Alias.common_alias_kvs
    // 同时应用于 --target=bun 和 --target=node
    //
    // 包含:
    //   1. node: 前缀的 Node.js 模块 (如 "node:fs", "node:http")
    //   2. 裸名 Node.js 模块 (如 "fs", "http") - 自动加上 node: 前缀
    //   3. 内部模块别名 (如 "_http_agent")
    //   4. 特殊别名 (如 "sys" -> "node:util")
    // ========================================================================

    /// 填充公共别名条目
    /// 对应 Bun common_alias_kvs 数组中的所有条目
    private static func fillCommonAliases(m: HashMap<String, BuiltinAlias>): Unit {
        // ===== node: 前缀形式 =====
        fillNodeEntry(m, "node:assert")
        fillNodeEntry(m, "node:assert/strict")
        fillNodeEntry(m, "node:async_hooks")
        fillNodeEntry(m, "node:buffer")
        fillNodeEntry(m, "node:child_process")
        fillNodeEntry(m, "node:cluster")
        fillNodeEntry(m, "node:console")
        fillNodeEntry(m, "node:constants")
        fillNodeEntry(m, "node:crypto")
        fillNodeEntry(m, "node:dgram")
        fillNodeEntry(m, "node:diagnostics_channel")
        fillNodeEntry(m, "node:dns")
        fillNodeEntry(m, "node:dns/promises")
        fillNodeEntry(m, "node:domain")
        fillNodeEntry(m, "node:events")
        fillNodeEntry(m, "node:fs")
        fillNodeEntry(m, "node:fs/promises")
        fillNodeEntry(m, "node:http")
        fillNodeEntry(m, "node:http2")
        fillNodeEntry(m, "node:https")
        fillNodeEntry(m, "node:inspector")
        fillNodeEntry(m, "node:inspector/promises")
        fillNodeEntry(m, "node:module")
        fillNodeEntry(m, "node:net")
        fillNodeEntry(m, "node:os")
        fillNodeEntry(m, "node:path")
        fillNodeEntry(m, "node:path/posix")
        fillNodeEntry(m, "node:path/win32")
        fillNodeEntry(m, "node:perf_hooks")
        fillNodeEntry(m, "node:process")
        fillNodeEntry(m, "node:punycode")
        fillNodeEntry(m, "node:querystring")
        fillNodeEntry(m, "node:readline")
        fillNodeEntry(m, "node:readline/promises")
        fillNodeEntry(m, "node:repl")
        fillNodeEntry(m, "node:stream")
        fillNodeEntry(m, "node:stream/consumers")
        fillNodeEntry(m, "node:stream/promises")
        fillNodeEntry(m, "node:stream/web")
        fillNodeEntry(m, "node:string_decoder")
        fillNodeEntry(m, "node:timers")
        fillNodeEntry(m, "node:timers/promises")
        fillNodeEntry(m, "node:tls")
        fillNodeEntry(m, "node:trace_events")
        fillNodeEntry(m, "node:tty")
        fillNodeEntry(m, "node:url")
        fillNodeEntry(m, "node:util")
        fillNodeEntry(m, "node:util/types")
        fillNodeEntry(m, "node:v8")
        fillNodeEntry(m, "node:vm")
        fillNodeEntry(m, "node:wasi")
        fillNodeEntry(m, "node:worker_threads")
        fillNodeEntry(m, "node:zlib")

        // node:test 仅支持 node: 前缀 - 对应 Bun nodeEntryOnlyPrefix
        let testEntry = nodeEntryOnlyPrefix("node:test")
        m.put(testEntry.first, testEntry.second)

        // ===== 裸名形式 (自动加上 node: 前缀) =====
        fillNodeEntry(m, "assert")
        fillNodeEntry(m, "assert/strict")
        fillNodeEntry(m, "async_hooks")
        fillNodeEntry(m, "buffer")
        fillNodeEntry(m, "child_process")
        fillNodeEntry(m, "cluster")
        fillNodeEntry(m, "console")
        fillNodeEntry(m, "constants")
        fillNodeEntry(m, "crypto")
        fillNodeEntry(m, "dgram")
        fillNodeEntry(m, "diagnostics_channel")
        fillNodeEntry(m, "dns")
        fillNodeEntry(m, "dns/promises")
        fillNodeEntry(m, "domain")
        fillNodeEntry(m, "events")
        fillNodeEntry(m, "fs")
        fillNodeEntry(m, "fs/promises")
        fillNodeEntry(m, "http")
        fillNodeEntry(m, "http2")
        fillNodeEntry(m, "https")
        fillNodeEntry(m, "inspector")
        fillNodeEntry(m, "inspector/promises")
        fillNodeEntry(m, "module")
        fillNodeEntry(m, "net")
        fillNodeEntry(m, "os")
        fillNodeEntry(m, "path")
        fillNodeEntry(m, "path/posix")
        fillNodeEntry(m, "path/win32")
        fillNodeEntry(m, "perf_hooks")
        fillNodeEntry(m, "process")
        fillNodeEntry(m, "punycode")
        fillNodeEntry(m, "querystring")
        fillNodeEntry(m, "readline")
        fillNodeEntry(m, "readline/promises")
        fillNodeEntry(m, "repl")
        fillNodeEntry(m, "stream")
        fillNodeEntry(m, "stream/consumers")
        fillNodeEntry(m, "stream/promises")
        fillNodeEntry(m, "stream/web")
        fillNodeEntry(m, "string_decoder")
        fillNodeEntry(m, "timers")
        fillNodeEntry(m, "timers/promises")
        fillNodeEntry(m, "tls")
        fillNodeEntry(m, "trace_events")
        fillNodeEntry(m, "tty")
        fillNodeEntry(m, "url")
        fillNodeEntry(m, "util")
        fillNodeEntry(m, "util/types")
        fillNodeEntry(m, "v8")
        fillNodeEntry(m, "vm")
        fillNodeEntry(m, "wasi")
        fillNodeEntry(m, "worker_threads")
        fillNodeEntry(m, "zlib")

        // ===== node: 前缀内部模块 =====
        fillNodeEntry(m, "node:_http_agent")
        fillNodeEntry(m, "node:_http_client")
        fillNodeEntry(m, "node:_http_common")
        fillNodeEntry(m, "node:_http_incoming")
        fillNodeEntry(m, "node:_http_outgoing")
        fillNodeEntry(m, "node:_http_server")

        // ===== 裸名内部模块 =====
        fillNodeEntry(m, "_http_agent")
        fillNodeEntry(m, "_http_client")
        fillNodeEntry(m, "_http_common")
        fillNodeEntry(m, "_http_incoming")
        fillNodeEntry(m, "_http_outgoing")
        fillNodeEntry(m, "_http_server")

        // ===== 特殊别名 =====

        // sys 是 util 的已弃用别名
        // Bun: .{ "sys", .{ .path = "node:util", .node_builtin = true } }
        m.put("sys", BuiltinAlias(
            path: "node:util",
            tag: ImportTag.Builtin,
            nodeBuiltin: true,
            nodeOnlyPrefix: false
        ))
        m.put("node:sys", BuiltinAlias(
            path: "node:util",
            tag: ImportTag.Builtin,
            nodeBuiltin: true,
            nodeOnlyPrefix: false
        ))

        // 以下模块在 builtinModules 中返回，但使用量不大，作为别名处理
        // Bun: "These are returned in builtinModules, but probably not many
        //       packages use them so we will just alias them."
        fillNodeEntry(m, "node:_stream_duplex")
        fillNodeEntry(m, "node:_stream_passthrough")
        fillNodeEntry(m, "node:_stream_readable")
        fillNodeEntry(m, "node:_stream_transform")
        fillNodeEntry(m, "node:_stream_wrap")
        fillNodeEntry(m, "node:_stream_writable")
        fillNodeEntry(m, "node:_tls_common")

        // _tls_wrap 映射到 node:tls
        m.put("node:_tls_wrap", BuiltinAlias(
            path: "node:tls",
            tag: ImportTag.Builtin,
            nodeBuiltin: true,
            nodeOnlyPrefix: false
        ))

        fillNodeEntry(m, "_stream_duplex")
        fillNodeEntry(m, "_stream_passthrough")
        fillNodeEntry(m, "_stream_readable")
        fillNodeEntry(m, "_stream_transform")
        fillNodeEntry(m, "_stream_wrap")
        fillNodeEntry(m, "_stream_writable")
        fillNodeEntry(m, "_tls_common")

        // _tls_wrap 映射到 node:tls (裸名版本)
        m.put("_tls_wrap", BuiltinAlias(
            path: "node:tls",
            tag: ImportTag.Builtin,
            nodeBuiltin: true,
            nodeOnlyPrefix: false
        ))
    }

    /// 填充单个 nodeEntry 到映射表
    private static func fillNodeEntry(m: HashMap<String, BuiltinAlias>, path: String): Unit {
        let e = nodeEntry(path)
        m.put(e.first, e.second)
    }

    // ========================================================================
    // bun_extra_alias_kvs - Bun 额外别名
    // 严格对应 Bun HardcodedModule.Alias.bun_extra_alias_kvs
    // 仅在 --target=bun 时使用
    //
    // 包含:
    //   1. Bun 专有模块 (bun, bun:test, bun:sqlite 等)
    //   2. 第三方包覆盖 (undici, ws, node-fetch 等)
    //   3. 强制原生化的 polyfill (abort-controller)
    //   4. Next.js 编译依赖覆盖
    // ========================================================================

    /// 填充 Bun 额外别名
    private static func fillBunExtraAliases(m: HashMap<String, BuiltinAlias>): Unit {
        // ===== Bun 专有模块 =====
        // "bun" 本身使用 ImportTag.Bun 标签 - 对应 Bun .{ .tag = .bun }
        m.put("bun", BuiltinAlias(
            path: "bun",
            tag: ImportTag.Bun,
            nodeBuiltin: false,
            nodeOnlyPrefix: false
        ))

        fillEntry(m, "bun:test")
        fillEntry(m, "bun:app")
        fillEntry(m, "bun:ffi")
        fillEntry(m, "bun:jsc")
        fillEntry(m, "bun:main")
        fillEntry(m, "bun:sqlite")
        fillEntry(m, "bun:wrap")
        fillEntry(m, "bun:internal-for-testing")

        // ffi 别名 -> bun:ffi
        // Bun: .{ "ffi", .{ .path = "bun:ffi" } }
        m.put("ffi", BuiltinAlias(
            path: "bun:ffi",
            tag: ImportTag.Builtin,
            nodeBuiltin: false,
            nodeOnlyPrefix: false
        ))

        // ===== 第三方覆盖包 =====
        fillEntry(m, "@vercel/fetch")
        fillEntry(m, "isomorphic-fetch")
        fillEntry(m, "node-fetch")
        fillEntry(m, "undici")
        fillEntry(m, "utf-8-validate")
        fillEntry(m, "ws")

        // ws/lib/websocket -> ws
        // Bun: .{ "ws/lib/websocket", .{ .path = "ws" } }
        m.put("ws/lib/websocket", BuiltinAlias(
            path: "ws",
            tag: ImportTag.Builtin,
            nodeBuiltin: false,
            nodeOnlyPrefix: false
        ))

        // ===== 强制原生化的 polyfill =====
        fillEntry(m, "abort-controller")

        // abort-controller/polyfill -> abort-controller
        m.put("abort-controller/polyfill", BuiltinAlias(
            path: "abort-controller",
            tag: ImportTag.Builtin,
            nodeBuiltin: false,
            nodeOnlyPrefix: false
        ))

        // ===== Next.js 编译依赖覆盖 =====
        // 强制 Next.js 不使用其打包的依赖
        m.put("next/dist/compiled/ws", BuiltinAlias(
            path: "ws",
            tag: ImportTag.Builtin,
            nodeBuiltin: false,
            nodeOnlyPrefix: false
        ))
        m.put("next/dist/compiled/node-fetch", BuiltinAlias(
            path: "node-fetch",
            tag: ImportTag.Builtin,
            nodeBuiltin: false,
            nodeOnlyPrefix: false
        ))
        m.put("next/dist/compiled/undici", BuiltinAlias(
            path: "undici",
            tag: ImportTag.Builtin,
            nodeBuiltin: false,
            nodeOnlyPrefix: false
        ))
    }

    // ========================================================================
    // bun_test_extra_alias_kvs - 测试框架额外别名
    // 严格对应 Bun HardcodedModule.Alias.bun_test_extra_alias_kvs
    // 仅在 --target=bun 且启用 jest 重写时使用
    //
    // 将 Jest/Vitest 全局变量重写为 bun:test
    // ========================================================================

    /// 填充测试框架别名
    private static func fillBunTestExtraAliases(m: HashMap<String, BuiltinAlias>): Unit {
        // @jest/globals -> bun:test
        m.put("@jest/globals", BuiltinAlias(
            path: "bun:test",
            tag: ImportTag.Builtin,
            nodeBuiltin: false,
            nodeOnlyPrefix: false
        ))
        // vitest -> bun:test
        m.put("vitest", BuiltinAlias(
            path: "bun:test",
            tag: ImportTag.Builtin,
            nodeBuiltin: false,
            nodeOnlyPrefix: false
        ))
    }

    /// 填充普通条目
    private static func fillEntry(m: HashMap<String, BuiltinAlias>, path: String): Unit {
        let e = entry(path)
        m.put(e.first, e.second)
    }

    // ========================================================================
    // 查找表初始化函数
    // ========================================================================

    /// 初始化 Node.js 别名表 - 对应 Bun node_aliases
    private static func initNodeAliases(): HashMap<String, BuiltinAlias> {
        let m = HashMap<String, BuiltinAlias>()
        fillCommonAliases(m)
        return m
    }

    /// 初始化 Bun 别名表 - 对应 Bun bun_aliases
    /// = common + bun_extra
    private static func initBunAliases(): HashMap<String, BuiltinAlias> {
        let m = HashMap<String, BuiltinAlias>()
        fillCommonAliases(m)
        fillBunExtraAliases(m)
        return m
    }

    /// 初始化 Bun 测试别名表 - 对应 Bun bun_test_aliases
    /// = common + bun_extra + bun_test_extra
    private static func initBunTestAliases(): HashMap<String, BuiltinAlias> {
        let m = HashMap<String, BuiltinAlias>()
        fillCommonAliases(m)
        fillBunExtraAliases(m)
        fillBunTestExtraAliases(m)
        return m
    }

    /// 初始化 Node.js 内建模块快速查找集合
    private static func initNodeBuiltinSet(): HashSet<String> {
        let s = HashSet<String>()
        for (name in NODE_BUILTIN_PATTERNS) {
            s.insert(name)
        }
        return s
    }

    // ========================================================================
    // 公共 API - 对应 Bun 中 HardcodedModule/Alias 的公开接口
    // ========================================================================

    /// 判断模块名是否为内建模块
    /// 对应 Bun: isBuiltinModule() / Alias.has()
    /// 检查给定名称是否为 Node.js 内建模块或 Bun 内建模块
    ///
    /// 参数:
    ///   name: 模块说明符 (如 "fs", "node:path", "bun:sqlite")
    /// 返回: 是否为已知的内建模块
    public static func isBuiltin(name: String): Bool {
        // 先检查 HardcodedModule 映射 (包含所有已知的内建和覆盖模块)
        if (hardcodedMap.get(name) != None) {
            return true
        }
        // 再检查 Node.js 内建模块集合
        return nodeBuiltinSet.contains(name)
    }

    /// 判断模块名是否为 Node.js 内建模块
    /// 对应 Bun 中通过 Alias.node_builtin 判断
    ///
    /// 参数:
    ///   name: 模块说明符
    /// 返回: 是否为 Node.js 内建模块
    public static func isNodeBuiltin(name: String): Bool {
        return nodeBuiltinSet.contains(name)
    }

    /// 判断模块名是否为 Bun 专有内建模块
    /// 对应 Bun 中通过 "bun:" 前缀判断
    ///
    /// 参数:
    ///   name: 模块说明符
    /// 返回: 是否为 Bun 专有模块
    public static func isBunBuiltin(name: String): Bool {
        return name.startsWith("bun:")
    }

    /// 判断模块名是否为 Node.js 内部模块 (下划线前缀)
    /// 对应 Bun 中以 "_" 开头的 Node.js 模块
    ///
    /// 参数:
    ///   name: 模块说明符
    /// 返回: 是否为内部模块
    public static func isInternalModule(name: String): Bool {
        let bare = stripNodePrefix(name)
        return bare.length > 0 && bare[0] == Char('_')
    }

    /// 获取内建模块分类
    /// 对应 Bun 中通过 Alias.tag 和前缀隐式判断的分类
    ///
    /// 参数:
    ///   name: 模块说明符
    /// 返回: 分类枚举，如果非内建模块返回 None
    public static func getCategory(name: String): ?BuiltinCategory {
        // Bun 专有模块
        if (name.startsWith("bun:") || name == "bun") {
            return Some(BuiltinCategory.Bun)
        }

        // Node.js 内部模块 (下划线前缀)
        let bare = stripNodePrefix(name)
        if (bare.length > 0 && bare[0] == Char('_')) {
            return Some(BuiltinCategory.Internal)
        }

        // Node.js 内建模块
        if (isNodeBuiltin(name)) {
            return Some(BuiltinCategory.Node)
        }

        // 第三方覆盖包
        match (hardcodedMap.get(name)) {
            case Some(mod) => return Some(mod.category())
            case None => {}
        }

        return None
    }

    /// 解析内建模块
    /// 对应 Bun: Alias.get(name, target, cfg) -> ?Alias
    /// 根据目标平台查找模块的别名信息
    ///
    /// 参数:
    ///   name: 模块说明符
    ///   target: 目标平台 ("bun", "node", "browser")
    ///   rewriteJestForTests: 是否将 Jest/Vitest 重写为 bun:test
    /// 返回: 别名信息，如果未找到返回 None
    public static func resolveBuiltin(name: String, target: String,
                                       rewriteJestForTests: Bool): ?BuiltinAlias {
        if (target == "bun") {
            if (rewriteJestForTests) {
                return bunTestAliasMap.get(name)
            } else {
                return bunAliasMap.get(name)
            }
        } else if (target == "node") {
            return nodeAliasMap.get(name)
        }
        return None
    }

    /// 简化版解析 (默认 Bun 目标，不重写 Jest)
    public static func resolveBuiltin(name: String): ?BuiltinAlias {
        return bunAliasMap.get(name)
    }

    /// 判断别名表中是否包含指定模块
    /// 对应 Bun: Alias.has(name, target, cfg) -> bool
    public static func hasAlias(name: String, target: String,
                                 rewriteJestForTests: Bool): Bool {
        return resolveBuiltin(name, target, rewriteJestForTests) != None
    }

    /// 查找 HardcodedModule 枚举值
    /// 对应 Bun: HardcodedModule.map.get(name) -> ?HardcodedModule
    public static func lookupHardcodedModule(name: String): ?HardcodedModule {
        return hardcodedMap.get(name)
    }

    // ========================================================================
    // node: 前缀处理
    // 严格对应 Bun 中的 node: 前缀处理逻辑
    //
    // Bun:
    //   std.mem.eql(u8, path[0..5], "node:") 用于检测前缀
    //   "node:" ++ path 用于添加前缀
    //   path[5..] 用于剥离前缀
    // ========================================================================

    /// 剥离 "node:" 前缀
    /// 对应 Bun 中的 node: 前缀剥离逻辑
    /// "node:fs" -> "fs"
    /// "fs" -> "fs" (无变化)
    ///
    /// 参数:
    ///   name: 模块名称
    /// 返回: 剥离前缀后的裸名
    public static func stripNodePrefix(name: String): String {
        if (name.length > NODE_PREFIX_LEN &&
            name.substring(Int64(0), NODE_PREFIX_LEN) == NODE_PREFIX) {
            return name.substring(NODE_PREFIX_LEN, Int64(name.length))
        }
        return name
    }

    /// 添加 "node:" 前缀 (如果尚未存在)
    /// 对应 Bun ensure_node_prefix!
    ///
    /// 参数:
    ///   name: 模块名称
    /// 返回: 带 node: 前缀的名称
    public static func ensurePrefix(name: String): String {
        return ensureNodePrefix(name)
    }

    /// 检查是否有 "node:" 前缀
    public static func hasNodePrefix(name: String): Bool {
        return name.length > NODE_PREFIX_LEN &&
               name.substring(Int64(0), NODE_PREFIX_LEN) == NODE_PREFIX
    }

    // ========================================================================
    // 兼容性检查
    // 严格对应 Bun 中 --target=bun 时的兼容性判断
    //
    // Bun 兼容子集 (BUN_NODE_BUILTIN_PATTERNS_COMPAT):
    //   52 个模块，排除了 buffer, fs, path, process, test
    //   这些排除的模块 Bun 有自己的实现，不标记为外部
    // ========================================================================

    /// 判断模块是否在 Bun 兼容子集中
    /// 对应 Bun BUN_NODE_BUILTIN_PATTERNS_COMPAT 检查
    /// 在 --target=bun 时，这些模块可被标记为外部依赖
    ///
    /// 参数:
    ///   name: Node.js 模块裸名 (不含 node: 前缀)
    /// 返回: 是否在兼容子集中
    public static func isBunCompatNodeBuiltin(name: String): Bool {
        for (n in BUN_NODE_BUILTIN_PATTERNS_COMPAT) {
            if (n == name) {
                return true
            }
        }
        return false
    }

    /// 判断 Node.js 模块是否为 Bun 排除的 (由 Bun 提供实现)
    /// Bun 排除列表: buffer, fs, path, process, test
    ///
    /// 参数:
    ///   name: Node.js 模块裸名
    /// 返回: 是否被 Bun 排除
    public static func isBunExcludedNodeBuiltin(name: String): Bool {
        return name == "buffer" || name == "fs" || name == "path" ||
               name == "process" || name == "test"
    }
}
