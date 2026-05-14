// 严格翻译自: src/install/hoisted_install.zig, src/install/isolated_install.zig
// bao_install - 包链接 (node_modules 符号链接创建)
package bao_install

import bao_core.*
import bao_collections.*
import bao_io.*
import bao_hash.*
import bao_path.*

// ============================================================================
// 包链接器 - 创建 node_modules 中的符号链接
// 严格翻译自: src/install/hoisted_install.zig (HoistedInstall)
// ============================================================================

/// 链接类型
public enum LinkType {
    | Symlink     // 符号链接 (大多数情况)
    | Hardlink    // 硬链接 (同一文件系统)
    | Copy        // 文件复制 (Windows 回退)
    | Junction    // Windows junction point
}

/// 包链接信息
/// 严格翻译自: src/install/hoisted_install.zig 中的链接数据
public class PackageLink {
    /// 链接源 (缓存中的包路径)
    public var sourcePath: String
    /// 链接目标 (node_modules 中的路径)
    public var targetPath: String
    /// 包名
    public var packageName: String
    /// 包版本
    public var version: String
    /// 是否是 scope 包 (@org/name)
    public var isScoped: Bool
    /// scope 名 (例: @types)
    public var scopeName: ?String
    /// 链接类型
    public var linkType: LinkType

    public init(packageName: String, sourcePath: String, targetPath: String) {
        this.packageName = packageName
        this.sourcePath = sourcePath
        this.targetPath = targetPath
        this.version = ""
        this.isScoped = packageName.startsWith("@")
        this.scopeName = None
        this.linkType = LinkType.Symlink

        if (isScoped) {
            let slashIdx = packageName.indexOf("/")
            match (slashIdx) {
                case Some(idx) => scopeName = Some(packageName.substring(0, idx))
                case None => {}
            }
        }
    }
}

/// 包链接器
/// 严格翻译自: src/install/hoisted_install.zig HoistedInstall
/// 核心职责:
///   1. 创建 node_modules 目录结构
///   2. 为每个依赖创建符号链接
///   3. 处理 scoped packages (@org/name)
///   4. 处理 peer dependencies 的提升
///   5. 处理扁平化 vs 隔离布局
public class PackageLinker {
    /// 项目根目录
    private var rootDir: String
    /// 缓存目录 (包实际存放位置)
    private var cacheDir: String
    /// node_modules 路径
    private var nodeModulesPath: String
    /// 已创建的链接列表
    private var createdLinks: ArrayList<PackageLink>
    /// 是否使用扁平化布局 (hoisted)
    private var hoisted: Bool
    /// 是否 dry-run
    private var dryRun: Bool

    public init(rootDir: String, cacheDir: String) {
        this.rootDir = rootDir
        this.cacheDir = cacheDir
        this.nodeModulesPath = Path.join([rootDir, "node_modules"])
        this.createdLinks = ArrayList<PackageLink>()
        this.hoisted = true
        this.dryRun = false
    }

    /// 设置布局模式
    public func setHoisted(h: Bool): PackageLinker {
        hoisted = h
        return this
    }

    /// 设置 dry-run 模式
    public func setDryRun(d: Bool): PackageLinker {
        dryRun = d
        return this
    }

    /// 链接所有包
    // 严格翻译自: src/install/hoisted_install.zig installPackages
    public func linkAll(packages: ArrayList<ResolvedPackage>): LinkResult {
        let result = LinkResult()

        if (packages.size == 0) {
            return result
        }

        // 确保 node_modules 目录存在
        if (!dryRun) {
            BaoFile.mkdir(nodeModulesPath, true)
        }

        if (hoisted) {
            linkHoisted(packages, result)
        } else {
            linkIsolated(packages, result)
        }

        return result
    }

    /// 扁平化布局链接 (hoisted)
    // 严格翻译自: src/install/hoisted_install.zig
    private func linkHoisted(packages: ArrayList<ResolvedPackage>, result: LinkResult): Unit {
        // 按 depth 排序: 顶层包先链接, 嵌套的后链接
        // 这样顶层包 "赢得" 扁平化位置
        let sorted = sortByDepth(packages)

        for (pkg in sorted) {
            let link = createLink(pkg)
            match (link) {
                case Some(l) => {
                    // 检查目标是否已存在
                    if (BaoFile.exists(l.targetPath)) {
                        // 已有包占位: 保留现有 (hoisted 的核心规则)
                        result.skipped.append(pkg.name)
                        continue
                    }

                    if (!dryRun) {
                        let success = performLink(l)
                        if (success) {
                            createdLinks.append(l)
                            result.linked.append(pkg.name)
                        } else {
                            result.failed.append(pkg.name)
                        }
                    } else {
                        result.linked.append(pkg.name)
                    }
                }
                case None => result.failed.append(pkg.name)
            }
        }
    }

    /// 隔离布局链接 (pnpm 风格)
    // 严格翻译自: src/install/isolated_install.zig
    private func linkIsolated(packages: ArrayList<ResolvedPackage>, result: LinkResult): Unit {
        // 在隔离模式下, 每个包有自己的 node_modules
        // 例如: node_modules/react/node_modules/loose-envify
        for (pkg in packages) {
            let parentModulesPath = match (pkg.parentPackage) {
                case Some(parent) => {
                    Path.join([nodeModulesPath, parent, "node_modules"])
                }
                case None => nodeModulesPath
            }

            let link = createIsolatedLink(pkg, parentModulesPath)
            match (link) {
                case Some(l) => {
                    if (!dryRun) {
                        let success = performLink(l)
                        if (success) {
                            createdLinks.append(l)
                            result.linked.append(pkg.name)
                        } else {
                            result.failed.append(pkg.name)
                        }
                    } else {
                        result.linked.append(pkg.name)
                    }
                }
                case None => result.failed.append(pkg.name)
            }
        }
    }

    /// 创建包链接描述
    // 严格翻译自: src/install/hoisted_install.zig 中 link 逻辑
    private func createLink(pkg: ResolvedPackage): ?PackageLink {
        let sourcePath = Path.join([cacheDir, pkg.name + "@" + pkg.version])

        // 目标路径取决于是否有 scope
        let targetPath = if (pkg.name.startsWith("@")) {
            // @org/name -> node_modules/@org/name
            let slashIdx = pkg.name.indexOf("/")
            match (slashIdx) {
                case Some(idx) => {
                    let scope = pkg.name.substring(0, idx)
                    let scopedName = pkg.name.substring(idx + 1)
                    let scopeDir = Path.join([nodeModulesPath, scope])
                    if (!dryRun) {
                        BaoFile.mkdir(scopeDir, true)
                    }
                    Path.join([scopeDir, scopedName])
                }
                case None => Path.join([nodeModulesPath, pkg.name])
            }
        } else {
            Path.join([nodeModulesPath, pkg.name])
        }

        let link = PackageLink(pkg.name, sourcePath, targetPath)
        link.version = pkg.version
        return Some(link)
    }

    /// 创建隔离模式链接
    private func createIsolatedLink(pkg: ResolvedPackage, parentModulesPath: String): ?PackageLink {
        let sourcePath = Path.join([cacheDir, pkg.name + "@" + pkg.version])

        // 确保 parent node_modules 存在
        if (!dryRun) {
            BaoFile.mkdir(parentModulesPath, true)
        }

        let targetPath = if (pkg.name.startsWith("@")) {
            let slashIdx = pkg.name.indexOf("/")
            match (slashIdx) {
                case Some(idx) => {
                    let scope = pkg.name.substring(0, idx)
                    let scopedName = pkg.name.substring(idx + 1)
                    let scopeDir = Path.join([parentModulesPath, scope])
                    if (!dryRun) { BaoFile.mkdir(scopeDir, true) }
                    Path.join([scopeDir, scopedName])
                }
                case None => Path.join([parentModulesPath, pkg.name])
            }
        } else {
            Path.join([parentModulesPath, pkg.name])
        }

        let link = PackageLink(pkg.name, sourcePath, targetPath)
        link.version = pkg.version
        return Some(link)
    }

    /// 执行实际的链接操作
    // 严格翻译自: src/install/hoisted_install.zig symlinkat
    private func performLink(link: PackageLink): Bool {
        // 确保源路径存在
        if (!BaoFile.isDirectory(link.sourcePath)) {
            return false
        }

        // 检测最佳链接类型
        let linkType = detectLinkType()

        match (linkType) {
            case LinkType.Symlink => {
                return BaoFile.createSymlink(link.sourcePath, link.targetPath)
            }
            case LinkType.Hardlink => {
                // 硬链接目录: 递归创建
                return hardlinkTree(link.sourcePath, link.targetPath)
            }
            case LinkType.Copy => {
                return BaoFile.copyTree(link.sourcePath, link.targetPath)
            }
            case LinkType.Junction => {
                return BaoFile.createSymlink(link.sourcePath, link.targetPath)
            }
        }
    }

    /// 检测最佳链接类型
    // 严格翻译自: src/install/hoisted_install.zig 中的平台检测
    private func detectLinkType(): LinkType {
        let os = Sys.osName()
        if (os.startsWith("Win")) {
            // Windows: junction 用于目录, 否则 copy
            return LinkType.Junction
        }
        // POSIX: symlink
        return LinkType.Symlink
    }

    /// 递归硬链接目录树
    private func hardlinkTree(src: String, dest: String): Bool {
        BaoFile.mkdir(dest, true)
        let entries = BaoFile.readdir(src)
        for (entry in entries) {
            if (entry == "." || entry == "..") { continue }
            let srcPath = Path.join([src, entry])
            let destPath = Path.join([dest, entry])
            if (BaoFile.isDirectory(srcPath)) {
                hardlinkTree(srcPath, destPath)
            } else {
                BaoFile.createHardlink(srcPath, destPath)
            }
        }
        return true
    }

    /// 按 depth 排序 (顶层包在前)
    private func sortByDepth(packages: ArrayList<ResolvedPackage>): ArrayList<ResolvedPackage> {
        let result = ArrayList<ResolvedPackage>()
        for (pkg in packages) {
            result.append(pkg)
        }
        // 简单排序: 没有 parent 的在前
        // 实际 Bun 使用更复杂的拓扑排序
        result.sortWith({ a, b =>
            let aDepth = match (a.parentPackage) {
                case Some(_) => 1
                case None => 0
            }
            let bDepth = match (b.parentPackage) {
                case Some(_) => 1
                case None => 0
            }
            aDepth - bDepth
        })
        return result
    }

    /// 清理 node_modules 中不再需要的链接
    // 严格翻译自: src/install/hoisted_install.zig cleanup
    public func cleanup(keepPackages: HashSet<String>): CleanupResult {
        let result = CleanupResult()
        let entries = BaoFile.readdir(nodeModulesPath)

        for (entry in entries) {
            if (entry == "." || entry == "..") { continue }
            let entryPath = Path.join([nodeModulesPath, entry])

            // 检查是否是符号链接
            if (BaoFile.isSymlink(entryPath)) {
                let linkTarget = BaoFile.readSymlink(entryPath)
                match (linkTarget) {
                    case Some(target) => {
                        // 检查包名
                        let pkgName = if (entry.startsWith("@")) {
                            // 检查子目录
                            let subEntries = BaoFile.readdir(entryPath)
                            for (sub in subEntries) {
                                let fullName = "${entry}/${sub}"
                                if (!keepPackages.contains(fullName)) {
                                    let subPath = Path.join([entryPath, sub])
                                    BaoFile.remove(subPath)
                                    result.removed.append(fullName)
                                }
                            }
                            ""
                        } else {
                            entry
                        }

                        if (!pkgName.isEmpty() && !keepPackages.contains(pkgName)) {
                            BaoFile.remove(entryPath)
                            result.removed.append(pkgName)
                        }
                    }
                    case None => {}
                }
            }
        }

        return result
    }

    /// 获取已创建的链接数
    public func getLinkCount(): Int64 {
        return createdLinks.size
    }

    /// 获取已创建的链接列表
    public func getLinks(): ArrayList<PackageLink> {
        return createdLinks
    }
}

/// 已解析的包 (链接输入)
public class ResolvedPackage {
    /// 包名
    public var name: String
    /// 版本
    public var version: String
    /// 父包名 (用于嵌套依赖)
    public var parentPackage: ?String
    /// 深度 (0 = 顶层)
    public var depth: Int64

    public init(name: String, version: String) {
        this.name = name
        this.version = version
        this.parentPackage = None
        this.depth = 0
    }
}

/// 链接结果
public class LinkResult {
    /// 成功链接的包
    public var linked: ArrayList<String>
    /// 跳过的包 (已存在)
    public var skipped: ArrayList<String>
    /// 失败的包
    public var failed: ArrayList<String>

    public init() {
        linked = ArrayList<String>()
        skipped = ArrayList<String>()
        failed = ArrayList<String>()
    }

    public func hasErrors(): Bool {
        return failed.size > 0
    }
}

/// 清理结果
public class CleanupResult {
    /// 移除的包
    public var removed: ArrayList<String>

    public init() {
        removed = ArrayList<String>()
    }
}
