// 严格翻译自: src/sql/postgres/protocol/ErrorResponse.zig
// PostgreSQL ErrorResponse 消息
package bao_sql.postgres.protocol

import std.collection.ArrayList as StdArrayList

/// PostgreSQL ErrorResponse 消息
/// 对应 Bun: ErrorResponse
public class ErrorResponse {
    public var messages: StdArrayList<FieldMessage>

    public init() {
        messages = StdArrayList<FieldMessage>()
    }

    /// 释放资源
    /// 对应 Bun: ErrorResponse.deinit
    public func deinit(): Unit {
        // Cangjie has GC, no manual deinit needed
    }

    /// 从读取器解码
    /// 对应 Bun: ErrorResponse.decodeInternal
    public static func decode(reader: StackReaderImpl): ?ErrorResponse {
        let result = ErrorResponse()

        let length = reader.length()
        if (length.isNone()) { return None }

        var remainingBytes = Int64(length.getOrThrow())
        if (remainingBytes < 4) { return None }
        remainingBytes -= 4

        if (remainingBytes > 0) {
            let msgs = FieldMessage.decodeList(reader)
            if (msgs.isNone()) { return None }
            result.messages = msgs.getOrThrow()
        }

        return result
    }
}
