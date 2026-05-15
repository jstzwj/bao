// MySQL 认证切换请求
// 对应 Bun: src/sql/mysql/protocol/AuthSwitchRequest.zig
package bao_sql.mysql.protocol

/// MySQL 认证切换请求包
/// 对应 Bun: AuthSwitchRequest (struct)
///
/// 服务器发送此包要求客户端切换到不同的认证方法
public class AuthSwitchRequest {
    /// 包头 (0xfe)
    /// 对应 Bun: header u8
    public var header: UInt8

    /// 插件名称 (EOF 字符串)
    /// 对应 Bun: plugin_name Data
    public var pluginName: Array<UInt8>

    /// 插件数据 (EOF 字符串)
    /// 对应 Bun: plugin_data Data
    public var pluginData: Array<UInt8>

    /// 包大小
    /// 对应 Bun: packet_size u24
    public var packetSize: UInt32

    public init() {
        header = 0xfe
        pluginName = Array<UInt8>()
        pluginData = Array<UInt8>()
        packetSize = 0
    }

    public init(packetSize: UInt32) {
        header = 0xfe
        pluginName = Array<UInt8>()
        pluginData = Array<UInt8>()
        this.packetSize = packetSize
    }

    /// 释放资源
    /// 对应 Bun: AuthSwitchRequest.deinit
    public func deinit(): Unit {
        pluginName = Array<UInt8>()
        pluginData = Array<UInt8>()
    }

    /// 从读取器解码认证切换请求
    /// 对应 Bun: AuthSwitchRequest.decodeInternal
    public func decode(reader: MySQLPacketReader): Unit {
        header = reader.int8()
        if (header != 0xfe) {
            throw MySQLError.InvalidAuthSwitchRequest
        }

        // 读取剩余数据
        let remainingSize = Int64(packetSize) - 1
        let remaining = reader.read(remainingSize)

        // 在数据中查找 null 分隔符
        var zeroIndex = -1
        for (i in 0..remaining.size) {
            if (remaining[i] == 0) {
                zeroIndex = i
                break
            }
        }

        if (zeroIndex >= 0) {
            // EOF 字符串: plugin_name 以 null 结尾
            pluginName = remaining[0..zeroIndex]
            // 剩余部分为插件数据
            pluginData = remaining[(zeroIndex + 1)..remaining.size]
            return
        }

        throw MySQLError.InvalidAuthSwitchRequest
    }
}
