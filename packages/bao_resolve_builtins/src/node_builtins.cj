// NodeBuiltinPatterns - Node.js core module name lists
// Strictly translated from: bun/src/resolve_builtins/node_builtins.rs
//
// Bun maintains three const arrays via a single macro invocation:
//   NODE_BUILTIN_PATTERNS_RAW:  57 bare Node.js core module names
//   NODE_BUILTIN_PATTERNS:      RAW + each prefixed with "node:" = 114 entries
//   BUN_NODE_BUILTIN_PATTERNS_COMPAT: 52 Bun-compat subset (excludes buffer/fs/path/process/test)
//
// The Bun Rust macro `node_builtins_table!` ensures each name appears exactly
// once in the source, with the three const arrays generated automatically.
// In Cangjie we spell them out explicitly for clarity.
package bao_resolve_builtins

// ============================================================================
// compat group (52 names)
// These modules can be marked as external dependencies under --target=bun.
// Strictly mirrors Bun `node_builtins_table! { compat: [...] }`.
// Order matches Bun: compat-first, node_only-last.
// ============================================================================

/// Bun-compat Node.js core module bare names.
/// Translated from Bun BUN_NODE_BUILTIN_PATTERNS_COMPAT (52 entries).
/// Excludes: buffer, fs, path, process, test.
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

/// node_only group (5 names): Bun provides its own implementation for these,
/// so they stay resolvable under --target=bun rather than being marked external.
/// Translated from Bun `node_builtins_table! { node_only: [...] }`.
public let NODE_BUILTIN_NODE_ONLY: Array<String> = [
    "buffer",
    "fs",
    "path",
    "process",
    "test",
]

// ============================================================================
// NODE_BUILTIN_PATTERNS_RAW
// All 57 Node.js core module bare names (compat ++ node_only).
// Translated from Bun NODE_BUILTIN_PATTERNS_RAW.
// ============================================================================

/// All Node.js core module bare names (57 entries).
/// Concatenation of compat (52) + node_only (5).
/// Corresponds to Bun `NODE_BUILTIN_PATTERNS_RAW`.
public let NODE_BUILTIN_PATTERNS_RAW: Array<String> = [
    // compat group (52)
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
    // node_only group (5)
    "buffer",
    "fs",
    "path",
    "process",
    "test",
]

// ============================================================================
// NODE_BUILTIN_PATTERNS
// RAW ++ RAW.map(|m| "node:" ++ m) = 57 + 57 = 114 entries.
// Translated from Bun NODE_BUILTIN_PATTERNS.
// In Bun (Zig) this is built via comptime `++`; in the Rust port via
// `concat!` inside the macro; here we spell out the full list.
// ============================================================================

/// All Node.js core module names including "node:" prefixed versions (114 entries).
/// Corresponds to Bun `NODE_BUILTIN_PATTERNS`.
public let NODE_BUILTIN_PATTERNS: Array<String> = [
    // RAW (57 bare names)
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
    // "node:" prefixed versions (57)
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
