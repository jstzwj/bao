// MySQL 预编译语句协议
// 对应 Bun: src/sql/mysql/protocol/PreparedStatement.zig
package bao_sql.mysql.protocol

/// MySQL 预编译语句 PrepareOK 响应
/// 对应 Bun: PreparedStatement.PrepareOK (struct)
public class PrepareOK {
    /// 状态 (固定为 0)
    public var status: UInt8

    /// 语句 ID
    public var statementId: UInt32

    /// 列数
    public var numColumns: UInt16

    /// 参数数
    public var numParams: UInt16

    /// 警告计数
    public var warningCount: UInt16

    public init() {
        status = 0
        statementId = 0
        numColumns = 0
        numParams = 0
        warningCount = 0
    }

    /// 从读取器解码 PrepareOK 包
    public func decode(reader: MySQLPacketReader): Unit {
        status = reader.int8()
        if (status != 0) {
            throw MySQLProtocolException("InvalidPrepareOKPacket")
        }

        statementId = reader.int32()
        numColumns = reader.int16()
        numParams = reader.int16()
        let _ = reader.int8() // reserved_1
        warningCount = reader.int16()
    }
}

/// MySQL 预编译语句执行请求
/// 对应 Bun: PreparedStatement.Execute (struct)
public class PreparedStatementExecute {
    /// 语句 ID
    public var statementId: UInt32

    /// 执行标志
    public var flags: UInt8

    /// 迭代次数
    public var iterationCount: UInt32

    /// 参数值列表
    public var params: Array<Array<UInt8>>

    /// 参数类型列表
    public var paramTypes: Array<MySQLParam>

    /// 是否发送参数类型
    public var newParamsBindFlag: Bool

    public init() {
        statementId = 0
        flags = 0
        iterationCount = 1
        params = []
        paramTypes = []
        newParamsBindFlag = true
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

    /// 将执行请求写入到写入器
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

    private func isBinaryFieldType(ft: FieldType): Bool {
        match (ft) {
            case FieldType.MYSQL_TYPE_BLOB(_) | FieldType.MYSQL_TYPE_MEDIUM_BLOB(_) |
                 FieldType.MYSQL_TYPE_LONG_BLOB(_) | FieldType.MYSQL_TYPE_TINY_BLOB(_) |
                 FieldType.MYSQL_TYPE_GEOMETRY(_) => true
            case _ => false
        }
    }

    public func write(writer: MySQLPacketWriter): Unit {
        writer.int1(UInt8(0x17)) // COM_STMT_EXECUTE
        writer.int4(statementId)
        writer.int1(flags)
        writer.int4(iterationCount)

        if (params.size > 0) {
            writeNullBitmap(writer)

            // 写入新参数绑定标志
            writer.int1(if (newParamsBindFlag) { UInt8(1) } else { UInt8(0) })

            if (newParamsBindFlag) {
                // 写入参数类型
                for (i in 0..paramTypes.size) {
                    writer.int1(fieldTypeToByte(paramTypes[i].paramType))
                    writer.int1(if (paramTypes[i].flags.UNSIGNED) { UInt8(0x80) } else { UInt8(0) })
                }
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
    }

    private func isFieldTypeNull(ft: FieldType): Bool {
        match (ft) {
            case FieldType.MYSQL_TYPE_NULL(_) => true
            case _ => false
        }
    }
}
