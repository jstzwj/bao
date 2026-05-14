// bao_core - Result 类型
// 对应 Bun: src/bun_core/result.zig
// Rust 使用 Result<T,E> + ? 操作符
// 仓颉使用 Option + 异常，此处提供兼容的 Result 类型
package bao_core

// ============================================================================
// Result 类型
// 对应 Rust: Result<T, E>
// ============================================================================

/// 结果类型 - 表示成功或失败
public enum Result<T> {
    | Ok(T)
    | Err(BaoError)

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
    public func value(): Option<T> {
        match (this) {
            case Ok(v) => Some(v)
            case Err(_) => None
        }
    }

    /// 获取值，失败则抛出异常
    public func unwrap(): T {
        match (this) {
            case Ok(v) => v
            case Err(e) => throw e
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
    public func unwrapOrElse(fn: () -> T): T {
        match (this) {
            case Ok(v) => v
            case Err(_) => fn()
        }
    }

    /// 映射成功值
    public func map<U>(fn: (T) -> U): Result<U> {
        match (this) {
            case Ok(v) => Result<U>.Ok(fn(v))
            case Err(e) => Result<U>.Err(e)
        }
    }

    /// 映射错误
    public func mapErr(fn: (BaoError) -> BaoError): Result<T> {
        match (this) {
            case Ok(v) => Ok(v)
            case Err(e) => Err(fn(e))
        }
    }

    /// 链式操作
    public func andThen<U>(fn: (T) -> Result<U>): Result<U> {
        match (this) {
            case Ok(v) => fn(v)
            case Err(e) => Result<U>.Err(e)
        }
    }
}

// ============================================================================
// Option 扩展
// 仓颉已有 Option<T>，此处添加便捷方法
// ============================================================================

/// Option 扩展方法
public extension<T> Option<T> {
    /// 获取值或抛出异常
    public func unwrap(message: String): T {
        match (this) {
            case Some(v) => v
            case None => throw BaoError(message)
        }
    }
}
