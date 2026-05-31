// PostgreSQL 连接 JSC 绑定
// 严格翻译自: bun/src/sql_jsc/postgres/PostgresSQLConnection.zig
//   const PostgresSQLConnection = @This();
//   socket: Socket, status: Status, ...
package bao_runtime.sql.postgresql

import bao_runtime.sql.shared.*

/// PostgreSQL 连接 JSC 绑定
/// 对应 Bun PostgresSQLConnection
/// 连接 JavaScript 世界与底层 PostgreSQL 协议实现
public class PostgresSQLConnectionJSC {
    /// 连接配置
    public var config: PGConnectionConfig
    /// 连接状态
    public var status: PGConnectionStatus
    /// JS 全局对象引用
    public var globalObjectRef: Int64
    /// VM 引用
    public var vmRef: Int64
    /// JS 值引用 (用于 GC root)
    public var jsValueRef: Int64

    // === 回调引用 ===
    /// on("connect") 回调
    public var onConnectCallbackRef: Int64
    /// on("close") 回调引用
    public var onCloseCallbackRef: Int64

    // === 请求队列 ===
    /// 待处理请求队列
    public var requests: Array<PostgresSQLQueryJSC>
    /// 流水线请求数
    public var pipelinedRequests: UInt32
    /// 非流水线请求数
    public var nonPipelinedRequests: UInt32

    // === 预处理语句 ===
    /// 预处理语句缓存 (name hash -> statement)
    public var statements: HashMap<UInt64, PostgresSQLStatementJSC>
    /// 递增的预处理语句 ID
    public var preparedStatementId: UInt64

    // === 认证 ===
    /// 认证状态
    public var authenticationState: AuthenticationState
    /// SASL 认证
    public var saslAuth: SASLAuth

    // === TLS ===
    /// TLS 配置
    public var tlsConfig: Int64
    /// TLS 状态
    public var tlsStatus: TLSStatus
    /// SSL 模式
    public var sslMode: SSLMode

    // === 缓冲区 ===
    /// 写缓冲区
    public var writeBuffer: Array<UInt8>
    /// 读缓冲区
    public var readBuffer: Array<UInt8>
    /// 最后消息起始偏移
    public var lastMessageStart: UInt32

    // === 计时器 ===
    /// 空闲超时 (ms)
    public var idleTimeoutMs: UInt32
    /// 连接超时 (ms)
    public var connectionTimeoutMs: UInt32
    /// 最大生命周期 (ms)
    public var maxLifetimeMs: UInt32

    // === 标志 ===
    /// 连接标志
    public var flags: ConnectionFlags

    public init(config: PGConnectionConfig) {
        this.config = config
        status = PGConnectionStatus.Connecting
        globalObjectRef = 0
        vmRef = 0
        jsValueRef = 0
        onConnectCallbackRef = 0
        onCloseCallbackRef = 0
        requests = Array<PostgresSQLQueryJSC>()
        pipelinedRequests = 0
        nonPipelinedRequests = 0
        statements = HashMap<UInt64, PostgresSQLStatementJSC>()
        preparedStatementId = 0
        authenticationState = AuthenticationState.Pending
        saslAuth = SASLAuth()
        tlsConfig = 0
        tlsStatus = TLSStatus.None
        sslMode = config.sslMode
        writeBuffer = Array<UInt8>()
        readBuffer = Array<UInt8>()
        lastMessageStart = 0
        idleTimeoutMs = config.idleTimeoutMs
        connectionTimeoutMs = config.connectionTimeoutMs
        maxLifetimeMs = config.maxLifetimeMs
        flags = ConnectionFlags()
    }

    // ========================================================================
    // 构造函数 (JS 端调用入口)
    // ========================================================================

    /// 创建连接实例
    /// 对应 Bun PostgresSQLConnection.call()
    /// 从 JS 参数构建连接并开始连接流程
    public static func createInstance(
        hostname: String,
        port: Int32,
        username: String,
        password: String,
        database: String,
        sslModeInt: Int32,
        onConnect: Int64,
        onClose: Int64,
        idleTimeout: Int32,
        connectionTimeout: Int32,
        maxLifetime: Int32,
        useUnnamedPreparedStatements: Bool
    ): PostgresSQLConnectionJSC {
        let config = PGConnectionConfig()
        config.hostname = hostname
        config.port = port
        config.user = username
        config.password = password
        config.database = database
        config.sslMode = SSLMode.fromInt(sslModeInt)
        config.idleTimeoutMs = UInt32(idleTimeout)
        config.connectionTimeoutMs = UInt32(connectionTimeout)
        config.maxLifetimeMs = UInt32(maxLifetime)
        config.useUnnamedPreparedStatements = useUnnamedPreparedStatements

        let conn = PostgresSQLConnectionJSC(config)
        conn.onConnectCallbackRef = onConnect
        conn.onCloseCallbackRef = onClose
        return conn
    }

    // ========================================================================
    // 查询执行
    // ========================================================================

    /// 执行查询
    /// 对应 Bun PostgresSQLQuery.doRun()
    public func runQuery(query: PostgresSQLQueryJSC): Bool {
        if (query.flags.simple) {
            return runSimpleQuery(query)
        } else {
            return runPreparedQuery(query)
        }
    }

    /// 执行简单查询
    private func runSimpleQuery(query: PostgresSQLQueryJSC): Bool {
        let stmt = PostgresSQLStatementJSC(PGSignature.empty())
        stmt.status = PostgresSQLStatementJSC.StatementStatus.Parsing
        query.statement = stmt

        let canExecute = !hasQueryRunning()
        if (canExecute) {
            let writer = ProtocolWriter()
            PostgresRequestDispatcher.executeQuery(query.queryString, writer)
            flags.isReadyForQuery = false
            nonPipelinedRequests += 1
            query.status = PGQueryStatus.Running
            // TODO: 将 writer.getBuffer() 写入 socket
        } else {
            query.status = PGQueryStatus.Pending
        }
        requests.append(query)
        return true
    }

    /// 执行预处理查询
    private func runPreparedQuery(query: PostgresSQLQueryJSC): Bool {
        let queryStr = query.queryString
        let bindings = query.bindings

        // 生成签名
        let bindingTags = Array<PGTag>()
        for (b in bindings) {
            bindingTags.append(inferTag(b))
        }
        let signature = PGSignature.generate(
            queryStr, bindingTags,
            preparedStatementId,
            flags.useUnnamedPreparedStatements
        )

        let hasParams = signature.fields.size > 0
        let signatureHash = signature.hash()
        var didWrite = false

        // 检查是否已有缓存的预处理语句
        let existing = statements.get(signatureHash)
        match (existing) {
            case Some(stmt) => {
                query.statement = stmt
                match (stmt.status) {
                    case PostgresSQLStatementJSC.StatementStatus.Failed => {
                        return false
                    }
                    case PostgresSQLStatementJSC.StatementStatus.Prepared => {
                        if (!hasQueryRunning() || canPipeline()) {
                            let writer = ProtocolWriter()
                            PostgresRequestDispatcher.bindAndExecute(
                                stmt.toRef(), bindings, Array<PGValue>(), writer
                            )
                            flags.isReadyForQuery = false
                            query.status = PGQueryStatus.Binding
                            query.flags.pipelined = true
                            pipelinedRequests += 1
                            didWrite = true
                        }
                    }
                    case _ => {}
                }
            }
            case None => {
                // 创建新的预处理语句
                let stmt = PostgresSQLStatementJSC(signature)
                query.statement = stmt

                let canExecute = !hasQueryRunning()
                if (canExecute && !hasParams) {
                    let writer = ProtocolWriter()
                    PostgresRequestDispatcher.prepareAndQueryWithSignature(
                        queryStr, bindings, signature, writer
                    )
                    flags.isReadyForQuery = false
                    query.status = PGQueryStatus.Binding
                    didWrite = true
                    flags.waitingToPrepare = true
                }
                if (!flags.useUnnamedPreparedStatements) {
                    statements.put(signatureHash, stmt)
                    preparedStatementId += 1
                }
            }
        }

        requests.append(query)
        return true
    }

    // ========================================================================
    // 连接管理
    // ========================================================================

    /// 关闭连接
    /// 对应 Bun PostgresSQLConnection.doClose()
    public func close() {
        disconnect()
        writeBuffer = Array<UInt8>()
    }

    /// 断开连接
    public func disconnect() {
        if (status == PGConnectionStatus.Connected) {
            status = PGConnectionStatus.Disconnected
            cleanUpRequests(None)
        }
    }

    /// 是否有正在运行的查询
    public func hasQueryRunning(): Bool {
        !flags.isReadyForQuery || requests.size > 0
    }

    /// 是否可以流水线
    public func canPipeline(): Bool {
        nonPipelinedRequests == 0 &&
        !flags.useUnnamedPreparedStatements &&
        !flags.waitingToPrepare &&
        !flags.hasBackpressure &&
        writeBuffer.size < PostgresRequestDispatcher.MAX_PARAMETERS
    }

    /// 引用计数增加 (保持进程活跃)
    public func doRef() {
        // TODO: poll_ref.ref(vm)
    }

    /// 引用计数减少 (允许进程退出)
    public func doUnref() {
        // TODO: poll_ref.unref(vm)
    }

    /// 手动刷新
    public func doFlush() {
        // TODO: registerAutoFlusher()
    }

    // ========================================================================
    // 状态查询
    // ========================================================================

    /// 是否已连接
    public func getConnected(): Bool {
        status == PGConnectionStatus.Connected
    }

    /// 获取查询数组
    public func getQueries(): Array<PostgresSQLQueryJSC> {
        requests
    }

    // ========================================================================
    // 回调管理
    // ========================================================================

    /// 消费 onConnect 回调 (只触发一次)
    public func consumeOnConnectCallback(): ?Int64 {
        if (onConnectCallbackRef != 0) {
            let cb = onConnectCallbackRef
            onConnectCallbackRef = 0
            return cb
        }
        None
    }

    /// 消费 onClose 回调
    public func consumeOnCloseCallback(): ?Int64 {
        if (onCloseCallbackRef != 0) {
            let cb = onCloseCallbackRef
            onCloseCallbackRef = 0
            return cb
        }
        None
    }

    // ========================================================================
    // 内部方法
    // ========================================================================

    /// 清理请求队列
    private func cleanUpRequests(jsReason: ?Int64) {
        for (query in requests) {
            match (query.status) {
                case PGQueryStatus.Pending => {
                    // 标记语句为失败
                    match (query.statement) {
                        case Some(stmt) => {
                            stmt.status = PostgresSQLStatementJSC.StatementStatus.Failed
                        }
                        case None => {}
                    }
                }
                case PGQueryStatus.Binding | PGQueryStatus.Running | PGQueryStatus.PartialResponse => {
                    // 中断正在执行的查询
                }
                case _ => {}
            }
        }
        requests = Array<PostgresSQLQueryJSC>()
    }

    /// 从绑定值推断 PostgreSQL 类型标签
    private func inferTag(value: PGValue): PGTag {
        match (value) {
            case PGValue.Null => PGTag.Text
            case PGValue.Bool(_) => PGTag.Bool
            case PGValue.Int32(_) => PGTag.Int4
            case PGValue.Int64(_) => PGTag.Int8
            case PGValue.Float64(_) => PGTag.Float8
            case PGValue.Text(_) => PGTag.Text
            case PGValue.Bytes(_) => PGTag.Bytea
            case _ => PGTag.Text
        }
    }

    /// 释放资源
    public func deinit() {
        disconnect()
        authenticationState.zero()
        saslAuth.deinit()
        writeBuffer = Array<UInt8>()
        readBuffer = Array<UInt8>()
        requests = Array<PostgresSQLQueryJSC>()
        statements.clear()
    }
}

/// PostgreSQL 预处理语句 JSC 绑定
/// 对应 Bun PostgresSQLStatement
public class PostgresSQLStatementJSC {
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

    /// 语句签名
    public var signature: PGSignature
    /// 状态
    public var status: StatementStatus
    /// 字段描述
    public var fields: Array<FieldDescription>
    /// 参数类型
    public var parameters: Array<UInt32>
    /// 缓存的结构
    public var cachedStructure: CachedStructure
    /// 是否需要检查重复字段
    public var needsDuplicateCheck: Bool
    /// 字段标志
    public var fieldsFlags: SQLDataCellFlags
    /// 错误响应
    public var errorResponse: ?ErrorResponse

    public init(signature: PGSignature) {
        this.signature = signature
        status = StatementStatus.Pending
        fields = Array<FieldDescription>()
        parameters = Array<UInt32>()
        cachedStructure = CachedStructure()
        needsDuplicateCheck = true
        fieldsFlags = SQLDataCellFlags()
        errorResponse = None
    }

    /// 转为 PGStatementRef
    public func toRef(): PGStatementRef {
        let ref = PGStatementRef(signature)
        ref.fields = fields
        ref.parameters = parameters
        match (status) {
            case StatementStatus.Pending => ref.status = PGStatementRef.StatementStatus.Pending
            case StatementStatus.Parsing => ref.status = PGStatementRef.StatementStatus.Parsing
            case StatementStatus.Prepared => ref.status = PGStatementRef.StatementStatus.Prepared
            case StatementStatus.Failed => ref.status = PGStatementRef.StatementStatus.Failed
        }
        return ref
    }
}

/// PostgreSQL 查询 JSC 绑定
/// 对应 Bun PostgresSQLQuery
public class PostgresSQLQueryJSC {
    /// 查询状态
    public var status: PGQueryStatus
    /// 查询标志
    public var queryFlags: PGQueryFlagsJSC
    /// 查询字符串
    public var queryString: String
    /// 关联的预处理语句
    public var statement: ?PostgresSQLStatementJSC
    /// 绑定参数值
    public var bindings: Array<PGValue>
    /// JS this 值引用
    public var thisValueRef: Int64
    /// JS 目标值引用
    public var targetValueRef: Int64
    /// JS pending value 引用
    public var pendingValueRef: Int64

    public init(query: String) {
        status = PGQueryStatus.Pending
        queryFlags = PGQueryFlagsJSC()
        queryString = query
        statement = None
        bindings = Array<PGValue>()
        thisValueRef = 0
        targetValueRef = 0
        pendingValueRef = 0
    }

    /// 查询标志
    /// 对应 Bun PostgresSQLQuery.flags
    public class PGQueryFlagsJSC {
        public var isDone: Bool
        public var binary: Bool
        public var bigint: Bool
        public var simple: Bool
        public var pipelined: Bool
        public var resultMode: SQLQueryResultMode

        public init() {
            isDone = false
            binary = false
            bigint = false
            simple = false
            pipelined = false
            resultMode = SQLQueryResultMode.Objects
        }
    }

    /// 标记完成
    public func doDone() {
        queryFlags.isDone = true
    }

    /// 释放资源
    public func deinit() {
        match (statement) {
            case Some(stmt) => {}
            case None => {}
        }
    }
}

/// 缓存结构
/// 对应 Bun PostgresCachedStructure
public class CachedStructure {
    /// JS 结构值引用
    public var structureRef: Int64
    /// 字段标识符列表
    public var fields: Array<ColumnIdentifier>

    public init() {
        structureRef = 0
        fields = Array<ColumnIdentifier>()
    }

    public func has(): Bool {
        structureRef != 0 || fields.size > 0
    }

    public func deinit() {
        fields = Array<ColumnIdentifier>()
        structureRef = 0
    }
}

/// 查询绑定迭代器
/// 对应 Bun QueryBindingIterator
public class QueryBindingIterator {
    public enum IterMode {
        | Array(Array<PGValue>)     // 数组模式
        | Objects(ObjectIterator)   // 对象模式
    }

    public var mode: IterMode
    public var index: Int64

    public init(values: Array<PGValue>) {
        mode = IterMode.Array(values)
        index = 0
    }

    public init(values: Array<PGValue>, columns: Array<PGValue>) {
        mode = IterMode.Objects(ObjectIterator(values, columns))
        index = 0
    }

    /// 获取下一个值
    public func next(): ?PGValue {
        match (mode) {
            case IterMode.Array(arr) => {
                if (index >= arr.size) {
                    return None
                }
                let v = arr[index]
                index += 1
                return v
            }
            case IterMode.Objects(iter) => {
                iter.next()
            }
        }
    }

    /// 跳转到指定索引
    public func to(idx: UInt32) {
        match (mode) {
            case IterMode.Array(_) => {
                index = idx
            }
            case IterMode.Objects(iter) => {
                iter.seek(idx)
            }
        }
    }

    /// 重置
    public func reset() {
        index = 0
        match (mode) {
            case IterMode.Objects(iter) => {
                iter.reset()
            }
            case _ => {}
        }
    }
}

/// 对象迭代器
/// 对应 Bun ObjectIterator
/// 用于遍历 JS 对象数组的属性
public class ObjectIterator {
    public var array: Array<PGValue>
    public var columns: Array<PGValue>
    public var cellIndex: Int64
    public var rowIndex: Int64
    public var columnsCount: Int64
    public var arrayLength: Int64

    public init(array: Array<PGValue>, columns: Array<PGValue>) {
        this.array = array
        this.columns = columns
        cellIndex = 0
        rowIndex = 0
        columnsCount = columns.size
        arrayLength = array.size
    }

    public func next(): ?PGValue {
        if (rowIndex >= arrayLength) {
            return None
        }
        if (cellIndex >= columnsCount) {
            return None
        }
        // 简化: 按索引返回
        let idx = rowIndex * columnsCount + cellIndex
        cellIndex += 1
        if (cellIndex >= columnsCount) {
            cellIndex = 0
            rowIndex += 1
        }
        if (idx < array.size) {
            return array[idx]
        }
        return None
    }

    public func seek(pos: UInt32) {
        cellIndex = pos % columnsCount
        rowIndex = pos / columnsCount
    }

    public func reset() {
        cellIndex = 0
        rowIndex = 0
    }
}
