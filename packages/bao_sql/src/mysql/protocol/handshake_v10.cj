// MySQL 握手 V10 包
// 对应 Bun: src/sql/mysql/protocol/HandshakeV10.zig
package bao_sql

/// MySQL 服务器初始握手包 (协议版本 10)
/// 对应 Bun: HandshakeV10 (struct)
///
/// 服务器在连接建立后首先发送此包，
/// 包含服务器版本、连接 ID、认证插件数据等信息
public class HandshakeV10 {
    /// 协议版本 (固定为 10)
    /// 对应 Bun: protocol_version u8
    public var protocolVersion: UInt8

    /// 服务器版本 (null 终止字符串)
    /// 对应 Bun: server_version Data
    public var serverVersion: Array<UInt8>

    /// 连接 ID (4 字节)
    /// 对应 Bun: connection_id u32
    public var connectionId: UInt32

    /// 认证插件数据第一部分 (8 字节)
    /// 对应 Bun: auth_plugin_data_part_1 [8]u8
    public var authPluginDataPart1: Array<UInt8>

    /// 认证插件数据第二部分
    /// 对应 Bun: auth_plugin_data_part_2 []const u8
    public var authPluginDataPart2: Array<UInt8>

    /// 能力标志
    /// 对应 Bun: capability_flags Capabilities
    public var capabilityFlags: Capabilities

    /// 字符集
    /// 对应 Bun: character_set CharacterSet
    public var characterSet: UInt8

    /// 状态标志
    /// 对应 Bun: status_flags StatusFlags
    public var statusFlags: StatusFlags

    /// 认证插件名称
    /// 对应 Bun: auth_plugin_name Data
    public var authPluginName: Array<UInt8>

    public init() {
        protocolVersion = 10
        serverVersion = Array<UInt8>()
        connectionId = 0
        authPluginDataPart1 = Array<UInt8>(8)
        authPluginDataPart2 = Array<UInt8>()
        capabilityFlags = Capabilities()
        characterSet = 0
        statusFlags = StatusFlags()
        authPluginName = Array<UInt8>()
    }

    /// 释放资源
    /// 对应 Bun: HandshakeV10.deinit
    public func deinit(): Unit {
        serverVersion = Array<UInt8>()
        authPluginName = Array<UInt8>()
    }

    /// 从读取器解码握手包
    /// 对应 Bun: HandshakeV10.decodeInternal
    public func decode(reader: MySQLPacketReader): Unit {
        // 协议版本
        protocolVersion = reader.int8()
        if (protocolVersion != 10) {
            throw MySQLError.UnsupportedProtocolVersion
        }

        // 服务器版本 (null 终止字符串)
        serverVersion = reader.readZ()

        // 连接 ID (4 字节)
        connectionId = reader.int32()

        // 认证插件数据第一部分 (8 字节)
        authPluginDataPart1 = reader.read(8)

        // 跳过填充字节
        reader.skip(1)

        // 能力标志 (低 2 字节)
        let capabilitiesLower = UInt32(reader.int16())

        // 字符集
        characterSet = reader.int8()

        // 状态标志
        statusFlags = StatusFlags.fromInt(reader.int16())

        // 能力标志 (高 2 字节)
        let capabilitiesUpper = UInt32(reader.int16())
        capabilityFlags = Capabilities.fromInt((capabilitiesUpper << 16) | capabilitiesLower)

        // 认证插件数据长度
        var authPluginDataLen = Int64(reader.int8())
        if (authPluginDataLen < 21) {
            authPluginDataLen = 21
        }

        // 跳过保留字节 (10 字节)
        reader.skip(10)

        // 认证插件数据第二部分
        let remainingAuthLen = Int64.max(13, authPluginDataLen - 8)
        authPluginDataPart2 = reader.read(remainingAuthLen)

        // 认证插件名称
        if (capabilityFlags.CLIENT_PLUGIN_AUTH) {
            authPluginName = reader.readZ()
        }
    }
}
