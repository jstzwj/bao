// 严格翻译自: src/runtime/api/SecureContext.classes.ts
// SecureContext JSC class binding definitions
package bao_runtime.api

import bao_jsc.*
import bao_sys.{SysMaybe, SysError, SysTag}

// ============================================================================
// SecureContext.classes.ts 类绑定定义
// Bun: SecureContext 的 JSC 绑定
// construct: true, finalize: true, memoryCost: true, configurable: false
// klass: { intern: { fn: "intern", length: 1 } }
// proto: {} (空 — node:tls 使用 .context 对象本身)
// ============================================================================

/// SecureContext JSC 绑定
/// Bun: node:tls SecureContext 原生实现
/// 不暴露 SSL_CTX* 到 JS (类似 V8 External 的不透明对象)
public class SecureContextClasses {

    /// intern (static klass method)
    /// 严格翻译自: klass.intern { fn: "intern", length: 1 }
    /// tls.createSecureContext() 入口 — 通过配置摘要 WeakGCMap 缓存
    ///
    /// 对应 Bun: SecureContext.intern(global, callframe) -> JSValue
    public static func intern(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        return SecureContext.intern(jsGlobalObject, callframe)
    }

    /// constructor (instance constructor)
    /// 严格翻译自: SecureContext.constructor(global, callframe) -> *SecureContext
    ///
    /// 对应 Bun: SecureContext.constructor(global, callframe) -> *SecureContext
    public static func constructor(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): SysMaybe<SecureContext> {
        let opts = if (callframe.argumentsCount() > 0) {
            callframe.argument(0)
        } else {
            JsValue.jsUndefined()
        }

        let config = SecureContext.parseSslConfigStatic(jsGlobalObject, opts)
        match (config) {
            case Some(parsed) =>
                let sc = SecureContext.create(
                    jsGlobalObject,
                    parsed.keyFileName,
                    parsed.certFileName,
                    parsed.caFileName,
                    parsed.dhParamsFileName,
                    parsed.passphrase,
                    parsed.lowMemory
                )
                match (sc) {
                    case Some(ctx) => SysMaybe<SecureContext>.Ok(ctx)
                    case None => SysMaybe<SecureContext>.Err(SysError(UInt16(0), SysTag.TODO))
                }
            case None =>
                SysMaybe<SecureContext>.Ok(SecureContext())
        }
    }

    /// jsLiveCount (static method for testing)
    /// 对应 Bun: SecureContext.jsLiveCount(global, callframe) -> JSValue
    public static func jsLiveCount(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        return SecureContext.jsLiveCount(jsGlobalObject, callframe)
    }
}
