// MySQL 连接核心
// 严格翻译自: src/sql_jsc/mysql/MySQLConnection.zig
package bao_runtime.sql.mysql

import bao_core.*
import bao_runtime.sql.shared.*

/// MySQL 最大管道大小
public let MAX_PIPELINE_SIZE: Int64 = 1024 * 1024  // 1MB

/// MySQL 认证状态
/// 对应 Bun: MySQLConnection.AuthState
public enum AuthState {
    | pending                  // 等待开始
    | native_password          // mysql_native_password 认证中
    | caching_sha2(CachingSHA2State)  // caching_sha2_password 认证中
    | ok                       // 认证完成
}

/// caching_sha2_password 认证子状态
/// 对应 Bun: AuthState.CachingSHA2
public enum CachingSHA2State {
    | fast_auth       // 快速认证
    | full_auth       // 完整认证
    | waiting_key     // 等待公钥
}

/// MySQL 连接
/// 对应 Bun: MySQLConnection
/// 管理到 MySQL 服务器的 TCP/TLS 连接，处理认证和协议状态
public class MySQLConnection {
    /// 连接状态
    public var status: ConnectionState
    /// 写缓冲区
    public var writeBuffer: Array<UInt8>
    /// 读缓冲区
    public var readBuffer: Array<UInt8>
    /// 上一个消息起始偏移
    public var lastMessageStart: Int64
    /// 包序列号
    public var sequenceId: UInt8

    /// 请求队列
    public var queue: MySQLRequestQueue
    /// 预编译语句映射
    public var statements: HashMap<UInt32, MySQLStatement>

    /// 服务器版本
    public var serverVersion: Array<UInt8>
    /// 连接 ID
    public var connectionId: UInt32
    /// 能力标志
    public var capabilities: Capabilities
    /// 字符集
    public var characterSet: CharacterSet
    /// 状态标志
    public var statusFlags: StatusFlags

    /// 认证插件
    public var authPlugin: ?AuthMethod
    /// 认证状态
    public var authState: AuthState
    /// 认证数据 (nonce)
    public var authData: Array<UInt8>

    /// 数据库名
    public var database: String
    /// 用户名
    public var user: String
    /// 密码
    public var password: String

    /// TLS 状态
    public var tlsStatus: TLSStatus
    /// SSL 模式
    public var sslMode: SSLMode
    /// 连接标志
    public var flags: ConnectionFlags

    public init() {
        status = ConnectionState.disconnected
        writeBuffer = Array<UInt8>()
        readBuffer = Array<UInt8>()
        lastMessageStart = 0
        sequenceId = 0
        queue = MySQLRequestQueue()
        statements = HashMap<UInt32, MySQLStatement>()
        serverVersion = Array<UInt8>()
        connectionId = 0
        capabilities = Capabilities()
        characterSet = CharacterSet.DEFAULT
        statusFlags = StatusFlags()
        authPlugin = None
        authState = AuthState.pending
        authData = Array<UInt8>()
        database = ""
        user = ""
        password = ""
        tlsStatus = TLSStatus.none
        sslMode = SSLMode.disable
        flags = ConnectionFlags()
    }

    /// 初始化连接
    /// 对应 Bun: MySQLConnection.init
    public init(database: String, username: String, password: String, sslMode: SSLMode) {
        this.database = database
        user = username
        this.password = password
        this.sslMode = sslMode
        status = ConnectionState.disconnected
        writeBuffer = Array<UInt8>()
        readBuffer = Array<UInt8>()
        lastMessageStart = 0
        sequenceId = 0
        queue = MySQLRequestQueue()
        statements = HashMap<UInt32, MySQLStatement>()
        serverVersion = Array<UInt8>()
        connectionId = 0
        capabilities = Capabilities()
        characterSet = CharacterSet.DEFAULT
        statusFlags = StatusFlags()
        authPlugin = None
        authState = AuthState.pending
        authData = Array<UInt8>()
        tlsStatus = if (sslMode != SSLMode.disable) TLSStatus.pending else TLSStatus.none
        flags = ConnectionFlags()
    }

    /// 是否能够管道化
    /// 对应 Bun: MySQLConnection.canPipeline
    public func canPipeline(): Bool {
        return queue.canPipeline()
    }

    /// 是否能够预编译查询
    /// 对应 Bun: MySQLConnection.canPrepareQuery
    public func canPrepareQuery(): Bool {
        return queue.canPrepareQuery()
    }

    /// 是否能够执行查询
    /// 对应 Bun: MySQLConnection.canExecuteQuery
    public func canExecuteQuery(): Bool {
        return queue.canExecuteQuery()
    }

    /// 是否能够写入
    /// 对应 Bun: MySQLConnection.isAbleToWrite
    public func isAbleToWrite(): Bool {
        return status == ConnectionState.connected &&
            !flags.hasBackpressure &&
            writeBuffer.size < MAX_PIPELINE_SIZE
    }

    /// 是否正在处理数据
    /// 对应 Bun: MySQLConnection.isProcessingData
    public func isProcessingData(): Bool {
        return flags.isProcessingData
    }

    /// 是否有背压
    /// 对应 Bun: MySQLConnection.hasBackpressure
    public func hasBackpressure(): Bool {
        return flags.hasBackpressure
    }

    /// 重置背压
    /// 对应 Bun: MySQLConnection.resetBackpressure
    public func resetBackpressure(): Unit {
        flags.hasBackpressure = false
    }

    /// 是否能够刷新
    /// 对应 Bun: MySQLConnection.canFlush
    public func canFlush(): Bool {
        let hasData = writeBuffer.size > 0
        let hasPending = queue.current() != None
        return !flags.hasBackpressure &&
            status == ConnectionState.connected &&
            (hasData || hasPending)
    }

    /// 是否空闲
    /// 对应 Bun: MySQLConnection.isIdle
    public func isIdle(): Bool {
        return queue.current() == None && writeBuffer.size == 0
    }

    /// 是否活跃
    /// 对应 Bun: MySQLConnection.isActive
    public func isActive(): Bool {
        if (status == ConnectionState.disconnected || status == ConnectionState.failed) {
            return false
        }
        return true
    }

    /// 是否已连接
    /// 对应 Bun: MySQLConnection.isConnected
    public func isConnected(): Bool {
        return status == ConnectionState.connected
    }

    /// 入队请求
    /// 对应 Bun: MySQLConnection.enqueueRequest
    public func enqueueRequest(request: MySQLQueryRef): Unit {
        queue.add(request)
    }

    /// 关闭连接
    /// 对应 Bun: MySQLConnection.close
    public func close(): Unit {
        writeBuffer = Array<UInt8>()
        status = ConnectionState.disconnected
    }

    /// 清理资源
    /// 对应 Bun: MySQLConnection.cleanup
    public func cleanup(): Unit {
        queue = MySQLRequestQueue()
        statements = HashMap<UInt32, MySQLStatement>()
        writeBuffer = Array<UInt8>()
        readBuffer = Array<UInt8>()
        serverVersion = Array<UInt8>()
        authData = Array<UInt8>()
    }

    /// 发送握手响应
    /// 对应 Bun: MySQLConnection.sendHandshakeResponse
    public func sendHandshakeResponse(): Unit {
        let response = HandshakeResponse41()
        response.capabilityFlags = capabilities
        response.maxPacketSize = 0xFFFFFF
        response.characterSet = characterSet
        response.username = SQLData.fromString(user)
        response.authPluginName = SQLData.fromString(
            if (let Some(plugin) <- authPlugin) {
                match (plugin) {
                    case mysql_native_password => "mysql_native_password"
                    case caching_sha2_password => "caching_sha2_password"
                    case sha256_password => "sha256_password"
                }
            } else {
                "mysql_native_password"
            }
        )
        response.sequenceId = sequenceId
        response.database = SQLData.fromString(database)

        let writer = MySQLPacketWriter()
        response.write(writer)
        // 将 writer 的缓冲区追加到 writeBuffer
        for (b in writer.getBuffer()) {
            writeBuffer.append(b)
        }
    }

    /// 读取并处理数据
    /// 对应 Bun: MySQLConnection.readAndProcessData
    public func readAndProcessData(data: Array<UInt8>): Unit {
        flags.isProcessingData = true
        defer {
            flags.isProcessingData = false
        }

        let reader = MySQLPacketReader(data)
        processPackets(reader)
    }

    /// 处理数据包
    /// 对应 Bun: MySQLConnection.processPackets
    public func processPackets(reader: MySQLPacketReader): Unit {
        while (true) {
            reader.markMessageStart()

            // 读取包头
            let headerData = reader.peek()
            if (headerData.size < 4) {
                return  // ShortRead
            }
            let header = PacketHeader.decode(headerData)
            if (let Some(h) <- header) {
                let headerLength = h.length
                let packetLength = Int64(headerLength) + PacketHeader.SIZE

                if (reader.peek().size < packetLength) {
                    return  // ShortRead, 等待更多数据
                }

                // 跳过包头
                reader.skip(4)

                // 更新序列号
                sequenceId = h.sequenceId + 1

                // 分发处理
                processOnePacket(reader, h)
            } else {
                return
            }
        }
    }

    /// 处理单个数据包
    func processOnePacket(reader: MySQLPacketReader, header: PacketHeader): Unit {
        // 根据连接状态分发
        match (status) {
            case connecting => handleHandshake(reader, header)
            case authenticating => handleAuthResponse(reader, header)
            case connected => handleQueryResponse(reader, header)
            case _ => {}
        }
    }

    /// 处理握手
    func handleHandshake(reader: MySQLPacketReader, header: PacketHeader): Unit {
        let handshake = HandshakeV10()
        handshake.decode(reader)

        serverVersion = handshake.serverVersion.slice()
        connectionId = handshake.connectionId
        capabilities = handshake.capabilityFlags
        characterSet = handshake.characterSet
        statusFlags = handshake.statusFlags

        // 提取认证数据
        authData = Array<UInt8>()
        for (b in handshake.authPluginDataPart1) {
            authData.append(b)
        }
        for (b in handshake.authPluginDataPart2) {
            authData.append(b)
        }

        // 确定认证方法
        let pluginName = handshake.authPluginName.slice()
        var nameStr = ""
        for (b in pluginName) {
            nameStr += String(Char(b))
        }
        authPlugin = AuthMethod.fromString(nameStr)
        if (authPlugin == None) {
            authPlugin = AuthMethod.mysql_native_password
        }

        // 限制客户端能力
        let defaultCaps = Capabilities.getDefaultCapabilities(
            sslMode != SSLMode.disable,
            database.size > 0
        )
        capabilities = capabilities.intersect(defaultCaps)
        capabilities.reject()

        // 发送 SSL 请求 (如需要)
        if (sslMode != SSLMode.disable && capabilities.CLIENT_SSL) {
            tlsStatus = TLSStatus.pending
            let sslReq = SSLRequest()
            sslReq.capabilityFlags = capabilities
            sslReq.hasConnectionAttributes = false
            let writer = MySQLPacketWriter()
            sslReq.write(writer)
            for (b in writer.getBuffer()) {
                writeBuffer.append(b)
            }
        } else {
            // 直接发送握手响应
            status = ConnectionState.authenticating
            sendHandshakeResponse()
        }

        handshake.deinit()
    }

    /// 处理认证响应
    func handleAuthResponse(reader: MySQLPacketReader, header: PacketHeader): Unit {
        let firstByte = reader.readInt8()
        reader.skip(-1)  // 回退

        if (firstByte == 0x00) {
            // OK Packet - 认证成功
            let ok = OKPacket()
            ok.packetSize = header.length
            ok.decode(reader)
            statusFlags = ok.statusFlags
            status = ConnectionState.connected
            ok.deinit()
        } else if (firstByte == 0xff) {
            // Error Packet - 认证失败
            let err = ErrorPacket()
            err.decode(reader)
            status = ConnectionState.failed
            err.deinit()
        } else if (firstByte == 0xfe) {
            // Auth Switch Request
            let authSwitch = AuthSwitchRequest()
            authSwitch.packetSize = header.length
            authSwitch.decode(reader)

            // 切换认证方法
            let pluginNameSlice = authSwitch.pluginName.slice()
            var nameStr = ""
            for (b in pluginNameSlice) {
                nameStr += String(Char(b))
            }
            let newPlugin = AuthMethod.fromString(nameStr)
            if (let Some(plugin) <- newPlugin) {
                authPlugin = plugin
            }

            // 用新 nonce 生成 scramble
            let newNonce = authSwitch.pluginData.slice()
            if (let Some(plugin) <- authPlugin) {
                let scramble = MySQLAuth.scramble(plugin, password.toArray(), newNonce)
                if (let Some(s) <- scramble) {
                    let response = AuthSwitchResponse()
                    response.authResponse = SQLData.fromTemporary(s)
                    let writer = MySQLPacketWriter()
                    writer.start(sequenceId)
                    response.write(writer)
                    writer.endPacket()
                    for (b in writer.getBuffer()) {
                        writeBuffer.append(b)
                    }
                }
            }

            authSwitch.deinit()
        } else if (firstByte == 0x01) {
            // caching_sha2_password 快速认证继续
            let status = reader.readInt8()  // 0x03 = success, 0x04 = continue
            if (status == 0x03) {
                // 认证成功
                status = ConnectionState.connected
            }
            // 0x04 需要完整认证流程
        }
    }

    /// 处理查询响应
    func handleQueryResponse(reader: MySQLPacketReader, header: PacketHeader): Unit {
        let firstByte = reader.readInt8()
        reader.skip(-1)

        if (firstByte == 0x00 || firstByte == 0xfe) {
            // OK 或 EOF
            let ok = OKPacket()
            ok.packetSize = header.length
            ok.decode(reader)
            statusFlags = ok.statusFlags

            // 通知当前请求
            if (let Some(current) <- queue.current()) {
                current.onOK(ok.affectedRows, ok.lastInsertId)
                queue.advance()
            }
            ok.deinit()
        } else if (firstByte == 0xff) {
            // Error
            let err = ErrorPacket()
            err.decode(reader)
            if (let Some(current) <- queue.current()) {
                current.onError(err)
                queue.advance()
            }
            err.deinit()
        } else {
            // ResultSet header
            let resultSetHeader = ResultSetHeader()
            resultSetHeader.decode(reader)
            // 后续会收到 ColumnDefinition41 包
        }
    }
}

/// MySQL 查询引用 (用于请求队列)
public class MySQLQueryRef {
    public var query: String
    public var status: QueryStatus

    public init() {
        query = ""
        status = QueryStatus.pending
    }

    public init(query: String) {
        this.query = query
        status = QueryStatus.pending
    }

    public func isPending(): Bool {
        return status == QueryStatus.pending
    }

    public func isBeingPrepared(): Bool {
        return status == QueryStatus.binding
    }

    public func onOK(affectedRows: UInt64, lastInsertId: UInt64): Unit {
        status = QueryStatus.success
    }

    public func onError(err: ErrorPacket): Unit {
        status = QueryStatus.fail
    }
}

/// MySQL 请求队列
/// 对应 Bun: MySQLRequestQueue
public class MySQLRequestQueue {
    public var requests: ArrayList<MySQLQueryRef>
    public var currentIndex: Int64

    public init() {
        requests = ArrayList<MySQLQueryRef>()
        currentIndex = 0
    }

    public func add(request: MySQLQueryRef): Unit {
        requests.append(request)
    }

    public func current(): ?MySQLQueryRef {
        if (currentIndex < requests.size) {
            return requests[currentIndex]
        }
        return None
    }

    public func advance(): Unit {
        if (currentIndex < requests.size) {
            currentIndex += 1
        }
    }

    public func canPipeline(): Bool {
        return true
    }

    public func canPrepareQuery(): Bool {
        return true
    }

    public func canExecuteQuery(): Bool {
        return true
    }

    public func clean(): Unit {
        requests = ArrayList<MySQLQueryRef>()
        currentIndex = 0
    }

    public func deinit(): Unit {
        clean()
    }
}

/// MySQL 预编译语句
/// 对应 Bun: MySQLStatement
public class MySQLStatement {
    /// 语句 ID
    public var statementId: UInt32
    /// 参数数量
    public var numParams: UInt16
    /// 列数量
    public var numColumns: UInt16
    /// 参数类型
    public var paramTypes: Array<MySQLParam>
    /// 列定义
    public var columns: Array<ColumnDefinition41>
    /// SQL 文本
    public var query: String

    public init() {
        statementId = 0
        numParams = 0
        numColumns = 0
        paramTypes = Array<MySQLParam>()
        columns = Array<ColumnDefinition41>()
        query = ""
    }

    public init(statementId: UInt32, numParams: UInt16, numColumns: UInt16, query: String) {
        this.statementId = statementId
        this.numParams = numParams
        this.numColumns = numColumns
        this.query = query
        paramTypes = Array<MySQLParam>()
        columns = Array<ColumnDefinition41>()
    }

    /// 释放资源
    public func deinit(): Unit {
        for (col in columns) {
            col.deinit()
        }
        columns = Array<ColumnDefinition41>()
        paramTypes = Array<MySQLParam>()
    }
}
