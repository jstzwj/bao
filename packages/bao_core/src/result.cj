// bao_core - Result 类型
// 严格翻译自: src/bun_core/result.rs - Result<T, E> enum
// 以及 src/bun_core/result.zig - Result comptime
package bao_core

// ============================================================================
// Result<T, E> - 双参数结果类型
// 严格翻译自: src/bun_core/result.rs:622-636
//   pub enum Result<T, E> { Ok(T), Err(E) }
// 以及 src/bun_core/result.zig:1-11
//   pub fn Result(comptime T: type, comptime E: type) type {
//       return union(enum) { ok: T, err: E, ... }
//   }
// ============================================================================

/// 结果类型 - 严格对应 Bun Result<T, E>
/// Bun 使用 union(enum) { ok: T, err: E }
/// 仓颉使用 enum 变体
public enum Result<T, E> {
    | Ok(T)
    | Err(E)

    /// 对应 Bun Result::as_err → Option<&E>
    public func asErr(): ?E {
        match (this) {
            case Err(e) => Some(e)
            case Ok(_) => None
        }
    }

    /// 是否成功
    public func isOk(): Bool {
        match (this) {
            case Ok(_) => true
            case Err(_) => false
        }
    }

    /// 是否失败
    public func isErr(): Bool {
        match (this) {
            case Ok(_) => false
            case Err(_) => true
        }
    }

    /// 获取值 (如果成功)
    public func value(): ?T {
        match (this) {
            case Ok(v) => Some(v)
            case Err(_) => None
        }
    }

    /// 获取值，失败则抛出异常
    /// 对应 Rust .unwrap() / Bun try-catch 语义
    public func unwrap(): T {
        match (this) {
            case Ok(v) => v
            case Err(e) => throw e
        }
    }
    }

    /// 获取值，失败则返回默认值
    public func unwrapOr(default: T): T {
        match (this) {
            case Ok(v) => v
            case Err(_) => default
        }
    }

    /// 获取值，失败则执行函数
    public func unwrapOrElse(fn: (E) -> T): T {
        match (this) {
            case Ok(v) => v
            case Err(e) => fn(e)
        }
    }

    /// 映射成功值
    public func map<U>(fn: (T) -> U): Result<U, E> {
        match (this) {
            case Ok(v) => Result<U, E>.Ok(fn(v))
            case Err(e) => Result<U, E>.Err(e)
        }
    }

    /// 映射错误
    public func mapErr<F>(fn: (E) -> F): Result<T, F> {
        match (this) {
            case Ok(v) => Result<T, F>.Ok(v)
            case Err(e) => Result<T, F>.Err(fn(e))
        }
    }

    /// 链式操作 - 对应 Rust Result::and_then / Zig try 语义
    public func andThen<U>(fn: (T) -> Result<U, E>): Result<U, E> {
        match (this) {
            case Ok(v) => fn(v)
            case Err(e) => Result<U, E>.Err(e)
        }
    }

    /// 或写失败 - 对应 Bun OrWriteFailed trait
    /// src/bun_core/result.rs:295-312
    public func orWriteFailed(): Result<T, BaoError> {
        match (this) {
            case Ok(v) => Result<T, BaoError>.Ok(v)
            case Err(_) => Result<T, BaoError>.Err(BaoError(ErrorCode.WriteFailed))
        }
    }
}
