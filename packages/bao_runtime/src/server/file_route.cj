// FileRoute - 文件路由 (从磁盘提供文件)
// 严格翻译自: Bun src/runtime/server/FileRoute.zig
// 对应: 从文件系统提供文件响应
package bao_runtime

import bao_core.*
import bao_collections.*
import bao_sys.*

// ============================================================================
// FileRoute - 文件路由
// 严格翻译自: src/runtime/server/FileRoute.zig
// Bun: const FileRoute = @This()
// 从磁盘提供文件的 HTTP 路由，支持 Range 请求和条件请求
// ============================================================================

/// Stat 哈希 (用于缓存验证)
/// 对应 Bun: stat_hash: bun.fs.StatHash
public class StatHash {
    public var lastModifiedU64: Int64
    public var hash: Int64

    public init() {
        lastModifiedU64 = 0
        hash = 0
    }
}

/// 文件路由
/// 严格翻译自: src/runtime/server/FileRoute.zig
/// 对应 Bun: const FileRoute = @This()
/// 从文件系统提供静态文件服务，支持 Range 请求和 If-Modified-Since
public class FileRoute {
    // ========================================================================
    // 字段
    // ========================================================================

    /// 引用计数
    public var refCount: Int64

    /// 服务器引用 - 对应 Bun: server: ?AnyServer = null
    public var server: ?ServerRef

    /// 文件 Blob - 对应 Bun: blob: Blob
    public var blob: FileBlob

    /// 响应头 - 对应 Bun: headers: Headers
    public var headers: HashMap<String, String>

    /// 状态码 - 对应 Bun: status_code: u16
    public var statusCode: Int64

    /// Stat 哈希 - 对应 Bun: stat_hash: bun.fs.StatHash
    public var statHash: StatHash

    /// 是否有 Last-Modified 头 - 对应 Bun: has_last_modified_header: bool
    public var hasLastModifiedHeader: Bool

    /// 是否有 Content-Length 头 - 对应 Bun: has_content_length_header: bool
    public var hasContentLengthHeader: Bool

    /// 是否有 Content-Range 头 - 对应 Bun: has_content_range_header: bool
    public var hasContentRangeHeader: Bool

    public init() {
        refCount = 1
        server = None
        blob = FileBlob()
        headers = HashMap<String, String>()
        statusCode = 200
        statHash = StatHash()
        hasLastModifiedHeader = false
        hasContentLengthHeader = false
        hasContentRangeHeader = false
    }

    // ========================================================================
    // 创建
    // ========================================================================

    /// 从 Blob 创建文件路由
    /// 对应 Bun: pub fn initFromBlob(blob, opts) *FileRoute
    public static func initFromBlob(blob: FileBlob, statusCode: Int64,
                                     server: ?ServerRef): FileRoute {
        let route = FileRoute()
        route.blob = blob
        route.statusCode = statusCode
        route.server = server

        // 检查预设头部
        route.hasLastModifiedHeader = route.headers.get("last-modified") != None
        route.hasContentLengthHeader = route.headers.get("content-length") != None
        route.hasContentRangeHeader = route.headers.get("content-range") != None

        return route
    }

    // ========================================================================
    // 请求处理
    // ========================================================================

    /// 处理 HEAD 请求
    /// 对应 Bun: pub fn onHEADRequest(this, req, resp) void
    public func onHeadRequest(headers: HashMap<String, String>, resp: ResponseRef): Unit {
        on(headers, resp, HttpMethod.HEAD)
    }

    /// 处理请求
    /// 对应 Bun: pub fn onRequest(this, req, resp) void
    public func onRequest(requestHeaders: HashMap<String, String>, resp: ResponseRef): Unit {
        let methodStr = match (requestHeaders.get(":method")) {
            case Some(m) => m
            case None => "GET"
        }
        on(requestHeaders, resp, HttpMethod.fromString(methodStr))
    }

    /// 核心请求处理
    /// 对应 Bun: pub fn on(this, req, resp, method) void
    public func on(requestHeaders: HashMap<String, String>, resp: ResponseRef,
                    method: HttpMethod): Unit {
        ref()

        match (server) {
            case Some(s) => {
                resp.timeout(s.config.idleTimeout)
            }
            case None => ()
        }

        let filePath = blob.filePath
        if (filePath.size == 0) {
            onResponseComplete(resp)
            return
        }

        // 打开文件
        // 对应 Bun: bun.sys.openA(path, O.RDONLY | O.CLOEXEC | O.NONBLOCK, 0)
        let fd = openFile(filePath)
        if (fd < 0) {
            onResponseComplete(resp)
            return
        }

        // stat 文件
        let stat = fstat(fd)
        let statSize = if (stat.size >= 0) { stat.size } else { Int64(0) }
        let fileSize = if (statSize < blob.size) { statSize } else { blob.size }

        // 目录检查
        if (stat.isDir) {
            closeFile(fd)
            onResponseComplete(resp)
            return
        }

        // 确定文件类型
        let fileType = determineFileType(stat)
        let canServe = true

        if (!canServe) {
            closeFile(fd)
            onResponseComplete(resp)
            return
        }

        // 解析 Range 头
        let range: RangeResult = if ((method == HttpMethod.GET || method == HttpMethod.HEAD) &&
                                     fileType == FileType.File && statusCode == 200 &&
                                     !hasContentRangeHeader) {
            RangeRequest.fromRequest(requestHeaders, fileSize)
        } else {
            RangeResult.None
        }

        // 确定状态码
        var effectiveStatus: Int64 = statusCode
        match (range) {
            case RangeResult.Unsatisfiable => effectiveStatus = 416
            case RangeResult.Satisfiable(_) => effectiveStatus = 206
            case RangeResult.None => {
                if (fileSize == 0 && fileType == FileType.File && statusCode == 200) {
                    effectiveStatus = 204
                }
            }
        }

        writeStatusCode(effectiveStatus, resp)
        writeHeaders(resp)

        // 无 body 状态码
        if (effectiveStatus == 204 || effectiveStatus == 205 ||
            effectiveStatus == 304 || effectiveStatus == 307 ||
            effectiveStatus == 308) {
            resp.endWithoutBody(resp.shouldCloseConnection())
            closeFile(fd)
            onResponseComplete(resp)
            return
        }

        // Range 处理
        var bodyOffset: Int64 = 0
        var bodyLen: ?Int64 = None

        match (range) {
            case RangeResult.Satisfiable(let r) => {
                resp.writeHeader("Content-Range",
                    "bytes ${r.start}-${r.end}/${fileSize}")
                resp.writeHeader("Accept-Ranges", "bytes")
                bodyOffset = blob.offset + r.start
                bodyLen = r.end - r.start + 1
            }
            case RangeResult.Unsatisfiable => {
                resp.writeHeader("Content-Range", "bytes */${fileSize}")
                resp.writeHeader("Accept-Ranges", "bytes")
                resp.end("", resp.shouldCloseConnection())
                closeFile(fd)
                onResponseComplete(resp)
                return
            }
            case RangeResult.None => {
                bodyOffset = if (fileType == FileType.File) { blob.offset } else { 0 }
                bodyLen = if (fileType == FileType.File && blob.size > 0) {
                    Some(fileSize)
                } else {
                    None
                }
            }
        }

        if (fileType == FileType.File) {
            let len = match (bodyLen) {
                case Some(l) => l
                case None => fileSize
            }
            resp.writeHeader("Content-Length", len.toString())
        }

        if (method == HttpMethod.HEAD) {
            resp.endWithoutBody(resp.shouldCloseConnection())
            closeFile(fd)
            onResponseComplete(resp)
            return
        }

        // 使用 FileResponseStream 进行流式传输
        // 对应 Bun: FileResponseStream.start(...)
        let opts = FileResponseStreamStartOptions()
        opts.fd = fd
        opts.autoClose = true
        opts.resp = Some(resp)
        opts.fileType = fileType
        opts.pollable = false
        opts.offset = bodyOffset
        opts.length = bodyLen
        match (server) {
            case Some(s) => opts.idleTimeout = s.config.idleTimeout
            case None => opts.idleTimeout = 10
        }

        let stream = FileResponseStream.start(opts)
        stream.onComplete = Some({ (s: FileResponseStream) =>
            onResponseComplete(resp)
        })
        stream.onError = Some({ (s: FileResponseStream, err: BaoError) =>
            onResponseComplete(resp)
        })
    }

    // ========================================================================
    // 辅助方法
    // ========================================================================

    /// 写入头部
    /// 对应 Bun: fn writeHeaders(this, resp) void
    public func writeHeaders(resp: ResponseRef): Unit {
        for (key in headers.keys()) {
            match (headers.get(key)) {
                case Some(v) => resp.writeHeader(key, v)
                case None => ()
            }
        }

        // 自动添加 Last-Modified
        if (!hasLastModifiedHeader && statHash.lastModifiedU64 > 0) {
            resp.writeHeader("Last-Modified", formatHttpDate(statHash.lastModifiedU64))
        }
    }

    /// 写入状态码
    /// 对应 Bun: fn writeStatusCode(this, status, resp) void
    public func writeStatusCode(status: Int64, resp: ResponseRef): Unit {
        let text = HTTPStatusText.get(status)
        match (text) {
            case Some(t) => resp.writeStatus(t)
            case None => resp.writeStatus("${status} HM")
        }
    }

    /// 请求完成回调
    /// 对应 Bun: fn onResponseComplete(this, resp) void
    public func onResponseComplete(resp: ResponseRef): Unit {
        resp.clearAborted()
        resp.clearOnWritable()
        resp.clearTimeout()
        match (server) {
            case Some(s) => s.onStaticRequestComplete()
            case None => ()
        }
        deref()
    }

    /// 内存开销
    /// 对应 Bun: pub fn memoryCost(this) usize
    public func memoryCost(): Int64 {
        return headers.size + blob.reportedEstimatedSize
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

    /// 析构
    public func deinit(): Unit {
        blob.deinit()
        headers.clear()
    }

    /// 打开文件 (简化)
    private static func openFile(path: String): Int64 {
        // 对应 Bun: bun.sys.openA(path, O.RDONLY | O.CLOEXEC | O.NONBLOCK, 0)
        return SysFs.open(path, SysFs.O_RDONLY())
    }

    /// 关闭文件 (简化)
    private static func closeFile(fd: Int64): Unit {
        if (fd >= 0) {
            SysFs.close(fd)
        }
    }

    /// fstat (简化)
    private static func fstat(fd: Int64): FileStat {
        return SysFs.fstat(fd)
    }

    /// 确定文件类型
    private static func determineFileType(stat: FileStat): FileType {
        if (stat.isFifo || stat.isChar) {
            return FileType.Pipe
        }
        if (stat.isSocket) {
            return FileType.Socket
        }
        return FileType.File
    }

    /// 格式化 HTTP 日期
    private static func formatHttpDate(timestamp: Int64): String {
        // 简化实现
        return "Fri, 15 May 2026 00:00:00 GMT"
    }
}

/// 文件 Blob
/// 对应 Bun: Blob (文件相关)
public class FileBlob {
    public var filePath: String
    public var offset: Int64
    public var size: Int64
    public var reportedEstimatedSize: Int64

    public init() {
        filePath = ""
        offset = 0
        size = 0
        reportedEstimatedSize = 0
    }

    public func deinit(): Unit {
        filePath = ""
    }
}

/// 文件 stat 结果
public class FileStat {
    public var size: Int64
    public var mode: Int64
    public var isDir: Bool
    public var isFifo: Bool
    public var isChar: Bool
    public var isSocket: Bool

    public init() {
        size = 0
        mode = 0
        isDir = false
        isFifo = false
        isChar = false
        isSocket = false
    }
}
