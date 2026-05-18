// 严格翻译自: src/sql_jsc/mysql/JSMySQLQuery.rs
// MySQL JS 查询 - MySQL 查询的 JS 绑定

package bao_sql_jsc.mysql

import bao_core.*
import bao_jsc.*
import bao_sql.*

/// JS MySQL 查询
/// 对应 Bun: JSMySQLQuery
/// MySQL 查询的 JavaScript 绑定对象
/// 使用侵入式引用计数管理生命周期，通过 JsCell 实现内部可变性
public class JSMySQLQuery {
    var refCount: Int64 = 0
    var thisValue: JscValue = JscValue.undefined()
    var vm: JscVirtualMachine
    var globalObject: JscJSGlobalObject
    var query: MySQLQuery

    /// JS 缓存的 target 值（resolve/reject 回调的第一个参数）
    var targetValue: JscValue = JscValue.undefined()
    /// JS 缓存的 pendingValue（查询结果累加器）
    var pendingValue: JscValue = JscValue.undefined()
    /// JS 缓存的 columns 值
    var columnsValue: JscValue = JscValue.undefined()
    /// JS 缓存的 binding 值（查询参数绑定数组）
    var bindingValue: JscValue = JscValue.undefined()

    public init(vm: JscVirtualMachine, globalObject: JscJSGlobalObject,
                query: MySQLQuery) {
        this.vm = vm
        this.globalObject = globalObject
        this.query = query
    }

    /// 引用计数增加
    /// 对应 Bun: JSMySQLQuery.ref_
    public func ref(): Unit {
        refCount += 1
    }

    /// 引用计数减少
    /// 对应 Bun: JSMySQLQuery.deref
    public func deref(): Unit {
        refCount -= 1
        if (refCount <= 0) {
            deinit_()
        }
    }

    /// 释放资源
    /// 对应 Bun: JSMySQLQuery.deinit (Drop)
    private func deinit_(): Unit {
        query.cleanup()
    }

    /// 构造器（不允许直接调用）
    /// 对应 Bun: JSMySQLQuery.constructor
    public static func constructor(globalObject: JscJSGlobalObject,
                                    callFrame: JscCallFrame): ?JSMySQLQuery {
        globalObject.throwError("MySQLQuery cannot be constructed directly")
        return None
    }

    /// Finalize（GC 回调）
    /// 对应 Bun: JSMySQLQuery.finalize
    public func finalize(): Unit {
        thisValue = JscValue.undefined()
        deref()
    }

    /// 创建查询实例
    /// 对应 Bun: JSMySQLQuery.createInstance
    public static func createInstance_(globalObject: JscJSGlobalObject,
                                       callFrame: JscCallFrame): JscValue {
        let arguments = callFrame.arguments()
        let queryVal = arguments[0]
        let values = arguments[1]

        if (!queryVal.isString()) {
            globalObject.throwError("query must be a string")
            return JscValue.undefined()
        }

        if (!values.isArray()) {
            globalObject.throwError("values must be an array")
            return JscValue.undefined()
        }

        let pendingValue: JscValue = if (arguments.size > 2) arguments[2] else JscValue.undefined()
        let columns: JscValue = if (arguments.size > 3) arguments[3] else JscValue.undefined()
        let jsBigint: JscValue = if (arguments.size > 4) arguments[4] else JscValue.false_()
        let jsSimple: JscValue = if (arguments.size > 5) arguments[5] else JscValue.false_()

        let bigint = jsBigint.isBoolean() && jsBigint.asBoolean()
        let simple = jsSimple.isBoolean() && jsSimple.asBoolean()

        if (simple) {
            let valuesLength = values.getLength(globalObject)
            if (valuesLength != None && valuesLength.getOrThrow() > 0) {
                globalObject.throwError("simple query cannot have parameters")
                return JscValue.undefined()
            }
            let queryLength = queryVal.getLength(globalObject)
            if (queryLength != None && queryLength.getOrThrow() >= Int32.MaxValue) {
                globalObject.throwError("query is too long")
                return JscValue.undefined()
            }
        }

        // 检查 pendingValue 是否为数组类型
        if (!pendingValue.jsType().isArrayLike()) {
            globalObject.throwError("pendingValue must be an Array")
            return JscValue.undefined()
        }

        let queryString = queryVal.toBunString(globalObject)
        let mysqlQuery = MySQLQuery(query: queryString, bigint: bigint, simple: simple)

        let vm = globalObject.bunVM()
        let ptr = JSMySQLQuery(
            vm: vm,
            globalObject: globalObject,
            query: mysqlQuery
        )
        ptr.ref()

        let jsVal = ptr.toJS(globalObject)
        ptr.thisValue = jsVal

        // 设置缓存值
        ptr.bindingValue = values
        ptr.pendingValue = pendingValue
        if (!columns.isUndefined()) {
            ptr.columnsValue = columns
        }

        return jsVal
    }

    /// 执行查询
    /// 对应 Bun: JSMySQLQuery.doRun
    public func doRun(globalObject: JscJSGlobalObject,
                       callFrame: JscCallFrame): JscValue {
        ref()

        let arguments = callFrame.arguments()
        if (arguments.size < 2) {
            globalObject.throwError("run must be called with 2 arguments connection and target")
            return JscValue.undefined()
        }

        let connection: ?JSMySQLConnection = arguments[0].asMySQLConnection()
        if (connection == None) {
            globalObject.throwError("connection must be a MySQLConnection")
            return JscValue.undefined()
        }

        let target = arguments[1]
        if (!target.isObject()) {
            globalObject.throwError("query must be a Query")
            return JscValue.undefined()
        }

        // 设置 target
        targetValue = target

        // 运行查询
        if (let Err(err) <- run(connection.getOrThrow())) {
            if (!globalObject.hasException()) {
                return globalObject.throwValue(
                    AnyMySQLError.mysqlErrorToJS(globalObject, "failed to execute query",
                        AnyMySQLError.UnknownError))
            }
            deref()
            return JscValue.undefined()
        }

        connection.getOrThrow().enqueueRequest(this)
        deref()
        return JscValue.undefined()
    }

    /// 取消查询
    /// 对应 Bun: JSMySQLQuery.doCancel
    public func doCancel(): JscValue {
        // TODO: 可以取消待定的查询（未流水线的），正在运行的查询不值得/无法取消
        return JscValue.undefined()
    }

    /// 完成查询
    /// 对应 Bun: JSMySQLQuery.doDone
    public func doDone(): JscValue {
        return JscValue.undefined()
    }

    /// 从 JS 设置结果模式
    /// 对应 Bun: JSMySQLQuery.setModeFromJS
    public func setModeFromJS(globalObject: JscJSGlobalObject,
                               callFrame: JscCallFrame): JscValue {
        let jsMode = callFrame.argument(0)
        if (jsMode.isEmptyOrUndefinedOrNull() || !jsMode.isNumber()) {
            globalObject.throwError("mode must be a Number")
            return JscValue.undefined()
        }

        let modeValue = jsMode.coerceInt32(globalObject)
        let mode = match (modeValue) {
            case 0 => SQLQueryResultMode.Objects
            case 1 => SQLQueryResultMode.Values
            case 2 => SQLQueryResultMode.Raw
            case _ =>
                globalObject.throwError("invalid mode value")
                return JscValue.undefined()
        }
        query.setResultMode(mode)
        return JscValue.undefined()
    }

    /// 从 JS 设置 pendingValue
    /// 对应 Bun: JSMySQLQuery.setPendingValueFromJS
    public func setPendingValueFromJS(callFrame: JscCallFrame): JscValue {
        let result = callFrame.argument(0)
        setPendingValue(result)
        return JscValue.undefined()
    }

    /// Resolve 查询结果
    /// 对应 Bun: JSMySQLQuery.resolve
    public func resolve(queriesArray: JscValue, result: MySQLQueryResult): Unit {
        ref()
        let isLastResult = result.isLastResult
        defer {
            if (thisValue.isNotEmpty() && isLastResult) {
                // 最后结果时降级 JS 引用
            }
            deref()
        }

        if (!query.result(isLastResult)) {
            return
        }
        if (vm.isShuttingDown()) {
            return
        }

        let target = getTarget()
        if (target == None) {
            return
        }

        let tag = CommandTag.select(result.resultCount)
        let jsTag = tag.toJSTag(globalObject)

        let function = vm.rareData().mysqlContext.onQueryResolveFn
        if (function == None) {
            return
        }

        let pending = getPendingValue()
        let pendingVal = if (pending != None) pending.getOrThrow() else JscValue.undefined()
        setPendingValue(JscValue.undefined())

        let eventLoop = vm.eventLoop()
        eventLoop.runCallback(
            function.getOrThrow(),
            globalObject,
            thisValue,
            [
                target.getOrThrow(),
                pendingVal,
                jsTag,
                tag.toJSNumber(),
                if (queriesArray.isEmpty()) JscValue.undefined() else queriesArray,
                JscValue(isLastResult),
                JscValue(Float64(result.lastInsertId)),
                JscValue(Float64(result.affectedRows))
            ]
        )
    }

    /// 标记为失败（不触碰 JS）
    /// 对应 Bun: JSMySQLQuery.markAsFailed
    /// 注意：此处不能触碰 JS，如需触碰 JS 请使用 reject 或 rejectWithJSValue
    public func markAsFailed(): Unit {
        ref()
        if (thisValue.isNotEmpty()) {
            // 降级 JS 引用
        }
        let _ = query.fail()
        deref()
    }

    /// Reject 查询
    /// 对应 Bun: JSMySQLQuery.reject
    public func reject(queriesArray: JscValue, err: AnyMySQLError): Unit {
        if (vm.isShuttingDown()) {
            markAsFailed()
            return
        }
        if (globalObject.hasException()) {
            rejectWithJSValue(queriesArray, globalObject.takeException())
        } else {
            let instance = AnyMySQLError.mysqlErrorToJS(globalObject, "Failed to bind query", err)
            rejectWithJSValue(queriesArray, instance)
        }
    }

    /// 使用 JS 值 reject
    /// 对应 Bun: JSMySQLQuery.rejectWithJSValue
    public func rejectWithJSValue(queriesArray: JscValue, err: JscValue): Unit {
        ref()
        defer {
            if (thisValue.isNotEmpty()) {
                // 降级 JS 引用
            }
            deref()
        }

        if (!query.fail()) {
            return
        }

        if (vm.isShuttingDown()) {
            return
        }
        let target = getTarget()
        if (target == None) {
            return
        }

        var jsError = if (err.isError()) err else {
            AnyMySQLError.mysqlErrorToJS(globalObject, "Query failed",
                AnyMySQLError.UnknownError)
        }

        let function = vm.rareData().mysqlContext.onQueryRejectFn
        if (function == None) {
            return
        }

        let eventLoop = vm.eventLoop()
        let jsArray = if (queriesArray.isEmpty()) JscValue.undefined() else queriesArray
        eventLoop.runCallback(
            function.getOrThrow(),
            globalObject,
            thisValue,
            [target.getOrThrow(), jsError, jsArray]
        )
    }

    /// 运行查询
    /// 对应 Bun: JSMySQLQuery.run
    public func run(connection: JSMySQLConnection): Unit {
        if (vm.isShuttingDown()) {
            return
        }
        if (!query.isPending() || query.isBeingPrepared()) {
            return
        }

        // 升级 JS 引用
        // 错误时回滚
        let columns = if (columnsValue.isUndefined()) JscValue.undefined() else columnsValue
        let binding = if (bindingValue.isUndefined()) JscValue.undefined() else bindingValue

        if (let Err(err) <- query.runQuery(connection, globalObject, columns, binding)) {
            // 回滚：降级 JS 引用并标记失败
            let _ = query.fail()
            return
        }
    }

    /// 查询是否完成
    public func isCompleted(): Bool {
        return query.isCompleted()
    }

    /// 查询是否在运行
    public func isRunning(): Bool {
        return query.isRunning()
    }

    /// 查询是否待定
    public func isPending(): Bool {
        return query.isPending()
    }

    /// 查询是否在准备中
    public func isBeingPrepared(): Bool {
        return query.isBeingPrepared()
    }

    /// 是否流水线
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

    /// 获取语句
    public func getStatement(): ?MySQLStatement {
        return query.getStatement()
    }

    /// 标记为已准备
    public func markAsPrepared(): Unit {
        query.markAsPrepared()
    }

    // ===== 缓存值访问器 =====

    /// 设置 pendingValue
    /// 对应 Bun: JSMySQLQuery.setPendingValue
    public func setPendingValue(value: JscValue): Unit {
        if (vm.isShuttingDown()) {
            return
        }
        pendingValue = value
    }

    /// 获取 pendingValue
    /// 对应 Bun: JSMySQLQuery.getPendingValue
    public func getPendingValue(): ?JscValue {
        if (vm.isShuttingDown()) {
            return None
        }
        if (pendingValue.isUndefined()) {
            return None
        }
        return pendingValue
    }

    /// 设置 target
    private func setTarget(value: JscValue): Unit {
        if (vm.isShuttingDown()) {
            return
        }
        targetValue = value
    }

    /// 获取 target
    private func getTarget(): ?JscValue {
        if (vm.isShuttingDown()) {
            return None
        }
        if (targetValue.isUndefined()) {
            return None
        }
        return targetValue
    }

    /// 设置 columns
    private func setColumns(value: JscValue): Unit {
        if (vm.isShuttingDown()) {
            return
        }
        columnsValue = value
    }

    /// 获取 columns
    private func getColumns(): ?JscValue {
        if (vm.isShuttingDown()) {
            return None
        }
        if (columnsValue.isUndefined()) {
            return None
        }
        return columnsValue
    }

    /// 设置 binding
    private func setBinding(value: JscValue): Unit {
        if (vm.isShuttingDown()) {
            return
        }
        bindingValue = value
    }

    /// 获取 binding
    private func getBinding(): ?JscValue {
        if (vm.isShuttingDown()) {
            return None
        }
        if (bindingValue.isUndefined()) {
            return None
        }
        return bindingValue
    }

    /// 转换为 JS 值
    public func toJS(globalObject: JscJSGlobalObject): JscValue {
        return JscValue.undefined()
    }
}

/// MySQL 查询结果
/// 对应 Bun: MySQLQueryResult
public class MySQLQueryResult {
    public var resultCount: UInt64 = 0
    public var lastInsertId: UInt64 = 0
    public var affectedRows: UInt64 = 0
    public var isLastResult: Bool = true

    public init() {}

    public init(resultCount: UInt64, lastInsertId: UInt64,
                affectedRows: UInt64, isLastResult: Bool) {
        this.resultCount = resultCount
        this.lastInsertId = lastInsertId
        this.affectedRows = affectedRows
        this.isLastResult = isLastResult
    }
}

/// 查询结果模式
/// 对应 Bun: SQLQueryResultMode
public enum SQLQueryResultMode {
    | Objects
    | Values
    | Raw
}

/// 命令标签
/// 对应 Bun: CommandTag
public class CommandTag {
    public static func select(count: UInt64): CommandTag {
        return CommandTag()
    }

    public func toJSTag(globalObject: JscJSGlobalObject): JscValue {
        return JscValue.undefined()
    }

    public func toJSNumber(): JscValue {
        return JscValue.undefined()
    }
}
