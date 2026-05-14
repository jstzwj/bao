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
//   }
// ============================================================================

/// 依赖行为标志
/// 对应 Bun: Dependency.Behavior (bitfield)
public class DependencyBehavior {
    public var isPeer: Bool
    public var isDev: Bool
    public var isOptional: Bool
    public var isWorkspace: Bool

    public init() {
        isPeer = false
        isDev = false
        isOptional = false
        isWorkspace = false
    }

    /// 比较排序优先级
    /// 对应 Bun: Behavior.cmp
    /// 排序: peer > optional > dev > normal
    public func compare(other: DependencyBehavior): Int64 {
        let thisVal = (if (isPeer) { 4 } else { 0 }) +
                      (if (isOptional) { 2 } else { 0 }) +
                      (if (isDev) { 1 } else { 0 })
        let otherVal = (if (other.isPeer) { 4 } else { 0 }) +
                       (if (other.isOptional) { 2 } else { 0 }) +
                       (if (other.isDev) { 1 } else { 0 })
        if (thisVal < otherVal) { return -1 }
        if (thisVal > otherVal) { return 1 }
        return 0
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
    | Catalog

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
            if (isTarball(version)) { return DependencyTag.Tarball }
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

        // 默认为 dist-tag (如 "latest", "next")
        return DependencyTag.DistTag
    }

    /// 判断是否是 tarball 路径
    /// 对应 Bun: Dependency.isTarball
    private static func isTarball(s: String): Bool {
        return s.endsWith(".tgz") || s.endsWith(".tar.gz")
    }

    /// 获取真实包名 (用于 alias)
    /// 对应 Bun: Dependency.realname
    public func realName(): String {
        if (version.startsWith("npm:")) {
            // npm:package@version
            let rest = version.substring(4)
            let atIndex = rest.indexOf("@", Int64(1))  // skip @scope
            if (atIndex >= 0) {
                return rest.substring(0, atIndex)
            }
            return rest
        }
        return name
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
        return version
    }
}

// ============================================================================
// 已解析包
// 严格翻译自: src/install/resolution.zig - Resolution
//   pub const Resolution = ResolutionType(u64)
//   包含 tag + value (npm version, tarball URL, folder path, etc.)
// ============================================================================

/// 已解析包信息
public class ResolvedPackage {
    public let name: String
    public let version: String       // 解析后的确切版本
    public var tag: DependencyTag    // 来源类型
    public var resolved: String      // 下载 URL 或本地路径
    public var integrity: String     // SHA integrity
    public var dependencies: ArrayList<Dependency>
    public var peerDependencies: ArrayList<Dependency>
    public var optionalDependencies: ArrayList<Dependency>
    public var isOptional: Bool
    public var isPeer: Bool
    public var isDev: Bool
    public var isWorkspace: Bool
    public var depth: Int64

    public init(name: String, version: String) {
        this.name = name
        this.version = version
        this.tag = DependencyTag.Npm
        this.resolved = ""
        this.integrity = ""
        this.dependencies = ArrayList<Dependency>()
        this.peerDependencies = ArrayList<Dependency>()
        this.optionalDependencies = ArrayList<Dependency>()
        this.isOptional = false
        this.isPeer = false
        this.isDev = false
        this.isWorkspace = false
        this.depth = 0
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
}

// ============================================================================
// 解析树
// 严格翻译自: src/install/lockfile.zig - Lockfile.Tree
//   Bun 的 lockfile 包含 packages 数组和 trees 数组
//   树表示 node_modules 的目录层级结构
// ============================================================================

/// 解析树 - 完整的依赖关系树
public class ResolutionTree {
    /// 根包名
    public var rootName: String
    /// 所有已解析包 (name@version -> ResolvedPackage)
    public var packages: HashMap<String, ResolvedPackage>
    /// 依赖关系: name@version -> 子依赖列表
    public var edges: HashMap<String, ArrayList<String>>
    /// 冲突列表
    public var conflicts: ArrayList<ResolutionConflict>

    public init() {
        rootName = ""
        packages = HashMap<String, ResolvedPackage>()
        edges = HashMap<String, ArrayList<String>>()
        conflicts = ArrayList<ResolutionConflict>()
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
            case Some(list) => list.append(to)
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

    /// 统计
    public func stats(): String {
        return "ResolutionTree: ${packages.size} packages, ${edges.size} edges, ${conflicts.size} conflicts"
    }
}

// ============================================================================
// 解析冲突
// 对应 Bun: 多个依赖请求同一包但版本不兼容的情况
// ============================================================================

/// 解析冲突
public class ResolutionConflict {
    public let packageName: String
    public let requestedBy: ArrayList<String>  // 依赖方列表
    public let versions: ArrayList<String>      // 请求的版本范围
    public let resolvedVersion: ?String         // 最终选择的版本 (None=未解决)

    public init(packageName: String) {
        this.packageName = packageName
        this.requestedBy = ArrayList<String>()
        this.versions = ArrayList<String>()
        this.resolvedVersion = None
    }

    /// 添加冲突方
    public func addRequester(requester: String, versionRange: String): Unit {
        requestedBy.append(requester)
        versions.append(versionRange)
    }
}

// ============================================================================
// 依赖解析器
// 严格翻译自: src/install/PackageManager/PackageManagerResolution.zig
//   Bun 使用 Semver.Query 进行版本约束求解
//   resolve() 遍历所有依赖, 通过 registry 获取 metadata, 选择最佳版本
// ============================================================================

/// 依赖解析器
/// 对应 Bun: PackageManager 中的 resolve 方法组
public class DependencyResolver {
    private var registry: RegistryClient
    private var resolved: HashMap<String, ResolvedPackage>
    private var resolving: HashSet<String>
    private var maxDepth: Int64

    public init(registry: RegistryClient) {
        this.registry = registry
        this.resolved = HashMap<String, ResolvedPackage>()
        this.resolving = HashSet<String>()
        this.maxDepth = 128  // 防止无限递归
    }

    /// 解析依赖列表
    /// 对应 Bun: PackageManager.enqueueDependencyList + resolve
    /// 接收 package.json 中的依赖, 返回完整解析树
    public func resolve(deps: HashMap<String, String>): ResolutionTree {
        let tree = ResolutionTree()
        resolved.clear()
        resolving.clear()

        // 构建初始依赖列表
        let rootDeps = ArrayList<Dependency>()
        for (name in deps.keys()) {
            match (deps.get(name)) {
                case Some(ver) => rootDeps.append(Dependency(name, ver))
                case None => {}
            }
        }

        // 递归解析
        for (dep in rootDeps) {
            resolveDependency(dep, tree, 0)
        }

        // 检测冲突
        detectConflicts(tree)

        return tree
    }

    /// 解析单个依赖
    /// 对应 Bun: PackageManager.resolve 中的单包解析逻辑
    private func resolveDependency(dep: Dependency, tree: ResolutionTree, depth: Int64): ?ResolvedPackage {
        let depKey = "${dep.name}@${dep.resolvedVersion()}"

        // 检查是否已解析
        match (resolved.get(depKey)) {
            case Some(existing) => return Some(existing)
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
            case _ => None
        }

        resolving.remove(depKey)

        match (pkg) {
            case Some(p) => {
                resolved.put(depKey, p)
                tree.addPackage(p)
                return Some(p)
            }
            case None => return None
        }
    }

    /// 解析 npm semver 依赖
    /// 对应 Bun: Semver.Query + version matching
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

                        // 递归解析子依赖
                        resolveSubDependencies(pkg, vi.dependencies, tree, depth + 1)
                        resolvePeerDependencies(pkg, vi.peerDependencies, tree, depth + 1)
                        resolveOptionalDependencies(pkg, vi.optionalDependencies, tree, depth + 1)

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
    private func resolveTarballDependency(dep: Dependency, tree: ResolutionTree, depth: Int64): ?ResolvedPackage {
        let url = if (dep.version.startsWith("http://") ||
                      dep.version.startsWith("https://")) {
            dep.version
        } else {
            // 本地 tarball
            bao_path.PathModule.resolve(ArrayList<String>([dep.version]))
        }

        let pkg = ResolvedPackage(dep.name, dep.version)
        pkg.tag = DependencyTag.Tarball
        pkg.resolved = url
        pkg.depth = depth
        return Some(pkg)
    }

    /// 解析本地文件夹依赖
    /// 对应 Bun: FolderResolution
    private func resolveFolderDependency(dep: Dependency, tree: ResolutionTree, depth: Int64): ?ResolvedPackage {
        let path = if (dep.version.startsWith("file:")) {
            dep.version.substring(5)
        } else {
            dep.version
        }

        let pkg = ResolvedPackage(dep.name, dep.version)
        pkg.tag = DependencyTag.Folder
        pkg.resolved = bao_path.PathModule.resolve(ArrayList<String>([path]))
        pkg.depth = depth
        return Some(pkg)
    }

    /// 解析 symlink 依赖
    /// 对应 Bun: link: resolution
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
    private func resolveWorkspaceDependency(dep: Dependency, tree: ResolutionTree, depth: Int64): ?ResolvedPackage {
        let path = if (dep.version.startsWith("workspace:")) {
            dep.version.substring(10)
        } else {
            dep.version
        }

        let pkg = ResolvedPackage(dep.name, path)
        pkg.tag = DependencyTag.Workspace
        pkg.isWorkspace = true
        pkg.depth = depth
        return Some(pkg)
    }

    /// 解析 git 依赖
    /// 对应 Bun: Repository.parse for git URLs
    private func resolveGitDependency(dep: Dependency, tree: ResolutionTree, depth: Int64): ?ResolvedPackage {
        let pkg = ResolvedPackage(dep.name, dep.version)
        pkg.tag = DependencyTag.Git
        pkg.resolved = dep.version
        pkg.depth = depth
        return Some(pkg)
    }

    /// 解析 github 依赖
    /// 对应 Bun: Repository.parseAppendGithub
    private func resolveGithubDependency(dep: Dependency, tree: ResolutionTree, depth: Int64): ?ResolvedPackage {
        let pkg = ResolvedPackage(dep.name, dep.version)
        pkg.tag = DependencyTag.Github
        pkg.resolved = dep.version
        pkg.depth = depth
        return Some(pkg)
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
                    let dep = Dependency(name, ver)
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
    private func resolvePeerDependencies(
        pkg: ResolvedPackage,
        peers: HashMap<String, String>,
        tree: ResolutionTree,
        depth: Int64
    ): Unit {
        for (name in peers.keys()) {
            match (peers.get(name)) {
                case Some(ver) => {
                    let dep = Dependency(name, ver)
                    dep.behavior.isPeer = true
                    let child = resolveDependency(dep, tree, depth)
                    match (child) {
                        case Some(c) => {
                            tree.addEdge(pkg.key(), c.key())
                            pkg.peerDependencies.append(dep)
                        }
                        case None => {}
                    }
                }
                case None => {}
            }
        }
    }

    /// 解析 optional 依赖
    /// 对应 Bun: optional dependency handling (失败不中断安装)
    private func resolveOptionalDependencies(
        pkg: ResolvedPackage,
        optionals: HashMap<String, String>,
        tree: ResolutionTree,
        depth: Int64
    ): Unit {
        for (name in optionals.keys()) {
            match (optionals.get(name)) {
                case Some(ver) => {
                    let dep = Dependency(name, ver)
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
                            // 从 edges 收集所有请求此包的节点
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
                    if (versions.size > 1) {
                        // 检查是否有不兼容的版本
                        let uniqueVersions = HashSet<String>()
                        for (v in versions) {
                            uniqueVersions.put(v)
                        }
                        if (uniqueVersions.size > 1) {
                            let conflict = ResolutionConflict(name)
                            for (v in versions) {
                                conflict.addRequester(name, v)
                            }
                            tree.conflicts.append(conflict)
                        }
                    }
                }
                case None => {}
            }
        }
    }
}
