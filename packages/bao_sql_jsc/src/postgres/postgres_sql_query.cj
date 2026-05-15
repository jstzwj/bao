// 严格翻译自: src/sql_jsc/postgres/PostgresSQLQuery.zig
// Postgres SQL 查询

package bao_sql_jsc

import bao_core.*
import bao_jsc.*

/// Postgres SQL 查询
/// 对应 Bun: PostgresSQLQuery
/// 管理 PostgreSQL 查询的生命周期和状态
public class PostgresSQLQuery {
    public var statement: ?PostgresSQLStatement = None
    public var query: String = ""
    public var cursorName: String = ""
    public var thisValue: JscValue = JscValue.undefined()
    public var status: PostgresQueryStatus = PostgresQueryStatus.Pending
    var refCount: Int64 = 1
    public var flags: PostgresQueryFlags = PostgresQueryFlags()

    public init() {}

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

    /// 释放资源
    /// 对应 Bun: PostgresSQLQuery.deinit
    private func deinit_(): Unit {
        if (statement != None) {
            statement.getOrThrow().deref()
        }
    }

    /// GC 回调
    /// 对应 Bun: PostgresSQLQuery.finalize
    public func finalize(): Unit {
        thisValue = JscValue.undefined()
        deref()
    }

    /// 写入失败回调
    /// 对应 Bun: PostgresSQLQuery.onWriteFail
    public func onWriteFail(err: AnyPostgresError, globalObject: JscJSGlobalObject,
                             queriesArray: JscValue): Unit {
        ref()
        defer { deref() }
        status = PostgresQueryStatus.Fail

        let vm = JscVirtualMachine.get()
        let function = vm.rareData().postgresqlContext.onQueryRejectFn
        if (function == None) {
            return
        }

        let jsErr = postgresErrorToJS(globalObject, None, err)
        let eventLoop = vm.eventLoop()
        eventLoop.runCallback(
            function.getOrThrow(),
            globalObject,
            thisValue,
            [jsErr, queriesArray]
        )
    }

    /// JS 错误回调
    /// 对应 Bun: PostgresSQLQuery.onJSError
    public func onJSError(err: JscValue, globalObject: JscJSGlobalObject): Unit {
        ref()
        defer { deref() }
        status = PostgresQueryStatus.Fail
    }

    /// Resolve 查询结果
    /// 对应 Bun: PostgresSQLQuery.resolve
    public func resolve(queriesArray: JscValue, result: PostgresQueryResult): Unit {
        ref()
        defer { deref() }

        if (status == PostgresQueryStatus.Success || status == PostgresQueryStatus.Fail) {
            return
        }
        status = if (result.isLastResult) PostgresQueryStatus.Success else PostgresQueryStatus.PartialResponse

        let vm = JscVirtualMachine.get()
        if (vm.isShuttingDown()) {
            return
        }

        let function = vm.rareData().postgresqlContext.onQueryResolveFn
        if (function == None) {
            return
        }

        let tag = result.commandTag
        let jsTag = tag.toJSTag(globalObject)

        let eventLoop = vm.eventLoop()
        eventLoop.runCallback(
            function.getOrThrow(),
            globalObject,
            thisValue,
            [
                jsTag,
                tag.toJSNumber(),
                if (queriesArray.isZero()) JscValue.undefined() else queriesArray,
                JscValue(result.isLastResult)
            ]
        )
    }

    /// Reject 查询
    /// 对应 Bun: PostgresSQLQuery.reject
    public func reject(queriesArray: JscValue, err: AnyPostgresError): Unit {
        if (status == PostgresQueryStatus.Fail || status == PostgresQueryStatus.Success) {
            return
        }
        status = PostgresQueryStatus.Fail

        let vm = JscVirtualMachine.get()
        if (vm.isShuttingDown()) {
            return
        }

        let function = vm.rareData().postgresqlContext.onQueryRejectFn
        if (function == None) {
            return
        }

        let jsErr = postgresErrorToJS(globalObject, None, err)
        let eventLoop = vm.eventLoop()
        eventLoop.runCallback(
            function.getOrThrow(),
            globalObject,
            thisValue,
            [jsErr, queriesArray]
        )
    }

    /// 使用 JS 值 reject
    public func rejectWithJSValue(queriesArray: JscValue, err: JscValue): Unit {
        if (status == PostgresQueryStatus.Fail || status == PostgresQueryStatus.Success) {
            return
        }
        status = PostgresQueryStatus.Fail
    }

    /// 标记为失败
    public func markAsFailed(): Unit {
        status = PostgresQueryStatus.Fail
    }

    /// 查询状态判断方法
    public func isCompleted(): Bool {
        return status == PostgresQueryStatus.Success || status == PostgresQueryStatus.Fail
    }

    public func isRunning(): Bool {
        return status == PostgresQueryStatus.Running ||
            status == PostgresQueryStatus.Binding ||
            status == PostgresQueryStatus.PartialResponse
    }

    public func isPending(): Bool {
        return status == PostgresQueryStatus.Pending
    }

    public func isBeingPrepared(): Bool {
        return status == PostgresQueryStatus.Pending &&
            statement != None &&
            statement.getOrThrow().status == PostgresStatementStatus.Parsing
    }

    public func isPipelined(): Bool {
        return flags.pipelined
    }

    public func isSimple(): Bool {
        return flags.simple
    }

    public func isBigintSupported(): Bool {
        return flags.bigint
    }

    /// 调用创建查询
    /// 对应 Bun: PostgresSQLQuery.call
    public static func call_(globalObject: JscJSGlobalObject,
                              callFrame: JscCallFrame): JscValue {
        let arguments = callFrame.arguments()
        let queryVal = arguments[0]
        let values = arguments[1]

        if (!queryVal.isString()) {
            globalObject.throwError("query must be a string")
            return JscValue.undefined()
        }

        let pendingValue: JscValue = if (arguments.size > 2) arguments[2] else JscValue.undefined()
        let columns: JscValue = if (arguments.size > 3) arguments[3] else JscValue.undefined()
        let jsBigint: JscValue = if (arguments.size > 4) arguments[4] else JscValue.false_()
        let jsSimple: JscValue = if (arguments.size > 5) arguments[5] else JscValue.false_()

        let vm = globalObject.bunVM()
        let query = PostgresSQLQuery()
        query.query = queryVal.toBunString(globalObject)
        query.flags.bigint = jsBigint.isBoolean() && jsBigint.asBoolean()
        query.flags.simple = jsSimple.isBoolean() && jsSimple.asBoolean()
        query.ref()

        return query.toJS(globalObject)
    }

    /// 转换为 JS 值
    public func toJS(globalObject: JscJSGlobalObject): JscValue {
        return JscValue.undefined()
    }
}

/// Postgres 查询状态
/// 对应 Bun: PostgresSQLQuery.Status
public enum PostgresQueryStatus {
    | Pending
    | Binding
    | Running
    | PartialResponse
    | Success
    | Fail
}

/// Postgres 查询标志
/// 对应 Bun: PostgresSQLQuery.flags
public class PostgresQueryFlags {
    public var isDone: Bool = false
    public var binary: Bool = false
    public var bigint: Bool = false
    public var simple: Bool = false
    public var pipelined: Bool = false
    public var resultMode: PostgresSQLQueryResultMode = PostgresSQLQueryResultMode.Objects

    public init() {}
}

/// Postgres 查询结果模式
public enum PostgresSQLQueryResultMode {
    | Objects
    | Values
    | Raw
}

/// Postgres 查询结果
public class PostgresQueryResult {
    public var commandTag: PostgresCommandTag = PostgresCommandTag()
    public var isLastResult: Bool = true

    public init() {}
}

/// Postgres 命令标签
/// 对应 Bun: CommandTag
public class PostgresCommandTag {
    public var tagType: Int64 = 0
    public var count: Int64 = 0
    public var otherTag: String = ""

    public init() {}

    /// 转换为 JS 标签
    /// 对应 Bun: CommandTag.toJSTag
    public func toJSTag(globalObject: JscJSGlobalObject): JscValue {
        return JscValue(tagType)
    }

    /// 转换为 JS 数字
    /// 对应 Bun: CommandTag.toJSNumber
    public func toJSNumber(): JscValue {
        return JscValue(count)
    }
}
