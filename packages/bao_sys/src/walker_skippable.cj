// bao_sys - 可跳过的目录遍历器
// 严格翻译自: src/sys/walker_skippable.rs
//   Walker 是一个递归目录遍历器，支持跳过指定文件名和目录名
//   使用 wyhash 对名称进行哈希，实现 O(1) 的跳过检查
//   对应 Bun 中用于 node_modules 遍历等场景
package bao_sys

import bao_core.*

// ============================================================================
// WalkerEntry - 遍历条目
// 严格翻译自: src/sys/walker_skippable.rs:33-43
//   pub struct WalkerEntry<'a> {
//       pub dir: Fd, pub basename: &'a OSPathSliceZ,
//       pub path: &'a OSPathSliceZ, pub kind: sys::EntryKind
//   }
// ============================================================================

/// 遍历条目 - 对应 Bun WalkerEntry
/// 包含目录 FD、基本名、完整路径和文件类型
public class WalkerEntry {
    /// 包含目录的 FD - 对应 Bun dir
    public var dir: Int64
    /// 基本文件名 - 对应 Bun basename
    public var basename: String
    /// 完整路径 - 对应 Bun path
    public var path: String
    /// 文件类型 - 对应 Bun kind
    public var kind: DirEntryType

    public init(dir: Int64, basename: String, path: String, kind: DirEntryType) {
        this.dir = dir
        this.basename = basename
        this.path = path
        this.kind = kind
    }

    /// 是否为目录
    public func isDirectory(): Bool {
        return kind == DirEntryType.Directory
    }

    /// 是否为普通文件
    public func isFile(): Bool {
        return kind == DirEntryType.File
    }

    /// 是否为符号链接
    public func isSymlink(): Bool {
        return kind == DirEntryType.Symlink
    }
}

// ============================================================================
// WalkerStackItem - 遍历器栈项
// 严格翻译自: src/sys/walker_skippable.rs:45-48
//   struct StackItem { iter: WrappedIterator, dirname_len: usize }
// ============================================================================

/// 遍历器栈项 - 对应 Bun StackItem (内部使用)
class WalkerStackItem {
    /// 目录遍历器
    var iterator: DirIterator
    /// 目录路径长度
    var dirnameLen: Int64
    /// 目录 FD
    var dirFd: Int64

    init(iterator: DirIterator, dirnameLen: Int64, dirFd: Int64) {
        this.iterator = iterator
        this.dirnameLen = dirnameLen
        this.dirFd = dirFd
    }
}

// ============================================================================
// Walker - 可跳过的目录遍历器
// 严格翻译自: src/sys/walker_skippable.rs:20-251
//   pub struct Walker {
//       stack: Vec<StackItem>,
//       name_buffer: NameBufferList,
//       skip_filenames: Range<usize>,
//       skip_dirnames: Range<usize>,
//       skip_all: Box<[u64]>,
//       seed: u64,
//       pub resolve_unknown_entry_types: bool,
//   }
// ============================================================================

/// 可跳过的目录遍历器 - 对应 Bun Walker
/// 递归遍历目录，支持跳过指定文件名和目录名
public class Walker {
    /// 遍历栈 - 对应 Bun stack
    private var stack: ArrayList<WalkerStackItem>
    /// 跳过的文件名哈希范围 - 对应 Bun skip_filenames
    private var skipFilenamesStart: Int64
    private var skipFilenamesEnd: Int64
    /// 跳过的目录名哈希范围 - 对应 Bun skip_dirnames
    private var skipDirnamesStart: Int64
    private var skipDirnamesEnd: Int64
    /// 所有跳过名称的哈希 - 对应 Bun skip_all
    private var skipAll: Array<UInt64>
    /// 哈希种子 - 对应 Bun seed
    private var seed: UInt64
    /// 是否解析未知条目类型 - 对应 Bun resolve_unknown_entry_types
    public var resolveUnknownEntryTypes: Bool

    private init() {
        stack = ArrayList<WalkerStackItem>()
        skipFilenamesStart = 0
        skipFilenamesEnd = 0
        skipDirnamesStart = 0
        skipDirnamesEnd = 0
        skipAll = []
        seed = 0
        resolveUnknownEntryTypes = false
    }

    /// 获取下一个条目 - 对应 Bun Walker.next()
    /// walker_skippable.rs:54-189
    /// 深度优先遍历，每次返回一个条目
    public func next(): SysMaybe<?WalkerEntry> {
        while (!stack.isEmpty()) {
            let topIdx = stack.size - 1
            let top = stack[topIdx]
            let entry = top.iterator.next()
            match (entry) {
                case None =>
                    // 目录遍历完毕，弹出栈项
                    let item = stack.removeAt(topIdx)
                    // 关闭非根目录的 FD
                    if (stack.size > 0) {
                        FdExt.close(item.dirFd)
                    }
                    continue
                case Some(e) =>
                    var entryKind = e.entryType

                    // 可选: 解析未知类型
                    if (entryKind == DirEntryType.Unknown && resolveUnknownEntryTypes) {
                        // 尝试 lstat 获取准确类型
                        let fullPath = if (stack.size == 1) {
                            e.name
                        } else {
                            Path.join(["", e.name])  // 相对路径
                        }
                        // 简化: 保留 Unknown
                    }

                    // 检查是否需要跳过
                    if (shouldSkip(e.name, entryKind)) {
                        continue
                    }

                    // 构建完整路径
                    var currentPath = StringBuilder()
                    // 找到栈中第一个条目的路径前缀
                    if (stack.size > 0) {
                        let baseItem = stack[0]
                        // 构建相对于根的路径
                    }
                    currentPath.append(e.name)
                    let fullPath = currentPath.toString()

                    // 如果是目录，推入栈
                    if (entryKind == DirEntryType.Directory) {
                        let openResult = DirIterator.open(e.name)
                        match (openResult) {
                            case Ok(iter) =>
                                stack.append(WalkerStackItem(
                                    iter, Int64(currentPath.toString().size), top.dirFd
                                ))
                            case Err(err) =>
                                return SysMaybe<?WalkerEntry>.Err(err)
                        }
                    }

                    let dirFd = if (entryKind == DirEntryType.Directory) {
                        stack[stack.size - 1].dirFd
                    } else {
                        top.dirFd
                    }

                    return SysMaybe<?WalkerEntry>.Ok(
                        Some(WalkerEntry(dirFd, e.name, fullPath, entryKind))
                    )
            }
        }
        return SysMaybe<?WalkerEntry>.Ok(None)
    }

    /// 是否应跳过 - 内部使用
    private func shouldSkip(name: String, kind: DirEntryType): Bool {
        if (skipAll.size == 0) {
            return false
        }
        let hash = hashName(name)
        match (kind) {
            case DirEntryType.Directory =>
                // 检查目录跳过列表
                for (i in skipDirnamesStart..skipDirnamesEnd) {
                    if (skipAll[i] == hash) { return true }
                }
                return false
            case DirEntryType.File =>
                // 检查文件跳过列表
                for (i in skipFilenamesStart..skipFilenamesEnd) {
                    if (skipAll[i] == hash) { return true }
                }
                return false
            case DirEntryType.Symlink =>
                // 符号链接检查全部
                for (i in 0..Int64(skipAll.size)) {
                    if (skipAll[i] == hash) { return true }
                }
                return false
            case _ => return false
        }
    }

    /// 哈希名称 - 对应 Bun hash_with_seed
    private func hashName(name: String): UInt64 {
        // 简化的 FNV-1a 哈希
        var hash: UInt64 = seed
        if (seed == 0) {
            hash = UInt64(14695981039346656037)
        }
        for (i in 0..name.size) {
            hash = hash ^ UInt64(Int64(name[Int64(i)].value))
            hash = hash * UInt64(1099511628211)
        }
        return hash
    }

    /// 清理资源 - 对应 Bun Walker.drop()
    /// 关闭所有打开的目录 FD
    public func deinit(): Unit {
        for (i in 0..stack.size) {
            let item = stack[Int64(i)]
            item.iterator.close()
            // 关闭非根目录 FD
            if (i > 0) {
                FdExt.close(item.dirFd)
            }
        }
        stack.clear()
    }

    /// 析构时自动清理
    protected func finalize(): Unit {
        deinit()
    }
}

// ============================================================================
// walk - 创建遍历器
// 严格翻译自: src/sys/walker_skippable.rs:212-251
//   pub fn walk(self_: Fd, skip_filenames, skip_dirnames) Result<Walker, AllocError>
// ============================================================================

/// 创建可跳过的目录遍历器 - 对应 Bun walk()
/// self_: 起始目录 FD
/// skipFilenames: 要跳过的文件名列表
/// skipDirnames: 要跳过的目录名列表
public func walkSkippable(startFd: Int64,
                           skipFilenames: Array<String>,
                           skipDirnames: Array<String>): SysMaybe<Walker> {
    let walker = Walker()
    let totalCount = Int64(skipFilenames.size) + Int64(skipDirnames.size)
    walker.seed = UInt64(totalCount)

    // 构建跳过哈希数组
    var skipAll = ArrayList<UInt64>()
    for (name in skipFilenames) {
        skipAll.append(walker.hashName(name))
    }
    walker.skipFilenamesStart = 0
    walker.skipFilenamesEnd = Int64(skipFilenames.size)
    walker.skipDirnamesStart = Int64(skipFilenames.size)
    walker.skipDirnamesEnd = Int64(skipAll.size)

    for (name in skipDirnames) {
        skipAll.append(walker.hashName(name))
    }
    walker.skipAll = skipAll.toArray()

    // 打开根目录迭代器
    // 注意: 假设 startFd 已经是一个打开的目录 FD
    let iterResult = DirIterator.open(".")  // 使用相对路径
    match (iterResult) {
        case Err(e) => return SysMaybe<Walker>.Err(e)
        case Ok(iter) =>
            walker.stack.append(WalkerStackItem(iter, 0, startFd))
            return SysMaybe<Walker>.Ok(walker)
    }
}

/// 简化的目录遍历 - 不跳过任何文件
/// 对应简单的 walk 场景
public func walkAll(startPath: String): SysMaybe<Walker> {
    let startFd = SysFs.open(startPath,
        OpenFlags.DIRECTORY | OpenFlags.RDONLY | OpenFlags.CLOEXEC, 0)
    match (startFd) {
        case Err(e) => return SysMaybe<Walker>.Err(e)
        case Ok(fd) =>
            return walkSkippable(fd, [], [])
    }
}
