// 严格翻译自: src/jsc/ZigErrorType.zig + ZigStackFrameCode.zig +
//   Errorable.zig + ErrorCode.zig + DeferredError.zig +
//   GetterSetter.zig + CustomGetterSetter.zig + DeprecatedStrong.zig + JSRef.zig +
//   JSPropertyIterator.zig + TopExceptionScope.zig
// JavaScriptCore 错误处理、引用管理和辅助类型
// 注意: Exception 移至 exception.cj, Strong 移至 strong.cj, Weak 移至 weak.cj

package bao_jsc

// 注意: ZigErrorType 已移至 zig_error_type.cj
// 注意: ZigStackFrameCode 已移至 zig_stack_frame_code.cj
// 注意: ZigStackFramePosition 已移至 zig_stack_frame_position.cj

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

    public func toName(): String {
        match (this) {
            case Unknown => "Unknown"
            case InvalidArgType => "InvalidArgType"
            case InvalidArgValue => "InvalidArgValue"
            case MissingArgs => "MissingArgs"
            case OutOfRange => "OutOfRange"
            case ModuleNotFound => "ModuleNotFound"
            case FileNotFound => "FileNotFound"
            case PermissionDenied => "PermissionDenied"
            case AlreadyExists => "AlreadyExists"
            case NotDir => "NotDir"
            case IsDir => "IsDir"
            case CircularImport => "CircularImport"
            case ResolutionFailed => "ResolutionFailed"
        }
    }

    // 转为 Error 类型
    public func toError(): Exception {
        Exception(toName())
    }
}

// 注意: DeferredError 已移至 deferred_error.cj
// 注意: DeferredErrorKind 已移至 deferred_error.cj
// 注意: Errorable<T> 已移至 errorable.cj

// 注意: GetterSetter 已移至 getter_setter.cj

// 注意: CustomGetterSetter 已移至 custom_getter_setter.cj
// 注意: DeprecatedStrong 已移至 deprecated_strong.cj

// 注意: Strong<T> 已移至 strong.cj
// 注意: Weak<T> 已移至 weak.cj
// 注意: WeakRefType 已移至 weak.cj

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

    public func isStrong(): Bool {
        return isProtected
    }

    public func get(): JsValue {
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
    public func next(): ?String {
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
                if (options.skipEmptyName && name.isEmpty()) {
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
    public func getLongestPropertyName(): Int64 {
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

// 注意: TopExceptionScope 已移至 top_exception_scope.cj
