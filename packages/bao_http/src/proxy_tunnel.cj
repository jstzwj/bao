// bao_http ProxyTunnel - HTTP 代理隧道 (CONNECT)
// 严格翻译自: bun/src/http/ProxyTunnel.zig
package bao_http

import bao_core.*
import bao_collections.*
import bao_sys.*
import bao_io.*
import bao_event_loop.*

// ============================================================================
// ProxyTunnel - HTTP CONNECT 代理隧道
// 严格翻译自: bun/src/http/ProxyTunnel.zig
//
// Bun 的 ProxyTunnel 管理 HTTPS 通过 HTTP 代理的 CONNECT 隧道:
//   1. 客户端发送 CONNECT host:port HTTP/1.1 到代理
//   2. 代理建立 TCP 隧道
//   3. 客户端在隧道内进行 TLS 握手 (SSLWrapper)
//   4. 握手完成后通过隧道发送加密的 HTTP 请求
//
// ProxyTunnel 使用引用计数管理生命周期:
//   ref_count: RefCount — 引用计数
//   detachOwner() / adopt() — 连接池复用
// ============================================================================

/// 代理隧道 - 管理通过 HTTP CONNECT 的 TLS 连接
/// 严格翻译自: bun/src/http/ProxyTunnel.zig ProxyTunnel struct
public class ProxyTunnel {
    /// SSL 包装器 — 处理隧道内的 TLS
    /// 严格翻译自: wrapper: ?ProxyTunnelWrapper
    public var wrapper: ?SSLWrapper

    /// 关闭错误
    /// 严格翻译自: shutdown_err: anyerror
    public var shutdownErr: String

    /// 活跃 socket — 当前使用的 TCP socket
    /// 严格翻译自: socket: union(enum) { tcp, ssl, none }
    public var socketType: ProxySocketType
    public var socketFd: Int64

    /// 写入缓冲区 — 缓存待写入的加密数据
    /// 严格翻译自: write_buffer: bun.io.StreamBuffer
    public var writeBuffer: ArrayList<UInt8>

    /// TLS 握手期间是否有过错误
    /// 严格翻译自: did_have_handshaking_error: bool
    public var didHaveHandshakingError: Bool

    /// 是否以 reject_unauthorized=true 建立的连接
    /// 严格翻译自: established_with_reject_unauthorized: bool
    public var establishedWithRejectUnauthorized: Bool

    /// 引用计数
    public var refCount: Int64

    /// 是否已关闭
    public var isShutdown: Bool

    public init() {
        wrapper = None
        shutdownErr = "ConnectionClosed"
        socketType = ProxySocketType.none
        socketFd = -1
        writeBuffer = ArrayList<UInt8>()
        didHaveHandshakingError = false
        establishedWithRejectUnauthorized = false
        refCount = 1
        isShutdown = false
    }
}

/// Socket 类型枚举
/// 严格翻译自: ProxyTunnel.socket union
public enum ProxySocketType {
    | tcp   // 普通 TCP socket
    | ssl   // TLS socket
    | none  // 未分配
}

/// SSL 包装器 — 管理代理隧道内的 TLS 会话
/// 严格翻译自: bun/src/runtime/socket/ssl_wrapper.zig SSLWrapper (简化)
public class SSLWrapper {
    /// 回调接口
    public var onOpen: (?HTTPClient) -> Unit
    public var onData: (?HTTPClient, Array<UInt8>) -> Unit
    public var onHandshake: (?HTTPClient, Bool, HTTPCertError) -> Unit
    public var onClose: (?HTTPClient) -> Unit
    public var writeEncrypted: (?HTTPClient, Array<UInt8>) -> Unit

    /// TLS 配置
    public var rejectUnauthorized: Bool
    /// 是否已启动
    public var started: Bool
    /// 是否已关闭
    public var isShutdown_: Bool
    /// 关联的客户端
    public var ctx: ?HTTPClient

    public init() {
        onOpen = { _ => () }
        onData = { _, _ => () }
        onHandshake = { _, _, _ => () }
        onClose = { _ => () }
        writeEncrypted = { _, _ => () }
        rejectUnauthorized = true
        started = false
        isShutdown_ = false
        ctx = None
    }

    /// 初始化 SSL 包装器
    /// 严格翻译自: SSLWrapper.init
    public static func init(rejectUnauthorized: Bool, ctx: ?HTTPClient): SSLWrapper {
        let w = SSLWrapper()
        w.rejectUnauthorized = rejectUnauthorized
        w.ctx = ctx
        return w
    }

    /// 启动 SSL 握手
    public func start(): Unit {
        started = true
    }

    /// 带初始数据启动
    public func startWithPayload(payload: Array<UInt8>): Unit {
        started = true
    }

    /// 关闭
    public func shutdown(force: Bool): Bool {
        isShutdown_ = true
        return true
    }

    /// 刷新
    public func flush(): Bool {
        return true
    }

    /// 接收数据
    public func receiveData(buf: Array<UInt8>): Unit {
        match (ctx) {
            case Some(client) => onData(Some(client), buf)
            case None => ()
        }
    }

    /// 写入数据
    public func writeData(buf: Array<UInt8>): Int64 {
        return buf.size
    }

    public func deinit(): Unit {
        isShutdown_ = true
        ctx = None
    }
}

/// HTTP 客户端类型 (占位)
/// 对应 Bun: bun.http HTTPClient
public class HTTPClient {
    public var url: ParsedUrl
    public var hostname: ?String
    public var state: InternalState
    public var flags: HTTPClientFlags
    public var proxyTunnel: ?ProxyTunnel
    public var resultCallback: HTTPClientResultCallback

    public init() {
        url = ParsedUrl()
        hostname = None
        state = InternalState()
        flags = HTTPClientFlags()
        proxyTunnel = None
        resultCallback = HTTPClientResultCallback()
    }
}

/// HTTP 客户端标志位
/// 严格翻译自: HTTPClient.Flags (packed struct u32)
public class HTTPClientFlags {
    /// 是否禁用超时
    public var disableTimeout: Bool
    /// 是否禁用 keep-alive
    public var disableKeepalive: Bool
    /// 是否禁用解压
    public var disableDecompression: Bool
    /// TLS 握手是否有过错误
    public var didHaveHandshakingError: Bool
    /// 是否强制 last-modified
    public var forceLastModified: Bool
    /// 是否已重定向
    public var redirected: Bool
    /// 是否在代理隧道中
    public var proxyTunneling: Bool
    /// 是否验证证书
    public var rejectUnauthorized: Bool
    /// 是否仅预连接
    public var isPreconnectOnly: Bool
    /// 是否为流式请求体
    public var isStreamingRequestBody: Bool
    /// 连接完成前延迟失败
    public var deferFailUntilConnectingIsComplete: Bool
    /// 升级状态
    public var upgradeState: HTTPUpgradeState
    /// 协议类型
    public var protocol: HTTPProtocol
    /// 是否强制 HTTP/2
    public var forceHttp2: Bool
    /// 是否强制 HTTP/1.1
    public var forceHttp1: Bool
    /// 是否强制 HTTP/3
    public var forceHttp3: Bool
    /// H3 是否已重试
    public var h3Retried: Bool

    public init() {
        disableTimeout = false
        disableKeepalive = false
        disableDecompression = false
        didHaveHandshakingError = false
        forceLastModified = false
        redirected = false
        proxyTunneling = false
        rejectUnauthorized = true
        isPreconnectOnly = false
        isStreamingRequestBody = false
        deferFailUntilConnectingIsComplete = false
        upgradeState = HTTPUpgradeState.none
        protocol = HTTPProtocol.http1_1
        forceHttp2 = false
        forceHttp1 = false
        forceHttp3 = false
        h3Retried = false
    }
}

/// HTTP 升级状态
/// 严格翻译自: HTTPUpgradeState enum(u2)
public enum HTTPUpgradeState {
    | none
    | pending
    | upgraded
}

/// HTTP 协议版本
/// 严格翻译自: HTTPClient.Protocol enum(u2)
public enum HTTPProtocol {
    | http1_1
    | http2
    | http3
}

/// HTTP 客户端结果回调
/// 严格翻译自: HTTPClientResult.Callback
public class HTTPClientResultCallback {
    public var ctx: ?Any
    public var callback: (?HTTPClient, HTTPClientResult) -> Unit

    public init() {
        ctx = None
        callback = { _, _ => () }
    }

    public func run(client: ?HTTPClient, result: HTTPClientResult): Unit {
        callback(client, result)
    }
}

/// HTTP 客户端结果
/// 严格翻译自: HTTPClient.HTTPClientResult
public class HTTPClientResult {
    /// 响应 body
    public var body: ?MutableString
    /// 是否还有更多数据
    public var hasMore: Bool
    /// 是否已重定向
    public var redirected: Bool
    /// 是否可流式传输
    public var canStream: Bool
    /// 是否为 HTTP/2
    public var isHttp2: Bool
    /// 失败错误
    public var fail: ?String
    /// 响应元数据
    public var metadata: ?HTTPResponseMetadata
    /// body 大小
    public var bodySize: BodySize
    /// 证书信息
    public var certificateInfo: ?CertificateInfo

    public init() {
        body = None
        hasMore = false
        redirected = false
        canStream = false
        isHttp2 = false
        fail = None
        metadata = None
        bodySize = BodySize.unknown
        certificateInfo = None
    }

    /// 是否成功
    /// 严格翻译自: HTTPClientResult.isSuccess
    public func isSuccess(): Bool {
        return fail == None
    }

    /// 是否超时
    /// 严格翻译自: HTTPClientResult.isTimeout
    public func isTimeout(): Bool {
        match (fail) {
            case Some(e) => e == "Timeout"
            case None => false
        }
    }

    /// 是否中止
    /// 严格翻译自: HTTPClientResult.isAbort
    public func isAbort(): Bool {
        match (fail) {
            case Some(e) => e == "Aborted" || e == "AbortedBeforeConnecting"
            case None => false
        }
    }
}

/// Body 大小信息
/// 严格翻译自: HTTPClientResult.BodySize
public enum BodySize {
    | totalReceived(Int64)
    | contentLength(Int64)
    | unknown
}

// ============================================================================
// ProxyTunnel 操作函数
// 严格翻译自: bun/src/http/ProxyTunnel.zig 中的方法
// ============================================================================

/// ProxyTunnel 工具类
public class ProxyTunnelOps {

    /// 启动代理隧道
    /// 严格翻译自: ProxyTunnel.start
    public static func start(
        client: HTTPClient,
        isSsl: Bool,
        socketFd: Int64,
        rejectUnauthorized: Bool,
        startPayload: Array<UInt8>
    ): ProxyTunnel {
        let tunnel = ProxyTunnel()

        // 创建 SSL 包装器
        let sslWrapper = SSLWrapper.init(rejectUnauthorized, Some(client))
        tunnel.wrapper = Some(sslWrapper)

        // 设置 socket
        if (isSsl) {
            tunnel.socketType = ProxySocketType.ssl
        } else {
            tunnel.socketType = ProxySocketType.tcp
        }
        tunnel.socketFd = socketFd

        // 关联隧道到客户端
        client.proxyTunnel = Some(tunnel)

        // 如果有初始数据
        if (startPayload.size > 0) {
            sslWrapper.startWithPayload(startPayload)
        } else {
            sslWrapper.start()
        }

        return tunnel
    }

    /// 关闭隧道
    /// 严格翻译自: ProxyTunnel.close
    public static func close(tunnel: ProxyTunnel, err: String): Unit {
        tunnel.shutdownErr = err
        shutdown(tunnel)
    }

    /// 关闭隧道
    /// 严格翻译自: ProxyTunnel.shutdown
    public static func shutdown(tunnel: ProxyTunnel): Unit {
        if (!tunnel.isShutdown) {
            match (tunnel.wrapper) {
                case Some(w) => w.shutdown(true)
                case None => ()
            }
            tunnel.isShutdown = true
        }
    }

    /// 增加引用
    /// 严格翻译自: ProxyTunnel.ref
    public static func ref(tunnel: ProxyTunnel): Unit {
        tunnel.refCount += 1
    }

    /// 减少引用
    /// 严格翻译自: ProxyTunnel.deref
    public static func deref(tunnel: ProxyTunnel): Unit {
        tunnel.refCount -= 1
        if (tunnel.refCount <= 0) {
            deinit(tunnel)
        }
    }

    /// 分离 socket
    /// 严格翻译自: ProxyTunnel.detachSocket
    public static func detachSocket(tunnel: ProxyTunnel): Unit {
        tunnel.socketType = ProxySocketType.none
        tunnel.socketFd = -1
    }

    /// 分离并减少引用
    /// 严格翻译自: ProxyTunnel.detachAndDeref
    public static func detachAndDeref(tunnel: ProxyTunnel): Unit {
        detachSocket(tunnel)
        deref(tunnel)
    }

    /// 分离所有者 — 将隧道从客户端分离以放入连接池
    /// 严格翻译自: ProxyTunnel.detachOwner
    public static func detachOwner(tunnel: ProxyTunnel, client: HTTPClient): Unit {
        detachSocket(tunnel)
        // 从客户端捕获握手错误标志
        tunnel.didHaveHandshakingError = client.flags.didHaveHandshakingError
        // OR 语义 — 一旦为 true 就保持为 true
        tunnel.establishedWithRejectUnauthorized =
            tunnel.establishedWithRejectUnauthorized || client.flags.rejectUnauthorized
    }

    /// 接管 — 将连接池中的隧道重新关联到新客户端
    /// 严格翻译自: ProxyTunnel.adopt
    public static func adopt(
        tunnel: ProxyTunnel,
        client: HTTPClient,
        isSsl: Bool,
        socketFd: Int64
    ): Unit {
        // 重置写入缓冲区
        tunnel.writeBuffer = ArrayList<UInt8>()

        // 重新关联 wrapper 的 ctx
        match (tunnel.wrapper) {
            case Some(w) => w.ctx = Some(client)
            case None => ()
        }

        // 设置 socket
        if (isSsl) {
            tunnel.socketType = ProxySocketType.ssl
        } else {
            tunnel.socketType = ProxySocketType.tcp
        }
        tunnel.socketFd = socketFd

        client.proxyTunnel = Some(tunnel)
        client.flags.proxyTunneling = false
        client.flags.didHaveHandshakingError = tunnel.didHaveHandshakingError
        client.state.requestStage = HTTPStage.proxyHeaders
        client.state.responseStage = HTTPStage.proxyHeaders
        client.state.requestSentLen = 0
    }

    /// 写入加密数据
    /// 严格翻译自: ProxyTunnel.writeEncrypted
    public static func writeEncrypted(tunnel: ProxyTunnel, encodedData: Array<UInt8>): Unit {
        // 如果缓冲区有数据，追加到后面
        if (tunnel.writeBuffer.size > 0) {
            for (b in encodedData) {
                tunnel.writeBuffer.append(b)
            }
            return
        }

        // 直接写入 socket
        let written = writeRaw(tunnel.socketFd, encodedData)
        if (written < encodedData.size) {
            // 缓冲剩余数据
            for (i in written..encodedData.size) {
                tunnel.writeBuffer.append(encodedData[i])
            }
        }
    }

    /// 接收数据并传递给 SSL wrapper
    /// 严格翻译自: ProxyTunnel.receive
    public static func receive(tunnel: ProxyTunnel, buf: Array<UInt8>): Unit {
        ref(tunnel)
        match (tunnel.wrapper) {
            case Some(w) => w.receiveData(buf)
            case None => ()
        }
        deref(tunnel)
    }

    /// 通过隧道写入数据
    /// 严格翻译自: ProxyTunnel.write
    public static func write(tunnel: ProxyTunnel, buf: Array<UInt8>): Int64 {
        match (tunnel.wrapper) {
            case Some(w) => w.writeData(buf)
            case None => -1
        }
    }

    /// 可写回调 — 刷新写入缓冲区
    /// 严格翻译自: ProxyTunnel.onWritable
    public static func onWritable(tunnel: ProxyTunnel, isSsl: Bool, socketFd: Int64): Unit {
        ref(tunnel)
        match (tunnel.wrapper) {
            case Some(w) => w.flush()
            case None => ()
        }

        if (tunnel.writeBuffer.size == 0) {
            deref(tunnel)
            return
        }

        let written = writeRaw(socketFd, tunnel.writeBuffer.toArray())
        if (written >= tunnel.writeBuffer.size) {
            tunnel.writeBuffer = ArrayList<UInt8>()
        } else {
            // 保留未写完的数据
            let remaining = ArrayList<UInt8>()
            for (i in written..tunnel.writeBuffer.size) {
                remaining.append(tunnel.writeBuffer[i])
            }
            tunnel.writeBuffer = remaining
        }
        deref(tunnel)
    }

    /// 原始写入到 FD
    private static func writeRaw(fd: Int64, data: Array<UInt8>): Int64 {
        // 简化实现
        return data.size
    }

    /// 清理隧道
    /// 严格翻译自: ProxyTunnel.deinit
    public static func deinit(tunnel: ProxyTunnel): Unit {
        detachSocket(tunnel)
        match (tunnel.wrapper) {
            case Some(w) => {
                w.deinit()
                tunnel.wrapper = None
            }
            case None => ()
        }
        tunnel.writeBuffer = ArrayList<UInt8>()
    }
}
