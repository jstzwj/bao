// 严格翻译自: src/sql_jsc/mysql/MySQLQuery.zig
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
    var bigint: Bool = false
    var simple: Bool = false
    var pipelined: Bool = false
    var resultMode: SQLQueryResultMode = SQLQueryResultMode.Objects

    public init() {}

    /// 初始化
    /// 对应 Bun: MySQLQuery.init
    public init(query: String, bigint: Bool, simple: Bool) {
        this.queryString = query
        this.status = QueryStatus.Pending
        this.bigint = bigint
        this.simple = simple
    }

    /// 运行查询
    /// 对应 Bun: MySQLQuery.runQuery
    public func runQuery(connection: JSMySQLConnection): Unit {
        if (simple) {
            runSimpleQuery(connection)
        } else {
            runPreparedQuery(connection)
        }
    }

    /// 运行简单查询
    /// 对应 Bun: MySQLQuery.runSimpleQuery
    private func runSimpleQuery(connection: JSMySQLConnection): Unit {
        if (status != QueryStatus.Pending || !connection.connection.canExecuteQuery()) {
            return
        }
        // 发送 COM_QUERY 包
        status = QueryStatus.Running
    }

    /// 运行预处理查询
    /// 对应 Bun: MySQLQuery.runPreparedQuery
    private func runPreparedQuery(connection: JSMySQLConnection): Unit {
        if (statement == None) {
            // 创建新语句
            let stmt = MySQLStatement()
            stmt.status = StatementStatus.Pending
            statement = stmt

            // 生成签名并准备
            let signature = Signature.generate(queryString)
            stmt.signature = signature
        }

        let stmt = statement.getOrThrow()
        match (stmt.status) {
            case Prepared =>
                if (connection.connection.canPipeline()) {
                    // 绑定并执行
                    status = QueryStatus.Running
                    pipelined = true
                }
            case Parsing => ()
            case Pending =>
                if (connection.connection.canPrepareQuery()) {
                    // 发送 COM_STMT_PREPARE
                    stmt.status = StatementStatus.Parsing
                }
            case Failed =>
                // 语句失败
            case _ => ()
        }
    }

    /// 设置结果模式
    /// 对应 Bun: MySQLQuery.setResultMode
    public func setResultMode(mode: SQLQueryResultMode): Unit {
        resultMode = mode
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

    /// 标记为已准备
    public func markAsPrepared(): Unit {
        if (status == QueryStatus.Pending) {
            if (statement != None) {
                let stmt = statement.getOrThrow()
                if (stmt.status == StatementStatus.Parsing &&
                    stmt.paramsReceived == stmt.params.size &&
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

/// 语句状态
/// 对应 Bun: MySQLStatement.Status
public enum StatementStatus {
    | Pending
    | Parsing
    | Prepared
    | Failed
}

/// 查询签名
/// 对应 Bun: Signature (mysql/protocol/Signature.zig)
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
public class SignatureParam {
    public var fieldType: UInt8 = 0
    public var unsigned: Bool = false

    public init() {}
}
