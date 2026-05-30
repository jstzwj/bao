// Local Result type for bao_runtime.webcore.blob package
// This avoids Cangjie's multi-file import ambiguity issue with bao_core.Result

package bao_runtime.webcore.blob

/// Result type - mirrors bao_core.Result<T, E>
public enum Result<T, E> {
    | Ok(T)
    | Err(E)

    public func isOk(): Bool {
        match (this) {
            case Ok(_) => true
            case Err(_) => false
        }
    }

    public func isErr(): Bool {
        match (this) {
            case Ok(_) => false
            case Err(_) => true
        }
    }

    public func getOrThrow(): T {
        match (this) {
            case Ok(v) => v
            case Err(e) => throw Exception("Result::getOrThrow called on Err")
        }
    }
}
