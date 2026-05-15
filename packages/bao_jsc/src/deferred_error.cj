// 严格翻译自: src/jsc/DeferredError.zig (35行)
// 延迟创建的错误对象

package bao_jsc

// ========== DeferredError ==========
// 严格翻译自 DeferredError.zig DeferredError
// 错误不能在非主线程创建，因此用此结构存储信息以便稍后实例化
public class DeferredError {
    // 错误种类
    public var kind: DeferredErrorKind = DeferredErrorKind.PlainError
    // Node.js 风格错误码
    public var code: NodeJsErrorCode = NodeJsErrorCode.Unknown
    // 错误消息
    public var msg: String = ""

    public init() {}

    public init(kind: DeferredErrorKind, code: NodeJsErrorCode, msg: String) {
        this.kind = kind
        this.code = code
        this.msg = msg
    }

    // 严格翻译自 DeferredError.from
    // 工厂方法: 从格式化字符串创建
    public static func from(kind: DeferredErrorKind, code: NodeJsErrorCode, message: String) -> DeferredError {
        DeferredError(kind: kind, code: code, msg: message)
    }

    // 严格翻译自 DeferredError.toError
    // 在全局对象上实例化为 JS 错误
    public func toError(globalThis: JsObject) -> JsValue {
        let err = match (kind) {
            case PlainError => {
                JsValue(JsError(msg).toString())
            }
            case TypeError => {
                JsValue(JsTypeError(msg).toString())
            }
            case RangeError => {
                JsValue(JsRangeError(msg).toString())
            }
        }

        // 设置 code 属性
        // 对应 Zig: err.put(globalThis, ZigString.static("code"), ZigString.init(@tagName(this.code)).toJS(globalThis))
        if (let Some(errObj) <- err.toObject()) {
            errObj.set("code", JsValue(s: code.toName()))
        }
        err
    }
}

// ========== DeferredErrorKind ==========
// 严格翻译自 DeferredError.zig Kind
public enum DeferredErrorKind {
    | PlainError    // Error
    | TypeError     // TypeError
    | RangeError    // RangeError
}

// ========== NodeJsErrorCode ==========
// 严格翻译自 Node.js 风格错误码 (对应 jsc.Node.ErrorCode)
public enum NodeJsErrorCode {
    | Unknown
    | ModuleNotFound
    | CannotFindModule
    | ErrUnknownBuiltinModule
    | ErrModuleNotFound
    | ResolveError
    | InvalidArgType
    | InvalidArgValue
    | OutOfRange
    | FileNotFound
    | PermissionDenied
    | AlreadyExists
    | NotDir
    | IsDir

    public func toName() -> String {
        match (this) {
            case Unknown => "UNKNOWN"
            case ModuleNotFound => "MODULE_NOT_FOUND"
            case CannotFindModule => "CANNOT_FIND_MODULE"
            case ErrUnknownBuiltinModule => "ERR_UNKNOWN_BUILTIN_MODULE"
            case ErrModuleNotFound => "ERR_MODULE_NOT_FOUND"
            case ResolveError => "RESOLVE_ERROR"
            case InvalidArgType => "ERR_INVALID_ARG_TYPE"
            case InvalidArgValue => "ERR_INVALID_ARG_VALUE"
            case OutOfRange => "ERR_OUT_OF_RANGE"
            case FileNotFound => "ENOENT"
            case PermissionDenied => "EACCES"
            case AlreadyExists => "EEXIST"
            case NotDir => "ENOTDIR"
            case IsDir => "EISDIR"
        }
    }
}
