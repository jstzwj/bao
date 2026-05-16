// 严格翻译自: src/sql/postgres/protocol/ParameterDescription.zig
// PostgreSQL ParameterDescription 消息
package bao_sql.postgres.protocol

/// PostgreSQL ParameterDescription 消息
/// 对应 Bun: ParameterDescription
public class ParameterDescription {
    public var parameters: Array<UInt32>

    public init() {
        parameters = Array<UInt32>()
    }

    /// 从读取器解码
    /// 对应 Bun: ParameterDescription.decodeInternal
    public static func decode(reader: StackReaderImpl): ?ParameterDescription {
        let result = ParameterDescription()

        let length = reader.length()
        if (length.isNone()) { return None }
        var remainingBytes = Int64(length.getOrThrow()) - 4

        let count = reader.short()
        if (count.isNone()) { return None }
        let paramCount = Int64(count.getOrThrow())
        let safeCount = if (paramCount < 0) { Int64(0) } else { paramCount }

        // 读取参数类型 OID 数组
        let dataSize = safeCount * 4
        let data = reader.read(dataSize)
        if (data.isNone()) { return None }

        let dataSlice = data.getOrThrow().slice()
        result.parameters = Array<UInt32>(safeCount, repeat: UInt32(0))

        for (i in 0..safeCount) {
            let offset = i * 4
            // 大端字节序
            let value = UInt32(dataSlice[offset]) << 24 |
                        UInt32(dataSlice[offset + 1]) << 16 |
                        UInt32(dataSlice[offset + 2]) << 8 |
                        UInt32(dataSlice[offset + 3])
            result.parameters[i] = value
        }

        return result
    }
}
