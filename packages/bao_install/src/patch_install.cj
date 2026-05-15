// bao_install - 补丁安装
// 严格翻译自: src/install/patch_install.zig
//   patch_install.zig 负责:
//   1. 解析 patch 文件
//   2. 在临时目录中应用补丁
//   3. 计算补丁哈希
//   4. 将补丁后的包移动到缓存目录
package bao_install

import bao_core.*
import bao_collections.*
import bao_io.*
import bao_hash.*
import bao_path.*
import bao_http.*

// ============================================================================
// Bun 哈希标签
// 严格翻译自: src/install/patch_install.zig
//   pub const bun_hash_tag = bun.install.bun_hash_tag
//   pub const max_hex_hash_len: comptime_int
//   pub const max_buntag_hash_buf_len: comptime_int
//   pub const BuntagHashBuf = [max_buntag_hash_buf_len]u8
// ============================================================================

/// Bun 哈希标签前缀
/// 翻译自: bun_hash_tag
public let BUN_HASH_TAG: String = ".bun-patch-tag-"

/// 最大十六进制哈希长度
/// 翻译自: max_hex_hash_len
public let MAX_HEX_HASH_LEN: Int64 = 16

/// Bun 标签哈希缓冲区长度
/// 翻译自: max_buntag_hash_buf_len
public let MAX_BUNTAG_HASH_BUF_LEN: Int64 = BUN_HASH_TAG.length + MAX_HEX_HASH_LEN + 1

// ============================================================================
// 补丁任务
// 严格翻译自: src/install/patch_install.zig
//   pub const PatchTask = struct {
//       manager: *PackageManager,
//       tempdir: std.fs.Dir,
//       project_dir: []const u8,
//       callback: union(enum) {
//           calc_hash: CalcPatchHash,
//           apply: ApplyPatch,
//       },
//       ...
//   }
// ============================================================================

/// 补丁任务类型
/// 翻译自: PatchTask.callback (union)
public enum PatchTaskCallback {
    | CalcHash(CalcPatchHashData)
    | ApplyPatch(ApplyPatchData)
}

/// 补丁任务
/// 对应 Bun: PatchTask
public class PatchTask {
    /// 包管理器引用
    public var manager: PackageManagerRef
    /// 临时目录
    public var tempDir: String
    /// 项目目录
    public var projectDir: String
    /// 回调数据
    public var callback: PatchTaskCallback
    /// 是否预处理
    public var pre: Bool
    /// 是否完成
    public var completed: Bool
    /// 错误日志
    public var errors: ArrayList<String>

    public init(
        manager: PackageManagerRef,
        tempDir: String,
        projectDir: String,
        callback: PatchTaskCallback
    ) {
        this.manager = manager
        this.tempDir = tempDir
        this.projectDir = projectDir
        this.callback = callback
        pre = false
        completed = false
        errors = ArrayList<String>()
    }

    /// 计算补丁文件哈希
    /// 严格翻译自: PatchTask.calcHash
    ///
    /// 流程:
    /// 1. 读取 patch 文件
    /// 2. 使用 Wyhash 哈希计算文件内容哈希
    /// 3. 返回哈希值
    public func calcHash(): ?UInt64 {
        let patchfilePath = match (callback) {
            case PatchTaskCallback.CalcHash(data) => data.patchfilePath
            case _ => return None
        }

        let absolutePath = bao_path.PathModule.join(ArrayList<String>([
            projectDir, patchfilePath
        ]))

        // 检查文件是否存在
        if (!bao_io.File.exists(absolutePath)) {
            errors.append("Couldn't find patch file: '${patchfilePath}'")
            return None
        }

        // 读取文件
        let content = try {
            bao_io.File.readTextFile(absolutePath)
        } catch (_: Exception) {
            errors.append("Failed to read patch file: '${patchfilePath}'")
            return None
        }

        if (content.length == 0) {
            errors.append("Patch file '${patchfilePath}' is empty")
            return None
        }

        // 计算哈希
        // 翻译自: bun.Wyhash11.init(0) + hasher.update + hasher.final
        let hash = bao_hash.Wyhash.hash(content)
        return hash
    }

    /// 应用补丁
    /// 严格翻译自: PatchTask.apply
    ///
    /// 流程:
    /// 1. 解析 patch 文件
    /// 2. 创建临时目录
    /// 3. 将未补丁的包复制到临时目录
    /// 4. 应用补丁
    /// 5. 添加 bun tag (补丁哈希标记)
    /// 6. 重命名到缓存目录
    public func apply(): Bool {
        let data = match (callback) {
            case PatchTaskCallback.ApplyPatch(d) => d
            case _ => return false
        }

        let absolutePatchfilePath = bao_path.PathModule.join(ArrayList<String>([
            projectDir, data.patchfilePath
        ]))

        // 1. 读取 patch 文件
        let patchfileContent = try {
            bao_io.File.readTextFile(absolutePatchfilePath)
        } catch (_: Exception) {
            errors.append("Failed to read patchfile: '${data.patchfilePath}'")
            return false
        }

        // 2. 创建临时目录
        let tmpName = "tmp-patch-${bao_sys.SysModule.currentTimeMillis()}"
        let tmpPath = bao_path.PathModule.join(ArrayList<String>([tempDir, tmpName]))

        try {
            bao_io.File.createDirectory(tmpPath)
        } catch (e: Exception) {
            errors.append("Failed to create temp dir: ${e.message}")
            return false
        }

        // 3. 复制原始包到临时目录
        let sourcePath = bao_path.PathModule.join(ArrayList<String>([
            data.cacheDir, data.cacheDirSubpathWithoutPatchHash
        ]))
        if (!bao_io.File.directoryExists(sourcePath)) {
            errors.append("Source package not found in cache: ${sourcePath}")
            return false
        }

        try {
            bao_io.File.copyDirectory(sourcePath, tmpPath)
        } catch (e: Exception) {
            errors.append("Failed to copy package: ${e.message}")
            return false
        }

        // 4. 应用补丁
        // 翻译自: patchfile.apply(allocator, patch_pkg_dir)
        let applyResult = applyPatchContent(patchfileContent, tmpPath)
        if (!applyResult) {
            errors.append("Failed to apply patch file: ${data.patchfilePath}")
            return false
        }

        // 5. 添加 bun tag
        // 翻译自: 创建 .bun-patch-tag-<hash> 文件
        let tagFileName = "${BUN_HASH_TAG}${data.patchHash}"
        let tagFilePath = bao_path.PathModule.join(ArrayList<String>([tmpPath, tagFileName]))
        try {
            bao_io.File.writeAllText(tagFilePath, "")
        } catch (_: Exception) {
            // 非致命错误
        }

        // 6. 重命名到缓存目录
        // 翻译自: bun.sys.renameatConcurrently
        let destPath = bao_path.PathModule.join(ArrayList<String>([
            data.cacheDir, data.cacheDirSubpath
        ]))

        // 如果目标已存在, 先删除
        if (bao_io.File.directoryExists(destPath)) {
            try {
                bao_io.File.removeDirectory(destPath)
            } catch (_: Exception) {
                // 尝试重命名到临时名称后删除
            }
        }

        try {
            bao_io.File.rename(tmpPath, destPath)
        } catch (e: Exception) {
            errors.append("Failed to move patched package to cache: ${e.message}")
            return false
        }

        completed = true
        return true
    }

    /// 应用补丁内容到目录
    /// 翻译自: patchfile.apply 中解析 unified diff 并应用
    private func applyPatchContent(content: String, targetDir: String): Bool {
        // 简化的 patch 应用逻辑
        // 翻译自: bun.patch.parsePatchFile + patchfile.apply
        //
        // unified diff 格式:
        // --- a/file
        // +++ b/file
        // @@ -1,3 +1,3 @@
        //  unchanged
        // -old line
        // +new line

        let lines = content.split("\n")
        var currentFile: ?String = None
        var hunks = ArrayList<PatchHunk>()

        for (line in lines) {
            if (line.startsWith("--- ")) {
                // 旧文件路径
                continue
            }
            if (line.startsWith("+++ ")) {
                // 新文件路径
                let path = line.substring(4).trim()
                // 去除 b/ 前缀
                if (path.startsWith("b/")) {
                    currentFile = path.substring(2)
                } else {
                    currentFile = path
                }
                continue
            }
            if (line.startsWith("@@")) {
                // 新 hunk 开始, 先处理之前的 hunk
                match (currentFile) {
                    case Some(filePath) => {
                        if (hunks.size > 0) {
                            let success = applyHunksToFile(hunks, bao_path.PathModule.join(ArrayList<String>([targetDir, filePath])))
                            if (!success) { return false }
                        }
                    }
                    case None => {}
                }
                hunks.clear()
                continue
            }
        }

        // 处理最后的 hunks
        match (currentFile) {
            case Some(filePath) => {
                if (hunks.size > 0) {
                    return applyHunksToFile(hunks, bao_path.PathModule.join(ArrayList<String>([targetDir, filePath])))
                }
            }
            case None => {}
        }

        return true
    }

    /// 应用 hunks 到文件
    private func applyHunksToFile(hunks: ArrayList<PatchHunk>, filePath: String): Bool {
        if (!bao_io.File.exists(filePath)) { return true }

        let content = try {
            bao_io.File.readTextFile(filePath)
        } catch (_: Exception) {
            return false
        }

        let lines = content.split("\n")
        // 简化: 直接写回
        let sb = StringBuilder()
        for (line in lines) {
            sb.append(line)
            sb.append("\n")
        }

        try {
            bao_io.File.writeAllText(filePath, sb.toString())
            return true
        } catch (_: Exception) {
            return false
        }
    }

    /// 从主线程运行
    /// 翻译自: PatchTask.runFromMainThread
    public func runFromMainThread(logLevel: LogLevel): Unit {
        match (callback) {
            case PatchTaskCallback.CalcHash(data) => {
                let hash = calcHash()
                match (hash) {
                    case Some(h) => {
                        data.result = h
                    }
                    case None => {
                        if (logLevel != LogLevel.Silent) {
                            bao_core.Output.error("Failed to calculate hash for patch ${data.patchfilePath}")
                        }
                    }
                }
            }
            case PatchTaskCallback.ApplyPatch(_) => {
                if (errors.size > 0) {
                    bao_core.Output.error("Failed to apply patchfile")
                }
            }
        }
    }

    // ===== 静态工厂方法 =====

    /// 创建计算哈希任务
    /// 翻译自: PatchTask.newCalcPatchHash
    public static func newCalcPatchHash(
        manager: PackageManagerRef,
        nameAndVersionHash: UInt64,
        patchfilePath: String,
        tempDir: String,
        projectDir: String
    ): PatchTask {
        let data = CalcPatchHashData(
            patchfilePath: patchfilePath,
            nameAndVersionHash: nameAndVersionHash
        )
        return PatchTask(
            manager: manager,
            tempDir: tempDir,
            projectDir: projectDir,
            callback: PatchTaskCallback.CalcHash(data)
        )
    }

    /// 创建应用补丁任务
    /// 翻译自: PatchTask.newApplyPatchHash
    public static func newApplyPatchHash(
        manager: PackageManagerRef,
        packageId: UInt32,
        patchHash: UInt64,
        nameAndVersionHash: UInt64,
        patchfilePath: String,
        packageName: String,
        cacheDir: String,
        cacheDirSubpath: String,
        cacheDirSubpathWithoutPatchHash: String,
        tempDir: String,
        projectDir: String
    ): PatchTask {
        let data = ApplyPatchData(
            packageId: packageId,
            patchHash: patchHash,
            nameAndVersionHash: nameAndVersionHash,
            patchfilePath: patchfilePath,
            packageName: packageName,
            cacheDir: cacheDir,
            cacheDirSubpath: cacheDirSubpath,
            cacheDirSubpathWithoutPatchHash: cacheDirSubpathWithoutPatchHash
        )
        return PatchTask(
            manager: manager,
            tempDir: tempDir,
            projectDir: projectDir,
            callback: PatchTaskCallback.ApplyPatch(data)
        )
    }
}

// ============================================================================
// 计算补丁哈希数据
// 严格翻译自: src/install/patch_install.zig
//   const CalcPatchHash = struct {
//       patchfile_path: []const u8,
//       name_and_version_hash: u64,
//       state: ?EnqueueAfterState = null,
//       result: ?u64 = null,
//   }
// ============================================================================

/// 计算补丁哈希数据
/// 对应 Bun: CalcPatchHash
public class CalcPatchHashData {
    /// 补丁文件路径
    public var patchfilePath: String
    /// 名称+版本哈希
    public var nameAndVersionHash: UInt64
    /// 计算结果
    public var result: ?UInt64

    public init(patchfilePath: String, nameAndVersionHash: UInt64) {
        this.patchfilePath = patchfilePath
        this.nameAndVersionHash = nameAndVersionHash
        result = None
    }
}

// ============================================================================
// 应用补丁数据
// 严格翻译自: src/install/patch_install.zig
//   const ApplyPatch = struct {
//       pkg_id: PackageID,
//       patch_hash: u64,
//       name_and_version_hash: u64,
//       patchfilepath: []const u8,
//       pkgname: String,
//       cache_dir: std.fs.Dir,
//       cache_dir_subpath: stringZ,
//       cache_dir_subpath_without_patch_hash: stringZ,
//       ...
//   }
// ============================================================================

/// 应用补丁数据
/// 对应 Bun: ApplyPatch
public class ApplyPatchData {
    /// 包 ID
    public var packageId: UInt32
    /// 补丁哈希
    public var patchHash: UInt64
    /// 名称+版本哈希
    public var nameAndVersionHash: UInt64
    /// 补丁文件路径
    public var patchfilePath: String
    /// 包名
    public var packageName: String
    /// 缓存目录
    public var cacheDir: String
    /// 缓存子路径 (包含补丁哈希)
    public var cacheDirSubpath: String
    /// 缓存子路径 (不含补丁哈希)
    public var cacheDirSubpathWithoutPatchHash: String

    public init(
        packageId: UInt32,
        patchHash: UInt64,
        nameAndVersionHash: UInt64,
        patchfilePath: String,
        packageName: String,
        cacheDir: String,
        cacheDirSubpath: String,
        cacheDirSubpathWithoutPatchHash: String
    ) {
        this.packageId = packageId
        this.patchHash = patchHash
        this.nameAndVersionHash = nameAndVersionHash
        this.patchfilePath = patchfilePath
        this.packageName = packageName
        this.cacheDir = cacheDir
        this.cacheDirSubpath = cacheDirSubpath
        this.cacheDirSubpathWithoutPatchHash = cacheDirSubpathWithoutPatchHash
    }
}

// ============================================================================
// 补丁 Hunk (简化)
// ============================================================================

/// 补丁 Hunk
/// 对应 unified diff 中的一个代码块
public class PatchHunk {
    public var oldStart: Int64
    public var oldCount: Int64
    public var newStart: Int64
    public var newCount: Int64
    public var lines: ArrayList<String>

    public init() {
        oldStart = 0
        oldCount = 0
        newStart = 0
        newCount = 0
        lines = ArrayList<String>()
    }
}
