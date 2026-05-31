// PostgreSQL 请求调度 JSC 绑定
// 严格翻译自: bun/src/sql_jsc/postgres/PostgresRequest.zig
//   pub fn writeBind(...), pub fn writeQuery(...), pub fn onData(...)
package bao_runtime.sql.postgresql

import bao_runtime.sql.shared.*

/// PostgreSQL 请求调度器
/// 对应 Bun PostgresRequest (文件级函数)
/// 负责构建和发送 PostgreSQL 协议消息 (Bind, Parse, Describe, Execute)
public class PostgresRequestDispatcher {
    /// PostgreSQL wire 协议最大参数数量 (16-bit)
    public static let MAX_PARAMETERS: Int64 = 65535

    /// 写入 Bind 消息
    /// 对应 Bun PostgresRequest.writeBind()
    ///
    /// 将 JS 绑定参数编码为 PostgreSQL Bind 消息
    public static func writeBind(
        name: String,
        cursorName: String,
        values: Array<PGValue>,
        parameterFields: Array<UInt32>,
        resultFields: Array<FieldDescription>,
        writer: ProtocolWriter
    ): Bool {
        // 1. 写入 Bind 消息头
        writer.beginMessage(UInt8('B'))

        // 2. 写入目标 portal 名称和语句名称
        writer.writeNullTerminatedString(cursorName)
        writer.writeNullTerminatedString(name)

        // 3. 写入参数格式代码
        if (parameterFields.size > MAX_PARAMETERS) {
            return false
        }
        let paramLen = UInt16(parameterFields.size)
        writer.writeUInt16(paramLen)

        for (i in 0..parameterFields.size) {
            let parameterField = parameterFields[i]
            let isCustomType = parameterField > UInt32(UInt16.MaxValue)
            let tag = if (isCustomType) {
                PGTag.Text
            } else {
                PGTag.fromOID(UInt16(parameterField))
            }

            // 如果值为字符串，使用文本格式
            let forceText = isCustomType || (
                tag.isBinaryFormatSupported() &&
                i < values.size &&
                isStringValue(values[i])
            )

            if (forceText) {
                writer.writeUInt16(0) // 文本格式
            } else {
                writer.writeUInt16(tag.formatCode())
            }
        }

        // 4. 写入参数值
        writer.writeUInt16(paramLen)
        for (i in 0..values.size) {
            if (i >= parameterFields.size) {
                break
            }
            let parameterField = parameterFields[i]
            let isCustomType = parameterField > UInt32(UInt16.MaxValue)
            let tag = if (isCustomType) PGTag.Text else PGTag.fromOID(UInt16(parameterField))

            match (values[i]) {
                case PGValue.Null => {
                    writer.writeInt32(-1) // NULL
                }
                case PGValue.Bool(b) => {
                    let len = writer.reserveLength()
                    writer.writeUInt8(if (b) 1 else 0)
                    len.writeExcludingSelf()
                }
                case PGValue.Int32(v) => {
                    let len = writer.reserveLength()
                    writer.writeInt32(v)
                    len.writeExcludingSelf()
                }
                case PGValue.Int64(v) => {
                    let len = writer.reserveLength()
                    writer.writeInt64(v)
                    len.writeExcludingSelf()
                }
                case PGValue.Float64(v) => {
                    let len = writer.reserveLength()
                    writer.writeFloat64(v)
                    len.writeExcludingSelf()
                }
                case PGValue.Text(s) => {
                    let len = writer.reserveLength()
                    writer.writeString(s)
                    len.writeExcludingSelf()
                }
                case PGValue.Bytes(b) => {
                    let len = writer.reserveLength()
                    writer.writeBytes(b)
                    len.writeExcludingSelf()
                }
                case _ => {
                    // 默认作为字符串处理
                    let s = values[i].toString()
                    let len = writer.reserveLength()
                    writer.writeString(s)
                    len.writeExcludingSelf()
                }
            }
        }

        // 5. 写入结果格式代码
        var anyNonTextFields = false
        for (field in resultFields) {
            if (field.typeTag().isBinaryFormatSupported()) {
                anyNonTextFields = true
                break
            }
        }

        if (anyNonTextFields) {
            writer.writeUInt16(UInt16(resultFields.size))
            for (field in resultFields) {
                writer.writeUInt16(field.typeTag().formatCode())
            }
        } else {
            writer.writeUInt16(0)
        }

        writer.endMessage()
        return true
    }

    /// 写入 Parse + Describe 消息
    /// 对应 Bun PostgresRequest.writeQuery()
    public static func writeQuery(
        query: String,
        name: String,
        params: Array<UInt32>,
        writer: ProtocolWriter
    ): Bool {
        // 写入 Parse 消息
        writer.beginMessage(UInt8('P'))
        writer.writeNullTerminatedString(name)
        writer.writeNullTerminatedString(query)
        writer.writeUInt16(UInt16(params.size))
        for (p in params) {
            writer.writeUInt32(p)
        }
        writer.endMessage()

        // 写入 Describe 消息
        writer.beginMessage(UInt8('D'))
        writer.writeUInt8(UInt8('S')) // Statement
        writer.writeNullTerminatedString(name)
        writer.endMessage()

        return true
    }

    /// 写入 Execute + Flush + Sync
    /// 用于立即执行预处理语句
    public static func prepareAndQueryWithSignature(
        query: String,
        values: Array<PGValue>,
        signature: PGSignature,
        writer: ProtocolWriter
    ): Bool {
        // Parse + Describe
        if (!writeQuery(query, signature.preparedStatementName, signature.fields, writer)) {
            return false
        }
        // Bind
        if (!writeBind(signature.preparedStatementName, "", values, signature.fields, Array<FieldDescription>(), writer)) {
            return false
        }
        // Execute
        writeExecute(signature.preparedStatementName, writer)
        writeFlushAndSync(writer)
        return true
    }

    /// 绑定并执行已有的预处理语句
    /// 对应 Bun PostgresRequest.bindAndExecute()
    public static func bindAndExecute(
        statement: PGStatementRef,
        values: Array<PGValue>,
        columns: Array<PGValue>,
        writer: ProtocolWriter
    ): Bool {
        if (!writeBind(
            statement.signature.preparedStatementName, "",
            values, statement.parameters, statement.fields, writer
        )) {
            return false
        }
        writeExecute(statement.signature.preparedStatementName, writer)
        writeFlushAndSync(writer)
        return true
    }

    /// 原子性发送 Parse + Describe + Bind + Execute + Flush + Sync
    /// 对应 Bun PostgresRequest.parseAndBindAndExecute()
    /// 用于无名预处理语句，确保 PgBouncer 不会拆分消息
    public static func parseAndBindAndExecute(
        query: String,
        statement: PGStatementRef,
        values: Array<PGValue>,
        includeDescribe: Bool,
        writer: ProtocolWriter
    ): Bool {
        let name = statement.signature.preparedStatementName

        // Parse
        writer.beginMessage(UInt8('P'))
        writer.writeNullTerminatedString(name)
        writer.writeNullTerminatedString(query)
        writer.writeUInt16(UInt16(statement.signature.fields.size))
        for (f in statement.signature.fields) {
            writer.writeUInt32(f)
        }
        writer.endMessage()

        // Describe (首次执行需要)
        if (includeDescribe) {
            writer.beginMessage(UInt8('D'))
            writer.writeUInt8(UInt8('S'))
            writer.writeNullTerminatedString(name)
            writer.endMessage()
        }

        // Bind
        let paramFields = if (statement.parameters.size > 0) {
            statement.parameters
        } else {
            statement.signature.fields
        }
        writeBind(name, "", values, paramFields, statement.fields, writer)

        // Execute
        writeExecute(name, writer)
        writeFlushAndSync(writer)
        return true
    }

    /// 执行简单查询
    /// 对应 Bun PostgresRequest.executeQuery()
    public static func executeQuery(
        query: String,
        writer: ProtocolWriter
    ): Bool {
        writer.beginMessage(UInt8('Q'))
        writer.writeNullTerminatedString(query)
        writer.endMessage()
        writeFlushAndSync(writer)
        return true
    }

    // ========================================================================
    // 消息处理
    // ========================================================================

    /// 处理从服务器接收到的数据
    /// 对应 Bun PostgresRequest.onData()
    ///
    /// 参数:
    ///   connection - PostgreSQL 连接
    ///   reader - 协议数据读取器
    public static func onData(connection: PGConnectionRef, reader: ProtocolReader): Bool {
        while (true) {
            reader.markMessageStart()
            let c = reader.readUInt8()
            match (c) {
                case UInt8('D') => connection.onDataRow(reader)
                case UInt8('d') => connection.onCopyData(reader)
                case UInt8('S') => {
                    if (connection.tlsStatus == TLSStatus.MessageSent(8)) {
                        connection.tlsStatus = TLSStatus.SSLOk
                        connection.setupTLS()
                        return true
                    }
                    connection.onParameterStatus(reader)
                }
                case UInt8('Z') => connection.onReadyForQuery(reader)
                case UInt8('C') => connection.onCommandComplete(reader)
                case UInt8('2') => connection.onBindComplete(reader)
                case UInt8('1') => connection.onParseComplete(reader)
                case UInt8('t') => connection.onParameterDescription(reader)
                case UInt8('T') => connection.onRowDescription(reader)
                case UInt8('R') => connection.onAuthentication(reader)
                case UInt8('n') => connection.onNoData(reader)
                case UInt8('K') => connection.onBackendKeyData(reader)
                case UInt8('E') => connection.onErrorResponse(reader)
                case UInt8('s') => {} // PortalSuspended - TODO
                case UInt8('3') => connection.onCloseComplete(reader)
                case UInt8('G') => {} // CopyInResponse - TODO
                case UInt8('N') => {
                    if (connection.isWaitingForTLS()) {
                        connection.tlsStatus = TLSStatus.SSLNotAvailable
                        if (connection.sslMode == SSLMode.Require) {
                            connection.fail("Server does not support SSL")
                            return false
                        }
                    } else {
                        connection.onNoticeResponse(reader)
                    }
                }
                case UInt8('I') => connection.onEmptyQueryResponse(reader)
                case UInt8('H') => {} // CopyOutResponse - TODO
                case UInt8('c') => {} // CopyDone - TODO
                case UInt8('W') => {} // CopyBothResponse - TODO
                case _ => {
                    // 未知消息，跳过
                    let toSkip = reader.remainingLength() - 1
                    if (toSkip > 0) {
                        reader.skip(toSkip)
                    }
                }
            }

            if (reader.isEOF()) {
                break
            }
        }
        return true
    }

    // ========================================================================
    // 内部辅助
    // ========================================================================

    /// 写入 Execute 消息
    private static func writeExecute(stmtName: String, writer: ProtocolWriter) {
        writer.beginMessage(UInt8('E'))
        writer.writeUInt8(0) // portal name (空字符串)
        writer.writeNullTerminatedString("")
        writer.writeInt32(0) // 不限行数
        writer.endMessage()
    }

    /// 写入 Flush + Sync
    private static func writeFlushAndSync(writer: ProtocolWriter) {
        // Flush
        writer.beginMessage(UInt8('H'))
        writer.endMessage()
        // Sync
        writer.beginMessage(UInt8('S'))
        writer.endMessage()
    }

    /// 检查值是否为字符串类型
    private static func isStringValue(value: PGValue): Bool {
        match (value) {
            case PGValue.Text(_) => true
            case _ => false
        }
    }
}

/// 协议写入器接口
/// 对应 Bun protocol.NewWriter(Context)
public class ProtocolWriter {
    private var buffer: Array<UInt8>
    private var messageStart: Int64

    public init() {
        buffer = Array<UInt8>()
        messageStart = 0
    }

    /// 开始新消息
    public func beginMessage(msgType: UInt8) {
        buffer.append(msgType)
        messageStart = buffer.size
        // 预留 4 字节长度
        buffer.append(0)
        buffer.append(0)
        buffer.append(0)
        buffer.append(0)
    }

    /// 结束消息 (回写长度)
    public func endMessage() {
        let len = buffer.size - messageStart
        buffer[messageStart] = UInt8((len >> 24) & 0xFF)
        buffer[messageStart + 1] = UInt8((len >> 16) & 0xFF)
        buffer[messageStart + 2] = UInt8((len >> 8) & 0xFF)
        buffer[messageStart + 3] = UInt8(len & 0xFF)
    }

    /// 写入 UInt8
    public func writeUInt8(v: UInt8) {
        buffer.append(v)
    }

    /// 写入 UInt16 (大端)
    public func writeUInt16(v: UInt16) {
        buffer.append(UInt8((v >> 8) & 0xFF))
        buffer.append(UInt8(v & 0xFF))
    }

    /// 写入 UInt32 (大端)
    public func writeUInt32(v: UInt32) {
        buffer.append(UInt8((v >> 24) & 0xFF))
        buffer.append(UInt8((v >> 16) & 0xFF))
        buffer.append(UInt8((v >> 8) & 0xFF))
        buffer.append(UInt8(v & 0xFF))
    }

    /// 写入 Int32 (大端)
    public func writeInt32(v: Int32) {
        writeUInt32(UInt32(v))
    }

    /// 写入 Int64 (大端)
    public func writeInt64(v: Int64) {
        buffer.append(UInt8((v >> 56) & 0xFF))
        buffer.append(UInt8((v >> 48) & 0xFF))
        buffer.append(UInt8((v >> 40) & 0xFF))
        buffer.append(UInt8((v >> 32) & 0xFF))
        buffer.append(UInt8((v >> 24) & 0xFF))
        buffer.append(UInt8((v >> 16) & 0xFF))
        buffer.append(UInt8((v >> 8) & 0xFF))
        buffer.append(UInt8(v & 0xFF))
    }

    /// 写入 Float64 (大端, IEEE 754)
    public func writeFloat64(v: Float64) {
        let bits = v.toBits()
        writeInt64(Int64(bits))
    }

    /// 写入 null 终止字符串
    public func writeNullTerminatedString(s: String) {
        for (c in s) {
            buffer.append(UInt8(c))
        }
        buffer.append(0)
    }

    /// 写入字符串 (无 null 终止)
    public func writeString(s: String) {
        for (c in s) {
            buffer.append(UInt8(c))
        }
    }

    /// 写入字节数组
    public func writeBytes(bytes: Array<UInt8>) {
        for (b in bytes) {
            buffer.append(b)
        }
    }

    /// 预留长度字段并返回索引
    public func reserveLength(): LengthPlaceholder {
        let idx = buffer.size
        buffer.append(0)
        buffer.append(0)
        buffer.append(0)
        buffer.append(0)
        return LengthPlaceholder(buffer: buffer, index: idx)
    }

    /// 获取缓冲区
    public func getBuffer(): Array<UInt8> {
        buffer
    }

    /// 清空缓冲区
    public func clear() {
        buffer = Array<UInt8>()
    }
}

/// 长度占位符 — 用于回写消息片段长度
public class LengthPlaceholder {
    public var buffer: Array<UInt8>
    public var index: Int64

    public init(buffer: Array<UInt8>, index: Int64) {
        this.buffer = buffer
        this.index = index
    }

    /// 写入当前长度 (不包括自身 4 字节)
    public func writeExcludingSelf() {
        let len = buffer.size - index - 4
        buffer[index] = UInt8((len >> 24) & 0xFF)
        buffer[index + 1] = UInt8((len >> 16) & 0xFF)
        buffer[index + 2] = UInt8((len >> 8) & 0xFF)
        buffer[index + 3] = UInt8(len & 0xFF)
    }
}

/// 协议读取器接口
/// 对应 Bun protocol.NewReader(Context)
public class ProtocolReader {
    private var buffer: Array<UInt8>
    private var offset: Int64
    private var messageStartOffset: Int64

    public init(buffer: Array<UInt8>) {
        this.buffer = buffer
        offset = 0
        messageStartOffset = 0
    }

    /// 标记消息起始位置
    public func markMessageStart() {
        messageStartOffset = offset
    }

    /// 读取 UInt8
    public func readUInt8(): UInt8 {
        if (offset >= buffer.size) {
            return 0
        }
        let v = buffer[offset]
        offset += 1
        return v
    }

    /// 读取 UInt16 (大端)
    public func readUInt16(): UInt16 {
        if (offset + 1 >= buffer.size) {
            return 0
        }
        let v = UInt16(buffer[offset]) << 8 | UInt16(buffer[offset + 1])
        offset += 2
        return v
    }

    /// 读取 UInt32 (大端)
    public func readUInt32(): UInt32 {
        if (offset + 3 >= buffer.size) {
            return 0
        }
        let v = UInt32(buffer[offset]) << 24 |
                UInt32(buffer[offset + 1]) << 16 |
                UInt32(buffer[offset + 2]) << 8 |
                UInt32(buffer[offset + 3])
        offset += 4
        return v
    }

    /// 读取 Int32 (大端)
    public func readInt32(): Int32 {
        Int32(readUInt32())
    }

    /// 读取 Int64 (大端)
    public func readInt64(): Int64 {
        if (offset + 7 >= buffer.size) {
            return 0
        }
        let v = Int64(buffer[offset]) << 56 |
                Int64(buffer[offset + 1]) << 48 |
                Int64(buffer[offset + 2]) << 40 |
                Int64(buffer[offset + 3]) << 32 |
                Int64(buffer[offset + 4]) << 24 |
                Int64(buffer[offset + 5]) << 16 |
                Int64(buffer[offset + 6]) << 8 |
                Int64(buffer[offset + 7])
        offset += 8
        return v
    }

    /// 读取 null 终止字符串
    public func readNullTerminatedString(): String {
        let start = offset
        while (offset < buffer.size && buffer[offset] != 0) {
            offset += 1
        }
        let bytes = buffer.slice(start, offset)
        if (offset < buffer.size) {
            offset += 1 // 跳过 null 终止符
        }
        return bytes.toArray().map({ b => Char.fromUInt8(b) }).toString()
    }

    /// 读取指定长度的字节
    public func readBytes(len: Int64): Array<UInt8> {
        let end = offset + len
        if (end > buffer.size) {
            return Array<UInt8>()
        }
        let result = buffer.slice(offset, end)
        offset = end
        return result
    }

    /// 跳过指定字节数
    public func skip(count: Int64) {
        offset += count
        if (offset > buffer.size) {
            offset = buffer.size
        }
    }

    /// 是否已到末尾
    public func isEOF(): Bool {
        offset >= buffer.size
    }

    /// 剩余字节数
    public func remainingLength(): Int64 {
        buffer.size - offset
    }

    /// 消耗一个固定消息 (不需要解析内容)
    public func eatMessage() {
        // 已在 markMessageStart 之后读取了类型字节
        // 读取长度并跳到消息末尾
        let len = readUInt32()
        offset = messageStartOffset + 1 + Int64(len)
    }
}

/// PG 连接引用 — 由 PGConnection 的 JSC 绑定实现
/// 对应 Bun PostgresSQLConnection 的消息处理方法
public interface PGConnectionRef {
    func onDataRow(reader: ProtocolReader)
    func onCopyData(reader: ProtocolReader)
    func onParameterStatus(reader: ProtocolReader)
    func onReadyForQuery(reader: ProtocolReader)
    func onCommandComplete(reader: ProtocolReader)
    func onBindComplete(reader: ProtocolReader)
    func onParseComplete(reader: ProtocolReader)
    func onParameterDescription(reader: ProtocolReader)
    func onRowDescription(reader: ProtocolReader)
    func onAuthentication(reader: ProtocolReader)
    func onNoData(reader: ProtocolReader)
    func onBackendKeyData(reader: ProtocolReader)
    func onErrorResponse(reader: ProtocolReader)
    func onCloseComplete(reader: ProtocolReader)
    func onNoticeResponse(reader: ProtocolReader)
    func onEmptyQueryResponse(reader: ProtocolReader)

    var tlsStatus: TLSStatus { get set }
    var sslMode: SSLMode { get }
    func isWaitingForTLS(): Bool
    func setupTLS()
    func fail(message: String)
}

/// PG 语句引用 — 语句信息的可变引用
public class PGStatementRef {
    public var signature: PGSignature
    public var fields: Array<FieldDescription>
    public var parameters: Array<UInt32>
    public var status: StatementStatus

    public enum StatementStatus {
        | Pending
        | Parsing
        | Prepared
        | Failed
    }

    public init(signature: PGSignature) {
        this.signature = signature
        fields = Array<FieldDescription>()
        parameters = Array<UInt32>()
        status = StatementStatus.Pending
    }
}
