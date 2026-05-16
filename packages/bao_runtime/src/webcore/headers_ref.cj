// headers_ref - Body Content-Type 辅助提取
// 严格翻译自: src/runtime/webcore/headers_ref.rs
//   Bun 的 headers_ref 模块:
//   - any_blob_content_type: 从 AnyBlob 中提取用户设置的 content-type
//   - blob_content_type: 从 Blob 中提取用户设置的 content-type
//   - any_blob_content_type_opt: 可选 AnyBlob 的 content-type 提取
//   仓颉: 提供兼容的 Content-Type 提取接口
package bao_runtime.webcore

import bao_core.*

// ============================================================================
// headers_ref - Body Content-Type 辅助函数
// 严格翻译自: src/runtime/webcore/headers_ref.rs
//   Helpers for extracting the body content-type byte slice that
//   `headers_jsc::from_fetch_headers` consumes. Shared by
//   `webcore::fetch`, `server::StaticRoute`, `server::FileRoute`, and
//   `bake::DevServer`.
// ============================================================================

/// `Some(ct)` only when the body has a *user-set* content-type.
/// 对应 Bun: pub fn any_blob_content_type(b: &AnyBlob) -> Option<&[u8]>
public func anyBlobContentType(b: AnyBlob): ?Array<UInt8> {
    if (b.hasContentTypeFromUser()) {
        return b.contentType()
    }
    return None
}

/// `Some(ct)` only when the body has a *user-set* content-type.
/// 对应 Bun: pub fn blob_content_type(b: &Blob) -> Option<&[u8]>
public func blobContentType(b: Blob): ?Array<UInt8> {
    if (b.hasContentTypeFromUser()) {
        return b.contentTypeSlice()
    }
    return None
}

/// `Some(ct)` only when the body has a *user-set* content-type.
/// 对应 Bun: pub fn any_blob_content_type_opt(b: Option<&AnyBlob>) -> Option<&[u8]>
public func anyBlobContentTypeOpt(b: ?AnyBlob): ?Array<UInt8> {
    match (b) {
        case Some(blob) => anyBlobContentType(blob)
        case None => None
    }
}
