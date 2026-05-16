// 严格翻译自: src/sql/postgres/CommandTag.zig
// PostgreSQL 命令标签
package bao_sql.postgres

/// 已知的命令类型
/// 对应 Bun: CommandTag.KnownCommand
public enum KnownCommand {
    | INSERT
    | DELETE
    | UPDATE
    | MERGE
    | SELECT
    | MOVE
    | FETCH
    | COPY

    /// 从字符串解析已知命令
    public static func fromStr(s: String): ?KnownCommand {
        if (s == "INSERT") { return Some(KnownCommand.INSERT) }
        if (s == "DELETE") { return Some(KnownCommand.DELETE) }
        if (s == "UPDATE") { return Some(KnownCommand.UPDATE) }
        if (s == "MERGE") { return Some(KnownCommand.MERGE) }
        if (s == "SELECT") { return Some(KnownCommand.SELECT) }
        if (s == "MOVE") { return Some(KnownCommand.MOVE) }
        if (s == "FETCH") { return Some(KnownCommand.FETCH) }
        if (s == "COPY") { return Some(KnownCommand.COPY) }
        return None
    }
}

/// PostgreSQL 命令完成标签
/// 对于 INSERT, 标签是 INSERT oid rows
/// 对于 DELETE, 标签是 DELETE rows
/// 对应 Bun: CommandTag (union enum)
public enum CommandTag {
    | INSERT(UInt64)
    | DELETE(UInt64)
    | UPDATE(UInt64)
    | MERGE(UInt64)
    | SELECT(UInt64)
    | MOVE(UInt64)
    | FETCH(UInt64)
    | COPY(UInt64)
    | other(String)

    /// 从标签字符串初始化命令标签
    /// 对应 Bun: CommandTag.init
    public static func fromTag(tag: String): CommandTag {
        // 查找第一个空格位置
        let firstSpaceIndex = indexOfSpace(tag)
        if (firstSpaceIndex.isNone()) {
            return CommandTag.other(tag)
        }
        let spaceIdx = firstSpaceIndex.getOrThrow()

        let cmdStr = tag[0..spaceIdx]
        let cmdOpt = KnownCommand.fromStr(cmdStr)
        if (cmdOpt.isNone()) {
            return CommandTag.other(tag)
        }

        let cmd = cmdOpt.getOrThrow()
        let afterFirstSpace = spaceIdx + 1
        var numberPart: String = ""

        numberPart = parseNumberPart(cmd, tag, afterFirstSpace)

        let number = parseUInt64(numberPart)
        if (number.isNone()) {
            return CommandTag.other(tag)
        }

        let numVal = number.getOrThrow()
        match (cmd) {
            case KnownCommand.INSERT => CommandTag.INSERT(numVal)
            case KnownCommand.DELETE => CommandTag.DELETE(numVal)
            case KnownCommand.UPDATE => CommandTag.UPDATE(numVal)
            case KnownCommand.MERGE => CommandTag.MERGE(numVal)
            case KnownCommand.SELECT => CommandTag.SELECT(numVal)
            case KnownCommand.MOVE => CommandTag.MOVE(numVal)
            case KnownCommand.FETCH => CommandTag.FETCH(numVal)
            case KnownCommand.COPY => CommandTag.COPY(numVal)
        }
    }

    private static func indexOfSpace(s: String): ?Int64 {
        let bytes = s.toArray()
        for (i in 0..bytes.size) {
            if (bytes[i] == 0x20) {
                return Some(Int64(i))
            }
        }
        return None
    }

    private static func parseNumberPart(cmd: KnownCommand, tag: String, afterFirstSpace: Int64): String {
        match (cmd) {
            case KnownCommand.INSERT => parseInsertNumberPart(tag, afterFirstSpace)
            case _ => tag[afterFirstSpace..tag.size]
        }
    }

    private static func parseInsertNumberPart(tag: String, afterFirstSpace: Int64): String {
        // INSERT 的格式是 "INSERT oid rows"，需要跳过 oid
        let remaining = tag[afterFirstSpace..tag.size]
        let secondSpace = indexOfSpace(remaining)
        if (secondSpace.isNone()) {
            return ""
        }
        let ss = secondSpace.getOrThrow()
        return remaining[(ss + 1)..remaining.size]
    }

    private static func parseUInt64(s: String): ?UInt64 {
        var result: UInt64 = 0
        let bytes = s.toArray()
        for (i in 0..bytes.size) {
            let b = bytes[i]
            if (b >= 0x30 && b <= 0x39) {
                result = result * 10 + UInt64(b - 0x30)
            } else {
                return None
            }
        }
        return Some(result)
    }
}
