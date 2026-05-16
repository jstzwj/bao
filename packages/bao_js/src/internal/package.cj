// bao_js.internal - one-to-one Bun src/js/internal resource manifest
package bao_js.internal

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
        SourceResource("abort_listener", "bun/src/js/internal/abort_listener.ts", "resources/internal/abort_listener.ts", "typescript", true),
        SourceResource("assert/assertion_error", "bun/src/js/internal/assert/assertion_error.ts", "resources/internal/assert/assertion_error.ts", "typescript", true),
        SourceResource("assert/calltracker", "bun/src/js/internal/assert/calltracker.ts", "resources/internal/assert/calltracker.ts", "typescript", true),
        SourceResource("assert/myers_diff", "bun/src/js/internal/assert/myers_diff.ts", "resources/internal/assert/myers_diff.ts", "typescript", true),
        SourceResource("assert/utils", "bun/src/js/internal/assert/utils.ts", "resources/internal/assert/utils.ts", "typescript", true),
        SourceResource("buffer", "bun/src/js/internal/buffer.ts", "resources/internal/buffer.ts", "typescript", true),
        SourceResource("cluster/RoundRobinHandle", "bun/src/js/internal/cluster/RoundRobinHandle.ts", "resources/internal/cluster/RoundRobinHandle.ts", "typescript", true),
        SourceResource("cluster/Worker", "bun/src/js/internal/cluster/Worker.ts", "resources/internal/cluster/Worker.ts", "typescript", true),
        SourceResource("cluster/child", "bun/src/js/internal/cluster/child.ts", "resources/internal/cluster/child.ts", "typescript", true),
        SourceResource("cluster/isPrimary", "bun/src/js/internal/cluster/isPrimary.ts", "resources/internal/cluster/isPrimary.ts", "typescript", true),
        SourceResource("cluster/primary", "bun/src/js/internal/cluster/primary.ts", "resources/internal/cluster/primary.ts", "typescript", true),
        SourceResource("crypto/x509", "bun/src/js/internal/crypto/x509.ts", "resources/internal/crypto/x509.ts", "typescript", true),
        SourceResource("debugger", "bun/src/js/internal/debugger.ts", "resources/internal/debugger.ts", "typescript", true),
        SourceResource("errors", "bun/src/js/internal/errors.ts", "resources/internal/errors.ts", "typescript", true),
        SourceResource("fifo", "bun/src/js/internal/fifo.ts", "resources/internal/fifo.ts", "typescript", true),
        SourceResource("fixed_queue", "bun/src/js/internal/fixed_queue.ts", "resources/internal/fixed_queue.ts", "typescript", true),
        SourceResource("freelist", "bun/src/js/internal/freelist.ts", "resources/internal/freelist.ts", "typescript", true),
        SourceResource("fs/cp-sync", "bun/src/js/internal/fs/cp-sync.ts", "resources/internal/fs/cp-sync.ts", "typescript", true),
        SourceResource("fs/cp", "bun/src/js/internal/fs/cp.ts", "resources/internal/fs/cp.ts", "typescript", true),
        SourceResource("fs/glob", "bun/src/js/internal/fs/glob.ts", "resources/internal/fs/glob.ts", "typescript", true),
        SourceResource("fs/streams", "bun/src/js/internal/fs/streams.ts", "resources/internal/fs/streams.ts", "typescript", true),
        SourceResource("html", "bun/src/js/internal/html.ts", "resources/internal/html.ts", "typescript", true),
        SourceResource("http", "bun/src/js/internal/http.ts", "resources/internal/http.ts", "typescript", true),
        SourceResource("http/FakeSocket", "bun/src/js/internal/http/FakeSocket.ts", "resources/internal/http/FakeSocket.ts", "typescript", true),
        SourceResource("linkedlist", "bun/src/js/internal/linkedlist.ts", "resources/internal/linkedlist.ts", "typescript", true),
        SourceResource("net/isIP", "bun/src/js/internal/net/isIP.ts", "resources/internal/net/isIP.ts", "typescript", true),
        SourceResource("perf_hooks/monitorEventLoopDelay", "bun/src/js/internal/perf_hooks/monitorEventLoopDelay.ts", "resources/internal/perf_hooks/monitorEventLoopDelay.ts", "typescript", true),
        SourceResource("primordials", "bun/src/js/internal/primordials.js", "resources/internal/primordials.js", "javascript", true),
        SourceResource("promisify", "bun/src/js/internal/promisify.ts", "resources/internal/promisify.ts", "typescript", true),
        SourceResource("shared", "bun/src/js/internal/shared.ts", "resources/internal/shared.ts", "typescript", true),
        SourceResource("sql/errors", "bun/src/js/internal/sql/errors.ts", "resources/internal/sql/errors.ts", "typescript", true),
        SourceResource("sql/mysql", "bun/src/js/internal/sql/mysql.ts", "resources/internal/sql/mysql.ts", "typescript", true),
        SourceResource("sql/postgres", "bun/src/js/internal/sql/postgres.ts", "resources/internal/sql/postgres.ts", "typescript", true),
        SourceResource("sql/query", "bun/src/js/internal/sql/query.ts", "resources/internal/sql/query.ts", "typescript", true),
        SourceResource("sql/shared", "bun/src/js/internal/sql/shared.ts", "resources/internal/sql/shared.ts", "typescript", true),
        SourceResource("sql/sqlite", "bun/src/js/internal/sql/sqlite.ts", "resources/internal/sql/sqlite.ts", "typescript", true),
        SourceResource("stream/promises", "bun/src/js/internal/stream.promises.ts", "resources/internal/stream.promises.ts", "typescript", true),
        SourceResource("stream", "bun/src/js/internal/stream.ts", "resources/internal/stream.ts", "typescript", true),
        SourceResource("streams/add-abort-signal", "bun/src/js/internal/streams/add-abort-signal.ts", "resources/internal/streams/add-abort-signal.ts", "typescript", true),
        SourceResource("streams/compose", "bun/src/js/internal/streams/compose.ts", "resources/internal/streams/compose.ts", "typescript", true),
        SourceResource("streams/destroy", "bun/src/js/internal/streams/destroy.ts", "resources/internal/streams/destroy.ts", "typescript", true),
        SourceResource("streams/duplex", "bun/src/js/internal/streams/duplex.ts", "resources/internal/streams/duplex.ts", "typescript", true),
        SourceResource("streams/duplexify", "bun/src/js/internal/streams/duplexify.ts", "resources/internal/streams/duplexify.ts", "typescript", true),
        SourceResource("streams/duplexpair", "bun/src/js/internal/streams/duplexpair.ts", "resources/internal/streams/duplexpair.ts", "typescript", true),
        SourceResource("streams/end-of-stream", "bun/src/js/internal/streams/end-of-stream.ts", "resources/internal/streams/end-of-stream.ts", "typescript", true),
        SourceResource("streams/from", "bun/src/js/internal/streams/from.ts", "resources/internal/streams/from.ts", "typescript", true),
        SourceResource("streams/lazy_transform", "bun/src/js/internal/streams/lazy_transform.ts", "resources/internal/streams/lazy_transform.ts", "typescript", true),
        SourceResource("streams/legacy", "bun/src/js/internal/streams/legacy.ts", "resources/internal/streams/legacy.ts", "typescript", true),
        SourceResource("streams/native-readable", "bun/src/js/internal/streams/native-readable.ts", "resources/internal/streams/native-readable.ts", "typescript", true),
        SourceResource("streams/operators", "bun/src/js/internal/streams/operators.ts", "resources/internal/streams/operators.ts", "typescript", true),
        SourceResource("streams/passthrough", "bun/src/js/internal/streams/passthrough.ts", "resources/internal/streams/passthrough.ts", "typescript", true),
        SourceResource("streams/pipeline", "bun/src/js/internal/streams/pipeline.ts", "resources/internal/streams/pipeline.ts", "typescript", true),
        SourceResource("streams/readable", "bun/src/js/internal/streams/readable.ts", "resources/internal/streams/readable.ts", "typescript", true),
        SourceResource("streams/state", "bun/src/js/internal/streams/state.ts", "resources/internal/streams/state.ts", "typescript", true),
        SourceResource("streams/transform", "bun/src/js/internal/streams/transform.ts", "resources/internal/streams/transform.ts", "typescript", true),
        SourceResource("streams/utils", "bun/src/js/internal/streams/utils.ts", "resources/internal/streams/utils.ts", "typescript", true),
        SourceResource("streams/writable", "bun/src/js/internal/streams/writable.ts", "resources/internal/streams/writable.ts", "typescript", true),
        SourceResource("timers", "bun/src/js/internal/timers.ts", "resources/internal/timers.ts", "typescript", true),
        SourceResource("tls", "bun/src/js/internal/tls.ts", "resources/internal/tls.ts", "typescript", true),
        SourceResource("tty", "bun/src/js/internal/tty.ts", "resources/internal/tty.ts", "typescript", true),
        SourceResource("url", "bun/src/js/internal/url.ts", "resources/internal/url.ts", "typescript", true),
        SourceResource("util/colors", "bun/src/js/internal/util/colors.ts", "resources/internal/util/colors.ts", "typescript", true),
        SourceResource("util/deprecate", "bun/src/js/internal/util/deprecate.ts", "resources/internal/util/deprecate.ts", "typescript", true),
        SourceResource("util/inspect", "bun/src/js/internal/util/inspect.d.ts", "resources/internal/util/inspect.d.ts", "typescript-declaration", true),
        SourceResource("util/inspect", "bun/src/js/internal/util/inspect.js", "resources/internal/util/inspect.js", "javascript", true),
        SourceResource("util/mime", "bun/src/js/internal/util/mime.ts", "resources/internal/util/mime.ts", "typescript", true),
        SourceResource("validators", "bun/src/js/internal/validators.ts", "resources/internal/validators.ts", "typescript", true),
        SourceResource("webstreams_adapters", "bun/src/js/internal/webstreams_adapters.ts", "resources/internal/webstreams_adapters.ts", "typescript", true)
    ]
}

public const RESOURCE_COUNT: Int64 = 68
