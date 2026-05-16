// 严格翻译自: src/sql/postgres/protocol/ParameterStatus.zig
// PostgreSQL ParameterStatus 消息
package bao_sql.postgres.protocol

import bao_sql.shared.Data

/// PostgreSQL ParameterStatus 消息
/// 对应 Bun: ParameterStatus
public class ParameterStatus {
    public var name: Data
    public var value: Data

    public init() {
        name = Data.emptyData()
        value = Data.emptyData()
    }

    /// 释放资源
    /// 对应 Bun: ParameterStatus.deinit
    public func deinit(): Unit {
        // Cangjie has GC, no manual deinit needed
    }

    /// 从读取器解码
    /// 对应 Bun: ParameterStatus.decodeInternal
    public static func decode(reader: StackReaderImpl): ?ParameterStatus {
        let result = ParameterStatus()

        let length = reader.length()
        if (length.isNone()) { return None }

        let name = reader.readZ()
        if (name.isNone()) { return None }
        result.name = name.getOrThrow()

        let value = reader.readZ()
        if (value.isNone()) { return None }
        result.value = value.getOrThrow()

        return result
    }
}
