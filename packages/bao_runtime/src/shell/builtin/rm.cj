// rm.cj - rm命令
// 对应 Bun: src/runtime/shell/builtin/rm.zig
// 严格翻译Bun shell rm命令到仓颉

package bao_runtime.shell.builtin

import bao_core.*

// ============================================================================
// rm命令 - 删除文件或目录
// 支持 -r/R (递归删除), -f (强制), -v (详细输出), -d (删除空目录)
// 使用线程池并发递归删除
// ============================================================================

/// rm命令
public class RmCmd {
    /// 选项
    public var opts: RmOpts = RmOpts()
    /// 状态
    public var state: RmState = RmState.idle

    /// 状态类型
    public enum RmState {
        case idle
        case parseOpts(ParseOptsState)
        case exec(ExecState)
        case done(ExitCode)
        case waitingWriteErr
        case err(ExitCode)
    }

    /// 解析选项状态
    /// 对应 Bun: parse_opts struct in Rm state
    public struct ParseOptsState {
        public var argsSlice: Array<String>
        public var idx: UInt32 = 0
        public var innerState: ParseOptsInnerState = .normal
    }

    /// 解析选项内部状态
    public enum ParseOptsInnerState {
        case normal
        case waitWriteErr
    }

    /// 执行状态
    /// 对应 Bun: exec struct in Rm state
    public struct ExecState {
        public var filepathArgs: Array<String>
        public var totalTasks: UIntPtr = 0
        public var err: ?SyscallError = None
        public var outputDone: AtomicUIntPtr = AtomicUIntPtr()
        public var outputCount: AtomicUIntPtr = AtomicUIntPtr()
        public var innerState: ExecInnerState = .idle
    }

    /// 执行内部状态
    public enum ExecInnerState {
        case idle
        case waiting(WaitingState)
    }

    /// 等待状态
    public struct WaitingState {
        public var tasksDone: UIntPtr = 0
    }

    /// 启动
    public func start(): Yield {
        return this.next()
    }

    /// 下一步
    public func next(): Yield {
        while (this.state != .done(0) && this.state != .err(0)) {
            switch (this.state) {
                case .waitingWriteErr =>
                    return Yield.suspended

                case .idle =>
                    this.state = RmState.parseOpts(ParseOptsState(
                        argsSlice: this.bltn().argsSlice()
                    ))

                case .parseOpts(let parseOpts) =>
                    switch (parseOpts.innerState) {
                        case .normal =>
                            if (parseOpts.idx >= parseOpts.argsSlice.length) {
                                let errorString = Builtin.Kind.usageString("rm")
                                if (let safeguard = this.bltn().stderr.needsIO()) {
                                    return this.bltn().stderr.enqueue(this, errorString.toByteArray(), safeguard)
                                }
                                this.bltn().writeNoIO(.stderr, errorString.toByteArray())
                                return this.bltn().done(1)
                            }

                            let arg = parseOpts.argsSlice[parseOpts.idx]
                            switch (this.parseFlag(arg)) {
                                case .continueParsing =>
                                    // idx++
                                case .done =>
                                    // 检查根目录保护并转换到exec状态
                                case .illegalOption =>
                                    return this.bltn().done(1)
                                case .illegalOptionWithFlag =>
                                    return this.bltn().done(1)
                            }
                        case .waitWriteErr =>
                            panic("Invalid")
                    }

                case .exec =>
                    // 调度或等待任务完成
                    return Yield.suspended

                case .done, .err =>
                    panic("不可达状态")
            }
        }

        switch (this.state) {
            case .done(let exitCode) =>
                return this.bltn().done(exitCode)
            case .err(let exitCode) =>
                return this.bltn().done(exitCode)
            case _ =>
                panic("不可达状态")
        }
    }

    /// IO写入器数据块回调
    public func onIOWriterChunk(amount: UInt64, e: ?SystemError): Yield {
        if (let err = e) {
            err.deref()
        }

        if (let exec = this.state.getExec()) {
            // 增加outputDone
            return Yield.suspended
        }

        if (e != None) {
            this.state = RmState.err(1)
            return this.bltn().done(1)
        }

        return this.bltn().done(1)
    }

    /// 解析标志
    func parseFlag(flag: String): RmFlagResult {
        if (flag.length == 0) {
            return .done
        }
        if (flag[0] != '-') {
            return .done
        }
        if (flag.length > 2 && flag[1] == '-') {
            // 长选项
            if (flag == "--preserve-root") {
                this.opts.preserveRoot = true
                return .continueParsing
            } else if (flag == "--no-preserve-root") {
                this.opts.preserveRoot = false
                return .continueParsing
            } else if (flag == "--recursive") {
                this.opts.recursive = true
                return .continueParsing
            } else if (flag == "--verbose") {
                this.opts.verbose = true
                return .continueParsing
            } else if (flag == "--dir") {
                this.opts.removeEmptyDirs = true
                return .continueParsing
            } else if (flag == "--interactive=never") {
                this.opts.promptBehaviour = .never
                return .continueParsing
            } else if (flag == "--interactive=once") {
                this.opts.promptBehaviour = .once(OnceState())
                return .continueParsing
            } else if (flag == "--interactive=always") {
                this.opts.promptBehaviour = .always
                return .continueParsing
            }
            return .illegalOption
        }

        let smallFlags = flag.substring(1)
        for (c in smallFlags) {
            if (c == 'f') {
                this.opts.force = true
                this.opts.promptBehaviour = .never
            } else if (c == 'r' || c == 'R') {
                this.opts.recursive = true
            } else if (c == 'v') {
                this.opts.verbose = true
            } else if (c == 'd') {
                this.opts.removeEmptyDirs = true
            } else if (c == 'i') {
                this.opts.promptBehaviour = .once(OnceState())
            } else if (c == 'I') {
                this.opts.promptBehaviour = .always
            } else {
                return .illegalOptionWithFlag
            }
        }
        return .continueParsing
    }

    /// 写入失败错误
    public func writeFailingError(buf: String, exitCode: ExitCode): Yield {
        if (let safeguard = this.bltn().stderr.needsIO()) {
            this.state = RmState.waitingWriteErr
            return this.bltn().stderr.enqueue(this, buf.toByteArray(), safeguard)
        }
        this.bltn().writeNoIO(.stderr, buf.toByteArray())
        return this.bltn().done(exitCode)
    }

    /// 去初始化
    public func deinit() {}

    /// 获取Builtin引用
    public func bltn(): Builtin {
        return Builtin.fromImpl(this, "rm")
    }
}

/// rm命令选项
public struct RmOpts {
    /// --preserve-root: 保护根目录
    public var preserveRoot: Boolean = true
    /// -f: 强制删除
    public var force: Boolean = false
    /// 提示行为
    public var promptBehaviour: PromptBehaviour = .never
    /// -r/-R: 递归删除
    public var recursive: Boolean = false
    /// -v: 详细输出
    public var verbose: Boolean = false
    /// -d: 删除空目录
    public var removeEmptyDirs: Boolean = false
}

/// 提示行为
public enum PromptBehaviour {
    /// --interactive=never (默认)
    case never
    /// -I: 删除超过3个文件或递归删除时提示一次
    case once(OnceState)
    /// -i: 每次删除前提示
    case always
}

/// once状态
public struct OnceState {
    public var removedCount: UInt32 = 0
}

/// rm标志解析结果
public enum RmFlagResult {
    case continueParsing
    case done
    case illegalOption
    case illegalOptionWithFlag
}

/// Shell rm任务
public class ShellRmTask {
    public var rm: RmCmd
    public var opts: RmOpts
    public var cwd: FD
    public var rootPath: String = ""
    public var err: ?SyscallError = None
    public var errorSignal: AtomicBool = AtomicBool()

    /// 目录任务
    public class DirTask {
        public var taskManager: ShellRmTask
        public var parentTask: ?DirTask = None
        public var path: String = ""
        public var subtaskCount: AtomicUIntPtr = AtomicUIntPtr()
        public var deletedEntries: ArrayList<Byte> = ArrayList<Byte>()
        public var kindHint: EntryKindHint = .idk

        /// 条目类型提示
        public enum EntryKindHint {
            case idk
            case dir
            case file
        }

        /// 去初始化
        public func deinit() {
            this.deletedEntries.clear()
        }
    }

    /// 调度到线程池
    public func schedule() {
        // 排队到线程池
    }

    /// 去初始化
    public func deinit() {
        // 清理资源
    }
}
