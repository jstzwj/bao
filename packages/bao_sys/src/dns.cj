// bao_sys - DNS 解析
// 严格翻译自: src/dns/ (Bun 的 DNS 解析模块)
//   Bun 使用 c-ares 或 getaddrinfo 进行 DNS 查询
//   仓颉通过 C FFI 调用 getaddrinfo
package bao_sys

import bao_core.*
import bao_collections.*

// ============================================================================
// DNS C FFI 声明
// 对应 Bun: src/dns/ 中的系统调用绑定
// ============================================================================

@C
foreign func getaddrinfo(node: CPointer<Int8>, service: CPointer<Int8>,
                          hints: CPointer<Unit>, res: CPointer<CPointer<Unit>>): Int32
@C
foreign func freeaddrinfo(res: CPointer<Unit>): Unit
@C
foreign func gai_strerror(errcode: Int32): CPointer<Int8>
@C
foreign func getnameinfo(sa: CPointer<Unit>, salen: UIntNative,
    host: CPointer<Int8>, hostlen: UIntNative,
    serv: CPointer<Int8>, servlen: UIntNative,
    flags: Int32): Int32
@C
foreign func inet_pton(af: Int32, src: CPointer<Int8>, dst: CPointer<Unit>): Int32

// getaddrinfo 常量
public class AddrInfoFlags {
    public static let AI_PASSIVE: Int32 = 0x0001
    public static let AI_CANONNAME: Int32 = 0x0002
    public static let AI_NUMERICHOST: Int32 = 0x0004
    public static let AI_V4MAPPED: Int32 = 0x0008
    public static let AI_ALL: Int32 = 0x0010
    public static let AI_ADDRCONFIG: Int32 = 0x0020
    public static let AI_NUMERICSERV: Int32 = 0x0400
}

// ============================================================================
// DNS 解析结果
// ============================================================================

/// DNS 解析结果 - 对应 Bun DnsResolveResult
public class DnsResult {
    /// 解析到的地址列表
    public var addresses: ArrayList<SocketAddr>
    /// 规范名 (可选)
    public var canonName: ?String

    public init() {
        addresses = ArrayList<SocketAddr>()
        canonName = None
    }
}

/// DNS 查询类型 - 对应 Bun DNS 查询选项
public enum BasicDnsRecordType {
    | A     // IPv4
    | AAAA  // IPv6
    | CNAME // 规范名
    | MX    // 邮件交换
    | TXT   // 文本记录
    | NS    // 名称服务器
    | Any   // 所有记录
}

// ============================================================================
// DnsResolver - DNS 解析器
// 严格翻译自: src/dns/dns.zig
//   Bun 使用 c-ares 进行异步 DNS 查询
//   仓颉使用 getaddrinfo 进行同步查询
// ============================================================================

/// DNS 解析器 - 对应 Bun DNS resolver
public class BasicDnsResolver {
    /// 解析主机名到 IPv4/IPv6 地址
    /// 对应 Bun: dns.lookup(hostname, options)
    public static func lookup(hostname: String, port: UInt16): SysMaybe<Array<SocketAddr>> {
        let results = ArrayList<SocketAddr>()
        unsafe {
            let nodePtr = unsafeNewCString(hostname)
            var portStr = port.toString()
            let servicePtr = unsafeNewCString(portStr)

            // 分配 hints 和 result
            let hintsPtr = malloc(UIntNative(64))  // struct addrinfo 大小
            let resPtr = malloc(UIntNative(8))      // 指针

            // 设置 hints: AF_UNSPEC, SOCK_STREAM
            // 简化: 清零 hints 后设置 ai_family, ai_socktype
            memset(hintsPtr, 0, UIntNative(64))
            let familyPtr = CPointer<Int32>(hintsPtr)
            familyPtr.write(Int32(0))  // AF_UNSPEC
            let sockTypePtr = CPointer<Int32>(hintsPtr) + Int64(1)
            sockTypePtr.write(Int32(1))  // SOCK_STREAM

            let rc = getaddrinfo(nodePtr, servicePtr, hintsPtr,
                                  CPointer<CPointer<Unit>>(resPtr))
            free(hintsPtr)
            if (rc != 0) {
                free(resPtr)
                return SysMaybe<Array<SocketAddr>>.Err(
                    SysError(UInt16(Int64(rc)), SysTag.Getaddrinfo))
            }

            // 遍历结果链表
            // struct addrinfo { ai_flags, ai_family, ai_socktype, ai_protocol,
            //                   ai_addrlen, ai_addr, ai_canonname, ai_next }
            var currentPtr = CPointer<Unit>(CPointer<CPointer<Unit>>(resPtr).read())
            var count = 0
            while (!currentPtr.isNull() && count < 64) {
                // 读取 ai_family (偏移 4)
                let familyPtr2 = CPointer<Int32>(currentPtr) + Int64(1)
                let family = familyPtr2.read()

                // 读取 ai_addr (偏移 24, 指针大小 8)
                let addrPtrPtr = CPointer<CPointer<Unit>>(currentPtr) + Int64(3)
                let addrPtr = addrPtrPtr.read()

                if (!addrPtr.isNull()) {
                    if (family == 2) {
                        // AF_INET: sockaddr_in
                        // sin_port 在偏移 2, sin_addr 在偏移 4
                        let portNetPtr = CPointer<UInt16>(addrPtr) + Int64(1)
                        let addrBytePtr = CPointer<UInt8>(addrPtr) + Int64(4)
                        let resolvedPort = ntohs(portNetPtr.read())
                        let a = UInt8(Int32((CPointer<UInt8>(addrPtr) + Int64(4)).read()))
                        let b = UInt8(Int32((CPointer<UInt8>(addrPtr) + Int64(5)).read()))
                        let c = UInt8(Int32((CPointer<UInt8>(addrPtr) + Int64(6)).read()))
                        let d = UInt8(Int32((CPointer<UInt8>(addrPtr) + Int64(7)).read()))
                        results.append(SocketAddr.V4(SocketAddrV4(resolvedPort, a, b, c, d)))
                    } else if (family == 10) {
                        // AF_INET6: sockaddr_in6
                        let portNetPtr = CPointer<UInt16>(addrPtr) + Int64(1)
                        let flowPtr = CPointer<UInt32>(CPointer<UInt8>(addrPtr) + Int64(4))
                        let addrBytePtr = CPointer<UInt8>(addrPtr) + Int64(8)
                        let scopePtr = CPointer<UInt32>(CPointer<UInt8>(addrPtr) + Int64(24))
                        let v6 = SocketAddrV6(ntohs(portNetPtr.read()))
                        v6.flowInfo = ntohl(flowPtr.read())
                        for (i in 0..16) {
                            v6.addr[i] = (addrBytePtr + i).read()
                        }
                        v6.scopeId = ntohl(scopePtr.read())
                        results.append(SocketAddr.V6(v6))
                    }
                }

                // 读取 ai_next (偏移 32)
                let nextPtrPtr = CPointer<CPointer<Unit>>(currentPtr) + Int64(4)
                currentPtr = nextPtrPtr.read()
                count += 1
            }

            freeaddrinfo(CPointer<Unit>(CPointer<CPointer<Unit>>(resPtr).read()))
            free(resPtr)
        }
        return SysMaybe<Array<SocketAddr>>.Ok(results.toOwnedSlice())
    }

    /// 仅解析 IPv4
    public static func lookupV4(hostname: String, port: UInt16): SysMaybe<Array<SocketAddrV4>> {
        let result = lookup(hostname, port)
        match (result) {
            case Err(e) => return SysMaybe<Array<SocketAddrV4>>.Err(e)
            case Ok(addrs) =>
                var v4 = ArrayList<SocketAddrV4>()
                for (addr in addrs) {
                    match (addr) {
                        case SocketAddr.V4(a) => v4.append(a)
                        case _ => ()
                    }
                }
                return SysMaybe<Array<SocketAddrV4>>.Ok(v4.toOwnedSlice())
        }
    }

    /// 仅解析 IPv6
    public static func lookupV6(hostname: String, port: UInt16): SysMaybe<Array<SocketAddrV6>> {
        let result = lookup(hostname, port)
        match (result) {
            case Err(e) => return SysMaybe<Array<SocketAddrV6>>.Err(e)
            case Ok(addrs) =>
                var v6 = ArrayList<SocketAddrV6>()
                for (addr in addrs) {
                    match (addr) {
                        case SocketAddr.V6(a) => v6.append(a)
                        case _ => ()
                    }
                }
                return SysMaybe<Array<SocketAddrV6>>.Ok(v6.toOwnedSlice())
        }
    }

    /// 反向 DNS 查询
    /// 对应 Bun: getnameinfo based reverse DNS lookup
    public static func reverse(ip: String): SysMaybe<String> {
        unsafe {
            let hostBuf = malloc(UIntNative(1025))
            let servBuf = malloc(UIntNative(32))
            let sa = SockAddrFromIp(ip)
            if (sa.isNull()) {
                free(hostBuf)
                free(servBuf)
                return SysMaybe<String>.Err(SysError(0, SysTag.TODO))
            }
            // NI_NAMEREQD = 8
            let rc = getnameinfo(sa, UIntNative(128), hostBuf, UIntNative(1025),
                servBuf, UIntNative(32), Int32(8))
            if (rc != 0) {
                free(hostBuf)
                free(servBuf)
                free(sa)
                return SysMaybe<String>.Err(SysError(UInt16(rc), SysTag.TODO))
            }
            let hostname = CPointer<Int8>(hostBuf).readString()
            free(hostBuf)
            free(servBuf)
            free(sa)
            return SysMaybe<String>.Ok(hostname)
        }
    }
}

/// SockAddrFromIp helper - create a sockaddr from an IP string
/// AF_INET = 2, AF_INET6 = 10
private func SockAddrFromIp(ip: String): CPointer<Unit> {
    unsafe {
        let isV6 = ip.contains(":")
        let af: Int32 = if (isV6) { 10 } else { 2 }
        let saSize: UIntNative = if (isV6) { UIntNative(128) } else { UIntNative(16) }
        let sa = malloc(saSize)
        CPointer<Int8>(sa).write(Int8(0), count: Int64(saSize))
        let ipPtr = unsafeNewCString(ip)
        // Write address family
        let familyPtr = CPointer<Int16>(sa)
        familyPtr.write(Int16(af))
        // Convert IP address
        let dstOffset: Int64 = if (isV6) { Int64(8) } else { Int64(4) }
        let dstPtr = CPointer<Unit>(sa) + dstOffset
        let result = inet_pton(af, ipPtr, dstPtr)
        if (result != 1) {
            free(sa)
            return CPointer<Unit>.null()
        }
        // Set port to 0
        let portPtr = CPointer<Int16>(sa) + Int64(1)
        portPtr.write(Int16(0))
        return sa
    }
}
