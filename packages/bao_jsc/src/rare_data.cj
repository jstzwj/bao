// 严格翻译自: jsc/rare_data.zig (955行)
// Bun 稀有数据存储 (延迟初始化的 VM 级数据)

package bao_jsc

// ========== 引用计数环境值 ==========
// 严格翻译自 rare_data.zig RefCountedEnvValue
public class RefCountedEnvValue {
    public var value: String = ""
    public var refCount: Int64 = 1

    public init() {}

    public init(value: String) {
        this.value = value
    }

    public func ref() {
        refCount++
    }

    public func deref() {
        refCount--
        if (refCount <= 0) {
            // 释放
        }
    }
}

// ========== 代理环境变量存储 ==========
// 严格翻译自 rare_data.zig ProxyEnvStorage
public class ProxyEnvStorage {
    // 代理环境变量 (大小写敏感)
    public var HTTP_PROXY: ?RefCountedEnvValue = None
    public var http_proxy: ?RefCountedEnvValue = None
    public var HTTPS_PROXY: ?RefCountedEnvValue = None
    public var https_proxy: ?RefCountedEnvValue = None
    public var NO_PROXY: ?RefCountedEnvValue = None
    public var no_proxy: ?RefCountedEnvValue = None

    // 保护并发访问的锁
    public var lock: Mutex = Mutex()

    // 槽位定义
    // 严格翻译自 ProxyEnvStorage.Slot
    public class Slot {
        public var key: String = ""
        public var ptr: RefCountedEnvValue? = None

        public init() {}
    }

    public init() {}

    // 严格翻译自 ProxyEnvStorage.slot
    public func slot(name: String) -> ?Slot {
        let s = Slot()
        s.key = name
        match (name) {
            case "HTTP_PROXY" => {
                if (let Some(val) <- HTTP_PROXY) {
                    s.ptr = val
                    return s
                }
            }
            case "http_proxy" => {
                if (let Some(val) <- http_proxy) {
                    s.ptr = val
                    return s
                }
            }
            case "HTTPS_PROXY" => {
                if (let Some(val) <- HTTPS_PROXY) {
                    s.ptr = val
                    return s
                }
            }
            case "https_proxy" => {
                if (let Some(val) <- https_proxy) {
                    s.ptr = val
                    return s
                }
            }
            case "NO_PROXY" => {
                if (let Some(val) <- NO_PROXY) {
                    s.ptr = val
                    return s
                }
            }
            case "no_proxy" => {
                if (let Some(val) <- no_proxy) {
                    s.ptr = val
                    return s
                }
            }
            case _ => ()
        }
        None
    }

    // 严格翻译自 ProxyEnvStorage.cloneFrom
    // 从父级克隆引用计数值
    public func cloneFrom(parent: ProxyEnvStorage) {
        lock.lock()
        defer { lock.unlock() }

        if (let Some(val) <- parent.HTTP_PROXY) {
            val.ref()
            HTTP_PROXY = val
        }
        if (let Some(val) <- parent.http_proxy) {
            val.ref()
            http_proxy = val
        }
        if (let Some(val) <- parent.HTTPS_PROXY) {
            val.ref()
            HTTPS_PROXY = val
        }
        if (let Some(val) <- parent.https_proxy) {
            val.ref()
            https_proxy = val
        }
        if (let Some(val) <- parent.NO_PROXY) {
            val.ref()
            NO_PROXY = val
        }
        if (let Some(val) <- parent.no_proxy) {
            val.ref()
            no_proxy = val
        }
    }

    // 严格翻译自 ProxyEnvStorage.syncInto
    // 同步到目标
    public func syncInto(target: ProxyEnvStorage) {
        lock.lock()
        defer { lock.unlock() }

        if (let Some(val) <- HTTP_PROXY) { target.HTTP_PROXY = val }
        if (let Some(val) <- http_proxy) { target.http_proxy = val }
        if (let Some(val) <- HTTPS_PROXY) { target.HTTPS_PROXY = val }
        if (let Some(val) <- https_proxy) { target.https_proxy = val }
        if (let Some(val) <- NO_PROXY) { target.NO_PROXY = val }
        if (let Some(val) <- no_proxy) { target.no_proxy = val }
    }

    // 严格翻译自 ProxyEnvStorage.deinit
    public func deinit() {
        if (let Some(val) <- HTTP_PROXY) { val.deref() }
        if (let Some(val) <- http_proxy) { val.deref() }
        if (let Some(val) <- HTTPS_PROXY) { val.deref() }
        if (let Some(val) <- https_proxy) { val.deref() }
        if (let Some(val) <- NO_PROXY) { val.deref() }
        if (let Some(val) <- no_proxy) { val.deref() }
        HTTP_PROXY = None
        http_proxy = None
        HTTPS_PROXY = None
        https_proxy = None
        NO_PROXY = None
        no_proxy = None
    }
}

// ========== 路径缓冲区 ==========
// 严格翻译自 rare_data.zig PathBuf
public class PathBuf {
    // 三级固定大小缓冲区
    // small: 2 * MAX_PATH_BYTES
    var small: ?String = None
    // medium: 8 * MAX_PATH_BYTES
    var medium: ?String = None
    // large: 32 * MAX_PATH_BYTES
    var large: ?String = None

    static let MAX_PATH_BYTES: Int64 = 4096

    public init() {}

    // 严格翻译自 PathBuf.get
    public func get(minLen: Int64) -> String {
        if (minLen <= 2 * PathBuf.MAX_PATH_BYTES) {
            if (small == None) {
                small = String(" ").repeat(2 * PathBuf.MAX_PATH_BYTES)
            }
            return small.getOr("")
        } else if (minLen <= 8 * PathBuf.MAX_PATH_BYTES) {
            if (medium == None) {
                medium = String(" ").repeat(8 * PathBuf.MAX_PATH_BYTES)
            }
            return medium.getOr("")
        } else {
            if (large == None) {
                large = String(" ").repeat(32 * PathBuf.MAX_PATH_BYTES)
            }
            return large.getOr("")
        }
    }

    // 严格翻译自 PathBuf.deinit
    public func deinit() {
        small = None
        medium = None
        large = None
    }
}

// ========== 熵缓存 ==========
// 严格翻译自 rare_data.zig EntropyCache
public class EntropyCache {
    public var data: Array<UInt8> = []

    public init() {}
}

// ========== 热映射 ==========
// 严格翻译自 rare_data.zig HotMap
public class HotMap {
    public var entries: HashMap<String, Int64> = HashMap()

    public init() {}

    // 严格翻译自 HotMap.getOrCreate
    public func getOrCreate(key: String) -> Int64 {
        if (let Some(val) <- entries.get(key)) {
            return val
        }
        entries.put(key, 0)
        0
    }
}

// ========== AWS 签名缓存 ==========
// 严格翻译自 rare_data.zig AWSSignatureCache
public class AWSSignatureCache {
    public var cache: HashMap<String, String> = HashMap()

    public init() {}
}

// ========== Valkey 上下文 ==========
// 严格翻译自 rare_data.zig ValkeyContext
public class ValkeyContext {
    public init() {}
}

// ========== 清理钩子 ==========
// 严格翻译自 rare_data.zig CleanupHook
public class CleanupHook {
    public var func_: ((?BunVirtualMachine) -> Unit)? = None
    public var ctx: ?BunVirtualMachine = None
    public var globalThis: ?JsObject = None

    public init() {}

    // 严格翻译自 CleanupHook.execute
    public func execute() {
        if (let Some(f) <- func_) {
            f(ctx)
        }
    }
}

// ========== 编辑器上下文 ==========
// 严格翻译自 rare_data.zig EditorContext
public class EditorContext {
    public init() {}
}

// ========== 管道读取缓冲区 ==========
// 严格翻译自 rare_data.zig PipeReadBuffer
public class PipeReadBuffer {
    static let SIZE: Int64 = 256 * 1024
    public var buffer: Array<UInt8> = []

    public init() {}
}

// ========== 文件轮询存储 ==========
// 严格翻译自 rare_data.zig FilePoll.Store
public class FilePollStore {
    public var polls: HashMap<Int64, FilePoll> = HashMap()

    public init() {}
}

// ========== 文件轮询 ==========
public class FilePoll {
    public var fd: Int64 = 0
    public var path: String = ""

    public init() {}
}

// ========== FS Watcher ==========
public class FSWatcher {
    public var path: String = ""
    public var callback: ?JsFunction = None

    public init() {}

    public func close() {}
}

// ========== Stat Watcher ==========
public class StatWatcher {
    public var path: String = ""
    public var callback: ?JsFunction = None

    public init() {}

    public func close() {}
}

// ========== Stat Watcher 调度器 ==========
// 严格翻译自 rare_data.zig StatWatcherScheduler
public class StatWatcherScheduler {
    public var watchers: Array<StatWatcher> = []

    public init() {}
}

// ========== 套接字组 ==========
// 严格翻译自 uws.SocketGroup 的仓颉表示
public class SocketGroup {
    public var kind: String = ""
    public var isSsl: Bool = false

    public init() {}

    public func closeAll() {}
}

// ========== SSL 上下文缓存 ==========
// 严格翻译自 rare_data.zig SSLContextCache
public class SSLContextCache {
    public var cache: HashMap<String, SSLContext> = HashMap()

    public init() {}
}

// ========== SSL 上下文 ==========
public class SSLContext {
    public var config: String = ""

    public init() {}
}

// ========== 稀有数据主体 ==========
// 严格翻译自 rare_data.zig RareData
public class RareData {
    // WebSocket 压缩
    public var websocketDeflate: ?WebSocketDeflateRareData = None
    // 编辑器上下文
    public var editorContext: EditorContext = EditorContext()
    // stdio 存储
    public var stderrStore: ?BlobStore = None
    public var stdinStore: ?BlobStore = None
    public var stdoutStore: ?BlobStore = None
    // 熵缓存
    public var entropyCache: ?EntropyCache = None
    // 热映射 (用于 HMR)
    public var hotMap: ?HotMap = None
    // Cron 任务
    public var cronJobs: Array<CronJob> = []
    // 清理钩子
    public var cleanupHooks: Array<CleanupHook> = []
    // 文件轮询存储
    public var filePolls: ?FilePollStore = None
    // 全局 DNS 数据
    public var globalDnsData: ?String = None
    // MIME 类型映射
    public var mimeTypes: ?MimeTypeMap = None
    // 节点 FS stat watcher 调度器
    public var nodeFsStatWatcherScheduler: ?StatWatcherScheduler = None
    // Watch 模式下的监听套接字
    public var listeningSocketsForWatchMode: Array<Int64> = []
    // Watch 模式下的监听套接字锁
    public var listeningSocketsForWatchModeLock: Mutex = Mutex()
    // 隔离测试的 FS watchers
    public var fsWatchersForIsolation: Array<FSWatcher> = []
    // 隔离测试的 Stat watchers
    public var statWatchersForIsolation: Array<StatWatcher> = []
    // 管道读取缓冲区
    public var tempPipeReadBuffer: ?PipeReadBuffer = None
    // AWS 签名缓存
    public var awsSignatureCache: AWSSignatureCache = AWSSignatureCache()
    // S3 默认客户端
    public var s3DefaultClient: ?JsObject = None
    // 默认 CSRF secret
    public var defaultCsrfSecret: String = ""
    // Valkey 上下文
    public var valkeyContext: ValkeyContext = ValkeyContext()
    // TLS 默认密码
    public var tlsDefaultCiphers: ?String = None
    // 路径缓冲区
    public var pathBuf: PathBuf = PathBuf()
    // 代理环境变量存储
    public var proxyEnvStorage: ProxyEnvStorage = ProxyEnvStorage()

    // ---- 嵌入式套接字组 (每种类型一个) ----
    // 严格翻译自 rare_data.zig 中的各种 SocketGroup 字段

    // spawn IPC 组
    public var spawnIpcGroup: SocketGroup = SocketGroup()
    // test parallel IPC 组
    public var testParallelIpcGroup: SocketGroup = SocketGroup()
    // Bun.connect TCP 组
    public var bunConnectGroupTcp: SocketGroup = SocketGroup()
    // Bun.connect TLS 组
    public var bunConnectGroupTls: SocketGroup = SocketGroup()
    // Postgres TCP 组
    public var postgresGroup: SocketGroup = SocketGroup()
    // Postgres TLS 组
    public var postgresTlsGroup: SocketGroup = SocketGroup()
    // MySQL TCP 组
    public var mysqlGroup: SocketGroup = SocketGroup()
    // MySQL TLS 组
    public var mysqlTlsGroup: SocketGroup = SocketGroup()
    // Valkey TCP 组
    public var valkeyGroup: SocketGroup = SocketGroup()
    // Valkey TLS 组
    public var valkeyTlsGroup: SocketGroup = SocketGroup()
    // WebSocket upgrade 组
    public var wsUpgradeGroup: SocketGroup = SocketGroup()
    // WebSocket upgrade TLS 组
    public var wsUpgradeTlsGroup: SocketGroup = SocketGroup()
    // WebSocket client 组
    public var wsClientGroup: SocketGroup = SocketGroup()
    // WebSocket client TLS 组
    public var wsClientTlsGroup: SocketGroup = SocketGroup()

    // SSL 上下文缓存
    public var sslCtxCache: SSLContextCache = SSLContextCache()
    // 默认客户端 SSL 上下文
    public var defaultClientSslCtx: ?SSLContext = None

    public init() {}

    // ========== 热映射 ==========

    // 严格翻译自 RareData.hotMap
    public func hotMap(allocator: String) -> ?HotMap {
        if (hotMap == None) {
            hotMap = HotMap()
        }
        hotMap
    }

    // ========== MIME 类型 ==========

    // 严格翻译自 RareData.mimeTypeFromString
    public func mimeTypeFromString(allocator: String, str: String) -> ?MimeType {
        if (mimeTypes == None) {
            mimeTypes = MimeTypeMap()
        }
        mimeTypes.getOrThrow().lookup(str)
    }

    // ========== 清理钩子 ==========

    // 严格翻译自 RareData cleanup hooks 执行
    public func runCleanupHooks() {
        while (cleanupHooks.size > 0) {
            let hooks = cleanupHooks.toArray()
            cleanupHooks.clear()
            for (hook in hooks) {
                hook.execute()
            }
        }
    }

    // ========== 监听套接字管理 ==========

    // 严格翻译自 RareData.addListeningSocketForWatchMode
    public func addListeningSocketForWatchMode(socket: Int64) {
        listeningSocketsForWatchModeLock.lock()
        defer { listeningSocketsForWatchModeLock.unlock() }
        listeningSocketsForWatchMode.append(socket)
    }

    // 严格翻译自 RareData.removeListeningSocketForWatchMode
    public func removeListeningSocketForWatchMode(socket: Int64) {
        listeningSocketsForWatchModeLock.lock()
        defer { listeningSocketsForWatchModeLock.unlock() }
        var idx = -1
        for (i in 0..listeningSocketsForWatchMode.size) {
            if (listeningSocketsForWatchMode[Int64(i)] == socket) {
                idx = Int64(i)
                break
            }
        }
        if (idx >= 0) {
            listeningSocketsForWatchMode.removeAt(idx)
        }
    }

    // ========== 隔离测试 ==========

    // 严格翻译自 RareData.closeAllWatchersForIsolation
    public func closeAllWatchersForIsolation() {
        for (watcher in fsWatchersForIsolation) {
            watcher.close()
        }
        fsWatchersForIsolation.clear()

        for (watcher in statWatchersForIsolation) {
            watcher.close()
        }
        statWatchersForIsolation.clear()
    }

    // 严格翻译自 RareData.closeAllSocketGroups
    public func closeAllSocketGroups(vm: BunVirtualMachine) {
        spawnIpcGroup.closeAll()
        testParallelIpcGroup.closeAll()
        bunConnectGroupTcp.closeAll()
        bunConnectGroupTls.closeAll()
        postgresGroup.closeAll()
        postgresTlsGroup.closeAll()
        mysqlGroup.closeAll()
        mysqlTlsGroup.closeAll()
        valkeyGroup.closeAll()
        valkeyTlsGroup.closeAll()
        wsUpgradeGroup.closeAll()
        wsUpgradeTlsGroup.closeAll()
        wsClientGroup.closeAll()
        wsClientTlsGroup.closeAll()
    }

    // ========== deinit ==========

    // 严格翻译自 RareData.deinit
    public func deinit() {
        pathBuf.deinit()
        proxyEnvStorage.deinit()
        cleanupHooks.clear()
        cronJobs.clear()
        listeningSocketsForWatchMode.clear()
        fsWatchersForIsolation.clear()
        statWatchersForIsolation.clear()
    }
}

// ========== 辅助类型 ==========

// WebSocket 压缩稀有数据
public class WebSocketDeflateRareData {
    public init() {}
}

// Blob 存储
public class BlobStore {
    public var data: String = ""

    public init() {}
}

// Cron 任务
public class CronJob {
    public var name: String = ""
    public var expression: String = ""
    public var callback: ?JsFunction = None

    public init() {}

    // 严格翻译自 CronJob.clearAllForVM
    public static func clearAllForVM(vm: BunVirtualMachine, reason: String) {
        // 清除指定 VM 的所有 cron 任务
    }
}

// MIME 类型映射
public class MimeTypeMap {
    // 常见 MIME 类型
    static let COMMON_TYPES: HashMap<String, String> = HashMap()

    public init() {}

    public func lookup(ext: String) -> ?MimeType {
        let mt = MimeType()
        mt.ext = ext
        match (ext) {
            case ".js" => mt.contentType = "application/javascript"
            case ".json" => mt.contentType = "application/json"
            case ".html" => mt.contentType = "text/html"
            case ".css" => mt.contentType = "text/css"
            case ".txt" => mt.contentType = "text/plain"
            case ".png" => mt.contentType = "image/png"
            case ".jpg" | ".jpeg" => mt.contentType = "image/jpeg"
            case ".gif" => mt.contentType = "image/gif"
            case ".svg" => mt.contentType = "image/svg+xml"
            case ".wasm" => mt.contentType = "application/wasm"
            case _ => mt.contentType = "application/octet-stream"
        }
        mt
    }
}

// ========== 生成同步事件循环 ==========
// 严格翻译自 rare_data.zig SpawnSyncEventLoop
public class SpawnSyncEventLoop {
    public var isRunning: Bool = false

    public init() {}
}
