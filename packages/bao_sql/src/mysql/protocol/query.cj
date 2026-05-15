// MySQL 查询协议
// 对应 Bun: src/sql/mysql/protocol/Query.zig
package bao_sql.mysql.protocol

/// MySQL 查询执行 (带参数绑定)
/// 对应 Bun: Query.Execute (struct)
///
/// 使用文本协议执行查询，支持参数绑定
public class QueryExecute {
    /// SQL 查询语句
    /// 对应 Bun: query []const u8
    public var query: Array<UInt8>

    /// 参数值列表
    /// 对应 Bun: params []Data
    public var params: Array<Array<UInt8>>

    /// 参数类型列表
    /// 对应 Bun: param_types []const Param
    public var paramTypes: Array<MySQLParam>

    public init() {
        query = Array<UInt8>()
        params = Array<Array<UInt8>>()
        paramTypes = Array<MySQLParam>()
    }

    public init(query: Array<UInt8>, params: Array<Array<UInt8>>, paramTypes: Array<MySQLParam>) {
        this.query = query
        this.params = params
        this.paramTypes = paramTypes
    }

    /// 释放资源
    /// 对应 Bun: Execute.deinit
    public func deinit(): Unit {
        params = Array<Array<UInt8>>()
    }

    /// 写入 null 位图
    private func writeNullBitmap(writer: MySQLPacketWriter): Unit {
        let bitmapBytes = (params.size + 7) / 8
        let nullBitmap = Array<UInt8>(bitmapBytes)

        for (i in 0..params.size) {
            if (params[i].size == 0) {
                nullBitmap[i >> 3] = nullBitmap[i >> 3] | UInt8(1 << UInt8(i & 7))
            }
        }

        writer.write(nullBitmap)
    }

    /// 将查询写入到写入器
    /// 对应 Bun: Execute.writeInternal
    public func write(writer: MySQLPacketWriter): Unit {
        var packet = writer.start(0)
        writer.int1(CommandType.COM_QUERY.value())
        writer.write(query)

        if (params.size > 0) {
            writeNullBitmap(writer)

            // 始终为 1 (格式错误如果不是 1)
            writer.int1(1)

            // 写入参数类型
            for (i in 0..paramTypes.size) {
                writer.int1(paramTypes[i].paramType.toUInt8())
                writer.int1(if (paramTypes[i].flags.UNSIGNED) 0x80 else 0)
                // 写入参数名 (:p1, :p2, ...)
                let paramName = ":p${i + 1}"
                writer.writeLengthEncodedString(paramName.toUtf8Bytes())
            }

            // 写入参数值
            for (i in 0..params.size) {
                if (params[i].size == 0 || paramTypes[i].paramType == FieldType.MYSQL_TYPE_NULL(0x06)) {
                    continue
                }

                let value = params[i]
                if (paramTypes[i].paramType.isBinaryFormatSupported()) {
                    writer.write(value)
                } else {
                    writer.writeLengthEncodedString(value)
                }
            }
        }

        packet.end()
    }
}

/// MySQL 查询工具函数
/// 对应 Bun: Query.execute
public class MySQLQuery {
    /// 执行简单查询
    /// 对应 Bun: Query.execute
    public static func execute(query: Array<UInt8>, writer: MySQLPacketWriter): Unit {
        var packet = writer.start(0)
        writer.int1(CommandType.COM_QUERY.value())
        writer.write(query)
        packet.end()
    }
}
