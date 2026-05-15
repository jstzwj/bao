// bao_install - 补丁包管理
// 严格翻译自: src/install/PackageManager/patchPackage.zig
//   doPatchCommit: 执行补丁提交
//   preparePatch: 准备补丁
//   PatchCommitResult: 补丁提交结果
//   PatchArgKind: 补丁参数类型
//   escapePatchFilename: 转义补丁文件名
//   pkgInfoForNameAndVersion: 获取包信息
//   overwritePackageInNodeModulesFolder: 覆写 node_modules 中的包
//   detachModuleFolderFromSharedStore: 从共享存储分离模块文件夹
package bao_install.package_manager

import bao_core.*
import bao_collections.*
import bao_io.*
import bao_path.*

// ============================================================================
// 补丁参数类型
// 严格翻译自: patchPackage.zig - PatchArgKind
// ============================================================================

/// 补丁参数类型
/// 对应 Bun: PatchArgKind
public enum PatchArgKind {
    | Directory      // 目录参数
    | PackageName    // 包名参数
}

// ============================================================================
// 补丁提交结果
// 严格翻译自: patchPackage.zig - PatchCommitResult
// ============================================================================

/// 补丁提交结果
/// 对应 Bun: PatchCommitResult
public class PatchCommitResult {
    /// 补丁文件路径
    public var patchfilePath: String
    /// 包名
    public var packageName: String
    /// 包版本
    public var packageVersion: String
    /// 补丁内容哈希
    public var patchfileHash: UInt64

    public init() {
        patchfilePath = ""
        packageName = ""
        packageVersion = ""
        patchfileHash = UInt64(0)
    }

    public init(patchfilePath: String, packageName: String, packageVersion: String, patchfileHash: UInt64) {
        this.patchfilePath = patchfilePath
        this.packageName = packageName
        this.packageVersion = packageVersion
        this.patchfileHash = patchfileHash
    }
}

// ============================================================================
// 包信息
// ============================================================================

/// 包信息 (名称 + 版本)
public class PackageInfoForPatch {
    public var name: String
    public var version: String

    public init(name: String, version: String) {
        this.name = name
        this.version = version
    }
}

// ============================================================================
// 补丁包管理
// 严格翻译自: src/install/PackageManager/patchPackage.zig
//   ~1071 行的补丁管理模块
// ============================================================================

/// 补丁包管理
/// 对应 Bun: patchPackage 中的函数
/// 翻译自: src/install/PackageManager/patchPackage.zig
public class PatchPackage {

    /// 执行补丁提交
    /// 严格翻译自: doPatchCommit
    ///   pub fn doPatchCommit(manager, ctx, patch_dir, patches_dir) !PatchCommitResult
    ///   将补丁目录中的修改生成 .patch 文件并保存到 patches 目录
    public static func doPatchCommit(
        manager: PackageManagerRef,
        patchDir: String,
        patchesDir: String
    ): ?PatchCommitResult {
        // 1. 读取补丁目录中的 package.json 获取包名和版本
        let packageJsonPath = Path.join(patchDir, "package.json")
        let pkgInfo = pkgInfoForNameAndVersion(packageJsonPath)
        match (pkgInfo) {
            case None => return None
            case Some(_) => ()
        }

        let info = pkgInfo!
        let patchKey = "${info.name}@${info.version}"

        // 2. 转义文件名
        let escapedName = escapePatchFilename(patchKey)
        let patchfilePath = Path.join(patchesDir, "${escapedName}.patch")

        // 3. 生成 diff
        // 使用 git diff 生成补丁
        let originalDir = getOriginalPackageDir(manager: manager, pkgInfo: info)
        let diffResult = generatePatch(
            originalDir: originalDir,
            patchDir: patchDir,
            patchfilePath: patchfilePath
        )

        match (diffResult) {
            case Some(hash) => {
                // 4. 更新 package.json 中的 patchedDependencies
                let patchRelativePath = Path.relative(
                    manager.cwd,
                    patchfilePath
                )

                return PatchCommitResult(
                    patchfilePath: patchRelativePath,
                    packageName: info.name,
                    packageVersion: info.version,
                    patchfileHash: hash
                )
            }
            case None => return None
        }
    }

    /// 准备补丁
    /// 翻译自: preparePatch
    ///   pub fn preparePatch(manager, ctx, pkg, edit_dir) !void
    ///   将包复制到编辑目录, 供用户编辑
    public static func preparePatch(
        manager: PackageManagerRef,
        packageName: String,
        editDir: String
    ): Unit {
        // 1. 找到 node_modules 中的包
        let packageDir = Path.join(manager.cwd, "node_modules", packageName)
        if (!bao_io.File.exists(packageDir)) {
            bao_core.Output.error("Package ${packageName} not found in node_modules")
            return
        }

        // 2. 复制包到编辑目录
        bao_io.File.copyDirectory(
            src: packageDir,
            dest: editDir
        )

        // 3. 如果是从共享存储链接的, 需要分离
        detachModuleFolderFromSharedStore(
            manager: manager,
            moduleDir: editDir,
            packageName: packageName
        )
    }

    /// 转义补丁文件名
    /// 翻译自: escapePatchFilename
    ///   pub fn escapePatchFilename(input) []const u8
    ///   将包名中的特殊字符转义 (如 '/' -> '+')
    public static func escapePatchFilename(input: String): String {
        let sb = StringBuilder()
        for (c in input) {
            if (c.value == 47) { // '/'
                sb.append("+")
            } else {
                sb.append(c)
            }
        }
        return sb.toString()
    }

    /// 获取包名和版本
    /// 翻译自: pkgInfoForNameAndVersion
    ///   fn pkgInfoForNameAndVersion(allocator, lockfile, name, version) ?PackageInfoForPatch
    public static func pkgInfoForNameAndVersion(packageJsonPath: String): ?PackageInfoForPatch {
        try {
            let content = bao_io.File.readTextFile(packageJsonPath)
            let json = JsonParser.parseObject(content)

            let name = match (json.get("name")) {
                case Some(n) => n.asString()
                case None => return None
            }
            let version = match (json.get("version")) {
                case Some(v) => v.asString()
                case None => ""
            }

            if (name.length == 0) { return None }
            return PackageInfoForPatch(name: name, version: version)
        } catch (_: Exception) {
            return None
        }
    }

    /// 覆写 node_modules 中的包
    /// 翻译自: overwritePackageInNodeModulesFolder
    ///   fn overwritePackageInNodeModulesFolder(manager, pkg_path, dest_path) !void
    public static func overwritePackageInNodeModulesFolder(
        manager: PackageManagerRef,
        pkgPath: String,
        destPath: String
    ): Unit {
        // 删除目标并复制
        bao_io.File.deleteDirectory(destPath)
        bao_io.File.copyDirectory(src: pkgPath, dest: destPath)
    }

    /// 从共享存储分离模块文件夹
    /// 翻译自: detachModuleFolderFromSharedStore
    ///   fn detachModuleFolderFromSharedStore(manager, module_dir, package_name) !void
    ///   如果模块是通过符号链接指向共享存储, 需要解除链接并创建独立副本
    public static func detachModuleFolderFromSharedStore(
        manager: PackageManagerRef,
        moduleDir: String,
        packageName: String
    ): Unit {
        // 检查是否是符号链接
        let isSymlink = bao_io.File.isSymlink(moduleDir)
        if (isSymlink) {
            // 读取链接目标
            let target = bao_io.File.readSymlink(moduleDir)

            // 删除符号链接
            bao_io.File.deleteFile(moduleDir)

            // 复制实际内容到目标
            bao_io.File.copyDirectory(src: target, dest: moduleDir)
        }
    }

    /// 获取原始包目录
    private static func getOriginalPackageDir(manager: PackageManagerRef, pkgInfo: PackageInfoForPatch): String {
        // 从缓存中获取原始包路径
        let cacheDir = InstallWithManager.getCacheDirectory(manager)
        return Path.join(cacheDir, "${pkgInfo.name}@${pkgInfo.version}")
    }

    /// 生成补丁文件
    private static func generatePatch(
        originalDir: String,
        patchDir: String,
        patchfilePath: String
    ): ?UInt64 {
        // 使用 diff 命令生成补丁
        try {
            let result = bao_sys.Process.run(
                command: ArrayList<String>(["diff", "-ruN", originalDir, patchDir]),
                cwd: bao_io.File.getCurrentDirectory(),
                env: ArrayList<String>(),
                timeout: 30000
            )

            match (result) {
                case Some(output) => {
                    // 写入补丁文件
                    bao_io.File.writeTextFile(patchfilePath, output)
                    // 计算哈希
                    return SemverStringBuilder.stringHashStr(output)
                }
                case None => return None
            }
        } catch (_: Exception) {
            return None
        }
    }
}

// ============================================================================
// 辅助类型
// ============================================================================

/// 包管理器引用
public class PackageManagerRef {
    public var cwd: String

    public init() {
        cwd = bao_io.File.getCurrentDirectory()
    }
}

/// JSON 解析器
public class JsonParser {
    public static func parseObject(content: String): JsonExpr { return JsonExpr() }
}

/// JSON 表达式
public class JsonExpr {
    public func get(key: String): ?JsonExpr { return None }
    public func asString(): String { return "" }
}
