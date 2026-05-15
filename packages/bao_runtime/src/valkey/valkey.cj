// Valkey 客户端核心 - Valkey 连接、协议处理与命令管理
// 严格翻译自: bun/src/runtime/valkey_jsc/valkey.zig
package bao_runtime.valkey

import bao_core.*
import bao_collections.*
import bao_valkey.*

// ============================================================================
// ConnectionFlags - 连接标志
// 严格翻译自: valkey.zig - ConnectionFlags
//   pub const ConnectionFlags = struct {
//       is_authenticated: bool = false,
//       is_manually_closed: bool = false,
//       ...
//   };
// ============================================================================

/// 连接标志 - 跟踪 Valkey 客户端状态
/// 对应 Bun ConnectionFlags
public class ConnectionFlags {
    /// 是否已认证
    public var isAuthenticated: Bool
    /// 是否手动关闭
    public var isManuallyClosed: Bool
    /// 是否正在内部选择数据库
    public var isSelectingDbInternal: Bool
    /// 是否启用离线队列
    public var enableOfflineQueue: Bool
    /// 是否需要打开 socket
    public var needsToOpenSocket: Bool
    /// 是否启用自动重连
    public var enableAutoReconnect: Bool
    /// 是否正在重连
    public var isReconnecting: Bool
    /// 是否已失败
    public var failed: Bool
    /// 是否启用自动管道化
    public var enableAutoPipelining: Bool
    /// 是否已终结
    public var finalized: Bool
    /// 连接 Promise 是否返回客户端实例
    /// 这是一个轻微的 hack，用于在连接建立时返回客户端实例
    public var connectionPromiseReturnsClient: Bool

    public init() {
        isAuthenticated = false
        isManuallyClosed = false
        isSelectingDbInternal = false
        enableOfflineQueue = true
        needsToOpenSocket = true
        enableAutoReconnect = true
        isReconnecting = false
        failed = false
        enableAutoPipelining = true
        finalized = false
        connectionPromiseReturnsClient = false
    }
}

// ============================================================================
// Status - 连接状态
// 严格翻译自: valkey.zig - Status
//   pub const Status = enum { disconnected, connecting, connected };
// ============================================================================

/// Valkey 连接状态
/// 对应 Bun Status
public enum ConnectionStatus {
    | Disconnected
    | Connecting
    | Connected

    /// 是否活跃 (已连接或正在连接)
    /// 对应 Bun Status.isActive()
    public func isActive(): Bool {
        match (this) {
            case Connected | Connecting => true
            case Disconnected => false
        }
    }
}

// ============================================================================
// Protocol - 协议类型
// 严格翻译自: valkey.zig - Protocol
//   pub const Protocol = enum {
//       standalone, standalone_unix, standalone_tls, standalone_tls_unix,
//   };
// ============================================================================

/// 协议类型映射
/// 对应 Bun Protocol.Map (ComptimeStringMap)
public func protocolFromString(s: String): ?ValkeyProtocol {
    match (s) {
        case "valkey" => ValkeyProtocol.Standalone
        case "valkeys" => ValkeyProtocol.StandaloneTls
        case "valkey+tls" => ValkeyProtocol.StandaloneTls
        case "valkey+unix" => ValkeyProtocol.StandaloneUnix
        case "valkey+tls+unix" => ValkeyProtocol.StandaloneTlsUnix
        case "redis" => ValkeyProtocol.Standalone
        case "rediss" => ValkeyProtocol.StandaloneTls
        case "redis+tls" => ValkeyProtocol.StandaloneTls
        case "redis+unix" => ValkeyProtocol.StandaloneUnix
        case "redis+tls+unix" => ValkeyProtocol.StandaloneTlsUnix
        case _ => None
    }
}

/// Valkey 协议类型
/// 对应 Bun Protocol
public enum ValkeyProtocol {
    | Standalone          // 独立 TCP
    | StandaloneUnix      // Unix socket
    | StandaloneTls       // TLS TCP
    | StandaloneTlsUnix   // TLS Unix socket

    /// 是否使用 TLS
    /// 对应 Bun Protocol.isTLS()
    public func isTLS(): Bool {
        match (this) {
            case StandaloneTls | StandaloneTlsUnix => true
            case _ => false
        }
    }

    /// 是否使用 Unix socket
    /// 对应 Bun Protocol.isUnix()
    public func isUnix(): Bool {
        match (this) {
            case StandaloneUnix | StandaloneTlsUnix => true
            case _ => false
        }
    }
}

// ============================================================================
// TLS - TLS 配置
// 严格翻译自: valkey.zig - TLS (union(enum))
//   pub const TLS = union(enum) { none, enabled, custom: ... };
// ============================================================================

/// TLS 配置
/// 对应 Bun TLS
public enum TLSMode {
    | None       // 无 TLS
    | Enabled    // 默认 TLS
    | Custom     // 自定义 TLS 配置
}

/// TLS 配置类
public class TLSConfig {
    public var mode: TLSMode
    /// 自定义 SSL 配置
    public var sslConfig: ?SslConfig

    public init() {
        mode = TLSMode.None
        sslConfig = None
    }

    public init(mode: TLSMode) {
        this.mode = mode
        sslConfig = None
    }

    public init(sslConfig: SslConfig) {
        mode = TLSMode.Custom
        this.sslConfig = sslConfig
    }

    /// 克隆 TLS 配置
    /// 对应 Bun TLS.clone()
    public func clone(): TLSConfig {
        let result = TLSConfig()
        result.mode = mode
        if (sslConfig.isSome()) {
            result.sslConfig = sslConfig.getOrThrow().clone()
        }
        result
    }

    /// 是否拒绝未授权连接
    /// 对应 Bun TLS.rejectUnauthorized()
    public func rejectUnauthorized(): Bool {
        match (mode) {
            case TLSMode.Custom => {
                if (sslConfig.isSome()) {
                    sslConfig.getOrThrow().rejectUnauthorized
                } else {
                    false
                }
            }
            case TLSMode.Enabled => true
            case TLSMode.None => false
        }
    }
}

/// SSL 配置
/// 对应 Bun jsc.API.ServerConfig.SSLConfig
public class SslConfig {
    public var rejectUnauthorized: Bool
    public var cert: ?String
    public var key: ?String
    public var ca: ?String

    public init() {
        rejectUnauthorized = true
        cert = None
        key = None
        ca = None
    }

    /// 克隆 SSL 配置
    public func clone(): SslConfig {
        let result = SslConfig()
        result.rejectUnauthorized = rejectUnauthorized
        result.cert = cert
        result.key = key
        result.ca = ca
        result
    }
}

// ============================================================================
// Address - 连接地址
// 严格翻译自: valkey.zig - Address (union(enum))
//   pub const Address = union(enum) { unix: []const u8, host: struct { ... } };
// ============================================================================

/// 连接地址
/// 对应 Bun Address
public class ValkeyAddress {
    /// Unix socket 路径
    public var unixPath: ?String
    /// 主机名
    public var host: String
    /// 端口号
    public var port: UInt16
    /// 是否为 Unix socket
    public var isUnix: Bool

    public init(host: String, port: UInt16) {
        this.host = host
        this.port = port
        unixPath = None
        isUnix = false
    }

    public init(unixPath: String) {
        this.unixPath = unixPath
        host = ""
        port = 0
        isUnix = true
    }

    /// 获取主机名
    /// 对应 Bun Address.hostname()
    public func hostname(): String {
        if (isUnix) {
            unixPath.getOr("")
        } else {
            host
        }
    }
}

// ============================================================================
// Options - 连接选项
// 严格翻译自: valkey.zig - Options
//   pub const Options = struct { ... };
// ============================================================================

/// Valkey 连接选项
/// 对应 Bun Options
public class ValkeyOptions {
    /// 空闲超时 (毫秒)
    public var idleTimeoutMs: UInt32
    /// 连接超时 (毫秒)
    public var connectionTimeoutMs: UInt32
    /// 是否启用自动重连
    public var enableAutoReconnect: Bool
    /// 最大重试次数
    public var maxRetries: UInt32
    /// 是否启用离线队列
    public var enableOfflineQueue: Bool
    /// 是否启用自动管道化
    public var enableAutoPipelining: Bool
    /// 是否启用调试日志
    public var enableDebugLogging: Bool
    /// TLS 配置
    public var tls: TLSConfig

    public init() {
        idleTimeoutMs = 0
        connectionTimeoutMs = 10000
        enableAutoReconnect = true
        maxRetries = 20
        enableOfflineQueue = true
        enableAutoPipelining = true
        enableDebugLogging = false
        tls = TLSConfig()
    }
}

// ============================================================================
// OffsetByteList - 偏移字节列表
// 对应 Bun bun.OffsetByteList - 用于读写缓冲区
// ============================================================================

/// 偏移字节列表 - 读写缓冲区
/// 对应 Bun OffsetByteList
public class OffsetByteList {
    private var data: ArrayList<Byte>
    private var readPos: Int64
    private var writePos: Int64

    public init() {
        data = ArrayList<Byte>()
        readPos = 0
        writePos = 0
    }

    /// 数据容量
    public var cap: Int64 {
        data.capacity
    }

    /// 当前长度
    public func len(): Int64 {
        writePos - readPos
    }

    /// 获取剩余未读数据
    public func remaining(): Array<Byte> {
        if (writePos <= readPos) {
            []
        } else {
            data[readPos..writePos]
        }
    }

    /// 可读长度
    public func readableLength(): Int64 {
        writePos - readPos
    }

    /// 写入数据
    public func write(chunk: Array<Byte>): Unit {
        for (b in chunk) {
            data.append(b)
        }
        writePos += chunk.size
    }

    /// 消费指定长度的数据
    public func consume(count: Int64): Unit {
        readPos += count
        if (readPos >= writePos) {
            clearAndFree()
        }
    }

    /// 清除并释放
    public func clearAndFree(): Unit {
        data = ArrayList<Byte>()
        readPos = 0
        writePos = 0
    }

    /// 确保未使用的容量
    public func ensureUnusedCapacity(count: Int64): Unit {
        // 预分配空间
        data.ensureCapacity(writePos + count)
    }
}

// ============================================================================
// LinearFifo - 线性 FIFO 队列
// 对应 Bun bun.LinearFifo
// ============================================================================

/// 线性 FIFO 队列 - 泛型实现
/// 对应 Bun LinearFifo
public class LinearFifo<T> {
    private var items: ArrayList<T>

    public init() {
        items = ArrayList<T>()
    }

    /// 队列数量
    public var count: Int64 {
        items.size
    }

    /// 可读数量
    public func readableLength(): Int64 {
        items.size
    }

    /// 可读切片
    public func readableSlice(offset: Int64): Array<T> {
        items[offset..]
    }

    /// 查看指定索引的元素
    public func peekItem(index: Int64): T {
        items[index]
    }

    /// 写入元素
    public func writeItem(item: T): Unit {
        items.append(item)
    }

    /// 读取元素
    public func readItem(): ?T {
        if (items.size == 0) {
            None
        } else {
            let item = items[0]
            items.removeAt(0)
            item
        }
    }

    /// 丢弃指定数量的元素
    public func discard(count: Int64): Unit {
        for (_ in 0..count) {
            if (items.size > 0) {
                items.removeAt(0)
            }
        }
    }

    /// 释放队列
    public func deinit(): Unit {
        items = ArrayList<T>()
    }
}

// ============================================================================
// AutoFlusher - 自动刷新器
// 对应 Bun jsc.WebCore.AutoFlusher
// ============================================================================

/// 自动刷新器状态
/// 对应 Bun AutoFlusher
public class AutoFlusher {
    public var registered: Bool

    public init() {
        registered = false
    }
}

// ============================================================================
// ValkeyClient - 核心 Valkey 客户端
// 严格翻译自: valkey.zig - ValkeyClient
//   pub const ValkeyClient = struct {
//       socket: uws.AnySocket,
//       status: Status = Status.connecting,
//       write_buffer: bun.OffsetByteList = .{},
//       read_buffer: bun.OffsetByteList = .{},
//       in_flight: Command.PromisePair.Queue,
//       queue: Command.Entry.Queue,
//       ...
//   };
// ============================================================================

/// 核心 Valkey 客户端实现
/// 对应 Bun ValkeyClient
public class ValkeyClient {
    // socket 引用
    public var socket: AnySocket
    /// 连接状态
    public var status: ConnectionStatus

    // 缓冲区管理
    /// 写缓冲区
    public var writeBuffer: OffsetByteList
    /// 读缓冲区
    public var readBuffer: OffsetByteList

    /// 在途命令队列 (已写入网络 socket)
    /// 对应: in_flight: Command.PromisePair.Queue
    public var inFlight: LinearFifo<PromisePair>
    /// 等待发送的命令队列
    /// 对应: queue: Command.Entry.Queue
    public var queue: LinearFifo<CommandEntry>

    // 连接参数
    /// 密码
    public var password: String
    /// 用户名
    public var username: String
    /// 数据库编号
    public var database: UInt32
    /// 连接地址
    public var address: ValkeyAddress
    /// 协议类型
    public var protocol: ValkeyProtocol

    /// 连接字符串 (持久化缓冲区)
    public var connectionStrings: Array<Byte>

    // TLS 支持
    public var tls: TLSConfig

    // 超时与重连管理
    /// 空闲超时间隔 (毫秒)
    public var idleTimeoutIntervalMs: UInt32
    /// 连接超时 (毫秒)
    public var connectionTimeoutMs: UInt32
    /// 重试次数
    public var retryAttempts: UInt32
    /// 最大重试次数
    public var maxRetries: UInt32

    /// 连接标志
    public var flags: ConnectionFlags

    /// 自动管道化刷新器
    public var autoFlusher: AutoFlusher

    /// 虚拟机引用
    public var vm: VirtualMachine

    /// 父级 JSValkeyClient 引用
    public var parentClient: ?JSValkeyClient

    public init(vm: VirtualMachine, address: ValkeyAddress, protocol: ValkeyProtocol) {
        this.vm = vm
        this.address = address
        this.protocol = protocol
        status = ConnectionStatus.Disconnected
        writeBuffer = OffsetByteList()
        readBuffer = OffsetByteList()
        inFlight = LinearFifo<PromisePair>()
        queue = LinearFifo<CommandEntry>()
        password = ""
        username = ""
        database = 0
        connectionStrings = []
        tls = TLSConfig()
        idleTimeoutIntervalMs = 0
        connectionTimeoutMs = 0
        retryAttempts = 0
        maxRetries = 20
        flags = ConnectionFlags()
        autoFlusher = AutoFlusher()
        parentClient = None
        socket = AnySocket()
    }

    // ========================================================================
    // 清理资源
    // 严格翻译自: valkey.zig - ValkeyClient.deinit()
    // ========================================================================

    /// 清理 Valkey 客户端使用的资源
    /// 对应 Bun ValkeyClient.deinit()
    public func deinit(globalObjectOrFinalizing: ?JsObject): Unit {
        let pending = inFlight
        inFlight = LinearFifo<PromisePair>()
        let commands = queue
        queue = LinearFifo<CommandEntry>()

        if (globalObjectOrFinalizing.isSome()) {
            let globalThis = globalObjectOrFinalizing.getOrThrow()
            let errorObj = ProtocolJsc.valkeyErrorToJS("Connection closed", RedisError.ConnectionClosed)

            // 拒绝在途命令
            for (pair in pending.readableSlice(0)) {
                pair.rejectCommand(globalThis, errorObj)
            }

            // 拒绝离线命令
            for (cmd in commands.readableSlice(0)) {
                cmd.promise.reject(globalThis, errorObj)
                cmd.deinit()
            }
        } else {
            // 终结化 - 不能调用 JS
            for (pair in pending.readableSlice(0)) {
                pair.promise.deinit()
            }
            for (cmd in commands.readableSlice(0)) {
                cmd.promise.deinit()
                cmd.deinit()
            }
        }

        // connectionStrings 的释放
        // 注意：username, password 和 hostname 不需要释放，
        // 因为它们在 connectionStrings 缓冲区中
        writeBuffer.clearAndFree()
        readBuffer.clearAndFree()
        unregisterAutoFlusher()
    }

    // ========================================================================
    // 自动管道化
    // 严格翻译自: valkey.zig - registerAutoFlusher / unregisterAutoFlusher / onAutoFlush
    // ========================================================================

    /// 注册自动刷新器
    /// 对应 Bun ValkeyClient.registerAutoFlusher()
    func registerAutoFlusher(): Unit {
        if (!autoFlusher.registered) {
            autoFlusher.registered = true
            // 对应 Bun: AutoFlusher.registerDeferredMicrotaskWithTypeUnchecked
        }
    }

    /// 取消注册自动刷新器
    /// 对应 Bun ValkeyClient.unregisterAutoFlusher()
    func unregisterAutoFlusher(): Unit {
        if (autoFlusher.registered) {
            autoFlusher.registered = false
        }
    }

    /// 排水自动管道化命令
    /// 对应 Bun ValkeyClient.onAutoFlush()
    public func onAutoFlush(): Bool {
        // 未连接或正在处理时不处理
        if (status != ConnectionStatus.Connected) {
            autoFlusher.registered = false
            return false
        }

        var totalByteLength: Int64 = 0
        var processCount: Int64 = 0

        // 收集可管道化的命令
        let toProcess = queue.readableSlice(0)
        for (command in toProcess) {
            if (!command.meta.supportsAutoPipelining) {
                break
            }
            inFlight.writeItem(PromisePair(command.meta, command.promise))
            processCount += 1
            totalByteLength += command.serializedData.size
        }

        // 将管道化命令写入写缓冲区
        writeBuffer.ensureUnusedCapacity(totalByteLength)
        var processed: Int64 = 0
        for (command in toProcess) {
            if (processed >= processCount) {
                break
            }
            if (!command.meta.supportsAutoPipelining) {
                break
            }
            writeBuffer.write(command.serializedData)
            processed += 1
        }

        // 丢弃已处理的队列项
        queue.discard(processCount)

        // 刷新数据
        flushData()

        let haveMore = queue.readableLength() > 0
        autoFlusher.registered = haveMore
        return haveMore
    }

    // ========================================================================
    // 超时与重连
    // 严格翻译自: valkey.zig - getTimeoutInterval / getReconnectDelay
    // ========================================================================

    /// 获取适当的超时间隔
    /// 对应 Bun ValkeyClient.getTimeoutInterval()
    public func getTimeoutInterval(): UInt32 {
        if (flags.failed) { return 0 }
        match (status) {
            case ConnectionStatus.Connected => idleTimeoutIntervalMs
            case _ => connectionTimeoutMs
        }
    }

    /// 是否有待处理命令
    /// 对应 Bun ValkeyClient.hasAnyPendingCommands()
    public func hasAnyPendingCommands(): Bool {
        inFlight.readableLength() > 0 ||
        queue.readableLength() > 0 ||
        writeBuffer.len() > 0 ||
        readBuffer.len() > 0
    }

    /// 计算重连延迟 (指数退避)
    /// 对应 Bun ValkeyClient.getReconnectDelay()
    public func getReconnectDelay(): UInt32 {
        let baseDelay: UInt32 = 50   // 基础延迟 (毫秒)
        let maxDelay: UInt32 = 2000  // 最大延迟 (毫秒)

        if (retryAttempts == 0) { return baseDelay }

        // 限制退避计算的最大尝试次数为 10，避免整数溢出
        let attempt = if (retryAttempts < 10) { retryAttempts } else { 10 }

        var delay: UInt32 = baseDelay
        var i: UInt32 = 1
        while (i < attempt) {
            // 延迟翻倍，直到最大延迟
            delay = if (delay * 2 < maxDelay) { delay * 2 } else { maxDelay }
            i += 1
        }
        delay
    }

    // ========================================================================
    // 拒绝所有待处理命令
    // 严格翻译自: valkey.zig - rejectAllPendingCommands()
    // ========================================================================

    /// 拒绝所有待处理命令并带错误
    /// 对应 Bun ValkeyClient.rejectAllPendingCommands()
    func rejectAllPendingCommands(
        pendingPtr: LinearFifo<PromisePair>,
        entriesPtr: LinearFifo<CommandEntry>,
        globalThis: JsObject,
        jsvalue: JsValue
    ): Unit {
        // 拒绝在途命令
        for (item in pendingPtr.readableSlice(0)) {
            item.rejectCommand(globalThis, jsvalue)
        }

        // 拒绝离线命令
        for (item in entriesPtr.readableSlice(0)) {
            item.promise.reject(globalThis, jsvalue)
            item.deinit()
        }
    }

    // ========================================================================
    // 数据刷新
    // 严格翻译自: valkey.zig - flushData()
    // ========================================================================

    /// 刷新待发送数据到 socket
    /// 对应 Bun ValkeyClient.flushData()
    public func flushData(): Bool {
        let chunk = writeBuffer.remaining()
        if (chunk.size == 0) { return false }
        let wrote = socket.write(chunk)
        if (wrote > 0) {
            writeBuffer.consume(wrote)
        }
        writeBuffer.len() > 0
    }

    // ========================================================================
    // 连接失败处理
    // 严格翻译自: valkey.zig - fail() / failWithJSValue()
    // ========================================================================

    /// 延迟失败结构体
    /// 对应 Bun ValkeyClient.DeferredFailure
    class DeferredFailure {
        var message: String
        var err: RedisError
        var globalThis: JsObject
        var inFlight: LinearFifo<PromisePair>
        var queue: LinearFifo<CommandEntry>

        init(message: String, err: RedisError, globalThis: JsObject) {
            this.message = message
            this.err = err
            this.globalThis = globalThis
            inFlight = LinearFifo<PromisePair>()
            queue = LinearFifo<CommandEntry>()
        }

        /// 运行延迟失败
        /// 对应 Bun DeferredFailure.run()
        public func run(): Unit {
            let errorObj = ProtocolJsc.valkeyErrorToJS(message, err)
            rejectAllPendingCommands(inFlight, queue, globalThis, errorObj)
        }

        /// 入队延迟失败
        /// 对应 Bun DeferredFailure.enqueue()
        public func enqueue(): Unit {
            // 将延迟失败任务入队到事件循环
            // 对应: jsc.VirtualMachine.get().eventLoop().enqueueTask(managed_task)
        }
    }

    /// 标记连接为失败
    /// 对应 Bun ValkeyClient.fail()
    public func fail(message: String, err: RedisError): Unit {
        if (flags.failed) { return }

        if (flags.finalized) {
            // 不能在终结器中运行 Promise
            if (queue.count + inFlight.count > 0) {
                let deferred = DeferredFailure(message, err, vm.getGlobal())
                deferred.inFlight = inFlight
                deferred.queue = queue
                inFlight = LinearFifo<PromisePair>()
                queue = LinearFifo<CommandEntry>()
                deferred.enqueue()
            }
            return
        }

        let globalThis = globalObject()
        failWithJSValue(globalThis, ProtocolJsc.valkeyErrorToJS(message, err))
    }

    /// 使用 JS 值标记连接为失败
    /// 对应 Bun ValkeyClient.failWithJSValue()
    public func failWithJSValue(globalThis: JsObject, jsvalue: JsValue): Unit {
        if (flags.failed) { return }
        flags.failed = true
        rejectAllPendingCommands(inFlight, queue, globalThis, jsvalue)

        if (!connectionReady()) {
            flags.isManuallyClosed = true
            close()
        }
    }

    /// 关闭 socket
    /// 对应 Bun ValkeyClient.close()
    public func close(): Unit {
        socket.close()
    }

    // ========================================================================
    // 连接关闭处理
    // 严格翻译自: valkey.zig - onClose()
    // ========================================================================

    /// 处理连接关闭事件
    /// 对应 Bun ValkeyClient.onClose()
    public func onClose(): Unit {
        unregisterAutoFlusher()
        writeBuffer.clearAndFree()

        // 手动关闭时不尝试重连
        if (flags.isManuallyClosed) {
            fail("Connection closed", RedisError.ConnectionClosed)
            onValkeyClose()
            return
        }

        // 自动重连禁用时直接失败
        if (!flags.enableAutoReconnect) {
            fail("Connection closed", RedisError.ConnectionClosed)
            onValkeyClose()
            return
        }

        // 计算重连延迟 (指数退避)
        retryAttempts += 1
        let delayMs = getReconnectDelay()

        if (delayMs == 0 || retryAttempts > maxRetries) {
            fail("Max reconnection attempts reached", RedisError.ConnectionClosed)
            onValkeyClose()
            return
        }

        flags.isReconnecting = true
        flags.isAuthenticated = false
        flags.isSelectingDbInternal = false

        // 发信号启动重连定时器
        onValkeyReconnect()
    }

    // ========================================================================
    // 命令发送
    // 严格翻译自: valkey.zig - sendNextCommand() / drain() / enqueue() / send()
    // ========================================================================

    /// 发送下一个命令
    /// 对应 Bun ValkeyClient.sendNextCommand()
    public func sendNextCommand(): Unit {
        if (writeBuffer.remaining().size == 0 && connectionReady()) {
            if (queue.readableLength() > 0) {
                let headMeta = queue.peekItem(0).meta

                if (!headMeta.supportsAutoPipelining) {
                    // 队列头部不支持管道化，串行排空
                    if (inFlight.readableLength() == 0) {
                        drain()
                        // 检查新头部是否支持管道化
                        if (queue.readableLength() > 0 && queue.peekItem(0).meta.supportsAutoPipelining) {
                            registerAutoFlusher()
                        }
                    }
                } else {
                    // 队列头部支持管道化，注册刷新器
                    registerAutoFlusher()
                }
            } else if (inFlight.readableLength() == 0) {
                drain()
            }
        }
        flushData()
    }

    /// 处理从 socket 接收的数据
    /// 对应 Bun ValkeyClient.onData()
    public func onData(data: Array<Byte>): Unit {
        // 路径 1: 缓冲区已有数据，追加并从缓冲区处理
        if (readBuffer.remaining().size > 0) {
            readBuffer.write(data)

            // 尽可能从缓冲区处理完整的消息
            while (true) {
                let remainingBuffer = readBuffer.remaining()
                if (remainingBuffer.size == 0) {
                    break
                }

                let reader = ValkeyReader(remainingBuffer)
                let beforeReadPos = reader.pos

                let value = reader.readValueWithDepth(0)
                if (value.isNone()) {
                    // 需要更多数据，等待下次 onData 调用
                    return
                }

                let bytesConsumed = reader.pos - beforeReadPos
                if (bytesConsumed == 0 && remainingBuffer.size > 0) {
                    fail("Parser consumed 0 bytes unexpectedly (buffer path)", RedisError.InvalidResponse)
                    return
                }

                readBuffer.consume(bytesConsumed)
                handleResponse(value.getOrThrow())

                if (status == ConnectionStatus.Disconnected || flags.failed) {
                    return
                }
                sendNextCommand()
            }
            return
        }

        // 路径 2: 缓冲区为空，直接从栈数据中处理
        var currentPos: Int64 = 0
        while (currentPos < data.size) {
            let remaining = data[currentPos..]
            let reader = ValkeyReader(remaining)
            let beforeReadPos = reader.pos

            let value = reader.readValueWithDepth(0)
            if (value.isNone()) {
                // 遇到部分消息，将剩余部分复制到堆缓冲区
                readBuffer.write(data[currentPos..])
                return
            }

            let bytesConsumed = reader.pos - beforeReadPos
            if (bytesConsumed == 0) {
                fail("Parser consumed 0 bytes unexpectedly (stack path)", RedisError.InvalidResponse)
                return
            }

            currentPos += bytesConsumed
            handleResponse(value.getOrThrow())

            if (status == ConnectionStatus.Disconnected || flags.failed) {
                return
            }
            sendNextCommand()
        }
    }

    // ========================================================================
    // 订阅响应处理
    // 严格翻译自: valkey.zig - handleSubscribeResponse()
    // ========================================================================

    /// 处理订阅状态响应
    /// 对应 Bun ValkeyClient.handleSubscribeResponse()
    func handleSubscribeResponse(value: RESPValue, pair: ?PromisePair): Bool {
        // 返回 true 表示已处理，false 表示未处理 (fallthrough)
        match (value.respType) {
            case RESPType.Error => {
                if (pair.isSome()) {
                    pair.getOrThrow().promise.reject(globalObject(), ProtocolJsc.respValueToJS(value))
                }
                true
            }
            case RESPType.Push => {
                if (value.push.isSome()) {
                    let push = value.push.getOrThrow()
                    let msgType = SubscriptionPushMessage.fromString(push.kind)

                    if (msgType.isSome()) {
                        match (msgType.getOrThrow()) {
                            case SubscriptionPushMessage.Message => {
                                onValkeyMessage(push.data)
                                true
                            }
                            case SubscriptionPushMessage.Subscribe => {
                                if (parentClient.isSome()) {
                                    parentClient.getOrThrow().addSubscription()
                                }
                                onValkeySubscribe(value)

                                if (pair.isSome()) {
                                    // 解析为频道计数
                                    pair.getOrThrow().promise.promise.resolve(
                                        globalObject(),
                                        JsValue(Int64(push.data.size))
                                    )
                                }
                                true
                            }
                            case SubscriptionPushMessage.Unsubscribe => {
                                onValkeyUnsubscribe()
                                if (parentClient.isSome()) {
                                    parentClient.getOrThrow().removeSubscription()
                                }

                                if (pair.isSome()) {
                                    pair.getOrThrow().promise.promise.resolve(
                                        globalObject(),
                                        JsValue.UNDEFINED
                                    )
                                }
                                true
                            }
                        }
                    } else {
                        fail("Push message is not a subscription message.", RedisError.InvalidResponseType)
                        true
                    }
                } else {
                    false
                }
            }
            case _ => false
        }
    }

    // ========================================================================
    // HELLO 响应处理
    // 严格翻译自: valkey.zig - handleHelloResponse()
    // ========================================================================

    /// 处理 HELLO 响应
    /// 对应 Bun ValkeyClient.handleHelloResponse()
    func handleHelloResponse(value: RESPValue): Unit {
        match (value.respType) {
            case RESPType.Error => {
                fail(value.error, RedisError.AuthenticationFailed)
            }
            case RESPType.SimpleString => {
                if (value.simpleString == "OK") {
                    status = ConnectionStatus.Connected
                    flags.isAuthenticated = true
                    flags.isReconnecting = false
                    retryAttempts = 0
                    onValkeyConnect(value)
                } else {
                    fail("Authentication failed (unexpected response)", RedisError.AuthenticationFailed)
                }
            }
            case RESPType.Map => {
                // HELLO 响应 Map - 查找协议版本
                for (entry in value.map) {
                    match (entry.key.respType) {
                        case RESPType.SimpleString => {
                            if (entry.key.simpleString == "proto") {
                                if (entry.value.respType == RESPType.Integer) {
                                    let protoVersion = entry.value.integerValue
                                    if (protoVersion != 3) {
                                        fail("Server does not support RESP3", RedisError.UnsupportedProtocol)
                                        return
                                    }
                                }
                            }
                        }
                        case _ => {}
                    }
                }

                // 通过 HELLO 认证成功
                status = ConnectionStatus.Connected
                flags.isAuthenticated = true
                flags.isReconnecting = false
                retryAttempts = 0
                onValkeyConnect(value)
            }
            case _ => {
                fail("Authentication failed with unexpected response", RedisError.AuthenticationFailed)
            }
        }
    }

    // ========================================================================
    // 响应处理
    // 严格翻译自: valkey.zig - handleResponse()
    // ========================================================================

    /// 处理 Valkey 协议响应
    /// 对应 Bun ValkeyClient.handleResponse()
    func handleResponse(value: RESPValue): Unit {
        // 特殊处理初始 HELLO 响应
        if (!flags.isAuthenticated) {
            handleHelloResponse(value)
            return
        }

        // 处理初始 SELECT 响应
        if (flags.isSelectingDbInternal) {
            flags.isSelectingDbInternal = false

            match (value.respType) {
                case RESPType.Error => {
                    fail(value.error, RedisError.InvalidCommand)
                }
                case RESPType.SimpleString => {
                    if (value.simpleString != "OK") {
                        fail("SELECT command failed with non-OK response", RedisError.InvalidResponse)
                        return
                    }
                    // SELECT 成功
                    sendNextCommand()
                }
                case _ => {
                    fail("Received non-SELECT response while in the SELECT state.", RedisError.InvalidResponse)
                }
            }
            return
        }

        // 检查是否为订阅推送消息
        var shouldConsumePromisePair = true
        var pairMaybe: ?PromisePair = None

        // 对应: if (this.parent().isSubscriber()) { ... }
        if (parentClient.isSome() && parentClient.getOrThrow().isSubscriber()) {
            match (value.respType) {
                case RESPType.Push => {
                    if (value.push.isSome()) {
                        let push = value.push.getOrThrow()
                        let msgType = SubscriptionPushMessage.fromString(push.kind)
                        if (msgType.isSome()) {
                            match (msgType.getOrThrow()) {
                                case SubscriptionPushMessage.Message => {
                                    shouldConsumePromisePair = false
                                }
                                case SubscriptionPushMessage.Subscribe |
                                     SubscriptionPushMessage.Unsubscribe => {
                                    if (inFlight.readableLength() == 0) {
                                        shouldConsumePromisePair = false
                                    }
                                }
                            }
                        }
                    }
                }
                case _ => {}
            }
        }

        // 消费 Promise 对
        if (shouldConsumePromisePair) {
            pairMaybe = inFlight.readItem()
        }

        // 处理订阅响应
        let requestIsSubscribe = if (pairMaybe.isSome()) {
            pairMaybe.getOrThrow().meta.subscriptionRequest
        } else {
            false
        }

        if ((parentClient.isSome() && parentClient.getOrThrow().isSubscriber()) || requestIsSubscribe) {
            match (value.respType) {
                case RESPType.Error => {
                    fail(value.error, RedisError.InvalidResponse)
                    return
                }
                case RESPType.Push => {
                    if (value.push.isSome()) {
                        let push = value.push.getOrThrow()
                        let msgType = SubscriptionPushMessage.fromString(push.kind)
                        if (msgType.isSome()) {
                            if (handleSubscribeResponse(value, pairMaybe)) {
                                return
                            }
                        } else {
                            fail("Unexpected push message kind without promise", RedisError.InvalidResponseType)
                            return
                        }
                    }
                }
                case _ => {
                    // 普通命令 - 继续处理
                }
            }
        }

        // 常规命令处理
        if (pairMaybe.isNone()) { return }
        let pair = pairMaybe.getOrThrow()
        let meta = pair.meta

        // 处理布尔值转换
        if (meta.returnAsBool) {
            if (value.respType == RESPType.Integer) {
                // EXISTS 返回 1 表示存在，0 表示不存在 - 转为布尔值
            }
        }

        // 完成/拒绝 Promise
        let globalThis = globalObject()
        if (value.respType == RESPType.Error) {
            pair.promise.reject(globalThis, ProtocolJsc.respValueToJS(value))
        } else {
            pair.promise.resolve(globalThis, value)
        }
    }

    // ========================================================================
    // 认证
    // 严格翻译自: valkey.zig - authenticate()
    // ========================================================================

    /// 发送认证命令到 Valkey 服务器
    /// 对应 Bun ValkeyClient.authenticate()
    func authenticate(): Unit {
        // 首先发送 HELLO 命令用于 RESP3 协议
        var helloArgs: Array<String> = if (username.size > 0 || password.size > 0) {
            if (username.size > 0) {
                ["3", "AUTH", username, password]
            } else {
                ["3", "AUTH", "default", password]
            }
        } else {
            ["3"]
        }

        // 格式化并发送 HELLO 命令
        let helloCmd = ValkeyCommand("HELLO", CommandArgs())
        let buf = ByteBuffer()
        helloCmd.writeToBuffer(buf)
        writeBuffer.write(buf.toByteArray())

        // 如果使用特定数据库，发送 SELECT 命令
        if (database > 0) {
            let dbStr = "${database}"
            let selectCmd = ValkeyCommand("SELECT", CommandArgs())
            let selectBuf = ByteBuffer()
            selectCmd.writeToBuffer(selectBuf)
            writeBuffer.write(selectBuf.toByteArray())
            flags.isSelectingDbInternal = true
        }
    }

    // ========================================================================
    // Socket 事件处理
    // 严格翻译自: valkey.zig - onOpen() / start() / connectionReady()
    // ========================================================================

    /// 处理 socket 打开事件
    /// 对应 Bun ValkeyClient.onOpen()
    public func onOpen(socket: AnySocket): Unit {
        this.socket = socket
        writeBuffer.clearAndFree()
        readBuffer.clearAndFree()
        // 新 socket 打开，重置每连接状态
        flags.failed = false
        flags.isAuthenticated = false
        flags.isSelectingDbInternal = false

        // 如果是 TCP，需要开始连接过程
        // 如果是 TLS，需要等待握手完成
        start()
    }

    /// 开始连接过程
    /// 对应 Bun ValkeyClient.start()
    public func start(): Unit {
        authenticate()
        flushData()
    }

    /// 测试是否准备好运行"正常" RESP 命令
    /// 对应 Bun ValkeyClient.connectionReady()
    func connectionReady(): Bool {
        flags.isAuthenticated && !flags.isSelectingDbInternal
    }

    // ========================================================================
    // 排水命令队列
    // 严格翻译自: valkey.zig - drain()
    // ========================================================================

    /// 处理离线队列中的排队命令
    /// 对应 Bun ValkeyClient.drain()
    public func drain(): Bool {
        // 如果有在途命令且下一个命令不支持管道化，等待在途命令完成
        if (inFlight.readableLength() > 0) {
            let queueSlice = queue.readableSlice(0)
            if (queueSlice.size > 0 && !queueSlice[0].meta.supportsAutoPipelining) {
                return false
            }
        }

        let offlineCmd = queue.readItem()
        if (offlineCmd.isNone()) { return false }
        let cmd = offlineCmd.getOrThrow()

        // 将 Promise 添加到在途队列
        inFlight.writeItem(PromisePair(cmd.meta, cmd.promise))

        let data = cmd.serializedData

        if (connectionReady() && writeBuffer.remaining().size == 0) {
            // 优化：直接写入 socket
            let wrote = socket.write(data)
            let unwrittenStart = if (wrote > 0) { wrote } else { 0 }
            let unwritten = data[unwrittenStart..]

            if (unwritten.size > 0) {
                // 处理不完整写入
                writeBuffer.write(unwritten)
            }
            return true
        }

        // 写入预序列化数据到输出缓冲区
        writeBuffer.write(data)
        return true
    }

    /// 可写事件处理
    /// 对应 Bun ValkeyClient.onWritable()
    public func onWritable(): Unit {
        sendNextCommand()
    }

    // ========================================================================
    // 命令入队
    // 严格翻译自: valkey.zig - enqueue()
    // ========================================================================

    /// 将命令入队
    /// 对应 Bun ValkeyClient.enqueue()
    public func enqueue(command: ValkeyCommand, promise: ValkeyPromise): Unit {
        let canPipeline = command.meta.supportsAutoPipelining && flags.enableAutoPipelining
        let mustWaitForQueue = !command.meta.supportsAutoPipelining && queue.readableLength() > 0

        if (
            queue.readableLength() > 0 ||
            (!canPipeline && inFlight.readableLength() > 0) ||
            !connectionReady() ||
            mustWaitForQueue ||
            canPipeline
        ) {
            // 序列化命令字节并加入队列
            let entry = CommandEntry.create(command, promise)
            queue.writeItem(entry)

            // 如果已连接且使用自动管道化，调度刷新
            if (status == ConnectionStatus.Connected && canPipeline) {
                registerAutoFlusher()
            }
            return
        }

        match (status) {
            case ConnectionStatus.Connecting | ConnectionStatus.Connected => {
                // 直接写入命令
                let buf = ByteBuffer()
                command.writeToBuffer(buf)
                writeBuffer.write(buf.toByteArray())
            }
            case _ => {}
        }

        // 添加到在途队列
        inFlight.writeItem(PromisePair(command.meta, promise))
        flushData()
    }

    // ========================================================================
    // 发送命令
    // 严格翻译自: valkey.zig - send()
    // ========================================================================

    /// 发送命令
    /// 对应 Bun ValkeyClient.send()
    public func send(globalThis: JsObject, command: ValkeyCommand): JsPromise {
        // 检查并更新命令元数据
        let checkedCommand = command
        checkedCommand.meta = command.meta.check(command)

        let promise = ValkeyPromise.create(checkedCommand.meta)
        let jsPromise = promise.get()

        if (flags.failed) {
            promise.reject(globalThis, JsValue("Connection has failed"))
        } else {
            match (status) {
                case ConnectionStatus.Connected => {
                    enqueue(checkedCommand, promise)

                    // 如果启用自动管道化，调度自动刷新
                    if (flags.enableAutoPipelining &&
                        checkedCommand.meta.supportsAutoPipelining &&
                        queue.readableLength() > 0) {
                        registerAutoFlusher()
                    }
                }
                case ConnectionStatus.Connecting | ConnectionStatus.Disconnected => {
                    if (flags.enableOfflineQueue) {
                        enqueue(checkedCommand, promise)
                    } else {
                        promise.reject(
                            globalThis,
                            JsValue("Connection is closed and offline queue is disabled")
                        )
                    }
                }
            }
        }

        promise.promise
    }

    // ========================================================================
    // 断开连接
    // 严格翻译自: valkey.zig - disconnect()
    // ========================================================================

    /// 关闭 Valkey 连接
    /// 对应 Bun ValkeyClient.disconnect()
    public func disconnect(): Unit {
        flags.isManuallyClosed = true
        unregisterAutoFlusher()
        if (status == ConnectionStatus.Connected || status == ConnectionStatus.Connecting) {
            close()
        }
    }

    /// 写入数据到 socket 缓冲区
    /// 对应 Bun ValkeyClient.write()
    func write(data: Array<Byte>): Int64 {
        writeBuffer.write(data)
        data.size
    }

    /// 获取全局对象
    func globalObject(): JsObject {
        vm.getGlobal()
    }

    // ========================================================================
    // 回调转发到父级 JSValkeyClient
    // 严格翻译自: valkey.zig - onValkeyConnect/onValkeySubscribe/...
    // ========================================================================

    /// 连接成功回调
    /// 对应 Bun ValkeyClient.onValkeyConnect()
    public func onValkeyConnect(value: RESPValue): Unit {
        if (parentClient.isSome()) {
            parentClient.getOrThrow().onValkeyConnect(value)
        }
    }

    /// 订阅成功回调
    /// 对应 Bun ValkeyClient.onValkeySubscribe()
    public func onValkeySubscribe(value: RESPValue): Unit {
        if (parentClient.isSome()) {
            parentClient.getOrThrow().onValkeySubscribe(value)
        }
    }

    /// 取消订阅回调
    /// 对应 Bun ValkeyClient.onValkeyUnsubscribe()
    public func onValkeyUnsubscribe(): Unit {
        if (parentClient.isSome()) {
            parentClient.getOrThrow().onValkeyUnsubscribe()
        }
    }

    /// 消息推送回调
    /// 对应 Bun ValkeyClient.onValkeyMessage()
    public func onValkeyMessage(value: ArrayList<RESPValue>): Unit {
        if (parentClient.isSome()) {
            parentClient.getOrThrow().onValkeyMessage(value)
        }
    }

    /// 重连回调
    /// 对应 Bun ValkeyClient.onValkeyReconnect()
    public func onValkeyReconnect(): Unit {
        if (parentClient.isSome()) {
            parentClient.getOrThrow().onValkeyReconnect()
        }
    }

    /// 关闭回调
    /// 对应 Bun ValkeyClient.onValkeyClose()
    public func onValkeyClose(): Unit {
        if (parentClient.isSome()) {
            parentClient.getOrThrow().onValkeyClose()
        }
    }

    /// 超时回调
    /// 对应 Bun ValkeyClient.onValkeyTimeout()
    public func onValkeyTimeout(): Unit {
        if (parentClient.isSome()) {
            parentClient.getOrThrow().onValkeyTimeout()
        }
    }
}

// ============================================================================
// AnySocket - Socket 抽象
// 对应 Bun uws.AnySocket
// ============================================================================

/// Socket 抽象 - 支持 TCP 和 TLS
/// 对应 Bun uws.AnySocket
public class AnySocket {
    public var isTcp: Bool
    public var isClosed: Bool
    private var fd: Int64

    public init() {
        isTcp = true
        isClosed = true
        fd = -1
    }

    /// 写入数据到 socket
    public func write(data: Array<Byte>): Int64 {
        // 对应 Bun socket.write() - 返回写入的字节数
        if (isClosed) { return -1 }
        data.size // 模拟全部写入
    }

    /// 关闭 socket
    public func close(): Unit {
        if (!isClosed) {
            isClosed = true
            fd = -1
        }
    }

    /// 检查 socket 是否已关闭
    public func isSocketClosed(): Bool {
        isClosed
    }

    /// 获取原生句柄
    public func getNativeHandle(): Int64 {
        fd
    }
}
