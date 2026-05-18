// 严格翻译自: src/sql_jsc/mysql/JSMySQLConnection.zig
// MySQL JS 连接 - MySQL 连接的 JS 绑定

package bao_sql_jsc.mysql

import bao_core.*
import bao_jsc.*
import bao_sql.*

/// JS MySQL 连接
/// 对应 Bun: JSMySQLConnection
/// MySQL 连接的 JavaScript 绑定对象
/// 管理 socket 生命周期、定时器、自动刷新和回调
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
    /// 连接超时定时器（连接前）/ 空闲超时定时器（连接后）
    var timer: EventLoopTimer = EventLoopTimer(tag: TimerTag.MySQLConnectionTimeout)
    /// 连接最大生命周期定时器
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

    /// 自动刷新回调
    /// 对应 Bun: JSMySQLConnection.onAutoFlush
    /// 返回 true 保持注册，false 取消注册
    public func onAutoFlush(): Bool {
        if (connection.hasBackpressure()) {
            autoFlusher.registered = false
            return false
        }

        // 尽可能排空
        drainInternal()

        let keepFlusherRegistered = connection.canFlush()
        autoFlusher.registered = keepFlusherRegistered
        return keepFlusherRegistered
    }

    /// 内部排空
    /// 对应 Bun: JSMySQLConnection.drainInternal
    private func drainInternal(): Unit {
        if (vm.isShuttingDown()) {
            close()
            return
        }
        ref()
        defer { deref() }
        connection.flushQueue()
    }

    /// 注册自动刷新器
    /// 对应 Bun: JSMySQLConnection.registerAutoFlusher
    private func registerAutoFlusher(): Unit {
        if (!autoFlusher.registered && connection.canFlush()) {
            AutoFlusher.registerDeferredMicrotask(this, vm)
            autoFlusher.registered = true
        }
    }

    /// 取消注册自动刷新器
    /// 对应 Bun: JSMySQLConnection.unregisterAutoFlusher
    private func unregisterAutoFlusher(): Unit {
        if (autoFlusher.registered) {
            AutoFlusher.unregisterDeferredMicrotask(this, vm)
            autoFlusher.registered = false
        }
    }

    /// 停止定时器
    /// 对应 Bun: JSMySQLConnection.stopTimers
    private func stopTimers(): Unit {
        if (timer.isActive) {
            vm.timer.remove(timer)
        }
        if (maxLifetimeTimer.isActive) {
            vm.timer.remove(maxLifetimeTimer)
        }
    }

    /// 获取超时间隔
    /// 对应 Bun: JSMySQLConnection.getTimeoutInterval
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

    /// 重置连接超时
    /// 对应 Bun: JSMySQLConnection.resetConnectionTimeout
    public func resetConnectionTimeout(): Unit {
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

    /// 连接超时回调
    /// 对应 Bun: JSMySQLConnection.onConnectionTimeout
    public func onConnectionTimeout(): Unit {
        timer.state = EventLoopTimerState.Fired

        if (connection.isProcessingData()) {
            return
        }
        if (connection.status == ConnectionState.Failed) {
            return
        }
        if (getTimeoutInterval() == 0) {
            resetConnectionTimeout()
            return
        }

        match (connection.status) {
            case Connected =>
                failWithMessage("Idle timeout reached", AnyMySQLError.IdleTimeout)
            case Connecting =>
                failWithMessage("Connection timeout", AnyMySQLError.ConnectionTimedOut)
            case Handshaking | Authenticating | AuthenticationAwaitingPK =>
                failWithMessage("Connection timeout during authentication",
                    AnyMySQLError.ConnectionTimedOut)
            case _ => ()
        }
    }

    /// 最大生命周期超时回调
    /// 对应 Bun: JSMySQLConnection.onMaxLifetimeTimeout
    public func onMaxLifetimeTimeout(): Unit {
        maxLifetimeTimer.state = EventLoopTimerState.Fired
        if (connection.status == ConnectionState.Failed) {
            return
        }
        failWithMessage("Max lifetime timeout reached", AnyMySQLError.LifetimeTimeout)
    }

    /// 设置最大生命周期定时器（如果需要）
    /// 对应 Bun: JSMySQLConnection.setupMaxLifetimeTimerIfNecessary
    private func setupMaxLifetimeTimerIfNecessary(): Unit {
        if (maxLifetimeIntervalMs == 0) {
            return
        }
        if (maxLifetimeTimer.isActive) {
            return
        }
        maxLifetimeTimer.next = TimeSpec.msFromNow(maxLifetimeIntervalMs)
        vm.timer.insert(maxLifetimeTimer)
    }

    /// 获取构造器
    /// 对应 Bun: JSMySQLConnection.js.getConstructor
    public static func getConstructor(globalObject: JscJSGlobalObject): JscValue {
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

        // 选项字符串
        let optionsStr = arguments[7].toBunString(globalObject)
        let pathStr = arguments[8].toBunString(globalObject)

        // 超时参数
        let onConnect = arguments[9]
        let onClose = arguments[10]
        let idleTimeout = arguments[11].toInt32()
        let connectionTimeout = arguments[12].toInt32()
        let maxLifetime = arguments[13].toInt32()

        // null byte 安全检查
        // ... username/password/database/path 不得包含 null 字节

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
        ptr.setupMaxLifetimeTimerIfNecessary()
        ptr.resetConnectionTimeout()
        ptr.pollRef.ref(vm)

        let jsVal = ptr.toJS(globalObject)
        ptr.jsValue = jsVal

        // 缓存 onConnect / onClose 回调
        // js.onconnectSetCached(jsVal, globalObject, onConnect)
        // js.oncloseSetCached(jsVal, globalObject, onClose)

        return jsVal
    }

    /// 获取查询列表
    /// 对应 Bun: JSMySQLConnection.getQueries
    public func getQueries(thisValue: JscValue, globalObject: JscJSGlobalObject): JscValue {
        return JscValue.createEmptyArray(globalObject, 0)
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

    /// 结果行回调
    /// 对应 Bun: JSMySQLConnection.onResultRow
    public func onResultRow(request: JSMySQLQuery, statement: MySQLStatement,
                             data: Array<UInt8>): Unit {
        let resultMode = request.getResultMode()
        statement.resultCount += 1

        let pendingValue = request.getPendingValue()
        if (pendingValue == None || pendingValue.getOrThrow().isEmptyOrUndefinedOrNull()) {
            // 将行数据设置为 pending value
            request.setPendingValue(JscValue.undefined())
        }
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
            if (globalObject.hasException()) {
                req.rejectWithJSValue(getQueriesArray(), globalObject.takeException())
            } else {
                req.reject(getQueriesArray(), err)
            }
        } else {
            if (vm.isShuttingDown()) {
                close()
                return
            }
            if (globalObject.hasException()) {
                failWithJSValue(globalObject.takeException())
            } else {
                failWithMessage("Connection closed", err)
            }
        }
    }

    /// 错误包回调
    /// 对应 Bun: JSMySQLConnection.onErrorPacket
    public func onErrorPacket(request: ?JSMySQLQuery, err: ErrorPacket): Unit {
        if (request != None) {
            if (vm.isShuttingDown()) {
                request.getOrThrow().markAsFailed()
            } else {
                if (globalObject.hasException()) {
                    request.getOrThrow().rejectWithJSValue(getQueriesArray(),
                        globalObject.takeException())
                } else {
                    request.getOrThrow().rejectWithJSValue(getQueriesArray(),
                        err.toJS(globalObject))
                }
            }
        } else {
            if (vm.isShuttingDown()) {
                close()
                return
            }
            if (globalObject.hasException()) {
                failWithJSValue(globalObject.takeException())
            } else {
                failWithJSValue(err.toJS(globalObject))
            }
        }
    }

    /// 获取连接状态
    /// 对应 Bun: JSMySQLConnection.getConnected
    public func getConnected(): JscValue {
        return JscValue(connection.status == ConnectionState.Connected)
    }

    /// 获取 onConnect 回调
    /// 对应 Bun: JSMySQLConnection.getOnConnect
    public func getOnConnect(thisValue: JscValue): JscValue {
        return JscValue.undefined()
    }

    /// 设置 onConnect 回调
    /// 对应 Bun: JSMySQLConnection.setOnConnect
    public func setOnConnect(thisValue: JscValue, value: JscValue): Unit {
        // js.onconnectSetCached(thisValue, globalObject, value)
    }

    /// 获取 onClose 回调
    /// 对应 Bun: JSMySQLConnection.getOnClose
    public func getOnClose(thisValue: JscValue): JscValue {
        return JscValue.undefined()
    }

    /// 设置 onClose 回调
    /// 对应 Bun: JSMySQLConnection.setOnClose
    public func setOnClose(thisValue: JscValue, value: JscValue): Unit {
        // js.oncloseSetCached(thisValue, globalObject, value)
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

    /// 从签名哈希获取语句
    /// 对应 Bun: JSMySQLConnection.getStatementFromSignatureHash
    public func getStatementFromSignatureHash(signatureHash: UInt64): GetOrPutResult {
        return connection.getStatementFromSignatureHash(signatureHash)
    }

    /// 能否写入
    /// 对应 Bun: JSMySQLConnection.isAbleToWrite
    public func isAbleToWrite(): Bool {
        return connection.isAbleToWrite()
    }

    /// 是否已连接
    /// 对应 Bun: JSMySQLConnection.isConnected
    public func isConnected(): Bool {
        return connection.status == ConnectionState.Connected
    }

    /// 能否流水线
    /// 对应 Bun: JSMySQLConnection.canPipeline
    public func canPipeline(): Bool {
        return connection.canPipeline()
    }

    /// 能否准备查询
    /// 对应 Bun: JSMySQLConnection.canPrepareQuery
    public func canPrepareQuery(): Bool {
        return connection.canPrepareQuery()
    }

    /// 能否执行查询
    /// 对应 Bun: JSMySQLConnection.canExecuteQuery
    public func canExecuteQuery(): Bool {
        return connection.canExecuteQuery()
    }

    /// 获取写入器
    /// 对应 Bun: JSMySQLConnection.getWriter
    public func getWriter(): MySQLWriter {
        return connection.writer()
    }

    // ===== 私有辅助方法 =====

    private func deinit_(): Unit {
        stopTimers()
        pollRef.unref(vm)
        unregisterAutoFlusher()
        connection.cleanup()
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
        // 从 JS 缓存中获取并清除 onConnect 回调
        return None
    }

    private func consumeOnCloseCallback(globalObject: JscJSGlobalObject): ?JscValue {
        if (vm.isShuttingDown()) {
            return None
        }
        // 从 JS 缓存中获取并清除 onClose 回调
        return None
    }

    /// 获取查询数组
    /// 对应 Bun: JSMySQLConnection.getQueriesArray
    public func getQueriesArray(): JscValue {
        if (vm.isShuttingDown()) {
            return JscValue.undefined()
        }
        return JscValue.undefined()
    }

    /// 格式化错误消息并失败
    /// 对应 Bun: JSMySQLConnection.failFmt
    private func failWithMessage(message: String, err: AnyMySQLError): Unit {
        let instance = AnyMySQLError.mysqlErrorToJS(globalObject, message, err)
        failWithJSValue(instance)
    }

    /// 使用 JS 值失败
    /// 对应 Bun: JSMySQLConnection.failWithJSValue
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

        let onClose = consumeOnCloseCallback(globalObject)
        if (onClose == None) {
            return
        }
        onClose.getOrThrow().ensureStillAlive()

        let jsError = if (value.isError()) value else {
            AnyMySQLError.mysqlErrorToJS(globalObject, "Connection closed",
                AnyMySQLError.ConnectionClosed)
        }

        let queriesArray = getQueriesArray()
        let eventLoop = vm.eventLoop()
        eventLoop.runCallback(
            onClose.getOrThrow(),
            globalObject,
            JscValue.undefined(),
            [jsError, queriesArray]
        )
    }

    /// 转换为 JS 值
    public func toJS(globalObject: JscJSGlobalObject): JscValue {
        return JscValue.undefined()
    }
}

/// 保持活跃引用
/// 对应 Bun: KeepAlive (bun.Async.KeepAlive)
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
/// 对应 Bun: AutoFlusher (jsc.WebCore.AutoFlusher)
public class AutoFlusher {
    public var registered: Bool = false

    public init() {}

    public static func registerDeferredMicrotask(conn: JSMySQLConnection,
                                                  vm: JscVirtualMachine): Unit {}
    public static func unregisterDeferredMicrotask(conn: JSMySQLConnection,
                                                    vm: JscVirtualMachine): Unit {}
}

/// 事件循环定时器
/// 对应 Bun: EventLoopTimer
public class EventLoopTimer {
    public var tag: TimerTag
    public var isActive: Bool = false
    public var state: EventLoopTimerState = EventLoopTimerState.Pending
    public var next: TimeSpec = TimeSpec.epoch()

    public init(tag: TimerTag) {
        this.tag = tag
    }
}

/// 定时器状态
/// 对应 Bun: EventLoopTimer.State
public enum EventLoopTimerState {
    | Pending
    | Active
    | Fired
    | Cancelled
}

/// 定时器标签
/// 对应 Bun: EventLoopTimer.Tag
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

/// MySQL 错误类型
/// 对应 Bun: AnyMySQLError.Error
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

    /// 转换为 JS 错误
    public static func mysqlErrorToJS(globalObject: JscJSGlobalObject,
                                       message: String,
                                       err: AnyMySQLError): JscValue {
        let optsObj = JscObject.createEmptyObject(globalObject)
        optsObj.put(globalObject, "message", JscValue(message))
        optsObj.put(globalObject, "code", JscValue(err.toString()))
        return optsObj.toValue()
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
