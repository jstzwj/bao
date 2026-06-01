// MySQL HandshakeV10 协议包 (服务端初始握手)
// 严格翻译自: src/sql/mysql/protocol/HandshakeV10.zig
package bao_runtime.sql.mysql

import bao_core.*
import bao_sql.*
import bao_sql.mysql.protocol.*
import bao_runtime.sql.shared.*

/// MySQL 服务端初始握手包 (Protocol 10)
/// 对应 Bun: HandshakeV10
/// 连接建立后服务器发送的第一个包
public class HandshakeV10 {
    /// 协议版本 (固定 10)
    public var protocolVersion: UInt8
    /// 服务器版本字符串
    public var serverVersion: SQLData
    /// 连接 ID
    public var connectionId: UInt32
    /// 认证数据第 1 部分 (8 字节)
    public var authPluginDataPart1: Array<UInt8>
    /// 认证数据第 2 部分
    public var authPluginDataPart2: Array<UInt8>
    /// 服务器能力标志
    public var capabilityFlags: Capabilities
    /// 字符集
    public var characterSet: CharacterSet
    /// 状态标志
    public var statusFlags: StatusFlags
    /// 认证插件名称
    public var authPluginName: SQLData

    public init() {
        protocolVersion = 10
        serverVersion = SQLData.empty()
        connectionId = 0
        authPluginDataPart1 = Array<UInt8>(8, repeat: 0)
        authPluginDataPart2 = Array<UInt8>()
        capabilityFlags = Capabilities()
        characterSet = CharacterSet.Unknown
        statusFlags = StatusFlags()
        authPluginName = SQLData.empty()
    }

    /// 释放资源
    /// 对应 Bun: HandshakeV10.deinit
    public func deinit(): Unit {
        serverVersion.deinit()
        authPluginName.deinit()
    }

    /// 从 Reader 解码
    /// 对应 Bun: HandshakeV10.decodeInternal
    public func decode(reader: MySQLPacketReader): Unit {
        // 协议版本
        protocolVersion = reader.int8()
        if (protocolVersion != 10) {
            return  // UnsupportedProtocolVersion
        }

        // 服务器版本 (null 终止字符串)
        serverVersion = SQLData.fromTemporary(reader.readZ())

        // 连接 ID (4 字节)
        connectionId = reader.int32()

        // 认证数据第 1 部分 (8 字节)
        let authData1 = reader.read(8)
        authPluginDataPart1 = authData1

        // 跳过填充字节
        reader.skip(1)

        // 能力标志 (低 2 字节)
        let capabilitiesLower = reader.int16()

        // 字符集
        characterSet = CharacterSet.Unknown

        // 状态标志
        statusFlags = StatusFlags.fromInt(reader.int16())

        // 能力标志 (高 2 字节)
        let capabilitiesUpper = reader.int16()
        capabilityFlags = Capabilities.fromInt(
            UInt32(capabilitiesUpper) << 16 | UInt32(capabilitiesLower)
        )

        // 认证数据长度
        var authPluginDataLen = Int64(reader.int8())
        if (authPluginDataLen < 21) {
            authPluginDataLen = 21
        }

        // 跳过保留字段 (10 字节)
        reader.skip(10)

        // 认证数据第 2 部分
        let remainingAuthLen = if (13 > authPluginDataLen - 8) { Int64(13) } else { authPluginDataLen - 8 }
        let authData2 = reader.read(remainingAuthLen)
        authPluginDataPart2 = authData2

        // 认证插件名称
        if (capabilityFlags.CLIENT_PLUGIN_AUTH) {
            authPluginName = SQLData.fromTemporary(reader.readZ())
        }
    }
}
