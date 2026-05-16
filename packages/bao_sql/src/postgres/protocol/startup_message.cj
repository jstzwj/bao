// 严格翻译自: src/sql/postgres/protocol/StartupMessage.zig
// PostgreSQL StartupMessage 消息
package bao_sql.postgres.protocol

import bao_sql.shared.Data
import bao_sql.postgres.types.IntTypes

/// PostgreSQL StartupMessage 消息
/// 对应 Bun: StartupMessage
public class StartupMessage {
    public var user: Data
    public var database: Data
    public var options: Data

    public init(user: Data, database: Data, options: Data) {
        this.user = user
        this.database = database
        this.options = options
    }

    /// 写入 Startup 消息
    /// 对应 Bun: StartupMessage.writeInternal
    public func writeTo(writer: ArrayListWriter): Unit {
        let userSlice = user.slice()
        let databaseSlice = database.slice()
        let optionsSlice = options.slice()

        let userFieldCount = ZHelpers.zFieldCount("user", String.fromUtf8(userSlice))
        let dbFieldCount = ZHelpers.zFieldCount("database", String.fromUtf8(databaseSlice))
        let clientEncFieldCount = ZHelpers.zFieldCount("client_encoding", "UTF8")

        let count: UInt32 = 4 + 4 + UInt32(userFieldCount) + UInt32(dbFieldCount) +
            UInt32(clientEncFieldCount) + UInt32(optionsSlice.size) + 1

        writer.write(IntTypes.int32(count))
        writer.int4(196608)  // 协议版本 3.0

        writer.string("user")
        if (userSlice.size > 0) {
            writer.string(String.fromUtf8(userSlice))
        }

        writer.string("database")
        if (databaseSlice.size == 0) {
            // 如果未指定数据库，默认使用用户名
            writer.string(String.fromUtf8(userSlice))
        } else {
            writer.string(String.fromUtf8(databaseSlice))
        }

        writer.string("client_encoding")
        writer.string("UTF8")

        if (optionsSlice.size > 0) {
            writer.write(optionsSlice)
        }
        writer.write([UInt8(0)])
    }
}
