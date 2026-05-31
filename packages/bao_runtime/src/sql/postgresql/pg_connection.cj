// PostgreSQL 连接类 - 核心连接管理与协议处理
// 严格翻译自: bun/src/sql_jsc/postgres/PostgresSQLConnection.zig
//   const PostgresSQLConnection = @This();
//   socket: Socket, status: Status, ...
package bao_runtime.sql.postgresql

import bao_runtime.sql.shared.*

/// PostgreSQL 连接配置
/// 对应 Bun PostgresSQLConnection 构造参数
public class PGConnectionConfig {
    public var hostname: String
    public var port: Int32
    public var user: String
    public var password: String
    public var database: String
    public var path: String          // Unix socket 路径
    public var options: String       // 连接选项
    public var sslMode: SSLMode
    public var idleTimeoutMs: UInt32
    public var connectionTimeoutMs: UInt32
    public var maxLifetimeMs: UInt32
    public var useUnnamedPreparedStatements: Bool

    public init() {
        hostname = "localhost"
        port = 5432
        user = ""
        password = ""
        database = ""
        path = ""
        options = ""
        sslMode = SSLMode.Disable
        idleTimeoutMs = 0
        connectionTimeoutMs = 0
        maxLifetimeMs = 0
        useUnnamedPreparedStatements = false
    }

    public init(
        hostname: String,
        port: Int32,
        user: String,
        password: String,
        database: String
    ) {
        this.hostname = hostname
        this.port = port
        this.user = user
        this.password = password
        this.database = database
        path = ""
        options = ""
        sslMode = SSLMode.Disable
        idleTimeoutMs = 0
        connectionTimeoutMs = 0
        maxLifetimeMs = 0
        useUnnamedPreparedStatements = false
    }

    /// 从连接字符串解析配置
    /// 格式: postgres://user:password@host:port/database?sslmode=disable
    public static func parse(connectionString: String): ?PGConnectionConfig {
        let config = PGConnectionConfig()
        // 简化实现 - 实际需要完整的 URL 解析
        let s = connectionString
        if (s.startsWith("postgres://") || s.startsWith("postgresql://")) {
            // 移除协议前缀
            var rest = ""
            if (s.startsWith("postgres://")) {
                rest = s.substring("postgres://".size)
            } else {
                rest = s.substring("postgresql://".size)
            }

            // 解析 user:password@host:port/database
            let atIdx = rest.indexOf('@')
            if (atIdx.isSome()) {
                let userInfo = rest.substring(0, atIdx.getOrThrow())
                let hostPart = rest.substring(atIdx.getOrThrow() + 1)

                // 解析 user:password
                let colonIdx = userInfo.indexOf(':')
                match (colonIdx) {
                    case Some(idx) => {
                        config.user = userInfo.substring(0, idx)
                        config.password = userInfo.substring(idx + 1)
                    }
                    case None => {
                        config.user = userInfo
                    }
                }

                // 解析 host:port/database
                let slashIdx = hostPart.indexOf('/')
                match (slashIdx) {
                    case Some(idx) => {
                        let hostPort = hostPart.substring(0, idx)
                        config.database = hostPart.substring(idx + 1)
                        let hostColon = hostPort.indexOf(':')
                        match (hostColon) {
                            case Some(hi) => {
                                config.hostname = hostPort.substring(0, hi)
                                config.port = Int32(hostPort.substring(hi + 1))
                            }
                            case None => {
                                config.hostname = hostPort
                            }
                        }
                    }
                    case None => {
                        config.hostname = hostPart
                    }
                }
            }
            return config
        }
        None
    }
}

/// PostgreSQL 预处理语句信息
/// 对应 Bun PostgresSQLStatement
public class PGStatement {
    /// 语句状态
    public enum StatementStatus {
        | Pending      // 等待解析
        | Parsing      // 正在解析
        | Prepared     // 已准备好
        | Failed       // 解析失败

        public func isRunning(): Bool {
            match (this) {
                case Parsing => true
                case _ => false
            }
        }
    }

    public var status: StatementStatus
    /// 字段描述列表
    public var fields: Array<FieldDescription>
    /// 参数类型 OID 列表
    public var parameters: Array<UInt32>
    /// 语句签名（名称和参数类型）
    public var signature: PGStatementSignature
    /// 错误响应（如果有）
    public var errorResponse: ?ErrorResponse
    /// 是否需要检查重复字段
    public var needsDuplicateCheck: Bool
    /// 是否有重复列
    public var hasDuplicateColumns: Bool
    /// 是否有命名列
    public var hasNamedColumns: Bool
    /// 是否有索引列
    public var hasIndexedColumns: Bool

    public init(signature: PGStatementSignature) {
        status = StatementStatus.Pending
        fields = Array<FieldDescription>()
        parameters = Array<UInt32>()
        this.signature = signature
        errorResponse = None
        needsDuplicateCheck = true
        hasDuplicateColumns = false
        hasNamedColumns = false
        hasIndexedColumns = false
    }

    /// 检查是否有重复字段并更新标志
    /// 对应 Bun PostgresSQLStatement.checkForDuplicateFields()
    public func checkForDuplicateFields(): Unit {
        if (!needsDuplicateCheck) {
            return
        }
        needsDuplicateCheck = false

        let seenNames = HashSet<String>()
        let seenIndices = ArrayList<UInt32>()
        hasDuplicateColumns = false
        hasNamedColumns = false
        hasIndexedColumns = false

        // 从后向前遍历
        var i = fields.size - 1
        while (i >= 0) {
            let field = fields[i]
            match (field.nameOrIndex) {
                case ColumnIdentifier.Name(name) => {
                    if (seenNames.contains(name)) {
                        field.nameOrIndex = ColumnIdentifier.Duplicate
                        hasDuplicateColumns = true
                    } else {
                        seenNames.add(name)
                    }
                    hasNamedColumns = true
                }
                case ColumnIdentifier.Index(idx) => {
                    if (seenIndices.contains(idx)) {
                        field.nameOrIndex = ColumnIdentifier.Duplicate
                        hasDuplicateColumns = true
                    } else {
                        seenIndices.append(idx)
                    }
                    hasIndexedColumns = true
                }
                case ColumnIdentifier.Duplicate => {
                    hasDuplicateColumns = true
                }
                case ColumnIdentifier.Empty => {}
            }
            i -= 1
        }
    }

    /// 释放资源
    public func deinit() {
        for (field in fields) {
            field.deinit()
        }
        fields = Array<FieldDescription>()
        parameters = Array<UInt32>()
        match (errorResponse) {
            case Some(err) => err.deinit()
            case None => {}
        }
    }
}

/// 预处理语句签名
/// 对应 Bun Signature
public class PGStatementSignature {
    /// 语句名称
    public var name: String
    /// 参数字段类型列表
    public var fields: Array<UInt32>
    /// 预处理语句名称
    public var preparedStatementName: String

    public init(name: String) {
        this.name = name
        fields = Array<UInt32>()
        preparedStatementName = ""
    }

    public init(name: String, fields: Array<UInt32>) {
        this.name = name
        this.fields = fields
        preparedStatementName = ""
    }

    /// 释放资源
    public func deinit() {
        fields = Array<UInt32>()
    }
}

/// PostgreSQL 查询请求状态
/// 对应 Bun PostgresSQLQuery 的 Status
public enum PGQueryStatus {
    | Pending           // 等待发送
    | Binding           // 正在绑定参数
    | Running           // 正在执行
    | PartialResponse   // 部分响应（多语句查询）
    | Success           // 成功
    | Fail              // 失败
}

/// PostgreSQL 查询标志
/// 对应 Bun PostgresSQLQuery 的 flags
public class PGQueryFlags {
    /// 是否为简单查询模式
    public var simple: Bool
    /// 是否使用流水线
    public var pipelined: Bool
    /// 是否使用二进制格式
    public var binary: Bool
    /// 是否使用 BigInt
    public var bigint: Bool
    /// 结果模式
    public var resultMode: SQLQueryResultMode

    public init() {
        simple = false
        pipelined = false
        binary = false
        bigint = false
        resultMode = SQLQueryResultMode.Objects
    }
}

/// PostgreSQL 查询请求
/// 对应 Bun PostgresSQLQuery
public class PGQuery {
    public var status: PGQueryStatus
    public var flags: PGQueryFlags
    public var query: String
    public var statement: ?PGStatement
    /// 绑定参数值
    public var bindings: Array<PGValue>
    /// 查询结果
    public var result: ?PGQueryResult

    public init(query: String) {
        status = PGQueryStatus.Pending
        flags = PGQueryFlags()
        this.query = query
        statement = None
        bindings = Array<PGValue>()
        result = None
    }

    public init(query: String, bindings: Array<PGValue>) {
        status = PGQueryStatus.Pending
        flags = PGQueryFlags()
        this.query = query
        statement = None
        this.bindings = bindings
        result = None
    }

    /// 释放资源
    public func deinit() {
        match (statement) {
            case Some(stmt) => stmt.deinit()
            case None => {}
        }
        match (result) {
            case Some(r) => r.deinit()
            case None => {}
        }
    }
}

/// PostgreSQL 值类型
/// 用于绑定参数
public enum PGValue {
    | Null
    | Bool(Bool)
    | Int32(Int32)
    | Int64(Int64)
    | Float32(Float32)
    | Float64(Float64)
    | Text(String)
    | Bytes(Array<UInt8>)

    /// 转为协议字节数组
    public func toBytes(): ?Array<UInt8> {
        match (this) {
            case Null => None
            case Bool(b) => {
                if (b) {
                    Some(Array<UInt8>([116]))  // 't'
                } else {
                    Some(Array<UInt8>([102]))  // 'f'
                }
            }
            case Int32(v) => Some(int32BigEndian(UInt32(v)))
            case Int64(v) => {
                let b0 = UInt8((v >> 56) & 0xFF)
                let b1 = UInt8((v >> 48) & 0xFF)
                let b2 = UInt8((v >> 40) & 0xFF)
                let b3 = UInt8((v >> 32) & 0xFF)
                let b4 = UInt8((v >> 24) & 0xFF)
                let b5 = UInt8((v >> 16) & 0xFF)
                let b6 = UInt8((v >> 8) & 0xFF)
                let b7 = UInt8(v & 0xFF)
                Some([b0, b1, b2, b3, b4, b5, b6, b7])
            }
            case Float32(v) => Some(int32BigEndian(UInt32(v)))
            case Float64(v) => {
                let bits = UInt64(v)
                Some(int32BigEndian(UInt32(bits >> 32)).toArray() +
                     int32BigEndian(UInt32(bits & 0xFFFFFFFF)).toArray())
            }
            case Text(s) => Some(s.toArray().map({ c => UInt8(c) }))
            case Bytes(b) => Some(b)
        }
    }
}

/// PostgreSQL 查询结果
/// 对应 Bun PostgresSQLQuery 的结果
public class PGQueryResult {
    /// 命令标签
    public var commandTag: CommandTag
    /// 结果行
    public var rows: Array<PGRow>
    /// 字段描述
    public var fields: Array<FieldDescription>

    public init() {
        commandTag = CommandTag.Other("")
        rows = Array<PGRow>()
        fields = Array<FieldDescription>()
    }

    /// 行数
    public func rowCount(): Int64 {
        rows.size
    }

    /// 释放资源
    public func deinit() {
        for (field in fields) {
            field.deinit()
        }
    }
}

/// PostgreSQL 行数据
public class PGRow {
    /// 列值，按字段顺序排列
    public var values: Array<?Array<UInt8>>
    /// 对应的字段描述
    public var fields: Array<FieldDescription>

    public init(count: Int64, fields: Array<FieldDescription>) {
        values = Array<?Array<UInt8>>(count)
        this.fields = fields
    }

    /// 获取指定列的字节值
    public func getBytes(index: Int64): ?Array<UInt8> {
        if (index >= 0 && index < values.size) {
            values[index]
        } else {
            None
        }
    }

    /// 获取指定列的字符串值
    public func getString(index: Int64): ?String {
        match (getBytes(index)) {
            case Some(bytes) => {
                Some(bytes.toArray().map({ b => Char.fromUInt8(b) }).toString())
            }
            case None => None
        }
    }

    /// 获取指定列的 Int32 值
    public func getInt32(index: Int64): ?Int32 {
        match (getBytes(index)) {
            case Some(bytes) => {
                if (bytes.size == 4) {
                    Some(Int32(readUInt32BE(bytes, 0)))
                } else {
                    None
                }
            }
            case None => None
        }
    }

    /// 获取指定列的 Int64 值
    public func getInt64(index: Int64): ?Int64 {
        match (getBytes(index)) {
            case Some(bytes) => {
                if (bytes.size == 8) {
                    Some(readInt64BE(bytes, 0))
                } else {
                    None
                }
            }
            case None => None
        }
    }

    /// 获取指定列的布尔值
    public func getBool(index: Int64): ?Bool {
        match (getBytes(index)) {
            case Some(bytes) => {
                if (bytes.size > 0) {
                    Some(bytes[0] != 0 && bytes[0] != 102)  // 非 'f' 和非 0
                } else {
                    None
                }
            }
            case None => None
        }
    }

    /// 获取列名
    public func getColumnName(index: Int64): ?String {
        if (index >= 0 && index < fields.size) {
            match (fields[index].nameOrIndex) {
                case ColumnIdentifier.Name(name) => name
                case _ => None
            }
        } else {
            None
        }
    }

    /// 列数
    public func columnCount(): Int64 {
        values.size
    }
}
