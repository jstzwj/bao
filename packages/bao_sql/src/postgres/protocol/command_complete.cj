// 严格翻译自: src/sql/postgres/protocol/CommandComplete.zig
// PostgreSQL CommandComplete 消息
package bao_sql.postgres.protocol

import bao_sql.shared.Data

/// PostgreSQL CommandComplete 消息
/// 包含命令完成标签
/// 对应 Bun: CommandComplete
public class CommandComplete {
    public var commandTag: Data

    public init() {
        commandTag = Data.emptyData()
    }

    /// 释放资源
    /// 对应 Bun: CommandComplete.deinit
    public func deinit(): Unit {
        // Cangjie has GC, no manual deinit needed
    }

    /// 从读取器解码
    /// 对应 Bun: CommandComplete.decodeInternal
    public static func decode(reader: StackReaderImpl): ?CommandComplete {
        let result = CommandComplete()

        let length = reader.length()
        if (length.isNone()) { return None }

        let tag = reader.readZ()
        if (tag.isNone()) { return None }

        result.commandTag = tag.getOrThrow()
        return result
    }
}
