// MySQL 命令包类型
// 严格翻译自: src/sql/mysql/protocol/CommandType.zig
package bao_runtime.sql.mysql

/// MySQL 协议命令类型
/// 对应 Bun: CommandType (enum u8)
public enum CommandType {
    | ComQuit        // 0x01
    | ComInitDb      // 0x02
    | ComQuery       // 0x03
    | ComFieldList   // 0x04
    | ComCreateDb    // 0x05
    | ComDropDb      // 0x06
    | ComRefresh     // 0x07
    | ComShutdown    // 0x08
    | ComStatistics  // 0x09
    | ComProcessInfo // 0x0a
    | ComConnect     // 0x0b
    | ComProcessKill // 0x0c
    | ComDebug       // 0x0d
}
