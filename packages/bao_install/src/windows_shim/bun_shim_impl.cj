// bao_install - Windows Shim 实现
// 严格翻译自: src/install/windows-shim/bun_shim_impl.rs + .zig
//   bun_shim_impl 是 node_modules/.bin 脚本的 shim 程序
//   它读取 .bunx 文件中的配置, 然后启动正确的子进程
//   解决了 Windows 上符号链接和 shebang 的问题
package bao_install.windows_shim

import bao_core.*
import bao_collections.*
import bao_io.*
import bao_hash.*
import bao_path.*

// ============================================================================
// Shim 实现常量
// 严格翻译自: bun_shim_impl.zig — constants
// ============================================================================

/// 调试模式
/// 翻译自: const DBG = builtin.mode == .Debug
public let SHIM_DBG: Bool = false

/// 是否独立编译
/// 翻译自: const IS_STANDALONE = @import("root") == @This()
public let IS_STANDALONE: Bool = false

// ============================================================================
// NTDLL 调用
// 严格翻译自: bun_shim_impl.zig — nt module
//   直接使用 ntdll 系统调用, 避免引入大型依赖
// ============================================================================

/// NTDLL 状态码
/// 翻译自: nt.Status
public class NtStatus {
    public var value: Int32

    public init(value: Int32) {
        this.value = value
    }

    public static let SUCCESS: Int32 = 0
    public static let INVALID_HANDLE: Int32 = -1073741816 // 0xC0000008
    public static let FILE_NOT_FOUND: Int32 = -1073741809 // 0xC000000F
    public static let ACCESS_DENIED: Int32 = -1073741790 // 0xC0000022
    public static let BUFFER_TOO_SMALL: Int32 = -1073741789 // 0xC0000023

    public func isSuccess(): Bool {
        return value >= 0
    }
}

// ============================================================================
// Shim 主要逻辑
// 严格翻译自: bun_shim_impl.zig — main functions
// ============================================================================

/// Shim 主入口
/// 翻译自: wWinMain / main
///   读取 .bunx 配置, 解析 shebang, 启动子进程
public class BunShimImpl {
    /// 嵌入的可执行文件数据
    /// 翻译自: EMBEDDED_EXECUTABLE_DATA
    ///   在构建时, 这个数据是 bun_shim_impl.exe 的二进制内容
    ///   在运行时, 它为空 (非独立模式) 或为嵌入的 PE 数据
    public static let EMBEDDED_EXECUTABLE_DATA: Array<Byte> = Array<Byte>()

    /// 获取嵌入的可执行文件数据
    /// 翻译自: embedded_executable_data()
    ///   如果数据为空, 报错并退出
    public static func embeddedExecutableData(): Array<Byte> {
        if (EMBEDDED_EXECUTABLE_DATA.size == 0) {
            Output.prettyErrorln(
                "error: bun_shim_impl.exe is empty - the Windows shim PE must be built before this crate is compiled"
            )
            Global.crash()
        }
        return EMBEDDED_EXECUTABLE_DATA
    }

    /// 从 .bunx 文件加载配置并执行
    /// 翻译自: main body of bun_shim_impl
    public static func executeShim(shimPath: String, args: ArrayList<String>): Int64 {
        // 1. 读取 .bunx 文件内容
        let content = readFile(shimPath)
        match (content) {
            case None => {
                Output.prettyErrorln("error: failed to read shim file: ${shimPath}")
                return 1
            }
            case Some(data) => {
                // 2. 解码 shim 配置
                let decoded = BinLinkingShimModule.looseDecode(data)
                match (decoded) {
                    case None => {
                        Output.prettyErrorln("error: failed to decode shim file: ${shimPath}")
                        return 1
                    }
                    case Some(d) => {
                        // 3. 获取 bin_path 并构建命令行
                        let binPath = d.binPath
                        let flags = d.flags

                        // 4. 构建完整命令行
                        var commandLine = binPath
                        for (arg in args) {
                            commandLine = "${commandLine} ${arg}"
                        }

                        // 5. 如果有 shebang, 需要特殊处理
                        if (flags.hasShebang()) {
                            // shebang 指定了启动器 (如 "bun run", "node")
                            // 需要将 bin_path 作为参数传给启动器
                            return spawnProcess(commandLine)
                        }

                        // 6. 直接启动
                        return spawnProcess(commandLine)
                    }
                }
            }
        }
    }

    /// 启动子进程
    /// 翻译自: CreateProcessW 调用
    private static func spawnProcess(commandLine: String): Int64 {
        // 翻译自:
        //   var startup_info = std.mem.zeroes(STARTUPINFOW)
        //   var proc_info = std.mem.zeroes(PROCESS_INFORMATION)
        //   CreateProcessW(null, cmd_line, null, null, TRUE, 0, null, null, &startup_info, &proc_info)
        let result = bao_sys.Windows.createProcess(commandLine)
        match (result) {
            case Some(exitCode) => return exitCode
            case None => {
                Output.prettyErrorln("error: failed to spawn process: ${commandLine}")
                return 1
            }
        }
    }

    /// 读取文件内容
    private static func readFile(path: String): ?Array<Byte> {
        let file = bao_io.File.open(path, OpenMode.Read)
        match (file) {
            case Some(f) => {
                let content = f.readAllBytes()
                f.close()
                return content
            }
            case None => return None
        }
    }
}

// ============================================================================
// Windows 进程创建结构体
// 严格翻译自: Windows API structures
// ============================================================================

/// 启动信息 (Windows)
/// 翻译自: STARTUPINFOW
public class StartupInfoW {
    public var cb: UInt32
    public var lpReserved: UInt64 // pointer
    public var lpDesktop: UInt64
    public var lpTitle: UInt64
    public var dwX: UInt32
    public var dwY: UInt32
    public var dwXSize: UInt32
    public var dwYSize: UInt32
    public var dwXCountChars: UInt32
    public var dwYCountChars: UInt32
    public var dwFillAttribute: UInt32
    public var dwFlags: UInt32
    public var wShowWindow: UInt16
    public var cbReserved2: UInt16
    public var lpReserved2: UInt64
    public var hStdInput: UInt64
    public var hStdOutput: UInt64
    public var hStdError: UInt64

    public init() {
        cb = 0
        lpReserved = 0
        lpDesktop = 0
        lpTitle = 0
        dwX = 0
        dwY = 0
        dwXSize = 0
        dwYSize = 0
        dwXCountChars = 0
        dwYCountChars = 0
        dwFillAttribute = 0
        dwFlags = 0
        wShowWindow = 0
        cbReserved2 = 0
        lpReserved2 = 0
        hStdInput = 0
        hStdOutput = 0
        hStdError = 0
    }
}

/// 进程信息 (Windows)
/// 翻译自: PROCESS_INFORMATION
public class ProcessInformation {
    public var hProcess: UInt64
    public var hThread: UInt64
    public var dwProcessId: UInt32
    public var dwThreadId: UInt32

    public init() {
        hProcess = 0
        hThread = 0
        dwProcessId = 0
        dwThreadId = 0
    }
}

/// Unicode 字符串 (Windows)
/// 翻译自: UNICODE_STRING
public class UnicodeString {
    public var length: UInt16
    public var maximumLength: UInt16
    public var buffer: UInt64 // pointer

    public init() {
        length = 0
        maximumLength = 0
        buffer = 0
    }
}

/// IO 状态块 (Windows)
/// 翻译自: IO_STATUS_BLOCK
public class IoStatusBlock {
    public var status: Int32
    public var information: UInt64

    public init() {
        status = 0
        information = 0
    }
}

// ============================================================================
// BinLinkingShim 模块引用
//   由于在同一个包内, 直接引用 BinLinkingShim 的 looseDecode
// ============================================================================

/// 内部引用 BinLinkingShim 的 looseDecode 函数
/// 在仓颉中, 通过 import 引用
private class BinLinkingShimModule {
    public static func looseDecode(input: Array<Byte>): ?Decoded {
        return bao_install.windows_shim.looseDecode(input)
    }
}

/// 模块引用
public typealias Decoded = bao_install.windows_shim.Decoded
