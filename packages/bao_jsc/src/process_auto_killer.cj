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

    // 严格翻译自 ProcessAutoKiller.Result
    public class Result {
        public var processes: UInt32 = 0
        public init() {}
    }

    // 严格翻译自 ProcessAutoKiller.kill
    public func kill() -> ProcessAutoKillerResult {
        ProcessAutoKillerResult(processes: killProcesses())
    }

    // 严格翻译自 ProcessAutoKiller.killProcesses
    private func killProcesses() -> UInt32 {
        var count: UInt32 = 0
        while (processes.size > 0) {
            let process = processes.removeLast()
            if (!process.hasExited()) {
                process.kill()
                count += 1
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
            processes.append(process)
            process.ref()
        }
    }

    // 严格翻译自 ProcessAutoKiller.onSubprocessExit
    public func onSubprocessExit(process: SubProcess) {
        if (everEnabled) {
            let idx = processes.indexOf(process)
            if (idx >= 0) {
                processes.removeAt(idx)
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
    public init(processes: UInt32) { self.processes = processes }
}

public class SubProcess {
    public func hasExited() -> Bool { true }
    public func kill() {}
    public func ref() {}
    public func deref() {}
}
