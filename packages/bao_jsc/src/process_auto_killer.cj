// 严格翻译自: src/jsc/ProcessAutoKiller.zig
// 进程自动杀手 - 在退出时自动终止子进程

package bao_jsc

// ========== ProcessAutoKiller ==========
// 严格翻译自 ProcessAutoKiller
// 管理 spawn 的子进程，在进程退出时自动终止所有子进程
public class ProcessAutoKiller {
    public var processes: Array<SubProcess> = []
    public var enabled: Bool = false
    public var everEnabled: Bool = false

    public init() {}

    // 严格翻译自 ProcessAutoKiller.enable
    public func enable() {
        enabled = true
        everEnabled = true
    }

    // 严格翻译自 ProcessAutoKiller.disable
    public func disable() {
        enabled = false
    }

    // 严格翻译自 ProcessAutoKiller.kill
    public func kill(): ProcessAutoKillerResult {
        ProcessAutoKillerResult(killProcesses())
    }

    // 严格翻译自 ProcessAutoKiller.killProcesses
    private func killProcesses(): UInt32 {
        var count: UInt32 = 0
        while (processes.size > 0) {
            let lastIdx = Int64(processes.size - 1)
            let process = processes[lastIdx]
            processes = processes[0..lastIdx]
            if (!process.hasExited()) {
                process.kill()
                count += UInt32(1)
            }
        }
        count
    }

    // 严格翻译自 ProcessAutoKiller.clear
    public func clear() {
        processes = []
    }

    // 严格翻译自 ProcessAutoKiller.onSubprocessSpawn
    public func onSubprocessSpawn(process: SubProcess) {
        if (enabled) {
            // 使用 concat 追加到不可变数组（仓颉 Array 没有 append 方法）
            processes = processes.concat([process])
            process.ref()
        }
    }

    // 严格翻译自 ProcessAutoKiller.onSubprocessExit
    public func onSubprocessExit(process: SubProcess) {
        if (everEnabled) {
            // 按引用匹配查找并移除特定进程
            var idx: Int64 = -1
            for (i in 0..processes.size) {
                if (processes[Int64(i)].pid == process.pid) {
                    idx = Int64(i)
                    break
                }
            }
            if (idx >= 0) {
                processes = processes[0..idx].concat(processes[idx + 1..])
                process.deref()
            }
        }
    }

    // 严格翻译自 ProcessAutoKiller.deinit
    public func deinit() {
        for (process in processes) {
            process.deref()
        }
        processes = []
    }
}

// 支撑类型
public class ProcessAutoKillerResult {
    public var processes: UInt32 = 0
    public init(processes: UInt32) { this.processes = processes }
}

public class SubProcess {
    public var pid: Int32 = -1
    public var exited: Bool = false

    public init() {}
    public init(pid: Int32) {
        this.pid = pid
    }

    public func hasExited(): Bool { exited }
    public func kill() {}
    public func ref() {}
    public func deref() {}
}
