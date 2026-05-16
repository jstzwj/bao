// bao_js.node - Node.js 兼容内置模块定义
// 严格翻译自: src/js/node/*.ts
//   Bun 实现了完整的 Node.js 兼容层。
//   每个文件对应一个 node:* 模块:
//   fs.ts -> node:fs, path.ts -> node:path, http.ts -> node:http, ...
//   模块通过 $requireId(n) 或 require("node:xxx") 加载。
package bao_js.node

import bao_core.*
import bao_js.*

// ============================================================================
// NodeModuleRegistry - Node.js 模块注册表
// 严格翻译自: src/js/node/ 目录 (60+ 模块)
//   在 Bun 中, 每个 Node.js 兼容模块由一个 .ts 文件实现。
//   模块在编译时被打包器预处理:
//   - require("fs") -> $requireId(<n>)
//   - export default -> return
//   - $ 前缀 -> @ (JSC 内部)
// ============================================================================

/// Node.js 模块注册表
public class NodeModuleRegistry {
    /// 注册所有 Node.js 内置模块
    // 对应 Bun build 过程中自动生成的模块 ID 映射
    public static func registerAll(registry: BuiltinRegistry): Unit {
        // fs 模块
        // 严格翻译自: src/js/node/fs.ts
        //   export default { ... } -> 包含 fs API 的 Node.js 兼容实现
        registerFs(registry)

        // path 模块
        // 严格翻译自: src/js/node/path.ts, path.posix.ts, path.win32.ts
        registerPath(registry)

        // os 模块
        // 严格翻译自: src/js/node/os.ts
        registerOs(registry)

        // stream 模块
        // 严格翻译自: src/js/node/stream.ts, stream.web.ts, stream.promises.ts
        //   以及 _stream_readable.ts, _stream_writable.ts, _stream_duplex.ts,
        //   _stream_transform.ts, _stream_passthrough.ts, _stream_wrap.ts
        registerStream(registry)

        // events 模块
        // 严格翻译自: src/js/node/events.ts
        registerEvents(registry)

        // http 模块
        // 严格翻译自: src/js/node/http.ts, https.ts
        //   以及 _http_agent.ts, _http_client.ts, _http_common.ts,
        //   _http_incoming.ts, _http_outgoing.ts, _http_server.ts
        registerHttp(registry)

        // crypto 模块
        // 严格翻译自: src/js/node/crypto.ts
        registerCrypto(registry)

        // util 模块
        // 严格翻译自: src/js/node/util.ts
        registerUtil(registry)

        // url 模块
        // 严格翻译自: src/js/node/url.ts
        registerUrl(registry)

        // zlib 模块
        // 严格翻译自: src/js/node/zlib.ts
        registerZlib(registry)

        // net 模块
        // 严格翻译自: src/js/node/net.ts
        registerNet(registry)

        // dns 模块
        // 严格翻译自: src/js/node/dns.ts, dns.promises.ts
        registerDns(registry)

        // child_process 模块
        // 严格翻译自: src/js/node/child_process.ts
        registerChildProcess(registry)

        // tls 模块
        // 严格翻译自: src/js/node/tls.ts
        registerTls(registry)

        // vm 模块
        // 严格翻译自: src/js/node/vm.ts
        registerVm(registry)

        // 其他模块
        registerRemaining(registry)
    }

    private static func registerFs(registry: BuiltinRegistry): Unit {
        // 对应 src/js/node/fs.ts
        // export default { open, close, read, write, stat, lstat, fstat, ... }
        let module = BuiltinModule(
            BuiltinModuleId.Id(0),
            "node:fs",
            BuiltinModuleKind.Node,
            "fs"
        )
        registry.register(module)
    }

    private static func registerPath(registry: BuiltinRegistry): Unit {
        // 对应 src/js/node/path.ts, path.posix.ts, path.win32.ts
        let module = BuiltinModule(
            BuiltinModuleId.Id(1),
            "node:path",
            BuiltinModuleKind.Node,
            "path"
        )
        registry.register(module)
    }

    private static func registerOs(registry: BuiltinRegistry): Unit {
        // 对应 src/js/node/os.ts
        let module = BuiltinModule(
            BuiltinModuleId.Id(2),
            "node:os",
            BuiltinModuleKind.Node,
            "os"
        )
        registry.register(module)
    }

    private static func registerStream(registry: BuiltinRegistry): Unit {
        // 对应 src/js/node/stream.ts 等
        let module = BuiltinModule(
            BuiltinModuleId.Id(3),
            "node:stream",
            BuiltinModuleKind.Node,
            "stream"
        )
        registry.register(module)
    }

    private static func registerEvents(registry: BuiltinRegistry): Unit {
        let module = BuiltinModule(
            BuiltinModuleId.Id(4),
            "node:events",
            BuiltinModuleKind.Node,
            "events"
        )
        registry.register(module)
    }

    private static func registerHttp(registry: BuiltinRegistry): Unit {
        let module = BuiltinModule(
            BuiltinModuleId.Id(5),
            "node:http",
            BuiltinModuleKind.Node,
            "http"
        )
        registry.register(module)
    }

    private static func registerCrypto(registry: BuiltinRegistry): Unit {
        let module = BuiltinModule(
            BuiltinModuleId.Id(6),
            "node:crypto",
            BuiltinModuleKind.Node,
            "crypto"
        )
        registry.register(module)
    }

    private static func registerUtil(registry: BuiltinRegistry): Unit {
        let module = BuiltinModule(
            BuiltinModuleId.Id(7),
            "node:util",
            BuiltinModuleKind.Node,
            "util"
        )
        registry.register(module)
    }

    private static func registerUrl(registry: BuiltinRegistry): Unit {
        let module = BuiltinModule(
            BuiltinModuleId.Id(8),
            "node:url",
            BuiltinModuleKind.Node,
            "url"
        )
        registry.register(module)
    }

    private static func registerZlib(registry: BuiltinRegistry): Unit {
        let module = BuiltinModule(
            BuiltinModuleId.Id(9),
            "node:zlib",
            BuiltinModuleKind.Node,
            "zlib"
        )
        registry.register(module)
    }

    private static func registerNet(registry: BuiltinRegistry): Unit {
        let module = BuiltinModule(
            BuiltinModuleId.Id(10),
            "node:net",
            BuiltinModuleKind.Node,
            "net"
        )
        registry.register(module)
    }

    private static func registerDns(registry: BuiltinRegistry): Unit {
        let module = BuiltinModule(
            BuiltinModuleId.Id(11),
            "node:dns",
            BuiltinModuleKind.Node,
            "dns"
        )
        registry.register(module)
    }

    private static func registerChildProcess(registry: BuiltinRegistry): Unit {
        let module = BuiltinModule(
            BuiltinModuleId.Id(12),
            "node:child_process",
            BuiltinModuleKind.Node,
            "child_process"
        )
        registry.register(module)
    }

    private static func registerTls(registry: BuiltinRegistry): Unit {
        let module = BuiltinModule(
            BuiltinModuleId.Id(13),
            "node:tls",
            BuiltinModuleKind.Node,
            "tls"
        )
        registry.register(module)
    }

    private static func registerVm(registry: BuiltinRegistry): Unit {
        let module = BuiltinModule(
            BuiltinModuleId.Id(14),
            "node:vm",
            BuiltinModuleKind.Node,
            "vm"
        )
        registry.register(module)
    }

    private static func registerRemaining(registry: BuiltinRegistry): Unit {
        // 注册剩余模块:
        // assert, async_hooks, buffer, cluster, console, constants,
        // dgram, diagnostics_channel, domain, fs/promises, http2, https,
        // inspector, module, perf_hooks, punycode, querystring,
        // readline, repl, string_decoder, sys, timers, tty,
        // wasi, worker_threads, test, 等
        var nextId: Int32 = 15
        let remaining = ArrayList<String>()
        remaining.append("node:assert")
        remaining.append("node:async_hooks")
        remaining.append("node:buffer")
        remaining.append("node:child_process")
        remaining.append("node:cluster")
        remaining.append("node:console")
        remaining.append("node:dgram")
        remaining.append("node:diagnostics_channel")
        remaining.append("node:dns/promises")
        remaining.append("node:domain")
        remaining.append("node:fs/promises")
        remaining.append("node:http2")
        remaining.append("node:https")
        remaining.append("node:inspector")
        remaining.append("node:module")
        remaining.append("node:perf_hooks")
        remaining.append("node:punycode")
        remaining.append("node:querystring")
        remaining.append("node:readline")
        remaining.append("node:readline/promises")
        remaining.append("node:repl")
        remaining.append("node:stream/consumers")
        remaining.append("node:stream/promises")
        remaining.append("node:stream/web")
        remaining.append("node:string_decoder")
        remaining.append("node:timers")
        remaining.append("node:timers/promises")
        remaining.append("node:tty")
        remaining.append("node:wasi")
        remaining.append("node:worker_threads")
        remaining.append("node:test")
        remaining.append("node:v8")

        for (name in remaining) {
            let module = BuiltinModule(
                BuiltinModuleId.Id(nextId),
                name,
                BuiltinModuleKind.Node,
                name.substring(5) // 去掉 "node:" 前缀
            )
            registry.register(module)
            nextId++
        }
    }
}
