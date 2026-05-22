// 严格翻译自: src/sql_jsc/postgres/PostgresSQLQuery.zig
// Postgres SQL 查询

package bao_sql_jsc.postgres

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
    public func onWriteFail(err: AnyPostgresError, globalObject: JscJSGlobalObject,
                             queriesArray: JscValue): Unit {
        ref()
        status = PostgresQueryStatus.Fail
        // Stub: would invoke reject callback
        deref()
    }

    /// JS 错误回调
    /// 对应 Bun: PostgresSQLQuery.onJSError
    public func onJSError(err: JscValue, globalObject: JscJSGlobalObject): Unit {
        ref()
        status = PostgresQueryStatus.Fail
        deref()
    }

    /// Resolve 查询结果
    /// 对应 Bun: PostgresSQLQuery.resolve
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

        // Stub: would invoke resolve callback
        deref()
    }

    /// Reject 查询
    /// 对应 Bun: PostgresSQLQuery.reject
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

        // Stub: would invoke reject callback
    }

    /// 使用 JS 值 reject
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
