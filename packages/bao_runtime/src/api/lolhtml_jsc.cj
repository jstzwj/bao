// 严格翻译自: src/runtime/api/lolhtml_jsc.zig
package bao_runtime.api

import bao_jsc.*
import bao_core.*

// ============================================================================
// lolhtml_jsc - LOLHTML HTMLString 的 JSC 桥接
// 对应 Bun: src/runtime/api/lolhtml_jsc.zig
// ============================================================================

/// LOLHTML HTMLString 的 JS 转换桥接
/// 保持 src/lolhtml_sys/ 不包含 JSC 类型
public class LolhtmlJsc {

    /// 将 HTMLString 转换为 JS 值
    public static func htmlStringToJS(htmlString: HTMLString, globalThis: JsGlobalObject): JsValue {
        var str = htmlString.toString()
        defer str.deref()
        return try str.toJS(globalThis)
    }
}
