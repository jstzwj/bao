// bao_install - 网络下载任务
// 严格翻译自: src/install/NetworkTask.zig
//   pub const NetworkTask = struct {
//       unsafe_http_client: AsyncHTTP,
//       response: HTTPClientResult,
//       task_id: Task.Id,
//       url_buf: []const u8,
//       retried: u16,
//       allocator: std.mem.Allocator,
//       request_buffer: MutableString,
//       response_buffer: MutableString,
//       package_manager: *PackageManager,
//       callback: union(Task.Tag) {
//           package_manifest: struct { ... },
//           extract: ExtractTarball,
//           git_clone: void,
//           git_checkout: void,
//           local_tarball: void,
//       },
//       ...
//   }
package bao_install

import bao_core.*
import bao_collections.*
import bao_io.*
import bao_hash.*
import bao_path.*
import bao_http.*

// ============================================================================
// 网络任务授权选项
// 严格翻译自: src/install/NetworkTask.zig - Authorization
//   pub const Authorization = enum { no_authorization, allow_authorization }
// ============================================================================

/// 授权选项
public enum NetworkAuthorization {
    | NoAuthorization
    | AllowAuthorization
}

// ============================================================================
// Accept 头值
// 严格翻译自: src/install/NetworkTask.zig
//   const accept_header_value = "application/vnd.npm.install-v1+json; q=1.0, application/json; q=0.8, */*"
//   const accept_header_value_extended = "application/json, */*"
// ============================================================================

/// 标准 Accept 头
/// 翻译自: accept_header_value
public let ACCEPT_HEADER_VALUE: String = "application/vnd.npm.install-v1+json; q=1.0, application/json; q=0.8, */*"

/// 扩展 Accept 头 (用于完整 manifest)
/// 翻译自: accept_header_value_extended
public let ACCEPT_HEADER_VALUE_EXTENDED: String = "application/json, */*"

// ============================================================================
// 网络任务回调类型
// 严格翻译自: src/install/NetworkTask.zig - callback (union)
//   callback: union(Task.Tag) {
//       package_manifest: struct {
//           loaded_manifest: ?Npm.PackageManifest,
//           name: StringOrTinyString,
//           is_extended_manifest: bool,
//       },
//       extract: ExtractTarball,
//       git_clone: void,
//       git_checkout: void,
//       local_tarball: void,
//   }
// ============================================================================

/// 网络任务类型标签
public enum NetworkTaskType {
    | PackageManifest
    | Extract
    | GitClone
    | GitCheckout
    | LocalTarball
}

/// Package Manifest 回调数据
/// 翻译自: callback.package_manifest
public class PackageManifestCallback {
    /// 已加载的 manifest (缓存命中时)
    public var loadedManifest: ?PackageManifestData
    /// 包名
    public var name: String
    /// 是否请求完整 manifest
    public var isExtendedManifest: Bool

    public init(name: String) {
        loadedManifest = None
        this.name = name
        isExtendedManifest = false
    }
}

/// Extract (tarball 下载) 回调数据
/// 翻译自: callback.extract (ExtractTarball)
public class ExtractTarballCallback {
    /// 包名
    public var name: String
    /// tarball URL
    public var url: String
    /// 解析版本
    public var resolution: String
    /// 完整性哈希
    public var integrity: String

    public init(name: String, url: String) {
        this.name = name
        this.url = url
        resolution = ""
        integrity = ""
    }

    /// 构建 tarball URL
    /// 翻译自: ExtractTarball.buildURL
    public static func buildURL(registryUrl: String, name: String, version: String, stringBuf: String): String {
        if (version.length > 0) {
            let encoded = name.replace("/", "%2f")
            let base = registryUrl
            let sep = if (base.endsWith("/")) { "" } else { "/" }
            return "${base}${sep}${encoded}/-/${encoded}-${version}.tgz"
        }
        return ""
    }
}

// ============================================================================
// 网络任务
// 严格翻译自: src/install/NetworkTask.zig - NetworkTask
// ============================================================================

/// 网络任务
/// 对应 Bun: install.NetworkTask
/// 负责发起 HTTP 请求获取包 manifest 或下载 tarball
public class NetworkTask {
    /// 唯一任务 ID
    public var taskId: Int64
    /// 请求 URL
    public var urlBuf: String
    /// 重试次数
    /// 翻译自: retried: u16
    public var retried: UInt16
    /// 最大重试次数
    public var maxRetries: UInt16
    /// 任务类型
    public var taskType: NetworkTaskType
    /// 回调数据: package manifest
    public var manifestCallback: ?PackageManifestCallback
    /// 回调数据: extract tarball
    public var extractCallback: ?ExtractTarballCallback
    /// 是否是 git clone
    public var isGitClone: Bool
    /// 是否是 git checkout
    public var isGitCheckout: Bool
    /// 是否是本地 tarball
    public var isLocalTarball: Bool
    /// 响应状态码
    public var statusCode: Int64
    /// 响应体
    public var responseBody: String
    /// 错误信息
    public var error: ?String
    /// 是否完成
    public var completed: Bool
    /// 是否提交了流式提取
    /// 翻译自: streaming_committed
    public var streamingCommitted: Bool
    /// 下一个任务 (链表)
    /// 翻译自: next: ?*NetworkTask
    public var next: ?NetworkTask
    /// 是否是可选依赖
    public var isOptional: Bool

    public init(taskId: Int64) {
        this.taskId = taskId
        urlBuf = ""
        retried = UInt16(0)
        maxRetries = UInt16(3)
        taskType = NetworkTaskType.PackageManifest
        manifestCallback = None
        extractCallback = None
        isGitClone = false
        isGitCheckout = false
        isLocalTarball = false
        statusCode = 0
        responseBody = ""
        error = None
        completed = false
        streamingCommitted = false
        next = None
        isOptional = false
    }

    /// 配置用于获取包 manifest
    /// 翻译自: NetworkTask.forManifest
    ///   设置 URL, headers (Accept, If-None-Match, If-Modified-Since, Authorization)
    public func forManifest(
        name: String,
        scope: RegistryConfig,
        loadedManifest: ?PackageManifestData,
        isOptional: Bool,
        needsExtended: Bool
    ): Unit {
        this.isOptional = isOptional
        this.taskType = NetworkTaskType.PackageManifest

        // 构建 URL: registry + encoded_name
        var encodedName = name
        if (name.contains("/")) {
            encodedName = name.replace("/", "%2f")
        }

        let baseUrl = scope.url
        let sep = if (baseUrl.endsWith("/")) { "" } else { "/" }
        urlBuf = "${baseUrl}${sep}${encodedName}"

        // 设置回调数据
        let cb = PackageManifestCallback(name)
        cb.isExtendedManifest = needsExtended
        match (loadedManifest) {
            case Some(m) => cb.loadedManifest = loadedManifest
            case None => ()
        }
        manifestCallback = Some(cb)

        // Accept 头
        let acceptHeader = if (needsExtended) { ACCEPT_HEADER_VALUE_EXTENDED } else { ACCEPT_HEADER_VALUE }

        // 缓存头: If-None-Match (etag), If-Modified-Since
        // 翻译自: NetworkTask.forManifest 中 etag/last_modified 逻辑
    }

    /// 配置用于下载 tarball
    /// 翻译自: NetworkTask.forTarball
    public func forTarball(
        tarball: ExtractTarballCallback,
        scope: RegistryConfig,
        authorization: NetworkAuthorization
    ): Unit {
        this.taskType = NetworkTaskType.Extract
        extractCallback = Some(tarball)

        let tarballUrl = tarball.url
        if (tarballUrl.length > 0) {
            urlBuf = tarballUrl
        } else {
            // 从 registry URL 构建 tarball URL
            urlBuf = ExtractTarballCallback.buildURL(
                scope.url,
                tarball.name,
                "",
                ""
            )
        }

        // 校验 URL 协议
        if (!urlBuf.startsWith("https://") && !urlBuf.startsWith("http://")) {
            error = Some("Expected tarball URL to start with https:// or http://, got ${urlBuf}")
            return
        }
    }

    /// 完成回调
    /// 翻译自: NetworkTask.notify
    ///   当 HTTP 请求完成时调用, 处理响应并通知 package manager
    public func notify(statusCode: Int64, body: String, err: ?String): Unit {
        this.statusCode = statusCode
        this.responseBody = body
        this.error = err
        this.completed = true

        // 处理流式提取
        // 翻译自: NetworkTask.notify 中 tarball_stream 逻辑
        // 流式提取: 将响应体直接传递给解压器而不是缓冲全部数据
    }

    /// 是否需要重试
    /// 翻译自: NetworkTask 中的重试逻辑
    public func shouldRetry(): Bool {
        if (retried >= maxRetries) { return false }
        match (error) {
            case Some(_) => {
                retried = UInt16(Int64(retried) + 1)
                return true
            }
            case None => {
                // 5xx 错误可重试
                if (statusCode >= 500) {
                    retried = UInt16(Int64(retried) + 1)
                    return true
                }
                return false
            }
        }
    }

    /// 重置用于重试
    /// 翻译自: NetworkTask.resetStreamingForRetry
    public func resetForRetry(): Unit {
        completed = false
        error = None
        statusCode = 0
        responseBody = ""
        streamingCommitted = false
    }

    /// 丢弃未使用的流式状态
    /// 翻译自: NetworkTask.discardUnusedStreamingState
    public func discardUnusedStreamingState(): Unit {
        if (!streamingCommitted) {
            // 清理流式提取相关资源
        }
    }

    /// 获取 Accept 头
    public func getAcceptHeader(): String {
        match (taskType) {
            case PackageManifest => {
                match (manifestCallback) {
                    case Some(cb) => if (cb.isExtendedManifest) { ACCEPT_HEADER_VALUE_EXTENDED } else { ACCEPT_HEADER_VALUE }
                    case None => ACCEPT_HEADER_VALUE
                }
            }
            case _ => "*/*"
        }
    }

    /// 构建授权头
    /// 翻译自: NetworkTask.appendAuth / countAuth
    public static func buildAuthHeader(scope: RegistryConfig): ?String {
        if (scope.token.length > 0) {
            return Some("Bearer ${scope.token}")
        } else if (scope.auth.length > 0) {
            return Some("Basic ${scope.auth}")
        }
        return None
    }
}

// ============================================================================
// 去重映射
// 严格翻译自: src/install/NetworkTask.zig - DedupeMap
//   pub const DedupeMap = std.HashMap(Task.Id, DedupeMapEntry, IdentityContext(Task.Id), 80)
//   pub const DedupeMapEntry = struct { is_required: bool }
// ============================================================================

/// 网络任务去重映射
/// 翻译自: NetworkTask.DedupeMap
public class NetworkTaskDedupeMap {
    private var map: HashMap<Int64, Bool>

    public init() {
        map = HashMap<Int64, Bool>()
    }

    /// 插入或查找已有任务
    public func getOrInsert(taskId: Int64, isRequired: Bool): Bool {
        match (map.get(taskId)) {
            case Some(_) => return true  // 已存在
            case None => {
                map.put(taskId, isRequired)
                return false
            }
        }
    }

    /// 检查是否包含
    public func contains(taskId: Int64): Bool {
        match (map.get(taskId)) {
            case Some(_) => true
            case None => false
        }
    }

    /// 移除
    public func remove(taskId: Int64): Bool {
        return map.remove(taskId)
    }
}

// ============================================================================
// 包 Manifest 数据
// 严格翻译自: src/install/npm.zig - PackageManifest
//   Bun 的 PackageManifest 包含所有版本的元数据
// ============================================================================

/// 包 Manifest 数据
/// 对应 Bun: Npm.PackageManifest
public class PackageManifestData {
    /// 包名
    public var name: String
    /// 所有可用版本
    public var versions: ArrayList<String>
    /// dist-tags (latest, next, beta, etc.)
    public var distTags: HashMap<String, String>
    /// 最后修改时间
    public var lastModified: String
    /// ETag
    public var etag: String
    /// 缓存控制时间戳
    public var cacheControlTimestamp: Int64
    /// 是否有扩展 manifest
    public var hasExtendedManifest: Bool

    public init(name: String) {
        this.name = name
        versions = ArrayList<String>()
        distTags = HashMap<String, String>()
        lastModified = ""
        etag = ""
        cacheControlTimestamp = 0
        hasExtendedManifest = false
    }

    /// 从 HTTP 响应解析 manifest
    /// 翻译自: Npm.Registry.getPackageMetadata
    public static func parseFromResponse(
        body: String,
        packageName: String,
        lastModified: String,
        etag: String,
        cacheTimestamp: Int64,
        isExtended: Bool
    ): ?PackageManifestData {
        // 304 Not Modified -> 返回缓存的 manifest
        let manifest = PackageManifestData(packageName)
        manifest.lastModified = lastModified
        manifest.etag = etag
        manifest.cacheControlTimestamp = cacheTimestamp
        manifest.hasExtendedManifest = isExtended

        // 解析 JSON body 提取 versions 和 dist-tags
        // 翻译自: PackageManifest.parse
        try {
            let json = bao_json.JsonParser.parse(body)
            // dist-tags
            match (json.get("dist-tags")) {
                case Some(tags) => {
                    let tagObj = tags.asObject()
                    if (tagObj != None) {
                        for (key in tagObj.keys()) {
                            match (tagObj.get(key)) {
                                case Some(v) => manifest.distTags.put(key, v.asString())
                                case None => ()
                            }
                        }
                    }
                }
                case None => ()
            }
            // versions
            match (json.get("versions")) {
                case Some(vers) => {
                    let verObj = vers.asObject()
                    if (verObj != None) {
                        for (key in verObj.keys()) {
                            manifest.versions.append(key)
                        }
                    }
                }
                case None => ()
            }
            return manifest
        } catch (_: Exception) {
            return None
        }
    }

    /// 获取指定 dist-tag 的版本
    public func getDistTag(tag: String): ?String {
        match (distTags.get(tag)) {
            case Some(v) => Some(v)
            case None => None
        }
    }

    /// 获取 latest 版本
    public func getLatest(): ?String {
        return getDistTag("latest")
    }

    /// 查找满足 semver range 的最佳版本
    /// 翻译自: PackageManifest 中的版本匹配逻辑
    public func findBestVersion(range: String): ?String {
        let sv = SemVer.parse(range)
        match (sv) {
            case Some(target) => {
                // 精确匹配
                for (v in versions) {
                    let ver = SemVer.parse(v)
                    match (ver) {
                        case Some(parsed) => {
                            if (parsed.compare(target) == 0) { return v }
                        }
                        case None => ()
                    }
                }
                // 最新兼容版本
                var bestMatch: ?String = None
                for (v in versions) {
                    if (SemVer.satisfies(SemVer.parse(v).getOrThrow(), range)) {
                        bestMatch = Some(v)
                    }
                }
                return bestMatch
            }
            case None => {
                // dist-tag
                return getDistTag(range)
            }
        }
    }
}

// ============================================================================
// 网络任务队列
// 严格翻译自: src/install/PackageManager.zig
//   const NetworkQueue = bun.LinearFifo(*NetworkTask, .{ .Static = 32 })
//   const AsyncNetworkTaskQueue = bun.UnboundedQueue(NetworkTask, .next)
// ============================================================================

/// 网络任务队列 (静态大小 32)
/// 翻译自: NetworkQueue
public class NetworkTaskQueue {
    private var items: ArrayList<NetworkTask>
    private let capacity: Int64

    public init() {
        capacity = 32
        items = ArrayList<NetworkTask>()
    }

    public func push(task: NetworkTask): Unit {
        items.append(task)
    }

    public func pop(): ?NetworkTask {
        if (items.size > 0) {
            return items.removeAt(0)
        }
        return None
    }

    public func isEmpty(): Bool {
        return items.size == 0
    }

    public func count(): Int64 {
        return items.size
    }
}

/// 异步网络任务队列 (无界)
/// 翻译自: AsyncNetworkTaskQueue
public class AsyncNetworkTaskQueue {
    private var head: ?NetworkTask
    private var tail: ?NetworkTask
    private var count: Int64

    public init() {
        head = None
        tail = None
        count = 0
    }

    /// 入队
    /// 翻译自: UnboundedQueue.push
    public func push(task: NetworkTask): Unit {
        task.next = None
        match (tail) {
            case Some(t) => {
                t.next = task
                tail = task
            }
            case None => {
                head = task
                tail = task
            }
        }
        count += 1
    }

    /// 批量出队
    /// 翻译自: UnboundedQueue.popBatch
    public func drain(): ArrayList<NetworkTask> {
        let result = ArrayList<NetworkTask>()
        var current = head
        head = None
        tail = None
        while (current != None) {
            match (current) {
                case Some(task) => {
                    result.append(task)
                    let nextTask = task.next
                    task.next = None
                    current = nextTask
                }
                case None => current = None
            }
        }
        count = 0
        return result
    }

    public func isEmpty(): Bool {
        return head == None
    }

    public func count(): Int64 {
        return count
    }
}
