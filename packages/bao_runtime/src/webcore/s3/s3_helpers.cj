// S3 Helpers - S3 辅助工具
// 对应 Bun: src/runtime/webcore/s3/credentials_jsc.zig, download_stream.zig,
//           error_jsc.zig, list_objects.zig, multipart_options.zig, simple_request.zig
// 严格翻译自: src/runtime/webcore/s3/*.zig
package bao_runtime.webcore.s3

import bao_core.*
import bao_collections.*

// ============================================================================
// S3Error - S3 错误
// 对应 Bun: s3/error.zig, s3/error_jsc.zig
// ============================================================================

/// S3 错误
/// 对应 Bun: S3 错误类型
public class S3Error {
    /// 错误码
    public var code: String
    /// 错误消息
    public var message: String
    /// 资源
    public var resource: String
    /// 请求 ID
    public var requestId: String

    public init(code: String, message: String) {
        this.code = code
        this.message = message
        resource = ""
        requestId = ""
    }

    /// 转为 JsValue
    public func toJsValue(): JsValue {
        let obj = JsObject()
        obj.set("code", JsValue(BaoString(code)))
        obj.set("message", JsValue(BaoString(message)))
        obj.set("name", JsValue(BaoString("S3Error")))
        return JsValue(obj)
    }

    /// 抛出签名错误
    /// 对应 Bun: throwSignError
    public static func throwSignError(err: String): JsValue {
        let error = S3Error("SigningError", err)
        return error.toJsValue()
    }
}

// ============================================================================
// S3ListObjectsOptions - 列出对象选项
// 对应 Bun: s3/list_objects.zig S3ListObjectsOptions
// ============================================================================

/// S3 列出对象选项
/// 对应 Bun: S3ListObjectsOptions
public class S3ListObjectsOptions {
    /// 前缀
    public var prefix: String
    /// 分隔符
    public var delimiter: String
    /// 最大数量
    public var maxKeys: Int64
    /// 续 token
    public var continuationToken: String
    /// 起始 key
    public var startAfter: String

    public init() {
        prefix = ""
        delimiter = "/"
        maxKeys = 1000
        continuationToken = ""
        startAfter = ""
    }
}

// ============================================================================
// S3ListObjectsResult - 列出对象结果
// 对应 Bun: S3ListObjectsResult
// ============================================================================

/// S3 列出对象结果
/// 对应 Bun: S3ListObjectsResult
public class S3ListObjectsResult {
    /// 对象列表
    public var objects: ArrayList<S3ObjectInfo>
    /// 公共前缀列表
    public var commonPrefixes: ArrayList<String>
    /// 是否截断
    public var isTruncated: Bool
    /// 续 token
    public var nextContinuationToken: String

    public init() {
        objects = ArrayList<S3ObjectInfo>()
        commonPrefixes = ArrayList<String>()
        isTruncated = false
        nextContinuationToken = ""
    }
}

/// S3 对象信息
/// 对应 Bun: list_objects 中的对象信息
public class S3ObjectInfo {
    /// 对象 key
    public var key: String
    /// 大小
    public var size: Int64
    /// 最后修改时间
    public var lastModified: String
    /// ETag
    public var etag: String
    /// 存储类型
    public var storageClass: String

    public init(key: String) {
        this.key = key
        size = 0
        lastModified = ""
        etag = ""
        storageClass = "STANDARD"
    }
}

// ============================================================================
// S3HttpDownloadStreamingTask - S3 下载流任务
// 对应 Bun: s3/download_stream.zig
// ============================================================================

/// S3 下载流任务
/// 对应 Bun: s3/download_stream.zig S3HttpDownloadStreamingTask
public class S3HttpDownloadStreamingTask {
    /// S3 路径
    public var path: String
    /// 凭证
    public var credentials: S3Credentials
    /// 目标流
    public var targetStream: ?ByteStream
    /// 是否完成
    public var done: Bool
    /// 已下载字节
    public var downloadedBytes: Int64
    /// 总大小
    public var totalSize: Int64

    public init(credentials: S3Credentials, path: String) {
        this.path = path
        this.credentials = credentials
        targetStream = None
        done = false
        downloadedBytes = 0
        totalSize = 0
    }

    /// 启动下载
    /// 对应 Bun: S3HttpDownloadStreamingTask 执行逻辑
    public func execute(): Unit {
        // 简化: 实际实现会使用流式 HTTP 下载
        let client = S3Client(credentials)
        match (client.download(path)) {
            case Some(bytes) => {
                match (targetStream) {
                    case Some(stream) => {
                        let data = ArrayList<UInt8>()
                        for (b in bytes) {
                            data.append(b)
                        }
                        stream.onData(data, true)
                        downloadedBytes = bytes.size
                    }
                    case None => ()
                }
            }
            case None => ()
        }
        done = true
    }

    /// 中止下载
    public func abort(): Unit {
        done = true
    }
}

// ============================================================================
// S3SimpleRequest - S3 简单请求
// 对应 Bun: s3/simple_request.zig
// ============================================================================

/// S3 简单请求结果
/// 对应 Bun: S3UploadResult, S3DownloadResult, S3DeleteResult
public class S3SimpleResult {
    /// 是否成功
    public var success: Bool
    /// 错误信息
    public var error: ?S3Error
    /// 下载数据
    public var data: Array<UInt8>
    /// ETag
    public var etag: String
    /// 版本 ID
    public var versionId: String

    public init() {
        success = false
        error = None
        data = Array<UInt8>()
        etag = ""
        versionId = ""
    }

    public init(success: Bool) {
        this.success = success
        error = None
        data = Array<UInt8>()
        etag = ""
        versionId = ""
    }
}
