// MySQL 命令类型
// 对应 Bun: src/sql/mysql/protocol/CommandType.zig
package bao_sql.mysql.protocol

/// MySQL 命令包类型
/// 对应 Bun: CommandType (enum u8)
public enum CommandType {
    | COM_QUIT(UInt8)
    | COM_INIT_DB(UInt8)
    | COM_QUERY(UInt8)
    | COM_FIELD_LIST(UInt8)
    | COM_CREATE_DB(UInt8)
    | COM_DROP_DB(UInt8)
    | COM_REFRESH(UInt8)
    | COM_SHUTDOWN(UInt8)
    | COM_STATISTICS(UInt8)
    | COM_PROCESS_INFO(UInt8)
    | COM_CONNECT(UInt8)
    | COM_PROCESS_KILL(UInt8)
    | COM_DEBUG(UInt8)
    | COM_PING(UInt8)
    | COM_TIME(UInt8)
    | COM_DELAYED_INSERT(UInt8)
    | COM_CHANGE_USER(UInt8)
    | COM_BINLOG_DUMP(UInt8)
    | COM_TABLE_DUMP(UInt8)
    | COM_CONNECT_OUT(UInt8)
    | COM_REGISTER_SLAVE(UInt8)
    | COM_STMT_PREPARE(UInt8)
    | COM_STMT_EXECUTE(UInt8)
    | COM_STMT_SEND_LONG_DATA(UInt8)
    | COM_STMT_CLOSE(UInt8)
    | COM_STMT_RESET(UInt8)
    | COM_SET_OPTION(UInt8)
    | COM_STMT_FETCH(UInt8)
    | COM_DAEMON(UInt8)
    | COM_BINLOG_DUMP_GTID(UInt8)
    | COM_RESET_CONNECTION(UInt8)

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
