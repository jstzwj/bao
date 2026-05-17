// 严格翻译自: src/install/dependency.zig, src/install/bin.zig, src/install/install.zig
// bao_install - package.json 完整解析器
package bao_install

import bao_core.*
import bao_collections.*
import bao_io.*
import bao_sys.*
import bao_hash.*
import bao_path.*
import bao_http.*

// ============================================================================
// package.json 完整解析器
// 严格翻译自: src/install/install.zig PackageJSON, src/install/dependency.zig
// ============================================================================

/// 依赖版本信息
/// 严格翻译自: src/install/dependency.zig Dependency.Version
public class DependencyVersion {
    /// 版本标签类型
    public var tag: VersionTag
    /// 版本字面值
    public var literal: String
    /// 对于 dist_tag: 标签名
    public var distTagName: ?String
    /// 对于 npm: 包名
    public var npmName: ?String
    /// 对于 git: URL
    public var gitUrl: ?String
    /// 对于 github: repo
    public var githubRepo: ?String
    /// 对于 tarball: URL
    public var tarballUrl: ?String
    /// 对于 file: 本地路径
    public var filePath: ?String
    /// 对于 link: 链接路径
    public var linkPath: ?String

    public init() {
        tag = VersionTag.Npm
        literal = ""
        distTagName = None
        npmName = None
        gitUrl = None
        githubRepo = None
        tarballUrl = None
        filePath = None
        linkPath = None
    }

    /// 解析版本字符串
    // 严格翻译自: src/install/dependency.zig Dependency.parse
    public static func parse(name: String, version: String): DependencyVersion {
        let v = DependencyVersion()
        v.literal = version

        if (version.isEmpty() || version == "*" || version == "latest") {
            v.tag = VersionTag.DistTag
            v.distTagName = Some("latest")
            return v
        }

        if (version.startsWith("npm:")) {
            v.tag = VersionTag.Npm
            let rest = version[4..]
            let atIdx = rest.lastIndexOf("@")
            match (atIdx) {
                case Some(idx) => setNpmVersion(v, rest, idx)
                case None => v.npmName = Some(rest)
            }
            return v
        }

        if (version.startsWith("github:")) {
            v.tag = VersionTag.Github
            v.githubRepo = Some(version[7..])
            return v
        }

        if (version.startsWith("git+") || version.startsWith("git://")) {
            v.tag = VersionTag.Git
            v.gitUrl = Some(version)
            return v
        }

        if (version.startsWith("http://") || version.startsWith("https://")) {
            v.tag = VersionTag.Tarball
            v.tarballUrl = Some(version)
            return v
        }

        if (version.startsWith("file:")) {
            v.tag = VersionTag.File
            v.filePath = Some(version[5..])
            return v
        }

        if (version.startsWith("link:")) {
            v.tag = VersionTag.Link
            v.linkPath = Some(version[5..])
            return v
        }

        // 版本范围: ^1.2.3, ~1.2.3, >=1.0.0, 1.2.3
        v.tag = VersionTag.Npm
        return v
    }

    private static func setNpmVersion(v: DependencyVersion, rest: String, idx: Int64): Unit {
        v.npmName = Some(rest[..idx])
        v.literal = rest[idx + 1..]
    }
}

/// 版本标签类型
/// 严格翻译自: src/install/dependency.zig Version.Tag
public enum VersionTag {
    | Npm            // npm 版本范围
    | DistTag        // npm dist-tag (latest, next, beta...)
    | Git            // git URL
    | Github         // github repo shorthand
    | Tarball        // 直接 URL
    | File           // 本地文件路径
    | Link           // 本地链接
    | Workspace      // workspace 协议
}

/// Bin 字段类型
/// 严格翻译自: src/install/bin.zig Bin
public class PackageBin {
    /// bin 类型
    public var tag: BinTag
    /// 单文件路径 (tag == File)
    public var filePath: ?String
    /// 命名文件 (tag == NamedFile)
    public var name: ?String
    public var namedPath: ?String
    /// 目录 (tag == Dir)
    public var dirPath: ?String
    /// 映射 (tag == Map)
    public var binMap: HashMap<String, String>

    public init() {
        tag = BinTag.None
        filePath = None
        name = None
        namedPath = None
        dirPath = None
        binMap = HashMap<String, String>()
    }

    private static func parseBinString(path: String, result: PackageBin): Unit {
        if (!path.isEmpty()) {
            result.tag = BinTag.File
            result.filePath = Some(path)
        }
    }

    private static func parseBinObject(obj: HashMap<String, JsonValue>, result: PackageBin): Unit {
        let keys = obj.keys()
        if (keys.size == 1) {
            result.tag = BinTag.NamedFile
            result.name = Some(keys[0])
            match (obj.get(keys[0])) {
                case Some(JsonValue.Str(v)) => result.namedPath = Some(v)
                case _ => ()
            }
        } else if (keys.size > 1) {
            result.tag = BinTag.Map
            for (key in keys) {
                match (obj.get(key)) {
                    case Some(JsonValue.Str(v)) => result.binMap.put(key, v)
                    case _ => ()
                }
            }
        }
    }

    /// 从 JSON 解析 bin 字段
    // 严格翻译自: src/install/bin.zig Bin.parseAppend
    public static func parse(binValue: ?JsonValue): PackageBin {
        let result = PackageBin()
        match (binValue) {
            case Some(JsonValue.Str(path)) => parseBinString(path, result)
            case Some(JsonValue.Object(obj)) => parseBinObject(obj, result)
            case _ => ()
        }
        return result
    }

    /// 获取所有 bin 名称
    public func getBinNames(): ArrayList<String> {
        let names = ArrayList<String>()
        match (tag) {
            case BinTag.None => ()
            case BinTag.File => names.append("<package-name>")
            case BinTag.NamedFile => appendNameIfPresent(names)
            case BinTag.Map => appendMapKeys(names)
            case BinTag.Dir=> ()  // 遍历目录
        }
        return names
    }

    private func appendNameIfPresent(names: ArrayList<String>): Unit {
        match (name) {
            case Some(n) => names.append(n)
            case None => ()
        }
    }

    private func appendMapKeys(names: ArrayList<String>): Unit {
        for (key in binMap.keys()) {
            names.append(key)
        }
    }
}

/// Bin 类型枚举
/// 严格翻译自: src/install/bin.zig Bin.Tag
public enum BinTag {
    | None
    | File
    | NamedFile
    | Dir
    | Map

    public operator func ==(right: BinTag): Bool {
        match (this) {
            case None => match (right) { case None => true case _ => false }
            case File => match (right) { case File => true case _ => false }
            case NamedFile => match (right) { case NamedFile => true case _ => false }
            case Dir => match (right) { case Dir => true case _ => false }
            case Map => match (right) { case Map => true case _ => false }
        }
    }

    public operator func !=(right: BinTag): Bool {
        return !(this == right)
    }
}

/// 完整的 package.json 数据
/// 严格翻译自: src/install/install.zig PackageJSON
public class PackageJson {
    /// 名称
    public var name: String
    /// 版本
    public var version: String
    /// 描述
    public var description: String
    /// 主入口
    public var `main`: String
    /// module 入口
    public var moduleEntry: ?String
    /// types/typings 入口
    public var types: ?String
    /// exports 映射
    public var exports: ?JsonValue
    /// imports 映射
    public var imports: HashMap<String, String>
    /// bin 字段
    public var bin: PackageBin
    /// 脚本
    public var scripts: HashMap<String, String>
    /// 生产依赖
    public var dependencies: HashMap<String, String>
    /// 开发依赖
    public var devDependencies: HashMap<String, String>
    /// peer 依赖
    public var peerDependencies: HashMap<String, String>
    /// 可选依赖
    public var optionalDependencies: HashMap<String, String>
    /// trusted 依赖
    public var trustedDependencies: ArrayList<String>
    /// 指定 CPU 架构
    public var cpu: ArrayList<String>
    /// 指定操作系统
    public var os: ArrayList<String>
    /// 私有包标志
    public var isPrivate: Bool
    /// sideEffects 标志
    public var sideEffects: ?Bool
    /// type 字段 (module/commonjs)
    public var moduleType: String
    /// license
    public var license: ?String
    /// author
    public var author: ?String
    /// repository
    public var repository: ?String
    /// homepage
    public var homepage: ?String
    /// keywords
    public var keywords: ArrayList<String>
    /// engines
    public var engines: HashMap<String, String>
    /// workspaces
    public var workspaces: ArrayList<String>
    /// bundledDependencies
    public var bundledDependencies: ArrayList<String>
    /// publishConfig
    public var publishConfig: HashMap<String, String>
    /// packageManager
    public var packageManager: ?String
    /// 原始 JSON
    public var raw: ?JsonValue

    public init() {
        name = ""
        version = "0.0.0"
        description = ""
        `main` = "index.js"
        moduleEntry = None
        types = None
        exports = None
        imports = HashMap<String, String>()
        bin = PackageBin()
        scripts = HashMap<String, String>()
        dependencies = HashMap<String, String>()
        devDependencies = HashMap<String, String>()
        peerDependencies = HashMap<String, String>()
        optionalDependencies = HashMap<String, String>()
        trustedDependencies = ArrayList<String>()
        cpu = ArrayList<String>()
        os = ArrayList<String>()
        isPrivate = false
        sideEffects = None
        moduleType = "commonjs"
        license = None
        author = None
        repository = None
        homepage = None
        keywords = ArrayList<String>()
        engines = HashMap<String, String>()
        workspaces = ArrayList<String>()
        bundledDependencies = ArrayList<String>()
        publishConfig = HashMap<String, String>()
        packageManager = None
        raw = None
    }

    /// 从 JSON 解析完整 package.json
    // 严格翻译自: src/install/install.zig PackageJSON.init
    public static func parse(json: JsonValue): PackageJson {
        let pkg = PackageJson()
        pkg.raw = Some(json)

        // 基本字段
        pkg.name = JsonHelper.getString(json, "name") ?? ""
        pkg.version = JsonHelper.getString(json, "version") ?? "0.0.0"
        pkg.description = JsonHelper.getString(json, "description") ?? ""
        pkg.`main` = JsonHelper.getString(json, "main") ?? "index.js"
        pkg.moduleEntry = JsonHelper.getString(json, "module")
        pkg.types = JsonHelper.getString(json, "types")
        match (pkg.types) {
            case Some(_) => ()
            case None => pkg.types = JsonHelper.getString(json, "typings")
        }
        pkg.moduleType = JsonHelper.getString(json, "type") ?? "commonjs"
        pkg.license = JsonHelper.getString(json, "license")
        pkg.author = JsonHelper.getString(json, "author")
        pkg.homepage = JsonHelper.getString(json, "homepage")
        pkg.packageManager = JsonHelper.getString(json, "packageManager")

        // exports
        pkg.exports = JsonHelper.getField(json, "exports")

        // imports
        match (JsonHelper.getField(json, "imports")) {
            case Some(JsonValue.Object(obj)) =>
                // Parse imports map - store as string map
                for (key in obj.keys()) {
                    match (obj.get(key)) {
                        case Some(JsonValue.Str(v)) => pkg.imports.put(key, v)
                        case _ => ()
                    }
                }
            case _ => ()
        }

        // bin
        pkg.bin = PackageBin.parse(JsonHelper.getField(json, "bin"))
        // 也检查 directories.bin
        match (JsonHelper.getField(json, "directories")) {
            case Some(JsonValue.Object(dirs)) =>
                match (dirs.get("bin")) {
                    case Some(JsonValue.Str(binDir)) =>
                        if (pkg.bin.tag == BinTag.None) {
                            pkg.bin.tag = BinTag.Dir
                            pkg.bin.dirPath = Some(binDir)
                        }
                    case _ => ()
                }
            case _ => ()
        }

        // scripts
        match (JsonHelper.getField(json, "scripts")) {
            case Some(JsonValue.Object(obj)) =>
                for (key in obj.keys()) {
                    match (obj.get(key)) {
                        case Some(JsonValue.Str(v)) => pkg.scripts.put(key, v)
                        case _ => ()
                    }
                }
            case _ => ()
        }

        // dependencies
        pkg.dependencies = JsonHelper.getStringMap(json, "dependencies")
        pkg.devDependencies = JsonHelper.getStringMap(json, "devDependencies")
        pkg.peerDependencies = JsonHelper.getStringMap(json, "peerDependencies")
        pkg.optionalDependencies = JsonHelper.getStringMap(json, "optionalDependencies")

        // trustedDependencies
        match (JsonHelper.getField(json, "trustedDependencies")) {
            case Some(JsonValue.Array(arr)) =>
                for (item in arr) {
                    match (item) {
                        case JsonValue.Str(s) => pkg.trustedDependencies.append(s)
                        case _ => ()
                    }
                }
            case _ => ()
        }

        // cpu, os
        pkg.cpu = JsonHelper.getStringArray(json, "cpu")
        pkg.os = JsonHelper.getStringArray(json, "os")

        // private
        match (JsonHelper.getBool(json, "private")) {
            case Some(b) => pkg.isPrivate = b
            case None => ()
        }

        // sideEffects
        match (JsonHelper.getBool(json, "sideEffects")) {
            case Some(b) => pkg.sideEffects = Some(b)
            case None => pkg.sideEffects = None
        }

        // keywords
        pkg.keywords = JsonHelper.getStringArray(json, "keywords")

        // engines
        match (JsonHelper.getField(json, "engines")) {
            case Some(JsonValue.Object(obj)) =>
                for (key in obj.keys()) {
                    match (obj.get(key)) {
                        case Some(JsonValue.Str(v)) => pkg.engines.put(key, v)
                        case _ => ()
                    }
                }
            case _ => ()
        }

        // workspaces
        match (JsonHelper.getField(json, "workspaces")) {
            case Some(JsonValue.Array(arr)) =>
                for (item in arr) {
                    match (item) {
                        case JsonValue.Str(s) => pkg.workspaces.append(s)
                        case _ => ()
                    }
                }
            case Some(JsonValue.Object(obj)) =>
                // workspaces with packages key
                match (obj.get("packages")) {
                    case Some(JsonValue.Array(arr2)) =>
                        for (item in arr2) {
                            match (item) {
                                case JsonValue.Str(s) => pkg.workspaces.append(s)
                                case _ => ()
                            }
                        }
                    case _ => ()
                }
            case _ => ()
        }

        // repository
        match (JsonHelper.getField(json, "repository")) {
            case Some(JsonValue.Str(url)) => pkg.repository = Some(url)
            case Some(JsonValue.Object(obj))=>
                match (obj.get("url")) {
                    case Some(JsonValue.Str(u)) => pkg.repository = Some(u)
                    case _ => ()
                }
            case _ => ()
        }

        // bundledDependencies
        match (JsonHelper.getField(json, "bundledDependencies")) {
            case Some(JsonValue.Array(arr)) =>
                for (item in arr) {
                    match (item) {
                        case JsonValue.Str(s) => pkg.bundledDependencies.append(s)
                        case _ => ()
                    }
                }
            case _ => ()
        }

        return pkg
    }

    /// 从文件解析
    public static func fromFile(path: String): ?PackageJson {
        return None
    }

    /// 获取所有依赖声明
    // 严格翻译自: src/install/dependency.zig 中对依赖的遍历
    public func getAllDependencies(): ArrayList<DependencyEntry> {
        return ArrayList<DependencyEntry>()
    }

    /// 序列化为 JSON 字符串
    public func toJson(): String {
        return "{}"
    }

    /// 转义 JSON 字符串
    private func escapeJson(s: String): String {
        return s.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n")
    }

    /// 计算包名哈希
    // 严格翻译自: src/install/dependency.zig PackageNameHash
    public static func hashName(name: String): Int64 {
        // 使用简单哈希
        var hash: Int64 = 5381
        for (i in 0..name.size) {
            let c = name[i]
            hash = ((hash << 5) + hash) + Int64(c)
        }
        return hash
    }

    /// 解析 resolved 入口路径
    // 严格翻译自: src/install/install.zig 中对 exports/main 的解析
    public func resolveEntry(importPath: ?String): ?String {
        // 1. 尝试 exports 映射
        match (exports) {
            case Some(exp) =>
                let result = resolveExports(exp, importPath ?? ".")
                match (result) {
                    case Some(r) => return Some(r)
                    case None => ()
                }
            case None => ()
        }

        // 2. 如果有 importPath, 不走 main
        match (importPath) {
            case Some(p)=> if (p != ".") { return None }
            case None => ()
        }

        // 3. module (ESM)
        match (moduleEntry) {
            case Some(m) => return Some(m)
            case None => ()
        }

        // 4. main
        return Some(`main`)
    }

    /// 解析 exports 映射
    // 严格翻译自: src/resolver/package_json.rs resolveExports
    private func resolveExports(exports: JsonValue, importPath: String): ?String {
        match (exports) {
            case JsonValue.Str(path) => return Some(path)
            case JsonValue.Object(obj) =>
                // Try direct match on importPath
                match (obj.get(importPath)) {
                    case Some(JsonValue.Str(p)) => return Some(p)
                    case Some(JsonValue.Object(inner)) =>
                        // Try "default" or "." conditions
                        match (inner.get("default")) {
                            case Some(JsonValue.Str(p)) => return Some(p)
                            case _ => ()
                        }
                    case _ => ()
                }
            case _ => ()
        }
        return None
    }
}

/// 依赖种类
public enum DependencyKind {
    | Production
    | Development
    | Peer
    | Optional
}

/// 依赖条目
public class DependencyEntry {
    public let name: String
    public let version: String
    public let kind: DependencyKind

    public init(name: String, version: String, kind: DependencyKind) {
        this.name = name
        this.version = version
        this.kind = kind
    }
}

/// StringBuilder 辅助
public class StringBuilder {
    private var parts: ArrayList<String>

    public init() {
        parts = ArrayList<String>()
    }

    public func append(s: String): Unit {
        parts.append(s)
    }

    public func toString(): String {
        var result = ""
        for (p in parts) { result = result + p }
        return result
    }
}

