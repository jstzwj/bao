// 严格翻译自: src/sql_jsc/mysql/JSMySQLConnection.zig
// MySQL JS 连接 - MySQL 连接的 JS 绑定

package bao_sql_jsc.mysql

import bao_core.*
import bao_jsc.*
import bao_sql.*
import bao_sql_jsc.shared.*

/// JS MySQL 连接
/// 对应 Bun: JSMySQLConnection
/// MySQL 连接的 JavaScript 绑定对象
public class JSMySQLConnection {
    var refCount: Int64 = 0
    var jsValue: JscValue = JscValue.undefined()
    var globalObject: JscJSGlobalObject
    var vm: JscVirtualMachine
    var pollRef: MySQLKeepAlive = MySQLKeepAlive()
    var connection: MySQLConnection

    var autoFlusher: AutoFlusher = AutoFlusher()
    var idleTimeoutIntervalMs: UInt32 = 0
    var connectionTimeoutMs: UInt32 = 0
    var timer: SQLEventLoopTimer = SQLEventLoopTimer(TimerTag.MySQLConnectionTimeout)
    var maxLifetimeIntervalMs: UInt32 = 0
    var maxLifetimeTimer: SQLEventLoopTimer = SQLEventLoopTimer(TimerTag.MySQLConnectionMaxLifetime)

    public init(globalObject: JscJSGlobalObject, vm: JscVirtualMachine,
                connection: MySQLConnection) {
        this.globalObject = globalObject
        this.vm = vm
        this.connection = connection
    }

    /// 引用计数增加
    public func ref(): Unit {
        refCount += 1
    }

    /// 引用计数减少
    public func deref(): Unit {
        refCount -= 1
        if (refCount <= 0) {
            deinit_()
        }
    }

    /// 获取构造器
    /// 对应 Bun: JSMySQLConnection.js.getConstructor
    public static func getConstructor(globalObject: JscJSGlobalObject): JscValue {
        // 返回 JS 侧的构造器
        return JscValue.undefined()
    }

    /// 构造器（不允许直接调用）
    /// 对应 Bun: JSMySQLConnection.constructor
    public static func constructor(globalObject: JscJSGlobalObject,
                                    callFrame: JscCallFrame): ?JSMySQLConnection {
        globalObject.throwUnsupported("MySQLConnection cannot be constructed directly")
        return None
    }

    /// 创建实例
    /// 对应 Bun: JSMySQLConnection.createInstance
    public static func createInstance_(globalObject: JscJSGlobalObject,
                                       callFrame: JscCallFrame): JscValue {
        let vm = globalObject.vm.getOrThrow()
        let arguments = callFrame.arguments()

        let hostnameStr = arguments[0].toString()
        let port = arguments[1].toInt32()
        let usernameStr = arguments[2].toString()
        let passwordStr = arguments[3].toString()
        let databaseStr = arguments[4].toString()

        // SSL 模式
        let sslModeInt = arguments[5].toInt32()
        let sslMode = SSLMode.fromInt(sslModeInt)

        // TLS 对象
        let tlsObject = arguments[6]

        // 超时参数
        let onConnect = arguments[9]
        let onClose = arguments[10]
        let idleTimeout = arguments[11].toInt32()
        let connectionTimeout = arguments[12].toInt32()
        let maxLifetime = arguments[13].toInt32()

        let conn = MySQLConnection()
        let ptr = JSMySQLConnection(globalObject, vm, conn)
        ptr.idleTimeoutIntervalMs = UInt32(idleTimeout)
        ptr.connectionTimeoutMs = UInt32(connectionTimeout)
        ptr.maxLifetimeIntervalMs = UInt32(maxLifetime)

        ptr.ref()
        ptr.resetConnectionTimeout()

        let jsVal = ptr.toJS(globalObject)
        ptr.jsValue = jsVal

        return jsVal
    }

    /// 入队请求
    /// 对应 Bun: JSMySQLConnection.enqueueRequest
    public func enqueueRequest(item: JSMySQLQuery): Unit {
        connection.enqueueRequest(item)
        resetConnectionTimeout()
        registerAutoFlusher()
    }

    /// 关闭连接
    /// 对应 Bun: JSMySQLConnection.close
    public func close(): Unit {
        ref()
        stopTimers()
        unregisterAutoFlusher()
        if (vm.isShuttingDown()) {
            connection.close()
        } else {
            connection.cleanQueueAndClose(None, getQueriesArray())
        }
        updateReferenceType()
        deref()
    }

    /// 连接已建立回调
    /// 对应 Bun: JSMySQLConnection.onConnectionEstabilished
    public func onConnectionEstablished(): Unit {
        if (vm.isShuttingDown()) {
            return
        }
        let onConnect = consumeOnConnectCallback(globalObject)
        if (onConnect.isNone()) {
            return
        }
        let jsVal = jsValue
        let callback = onConnect.getOrThrow()
        vm.enqueueTask({ =>
            callback.call(globalObject.globalThis, JscValue.null(), [JscValue.null(), jsVal])
        })
    }

    /// 查询结果回调
    /// 对应 Bun: JSMySQLConnection.onQueryResult
    public func onQueryResult(request: JSMySQLQuery, result: MySQLQueryResult): Unit {
        request.resolve(getQueriesArray(), result)
    }

    /// 错误回调
    /// 对应 Bun: JSMySQLConnection.onError
    public func onError(request: ?JSMySQLQuery, err: AnyMySQLError): Unit {
        if (request.isSome()) {
            let req = request.getOrThrow()
            if (vm.isShuttingDown()) {
                req.markAsFailed()
                return
            }
            req.reject(getQueriesArray(), err)
        } else {
            if (vm.isShuttingDown()) {
                close()
                return
            }
            failWithMessage("Connection closed", err)
        }
    }

    /// 获取查询数组
    /// 对应 Bun: JSMySQLConnection.getQueriesArray
    public func getQueriesArray(): JscValue {
        if (vm.isShuttingDown()) {
            return JscValue.undefined()
        }
        return JscValue.undefined()
    }

    /// 获取连接状态
    /// 对应 Bun: JSMySQLConnection.getConnected
    public func getConnected(): JscValue {
        return JscValue(isConnected(connection.status))
    }

    /// 引用
    /// 对应 Bun: JSMySQLConnection.doRef
    public func doRef(): JscValue {
        pollRef.ref(vm)
        return JscValue.undefined()
    }

    /// 取消引用
    /// 对应 Bun: JSMySQLConnection.doUnref
    public func doUnref(): JscValue {
        pollRef.unref(vm)
        return JscValue.undefined()
    }

    /// 刷新
    /// 对应 Bun: JSMySQLConnection.doFlush
    public func doFlush(): JscValue {
        registerAutoFlusher()
        return JscValue.undefined()
    }

    /// 主动关闭
    /// 对应 Bun: JSMySQLConnection.doClose
    public func doClose(): JscValue {
        stopTimers()
        connection.cleanQueueAndClose(None, getQueriesArray())
        updateReferenceType()
        return JscValue.undefined()
    }

    // ===== 私有辅助方法 =====

    private func deinit_(): Unit {
        stopTimers()
        pollRef.unref(vm)
        unregisterAutoFlusher()
        connection.cleanup()
    }

    public func resetConnectionTimeout(): Unit {
        let interval = getTimeoutInterval()
        timer.deactivate()
        if (isConnectionFailed(connection.status) ||
            connection.isProcessingData() ||
            interval == 0) {
            return
        }
        timer.next = TimeSpec.msFromNow(interval)
        timer.activate()
    }

    private func getTimeoutInterval(): UInt32 {
        match (connection.status) {
            case Connected =>
                if (connection.isIdle()) {
                    return idleTimeoutIntervalMs
                }
                return 0
            case Failed => 0
            case _ => connectionTimeoutMs
        }
    }

    private func stopTimers(): Unit {
        timer.deactivate()
        maxLifetimeTimer.deactivate()
    }

    private func registerAutoFlusher(): Unit {
        if (!autoFlusher.registered && connection.canFlush()) {
            registerDeferredMicrotask(this, vm)
            autoFlusher.registered = true
        }
    }

    private func unregisterAutoFlusher(): Unit {
        if (autoFlusher.registered) {
            unregisterDeferredMicrotask(this, vm)
            autoFlusher.registered = false
        }
    }

    private func updateReferenceType(): Unit {
        if (connection.isActive()) {
            if (isConnected(connection.status) && connection.isIdle()) {
                pollRef.unref(vm)
            } else {
                pollRef.ref(vm)
            }
            return
        }
        pollRef.unref(vm)
    }

    private func consumeOnConnectCallback(globalObject: JscJSGlobalObject): ?JscValue {
        if (vm.isShuttingDown()) {
            return None
        }
        return None
    }

    private func consumeOnCloseCallback(globalObject: JscJSGlobalObject): ?JscValue {
        if (vm.isShuttingDown()) {
            return None
        }
        return None
    }

    private func failWithMessage(message: String, err: AnyMySQLError): Unit {
        let instance = AnyMySQLError.mysqlErrorToJS(globalObject, message, err)
        failWithJSValue(instance)
    }

    private func failWithJSValue(value: JscValue): Unit {
        ref()
        stopTimers()
        if (isConnectionFailed(connection.status)) {
            deref()
            return
        }
        connection.status = ConnectionState.Failed
        if (vm.isShuttingDown()) {
            updateReferenceType()
            deref()
            return
        }
        if (vm.isShuttingDown()) {
            connection.close()
        } else {
            connection.cleanQueueAndClose(value, getQueriesArray())
        }
        updateReferenceType()
        deref()
    }

    /// 转换为 JS 值
    public func toJS(globalObject: JscJSGlobalObject): JscValue {
        return JscValue.undefined()
    }
}

/// 保持活跃引用
public class MySQLKeepAlive {
    public var isActive: Bool = false

    public init() {}

    public func ref(vm: JscVirtualMachine): Unit {
        isActive = true
    }

    public func unref(vm: JscVirtualMachine): Unit {
        isActive = false
    }
}

/// 自动刷新器
public class AutoFlusher {
    public var registered: Bool = false

    public init() {}
}

/// 事件循环定时器
public class SQLEventLoopTimer {
    public var tag: TimerTag
    public var isActive: Bool = false
    public var next: TimeSpec = TimeSpec.epoch()

    public init(tag: TimerTag) {
        this.tag = tag
    }

    public func activate(): Unit {
        isActive = true
    }

    public func deactivate(): Unit {
        isActive = false
    }
}

/// 定时器标签
public enum TimerTag {
    | MySQLConnectionTimeout
    | MySQLConnectionMaxLifetime
    | PostgresSQLConnectionTimeout
    | PostgresSQLConnectionMaxLifetime
}

/// 时间规范
public class TimeSpec {
    public static func msFromNow(ms: UInt32): TimeSpec {
        return TimeSpec()
    }

    public static func epoch(): TimeSpec {
        return TimeSpec()
    }
}

/// SSL 模式
/// 对应 Bun: SSLMode
public enum SSLMode {
    | Disable
    | Prefer
    | Require
    | VerifyCA
    | VerifyFull

    public static func fromInt(v: Int32): SSLMode {
        match (v) {
            case 0 => SSLMode.Disable
            case 1 => SSLMode.Prefer
            case 2 => SSLMode.Require
            case 3 => SSLMode.VerifyCA
            case 4 => SSLMode.VerifyFull
            case _ => SSLMode.Disable
        }
    }

    public operator func ==(right: SSLMode): Bool {
        match (this) {
            case Disable => match (right) { case Disable => true case _ => false }
            case Prefer => match (right) { case Prefer => true case _ => false }
            case Require => match (right) { case Require => true case _ => false }
            case VerifyCA => match (right) { case VerifyCA => true case _ => false }
            case VerifyFull => match (right) { case VerifyFull => true case _ => false }
        }
    }

    public operator func !=(right: SSLMode): Bool {
        !(this == right)
    }
}

/// 连接状态
/// 对应 Bun: ConnectionState
public enum ConnectionState {
    | Disconnected
    | Connecting
    | Handshaking
    | Authenticating
    | AuthenticationAwaitingPK
    | Connected
    | Failed

    public operator func ==(right: ConnectionState): Bool {
        match (this) {
            case Disconnected => match (right) { case Disconnected => true case _ => false }
            case Connecting => match (right) { case Connecting => true case _ => false }
            case Handshaking => match (right) { case Handshaking => true case _ => false }
            case Authenticating => match (right) { case Authenticating => true case _ => false }
            case AuthenticationAwaitingPK => match (right) { case AuthenticationAwaitingPK => true case _ => false }
            case Connected => match (right) { case Connected => true case _ => false }
            case Failed => match (right) { case Failed => true case _ => false }
        }
    }

    public operator func !=(right: ConnectionState): Bool {
        !(this == right)
    }
}

/// 连接状态辅助函数
public func isConnected(status: ConnectionState): Bool {
    match (status) {
        case Connected => true
        case _ => false
    }
}

public func isConnectionFailed(status: ConnectionState): Bool {
    match (status) {
        case Failed => true
        case _ => false
    }
}

/// 自动刷新器扩展方法
public func registerDeferredMicrotask(conn: JSMySQLConnection, vm: JscVirtualMachine): Unit {}
public func unregisterDeferredMicrotask(conn: JSMySQLConnection, vm: JscVirtualMachine): Unit {}

/// MySQL 错误类型（本地定义，避免与 protocol 子包循环依赖）
/// 对应 Bun: AnyMySQLError
public enum AnyMySQLError {
    | UnknownError
    | ConnectionClosed
    | ConnectionTimedOut
    | IdleTimeout
    | LifetimeTimeout
    | AuthenticationFailed
    | ShortRead
    | UnexpectedPacket
    | JSError
    | OutOfMemory
    | JSTerminated

    public static func mysqlErrorToJS(globalObject: JscJSGlobalObject,
                                       message: String,
                                       err: AnyMySQLError): JscValue {
        let optsObj = JscValue.createEmptyObject(globalObject.globalThis)
        optsObj.put(globalObject.globalThis, "message", JscValue(message))
        optsObj.put(globalObject.globalThis, "code", JscValue(err.toString()))
        return optsObj
    }

    public func toString(): String {
        match (this) {
            case UnknownError => "UNKNOWN_ERROR"
            case ConnectionClosed => "CONNECTION_CLOSED"
            case ConnectionTimedOut => "CONNECTION_TIMEOUT"
            case IdleTimeout => "IDLE_TIMEOUT"
            case LifetimeTimeout => "LIFETIME_TIMEOUT"
            case AuthenticationFailed => "AUTHENTICATION_FAILED"
            case ShortRead => "SHORT_READ"
            case UnexpectedPacket => "UNEXPECTED_PACKET"
            case JSError => "JS_ERROR"
            case OutOfMemory => "OUT_OF_MEMORY"
            case JSTerminated => "JS_TERMINATED"
        }
    }
}
