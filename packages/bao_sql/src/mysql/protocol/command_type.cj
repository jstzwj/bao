// MySQL 命令类型
// 对应 Bun: src/sql/mysql/protocol/CommandType.zig
package bao_sql

/// MySQL 命令包类型
/// 对应 Bun: CommandType (enum u8)
public enum CommandType <: UInt8 {
    | COM_QUIT(UInt8)               // 0x01
    | COM_INIT_DB(UInt8)            // 0x02
    | COM_QUERY(UInt8)              // 0x03
    | COM_FIELD_LIST(UInt8)         // 0x04
    | COM_CREATE_DB(UInt8)          // 0x05
    | COM_DROP_DB(UInt8)            // 0x06
    | COM_REFRESH(UInt8)            // 0x07
    | COM_SHUTDOWN(UInt8)           // 0x08
    | COM_STATISTICS(UInt8)         // 0x09
    | COM_PROCESS_INFO(UInt8)       // 0x0a
    | COM_CONNECT(UInt8)            // 0x0b
    | COM_PROCESS_KILL(UInt8)       // 0x0c
    | COM_DEBUG(UInt8)              // 0x0d
    | COM_PING(UInt8)               // 0x0e
    | COM_TIME(UInt8)               // 0x0f
    | COM_DELAYED_INSERT(UInt8)     // 0x10
    | COM_CHANGE_USER(UInt8)        // 0x11
    | COM_BINLOG_DUMP(UInt8)        // 0x12
    | COM_TABLE_DUMP(UInt8)         // 0x13
    | COM_CONNECT_OUT(UInt8)        // 0x14
    | COM_REGISTER_SLAVE(UInt8)     // 0x15
    | COM_STMT_PREPARE(UInt8)       // 0x16
    | COM_STMT_EXECUTE(UInt8)       // 0x17
    | COM_STMT_SEND_LONG_DATA(UInt8)// 0x18
    | COM_STMT_CLOSE(UInt8)         // 0x19
    | COM_STMT_RESET(UInt8)         // 0x1a
    | COM_SET_OPTION(UInt8)         // 0x1b
    | COM_STMT_FETCH(UInt8)         // 0x1c
    | COM_DAEMON(UInt8)             // 0x1d
    | COM_BINLOG_DUMP_GTID(UInt8)   // 0x1e
    | COM_RESET_CONNECTION(UInt8)   // 0x1f

    /// 从整数值创建
    public static func fromInt(value: UInt8): CommandType {
        match (value) {
            case 0x01 => CommandType.COM_QUIT(0x01)
            case 0x02 => CommandType.COM_INIT_DB(0x02)
            case 0x03 => CommandType.COM_QUERY(0x03)
            case 0x04 => CommandType.COM_FIELD_LIST(0x04)
            case 0x05 => CommandType.COM_CREATE_DB(0x05)
            case 0x06 => CommandType.COM_DROP_DB(0x06)
            case 0x07 => CommandType.COM_REFRESH(0x07)
            case 0x08 => CommandType.COM_SHUTDOWN(0x08)
            case 0x09 => CommandType.COM_STATISTICS(0x09)
            case 0x0a => CommandType.COM_PROCESS_INFO(0x0a)
            case 0x0b => CommandType.COM_CONNECT(0x0b)
            case 0x0c => CommandType.COM_PROCESS_KILL(0x0c)
            case 0x0d => CommandType.COM_DEBUG(0x0d)
            case 0x0e => CommandType.COM_PING(0x0e)
            case 0x0f => CommandType.COM_TIME(0x0f)
            case 0x10 => CommandType.COM_DELAYED_INSERT(0x10)
            case 0x11 => CommandType.COM_CHANGE_USER(0x11)
            case 0x12 => CommandType.COM_BINLOG_DUMP(0x12)
            case 0x13 => CommandType.COM_TABLE_DUMP(0x13)
            case 0x14 => CommandType.COM_CONNECT_OUT(0x14)
            case 0x15 => CommandType.COM_REGISTER_SLAVE(0x15)
            case 0x16 => CommandType.COM_STMT_PREPARE(0x16)
            case 0x17 => CommandType.COM_STMT_EXECUTE(0x17)
            case 0x18 => CommandType.COM_STMT_SEND_LONG_DATA(0x18)
            case 0x19 => CommandType.COM_STMT_CLOSE(0x19)
            case 0x1a => CommandType.COM_STMT_RESET(0x1a)
            case 0x1b => CommandType.COM_SET_OPTION(0x1b)
            case 0x1c => CommandType.COM_STMT_FETCH(0x1c)
            case 0x1d => CommandType.COM_DAEMON(0x1d)
            case 0x1e => CommandType.COM_BINLOG_DUMP_GTID(0x1e)
            case 0x1f => CommandType.COM_RESET_CONNECTION(0x1f)
            case _ => CommandType.COM_QUIT(0x01)
        }
    }

    public func value(): UInt8 {
        match (this) {
            case COM_QUIT(v) => v
            case COM_INIT_DB(v) => v
            case COM_QUERY(v) => v
            case COM_FIELD_LIST(v) => v
            case COM_CREATE_DB(v) => v
            case COM_DROP_DB(v) => v
            case COM_REFRESH(v) => v
            case COM_SHUTDOWN(v) => v
            case COM_STATISTICS(v) => v
            case COM_PROCESS_INFO(v) => v
            case COM_CONNECT(v) => v
            case COM_PROCESS_KILL(v) => v
            case COM_DEBUG(v) => v
            case COM_PING(v) => v
            case COM_TIME(v) => v
            case COM_DELAYED_INSERT(v) => v
            case COM_CHANGE_USER(v) => v
            case COM_BINLOG_DUMP(v) => v
            case COM_TABLE_DUMP(v) => v
            case COM_CONNECT_OUT(v) => v
            case COM_REGISTER_SLAVE(v) => v
            case COM_STMT_PREPARE(v) => v
            case COM_STMT_EXECUTE(v) => v
            case COM_STMT_SEND_LONG_DATA(v) => v
            case COM_STMT_CLOSE(v) => v
            case COM_STMT_RESET(v) => v
            case COM_SET_OPTION(v) => v
            case COM_STMT_FETCH(v) => v
            case COM_DAEMON(v) => v
            case COM_BINLOG_DUMP_GTID(v) => v
            case COM_RESET_CONNECTION(v) => v
        }
    }
}
