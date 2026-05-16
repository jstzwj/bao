// MySQL 握手响应 4.1
// 对应 Bun: src/sql/mysql/protocol/HandshakeResponse41.zig
package bao_sql.mysql.protocol

import std.collection.*

/// MySQL 客户端认证响应 (协议 4.1)
/// 对应 Bun: HandshakeResponse41 (struct)
///
/// 客户端在收到服务器握手包后发送此响应，
/// 包含能力标志、用户名、认证数据等信息
public class HandshakeResponse41 {
    /// 能力标志
    /// 对应 Bun: capability_flags Capabilities
    public var capabilityFlags: Capabilities

    /// 最大包大小 (默认 16MB)
    /// 对应 Bun: max_packet_size u32
    public var maxPacketSize: UInt32

    /// 字符集
    /// 对应 Bun: character_set CharacterSet
    public var characterSet: UInt8

    /// 用户名
    /// 对应 Bun: username Data
    public var username: Array<UInt8>

    /// 认证响应数据
    /// 对应 Bun: auth_response Data
    public var authResponse: Array<UInt8>

    /// 数据库名
    /// 对应 Bun: database Data
    public var database: Array<UInt8>

    /// 认证插件名称
    /// 对应 Bun: auth_plugin_name Data
    public var authPluginName: Array<UInt8>

    /// 连接属性
    /// 对应 Bun: connect_attrs bun.StringHashMapUnmanaged([]const u8)
    public var connectAttrs: HashMap<String, String>

    /// 序列号
    /// 对应 Bun: sequence_id u8
    public var sequenceId: UInt8

    public init() {
        capabilityFlags = Capabilities()
        maxPacketSize = 0xFFFFFF // 16MB
        characterSet = 45 // utf8mb4_general_ci
        username = Array<UInt8>()
        authResponse = Array<UInt8>()
        database = Array<UInt8>()
        authPluginName = Array<UInt8>()
        connectAttrs = HashMap<String, String>()
        sequenceId = 0
    }

    /// 释放资源
    /// 对应 Bun: HandshakeResponse41.deinit
    public func release(): Unit {
        username = Array<UInt8>()
        authResponse = Array<UInt8>()
        database = Array<UInt8>()
        authPluginName = Array<UInt8>()
        connectAttrs.clear()
    }

    /// 将握手响应写入到写入器
    /// 对应 Bun: HandshakeResponse41.writeInternal
    public func write(writer: MySQLPacketWriter): Unit {
        var packet = writer.start(sequenceId)

        capabilityFlags.CLIENT_CONNECT_ATTRS = connectAttrs.size > 0

        // 写入客户端能力标志 (4 字节)
        let caps = capabilityFlags.toInt()
        writer.int4(caps)

        // 写入最大包大小 (4 字节)
        writer.int4(maxPacketSize)

        // 写入字符集 (1 字节)
        writer.int1(characterSet)

        // 写入 23 字节填充
        writer.write(Array<UInt8>(23, repeat: UInt8(0)))

        // 写入用户名 (null 终止)
        writer.writeZ(username)

        // 根据能力标志写入认证响应
        if (capabilityFlags.CLIENT_PLUGIN_AUTH_LENENC_CLIENT_DATA) {
            writer.writeLengthEncodedString(authResponse)
        } else if (capabilityFlags.CLIENT_SECURE_CONNECTION) {
            writer.int1(UInt8(authResponse.size))
            writer.write(authResponse)
        } else {
            writer.writeZ(authResponse)
        }

        // 写入数据库名 (如果请求)
        if (capabilityFlags.CLIENT_CONNECT_WITH_DB && database.size > 0) {
            writer.writeZ(database)
        }

        // 写入认证插件名称 (如果支持)
        if (capabilityFlags.CLIENT_PLUGIN_AUTH) {
            writer.writeZ(authPluginName)
        }

        // 写入连接属性 (如果启用)
        if (capabilityFlags.CLIENT_CONNECT_ATTRS) {
            var totalLength: Int64 = 0
            for ((key, value) in connectAttrs) {
                totalLength += EncodeInt.encodeLengthInt(UInt64(key.toArray().size)).size
                totalLength += key.toArray().size
                totalLength += EncodeInt.encodeLengthInt(UInt64(value.toArray().size)).size
                totalLength += value.toArray().size
            }

            writer.writeLengthEncodedInt(UInt64(totalLength))

            for ((key, value) in connectAttrs) {
                writer.writeLengthEncodedString(key.toArray())
                writer.writeLengthEncodedString(value.toArray())
            }
        }

        packet.end()
    }
}
