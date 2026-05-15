// 严格翻译自: src/sql_jsc/postgres/PostgresRequest.zig
// Postgres 请求 - 查询写入和消息调度

package bao_sql_jsc

import bao_core.*
import bao_jsc.*

/// Postgres 请求工具
/// 对应 Bun: PostgresRequest
/// 提供 Bind/Execute/Parse 写入和消息调度功能
public class PostgresRequest {
    /// 最大参数数量（PostgreSQL 线协议使用 16 位整数）
    let MAX_PARAMETERS: Int64 = 65535

    public init() {}

    /// 写入 Bind 消息
    /// 对应 Bun: PostgresRequest.writeBind
    public static func writeBind(name: String, cursorName: String,
                                  globalObject: JscJSGlobalObject,
                                  valuesArray: JscValue, columnsValue: JscValue,
                                  parameterFields: Array<Int32>,
                                  resultFields: Array<FieldDescription>,
                                  writer: PostgresWriter): Unit {
        writer.write("B")

        // 写入 portal 名称和语句名称
        writer.string(cursorName)
        writer.string(name)

        // 写入参数格式代码
        let len = Int16(parameterFields.size)
        writer.short(len)

        // 写入参数值
        writer.short(len)

        let iter = QueryBindingIterator.init(valuesArray, columnsValue, globalObject)
        if (iter == None) {
            return
        }

        var i: Int64 = 0
        var nextValue = iter.getOrThrow().next()
        while (nextValue != None) {
            let value = nextValue.getOrThrow()

            if (value.isEmptyOrUndefinedOrNull()) {
                writer.int32(-1)
            } else {
                // 根据类型写入值
                if (i < parameterFields.size) {
                    let paramField = parameterFields[Int64(i)]
                    writeBindValue(value, paramField, globalObject, writer)
                } else {
                    writeBindValue(value, 0, globalObject, writer)
                }
            }
            i += 1
            nextValue = iter.getOrThrow().next()
        }

        // 写入结果格式代码
        writer.short(0)
    }

    /// 写入绑定值
    private static func writeBindValue(value: JscValue, paramField: Int32,
                                        globalObject: JscJSGlobalObject,
                                        writer: PostgresWriter): Unit {
        let tag = if (paramField > Int16.MaxValue) PostgresTag.Text
                  else PostgresTag.fromInt(paramField)

        match (tag) {
            case Bool =>
                writer.write([UInt8(if (value.toBoolean()) 1 else 0)])
            case Int4 =>
                writer.int32(value.coerceToInt32(globalObject))
            case Float8 =>
                writer.f64(value.toNumber(globalObject))
            case Bytea =>
                if (value.asArrayBuffer(globalObject) != None) {
                    let buf = value.asArrayBuffer(globalObject).getOrThrow()
                    writer.write(buf.byteSlice())
                }
            case _ =>
                let str = value.toBunString(globalObject)
                let slice = str.toUTF8()
                writer.write(slice)
        }
    }

    /// 写入 Parse + Describe
    /// 对应 Bun: PostgresRequest.writeQuery
    public static func writeQuery(query: String, name: String, params: Array<Int32>,
                                   writer: PostgresWriter): Unit {
        // Parse 消息
        writer.write("P")
        writer.string(name)
        writer.string(query)
        writer.short(Int16(params.size))
        for (p in params) {
            writer.int32(p)
        }

        // Describe 消息
        writer.write("D")
        writer.write("S")
        writer.string(name)
    }

    /// 准备并执行查询
    /// 对应 Bun: PostgresRequest.prepareAndQueryWithSignature
    public static func prepareAndQueryWithSignature(globalObject: JscJSGlobalObject,
                                                      query: String, arrayValue: JscValue,
                                                      writer: PostgresWriter,
                                                      signature: PostgresSignature): Unit {
        writeQuery(query, signature.preparedStatementName, signature.fields, writer)
        writeBind(signature.preparedStatementName, "", globalObject, arrayValue,
            JscValue.undefined(), [], [], writer)
        writer.write("E")
        writer.write("H")  // Flush
        writer.write("S")  // Sync
    }

    /// 绑定并执行
    /// 对应 Bun: PostgresRequest.bindAndExecute
    public static func bindAndExecute(globalObject: JscJSGlobalObject,
                                       statement: PostgresSQLStatement,
                                       arrayValue: JscValue, columnsValue: JscValue,
                                       writer: PostgresWriter): Unit {
        writeBind(statement.signature.preparedStatementName, "",
            globalObject, arrayValue, columnsValue,
            statement.parameters, statement.fields, writer)
        writer.write("E")
        writer.write("H")  // Flush
        writer.write("S")  // Sync
    }

    /// 执行查询
    /// 对应 Bun: PostgresRequest.executeQuery
    public static func executeQuery(query: String, writer: PostgresWriter): Unit {
        writer.write("Q")
        writer.string(query)
    }

    /// 处理接收到的数据
    /// 对应 Bun: PostgresRequest.onData
    public static func onData(connection: PostgresSQLConnection,
                               reader: PostgresReader): Unit {
        while (true) {
            reader.markMessageStart()
            let c = reader.readByte()
            if (c == None) {
                return
            }

            match (c.getOrThrow()) {
                case 'D' => connection.on(PostgresMessageType.DataRow, reader)
                case 'S' =>
                    if (connection.tlsStatus == PostgresTLSStatus.MessageSent) {
                        connection.tlsStatus = PostgresTLSStatus.SSLOk
                        connection.setupTLS()
                        return
                    }
                    connection.on(PostgresMessageType.ParameterStatus, reader)
                case 'Z' => connection.on(PostgresMessageType.ReadyForQuery, reader)
                case 'C' => connection.on(PostgresMessageType.CommandComplete, reader)
                case '2' => connection.on(PostgresMessageType.BindComplete, reader)
                case '1' => connection.on(PostgresMessageType.ParseComplete, reader)
                case 't' => connection.on(PostgresMessageType.ParameterDescription, reader)
                case 'T' => connection.on(PostgresMessageType.RowDescription, reader)
                case 'R' => connection.on(PostgresMessageType.Authentication, reader)
                case 'n' => connection.on(PostgresMessageType.NoData, reader)
                case 'K' => connection.on(PostgresMessageType.BackendKeyData, reader)
                case 'E' => connection.on(PostgresMessageType.ErrorResponse, reader)
                case 'N' =>
                    if (connection.tlsStatus == PostgresTLSStatus.MessageSent) {
                        connection.tlsStatus = PostgresTLSStatus.SSLNotAvailable
                        if (connection.sslMode == PostgresSSLMode.Require) {
                            connection.fail("Server does not support SSL", AnyPostgresError.TLSNotAvailable)
                            return
                        }
                    } else {
                        connection.on(PostgresMessageType.NoticeResponse, reader)
                    }
                case _ =>
                    reader.skipRemaining()
            }
        }
    }
}

/// Postgres 消息类型
public enum PostgresMessageType {
    | DataRow
    | ParameterStatus
    | ReadyForQuery
    | CommandComplete
    | BindComplete
    | ParseComplete
    | ParameterDescription
    | RowDescription
    | Authentication
    | NoData
    | BackendKeyData
    | ErrorResponse
    | NoticeResponse
    | CopyData
    | PortalSuspended
    | CloseComplete
    | CopyInResponse
    | EmptyQueryResponse
    | CopyOutResponse
    | CopyDone
    | CopyBothResponse
}

/// Postgres 写入器
public class PostgresWriter {
    var buffer: ArrayList<UInt8> = ArrayList<UInt8>()

    public init() {}

    public func write(data: String): Unit {
        for (b in data.toArray()) {
            buffer.append(b)
        }
    }

    public func write(data: Array<UInt8>): Unit {
        for (b in data) {
            buffer.append(b)
        }
    }

    public func string(s: String): Unit {
        for (b in s.toArray()) {
            buffer.append(b)
        }
        buffer.append(0)
    }

    public func short(v: Int16): Unit {
        buffer.append(UInt8((v >> 8) & 0xFF))
        buffer.append(UInt8(v & 0xFF))
    }

    public func int32(v: Int32): Unit {
        buffer.append(UInt8((v >> 24) & 0xFF))
        buffer.append(UInt8((v >> 16) & 0xFF))
        buffer.append(UInt8((v >> 8) & 0xFF))
        buffer.append(UInt8(v & 0xFF))
    }

    public func int64(v: Int64): Unit {
        for (i in 0..8) {
            buffer.append(UInt8((v >> (56 - i * 8)) & 0xFF))
        }
    }

    public func f64(v: Float64): Unit {
        // 写入 IEEE 754 双精度浮点数
        int64(Int64.fromFloat64Bits(v))
    }

    public func length(): Int64 {
        return buffer.size
    }
}

/// Postgres 读取器
public class PostgresReader {
    var data: Array<UInt8> = []
    var offset: Int64 = 0

    public init() {}
    public init(data: Array<UInt8>) {
        this.data = data
    }

    public func markMessageStart(): Unit {}

    public func readByte(): ?UInt8 {
        if (offset >= data.size) {
            return None
        }
        let b = data[offset]
        offset += 1
        return b
    }

    public func skipRemaining(): Unit {
        offset = data.size
    }

    public func readInt32(): Int32 {
        if (offset + 4 > data.size) {
            return 0
        }
        let v = (Int32(data[offset]) << 24) | (Int32(data[offset + 1]) << 16) |
            (Int32(data[offset + 2]) << 8) | Int32(data[offset + 3])
        offset += 4
        return v
    }

    public func readInt16(): Int16 {
        if (offset + 2 > data.size) {
            return 0
        }
        let v = (Int16(data[offset]) << 8) | Int16(data[offset + 1])
        offset += 2
        return v
    }

    public func readString(): String {
        var end = offset
        while (end < data.size && data[end] != 0) {
            end += 1
        }
        let s = String.fromUtf8(data[offset..end])
        offset = end + 1
        return s
    }
}
