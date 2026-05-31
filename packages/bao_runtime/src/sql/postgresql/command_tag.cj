// PostgreSQL 命令标签 - 解析命令完成标签
// 严格翻译自: bun/src/sql/postgres/CommandTag.zig
//   pub const CommandTag = union(enum) { INSERT: u64, DELETE: u64, ... };
package bao_runtime.sql.postgresql

/// PostgreSQL 命令标签
/// 解析 CommandComplete 消息中的标签字符串
/// 对应 Bun CommandTag
public enum CommandTag {
    | INSERT(UInt64)       // INSERT oid rows
    | DELETE(UInt64)       // DELETE rows
    | UPDATE(UInt64)       // UPDATE rows
    | MERGE(UInt64)        // MERGE rows
    | SELECT(UInt64)       // SELECT rows
    | MOVE(UInt64)         // MOVE rows
    | FETCH(UInt64)        // FETCH rows
    | COPY(UInt64)         // COPY rows
    | Other(String)        // 其他命令标签

    /// 从标签字符串解析 CommandTag
    /// 对应 Bun CommandTag.init()
    /// 标签格式如 "SELECT 5", "INSERT 0 1", "UPDATE 3"
    public static func init(tag: String): CommandTag {
        // 查找第一个空格
        let spaceIndex = tag.indexOf(' ')
        match (spaceIndex) {
            case None => return Other(tag)
            case Some(firstSpace) => {
                let cmdStr = tag.substring(0, firstSpace)
                let afterTag = tag.substring(firstSpace + 1)

                // 匹配已知命令
                let cmd = parseKnownCommand(cmdStr)
                match (cmd) {
                    case None => return Other(tag)
                    case Some(knownCmd) => {
                        let number = parseRowCount(knownCmd, afterTag, tag)
                        match (number) {
                            case Some(n) => buildTag(knownCmd, n)
                            case None => Other(tag)
                        }
                    }
                }
            }
        }
    }

    /// 获取受影响的行数
    public func rowCount(): ?UInt64 {
        match (this) {
            case INSERT(n) => n
            case DELETE(n) => n
            case UPDATE(n) => n
            case MERGE(n) => n
            case SELECT(n) => n
            case MOVE(n) => n
            case FETCH(n) => n
            case COPY(n) => n
            case Other(_) => None
        }
    }

    /// 获取命令名称
    public func commandName(): String {
        match (this) {
            case INSERT(_) => "INSERT"
            case DELETE(_) => "DELETE"
            case UPDATE(_) => "UPDATE"
            case MERGE(_) => "MERGE"
            case SELECT(_) => "SELECT"
            case MOVE(_) => "MOVE"
            case FETCH(_) => "FETCH"
            case COPY(_) => "COPY"
            case Other(s) => s
        }
    }

    // ========================================================================
    // 私有辅助方法
    // ========================================================================

    private enum KnownCommand {
        | INSERT
        | DELETE
        | UPDATE
        | MERGE
        | SELECT
        | MOVE
        | FETCH
        | COPY
    }

    private static func parseKnownCommand(s: String): ?KnownCommand {
        match (s) {
            case "INSERT" => KnownCommand.INSERT
            case "DELETE" => KnownCommand.DELETE
            case "UPDATE" => KnownCommand.UPDATE
            case "MERGE" => KnownCommand.MERGE
            case "SELECT" => KnownCommand.SELECT
            case "MOVE" => KnownCommand.MOVE
            case "FETCH" => KnownCommand.FETCH
            case "COPY" => KnownCommand.COPY
            case _ => None
        }
    }

    private static func parseRowCount(cmd: KnownCommand, afterTag: String, fullTag: String): ?UInt64 {
        match (cmd) {
            case KnownCommand.INSERT => {
                // INSERT 格式: "INSERT oid rows"
                // 需要跳过 oid 部分
                let secondSpace = afterTag.indexOf(' ')
                match (secondSpace) {
                    case None => None
                    case Some(idx) => {
                        let rowStr = afterTag.substring(idx + 1)
                        UInt64.parse(rowStr)
                    }
                }
            }
            case _ => {
                // 其他命令格式: "CMD rows"
                UInt64.parse(afterTag)
            }
        }
    }

    private static func buildTag(cmd: KnownCommand, n: UInt64): CommandTag {
        match (cmd) {
            case KnownCommand.INSERT => INSERT(n)
            case KnownCommand.DELETE => DELETE(n)
            case KnownCommand.UPDATE => UPDATE(n)
            case KnownCommand.MERGE => MERGE(n)
            case KnownCommand.SELECT => SELECT(n)
            case KnownCommand.MOVE => MOVE(n)
            case KnownCommand.FETCH => FETCH(n)
            case KnownCommand.COPY => COPY(n)
        }
    }
}
