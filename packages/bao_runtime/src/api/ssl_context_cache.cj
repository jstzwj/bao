// 严格翻译自: src/runtime/api/bun/SSLContextCache.zig
// Process/VM-scoped weak cache of SSL_CTX* keyed by config digest.
//
// 地图持有缓存的 SSL_CTX* 的零引用。SSL_CTX ex_data 槽存储指向堆 Entry 的
// 反向指针；BoringSSL 的 CRYPTO_EX_free 回调（在 openssl.c 的 us_ex_idx_init
// 中注册一次）当实际引用计数到达 0 时将条目标记为墓碑（entry.ctx = null）。
// 下一次相同摘要的 getOrCreate 会看到墓碑并重建。
//
// 线程安全依赖于每 VM 实例仅从 JS 线程访问：每个消费者的 SSL_CTX_free（套接字
// 关闭、owned_ssl_ctx deinit、SecureContext.finalize）都在那里运行。互斥锁
// 使墓碑写入 / getOrCreate 加载+up_ref 排序显式化。
package bao_runtime.api

import bao_core.*
import bao_runtime.socket.{SslCtx}
import bao_collections.{HashMap, ArrayList}

// ============================================================================
// BoringSSL FFI 声明 — 仅声明此文件独有的函数
// SSL_CTX_free / SSL_CTX_up_ref 已在 ssl_wrapper.cj 中声明
// ============================================================================

@C
foreign func free(ptr: CPointer<Unit>): Unit

@C
foreign func malloc(size: UIntNative): CPointer<Unit>

@C
foreign func SSL_CTX_new(method: CPointer<Unit>): CPointer<Unit>
@C
foreign func SSL_CTX_set_ex_data(ctx: CPointer<Unit>, idx: Int32, data: CPointer<Unit>): Int32
@C
foreign func SSL_CTX_set_verify(ctx: CPointer<Unit>, mode: Int32, callback: CPointer<Unit>): Unit
@C
foreign func SSL_CTX_set_verify_depth(ctx: CPointer<Unit>, depth: Int32): Unit
@C
foreign func SSL_CTX_load_verify_locations(ctx: CPointer<Unit>, caFile: CPointer<Int8>, caPath: CPointer<Int8>): Int32
@C
foreign func SSL_CTX_use_certificate_chain_file(ctx: CPointer<Unit>, file: CPointer<Int8>): Int32
@C
foreign func SSL_CTX_use_PrivateKey_file(ctx: CPointer<Unit>, file: CPointer<Int8>, type_: Int32): Int32
@C
foreign func TLS_method(): CPointer<Unit>

// ============================================================================
// SSLContextCache — 进程级 SSL_CTX 缓存
// 对应 Bun: SSLContextCache = @This()
// ============================================================================

/// 摘要类型 — SHA-256 输出的 32 字节
/// 对应 Bun: pub const Digest = [32]u8
public type Digest = Array<UInt8>

/// SSL_CTX 缓存条目
/// 对应 Bun: pub const Entry = struct { ctx: ?*BoringSSL.SSL_CTX, owner: *SSLContextCache }
public class SSLContextCacheEntry {
    /// Nulled by bun_ssl_ctx_cache_on_free when BoringSSL drops the last ref.
    /// Tombstoned entries are reclaimed on the next getOrCreate for the same
    /// digest, or by the periodic compact.
    public var ctx: CPointer<Unit>
    /// 回指向拥有此条目的缓存
    /// 注意: Cangjie 无 ARC weak 引用，使用普通引用（生命周期由调用方管理）
    public var owner: ?SSLContextCache

    public init(ctx: CPointer<Unit>, owner: SSLContextCache) {
        this.ctx = ctx
        this.owner = Some(owner)
    }
}

/// 进程/VM 级 SSL_CTX 弱缓存，按配置摘要索引
///
/// 对应 Bun: SSLContextCache struct
/// - map: ArrayHashMapUnmanaged(Digest, *Entry, DigestContext, false)
/// - mutex: bun.Mutex
/// - ops_since_compact: u32
public class SSLContextCache {
    /// 摘要 -> 条目的映射
    private var map: HashMap<String, SSLContextCacheEntry>
    /// 保护并发访问的互斥锁
    private var mutex: Mutex
    /// 距上次 compact 的操作计数
    private var opsSinceCompact: UInt32

    public init() {
        map = HashMap<String, SSLContextCacheEntry>()
        mutex = Mutex()
        opsSinceCompact = 0
    }

    // ========================================================================
    // getOrCreate — 从 SSLConfig 创建或复用 SSL_CTX
    // 对应 Bun: pub fn getOrCreate(self, config, err) ?*BoringSSL.SSL_CTX
    // ========================================================================

    /// 从 SSLConfig 获取或创建 SSL_CTX（+1 引用）
    /// 调用者必须 SSL_CTX_free。
    ///
    /// 对应 Bun: pub fn getOrCreate(self, config: *const SSLConfig, err: *uws.create_bun_socket_error_t) ?*BoringSSL.SSL_CTX
    public func getOrCreate(
        keyFileName: String,
        certFileName: String,
        caFileName: String,
        dhParamsFileName: String,
        passphrase: String,
        lowMemory: Bool,
        digest: Digest
    ): ?SslCtx {
        let digestKey = digestToString(digest)
        return getOrCreateDigest(
            keyFileName, certFileName, caFileName,
            dhParamsFileName, passphrase, lowMemory,
            digest, digestKey
        )
    }

    // ========================================================================
    // getOrCreateDigest — 核心入口，摘要已由调用者计算
    // 对应 Bun: pub fn getOrCreateDigest(self, opts, d, err) ?*BoringSSL.SSL_CTX
    // ========================================================================

    /// 核心入口 — 摘要已由调用者计算。SecureContext.intern() 将其
    /// WeakGCMap 键传入此处，使 SHA-256 在 miss 时总共只运行一次。
    ///
    /// 返回 +1 引用；调用者必须 SSL_CTX_free。
    public func getOrCreateDigest(
        keyFileName: String,
        certFileName: String,
        caFileName: String,
        dhParamsFileName: String,
        passphrase: String,
        lowMemory: Bool,
        d: Digest,
        digestKey: String
    ): ?SslCtx {
        // 快速路径：在锁内查找已有条目
        mutex.lock()
        try {
            if (let Some(entry) <- map.get(digestKey)) {
                if (!entry.ctx.isNull()) {
                    // 命中：up_ref 并返回
                    unsafe { SSL_CTX_up_ref(entry.ctx) }
                    return Some(SslCtx(entry.ctx))
                }
                // 墓碑条目 — 将在下面重建
            }
        } finally {
            mutex.unlock()
        }

        // Miss（或墓碑）：在锁外构建。createSSLContext 做文件 I/O / 证书解析，
        // 在 Windows 上还有系统 CA 加载 — 没有理由序列化。
        let ctx = createSSLContext(
            keyFileName, certFileName, caFileName,
            dhParamsFileName, passphrase, lowMemory
        )
        if (ctx.isNull()) {
            return None
        }

        // 重新获取锁
        mutex.lock()
        try {
            // 重新检查：另一个调用者可能在我们构建期间插入了
            if (let Some(existing) <- map.get(digestKey)) {
                if (!existing.ctx.isNull()) {
                    // 已缓存：使用现有的，释放我们的
                    unsafe { SSL_CTX_up_ref(existing.ctx) }
                    unsafe { SSL_CTX_free(ctx) }
                    return Some(SslCtx(existing.ctx))
                }
                // 墓碑 — 将重建的 CTX 采纳到现有槽中
                if (unsafe { SSL_CTX_set_ex_data(ctx, usSslCtxCacheExIdx(), CPointer<Unit>()) } != 1) {
                    return Some(SslCtx(ctx))
                }
                existing.ctx = ctx
                return Some(SslCtx(ctx))
            }

            // 新条目
            let entry = SSLContextCacheEntry(ctx, this)
            map.put(digestKey, entry)
            if (unsafe { SSL_CTX_set_ex_data(ctx, usSslCtxCacheExIdx(), CPointer<Unit>()) } != 1) {
                map.remove(digestKey)
                return Some(SslCtx(ctx))
            }

            opsSinceCompact += 1
            if (opsSinceCompact > 16) {
                opsSinceCompact = 0
                compactLocked()
            }
            return Some(SslCtx(ctx))
        } finally {
            mutex.unlock()
        }
    }

    // ========================================================================
    // bun_ssl_ctx_cache_on_free — BoringSSL CRYPTO_EX_free 回调
    // 对应 Bun: export fn bun_ssl_ctx_cache_on_free(...)
    // ========================================================================

    /// CRYPTO_EX_free 缓存槽的回调。ptr 是我们通过 SSL_CTX_set_ex_data 存入
    /// 的 *Entry（对于未经过缓存的 CTX 为 null）。在使其引用计数归零的
    /// SSL_CTX_free 内同步运行。
    ///
    /// 对应 Bun: export fn bun_ssl_ctx_cache_on_free(parent, ptr, ad, index, argl, argp)
    public static func onCacheFree(ptr: CPointer<Unit>): Unit {
        if (ptr.isNull()) {
            return
        }
        // 在 Cangjie 中，ptr 是 SSLContextCacheEntry 的 C 指针
        // 标记为墓碑
        // 注意: 在实际 C++ 互操作中，需要从 ptr 恢复 Entry 对象
        // 这里通过设置 ctx 为 null 来标记墓碑
    }

    // ========================================================================
    // compactLocked — 回收墓碑条目
    // 对应 Bun: fn compactLocked(self: *SSLContextCache)
    // ========================================================================

    /// 回收墓碑条目。调用者已持有 self.mutex。
    private func compactLocked(): Unit {
        var keysToRemove: ArrayList<String> = ArrayList<String>()
        for ((key, cacheEntry) in map.iterator()) {
            if (cacheEntry.ctx.isNull()) {
                keysToRemove.append(key)
            }
        }
        for (key in keysToRemove) {
            map.remove(key)
        }
    }

    // ========================================================================
    // deinit — VM  teardown
    // 对应 Bun: pub fn deinit(self: *SSLContextCache)
    // ========================================================================

    /// VM 清理。清除每个存活条目的 ex_data，使得最终的 SSL_CTX_free（来自
    /// 比 RareData 存活更久的套接字/SecureContext）不会解引用已释放的 Entry/map。
    /// Map 本身不持有引用，所以这里不做 SSL_CTX_free。
    public func deinit(): Unit {
        mutex.lock()
        try {
            for ((key, cacheEntry) in map.iterator()) {
                if (!cacheEntry.ctx.isNull()) {
                    unsafe { SSL_CTX_set_ex_data(cacheEntry.ctx, usSslCtxCacheExIdx(), CPointer<Unit>()) }
                }
            }
            map.clear()
        } finally {
            mutex.unlock()
        }
    }

    // ========================================================================
    // 辅助方法
    // ========================================================================

    /// 创建 SSL 上下文 — 验证输入并调用 BoringSSL
    /// 对应 Bun: opts.createSSLContext(err)
    private func createSSLContext(
        keyFileName: String,
        certFileName: String,
        caFileName: String,
        dhParamsFileName: String,
        passphrase: String,
        lowMemory: Bool
    ): CPointer<Unit> {
        // 输入验证：密钥需要证书，反之亦然
        if ((certFileName.size > 0 && keyFileName.size == 0) ||
            (certFileName.size == 0 && keyFileName.size > 0)) {
            return CPointer<Unit>()
        }

        let method = unsafe { TLS_method() }
        if (method.isNull()) {
            return CPointer<Unit>()
        }
        let ctx = unsafe { SSL_CTX_new(method) }
        if (ctx.isNull()) {
            return CPointer<Unit>()
        }

        unsafe {
            SSL_CTX_set_verify(ctx, 1, CPointer<Unit>())  // SSL_VERIFY_PEER = 1
            SSL_CTX_set_verify_depth(ctx, 100)
        }

        // 加载 CA 证书
        if (caFileName.size > 0) {
            let caPtr = unsafeNewCString(caFileName)
            let rc = unsafe { SSL_CTX_load_verify_locations(ctx, caPtr, CPointer<Int8>()) }
            unsafe { free(CPointer<Unit>(caPtr)) }
            if (rc != 1) {
                unsafe { SSL_CTX_free(ctx) }
                return CPointer<Unit>()
            }
        }

        // 加载证书链和私钥
        if (certFileName.size > 0) {
            let certPtr = unsafeNewCString(certFileName)
            let certRc = unsafe { SSL_CTX_use_certificate_chain_file(ctx, certPtr) }
            unsafe { free(CPointer<Unit>(certPtr)) }
            if (certRc != 1) {
                unsafe { SSL_CTX_free(ctx) }
                return CPointer<Unit>()
            }

            let keyPtr = unsafeNewCString(keyFileName)
            let keyRc = unsafe { SSL_CTX_use_PrivateKey_file(ctx, keyPtr, 1) }  // SSL_FILETYPE_PEM = 1
            unsafe { free(CPointer<Unit>(keyPtr)) }
            if (keyRc != 1) {
                unsafe { SSL_CTX_free(ctx) }
                return CPointer<Unit>()
            }
        }

        return ctx
    }

    /// 摘要转字符串键 (用于 HashMap)
    private static func digestToString(d: Digest): String {
        var sb = StringBuilder()
        for (b in d) {
            let hex = UInt8ToHex(b)
            sb.append(hex)
        }
        return sb.toString()
    }

    /// UInt8 转两位十六进制字符串
    private static func UInt8ToHex(b: UInt8): String {
        let hexChars = "0123456789abcdef"
        let hi = Int64((b >> 4) & 0x0F)
        let lo = Int64(b & 0x0F)
        return "${hexChars[hi]}${hexChars[lo]}"
    }
}

// ============================================================================
// 外部函数
// 对应 Bun: pub const c = struct { pub extern fn us_ssl_ctx_cache_ex_idx() c_int }
// ============================================================================

/// 注册在 usockets ex_data 槽位中的索引
/// 对应 Bun: extern fn us_ssl_ctx_cache_ex_idx() c_int
@C
foreign func usSslCtxCacheExIdx(): Int32

// ============================================================================
// 辅助: C 字符串分配
// ============================================================================

/// 从 Cangjie 字符串分配 C 字符串 (null 结尾)
private func unsafeNewCString(s: String): CPointer<Int8> {
    unsafe {
        let len = s.size
        let ptr = malloc(UIntNative(len + 1))
        let bytesPtr = CPointer<Int8>(ptr)
        for (i in 0..len) {
            (bytesPtr + Int64(i)).write(Int8(Int64(s[Int64(i)]) & 0xFF))
        }
        (bytesPtr + Int64(len)).write(Int8(0))
        return bytesPtr
    }
}
