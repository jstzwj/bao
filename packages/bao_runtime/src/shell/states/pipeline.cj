// pipeline.cj - 管道执行状态
// 对应 Bun: src/runtime/shell/states/Pipeline.zig
// 严格翻译Bun shell管道状态到仓颉

package bao_runtime.shell.states

import bao_core.*

// ============================================================================
// 管道执行状态
// 管道创建多个执行"线程"
// cmd1 | cmd2 | cmd3
// ============================================================================

/// 管道状态
public class PipelineState {
    /// 基类
    public var base: Base
    /// AST节点
    public var node: Pipeline
    /// 父节点
    public var parent: ParentPtr
    /// 已退出的命令数
    public var exitedCount: UInt32 = 0
    /// 命令列表
    public var cmds: ?Array<CmdOrResult> = None
    /// 管道列表
    public var pipes: ?Array<Pipe> = None
    /// IO
    public var io: IO
    /// 状态
    public var state: PipelineStateKind

    /// 管道状态类型
    public enum PipelineStateKind {
        case startingCmds(idx: UInt32)
        case pending
        case waitingWriteErr
        case done(exitCode: ExitCode)
    }

    /// 父节点指针
    public class ParentPtr {
        public var ptr: Any

        public static func initFunc(p: Any): ParentPtr {
            let pp = ParentPtr()
            pp.ptr = p
            return pp
        }
    }

    /// 子节点指针
    public class ChildPtr {
        public var ptr: Any

        public static func initFunc(p: Any): ChildPtr {
            let cp = ChildPtr()
            cp.ptr = p
            return cp
        }

        public func deinit() {
            // 根据类型去初始化
        }
    }

    /// 命令或结果
    public enum CmdOrResult {
        case cmd(Any)
        case result(ExitCode)
    }

    /// 初始化
    public static func initFunc(
        interpreter: Interpreter,
        shellState: ShellExecEnv,
        node: Pipeline,
        parent: ParentPtr,
        io: IO
    ): PipelineState {
        let pipeline = PipelineState()
        pipeline.base = Base.initWithNewAllocScope(StateKind.pipeline, interpreter, shellState)
        pipeline.node = node
        pipeline.parent = parent
        pipeline.exitedCount = 0
        pipeline.cmds = None
        pipeline.pipes = None
        pipeline.io = io
        pipeline.state = PipelineStateKind.startingCmds(idx: 0)
        return pipeline
    }

    /// 启动
    public func start(): Yield {
        // 设置命令
        if (this.cmds == None) {
            this.state = PipelineStateKind.done(exitCode: 0)
            return Yield.done
        }
        return Yield.pipeline(this)
    }

    /// 下一步
    public func next(): Yield {
        switch (this.state) {
            case .startingCmds(let idx) =>
                let cmds = this.cmds.getOrThrow()
                if (idx >= cmds.length) {
                    this.state = PipelineStateKind.pending
                    return Yield.suspended
                }
                this.state = PipelineStateKind.startingCmds(idx: idx + 1)
                let cmdOrResult = cmds[idx]
                return Yield.pipeline(this)
            case .pending =>
                unreachableState("Pipeline.next", "pending")
            case .waitingWriteErr =>
                unreachableState("Pipeline.next", "waitingWriteErr")
            case .done(let exitCode) =>
                return this.parent.childDone(this, exitCode)
        }
    }

    /// IO写入器数据块回调
    public func onIOWriterChunk(amount: UInt64, err: ?SystemError): Yield {
        if (let e = err) {
            this.base.throw(ShellErr.newSys(e))
            return Yield.failed
        }
        return this.parent.childDone(this, 1)
    }

    /// 子节点完成
    public func childDone(child: ChildPtr, exitCode: ExitCode): Yield {
        child.deinit()
        this.exitedCount += 1
        if (this.exitedCount >= this.cmds.getOrThrow().length) {
            this.state = PipelineStateKind.done(exitCode: exitCode)
            return Yield.pipeline(this)
        }
        return Yield.suspended
    }

    /// 去初始化
    public func deinit() {
        if (let cmds = this.cmds) {
            this.base.allocator().free(cmds)
        }
        if (let pipes = this.pipes) {
            this.base.allocator().free(pipes)
        }
        this.io.deref()
        this.base.endScope()
    }
}
