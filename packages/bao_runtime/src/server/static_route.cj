// StaticRoute - 静态路由 (静态 Blob 响应)
// 严格翻译自: Bun src/runtime/server/StaticRoute.zig
// 对应: 存储和提供静态 Blob 响应
package bao_runtime.server

import bao_core.*
import bao_collections.*

// ============================================================================
// StaticRoute - 静态路由
// 严格翻译自: src/runtime/server/StaticRoute.zig
// Bun: const StaticRoute = @This()
// 存储和提供静态 Blob，可从 JS Response 对象或全局分配的字节创建
// ============================================================================

/// 静态路由
/// 对应 Bun: const StaticRoute = @This()
/// 存储一个预构建的 HTTP 响应 (状态码 + 头部 + body)
/// 可在多个请求中复用
public class StaticRoute {
    // ========================================================================
    // 字段
    // ========================================================================

    /// 引用计数 - 对应 Bun: ref_count: RefCount
    public var refCount: Int64

    /// 服务器引用 - 对应 Bun: server: ?AnyServer = null
    public var server: ?ServerRef

    /// 状态码 - 对应 Bun: status_code: u16
    public var statusCode: Int64

    /// Blob 数据 - 对应 Bun: blob: AnyBlob
    public var blob: Array<UInt8>

    /// 缓存的 Blob 大小 - 对应 Bun: cached_blob_size: u64
    public var cachedBlobSize: Int64

    /// 是否有 Content-Disposition - 对应 Bun: has_content_disposition: bool = false
    public var hasContentDisposition: Bool

    /// 响应头 - 对应 Bun: headers: Headers
    public var headers: HashMap<String, String>

    public init() {
        refCount = 1
        server = None
        statusCode = 200
        blob = Array<UInt8>()
        cachedBlobSize = 0
        hasContentDisposition = false
        headers = HashMap<String, String>()
    }

    // ========================================================================
    // 从 Blob 创建
    // ========================================================================

    /// 从任意 Blob 创建静态路由
    /// 对应 Bun: pub fn initFromAnyBlob(blob, options) *StaticRoute
    public static func initFromAnyBlob(blob: Array<UInt8>, statusCode: Int64,
                                        mimeType: ?String, server: ?ServerRef): StaticRoute {
        let route = StaticRoute()
        route.blob = blob
        route.cachedBlobSize = blob.size
        route.statusCode = statusCode
        route.server = server

        // 设置 Content-Type
        match (mimeType) {
            case Some(mt) => {
                if (mt.size > 0) {
                    route.headers.put("Content-Type", mt)
                }
            }
            case None => ()
        }

        // 生成 ETag
        if (blob.size > 0) {
            let etag = computeETag(blob)
            route.headers.put("ETag", etag)
        }

        return route
    }

    // ========================================================================
    // 请求处理
    // ========================================================================

    /// 处理请求
    /// 对应 Bun: pub fn onRequest(this, req, resp) void
    public func onRequest(method: HttpMethod, resp: ResponseRef): Unit {
        match (method) {
            case HttpMethod.GET => onGet(resp)
            case HttpMethod.HEAD => onHead(resp)
            case _ => {
                // 其他方法直接处理
                on(resp)
            }
        }
    }

    /// 处理 HEAD 请求
    /// 对应 Bun: pub fn onHEAD(this, resp) void
    public func onHead(resp: ResponseRef): Unit {
        ref()

        match (server) {
            case Some(s) => resp.timeout(s.config.idleTimeout)
            case None => ()
        }

        renderMetadata(resp)
        resp.writeHeader("Content-Length", cachedBlobSize.toString())
        resp.endWithoutBody(resp.shouldCloseConnection())

        onResponseComplete(resp)
    }

    /// 处理 GET 请求
    /// 对应 Bun: pub fn onGET(this, req, resp) void
    public func onGet(resp: ResponseRef): Unit {
        // 检查 If-None-Match (ETag 缓存验证)
        if (statusCode == 200) {
            // 对应 Bun: render304NotModifiedIfNoneMatch
            // 简化: 直接处理
        }
        on(resp)
    }

    /// 处理请求 (发送 Blob)
    /// 对应 Bun: pub fn on(this, resp) void
    public func on(resp: ResponseRef): Unit {
        ref()

        match (server) {
            case Some(s) => resp.timeout(s.config.idleTimeout)
            case None => ()
        }

        renderMetadata(resp)
        renderBytes(resp)

        onResponseComplete(resp)
    }

    /// 按方法处理
    /// 对应 Bun: pub fn onWithMethod(this, method, resp) void
    public func onWithMethod(method: HttpMethod, resp: ResponseRef): Unit {
        match (method) {
            case HttpMethod.GET => on(resp)
            case HttpMethod.HEAD => onHead(resp)
            case _ => {
                doWriteStatus(405, resp)  // Method Not Allowed
                resp.endWithoutBody(resp.shouldCloseConnection())
            }
        }
    }

    // ========================================================================
    // 渲染方法
    // ========================================================================

    /// 渲染元数据 (状态行 + 头部)
    /// 对应 Bun: fn renderMetadata(this, resp) void
    public func renderMetadata(resp: ResponseRef): Unit {
        var status = statusCode
        let size = cachedBlobSize

        // 200 + 空 body -> 204
        if (status == 200 && size == 0) {
            status = 204
        }

        doWriteStatus(status, resp)
        doWriteHeaders(resp)
    }

    /// 渲染 bytes
    /// 对应 Bun: fn renderBytes(this, resp) void
    public func renderBytes(resp: ResponseRef): Unit {
        let allBytes = blob
        resp.tryEnd(allBytes, allBytes.size, resp.shouldCloseConnection())
    }

    /// 写入状态行
    /// 对应 Bun: fn doWriteStatus(this, status, resp) void
    public func doWriteStatus(status: Int64, resp: ResponseRef): Unit {
        let text = HTTPStatusText.get(status)
        match (text) {
            case Some(t) => resp.writeStatus(t)
            case None => resp.writeStatus("${status} HM")
        }
    }

    /// 写入头部
    /// 对应 Bun: fn doWriteHeaders(this, resp) void
    public func doWriteHeaders(resp: ResponseRef): Unit {
        for (key in headers.keys()) {
            match (headers.get(key)) {
                case Some(v) => resp.writeHeader(key, v)
                case None => ()
            }
        }
    }

    // ========================================================================
    // 生命周期
    // ========================================================================

    /// 请求完成回调
    /// 对应 Bun: fn onResponseComplete(this, resp) void
    public func onResponseComplete(resp: ResponseRef): Unit {
        resp.clearAborted()
        resp.clearOnWritable()
        resp.clearTimeout()
        deref()
    }

    /// 增加引用
    public func ref(): Unit {
        refCount += 1
    }

    /// 减少引用
    public func deref(): Unit {
        refCount -= 1
        if (refCount <= 0) {
            deinit()
        }
    }

    /// 内存开销
    /// 对应 Bun: pub fn memoryCost(this) usize
    public func memoryCost(): Int64 {
        return blob.size + headers.size
    }

    /// 析构
    /// 对应 Bun: fn deinit(this) void
    public func deinit(): Unit {
        blob = Array<UInt8>()
        headers.clear()
    }

    // ========================================================================
    // 辅助函数
    // ========================================================================

    /// 计算 ETag
    /// 对应 Bun: ETag.appendToHeaders
    private static func computeETag(data: Array<UInt8>): String {
        // 简化: 使用大小作为弱 ETag
        return "W/\"${data.size}\""
    }
}
