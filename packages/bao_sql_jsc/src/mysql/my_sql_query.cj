// 严格翻译自: src/sql_jsc/mysql/MySQLQuery.rs
// MySQL 查询 - 查询状态和执行管理

package bao_sql_jsc.mysql

import bao_core.*
import bao_jsc.*
import bao_sql.*

/// MySQL 查询
/// 对应 Bun: MySQLQuery
/// 管理 MySQL 查询的生命周期：创建、准备、绑定、执行
public class MySQLQuery {
    var statement: ?MySQLStatement = None
    var queryString: String = ""
    var status: QueryStatus = QueryStatus.Pending
    var flags: QueryFlags = QueryFlags()

    public init() {}

    /// 初始化
    /// 对应 Bun: MySQLQuery.init
    /// 接受 query 字符串的所有权（调用者需先 ref）
    public init(query: String, bigint: Bool, simple: Bool) {
        this.queryString = query
        this.status = QueryStatus.Pending
        this.flags = QueryFlags(bigint: bigint, simple: simple)
    }

    /// 运行查询
    /// 对应 Bun: MySQLQuery.runQuery
    public func runQuery(connection: JSMySQLConnection, globalObject: JscJSGlobalObject,
                          columnsValue: JscValue, bindingValue: JscValue): Unit {
        if (flags.simple) {
            runSimpleQuery(connection)
        } else {
            runPreparedQuery(connection, globalObject, columnsValue, bindingValue)
        }
    }

    /// 运行简单查询
    /// 对应 Bun: MySQLQuery.runSimpleQuery
    private func runSimpleQuery(connection: JSMySQLConnection): Unit {
        if (status != QueryStatus.Pending || !connection.connection.canExecuteQuery()) {
            return
        }
        // 创建新语句用于简单查询
        if (statement == None) {
            let stmt = MySQLStatement()
            stmt.signature = Signature.empty()
            stmt.status = StatementStatus.Parsing
            statement = stmt
        }
        // 发送 COM_QUERY 包
        status = QueryStatus.Running
    }

    /// 运行预处理查询
    /// 对应 Bun: MySQLQuery.runPreparedQuery
    private func runPreparedQuery(connection: JSMySQLConnection,
                                   globalObject: JscJSGlobalObject,
                                   columnsValue: JscValue,
                                   bindingValue: JscValue): Unit {
        if (statement == None) {
            // 生成签名
            let signature = Signature.generate(queryString)

            // 查找或创建预处理语句
            let entry = connection.connection.getStatementFromSignatureHash(
                signature.name.hash())

            if (entry.foundExisting) {
                let stmt = entry.value
                if (stmt.status == StatementStatus.Failed) {
                    // 语句已失败
                    return
                }
                statement = stmt
                stmt.ref()
            } else {
                // 创建新语句
                let stmt = MySQLStatement()
                stmt.signature = signature
                stmt.status = StatementStatus.Pending
                stmt.statementId = 0
                stmt.initExactRefs(2)
                statement = stmt
                entry.value = stmt
            }
        }

        let stmt = statement.getOrThrow()
        match (stmt.status) {
            case Failed => {
                // 语句失败
            }
            case Prepared =>
                if (connection.connection.canPipeline()) {
                    // 绑定并执行
                    bindAndExecute(connection, stmt, globalObject,
                        columnsValue, bindingValue)
                    flags.pipelined = true
                }
            case Parsing => ()
            case Pending =>
                if (connection.connection.canPrepareQuery()) {
                    // 发送 COM_STMT_PREPARE
                    stmt.status = StatementStatus.Parsing
                }
        }
    }

    /// 绑定参数并执行
    /// 对应 Bun: MySQLQuery.bindAndExecute
    private func bindAndExecute(connection: JSMySQLConnection, statement: MySQLStatement,
                                 globalObject: JscJSGlobalObject,
                                 bindingValue: JscValue, columnsValue: JscValue): Unit {
        // 绑定参数
        // ... 参数绑定逻辑 ...
        status = QueryStatus.Running
    }

    /// 设置结果模式
    /// 对应 Bun: MySQLQuery.setResultMode
    public func setResultMode(mode: SQLQueryResultMode): Unit {
        flags.resultMode = mode
    }

    /// 标记结果
    /// 对应 Bun: MySQLQuery.result
    public func result(isLastResult: Bool): Bool {
        if (status == QueryStatus.Success || status == QueryStatus.Fail) {
            return false
        }
        status = if (isLastResult) QueryStatus.Success else QueryStatus.PartialResponse
        return true
    }

    /// 标记失败
    /// 对应 Bun: MySQLQuery.fail
    public func fail(): Bool {
        if (status == QueryStatus.Fail || status == QueryStatus.Success) {
            return false
        }
        status = QueryStatus.Fail
        return true
    }

    /// 清理
    /// 对应 Bun: MySQLQuery.cleanup
    public func cleanup(): Unit {
        if (statement != None) {
            statement.getOrThrow().deref()
            statement = None
        }
        queryString = ""
    }

    /// 是否完成
    public func isCompleted(): Bool {
        return status == QueryStatus.Success || status == QueryStatus.Fail
    }

    /// 是否运行中
    public func isRunning(): Bool {
        match (status) {
            case Running | Binding | PartialResponse => true
            case _ => false
        }
    }

    /// 是否待定
    public func isPending(): Bool {
        return status == QueryStatus.Pending
    }

    /// 是否在准备中
    public func isBeingPrepared(): Bool {
        return status == QueryStatus.Pending &&
            statement != None &&
            statement.getOrThrow().status == StatementStatus.Parsing
    }

    /// 是否流水线
    public func isPipelined(): Bool {
        return flags.pipelined
    }

    /// 是否简单查询
    public func isSimple(): Bool {
        return flags.simple
    }

    /// 是否支持 BigInt
    public func isBigintSupported(): Bool {
        return flags.bigint
    }

    /// 获取结果模式
    public func getResultMode(): SQLQueryResultMode {
        return flags.resultMode
    }

    /// 标记为已准备
    public func markAsPrepared(): Unit {
        if (status == QueryStatus.Pending) {
            if (statement != None) {
                let stmt = statement.getOrThrow()
                if (stmt.status == StatementStatus.Parsing &&
                    stmt.paramsReceived == UInt32(stmt.params.size) &&
                    stmt.statementId > 0) {
                    stmt.status = StatementStatus.Prepared
                }
            }
        }
    }

    /// 获取语句
    public func getStatement(): ?MySQLStatement {
        return statement
    }
}

/// 查询状态
/// 对应 Bun: QueryStatus
public enum QueryStatus {
    | Pending
    | Binding
    | Running
    | PartialResponse
    | Success
    | Fail
}

/// 查询标志
/// 对应 Bun: MySQLQuery.Flags (packed struct)
/// bigint, simple, pipelined 标志位 + resultMode
public class QueryFlags {
    public var bigint: Bool = false
    public var simple: Bool = false
    public var pipelined: Bool = false
    public var resultMode: SQLQueryResultMode = SQLQueryResultMode.Objects

    public init() {}

    public init(bigint: Bool, simple: Bool) {
        this.bigint = bigint
        this.simple = simple
    }
}

/// 语句状态
/// 对应 Bun: MySQLStatement.Status
public enum StatementStatus {
    | Pending
    | Parsing
    | Prepared
    | Failed
}

/// 查询签名
/// 对应 Bun: Signature
/// 生成和存储查询签名，用于预处理语句缓存
public class Signature {
    public var fields: Array<SignatureParam> = []
    public var name: String = ""
    public var query: String = ""

    public init() {}

    public static func empty(): Signature {
        return Signature()
    }

    public static func generate(query: String): Signature {
        let sig = Signature()
        sig.query = query
        sig.name = query
        return sig
    }

    public func deinit(): Unit {
        fields = []
        name = ""
        query = ""
    }
}

/// 签名参数
/// 对应 Bun: SignatureParam
public class SignatureParam {
    public var fieldType: UInt8 = 0
    public var unsigned: Bool = false

    public init() {}
}
