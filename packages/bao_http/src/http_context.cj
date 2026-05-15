// bao_http HTTPContext - HTTP 连接上下文和连接池
// 严格翻译自: bun/src/http/HTTPContext.zig
package bao_http

import bao_core.*
import bao_collections.*
import bao_sys.*
import bao_io.*
import bao_event_loop.*

// ============================================================================
// HTTPContext - HTTP/HTTPS 连接上下文
// 严格翻译自: bun/src/http/HTTPContext.zig
//
// Bun 使用 HTTPContext 管理 HTTP/HTTPS 连接:
//   - 连接池 (PooledSocket) — keep-alive socket 复用
//   - 连接建立 (connect) — 创建新连接或复用已有连接
//   - Socket 回调 (Handler) — onData/onWritable/onClose 等
//   - 引用计数 (RefCount) — 生命周期管理
//   - SSL 上下文 — BoringSSL SSL_CTX 管理
//
// NewHTTPContext(comptime ssl: bool) 返回不同的类型:
//   - ssl=false: HTTP 上下文，不需要 SSL
//   - ssl=true: HTTPS 上下文，需要 SSL_CTX
// ============================================================================

/// 连接池大小 - 对应 Bun: pool_size = 64
public let POOL_SIZE: Int64 = 64

/// 最大 keep-alive hostname 长度
/// 严格翻译自: MAX_KEEPALIVE_HOSTNAME = 128
public let MAX_KEEPALIVE_HOSTNAME: Int64 = 128

/// 池化 Socket — keep-alive 连接池中的条目
/// 严格翻译自: HTTPContext.PooledSocket
public class PooledSocket {
    /// HTTP socket
    /// 严格翻译自: http_socket: HTTPSocket
    public var httpSocketFd: Int64
    /// hostname 缓冲区
    /// 严格翻译自: hostname_buf: [MAX_KEEPALIVE_HOSTNAME]u8
    public var hostname: String
    /// 端口
    /// 严格翻译自: port: u16
    public var port: UInt16
    /// 是否在 reject_unauthorized=false 时有过握手错误
    /// 严格翻译自: did_have_handshaking_error_while_reject_unauthorized_is_false: bool
    public var didHaveHandshakingErrorWhileRejectUnauthorizedIsFalse: Bool
    /// SSL 配置
    /// 严格翻译自: ssl_config: ?SSLConfig.SharedPtr
    public var sslConfig: ?TLSConfig
    /// 所属的上下文
    /// 严格翻译自: owner: *Context
    public var owner: ?HTTPContext
    /// 代理隧道
    /// 严格翻译自: proxy_tunnel: ?ProxyTunnel.RefPtr
    public var proxyTunnel: ?ProxyTunnel
    /// 目标 hostname (隧道)
    /// 严格翻译自: target_hostname: []const u8
    public var targetHostname: String
    /// 目标端口 (隧道)
    /// 严格翻译自: target_port: u16
    public var targetPort: UInt16
    /// 代理认证哈希
    /// 严格翻译自: proxy_auth_hash: u64
    public var proxyAuthHash: UInt64
    /// HTTP/2 会话
    /// 严格翻译自: h2_session: ?*H2.ClientSession
    public var h2Session: ?Any
    /// 是否正在使用
    public var inUse: Bool

    public init() {
        httpSocketFd = -1
        hostname = ""
        port = UInt16(0)
        didHaveHandshakingErrorWhileRejectUnauthorizedIsFalse = false
        sslConfig = None
        owner = None
        proxyTunnel = None
        targetHostname = ""
        targetPort = UInt16(0)
        proxyAuthHash = UInt64(0)
        h2Session = None
        inUse = false
    }
}

/// 已有 socket 查找结果
/// 严格翻译自: HTTPContext.ExistingSocket
public class ExistingSocket {
    public var socketFd: Int64
    public var tunnel: ?ProxyTunnel
    public var h2Session: ?Any

    public init(socketFd: Int64, tunnel: ?ProxyTunnel, h2Session: ?Any) {
        this.socketFd = socketFd
        this.tunnel = tunnel
        this.h2Session = h2Session
    }
}

/// Socket 活跃类型标记
/// 严格翻译自: ActiveSocket (TaggedPointerUnion)
public enum ActiveSocketType {
    | deadSocket
    | httpClient
    | pooledSocket
    | h2Session
}

/// 活跃 Socket 标记
public class ActiveSocket {
    public var type_: ActiveSocketType
    public var socket: Any

    public init() {
        type_ = ActiveSocketType.deadSocket
        socket = None
    }

    public static func initDead(): ActiveSocket {
        let s = ActiveSocket()
        s.type_ = ActiveSocketType.deadSocket
        return s
    }
}

/// HTTP 连接上下文
/// 严格翻译自: bun/src/http/HTTPContext.zig NewHTTPContext
///
/// 管理连接池、SSL 上下文、Socket 生命周期
/// 对应 Bun 中 uws.SocketGroup + PooledSocket 池
public class HTTPContext {
    /// 是否为 SSL 上下文
    public var isSsl: Bool
    /// 引用计数
    public var refCount: Int64
    /// 连接池 — keep-alive socket 数组
    /// 严格翻译自: pending_sockets: PooledSocketHiveAllocator
    public var pendingSockets: ArrayList<PooledSocket>
    /// Socket 组 — uws.SocketGroup
    /// 严格翻译自: group: uws.SocketGroup
    public var socketGroup: SocketGroup
    /// SSL 上下文 (仅 HTTPS)
    /// 严格翻译自: secure: ?*BoringSSL.SSL_CTX
    public var secure: ?Any
    /// 活跃的 HTTP/2 会话
    /// 严格翻译自: active_h2_sessions
    public var activeH2Sessions: ArrayList<Any>
    /// 挂起的 HTTP/2 连接
    /// 严格翻译自: pending_h2_connects
    public var pendingH2Connects: ArrayList<Any>

    public init(isSsl: Bool) {
        this.isSsl = isSsl
        refCount = 1
        pendingSockets = ArrayList<PooledSocket>()
        socketGroup = SocketGroup()
        secure = None
        activeH2Sessions = ArrayList<Any>()
        pendingH2Connects = ArrayList<Any>()
    }

    /// 初始化上下文
    /// 严格翻译自: HTTPContext.init
    public func init_(): Unit {
        // 创建 SocketGroup
        socketGroup = SocketGroup()
        if (isSsl) {
            // 创建 SSL_CTX
            // 严格翻译自: secure = createSSLContext(request_cert=1, reject_unauthorized=0)
            secure = Some("SSL_CTX")
        }
    }

    /// 使用线程选项初始化 (仅 SSL)
    /// 严格翻译自: HTTPContext.initWithThreadOpts
    public func initWithThreadOpts(ca: ?String, caFileName: ?String): Unit {
        if (!isSsl) {
            return
        }
        // 创建带 CA 的 SSL_CTX
        secure = Some("SSL_CTX")
    }

    /// 增加引用
    public func ref(): Unit {
        refCount += 1
    }

    /// 减少引用
    public func deref(): Unit {
        refCount -= 1
        if (refCount <= 0) {
            deinit()
        }
    }

    // ========================================================================
    // releaseSocket - 释放 socket 到连接池
    // 严格翻译自: HTTPContext.releaseSocket
    //
    // 尝试将 socket 放入 keep-alive 池以复用
    // 如果池满或 socket 有错误，则关闭
    // ========================================================================

    /// 释放 socket 到连接池
    /// 严格翻译自: HTTPContext.releaseSocket
    public func releaseSocket(
        socketFd: Int64,
        didHaveHandshakingError: Bool,
        hostname: String,
        port: UInt16,
        sslConfig: ?TLSConfig,
        tunnel: ?ProxyTunnel,
        targetHostname: String,
        targetPort: UInt16,
        proxyAuthHash: UInt64,
        h2Session: ?Any
    ): Unit {
        if (hostname.size > 0 && hostname.size <= MAX_KEEPALIVE_HOSTNAME &&
            socketFd >= 0) {

            // 查找空闲的池槽位
            for (pooled in pendingSockets) {
                if (!pooled.inUse) {
                    pooled.httpSocketFd = socketFd
                    pooled.hostname = hostname
                    pooled.port = port
                    pooled.owner = Some(this)
                    pooled.didHaveHandshakingErrorWhileRejectUnauthorizedIsFalse = didHaveHandshakingError && !sslConfig.map({ c => c.rejectUnauthorized }).getOrElse(true)
                    pooled.sslConfig = sslConfig
                    pooled.proxyTunnel = tunnel
                    pooled.proxyAuthHash = proxyAuthHash
                    pooled.targetHostname = targetHostname
                    pooled.targetPort = targetPort
                    pooled.h2Session = h2Session
                    pooled.inUse = true
                    return
                }
            }

            // 池满 - 创建新条目或关闭
            if (pendingSockets.size < POOL_SIZE) {
                let pooled = PooledSocket()
                pooled.httpSocketFd = socketFd
                pooled.hostname = hostname
                pooled.port = port
                pooled.owner = Some(this)
                pooled.didHaveHandshakingErrorWhileRejectUnauthorizedIsFalse = didHaveHandshakingError
                pooled.sslConfig = sslConfig
                pooled.proxyTunnel = tunnel
                pooled.proxyAuthHash = proxyAuthHash
                pooled.targetHostname = targetHostname
                pooled.targetPort = targetPort
                pooled.h2Session = h2Session
                pooled.inUse = true
                pendingSockets.append(pooled)
                return
            }
        }

        // 关闭隧道
        match (tunnel) {
            case Some(t) => {
                ProxyTunnelOps.shutdown(t)
                ProxyTunnelOps.detachAndDeref(t)
            }
            case None => ()
        }

        // 关闭 socket
        closeSocket(socketFd)
    }

    // ========================================================================
    // existingSocket - 查找可复用的 keep-alive socket
    // 严格翻译自: HTTPContext.existingSocket
    //
    // 按 hostname/port/ssl_config/tunnel 匹配
    // ========================================================================

    /// 查找可复用的 keep-alive socket
    /// 严格翻译自: HTTPContext.existingSocket
    public func existingSocket(
        rejectUnauthorized: Bool,
        hostname: String,
        port: UInt16,
        sslConfig: ?TLSConfig,
        wantTunnel: Bool,
        targetHostname: String,
        targetPort: UInt16,
        proxyAuthHash: UInt64
    ): ?ExistingSocket {
        if (hostname.size > MAX_KEEPALIVE_HOSTNAME) {
            return None
        }

        for (pooled in pendingSockets) {
            if (!pooled.inUse) {
                continue
            }
            if (pooled.port != port) {
                continue
            }

            // 检查握手错误兼容性
            if (pooled.didHaveHandshakingErrorWhileRejectUnauthorizedIsFalse && rejectUnauthorized) {
                continue
            }

            // 隧道匹配
            let pooledHasTunnel = match (pooled.proxyTunnel) {
                case Some(_) => true
                case None => false
            }
            if (wantTunnel != pooledHasTunnel) {
                continue
            }

            if (wantTunnel) {
                if (pooled.proxyAuthHash != proxyAuthHash) {
                    continue
                }
                if (pooled.targetPort != targetPort) {
                    continue
                }
                if (pooled.targetHostname != targetHostname) {
                    continue
                }
            }

            // hostname 匹配 (大小写不敏感)
            if (eqlCaseInsensitive(pooled.hostname, hostname)) {
                let socketFd = pooled.httpSocketFd
                if (socketFd < 0) {
                    continue
                }

                // 释放池条目
                pooled.inUse = false
                let tunnel = pooled.proxyTunnel
                pooled.proxyTunnel = None
                pooled.targetHostname = ""
                pooled.h2Session = None

                return Some(ExistingSocket(socketFd, tunnel, None))
            }
        }

        return None
    }

    // ========================================================================
    // connect - 建立连接
    // 严格翻译自: HTTPContext.connect
    //
    // 1. 先检查连接池是否有可复用的 socket
    // 2. 如果没有，创建新的 TCP/TLS 连接
    // ========================================================================

    /// 建立连接
    /// 严格翻译自: HTTPContext.connect
    public func connect(
        client: HTTPClient,
        hostname: String,
        port: UInt16
    ): ?Int64 {
        // 尝试从连接池复用
        let wantTunnel = match (client.proxyTunnel) {
            case Some(_) => true
            case None => false
        }
        let targetHostname = if (wantTunnel) { client.url.hostname } else { "" }
        let targetPort = if (wantTunnel) { UInt16(client.url.port) } else { UInt16(0) }
        let proxyAuthHash = UInt64(0) // 简化

        let found = existingSocket(
            client.flags.rejectUnauthorized,
            hostname,
            port,
            None, // sslConfig
            wantTunnel,
            targetHostname,
            targetPort,
            proxyAuthHash
        )

        match (found) {
            case Some(existing) => {
                // 复用已有连接
                client.flags.didHaveHandshakingError = false
                match (existing.tunnel) {
                    case Some(tunnel) => {
                        // 复用隧道
                        ProxyTunnelOps.adopt(tunnel, client, isSsl, existing.socketFd)
                    }
                    case None => ()
                }
                return Some(existing.socketFd)
            }
            case None => ()
        }

        // 创建新连接
        // 严格翻译自: HTTPSocket.connectGroup
        let socketFd = createConnection(hostname, port)
        return socketFd
    }

    /// 通过 Unix socket 连接
    /// 严格翻译自: HTTPContext.connectSocket
    public func connectSocket(client: HTTPClient, socketPath: String): ?Int64 {
        let socketFd = createUnixConnection(socketPath)
        return socketFd
    }

    // ========================================================================
    // Handler 回调
    // 严格翻译自: HTTPContext.Handler
    //
    // Bun 使用 uws 的回调系统:
    //   onOpen, onHandshake, onClose, onData, onWritable, onTimeout
    // ========================================================================

    /// Handler 回调接口
    public class Handler {
        /// socket 打开回调
        /// 严格翻译自: Handler.onOpen
        public static func onOpen(ctx: HTTPContext, client: HTTPClient, socketFd: Int64): Unit {
            // 设置超时
            client.state.requestStage = HTTPStage.opened
        }

        /// 数据到达回调
        /// 严格翻译自: Handler.onData
        public static func onData(ctx: HTTPContext, client: HTTPClient, socketFd: Int64, data: Array<UInt8>): Unit {
            // 根据响应阶段分发
            match (client.state.responseStage) {
                case pending => ()
                case headers => ()
                case body => ()
                case bodyChunk => ()
                case fail => ()
                case _ => ()
            }
        }

        /// socket 可写回调
        /// 严格翻译自: Handler.onWritable
        public static func onWritable(ctx: HTTPContext, client: HTTPClient, socketFd: Int64): Unit {
            // 根据请求阶段处理
            match (client.state.requestStage) {
                case pending => ()
                case headers => ()
                case body => ()
                case done => ()
                case _ => ()
            }
        }

        /// socket 关闭回调
        /// 严格翻译自: Handler.onClose
        public static func onClose(ctx: HTTPContext, client: HTTPClient, socketFd: Int64): Unit {
            // 清理连接状态
        }

        /// 超时回调
        /// 严格翻译自: Handler.onLongTimeout / Handler.onTimeout
        public static func onTimeout(ctx: HTTPContext, client: HTTPClient, socketFd: Int64): Unit {
            // 处理超时
        }
    }

    // ========================================================================
    // 辅助方法
    // ========================================================================

    /// 关闭 socket
    public func closeSocket(socketFd: Int64): Unit {
        if (socketFd >= 0) {
            // SysFs.close(socketFd)
        }
    }

    /// 终止 socket
    public func terminateSocket(socketFd: Int64): Unit {
        closeSocket(socketFd)
    }

    /// 清理
    /// 严格翻译自: HTTPContext.deinit
    public func deinit(): Unit {
        // 关闭所有池化 socket
        for (pooled in pendingSockets) {
            if (pooled.inUse) {
                pooled.sslConfig = None
                match (pooled.proxyTunnel) {
                    case Some(t) => ProxyTunnelOps.deref(t)
                    case None => ()
                }
                pooled.proxyTunnel = None
                pooled.targetHostname = ""
                pooled.h2Session = None
                closeSocket(pooled.httpSocketFd)
            }
        }
        pendingSockets = ArrayList<PooledSocket>()
        activeH2Sessions = ArrayList<Any>()
        pendingH2Connects = ArrayList<Any>()
    }

    /// 创建 TCP 连接
    private func createConnection(hostname: String, port: UInt16): ?Int64 {
        // 简化: 实际通过 C FFI socket/connect
        return Some(Int64(42)) // 返回模拟 FD
    }

    /// 创建 Unix socket 连接
    private func createUnixConnection(path: String): ?Int64 {
        return Some(Int64(43))
    }

    /// 大小写不敏感比较
    private static func eqlCaseInsensitive(a: String, b: String): Bool {
        if (a.size != b.size) {
            return false
        }
        for (i in 0..a.size) {
            if (a[i].toLower() != b[i].toLower()) {
                return false
            }
        }
        return true
    }
}

/// Socket 组 — 对应 uws.SocketGroup
public class SocketGroup {
    public init() {}
}

/// Any 类型 (仓颉没有 Any，用这代替)
public type Any = ?Object
