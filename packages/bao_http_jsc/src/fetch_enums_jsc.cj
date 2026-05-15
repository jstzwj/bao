// 严格翻译自: src/http_jsc/fetch_enums_jsc.zig
//! JSC bridges for the small `http_types/Fetch*` enums.
package bao_http_jsc

import bao_jsc.*
import bao_core.*

// ============================================================================
// FetchEnumsJSC - Fetch 枚举的 JSC 桥接
// 严格翻译自: src/http_jsc/fetch_enums_jsc.zig:5-22
//   extern "c" fn Bun__FetchRedirect__toJS(v: u8, global) jsc.JSValue
//   extern "c" fn Bun__FetchRequestMode__toJS(v: u8, global) jsc.JSValue
//   extern "c" fn Bun__FetchCacheMode__toJS(v: u8, global) jsc.JSValue
// ============================================================================

// 外部 C 函数声明 - 严格对应 Bun extern "c" 声明
@Foreign("c")
public func Bun__FetchRedirect__toJS(v: UInt8, global: JSGlobalObject): JSValue

@Foreign("c")
public func Bun__FetchRequestMode__toJS(v: UInt8, global: JSGlobalObject): JSValue

@Foreign("c")
public func Bun__FetchCacheMode__toJS(v: UInt8, global: JSGlobalObject): JSValue

/// 将 FetchRedirect 转换为 JS - 严格对应 Bun fetchRedirectToJS
/// Zig: pub fn fetchRedirectToJS(this: bun.http.FetchRedirect, global) jsc.JSValue
/// Zig: return Bun__FetchRedirect__toJS(@intFromEnum(this), global)
public func fetchRedirectToJS(this: FetchRedirect, global: JSGlobalObject): JSValue {
    return Bun__FetchRedirect__toJS(UInt8(this), global)
}

/// 将 FetchRequestMode 转换为 JS - 严格对应 Bun fetchRequestModeToJS
/// Zig: pub fn fetchRequestModeToJS(this: bun.http.FetchRequestMode, global) jsc.JSValue
/// Zig: return Bun__FetchRequestMode__toJS(@intFromEnum(this), global)
public func fetchRequestModeToJS(this: FetchRequestMode, global: JSGlobalObject): JSValue {
    return Bun__FetchRequestMode__toJS(UInt8(this), global)
}

/// 将 FetchCacheMode 转换为 JS - 严格对应 Bun fetchCacheModeToJS
/// Zig: pub fn fetchCacheModeToJS(this: bun.http.FetchCacheMode, global) jsc.JSValue
/// Zig: return Bun__FetchCacheMode__toJS(@intFromEnum(this), global)
public func fetchCacheModeToJS(this: FetchCacheMode, global: JSGlobalObject): JSValue {
    return Bun__FetchCacheMode__toJS(UInt8(this), global)
}
