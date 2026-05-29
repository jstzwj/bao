// 严格翻译自: src/runtime/api/bun/SSLContextCache.zig
package bao_runtime.api

import bao_jsc.{JsGlobalObject, JsValue}
import bao_core.{Allocator, Output}
import bao_collections.{ArrayList, HashMap}
import bao_runtime.socket.{BoringSSL, BunSocketContextOptions, CreateBunSocketError, SSLConfig, SslCtx}

// ============================================================================
// SSLContextCache - 进程/VM 范围的 SSL_CTX* 弱缓存
// 对应 Bun: src/runtime/api/bun/SSLContextCache.zig
// ============================================================================

/// Digest - SHA-256 摘要 (32 字节)
public type Digest = Array<UInt8>

public class SSLContextCacheEntry {
    public var ctx: ?SSLCtx
    public var owner: ?SSLContextCache

    public init(ctx: SSLCtx, owner: SSLContextCache) {
        this.ctx = Some(ctx)
        this.owner = Some(owner)
    }
}

/// DigestContext - 摘要的哈希和相等比较
public class DigestContext {
    /// SHA-256 输出均匀分布, 前 4 字节是完美的桶哈希
    public static func hash(k!: Digest): UInt32 {
        return k.readUInt32LE(0)
    }

    public static func eql(a!: Digest, b!: Digest): Bool {
        return a.eqlLong(b)
    }
}

/// SSLContextCache - 基于 SSL_CTX 的配置摘要进行缓存
/// 相同配置 = 一个 CTX 每进程
public class SSLContextCache {
    public var map: HashMap<String, SSLContextCacheEntry>
    public var mutex: Mutex
    public var opsSinceCompact: UInt32

    // ========================================================================
    // getOrCreate - 获取或创建 SSL_CTX
    // ========================================================================

    /// 获取或创建 SSL_CTX (+1 引用; 调用者必须 SSL_CTX_free)
    public func getOrCreate(config!: SSLConfig, err!: CreateBunSocketError): ?SSLCtx {
        let opts = config.asUSockets()
        return getOrCreateDigest(opts, opts.digest(), err)
    }

    /// 使用预计算的选项
    public func getOrCreateOpts(opts!: BunSocketContextOptions, err!: CreateBunSocketError): ?SSLCtx {
        return getOrCreateDigest(opts, opts.digest(), err)
    }

    /// 核心入口 - d 已由调用者计算
    public func getOrCreateDigest(opts!: BunSocketContextOptions, d!: Digest, err!: CreateBunSocketError): ?SSLCtx {
        // 在锁内查找
        mutex.lock()
        let key = digestKey(d)
        if (let entry <- map.get(key)) {
            if (let ctx <- entry.ctx) {
                BoringSSL.sslCtxUpRef(ctx)
                mutex.unlock()
                return ctx
            }
        }

        // 未命中: 在锁外构建
        mutex.unlock()
        let ctxOpt = opts.createSSLContext(err)
        if (ctxOpt.isNone()) {
            return none
        }
        let ctx = ctxOpt.get()

        mutex.lock()

        // 重新检查: 另一个调用者可能在我们构建时插入了
        if (let entry <- map.get(key)) {
            if (let existingCtx <- entry.ctx) {
                // 使用已有的, 释放我们创建的
                BoringSSL.sslCtxFree(ctx)
                BoringSSL.sslCtxUpRef(existingCtx)
                mutex.unlock()
                return existingCtx
            }
            // 墓碑: 替换
            entry.ctx = ctx
        } else {
            // 新条目
            let entry = SSLContextCacheEntry(ctx: ctx, owner: this)
            map.put(key, entry)
        }

        // 设置 ex_data 回调
        // ...

        opsSinceCompact += 1
        if (opsSinceCompact >= 64) {
            compact()
            opsSinceCompact = 0
        }

        mutex.unlock()
        return ctx
    }

    // ========================================================================
    // compact - 压缩墓碑条目
    // ========================================================================

    /// compact - 移除墓碑条目
    public func compact(): Unit {
        // Compact placeholder: HashMap iterator/removal shape is still being restored.
    }
}

func digestKey(d: Digest): String {
    return d.toString()
}
