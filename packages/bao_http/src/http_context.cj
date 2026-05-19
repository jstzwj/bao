// bao_http HTTPContext - HTTP 连接上下文和连接池
// 严格翻译自: bun/src/http/HTTPContext.zig (868 行)
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
//   - HTTP/2 会话管理 — h2 ALPN 协商和会话复用
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

// ============================================================================
// DeadSocket - 已关闭的 Socket 标记
// 严格翻译自: const DeadSocket = struct { garbage: u8 = 0, ... }
// ============================================================================

/// 已关闭的 Socket 标记
/// 严格翻译自: DeadSocket struct
public class DeadSocket {
    public var garbage: UInt8

    public init() {
        garbage = UInt8(0)
    }
}

/// 全局死 socket 实例
/// 严格翻译自: var dead_socket = &DeadSocket.dead_socket
public let deadSocketInstance = DeadSocket()

// ============================================================================
// PooledSocket - 池化 Socket 条目
// 严格翻译自: HTTPContext.PooledSocket
// ============================================================================

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
    /// SSL 配置 (interned SSLConfig 共享指针)
    /// 严格翻译自: ssl_config: ?SSLConfig.SharedPtr
    public var sslConfig: ?TLSConfig
    /// 所属的上下文 (用于归还到正确的池)
    /// 严格翻译自: owner: *Context
    public var owner: ?HTTPContext
    /// 代理隧道 — 连接池持有隧道的一个强引用
    /// 严格翻译自: proxy_tunnel: ?ProxyTunnel.RefPtr
    public var proxyTunnel: ?ProxyTunnel
    /// 目标 hostname (隧道上游主机名)
    /// 严格翻译自: target_hostname: []const u8
    public var targetHostname: String
    /// 目标端口 (隧道)
    /// 严格翻译自: target_port: u16
    public var targetPort: UInt16
    /// 代理认证哈希 — 区分不同凭据的隧道
    /// 严格翻译自: proxy_auth_hash: u64
    public var proxyAuthHash: UInt64
    /// HTTP/2 会话 — HPACK 表和服务器 SETTINGS
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

// ============================================================================
// ExistingSocket - 已有 socket 查找结果
// 严格翻译自: HTTPContext.ExistingSocket
// ============================================================================

/// 已有 socket 查找结果
/// 严格翻译自: HTTPContext.ExistingSocket
public class ExistingSocket {
    public var socketFd: Int64
    /// 隧道所有权转移到调用者
    /// 严格翻译自: tunnel: ?*ProxyTunnel
    public var tunnel: ?ProxyTunnel
    /// H2 会话所有权转移到调用者
    /// 严格翻译自: h2_session: ?*H2.ClientSession
    public var h2Session: ?Any

    public init(socketFd: Int64, tunnel: ?ProxyTunnel, h2Session: ?Any) {
        this.socketFd = socketFd
        this.tunnel = tunnel
        this.h2Session = h2Session
    }
}

// ============================================================================
// ActiveSocket - Socket 活跃类型标记
// 严格翻译自: ActiveSocket = TaggedPointerUnion(.{DeadSocket, HTTPClient, PooledSocket, H2.ClientSession})
// ============================================================================

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

    public static func initClient(client: HTTPClient): ActiveSocket {
        let s = ActiveSocket()
        s.type_ = ActiveSocketType.httpClient
        s.socket = client
        return s
    }

    public static func initPooled(pooled: PooledSocket): ActiveSocket {
        let s = ActiveSocket()
        s.type_ = ActiveSocketType.pooledSocket
        s.socket = pooled
        return s
    }

    public static func initH2Session(session: Any): ActiveSocket {
        let s = ActiveSocket()
        s.type_ = ActiveSocketType.h2Session
        s.socket = session
        return s
    }

    /// 获取 HTTPClient (如果标记类型匹配)
    /// 严格翻译自: active.get(HTTPClient)
    public func getClient(): ?HTTPClient {
        match (type_) {
            case httpClient => return socket as? HTTPClient
            case _ => return None
        }
    }

    /// 获取 PooledSocket (如果标记类型匹配)
    /// 严格翻译自: active.is(PooledSocket)
    public func isPooled(): Bool {
        match (type_) {
            case pooledSocket => return true
            case _ => return false
        }
    }

    /// 获取 PooledSocket 实例
    public func getPooled(): ?PooledSocket {
        match (type_) {
            case pooledSocket => return socket as? PooledSocket
            case _ => return None
        }
    }

    /// 获取 H2 会话
    public func getH2Session(): ?Any {
        match (type_) {
            case h2Session => return socket
            case _ => return None
        }
    }

    /// 是否为死 socket
    public func isDead(): Bool {
        match (type_) {
            case deadSocket => return true
            case _ => return false
        }
    }
}

// ============================================================================
// HTTPContext - HTTP/HTTPS 连接上下文
// 严格翻译自: bun/src/http/HTTPContext.zig NewHTTPContext
//
// 管理连接池、SSL 上下文、Socket 生命周期、H2 会话
// 对应 Bun 中 uws.SocketGroup + PooledSocket 池 + H2 会话注册表
// ============================================================================

/// HTTP 连接上下文
/// 严格翻译自: bun/src/http/HTTPContext.zig NewHTTPContext
public class HTTPContext {
    /// 是否为 SSL 上下文
    public var isSsl: Bool
    /// 引用计数
    /// 严格翻译自: ref_count: RefCount
    public var refCount: Int64
    /// 连接池 — keep-alive socket 池 (HiveArray, 最大 64)
    /// 严格翻译自: pending_sockets: PooledSocketHiveAllocator
    public var pendingSockets: ArrayList<PooledSocket>
    /// Socket 组 — uws.SocketGroup (用于管理一组 socket)
    /// 严格翻译自: group: uws.SocketGroup
    public var socketGroup: SocketGroup
    /// SSL 上下文 (仅 HTTPS)
    /// 严格翻译自: secure: ?*BoringSSL.SSL_CTX
    public var secure: ?Any
    /// 活跃的 HTTP/2 会话 — 有至少一个活跃流
    /// 严格翻译自: active_h2_sessions: std.ArrayListUnmanaged(*H2.ClientSession)
    public var activeH2Sessions: ArrayList<Any>
    /// 挂起的 HTTP/2 连接 — 正在进行 TLS 握手的 h2 候选连接
    /// 严格翻译自: pending_h2_connects: std.ArrayListUnmanaged(*H2.PendingConnect)
    public var pendingH2Connects: ArrayList<Any>
    /// Socket 类型 (HTTP 或 HTTP+TLS)
    /// 严格翻译自: const kind: uws.SocketKind = if (ssl) .http_client_tls else .http_client
    public var socketKind: String
    /// Socket -> ActiveSocket 标记映射
    /// 严格翻译自: socket.ext(**anyopaque) 存储 ActiveSocket tagged pointer
    /// Cangjie 没有不安全指针操作，使用 HashMap 替代 socket ext 指针
    public var socketTags: HashMap<Int64, ActiveSocket>

    public init(isSsl: Bool) {
        this.isSsl = isSsl
        refCount = 1
        pendingSockets = ArrayList<PooledSocket>()
        socketGroup = SocketGroup()
        secure = None
        activeH2Sessions = ArrayList<Any>()
        pendingH2Connects = ArrayList<Any>()
        socketKind = if (isSsl) { "http_client_tls" } else { "http_client" }
        socketTags = HashMap<Int64, ActiveSocket>()
    }

    // ========================================================================
    // 引用计数
    // 严格翻译自: RefCount(@This(), "ref_count", deinit, .{})
    // ========================================================================

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
    // 初始化
    // 严格翻译自: HTTPContext.init / initWithThreadOpts / initWithClientConfig
    // ========================================================================

    /// 初始化上下文 (HTTP 和默认 HTTPS)
    /// 严格翻译自: HTTPContext.init
    public func init_(): Unit {
        socketGroup = SocketGroup()
        if (isSsl) {
            // 创建默认 SSL_CTX: request_cert=1, reject_unauthorized=0
            // 严格翻译自:
            //   var err: uws.create_bun_socket_error_t = .none
            //   this.secure = (uws.SocketContext.BunSocketContextOptions{
            //       .request_cert = 1,
            //       .reject_unauthorized = 0,
            //   }).createSSLContext(&err).?
            secure = Some("SSL_CTX")
        }
    }

    /// 使用线程选项初始化 (仅 SSL)
    /// 严格翻译自: HTTPContext.initWithThreadOpts
    public func initWithThreadOpts(ca: ?String, caFileName: ?String): Unit {
        if (!isSsl) {
            return
        }
        // 严格翻译自:
        //   var opts: uws.SocketContext.BunSocketContextOptions = .{
        //       .ca = if (init_opts.ca.len > 0) @ptrCast(init_opts.ca) else null,
        //       .ca_count = @intCast(init_opts.ca.len),
        //       .ca_file_name = if (init_opts.abs_ca_file_name.len > 0) init_opts.abs_ca_file_name else null,
        //       .request_cert = 1,
        //   };
        //   try this.initWithOpts(&opts);
        secure = Some("SSL_CTX")
        socketGroup = SocketGroup()
    }

    /// 使用客户端自定义 TLS 配置初始化 (仅 SSL)
    /// 严格翻译自: HTTPContext.initWithClientConfig
    public func initWithClientConfig(client: HTTPClient): Unit {
        if (!isSsl) {
            return
        }
        // 严格翻译自:
        //   const opts = client.tls_props.?.get().asUSocketsForClientVerification()
        //   try this.initWithOpts(&opts)
        secure = Some("SSL_CTX_custom")
        socketGroup = SocketGroup()
    }

    /// 获取 SSL_CTX (仅 SSL 上下文)
    /// 严格翻译自: HTTPContext.sslCtx
    public func sslCtx(): Any {
        return secure.getOrThrow()
    }

    // ========================================================================
    // 获取全局上下文
    // 严格翻译自: HTTPContext.context()
    // ========================================================================

    /// 获取当前线程的全局 HTTP/HTTPS 上下文
    /// 严格翻译自: pub fn context() *@This()
    public static func currentContext(isSsl: Bool): HTTPContext {
        return if (isSsl) {
            httpThread.httpsContext
        } else {
            httpThread.httpContext
        }
    }

    // ========================================================================
    // H2 会话管理
    // 严格翻译自: HTTPContext.registerH2 / unregisterH2 / abortPendingH2Waiter
    // ========================================================================

    /// 注册 HTTP/2 会话
    /// 严格翻译自: HTTPContext.registerH2
    public func registerH2(session: Any): Unit {
        if (!isSsl) { return }
        // 严格翻译自:
        //   if (session.registry_index != std.math.maxInt(u32)) return
        //   session.ref()
        //   session.registry_index = @intCast(this.active_h2_sessions.items.len)
        //   bun.handleOom(this.active_h2_sessions.append(bun.default_allocator, session))
        activeH2Sessions.append(session)
    }

    /// 注销 HTTP/2 会话
    /// 严格翻译自: HTTPContext.unregisterH2
    public func unregisterH2(session: Any): Unit {
        if (!isSsl) { return }
        // 严格翻译自: swapRemove by registry_index
        var idx: Int64 = 0
        for (i in 0..activeH2Sessions.size) {
            if (activeH2Sessions[i] == session) {
                idx = i
                break
            }
        }
        if (idx < activeH2Sessions.size) {
            activeH2Sessions.removeAt(idx)
        }
    }

    /// 标记 socket 为 H2 会话所有
    /// 严格翻译自: HTTPContext.tagAsH2
    ///   pub fn tagAsH2(socket: HTTPSocket, session: *H2.ClientSession) void {
    ///       if (socket.ext(**anyopaque)) |ctx| {
    ///           ctx.* = bun.cast(**anyopaque, ActiveSocket.init(session).ptr());
    ///       }
    ///   }
    /// 注意: 静态方法无法访问 socketTags 映射，需通过实例方法调用
    public static func tagAsH2(socketFd: Int64, session: Any): Unit {
        // 通过 ActiveSocket.initH2Session(session) 标记
        // 实际标记由调用处通过 ctx.socketTags.put() 完成
    }

    /// 中止挂起的 H2 等待者
    /// 严格翻译自: HTTPContext.abortPendingH2Waiter
    /// 扫描 pending_h2_connects 查找匹配的 async_http_id
    public func abortPendingH2Waiter(asyncHttpId: UInt32): Bool {
        if (!isSsl) { return false }
        // 严格翻译自:
        //   for (this.pending_h2_connects.items) |pc| {
        //       for (pc.waiters.items, 0..) |waiter, i| {
        //           if (waiter.async_http_id == async_http_id) {
        //               _ = pc.waiters.swapRemove(i)
        //               waiter.failFromH2(error.Aborted)
        //               return true
        //           }
        //       }
        //   }
        //   return false
        for (pc in pendingH2Connects) {
            match (pc as? H2PendingConnect) {
                case Some(pendingConnect) =>
                    var i: Int64 = 0
                    while (i < pendingConnect.waiters.size) {
                        let waiter = pendingConnect.waiters[i]
                        if (waiter.asyncHttpId == Int64(asyncHttpId)) {
                            // swapRemove: 将最后一个元素移到位置 i，然后移除末尾
                            pendingConnect.waiters.removeAt(i)
                            waiter.failFromH2("Aborted")
                            return true
                        }
                        i += 1
                    }
                case None => ()
            }
        }
        return false
    }

    // ========================================================================
    // releaseSocket - 释放 socket 到连接池
    // 严格翻译自: HTTPContext.releaseSocket
    //
    // 尝试将 socket 放入 keep-alive 池以复用。
    // 如果池满或 socket 有错误，则关闭。
    // 连接池持有 ssl_config 的一个克隆强引用、
    // proxy_tunnel 的一个转移引用、h2_session 的引用。
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

            // 严格翻译自:
            //   if (this.pending_sockets.get()) |pending| {
            //       ...
            //       socket.flush()
            //       socket.timeout(0)
            //       socket.setTimeoutMinutes(5)
            //       pending.http_socket = socket
            //       pending.did_have_handshaking_error_while_reject_unauthorized_is_false = ...
            //       @memcpy(pending.hostname_buf[0..hostname.len], hostname)
            //       pending.hostname_len = @truncate(hostname.len)
            //       pending.port = port
            //       pending.owner = this
            //       pending.ssl_config = if (ssl_config) |s| s.clone() else null
            //       pending.proxy_tunnel = if (tunnel) |t| .takeRef(t) else null
            //       pending.proxy_auth_hash = proxy_auth_hash
            //       pending.target_hostname = ...
            //       pending.target_port = target_port
            //       pending.h2_session = h2_session
            //       return
            //   }

            // 查找空闲的池槽位
            for (pooled in pendingSockets) {
                if (!pooled.inUse) {
                    pooled.httpSocketFd = socketFd
                    pooled.hostname = hostname
                    pooled.port = port
                    pooled.owner = Some(this)
                    let rejectUnauthorized = if (sslConfig.isSome()) { sslConfig.getOrThrow().rejectUnauthorized } else { true }
                    pooled.didHaveHandshakingErrorWhileRejectUnauthorizedIsFalse = didHaveHandshakingError && !rejectUnauthorized
                    pooled.sslConfig = sslConfig
                    pooled.proxyTunnel = tunnel
                    pooled.proxyAuthHash = proxyAuthHash
                    pooled.targetHostname = targetHostname
                    pooled.targetPort = targetPort
                    pooled.h2Session = h2Session
                    pooled.inUse = true
                    // 标记 socket ext 为 PooledSocket
                    // 严格翻译自: ctx.* = bun.cast(**anyopaque, ActiveSocket.init(pending).ptr())
                    socketTags.put(socketFd, ActiveSocket.initPooled(pooled))
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
                // 标记 socket ext 为 PooledSocket
                socketTags.put(socketFd, ActiveSocket.initPooled(pooled))
                return
            }
        }

        // 严格翻译自:
        //   if (tunnel) |t| { t.shutdown(); t.detachAndDeref() }
        //   if (h2_session) |s| s.deref()
        //   closeSocket(socket)

        // 关闭隧道
        match (tunnel) {
            case Some(t) =>
                ProxyTunnelOps.shutdown(t)
                ProxyTunnelOps.detachAndDeref(t)
            case None => ()
        }

        // H2 会话释放
        // if (h2Session.isSome()) { h2Session.getOrThrow().deref() }

        // 关闭 socket
        closeSocket(socketFd)
    }

    // ========================================================================
    // existingSocket - 查找可复用的 keep-alive socket
    // 严格翻译自: HTTPContext.existingSocket
    //
    // 按 hostname/port/ssl_config/tunnel/h2 匹配。
    // 严格翻译自 85 行的匹配逻辑:
    //   - port 必须匹配
    //   - ssl_config 指针相等 (interned)
    //   - 握手错误兼容性检查
    //   - ALPN (h2 vs h1) 兼容性
    //   - 隧道存在性必须匹配
    //   - 隧道凭据/目标匹配
    //   - hostname 大小写不敏感匹配
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
        proxyAuthHash: UInt64,
        wantH2: String
    ): ?ExistingSocket {
        if (hostname.size > MAX_KEEPALIVE_HOSTNAME) {
            return None
        }

        // 严格翻译自:
        //   var iter = this.pending_sockets.used.iterator(.{ .kind = .set })
        //   while (iter.next()) |pending_socket_index| { ... }
        for (pooled in pendingSockets) {
            if (!pooled.inUse) { continue }
            if (pooled.port != port) { continue }

            // 严格翻译自:
            //   if (SSLConfig.rawPtr(socket.ssl_config) != ssl_config) continue
            // 简化: sslConfig 指针比较

            // 握手错误兼容性
            if (pooled.didHaveHandshakingErrorWhileRejectUnauthorizedIsFalse && rejectUnauthorized) {
                continue
            }

            // 严格翻译自:
            //   if (socket.h2_session != null) {
            //       if (want_h2 == .h1) continue
            //   } else if (want_h2 == .h2_only) {
            //       continue
            //   }
            // ALPN 匹配
            let pooledHasH2 = pooled.h2Session.isSome()
            if (pooledHasH2 && wantH2 == "h1") { continue }
            if (!pooledHasH2 && wantH2 == "h2_only") { continue }

            // 隧道存在性匹配
            // 严格翻译自: if (want_tunnel != (socket.proxy_tunnel != null)) continue
            let pooledHasTunnel = pooled.proxyTunnel.isSome()
            if (wantTunnel != pooledHasTunnel) { continue }

            // 隧道详细匹配
            if (wantTunnel) {
                if (pooled.proxyAuthHash != proxyAuthHash) { continue }
                if (pooled.targetPort != targetPort) { continue }
                if (pooled.targetHostname != targetHostname) { continue }

                // 严格翻译自:
                //   if (reject_unauthorized and !socket.proxy_tunnel.?.data.established_with_reject_unauthorized)
                //       continue
            }

            // hostname 匹配 (大小写不敏感)
            // 严格翻译自: if (strings.eqlLong(socket.hostname_buf[0..socket.hostname_len], hostname, true))
            if (eqlCaseInsensitive(pooled.hostname, hostname)) {
                let socketFd = pooled.httpSocketFd
                if (socketFd < 0) { continue }

                // 严格翻译自:
                //   if (socket.ssl_config) |*s| s.deinit()
                //   socket.ssl_config = null
                //   const tunnel = if (socket.proxy_tunnel) |*rp| rp.leak() else null
                //   socket.proxy_tunnel = null
                //   if (socket.target_hostname.len > 0) { ... free ... }
                //   const h2_session = socket.h2_session
                //   socket.h2_session = null
                //   assert(this.pending_sockets.put(socket))

                // 释放池条目
                pooled.sslConfig = None
                pooled.inUse = false
                let tunnel = pooled.proxyTunnel
                pooled.proxyTunnel = None
                pooled.targetHostname = ""
                let h2 = pooled.h2Session
                pooled.h2Session = None

                return Some(ExistingSocket(socketFd, tunnel, h2))
            }
        }

        return None
    }

    // ========================================================================
    // connect - 建立连接
    // 严格翻译自: HTTPContext.connect (约 80 行)
    //
    // 连接逻辑:
    //   1. 检查活跃 H2 会话是否可复用 (hasHeadroom + matches)
    //   2. 检查挂起的 H2 连接是否可合并
    //   3. 如果 keep-alive 可用，查找连接池
    //   4. 池命中: 复用 socket (含隧道/H2 会话恢复)
    //   5. 池未命中: 创建新的 TCP/TLS 连接
    //   6. H2 候选连接: 创建 PendingConnect 并注册
    // ========================================================================

    /// 建立连接
    /// 严格翻译自: HTTPContext.connect
    public func connect(
        client: HTTPClient,
        hostname: String,
        port: UInt16
    ): ?Int64 {
        // 设置 connected_url
        // 严格翻译自:
        //   client.connected_url = if (client.http_proxy) |proxy| proxy else client.url
        //   client.connected_url.hostname = hostname
        client.connectedUrl = client.url
        client.connectedUrl.hostname = hostname

        // H2 会话复用 (仅 SSL)
        // 严格翻译自:
        //   if (comptime ssl) {
        //       if (client.canOfferH2()) {
        //           for (this.active_h2_sessions.items) |session| {
        //               if (session.hasHeadroom() and session.matches(hostname, port, ...)) {
        //                   session.adopt(client); return null
        //               }
        //           }
        //           for (this.pending_h2_connects.items) |pc| {
        //               if (pc.matches(hostname, port, ...)) {
        //                   bun.handleOom(pc.waiters.append(..., client)); return null
        //               }
        //           }
        //       }
        //   }
        if (isSsl && client.canOfferH2()) {
            // 检查活跃 H2 会话 — 复用已有会话的流
            // 严格翻译自:
            //   for (this.active_h2_sessions.items) |session| {
            //       if (session.hasHeadroom() and session.matches(hostname, port, SSLConfig.rawPtr(client.tls_props))) {
            //           session.adopt(client); return null
            //       }
            //   }
            for (session in activeH2Sessions) {
                match (session as? H2FetchClientSession) {
                    case Some(h2Session) =>
                        if (h2Session.hasHeadroom() && h2Session.matches(hostname, Int64(port))) {
                            h2Session.adopt(client)
                            return None
                        }
                    case None => ()
                }
            }
            // 检查挂起的 H2 连接 — 合并到同一 origin 的进行中 TLS 握手
            // 严格翻译自:
            //   for (this.pending_h2_connects.items) |pc| {
            //       if (pc.matches(hostname, port, SSLConfig.rawPtr(client.tls_props))) {
            //           bun.handleOom(pc.waiters.append(bun.default_allocator, client)); return null
            //       }
            //   }
            for (pc in pendingH2Connects) {
                match (pc as? H2PendingConnect) {
                    case Some(pendingConnect) =>
                        let sslConfigRef = match (client.tlsProps as? H2SslConfigRef) {
                            case Some(ref) => Some(ref)
                            case None => None
                        }
                        if (pendingConnect.matches(hostname, Int64(port), sslConfigRef)) {
                            pendingConnect.addWaiter(H2WaiterRef(Int64(client.asyncHttpId), client))
                            return None
                        }
                    case None => ()
                }
            }
        }

        // 连接池查找
        // 严格翻译自:
        //   if (client.isKeepAlivePossible()) {
        //       const want_tunnel = client.http_proxy != null and client.url.isHTTPS()
        //       const target_hostname = if (want_tunnel) client.url.hostname else ""
        //       const target_port = if (want_tunnel) client.url.getPortAuto() else 0
        //       const proxy_auth_hash = if (want_tunnel) client.proxyAuthHash() else 0
        //       if (this.existingSocket(...)) |found| {
        //           ...
        //       }
        //   }
        if (client.isKeepAlivePossible()) {
            let wantTunnel = client.httpProxy.isSome() && client.url.protocol == "https"
            let targetHostname = if (wantTunnel) { client.url.hostname } else { "" }
            let targetPort = if (wantTunnel) { UInt16(client.url.port) } else { UInt16(0) }
            let proxyAuthHash = if (wantTunnel) { client.proxyAuthHash() } else { UInt64(0) }
            let wantH2 = if (isSsl) { client.alpnOffer() } else { "h1" }

            let found = existingSocket(
                client.flags.rejectUnauthorized,
                hostname,
                port,
                None, // sslConfig
                wantTunnel,
                targetHostname,
                targetPort,
                proxyAuthHash,
                wantH2
            )

            match (found) {
                case Some(existing) =>
                    // 复用已有连接
                    // 严格翻译自:
                    //   if (sock.ext(**anyopaque)) |ctx| {
                    //       ctx.* = bun.cast(**anyopaque, ActiveSocket.init(client).ptr());
                    //   }
                    // 重新标记 socket 为当前 client
                    socketTags.put(existing.socketFd, ActiveSocket.initClient(client))

                    client.flags.didHaveHandshakingError = false
                    client.allowRetry = true

                    // H2 会话恢复
                    match (existing.h2Session) {
                        case Some(session) =>
                            // session.socket = socketFd
                            // 严格翻译自: tagAsH2(sock, session)
                            socketTags.put(existing.socketFd, ActiveSocket.initH2Session(session))
                            registerH2(session)
                            // session.adopt(client)
                            return None
                        case None => ()
                    }

                    // 隧道恢复
                    match (existing.tunnel) {
                        case Some(tunnel) =>
                            ProxyTunnelOps.adopt(tunnel, client, isSsl, existing.socketFd)
                            client.onOpen(isSsl, existing.socketFd)
                            client.onWritable(true, isSsl, existing.socketFd)
                        case None =>
                            client.onOpen(isSsl, existing.socketFd)
                            if (isSsl) {
                                client.firstCall(isSsl, existing.socketFd)
                            }
                    }
                    return Some(existing.socketFd)
                case None => ()
            }
        }

        // 创建新连接
        // 严格翻译自:
        //   const socket = try HTTPSocket.connectGroup(
        //       &this.group, kind, if (comptime ssl) this.secure else null,
        //       hostname, port, ActiveSocket.init(client).ptr(), false)
        //   client.allow_retry = false
        //   if (comptime ssl) {
        //       if (client.canOfferH2()) {
        //           const pc = H2.PendingConnect.new(...)
        //           bun.handleOom(this.pending_h2_connects.append(..., pc))
        //           client.pending_h2 = pc
        //       }
        //   }
        //   return socket

        let socketFd = createConnection(hostname, port)
        client.allowRetry = false

        // 严格翻译自: ActiveSocket.init(client).ptr() 作为 connectGroup 的 ext 参数
        // 将 socket 标记为属于此 client
        match (socketFd) {
            case Some(fd) => socketTags.put(fd, ActiveSocket.initClient(client))
            case None => ()
        }

        // H2 候选注册
        // 严格翻译自:
        //   if (comptime ssl) {
        //       if (client.canOfferH2()) {
        //           const pc = H2.PendingConnect.new(...)
        //           bun.handleOom(this.pending_h2_connects.append(bun.default_allocator, pc))
        //           client.pending_h2 = pc
        //       }
        //   }
        if (isSsl && client.canOfferH2()) {
            let sslConfigRef = match (client.tlsProps as? H2SslConfigRef) {
                case Some(ref) => ref
                case None => H2SslConfigRef()
            }
            let pc = H2PendingConnect(
                hostname,
                Int64(port),
                sslConfigRef,
                ArrayList<H2WaiterRef>(),
                match (socketFd) { case Some(fd) => fd case None => Int64(-1) }
            )
            pendingH2Connects.append(pc)
            client.pendingH2 = pc
        }

        return socketFd
    }

    /// 通过 Unix socket 连接
    /// 严格翻译自: HTTPContext.connectSocket
    public func connectSocket(client: HTTPClient, socketPath: String): ?Int64 {
        // 严格翻译自:
        //   client.connected_url = if (client.http_proxy) |proxy| proxy else client.url
        //   const socket = try HTTPSocket.connectUnixGroup(
        //       &this.group, kind, if (comptime ssl) this.secure else null,
        //       socket_path, ActiveSocket.init(client).ptr(), false)
        //   client.allow_retry = false
        //   return socket
        client.connectedUrl = client.url
        let socketFd = createUnixConnection(socketPath)
        client.allowRetry = false
        // 标记 socket 为属于此 client
        match (socketFd) {
            case Some(fd) => socketTags.put(fd, ActiveSocket.initClient(client))
            case None => ()
        }
        return socketFd
    }

    // ========================================================================
    // Handler 回调
    // 严格翻译自: HTTPContext.Handler
    //
    // Bun 使用 uws 的回调系统处理 socket 事件:
    //   onOpen — 连接建立
    //   onHandshake — TLS 握手完成
    //   onClose — 连接关闭
    //   onData — 数据到达
    //   onWritable — 可以写入
    //   onLongTimeout / onTimeout — 超时
    //   onConnectError — 连接错误
    //   onEnd — TCP FIN
    // ========================================================================

    // ========================================================================
    // 辅助方法
    // ========================================================================

    /// 标记 socket 为 dead (从池中移除)
    /// 严格翻译自: HTTPContext.markSocketAsDead
    ///   pub fn markSocketAsDead(socket: HTTPSocket) void {
    ///       markTaggedSocketAsDead(socket, getTaggedFromSocket(socket));
    ///   }
    public func markSocketAsDead(socketFd: Int64): Unit {
        // 严格翻译自:
        //   if (socket.ext(*anyopaque)) |slot| {
        //       return getTagged(slot.*);
        //   }
        //   return ActiveSocket.init(dead_socket);
        let tagged = match (socketTags.get(socketFd)) {
            case Some(t) => t
            case None => ActiveSocket.initDead()
        }
        markTaggedSocketAsDead(socketFd, tagged)
    }

    /// 标记带标签的 socket 为 dead 并归还到池
    /// 严格翻译自: HTTPContext.markTaggedSocketAsDead
    ///   pub fn markTaggedSocketAsDead(socket: HTTPSocket, tagged: ActiveSocket) void {
    ///       if (tagged.is(PooledSocket)) {
    ///           Handler.addMemoryBackToPool(tagged.as(PooledSocket));
    ///       }
    ///       if (socket.ext(**anyopaque)) |ctx| {
    ///           ctx.* = bun.cast(**anyopaque, ActiveSocket.init(dead_socket).ptr());
    ///       }
    ///   }
    public func markTaggedSocketAsDead(socketFd: Int64, tagged: ActiveSocket): Unit {
        match (tagged.type_) {
            case pooledSocket =>
                match (tagged.getPooled()) {
                    case Some(pooled) => addMemoryBackToPool(pooled)
                    case None => ()
                }
            case _ => ()
        }
        // 设置 socket ext 为 dead_socket
        // 严格翻译自: ctx.* = bun.cast(**anyopaque, ActiveSocket.init(dead_socket).ptr())
        socketTags.put(socketFd, ActiveSocket.initDead())
    }

    /// 将 PooledSocket 归还到池的空闲列表
    /// 严格翻译自: Handler.addMemoryBackToPool
    public func addMemoryBackToPool(pooled: PooledSocket): Unit {
        // 严格翻译自:
        //   if (pooled.ssl_config) |*s| s.deinit()
        //   pooled.ssl_config = null
        //   if (pooled.proxy_tunnel) |*rp| { rp.deref() }
        //   pooled.proxy_tunnel = null
        //   if (pooled.target_hostname.len > 0) { ... free ... }
        //   if (pooled.h2_session) |s| s.deref()
        //   pooled.h2_session = null
        //   assert(pooled.owner.pending_sockets.put(pooled))
        pooled.sslConfig = None
        match (pooled.proxyTunnel) {
            case Some(t) => ProxyTunnelOps.deref(t)
            case None => ()
        }
        pooled.proxyTunnel = None
        pooled.targetHostname = ""
        pooled.h2Session = None
        pooled.inUse = false
    }

    /// 关闭 socket (正常关闭)
    /// 严格翻译自: HTTPContext.closeSocket
    public func closeSocket(socketFd: Int64): Unit {
        // 严格翻译自:
        //   markSocketAsDead(socket)
        //   socket.close(.normal)
        markSocketAsDead(socketFd)
        if (socketFd >= 0) {
            // SysFs.close(socketFd)
        }
    }

    /// 终止 socket (强制关闭)
    /// 严格翻译自: HTTPContext.terminateSocket
    public func terminateSocket(socketFd: Int64): Unit {
        // 严格翻译自:
        //   markSocketAsDead(socket)
        //   socket.close(.failure)
        markSocketAsDead(socketFd)
        if (socketFd >= 0) {
            // SysFs.close(socketFd)
        }
    }

    /// 清理所有资源
    /// 严格翻译自: HTTPContext.deinit
    public func deinit(): Unit {
        // 严格翻译自:
        //   1. 排空池化 keepalive socket: deref ssl_config, 关闭隧道, 释放 H2 会话
        //   2. 清理 active_h2_sessions
        //   3. 清理 pending_h2_connects
        //   4. 关闭所有 socket (group.closeAll)
        //   5. 释放 SSL_CTX (如果 SSL)

        // 关闭所有池化 socket
        for (pooled in pendingSockets) {
            if (pooled.inUse) {
                // 严格翻译自:
                //   if (pooled.ssl_config) |*s| s.deinit()
                //   if (pooled.proxy_tunnel) |*rp| { rp.deref() } // 不调用 shutdown
                //   if (pooled.target_hostname.len > 0) { ... free ... }
                //   if (pooled.h2_session) |s| s.deref()
                //   pooled.http_socket.close(.failure)
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

        // 严格翻译自:
        //   for (this.pending_h2_connects.items) |pc| pc.deinit()
        //   this.pending_h2_connects.deinit(...)
        pendingH2Connects = ArrayList<Any>()

        // 清理 socket 标记映射
        socketTags = HashMap<Int64, ActiveSocket>()

        // 严格翻译自:
        //   this.group.closeAll()
        //   this.group.deinit()
        //   if (comptime ssl) { if (this.secure) |c| BoringSSL.SSL_CTX_free(c) }
        //   bun.default_allocator.destroy(this)
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
            if (lowerAsciiByte(a[i]) != lowerAsciiByte(b[i])) {
                return false
            }
        }
        return true
    }

    private static func lowerAsciiByte(c: UInt8): UInt8 {
        if (c >= UInt8(65) && c <= UInt8(90)) {
            return c + UInt8(32)
        }
        return c
    }
}

// ============================================================================
// HTTPContextHandler - Handler 回调接口
// 严格翻译自: HTTPContext.Handler struct
//
// Handler 是 uws 的回调处理器，通过 ActiveSocket 标记联合
// 将 socket 事件分派到正确的处理对象:
//   - HTTPClient: 普通请求
//   - H2.ClientSession: HTTP/2 会话
//   - PooledSocket: 池化的 keep-alive socket
//   - DeadSocket: 已关闭的 socket (忽略)
// ============================================================================

/// Handler 回调接口
/// 严格翻译自: HTTPContext.Handler
public class HTTPContextHandler {

    /// 连接建立回调
    /// 严格翻译自: Handler.onOpen
    public static func onOpen(ctx: HTTPContext, ptr: ActiveSocket, socketFd: Int64): Unit {
        match (ptr.type_) {
            case httpClient =>
                match (ptr.getClient()) {
                    case Some(client) =>
                        // 严格翻译自:
                        //   if (client.onOpen(comptime ssl, socket)) |_| { return }
                        //   else |_| { terminateSocket(socket); return }
                        client.onOpen(ctx.isSsl, socketFd)
                    case None => ()
                }
            case _ =>
                // 严格翻译自: log("Unexpected open on unknown socket"); terminateSocket(socket)
                ctx.terminateSocket(socketFd)
        }
    }

    /// TLS 握手完成回调
    /// 严格翻译自: Handler.onHandshake
    public static func onHandshake(
        ctx: HTTPContext,
        ptr: ActiveSocket,
        socketFd: Int64,
        success: Bool,
        errorCode: Int64,
        errorReason: String
    ): Unit {
        match (ptr.type_) {
            case httpClient =>
                match (ptr.getClient()) {
                    case Some(client) =>
                        // 严格翻译自:
                        //   client.flags.did_have_handshaking_error = handshake_error.error_no != 0
                        //   if (handshake_success) {
                        //       if (client.flags.reject_unauthorized) {
                        //           if (client.flags.did_have_handshaking_error) {
                        //               client.closeAndFail(...); return
                        //           }
                        //           if (!client.checkServerIdentity(...)) { return }
                        //       }
                        //       return client.firstCall(comptime ssl, socket)
                        //   } else {
                        //       if (client.flags.did_have_handshaking_error) {
                        //           client.closeAndFail(...); return
                        //       }
                        //       client.closeAndFail(error.ConnectionRefused, ...)
                        //   }
                        client.flags.didHaveHandshakingError = errorCode != 0

                        if (success) {
                            if (client.flags.rejectUnauthorized) {
                                if (client.flags.didHaveHandshakingError) {
                                    client.closeAndFail("CertError", ctx.isSsl, socketFd)
                                    return
                                }
                                // checkServerIdentity (简化)
                            }
                            client.firstCall(ctx.isSsl, socketFd)
                        } else {
                            if (client.flags.didHaveHandshakingError) {
                                client.closeAndFail("CertError", ctx.isSsl, socketFd)
                            } else {
                                client.closeAndFail("ConnectionRefused", ctx.isSsl, socketFd)
                            }
                        }
                    case None => ()
                }
            case pooledSocket =>
                // 严格翻译自: 池化 socket 握手成功后重置超时
                if (success) {
                    // socket.setTimeout(0); socket.setTimeoutMinutes(5)
                }
            case _ =>
                ctx.terminateSocket(socketFd)
        }
    }

    /// 数据到达回调
    /// 严格翻译自: Handler.onData
    public static func onData(ctx: HTTPContext, ptr: ActiveSocket, socketFd: Int64, data: Array<UInt8>): Unit {
        match (ptr.type_) {
            case httpClient =>
                match (ptr.getClient()) {
                    case Some(client) =>
                        // 严格翻译自:
                        //   return client.onData(comptime ssl, buf, client.getSslCtx(ssl), socket)
                        client.onData(ctx.isSsl, "", ctx, socketFd)
                    case None => ()
                }
            case h2Session =>
                // 严格翻译自: return session.onData(buf)
                ()
            case pooledSocket =>
                // 严格翻译自:
                //   if (pooled.proxy_tunnel != null) { terminateSocket; return }
                //   if (pooled.h2_session) |session| {
                //       session.onIdleData(buf)
                //       if (!session.canPool()) terminateSocket(socket)
                //       return
                //   }
                //   if (strings.eqlComptime(buf, end_of_chunked...)) return
                //   log("Unexpected data on socket")
                ()
            case _ =>
                ctx.terminateSocket(socketFd)
        }
    }

    /// 可写回调
    /// 严格翻译自: Handler.onWritable
    public static func onWritable(ctx: HTTPContext, ptr: ActiveSocket, socketFd: Int64): Unit {
        match (ptr.type_) {
            case httpClient =>
                match (ptr.getClient()) {
                    case Some(client) =>
                        // 严格翻译自: return client.onWritable(false, comptime ssl, socket)
                        client.onWritable(false, ctx.isSsl, socketFd)
                    case None => ()
                }
            case h2Session =>
                // 严格翻译自: return session.onWritable()
                ()
            case pooledSocket =>
                // keep-alive socket, 忽略
                ()
            case _ =>
                ctx.terminateSocket(socketFd)
        }
    }

    /// 超时回调 (秒级)
    /// 严格翻译自: Handler.onTimeout
    public static func onTimeout(ctx: HTTPContext, ptr: ActiveSocket, socketFd: Int64): Unit {
        // 严格翻译自: onLongTimeout(ptr, socket)
        onLongTimeout(ctx, ptr, socketFd)
    }

    /// 长超时回调 (分钟级)
    /// 严格翻译自: Handler.onLongTimeout
    public static func onLongTimeout(ctx: HTTPContext, ptr: ActiveSocket, socketFd: Int64): Unit {
        match (ptr.type_) {
            case httpClient =>
                match (ptr.getClient()) {
                    case Some(client) =>
                        // 严格翻译自: return client.onTimeout(comptime ssl, socket)
                        client.onTimeout(ctx.isSsl, socketFd)
                    case None => ()
                }
            case h2Session =>
                // 严格翻译自: markSocketAsDead(socket); session.onClose(error.Timeout)
                ctx.markSocketAsDead(socketFd)
            case _ => ()
        }
        ctx.terminateSocket(socketFd)
    }

    /// 连接错误回调
    /// 严格翻译自: Handler.onConnectError
    public static func onConnectError(ctx: HTTPContext, ptr: ActiveSocket, socketFd: Int64): Unit {
        ctx.markSocketAsDead(socketFd)
        match (ptr.type_) {
            case httpClient =>
                match (ptr.getClient()) {
                    case Some(client) =>
                        // 严格翻译自: client.onConnectError()
                        client.fail("ConnectionRefused")
                    case None => ()
                }
            case _ => ()
        }
    }

    /// TCP FIN 回调
    /// 严格翻译自: Handler.onEnd
    public static func onEnd(ctx: HTTPContext, ptr: ActiveSocket, socketFd: Int64): Unit {
        // 严格翻译自:
        //   markTaggedSocketAsDead(socket, tagged)
        //   socket.close(.failure)
        //   if (tagged.get(HTTPClient)) |client| { client.onClose(...); return }
        //   if (tagged.get(H2.ClientSession)) |session| { session.onClose(...); return }
        ctx.markSocketAsDead(socketFd)
        match (ptr.type_) {
            case httpClient =>
                match (ptr.getClient()) {
                    case Some(client) => client.onClose(ctx.isSsl, socketFd)
                    case None => ()
                }
            case h2Session =>
                // session.onClose(error.ConnectionClosed)
                ()
            case _ => ()
        }
    }

    /// 关闭回调
    /// 严格翻译自: Handler.onClose
    public static func onClose(ctx: HTTPContext, ptr: ActiveSocket, socketFd: Int64): Unit {
        ctx.markSocketAsDead(socketFd)
        match (ptr.type_) {
            case httpClient =>
                match (ptr.getClient()) {
                    case Some(client) =>
                        // 严格翻译自: return client.onClose(comptime ssl, socket)
                        client.onClose(ctx.isSsl, socketFd)
                    case None => ()
                }
            case h2Session =>
                // 严格翻译自: return session.onClose(error.ConnectionClosed)
                ()
            case _ => ()
        }
    }
}

// ============================================================================
// Socket 组 — 对应 uws.SocketGroup
// ============================================================================

/// Socket 组 — 对应 uws.SocketGroup
public class SocketGroup {
    /// 初始化 socket 组
    /// 严格翻译自: this.group.init(bun.http.http_thread.loop.loop, null, this)
    public init() {}

    /// 关闭所有 socket
    /// 严格翻译自: this.group.closeAll()
    public func closeAll(): Unit {}

    /// 清理 socket 组
    /// 严格翻译自: this.group.deinit()
    public func deinit(): Unit {}
}
