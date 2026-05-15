// MySQL 预编译语句协议
// 对应 Bun: src/sql/mysql/protocol/PreparedStatement.zig
package bao_sql.mysql.protocol

/// MySQL 预编译语句 PrepareOK 响应
/// 对应 Bun: PreparedStatement.PrepareOK (struct)
///
/// 服务器在成功处理 COM_STMT_PREPARE 后发送此包
public class PrepareOK {
    /// 状态 (固定为 0)
    /// 对应 Bun: status u8
    public var status: UInt8

    /// 语句 ID
    /// 对应 Bun: statement_id u32
    public var statementId: UInt32

    /// 列数
    /// 对应 Bun: num_columns u16
    public var numColumns: UInt16

    /// 参数数
    /// 对应 Bun: num_params u16
    public var numParams: UInt16

    /// 警告计数
    /// 对应 Bun: warning_count u16
    public var warningCount: UInt16

    public init() {
        status = 0
        statementId = 0
        numColumns = 0
        numParams = 0
        warningCount = 0
    }

    /// 从读取器解码 PrepareOK 包
    /// 对应 Bun: PrepareOK.decodeInternal
    public func decode(reader: MySQLPacketReader): Unit {
        status = reader.int8()
        if (status != 0) {
            throw MySQLError.InvalidPrepareOKPacket
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
///
/// 客户端发送此包执行之前准备好的语句
public class PreparedStatementExecute {
    /// 语句 ID (由 COM_STMT_PREPARE 返回)
    /// 对应 Bun: statement_id u32
    public var statementId: UInt32

    /// 执行标志 (目前只支持 CURSOR_TYPE_READ_ONLY = 0x01)
    /// 对应 Bun: flags u8
    public var flags: UInt8

    /// 迭代次数 (通常为 1)
    /// 对应 Bun: iteration_count u32
    public var iterationCount: UInt32

    /// 参数值列表
    /// 对应 Bun: params []Value
    public var params: Array<Array<UInt8>>

    /// 参数类型列表
    /// 对应 Bun: param_types []const Param
    public var paramTypes: Array<MySQLParam>

    /// 是否发送参数类型 (首次执行为 true，后续为 false)
    /// 对应 Bun: new_params_bind_flag bool
    public var newParamsBindFlag: Bool

    public init() {
        statementId = 0
        flags = 0
        iterationCount = 1
        params = Array<Array<UInt8>>()
        paramTypes = Array<MySQLParam>()
        newParamsBindFlag = true
    }

    /// 释放资源
    /// 对应 Bun: Execute.deinit
    public func deinit(): Unit {
        params = Array<Array<UInt8>>()
    }

    /// 写入 null 位图
    /// 对应 Bun: Execute.writeNullBitmap
    private func writeNullBitmap(writer: MySQLPacketWriter): Unit {
        // MySQL 最大参数数 = (u16_max / 8) + 1
        let bitmapBytes = (params.size + 7) / 8
        let nullBitmap = Array<UInt8>(bitmapBytes) // 初始化为 0

        for (i in 0..params.size) {
            if (params[i].size == 0) {
                nullBitmap[i >> 3] = nullBitmap[i >> 3] | UInt8(1 << UInt8(i & 7))
            }
        }

        writer.write(nullBitmap)
    }

    /// 将执行请求写入到写入器
    /// 对应 Bun: Execute.writeInternal
    public func write(writer: MySQLPacketWriter): Unit {
        writer.int1(CommandType.COM_STMT_EXECUTE.value())
        writer.int4(statementId)
        writer.int1(flags)
        writer.int4(iterationCount)

        if (params.size > 0) {
            writeNullBitmap(writer)

            // 写入新参数绑定标志
            writer.int1(if (newParamsBindFlag) 1 else 0)

            if (newParamsBindFlag) {
                // 写入参数类型
                for (i in 0..paramTypes.size) {
                    writer.int1(paramTypes[i].paramType.toUInt8())
                    writer.int1(if (paramTypes[i].flags.UNSIGNED) 0x80 else 0)
                }
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
    }
}
