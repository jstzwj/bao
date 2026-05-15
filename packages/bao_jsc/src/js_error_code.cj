// 严格翻译自: src/jsc/JSErrorCode.zig (73行)
// JavaScript 错误类型枚举和 DOM 异常码

package bao_jsc

// ========== JSErrorCode ==========
// 严格翻译自 JSErrorCode.zig JSErrorCode
// 表示 JavaScript 错误类型
// 注意: StackOverflow & OutOfMemoryError 不是 JSC "ErrorType.h" 中的 ErrorType，
// 所以数值完全是自己分配的
public enum JSErrorCode {
    // 标准 JS 错误类型
    | Error            // 0
    | EvalError        // 1
    | RangeError       // 2
    | ReferenceError   // 3
    | SyntaxError      // 4
    | TypeError        // 5
    | URIError         // 6
    | AggregateError   // 7

    // 非 JSC 标准，Bun 自定义
    | OutOfMemoryError // 8
    | BundlerError     // 252
    | StackOverflow    // 253
    | UserErrorCode    // 254
    | Unknown          // 255 (默认/未初始化)

    // 严格翻译自 JSErrorCode 的整数值
    public func toInt() -> Int64 {
        match (this) {
            case Error => 0
            case EvalError => 1
            case RangeError => 2
            case ReferenceError => 3
            case SyntaxError => 4
            case TypeError => 5
            case URIError => 6
            case AggregateError => 7
            case OutOfMemoryError => 8
            case BundlerError => 252
            case StackOverflow => 253
            case UserErrorCode => 254
            case Unknown => 255
        }
    }

    // 从整数值创建
    public static func fromInt(value: Int64) -> JSErrorCode {
        match (value) {
            case 0 => Error
            case 1 => EvalError
            case 2 => RangeError
            case 3 => ReferenceError
            case 4 => SyntaxError
            case 5 => TypeError
            case 6 => URIError
            case 7 => AggregateError
            case 8 => OutOfMemoryError
            case 252 => BundlerError
            case 253 => StackOverflow
            case 254 => UserErrorCode
            case _ => Unknown
        }
    }

    // 转为字符串名称
    public func toName() -> String {
        match (this) {
            case Error => "Error"
            case EvalError => "EvalError"
            case RangeError => "RangeError"
            case ReferenceError => "ReferenceError"
            case SyntaxError => "SyntaxError"
            case TypeError => "TypeError"
            case URIError => "URIError"
            case AggregateError => "AggregateError"
            case OutOfMemoryError => "OutOfMemoryError"
            case BundlerError => "BundlerError"
            case StackOverflow => "StackOverflow"
            case UserErrorCode => "UserErrorCode"
            case Unknown => "Unknown"
        }
    }
}

// ========== DOMExceptionCode ==========
// 严格翻译自 JSErrorCode.zig DOMExceptionCode
// 与 src/jsc/bindings/ExceptionCode.h 中的 ExceptionCode 保持同步
public enum DOMExceptionCode {
    // DOMException 错误名称 (https://webidl.spec.whatwg.org/#idl-DOMException-error-names)
    // 需要与 DOMException.cpp 中的数组保持同步
    | IndexSizeError                // 已弃用，使用 RangeError 替代
    | HierarchyRequestError
    | WrongDocumentError
    | InvalidCharacterError
    | NoModificationAllowedError
    | NotFoundError
    | NotSupportedError
    | InUseAttributeError
    | InvalidStateError
    | DOMSyntaxError
    | InvalidModificationError
    | NamespaceError
    | InvalidAccessError            // 已弃用，使用 NotAllowedError 替代
    | TypeMismatchError             // 已弃用，使用 TypeError 替代
    | SecurityError
    | NetworkError
    | AbortError
    | URLMismatchError
    | QuotaExceededError
    | TimeoutError
    | InvalidNodeTypeError
    | DataCloneError
    | EncodingError
    | NotReadableError
    | UnknownError
    | ConstraintError
    | DataError
    | TransactionInactiveError
    | ReadonlyError
    | VersionError
    | OperationError
    | NotAllowedError

    // 简单异常 (https://webidl.spec.whatwg.org/#idl-exceptions)
    | RangeError
    | TypeError
    | JSSyntaxError                 // 与 DOM SYNTAX_ERR 不同

    // 非标准错误
    | StackOverflowError
    | OutOfMemoryError

    // 用于指示绑定层下方抛出了 JS 异常，应向上传播
    | ExistingExceptionError

    | InvalidThisError
    | InvalidURLError
    | CryptoOperationFailedError

    // 转为字符串名称
    public func toName() -> String {
        match (this) {
            case IndexSizeError => "IndexSizeError"
            case HierarchyRequestError => "HierarchyRequestError"
            case WrongDocumentError => "WrongDocumentError"
            case InvalidCharacterError => "InvalidCharacterError"
            case NoModificationAllowedError => "NoModificationAllowedError"
            case NotFoundError => "NotFoundError"
            case NotSupportedError => "NotSupportedError"
            case InUseAttributeError => "InUseAttributeError"
            case InvalidStateError => "InvalidStateError"
            case DOMSyntaxError => "SyntaxError"
            case InvalidModificationError => "InvalidModificationError"
            case NamespaceError => "NamespaceError"
            case InvalidAccessError => "InvalidAccessError"
            case TypeMismatchError => "TypeMismatchError"
            case SecurityError => "SecurityError"
            case NetworkError => "NetworkError"
            case AbortError => "AbortError"
            case URLMismatchError => "URLMismatchError"
            case QuotaExceededError => "QuotaExceededError"
            case TimeoutError => "TimeoutError"
            case InvalidNodeTypeError => "InvalidNodeTypeError"
            case DataCloneError => "DataCloneError"
            case EncodingError => "EncodingError"
            case NotReadableError => "NotReadableError"
            case UnknownError => "UnknownError"
            case ConstraintError => "ConstraintError"
            case DataError => "DataError"
            case TransactionInactiveError => "TransactionInactiveError"
            case ReadonlyError => "ReadonlyError"
            case VersionError => "VersionError"
            case OperationError => "OperationError"
            case NotAllowedError => "NotAllowedError"
            case RangeError => "RangeError"
            case TypeError => "TypeError"
            case JSSyntaxError => "SyntaxError"
            case StackOverflowError => "StackOverflowError"
            case OutOfMemoryError => "OutOfMemoryError"
            case ExistingExceptionError => "ExistingExceptionError"
            case InvalidThisError => "InvalidThisError"
            case InvalidURLError => "InvalidURLError"
            case CryptoOperationFailedError => "CryptoOperationFailedError"
        }
    }
}
