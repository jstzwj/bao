// bao_js.node - one-to-one Bun src/js/node resource manifest
package bao_js.node

/// Describes a Bun source file preserved as a Bao runtime/build resource.
/// JS/TS resources are intentionally not translated to Cangjie because Bun loads
/// them as JavaScript modules or build-time generator scripts.
public struct SourceResource {
    public let moduleName: String
    public let bunPath: String
    public let resourcePath: String
    public let kind: String
    public let runtimeResource: Bool

    public init(moduleName: String, bunPath: String, resourcePath: String, kind: String, runtimeResource: Bool) {
        this.moduleName = moduleName
        this.bunPath = bunPath
        this.resourcePath = resourcePath
        this.kind = kind
        this.runtimeResource = runtimeResource
    }
}

public func listResources(): Array<SourceResource> {
    return [
        SourceResource("_http2_upgrade", "bun/src/js/node/_http2_upgrade.ts", "resources/node/_http2_upgrade.ts", "typescript", true),
        SourceResource("_http_agent", "bun/src/js/node/_http_agent.ts", "resources/node/_http_agent.ts", "typescript", true),
        SourceResource("_http_client", "bun/src/js/node/_http_client.ts", "resources/node/_http_client.ts", "typescript", true),
        SourceResource("_http_common", "bun/src/js/node/_http_common.ts", "resources/node/_http_common.ts", "typescript", true),
        SourceResource("_http_incoming", "bun/src/js/node/_http_incoming.ts", "resources/node/_http_incoming.ts", "typescript", true),
        SourceResource("_http_outgoing", "bun/src/js/node/_http_outgoing.ts", "resources/node/_http_outgoing.ts", "typescript", true),
        SourceResource("_http_server", "bun/src/js/node/_http_server.ts", "resources/node/_http_server.ts", "typescript", true),
        SourceResource("_stream_duplex", "bun/src/js/node/_stream_duplex.ts", "resources/node/_stream_duplex.ts", "typescript", true),
        SourceResource("_stream_passthrough", "bun/src/js/node/_stream_passthrough.ts", "resources/node/_stream_passthrough.ts", "typescript", true),
        SourceResource("_stream_readable", "bun/src/js/node/_stream_readable.ts", "resources/node/_stream_readable.ts", "typescript", true),
        SourceResource("_stream_transform", "bun/src/js/node/_stream_transform.ts", "resources/node/_stream_transform.ts", "typescript", true),
        SourceResource("_stream_wrap", "bun/src/js/node/_stream_wrap.ts", "resources/node/_stream_wrap.ts", "typescript", true),
        SourceResource("_stream_writable", "bun/src/js/node/_stream_writable.ts", "resources/node/_stream_writable.ts", "typescript", true),
        SourceResource("_tls_common", "bun/src/js/node/_tls_common.ts", "resources/node/_tls_common.ts", "typescript", true),
        SourceResource("assert/strict", "bun/src/js/node/assert.strict.ts", "resources/node/assert.strict.ts", "typescript", true),
        SourceResource("assert", "bun/src/js/node/assert.ts", "resources/node/assert.ts", "typescript", true),
        SourceResource("async_hooks", "bun/src/js/node/async_hooks.ts", "resources/node/async_hooks.ts", "typescript", true),
        SourceResource("child_process", "bun/src/js/node/child_process.ts", "resources/node/child_process.ts", "typescript", true),
        SourceResource("cluster", "bun/src/js/node/cluster.ts", "resources/node/cluster.ts", "typescript", true),
        SourceResource("console", "bun/src/js/node/console.ts", "resources/node/console.ts", "typescript", true),
        SourceResource("crypto", "bun/src/js/node/crypto.ts", "resources/node/crypto.ts", "typescript", true),
        SourceResource("dgram", "bun/src/js/node/dgram.ts", "resources/node/dgram.ts", "typescript", true),
        SourceResource("diagnostics_channel", "bun/src/js/node/diagnostics_channel.ts", "resources/node/diagnostics_channel.ts", "typescript", true),
        SourceResource("dns/promises", "bun/src/js/node/dns.promises.ts", "resources/node/dns.promises.ts", "typescript", true),
        SourceResource("dns", "bun/src/js/node/dns.ts", "resources/node/dns.ts", "typescript", true),
        SourceResource("domain", "bun/src/js/node/domain.ts", "resources/node/domain.ts", "typescript", true),
        SourceResource("events", "bun/src/js/node/events.ts", "resources/node/events.ts", "typescript", true),
        SourceResource("fs/promises", "bun/src/js/node/fs.promises.ts", "resources/node/fs.promises.ts", "typescript", true),
        SourceResource("fs", "bun/src/js/node/fs.ts", "resources/node/fs.ts", "typescript", true),
        SourceResource("http", "bun/src/js/node/http.ts", "resources/node/http.ts", "typescript", true),
        SourceResource("http2", "bun/src/js/node/http2.ts", "resources/node/http2.ts", "typescript", true),
        SourceResource("https", "bun/src/js/node/https.ts", "resources/node/https.ts", "typescript", true),
        SourceResource("inspector/promises", "bun/src/js/node/inspector.promises.ts", "resources/node/inspector.promises.ts", "typescript", true),
        SourceResource("inspector", "bun/src/js/node/inspector.ts", "resources/node/inspector.ts", "typescript", true),
        SourceResource("net", "bun/src/js/node/net.ts", "resources/node/net.ts", "typescript", true),
        SourceResource("os", "bun/src/js/node/os.ts", "resources/node/os.ts", "typescript", true),
        SourceResource("path/posix", "bun/src/js/node/path.posix.ts", "resources/node/path.posix.ts", "typescript", true),
        SourceResource("path", "bun/src/js/node/path.ts", "resources/node/path.ts", "typescript", true),
        SourceResource("path/win32", "bun/src/js/node/path.win32.ts", "resources/node/path.win32.ts", "typescript", true),
        SourceResource("perf_hooks", "bun/src/js/node/perf_hooks.ts", "resources/node/perf_hooks.ts", "typescript", true),
        SourceResource("punycode", "bun/src/js/node/punycode.ts", "resources/node/punycode.ts", "typescript", true),
        SourceResource("querystring", "bun/src/js/node/querystring.ts", "resources/node/querystring.ts", "typescript", true),
        SourceResource("readline/promises", "bun/src/js/node/readline.promises.ts", "resources/node/readline.promises.ts", "typescript", true),
        SourceResource("readline", "bun/src/js/node/readline.ts", "resources/node/readline.ts", "typescript", true),
        SourceResource("repl", "bun/src/js/node/repl.ts", "resources/node/repl.ts", "typescript", true),
        SourceResource("stream/consumers", "bun/src/js/node/stream.consumers.ts", "resources/node/stream.consumers.ts", "typescript", true),
        SourceResource("stream/promises", "bun/src/js/node/stream.promises.ts", "resources/node/stream.promises.ts", "typescript", true),
        SourceResource("stream", "bun/src/js/node/stream.ts", "resources/node/stream.ts", "typescript", true),
        SourceResource("stream/web", "bun/src/js/node/stream.web.ts", "resources/node/stream.web.ts", "typescript", true),
        SourceResource("test", "bun/src/js/node/test.ts", "resources/node/test.ts", "typescript", true),
        SourceResource("timers/promises", "bun/src/js/node/timers.promises.ts", "resources/node/timers.promises.ts", "typescript", true),
        SourceResource("timers", "bun/src/js/node/timers.ts", "resources/node/timers.ts", "typescript", true),
        SourceResource("tls", "bun/src/js/node/tls.ts", "resources/node/tls.ts", "typescript", true),
        SourceResource("trace_events", "bun/src/js/node/trace_events.ts", "resources/node/trace_events.ts", "typescript", true),
        SourceResource("tty", "bun/src/js/node/tty.ts", "resources/node/tty.ts", "typescript", true),
        SourceResource("url", "bun/src/js/node/url.ts", "resources/node/url.ts", "typescript", true),
        SourceResource("util", "bun/src/js/node/util.ts", "resources/node/util.ts", "typescript", true),
        SourceResource("v8", "bun/src/js/node/v8.ts", "resources/node/v8.ts", "typescript", true),
        SourceResource("vm", "bun/src/js/node/vm.ts", "resources/node/vm.ts", "typescript", true),
        SourceResource("wasi", "bun/src/js/node/wasi.ts", "resources/node/wasi.ts", "typescript", true),
        SourceResource("worker_threads", "bun/src/js/node/worker_threads.ts", "resources/node/worker_threads.ts", "typescript", true),
        SourceResource("zlib", "bun/src/js/node/zlib.ts", "resources/node/zlib.ts", "typescript", true)
    ]
}

public const RESOURCE_COUNT: Int64 = 62
