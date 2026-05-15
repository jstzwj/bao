// 严格翻译自: src/runtime/api/bun/SecureContext.zig
package bao_runtime

import bao_jsc.*
import bao_core.*

// ============================================================================
// SecureContext - node:tls SecureContext 的原生支持
// 对应 Bun: src/runtime/api/bun/SecureContext.zig
// ============================================================================

/// SecureContext - 拥有一个 BoringSSL SSL_CTX*
/// 每个 tls.connect/upgradeTLS/addContext 使用此对象传递指针
public class SecureContext {
    public var ctx: SSLCtx
    public var digest: Array<UInt8>  // 32 字节摘要
    public var extraMemory: Int

    // ========================================================================
    // 构造函数
    // ========================================================================

    /// 构造函数 - 从 JS 参数创建
    public static func constructor(global: JsGlobalObject, callframe: JsCallFrame): SecureContext {
        let args = callframe.arguments()
        let opts = args.len > 0 ? args[0] : JsValue.jsUndefined

        var config = try SSLConfig.fromJS(global.bunVM(), global, opts) ?? SSLConfig.zero
        defer config.deinit()

        return try create(global, config)
    }

    /// 创建 SecureContext
    public static func create(global: JsGlobalObject, config: SSLConfig): SecureContext {
        let ctxOpts = config.asUSockets()
        return createWithDigest(global, ctxOpts, ctxOpts.digest())
    }

    /// 使用摘要创建
    public static func createWithDigest(global: JsGlobalObject, ctxOpts: BunSocketContextOptions, d: Array<UInt8>): SecureContext {
        var err: CreateBunSocketError = .none
        let ctx = global.bunVM().rareData().sslCtxCache().getOrCreateDigest(ctxOpts, d, &err) ?? {
            if (err == .none) {
                let code = BoringSSL.ERR_get_error()
                if (code != 0) {
                    global.throwValue(BoringSSL.ERR_toJS(global, code))
                    return SecureContext()
                }
                global.throw("Failed to create SSL context")
                return SecureContext()
            }
            global.throwValue(err.toJS(global))
            return SecureContext()
        }

        return SecureContext(
            ctx: ctx,
            digest: d,
            extraMemory: ctxOpts.approxCertBytes() + sslCtxBaseCost,
        )
    }

    // ========================================================================
    // intern - 缓存并返回
    // ========================================================================

    /// intern - tls.createSecureContext(opts) 入口
    /// 通过配置摘要进行 WeakGCMap 记忆化
    public static func intern(global: JsGlobalObject, callframe: JsCallFrame): JsValue {
        let args = callframe.arguments()
        let opts = args.len > 0 ? args[0] : JsValue.jsUndefined

        var config = try SSLConfig.fromJS(global.bunVM(), global, opts) ?? SSLConfig.zero
        defer config.deinit()

        let ctxOpts = config.asUSockets()
        let d = ctxOpts.digest()
        let key = d.readUInt64LE(0)

        // 检查缓存
        let cached = Bun__SecureContextCache__get(global, key)
        if (cached != JsValue.zero) {
            if (let existing = fromJS(cached)) {
                if (existing.digest.eqlLong(d)) {
                    return cached
                }
            }
        }

        // 创建新的
        let sc = try createWithDigest(global, ctxOpts, d)
        let jsValue = sc.toJS(global)

        // 缓存
        Bun__SecureContextCache__set(global, key, jsValue, d)

        return jsValue
    }

    // ========================================================================
    // finalize
    // ========================================================================

    /// finalize - GC 回收时调用
    public func finalize(): Unit {
        // SSL_CTX 的引用由 SSLContextCache 管理
    }

    @Extern
    public static func Bun__SecureContextCache__get(global: JsGlobalObject, key: UInt64): JsValue

    @Extern
    public static func Bun__SecureContextCache__set(global: JsGlobalObject, key: UInt64, value: JsValue, digest: Array<UInt8>): Unit

    public static let sslCtxBaseCost: Int = 50000
}
