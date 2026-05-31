// MySQL 预编译语句协议
// 严格翻译自: src/sql/mysql/protocol/PreparedStatement.zig
package bao_runtime.sql.mysql

import bao_core.*
import bao_runtime.sql.shared.*

/// MySQL 预编译语句 PrepareOK 响应
/// 对应 Bun: PreparedStatement.PrepareOK
public class PrepareOK {
    /// 状态 (0 = OK)
    public var status: UInt8
    /// 语句 ID
    public var statementId: UInt32
    /// 列数
    public var numColumns: UInt16
    /// 参数数
    public var numParams: UInt16
    /// 警告数
    public var warningCount: UInt16

    public init() {
        status = 0
        statementId = 0
        numColumns = 0
        numParams = 0
        warningCount = 0
    }

    /// 从 Reader 解码
    /// 对应 Bun: PrepareOK.decodeInternal
    public func decode(reader: MySQLPacketReader): Unit {
        status = reader.readInt8()
        if (status != 0) {
            return  // InvalidPrepareOKPacket
        }

        statementId = reader.readInt32()
        numColumns = reader.readInt16()
        numParams = reader.readInt16()
        _ = reader.readInt8()  // reserved_1
        warningCount = reader.readInt16()
    }
}

/// MySQL 预编译语句执行包
/// 对应 Bun: PreparedStatement.Execute
/// COM_STMT_EXECUTE 命令
public class PreparedStatementExecute {
    /// 预编译语句 ID
    public var statementId: UInt32
    /// 执行标志 (仅支持 CURSOR_TYPE_READ_ONLY = 0x01)
    public var flags: UInt8
    /// 迭代次数 (通常为 1)
    public var iterationCount: UInt32
    /// 参数值列表
    public var params: Array<MySQLValue>
    /// 参数类型列表
    public var paramTypes: Array<MySQLParam>
    /// 是否发送新参数绑定标志
    public var newParamsBindFlag: Bool

    public init() {
        statementId = 0
        flags = 0
        iterationCount = 1
        params = Array<MySQLValue>()
        paramTypes = Array<MySQLParam>()
        newParamsBindFlag = true
    }

    /// 释放资源
    /// 对应 Bun: PreparedStatement.Execute.deinit
    public func deinit(): Unit {
        params = Array<MySQLValue>()
        paramTypes = Array<MySQLParam>()
    }

    /// 写入 null bitmap
    /// 对应 Bun: PreparedStatement.Execute.writeNullBitmap
    func writeNullBitmap(writer: MySQLPacketWriter): Unit {
        let bitmapBytes = (params.size + 7) / 8
        let bitmap = Array<UInt8>(bitmapBytes, item: 0)
        for (i in 0..params.size) {
            if (params[i].isNull()) {
                bitmap[i >> 3] = bitmap[i >> 3] | UInt8(1 << (i & 7))
            }
        }
        for (b in bitmap) {
            writer.buffer.append(b)
        }
    }

    /// 编码到 Writer
    /// 对应 Bun: PreparedStatement.Execute.writeInternal
    public func write(writer: MySQLPacketWriter): Unit {
        writer.writeInt8(CommandType.COM_STMT_EXECUTE.value)
        writer.writeInt32(statementId)
        writer.writeInt8(flags)
        writer.writeInt32(iterationCount)

        if (params.size > 0) {
            writeNullBitmap(writer)

            // 写入新参数绑定标志
            writer.writeInt8(if (newParamsBindFlag) 1 else 0)

            if (newParamsBindFlag) {
                // 写入参数类型
                for (paramType in paramTypes) {
                    writer.writeInt8(paramType.paramType.value)
                    writer.writeInt8(if (paramType.flags.UNSIGNED) 0x80 else 0)
                }
            }

            // 写入参数值
            for (i in 0..params.size) {
                if (params[i].isNull() || paramTypes[i].paramType == FieldType.MYSQL_TYPE_NULL) {
                    continue
                }
                let value = params[i].toData(paramTypes[i].paramType)
                if (paramTypes[i].paramType.isBinaryFormatSupported()) {
                    writer.writeBytes(value)
                } else {
                    writer.writeLengthEncodedString(value)
                }
            }
        }
    }
}
