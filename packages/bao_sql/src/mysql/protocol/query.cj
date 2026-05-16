// MySQL 查询协议
// 对应 Bun: src/sql/mysql/protocol/Query.zig
package bao_sql.mysql.protocol

/// MySQL 查询执行 (带参数绑定)
/// 对应 Bun: Query.Execute (struct)
public class QueryExecute {
    /// SQL 查询语句
    public var query: Array<UInt8>

    /// 参数值列表
    public var params: Array<Array<UInt8>>

    /// 参数类型列表
    public var paramTypes: Array<MySQLParam>

    public init() {
        query = []
        params = []
        paramTypes = []
    }

    public init(query: Array<UInt8>, params: Array<Array<UInt8>>, paramTypes: Array<MySQLParam>) {
        this.query = query
        this.params = params
        this.paramTypes = paramTypes
    }

    /// 释放资源
    public func release(): Unit {
        params = []
    }

    /// 写入 null 位图
    private func writeNullBitmap(writer: MySQLPacketWriter): Unit {
        let bitmapBytes = (params.size + 7) / 8
        let nullBitmap = Array<UInt8>(bitmapBytes, repeat: UInt8(0))

        for (i in 0..params.size) {
            if (params[i].size == 0) {
                let byteIdx = Int64(i >> 3)
                let bitIdx = Int64(i & 7)
                nullBitmap[byteIdx] = nullBitmap[byteIdx] | UInt8(1 << bitIdx)
            }
        }

        writer.write(nullBitmap)
    }

    /// 将查询写入到写入器
    public func write(writer: MySQLPacketWriter): Unit {
        var packet = writer.start(0)
        writer.int1(UInt8(0x03)) // COM_QUERY
        writer.write(query)

        if (params.size > 0) {
            writeNullBitmap(writer)

            // 始终为 1
            writer.int1(1)

            // 写入参数类型
            for (i in 0..paramTypes.size) {
                writer.int1(fieldTypeToByte(paramTypes[i].paramType))
                writer.int1(if (paramTypes[i].flags.UNSIGNED) { UInt8(0x80) } else { UInt8(0) })
                // 写入参数名 (:p1, :p2, ...)
                let paramName = ":p${Int64(i) + 1}"
                writer.writeLengthEncodedString(paramName.toArray())
            }

            // 写入参数值
            for (i in 0..params.size) {
                let isNullType = isFieldTypeNull(paramTypes[i].paramType)
                if (params[i].size == 0 || isNullType) {
                    continue
                }

                let value = params[i]
                if (isBinaryFieldType(paramTypes[i].paramType)) {
                    writer.write(value)
                } else {
                    writer.writeLengthEncodedString(value)
                }
            }
        }

        packet.end()
    }

    private func fieldTypeToByte(ft: FieldType): UInt8 {
        match (ft) {
            case FieldType.MYSQL_TYPE_DECIMAL(v) => v
            case FieldType.MYSQL_TYPE_TINY(v) => v
            case FieldType.MYSQL_TYPE_SHORT(v) => v
            case FieldType.MYSQL_TYPE_LONG(v) => v
            case FieldType.MYSQL_TYPE_FLOAT(v) => v
            case FieldType.MYSQL_TYPE_DOUBLE(v) => v
            case FieldType.MYSQL_TYPE_NULL(v) => v
            case FieldType.MYSQL_TYPE_TIMESTAMP(v) => v
            case FieldType.MYSQL_TYPE_LONGLONG(v) => v
            case FieldType.MYSQL_TYPE_INT24(v) => v
            case FieldType.MYSQL_TYPE_DATE(v) => v
            case FieldType.MYSQL_TYPE_TIME(v) => v
            case FieldType.MYSQL_TYPE_DATETIME(v) => v
            case FieldType.MYSQL_TYPE_YEAR(v) => v
            case FieldType.MYSQL_TYPE_NEWDATE(v) => v
            case FieldType.MYSQL_TYPE_VARCHAR(v) => v
            case FieldType.MYSQL_TYPE_BIT(v) => v
            case FieldType.MYSQL_TYPE_TIMESTAMP2(v) => v
            case FieldType.MYSQL_TYPE_DATETIME2(v) => v
            case FieldType.MYSQL_TYPE_TIME2(v) => v
            case FieldType.MYSQL_TYPE_JSON(v) => v
            case FieldType.MYSQL_TYPE_NEWDECIMAL(v) => v
            case FieldType.MYSQL_TYPE_ENUM(v) => v
            case FieldType.MYSQL_TYPE_SET(v) => v
            case FieldType.MYSQL_TYPE_TINY_BLOB(v) => v
            case FieldType.MYSQL_TYPE_MEDIUM_BLOB(v) => v
            case FieldType.MYSQL_TYPE_LONG_BLOB(v) => v
            case FieldType.MYSQL_TYPE_BLOB(v) => v
            case FieldType.MYSQL_TYPE_VAR_STRING(v) => v
            case FieldType.MYSQL_TYPE_STRING(v) => v
            case FieldType.MYSQL_TYPE_GEOMETRY(v) => v
        }
    }

    private func isFieldTypeNull(ft: FieldType): Bool {
        match (ft) {
            case FieldType.MYSQL_TYPE_NULL(_) => true
            case _ => false
        }
    }

    private func isBinaryFieldType(ft: FieldType): Bool {
        match (ft) {
            case FieldType.MYSQL_TYPE_BLOB(_) | FieldType.MYSQL_TYPE_MEDIUM_BLOB(_) |
                 FieldType.MYSQL_TYPE_LONG_BLOB(_) | FieldType.MYSQL_TYPE_TINY_BLOB(_) |
                 FieldType.MYSQL_TYPE_GEOMETRY(_) => true
            case _ => false
        }
    }
}

/// MySQL 查询工具函数
public class MySQLQuery {
    /// 执行简单查询
    public static func execute(query: Array<UInt8>, writer: MySQLPacketWriter): Unit {
        var packet = writer.start(0)
        writer.int1(UInt8(0x03)) // COM_QUERY
        writer.write(query)
        packet.end()
    }
}
