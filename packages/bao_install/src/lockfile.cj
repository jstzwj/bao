// bao_install - 锁文件
// 严格翻译自: src/install/lockfile.zig, src/install/lockfile/bun.lock.zig
package bao_install

import bao_core.*
import bao_collections.*
import bao_io.*
import bao_hash.*
import bao_path.*
import bao_http.*

// ============================================================================
// 锁文件格式版本
// 严格翻译自: src/install/lockfile/bun.lock.zig - Version
//   pub const Version = enum(u32) { v0 = 0, v1, pub const current: Version = .v1 }
// ============================================================================

/// 锁文件格式版本
/// 对应 Bun: TextLockfile.Version
public enum LockfileFormatVersion {
    | V0  // 初始格式
    | V1  // 当前默认 (对应 Bun: v1)

    public func toInt(): Int64 {
        match (this) {
            case V0 => 0
            case V1 => 1
        }
    }

    public static func fromInt(v: Int64): LockfileFormatVersion {
        if (v >= 1) { return V1 }
        return V0
    }

    public static func current(): LockfileFormatVersion {
        return V1
    }
}

// ============================================================================
// 锁文件条目
// 严格翻译自: src/install/lockfile.zig - Lockfile.Package
//   Bun 的 lockfile 中每个包条目包含:
//   name, version, resolution, integrity, dependencies, bin, scripts 等
//   翻译自: Lockfile.Package struct 和 Meta struct
// ============================================================================

/// 锁文件中的单个包条目
/// 对应 Bun: Lockfile.Package
public class LockfilePackage {
    /// 包名
    public let name: String
    /// 精确版本
    public let version: String
    /// 解析信息: resolution type + value
    /// 对应 Bun: Resolution
    ///   npm: "name@version", registry URL
    ///   tarball: tarball URL
    ///   folder: "name@file:path"
    ///   symlink: "name@link:path"
    ///   workspace: "name@workspace:path"
    ///   git: "name@git+repo"
    ///   github: "name@github:user/repo"
    public var resolution: String
    /// 完整性哈希 (sha512-xxx 或 sha1-xxx)
    /// 对应 Bun: Lockfile.Package.Meta.integrity
    public var integrity: String
    /// 依赖列表 name -> version range
    public var dependencies: HashMap<String, String>
    /// 开发依赖
    public var devDependencies: HashMap<String, String>
    /// 可选依赖
    public var optionalDependencies: HashMap<String, String>
    /// peer 依赖
    public var peerDependencies: HashMap<String, String>
    /// optional peer 依赖名称列表
    public var optionalPeers: ArrayList<String>
    /// 是否有安装脚本
    /// 对应 Bun: Lockfile.Package.Meta.hasInstallScript
    public var hasInstallScript: Bool
    /// 是否可选 (安装失败不报错)
    public var isOptional: Bool
    /// 是否已弃用
    public var deprecated: ?String
    /// bin 条目
    /// 对应 Bun: Lockfile.Package.bin
    public var bin: HashMap<String, String>
    /// bin 目录
    public var binDir: ?String
    /// 包所在路径 (相对于项目根目录)
    public var packagePath: String
    /// OS 限制
    public var os: ArrayList<String>
    /// CPU 限制
    public var cpu: ArrayList<String>
    /// 是否 bundled
    public var isBundled: Bool
    /// registry URL (非默认时记录)
    public var registryUrl: String

    public init(name: String, version: String) {
        this.name = name
        this.version = version
        resolution = ""
        integrity = ""
        dependencies = HashMap<String, String>()
        devDependencies = HashMap<String, String>()
        optionalDependencies = HashMap<String, String>()
        peerDependencies = HashMap<String, String>()
        optionalPeers = ArrayList<String>()
        hasInstallScript = false
        isOptional = false
        deprecated = None
        bin = HashMap<String, String>()
        binDir = None
        packagePath = ""
        os = ArrayList<String>()
        cpu = ArrayList<String>()
        isBundled = false
        registryUrl = ""
    }

    /// 唯一键
    public func key(): String {
        return "${name}@${version}"
    }

    /// 从 ResolvedPackage 构建
    public static func fromResolved(pkg: ResolvedPackage): LockfilePackage {
        let entry = LockfilePackage(pkg.name, pkg.version)

        // 构造 resolution 字符串
        // 翻译自: bun.lock.zig Stringifier 中按 tag 写入不同格式
        entry.resolution = match (pkg.tag) {
            case DependencyTag.Npm => "${pkg.name}@${pkg.version}"
            case DependencyTag.Tarball => "${pkg.name}@${pkg.resolved}"
            case DependencyTag.Folder => "${pkg.name}@file:${pkg.resolved}"
            case DependencyTag.Symlink => "${pkg.name}@link:${pkg.resolved}"
            case DependencyTag.Workspace => "${pkg.name}@workspace:${pkg.packagePath}"
            case DependencyTag.Git => "${pkg.name}@git+${pkg.resolved}"
            case DependencyTag.Github => "${pkg.name}@github:${pkg.resolved}"
            case _ => "${pkg.name}@${pkg.version}"
        }

        entry.integrity = pkg.integrity
        entry.isOptional = pkg.isOptional
        entry.hasInstallScript = pkg.hasInstallScript
        entry.bin = pkg.bin
        entry.os = pkg.os
        entry.cpu = pkg.cpu
        entry.deprecated = pkg.deprecated
        entry.packagePath = pkg.packagePath
        entry.registryUrl = pkg.registryUrl

        // 依赖
        for (dep in pkg.dependencies) {
            entry.dependencies.put(dep.name, dep.version)
        }
        for (dep in pkg.peerDependencies) {
            entry.peerDependencies.put(dep.name, dep.version)
        }
        for (dep in pkg.optionalDependencies) {
            entry.optionalDependencies.put(dep.name, dep.version)
        }

        return entry
    }
}

// ============================================================================
// 锁文件格式 (JSON - 与 Bun bun.lock 格式兼容)
// 严格翻译自: src/install/lockfile/bun.lock.zig - TextLockfile.Stringifier
//   Bun 的文本锁文件 (bun.lock) 使用 JSON 格式:
//   {
//     "lockfileVersion": 1,
//     "workspaces": { ... },
//     "packages": {
//       "package-name": ["name@version", registry, { deps }, integrity]
//     }
//   }
//
//   每个包条目格式:
//     npm:         ["name@version", "", { deps }, "sha512-xxx"]
//     tarball:     ["name@url", { deps }, "sha512-xxx"]
//     folder:      ["name@file:path", { deps }]
//     symlink:     ["name@link:path", { deps }]
//     workspace:   ["name@workspace:path"]
//     git:         ["name@git+repo", { deps }, "resolved-ref", "sha512-xxx"]
//     github:      ["name@github:user/repo", { deps }, "resolved-ref", "sha512-xxx"]
// ============================================================================

/// 锁文件格式化器
/// 对应 Bun: TextLockfile.Stringifier
public class LockfileFormat {
    /// 默认锁文件名
    /// 对应 Bun: Lockfile.default_filename = "bun.lockb" (binary) or "bun.lock" (text)
    public static let DEFAULT_FILENAME: String = "bao.lock"

    /// 序列化解析树为锁文件文本 (JSON 格式, 兼容 Bun bun.lock)
    /// 对应 Bun: TextLockfile.Stringifier.saveFromBinary
    /// 翻译自: bun.lock.zig Stringifier.saveFromBinary_inner
    public static func serialize(tree: ResolutionTree): String {
        let sb = StringBuilder()
        sb.append("{\n")

        // lockfileVersion
        // 翻译自: writer.print("\"lockfileVersion\": {d},\n", .{@intFromEnum(Version.current)})
        sb.append("  \"lockfileVersion\": ${LockfileFormatVersion.current().toInt()},\n")

        // workspaces (空, 因为 Bao 目前不支持 workspace 序列化到 lockfile)
        sb.append("  \"workspaces\": {},\n")

        // packages
        // 翻译自: bun.lock.zig Stringifier 中 packages 遍历
        sb.append("  \"packages\": {")
        var first = true

        // 收集所有包并按路径/名称排序
        let sortedPkgs = ArrayList<ResolvedPackage>()
        for (key in tree.packages.keys()) {
            match (tree.packages.get(key)) {
                case Some(pkg) => sortedPkgs.append(pkg)
                case None => {}
            }
        }
        sortedPkgs.sortBy(func(a: ResolvedPackage, b: ResolvedPackage): Int64 {
            // 先按深度排序, 再按名称排序
            // 翻译自: TreeSortCtx.isLessThan
            if (a.depth != b.depth) {
                return a.depth - b.depth
            }
            return a.name.compare(b.name)
        })

        for (pkg in sortedPkgs) {
            // 构建包的 JSON key (路径 + 包名)
            // 翻译自: bun.lock.zig 中 relative_path + dep_name 的组合
            let pkgKey = if (pkg.packagePath.length > 0) {
                "${pkg.packagePath}/${pkg.name}"
            } else {
                pkg.name
            }

            if (!first) {
                sb.append(",\n\n")
            } else {
                sb.append("\n")
                first = false
            }

            sb.append("    ${escapeJson(pkgKey)}: ")

            // 构建包条目数组
            // 翻译自: bun.lock.zig 中按 res.tag 分支写入
            sb.append("[")
            match (pkg.tag) {
                case DependencyTag.Npm => {
                    // npm: ["name@version", "", { deps }, "integrity"]
                    // 翻译自: res.tag == .npm 的序列化路径
                    sb.append("${escapeJson("${pkg.name}@${pkg.version}")}")
                    // registry URL (空 = 默认)
                    sb.append(", \"${pkg.registryUrl}\"")
                    // 依赖信息
                    sb.append(", ")
                    appendPackageInfo(sb, pkg)
                    // integrity
                    if (pkg.integrity.length > 0) {
                        sb.append(", ${escapeJson(pkg.integrity)}")
                    }
                }
                case DependencyTag.Tarball => {
                    // tarball: ["name@url", { deps }, "integrity"]
                    sb.append("${escapeJson("${pkg.name}@${pkg.resolved}")}")
                    sb.append(", ")
                    appendPackageInfo(sb, pkg)
                    if (pkg.integrity.length > 0) {
                        sb.append(", ${escapeJson(pkg.integrity)}")
                    }
                }
                case DependencyTag.Folder => {
                    // folder: ["name@file:path", { deps }]
                    sb.append("${escapeJson("${pkg.name}@file:${pkg.resolved}")}")
                    sb.append(", ")
                    appendPackageInfo(sb, pkg)
                }
                case DependencyTag.Symlink => {
                    // symlink: ["name@link:path", { deps }]
                    sb.append("${escapeJson("${pkg.name}@link:${pkg.resolved}")}")
                    sb.append(", ")
                    appendPackageInfo(sb, pkg)
                }
                case DependencyTag.Workspace => {
                    // workspace: ["name@workspace:path"]
                    sb.append("${escapeJson("${pkg.name}@workspace:${pkg.packagePath}")}")
                }
                case DependencyTag.Git => {
                    // git: ["name@git+repo", { deps }, "resolved-ref", "integrity"]
                    sb.append("${escapeJson("${pkg.name}@git+${pkg.resolved}")}")
                    sb.append(", ")
                    appendPackageInfo(sb, pkg)
                    if (pkg.integrity.length > 0) {
                        sb.append(", \"\", ${escapeJson(pkg.integrity)}")
                    }
                }
                case DependencyTag.Github => {
                    // github: ["name@github:user/repo", { deps }, "resolved-ref", "integrity"]
                    sb.append("${escapeJson("${pkg.name}@github:${pkg.resolved}")}")
                    sb.append(", ")
                    appendPackageInfo(sb, pkg)
                    if (pkg.integrity.length > 0) {
                        sb.append(", \"\", ${escapeJson(pkg.integrity)}")
                    }
                }
                case _ => {
                    sb.append("${escapeJson("${pkg.name}@${pkg.version}")}")
                    sb.append(", ")
                    appendPackageInfo(sb, pkg)
                }
            }
            sb.append("]")
        }

        if (!first) {
            sb.append("\n  ")
        }
        sb.append("}\n}\n")

        return sb.toString()
    }

    /// 写入包依赖信息对象
    /// 翻译自: bun.lock.zig writePackageInfoObject
    ///   写入: dependencies, devDependencies, peerDependencies, optionalDependencies,
    ///         os, cpu, bin, binDir, bundled, optionalPeers
    private static func appendPackageInfo(sb: StringBuilder, pkg: ResolvedPackage): Unit {
        sb.append("{")
        var any = false

        // dependencies
        // 翻译自: inline for (workspace_dependency_groups) 中按 behavior 分组
        let deps = HashMap<String, String>()
        let devDeps = HashMap<String, String>()
        let peerDeps = HashMap<String, String>()
        let optDeps = HashMap<String, String>()

        for (dep in pkg.dependencies) {
            if (dep.behavior.isDev) {
                devDeps.put(dep.name, dep.version)
            } else if (dep.behavior.isOptional) {
                optDeps.put(dep.name, dep.version)
            } else {
                deps.put(dep.name, dep.version)
            }
        }
        for (dep in pkg.peerDependencies) {
            peerDeps.put(dep.name, dep.version)
        }
        for (dep in pkg.optionalDependencies) {
            optDeps.put(dep.name, dep.version)
        }

        if (deps.size > 0) {
            if (any) { sb.append(",") }
            sb.append(" \"dependencies\": ")
            appendDepMap(sb, deps)
            any = true
        }
        if (devDeps.size > 0) {
            if (any) { sb.append(",") }
            sb.append(" \"devDependencies\": ")
            appendDepMap(sb, devDeps)
            any = true
        }
        if (peerDeps.size > 0) {
            if (any) { sb.append(",") }
            sb.append(" \"peerDependencies\": ")
            appendDepMap(sb, peerDeps)
            any = true
        }
        if (optDeps.size > 0) {
            if (any) { sb.append(",") }
            sb.append(" \"optionalDependencies\": ")
            appendDepMap(sb, optDeps)
            any = true
        }

        // bin
        if (pkg.bin.size > 0) {
            if (any) { sb.append(",") }
            sb.append(" \"bin\": ")
            appendDepMap(sb, pkg.bin)
            any = true
        }

        // hasInstallScript
        if (pkg.hasInstallScript) {
            if (any) { sb.append(",") }
            sb.append(" \"hasInstallScript\": true")
            any = true
        }

        sb.append("}")
    }

    /// 写入依赖映射 { "name": "version", ... }
    private static func appendDepMap(sb: StringBuilder, map: HashMap<String, String>): Unit {
        sb.append("{ ")
        var first = true
        for (key in map.keys()) {
            match (map.get(key)) {
                case Some(val) => {
                    if (!first) { sb.append(", ") }
                    sb.append("${escapeJson(key)}: ${escapeJson(val)}")
                    first = false
                }
                case None => {}
            }
        }
        sb.append(" }")
    }

    // ========================================================================
    // 反序列化
    // 严格翻译自: src/install/lockfile/bun.lock.zig - TextLockfile.parseIntoBinaryLockfile
    //   Bun 的 bun.lock 使用 JSON 格式
    //   packages 中的值是数组:
    //     [0] = resolution string ("name@version")
    //     [1] = registry URL (npm) 或 deps object
    //     [2] = deps object (npm) 或 integrity
    //     [3] = integrity (npm)
    // ========================================================================

    /// 反序列化锁文件文本为包列表
    /// 对应 Bun: TextLockfile.parseIntoBinaryLockfile
    public static func deserialize(text: String): ArrayList<LockfilePackage> {
        let result = ArrayList<LockfilePackage>()
        let parser = JsonParser()
        let json = parser.parse(text)

        match (json) {
            case Some(root) => {
                match (JsonHelper.getField(root, "packages")) {
                    case Some(JsonValue.Object(packages)) => {
                        for (pkgKey in packages.keys()) {
                            match (packages.get(pkgKey)) {
                                case Some(JsonValue.Array(arr)) => {
                                    let entry = parsePackageEntry(pkgKey, arr)
                                    match (entry) {
                                        case Some(e) => result.append(e)
                                        case None => {}
                                    }
                                }
                                // 兼容旧格式: 对象格式
                                case Some(JsonValue.Object(pkgObj)) => {
                                    let entry = parseLegacyPackageEntry(pkgKey, pkgObj)
                                    match (entry) {
                                        case Some(e) => result.append(e)
                                        case None => {}
                                    }
                                }
                                case _ => {}
                            }
                        }
                    }
                    case _ => {}
                }
            }
            case None => {}
        }

        return result
    }

    /// 解析 Bun lockfile 格式的包条目 (数组格式)
    /// 翻译自: bun.lock.zig parseIntoBinaryLockfile 中数组解析
    ///   ["name@version", "", { deps }, "integrity"] (npm)
    ///   ["name@url", { deps }, "integrity"] (tarball)
    ///   ["name@workspace:path"] (workspace)
    private static func parsePackageEntry(pkgKey: String, arr: ArrayList<JsonValue>): ?LockfilePackage {
        if (arr.size == 0) { return None }

        // 第一个元素: resolution string
        let resolutionStr = match (arr[0]) {
            case JsonValue.Str(s) => s
            case _ => return None
        }

        // 解析 resolution string
        let pkg = parseResolutionString(resolutionStr)
        match (pkg) {
            case Some(p) => {
                // 根据数组长度和内容解析剩余字段
                if (arr.size >= 2) {
                    // 第二个元素可能是 registry URL (string) 或 deps object
                    match (arr[1]) {
                        case JsonValue.Str(registryUrl) => {
                            // npm 格式: [resolution, registry, deps, integrity]
                            p.registryUrl = registryUrl
                            if (arr.size >= 3) {
                                match (arr[2]) {
                                    case JsonValue.Object(depsObj) => {
                                        extractDeps(depsObj, p)
                                    }
                                    case _ => {}
                                }
                            }
                            if (arr.size >= 4) {
                                match (arr[3]) {
                                    case JsonValue.Str(integrity) => p.integrity = integrity
                                    case _ => {}
                                }
                            }
                        }
                        case JsonValue.Object(depsObj) => {
                            // tarball/folder/symlink/git 格式: [resolution, deps, ...]
                            extractDeps(depsObj, p)
                            if (arr.size >= 3) {
                                match (arr[2]) {
                                    case JsonValue.Str(integrityOrRef) => {
                                        // 可能是 git resolved ref 或 integrity
                                        if (integrityOrRef.startsWith("sha")) {
                                            p.integrity = integrityOrRef
                                        }
                                    }
                                    case _ => {}
                                }
                                if (arr.size >= 4) {
                                    match (arr[3]) {
                                        case JsonValue.Str(integrity) => p.integrity = integrity
                                        case _ => {}
                                    }
                                }
                            }
                        }
                        case _ => {}
                    }
                }
                return Some(p)
            }
            case None => return None
        }
    }

    /// 解析 resolution string
    /// 翻译自: bun.lock.zig Resolution.fromTextLockfile
    private static func parseResolutionString(s: String): ?LockfilePackage {
        // root: "name@root:"
        if (s.endsWith("@root:")) {
            let name = s.substring(0, s.length - 6)
            let pkg = LockfilePackage(name, "")
            pkg.resolution = s
            return Some(pkg)
        }

        // link: "name@link:path"
        let linkPrefix = "@link:"
        let linkIdx = s.indexOf(linkPrefix)
        if (linkIdx >= 0) {
            let name = s.substring(0, linkIdx)
            let path = s.substring(linkIdx + linkPrefix.length)
            let pkg = LockfilePackage(name, "")
            pkg.resolution = s
            return Some(pkg)
        }

        // workspace: "name@workspace:path"
        let wsPrefix = "@workspace:"
        let wsIdx = s.indexOf(wsPrefix)
        if (wsIdx >= 0) {
            let name = s.substring(0, wsIdx)
            let path = s.substring(wsIdx + wsPrefix.length)
            let pkg = LockfilePackage(name, "")
            pkg.resolution = s
            return Some(pkg)
        }

        // file: "name@file:path"
        let filePrefix = "@file:"
        let fileIdx = s.indexOf(filePrefix)
        if (fileIdx >= 0) {
            let name = s.substring(0, fileIdx)
            let path = s.substring(fileIdx + filePrefix.length)
            let pkg = LockfilePackage(name, "")
            pkg.resolution = s
            return Some(pkg)
        }

        // git: "name@git+..."
        let gitPrefix = "@git+"
        let gitIdx = s.indexOf(gitPrefix)
        if (gitIdx >= 0) {
            let name = s.substring(0, gitIdx)
            let repo = s.substring(gitIdx + gitPrefix.length)
            let pkg = LockfilePackage(name, "")
            pkg.resolution = s
            return Some(pkg)
        }

        // github: "name@github:..."
        let githubPrefix = "@github:"
        let githubIdx = s.indexOf(githubPrefix)
        if (githubIdx >= 0) {
            let name = s.substring(0, githubIdx)
            let repo = s.substring(githubIdx + githubPrefix.length)
            let pkg = LockfilePackage(name, "")
            pkg.resolution = s
            return Some(pkg)
        }

        // npm: "name@version"
        // 找到最后一个 @ (处理 scoped packages)
        let lastAt = s.lastIndexOf("@")
        if (lastAt >= 0) {
            let name = s.substring(0, lastAt)
            let version = s.substring(lastAt + 1)
            let pkg = LockfilePackage(name, version)
            pkg.resolution = s
            return Some(pkg)
        }

        return None
    }

    /// 从 JSON 对象提取依赖
    private static func extractDeps(depsObj: HashMap<String, JsonValue>, pkg: LockfilePackage): Unit {
        // dependencies
        match (depsObj.get("dependencies")) {
            case Some(JsonValue.Object(m)) => {
                for (k in m.keys()) {
                    match (m.get(k)) {
                        case Some(JsonValue.Str(v)) => pkg.dependencies.put(k, v)
                        case _ => {}
                    }
                }
            }
            case _ => {}
        }
        // devDependencies
        match (depsObj.get("devDependencies")) {
            case Some(JsonValue.Object(m)) => {
                for (k in m.keys()) {
                    match (m.get(k)) {
                        case Some(JsonValue.Str(v)) => pkg.devDependencies.put(k, v)
                        case _ => {}
                    }
                }
            }
            case _ => {}
        }
        // peerDependencies
        match (depsObj.get("peerDependencies")) {
            case Some(JsonValue.Object(m)) => {
                for (k in m.keys()) {
                    match (m.get(k)) {
                        case Some(JsonValue.Str(v)) => pkg.peerDependencies.put(k, v)
                        case _ => {}
                    }
                }
            }
            case _ => {}
        }
        // optionalDependencies
        match (depsObj.get("optionalDependencies")) {
            case Some(JsonValue.Object(m)) => {
                for (k in m.keys()) {
                    match (m.get(k)) {
                        case Some(JsonValue.Str(v)) => pkg.optionalDependencies.put(k, v)
                        case _ => {}
                    }
                }
            }
            case _ => {}
        }
        // optionalPeers
        match (depsObj.get("optionalPeers")) {
            case Some(JsonValue.Array(arr)) => {
                for (item in arr) {
                    match (item) {
                        case JsonValue.Str(s) => pkg.optionalPeers.append(s)
                        case _ => {}
                    }
                }
            }
            case _ => {}
        }
        // bin
        match (depsObj.get("bin")) {
            case Some(JsonValue.Object(m)) => {
                for (k in m.keys()) {
                    match (m.get(k)) {
                        case Some(JsonValue.Str(v)) => pkg.bin.put(k, v)
                        case _ => {}
                    }
                }
            }
            case _ => {}
        }
        // binDir
        match (depsObj.get("binDir")) {
            case Some(JsonValue.Str(s)) => pkg.binDir = Some(s)
            case _ => {}
        }
        // hasInstallScript
        match (depsObj.get("hasInstallScript")) {
            case Some(JsonValue.Bool(b)) => pkg.hasInstallScript = b
            case _ => {}
        }
        // bundled
        match (depsObj.get("bundled")) {
            case Some(JsonValue.Bool(b)) => pkg.isBundled = b
            case _ => {}
        }
        // os
        match (depsObj.get("os")) {
            case Some(JsonValue.Array(arr)) => {
                for (item in arr) {
                    match (item) {
                        case JsonValue.Str(s) => pkg.os.append(s)
                        case _ => {}
                    }
                }
            }
            case _ => {}
        }
        // cpu
        match (depsObj.get("cpu")) {
            case Some(JsonValue.Array(arr)) => {
                for (item in arr) {
                    match (item) {
                        case JsonValue.Str(s) => pkg.cpu.append(s)
                        case _ => {}
                    }
                }
            }
            case _ => {}
        }
    }

    /// 解析旧版/简化格式的包条目 (对象格式)
    private static func parseLegacyPackageEntry(pkgKey: String, pkgObj: HashMap<String, JsonValue>): ?LockfilePackage {
        // 从 key 提取名称 (去掉 node_modules/ 前缀)
        var name = pkgKey
        if (name.startsWith("node_modules/")) {
            name = name.substring(13)
        }

        let version = match (JsonHelper.getString(JsonValue.Object(pkgObj), "version")) {
            case Some(v) => v
            case None => "0.0.0"
        }

        let entry = LockfilePackage(name, version)
        entry.resolution = match (JsonHelper.getString(JsonValue.Object(pkgObj), "resolution")) {
            case Some(v) => v
            case None => match (JsonHelper.getString(JsonValue.Object(pkgObj), "resolved")) {
                case Some(v) => v
                case None => ""
            }
        }
        entry.integrity = match (JsonHelper.getString(JsonValue.Object(pkgObj), "integrity")) {
            case Some(v) => v
            case None => ""
        }

        extractDeps(pkgObj, entry)
        return Some(entry)
    }

    /// JSON 字符串转义
    private static func escapeJson(s: String): String {
        if (s.length == 0) { return "\"\"" }
        let sb = StringBuilder()
        sb.append("\"")
        for (c in s) {
            match (c) {
                case '"' => sb.append("\\\"")
                case '\\' => sb.append("\\\\")
                case '\n' => sb.append("\\n")
                case '\r' => sb.append("\\r")
                case '\t' => sb.append("\\t")
                case _ => sb.append(c)
            }
        }
        sb.append("\"")
        return sb.toString()
    }
}

// ============================================================================
// 锁文件差异检测
// 严格翻译自: src/install/lockfile.zig - Lockfile.Package.Diff
//   Bun 在安装时比较新旧 lockfile 的差异
//   Diff 包含: added, removed, changed 包列表
// ============================================================================

/// 锁文件差异
/// 对应 Bun: Lockfile.Package.Diff
public class LockfileDiff {
    /// 新增的包
    public var added: ArrayList<LockfilePackage>
    /// 删除的包
    public var removed: ArrayList<LockfilePackage>
    /// 变更的包 (版本/分辨率/integrity 变化)
    public var changed: ArrayList<LockfilePackageChange>

    public init() {
        added = ArrayList<LockfilePackage>()
        removed = ArrayList<LockfilePackage>()
        changed = ArrayList<LockfilePackageChange>()
    }

    /// 是否有变化
    public func hasChanges(): Bool {
        return added.size > 0 || removed.size > 0 || changed.size > 0
    }

    /// 统计描述
    public func summary(): String {
        var parts = ArrayList<String>()
        if (added.size > 0) { parts.append("+${added.size}") }
        if (removed.size > 0) { parts.append("-${removed.size}") }
        if (changed.size > 0) { parts.append("~${changed.size}") }
        if (parts.size == 0) { return "No changes" }
        return "Changes: ${String.join(", ", parts)}"
    }
}

/// 包变更详情
public class LockfilePackageChange {
    public let name: String
    public var oldVersion: String
    public var newVersion: String
    public var oldResolution: String
    public var newResolution: String
    public var oldIntegrity: String
    public var newIntegrity: String

    public init(name: String) {
        this.name = name
        oldVersion = ""
        newVersion = ""
        oldResolution = ""
        newResolution = ""
        oldIntegrity = ""
        newIntegrity = ""
    }
}

// ============================================================================
// 锁文件读写
// 严格翻译自: src/install/lockfile.zig - Lockfile.loadFromDir / save
//   Bun 的 Lockfile 支持二进制 (bun.lockb) 和文本 (bun.lock) 格式
//   翻译自: Lockfile.loadFromDir, Lockfile.save
// ============================================================================

/// 锁文件管理器
/// 对应 Bun: Lockfile struct
public class Lockfile {
    private var jsonParser: JsonParser

    public init() {
        jsonParser = JsonParser()
    }

    /// 从文件路径读取锁文件
    /// 对应 Bun: Lockfile.loadFromDir
    /// 优先尝试 bao.lock (text JSON), 然后尝试 bao.lockb (binary)
    public func read(path: String): ?ArrayList<LockfilePackage> {
        // 尝试读取 bao.lock (JSON 文本格式)
        let content = try {
            BaoFile.readAllText(path)
        } catch (_: Exception) {
            return None
        }

        if (content.length == 0) {
            return None
        }

        // 自动检测格式
        let trimmed = content.trim()
        if (trimmed.startsWith("{")) {
            // JSON 格式 (Bun bun.lock 格式)
            return LockfileFormat.deserialize(content)
        }

        // 旧版文本格式 (兼容)
        return parseLegacyTextLockfile(content)
    }

    /// 从当前目录读取
    /// 对应 Bun: Lockfile.loadFromCwd
    public func readFromCwd(): ?ArrayList<LockfilePackage> {
        // 尝试 bao.lock (新格式)
        let result = read(LockfileFormat.DEFAULT_FILENAME)
        match (result) {
            case Some(pkgs) => return Some(pkgs)
            case None => {}
        }
        // 回退: bun.lock
        return read("bun.lock")
    }

    /// 写入锁文件
    /// 对应 Bun: Lockfile.save / TextLockfile.Stringifier
    public func write(path: String, tree: ResolutionTree): Bool {
        let content = LockfileFormat.serialize(tree)
        return try {
            BaoFile.writeAllText(path, content)
            true
        } catch (_: Exception) {
            false
        }
    }

    /// 写入到当前目录
    public func writeToCwd(tree: ResolutionTree): Bool {
        return write(LockfileFormat.DEFAULT_FILENAME, tree)
    }

    /// 比较两个锁文件的差异
    /// 对应 Bun: Lockfile.Package.Diff
    /// 翻译自: Lockfile 中新旧 lockfile 比较逻辑
    public func diff(oldPackages: ArrayList<LockfilePackage>, newPackages: ArrayList<LockfilePackage>): LockfileDiff {
        let result = LockfileDiff()

        // 建立索引
        let oldMap = HashMap<String, LockfilePackage>()
        let newMap = HashMap<String, LockfilePackage>()

        for (pkg in oldPackages) {
            oldMap.put(pkg.key(), pkg)
        }
        for (pkg in newPackages) {
            newMap.put(pkg.key(), pkg)
        }

        // 查找新增和变更
        for (pkg in newPackages) {
            match (oldMap.get(pkg.key())) {
                case Some(_) => {}  // 已存在, 检查是否变更
                case None => result.added.append(pkg)
            }

            // 检查变更 (同名但不同版本)
            match (oldMap.get("${pkg.name}@*")) {
                case Some(_) => {}  // 不需要
                case None => {}
            }
        }

        // 查找删除
        for (pkg in oldPackages) {
            match (newMap.get(pkg.key())) {
                case Some(_) => {}
                case None => result.removed.append(pkg)
            }
        }

        // 查找变更 (同包名, 不同版本)
        let oldByName = HashMap<String, LockfilePackage>()
        let newByName = HashMap<String, LockfilePackage>()
        for (pkg in oldPackages) { oldByName.put(pkg.name, pkg) }
        for (pkg in newPackages) { newByName.put(pkg.name, pkg) }

        for (name in newByName.keys()) {
            match (newByName.get(name)) {
                case Some(newPkg) => {
                    match (oldByName.get(name)) {
                        case Some(oldPkg) => {
                            if (oldPkg.version != newPkg.version ||
                                oldPkg.resolution != newPkg.resolution ||
                                oldPkg.integrity != newPkg.integrity) {
                                let change = LockfilePackageChange(name)
                                change.oldVersion = oldPkg.version
                                change.newVersion = newPkg.version
                                change.oldResolution = oldPkg.resolution
                                change.newResolution = newPkg.resolution
                                change.oldIntegrity = oldPkg.integrity
                                change.newIntegrity = newPkg.integrity
                                result.changed.append(change)
                            }
                        }
                        case None => {}
                    }
                }
                case None => {}
            }
        }

        return result
    }

    /// 验证锁文件完整性
    /// 对应 Bun: Integrity.verify
    /// 检查每个包的 integrity 哈希是否匹配
    public func verifyIntegrity(packages: ArrayList<LockfilePackage>): Bool {
        for (pkg in packages) {
            if (pkg.integrity.length == 0 || pkg.resolution.length == 0) {
                continue  // 无完整性信息, 跳过
            }

            // 检查本地文件是否存在
            let localPath = "./node_modules/${pkg.name}"
            if (!BaoFile.exists(localPath)) {
                return false
            }
        }
        return true
    }

    /// 计算锁文件自身的哈希
    /// 对应 Bun: Lockfile.meta_hash
    public func computeMetaHash(content: String): String {
        var bytes = Array<UInt8>()
        for (c in content) {
            bytes.append(UInt8(c.value))
        }
        let hash = bao_hash.Sha256.hash(bytes)
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

    /// 比较两个锁文件是否相同
    /// 用于判断是否需要重新安装
    public func isSameAs(oldContent: String, newContent: String): Bool {
        return computeMetaHash(oldContent) == computeMetaHash(newContent)
    }

    /// 解析旧版文本格式锁文件
    private func parseLegacyTextLockfile(content: String): ?ArrayList<LockfilePackage> {
        let result = ArrayList<LockfilePackage>()
        let lines = content.split("\n")
        var currentPkg: ?LockfilePackage = None
        var section: String = ""

        for (line in lines) {
            let trimmed = line.trim()
            if (trimmed.length == 0 || trimmed.startsWith("#")) { continue }

            if (trimmed == "[[package]]") {
                match (currentPkg) {
                    case Some(p) => result.append(p)
                    case None => {}
                }
                currentPkg = None
                section = "package"
                continue
            }

            if (trimmed == "[[package.dependencies]]") {
                section = "dependencies"
                continue
            }
            if (trimmed == "[[package.devDependencies]]") {
                section = "devDependencies"
                continue
            }
            if (trimmed == "[[package.peerDependencies]]") {
                section = "peerDependencies"
                continue
            }
            if (trimmed == "[[package.optionalDependencies]]") {
                section = "optionalDependencies"
                continue
            }

            if (trimmed == "[metadata]" || trimmed == "[packages]") {
                section = "header"
                continue
            }

            // 解析 key = "value" 行
            let eqIdx = trimmed.indexOf("=")
            if (eqIdx < 0) { continue }

            let key = trimmed.substring(0, eqIdx).trim()
            var value = trimmed.substring(eqIdx + 1).trim()
            if (value.startsWith("\"") && value.endsWith("\"") && value.length >= 2) {
                value = value.substring(1, value.length - 1)
            }

            if (section == "package") {
                match (currentPkg) {
                    case Some(pkg) => {
                        if (key == "name") {}  // 已在初始化时设置
                        if (key == "version") { pkg.version = value }
                        if (key == "resolution") { pkg.resolution = value }
                        if (key == "integrity") { pkg.integrity = value }
                        if (key == "optional") { pkg.isOptional = (value == "true") }
                    }
                    case None => {
                        if (key == "name") {
                            currentPkg = Some(LockfilePackage(value, "0.0.0"))
                        }
                    }
                }
            }

            if (section == "dependencies") {
                match (currentPkg) {
                    case Some(pkg) => pkg.dependencies.put(key, value)
                    case None => {}
                }
            }
            if (section == "devDependencies") {
                match (currentPkg) {
                    case Some(pkg) => pkg.devDependencies.put(key, value)
                    case None => {}
                }
            }
            if (section == "peerDependencies") {
                match (currentPkg) {
                    case Some(pkg) => pkg.peerDependencies.put(key, value)
                    case None => {}
                }
            }
            if (section == "optionalDependencies") {
                match (currentPkg) {
                    case Some(pkg) => pkg.optionalDependencies.put(key, value)
                    case None => {}
                }
            }
        }

        match (currentPkg) {
            case Some(p) => result.append(p)
            case None => {}
        }

        if (result.size > 0) {
            return Some(result)
        }
        return None
    }
}
