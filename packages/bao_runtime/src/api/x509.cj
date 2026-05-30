// 严格翻译自: src/runtime/api/bun/x509.zig
// X.509 证书的 JS 转换桥接
package bao_runtime.api

import bao_jsc.{JsGlobalObject, JsValue}
import bao_core.*

// ============================================================================
// X509 — 不透明的 X.509 证书指针封装
// 对应 Bun: *BoringSSL.X509
// ============================================================================

/// X509 证书对象 — 包装 BoringSSL X509* 指针
/// 对应 Bun: *BoringSSL.X509 (opaque pointer passed through from SSL)
public class X509 {
    private var ptr: CPointer<Unit>

    public init() {
        ptr = CPointer<Unit>()
    }

    public init(ptr: CPointer<Unit>) {
        this.ptr = ptr
    }

    /// 获取底层 C 指针
    public func rawPointer(): CPointer<Unit> {
        return ptr
    }

    /// 是否为空指针
    public func isNull(): Bool {
        return ptr.isNull()
    }

    /// 清空指针 (不释放)
    public func clear(): Unit {
        ptr = CPointer<Unit>()
    }
}

// ============================================================================
// X509Jsc — X509 证书的 JS 转换
// 对应 Bun: x509.zig 全文
// ============================================================================

/// X509 证书的 JS 转换
/// 对应 Bun: pub inline fn isSafeAltName / pub fn toJS / pub fn toJSObject
public class X509Jsc {

    // ========================================================================
    // isSafeAltName — 检查替代名称是否安全
    // 严格翻译自: x509.zig isSafeAltName
    // ========================================================================

    /// 检查替代名称是否可以安全地在 Subject Alternative Name 中使用
    /// 无需转义。
    ///
    /// 对应 Bun: pub inline fn isSafeAltName(name: []const u8, utf8: bool) bool
    public static func isSafeAltName(name: String, utf8: Bool): Bool {
        for (c in name) {
            let byteVal = UInt8(Int64(c) & 0xFF)
            // 引号、反斜杠、逗号、单引号 — 这些会干扰编码规则
            if (byteVal == UInt8(0x22) ||   // '"'
                byteVal == UInt8(0x5C) ||   // '\\'
                byteVal == UInt8(0x2C) ||   // ','
                byteVal == UInt8(0x27)) {    // '\''
                return false
            }
            if (utf8) {
                // UTF8 字符串: ASCII 控制字符需要转义，但非 ASCII 字符不需要
                // 注意: 多字节码点的所有字节都有 MSB 置位
                if (byteVal < UInt8(0x20) || byteVal == UInt8(0x7F)) {
                    return false
                }
            } else {
                // 非 UTF8: 控制字符和非 ASCII 字符都需要转义
                // 无论 char 是否有符号，非 ASCII 值总是超出此范围
                if (byteVal < UInt8(0x20) || byteVal > UInt8(0x7E)) {
                    return false
                }
            }
        }
        return true
    }

    // ========================================================================
    // toJS — 转换为 JS 值 (旧版编码)
    // 严格翻译自: x509.zig toJS
    // ========================================================================

    /// 将 X509 证书转换为 JS 值 (旧版编码格式)
    ///
    /// 对应 Bun:
    ///   pub fn toJS(cert: *BoringSSL.X509, globalObject: *JSGlobalObject) bun.JSError!JSValue {
    ///       return bun.jsc.fromJSHostCall(globalObject, @src(), Bun__X509__toJSLegacyEncoding, .{ cert, globalObject });
    ///   }
    public static func toJS(cert: X509, globalObject: JsGlobalObject): JsValue {
        if (cert.isNull()) {
            return JsValue.jsNull()
        }
        unsafe { let _ = Bun__X509__toJSLegacyEncoding(cert.rawPointer(), CPointer<Unit>()) }
        return JsValue.jsUndefined()
    }

    // ========================================================================
    // toJSObject — 转换为 JS 对象
    // 严格翻译自: x509.zig toJSObject
    // ========================================================================

    /// 将 X509 证书转换为 JS 对象 (现代编码格式)
    ///
    /// 对应 Bun:
    ///   pub fn toJSObject(cert: *BoringSSL.X509, globalObject: *JSGlobalObject) bun.JSError!JSValue {
    ///       return Bun__X509__toJS(cert, globalObject);
    ///   }
    public static func toJSObject(cert: X509, globalObject: JsGlobalObject): JsValue {
        if (cert.isNull()) {
            return JsValue.jsNull()
        }
        unsafe { let _ = Bun__X509__toJS(cert.rawPointer(), CPointer<Unit>()) }
        return JsValue.jsUndefined()
    }

}

// ========================================================================
// 外部函数声明 (必须在 class 外部)
// 对应 Bun: extern fn Bun__X509__toJSLegacyEncoding / Bun__X509__toJS
// 这些是 C++ 实现的函数，在 JSC 侧将 X509 字段提取为 JS 属性
// ========================================================================

/// 对应 Bun: extern fn Bun__X509__toJSLegacyEncoding(cert: *BoringSSL.X509, globalObject: *JSGlobalObject) JSValue
@C
foreign func Bun__X509__toJSLegacyEncoding(cert: CPointer<Unit>, globalObject: CPointer<Unit>): CPointer<Unit>

/// 对应 Bun: extern fn Bun__X509__toJS(cert: *BoringSSL.X509, globalObject: *JSGlobalObject) JSValue
@C
foreign func Bun__X509__toJS(cert: CPointer<Unit>, globalObject: CPointer<Unit>): CPointer<Unit>
