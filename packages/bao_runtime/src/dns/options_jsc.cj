// options_jsc.cj - DNS 选项的 JS 绑定
// 对应 Bun 源文件: src/runtime/dns_jsc/options_jsc.zig
// `fromJS`/`toJS` for `GetAddrInfo` and its nested option types, plus
// `addressToJS`/`addrInfoToJSArray`. The pure types stay in `src/dns/`.

package bao_runtime.dns

// ============================================================================
// 从 JS 值解析 DNS 选项
// 对应 Bun: options_jsc.zig - optionsFromJS
// ============================================================================

/// 从 JS 值解析 Options
/// 对应 Bun: optionsFromJS
public func optionsFromJS(value: JsValue, globalObject: JsObject): ?DnsOptions {
    if (value.isEmptyOrUndefinedOrNull()) {
        return DnsOptions()
    }

    if (value.isObject()) {
        var options = DnsOptions()

        let familyVal = value.getObject().get("family")
        if (familyVal != None && !familyVal.isUndefinedOrNull()) {
            let fam = familyFromJS(familyVal, globalObject)
            if (fam == None) {
                return None
            }
            options.family = fam
        }

        let socktypeVal = value.getObject().get("socketType")
        let socktypeAlt = value.getObject().get("socktype")
        let sockInput = if (socktypeVal != None && !socktypeVal.isUndefinedOrNull()) {
            socktypeVal
        } else if (socktypeAlt != None && !socktypeAlt.isUndefinedOrNull()) {
            socktypeAlt
        } else {
            JsValue.UNDEFINED
        }
        if (!sockInput.isUndefinedOrNull()) {
            let st = socketTypeFromJS(sockInput, globalObject)
            if (st == None) {
                return None
            }
            options.socktype = st
        }

        let protocolVal = value.getObject().get("protocol")
        if (protocolVal != None && !protocolVal.isUndefinedOrNull()) {
            let proto = protocolFromJS(protocolVal, globalObject)
            if (proto == None) {
                return None
            }
            options.protocol = proto
        }

        let backendVal = value.getObject().get("backend")
        if (backendVal != None && !backendVal.isUndefinedOrNull()) {
            let be = backendFromJS(backendVal, globalObject)
            if (be == None) {
                return None
            }
            options.backend = be
        }

        let flagsVal = value.getObject().get("flags")
        if (flagsVal != None && !flagsVal.isUndefinedOrNull()) {
            if (!flagsVal.isNumber()) {
                return None
            }
            options.flags = flagsVal.toNumber()
        }

        return options
    }

    return None
}

// ============================================================================
// Family 从 JS 解析
// 对应 Bun: options_jsc.zig - familyFromJS
// ============================================================================

/// 从 JS 值解析地址族
/// 对应 Bun: familyFromJS
public func familyFromJS(value: JsValue, globalObject: JsObject): ?DnsFamily {
    if (value.isEmptyOrUndefinedOrNull()) {
        return DnsFamily.unspecified
    }

    if (value.isNumber()) {
        let num = Int64(value.toNumber())
        match (num) {
            case 0 => return DnsFamily.unspecified
            case 4 => return DnsFamily.inet
            case 6 => return DnsFamily.inet6
            case _ => return None
        }
    }

    if (value.valueType == JsValueType.String) {
        let str = value.toString()
        if (str.isEmpty()) {
            return DnsFamily.unspecified
        }
        // 映射字符串到枚举
        match (str) {
            case "unspecified" | "IPv4" | "4" => return DnsFamily.unspecified
            case "inet" | "ipv4" => return DnsFamily.inet
            case "inet6" | "ipv6" => return DnsFamily.inet6
            case _ => return None
        }
    }

    return None
}

// ============================================================================
// SocketType 从 JS 解析
// 对应 Bun: options_jsc.zig - socketTypeFromJS
// ============================================================================

/// 从 JS 值解析套接字类型
/// 对应 Bun: socketTypeFromJS
public func socketTypeFromJS(value: JsValue, globalObject: JsObject): ?DnsSocketType {
    if (value.isEmptyOrUndefinedOrNull()) {
        // 默认为 stream
        return DnsSocketType.stream
    }

    if (value.isNumber()) {
        let num = Int64(value.toNumber())
        match (num) {
            case 0 => return DnsSocketType.unspecified
            case 1 => return DnsSocketType.stream
            case 2 => return DnsSocketType.dgram
            case _ => return None
        }
    }

    if (value.valueType == JsValueType.String) {
        let str = value.toString()
        if (str.isEmpty()) {
            return DnsSocketType.unspecified
        }
        match (str) {
            case "stream" => return DnsSocketType.stream
            case "dgram" => return DnsSocketType.dgram
            case _ => return None
        }
    }

    return None
}

// ============================================================================
// Protocol 从 JS 解析
// 对应 Bun: options_jsc.zig - protocolFromJS
// ============================================================================

/// 从 JS 值解析协议
/// 对应 Bun: protocolFromJS
public func protocolFromJS(value: JsValue, globalObject: JsObject): ?DnsProtocol {
    if (value.isEmptyOrUndefinedOrNull()) {
        return DnsProtocol.unspecified
    }

    if (value.isNumber()) {
        let num = Int64(value.toNumber())
        match (num) {
            case 0 => return DnsProtocol.unspecified
            case 6 => return DnsProtocol.tcp
            case 17 => return DnsProtocol.udp
            case _ => return None
        }
    }

    if (value.valueType == JsValueType.String) {
        let str = value.toString()
        if (str.isEmpty()) {
            return DnsProtocol.unspecified
        }
        match (str) {
            case "tcp" => return DnsProtocol.tcp
            case "udp" => return DnsProtocol.udp
            case _ => return None
        }
    }

    return None
}

// ============================================================================
// Backend 从 JS 解析
// 对应 Bun: options_jsc.zig - backendFromJS
// ============================================================================

/// 从 JS 值解析后端
/// 对应 Bun: backendFromJS
public func backendFromJS(value: JsValue, globalObject: JsObject): ?DnsBackend {
    if (value.isEmptyOrUndefinedOrNull()) {
        return DnsBackend.system
    }

    if (value.valueType == JsValueType.String) {
        let str = value.toString()
        if (str.isEmpty()) {
            return DnsBackend.system
        }
        match (str) {
            case "c_ares" => return DnsBackend.c_ares
            case "libc" => return DnsBackend.libc
            case "system" => return DnsBackend.system
            case _ => return None
        }
    }

    return None
}

// ============================================================================
// DNS 结果转 JS
// 对应 Bun: options_jsc.zig - resultAnyToJS, resultToJS, addressToJS
// ============================================================================

/// 将 DNS Result.Any 转为 JS 值
/// 对应 Bun: resultAnyToJS
public func resultAnyToJS(result: DnsResultAny, globalThis: JsObject): ?JsValue {
    match (result) {
        case DnsResultAny.addrinfo(addrinfo) => {
            if (addrinfo == None) {
                return None
            }
            return addrInfoToJSArray(addrInfo: addrInfo!, globalThis)
        }
        case DnsResultAny.list(list) => {
            let array = JsValue(JsValueType.Array)
            var items = ArrayList<JsValue>()
            for (item in list.items) {
                items.append(resultToJS(item, globalThis))
            }
            array.arrayData = Some(items)
            return array
        }
    }
}

/// 将单个 DNS 结果转为 JS 对象
/// 对应 Bun: resultToJS
public func resultToJS(result: DnsResult, globalThis: JsObject): JsValue {
    let obj = JsObject()
    obj.set("address", addressToJS(result.address, globalThis))

    let familyNum = match (result.address.family) {
        case AF_INET => JsValue(4.0)
        case AF_INET6 => JsValue(6.0)
        case _ => JsValue(0.0)
    }
    obj.set("family", familyNum)
    obj.set("ttl", JsValue(Float64(result.ttl)))

    return JsValue(obj)
}

/// 将网络地址转为 JS 字符串
/// 对应 Bun: addressToJS
public func addressToJS(address: NetworkAddress, globalThis: JsObject): JsValue {
    return JsValue(addressToString(address))
}

/// 将 addrinfo 链转为 JS 数组
/// 对应 Bun: addrInfoToJSArray
public func addrInfoToJSArray(addrInfo: AddrInfo, globalThis: JsObject): JsValue {
    var items = ArrayList<JsValue>()
    var current: ?AddrInfoNode = addrInfo.first
    while (current != None) {
        let node = current!
        let result = DnsResult.fromAddrInfo(node)
        if (result != None) {
            items.append(resultToJS(result!, globalThis))
        }
        current = node.next
    }
    return JsValue.array(items)
}

// ============================================================================
// DNS 相关类型定义
// ============================================================================

/// DNS 地址族
public enum DnsFamily {
    | unspecified
    | inet     // IPv4
    | inet6    // IPv6
}

/// DNS 套接字类型
public enum DnsSocketType {
    | unspecified
    | stream   // TCP
    | dgram    // UDP
}

/// DNS 协议
public enum DnsProtocol {
    | unspecified
    | tcp
    | udp
}

/// DNS 后端类型
public enum DnsBackend {
    | c_ares
    | libc
    | system

    public func defaultValue(): DnsBackend {
        return DnsBackend.system
    }
}

/// DNS 选项
public class DnsOptions {
    public var family: DnsFamily = DnsFamily.unspecified
    public var socktype: DnsSocketType = DnsSocketType.stream
    public var protocol: DnsProtocol = DnsProtocol.unspecified
    public var backend: DnsBackend = DnsBackend.system
    public var flags: Float64 = 0.0

    public init() {}
}

/// 地址族常量
public const AF_INET: Int64 = 2
public const AF_INET6: Int64 = 10

/// DNS 解析结果
public class DnsResult {
    public var address: NetworkAddress
    public var ttl: Int32

    public init(addr: NetworkAddress, ttl: Int32) {
        address = addr
        this.ttl = ttl
    }

    public static func fromAddrInfo(node: AddrInfoNode): ?DnsResult {
        return DnsResult(addr: node.address, ttl: node.ttl)
    }
}

/// DNS 结果的 Any 联合类型
public enum DnsResultAny {
    | addrinfo(?AddrInfo)
    | list(DnsResultList)
}

/// DNS 结果列表
public class DnsResultList {
    public var items: ArrayList<DnsResult>

    public init(items: ArrayList<DnsResult>) {
        this.items = items
    }
}

/// 网络地址
public class NetworkAddress {
    public var family: Int64
    public var address: String

    public init(family: Int64, address: String) {
        this.family = family
        this.address = address
    }
}

/// addrinfo 节点链
public class AddrInfoNode {
    public var address: NetworkAddress
    public var ttl: Int32
    public var next: ?AddrInfoNode

    public init(addr: NetworkAddress, ttl: Int32) {
        address = addr
        this.ttl = ttl
        next = None
    }
}

/// addrinfo 结构
public class AddrInfo {
    public var first: ?AddrInfoNode

    public init(first: ?AddrInfoNode) {
        this.first = first
    }
}

/// 将网络地址转为字符串
public func addressToString(address: NetworkAddress): String {
    return address.address
}
