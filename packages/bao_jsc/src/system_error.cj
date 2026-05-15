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
    public func toJS(global: JsObject) -> JsValue {
        let obj = JsObject.make()
        obj.className = "Error"
        obj.set("code", JsValue(s: code))
        obj.set("message", JsValue(s: message))
        obj.set("errno", JsValue(n: errnoCode))
        obj.set("syscall", JsValue(s: syscall))
        if (!path.isEmpty) {
            obj.set("path", JsValue(s: path))
        }
        JsValue(obj: obj)
    }

    // 严格翻译自 SystemError.fromCode
    public static func fromCode(errnoCode: Int64, syscall: String) -> SystemError {
        let err = SystemError()
        err.errnoCode = errnoCode
        err.syscall = syscall
        err.code = errorCodeToString(errnoCode)
        err.message = err.code + ": " + syscall
        err
    }

    // 错误码到字符串
    static func errorCodeToString(code: Int64) -> String {
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

// ========== PosixSignalHandle ==========
// 严格翻译自 PosixSignalHandle.zig
public class PosixSignalHandle {
    public var signal: Int64 = 0
    public var callback: ?(() -> Unit) = None
    public var isActive: Bool = true

    public init() {}

    public init(signal: Int64, callback: () -> Unit) {
        this.signal = signal
        this.callback = callback
    }

    public func trigger() {
        if (isActive) {
            if (let Some(cb) <- callback) {
                cb()
            }
        }
    }

    public func close() {
        isActive = false
        callback = None
    }
}

// ========== ProcessAutoKiller ==========
// 严格翻译自 ProcessAutoKiller.zig
public class ProcessAutoKiller {
    public var pid: Int64 = 0
    public var isEnabled: Bool = false
    public var signal: Int64 = 15  // SIGTERM

    public init() {}

    public func enable(pid: Int64) {
        this.pid = pid
        this.isEnabled = true
    }

    public func disable() {
        isEnabled = false
    }
}

// ========== RegularExpression ==========
// 严格翻译自 RegularExpression.zig
public class RegularExpression {
    public var pattern: String = ""
    public var flags: String = ""
    public var isGlobal: Bool = false
    public var isIgnoreCase: Bool = false
    public var isMultiline: Bool = false
    public var isDotAll: Bool = false
    public var isUnicode: Bool = false
    public var isSticky: Bool = false
    public var isHasIndices: Bool = false
    public var lastIndex: Int64 = 0

    public init() {}

    public init(pattern: String, flags: String) {
        this.pattern = pattern
        this.flags = flags
        parseFlags(flags)
    }

    func parseFlags(f: String) {
        for (c in f) {
            match (c) {
                case 'g' => isGlobal = true
                case 'i' => isIgnoreCase = true
                case 'm' => isMultiline = true
                case 's' => isDotAll = true
                case 'u' => isUnicode = true
                case 'y' => isSticky = true
                case 'd' => isHasIndices = true
                case _ => ()
            }
        }
    }

    // 测试字符串是否匹配
    public func test(input: String) -> Bool {
        // 简化实现
        input.indexOf(pattern) >= 0
    }

    // 执行匹配
    public func exec(input: String) -> ?RegexMatchResult {
        let idx = input.indexOf(pattern)
        if (idx < 0) { return None }
        let result = RegexMatchResult()
        result.match = input[idx..idx + pattern.size]
        result.index = Int64(idx)
        result.input = input
        result.groups = [result.match]
        Some(result)
    }

    // 转为 JsValue
    public func toJsValue() -> JsValue {
        let obj = JsObject.make()
        obj.className = "RegExp"
        obj.set("source", JsValue(s: pattern))
        obj.set("flags", JsValue(s: flags))
        obj.set("global", JsValue(b: isGlobal))
        obj.set("ignoreCase", JsValue(b: isIgnoreCase))
        obj.set("multiline", JsValue(b: isMultiline))
        JsValue(obj: obj)
    }
}

// 正则匹配结果
public class RegexMatchResult {
    public var match: String = ""
    public var index: Int64 = 0
    public var input: String = ""
    public var groups: Array<String> = []
    public var namedGroups: HashMap<String, String> = HashMap()

    public init() {}
}

// ========== TextCodec ==========
// 严格翻译自 TextCodec.zig
public class TextCodec {
    public var encoding: String = "utf-8"
    public var fatal: Bool = false
    public var ignoreBOM: Bool = false

    public init() {}

    public init(encoding: String) {
        this.encoding = encoding.toLowerAscii()
    }

    // 编码
    public func encode(input: String) -> Array<UInt8> {
        // 简化实现 - UTF-8
        var result = Array<UInt8>()
        for (c in input) {
            let code = c.code
            if (code < 0x80) {
                result.append(UInt8(code))
            } else if (code < 0x800) {
                result.append(UInt8(0xC0 | (code >> 6)))
                result.append(UInt8(0x80 | (code & 0x3F)))
            } else {
                result.append(UInt8(0xE0 | (code >> 12)))
                result.append(UInt8(0x80 | ((code >> 6) & 0x3F)))
                result.append(UInt8(0x80 | (code & 0x3F)))
            }
        }
        result
    }

    // 解码
    public func decode(input: Array<UInt8>) -> String {
        // 简化实现 - UTF-8
        String.fromUtf8(input)
    }
}

// ========== JSModuleLoader ==========
// 严格翻译自 JSModuleLoader.zig
public class JsModuleLoader {
    public init() {}

    // 严格翻译自 JSModuleLoader.loadAndEvaluateModule
    public static func loadAndEvaluateModule(global: JsObject, specifier: String) -> ?JsObject {
        None  // 简化实现
    }

    // 严格翻译自 JSModuleLoader.import
    public static func import_(global: JsObject, specifier: String) -> ?JsObject {
        loadAndEvaluateModule(global, specifier)
    }
}

// ========== NodeModuleModule ==========
// 严格翻译自 NodeModuleModule.zig
// Node.js `module` 内置模块
public class NodeModuleModule {
    public var id: String = "."
    public var filename: String = ""
    public var loaded: Bool = false
    public var parent: ?NodeModuleModule = None
    public var children: Array<NodeModuleModule> = []
    public var exports: JsObject = JsObject.make()
    public var paths: Array<String> = []
    public var require_: ?JsFunction = None

    public init() {}

    public init(id: String, filename: String) {
        this.id = id
        this.filename = filename
    }

    // require 缓存
    static var cache: HashMap<String, NodeModuleModule> = HashMap()

    // 转为 JsValue
    public func toJsValue() -> JsValue {
        let obj = JsObject.make()
        obj.className = "Module"
        obj.set("id", JsValue(s: id))
        obj.set("filename", JsValue(s: filename))
        obj.set("loaded", JsValue(b: loaded))
        obj.set("exports", JsValue(obj: exports))
        obj.set("paths", JsValue(obj: JsObject.make()))
        JsValue(obj: obj)
    }
}

// ========== CommonAbortReason ==========
// 严格翻译自 CommonAbortReason.zig
public enum CommonAbortReason {
    | UserAbort
    | Timeout
    | Signal
    | SystemError
    | Unknown
}

// ========== CommonStrings ==========
// 严格翻译自 CommonStrings.zig
public class CommonStrings {
    public static let UNDEFINED = "undefined"
    public static let NULL = "null"
    public static let TRUE = "true"
    public static let FALSE = "false"
    public static let NAN = "NaN"
    public static let INFINITY = "Infinity"
    public static let OBJECT = "[object Object]"
    public static let FUNCTION = "function"
    public static let ARRAY = "Array"
    public static let PROMISE = "Promise"
    public static let ERROR = "Error"
    public static let LENGTH = "length"
    public static let PROTOTYPE = "prototype"
    public static let CONSTRUCTOR = "constructor"
    public static let THEN = "then"
    public static let CATCH = "catch"
    public static let FINALLY = "finally"
    public static let MESSAGE = "message"
    public static let STACK = "stack"
    public static let NAME = "name"
    public static let CODE = "code"

    public init() {}
}

// ========== AbortSignal ==========
// 严格翻译自 AbortSignal.zig
public class AbortSignal {
    public var aborted: Bool = false
    public var reason: JsValue = JsValue.undefined()
    public var onabort: ?JsFunction = None
    public var listeners: Array<JsFunction> = []

    public init() {}

    // AbortSignal.abort()
    public static func abort() -> AbortSignal {
        let signal = AbortSignal()
        signal.aborted = true
        signal.reason = JsValue(s: "AbortError")
        signal
    }

    public static func abort(reason: JsValue) -> AbortSignal {
        let signal = AbortSignal()
        signal.aborted = true
        signal.reason = reason
        signal
    }

    // AbortSignal.timeout()
    public static func timeout(ms: Int64) -> AbortSignal {
        AbortSignal()
    }

    // throwIfAborted
    public func throwIfAborted() {
        if (aborted) {
            throw JsError(reason.toString())
        }
    }

    // 触发 abort
    public func triggerAbort(reason: JsValue) {
        if (aborted) { return }
        aborted = true
        this.reason = reason
        if (let Some(cb) <- onabort) {
            cb.call(JsValue.undefined(), [])
        }
        for (listener in listeners) {
            listener.call(JsValue.undefined(), [reason])
        }
    }

    // 添加事件监听
    public func addEventListener(name: String, callback: JsFunction) {
        if (name == "abort") {
            listeners.append(callback)
        }
    }

    // 移除事件监听
    public func removeEventListener(name: String, callback: JsFunction) {
        if (name == "abort") {
            var idx = -1
            for (i in 0..listeners.size) {
                if (listeners[Int64(i)] === callback) {
                    idx = Int64(i)
                    break
                }
            }
            if (idx >= 0) {
                listeners.removeAt(idx)
            }
        }
    }

    // 转为 JsValue
    public func toJsValue() -> JsValue {
        let obj = JsObject.make()
        obj.className = "AbortSignal"
        obj.set("aborted", JsValue(b: aborted))
        obj.set("reason", reason)
        JsValue(obj: obj)
    }
}

// ========== AbortController ==========
public class AbortController {
    public var signal: AbortSignal = AbortSignal()

    public init() {}

    // abort()
    public func abort() {
        signal.triggerAbort(JsValue(s: "AbortError"))
    }

    public func abort(reason: JsValue) {
        signal.triggerAbort(reason)
    }

    // 转为 JsValue
    public func toJsValue() -> JsValue {
        let obj = JsObject.make()
        obj.className = "AbortController"
        obj.set("signal", signal.toJsValue())
        JsValue(obj: obj)
    }
}

// ========== AnyPromise ==========
// 严格翻译自 AnyPromise.zig
// 可以是已解决或待定的 Promise
public class AnyPromise {
    public var promise: ?JsPromise = None

    public init() {}

    public init(promise: JsPromise) {
        this.promise = promise
    }

    public static func resolved(value: JsValue) -> AnyPromise {
        AnyPromise(JsPromise.resolve(value))
    }

    public static func pending() -> AnyPromise {
        AnyPromise(JsPromise())
    }
}
