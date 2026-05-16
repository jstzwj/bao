// 严格翻译自: src/sql/postgres/protocol/CopyFail.zig
// PostgreSQL CopyFail 消息
package bao_sql.postgres.protocol

import bao_sql.shared.Data
import bao_sql.postgres.types.IntTypes

/// PostgreSQL CopyFail 消息
/// 对应 Bun: CopyFail
public class CopyFail {
    public var message: Data

    public init() {
        message = Data.emptyData()
    }

    /// 从读取器解码
    /// 对应 Bun: CopyFail.decodeInternal
    public static func decode(reader: StackReaderImpl): ?CopyFail {
        let result = CopyFail()
        let _ = reader.int4()  // 读取长度

        let msg = reader.readZ()
        if (msg.isNone()) { return None }

        result.message = msg.getOrThrow()
        return result
    }

    /// 写入 CopyFail 消息
    /// 对应 Bun: CopyFail.writeInternal
    public func writeTo(writer: ArrayListWriter): Unit {
        let messageSlice = message.slice()
        let count: UInt32 = 4 + UInt32(messageSlice.size) + 1
        writer.write([UInt8(102)])
        writer.int4(count)
        writer.string(String.fromUtf8(messageSlice))
    }
}
