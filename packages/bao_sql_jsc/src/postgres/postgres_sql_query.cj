// 严格翻译自: src/sql_jsc/postgres/PostgresSQLQuery.zig
// Postgres SQL 查询

package bao_sql_jsc.postgres

import bao_core.*
import bao_jsc.*
import bao_collections.ArrayList
import bao_sql_jsc.Codegen as SqlCodegen
import bao_sql_jsc.SqlRareDataRegistry

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
    /// 已收集的行数据 (JS 值)
    /// 对应 Bun: PostgresSQLQuery.rows — 用于收集查询结果行
    public var rows: ArrayList<JscValue> = ArrayList<JscValue>()
    /// 关联的 globalObject (在调用时设置)
    /// 对应 Bun: 通过 thisValue.getGlobal() 获取
    public var globalObject: ?JscJSGlobalObject = None

    public init() {}

    public operator func == (other: PostgresSQLQuery): Bool {
        this.query == other.query && this.refCount == other.refCount
    }
    public operator func != (other: PostgresSQLQuery): Bool {
        !(this == other)
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

    /// 释放资源
    /// 对应 Bun: PostgresSQLQuery.deinit
    private func deinit_(): Unit {
        if (statement.isSome()) {
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
    /// 通过 SQL RareData 的 postgresql_context.onQueryRejectFn 将错误传递给 JS
    public func onWriteFail(err: AnyPostgresError, globalObject: JscJSGlobalObject,
                             queriesArray: JscValue): Unit {
        ref()
        status = PostgresQueryStatus.Fail

        // 获取 SQL RareData 中的 postgresql_context 回调
        let sqlRareData = SqlRareDataRegistry.getOrInit(globalObject)
        let rejectFn = sqlRareData.postgresqlContext.onQueryRejectFn
        match (rejectFn) {
            case Some(fn) =>
                let jsErr = postgresErrorToJS(globalObject, "", err)
                let targetValue = getTarget(globalObject, true)
                match (targetValue) {
                    case Some(target) =>
                        // 对应 Bun: eventLoop.runCallback(function, globalObject, thisValue, args)
                        fn.call(globalObject.globalThis, thisValue,
                            [target, jsErr, queriesArray])
                    case None => ()
                }
            case None => ()
        }

        deref()
    }

    /// JS 错误回调
    /// 对应 Bun: PostgresSQLQuery.onJSError
    /// 通过 SQL RareData 的 postgresql_context.onQueryRejectFn 将 JS 错误传递回 JS
    public func onJSError(err: JscValue, globalObject: JscJSGlobalObject): Unit {
        ref()
        status = PostgresQueryStatus.Fail

        // 获取 SQL RareData 中的 postgresql_context 回调
        let sqlRareData = SqlRareDataRegistry.getOrInit(globalObject)
        let rejectFn = sqlRareData.postgresqlContext.onQueryRejectFn
        match (rejectFn) {
            case Some(fn) =>
                let targetValue = getTarget(globalObject, true)
                match (targetValue) {
                    case Some(target) =>
                        fn.call(globalObject.globalThis, thisValue,
                            [target, err])
                    case None => ()
                }
            case None => ()
        }

        deref()
    }

    /// Resolve 查询结果
    /// 对应 Bun: PostgresSQLQuery.resolve / PostgresSQLQuery.onResult
    /// 通过 SQL RareData 的 postgresql_context.onQueryResolveFn 将结果传递给 JS
    public func resolve(queriesArray: JscValue, result: PostgresQueryResult): Unit {
        ref()

        let isDone = match (status) {
            case PostgresQueryStatus.Success => true
            case PostgresQueryStatus.Fail => true
            case _ => false
        }
        if (isDone) {
            deref()
            return
        }
        status = if (result.isLastResult) { PostgresQueryStatus.Success } else { PostgresQueryStatus.PartialResponse }

        // 获取 SQL RareData 中的 postgresql_context 回调
        let globalObject = this.globalObject
        match (globalObject) {
            case Some(globalObj) =>
                let sqlRareData = SqlRareDataRegistry.getOrInit(globalObj)
                let resolveFn = sqlRareData.postgresqlContext.onQueryResolveFn
                match (resolveFn) {
                    case Some(fn) =>
                        let jsTag = result.commandTag.toJSTag(globalObj)
                        let jsNumber = result.commandTag.toJSNumber()
                        let targetValue = getTarget(globalObj, result.isLastResult)
                        match (targetValue) {
                            case Some(target) =>
                                fn.call(globalObj.globalThis, thisValue,
                                    [target, JscValue.undefined(), jsTag, jsNumber,
                                     queriesArray, JscValue(result.isLastResult)])
                            case None => ()
                        }
                    case None => ()
                }
            case None => ()
        }

        deref()
    }

    /// Reject 查询
    /// 对应 Bun: PostgresSQLQuery.reject
    /// 通过 SQL RareData 的 postgresql_context.onQueryRejectFn 将错误传递给 JS
    public func reject(queriesArray: JscValue, err: AnyPostgresError): Unit {
        let isDone = match (status) {
            case PostgresQueryStatus.Fail => true
            case PostgresQueryStatus.Success => true
            case _ => false
        }
        if (isDone) {
            return
        }
        status = PostgresQueryStatus.Fail

        // 获取 SQL RareData 中的 postgresql_context 回调
        let globalObject = this.globalObject
        match (globalObject) {
            case Some(globalObj) =>
                let sqlRareData = SqlRareDataRegistry.getOrInit(globalObj)
                let rejectFn = sqlRareData.postgresqlContext.onQueryRejectFn
                match (rejectFn) {
                    case Some(fn) =>
                        let jsErr = postgresErrorToJS(globalObj, "", err)
                        let targetValue = getTarget(globalObj, true)
                        match (targetValue) {
                            case Some(target) =>
                                fn.call(globalObj.globalThis, thisValue,
                                    [target, jsErr, queriesArray])
                            case None => ()
                        }
                    case None => ()
                }
            case None => ()
        }
    }

    /// 使用 JS 值 reject
    /// 对应 Bun: PostgresSQLQuery.rejectWithJSValue (内联于 onJSError)
    public func rejectWithJSValue(queriesArray: JscValue, err: JscValue): Unit {
        let isDone = match (status) {
            case PostgresQueryStatus.Fail => true
            case PostgresQueryStatus.Success => true
            case _ => false
        }
        if (isDone) {
            return
        }
        status = PostgresQueryStatus.Fail

        // 获取 SQL RareData 中的 postgresql_context 回调
        let globalObject = this.globalObject
        match (globalObject) {
            case Some(globalObj) =>
                let sqlRareData = SqlRareDataRegistry.getOrInit(globalObj)
                let rejectFn = sqlRareData.postgresqlContext.onQueryRejectFn
                match (rejectFn) {
                    case Some(fn) =>
                        let targetValue = getTarget(globalObj, true)
                        match (targetValue) {
                            case Some(target) =>
                                fn.call(globalObj.globalThis, thisValue,
                                    [target, err, queriesArray])
                            case None => ()
                        }
                    case None => ()
                }
            case None => ()
        }
    }

    /// 标记为失败
    public func markAsFailed(): Unit {
        status = PostgresQueryStatus.Fail
    }

    /// 查询状态判断方法
    public func isCompleted(): Bool {
        let s = status
        return match (s) {
            case PostgresQueryStatus.Success => true
            case PostgresQueryStatus.Fail => true
            case _ => false
        }
    }

    public func isRunning(): Bool {
        let s = status
        return match (s) {
            case PostgresQueryStatus.Running => true
            case PostgresQueryStatus.Binding => true
            case PostgresQueryStatus.PartialResponse => true
            case _ => false
        }
    }

    public func isPending(): Bool {
        return match (status) {
            case PostgresQueryStatus.Pending => true
            case _ => false
        }
    }

    public func isBeingPrepared(): Bool {
        let isPending = match (status) {
            case PostgresQueryStatus.Pending => true
            case _ => false
        }
        return isPending && statement.isSome() &&
            match (statement.getOrThrow().status) {
                case PostgresStatementStatus.Parsing => true
                case _ => false
            }
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

        if (!queryVal.isString()) {
            return JscValue.undefined()
        }

        let query = PostgresSQLQuery()
        query.query = queryVal.toString()
        query.globalObject = globalObject
        query.ref()

        return query.toJS(globalObject)
    }

    /// 获取目标值 (用于回调中的 this 绑定)
    /// 对应 Bun: PostgresSQLQuery.getTarget
    /// 从 Codegen.targetGetCached 获取缓存的 target JS 值
    public func getTarget(globalObject: JscJSGlobalObject, cleanTarget: Bool): ?JscValue {
        let target = SqlCodegen.targetGetCached(thisValue)
        if (cleanTarget) {
            SqlCodegen.targetSetCached(thisValue, globalObject, JscValue.undefined())
        }
        return target
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

// ============================================================================
// postgresErrorToJS - 将 Postgres 错误转为 JS 值
// 对应 Bun: postgresErrorToJS(globalObject, message, err)
// ============================================================================

/// 将 Postgres 错误转换为 JS 错误对象
/// 对应 Bun: AnyPostgresError.postgresErrorToJS
/// 创建包含 name 和 message 属性的 JS Error 对象
public func postgresErrorToJS(globalObject: JscJSGlobalObject, message: String,
                               err: AnyPostgresError): JscValue {
    let errObj = JscValue.createEmptyObject(globalObject.globalThis)
    match (err) {
        case AnyPostgresError.JSError =>
            errObj.put(globalObject.globalThis, "name", JscValue("PostgresError"))
            errObj.put(globalObject.globalThis, "message", JscValue(if (message.size > 0) { message } else { "Postgres error" }))
        case AnyPostgresError.OutOfMemory =>
            errObj.put(globalObject.globalThis, "name", JscValue("OutOfMemory"))
            errObj.put(globalObject.globalThis, "message", JscValue("Out of memory"))
        case AnyPostgresError.JSTerminated =>
            errObj.put(globalObject.globalThis, "name", JscValue("Terminated"))
            errObj.put(globalObject.globalThis, "message", JscValue("JavaScript was terminated"))
        case _ =>
            errObj.put(globalObject.globalThis, "name", JscValue("PostgresError"))
            errObj.put(globalObject.globalThis, "message", JscValue(if (message.size > 0) { message } else { "Postgres error" }))
    }
    return errObj
}
