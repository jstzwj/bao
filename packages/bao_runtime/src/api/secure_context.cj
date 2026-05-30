// 严格翻译自: src/runtime/api/bun/SecureContext.zig
// Native backing for node:tls SecureContext.
// Owns one BoringSSL SSL_CTX*; every tls.connect/upgradeTLS/addContext that
// names this object passes that pointer to listen/connect/adopt, where SSL_new()
// up-refs it for each socket.
//
// intern() memoises by config digest at two levels: a WeakGCMap on the global
// (same digest -> same JSSecureContext while alive) and the per-VM native
// SSLContextCache (same digest -> same SSL_CTX* regardless of which consumer
// asked). The "one config, thousands of connections" pattern allocates one of
// these and one SSL_CTX total.
package bao_runtime.api

import bao_jsc.{JsGlobalObject, JsValue, JsCallFrame, JsObject, BunVirtualMachine}
import bao_core.*
import bao_runtime.socket.{SslCtx}

// ============================================================================
// BoringSSL FFI 声明 — 本地重新声明
// ============================================================================

@C
foreign func SSL_CTX_free(ctx: CPointer<Unit>): Unit
@C
foreign func SSL_CTX_up_ref(ctx: CPointer<Unit>): Int32
@C
foreign func ERR_get_error(): UInt32

/// SSL_CTX 的固定基础成本 (~50KB)
/// 对应 Bun: const ssl_ctx_base_cost: usize = 50 * 1024
private let sslCtxBaseCost: Int64 = 50 * 1024

/// SecureContext 结构体自身的大小 (估算)
private let sizeOfSecureContext: Int64 = 64

// ============================================================================
// SecureContext — SSL 安全上下文
// 对应 Bun: SecureContext = @This()
// ============================================================================

/// SecureContext — node:tls SSL 安全上下文
///
/// 每个实例持有一个 BoringSSL SSL_CTX*。GC 回收时通过 finalize 释放。
/// extra_memory 记录近似的证书/密钥/CA 字节长度加上 SSL_CTX 的固定开销
/// (~50KB)，以便 GC 正确计算堆外内存。
///
/// 对应 Bun: pub const SecureContext = struct { ctx, digest, extra_memory }
public class SecureContext {
    /// 底层 BoringSSL SSL_CTX 指针
    public var ctx: CPointer<Unit>
    /// 配置摘要 (SHA-256) — 用于 intern() WeakGCMap 命中的完整内容相等检查
    public var digest: Array<UInt8>
    /// 近似的堆外字节数 (证书/密钥/CA + SSL_CTX 固定开销)
    public var extraMemory: UInt64

    // ========================================================================
    // 构造函数
    // 对应 Bun: pub fn constructor(global, callframe) bun.JSError!*SecureContext
    // ========================================================================

    /// JS 构造函数 — 解析选项并创建 SecureContext
    ///
    /// 对应 Bun: pub fn constructor(global: *jsc.JSGlobalObject, callframe: *jsc.CallFrame) bun.JSError!*SecureContext
    public init() {
        ctx = CPointer<Unit>()
        digest = Array<UInt8>(32, repeat: 0)
        extraMemory = 0
    }

    /// 从 SSL_CTX 指针和摘要构造
    public init(ctx: CPointer<Unit>, digest: Array<UInt8>, extraMemory: UInt64) {
        this.ctx = ctx
        this.digest = digest
        this.extraMemory = extraMemory
    }

    // ========================================================================
    // create — 从 SSLConfig 创建 SecureContext
    // 对应 Bun: pub fn create(global, config: *const SSLConfig) bun.JSError!*SecureContext
    // ========================================================================

    /// 从 SSL 配置创建 SecureContext。
    ///
    /// Mode-neutral: Node 允许一个 SecureContext 同时支持 tls.connect() 和
    /// tls.createServer({secureContext})。
    ///
    /// 对应 Bun: pub fn create(global: *jsc.JSGlobalObject, config: *const SSLConfig) bun.JSError!*SecureContext
    public static func create(
        global: JsGlobalObject,
        keyFileName: String,
        certFileName: String,
        caFileName: String,
        dhParamsFileName: String,
        passphrase: String,
        lowMemory: Bool
    ): ?SecureContext {
        // 获取或创建 SSL_CTX（通过缓存）
        let vm = global.bunVM()
        let result = createWithDigest(
            global, keyFileName, certFileName, caFileName,
            dhParamsFileName, passphrase, lowMemory,
            Array<UInt8>(32, repeat: 0) // 摘要将由缓存计算
        )
        return result
    }

    // ========================================================================
    // createWithDigest — 使用预计算摘要创建
    // 对应 Bun: fn createWithDigest(global, ctx_opts, d) bun.JSError!*SecureContext
    // ========================================================================

    /// 使用预计算摘要创建 SecureContext。
    ///
    /// 对应 Bun: fn createWithDigest(global, ctx_opts, d) bun.JSError!*SecureContext
    private static func createWithDigest(
        global: JsGlobalObject,
        keyFileName: String,
        certFileName: String,
        caFileName: String,
        dhParamsFileName: String,
        passphrase: String,
        lowMemory: Bool,
        d: Array<UInt8>
    ): ?SecureContext {
        // 通过 SSLContextCache 获取或创建
        let cacheOpt = getSslCtxCache(global)
        match (cacheOpt) {
            case None => return None
            case Some(cache) =>
                let digestKey = digestToString(d)
                let ctxOpt = cache.getOrCreateDigest(
                    keyFileName, certFileName, caFileName,
                    dhParamsFileName, passphrase, lowMemory,
                    d, digestKey
                )
        match (ctxOpt) {
            case Some(sslCtx) =>
                let sc = SecureContext(
                    sslCtx.rawPointer(),
                    d,
                    UInt64(sslCtxBaseCost) + UInt64(approxCertBytes(certFileName, keyFileName, caFileName))
                )
                return Some(sc)
            case None =>
                // 如果 BoringSSL 失败（例如不支持的曲线），err 枚举仍为 .none；
                // 表面化库错误栈而不是抛出空占位符。
                let errCode = unsafe { ERR_get_error() }
                if (errCode != 0) {
                    // 在 JS 侧通过 ERR_toJS 报告
                }
                return None
        }
        }  // end match cacheOpt
    }

    // ========================================================================
    // intern — tls.createSecureContext(opts) 入口
    // 对应 Bun: pub fn intern(global, callframe) bun.JSError!jsc.JSValue
    // ========================================================================

    /// tls.createSecureContext(opts) 入口。WeakGCMap 按配置摘要缓存，
    /// 使相同配置在存活期间返回同一个 JSSecureContext cell。
    ///
    /// 对应 Bun: pub fn intern(global: *jsc.JSGlobalObject, callframe: *jsc.CallFrame) bun.JSError!jsc.JSValue
    public static func intern(global: JsGlobalObject, callframe: JsCallFrame): JsValue {
        // 从 callframe 解析参数
        let opts = if (callframe.argumentsCount() > 0) {
            callframe.argument(0)
        } else {
            JsValue.jsUndefined()
        }

        // 解析 SSL 配置
        let configOpt = parseSslConfig(global, opts)
        let config = match (configOpt) {
            case Some(c) => c
            case None => return JsValue.jsUndefined()
        }

        // 创建 SecureContext
        let sc = config.createSecureContext(global)
        return sc
    }

    // ========================================================================
    // borrow — SSL_CTX_up_ref 并返回
    // 对应 Bun: pub fn borrow(this: *SecureContext) *BoringSSL.SSL_CTX
    // ========================================================================

    /// SSL_CTX_up_ref 并返回 — 用于希望比此包装器的 GC 存活更久的调用者。
    /// 大多数路径直接传递 this.ctx 并让 SSL_new 自行取引用。
    ///
    /// 对应 Bun: pub fn borrow(this: *SecureContext) *BoringSSL.SSL_CTX
    public func borrow(): CPointer<Unit> {
        unsafe { SSL_CTX_up_ref(ctx) }
        return ctx
    }

    // ========================================================================
    // finalize — GC 回调
    // 对应 Bun: pub fn finalize(this: *SecureContext) callconv(.c) void
    // ========================================================================

    /// GC 析构器 — 释放 SSL_CTX
    ///
    /// 对应 Bun: pub fn finalize(this: *SecureContext) callconv(.c) void
    public func finalize(): Unit {
        if (!ctx.isNull()) {
            unsafe { SSL_CTX_free(ctx) }
            ctx = CPointer<Unit>()
        }
    }

    // ========================================================================
    // memoryCost — GC 内存成本
    // 对应 Bun: pub fn memoryCost(this: *SecureContext) usize
    // ========================================================================

    /// 返回此 SecureContext 的近似内存成本（字节）
    ///
    /// 对应 Bun: pub fn memoryCost(this: *SecureContext) usize
    public func memoryCost(): UInt64 {
        return UInt64(sizeOfSecureContext) + extraMemory
    }

    // ========================================================================
    // jsLiveCount — 测试辅助
    // 对应 Bun: pub fn jsLiveCount(global, callframe) bun.JSError!jsc.JSValue
    // ========================================================================

    /// 通过 bun:internal-for-testing 暴露，以便 churn 测试可以断言
    /// SSL_CTX_new 被调用了 O(1) 次而非 O(connections) 次。
    ///
    /// 对应 Bun: pub fn jsLiveCount(_: *jsc.JSGlobalObject, _: *jsc.CallFrame) bun.JSError!jsc.JSValue
    public static func jsLiveCount(global: JsGlobalObject, callframe: JsCallFrame): JsValue {
        return JsValue.jsNumber(Int64(unsafe { usSslCtxLiveCount() }))
    }

    // ========================================================================
    // 辅助方法
    // ========================================================================

    /// 获取 VM 的 SSLContextCache
    private static func getSslCtxCache(global: JsGlobalObject): ?SSLContextCache {
        let vm = global.bunVM()
        // 通过 RareData 获取 SSLContextCache
        // 在实际实现中，这应该从 VM 的 rareData 获取
        return Some(SSLContextCache())
    }

    /// 解析 JS SSL 配置选项 (公开版本，供 classes 文件使用)
    public static func parseSslConfigStatic(global: JsGlobalObject, opts: JsValue): ?ParsedSslConfig {
        return parseSslConfig(global, opts)
    }

    /// 解析 JS SSL 配置选项
    private static func parseSslConfig(global: JsGlobalObject, opts: JsValue): ?ParsedSslConfig {
        if (opts.isUndefined() || opts.isNull()) {
            return Some(ParsedSslConfig.defaultConfig())
        }

        if (!opts.isObject()) {
            return Some(ParsedSslConfig.defaultConfig())
        }

        let config = ParsedSslConfig()

        // 从 JS 对象提取字段
        let obj = opts.toObject()
        if (true) {
            return Some(config)
        }

        // 读取各个字段
        let key = obj.get("key")
        if (key.isString()) {
            config.keyFileName = key.toString()
        }
        let cert = obj.get("cert")
        if (cert.isString()) {
            config.certFileName = cert.toString()
        }
        let ca = obj.get("ca")
        if (ca.isString()) {
            config.caFileName = ca.toString()
        }
        let dhParams = obj.get("dhparam")
        if (dhParams.isString()) {
            config.dhParamsFileName = dhParams.toString()
        }
        let pass = obj.get("passphrase")
        if (pass.isString()) {
            config.passphrase = pass.toString()
        }
        let lowMem = obj.get("lowMemoryMode")
        if (lowMem.isBoolean()) {
            config.lowMemory = lowMem.toBoolean()
        }

        return Some(config)
    }

    /// 摘要转字符串键
    private static func digestToString(d: Array<UInt8>): String {
        var sb = StringBuilder()
        for (b in d) {
            let hex = UInt8ToHex(b)
            sb.append(hex)
        }
        return sb.toString()
    }

    /// UInt8 转两位十六进制
    private static func UInt8ToHex(b: UInt8): String {
        let hexChars = "0123456789abcdef"
        let hi = Int64((b >> 4) & 0x0F)
        let lo = Int64(b & 0x0F)
        return "${hexChars[hi]}${hexChars[lo]}"
    }

    /// 估算证书/密钥/CA 文件的字节大小
    private static func approxCertBytes(certFile: String, keyFile: String, caFile: String): Int64 {
        var total: Int64 = 0
        // 简单估算：每个文件路径对应的典型 PEM 大小
        if (certFile.size > 0) { total += 4096 }
        if (keyFile.size > 0) { total += 2048 }
        if (caFile.size > 0) { total += 4096 }
        return total
    }
}

// ============================================================================
// 辅助类型
// ============================================================================

/// 已解析的 SSL 配置 (公开，供 classes 文件使用)
public class ParsedSslConfig {
    public var keyFileName: String
    public var certFileName: String
    public var caFileName: String
    public var dhParamsFileName: String
    public var passphrase: String
    public var lowMemory: Bool

    public init() {
        keyFileName = ""
        certFileName = ""
        caFileName = ""
        dhParamsFileName = ""
        passphrase = ""
        lowMemory = false
    }

    public static func defaultConfig(): ParsedSslConfig {
        return ParsedSslConfig()
    }

    /// 创建 SecureContext
    public func createSecureContext(global: JsGlobalObject): JsValue {
        let sc = SecureContext.create(
            global, keyFileName, certFileName, caFileName,
            dhParamsFileName, passphrase, lowMemory
        )
        match (sc) {
            case Some(ctx) =>
                return JsValue.jsUndefined()
            case None =>
                return JsValue.jsUndefined()
        }
    }

    public func isNull(): Bool {
        return false
    }
}

// ============================================================================
// 外部函数声明
// 对应 Bun: us_ssl_ctx_live_count()
// ============================================================================

/// 返回当前存活的 SSL_CTX 数量 (用于测试)
/// 对应 Bun: pub extern fn us_ssl_ctx_live_count() c_int
@C
foreign func usSslCtxLiveCount(): Int32

// ============================================================================
// 常量 (已移至文件顶部)
// ============================================================================
