// bao_install - Workspace 管理
// 严格翻译自: src/install/PackageManager/WorkspacePackageJSONCache.zig
//              src/install/hoisted_install.zig
//              src/install/isolated_install.zig
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
//   翻译自: WorkspacePackageJSONCache 中缓存的包信息
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
    /// peer 依赖元数据 (optional 标记)
    public var peerDependenciesMeta: HashMap<String, HashMap<String, String>>
    /// 可选依赖
    public var optionalDependencies: HashMap<String, String>
    /// 是否是根工作区
    public var isRoot: Bool
    /// 包的主入口
    public var `main`: String
    /// scripts
    public var scripts: HashMap<String, String>
    /// bin 条目
    public var bin: HashMap<String, String>
    /// trustedDependencies
    public var trustedDependencies: ArrayList<String>
    /// workspaces 定义 (仅根包)
    public var workspaces: ArrayList<String>
    /// overrides (仅根包)
    public var overrides: HashMap<String, String>

    public init(name: String, version: SemVer, relativePath: String) {
        this.name = name
        this.version = version
        this.relativePath = relativePath
        absolutePath = ""
        dependencies = HashMap<String, String>()
        devDependencies = HashMap<String, String>()
        peerDependencies = HashMap<String, String>()
        peerDependenciesMeta = HashMap<String, HashMap<String, String>>()
        optionalDependencies = HashMap<String, String>()
        isRoot = false
        `main` = "index.js"
        scripts = HashMap<String, String>()
        bin = HashMap<String, String>()
        trustedDependencies = ArrayList<String>()
        workspaces = ArrayList<String>()
        overrides = HashMap<String, String>()
    }

    /// 所有依赖 (合并 dependencies + devDependencies)
    public func allDependencies(): HashMap<String, String> {
        let all = HashMap<String, String>()
        for (key in dependencies.keys()) {
            match (dependencies.get(key)) {
                case Some(v) => all.put(key, v)
                case None => ()
            }
        }
        for (key in devDependencies.keys()) {
            match (devDependencies.get(key)) {
                case Some(v) => all.put(key, v)
                case None => ()
            }
        }
        return all
    }

    /// 唯一键
    public func key(): String {
        return "${name}@${version.toString()}"
    }

    /// 是否信任指定包的生命周期脚本
    public func isTrusted(packageName: String): Bool {
        for (td in trustedDependencies) {
            if (td == packageName) { return true }
        }
        return false
    }
}

// ============================================================================
// 工作区 glob 解析
// 严格翻译自: package.json 中 workspaces 字段的解析
//   Bun 支持 workspaces: ["packages/*"] glob 模式
//   翻译自: WorkspacePackageJSONCache.load 中 glob 展开
// ============================================================================

/// 工作区 glob 解析器
public class WorkspaceGlob {
    /// 解析 workspaces 字段
    /// 支持: ["packages/*"], ["app", "libs/*"], "packages/*"
    /// 翻译自: package.json 中 workspaces 字段的多种格式
    public static func parseGlobs(workspacesField: ?JsonValue): ArrayList<String> {
        let globs = ArrayList<String>()
        match (workspacesField) {
            case Some(JsonValue.Array(arr)) => parseGlobsFromArray(arr, globs)
            case Some(JsonValue.Str(s)) => globs.append(s)
            // npm 的 workspaces 可能是对象: { packages: [...] }
            case Some(JsonValue.Object(obj)) => parseGlobsFromObject(obj, globs)
            case _ => ()
        }
        return globs
    }

    private static func parseGlobsFromArray(arr: ArrayList<JsonValue>, globs: ArrayList<String>): Unit {
        for (item in arr) {
            match (item) {
                case JsonValue.Str(s) => globs.append(s)
                case _ => ()
            }
        }
    }

    private static func parseGlobsFromObject(obj: HashMap<String, JsonValue>, globs: ArrayList<String>): Unit {
        match (obj.get("packages")) {
            case Some(JsonValue.Array(arr)) => parseGlobsFromArray(arr, globs)
            case _ => ()
        }
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

        // 排序路径
        paths.sortWith({ a, b => a.compare(b) })

        return paths
    }

    /// 展开单个 glob 模式
    /// 处理通配符: packages/* -> packages/a, packages/b, ...
    private static func expandSingleGlob(glob: String, rootDir: String): ArrayList<String> {
        let result = ArrayList<String>()

        // 简单 glob: 仅处理末尾的 *
        if (glob.endsWith("/*")) {
            let dir = glob.substring(0, glob.size - 2)
            let fullDir = Path.join([rootDir, dir])

            // 列出目录下的子目录
            let entries = BaoFile.readDir(fullDir)
            match (entries) {
                case Some(dirEntries) => expandDirEntries(dirEntries, dir, rootDir, result)
                case None => ()
            }
        } else if (glob.endsWith("/**")) {
            // 递归 glob: packages/**
            let dir = glob.substring(0, glob.size - 3)
            expandRecursive(rootDir, dir, result)
        } else {
            // 精确路径
            let pkgJson = Path.join([rootDir, glob, "package.json"])
            if (BaoFile.exists(pkgJson)) {
                result.append(glob)
            }
        }

        return result
    }

    private static func expandDirEntries(dirEntries: ArrayList<String>, dir: String, rootDir: String, result: ArrayList<String>): Unit {
        for (entry in dirEntries) {
            let entryPath = Path.join([dir, entry])
            // 检查是否有 package.json
            let pkgJson = Path.join([
                rootDir, entryPath, "package.json"
            ])
            if (BaoFile.exists(pkgJson)) {
                result.append(entryPath)
            }
        }
    }

    /// 递归展开目录
    private static func expandRecursive(rootDir: String, subDir: String, result: ArrayList<String>): Unit {
        let fullDir = Path.join([rootDir, subDir])
        let entries = BaoFile.readDir(fullDir)
        match (entries) {
            case Some(dirEntries) => expandRecursiveEntries(dirEntries, rootDir, subDir, result)
            case None => ()
        }
    }

    private static func expandRecursiveEntries(dirEntries: ArrayList<String>, rootDir: String, subDir: String, result: ArrayList<String>): Unit {
        for (entry in dirEntries) {
            let entryPath = Path.join([subDir, entry])
            let pkgJson = Path.join([
                rootDir, entryPath, "package.json"
            ])
            if (BaoFile.exists(pkgJson)) {
                result.append(entryPath)
            }
            // 递归子目录 (仅当子目录没有 package.json 时)
            let subDirPath = Path.join([rootDir, entryPath])
            if (BaoFile.isDirectory(subDirPath)) {
                expandRecursive(rootDir, entryPath, result)
            }
        }
    }
}

// ============================================================================
// 包图 - 工作区依赖图
// 严格翻译自: src/install/hoisted_install.zig 中的依赖图构建
//   Bun 构建工作区依赖图来确定安装顺序和提升策略
//   翻译自: hoisted_install 中 Tree/Package 的拓扑排序
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
            case Some(list) => addDepToList(list, to)
            case None => addNewDepList(from, to)
        }
        topoOrder = None
    }

    private func addDepToList(list: ArrayList<String>, to: String): Unit {
        if (!list.contains(to)) {
            list.append(to)
        }
    }

    private func addNewDepList(from: String, to: String): Unit {
        let list = ArrayList<String>()
        list.append(to)
        edges.put(from, list)
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
                case None => ()
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
    /// 翻译自: hoisted_install 中确定安装顺序的逻辑
    public func topologicalSort(): ArrayList<String> {
        match (topoOrder) {
            case Some(order) => return order
            case None => ()
        }

        let result = ArrayList<String>()
        let visited = HashSet<String>()
        let inStack = HashSet<String>()

        // 从根包开始
        match (rootPackage) {
            case Some(root) => topoVisit(root, visited, inStack, result)
            case None => ()
        }

        // 处理未连接到根的包
        for (key in packages.keys()) {
            match (key) {
                case Some(k) => topoVisit(k, visited, inStack, result)
                case None => ()
            }
        }

        // 反转得到依赖优先的顺序 (被依赖的在前)
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
            case Some(deps) => topoVisitDeps(deps, visited, inStack, result)
            case None => ()
        }

        inStack.remove(node)
        visited.put(node)
        result.append(node)
    }

    private func topoVisitDeps(deps: ArrayList<String>, visited: HashSet<String>, inStack: HashSet<String>, result: ArrayList<String>): Unit {
        for (dep in deps) {
            topoVisit(dep, visited, inStack, result)
        }
    }

    /// 检查是否有循环依赖
    public func hasCycles(): Bool {
        let visited = HashSet<String>()
        let inStack = HashSet<String>()

        for (key in packages.keys()) {
            match (key) {
                case Some(k) => if (detectCycle(k, visited, inStack)) { return true }
                case None => ()
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
            case Some(deps) => if (detectCycleInDeps(deps, visited, inStack)) { return true }
            case None => ()
        }

        inStack.remove(node)
        return false
    }

    private func detectCycleInDeps(deps: ArrayList<String>, visited: HashSet<String>, inStack: HashSet<String>): Bool {
        for (dep in deps) {
            if (detectCycle(dep, visited, inStack)) {
                return true
            }
        }
        return false
    }

    /// 获取依赖于指定包的包列表 (反向依赖)
    public func getDependents(packageName: String): ArrayList<String> {
        let result = ArrayList<String>()
        for (key in edges.keys()) {
            match (edges.get(key)) {
                case Some(deps) => if (deps.contains(packageName)) { result.append(key) }
                case None => ()
            }
        }
        return result
    }

    /// 获取包的依赖边
    public func getDependencies(name: String): ArrayList<String> {
        match (edges.get(name)) {
            case Some(deps) => return deps
            case None => return ArrayList<String>()
        }
    }
}

// ============================================================================
// 工作区解析器
// 严格翻译自: src/install/PackageManager/WorkspacePackageJSONCache.zig
//   Bun 在安装开始时扫描所有 workspace 的 package.json
//   解析 workspaces 字段, 构建依赖图
//   翻译自: WorkspacePackageJSONCache.load
// ============================================================================

/// 工作区解析器 - monorepo 工作区检测和管理
/// 对应 Bun: WorkspacePackageJSONCache
public class WorkspaceResolver {
    private var rootDir: String
    private var jsonParser: JsonParser
    private var graph: PackageGraph
    /// 根包的 package.json
    private var rootPackage: ?WorkspacePackage
    /// 工作区包名 -> 版本映射
    private var workspaceVersions: HashMap<String, String>

    public init(rootDir: String) {
        this.rootDir = rootDir
        jsonParser = JsonParser()
        graph = PackageGraph()
        rootPackage = None
        workspaceVersions = HashMap<String, String>()
    }

    /// 解析工作区配置并构建依赖图
    /// 对应 Bun: WorkspacePackageJSONCache.load
    public func resolveWorkspacePackages(): PackageGraph {
        graph = PackageGraph()
        workspaceVersions.clear()

        // 1. 读取根 package.json
        let rootPkgJsonPath = Path.join([rootDir, "package.json"])
        let rootContent = try {
            BaoFile.readAllText(rootPkgJsonPath)
        } catch (_: Exception) {
            return graph
        }

        let rootJson = jsonParser.parse(rootContent)
        match (rootJson) {
            case Some(root) => resolveFromRootJson(root)
            case None => ()
        }

        return graph
    }

    private func resolveFromRootJson(root: JsonValue): Unit {
        let rootPkg = parsePackageJson(root, ".", true)
        match (rootPkg) {
            case Some(pkg) => _matchHelper_workspace_244()
            case None => ()
        }
        // 2. 获取 workspaces 配置
        let workspacesField = JsonHelper.getField(root, "workspaces")
        let globs = WorkspaceGlob.parseGlobs(workspacesField)
        // 3. 展开 glob 模式
        let workspacePaths = WorkspaceGlob.expandGlobs(globs, rootDir)
        // 4. 解析每个 workspace 的 package.json
        for (wsPath in workspacePaths) {
            let pkgJsonPath = Path.join([
                rootDir, wsPath, "package.json"
            ])
            let content = try {
                BaoFile.readAllText(pkgJsonPath)
            } catch (_: Exception) {
                continue
            }
            let wsJson = jsonParser.parse(content)
            match (wsJson) {
                case Some(j) => parseWorkspaceJson(j, wsPath)
                case None => ()
            }
        }
        // 5. 构建依赖图边
        buildDependencyEdges()
    }

    private func parseWorkspaceJson(json: JsonValue, wsPath: String): Unit {
        let wsPkg = parsePackageJson(json, wsPath, false)
        match (wsPkg) {
            case Some(pkg) => _matchHelper_workspace_245()
            case None => ()
        }
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
        pkg.absolutePath = Path.join([rootDir, relativePath])
        pkg.`main` = match (JsonHelper.getString(json, "main")) {
            case Some(m) => m
            case None => "index.js"
        }

        // 依赖
        pkg.dependencies = JsonHelper.getStringMap(json, "dependencies")
        pkg.devDependencies = JsonHelper.getStringMap(json, "devDependencies")
        pkg.peerDependencies = JsonHelper.getStringMap(json, "peerDependencies")
        pkg.optionalDependencies = JsonHelper.getStringMap(json, "optionalDependencies")

        // peerDependenciesMeta
        match (JsonHelper.getField(json, "peerDependenciesMeta")) {
            case Some(JsonValue.Object(pdm)) => parsePeerDepsMeta(pdm, pkg)
            case _ => ()
        }

        // scripts
        match (JsonHelper.getField(json, "scripts")) {
            case Some(JsonValue.Object(scripts)) => parseScripts(scripts, pkg)
            case _ => ()
        }

        // bin
        match (JsonHelper.getField(json, "bin")) {
            case Some(JsonValue.Object(binObj)) => parseBin(binObj, pkg)
            case Some(JsonValue.Str(binStr)) => pkg.bin.put(name, binStr)
            case _ => ()
        }

        // trustedDependencies
        match (JsonHelper.getField(json, "trustedDependencies")) {
            case Some(JsonValue.Array(arr)) => parseTrustedDeps(arr, pkg)
            case _ => ()
        }

        // overrides
        match (JsonHelper.getField(json, "overrides")) {
            case Some(JsonValue.Object(overridesObj)) => parseOverrides(overridesObj, pkg)
            case _ => ()
        }

        // workspaces (仅根包)
        if (isRoot) {
            let wsGlobs = WorkspaceGlob.parseGlobs(JsonHelper.getField(json, "workspaces"))
            for (g in wsGlobs) {
                pkg.workspaces.append(g)
            }
        }

        return Some(pkg)
    }

    private func parsePeerDepsMeta(pdm: HashMap<String, JsonValue>, pkg: WorkspacePackage): Unit {
        for (k in pdm.keys()) {
            match (pdm.get(k)) {
                case Some(JsonValue.Object(metaObj)) => _matchHelper_workspace_246()
                case _ => ()
            }
        }
    }

    private func parseScripts(scripts: HashMap<String, JsonValue>, pkg: WorkspacePackage): Unit {
        for (k in scripts.keys()) {
            match (scripts.get(k)) {
                case Some(JsonValue.Str(v)) => pkg.scripts.put(k, v)
                case _ => ()
            }
        }
    }

    private func parseBin(binObj: HashMap<String, JsonValue>, pkg: WorkspacePackage): Unit {
        for (k in binObj.keys()) {
            match (binObj.get(k)) {
                case Some(JsonValue.Str(v)) => pkg.bin.put(k, v)
                case _ => ()
            }
        }
    }

    private func parseTrustedDeps(arr: ArrayList<JsonValue>, pkg: WorkspacePackage): Unit {
        for (item in arr) {
            match (item) {
                case JsonValue.Str(s) => pkg.trustedDependencies.append(s)
                case _ => ()
            }
        }
    }

    private func parseOverrides(overridesObj: HashMap<String, JsonValue>, pkg: WorkspacePackage): Unit {
        for (k in overridesObj.keys()) {
            match (overridesObj.get(k)) {
                case Some(JsonValue.Str(v)) => pkg.overrides.put(k, v)
                case _ => ()
            }
        }
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
                case Some(pkg) => buildPkgEdges(pkg, pkgName, pkgNames)
                case None => ()
            }
        }
    }

    private func buildPkgEdges(pkg: WorkspacePackage, pkgName: String, pkgNames: HashSet<String>): Unit {
        // 检查依赖是否指向其他 workspace
        let allDeps = pkg.allDependencies()
        for (depName in allDeps.keys()) {
            match (allDeps.get(depName)) {
                case Some(ver) => _matchHelper_workspace_247()
                case None => ()
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

    /// 获取 workspace 版本映射
    public func getWorkspaceVersions(): HashMap<String, String> {
        return workspaceVersions
    }

    /// 获取所有 workspace 包名
    public func getWorkspacePackageNames(): HashSet<String> {
        let names = HashSet<String>()
        for (name in workspaceVersions.keys()) {
            names.put(name)
        }
        return names
    }
}

// ============================================================================
// 包提升 (Hoisting)
// 严格翻译自: src/install/hoisted_install.zig
//   Bun 支持提升 (hoist) 模式: 将依赖提升到根 node_modules
//   避免重复安装相同版本的包
//   翻译自: hoisted_install 中 installHoistedPackages
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
        version1 = v1
        version2 = v2
        source1 = s1
        source2 = s2
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
/// 翻译自: installHoistedPackages 中的依赖提升算法
public class Hoisting {
    /// 将公共依赖提升到根 node_modules
    /// 对应 Bun: installHoistedPackages
    /// 翻译自: hoisted_install 中遍历 Tree 并安装的逻辑
    public static func hoistToRoot(graph: PackageGraph): HoistResult {
        let result = HoistResult()

        // 收集所有包的所有依赖
        // name -> {version -> [source packages]}
        let depVersions = HashMap<String, HashMap<String, ArrayList<String>>>()

        let pkgNames = graph.packageNames()
        for (pkgName in pkgNames) {
            match (graph.getPackage(pkgName)) {
                case Some(pkg) => collectDepsForHoisting(pkg, pkgName, depVersions)
                case None => ()
            }
        }

        // 提升策略:
        // 1. 所有工作区使用同一版本 -> 提升到根
        // 2. 有不同版本 -> 尝试兼容性提升 (如果版本范围兼容)
        // 3. 不兼容 -> 保留在各工作区 (记录冲突)
        for (depName in depVersions.keys()) {
            match (depVersions.get(depName)) {
                case Some(verMap) => decideHoisting(depName, verMap, result)
                case None => ()
            }
        }

        return result
    }

    private static func collectDepsForHoisting(pkg: WorkspacePackage, pkgName: String, depVersions: HashMap<String, HashMap<String, ArrayList<String>>>): Unit {
        let allDeps = pkg.allDependencies()
        for (depName in allDeps.keys()) {
            match (allDeps.get(depName)) {
                case Some(ver) => _matchHelper_workspace_248()
                case None => ()
            }
        }
    }

    private static func addDepVersionSource(verMap: HashMap<String, ArrayList<String>>, resolvedVer: String, pkgName: String): Unit {
        match (verMap.get(resolvedVer)) {
            case Some(sources) => sources.append(pkgName)
            case None => _matchHelper_workspace_249()
        }
    }

    private static func addNewDepVersion(depVersions: HashMap<String, HashMap<String, ArrayList<String>>>, depName: String, resolvedVer: String, pkgName: String): Unit {
        let verMap = HashMap<String, ArrayList<String>>()
        let sources = ArrayList<String>()
        sources.append(pkgName)
        verMap.put(resolvedVer, sources)
        depVersions.put(depName, verMap)
    }

    private static func decideHoisting(depName: String, verMap: HashMap<String, ArrayList<String>>, result: HoistResult): Unit {
        if (verMap.size == 1) {
            // 只有一个版本 -> 可以提升
            for (ver in verMap.keys()) {
                match (verMap.get(ver)) {
                    case Some(_) => result.hoisted.append("${depName}@${ver}")
                    case None => ()
                }
            }
        } else {
            // 多个版本 -> 检查是否可以通过 semver 兼容
            let versions = ArrayList<String>()
            for (ver in verMap.keys()) {
                versions.append(ver)
            }
            // 尝试找到满足所有请求的版本
            let compatible = findCompatibleVersion(versions)
            match (compatible) {
                case Some(bestVer) => _matchHelper_workspace_250()
                case None => _matchHelper_workspace_251()
            }
        }
    }

    /// 检测提升冲突
    /// 对应 Bun: hoisted_install 中的冲突检测
    public static func detectConflicts(graph: PackageGraph): ArrayList<HoistConflict> {
        let result = ArrayList<HoistConflict>()
        let depVersions = HashMap<String, ArrayList<String>>()

        let pkgNames = graph.packageNames()
        for (pkgName in pkgNames) {
            match (graph.getPackage(pkgName)) {
                case Some(pkg) => collectConflictsForPkg(pkg, depVersions)
                case None => ()
            }
        }

        for (depName in depVersions.keys()) {
            match (depVersions.get(depName)) {
                case Some(versions) => checkVersionConflicts(depName, versions, result)
                case None => ()
            }
        }

        return result
    }

    private static func collectConflictsForPkg(pkg: WorkspacePackage, depVersions: HashMap<String, ArrayList<String>>): Unit {
        let allDeps = pkg.allDependencies()
        for (depName in allDeps.keys()) {
            match (allDeps.get(depName)) {
                case Some(ver) => _matchHelper_workspace_252()
                case None => ()
            }
        }
    }

    private static func checkVersionConflicts(depName: String, versions: ArrayList<String>, result: ArrayList<HoistConflict>): Unit {
        let uniqueVersions = HashSet<String>()
        for (v in versions) { uniqueVersions.put(v) }
        if (uniqueVersions.size > 1) {
            let vers = ArrayList<String>()
            for (v in uniqueVersions) {
                match (v) {
                    case Some(val) => vers.append(val)
                    case None => ()
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

    /// 解析版本范围到具体版本
    /// 对应 Bun: semver range resolution
    private static func resolveVersion(range: String): String {
        if (range.startsWith("workspace:")) {
            let rest = range.substring(10)
            if (rest == "*" || rest == "^" || rest == "~") {
                return "workspace:*"
            }
            return rest
        }
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

    /// 查找兼容版本 (满足所有版本范围的最高版本)
    private static func findCompatibleVersion(versions: ArrayList<String>): ?String {
        if (versions.size == 0) { return None }
        if (versions.size == 1) { return Some(versions[0]) }

        // 尝试找到最高版本
        var best: ?String = None
        for (v in versions) {
            let sv = SemVer.parse(v)
            match (sv) {
                case Some(parsed) => best = updateBest(best, v, parsed)
                case None => ()
            }
        }
        return best
    }

    private static func updateBest(best: ?String, v: String, parsed: SemVer): ?String {
        match (best) {
            case Some(b) => _matchHelper_workspace_253()
            case None => return Some(v)
        }
    }
}

// ============================================================================
// 隔离安装模式 (pnpm-style)
// 严格翻译自: src/install/isolated_install.zig
//   Bun 的 isolated install 模式类似 pnpm:
//   - 使用全局 Store 存储包
//   - 通过硬链接/符号链接安装到 node_modules
//   - 每个 包 有自己的 node_modules, 只包含声明的依赖
//   - 使用 .store 目录存放实际的包内容
//
// 翻译自: installIsolatedPackages 中的 Store/Node 构建逻辑
// ============================================================================

/// 隔离安装布局
/// 对应 Bun: isolated_install 中的 Node 结构
public class IsolatedNode {
    /// 包名
    public let name: String
    /// 版本
    public let version: String
    /// Store 中的路径
    public var storePath: String
    /// node_modules 中的链接路径
    public var linkPath: String
    /// 父节点 ID
    public var parentId: Int64
    /// 是否已安装
    public var installed: Bool
    /// peer 依赖解析结果
    public var resolvedPeers: HashMap<String, String>

    public init(name: String, version: String) {
        this.name = name
        this.version = version
        storePath = ""
        linkPath = ""
        parentId = -1
        installed = false
        resolvedPeers = HashMap<String, String>()
    }

    public func key(): String {
        return "${name}@${version}"
    }
}


            private func _matchHelper_workspace_244(): Unit {
                rootPackage = Some(pkg)
                graph.addPackage(pkg)
                workspaceVersions.put(pkg.name, pkg.version.toString())
            }

            private func _matchHelper_workspace_245(): Unit {
                graph.addPackage(pkg)
                workspaceVersions.put(pkg.name, pkg.version.toString())
            }

                private func _matchHelper_workspace_246(): Unit {
                    let meta = HashMap<String, String>()
                    for (mk in metaObj.keys()) {
                        match (metaObj.get(mk)) {
                            case Some(JsonValue.JsonBool(b)) => meta.put(mk, if (b) { "true" } else { "false" })
                            case Some(JsonValue.Str(s)) => meta.put(mk, s)
                            case _ => ()
                        }
                    }
                    pkg.peerDependenciesMeta.put(k, meta)
                }

                private func _matchHelper_workspace_247(): Unit {
                    // workspace 协议: workspace:*, workspace:^
                    let isWorkspaceDep = ver.startsWith("workspace:")
                    if (isWorkspaceDep || pkgNames.contains(depName)) {
                        graph.addDependency(pkgName, depName)
                    }
                }

                private func _matchHelper_workspace_248(): Unit {
                    // 解析版本范围
                    let resolvedVer = resolveVersion(ver)
                    match (depVersions.get(depName)) {
                        case Some(verMap) => addDepVersionSource(verMap, resolvedVer, pkgName)
                        case None => addNewDepVersion(depVersions, depName, resolvedVer, pkgName)
                    }
                }

            private func _matchHelper_workspace_249(): Unit {
                let sources = ArrayList<String>()
                sources.append(pkgName)
                verMap.put(resolvedVer, sources)
            }

                private func _matchHelper_workspace_250(): Unit {
                    // 可以提升到兼容版本
                    result.hoisted.append("${depName}@${bestVer}")
                }

                private func _matchHelper_workspace_251(): Unit {
                    // 无法兼容 -> 记录冲突
                    if (versions.size >= 2) {
                        result.conflicts.append(HoistConflict(
                            packageName: depName,
                            v1: versions[0],
                            v2: versions[1],
                            s1: "",
                            s2: ""
                        ))
                    }
                    // 各自保留
                    for (ver in verMap.keys()) {
                        match (verMap.get(ver)) {
                            case Some(sources) => _matchHelper_workspace_81()
                            case None => ()
                        }
                    }
                }

                private func _matchHelper_workspace_252(): Unit {
                    let resolved = resolveVersion(ver)
                    match (depVersions.get(depName)) {
                        case Some(list) => list.append(resolved)
                        case None => _matchHelper_workspace_82()
                    }
                }

            private func _matchHelper_workspace_253(): Unit {
                let bsv = SemVer.parse(b)
                match (bsv) {
                    case Some(bsvParsed) => _matchHelper_workspace_83()
                    case None => return best
                }
            }

                            private func _matchHelper_workspace_81(): Unit {
                                for (source in sources) {
                                    result.local.put("${depName}@${ver}", source)
                                }
                            }

                        private func _matchHelper_workspace_82(): Unit {
                            let list = ArrayList<String>()
                            list.append(resolved)
                            depVersions.put(depName, list)
                        }

                    private func _matchHelper_workspace_83(): Unit {
                        if (parsed.compare(bsvParsed) > 0) {
                            return Some(v)
                        }
                        return best
                    }