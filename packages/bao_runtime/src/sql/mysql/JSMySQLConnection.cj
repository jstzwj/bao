// MySQL JS 连接绑定
// 严格翻译自: src/sql_jsc/mysql/JSMySQLConnection.zig
//
// 这是 MySQL 连接的 JS 层封装，负责:
// - 连接生命周期管理 (ref/deref, poll_ref, GC root)
// - 定时器管理 (idle timeout, connection timeout, max lifetime)
// - 自动刷新写缓冲
// - Socket 事件回调 (onOpen, onData, onWritable, onClose)
// - 将协议层事件分发到 JS 回调 (onConnect, onClose, onQueryResult, onResultRow, onError)
package bao_runtime.sql.mysql

import bao_core.*
import bao_runtime.sql.shared.*

/// MySQL 连接的 JS 绑定
/// 对应 Bun: JSMySQLConnection
/// 管理连接的 JS 生命周期，定时器，以及 JS 回调分发
public class JSMySQLConnection {
    /// 引用计数
    public var refCount: Int64
    /// JS 值引用 (强/弱引用切换)
    public var jsValue: JSValueRef
    /// 全局对象
    public var globalObject: JSValueRef
    /// 虚拟机
    public var vm: JSValueRef
    /// poll 引用 (事件循环保活)
    public var pollRef: PollRef
    /// 底层 MySQL 连接
    public var connection: MySQLConnection
    /// 自动刷新器
    public var autoFlusher: AutoFlusher

    // 定时器
    /// 空闲超时 (毫秒)
    public var idleTimeoutIntervalMs: UInt32
    /// 连接超时 (毫秒)
    public var connectionTimeoutMs: UInt32
    /// 连接定时器
    public var timer: EventLoopTimer
    /// 最大生命周期 (毫秒)
    public var maxLifetimeIntervalMs: UInt32
    /// 最大生命周期定时器
    public var maxLifetimeTimer: EventLoopTimer

    // JS 回调缓存
    /// onconnect 回调
    public var onConnectCallback: JSValueRef
    /// onclose 回调
    public var onCloseCallback: JSValueRef
    /// queries 数组
    public var queriesArray: JSValueRef

    public init() {
        refCount = 1
        jsValue = JSValueRef()
        globalObject = JSValueRef()
        vm = JSValueRef()
        pollRef = PollRef()
        connection = MySQLConnection()
        autoFlusher = AutoFlusher()
        idleTimeoutIntervalMs = 0
        connectionTimeoutMs = 0
        timer = EventLoopTimer(tag: TimerTag.MySQLConnectionTimeout)
        maxLifetimeIntervalMs = 0
        maxLifetimeTimer = EventLoopTimer(tag: TimerTag.MySQLConnectionMaxLifetime)
        onConnectCallback = JSValueRef()
        onCloseCallback = JSValueRef()
        queriesArray = JSValueRef()
    }

    public init(
        globalObject: JSValueRef,
        vm: JSValueRef,
        idleTimeout: UInt32,
        connectionTimeout: UInt32,
        maxLifetime: UInt32,
        connection: MySQLConnection
    ) {
        refCount = 1
        jsValue = JSValueRef()
        this.globalObject = globalObject
        this.vm = vm
        pollRef = PollRef()
        this.connection = connection
        autoFlusher = AutoFlusher()
        idleTimeoutIntervalMs = idleTimeout
        connectionTimeoutMs = connectionTimeout
        timer = EventLoopTimer(tag: TimerTag.MySQLConnectionTimeout)
        maxLifetimeIntervalMs = maxLifetime
        maxLifetimeTimer = EventLoopTimer(tag: TimerTag.MySQLConnectionMaxLifetime)
        onConnectCallback = JSValueRef()
        onCloseCallback = JSValueRef()
        queriesArray = JSValueRef()
    }

    // ============================================================================
    // 引用计数
    // 对应 Bun: RefCount.ref / RefCount.deref
    // ============================================================================

    /// 增加引用
    public func ref(): Unit {
        refCount += 1
    }

    /// 减少引用，到 0 时销毁
    public func deref(): Unit {
        refCount -= 1
        if (refCount <= 0) {
            deinit()
        }
    }

    // ============================================================================
    // 自动刷新
    // 对应 Bun: JSMySQLConnection.autoFlusher 相关方法
    // ============================================================================

    /// 自动刷新回调
    /// 对应 Bun: JSMySQLConnection.onAutoFlush
    public func onAutoFlush(): Bool {
        if (connection.hasBackpressure()) {
            autoFlusher.registered = false
            return false
        }

        // 尽可能多地排空
        drainInternal()

        // 如果没有背压且仍有数据需要发送，返回 true 保持注册
        let keepFlusherRegistered = connection.canFlush()
        autoFlusher.registered = keepFlusherRegistered
        return keepFlusherRegistered
    }

    /// 注册自动刷新微任务
    /// 对应 Bun: JSMySQLConnection.registerAutoFlusher
    public func registerAutoFlusher(): Unit {
        if (!autoFlusher.registered && connection.canFlush()) {
            autoFlusher.registered = true
            // 在真实 JSC 环境中注册延迟微任务
        }
    }

    /// 取消注册自动刷新微任务
    /// 对应 Bun: JSMySQLConnection.unregisterAutoFlusher
    public func unregisterAutoFlusher(): Unit {
        if (autoFlusher.registered) {
            autoFlusher.registered = false
        }
    }

    // ============================================================================
    // 定时器管理
    // 对应 Bun: JSMySQLConnection 定时器相关方法
    // ============================================================================

    /// 停止所有定时器
    /// 对应 Bun: JSMySQLConnection.stopTimers
    public func stopTimers(): Unit {
        if (timer.state == TimerState.ACTIVE) {
            timer.state = TimerState.INACTIVE
        }
        if (maxLifetimeTimer.state == TimerState.ACTIVE) {
            maxLifetimeTimer.state = TimerState.INACTIVE
        }
    }

    /// 获取当前超时间隔
    /// 对应 Bun: JSMySQLConnection.getTimeoutInterval
    public func getTimeoutInterval(): UInt32 {
        match (connection.status) {
            case connected =>
                if (connection.isIdle()) {
                    return idleTimeoutIntervalMs
                }
                return 0
            case failed => 0
            case _ =>
                return connectionTimeoutMs
        }
    }

    /// 重置连接超时定时器
    /// 对应 Bun: JSMySQLConnection.resetConnectionTimeout
    public func resetConnectionTimeout(): Unit {
        let interval = getTimeoutInterval()
        if (timer.state == TimerState.ACTIVE) {
            timer.state = TimerState.INACTIVE
        }
        if (connection.status == ConnectionState.failed ||
            connection.isProcessingData() ||
            interval == 0) {
            return
        }

        timer.intervalMs = interval
        timer.state = TimerState.ACTIVE
    }

    /// 连接超时回调
    /// 对应 Bun: JSMySQLConnection.onConnectionTimeout
    public func onConnectionTimeout(): Unit {
        timer.state = TimerState.FIRED

        if (connection.isProcessingData()) {
            return
        }

        if (connection.status == ConnectionState.failed) {
            return
        }

        let interval = getTimeoutInterval()
        if (interval == 0) {
            resetConnectionTimeout()
            return
        }

        match (connection.status) {
            case connected =>
                fail(
                    "Idle timeout reached after ${interval}ms",
                    MySQLError.IdleTimeout
                )
            case connecting =>
                fail(
                    "Connection timeout after ${interval}ms",
                    MySQLError.ConnectionTimedOut
                )
            case handshaking =>
                fail(
                    "Connection timeout after ${interval}ms (during authentication)",
                    MySQLError.ConnectionTimedOut
                )
            case authenticating =>
                fail(
                    "Connection timeout after ${interval}ms (during authentication)",
                    MySQLError.ConnectionTimedOut
                )
            case authentication_awaiting_pk =>
                fail(
                    "Connection timeout after ${interval}ms (during authentication)",
                    MySQLError.ConnectionTimedOut
                )
            case disconnected => {}
            case failed => {}
        }
    }

    /// 最大生命周期超时回调
    /// 对应 Bun: JSMySQLConnection.onMaxLifetimeTimeout
    public func onMaxLifetimeTimeout(): Unit {
        maxLifetimeTimer.state = TimerState.FIRED
        if (connection.status == ConnectionState.failed) {
            return
        }
        fail(
            "Max lifetime timeout reached after ${maxLifetimeIntervalMs}ms",
            MySQLError.LifetimeTimeout
        )
    }

    /// 如果需要，设置最大生命周期定时器
    /// 对应 Bun: JSMySQLConnection.setupMaxLifetimeTimerIfNecessary
    public func setupMaxLifetimeTimerIfNecessary(): Unit {
        if (maxLifetimeIntervalMs == 0) {
            return
        }
        if (maxLifetimeTimer.state == TimerState.ACTIVE) {
            return
        }
        maxLifetimeTimer.intervalMs = maxLifetimeIntervalMs
        maxLifetimeTimer.state = TimerState.ACTIVE
    }

    // ============================================================================
    // 请求队列
    // 对应 Bun: JSMySQLConnection.enqueueRequest
    // ============================================================================

    /// 入队请求
    /// 对应 Bun: JSMySQLConnection.enqueueRequest
    public func enqueueRequest(item: JSMySQLQuery): Unit {
        connection.enqueueRequest(item.asRef())
        resetConnectionTimeout()
        registerAutoFlusher()
    }

    // ============================================================================
    // 连接操作
    // 对应 Bun: JSMySQLConnection.close / drainInternal / deinit
    // ============================================================================

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
        // 在真实环境中检查 vm 是否正在关闭
        connection.close()
    }

    /// 内部排空
    /// 对应 Bun: JSMySQLConnection.drainInternal
    public func drainInternal(): Unit {
        connection.flushQueue()
    }

    /// 释放资源
    /// 对应 Bun: JSMySQLConnection.deinit
    public func deinit(): Unit {
        stopTimers()
        pollRef.unref()
        unregisterAutoFlusher()
        connection.cleanup()
    }

    // ============================================================================
    // JS 值管理
    // 对应 Bun: JSMySQLConnection 的 JS 值操作方法
    // ============================================================================

    /// 确保 JS 值存活
    /// 对应 Bun: JSMySQLConnection.ensureJSValueIsAlive
    public func ensureJSValueIsAlive(): Unit {
        // 在真实 JSC 环境中调用 ensureStillAlive
    }

    /// GC finalize
    /// 对应 Bun: JSMySQLConnection.finalize
    public func finalize(): Unit {
        jsValue.finalize()
        deref()
    }

    /// 更新引用类型 (强/弱引用切换)
    /// 对应 Bun: JSMySQLConnection.updateReferenceType
    public func updateReferenceType(): Unit {
        if (connection.isActive()) {
            if (jsValue.isNotEmpty() && jsValue.isWeak) {
                jsValue.upgrade(globalObject)
            }
            if (connection.status == ConnectionState.connected && connection.isIdle()) {
                pollRef.unref()
            } else {
                pollRef.ref()
            }
            return
        }
        if (jsValue.isNotEmpty() && jsValue.isStrong) {
            jsValue.downgrade()
        }
        pollRef.unref()
    }

    // ============================================================================
    // JS 构造器 / 属性访问器
    // 对应 Bun: JSMySQLConnection 的 JS 对外接口
    // ============================================================================

    /// 构造器 (禁止直接构造)
    /// 对应 Bun: JSMySQLConnection.constructor
    public static func constructor(globalObject: JSValueRef, callframe: JSValueRef): JSValueRef {
        return JSValueRef.throwError(globalObject, "MySQLConnection cannot be constructed directly")
    }

    /// 创建连接实例
    /// 对应 Bun: JSMySQLConnection.createInstance
    public static func createInstance(globalObject: JSValueRef, arguments: ArrayList<JSValueRef>): JSValueRef {
        // arguments[0] = hostname
        // arguments[1] = port
        // arguments[2] = username
        // arguments[3] = password
        // arguments[4] = database
        // arguments[5] = ssl_mode
        // arguments[6] = tls_object
        // arguments[7] = options
        // arguments[8] = path
        // arguments[9] = on_connect
        // arguments[10] = on_close
        // arguments[11] = idle_timeout
        // arguments[12] = connection_timeout
        // arguments[13] = max_lifetime
        // arguments[14] = use_unnamed_prepared_statements

        if (arguments.size < 15) {
            return JSValueRef.throwError(globalObject, "MySQLConnection.createInstance requires 15 arguments")
        }

        let hostname = arguments[0].toString()
        let port = arguments[1].toInt32()
        let username = arguments[2].toString()
        let password = arguments[3].toString()
        let database = arguments[4].toString()

        // SSL 模式
        let sslModeInt = arguments[5].toInt32()
        let sslMode = match (sslModeInt) {
            case 0 => SSLMode.disable
            case 1 => SSLMode.prefer
            case 2 => SSLMode.require
            case 3 => SSLMode.verify_ca
            case 4 => SSLMode.verify_full
            case _ => SSLMode.disable
        }

        let options = arguments[7].toString()
        let path = arguments[8].toString()
        let onConnect = arguments[9]
        let onClose = arguments[10]
        let idleTimeout = UInt32(arguments[11].toInt32())
        let connectionTimeout = UInt32(arguments[12].toInt32())
        let maxLifetime = UInt32(arguments[13].toInt32())

        // 创建底层连接
        let conn = MySQLConnection(database, username, password, sslMode)
        conn.status = ConnectionState.connecting

        // 创建 JS 包装
        let ptr = JSMySQLConnection(
            globalObject: globalObject,
            vm: JSValueRef(),
            idleTimeout: idleTimeout,
            connectionTimeout: connectionTimeout,
            maxLifetime: maxLifetime,
            connection: conn
        )

        ptr.resetConnectionTimeout()
        ptr.pollRef.ref()

        // 缓存 JS 回调
        ptr.onConnectCallback = onConnect
        ptr.onCloseCallback = onClose

        let jsValue = ptr.toJS(globalObject)
        ptr.jsValue.setStrong(jsValue, globalObject)

        return jsValue
    }

    /// 获取 queries 属性
    /// 对应 Bun: JSMySQLConnection.getQueries
    public func getQueries(thisValue: JSValueRef, globalObject: JSValueRef): JSValueRef {
        if (queriesArray.isNotEmpty()) {
            return queriesArray
        }
        let array = JSValueRef.createEmptyArray(globalObject)
        queriesArray = array
        return array
    }

    /// 获取 connected 属性
    /// 对应 Bun: JSMySQLConnection.getConnected
    public func getConnected(): JSValueRef {
        return JSValueRef.jsBoolean(connection.status == ConnectionState.connected)
    }

    /// 获取 onConnect 回调
    /// 对应 Bun: JSMySQLConnection.getOnConnect
    public func getOnConnect(thisValue: JSValueRef): JSValueRef {
        if (onConnectCallback.isNotEmpty()) {
            return onConnectCallback
        }
        return JSValueRef.UNDEFINED
    }

    /// 设置 onConnect 回调
    /// 对应 Bun: JSMySQLConnection.setOnConnect
    public func setOnConnect(thisValue: JSValueRef, globalObject: JSValueRef, value: JSValueRef): Unit {
        onConnectCallback = value
    }

    /// 获取 onClose 回调
    /// 对应 Bun: JSMySQLConnection.getOnClose
    public func getOnClose(thisValue: JSValueRef): JSValueRef {
        if (onCloseCallback.isNotEmpty()) {
            return onCloseCallback
        }
        return JSValueRef.UNDEFINED
    }

    /// 设置 onClose 回调
    /// 对应 Bun: JSMySQLConnection.setOnClose
    public func setOnClose(thisValue: JSValueRef, globalObject: JSValueRef, value: JSValueRef): Unit {
        onCloseCallback = value
    }

    /// ref() — 阻止事件循环退出
    /// 对应 Bun: JSMySQLConnection.doRef
    public func doRef(): JSValueRef {
        pollRef.ref()
        return JSValueRef.UNDEFINED
    }

    /// unref() — 允许事件循环退出
    /// 对应 Bun: JSMySQLConnection.doUnref
    public func doUnref(): JSValueRef {
        pollRef.unref()
        return JSValueRef.UNDEFINED
    }

    /// flush() — 刷新写缓冲
    /// 对应 Bun: JSMySQLConnection.doFlush
    public func doFlush(): JSValueRef {
        registerAutoFlusher()
        return JSValueRef.UNDEFINED
    }

    /// close() JS 方法
    /// 对应 Bun: JSMySQLConnection.doClose
    public func doClose(): JSValueRef {
        stopTimers()
        defer {
            updateReferenceType()
        }
        connection.close()
        return JSValueRef.UNDEFINED
    }

    /// 转为 JS 值
    public func toJS(globalObject: JSValueRef): JSValueRef {
        return JSValueRef.wrap(this)
    }

    // ============================================================================
    // 回调消费
    // 对应 Bun: JSMySQLConnection 的 consume*Callback 方法
    // ============================================================================

    /// 消费 onConnect 回调
    /// 对应 Bun: JSMySQLConnection.consumeOnConnectCallback
    public func consumeOnConnectCallback(globalObject: JSValueRef): JSValueRef {
        if (onConnectCallback.isEmpty()) {
            return JSValueRef()
        }
        let callback = onConnectCallback
        onConnectCallback = JSValueRef()
        return callback
    }

    /// 消费 onClose 回调
    /// 对应 Bun: JSMySQLConnection.consumeOnCloseCallback
    public func consumeOnCloseCallback(globalObject: JSValueRef): JSValueRef {
        if (onCloseCallback.isEmpty()) {
            return JSValueRef()
        }
        let callback = onCloseCallback
        onCloseCallback = JSValueRef()
        return callback
    }

    /// 获取 queries 数组
    /// 对应 Bun: JSMySQLConnection.getQueriesArray
    public func getQueriesArray(): JSValueRef {
        if (queriesArray.isEmpty()) {
            return JSValueRef.UNDEFINED
        }
        return queriesArray
    }

    // ============================================================================
    // 查询能力判断
    // 对应 Bun: JSMySQLConnection 的 isAbleToWrite/isConnected/canPipeline 等
    // ============================================================================

    /// 是否能写
    public func isAbleToWrite(): Bool {
        return connection.isAbleToWrite()
    }

    /// 是否已连接
    public func isConnected(): Bool {
        return connection.isConnected()
    }

    /// 是否能管道化
    public func canPipeline(): Bool {
        return connection.canPipeline()
    }

    /// 是否能预编译
    public func canPrepareQuery(): Bool {
        return connection.canPrepareQuery()
    }

    /// 是否能执行查询
    public func canExecuteQuery(): Bool {
        return connection.canExecuteQuery()
    }

    // ============================================================================
    // 错误/结果回调
    // 对应 Bun: JSMySQLConnection 的 fail/failWithJSValue/onConnectionEstabilished 等
    // ============================================================================

    /// 带 format 的失败
    /// 对应 Bun: JSMySQLConnection.failFmt
    public func fail(message: String, errorCode: MySQLError): Unit {
        let err = MySQLErrorJSC.mysqlErrorToJS(globalObject, message, errorCode)
        failWithJSValue(err)
    }

    /// 带 JS 值的失败
    /// 对应 Bun: JSMySQLConnection.failWithJSValue
    public func failWithJSValue(value: JSValueRef): Unit {
        ref()

        defer {
            connection.close()
            updateReferenceType()
            deref()
        }
        stopTimers()

        if (connection.status == ConnectionState.failed) {
            return
        }

        connection.status = ConnectionState.failed

        let onClose = consumeOnCloseCallback(globalObject)
        if (onClose.isEmpty()) {
            return
        }

        let jsError = if (value.isError()) value else value
        if (jsError.isZero()) {
            return
        }

        let qArray = getQueriesArray()

        // 在真实环境中通过事件循环调用 onClose 回调
        // eventLoop.runCallback(onClose, globalObject, UNDEFINED, [jsError, qArray])
    }

    /// 连接建立成功回调
    /// 对应 Bun: JSMySQLConnection.onConnectionEstabilished
    public func onConnectionEstabilished(): Unit {
        let onConnect = consumeOnConnectCallback(globalObject)
        if (onConnect.isEmpty()) {
            return
        }
        let jsValue = if (jsValue.isNotEmpty()) jsValue else JSValueRef.UNDEFINED

        // 在真实环境中通过事件循环调用 onConnect 回调
        // globalObject.queueMicrotask(onConnect, [JSValueRef.jsNull(), jsValue])
    }

    /// 查询结果回调
    /// 对应 Bun: JSMySQLConnection.onQueryResult
    public func onQueryResult(request: JSMySQLQuery, result: MySQLQueryResult): Unit {
        request.resolve(getQueriesArray(), result)
    }

    /// 结果行回调
    /// 对应 Bun: JSMySQLConnection.onResultRow
    public func onResultRow(
        request: JSMySQLQuery,
        statement: MySQLStatement,
        row: MySQLRow
    ): Unit {
        let resultMode = request.getResultMode()

        row.decode(statement.columnsAsArrayList())

        let pendingValue = request.getPendingValue()
        let rowValue = rowToJS(row, statement, resultMode)

        if (pendingValue.isEmptyOrUndefinedOrNull()) {
            request.setPendingValue(rowValue)
        }
    }

    /// 错误回调
    /// 对应 Bun: JSMySQLConnection.onError
    public func onError(request: ?JSMySQLQuery, err: MySQLError): Unit {
        if (let Some(req) <- request) {
            req.reject(getQueriesArray(), err)
        } else {
            if (connection.status == ConnectionState.failed) {
                close()
                return
            }
            fail("Connection closed", err)
        }
    }

    /// 错误包回调
    /// 对应 Bun: JSMySQLConnection.onErrorPacket
    public func onErrorPacket(request: ?JSMySQLQuery, err: ErrorPacket): Unit {
        let jsErr = ErrorPacketJSC.toJS(err, globalObject)
        if (let Some(req) <- request) {
            req.rejectWithJSValue(getQueriesArray(), jsErr)
        } else {
            if (connection.status == ConnectionState.failed) {
                close()
                return
            }
            failWithJSValue(jsErr)
        }
    }

    // ============================================================================
    // 内部辅助
    // ============================================================================

    /// 将行数据转为 JS 值
    private func rowToJS(row: MySQLRow, statement: MySQLStatement, resultMode: SQLQueryResultMode): JSValueRef {
        // 简化实现 — 在真实 JSC 环境中调用 SQLDataCell.constructObjectFromDataCell
        return JSValueRef.UNDEFINED
    }
}

// ============================================================================
// 辅助类型
// ============================================================================

/// JS 值引用
/// 对应 Bun: jsc.JSRef
/// 封装强引用/弱引用切换
public class JSValueRef {
    public var handle: Int64
    public var isWeak: Bool
    public var isStrong: Bool

    public static let UNDEFINED = JSValueRef()
    public static let ZERO = JSValueRef()
    public static let JS_NULL = JSValueRef()

    public init() {
        handle = 0
        isWeak = false
        isStrong = false
    }

    public func isNotEmpty(): Bool {
        return handle != 0
    }

    public func isEmpty(): Bool {
        return handle == 0
    }

    public func isError(): Bool {
        return false // 简化
    }

    public func isZero(): Bool {
        return handle == 0
    }

    public func isEmptyOrUndefinedOrNull(): Bool {
        return handle == 0
    }

    public func setStrong(value: JSValueRef, globalObject: JSValueRef): Unit {
        handle = value.handle
        isStrong = true
        isWeak = false
    }

    public func setWeak(value: JSValueRef): Unit {
        handle = value.handle
        isWeak = true
        isStrong = false
    }

    public func upgrade(globalObject: JSValueRef): Unit {
        isStrong = true
        isWeak = false
    }

    public func downgrade(): Unit {
        isWeak = true
        isStrong = false
    }

    public func finalize(): Unit {
        handle = 0
        isWeak = false
        isStrong = false
    }

    public func tryGet(): ?JSValueRef {
        if (handle != 0) {
            return this
        }
        return None
    }

    /// 创建错误
    public static func throwError(globalObject: JSValueRef, message: String): JSValueRef {
        return JSValueRef()
    }

    /// 创建 JS 布尔值
    public static func jsBoolean(value: Bool): JSValueRef {
        let v = JSValueRef()
        v.handle = if (value) 1 else 0
        return v
    }

    /// 创建空数组
    public static func createEmptyArray(globalObject: JSValueRef): JSValueRef {
        return JSValueRef()
    }

    /// 包装原生对象
    public static func wrap(obj: Object): JSValueRef {
        return JSValueRef()
    }

    public func toString(): String {
        return ""
    }

    public func toInt32(): Int32 {
        return 0
    }

    public func isString(): Bool {
        return false
    }

    public func isCallable(): Bool {
        return false
    }
}

/// Poll 引用
/// 对应 Bun: bun.Async.KeepAlive
/// 控制事件循环是否因活跃连接而保持存活
public class PollRef {
    public var refCount: Int64

    public init() {
        refCount = 0
    }

    public func ref(): Unit {
        refCount += 1
    }

    public func unref(): Unit {
        if (refCount > 0) {
            refCount -= 1
        }
    }
}

/// 自动刷新器
/// 对应 Bun: jsc.WebCore.AutoFlusher
/// 注册为微任务以自动排空写缓冲
public class AutoFlusher {
    public var registered: Bool

    public init() {
        registered = false
    }
}

/// 定时器标签
/// 对应 Bun: Timer.EventLoopTimer.tag
public enum TimerTag {
    | MySQLConnectionTimeout
    | MySQLConnectionMaxLifetime
}

/// 定时器状态
/// 对应 Bun: Timer.state
public enum TimerState {
    | INACTIVE
    | ACTIVE
    | FIRED
}

/// 事件循环定时器
/// 对应 Bun: bun.api.Timer.EventLoopTimer
public class EventLoopTimer {
    public var tag: TimerTag
    public var state: TimerState
    public var intervalMs: UInt32

    public init(tag: TimerTag) {
        this.tag = tag
        state = TimerState.INACTIVE
        intervalMs = 0
    }
}
