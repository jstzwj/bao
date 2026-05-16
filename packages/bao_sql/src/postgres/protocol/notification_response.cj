// 严格翻译自: src/sql/postgres/protocol/NotificationResponse.zig
// PostgreSQL NotificationResponse 消息
package bao_sql.postgres.protocol

/// PostgreSQL NotificationResponse 消息 (LISTEN/NOTIFY)
/// 对应 Bun: NotificationResponse
public class NotificationResponse {
    public var pid: UInt32
    public var channel: String
    public var payload: String

    public init() {
        pid = 0
        channel = ""
        payload = ""
    }

    /// 释放资源
    /// 对应 Bun: NotificationResponse.deinit
    public func deinit(): Unit {
        channel = ""
        payload = ""
    }

    /// 从读取器解码
    /// 对应 Bun: NotificationResponse.decodeInternal
    public static func decode(reader: StackReaderImpl): ?NotificationResponse {
        let result = NotificationResponse()

        let length = reader.length()
        if (length.isNone()) { return None }

        let pid = reader.int4()
        if (pid.isNone()) { return None }
        result.pid = pid.getOrThrow()

        let channel = reader.readZ()
        if (channel.isNone()) { return None }
        result.channel = String.fromUtf8(channel.getOrThrow().slice())

        let payload = reader.readZ()
        if (payload.isNone()) { return None }
        result.payload = String.fromUtf8(payload.getOrThrow().slice())

        return result
    }
}
