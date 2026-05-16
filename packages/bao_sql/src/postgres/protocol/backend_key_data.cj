// 严格翻译自: src/sql/postgres/protocol/BackendKeyData.zig
// PostgreSQL 后端密钥数据消息
package bao_sql.postgres.protocol

/// PostgreSQL 后端密钥数据
/// 对应 Bun: BackendKeyData
public class BackendKeyData {
    public var processId: UInt32
    public var secretKey: UInt32

    public init() {
        processId = 0
        secretKey = 0
    }

    /// 从读取器解码
    /// 对应 Bun: BackendKeyData.decodeInternal
    public static func decode(reader: StackReaderImpl): ?BackendKeyData {
        let result = BackendKeyData()

        // 验证长度为 12
        let length = reader.int4()
        if (length.isNone()) { return None }
        if (length.getOrThrow() != 12) { return None }

        let pid = reader.int4()
        if (pid.isNone()) { return None }
        result.processId = pid.getOrThrow()

        let key = reader.int4()
        if (key.isNone()) { return None }
        result.secretKey = key.getOrThrow()

        return result
    }
}
