// 严格翻译自: src/sql/postgres/protocol/DataRow.zig
// PostgreSQL DataRow 消息
package bao_sql.postgres.protocol

import bao_sql.shared.Data

/// PostgreSQL DataRow 消息 - 包含一行数据中的各字段值
/// 对应 Bun: DataRow
///
/// null_int4: 表示 NULL 值的特殊长度 (-1 作为 uint32)
public class DataRow {
    public static let NULL_INT4: UInt32 = 4294967295

    /// 解码一行数据，对每个字段调用回调函数
    /// 对应 Bun: DataRow.decode
    ///
    /// - context: 用户上下文
    /// - reader: 读取器
    /// - forEach: 对每个字段调用的回调 (context, index, bytes?) -> shouldContinue
    public static func decode(reader: StackReaderImpl, forEach: (Int64, ?Data) -> Bool): ?AnyPostgresError {
        var remainingBytes = reader.length()
        if (remainingBytes.isNone()) { return AnyPostgresError.ShortRead }
        var remaining = Int64(remainingBytes.getOrThrow()) - 4

        let fieldCountVal = reader.short()
        if (fieldCountVal.isNone()) { return AnyPostgresError.ShortRead }
        let fieldCount = Int64(fieldCountVal.getOrThrow())
        let remainingFields = if (fieldCount < 0) { Int64(0) } else { fieldCount }

        for (index in 0..remainingFields) {
            let byteLength = reader.int4()
            if (byteLength.isNone()) { return AnyPostgresError.ShortRead }
            let len = byteLength.getOrThrow()

            if (len == 0) {
                let empty = Data.emptyData()
                if (!forEach(index, Some(empty))) { break }
            } else if (len == DataRow.NULL_INT4) {
                if (!forEach(index, None)) { break }
            } else {
                let bytes = reader.read(Int64(len))
                if (bytes.isNone()) { return AnyPostgresError.ShortRead }
                if (!forEach(index, Some(bytes.getOrThrow()))) { break }
            }
        }
        return None
    }
}
