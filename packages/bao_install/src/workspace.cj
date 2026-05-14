// bao_install - Workspace 管理
// 严格翻译自: src/install/PackageManager/WorkspacePackageJSONCache.zig
//              src/install/hoisted_install.zig
package bao_install

import bao_core.*
import bao_collections.*
import bao_io.*
import bao_hash.*
import bao_path.*
import bao_http.*

// ============================================================================
// 工作区包信息
// 严格翻译自: src/install/PackageManager/WorkspacePackageJSONCache.zig
//   Bun 为每个 workspace 解析 package.json 并缓存结果
// ============================================================================

/// 工作区包信息
/// 对应 Bun: WorkspacePackageJSONCache 中的条目
public class WorkspacePackage {
    /// 包名
    public let name: String
    /// 版本
    public let version: SemVer
    /// 工作区相对路径 (相对于 monorepo 根目录)
    public let relativePath: String
    /// 绝对路径
    public var absolutePath: String
    /// 依赖
    public var dependencies: HashMap<String, String>
    /// 开发依赖
    public var devDependencies: HashMap<String, String>
    /// peer 依赖
    public var peerDependencies: HashMap<String, String>
    /// 可选依赖
    public var optionalDependencies: HashMap<String, String>
    /// 是否是根工作区
    public var isRoot: Bool
    /// 包的主入口
    public var main: String
    /// scripts
    public var scripts: HashMap<String, String>

    public init(name: String, version: SemVer, relativePath: String) {
        this.name = name
        this.version = version
        this.relativePath = relativePath
        this.absolutePath = ""
        this.dependencies = HashMap<String, String>()
        this.devDependencies = HashMap<String, String>()
        this.peerDependencies = HashMap<String, String>()
        this.optionalDependencies = HashMap<String, String>()
        this.isRoot = false
        this.main = "index.js"
        this.scripts = HashMap<String, String>()
    }

    /// 所有依赖 (合并 dependencies + devDependencies)
    public func allDependencies(): HashMap<String, String> {
        let all = HashMap<String, String>()
        for (key in dependencies.keys()) {
            match (dependencies.get(key)) {
                case Some(v) => all.put(key, v)
                case None => {}
            }
        }
        for (key in devDependencies.keys()) {
            match (devDependencies.get(key)) {
                case Some(v) => all.put(key, v)
                case None => {}
            }
        }
        return all
    }

    /// 唯一键
    public func key(): String {
        return "${name}@${version.toString()}"
    }
}

// ============================================================================
// 工作区 glob 解析
// 严格翻译自: package.json 中 workspaces 字段的解析
//   Bun 支持 workspaces: ["packages/*"] glob 模式
// ============================================================================

/// 工作区 glob 解析器
public class WorkspaceGlob {
    /// 解析 workspaces 字段
    /// 支持: ["packages/*"], ["app", "libs/*"], "packages/*"
    public static func parseGlobs(workspacesField: ?JsonValue): ArrayList<String> {
        let globs = ArrayList<String>()
        match (workspacesField) {
            case Some(JsonValue.Array(arr)) => {
                for (item in arr) {
                    match (item) {
                        case JsonValue.Str(s) => globs.append(s)
                        case _ => {}
                    }
                }
            }
            case Some(JsonValue.Str(s)) => {
                globs.append(s)
            }
            case _ => {}
        }
        return globs
    }

    /// 展开 glob 模式为具体路径
    /// 对应 Bun: 使用 glob 匹配 packages/* 等
    public static func expandGlobs(globs: ArrayList<String>, rootDir: String): ArrayList<String> {
        let paths = ArrayList<String>()
        let seen = HashSet<String>()

        for (glob in globs) {
            let expanded = expandSingleGlob(glob, rootDir)
            for (p in expanded) {
                if (!seen.contains(p)) {
                    seen.put(p)
                    paths.append(p)
                }
            }
        }

        return paths
    }

    /// 展开单个 glob 模式
    /// 处理通配符: packages/* -> packages/a, packages/b, ...
    private static func expandSingleGlob(glob: String, rootDir: String): ArrayList<String> {
        let result = ArrayList<String>()

        // 简单 glob: 仅处理末尾的 *
        if (glob.endsWith("/*")) {
            let dir = glob.substring(0, glob.length - 2)
            let fullDir = bao_path.PathModule.join(ArrayList<String>([rootDir, dir]))

            // 列出目录下的子目录
            let entries = BaoFile.readDir(fullDir)
            match (entries) {
                case Some(dirEntries) => {
                    for (entry in dirEntries) {
                        let entryPath = bao_path.PathModule.join(ArrayList<String>([dir, entry]))
                        // 检查是否有 package.json
                        let pkgJson = bao_path.PathModule.join(ArrayList<String>([
                            rootDir, entryPath, "package.json"
                        ]))
                        if (BaoFile.exists(pkgJson)) {
                            result.append(entryPath)
                        }
                    }
                }
                case None => {}
            }
        } else if (glob.endsWith("/**")) {
            // 递归 glob: packages/**
            let dir = glob.substring(0, glob.length - 3)
            expandRecursive(rootDir, dir, result)
        } else {
            // 精确路径
            let pkgJson = bao_path.PathModule.join(ArrayList<String>([rootDir, glob, "package.json"]))
            if (BaoFile.exists(pkgJson)) {
                result.append(glob)
            }
        }

        return result
    }

    /// 递归展开目录
    private static func expandRecursive(rootDir: String, subDir: String, result: ArrayList<String>): Unit {
        let fullDir = bao_path.PathModule.join(ArrayList<String>([rootDir, subDir]))
        let entries = BaoFile.readDir(fullDir)
        match (entries) {
            case Some(dirEntries) => {
                for (entry in dirEntries) {
                    let entryPath = bao_path.PathModule.join(ArrayList<String>([subDir, entry]))
                    let pkgJson = bao_path.PathModule.join(ArrayList<String>([
                        rootDir, entryPath, "package.json"
                    ]))
                    if (BaoFile.exists(pkgJson)) {
                        result.append(entryPath)
                    }
                    // 递归子目录
                    let subEntries = BaoFile.readDir(
                        bao_path.PathModule.join(ArrayList<String>([rootDir, entryPath]))
                    )
                    match (subEntries) {
                        case Some(se) => expandRecursive(rootDir, entryPath, result)
                        case None => {}
                    }
                }
            }
            case None => {}
        }
    }
}

// ============================================================================
// 包图 - 工作区依赖图
// 严格翻译自: src/install/hoisted_install.zig 中的依赖图构建
//   Bun 构建工作区依赖图来确定安装顺序和提升策略
// ============================================================================

/// 包图 - 工作区间的依赖关系图
public class PackageGraph {
    /// 工作区包 name -> WorkspacePackage
    private var packages: HashMap<String, WorkspacePackage>
    /// 依赖边: name -> [依赖的包名列表]
    private var edges: HashMap<String, ArrayList<String>>
    /// 拓扑排序缓存
    private var topoOrder: ?ArrayList<String>
    /// 根包名
    private var rootPackage: ?String

    public init() {
        packages = HashMap<String, WorkspacePackage>()
        edges = HashMap<String, ArrayList<String>>()
        topoOrder = None
        rootPackage = None
    }

    /// 添加工作区包
    public func addPackage(pkg: WorkspacePackage): Unit {
        packages.put(pkg.name, pkg)
        if (!edges.contains(pkg.name)) {
            edges.put(pkg.name, ArrayList<String>())
        }
        if (pkg.isRoot) {
            rootPackage = Some(pkg.name)
        }
        topoOrder = None  // 使缓存失效
    }

    /// 添加依赖边
    public func addDependency(from: String, to: String): Unit {
        match (edges.get(from)) {
            case Some(list) => {
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
        topoOrder = None
    }

    /// 获取包
    public func getPackage(name: String): ?WorkspacePackage {
        return packages.get(name)
    }

    /// 获取所有包名
    public func packageNames(): ArrayList<String> {
        let names = ArrayList<String>()
        for (key in packages.keys()) {
            match (key) {
                case Some(k) => names.append(k)
                case None => {}
            }
        }
        return names
    }

    /// 工作区数量
    public prop size: Int64 {
        get() { packages.size }
    }

    /// 拓扑排序 - 返回按依赖顺序排列的包名
    /// 对应 Bun: 确定安装顺序的依赖图遍历
    public func topologicalSort(): ArrayList<String> {
        match (topoOrder) {
            case Some(order) => return order
            case None => {}
        }

        let result = ArrayList<String>()
        let visited = HashSet<String>()
        let inStack = HashSet<String>()

        // 从根包开始
        match (rootPackage) {
            case Some(root) => topoVisit(root, visited, inStack, result)
            case None => {}
        }

        // 处理未连接到根的包
        for (key in packages.keys()) {
            match (key) {
                case Some(k) => topoVisit(k, visited, inStack, result)
                case None => {}
            }
        }

        // 反转得到依赖优先的顺序
        let reversed = ArrayList<String>()
        for (i in 0..result.size) {
            reversed.append(result[result.size - 1 - i])
        }

        topoOrder = Some(reversed)
        return reversed
    }

    /// DFS 拓扑遍历
    private func topoVisit(
        node: String,
        visited: HashSet<String>,
        inStack: HashSet<String>,
        result: ArrayList<String>
    ): Unit {
        if (visited.contains(node)) { return }
        if (inStack.contains(node)) { return }  // 循环依赖, 跳过

        inStack.put(node)

        match (edges.get(node)) {
            case Some(deps) => {
                for (dep in deps) {
                    topoVisit(dep, visited, inStack, result)
                }
            }
            case None => {}
        }

        inStack.remove(node)
        visited.put(node)
        result.append(node)
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

    /// 获取依赖于指定包的包列表 (反向依赖)
    public func getDependents(packageName: String): ArrayList<String> {
        let result = ArrayList<String>()
        for (key in edges.keys()) {
            match (edges.get(key)) {
                case Some(deps) => {
                    if (deps.contains(packageName)) {
                        result.append(key)
                    }
                }
                case None => {}
            }
        }
        return result
    }
}

// ============================================================================
// 工作区解析器
// 严格翻译自: src/install/PackageManager/WorkspacePackageJSONCache.zig
//   Bun 在安装开始时扫描所有 workspace 的 package.json
//   解析 workspaces 字段, 构建依赖图
// ============================================================================

/// 工作区解析器 - monorepo 工作区检测和管理
/// 对应 Bun: WorkspacePackageJSONCache
public class WorkspaceResolver {
    private var rootDir: String
    private var jsonParser: JsonParser
    private var graph: PackageGraph
    /// 根包的 package.json
    private var rootPackage: ?WorkspacePackage

    public init(rootDir: String) {
        this.rootDir = rootDir
        this.jsonParser = JsonParser()
        this.graph = PackageGraph()
        this.rootPackage = None
    }

    /// 解析工作区配置并构建依赖图
    /// 对应 Bun: WorkspacePackageJSONCache.load
    public func resolveWorkspacePackages(): PackageGraph {
        graph = PackageGraph()

        // 1. 读取根 package.json
        let rootPkgJsonPath = bao_path.PathModule.join(ArrayList<String>([rootDir, "package.json"]))
        let rootContent = try {
            BaoFile.readAllText(rootPkgJsonPath)
        } catch (_: Exception) {
            return graph
        }

        let rootJson = jsonParser.parse(rootContent)
        match (rootJson) {
            case Some(root) => {
                let rootPkg = parsePackageJson(root, ".", true)
                match (rootPkg) {
                    case Some(pkg) => {
                        rootPackage = Some(pkg)
                        graph.addPackage(pkg)
                    }
                    case None => {}
                }

                // 2. 获取 workspaces 配置
                let workspacesField = JsonHelper.getField(root, "workspaces")
                let globs = WorkspaceGlob.parseGlobs(workspacesField)

                // 3. 展开 glob 模式
                let workspacePaths = WorkspaceGlob.expandGlobs(globs, rootDir)

                // 4. 解析每个 workspace 的 package.json
                for (wsPath in workspacePaths) {
                    let pkgJsonPath = bao_path.PathModule.join(ArrayList<String>([
                        rootDir, wsPath, "package.json"
                    ]))
                    let content = try {
                        BaoFile.readAllText(pkgJsonPath)
                    } catch (_: Exception) {
                        continue
                    }

                    let wsJson = jsonParser.parse(content)
                    match (wsJson) {
                        case Some(j) => {
                            let wsPkg = parsePackageJson(j, wsPath, false)
                            match (wsPkg) {
                                case Some(pkg) => {
                                    graph.addPackage(pkg)
                                }
                                case None => {}
                            }
                        }
                        case None => {}
                    }
                }

                // 5. 构建依赖图边
                buildDependencyEdges()
            }
            case None => {}
        }

        return graph
    }

    /// 解析单个 package.json
    private func parsePackageJson(json: JsonValue, relativePath: String, isRoot: Bool): ?WorkspacePackage {
        let name = match (JsonHelper.getString(json, "name")) {
            case Some(n) => n
            case None => if (isRoot) { "root" } else { return None }
        }

        let versionStr = match (JsonHelper.getString(json, "version")) {
            case Some(v) => v
            case None => "0.0.0"
        }

        let version = match (SemVer.parse(versionStr)) {
            case Some(v) => v
            case None => SemVer(0, 0, 0)
        }

        let pkg = WorkspacePackage(name, version, relativePath)
        pkg.isRoot = isRoot
        pkg.absolutePath = bao_path.PathModule.join(ArrayList<String>([rootDir, relativePath]))
        pkg.main = match (JsonHelper.getString(json, "main")) {
            case Some(m) => m
            case None => "index.js"
        }

        // 依赖
        pkg.dependencies = JsonHelper.getStringMap(json, "dependencies")
        pkg.devDependencies = JsonHelper.getStringMap(json, "devDependencies")
        pkg.peerDependencies = JsonHelper.getStringMap(json, "peerDependencies")
        pkg.optionalDependencies = JsonHelper.getStringMap(json, "optionalDependencies")

        // scripts
        match (JsonHelper.getField(json, "scripts")) {
            case Some(JsonValue.Object(scripts)) => {
                for (k in scripts.keys()) {
                    match (scripts.get(k)) {
                        case Some(JsonValue.Str(v)) => pkg.scripts.put(k, v)
                        case _ => {}
                    }
                }
            }
            case _ => {}
        }

        return Some(pkg)
    }

    /// 构建依赖图边
    /// 对应 Bun: 构建工作区间依赖关系
    private func buildDependencyEdges(): Unit {
        let allPackages = graph.packageNames()
        let pkgNames = HashSet<String>()
        for (name in allPackages) {
            pkgNames.put(name)
        }

        for (pkgName in allPackages) {
            match (graph.getPackage(pkgName)) {
                case Some(pkg) => {
                    // 检查依赖是否指向其他 workspace
                    let allDeps = pkg.allDependencies()
                    for (depName in allDeps.keys()) {
                        // workspace 协议: workspace:*, workspace:^
                        match (allDeps.get(depName)) {
                            case Some(ver) => {
                                let isWorkspaceDep = ver.startsWith("workspace:")
                                if (isWorkspaceDep || pkgNames.contains(depName)) {
                                    graph.addDependency(pkgName, depName)
                                }
                            }
                            case None => {}
                        }
                    }
                }
                case None => {}
            }
        }
    }

    /// 获取根包
    public func getRootPackage(): ?WorkspacePackage {
        return rootPackage
    }

    /// 获取依赖图
    public func getGraph(): PackageGraph {
        return graph
    }
}

// ============================================================================
// 包提升 (Hoisting)
// 严格翻译自: src/install/hoisted_install.zig
//   Bun 支持提升 (hoist) 模式: 将依赖提升到根 node_modules
//   避免重复安装相同版本的包
// ============================================================================

/// 提升冲突信息
public class HoistConflict {
    public let packageName: String
    public let version1: String
    public let version2: String
    public let source1: String
    public let source2: String

    public init(packageName: String, v1: String, v2: String, s1: String, s2: String) {
        this.packageName = packageName
        this.version1 = v1
        this.version2 = v2
        this.source1 = s1
        this.source2 = s2
    }

    public func toString(): String {
        return "Hoist conflict: ${packageName} has conflicting versions ${version1} (from ${source1}) and ${version2} (from ${source2})"
    }
}

/// 提升结果
public class HoistResult {
    /// 提升到根的包 name@version
    public var hoisted: ArrayList<String>
    /// 保留在各工作区的包 name@version -> workspace
    public var local: HashMap<String, String>
    /// 冲突列表
    public var conflicts: ArrayList<HoistConflict>

    public init() {
        hoisted = ArrayList<String>()
        local = HashMap<String, String>()
        conflicts = ArrayList<HoistConflict>()
    }
}

/// 包提升管理器
/// 对应 Bun: hoisted_install.zig 中的提升逻辑
public class Hoisting {
    /// 将公共依赖提升到根 node_modules
    /// 对应 Bun: installHoistedPackages
    public static func hoistToRoot(graph: PackageGraph): HoistResult {
        let result = HoistResult()

        // 收集所有包的所有依赖
        // name -> {version -> [source packages]}
        let depVersions = HashMap<String, HashMap<String, ArrayList<String>>>()

        let pkgNames = graph.packageNames()
        for (pkgName in pkgNames) {
            match (graph.getPackage(pkgName)) {
                case Some(pkg) => {
                    let allDeps = pkg.allDependencies()
                    for (depName in allDeps.keys()) {
                        match (allDeps.get(depName)) {
                            case Some(ver) => {
                                // 解析版本范围
                                let resolvedVer = resolveVersion(ver)
                                match (depVersions.get(depName)) {
                                    case Some(verMap) => {
                                        match (verMap.get(resolvedVer)) {
                                            case Some(sources) => sources.append(pkgName)
                                            case None => {
                                                let sources = ArrayList<String>()
                                                sources.append(pkgName)
                                                verMap.put(resolvedVer, sources)
                                            }
                                        }
                                    }
                                    case None => {
                                        let verMap = HashMap<String, ArrayList<String>>()
                                        let sources = ArrayList<String>()
                                        sources.append(pkgName)
                                        verMap.put(resolvedVer, sources)
                                        depVersions.put(depName, verMap)
                                    }
                                }
                            }
                            case None => {}
                        }
                    }
                }
                case None => {}
            }
        }

        // 提升策略: 如果所有工作区使用同一版本 -> 提升到根
        // 如果有不同版本 -> 保留在各工作区 (记录冲突)
        for (depName in depVersions.keys()) {
            match (depVersions.get(depName)) {
                case Some(verMap) => {
                    if (verMap.size == 1) {
                        // 只有一个版本 -> 可以提升
                        for (ver in verMap.keys()) {
                            match (verMap.get(ver)) {
                                case Some(_) => {
                                    result.hoisted.append("${depName}@${ver}")
                                }
                                case None => {}
                            }
                        }
                    } else {
                        // 多个版本 -> 冲突, 各自保留
                        let versions = ArrayList<String>()
                        for (ver in verMap.keys()) {
                            versions.append(ver)
                        }
                        if (versions.size >= 2) {
                            result.conflicts.append(HoistConflict(
                                packageName: depName,
                                v1: versions[0],
                                v2: versions[1],
                                s1: "",
                                s2: ""
                            ))
                        }
                        // 记录本地保留
                        for (ver in verMap.keys()) {
                            match (verMap.get(ver)) {
                                case Some(sources) => {
                                    for (source in sources) {
                                        result.local.put("${depName}@${ver}", source)
                                    }
                                }
                                case None => {}
                            }
                        }
                    }
                }
                case None => {}
            }
        }

        return result
    }

    /// 检测提升冲突
    /// 对应 Bun: hoisted_install 中的冲突检测
    public static func detectConflicts(graph: PackageGraph): ArrayList<HoistConflict> {
        let result = ArrayList<HoistConflict>()
        let depVersions = HashMap<String, ArrayList<String>>()

        let pkgNames = graph.packageNames()
        for (pkgName in pkgNames) {
            match (graph.getPackage(pkgName)) {
                case Some(pkg) => {
                    let allDeps = pkg.allDependencies()
                    for (depName in allDeps.keys()) {
                        match (allDeps.get(depName)) {
                            case Some(ver) => {
                                let resolved = resolveVersion(ver)
                                match (depVersions.get(depName)) {
                                    case Some(list) => list.append(resolved)
                                    case None => {
                                        let list = ArrayList<String>()
                                        list.append(resolved)
                                        depVersions.put(depName, list)
                                    }
                                }
                            }
                            case None => {}
                        }
                    }
                }
                case None => {}
            }
        }

        // 找到版本冲突
        for (depName in depVersions.keys()) {
            match (depVersions.get(depName)) {
                case Some(versions) => {
                    let uniqueVersions = HashSet<String>()
                    for (v in versions) { uniqueVersions.put(v) }
                    if (uniqueVersions.size > 1) {
                        let vers = ArrayList<String>()
                        for (v in uniqueVersions) {
                            match (v) {
                                case Some(val) => vers.append(val)
                                case None => {}
                            }
                        }
                        if (vers.size >= 2) {
                            result.append(HoistConflict(
                                packageName: depName,
                                v1: vers[0],
                                v2: vers[1],
                                s1: "",
                                s2: ""
                            ))
                        }
                    }
                }
                case None => {}
            }
        }

        return result
    }

    /// 解析版本范围到具体版本
    /// 对应 Bun: semver range resolution
    private static func resolveVersion(range: String): String {
        // workspace: 协议
        if (range.startsWith("workspace:")) {
            let rest = range.substring(10)
            if (rest == "*" || rest == "^" || rest == "~") {
                return "workspace:*"
            }
            return rest
        }
        // npm: alias
        if (range.startsWith("npm:")) {
            let rest = range.substring(4)
            let atIndex = rest.indexOf("@", Int64(1))
            if (atIndex >= 0) {
                return rest.substring(atIndex + 1)
            }
            return "latest"
        }
        return range
    }
}
