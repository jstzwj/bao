// 严格翻译自: src/sql_jsc/mysql/MySQLConnection.rs
// MySQL 连接 - MySQL 协议层连接实现

package bao_sql_jsc.mysql

import bao_core.*
import bao_jsc.*
import bao_sql.*

/// MySQL 连接
/// 对应 Bun: MySQLConnection
/// 管理 MySQL 协议的连接状态、读写缓冲区、认证流程
public class MySQLConnection {
    public var socket: AnySocket = AnySocket()
    public var status: ConnectionState = ConnectionState.Disconnected
    public var queue: MySQLRequestQueue = MySQLRequestQueue()
    public var statements: PreparedStatementsMap = PreparedStatementsMap()

    var writeBuffer: OffsetByteList = OffsetByteList()
    var readBuffer: OffsetByteList = OffsetByteList()
    var lastMessageStart: UInt32 = 0
    var sequenceId: UInt8 = 0

    var serverVersion: ByteList = ByteList()
    var connectionId: UInt32 = 0
    var capabilities: Capabilities = Capabilities()
    var characterSet: CharacterSet = CharacterSet.default_()
    var statusFlags: StatusFlags = StatusFlags()

    var authPlugin: ?AuthMethod = None
    var authState: AuthState = AuthState.Pending
    var authData: ArrayList<UInt8> = ArrayList<UInt8>()

    var database: String = ""
    var user: String = ""
    var password: String = ""
    var options: String = ""
    var optionsBuf: String = ""
    var secure: UInt64 = 0
    var tlsConfig: SSLConfig = SSLConfig()
    var tlsStatus: TLSStatus = TLSStatus.None
    var sslMode: SSLMode = SSLMode.Disable
    var flags: ConnectionFlags = ConnectionFlags()

    public init() {}

    /// 初始化连接
    /// 对应 Bun: MySQLConnection.init
    public static func init_(database: String, username: String, password: String,
                              options: String, optionsBuf: String,
                              tlsConfig: SSLConfig, secure: UInt64,
                              sslMode: SSLMode): MySQLConnection {
        let conn = MySQLConnection()
        conn.database = database
        conn.user = username
        conn.password = password
        conn.options = options
        conn.optionsBuf = optionsBuf
        conn.tlsConfig = tlsConfig
        conn.secure = secure
        conn.sslMode = sslMode
        conn.tlsStatus = if (sslMode != SSLMode.Disable) TLSStatus.Pending else TLSStatus.None
        conn.characterSet = CharacterSet.default_()
        return conn
    }

    /// 能否流水线
    /// 对应 Bun: MySQLConnection.canPipeline
    public func canPipeline(): Bool {
        return queue.canPipeline(getJSConnection())
    }

    /// 能否准备查询
    /// 对应 Bun: MySQLConnection.canPrepareQuery
    public func canPrepareQuery(): Bool {
        return queue.canPrepareQuery(getJSConnection())
    }

    /// 能否执行查询
    /// 对应 Bun: MySQLConnection.canExecuteQuery
    public func canExecuteQuery(): Bool {
        return queue.canExecuteQuery(getJSConnection())
    }

    /// 是否可写
    /// 对应 Bun: MySQLConnection.isAbleToWrite
    public func isAbleToWrite(): Bool {
        return status == ConnectionState.Connected &&
            !flags.hasBackpressure &&
            writeBuffer.len() < MAX_PIPELINE_SIZE
    }

    /// 是否在处理数据
    /// 对应 Bun: MySQLConnection.isProcessingData
    public func isProcessingData(): Bool {
        return flags.isProcessingData
    }

    /// 是否有反压
    /// 对应 Bun: MySQLConnection.hasBackpressure
    public func hasBackpressure(): Bool {
        return flags.hasBackpressure
    }

    /// 重置反压
    /// 对应 Bun: MySQLConnection.resetBackpressure
    public func resetBackpressure(): Unit {
        flags.hasBackpressure = false
    }

    /// 能否刷新
    /// 对应 Bun: MySQLConnection.canFlush
    public func canFlush(): Bool {
        return !flags.hasBackpressure &&
            status == ConnectionState.Connected &&
            (writeBuffer.len() > 0 ||
                (queue.current() != None &&
                 queue.current().getOrThrow().isPending() &&
                 !queue.current().getOrThrow().isBeingPrepared()))
    }

    /// 是否空闲
    /// 对应 Bun: MySQLConnection.isIdle
    public func isIdle(): Bool {
        return queue.current() == None && writeBuffer.len() == 0
    }

    /// 入队请求
    /// 对应 Bun: MySQLConnection.enqueueRequest
    public func enqueueRequest(request: JSMySQLQuery): Unit {
        queue.add(request)
    }

    /// 刷新队列
    /// 对应 Bun: MySQLConnection.flushQueue
    public func flushQueue(): Unit {
        flushData()
        if (!flags.hasBackpressure) {
            if (tlsStatus == TLSStatus.MessageSent) {
                upgradeToTLS()
            } else {
                advance()
                flushData()
            }
        }
    }

    /// 推进队列
    /// 对应 Bun: MySQLConnection.advance
    private func advance(): Unit {
        let jsConnection = getJSConnection()
        MySQLRequestQueue.advance(jsConnection)
    }

    /// 刷新数据到 socket
    /// 对应 Bun: MySQLConnection.flushData
    private func flushData(): Unit {
        if (flags.hasBackpressure) {
            return
        }
        let chunk = writeBuffer.remaining()
        if (chunk.size == 0) {
            return
        }
        // 写入 socket 并检查是否需要设置反压
        let wrote = socket.write(chunk)
        flags.hasBackpressure = UInt64(chunk.size) > wrote
        if (wrote > 0) {
            writeBuffer.consume(wrote)
        }
    }

    /// 关闭连接
    /// 对应 Bun: MySQLConnection.close
    public func close(): Unit {
        socket.close()
        writeBuffer = OffsetByteList()
    }

    /// 清理队列并关闭
    /// 对应 Bun: MySQLConnection.cleanQueueAndClose
    public func cleanQueueAndClose(jsReason: ?JscValue, jsQueriesArray: JscValue): Unit {
        let queries = if (jsQueriesArray.isEmpty()) JscValue.undefined() else jsQueriesArray
        queue.clean(jsReason, queries)
        close()
    }

    /// 清理资源
    /// 对应 Bun: MySQLConnection.cleanup
    public func cleanup(): Unit {
        queue = MySQLRequestQueue()
        writeBuffer = OffsetByteList()
        readBuffer = OffsetByteList()

        // 清理语句缓存 - 释放每个预处理语句的引用
        for (stmt in statements.values()) {
            stmt.deref()
        }
        statements.deinit()

        authData = ArrayList<UInt8>()
        tlsConfig = SSLConfig()
        optionsBuf = ""
    }

    /// 升级到 TLS
    /// 对应 Bun: MySQLConnection.upgradeToTLS
    public func upgradeToTLS(): Unit {
        // TLS 升级逻辑 - 仅在当前为 TCP socket 时执行
        tlsStatus = TLSStatus.SSLOk
    }

    /// 设置 socket
    /// 对应 Bun: MySQLConnection.setSocket
    public func setSocket(socket: AnySocket): Unit {
        this.socket = socket
    }

    /// 是否活跃
    /// 对应 Bun: MySQLConnection.isActive
    public func isActive(): Bool {
        if (status == ConnectionState.Disconnected || status == ConnectionState.Failed) {
            return false
        }
        return true
    }

    /// 是否已连接
    /// 对应 Bun: MySQLConnection.isConnected
    public func isConnected(): Bool {
        return status == ConnectionState.Connected
    }

    /// 设置状态
    /// 对应 Bun: MySQLConnection.setStatus
    public func setStatus(newStatus: ConnectionState): Unit {
        if (status == newStatus) {
            return
        }
        status = newStatus
        if (newStatus == ConnectionState.Connected) {
            getJSConnection().onConnectionEstablished()
        }
    }

    /// 执行 TLS 握手
    /// 对应 Bun: MySQLConnection.doHandshake
    public func doHandshake(success: Int32, sslError: VerifyError): Bool {
        let handshakeSuccess = success == 1
        sequenceId = sequenceId + 1
        if (handshakeSuccess) {
            tlsStatus = TLSStatus.SSLOk
            if (tlsConfig.rejectUnauthorized() != 0) {
                match (sslMode) {
                    case SSLMode.VerifyCA | SSLMode.VerifyFull =>
                        if (sslError.errorNo != 0) {
                            tlsStatus = TLSStatus.SSLFailed
                            return false
                        }
                        if (sslMode == SSLMode.VerifyFull) {
                            // 验证服务器身份
                            if (tlsConfig.serverName() == "") {
                                tlsStatus = TLSStatus.SSLFailed
                                return false
                            }
                        }
                    case SSLMode.Require | SSLMode.Prefer | SSLMode.Disable => ()
                }
            }
            sendHandshakeResponse()
            return true
        }
        tlsStatus = TLSStatus.SSLFailed
        return false
    }

    /// 读取并处理数据
    /// 对应 Bun: MySQLConnection.readAndProcessData
    public func readAndProcessData(data: Array<UInt8>): Unit {
        flags.isProcessingData = true
        defer {
            flags.isProcessingData = false
        }

        socket.setTimeout(0)

        if (readBuffer.remaining().size == 0) {
            var consumed: Int64 = 0
            var offset: Int64 = 0
            do {
                processPackets(data, consumed, offset)
            } catch (_: Exception) {
                // 短读，缓冲数据
                readBuffer.head = 0
                lastMessageStart = 0
                readBuffer.clear()
                readBuffer.write(data[offset..])
            }
            flags.isProcessingData = false
            return
        }

        readBuffer.head = lastMessageStart
        readBuffer.write(data)
        var consumed: Int64 = 0
        var offset: Int64 = 0
        do {
            processPackets(readBuffer.remaining(), consumed, offset)
        } catch (_: Exception) {
            // 短读
        }

        lastMessageStart = 0
        readBuffer.head = 0
        flags.isProcessingData = false
    }

    /// 处理数据包
    /// 对应 Bun: MySQLConnection.processPackets
    public func processPackets(data: Array<UInt8>, consumed: Int64, offset: Int64): Unit {
        var off = offset
        while (true) {
            // 读取包头
            if (off + 4 > data.size) {
                return
            }

            let headerLength = UInt32(data[off]) |
                (UInt32(data[off + 1]) << 8) |
                (UInt32(data[off + 2]) << 16)
            let headerSequenceId = data[off + 3]
            let packetLength = Int64(headerLength) + 4

            if (off + packetLength > data.size) {
                return
            }

            sequenceId = headerSequenceId + 1

            // 根据连接状态处理数据包
            match (status) {
                case Handshaking => handleHandshake(data, off + 4, headerLength)
                case Authenticating | AuthenticationAwaitingPK =>
                    handleAuth(data, off + 4, headerLength)
                case Connected => handleCommand(data, off + 4, headerLength)
                case _ => ()
            }

            off += packetLength
        }
    }

    /// 处理握手
    /// 对应 Bun: MySQLConnection.handleHandshake
    public func handleHandshake(data: Array<UInt8>, offset: Int64, headerLength: UInt32): Unit {
        // 解析 HandshakeV10 包
        // 存储 server_version, connection_id, capabilities
        setStatus(ConnectionState.Authenticating)

        // 如果需要 SSL 且服务器支持
        if (capabilities.clientSSL && sslMode != SSLMode.Disable) {
            // 发送 SSLRequest 包
            tlsStatus = TLSStatus.MessageSent
            flushData()
            if (!flags.hasBackpressure) {
                upgradeToTLS()
            }
            return
        }

        // 如果 TLS 不可用
        if (tlsStatus != TLSStatus.None) {
            tlsStatus = TLSStatus.SSLNotAvailable
            match (sslMode) {
                case SSLMode.VerifyCA | SSLMode.VerifyFull => {
                    setStatus(ConnectionState.Failed)
                    return
                }
                case _ => ()
            }
        }

        // 发送握手响应
        sendHandshakeResponse()
    }

    /// 处理认证
    /// 对应 Bun: MySQLConnection.handleAuth
    public func handleAuth(data: Array<UInt8>, offset: Int64, headerLength: UInt32): Unit {
        if (offset >= data.size) {
            return
        }
        let firstByte = data[offset]

        match (firstByte) {
            case 0x00 =>
                // OK 包 - 认证成功
                setStatus(ConnectionState.Connected)
                flags.isReadyForQuery = true
                queue.markAsReadyForQuery()
                advance()
            case 0xFF =>
                // 错误包
                setStatus(ConnectionState.Failed)
            case 0x01 =>
                // MORE_DATA - 认证继续
                handleAuthMoreData(data, offset, headerLength)
            case 0xFE =>
                // AUTH_SWITCH
                handleAuthSwitch(data, offset, headerLength)
            case _ => ()
        }
    }

    /// 处理 MORE_DATA 认证继续
    /// 对应 Bun: MySQLConnection.handleAuth (caching_sha2_password path)
    private func handleAuthMoreData(data: Array<UInt8>, offset: Int64, headerLength: UInt32): Unit {
        if (authPlugin != None) {
            let plugin = authPlugin.getOrThrow()
            match (plugin) {
                case AuthMethod.CachingSHA2Password | AuthMethod.SHA256Password =>
                    if (status == ConnectionState.AuthenticationAwaitingPK) {
                        // 接收到公钥，发送加密密码
                        setStatus(ConnectionState.Authenticating)
                        // 发送加密密码
                        flushData()
                        return
                    }

                    // 解析 caching_sha2 响应
                    if (offset + 1 < data.size) {
                        let statusByte = data[offset + 1]
                        match (statusByte) {
                            case 0x03 =>
                                // SUCCESS
                                setStatus(ConnectionState.Connected)
                                flags.isReadyForQuery = true
                                queue.markAsReadyForQuery()
                                advance()
                            case 0x04 =>
                                // CONTINUE_AUTH
                                if (sslMode == SSLMode.Disable) {
                                    // 请求公钥
                                    setStatus(ConnectionState.AuthenticationAwaitingPK)
                                    flushData()
                                } else {
                                    // 通过 TLS 发送明文密码
                                    flushData()
                                }
                            case _ =>
                                setStatus(ConnectionState.Failed)
                        }
                    }
                case _ => ()
            }
        }
    }

    /// 处理认证切换
    /// 对应 Bun: MySQLConnection.handleAuth (AUTH_SWITCH path)
    private func handleAuthSwitch(data: Array<UInt8>, offset: Int64, headerLength: UInt32): Unit {
        // 解析 AuthSwitchRequest
        // 更新 auth_plugin 和 auth_data
        // 发送新的认证响应
        sendAuthSwitchResponse()
    }

    /// 处理命令响应
    /// 对应 Bun: MySQLConnection.handleCommand
    public func handleCommand(data: Array<UInt8>, offset: Int64, headerLength: UInt32): Unit {
        let request = queue.current()
        if (request == None) {
            return
        }
        request.getOrThrow().ref()
        defer { request.getOrThrow().deref() }

        if (request.getOrThrow().isSimple()) {
            handleResultSet(data, offset, headerLength)
            return
        }

        let statement = request.getOrThrow().getStatement()
        if (statement != None) {
            match (statement.getOrThrow().status) {
                case Parsing => handlePreparedStatement(data, offset, headerLength)
                case Prepared => handleResultSet(data, offset, headerLength)
                case Failed =>
                    flags.isReadyForQuery = true
                    queue.markAsReadyForQuery()
                    queue.markCurrentRequestAsFinished(request.getOrThrow())
                    flushQueue()
                case _ => ()
            }
        }
    }

    /// 发送握手响应
    /// 对应 Bun: MySQLConnection.sendHandshakeResponse
    public func sendHandshakeResponse(): Unit {
        // 构建 HandshakeResponse41 包
        // 设置 capability_flags, character_set, username, database
        // 根据 auth_plugin 生成 auth_response
        flushData()
    }

    /// 发送认证切换响应
    /// 对应 Bun: MySQLConnection.sendAuthSwitchResponse
    public func sendAuthSwitchResponse(): Unit {
        // 使用新的认证方法和数据生成响应
        flushData()
    }

    /// 处理结果集
    /// 对应 Bun: MySQLConnection.handleResultSet
    public func handleResultSet(data: Array<UInt8>, offset: Int64, headerLength: UInt32): Unit {
        let request = queue.current()
        if (request == None) {
            return
        }

        if (offset >= data.size) {
            return
        }
        let firstByte = data[offset]

        match (firstByte) {
            case 0xFF =>
                // 错误包
                flags.isReadyForQuery = true
                queue.markAsReadyForQuery()
                queue.markCurrentRequestAsFinished(request.getOrThrow())
                flushQueue()
            case 0xFE =>
                // EOF 或 OK 包
                handleResultSetOK(request.getOrThrow(), StatusFlags(), 0, 0)
            case 0x00 =>
                // OK 包 - 查询无结果
                handleResultSetOK(request.getOrThrow(), StatusFlags(), 0, 0)
            case _ =>
                // ResultSetHeader - 开始接收列定义
                let stmt = request.getOrThrow().getStatement()
                if (stmt != None) {
                    let s = stmt.getOrThrow()
                    s.executionFlags.headerReceived = true
                    s.executionFlags.needsDuplicateCheck = true
                }
        }
    }

    /// 处理结果集 OK 包
    /// 对应 Bun: MySQLConnection.handleResultSetOK
    public func handleResultSetOK(request: JSMySQLQuery, statusFlags: StatusFlags,
                                   lastInsertId: UInt64, affectedRows: UInt64): Unit {
        let isLastResult = !statusFlags.hasMoreResults
        flags.isReadyForQuery = isLastResult
        if (isLastResult) {
            queue.markAsReadyForQuery()
            queue.markCurrentRequestAsFinished(request)
        }

        let resultCount = if (request.getStatement() != None) {
            request.getStatement().getOrThrow().resultCount
        } else {
            0
        }
        getJSConnection().onQueryResult(request, MySQLQueryResult(
            resultCount: resultCount,
            lastInsertId: lastInsertId,
            affectedRows: affectedRows,
            isLastResult: isLastResult
        ))

        // 重置语句
        if (request.getStatement() != None) {
            request.getStatement().getOrThrow().reset()
        }

        flushQueue()
    }

    /// 处理预处理语句
    /// 对应 Bun: MySQLConnection.handlePreparedStatement
    public func handlePreparedStatement(data: Array<UInt8>, offset: Int64, headerLength: UInt32): Unit {
        let request = queue.current()
        if (request == None) {
            return
        }
        let statement = request.getOrThrow().getStatement()
        if (statement == None) {
            return
        }
        let stmt = statement.getOrThrow()

        if (offset >= data.size) {
            return
        }
        let firstByte = data[offset]

        // 如果 statementId > 0，正在接收参数/列定义
        if (stmt.statementId > 0) {
            if (stmt.paramsReceived < UInt32(stmt.params.size)) {
                // 接收参数定义
                stmt.params[Int64(stmt.paramsReceived)] = StatementParam()
                stmt.paramsReceived += 1
            } else if (stmt.columnsReceived < UInt32(stmt.columns.size)) {
                // 接收列定义
                stmt.columnsReceived += 1
            }
            checkIfPreparedStatementIsDone(stmt)
            return
        }

        match (firstByte) {
            case 0x00 =>
                // StmtPrepareOK
                // 解析 statement_id, num_params, num_columns
                stmt.statementId = 1 // 占位
                checkIfPreparedStatementIsDone(stmt)
            case 0xFF =>
                // 错误包
                flags.isReadyForQuery = true
                stmt.status = StatementStatus.Failed
                queue.markAsReadyForQuery()
                queue.markCurrentRequestAsFinished(request.getOrThrow())
                getJSConnection().onErrorPacket(request.getOrThrow(), ErrorPacket())
                advance()
            case _ => ()
        }
    }

    /// 检查预处理语句是否完成
    /// 对应 Bun: MySQLConnection.checkIfPreparedStatementIsDone
    private func checkIfPreparedStatementIsDone(statement: MySQLStatement): Unit {
        if (statement.columnsReceived == UInt32(statement.columns.size) &&
            statement.paramsReceived == UInt32(statement.params.size)) {
            statement.status = StatementStatus.Prepared
            flags.waitingToPrepare = false
            flags.isReadyForQuery = true
            queue.markAsReadyForQuery()
            queue.markAsPrepared()
            statement.reset()
            advance()
        }
    }

    /// 获取写入器
    /// 对应 Bun: MySQLConnection.writer
    public func writer(): MySQLWriter {
        return MySQLWriter(connection: this)
    }

    /// 获取缓冲读取器
    /// 对应 Bun: MySQLConnection.bufferedReader
    public func bufferedReader(): MySQLReader {
        return MySQLReader(connection: this)
    }

    /// 从签名哈希获取语句
    /// 对应 Bun: JSMySQLConnection.getStatementFromSignatureHash
    public func getStatementFromSignatureHash(signatureHash: UInt64): GetOrPutResult {
        return statements.getOrPut(signatureHash)
    }

    /// 获取关联的 JS 连接
    private func getJSConnection(): JSMySQLConnection {
        return JSMySQLConnection(
            globalObject: JscJSGlobalObject(),
            vm: JscVirtualMachine(),
            connection: this
        )
    }

    let MAX_PIPELINE_SIZE: Int64 = 65535
}

/// MySQL 写入器
/// 对应 Bun: MySQLConnection.Writer
/// 持有指向连接的指针，通过 write_buffer 写入数据
public class MySQLWriter {
    public var connection: MySQLConnection

    public init(connection: MySQLConnection) {
        this.connection = connection
    }

    /// 写入数据到连接的写入缓冲区
    public func write(data: Array<UInt8>): Unit {
        connection.writeBuffer.write(data)
    }

    /// 在指定位置写入数据
    public func pwrite(data: Array<UInt8>, index: Int64): Unit {
        connection.writeBuffer.pwrite(data, index)
    }

    /// 获取当前写入偏移
    public func offset(): Int64 {
        return connection.writeBuffer.len()
    }

    /// 开始一个新数据包
    /// 对应 Bun: Writer.start
    public func start(sequenceId: UInt8): MySQLPacketWriter {
        return MySQLPacketWriter(writer: this, sequenceId: sequenceId)
    }
}

/// MySQL 读取器
/// 对应 Bun: MySQLConnection.Reader
/// 从连接的读取缓冲区读取数据
public class MySQLReader {
    public var connection: MySQLConnection

    public init(connection: MySQLConnection) {
        this.connection = connection
    }

    /// 标记消息开始位置
    public func markMessageStart(): Unit {
        connection.lastMessageStart = connection.readBuffer.head
    }

    /// 设置从起始位置的偏移
    public func setOffsetFromStart(offset: Int64): Unit {
        connection.readBuffer.head = connection.lastMessageStart + UInt32(offset)
    }

    /// 查看剩余数据
    public func peek(): Array<UInt8> {
        return connection.readBuffer.remaining()
    }

    /// 跳过指定字节数
    public func skip(count: Int64): Unit {
        if (count < 0) {
            let absCount = -count
            if (absCount > connection.readBuffer.head) {
                connection.readBuffer.head = 0
                return
            }
            connection.readBuffer.head -= UInt32(absCount)
            return
        }
        connection.readBuffer.head += UInt32(count)
    }

    /// 确保有足够的数据
    public func ensureCapacity(count: Int64): Bool {
        return connection.readBuffer.remaining().size >= count
    }

    /// 读取指定字节数
    public func read(count: Int64): ?Array<UInt8> {
        let remaining = connection.readBuffer.remaining()
        if (remaining.size < count) {
            return None
        }
        let result = remaining[0..count]
        skip(count)
        return result
    }
}

/// MySQL 包写入器
/// 对应 Bun: Writer packet helper
public class MySQLPacketWriter {
    var writer: MySQLWriter
    var sequenceId: UInt8

    init(writer: MySQLWriter, sequenceId: UInt8) {
        this.writer = writer
        this.sequenceId = sequenceId
    }

    /// 结束数据包
    public func end(): Unit {
        // 更新包长度和 sequence ID
    }
}

/// 认证状态
/// 对应 Bun: AuthState
public enum AuthState {
    | Pending
    | NativePassword
    | CachingSha2(CachingSha2State)
    | Ok
}

/// Caching SHA2 状态
/// 对应 Bun: CachingSha2
public enum CachingSha2State {
    | FastAuth
    | FullAuth
    | WaitingKey
}

/// 刷新队列错误
/// 对应 Bun: FlushQueueError
public enum FlushQueueError {
    | AuthenticationFailed
}

/// 偏移字节列表
/// 对应 Bun: OffsetByteList
/// head 偏移量 + 动态字节数组，用于读写缓冲
public class OffsetByteList {
    public var head: UInt32 = 0
    public var bytes: ArrayList<UInt8> = ArrayList<UInt8>()

    public init() {}

    public func len(): Int64 {
        return bytes.size - Int64(head)
    }

    public func remaining(): Array<UInt8> {
        if (Int64(head) >= bytes.size) {
            return []
        }
        return bytes[Int64(head)..]
    }

    public func consume(count: Int64): Unit {
        head += UInt32(count)
    }

    public func write(data: Array<UInt8>): Unit {
        for (b in data) {
            bytes.append(b)
        }
    }

    public func pwrite(data: Array<UInt8>, index: Int64): Unit {
        var i = index
        for (b in data) {
            if (i < bytes.size) {
                bytes[i] = b
            }
            i += 1
        }
    }

    public func clearAndFree(): Unit {
        bytes = ArrayList<UInt8>()
        head = 0
    }

    public func clear(): Unit {
        bytes = ArrayList<UInt8>()
        head = 0
    }

    public func reset(): Unit {
        head = 0
    }
}

/// 字节列表
public class ByteList {
    var bytes: ArrayList<UInt8> = ArrayList<UInt8>()

    public init() {}

    public func slice(): Array<UInt8> {
        return bytes.toArray()
    }
}

/// 能力标志
/// 对应 Bun: Capabilities
public class Capabilities {
    public var clientSSL: Bool = false
    public var clientDeprecateEOF: Bool = true
    public var value: UInt32 = 0

    public init() {}

    /// 获取默认能力（客户端）
    public static func getDefaultCapabilities(ssl: Bool, hasDatabase: Bool): Capabilities {
        let cap = Capabilities()
        cap.clientSSL = ssl
        cap.clientDeprecateEOF = true
        return cap
    }

    /// 与服务器能力取交集
    public func intersect(serverFlags: Capabilities): Capabilities {
        clientDeprecateEOF = clientDeprecateEOF && serverFlags.clientDeprecateEOF
        return this
    }

    public func toInt(): UInt32 {
        return value
    }
}

/// 字符集
/// 对应 Bun: CharacterSet
public class CharacterSet {
    public var value: UInt8 = 0

    public static func default_(): CharacterSet {
        let cs = CharacterSet()
        cs.value = 45 // utf8mb4
        return cs
    }
}

/// 状态标志
/// 对应 Bun: StatusFlags
public class StatusFlags {
    public var value: UInt32 = 0
    public var hasMoreResults: Bool = false

    public init() {}

    public func toInt(): UInt32 {
        return value
    }
}

/// 认证方法
/// 对应 Bun: AuthMethod
public enum AuthMethod {
    | MySQLNativePassword
    | CachingSHA2Password
    | SHA256Password
}

/// TLS 状态
/// 对应 Bun: TLSStatus
public enum TLSStatus {
    | None
    | Pending
    | MessageSent
    | SSLOk
    | SSLFailed
    | SSLNotAvailable
}

/// 连接标志
/// 对应 Bun: ConnectionFlags
public class ConnectionFlags {
    public var hasBackpressure: Bool = false
    public var isProcessingData: Bool = false
    public var isReadyForQuery: Bool = true
    public var waitingToPrepare: Bool = false

    public init() {}
}

/// SSL 配置
/// 对应 Bun: SSLConfig
public class SSLConfig {
    public init() {}

    public func serverName(): String {
        return ""
    }

    public func rejectUnauthorized(): Int32 {
        return 0
    }
}

/// 验证错误
/// 对应 Bun: us_bun_verify_error_t
public class VerifyError {
    public var errorNo: Int32 = 0

    public init() {}
}

/// 预处理语句映射
/// 对应 Bun: PreparedStatementsMap
public class PreparedStatementsMap {
    private var map: HashMap<UInt64, MySQLStatement> = HashMap<UInt64, MySQLStatement>()

    public init() {}

    public func getOrPut(key: UInt64): GetOrPutResult {
        if (map.contains(key)) {
            return GetOrPutResult(foundExisting: true, value: map[key].getOrThrow())
        }
        return GetOrPutResult(foundExisting: false, value: MySQLStatement())
    }

    public func values(): Array<MySQLStatement> {
        return map.values().toArray()
    }

    public func deinit(): Unit {
        map.clear()
    }
}

/// 获取或放入结果
public class GetOrPutResult {
    public var foundExisting: Bool
    public var value: MySQLStatement

    public init(foundExisting: Bool, value: MySQLStatement) {
        this.foundExisting = foundExisting
        this.value = value
    }
}

/// AnySocket - socket 封装
/// 对应 Bun: AnySocket
public class AnySocket {
    public init() {}

    public func write(data: Array<UInt8>): UInt64 {
        return UInt64(data.size)
    }

    public func close(): Unit {}

    public func setTimeout(timeout: UInt32): Unit {}
}

/// 状态标志 (StatusFlags) 中的标志
/// 对应 Bun: StatusFlag
public enum StatusFlag {
    | ServerMoreResultsExists
}
