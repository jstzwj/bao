// HardcodedModule enum, Alias struct, and lookup maps
// Strictly translated from:
//   bun/src/resolve_builtins/HardcodedModule.rs  (Rust port)
//   bun/src/resolve_builtins/HardcodedModule.zig  (Zig original)
//
// This file is the core of the resolve_builtins module. It defines:
//
//   1. HardcodedModule  - enum of all known built-in / override modules
//         Zig: pub const HardcodedModule = enum { bun, @"bun:app", ... }
//         Rust: pub enum HardcodedModule { Bun, AbortController, ... }
//
//   2. HardcodedModule.MAP  - static string-to-enum lookup
//         Zig: pub const map = bun.ComptimeStringMap(HardcodedModule, ...)
//         Rust: pub const MAP: phf::Map<&'static [u8], HardcodedModule> = phf::phf_map! { ... }
//
//   3. Alias struct  - describes how a module specifier resolves
//         Zig/Rust: pub struct Alias { path, tag, node_builtin, node_only_prefix }
//
//   4. Alias lookup tables (common / bun_extra / bun_test_extra)
//         Zig:  comptime concat of const arrays into ComptimeStringMap
//         Rust: const slices + linear scan (Phase B: phf_codegen)
//
//   5. Cfg struct + Alias.get() / Alias.has()  - public API
package bao_resolve_builtins

import bao_core.*
import bao_collections.*
import bao_options.ImportTag

// ============================================================================
// HardcodedModule - enum of all known built-in/override modules
// Strictly translated from:
//   HardcodedModule.zig:  pub const HardcodedModule = enum { bun, @"bun:app", ... }
//   HardcodedModule.rs:   pub enum HardcodedModule { Bun, AbortController, ... }
//
// Each variant maps to a canonical module specifier string.
// Bun uses ComptimeStringMap for O(1) lookup; Cangjie uses HashMap.
// ============================================================================

/// HardcodedModule - represents a known built-in or third-party-override module.
/// The module loader first uses Alias to resolve a specifier, then maps the
/// resolved string to this enum via the MAP lookup table.
/// Do NOT include aliases here; those go in the Alias tables.
public enum HardcodedModule {
    // ===== Bun-specific modules =====
    | Bun                       // "bun"
    | AbortController           // "abort-controller"
    | BunApp                    // "bun:app"
    | BunFfi                    // "bun:ffi"
    | BunJsc                    // "bun:jsc"
    | BunMain                   // "bun:main"
    | BunTest                   // "bun:test"
    | BunWrap                   // "bun:wrap"
    | BunSqlite                 // "bun:sqlite"

    // ===== Node.js core modules (node: prefix) =====
    | NodeAssert                // "node:assert"
    | NodeAssertStrict          // "node:assert/strict"
    | NodeAsyncHooks            // "node:async_hooks"
    | NodeBuffer                // "node:buffer"
    | NodeChildProcess          // "node:child_process"
    | NodeConsole               // "node:console"
    | NodeConstants             // "node:constants"
    | NodeCrypto                // "node:crypto"
    | NodeDns                   // "node:dns"
    | NodeDnsPromises           // "node:dns/promises"
    | NodeDomain                // "node:domain"
    | NodeEvents                // "node:events"
    | NodeFs                    // "node:fs"
    | NodeFsPromises            // "node:fs/promises"
    | NodeHttp                  // "node:http"
    | NodeHttps                 // "node:https"
    | NodeModule                // "node:module"
    | NodeNet                   // "node:net"
    | NodeOs                    // "node:os"
    | NodePath                  // "node:path"
    | NodePathPosix             // "node:path/posix"
    | NodePathWin32             // "node:path/win32"
    | NodePerfHooks             // "node:perf_hooks"
    | NodeProcess               // "node:process"
    | NodeQuerystring           // "node:querystring"
    | NodeReadline              // "node:readline"
    | NodeReadlinePromises      // "node:readline/promises"
    | NodeStream                // "node:stream"
    | NodeStreamConsumers       // "node:stream/consumers"
    | NodeStreamPromises        // "node:stream/promises"
    | NodeStreamWeb             // "node:stream/web"
    | NodeStringDecoder         // "node:string_decoder"
    | NodeTest                  // "node:test"
    | NodeTimers                // "node:timers"
    | NodeTimersPromises        // "node:timers/promises"
    | NodeTls                   // "node:tls"
    | NodeTty                   // "node:tty"
    | NodeUrl                   // "node:url"
    | NodeUtil                  // "node:util"
    | NodeUtilTypes             // "node:util/types"
    | NodeVm                    // "node:vm"
    | NodeWasi                  // "node:wasi"
    | NodeZlib                  // "node:zlib"
    | NodeWorkerThreads         // "node:worker_threads"
    | NodePunycode              // "node:punycode"

    // ===== Third-party override packages =====
    | Undici                    // "undici"
    | Ws                        // "ws"
    | IsomorphicFetch           // "isomorphic-fetch"
    | NodeFetch                 // "node-fetch"
    | VercelFetch               // "@vercel/fetch"
    | Utf8Validate              // "utf-8-validate"

    // ===== Additional Node.js core modules =====
    | NodeV8                    // "node:v8"
    | NodeTraceEvents           // "node:trace_events"
    | NodeRepl                  // "node:repl"
    | NodeInspector             // "node:inspector"
    | NodeInspectorPromises     // "node:inspector/promises"
    | NodeHttp2                 // "node:http2"
    | NodeDiagnosticsChannel    // "node:diagnostics_channel"
    | NodeDgram                 // "node:dgram"
    | NodeCluster               // "node:cluster"

    // ===== Node.js internal modules (underscore-prefixed) =====
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

    // ===== Bun internal (gated behind --expose-internals) =====
    | BunInternalForTesting     // "bun:internal-for-testing"

    /// Returns the canonical module specifier string for this variant.
    /// Corresponds to the Zig enum literal names and Rust #[strum(serialize)] values.
    public func canonicalName(): String {
        match (this) {
            // Bun-specific
            case Bun => "bun"
            case AbortController => "abort-controller"
            case BunApp => "bun:app"
            case BunFfi => "bun:ffi"
            case BunJsc => "bun:jsc"
            case BunMain => "bun:main"
            case BunTest => "bun:test"
            case BunWrap => "bun:wrap"
            case BunSqlite => "bun:sqlite"
            case BunInternalForTesting => "bun:internal-for-testing"
            // Node.js core
            case NodeAssert => "node:assert"
            case NodeAssertStrict => "node:assert/strict"
            case NodeAsyncHooks => "node:async_hooks"
            case NodeBuffer => "node:buffer"
            case NodeChildProcess => "node:child_process"
            case NodeConsole => "node:console"
            case NodeConstants => "node:constants"
            case NodeCrypto => "node:crypto"
            case NodeDns => "node:dns"
            case NodeDnsPromises => "node:dns/promises"
            case NodeDomain => "node:domain"
            case NodeEvents => "node:events"
            case NodeFs => "node:fs"
            case NodeFsPromises => "node:fs/promises"
            case NodeHttp => "node:http"
            case NodeHttps => "node:https"
            case NodeModule => "node:module"
            case NodeNet => "node:net"
            case NodeOs => "node:os"
            case NodePath => "node:path"
            case NodePathPosix => "node:path/posix"
            case NodePathWin32 => "node:path/win32"
            case NodePerfHooks => "node:perf_hooks"
            case NodeProcess => "node:process"
            case NodeQuerystring => "node:querystring"
            case NodeReadline => "node:readline"
            case NodeReadlinePromises => "node:readline/promises"
            case NodeStream => "node:stream"
            case NodeStreamConsumers => "node:stream/consumers"
            case NodeStreamPromises => "node:stream/promises"
            case NodeStreamWeb => "node:stream/web"
            case NodeStringDecoder => "node:string_decoder"
            case NodeTest => "node:test"
            case NodeTimers => "node:timers"
            case NodeTimersPromises => "node:timers/promises"
            case NodeTls => "node:tls"
            case NodeTty => "node:tty"
            case NodeUrl => "node:url"
            case NodeUtil => "node:util"
            case NodeUtilTypes => "node:util/types"
            case NodeVm => "node:vm"
            case NodeWasi => "node:wasi"
            case NodeZlib => "node:zlib"
            case NodeWorkerThreads => "node:worker_threads"
            case NodePunycode => "node:punycode"
            // Third-party overrides
            case Undici => "undici"
            case Ws => "ws"
            case IsomorphicFetch => "isomorphic-fetch"
            case NodeFetch => "node-fetch"
            case VercelFetch => "@vercel/fetch"
            case Utf8Validate => "utf-8-validate"
            // Additional Node.js core
            case NodeV8 => "node:v8"
            case NodeTraceEvents => "node:trace_events"
            case NodeRepl => "node:repl"
            case NodeInspector => "node:inspector"
            case NodeInspectorPromises => "node:inspector/promises"
            case NodeHttp2 => "node:http2"
            case NodeDiagnosticsChannel => "node:diagnostics_channel"
            case NodeDgram => "node:dgram"
            case NodeCluster => "node:cluster"
            // Node.js internal
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
        }
    }

    /// Static MAP: module specifier -> HardcodedModule.
    /// Corresponds to Bun:
    ///   Zig:  pub const map = bun.ComptimeStringMap(HardcodedModule, ...)
    ///   Rust: pub const MAP: phf::Map<&'static [u8], HardcodedModule> = phf::phf_map! { ... }
    /// Lazily initialized HashMap since Cangjie lacks compile-time perfect hash maps.
    public static let MAP: HashMap<String, HardcodedModule> = HardcodedModule.initMap()

    private static func initMap(): HashMap<String, HardcodedModule> {
        let m = HashMap<String, HardcodedModule>()
        // Bun-specific modules
        m.put("bun", HardcodedModule.Bun)
        m.put("bun:app", HardcodedModule.BunApp)
        m.put("bun:ffi", HardcodedModule.BunFfi)
        m.put("bun:jsc", HardcodedModule.BunJsc)
        m.put("bun:main", HardcodedModule.BunMain)
        m.put("bun:test", HardcodedModule.BunTest)
        m.put("bun:sqlite", HardcodedModule.BunSqlite)
        m.put("bun:wrap", HardcodedModule.BunWrap)
        m.put("bun:internal-for-testing", HardcodedModule.BunInternalForTesting)
        // Node.js core modules (node: prefix)
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
        m.put("node:readline", HardcodedModule.NodeReadline)
        m.put("node:test", HardcodedModule.NodeTest)
        m.put("node:os", HardcodedModule.NodeOs)
        m.put("node:path", HardcodedModule.NodePath)
        m.put("node:path/posix", HardcodedModule.NodePathPosix)
        m.put("node:path/win32", HardcodedModule.NodePathWin32)
        m.put("node:perf_hooks", HardcodedModule.NodePerfHooks)
        m.put("node:process", HardcodedModule.NodeProcess)
        m.put("node:punycode", HardcodedModule.NodePunycode)
        m.put("node:querystring", HardcodedModule.NodeQuerystring)
        m.put("node:readline/promises", HardcodedModule.NodeReadlinePromises)
        m.put("node:repl", HardcodedModule.NodeRepl)
        m.put("node:stream", HardcodedModule.NodeStream)
        m.put("node:stream/consumers", HardcodedModule.NodeStreamConsumers)
        m.put("node:stream/promises", HardcodedModule.NodeStreamPromises)
        m.put("node:stream/web", HardcodedModule.NodeStreamWeb)
        m.put("node:string_decoder", HardcodedModule.NodeStringDecoder)
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
        // Node.js internal modules (underscore-prefixed)
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
        // Third-party override packages
        m.put("node-fetch", HardcodedModule.NodeFetch)
        m.put("isomorphic-fetch", HardcodedModule.IsomorphicFetch)
        m.put("undici", HardcodedModule.Undici)
        m.put("ws", HardcodedModule.Ws)
        m.put("@vercel/fetch", HardcodedModule.VercelFetch)
        m.put("utf-8-validate", HardcodedModule.Utf8Validate)
        m.put("abort-controller", HardcodedModule.AbortController)
        return m
    }

    /// Lookup a module by specifier string.
    /// Returns the HardcodedModule enum value, or None if not found.
    /// Corresponds to Bun: HardcodedModule.map.get(name) -> ?HardcodedModule
    public static func lookup(name: String): ?HardcodedModule {
        MAP.get(name)
    }
}

// ============================================================================
// Alias struct
// Strictly translated from:
//   HardcodedModule.zig:  pub const Alias = struct { path, tag, node_builtin, node_only_prefix }
//   HardcodedModule.rs:   pub struct Alias { path: &'static ZStr, tag, node_builtin, node_only_prefix }
//
// Contains the resolved path, import tag, and metadata for a module specifier.
// The module loader uses Alias to resolve specifiers before mapping to HardcodedModule.
// ============================================================================

/// Alias - describes how a module specifier resolves to an actual module path.
/// Corresponds to Bun HardcodedModule.Alias.
///
/// Fields:
///   path:           resolved canonical path (e.g. "node:util", "bun:ffi")
///   tag:            import record tag (Builtin for most, Bun for "bun" itself)
///   nodeBuiltin:    true if this is a Node.js built-in module
///   nodeOnlyPrefix: true if this module ONLY resolves via "node:" prefix (e.g. node:test)
public class Alias {
    /// Resolved canonical path.
    /// Zig: [:0]const u8  /  Rust: &'static ZStr
    public var path: String
    /// Import record tag.
    /// Zig: ImportRecord.Tag  /  Rust: import_record::Tag
    public var tag: ImportTag
    /// Whether this is a Node.js built-in module.
    public var nodeBuiltin: Bool
    /// Whether this module only resolves via the "node:" prefix.
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
// Cfg - configuration for Alias lookup
// Strictly translated from:
//   HardcodedModule.zig:  const Cfg = struct { rewrite_jest_for_tests: bool = false }
//   HardcodedModule.rs:   pub struct Cfg { pub rewrite_jest_for_tests: bool }
// ============================================================================

/// Configuration for Alias lookup.
/// Corresponds to Bun HardcodedModule.Alias.Cfg.
public class Cfg {
    /// Whether to rewrite @jest/globals and vitest to bun:test.
    public var rewriteJestForTests: Bool

    public init() {
        rewriteJestForTests = false
    }

    public init(rewriteJestForTests: Bool) {
        this.rewriteJestForTests = rewriteJestForTests
    }
}

// ============================================================================
// Target - compilation target (re-exported from bao_bundler for Alias lookups)
// Strictly translated from:
//   HardcodedModule.zig uses options.Target (from bundler/options.zig)
//   HardcodedModule.rs  uses bun_ast::Target
//
// We define a lightweight Target enum here to avoid a circular dependency
// on bao_bundler. The Target type provides isBun() and isNode() methods
// which are the only methods used by Alias.get/has.
// ============================================================================

/// Compilation target for Alias lookup.
/// Corresponds to Bun options.Target (the subset needed by resolve_builtins).
/// Mirrors the Target enum in bao_bundler/src/options.cj.
public enum Target {
    | Browser
    | Bun
    | BunMacro
    | Node
    | BakeServerComponentsSsr

    /// Whether this target is a Bun runtime variant.
    /// Corresponds to Bun Target.isBun().
    public func isBun(): Bool {
        match (this) {
            case Bun | BunMacro | BakeServerComponentsSsr => true
            case _ => false
        }
    }

    /// Whether this target is Node.js.
    /// Corresponds to Bun Target.isNode().
    public func isNode(): Bool {
        this == Target.Node
    }
}

// ============================================================================
// Alias lookup table construction helpers
// Strictly translated from:
//   HardcodedModule.zig:  fn nodeEntry, fn nodeEntryOnlyPrefix, fn entry
//   HardcodedModule.rs:   macro_rules! node_entry!, node_entry_only_prefix!, entry!
//
// Zig constructs entries via comptime functions that return struct tuples.
// Rust uses declarative macros. Cangjie uses static helper functions.
// ============================================================================

/// "node:" prefix constant
private let NODE_PREFIX: String = "node:"
/// Length of "node:" prefix
private let NODE_PREFIX_LEN: Int64 = 5

/// Ensure a path has the "node:" prefix.
/// Corresponds to:
///   Zig:  if (path.len > 5 and std.mem.eql(u8, path[0..5], "node:")) path else "node:" ++ path
///   Rust: ensure_node_prefix! macro
private func ensureNodePrefix(path: String): String {
    if (path.length > NODE_PREFIX_LEN &&
        path.substring(Int64(0), NODE_PREFIX_LEN) == NODE_PREFIX) {
        return path
    }
    return NODE_PREFIX + path
}

/// Create a node entry (Node.js builtin with auto-prefixed path).
/// Corresponds to:
///   Zig:  fn nodeEntry(comptime path) struct { string, Alias }
///   Rust: macro_rules! node_entry!
///
/// The key is the input path; the Alias.path is the path with "node:" ensured.
/// tag = .builtin, node_builtin = true, node_only_prefix = false
private func nodeEntry(path: String): (String, Alias) {
    let resolvedPath = ensureNodePrefix(path)
    return (
        path,
        Alias(
            path: resolvedPath,
            tag: ImportTag.Builtin,
            nodeBuiltin: true,
            nodeOnlyPrefix: false
        )
    )
}

/// Create a node-only-prefix entry.
/// Corresponds to:
///   Zig:  fn nodeEntryOnlyPrefix(comptime path) struct { string, Alias }
///   Rust: macro_rules! node_entry_only_prefix!
///
/// Like nodeEntry but node_only_prefix = true. Used for modules that
/// ONLY resolve via the "node:" prefix (e.g. node:test).
private func nodeEntryOnlyPrefix(path: String): (String, Alias) {
    let resolvedPath = ensureNodePrefix(path)
    return (
        path,
        Alias(
            path: resolvedPath,
            tag: ImportTag.Builtin,
            nodeBuiltin: true,
            nodeOnlyPrefix: true
        )
    )
}

/// Create a plain entry (not a Node.js builtin).
/// Corresponds to:
///   Zig:  fn entry(comptime path) struct { string, Alias }
///   Rust: macro_rules! entry!
///
/// tag = .builtin, node_builtin = false, node_only_prefix = false
private func aliasEntry(path: String): (String, Alias) {
    return (
        path,
        Alias(
            path: path,
            tag: ImportTag.Builtin,
            nodeBuiltin: false,
            nodeOnlyPrefix: false
        )
    )
}

// ============================================================================
// COMMON_ALIAS_KVS - common alias key-value pairs
// Strictly translated from:
//   HardcodedModule.zig:  const common_alias_kvs = [_]struct { string, Alias }{ ... }
//   HardcodedModule.rs:   const COMMON_ALIAS_KVS: &[AliasKv] = &[ ... ]
//
// Applied to both --target=bun and --target=node.
// Contains:
//   1. node:-prefixed Node.js modules
//   2. Bare-name Node.js modules (auto-prefixed with "node:")
//   3. node:-prefixed internal modules (_http_*, _stream_*, _tls_*)
//   4. Bare-name internal modules
//   5. Special aliases (sys -> node:util)
//   6. Low-usage internal aliases (_stream_*, _tls_*)
// ============================================================================

/// Populate common aliases into the given map.
/// Corresponds to Bun COMMON_ALIAS_KVS array.
private func fillCommonAliases(m: HashMap<String, Alias>): Unit {
    // ===== node:-prefixed Node.js core modules =====
    putNodeEntry(m, "node:assert")
    putNodeEntry(m, "node:assert/strict")
    putNodeEntry(m, "node:async_hooks")
    putNodeEntry(m, "node:buffer")
    putNodeEntry(m, "node:child_process")
    putNodeEntry(m, "node:cluster")
    putNodeEntry(m, "node:console")
    putNodeEntry(m, "node:constants")
    putNodeEntry(m, "node:crypto")
    putNodeEntry(m, "node:dgram")
    putNodeEntry(m, "node:diagnostics_channel")
    putNodeEntry(m, "node:dns")
    putNodeEntry(m, "node:dns/promises")
    putNodeEntry(m, "node:domain")
    putNodeEntry(m, "node:events")
    putNodeEntry(m, "node:fs")
    putNodeEntry(m, "node:fs/promises")
    putNodeEntry(m, "node:http")
    putNodeEntry(m, "node:http2")
    putNodeEntry(m, "node:https")
    putNodeEntry(m, "node:inspector")
    putNodeEntry(m, "node:inspector/promises")
    putNodeEntry(m, "node:module")
    putNodeEntry(m, "node:net")
    putNodeEntry(m, "node:os")
    putNodeEntry(m, "node:path")
    putNodeEntry(m, "node:path/posix")
    putNodeEntry(m, "node:path/win32")
    putNodeEntry(m, "node:perf_hooks")
    putNodeEntry(m, "node:process")
    putNodeEntry(m, "node:punycode")
    putNodeEntry(m, "node:querystring")
    putNodeEntry(m, "node:readline")
    putNodeEntry(m, "node:readline/promises")
    putNodeEntry(m, "node:repl")
    putNodeEntry(m, "node:stream")
    putNodeEntry(m, "node:stream/consumers")
    putNodeEntry(m, "node:stream/promises")
    putNodeEntry(m, "node:stream/web")
    putNodeEntry(m, "node:string_decoder")
    putNodeEntry(m, "node:timers")
    putNodeEntry(m, "node:timers/promises")
    putNodeEntry(m, "node:tls")
    putNodeEntry(m, "node:trace_events")
    putNodeEntry(m, "node:tty")
    putNodeEntry(m, "node:url")
    putNodeEntry(m, "node:util")
    putNodeEntry(m, "node:util/types")
    putNodeEntry(m, "node:v8")
    putNodeEntry(m, "node:vm")
    putNodeEntry(m, "node:wasi")
    putNodeEntry(m, "node:worker_threads")
    putNodeEntry(m, "node:zlib")

    // node:test is node-only-prefix (only resolves via "node:test", not "test")
    // Bun: nodeEntryOnlyPrefix("node:test")
    let testKV = nodeEntryOnlyPrefix("node:test")
    m.put(testKV[0], testKV[1])

    // ===== Bare-name Node.js core modules (auto-prefixed with "node:") =====
    putNodeEntry(m, "assert")
    putNodeEntry(m, "assert/strict")
    putNodeEntry(m, "async_hooks")
    putNodeEntry(m, "buffer")
    putNodeEntry(m, "child_process")
    putNodeEntry(m, "cluster")
    putNodeEntry(m, "console")
    putNodeEntry(m, "constants")
    putNodeEntry(m, "crypto")
    putNodeEntry(m, "dgram")
    putNodeEntry(m, "diagnostics_channel")
    putNodeEntry(m, "dns")
    putNodeEntry(m, "dns/promises")
    putNodeEntry(m, "domain")
    putNodeEntry(m, "events")
    putNodeEntry(m, "fs")
    putNodeEntry(m, "fs/promises")
    putNodeEntry(m, "http")
    putNodeEntry(m, "http2")
    putNodeEntry(m, "https")
    putNodeEntry(m, "inspector")
    putNodeEntry(m, "inspector/promises")
    putNodeEntry(m, "module")
    putNodeEntry(m, "net")
    putNodeEntry(m, "os")
    putNodeEntry(m, "path")
    putNodeEntry(m, "path/posix")
    putNodeEntry(m, "path/win32")
    putNodeEntry(m, "perf_hooks")
    putNodeEntry(m, "process")
    putNodeEntry(m, "punycode")
    putNodeEntry(m, "querystring")
    putNodeEntry(m, "readline")
    putNodeEntry(m, "readline/promises")
    putNodeEntry(m, "repl")
    putNodeEntry(m, "stream")
    putNodeEntry(m, "stream/consumers")
    putNodeEntry(m, "stream/promises")
    putNodeEntry(m, "stream/web")
    putNodeEntry(m, "string_decoder")
    putNodeEntry(m, "timers")
    putNodeEntry(m, "timers/promises")
    putNodeEntry(m, "tls")
    putNodeEntry(m, "trace_events")
    putNodeEntry(m, "tty")
    putNodeEntry(m, "url")
    putNodeEntry(m, "util")
    putNodeEntry(m, "util/types")
    putNodeEntry(m, "v8")
    putNodeEntry(m, "vm")
    putNodeEntry(m, "wasi")
    putNodeEntry(m, "worker_threads")
    putNodeEntry(m, "zlib")

    // ===== node:-prefixed internal HTTP modules =====
    putNodeEntry(m, "node:_http_agent")
    putNodeEntry(m, "node:_http_client")
    putNodeEntry(m, "node:_http_common")
    putNodeEntry(m, "node:_http_incoming")
    putNodeEntry(m, "node:_http_outgoing")
    putNodeEntry(m, "node:_http_server")

    // ===== Bare-name internal HTTP modules =====
    putNodeEntry(m, "_http_agent")
    putNodeEntry(m, "_http_client")
    putNodeEntry(m, "_http_common")
    putNodeEntry(m, "_http_incoming")
    putNodeEntry(m, "_http_outgoing")
    putNodeEntry(m, "_http_server")

    // ===== Special aliases =====

    // sys is a deprecated alias for util
    // Bun: .{ "sys", .{ .path = "node:util", .node_builtin = true } }
    m.put("sys", Alias(
        path: "node:util",
        tag: ImportTag.Builtin,
        nodeBuiltin: true,
        nodeOnlyPrefix: false
    ))
    m.put("node:sys", Alias(
        path: "node:util",
        tag: ImportTag.Builtin,
        nodeBuiltin: true,
        nodeOnlyPrefix: false
    ))

    // ===== Low-usage internal aliases =====
    // Bun: "These are returned in builtinModules, but probably not many
    //       packages use them so we will just alias them."

    // node:-prefixed stream/tls internals
    m.put("node:_stream_duplex", Alias(
        path: "node:_stream_duplex",
        tag: ImportTag.Builtin,
        nodeBuiltin: true,
        nodeOnlyPrefix: false
    ))
    m.put("node:_stream_passthrough", Alias(
        path: "node:_stream_passthrough",
        tag: ImportTag.Builtin,
        nodeBuiltin: true,
        nodeOnlyPrefix: false
    ))
    m.put("node:_stream_readable", Alias(
        path: "node:_stream_readable",
        tag: ImportTag.Builtin,
        nodeBuiltin: true,
        nodeOnlyPrefix: false
    ))
    m.put("node:_stream_transform", Alias(
        path: "node:_stream_transform",
        tag: ImportTag.Builtin,
        nodeBuiltin: true,
        nodeOnlyPrefix: false
    ))
    m.put("node:_stream_wrap", Alias(
        path: "node:_stream_wrap",
        tag: ImportTag.Builtin,
        nodeBuiltin: true,
        nodeOnlyPrefix: false
    ))
    m.put("node:_stream_writable", Alias(
        path: "node:_stream_writable",
        tag: ImportTag.Builtin,
        nodeBuiltin: true,
        nodeOnlyPrefix: false
    ))
    // _tls_wrap -> node:tls (redirect)
    m.put("node:_tls_wrap", Alias(
        path: "node:tls",
        tag: ImportTag.Builtin,
        nodeBuiltin: true,
        nodeOnlyPrefix: false
    ))
    m.put("node:_tls_common", Alias(
        path: "node:_tls_common",
        tag: ImportTag.Builtin,
        nodeBuiltin: true,
        nodeOnlyPrefix: false
    ))

    // Bare-name stream/tls internals
    m.put("_stream_duplex", Alias(
        path: "node:_stream_duplex",
        tag: ImportTag.Builtin,
        nodeBuiltin: true,
        nodeOnlyPrefix: false
    ))
    m.put("_stream_passthrough", Alias(
        path: "node:_stream_passthrough",
        tag: ImportTag.Builtin,
        nodeBuiltin: true,
        nodeOnlyPrefix: false
    ))
    m.put("_stream_readable", Alias(
        path: "node:_stream_readable",
        tag: ImportTag.Builtin,
        nodeBuiltin: true,
        nodeOnlyPrefix: false
    ))
    m.put("_stream_transform", Alias(
        path: "node:_stream_transform",
        tag: ImportTag.Builtin,
        nodeBuiltin: true,
        nodeOnlyPrefix: false
    ))
    m.put("_stream_wrap", Alias(
        path: "node:_stream_wrap",
        tag: ImportTag.Builtin,
        nodeBuiltin: true,
        nodeOnlyPrefix: false
    ))
    m.put("_stream_writable", Alias(
        path: "node:_stream_writable",
        tag: ImportTag.Builtin,
        nodeBuiltin: true,
        nodeOnlyPrefix: false
    ))
    m.put("_tls_wrap", Alias(
        path: "node:tls",
        tag: ImportTag.Builtin,
        nodeBuiltin: true,
        nodeOnlyPrefix: false
    ))
    m.put("_tls_common", Alias(
        path: "node:_tls_common",
        tag: ImportTag.Builtin,
        nodeBuiltin: true,
        nodeOnlyPrefix: false
    ))
}

// ============================================================================
// BUN_EXTRA_ALIAS_KVS - Bun-specific extra aliases
// Strictly translated from:
//   HardcodedModule.zig:  const bun_extra_alias_kvs = [_]struct { string, Alias }{ ... }
//   HardcodedModule.rs:   const BUN_EXTRA_ALIAS_KVS: &[AliasKv] = &[ ... ]
//
// Only used under --target=bun.
// Contains:
//   1. Bun-specific modules (bun, bun:test, bun:sqlite, etc.)
//   2. Third-party package overrides (undici, ws, node-fetch, etc.)
//   3. Forced-native polyfills (abort-controller)
//   4. Next.js compiled dependency overrides
// ============================================================================

/// Populate Bun-specific extra aliases.
/// Corresponds to Bun BUN_EXTRA_ALIAS_KVS.
private func fillBunExtraAliases(m: HashMap<String, Alias>): Unit {
    // ===== Bun-specific modules =====
    // "bun" itself uses ImportTag.Bun - corresponds to Bun .{ .tag = .bun }
    m.put("bun", Alias(
        path: "bun",
        tag: ImportTag.Bun,
        nodeBuiltin: false,
        nodeOnlyPrefix: false
    ))

    putAliasEntry(m, "bun:test")
    putAliasEntry(m, "bun:app")
    putAliasEntry(m, "bun:ffi")
    putAliasEntry(m, "bun:jsc")
    putAliasEntry(m, "bun:main")
    putAliasEntry(m, "bun:sqlite")
    putAliasEntry(m, "bun:wrap")
    putAliasEntry(m, "bun:internal-for-testing")

    // ffi alias -> bun:ffi
    // Bun: .{ "ffi", .{ .path = "bun:ffi" } }
    m.put("ffi", Alias(
        path: "bun:ffi",
        tag: ImportTag.Builtin,
        nodeBuiltin: false,
        nodeOnlyPrefix: false
    ))

    // ===== Third-party package overrides =====
    putAliasEntry(m, "@vercel/fetch")
    putAliasEntry(m, "isomorphic-fetch")
    putAliasEntry(m, "node-fetch")
    putAliasEntry(m, "undici")
    putAliasEntry(m, "utf-8-validate")
    putAliasEntry(m, "ws")

    // ws/lib/websocket -> ws
    // Bun: .{ "ws/lib/websocket", .{ .path = "ws" } }
    m.put("ws/lib/websocket", Alias(
        path: "ws",
        tag: ImportTag.Builtin,
        nodeBuiltin: false,
        nodeOnlyPrefix: false
    ))

    // ===== Forced-native polyfills =====
    putAliasEntry(m, "abort-controller")

    // abort-controller/polyfill -> abort-controller
    m.put("abort-controller/polyfill", Alias(
        path: "abort-controller",
        tag: ImportTag.Builtin,
        nodeBuiltin: false,
        nodeOnlyPrefix: false
    ))

    // ===== Next.js compiled dependency overrides =====
    // Force Next.js to not use bundled dependencies.
    m.put("next/dist/compiled/ws", Alias(
        path: "ws",
        tag: ImportTag.Builtin,
        nodeBuiltin: false,
        nodeOnlyPrefix: false
    ))
    m.put("next/dist/compiled/node-fetch", Alias(
        path: "node-fetch",
        tag: ImportTag.Builtin,
        nodeBuiltin: false,
        nodeOnlyPrefix: false
    ))
    m.put("next/dist/compiled/undici", Alias(
        path: "undici",
        tag: ImportTag.Builtin,
        nodeBuiltin: false,
        nodeOnlyPrefix: false
    ))
}

// ============================================================================
// BUN_TEST_EXTRA_ALIAS_KVS - test framework extra aliases
// Strictly translated from:
//   HardcodedModule.zig:  const bun_test_extra_alias_kvs = [_]struct { string, Alias }{ ... }
//   HardcodedModule.rs:   const BUN_TEST_EXTRA_ALIAS_KVS: &[AliasKv] = &[ ... ]
//
// Only used under --target=bun with rewrite_jest_for_tests=true.
// Maps @jest/globals and vitest to bun:test.
// ============================================================================

/// Populate test framework extra aliases.
/// Corresponds to Bun BUN_TEST_EXTRA_ALIAS_KVS.
private func fillBunTestExtraAliases(m: HashMap<String, Alias>): Unit {
    // @jest/globals -> bun:test
    m.put("@jest/globals", Alias(
        path: "bun:test",
        tag: ImportTag.Builtin,
        nodeBuiltin: false,
        nodeOnlyPrefix: false
    ))
    // vitest -> bun:test
    m.put("vitest", Alias(
        path: "bun:test",
        tag: ImportTag.Builtin,
        nodeBuiltin: false,
        nodeOnlyPrefix: false
    ))
}

// ============================================================================
// Helper: put a nodeEntry into the map
// ============================================================================

private func putNodeEntry(m: HashMap<String, Alias>, path: String): Unit {
    let kv = nodeEntry(path)
    m.put(kv[0], kv[1])
}

private func putAliasEntry(m: HashMap<String, Alias>, path: String): Unit {
    let kv = aliasEntry(path)
    m.put(kv[0], kv[1])
}

// ============================================================================
// Alias lookup tables
// Strictly translated from:
//   HardcodedModule.zig:
//     const node_aliases      = bun.ComptimeStringMap(Alias, common_alias_kvs)
//     pub const bun_aliases   = bun.ComptimeStringMap(Alias, common_alias_kvs ++ bun_extra_alias_kvs)
//     const bun_test_aliases  = bun.ComptimeStringMap(Alias, common ++ bun_extra ++ bun_test_extra)
//   HardcodedModule.rs:
//     const NODE_ALIASES:      &[&[AliasKv]] = &[COMMON_ALIAS_KVS]
//     pub const BUN_ALIASES:   &[&[AliasKv]] = &[COMMON_ALIAS_KVS, BUN_EXTRA_ALIAS_KVS]
//     const BUN_TEST_ALIASES:  &[&[AliasKv]] = &[COMMON, BUN_EXTRA, BUN_TEST_EXTRA]
//
// Zig builds three ComptimeStringMaps by concatenating const arrays via comptime ++.
// Rust uses layered const slices with a linear scan lookup.
// Cangjie uses HashMap<String, Alias> for O(1) amortized lookup.
// ============================================================================

/// Node.js alias map (common only).
/// Corresponds to Bun node_aliases = ComptimeStringMap(Alias, common_alias_kvs).
/// Used under --target=node.
public let NODE_ALIASES: HashMap<String, Alias> = AliasTables.initNodeAliases()

/// Bun alias map (common + bun_extra).
/// Corresponds to Bun bun_aliases = ComptimeStringMap(Alias, common ++ bun_extra).
/// Used under --target=bun (without jest rewrite).
public let BUN_ALIASES: HashMap<String, Alias> = AliasTables.initBunAliases()

/// Bun test alias map (common + bun_extra + bun_test_extra).
/// Corresponds to Bun bun_test_aliases = ComptimeStringMap(Alias, common ++ bun_extra ++ bun_test_extra).
/// Used under --target=bun with rewrite_jest_for_tests=true.
public let BUN_TEST_ALIASES: HashMap<String, Alias> = AliasTables.initBunTestAliases()

/// Internal class for lazy initialization of alias tables.
/// Separated to avoid circular static initialization issues.
internal class AliasTables {
    public static func initNodeAliases(): HashMap<String, Alias> {
        let m = HashMap<String, Alias>()
        fillCommonAliases(m)
        return m
    }

    public static func initBunAliases(): HashMap<String, Alias> {
        let m = HashMap<String, Alias>()
        fillCommonAliases(m)
        fillBunExtraAliases(m)
        return m
    }

    public static func initBunTestAliases(): HashMap<String, Alias> {
        let m = HashMap<String, Alias>()
        fillCommonAliases(m)
        fillBunExtraAliases(m)
        fillBunTestExtraAliases(m)
        return m
    }
}

// ============================================================================
// Alias lookup function
// Strictly translated from:
//   HardcodedModule.rs:  fn lookup(tables: &[&[AliasKv]], name: &[u8]) -> Option<Alias>
//   HardcodedModule.zig: ComptimeStringMap.get() (O(1) comptime perfect hash)
// ============================================================================

/// Look up an alias by name in the given table.
/// Corresponds to Bun lookup() function (linear scan in Rust, O(1) in Zig).
/// Cangjie uses HashMap.get() for O(1) amortized lookup.
public func aliasLookup(table: HashMap<String, Alias>, name: String): ?Alias {
    table.get(name)
}

// ============================================================================
// Alias public API: has() and get()
// Strictly translated from:
//   HardcodedModule.zig:
//     pub fn has(name: []const u8, target: options.Target, cfg: Cfg) bool
//     pub fn get(name: []const u8, target: options.Target, cfg: Cfg) ?Alias
//   HardcodedModule.rs:
//     pub fn has(name: &[u8], target: Target, cfg: Cfg) -> bool
//     pub fn get(name: &[u8], target: Target, cfg: Cfg) -> Option<Alias>
//
// Lookup logic:
//   if target.isBun():
//     if cfg.rewrite_jest_for_tests: bun_test_aliases.get(name)
//     else:                          bun_aliases.get(name)
//   elif target.isNode():
//     node_aliases.get(name)
//   else:
//     null
// ============================================================================

/// Alias lookup by name, target, and configuration.
/// Corresponds to Bun Alias.get(name, target, cfg) -> ?Alias.
///
/// - name:   module specifier (e.g. "fs", "node:path", "bun:sqlite")
/// - target: compilation target (Bun, Node, Browser, etc.)
/// - cfg:    configuration (rewrite_jest_for_tests flag)
/// Returns:  the Alias if found, None otherwise.
public func aliasGet(name: String, target: Target, cfg: Cfg): ?Alias {
    if (target.isBun()) {
        if (cfg.rewriteJestForTests) {
            return BUN_TEST_ALIASES.get(name)
        } else {
            return BUN_ALIASES.get(name)
        }
    } else if (target.isNode()) {
        return NODE_ALIASES.get(name)
    }
    return None
}

/// Check if an alias exists for the given name, target, and configuration.
/// Corresponds to Bun Alias.has(name, target, cfg) -> bool.
public func aliasHas(name: String, target: Target, cfg: Cfg): Bool {
    aliasGet(name, target, cfg) != None
}
