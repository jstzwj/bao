// MySQL JS 查询绑定
// 严格翻译自: src/sql_jsc/mysql/JSMySQLQuery.zig
//
// 这是 MySQL 查询的 JS 层封装，负责:
// - 查询创建、运行、取消、完成
// - 参数绑定 (JS 值 → MySQL 值)
// - 结果解析回调 (resolve/reject)
// - 查询状态管理 (pending/running/success/fail)
package bao_runtime.sql.mysql

import bao_core.*
import bao_runtime.sql.shared.*

/// MySQL 查询的 JS 绑定
/// 对应 Bun: JSMySQLQuery
/// 管理查询的 JS 生命周期和回调
public class JSMySQLQuery {
    /// 引用计数
    public var refCount: Int64
    /// JS this 值引用
    public var thisValue: JSValueRef
    /// 全局对象
    public var globalObject: JSValueRef
    /// 虚拟机
    public var vm: JSValueRef
    /// 底层 MySQL 查询
    public var query: MySQLQuery

    // JS 缓存值
    /// pending value (累计结果)
    public var pendingValueCache: JSValueRef
    /// target (JS Query 对象)
    public var targetCache: JSValueRef
    /// columns
    public var columnsCache: JSValueRef
    /// binding (参数数组)
    public var bindingCache: JSValueRef

    public init() {
        refCount = 1
        thisValue = JSValueRef()
        globalObject = JSValueRef()
        vm = JSValueRef()
        query = MySQLQuery()
        pendingValueCache = JSValueRef()
        targetCache = JSValueRef()
        columnsCache = JSValueRef()
        bindingCache = JSValueRef()
    }

    public init(
        globalObject: JSValueRef,
        vm: JSValueRef,
        query: MySQLQuery
    ) {
        refCount = 1
        thisValue = JSValueRef()
        this.globalObject = globalObject
        this.vm = vm
        this.query = query
        pendingValueCache = JSValueRef()
        targetCache = JSValueRef()
        columnsCache = JSValueRef()
        bindingCache = JSValueRef()
    }

    // ============================================================================
    // 引用计数
    // 对应 Bun: RefCount.ref / RefCount.deref
    // ============================================================================

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

    /// 释放资源
    /// 对应 Bun: JSMySQLQuery.deinit
    public func deinit(): Unit {
        query.cleanup()
    }

    /// GC finalize
    /// 对应 Bun: JSMySQLQuery.finalize
    public func finalize(): Unit {
        thisValue.finalize()
        deref()
    }

    // ============================================================================
    // JS 构造器
    // 对应 Bun: JSMySQLQuery.constructor / createInstance
    // ============================================================================

    /// 构造器 (禁止直接构造)
    /// 对应 Bun: JSMySQLQuery.constructor
    public static func constructor(globalObject: JSValueRef, callframe: JSValueRef): JSValueRef {
        return JSValueRef.throwError(globalObject, "MySQLQuery cannot be constructed directly")
    }

    /// 创建查询实例
    /// 对应 Bun: JSMySQLQuery.createInstance
    public static func createInstance(globalObject: JSValueRef, arguments: ArrayList<JSValueRef>): JSValueRef {
        if (arguments.size < 2) {
            return JSValueRef.throwError(globalObject, "query must be a string")
        }

        let queryValue = arguments[0]
        let valuesValue = arguments[1]

        if (!queryValue.isString()) {
            return JSValueRef.throwError(globalObject, "query must be a string")
        }

        let pendingValue: JSValueRef = if (arguments.size > 2) arguments[2] else JSValueRef.UNDEFINED
        let columns: JSValueRef = if (arguments.size > 3) arguments[3] else JSValueRef.UNDEFINED
        let jsBigint: JSValueRef = if (arguments.size > 4) arguments[4] else JSValueRef()
        let jsSimple: JSValueRef = if (arguments.size > 5) arguments[5] else JSValueRef()

        let queryStr = queryValue.toString()
        let mysqlQuery = MySQLQuery(queryStr)

        let this_ = JSMySQLQuery(
            globalObject: globalObject,
            vm: JSValueRef(),
            query: mysqlQuery
        )

        let thisValue = this_.toJS(globalObject)
        this_.thisValue.setWeak(thisValue)

        this_.setBinding(valuesValue)
        this_.setPendingValue(pendingValue)
        if (!columns.isEmptyOrUndefinedOrNull()) {
            this_.setColumns(columns)
        }

        return thisValue
    }

    // ============================================================================
    // 查询操作
    // 对应 Bun: JSMySQLQuery 的 doRun / doCancel / doDone / setModeFromJS
    // ============================================================================

    /// 运行查询
    /// 对应 Bun: JSMySQLQuery.doRun
    public func doRun(globalObject: JSValueRef, arguments: ArrayList<JSValueRef>): JSValueRef {
        ref()
        defer {
            deref()
        }

        if (arguments.size < 2) {
            return JSValueRef.throwError(globalObject, "run must be called with 2 arguments: connection and target")
        }

        let connection = arguments[0]
        let target = arguments[1]
        setTarget(target)

        // 运行查询
        query.run()

        return JSValueRef.UNDEFINED
    }

    /// 取消查询
    /// 对应 Bun: JSMySQLQuery.doCancel
    public func doCancel(): JSValueRef {
        // TODO: 取消尚未管道化的查询
        return JSValueRef.UNDEFINED
    }

    /// 完成
    /// 对应 Bun: JSMySQLQuery.doDone
    public func doDone(): JSValueRef {
        return JSValueRef.UNDEFINED
    }

    /// 设置结果模式
    /// 对应 Bun: JSMySQLQuery.setModeFromJS
    public func setModeFromJS(globalObject: JSValueRef, jsMode: JSValueRef): JSValueRef {
        let modeValue = jsMode.toInt32()
        let mode = match (modeValue) {
            case 0 => SQLQueryResultMode.objects
            case 1 => SQLQueryResultMode.values
            case 2 => SQLQueryResultMode.raw
            case _ => SQLQueryResultMode.objects
        }
        query.setResultMode(mode)
        return JSValueRef.UNDEFINED
    }

    /// 设置 pending value
    /// 对应 Bun: JSMySQLQuery.setPendingValueFromJS
    public func setPendingValueFromJS(result: JSValueRef): JSValueRef {
        setPendingValue(result)
        return JSValueRef.UNDEFINED
    }

    // ============================================================================
    // 结果回调
    // 对应 Bun: JSMySQLQuery.resolve / reject / rejectWithJSValue
    // ============================================================================

    /// 解析结果
    /// 对应 Bun: JSMySQLQuery.resolve
    public func resolve(queriesArray: JSValueRef, result: MySQLQueryResult): Unit {
        ref()

        let isLastResult = result.isLastResult
        defer {
            if (thisValue.isNotEmpty() && isLastResult) {
                thisValue.downgrade()
            }
            deref()
        }

        if (!query.result(isLastResult)) {
            return
        }

        let targetValue = getTarget()
        if (targetValue.isEmpty()) {
            return
        }
        let thisValue_ = if (thisValue.isNotEmpty()) thisValue else JSValueRef.UNDEFINED

        let pendingValue = getPendingValue()
        setPendingValue(JSValueRef.UNDEFINED)

        // 在真实环境中通过事件循环调用 onQueryResolveFn
        // eventLoop.runCallback(resolveFn, globalObject, thisValue,
        //     [targetValue, pendingValue, jsTag, tagNumber, queriesArray, isLastResult, lastInsertId, affectedRows])
    }

    /// 标记为失败 (不接触 JS)
    /// 对应 Bun: JSMySQLQuery.markAsFailed
    public func markAsFailed(): Unit {
        ref()
        defer {
            deref()
        }
        if (thisValue.isNotEmpty()) {
            thisValue.downgrade()
        }
        query.fail()
    }

    /// 拒绝 (带错误)
    /// 对应 Bun: JSMySQLQuery.reject
    public func reject(queriesArray: JSValueRef, err: MySQLError): Unit {
        let jsErr = MySQLErrorJSC.mysqlErrorToJS(globalObject, "Failed to bind query", err)
        rejectWithJSValue(queriesArray, jsErr)
    }

    /// 拒绝 (带 JS 值)
    /// 对应 Bun: JSMySQLQuery.rejectWithJSValue
    public func rejectWithJSValue(queriesArray: JSValueRef, err: JSValueRef): Unit {
        ref()

        defer {
            if (thisValue.isNotEmpty()) {
                thisValue.downgrade()
            }
            deref()
        }

        if (!query.fail()) {
            return
        }

        let targetValue = getTarget()
        if (targetValue.isEmpty()) {
            return
        }

        var jsError = if (err.isError()) err else err
        if (jsError.isZero()) {
            jsError = MySQLErrorJSC.mysqlErrorToJS(globalObject, "Query failed", MySQLError.UnknownError)
        }

        let jsArray = if (queriesArray.isZero()) JSValueRef.UNDEFINED else queriesArray

        // 在真实环境中通过事件循环调用 onQueryRejectFn
        // eventLoop.runCallback(rejectFn, globalObject, thisValue.tryGet(),
        //     [targetValue, jsError, jsArray])
    }

    // ============================================================================
    // 查询状态
    // 对应 Bun: JSMySQLQuery 的 is* 方法
    // ============================================================================

    /// 转为 MySQLQueryRef
    public func asRef(): MySQLQueryRef {
        let ref_ = MySQLQueryRef(query.sql)
        ref_.jsQuery = this
        return ref_
    }

    /// 是否完成
    public func isCompleted(): Bool {
        return query.isCompleted()
    }

    /// 是否正在运行
    public func isRunning(): Bool {
        return query.isRunning()
    }

    /// 是否等待中
    public func isPending(): Bool {
        return query.isPending()
    }

    /// 是否正在预编译
    public func isBeingPrepared(): Bool {
        return query.isBeingPrepared()
    }

    /// 是否已管道化
    public func isPipelined(): Bool {
        return query.isPipelined()
    }

    /// 是否简单查询
    public func isSimple(): Bool {
        return query.isSimple()
    }

    /// 是否支持 BigInt
    public func isBigintSupported(): Bool {
        return query.isBigintSupported()
    }

    /// 获取结果模式
    public func getResultMode(): SQLQueryResultMode {
        return query.getResultMode()
    }

    /// 标记为已预编译
    public func markAsPrepared(): Unit {
        query.markAsPrepared()
    }

    // ============================================================================
    // JS 缓存值操作
    // 对应 Bun: JSMySQLQuery 的 set*/get* Cached 方法
    // ============================================================================

    /// 设置 pending value
    public func setPendingValue(result: JSValueRef): Unit {
        pendingValueCache = result
    }

    /// 获取 pending value
    public func getPendingValue(): JSValueRef {
        if (pendingValueCache.isEmpty()) {
            return None
        }
        return pendingValueCache
    }

    /// 设置 target
    public func setTarget(result: JSValueRef): Unit {
        targetCache = result
    }

    /// 获取 target
    public func getTarget(): JSValueRef {
        return targetCache
    }

    /// 设置 columns
    public func setColumns(result: JSValueRef): Unit {
        columnsCache = result
    }

    /// 获取 columns
    public func getColumns(): JSValueRef {
        if (columnsCache.isEmpty()) {
            return None
        }
        return columnsCache
    }

    /// 设置 binding
    public func setBinding(result: JSValueRef): Unit {
        bindingCache = result
    }

    /// 获取 binding
    public func getBinding(): JSValueRef {
        if (bindingCache.isEmpty()) {
            return None
        }
        return bindingCache
    }

    /// 转为 JS 值
    public func toJS(globalObject: JSValueRef): JSValueRef {
        return JSValueRef.wrap(this)
    }
}

/// MySQL 查询内部逻辑
/// 对应 Bun: MySQLQuery
/// 管理查询 SQL、状态、结果模式和语句引用
public class MySQLQuery {
    /// SQL 文本
    public var sql: String
    /// 查询状态
    public var status: QueryStatus
    /// 是否支持 BigInt
    public var bigint: Bool
    /// 是否简单查询
    public var simple: Bool
    /// 是否已管道化
    public var pipelined: Bool
    /// 结果模式
    public var resultMode: SQLQueryResultMode
    /// 关联的预编译语句
    public var statement: ?MySQLStatement

    public init() {
        sql = ""
        status = QueryStatus.pending
        bigint = false
        simple = false
        pipelined = false
        resultMode = SQLQueryResultMode.objects
        statement = None
    }

    public init(sql: String) {
        this.sql = sql
        status = QueryStatus.pending
        bigint = false
        simple = false
        pipelined = false
        resultMode = SQLQueryResultMode.objects
        statement = None
    }

    public init(sql: String, bigint: Bool, simple: Bool) {
        this.sql = sql
        status = QueryStatus.pending
        this.bigint = bigint
        this.simple = simple
        pipelined = false
        resultMode = SQLQueryResultMode.objects
        statement = None
    }

    /// 设置结果模式
    /// 对应 Bun: MySQLQuery.setResultMode
    public func setResultMode(mode: SQLQueryResultMode): Unit {
        resultMode = mode
    }

    /// 处理结果
    /// 对应 Bun: MySQLQuery.result
    public func result(isLastResult: Bool): Bool {
        if (status == QueryStatus.success || status == QueryStatus.fail) {
            return false
        }
        status = if (isLastResult) QueryStatus.success else QueryStatus.partial_response
        return true
    }

    /// 标记失败
    /// 对应 Bun: MySQLQuery.fail
    public func fail(): Bool {
        if (status == QueryStatus.fail || status == QueryStatus.success) {
            return false
        }
        status = QueryStatus.fail
        return true
    }

    /// 清理资源
    /// 对应 Bun: MySQLQuery.cleanup
    public func cleanup(): Unit {
        statement = None
        sql = ""
    }

    /// 运行查询
    /// 对应 Bun: MySQLQuery.runQuery
    public func run(): Unit {
        if (status != QueryStatus.pending) {
            return
        }
        status = QueryStatus.running
    }

    /// 是否完成
    public func isCompleted(): Bool {
        return status == QueryStatus.success || status == QueryStatus.fail
    }

    /// 是否正在运行
    public func isRunning(): Bool {
        let v = status.value
        return v > QueryStatus.pending.value && v < QueryStatus.success.value
    }

    /// 是否等待中
    public func isPending(): Bool {
        return status == QueryStatus.pending
    }

    /// 是否正在预编译
    public func isBeingPrepared(): Bool {
        return status == QueryStatus.pending &&
            statement.isSome() &&
            statement.getOrThrow().status == StatementStatus.parsing
    }

    /// 是否已管道化
    public func isPipelined(): Bool {
        return pipelined
    }

    /// 是否简单查询
    public func isSimple(): Bool {
        return simple
    }

    /// 是否支持 BigInt
    public func isBigintSupported(): Bool {
        return bigint
    }

    /// 获取结果模式
    public func getResultMode(): SQLQueryResultMode {
        return resultMode
    }

    /// 标记为已预编译
    public func markAsPrepared(): Unit {
        if (status == QueryStatus.pending) {
            if (let Some(stmt) <- statement) {
                if (stmt.status == StatementStatus.parsing &&
                    stmt.params.size == stmt.paramsReceived &&
                    stmt.statementId > 0) {
                    stmt.status = StatementStatus.prepared
                }
            }
        }
    }
}

/// 语句状态 (JSC 层)
/// 对应 Bun: MySQLStatement.Status
public enum StatementStatus {
    | pending
    | parsing
    | prepared
    | failed
}
