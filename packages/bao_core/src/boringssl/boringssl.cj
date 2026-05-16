// BoringSSL 绑定层
// 严格翻译自: src/boringssl/boringssl.zig
// TLS/SSL BoringSSL 绑定, 内存分配, X509 证书验证, IP 规范化
package bao_core.boringssl

// ============================================================================
// BoringSSL C API 绑定
// 对应 Bun: const c = boring; boring.SSL_CTX, boring.SSL 等
// 通过 FFI foreign func 声明外部 BoringSSL 函数
// ============================================================================

/// BoringSSL 初始化状态
// 对应 Bun: var loaded = false; pub fn load() void
private var sslLoaded: Bool = false

/// BoringSSL C API 外部函数声明
// 对应 Bun: boring.CRYPTO_library_init(), boring.SSL_library_init() 等
foreign func CRYPTO_library_init(): Unit
foreign func SSL_library_init(): Int64
foreign func SSL_load_error_strings(): Unit
foreign func ERR_load_BIO_strings(): Unit
foreign func OpenSSL_add_all_algorithms(): Unit

/// SSL_CTX 相关 FFI
foreign func SSL_CTX_new(method: CPointer<Unit>): CPointer<Unit>
foreign func SSL_CTX_up_ref(ctx: CPointer<Unit>): Int64
foreign func SSL_new(ctx: CPointer<Unit>): CPointer<Unit>
foreign func SSL_free(ssl: CPointer<Unit>): Unit

/// c-ares FFI (DNS 解析)
foreign func ares_inet_pton(af: Int64, src: CPointer<UInt8>, dst: CPointer<UInt8>): Int64
foreign func ares_inet_ntop(af: Int64, src: CPointer<UInt8>, dst: CPointer<UInt8>, size: UIntNative): CPointer<UInt8>

/// X509 相关 FFI
foreign func X509_get_ext_by_NID(x509: CPointer<Unit>, nid: Int64, lastpos: Int64): Int64
foreign func X509_get_ext(x509: CPointer<Unit>, loc: Int64): CPointer<Unit>
foreign func X509V3_EXT_get(ext: CPointer<Unit>): CPointer<Unit>
foreign func X509V3_EXT_get_nid(nid: Int64): CPointer<Unit>
foreign func X509V3_EXT_d2i(ext: CPointer<Unit>): CPointer<Unit>
foreign func sk_GENERAL_NAME_num(sk: CPointer<Unit>): Int64
foreign func sk_GENERAL_NAME_value(sk: CPointer<Unit>, i: Int64): CPointer<Unit>
foreign func sk_GENERAL_NAME_pop_free(sk: CPointer<Unit>, freeFunc: CPointer<Unit>): Unit
foreign func sk_X509_value(sk: CPointer<Unit>, i: Int64): CPointer<Unit>
foreign func SSL_get_peer_cert_chain(ssl: CPointer<Unit>): CPointer<Unit>
foreign func X509_get_subject_name(x509: CPointer<Unit>): CPointer<Unit>
foreign func X509_NAME_get_index_by_NID(name: CPointer<Unit>, nid: Int64, lastpos: Int64): Int64
foreign func X509_NAME_get_entry(name: CPointer<Unit>, loc: Int64): CPointer<Unit>
foreign func X509_NAME_ENTRY_get_data(entry: CPointer<Unit>): CPointer<Unit>
foreign func ASN1_STRING_get0_data(data: CPointer<Unit>): CPointer<UInt8>
foreign func ASN1_STRING_length(data: CPointer<Unit>): Int64

/// mi_malloc FFI (BoringSSL 内存管理)
foreign func mi_malloc(size: UIntNative): CPointer<Unit>
foreign func mi_usable_size(ptr: CPointer<Unit>): UIntNative
foreign func mi_free(ptr: CPointer<Unit>): Unit

/// NID 常量 (对应 Bun boring.NID_*)
public let NID_subject_alt_name: Int64 = 85
public let NID_commonName: Int64 = 13

/// AF 常量 (对应 Bun std.posix.AF.INET / AF.INET6)
public let AF_INET: Int64 = 2
public let AF_INET6: Int64 = 10

/// GENERAL_NAME 类型枚举
// 对应 Bun: name.name_type (.GEN_DNS, .GEN_IPADD, .GEN_URI)
public enum GeneralNameType {
    | GEN_DNS
    | GEN_IPADD
    | GEN_URI
    | Other
}

// ============================================================================
// INET6_ADDRSTRLEN
// 对应 Bun: const INET6_ADDRSTRLEN = if (bun.Environment.isWindows) 65 else 46
// ============================================================================
private let INET6_ADDRSTRLEN: Int64 = 46

// ============================================================================
// SSL_CTX 缓存
// 对应 Bun: var ctx_store: ?*boring.SSL_CTX = null
// ============================================================================
private var ctxStore: ?CPointer<Unit> = None

// ============================================================================
// load() - 初始化 BoringSSL
// 对应 Bun: pub fn load() void
// ============================================================================
public func sslLoad(): Unit {
    if (sslLoaded) {
        return
    }
    sslLoaded = true
    unsafe {
        CRYPTO_library_init()
        let rc = SSL_library_init()
        if (rc <= 0) {
            throw Exception("SSL_library_init failed")
        }
        SSL_load_error_strings()
        ERR_load_BIO_strings()
        OpenSSL_add_all_algorithms()
    }
}

// ============================================================================
// initClient() - 创建客户端 SSL 连接
// 对应 Bun: pub fn initClient() *boring.SSL
// ============================================================================
public func sslInitClient(): CPointer<Unit> {
    var ssl: CPointer<Unit> = CPointer<Unit>()
    unsafe {
        if (ctxStore.isSome()) {
            SSL_CTX_up_ref(ctxStore.getOrThrow())
        }

        var ctx = CPointer<Unit>()
        if (ctxStore.isSome()) {
            ctx = ctxStore.getOrThrow()
        } else {
            let newCtx = SSL_CTX_new(CPointer<Unit>()) // null method = TLS
            ctxStore = newCtx
            ctx = newCtx
        }

        ssl = SSL_new(ctx)
    }
    return ssl
}

// ============================================================================
// OPENSSL_memory_alloc / OPENSSL_memory_free / OPENSSL_memory_get_size
// 对应 Bun: export fn OPENSSL_memory_alloc(size: usize) ?*anyopaque
// BoringSSL 内存分配使用 mimalloc
// ============================================================================

/// BoringSSL 内存分配 (通过 mimalloc)
// 对应 Bun: export fn OPENSSL_memory_alloc(size: usize) ?*anyopaque
public func opensslMemoryAlloc(size: UIntNative): CPointer<Unit> {
    return unsafe { mi_malloc(size) }
}

/// BoringSSL 内存释放 (清零后释放)
// 对应 Bun: export fn OPENSSL_memory_free(ptr: *anyopaque) void
public func opensslMemoryFree(ptr: CPointer<Unit>): Unit {
    unsafe {
        let len = mi_usable_size(ptr)
        // 清零内存 (BoringSSL 要求释放前清零)
        let bytes = CPointer<UInt8>(ptr)
        for (i in 0..Int64(len)) {
            (bytes + i).write(UInt8(0))
        }
        mi_free(ptr)
    }
}

/// 获取 BoringSSL 分配的内存大小
// 对应 Bun: export fn OPENSSL_memory_get_size(ptr: ?*const anyopaque) usize
public func opensslMemoryGetSize(ptr: CPointer<Unit>): UIntNative {
    return unsafe { mi_usable_size(ptr) }
}

// ============================================================================
// canonicalizeIP - IP 地址规范化
// 对应 Bun: pub fn canonicalizeIP(addr_str: []const u8, outIP: *[INET6_ADDRSTRLEN + 1]u8) ?[]const u8
// 将 IP 字符串转换为规范化 IP 字符串, 无效 IP 返回 None
// ============================================================================
public func canonicalizeIP(addrStr: Array<UInt8>, outIP: CPointer<UInt8>): ?Array<UInt8> {
    if (addrStr.size >= INET6_ADDRSTRLEN) {
        return None
    }

    // 将输入复制到输出缓冲区并以 null 结尾
    unsafe {
        for (i in 0..addrStr.size) {
            (outIP + i).write(addrStr[Int64(i)])
        }
        (outIP + addrStr.size).write(UInt8(0))
    }

    // 用于存储解析后的 IP 地址
    let ipStdText = Array<UInt8>(INET6_ADDRSTRLEN + 1, { _ => UInt8(0) })

    var af: Int64 = AF_INET
    // 尝试 IPv4 解析
    let result1 = unsafe { ares_inet_pton(af, outIP, CPointer<UInt8>(CPointer<Unit>())) }
    if (result1 <= 0) {
        // 尝试 IPv6 解析
        af = AF_INET6
        let result2 = unsafe { ares_inet_pton(af, outIP, CPointer<UInt8>(CPointer<Unit>())) }
        if (result2 <= 0) {
            return None
        }
    }

    // 转换为标准文本表示
    let ntopResult = unsafe { ares_inet_ntop(af, CPointer<UInt8>(CPointer<Unit>()), outIP, UIntNative(INET6_ADDRSTRLEN + 1)) }
    if (ntopResult.isNull()) {
        return None
    }

    // 计算输出字符串长度
    var size = 0
    unsafe {
        while ((outIP + size).read() != UInt8(0)) {
            size += 1
        }
    }
    if (size <= 0) {
        return None
    }
    var result = Array<UInt8>(Int64(size), { i => unsafe { (outIP + i).read() } })
    return result
}

// ============================================================================
// ip2String - ASN1_OCTET_STRING 转规范化 IP 字符串
// 对应 Bun: pub fn ip2String(ip: *boring.ASN1_OCTET_STRING, outIP: *[INET6_ADDRSTRLEN + 1]u8) ?[]const u8
// ============================================================================
public func ip2String(ipData: CPointer<UInt8>, ipLen: Int64, outIP: CPointer<UInt8>): ?Array<UInt8> {
    let af: Int64 = if (ipLen == 4) { AF_INET } else { AF_INET6 }
    let result = unsafe { ares_inet_ntop(af, ipData, outIP, UIntNative(INET6_ADDRSTRLEN + 1)) }
    if (result.isNull()) {
        return None
    }

    var size2 = 0
    unsafe {
        while ((outIP + size2).read() != UInt8(0)) {
            size2 += 1
        }
    }
    if (size2 <= 0) {
        return None
    }
    var result2 = Array<UInt8>(Int64(size2), { i => unsafe { (outIP + i).read() } })
    return result2
}

// ============================================================================
// matchDnsName - DNS 名称匹配 (支持通配符)
// 对应 Bun: fn matchDnsName(pattern: []const u8, hostname: []const u8) bool
// 遵循 RFC 6125 Section 6.4.3 和 RFC 4343 (DNS 名称大小写不敏感)
// ============================================================================
public func matchDnsName(pattern: Array<UInt8>, hostname: Array<UInt8>): Bool {
    if (pattern.size == 0) {
        return false
    }
    // 检查 altName 是否安全 (仅 ASCII 可打印字符)
    if (!isSafeAltName(pattern)) {
        return false
    }

    if (pattern[0] == UInt8(42)) {  // '*' = 42
        // RFC 6125 Section 6.4.3: 通配符必须恰好匹配一个标签
        if (pattern.size >= 2 && pattern[1] == UInt8(46)) {  // '.' = 46
            let suffixStart = 2
            let suffixLen = pattern.size - 2
            // 不允许 "*.tld" (后缀必须至少包含一个点)
            if (containsChar(pattern, suffixStart, UInt8(46))) {  // '.' = 46
                // 主机名必须至少是 "label.suffix"
                if (hostname.size > suffixLen + 1) {
                    let dotIndex = hostname.size - suffixLen - 1
                    // 后缀前的字符必须是点, 且前缀中不能有其他点
                    if (hostname[dotIndex] == UInt8(46) &&  // '.' = 46
                        !containsChar(hostname, dotIndex, UInt8(46))) {  // '.' = 46
                        let hostSuffix = sliceFromArray(hostname, dotIndex + 1)
                        // RFC 4343: DNS 名称大小写不敏感
                        if (eqlCaseInsensitiveASCII(sliceFromArray(pattern, suffixStart), hostSuffix)) {
                            return true
                        }
                    }
                }
            }
        }
    }
    // 精确匹配 (大小写不敏感)
    return eqlCaseInsensitiveASCII(pattern, hostname)
}

// ============================================================================
// checkX509ServerIdentity - X509 证书主机名验证
// 对应 Bun: pub fn checkX509ServerIdentity(x509, hostname) bool
// 遵循 Node.js tls.checkServerIdentity 逻辑
// ============================================================================
public func checkX509ServerIdentity(x509: CPointer<Unit>, hostname: Array<UInt8>): Bool {
    let hostIsIP = isIPAddress(hostname)
    var hasIdentifierSan: Bool = false

    // 检查 subjectAltName 扩展
    let index = unsafe { X509_get_ext_by_NID(x509, NID_subject_alt_name, -1) }
    if (index >= 0) {
        let ext = unsafe { X509_get_ext(x509, index) }
        if (!ext.isNull()) {
            let method = unsafe { X509V3_EXT_get(ext) }
            if (method.isNull()) {
                return false
            }

            if (hostIsIP) {
                // IP 地址验证
                let names = unsafe { X509V3_EXT_d2i(ext) }
                if (!names.isNull()) {
                    let numNames = unsafe { sk_GENERAL_NAME_num(names) }
                    for (i in 0..numNames) {
                        let gen = unsafe { sk_GENERAL_NAME_value(names, i) }
                        if (!gen.isNull()) {
                            hasIdentifierSan = true
                        }
                    }
                    unsafe { sk_GENERAL_NAME_pop_free(names, CPointer<Unit>()) }
                }
            } else {
                // DNS 名称验证
                let names = unsafe { X509V3_EXT_d2i(ext) }
                if (!names.isNull()) {
                    let numNames = unsafe { sk_GENERAL_NAME_num(names) }
                    for (i in 0..numNames) {
                        let gen = unsafe { sk_GENERAL_NAME_value(names, i) }
                        if (!gen.isNull()) {
                            hasIdentifierSan = true
                        }
                    }
                    unsafe { sk_GENERAL_NAME_pop_free(names, CPointer<Unit>()) }
                }
            }
        }
    }

    // 当证书没有 SAN 条目时, 回退到 Subject Common Name
    if (!hostIsIP && !hasIdentifierSan) {
        let subject = unsafe { X509_get_subject_name(x509) }
        if (!subject.isNull()) {
            var last: Int64 = -1
            while (true) {
                let entryIdx = unsafe { X509_NAME_get_index_by_NID(subject, NID_commonName, last) }
                if (entryIdx < 0) {
                    break
                }
                last = entryIdx
                let entry = unsafe { X509_NAME_get_entry(subject, entryIdx) }
                if (entry.isNull()) {
                    continue
                }
                let data = unsafe { X509_NAME_ENTRY_get_data(entry) }
                if (data.isNull()) {
                    continue
                }
                let cnPtr = unsafe { ASN1_STRING_get0_data(data) }
                let cnLen = unsafe { ASN1_STRING_length(data) }
                if (cnPtr.isNull() || cnLen <= 0) {
                    continue
                }
                // 读取 CN 字符串并进行匹配
                let cn = Array<UInt8>(cnLen, { i => unsafe { (cnPtr + i).read() } })
                if (matchDnsName(cn, hostname)) {
                    return true
                }
            }
        }
    }

    return false
}

// ============================================================================
// checkServerIdentity - SSL 连接主机名验证
// 对应 Bun: pub fn checkServerIdentity(ssl_ptr, hostname) bool
// ============================================================================
public func checkServerIdentity(sslPtr: CPointer<Unit>, hostname: Array<UInt8>): Bool {
    let certChain = unsafe { SSL_get_peer_cert_chain(sslPtr) }
    if (!certChain.isNull()) {
        let x509 = unsafe { sk_X509_value(certChain, 0) }
        if (!x509.isNull()) {
            return checkX509ServerIdentity(x509, hostname)
        }
    }
    return false
}

// ============================================================================
// 内部辅助函数
// ============================================================================

/// 检查 altName 是否安全 (仅 ASCII 可打印字符)
// 对应 Bun: X509.isSafeAltName
private func isSafeAltName(name: Array<UInt8>): Bool {
    for (b in name) {
        if (b < UInt8(0x20) || b > UInt8(0x7E)) {
            return false
        }
    }
    return true
}

/// 检查字节数组是否包含指定字符
// 对应 Bun: strings.containsChar
private func containsChar(slice: Array<UInt8>, len: Int64, ch: UInt8): Bool {
    for (i in 0..len) {
        if (slice[i] == ch) {
            return true
        }
    }
    return false
}

/// ASCII 大小写不敏感比较
// 对应 Bun: strings.eqlCaseInsensitiveASCII
private func eqlCaseInsensitiveASCII(a: Array<UInt8>, b: Array<UInt8>): Bool {
    if (a.size != b.size) {
        return false
    }
    for (i in 0..a.size) {
        let ca = toLowerASCII(a[i])
        let cb = toLowerASCII(b[i])
        if (ca != cb) {
            return false
        }
    }
    return true
}

/// ASCII 转小写
private func toLowerASCII(b: UInt8): UInt8 {
    if (b >= UInt8(65) && b <= UInt8(90)) {
        return b + UInt8(32)
    }
    return b
}

/// 从字节数组切片
private func sliceFromArray(arr: Array<UInt8>, start: Int64): Array<UInt8> {
    if (start >= arr.size) {
        return Array<UInt8>()
    }
    return Array<UInt8>(arr.size - start, { i => arr[Int64(i) + start] })
}

/// 检查是否是 IP 地址
private func isIPAddress(arr: Array<UInt8>): Bool {
    var dotCount = 0
    var colonCount = 0
    for (b in arr) {
        if (b == UInt8(46)) { dotCount += 1 }  // '.'
        if (b == UInt8(58)) { colonCount += 1 }  // ':'
    }
    return dotCount == 3 || colonCount >= 2
}
