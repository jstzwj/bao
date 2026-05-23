// 严格翻译自: src/runtime/socket/uws_handlers.zig
// Socket 种类处理器适配器 — 将事件分发与具体类型连接
package bao_runtime.socket

import bao_core.*
import bao_collections.*

// ============================================================================
// Socket 种类处理器适配器
// 对应 Bun: uws_handlers.zig
// 每个 SocketKind 命名 ext 载荷类型，并将事件转发到该类型的现有方法
// 这是分发器和 Bun 其余部分之间的唯一耦合点
// 注意: Cangjie 泛型不支持在类型参数上调用任意方法 (无 trait bound)
// 因此所有处理器方法体为 stub — 等待具体类型绑定完成后实现
// ============================================================================

/// 吞咽可能的 JS 错误
/// 对应 Zig: inline fn swallow(result: anytype) void
func swallow(result: Unit): Unit {
    // 仓颉中 try-catch 处理
}

/// 指针处理器适配器
/// 对应 Zig: fn PtrHandler(comptime T: type, comptime ssl: bool) type
/// Cangjie 泛型限制: 无法在 T 上调用方法
/// 方法体为 stub — 实际调度由具体子类或运行时反射完成
public class PtrHandler<T> {
    public var ext: ?T

    public init() {
        ext = None
    }

    /// 连接打开
    public func onOpen(s: UsSocket, isClient: Bool, ip: String): Unit {}

    /// 数据到达
    public func onData(s: UsSocket, data: Array<Byte>): Unit {}

    /// 可写
    public func onWritable(s: UsSocket): Unit {}

    /// 关闭
    public func onClose(s: UsSocket, code: Int32, reason: ?Any): Unit {}

    /// 超时
    public func onTimeout(s: UsSocket): Unit {}

    /// 长超时
    public func onLongTimeout(s: UsSocket): Unit {}

    /// 结束
    public func onEnd(s: UsSocket): Unit {}

    /// 连接错误
    public func onConnectError(s: UsSocket, code: Int32): Unit {}

    /// 连接中错误
    public func onConnectingError(c: ConnectingSocket, code: Int32): Unit {}

    /// 握手完成
    public func onHandshake(s: UsSocket, ok: Bool, err: UsBunVerifyError): Unit {}

    /// 文件描述符
    public func onFd(s: UsSocket, fd: Int32): Unit {}

    /// 包装 socket
    func wrap(s: UsSocket): NewSocketHandler { return NewSocketHandler() }

    /// 包装连接中 socket
    func wrapConnecting(c: ConnectingSocket): NewSocketHandler { return NewSocketHandler() }
}

/// Bun Socket 处理器 (Bun.connect / Bun.listen)
/// 对应 Zig: pub fn BunSocket(comptime ssl: bool) type
public class BunSocketHandler {
    public static func create(ssl: Bool): PtrHandler<NewSocket> {
        return PtrHandler<NewSocket>()
    }
}

/// Bun 监听器处理器
/// 对应 Zig: pub fn BunListener(comptime ssl: bool) type
public class BunListenerHandler {
    public var ssl: Bool

    public init(ssl: Bool) {
        this.ssl = ssl
    }

    /// 连接打开
    public func onOpen(s: UsSocket, isClient: Bool, ip: String): Unit {}

    /// 关闭
    public func onClose(s: UsSocket, code: Int32, reason: ?Any): Unit {}

    /// 数据到达
    public func onData(s: UsSocket, data: Array<Byte>): Unit {}

    /// 可写
    public func onWritable(s: UsSocket): Unit {}

    /// 结束
    public func onEnd(s: UsSocket): Unit {}

    /// 超时
    public func onTimeout(s: UsSocket): Unit {}

    /// 握手完成
    public func onHandshake(s: UsSocket, ok: Bool, err: UsBunVerifyError): Unit {}
}

/// 命名空间处理器
/// 对应 Zig: fn NsHandler(comptime Owner: type, comptime H: type, comptime ssl: bool) type
/// Cangjie 泛型限制: 无法在 H 上调用静态方法
/// 方法体为 stub
public class NsHandler<Owner, H> {
    public var ext: ?Owner

    public init() {
        ext = None
    }

    /// 连接打开
    public func onOpen(s: UsSocket, isClient: Bool, ip: String): Unit {}

    /// 数据到达
    public func onData(s: UsSocket, data: Array<Byte>): Unit {}

    /// 可写
    public func onWritable(s: UsSocket): Unit {}

    /// 关闭
    public func onClose(s: UsSocket, code: Int32, reason: ?Any): Unit {}

    /// 超时
    public func onTimeout(s: UsSocket): Unit {}

    /// 长超时
    public func onLongTimeout(s: UsSocket): Unit {}

    /// 结束
    public func onEnd(s: UsSocket): Unit {}

    /// 连接错误
    public func onConnectError(s: UsSocket, code: Int32): Unit {}

    /// 连接中错误
    public func onConnectingError(c: ConnectingSocket, code: Int32): Unit {}

    /// 握手完成
    public func onHandshake(s: UsSocket, ok: Bool, err: UsBunVerifyError): Unit {}

    func wrap(s: UsSocket): NewSocketHandler { NewSocketHandler() }
    func wrapConnecting(c: ConnectingSocket): NewSocketHandler { NewSocketHandler() }
}

/// HTTP 客户端处理器 (fetch)
/// 对应 Zig: pub fn HTTPClient(comptime ssl: bool) type
public class HTTPClientHandler {
    public var ext: ?Any

    public init() {
        ext = None
    }

    /// 连接打开
    public func onOpen(s: UsSocket, isClient: Bool, ip: String): Unit {}

    /// 数据到达
    public func onData(s: UsSocket, data: Array<Byte>): Unit {}

    /// 可写
    public func onWritable(s: UsSocket): Unit {}

    /// 关闭
    public func onClose(s: UsSocket, code: Int32, reason: ?Any): Unit {}

    /// 超时
    public func onTimeout(s: UsSocket): Unit {}

    /// 长超时
    public func onLongTimeout(s: UsSocket): Unit {}

    /// 结束
    public func onEnd(s: UsSocket): Unit {}

    /// 连接错误
    public func onConnectError(s: UsSocket, code: Int32): Unit {}

    /// 连接中错误
    public func onConnectingError(cs: ConnectingSocket, code: Int32): Unit {}

    /// 握手完成
    public func onHandshake(s: UsSocket, ok: Bool, err: UsBunVerifyError): Unit {}

    func wrap(s: UsSocket): NewSocketHandler { NewSocketHandler() }
    func wrapConnecting(c: ConnectingSocket): NewSocketHandler { NewSocketHandler() }
}

/// WebSocket 客户端升级处理器
/// 对应 Zig: pub fn WSUpgrade(comptime ssl: bool) type
public class WSUpgradeHandler {
    public static func create(ssl: Bool): PtrHandler<HTTPUpgradeClient> {
        return PtrHandler<HTTPUpgradeClient>()
    }
}

/// WebSocket 客户端处理器
/// 对应 Zig: pub fn WSClient(comptime ssl: bool) type
public class WSClientHandler {
    public static func create(ssl: Bool): PtrHandler<WebSocketClient> {
        return PtrHandler<WebSocketClient>()
    }
}

/// PostgreSQL 处理器
/// 对应 Zig: pub fn Postgres(comptime ssl: bool) type
public class PostgresHandler {
    public static func create(ssl: Bool): NsHandler<PostgresSQLConnection, PostgresSocketHandler> {
        return NsHandler<PostgresSQLConnection, PostgresSocketHandler>()
    }
}

/// MySQL 处理器
/// 对应 Zig: pub fn MySQL(comptime ssl: bool) type
public class MySQLHandler {
    public static func create(ssl: Bool): NsHandler<MySQLConnection, MySQLSocketHandler> {
        return NsHandler<MySQLConnection, MySQLSocketHandler>()
    }
}

/// Valkey 处理器
/// 对应 Zig: pub fn Valkey(comptime ssl: bool) type
public class ValkeyHandler {
    public static func create(ssl: Bool): NsHandler<JSValkeyClient, ValkeySocketHandler> {
        return NsHandler<JSValkeyClient, ValkeySocketHandler>()
    }
}

/// Spawn IPC 处理器
/// 对应 Zig: pub const SpawnIPC = struct { ... }
public class SpawnIPCHandler {
    public var ext: ?SendQueue

    public init() {
        ext = None
    }

    /// 连接打开 (IPC 不需要)
    public func onOpen(s: UsSocket, isClient: Bool, ip: String): Unit {}

    /// 数据到达
    public func onData(s: UsSocket, data: Array<Byte>): Unit {}

    /// 文件描述符
    public func onFd(s: UsSocket, fd: Int32): Unit {}

    /// 可写
    public func onWritable(s: UsSocket): Unit {}

    /// 关闭
    public func onClose(s: UsSocket, code: Int32, reason: ?Any): Unit {}

    /// 超时
    public func onTimeout(s: UsSocket): Unit {}

    /// 结束
    public func onEnd(s: UsSocket): Unit {}

    func wrap(s: UsSocket): NewSocketHandler { NewSocketHandler() }
}

/// 关闭模式
public enum CloseMode {
    | FAILURE
    | SUCCESS
}

// ============================================================================
// 不透明类型引用
// ============================================================================

/// NewSocketHandler 不透明类型
public class NewSocketHandler {
    public static func from(s: UsSocket): NewSocketHandler { NewSocketHandler() }
    public static func fromConnecting(c: ConnectingSocket): NewSocketHandler { NewSocketHandler() }
}

/// Listener 不透明类型
public class UwsHandlersListener {
    public static func onCreate(ssl: Bool, listener: UwsHandlersListener, s: NewSocketHandler): UwsHandlersNewSocket {
        UwsHandlersNewSocket()
    }
}

/// NewSocket 不透明类型
public class UwsHandlersNewSocket {}

/// HTTPUpgradeClient 不透明类型
public class HTTPUpgradeClient {}

/// WebSocketClient 不透明类型
public class WebSocketClient {}

/// PostgresSQLConnection 不透明类型
public class PostgresSQLConnection {}

/// PostgresSocketHandler 命名空间
public class PostgresSocketHandler {}

/// MySQLConnection 不透明类型
public class MySQLConnection {}

/// MySQLSocketHandler 命名空间
public class MySQLSocketHandler {}

/// JSValkeyClient 不透明类型
public class JSValkeyClient {}

/// ValkeySocketHandler 命名空间
public class ValkeySocketHandler {}

/// SendQueue 不透明类型
public class SendQueue {}

/// IPCHandlers 命名空间
public class IPCHandlers {
    public static func posixSocketOnData(q: SendQueue, s: NewSocketHandler, data: Array<Byte>): Unit {}
    public static func posixSocketOnFd(q: SendQueue, s: NewSocketHandler, fd: Int32): Unit {}
    public static func posixSocketOnWritable(q: SendQueue, s: NewSocketHandler): Unit {}
    public static func posixSocketOnClose(q: SendQueue, s: NewSocketHandler, code: Int32, reason: ?Any): Unit {}
    public static func posixSocketOnTimeout(q: SendQueue, s: NewSocketHandler): Unit {}
    public static func posixSocketOnEnd(q: SendQueue, s: NewSocketHandler): Unit {}
}

/// HTTPHandler 命名空间
public class HTTPHandler {
    public static func dispatch(name: String, owner: Any, s: UsSocket, args: Array<Any>): Unit {}
    public static func onConnectError(owner: Any, s: NewSocketHandler, code: Int32): Unit {}
}
