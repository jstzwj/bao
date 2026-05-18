// Socket 地址 — IP 套接字地址表示
// 对应 Bun: src/runtime/socket/SocketAddress.zig
// 用于 TCP/UDP 连接的地址解析、格式化和 JS 绑定
package bao_runtime.socket

import bao_core.*
import bao_collections.*

// ============================================================================
// 地址族枚举
// 对应 Bun: SocketAddress.AF
// ============================================================================

/// IP 地址族类型
/// 对应 Zig: enum(inet.sa_family_t) { INET, INET6 }
public enum AddressFamily {
    | IPv4   // AF_INET
    | IPv6   // AF_INET6

    /// 转为整数值
    public func toInt(): Int32 {
        match (this) {
            case IPv4 => 2      // AF_INET = 2
            case IPv6 => 10     // AF_INET6 = 10
        }
    }

    /// 从字符串解析地址族
    /// 对应 Zig: AF.fromJS
    public static func fromString(value: String): ?AddressFamily {
        let lower = value.toRuneArray().map({ r => r.toAsciiLowerCase() })
        if (lower == "ipv4") {
            return AddressFamily.IPv4
        }
        if (lower == "ipv6") {
            return AddressFamily.IPv6
        }
        return None
    }

    /// 获取显示名称
    public func label(): String {
        match (this) {
            case IPv4 => "IPv4"
            case IPv6 => "IPv6"
        }
    }
}

// ============================================================================
// Socket 地址
// 对应 Bun: SocketAddress struct
// ============================================================================

/// IP 套接字地址
/// 对应 Zig: const SocketAddress = @This()
/// 支持 IPv4 和 IPv6 地址存储、解析、格式化
public class SocketAddress {
    /// 内部存储的地址族
    public var family: AddressFamily
    /// IPv4 地址 (4 字节, 网络字节序)
    public var addrV4: Array<UInt8>
    /// IPv6 地址 (16 字节, 网络字节序)
    public var addrV6: Array<UInt8>
    /// 端口号 (主机字节序)
    public var port: UInt16
    /// IPv6 流标签
    public var flowLabel: UInt32
    /// IPv6 scope_id
    public var scopeId: UInt32
    /// 缓存的地址展示格式字符串
    public var presentation: String

    public init() {
        family = AddressFamily.IPv4
        addrV4 = [127, 0, 0, 1]
        addrV6 = Array<UInt8>(16, item: 0)
        port = 0
        flowLabel = 0
        scopeId = 0
        presentation = ""
    }

    /// 从地址族和参数构造
    /// 对应 Zig: initJS
    public init(family: AddressFamily, address: String, port: UInt16, flowLabel: UInt32) {
        this.family = family
        this.port = port
        this.flowLabel = flowLabel
        this.scopeId = 0
        this.presentation = address

        // 解析地址字符串为字节数组
        match (family) {
            case IPv4 => {
                addrV4 = SocketAddress.parseIPv4ToBytes(address)
                addrV6 = Array<UInt8>(16, item: 0)
            }
            case IPv6 => {
                addrV4 = [0, 0, 0, 0]
                addrV6 = SocketAddress.parseIPv6ToBytes(address)
            }
        }
    }

    /// 从原始字节初始化 IPv4 地址
    /// 对应 Zig: initIPv4
    public static func initIPv4(addr: Array<UInt8>, port: UInt16): SocketAddress {
        let sa = SocketAddress()
        sa.family = AddressFamily.IPv4
        sa.addrV4 = addr
        sa.port = port
        sa.presentation = formatIPv4(addr)
        return sa
    }

    /// 从原始字节初始化 IPv6 地址
    /// 对应 Zig: initIPv6
    public static func initIPv6(addr: Array<UInt8>, port: UInt16, flowInfo: UInt32, scopeId: UInt32): SocketAddress {
        let sa = SocketAddress()
        sa.family = AddressFamily.IPv6
        sa.addrV6 = addr
        sa.port = port
        sa.flowLabel = flowInfo
        sa.scopeId = scopeId
        sa.presentation = formatIPv6(addr)
        return sa
    }

    /// 从地址字节数组自动判断 IPv4/IPv6
    /// 对应 Zig: init
    public static func fromBytes(addr: Array<UInt8>, port: UInt16): ?SocketAddress {
        if (addr.size == 4) {
            return SocketAddress.initIPv4(addr, port)
        }
        if (addr.size == 16) {
            return SocketAddress.initIPv6(addr, port, 0, 0)
        }
        return None
    }

    /// 解析地址字符串为 SocketAddress
    /// 对应 Zig: parse
    public static func parse(input: String): ?SocketAddress {
        // 简单解析: 格式为 "host:port" 或 "[host]:port"
        if (input.isEmpty()) {
            return None
        }

        // 处理 IPv6 地址格式 [host]:port
        if (input.startsWith("[")) {
            let closeBracket = input.indexOf(']')
            if (closeBracket < 0) {
                return None
            }
            let host = input.subString(1, closeBracket - 1)
            let portStr = input.subString(closeBracket + 1)
            var port: UInt16 = 0
            if (portStr.startsWith(":")) {
                port = UInt16.parse(portStr.subString(1)).getOr(0)
            }
            return SocketAddress(AddressFamily.IPv6, host, port, 0)
        }

        // 处理 IPv4 地址格式 host:port
        let lastColon = input.lastIndexOf(':')
        if (lastColon >= 0) {
            let host = input.subString(0, lastColon)
            let portStr = input.subString(lastColon + 1)
            let port = UInt16.parse(portStr).getOr(0)
            return SocketAddress(AddressFamily.IPv4, host, port, 0)
        }

        // 仅主机名, 无端口
        return SocketAddress(AddressFamily.IPv4, input, 0, 0)
    }

    /// 获取地址的展示格式 (不含端口)
    /// 对应 Zig: pub fn address(this: *SocketAddress) bun.String
    public func getAddress(): String {
        if (!presentation.isEmpty()) {
            return presentation
        }
        match (family) {
            case IPv4 => {
                if (addrV4.size == 4) {
                    presentation = formatIPv4(addrV4)
                } else {
                    presentation = "127.0.0.1"
                }
            }
            case IPv6 => {
                if (addrV6.size == 16) {
                    presentation = formatIPv6(addrV6)
                } else {
                    presentation = "::"
                }
            }
        }
        return presentation
    }

    /// 获取地址的JS值
    /// 对应 Bun: pub fn getAddress(this: *SocketAddress, global: *jsc.JSGlobalObject) bun.JSError!jsc.JSValue
    public func getAddressJS(global: JsObject): JsValue {
        return JsValue(getAddress())
    }

    /// 获取地址族的JS值
    /// 对应 Bun: pub fn getFamily(this: *SocketAddress, global: *jsc.JSGlobalObject) bun.JSError!JSValue
    public func getFamilyJS(global: JsObject): JsValue {
        return JsValue(getFamily().label())
    }

    /// 获取地址族的数值
    /// 对应 Bun: pub fn getAddrFamily(this: *SocketAddress, _: *jsc.JSGlobalObject) JSValue
    public func getAddrFamilyJS(global: JsObject): JsValue {
        return JsValue(getFamily().toInt())
    }

    /// 获取端口的JS值
    /// 对应 Bun: pub fn getPort(this: *SocketAddress, _: *jsc.JSGlobalObject) JSValue
    public func getPortJS(global: JsObject): JsValue {
        return JsValue(Int64(getPort()))
    }

    /// 获取流标签的JS值
    /// 对应 Bun: pub fn getFlowLabel(this: *SocketAddress, _: *jsc.JSGlobalObject) JSValue
    public func getFlowLabelJS(global: JsObject): JsValue {
        return JsValue(Int64(getFlowLabel()))
    }

    /// 转为DTO对象
    /// 对应 Bun: pub fn intoDTO(this: *SocketAddress, global: *jsc.JSGlobalObject) bun.JSError!jsc.JSValue
    /// this被消耗，返回一个普通JS对象（非SocketAddress实例）
    public func intoDTO(global: JsObject): JsValue {
        let obj = JsObject()
        obj.set("address", JsValue(getAddress()))
        obj.set("family", JsValue(getFamily().label()))
        obj.set("port", JsValue(Int64(getPort())))
        obj.set("flowlabel", JsValue(Int64(getFlowLabel())))
        return JsValue(obj)
    }

    /// 静态创建DTO
    /// 对应 Bun: pub fn createDTO(globalObject, addr_, port_, is_ipv6) bun.JSError!jsc.JSValue
    public static func createDTO(global: JsObject, addr: String, port: UInt16, isIPv6: Boolean): JsValue {
        let obj = JsObject()
        obj.set("address", JsValue(addr))
        obj.set("port", JsValue(Int64(port)))
        obj.set("family", JsValue(if (isIPv6) "IPv6" else "IPv4"))
        return JsValue(obj)
    }

    /// 从地址族和JS值创建
    /// 对应 Bun: pub fn initFromAddrFamily(global, address_js, family_js) bun.JSError!SocketAddress
    public static func initFromAddrFamily(global: JsObject, addressJs: JsValue, familyJs: JsValue): ?SocketAddress {
        if (!addressJs.isString()) {
            return None
        }
        let addressStr = addressJs.toString()
        let familyStr = familyJs.toString()
        let family = AddressFamily.fromString(familyStr) ?? AddressFamily.IPv4
        return SocketAddress(family, addressStr, 0, 0)
    }

    /// 去初始化
    /// 对应 Bun: fn deinit(this: *SocketAddress) void
    public func deinit() {
        presentation = ""
    }

    /// 终结化
    /// 对应 Bun: pub fn finalize(this: *SocketAddress) void
    public func finalize() {
        this.deinit()
    }

    /// 判断是否为IPv4映射的IPv6地址
    /// 对应 Bun: as_v4 中对IPv4-mapped IPv6地址的检测
    public func isIPv4MappedIPv6(): Boolean {
        if (family != IPv6) {
            return false
        }
        // 检查是否为 ::ffff:a.b.c.d 格式
        for (i in 0..10) {
            if (addrV6[i] != 0) {
                return false
            }
        }
        if (addrV6[10] != 255 || addrV6[11] != 255) {
            return false
        }
        return true
    }

    /// 获取IPv4映射地址的IPv4部分
    /// 对应 Bun: as_v4 的返回值
    public func asIPv4(): ?UInt32 {
        if (family == IPv4) {
            return UInt32(addrV4[0]) << 24 | UInt32(addrV4[1]) << 16 |
                   UInt32(addrV4[2]) << 8 | UInt32(addrV4[3])
        }
        if (this.isIPv4MappedIPv6()) {
            return UInt32(addrV6[12]) << 24 | UInt32(addrV6[13]) << 16 |
                   UInt32(addrV6[14]) << 8 | UInt32(addrV6[15])
        }
        return None
    }

    /// 获取端口号 (主机字节序)
    /// 对应 Zig: port()
    public func getPort(): UInt16 {
        return port
    }

    /// 获取地址族
    /// 对应 Zig: family()
    public func getFamily(): AddressFamily {
        return family
    }

    /// 获取 IPv6 流标签
    /// 对应 Zig: flowLabel()
    public func getFlowLabel(): UInt32 {
        match (family) {
            case IPv6 => return flowLabel
            case IPv4 => return 0
        }
    }

    /// 获取 socklen
    /// 对应 Zig: socklen()
    public func socklen(): UInt32 {
        match (family) {
            case IPv4 => 16    // sizeof(sockaddr_in)
            case IPv6 => 28    // sizeof(sockaddr_in6)
        }
    }

    /// 转为 JSON 对象
    /// 对应 Zig: toJSON
    public func toJSON(): JsValue {
        let obj = JsObject()
        obj.set("address", JsValue(getAddress()))
        obj.set("family", JsValue(getFamily().label()))
        obj.set("port", JsValue(Float64(getPort())))
        obj.set("flowlabel", JsValue(Float64(getFlowLabel())))
        return JsValue(obj)
    }

    /// 估算内存大小
    /// 对应 Zig: estimatedSize
    public func estimatedSize(): Int64 {
        return 64 + presentation.size
    }

    /// 判断JS值是否为SocketAddress
    /// 对应 Bun: pub fn isSocketAddress(_: *jsc.JSGlobalObject, callframe: *jsc.CallFrame) bun.JSError!JSValue
    public static func isSocketAddress(value: JsValue): Boolean {
        // 检查是否为SocketAddress JS包装对象
        return value.isCell() && value.isInstanceOf(SocketAddress)
    }

    /// 从JS对象构造选项
    /// 对应 Bun: pub fn fromJS(global: *jsc.JSGlobalObject, obj: JSValue) bun.JSError!Options
    public static func optionsFromJS(global: JsObject, obj: JsValue): ?SocketAddressOptions {
        if (!obj.isObject()) {
            return None
        }
        let opts = SocketAddressOptions()

        // 解析 family
        let familyVal = obj.get(global, "family")
        if (familyVal.isString()) {
            opts.family = AddressFamily.fromString(familyVal.toString()) ?? AddressFamily.IPv4
        }

        // 解析 address
        let addressVal = obj.get(global, "address")
        if (addressVal.isString()) {
            opts.address = addressVal.toString()
        } else {
            // 默认地址根据family决定
            if (opts.family == IPv4) {
                opts.address = "127.0.0.1"
            } else {
                opts.address = "::1"
            }
        }

        // 解析 port
        let portVal = obj.get(global, "port")
        if (portVal.isNumber()) {
            let port32 = portVal.toInt32()
            if (port32 >= 0 && port32 <= 65535) {
                opts.port = UInt16(port32)
            }
        }

        // 解析 flowlabel
        let flowlabelVal = obj.get(global, "flowlabel")
        if (flowlabelVal.isNumber()) {
            opts.flowLabel = flowlabelVal.toUInt32()
        }

        return opts
    }

    // ========================================================================
    // 私有辅助方法
    // ========================================================================

    /// 将 IPv4 字节数组格式化为字符串
    private static func formatIPv4(bytes: Array<UInt8>): String {
        if (bytes.size < 4) {
            return "0.0.0.0"
        }
        return "${bytes[0]}.${bytes[1]}.${bytes[2]}.${bytes[3]}"
    }

    /// 将 IPv6 字节数组格式化为字符串
    private static func formatIPv6(bytes: Array<UInt8>): String {
        if (bytes.size < 16) {
            return "::"
        }
        // 简化: 将16字节格式化为8组4位十六进制
        var groups = ArrayList<String>()
        var i: Int64 = 0
        while (i < 16) {
            let hi = bytes[i].toInt()
            let lo = bytes[i + 1].toInt()
            let val = (hi << 8) | lo
            groups.append(val.toHexString())
            i += 2
        }
        return groups.join(":")
    }

    /// 解析 IPv4 字符串为字节数组
    private static func parseIPv4ToBytes(addr: String): Array<UInt8> {
        let parts = addr.split('.')
        if (parts.size != 4) {
            return [127, 0, 0, 1]
        }
        var bytes = ArrayList<UInt8>()
        for (part in parts) {
            let v = UInt8.parse(part)
            match (v) {
                case Some(b) => bytes.append(b)
                case None => bytes.append(0)
            }
        }
        return bytes.toArray()
    }

    /// 解析 IPv6 字符串为字节数组
    private static func parseIPv6ToBytes(addr: String): Array<UInt8> {
        // 简化实现: 16字节全零
        var bytes = ArrayList<UInt8>()
        for (_ in 0..16) {
            bytes.append(0)
        }

        // 处理 :: 缩写
        if (addr == "::") {
            return bytes.toArray()
        }

        let parts = addr.split(':')
        var idx: Int64 = 0
        for (part in parts) {
            if (part.isEmpty()) {
                // :: 展开 — 跳过适当数量的字节
                let skip = (8 - parts.size + 1) * 2
                idx += skip
                continue
            }
            if (idx + 1 < 16) {
                let val = Int64.parse(part, radix: 16).getOr(0)
                bytes[idx] = UInt8((val >> 8) & 0xFF)
                bytes[idx + 1] = UInt8(val & 0xFF)
                idx += 2
            }
        }
        return bytes.toArray()
    }
}

// ============================================================================
// SocketAddress 选项
// 对应 Bun: SocketAddress.Options
// ============================================================================

/// SocketAddress 构造选项
/// 对应 Bun: pub const Options = struct { family, address, port, flowlabel }
public class SocketAddressOptions {
    /// 地址族
    public var family: AddressFamily = AddressFamily.IPv4
    /// 地址字符串
    public var address: ?String = None
    /// 端口号
    public var port: UInt16 = 0
    /// IPv6 流标签
    public var flowLabel: ?UInt32 = None

    public init() {}

    /// 从另一个SocketAddress复制
    public init(family: AddressFamily, address: ?String, port: UInt16, flowLabel: ?UInt32) {
        this.family = family
        this.address = address
        this.port = port
        this.flowLabel = flowLabel
    }

    /// 获取默认地址
    /// 对应 Bun: null地址时根据family决定默认值
    public func defaultAddress(): String {
        if (let addr = this.address) {
            return addr
        }
        match (family) {
            case IPv4 => return "127.0.0.1"
            case IPv6 => return "::1"
        }
    }
}
