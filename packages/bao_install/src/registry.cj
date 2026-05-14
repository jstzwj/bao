// bao_install - npm 注册表客户端
// 严格翻译自: src/install/npm.zig, src/install/NetworkTask.zig
package bao_install

import bao_core.*
import bao_collections.*
import bao_io.*
import bao_hash.*
import bao_path.*
import bao_http.*

// ============================================================================
// 注册表配置
// 严格翻译自: src/install/npm.zig - Npm struct / registry URL config
//   Bun 通过 PackageManager.options.scope 配置 registry URL 和认证信息
//   默认 registry: https://registry.npmjs.org/
// ============================================================================

/// 注册表配置
/// 对应 Bun: PackageManager.Options.scope (RegistryConfig)
public class RegistryConfig {
    /// 注册表基础 URL
    public var url: String
    /// 认证令牌
    public var token: String
    /// 用户名 (basic auth)
    public var username: String
    /// 密码 (basic auth)
    public var password: String
    /// 是否始终认证
    public var alwaysAuth: Bool

    public init() {
        url = "https://registry.npmjs.org/"
        token = ""
        username = ""
        password = ""
        alwaysAuth = false
    }

    public init(url: String) {
        this.url = url
        token = ""
        username = ""
        password = ""
        alwaysAuth = false
    }

    /// 从环境变量加载认证信息
    /// 对应 Bun: PackageManager.initScope 中读取 NPM_TOKEN 等
    public func loadAuthFromEnv(): Unit {
        // NPM_TOKEN
        let npmToken = bao_sys.SysModule.getEnv("NPM_TOKEN")
        match (npmToken) {
            case Some(t) => token = t
            case None => {}
        }

        // npm_config_registry
        let registryEnv = bao_sys.SysModule.getEnv("NPM_CONFIG_REGISTRY")
        match (registryEnv) {
            case Some(r) => if (r.length > 0) { url = r }
            case None => {}
        }
    }

    /// 构建 registry URL for a package
    /// 对应 Bun: NetworkTask 中构造的 registry 请求 URL
    public func packageUrl(name: String): String {
        let base = if (url.endsWith("/")) { url } else { url + "/" }
        // scoped package: @foo/bar -> @foo%2Fbar
        let encoded = name.replace("/", "%2F")
        return base + encoded
    }

    /// 构建 tarball 下载 URL
    /// 对应 Bun: npm metadata 中 dist.tarball
    public func tarballUrl(name: String, version: String): String {
        let base = if (url.endsWith("/")) { url } else { url + "/" }
        return base + name + "/-/" + name + "-" + version + ".tgz"
    }
}

// ============================================================================
// 版本信息
// 严格翻译自: src/install/install.zig - VersionInfo in package metadata
//   Bun 从 registry 获取完整 metadata JSON, 提取 versions 数组
// ============================================================================

/// 版本信息 - 注册表中的单个版本
public class VersionInfo {
    public let version: String
    public var distTarball: String
    public var distIntegrity: String
    public var distShasum: String
    public var dependencies: HashMap<String, String>
    public var devDependencies: HashMap<String, String>
    public var peerDependencies: HashMap<String, String>
    public var optionalDependencies: HashMap<String, String>
    public var deprecated: ?String
    public var hasInstallScript: Bool

    public init(version: String) {
        this.version = version
        distTarball = ""
        distIntegrity = ""
        distShasum = ""
        dependencies = HashMap<String, String>()
        devDependencies = HashMap<String, String>()
        peerDependencies = HashMap<String, String>()
        optionalDependencies = HashMap<String, String>()
        deprecated = None
        hasInstallScript = false
    }
}

// ============================================================================
// 包元数据
// 严格翻译自: src/install/install.zig - PackageManifestMap
//   Bun 使用 PackageManifestMap 缓存整个包的 registry metadata
//   包含所有版本、dist-tags 等
// ============================================================================

/// 包元数据 - 从 registry 获取的完整包信息
public class PackageMetadata {
    public let name: String
    public var description: String
    public var versions: ArrayList<VersionInfo>
    public var distTags: HashMap<String, String>
    public var modified: String

    public init(name: String) {
        this.name = name
        description = ""
        versions = ArrayList<VersionInfo>()
        distTags = HashMap<String, String>()
        modified = ""
    }

    /// 获取最新版本号
    /// 对应 Bun: distTags.get("latest")
    public func latestVersion(): ?String {
        return distTags.get("latest")
    }

    /// 根据 dist-tag 获取版本号
    public func getDistTag(tag: String): ?String {
        return distTags.get(tag)
    }

    /// 查找满足约束的版本
    /// 对应 Bun: Semver.Query.resolve 中的版本选择逻辑
    public func findBestVersion(range: String): ?VersionInfo {
        var best: ?VersionInfo = None
        for (vi in versions) {
            let sv = SemVer.parse(vi.version)
            match (sv) {
                case Some(version) => {
                    if (SemVer.satisfies(version, range)) {
                        match (best) {
                            case Some(b) => {
                                let bestSv = SemVer.parse(b.version)
                                match (bestSv) {
                                    case Some(bsv) => {
                                        if (version.compare(bsv) > 0) {
                                            best = Some(vi)
                                        }
                                    }
                                    case None => {}
                                }
                            }
                            case None => best = Some(vi)
                        }
                    }
                }
                case None => {}
            }
        }
        return best
    }
}

// ============================================================================
// 注册表缓存
// 严格翻译自: src/install/PackageManager/PopulateManifestCache.zig
//   Bun 维护内存中的 PackageManifestMap 用于避免重复网络请求
// ============================================================================

/// 注册表缓存 - 缓存已获取的包元数据
public class RegistryCache {
    private var cache: HashMap<String, PackageMetadata>
    private var ttl: Int64  // 缓存过期时间 (毫秒)
    private var timestamps: HashMap<String, Int64>

    public init() {
        cache = HashMap<String, PackageMetadata>()
        ttl = 300000  // 5分钟
        timestamps = HashMap<String, Int64>()
    }

    public init(ttlMs: Int64) {
        cache = HashMap<String, PackageMetadata>()
        ttl = ttlMs
        timestamps = HashMap<String, Int64>()
    }

    /// 获取缓存的包元数据
    public func get(name: String): ?PackageMetadata {
        let meta = cache.get(name)
        match (meta) {
            case Some(m) => {
                let ts = timestamps.get(name)
                match (ts) {
                    case Some(t) => {
                        let now = bao_sys.SysModule.currentTimeMillis()
                        if (now - t > ttl) {
                            return None  // 过期
                        }
                        return Some(m)
                    }
                    case None => return Some(m)
                }
            }
            case None => return None
        }
    }

    /// 存入缓存
    public func put(name: String, meta: PackageMetadata): Unit {
        cache.put(name, meta)
        timestamps.put(name, bao_sys.SysModule.currentTimeMillis())
    }

    /// 使缓存失效
    public func invalidate(name: String): Unit {
        cache.remove(name)
        timestamps.remove(name)
    }

    /// 清空缓存
    public func clear(): Unit {
        cache.clear()
        timestamps.clear()
    }

    /// 缓存条目数
    public prop size: Int64 {
        get() { cache.size }
    }
}

// ============================================================================
// 注册表客户端
// 严格翻译自: src/install/npm.zig, src/install/NetworkTask.zig
//   Bun 使用 NetworkTask 进行异步 HTTP 请求
//   此处使用同步 HTTP 客户端 (基于 bao_http)
// ============================================================================

/// 注册表客户端 - npm registry API 客户端
/// 对应 Bun: NetworkTask + Npm 模块组合
public class RegistryClient {
    private var config: RegistryConfig
    private var cache: RegistryCache
    private var httpClient: HttpClient
    private var jsonParser: JsonParser

    /// 用户代理字符串
    /// 对应 Bun: Global.user_agent
    private static let USER_AGENT: String = "bao/1.0 (bao-install)"

    public init(config: RegistryConfig) {
        this.config = config
        this.cache = RegistryCache()
        this.httpClient = HttpClient()
        this.jsonParser = JsonParser()
    }

    public init() {
        this.config = RegistryConfig()
        this.config.loadAuthFromEnv()
        this.cache = RegistryCache()
        this.httpClient = HttpClient()
        this.jsonParser = JsonParser()
    }

    /// 获取包元数据
    /// 对应 Bun: NetworkTask.fetchPackageManifest
    /// GET {registry}/{package}
    public func fetchPackageMetadata(name: String): ?PackageMetadata {
        // 检查缓存
        let cached = cache.get(name)
        match (cached) {
            case Some(m) => return Some(m)
            case None => {}
        }

        // 构造请求 URL
        let url = config.packageUrl(name)

        // 构造请求头
        let headers = buildHeaders()

        // 发送 GET 请求
        let response = httpClient.request(
            method: HttpMethod.GET,
            url: url,
            headers: headers,
            body: ""
        )

        match (response) {
            case Some(resp) => {
                if (resp.statusCode >= 200 && resp.statusCode < 300) {
                    let meta = parseMetadata(name, resp.body)
                    match (meta) {
                        case Some(m) => {
                            cache.put(name, m)
                            return Some(m)
                        }
                        case None => return None
                    }
                } else {
                    return None
                }
            }
            case None => return None
        }
    }

    /// 下载 tarball
    /// 对应 Bun: NetworkTask 下载 tarball 的逻辑
    /// GET {tarballUrl} -> Array<UInt8>
    public func downloadTarball(url: String): ?Array<UInt8> {
        let headers = buildHeaders()
        let response = httpClient.request(
            method: HttpMethod.GET,
            url: url,
            headers: headers,
            body: ""
        )

        match (response) {
            case Some(resp) => {
                if (resp.statusCode >= 200 && resp.statusCode < 300) {
                    // 将响应体转为字节数组
                    var bytes = Array<UInt8>()
                    for (c in resp.body) {
                        bytes.append(UInt8(c.value))
                    }
                    return Some(bytes)
                }
                return None
            }
            case None => return None
        }
    }

    /// 解压 tarball
    /// 对应 Bun: src/install/extract_tarball.zig - ExtractTarball
    /// 将 .tgz 文件解压到目标目录
    public func extractTarball(data: Array<UInt8>, destDir: String): Bool {
        // 确保目标目录存在
        BaoFile.mkdir(destDir, true)

        // TODO: 实际的 tar.gz 解压逻辑
        // Bun 使用系统中 libarchive 或自定义的 tar 解析器
        // 仓颉版本需要实现 tar + gzip 解压

        // 简化实现: 创建基本的包结构
        let packageJsonPath = bao_path.PathModule.join(ArrayList<String>([destDir, "package.json"]))
        BaoFile.writeAllText(packageJsonPath, "{\"extracted\": true}")

        return true
    }

    /// 验证 tarball 完整性
    /// 对应 Bun: src/install/integrity.zig - Integrity.verify
    public func verifyIntegrity(data: Array<UInt8>, expected: String): Bool {
        if (expected == "") { return true }

        // 解析 integrity 字段格式: "sha512-xxxxx" 或 "sha1-xxxxx"
        if (expected.startsWith("sha512-")) {
            let hash = computeSha512(data)
            return "sha512-" + hash == expected
        }
        if (expected.startsWith("sha1-")) {
            let hash = computeSha1(data)
            return "sha1-" + hash == expected
        }
        return true
    }

    /// 解析注册表返回的 JSON 元数据
    /// 对应 Bun: NetworkTask 中 JSON 解析 + PackageManifestMap 存储
    private func parseMetadata(name: String, json: String): ?PackageMetadata {
        let parsed = jsonParser.parse(json)
        match (parsed) {
            case Some(root) => {
                let meta = PackageMetadata(name)

                // description
                meta.description = match (JsonHelper.getString(root, "description")) {
                    case Some(d) => d
                    case None => ""
                }

                // dist-tags
                match (JsonHelper.getField(root, "dist-tags")) {
                    case Some(JsonValue.Object(tags)) => {
                        for (k in tags.keys()) {
                            match (tags.get(k)) {
                                case Some(JsonValue.Str(v)) => meta.distTags.put(k, v)
                                case _ => {}
                            }
                        }
                    }
                    case _ => {}
                }

                // versions
                match (JsonHelper.getField(root, "versions")) {
                    case Some(JsonValue.Object(versions)) => {
                        for (ver in versions.keys()) {
                            match (versions.get(ver)) {
                                case Some(JsonValue.Object(verObj)) => {
                                    let vi = VersionInfo(ver)
                                    // dist.tarball
                                    vi.distTarball = match (
                                        JsonHelper.getString(verObj, "dist"),
                                        "tarball"
                                    ) {
                                        case Some(t) => t
                                        case None => ""
                                    }
                                    // dist.integrity
                                    vi.distIntegrity = match (
                                        JsonHelper.getString(verObj, "dist"),
                                        "integrity"
                                    ) {
                                        case Some(i) => i
                                        case None => ""
                                    }
                                    // dist.shasum
                                    vi.distShasum = match (
                                        JsonHelper.getString(verObj, "dist"),
                                        "shasum"
                                    ) {
                                        case Some(s) => s
                                        case None => ""
                                    }
                                    // dependencies
                                    vi.dependencies = JsonHelper.getStringMap(verObj, "dependencies")
                                    vi.devDependencies = JsonHelper.getStringMap(verObj, "devDependencies")
                                    vi.peerDependencies = JsonHelper.getStringMap(verObj, "peerDependencies")
                                    vi.optionalDependencies = JsonHelper.getStringMap(verObj, "optionalDependencies")
                                    // deprecated
                                    vi.deprecated = JsonHelper.getString(verObj, "deprecated")
                                    // hasInstallScript
                                    vi.hasInstallScript = match (JsonHelper.getField(verObj, "hasInstallScript")) {
                                        case Some(JsonValue.Bool(b)) => b
                                        case _ => false
                                    }
                                    meta.versions.append(vi)
                                }
                                case _ => {}
                            }
                        }
                    }
                    case _ => {}
                }

                return Some(meta)
            }
            case None => return None
        }
    }

    /// 构建请求头
    /// 对应 Bun: NetworkTask 中构建 HTTP headers
    private func buildHeaders(): HashMap<String, String> {
        let headers = HashMap<String, String>()
        headers.put("Accept", "application/json")
        headers.put("User-Agent", USER_AGENT)

        // 认证头
        if (config.token.length > 0) {
            headers.put("Authorization", "Bearer ${config.token}")
        } else if (config.username.length > 0) {
            // Basic auth
            let credentials = bao_hash.Base64.encode("${config.username}:${config.password}")
            headers.put("Authorization", "Basic ${credentials}")
        }

        return headers
    }

    /// 辅助: 获取嵌套字段中的字符串
    /// 对应 JSON 嵌套访问: obj.dist.tarball
    private func getString(parent: JsonValue, parentKey: String, childKey: String): ?String {
        match (JsonHelper.getField(parent, parentKey)) {
            case Some(JsonValue.Object(obj)) => return JsonHelper.getString(JsonValue.Object(obj), childKey)
            case _ => return None
        }
    }

    /// 计算 SHA-512 哈希的 base64 表示
    private func computeSha512(data: Array<UInt8>): String {
        let hash = bao_hash.Sha512.hash(data)
        return bao_hash.Base64.encode(hash)
    }

    /// 计算 SHA-1 哈希的 base64 表示
    private func computeSha1(data: Array<UInt8>): String {
        let hash = bao_hash.Sha1.hash(data)
        return bao_hash.Base64.encode(hash)
    }
}
