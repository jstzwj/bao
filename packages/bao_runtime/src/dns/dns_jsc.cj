// dns_jsc.cj - DNS JSC 绑定公共接口
// 对应 Bun 源文件: src/runtime/dns_jsc/mod.rs, mod.zig
// DNS resolver JSC bindings (`node:dns`, `Bun.dns`).
// 本模块是公共表面层，重新导出 dns.cj, cares_jsc.cj, options_jsc.cj 中的类型和方法，
// 使调用方（dispatch, repl_command, udp_socket 等）可以直接使用 `dns_jsc.Foo`。

package bao_runtime.dns

// ============================================================================
// 从 dns.cj 重新导出的核心类型
// 对应 Bun: mod.rs - pub use dns_body::{...}
// ============================================================================

// --- 缓存相关 ---
// CacheConfig: DNS 缓存配置
// ResolveInfoPendingCacheKey: ResolveInfoRequest 待处理缓存键
// GetHostByAddrPendingCacheKey: GetHostByAddrInfoRequest 待处理缓存键
// GetNameInfoPendingCacheKey: GetNameInfoRequest 待处理缓存键
// GetAddrInfoPendingCacheKey: GetAddrInfoRequest 待处理缓存键

// --- 请求相关 ---
// DnsRequest: DNS 请求
// RequestKey: DNS 请求键
// RequestResult: DNS 请求结果
// ResultEntry: DNS 结果条目
// GlobalCache: 全局 DNS 缓存

// --- 解析器 ---
// DnsResolver: DNS 解析器
// DnsOrder: DNS 结果排序顺序
// DnsRecordType: DNS 记录类型
// GetAddrInfo: getaddrinfo 查询参数
// ChannelResult: 通道结果
// Channel: DNS 通道
// ChannelOptions: 通道选项
// CacheHit: 缓存命中类型
// LookupCacheHit: 查询缓存命中类型
// PendingCache: 待处理缓存

// --- 请求封装 ---
// ResolveInfoRequest: 泛型 DNS 解析信息请求
// GetHostByAddrInfoRequest: 反向地址解析请求
// GetNameInfoRequest: getnameinfo 请求
// GetAddrInfoRequest: getaddrinfo 请求
// CAresReverse: 反向 DNS 查询
// CAresLookup: 泛型 c-ares 查询
// CAresNameInfo: getnameinfo 查询
// DNSLookup: DNS 查找

// --- 全局数据 ---
// DnsGlobalData: DNS 全局数据
// DnsInternal: 内部 DNS 缓存和预取

// --- 其他 ---
// DNSRequestOwner: DNS 请求所有者类型
// NormalizeResult: 规范化结果
// DnsOptions: DNS 选项
// DnsFamily: 地址族
// DnsSocketType: 套接字类型
// DnsProtocol: 协议
// DnsBackend: 后端类型

// ============================================================================
// 从 cares_jsc.cj 重新导出的类型
// 对应 Bun: mod.rs - pub mod cares_jsc
// ============================================================================

// --- c-ares 数据类型 ---
// DnsError: DNS 错误码
// Hostent: 主机条目
// HostentWithTtls: 带有 TTL 的主机条目
// NameInfo: getnameinfo 结果
// CaresAddrInfo: c-ares AddrInfo
// CaresAddrInfoNode: c-ares AddrInfo 节点
// CaaReply: CAA 记录
// SrvReply: SRV 记录
// MxReply: MX 记录
// TxtReply: TXT 记录
// NaptrReply: NAPTR 记录
// SoaReply: SOA 记录
// AnyReply: ANY 回复
// DnsErrorDeferred: DNS 错误延迟拒绝

// --- c-ares JS 转换函数 ---
// hostentToJSResponse: hostent -> JS 响应
// hostentWithTtlsToJSResponse: hostent_with_ttls -> JS 响应
// nameinfoToJSResponse: nameinfo -> JS 响应
// caresAddrInfoToJSArray: AddrInfo -> JS 数组
// caaReplyToJSResponse: CAA -> JS 响应
// srvReplyToJSResponse: SRV -> JS 响应
// mxReplyToJSResponse: MX -> JS 响应
// txtReplyToJSResponse: TXT -> JS 响应
// naptrReplyToJSResponse: NAPTR -> JS 响应
// soaReplyToJSResponse: SOA -> JS 响应
// anyReplyToJSResponse: ANY -> JS 响应
// errorToDeferred: 错误转延迟拒绝
// errorToJSWithSyscall: 错误转 JS (带 syscall)
// errorToJSWithSyscallAndHostname: 错误转 JS (带 syscall 和 hostname)
// canonicalizeIP: 规范化 IP 地址

// ============================================================================
// 从 options_jsc.cj 重新导出的类型
// 对应 Bun: mod.rs - pub mod options_jsc
// ============================================================================

// --- JS 选项解析 ---
// optionsFromJS: 从 JS 值解析 DNS 选项
// familyFromJS: 从 JS 值解析地址族
// socketTypeFromJS: 从 JS 值解析套接字类型
// protocolFromJS: 从 JS 值解析协议
// backendFromJS: 从 JS 值解析后端

// --- DNS 结果转 JS ---
// resultAnyToJS: DNS Result.Any -> JS
// resultToJS: 单个 DNS 结果 -> JS 对象
// addressToJS: 网络地址 -> JS 字符串
// addrInfoToJSArray: addrinfo 链 -> JS 数组
// addressToString: 网络地址 -> 字符串

// ============================================================================
// 便捷访问函数
// 对应 Bun: dns_jsc 作为全局 DNS 入口的使用方式
// ============================================================================

/// 获取全局 DNS 解析器
/// 对应 Bun: global_resolver() / RareData::globalDNSResolver()
public func getGlobalResolver(vm: VirtualMachine): DnsResolver {
    let globalData = DnsGlobalData(allocator: SimpleAllocator(), vm: vm)
    return globalData.resolver
}

/// DNS 查找的公共入口
/// 对应 Bun: internal.getaddrinfo
public func dnsLookup(vm: VirtualMachine, host: String, port: UInt16): ?DnsRequest {
    let loop_ = vm.getEventLoop()
    return DnsInternal.getaddrinfo(loop_, host, port, None)
}

/// DNS 预取
/// 对应 Bun: internal.prefetch
public func dnsPrefetch(vm: VirtualMachine, host: String, port: UInt16): Unit {
    let loop_ = vm.getEventLoop()
    DnsInternal.prefetch(loop_, host, port)
}

/// 获取 DNS 缓存统计信息
/// 对应 Bun: internal.getDNSCacheStats
public func getDNSCacheStats(globalObject: JsObject): JsValue {
    return DnsInternal.getDNSCacheStats(globalObject)
}

/// 获取 DNS 结果排序顺序的运行时默认值
/// 对应 Bun: Resolver.getRuntimeDefaultResultOrder
public func getRuntimeDefaultResultOrder(): DnsOrder {
    return DnsOrder.defaultValue()
}

/// 简单分配器实现
class SimpleAllocator <: Allocator {
    public func allocate(size: Int64): ?Array<Byte> {
        return Array<Byte>(size)
    }
    public func free(ptr: Array<Byte>): Unit {}
}
