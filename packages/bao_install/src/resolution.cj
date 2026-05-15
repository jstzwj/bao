// bao_install - 依赖解析
// 严格翻译自: src/install/dependency.zig, src/install/resolution.zig
package bao_install

import bao_core.*
import bao_collections.*
import bao_io.*
import bao_hash.*
import bao_path.*
import bao_http.*

// ============================================================================
// 依赖行为标志
// 严格翻译自: src/install/dependency.zig - Behavior
//   pub const Behavior = packed struct(u8) {
//       peer: bool = false,
//       dev: bool = false,
//       optional: bool = false,
//       workspace: bool = false,
//       bundled: bool = false,
//   }
// ============================================================================

/// 依赖行为标志
/// 对应 Bun: Dependency.Behavior (bitfield)
public class DependencyBehavior {
    public var isPeer: Bool
    public var isDev: Bool
    public var isOptional: Bool
    public var isWorkspace: Bool
    public var isBundled: Bool

    public init() {
        isPeer = false
        isDev = false
        isOptional = false
        isWorkspace = false
        isBundled = false
    }

    /// 比较排序优先级
    /// 对应 Bun: Behavior.cmp
    /// 翻译自: src/install/dependency.zig Behavior.cmp
    /// 排序: peer > optional > dev > normal (按权重降序)
    public func compare(other: DependencyBehavior): Int64 {
        let thisVal = (if (isPeer) { 8 } else { 0 }) +
                      (if (isOptional) { 4 } else { 0 }) +
                      (if (isDev) { 2 } else { 0 }) +
                      (if (isBundled) { 1 } else { 0 })
        let otherVal = (if (other.isPeer) { 8 } else { 0 }) +
                       (if (other.isOptional) { 4 } else { 0 }) +
                       (if (other.isDev) { 2 } else { 0 }) +
                       (if (other.isBundled) { 1 } else { 0 })
        if (thisVal < otherVal) { return -1 }
        if (thisVal > otherVal) { return 1 }
        return 0
    }

    /// 是否包含指定行为
    public func includes(other: DependencyBehavior): Bool {
        if (other.isPeer && !isPeer) { return false }
        if (other.isDev && !isDev) { return false }
        if (other.isOptional && !isOptional) { return false }
        if (other.isWorkspace && !isWorkspace) { return false }
        if (other.isBundled && !isBundled) { return false }
        return true
    }

    /// 是否是 optional peer
    public func isOptionalPeer(): Bool {
        return isPeer && isOptional
    }
}

// ============================================================================
// 依赖版本标签
// 严格翻译自: src/install/dependency.zig - Dependency.Version.Tag
//   pub const Tag = enum(u8) {
//       uninitialized, npm, dist_tag, tarball, folder, symlink, workspace,
//       git, github, catalog
//   }
// ============================================================================

/// 依赖版本标签
public enum DependencyTag {
    | Uninitialized
    | Npm            // semver range: ^1.2.3
    | DistTag        // npm dist-tag: latest, next, beta
    | Tarball        // .tgz URL or path
    | Folder         // local folder
    | Symlink        // link:path
    | Workspace      // workspace:*
    | Git            // git repository
    | Github         // github:owner/repo
    | Catalog        // catalog: (pnpm-like)

    public func toString(): String {
        match (this) {
            case Uninitialized => "uninitialized"
            case Npm => "npm"
            case DistTag => "dist-tag"
            case Tarball => "tarball"
            case Folder => "folder"
            case Symlink => "symlink"
            case Workspace => "workspace"
            case Git => "git"
            case Github => "github"
            case Catalog => "catalog"
        }
    }

    /// 是否需要网络请求
    /// 对应 Bun: Tag.canEnqueueInstallTask
    public func needsNetwork(): Bool {
        match (this) {
            case Npm => true
            case DistTag => true
            case Tarball => true
            case Git => true
            case Github => true
            case _ => false
        }
    }

    /// 是否是 git 类型
    /// 对应 Bun: Resolution.isGit
    public func isGit(): Bool {
        match (this) {
            case Git => true
            case Github => true
            case _ => false
        }
    }
}

// ============================================================================
// 依赖描述
// 严格翻译自: src/install/dependency.zig - Dependency
//   pub const Dependency = struct {
//       name_hash: PackageNameHash,
//       name: String,
//       version: Version,
//       behavior: Behavior,
//   }
// ============================================================================

/// 依赖描述
/// 对应 Bun: Dependency struct
public class Dependency {
    public let name: String
    public let version: String       // 版本范围字面量
    public var tag: DependencyTag    // 版本类型
    public var behavior: DependencyBehavior
    public var alias: ?String        // npm alias: "alias": "npm:real@version"

    public init(name: String, version: String) {
        this.name = name
        this.version = version
        this.tag = inferTag(version)
        this.behavior = DependencyBehavior()
        this.alias = None
    }

    public init(name: String, version: String, tag: DependencyTag) {
        this.name = name
        this.version = version
        this.tag = tag
        this.behavior = DependencyBehavior()
        this.alias = None
    }

    /// 推断版本标签
    /// 对应 Bun: Dependency.Version.Tag.infer
    /// 翻译自: src/install/dependency.zig Tag.infer
    public static func inferTag(version: String): DependencyTag {
        if (version.length == 0) { return DependencyTag.DistTag }

        let c = version[0]
        // ^, =, >, <, *, | -> npm semver
        if (c == '^' || c == '=' || c == '>' || c == '<' || c == '*' || c == '|') {
            return DependencyTag.Npm
        }
        // ~1.2.3 or ~/path
        if (c == '~') {
            if (version.length > 1 && version[1] == '/') {
                return DependencyTag.Folder
            }
            return DependencyTag.Npm
        }
        // ./path or ../path
        if (c == '.' || c == '/') {
            if (isTarball(version)) { return DependencyTag.Tarball }
            return DependencyTag.Folder
        }
        // 数字开头: 1.2.3
        if (c >= '0' && c <= '9') {
            if (isTarball(version)) { return DependencyTag.Tarball }
            return DependencyTag.Npm
        }
        // file: prefix
        if (version.startsWith("file:")) {
            let rest = version.substring(5)
            if (isTarball(rest)) { return DependencyTag.Tarball }
            return DependencyTag.Folder
        }
        // link: prefix
        if (version.startsWith("link:")) {
            return DependencyTag.Symlink
        }
        // workspace: prefix
        if (version.startsWith("workspace:")) {
            return DependencyTag.Workspace
        }
        // git/https/http
        if (version.startsWith("git+")) { return DependencyTag.Git }
        if (version.startsWith("github:")) { return DependencyTag.Github }
        if (version.startsWith("https://") || version.startsWith("http://")) {
            return DependencyTag.Tarball
        }
        // npm: alias
        if (version.startsWith("npm:")) { return DependencyTag.Npm }
        // catalog:
        if (version.startsWith("catalog:")) { return DependencyTag.Catalog }

        // SCP-like path: user@host:path (git shorthand)
        // 翻译自: Dependency.isSCPLikePath
        if (isSCPLikePath(version)) {
            return DependencyTag.Git
        }

        // GitHub tarball URL
        // 翻译自: Dependency.isGitHubTarballPath
        if (isGitHubTarballPath(version)) {
            return DependencyTag.Github
        }

        // 默认为 dist-tag (如 "latest", "next")
        return DependencyTag.DistTag
    }

    /// 判断是否是 tarball 路径
    /// 对应 Bun: Dependency.isTarball
    private static func isTarball(s: String): Bool {
        return s.endsWith(".tgz") || s.endsWith(".tar.gz")
    }

    /// 判断是否是 SCP 风格路径
    /// 翻译自: Dependency.isSCPLikePath
    ///   user@host:path 或 git@github.com:user/repo
    private static func isSCPLikePath(dependency: String): Bool {
        if (dependency.length < 3) { return false }
        var atIndex: Int64 = -1
        var i: Int64 = 0
        while (i < dependency.length) {
            let c = dependency[i]
            if (c == '@') {
                if (atIndex < 0) { atIndex = i }
            } else if (c == ':') {
                if (i + 2 < dependency.length && dependency[Int64(i) + 1] == '/' && dependency[Int64(i) + 2] == '/') {
                    // "://" -> 这是 URL, 不是 SCP
                    return false
                }
                return i > atIndex + 1 && atIndex >= 0
            } else if (c == '/') {
                return if (atIndex >= 0) { i > atIndex + 1 } else { false }
            }
            i += 1
        }
        return false
    }

    /// 判断是否是 GitHub tarball 路径
    /// 翻译自: Dependency.isGitHubTarballPath
    private static func isGitHubTarballPath(dependency: String): Bool {
        if (isTarball(dependency)) { return true }
        // 检查 .../tarball/... 模式
        let parts = dependency.split("/")
        var count: Int64 = 0
        for (part in parts) {
            count += 1
            if (count == 3 && part == "tarball") {
                return true
            }
        }
        return false
    }

    /// 判断是否是远程 tarball
    /// 翻译自: Dependency.isRemoteTarball
    public static func isRemoteTarball(s: String): Bool {
        return (s.startsWith("https://") || s.startsWith("http://")) && isTarball(s)
    }

    /// 获取真实包名 (用于 alias)
    /// 对应 Bun: Dependency.realname
    /// 翻译自: src/install/dependency.zig realname
    ///   对于 npm: alias -> 返回 alias 中的真实包名
    ///   对于 dist_tag -> 返回 dist_tag.name
    ///   对于 git/github -> 返回对应的 package_name
    public func realName(): String {
        if (version.startsWith("npm:")) {
            // npm:package@version 或 npm:@scope/package@version
            let rest = version.substring(4)
            // 处理 scoped package: npm:@scope/pkg@version
            let startIdx: Int64 = if (rest.startsWith("@")) { Int64(1) + rest.indexOf("@", Int64(1)) } else { -1 }
            match (startIdx) {
                case -1 => {
                    // 没有 @version 部分, 整个字符串是包名
                    let atIndex = rest.indexOf("@", Int64(1))
                    if (atIndex >= 0) {
                        return rest.substring(0, atIndex)
                    }
                    return rest
                }
                case idx => {
                    // 跳过第一个 @ (scope)
                    let atIndex = rest.indexOf("@", Int64(1))
                    if (atIndex >= 0) {
                        return rest.substring(0, atIndex)
                    }
                    return rest
                }
            }
        }
        return name
    }

    /// 是否是 aliased 依赖
    /// 翻译自: Dependency.isAliased
    public func isAliased(): Bool {
        if (version.startsWith("npm:")) {
            let realName = realName()
            return realName != name
        }
        return false
    }

    /// 获取解析后的版本字符串
    /// 对应 Bun: 从 npm: alias 或 workspace: 提取版本
    public func resolvedVersion(): String {
        if (version.startsWith("npm:")) {
            let rest = version.substring(4)
            let atIndex = rest.indexOf("@", Int64(1))
            if (atIndex >= 0) {
                return rest.substring(atIndex + 1)
            }
            return "latest"
        }
        if (version.startsWith("workspace:")) {
            let rest = version.substring(10)
            // workspace:* 或 workspace:^
            if (rest == "*" || rest == "^" || rest == "~") {
                return rest
            }
            return rest
        }
        if (version.startsWith("catalog:")) {
            return version.substring(8)
        }
        return version
    }
}

// ============================================================================
// 已解析包
// 严格翻译自: src/install/resolution.zig - Resolution
//   pub const Resolution = ResolutionType(u64)
//   包含 tag + value (npm version, tarball URL, folder path, etc.)
//   翻译自: src/install/resolution.zig ResolutionType
//     .tag: npm, git, github, tarball, folder, symlink, workspace, root
//     .value: 具体值 (版本号, URL, 路径等)
// ============================================================================

/// 已解析包信息
public class ResolvedPackage {
    public let name: String
    public let version: String       // 解析后的确切版本
    public var tag: DependencyTag    // 来源类型
    /// 下载 URL 或本地路径
    /// 对应 Bun: Resolution.value.npm.url 或 dist.tarball
    public var resolved: String
    /// 完整性哈希 (SRI 格式: sha512-xxxx)
    /// 对应 Bun: Lockfile.Package.Meta.integrity
    public var integrity: String
    public var dependencies: ArrayList<Dependency>
    public var peerDependencies: ArrayList<Dependency>
    public var optionalDependencies: ArrayList<Dependency>
    public var isOptional: Bool
    public var isPeer: Bool
    public var isDev: Bool
    public var isWorkspace: Bool
    /// 解析深度
    public var depth: Int64
    /// 包路径 (相对于项目根目录)
    /// 对应 Bun: Lockfile.Tree 中的 relative_path
    public var packagePath: String
    /// bin 条目 (命令名 -> 可执行文件路径)
    public var bin: HashMap<String, String>
    /// 是否有安装脚本
    public var hasInstallScript: Bool
    /// OS 限制
    public var os: ArrayList<String>
    /// CPU 限制
    public var cpu: ArrayList<String>
    /// 是否已弃用
    public var deprecated: ?String
    /// registry URL (用于 lockfile 中记录非默认 registry)
    /// 对应 Bun: Resolution.value.npm.url
    public var registryUrl: String

    public init(name: String, version: String) {
        this.name = name
        this.version = version
        tag = DependencyTag.Npm
        resolved = ""
        integrity = ""
        dependencies = ArrayList<Dependency>()
        peerDependencies = ArrayList<Dependency>()
        optionalDependencies = ArrayList<Dependency>()
        isOptional = false
        isPeer = false
        isDev = false
        isWorkspace = false
        depth = 0
        packagePath = ""
        bin = HashMap<String, String>()
        hasInstallScript = false
        os = ArrayList<String>()
        cpu = ArrayList<String>()
        deprecated = None
        registryUrl = ""
    }

    /// 所有直接依赖
    public func allDependencies(): ArrayList<Dependency> {
        let all = ArrayList<Dependency>()
        for (d in dependencies) { all.append(d) }
        for (d in peerDependencies) { all.append(d) }
        for (d in optionalDependencies) { all.append(d) }
        return all
    }

    /// 唯一标识: name@version
    public func key(): String {
        return "${name}@${version}"
    }

    /// 是否与当前平台兼容
    /// 翻译自: Lockfile.Package.Meta 中 os/cpu 检查
    public func isPlatformCompatible(): Bool {
        // 无限制 = 兼容
        if (os.size == 0 && cpu.size == 0) { return true }

        // 检查 OS
        if (os.size > 0) {
            let currentOs = bao_sys.SysModule.getOsName()
            var osMatch = false
            for (o in os) {
                let osName = if (o.startsWith("!")) { o.substring(1) } else { o }
                if (osName == currentOs || osName == "*") {
                    osMatch = true
                    break
                }
            }
            if (!osMatch) { return false }
        }

        // 检查 CPU
        if (cpu.size > 0) {
            let currentArch = bao_sys.SysModule.getArchName()
            var cpuMatch = false
            for (c in cpu) {
                let cpuName = if (c.startsWith("!")) { c.substring(1) } else { c }
                if (cpuName == currentArch || cpuName == "*") {
                    cpuMatch = true
                    break
                }
            }
            if (!cpuMatch) { return false }
        }

        return true
    }
}

// ============================================================================
// 解析树
// 严格翻译自: src/install/lockfile.zig - Lockfile.Tree
//   Bun 的 lockfile 包含 packages 数组和 trees 数组
//   树表示 node_modules 的目录层级结构
//   翻译自: Lockfile.Tree 和 Lockfile.packages 的组合
// ============================================================================

/// 解析树 - 完整的依赖关系树
public class ResolutionTree {
    /// 根包名
    public var rootName: String
    /// 根包版本
    public var rootVersion: String
    /// 所有已解析包 (name@version -> ResolvedPackage)
    public var packages: HashMap<String, ResolvedPackage>
    /// 依赖关系: name@version -> 子依赖 key 列表
    public var edges: HashMap<String, ArrayList<String>>
    /// 冲突列表
    public var conflicts: ArrayList<ResolutionConflict>
    /// peer 依赖警告
    public var peerWarnings: ArrayList<PeerWarning>
    /// 解析过程中的错误 (optional deps 失败等)
    public var errors: ArrayList<ResolutionError>
    /// workspace 包列表
    public var workspacePackages: ArrayList<String>
    /// overrides
    public var overrides: HashMap<String, String>

    public init() {
        rootName = ""
        rootVersion = "0.0.0"
        packages = HashMap<String, ResolvedPackage>()
        edges = HashMap<String, ArrayList<String>>()
        conflicts = ArrayList<ResolutionConflict>()
        peerWarnings = ArrayList<PeerWarning>()
        errors = ArrayList<ResolutionError>()
        workspacePackages = ArrayList<String>()
        overrides = HashMap<String, String>()
    }

    /// 添加已解析包
    public func addPackage(pkg: ResolvedPackage): Unit {
        packages.put(pkg.key(), pkg)
        if (!edges.contains(pkg.key())) {
            edges.put(pkg.key(), ArrayList<String>())
        }
    }

    /// 添加依赖边
    public func addEdge(from: String, to: String): Unit {
        match (edges.get(from)) {
            case Some(list) => {
                // 避免重复边
                if (!list.contains(to)) {
                    list.append(to)
                }
            }
            case None => {
                let list = ArrayList<String>()
                list.append(to)
                edges.put(from, list)
            }
        }
    }

    /// 获取包的直接依赖
    public func getDependencies(pkgKey: String): ArrayList<ResolvedPackage> {
        let result = ArrayList<ResolvedPackage>()
        match (edges.get(pkgKey)) {
            case Some(deps) => {
                for (depKey in deps) {
                    match (packages.get(depKey)) {
                        case Some(pkg) => result.append(pkg)
                        case None => {}
                    }
                }
            }
            case None => {}
        }
        return result
    }

    /// 查找已解析的包 (按名称查找, 返回最新版本)
    public func findPackage(name: String): ?ResolvedPackage {
        var best: ?ResolvedPackage = None
        for (key in packages.keys()) {
            match (packages.get(key)) {
                case Some(pkg) => {
                    if (pkg.name == name) {
                        match (best) {
                            case Some(b) => {
                                let bestSv = SemVer.parse(b.version)
                                let pkgSv = SemVer.parse(pkg.version)
                                match (bestSv) {
                                    case Some(bsv) => match (pkgSv) {
                                        case Some(psv) => {
                                            if (psv.compare(bsv) > 0) {
                                                best = Some(pkg)
                                            }
                                        }
                                        case None => {}
                                    }
                                    case None => {}
                                }
                            }
                            case None => best = Some(pkg)
                        }
                    }
                }
                case None => {}
            }
        }
        return best
    }

    /// 检查是否有循环依赖
    public func hasCycles(): Bool {
        let visited = HashSet<String>()
        let inStack = HashSet<String>()
        for (key in packages.keys()) {
            match (key) {
                case Some(k) => {
                    if (detectCycle(k, visited, inStack)) {
                        return true
                    }
                }
                case None => {}
            }
        }
        return false
    }

    /// DFS 检测环
    private func detectCycle(node: String, visited: HashSet<String>, inStack: HashSet<String>): Bool {
        if (inStack.contains(node)) { return true }
        if (visited.contains(node)) { return false }
        visited.put(node)
        inStack.put(node)

        match (edges.get(node)) {
            case Some(deps) => {
                for (dep in deps) {
                    if (detectCycle(dep, visited, inStack)) {
                        return true
                    }
                }
            }
            case None => {}
        }

        inStack.remove(node)
        return false
    }

    /// 获取所有包的扁平列表 (拓扑排序)
    public func flatten(): ArrayList<ResolvedPackage> {
        let result = ArrayList<ResolvedPackage>()
        let visited = HashSet<String>()
        let rootPkgs = ArrayList<String>()

        // 找到所有根包 (没有被其他包依赖的)
        let allDepended = HashSet<String>()
        for (key in edges.keys()) {
            match (edges.get(key)) {
                case Some(deps) => {
                    for (dep in deps) {
                        allDepended.put(dep)
                    }
                }
                case None => {}
            }
        }
        for (key in packages.keys()) {
            match (key) {
                case Some(k) => {
                    if (!allDepended.contains(k)) {
                        rootPkgs.append(k)
                    }
                }
                case None => {}
            }
        }

        // DFS 拓扑排序
        for (root in rootPkgs) {
            flattenDfs(root, visited, result)
        }
        return result
    }

    private func flattenDfs(node: String, visited: HashSet<String>, result: ArrayList<ResolvedPackage>): Unit {
        if (visited.contains(node)) { return }
        visited.put(node)

        match (edges.get(node)) {
            case Some(deps) => {
                for (dep in deps) {
                    flattenDfs(dep, visited, result)
                }
            }
            case None => {}
        }

        match (packages.get(node)) {
            case Some(pkg) => result.append(pkg)
            case None => {}
        }
    }

    /// 统计
    public func stats(): String {
        return "ResolutionTree: ${packages.size} packages, ${edges.size} edges, ${conflicts.size} conflicts, ${peerWarnings.size} peer warnings"
    }
}

// ============================================================================
// 解析冲突
// 对应 Bun: 多个依赖请求同一包但版本不兼容的情况
// 翻译自: PackageManager 中版本冲突检测
// ============================================================================

/// 解析冲突
public class ResolutionConflict {
    public let packageName: String
    public let requestedBy: ArrayList<String>  // 依赖方列表
    public let versions: ArrayList<String>      // 请求的版本范围
    public var resolvedVersion: ?String         // 最终选择的版本 (None=未解决)

    public init(packageName: String) {
        this.packageName = packageName
        requestedBy = ArrayList<String>()
        versions = ArrayList<String>()
        resolvedVersion = None
    }

    /// 添加冲突方
    public func addRequester(requester: String, versionRange: String): Unit {
        requestedBy.append(requester)
        versions.append(versionRange)
    }

    /// 冲突描述
    public func toString(): String {
        return "Conflict: ${packageName} requested ${versions} by ${requestedBy}"
    }
}

// ============================================================================
// Peer 依赖警告
// 严格翻译自: Bun 中 peer dependency 满足性检查的警告
//   Bun 在安装时检查 peer dependencies 是否被正确解析
//   如果 peer dep 未满足, 生成警告而非错误
// ============================================================================

/// Peer 依赖警告
public class PeerWarning {
    public let packageName: String
    public let peerName: String
    public let peerVersion: String
    public let requiredBy: String
    public var resolvedVersion: ?String
    public var isMissing: Bool

    public init(packageName: String, peerName: String, peerVersion: String, requiredBy: String) {
        this.packageName = packageName
        this.peerName = peerName
        this.peerVersion = peerVersion
        this.requiredBy = requiredBy
        resolvedVersion = None
        isMissing = true
    }

    public func toString(): String {
        if (isMissing) {
            return "WARN: ${requiredBy} requires peer ${peerName}@${peerVersion} but it was not installed"
        }
        match (resolvedVersion) {
            case Some(v) => return "WARN: ${requiredBy} requires peer ${peerName}@${peerVersion} but got ${v}"
            case None => return "WARN: ${requiredBy} requires peer ${peerName}@${peerVersion} but got none"
        }
    }
}

// ============================================================================
// 解析错误
// ============================================================================

/// 解析错误
public class ResolutionError {
    public let packageName: String
    public let message: String
    public var isOptional: Bool

    public init(packageName: String, message: String, isOptional: Bool) {
        this.packageName = packageName
        this.message = message
        this.isOptional = isOptional
    }
}

// ============================================================================
// 依赖解析器
// 严格翻译自: src/install/PackageManager/PackageManagerResolution.zig
//   Bun 使用 Semver.Query 进行版本约束求解
//   resolve() 遍历所有依赖, 通过 registry 获取 metadata, 选择最佳版本
//
// 关键翻译来源:
//   - PackageManager.enqueueDependencyList: 队列化依赖列表
//   - PackageManager.resolveDependencies: 解析依赖
//   - PackageManager.processDependencyList: 处理依赖列表
//   - Semver.Query.resolve: 版本约束求解
// ============================================================================

/// 依赖解析器
/// 对应 Bun: PackageManager 中的 resolve 方法组
public class DependencyResolver {
    private var registry: RegistryClient
    /// 已解析包缓存 (name@version -> ResolvedPackage)
    private var resolved: HashMap<String, ResolvedPackage>
    /// 正在解析中的包 (防止循环)
    private var resolving: HashSet<String>
    /// 最大递归深度
    private var maxDepth: Int64
    /// 版本去重: name -> 已选择的版本
    /// 对应 Bun: PackageManager 中同一包只解析一个版本 (扁平化)
    private var resolvedVersions: HashMap<String, String>
    /// 所有已存在的 peer 依赖 (用于 peer 满足性检查)
    private var availablePeers: HashMap<String, String>
    /// workspace 包名集合 (用于解析 workspace: 协议)
    private var workspacePackages: HashMap<String, String>
    /// overrides
    private var overrides: HashMap<String, String>
    /// 是否为生产模式 (跳过 devDependencies)
    private var productionMode: Bool

    public init(registry: RegistryClient) {
        this.registry = registry
        resolved = HashMap<String, ResolvedPackage>()
        resolving = HashSet<String>()
        maxDepth = 128
        resolvedVersions = HashMap<String, String>()
        availablePeers = HashMap<String, String>()
        workspacePackages = HashMap<String, String>()
        overrides = HashMap<String, String>()
        productionMode = false
    }

    /// 设置生产模式
    public func setProductionMode(production: Bool): Unit {
        productionMode = production
    }

    /// 设置 workspace 包
    public func setWorkspacePackages(packages: HashMap<String, String>): Unit {
        workspacePackages = packages
    }

    /// 设置 overrides
    public func setOverrides(overrides: HashMap<String, String>): Unit {
        this.overrides = overrides
    }

    /// 解析依赖列表
    /// 对应 Bun: PackageManager.enqueueDependencyList + resolve
    /// 接收 package.json 中的依赖, 返回完整解析树
    public func resolve(deps: HashMap<String, String>): ResolutionTree {
        let tree = ResolutionTree()
        resolved.clear()
        resolving.clear()
        resolvedVersions.clear()
        availablePeers.clear()

        // 应用 overrides
        tree.overrides = overrides

        // 构建初始依赖列表
        let rootDeps = ArrayList<Dependency>()
        for (name in deps.keys()) {
            match (deps.get(name)) {
                case Some(ver) => {
                    // 检查 overrides
                    var effectiveVer = ver
                    match (overrides.get(name)) {
                        case Some(overrideVer) => effectiveVer = overrideVer
                        case None => {}
                    }
                    rootDeps.append(Dependency(name, effectiveVer))
                }
                case None => {}
            }
        }

        // 递归解析
        for (dep in rootDeps) {
            resolveDependency(dep, tree, 0)
        }

        // 检测冲突
        detectConflicts(tree)

        // 检查 peer 依赖满足性
        checkPeerDependencies(tree)

        return tree
    }

    /// 解析带标记的依赖列表 (dev/peer/optional)
    /// 对应 Bun: PackageManager 中处理不同类型依赖
    public func resolveWithBehaviors(
        dependencies: HashMap<String, String>,
        devDependencies: HashMap<String, String>,
        peerDependencies: HashMap<String, String>,
        optionalDependencies: HashMap<String, String>
    ): ResolutionTree {
        let tree = ResolutionTree()
        resolved.clear()
        resolving.clear()
        resolvedVersions.clear()
        availablePeers.clear()

        // 解析 dependencies
        for (name in dependencies.keys()) {
            match (dependencies.get(name)) {
                case Some(ver) => {
                    let dep = Dependency(name, applyOverride(name, ver))
                    resolveDependency(dep, tree, 0)
                }
                case None => {}
            }
        }

        // 解析 devDependencies (非生产模式)
        if (!productionMode) {
            for (name in devDependencies.keys()) {
                match (devDependencies.get(name)) {
                    case Some(ver) => {
                        let dep = Dependency(name, applyOverride(name, ver))
                        dep.behavior.isDev = true
                        resolveDependency(dep, tree, 0)
                    }
                    case None => {}
                }
            }
        }

        // 解析 peerDependencies
        for (name in peerDependencies.keys()) {
            match (peerDependencies.get(name)) {
                case Some(ver) => {
                    let dep = Dependency(name, applyOverride(name, ver))
                    dep.behavior.isPeer = true
                    resolveDependency(dep, tree, 0)
                }
                case None => {}
            }
        }

        // 解析 optionalDependencies
        for (name in optionalDependencies.keys()) {
            match (optionalDependencies.get(name)) {
                case Some(ver) => {
                    let dep = Dependency(name, applyOverride(name, ver))
                    dep.behavior.isOptional = true
                    resolveDependency(dep, tree, 0)
                }
                case None => {}
            }
        }

        detectConflicts(tree)
        checkPeerDependencies(tree)

        return tree
    }

    /// 解析单个依赖
    /// 对应 Bun: PackageManager.resolve 中的单包解析逻辑
    private func resolveDependency(dep: Dependency, tree: ResolutionTree, depth: Int64): ?ResolvedPackage {
        let depKey = "${dep.name}@${dep.resolvedVersion()}"

        // 检查是否已解析 (版本去重)
        // 对应 Bun: PackageManager 中同一包不同版本的处理
        match (resolved.get(depKey)) {
            case Some(existing) => return Some(existing)
            case None => {}
        }

        // 检查同包名是否已有解析版本 (扁平化去重)
        // 对应 Bun: hoisted install 中同名包只安装一个版本
        match (resolvedVersions.get(dep.name)) {
            case Some(existingVer) => {
                let existingKey = "${dep.name}@${existingVer}"
                match (resolved.get(existingKey)) {
                    case Some(existing) => {
                        // 检查现有版本是否满足新约束
                        let existingSv = SemVer.parse(existingVer)
                        match (existingSv) {
                            case Some(sv) => {
                                if (SemVer.satisfies(sv, dep.resolvedVersion())) {
                                    return Some(existing)
                                }
                            }
                            case None => {}
                        }
                    }
                    case None => {}
                }
            }
            case None => {}
        }

        // 检查循环
        if (resolving.contains(depKey)) {
            return None
        }

        // 检查深度
        if (depth >= maxDepth) {
            return None
        }

        resolving.put(depKey)

        // 根据类型解析
        let pkg = match (dep.tag) {
            case DependencyTag.Npm => resolveNpmDependency(dep, tree, depth)
            case DependencyTag.DistTag => resolveDistTagDependency(dep, tree, depth)
            case DependencyTag.Tarball => resolveTarballDependency(dep, tree, depth)
            case DependencyTag.Folder => resolveFolderDependency(dep, tree, depth)
            case DependencyTag.Symlink => resolveSymlinkDependency(dep, tree, depth)
            case DependencyTag.Workspace => resolveWorkspaceDependency(dep, tree, depth)
            case DependencyTag.Git => resolveGitDependency(dep, tree, depth)
            case DependencyTag.Github => resolveGithubDependency(dep, tree, depth)
            case DependencyTag.Catalog => resolveCatalogDependency(dep, tree, depth)
            case _ => None
        }

        resolving.remove(depKey)

        match (pkg) {
            case Some(p) => {
                resolved.put(depKey, p)
                resolvedVersions.put(dep.name, p.version)
                tree.addPackage(p)

                // 记录 peer 依赖
                for (pd in p.peerDependencies) {
                    availablePeers.put(pd.name, pd.version)
                }

                return Some(p)
            }
            case None => {
                // 记录解析失败
                let isOptionalDep = dep.behavior.isOptional
                tree.errors.append(ResolutionError(
                    packageName: dep.name,
                    message: "Failed to resolve ${dep.name}@${dep.version}",
                    isOptional: isOptionalDep
                ))
                return None
            }
        }
    }

    /// 解析 npm semver 依赖
    /// 对应 Bun: Semver.Query + version matching
    /// 翻译自: PackageManager 中 resolve npm 依赖的路径
    private func resolveNpmDependency(dep: Dependency, tree: ResolutionTree, depth: Int64): ?ResolvedPackage {
        let meta = registry.fetchPackageMetadata(dep.realName())
        match (meta) {
            case Some(m) => {
                let versionRange = dep.resolvedVersion()
                let best = m.findBestVersion(versionRange)
                match (best) {
                    case Some(vi) => {
                        let pkg = ResolvedPackage(dep.name, vi.version)
                        pkg.tag = DependencyTag.Npm
                        pkg.resolved = vi.distTarball
                        pkg.integrity = vi.distIntegrity
                        pkg.depth = depth
                        pkg.isDev = dep.behavior.isDev
                        pkg.isPeer = dep.behavior.isPeer
                        pkg.isOptional = dep.behavior.isOptional
                        pkg.hasInstallScript = vi.hasInstallScript
                        pkg.bin = vi.bin
                        pkg.os = vi.os
                        pkg.cpu = vi.cpu
                        pkg.deprecated = vi.deprecated
                        pkg.registryUrl = ""  // 使用默认 registry

                        // 递归解析子依赖
                        resolveSubDependencies(pkg, vi.dependencies, tree, depth + 1)
                        resolvePeerDependencies(pkg, vi.peerDependencies, vi.peerDependenciesMeta, tree, depth + 1)
                        resolveOptionalDependencies(pkg, vi.optionalDependencies, tree, depth + 1)

                        // 检查平台兼容性
                        if (!pkg.isPlatformCompatible()) {
                            // 标记为 optional, 安装时跳过
                            pkg.isOptional = true
                        }

                        return Some(pkg)
                    }
                    case None => return None
                }
            }
            case None => return None
        }
    }

    /// 解析 dist-tag 依赖 (如 "latest", "next")
    /// 对应 Bun: dist-tag 解析路径
    private func resolveDistTagDependency(dep: Dependency, tree: ResolutionTree, depth: Int64): ?ResolvedPackage {
        let meta = registry.fetchPackageMetadata(dep.realName())
        match (meta) {
            case Some(m) => {
                let tagName = if (dep.version.length == 0) { "latest" } else { dep.version }
                let version = m.getDistTag(tagName)
                match (version) {
                    case Some(v) => {
                        // 用解析出的精确版本重新构造 npm 依赖
                        let exactDep = Dependency(dep.name, v, DependencyTag.Npm)
                        return resolveNpmDependency(exactDep, tree, depth)
                    }
                    case None => {
                        // fallback: 尝试 latest
                        let latest = m.latestVersion()
                        match (latest) {
                            case Some(v) => {
                                let exactDep = Dependency(dep.name, v, DependencyTag.Npm)
                                return resolveNpmDependency(exactDep, tree, depth)
                            }
                            case None => return None
                        }
                    }
                }
            }
            case None => return None
        }
    }

    /// 解析 tarball 依赖
    /// 对应 Bun: tarball resolution path
    /// 翻译自: ResolutionType 中 .remote_tarball 和 .local_tarball
    private func resolveTarballDependency(dep: Dependency, tree: ResolutionTree, depth: Int64): ?ResolvedPackage {
        let url: String
        if (dep.version.startsWith("http://") || dep.version.startsWith("https://")) {
            url = dep.version
        } else if (dep.version.startsWith("file:")) {
            url = dep.version.substring(5)
        } else {
            url = bao_path.PathModule.resolve(ArrayList<String>([dep.version]))
        }

        let pkg = ResolvedPackage(dep.name, dep.version)
        pkg.tag = DependencyTag.Tarball
        pkg.resolved = url
        pkg.depth = depth
        return Some(pkg)
    }

    /// 解析本地文件夹依赖
    /// 对应 Bun: FolderResolution
    /// 翻译自: ResolutionType.folder
    private func resolveFolderDependency(dep: Dependency, tree: ResolutionTree, depth: Int64): ?ResolvedPackage {
        let path = if (dep.version.startsWith("file:")) {
            dep.version.substring(5)
        } else {
            dep.version
        }

        let absPath = bao_path.PathModule.resolve(ArrayList<String>([path]))
        let pkg = ResolvedPackage(dep.name, dep.version)
        pkg.tag = DependencyTag.Folder
        pkg.resolved = absPath
        pkg.depth = depth

        // 尝试读取文件夹中的 package.json 以获取子依赖
        let pkgJsonPath = bao_path.PathModule.join(ArrayList<String>([absPath, "package.json"]))
        let content = try {
            BaoFile.readAllText(pkgJsonPath)
        } catch (_: Exception) {
            return Some(pkg)
        }

        let parser = JsonParser()
        let json = parser.parse(content)
        match (json) {
            case Some(root) => {
                let subDeps = JsonHelper.getStringMap(root, "dependencies")
                resolveSubDependencies(pkg, subDeps, tree, depth + 1)
                let peerDeps = JsonHelper.getStringMap(root, "peerDependencies")
                resolvePeerDependencies(pkg, peerDeps, HashMap<String, HashMap<String, String>>(), tree, depth + 1)
            }
            case None => {}
        }

        return Some(pkg)
    }

    /// 解析 symlink 依赖
    /// 对应 Bun: link: resolution
    /// 翻译自: ResolutionType.symlink
    private func resolveSymlinkDependency(dep: Dependency, tree: ResolutionTree, depth: Int64): ?ResolvedPackage {
        let path = if (dep.version.startsWith("link:")) {
            dep.version.substring(5)
        } else {
            dep.version
        }

        let pkg = ResolvedPackage(dep.name, dep.version)
        pkg.tag = DependencyTag.Symlink
        pkg.resolved = bao_path.PathModule.resolve(ArrayList<String>([path]))
        pkg.depth = depth
        return Some(pkg)
    }

    /// 解析 workspace 依赖
    /// 对应 Bun: workspace: resolution (monorepo 内部引用)
    /// 翻译自: ResolutionType.workspace
    private func resolveWorkspaceDependency(dep: Dependency, tree: ResolutionTree, depth: Int64): ?ResolvedPackage {
        let path = if (dep.version.startsWith("workspace:")) {
            dep.version.substring(10)
        } else {
            dep.version
        }

        // workspace:* -> 使用 workspace 中对应包的版本
        var resolvedVersion = path
        if (path == "*" || path == "^" || path == "~") {
            // 从 workspacePackages 中查找版本
            match (workspacePackages.get(dep.name)) {
                case Some(ver) => resolvedVersion = ver
                case None => resolvedVersion = "*"
            }
        }

        let pkg = ResolvedPackage(dep.name, resolvedVersion)
        pkg.tag = DependencyTag.Workspace
        pkg.isWorkspace = true
        pkg.depth = depth

        // 查找 workspace 路径
        match (workspacePackages.get(dep.name)) {
            case Some(ver) => {
                // workspace 包的路径在安装时确定
                pkg.packagePath = dep.name
            }
            case None => {}
        }

        tree.workspacePackages.append(pkg.key())

        // 读取 workspace 包的依赖
        let wsPath = pkg.packagePath
        if (wsPath.length > 0) {
            let pkgJsonPath = bao_path.PathModule.join(ArrayList<String>([wsPath, "package.json"]))
            let content = try {
                BaoFile.readAllText(pkgJsonPath)
            } catch (_: Exception) {
                return Some(pkg)
            }

            let parser = JsonParser()
            let json = parser.parse(content)
            match (json) {
                case Some(root) => {
                    let subDeps = JsonHelper.getStringMap(root, "dependencies")
                    resolveSubDependencies(pkg, subDeps, tree, depth + 1)
                }
                case None => {}
            }
        }

        return Some(pkg)
    }

    /// 解析 git 依赖
    /// 对应 Bun: Repository.parse for git URLs
    /// 翻译自: ResolutionType.git
    private func resolveGitDependency(dep: Dependency, tree: ResolutionTree, depth: Int64): ?ResolvedPackage {
        let pkg = ResolvedPackage(dep.name, dep.version)
        pkg.tag = DependencyTag.Git
        pkg.resolved = dep.version
        pkg.depth = depth
        return Some(pkg)
    }

    /// 解析 github 依赖
    /// 对应 Bun: Repository.parseAppendGithub
    /// 翻译自: ResolutionType.github
    private func resolveGithubDependency(dep: Dependency, tree: ResolutionTree, depth: Int64): ?ResolvedPackage {
        let pkg = ResolvedPackage(dep.name, dep.version)
        pkg.tag = DependencyTag.Github
        pkg.resolved = dep.version
        pkg.depth = depth
        return Some(pkg)
    }

    /// 解析 catalog 依赖
    /// 对应 Bun: catalog: 协议 (pnpm workspaces 特性)
    /// 翻译自: Dependency.Version.Tag.catalog
    private func resolveCatalogDependency(dep: Dependency, tree: ResolutionTree, depth: Int64): ?ResolvedPackage {
        // catalog: 协议查找 workspace 根目录的 pnpm-workspace.yaml 中的 catalog 定义
        // 简化实现: 将 catalog: 视为 npm:
        let catalogName = dep.resolvedVersion()
        let npmDep = Dependency(dep.name, catalogName, DependencyTag.Npm)
        return resolveNpmDependency(npmDep, tree, depth)
    }

    /// 解析子依赖列表
    /// 对应 Bun: PackageManager.processDependencyList
    private func resolveSubDependencies(
        pkg: ResolvedPackage,
        deps: HashMap<String, String>,
        tree: ResolutionTree,
        depth: Int64
    ): Unit {
        for (name in deps.keys()) {
            match (deps.get(name)) {
                case Some(ver) => {
                    let effectiveVer = applyOverride(name, ver)
                    let dep = Dependency(name, effectiveVer)
                    dep.behavior.isDev = pkg.isDev
                    let child = resolveDependency(dep, tree, depth)
                    match (child) {
                        case Some(c) => {
                            tree.addEdge(pkg.key(), c.key())
                            pkg.dependencies.append(dep)
                        }
                        case None => {}
                    }
                }
                case None => {}
            }
        }
    }

    /// 解析 peer 依赖
    /// 对应 Bun: peer dependency handling in PackageManager
    /// 翻译自: PackageManager 中 peer dependency 解析
    ///   Bun 检查 peerDependenciesMeta 中的 "optional" 标记
    private func resolvePeerDependencies(
        pkg: ResolvedPackage,
        peers: HashMap<String, String>,
        peersMeta: HashMap<String, HashMap<String, String>>,
        tree: ResolutionTree,
        depth: Int64
    ): Unit {
        for (name in peers.keys()) {
            match (peers.get(name)) {
                case Some(ver) => {
                    let effectiveVer = applyOverride(name, ver)
                    let dep = Dependency(name, effectiveVer)
                    dep.behavior.isPeer = true

                    // 检查 peerDependenciesMeta 中的 optional 标记
                    match (peersMeta.get(name)) {
                        case Some(meta) => {
                            match (meta.get("optional")) {
                                case Some("true") => dep.behavior.isOptional = true
                                case _ => {}
                            }
                        }
                        case None => {}
                    }

                    let child = resolveDependency(dep, tree, depth)
                    match (child) {
                        case Some(c) => {
                            tree.addEdge(pkg.key(), c.key())
                            pkg.peerDependencies.append(dep)
                        }
                        case None => {
                            // peer dep 未解析 -> 记录警告
                            let isOptionalPeer = dep.behavior.isOptional
                            if (!isOptionalPeer) {
                                tree.peerWarnings.append(PeerWarning(
                                    packageName: name,
                                    peerName: name,
                                    peerVersion: ver,
                                    requiredBy: pkg.key()
                                ))
                            }
                        }
                    }
                }
                case None => {}
            }
        }
    }

    /// 解析 optional 依赖
    /// 对应 Bun: optional dependency handling (失败不中断安装)
    /// 翻译自: PackageManager 中 optional dependency 处理
    private func resolveOptionalDependencies(
        pkg: ResolvedPackage,
        optionals: HashMap<String, String>,
        tree: ResolutionTree,
        depth: Int64
    ): Unit {
        for (name in optionals.keys()) {
            match (optionals.get(name)) {
                case Some(ver) => {
                    let effectiveVer = applyOverride(name, ver)
                    let dep = Dependency(name, effectiveVer)
                    dep.behavior.isOptional = true
                    // optional 依赖解析失败不报错
                    let child = resolveDependency(dep, tree, depth)
                    match (child) {
                        case Some(c) => {
                            tree.addEdge(pkg.key(), c.key())
                            pkg.optionalDependencies.append(dep)
                        }
                        case None => {}  // 静默忽略
                    }
                }
                case None => {}
            }
        }
    }

    /// 检测版本冲突
    /// 对应 Bun: 检查同一包的不同版本请求是否兼容
    private func detectConflicts(tree: ResolutionTree): Unit {
        // 收集每个包名被请求的所有版本
        let requests = HashMap<String, ArrayList<String>>()
        for (key in resolved.keys()) {
            match (key) {
                case Some(k) => {
                    match (resolved.get(k)) {
                        case Some(pkg) => {
                            match (requests.get(pkg.name)) {
                                case Some(list) => list.append(pkg.version)
                                case None => {
                                    let list = ArrayList<String>()
                                    list.append(pkg.version)
                                    requests.put(pkg.name, list)
                                }
                            }
                        }
                        case None => {}
                    }
                }
                case None => {}
            }
        }

        // 检查冲突: 同名但版本不同
        for (name in requests.keys()) {
            match (requests.get(name)) {
                case Some(versions) => {
                    let uniqueVersions = HashSet<String>()
                    for (v in versions) {
                        uniqueVersions.put(v)
                    }
                    if (uniqueVersions.size > 1) {
                        let conflict = ResolutionConflict(name)
                        for (v in versions) {
                            conflict.addRequester(name, v)
                        }
                        // 选择最新版本作为解决方案
                        var bestVer = ""
                        for (v in uniqueVersions) {
                            match (v) {
                                case Some(ver) => {
                                    if (bestVer.length == 0) {
                                        bestVer = ver
                                    } else {
                                        let svA = SemVer.parse(ver)
                                        let svB = SemVer.parse(bestVer)
                                        match (svA) {
                                            case Some(a) => match (svB) {
                                                case Some(b) => {
                                                    if (a.compare(b) > 0) {
                                                        bestVer = ver
                                                    }
                                                }
                                                case None => bestVer = ver
                                            }
                                            case None => {}
                                        }
                                    }
                                }
                                case None => {}
                            }
                        }
                        conflict.resolvedVersion = Some(bestVer)
                        tree.conflicts.append(conflict)
                    }
                }
                case None => {}
            }
        }
    }

    /// 检查 peer 依赖满足性
    /// 翻译自: PackageManager 中 peer dependency 验证
    ///   Bun 在安装完成后检查 peer 是否被正确满足
    private func checkPeerDependencies(tree: ResolutionTree): Unit {
        for (key in tree.packages.keys()) {
            match (tree.packages.get(key)) {
                case Some(pkg) => {
                    for (pd in pkg.peerDependencies) {
                        // 检查 peer 是否在已解析包中
                        let peerKey = "${pd.name}@${pd.resolvedVersion()}"
                        var found = false

                        // 检查直接匹配
                        match (tree.packages.get(peerKey)) {
                            case Some(_) => found = true
                            case None => {}
                        }

                        // 检查按名称匹配
                        if (!found) {
                            let peerPkg = tree.findPackage(pd.name)
                            match (peerPkg) {
                                case Some(pp) => {
                                    let peerSv = SemVer.parse(pp.version)
                                    match (peerSv) {
                                        case Some(sv) => {
                                            if (SemVer.satisfies(sv, pd.resolvedVersion())) {
                                                found = true
                                            }
                                        }
                                        case None => {}
                                    }
                                }
                                case None => {}
                            }
                        }

                        if (!found && !pd.behavior.isOptional) {
                            // 检查是否已有相同警告
                            var alreadyWarned = false
                            for (w in tree.peerWarnings) {
                                if (w.peerName == pd.name && w.requiredBy == pkg.key()) {
                                    alreadyWarned = true
                                    break
                                }
                            }
                            if (!alreadyWarned) {
                                tree.peerWarnings.append(PeerWarning(
                                    packageName: pkg.name,
                                    peerName: pd.name,
                                    peerVersion: pd.version,
                                    requiredBy: pkg.key()
                                ))
                            }
                        }
                    }
                }
                case None => {}
            }
        }
    }

    /// 应用 override
    /// 翻译自: Lockfile.overrides / package.json overrides
    private func applyOverride(name: String, version: String): String {
        match (overrides.get(name)) {
            case Some(overrideVer) => return overrideVer
            case None => return version
        }
    }
}
