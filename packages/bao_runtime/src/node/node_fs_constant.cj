// 文件系统常量定义
// 对应 Bun: src/runtime/node/node_fs_constant.zig
// 严格翻译自: src/runtime/node/node_fs_constant.zig
package bao_runtime.node

// ============================================================================
// 文件访问常量
// 对应 Bun: src/runtime/node/node_fs_constant.zig - F_OK, R_OK, W_OK, X_OK
// ============================================================================
public class FsAccessConstants {
    public static let F_OK: Int32 = 0   // 文件可见
    public static let R_OK: Int32 = 4   // 可读
    public static let W_OK: Int32 = 2   // 可写
    public static let X_OK: Int32 = 1   // 可执行
}

// ============================================================================
// 文件复制常量
// 对应 Bun: src/runtime/node/node_fs_constant.zig - Copyfile
// ============================================================================
public class FsCopyConstants {
    public static let COPYFILE_EXCL: Int32 = 1       // 不覆盖
    public static let COPYFILE_FICLONE: Int32 = 2    // copy-on-write
    public static let COPYFILE_FICLONE_FORCE: Int32 = 4  // 强制 copy-on-write
}

// ============================================================================
// 文件打开常量
// 对应 Bun: src/runtime/node/node_fs_constant.zig - O_*
// ============================================================================
public class FsOpenConstants {
    public static let O_RDONLY: Int32 = 0
    public static let O_WRONLY: Int32 = 1
    public static let O_RDWR: Int32 = 2
    public static let O_CREAT: Int32 = 64        // 0100
    public static let O_EXCL: Int32 = 128         // 0200
    public static let O_NOCTTY: Int32 = 256       // 0400
    public static let O_TRUNC: Int32 = 512        // 01000
    public static let O_APPEND: Int32 = 1024      // 02000
    public static let O_DIRECTORY: Int32 = 65536  // 0200000
    public static let O_NOATIME: Int32 = 262144   // 01000000
    public static let O_NOFOLLOW: Int32 = 131072  // 0400000
    public static let O_SYNC: Int32 = 1052672     // 04010000
    public static let O_DSYNC: Int32 = 4096       // 010000
    public static let O_SYMLINK: Int32 = 524288   // 02000000
    public static let O_DIRECT: Int32 = 16384     // 040000
    public static let O_NONBLOCK: Int32 = 2048    // 04000
}

// ============================================================================
// 文件类型常量
// 对应 Bun: src/runtime/node/node_fs_constant.zig - S_*
// ============================================================================
public class FsTypeConstants {
    public static let S_IFMT: UInt64 = 61440     // 0170000
    public static let S_IFREG: UInt64 = 32768    // 0100000
    public static let S_IFDIR: UInt64 = 16384    // 0040000
    public static let S_IFCHR: UInt64 = 8192     // 0020000
    public static let S_IFBLK: UInt64 = 24576    // 0060000
    public static let S_IFIFO: UInt64 = 4096     // 0010000
    public static let S_IFLNK: UInt64 = 40960    // 0120000
    public static let S_IFSOCK: UInt64 = 49152   // 0140000
}

// ============================================================================
// 文件权限常量
// 对应 Bun: src/runtime/node/node_fs_constant.zig - S_IR*
// ============================================================================
public class FsModeConstants {
    public static let S_IRWXU: UInt64 = 448      // 0700
    public static let S_IRUSR: UInt64 = 256      // 0400
    public static let S_IWUSR: UInt64 = 128      // 0200
    public static let S_IXUSR: UInt64 = 64       // 0100
    public static let S_IRWXG: UInt64 = 56       // 0070
    public static let S_IRGRP: UInt64 = 32       // 0040
    public static let S_IWGRP: UInt64 = 16       // 0020
    public static let S_IXGRP: UInt64 = 8        // 0010
    public static let S_IRWXO: UInt64 = 7        // 0007
    public static let S_IROTH: UInt64 = 4        // 0004
    public static let S_IWOTH: UInt64 = 2        // 0002
    public static let S_IXOTH: UInt64 = 1        // 0001
}

// ============================================================================
// UV 文件系统常量
// 对应 Bun: src/runtime/node/node_fs_constant.zig - UV_FS_O_FILEMAP
// ============================================================================
public class FsUvConstants {
    public static let UV_FS_O_FILEMAP: Int32 = 536870912
}
