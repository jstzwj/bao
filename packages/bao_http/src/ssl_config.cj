// bao_http ssl_config - SSL/TLS 配置
// 严格翻译自: src/http/ssl_config.rs (633 行)
package bao_http

import bao_core.*
import bao_collections.*

// ============================================================================
// SSLConfig - SSL/TLS 配置
// 严格翻译自: bun/src/http/ssl_config.rs SSLConfig
//
// Rust SSLConfig:
//   pub struct SSLConfig {
//       pub server_name: CStrPtr,
//       pub key_file_name: CStrPtr,
//       pub cert_file_name: CStrPtr,
//       pub ca_file_name: CStrPtr,
//       pub dh_params_file_name: CStrPtr,
//       pub passphrase: CStrPtr,
//       pub key: CStrSlice,
//       pub cert: CStrSlice,
//       pub ca: CStrSlice,
//       pub secure_options: u32,
//       pub request_cert: i32,
//       pub reject_unauthorized: i32,
//       pub ssl_ciphers: CStrPtr,
//       pub protos: CStrPtr,
//       pub client_renegotiation_limit: u32,
//       pub client_renegotiation_window: u32,
//       pub requires_custom_request_ctx: bool,
//       pub is_using_default_ciphers: bool,
//       pub low_memory_mode: bool,
//       pub cached_hash: AtomicU64,
//   }
//
// 附加类型:
//   SharedPtr (Arc<SSLConfig>) — 原子共享指针
//   WeakPtr (Weak<SSLConfig>)  — 弱引用
//   global_registry — 全局注册表 (弱去重缓存)
// ============================================================================

/// SSL/TLS 配置 — 完整的 SSL 选项
/// 严格翻译自: ssl_config.rs SSLConfig struct
public class SSLConfigFull {
    /// 服务器名称 (SNI)
    /// 严格翻译自: pub server_name: CStrPtr
    public var serverName: String

    /// 私钥文件路径
    /// 严格翻译自: pub key_file_name: CStrPtr
    public var keyFileName: String

    /// 证书文件路径
    /// 严格翻译自: pub cert_file_name: CStrPtr
    public var certFileName: String

    /// CA 证书文件路径
    /// 严格翻译自: pub ca_file_name: CStrPtr
    public var caFileName: String

    /// DH 参数文件路径
    /// 严格翻译自: pub dh_params_file_name: CStrPtr
    public var dhParamsFileName: String

    /// 密码
    /// 严格翻译自: pub passphrase: CStrPtr
    public var passphrase: String

    /// 私钥数据 (PEM 字符串列表)
    /// 严格翻译自: pub key: CStrSlice (Option<Box<[CStrPtr]>>)
    public var key: ArrayList<String>

    /// 证书数据 (PEM 字符串列表)
    /// 严格翻译自: pub cert: CStrSlice
    public var cert: ArrayList<String>

    /// CA 证书数据 (PEM 字符串列表)
    /// 严格翻译自: pub ca: CStrSlice
    public var ca: ArrayList<String>

    /// 安全选项位
    /// 严格翻译自: pub secure_options: u32
    public var secureOptions: UInt32

    /// 是否请求客户端证书
    /// 严格翻译自: pub request_cert: i32
    public var requestCert: Int32

    /// 是否拒绝未授权连接
    /// 严格翻译自: pub reject_unauthorized: i32
    public var rejectUnauthorized: Int32

    /// 密码套件
    /// 严格翻译自: pub ssl_ciphers: CStrPtr
    public var sslCiphers: String

    /// ALPN 协议
    /// 严格翻译自: pub protos: CStrPtr
    public var protos: String

    /// 客户端重协商限制
    /// 严格翻译自: pub client_renegotiation_limit: u32
    public var clientRenegotiationLimit: UInt32

    /// 客户端重协商窗口
    /// 严格翻译自: pub client_renegotiation_window: u32
    public var clientRenegotiationWindow: UInt32

    /// 是否需要自定义请求上下文
    /// 严格翻译自: pub requires_custom_request_ctx: bool
    public var requiresCustomRequestCtx: Bool

    /// 是否使用默认密码套件
    /// 严格翻译自: pub is_using_default_ciphers: bool
    public var isUsingDefaultCiphers: Bool

    /// 低内存模式
    /// 严格翻译自: pub low_memory_mode: bool
    public var lowMemoryMode: Bool

    /// 缓存的内容哈希
    /// 严格翻译自: pub cached_hash: AtomicU64
    public var cachedHash: UInt64

    public init() {
        serverName = ""
        keyFileName = ""
        certFileName = ""
        caFileName = ""
        dhParamsFileName = ""
        passphrase = ""
        key = ArrayList<String>()
        cert = ArrayList<String>()
        ca = ArrayList<String>()
        secureOptions = UInt32(0)
        requestCert = Int32(0)
        rejectUnauthorized = Int32(0)
        sslCiphers = ""
        protos = ""
        clientRenegotiationLimit = UInt32(0)
        clientRenegotiationWindow = UInt32(0)
        requiresCustomRequestCtx = false
        isUsingDefaultCiphers = true
        lowMemoryMode = false
        cachedHash = UInt64(0)
    }

    /// 零值
    /// 严格翻译自: SSLConfig::ZERO / SSLConfig::zero()
    public static func zero(): SSLConfigFull {
        return SSLConfigFull()
    }

    /// 获取 server_name 的字节表示
    /// 严格翻译自: SSLConfig.server_name_bytes
    public func serverNameBytes(): ?Array<UInt8> {
        if (serverName.size == 0) {
            return None
        }
        return stringToBytes(serverName)
    }

    /// 获取 protos 的字节表示
    /// 严格翻译自: SSLConfig.protos_bytes
    public func protosBytes(): ?Array<UInt8> {
        if (protos.size == 0) {
            return None
        }
        return stringToBytes(protos)
    }

    // ========================================================================
    // asUsockets - 转换为 uws socket 选项
    // 严格翻译自: SSLConfig.as_usockets
    //   pub fn as_usockets(&self) -> uws::socket_context::BunSocketContextOptions
    // ========================================================================

    /// 转换为 uws socket 选项
    /// 严格翻译自: SSLConfig.as_usockets
    public func asUsockets(): BunSocketContextOptions {
        let opts = BunSocketContextOptions()

        if (keyFileName.size > 0) {
            opts.keyFileName = keyFileName
        }
        if (certFileName.size > 0) {
            opts.certFileName = certFileName
        }
        if (caFileName.size > 0) {
            opts.caFileName = caFileName
        }
        if (dhParamsFileName.size > 0) {
            opts.dhParamsFileName = dhParamsFileName
        }
        if (passphrase.size > 0) {
            opts.passphrase = passphrase
        }
        opts.sslPreferLowMemoryUsage = if (lowMemoryMode) { 1 } else { 0 }

        if (key.size > 0) {
            opts.key = key
        }
        if (cert.size > 0) {
            opts.cert = cert
        }
        if (ca.size > 0) {
            opts.ca = ca
        }

        if (sslCiphers.size > 0) {
            opts.sslCiphers = sslCiphers
        }
        opts.requestCert = requestCert
        opts.rejectUnauthorized = rejectUnauthorized

        return opts
    }

    // ========================================================================
    // asUsocketsForClientVerification - 客户端验证的 socket 选项
    // 严格翻译自: SSLConfig.as_usockets_for_client_verification
    //   pub fn as_usockets_for_client_verification(&self) -> BunSocketContextOptions
    // ========================================================================

    /// 获取客户端验证的 socket 选项
    /// 严格翻译自: SSLConfig.as_usockets_for_client_verification
    public func asUsocketsForClientVerification(): BunSocketContextOptions {
        let opts = asUsockets()
        opts.requestCert = Int32(1)
        opts.rejectUnauthorized = Int32(0)
        return opts
    }

    // ========================================================================
    // forClientVerification - 复制为客户端验证配置
    // 严格翻译自: SSLConfig.for_client_verification
    // ========================================================================

    /// 复制为客户端验证配置
    /// 严格翻译自: SSLConfig.for_client_verification
    public func forClientVerification(): SSLConfigFull {
        let copy = clone()
        copy.requestCert = Int32(1)
        copy.rejectUnauthorized = Int32(0)
        return copy
    }

    // ========================================================================
    // isSame - 内容比较
    // 严格翻译自: SSLConfig.is_same
    //   pub fn is_same(&self, other: &SSLConfig) -> bool
    // ========================================================================

    /// 内容比较
    /// 严格翻译自: SSLConfig.is_same
    public func isSame(other: SSLConfigFull): Bool {
        if (serverName != other.serverName) { return false }
        if (keyFileName != other.keyFileName) { return false }
        if (certFileName != other.certFileName) { return false }
        if (caFileName != other.caFileName) { return false }
        if (dhParamsFileName != other.dhParamsFileName) { return false }
        if (passphrase != other.passphrase) { return false }

        if (!stringListsEqual(key, other.key)) { return false }
        if (!stringListsEqual(cert, other.cert)) { return false }
        if (!stringListsEqual(ca, other.ca)) { return false }

        if (secureOptions != other.secureOptions) { return false }
        if (requestCert != other.requestCert) { return false }
        if (rejectUnauthorized != other.rejectUnauthorized) { return false }
        if (sslCiphers != other.sslCiphers) { return false }
        if (protos != other.protos) { return false }
        if (clientRenegotiationLimit != other.clientRenegotiationLimit) { return false }
        if (clientRenegotiationWindow != other.clientRenegotiationWindow) { return false }
        if (requiresCustomRequestCtx != other.requiresCustomRequestCtx) { return false }
        if (isUsingDefaultCiphers != other.isUsingDefaultCiphers) { return false }
        if (lowMemoryMode != other.lowMemoryMode) { return false }
        return true
    }

    // ========================================================================
    // contentHash - 内容哈希
    // 严格翻译自: SSLConfig.content_hash
    //   pub fn content_hash(&self) -> u64
    // ========================================================================

    /// 内容哈希 (带缓存)
    /// 严格翻译自: SSLConfig.content_hash
    public func contentHash(): UInt64 {
        if (cachedHash != UInt64(0)) {
            return cachedHash
        }
        var hash: UInt64 = UInt64(0)
        hash = hashField(hash, serverName)
        hash = hashField(hash, keyFileName)
        hash = hashField(hash, certFileName)
        hash = hashField(hash, caFileName)
        hash = hashField(hash, dhParamsFileName)
        hash = hashField(hash, passphrase)
        hash = hashStringList(hash, key)
        hash = hashStringList(hash, cert)
        hash = hashStringList(hash, ca)
        hash = hash + UInt32ToHash(secureOptions)
        hash = hash + UInt32ToHash(UInt32(requestCert))
        hash = hash + UInt32ToHash(UInt32(rejectUnauthorized))
        hash = hashField(hash, sslCiphers)
        hash = hashField(hash, protos)
        hash = hash + UInt32ToHash(clientRenegotiationLimit)
        hash = hash + UInt32ToHash(clientRenegotiationWindow)
        if (requiresCustomRequestCtx) { hash = hash + UInt64(1) }
        if (isUsingDefaultCiphers) { hash = hash + UInt64(2) }
        if (lowMemoryMode) { hash = hash + UInt64(3) }

        // 避免使用 0 作为哈希值 (0 是"未计算"的哨兵值)
        if (hash == UInt64(0)) {
            hash = UInt64(1)
        }
        cachedHash = hash
        return hash
    }

    // ========================================================================
    // clone - 克隆
    // 严格翻译自: impl Clone for SSLConfig
    // ========================================================================

    /// 克隆
    /// 严格翻译自: SSLConfig.clone
    public func clone(): SSLConfigFull {
        let c = SSLConfigFull()
        c.serverName = serverName
        c.keyFileName = keyFileName
        c.certFileName = certFileName
        c.caFileName = caFileName
        c.dhParamsFileName = dhParamsFileName
        c.passphrase = passphrase
        c.key = cloneStringList(key)
        c.cert = cloneStringList(cert)
        c.ca = cloneStringList(ca)
        c.secureOptions = secureOptions
        c.requestCert = requestCert
        c.rejectUnauthorized = rejectUnauthorized
        c.sslCiphers = sslCiphers
        c.protos = protos
        c.clientRenegotiationLimit = clientRenegotiationLimit
        c.clientRenegotiationWindow = clientRenegotiationWindow
        c.requiresCustomRequestCtx = requiresCustomRequestCtx
        c.isUsingDefaultCiphers = isUsingDefaultCiphers
        c.lowMemoryMode = lowMemoryMode
        c.cachedHash = UInt64(0)
        return c
    }

    // ========================================================================
    // deinit - 释放
    // 严格翻译自: SSLConfig.deinit
    // ========================================================================

    /// 释放资源
    /// 严格翻译自: SSLConfig.deinit
    public func deinit(): Unit {
        serverName = ""
        keyFileName = ""
        certFileName = ""
        caFileName = ""
        dhParamsFileName = ""
        passphrase = ""
        key = ArrayList<String>()
        cert = ArrayList<String>()
        ca = ArrayList<String>()
        sslCiphers = ""
        protos = ""
    }

    // ========================================================================
    // takeProtos / takeServerName - 取出并清空字段
    // 严格翻译自: SSLConfig.take_protos / take_server_name
    // ========================================================================

    /// 取出 protos 并清空
    /// 严格翻译自: SSLConfig.take_protos
    public func takeProtos(): ?Array<UInt8> {
        if (protos.size == 0) {
            return None
        }
        let bytes = stringToBytes(protos)
        protos = ""
        return bytes
    }

    /// 取出 server_name 并清空
    /// 严格翻译自: SSLConfig.take_server_name
    public func takeServerName(): ?Array<UInt8> {
        if (serverName.size == 0) {
            return None
        }
        let bytes = stringToBytes(serverName)
        serverName = ""
        return bytes
    }
}

// ============================================================================
// SharedPtr / WeakPtr - 原子共享/弱引用指针
// 严格翻译自:
//   #[derive(Clone)]
//   #[repr(transparent)]
//   pub struct SharedPtr(Arc<SSLConfig>);
//   pub type WeakPtr = Weak<SSLConfig>;
// ============================================================================

/// SSL 配置共享指针
/// 严格翻译自: ssl_config.rs SharedPtr
public class SSLConfigSharedPtr {
    private var config: SSLConfigFull
    private var refCount: Int64

    public init(config: SSLConfigFull) {
        this.config = config
        this.refCount = 1
    }

    /// 获取引用
    /// 严格翻译自: SharedPtr.get
    public func get(): SSLConfigFull {
        return config
    }

    /// 增加引用
    public func ref(): Unit {
        refCount += 1
    }

    /// 减少引用
    public func deref(): Bool {
        refCount -= 1
        return refCount == 0
    }

    /// 克隆弱引用
    /// 严格翻译自: SharedPtr.clone_weak
    public func cloneWeak(): SSLConfigWeakPtr {
        return SSLConfigWeakPtr(this)
    }

    /// 获取引用计数
    public func getRefCount(): Int64 {
        return refCount
    }
}

/// SSL 配置弱引用指针
/// 严格翻译自: ssl_config.rs WeakPtr
public class SSLConfigWeakPtr {
    private var shared: ?SSLConfigSharedPtr

    public init(shared: SSLConfigSharedPtr) {
        this.shared = shared
    }

    /// 尝试升级为强引用
    /// 严格翻译自: Weak::upgrade
    public func upgrade(): ?SSLConfigSharedPtr {
        return shared
    }

    /// 获取裸指针
    /// 严格翻译自: Weak::as_ptr
    public func asPtr(): ?SSLConfigSharedPtr {
        return shared
    }
}

// ============================================================================
// GlobalRegistry - 全局注册表 (弱去重缓存)
// 严格翻译自:
//   pub mod global_registry {
//       static REGISTRY: Mutex<Vec<(u64, WeakPtr)>> = Mutex::new(Vec::new());
//       pub fn intern(config: SSLConfig) -> SharedPtr { ... }
//       pub(super) fn remove(config: &SSLConfig) { ... }
//   }
// ============================================================================

/// 全局注册表 — SSL 配置弱去重缓存
/// 严格翻译自: ssl_config.rs global_registry
public class SSLConfigGlobalRegistry {
    /// 注册表 (hash, weakPtr) 对
    private var entries: ArrayList<SSLConfigRegistryEntry>

    public init() {
        entries = ArrayList<SSLConfigRegistryEntry>()
    }

    // ========================================================================
    // intern - 注册 (去重)
    // 严格翻译自:
    //   pub fn intern(config: SSLConfig) -> SharedPtr {
    //       let hash = config.content_hash();
    //       let new_shared = SharedPtr::new(config);
    //       // 查找已有条目: 匹配 hash + 内容相同
    //       // 如果找到: 返回已有
    //       // 否则: 插入新条目
    //   }
    // ========================================================================

    /// 注册 (去重)
    /// 严格翻译自: global_registry.intern
    public func intern(config: SSLConfigFull): SSLConfigSharedPtr {
        let hash = config.contentHash()
        let newShared = SSLConfigSharedPtr(config)

        // 查找已有条目
        var foundIdx: Int64 = -1
        var i: Int64 = 0
        while (i < entries.size) {
            let entry = entries[i]
            if (entry.hash != hash) {
                i += 1
                continue
            }
            match (entry.weak.upgrade()) {
                case Some(existing) =>
                    if (existing.get().isSame(newShared.get())) {
                        // 找到相同的配置
                        return existing
                    }
                case None =>
                    // 强引用为 0, 可替换
                    foundIdx = i
            }
            i += 1
        }

        // 插入或替换
        if (foundIdx >= 0) {
            entries[Int64(foundIdx)] = SSLConfigRegistryEntry(hash, newShared.cloneWeak())
        } else {
            entries.append(SSLConfigRegistryEntry(hash, newShared.cloneWeak()))
        }
        return newShared
    }

    // ========================================================================
    // remove - 移除
    // 严格翻译自:
    //   pub(super) fn remove(config: &SSLConfig) {
    //       let hash = config.cached_hash.load(Ordering::Relaxed);
    //       // 按指针身份查找并移除
    //   }
    // ========================================================================

    /// 移除
    /// 严格翻译自: global_registry.remove
    public func remove(config: SSLConfigFull): Unit {
        let hash = config.cachedHash
        var i: Int64 = 0
        while (i < entries.size) {
            let entry = entries[i]
            if ((hash == UInt64(0) || entry.hash == hash)) {
                entries.removeAt(i)
                return
            }
            i += 1
        }
    }
}

/// 注册表条目
public class SSLConfigRegistryEntry {
    public var hash: UInt64
    public var weak: SSLConfigWeakPtr

    public init(hash: UInt64, weak: SSLConfigWeakPtr) {
        this.hash = hash
        this.weak = weak
    }
}

/// 全局注册表单例
public var sslConfigGlobalRegistry: SSLConfigGlobalRegistry = SSLConfigGlobalRegistry()

// ============================================================================
// BunSocketContextOptions - uws socket 上下文选项
// 严格翻译自: uws::socket_context::BunSocketContextOptions
// ============================================================================

/// uws Socket 上下文选项
/// 严格翻译自: BunSocketContextOptions
public class BunSocketContextOptions {
    public var keyFileName: String
    public var certFileName: String
    public var caFileName: String
    public var dhParamsFileName: String
    public var passphrase: String
    public var sslPreferLowMemoryUsage: Int32
    public var key: ArrayList<String>
    public var cert: ArrayList<String>
    public var ca: ArrayList<String>
    public var sslCiphers: String
    public var requestCert: Int32
    public var rejectUnauthorized: Int32

    public init() {
        keyFileName = ""
        certFileName = ""
        caFileName = ""
        dhParamsFileName = ""
        passphrase = ""
        sslPreferLowMemoryUsage = Int32(0)
        key = ArrayList<String>()
        cert = ArrayList<String>()
        ca = ArrayList<String>()
        sslCiphers = ""
        requestCert = Int32(0)
        rejectUnauthorized = Int32(0)
    }
}

// ============================================================================
// 辅助函数
// ============================================================================

private func stringToBytes(s: String): Array<UInt8> {
    let bytes = ArrayList<UInt8>()
    for (c in s) {
        bytes.append(c)
    }
    return bytes.toOwnedSlice()
}

private func stringListsEqual(a: ArrayList<String>, b: ArrayList<String>): Bool {
    if (a.size != b.size) { return false }
    for (i in 0..a.size) {
        if (a[i] != b[i]) { return false }
    }
    return true
}

private func cloneStringList(list: ArrayList<String>): ArrayList<String> {
    let result = ArrayList<String>()
    for (s in list) {
        result.append(s)
    }
    return result
}

private func hashField(hash: UInt64, field: String): UInt64 {
    if (field.size > 0) {
        var h = hash
        for (c in field) {
            h = h * UInt64(31) + UInt64(c)
        }
        return h
    }
    return hash
}

private func hashStringList(hash: UInt64, list: ArrayList<String>): UInt64 {
    var h = hash
    for (s in list) {
        h = hashField(h, s)
    }
    return h
}

private func UInt32ToHash(v: UInt32): UInt64 {
    return UInt64(v)
}
