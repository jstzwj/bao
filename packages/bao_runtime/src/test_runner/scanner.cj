// 严格翻译自: src/runtime/cli/test/Scanner.zig
//   Test file scanner: discovers test files by traversing directories.
package bao_runtime.test_runner

import bao_core.*
import bao_collections.*
import bao_path.Path as BaoPath
import bao_io.BaoFile

// ============================================================================
// Scanner — 测试文件扫描器
// 严格翻译自: src/runtime/cli/test/Scanner.zig - Scanner struct
//
// 扫描目录树查找测试文件:
//   - 排除以 '.' 开头的目录和 node_modules
//   - 应用排除名称列表 (exclusion_names)
//   - 应用过滤器 (filter_names) 和路径忽略模式 (path_ignore_patterns)
//   - 识别测试文件后缀 (.test, _test, .spec, _spec)
// ============================================================================

/// 扫描条目 — 目录扫描队列中的条目
/// 对应 Bun: ScanEntry struct
public class ScanEntry {
    /// 相对目录文件描述符
    public var relativeDir: Int64
    /// 目录路径
    public var dirPath: String
    /// 名称
    public var name: String

    public init(relativeDir: Int64, dirPath: String, name: String) {
        this.relativeDir = relativeDir
        this.dirPath = dirPath
        this.name = name
    }
}

/// 测试名称后缀
/// 对应 Bun: Scanner.test_name_suffixes
public let TEST_NAME_SUFFIXES: Array<String> = [
    ".test",
    "_test",
    ".spec",
    "_spec"
]

/// 测试文件扫描器
/// 对应 Bun: Scanner struct
public class Scanner {
    /// 排除的目录/文件名称列表
    /// 翻译自: exclusion_names: []const []const u8 = &.{}
    public var exclusionNames: ArrayList<String>

    /// 过滤器名称列表 (空时不过滤)
    /// 翻译自: filter_names: []const []const u8 = &.{}
    public var filterNames: ArrayList<String>

    /// 路径忽略 glob 模式列表
    /// 翻译自: path_ignore_patterns: []const []const u8 = &.{}
    public var pathIgnorePatterns: ArrayList<String>

    /// 待扫描的目录队列
    /// 翻译自: dirs_to_scan: Fifo
    public var dirsToScan: ArrayList<ScanEntry>

    /// 发现的测试文件路径
    /// 翻译自: test_files: std.ArrayListUnmanaged(bun.PathString)
    public var testFiles: ArrayList<String>

    /// 文件系统
    /// 翻译自: fs: *FileSystem
    public var fs: FileSystem

    /// Bundle 选项
    /// 翻译自: options: *BundleOptions
    public var options: BundleOptions

    /// 是否已迭代
    /// 翻译自: has_iterated: bool = false
    public var hasIterated: Bool

    /// 搜索计数
    /// 翻译自: search_count: usize = 0
    public var searchCount: Int64

    /// 项目根目录
    public var topLevelDir: String

    public init(fs: FileSystem, options: BundleOptions, topLevelDir: String) {
        exclusionNames = ArrayList<String>()
        filterNames = ArrayList<String>()
        pathIgnorePatterns = ArrayList<String>()
        dirsToScan = ArrayList<ScanEntry>()
        testFiles = ArrayList<String>()
        this.fs = fs
        this.options = options
        this.topLevelDir = topLevelDir
        hasIterated = false
        searchCount = Int64(0)
    }

    /// 释放资源
    /// 对应 Bun: pub fn deinit(this: *Scanner) void
    public func deinit(): Unit {
        testFiles.clear()
        dirsToScan.clear()
    }

    /// 取出发现的测试文件列表
    /// 对应 Bun: pub fn takeFoundTestFiles(this: *Scanner) ![]bun.PathString
    public func takeFoundTestFiles(): ArrayList<String> {
        let result = testFiles
        testFiles = ArrayList<String>()
        return result
    }

    /// 扫描指定路径
    /// 对应 Bun: pub fn scan(this: *Scanner, path_literal: []const u8) Error!void
    public func scan(pathLiteral: String): Unit {
        let path = BaoPath.join([topLevelDir, pathLiteral])

        // 检查路径是否存在
        if (!BaoFile.exists(path)) {
            return
        }

        // 如果是文件 (不是目录)
        if (!BaoFile.isDirectory(path)) {
            if (isTestFile(path)) {
                testFiles.append(path)
            }
            return
        }

        // 扫描目录内容
        scanDirectory(path)

        // 处理队列中的目录
        while (dirsToScan.size > Int64(0)) {
            let entry = dirsToScan.removeAt(Int64(0))
            let childPath = BaoPath.join([entry.dirPath, entry.name])
            if (BaoFile.isDirectory(childPath)) {
                scanDirectory(childPath)
            }
        }
    }

    /// 扫描单个目录
    private func scanDirectory(dirPath: String): Unit {
        hasIterated = true
        let entries: ArrayList<String> = ArrayList<String>() // TODO: BaoFile.readDir
        for (i in 0..entries.size) {
            // TODO: processEntry(dirPath, entry)
        }
    }

    /// 处理单个目录条目
    /// 对应 Bun: pub fn next(this: *Scanner, entry: *FileSystem.Entry, fd: bun.FD) void
    private func processEntry(dirPath: String, entry: DirEntry): Unit {
        let name = entry.name
        hasIterated = true

        if (entry.isDirectory) {
            // 跳过以 '.' 开头的目录和 node_modules
            // 翻译自: if ((name.len > 0 and name[0] == '.') or strings.eqlComptime(name, "node_modules"))
            if (name.size > Int64(0) && name[Int64(0)] == UInt8(46) || name == "node_modules") {
                return
            }

            // 检查排除列表
            for (excludeName in exclusionNames) {
                if (name == excludeName) {
                    return
                }
            }

            // 检查路径忽略模式
            if (pathIgnorePatterns.size > Int64(0)) {
                let fullPath = BaoPath.join([dirPath, name])
                if (matchesPathIgnorePattern(fullPath)) {
                    return
                }
            }

            searchCount += Int64(1)

            // 加入待扫描队列
            dirsToScan.append(ScanEntry(Int64(0), dirPath, name))
        } else {
            // 文件: 检查是否是测试文件
            searchCount += Int64(1)
            if (!couldBeTestFile(name, true)) {
                return
            }

            let fullPath = BaoPath.join([dirPath, name])

            if (!doesAbsolutePathMatchFilter(fullPath)) {
                let relPath = BaoPath.relative(topLevelDir, fullPath)
                if (!doesPathMatchFilter(relPath)) {
                    return
                }
            }

            if (matchesPathIgnorePattern(fullPath)) {
                return
            }

            testFiles.append(fullPath)
        }
    }

    /// 判断文件名是否可能是测试文件
    /// 对应 Bun: pub fn couldBeTestFile(this, name, comptime needs_test_suffix) bool
    public func couldBeTestFile(name: String, needsTestSuffix: Bool): Bool {
        // 检查扩展名是否是 JS 类型的
        let ext = getExtension(name)
        if (ext.isEmpty() || !isJavaScriptLike(ext)) {
            return false
        }
        if (!needsTestSuffix) {
            return true
        }
        // 检查测试文件后缀
        let nameWithoutExt = name[Int64(0)..(name.size - ext.size)]
        for (suffix in TEST_NAME_SUFFIXES) {
            if (nameWithoutExt.endsWith(suffix)) {
                return true
            }
        }
        return false
    }

    /// 检查绝对路径是否匹配过滤器
    /// 对应 Bun: pub fn doesAbsolutePathMatchFilter(this, name) bool
    public func doesAbsolutePathMatchFilter(name: String): Bool {
        if (filterNames.size == Int64(0)) {
            return true
        }
        for (filterName in filterNames) {
            if (name.startsWith(filterName)) {
                return true
            }
        }
        return false
    }

    /// 检查路径是否匹配过滤器
    /// 对应 Bun: pub fn doesPathMatchFilter(this, name) bool
    public func doesPathMatchFilter(name: String): Bool {
        if (filterNames.size == Int64(0)) {
            return true
        }
        for (filterName in filterNames) {
            if (name.contains(filterName)) {
                return true
            }
        }
        return false
    }

    /// 检查路径是否匹配忽略模式
    /// 对应 Bun: pub fn matchesPathIgnorePattern(this, abs_path) bool
    public func matchesPathIgnorePattern(absPath: String): Bool {
        if (pathIgnorePatterns.size == Int64(0)) {
            return false
        }
        let relPath = BaoPath.relative(topLevelDir, absPath)

        // 构建带斜杠后缀的相对路径
        var relWithSlash: ?String = None
        if (relPath.size > Int64(0) && !relPath.endsWith("/")) {
            relWithSlash = relPath + "/"
        }

        for (pattern in pathIgnorePatterns) {
            if (globMatch(pattern, relPath)) {
                return true
            }
            // 仅对 ** 模式尝试尾部斜杠匹配
            match (relWithSlash) {
                case Some(p) =>
                    if (pattern.contains("**")) {
                        if (globMatch(pattern, p)) {
                            return true
                        }
                    }
                case None => ()
            }
        }
        return false
    }

    /// 判断是否是测试文件 (完整检查)
    /// 对应 Bun: pub fn isTestFile(this, name) bool
    public func isTestFile(name: String): Bool {
        return couldBeTestFile(name, false) && doesPathMatchFilter(name) && !matchesPathIgnorePattern(name)
    }

    // ============================================================================
    // 私有辅助函数
    // ============================================================================

    /// 获取文件扩展名
    private func getExtension(name: String): String {
        let dotIdx = name.lastIndexOf('.')
        if (dotIdx.isNone() || dotIdx.getOrThrow() < Int64(0)) {
            return ""
        }
        return name[dotIdx.getOrThrow()..]
    }

    /// 检查扩展名是否是 JS 类型
    private func isJavaScriptLike(ext: String): Bool {
        return ext == ".js" || ext == ".ts" || ext == ".jsx" || ext == ".tsx" ||
               ext == ".mjs" || ext == ".cjs" || ext == ".mts" || ext == ".cts"
    }

    /// 简单 glob 匹配 (简化实现)
    private func globMatch(pattern: String, path: String): Bool {
        // 简化: 仅支持 * 和 ** 通配符
        if (pattern == "*") {
            return true
        }
        if (pattern == "**") {
            return true
        }
        return path.contains(pattern.replace("*", ""))
    }
}

/// 文件系统 (简化)
/// 对应 Bun: FileSystem
public class FileSystem {}

/// Bundle 选项 (简化)
/// 对应 Bun: BundleOptions
public class BundleOptions {}

/// 目录条目 (简化)
/// 对应 Bun: FileSystem.Entry
public class DirEntry {
    public var name: String
    public var isDirectory: Bool

    public init(name: String, isDirectory: Bool) {
        this.name = name
        this.isDirectory = isDirectory
    }
}
