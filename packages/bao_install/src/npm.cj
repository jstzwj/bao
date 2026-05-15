// bao_install - npm 注册表交互
// 严格翻译自: src/install/npm.zig
//   pub const Npm = struct {
//       pub const Registry = struct {
//           pub const default_url = "https://registry.npmjs.org/"
//           pub const Scope = struct { name, auth, url, url_hash, token, user }
//           pub fn getPackageMetadata(...)
//       }
//   }
package bao_install

import bao_core.*
import bao_collections.*
import bao_io.*
import bao_hash.*
import bao_path.*
import bao_http.*

// ============================================================================
// 注册表默认配置
// 严格翻译自: src/install/npm.zig - Registry
//   pub const default_url = "https://registry.npmjs.org/"
// ============================================================================

/// 默认 npm 注册表 URL
/// 翻译自: Npm.Registry.default_url
public let NPM_DEFAULT_REGISTRY: String = "https://registry.npmjs.org/"

/// 默认 URL 哈希
/// 翻译自: Npm.Registry.default_url_hash = bun.Wyhash11.hash(0, ...)
public let NPM_DEFAULT_REGISTRY_HASH: UInt64 = UInt64(0)

/// 默认最大同时 HTTP 请求数
/// 翻译自: default_max_simultaneous_requests_for_bun_install = 64
public let DEFAULT_MAX_SIMULTANEOUS_REQUESTS: Int64 = 64

/// 使用代理时的最大同时 HTTP 请求数
/// 翻译自: default_max_simultaneous_requests_for_bun_install_for_proxies = 64
public let DEFAULT_MAX_SIMULTANEOUS_REQUESTS_FOR_PROXIES: Int64 = 64

// ============================================================================
// 注册表 Scope 配置
// 严格翻译自: src/install/npm.zig - Npm.Registry.Scope
//   pub const Scope = struct {
//       name: string = "",
//       auth: string = "",
//       url: URL,
//       url_hash: u64,
//       token: string = "",
//       user: string = "",
//   }
// ============================================================================

/// 注册表 Scope
/// 对应 Bun: Npm.Registry.Scope
public class NpmRegistryScope {
    /// Scope 名称 (如 "babel" from @babel/core)
    public var name: String
    /// Basic auth 编码
    public var auth: String
    /// 注册表 URL
    public var url: String
    /// URL 哈希
    public var urlHash: UInt64
    /// Bearer token
    public var token: String
    /// 用户名:密码 (原始)
    public var user: String
    /// URL 中的用户名
    public var username: String

    public init() {
        name = ""
        auth = ""
        url = NPM_DEFAULT_REGISTRY
        urlHash = hashURL(url)
        token = ""
        user = ""
        username = ""
    }

    public init(url: String) {
        name = ""
        auth = ""
        this.url = url
        urlHash = hashURL(url)
        token = ""
        user = ""
        username = ""
    }

    /// 计算 URL 哈希
    /// 翻译自: Scope.hash / String.Builder.stringHash
    public static func hashURL(url: String): UInt64 {
        var normalized = url
        if (normalized.endsWith("/")) {
            normalized = normalized.substring(0, normalized.length - 1)
        }
        return UInt64(bao_hash.Wyhash.hash(0, normalized.toByteArray()))
    }

    /// 从包名获取 scope 名称
    /// 翻译自: Scope.getName
    ///   "@babel/core" -> "babel"
    public static func getScopeName(name: String): String {
        if (name.length == 0 || name[0] != '@') { return name }
        let slashIdx = name.indexOf("/")
        match (slashIdx) {
            case Some(idx) => name.substring(1, idx)
            case None => name.substring(1)
        }
    }

    /// 是否有认证信息
    public func hasAuth(): Bool {
        return token.length > 0 || auth.length > 0
    }

    /// 构建 Authorization 头值
    /// 翻译自: NetworkTask.appendAuth
    public func authHeaderValue(): ?String {
        if (token.length > 0) {
            return "Bearer ${token}"
        }
        if (auth.length > 0) {
            return "Basic ${auth}"
        }
        return None
    }
}

// ============================================================================
// 注册表 Scope 映射
// 严格翻译自: src/install/npm.zig - Npm.Registry.Map
//   pub const Map = std.HashMapUnmanaged(u64, Scope, IdentityContext(u64), 80)
// ============================================================================

/// Scope 映射 (scope hash -> scope config)
public class NpmRegistryMap {
    private var scopes: HashMap<UInt64, NpmRegistryScope>

    public init() {
        scopes = HashMap<UInt64, NpmRegistryScope>()
    }

    /// 获取指定包名对应的 scope
    /// 翻译自: PackageManager.scopeForPackageName
    public func scopeForPackageName(name: String): NpmRegistryScope {
        if (name.length > 0 && name[0] == '@') {
            let scopeName = NpmRegistryScope.getScopeName(name)
            let scopeHash = NpmRegistryScope.hashURL(scopeName)
            match (scopes.get(scopeHash)) {
                case Some(scope) => return scope
                case None => ()
            }
        }
        // 返回默认 scope
        return NpmRegistryScope()
    }

    /// 添加 scope
    public func put(scope: NpmRegistryScope): Unit {
        scopes.put(scope.urlHash, scope)
    }

    /// 移除 scope
    public func remove(hash: UInt64): Bool {
        return scopes.remove(hash)
    }
}

// ============================================================================
// 包版本响应
// 严格翻译自: src/install/npm.zig - Registry.PackageVersionResponse
//   const PackageVersionResponse = union(Tag) {
//       pub const Tag = enum { cached, fresh, not_found }
//       cached: PackageManifest,
//       fresh: PackageManifest,
//       not_found: void,
//   }
// ============================================================================

/// 包版本响应类型
public enum PackageVersionResponseTag {
    | Cached
    | Fresh
    | NotFound
}

/// 包版本响应
/// 对应 Bun: Npm.Registry.PackageVersionResponse
public class PackageVersionResponse {
    public var tag: PackageVersionResponseTag
    public var manifest: ?PackageManifestData

    public init(tag: PackageVersionResponseTag) {
        this.tag = tag
        manifest = None
    }

    public init(manifest: PackageManifestData, isFresh: Bool) {
        if (isFresh) {
            tag = PackageVersionResponseTag.Fresh
        } else {
            tag = PackageVersionResponseTag.Cached
        }
        this.manifest = Some(manifest)
    }

    /// 从 HTTP 状态码和响应体解析
    /// 翻译自: Registry.getPackageMetadata
    public static func fromResponse(
        statusCode: Int64,
        body: String,
        packageName: String,
        loadedManifest: ?PackageManifestData,
        lastModified: String,
        etag: String,
        cacheTimestamp: Int64,
        isExtended: Bool
    ): PackageVersionResponse {
        // 翻译自: switch (response.status_code)
        if (statusCode == 400) {
            return PackageVersionResponse(PackageVersionResponseTag.NotFound)
        }
        if (statusCode == 429) {
            return PackageVersionResponse(PackageVersionResponseTag.NotFound)
        }
        if (statusCode == 404) {
            return PackageVersionResponse(PackageVersionResponseTag.NotFound)
        }
        if (statusCode >= 500) {
            return PackageVersionResponse(PackageVersionResponseTag.NotFound)
        }
        // 304 Not Modified
        if (statusCode == 304) {
            match (loadedManifest) {
                case Some(m) => return PackageVersionResponse(m, false)
                case None => return PackageVersionResponse(PackageVersionResponseTag.NotFound)
            }
        }

        // 解析 manifest
        let parsed = PackageManifestData.parseFromResponse(
            body, packageName, lastModified, etag, cacheTimestamp, isExtended
        )
        match (parsed) {
            case Some(m) => return PackageVersionResponse(m, true)
            case None => return PackageVersionResponse(PackageVersionResponseTag.NotFound)
        }
    }
}

// ============================================================================
// NPM 客户端
// 严格翻译自: src/install/npm.zig - Npm.whoami, Npm.responseError
// ============================================================================

/// NPM 客户端
/// 对应 Bun: install.Npm
public class NpmClient {
    /// 执行 whoami 请求
    /// 翻译自: Npm.whoami
    ///   向 registry 发送 GET /-/whoami 请求, 返回当前用户名
    public static func whoami(registry: NpmRegistryScope): ?String {
        // 如果 user 中有 "username:password" 格式
        if (registry.user.length > 0) {
            let sepIdx = registry.user.indexOf(":")
            match (sepIdx) {
                case Some(idx) => return registry.user.substring(0, idx)
                case None => return registry.user
            }
        }

        // URL 中的用户名
        if (registry.username.length > 0) {
            return registry.username
        }

        // 没有 token 则无法认证
        if (registry.token.length == 0) {
            return None
        }

        // 发送 HTTP 请求: GET {registry}/-/whoami
        let baseUrl = registry.url
        let sep = if (baseUrl.endsWith("/")) { "" } else { "/" }
        let whoamiUrl = "${baseUrl}${sep}-/whoami"

        try {
            let response = bao_http.HttpClient.get(whoamiUrl, [
                HttpHeader("Authorization", "Bearer ${registry.token}"),
                HttpHeader("Accept", "*/*")
            ])
            if (response.statusCode == 200) {
                let json = bao_json.JsonParser.parse(response.body)
                match (json.get("username")) {
                    case Some(u) => return u.asString()
                    case None => return None
                }
            }
            return None
        } catch (_: Exception) {
            return None
        }
    }

    /// 处理 registry 响应错误
    /// 翻译自: Npm.responseError
    public static func responseError(
        statusCode: Int64,
        statusText: String,
        url: String,
        body: String,
        packageName: ?String,
        packageVersion: ?String
    ): String {
        var message = "HTTP ${statusCode}"
        if (statusText.length > 0) {
            message = message + " ${statusText}"
        }
        // 尝试从响应体解析 error 字段
        try {
            let json = bao_json.JsonParser.parse(body)
            match (json.get("error")) {
                case Some(e) => message = message + ": ${e.asString()}"
                case None => ()
            }
        } catch (_: Exception) {
            // 无法解析 JSON, 使用原始 body
            if (body.length > 0 && body.length < 200) {
                message = message + ": ${body}"
            }
        }

        // 404 特殊处理
        if (statusCode == 404) {
            match (packageName) {
                case Some(name) => {
                    match (packageVersion) {
                        case Some(ver) => message = message + "\n - '${name}@${ver}' does not exist in this registry"
                        case None => message = message + "\n - '${name}' does not exist in this registry"
                    }
                }
                case None => ()
            }
        }

        return message
    }
}

// ============================================================================
// 可否定集合 (OS/CPU 过滤)
// 严格翻译自: src/install/npm.zig - Negatable
//   pub fn Negatable(comptime T: type) type {
//       return struct { added: T, removed: T, had_wildcard: bool, ... }
//   }
// ============================================================================

/// 可否定集合
/// 翻译自: Npm.Negatable
/// 用于 OS/CPU 兼容性过滤 (支持 "!" 前缀排除)
public class NegatableSet {
    /// 包含的值
    public var added: HashSet<String>
    /// 排除的值
    public var removed: HashSet<String>
    /// 是否有通配符
    public var hadWildcard: Bool
    /// 是否有无法识别的值
    public var hadUnrecognizedValues: Bool

    public init() {
        added = HashSet<String>()
        removed = HashSet<String>()
        hadWildcard = false
        hadUnrecognizedValues = false
    }

    /// 合并结果: 返回最终允许的集合
    /// 翻译自: Negatable.combine
    public func combine(): HashSet<String> {
        if (hadWildcard) {
            // 通配符: 所有值减去排除的
            let result = HashSet<String>()
            // all_value minus removed
            for (item in added) {
                if (!removed.contains(item)) {
                    result.add(item)
                }
            }
            return result
        }
        let result = HashSet<String>()
        for (item in added) {
            if (!removed.contains(item)) {
                result.add(item)
            }
        }
        return result
    }

    /// 添加值 (支持 "!" 前缀排除)
    public func addValue(value: String): Unit {
        if (value == "*") {
            hadWildcard = true
            return
        }
        if (value.startsWith("!")) {
            let negated = value.substring(1)
            removed.add(negated)
        } else {
            added.add(value)
        }
    }

    /// 检查给定值是否匹配
    public func matches(value: String): Bool {
        if (hadWildcard) {
            return !removed.contains(value)
        }
        return added.contains(value) && !removed.contains(value)
    }
}
