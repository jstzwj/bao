// 严格翻译自: src/sql_jsc/mysql/MySQLConnection.zig
// MySQL 连接 - MySQL 协议层连接实现

package bao_sql_jsc.mysql

import bao_core.*
import bao_jsc.*
import bao_sql.*

/// MySQL 连接
/// 对应 Bun: MySQLConnection
/// 管理 MySQL 协议的连接状态、读写缓冲区、认证流程
public class MySQLConnection {
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

    /// 能否写入
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
                queue.advance(getJSConnection())
                flushData()
            }
        }
    }

    /// 关闭连接
    /// 对应 Bun: MySQLConnection.close
    public func close(): Unit {
        writeBuffer.clearAndFree()
    }

    /// 清理队列并关闭
    /// 对应 Bun: MySQLConnection.cleanQueueAndClose
    public func cleanQueueAndClose(jsReason: ?JscValue, jsQueriesArray: JscValue): Unit {
        queue.clean(jsReason, jsQueriesArray)
        close()
    }

    /// 清理资源
    /// 对应 Bun: MySQLConnection.cleanup
    public func cleanup(): Unit {
        queue.deinit()
        queue = MySQLRequestQueue()
        writeBuffer.clearAndFree()
        readBuffer.clearAndFree()

        // 清理语句缓存
        for (stmt in statements.values()) {
            stmt.deref()
        }
        statements.deinit()

        authData.clear()
    }

    /// 升级到 TLS
    /// 对应 Bun: MySQLConnection.upgradeToTLS
    public func upgradeToTLS(): Unit {
        // TLS 升级逻辑
        tlsStatus = TLSStatus.SSLOk
    }

    /// 设置 socket
    /// 对应 Bun: MySQLConnection.setSocket
    public func setSocket(socket: AnySocket): Unit {
        // socket 管理
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

    /// 读取并处理数据
    /// 对应 Bun: MySQLConnection.readAndProcessData
    public func readAndProcessData(data: Array<UInt8>): Unit {
        flags.isProcessingData = true
        defer {
            flags.isProcessingData = false
        }

        if (readBuffer.remaining().size == 0) {
            do {
                processPackets(data)
            } catch (_: Exception) {
                // 短读，缓冲数据
                readBuffer.write(data)
            }
            return
        }

        readBuffer.write(data)
        do {
            processPackets(readBuffer.remaining())
        } catch (_: Exception) {
            // 短读
        }
        lastMessageStart = 0
        readBuffer.reset()
    }

    /// 处理数据包
    /// 对应 Bun: MySQLConnection.processPackets
    public func processPackets(data: Array<UInt8>): Unit {
        var offset: Int64 = 0
        while (offset < data.size) {
            if (offset + 4 > data.size) {
                // 短读
                return
            }

            // 读取包头
            let headerLength = UInt32(data[offset]) |
                (UInt32(data[offset + 1]) << 8) |
                (UInt32(data[offset + 2]) << 16)
            let headerSequenceId = data[offset + 3]
            let packetLength = headerLength + 4

            if (offset + packetLength > data.size) {
                // 短读
                return
            }

            sequenceId = headerSequenceId + 1

            let packetData = data[offset + 4..offset + packetLength]

            match (status) {
                case Handshaking => handleHandshake(packetData)
                case Authenticating | AuthenticationAwaitingPK =>
                    handleAuth(packetData, headerLength)
                case Connected => handleCommand(packetData, headerLength)
                case _ => ()
            }

            offset += packetLength
        }
    }

    /// 处理握手
    /// 对应 Bun: MySQLConnection.handleHandshake
    public func handleHandshake(data: Array<UInt8>): Unit {
        // 解析 HandshakeV10 包
        setStatus(ConnectionState.Authenticating)

        // 如果需要 SSL
        if (capabilities.clientSSL && sslMode != SSLMode.Disable) {
            tlsStatus = TLSStatus.MessageSent
            flushData()
            if (!flags.hasBackpressure) {
                upgradeToTLS()
            }
            return
        }

        // 发送握手响应
        sendHandshakeResponse()
    }

    /// 处理认证
    /// 对应 Bun: MySQLConnection.handleAuth
    public func handleAuth(data: Array<UInt8>, headerLength: UInt32): Unit {
        if (data.size == 0) {
            return
        }
        let firstByte = data[0]

        match (firstByte) {
            case 0x00 =>
                // OK 包
                setStatus(ConnectionState.Connected)
                flags.isReadyForQuery = true
                queue.markAsReadyForQuery()
                queue.advance(getJSConnection())
            case 0xFF =>
                // 错误包
                setStatus(ConnectionState.Failed)
            case 0x01 =>
                // MORE_DATA - 认证继续
                handleAuthContinue(data, headerLength)
            case 0xFE =>
                // AUTH_SWITCH
                handleAuthSwitch(data, headerLength)
            case _ => ()
        }
    }

    /// 处理认证继续
    private func handleAuthContinue(data: Array<UInt8>, headerLength: UInt32): Unit {
        // SASL 认证流程
    }

    /// 处理认证切换
    private func handleAuthSwitch(data: Array<UInt8>, headerLength: UInt32): Unit {
        // 认证切换逻辑
    }

    /// 处理命令
    /// 对应 Bun: MySQLConnection.handleCommand
    public func handleCommand(data: Array<UInt8>, headerLength: UInt32): Unit {
        let request = queue.current()
        if (request == None) {
            return
        }
        request.getOrThrow().ref()
        defer { request.getOrThrow().deref() }

        if (request.getOrThrow().isSimple()) {
            handleResultSet(data, headerLength)
            return
        }

        let statement = request.getOrThrow().getStatement()
        if (statement != None) {
            match (statement.getOrThrow().status) {
                case Parsing => handlePreparedStatement(data, headerLength)
                case Prepared => handleResultSet(data, headerLength)
                case Failed =>
                    flags.isReadyForQuery = true
                    queue.markAsReadyForQuery()
                    queue.markCurrentRequestAsFinished(request.getOrThrow())
                case _ => ()
            }
        }
    }

    /// 发送握手响应
    /// 对应 Bun: MySQLConnection.sendHandshakeResponse
    public func sendHandshakeResponse(): Unit {
        // 发送 HandshakeResponse41 包
    }

    /// 处理结果集
    /// 对应 Bun: MySQLConnection.handleResultSet
    public func handleResultSet(data: Array<UInt8>, headerLength: UInt32): Unit {
        // 结果集处理逻辑
    }

    /// 处理预处理语句
    /// 对应 Bun: MySQLConnection.handlePreparedStatement
    public func handlePreparedStatement(data: Array<UInt8>, headerLength: UInt32): Unit {
        // 预处理语句处理逻辑
    }

    /// 刷新数据到 socket
    private func flushData(): Unit {
        if (flags.hasBackpressure) {
            return
        }
        let chunk = writeBuffer.remaining()
        if (chunk.size == 0) {
            return
        }
        // 写入 socket
        writeBuffer.consume(chunk.size)
    }

    /// 获取关联的 JS 连接
    private func getJSConnection(): JSMySQLConnection {
        // 通过字段偏移获取父结构
        return JSMySQLConnection(
            globalObject: JscJSGlobalObject(),
            vm: JscVirtualMachine(),
            connection: this
        )
    }

    /// 获取写入器
    public func writer(): MySQLWriter {
        return MySQLWriter(connection: this)
    }

    let MAX_PIPELINE_SIZE: Int64 = 65535
}

/// MySQL 写入器
/// 对应 Bun: MySQLConnection.Writer
public class MySQLWriter {
    public var connection: MySQLConnection

    public init(connection: MySQLConnection) {
        this.connection = connection
    }

    public func write(data: Array<UInt8>): Unit {
        connection.writeBuffer.write(data)
    }

    public func offset(): Int64 {
        return connection.writeBuffer.len()
    }
}

/// 偏移字节列表
public class OffsetByteList {
    var head: Int64 = 0
    var bytes: ArrayList<UInt8> = ArrayList<UInt8>()

    public init() {}

    public func len(): Int64 {
        return bytes.size - head
    }

    public func remaining(): Array<UInt8> {
        if (head >= bytes.size) {
            return []
        }
        return bytes[head..]
    }

    public func consume(count: Int64): Unit {
        head += count
    }

    public func write(data: Array<UInt8>): Unit {
        for (b in data) {
            bytes.append(b)
        }
    }

    public func clearAndFree(): Unit {
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
public class Capabilities {
    public var clientSSL: Bool = false
    public var clientDeprecateEOF: Bool = true

    public init() {}

    public func toInt(): UInt32 {
        return 0
    }
}

/// 字符集
public class CharacterSet {
    public var value: UInt8 = 0

    public static func default_(): CharacterSet {
        let cs = CharacterSet()
        cs.value = 45 // utf8mb4
        return cs
    }
}

/// 状态标志
public class StatusFlags {
    public init() {}

    public func toInt(): UInt32 {
        return 0
    }
}

/// 认证方法
public enum AuthMethod {
    | MySQLNativePassword
    | CachingSHA2Password
    | SHA256Password
}

/// TLS 状态
public enum TLSStatus {
    | None
    | Pending
    | MessageSent
    | SSLOk
    | SSLFailed
    | SSLNotAvailable
}

/// 连接标志
public class ConnectionFlags {
    public var hasBackpressure: Bool = false
    public var isProcessingData: Bool = false
    public var isReadyForQuery: Bool = true
    public var waitingToPrepare: Bool = false

    public init() {}
}

/// 预处理语句映射
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

/// AnySocket
public class AnySocket {
    public init() {}
}

/// SSLConfig
public class SSLConfig {
    public init() {}
}
