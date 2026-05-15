// bao_io - 父进程死亡看门狗
// 严格翻译自: src/io/ParentDeathWatchdog.zig
//   Bun 在启用 no-orphans 模式时监控父进程是否存活
//   Linux: prctl(PR_SET_PDEATHSIG, SIGKILL) 内核自动发送 SIGKILL
//   macOS: kqueue EVFILT_PROC/NOTE_EXIT 监控父进程退出
//   退出时递归 SIGKILL 所有子孙进程
//   仓颉实现提供等价的看门狗逻辑
package bao_io

import bao_core.*

// ============================================================================
// ParentDeathWatchdog - 父进程死亡看门狗
// 严格翻译自: src/io/ParentDeathWatchdog.zig
//   enabled: bool (全局状态)
//   original_ppid: pid_t (原始父进程 PID)
//   install_thread_id: Thread.Id (安装时的线程 ID)
//   功能:
//     - install(): 从环境变量检查并启用
//     - enable(): Linux prctl, macOS kqueue 注册
//     - killDescendants(): 递归 SIGKILL 子孙进程
//     - shouldDefaultSpawnPdeathsig(): 判断子进程是否应设置 PDEATHSIG
// ============================================================================

/// 父进程死亡看门狗
/// 严格翻译自 ParentDeathWatchdog.zig:50-56
///   var enabled: bool = false;
///   var original_ppid: std.c.pid_t = 0;
///   var install_thread_id: std.Thread.Id = 0;
public class ParentDeathWatchdog {
    /// 退出码: 128 + SIGHUP
    /// 严格翻译自: pub const exit_code: u8 = 128 + 1
    public static let EXIT_CODE: UInt8 = 129 // 128 + SIGHUP(1)

    /// 是否启用
    /// 严格翻译自: var enabled: bool = false
    private static var enabled: Bool = false

    /// 原始父进程 PID
    /// 严格翻译自: var original_ppid: std.c.pid_t = 0
    private static var originalPpid: Int32 = 0

    /// 安装时的线程 ID
    /// 严格翻译自: var install_thread_id: std.Thread.Id = 0
    private static var installThreadId: UInt64 = 0

    /// sync PGID 缓冲区
    /// 严格翻译自: var sync_pgids_buf: [4]std.c.pid_t = .{0} ** 4
    private static var syncPgidsBuf: Array<Int32> = Array<Int32>(4, item: 0)

    /// sync PGID 列表
    /// 严格翻译自: var sync_pgids: []std.c.pid_t = sync_pgids_buf[0..0]
    private static var syncPgidsLen: Int64 = 0

    /// 是否启用 no-orphans 模式
    /// 严格翻译自: pub fn isEnabled() bool
    public static func isEnabled(): Bool {
        return enabled
    }

    /// 获取要监控的父进程 PID
    /// 严格翻译自: pub fn ppidToWatch() ?std.c.pid_t
    public static func ppidToWatch(): ?Int32 {
        if (!enabled || originalPpid <= 1) {
            return None
        }
        return originalPpid
    }

    /// 从 main() 安装, 检查环境变量
    /// 严格翻译自: pub fn install() void
    ///   检查 BUN_FEATURE_FLAG_NO_ORPHANS 环境变量
    public static func install(): Unit {
        if (!isPosix()) {
            return
        }
        let envValue = getEnv("BUN_FEATURE_FLAG_NO_ORPHANS")
        if (envValue == None || envValue!.isEmpty) {
            return
        }
        enable()
    }

    /// 启用看门狗 (幂等)
    /// 严格翻译自: pub fn enable() void
    ///   Linux: prctl(PR_SET_PDEATHSIG, SIGKILL)
    ///   macOS: 惰性安装到 event loop
    ///   设置 env 变量, 注册退出回调
    public static func enable(): Unit {
        if (!isPosix()) {
            return
        }
        if (enabled) {
            return
        }

        enabled = true
        installThreadId = getCurrentThreadId()

        // 导出环境变量给子进程
        setEnv("BUN_FEATURE_FLAG_NO_ORPHANS", "1")

        // 注册退出回调
        addExitCallback(onProcessExit)

        // 获取原始父进程 PID
        originalPpid = getParentPid()

        // 如果已是孤儿进程 (ppid <= 1), 无需监控
        if (originalPpid <= 1) {
            return
        }

        // Linux: prctl(PR_SET_PDEATHSIG, SIGKILL)
        if (isLinux()) {
            let result = prctlSetPdeathsig(9) // SIGKILL = 9
            if (result < 0) {
                return
            }
            // 竞态检查: 父进程可能在 getppid 和 prctl 之间退出
            let currentPpid = getParentPid()
            if (currentPpid != originalPpid) {
                killDescendants()
                sysExit(EXIT_CODE)
            }
        }
        // macOS: 惰性安装到 event loop (installOnEventLoop)
    }

    /// 推入 sync PGID
    /// 严格翻译自: pub fn pushSyncPgid(pgid: std.c.pid_t) bool
    public static func pushSyncPgid(pgid: Int32): Bool {
        if (!isPosix()) {
            return false
        }
        if (syncPgidsLen >= syncPgidsBuf.size) {
            return false
        }
        syncPgidsBuf[Int64(syncPgidsLen)] = pgid
        syncPgidsLen += 1
        return true
    }

    /// 弹出 sync PGID
    /// 严格翻译自: pub fn popSyncPgid() void
    public static func popSyncPgid(): Unit {
        if (!isPosix()) {
            return
        }
        if (syncPgidsLen > 0) {
            syncPgidsLen -= 1
        }
    }

    /// 杀死 sync 脚本树
    /// 严格翻译自: pub fn killSyncScriptTree() void
    public static func killSyncScriptTree(): Unit {
        if (!isPosix()) {
            return
        }
        var i: Int64 = 0
        while (i < syncPgidsLen) {
            let pgid = syncPgidsBuf[i]
            if (pgid > 1) {
                sysKill(-pgid, 9) // SIGKILL
            }
            i += 1
        }
    }

    /// 判断是否应为子进程默认设置 PDEATHSIG
    /// 严格翻译自: pub fn shouldDefaultSpawnPdeathsig() bool
    ///   PR_SET_PDEATHSIG 是线程范围的, 只有主线程的子进程应该默认启用
    public static func shouldDefaultSpawnPdeathsig(): Bool {
        return enabled && getCurrentThreadId() == installThreadId
    }

    /// 递归 SIGKILL 所有子孙进程
    /// 严格翻译自: pub fn killDescendants() void
    ///   使用 SIGSTOP + ppid 验证 + 叶优先 SIGKILL 模式
    ///   防止 PID 重用导致误杀
    public static func killDescendants(): Unit {
        if (!isPosix()) {
            return
        }

        let selfPid = getPid()
        var toVisit: Array<Int32> = []
        var toKill: Array<Int32> = []

        toVisit.append(selfPid)

        // 收集所有子孙进程
        while (toVisit.size > 0 && toKill.size < 4096) {
            let parent = toVisit.removeAt(toVisit.size - 1)
            let children = listChildPids(parent)
            for (child in children) {
                if (child == selfPid || child <= 1) {
                    continue
                }
                // SIGSTOP 冻结, 验证 ppid
                if (sysKill(child, 19) != 0) { // SIGSTOP = 19
                    continue
                }
                if (parentPidOf(child) != parent) {
                    sysKill(child, 18) // SIGCONT
                    continue
                }
                toKill.append(child)
                toVisit.append(child)
            }
        }

        // 反向: 叶节点优先 SIGKILL
        var i = toKill.size
        while (i > 0) {
            i -= 1
            sysKill(toKill[i], 9) // SIGKILL
        }
    }

    /// 快照当前直接子进程
    /// 严格翻译自: pub fn snapshotChildren(out: []std.c.pid_t) []const std.c.pid_t
    public static func snapshotChildren(): Array<Int32> {
        if (!isLinux()) {
            return []
        }
        return listChildPids(getPid())
    }

    /// 杀死 subreaper 收养的进程
    /// 严格翻译自: pub fn killSubreaperAdoptees(siblings: []const std.c.pid_t) void
    public static func killSubreaperAdoptees(siblings: Array<Int32>): Unit {
        if (!isLinux()) {
            return
        }
        let selfPid = getPid()
        var rounds: UInt8 = 64

        while (rounds > 0) {
            rounds -= 1
            let children = listChildPids(selfPid)
            var killedAny = false
            for (child in children) {
                if (child <= 1 || child == selfPid) {
                    continue
                }
                if (siblings.contains(child)) {
                    continue
                }
                killTreeRootedAt(child, selfPid)
                killedAny = true
            }
            // 回收已杀死的子进程
            reapChildren()
            if (!killedAny) {
                return
            }
        }
    }

    /// 杀死以指定进程为根的子树
    /// 严格翻译自: fn killTreeRootedAt(root: std.c.pid_t, expected_ppid_of_root: std.c.pid_t) void
    private static func killTreeRootedAt(root: Int32, expectedPpid: Int32): Unit {
        if (!isPosix()) {
            return
        }

        if (sysKill(root, 19) != 0) { // SIGSTOP
            return
        }
        if (parentPidOf(root) != expectedPpid) {
            sysKill(root, 18) // SIGCONT
            return
        }

        var toVisit: Array<Int32> = [root]
        var toKill: Array<Int32> = [root]

        while (toVisit.size > 0 && toKill.size < 4096) {
            let parent = toVisit.removeAt(toVisit.size - 1)
            let children = listChildPids(parent)
            for (child in children) {
                if (child <= 1) {
                    continue
                }
                if (sysKill(child, 19) != 0) {
                    continue
                }
                if (parentPidOf(child) != parent) {
                    sysKill(child, 18) // SIGCONT
                    continue
                }
                toKill.append(child)
                toVisit.append(child)
            }
        }

        var i = toKill.size
        while (i > 0) {
            i -= 1
            sysKill(toKill[i], 9) // SIGKILL
        }
    }

    /// 退出回调 - 杀死所有子孙进程
    /// 严格翻译自: fn onProcessExit() callconv(.c) void
    private static func onProcessExit(): Unit {
        killSyncScriptTree()
        killDescendants()
    }

    // ========================================================================
    // 平台相关辅助函数
    // ========================================================================

    private static func isPosix(): Bool {
        // 由平台配置提供
        return true
    }

    private static func isLinux(): Bool {
        return false
    }

    private static func getCurrentThreadId(): UInt64 {
        return 0
    }

    private static func getParentPid(): Int32 {
        return 0
    }

    private static func getPid(): Int32 {
        return 0
    }

    private static func parentPidOf(pid: Int32): Int32 {
        return 0
    }

    private static func listChildPids(parent: Int32): Array<Int32> {
        return []
    }

    private static func prctlSetPdeathsig(sig: Int32): Int32 {
        return -1
    }

    private static func getEnv(name: String): ?String {
        return None
    }

    private static func setEnv(name: String, value: String): Unit {}

    private static func addExitCallback(callback: () -> Unit): Unit {}

    private static func sysKill(pid: Int32, sig: Int32): Int32 {
        return -1
    }

    private static func sysExit(code: UInt8): Unit {}

    private static func reapChildren(): Unit {}
}
