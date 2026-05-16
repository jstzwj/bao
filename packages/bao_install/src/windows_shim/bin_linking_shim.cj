// bao_install - Windows Shim 二进制链接
// 严格翻译自: src/install/windows-shim/BinLinkingShim.rs + .zig
//   BinLinkingShim 用于在 Windows 上创建 .bunx 文件, 解决:
//   - Windows 不处理 Shebang
//   - Windows 上符号链接不可靠
//   格式: [WSTR:bin_path][u16'"'][u16:0](shebang?)[flags:u16]
package bao_install.windows_shim

import bao_core.*
import bao_collections.*
import bao_io.*
import bao_hash.*
import bao_path.*

// ============================================================================
// 版本标志
// 严格翻译自: BinLinkingShim.VersionFlag
//   enum(u13) 非穷举, 用透明包装 u16 存 13 位值
//   选取随机数用于验证, 防止偏移错误
// ============================================================================

/// 版本标志
/// 翻译自: VersionFlag (u13 enum)
public class VersionFlag {
    public var value: UInt16

    public init(value: UInt16) {
        this.value = value
    }

    public static let CURRENT: VersionFlag = VersionFlag.V5

    public static let V1: VersionFlag = VersionFlag(value: UInt16(5474))
    /// 修复路径未正确连接的 bug
    public static let V2: VersionFlag = VersionFlag(value: UInt16(5475))
    /// 添加了进程未找到时的错误信息
    public static let V3: VersionFlag = VersionFlag(value: UInt16(5476))
    /// 添加标记指示 shebang 是否为 "node" (自动回退到 "bun")
    public static let V4: VersionFlag = VersionFlag(value: UInt16(5477))
    /// 修复参数传递不总有效的 bug
    public static let V5: VersionFlag = VersionFlag(value: UInt16(5478))

    /// std.math.maxInt(u13) = 8191
    public static let MAX: UInt16 = UInt16((1 << 13) - 1)
}

// ============================================================================
// 标志位
// 严格翻译自: BinLinkingShim.Flags
//   packed struct(u16): is_node_or_bun:bool, is_node:bool, has_shebang:bool, version_tag:u13
// ============================================================================

/// Shim 标志位
/// 翻译自: Flags (packed struct u16)
public class Flags {
    public var bits: UInt16

    public init(bits: UInt16) {
        this.bits = bits
    }

    /// 构造标志
    /// 翻译自: Flags.new
    public static func new(
        isNodeOrBun: Bool,
        isNode: Bool,
        hasShebang: Bool,
        versionTag: VersionFlag
    ): Flags {
        let b = (isNodeOrBun ? UInt16(1) : UInt16(0))
            | ((isNode ? UInt16(1) : UInt16(0)) << 1)
            | ((hasShebang ? UInt16(1) : UInt16(0)) << 2)
            | (versionTag.value << 3)
        return Flags(bits: b)
    }

    /// 从位构造
    /// 翻译自: Flags.from_bits
    public static func fromBits(b: UInt16): Flags {
        return Flags(bits: b)
    }

    /// shebang 内容是 "node" 或 "bun"
    /// 翻译自: Flags.is_node_or_bun
    public func isNodeOrBun(): Bool {
        return (bits & 0b001) != UInt16(0)
    }

    /// 验证标志不为损坏数据
    /// 翻译自: Flags.is_node
    public func isNode(): Bool {
        return (bits & 0b010) != UInt16(0)
    }

    /// 是否有 shebang
    /// 翻译自: Flags.has_shebang
    public func hasShebang(): Bool {
        return (bits & 0b100) != UInt16(0)
    }

    /// 版本标签
    /// 翻译自: Flags.version_tag
    public func versionTag(): VersionFlag {
        return VersionFlag(value: bits >> 3)
    }

    /// 设置 is_node
    /// 翻译自: Flags.set_is_node
    public func setIsNode(v: Bool): Unit {
        bits = (bits & ~UInt16(0b010)) | ((v ? UInt16(1) : UInt16(0)) << 1)
    }

    /// 验证标志是否有效
    /// 翻译自: Flags.is_valid
    public func isValid(): Bool {
        let mask = Flags.new(false, false, false, VersionFlag(value: VersionFlag.MAX)).bits
        let compareTo = Flags.new(false, false, false, VersionFlag.CURRENT).bits
        return (bits & mask) == compareTo
    }
}

// ============================================================================
// Shebang
// 严格翻译自: BinLinkingShim.Shebang
//   解析文件开头的 #! 行
// ============================================================================

/// 扩展名类型
/// 翻译自: ExtensionType
public enum ExtensionType {
    | RunWithBun
    | RunWithCmd
    | RunWithPowershell
}

/// Shebang 信息
/// 翻译自: Shebang
public class Shebang {
    /// 启动器命令 (如 "bun run", "node", "python")
    public var launcher: String
    /// UTF-16 长度
    public var utf16Len: UInt32
    /// 是否是 node 或 bun
    public var isNodeOrBun: Bool

    public init(launcher: String, utf16Len: UInt32, isNodeOrBun: Bool) {
        this.launcher = launcher
        this.utf16Len = utf16Len
        this.isNodeOrBun = isNodeOrBun
    }

    /// 初始化 shebang
    /// 翻译自: Shebang.init
    public static func init(launcher: String, isNodeOrBun: Bool): Result<Shebang> {
        let utf16Len = UInt32(launcher.length) // 简化: ASCII
        return Result.Ok(Shebang(
            launcher: launcher,
            utf16Len: utf16Len,
            isNodeOrBun: isNodeOrBun
        ))
    }

    /// 从 bin 路径推断 shebang
    /// 翻译自: Shebang.parseFromBinPath
    public static func parseFromBinPath(binPath: String): ?Shebang {
        let ext = extensionW(binPath)
        match (bunExtensionsGet(ext)) {
            case Some(t) => {
                return match (t) {
                    case ExtensionType.RunWithBun => Some(Shebang(
                        launcher: "bun run",
                        utf16Len: 7,
                        isNodeOrBun: true
                    ))
                    case ExtensionType.RunWithCmd => Some(Shebang(
                        launcher: "cmd /c",
                        utf16Len: 6,
                        isNodeOrBun: false
                    ))
                    case ExtensionType.RunWithPowershell => Some(Shebang(
                        launcher: "powershell -ExecutionPolicy Bypass -File",
                        utf16Len: 40,
                        isNodeOrBun: false
                    ))
                }
            }
            case None => return None
        }
    }

    /// 解析 shebang 内容
    /// 翻译自: Shebang.parse
    ///   从文件内容解析 #! 行
    public static func parse(contents: Array<Byte>, binPath: String): ?Shebang {
        if (contents.size < 3) {
            return parseFromBinPath(binPath)
        }

        if (contents[0] != Byte('#') || contents[1] != Byte('!')) {
            return parseFromBinPath(binPath)
        }

        // 找到行尾
        var lineEnd = contents.size
        var i = 2
        while (i < contents.size) {
            if (contents[i] == Byte('\n')) {
                lineEnd = i.toInt()
                // 检查 \r\n
                if (i > 2 && contents[i - 1] == Byte('\r')) {
                    lineEnd = (i - 1).toInt()
                }
                break
            }
            i += 1
        }

        let line = contents.slice(2, lineEnd)

        // 分词
        var idx = 0
        // 跳过前导空格
        while (idx < line.size && line[idx] == Byte(' ')) {
            idx += 1
        }
        let firstStart = idx
        while (idx < line.size && line[idx] != Byte(' ')) {
            idx += 1
        }
        let first = line.slice(firstStart, idx)
        if (first.size == 0) {
            return parseFromBinPath(binPath)
        }

        // /usr/bin/env 或 /bin/env
        if (first == "/usr/bin/env".toByteArray() || first == "/bin/env".toByteArray()) {
            // 跳过空格, 取程序名
            while (idx < line.size && line[idx] == Byte(' ')) {
                idx += 1
            }
            let progStart = idx
            while (idx < line.size && line[idx] != Byte(' ')) {
                idx += 1
            }
            let program = line.slice(progStart, idx)
            if (program.size == 0) {
                return parseFromBinPath(binPath)
            }
            let isNodeOrBun = (program == "bun".toByteArray() || program == "node".toByteArray())
            // rest = 程序后面的参数
            let rest = line.slice(idx, line.size)
            let result = Shebang.init(
                launcher: String.fromBytes(rest),
                isNodeOrBun: isNodeOrBun
            )
            match (result) {
                case Result.Ok(s) => return Some(s)
                case _ => return parseFromBinPath(binPath)
            }
        }

        // 直接以 launcher 使用整行
        let result = Shebang.init(
            launcher: String.fromBytes(line),
            isNodeOrBun: false
        )
        match (result) {
            case Result.Ok(s) => return Some(s)
            case _ => return None
        }
    }

    /// 编码长度
    /// 翻译自: Shebang.encoded_length
    public func encodedLength(): Int64 {
        return (1 + utf16Len.toInt()) * 2 + 4 * 2 // sizeof(u32) * 2
    }

    /// 最大输入长度 (CreateProcessW 限制)
    /// 翻译自: MAX_SHEBANG_INPUT_LENGTH
    public static let MAX_SHEBANG_INPUT_LENGTH: Int64 = 32766 + 2
}

// ============================================================================
// BinLinkingShim 编码器
// 严格翻译自: BinLinkingShim struct
// ============================================================================

/// Bin 链接 Shim
/// 翻译自: BinLinkingShim
public class BinLinkingShim {
    /// 相对 node_modules 的路径
    public var binPath: String
    /// shebang 信息
    public var shebang: ?Shebang

    public init(binPath: String, shebang: ?Shebang) {
        this.binPath = binPath
        this.shebang = shebang
    }

    /// 编码长度
    /// 翻译自: BinLinkingShim.encoded_length
    public func encodedLength(): Int64 {
        // bin_path + 引号 + 空格 = (len + 2) * 2
        var l = (binPath.length + 2) * 2
        // flags u16
        l += 2
        match (shebang) {
            case Some(s) => l += s.encodedLength()
            case None => {}
        }
        return l.toInt()
    }

    /// 编码到缓冲区
    /// 翻译自: BinLinkingShim.encode_into
    public func encodeInto(buf: ArrayList<Byte>): Result<Unit> {
        // 写入 bin_path (UTF-16LE)
        let binPathUtf16 = bao_core.Strings.convertUtf8ToUtf16(binPath)
        for (ch in binPathUtf16) {
            buf.append(Byte(ch & 0xFF))
            buf.append(Byte((ch >> 8) & 0xFF))
        }

        // 写入引号字符 (UTF-16LE)
        buf.append(Byte(0x22)) // '"'
        buf.append(Byte(0x00))
        // 写入空字符
        buf.append(Byte(0x00))
        buf.append(Byte(0x00))

        // 构建 flags
        let isNodeOrBun = match (shebang) {
            case Some(s) => s.isNodeOrBun
            case None => false
        }
        var flags = Flags.new(
            isNodeOrBun: isNodeOrBun,
            isNode: false,
            hasShebang: shebang != None,
            versionTag: VersionFlag.CURRENT
        )

        match (shebang) {
            case Some(s) => {
                let isNode = s.launcher.startsWith("node") &&
                    (s.launcher.length == 4 || s.launcher[4] == ' ')
                flags.setIsNode(isNode)

                // 写入 shebang launcher (UTF-16LE)
                let launcherUtf16 = bao_core.Strings.convertUtf8ToUtf16(s.launcher)
                for (ch in launcherUtf16) {
                    buf.append(Byte(ch & 0xFF))
                    buf.append(Byte((ch >> 8) & 0xFF))
                }

                // 写入空格 (UTF-16LE)
                buf.append(Byte(0x20))
                buf.append(Byte(0x00))

                // bin_path_byte_len (u32 LE)
                let binPathByteLen = UInt32(binPath.length * 2)
                buf.append(Byte((binPathByteLen >> 0) & 0xFF))
                buf.append(Byte((binPathByteLen >> 8) & 0xFF))
                buf.append(Byte((binPathByteLen >> 16) & 0xFF))
                buf.append(Byte((binPathByteLen >> 24) & 0xFF))

                // arg_byte_len (u32 LE)
                let argByteLen = s.utf16Len * 2 + 2
                buf.append(Byte((argByteLen >> 0) & 0xFF))
                buf.append(Byte((argByteLen >> 8) & 0xFF))
                buf.append(Byte((argByteLen >> 16) & 0xFF))
                buf.append(Byte((argByteLen >> 24) & 0xFF))
            }
            case None => {}
        }

        // 写入 flags (u16 LE)
        buf.append(Byte(flags.bits & 0xFF))
        buf.append(Byte((flags.bits >> 8) & 0xFF))

        return Result.Ok(())
    }
}

// ============================================================================
// 解码器
// 严格翻译自: BinLinkingShim.loose_decode
// ============================================================================

/// 解码结果
/// 翻译自: Decoded
public class Decoded {
    public var binPath: String
    public var flags: Flags

    public init(binPath: String, flags: Flags) {
        this.binPath = binPath
        this.flags = flags
    }
}

/// 宽松解码
/// 翻译自: loose_decode
///   从 .bunx 文件数据中解析 bin_path 和 flags
public func looseDecode(input: Array<Byte>): ?Decoded {
    let flagsSize: Int64 = 2 // sizeof(u16)
    // 最小长度检查
    if (input.size < flagsSize + 4 * 2 + 8) {
        return None
    }

    // 从末尾读取 flags
    let flagsBits = UInt16(input[input.size - 2]) | (UInt16(input[input.size - 1]) << 8)
    let flags = Flags.fromBits(flagsBits)
    if (!flags.isValid()) {
        return None
    }

    // 解析 bin_path
    let binPath: String
    if (flags.hasShebang()) {
        // 有 shebang: bin_path 长度在 flags 前的 u32 中
        let off = input.size - flagsSize.toInt() - 4 * 2
        let binPathByteLen = UInt32(input[off]) |
            (UInt32(input[off + 1]) << 8) |
            (UInt32(input[off + 2]) << 16) |
            (UInt32(input[off + 3]) << 24)
        if (binPathByteLen % 2 != UInt32(0) || binPathByteLen.toInt() > input.size - 8) {
            return None
        }
        // 从 UTF-16LE 读取 bin_path
        let pathBytes = input.slice(0, binPathByteLen.toInt())
        binPath = utf16LEToString(pathBytes)
    } else {
        // 无 shebang: bin_path 从头到 flags 前
        let pathBytes = input.slice(0, input.size - flagsSize.toInt())
        binPath = utf16LEToString(pathBytes)
    }

    return Some(Decoded(binPath: binPath, flags: flags))
}

// ============================================================================
// 辅助函数
// ============================================================================

/// 获取文件扩展名 (UTF-16 路径)
/// 翻译自: Shebang.extensionW
private func extensionW(path: String): String {
    let filename = bao_core.Strings.basenameWindows(path)
    let dotIndex = filename.lastIndexOf(".")
    match (dotIndex) {
        case Some(idx) => {
            if (idx == 0) { return "" }
            return filename.substring(idx)
        }
        case None => return ""
    }
}

/// 获取扩展名对应的类型
/// 翻译自: bun_extensions_get
private func bunExtensionsGet(ext: String): ?ExtensionType {
    match (ext) {
        case ".js" => ExtensionType.RunWithBun
        case ".mjs" => ExtensionType.RunWithBun
        case ".cjs" => ExtensionType.RunWithBun
        case ".jsx" => ExtensionType.RunWithBun
        case ".ts" => ExtensionType.RunWithBun
        case ".cts" => ExtensionType.RunWithBun
        case ".mts" => ExtensionType.RunWithBun
        case ".tsx" => ExtensionType.RunWithBun
        case ".sh" => ExtensionType.RunWithBun
        case ".cmd" => ExtensionType.RunWithCmd
        case ".bat" => ExtensionType.RunWithCmd
        case ".ps1" => ExtensionType.RunWithPowershell
        case _ => None
    }
}

/// UTF-16LE 字节转字符串
private func utf16LEToString(bytes: Array<Byte>): String {
    if (bytes.size % 2 != 0) {
        return ""
    }
    let chars = ArrayList<Char>()
    var i = 0
    while (i < bytes.size - 1) {
        let ch = UInt16(bytes[i]) | (UInt16(bytes[i + 1]) << 8)
        chars.append(Char(ch))
        i += 2
    }
    return String.fromChars(chars)
}
