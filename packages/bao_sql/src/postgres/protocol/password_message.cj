// 严格翻译自: src/sql/postgres/protocol/PasswordMessage.zig
// PostgreSQL PasswordMessage 消息
package bao_sql.postgres.protocol

import bao_sql.shared.Data
import bao_sql.postgres.types.IntTypes

/// PostgreSQL PasswordMessage 消息
/// 对应 Bun: PasswordMessage
public class PasswordMessage {
    public var password: Data

    public init(password: Data) {
        this.password = password
    }

    /// 释放资源
    /// 对应 Bun: PasswordMessage.deinit
    public func deinit(): Unit {
        // Cangjie has GC, no manual deinit needed
    }

    /// 写入 Password 消息
    /// 对应 Bun: PasswordMessage.writeInternal
    public func writeTo(writer: ArrayListWriter): Unit {
        let passwordSlice = password.slice()
        let count: UInt32 = 4 + UInt32(passwordSlice.size) + 1
        writer.write([UInt8(112)])
        writer.int4(count)
        writer.string(String.fromUtf8(passwordSlice))
    }
}
