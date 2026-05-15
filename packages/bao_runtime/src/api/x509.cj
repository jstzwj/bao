// 严格翻译自: src/runtime/api/bun/x509.zig
package bao_runtime

import bao_jsc.*
import bao_core.*

// ============================================================================
// x509 - X.509 证书的 JS 转换桥接
// 对应 Bun: src/runtime/api/bun/x509.zig
// ============================================================================

/// X509 证书的 JS 转换
public class X509Jsc {

    // ========================================================================
    // isSafeAltName - 检查替代名称是否安全
    // ========================================================================

    /// 检查替代名称是否可以安全地在 Subject Alternative Name 中使用
    /// 无需转义
    public static func isSafeAltName(name: String, utf8: Bool): Bool {
        for (c in name) {
            match (c) {
                case '"', '\\', ',', '\'' => return false
                default =>
                    if (utf8) {
                        if (c < ' ' || c == '\x7f') { return false }
                    } else {
                        if (c < ' ' || c > '~') { return false }
                    }
            }
        }
        return true
    }

    // ========================================================================
    // toJS - 转换为 JS 值
    // ========================================================================

    /// 将 X509 证书转换为 JS 值 (旧版编码)
    public static func toJS(cert: X509, globalObject: JsGlobalObject): JsValue {
        return fromJSHostCall(globalObject, Bun__X509__toJSLegacyEncoding, [cert, globalObject])
    }

    /// 将 X509 证书转换为 JS 对象
    public static func toJSObject(cert: X509, globalObject: JsGlobalObject): JsValue {
        return Bun__X509__toJS(cert, globalObject)
    }

    // ========================================================================
    // 外部函数声明
    // ========================================================================

    @Extern
    public static func Bun__X509__toJSLegacyEncoding(cert: X509, globalObject: JsGlobalObject): JsValue

    @Extern
    public static func Bun__X509__toJS(cert: X509, globalObject: JsGlobalObject): JsValue
}
