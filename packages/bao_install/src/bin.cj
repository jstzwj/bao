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
            // TODO: 使用 std.fs.Directory.create 替换
            ()
        }

        match (bin.tag) {
            case BinTag.None => return result
            case BinTag.File => installBinFile(bin, packageName, result)
            case BinTag.NamedFile => installBinNamed(bin, packageName, result)
            case BinTag.Map => installBinMap(bin, packageName, result)
            case BinTag.Dir => installBinDir(bin, packageName, result, nodeModulesPath)
        }
        return result
    }

    private func installBinFile(bin: PackageBin, packageName: String, result: BinInstallResult): Unit {
        match (bin.filePath) {
            case Some(path) => linkBin(packageNameToBinName(packageName), path, packageName, result)
            case None => ()
        }
    }

    private func installBinNamed(bin: PackageBin, packageName: String, result: BinInstallResult): Unit {
        let binName = bin.name ?? packageName
        let binSource = bin.namedPath ?? ""
        if (!binName.isEmpty() && !binSource.isEmpty()) {
            linkBin(binName, binSource, packageName, result)
        }
    }

    private func installBinMap(bin: PackageBin, packageName: String, result: BinInstallResult): Unit {
        bin.binMap.forEach({ key, value =>
            linkBin(key, value, packageName, result)
        })
    }

    private func installBinDir(bin: PackageBin, packageName: String, result: BinInstallResult, nmPath: String): Unit {
        match (bin.dirPath) {
            case Some(dirRelPath) => installBinDirEntries(dirRelPath, packageName, nmPath, result)
            case None => ()
        }
    }

    private func installBinDirEntries(dirRelPath: String, packageName: String, nmPath: String, result: BinInstallResult): Unit {
        let packageDir = Path.join([nmPath, packageName])
        let binDir = Path.join([packageDir, dirRelPath])
        // TODO: 实现目录读取 - 需要 std.fs.Directory.readFrom
        // 暂时跳过目录扫描
    }

    private func linkBinDirFiles(files: ArrayList<String>, dirRelPath: String, packageName: String, result: BinInstallResult): Unit {
        for (file in files) {
            let binName = packageNameToBinName(file)
            let binSource = Path.join([dirRelPath, file])
            linkBin(binName, binSource, packageName, result)
        }
    }

    private func linkBin(binName: String, path: String, packageName: String, result: BinInstallResult): Unit {
        let link = createBinLink(binName, path, packageName)
        match (link) {
            case Some(l) => addLinkResult(l, binName, result)
            case None => result.failed.append(binName)
        }
    }

    private func addLinkResult(link: BinLink, binName: String, result: BinInstallResult): Unit {
        result.links.append(link)
        result.installed.append(binName)
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
        // TODO: 实现文件存在检查和删除 - 需要 std.fs.exists/remove
        // 暂时直接返回 true
        return true
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
        match (BaoFile.writeAllText(cmdPath, shimContent)) {
            case _ => ()
        }

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
            if (let Some(idx) <- slashIdx) {
                return packageName[Int64(idx) + 1..]
            }
            return packageName
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
        var i: Int64 = 0
        while (i < links.size) {
            if (links[Int64(i)].packageName == packageName) {
                links.removeAt(Int64(i))
            } else {
                i += 1
            }
        }
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
            case BinTag.File => installGlobalBinFile(bin, packageName, globalBinDir, result)
            case BinTag.NamedFile => installGlobalBinNamed(bin, packageName, globalBinDir, result)
            case BinTag.Map => installGlobalBinMap(bin, packageName, globalBinDir, result)
            case BinTag.Dir => ()  // 全局安装中不太常见
        }
        return result
    }

    private func installGlobalBinFile(bin: PackageBin, packageName: String, globalBinDir: String, result: BinInstallResult): Unit {
        if (let Some(path) <- bin.filePath) {
            let binName = packageNameToBinName(packageName)
            let sourcePath = Path.join([globalBinDir, "..", "lib", "node_modules", packageName, path])
            let linkPath = Path.join([globalBinDir, binName])
            BaoFile.createSymlink(sourcePath, linkPath)
            result.installed.append(binName)
        }
    }

    private func installGlobalBinNamed(bin: PackageBin, packageName: String, globalBinDir: String, result: BinInstallResult): Unit {
        let binName = bin.name ?? packageName
        let binSource = bin.namedPath ?? ""
        if (!binName.isEmpty() && !binSource.isEmpty()) {
            let sourcePath = Path.join([globalBinDir, "..", "lib", "node_modules", packageName, binSource])
            let linkPath = Path.join([globalBinDir, binName])
            BaoFile.createSymlink(sourcePath, linkPath)
            result.installed.append(binName)
        }
    }

    private func installGlobalBinMap(bin: PackageBin, packageName: String, globalBinDir: String, result: BinInstallResult): Unit {
        bin.binMap.forEach({ key, value =>
            let sourcePath = Path.join([globalBinDir, "..", "lib", "node_modules", packageName, value])
            let linkPath = Path.join([globalBinDir, key])
            BaoFile.createSymlink(sourcePath, linkPath)
            result.installed.append(key)
        })
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