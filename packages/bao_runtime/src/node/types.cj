// Node.js 运行时类型定义
// 对应 Bun: src/runtime/node/types.zig
// 严格翻译自: src/runtime/node/types.zig
package bao_runtime

import bao_core.*

// ============================================================================
// 编码类型枚举
// 对应 Bun: src/runtime/node/types.zig - Encoding
// ============================================================================
public enum Encoding {
    utf8,
    ucs2,
    utf16le,
    latin1,
    ascii,
    base64,
    base64url,
    hex,
    buffer,

    // 编码名称映射（用于从字符串解析编码类型）
    public static func from(name: String): ?Encoding {
        let lower = name.toLowerAscii()
        if (lower == "utf-8" || lower == "utf8") {
            return utf8
        }
        if (lower == "ucs-2" || lower == "ucs2" || lower == "utf16-le" || lower == "utf16le") {
            return utf16le
        }
        if (lower == "binary" || lower == "latin1") {
            return latin1
        }
        if (lower == "ascii") {
            return ascii
        }
        if (lower == "base64") {
            return base64
        }
        if (lower == "hex") {
            return hex
        }
        if (lower == "buffer") {
            return buffer
        }
        if (lower == "base64url") {
            return base64url
        }
        return None
    }

    // 是否为二进制到文本的编码
    public func isBinaryToText(): Bool {
        return this == hex || this == base64 || this == base64url
    }
}

// ============================================================================
// 文件系统标志
// 对应 Bun: src/runtime/node/types.zig - FileSystemFlags
// ============================================================================
public enum FileSystemFlags {
    // 打开文件用于读取
    r,
    // 打开文件用于写入
    w,
    // 打开文件用于追加
    a,

    // 从字符串解析文件系统标志
    public static func from(flag: String): ?FileSystemFlags {
        if (flag == "r" || flag == "rs" || flag == "sr" || flag == "R" || flag == "RS" || flag == "SR") {
            return r
        }
        if (flag == "w" || flag == "W" || flag == "wx" || flag == "xw" || flag == "WX" || flag == "XW") {
            return w
        }
        if (flag == "a" || flag == "A" || flag == "ax" || flag == "xa" || flag == "AX" || flag == "XA") {
            return a
        }
        return None
    }
}

// ============================================================================
// 路径或文件描述符联合类型
// 对应 Bun: src/runtime/node/types.zig - PathOrFileDescriptor
// ============================================================================
public class PathOrFileDescriptor {
    public var isFd: Bool = false
    public var fd: Int32 = -1
    public var path: String = ""

    public init(fd: Int32) {
        this.isFd = true
        this.fd = fd
    }

    public init(path: String) {
        this.isFd = false
        this.path = path
    }

    // 获取路径字符串
    public func slice(): String {
        return if (isFd) { fd.toString() } else { path }
    }
}

// ============================================================================
// 目录项
// 对应 Bun: src/runtime/node/types.zig - Dirent
// ============================================================================
public class Dirent {
    public var name: String = ""
    public var path: String = ""
    public var kind: EntryKind = EntryKind.unknown

    public init(name: String, path: String, kind: EntryKind) {
        this.name = name
        this.path = path
        this.kind = kind
    }

    // 文件类型判断
    public func isFile(): Bool {
        return kind == EntryKind.file
    }

    public func isDirectory(): Bool {
        return kind == EntryKind.directory
    }

    public func isSymbolicLink(): Bool {
        return kind == EntryKind.sym_link
    }

    public func isBlockDevice(): Bool {
        return kind == EntryKind.block_device
    }

    public func isCharacterDevice(): Bool {
        return kind == EntryKind.character_device
    }

    public func isFIFO(): Bool {
        return kind == EntryKind.named_pipe
    }

    public func isSocket(): Bool {
        return kind == EntryKind.unix_domain_socket
    }
}

// ============================================================================
// 文件类型枚举
// 对应 Bun: src/runtime/node/types.zig - Dirent.Kind
// ============================================================================
public enum EntryKind {
    file,
    directory,
    sym_link,
    block_device,
    character_device,
    named_pipe,
    unix_domain_socket,
    event_port,
    whiteout,
    door,
    unknown
}

// ============================================================================
// 路径验证工具
// 对应 Bun: src/runtime/node/types.zig - Valid
// ============================================================================
public class Valid {
    // 最大路径长度
    public static let MAX_PATH_BYTES: Int64 = 4096

    // 验证路径长度
    public static func pathStringLength(len: Int64): Bool {
        return len >= 0 && len <= MAX_PATH_BYTES
    }

    // 验证路径不包含空字节
    public static func pathNullBytes(path: String): Bool {
        return !path.contains('\x00')
    }
}

// ============================================================================
// 模式解析
// 对应 Bun: src/runtime/node/types.zig - modeFromJS
// ============================================================================
public class ModeUtils {
    // 从字符串或数字解析文件权限模式
    public static func fromString(modeStr: String): ?UInt32 {
        var str = modeStr
        if (str.startsWith("0o")) {
            str = str.substring(2)
        }
        // 解析八进制字符串
        var result: UInt32 = 0
        for (c in str) {
            if (c >= '0' && c <= '7') {
                result = result * 8 + UInt32(UInt8(c) - UInt8('0'))
            } else {
                return None
            }
        }
        return result & 0o777
    }

    // 从数字解析模式
    public static func fromNumber(mode: Int64): UInt32 {
        return UInt32(mode) & 0o777
    }
}
