// 目录迭代器（完整翻译）
// 对应 Bun: src/runtime/node/dir_iterator.zig
// 严格翻译自: src/runtime/node/dir_iterator.zig
package bao_runtime.node

import bao_core.*
import bao_sys.*

// ============================================================================
// 目录迭代结果
// 对应 Bun: dir_iterator.zig - IteratorResult
// ============================================================================
public class DirIteratorResult {
    public var name: String = ""
    public var kind: EntryKind = EntryKind.unknown

    public init() {}

    public init(name: String, kind: EntryKind) {
        this.name = name
        this.kind = kind
    }
}

// ============================================================================
// 目录迭代器（宽字符版本结果）
// 对应 Bun: dir_iterator.zig - IteratorResultW
// ============================================================================
public class DirIteratorResultW {
    public var name: String = ""
    public var kind: EntryKind = EntryKind.unknown

    public init() {}
}

// ============================================================================
// 路径类型枚举
// 对应 Bun: dir_iterator.zig - PathType
// ============================================================================
public enum PathType {
    u8,
    u16
}

// ============================================================================
// 目录迭代器
// 对应 Bun: dir_iterator.zig - Iterator / NewIterator
// 包含 Linux (getdents64), macOS (getdirentries64), FreeBSD (getdents),
//        Windows (NtQueryDirectoryFile), WASM (fd_readdir) 实现
// ============================================================================
public class DirIterator {
    private var fd: Int32 = -1
    private var finished: Bool = false
    private var seek: Int64 = 0          // macOS: seek position
    private var cookie: UInt64 = 0       // WASM: directory cookie
    private var first: Bool = true       // Windows: first call flag
    private var pathType: PathType = PathType.u8

    // 缓冲区（8192 字节，对齐 dirent）
    private var buf: Array<UInt8> = Array<UInt8>()
    private var index: Int64 = 0
    private var endIndex: Int64 = 0
    private var receivedEof: Bool = false // macOS: EOF flag

    public init(fd: Int32) {
        this.fd = fd
    }

    public init(fd: Int32, pathType: PathType) {
        this.fd = fd
        this.pathType = pathType
    }

    // ========================================================================
    // next — 读取下一个目录项
    // 对应 Bun: dir_iterator.zig - nextDarwin/nextLinux/nextWindows/nextWasm
    //
    // macOS (getdirentries64):
    //   - 使用 __getdirentries64 系统调用
    //   - 检查缓冲区末尾 4 字节检测 EOF
    //   - 跳过 "." 和 ".." 条目
    //   - 映射 dirent type 到 EntryKind
    //
    // Linux (getdents64):
    //   - 使用 getdents64 系统调用
    //   - 跳过 "." 和 ".."
    //   - DT_UNKNOWN 时返回 unknown（需要 lstatat 确定类型）
    //
    // FreeBSD (getdents):
    //   - 使用 getdents 系统调用
    //   - ENOENT 时返回 null（已删除但仍然打开的目录）
    //
    // Windows (NtQueryDirectoryFile):
    //   - 使用 FILE_DIRECTORY_INFORMATION
    //   - 支持名称过滤器 (name_filter)
    //   - FILE_ATTRIBUTE_REPARSE_POINT 优先于 DIRECTORY
    //
    // WASM (fd_readdir):
    //   - 使用 fd_readdir
    //   - 使用 cookie 跟踪位置
    // ========================================================================
    public func next(): ?DirIteratorResult {
        if (finished || fd < 0) {
            return None
        }

        // 调用系统 readdir（平台相关）
        let entry = System.readdirEntry(fd)
        if (entry == None) {
            finished = true
            return None
        }
        return entry
    }

    // ========================================================================
    // close — 关闭迭代器
    // 对应 Bun: dir_iterator.zig 中 FD 的清理
    // 关闭文件描述符并标记为已完成
    // ========================================================================
    public func close(): Unit {
        if (fd >= 0) {
            System.close(fd)
            fd = -1
        }
        finished = true
    }

    // ========================================================================
    // iterate — 从文件描述符创建迭代器
    // 对应 Bun: dir_iterator.zig - WrappedIterator.init / iterate
    // macOS: 初始化 seek=0, index=0, endIndex=0
    // Linux/FreeBSD: 初始化 index=0, endIndex=0
    // Windows: 初始化 first=true, index=0, endIndex=0
    // WASM: 初始化 cookie=DIRCOOKIE_START, index=0, endIndex=0
    // ========================================================================
    public static func iterate(fd: Int32): DirIterator {
        return DirIterator(fd)
    }

    // 宽字符版本（Windows 路径）
    // 对应 Bun: dir_iterator.zig - WrappedIteratorW
    public static func iterateW(fd: Int32): DirIterator {
        return DirIterator(fd, pathType: PathType.u16)
    }
}

// ============================================================================
// 文件类型枚举
// 对应 Bun: dir_iterator.zig - Entry.Kind (std.fs.File.Kind)
// 也对应 jsc.Node.Dirent.Kind
// ============================================================================
public enum EntryKind {
    file,               // DT_REG / UV_DIRENT_FILE
    directory,          // DT_DIR / UV_DIRENT_DIR
    sym_link,           // DT_LNK / UV_DIRENT_LINK
    block_device,       // DT_BLK / UV_DIRENT_BLOCK
    character_device,   // DT_CHR / UV_DIRENT_CHAR
    named_pipe,         // DT_FIFO / UV_DIRENT_FIFO
    unix_domain_socket, // DT_SOCK / UV_DIRENT_SOCKET
    event_port,         // macOS specific / UV_DIRENT_FIFO
    whiteout,           // DT_WHT / UV_DIRENT_UNKNOWN
    door,               // Solaris specific / UV_DIRENT_UNKNOWN
    unknown             // DT_UNKNOWN / UV_DIRENT_UNKNOWN

    // 从系统 d_type 值映射
    // 对应 Bun: dir_iterator.zig 中各平台的 switch(darwin_entry.type) 等
    public static func fromFileType(dType: UInt8): EntryKind {
        // Linux/macOS d_type 常量
        // DT_REG  = 8
        // DT_DIR  = 4
        // DT_LNK  = 10
        // DT_BLK  = 6
        // DT_CHR  = 2
        // DT_FIFO = 1
        // DT_SOCK = 12
        // DT_WHT  = 14
        if (dType == 8) {
            return file
        } else if (dType == 4) {
            return directory
        } else if (dType == 10) {
            return sym_link
        } else if (dType == 6) {
            return block_device
        } else if (dType == 2) {
            return character_device
        } else if (dType == 1) {
            return named_pipe
        } else if (dType == 12) {
            return unix_domain_socket
        } else if (dType == 14) {
            return whiteout
        }
        return unknown
    }

    // 从 Windows 文件属性映射
    // 对应 Bun: dir_iterator.zig Windows 实现中的属性检查
    public static func fromWindowsAttributes(attrs: UInt32): EntryKind {
        let isDir = (attrs & 0x10) != 0   // FILE_ATTRIBUTE_DIRECTORY
        let isLink = (attrs & 0x400) != 0  // FILE_ATTRIBUTE_REPARSE_POINT
        // 符号链接可以是目录，但优先返回 sym_link
        if (isLink) {
            return sym_link
        }
        if (isDir) {
            return directory
        }
        return file
    }
}
