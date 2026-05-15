// 网络绑定模块
// 对应 Bun: src/runtime/node/node_net_binding.zig
// 严格翻译自: src/runtime/node/node_net_binding.zig
package bao_runtime.node

// ============================================================================
// 自动选择族默认值
// 对应 Bun: src/runtime/node/node_net_binding.zig - autoSelectFamilyDefault
// ============================================================================
public class NodeNetBinding {
    private static var autoSelectFamilyDefault: Bool = true
    private static var autoSelectFamilyAttemptTimeoutDefault: UInt32 = 250

    // 获取自动选择族默认值
    // 对应 Bun: src/runtime/node/node_net_binding.zig - getDefaultAutoSelectFamily
    public static func getDefaultAutoSelectFamily(): Bool {
        return autoSelectFamilyDefault
    }

    // 设置自动选择族默认值
    // 对应 Bun: src/runtime/node/node_net_binding.zig - setDefaultAutoSelectFamily
    public static func setDefaultAutoSelectFamily(value: Bool): Unit {
        autoSelectFamilyDefault = value
    }

    // 获取自动选择族尝试超时
    // 对应 Bun: src/runtime/node/node_net_binding.zig - getDefaultAutoSelectFamilyAttemptTimeout
    public static func getDefaultAutoSelectFamilyAttemptTimeout(): UInt32 {
        return autoSelectFamilyAttemptTimeoutDefault
    }

    // 设置自动选择族尝试超时
    // 对应 Bun: src/runtime/node/node_net_binding.zig - setDefaultAutoSelectFamilyAttemptTimeout
    public static func setDefaultAutoSelectFamilyAttemptTimeout(value: UInt32): Unit {
        var v = value
        if (v < 10) { v = 10 }
        autoSelectFamilyAttemptTimeoutDefault = v
    }
}

// ============================================================================
// Socket 地址
// 对应 Bun: src/runtime/node/node_net_binding.zig - SocketAddress
// ============================================================================
public class SocketAddress {
    public var address: String = ""
    public var port: UInt16 = 0
    public var family: String = "IPv4"
    public var flowlabel: UInt32 = 0
    public var scopeid: UInt32 = 0

    public init() {}

    public init(address: String, port: UInt16, family: String) {
        this.address = address
        this.port = port
        this.family = family
    }
}
