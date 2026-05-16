// pipeline.cj - 管道执行状态
// 对应 Bun: src/runtime/shell/states/Pipeline.zig
// 严格翻译Bun shell管道状态到仓颉

package bao_runtime.shell.states

import bao_core.*
import bao_runtime.shell.*

// ============================================================================
// 管道执行状态
// 管道创建多个执行"线程"
// cmd1 | cmd2 | cmd3
// ============================================================================

/// 管道状态类型（提取到顶层）
public enum PipelineStateKind {
| startingCmds(UInt32)
| pending
| waitingWriteErr
| done(ExitCode)
}

/// 管道父节点指针（提取到顶层）
public class PipelineParentPtr {
    public var ptr: Any

    public static func initFunc(p: Any): PipelineParentPtr {
        let pp = PipelineParentPtr()
        pp.ptr = p
        return pp
    }
}

/// 管道子节点指针（提取到顶层）
public class PipelineChildPtr {
    public var ptr: Any

    public static func initFunc(p: Any): PipelineChildPtr {
        let cp = PipelineChildPtr()
        cp.ptr = p
        return cp
    }

    public func deinit() {
        // 根据类型去初始化
    }
}

/// 命令或结果（提取到顶层）
public enum PipelineCmdOrResult {
| cmd(Any)
| result(ExitCode)
}

/// 管道状态
public class PipelineState {
    /// 基类
    public var base: Base
    /// AST节点
    public var node: Pipeline
    /// 父节点
    public var parent: PipelineParentPtr
    /// 已退出的命令数
    public var exitedCount: UInt32 = 0
    /// 命令列表
    public var cmds: ?Array<PipelineCmdOrResult> = None
    /// 管道列表
    public var pipes: ?Array<Pipe> = None
    /// IO
    public var io: IO
    /// 状态
    public var state: PipelineStateKind

    /// 初始化
    public static func initFunc(
        interpreter: Interpreter,
        shellState: ShellExecEnv,
        node: Pipeline,
        parent: PipelineParentPtr,
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
        pipeline.state = PipelineStateKind.startingCmds(0)
        return pipeline
    }

    /// 启动
    public func start(): Yield {
        // 设置命令
        if (this.cmds == None) {
            this.state = PipelineStateKind.done(0)
            return Yield.done
        }
        return Yield.pipeline(this)
    }

    /// 下一步
    public func next(): Yield {
        match (this.state) {
            case PipelineStateKind.startingCmds(idx) =>
                let cmds = this.cmds.getOrThrow()
                if (idx >= cmds.size) {
                    this.state = PipelineStateKind.pending
                    return Yield.suspended
                }
                this.state = PipelineStateKind.startingCmds(idx + 1)
                let cmdOrResult = cmds[idx]
                return Yield.pipeline(this)
            case PipelineStateKind.pending =>
                unreachableState("Pipeline.next", "pending")
            case PipelineStateKind.waitingWriteErr =>
                unreachableState("Pipeline.next", "waitingWriteErr")
            case PipelineStateKind.done(exitCode) =>
                return this.parent.childDone(this, exitCode)
        }
    }

    /// IO写入器数据块回调
    public func onIOWriterChunk(chunk: UInt64, err: ?SystemError): Yield {
        if (let Some(e) <- err) {
            this.base.`throw`(ShellErr.newSys(e))
            return Yield.failed
        }
        return this.parent.childDone(this, 1)
    }

    /// 子节点完成
    public func childDone(child: PipelineChildPtr, exitCode: ExitCode): Yield {
        child.deinit()
        this.exitedCount += 1
        if (this.exitedCount >= this.cmds.getOrThrow().size) {
            this.state = PipelineStateKind.done(exitCode)
            return Yield.pipeline(this)
        }
        return Yield.suspended
    }

    /// 去初始化
    public func deinit() {
        if (let Some(cmds) <- this.cmds) {
            this.base.allocator().free(cmds)
        }
        if (let Some(pipes) <- this.pipes) {
            this.base.allocator().free(pipes)
        }
        this.io.deref()
        this.base.endScope()
    }
}
