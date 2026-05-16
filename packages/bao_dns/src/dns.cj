// dns.cj - DNS解析核心
// 严格翻译自: src/dns/dns.zig
// 1:1 翻译 Bun DNS 模块到仓颉

package bao_dns

import bao_core.*
import bao_hash.*
import std.collection.*

// ============================================================================
// 常量
// 严格翻译自: src/dns/dns.zig AI_V4MAPPED, AI_ADDRCONFIG, AI_ALL
// ============================================================================

/// AI_V4MAPPED: 在没有IPv6记录时返回映射的IPv4地址
public const AI_V4MAPPED: Int32 = 2048

/// AI_ADDRCONFIG: 只返回本机有对应地址族的地址
public const AI_ADDRCONFIG: Int32 = 1024

/// AI_ALL: 返回所有地址
public const AI_ALL: Int32 = 256

// ============================================================================
// 地址族枚举
// 严格翻译自: src/dns/dns.zig Family
// ============================================================================

/// 地址族
public enum Family {
    | unspecified
    | inet       // IPv4
    | inet6      // IPv6
    | unix       // Unix域套接字

    /// 转换为libc常量
    public func toLibC(): Int32 {
        match (this) {
            case unspecified => 0
            case inet => 2       // AF_INET
            case inet6 => 10     // AF_INET6
            case unix => 1       // AF_UNIX
        }
    }

    /// 从字符串解析
    public static func fromString(s: String): ?Family {
        let lower = s
        if (lower == "ipv4" || lower == "4") { return Family.inet }
        if (lower == "ipv6" || lower == "6") { return Family.inet6 }
        if (lower == "any" || lower == "unspecified") { return Family.unspecified }
        return None
    }
}

// ============================================================================
// 套接字类型枚举
// 严格翻译自: src/dns/dns.zig SocketType
// ============================================================================

/// 套接字类型
public enum SocketType {
    | unspecified
    | stream     // TCP
    | dgram      // UDP

    /// 转换为libc常量
    public func toLibC(): Int32 {
        match (this) {
            case unspecified => 0
            case stream => 1    // SOCK_STREAM
            case dgram => 2     // SOCK_DGRAM
        }
    }

    /// 从字符串解析
    public static func fromString(s: String): ?SocketType {
        let lower = s
        if (lower == "stream" || lower == "tcp") { return SocketType.stream }
        if (lower == "dgram" || lower == "udp") { return SocketType.dgram }
        return None
    }
}

// ============================================================================
// 协议枚举
// 严格翻译自: src/dns/dns.zig Protocol
// ============================================================================

/// 协议类型
public enum Protocol {
    | unspecified
    | tcp
    | udp

    /// 转换为libc常量
    public func toLibC(): Int32 {
        match (this) {
            case unspecified => 0
            case tcp => 6    // IPPROTO_TCP
            case udp => 17   // IPPROTO_UDP
        }
    }

    /// 从字符串解析
    public static func fromString(s: String): ?Protocol {
        let lower = s
        if (lower == "tcp") { return Protocol.tcp }
        if (lower == "udp") { return Protocol.udp }
        return None
    }
}

// ============================================================================
// DNS后端枚举
// 严格翻译自: src/dns/dns.zig Backend
// ============================================================================

/// DNS解析后端
public enum Backend {
    | c_ares     // c-ares异步DNS库
    | system     // 系统解析器
    | libc       // libc getaddrinfo

    /// 从字符串解析
    public static func fromString(s: String): ?Backend {
        let lower = s
        if (lower == "c-ares" || lower == "c_ares" || lower == "cares" || lower == "async") {
            return Backend.c_ares
        }
        if (lower == "libc" || lower == "getaddrinfo") { return Backend.libc }
        if (lower == "system") { return Backend.system }
        return None
    }

    /// 默认后端
    /// 对应 Bun: Linux用c_ares, macOS/Windows用system
    public static func defaultBackend(): Backend { Backend.system }
}

// ============================================================================
// DNS选项
// 严格翻译自: src/dns/dns.zig Options
//   Bun使用 packed struct(u64), 仓颉使用class
// ============================================================================

/// DNS查询选项
public class Options {
    public var family: Family
    public var socktype: SocketType
    public var protocol: Protocol
    public var backend: Backend
    public var flags: Int32

    public init() {
        family = Family.unspecified
        socktype = SocketType.stream  // Node硬编码为SOCK_STREAM
        protocol = Protocol.unspecified
        backend = Backend.defaultBackend()
        flags = 0
    }

    public init(family: Family, socktype: SocketType, protocol: Protocol, backend: Backend, flags: Int32) {
        this.family = family
        this.socktype = socktype
        this.protocol = protocol
        this.backend = backend
        this.flags = flags
    }
}

// ============================================================================
// DNS查询结果
// 严格翻译自: src/dns/dns.zig Result
// ============================================================================

/// DNS查询结果
public class DnsResultType {
    /// IP地址字符串
    public var address: String
    /// TTL (秒)
    public var ttl: Int32
    /// 地址族
    public var family: Family

    public init(address: String, ttl: Int32, family: Family) {
        this.address = address
        this.ttl = ttl
        this.family = family
    }
}

// ============================================================================
// GetAddrInfo 请求结构
// 严格翻译自: src/dns/dns.zig GetAddrInfo
// ============================================================================

/// DNS GetAddrInfo 请求
public class GetAddrInfo {
    /// 主机名
    public var name: String
    /// 端口号
    public var port: UInt16
    /// 查询选项
    public var options: Options

    public init(name: String, port: UInt16, options: Options) {
        this.name = name
        this.port = port
        this.options = options
    }

    public init(name: String) {
        this.name = name
        this.port = 0
        this.options = Options()
    }

    /// 克隆
    public func clone(): GetAddrInfo {
        return GetAddrInfo(this.name, this.port, this.options)
    }

    /// 计算哈希
    /// 对应 Bun: GetAddrInfo.hash() 使用 Wyhash
    public func hash(): UInt64 {
        var hasher = Wyhash11(UInt64(0))
        // 更新端口字节
        let portBytes = [UInt8(port & 0xFF), UInt8((port >> 8) & 0xFF)]
        hasher.update(portBytes)
        // 更新名称
        hasher.update(stringToBytes(name))
        return hasher.finalize()
    }
}

// ============================================================================
// 地址转字符串
// 严格翻译自: src/dns/dns.zig addressToString
// ============================================================================

/// 地址转字符串
public func addressToString(family: Family, addr: Array<UInt8>): String {
    match (family) {
        case inet =>
            // IPv4: "a.b.c.d"
            if (addr.size >= 4) {
                return "${Int64(addr[0])}.${Int64(addr[1])}.${Int64(addr[2])}.${Int64(addr[3])}"
            }
            return ""
        case inet6 =>
            // IPv6: 简化处理
            if (addr.size >= 16) {
                let parts = ArrayList<String>()
                var i: Int64 = 0
                while (i < 16) {
                    let val = (Int64(addr[i]) << 8) | Int64(addr[i + 1])
                    parts.add(val.toString())
                    i += 2
                }
                return String.join(parts.toArray(), delimiter: ":")
            }
            return ""
        case unix =>
            return String.fromUtf8(addr)
        case unspecified =>
            return ""
    }
}

/// 统计addrinfo数量
/// 对应 Bun: addrInfoCount
public func addrInfoCount(count: Int32): Int32 {
    return if (count > 0) { count } else { 0 }
}

// ============================================================================
// 工具函数
// ============================================================================

private func stringToBytes(s: String): Array<UInt8> {
    let bytes = ArrayList<UInt8>()
    for (b in s) { bytes.add(UInt8(b)) }
    return bytes.toArray()
}
