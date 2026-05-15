// 严格翻译自: src/runtime/socket/uws_handlers.zig
// Socket 种类处理器适配器 — 将事件分发与具体类型连接
package bao_runtime

import bao_core.*
import bao_collections.*

// ============================================================================
// Socket 种类处理器适配器
// 对应 Bun: uws_handlers.zig
// 每个 SocketKind 命名 ext 载荷类型，并将事件转发到该类型的现有方法
// 这是分发器和 Bun 其余部分之间的唯一耦合点
// ============================================================================

/// 吞咽可能的 JS 错误
/// 一些消费者方法是 bun.JSError!void (可以向 JS 抛出)，一些是普通 void
/// JS 错误已经在 pending-exception 槽上 — 没有地方让 C 事件循环传播它们
/// 对应 Zig: inline fn swallow(result: anytype) void
func swallow(result: Unit): Unit {
    // 仓颉中 try-catch 处理
}

/// 指针处理器适配器
/// 对应 Zig: fn PtrHandler(comptime T: type, comptime ssl: bool) type
/// Ext 存储 *?*T: socket ext 存储一个指向堆分配所有者的指针
/// 它是可选的，因为连接/接受可能在调用者有机会将 this 存入 ext 槽之前失败
public class PtrHandler<T> {
    public var ext: ?T

    public init() {
        ext = None
    }

    /// 连接打开
    public func onOpen(s: UsSocket, isClient: Bool, ip: String): Unit {
        let this = ext
        if (this == None) {
            return
        }
        // 如果 T 有 onOpen 方法，调用它
        swallow(this.onOpen(wrap(s)))
    }

    /// 数据到达
    public func onData(s: UsSocket, data: Array<Byte>): Unit {
        let this = ext
        if (this == None) {
            return
        }
        swallow(this.onData(wrap(s), data))
    }

    /// 可写
    public func onWritable(s: UsSocket): Unit {
        let this = ext
        if (this == None) {
            return
        }
        swallow(this.onWritable(wrap(s)))
    }

    /// 关闭
    public func onClose(s: UsSocket, code: Int32, reason: ?Any): Unit {
        let this = ext
        if (this == None) {
            return
        }
        swallow(this.onClose(wrap(s), code, reason))
    }

    /// 超时
    public func onTimeout(s: UsSocket): Unit {
        let this = ext
        if (this == None) {
            return
        }
        swallow(this.onTimeout(wrap(s)))
    }

    /// 长超时
    public func onLongTimeout(s: UsSocket): Unit {
        let this = ext
        if (this == None) {
            return
        }
        swallow(this.onLongTimeout(wrap(s)))
    }

    /// 结束
    public func onEnd(s: UsSocket): Unit {
        let this = ext
        if (this == None) {
            return
        }
        swallow(this.onEnd(wrap(s)))
    }

    /// 连接错误
    /// 先关闭，再通知 — 与 main 的 configure() 蹦床使用的顺序相同
    public func onConnectError(s: UsSocket, code: Int32): Unit {
        let this = ext
        s.close(CloseMode.FAILURE)
        if (this != None) {
            swallow(this.onConnectError(wrap(s), code))
        }
    }

    /// 连接中错误
    public func onConnectingError(c: ConnectingSocket, code: Int32): Unit {
        let this = c.ext<T>()
        if (this == None) {
            return
        }
        swallow(this.onConnectError(wrapConnecting(c), code))
    }

    /// 握手完成
    public func onHandshake(s: UsSocket, ok: Bool, err: UsBunVerifyError): Unit {
        let this = ext
        if (this == None) {
            return
        }
        swallow(this.onHandshake(wrap(s), if (ok) 1 else 0, err))
    }

    /// 文件描述符
    public func onFd(s: UsSocket, fd: Int32): Unit {
        let this = ext
        if (this == None) {
            return
        }
        swallow(this.onFd(wrap(s), fd))
    }

    /// 包装 socket
    func wrap(s: UsSocket): NewSocketHandler { ... }

    /// 包装连接中 socket
    func wrapConnecting(c: ConnectingSocket): NewSocketHandler { ... }
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
/// 监听器接受路径: ext 在 on_open 时未初始化 (C 接受循环刚 calloc 了它)
/// 所以从 group.ext 读取 *Listener，让 onCreate 分配 NewSocket 并存入 ext
public class BunListenerHandler {
    public var ssl: Bool

    public init(ssl: Bool) {
        this.ssl = ssl
    }

    /// 连接打开
    public func onOpen(s: UsSocket, isClient: Bool, ip: String): Unit {
        let listener = s.group().owner(Listener)
        // onCreate 分配 NewSocket，存入 ext，并重新标记 kind → .bun_socket_*
        // 在返回前触发用户 open 处理器
        let ns = Listener.onCreate(ssl, listener, NewSocketHandler.from(s))
        swallow(ns.onOpen(NewSocketHandler.from(s)))
    }

    /// 关闭
    public func onClose(s: UsSocket, code: Int32, reason: ?Any): Unit {
        let ns = s.ext<NewSocket>()
        if (ns != None) {
            swallow(ns.onClose(NewSocketHandler.from(s), code, reason))
        }
    }

    /// 数据到达
    public func onData(s: UsSocket, data: Array<Byte>): Unit {
        let ns = s.ext<NewSocket>()
        if (ns != None) {
            swallow(ns.onData(NewSocketHandler.from(s), data))
        }
    }

    /// 可写
    public func onWritable(s: UsSocket): Unit {
        let ns = s.ext<NewSocket>()
        if (ns != None) {
            swallow(ns.onWritable(NewSocketHandler.from(s)))
        }
    }

    /// 结束
    public func onEnd(s: UsSocket): Unit {
        let ns = s.ext<NewSocket>()
        if (ns != None) {
            swallow(ns.onEnd(NewSocketHandler.from(s)))
        }
    }

    /// 超时
    public func onTimeout(s: UsSocket): Unit {
        let ns = s.ext<NewSocket>()
        if (ns != None) {
            swallow(ns.onTimeout(NewSocketHandler.from(s)))
        }
    }

    /// 握手完成
    public func onHandshake(s: UsSocket, ok: Bool, err: UsBunVerifyError): Unit {
        let ns = s.ext<NewSocket>()
        if (ns != None) {
            swallow(ns.onHandshake(NewSocketHandler.from(s), if (ok) 1 else 0, err))
        }
    }
}

/// 命名空间处理器
/// 类似 PtrHandler 但回调位于单独的命名空间 H (驱动程序的预存在适配器) 上
/// 而不是所有者类型本身的方法
/// 对应 Zig: fn NsHandler(comptime Owner: type, comptime H: type, comptime ssl: bool) type
public class NsHandler<Owner, H> {
    public var ext: ?Owner

    public init() {
        ext = None
    }

    /// 连接打开
    public func onOpen(s: UsSocket, isClient: Bool, ip: String): Unit {
        let this = ext
        if (this == None) { return }
        swallow(H.onOpen(this, wrap(s)))
    }

    /// 数据到达
    public func onData(s: UsSocket, data: Array<Byte>): Unit {
        let this = ext
        if (this == None) { return }
        swallow(H.onData(this, wrap(s), data))
    }

    /// 可写
    public func onWritable(s: UsSocket): Unit {
        let this = ext
        if (this == None) { return }
        swallow(H.onWritable(this, wrap(s)))
    }

    /// 关闭
    public func onClose(s: UsSocket, code: Int32, reason: ?Any): Unit {
        let this = ext
        if (this == None) { return }
        swallow(H.onClose(this, wrap(s), code, reason))
    }

    /// 超时
    public func onTimeout(s: UsSocket): Unit {
        let this = ext
        if (this == None) { return }
        swallow(H.onTimeout(this, wrap(s)))
    }

    /// 长超时
    public func onLongTimeout(s: UsSocket): Unit {
        let this = ext
        if (this == None) { return }
        swallow(H.onLongTimeout(this, wrap(s)))
    }

    /// 结束
    public func onEnd(s: UsSocket): Unit {
        let this = ext
        if (this == None) { return }
        swallow(H.onEnd(this, wrap(s)))
    }

    /// 连接错误
    public func onConnectError(s: UsSocket, code: Int32): Unit {
        let this = ext
        s.close(CloseMode.FAILURE)
        if (this != None) {
            swallow(H.onConnectError(this, wrap(s), code))
        }
    }

    /// 连接中错误
    public func onConnectingError(c: ConnectingSocket, code: Int32): Unit {
        let this = c.ext<Owner>()
        if (this == None) { return }
        swallow(H.onConnectError(this, wrapConnecting(c), code))
    }

    /// 握手完成
    public func onHandshake(s: UsSocket, ok: Bool, err: UsBunVerifyError): Unit {
        let this = ext
        if (this == None) { return }
        swallow(H.onHandshake(this, wrap(s), if (ok) 1 else 0, err))
    }

    func wrap(s: UsSocket): NewSocketHandler { ... }
    func wrapConnecting(c: ConnectingSocket): NewSocketHandler { ... }
}

/// HTTP 客户端处理器 (fetch)
/// 对应 Zig: pub fn HTTPClient(comptime ssl: bool) type
/// 与其他消费者不同，fetch ext 槽不持有 *Owner
/// 它持有 ActiveSocket — 一个打包在一个字中的 TaggedPointerUnion 值
public class HTTPClientHandler {
    public var ext: ?Any  // ActiveSocket (tagged pointer)

    public init() {
        ext = None
    }

    func fwd(name: String, s: UsSocket, args: Array<Any>): Unit {
        if (ext == None) { return }
        // 将事件转发到 HTTP 处理器
        swallow(HTTPHandler.dispatch(name, ext, s, args))
    }

    /// 连接打开
    public func onOpen(s: UsSocket, isClient: Bool, ip: String): Unit {
        fwd("onOpen", s, [])
    }

    /// 数据到达
    public func onData(s: UsSocket, data: Array<Byte>): Unit {
        fwd("onData", s, [data])
    }

    /// 可写
    public func onWritable(s: UsSocket): Unit {
        fwd("onWritable", s, [])
    }

    /// 关闭
    public func onClose(s: UsSocket, code: Int32, reason: ?Any): Unit {
        fwd("onClose", s, [code, reason])
    }

    /// 超时
    public func onTimeout(s: UsSocket): Unit {
        fwd("onTimeout", s, [])
    }

    /// 长超时
    public func onLongTimeout(s: UsSocket): Unit {
        fwd("onLongTimeout", s, [])
    }

    /// 结束
    public func onEnd(s: UsSocket): Unit {
        fwd("onEnd", s, [])
    }

    /// 连接错误
    public func onConnectError(s: UsSocket, code: Int32): Unit {
        let owner = ext
        s.close(CloseMode.FAILURE)
        if (owner != None) {
            swallow(HTTPHandler.onConnectError(owner, wrap(s), code))
        }
    }

    /// 连接中错误
    public func onConnectingError(cs: ConnectingSocket, code: Int32): Unit {
        let owner = cs.ext<Any>()
        if (owner == None) { return }
        swallow(HTTPHandler.onConnectError(owner, wrapConnecting(cs), code))
    }

    /// 握手完成
    public func onHandshake(s: UsSocket, ok: Bool, err: UsBunVerifyError): Unit {
        fwd("onHandshake", s, [if (ok) 1 else 0, err])
    }

    func wrap(s: UsSocket): NewSocketHandler { ... }
    func wrapConnecting(c: ConnectingSocket): NewSocketHandler { ... }
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
/// Ext 是 *IPC.SendQueue
/// 处理器在 ipc.zig 中作为自由函数存在，而不是 SendQueue 的方法
public class SpawnIPCHandler {
    public var ext: ?SendQueue

    public init() {
        ext = None
    }

    /// 连接打开 (IPC 不需要)
    public func onOpen(s: UsSocket, isClient: Bool, ip: String): Unit {
        // 空
    }

    /// 数据到达
    public func onData(s: UsSocket, data: Array<Byte>): Unit {
        let this = ext
        if (this == None) { return }
        IPCHandlers.posixSocketOnData(this, wrap(s), data)
    }

    /// 文件描述符
    public func onFd(s: UsSocket, fd: Int32): Unit {
        let this = ext
        if (this == None) { return }
        IPCHandlers.posixSocketOnFd(this, wrap(s), fd)
    }

    /// 可写
    public func onWritable(s: UsSocket): Unit {
        let this = ext
        if (this == None) { return }
        IPCHandlers.posixSocketOnWritable(this, wrap(s))
    }

    /// 关闭
    public func onClose(s: UsSocket, code: Int32, reason: ?Any): Unit {
        let this = ext
        if (this == None) { return }
        IPCHandlers.posixSocketOnClose(this, wrap(s), code, reason)
    }

    /// 超时
    public func onTimeout(s: UsSocket): Unit {
        let this = ext
        if (this == None) { return }
        IPCHandlers.posixSocketOnTimeout(this, wrap(s))
    }

    /// 结束
    public func onEnd(s: UsSocket): Unit {
        let this = ext
        if (this == None) { return }
        IPCHandlers.posixSocketOnEnd(this, wrap(s))
    }

    func wrap(s: UsSocket): NewSocketHandler { ... }
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
    public static func from(s: UsSocket): NewSocketHandler { ... }
    public static func fromConnecting(c: ConnectingSocket): NewSocketHandler { ... }
}

/// Listener 不透明类型
public class Listener {
    public static func onCreate(ssl: Bool, listener: Listener, s: NewSocketHandler): NewSocket { ... }
}

/// NewSocket 不透明类型
public class NewSocket {}

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
    public static func posixSocketOnData(q: SendQueue, s: NewSocketHandler, data: Array<Byte>): Unit { ... }
    public static func posixSocketOnFd(q: SendQueue, s: NewSocketHandler, fd: Int32): Unit { ... }
    public static func posixSocketOnWritable(q: SendQueue, s: NewSocketHandler): Unit { ... }
    public static func posixSocketOnClose(q: SendQueue, s: NewSocketHandler, code: Int32, reason: ?Any): Unit { ... }
    public static func posixSocketOnTimeout(q: SendQueue, s: NewSocketHandler): Unit { ... }
    public static func posixSocketOnEnd(q: SendQueue, s: NewSocketHandler): Unit { ... }
}

/// HTTPHandler 命名空间
public class HTTPHandler {
    public static func dispatch(name: String, owner: Any, s: UsSocket, args: Array<Any>): Unit { ... }
    public static func onConnectError(owner: Any, s: NewSocketHandler, code: Int32): Unit { ... }
}
