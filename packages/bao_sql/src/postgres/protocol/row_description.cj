// 严格翻译自: src/sql/postgres/protocol/RowDescription.zig
// PostgreSQL RowDescription 消息
package bao_sql.postgres.protocol

/// PostgreSQL RowDescription 消息
/// 对应 Bun: RowDescription
public class RowDescription {
    public var fields: Array<FieldDescription>

    public init() {
        fields = Array<FieldDescription>()
    }

    /// 释放资源
    /// 对应 Bun: RowDescription.deinit
    public func deinit(): Unit {
        // Cangjie has GC, no manual deinit needed
    }

    /// 从读取器解码
    /// 对应 Bun: RowDescription.decodeInternal
    public static func decode(reader: StackReaderImpl): ?RowDescription {
        let result = RowDescription()

        let length = reader.length()
        if (length.isNone()) { return None }

        var remainingBytes = Int64(length.getOrThrow()) - 4

        let fieldCount = reader.short()
        if (fieldCount.isNone()) { return None }
        let count = Int64(fieldCount.getOrThrow())
        let safeCount = if (count < 0) { Int64(0) } else { count }

        result.fields = Array<FieldDescription>(safeCount, repeat: FieldDescription())

        for (i in 0..safeCount) {
            let field = FieldDescription.decode(reader)
            if (field.isNone()) { return None }
            result.fields[i] = field.getOrThrow()
        }

        return result
    }
}
