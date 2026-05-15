// 严格翻译自: src/cli/test/Scanner.zig
package bao_cli.test

import bao_core.*

// ============================================================================
// Scanner — 测试文件扫描器
// 严格翻译自: src/cli/test/Scanner.zig - Scanner struct
// ============================================================================

/// 测试名称后缀
/// 对应 Bun: Scanner.test_name_suffixes
public let TEST_NAME_SUFFIXES: Array<String> = [
    ".test",
    "_test",
    ".spec",
    "_spec",
]

/// 测试文件扫描器
/// 对应 Bun: Scanner
public class Scanner {
    /// 排除名称列表 (内存借用)
    public var exclusionNames: ArrayList<String>

    /// 过滤名称列表 (为空时不应用过滤器)
    /// "test" 后缀在遍历目录时始终应用
    public var filterNames: ArrayList<String>

    /// 路径忽略 glob 模式列表 (相对于项目根目录匹配)
    public var pathIgnorePatterns: ArrayList<String>

    /// 待扫描目录队列
    private var dirsToScan: Fifo<ScanEntry>

    /// 找到的测试文件路径列表
    public var testFiles: ArrayList<String>

    /// 文件系统引用
    private var fs: FileSystem

    /// 选项引用
    private var options: BundleOptions

    /// 是否已迭代
    private var hasIterated: Bool

    /// 搜索计数
    public var searchCount: Int64

    public init(
        allocator: Allocator,
        transpiler: Transpiler,
        initialResultsCapacity: Int64
    ) {
        exclusionNames = ArrayList<String>()
        filterNames = ArrayList<String>()
        pathIgnorePatterns = ArrayList<String>()
        dirsToScan = Fifo<ScanEntry>(allocator)
        testFiles = ArrayList<String>(initialResultsCapacity)
        fs = transpiler.fs
        options = transpiler.options
        hasIterated = false
        searchCount = 0
    }

    /// 释放资源
    public func deinit(): Unit {
        testFiles.clear()
        dirsToScan.deinit()
    }

    /// 取出找到的测试文件列表
    public func takeFoundTestFiles(): ArrayList<String> {
        let result = testFiles
        testFiles = ArrayList<String>()
        return result
    }

    /// 扫描指定路径
    /// 对应 Bun: Scanner.scan()
    public func scan(pathLiteral: String): Unit {
        let path = Path.join(fs.topLevelDir, pathLiteral)

        let root = fs.readDirectoryWithName(path, None)

        if (root.isErr) {
            when (root.error) {
                case "NotDir" | "ENOTDIR" => {
                    if (isTestFile(path)) {
                        testFiles.append(path)
                    }
                }
                case "ENOENT" => throw ScannerError.DoesNotExist
                else => {}
            }
            return
        }

        // 用户输入 "." 且已扫描
        if (!hasIterated) {
            if (root.entries != None) {
                for (entry in root.entries!!) {
                    next(entry, root.fd)
                }
            }
        }

        // 处理待扫描目录
        while (dirsToScan.readItem() != None) {
            let entry = dirsToScan.readItem()!!
            let childPath = Path.join(entry.dirPath, entry.name)
            let childDir = BaoFile.openDir(childPath)
            if (childDir != None) {
                let absPath = childPath
                readDirWithName(absPath, childDir)
            }
        }
    }

    /// 读取目录
    private func readDirWithName(name: String, handle: ?FileDescriptor): ?DirectoryResult {
        return fs.readDirectoryWithIterator(name, handle, 0, true, this)
    }

    /// 判断文件名是否可能是测试文件
    /// 对应 Bun: Scanner.couldBeTestFile()
    public func couldBeTestFile(name: String, needsTestSuffix: Bool): Bool {
        let extname = Path.extension(name)
        if (extname.length == 0 || !options.loader(extname).isJavaScriptLike()) {
            return false
        }
        if (!needsTestSuffix) {
            return true
        }
        let nameWithoutExtension = name.substring(0, name.length - extname.length)
        for (suffix in TEST_NAME_SUFFIXES) {
            if (nameWithoutExtension.endsWith(suffix)) {
                return true
            }
        }
        return false
    }

    /// 绝对路径是否匹配过滤器
    /// 对应 Bun: Scanner.doesAbsolutePathMatchFilter()
    public func doesAbsolutePathMatchFilter(name: String): Bool {
        if (filterNames.size == 0) {
            return true
        }
        for (filterName in filterNames) {
            if (name.startsWith(filterName)) {
                return true
            }
        }
        return false
    }

    /// 路径是否匹配过滤器
    /// 对应 Bun: Scanner.doesPathMatchFilter()
    public func doesPathMatchFilter(name: String): Bool {
        if (filterNames.size == 0) {
            return true
        }
        for (filterName in filterNames) {
            if (name.contains(filterName)) {
                return true
            }
        }
        return false
    }

    /// 检查路径是否匹配任何忽略模式
    /// 对应 Bun: Scanner.matchesPathIgnorePattern()
    public func matchesPathIgnorePattern(absPath: String): Bool {
        if (pathIgnorePatterns.size == 0) {
            return false
        }
        let relPath = Path.relative(fs.topLevelDir, absPath)

        // 构建 relPath + '/' 一次
        var relWithSlash: ?String = None
        if (relPath.length > 0 && relPath[relPath.length - 1] != '/') {
            relWithSlash = relPath + "/"
        }

        for (pattern in pathIgnorePatterns) {
            if (Glob.match(pattern, relPath).matches()) {
                return true
            }
            if (relWithSlash != None && pattern.contains("**")) {
                if (Glob.match(pattern, relWithSlash!!).matches()) {
                    return true
                }
            }
        }
        return false
    }

    /// 判断文件是否为测试文件
    /// 对应 Bun: Scanner.isTestFile()
    public func isTestFile(name: String): Bool {
        return couldBeTestFile(name, false) && doesPathMatchFilter(name) && !matchesPathIgnorePattern(name)
    }

    /// 处理目录迭代中的下一个条目
    /// 对应 Bun: Scanner.next()
    public func next(entry: FileSystemEntry, fd: FileDescriptor): Unit {
        let name = entry.baseLowercase()
        hasIterated = true

        when (entry.kind) {
            case EntryKind.dir => {
                // 跳过隐藏目录和 node_modules
                if ((name.length > 0 && name[0] == '.') || name == "node_modules") {
                    return
                }

                // 检查排除列表
                for (excludeName in exclusionNames) {
                    if (excludeName == name) {
                        return
                    }
                }

                // 提前修剪被忽略的目录树
                if (pathIgnorePatterns.size > 0) {
                    let dirPath = Path.join(entry.dir, entry.base())
                    if (matchesPathIgnorePattern(dirPath)) {
                        return
                    }
                }

                searchCount += 1
                dirsToScan.writeItem(ScanEntry(fd, entry.dir, entry.base()))
            }
            case EntryKind.file => {
                // 已经处理过
                if (!entry.absPath.isEmpty()) {
                    return
                }

                searchCount += 1
                if (!couldBeTestFile(name, true)) {
                    return
                }

                let path = Path.join(entry.dir, entry.base())

                if (!doesAbsolutePathMatchFilter(path)) {
                    let relPath = Path.relative(fs.topLevelDir, path)
                    if (!doesPathMatchFilter(relPath)) {
                        return
                    }
                }

                if (matchesPathIgnorePattern(path)) {
                    return
                }

                entry.absPath = path
                testFiles.append(path)
            }
        }
    }
}

/// 扫描条目
public class ScanEntry {
    public var relativeDir: FileDescriptor
    public var dirPath: String
    public var name: String

    public init(relativeDir: FileDescriptor, dirPath: String, name: String) {
        this.relativeDir = relativeDir
        this.dirPath = dirPath
        this.name = name
    }
}

/// 扫描器错误
public enum ScannerError {
    | DoesNotExist
    | OutOfMemory
}
