// bao_install.windows_shim - Windows Shim 入口点
// 严格翻译自: src/install/windows-shim/main.rs
//   main.rs 是 bun_shim_impl.exe 的入口点
//   在 Windows 上作为 node_modules/.bin 中可执行文件的 shim
//   读取 .bunx 配置, 解析 shebang, 启动子进程
package bao_install.windows_shim

import bao_core.*
import bao_collections.*
import bao_sys.*

// ============================================================================
// Shim 主入口
// 严格翻译自: src/install/windows-shim/main.rs
//   main.rs 是独立 PE 的入口点
//   在 freestanding 模式下运行 (no_std + no_main)
//   通过 shim_main 函数被调用
//   此处简化为普通仓颉函数
// ============================================================================

/// Shim 主入口函数
/// 翻译自: main.rs — shim_main / _bun_shim_impl::main()
///   PE 入口点 (通过 /ENTRY:shim_main 指定)
///   1. 从 TEB/PEB 获取进程参数 (命令行, 图像路径)
///   2. 读取 .bunx 文件内容
///   3. 解码 shim 配置
///   4. 构建命令行
///   5. CreateProcessW 启动子进程
///   6. WaitForSingleObject 等待完成
///   7. GetExitCodeProcess 获取退出码
///   8. RtlExitUserProcess 退出
public class ShimMain {
    /// 主入口
    /// 翻译自: shim_main() -> !
    public static func main(): Int64 {
        // 翻译自: main.rs 中的 shim_main
        //   1. 获取命令行参数
        //   2. 获取当前可执行文件路径 (shim 路径)
        //   3. 构造 .bunx 文件路径 (shim 路径 + ".bunx")
        //   4. 读取并解码 .bunx 文件
        //   5. 根据 flags 处理 shebang
        //   6. 启动子进程

        // 获取当前可执行文件路径
        let shimPath = SysModule.getExecutablePath()
        if (shimPath.size == 0) {
            Output.prettyErrorln("error: failed to get shim path")
            return 1
        }

        // 执行 shim
        return BunShimImpl.executeShim(shimPath, SysModule.getArgs())
    }
}

// ============================================================================
// CRT stubs (Windows 特定)
// 严格翻译自: main.rs — _fltused / __chkstk
//   在 Windows PE 中, 这些是 CRT 需要的链接时符号
//   在仓颉中不需要, 但保留注释说明
// ============================================================================

/// _fltused 标记
/// 翻译自: pub static _fltused: i32 = 0
/// MSVC CRT 中当翻译单元涉及浮点时引用的链接时标记
/// 在仓颉中不需要
public let FLTUSED: Int32 = Int32(0)

// ============================================================================
// 辅助函数
// ============================================================================

/// 从 PEB 获取命令行参数
/// 翻译自: main.rs 中通过 TEB -> PEB -> ProcessParameters 获取参数
///   在 Windows 上使用 NtQueryInformationProcess
///   在仓颉中使用 SysModule.getArgs()
public class ShimArgs {
    /// 获取命令行参数列表
    public static func getCommandLineArgs(): ArrayList<String> {
        return SysModule.getArgs()
    }

    /// 获取可执行文件路径
    public static func getExecutablePath(): String {
        return SysModule.getExecutablePath()
    }
}

/// 处理退出
/// 翻译自: RtlExitUserProcess(ExitStatus)
public class ShimExit {
    public static func exit(code: Int64): Unit {
        SysModule.exit(code)
    }
}
