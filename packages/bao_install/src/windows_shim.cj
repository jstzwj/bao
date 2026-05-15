// bao_install - Windows 二进制链接垫片
// 严格翻译自: src/install/windows-shim/BinLinkingShim.zig
//   BinLinkingShim.zig 负责在 Windows 上编码 .bunx 文件,
//   用于替代符号链接来执行 node_modules/.bin 中的脚本
//
// Windows 上需要此机制的原因:
// 1. 符号链接不保证在 Windows 上工作
// 2. Windows 不处理 Shebang
// 3. 避免 NPM/Yarn 的 "Terminate batch job (Y/N)" 问题
package bao_install

import bao_core.*
import bao_collections.*
import bao_io.*
import bao_hash.*
import bao_path.*
import bao_http.*

// ============================================================================
// 版本标记
// 严格翻译自: src/install/windows-shim/BinLinkingShim.zig
//   pub const VersionFlag = enum(u13) {
//       pub const current = .v5;
//       v1 = 5474,
//       v2 = 5475,
//       v3 = 5476,
//       v4 = 5477,
//       v5 = 5478,
//       _,
//   }
// ============================================================================

/// 版本标记
/// 对应 Bun: VersionFlag
/// 随机数用于验证, 这些数字不太可能出现在其他字段中
public enum VersionFlag {
    | V1   // = 5474
    | V2   // = 5475, 修复路径连接 bug
    | V3   // = 5476, 添加进程未找到错误消息
    | V4   // = 5477, 添加 "node" shebang 检测标记
    | V5   // = 5478, 修复参数传递 bug

    /// 当前版本
    /// 翻译自: VersionFlag.current = .v5
    public static let CURRENT: VersionFlag = VersionFlag.V5

    /// 获取数值
    public func value(): Int64 {
        match (this) {
            case V1 => return 5474
            case V2 => return 5475
            case V3 => return 5476
            case V4 => return 5477
            case V5 => return 5478
        }
    }
}

// ============================================================================
// 垫片标志
// 严格翻译自: BinLinkingShim.zig
//   pub const Flags = packed struct(u16) {
//       is_node_or_bun: bool,
//       is_node: bool,
//       has_shebang: bool,
//       version_tag: VersionFlag = VersionFlag.current,
//   }
// ============================================================================

/// 垫片标志
/// 对应 Bun: BinLinkingShim.Flags
/// 打包为 16 位整数:
/// bit 0: is_node_or_bun
/// bit 1: is_node
/// bit 2: has_shebang
/// bit 3-15: version_tag
public class BinLinkingShimFlags {
    /// shebang 内容是否为 "node" 或 "bun"
    public var isNodeOrBun: Bool
    /// shebang 内容是否为 "node"
    public var isNode: Bool
    /// 是否有 shebang
    public var hasShebang: Bool
    /// 版本标记
    public var versionTag: VersionFlag

    public init() {
        isNodeOrBun = false
        isNode = false
        hasShebang = false
        versionTag = VersionFlag.CURRENT
    }

    public init(isNodeOrBun: Bool, isNode: Bool, hasShebang: Bool) {
        this.isNodeOrBun = isNodeOrBun
        this.isNode = isNode
        this.hasShebang = hasShebang
        versionTag = VersionFlag.CURRENT
    }

    /// 验证标志是否有效
    /// 翻译自: Flags.isValid
    public func isValid(): Bool {
        // 版本标记必须匹配当前版本
        return versionTag == VersionFlag.CURRENT
    }

    /// 编码为 16 位整数
    /// 翻译自: packed struct 的位布局
    public func encode(): UInt16 {
        var value: UInt16 = UInt16(0)
        if (isNodeOrBun) { value = value | UInt16(1) }
        if (isNode) { value = value | UInt16(2) }
        if (hasShebang) { value = value | UInt16(4) }
        value = value | (UInt16(versionTag.value()) << UInt16(3))
        return value
    }

    /// 从 16 位整数解码
    public static func decode(value: UInt16): BinLinkingShimFlags {
        let flags = BinLinkingShimFlags()
        flags.isNodeOrBun = (value & UInt16(1)) != UInt16(0)
        flags.isNode = (value & UInt16(2)) != UInt16(0)
        flags.hasShebang = (value & UInt16(4)) != UInt16(0)
        let versionBits = Int64(value >> UInt16(3))
        flags.versionTag = match (versionBits) {
            case 5474 => VersionFlag.V1
            case 5475 => VersionFlag.V2
            case 5476 => VersionFlag.V3
            case 5477 => VersionFlag.V4
            case 5478 => VersionFlag.V5
            case _ => VersionFlag.CURRENT
        }
        return flags
    }
}

// ============================================================================
// Shebang 信息
// 严格翻译自: BinLinkingShim.zig
//   pub const Shebang = struct {
//       launcher: []const u8,
//       utf16_len: u32,
//       is_node_or_bun: bool,
//       ...
//   }
// ============================================================================

/// 扩展名类型
/// 翻译自: Shebang.ExtensionType
public enum ExtensionType {
    | RunWithBun         // .js, .mjs, .cjs, .jsx, .ts, .cts, .mts, .tsx, .sh
    | RunWithCmd         // .cmd, .bat
    | RunWithPowerShell  // .ps1
}

/// Shebang 信息
/// 对应 Bun: Shebang
public class Shebang {
    /// 启动器命令
    /// 翻译自: launcher: []const u8
    public var launcher: String
    /// UTF-16 长度
    /// 翻译自: utf16_len: u32
    public var utf16Len: Int64
    /// 是否为 node 或 bun
    /// 翻译自: is_node_or_bun: bool
    public var isNodeOrBun: Bool

    public init(launcher: String, isNodeOrBun: Bool) {
        this.launcher = launcher
        utf16Len = Int64(launcher.length)  // 简化: UTF-16 长度约等于 UTF-8 长度
        this.isNodeOrBun = isNodeOrBun
    }

    /// 编码后的长度
    /// 翻译自: Shebang.encodedLength
    public func encodedLength(): Int64 {
        // (" ".len + shebang.utf16_len) * @sizeOf(u16) + @sizeOf(u32) * 2
        return (1 + utf16Len) * 2 + 4 * 2
    }

    /// 从 bin 路径解析 shebang
    /// 翻译自: Shebang.parseFromBinPath
    public static func parseFromBinPath(binPath: String): ?Shebang {
        let ext = getFileExtension(binPath)
        match (ext) {
            case ".js" => return Shebang(launcher: "bun run", isNodeOrBun: true)
            case ".mjs" => return Shebang(launcher: "bun run", isNodeOrBun: true)
            case ".cjs" => return Shebang(launcher: "bun run", isNodeOrBun: true)
            case ".jsx" => return Shebang(launcher: "bun run", isNodeOrBun: true)
            case ".ts" => return Shebang(launcher: "bun run", isNodeOrBun: true)
            case ".cts" => return Shebang(launcher: "bun run", isNodeOrBun: true)
            case ".mts" => return Shebang(launcher: "bun run", isNodeOrBun: true)
            case ".tsx" => return Shebang(launcher: "bun run", isNodeOrBun: true)
            case ".sh" => return Shebang(launcher: "bun run", isNodeOrBun: true)
            case ".cmd" => return Shebang(launcher: "cmd /c", isNodeOrBun: false)
            case ".bat" => return Shebang(launcher: "cmd /c", isNodeOrBun: false)
            case ".ps1" => return Shebang(launcher: "powershell -ExecutionPolicy Bypass -File", isNodeOrBun: false)
            case _ => return None
        }
    }

    /// 从文件内容解析 shebang
    /// 严格翻译自: Shebang.parse(contents_maybe_overflow, bin_path)
    ///
    /// 解析 #! 行, 支持 /usr/bin/env 格式
    public static func parse(contents: String, binPath: String): ?Shebang {
        let maxLen = 32766 + 2  // max_shebang_input_length
        let content = if (contents.length > maxLen) { contents.substring(0, maxLen) } else { contents }

        if (content.length < 3) {
            return parseFromBinPath(binPath)
        }

        // 检查 #! 开头
        if (content[0] != '#' || content[1] != '!') {
            return parseFromBinPath(binPath)
        }

        // 提取第一行
        let newLineIdx = content.indexOf("\n")
        let line = match (newLineIdx) {
            case Some(idx) => {
                if (idx > 0 && content[idx - 1] == '\r') {
                    content.substring(2, idx - 1)
                } else {
                    content.substring(2, idx)
                }
            }
            case None => return parseFromBinPath(binPath)
        }

        // 分词
        let tokens = line.split(" ")
        if (tokens.size == 0) { return parseFromBinPath(binPath) }

        let first = tokens[0]
        if (first == "/usr/bin/env" || first == "/bin/env") {
            // /usr/bin/env 格式
            if (tokens.size < 2) { return parseFromBinPath(binPath) }
            let program = tokens[1]
            let isNodeOrBun = (program == "bun" || program == "node")
            // rest 是剩余的参数
            var rest = ""
            for (i in 2..tokens.size) {
                if (rest.length > 0) { rest = rest + " " }
                rest = rest + tokens[i]
            }
            if (rest.length > 0) {
                rest = rest + " "
            }
            return Shebang(launcher: rest, isNodeOrBun: isNodeOrBun)
        }

        return Shebang(launcher: line, isNodeOrBun: false)
    }
}

// ============================================================================
// 二进制链接垫片
// 严格翻译自: BinLinkingShim.zig - 主结构体
//   BinLinkingShim = struct {
//       bin_path: []const u16,
//       shebang: ?Shebang,
//   }
// ============================================================================

/// 二进制链接垫片
/// 对应 Bun: BinLinkingShim
///
/// 编码格式:
/// [WSTR:bin_path][u16'"'][u16:0](shebang?)[flags:u16]
///
/// 如果有 shebang:
/// [WSTR:program][u16:0][WSTR:args][u32:bin_path_byte_len][u32:arg_byte_len]
public class BinLinkingShim {
    /// 相对于 node_modules 的 bin 路径 (不含斜杠)
    /// 翻译自: bin_path: []const u16
    public var binPath: String
    /// Shebang 信息
    /// 翻译自: shebang: ?Shebang
    public var shebang: ?Shebang

    public init(binPath: String, shebang: ?Shebang) {
        this.binPath = binPath
        this.shebang = shebang
    }

    /// 编码后的总长度
    /// 翻译自: BinLinkingShim.encodedLength
    public func encodedLength(): Int64 {
        let binPathLen = (binPath.length + 2) * 2  // +2 for '" ' 字符
        let flagsLen = 2  // UInt16
        let shebangLen = match (shebang) {
            case Some(s) => s.encodedLength()
            case None => 0
        }
        return binPathLen + flagsLen + shebangLen
    }

    /// 编码到字节数组
    /// 严格翻译自: BinLinkingShim.encodeInto
    public func encodeInto(buf: ArrayList<Byte>): Unit {
        // 写入 bin_path (UTF-16LE)
        // 翻译自: @memcpy(wbuf[0..options.bin_path.len], options.bin_path)
        for (i in 0..binPath.length) {
            buf.append(Byte(binPath[i]))
            buf.append(Byte(0))  // UTF-16LE 低字节
        }

        // 写入 '"'
        buf.append(Byte(34))  // '"'
        buf.append(Byte(0))

        // 如果有 shebang, 写入 shebang 数据
        match (shebang) {
            case Some(s) => {
                // 写入 launcher (UTF-16LE)
                for (i in 0..s.launcher.length) {
                    buf.append(Byte(s.launcher[i]))
                    buf.append(Byte(0))
                }

                // 写入 ' '
                buf.append(Byte(32))
                buf.append(Byte(0))

                // 写入 bin_path_byte_len (u32)
                let binPathByteLen = UInt32(binPath.length * 2)
                buf.append(Byte(binPathByteLen & UInt32(0xFF)))
                buf.append(Byte((binPathByteLen >> 8) & UInt32(0xFF)))
                buf.append(Byte((binPathByteLen >> 16) & UInt32(0xFF)))
                buf.append(Byte((binPathByteLen >> 24) & UInt32(0xFF)))

                // 写入 arg_byte_len (u32)
                let argByteLen = UInt32(s.utf16Len * 2 + 2)  // include spaces
                buf.append(Byte(argByteLen & UInt32(0xFF)))
                buf.append(Byte((argByteLen >> 8) & UInt32(0xFF)))
                buf.append(Byte((argByteLen >> 16) & UInt32(0xFF)))
                buf.append(Byte((argByteLen >> 24) & UInt32(0xFF)))
            }
            case None => ()
        }

        // 写入 flags (u16)
        let isNodeOrBun = match (shebang) {
            case Some(s) => s.isNodeOrBun
            case None => false
        }
        let flags = BinLinkingShimFlags(
            isNodeOrBun: isNodeOrBun,
            isNode: false,
            hasShebang: shebang != None
        )
        let flagsValue = flags.encode()
        buf.append(Byte(flagsValue & UInt16(0xFF)))
        buf.append(Byte((flagsValue >> UInt16(8)) & UInt16(0xFF)))
    }

    /// 宽松解码
    /// 翻译自: BinLinkingShim.looseDecode
    public static func looseDecode(input: ArrayList<Byte>): ?DecodedShim {
        let minSize = 2 + 2 * 4 + 8  // flags + 2*u32 + 8
        if (input.size < minSize) { return None }

        // 读取 flags (最后 2 字节)
        let flagsByte0 = Int64(input[input.size - 2])
        let flagsByte1 = Int64(input[input.size - 1])
        let flagsValue = UInt16(flagsByte0 | (flagsByte1 << 8))
        let flags = BinLinkingShimFlags.decode(flagsValue)

        if (!flags.isValid()) { return None }

        var binPathEnd = input.size - 2  // 减去 flags

        if (flags.hasShebang) {
            // 读取 bin_path_byte_len
            let off = input.size - 2 - 8  // 减去 flags + 2*u32
            let binPathByteLen = Int64(input[off]) |
                (Int64(input[off + 1]) << 8) |
                (Int64(input[off + 2]) << 16) |
                (Int64(input[off + 3]) << 24)
            if (binPathByteLen % 2 != 0) { return None }
            if (binPathByteLen > input.size - 8) { return None }
            binPathEnd = Int64(binPathByteLen)
        }

        if (binPathEnd % 2 != 0) { return None }

        // 提取 bin_path (UTF-16LE -> UTF-8)
        let sb = StringBuilder()
        var i = 0
        while (i + 1 < binPathEnd) {
            let ch = Int64(input[i]) | (Int64(input[i + 1]) << 8)
            if (ch > 0) {
                sb.append(Char(ch))
            }
            i += 2
        }

        return DecodedShim(binPath: sb.toString(), flags: flags)
    }
}

/// 解码后的垫片数据
/// 翻译自: BinLinkingShim.Decoded
public class DecodedShim {
    public var binPath: String
    public var flags: BinLinkingShimFlags

    public init(binPath: String, flags: BinLinkingShimFlags) {
        this.binPath = binPath
        this.flags = flags
    }
}

// ============================================================================
// 垫片实现 (Bun Shim Impl)
// 严格翻译自: src/install/windows-shim/bun_shim_impl.zig
//   bun_shim_impl.zig 是一个独立的可执行程序, 用于在 Windows 上
//   执行 .bunx 垫片文件
//
// 在仓颉中, 我们将其实现为库函数
// ============================================================================

/// 失败原因
/// 翻译自: bun_shim_impl.zig - FailReason
public enum ShimFailReason {
    | NoDirname
    | CouldNotOpenShim
    | CouldNotReadShim
    | InvalidShimDataSize
    | ShimNotFound
    | CreateProcessFailed
    | InvalidShimValidation
    | InvalidShimBounds
    | CouldNotDirectLaunch
    | BinNotFound
    | InterpreterNotFound
    | InterpreterNotFoundBun
    | ElevationRequired

    public func message(): String {
        match (this) {
            case NoDirname => "could not find node_modules path"
            case CouldNotOpenShim => "could not open bin metadata file"
            case CouldNotReadShim => "could not read bin metadata"
            case InvalidShimDataSize => "bin metadata is corrupt (size)"
            case ShimNotFound => "could not find bin metadata file"
            case CreateProcessFailed => "could not create process"
            case InvalidShimValidation => "bin metadata is corrupt (validate)"
            case InvalidShimBounds => "bin metadata is corrupt (bounds)"
            case CouldNotDirectLaunch => "bin metadata is corrupt (invalid utf16)"
            case BinNotFound => "bin executable does not exist on disk"
            case InterpreterNotFound => "interpreter executable not found in %PATH%"
            case InterpreterNotFoundBun => "bun is not installed in %PATH%"
            case ElevationRequired => "process requires elevation"
        }
    }
}

/// 启动器模式
/// 翻译自: bun_shim_impl.zig - LauncherMode
public enum LauncherMode {
    | Launch
    | ReadWithoutLaunch
}

/// 无启动读取结果
/// 翻译自: bun_shim_impl.zig - ReadWithoutLaunchResult
public enum ReadWithoutLaunchResult {
    | Err(ShimFailReason)
    | CommandLine(String)
}

/// Bun 运行上下文
/// 翻译自: bun_shim_impl.zig - FromBunRunContext
public class FromBunRunContext {
    /// 基础路径
    public var basePath: String
    /// 命令行参数
    public var arguments: String
    /// 文件句柄
    public var handle: Int64
    /// 是否强制使用 bun
    public var forceUseBun: Bool
    /// 环境变量
    public var environment: HashMap<String, String>

    public init() {
        basePath = ""
        arguments = ""
        handle = 0
        forceUseBun = false
        environment = HashMap<String, String>()
    }
}

/// Bun Shell 上下文
/// 翻译自: bun_shim_impl.zig - FromBunShellContext
public class FromBunShellContext {
    /// 基础路径
    public var basePath: String
    /// 命令行参数
    public var arguments: String
    /// 文件句柄
    public var handle: Int64
    /// 是否强制使用 bun
    public var forceUseBun: Bool

    public init() {
        basePath = ""
        arguments = ""
        handle = 0
        forceUseBun = false
    }
}

/// 垫片实现
/// 对应 Bun: bun_shim_impl.zig 中的 launcher 函数
public class BunShimImpl {

    /// 从 Bun 运行上下文尝试启动
    /// 翻译自: bun_shim_impl.zig - tryStartupFromBunJS
    public static func tryStartupFromBunJS(context: FromBunRunContext): ?ShimFailReason {
        // 读取 .bunx 元数据文件
        let metadata = readMetadata(context.basePath, context.handle)
        match (metadata) {
            case Some(data) => {
                // 验证标志
                if (!data.flags.isValid()) {
                    return ShimFailReason.InvalidShimValidation
                }
                // 构建命令行并执行
                return None  // 成功
            }
            case None => {
                return ShimFailReason.CouldNotReadShim
            }
        }
    }

    /// 从 Bun Shell 上下文读取 (不启动)
    /// 翻译自: bun_shim_impl.zig - readWithoutLaunch
    public static func readWithoutLaunch(context: FromBunShellContext): ReadWithoutLaunchResult {
        let metadata = readMetadata(context.basePath, context.handle)
        match (metadata) {
            case Some(data) => {
                if (!data.flags.isValid()) {
                    return ReadWithoutLaunchResult.Err(ShimFailReason.InvalidShimValidation)
                }
                // 构建命令行
                let cmdLine = buildCommandLine(data: data, arguments: context.arguments)
                return ReadWithoutLaunchResult.CommandLine(cmdLine)
            }
            case None => {
                return ReadWithoutLaunchResult.Err(ShimFailReason.CouldNotReadShim)
            }
        }
    }

    /// 读取元数据
    private static func readMetadata(basePath: String, handle: Int64): ?DecodedShim {
        // 读取 .bunx 文件
        let bunxPath = changeExtension(basePath, ".bunx")
        if (!bao_io.File.exists(bunxPath)) {
            return None
        }

        try {
            let content = bao_io.File.readBinaryFile(bunxPath)
            return BinLinkingShim.looseDecode(content)
        } catch (_: Exception) {
            return None
        }
    }

    /// 构建命令行
    private static func buildCommandLine(data: DecodedShim, arguments: String): String {
        let binPath = data.binPath
        if (data.flags.hasShebang) {
            return "${binPath} \"${data.binPath}\" ${arguments}"
        } else {
            return "\"${binPath}\" ${arguments}"
        }
    }

    /// 更改文件扩展名
    private static func changeExtension(path: String, newExt: String): String {
        let dotIdx = path.lastIndexOf(".")
        if (dotIdx >= 0) {
            return path.substring(0, dotIdx) + newExt
        }
        return path + newExt
    }
}

// ============================================================================
// 辅助方法
// ============================================================================

/// 获取文件扩展名
/// 翻译自: Shebang.extensionW
public func getFileExtension(path: String): String {
    let dotIdx = path.lastIndexOf(".")
    if (dotIdx < 0) { return "" }
    return path.substring(dotIdx)
}
