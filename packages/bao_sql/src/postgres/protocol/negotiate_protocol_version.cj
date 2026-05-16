// 严格翻译自: src/sql/postgres/protocol/NegotiateProtocolVersion.zig
// PostgreSQL NegotiateProtocolVersion 消息
package bao_sql.postgres.protocol

import std.collection.ArrayList as StdArrayList

/// PostgreSQL NegotiateProtocolVersion 消息
/// 对应 Bun: NegotiateProtocolVersion
public class NegotiateProtocolVersion {
    public var version: UInt32
    public var unrecognizedOptions: StdArrayList<String>

    public init() {
        version = 0
        unrecognizedOptions = StdArrayList<String>()
    }

    /// 从读取器解码
    /// 对应 Bun: NegotiateProtocolVersion.decodeInternal
    public static func decode(reader: StackReaderImpl): ?NegotiateProtocolVersion {
        let result = NegotiateProtocolVersion()

        let length = reader.length()
        if (length.isNone()) { return None }

        let version = reader.int4()
        if (version.isNone()) { return None }
        result.version = version.getOrThrow()

        let optionCount = reader.int4()
        if (optionCount.isNone()) { return None }
        let count = if (Int64(optionCount.getOrThrow()) < 0) { Int64(0) } else { Int64(optionCount.getOrThrow()) }

        for (_ in 0..count) {
            let option = reader.readZ()
            if (option.isNone()) { break }
            let optSlice = option.getOrThrow().slice()
            if (optSlice.size == 0) { break }
            result.unrecognizedOptions.add(String.fromUtf8(optSlice))
        }

        return result
    }
}
