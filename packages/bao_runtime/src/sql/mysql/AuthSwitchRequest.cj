// MySQL AuthSwitchRequest 协议包
// 严格翻译自: src/sql/mysql/protocol/AuthSwitchRequest.zig
package bao_runtime.sql.mysql

import bao_core.*
import bao_runtime.sql.shared.*

/// MySQL 认证切换请求包
/// 对应 Bun: AuthSwitchRequest
/// 服务器要求客户端切换到另一种认证方式
public class AuthSwitchRequest {
    /// 包头 (0xfe)
    public var header: UInt8
    /// 插件名称
    public var pluginName: SQLData
    /// 插件数据 (nonce)
    public var pluginData: SQLData
    /// 包大小
    public var packetSize: UInt32

    public init() {
        header = 0xfe
        pluginName = SQLData.empty()
        pluginData = SQLData.empty()
        packetSize = 0
    }

    /// 释放资源
    /// 对应 Bun: AuthSwitchRequest.deinit
    public func deinit(): Unit {
        pluginName.deinit()
        pluginData.deinit()
    }

    /// 从 Reader 解码
    /// 对应 Bun: AuthSwitchRequest.decodeInternal
    public func decode(reader: MySQLPacketReader): Unit {
        header = reader.readInt8()
        if (header != 0xfe) {
            return  // InvalidAuthSwitchRequest
        }

        let remaining = reader.readBytes(Int64(packetSize) - 1)
        let remainingSlice = remaining.slice()

        // 查找 null 终止符分割 plugin_name 和 plugin_data
        var zeroPos = -1
        for (i in 0..remainingSlice.size) {
            if (remainingSlice[i] == 0) {
                zeroPos = i
                break
            }
        }

        if (zeroPos >= 0) {
            // EOF String: plugin_name\0plugin_data
            var nameBytes = Array<UInt8>()
            for (i in 0..zeroPos) {
                nameBytes.append(remainingSlice[i])
            }
            pluginName = SQLData.fromTemporary(nameBytes)

            var dataBytes = Array<UInt8>()
            for (i in (zeroPos + 1)..remainingSlice.size) {
                dataBytes.append(remainingSlice[i])
            }
            pluginData = SQLData.fromTemporary(dataBytes)
        }
        // InvalidAuthSwitchRequest
    }
}
