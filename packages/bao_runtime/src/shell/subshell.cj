// subshell.cj - Subshell state
// Translates Bun: src/runtime/shell/states/Subshell.rs
// (Rust rewrite of Subshell.zig)
//
// A subshell executes a Script in a duplicated shell execution environment.
// The env is already duped at construction time (by init_dupe_shell_state or
// Pipeline), so Subshell always owns its shell env.
//
// Flow: Idle -> create Script -> Script runs stmts -> childDone -> Done -> parent.childDone

package bao_runtime.shell

import bao_core.*
import bao_collections.*

// ============================================================================
// Subshell state kind
// ============================================================================

/// Subshell state kind
/// Matches Bun Rust: SubshellState { Idle, Expanding, Exec, WaitWriteErr, Done }
public enum SubshellStateKind {
    | `idle`
    | expanding
    | `exec`
    | waitWriteErr
    | done
}

// ============================================================================
// Subshell parent pointer
// ============================================================================

/// Subshell parent pointer
/// Type-erased pointer to the parent state (Stmt, Pipeline, or Binary).
/// Dispatches childDone to the actual parent.
public class SubshellParentPtr {
    public var ptr: Any = Option<Any>.None

    public static func initFunc(p: Any): SubshellParentPtr {
        let pp = SubshellParentPtr()
        pp.ptr = p
        return pp
    }

    public func childDone(child: Any, exitCode: ExitCode): Yield {
        // Dispatch based on parent type
        // Subshell's parent can be: StmtState, PipelineState, BinaryState
        if (this.ptr is StmtState) {
            let stmt = (this.ptr as StmtState).getOrThrow()
            return stmt.childDone(StmtChildPtr.initFunc(child), exitCode)
        }
        if (this.ptr is PipelineState) {
            let pipeline = (this.ptr as PipelineState).getOrThrow()
            return pipeline.childDone(PipelineChildPtr.initFunc(child), exitCode)
        }
        if (this.ptr is BinaryState) {
            let binary = (this.ptr as BinaryState).getOrThrow()
            return binary.childDone(BinaryChildPtr.initFunc(child), exitCode)
        }
        // Fallback (should not happen in correct state machine)
        return Yield.done
    }

    public func create<T>(): T {
        throw Exception("SubshellParentPtr.create is unavailable in the compile-only runtime shell")
    }

    public func destroy<T>(ptr: T) {}
}

// ============================================================================
// Subshell child pointer
// ============================================================================

/// Subshell child pointer
/// Type-erased pointer to a child state (Script or Expansion).
public class SubshellChildPtr {
    public var ptr: Any = Option<Any>.None

    public static func initFunc(p: Any): SubshellChildPtr {
        let cp = SubshellChildPtr()
        cp.ptr = p
        return cp
    }

    public func `is`(`type`: Any): Bool { true }

    public func deinit() {
        // Deinit based on type
        if (this.ptr is ScriptState) {
            (this.ptr as ScriptState).getOrThrow().deinit()
        } else if (this.ptr is ExpansionState) {
            (this.ptr as ExpansionState).getOrThrow().deinit()
        }
    }
}

// ============================================================================
// Subshell state
// ============================================================================

/// Subshell state
/// Executes a shell script (AST Subshell node) in a duplicated shell environment.
///
/// The shell env is already duped at construction time. Subshell always owns it.
///
/// Matches Bun Rust Subshell.rs:
/// - start() -> Yield.subshell(this) to enter trampoline
/// - next() in Idle: create Script, set state to Exec, return Script.start()
/// - next() in Done: call parent.childDone(this, exitCode)
/// - childDone(): set exitCode, set state to Done, return Yield.subshell(this)
public class SubshellState {
    /// Base state header
    public var base: Base = Base()
    /// AST node (the Subshell AST node containing the script)
    public var node: Subshell = Subshell(ASTScript([]), Option<Redirect>.None, RedirectFlags())
    /// Parent pointer (Stmt, Pipeline, or Binary)
    public var parent: SubshellParentPtr = SubshellParentPtr()
    /// IO (stdin/stdout/stderr)
    public var io: IO = IO()
    /// Current state
    public var state: SubshellStateKind = SubshellStateKind.`idle`
    /// Exit code
    public var exitCode: ExitCode = ExitCode.exited(0)

    public init() {}

    /// Initialize a SubshellState.
    ///
    /// The `shellState` must already be a duped env owned by this node
    /// (see initDupeShellState for the Stmt/Binary path; Pipeline dupes
    /// the env itself before calling this). SubshellState.deinit frees it.
    ///
    /// Matches Bun Rust: Subshell::init(interp, shell, node, parent, io)
    public static func initFunc(
        interpreter: Interpreter,
        shellState: ShellExecEnv,
        node: Subshell,
        parent: SubshellParentPtr,
        io: IO
    ): SubshellState {
        let subshell = SubshellState()
        subshell.base = Base.initWithNewAllocScope(StateKind.subshell, interpreter, shellState)
        subshell.node = node
        subshell.parent = parent
        subshell.io = io
        subshell.state = SubshellStateKind.`idle`
        subshell.exitCode = ExitCode.exited(0)
        return subshell
    }

    /// Initialize by duplicating the parent shell environment.
    ///
    /// Called by Stmt/Binary via Interpreter.spawn_expr.
    /// Pipeline does NOT use this (it dupes per-child itself and calls init directly).
    ///
    /// Matches Bun Rust: Subshell::init_dupe_shell_state(interp, parent_shell, node, parent, io)
    public static func initDupeShellState(
        interpreter: Interpreter,
        shellState: ShellExecEnv,
        node: Subshell,
        parent: SubshellParentPtr,
        io: IO
    ): SubshellState {
        let subshell = SubshellState()
        subshell.base = Base.initWithNewAllocScope(StateKind.subshell, interpreter, shellState)
        subshell.node = node
        subshell.parent = parent
        subshell.io = io
        subshell.state = SubshellStateKind.`idle`
        subshell.exitCode = ExitCode.exited(0)
        // NOTE: In Bun Rust, this calls shell_state.dupe_for_subshell().
        // In Bao, the ShellExecEnv.dupeForSubshell() is already called by the
        // caller (StmtState.next) before passing the shellState to initFunc.
        // So the shellState here is already the duped env.
        return subshell
    }

    /// Start execution.
    ///
    /// Returns Yield.subshell(this) to enter the trampoline, which will call next().
    /// Matches Bun Rust: Subshell::start() -> Yield::Next(this)
    public func start(): Yield {
        return Yield.subshell(this)
    }

    /// Next step in the state machine.
    ///
    /// Matches Bun Rust: Subshell::next(interp, this)
    /// - Idle: create Script from node.script, set state to Exec, return Script.start()
    /// - Expanding/Exec/WaitWriteErr: return suspended
    /// - Done: return parent.childDone(this, exitCode)
    public func next(): Yield {
        match (this.state) {
            case SubshellStateKind.`idle` =>
                // Create a Script to execute the subshell body.
                // The env was already duped at construction — do NOT dupe again.
                let scriptNode = this.node.script
                let script = ScriptState.initFunc(
                    this.base.interpreter,
                    this.base.shell,
                    scriptNode,
                    ScriptParentPtr.initFunc(this),
                    this.io.copy()
                )
                this.state = SubshellStateKind.`exec`
                return script.start()

            case SubshellStateKind.expanding =>
                // TODO: redirect expansion (not yet implemented in Bun Rust either)
                return Yield.suspended

            case SubshellStateKind.`exec` =>
                // Waiting for the Script child to finish
                return Yield.suspended

            case SubshellStateKind.waitWriteErr =>
                // Waiting for error write to complete
                return Yield.suspended

            case SubshellStateKind.done =>
                // Script finished — propagate exit code to parent
                return this.parent.childDone(this, this.exitCode)
        }
    }

    /// Child node completed.
    ///
    /// Called when the child Script (or Expansion) finishes.
    /// Sets exit code, transitions to Done, and re-enters the trampoline.
    ///
    /// Matches Bun Rust: Subshell::child_done(interp, this, child, exit_code)
    public func childDone(child: SubshellChildPtr, exitCode: ExitCode): Yield {
        this.exitCode = exitCode
        // Deinit the child node
        // In Bun Rust: interp.deinit_node(child)
        child.deinit()
        // Transition to Done state
        this.state = SubshellStateKind.done
        // Re-enter trampoline — next() will see Done and call parent.childDone
        return Yield.subshell(this)
    }

    /// IO writer chunk callback.
    ///
    /// Called when the error writer finishes writing.
    /// Matches Bun Rust: Subshell::on_io_writer_chunk(interp, this, written, err)
    public func onIOWriterChunk(chunk: UInt64, err: ?SystemError): Yield {
        if (let Some(sysErr) <- err) {
            sysErr.deref()
        }
        this.state = SubshellStateKind.done
        return this.parent.childDone(this, this.exitCode)
    }

    /// Deinitialize.
    ///
    /// The env was duped at construction (either by Pipeline or by
    /// initDupeShellState) — Subshell always owns it.
    ///
    /// Matches Bun Rust: Subshell::deinit(interp, this)
    public func deinit() {
        // Deinit the duped shell env
        this.base.shell.deinit()
        // Deref IO
        this.io.deref()
        // End alloc scope
        this.base.endScope()
    }

    /// Write a failing error message.
    ///
    /// Matches Bun Zig: Subshell.writeFailingError
    public func writeFailingError(s: String): Yield {
        this.state = SubshellStateKind.waitWriteErr
        return this.base.shell.writeFailingErrorFmt(this, { _ => () }, s, [])
    }
}
