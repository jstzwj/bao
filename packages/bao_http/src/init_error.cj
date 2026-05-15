// bao_http InitError - HTTP 初始化错误
// 严格翻译自: src/http/InitError.zig
package bao_http

import bao_core.*

// ============================================================================
// InitError - HTTP 客户端初始化错误
// 严格翻译自: bun/src/http/InitError.zig
//
// Bun:
//   pub const InitError = error{
//       FailedToOpenSocket,
//       LoadCAFile,
//       InvalidCAFile,
//       InvalidCA,
//   };
//
// 这些错误在 HTTP 线程初始化时可能发生:
//   FailedToOpenSocket — 创建 socket 失败
//   LoadCAFile — 加载 CA 证书文件失败
//   InvalidCAFile — CA 证书文件格式无效
//   InvalidCA — CA 证书内容无效
// ============================================================================

/// HTTP 初始化错误类型
/// 严格翻译自: InitError error enum
public enum InitError {
    | failedToOpenSocket    // 创建 socket 失败
    | loadCAFile            // 加载 CA 证书文件失败
    | invalidCAFile         // CA 证书文件格式无效
    | invalidCA             // CA 证书内容无效

    /// 获取错误描述
    public func toString(): String {
        match (this) {
            case failedToOpenSocket => "FailedToOpenSocket"
            case loadCAFile => "LoadCAFile"
            case invalidCAFile => "InvalidCAFile"
            case invalidCA => "InvalidCA"
        }
    }

    /// 获取详细错误信息
    public func message(): String {
        match (this) {
            case failedToOpenSocket => "Failed to open socket for HTTP client"
            case loadCAFile => "Failed to load CA certificate file"
            case invalidCAFile => "CA certificate file format is invalid"
            case invalidCA => "CA certificate content is invalid"
        }
    }
}
