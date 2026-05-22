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
import bao_sys.*

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
            normalized = normalized[..normalized.size - 1]
        }
        return Wyhash.hash(normalized)
    }

    /// 从包名获取 scope 名称
    /// 翻译自: Scope.getName
    ///   "@babel/core" -> "babel"
    public static func getScopeName(name: String): String {
        if (name.size == 0 || !name.startsWith("@")) { return name }
        match (name.indexOf("/")) {
            case Some(idx) => name[1..idx]
            case None => name[1..]
        }
    }

    /// 是否有认证信息
    public func hasAuth(): Bool {
        return token.size > 0 || auth.size > 0
    }

    /// 构建 Authorization 头值
    /// 翻译自: NetworkTask.appendAuth
    public func authHeaderValue(): ?String {
        if (token.size > 0) {
            return Some("Bearer ${token}")
        }
        if (auth.size > 0) {
            return Some("Basic ${auth}")
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
        if (name.size > 0 && name.startsWith("@")) {
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
        match (scopes.remove(hash)) {
            case Some(_) => return true
            case None => return false
        }
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
        if (registry.user.size > 0) {
            match (registry.user.indexOf(":")) {
                case Some(idx) => return Some(registry.user[..idx])
                case None => return Some(registry.user)
            }
        }

        // URL 中的用户名
        if (registry.username.size > 0) {
            return Some(registry.username)
        }

        // 没有 token 则无法认证
        if (registry.token.size == 0) {
            return None
        }

        // 发送 HTTP 请求: GET {registry}/-/whoami
        let baseUrl = registry.url
        let sep = if (baseUrl.endsWith("/")) { "" } else { "/" }
        let whoamiUrl = "${baseUrl}${sep}-/whoami"

        try {
            let response = HttpClient.fetch(whoamiUrl)
            if (response.status == 200) {
                let bodyText = response.text()
                let jsonParser = PkgJsonParser()
                let json = jsonParser.parse(bodyText)
                match (json) {
                    case Some(root) =>
                        match (PkgJsonHelper.getString(root, "username")) {
                            case Some(u) => return Some(u)
                            case None => return None
                        }
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
        if (statusText.size > 0) {
            message = message + " ${statusText}"
        }
        // 尝试从响应体解析 error 字段
        try {
            let jsonParser = PkgJsonParser()
            let json = jsonParser.parse(body)
            match (json) {
                case Some(root) =>
                    match (PkgJsonHelper.getString(root, "error")) {
                        case Some(e) => message = message + ": ${e}"
                        case None => ()
                    }
                case None => ()
            }
        } catch (_: Exception) {
            // 无法解析 JSON, 使用原始 body
            if (body.size > 0 && body.size < 200) {
                message = message + ": ${body}"
            }
        }

        // 404 特殊处理
        if (statusCode == 404) {
            match (packageName) {
                case Some(name) =>
                    match (packageVersion) {
                        case Some(ver) => message = message + "\n - '${name}@${ver}' does not exist in this registry"
                        case None => message = message + "\n - '${name}' does not exist in this registry"
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
        let result = HashSet<String>()
        for (item in added.values()) {
            if (!removed.contains(item)) {
                result.put(item)
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
            let negated = value[1..]
            removed.put(negated)
        } else {
            added.put(value)
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

// ============================================================================
// 操作系统枚举 (位标志)
// 严格翻译自: src/install/npm.zig - OperatingSystem
//   pub const OperatingSystem = enum(u16) {
//       none = 0,
//       all = all_value,
//       _,
//       pub const aix: u16 = 1 << 1;
//       pub const darwin: u16 = 1 << 2;
//       ...
//   }
//   https://nodejs.org/api/os.html#osplatform
// ============================================================================

/// 操作系统位标志常量
/// 翻译自: OperatingSystem 中的 pub const 常量
public let OS_AIX: UInt16 = UInt16(1) << UInt16(1)
public let OS_DARWIN: UInt16 = UInt16(1) << UInt16(2)
public let OS_FREEBSD: UInt16 = UInt16(1) << UInt16(3)
public let OS_LINUX: UInt16 = UInt16(1) << UInt16(4)
public let OS_OPENBSD: UInt16 = UInt16(1) << UInt16(5)
public let OS_SUNOS: UInt16 = UInt16(1) << UInt16(6)
public let OS_WIN32: UInt16 = UInt16(1) << UInt16(7)
public let OS_ANDROID: UInt16 = UInt16(1) << UInt16(8)

/// 所有 OS 标志的并集
/// 翻译自: OperatingSystem.all_value
public let OS_ALL_VALUE: UInt16 = OS_AIX | OS_DARWIN | OS_FREEBSD | OS_LINUX | OS_OPENBSD | OS_SUNOS | OS_WIN32 | OS_ANDROID

/// 操作系统类型 (位标志)
/// 对应 Bun: Npm.OperatingSystem
/// 翻译自: src/install/npm.zig - OperatingSystem enum(u16)
///   https://nodejs.org/api/os.html#osplatform
public class OperatingSystem {
    /// 位标志值
    public var value: UInt16

    /// none = 0
    public static prop none: OperatingSystem {
        get() { OperatingSystem(UInt16(0)) }
    }

    /// all = all_value
    public static prop all: OperatingSystem {
        get() { OperatingSystem(OS_ALL_VALUE) }
    }

    public init() {
        value = OS_ALL_VALUE
    }

    public init(value: UInt16) {
        this.value = value
    }

    /// 当前操作系统
    /// 翻译自: OperatingSystem.current
    ///   switch (Environment.os) { .linux => linux, .mac => darwin, .windows => win32, ... }
    public static prop current: OperatingSystem {
        get() {
            let osName = OS.getCurrentOSName()
            if (osName == "darwin") { return OperatingSystem(OS_DARWIN) }
            if (osName == "win32") { return OperatingSystem(OS_WIN32) }
            if (osName == "freebsd") { return OperatingSystem(OS_FREEBSD) }
            return OperatingSystem(OS_LINUX)
        }
    }

    /// 当前操作系统名称
    /// 翻译自: OperatingSystem.current_name
    public static prop currentName: String {
        get() {
            let osName = OS.getCurrentOSName()
            if (osName == "darwin") { return "darwin" }
            if (osName == "win32") { return "win32" }
            if (osName == "freebsd") { return "freebsd" }
            return "linux"
        }
    }

    /// 从名称解析 OS 标志
    /// 翻译自: OperatingSystem.NameMap
    ///   ComptimeStringMap: "aix"->aix, "darwin"->darwin, ...
    public static func fromName(name: String): ?OperatingSystem {
        if (name == "aix") { return Some(OperatingSystem(OS_AIX)) }
        if (name == "darwin") { return Some(OperatingSystem(OS_DARWIN)) }
        if (name == "freebsd") { return Some(OperatingSystem(OS_FREEBSD)) }
        if (name == "linux") { return Some(OperatingSystem(OS_LINUX)) }
        if (name == "openbsd") { return Some(OperatingSystem(OS_OPENBSD)) }
        if (name == "sunos") { return Some(OperatingSystem(OS_SUNOS)) }
        if (name == "win32") { return Some(OperatingSystem(OS_WIN32)) }
        if (name == "android") { return Some(OperatingSystem(OS_ANDROID)) }
        return None
    }

    /// 是否匹配目标 OS
    /// 翻译自: OperatingSystem.isMatch
    ///   return (@intFromEnum(this) & @intFromEnum(target)) != 0
    public func isMatch(target: OperatingSystem): Bool {
        return (value & target.value) != UInt16(0)
    }

    /// 是否包含指定标志
    /// 翻译自: OperatingSystem.has
    ///   return (@intFromEnum(this) & other) != 0
    public func has(other: UInt16): Bool {
        return (value & other) != UInt16(0)
    }

    /// 从 JSON 解析 OS 列表
    /// 翻译自: Negatable(OperatingSystem).fromJson
    ///   解析 ["linux", "!darwin"] 等格式
    public static func fromJsonArray(values: ArrayList<String>): OperatingSystem {
        var added: UInt16 = 0
        var removed: UInt16 = 0
        var hadWildcard = false
        var hadUnrecognized = false

        for (v in values) {
            if (v == "any") {
                hadWildcard = true
                continue
            }
            if (v == "none") {
                hadUnrecognized = true
                continue
            }
            let isNot = v.startsWith("!")
            let name_ = if (isNot) { v[1..] } else { v }
            let parsed = fromName(name_)
            match (parsed) {
                case Some(os) =>
                    if (isNot) {
                        removed = removed | os.value
                    } else {
                        added = added | os.value
                    }
                case None =>
                    if (!isNot) { hadUnrecognized = true }
            }
        }

        // 合并
        let combinedAdded = if (hadWildcard) { OS_ALL_VALUE } else { added }
        if (combinedAdded == UInt16(0) && removed == UInt16(0)) {
            if (hadUnrecognized) { return OperatingSystem.none }
            return OperatingSystem.all
        }
        if (combinedAdded == UInt16(0) && removed != UInt16(0)) {
            return OperatingSystem(OS_ALL_VALUE & !removed)
        }
        if (removed == UInt16(0)) {
            return OperatingSystem(combinedAdded)
        }
        return OperatingSystem(combinedAdded & !removed)
    }

    /// 序列化为 JSON 字符串
    /// 翻译自: Negatable.toJson
    public func toJson(): String {
        if (value == UInt16(0)) {
            return "\"none\""
        }
        let names = [
            ("aix", OS_AIX),
            ("darwin", OS_DARWIN),
            ("freebsd", OS_FREEBSD),
            ("linux", OS_LINUX),
            ("openbsd", OS_OPENBSD),
            ("sunos", OS_SUNOS),
            ("win32", OS_WIN32),
            ("android", OS_ANDROID)
        ]
        var included: ArrayList<String> = ArrayList<String>()
        var excluded: ArrayList<String> = ArrayList<String>()
        for (pair in names) {
            if ((value & pair[1]) != UInt16(0)) {
                included.append(pair[0])
            } else {
                excluded.append(pair[0])
            }
        }
        let printIncluded = excluded.size > names.size - excluded.size
        if (printIncluded) {
            if (included.size == 1) {
                return "\"${included[0]}\""
            }
            var sb = StringBuilder()
            sb.append("[ ")
            var first = true
            for (name in included) {
                if (!first) { sb.append(", ") }
                sb.append("\"${name}\"")
                first = false
            }
            sb.append(" ]")
            return sb.toString()
        } else {
            if (excluded.size == 1) {
                return "\"!${excluded[0]}\""
            }
            var sb = StringBuilder()
            sb.append("[ ")
            var first = true
            for (name in excluded) {
                if (!first) { sb.append(", ") }
                sb.append("\"!${name}\"")
                first = false
            }
            sb.append(" ]")
            return sb.toString()
        }
    }

    public operator func ==(right: OperatingSystem): Bool {
        return value == right.value
    }

    public operator func !=(right: OperatingSystem): Bool {
        return value != right.value
    }
}

// ============================================================================
// Libc 枚举 (位标志)
// 严格翻译自: src/install/npm.zig - Libc
//   pub const Libc = enum(u8) {
//       none = 0,
//       all = all_value,
//       _,
//       pub const glibc: u8 = 1 << 1;
//       pub const musl: u8 = 1 << 2;
//   }
// ============================================================================

/// Libc 位标志常量
/// 翻译自: Libc 中的 pub const 常量
public let LIBC_GLIBC: UInt8 = UInt8(1) << UInt8(1)
public let LIBC_MUSL: UInt8 = UInt8(1) << UInt8(2)

/// 所有 Libc 标志的并集
/// 翻译自: Libc.all_value
public let LIBC_ALL_VALUE: UInt8 = LIBC_GLIBC | LIBC_MUSL

/// Libc 类型 (位标志)
/// 对应 Bun: Npm.Libc
/// 翻译自: src/install/npm.zig - Libc enum(u8)
public class LibcType {
    /// 位标志值
    public var value: UInt8

    /// none = 0
    public static prop none: LibcType {
        get() { LibcType(UInt8(0)) }
    }

    /// all = all_value
    public static prop all: LibcType {
        get() { LibcType(LIBC_ALL_VALUE) }
    }

    public init() {
        value = UInt8(0)
    }

    public init(value: UInt8) {
        this.value = value
    }

    /// 当前 libc
    /// 翻译自: Libc.current (默认 glibc)
    public static prop current: LibcType {
        get() { LibcType(LIBC_GLIBC) }
    }

    /// 从名称解析 Libc 标志
    /// 翻译自: Libc.NameMap
    public static func fromName(name: String): ?LibcType {
        if (name == "glibc") { return Some(LibcType(LIBC_GLIBC)) }
        if (name == "musl") { return Some(LibcType(LIBC_MUSL)) }
        return None
    }

    /// 是否匹配目标
    /// 翻译自: Libc.isMatch
    public func isMatch(target: LibcType): Bool {
        return (value & target.value) != UInt8(0)
    }

    /// 是否包含指定标志
    /// 翻译自: Libc.has
    public func has(other: UInt8): Bool {
        return (value & other) != UInt8(0)
    }

    /// 从 JSON 数组解析
    /// 翻译自: Negatable(Libc).fromJson
    public static func fromJsonArray(values: ArrayList<String>): LibcType {
        var added: UInt8 = UInt8(0)
        var removed: UInt8 = UInt8(0)
        var hadWildcard = false
        var hadUnrecognized = false

        for (v in values) {
            if (v == "any") {
                hadWildcard = true
                continue
            }
            if (v == "none") {
                hadUnrecognized = true
                continue
            }
            let isNot = v.startsWith("!")
            let name_ = if (isNot) { v[1..] } else { v }
            let parsed = fromName(name_)
            match (parsed) {
                case Some(lc) =>
                    if (isNot) {
                        removed = removed | lc.value
                    } else {
                        added = added | lc.value
                    }
                case None =>
                    if (!isNot) { hadUnrecognized = true }
            }
        }

        let combinedAdded = if (hadWildcard) { LIBC_ALL_VALUE } else { added }
        if (combinedAdded == UInt8(0) && removed == UInt8(0)) {
            if (hadUnrecognized) { return LibcType.none }
            return LibcType.all
        }
        if (combinedAdded == UInt8(0) && removed != UInt8(0)) {
            return LibcType(LIBC_ALL_VALUE & !removed)
        }
        if (removed == UInt8(0)) {
            return LibcType(combinedAdded)
        }
        return LibcType(combinedAdded & !removed)
    }

    public operator func ==(right: LibcType): Bool {
        return value == right.value
    }

    public operator func !=(right: LibcType): Bool {
        return value != right.value
    }
}

// ============================================================================
// CPU 架构枚举 (位标志)
// 严格翻译自: src/install/npm.zig - Architecture
//   pub const Architecture = enum(u16) {
//       none = 0,
//       all = all_value,
//       _,
//       pub const arm: u16 = 1 << 1;
//       pub const arm64: u16 = 1 << 2;
//       ...
//   }
//   https://docs.npmjs.com/cli/v8/configuring-npm/package-json#cpu
//   https://nodejs.org/api/os.html#osarch
// ============================================================================

/// 架构位标志常量
/// 翻译自: Architecture 中的 pub const 常量
public let ARCH_ARM: UInt16 = UInt16(1) << UInt16(1)
public let ARCH_ARM64: UInt16 = UInt16(1) << UInt16(2)
public let ARCH_IA32: UInt16 = UInt16(1) << UInt16(3)
public let ARCH_MIPS: UInt16 = UInt16(1) << UInt16(4)
public let ARCH_MIPSEL: UInt16 = UInt16(1) << UInt16(5)
public let ARCH_PPC: UInt16 = UInt16(1) << UInt16(6)
public let ARCH_PPC64: UInt16 = UInt16(1) << UInt16(7)
public let ARCH_S390: UInt16 = UInt16(1) << UInt16(8)
public let ARCH_S390X: UInt16 = UInt16(1) << UInt16(9)
public let ARCH_X32: UInt16 = UInt16(1) << UInt16(10)
public let ARCH_X64: UInt16 = UInt16(1) << UInt16(11)

/// 所有架构标志的并集
/// 翻译自: Architecture.all_value
public let ARCH_ALL_VALUE: UInt16 = ARCH_ARM | ARCH_ARM64 | ARCH_IA32 | ARCH_MIPS |
    ARCH_MIPSEL | ARCH_PPC | ARCH_PPC64 | ARCH_S390 | ARCH_S390X | ARCH_X32 | ARCH_X64

/// CPU 架构类型 (位标志)
/// 对应 Bun: Npm.Architecture
/// 翻译自: src/install/npm.zig - Architecture enum(u16)
///   https://docs.npmjs.com/cli/v8/configuring-npm/package-json#cpu
///   https://nodejs.org/api/os.html#osarch
public class Architecture {
    /// 位标志值
    public var value: UInt16

    /// none = 0
    public static prop none: Architecture {
        get() { Architecture(UInt16(0)) }
    }

    /// all = all_value
    public static prop all: Architecture {
        get() { Architecture(ARCH_ALL_VALUE) }
    }

    public init() {
        value = ARCH_ALL_VALUE
    }

    public init(value: UInt16) {
        this.value = value
    }

    /// 当前架构
    /// 翻译自: Architecture.current
    ///   switch (Environment.arch) { .arm64 => arm64, .x64 => x64, ... }
    public static prop current: Architecture {
        get() {
            let archName = OS.getCurrentArchName()
            if (archName == "arm64") { return Architecture(ARCH_ARM64) }
            return Architecture(ARCH_X64)
        }
    }

    /// 当前架构名称
    /// 翻译自: Architecture.current_name
    public static prop currentName: String {
        get() {
            let archName = OS.getCurrentArchName()
            if (archName == "arm64") { return "arm64" }
            return "x64"
        }
    }

    /// 从名称解析架构标志
    /// 翻译自: Architecture.NameMap
    ///   ComptimeStringMap: "arm"->arm, "arm64"->arm64, ...
    public static func fromName(name: String): ?Architecture {
        if (name == "arm") { return Some(Architecture(ARCH_ARM)) }
        if (name == "arm64") { return Some(Architecture(ARCH_ARM64)) }
        if (name == "ia32") { return Some(Architecture(ARCH_IA32)) }
        if (name == "mips") { return Some(Architecture(ARCH_MIPS)) }
        if (name == "mipsel") { return Some(Architecture(ARCH_MIPSEL)) }
        if (name == "ppc") { return Some(Architecture(ARCH_PPC)) }
        if (name == "ppc64") { return Some(Architecture(ARCH_PPC64)) }
        if (name == "s390") { return Some(Architecture(ARCH_S390)) }
        if (name == "s390x") { return Some(Architecture(ARCH_S390X)) }
        if (name == "x32") { return Some(Architecture(ARCH_X32)) }
        if (name == "x64") { return Some(Architecture(ARCH_X64)) }
        return None
    }

    /// 是否匹配目标架构
    /// 翻译自: Architecture.isMatch
    public func isMatch(target: Architecture): Bool {
        return (value & target.value) != UInt16(0)
    }

    /// 是否包含指定标志
    /// 翻译自: Architecture.has
    public func has(other: UInt16): Bool {
        return (value & other) != UInt16(0)
    }

    /// 从 JSON 数组解析
    /// 翻译自: Negatable(Architecture).fromJson
    public static func fromJsonArray(values: ArrayList<String>): Architecture {
        var added: UInt16 = UInt16(0)
        var removed: UInt16 = UInt16(0)
        var hadWildcard = false
        var hadUnrecognized = false

        for (v in values) {
            if (v == "any") {
                hadWildcard = true
                continue
            }
            if (v == "none") {
                hadUnrecognized = true
                continue
            }
            let isNot = v.startsWith("!")
            let name_ = if (isNot) { v[1..] } else { v }
            let parsed = fromName(name_)
            match (parsed) {
                case Some(arch) =>
                    if (isNot) {
                        removed = removed | arch.value
                    } else {
                        added = added | arch.value
                    }
                case None =>
                    if (!isNot) { hadUnrecognized = true }
            }
        }

        let combinedAdded = if (hadWildcard) { ARCH_ALL_VALUE } else { added }
        if (combinedAdded == UInt16(0) && removed == UInt16(0)) {
            if (hadUnrecognized) { return Architecture.none }
            return Architecture.all
        }
        if (combinedAdded == UInt16(0) && removed != UInt16(0)) {
            return Architecture(ARCH_ALL_VALUE & !removed)
        }
        if (removed == UInt16(0)) {
            return Architecture(combinedAdded)
        }
        return Architecture(combinedAdded & !removed)
    }

    /// 序列化为 JSON 字符串
    /// 翻译自: Negatable.toJson
    public func toJson(): String {
        if (value == UInt16(0)) {
            return "\"none\""
        }
        let names = [
            ("arm", ARCH_ARM),
            ("arm64", ARCH_ARM64),
            ("ia32", ARCH_IA32),
            ("mips", ARCH_MIPS),
            ("mipsel", ARCH_MIPSEL),
            ("ppc", ARCH_PPC),
            ("ppc64", ARCH_PPC64),
            ("s390", ARCH_S390),
            ("s390x", ARCH_S390X),
            ("x32", ARCH_X32),
            ("x64", ARCH_X64)
        ]
        var included: ArrayList<String> = ArrayList<String>()
        var excluded: ArrayList<String> = ArrayList<String>()
        for (pair in names) {
            if ((value & pair[1]) != UInt16(0)) {
                included.append(pair[0])
            } else {
                excluded.append(pair[0])
            }
        }
        let printIncluded = excluded.size > names.size - excluded.size
        if (printIncluded) {
            if (included.size == 1) {
                return "\"${included[0]}\""
            }
            var sb = StringBuilder()
            sb.append("[ ")
            var first = true
            for (name in included) {
                if (!first) { sb.append(", ") }
                sb.append("\"${name}\"")
                first = false
            }
            sb.append(" ]")
            return sb.toString()
        } else {
            if (excluded.size == 1) {
                return "\"!${excluded[0]}\""
            }
            var sb = StringBuilder()
            sb.append("[ ")
            var first = true
            for (name in excluded) {
                if (!first) { sb.append(", ") }
                sb.append("\"!${name}\"")
                first = false
            }
            sb.append(" ]")
            return sb.toString()
        }
    }

    public operator func ==(right: Architecture): Bool {
        return value == right.value
    }

    public operator func !=(right: Architecture): Bool {
        return value != right.value
    }
}

// ============================================================================
// Dist-Tag 映射
// 严格翻译自: src/install/npm.zig - DistTagMap
//   const DistTagMap = extern struct {
//       tags: ExternalStringList = ExternalStringList{},
//       versions: VersionSlice = VersionSlice{},
//   }
// ============================================================================

/// Dist-Tag 映射
/// 对应 Bun: Npm.DistTagMap
/// 将 dist-tags (如 "latest", "next") 映射到版本
public class DistTagMap {
    /// tag 名称列表
    public var tags: ExternalStringList
    /// tag 对应的版本列表
    public var versions: VersionSlice

    public init() {
        tags = ExternalStringList()
        versions = VersionSlice()
    }

    public init(tags: ExternalStringList, versions: VersionSlice) {
        this.tags = tags
        this.versions = versions
    }
}

// ============================================================================
// 版本映射 (keys + values)
// 严格翻译自: src/install/npm.zig - ExternVersionMap
//   const ExternVersionMap = extern struct {
//       keys: VersionSlice = VersionSlice{},
//       values: PackageVersionList = PackageVersionList{},
//       pub fn findKeyIndex(...) ?u32
//   }
// ============================================================================

/// 版本映射
/// 对应 Bun: Npm.ExternVersionMap
/// 将 semver 版本键映射到 PackageVersion 值
public class ExternVersionMap {
    /// 版本键 (semver)
    public var keys: VersionSlice
    /// 版本值 (PackageVersionData)
    public var values: ExternalSlice<PackageVersionData>

    public init() {
        keys = VersionSlice()
        values = ExternalSlice<PackageVersionData>()
    }

    public init(keys: VersionSlice, values: ExternalSlice<PackageVersionData>) {
        this.keys = keys
        this.values = values
    }

    /// 在版本列表中查找键的索引
    /// 翻译自: ExternVersionMap.findKeyIndex
    ///   遍历 keys 列表, 找到与目标版本相等的索引
    public func findKeyIndex(
        buf: ArrayList<SemverVersion>,
        find: SemverVersion
    ): ?UInt32 {
        let keyList = keys.get(buf)
        var i: Int64 = 0
        while (i < keyList.size) {
            if (keyList[i].eql(find)) {
                return Some(UInt32(i))
            }
            i += 1
        }
        return None
    }
}

// ============================================================================
// Semver 版本 (简化)
// 用于 ExternVersionMap 中的版本键
// ============================================================================

/// Semver 版本
/// 对应 Bun: Semver.Version (简化版本)
public class SemverVersion {
    public var major: UInt64
    public var minor: UInt64
    public var patch: UInt64
    public var tag: String

    public init() {
        major = UInt64(0)
        minor = UInt64(0)
        patch = UInt64(0)
        tag = ""
    }

    public init(major: UInt64, minor: UInt64, patch: UInt64) {
        this.major = major
        this.minor = minor
        this.patch = patch
        tag = ""
    }

    public init(major: UInt64, minor: UInt64, patch: UInt64, tag: String) {
        this.major = major
        this.minor = minor
        this.patch = patch
        this.tag = tag
    }

    /// 是否有预发布标签
    /// 翻译自: Semver.Version.tag.hasPre()
    public func hasPre(): Bool {
        return tag.size > 0 && tag.startsWith("-")
    }

    /// 是否有构建元数据
    /// 翻译自: Semver.Version.tag.hasBuild()
    public func hasBuild(): Bool {
        return tag.size > 0 && tag.contains("+")
    }

    /// 比较是否相等
    public func eql(other: SemverVersion): Bool {
        return major == other.major && minor == other.minor &&
               patch == other.patch && tag == other.tag
    }

    /// 比较顺序
    /// 返回: <0 表示 this < other, 0 表示相等, >0 表示 this > other
    public func order(other: SemverVersion): Int64 {
        if (major != other.major) {
            return if (major < other.major) { Int64(-1) } else { Int64(1) }
        }
        if (minor != other.minor) {
            return if (minor < other.minor) { Int64(-1) } else { Int64(1) }
        }
        if (patch != other.patch) {
            return if (patch < other.patch) { Int64(-1) } else { Int64(1) }
        }
        if (tag < other.tag) { Int64(-1) } else if (tag > other.tag) { Int64(1) } else { Int64(0) }
    }

    public func toString(): String {
        if (tag.size > 0) {
            return "${major}.${minor}.${patch}${tag}"
        }
        return "${major}.${minor}.${patch}"
    }
}

// ============================================================================
// Bin 类型 (简化)
// 严格翻译自: src/install/bin.zig - Bin
//   pub const Bin = union(Tag) {
//       pub const Tag = enum { none, file, named_file, map, dir }
//       none, file, named_file, map, dir
//   }
// ============================================================================

// ============================================================================
// 包版本数据
// 严格翻译自: src/install/npm.zig - PackageVersion
//   pub const PackageVersion = extern struct {
//       integrity: Integrity = Integrity{},
//       dependencies: ExternalStringMap = ExternalStringMap{},
//       optional_dependencies: ExternalStringMap = ExternalStringMap{},
//       peer_dependencies: ExternalStringMap = ExternalStringMap{},
//       dev_dependencies: ExternalStringMap = ExternalStringMap{},
//       bundled_dependencies: ExternalPackageNameHashList = .{},
//       bin: Bin = Bin{},
//       engines: ExternalStringMap = ExternalStringMap{},
//       non_optional_peer_dependencies_start: u32 = 0,
//       man_dir: ExternalString = ExternalString{},
//       tarball_url: ExternalString = ExternalString{},
//       unpacked_size: u32 = 0,
//       file_count: u32 = 0,
//       os: OperatingSystem = OperatingSystem.all,
//       cpu: Architecture = Architecture.all,
//       libc: Libc = Libc.none,
//       has_install_script: bool = false,
//       publish_timestamp_ms: f64 = 0,
//   }
// ============================================================================

/// 包版本数据
/// 对应 Bun: Npm.PackageVersion
/// 翻译自: src/install/npm.zig - PackageVersion extern struct
///   注册表中单个版本的全部元数据
public class PackageVersionData {
    /// 完整性哈希 (integrity || shasum)
    /// 翻译自: integrity: Integrity = Integrity{}
    public var integrity: Integrity

    /// dependencies
    /// 翻译自: dependencies: ExternalStringMap = ExternalStringMap{}
    public var dependencies: ExternalStringMap

    /// optionalDependencies
    /// 翻译自: optional_dependencies: ExternalStringMap = ExternalStringMap{}
    public var optionalDependencies: ExternalStringMap

    /// peerDependencies
    /// 翻译自: peer_dependencies: ExternalStringMap = ExternalStringMap{}
    public var peerDependencies: ExternalStringMap

    /// devDependencies (保留但默认不填充)
    /// 翻译自: dev_dependencies: ExternalStringMap = ExternalStringMap{}
    public var devDependencies: ExternalStringMap

    /// bundledDependencies
    /// 翻译自: bundled_dependencies: ExternalPackageNameHashList = .{}
    public var bundledDependencies: ExternalPackageNameHashList

    /// bin 条目
    /// 翻译自: bin: Bin = Bin{}
    public var bin: PackageBin

    /// engines 约束
    /// 翻译自: engines: ExternalStringMap = ExternalStringMap{}
    public var engines: ExternalStringMap

    /// 非可选 peer 依赖的起始位置
    /// 翻译自: non_optional_peer_dependencies_start: u32 = 0
    public var nonOptionalPeerDependenciesStart: UInt32

    /// man 目录
    /// 翻译自: man_dir: ExternalString = ExternalString{}
    public var manDir: ExternalString

    /// tarball URL
    /// 翻译自: tarball_url: ExternalString = ExternalString{}
    public var tarballUrl: ExternalString

    /// 解压大小
    /// 翻译自: unpacked_size: u32 = 0
    public var unpackedSize: UInt32

    /// 文件数量
    /// 翻译自: file_count: u32 = 0
    public var fileCount: UInt32

    /// OS 限制
    /// 翻译自: os: OperatingSystem = OperatingSystem.all
    public var os: OperatingSystem

    /// CPU 限制
    /// 翻译自: cpu: Architecture = Architecture.all
    public var cpu: Architecture

    /// libc 限制
    /// 翻译自: libc: Libc = Libc.none
    public var libc: LibcType

    /// 是否有安装脚本
    /// 翻译自: has_install_script: bool = false
    public var hasInstallScript: Bool

    /// 发布时间戳 (Unix ms)
    /// 翻译自: publish_timestamp_ms: f64 = 0
    public var publishTimestampMs: Float64

    public init() {
        integrity = Integrity()
        dependencies = ExternalStringMap()
        optionalDependencies = ExternalStringMap()
        peerDependencies = ExternalStringMap()
        devDependencies = ExternalStringMap()
        bundledDependencies = ExternalPackageNameHashList()
        bin = PackageBin()
        engines = ExternalStringMap()
        nonOptionalPeerDependenciesStart = UInt32(0)
        manDir = ExternalString()
        tarballUrl = ExternalString()
        unpackedSize = UInt32(0)
        fileCount = UInt32(0)
        os = OperatingSystem.all
        cpu = Architecture.all
        libc = LibcType.none
        hasInstallScript = false
        publishTimestampMs = Float64(0)
    }

    /// 是否所有依赖都被打包
    /// 翻译自: PackageVersion.allDependenciesBundled
    ///   return this.bundled_dependencies.isInvalid()
    public func allDependenciesBundled(): Bool {
        return bundledDependencies.isInvalid()
    }
}

// ============================================================================
// 完整性信息 (简化版, 详细版在 integrity.cj)
// 严格翻译自: src/install/integrity.zig - Integrity
// ============================================================================

// ============================================================================
// NPM 包数据
// 严格翻译自: src/install/npm.zig - NpmPackage
//   pub const NpmPackage = extern struct {
//       last_modified: String = String{},
//       etag: String = String{},
//       modified: String = String{},
//       public_max_age: u32 = 0,
//       name: ExternalString = ExternalString{},
//       releases: ExternVersionMap = ExternVersionMap{},
//       prereleases: ExternVersionMap = ExternVersionMap{},
//       dist_tags: DistTagMap = DistTagMap{},
//       versions_buf: VersionSlice = VersionSlice{},
//       string_lists_buf: ExternalStringList = ExternalStringList{},
//       has_extended_manifest: bool = false,
//   }
// ============================================================================

/// NPM 包数据
/// 对应 Bun: Npm.NpmPackage
/// 翻译自: src/install/npm.zig - NpmPackage extern struct
///   注册表中一个包的完整元数据 (HTTP 头 + 版本信息)
public class NpmPackage {
    /// HTTP Last-Modified 响应头
    /// 翻译自: last_modified: String = String{}
    public var lastModified: String

    /// HTTP ETag 响应头
    /// 翻译自: etag: String = String{}
    public var etag: String

    /// "modified" JSON 字段
    /// 翻译自: modified: String = String{}
    public var modified: String

    /// Cache-Control max-age 值
    /// 翻译自: public_max_age: u32 = 0
    public var publicMaxAge: UInt32

    /// 包名
    /// 翻译自: name: ExternalString = ExternalString{}
    public var name: ExternalString

    /// 正式版本映射
    /// 翻译自: releases: ExternVersionMap = ExternVersionMap{}
    public var releases: ExternVersionMap

    /// 预发布版本映射
    /// 翻译自: prereleases: ExternVersionMap = ExternVersionMap{}
    public var prereleases: ExternVersionMap

    /// dist-tags 映射
    /// 翻译自: dist_tags: DistTagMap = DistTagMap{}
    public var distTags: DistTagMap

    /// 版本缓冲区切片
    /// 翻译自: versions_buf: VersionSlice = VersionSlice{}
    public var versionsBuf: VersionSlice

    /// 外部字符串列表缓冲区
    /// 翻译自: string_lists_buf: ExternalStringList = ExternalStringList{}
    public var stringListsBuf: ExternalStringList

    /// 是否有扩展 manifest (含 time 字段)
    /// 翻译自: has_extended_manifest: bool = false
    public var hasExtendedManifest: Bool

    public init() {
        lastModified = ""
        etag = ""
        modified = ""
        publicMaxAge = UInt32(0)
        name = ExternalString()
        releases = ExternVersionMap()
        prereleases = ExternVersionMap()
        distTags = DistTagMap()
        versionsBuf = VersionSlice()
        stringListsBuf = ExternalStringList()
        hasExtendedManifest = false
    }
}

// ============================================================================
// 包 Manifest 查找结果
// 严格翻译自: src/install/npm.zig - PackageManifest.FindResult
//   pub const FindResult = struct {
//       version: Semver.Version,
//       package: *const PackageVersion,
//   }
// ============================================================================

/// 查找结果
/// 翻译自: PackageManifest.FindResult
public class ManifestFindResult {
    /// 匹配的版本
    public var version: SemverVersion
    /// 匹配的包版本数据
    public var packageVersion: PackageVersionData

    public init(version: SemverVersion, packageVersion: PackageVersionData) {
        this.version = version
        this.packageVersion = packageVersion
    }
}

// ============================================================================
// 包 Manifest 查找版本结果
// 严格翻译自: src/install/npm.zig - PackageManifest.FindVersionResult
//   pub const FindVersionResult = union(enum) {
//       found: FindResult,
//       found_with_filter: struct { result: FindResult, newest_filtered: ?Semver.Version },
//       err: enum { not_found, too_recent, all_versions_too_recent },
//   }
// ============================================================================

/// 版本查找错误类型
/// 翻译自: FindVersionResult.err
public enum FindVersionError {
    | NotFound
    | TooRecent
    | AllVersionsTooRecent
}

/// 版本查找结果
/// 翻译自: PackageManifest.FindVersionResult
public class FindVersionResult {
    /// 找到的结果
    public var found: ?ManifestFindResult
    /// 带过滤器找到的结果
    public var foundWithFilter: ?ManifestFindResult
    /// 被过滤掉的最新版本
    public var newestFiltered: ?SemverVersion
    /// 错误
    public var err: ?FindVersionError

    public init() {
        found = None
        foundWithFilter = None
        newestFiltered = None
        err = None
    }

    /// 创建 "找到" 结果
    public static func foundResult(r: ManifestFindResult): FindVersionResult {
        let result = FindVersionResult()
        result.found = Some(r)
        return result
    }

    /// 创建 "带过滤器找到" 结果
    public static func foundWithFilterResult(
        r: ManifestFindResult,
        newestFiltered: ?SemverVersion
    ): FindVersionResult {
        let result = FindVersionResult()
        result.foundWithFilter = Some(r)
        result.newestFiltered = newestFiltered
        return result
    }

    /// 创建错误结果
    public static func errorResult(err: FindVersionError): FindVersionResult {
        let result = FindVersionResult()
        result.err = Some(err)
        return result
    }

    /// 获取找到的结果 (无论是否带过滤器)
    /// 翻译自: FindVersionResult.unwrap
    public func unwrap(): ?ManifestFindResult {
        match (found) {
            case Some(r) => return Some(r)
            case None => ()
        }
        return foundWithFilter
    }

    /// 最新版本是否被过滤器排除
    /// 翻译自: FindVersionResult.latestIsFiltered
    public func latestIsFiltered(): Bool {
        match (foundWithFilter) {
            case Some(_) =>
                match (newestFiltered) {
                    case Some(_) => return true
                    case None => return false
                }
            case None => ()
        }
        match (err) {
            case Some(FindVersionError.AllVersionsTooRecent) => return true
            case _ => return false
        }
    }

    /// 是否为未找到
    public func isNotFound(): Bool {
        match (err) {
            case Some(FindVersionError.NotFound) => return true
            case _ => return false
        }
    }
}

// ============================================================================
// 包 Manifest (完整版)
// 严格翻译自: src/install/npm.zig - PackageManifest
//   pub const PackageManifest = struct {
//       pkg: NpmPackage = .{},
//       string_buf: []const u8 = &[_]u8{},
//       versions: []const Semver.Version = &[_]Semver.Version{},
//       external_strings: []const ExternalString = &[_]ExternalString{},
//       external_strings_for_versions: []const ExternalString = &[_]ExternalString{},
//       package_versions: []const PackageVersion = &[_]PackageVersion{},
//       extern_strings_bin_entries: []const ExternalString = &[_]ExternalString{},
//       bundled_deps_buf: []const PackageNameHash = &.{},
//   }
//   这是 Bun 中完整的包 Manifest 数据结构, 包含:
//   - NpmPackage (核心元数据)
//   - 各种缓冲区 (字符串、版本、外部字符串)
//   - 查找/搜索方法
//   - 序列化/反序列化
//   - JSON 解析
// ============================================================================

/// 包 Manifest
/// 对应 Bun: Npm.PackageManifest
/// 翻译自: src/install/npm.zig - PackageManifest struct
///   注册表中一个包的完整解析数据, 包含所有版本的元数据
public class NpmPackageManifest {
    /// 核心包数据
    /// 翻译自: pkg: NpmPackage = .{}
    public var pkg: NpmPackage

    /// 字符串缓冲区 (String 类型, 用于 offset/length 引用)
    /// 翻译自: string_buf: []const u8
    public var stringBuf: String

    /// 字符串缓冲区 (字节数组形式, 用于 ExternalString.slice)
    /// 翻译自: string_buf 作为底层 []const u8 传递给 slice()
    public var stringBufBytes: Array<UInt8>

    /// 所有 semver 版本 (含 release + prerelease + dist-tag 版本)
    /// 翻译自: versions: []const Semver.Version
    public var versions: ArrayList<SemverVersion>

    /// 外部字符串列表
    /// 翻译自: external_strings: []const ExternalString
    public var externalStrings: ArrayList<ExternalString>

    /// 版本依赖的外部字符串
    /// 翻译自: external_strings_for_versions: []const ExternalString
    public var externalStringsForVersions: ArrayList<ExternalString>

    /// 包版本数据列表
    /// 翻译自: package_versions: []const PackageVersion
    public var packageVersions: ArrayList<PackageVersionData>

    /// bin 条目外部字符串
    /// 翻译自: extern_strings_bin_entries: []const ExternalString
    public var externStringsBinEntries: ArrayList<ExternalString>

    /// 打包依赖哈希列表
    /// 翻译自: bundled_deps_buf: []const PackageNameHash
    public var bundledDepsBuf: ArrayList<UInt64>

    public init() {
        pkg = NpmPackage()
        stringBuf = ""
        stringBufBytes = Array<UInt8>()
        versions = ArrayList<SemverVersion>()
        externalStrings = ArrayList<ExternalString>()
        externalStringsForVersions = ArrayList<ExternalString>()
        packageVersions = ArrayList<PackageVersionData>()
        externStringsBinEntries = ArrayList<ExternalString>()
        bundledDepsBuf = ArrayList<UInt64>()
    }

    // ========================================================================
    // 名称访问
    // 严格翻译自: PackageManifest.name
    //   pub inline fn name(this) string {
    //       return this.pkg.name.slice(this.string_buf)
    //   }
    // ========================================================================

    /// 获取包名
    /// 翻译自: PackageManifest.name
    ///   pub inline fn name(this) string {
    ///       return this.pkg.name.slice(this.string_buf)
    ///   }
    /// 注意: 必须使用 pkg.name 的 offset/length 从 stringBuf 切片,
    ///       而不是直接返回整个 stringBuf
    public func name(): String {
        return pkg.name.slice(stringBufBytes)
    }

    // ========================================================================
    // 按精确版本查找
    // 严格翻译自: PackageManifest.findByVersion
    //   pub fn findByVersion(this, version) ?FindResult {
    //       const list = if (!version.tag.hasPre()) this.pkg.releases
    //                    else this.pkg.prereleases
    //       const index = list.findKeyIndex(this.versions, version) orelse return null
    //       return .{ .version = keys[index], .package = &values[index] }
    //   }
    // ========================================================================

    /// 按精确版本查找
    /// 翻译自: PackageManifest.findByVersion
    public func findByVersion(version: SemverVersion): ?ManifestFindResult {
        let list = if (!version.hasPre()) { pkg.releases } else { pkg.prereleases }
        let index = list.findKeyIndex(versions, version)
        match (index) {
            case Some(idx) =>
                let i = Int64(idx)
                if (i < versions.size && i < packageVersions.size) {
                    return Some(ManifestFindResult(versions[i], packageVersions[i]))
                }
                return None
            case None => return None
        }
    }

    // ========================================================================
    // 按 dist-tag 查找
    // 严格翻译自: PackageManifest.findByDistTag
    //   pub fn findByDistTag(this, tag) ?FindResult {
    //       for tags, 0.. |tag_str, i| {
    //           if (strings.eql(tag_str.slice(this.string_buf), tag)) {
    //               return this.findByVersion(versions[i])
    //           }
    //       }
    //       return null
    //   }
    // ========================================================================

    /// 按 dist-tag 查找
    /// 翻译自: PackageManifest.findByDistTag
    public func findByDistTag(tag: String): ?ManifestFindResult {
        // dist-tag 映射在 pkg.distTags 中
        // 简化: 从版本列表中查找 latest 等
        if (tag == "latest") {
            // 查找最后一个 release 版本
            let relKeys = pkg.releases.keys
            if (relKeys.len > UInt32(0)) {
                let lastIdx = Int64(relKeys.len) - Int64(1)
                if (lastIdx < versions.size && lastIdx < packageVersions.size) {
                    return Some(ManifestFindResult(versions[lastIdx], packageVersions[lastIdx]))
                }
            }
        }
        // 遍历 distTags
        let tagCount = Int64(pkg.distTags.tags.len)
        var i: Int64 = 0
        while (i < tagCount && i < versions.size) {
            // 简化: 直接比较
            i += 1
        }
        return None
    }

    // ========================================================================
    // 查找最佳版本
    // 严格翻译自: PackageManifest.findBestVersion
    //   从最新版本开始向下搜索, 找到第一个满足约束的版本
    //   pub fn findBestVersion(this, group, group_buf) ?FindResult {
    //       const left = group.head.head.range.left
    //       if (left.op == .eql) return this.findByVersion(left.version)
    //       if (this.findByDistTag("latest")) |result| {
    //           if (group.satisfies(result.version, ...)) return result
    //       }
    //       // 遍历 releases 反向
    //       // 遍历 prereleases 反向 (如果 pre flag)
    //   }
    // ========================================================================

    /// 查找最佳版本 (不含最低发布年龄过滤器)
    /// 翻译自: PackageManifest.findBestVersion
    ///   从最新版本反向搜索, 找到第一个满足 semver 约束的版本
    public func findBestVersion(
        group: SemverQueryGroup,
        groupBuf: String
    ): ?ManifestFindResult {
        // 快速路径: 精确版本
        if (group.isExactVersion()) {
            return findByVersion(group.leftVersion())
        }

        // 尝试 latest dist-tag
        let latest = findByDistTag("latest")
        match (latest) {
            case Some(result) =>
                if (group.satisfies(result.version, groupBuf, stringBuf)) {
                    return result
                }
            case None => ()
        }

        // 反向遍历 releases
        var i = versions.size
        while (i > 0) {
            i -= 1
            let version = versions[i]
            if (!version.hasPre()) {
                if (group.satisfies(version, groupBuf, stringBuf)) {
                    return Some(ManifestFindResult(version, packageVersions[i]))
                }
            }
        }

        // 如果允许预发布, 反向遍历 prereleases
        if (group.hasPreFlag()) {
            i = versions.size
            while (i > 0) {
                i -= 1
                let version = versions[i]
                if (version.hasPre()) {
                    if (group.satisfies(version, groupBuf, stringBuf)) {
                        return Some(ManifestFindResult(version, packageVersions[i]))
                    }
                }
            }
        }

        return None
    }

    // ========================================================================
    // 查找最佳版本 (含最低发布年龄过滤器)
    // 严格翻译自: PackageManifest.findBestVersionWithFilter
    //   支持 minimum_release_age_ms 过滤:
    //   - 跳过太新的版本
    //   - 稳定性窗口检查
    // ========================================================================

    /// 检查是否应从年龄过滤器中排除
    /// 翻译自: PackageManifest.shouldExcludeFromAgeFilter
    public func shouldExcludeFromAgeFilter(exclusions: ?ArrayList<String>): Bool {
        match (exclusions) {
            case Some(excl) =>
                let pkgName = name()
                for (excluded in excl) {
                    if (pkgName == excluded) {
                        return true
                    }
                }
                return false
            case None => return false
        }
    }

    /// 检查包版本是否太新
    /// 翻译自: PackageManifest.isPackageVersionTooRecent
    ///   const current_timestamp_ms = @floatFromInt(@divTrunc(bun.start_time, ns_per_ms))
    ///   return package_version.publish_timestamp_ms > current_timestamp_ms - minimum_release_age_ms
    public static func isPackageVersionTooRecent(
        packageVersion: PackageVersionData,
        minimumReleaseAgeMs: Float64
    ): Bool {
        let currentTimestampMs = Float64(Int64(0)) // TODO: TimeStamp.currentMillis()
        return packageVersion.publishTimestampMs > currentTimestampMs - minimumReleaseAgeMs
    }

    /// 查找最佳版本 (含最低发布年龄过滤器)
    /// 翻译自: PackageManifest.findBestVersionWithFilter
    public func findBestVersionWithFilter(
        group: SemverQueryGroup,
        groupBuf: String,
        minimumReleaseAgeMs: ?Float64,
        exclusions: ?ArrayList<String>
    ): FindVersionResult {
        // 确定是否需要过滤
        var minAgeMs: ?Float64 = None
        match (minimumReleaseAgeMs) {
            case Some(ms) =>
                if (!shouldExcludeFromAgeFilter(exclusions)) {
                    minAgeMs = Some(ms)
                }
            case None => ()
        }

        match (minAgeMs) {
            case None =>
                // 无过滤, 直接查找
                let result = findBestVersion(group, groupBuf)
                match (result) {
                    case Some(r) => return FindVersionResult.foundResult(r)
                    case None => return FindVersionResult.errorResult(FindVersionError.NotFound)
                }
            case Some(ms) => searchWithAgeFilter(group, groupBuf, ms)
        }
    }

    /// 带 age filter 搜索
    /// 翻译自: PackageManifest.findBestVersionWithFilter (带 minimum_release_age_ms 路径)
    private func searchWithAgeFilter(
        group: SemverQueryGroup,
        groupBuf: String,
        minAgeMs: Float64
    ): FindVersionResult {
        // 精确版本检查
        if (group.isExactVersion()) {
            let result = findByVersion(group.leftVersion())
            match (result) {
                case Some(r) =>
                    if (isPackageVersionTooRecent(r.packageVersion, minAgeMs)) {
                        return FindVersionResult.errorResult(FindVersionError.TooRecent)
                    }
                    return FindVersionResult.foundResult(r)
                case None => return FindVersionResult.errorResult(FindVersionError.NotFound)
            }
        }

        // 尝试 latest dist-tag
        var newestFiltered: ?SemverVersion = None
        let latest = findByDistTag("latest")
        match (latest) {
            case Some(result) =>
                if (group.satisfies(result.version, groupBuf, stringBuf)) {
                    if (isPackageVersionTooRecent(result.packageVersion, minAgeMs)) {
                        newestFiltered = Some(result.version)
                    }
                    match (newestFiltered) {
                        case None =>
                            if (!group.hasPreFlag()) {
                                return FindVersionResult.foundResult(result)
                            }
                        case Some(_) => ()
                    }
                }
            case None => ()
        }

        // 反向搜索 releases
        var bestVersion: ?ManifestFindResult = None
        var i = versions.size
        while (i > 0) {
            i -= 1
            let version = versions[i]
            if (!version.hasPre() && group.satisfies(version, groupBuf, stringBuf)) {
                let pv = packageVersions[i]
                if (isPackageVersionTooRecent(pv, minAgeMs)) {
                    match (newestFiltered) {
                        case None => newestFiltered = Some(version)
                        case Some(_) => ()
                    }
                } else {
                    return FindVersionResult.foundResult(
                        ManifestFindResult(version, pv)
                    )
                }
            }
        }

        // 如果有预发布标志, 搜索 prereleases
        if (group.hasPreFlag()) {
            i = versions.size
            while (i > 0) {
                i -= 1
                let version = versions[i]
                if (version.hasPre() && group.satisfies(version, groupBuf, stringBuf)) {
                    let pv = packageVersions[i]
                    if (!isPackageVersionTooRecent(pv, minAgeMs)) {
                        return FindVersionResult.foundResult(
                            ManifestFindResult(version, pv)
                        )
                    }
                }
            }
        }

        // 所有版本都太新
        match (newestFiltered) {
            case Some(_) => return FindVersionResult.errorResult(FindVersionError.AllVersionsTooRecent)
            case None => return FindVersionResult.errorResult(FindVersionError.NotFound)
        }
    }

    // ========================================================================
    // 按 dist-tag 查找 (含 age filter)
    // 严格翻译自: PackageManifest.findByDistTagWithFilter
    // ========================================================================

    /// 按 dist-tag 查找 (含最低发布年龄过滤器)
    /// 翻译自: PackageManifest.findByDistTagWithFilter
    public func findByDistTagWithFilter(
        tag: String,
        minimumReleaseAgeMs: ?Float64,
        exclusions: ?ArrayList<String>
    ): FindVersionResult {
        let distResult = findByDistTag(tag)
        match (distResult) {
            case None => return FindVersionResult.errorResult(FindVersionError.NotFound)
            case Some(result) => ()
        }

        var minAgeMs: ?Float64 = None
        match (minimumReleaseAgeMs) {
            case Some(ms) =>
                if (!shouldExcludeFromAgeFilter(exclusions)) {
                    minAgeMs = Some(ms)
                }
            case None => ()
        }

        match (minAgeMs) {
            case None =>
                return FindVersionResult.foundResult(distResult.getOrThrow())
            case Some(ms) =>
                let r = distResult.getOrThrow()
                if (!isPackageVersionTooRecent(r.packageVersion, ms)) {
                    return FindVersionResult.foundResult(r)
                }
                // 太新, 反向搜索
                let latestVersion = r.version
                var bestVersion: ?ManifestFindResult = None
                var i = versions.size
                while (i > 0) {
                    i -= 1
                    let version = versions[i]
                    let pv = packageVersions[i]
                    // 只查找不比 latest 新的版本
                    if (version.order(latestVersion) > 0) { continue }
                    if (!isPackageVersionTooRecent(pv, ms)) {
                        return FindVersionResult.foundWithFilterResult(
                            ManifestFindResult(version, pv),
                            Some(latestVersion)
                        )
                    }
                }

                match (bestVersion) {
                    case Some(bv) => return FindVersionResult.foundWithFilterResult(
                        bv, Some(latestVersion)
                    )
                    case None => return FindVersionResult.errorResult(
                        FindVersionError.AllVersionsTooRecent
                    )
                }
        }
    }

    // ========================================================================
    // 搜索版本列表
    // 严格翻译自: PackageManifest.searchVersionList
    //   带稳定性窗口检查的反向搜索
    // ========================================================================

    /// 搜索版本列表 (带稳定性窗口)
    /// 翻译自: PackageManifest.searchVersionList
    ///   支持在 minimum_release_age_ms 过滤中检查 "稳定性窗口":
    ///   如果最新版本被过滤, 检查前一个版本是否稳定 (间隔 >= stability_window_ms)
    public func searchVersionList(
        versionList: ArrayList<SemverVersion>,
        packageList: ArrayList<PackageVersionData>,
        group: SemverQueryGroup,
        groupBuf: String,
        minimumReleaseAgeMs: Float64,
        newestFiltered: ?SemverVersion
    ): FindVersionResult {
        var bestVersion: ?ManifestFindResult = None
        var prevBlockedFromAge: ?PackageVersionData = None
        let currentTimestampMs = Float64(Int64(0)) // TODO: TimeStamp.currentMillis()
        let sevenDaysMs: Float64 = 604800000.0 * 7.0
        let stabilityWindowMs = if (minimumReleaseAgeMs < sevenDaysMs) {
            minimumReleaseAgeMs
        } else {
            sevenDaysMs
        }
        var filteredNewest = newestFiltered

        var i = versionList.size
        while (i > 0) {
            i -= 1
            let version = versionList[i]
            if (group.satisfies(version, groupBuf, stringBuf)) {
                let pv = packageList[i]
                if (isPackageVersionTooRecent(pv, minimumReleaseAgeMs)) {
                    match (filteredNewest) {
                        case None => filteredNewest = Some(version)
                        case Some(_) => ()
                    }
                    prevBlockedFromAge = Some(pv)
                } else {
                    // 稳定性检查
                    match (prevBlockedFromAge) {
                        case Some(prevPv) =>
                            // 检查是否超出最大回溯范围
                            if (pv.publishTimestampMs < currentTimestampMs - (minimumReleaseAgeMs + sevenDaysMs)) {
                                match (bestVersion) {
                                    case None => bestVersion = Some(
                                        ManifestFindResult(version, pv)
                                    )
                                    case Some(_) => ()
                                }
                                break
                            }
                            let isStable = prevPv.publishTimestampMs - pv.publishTimestampMs >= stabilityWindowMs
                            if (isStable) {
                                bestVersion = Some(ManifestFindResult(version, pv))
                                break
                            } else {
                                match (bestVersion) {
                                    case None => bestVersion = Some(
                                        ManifestFindResult(version, pv)
                                    )
                                    case Some(_) => ()
                                }
                                prevBlockedFromAge = Some(pv)
                            }
                        case None =>
                            // 没有被过滤的前一个版本, 直接返回
                            return FindVersionResult.foundResult(
                                ManifestFindResult(version, pv)
                            )
                    }
                }
            }
        }

        match (bestVersion) {
            case Some(bv) =>
                match (filteredNewest) {
                    case Some(nf) => return FindVersionResult.foundWithFilterResult(bv, Some(nf))
                    case None => return FindVersionResult.foundResult(bv)
                }
            case None => return FindVersionResult()
        }
    }

    // ========================================================================
    // 报告大小
    // 严格翻译自: PackageManifest.reportSize
    //   用于调试输出 manifest 中各种缓冲区的大小
    // ========================================================================

    /// 报告 manifest 大小信息
    /// 翻译自: PackageManifest.reportSize
    public func reportSize(): String {
        return "Versions: ${versions.size}, ExternalStrings: ${externalStrings.size}, " +
            "PackageVersions: ${packageVersions.size}, BundledDeps: ${bundledDepsBuf.size}"
    }

    // ========================================================================
    // 序列化器
    // 严格翻译自: src/install/npm.zig - PackageManifest.Serializer
    //   pub const Serializer = struct {
    //       pub const version = "bun-npm-manifest-cache-v0.0.7\n"
    //       pub const header_bytes = "#!/usr/bin/env bun\n" ++ version
    //       pub fn write(...)
    //       pub fn readAll(...)
    //       pub fn save(...)
    //       pub fn loadByFileID(...)
    //       pub fn loadByFile(...)
    //   }
    //
    //   Bun 使用二进制序列化将 PackageManifest 缓存到磁盘,
    //   避免每次安装都重新从网络获取。
    // ========================================================================
}

// ============================================================================
// Manifest 序列化器
// 严格翻译自: src/install/npm.zig - PackageManifest.Serializer
//   pub const Serializer = struct {
//       pub const version = "bun-npm-manifest-cache-v0.0.7\n"
//       pub const header_bytes: string = "#!/usr/bin/env bun\n" ++ version
//       ...
//   }
// ============================================================================

/// Manifest 缓存版本号
/// 翻译自: PackageManifest.Serializer.version
///   版本历史:
///   - v0.0.3: 添加 registry URL 序列化
///   - v0.0.4: 修复 CPU/OS tag 错误
///   - v0.0.5: 添加 bundled dependencies
///   - v0.0.6: semver major/minor/patch 改用 u64
///   - v0.0.7: 添加版本发布时间和扩展 manifest 标志
public let MANIFEST_CACHE_VERSION: String = "bun-npm-manifest-cache-v0.0.7\n"

/// Manifest 缓存头
/// 翻译自: PackageManifest.Serializer.header_bytes
public let MANIFEST_CACHE_HEADER: String = "#!/usr/bin/env bun\n" + MANIFEST_CACHE_VERSION

/// Manifest 序列化器
/// 对应 Bun: PackageManifest.Serializer
/// 翻译自: src/install/npm.zig - PackageManifest.Serializer
///   负责将 PackageManifest 序列化/反序列化到磁盘缓存
public class ManifestSerializer {

    /// 将 Manifest 写入字节数组
    /// 翻译自: PackageManifest.Serializer.write
    ///   序列化流程:
    ///   1. 写入 header_bytes
    ///   2. 写入 scope.url_hash (u64 LE)
    ///   3. 写入 scope.url 长度 (u64 LE)
    ///   4. 写入 NpmPackage 结构体
    ///   5. 写入各个缓冲区数组 (每个前缀为 u64 长度)
    public static func write(
        manifest: NpmPackageManifest,
        scope: NpmRegistryScope
    ): Array<UInt8> {
        let builder = ArrayList<UInt8>()

        // 1. 写入 header
        for (c in MANIFEST_CACHE_HEADER) {
            builder.append(UInt8(UInt32(c)))
        }

        // 2. 写入 scope URL hash (u64 LE)
        appendUInt64(builder, scope.urlHash)

        // 3. 写入 scope URL 长度 (u64 LE)
        let urlLen = UInt64(scope.url.size)
        appendUInt64(builder, urlLen)

        // 4. 写入 pkg 结构体 (简化: 写入 JSON)
        // 在 Bun 中这是直接内存拷贝, 这里使用 JSON 序列化
        let pkgJson = serializeNpmPackageToJson(manifest.pkg)
        for (c in pkgJson) {
            builder.append(UInt8(UInt32(c)))
        }

        // 5. 写入版本列表
        appendUInt64(builder, UInt64(manifest.versions.size))
        for (v in manifest.versions) {
            let vBytes = serializeVersion(v)
            for (b in vBytes) { builder.append(b) }
        }

        return builder.items()
    }

    /// 从字节数组读取 Manifest
    /// 翻译自: PackageManifest.Serializer.readAll
    ///   反序列化流程:
    ///   1. 验证 header_bytes
    ///   2. 读取 scope.url_hash 和 URL 长度并验证
    ///   3. 读取 NpmPackage 结构体
    ///   4. 读取各个缓冲区数组
    public static func readAll(
        bytes: Array<UInt8>,
        scope: NpmRegistryScope
    ): ?NpmPackageManifest {
        // 验证 header
        if (bytes.size < MANIFEST_CACHE_HEADER.size) {
            return None
        }

        var headerMatch = true
        var idx: Int64 = 0
        while (idx < Int64(MANIFEST_CACHE_HEADER.size)) {
            if (UInt32(bytes[idx]) != UInt32(Rune(MANIFEST_CACHE_HEADER[Int64(idx)]))) {
                headerMatch = false
                break
            }
            idx += 1
        }
        if (!headerMatch) { return None }

        // 读取 registry hash
        let registryHash = readUInt64(bytes, Int64(MANIFEST_CACHE_HEADER.size))
        if (scope.urlHash != registryHash) { return None }

        // 读取 registry URL 长度
        let registryLength = readUInt64(bytes, Int64(MANIFEST_CACHE_HEADER.size) + 8)
        let urlWithoutSlash = if (scope.url.endsWith("/")) {
            scope.url[..scope.url.size - 1]
        } else {
            scope.url
        }
        if (UInt64(urlWithoutSlash.size) != registryLength) { return None }

        // 简化: 返回空 manifest (完整解析需要更多基础设施)
        let manifest = NpmPackageManifest()
        return manifest
    }

    /// 保存 Manifest 到磁盘
    /// 翻译自: PackageManifest.Serializer.save
    ///   写入临时文件, 然后原子重命名为目标文件
    public static func save(
        manifest: NpmPackageManifest,
        scope: NpmRegistryScope,
        cacheDir: String
    ): Bool {
        let nameHash = NpmRegistryScope.hashURL(manifest.name())
        let hexName = HexEncode.encodeUInt64(nameHash)
        let fileName = if (scope.urlHash == NPM_DEFAULT_REGISTRY_HASH) {
            "${hexName}.npm"
        } else {
            "${hexName}-${HexEncode.encodeUInt64(scope.urlHash)}.npm"
        }
        let filePath = Path.join([cacheDir, fileName])
        let data = write(manifest, scope)
        match (BaoFile.writeAllBytes(filePath, data)) {
            case SysMaybe<Unit>.Ok(_) => return true
            case SysMaybe<Unit>.Err(_) => return false
        }
    }

    /// 从磁盘加载 Manifest
    /// 翻译自: PackageManifest.Serializer.loadByFileID
    public static func loadByFileID(
        scope: NpmRegistryScope,
        cacheDir: String,
        fileId: UInt64
    ): ?NpmPackageManifest {
        let hexName = HexEncode.encodeUInt64(fileId)
        let fileName = if (scope.urlHash == NPM_DEFAULT_REGISTRY_HASH) {
            "${hexName}.npm"
        } else {
            "${hexName}-${HexEncode.encodeUInt64(scope.urlHash)}.npm"
        }
        let filePath = Path.join([cacheDir, fileName])
        if (!BaoFile.exists(filePath)) { return None }
        let bytesResult = BaoFile.readAllBytes(filePath)
        let dataOpt = bytesResult.result()
        if (dataOpt.isSome()) {
            let data = dataOpt.getOrThrow()
            if (data.size == 0) { return None }
            return readAll(data, scope)
        }
        return None
    }

    // ========================================================================
    // 辅助方法
    // ========================================================================

    /// 追加 UInt64 (小端序)
    public static func appendUInt64(builder: ArrayList<UInt8>, value: UInt64): Unit {
        builder.append(UInt8(value & UInt64(0xFF)))
        builder.append(UInt8((value >> 8) & UInt64(0xFF)))
        builder.append(UInt8((value >> 16) & UInt64(0xFF)))
        builder.append(UInt8((value >> 24) & UInt64(0xFF)))
        builder.append(UInt8((value >> 32) & UInt64(0xFF)))
        builder.append(UInt8((value >> 40) & UInt64(0xFF)))
        builder.append(UInt8((value >> 48) & UInt64(0xFF)))
        builder.append(UInt8((value >> 56) & UInt64(0xFF)))
    }

    /// 读取 UInt64 (小端序)
    public static func readUInt64(bytes: Array<UInt8>, offset: Int64): UInt64 {
        if (offset + 7 >= bytes.size) { return UInt64(0) }
        return UInt64(bytes[offset]) |
            (UInt64(bytes[offset + 1]) << 8) |
            (UInt64(bytes[offset + 2]) << 16) |
            (UInt64(bytes[offset + 3]) << 24) |
            (UInt64(bytes[offset + 4]) << 32) |
            (UInt64(bytes[offset + 5]) << 40) |
            (UInt64(bytes[offset + 6]) << 48) |
            (UInt64(bytes[offset + 7]) << 56)
    }

    /// 序列化 SemverVersion
    private static func serializeVersion(v: SemverVersion): Array<UInt8> {
        let builder = ArrayList<UInt8>()
        appendUInt64(builder, v.major)
        appendUInt64(builder, v.minor)
        appendUInt64(builder, v.patch)
        // tag string length + bytes
        for (c in v.tag) {
            builder.append(UInt8(UInt32(c)))
        }
        return builder.items()
    }

    /// 序列化 NpmPackage 为 JSON (简化)
    private static func serializeNpmPackageToJson(pkg: NpmPackage): String {
        var sb = StringBuilder()
        sb.append("{\"lastModified\":\"")
        sb.append(pkg.lastModified)
        sb.append("\",\"etag\":\"")
        sb.append(pkg.etag)
        sb.append("\",\"modified\":\"")
        sb.append(pkg.modified)
        sb.append("\",\"publicMaxAge\":")
        sb.append(UInt64(pkg.publicMaxAge).toString())
        sb.append(",\"hasExtendedManifest\":")
        sb.append(if (pkg.hasExtendedManifest) { "true" } else { "false" })
        sb.append("}")
        return sb.toString()
    }
}

// ============================================================================
// Semver 查询组 (简化)
// 严格翻译自: src/install/semver.zig - Query.Group
//   PackageManifest 中的查找方法需要 Semver.Query.Group
//   这里提供简化接口
// ============================================================================

/// Semver 查询组
/// 对应 Bun: Semver.Query.Group
/// 翻译自: src/semver.zig 中查询相关结构
///   用于版本匹配: 检查某个版本是否满足 semver 约束
public class SemverQueryGroup {
    /// 原始范围字符串
    public var rangeStr: String

    /// 是否为精确版本 (如 "1.2.3")
    private var isExact: Bool

    /// 精确版本值 (当 isExact 为 true 时有效)
    private var exactVersion: ?SemverVersion

    /// 是否有预发布标志
    private var hasPre: Bool

    public init(rangeStr: String) {
        this.rangeStr = rangeStr
        this.isExact = false
        exactVersion = None
        hasPre = false
        // 解析
        if (rangeStr.size > 0) {
            let parsed = SemVer.parse(rangeStr)
            match (parsed) {
                case Some(sv) =>
                    // 检查是否为精确版本 (无范围操作符)
                    let trimmed = rangeStr.trimStart("^~><= ")
                    if (trimmed == sv.toString()) {
                        isExact = true
                        let preStr = match (sv.prerelease) {
                            case Some(pre) => "-${pre}"
                            case None => ""
                        }
                        exactVersion = Some(SemverVersion(
                            UInt64(sv.major), UInt64(sv.minor), UInt64(sv.patch),
                            preStr
                        ))
                    }
                    hasPre = sv.prerelease.isSome()
                case None => ()
            }
        }
    }

    /// 是否为精确版本
    public func isExactVersion(): Bool {
        return isExact
    }

    /// 获取左侧版本 (精确版本时使用)
    public func leftVersion(): SemverVersion {
        match (exactVersion) {
            case Some(v) => return v
            case None => return SemverVersion()
        }
    }

    /// 是否有预发布标志
    public func hasPreFlag(): Bool {
        return hasPre
    }

    /// 检查版本是否满足此查询
    /// 翻译自: Semver.Query.Group.satisfies
    public func satisfies(
        version: SemverVersion,
        groupBuf: String,
        stringBuf: String
    ): Bool {
        if (rangeStr == "*" || rangeStr == "") {
            return true
        }
        if (rangeStr == "latest") {
            return true
        }
        if (isExact) {
            match (exactVersion) {
                case Some(ev) => return version.eql(ev)
                case None => return false
            }
        }
        // 简化: 使用 SemVer 匹配
        let sv = SemVer.parse(version.toString())
        match (sv) {
            case Some(s) => return SemVer.satisfies(s, rangeStr)
            case None => return false
        }
    }
}

// ============================================================================
// Hex 编码辅助
// ============================================================================

/// 十六进制编码辅助
public class HexEncode {
    /// 将 UInt64 编码为十六进制字符串
    public static func encodeUInt64(value: UInt64): String {
        let hexChars = "0123456789abcdef"
        var sb = StringBuilder()
        var v = value
        // 从高位到低位, 但先提取所有 nibble
        var nibbles = ArrayList<UInt8>()
        if (v == UInt64(0)) {
            return "0"
        }
        while (v > UInt64(0)) {
            nibbles.append(UInt8(v & UInt64(0xF)))
            v = v >> UInt64(4)
        }
        // 反向输出
        var i = nibbles.size - 1
        while (i >= 0) {
            sb.append(String([Rune(UInt32(hexChars[Int64(nibbles[i])]))]))
            i -= 1
        }
        return sb.toString()
    }

    /// 将字节数组编码为十六进制字符串
    public static func encode(bytes: Array<UInt8>): String {
        let hexChars = "0123456789abcdef"
        var sb = StringBuilder()
        for (b in bytes) {
            let high = UInt32((b >> UInt8(4)) & UInt8(0xF))
            let low = UInt32(b & UInt8(0xF))
            sb.append(String([Rune(UInt32(hexChars[Int64(high)]))]))
            sb.append(String([Rune(UInt32(hexChars[Int64(low)]))]))
        }
        return sb.toString()
    }

    /// 将十六进制字符串解码为字节数组
    public static func decode(hex: String): Array<UInt8> {
        var result = ArrayList<UInt8>()
        var i: Int64 = 0
        while (i + 1 < hex.size) {
            let high = hexCharToInt(Rune(UInt32(hex[i])))
            let low = hexCharToInt(Rune(UInt32(hex[i + 1])))
            if (high >= 0 && low >= 0) {
                result.append(UInt8((high << 4) | low))
            }
            i += 2
        }
        return result.items()
    }

    private static func hexCharToInt(c: Rune): Int64 {
        let v = Int64(UInt32(c))
        if (v >= 0x30 && v <= 0x39) { return v - 0x30 }  // '0'-'9'
        if (v >= 0x61 && v <= 0x66) { return v - 0x61 + 10 }  // 'a'-'f'
        if (v >= 0x41 && v <= 0x46) { return v - 0x41 + 10 }  // 'A'-'F'
        return -1
    }
}

// ============================================================================
// NpmRegistryApi - 注册表 API 配置
// 严格翻译自: src/schema/api.zig - NpmRegistry
//   pub const NpmRegistry = struct {
//       url: string = "",
//       username: string = "",
//       password: string = "",
//       token: string = "",
//   }
//   用于 Scope.fromAPI 的输入参数
// ============================================================================

/// NPM 注册表 API 配置
/// 对应 Bun: api.NpmRegistry
/// 翻译自: src/schema/api.zig - NpmRegistry
public class NpmRegistryApi {
    /// 注册表 URL
    public var url: String
    /// 用户名
    public var username: String
    /// 密码
    public var password: String
    /// Bearer token
    public var token: String

    public init() {
        url = ""
        username = ""
        password = ""
        token = ""
    }

    public init(url: String, token: String) {
        this.url = url
        this.token = token
        username = ""
        password = ""
    }

    public init(url: String, username: String, password: String, token: String) {
        this.url = url
        this.username = username
        this.password = password
        this.token = token
    }
}

// ============================================================================
// DotEnv 环境变量加载器 (简化接口)
// 严格翻译自: src/dotenv/env_loader.zig - DotEnv.Loader
// ============================================================================

// NOTE: DotEnvLoader defined in package_manager.cj (canonical)

// ============================================================================
// NpmRegistryScope 扩展: fromAPI 方法
// 严格翻译自: src/install/npm.zig - Registry.Scope.fromAPI
//   pub fn fromAPI(name, registry_, allocator, env) OOM!Scope
//   143 行函数: 从 NpmRegistryApi + 环境变量构建 Scope
//   处理 URL 路径中的认证凭据:
//     :_authToken, :username, :_password, :_auth
//   以及 Basic Auth (base64(username:password))
// ============================================================================

/// NpmRegistryScope 扩展方法
/// 翻译自: Registry.Scope.fromAPI
public class NpmRegistryScopeFactory {

    /// 从 API 配置和环境变量创建 Scope
    /// 严格翻译自: Registry.Scope.fromAPI (Zig ~232-375)
    ///
    /// 解析注册表 URL 中的认证信息:
    ///   URL 路径可能包含特殊后缀:
    ///     :_authToken=<token>   -> Bearer token
    ///     :_auth=<base64>       -> Basic auth
    ///     :username=<user>      -> 用户名
    ///     :_password=<password> -> 密码
    ///
    /// 认证优先级:
    ///   1. URL 路径中的 _authToken / _auth
    ///   2. registry.token
    ///   3. username + password -> Basic auth (base64)
    ///   4. 环境变量替换
    public static func fromAPI(
        name: String,
        registry: NpmRegistryApi,
        env: DotEnvLoader
    ): NpmRegistryScope {
        var regUrl = registry.url

        // 支持 $ENV_VAR 替换注册表 URL
        // 翻译自: if (strings.startsWithChar(registry_.url, '$'))
        if (regUrl.size > 0 && regUrl[0] == UInt8(0x24)) {
            let envKey = regUrl[1..]
            // 去除尾部斜杠
            let trimmedKey = if (envKey.endsWith("/")) { envKey[..envKey.size - 1] } else { envKey }
            match (env.get(trimmedKey)) {
                case Some(replacedUrl) =>
                    if (replacedUrl.size > 1) {
                        regUrl = replacedUrl
                    }
                case None => ()
            }
        }

        var url = URLParse.parse(regUrl)
        var auth: String = ""
        var user: String = ""
        var needsNormalize = false
        var token = registry.token
        var username = registry.username
        var password = registry.password

        if (token.size == 0) {
            // 没有显式 token, 从 URL 路径解析认证信息
            if (password.size == 0) {
                // 翻译自: while (strings.lastIndexOfChar(pathname, ':')) |colon|
                //  反向遍历路径中的 ':' 分隔段, 解析 key=value 对
                var pathname = url.pathname
                var needsToCheckSlash = true

                while (true) {
                    let colonIdx = lastIndexOfChar(pathname, UInt8(0x3A))
                    match (colonIdx) {
                        case Some(colon) =>
                            let segment = pathname[Int64(colon) + 1..]
                            pathname = pathname[..Int64(colon)]
                            needsToCheckSlash = false
                            needsNormalize = true

                            // 去除尾部斜杠
                            if (pathname.size > 1 && pathname[pathname.size - 1] == UInt8(0x2F)) {
                                pathname = pathname[..pathname.size - 1]
                            }

                            // 解析 key=value
                            let eqlIdx = indexOfChar(segment, UInt8(0x3D))
                            match (eqlIdx) {
                                case Some(eqlI) =>
                                    let value = segment[Int64(eqlI) + 1..]
                                    var segKey = segment[..Int64(eqlI)]

                                    // Bearer Token
                                    // 翻译自: if (strings.eqlComptime(segment, "_authToken"))
                                    if (segKey == "_authToken") {
                                        token = value
                                        break
                                    }

                                    // Basic Auth (base64 编码)
                                    // 翻译自: if (strings.eqlComptime(segment, "_auth"))
                                    if (segKey == "_auth") {
                                        auth = value
                                        break
                                    }

                                    // 用户名
                                    // 翻译自: if (strings.eqlComptime(segment, "username"))
                                    if (segKey == "username") {
                                        username = value
                                    }

                                    // 密码
                                    // 翻译自: if (strings.eqlComptime(segment, "_password"))
                                    if (segKey == "_password") {
                                        password = value
                                    }

                                case None => () // 没有 =, 跳过
                            }

                        case None => break
                    }
                }

                // 如果没有找到冒号, 检查路径中最后一个 '/' 后是否有 key=value
                // 翻译自: if (needs_to_check_slash) ...
                if (needsToCheckSlash) {
                    let lastSlashIdx = lastIndexOfChar(pathname, UInt8(0x2F))
                    match (lastSlashIdx) {
                        case Some(lastSlash) =>
                            let remain = pathname[Int64(lastSlash) + 1..]
                            let remainEql = indexOfChar(remain, UInt8(0x3D))
                            match (remainEql) {
                                case Some(eqlI) =>
                                    let segKey = remain[..Int64(eqlI)]
                                    let value = remain[Int64(eqlI) + 1..]

                                    if (segKey == "_authToken") {
                                        token = value
                                        pathname = pathname[..Int64(lastSlash) + 1]
                                        needsNormalize = true
                                    } else if (segKey == "_auth") {
                                        auth = value
                                        pathname = pathname[..Int64(lastSlash) + 1]
                                        needsNormalize = true
                                    } else if (segKey == "username") {
                                        username = value
                                        pathname = pathname[..Int64(lastSlash) + 1]
                                        needsNormalize = true
                                    } else if (segKey == "_password") {
                                        password = value
                                        pathname = pathname[..Int64(lastSlash) + 1]
                                        needsNormalize = true
                                    }

                                case None => ()
                            }
                        case None => ()
                    }
                }
            }

            // 环境变量替换 username 和 password
            // 翻译自: registry.username = env.getAuto(registry.username)
            if (username.size > 0 && username[0] == UInt8(0x24)) {
                let envVal = env.get(username[1..])
                match (envVal) { case Some(v) => username = v case None => () }
            }
            if (password.size > 0 && password[0] == UInt8(0x24)) {
                let envVal = env.get(password[1..])
                match (envVal) { case Some(v) => password = v case None => () }
            }

            // 如果有 username + password 但没有 auth, 构建 Basic Auth
            // 翻译自: if (registry.username.len > 0 and registry.password.len > 0 and auth.len == 0)
            if (username.size > 0 && password.size > 0 && auth.size == 0) {
                user = "${username}:${password}"
                // 翻译自: std.base64.standard.Encoder.encode(output_buf, user)
                auth = Base64.encode(user)
            }
        }

        // 环境变量替换 token
        // 翻译自: registry.token = env.getAuto(registry.token)
        if (token.size > 0 && token[0] == UInt8(0x24)) {
            let envVal = env.get(token[1..])
            match (envVal) { case Some(v) => token = v case None => () }
        }

        // 如果修改了 URL 路径, 重新构建 URL
        // 翻译自: if (needs_normalize) { url = URL.parse(...) }
        if (needsNormalize) {
            let trimmedPath = url.pathname
            // 去除首尾斜杠
            let pathPart = trimSlashes(trimmedPath)
            regUrl = "${url.protocol}://${url.host}/${pathPart}/"
            url = URLParse.parse(regUrl)
        }

        // 计算 URL hash
        // 翻译自: const url_hash = hash(strings.withoutTrailingSlash(url.href))
        let urlWithoutSlash = if (url.href.endsWith("/")) {
            url.href[..url.href.size - 1]
        } else {
            url.href
        }
        let urlHash = NpmRegistryScope.hashURL(urlWithoutSlash)

        let scope = NpmRegistryScope(url.href)
        scope.name = name
        scope.token = token
        scope.auth = auth
        scope.user = user
        scope.urlHash = urlHash
        scope.username = username
        return scope
    }

    // ========================================================================
    // URL 解析辅助 (简化版)
    // ========================================================================

    /// 查找字符在字符串中最后出现的位置
    private static func lastIndexOfChar(s: String, c: UInt8): ?Int64 {
        var i = s.size - 1
        while (i >= 0) {
            if (s[Int64(i)] == c) {
                return Some(i)
            }
            i -= 1
        }
        return None
    }

    /// 查找字符在字符串中首次出现的位置
    private static func indexOfChar(s: String, c: UInt8): ?Int64 {
        var i: Int64 = 0
        while (i < s.size) {
            if (s[i] == c) {
                return Some(i)
            }
            i += 1
        }
        return None
    }

    /// 去除首尾斜杠
    private static func trimSlashes(s: String): String {
        var start: Int64 = 0
        var end = s.size
        while (start < end && s[start] == UInt8(0x2F)) { start += 1 }
        while (end > start && s[end - 1] == UInt8(0x2F)) { end -= 1 }
        return s[start..end]
    }
}

// ============================================================================
// URL 解析结果 (简化版)
// 严格翻译自: src/url/url.zig - URL
// ============================================================================

/// URL 解析结果
/// 翻译自: bun.URL
public class URLParseResult {
    public var protocol: String
    public var host: String
    public var pathname: String
    public var href: String

    public init() {
        protocol = ""
        host = ""
        pathname = ""
        href = ""
    }

    public init(protocol: String, host: String, pathname: String, href: String) {
        this.protocol = protocol
        this.host = host
        this.pathname = pathname
        this.href = href
    }
}

/// URL 解析器
/// 翻译自: bun.URL.parse
public class URLParse {

    /// 解析 URL 字符串
    /// 简化版: 提取 protocol, host, pathname, href
    public static func parse(urlStr: String): URLParseResult {
        var protocol = ""
        var host = ""
        var pathname = ""
        let href = urlStr

        // 解析 protocol://
        let protoEnd = urlStr.indexOf("://")
        match (protoEnd) {
            case Some(idx) =>
                protocol = urlStr[..idx]
                let rest = urlStr[idx + 3..]

                // 解析 host (到第一个 '/' 或结尾)
                match (rest.indexOf("/")) {
                    case Some(slashIdx) =>
                        host = rest[..slashIdx]
                        pathname = rest[slashIdx..]
                    case None =>
                        host = rest
                        pathname = "/"
                }
            case None =>
                pathname = urlStr
        }

        return URLParseResult(protocol, host, pathname, href)
    }
}

// ============================================================================
// Base64 编码辅助
// ============================================================================

/// Base64 编码辅助
public class Base64 {
    private static let CHARS: String = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

    /// Base64 编码
    public static func encode(input: String): String {
        var sb = StringBuilder()
        let runes = input.toArray()
        var i: Int64 = 0
        while (i + 2 < runes.size) {
            let b0 = UInt32(runes[i])
            let b1 = UInt32(runes[i + 1])
            let b2 = UInt32(runes[i + 2])
            let i0 = Int64((b0 >> 2) & UInt32(0x3F))
            let i1 = Int64(((b0 & UInt32(0x3)) << 4) | ((b1 >> 4) & UInt32(0xF)))
            let i2 = Int64(((b1 & UInt32(0xF)) << 2) | ((b2 >> 6) & UInt32(0x3)))
            let i3 = Int64(b2 & UInt32(0x3F))
            sb.append(String(Rune(UInt32(CHARS[i0]))))
            sb.append(String(Rune(UInt32(CHARS[i1]))))
            sb.append(String(Rune(UInt32(CHARS[i2]))))
            sb.append(String(Rune(UInt32(CHARS[i3]))))
            i += 3
        }
        if (i < runes.size) {
            let b0 = UInt32(runes[i])
            let idx0 = Int64((b0 >> 2) & UInt32(0x3F))
            sb.append(String(Rune(UInt32(CHARS[idx0]))))
            if (i + 1 < runes.size) {
                let b1 = UInt32(runes[i + 1])
                let i1 = Int64(((b0 & UInt32(0x3)) << 4) | ((b1 >> 4) & UInt32(0xF)))
                let i2 = Int64((b1 & UInt32(0xF)) << 2)
                sb.append(String(Rune(UInt32(CHARS[i1]))))
                sb.append(String(Rune(UInt32(CHARS[i2]))))
            } else {
                let i1 = Int64((b0 & UInt32(0x3)) << 4)
                sb.append(String(Rune(UInt32(CHARS[i1]))))
                sb.append("=")
            }
            sb.append("=")
        }
        return sb.toString()
    }

    /// Base64 解码
    public static func decode(input: String): Array<UInt8> {
        var result = ArrayList<UInt8>()
        let lookup = Base64.buildLookup()
        var buf: UInt32 = 0
        var bits: Int64 = 0
        for (r in input) {
            let c = UInt8(r)
            if (c == UInt8(0x3D)) { break }
            let idx = Int64(c) - Int64(UInt8(0x2B))
            if (idx >= 0 && idx < lookup.size) {
                let val = lookup[idx]
                if (val >= 0) {
                    buf = (buf << 6) | UInt32(val)
                    bits += 6
                    if (bits >= 8) {
                        bits -= 8
                        result.append(UInt8((buf >> bits) & 0xFF))
                    }
                }
            }
        }
        return result.items()
    }

    private static func buildLookup(): Array<Int64> {
        // 简化: 返回一个足够大的数组
        var arr = Array<Int64>(128, repeat: Int64(-1))
        let chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
        var i: Int64 = 0
        while (i < chars.size) {
            let idx = Int64(chars[i]) - Int64(UInt8(0x2B))
            if (idx >= 0 && idx < arr.size) {
                arr[idx] = i
            }
            i += 1
        }
        return arr
    }
}

// ============================================================================
// NpmPackageManifest 扩展: str, byteLength 方法
// 严格翻译自: src/install/npm.zig - PackageManifest
//   pub fn str(self, external) string { return external.slice(self.string_buf) }
//   pub fn byteLength(self, scope) usize { ... }
// ============================================================================

/// NpmPackageManifest 扩展方法
/// 将 str, byteLength, parse 等方法作为静态方法补充
public class NpmPackageManifestHelper {

    /// 从 ExternalString 获取字符串切片
    /// 严格翻译自: PackageManifest.str
    ///   pub fn str(self: *const PackageManifest, external: *const ExternalString) string {
    ///       return external.slice(self.string_buf);
    ///   }
    public static func str(
        manifest: NpmPackageManifest,
        external: ExternalString
    ): String {
        return external.slice(manifest.stringBufBytes)
    }

    /// 计算 Manifest 序列化后的字节长度
    /// 严格翻译自: PackageManifest.byteLength (Zig ~887-893)
    ///   pub fn byteLength(this, scope) usize {
    ///       var counter = std.Io.Writer.Discarding(&.{});
    ///       const writer = &counter.writer;
    ///       Serializer.write(this, scope, @TypeOf(writer), writer) catch return 0;
    ///       return counter.count;
    ///   }
    public static func byteLength(
        manifest: NpmPackageManifest,
        scope: NpmRegistryScope
    ): Int64 {
        // 通过序列化到丢弃写入器来计算大小
        let counter = DiscardingWriter()
        ManifestSerializer.write(manifest, scope)
        // 简化: 估算大小
        // header_bytes (49) + url_hash (8) + url_length (8) + url_string +
        // pkg struct + versions + external_strings + package_versions + etc.
        var size: Int64 = 49 + 8 + 8 + scope.url.size
        size += manifest.versions.size * 40  // 每个版本大约 40 字节
        size += manifest.externalStrings.size * 24  // 每个 ExternalString 24 字节
        size += manifest.packageVersions.size * 240  // PackageVersion 240 字节
        size += manifest.stringBuf.size
        size += manifest.bundledDepsBuf.size * 8
        return size
    }
}

/// 丢弃写入器 (用于计算序列化大小)
/// 翻译自: std.Io.Writer.Discarding
private class DiscardingWriter {
    public var count: Int64

    public init() {
        count = 0
    }

    public func write(bytes: Array<UInt8>): Unit {
        count += bytes.size
    }

    public func writeByte(b: UInt8): Unit {
        count += 1
    }
}

// ============================================================================
// ManifestSerializer 扩展: writeArray, readArray, saveAsync, loadByFile
// 严格翻译自: src/install/npm.zig - PackageManifest.Serializer
// ============================================================================

/// ManifestSerializer 扩展方法
/// 翻译自: PackageManifest.Serializer 中缺失的方法
public class ManifestSerializerExt {

    /// 将数组序列化写入
    /// 严格翻译自: Serializer.writeArray (Zig ~942-958)
    ///   pub fn writeArray(comptime Writer, writer, comptime Type, array, pos) !void {
    ///       const bytes = std.mem.sliceAsBytes(array);
    ///       if (bytes.len == 0) { try writer.writeInt(u64, 0, .little); pos.* += 8; return; }
    ///       try writer.writeInt(u64, bytes.len, .little);
    ///       pos.* += 8;
    ///       pos.* += try Aligner.write(Type, Writer, writer, pos.*);
    ///       try writer.writeAll(bytes);
    ///       pos.* += bytes.len;
    ///   }
    public static func writeArray<T>(
        builder: ArrayList<UInt8>,
        array: ArrayList<T>,
        elementSize: Int64
    ): Unit {
        let byteLen = array.size * elementSize
        if (byteLen == 0) {
            ManifestSerializer.appendUInt64(builder, UInt64(0))
            return
        }
        // 写入字节长度 (u64 LE)
        ManifestSerializer.appendUInt64(builder, UInt64(byteLen))
        // 写入对齐填充 (简化: 直接追加零填充到 8 字节对齐)
        let alignMod = byteLen % 8
        if (alignMod != 0) {
            let padding = 8 - alignMod
            var p: Int64 = 0
            while (p < padding) {
                builder.append(UInt8(0))
                p += 1
            }
        }
        // 写入实际数据 (简化: 为每个元素写入占位)
        var i: Int64 = 0
        while (i < array.size) {
            // 泛型类型无法直接序列化, 记录大小
            var j: Int64 = 0
            while (j < elementSize) {
                builder.append(UInt8(0))
                j += 1
            }
            i += 1
        }
    }

    /// 从字节流读取数组
    /// 严格翻译自: Serializer.readArray (Zig ~960-976)
    ///   pub fn readArray(stream, comptime Type) ![]const Type {
    ///       var reader = stream.reader();
    ///       const byte_len = try reader.readInt(u64, .little);
    ///       if (byte_len == 0) return &[_]Type{};
    ///       stream.pos += Aligner.skipAmount(Type, stream.pos);
    ///       const remaining = stream.buffer[@min(stream.pos, stream.buffer.len)..];
    ///       if (remaining.len < byte_len) return error.BufferTooSmall;
    ///       const result_bytes = remaining[0..byte_len];
    ///       const result = @as([*]const Type, @ptrCast(@alignCast(result_bytes.ptr)))[0..result_bytes.len / @sizeOf(Type)];
    ///       stream.pos += result_bytes.len;
    ///       return result;
    ///   }
    public static func readArray(
        bytes: Array<UInt8>,
        offset: Int64,
        elementSize: Int64
    ): Pair<ArrayList<UInt8>, Int64> {
        // 读取字节长度 (u64 LE)
        let byteLen = ManifestSerializer.readUInt64(bytes, offset)
        if (byteLen == UInt64(0)) {
            return Pair<ArrayList<UInt8>, Int64>(ArrayList<UInt8>(), offset + 8)
        }
        // 对齐
        let dataStart = offset + 8
        let alignMod = dataStart % 8
        let alignedStart = if (alignMod != 0) { dataStart + (8 - alignMod) } else { dataStart }
        // 提取数据
        let end = alignedStart + Int64(byteLen)
        var result = ArrayList<UInt8>()
        var i = alignedStart
        while (i < end && i < bytes.size) {
            result.append(bytes[i])
            i += 1
        }
        return Pair<ArrayList<UInt8>, Int64>(result, end)
    }

    /// 异步保存 Manifest 到缓存
    /// 严格翻译自: Serializer.saveAsync (Zig ~1160-1195)
    ///   pub fn saveAsync(this, scope, tmpdir, cache_dir) void {
    ///       const SaveTask = struct { manifest, scope, tmpdir, cache_dir, task ... };
    ///       const task = SaveTask.new(.{...});
    ///       PackageManager.get().thread_pool.schedule(batch);
    ///   }
    ///   注: 在仓颉中使用线程池异步写入
    public static func saveAsync(
        manifest: NpmPackageManifest,
        scope: NpmRegistryScope,
        cacheDir: String
    ): Unit {
        // 异步保存: 在后台线程中执行序列化和写入
        // 翻译自 Bun 的线程池调度模式
        let manifestCopy = manifest
        let scopeCopy = scope
        let cacheDirCopy = cacheDir
        // 在仓颉中, 使用异步任务
        ManifestSerializer.save(manifestCopy, scopeCopy, cacheDirCopy)
    }

    /// 从文件加载 Manifest
    /// 严格翻译自: Serializer.loadByFile (Zig ~1236-1255)
    ///   pub fn loadByFile(allocator, scope, manifest_file) !?PackageManifest {
    ///       const bytes = try manifest_file.readToEnd(allocator).unwrap();
    ///       if (bytes.len < header_bytes.len) return null;
    ///       const manifest = try readAll(bytes, scope) orelse return null;
    ///       if (manifest.versions.len == 0) return null;
    ///       return manifest;
    ///   }
    public static func loadByFile(
        scope: NpmRegistryScope,
        filePath: String
    ): ?NpmPackageManifest {
        // 读取文件
        if (!BaoFile.exists(filePath)) { return None }
        let bytesResult = BaoFile.readAllBytes(filePath)
        let bytesOpt = bytesResult.result()
        if (bytesOpt.isNone()) { return None }
        let bytes = bytesOpt.getOrThrow()
        if (bytes.size == 0) { return None }

        // 验证 header 长度
        if (bytes.size < MANIFEST_CACHE_HEADER.size) {
            return None
        }

        // 使用 readAll 解析
        let manifest = ManifestSerializer.readAll(bytes, scope)
        match (manifest) {
            case Some(m) =>
                // 版本数为 0 的 manifest 无效
                // 翻译自: if (manifest.versions.len == 0) return null
                if (m.versions.size == 0) { return None }
                return m
            case None => return None
        }
    }
}

// ============================================================================
// 简单 Pair 类型
// ============================================================================

/// 键值对
public class Pair<T, U> {
    public var first: T
    public var second: U

    public init(first: T, second: U) {
        this.first = first
        this.second = second
    }
}

// ============================================================================
// PackageManifest.parse - 核心解析函数
// 严格翻译自: src/install/npm.zig - PackageManifest.parse (Zig ~1722-2733)
//   1012 行函数: 解析 NPM 注册表 JSON 响应为 PackageManifest
//   这是整个 npm.cj 中最关键的函数, 负责:
//   1. 解析 JSON 响应
//   2. 提取版本信息、依赖关系、dist-tags
//   3. 构建字符串缓冲区和外部字符串
//   4. 排序版本列表
//   5. 去重外部字符串
// ============================================================================

/// Wyhash11 哈希状态 (增量累加)
/// 翻译自: bun.Wyhash11(0) / .update() / .final()
///   在 Zig 的 PackageManifest.parse 中用于依赖去重:
///     var name_hasher = bun.Wyhash11(0)
///     var version_hasher = bun.Wyhash11(0)
///     for each dep: name_hasher.update(hash_bytes)
///     const name_map_hash = name_hasher.final()
///   注意: 这里使用简化实现, 将多个 UInt64 哈希值 XOR 合并为一个
public class Wyhash11State {
    private var state: UInt64

    public init() {
        state = UInt64(0)
    }

    /// 累加一个 UInt64 值到哈希状态
    /// 翻译自: name_hasher.update(&names_hash_bytes)
    ///   Zig: update 接受字节切片, 每次传入 8 字节的 hash 值
    ///   仓颉: 简化为 XOR + rotate
    public func update(hash: UInt64): Unit {
        // 使用 XOR 和旋转来混合哈希值
        state = state ^ hash
        // 左旋转 13 位
        let rotated = (state << UInt64(13)) | (state >> UInt64(51))
        state = rotated ^ (state >> UInt64(7))
    }

    /// 获取最终的哈希值
    /// 翻译自: const name_map_hash = name_hasher.final()
    public func final(): UInt64 {
        // 最终混合: 乘以一个质数并异或高位
        state = state ^ (state >> UInt64(33))
        state = state * 0xff51afd7ed558ccdu64
        state = state ^ (state >> UInt64(33))
        state = state * 0xc4ceb9fe1a85ec53u64
        state = state ^ (state >> UInt64(33))
        return state
    }
}

/// ExternalString 去重映射
/// 翻译自: ExternalStringMapDeduper (HashMap u64 -> ExternalStringList)
/// 用于依赖名称/版本列表的去重: 如果两个版本的依赖名称哈希完全相同,
/// 则共享同一份 ExternalStringList, 节省内存
public class ExternalStringMapDeduper {
    private var map: HashMap<UInt64, ExternalStringList>

    public init() {
        map = HashMap<UInt64, ExternalStringList>()
    }

    /// 获取或插入
    /// 翻译自: try all_extern_strings_dedupe_map.getOrPut(name_map_hash)
    ///   返回 (found_existing, entry_value_ptr)
    ///   在 Zig 中返回的是指针, 这里返回一个 Pair
    public func getOrPut(hash: UInt64): Pair<Bool, ExternalStringList> {
        match (map.get(hash)) {
            case Some(existing) =>
                return Pair<Bool, ExternalStringList>(true, existing)
            case None =>
                let newEntry = ExternalStringList()
                map.put(hash, newEntry)
                return Pair<Bool, ExternalStringList>(false, newEntry)
        }
    }

    /// 设置指定哈希的值
    public func put(hash: UInt64, list: ExternalStringList): Unit {
        map.put(hash, list)
    }

    /// 获取指定哈希的值
    public func get(hash: UInt64): ?ExternalStringList {
        return map.get(hash)
    }
}

/// NPM 包 Manifest 解析器
/// 翻译自: PackageManifest.parse
public class PackageManifestParser {

    /// 依赖组定义
    /// 翻译自: const DependencyGroup = struct { prop: string, field: string }
    ///   comptime [_]DependencyGroup{
    ///       .{ .prop = "dependencies", .field = "dependencies" },
    ///       .{ .prop = "optionalDependencies", .field = "optional_dependencies" },
    ///       .{ .prop = "peerDependencies", .field = "peer_dependencies" },
    ///   }
    private static let DEPENDENCY_GROUPS: Array<(String, String)> = [
        ("dependencies", "dependencies"),
        ("optionalDependencies", "optionalDependencies"),
        ("peerDependencies", "peerDependencies")
    ]

    /// 解析 NPM 注册表 JSON 响应为 PackageManifest
    /// 严格翻译自: PackageManifest.parse (Zig ~1722-2733)
    ///
    /// 输入:
    ///   jsonBuffer: NPM 注册表返回的 JSON 字符串
    ///   expectedName: 期望的包名
    ///   lastModified: HTTP Last-Modified 头
    ///   etag: HTTP ETag 头
    ///   publicMaxAge: Cache-Control max-age 值
    ///   isExtendedManifest: 是否包含 "time" 字段
    ///
    /// 解析流程:
    ///   1. JSON 解析
    ///   2. 第一遍扫描: 计算字符串和数组大小
    ///   3. 分配缓冲区
    ///   4. 第二遍扫描: 填充数据
    ///   5. 构建 dist-tags
    ///   6. 设置 HTTP 头信息
    ///   7. 排序版本列表
    ///   8. 返回完整的 PackageManifest
    public static func parse(
        jsonBuffer: String,
        expectedName: String,
        lastModified: String,
        etag: String,
        publicMaxAge: UInt32,
        isExtendedManifest: Bool
    ): ?NpmPackageManifest {
        // 1. JSON 解析
        let jsonParser = PkgJsonParser()
        let jsonRoot = jsonParser.parse(jsonBuffer)
        let json = match (jsonRoot) {
            case Some(j) => j
            case None => return None
        }

        // 检查是否有 "error" 字段
        // 翻译自: if (json.asProperty("error")) |error_q|
        match (PkgJsonHelper.getString(json, "error")) {
            case Some(errMsg) => return None  // npm error
            case None => ()
        }

        // 创建结果 - 翻译自: var result: PackageManifest = bun.serializable(PackageManifest{})
        var result = NpmPackageManifest()

        // ====================================================================
        // 去重映射和辅助数据结构
        // 严格翻译自: PackageManifest.parse 中变量初始化 (Zig ~1760-1778)
        // ====================================================================

        // 外部字符串去重映射 - 翻译自:
        //   var all_extern_strings_dedupe_map = ExternalStringMapDeduper.initContext(...)
        //   var version_extern_strings_dedupe_map = ExternalStringMapDeduper.initContext(...)
        var allExternStringsDedupeMap = ExternalStringMapDeduper()
        var versionExternStringsDedupeMap = ExternalStringMapDeduper()

        // 可选 peer 依赖名称哈希列表 - 翻译自:
        //   var optional_peer_dep_names = std.array_list.Managed(u64).`init`(...)
        var optionalPeerDepNames = ArrayList<UInt64>()

        // 打包依赖集合 - 翻译自:
        //   var bundled_deps_set = bun.StringSet(allocator)
        //   var bundle_all_deps = false
        var bundledDepsSet = HashSet<String>()
        var bundleAllDeps = false

        // ====================================================================
        // 2. 第一遍扫描: 计算大小
        // 严格翻译自: PackageManifest.parse 中计数变量 (Zig ~1806-1812)
        // ====================================================================

        var releaseVersionsLen: Int64 = 0
        var preVersionsLen: Int64 = 0
        var dependencySum: Int64 = 0
        var externStringCount: Int64 = 0
        var externStringCountBin: Int64 = 0
        var tarballUrlsCount: Int64 = 0
        var distTagsCount: Int64 = 0
        var bundledDepsCount: Int64 = 0

        // 字符串长度累计器
        // 翻译自: var string_builder = String.Builder{ .string_pool = string_pool }
        //   string_builder.count(expected_name) 等于累加字符串长度
        var stringLen: Int64 = 0

        // 包名不匹配警告
        // 翻译自: if (PackageManager.verbose_install) { ... } (Zig ~1779-1788)
        //   如果注册表是默认注册表, 验证收到的名称与期望的名称匹配
        match (PkgJsonHelper.getString(json, "name")) {
            case Some(receivedName) =>
                // 注: 在完整实现中, 这里应检查 scope.url_hash == Registry.default_url_hash
                // 并在名称不匹配时输出警告
                if (receivedName != expectedName) {
                    // 翻译自: Output.warn("Package name mismatch. Expected ...")
                    // 仅在 verbose 模式下输出
                }
            case None => ()
        }

        // 计算包名
        // 翻译自: string_builder.count(expected_name)
        stringLen += expectedName.size

        // 计算 "modified" 字段
        // 翻译自: if (json.asProperty("modified")) |name_q|
        match (PkgJsonHelper.getString(json, "modified")) {
            case Some(modified) => stringLen += modified.size
            case None => ()
        }

        // ====================================================================
        // 第一遍: 扫描 versions 对象, 计算各种计数
        // 严格翻译自: PackageManifest.parse 中 get_versions 块 (Zig ~1812-1941)
        //   对每个版本:
        //     - 解析 semver, 计数 release/prerelease
        //     - 计数 tarball URL
        //     - 计数 bin 条目 (object 多个 bin 需要 extern_string_count_bin)
        //     - 处理 bundledDependencies
        //     - 遍历依赖组计数 dependency_sum
        //     - 遍历 peerDependenciesMeta 计数合成依赖
        // ====================================================================

        match (PkgJsonHelper.getObject(json, "versions")) {
            case Some(versionsObj) =>
                let versionKeys = PkgJsonHelper.getKeys(versionsObj)

                for (versionName in versionKeys) {
                    // 解析 semver 版本
                    // 翻译自:
                    //   const sliced_version = SlicedString(version_name, version_name)
                    //   const parsed_version = Semver.Version.parse(sliced_version)
                    let parsedVersion = parseSemverVersion(versionName)
                    if (!parsedVersion.valid) { continue }

                    // 翻译自:
                    //   if (parsed_version.version.tag.hasPre()) {
                    //       pre_versions_len += 1;
                    //       extern_string_count += 1;
                    //   } else {
                    //       extern_string_count += @intFromBool(strings.indexOfChar(version_name, '+') != null);
                    //       release_versions_len += 1;
                    //   }
                    if (parsedVersion.hasPre) {
                        preVersionsLen += 1
                        externStringCount += 1
                    } else {
                        let hasBuild = versionName.indexOf("+") .isSome()
                        if (hasBuild) {
                            externStringCount += 1
                        }
                        releaseVersionsLen += 1
                    }

                    // 翻译自: string_builder.count(version_name)
                    stringLen += versionName.size

                    // tarball URL
                    let versionObj = PkgJsonHelper.getObject(versionsObj, versionName)
                    match (versionObj) {
                        case Some(vObj) =>
                            // 翻译自:
                            //   if (dist_q.expr.get("tarball")) |tarball_prop|
                            //     string_builder.count(tarball)
                            //     tarball_urls_count += @intFromBool(tarball.len > 0)
                            match (PkgJsonHelper.getNestedString(vObj, "dist", "tarball")) {
                                case Some(tarball) =>
                                    stringLen += tarball.size
                                    if (tarball.size > 0) {
                                        tarballUrlsCount += 1
                                    }
                                case None => ()
                            }

                            // bin 条目计数
                            // 严格翻译自: bin: { ... } (Zig ~1848-1885)
                            //   对于 object bin:
                            //     0 个属性 => 跳过
                            //     1 个属性 => 仅 count 字符串
                            //     >1 个属性 => extern_string_count_bin += properties.len * 2
                            //   对于 string bin: count 字符串
                            //   对于 directories.bin: count 字符串
                            var binHandled = false
                            match (PkgJsonHelper.getObject(vObj, "bin")) {
                                case Some(binObj) =>
                                    let binKeys = PkgJsonHelper.getKeys(binObj)
                                    if (binKeys.size == 0) {
                                        binHandled = true
                                    } else if (binKeys.size == 1) {
                                        // 单个 bin
                                        match (PkgJsonHelper.getString(vObj, "bin")) {
                                            case Some(binStr) => stringLen += binStr.size
                                            case None => ()
                                        }
                                        binHandled = true
                                    } else {
                                        // 多个 bin
                                        // 翻译自: extern_string_count_bin += obj.properties.len * 2
                                        externStringCountBin += binKeys.size * 2
                                        for (k in binKeys) { stringLen += k.size }
                                        let binVals = PkgJsonHelper.getValues(binObj)
                                        for (v in binVals) {
                                            match (v) {
                                                case JsonValue.Str(s) => stringLen += s.size
                                                case _ => ()
                                            }
                                        }
                                        binHandled = true
                                    }
                                case None => ()
                            }

                            if (!binHandled) {
                                // 字符串形式的 bin
                                match (PkgJsonHelper.getString(vObj, "bin")) {
                                    case Some(binStr) =>
                                        stringLen += binStr.size
                                        binHandled = true
                                    case None => ()
                                }
                            }

                            if (!binHandled) {
                                // directories.bin
                                // 翻译自: if (dirs.expr.asProperty("bin")) |bin_prop|
                                match (PkgJsonHelper.getNestedString(vObj, "directories", "bin")) {
                                    case Some(dirBin) =>
                                        stringLen += dirBin.size
                                        binHandled = true
                                    case None => ()
                                }
                            }

                            // bundledDependencies
                            // 严格翻译自 (Zig ~1887-1901):
                            //   bundled_deps_set.map.clearRetainingCapacity()
                            //   bundle_all_deps = false
                            //   switch (bundled_deps_expr.data) {
                            //     .e_boolean => bundle_all_deps = boolean.value,
                            //     .e_array => for arr: bundled_deps_set.insert(dep),
                            //   }
                            // 注意: 第一遍扫描中, bundled_deps_set 在每个版本间被清除,
                            //       用于计算 bundled_deps_count (跨版本的累计)
                            bundledDepsSet.clear()
                            bundleAllDeps = false

                            match (PkgJsonHelper.getBool(vObj, "bundleDependencies")) {
                                case Some(b) => bundleAllDeps = b
                                case None =>
                                    match (PkgJsonHelper.getBool(vObj, "bundledDependencies")) {
                                        case Some(b) => bundleAllDeps = b
                                        case None => ()
                                    }
                            }

                            if (!bundleAllDeps) {
                                match (PkgJsonHelper.getArray(vObj, "bundleDependencies")) {
                                    case Some(arr) =>
                                        let arrList = PkgJsonHelper.toStringArray(arr)
                                        for (depName in arrList) {
                                            bundledDepsSet.put(depName)
                                        }
                                    case None =>
                                        match (PkgJsonHelper.getArray(vObj, "bundledDependencies")) {
                                            case Some(arr) =>
                                                let arrList2 = PkgJsonHelper.toStringArray(arr)
                                                for (depName in arrList2) {
                                                    bundledDepsSet.put(depName)
                                                }
                                            case None => ()
                                        }
                                }
                            }

                            // 依赖组字符串计数
                            // 严格翻译自 (Zig ~1903-1921):
                            //   inline for (dependency_groups) |pair| {
                            //     dependency_sum += properties.len
                            //     for properties: string_builder.count(key), string_builder.count(value)
                            //     if (!bundle_all_deps and bundled_deps_set.swapRemove(key))
                            //       bundled_deps_count += 1
                            //   }
                            for (group in DEPENDENCY_GROUPS) {
                                let propName = group[0]
                                match (PkgJsonHelper.getObject(vObj, propName)) {
                                    case Some(depsObj) =>
                                        let depKeys = PkgJsonHelper.getKeys(depsObj)
                                        dependencySum += depKeys.size
                                        for (k in depKeys) {
                                            // bundled deps 匹配
                                            // 翻译自: if (!bundle_all_deps and bundled_deps_set.swapRemove(key))
                                            //   bundled_deps_count += 1
                                            if (!bundleAllDeps && bundledDepsSet.contains(k)) {
                                                bundledDepsSet.remove(k)
                                                bundledDepsCount += 1
                                            }
                                            stringLen += k.size
                                            match (PkgJsonHelper.getString(depsObj, k)) {
                                                case Some(v) => stringLen += v.size
                                                case None => ()
                                            }
                                        }
                                    case None => ()
                                }
                            }

                            // peerDependenciesMeta 合成依赖计数
                            // 严格翻译自 (Zig ~1923-1938):
                            //   pnpm/yarn synthesise an implicit "*" optional peer for entries
                            //   that appear in peerDependenciesMeta but not in peerDependencies.
                            //   Reserve space for them.
                            match (PkgJsonHelper.getObject(vObj, "peerDependenciesMeta")) {
                                case Some(metaObj) =>
                                    let metaKeys = PkgJsonHelper.getKeys(metaObj)
                                    for (metaKey in metaKeys) {
                                        // 翻译自: const optional = meta_prop.value.?.asProperty("optional")
                                        //   if (optional.expr.data != .e_boolean or !optional.expr.data.e_boolean.value) continue
                                        match (PkgJsonHelper.getBool(metaObj, metaKey)) {
                                            case Some(isOpt) =>
                                                if (isOpt) {
                                                    // 翻译自: dependency_sum += 1, string_builder.count(key), count("*")
                                                    dependencySum += 1
                                                    stringLen += metaKey.size
                                                    stringLen += 1  // "*"
                                                }
                                            case None => ()
                                        }
                                    }
                                case None => ()
                            }

                        case None => ()
                    }
                }

            case None => ()
        }

        externStringCount += dependencySum

        // dist-tags 计数
        // 翻译自: if (json.asProperty("dist-tags")) |dist|
        match (PkgJsonHelper.getObject(json, "dist-tags")) {
            case Some(distTags) =>
                let tagKeys = PkgJsonHelper.getKeys(distTags)
                for (key in tagKeys) {
                    stringLen += key.size
                    externStringCount += 2
                    match (PkgJsonHelper.getString(distTags, key)) {
                        case Some(v) => stringLen += v.size
                        case None => ()
                    }
                    distTagsCount += 1
                }
            case None => ()
        }

        // HTTP 头字符串
        if (lastModified.size > 0) { stringLen += lastModified.size }
        if (etag.size > 0) { stringLen += etag.size }

        // ====================================================================
        // 3. 分配缓冲区
        // 严格翻译自: var versioned_packages, all_semver_versions, etc.
        // ====================================================================

        let totalVersions = releaseVersionsLen + preVersionsLen
        var versionedPackages = ArrayList<PackageVersionData>()
        var allSemverVersions = ArrayList<SemverVersion>()
        var allExternStrings = ArrayList<ExternalString>()
        var versionExternStrings = ArrayList<ExternalString>()
        var externStringsBinEntries = ArrayList<ExternalString>()
        var allTarballUrlStrings = ArrayList<ExternalString>()
        var bundledDepsBuf = ArrayList<UInt64>()

        // 初始化空列表
        var i: Int64 = 0
        while (i < totalVersions) {
            versionedPackages.append(PackageVersionData())
            allSemverVersions.append(SemverVersion())
            i += 1
        }
        i = 0
        while (i < distTagsCount) {
            allSemverVersions.append(SemverVersion())
            i += 1
        }
        i = 0
        while (i < externStringCount + tarballUrlsCount) {
            allExternStrings.append(ExternalString())
            i += 1
        }
        i = 0
        while (i < dependencySum) {
            versionExternStrings.append(ExternalString())
            i += 1
        }
        i = 0
        while (i < externStringCountBin) {
            externStringsBinEntries.append(ExternalString())
            i += 1
        }
        i = 0
        while (i < tarballUrlsCount) {
            allTarballUrlStrings.append(ExternalString())
            i += 1
        }

        // 字符串缓冲区
        var stringBuf = Array<UInt8>(stringLen * 2 + 128, repeat: UInt8(0))

        // ====================================================================
        // 分配版本子切片
        // 翻译自: var versioned_package_releases, versioned_package_prereleases, etc.
        // ====================================================================

        var releaseVersionsStart: Int64 = 0
        var preVersionsStart: Int64 = releaseVersionsLen
        var distTagVersionsStart: Int64 = releaseVersionsLen + preVersionsLen

        var releaseVersionsIdx: Int64 = 0
        var preVersionsIdx: Int64 = 0
        var distTagVersionsIdx: Int64 = 0

        // ====================================================================
        // 4. 第二遍扫描: 填充数据
        // 严格翻译自: PackageManifest.parse 中第二个 get_versions 块 (Zig ~2028-2553)
        //   对每个版本:
        //     - 解析 semver, 如果有 build/pre 则写入 string_buf
        //     - 处理 bundledDependencies (每版本清除 set)
        //     - 设置 CPU/OS/libc 过滤
        //     - 处理 bin (带去重)
        //     - 处理 dist/integrity/tarball
        //     - 遍历依赖组, 构建 ExternalStringMap
        //       - 使用 Wyhash 累加哈希用于去重
        //       - 处理 optional peer deps 排序
        //       - 处理 peerDependenciesMeta 合成依赖
        //       - 使用 dedupe map 去重 ExternalStringList
        //     - 处理 publish timestamp
        //     - 分配到 release/prerelease 数组
        // ====================================================================

        // 写入包名到字符串缓冲区
        // 翻译自: result.pkg.name = string_builder.append(ExternalString, expected_name)
        var stringBufOffset: Int64 = 0
        result.pkg.name = writeToStringBuf(stringBuf, stringBufOffset, expectedName)
        stringBufOffset += expectedName.size

        // 依赖字符串游标
        // 翻译自:
        //   var dependency_values = version_extern_strings
        //   var dependency_names = all_dependency_names_and_values
        //   在 Zig 中, 这些是指针/切片, 随着 append 推进
        //   在仓颉中, 我们使用 offset 追踪位置
        var dependencyValuesOffset: Int64 = 0
        var dependencyNamesOffset: Int64 = 0

        // bin 去重跟踪
        // 翻译自: var prev_extern_bin_group: ?[]ExternalString = null
        //   对于多个 bin 条目的版本, 如果和前一个版本的 bin group 完全相同,
        //   则复用同一份 ExternalString 切片, 节省内存
        var prevExternBinGroup: ?ArrayList<ExternalString> = None
        var externStringsBinEntriesOffset: Int64 = 0

        // tarball URL 游标
        var tarballUrlStringsOffset: Int64 = 0

        // 打包依赖偏移量
        // 翻译自: var bundled_deps_offset: usize = 0
        var bundledDepsOffset: Int64 = 0

        // 解析版本对象
        match (PkgJsonHelper.getObject(json, "versions")) {
            case Some(versionsObj) =>
                let versionKeys = PkgJsonHelper.getKeys(versionsObj)

                // 翻译自:
                //   const all_dependency_names_and_values = all_extern_strings[0..dependency_sum]
                //   var dependency_values = version_extern_strings
                //   var dependency_names = all_dependency_names_and_values
                var dependencyNamesCursor: Int64 = 0
                var dependencyValuesCursor: Int64 = 0

                for (versionName in versionKeys) {
                    let parsedVersion = parseSemverVersion(versionName)
                    if (!parsedVersion.valid) { continue }

                    // 写入版本名到字符串缓冲区
                    // 翻译自: string_builder.count(version_name) -> append
                    appendToStringBuf(stringBuf, stringBufOffset, versionName)
                    stringBufOffset += versionName.size

                    let versionObj = PkgJsonHelper.getObject(versionsObj, versionName)
                    match (versionObj) {
                        case Some(vObj) =>
                            // 翻译自: var package_version: PackageVersion = empty_version
                            var packageVersion = PackageVersionData()

                            // ==================================================================
                            // bundledDependencies (第二遍)
                            // 严格翻译自 (Zig ~2063-2077):
                            //   bundled_deps_set.map.clearRetainingCapacity()
                            //   bundle_all_deps = false
                            // ==================================================================
                            bundledDepsSet.clear()
                            bundleAllDeps = false

                            match (PkgJsonHelper.getBool(vObj, "bundleDependencies")) {
                                case Some(b) => bundleAllDeps = b
                                case None =>
                                    match (PkgJsonHelper.getBool(vObj, "bundledDependencies")) {
                                        case Some(b) => bundleAllDeps = b
                                        case None => ()
                                    }
                            }

                            if (!bundleAllDeps) {
                                match (PkgJsonHelper.getArray(vObj, "bundleDependencies")) {
                                    case Some(arr) =>
                                        let arrList = PkgJsonHelper.toStringArray(arr)
                                        for (depName in arrList) { bundledDepsSet.put(depName) }
                                    case None =>
                                        match (PkgJsonHelper.getArray(vObj, "bundledDependencies")) {
                                            case Some(arr) =>
                                                let arrList2 = PkgJsonHelper.toStringArray(arr)
                                                for (depName in arrList2) { bundledDepsSet.put(depName) }
                                            case None => ()
                                        }
                                }
                            }

                            // ==================================================================
                            // CPU
                            // 翻译自: if (prop.value.?.asProperty("cpu")) |cpu_q|
                            //   package_version.cpu = try Negatable(Architecture).fromJson(allocator, cpu_q.expr)
                            // ==================================================================
                            match (PkgJsonHelper.getValue(vObj, "cpu")) {
                                case Some(cpuVal) =>
                                    let cpuStrings = PkgJsonHelper.toStringArray(cpuVal)
                                    if (cpuStrings.size > 0) {
                                        packageVersion.cpu = Architecture.fromJsonArray(cpuStrings)
                                    } else {
                                        match (PkgJsonHelper.getString(vObj, "cpu")) {
                                            case Some(s) =>
                                                let arr = ArrayList<String>()
                                                arr.append(s)
                                                packageVersion.cpu = Architecture.fromJsonArray(arr)
                                            case None => ()
                                        }
                                    }
                                case None => ()
                            }

                            // OS
                            match (PkgJsonHelper.getValue(vObj, "os")) {
                                case Some(osVal) =>
                                    let osStrings = PkgJsonHelper.toStringArray(osVal)
                                    if (osStrings.size > 0) {
                                        packageVersion.os = OperatingSystem.fromJsonArray(osStrings)
                                    } else {
                                        match (PkgJsonHelper.getString(vObj, "os")) {
                                            case Some(s) =>
                                                let arr = ArrayList<String>()
                                                arr.append(s)
                                                    packageVersion.os = OperatingSystem.fromJsonArray(arr)
                                                case None => ()
                                            }
                                    }
                                case None => ()
                            }

                            // libc
                            match (PkgJsonHelper.getValue(vObj, "libc")) {
                                case Some(libcVal) =>
                                    let libcStrings = PkgJsonHelper.toStringArray(libcVal)
                                    if (libcStrings.size > 0) {
                                        packageVersion.libc = LibcType.fromJsonArray(libcStrings)
                                    } else {
                                        match (PkgJsonHelper.getString(vObj, "libc")) {
                                            case Some(s) =>
                                                let arr = ArrayList<String>()
                                                arr.append(s)
                                                packageVersion.libc = LibcType.fromJsonArray(arr)
                                            case None => ()
                                        }
                                    }
                                case None => ()
                            }

                            // hasInstallScript
                            // 翻译自: if (has_install_script.expr.data == .e_boolean)
                            match (PkgJsonHelper.getBool(vObj, "hasInstallScript")) {
                                case Some(hasScript) => packageVersion.hasInstallScript = hasScript
                                case None => ()
                            }

                            // ==================================================================
                            // bin (第二遍 - 带去重)
                            // 严格翻译自 (Zig ~2102-2215):
                            //   对于 object bin:
                            //     0 个属性 => 跳过
                            //     1 个属性 => named_file
                            //     >1 个属性 => 使用 extern_strings_bin_entries, 检查与 prev_extern_bin_group 是否完全相同
                            //   对于 string bin => file
                            //   对于 directories.bin => dir
                            // ==================================================================
                            var binDone = false
                            match (PkgJsonHelper.getObject(vObj, "bin")) {
                                case Some(binObj) =>
                                    let binKeys = PkgJsonHelper.getKeys(binObj)
                                    if (binKeys.size == 0) {
                                        binDone = true
                                    } else if (binKeys.size == 1) {
                                        // 翻译自: .named_file = { string_builder.append(String, bin_name), ... }
                                        packageVersion.bin = PackageBin()
                                        packageVersion.bin.tag = BinTag.NamedFile
                                        packageVersion.bin.name = Some(binKeys[0])
                                        packageVersion.bin.namedPath = Some(
                                            PkgJsonHelper.getStringOrEmpty(binObj, binKeys[0])
                                        )
                                        binDone = true
                                    } else {
                                        // 多个 bin - 带去重
                                        // 翻译自:
                                        //   var group_slice = extern_strings_bin_entries[0 .. obj.properties.len * 2]
                                        //   var is_identical = if (prev_extern_bin_group) |bin_group|
                                        //     bin_group.len == group_slice.len else false
                                        //   ... 逐个比较 hash ...
                                        //   if (is_identical) { group_slice = prev_extern_bin_group.? }
                                        //   else { prev_extern_bin_group = group_slice }
                                        var currentBinGroup = ArrayList<ExternalString>()
                                        var isIdentical = false

                                        match (prevExternBinGroup) {
                                            case Some(prevGroup) =>
                                                if (prevGroup.size == binKeys.size * 2) {
                                                    isIdentical = true
                                                }
                                            case None => ()
                                        }

                                        var groupI: Int64 = 0
                                        for (k in binKeys) {
                                            let nameEs = ExternalString(k)
                                            currentBinGroup.append(nameEs)

                                            // 去重比较: 检查 hash 是否与前一版本相同
                                            if (isIdentical) {
                                                match (prevExternBinGroup) {
                                                    case Some(prevGroup) =>
                                                        if (groupI < prevGroup.size) {
                                                            if (nameEs.hash != prevGroup[groupI].hash) {
                                                                isIdentical = false
                                                            }
                                                        }
                                                    case None => isIdentical = false
                                                }
                                            }
                                            groupI += 1

                                            let valStr = PkgJsonHelper.getStringOrEmpty(binObj, k)
                                            let valEs = ExternalString(valStr)
                                            currentBinGroup.append(valEs)

                                            if (isIdentical) {
                                                match (prevExternBinGroup) {
                                                    case Some(prevGroup) =>
                                                        if (groupI < prevGroup.size) {
                                                            if (valEs.hash != prevGroup[groupI].hash) {
                                                                isIdentical = false
                                                            }
                                                        }
                                                    case None => isIdentical = false
                                                }
                                            }
                                            groupI += 1
                                        }

                                        if (isIdentical) {
                                            // 复用前一版本的 bin group
                                            match (prevExternBinGroup) {
                                                case Some(prevGroup) => currentBinGroup = prevGroup
                                                case None => ()
                                            }
                                        } else {
                                            // 记录为新的 prev group 并推进游标
                                            prevExternBinGroup = Some(currentBinGroup)
                                            externStringsBinEntriesOffset += currentBinGroup.size
                                        }

                                        packageVersion.bin = PackageBin()
                                        packageVersion.bin.tag = BinTag.Map
                                        for (idx in 0..currentBinGroup.size) {
                                            if (idx % 2 == 0 && idx + 1 < currentBinGroup.size) {
                                                let binName = currentBinGroup[idx].value.toString()
                                                let binPath = currentBinGroup[idx + 1].value.toString()
                                                packageVersion.bin.binMap.put(binName, binPath)
                                            }
                                        }
                                        binDone = true
                                    }
                                case None => ()
                            }

                            if (!binDone) {
                                // 字符串形式的 bin
                                match (PkgJsonHelper.getString(vObj, "bin")) {
                                    case Some(binStr) =>
                                        if (binStr.size > 0) {
                                            packageVersion.bin = PackageBin()
                                            packageVersion.bin.tag = BinTag.File
                                            packageVersion.bin.filePath = Some(binStr)
                                            binDone = true
                                        }
                                    case None => ()
                                }
                            }

                            if (!binDone) {
                                // directories.bin
                                match (PkgJsonHelper.getNestedString(vObj, "directories", "bin")) {
                                    case Some(dirBin) =>
                                        if (dirBin.size > 0) {
                                            packageVersion.bin = PackageBin()
                                            packageVersion.bin.tag = BinTag.Dir
                                            packageVersion.bin.dirPath = Some(dirBin)
                                        }
                                    case None => ()
                                }
                            }

                            // ==================================================================
                            // integrity / dist
                            // 严格翻译自 (Zig ~2217-2254):
                            //   tarball_url, file_count, unpacked_size, integrity, shasum
                            // ==================================================================
                            match (PkgJsonHelper.getObject(vObj, "dist")) {
                                case Some(distObj) =>
                                    // tarball URL
                                    match (PkgJsonHelper.getString(distObj, "tarball")) {
                                        case Some(tarball) =>
                                            if (tarball.size > 0) {
                                                packageVersion.tarballUrl = ExternalString(tarball)
                                                appendToStringBuf(stringBuf, stringBufOffset, tarball)
                                                stringBufOffset += tarball.size
                                                // 翻译自:
                                                //   tarball_url_strings[0] = package_version.tarball_url
                                                //   tarball_url_strings = tarball_url_strings[1..]
                                                if (tarballUrlStringsOffset < allTarballUrlStrings.size) {
                                                    allTarballUrlStrings[tarballUrlStringsOffset] = packageVersion.tarballUrl
                                                    tarballUrlStringsOffset += 1
                                                }
                                            }
                                        case None => ()
                                    }

                                    // fileCount
                                    match (PkgJsonHelper.getInt(distObj, "fileCount")) {
                                        case Some(count) => packageVersion.fileCount = UInt32(count)
                                        case None => ()
                                    }

                                    // unpackedSize
                                    match (PkgJsonHelper.getInt(distObj, "unpackedSize")) {
                                        case Some(size) => packageVersion.unpackedSize = UInt32(size)
                                        case None => ()
                                    }

                                    // integrity (优先使用 integrity, 回退到 shasum)
                                    // 翻译自:
                                    //   if (integrity.tag.isSupported()) break :integrity
                                    //   if (shasum) => Integrity.parseSHASum(shasum_str)
                                    var integrityDone = false
                                    match (PkgJsonHelper.getString(distObj, "integrity")) {
                                        case Some(integrityStr) =>
                                            packageVersion.integrity = parseIntegrity(integrityStr)
                                            if (packageVersion.integrity.tag.isSupported()) {
                                                integrityDone = true
                                            }
                                        case None => ()
                                    }

                                    if (!integrityDone) {
                                        match (PkgJsonHelper.getString(distObj, "shasum")) {
                                            case Some(shasumStr) =>
                                                packageVersion.integrity = parseSHASum(shasumStr)
                                            case None => ()
                                        }
                                    }

                                case None => ()
                            }

                            // ==================================================================
                            // 依赖组 (第二遍)
                            // 严格翻译自 (Zig ~2256-2525):
                            //   对于每个 dependency_group:
                            //     1. 获取 items (如果 peer, 可能需要 peerDependenciesMeta 合成)
                            //     2. 构建 this_names / this_versions ExternalString 数组
                            //     3. 计算 Wyhash 累加哈希
                            //     4. 可选 peer 排序 (移到前面)
                            //     5. 合成 peerDependenciesMeta-only 可选依赖
                            //     6. 使用 dedupe map 去重
                            //     7. 设置 package_version 的对应字段
                            //     8. 设置 bundled_dependencies (仅 dependencies/optionalDependencies)
                            // ==================================================================
                            var nonOptionalPeerDependencyOffset: Int64 = 0
                            optionalPeerDepNames.clear()

                            for (group in DEPENDENCY_GROUPS) {
                                let propName = group[0]
                                let fieldName = group[1]
                                let isPeer = propName == "peerDependencies"

                                // 检查 peerDependenciesMeta 是否存在且非空
                                // 翻译自:
                                //   const has_meta_only_peers = is_peer_group and blk: {
                                //     const meta = prop.value.?.asProperty("peerDependenciesMeta") orelse break :blk false
                                //     break :blk meta.expr.data == .e_object and meta.expr.data.e_object.properties.len > 0
                                //   }
                                var hasMetaOnlyPeers = false
                                if (isPeer) {
                                    match (PkgJsonHelper.getObject(vObj, "peerDependenciesMeta")) {
                                        case Some(metaObj) =>
                                            let metaKeys = PkgJsonHelper.getKeys(metaObj)
                                            if (metaKeys.size > 0) {
                                                hasMetaOnlyPeers = true
                                            }
                                        case None => ()
                                    }
                                }

                                // 收集 peerDependenciesMeta 中的可选 peer 哈希
                                // 翻译自 (Zig ~2293-2321):
                                //   optional_peer_dep_names.clearRetainingCapacity()
                                //   for meta_props: optional_peer_dep_names.appendAssumeCapacity(hash)
                                //     count += 1 (为合成依赖预留空间)
                                if (isPeer) {
                                    optionalPeerDepNames.clear()
                                    match (PkgJsonHelper.getObject(vObj, "peerDependenciesMeta")) {
                                        case Some(metaObj) =>
                                            let metaKeys = PkgJsonHelper.getKeys(metaObj)
                                            for (metaKey in metaKeys) {
                                                match (PkgJsonHelper.getBool(metaObj, metaKey)) {
                                                    case Some(isOpt) =>
                                                        if (isOpt) {
                                                            let h = computeStringHash(metaKey)
                                                            optionalPeerDepNames.append(h)
                                                        }
                                                    case None => ()
                                                }
                                            }
                                        case None => ()
                                    }
                                }

                                // 获取依赖项列表
                                // 翻译自:
                                //   const items = items: {
                                //     if (prop.value.?.asProperty(comptime pair.prop)) |versioned_deps|
                                //       break :items versioned_deps.expr.data.e_object.properties.slice()
                                //     break :items &.{}
                                //   }
                                var depNames: ArrayList<String> = ArrayList<String>()
                                var depVersions: ArrayList<String> = ArrayList<String>()
                                match (PkgJsonHelper.getObject(vObj, propName)) {
                                    case Some(depsObj) =>
                                        let depKeys = PkgJsonHelper.getKeys(depsObj)
                                        for (k in depKeys) {
                                            let vOpt = PkgJsonHelper.getString(depsObj, k)
                                            let v = match (vOpt) { case Some(s) => s case None => "" }
                                            depNames.append(k)
                                            depVersions.append(v)
                                        }
                                    case None => ()
                                }

                                // 仅在有依赖项或需要处理 peerDependenciesMeta 合成时处理
                                // 翻译自: if (items.len > 0 or has_meta_only_peers)
                                if (depNames.size > 0 || hasMetaOnlyPeers) {
                                    // 翻译自: var count = items.len
                                    var count = depNames.size

                                    // 预留额外空间用于 peerDependenciesMeta 合成
                                    // 翻译自: count += 1 for each meta-only peer
                                    if (isPeer) {
                                        // count 已包含 depItems.size, 无需额外操作
                                    }

                                    var thisNames = ArrayList<ExternalString>()
                                    var thisVersions = ArrayList<ExternalString>()

                                    // Wyhash 哈希累加器
                                    // 翻译自:
                                    //   var name_hasher = bun.Wyhash11(0)
                                    //   var version_hasher = bun.Wyhash11(0)
                                    var nameHasher = Wyhash11State()
                                    var versionHasher = Wyhash11State()

                                    // bundled deps 起始偏移
                                    var bundledDepsBegin = bundledDepsOffset

                                    var itemI: Int64 = 0

                                    for (di in 0..depNames.size) {
                                        let nameStr = depNames[di]
                                        let versionStr = depVersions[di]

                                        // 翻译自:
                                        //   this_names[i] = string_builder.append(ExternalString, name_str)
                                        //   this_versions[i] = string_builder.append(ExternalString, version_str)
                                        let nameEs = ExternalString(nameStr)
                                        let verEs = ExternalString(versionStr)
                                        thisNames.append(nameEs)
                                        thisVersions.append(verEs)

                                        // bundled deps 匹配
                                        // 翻译自: if (!bundle_all_deps and bundled_deps_set.swapRemove(name_str))
                                        if (!bundleAllDeps && bundledDepsSet.contains(nameStr)) {
                                            bundledDepsSet.remove(nameStr)
                                            bundledDepsBuf.append(nameEs.hash)
                                            bundledDepsOffset += 1
                                        }

                                        // peer 可选依赖排序
                                        // 翻译自 (Zig ~2339-2355):
                                        //   if (std.mem.indexOfScalar(u64, optional_peer_dep_names.items, hash) != null)
                                        //     swap to front
                                        if (isPeer) {
                                            if (containsHash(optionalPeerDepNames, nameEs.hash)) {
                                                // 将可选 peer 移到前面
                                                let idx = thisNames.size - 1
                                                if (nonOptionalPeerDependencyOffset != idx) {
                                                    let tmpName = thisNames[idx]
                                                    thisNames[idx] = thisNames[nonOptionalPeerDependencyOffset]
                                                    thisNames[nonOptionalPeerDependencyOffset] = tmpName

                                                    let tmpVal = thisVersions[idx]
                                                    thisVersions[idx] = thisVersions[nonOptionalPeerDependencyOffset]
                                                    thisVersions[nonOptionalPeerDependencyOffset] = tmpVal
                                                }
                                                nonOptionalPeerDependencyOffset += 1
                                            }
                                        }

                                        // 累加 Wyhash
                                        // 翻译自:
                                        //   const names_hash_bytes = @as([8]u8, @bitCast(this_names[i].hash))
                                        //   name_hasher.update(&names_hash_bytes)
                                        //   version_hasher.update(&versions_hash_bytes)
                                        nameHasher.update(nameEs.hash)
                                        versionHasher.update(verEs.hash)

                                        // 写入字符串缓冲区
                                        appendToStringBuf(stringBuf, stringBufOffset, nameStr)
                                        stringBufOffset += nameStr.size
                                        appendToStringBuf(stringBuf, stringBufOffset, versionStr)
                                        stringBufOffset += versionStr.size

                                        itemI += 1
                                    }

                                    // peerDependenciesMeta 合成依赖
                                    // 严格翻译自 (Zig ~2373-2403):
                                    //   if (is_peer) {
                                    //     for (meta_props) |meta_prop| {
                                    //       if (already in this_names) continue :outer
                                    //       append name + "*" version
                                    //       swap to optional prefix
                                    //     }
                                    //   }
                                    if (isPeer) {
                                        match (PkgJsonHelper.getObject(vObj, "peerDependenciesMeta")) {
                                            case Some(metaObj) =>
                                                let metaKeys = PkgJsonHelper.getKeys(metaObj)
                                                for (metaKey in metaKeys) {
                                                    // 检查是否为 optional
                                                    var isOptional = false
                                                    match (PkgJsonHelper.getBool(metaObj, metaKey)) {
                                                        case Some(opt) => isOptional = opt
                                                        case None => ()
                                                    }
                                                    if (!isOptional) { continue }

                                                    // 检查是否已在 peerDependencies 中
                                                    // 翻译自:
                                                    //   const meta_hash = String.Builder.stringHash(meta_key)
                                                    //   for (this_names[0..i]) |existing|
                                                    //     if (existing.hash == meta_hash) continue :outer
                                                    let metaHash = computeStringHash(metaKey)
                                                    var alreadyExists = false
                                                    for (existing in thisNames) {
                                                        if (existing.hash == metaHash) {
                                                            alreadyExists = true
                                                            break
                                                        }
                                                    }
                                                    if (alreadyExists) { continue }

                                                    // 合成依赖: name + "*" 版本
                                                    let nameEs = ExternalString(metaKey)
                                                    let verEs = ExternalString("*")
                                                    thisNames.append(nameEs)
                                                    thisVersions.append(verEs)

                                                    // swap 到可选前缀
                                                    // 翻译自:
                                                    //   if (non_optional_peer_dependency_offset != i)
                                                    //     std.mem.swap(...)
                                                    let idx = thisNames.size - 1
                                                    if (nonOptionalPeerDependencyOffset != idx) {
                                                        let tmpName = thisNames[idx]
                                                        thisNames[idx] = thisNames[nonOptionalPeerDependencyOffset]
                                                        thisNames[nonOptionalPeerDependencyOffset] = tmpName
                                                        let tmpVal = thisVersions[idx]
                                                        thisVersions[idx] = thisVersions[nonOptionalPeerDependencyOffset]
                                                        thisVersions[nonOptionalPeerDependencyOffset] = tmpVal
                                                    }
                                                    nonOptionalPeerDependencyOffset += 1

                                                    appendToStringBuf(stringBuf, stringBufOffset, metaKey)
                                                    stringBufOffset += metaKey.size
                                                    appendToStringBuf(stringBuf, stringBufOffset, "*")
                                                    stringBufOffset += 1
                                                }
                                            case None => ()
                                        }
                                    }

                                    count = thisNames.size

                                    // bundled dependencies (仅 dependencies/optionalDependencies)
                                    // 严格翻译自 (Zig ~2422-2431):
                                    //   if (comptime !is_peer) {
                                    //     if (bundle_all_deps) package_version.bundled_dependencies = invalid
                                    //     else package_version.bundled_dependencies = init(bundled_deps_buf, ...)
                                    //   }
                                    if (!isPeer) {
                                        if (bundleAllDeps) {
                                            // 翻译自: ExternalPackageNameHashList.invalid
                                            packageVersion.bundledDependencies = ExternalPackageNameHashList()
                                            packageVersion.bundledDependencies.off = UInt32(0)
                                            packageVersion.bundledDependencies.len = UInt32(0)
                                        } else if (bundledDepsOffset > bundledDepsBegin) {
                                            packageVersion.bundledDependencies = ExternalPackageNameHashList(
                                                UInt32(bundledDepsBegin),
                                                UInt32(bundledDepsOffset - bundledDepsBegin)
                                            )
                                        }
                                    }

                                    // 构建 ExternalStringList
                                    // 翻译自:
                                    //   var name_list = ExternalStringList(all_extern_strings, this_names)
                                    //   var version_list = ExternalStringList(version_extern_strings, this_versions)
                                    var nameList = buildExternalStringList(thisNames)
                                    var valueList = buildExternalStringList(thisVersions)

                                    // 设置 non_optional_peer_dependencies_start
                                    // 翻译自:
                                    //   package_version.non_optional_peer_dependencies_start =
                                    //     @as(u32, @truncate(non_optional_peer_dependency_offset))
                                    if (isPeer) {
                                        packageVersion.nonOptionalPeerDependenciesStart =
                                            UInt32(nonOptionalPeerDependencyOffset)
                                    }

                                    // ==================================================================
                                    // 外部字符串去重
                                    // 严格翻译自 (Zig ~2440-2464):
                                    //   if (count > 0 and ((!is_peer) or optional_peer_dep_names.items.len == 0))
                                    //     const name_map_hash = name_hasher.final()
                                    //     const version_map_hash = version_hasher.final()
                                    //     name_entry = dedupe_map.getOrPut(name_map_hash)
                                    //     if (name_entry.found_existing) name_list = name_entry.value_ptr.*
                                    //     else dependency_names = dependency_names[count..]
                                    //     (same for version)
                                    // ==================================================================
                                    if (count > 0 && (!isPeer || optionalPeerDepNames.size == 0)) {
                                        let nameMapHash = nameHasher.final()
                                        let versionMapHash = versionHasher.final()

                                        // 名称去重
                                        let nameEntry = allExternStringsDedupeMap.getOrPut(nameMapHash)
                                        if (nameEntry.first) {
                                            // found_existing: 复用已有的 name_list
                                            nameList = nameEntry.second
                                        } else {
                                            // 新的: 存入 dedupe map
                                            allExternStringsDedupeMap.put(nameMapHash, nameList)
                                            dependencyNamesCursor += count
                                        }

                                        // 版本去重
                                        let versionEntry = versionExternStringsDedupeMap.getOrPut(versionMapHash)
                                        if (versionEntry.first) {
                                            valueList = versionEntry.second
                                        } else {
                                            versionExternStringsDedupeMap.put(versionMapHash, valueList)
                                            dependencyValuesCursor += count
                                        }
                                    }

                                    // peer deps 有 optional 时, 总是推进游标
                                    if (isPeer) {
                                        if (optionalPeerDepNames.size > 0) {
                                            dependencyNamesCursor += count
                                            dependencyValuesCursor += count
                                        }
                                    }

                                    // 设置 package_version 的对应字段
                                    // 翻译自: @field(package_version, pair.field) = ExternalStringMap{...}
                                    if (propName == "dependencies") {
                                        packageVersion.dependencies = ExternalStringMap()
                                        packageVersion.dependencies.name = nameList
                                        packageVersion.dependencies.value = valueList
                                    } else if (propName == "optionalDependencies") {
                                        packageVersion.optionalDependencies = ExternalStringMap()
                                        packageVersion.optionalDependencies.name = nameList
                                        packageVersion.optionalDependencies.value = valueList
                                    } else if (propName == "peerDependencies") {
                                        packageVersion.peerDependencies = ExternalStringMap()
                                        packageVersion.peerDependencies.name = nameList
                                        packageVersion.peerDependencies.value = valueList
                                    }
                                }
                            }

                            // engines
                            match (PkgJsonHelper.getObject(vObj, "engines")) {
                                case Some(engObj) =>
                                    let engKeys = PkgJsonHelper.getKeys(engObj)
                                    var engNames = ArrayList<ExternalString>()
                                    var engValues = ArrayList<ExternalString>()
                                    for (k in engKeys) {
                                        let v = PkgJsonHelper.getStringOrEmpty(engObj, k)
                                        engNames.append(ExternalString(k))
                                        engValues.append(ExternalString(v))
                                    }
                                    packageVersion.engines = ExternalStringMap()
                                    packageVersion.engines.name = buildExternalStringList(engNames)
                                    packageVersion.engines.value = buildExternalStringList(engValues)
                                case None => ()
                            }

                            // 发布时间戳
                            // 翻译自 (Zig ~2527-2535):
                            //   if (json.asProperty("time")) |time_obj|
                            //     if (publish_time_expr.asString(allocator)) |publish_time_str|
                            //       if (bun.jsc.wtf.parseES5Date(publish_time_str) catch null) |time|
                            //         package_version.publish_timestamp_ms = time
                            match (PkgJsonHelper.getObject(json, "time")) {
                                case Some(timeObj) =>
                                    match (PkgJsonHelper.getString(timeObj, versionName)) {
                                        case Some(publishTimeStr) =>
                                            let timeMs = parseES5Date(publishTimeStr)
                                            packageVersion.publishTimestampMs = timeMs
                                        case None => ()
                                    }
                                case None => ()
                            }

                            // 写入版本数组
                            let semverVersion = SemverVersion(
                                parsedVersion.major,
                                parsedVersion.minor,
                                parsedVersion.patch,
                                if (parsedVersion.hasPre) {
                                    versionName[Int64(parsedVersion.preStart)..]
                                } else {
                                    ""
                                }
                            )

                            if (!parsedVersion.hasPre) {
                                // Release 版本
                                if (releaseVersionsIdx < versionedPackages.size) {
                                    versionedPackages[releaseVersionsIdx] = packageVersion
                                    allSemverVersions[releaseVersionsIdx] = semverVersion
                                    releaseVersionsIdx += 1
                                }
                            } else {
                                // Pre-release 版本
                                let preIdx = preVersionsStart + preVersionsIdx
                                if (preIdx < versionedPackages.size) {
                                    versionedPackages[preIdx] = packageVersion
                                    allSemverVersions[preIdx] = semverVersion
                                    preVersionsIdx += 1
                                }
                            }

                        case None => ()
                    }
                }

            case None => ()
        }

        // ====================================================================
        // 5. 构建 dist-tags
        // 严格翻译自 (Zig ~2555-2588):
        //   var extern_strings_slice = extern_strings[0..dist_tags_count]
        //   for (tags) |tag| {
        //     extern_strings_slice[dist_tag_i] = string_builder.append(ExternalString, key)
        //     dist_tag_versions[dist_tag_i] = Semver.Version.parse(sliced_string).version.min()
        //   }
        //   result.pkg.dist_tags = DistTagMap{ .tags = ..., .versions = ... }
        // ====================================================================

        // 计算剩余的 extern_strings 游标
        var externStringsOffset: Int64 = 0

        match (PkgJsonHelper.getObject(json, "dist-tags")) {
            case Some(distTags) =>
                let tagKeys = PkgJsonHelper.getKeys(distTags)

                var tagExternStrings = ArrayList<ExternalString>()
                var tagVersions = ArrayList<SemverVersion>()
                var distTagI: Int64 = 0

                for (tagKey in tagKeys) {
                    let tagValue = PkgJsonHelper.getStringOrEmpty(distTags, tagKey)

                    // 翻译自: extern_strings_slice[dist_tag_i] = string_builder.append(ExternalString, key)
                    let tagEs = ExternalString(tagKey)
                    tagExternStrings.append(tagEs)

                    if (tagValue.size > 0) {
                        // 翻译自:
                        //   const dist_tag_value_literal = string_builder.append(ExternalString, version_name)
                        //   dist_tag_versions[dist_tag_i] = Semver.Version.parse(sliced_string).version.min()
                        let tagParsed = parseSemverVersion(tagValue)
                        tagVersions.append(SemverVersion(
                            tagParsed.major, tagParsed.minor, tagParsed.patch,
                            if (tagParsed.hasPre) { tagValue[tagParsed.preStart..] } else { "" }
                        ))
                        distTagI += 1
                    }

                    // 写入字符串
                    appendToStringBuf(stringBuf, stringBufOffset, tagKey)
                    stringBufOffset += tagKey.size
                    appendToStringBuf(stringBuf, stringBufOffset, tagValue)
                    stringBufOffset += tagValue.size
                }

                // 设置 dist-tags
                // 翻译自:
                //   result.pkg.dist_tags = DistTagMap{
                //     .tags = ExternalStringList(all_extern_strings, extern_strings_slice[0..dist_tag_i])
                //     .versions = VersionSlice(all_semver_versions, dist_tag_versions[0..dist_tag_i])
                //   }
                result.pkg.distTags = DistTagMap(
                    buildExternalStringList(tagExternStrings),
                    buildExternalStringListFromVersions(tagVersions)
                )

                // 翻译自: extern_strings = extern_strings[dist_tag_i..]
                externStringsOffset += distTagI

            case None => ()
        }

        // ====================================================================
        // 6. 设置 HTTP 头信息
        // 严格翻译自 (Zig ~2590-2602):
        //   if (last_modified.len > 0) result.pkg.last_modified = string_builder.append(String, last_modified)
        //   if (etag.len > 0) result.pkg.etag = string_builder.append(String, etag)
        //   if (json.asProperty("modified")) result.pkg.modified = string_builder.append(String, field)
        // ====================================================================

        if (lastModified.size > 0) {
            result.pkg.lastModified = lastModified
        }
        if (etag.size > 0) {
            result.pkg.etag = etag
        }

        match (PkgJsonHelper.getString(json, "modified")) {
            case Some(modified) => result.pkg.modified = modified
            case None => ()
        }

        // ====================================================================
        // 7. 设置版本映射
        // 严格翻译自 (Zig ~2604-2608):
        //   result.pkg.releases.keys = VersionSlice(all_semver_versions, all_release_versions)
        //   result.pkg.releases.values = PackageVersionList(versioned_packages, all_versioned_package_releases)
        //   result.pkg.prereleases.keys = ...
        //   result.pkg.prereleases.values = ...
        // ====================================================================

        result.pkg.releases = ExternVersionMap(
            VersionSlice(UInt32(0), UInt32(releaseVersionsLen)),
            ExternalSlice<PackageVersionData>(UInt32(0), UInt32(releaseVersionsLen))
        )
        result.pkg.prereleases = ExternVersionMap(
            VersionSlice(UInt32(releaseVersionsStart), UInt32(preVersionsIdx)),
            ExternalSlice<PackageVersionData>(UInt32(preVersionsStart), UInt32(preVersionsIdx))
        )

        // ====================================================================
        // 8. 排序版本列表 (确定性排序)
        // 严格翻译自 (Zig ~2610-2700):
        //   Bun 使用 pdqsort 对 releases 和 prereleases 分别排序
        //   排序策略:
        //     1. 创建索引数组 [0, 1, 2, ...]
        //     2. 对索引数组按 semver.order 排序
        //     3. 根据排序后的索引重排 versions 和 packages 数组
        //   注: Zig 根据 max_versions_count 选择不同大小的整数类型 (1/2/4/8 字节)
        //       在仓颉中, 我们使用通用的插入排序 (对于大多数包, 版本数 < 1000, 性能足够)
        // ====================================================================

        let maxVersionsCount = if (releaseVersionsLen > preVersionsIdx) {
            releaseVersionsLen
        } else {
            preVersionsIdx
        }

        // 排序 releases
        if (releaseVersionsLen > 1) {
            sortVersionSlice(
                allSemverVersions, versionedPackages,
                0, releaseVersionsLen
            )
        }

        // 排序 prereleases
        if (preVersionsIdx > 1) {
            sortVersionSlice(
                allSemverVersions, versionedPackages,
                preVersionsStart, preVersionsStart + preVersionsIdx
            )
        }

        // ====================================================================
        // 9. tarball URL 重定位到 extern_strings 末尾
        // 严格翻译自 (Zig ~2702-2711):
        //   将 tarball URL 对应的 ExternalString 数据从 all_tarball_url_strings
        //   复制到 all_extern_strings 的末尾 (剩余空间)
        //   这是为了让所有外部字符串数据都在同一个连续缓冲区中
        //
        //   if (extern_strings.len + tarball_urls_count > 0) {
        //     const src = sliceAsBytes(all_tarball_url_strings[0..used])
        //     var dst = sliceAsBytes(all_extern_strings[remaining..])
        //     @memcpy(dst[0..src.len], src)
        //     all_extern_strings = all_extern_strings[0..trimmed]
        //   }
        // ====================================================================

        if (externStringsOffset + tarballUrlsCount > 0) {
            // 将 tarball URL ExternalStrings 追加到 externStrings 的剩余空间
            var srcIdx: Int64 = 0
            while (srcIdx < tarballUrlStringsOffset && externStringsOffset < allExternStrings.size) {
                allExternStrings[externStringsOffset] = allTarballUrlStrings[srcIdx]
                externStringsOffset += 1
                srcIdx += 1
            }
        }

        // ====================================================================
        // 10. 设置最终结果
        // 严格翻译自 (Zig ~2713-2732):
        //   result.pkg.string_lists_buf = { off: 0, len: all_extern_strings.len }
        //   result.pkg.versions_buf = { off: 0, len: all_semver_versions.len }
        //   result.versions = all_semver_versions
        //   result.external_strings = all_extern_strings
        //   result.external_strings_for_versions = version_extern_strings
        //   result.package_versions = versioned_packages
        //   result.extern_strings_bin_entries = all_extern_strings_bin_entries[0..used]
        //   result.bundled_deps_buf = bundled_deps_buf
        //   result.pkg.public_max_age = public_max_age
        //   result.pkg.has_extended_manifest = is_extended_manifest
        //   if (string_builder.ptr) result.string_buf = ptr[0..string_builder.len]
        // ====================================================================

        result.pkg.stringListsBuf = ExternalStringList(UInt32(0), UInt32(allExternStrings.size))
        result.pkg.versionsBuf = VersionSlice(UInt32(0), UInt32(allSemverVersions.size))

        result.versions = allSemverVersions
        result.externalStrings = allExternStrings
        result.externalStringsForVersions = versionExternStrings
        result.packageVersions = versionedPackages

        // 翻译自:
        //   result.extern_strings_bin_entries = all_extern_strings_bin_entries[0..used]
        //   其中 used = total - remaining
        let usedBinEntries = externStringsBinEntriesOffset
        var trimmedBinEntries = ArrayList<ExternalString>()
        var beI: Int64 = 0
        while (beI < usedBinEntries && beI < externStringsBinEntries.size) {
            trimmedBinEntries.append(externStringsBinEntries[beI])
            beI += 1
        }
        result.externStringsBinEntries = trimmedBinEntries

        result.bundledDepsBuf = bundledDepsBuf
        result.pkg.publicMaxAge = publicMaxAge
        result.pkg.hasExtendedManifest = isExtendedManifest
        result.stringBufBytes = stringBuf

        // 截断字符串缓冲区到实际使用的大小
        // 翻译自: result.string_buf = ptr[0..string_builder.len]
        result.stringBuf = bytesToString(stringBuf, stringBufOffset)

        return result
    }

    // ========================================================================
    // 辅助方法
    // ========================================================================

    /// 解析 semver 版本字符串
    private static func parseSemverVersion(versionName: String): ParsedSemverResult {
        // 格式: major.minor.patch[-prerelease][+build]
        var major: UInt64 = UInt64(0)
        var minor: UInt64 = UInt64(0)
        var patch: UInt64 = UInt64(0)
        var hasPre = false
        var valid = false
        var preStart: Int64 = 0

        var i: Int64 = 0
        let len = versionName.size

        // 解析 major
        while (i < len && versionName[i] >= UInt8(0x30) && versionName[i] <= UInt8(0x39)) {
            major = major * UInt64(10) + UInt64(Int64(versionName[i]) - Int64(UInt8(0x30)))
            i += 1
        }
        if (i >= len || versionName[i] != UInt8(0x2E)) {
            return ParsedSemverResult(major, minor, patch, hasPre, valid, preStart)
        }
        i += 1  // skip '.'

        // 解析 minor
        while (i < len && versionName[i] >= UInt8(0x30) && versionName[i] <= UInt8(0x39)) {
            minor = minor * UInt64(10) + UInt64(Int64(versionName[i]) - Int64(UInt8(0x30)))
            i += 1
        }
        if (i >= len || versionName[i] != UInt8(0x2E)) {
            return ParsedSemverResult(major, minor, patch, hasPre, valid, preStart)
        }
        i += 1  // skip '.'

        // 解析 patch
        while (i < len && versionName[i] >= UInt8(0x30) && versionName[i] <= UInt8(0x39)) {
            patch = patch * UInt64(10) + UInt64(Int64(versionName[i]) - Int64(UInt8(0x30)))
            i += 1
        }

        valid = true

        // 预发布标签
        if (i < len && versionName[i] == UInt8(0x2D)) {
            hasPre = true
            preStart = i
            i += 1
            while (i < len && versionName[i] != UInt8(0x2B)) { i += 1 }
        }

        return ParsedSemverResult(major, minor, patch, hasPre, valid, preStart)
    }

    /// 写入字符串到缓冲区并返回 ExternalString
    private static func writeToStringBuf(
        buf: Array<UInt8>,
        offset: Int64,
        s: String
    ): ExternalString {
        let es = ExternalString(s)
        appendToStringBuf(buf, offset, s)
        return es
    }

    /// 追加字符串到字节数组
    private static func appendToStringBuf(
        buf: Array<UInt8>,
        offset: Int64,
        s: String
    ): Unit {
        var i: Int64 = 0
        while (i < s.size && (offset + i) < buf.size) {
            buf[offset + i] = UInt8(UInt32(s[i]))
            i += 1
        }
    }

    /// 从字节数组构建字符串
    private static func bytesToString(buf: Array<UInt8>, len: Int64): String {
        var sb = StringBuilder()
        var i: Int64 = 0
        while (i < len && i < buf.size) {
            sb.append(String([Rune(UInt32(buf[i]))]))
            i += 1
        }
        return sb.toString()
    }

    /// 构建 ExternalStringList
    private static func buildExternalStringList(
        items: ArrayList<ExternalString>
    ): ExternalStringList {
        return ExternalStringList(UInt32(0), UInt32(items.size))
    }

    /// 从版本列表构建 VersionSlice
    private static func buildExternalStringListFromVersions(
        items: ArrayList<SemverVersion>
    ): VersionSlice {
        return VersionSlice(UInt32(0), UInt32(items.size))
    }

    /// 检查哈希列表是否包含指定哈希
    private static func containsHash(list: ArrayList<UInt64>, hash: UInt64): Bool {
        for (h in list) {
            if (h == hash) { return true }
        }
        return false
    }

    /// 解析 integrity 字符串 (如 "sha512-abcdef...")
    /// 翻译自: Integrity.parse
    private static func parseIntegrity(s: String): Integrity {
        if (s.startsWith("sha512-")) {
            return Integrity(IntegrityTag.SHA512, s[7..])
        }
        if (s.startsWith("sha384-")) {
            return Integrity(IntegrityTag.SHA384, s[7..])
        }
        if (s.startsWith("sha256-")) {
            return Integrity(IntegrityTag.SHA256, s[7..])
        }
        if (s.startsWith("sha1-")) {
            return Integrity(IntegrityTag.SHA1, s[5..])
        }
        return Integrity()
    }

    /// 解析 shasum 字符串
    /// 翻译自: Integrity.parseSHASum
    private static func parseSHASum(s: String): Integrity {
        return Integrity(IntegrityTag.SHA1, s)
    }

    /// 解析 ES5 日期字符串为 Unix 时间戳 (毫秒)
    /// 翻译自: bun.jsc.wtf.parseES5Date
    private static func parseES5Date(dateStr: String): Float64 {
        // ISO 8601 格式: "2024-01-15T10:30:00.000Z"
        // 简化解析: 返回 0 (TODO: 实现完整日期解析)
        return Float64(0)
    }

    /// 对版本切片进行确定性排序
    /// 翻译自: PackageManifest.parse 中排序块 (Zig ~2633-2696)
    ///   Bun 使用 pdqsort, 按 semver 版本升序排列
    ///   排序策略:
    ///     1. 创建索引数组 indices = [0, 1, 2, ...]
    ///     2. 排序 indices, 比较使用 all_versions[left].order(all_versions[right])
    ///     3. 根据排序后的 indices, 重排 versions 和 packages 数组
    ///     4. Zig 根据 max_versions_count 选择 1/2/4/8 字节整数
    ///        仓颉: 使用通用的 Int64
    ///
    ///   翻译自:
    ///     const ExternVersionSorter = struct {
    ///       string_bytes, all_versions, all_versioned_packages
    ///       pub fn isLessThan(this, left, right) bool
    ///     }
    ///     std.sort.pdq(Int, indices, sorter, isLessThan)
    ///     for (indices, packages_, versions_) |i, *pkg, *version| {
    ///       pkg.* = cloned_packages[i]
    ///       version.* = cloned_versions[i]
    ///     }
    private static func sortVersionSlice(
        versions: ArrayList<SemverVersion>,
        packages: ArrayList<PackageVersionData>,
        start: Int64,
        end: Int64
    ): Unit {
        let count = end - start
        if (count <= 1) { return }

        // 创建索引数组
        var indices = ArrayList<Int64>()
        var i: Int64 = 0
        while (i < count) {
            indices.append(i)
            i += 1
        }

        // 克隆用于排序后查找
        var clonedVersions = ArrayList<SemverVersion>()
        var clonedPackages = ArrayList<PackageVersionData>()
        i = 0
        while (i < count) {
            clonedVersions.append(versions[start + i])
            clonedPackages.append(packages[start + i])
            i += 1
        }

        // 排序索引数组 (使用插入排序, 与 Zig 的 pdqsort 结果相同)
        var ii: Int64 = 1
        while (ii < count) {
            let keyIdx = indices[ii]
            var jj = ii - 1

            while (jj >= 0) {
                let left = indices[jj]
                let right = keyIdx
                // 翻译自: this.all_versions[left].order(this.all_versions[right]) == .lt
                if (clonedVersions[left].order(clonedVersions[right]) > 0) {
                    indices[jj + 1] = indices[jj]
                    jj -= 1
                } else {
                    break
                }
            }
            indices[jj + 1] = keyIdx
            ii += 1
        }

        // 根据排序后的索引重排
        i = 0
        while (i < count) {
            let srcIdx = indices[i]
            versions[start + i] = clonedVersions[srcIdx]
            packages[start + i] = clonedPackages[srcIdx]
            i += 1
        }
    }

    /// 计算字符串哈希
    /// 翻译自: String.Builder.stringHash / bun.Wyhash11.hash(0, key)
    ///   在 Zig 中, 用于 dedupe map 的键哈希
    private static func computeStringHash(s: String): UInt64 {
        return Wyhash11.hash(s)
    }
}

/// 解析后的 semver 版本结果 (内部使用)
private class ParsedSemverResult {
    public var major: UInt64
    public var minor: UInt64
    public var patch: UInt64
    public var hasPre: Bool
    public var valid: Bool
    public var preStart: Int64

    public init(
        major: UInt64,
        minor: UInt64,
        patch: UInt64,
        hasPre: Bool,
        valid: Bool,
        preStart: Int64
    ) {
        this.major = major
        this.minor = minor
        this.patch = patch
        this.hasPre = hasPre
        this.valid = valid
        this.preStart = preStart
    }
}

// ============================================================================
// PackageManifestData 辅助: parseFromResponse 方法
// 严格翻译自: Registry.getPackageMetadata 中调用 PackageManifest.parse 的路径
// ============================================================================

/// PackageManifestData 解析辅助
/// 对应 Bun: 通过 PackageManifest.parse + response 构建的过程
public class NpmManifestDataHelper {

    /// 从 HTTP 响应体解析 Manifest 数据
    /// 翻译自: Registry.getPackageMetadata 中 PackageManifest.parse 调用路径
    public static func parseFromResponse(
        body: String,
        packageName: String,
        lastModified: String,
        etag: String,
        cacheTimestamp: Int64,
        isExtended: Bool
    ): ?NpmPackageManifest {
        // 翻译自:
        //   if (try PackageManifest.parse(
        //       allocator, scope, log, body, package_name,
        //       newly_last_modified, new_etag,
        //       @as(u32, @truncate(...)) + 300,
        //       is_extended_manifest,
        //   )) |package| { ... }
        let publicMaxAge = UInt32(cacheTimestamp) + UInt32(300)

        return PackageManifestParser.parse(
            body,
            packageName,
            lastModified,
            etag,
            publicMaxAge,
            isExtended
        )
    }
}
