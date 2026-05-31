// MySQL HandshakeResponse41 协议包 (客户端认证响应)
// 严格翻译自: src/sql/mysql/protocol/HandshakeResponse41.zig
package bao_runtime.sql.mysql

import bao_core.*
import bao_runtime.sql.shared.*

/// MySQL 客户端认证响应包 (4.1 协议)
/// 对应 Bun: HandshakeResponse41
/// 客户端收到 HandshakeV10 后发送此包
public class HandshakeResponse41 {
    /// 客户端能力标志
    public var capabilityFlags: Capabilities
    /// 最大包大小 (默认 16MB)
    public var maxPacketSize: UInt32
    /// 字符集
    public var characterSet: CharacterSet
    /// 用户名
    public var username: SQLData
    /// 认证响应数据
    public var authResponse: SQLData
    /// 数据库名
    public var database: SQLData
    /// 认证插件名
    public var authPluginName: SQLData
    /// 连接属性
    public var connectAttrs: HashMap<String, String>
    /// 序列号
    public var sequenceId: UInt8

    public init() {
        capabilityFlags = Capabilities()
        maxPacketSize = 0xFFFFFF  // 16MB
        characterSet = CharacterSet.DEFAULT
        username = SQLData.empty()
        authResponse = SQLData.empty()
        database = SQLData.empty()
        authPluginName = SQLData.empty()
        connectAttrs = HashMap<String, String>()
        sequenceId = 0
    }

    /// 释放资源
    /// 对应 Bun: HandshakeResponse41.deinit
    public func deinit(): Unit {
        username.deinit()
        authResponse.deinit()
        database.deinit()
        authPluginName.deinit()
    }

    /// 编码到 Writer
    /// 对应 Bun: HandshakeResponse41.writeInternal
    public func write(writer: MySQLPacketWriter): Unit {
        capabilityFlags.CLIENT_CONNECT_ATTRS = connectAttrs.size > 0

        // 开始包
        writer.start(sequenceId)

        // 写入客户端能力标志 (4 字节)
        let caps = capabilityFlags.toInt()
        writer.writeInt32(caps)

        // 写入最大包大小 (4 字节)
        writer.writeInt32(maxPacketSize)

        // 写入字符集 (1 字节)
        writer.writeInt8(characterSet.value)

        // 写入 23 字节填充
        writer.writeZeros(23)

        // 写入用户名 (null 终止)
        writer.writeNullTerminated(username.slice())

        // 写入认证响应 (根据能力标志)
        let authData = authResponse.slice()
        if (capabilityFlags.CLIENT_PLUGIN_AUTH_LENENC_CLIENT_DATA) {
            writer.writeLengthEncodedString(authData)
        } else if (capabilityFlags.CLIENT_SECURE_CONNECTION) {
            writer.writeInt8(UInt8(authData.size))
            writer.writeBytes(authData)
        } else {
            writer.writeNullTerminated(authData)
        }

        // 写入数据库名
        if (capabilityFlags.CLIENT_CONNECT_WITH_DB && database.len() > 0) {
            writer.writeNullTerminated(database.slice())
        }

        // 写入认证插件名
        if (capabilityFlags.CLIENT_PLUGIN_AUTH) {
            writer.writeNullTerminated(authPluginName.slice())
        }

        // 写入连接属性
        if (capabilityFlags.CLIENT_CONNECT_ATTRS) {
            var totalLength: Int64 = 0
            for ((key, value) in connectAttrs) {
                totalLength += encodeLengthInt(UInt64(key.size)).size
                totalLength += key.size
                totalLength += encodeLengthInt(UInt64(value.size)).size
                totalLength += value.size
            }

            writer.writeLengthEncodedInt(UInt64(totalLength))

            for ((key, value) in connectAttrs) {
                writer.writeLengthEncodedString(key.toArray())
                writer.writeLengthEncodedString(value.toArray())
            }
        }

        // 结束包
        writer.endPacket()
    }
}
