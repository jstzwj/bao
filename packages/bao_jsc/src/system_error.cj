// 严格翻译自: src/jsc/SystemError.zig + PosixSignalHandle.zig + ProcessAutoKiller.zig +
//   RegularExpression.zig + TextCodec.zig + NodeModuleModule.zig + JSModuleLoader.zig +
//   CommonAbortReason.zig + CommonStrings.zig + AbortSignal.zig + AnyPromise.zig
// JavaScriptCore 系统错误、信号处理、正则表达式和其他绑定

package bao_jsc

// ========== SystemError ==========
// 严格翻译自 SystemError.zig
// 系统错误表示
public class SystemError {
    public var errnoCode: Int64 = 0
    public var code: String = ""
    public var message: String = ""
    public var path: String = ""
    public var syscall: String = ""
    public var fd: Int64 = -1
    public var hostname: String = ""
    public var dest: String = ""
    public var address: String = ""
    public var port: Int64 = 0
    public var info: ?JsObject = None

    public init() {}

    public init(code: String, message: String) {
        this.code = code
        this.message = message
    }

    // 转为 JsValue
    public func toJS(global: JsObject): JsValue {
        let obj = JsObject.make()
        obj.className = "Error"
        obj.set("code", JsValue(code))
        obj.set("message", JsValue(message))
        obj.set("errno", JsValue(errnoCode))
        obj.set("syscall", JsValue(syscall))
        if (!path.size == 0) {
            obj.set("path", JsValue(path))
        }
        JsValue(obj)
    }

    // 严格翻译自 SystemError.fromCode
    public static func fromCode(errnoCode: Int64, syscall: String): SystemError {
        let err = SystemError()
        err.errnoCode = errnoCode
        err.syscall = syscall
        err.code = errorCodeToString(errnoCode)
        err.message = err.code + ": " + syscall
        err
    }

    // 错误码到字符串
    static func errorCodeToString(code: Int64): String {
        match (code) {
            case 1 => "EPERM"
            case 2 => "ENOENT"
            case 3 => "ESRCH"
            case 4 => "EINTR"
            case 5 => "EIO"
            case 6 => "ENXIO"
            case 7 => "E2BIG"
            case 8 => "ENOEXEC"
            case 9 => "EBADF"
            case 10 => "ECHILD"
            case 11 => "EAGAIN"
            case 12 => "ENOMEM"
            case 13 => "EACCES"
            case 14 => "EFAULT"
            case 15 => "ENOTBLK"
            case 16 => "EBUSY"
            case 17 => "EEXIST"
            case 18 => "EXDEV"
            case 19 => "ENODEV"
            case 20 => "ENOTDIR"
            case 21 => "EISDIR"
            case 22 => "EINVAL"
            case 23 => "ENFILE"
            case 24 => "EMFILE"
            case 25 => "ENOTTY"
            case 26 => "ETXTBSY"
            case 27 => "EFBIG"
            case 28 => "ENOSPC"
            case 29 => "ESPIPE"
            case 30 => "EROFS"
            case 31 => "EMLINK"
            case 32 => "EPIPE"
            case 33 => "EDOM"
            case 34 => "ERANGE"
            case 35 => "EDEADLK"
            case 36 => "ENAMETOOLONG"
            case 37 => "ENOLCK"
            case 38 => "ENOSYS"
            case 39 => "ENOTEMPTY"
            case 40 => "ELOOP"
            case _ => "EUNKNOWN"
        }
    }
}

// 注意: PosixSignalHandle 已移至 posix_signal_handle.cj
// 注意: ProcessAutoKiller 已移至 process_auto_killer.cj

// 注意: PosixSignalHandle 已移至 posix_signal_handle.cj
// 注意: ProcessAutoKiller 已移至 process_auto_killer.cj
// 注意: RegularExpression 已移至 regular_expression.cj
// 注意: RegexMatchResult 已移至 regular_expression.cj
// 注意: TextCodec 已移至 text_codec.cj
// 注意: JsModuleLoader 已移至 module_loader.cj
// 注意: NodeModuleModule 已移至 node_module_module.cj
// 注意: CommonAbortReason 已移至 common_abort_reason.cj
// 注意: CommonStrings 已移至 common_strings.cj
// 注意: AbortSignal 已移至 abort_signal.cj
// 注意: AbortController 已移至 abort_signal.cj

// 注意: AnyPromise 已移至 any_promise.cj
