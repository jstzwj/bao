// 严格翻译自: src/sql/postgres/protocol/CopyData.zig
// PostgreSQL CopyData 消息
package bao_sql.postgres.protocol

import bao_sql.shared.Data
import bao_sql.postgres.types.IntTypes

/// PostgreSQL CopyData 消息
/// 对应 Bun: CopyData
public class CopyData {
    public var data: Data

    public init() {
        data = Data.emptyData()
    }

    /// 从读取器解码
    /// 对应 Bun: CopyData.decodeInternal
    public static func decode(reader: StackReaderImpl): ?CopyData {
        let result = CopyData()
        let length = reader.length()
        if (length.isNone()) { return None }

        let dataLen = Int64(length.getOrThrow()) - 5
        if (dataLen <= 0) { return None }

        let data = reader.read(dataLen)
        if (data.isNone()) { return None }

        result.data = data.getOrThrow()
        return result
    }

    /// 写入 CopyData 消息
    /// 对应 Bun: CopyData.writeInternal
    public func writeTo(writer: ArrayListWriter): Unit {
        let dataSlice = data.slice()
        let count: UInt32 = 4 + UInt32(dataSlice.size) + 1
        writer.write([UInt8(100)])
        writer.int4(count)
        writer.string(String.fromUtf8(dataSlice))
    }
}
