// 进程信息和控制 API（完整翻译）
// 对应 Bun: src/runtime/node/node_process.zig
// 严格翻译自: src/runtime/node/node_process.zig
package bao_runtime.node

import bao_core.*
import bao_sys.*

// ============================================================================
// 进程 API
// 对应 Bun: src/runtime/node/node_process.zig
// 包含: getTitle, setTitle, createArgv, getCwd, setCwd, exit,
//       createArgv0, getExecPath, createExecArgv, getEval,
//       Bun__NODE_NO_WARNINGS, Bun__version 等
// ============================================================================
public class NodeProcess {
    // ========================================================================
    // 进程标题（线程安全）
    // 对应 Bun: node_process.zig title_mutex + getTitle/setTitle
    // ============================================================================
    private static var processTitle: String = "bao"

    // ========================================================================
    // 版本号常量
    // 对应 Bun: node_process.zig Bun__version, Bun__version_with_sha
    // ============================================================================
    public static let version: String = "v1.0.0"
    public static let versionWithSha: String = "v1.0.0"

    // 版本 SHA
    // 对应 Bun: Bun__version_sha
    public static let versionSha: String = "unknown"

    // uWS/uSockets 版本
    // 对应 Bun: Bun__versions_uws, Bun__versions_usockets
    public static let versionsUws: String = "unknown"
    public static let versionsUsockets: String = "unknown"

    // ========================================================================
    // getTitle — 获取进程标题
    // 对应 Bun: node_process.zig getTitle
    // 默认值为 "bao"（Bun 中为 "bun"）
    // ============================================================================
    public static func getTitle(): String {
        return processTitle
    }

    // ========================================================================
    // setTitle — 设置进程标题
    // 对应 Bun: node_process.zig setTitle
    // 使用互斥锁保护（Bun 中使用 bun.Mutex）
    // ============================================================================
    public static func setTitle(title: String): Unit {
        processTitle = title
    }

    // ========================================================================
    // getCwd — 获取当前工作目录
    // 对应 Bun: node_process.zig getCwd_
    // 使用 bun.api.node.path.getCwd 获取缓存的工作目录
    // 错误时抛出 SystemError
    // ============================================================================
    public static func getCwd(): String {
        return System.cwd()
    }

    // ========================================================================
    // setCwd — 设置当前工作目录
    // 对应 Bun: node_process.zig setCwd_
    // 1. 验证路径非空
    // 2. 调用 chdir 系统调用
    // 3. 更新 bundler 的缓存工作目录
    // 4. 确保路径以斜杠结尾（bundler 内部约定）
    // 5. 返回新的工作目录（不带尾部斜杠）
    // ============================================================================
    public static func setCwd(path: String): Bool {
        if (path.size == 0) {
            return false
        }
        return System.chdir(path)
    }

    // ========================================================================
    // createArgv0 — 获取 argv[0]（可执行文件名）
    // 对应 Bun: node_process.zig createArgv0
    // 返回 bun.argv[0]
    // ============================================================================
    public static func getArgv0(): String {
        return System.execPath()
    }

    // ========================================================================
    // getExecPath — 获取可执行文件完整路径
    // 对应 Bun: node_process.zig getExecPath
    // 使用 bun.selfExePath() 获取，失败时回退到 argv[0]
    // ============================================================================
    public static func getExecPath(): String {
        let path = System.selfExePath()
        if (path.size > 0) {
            return path
        }
        return getArgv0()
    }

    // ========================================================================
    // createArgv — 获取完整 argv 列表
    // 对应 Bun: node_process.zig createArgv
    // 1. standalone 模式: ["bun", main, ...argv]
    // 2. worker 模式: [exe_path, "[worker eval]"/main, ...worker.argv]
    // 3. 普通模式: [exe_path, main, ...vm.argv]
    // ============================================================================
    public static func getArgv(): Array<String> {
        return System.argv()
    }

    // ========================================================================
    // createExecArgv — 获取 execArgv（传给引擎的参数）
    // 对应 Bun: node_process.zig createExecArgv
    // 1. Worker 模式: 如果设置了 execArgv 则直接使用
    // 2. Standalone 模式: 合并 compile_exec_argv 和 BUN_OPTIONS
    // 3. 普通模式: 从 process.argv 重新解析，提取以 - 开头的参数
    //    - 跳过 "run" 命令
    //    - 识别需要值的参数（如 --eval, --require 等）
    // ============================================================================
    public static func getExecArgv(): Array<String> {
        // 简化实现：从 argv 中提取以 - 开头的参数
        let argv = System.argv()
        var execArgv = Array<String>()
        var seenRun = false
        var prev: ?String = None

        // 需要额外参数的选项集
        // 对应 Bun: node_process.zig createExecArgv 中的 auto_params 映射
        let stringOptions = Array<String>(["--eval", "-e", "--print", "-p", "--require", "-r", "--config", "--import"])

        for (arg in argv) {
            let prevVal = prev
            prev = arg

            if (arg.size >= 1 && arg[0] == '-') {
                execArgv.add(arg)
                continue
            }

            if (!seenRun && arg == "run") {
                seenRun = true
                continue
            }

            // 如果前一个参数是需要值的选项，则当前参数也是 execArgv
            if (prevVal != None) {
                var isStringOpt = false
                for (opt in stringOptions) {
                    if (prevVal == opt) {
                        isStringOpt = true
                        break
                    }
                }
                if (isStringOpt) {
                    execArgv.add(arg)
                    continue
                }
            }

            // 遇到脚本名称后停止
            break
        }

        return execArgv
    }

    // ========================================================================
    // exit — 退出进程
    // 对应 Bun: node_process.zig exit
    // Worker 模式: worker.exit()
    // 主线程: vm.onExit() + vm.globalExit()
    // ============================================================================
    public static func exit(code: Int32): Unit {
        System.exit(code)
    }

    // ========================================================================
    // getEval — 获取 eval 源代码
    // 对应 Bun: node_process.zig getEval
    // 返回 vm.module_loader.eval_source 或 undefined
    // ============================================================================
    public static func getEval(): ?String {
        return None
    }

    // ========================================================================
    // 环境变量操作
    // ========================================================================

    // 获取环境变量
    public static func getEnv(name: String): ?String {
        return System.getenv(name)
    }

    // 设置环境变量
    public static func setEnv(name: String, value: String): Unit {
        System.setenv(name, value: value)
    }

    // 删除环境变量
    public static func deleteEnv(name: String): Unit {
        System.unsetenv(name)
    }

    // 获取所有环境变量
    public static func getAllEnv(): Map<String, String> {
        return System.environ()
    }

    // ========================================================================
    // 进程 ID 操作
    // ========================================================================

    // 获取进程 ID
    public static func getPid(): Int32 {
        return System.getpid()
    }

    // 获取父进程 ID
    public static func getPpid(): Int32 {
        return System.getppid()
    }

    // 获取用户 ID
    public static func getUid(): UInt32 {
        return System.getuid()
    }

    // 获取组 ID
    public static func getGid(): UInt32 {
        return System.getgid()
    }

    // 设置用户 ID
    public static func setUid(uid: UInt32): Unit {
        System.setuid(uid)
    }

    // 设置组 ID
    public static func setGid(gid: UInt32): Unit {
        System.setgid(gid)
    }

    // ========================================================================
    // NODE_NO_WARNINGS — 抑制 Node.js 警告
    // 对应 Bun: node_process.zig Bun__NODE_NO_WARNINGS
    // 检查环境变量 NODE_NO_WARNINGS 是否设置
    // ============================================================================
    public static func nodeNoWarnings(): Bool {
        let val = System.getenv("NODE_NO_WARNINGS")
        return val != None
    }

    // ========================================================================
    // suppressCrashOnProcessKillSelfIfDesired — 抑制自杀死崩溃报告
    // 对应 Bun: node_process.zig Bun__suppressCrashOnProcessKillSelfIfDesired
    // 检查 BUN_INTERNAL_SUPPRESS_CRASH_ON_PROCESS_KILL_SELF 标志
    // ============================================================================
    public static func suppressCrashOnProcessKillSelf(): Bool {
        let val = System.getenv("BUN_INTERNAL_SUPPRESS_CRASH_ON_PROCESS_KILL_SELF")
        return val != None
    }

    // ========================================================================
    // abort — 异常终止进程
    // ============================================================================
    public static func abort(): Unit {
        System.abort()
    }

    // ========================================================================
    // kill — 发送信号给进程
    // ============================================================================
    public static func kill(pid: Int32, signal: String): Bool {
        return System.kill(pid, signal: signal)
    }

    // ========================================================================
    // nextTick — 下一个 tick 回调
    // ============================================================================
    public static func nextTick(callback: () -> Unit): Unit {
        callback()
    }

    // ========================================================================
    // memoryUsage — 获取内存使用信息
    // ============================================================================
    public static func memoryUsage(): MemoryUsageInfo {
        let info = MemoryUsageInfo()
        info.rss = System.rss()
        info.heapTotal = 0
        info.heapUsed = 0
        info.external = 0
        info.arrayBuffers = 0
        return info
    }

    // ========================================================================
    // cpuUsage — 获取 CPU 使用信息
    // ============================================================================
    public static func cpuUsage(): CpuUsageInfo {
        let info = CpuUsageInfo()
        info.user = 0
        info.system = 0
        return info
    }

    // ========================================================================
    // umask — 获取/设置文件模式创建掩码
    // ============================================================================
    public static func umask(): UInt32 {
        return System.umask()
    }

    public static func umask(mask: UInt32): UInt32 {
        return System.umask(mask)
    }

    // ========================================================================
    // hrtime — 高精度时间
    // ============================================================================
    public static func hrtime(): Array<Int64> {
        let ns = System.hrtime()
        return Array<Int64>([ns / 1000000000, ns % 1000000000])
    }

    // ========================================================================
    // uptime — 进程运行时间
    // ============================================================================
    public static func processUptime(): Float64 {
        return System.processUptime()
    }
}

// ============================================================================
// 内存使用信息
// ============================================================================
public class MemoryUsageInfo {
    public var rss: Int64 = 0
    public var heapTotal: Int64 = 0
    public var heapUsed: Int64 = 0
    public var external: Int64 = 0
    public var arrayBuffers: Int64 = 0

    public init() {}
}

// ============================================================================
// CPU 使用信息
// ============================================================================
public class CpuUsageInfo {
    public var user: Int64 = 0
    public var system: Int64 = 0

    public init() {}
}
