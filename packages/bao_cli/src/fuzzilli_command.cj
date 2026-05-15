// 严格翻译自: src/cli/fuzzilli_command.zig
package bao_cli

import bao_core.*

// ============================================================================
// FuzzilliCommand — Fuzzilli 模糊测试命令
// 严格翻译自: src/cli/fuzzilli_command.zig - FuzzilliCommand struct
// 注意: Zig 版本使用条件编译 (bun.Environment.enable_fuzzilli)
// 仓颉版本使用运行时标志
// ============================================================================

/// Fuzzilli 模糊测试命令
/// 对应 Bun: FuzzilliCommand (条件编译)
public class FuzzilliCommand {
    /// REPRL 文件描述符
    public static let REPRL_CRFD: Int64 = 100

    /// 执行 Fuzzilli 模糊测试
    /// 对应 Bun: FuzzilliCommand.exec()
    public static func exec(ctx: CommandContext): Unit {
        // 仅支持 POSIX 系统
        if (!Environment.isPosix) {
            Output.prettyErrorLn("error: Fuzzilli mode is only supported on POSIX systems")
            Global.exit(1)
        }

        // 设置环境变量以在 JavaScript 中检测 fuzzilli 模式
        // 验证 REPRL 文件描述符是否可用
        if (!verifyFd(REPRL_CRFD)) {
            Output.prettyErrorLn("error: REPRL_CRFD (fd ${REPPL_CRFD}) is not available. Run Bun under Fuzzilli.")
            Output.prettyErrorLn("Example: fuzzilli --profile=bun /path/to/bun fuzzilli")
            Global.exit(1)
        }

        // REPRL 脚本 (嵌入)
        val reprlScript = FuzzilliReprl.getScript()

        // 打开 /tmp 目录
        val tempDir = "/tmp"

        // 创建临时文件
        val tempFileName = "bun-fuzzilli-reprl.js"
        val tempPath = "${tempDir}/${tempFileName}"

        // 写入脚本到临时文件
        BaoFile.writeAllText(tempPath, reprlScript)

        Output.prettyErrorLn("[FUZZILLI] Temp file written, booting JS runtime")

        // 运行临时文件
        val runOpts = RunOptions()
        runOpts.script = tempPath
        RunCommand.execute(ctx, runOpts)
    }

    /// 验证文件描述符是否可用
    private static func verifyFd(fd: Int64): Bool {
        return Sys.fstat(fd) != null
    }
}
