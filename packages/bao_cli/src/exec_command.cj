// 严格翻译自: src/cli/exec_command.zig
package bao_cli

import bao_core.*
import bao_install.*

// ============================================================================
// ExecCommand — exec 子命令
// 严格翻译自: src/cli/exec_command.zig
//
// 执行 shell 脚本代码字符串
// ============================================================================

/// exec 命令: 执行 shell 脚本代码
/// 对应 Bun: ExecCommand
public class ExecCommand {
    /// 执行 exec 命令
    /// 对应 Bun: ExecCommand.exec()
    public static func exec(ctx: CommandContext): Unit {
        val script = ctx.positionals[1]

        // 创建 Transpiler 以运行环境变量加载器
        // 对应 Bun: 创建 dummy bundler 并运行 env loader
        val bundle = Transpiler.init(
            ctx.allocator,
            ctx.log,
            Config.configureTransformOptionsForBunVM(ctx.allocator, ctx.args),
            None
        )
        bundle.runEnvLoader(bundle.options.env.disableDefaultEnvFiles)

        // 获取当前工作目录
        val cwd = Sys.getcwd()

        // 构建 script_path
        val parts: ArrayList<String> = ArrayList<String>()
        parts.append(cwd)
        parts.append("[eval]")
        val scriptPath = Path.join(parts)

        // 通过 shell 解释器执行脚本
        // 对应 Bun: bun.shell.Interpreter.initAndRunFromSource
        val code = ShellInterpreter.initAndRunFromSource(ctx, bundle.env, cwd, scriptPath, script, None)

        Global.exit(code)
    }
}
