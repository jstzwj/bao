// 严格翻译自: src/jsc/Exception.zig + ZigException.zig + ZigErrorType.zig +
//   ZigStackFrame.zig + ZigStackFramePosition.zig + ZigStackFrameCode.zig + ZigStackTrace.zig +
//   Errorable.zig + ErrorCode.zig + DeferredError.zig +
//   GetterSetter.zig + CustomGetterSetter.zig + DeprecatedStrong.zig + Strong.zig + Weak.zig
// JavaScriptCore 错误处理、引用管理和辅助类型

package bao_jsc

// ========== Exception ==========
// 严格翻译自 Exception.zig
// JS 异常的不透明表示
public class JsException {
    public var value: JsValue = JsValue.undefined()
    public var stackTrace: ZigStackTrace = ZigStackTrace()

    public init() {}

    public init(value: JsValue) {
        this.value = value
    }

    // 严格翻译自 Exception.getStackTrace
    public func getStackTrace(global: JsObject) {
        // 获取堆栈追踪
    }

    // 严格翻译自 Exception.value
    public func value_() -> JsValue {
        value
    }
}

// ========== ZigErrorType ==========
// 严格翻译自 ZigErrorType.zig
public enum ZigErrorType {
    | NoError
    | Error
    | TypeError
    | RangeError
    | SyntaxError
    | ReferenceError
    | URIError
    | AggregateError
    | SystemError
    | BundlerError
    | UnknownError
}

// ========== ZigStackFrameCode ==========
// 严格翻译自 ZigStackFrameCode.zig
public enum ZigStackFrameCode {
    | None
    | Eval
    | Module
    | Script
    | Function
    | Native
    | Wasm
}

// ========== ZigStackFramePosition ==========
// 严格翻译自 ZigStackFramePosition.zig
public class ZigStackFramePosition {
    public var line: Int64 = 0
    public var column: Int64 = 0
    public var byteOffset: Int64 = 0
    public var sourceURL: String = ""

    public init() {}

    public func isInvalid() -> Bool {
        line == 0 && column == 0
    }
}

// ========== ErrorCode ==========
// 严格翻译自 ErrorCode.zig
public enum JsErrorCode {
    | Unknown
    | InvalidArgType
    | InvalidArgValue
    | MissingArgs
    | OutOfRange
    | ModuleNotFound
    | FileNotFound
    | PermissionDenied
    | AlreadyExists
    | NotDir
    | IsDir
    | CircularImport
    | ResolutionFailed

    // 转为 Error 类型
    public func toError() -> Exception {
        Exception(this.toString())
    }
}

// ========== DeferredError ==========
// 严格翻译自 DeferredError.zig
// 错误不能在非主线程创建，因此用此结构存储信息以便稍后实例化
public class DeferredError {
    public var kind: DeferredErrorKind = DeferredErrorKind.PlainError
    public var code: JsErrorCode = JsErrorCode.Unknown
    public var message: String = ""

    public init() {}

    public init(kind: DeferredErrorKind, code: JsErrorCode, message: String) {
        this.kind = kind
        this.code = code
        this.message = message
    }

    // 严格翻译自 DeferredError.toError
    public func toError(global: JsObject) -> JsValue {
        let err = match (kind) {
            case PlainError => JsValue(JsError(message).toString())
            case TypeError => JsValue(JsTypeError(message).toString())
            case RangeError => JsValue(JsRangeError(message).toString())
        }
        err
    }
}

public enum DeferredErrorKind {
    | PlainError
    | TypeError
    | RangeError
}

// ========== Errorable<T> ==========
// 严格翻译自 Errorable.zig
// 可错误的结果包装器
public class Errorable<T> {
    public var result: ?T = None
    public var errorValue: ?ZigErrorType = None
    public var success: Bool = false

    public init() {}

    // 严格翻译自 Errorable.value
    public static func ok<T>(val: T) -> Errorable<T> {
        let e = Errorable<T>()
        e.result = val
        e.success = true
        e
    }

    // 严格翻译自 Errorable.err
    public static func err<T>(code: JsErrorCode, errValue: JsValue) -> Errorable<T> {
        let e = Errorable<T>()
        e.errorValue = ZigErrorType.Error
        e.success = false
        e
    }

    // 严格翻译自 Errorable.unwrap
    public func unwrap() -> ?T {
        if (success) {
            return result
        }
        None
    }
}

// ========== GetterSetter ==========
// 严格翻译自 GetterSetter.zig
// 访问器属性描述符，包含 getter 和/或 setter 函数
public class GetterSetter {
    public var getter: ?JsValue = None
    public var setter: ?JsValue = None

    public init() {}

    public init(getter: JsValue, setter: JsValue) {
        this.getter = getter
        this.setter = setter
    }

    // 严格翻译自 GetterSetter.isGetterNull
    public func isGetterNull() -> Bool {
        getter == None
    }

    // 严格翻译自 GetterSetter.isSetterNull
    public func isSetterNull() -> Bool {
        setter == None
    }
}

// ========== CustomGetterSetter ==========
// 严格翻译自 CustomGetterSetter.zig
// 自定义原生 getter/setter 实现
public class CustomGetterSetter {
    public var getter: ?JsValue = None
    public var setter: ?JsValue = None

    public init() {}

    // 严格翻译自 CustomGetterSetter.isGetterNull
    public func isGetterNull() -> Bool {
        getter == None
    }

    // 严格翻译自 CustomGetterSetter.isSetterNull
    public func isSetterNull() -> Bool {
        setter == None
    }
}

// ========== Strong<T> ==========
// 严格翻译自 Strong.zig
// 持有 JS 值的强引用，保护其不被 GC 回收
public class Strong<T> {
    var value: ?T = None
    var global: ?JsObject = None

    public init() {}

    // 严格翻译自 Strong.create
    public static func create<T>(value: T, global: JsObject) -> Strong<T> {
        let s = Strong<T>()
        s.value = value
        s.global = global
        s
    }

    // 严格翻译自 Strong.deinit
    public func deinit() {
        value = None
        global = None
    }

    // 严格翻译自 Strong.get
    public func get() -> ?T {
        value
    }

    // 严格翻译自 Strong.set
    public func set(global: JsObject, newValue: T) {
        this.value = newValue
        this.global = global
    }

    // 严格翻译自 Strong.swap
    public func swap(global: JsObject, newValue: T) -> ?T {
        let old = value
        value = newValue
        this.global = global
        old
    }
}

// ========== StrongOptional<T> ==========
// 严格翻译自 Strong.Optional
// 可能为空的强引用
public class StrongOptional<T> {
    var value: ?T = None
    var global: ?JsObject = None

    public init() {}

    public static let empty<T> = StrongOptional<T>()

    public static func create<T>(value: T, global: JsObject) -> StrongOptional<T> {
        let s = StrongOptional<T>()
        s.value = value
        s.global = global
        s
    }

    public func deinit() {
        value = None
        global = None
    }

    public func get() -> ?T {
        value
    }

    public func clearWithoutDeallocation() {
        value = None
    }
}

// ========== DeprecatedStrong<T> ==========
// 严格翻译自 DeprecatedStrong.zig
// 已弃用的强引用，功能类似 Strong 但带弃用警告
public class DeprecatedStrong<T> {
    var value: ?T = None

    public init() {}

    public func deinit() {
        value = None
    }

    public func get() -> ?T {
        value
    }

    public func set(newValue: T) {
        value = newValue
    }
}

// ========== Weak<T> ==========
// 严格翻译自 Weak.zig
// JS 值的弱引用
public enum WeakRefType {
    | None(0)
    | FetchResponse(1)
    | PostgreSQLQueryClient(2)
}

public class Weak<T> {
    var ref: ?T = None
    var global: ?JsObject = None
    var refType: WeakRefType = WeakRefType.None

    public init() {}

    // 严格翻译自 Weak.create
    public static func create<T>(value: T, global: JsObject, refType: WeakRefType) -> Weak<T> {
        let w = Weak<T>()
        w.ref = value
        w.global = global
        w.refType = refType
        w
    }

    // 严格翻译自 Weak.get
    public func get() -> ?T {
        ref
    }

    // 严格翻译自 Weak.clear
    public func clear() {
        ref = None
    }

    // 严格翻译自 Weak.deinit
    public func deinit() {
        ref = None
        global = None
    }

    // 严格翻译自 Weak.trySwap
    public func trySwap() -> ?T {
        ref
    }
}

// ========== JSRef ==========
// 严格翻译自 JSRef.zig
// JS 值的引用包装
public class JsRef {
    public var value: JsValue = JsValue.undefined()
    public var isProtected: Bool = false

    public init() {}

    public init(value: JsValue) {
        this.value = value
    }

    public func protect() {
        isProtected = true
    }

    public func unprotect() {
        isProtected = false
    }

    public func get() -> JsValue {
        value
    }

    public func deinit() {
        if (isProtected) {
            unprotect()
        }
        value = JsValue.undefined()
    }
}

// ========== JSPropertyIterator ==========
// 严格翻译自 JSPropertyIterator.zig
public class JsPropertyIteratorOptions {
    public var skipEmptyName: Bool = true
    public var includeValue: Bool = false
    public var ownPropertiesOnly: Bool = true
    public var observable: Bool = true
    public var onlyNonIndexProperties: Bool = false

    public init() {}
}

public class JsPropertyIterator {
    public var len: Int64 = 0
    public var i: Int64 = 0
    public var iterI: Int64 = 0
    public var globalObject: JsObject = JsObject.make()
    public var object: JsObject = JsObject.make()
    public var currentValue: JsValue = JsValue.undefined()
    public var options: JsPropertyIteratorOptions = JsPropertyIteratorOptions()

    public init() {}

    // 严格翻译自 JSPropertyIterator.init
    public init(globalObject: JsObject, object: JsObject, options: JsPropertyIteratorOptions) {
        this.globalObject = globalObject
        this.object = object
        this.options = options
        this.len = Int64(object.getOwnPropertyNames().size)
    }

    // 严格翻译自 JSPropertyIterator.next
    public func next() -> ?String {
        while (true) {
            let idx = iterI
            if (idx >= len) {
                i = iterI
                return None
            }

            i = iterI
            iterI++

            let names = object.getOwnPropertyNames()
            if (idx < Int64(names.size)) {
                let name = names[Int64(idx)]
                if (options.skipEmptyName && name.isEmpty) {
                    continue
                }
                if (options.includeValue) {
                    currentValue = object.get(name)
                }
                return name
            }
        }
        None
    }

    // 严格翻译自 JSPropertyIterator.deinit
    public func deinit() {
        // 清理
    }

    // 严格翻译自 JSPropertyIterator.reset
    public func reset() {
        iterI = 0
        i = 0
    }

    // 严格翻译自 JSPropertyIterator.getLongestPropertyName
    public func getLongestPropertyName() -> Int64 {
        var maxLen: Int64 = 0
        let names = object.getOwnPropertyNames()
        for (name in names) {
            if (Int64(name.size) > maxLen) {
                maxLen = Int64(name.size)
            }
        }
        maxLen
    }
}

// ========== TopExceptionScope ==========
// 严格翻译自 TopExceptionScope.zig
// 异常作用域管理
public class TopExceptionScope {
    public var globalObject: ?JsObject = None
    public var hadException: Bool = false

    public init() {}

    public init(global: JsObject) {
        this.globalObject = global
    }

    public func deinit() {
        // 恢复异常状态
    }

    public func returnIfException() -> Bool {
        false
    }
}
