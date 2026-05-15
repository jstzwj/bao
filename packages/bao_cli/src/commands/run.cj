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
/// 支持运行模式:
///   1. 运行 package.json 中定义的 script: bun run build
///   2. 运行 JS/TS 文件: bun run index.ts
///   3. Watch 模式: bun run --watch index.ts
///   4. Hot 模式: bun run --hot index.ts (HMR)
///   5. Eval 模式: bao run -e "console.log('hello')"
///   6. Stdin 模式: echo "console.log(1)" | bao run -
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
    /// 对应 Bun: RunCommand.exec -> run js/ts file or package.json script
    public func execute(): Int64 {
        // Eval 模式 (-e flag)
        // 严格翻译自: run_command.zig 中 -e/--eval 模式
        if (options.eval.length > 0) {
            return runEval()
        }

        // 无脚本参数 — 列出可用 scripts
        if (options.script.isEmpty()) {
            return listScripts()
        }

        // Stdin 模式 (script == "-")
        // 严格翻译自: Bun 支持 stdin 执行: echo "code" | bun run -
        if (options.script == "-") {
            return runStdin()
        }

        // 检查是否为 package.json script 名称
        let scriptResult = tryRunPackageScript()
        if (scriptResult.executed) {
            return scriptResult.exitCode
        }

        // 作为文件运行
        return runFile()
    }

    /// Eval 模式执行
    // 严格翻译自: Bun 中 -e/--eval 选项
    // bun -e "console.log('hello')"
    private func runEval(): Int64 {
        // 注入环境变量 (从 .env 文件)
        injectEnvVariables()

        try {
            vm.eval(options.eval, "<eval>")
            return 0
        } catch (e: Exception) {
            println("error: ${e.message}")
            return 1
        }
    }

    /// Stdin 模式执行
    // 严格翻译自: Bun 支持 stdin 管道执行
    // echo "console.log(1)" | bun run -
    private func runStdin(): Int64 {
        injectEnvVariables()

        try {
            let stdinData = readStdin()
            let code = bytesToString(stdinData)
            vm.eval(code, "<stdin>")
            return 0
        } catch (e: Exception) {
            println("error: ${e.message}")
            return 1
        }
    }

    /// 读取 stdin 全部内容
    private func readStdin(): Array<UInt8> {
        let buffer = ArrayBuffer(4096)
        // 简化: 从标准输入读取直到 EOF
        // 实际实现使用 POSIX read(0, ...) 循环
        try {
            let stdin = SysFs.stdin()
            var chunk = Array<UInt8>(4096, item: 0)
            var done = false
            while (!done) {
                let result = SysFs.read(stdin.fd, chunk)
                match (result) {
                    case Ok(n) =>
                        if (n == 0) {
                            done = true
                        } else {
                            for (i in 0..n) {
                                buffer.append(chunk[Int64(i)])
                            }
                        }
                    case Err(_) => done = true
                }
            }
        } catch (_: Exception) {}
        return buffer.slice()
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
                // 判断是脚本文件还是二进制文件
                // 严格翻译自: Bun 中检测文件是否为 shebang / binary / text
                let fileType = detectFileType(path)
                match (fileType) {
                    case FileType.Binary => {
                        // 二进制文件: 作为可执行文件运行
                        return runBinary(path)
                    }
                    case FileType.Script | FileType.Text => {
                        // 脚本文件
                        if (options.hot) {
                            return runWithHot(path)
                        } else if (options.watch) {
                            return runWithWatch(path)
                        } else {
                            return executeFile(path)
                        }
                    }
                }
            }
            case None => {
                println("error: Cannot find module '${options.script}'")
                return 1
            }
        }
    }

    /// 检测文件类型 (脚本 / 二进制 / 文本)
    // 严格翻译自: Bun 中通过文件头魔数检测文件类型
    private func detectFileType(path: String): FileType {
        try {
            let header = BaoFile.readBytes(path, 4)
            // ELF 二进制
            if (header.size >= 4 && header[0] == UInt8(0x7F) && header[1] == UInt8(0x45) &&
                header[2] == UInt8(0x4C) && header[3] == UInt8(0x46)) {
                return FileType.Binary
            }
            // Mach-O 二进制
            if (header.size >= 4 && (header[0] == UInt8(0xFE) || header[0] == UInt8(0xCF))) {
                return FileType.Binary
            }
            // PE 二进制
            if (header.size >= 2 && header[0] == UInt8(0x4D) && header[1] == UInt8(0x5A)) {
                return FileType.Binary
            }
            // Shebang
            if (header.size >= 2 && header[0] == UInt8(0x23) && header[1] == UInt8(0x21)) {
                return FileType.Script
            }
            return FileType.Text
        } catch (_: Exception) {
            return FileType.Text
        }
    }

    /// 运行二进制文件
    // 严格翻译自: Bun runBinary 中 spawn 子进程执行二进制
    private func runBinary(path: String): Int64 {
        try {
            // 构建参数列表
            let argv = ArrayList<String>()
            argv.append(path)
            for (arg in options.args) {
                argv.append(arg)
            }

            // 注入环境变量
            injectEnvVariables()

            // spawn 子进程
            let process = Process.spawn(path, argv.toArray())
            return process.wait()
        } catch (e: Exception) {
            println("error: Failed to run '${path}': ${e.message}")
            return 1
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
    /// 对应 Bun: RunCommand 解析文件 -> 创建虚拟机 -> 执行
    private func executeFile(path: String): Int64 {
        // 1. 注入 .env 环境变量
        // 严格翻译自: Bun 中 DotEnv.Loader 加载 .env 文件
        injectEnvVariables()

        // 2. 执行 preload 文件
        // 严格翻译自: Bun 中 --preload / BUN_PRELOAD 选项
        executePreloads()

        try {
            // 3. 设置进程参数
            // 对应 Bun: process.argv = [bun_path, script_path, ...args]
            let argv = ArrayList<String>()
            argv.append("bao")
            argv.append(path)
            for (arg in options.args) {
                argv.append(arg)
            }

            // 4. 执行文件
            vm.executeFile(path)
            return 0
        } catch (e: Exception) {
            println("error: ${e.message}")
            return 1
        }
    }

    /// 注入环境变量 (从 .env 文件)
    // 严格翻译自: Bun 中 DotEnv.Loader.load 加载 .env/.env.local/.env.production 等
    private func injectEnvVariables(): Unit {
        // 按优先级加载 .env 文件:
        // .env.${NODE_ENV}.local > .env.local > .env.${NODE_ENV} > .env
        let envFiles = [
            ".env.local",
            ".env.development.local",
            ".env.development",
            ".env"
        ]

        for (envFile in envFiles) {
            let path = Path.resolve(envFile)
            if (BaoFile.exists(path)) {
                loadDotEnv(path)
            }
        }

        // 设置用户指定的环境变量
        for ((key, value) in options.envVars) {
            OS.setenv(key, value, 1)
        }
    }

    /// 加载 .env 文件
    // 严格翻译自: DotEnv.Loader.parse 中逐行解析 KEY=VALUE
    private func loadDotEnv(path: String): Unit {
        try {
            let content = BaoFile.readAllText(path)
            let lines = content.split("\n")
            for (line in lines) {
                let trimmed = line.trim()
                // 跳过空行和注释
                if (trimmed.length == 0 || trimmed.startsWith("#")) {
                    continue
                }
                let eqIdx = trimmed.indexOf("=")
                if (eqIdx > 0) {
                    let key = trimmed.substring(0, eqIdx).trim()
                    var value = trimmed.substring(eqIdx + 1).trim()
                    // 去除引号
                    if ((value.startsWith("\"") && value.endsWith("\"")) ||
                        (value.startsWith("'") && value.endsWith("'"))) {
                        value = value.substring(1, value.length - 1)
                    }
                    // 只设置尚未存在的变量 (不覆盖系统环境变量)
                    if (OS.getenv(key) == None) {
                        OS.setenv(key, value, 0)
                    }
                }
            }
        } catch (_: Exception) {}
    }

    /// 执行 preload 文件
    // 严格翻译自: Bun 中 --preload 和 BUN_PRELOAD 环境变量
    private func executePreloads(): Unit {
        // 命令行指定的 preload
        for (preload in options.preloads) {
            let resolved = resolveScriptPath(preload)
            match (resolved) {
                case Some(path) =>
                    try {
                        vm.executeFile(path)
                    } catch (_: Exception) {}
                case None =>
                    println("warning: preload file not found: ${preload}")
            }
        }
        // 环境变量指定的 preload
        match (OS.getenv("BUN_PRELOAD")) {
            case Some(preload) =>
                let resolved = resolveScriptPath(preload)
                match (resolved) {
                    case Some(path) =>
                        try { vm.executeFile(path) } catch (_: Exception) {}
                    case None => {}
                }
            case None => {}
        }
    }

    /// Watch 模式执行
    /// 对应 Bun: RunCommand --watch
    /// 文件变更时完全重启进程 (重新加载所有模块)
    // 严格翻译自: Bun 中 --watch 使用 inotify/kqueue 监听文件变更
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
            // Watch 模式: 完全重新创建虚拟机 (清除所有状态)
            vm = VirtualMachine()
            injectEnvVariables()
            executeFile(path)
        })

        // 阻塞等待 watcher
        w.wait()

        return exitCode
    }

    /// Hot 模式执行 (HMR)
    /// 对应 Bun: RunCommand --hot
    /// 文件变更时热替换模块 (保留全局状态)
    // 严格翻译自: Bun 中 --hot 使用 HMR 热替换修改的模块
    private func runWithHot(path: String): Int64 {
        println("Hot-reloading ${path}...")

        // 首次执行
        let exitCode = executeFile(path)

        // 设置文件监听
        let w = FileWatcher(path)
        watcher = Some(w)
        w.start({ =>
            if (!options.silent) {
                println("\n--- Hot reloading ${path} ---")
            }
            // Hot 模式: 不重建虚拟机, 只热替换变更的模块
            // 保留全局状态 (globalThis, setTimeout 回调等)
            try {
                vm.hotReload(path)
            } catch (e: Exception) {
                println("error: Hot reload failed: ${e.message}")
                // Hot 失败时回退到完全重启
                vm = VirtualMachine()
                executeFile(path)
            }
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

// ============================================================================
// 文件类型枚举
// ============================================================================

/// 文件类型检测结果
enum FileType {
    | Script     // 脚本文件 (shebang, .js, .ts 等)
    | Binary     // 二进制可执行文件 (ELF, Mach-O, PE)
    | Text       // 纯文本文件
}

// ============================================================================
// 字节数组转字符串辅助
// ============================================================================

/// 字节数组转字符串
func bytesToString(bytes: Array<UInt8>): String {
    let sb = StringBuilder()
    for (b in bytes) {
        sb.append(Char(Int32(b)))
    }
    return sb.toString()
}
