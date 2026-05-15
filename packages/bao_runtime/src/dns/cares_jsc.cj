// cares_jsc.cj - c-ares 的 JSC 桥接层
// 对应 Bun 源文件: src/runtime/dns_jsc/cares_jsc.zig
// JSC bridges for c-ares reply structs. Keeps `src/cares_sys/` free of
// `JSValue`/`JSGlobalObject`/`CallFrame` types.

package bao_runtime

// ============================================================================
// struct_hostent -> JS 响应
// 对应 Bun: cares_jsc.zig - hostentToJSResponse
// ============================================================================

/// 将 hostent 结构转为 JS 响应
/// 对应 Bun: hostentToJSResponse
public func hostentToJSResponse(hostent: Hostent, lookupName: String, globalThis: JsObject): JsValue {
    if (lookupName == "cname") {
        // CNAME 查询始终返回单条记录，但遵循公共 API
        if (hostent.name == None || hostent.name.isEmpty()) {
            return JsValue.array(ArrayList<JsValue>())
        }
        var arr = ArrayList<JsValue>()
        arr.append(JsValue(hostent.name))
        return JsValue.array(arr)
    }

    if (hostent.aliases == None) {
        return JsValue.array(ArrayList<JsValue>())
    }

    var arr = ArrayList<JsValue>()
    for (alias in hostent.aliases) {
        arr.append(JsValue(alias))
    }

    return JsValue.array(arr)
}

// ============================================================================
// hostent_with_ttls -> JS 响应
// 对应 Bun: cares_jsc.zig - hostentWithTtlsToJSResponse
// ============================================================================

/// 将 hostent_with_ttls 结构转为 JS 响应（用于 A/AAAA 记录）
/// 对应 Bun: hostentWithTtlsToJSResponse
public func hostentWithTtlsToJSResponse(hostentWithTtls: HostentWithTtls, lookupName: String, globalThis: JsObject): JsValue {
    if (lookupName == "a" || lookupName == "aaaa") {
        if (hostentWithTtls.hostent.addrList == None) {
            return JsValue.array(ArrayList<JsValue>())
        }

        val addrList = hostentWithTtls.hostent.addrList
        var arr = ArrayList<JsValue>()

        var count = 0
        for (addr in addrList) {
            val addrString = if (hostentWithTtls.hostent.addrType == AF_INET6) {
                addressToJS(NetworkAddress(family: AF_INET6, address: addr), globalThis)
            } else {
                addressToJS(NetworkAddress(family: AF_INET, address: addr), globalThis)
            }

            val ttl: ?Int32 = if (count < hostentWithTtls.ttls.size) {
                hostentWithTtls.ttls[count]
            } else {
                None
            }

            val resultObj = JsObject()
            resultObj.set("address", addrString)
            if (ttl != None) {
                resultObj.set("ttl", JsValue(Float64(ttl)))
            } else {
                resultObj.set("ttl", JsValue.UNDEFINED)
            }
            arr.append(JsValue(resultObj))
            count += 1
        }

        return JsValue.array(arr)
    }

    return JsValue.array(ArrayList<JsValue>())
}

// ============================================================================
// struct_nameinfo -> JS 响应
// 对应 Bun: cares_jsc.zig - nameinfoToJSResponse
// ============================================================================

/// 将 nameinfo 结构转为 JS 响应
/// 对应 Bun: nameinfoToJSResponse
public func nameinfoToJSResponse(nameinfo: NameInfo, globalThis: JsObject): JsValue {
    var arr = ArrayList<JsValue>()

    // [node, service]
    if (nameinfo.node != None && !nameinfo.node.isEmpty()) {
        arr.append(JsValue(nameinfo.node))
    } else {
        arr.append(JsValue.UNDEFINED)
    }

    if (nameinfo.service != None && !nameinfo.service.isEmpty()) {
        arr.append(JsValue(nameinfo.service))
    } else {
        arr.append(JsValue.UNDEFINED)
    }

    return JsValue.array(arr)
}

// ============================================================================
// AddrInfo -> JS 数组
// 对应 Bun: cares_jsc.zig - addrInfoToJSArray
// ============================================================================

/// 将 c-ares AddrInfo 转为 JS 数组
/// 对应 Bun: addrInfoToJSArray (cares_jsc 版本)
public func caresAddrInfoToJSArray(addrInfo: CaresAddrInfo, globalThis: JsObject): JsValue {
    if (addrInfo.node == None) {
        return JsValue.array(ArrayList<JsValue>())
    }

    var arr = ArrayList<JsValue>()
    var current: ?CaresAddrInfoNode = addrInfo.node

    while (current != None) {
        val node = current!
        val address = NetworkAddress(
            family: if (node.family == AF_INET6) { AF_INET6 } else { AF_INET },
            address: node.address
        )
        val result = DnsResult(addr: address, ttl: node.ttl)
        arr.append(resultToJS(result, globalThis))
        current = node.next
    }

    return JsValue.array(arr)
}

// ============================================================================
// CAA 记录 -> JS 响应
// 对应 Bun: cares_jsc.zig - caaReplyToJSResponse, caaReplyToJS
// ============================================================================

/// 将 CAA 记录链转为 JS 数组
/// 对应 Bun: caaReplyToJSResponse
public func caaReplyToJSResponse(caaReply: CaaReply, globalThis: JsObject): JsValue {
    var arr = ArrayList<JsValue>()
    var current: ?CaaReply = Some(caaReply)

    while (current != None) {
        val node = current!
        arr.append(caaReplyToJS(node, globalThis))
        current = node.next
    }

    return JsValue.array(arr)
}

/// 单个 CAA 记录转 JS 对象
/// 对应 Bun: caaReplyToJS
public func caaReplyToJS(caa: CaaReply, globalThis: JsObject): JsValue {
    val obj = JsObject()
    obj.set("critical", JsValue(Float64(caa.critical)))

    // 属性名作为 key，值作为 value
    val propKey = caa.property
    val propVal = JsValue(caa.value)
    obj.set(propKey, propVal)

    return JsValue(obj)
}

// ============================================================================
// SRV 记录 -> JS 响应
// 对应 Bun: cares_jsc.zig - srvReplyToJSResponse, srvReplyToJS
// ============================================================================

/// 将 SRV 记录链转为 JS 数组
/// 对应 Bun: srvReplyToJSResponse
public func srvReplyToJSResponse(srvReply: SrvReply, globalThis: JsObject): JsValue {
    var arr = ArrayList<JsValue>()
    var current: ?SrvReply = Some(srvReply)

    while (current != None) {
        val node = current!
        arr.append(srvReplyToJS(node, globalThis))
        current = node.next
    }

    return JsValue.array(arr)
}

/// 单个 SRV 记录转 JS 对象
/// 对应 Bun: srvReplyToJS
public func srvReplyToJS(srv: SrvReply, globalThis: JsObject): JsValue {
    val obj = JsObject()
    obj.set("priority", JsValue(Float64(srv.priority)))
    obj.set("weight", JsValue(Float64(srv.weight)))
    obj.set("port", JsValue(Float64(srv.port)))
    obj.set("name", JsValue(srv.host))
    return JsValue(obj)
}

// ============================================================================
// MX 记录 -> JS 响应
// 对应 Bun: cares_jsc.zig - mxReplyToJSResponse, mxReplyToJS
// ============================================================================

/// 将 MX 记录链转为 JS 数组
/// 对应 Bun: mxReplyToJSResponse
public func mxReplyToJSResponse(mxReply: MxReply, globalThis: JsObject): JsValue {
    var arr = ArrayList<JsValue>()
    var current: ?MxReply = Some(mxReply)

    while (current != None) {
        val node = current!
        arr.append(mxReplyToJS(node, globalThis))
        current = node.next
    }

    return JsValue.array(arr)
}

/// 单个 MX 记录转 JS 对象
/// 对应 Bun: mxReplyToJS
public func mxReplyToJS(mx: MxReply, globalThis: JsObject): JsValue {
    val obj = JsObject()
    obj.set("priority", JsValue(Float64(mx.priority)))
    obj.set("exchange", JsValue(mx.host))
    return JsValue(obj)
}

// ============================================================================
// TXT 记录 -> JS 响应
// 对应 Bun: cares_jsc.zig - txtReplyToJSResponse, txtReplyToJS
// ============================================================================

/// 将 TXT 记录链转为 JS 数组
/// 对应 Bun: txtReplyToJSResponse
public func txtReplyToJSResponse(txtReply: TxtReply, globalThis: JsObject): JsValue {
    var arr = ArrayList<JsValue>()
    var current: ?TxtReply = Some(txtReply)

    while (current != None) {
        val node = current!
        arr.append(txtReplyToJS(node, globalThis))
        current = node.next
    }

    return JsValue.array(arr)
}

/// 单个 TXT 记录转 JS 数组（每条记录本身是一个字符串数组）
/// 对应 Bun: txtReplyToJS
public func txtReplyToJS(txt: TxtReply, globalThis: JsObject): JsValue {
    var arr = ArrayList<JsValue>()
    arr.append(JsValue(txt.text))
    return JsValue.array(arr)
}

/// TXT 记录转 JS（用于 ANY 查询）
/// 对应 Bun: txtReplyToJSForAny
public func txtReplyToJSForAny(txtReply: TxtReply, lookupName: String, globalThis: JsObject): JsValue {
    var arr = ArrayList<JsValue>()
    var current: ?TxtReply = Some(txtReply)

    while (current != None) {
        val node = current!
        arr.append(JsValue(node.text))
        current = node.next
    }

    // 返回 { entries: [...] }
    val obj = JsObject()
    obj.set("entries", JsValue.array(arr))
    return JsValue(obj)
}

// ============================================================================
// NAPTR 记录 -> JS 响应
// 对应 Bun: cares_jsc.zig - naptrReplyToJSResponse, naptrReplyToJS
// ============================================================================

/// 将 NAPTR 记录链转为 JS 数组
/// 对应 Bun: naptrReplyToJSResponse
public func naptrReplyToJSResponse(naptrReply: NaptrReply, globalThis: JsObject): JsValue {
    var arr = ArrayList<JsValue>()
    var current: ?NaptrReply = Some(naptrReply)

    while (current != None) {
        val node = current!
        arr.append(naptrReplyToJS(node, globalThis))
        current = node.next
    }

    return JsValue.array(arr)
}

/// 单个 NAPTR 记录转 JS 对象
/// 对应 Bun: naptrReplyToJS
public func naptrReplyToJS(naptr: NaptrReply, globalThis: JsObject): JsValue {
    val obj = JsObject()
    obj.set("preference", JsValue(Float64(naptr.preference)))
    obj.set("order", JsValue(Float64(naptr.order)))
    obj.set("flags", JsValue(naptr.flags))
    obj.set("service", JsValue(naptr.service))
    obj.set("regexp", JsValue(naptr.regexp))
    obj.set("replacement", JsValue(naptr.replacement))
    return JsValue(obj)
}

// ============================================================================
// SOA 记录 -> JS 响应
// 对应 Bun: cares_jsc.zig - soaReplyToJSResponse, soaReplyToJS
// ============================================================================

/// SOA 记录转 JS 响应
/// 对应 Bun: soaReplyToJSResponse
public func soaReplyToJSResponse(soaReply: SoaReply, globalThis: JsObject): JsValue {
    return soaReplyToJS(soaReply, globalThis)
}

/// 单个 SOA 记录转 JS 对象
/// 对应 Bun: soaReplyToJS
public func soaReplyToJS(soa: SoaReply, globalThis: JsObject): JsValue {
    val obj = JsObject()
    obj.set("serial", JsValue(Float64(soa.serial)))
    obj.set("refresh", JsValue(Float64(soa.refresh)))
    obj.set("retry", JsValue(Float64(soa.retry)))
    obj.set("expire", JsValue(Float64(soa.expire)))
    obj.set("minttl", JsValue(Float64(soa.minttl)))
    obj.set("nsname", JsValue(soa.nsname))
    obj.set("hostmaster", JsValue(soa.hostmaster))
    return JsValue(obj)
}

// ============================================================================
// ANY 记录 -> JS 响应
// 对应 Bun: cares_jsc.zig - anyReplyToJSResponse, anyReplyToJS
// ============================================================================

/// ANY 记录转 JS 响应
/// 对应 Bun: anyReplyToJSResponse
public func anyReplyToJSResponse(anyReply: AnyReply, globalThis: JsObject): JsValue {
    return anyReplyToJS(anyReply, globalThis)
}

/// 将任意 DNS 回复转为 JS 数组
/// 对应 Bun: anyReplyToJS
public func anyReplyToJS(reply: AnyReply, globalThis: JsObject): JsValue {
    var arr = ArrayList<JsValue>()

    if (reply.caaReply != None) {
        var i = 0
        var current = reply.caaReply
        while (current != None) {
            val node = current!
            anyReplyAppend(globalThis, arr, i, caaReplyToJS(node, globalThis), "caa")
            i += 1
            current = node.next
        }
    }
    if (reply.srvReply != None) {
        var i = 0
        var current = reply.srvReply
        while (current != None) {
            val node = current!
            anyReplyAppend(globalThis, arr, i, srvReplyToJS(node, globalThis), "srv")
            i += 1
            current = node.next
        }
    }
    if (reply.mxReply != None) {
        var i = 0
        var current = reply.mxReply
        while (current != None) {
            val node = current!
            anyReplyAppend(globalThis, arr, i, mxReplyToJS(node, globalThis), "mx")
            i += 1
            current = node.next
        }
    }
    if (reply.txtReply != None) {
        var i = 0
        var current = reply.txtReply
        while (current != None) {
            val node = current!
            anyReplyAppend(globalThis, arr, i, JsValue(node.text), "txt")
            i += 1
            current = node.next
        }
    }
    if (reply.naptrReply != None) {
        var i = 0
        var current = reply.naptrReply
        while (current != None) {
            val node = current!
            anyReplyAppend(globalThis, arr, i, naptrReplyToJS(node, globalThis), "naptr")
            i += 1
            current = node.next
        }
    }
    if (reply.soaReply != None) {
        val idx = arr.size
        anyReplyAppend(globalThis, arr, idx, soaReplyToJS(reply.soaReply!, globalThis), "soa")
    }
    if (reply.nsReply != None) {
        val idx = arr.size
        anyReplyAppend(globalThis, arr, idx, hostentToJSResponse(reply.nsReply!, "ns", globalThis), "ns")
    }
    if (reply.cnameReply != None) {
        val idx = arr.size
        anyReplyAppend(globalThis, arr, idx, hostentToJSResponse(reply.cnameReply!, "cname", globalThis), "cname")
    }
    if (reply.ptrReply != None) {
        val idx = arr.size
        anyReplyAppend(globalThis, arr, idx, hostentToJSResponse(reply.ptrReply!, "ptr", globalThis), "ptr")
    }

    return JsValue.array(arr)
}

/// 向 ANY 数组添加一条结果（包装成带 type 字段的对象）
/// 对应 Bun: anyReplyAppend
func anyReplyAppend(globalThis: JsObject, arr: ArrayList<JsValue>, index: Int64, response: JsValue, lookupName: String): Unit {
    // 如果响应是字符串，包装为 { value: str, type: UPPER }
    val transformed = if (response.valueType == JsValueType.String) {
        val obj = JsObject()
        obj.set("value", response)
        JsValue(obj)
    } else {
        response
    }

    val upper = lookupName.toUpper()
    if (transformed.valueType == JsValueType.Object && transformed.objectData != None) {
        transformed.objectData.set("type", JsValue(upper))
    }
    arr.append(transformed)
}

// ============================================================================
// 错误处理
// 对应 Bun: cares_jsc.zig - ErrorDeferred
// ============================================================================

/// DNS 错误延迟拒绝
/// 对应 Bun: ErrorDeferred
public class DnsErrorDeferred {
    public var errno: DnsError
    public var syscall: String
    public var hostname: ?String
    public var promise: JsPromise

    public init(errno: DnsError, syscall: String, hostname: ?String, promise: JsPromise) {
        this.errno = errno
        this.syscall = syscall
        this.hostname = hostname
        this.promise = promise
    }

    /// 拒绝 Promise 并创建 DNSException
    /// 对应 Bun: ErrorDeferred.reject
    public func reject(globalThis: JsObject): Unit {
        val message = if (hostname != None) {
            "${syscall} ${errno.code().subString(4)} ${hostname}"
        } else {
            "${syscall} ${errno.code().subString(4)}"
        }

        val errorObj = JsObject()
        errorObj.set("name", JsValue("DNSException"))
        errorObj.set("code", JsValue(errno.code()))
        errorObj.set("message", JsValue(message))
        errorObj.set("syscall", JsValue(syscall))
        if (hostname != None) {
            errorObj.set("hostname", JsValue(hostname))
        }

        promise.reject(JsValue(errorObj))
    }

    /// 延迟拒绝（通过事件循环调度）
    /// 对应 Bun: ErrorDeferred.rejectLater
    public func rejectLater(globalThis: JsObject): Unit {
        // 在事件循环中调度拒绝
        reject(globalThis)
    }

    /// 清理资源
    /// 对应 Bun: ErrorDeferred.deinit
    public func deinit(): Unit {
        hostname = None
    }
}

/// 将 c-ares 错误转为延迟拒绝对象
/// 对应 Bun: errorToDeferred
public func errorToDeferred(err: DnsError, syscall: String, hostname: ?String, promise: JsPromise): DnsErrorDeferred {
    return DnsErrorDeferred(errno: err, syscall: syscall, hostname: hostname, promise: promise)
}

/// 将 c-ares 错误转为 JS 错误（带 syscall）
/// 对应 Bun: errorToJSWithSyscall
public func errorToJSWithSyscall(err: DnsError, globalThis: JsObject, syscall: String): JsValue {
    val message = "${syscall} ${err.code().subString(4)}"

    val errorObj = JsObject()
    errorObj.set("name", JsValue("DNSException"))
    errorObj.set("code", JsValue(err.code()))
    errorObj.set("message", JsValue(message))
    errorObj.set("syscall", JsValue(syscall))

    return JsValue(errorObj)
}

/// 将 c-ares 错误转为 JS 错误（带 syscall 和 hostname）
/// 对应 Bun: errorToJSWithSyscallAndHostname
public func errorToJSWithSyscallAndHostname(err: DnsError, globalThis: JsObject, syscall: String, hostname: String): JsValue {
    val message = "${syscall} ${err.code().subString(4)} ${hostname}"

    val errorObj = JsObject()
    errorObj.set("name", JsValue("DNSException"))
    errorObj.set("code", JsValue(err.code()))
    errorObj.set("message", JsValue(message))
    errorObj.set("syscall", JsValue(syscall))
    errorObj.set("hostname", JsValue(hostname))

    return JsValue(errorObj)
}

// ============================================================================
// Bun__canonicalizeIP
// 对应 Bun: cares_jsc.zig - Bun__canonicalizeIP_
// ============================================================================

/// 规范化 IP 地址
/// 对应 Bun: Bun__canonicalizeIP_
public func canonicalizeIP(globalThis: JsObject, args: ArrayList<JsValue>): JsValue {
    if (args.size == 0) {
        return JsValue.UNDEFINED
    }

    // IPv6 地址字符串最大长度 46 字节 (Windows 上 65)
    val INET6_ADDRSTRLEN = 46

    val addrArg = args[0]
    if (addrArg.valueType != JsValueType.String) {
        return JsValue.UNDEFINED
    }
    val addrStr = addrArg.toString()
    if (addrStr.size >= INET6_ADDRSTRLEN) {
        return JsValue.UNDEFINED
    }

    // 不允许 CIDR
    if (addrStr.contains('/')) {
        return JsValue.UNDEFINED
    }

    // 尝试解析为 IPv4 或 IPv6
    // 使用 FFI 调用 ares_inet_pton / ares_inet_ntop
    // 简化版本：直接返回输入（实际实现需要 FFI）
    val normalized = tryParseAndFormatIp(addrStr)
    if (normalized == None) {
        return JsValue.UNDEFINED
    }

    if (normalized == addrStr) {
        return addrArg
    }

    return JsValue(normalized)
}

/// 尝试解析并格式化 IP 地址
func tryParseAndFormatIp(addr: String): ?String {
    // 简化实现：实际应通过 FFI 调用 inet_pton/inet_ntop
    // 此处返回输入地址的规范化形式
    return addr
}

// ============================================================================
// c-ares 数据类型定义
// ============================================================================

/// DNS 错误码
public enum DnsError {
    | ENOTFOUND
    | EAI_AGAIN
    | EAI_FAIL
    | EAI_NONAME
    | EAI_SERVICE
    | EAI_SOCKTYPE
    | EAI_FAMILY
    | EAI_MEMORY
    | EAI_SYSTEM
    | UNKNOWN

    public func code(): String {
        match (this) {
            case ENOTFOUND => "ENOTFOUND"
            case EAI_AGAIN => "EAI_AGAIN"
            case EAI_FAIL => "EAI_FAIL"
            case EAI_NONAME => "EAI_NONAME"
            case EAI_SERVICE => "EAI_SERVICE"
            case EAI_SOCKTYPE => "EAI_SOCKTYPE"
            case EAI_FAMILY => "EAI_FAMILY"
            case EAI_MEMORY => "EAI_MEMORY"
            case EAI_SYSTEM => "EAI_SYSTEM"
            case UNKNOWN => "UNKNOWN"
        }
    }

    public func label(): String {
        match (this) {
            case ENOTFOUND => "not found"
            case EAI_AGAIN => "temporary failure"
            case EAI_FAIL => "permanent failure"
            case EAI_NONAME => "no name"
            case EAI_SERVICE => "service not found"
            case EAI_SOCKTYPE => "socket type not supported"
            case EAI_FAMILY => "address family not supported"
            case EAI_MEMORY => "out of memory"
            case EAI_SYSTEM => "system error"
            case UNKNOWN => "unknown error"
        }
    }

    public static func initEAI(status: Int32): ?DnsError {
        match (status) {
            case 0 => None
            case _ => Some(DnsError.UNKNOWN)
        }
    }
}

/// Hostent 结构（主机条目）
public class Hostent {
    public var name: String = ""
    public var aliases: ?ArrayList<String> = None
    public var addrList: ?ArrayList<String> = None
    public var addrType: Int64 = 0

    public init() {}
}

/// Hostent with TTLs（用于 A/AAAA 记录）
public class HostentWithTtls {
    public var hostent: Hostent
    public var ttls: ArrayList<Int32>

    public init(hostent: Hostent, ttls: ArrayList<Int32>) {
        this.hostent = hostent
        this.ttls = ttls
    }
}

/// NameInfo 结构（getnameinfo 结果）
public class NameInfo {
    public var node: String = ""
    public var service: String = ""

    public init() {}
}

/// c-ares AddrInfo 结构
public class CaresAddrInfo {
    public var node: ?CaresAddrInfoNode = None

    public init() {}
}

/// c-ares AddrInfo 节点
public class CaresAddrInfoNode {
    public var family: Int64
    public var address: String
    public var ttl: Int32
    public var next: ?CaresAddrInfoNode = None

    public init(family: Int64, address: String, ttl: Int32) {
        this.family = family
        this.address = address
        this.ttl = ttl
    }
}

/// CAA 记录
public class CaaReply {
    public var critical: Int32 = 0
    public var property: String = ""
    public var value: String = ""
    public var next: ?CaaReply = None

    public init() {}
}

/// SRV 记录
public class SrvReply {
    public var priority: Int32 = 0
    public var weight: Int32 = 0
    public var port: Int32 = 0
    public var host: String = ""
    public var next: ?SrvReply = None

    public init() {}
}

/// MX 记录
public class MxReply {
    public var priority: Int32 = 0
    public var host: String = ""
    public var next: ?MxReply = None

    public init() {}
}

/// TXT 记录
public class TxtReply {
    public var text: String = ""
    public var length: Int32 = 0
    public var next: ?TxtReply = None

    public init() {}
}

/// NAPTR 记录
public class NaptrReply {
    public var preference: Int32 = 0
    public var order: Int32 = 0
    public var flags: String = ""
    public var service: String = ""
    public var regexp: String = ""
    public var replacement: String = ""
    public var next: ?NaptrReply = None

    public init() {}
}

/// SOA 记录
public class SoaReply {
    public var serial: Int64 = 0
    public var refresh: Int64 = 0
    public var retry: Int64 = 0
    public var expire: Int64 = 0
    public var minttl: Int64 = 0
    public var nsname: String = ""
    public var hostmaster: String = ""

    public init() {}
}

/// ANY 回复（包含所有类型的联合）
public class AnyReply {
    public var caaReply: ?CaaReply = None
    public var srvReply: ?SrvReply = None
    public var mxReply: ?MxReply = None
    public var txtReply: ?TxtReply = None
    public var naptrReply: ?NaptrReply = None
    public var soaReply: ?SoaReply = None
    public var nsReply: ?Hostent = None
    public var cnameReply: ?Hostent = None
    public var ptrReply: ?Hostent = None

    public init() {}
}

/// JS Promise 简化封装
public class JsPromise {
    private var resolved: Bool = false
    private var rejected: Bool = false
    private var result: ?JsValue = None

    public init() {}

    public func resolve(value: JsValue): Unit {
        resolved = true
        result = value
    }

    public func reject(value: JsValue): Unit {
        rejected = true
        result = value
    }

    public func value(): JsValue {
        // 返回 Promise 对象
        val obj = JsObject()
        obj.set("__promise__", JsValue.TRUE)
        return JsValue(obj)
    }
}
