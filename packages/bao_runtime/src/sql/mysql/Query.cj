// MySQL 查询协议
// 严格翻译自: src/sql/mysql/protocol/Query.zig
package bao_runtime.sql.mysql

import bao_core.*
import bao_runtime.sql.shared.*

/// MySQL 文本查询执行包
/// 对应 Bun: Query.Execute
/// COM_QUERY 命令的执行包 (带参数绑定)
public class QueryExecute {
    /// SQL 查询文本
    public var query: Array<UInt8>
    /// 参数值
    public var params: Array<SQLData>
    /// 参数类型
    public var paramTypes: Array<MySQLParam>

    public init() {
        query = Array<UInt8>()
        params = Array<SQLData>()
        paramTypes = Array<MySQLParam>()
    }

    /// 释放资源
    /// 对应 Bun: Query.Execute.deinit
    public func deinit(): Unit {
        for (param in params) {
            param.deinit()
        }
    }

    /// 编码到 Writer
    /// 对应 Bun: Query.Execute.writeInternal
    public func write(writer: MySQLPacketWriter): Unit {
        writer.start(0)
        writer.writeInt8(CommandType.COM_QUERY.value)
        writer.writeBytes(query)

        if (params.size > 0) {
            // 写入 null bitmap
            let bitmapBytes = (params.size + 7) / 8
            let bitmap = Array<UInt8>(bitmapBytes, item: 0)
            for (i in 0..params.size) {
                if (params[i].isEmpty() || paramTypes[i].paramType == FieldType.MYSQL_TYPE_NULL) {
                    bitmap[i >> 3] = bitmap[i >> 3] | UInt8(1 << (i & 7))
                }
            }
            for (b in bitmap) {
                writer.buffer.append(b)
            }

            // 固定为 1 (格式错误如果不是 1)
            writer.writeInt8(1)

            // 写入参数类型
            for (i in 0..paramTypes.size) {
                writer.writeInt8(paramTypes[i].paramType.value)
                writer.writeInt8(if (paramTypes[i].flags.UNSIGNED) 0x80 else 0)
                // 写入参数名
                let paramNameStr = ":p${i + 1}"
                writer.writeLengthEncodedString(paramNameStr.toArray())
            }

            // 写入参数值
            for (i in 0..params.size) {
                if (params[i].isEmpty() || paramTypes[i].paramType == FieldType.MYSQL_TYPE_NULL) {
                    continue
                }
                let value = params[i].slice()
                if (paramTypes[i].paramType.isBinaryFormatSupported()) {
                    writer.writeBytes(value)
                } else {
                    writer.writeLengthEncodedString(value)
                }
            }
        }
        writer.endPacket()
    }
}

/// 执行简单文本查询 (无参数)
/// 对应 Bun: Query.execute
public func executeQuery(query: Array<UInt8>, writer: MySQLPacketWriter): Unit {
    writer.start(0)
    writer.writeInt8(CommandType.COM_QUERY.value)
    writer.writeBytes(query)
    writer.endPacket()
}

/// 预编译请求
/// 对应 Bun: MySQLRequest.prepareRequest
public func prepareRequest(query: Array<UInt8>, writer: MySQLPacketWriter): Unit {
    writer.start(0)
    writer.writeInt8(CommandType.COM_STMT_PREPARE.value)
    writer.writeBytes(query)
    writer.endPacket()
}

/// 执行查询请求
/// 对应 Bun: MySQLRequest.executeQuery
public func executeQueryRequest(query: Array<UInt8>, writer: MySQLPacketWriter): Unit {
    writer.start(0)
    writer.writeInt8(CommandType.COM_QUERY.value)
    writer.writeBytes(query)
    writer.endPacket()
}
