// 严格翻译自: src/cares_sys/c_ares.zig
package bao_cares_sys

// ============================================================================
// NSClass - DNS 记录类别枚举
// 严格翻译自: c_ares.zig NSClass
// ============================================================================
public enum NSClass {
    | ns_c_invalid
    | ns_c_in
    | ns_c_2
    | ns_c_chaos
    | ns_c_hs
    | ns_c_none
    | ns_c_any
    | ns_c_max
}

// ============================================================================
// NSType - DNS 记录类型枚举
// 严格翻译自: c_ares.zig NSType
// ============================================================================
public enum NSType {
    | ns_t_invalid
    | ns_t_a
    | ns_t_ns
    | ns_t_md
    | ns_t_mf
    | ns_t_cname
    | ns_t_soa
    | ns_t_mb
    | ns_t_mg
    | ns_t_mr
    | ns_t_null
    | ns_t_wks
    | ns_t_ptr
    | ns_t_hinfo
    | ns_t_minfo
    | ns_t_mx
    | ns_t_txt
    | ns_t_rp
    | ns_t_afsdb
    | ns_t_x25
    | ns_t_isdn
    | ns_t_rt
    | ns_t_nsap
    | ns_t_nsap_ptr
    | ns_t_sig
    | ns_t_key
    | ns_t_px
    | ns_t_gpos
    | ns_t_aaaa
    | ns_t_loc
    | ns_t_nxt
    | ns_t_eid
    | ns_t_nimloc
    | ns_t_srv
    | ns_t_atma
    | ns_t_naptr
    | ns_t_kx
    | ns_t_cert
    | ns_t_a6
    | ns_t_dname
    | ns_t_sink
    | ns_t_opt
    | ns_t_apl
    | ns_t_ds
    | ns_t_sshfp
    | ns_t_rrsig
    | ns_t_nsec
    | ns_t_dnskey
    | ns_t_tkey
    | ns_t_tsig
    | ns_t_ixfr
    | ns_t_axfr
    | ns_t_mailb
    | ns_t_maila
    | ns_t_any
    | ns_t_uri
    | ns_t_caa
    | ns_t_max
}

// ============================================================================
// AresError - c-ares 错误码枚举
// 严格翻译自: c_ares.zig Error
// ============================================================================
public enum AresError {
    | ENODATA
    | EFORMERR
    | ESERVFAIL
    | ENOTFOUND
    | ENOTIMP
    | EREFUSED
    | EBADQUERY
    | EBADNAME
    | EBADFAMILY
    | EBADRESP
    | ECONNREFUSED
    | ETIMEOUT
    | EOF
    | EFILE
    | ENOMEM
    | EDESTRUCTION
    | EBADSTR
    | EBADFLAGS
    | ENONAME
    | EBADHINTS
    | ENOTINITIALIZED
    | ELOADIPHLPAPI
    | EADDRGETNETWORKPARAMS
    | ECANCELLED
    | ESERVICE
    | ENOSERVER
}

// ============================================================================
// 回调函数类型
// 严格翻译自: c_ares.zig 中的回调类型定义
// ============================================================================
public type AresCallback = CFunc<(CPointer<Unit>, Int32, Int32, CPointer<UInt8>, Int32) -> Unit>
public type AresHostCallback = CFunc<(CPointer<Unit>, Int32, Int32, CPointer<Unit>) -> Unit>
public type AresNameinfoCallback = CFunc<(CPointer<Unit>, Int32, Int32, CString, CString) -> Unit>
public type AresSockCreateCallback = CFunc<(Int32, Int32, CPointer<Unit>) -> Int32>
public type AresSockConfigCallback = CFunc<(Int32, Int32, CPointer<Unit>) -> Int32>
public type AresAddrinfoCallback = CFunc<(CPointer<Unit>, Int32, Int32, CPointer<Unit>) -> Unit>
public type AresSockStateCallback = CFunc<(CPointer<Unit>, Int32, Int32, Int32) -> Unit>

// ============================================================================
// 结构体定义
// 严格翻译自: c_ares.zig 中的 extern struct
// ============================================================================

/// c-ares 服务器故障转移选项
/// 严格翻译自: struct_ares_server_failover_options
@C
public struct AresServerFailoverOptions {
    public var retry_chance: UInt16 = 0
    public var retry_delay: UIntNative = 0
}

/// c-ares 初始化选项
/// 严格翻译自: Options
@C
public struct AresOptions {
    public var flags: Int32 = 0
    public var timeout: Int32 = 0
    public var tries: Int32 = 0
    public var ndots: Int32 = 0
    public var udp_port: UInt16 = 0
    public var tcp_port: UInt16 = 0
    public var socket_send_buffer_size: Int32 = 0
    public var socket_receive_buffer_size: Int32 = 0
    public var servers: CPointer<Unit> = CPointer<Unit>()
    public var nservers: Int32 = 0
    public var domains: CPointer<CPointer<UInt8>> = CPointer<CPointer<UInt8>>()
    public var ndomains: Int32 = 0
    public var lookups: CString = CString()
    public var sock_state_cb: AresSockStateCallback = AresSockStateCallback()
    public var sock_state_cb_data: CPointer<Unit> = CPointer<Unit>()
    public var sortlist: CPointer<Unit> = CPointer<Unit>()
    public var nsort: Int32 = 0
    public var ednspsz: Int32 = 0
    public var resolvconf_path: CString = CString()
    public var hosts_path: CString = CString()
    public var udp_max_queries: Int32 = 0
    public var maxtimeout: Int32 = 0
    public var qcache_max_ttl: UInt32 = 0
    public var evsys: UInt32 = 0
    public var server_failover_opts: AresServerFailoverOptions = AresServerFailoverOptions()
}

/// hostent 结构体
/// 严格翻译自: struct_hostent
@C
public struct Hostent {
    public var h_name: CString = CString()
    public var h_aliases: CPointer<CPointer<UInt8>> = CPointer<CPointer<UInt8>>()
    public var h_addrtype: Int32 = 0
    public var h_length: Int32 = 0
    public var h_addr_list: CPointer<CPointer<UInt8>> = CPointer<CPointer<UInt8>>()
}

/// nameinfo 结构体
/// 严格翻译自: struct_nameinfo
@C
public struct NameInfo {
    public var node: CPointer<UInt8> = CPointer<UInt8>()
    public var service: CPointer<UInt8> = CPointer<UInt8>()
}

/// AddrInfo CNAME 节点
/// 严格翻译自: AddrInfo_cname
@C
public struct AddrInfoCname {
    public var ttl: Int32 = 0
    public var alias: CPointer<UInt8> = CPointer<UInt8>()
    public var name: CPointer<UInt8> = CPointer<UInt8>()
    public var next: CPointer<AddrInfoCname> = CPointer<AddrInfoCname>()
}

/// AddrInfo 节点
/// 严格翻译自: AddrInfo_node
@C
public struct AddrInfoNode {
    public var ttl: Int32 = 0
    public var flags: Int32 = 0
    public var family: Int32 = 0
    public var socktype: Int32 = 0
    public var protocol: Int32 = 0
    public var addrlen: UInt32 = 0
    public var addr: CPointer<Unit> = CPointer<Unit>()
    public var next: CPointer<AddrInfoNode> = CPointer<AddrInfoNode>()
}

/// AddrInfo
/// 严格翻译自: AddrInfo
@C
public struct AddrInfo {
    public var cnames_: CPointer<AddrInfoCname> = CPointer<AddrInfoCname>()
    public var node: CPointer<AddrInfoNode> = CPointer<AddrInfoNode>()
    public var name_: CString = CString()
}

/// AddrInfo 提示
/// 严格翻译自: AddrInfo_hints
@C
public struct AddrInfoHints {
    public var ai_flags: Int32 = 0
    public var ai_family: Int32 = 0
    public var ai_socktype: Int32 = 0
    public var ai_protocol: Int32 = 0
}

/// c-ares IPv6 地址
/// 严格翻译自: struct_ares_in6_addr
@C
public struct AresIn6Addr {
    public var s6_addr: VArray<UInt8, $16> = VArray<UInt8, $16>(repeat: 0)
}

/// c-ares addr+TTL (A record)
/// 严格翻译自: struct_ares_addrttl
@C
public struct AresAddrttl {
    public var ipaddr: UInt32 = 0
    public var ttl: Int32 = 0
}

/// c-ares addr6+TTL (AAAA record)
/// 严格翻译自: struct_ares_addr6ttl
@C
public struct AresAddr6ttl {
    public var ip6addr: AresIn6Addr = AresIn6Addr()
    public var ttl: Int32 = 0
}

/// CAA 回复
/// 严格翻译自: struct_ares_caa_reply
@C
public struct AresCaaReply {
    public var next: CPointer<AresCaaReply> = CPointer<AresCaaReply>()
    public var critical: Int32 = 0
    public var property: CPointer<UInt8> = CPointer<UInt8>()
    public var plength: UIntNative = 0
    public var value: CPointer<UInt8> = CPointer<UInt8>()
    public var length: UIntNative = 0
}

/// SRV 回复
/// 严格翻译自: struct_ares_srv_reply
@C
public struct AresSrvReply {
    public var next: CPointer<AresSrvReply> = CPointer<AresSrvReply>()
    public var host: CPointer<UInt8> = CPointer<UInt8>()
    public var priority: UInt16 = 0
    public var weight: UInt16 = 0
    public var port: UInt16 = 0
}

/// MX 回复
/// 严格翻译自: struct_ares_mx_reply
@C
public struct AresMxReply {
    public var next: CPointer<AresMxReply> = CPointer<AresMxReply>()
    public var host: CPointer<UInt8> = CPointer<UInt8>()
    public var priority: UInt16 = 0
}

/// TXT 回复
/// 严格翻译自: struct_ares_txt_reply
@C
public struct AresTxtReply {
    public var next: CPointer<AresTxtReply> = CPointer<AresTxtReply>()
    public var txt: CPointer<UInt8> = CPointer<UInt8>()
    public var length: UIntNative = 0
}

/// TXT 扩展回复
/// 严格翻译自: struct_ares_txt_ext
@C
public struct AresTxtExt {
    public var next: CPointer<AresTxtExt> = CPointer<AresTxtExt>()
    public var txt: CPointer<UInt8> = CPointer<UInt8>()
    public var length: UIntNative = 0
    public var record_start: UInt8 = 0
}

/// NAPTR 回复
/// 严格翻译自: struct_ares_naptr_reply
@C
public struct AresNaptrReply {
    public var next: CPointer<AresNaptrReply> = CPointer<AresNaptrReply>()
    public var flags: CPointer<UInt8> = CPointer<UInt8>()
    public var service: CPointer<UInt8> = CPointer<UInt8>()
    public var regexp: CPointer<UInt8> = CPointer<UInt8>()
    public var replacement: CPointer<UInt8> = CPointer<UInt8>()
    public var order: UInt16 = 0
    public var preference: UInt16 = 0
}

/// SOA 回复
/// 严格翻译自: struct_ares_soa_reply
@C
public struct AresSoaReply {
    public var nsname: CPointer<UInt8> = CPointer<UInt8>()
    public var hostmaster: CPointer<UInt8> = CPointer<UInt8>()
    public var serial: UInt32 = 0
    public var refresh: UInt32 = 0
    public var retry: UInt32 = 0
    public var expire: UInt32 = 0
    public var minttl: UInt32 = 0
}

/// URI 回复
/// 严格翻译自: struct_ares_uri_reply
@C
public struct AresUriReply {
    public var next: CPointer<AresUriReply> = CPointer<AresUriReply>()
    public var priority: UInt16 = 0
    public var weight: UInt16 = 0
    public var uri: CPointer<UInt8> = CPointer<UInt8>()
    public var ttl: Int32 = 0
}

/// 地址节点
/// 严格翻译自: struct_ares_addr_node
@C
public struct AresAddrNode {
    public var next: CPointer<AresAddrNode> = CPointer<AresAddrNode>()
    public var family: Int32 = 0
    public var addr: UInt32 = 0
}

/// 地址端口节点
/// 严格翻译自: struct_ares_addr_port_node
@C
public struct AresAddrPortNode {
    public var next: CPointer<AresAddrPortNode> = CPointer<AresAddrPortNode>()
    public var family: Int32 = 0
    public var addr: UInt32 = 0
    public var udp_port: Int32 = 0
    public var tcp_port: Int32 = 0
}

// ============================================================================
// 常量 - ARES 返回码
// 严格翻译自: c_ares.zig ARES_SUCCESS 等
// ============================================================================
public let ARES_SUCCESS: Int32 = 0
public let ARES_ENODATA: Int32 = 1
public let ARES_EFORMERR: Int32 = 2
public let ARES_ESERVFAIL: Int32 = 3
public let ARES_ENOTFOUND: Int32 = 4
public let ARES_ENOTIMP: Int32 = 5
public let ARES_EREFUSED: Int32 = 6
public let ARES_EBADQUERY: Int32 = 7
public let ARES_EBADNAME: Int32 = 8
public let ARES_EBADFAMILY: Int32 = 9
public let ARES_EBADRESP: Int32 = 10
public let ARES_ECONNREFUSED: Int32 = 11
public let ARES_ETIMEOUT: Int32 = 12
public let ARES_EOF: Int32 = 13
public let ARES_EFILE: Int32 = 14
public let ARES_ENOMEM: Int32 = 15
public let ARES_EDESTRUCTION: Int32 = 16
public let ARES_EBADSTR: Int32 = 17
public let ARES_EBADFLAGS: Int32 = 18
public let ARES_ENONAME: Int32 = 19
public let ARES_EBADHINTS: Int32 = 20
public let ARES_ENOTINITIALIZED: Int32 = 21
public let ARES_ELOADIPHLPAPI: Int32 = 22
public let ARES_EADDRGETNETWORKPARAMS: Int32 = 23
public let ARES_ECANCELLED: Int32 = 24
public let ARES_ESERVICE: Int32 = 25
public let ARES_ENOSERVER: Int32 = 26

// ============================================================================
// 常量 - ARES 标志
// 严格翻译自: c_ares.zig ARES_FLAG_* 等
// ============================================================================
public let ARES_FLAG_USEVC: Int32 = 1 << 0
public let ARES_FLAG_PRIMARY: Int32 = 1 << 1
public let ARES_FLAG_IGNTC: Int32 = 1 << 2
public let ARES_FLAG_NORECURSE: Int32 = 1 << 3
public let ARES_FLAG_STAYOPEN: Int32 = 1 << 4
public let ARES_FLAG_NOSEARCH: Int32 = 1 << 5
public let ARES_FLAG_NOALIASES: Int32 = 1 << 6
public let ARES_FLAG_NOCHECKRESP: Int32 = 1 << 7
public let ARES_FLAG_EDNS: Int32 = 1 << 8
public let ARES_FLAG_NO_DFLT_SVR: Int32 = 1 << 9

// ============================================================================
// 常量 - ARES 选项掩码
// 严格翻译自: c_ares.zig ARES_OPT_* 等
// ============================================================================
public let ARES_OPT_FLAGS: Int32 = 1 << 0
public let ARES_OPT_TIMEOUT: Int32 = 1 << 1
public let ARES_OPT_TRIES: Int32 = 1 << 2
public let ARES_OPT_NDOTS: Int32 = 1 << 3
public let ARES_OPT_UDP_PORT: Int32 = 1 << 4
public let ARES_OPT_TCP_PORT: Int32 = 1 << 5
public let ARES_OPT_SERVERS: Int32 = 1 << 6
public let ARES_OPT_DOMAINS: Int32 = 1 << 7
public let ARES_OPT_LOOKUPS: Int32 = 1 << 8
public let ARES_OPT_SOCK_STATE_CB: Int32 = 1 << 9
public let ARES_OPT_SORTLIST: Int32 = 1 << 10
public let ARES_OPT_SOCK_SNDBUF: Int32 = 1 << 11
public let ARES_OPT_SOCK_RCVBUF: Int32 = 1 << 12
public let ARES_OPT_TIMEOUTMS: Int32 = 1 << 13
public let ARES_OPT_ROTATE: Int32 = 1 << 14
public let ARES_OPT_EDNSPSZ: Int32 = 1 << 15
public let ARES_OPT_NOROTATE: Int32 = 1 << 16
public let ARES_OPT_RESOLVCONF: Int32 = 1 << 17
public let ARES_OPT_HOSTS_FILE: Int32 = 1 << 18

// ============================================================================
// 常量 - ARES NI 标志
// 严格翻译自: c_ares.zig ARES_NI_* 等
// ============================================================================
public let ARES_NI_NOFQDN: Int32 = 1 << 0
public let ARES_NI_NUMERICHOST: Int32 = 1 << 1
public let ARES_NI_NAMEREQD: Int32 = 1 << 2
public let ARES_NI_NUMERICSERV: Int32 = 1 << 3
public let ARES_NI_DGRAM: Int32 = 1 << 4
public let ARES_NI_TCP: Int32 = 0
public let ARES_NI_UDP: Int32 = ARES_NI_DGRAM
public let ARES_NI_SCTP: Int32 = 1 << 5
public let ARES_NI_DCCP: Int32 = 1 << 6
public let ARES_NI_NUMERICSCOPE: Int32 = 1 << 7
public let ARES_NI_LOOKUPHOST: Int32 = 1 << 8
public let ARES_NI_LOOKUPSERVICE: Int32 = 1 << 9
public let ARES_NI_IDN: Int32 = 1 << 10
public let ARES_NI_IDN_ALLOW_UNASSIGNED: Int32 = 1 << 11
public let ARES_NI_IDN_USE_STD3_ASCII_RULES: Int32 = 1 << 12

// ============================================================================
// 常量 - ARES AI 标志
// 严格翻译自: c_ares.zig ARES_AI_* 等
// ============================================================================
public let ARES_AI_CANONNAME: Int32 = 1 << 0
public let ARES_AI_NUMERICHOST: Int32 = 1 << 1
public let ARES_AI_PASSIVE: Int32 = 1 << 2
public let ARES_AI_NUMERICSERV: Int32 = 1 << 3
public let ARES_AI_V4MAPPED: Int32 = 1 << 4
public let ARES_AI_ALL: Int32 = 1 << 5
public let ARES_AI_ADDRCONFIG: Int32 = 1 << 6
public let ARES_AI_NOSORT: Int32 = 1 << 7
public let ARES_AI_ENVHOSTS: Int32 = 1 << 8
public let ARES_AI_IDN: Int32 = 1 << 10
public let ARES_AI_IDN_ALLOW_UNASSIGNED: Int32 = 1 << 11
public let ARES_AI_IDN_USE_STD3_ASCII_RULES: Int32 = 1 << 12
public let ARES_AI_CANONIDN: Int32 = 1 << 13

// ============================================================================
// 常量 - 事件系统
// 严格翻译自: c_ares.zig ARES_EVSYS_*
// ============================================================================
public let ARES_EVSYS_DEFAULT: Int32 = 0
public let ARES_EVSYS_WIN32: Int32 = 1
public let ARES_EVSYS_EPOLL: Int32 = 2
public let ARES_EVSYS_KQUEUE: Int32 = 3
public let ARES_EVSYS_POLL: Int32 = 4
public let ARES_EVSYS_SELECT: Int32 = 5

// ============================================================================
// 常量 - 其他
// 严格翻译自: c_ares.zig ARES_LIB_INIT_* 等
// ============================================================================
public let ARES_LIB_INIT_NONE: Int32 = 0
public let ARES_LIB_INIT_WIN32: Int32 = 1 << 0
public let ARES_LIB_INIT_ALL: Int32 = ARES_LIB_INIT_WIN32
public let ARES_GETSOCK_MAXNUM: Int32 = 16
public let ARES_SOCKET_BAD: Int32 = -1
