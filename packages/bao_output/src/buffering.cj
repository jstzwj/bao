// 严格翻译自: src/bun_core/output.rs:991-1043
//   pub struct EnableBufferingScope { prev_buffering: bool }
//   pub struct DisableBufferingScope(());
//   pub fn enable_buffering_scope() -> EnableBufferingScope { ... }
//   pub fn disable_buffering_scope() -> DisableBufferingScope { ... }
//
// 也翻译自: src/bun_core/output.rs:1166-1186
//   pub struct FlushGuard(());
//   pub fn flush_guard() -> FlushGuard { ... }
package bao_output

import bao_core.Output

// ============================================================================
// EnableBufferingScope - 启用缓冲作用域
// 严格翻译自: src/bun_core/output.rs:991-1009
//   pub struct EnableBufferingScope { prev_buffering: bool, }
//   impl EnableBufferingScope {
//       pub fn init() -> EnableBufferingScope {
//           let prev_buffering = ENABLE_BUFFERING.load(Relaxed);
//           ENABLE_BUFFERING.store(true, Relaxed);
//           EnableBufferingScope { prev_buffering }
//       }
//   }
//   impl Drop for EnableBufferingScope {
//       fn drop(&mut self) { ENABLE_BUFFERING.store(self.prev_buffering, Relaxed); }
//   }
// ============================================================================

/// 启用缓冲作用域 - 对应 Bun EnableBufferingScope
/// pub struct EnableBufferingScope { prev_buffering: bool }
/// RAII: 保存之前的缓冲状态, 启用缓冲, 退出时恢复
public class EnableBufferingScope {
    private let prevBuffering: Bool

    public init() {
        this.prevBuffering = Output.enableBuffering
        Output.enableBuffering = true
    }

    /// 恢复缓冲状态 - 对应 Bun Drop for EnableBufferingScope
    /// Does not call Output.flush().
    public func close(): Unit {
        Output.enableBuffering = prevBuffering
    }
}

// ============================================================================
// DisableBufferingScope - 禁用缓冲作用域
// 严格翻译自: src/bun_core/output.rs:1025-1043
//   pub struct DisableBufferingScope(());
//   impl DisableBufferingScope {
//       pub fn init() -> DisableBufferingScope {
//           disable_buffering();
//           DisableBufferingScope(())
//       }
//   }
//   impl Drop for DisableBufferingScope {
//       fn drop(&mut self) { enable_buffering(); }
//   }
// ============================================================================

/// 禁用缓冲作用域 - 对应 Bun DisableBufferingScope
/// pub struct DisableBufferingScope(());
/// RAII: 禁用缓冲, 退出时恢复
public class DisableBufferingScope {
    private let prevBuffering: Bool

    public init() {
        this.prevBuffering = Output.enableBuffering
        Output.enableBuffering = false
    }

    /// 恢复缓冲状态 - 对应 Bun Drop for DisableBufferingScope
    public func close(): Unit {
        Output.enableBuffering = prevBuffering
    }
}

// ============================================================================
// FlushGuard - 刷新守卫
// 严格翻译自: src/bun_core/output.rs:1166-1186
//   #[must_use = "FlushGuard flushes on Drop"]
//   pub struct FlushGuard(());
//   impl Drop for FlushGuard { fn drop(&mut self) { flush(); } }
//   pub fn flush_guard() -> FlushGuard { FlushGuard(()) }
// ============================================================================

/// 刷新守卫 - 对应 Bun FlushGuard
/// pub struct FlushGuard(());
/// RAII: 作用域结束时自动调用 flush()
public class FlushGuard {

    public init() {}

    /// 刷新 - 对应 Bun Drop for FlushGuard
    public func close(): Unit {
        Output.flush()
    }
}
