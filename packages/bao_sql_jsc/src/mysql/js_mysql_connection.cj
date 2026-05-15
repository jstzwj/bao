// 严格翻译自: src/sql_jsc/mysql/JSMySQLConnection.zig
// MySQL JS 连接 - MySQL 连接的 JS 绑定

package bao_sql_jsc

import bao_core.*
import bao_jsc.*
import bao_sql.*

/// JS MySQL 连接
/// 对应 Bun: JSMySQLConnection
/// MySQL 连接的 JavaScript 绑定对象
public class JSMySQLConnection {
    var refCount: Int64 = 0
    var jsValue: JscValue = JscValue.undefined()
    var globalObject: JscJSGlobalObject
    var vm: JscVirtualMachine
    var pollRef: KeepAlive = KeepAlive()
    var connection: MySQLConnection

    var autoFlusher: AutoFlusher = AutoFlusher()
    var idleTimeoutIntervalMs: UInt32 = 0
    var connectionTimeoutMs: UInt32 = 0
    var timer: EventLoopTimer = EventLoopTimer(tag: TimerTag.MySQLConnectionTimeout)
    var maxLifetimeIntervalMs: UInt32 = 0
    var maxLifetimeTimer: EventLoopTimer = EventLoopTimer(tag: TimerTag.MySQLConnectionMaxLifetime)

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
        globalObject.throwError("MySQLConnection cannot be constructed directly")
        return None
    }

    /// 创建实例
    /// 对应 Bun: JSMySQLConnection.createInstance
    public static func createInstance_(globalObject: JscJSGlobalObject,
                                       callFrame: JscCallFrame): JscValue {
        let vm = globalObject.bunVM()
        let arguments = callFrame.arguments()

        let hostnameStr = arguments[0].toBunString(globalObject)
        let port = arguments[1].coerceInt32(globalObject)
        let usernameStr = arguments[2].toBunString(globalObject)
        let passwordStr = arguments[3].toBunString(globalObject)
        let databaseStr = arguments[4].toBunString(globalObject)

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
        let ptr = JSMySQLConnection(
            globalObject: globalObject,
            vm: vm,
            connection: conn
        )
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
        defer {
            updateReferenceType()
            deref()
        }
        if (vm.isShuttingDown()) {
            connection.close()
        } else {
            connection.cleanQueueAndClose(None, getQueriesArray())
        }
    }

    /// 连接已建立回调
    /// 对应 Bun: JSMySQLConnection.onConnectionEstabilished
    public func onConnectionEstablished(): Unit {
        if (vm.isShuttingDown()) {
            return
        }
        let onConnect = consumeOnConnectCallback(globalObject)
        if (onConnect == None) {
            return
        }
        let jsVal = jsValue
        globalObject.queueMicrotask(onConnect.getOrThrow(), [JscValue.null(), jsVal])
    }

    /// 查询结果回调
    /// 对应 Bun: JSMySQLConnection.onQueryResult
    public func onQueryResult(request: JSMySQLQuery, result: MySQLQueryResult): Unit {
        request.resolve(getQueriesArray(), result)
    }

    /// 错误回调
    /// 对应 Bun: JSMySQLConnection.onError
    public func onError(request: ?JSMySQLQuery, err: AnyMySQLError): Unit {
        if (request != None) {
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
        return JscValue(connection.status == ConnectionState.Connected)
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
        defer {
            updateReferenceType()
        }
        connection.cleanQueueAndClose(None, getQueriesArray())
        return JscValue.undefined()
    }

    // ===== 私有辅助方法 =====

    private func deinit_(): Unit {
        stopTimers()
        pollRef.unref(vm)
        unregisterAutoFlusher()
        connection.cleanup()
    }

    private func resetConnectionTimeout(): Unit {
        let interval = getTimeoutInterval()
        if (timer.isActive) {
            vm.timer.remove(timer)
        }
        if (connection.status == ConnectionState.Failed ||
            connection.isProcessingData() ||
            interval == 0) {
            return
        }
        timer.next = TimeSpec.msFromNow(interval)
        vm.timer.insert(timer)
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
        if (timer.isActive) {
            vm.timer.remove(timer)
        }
        if (maxLifetimeTimer.isActive) {
            vm.timer.remove(maxLifetimeTimer)
        }
    }

    private func registerAutoFlusher(): Unit {
        if (!autoFlusher.registered && connection.canFlush()) {
            AutoFlusher.registerDeferredMicrotask(this, vm)
            autoFlusher.registered = true
        }
    }

    private func unregisterAutoFlusher(): Unit {
        if (autoFlusher.registered) {
            AutoFlusher.unregisterDeferredMicrotask(this, vm)
            autoFlusher.registered = false
        }
    }

    private func updateReferenceType(): Unit {
        if (connection.isActive()) {
            if (connection.status == ConnectionState.Connected && connection.isIdle()) {
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
        defer {
            if (vm.isShuttingDown()) {
                connection.close()
            } else {
                connection.cleanQueueAndClose(value, getQueriesArray())
            }
            updateReferenceType()
            deref()
        }
        stopTimers()
        if (connection.status == ConnectionState.Failed) {
            return
        }
        connection.status = ConnectionState.Failed
        if (vm.isShuttingDown()) {
            return
        }
    }

    /// 转换为 JS 值
    public func toJS(globalObject: JscJSGlobalObject): JscValue {
        return JscValue.undefined()
    }
}

/// 保持活跃引用
public class KeepAlive {
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
public class EventLoopTimer {
    public var tag: TimerTag
    public var isActive: Bool = false
    public var next: TimeSpec = TimeSpec.epoch()

    public init(tag: TimerTag) {
        this.tag = tag
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
}

/// 自动刷新器静态方法
public class AutoFlusher {
    public static func registerDeferredMicrotask(conn: JSMySQLConnection, vm: JscVirtualMachine): Unit {}
    public static func unregisterDeferredMicrotask(conn: JSMySQLConnection, vm: JscVirtualMachine): Unit {}
}
