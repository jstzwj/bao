// 严格翻译自: src/runtime/cli/fuzzilli_command.zig
package bao_runtime

import bao_core.*
import bao_io.*
import bao_sys.*

// ============================================================================
// FuzzilliCommand — Fuzzilli 模糊测试命令
// 严格翻译自: src/runtime/cli/fuzzilli_command.zig - FuzzilliCommand struct
// 注意: Zig 版本使用条件编译 (bun.Environment.enable_fuzzilli)
// 仓颉版本使用运行时标志
// ============================================================================

/// Fuzzilli 模糊测试命令
/// 对应 Bun: FuzzilliCommand (条件编译, enable_fuzzilli 时为 struct, 否则为 {})
public class FuzzilliCommand {
    /// REPRL 文件描述符
    /// 翻译自: const REPRL_CRFD: c_int = 100
    public static let REPRL_CRFD: Int32 = Int32(100)

    /// REPRL 脚本模板
    /// 翻译自: @embedFile("../js/eval/fuzzilli-reprl.ts")
    /// Fuzzilli REPRL (Read-Eval-Print-Loop) 桥接脚本
    private static let REPRL_SCRIPT: String =
        "// Bao Fuzzilli REPRL Bridge\n" +
        "// This script bridges Fuzzilli's IPC with the Bao runtime\n" +
        "\n" +
        "const REPRL_CRFD = 100;\n" +
        "const REPRL_CWFD = 101;\n" +
        "const REPRL_DRFD = 102;\n" +
        "\n" +
        "function reprl_read(fd, count) {\n" +
        "  const buf = new Buffer(count);\n" +
        "  let totalRead = 0;\n" +
        "  while (totalRead < count) {\n" +
        "    const n = Bao.syscall.read(fd, buf, totalRead, count - totalRead);\n" +
        "    if (n <= 0) break;\n" +
        "    totalRead += n;\n" +
        "  }\n" +
        "  return buf;\n" +
        "}\n" +
        "\n" +
        "function reprl_write(fd, buf, count) {\n" +
        "  let totalWritten = 0;\n" +
        "  while (totalWritten < count) {\n" +
        "    const n = Bao.syscall.write(fd, buf, totalWritten, count - totalWritten);\n" +
        "    if (n <= 0) break;\n" +
        "    totalWritten += n;\n" +
        "  }\n" +
        "}\n" +
        "\n" +
        "async function main() {\n" +
        "  while (true) {\n" +
        "    const actionBuf = reprl_read(REPRL_CRFD, 4);\n" +
        "    if (actionBuf.length < 4) break;\n" +
        "    const action = actionBuf.toString('ascii');\n" +
        "    if (action === 'exec') {\n" +
        "      const lenBuf = reprl_read(REPRL_CRFD, 4);\n" +
        "      if (lenBuf.length < 4) break;\n" +
        "      const scriptLen = lenBuf.readUInt32BE(0);\n" +
        "      const scriptBuf = reprl_read(REPRL_CRFD, scriptLen);\n" +
        "      const script = scriptBuf.toString('utf-8');\n" +
        "      let result = 0;\n" +
        "      try { new Function(script)(); result = 0; } catch (e) { result = 1; }\n" +
        "      const resultBuf = new Buffer(4);\n" +
        "      resultBuf.writeUInt32BE(result, 0);\n" +
        "      reprl_write(REPRL_CWFD, resultBuf, 4);\n" +
        "    } else if (action === 'exit') { break; }\n" +
        "  }\n" +
        "}\n" +
        "main();\n"

    /// 执行 Fuzzilli 模糊测试
    /// 对应 Bun: FuzzilliCommand.exec()
    /// 翻译自: @branchHint(.cold) — 仅在启用 fuzzilli 时调用
    public static func exec(ctx: CommandContext): Unit {
        // 仅支持 POSIX 系统
        // 翻译自: if (!Environment.isPosix) { ... }
        // Fuzzilli only supported on POSIX (true for Linux)
        if (false) {
            Output.prettyErrorln("error: Fuzzilli mode is only supported on POSIX systems")
            Global.exit(1)
        }

        // 验证 REPRL 文件描述符是否可用
        // 翻译自: verifyFd(REPRL_CRFD) catch { ... }
        if (!verifyFd(REPRL_CRFD)) {
            Output.prettyErrorln("error: REPRL_CRFD (fd ${Int64(REPRL_CRFD)}) is not available. Run Bao under Fuzzilli.")
            Output.prettyErrorln("Example: fuzzilli --profile=bao /path/to/bao fuzzilli")
            Global.exit(1)
        }

        // 打开 /tmp 目录
        // 翻译自: bun.sys.open("/tmp", bun.O.DIRECTORY | bun.O.RDONLY, 0)
        let tempDir = "/tmp"
        if (!BaoFile.isDirectory(tempDir)) {
            Output.prettyErrorln("error: Could not access /tmp directory")
            Global.exit(1)
        }

        // 创建临时文件
        // 翻译自: bun.sys.openat(temp_dir_fd, "bun-fuzzilli-reprl.js", ...)
        let tempFileName = "bao-fuzzilli-reprl.js"
        let tempFilePath = "${tempDir}/${tempFileName}"

        // 写入 REPRL 脚本到临时文件
        // 翻译自: bun.sys.write(temp_file_fd, reprl_script)
        let writeResult = BaoFile.writeAllText(tempFilePath, REPRL_SCRIPT)
        match (writeResult) {
            case SysMaybe<Unit>.Err(_) =>
                Output.prettyErrorln("error: Could not create temp file at ${tempFilePath}")
                Global.exit(1)
            case _ => ()
        }

        Output.prettyErrorln("[FUZZILLI] Temp file written to ${tempFilePath}, booting JS runtime")

        // 运行临时文件
        // 翻译自: try Run.boot(ctx, temp_path, null)
        runFuzzilliScript(ctx, tempFilePath)
    }

    /// 验证文件描述符是否可用
    /// 翻译自: FuzzilliCommand.verifyFd — 使用 fstat 检查 fd 是否有效
    private static func verifyFd(fd: Int32): Bool {
        let result = LinuxSyscall.fstat(fd)
        match (result) {
            case SysMaybe<PosixStat>.Ok(_) => return true
            case SysMaybe<PosixStat>.Err(_) => return false
        }
    }

    /// 运行 Fuzzilli 脚本
    /// 翻译自: Run.boot(ctx, temp_path, null)
    /// 启动 JS 运行时执行 REPRL 桥接脚本
    private static func runFuzzilliScript(ctx: CommandContext, scriptPath: String): Unit {
        // TODO: implement with RunCommandConfig
        ctx.positionals.clear()
        ctx.positionals.append(scriptPath)
        RunCommand.exec(ctx)
    }
}
