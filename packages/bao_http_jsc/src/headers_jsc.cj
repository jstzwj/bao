// 严格翻译自: src/http_jsc/headers_jsc.zig
//! JSC bridges for `bun.http.{Headers,H2Client,H3Client}`. Keeps `src/http/` free of JSC types.
package bao_http_jsc

import bao_jsc.*
import bao_core.*

// ============================================================================
// HeadersJSC - Headers 的 JSC 桥接
// 严格翻译自: src/http_jsc/headers_jsc.zig:4-16
//   pub fn toFetchHeaders(this: *Headers, global) bun.JSError!*FetchHeaders
// ============================================================================

/// 将 Headers 转换为 FetchHeaders - 严格对应 Bun toFetchHeaders
/// Zig: pub fn toFetchHeaders(this: *Headers, global: *bun.jsc.JSGlobalObject) bun.JSError!*FetchHeaders
public func headersToFetchHeaders(`this`: Headers, global: JSGlobalObject): FetchHeaders {
    if (this.entries.size == 0) {
        return FetchHeaders.createEmpty()
    }
    let headers = FetchHeaders.create(
        global,
        this.entries.items.name.ptr,
        this.entries.items.value.ptr,
        ZigString.fromBytes(this.buf.items),
        UInt32(this.entries.size)
    )
    return headers
}

// ============================================================================
// H2TestingAPIs - H2 测试 API
// 严格翻译自: src/http_jsc/headers_jsc.zig:18-26
// ============================================================================

/// H2 测试 API - 严格对应 Bun H2TestingAPIs
public class H2TestingAPIs {
    /// 获取实时计数 - 严格对应 Bun liveCounts
    /// Zig: pub fn liveCounts(globalThis, _) bun.JSError!jsc.JSValue
    public static func liveCounts(globalThis: JSGlobalObject, _: CallFrame): JSValue {
        let obj = JSValue.createEmptyObject(globalThis, 2)
        obj.put(globalThis, ZigString.static("sessions"), JSValue.jsNumber(H2Client.liveSessions.load(.monotonic)))
        obj.put(globalThis, ZigString.static("streams"), JSValue.jsNumber(H2Client.liveStreams.load(.monotonic)))
        return obj
    }
}

// ============================================================================
// H3TestingAPIs - H3 测试 API
// 严格翻译自: src/http_jsc/headers_jsc.zig:27-37
// ============================================================================

/// H3 测试 API - 严格对应 Bun H3TestingAPIs
public class H3TestingAPIs {
    /// 获取 QUIC 实时计数 - 严格对应 Bun quicLiveCounts
    /// Zig: pub fn quicLiveCounts(globalThis, _) bun.JSError!jsc.JSValue
    public static func quicLiveCounts(globalThis: JSGlobalObject, _: CallFrame): JSValue {
        let obj = JSValue.createEmptyObject(globalThis, 2)
        obj.put(globalThis, ZigString.static("sessions"), JSValue.jsNumber(H3Client.liveSessions.load(.monotonic)))
        obj.put(globalThis, ZigString.static("streams"), JSValue.jsNumber(H3Client.liveStreams.load(.monotonic)))
        return obj
    }
}
