// MySQL PrepareOK 包 (独立版本)
// 对应 Bun: src/sql/mysql/protocol/StmtPrepareOKPacket.zig
package bao_sql.mysql.protocol

/// MySQL 预编译语句准备 OK 包
/// 对应 Bun: StmtPrepareOKPacket (struct)
///
/// 服务器在成功处理 COM_STMT_PREPARE 后发送此包
public class StmtPrepareOKPacket {
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

    /// 包长度
    /// 对应 Bun: packet_length u24
    public var packetLength: UInt32

    public init() {
        status = 0
        statementId = 0
        numColumns = 0
        numParams = 0
        warningCount = 0
        packetLength = 0
    }

    public init(packetLength: UInt32) {
        status = 0
        statementId = 0
        numColumns = 0
        numParams = 0
        warningCount = 0
        this.packetLength = packetLength
    }

    /// 从读取器解码 PrepareOK 包
    /// 对应 Bun: StmtPrepareOKPacket.decodeInternal
    public func decode(reader: MySQLPacketReader): Unit {
        status = reader.int8()
        if (status != 0) {
            throw MySQLProtocolException("InvalidPrepareOKPacket")
        }

        statementId = reader.int32()
        numColumns = reader.int16()
        numParams = reader.int16()
        let _ = reader.int8() // reserved_1
        if (packetLength >= 12) {
            warningCount = reader.int16()
        }
    }
}
