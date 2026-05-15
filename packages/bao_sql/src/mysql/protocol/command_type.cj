// MySQL 命令类型
// 对应 Bun: src/sql/mysql/protocol/CommandType.zig
package bao_sql.mysql.protocol

/// MySQL 命令包类型
/// 对应 Bun: CommandType (enum u8)
public enum CommandType {
}
    }

    public func value(): UInt8 {
        match (this) {
            | COM_QUIT(v) => v
            | COM_INIT_DB(v) => v
            | COM_QUERY(v) => v
            | COM_FIELD_LIST(v) => v
            | COM_CREATE_DB(v) => v
            | COM_DROP_DB(v) => v
            | COM_REFRESH(v) => v
            | COM_SHUTDOWN(v) => v
            | COM_STATISTICS(v) => v
            | COM_PROCESS_INFO(v) => v
            | COM_CONNECT(v) => v
            | COM_PROCESS_KILL(v) => v
            | COM_DEBUG(v) => v
            | COM_PING(v) => v
            | COM_TIME(v) => v
            | COM_DELAYED_INSERT(v) => v
            | COM_CHANGE_USER(v) => v
            | COM_BINLOG_DUMP(v) => v
            | COM_TABLE_DUMP(v) => v
            | COM_CONNECT_OUT(v) => v
            | COM_REGISTER_SLAVE(v) => v
            | COM_STMT_PREPARE(v) => v
            | COM_STMT_EXECUTE(v) => v
            | COM_STMT_SEND_LONG_DATA(v) => v
            | COM_STMT_CLOSE(v) => v
            | COM_STMT_RESET(v) => v
            | COM_SET_OPTION(v) => v
            | COM_STMT_FETCH(v) => v
            | COM_DAEMON(v) => v
            | COM_BINLOG_DUMP_GTID(v) => v
            | COM_RESET_CONNECTION(v) => v
        }
    }
}
