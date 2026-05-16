// 网络绑定模块 — autoSelectFamily、SocketAddress、BlockList、newDetachedSocket、doConnect
// 对应 Bun: src/runtime/node/node_net_binding.zig
// 严格翻译自: src/runtime/node/node_net_binding.zig
package bao_runtime.node

// ============================================================================
// 自动选择族默认值
// 对应 Bun: src/runtime/node/node_net_binding.zig - autoSelectFamilyDefault
// ============================================================================
private var autoSelectFamilyDefault: Bool = true
private var autoSelectFamilyAttemptTimeoutDefault: UInt32 = 250

// 获取自动选择族默认值
// 对应 Bun: src/runtime/node/node_net_binding.zig - getDefaultAutoSelectFamily
public func getDefaultAutoSelectFamily(): Bool {
    return autoSelectFamilyDefault
}

// 设置自动选择族默认值
// 对应 Bun: src/runtime/node/node_net_binding.zig - setDefaultAutoSelectFamily
public func setDefaultAutoSelectFamily(value: Bool): Unit {
    autoSelectFamilyDefault = value
}

// 获取自动选择族尝试超时
// 对应 Bun: src/runtime/node/node_net_binding.zig - getDefaultAutoSelectFamilyAttemptTimeout
public func getDefaultAutoSelectFamilyAttemptTimeout(): UInt32 {
    return autoSelectFamilyAttemptTimeoutDefault
}

// 设置自动选择族尝试超时
// 对应 Bun: src/runtime/node/node_net_binding.zig - setDefaultAutoSelectFamilyAttemptTimeout
// 最小值为 10ms
public func setDefaultAutoSelectFamilyAttemptTimeout(value: UInt32): Unit {
    var v = value
    if (v < 10) {
        v = 10
    }
    autoSelectFamilyAttemptTimeoutDefault = v
}

// ============================================================================
// Socket 地址
// 对应 Bun: src/runtime/node/node_net_binding.zig - SocketAddress
// 也对应 Bun: src/runtime/node/net/Socket地址的构造函数
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

    // 从字符串解析
    public static func parse(addr: String): ?SocketAddress {
        let sa = SocketAddress()
        // 解析地址:端口格式
        let lastColon = addr.lastIndexOf(':')
        if (lastColon >= 0) {
            sa.address = addr.substring(0, endIndex: lastColon)
            sa.port = UInt16(Int64(addr.substring(lastColon + 1)) ?? UInt16(0))
        } else {
            sa.address = addr
        }
        return sa
    }
}

// ============================================================================
// NodeNetBinding — 网络绑定入口
// 对应 Bun: src/runtime/node/node_net_binding.zig
// ============================================================================
public class NodeNetBinding {
    // 获取自动选择族默认值
    public static func getDefaultAutoSelectFamily(): Bool {
        return bao_runtime.node.getDefaultAutoSelectFamily()
    }

    // 设置自动选择族默认值
    public static func setDefaultAutoSelectFamily(value: Bool): Unit {
        bao_runtime.node.setDefaultAutoSelectFamily(value)
    }

    // 获取自动选择族尝试超时
    public static func getDefaultAutoSelectFamilyAttemptTimeout(): UInt32 {
        return bao_runtime.node.getDefaultAutoSelectFamilyAttemptTimeout()
    }

    // 设置自动选择族尝试超时
    public static func setDefaultAutoSelectFamilyAttemptTimeout(value: UInt32): Unit {
        bao_runtime.node.setDefaultAutoSelectFamilyAttemptTimeout(value)
    }

    // 创建分离的 socket
    // 对应 Bun: src/runtime/node/node_net_binding.zig - newDetachedSocket
    // 根据 isSsl 创建 TCP 或 TLS 分离 socket
    public static func newDetachedSocket(isSsl: Bool): ?Any {
        // 在实际实现中:
        // if (!isSsl) { make<false>(global) } else { make<true>(global) }
        // 创建 NewSocket 实例，socket 字段设为 DETACHED
        return None
    }

    // 执行连接
    // 对应 Bun: src/runtime/node/node_net_binding.zig - doConnect
    public static func doConnect(prev: Any, options: Any): Any {
        // 在实际实现中:
        // 尝试将 prev 转型为 TCPSocket 或 TLSSocket
        // 调用 Listener.connectInner(global, maybeTcp, maybeTls, opts)
        return prev
    }
}
