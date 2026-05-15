// 严格翻译自: src/install/bin.zig, src/install/PackageInstaller.zig
// bao_install - 二进制符号链接管理 (.bin 目录)
package bao_install

import bao_core.*
import bao_collections.*
import bao_io.*
import bao_hash.*
import bao_path.*

// ============================================================================
// Binary 符号链接管理
// 严格翻译自: src/install/bin.zig, src/install/PackageInstaller.zig
// 管理器负责在 node_modules/.bin 中创建可执行文件的符号链接
// ============================================================================

/// Bin 链接条目
/// 严格翻译自: src/install/bin.zig 中 bin 解析后的链接信息
public class BinLink {
    /// bin 名称 (命令名)
    public var binName: String
    /// bin 源路径 (包内的相对路径)
    public var binSource: String
    /// 包名
    public var packageName: String
    /// 链接目标绝对路径 (node_modules/.bin/<name>)
    public var linkPath: String
    /// bin 源文件绝对路径
    public var sourceAbsPath: String

    public init(binName: String, binSource: String, packageName: String) {
        this.binName = binName
        this.binSource = binSource
        this.packageName = packageName
        this.linkPath = ""
        this.sourceAbsPath = ""
    }
}

/// Bin 管理器
/// 严格翻译自: src/install/PackageInstaller.zig 中的 bin 处理
/// 核心职责:
///   1. 从 package.json 的 bin 字段读取可执行文件信息
///   2. 在 node_modules/.bin 目录中创建符号链接
///   3. 处理 Windows 上的 .cmd shim 文件
///   4. 管理全局 bin 链接
public class BinManager {
    /// 项目根目录
    private var rootDir: String
    /// node_modules 路径
    private var nodeModulesPath: String
    /// .bin 目录路径
    private var binDirPath: String
    /// 已创建的 bin 链接
    private var links: ArrayList<BinLink>
    /// 是否 dry-run
    private var dryRun: Bool

    public init(rootDir: String) {
        this.rootDir = rootDir
        this.nodeModulesPath = Path.join([rootDir, "node_modules"])
        this.binDirPath = Path.join([nodeModulesPath, ".bin"])
        this.links = ArrayList<BinLink>()
        this.dryRun = false
    }

    /// 设置 dry-run
    public func setDryRun(d: Bool): BinManager {
        dryRun = d
        return this
    }

    /// 为包安装 bin 链接
    // 严格翻译自: src/install/PackageInstaller.zig installBin
    public func installBin(packageName: String, pkgJson: PackageJson): BinInstallResult {
        let result = BinInstallResult()
        let bin = pkgJson.bin

        // 确保 .bin 目录存在
        if (!dryRun) {
            BaoFile.mkdir(binDirPath, true)
        }

        match (bin.tag) {
            case BinTag.None => {
                // 没有 bin 字段
                return result
            }
            case BinTag.File => {
                // bin: "./cli.js"
                match (bin.filePath) {
                    case Some(path) => {
                        let binName = packageNameToBinName(packageName)
                        let link = createBinLink(binName, path, packageName)
                        match (link) {
                            case Some(l) => {
                                result.links.append(l)
                                result.installed.append(binName)
                            }
                            case None => result.failed.append(binName)
                        }
                    }
                    case None => ()
                }
            }
            case BinTag.NamedFile => {
                // bin: { "my-cli": "./cli.js" }
                let binName = bin.name ?? packageName
                let binSource = bin.namedPath ?? ""
                if (!binName.isEmpty() && !binSource.isEmpty()) {
                    let link = createBinLink(binName, binSource, packageName)
                    match (link) {
                        case Some(l) => {
                            result.links.append(l)
                            result.installed.append(binName)
                        }
                        case None => result.failed.append(binName)
                    }
                }
            }
            case BinTag.Map => {
                // bin: { "cmd1": "./cmd1.js", "cmd2": "./cmd2.js" }
                for (entry in bin.binMap.entries()) {
                    let link = createBinLink(entry.key, entry.value, packageName)
                    match (link) {
                        case Some(l) => {
                            result.links.append(l)
                            result.installed.append(entry.key)
                        }
                        case None => result.failed.append(entry.key)
                    }
                }
            }
            case BinTag.Dir => {
                // directories.bin: "./bin"
                match (bin.dirPath) {
                    case Some(dirRelPath) => {
                        let packageDir = Path.join([nodeModulesPath, packageName])
                        let binDir = Path.join([packageDir, dirRelPath])
                        // 遍历目录中的文件
                        let entries = BaoFile.readdir(binDir)
                        for (entry in entries) {
                            if (entry == "." || entry == "..") { continue }
                            let entryPath = Path.join([binDir, entry])
                            if (!BaoFile.isDirectory(entryPath)) {
                                let relPath = Path.join([dirRelPath, entry])
                                let link = createBinLink(entry, relPath, packageName)
                                match (link) {
                                    case Some(l) => {
                                        result.links.append(l)
                                        result.installed.append(entry)
                                    }
                                    case None => result.failed.append(entry)
                                }
                            }
                        }
                    }
                    case None => ()
                }
            }
        }

        // 执行链接创建
        if (!dryRun) {
            for (link in result.links) {
                let success = performBinLink(link)
                if (!success) {
                    result.failed.append(link.binName)
                    result.installed.remove(link.binName)
                }
            }
        }

        // 将链接添加到全局列表
        for (link in result.links) {
            links.append(link)
        }

        return result
    }

    /// 创建 BinLink 对象
    // 严格翻译自: src/install/PackageInstaller.zig 中 bin link 创建
    private func createBinLink(binName: String, binSource: String, packageName: String): ?BinLink {
        let link = BinLink(binName, binSource, packageName)
        link.linkPath = Path.join([binDirPath, binName])
        link.sourceAbsPath = Path.join([nodeModulesPath, packageName, binSource])
        return Some(link)
    }

    /// 执行 bin 链接
    // 严格翻译自: src/install/PackageInstaller.zig 中 symlink bin
    private func performBinLink(link: BinLink): Bool {
        // 检查源文件是否存在
        if (!BaoFile.exists(link.sourceAbsPath)) {
            return false
        }

        // 移除旧的链接
        if (BaoFile.exists(link.linkPath)) {
            BaoFile.remove(link.linkPath)
        }

        // 创建符号链接
        let os = Sys.osName()
        if (os.startsWith("Win")) {
            // Windows: 创建 .cmd shim 文件
            return createWindowsShim(link)
        } else {
            // POSIX: 创建符号链接
            let success = BaoFile.createSymlink(link.sourceAbsPath, link.linkPath)
            if (success) {
                // 确保源文件可执行
                BaoFile.setExecutable(link.sourceAbsPath, true)
            }
            return success
        }
    }

    /// 创建 Windows .cmd shim
    // 严格翻译自: src/install/PackageInstaller.zig Windows shim
    private func createWindowsShim(link: BinLink): Bool {
        let shimContent = "@ECHO off\r\n" +
            "GOTO start\r\n" +
            ":start\r\n" +
            "@SETLOCAL\r\n" +
            "@SET PATHEXT=%PATHEXT:;.JS;=;%\r\n" +
            "\"${link.sourceAbsPath.replace("/", "\\")}\" %*\r\n"

        let cmdPath = link.linkPath + ".cmd"
        BaoFile.writeAllText(cmdPath, shimContent)

        // 也创建不带 .cmd 的符号链接
        BaoFile.createSymlink(link.sourceAbsPath, link.linkPath)

        return true
    }

    /// 从包名提取 bin 名
    // 严格翻译自: src/install/bin.zig 中的名称处理
    private func packageNameToBinName(packageName: String): String {
        // @org/package -> package
        if (packageName.startsWith("@")) {
            let slashIdx = packageName.indexOf("/")
            match (slashIdx) {
                case Some(idx) => return packageName.substring(idx + 1)
                case None => return packageName
            }
        }
        return packageName
    }

    /// 移除包的所有 bin 链接
    // 严格翻译自: src/install/PackageInstaller.zig 中的 bin 清理
    public func removeBin(packageName: String): Unit {
        let toRemove = ArrayList<String>()
        for (link in links) {
            if (link.packageName == packageName) {
                toRemove.append(link.binName)
            }
        }
        for (binName in toRemove) {
            let linkPath = Path.join([binDirPath, binName])
            if (BaoFile.exists(linkPath)) {
                BaoFile.remove(linkPath)
            }
            // Windows .cmd
            let cmdPath = linkPath + ".cmd"
            if (BaoFile.exists(cmdPath)) {
                BaoFile.remove(cmdPath)
            }
        }
        // 从列表中移除
        links.removeAllWhere({ l => l.packageName == packageName })
    }

    /// 列出所有已安装的 bin
    public func listBins(): ArrayList<String> {
        let result = ArrayList<String>()
        let entries = BaoFile.readdir(binDirPath)
        for (entry in entries) {
            if (entry == "." || entry == "..") { continue }
            // 跳过 .cmd 文件
            if (!entry.endsWith(".cmd")) {
                result.append(entry)
            }
        }
        return result
    }

    /// 获取 bin 路径
    public func getBinPath(binName: String): ?String {
        let path = Path.join([binDirPath, binName])
        if (BaoFile.exists(path)) {
            return Some(path)
        }
        return None
    }

    /// 安装全局 bin 链接
    // 严格翻译自: src/install/PackageInstaller.zig global bin
    public func installGlobalBin(packageName: String, pkgJson: PackageJson, globalBinDir: String): BinInstallResult {
        let result = BinInstallResult()
        let bin = pkgJson.bin

        match (bin.tag) {
            case BinTag.None => return result
            case BinTag.File => {
                match (bin.filePath) {
                    case Some(path) => {
                        let binName = packageNameToBinName(packageName)
                        let sourcePath = Path.join([globalBinDir, "..", "lib", "node_modules", packageName, path])
                        let linkPath = Path.join([globalBinDir, binName])
                        BaoFile.createSymlink(sourcePath, linkPath)
                        result.installed.append(binName)
                    }
                    case None => ()
                }
            }
            case BinTag.NamedFile => {
                let binName = bin.name ?? packageName
                let binSource = bin.namedPath ?? ""
                if (!binName.isEmpty() && !binSource.isEmpty()) {
                    let sourcePath = Path.join([globalBinDir, "..", "lib", "node_modules", packageName, binSource])
                    let linkPath = Path.join([globalBinDir, binName])
                    BaoFile.createSymlink(sourcePath, linkPath)
                    result.installed.append(binName)
                }
            }
            case BinTag.Map => {
                for (entry in bin.binMap.entries()) {
                    let sourcePath = Path.join([globalBinDir, "..", "lib", "node_modules", packageName, entry.value])
                    let linkPath = Path.join([globalBinDir, entry.key])
                    BaoFile.createSymlink(sourcePath, linkPath)
                    result.installed.append(entry.key)
                }
            }
            case BinTag.Dir => {
                // 全局安装中不太常见
            }
        }
        return result
    }

    /// 获取链接数
    public func getLinkCount(): Int64 {
        return links.size
    }

    /// 获取所有链接
    public func getLinks(): ArrayList<BinLink> {
        return links
    }
}

/// Bin 安装结果
public class BinInstallResult {
    /// 成功安装的 bin 名称
    public var installed: ArrayList<String>
    /// 失败的 bin 名称
    public var failed: ArrayList<String>
    /// 创建的链接详情
    public var links: ArrayList<BinLink>

    public init() {
        installed = ArrayList<String>()
        failed = ArrayList<String>()
        links = ArrayList<BinLink>()
    }

    public func hasErrors(): Bool {
        return failed.size > 0
    }
}

/// PackageJson 引用 (避免循环依赖, 使用简化的 bin 字段)
public class PackageJson {
    public var bin: PackageBin

    public init() {
        bin = PackageBin()
    }
}

/// Bin 字段
public class PackageBin {
    public var tag: BinTag
    public var filePath: ?String
    public var name: ?String
    public var namedPath: ?String
    public var dirPath: ?String
    public var binMap: HashMap<String, String>

    public init() {
        tag = BinTag.None
        filePath = None
        name = None
        namedPath = None
        dirPath = None
        binMap = HashMap<String, String>()
    }
}

/// Bin 类型
public enum BinTag {
    | None
    | File
    | NamedFile
    | Dir
    | Map
}
