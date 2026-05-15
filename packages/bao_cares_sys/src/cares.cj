// 严格翻译自: src/cares_sys/c_ares.zig
package bao_cares_sys

// ============================================================================
// c-ares FFI 函数声明
// 严格翻译自: c_ares.zig 中所有 pub extern fn
// ============================================================================

// --- 库初始化/清理 ---
foreign func ares_library_init(flags: Int32): Int32
foreign func ares_library_init_mem(
    flags: Int32,
    amalloc: CFunc<(UIntNative) -> CPointer<Unit>>,
    afree: CFunc<(CPointer<Unit>) -> Unit>,
    arealloc: CFunc<(CPointer<Unit>, UIntNative) -> CPointer<Unit>>
): Int32
foreign func ares_library_initialized(): Int32
foreign func ares_library_cleanup(): Unit
foreign func ares_version(version: CPointer<Int32>): CString

// --- Channel 管理 ---
foreign func ares_init(channelptr: CPointer<CPointer<Unit>>): Int32
foreign func ares_init_options(channelptr: CPointer<CPointer<Unit>>, options: CPointer<AresOptions>, optmask: Int32): Int32
foreign func ares_save_options(channel: CPointer<Unit>, options: CPointer<AresOptions>, optmask: CPointer<Int32>): Int32
foreign func ares_destroy_options(options: CPointer<AresOptions>): Unit
foreign func ares_dup(dest: CPointer<CPointer<Unit>>, src: CPointer<Unit>): Int32
foreign func ares_destroy(channel: CPointer<Unit>): Unit
foreign func ares_cancel(channel: CPointer<Unit>): Unit

// --- 本地地址设置 ---
foreign func ares_set_local_ip4(channel: CPointer<Unit>, local_ip: UInt32): Unit
foreign func ares_set_local_ip6(channel: CPointer<Unit>, local_ip6: CPointer<UInt8>): Unit
foreign func ares_set_local_dev(channel: CPointer<Unit>, local_dev_name: CString): Unit

// --- Socket 回调 ---
foreign func ares_set_socket_callback(channel: CPointer<Unit>, callback: AresSockCreateCallback, user_data: CPointer<Unit>): Unit
foreign func ares_set_socket_configure_callback(channel: CPointer<Unit>, callback: AresSockConfigCallback, user_data: CPointer<Unit>): Unit
foreign func ares_set_sortlist(channel: CPointer<Unit>, sortstr: CString): Int32

// --- 地址查询 ---
foreign func ares_getaddrinfo(
    channel: CPointer<Unit>,
    node: CString,
    service: CString,
    hints: CPointer<AddrInfoHints>,
    callback: AresAddrinfoCallback,
    arg: CPointer<Unit>
): Unit
foreign func ares_freeaddrinfo(ai: CPointer<Unit>): Unit

// --- Socket 函数 ---
foreign func ares_set_socket_functions(channel: CPointer<Unit>, funcs: CPointer<Unit>, user_data: CPointer<Unit>): Unit

// --- DNS 查询 ---
foreign func ares_send(channel: CPointer<Unit>, qbuf: CPointer<UInt8>, qlen: Int32, callback: AresCallback, arg: CPointer<Unit>): Unit
foreign func ares_query(channel: CPointer<Unit>, name: CString, dnsclass: NSClass, ares_type: NSType, callback: AresCallback, arg: CPointer<Unit>): Unit
foreign func ares_search(channel: CPointer<Unit>, name: CString, dnsclass: Int32, ares_type: Int32, callback: AresCallback, arg: CPointer<Unit>): Unit

// --- 主机查询 ---
foreign func ares_gethostbyname(channel: CPointer<Unit>, name: CString, family: Int32, callback: AresHostCallback, arg: CPointer<Unit>): Unit
foreign func ares_gethostbyname_file(channel: CPointer<Unit>, name: CString, family: Int32, host: CPointer<CPointer<Unit>>): Int32
foreign func ares_gethostbyaddr(channel: CPointer<Unit>, addr: CPointer<Unit>, addrlen: Int32, family: Int32, callback: AresHostCallback, arg: CPointer<Unit>): Unit

// --- 名称信息查询 ---
foreign func ares_getnameinfo(channel: CPointer<Unit>, sa: CPointer<Unit>, salen: UInt32, flags: Int32, callback: AresNameinfoCallback, arg: CPointer<Unit>): Unit

// --- Socket 监控 ---
foreign func ares_getsock(channel: CPointer<Unit>, socks: CPointer<Int32>, numsocks: Int32): Int32
foreign func ares_timeout(channel: CPointer<Unit>, maxtv: CPointer<Unit>, tv: CPointer<Unit>): CPointer<Unit>
foreign func ares_process_fd(channel: CPointer<Unit>, read_fd: Int32, write_fd: Int32): Unit

// --- 查询构造 ---
foreign func ares_create_query(name: CString, dnsclass: Int32, ares_type: Int32, id: UInt16, rd: Int32, buf: CPointer<CPointer<UInt8>>, buflen: CPointer<Int32>, max_udp_size: Int32): Int32
foreign func ares_mkquery(name: CString, dnsclass: Int32, ares_type: Int32, id: UInt16, rd: Int32, buf: CPointer<CPointer<UInt8>>, buflen: CPointer<Int32>): Int32

// --- 名称/字符串展开 ---
foreign func ares_expand_name(encoded: CPointer<UInt8>, abuf: CPointer<UInt8>, alen: Int32, s: CPointer<CPointer<UInt8>>, enclen: CPointer<Int64>): Int32
foreign func ares_expand_string(encoded: CPointer<UInt8>, abuf: CPointer<UInt8>, alen: Int32, s: CPointer<CPointer<UInt8>>, enclen: CPointer<Int64>): Int32

// --- 查询计数 ---
foreign func ares_queue_active_queries(channel: CPointer<Unit>): UIntNative

// --- 解析回复 ---
foreign func ares_parse_a_reply(abuf: CPointer<UInt8>, alen: Int32, host: CPointer<CPointer<Unit>>, addrttls: CPointer<AresAddrttl>, naddrttls: CPointer<Int32>): Int32
foreign func ares_parse_aaaa_reply(abuf: CPointer<UInt8>, alen: Int32, host: CPointer<CPointer<Unit>>, addrttls: CPointer<AresAddr6ttl>, naddrttls: CPointer<Int32>): Int32
foreign func ares_parse_caa_reply(abuf: CPointer<UInt8>, alen: Int32, caa_out: CPointer<CPointer<AresCaaReply>>): Int32
foreign func ares_parse_ptr_reply(abuf: CPointer<UInt8>, alen: Int32, addr: CPointer<Unit>, addrlen: Int32, family: Int32, host: CPointer<CPointer<Unit>>): Int32
foreign func ares_parse_ns_reply(abuf: CPointer<UInt8>, alen: Int32, host: CPointer<CPointer<Unit>>): Int32
foreign func ares_parse_srv_reply(abuf: CPointer<UInt8>, alen: Int32, srv_out: CPointer<CPointer<AresSrvReply>>): Int32
foreign func ares_parse_mx_reply(abuf: CPointer<UInt8>, alen: Int32, mx_out: CPointer<CPointer<AresMxReply>>): Int32
foreign func ares_parse_txt_reply(abuf: CPointer<UInt8>, alen: Int32, txt_out: CPointer<CPointer<AresTxtReply>>): Int32
foreign func ares_parse_txt_reply_ext(abuf: CPointer<UInt8>, alen: Int32, txt_out: CPointer<CPointer<AresTxtExt>>): Int32
foreign func ares_parse_naptr_reply(abuf: CPointer<UInt8>, alen: Int32, naptr_out: CPointer<CPointer<AresNaptrReply>>): Int32
foreign func ares_parse_soa_reply(abuf: CPointer<UInt8>, alen: Int32, soa_out: CPointer<CPointer<AresSoaReply>>): Int32
foreign func ares_parse_uri_reply(abuf: CPointer<UInt8>, alen: Int32, uri_out: CPointer<CPointer<AresUriReply>>): Int32

// --- 内存释放 ---
foreign func ares_free_string(str: CPointer<Unit>): Unit
foreign func ares_free_hostent(host: CPointer<Unit>): Unit
foreign func ares_free_data(dataptr: CPointer<Unit>): Unit

// --- 错误信息 ---
foreign func ares_strerror(code: Int32): CString

// --- 服务器设置 ---
foreign func ares_set_servers(channel: CPointer<Unit>, servers: CPointer<AresAddrNode>): Int32
foreign func ares_set_servers_ports(channel: CPointer<Unit>, servers: CPointer<AresAddrPortNode>): Int32
foreign func ares_set_servers_csv(channel: CPointer<Unit>, servers: CString): Int32
foreign func ares_set_servers_ports_csv(channel: CPointer<Unit>, servers: CString): Int32
foreign func ares_get_servers(channel: CPointer<Unit>, servers: CPointer<CPointer<AresAddrPortNode>>): Int32
foreign func ares_get_servers_ports(channel: CPointer<Unit>, servers: CPointer<CPointer<AresAddrPortNode>>): Int32

// --- 地址转换 ---
foreign func ares_inet_ntop(af: Int32, src: CPointer<Unit>, dst: CPointer<UInt8>, size: UInt32): CString
foreign func ares_inet_pton(af: Int32, src: CString, dst: CPointer<Unit>): Int32
