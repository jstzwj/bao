// bao_sys - 目录遍历
// 严格翻译自: src/sys/dirent.zig
//   Bun 使用 opendir/readdir/closedir 遍历目录
//   仓颉通过 C FFI 调用 POSIX 目录操作
package bao_sys

import bao_core.*

// ============================================================================
// 目录操作 C FFI 声明
// ============================================================================

@C
foreign func opendir(name: CPointer<Int8>): CPointer<Unit>
@C
foreign func readdir(dir: CPointer<Unit>): CPointer<Unit>
@C
foreign func closedir(dir: CPointer<Unit>): Int32
@C
foreign func dirfd(dir: CPointer<Unit>): Int32

// ============================================================================
// DirEntry - 目录项
// 严格翻译自: struct dirent
// ============================================================================

/// 目录项 - 对应 Bun DirEntry / struct dirent
public class DirEntry {
    /// 文件名
    public var name: String
    /// 文件类型
    public var entryType: DirEntryType
    /// inode 号
    public var ino: UInt64

    public init(name: String, entryType: DirEntryType) {
        this.name = name
        this.entryType = entryType
        this.ino = 0
    }

    public init(name: String, entryType: DirEntryType, ino: UInt64) {
        this.name = name
        this.entryType = entryType
        this.ino = ino
    }

    /// 是否为普通文件
    public func isFile(): Bool {
        return entryType == DirEntryType.File
    }

    /// 是否为目录
    public func isDirectory(): Bool {
        return entryType == DirEntryType.Directory
    }

    /// 是否为符号链接
    public func isSymlink(): Bool {
        return entryType == DirEntryType.Symlink
    }
}

/// 目录项类型 - 对应 DT_* 常量
public enum DirEntryType {
    | Unknown    // DT_UNKNOWN = 0
    | File       // DT_REG = 8
    | Directory  // DT_DIR = 4
    | Symlink    // DT_LNK = 10
    | Block      // DT_BLK = 6
    | Char       // DT_CHR = 2
    | Fifo       // DT_FIFO = 1
    | Socket     // DT_SOCK = 12

    public static func fromDType(dtype: UInt8): DirEntryType {
        match (Int32(dtype)) {
            case 8 => DirEntryType.File
            case 4 => DirEntryType.Directory
            case 10 => DirEntryType.Symlink
            case 6 => DirEntryType.Block
            case 2 => DirEntryType.Char
            case 1 => DirEntryType.Fifo
            case 12 => DirEntryType.Socket
            case _ => DirEntryType.Unknown
        }
    }
}

// ============================================================================
// DirIterator - 目录遍历器
// 严格翻译自: src/sys/dirent.zig
//   Bun 的 DirIterator 封装 opendir/readdir
// ============================================================================

/// 目录遍历器 - 对应 Bun DirIterator
public class DirIterator {
    private var dirPtr: CPointer<Unit>
    private var closed: Bool

    private init(dirPtr: CPointer<Unit>) {
        this.dirPtr = dirPtr
        this.closed = false
    }

    /// 打开目录
    /// 对应 Bun: sys.opendir(path) -> Maybe(DirIterator)
    public static func open(path: String): SysMaybe<DirIterator> {
        unsafe {
            let pathPtr = unsafeNewCString(path)
            let dir = opendir(pathPtr)
            if (dir.isNull()) {
                return SysMaybe<DirIterator>.Err(
                    SysError(UInt16(Int64(OS.errno())), SysTag.Open, path)
                )
            }
            return SysMaybe<DirIterator>.Ok(DirIterator(dir))
        }
    }

    /// 读取下一个目录项
    /// 对应 Bun: DirIterator.next() -> ?DirEntry
    public func next(): ?DirEntry {
        if (closed) { return None }
        unsafe {
            let entry = readdir(dirPtr)
            if (entry.isNull()) {
                return None
            }
            // 解析 struct dirent:
            // d_ino (8 bytes) + d_off (8 bytes) + d_reclen (2) + d_type (1) + d_name (256)
            let nameOffset = 19  // 在 Linux x86_64 上
            var name = StringBuilder()
            var i = 0
            while (i < 256) {
                let bytePtr = CPointer<Int8>(entry) + IntNative(nameOffset + i)
                let b = Int32(bytePtr.read())
                if (b == 0) { break }
                name.append(Char(b))
                i += 1
            }
            let entryName = name.toString()
            // 跳过 . 和 ..
            if (entryName == "." || entryName == "..") {
                return next()
            }
            // 读取 d_type (偏移 18)
            let dtypePtr = CPointer<UInt8>(entry) + IntNative(18)
            let dtype = dtypePtr.read()
            return Some(DirEntry(entryName, DirEntryType.fromDType(dtype)))
        }
    }

    /// 收集所有目录项
    /// 对应 Bun: DirIterator.collect()
    public func collect(): ArrayList<DirEntry> {
        var result = ArrayList<DirEntry>()
        while (true) {
            let entry = next()
            if (entry == None) { break }
            result.append(entry.unwrap())
        }
        return result
    }

    /// 关闭目录
    /// 对应 Bun: DirIterator.close()
    public func close(): Unit {
        if (!closed) {
            closedir(dirPtr)
            closed = true
        }
    }
}

/// 目录遍历工具 - 对应 Bun 目录遍历辅助函数
public class DirUtils {
    /// 列出目录中的文件
    public static func listDir(path: String): SysMaybe<ArrayList<DirEntry>> {
        let iter = DirIterator.open(path)
        match (iter) {
            case Err(e) => return SysMaybe<ArrayList<DirEntry>>.Err(e)
            case Ok(it) =>
                let entries = it.collect()
                it.close()
                return SysMaybe<ArrayList<DirEntry>>.Ok(entries)
        }
    }

    /// 递归遍历目录
    /// 对应 Bun: 遍历 node_modules 等场景
    public static func walkDir(path: String, callback: (String, DirEntry) -> Unit): Unit {
        let iter = DirIterator.open(path)
        match (iter) {
            case Err(_) => return
            case Ok(it) =>
                while (true) {
                    let entry = it.next()
                    if (entry == None) { break }
                    let e = entry.unwrap()
                    let fullPath = Path.join([path, e.name])
                    callback(fullPath, e)
                    if (e.isDirectory()) {
                        walkDir(fullPath, callback)
                    }
                }
                it.close()
        }
    }
}
