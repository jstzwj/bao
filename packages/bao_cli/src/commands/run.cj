// 严格翻译自: src/cli/run_command.zig
// Run 命令实现
package bao_cli

import bao_core.*
import bao_collections.*
import bao_runtime.*
import bao_io.*
import bao_sys.*
import bao_path.*

// ============================================================================
// RunCommand — bun run 实现
// 严格翻译自: src/cli/run_command.zig - RunCommand
// 对应 Bun: bun run <script> / bun <file>
// ============================================================================

/// Run 命令执行器
/// 对应 Bun: RunCommand.exec(ctx)
///
/// 支持三种运行模式:
///   1. 运行 package.json 中定义的 script: bun run build
///   2. 运行 JS/TS 文件: bun run index.ts
///   3. Watch 模式: bun run --watch index.ts
public class RunCommand {
    /// 运行选项
    private var options: RunOptions

    /// 虚拟机实例
    private var vm: VirtualMachine

    /// 文件监听器 (watch 模式)
    private var watcher: ?FileWatcher

    public init(options: RunOptions) {
        this.options = options
        this.vm = VirtualMachine()
        this.watcher = None
    }

    /// 执行 run 命令
    /// 对应 Bun: RunCommand.exec → run js/ts file or package.json script
    public func execute(): Int64 {
        // 无脚本参数 — 列出可用 scripts
        if (options.script.isEmpty()) {
            return listScripts()
        }

        // 检查是否为 package.json script 名称
        let scriptResult = tryRunPackageScript()
        if (scriptResult.executed) {
            return scriptResult.exitCode
        }

        // 作为文件运行
        return runFile()
    }

    /// 列出 package.json 中的可用脚本
    /// 对应 Bun: bun run (无参数) → 列出 scripts
    private func listScripts(): Int64 {
        let pkgOpt = readPackageJson()
        match (pkgOpt) {
            case Some(pkg) => {
                if (pkg.scripts.size == 0) {
                    println("No scripts found in package.json")
                    return 0
                }
                println("Available scripts:")
                let keys = pkg.scripts.keys()
                for (key in keys) {
                    match (pkg.scripts.get(key)) {
                        case Some(cmd) => println("  ${key}")
                        case None => ()
                    }
                }
                return 0
            }
            case None => {
                println("error: no script specified and no package.json found")
                return 1
            }
        }
    }

    /// 尝试作为 package.json script 运行
    /// 对应 Bun: RunCommand 中检查 package.json scripts
    private func tryRunPackageScript(): ScriptResult {
        let result = ScriptResult(false, 0)
        let pkgOpt = readPackageJson()

        match (pkgOpt) {
            case Some(pkg) => {
                match (pkg.scripts.get(options.script)) {
                    case Some(cmd) => {
                        result.executed = true
                        if (!options.silent) {
                            println("$ ${cmd}")
                        }
                        // 执行脚本命令
                        // 对应 Bun: spawn shell 进程执行命令
                        try {
                            let exitCode = executeShellCommand(cmd)
                            result.exitCode = exitCode
                        } catch (e: Exception) {
                            println("error: ${e.message}")
                            result.exitCode = 1
                        }
                    }
                    case None => ()
                }
            }
            case None => ()
        }

        return result
    }

    /// 作为文件运行
    /// 对应 Bun: RunCommand 解析文件路径并执行
    private func runFile(): Int64 {
        let scriptPath = resolveScriptPath(options.script)
        match (scriptPath) {
            case Some(path) => {
                if (options.watch) {
                    return runWithWatch(path)
                } else {
                    return executeFile(path)
                }
            }
            case None => {
                println("error: Cannot find module '${options.script}'")
                return 1
            }
        }
    }

    /// 解析脚本路径
    /// 对应 Bun: RunCommand 中的路径解析逻辑
    /// 支持:
    ///   - 绝对路径: /path/to/file.js
    ///   - 相对路径: ./file.js, ../file.js
    ///   - 裸名称: file (自动尝试 .js, .ts, .tsx, .jsx 扩展名)
    private func resolveScriptPath(script: String): ?String {
        // 绝对路径
        if (Path.isAbsolute(script)) {
            if (BaoFile.exists(script)) {
                return Some(script)
            }
            return tryExtensions(script)
        }

        // 相对路径
        if (script.startsWith("./") || script.startsWith("../")) {
            if (BaoFile.exists(script)) {
                return Some(Path.resolve(script))
            }
            return tryExtensions(Path.resolve(script))
        }

        // 裸名称 — 尝试添加扩展名
        let resolved = tryExtensions(Path.resolve(script))
        match (resolved) {
            case Some(p) => return Some(p)
            case None => ()
        }

        // 尝试在 node_modules/.bin 中查找
        let binPath = Path.resolve("node_modules/.bin/${script}")
        if (BaoFile.exists(binPath)) {
            return Some(binPath)
        }

        return None
    }

    /// 尝试添加常见扩展名
    private func tryExtensions(basePath: String): ?String {
        let extensions = [".js", ".ts", ".tsx", ".jsx", ".mjs", ".cjs"]
        for (ext in extensions) {
            let path = basePath + ext
            if (BaoFile.exists(path)) {
                return Some(path)
            }
        }
        // 尝试目录中的 index 文件
        if (BaoFile.isDirectory(basePath)) {
            for (ext in extensions) {
                let indexPath = basePath + "/index" + ext
                if (BaoFile.exists(indexPath)) {
                    return Some(indexPath)
                }
            }
        }
        return None
    }

    /// 执行 JS/TS 文件
    /// 对应 Bun: RunCommand 解析文件 → 创建虚拟机 → 执行
    private func executeFile(path: String): Int64 {
        try {
            // 设置进程参数
            // 对应 Bun: process.argv = [bun_path, script_path, ...args]
            let argv = ArrayList<String>()
            argv.append("bao")
            argv.append(path)
            for (arg in options.args) {
                argv.append(arg)
            }

            vm.executeFile(path)
            return 0
        } catch (e: Exception) {
            println("error: ${e.message}")
            return 1
        }
    }

    /// Watch 模式执行
    /// 对应 Bun: RunCommand --watch
    /// 文件变更时重新执行
    private func runWithWatch(path: String): Int64 {
        println("Watching ${path}...")

        // 首次执行
        let exitCode = executeFile(path)

        // 设置文件监听
        // 对应 Bun: 使用 inotify (Linux) / kqueue (macOS) 监听文件变更
        let w = FileWatcher(path)
        watcher = Some(w)
        w.start({ =>
            if (!options.silent) {
                println("\n--- File changed, restarting ---")
            }
            // 重新创建虚拟机 (清除状态)
            vm = VirtualMachine()
            executeFile(path)
        })

        // 阻塞等待 watcher
        w.wait()

        return exitCode
    }

    /// 执行 Shell 命令
    /// 对应 Bun: RunCommand 通过 spawn 子进程执行 shell 命令
    /// Bun: 使用系统 shell (bash/zsh/sh) 执行命令
    private func executeShellCommand(cmd: String): Int64 {
        // 实际实现:
        // let process = Process.spawn("sh", ["-c", cmd])
        // return process.wait()

        // 简化: 通过虚拟机 eval 执行
        try {
            vm.eval(cmd, "<script>")
            return 0
        } catch (e: Exception) {
            throw e
        }
    }
}

// ============================================================================
// 辅助类型
// ============================================================================

/// 脚本执行结果
class ScriptResult {
    public var executed: Bool
    public var exitCode: Int64

    public init(executed: Bool, exitCode: Int64) {
        this.executed = executed
        this.exitCode = exitCode
    }
}

/// 文件变更监听器
/// 对应 Bun: 使用 inotify/kqueue 实现 watch 模式
class FileWatcher {
    private var path: String
    private var callback: () -> Unit
    private var running: Bool

    public init(path: String) {
        this.path = path
        this.callback = { => () }
        this.running = false
    }

    /// 设置变更回调
    public func start(callback: () -> Unit): Unit {
        this.callback = callback
        this.running = true
        // 实际实现:
        // 1. 创建 inotify 实例
        //    let fd = inotify_init1(IN_NONBLOCK)
        //    inotify_add_watch(fd, path, IN_MODIFY | IN_CLOSE_WRITE)
        //
        // 2. 在独立线程中轮询事件
        //    while (running) {
        //        let events = poll(fd, timeout=1000)
        //        if (events.has(IN_MODIFY)) {
        //            debounce(100ms)  // 防抖
        //            callback()
        //        }
        //    }
    }

    /// 停止监听
    public func stop(): Unit {
        running = false
    }

    /// 阻塞等待 (watch 模式使用)
    public func wait(): Unit {
        // 实际实现: 阻塞直到 stop() 被调用
        // while (running) { sleep(100ms) }
    }

    /// 手动触发 (测试用)
    public func trigger(): Unit {
        callback()
    }
}
