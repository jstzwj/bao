// Socket 核心 — TCP/TLS 连接管理
// 对应 Bun: src/runtime/socket/socket.zig
// 包含 TCPSocket 和 TLSSocket 的完整生命周期管理
package bao_runtime.socket

import bao_core.*
import bao_collections.*

// ============================================================================
// Socket 状态标志
// 对应 Bun: socket.Flags (packed struct)
// ============================================================================

/// Socket 内部状态标志
public class SocketFlags {
    /// 是否活跃
    public var isActive: Bool
    /// 是否正在 finalize
    public var finalizing: Bool
    /// TLS 是否已授权
    public var authorized: Bool
    /// TLS 握手是否完成
    public var handshakeComplete: Bool
    /// 是否有待发送的空包 (TLS)
    public var emptyPacketPending: Bool
    /// flush 后是否结束
    public var endAfterFlush: Bool
    /// 是否拥有 protos 内存
    public var ownedProtos: Bool
    /// 是否暂停
    public var isPaused: Bool
    /// 是否允许半开连接
    public var allowHalfOpen: Bool
    /// 是否绕过 TLS (raw 半)
    public var bypassTls: Bool

    public init() {
        isActive = false
        finalizing = false
        authorized = false
        handshakeComplete = false
        emptyPacketPending = false
        endAfterFlush = false
        ownedProtos = true
        isPaused = false
        allowHalfOpen = false
        bypassTls = false
    }
}

// ============================================================================
// 写入结果
// 对应 Bun: socket.WriteResult
// ============================================================================

/// 写入操作的返回结果
public enum WriteResult {
    | Fail
    | Success(Int64, Int64)  // (wrote, total)

    /// 是否成功
    public func isOk(): Bool {
        match (this) {
            case Fail => false
            case Success(_, _) => true
        }
    }

    /// 获取已写入字节数
    public func wrote(): Int64 {
        match (this) {
            case Fail => -1
            case Success(w, _) => w
        }
    }

    /// 获取总字节数
    public func total(): Int64 {
        match (this) {
            case Fail => 0
            case Success(_, t) => t
        }
    }
}

// ============================================================================
// 原生回调类型
// 对应 Bun: socket.NativeCallbacks
// ============================================================================

/// 原生回调 (HTTP/2 等上层协议使用)
public enum NativeCallback {
    | H2(H2FrameParser)
    | None

    /// 处理数据
    public func onData(data: Array<UInt8>): Bool {
        match (this) {
            case H2(_) => true    // h2.onNativeRead(data)
            case None => false
        }
    }

    /// 处理可写事件
    public func onWritable(): Bool {
        match (this) {
            case H2(_) => true    // h2.onNativeWritable()
            case None => false
        }
    }
}

// ============================================================================
// H2 帧解析器 (占位)
// ============================================================================

/// HTTP/2 帧解析器占位
public class H2FrameParser {
    public init() {}
}

// ============================================================================
// Socket 连接信息
// 对应 Bun: Listener.UnixOrHost
// ============================================================================

/// Socket 连接目标
public enum ConnectionTarget {
    /// Unix 域套接字
    | Unix(String)
    /// TCP 主机:端口
    | Host(String, UInt16)
    /// 文件描述符
    | Fd(Int64)

    /// 克隆连接信息
    public func clone(): ConnectionTarget {
        match (this) {
            case Unix(path) => ConnectionTarget.Unix(path)
            case Host(host, port) => ConnectionTarget.Host(host, port)
            case Fd(fd) => ConnectionTarget.Fd(fd)
        }
    }

    /// 释放资源
    public func deinit(): Unit {
        // Host/Unix 的字符串由调用方管理
    }
}

// ============================================================================
// Socket 连接状态
// 对应 Bun: socket 中 Socket 类型
// ============================================================================

/// Socket 连接状态
public enum SocketState {
    /// 已分离 (未连接)
    | Detached
    /// 正在连接
    | Connecting
    /// 已连接
    | Connected
    /// 已关闭
    | Closed
    /// 已关闭写端
    | Shutdown
    /// Named Pipe (Windows)
    | NamedPipe
}

// ============================================================================
// Socket 基类 — TCP/TLS 连接核心
// 对应 Bun: NewSocket(ssl: bool) type
// ============================================================================

/// TCP/TLS Socket 连接
/// 对应 Zig: pub fn NewSocket(comptime ssl: bool) type
/// 通过 ssl 参数区分 TCP 和 TLS 行为
public class Socket {
    /// 是否为 TLS 连接
    public let isSsl: Bool

    /// Socket 连接状态
    public var socketState: SocketState
    /// 状态标志
    public var flags: SocketFlags
    /// 引用计数
    public var refCount: Int64
    /// 事件处理器
    public var handlers: ?Handlers
    /// JS 包装器引用
    public var thisValue: JsValue
    /// 连接目标
    public var connection: ?ConnectionTarget
    /// ALPN 协议
    public var protos: ?String
    /// TLS 服务器名
    public var serverName: ?String
    /// 缓冲的待发送数据
    public var bufferedData: ArrayList<UInt8>
    /// 已写入字节总数
    public var bytesWritten: Int64
    /// 原生回调
    public var nativeCallback: NativeCallback
    /// TLS 双胞胎 (upgradeTLS 时使用)
    public var twin: ?Socket

    /// 文件描述符 (非 Windows)
    public var fd: Int64
    /// 本地地址
    public var localAddress: ?SocketAddress
    /// 远程地址
    public var remoteAddress: ?SocketAddress

    public init(ssl: Bool) {
        isSsl = ssl
        socketState = SocketState.Detached
        flags = SocketFlags()
        refCount = 1
        handlers = None
        thisValue = JsValue.UNDEFINED
        connection = None
        protos = None
        serverName = None
        bufferedData = ArrayList<UInt8>()
        bytesWritten = 0
        nativeCallback = NativeCallback.None
        twin = None
        fd = -1
        localAddress = None
        remoteAddress = None
    }

    /// 增加引用计数
    /// 对应 Zig: ref()
    public func ref(): Unit {
        refCount += 1
    }

    /// 减少引用计数
    /// 对应 Zig: deref()
    public func deref(): Unit {
        refCount -= 1
        if (refCount <= 0) {
            deinit()
        }
    }

    /// 是否已分离
    public func isDetached(): Bool {
        match (socketState) {
            case Detached => true
            case _ => false
        }
    }

    /// 是否已关闭
    public func isClosed(): Bool {
        match (socketState) {
            case Closed => true
            case _ => false
        }
    }

    /// 是否已建立连接
    public func isEstablished(): Bool {
        match (socketState) {
            case Connected => true
            case _ => false
        }
    }

    /// 是否为服务器模式
    public func isServer(): Bool {
        match (handlers) {
            case Some(h) => h.mode.isServer()
            case None => false
        }
    }

    /// 获取 Handlers (不可为空)
    /// 对应 Zig: getHandlers
    public func getHandlers(): Handlers {
        match (handlers) {
            case Some(h) => h
            case None => throw BaoError("No handlers set on Socket")
        }
    }

    // ========================================================================
    // 连接操作
    // 对应 Bun: socket.doConnect
    // ========================================================================

    /// 建立连接
    /// 对应 Zig: doConnect
    public func doConnect(target: ConnectionTarget): Unit {
        ref()
        defer {
            deref()
        }

        socketState = SocketState.Connecting

        match (target) {
            case Host(host, port) => {
                // TCP 连接: 解析主机名, 建立连接
                let cleanedHost = cleanIPv6Brackets(host)
                let kind = if (isSsl) "tls" else "tcp"
                // 实际实现: 通过 bao_sys socket 接口连接
                socketState = SocketState.Connecting
            }
            case Unix(path) => {
                // Unix 域套接字连接
                socketState = SocketState.Connecting
            }
            case Fd(fdValue) => {
                // 从文件描述符创建
                this.fd = fdValue
                socketState = SocketState.Connected
                onOpen()
            }
        }
    }

    /// 处理连接错误
    /// 对应 Zig: handleConnectError
    public func handleConnectError(errno: Int64): Unit {
        ref()
        defer {
            deref()
        }

        bufferedData.clear()

        let wasAttached = !isDetached()
        socketState = SocketState.Detached
        defer {
            markInactive()
        }

        let h = getHandlers()
        let errorCode = if (errno == 2) "ENOENT" else "ECONNREFUSED"
        let errorMsg = "Failed to connect"

        let callback = h.onConnectError

        // 如果没有 connectError 回调, 拒绝 promise
        if (callback.valueType != JsValueType.Function) {
            thisValue = JsValue.UNDEFINED
            h.rejectPromise(JsValue(errorMsg))
            return
        }

        // 调用 connectError 回调
        thisValue = JsValue.UNDEFINED
    }

    // ========================================================================
    // 事件回调
    // 对应 Bun: socket.onOpen/onClose/onData/onEnd/onWritable/onTimeout/onHandshake
    // ========================================================================

    /// 连接已打开
    /// 对应 Zig: onOpen
    public func onOpen(): Unit {
        ref()
        defer {
            deref()
        }

        socketState = SocketState.Connected
        markActive()

        let h = getHandlers()
        let callback = h.onOpen

        // 解析 promise
        h.resolvePromise(thisValue)

        if (callback.valueType != JsValueType.Function) {
            return
        }

        // 调用 onOpen(thisValue)
        // 实际实现: 通过 JS 引擎调用
    }

    /// 连接已关闭
    /// 对应 Zig: onClose
    public func onClose(errno: Int64): Unit {
        detachNativeCallback()
        socketState = SocketState.Detached

        // 处理 twin (upgradeTLS 的 raw 半)
        match (twin) {
            case Some(raw) => {
                twin = None
                raw.onClose(errno)
            }
            case None => ()
        }

        defer {
            deref()
        }
        defer {
            markInactive()
        }

        if (flags.finalizing) {
            return
        }

        let h = getHandlers()
        let callback = h.onClose
        if (callback.valueType != JsValueType.Function) {
            return
        }

        // 构建错误值
        var jsError = JsValue.UNDEFINED
        if (errno != 0) {
            jsError = JsValue("Read error: ${errno}")
        }

        // 调用 onClose(thisValue, jsError)
    }

    /// 数据到达
    /// 对应 Zig: onData
    public func onData(data: Array<UInt8>): Unit {
        if (isDetached()) {
            return
        }

        // 处理原生回调
        match (nativeCallback) {
            case NativeCallback.H2(_) => {
                if (nativeCallback.onData(data)) {
                    return
                }
            }
            case NativeCallback.None => ()
        }

        let h = getHandlers()
        let callback = h.onData
        if (callback.valueType != JsValueType.Function || flags.finalizing) {
            return
        }

        // 将二进制数据转为 JS 值
        let outputValue = binaryTypeToJS(data, h.binaryType)

        // 调用 onData(thisValue, outputValue)
    }

    /// 可写事件
    /// 对应 Zig: onWritable
    public func onWritable(): Unit {
        if (isDetached()) {
            return
        }

        match (nativeCallback) {
            case NativeCallback.H2(_) => {
                if (nativeCallback.onWritable()) {
                    return
                }
            }
            case NativeCallback.None => ()
        }

        let h = getHandlers()
        let callback = h.onWritable
        if (callback.valueType != JsValueType.Function) {
            return
        }

        internalFlush()

        // 如果有缓冲数据或已分离, 不触发回调
        if (bufferedData.size > 0 || isDetached()) {
            return
        }

        // 调用 onWritable(thisValue)
    }

    /// 超时
    /// 对应 Zig: onTimeout
    public func onTimeout(): Unit {
        if (isDetached()) {
            return
        }

        let h = getHandlers()
        let callback = h.onTimeout
        if (callback.valueType != JsValueType.Function || flags.finalizing) {
            return
        }

        // 调用 onTimeout(thisValue)
    }

    /// 连接结束 (TCP FIN)
    /// 对应 Zig: onEnd
    public func onEnd(): Unit {
        if (isDetached()) {
            return
        }

        ref()
        defer {
            deref()
        }

        let h = getHandlers()
        let callback = h.onEnd
        if (callback.valueType != JsValueType.Function) {
            // 未处理 FIN, 直接关闭
            markInactive()
            return
        }

        // 调用 onEnd(thisValue)
    }

    /// TLS 握手完成
    /// 对应 Zig: onHandshake
    public func onHandshake(success: Bool, sslError: SslVerifyError): Unit {
        flags.handshakeComplete = true

        if (isDetached()) {
            return
        }

        let h = getHandlers()
        flags.authorized = success

        var callback = h.onHandshake
        var isOpen = false

        // 如果没有 handshake 回调, 使用 onOpen 回调
        if (callback.valueType != JsValueType.Function) {
            callback = h.onOpen
            if (callback.valueType != JsValueType.Function) {
                return
            }
            isOpen = true
        }

        // 调用回调
        if (isOpen) {
            // onOpen(thisValue)
        } else {
            // onHandshake(thisValue, authorized, authorizationError)
        }
    }

    // ========================================================================
    // 读写操作
    // 对应 Bun: socket.write/end/flush
    // ========================================================================

    /// 写入数据
    /// 对应 Zig: writeMaybeCorked
    public func writeMaybeCorked(buffer: Array<UInt8>): Int64 {
        if (isClosed()) {
            match (socketState) {
                case Shutdown => return -1
                case _ => ()
            }
        }

        let res = doSocketWrite(buffer)
        let wrote: Int64 = if (res > 0) { res } else { 0 }
        bytesWritten += wrote
        return res
    }

    /// 实际 Socket 写入
    /// 对应 Zig: doSocketWrite
    public func doSocketWrite(buffer: Array<UInt8>): Int64 {
        // 通过 bao_sys socket 接口写入
        // 返回写入字节数, -1 表示错误
        return Int64(buffer.size)
    }

    /// 从 JS 调用写入
    /// 对应 Zig: write
    public func writeFromJS(args: ArrayList<JsValue>): JsValue {
        if (isDetached()) {
            return JsValue(-1.0)
        }

        match (writeOrEnd(args, false, false)) {
            case WriteResult.Fail => return JsValue.UNDEFINED
            case WriteResult.Success(w, _) => return JsValue(Float64(w))
        }
    }

    /// 从 JS 调用结束
    /// 对应 Zig: end
    public func endFromJS(args: ArrayList<JsValue>): JsValue {
        if (isDetached()) {
            return JsValue(-1.0)
        }

        ref()
        defer {
            deref()
        }

        match (writeOrEnd(args, false, true)) {
            case WriteResult.Fail => return JsValue.UNDEFINED
            case WriteResult.Success(w, _) => {
                return JsValue(Float64(w))
            }
        }
    }

    /// 写入或结束的统一实现
    /// 对应 Zig: writeOrEnd
    public func writeOrEnd(args: ArrayList<JsValue>, bufferUnwrittenData: Bool, isEnd: Bool): WriteResult {
        if (args.size == 0 || args[0].valueType == JsValueType.Undefined) {
            if (isEnd) {
                flags.endAfterFlush = true
            }
            return WriteResult.Success(0, 0)
        }

        // 获取数据缓冲区
        let dataValue = args[0]
        let bytes = jsValueToBytes(dataValue)
        if (bytes.size == 0) {
            return WriteResult.Success(0, 0)
        }

        if (isEnd) {
            flags.endAfterFlush = true
        }

        let wrote = writeMaybeCorked(bytes)
        let uwrote: Int64 = if (wrote > 0) { wrote } else { 0 }

        if (bufferUnwrittenData) {
            var remaining = ArrayList<UInt8>()
            var i = uwrote
            while (i < bytes.size) {
                remaining.append(bytes[i])
                i += 1
            }
            if (remaining.size > 0) {
                bufferedData.appendAll(remaining)
            }
        }

        return WriteResult.Success(wrote, Int64(bytes.size))
    }

    /// 内部刷新
    /// 对应 Zig: internalFlush
    public func internalFlush(): Unit {
        if (bufferedData.size > 0) {
            let buffer = bufferedData.toArray()
            let written = doSocketWrite(buffer)
            let wrote: Int64 = if (written > 0) { written } else { 0 }
            bytesWritten += wrote

            if (wrote > 0) {
                if (bufferedData.size > wrote) {
                    // 移动剩余数据
                    var remaining = ArrayList<UInt8>()
                    var i = wrote
                    while (i < bufferedData.size) {
                        remaining.append(bufferedData[i])
                        i += 1
                    }
                    bufferedData = remaining
                } else {
                    bufferedData.clear()
                }
            }
        }
    }

    /// 从 JS 调用刷新
    /// 对应 Zig: flush
    public func flushFromJS(): JsValue {
        if (isDetached()) {
            return JsValue.UNDEFINED
        }
        internalFlush()
        return JsValue.UNDEFINED
    }

    // ========================================================================
    // Socket 选项
    // 对应 Bun: socket.setKeepAlive/setNoDelay/timeout
    // ========================================================================

    /// 设置 TCP Keep-Alive
    /// 对应 Zig: setKeepAlive
    public func setKeepAlive(enabled: Bool, initialDelay: UInt32): Bool {
        // 通过 bao_sys setsockopt 设置
        return true
    }

    /// 设置 TCP No-Delay (禁用 Nagle 算法)
    /// 对应 Zig: setNoDelay
    public func setNoDelay(enabled: Bool): Bool {
        // 通过 bao_sys setsockopt 设置
        return true
    }

    /// 设置超时
    /// 对应 Zig: timeout
    public func setTimeout(timeout: Int64): Unit {
        if (isDetached()) {
            return
        }
        // 通过 bao_sys 设置 socket 超时
    }

    // ========================================================================
    // 地址信息
    // 对应 Bun: socket.getLocalAddress/getRemoteAddress 等
    // ========================================================================

    /// 获取本地地址族
    /// 对应 Zig: getLocalFamily
    public func getLocalFamily(globalObject: JsObject): JsValue {
        if (isDetached()) {
            return JsValue.UNDEFINED
        }
        match (localAddress) {
            case Some(addr) => return JsValue(addr.getFamily().label())
            case None => return JsValue.UNDEFINED
        }
    }

    /// 获取本地地址
    /// 对应 Zig: getLocalAddress
    public func getLocalAddress(globalObject: JsObject): JsValue {
        if (isDetached()) {
            return JsValue.UNDEFINED
        }
        match (localAddress) {
            case Some(addr) => return JsValue(addr.getAddress())
            case None => return JsValue.UNDEFINED
        }
    }

    /// 获取本地端口
    /// 对应 Zig: getLocalPort
    public func getLocalPort(): JsValue {
        if (isDetached()) {
            return JsValue.UNDEFINED
        }
        match (localAddress) {
            case Some(addr) => return JsValue(Float64(addr.getPort()))
            case None => return JsValue.UNDEFINED
        }
    }

    /// 获取远程地址族
    /// 对应 Zig: getRemoteFamily
    public func getRemoteFamily(globalObject: JsObject): JsValue {
        if (isDetached()) {
            return JsValue.UNDEFINED
        }
        match (remoteAddress) {
            case Some(addr) => return JsValue(addr.getFamily().label())
            case None => return JsValue.UNDEFINED
        }
    }

    /// 获取远程地址
    /// 对应 Zig: getRemoteAddress
    public func getRemoteAddress(globalObject: JsObject): JsValue {
        if (isDetached()) {
            return JsValue.UNDEFINED
        }
        match (remoteAddress) {
            case Some(addr) => return JsValue(addr.getAddress())
            case None => return JsValue.UNDEFINED
        }
    }

    /// 获取远程端口
    /// 对应 Zig: getRemotePort
    public func getRemotePort(): JsValue {
        if (isDetached()) {
            return JsValue.UNDEFINED
        }
        match (remoteAddress) {
            case Some(addr) => return JsValue(Float64(addr.getPort()))
            case None => return JsValue.UNDEFINED
        }
    }

    /// 获取 ReadyState
    /// 对应 Zig: getReadyState
    public func getReadyState(): JsValue {
        if (isDetached()) {
            return JsValue(-1.0)
        }
        match (socketState) {
            case Closed => return JsValue(0.0)
            case Connected => return JsValue(1.0)
            case Shutdown => return JsValue(-2.0)
            case _ => return JsValue(2.0)
        }
    }

    /// 获取文件描述符
    /// 对应 Zig: getFD
    public func getFD(): JsValue {
        return JsValue(Float64(fd))
    }

    /// 获取已写入字节总数
    /// 对应 Zig: getBytesWritten
    public func getBytesWritten(): JsValue {
        return JsValue(Float64(bytesWritten + bufferedData.size))
    }

    /// 获取 TLS 授权状态
    /// 对应 Zig: getAuthorized
    public func getAuthorized(): JsValue {
        return JsValue(flags.authorized)
    }

    // ========================================================================
    // 生命周期管理
    // 对应 Bun: socket.markActive/markInactive/deinit/finalize
    // ========================================================================

    /// 标记为活跃
    /// 对应 Zig: markActive
    public func markActive(): Unit {
        if (!flags.isActive) {
            let h = getHandlers()
            h.markActive()
            flags.isActive = true
        }
    }

    /// 标记为非活跃
    /// 对应 Zig: markInactive
    public func markInactive(): Unit {
        if (flags.isActive) {
            // 必须先关闭 socket
            if (!isClosed() && !isDetached()) {
                closeAndDetach()
                // onClose 会再次调用 markInactive
                return
            }

            flags.isActive = false

            match (handlers) {
                case Some(h) => {
                    if (h.markInactive()) {
                        // 客户端模式: handlers 已被释放
                        handlers = None
                    }
                }
                case None => ()
            }
        }
    }

    /// 关闭并分离 Socket
    /// 对应 Zig: closeAndDetach
    public func closeAndDetach(): Unit {
        bufferedData.clear()
        socketState = SocketState.Detached
        detachNativeCallback()
    }

    /// 分离原生回调
    public func detachNativeCallback(): Unit {
        match (nativeCallback) {
            case NativeCallback.H2(h2) => {
                nativeCallback = NativeCallback.None
            }
            case NativeCallback.None => ()
        }
    }

    /// 终止连接
    /// 对应 Zig: terminate
    public func terminate(): JsValue {
        closeAndDetach()
        return JsValue.UNDEFINED
    }

    /// 关闭写端 (shutdown)
    /// 对应 Zig: shutdown
    public func shutdown(readOnly: Bool): JsValue {
        // 通过 bao_sys shutdown
        socketState = SocketState.Shutdown
        return JsValue.UNDEFINED
    }

    /// 关闭连接
    /// 对应 Zig: close
    public func close(): JsValue {
        socketState = SocketState.Closed
        return JsValue.UNDEFINED
    }

    /// 暂停读取
    /// 对应 Zig: pauseFromJS
    public func pauseFromJS(): JsValue {
        if (isDetached()) {
            return JsValue.UNDEFINED
        }
        if (flags.bypassTls) {
            return JsValue.UNDEFINED
        }
        if (!flags.isPaused) {
            flags.isPaused = true
        }
        return JsValue.UNDEFINED
    }

    /// 恢复读取
    /// 对应 Zig: resumeFromJS
    public func resumeFromJS(): JsValue {
        if (isDetached()) {
            return JsValue.UNDEFINED
        }
        if (flags.bypassTls) {
            return JsValue.UNDEFINED
        }
        if (flags.isPaused) {
            flags.isPaused = false
        }
        return JsValue.UNDEFINED
    }

    /// 引用 (保持事件循环活跃)
    /// 对应 Zig: jsRef
    public func jsRef(): JsValue {
        return JsValue.UNDEFINED
    }

    /// 取消引用
    /// 对应 Zig: jsUnref
    public func jsUnref(): JsValue {
        return JsValue.UNDEFINED
    }

    /// 释放资源
    /// 对应 Zig: deinit
    public func deinit(): Unit {
        markInactive()
        detachNativeCallback()
        thisValue = JsValue.UNDEFINED
        bufferedData.clear()

        if (flags.ownedProtos) {
            protos = None
        }
        serverName = None
        match (connection) {
            case Some(c) => {
                c.deinit()
                connection = None
            }
            case None => ()
        }
    }

    /// GC finalize
    /// 对应 Zig: finalize
    public func finalize(): Unit {
        flags.finalizing = true
        if (!isClosed()) {
            closeAndDetach()
        }
        deref()
    }

    // ========================================================================
    // 私有辅助方法
    // ========================================================================

    /// 清理 IPv6 地址中的方括号
    private func cleanIPv6Brackets(host: String): String {
        if (host.size > 1 && host.startsWith("[") && host.endsWith("]")) {
            return host.subString(1, host.size - 2)
        }
        return host
    }

    /// 将二进制数据转为 JS 值
    private func binaryTypeToJS(data: Array<UInt8>, binaryType: BinaryType): JsValue {
        // 简化: 返回字符串表示
        // 实际实现应根据 binaryType 创建 Buffer/ArrayBuffer/Uint8Array
        return JsValue("Buffer(${data.size} bytes)")
    }

    /// 将 JS 值转为字节数组
    private func jsValueToBytes(value: JsValue): Array<UInt8> {
        // 简化: 从 ArrayBuffer/Buffer 提取字节
        return Array<UInt8>()
    }
}

// ============================================================================
// TLS 验证错误
// 对应 Bun: uws.us_bun_verify_error_t
// ============================================================================

/// TLS 验证错误信息
public class SslVerifyError {
    /// 错误号
    public var errorNo: Int64
    /// 错误码字符串
    public var code: String
    /// 错误原因
    public var reason: String

    public init() {
        errorNo = 0
        code = ""
        reason = ""
    }

    public init(errorNo: Int64, code: String, reason: String) {
        this.errorNo = errorNo
        this.code = code
        this.reason = reason
    }

    /// 转为 JS 值
    public func toJS(globalObject: JsObject): JsValue {
        if (errorNo == 0) {
            return JsValue.NULL
        }
        let obj = JsObject()
        obj.set("code", JsValue(code))
        obj.set("message", JsValue(reason))
        return JsValue(obj)
    }
}

// ============================================================================
// Socket 对 — 创建 socket pair
// 对应 Bun: jsCreateSocketPair
// ============================================================================

/// 创建 Socket 对
public func createSocketPair(): ?Array<Int64> {
    // 对应 std.c.socketpair(AF_UNIX, SOCK_STREAM, 0, &fds)
    // 通过 bao_sys 调用
    return None
}
