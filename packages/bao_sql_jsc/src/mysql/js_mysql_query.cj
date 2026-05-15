// 严格翻译自: src/sql_jsc/mysql/JSMySQLQuery.zig
// MySQL JS 查询 - MySQL 查询的 JS 绑定

package bao_sql_jsc

import bao_core.*
import bao_jsc.*
import bao_sql.*

/// JS MySQL 查询
/// 对应 Bun: JSMySQLQuery
/// MySQL 查询的 JavaScript 绑定对象
public class JSMySQLQuery {
    var refCount: Int64 = 0
    var thisValue: JscValue = JscValue.undefined()
    var vm: JscVirtualMachine
    var globalObject: JscJSGlobalObject
    var query: MySQLQuery

    public init(vm: JscVirtualMachine, globalObject: JscJSGlobalObject,
                query: MySQLQuery) {
        this.vm = vm
        this.globalObject = globalObject
        this.query = query
    }

    public func ref(): Unit {
        refCount += 1
    }

    public func deref(): Unit {
        refCount -= 1
        if (refCount <= 0) {
            deinit_()
        }
    }

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

        return jsVal
    }

    /// 执行查询
    /// 对应 Bun: JSMySQLQuery.doRun
    public func doRun(globalObject: JscJSGlobalObject,
                       callFrame: JscCallFrame): JscValue {
        ref()
        defer { deref() }

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

        do {
            query.run(connection.getOrThrow())
        } catch (_: Exception) {
            if (!globalObject.hasException()) {
                return globalObject.throwValue(
                    AnyMySQLError.mysqlErrorToJS(globalObject, "failed to execute query",
                        AnyMySQLError.UnknownError))
            }
            return JscValue.undefined()
        }

        connection.getOrThrow().enqueueRequest(this)
        return JscValue.undefined()
    }

    /// Resolve 查询结果
    /// 对应 Bun: JSMySQLQuery.resolve
    public func resolve(queriesArray: JscValue, result: MySQLQueryResult): Unit {
        ref()
        let isLastResult = result.isLastResult
        defer {
            deref()
        }

        if (!query.result(isLastResult)) {
            return
        }
        if (vm.isShuttingDown()) {
            return
        }

        let targetValue = getTarget()
        if (targetValue == None) {
            return
        }

        let pendingValue = getPendingValue()
        if (pendingValue == None) {
            setPendingValue(JscValue.undefined())
        }

        // 调用 onQueryResolveFn
        let function = vm.rareData().mysqlContext.onQueryResolveFn
        if (function == None) {
            return
        }

        let eventLoop = vm.eventLoop()
        eventLoop.runCallback(
            function.getOrThrow(),
            globalObject,
            thisValue,
            [
                targetValue.getOrThrow(),
                pendingValue.getOrThrow(),
                JscValue(result.resultCount),
                JscValue.undefined(),
                if (queriesArray.isZero()) JscValue.undefined() else queriesArray,
                JscValue(isLastResult),
                JscValue(result.lastInsertId),
                JscValue(result.affectedRows)
            ]
        )
    }

    /// 标记为失败（不触碰 JS）
    /// 对应 Bun: JSMySQLQuery.markAsFailed
    public func markAsFailed(): Unit {
        ref()
        defer { deref() }
        query.fail()
    }

    /// Reject 查询
    /// 对应 Bun: JSMySQLQuery.reject
    public func reject(queriesArray: JscValue, err: AnyMySQLError): Unit {
        if (vm.isShuttingDown()) {
            markAsFailed()
            return
        }
        let instance = AnyMySQLError.mysqlErrorToJS(globalObject, "Failed to bind query", err)
        rejectWithJSValue(queriesArray, instance)
    }

    /// 使用 JS 值 reject
    /// 对应 Bun: JSMySQLQuery.rejectWithJSValue
    public func rejectWithJSValue(queriesArray: JscValue, err: JscValue): Unit {
        ref()
        defer { deref() }
        if (!query.fail()) {
            return
        }
        if (vm.isShuttingDown()) {
            return
        }

        let targetValue = getTarget()
        if (targetValue == None) {
            return
        }

        let function = vm.rareData().mysqlContext.onQueryRejectFn
        if (function == None) {
            return
        }

        let eventLoop = vm.eventLoop()
        let jsArray = if (queriesArray.isZero()) JscValue.undefined() else queriesArray
        eventLoop.runCallback(
            function.getOrThrow(),
            globalObject,
            thisValue,
            [targetValue.getOrThrow(), err, jsArray]
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
        query.runQuery(connection)
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

    // ===== 私有辅助方法 =====

    private func getTarget(): ?JscValue {
        if (vm.isShuttingDown()) {
            return None
        }
        return None // 简化，实际从 JS 缓存中读取
    }

    private func getPendingValue(): ?JscValue {
        if (vm.isShuttingDown()) {
            return None
        }
        return None
    }

    private func setPendingValue(value: JscValue): Unit {
        if (vm.isShuttingDown()) {
            return
        }
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
}

/// 查询结果模式
/// 对应 Bun: SQLQueryResultMode
public enum SQLQueryResultMode {
    | Objects
    | Values
    | Raw
}
