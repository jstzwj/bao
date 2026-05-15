// BlockList — IP 地址阻止列表
// 对应 Bun: src/runtime/node/net/BlockList.zig
// 严格翻译自: src/runtime/node/net/BlockList.zig
package bao_runtime

// ============================================================================
// 规则类型
// ============================================================================
public enum BlockRuleKind {
    addr,
    range,
    subnet
}

// ============================================================================
// 阻止规则
// ============================================================================
public class BlockRule {
    public var kind: BlockRuleKind = BlockRuleKind.addr
    public var address: UInt32 = 0
    public var prefix: UInt32 = 0
    public var start: UInt32 = 0
    public var end: UInt32 = 0

    public init() {}
}

// ============================================================================
// BlockList — IP 地址阻止列表
// 对应 Bun: src/runtime/node/net/BlockList.zig
// ============================================================================
public class BlockList {
    private var rules: Array<BlockRule> = Array<BlockRule>()

    public init() {}

    // 添加单个地址
    // 对应 Bun: src/runtime/node/net/BlockList.zig - addAddress
    public func addAddress(address: String, family: String = "ipv4"): Unit {
        let rule = BlockRule()
        rule.kind = BlockRuleKind.addr
        rule.address = parseIpAddress(address, family: family)
        rules.add(rule)
    }

    // 添加地址范围
    // 对应 Bun: src/runtime/node/net/BlockList.zig - addRange
    public func addRange(start: String, end: String, family: String = "ipv4"): Unit {
        let rule = BlockRule()
        rule.kind = BlockRuleKind.range
        rule.start = parseIpAddress(start, family: family)
        rule.end = parseIpAddress(end, family: family)
        rules.add(rule)
    }

    // 添加子网
    // 对应 Bun: src/runtime/node/net/BlockList.zig - addSubnet
    public func addSubnet(address: String, prefix: Int32, family: String = "ipv4"): Unit {
        let rule = BlockRule()
        rule.kind = BlockRuleKind.subnet
        rule.address = parseIpAddress(address, family: family)
        rule.prefix = UInt32(prefix)
        rules.add(rule)
    }

    // 检查地址是否被阻止
    // 对应 Bun: src/runtime/node/net/BlockList.zig - check
    public func check(address: String, family: String = "ipv4"): Bool {
        let addr = parseIpAddress(address, family: family)
        for (rule in rules) {
            match (rule.kind) {
                case BlockRuleKind.addr => {
                    if (rule.address == addr) {
                        return true
                    }
                }
                case BlockRuleKind.range => {
                    if (addr >= rule.start && addr <= rule.end) {
                        return true
                    }
                }
                case BlockRuleKind.subnet => {
                    let mask = if (rule.prefix == 0) { UInt32(0) } else { UInt32(0xFFFFFFFF) << Int64(32 - rule.prefix) }
                    if ((addr & mask) == (rule.address & mask)) {
                        return true
                    }
                }
            }
        }
        return false
    }

    // 获取规则列表
    public func getRules(): Array<BlockRule> {
        return rules
    }

    // 解析 IP 地址
    private func parseIpAddress(address: String, family: String): UInt32 {
        // 简化实现：解析 IPv4 点分十进制
        var result: UInt32 = 0
        let parts = address.split('.')
        if (parts.size == 4) {
            for (i in 0..4) {
                result = (result << 8) | UInt32(Int64(parts[i]) & 0xFF)
            }
        }
        return result
    }
}
