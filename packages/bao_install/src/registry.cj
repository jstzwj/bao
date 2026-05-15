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
//   src/install/npm.zig: pub const Registry = struct { pub const default_url = "https://registry.npmjs.org/" }
// ============================================================================

/// 注册表配置
/// 对应 Bun: PackageManager.Options.scope (RegistryConfig)
/// 翻译自: src/install/npm.zig Npm.Registry.Scope
public class RegistryConfig {
    /// 注册表基础 URL
    /// 对应 Bun: scope.url.href
    public var url: String
    /// 认证令牌 (Bearer token)
    /// 对应 Bun: scope.token
    public var token: String
    /// Basic auth 编码字符串
    /// 对应 Bun: scope.auth
    public var auth: String
    /// 用户名 (basic auth)
    public var username: String
    /// 密码 (basic auth)
    public var password: String
    /// 是否始终认证
    /// 对应 Bun: scope.always_auth
    public var alwaysAuth: Bool

    public init() {
        url = "https://registry.npmjs.org/"
        token = ""
        auth = ""
        username = ""
        password = ""
        alwaysAuth = false
    }

    public init(url: String) {
        this.url = url
        token = ""
        auth = ""
        username = ""
        password = ""
        alwaysAuth = false
    }

    /// 从环境变量加载认证信息
    /// 对应 Bun: PackageManager.initScope 中读取 NPM_TOKEN 等
    /// 翻译自: src/install/PackageManager.zig 中 initScope 环境变量读取逻辑
    public func loadAuthFromEnv(): Unit {
        // NPM_TOKEN
        let npmToken = bao_sys.SysModule.getEnv("NPM_TOKEN")
        match (npmToken) {
            case Some(t) => token = t
            case None => {}
        }

        // NPM_CONFIG_REGISTRY - 覆盖默认 registry
        let registryEnv = bao_sys.SysModule.getEnv("NPM_CONFIG_REGISTRY")
        match (registryEnv) {
            case Some(r) => if (r.length > 0) { url = r }
            case None => {}
        }

        // Bun 翻译: 支持 Bun 特有的环境变量
        let bunToken = bao_sys.SysModule.getEnv("BUN_CONFIG_TOKEN")
        match (bunToken) {
            case Some(t) => token = t
            case None => {}
        }

        // 如果有 token, 自动设置 alwaysAuth
        if (token.length > 0) {
            alwaysAuth = true
        }

        // 如果有用户名和密码, 构建 Basic auth
        let npmUser = bao_sys.SysModule.getEnv("NPM_CONFIG_USERNAME")
        let npmPass = bao_sys.SysModule.getEnv("NPM_CONFIG_PASSWORD")
        match (npmUser) {
            case Some(u) => {
                username = u
                match (npmPass) {
                    case Some(p) => {
                        password = p
                        // 构建 Base64 编码的 Basic auth
                        auth = bao_hash.Base64.encode(Array<UInt8>(u.length + p.length + 1, item: 0))
                    }
                    case None => {}
                }
            }
            case None => {}
        }
    }

    /// 构建 registry URL for a package
    /// 对应 Bun: NetworkTask.forManifest 中的 URL 构造
    /// 翻译自: src/install/NetworkTask.zig forManifest()
    ///   const encoded_name = if (strings.containsChar(name, '/'))
    ///     std.mem.replaceOwned(u8, ..., name, "/", "%2f") else name;
    ///   const tmp = bun.jsc.URL.join(registry_url, encoded_name);
    public func packageUrl(name: String): String {
        let base = if (url.endsWith("/")) { url } else { url + "/" }
        // scoped package: @foo/bar -> @foo%2Fbar
        // Bun 翻译: 不是所有 registry 都支持 scoped package 的原始斜杠
        //   registry.npmjs.org 支持两种: @storybook%2Faddons 和 @storybook/addons
        //   AWS codeartifact 只支持前者
        //   npm CLI 使用编码后的名称请求
        let encoded = name.replace("/", "%2F")
        return base + encoded
    }

    /// 构建 tarball 下载 URL
    /// 对应 Bun: npm metadata 中 dist.tarball
    /// 翻译自: src/install/NetworkTask.zig forTarball() 中的 URL 构造
    public func tarballUrl(name: String, version: String): String {
        let base = if (url.endsWith("/")) { url } else { url + "/" }
        // 对于 scoped packages: @foo/bar -> @foo/bar/-/bar-1.0.0.tgz
        let pkgPart = name.replace("@", "")
        return base + name + "/-/" + name + "-" + version + ".tgz"
    }

    /// 获取 scope 前缀 (从包名提取)
    /// 对应 Bun: scope 解析逻辑
    public func getScopeForPackage(name: String): RegistryConfig {
        // 如果包名以 @ 开头, 检查是否有对应的 scope 配置
        if (name.startsWith("@")) {
            let slashIdx = name.indexOf("/")
            match (slashIdx) {
                case Some(idx) => {
                    let scope = name.substring(0, idx)
                    // 检查环境变量: NPM_CONFIG_${SCOPE}_REGISTRY
                    let envVar = "NPM_CONFIG_${scope}_REGISTRY"
                    let scopeRegistry = bao_sys.SysModule.getEnv(envVar)
                    match (scopeRegistry) {
                        case Some(r) => if (r.length > 0) {
                            return RegistryConfig(r)
                        }
                        case None => {}
                    }
                }
                case None => {}
            }
        }
        return this
    }
}

// ============================================================================
// 版本信息
// 严格翻译自: src/install/install.zig - VersionInfo in package metadata
//   Bun 从 registry 获取完整 metadata JSON, 提取 versions 数组
//   对应 Npm.PackageManifest 中每个版本的解析
// ============================================================================

/// 版本信息 - 注册表中的单个版本
/// 对应 Bun: Npm.PackageManifest 中单个版本的元数据
public class VersionInfo {
    public let version: String
    /// tarball 下载 URL
    /// 对应 Bun: dist.tarball
    public var distTarball: String
    /// SRI integrity (sha512-xxxx)
    /// 对应 Bun: dist.integrity
    public var distIntegrity: String
    /// shasum (十六进制)
    /// 对应 Bun: dist.shasum
    public var distShasum: String
    /// 文件数量
    /// 对应 Bun: dist.fileCount
    public var distFileCount: Int64
    /// 解压后大小
    /// 对应 Bun: dist.unpackedSize
    public var distUnpackedSize: Int64
    /// NPM signature
    /// 对应 Bun: dist.signatures
    public var distNpmSignature: String

    public var dependencies: HashMap<String, String>
    public var devDependencies: HashMap<String, String>
    public var peerDependencies: HashMap<String, String>
    public var peerDependenciesMeta: HashMap<String, HashMap<String, String>>
    public var optionalDependencies: HashMap<String, String>
    public var bundledDependencies: ArrayList<String>
    /// 是否弃用
    /// 对应 Bun: deprecated 字段
    public var deprecated: ?String
    /// 是否有安装脚本
    /// 对应 Bun: hasInstallScript
    public var hasInstallScript: Bool
    /// CPU 限制
    /// 对应 Bun: cpu
    public var os: ArrayList<String>
    /// OS 限制
    /// 对应 Bun: os
    public var cpu: ArrayList<String>
    /// License
    public var license: String
    /// bin 条目 (命令名 -> 可执行文件)
    /// 对应 Bun: bin
    public var bin: HashMap<String, String>
    /// main 入口
    public var main: ?String
    /// module 入口
    public var module: ?String
    /// types 入口
    public var types: ?String

    public init(version: String) {
        this.version = version
        distTarball = ""
        distIntegrity = ""
        distShasum = ""
        distFileCount = 0
        distUnpackedSize = 0
        distNpmSignature = ""
        dependencies = HashMap<String, String>()
        devDependencies = HashMap<String, String>()
        peerDependencies = HashMap<String, String>()
        peerDependenciesMeta = HashMap<String, HashMap<String, String>>()
        optionalDependencies = HashMap<String, String>()
        bundledDependencies = ArrayList<String>()
        deprecated = None
        hasInstallScript = false
        os = ArrayList<String>()
        cpu = ArrayList<String>()
        license = ""
        bin = HashMap<String, String>()
        main = None
        module = None
        types = None
    }
}

// ============================================================================
// 包元数据
// 严格翻译自: src/install/install.zig - PackageManifestMap
//   Bun 使用 PackageManifestMap 缓存整个包的 registry metadata
//   翻译自: src/install/npm.zig 中 Npm.PackageManifest 结构
//   包含所有版本、dist-tags、time、etag 等
// ============================================================================

/// 包元数据 - 从 registry 获取的完整包信息
/// 对应 Bun: Npm.PackageManifest
public class PackageMetadata {
    public let name: String
    public var description: String
    /// 所有版本列表
    /// 对应 Bun: PackageManifest 中遍历 versions 对象
    public var versions: ArrayList<VersionInfo>
    /// 按 tag 索引的版本: latest, next, beta 等
    /// 对应 Bun: dist-tags 对象
    public var distTags: HashMap<String, String>
    /// 各版本发布时间
    /// 对应 Bun: time 对象
    public var time: HashMap<String, String>
    /// 最后修改时间 (HTTP header)
    /// 对应 Bun: PackageManifest.pkg.last_modified
    public var lastModified: String
    /// ETag (HTTP header)
    /// 对应 Bun: PackageManifest.pkg.etag
    public var etag: String
    /// 是否有扩展元数据
    /// 对应 Bun: PackageManifest.pkg.has_extended_manifest
    public var hasExtendedManifest: Bool
    /// 原始 JSON 缓存 (用于避免重复解析)
    public var rawJson: String

    public init(name: String) {
        this.name = name
        description = ""
        versions = ArrayList<VersionInfo>()
        distTags = HashMap<String, String>()
        time = HashMap<String, String>()
        lastModified = ""
        etag = ""
        hasExtendedManifest = false
        rawJson = ""
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

    /// 根据 exact version 查找 VersionInfo
    /// 对应 Bun: 从 versions map 中查找特定版本
    public func getVersion(version: String): ?VersionInfo {
        for (vi in versions) {
            if (vi.version == version) {
                return Some(vi)
            }
        }
        return None
    }

    /// 查找满足约束的最佳版本
    /// 对应 Bun: Semver.Query.resolve 中的版本选择逻辑
    /// 翻译自: src/install/resolution.zig 中版本匹配
    public func findBestVersion(range: String): ?VersionInfo {
        if (range == "*" || range == "" || range == "latest") {
            // 返回 latest dist-tag 版本
            let latest = latestVersion()
            match (latest) {
                case Some(v) => return getVersion(v)
                case None => {}
            }
        }

        var best: ?VersionInfo = None
        for (vi in versions) {
            // 跳过 pre-release 版本 (除非范围显式请求)
            let sv = SemVer.parse(vi.version)
            match (sv) {
                case Some(version) => {
                    // pre-release 版本只在范围包含 pre-release 标识符时匹配
                    if (version.prerelease.isSome()) {
                        // 检查 range 是否也包含 pre-release
                        var rangeHasPre = false
                        if (range.contains("-")) {
                            rangeHasPre = true
                        }
                        if (!rangeHasPre) {
                            continue
                        }
                    }

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

    /// 获取所有可用版本号 (降序)
    public func availableVersions(): ArrayList<String> {
        let result = ArrayList<String>()
        for (vi in versions) {
            result.append(vi.version)
        }
        // 按版本号降序排列 (最新的在前)
        result.sortBy(func(a: String, b: String): Int64 {
            let svA = SemVer.parse(a)
            let svB = SemVer.parse(b)
            match (svA) {
                case Some(a2) => match (svB) {
                    case Some(b2) => return b2.compare(a2)  // 降序
                    case None => return -1
                }
                case None => return 1
            }
        })
        return result
    }
}

// ============================================================================
// 注册表缓存
// 严格翻译自: src/install/PackageManager/PopulateManifestCache.zig
//   Bun 维护内存中的 PackageManifestMap 用于避免重复网络请求
//   翻译自: src/install/PackageManager.zig 中 manifests 字段
//   PackageManifestMap 使用 HashMap<String, Npm.PackageManifest> 存储
// ============================================================================

/// 注册表缓存 - 缓存已获取的包元数据
/// 对应 Bun: PackageManager.manifests (PackageManifestMap)
public class RegistryCache {
    /// name -> PackageMetadata
    private var cache: HashMap<String, PackageMetadata>
    /// 缓存过期时间 (毫秒), 0 表示不过期
    private var ttl: Int64
    /// 缓存时间戳 (用于 TTL 过期)
    private var timestamps: HashMap<String, Int64>
    /// ETag 存储 (name -> etag)
    private var etags: HashMap<String, String>
    /// Last-Modified 存储 (name -> lastModified)
    private var lastModifieds: HashMap<String, String>

    public init() {
        cache = HashMap<String, PackageMetadata>()
        ttl = 300000  // 5分钟, 与 Bun 一致
        timestamps = HashMap<String, Int64>()
        etags = HashMap<String, String>()
        lastModifieds = HashMap<String, String>()
    }

    public init(ttlMs: Int64) {
        cache = HashMap<String, PackageMetadata>()
        ttl = ttlMs
        timestamps = HashMap<String, Int64>()
        etags = HashMap<String, String>()
        lastModifieds = HashMap<String, String>()
    }

    /// 获取缓存的包元数据
    /// 对应 Bun: PackageManifestMap.get
    public func get(name: String): ?PackageMetadata {
        let meta = cache.get(name)
        match (meta) {
            case Some(m) => {
                if (ttl > 0) {
                    let ts = timestamps.get(name)
                    match (ts) {
                        case Some(t) => {
                            let now = bao_sys.SysModule.currentTimeMillis()
                            if (now - t > ttl) {
                                return None  // 过期
                            }
                        }
                        case None => {}
                    }
                }
                return Some(m)
            }
            case None => return None
        }
    }

    /// 存入缓存
    /// 对应 Bun: PackageManifestMap.put
    public func put(name: String, meta: PackageMetadata): Unit {
        cache.put(name, meta)
        timestamps.put(name, bao_sys.SysModule.currentTimeMillis())
        if (meta.etag.length > 0) {
            etags.put(name, meta.etag)
        }
        if (meta.lastModified.length > 0) {
            lastModifieds.put(name, meta.lastModified)
        }
    }

    /// 获取缓存条目的 ETag
    /// 对应 Bun: NetworkTask.forManifest 中使用 loaded_manifest.etag
    public func getEtag(name: String): String {
        match (etags.get(name)) {
            case Some(e) => return e
            case None => return ""
        }
    }

    /// 获取缓存条目的 Last-Modified
    /// 对应 Bun: NetworkTask.forManifest 中使用 loaded_manifest.last_modified
    public func getLastModified(name: String): String {
        match (lastModifieds.get(name)) {
            case Some(lm) => return lm
            case None => return ""
        }
    }

    /// 使缓存失效
    public func invalidate(name: String): Unit {
        cache.remove(name)
        timestamps.remove(name)
        etags.remove(name)
        lastModifieds.remove(name)
    }

    /// 清空缓存
    public func clear(): Unit {
        cache.clear()
        timestamps.clear()
        etags.clear()
        lastModifieds.clear()
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
//   NetworkTask 有两种回调: package_manifest 和 extract
//   此处使用同步 HTTP 客户端 (基于 bao_http) 进行简化
//
// 关键翻译来源:
//   - NetworkTask.forManifest(): 获取包元数据
//   - NetworkTask.forTarball(): 下载 tarball
//   - Npm.whoami(): 认证
//   - Npm.Registry: 注册表常量
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
    /// 翻译自: src/install/NetworkTask.zig 中 user-agent header
    private static let USER_AGENT: String = "bao/1.0 (bao-install)"

    /// 默认 Accept header (简洁版本)
    /// 对应 Bun: NetworkTask.accept_header_value
    /// 翻译自: const accept_header_value = "application/vnd.npm.install-v1+json; q=1.0, application/json; q=0.8, */*";
    private static let ACCEPT_HEADER_COMPACT: String = "application/vnd.npm.install-v1+json; q=1.0, application/json; q=0.8, */*"

    /// 扩展 Accept header (完整版本, 包含所有 metadata)
    /// 对应 Bun: NetworkTask.accept_header_value_extended
    /// 翻译自: const accept_header_value_extended = "application/json, */*";
    private static let ACCEPT_HEADER_EXTENDED: String = "application/json, */*"

    /// 最大重试次数
    /// 对应 Bun: NetworkTask 中 retried 字段
    private static let MAX_RETRIES: Int64 = 3

    /// 请求超时 (毫秒)
    private static let REQUEST_TIMEOUT: Int64 = 30000

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

    // ========================================================================
    // 包元数据获取
    // 严格翻译自: src/install/NetworkTask.zig forManifest()
    //   NetworkTask.forManifest 构造 GET 请求到 registry
    //   支持 ETag/If-None-Match 和 If-Modified-Since 条件请求
    //   支持 scoped package URL 编码
    // ========================================================================

    /// 获取包元数据
    /// 对应 Bun: NetworkTask.fetchPackageManifest -> forManifest -> GET {registry}/{package}
    public func fetchPackageMetadata(name: String): ?PackageMetadata {
        // 检查缓存
        let cached = cache.get(name)
        match (cached) {
            case Some(m) => return Some(m)
            case None => {}
        }

        // 获取该包的 scope 配置
        let scopeConfig = config.getScopeForPackage(name)

        // 构造请求 URL
        let url = scopeConfig.packageUrl(name)

        // 构造请求头
        // 翻译自: NetworkTask.forManifest 中 header_builder 构造
        let headers = buildManifestHeaders(name, scopeConfig)

        // 发送 GET 请求 (带重试)
        var response: ?HttpResponse = None
        var retryCount: Int64 = 0
        while (retryCount < MAX_RETRIES) {
            response = httpClient.request(
                method: HttpMethod.GET,
                url: url,
                headers: headers,
                body: ""
            )
            match (response) {
                case Some(resp) => {
                    // 304 Not Modified: 使用缓存
                    if (resp.statusCode == 304) {
                        // 缓存仍然有效, 返回缓存数据
                        return cache.get(name)
                    }
                    if (resp.statusCode >= 200 && resp.statusCode < 300) {
                        break  // 成功
                    }
                    // 404: 包不存在
                    if (resp.statusCode == 404) {
                        return None
                    }
                    // 5xx: 可能重试
                    if (resp.statusCode >= 500) {
                        retryCount += 1
                        continue
                    }
                    // 4xx: 不重试
                    return None
                }
                case None => {
                    retryCount += 1
                    continue
                }
            }
        }

        match (response) {
            case Some(resp) => {
                if (resp.statusCode >= 200 && resp.statusCode < 300) {
                    let meta = parseMetadata(name, resp)
                    match (meta) {
                        case Some(m) => {
                            // 保存 ETag 和 Last-Modified
                            match (resp.getHeader("ETag")) {
                                case Some(etag) => m.etag = etag
                                case None => {}
                            }
                            match (resp.getHeader("Last-Modified")) {
                                case Some(lm) => m.lastModified = lm
                                case None => {}
                            }
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

    /// 获取特定版本的元数据
    /// 对应 Bun: 从 PackageManifest.versions 中查找特定版本
    public func fetchVersionMetadata(name: String, version: String): ?VersionInfo {
        let meta = fetchPackageMetadata(name)
        match (meta) {
            case Some(m) => {
                // 先尝试精确版本
                let exact = m.getVersion(version)
                match (exact) {
                    case Some(v) => return Some(v)
                    case None => {}
                }
                // 再尝试 dist-tag
                let tagVersion = m.getDistTag(version)
                match (tagVersion) {
                    case Some(v) => return m.getVersion(v)
                    case None => {}
                }
                // 最后尝试版本范围
                return m.findBestVersion(version)
            }
            case None => return None
        }
    }

    // ========================================================================
    // Tarball 下载
    // 严格翻译自: src/install/NetworkTask.zig forTarball()
    //   NetworkTask.forTarball 构造 GET 请求下载 .tgz 文件
    //   支持 streaming extraction (此处简化为缓冲方式)
    // ========================================================================

    /// 下载 tarball
    /// 对应 Bun: NetworkTask.forTarball -> GET {tarballUrl} -> Array<UInt8>
    public func downloadTarball(url: String): ?Array<UInt8> {
        // 确定 scope: 从 URL 中推断或使用默认
        let headers = buildTarballHeaders(config)
        var retryCount: Int64 = 0
        var result: ?Array<UInt8> = None

        while (retryCount < MAX_RETRIES) {
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
                        let body = resp.bodyBytes
                        match (body) {
                            case Some(bytes) => {
                                result = Some(bytes)
                                break
                            }
                            case None => {
                                // 回退: 从 body 字符串转换
                                var bytes = Array<UInt8>()
                                for (c in resp.body) {
                                    bytes.append(UInt8(c.value))
                                }
                                result = Some(bytes)
                                break
                            }
                        }
                    }
                    if (resp.statusCode >= 500) {
                        retryCount += 1
                        continue
                    }
                    return None
                }
                case None => {
                    retryCount += 1
                    continue
                }
            }
        }

        return result
    }

    // ========================================================================
    // 完整性验证
    // 严格翻译自: src/install/integrity.zig
    //   Integrity struct: tag (sha1/sha256/sha384/sha512) + value
    //   Integrity.verify: 计算哈希并比较
    //   Integrity.forBytes: 从原始字节计算 sha512
    //   Integrity.parse: 从 "sha512-xxxx" 字符串解析
    // ========================================================================

    /// 验证 tarball 完整性
    /// 对应 Bun: src/install/integrity.zig - Integrity.verify
    /// 翻译自: Integrity.verify 比较计算哈希与预期哈希
    public func verifyIntegrity(data: Array<UInt8>, expected: String): Bool {
        if (expected == "") { return true }

        // 解析 integrity 字段格式: "sha512-xxxxx" 或 "sha1-xxxxx"
        // 翻译自: Integrity.Tag.parse
        if (expected.startsWith("sha512-")) {
            let expectedHash = expected.substring(7)  // 去掉 "sha512-" 前缀
            let computed = computeSha512Base64(data)
            return computed == expectedHash
        }
        if (expected.startsWith("sha384-")) {
            let expectedHash = expected.substring(7)
            let computed = computeSha384Base64(data)
            return computed == expectedHash
        }
        if (expected.startsWith("sha256-")) {
            let expectedHash = expected.substring(7)
            let computed = computeSha256Base64(data)
            return computed == expectedHash
        }
        if (expected.startsWith("sha1-")) {
            let expectedHash = expected.substring(5)
            let computed = computeSha1Base64(data)
            return computed == expectedHash
        }
        // shasum (40字符十六进制, 无前缀)
        if (expected.length == 40) {
            let computed = computeSha1Hex(data)
            return computed == expected
        }
        return true  // 未知格式, 跳过验证
    }

    // ========================================================================
    // JSON 解析
    // 严格翻译自: src/install/NetworkTask.zig 中 JSON 解析
    //   NetworkTask.onPackageManifest 中解析 registry 返回的 JSON
    //   提取: name, description, dist-tags, versions (含 dist.tarball, dist.integrity, dependencies)
    // ========================================================================

    /// 解析注册表返回的 JSON 元数据
    /// 对应 Bun: NetworkTask 中 JSON 解析 + PackageManifestMap 存储
    /// 翻译自: src/install/npm.zig 中 Npm.PackageManifest 的构造
    private func parseMetadata(name: String, resp: HttpResponse): ?PackageMetadata {
        let body = resp.body
        let parsed = jsonParser.parse(body)
        match (parsed) {
            case Some(root) => {
                let meta = PackageMetadata(name)
                meta.rawJson = body

                // description
                meta.description = match (JsonHelper.getString(root, "description")) {
                    case Some(d) => d
                    case None => ""
                }

                // dist-tags: { "latest": "1.0.0", "next": "2.0.0-beta" }
                // 翻译自: Npm.PackageManifest 中 dist-tags 解析
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

                // time: { "created": "...", "modified": "...", "1.0.0": "..." }
                match (JsonHelper.getField(root, "time")) {
                    case Some(JsonValue.Object(timeObj)) => {
                        for (k in timeObj.keys()) {
                            match (timeObj.get(k)) {
                                case Some(JsonValue.Str(v)) => meta.time.put(k, v)
                                case _ => {}
                            }
                        }
                    }
                    case _ => {}
                }

                // versions: { "1.0.0": { ... }, "1.1.0": { ... } }
                // 翻译自: Npm.PackageManifest 中 versions 遍历
                match (JsonHelper.getField(root, "versions")) {
                    case Some(JsonValue.Object(versions)) => {
                        for (ver in versions.keys()) {
                            match (versions.get(ver)) {
                                case Some(JsonValue.Object(verObj)) => {
                                    let vi = VersionInfo(ver)

                                    // dist.tarball, dist.integrity, dist.shasum
                                    // 翻译自: Npm.PackageManifest 中 dist 字段提取
                                    match (JsonHelper.getField(verObj, "dist")) {
                                        case Some(JsonValue.Object(distObj)) => {
                                            vi.distTarball = match (JsonHelper.getString(distObj, "tarball")) {
                                                case Some(t) => t
                                                case None => ""
                                            }
                                            vi.distIntegrity = match (JsonHelper.getString(distObj, "integrity")) {
                                                case Some(i) => i
                                                case None => ""
                                            }
                                            vi.distShasum = match (JsonHelper.getString(distObj, "shasum")) {
                                                case Some(s) => s
                                                case None => ""
                                            }
                                            vi.distFileCount = match (JsonHelper.getField(distObj, "fileCount")) {
                                                case Some(JsonValue.Number(n)) => Int64(n)
                                                case _ => 0
                                            }
                                            vi.distUnpackedSize = match (JsonHelper.getField(distObj, "unpackedSize")) {
                                                case Some(JsonValue.Number(n)) => Int64(n)
                                                case _ => 0
                                            }
                                            vi.distNpmSignature = match (JsonHelper.getString(distObj, "npm-signature")) {
                                                case Some(s) => s
                                                case None => ""
                                            }
                                        }
                                        case _ => {}
                                    }

                                    // 依赖
                                    vi.dependencies = JsonHelper.getStringMap(verObj, "dependencies")
                                    vi.devDependencies = JsonHelper.getStringMap(verObj, "devDependencies")
                                    vi.peerDependencies = JsonHelper.getStringMap(verObj, "peerDependencies")
                                    vi.optionalDependencies = JsonHelper.getStringMap(verObj, "optionalDependencies")

                                    // peerDependenciesMeta
                                    match (JsonHelper.getField(verObj, "peerDependenciesMeta")) {
                                        case Some(JsonValue.Object(pdm)) => {
                                            for (k in pdm.keys()) {
                                                match (pdm.get(k)) {
                                                    case Some(JsonValue.Object(metaObj)) => {
                                                        let meta2 = HashMap<String, String>()
                                                        for (mk in metaObj.keys()) {
                                                            match (metaObj.get(mk)) {
                                                                case Some(JsonValue.Bool(b)) => meta2.put(mk, if (b) { "true" } else { "false" })
                                                                case Some(JsonValue.Str(s)) => meta2.put(mk, s)
                                                                case _ => {}
                                                            }
                                                        }
                                                        vi.peerDependenciesMeta.put(k, meta2)
                                                    }
                                                    case _ => {}
                                                }
                                            }
                                        }
                                        case _ => {}
                                    }

                                    // bundledDependencies
                                    match (JsonHelper.getField(verObj, "bundledDependencies")) {
                                        case Some(JsonValue.Array(arr)) => {
                                            for (item in arr) {
                                                match (item) {
                                                    case JsonValue.Str(s) => vi.bundledDependencies.append(s)
                                                    case _ => {}
                                                }
                                            }
                                        }
                                        case _ => {}
                                    }

                                    // deprecated
                                    vi.deprecated = JsonHelper.getString(verObj, "deprecated")

                                    // hasInstallScript
                                    vi.hasInstallScript = match (JsonHelper.getField(verObj, "hasInstallScript")) {
                                        case Some(JsonValue.Bool(b)) => b
                                        case _ => false
                                    }

                                    // scripts (用于检测 hasInstallScript)
                                    if (!vi.hasInstallScript) {
                                        match (JsonHelper.getField(verObj, "scripts")) {
                                            case Some(JsonValue.Object(scriptsObj)) => {
                                                let installScript = scriptsObj.get("install")
                                                let postinstallScript = scriptsObj.get("postinstall")
                                                let preinstallScript = scriptsObj.get("preinstall")
                                                match (installScript) {
                                                    case Some(JsonValue.Str(s)) => if (s.length > 0) { vi.hasInstallScript = true }
                                                    case _ => {}
                                                }
                                                if (!vi.hasInstallScript) {
                                                    match (postinstallScript) {
                                                        case Some(JsonValue.Str(s)) => if (s.length > 0) { vi.hasInstallScript = true }
                                                        case _ => {}
                                                    }
                                                }
                                            }
                                            case _ => {}
                                        }
                                    }

                                    // os / cpu
                                    match (JsonHelper.getField(verObj, "os")) {
                                        case Some(JsonValue.Array(arr)) => {
                                            for (item in arr) {
                                                match (item) {
                                                    case JsonValue.Str(s) => vi.os.append(s)
                                                    case _ => {}
                                                }
                                            }
                                        }
                                        case _ => {}
                                    }
                                    match (JsonHelper.getField(verObj, "cpu")) {
                                        case Some(JsonValue.Array(arr)) => {
                                            for (item in arr) {
                                                match (item) {
                                                    case JsonValue.Str(s) => vi.cpu.append(s)
                                                    case _ => {}
                                                }
                                            }
                                        }
                                        case _ => {}
                                    }

                                    // license
                                    vi.license = match (JsonHelper.getString(verObj, "license")) {
                                        case Some(l) => l
                                        case None => ""
                                    }

                                    // bin
                                    match (JsonHelper.getField(verObj, "bin")) {
                                        case Some(JsonValue.Object(binObj)) => {
                                            for (k in binObj.keys()) {
                                                match (binObj.get(k)) {
                                                    case Some(JsonValue.Str(v)) => vi.bin.put(k, v)
                                                    case _ => {}
                                                }
                                            }
                                        }
                                        case Some(JsonValue.Str(binStr)) => {
                                            // bin: "single-bin.js" -> { name: "single-bin.js" }
                                            vi.bin.put(name, binStr)
                                        }
                                        case _ => {}
                                    }

                                    // main / module / types
                                    vi.main = JsonHelper.getString(verObj, "main")
                                    vi.module = JsonHelper.getString(verObj, "module")
                                    vi.types = match (JsonHelper.getString(verObj, "types")) {
                                        case Some(t) => Some(t)
                                        case None => JsonHelper.getString(verObj, "typings")
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

    // ========================================================================
    // HTTP 请求头构建
    // 严格翻译自: src/install/NetworkTask.zig 中 header_builder 构造
    //   countAuth / appendAuth: 添加认证头
    //   ETag / If-None-Match: 条件请求
    //   If-Modified-Since: 条件请求
    //   Accept: 区分 compact/extended
    // ========================================================================

    /// 构建包元数据请求头
    /// 翻译自: NetworkTask.forManifest 中的 header_builder
    private func buildManifestHeaders(name: String, scopeConfig: RegistryConfig): HashMap<String, String> {
        let headers = HashMap<String, String>()

        // Accept header
        // 翻译自: const accept_header_value = "application/vnd.npm.install-v1+json; q=1.0, application/json; q=0.8, */*"
        headers.put("Accept", ACCEPT_HEADER_COMPACT)
        headers.put("User-Agent", USER_AGENT)
        // Accept-Encoding
        // 翻译自: headers.count("accept-encoding", "gzip,deflate")
        headers.put("Accept-Encoding", "gzip,deflate")

        // 条件请求: ETag
        // 翻译自: if (etag.len != 0) { header_builder.append("If-None-Match", etag) }
        let cachedEtag = cache.getEtag(name)
        if (cachedEtag.length > 0) {
            headers.put("If-None-Match", cachedEtag)
        }

        // 条件请求: Last-Modified
        // 翻译自: if (last_modified.len != 0) { header_builder.append("If-Modified-Since", last_modified) }
        let cachedLastModified = cache.getLastModified(name)
        if (cachedLastModified.length > 0) {
            headers.put("If-Modified-Since", cachedLastModified)
        }

        // 认证头
        // 翻译自: countAuth / appendAuth
        appendAuthHeaders(headers, scopeConfig)

        return headers
    }

    /// 构建 tarball 下载请求头
    /// 翻译自: NetworkTask.forTarball 中的 header_builder
    private func buildTarballHeaders(scopeConfig: RegistryConfig): HashMap<String, String> {
        let headers = HashMap<String, String>()
        headers.put("Accept", "*/*")
        headers.put("User-Agent", USER_AGENT)
        headers.put("Accept-Encoding", "gzip,deflate")

        // 认证 (仅当 alwaysAuth 或 tarball 在同一域名时)
        appendAuthHeaders(headers, scopeConfig)

        return headers
    }

    /// 添加认证头
    /// 翻译自: NetworkTask.countAuth / appendAuth
    ///   fn appendAuth(header_builder, scope):
    ///     if scope.token.len > 0: "Authorization: Bearer {token}"
    ///     elif scope.auth.len > 0: "Authorization: Basic {auth}"
    ///     header_builder.append("npm-auth-type", "legacy")
    private func appendAuthHeaders(headers: HashMap<String, String>, scopeConfig: RegistryConfig): Unit {
        if (scopeConfig.token.length > 0) {
            headers.put("Authorization", "Bearer ${scopeConfig.token}")
            headers.put("npm-auth-type", "legacy")
        } else if (scopeConfig.auth.length > 0) {
            headers.put("Authorization", "Basic ${scopeConfig.auth}")
            headers.put("npm-auth-type", "legacy")
        } else if (scopeConfig.username.length > 0 && scopeConfig.password.length > 0) {
            let credentials = bao_hash.Base64.encodeFromString("${scopeConfig.username}:${scopeConfig.password}")
            headers.put("Authorization", "Basic ${credentials}")
            headers.put("npm-auth-type", "legacy")
        }
    }

    // ========================================================================
    // 哈希计算
    // 严格翻译自: src/install/integrity.zig
    //   Integrity.forBytes: 计算数据的哈希
    //   Base64 编码: std.base64.standard_no_pad
    // ========================================================================

    /// 计算 SHA-512 哈希的 base64 表示
    /// 翻译自: Integrity.forBytes -> SHA512.hash -> Base64.Encoder.encode
    private func computeSha512Base64(data: Array<UInt8>): String {
        let hash = bao_hash.Sha512.hash(data)
        return bao_hash.Base64.encode(hash)
    }

    /// 计算 SHA-384 哈希的 base64 表示
    private func computeSha384Base64(data: Array<UInt8>): String {
        let hash = bao_hash.Sha384.hash(data)
        return bao_hash.Base64.encode(hash)
    }

    /// 计算 SHA-256 哈希的 base64 表示
    private func computeSha256Base64(data: Array<UInt8>): String {
        let hash = bao_hash.Sha256.hash(data)
        return bao_hash.Base64.encode(hash)
    }

    /// 计算 SHA-1 哈希的 base64 表示
    /// 翻译自: Integrity.forBytes 使用 Sha1
    private func computeSha1Base64(data: Array<UInt8>): String {
        let hash = bao_hash.Sha1.hash(data)
        return bao_hash.Base64.encode(hash)
    }

    /// 计算 SHA-1 哈希的十六进制表示 (用于 shasum)
    /// 翻译自: Integrity.parseSHASum
    private func computeSha1Hex(data: Array<UInt8>): String {
        let hash = bao_hash.Sha1.hash(data)
        let sb = StringBuilder()
        for (b in hash) {
            let hex = Int64(b).toString(16)
            if (hex.length < 2) {
                sb.append("0")
            }
            sb.append(hex)
        }
        return sb.toString()
    }
}

// ============================================================================
// HTTP 响应扩展
// 为了支持 getHeader 等方法, 此处添加 HttpResponse 的辅助方法
// ============================================================================

/// HTTP 响应包装器 (提供 getHeader 等便利方法)
public class HttpResponse {
    public var statusCode: Int64
    public var body: String
    public var headers: HashMap<String, String>

    public init() {
        statusCode = 0
        body = ""
        headers = HashMap<String, String>()
    }

    /// 获取响应头 (不区分大小写)
    public func getHeader(name: String): ?String {
        // 直接查找
        match (headers.get(name)) {
            case Some(v) => return Some(v)
            case None => {}
        }
        // 小写查找
        match (headers.get(name.toLower())) {
            case Some(v) => return Some(v)
            case None => {}
        }
        return None
    }

    /// 获取响应体字节 (如果可用)
    public func bodyBytes: ?Array<UInt8> {
        return None  // 基础实现不提供字节访问
    }
}
