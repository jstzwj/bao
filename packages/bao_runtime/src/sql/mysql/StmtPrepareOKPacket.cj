// MySQL StmtPrepareOKPacket 协议包
// 严格翻译自: src/sql/mysql/protocol/StmtPrepareOKPacket.zig
package bao_runtime.sql.mysql

import bao_core.*

/// MySQL 预编译语句 OK 响应包
/// 对应 Bun: StmtPrepareOKPacket
/// COM_STMT_PREPARE 成功后服务器返回此包
public class StmtPrepareOKPacket {
    /// 状态 (0 = OK)
    public var status: UInt8
    /// 语句 ID
    public var statementId: UInt32
    /// 参数列数
    public var numColumns: UInt16
    /// 参数数
    public var numParams: UInt16
    /// 警告数
    public var warningCount: UInt16
    /// 包长度
    public var packetLength: UInt32

    public init() {
        status = 0
        statementId = 0
        numColumns = 0
        numParams = 0
        warningCount = 0
        packetLength = 0
    }

    /// 从 Reader 解码
    /// 对应 Bun: StmtPrepareOKPacket.decodeInternal
    public func decode(reader: MySQLPacketReader): Unit {
        status = reader.readInt8()
        if (status != 0) {
            return  // InvalidPrepareOKPacket
        }

        statementId = reader.readInt32()
        numColumns = reader.readInt16()
        numParams = reader.readInt16()
        _ = reader.readInt8()  // reserved_1
        if (packetLength >= 12) {
            warningCount = reader.readInt16()
        }
    }
}
