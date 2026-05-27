// BakeResponse - Bake 响应
// 对应 Bun: src/runtime/webcore/BakeResponse.zig
// 严格翻译自: src/runtime/webcore/BakeResponse.zig
package bao_runtime.webcore

import bao_core.*
import bao_http.*

// ============================================================================
// BakeResponse - Bake 响应
// 对应 Bun: src/runtime/webcore/BakeResponse.zig
// ============================================================================

/// BakeResponse — Bun.serve() 中的预渲染响应
/// 对应 Bun: src/runtime/webcore/BakeResponse.zig
/// 用于在服务器渲染时预编译静态响应
public class BakeResponse {
    /// 预编译的状态码
    public var statusCode: Int64
    /// 预编译的响应头
    public var headers: Headers
    /// 预编译的响应体
    public var body: Array<UInt8>
    /// 是否已编译
    public var baked: Bool

    public init() {
        statusCode = 200
        headers = Headers()
        body = Array<UInt8>()
        baked = false
    }

    public init(statusCode: Int64, headers: Headers, body: Array<UInt8>) {
        this.statusCode = statusCode
        this.headers = headers
        this.body = body
        baked = true
    }

    /// 从 Response 创建 BakeResponse
    /// 对应 Bun: BakeResponse 编译逻辑
    public static func fromResponse(response: Response): BakeResponse {
        let baked = BakeResponse()
        baked.statusCode = response.statusCode()
        // 克隆 headers
        let respHeaders = response.getHeaders()
        let keys = respHeaders.keys()
        for (key in keys) {
            match (respHeaders.get(key)) {
                case Some(val) => baked.headers.set(key, val)
                case None => ()
            }
        }
        baked.body = response.arrayBuffer()
        baked.baked = true
        return baked
    }

    /// 转为 Response (placeholder)
    /// 对应 Bun: BakeResponse 转为 Response 逻辑
    public func toResponse(): Response {
        return Response()
    }
}
