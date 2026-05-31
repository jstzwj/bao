// PostgreSQL 连接客户端 - 连接管理与协议处理
// 严格翻译自: bun/src/sql_jsc/postgres/PostgresSQLConnection.zig 中的核心逻辑
// 包含连接生命周期、消息处理、查询执行
package bao_runtime.sql.postgresql

import bao_runtime.sql.shared.*

/// PostgreSQL 连接客户端
/// 管理与 PostgreSQL 服务器的连接，处理协议消息
/// 对应 Bun PostgresSQLConnection 的核心功能
public class PGClient {
    /// 连接配置
    public var config: PGConnectionConfig
    /// 连接状态
    public var status: PGConnectionStatus
    /// 连接标志
    public var flags: SQLConnectionFlags
    /// TLS 状态
    public var tlsStatus: TLSStatus
    /// SSL 模式
    public var sslMode: SSLMode
    /// 认证状态
    public var authenticationState: AuthenticationState
    /// 后端密钥数据
    public var backendKeyData: BackendKeyData
    /// 后端参数
    public var backendParameters: HashMap<String, String>
    /// 预处理语句缓存
    public var statements: HashMap<String, PGStatement>
    /// 语句 ID 计数器
    public var statementId: UInt64
    /// 待处理请求队列
    public var pendingQueries: ArrayList<PGQuery>
    /// 流水线请求数
    public var pipelinedRequests: UInt32
    /// 非流水线请求数
    public var nonPipelinableRequests: UInt32
    /// 协议写入器
    public var writer: ProtocolWriter
    /// 读取缓冲区
    public var readBuffer: Array<UInt8>
    /// 最后消息起始位置
    public var lastMessageStart: Int64

    // 回调
    public var onConnectCallback: ?(PGClient) -> Unit
    public var onCloseCallback: ?(PGClient, ?PGError) -> Unit

    public init(config: PGConnectionConfig) {
        this.config = config
        status = PGConnectionStatus.Disconnected
        flags = SQLConnectionFlags()
        tlsStatus = TLSStatus.None
        sslMode = config.sslMode
        authenticationState = AuthenticationState.Pending
        backendKeyData = BackendKeyData()
        backendParameters = HashMap<String, String>()
        statements = HashMap<String, PGStatement>()
        statementId = 0
        pendingQueries = ArrayList<PGQuery>()
        pipelinedRequests = 0
        nonPipelinableRequests = 0
        writer = ProtocolWriter()
        readBuffer = Array<UInt8>()
        lastMessageStart = 0
        onConnectCallback = None
        onCloseCallback = None
    }

    // ========================================================================
    // 连接管理
    // ========================================================================

    /// 发送启动消息
    /// 对应 Bun PostgresSQLConnection.sendStartupMessage()
    public func sendStartupMessage(): Unit {
        if (status != PGConnectionStatus.Connecting) {
            return
        }
        status = PGConnectionStatus.SentStartupMessage
        ClientMessageWriter.writeStartupMessage(
            writer,
            config.user,
            config.database,
            config.options
        )
    }

    /// 开始 TLS 握手
    /// 对应 Bun PostgresSQLConnection.startTLS()
    public func startTLS(): Unit {
        let offset = match (tlsStatus) {
            case TLSStatus.MessageSent(count) => Int64(count)
            case _ => 0
        }
        // 写入 SSL 请求消息
        let sslRequest = SSL_REQUEST
        for (i in Int64(offset)..5) {
            writer.writeByte(sslRequest[i])
        }
        tlsStatus = TLSStatus.MessageSent(UInt8(offset))
    }

    /// 处理连接打开
    /// 对应 Bun PostgresSQLConnection.onOpen()
    public func onOpen(): Unit {
        if (tlsStatus.isPending()) {
            startTLS()
            return
        }
        sendStartupMessage()
    }

    /// 断开连接
    /// 对应 Bun PostgresSQLConnection.disconnect()
    public func disconnect(): Unit {
        stopTimers()
        if (status == PGConnectionStatus.Connected) {
            status = PGConnectionStatus.Disconnected
            cleanupRequests()
        }
    }

    /// 关闭连接
    /// 对应 Bun PostgresSQLConnection.close()
    public func close(): Unit {
        disconnect()
        writer.clear()
    }

    /// 处理连接失败
    /// 对应 Bun PostgresSQLConnection.fail()
    public func fail(message: String, error: PostgresError): Unit {
        status = PGConnectionStatus.Failed
        match (onCloseCallback) {
            case Some(cb) => cb(this, PGError(message: message, error: error))
            case None => {}
        }
    }

    /// 处理连接关闭
    /// 对应 Bun PostgresSQLConnection.onClose()
    public func onClose(): Unit {
        fail("Connection closed", PostgresError.ConnectionClosed)
    }

    /// 停止定时器
    /// 对应 Bun PostgresSQLConnection.stopTimers()
    public func stopTimers(): Unit {
        // 定时器逻辑由上层管理
    }

    // ========================================================================
    // 查询执行
    // ========================================================================

    /// 执行简单查询
    /// 对应 Bun PostgresSQLConnection 中的简单查询路径
    public func executeQuery(query: String): PGQuery {
        let pgQuery = PGQuery(query)
        pgQuery.flags.simple = true
        pendingQueries.append(pgQuery)
        advance()
        return pgQuery
    }

    /// 执行预处理查询
    /// 对应 Bun PostgresSQLConnection 中的预处理查询路径
    public func executePrepared(query: String, bindings: Array<PGValue>): PGQuery {
        let pgQuery = PGQuery(query, bindings)
        pgQuery.flags.simple = false

        // 查找或创建预处理语句
        let stmtName = "stmt_${statementId}"
        statementId += 1
        let signature = PGStatementSignature(name: query, fields: Array<UInt32>())
        signature.preparedStatementName = stmtName
        let stmt = PGStatement(signature)
        statements.put(stmtName, stmt)
        pgQuery.statement = stmt

        pendingQueries.append(pgQuery)
        advance()
        return pgQuery
    }

    /// 推进请求处理
    /// 对应 Bun PostgresSQLConnection.advance()
    public func advance(): Unit {
        var offset = 0
        while (offset < pendingQueries.size && !flags.hasBackpressure) {
            let req = pendingQueries[offset]
            match (req.status) {
                case PGQueryStatus.Pending => {
                    if (req.flags.simple) {
                        // 简单查询
                        if (!flags.isReadyForQuery) {
                            return  // 等待前一个查询完成
                        }
                        ClientMessageWriter.writeQuery(writer, req.query)
                        ClientMessageWriter.writeSync(writer)
                        nonPipelinableRequests += 1
                        flags.isReadyForQuery = false
                        req.status = PGQueryStatus.Running
                        return
                    } else {
                        // 预处理查询
                        match (req.statement) {
                            case Some(stmt) => {
                                match (stmt.status) {
                                    case PGStatement.StatementStatus.Prepared => {
                                        // 绑定并执行
                                        let bindings = req.bindings.map({ v =>
                                            v.toBytes()
                                        })
                                        ClientMessageWriter.writeBind(
                                            writer, "",
                                            stmt.signature.preparedStatementName,
                                            bindings,
                                            Array<UInt16>(),
                                            Array<UInt16>()
                                        )
                                        ClientMessageWriter.writeExecute(writer, "", 0)
                                        ClientMessageWriter.writeSync(writer)
                                        flags.isReadyForQuery = false
                                        req.status = PGQueryStatus.Binding
                                        req.flags.pipelined = true
                                        pipelinedRequests += 1
                                        offset += 1
                                    }
                                    case PGStatement.StatementStatus.Pending => {
                                        // 解析 + 描述 + 同步
                                        ClientMessageWriter.writeParse(
                                            writer,
                                            stmt.signature.preparedStatementName,
                                            req.query,
                                            Array<UInt32>()
                                        )
                                        ClientMessageWriter.writeDescribe(
                                            writer,
                                            stmt.signature.preparedStatementName,
                                            true
                                        )
                                        ClientMessageWriter.writeSync(writer)
                                        flags.isReadyForQuery = false
                                        flags.waitingToPrepare = true
                                        stmt.status = PGStatement.StatementStatus.Parsing
                                        return
                                    }
                                    case PGStatement.StatementStatus.Parsing => {
                                        offset += 1  // 等待解析完成
                                    }
                                    case PGStatement.StatementStatus.Failed => {
                                        req.status = PGQueryStatus.Fail
                                        offset += 1
                                    }
                                }
                            }
                            case None => {
                                offset += 1
                            }
                        }
                    }
                }
                case PGQueryStatus.Running | PGQueryStatus.Binding |
                     PGQueryStatus.PartialResponse => {
                    offset += 1
                }
                case PGQueryStatus.Success | PGQueryStatus.Fail => {
                    offset += 1
                }
            }
        }
    }

    // ========================================================================
    // 消息处理
    // ========================================================================

    /// 处理接收到的数据
    /// 对应 Bun PostgresSQLConnection.onData()
    public func onData(data: Array<UInt8>): Unit {
        flags.isProcessingData = true
        defer {
            flags.isProcessingData = false
        }

        // 将数据追加到读取缓冲区
        readBuffer = readBuffer + data

        // 处理缓冲区中的消息
        let reader = ProtocolReader(readBuffer, lastMessageStart)
        processMessages(reader)

        // 清理已消费的数据
        readBuffer = Array<UInt8>()
        lastMessageStart = 0
    }

    /// 处理协议消息循环
    /// 对应 Bun PostgresSQLConnection.on() 中的消息分发逻辑
    public func processMessages(reader: ProtocolReader): Unit {
        while (reader.remaining() > 0) {
            let msgType = reader.readByte()
            match (msgType) {
                case None => break
                case Some(b) => {
                    reader.markMessageStart()
                    let processed = handleMessage(b, reader)
                    if (!processed) {
                        break  // 短读，等待更多数据
                    }
                }
            }
        }
    }

    /// 处理单个消息
    /// 对应 Bun PostgresSQLConnection.on() 中的 switch
    private func handleMessage(msgByte: UInt8, reader: ProtocolReader): Bool {
        match (msgByte) {
            case 82 => handleAuthentication(reader)   // 'R' - Authentication
            case 75 => handleBackendKeyData(reader)    // 'K' - BackendKeyData
            case 83 => handleParameterStatus(reader)   // 'S' - ParameterStatus
            case 90 => handleReadyForQuery(reader)     // 'Z' - ReadyForQuery
            case 84 => handleRowDescription(reader)    // 'T' - RowDescription
            case 68 => handleDataRow(reader)           // 'D' - DataRow
            case 67 => handleCommandComplete(reader)   // 'C' - CommandComplete
            case 69 => handleErrorResponse(reader)     // 'E' - ErrorResponse
            case 78 => handleNoticeResponse(reader)    // 'N' - NoticeResponse
            case 65 => handleNotificationResponse(reader)// 'A' - NotificationResponse
            case 116 => handleParameterDescription(reader)// 't' - ParameterDescription
            case 49 => handleParseComplete(reader)     // '1' - ParseComplete
            case 50 => handleBindComplete(reader)      // '2' - BindComplete
            case 51 => handleCloseComplete(reader)     // '3' - CloseComplete
            case 73 => handleEmptyQueryResponse(reader)// 'I' - EmptyQueryResponse
            case 110 => handleNoData(reader)           // 'n' - NoData
            case _ => {
                // 未知消息类型，尝试跳过
                let _len = reader.readLength()
                match (_len) {
                    case None => return false
                    case Some(len) => reader.skip(Int64(len) - 4)
                }
            }
        }
        return true
    }

    // ========================================================================
    // 各消息类型的处理器
    // ========================================================================

    /// 处理认证消息
    /// 对应 Bun PostgresSQLConnection.on(.Authentication)
    private func handleAuthentication(reader: ProtocolReader): Bool {
        let auth = AuthenticationDecoder.decode(reader)
        match (auth) {
            case None => return false
            case Some(msg) => {
                match (msg) {
                    case AuthenticationMessage.Ok => {
                        authenticationState = AuthenticationState.Ok
                    }
                    case AuthenticationMessage.ClearTextPassword => {
                        ClientMessageWriter.writePasswordMessage(writer, config.password)
                    }
                    case AuthenticationMessage.MD5Password(salt) => {
                        // MD5 密码认证
                        // md5(md5(password + user) + salt)
                        let md5Pwd = computeMD5Password(config.password, config.user, salt)
                        ClientMessageWriter.writePasswordMessage(writer, md5Pwd)
                        authenticationState = AuthenticationState.MD5
                    }
                    case AuthenticationMessage.SASL => {
                        // SCRAM-SHA-256 开始
                        let saslState = SASLState()
                        let nonce = saslState.nonce()
                        let mechanism = "n,,n=*,r=${nonce}"
                        ClientMessageWriter.writeSASLInitialResponse(
                            writer, "SCRAM-SHA-256", mechanism
                        )
                        authenticationState = AuthenticationState.SASL(saslState)
                    }
                    case AuthenticationMessage.SASLContinue(data) => {
                        // SCRAM-SHA-256 继续
                        // 这里需要实际的 SCRAM 计算逻辑
                    }
                    case AuthenticationMessage.SASLFinal(data) => {
                        // SCRAM-SHA-256 最终验证
                        data.zeroDeinit()
                        authenticationState = AuthenticationState.Ok
                    }
                    case AuthenticationMessage.Unknown => {
                        fail("Unknown authentication method", PostgresError.UnknownAuthenticationMethod)
                    }
                    case _ => {
                        fail("Unsupported authentication method", PostgresError.UnsupportedAuthenticationMethod)
                    }
                }
                msg.deinit()
            }
        }
        return true
    }

    /// 处理后端密钥数据
    private func handleBackendKeyData(reader: ProtocolReader): Bool {
        backendKeyData.decode(reader)
    }

    /// 处理参数状态
    private func handleParameterStatus(reader: ProtocolReader): Bool {
        let param = ParameterStatus()
        let result = param.decode(reader)
        if (result) {
            backendParameters.put(param.nameString(), param.valueString())
        }
        param.deinit()
        result
    }

    /// 处理 ReadyForQuery
    /// 对应 Bun PostgresSQLConnection.on(.ReadyForQuery)
    private func handleReadyForQuery(reader: ProtocolReader): Bool {
        let ready = ReadyForQuery()
        let result = ready.decode(reader)
        if (result) {
            if (status != PGConnectionStatus.Connected) {
                status = PGConnectionStatus.Connected
                match (onConnectCallback) {
                    case Some(cb) => cb(this)
                    case None => {}
                }
            }
            flags.waitingToPrepare = false
            flags.isReadyForQuery = true

            // 完成当前查询（如果是部分响应）
            if (pendingQueries.size > 0) {
                let current = pendingQueries[0]
                if (current.status == PGQueryStatus.PartialResponse) {
                    finishRequest(current)
                }
            }

            // 推进下一个查询
            advance()
        }
        result
    }

    /// 处理行描述
    /// 对应 Bun PostgresSQLConnection.on(.RowDescription)
    private func handleRowDescription(reader: ProtocolReader): Bool {
        let desc = RowDescription()
        let result = desc.decode(reader)
        if (result && pendingQueries.size > 0) {
            let query = pendingQueries[0]
            match (query.statement) {
                case Some(stmt) => {
                    // 更新语句的字段描述
                    for (field in stmt.fields) {
                        field.deinit()
                    }
                    stmt.fields = desc.fields
                    stmt.needsDuplicateCheck = true
                    desc.fields = Array<FieldDescription>()  // 转移所有权
                }
                case None => {
                    // 简单查询 - 创建临时语句
                    desc.deinit()
                }
            }
        }
        return result
    }

    /// 处理数据行
    /// 对应 Bun PostgresSQLConnection.on(.DataRow)
    private func handleDataRow(reader: ProtocolReader): Bool {
        match (DataRow.decode(reader)) {
            case Some(row) => {
                if (pendingQueries.size > 0) {
                    let query = pendingQueries[0]
                    match (query.result) {
                        case Some(result) => result.rows.append(row)
                        case None => {
                            let result = PGQueryResult()
                            result.rows.append(row)
                            query.result = result
                        }
                    }
                }
                return true
            }
            case None => return false
        }
    }

    /// 处理命令完成
    /// 对应 Bun PostgresSQLConnection.on(.CommandComplete)
    private func handleCommandComplete(reader: ProtocolReader): Bool {
        let cmd = CommandComplete()
        let result = cmd.decode(reader)
        if (result && pendingQueries.size > 0) {
            let query = pendingQueries[0]
            let tag = CommandTag.init(cmd.tagString())
            match (query.result) {
                case Some(r) => r.commandTag = tag
                case None => {
                    let r = PGQueryResult()
                    r.commandTag = tag
                    query.result = r
                }
            }
        }
        cmd.deinit()
        return result
    }

    /// 处理错误响应
    /// 对应 Bun PostgresSQLConnection.on(.ErrorResponse)
    private func handleErrorResponse(reader: ProtocolReader): Bool {
        let err = ErrorResponse()
        let result = err.decode(reader)
        if (result) {
            if (status == PGConnectionStatus.Connecting ||
                status == PGConnectionStatus.SentStartupMessage) {
                // 连接阶段的错误
                let msg = err.message().getOrThrow()
                fail(msg, PostgresError.ConnectionClosed)
                err.deinit()
                return result
            }

            if (pendingQueries.size > 0) {
                let query = pendingQueries[0]
                match (query.statement) {
                    case Some(stmt) => {
                        if (stmt.status == PGStatement.StatementStatus.Parsing) {
                            stmt.status = PGStatement.StatementStatus.Failed
                            stmt.errorResponse = err
                        }
                    }
                    case None => {}
                }
                query.status = PGQueryStatus.Fail
            } else {
                err.deinit()
            }
        }
        result
    }

    /// 处理通知响应
    private func handleNoticeResponse(reader: ProtocolReader): Bool {
        let notice = NoticeResponse()
        let result = notice.decode(reader)
        notice.deinit()
        result
    }

    /// 处理通知 (LISTEN/NOTIFY)
    private func handleNotificationResponse(reader: ProtocolReader): Bool {
        let notif = NotificationResponse()
        notif.decode(reader)
        // 可以触发回调
        true
    }

    /// 处理参数描述
    private func handleParameterDescription(reader: ProtocolReader): Bool {
        let desc = ParameterDescription()
        let result = desc.decode(reader)
        if (result && pendingQueries.size > 0) {
            let query = pendingQueries[0]
            match (query.statement) {
                case Some(stmt) => {
                    stmt.parameters = desc.parameters
                    if (stmt.status == PGStatement.StatementStatus.Parsing) {
                        stmt.status = PGStatement.StatementStatus.Prepared
                        flags.waitingToPrepare = false
                    }
                }
                case None => {}
            }
        }
        result
    }

    /// 处理解析完成
    private func handleParseComplete(reader: ProtocolReader): Bool {
        if (!reader.eatMessage(PARSE_COMPLETE)) {
            return false
        }
        if (pendingQueries.size > 0) {
            let query = pendingQueries[0]
            match (query.statement) {
                case Some(stmt) => {
                    if (stmt.status == PGStatement.StatementStatus.Parsing &&
                        stmt.signature.fields.size == 0) {
                        stmt.status = PGStatement.StatementStatus.Prepared
                        flags.waitingToPrepare = false
                    }
                }
                case None => {}
            }
        }
        return true
    }

    /// 处理绑定完成
    private func handleBindComplete(reader: ProtocolReader): Bool {
        if (!reader.eatMessage(BIND_COMPLETE)) {
            return false
        }
        if (pendingQueries.size > 0) {
            let query = pendingQueries[0]
            if (query.status == PGQueryStatus.Binding) {
                query.status = PGQueryStatus.Running
            }
        }
        return true
    }

    /// 处理关闭完成
    private func handleCloseComplete(reader: ProtocolReader): Bool {
        reader.eatMessage(CLOSE_COMPLETE)
    }

    /// 处理空查询响应
    private func handleEmptyQueryResponse(reader: ProtocolReader): Bool {
        reader.eatMessage(EMPTY_QUERY_RESPONSE)
    }

    /// 处理无数据
    private func handleNoData(reader: ProtocolReader): Bool {
        reader.eatMessage(NO_DATA)
    }

    // ========================================================================
    // 辅助方法
    // ========================================================================

    /// 完成当前请求
    private func finishRequest(query: PGQuery): Unit {
        match (query.status) {
            case PGQueryStatus.Running | PGQueryStatus.Binding |
                 PGQueryStatus.PartialResponse => {
                if (query.flags.simple) {
                    nonPipelinableRequests -= 1
                } else if (query.flags.pipelined) {
                    pipelinedRequests -= 1
                }
            }
            case _ => {}
        }
        query.status = PGQueryStatus.Success
    }

    /// 清理所有待处理请求
    private func cleanupRequests(): Unit {
        for (query in pendingQueries) {
            match (query.status) {
                case PGQueryStatus.Pending | PGQueryStatus.Binding |
                     PGQueryStatus.Running | PGQueryStatus.PartialResponse => {
                    query.status = PGQueryStatus.Fail
                    match (query.statement) {
                        case Some(stmt) => {
                            stmt.status = PGStatement.StatementStatus.Failed
                        }
                        case None => {}
                    }
                }
                case _ => {}
            }
            query.deinit()
        }
        pendingQueries = ArrayList<PGQuery>()
    }

    /// 计算 MD5 密码
    /// 对应 Bun PostgresSQLConnection.on(.MD5Password) 中的 MD5 计算逻辑
    private func computeMD5Password(password: String, user: String, salt: Array<UInt8>): String {
        // md5(md5(password + user) + salt)
        // 需要 MD5 实现
        // 第一轮: md5(password + user)
        let firstInput = (password + user).toArray().map({ c => UInt8(c) })
        let firstHash = MD5.hash(firstInput)

        // 第二轮: md5(firstHash_hex + salt)
        let firstHex = firstHash.map({ b =>
            let hex = UInt8.toHexString(b)
            if (hex.size == 1) "0${hex}" else hex
        }).toString()
        let secondInput = firstHex.toArray().map({ c => UInt8(c) }) + salt
        let secondHash = MD5.hash(secondInput)

        // 结果: "md5" + hex(secondHash)
        let result = "md5" + secondHash.map({ b =>
            let hex = UInt8.toHexString(b)
            if (hex.size == 1) "0${hex}" else hex
        }).toString()

        result
    }

    /// 是否有查询正在运行
    public func hasQueryRunning(): Bool {
        !flags.isReadyForQuery || pendingQueries.size > 0
    }

    /// 是否已连接
    public func isConnected(): Bool {
        status == PGConnectionStatus.Connected
    }

    /// 获取写入缓冲区数据
    public func flushWriteBuffer(): Array<UInt8> {
        writer.getBuffer()
    }

    /// 释放资源
    public func deinit(): Unit {
        disconnect()
        for ((_, stmt) in statements) {
            stmt.deinit()
        }
        for (query in pendingQueries) {
            query.deinit()
        }
    }
}

/// PostgreSQL 错误信息
public class PGError {
    public var message: String
    public var error: PostgresError
    public var code: ?String
    public var detail: ?String
    public var hint: ?String
    public var position: ?String

    public init(message: String, error: PostgresError) {
        this.message = message
        this.error = error
        code = None
        detail = None
        hint = None
        position = None
    }
}
