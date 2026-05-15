// 进程信息和控制 API
// 对应 Bun: src/runtime/node/node_process.zig
// 严格翻译自: src/runtime/node/node_process.zig
package bao_runtime

import bao_core.*
import bao_sys.*

// ============================================================================
// 进程 API
// 对应 Bun: src/runtime/node/node_process.zig
// ============================================================================
public class NodeProcess {
    // 进程标题
    private static var processTitle: String = "bao"

    // 版本号
    public static let version: String = "v1.0.0"

    // 版本信息（含 SHA）
    public static let versionWithSha: String = "v1.0.0"

    // 获取进程标题
    // 对应 Bun: src/runtime/node/node_process.zig - getTitle
    public static func getTitle(): String {
        return processTitle
    }

    // 设置进程标题
    // 对应 Bun: src/runtime/node/node_process.zig - setTitle
    public static func setTitle(title: String): Unit {
        processTitle = title
    }

    // 获取当前工作目录
    // 对应 Bun: src/runtime/node/node_process.zig - getCwd
    public static func getCwd(): String {
        return System.cwd()
    }

    // 设置当前工作目录
    // 对应 Bun: src/runtime/node/node_process.zig - setCwd
    public static func setCwd(path: String): Bool {
        if (path.size == 0) {
            return false
        }
        return System.chdir(path)
    }

    // 获取 argv[0]（可执行文件路径）
    // 对应 Bun: src/runtime/node/node_process.zig - createArgv0
    public static func getArgv0(): String {
        return System.execPath()
    }

    // 获取可执行文件路径
    // 对应 Bun: src/runtime/node/node_process.zig - getExecPath
    public static func getExecPath(): String {
        return System.execPath()
    }

    // 获取 argv 列表
    // 对应 Bun: src/runtime/node/node_process.zig - createArgv
    public static func getArgv(): Array<String> {
        return System.argv()
    }

    // 获取 execArgv（传给 V8/JSC 的参数）
    // 对应 Bun: src/runtime/node/node_process.zig - createExecArgv
    public static func getExecArgv(): Array<String> {
        // 返回空数组（简化实现）
        return Array<String>()
    }

    // 退出进程
    // 对应 Bun: src/runtime/node/node_process.zig - exit
    public static func exit(code: Int32): Unit {
        System.exit(code)
    }

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

    // 获取 eval 源代码
    // 对应 Bun: src/runtime/node/node_process.zig - getEval
    public static func getEval(): ?String {
        return None
    }

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

    // NODE_NO_WARNINGS 标志
    // 对应 Bun: src/runtime/node/node_process.zig - Bun__NODE_NO_WARNINGS
    public static func nodeNoWarnings(): Bool {
        let val = System.getenv("NODE_NO_WARNINGS")
        return val != None
    }
}
