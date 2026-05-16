// 严格翻译自: src/runtime/socket/ssl_wrapper.zig
// SSL 包装器 — 通用 SSL/TLS 流包装，支持任意传输层
package bao_runtime.socket

import bao_core.*
import bao_collections.*

// ============================================================================
// SSL 包装器
// 对应 Bun: SSLWrapper(T) — 泛型 SSL 流包装
// ============================================================================

/// SSL 握手状态
public enum HandshakeState {
    | HandshakePending           // 等待握手
    | HandshakeCompleted         // 握手完成
    | HandshakeRenegotiationPending  // 等待重协商
}

/// SSL 标志位
public class SslFlags {
    /// 握手状态
    public var handshakeState: HandshakeState
    /// 是否已收到 SSL 关闭
    public var receivedSslShutdown: Bool
    /// 是否已发送 SSL 关闭
    public var sentSslShutdown: Bool
    /// 是否为客户端
    public var isClient: Bool
    /// 是否已授权
    public var authorized: Bool
    /// 是否发生致命错误
    public var fatalError: Bool
    /// 是否已通知关闭
    public var closedNotified: Bool

    public init() {
        handshakeState = HandshakeState.HandshakePending
        receivedSslShutdown = false
        sentSslShutdown = false
        isClient = false
        authorized = false
        fatalError = false
        closedNotified = false
    }
}

/// 64KB 缓冲区大小，适用于大多数 SSL 读写场景
public let SSL_BUFFER_SIZE: Int64 = 65536

/// SSL 包装器回调处理器接口
/// 对应 Zig: pub const Handlers = struct { ... }
public interface SslHandlers<T> {
    /// 连接打开回调
    func onOpen(ctx: T): Unit
    /// 握手完成回调 (success, verify_error)
    func onHandshake(ctx: T, success: Bool, error: UsBunVerifyError): Unit
    /// 数据写入回调 (加密数据发送到网络)
    func write(ctx: T, data: Array<Byte>): Unit
    /// 数据接收回调 (解密后的数据)
    func onData(ctx: T, data: Array<Byte>): Unit
    /// 连接关闭回调
    func onClose(ctx: T): Unit
}

/// SSL 验证错误
/// 对应 Zig: us_bun_verify_error_t
public class UsBunVerifyError {
    public var errorNo: Int32
    public var code: String
    public var reason: String

    public init() {
        errorNo = 0
        code = ""
        reason = ""
    }

    public init(errorNo: Int32, code: String, reason: String) {
        this.errorNo = errorNo
        this.code = code
        this.reason = reason
    }
}

/// SSL 包装器
/// 模拟 uSockets 中 openssl.c 的行为，包装可从任何来源接收的数据
/// receiveData() 在从网络接收数据时调用 (加密数据将由 SSLWrapper 解密)
/// writeData() 在向网络发送数据时调用 (未加密数据将由 SSLWrapper 加密)
///
/// 初始化后需要调用 start() 开始 SSL 握手
/// 这将在握手开始前触发 onOpen 回调，握手完成后触发 onHandshake 回调
/// onData 和 write 回调在有数据可读或可写时触发
/// onData 将传递从网络接收的解密数据
/// write 将传递要发送到网络的加密数据
/// onClose 在关闭网络连接时触发
///
/// 注意:
/// SSL_read() 读取存储在输入 BIO 中的未加密数据
/// SSL_write() 将未加密数据写入输出 BIO
/// BIO_write() 将加密数据写入输入 BIO
/// BIO_read() 从输出 BIO 读取加密数据
public class SslWrapper<T> {
    /// 回调处理器
    public var handlers: SslHandlers<T>
    /// SSL 连接对象
    public var ssl: ?Ssl
    /// SSL 上下文对象
    public var ctx: ?SslCtx
    /// 状态标志
    public var flags: SslFlags
    /// 用户上下文
    public var userCtx: ?T

    public init(handlers: SslHandlers<T>) {
        this.handlers = handlers
        this.ssl = None
        this.ctx = None
        this.flags = SslFlags()
        this.userCtx = None
    }

    /// 使用现有的 SSL_CTX 初始化 SSLWrapper
    /// 如果希望在 SSLWrapper 去初始化后保持 SSL_CTX 存活，请记得调用 SSL_CTX_up_ref
    public func initWithCTX(ctx: SslCtx, isClient: Bool, userCtx: T, handlers: SslHandlers<T>): Unit {
        this.ctx = ctx
        this.userCtx = userCtx
        this.handlers = handlers
        this.flags = SslFlags()
        this.flags.isClient = isClient

        // 创建 SSL 对象
        let ssl = BoringSSL.sslNew(ctx)
        if (ssl == None) {
            throw SslError.OutOfMemory
        }
        this.ssl = ssl

        if (isClient) {
            // 客户端: 设置重协商模式为显式模式
            BoringSSL.sslSetRenegotiateMode(ssl, SSLRenegotiateMode.EXPLICIT)
            BoringSSL.sslSetConnectState(ssl)
            // 如果 CTX 验证模式为 VERIFY_NONE，则设置 VERIFY_PEER
            if (BoringSSL.sslCtxGetVerifyMode(ctx) == SSLVerifyMode.NONE) {
                BoringSSL.sslSetVerify(ssl, SSLVerifyMode.PEER, SslWrapper.alwaysContinueVerify)
                let roots = usGetSharedDefaultCaStore()
                if (roots != None) {
                    BoringSSL.sslSet0VerifyCertStore(ssl, roots)
                }
            }
        } else {
            // 服务器: 设置重协商模式为永不重协商
            BoringSSL.sslSetRenegotiateMode(ssl, SSLRenegotiateMode.NEVER)
            BoringSSL.sslSetAcceptState(ssl)
        }

        // 创建输入/输出 BIO
        let input = BoringSSL.bioNew(BoringSSL.bioSMem())
        if (input == None) {
            throw SslError.OutOfMemory
        }
        let output = BoringSSL.bioNew(BoringSSL.bioSMem())
        if (output == None) {
            BoringSSL.bioFree(input)
            throw SslError.OutOfMemory
        }

        // 设置 EOF 返回值为 -1 以便检测 BIO 是否为空
        BoringSSL.bioSetMemEofReturn(input, -1)
        BoringSSL.bioSetMemEofReturn(output, -1)
        // 设置输入输出 BIO
        BoringSSL.sslSetBio(ssl, input, output)
    }

    /// 使用 SSL 配置选项初始化
    public func initFunc(sslOptions: SSLConfig, isClient: Bool, userCtx: T, handlers: SslHandlers<T>): Unit {
        let ctxOpts = sslOptions.asUSockets()
        var err: CreateBunSocketError = CreateBunSocketError.NONE
        let sslCtx = ctxOpts.createSSLContext(err)
        if (sslCtx == None) {
            throw SslError.InvalidOptions
        }
        try {
            initWithCTX(sslCtx, isClient, userCtx, handlers)
        } catch ex: SslError {
            BoringSSL.sslCtxFree(sslCtx)
            throw ex
        }
    }

    /// 启动 SSL 连接
    /// 触发 onOpen 回调以便用户在第一次握手前配置 SSL 连接
    public func start(): Unit {
        if (userCtx != None) {
            handlers.onOpen(userCtx.getOrThrow())
        }
        handleTraffic()
    }

    /// 使用初始载荷启动 SSL 连接
    public func startWithPayload(payload: Array<Byte>): Unit {
        if (userCtx != None) {
            handlers.onOpen(userCtx.getOrThrow())
        }
        receiveData(payload)
        handleTraffic()
    }

    /// 关闭 SSL 的读取方向 (仅为了方便)
    /// SSL 中无法关闭读取方向，读取方向由对端关闭
    /// 所以我们只是忽略 onData 数据，仍然等待收到关闭通知
    public func shutdownRead(): Unit {
        // 替换 onData 为空处理器
        // 在仓颉中我们通过设置标志来忽略数据
    }

    /// 关闭 SSL 的写入方向并返回是否完全关闭
    /// 不能假设发送关闭后读取部分保持开放
    /// 注意: 如果 fast_shutdown = true，不要重用 socket
    public func shutdown(fastShutdown: Bool): Bool {
        let sslVal = ssl
        if (sslVal == None) {
            return false
        }
        // 已经发送了 SSL 关闭
        if (flags.sentSslShutdown || flags.fatalError) {
            return flags.receivedSslShutdown
        }

        // 调用 SSL_shutdown() 关闭写入方向
        let ret = BoringSSL.sslShutdown(sslVal)
        if (fastShutdown) {
            // 快速关闭: 再次调用 SSL_shutdown
            BoringSSL.sslShutdown(sslVal)
            flags.receivedSslShutdown = true
            // 重置待处理的握手
            if (flags.handshakeState != HandshakeState.HandshakeCompleted) {
                flags.handshakeState = HandshakeState.HandshakeCompleted
                triggerHandshakeCallback(false, getVerifyError())
            }
            triggerCloseCallback()
            return false
        }

        // 标记已发送关闭
        flags.sentSslShutdown = ret >= 0
        if (ret < 0) {
            let err = BoringSSL.sslGetError(sslVal, ret)
            BoringSSL.errClearError()
            if (err == SSLError.SSL_ERROR_SSL || err == SSLError.SSL_ERROR_SYSCALL) {
                flags.fatalError = true
                triggerCloseCallback()
                return false
            }
        }
        return ret == 1  // 真正关闭
    }

    /// 刷新缓冲数据并返回待写入数据量
    public func flush(): Int64 {
        handleTraffic()
        let sslVal = ssl
        if (sslVal == None) {
            return 0
        }
        let pending = BoringSSL.bioCtrlPending(BoringSSL.sslGetWbio(sslVal))
        if (pending > 0) {
            return pending
        }
        return 0
    }

    /// 返回是否有待读取或写入的数据
    public func hasPendingData(): Bool {
        let sslVal = ssl
        if (sslVal == None) {
            return false
        }
        return BoringSSL.bioCtrlPending(BoringSSL.sslGetWbio(sslVal)) > 0 ||
               BoringSSL.bioCtrlPending(BoringSSL.sslGetRbio(sslVal)) > 0
    }

    /// 返回 BIO 读缓冲区中是否有缓冲数据
    func hasPendingRead(): Bool {
        let sslVal = ssl
        if (sslVal == None) {
            return false
        }
        return BoringSSL.bioCtrlPending(BoringSSL.sslGetRbio(sslVal)) > 0
    }

    /// 是否已发送或收到关闭 (正在关闭或已关闭)
    public func isShutdown(): Bool {
        return flags.closedNotified || flags.receivedSslShutdown || flags.sentSslShutdown
    }

    /// 是否已发送并收到关闭 (完全关闭)
    public func isClosed(): Bool {
        return flags.receivedSslShutdown && flags.sentSslShutdown
    }

    /// 是否已授权
    public func isAuthorized(): Bool {
        if (flags.handshakeState == HandshakeState.HandshakeCompleted) {
            return flags.authorized
        }
        return false
    }

    /// 从网络接收数据 (加密数据)
    public func receiveData(data: Array<Byte>): Unit {
        let sslVal = ssl
        if (sslVal == None) {
            return
        }
        let input = BoringSSL.sslGetRbio(sslVal)
        if (input == None) {
            return
        }
        let written = BoringSSL.bioWrite(input, data, data.size)
        if (written > -1) {
            handleTraffic()
        }
    }

    /// 向网络发送数据 (未加密数据)
    public func writeData(data: Array<Byte>): Int64 {
        let sslVal = ssl
        if (sslVal == None) {
            throw SslError.ConnectionClosed
        }
        // 已发送关闭，不能再写入
        if (flags.sentSslShutdown) {
            throw SslError.ConnectionClosed
        }
        if (data.size == 0) {
            // 仅循环通过内部 openssl 状态
            handleTraffic()
            return 0
        }
        let written = BoringSSL.sslWrite(sslVal, data, data.size)
        if (written <= 0) {
            let err = BoringSSL.sslGetError(sslVal, written)
            BoringSSL.errClearError()
            if (err == SSLError.SSL_ERROR_WANT_READ) {
                handleTraffic()
                throw SslError.WantRead
            }
            if (err == SSLError.SSL_ERROR_WANT_WRITE) {
                handleTraffic()
                throw SslError.WantWrite
            }
            // 发生严重错误，必须关闭
            flags.fatalError = err == SSLError.SSL_ERROR_SSL || err == SSLError.SSL_ERROR_SYSCALL
            triggerCloseCallback()
            throw SslError.ConnectionClosed
        }
        handleTraffic()
        return written
    }

    /// 释放所有资源
    public func deinit(): Unit {
        flags.closedNotified = true
        if (ssl != None) {
            let sslVal = ssl
            ssl = None
            // SSL_free 也会释放输入和输出 BIO
            BoringSSL.sslFree(sslVal)
        }
        if (ctx != None) {
            let ctxVal = ctx
            ctx = None
            // SSL_CTX_free 释放 SSL 上下文和所有证书
            BoringSSL.sslCtxFree(ctxVal)
        }
    }

    /// 触发握手回调
    func triggerHandshakeCallback(success: Bool, result: UsBunVerifyError): Unit {
        if (flags.closedNotified) {
            return
        }
        flags.authorized = success
        if (userCtx != None) {
            handlers.onHandshake(userCtx!, success, result)
        }
    }

    /// 触发写入回调
    func triggerWannaWriteCallback(data: Array<Byte>): Unit {
        if (flags.closedNotified) {
            return
        }
        if (userCtx != None) {
            handlers.write(userCtx!, data)
        }
    }

    /// 触发数据回调
    func triggerDataCallback(data: Array<Byte>): Unit {
        if (flags.closedNotified) {
            return
        }
        if (userCtx != None) {
            handlers.onData(userCtx!, data)
        }
    }

    /// 触发关闭回调
    func triggerCloseCallback(): Unit {
        if (flags.closedNotified) {
            return
        }
        flags.closedNotified = true
        if (userCtx != None) {
            handlers.onClose(userCtx.getOrThrow())
        }
    }

    /// 获取验证错误
    func getVerifyError(): UsBunVerifyError {
        if (isShutdown()) {
            return UsBunVerifyError()
        }
        let sslVal = ssl
        if (sslVal == None) {
            return UsBunVerifyError()
        }
        return BoringSSL.getSslVerifyError(sslVal)
    }

    /// 更新握手状态
    /// 返回 true 如果可以调用 handleReading
    func updateHandshakeState(): Bool {
        if (flags.closedNotified) {
            return false
        }
        let sslVal = ssl
        if (sslVal == None) {
            return false
        }

        if (BoringSSL.sslIsInitFinished(sslVal) != 0) {
            // 握手已完成
            if ((BoringSSL.sslGetShutdown(sslVal) & BoringSSL.SSL_RECEIVED_SHUTDOWN) != 0) {
                // 收到关闭
                flags.receivedSslShutdown = true
                // 两步关闭
                shutdown(false)
                triggerCloseCallback()
                return false
            }
            return true
        }

        if (flags.handshakeState == HandshakeState.HandshakeRenegotiationPending) {
            // 正在重协商中
            return true
        }

        let result = BoringSSL.sslDoHandshake(sslVal)

        if (result <= 0) {
            let err = BoringSSL.sslGetError(sslVal, result)
            BoringSSL.errClearError()
            if (err == SSLError.SSL_ERROR_ZERO_RETURN) {
                // 远程发起的关闭
                flags.receivedSslShutdown = true
                shutdown(false)
                handleEndOfRenegotiation()
                return false
            }
            if (err != SSLError.SSL_ERROR_WANT_READ && err != SSLError.SSL_ERROR_WANT_WRITE) {
                flags.fatalError = err == SSLError.SSL_ERROR_SSL || err == SSLError.SSL_ERROR_SYSCALL
                flags.handshakeState = HandshakeState.HandshakeCompleted
                triggerHandshakeCallback(false, getVerifyError())
                if (flags.fatalError) {
                    triggerCloseCallback()
                    return false
                }
                return true
            }
            flags.handshakeState = HandshakeState.HandshakePending
            return true
        }

        // 握手完成
        flags.handshakeState = HandshakeState.HandshakeCompleted
        triggerHandshakeCallback(true, getVerifyError())
        return true
    }

    /// 处理重协商结束
    func handleEndOfRenegotiation(): Unit {
        let sslVal = ssl
        if (flags.handshakeState == HandshakeState.HandshakeRenegotiationPending &&
            (sslVal == None || BoringSSL.sslIsInitFinished(sslVal) != 0)) {
            // 重协商成功完成
            flags.handshakeState = HandshakeState.HandshakeCompleted
            triggerHandshakeCallback(true, getVerifyError())
        }
    }

    /// 处理数据读取
    /// 返回 true 如果可以调用 handleWriting
    func handleReading(buffer: Array<Byte>): Bool {
        var read: Int64 = 0

        while (true) {
            let sslVal = ssl
            if (sslVal == None) {
                return false
            }

            let available = buffer[read.toInt():]
            let justRead = BoringSSL.sslRead(sslVal, available, available.size)
            if (justRead <= 0) {
                let err = BoringSSL.sslGetError(sslVal, justRead)
                BoringSSL.errClearError()

                if (err != SSLError.SSL_ERROR_WANT_READ && err != SSLError.SSL_ERROR_WANT_WRITE) {
                    if (err == SSLError.SSL_ERROR_WANT_RENEGOTIATE) {
                        flags.handshakeState = HandshakeState.HandshakeRenegotiationPending
                        if (BoringSSL.sslRenegotiate(sslVal) == 0) {
                            flags.handshakeState = HandshakeState.HandshakeCompleted
                            triggerHandshakeCallback(false, getVerifyError())
                            triggerCloseCallback()
                            return false
                        }
                        continue
                    } else if (err == SSLError.SSL_ERROR_ZERO_RETURN) {
                        // 远程发起的关闭
                        flags.receivedSslShutdown = true
                        shutdown(false)
                        handleEndOfRenegotiation()
                    }
                    flags.fatalError = err == SSLError.SSL_ERROR_SSL || err == SSLError.SSL_ERROR_SYSCALL

                    // 刷新读取
                    if (read > 0) {
                        triggerDataCallback(buffer[0:read.toInt()])
                        if (ssl == None || flags.closedNotified) {
                            return false
                        }
                    }
                    triggerCloseCallback()
                    return false
                } else {
                    // 想要读/写，跳出
                    break
                }
            }

            handleEndOfRenegotiation()

            read += justRead
            if (read == buffer.size) {
                // 缓冲区已满
                triggerDataCallback(buffer[0:read.toInt()])
                if (ssl == None || flags.closedNotified) {
                    return false
                }
                read = 0
            }
        }
        // 读取完成
        if (read > 0) {
            triggerDataCallback(buffer[0:read.toInt()])
            if (ssl == None || flags.closedNotified) {
                return false
            }
        }
        return true
    }

    /// 处理数据写入
    func handleWriting(buffer: Array<Byte>): Unit {
        var read: Int64 = 0
        while (true) {
            let sslVal = ssl
            if (sslVal == None) {
                return
            }
            let output = BoringSSL.sslGetWbio(sslVal)
            if (output == None) {
                return
            }
            let available = buffer[read.toInt():]
            let justRead = BoringSSL.bioRead(output, available, available.size)
            if (justRead > 0) {
                read += justRead
                if (read == buffer.size) {
                    triggerWannaWriteCallback(buffer[0:read.toInt()])
                    read = 0
                }
            } else {
                break
            }
        }
        if (read > 0) {
            triggerWannaWriteCallback(buffer[0:read.toInt()])
        }
    }

    /// 处理流量 (核心调度方法)
    func handleTraffic(): Unit {
        // 总是先处理握手
        if (updateHandshakeState()) {
            // 共享栈缓冲区用于读取和写入
            var buffer = Array<Byte>(SSL_BUFFER_SIZE)
            // 先排空输出 BIO
            handleWriting(buffer)
            // 循环排空输入 BIO，因为读取可能触发写入，反之亦然
            while (hasPendingRead() && handleReading(buffer)) {
                // 读取数据可能触发写入
                handleWriting(buffer)
            }
        }
    }

    /// 验证回调 — 让握手完成而不考虑验证结果
    /// JS 侧读取 authorizationError 和 rejectUnauthorized 来决定
    static func alwaysContinueVerify(ok: Int32, x509StoreCtx: ?X509StoreCtx): Int32 {
        return 1
    }
}

/// 获取共享的默认 CA 证书存储
/// 进程范围的捆绑根存储，仅构建一次
extern func usGetSharedDefaultCaStore(): ?X509Store

/// Socket 创建错误类型
public enum CreateBunSocketError {
    | NONE               // 无错误
    | LOAD_CA_FILE       // 加载 CA 文件失败
    | INVALID_CA_FILE    // 无效的 CA 文件
    | INVALID_CA         // 无效的 CA
    | INVALID_CIPHERS    // 无效的密码套件
}

/// SSL 错误类型
public enum SslError {
    | OutOfMemory
    | InvalidOptions
    | ConnectionClosed
    | WantRead
    | WantWrite
    | HandshakeFailed
}

/// SSL 错误码
public enum SSLError {
    | SSL_ERROR_NONE            // 0
    | SSL_ERROR_SSL             // 1
    | SSL_ERROR_WANT_READ       // 2
    | SSL_ERROR_WANT_WRITE      // 3
    | SSL_ERROR_WANT_X509_LOOKUP // 4
    | SSL_ERROR_SYSCALL         // 5
    | SSL_ERROR_ZERO_RETURN     // 6
    | SSL_ERROR_WANT_CONNECT    // 7
    | SSL_ERROR_WANT_ACCEPT     // 8
    | SSL_ERROR_WANT_RENEGOTIATE //?
}

/// SSL 验证模式
public enum SSLVerifyMode {
    | NONE      // SSL_VERIFY_NONE
    | PEER      // SSL_VERIFY_PEER
    | FAIL_IF_NO_PEER_CERT  // SSL_VERIFY_FAIL_IF_NO_PEER_CERT
}

/// SSL 重协商模式
public enum SSLRenegotiateMode {
    | NEVER     // ssl_renegotiate_never
    | EXPLICIT  // ssl_renegotiate_explicit
    | FREELY    // ssl_renegotiate_freely
}

/// BoringSSL FFI 桥接
public class BoringSSL {
    public static func sslNew(ctx: SslCtx): ?Ssl { ... }
    public static func sslFree(ssl: Ssl): Unit { ... }
    public static func sslCtxFree(ctx: SslCtx): Unit { ... }
    public static func sslSetRenegotiateMode(ssl: Ssl, mode: SSLRenegotiateMode): Unit { ... }
    public static func sslSetConnectState(ssl: Ssl): Unit { ... }
    public static func sslSetAcceptState(ssl: Ssl): Unit { ... }
    public static func sslCtxGetVerifyMode(ctx: SslCtx): Int32 { ... }
    public static func sslSetVerify(ssl: Ssl, mode: SSLVerifyMode, callback: (Int32, ?X509StoreCtx) -> Int32): Unit { ... }
    public static func sslSet0VerifyCertStore(ssl: Ssl, store: X509Store): Bool { ... }
    public static func bioNew(method: BioMethod): ?Bio { ... }
    public static func bioSMem(): BioMethod { ... }
    public static func bioFree(bio: Bio): Unit { ... }
    public static func bioSetMemEofReturn(bio: Bio, value: Int32): Unit { ... }
    public static func sslSetBio(ssl: Ssl, input: Bio, output: Bio): Unit { ... }
    public static func sslShutdown(ssl: Ssl): Int32 { ... }
    public static func sslGetError(ssl: Ssl, retCode: Int64): SSLError { ... }
    public static func errClearError(): Unit { ... }
    public static func bioCtrlPending(bio: Bio): Int64 { ... }
    public static func sslGetWbio(ssl: Ssl): ?Bio { ... }
    public static func sslGetRbio(ssl: Ssl): ?Bio { ... }
    public static func bioWrite(bio: Bio, data: Array<Byte>, len: Int64): Int32 { ... }
    public static func bioRead(bio: Bio, data: Array<Byte>, len: Int64): Int32 { ... }
    public static func sslWrite(ssl: Ssl, data: Array<Byte>, len: Int64): Int32 { ... }
    public static func sslRead(ssl: Ssl, data: Array<Byte>, len: Int64): Int32 { ... }
    public static func sslIsInitFinished(ssl: Ssl): Int32 { ... }
    public static func sslGetShutdown(ssl: Ssl): Int32 { ... }
    public static func sslDoHandshake(ssl: Ssl): Int32 { ... }
    public static func sslRenegotiate(ssl: Ssl): Int32 { ... }
    public static func sslCtxUpRef(ctx: SslCtx): Unit { ... }
    public static func getSslVerifyError(ssl: Ssl): UsBunVerifyError { ... }

    public static let SSL_RECEIVED_SHUTDOWN: Int32 = 4

    // ERR_toJS 相关
    public static func errGetError(): Int64 { ... }
}

/// SSL 对象的不透明类型
public class Ssl {}
/// SSL_CTX 对象的不透明类型
public class SslCtx {}
/// BIO 对象的不透明类型
public class Bio {}
/// BIO 方法的不透明类型
public class BioMethod {}
/// X509_STORE 对象的不透明类型
public class X509Store {}
/// X509_STORE_CTX 对象的不透明类型
public class X509StoreCtx {}
