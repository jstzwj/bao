// 严格翻译自: src/jsc/JSType.zig (840行)
// JavaScriptCore JSType 类型枚举 - JS 值类型系统

package bao_jsc

// ========== JSType 枚举 ==========
// 严格翻译自 JSType.zig JSType
// JSType 是 JavaScriptCore 中的关键性能优化，实现 O(1) 类型识别
// 该枚举提供了 JavaScript 运行时类型的完整分类
public enum JSType {
}
    }

    // ========== 类型检查方法 ==========

    // 严格翻译自 JSType.isObject
    public func isObject() -> Bool {
        this != Cell && this != Structure && this != String && this != HeapBigInt &&
        this != HeapDouble && this != HeapInt32 && this != Symbol
    }

    // 严格翻译自 JSType.isString
    public func isString() -> Bool {
        this == String
    }

    // 严格翻译自 JSType.isStringObject
    public func isStringObject() -> Bool {
        this == StringObject
    }

    // 严格翻译自 JSType.isDerivedStringObject
    public func isDerivedStringObject() -> Bool {
        this == DerivedStringObject
    }

    // 严格翻译自 JSType.isStringLike
    public func isStringLike() -> Bool {
        this == String || this == StringObject || this == DerivedStringObject
    }

    // 严格翻译自 JSType.isFunction
    public func isFunction() -> Bool {
        this == JSFunction || this == FunctionExecutable || this == InternalFunction
    }

    // 严格翻译自 JSType.isArray
    public func isArray() -> Bool {
        this == Array || this == DerivedArray
    }

    // 严格翻译自 JSType.isArrayLike
    public func isArrayLike() -> Bool {
        isArray() || isTypedArrayOrArrayBuffer()
    }

    // 严格翻译自 JSType.isSet
    public func isSet() -> Bool {
        this == Set || this == WeakSet
    }

    // 严格翻译自 JSType.isMap
    public func isMap() -> Bool {
        this == Map || this == WeakMap
    }

    // 严格翻译自 JSType.isArguments
    public func isArguments() -> Bool {
        this == DirectArguments || this == ClonedArguments || this == ScopedArguments
    }

    // 严格翻译自 JSType.isTypedArrayOrArrayBuffer
    public func isTypedArrayOrArrayBuffer() -> Bool {
        this == ArrayBuffer ||
        this == Int8Array || this == Uint8Array || this == Uint8ClampedArray ||
        this == Int16Array || this == Uint16Array ||
        this == Int32Array || this == Uint32Array ||
        this == Float16Array || this == Float32Array || this == Float64Array ||
        this == BigInt64Array || this == BigUint64Array
    }

    // 严格翻译自 JSType.isArrayBufferLike
    public func isArrayBufferLike() -> Bool {
        isTypedArrayOrArrayBuffer() || this == DataView
    }

    // 严格翻译自 JSType.isHidden
    public func isHidden() -> Bool {
        this == APIValueWrapper ||
        this == NativeExecutable || this == ProgramExecutable ||
        this == ModuleProgramExecutable || this == EvalExecutable ||
        this == FunctionExecutable || this == CodeBlock ||
        this == JSCellButterfly || this == JSSourceCode ||
        this == SlimPromiseReaction || this == FullPromiseReaction ||
        this == PromiseAllContext || this == PromiseAllGlobalContext
    }

    // 严格翻译自 JSType.canGet
    public func canGet() -> Bool {
        isArray() || isTypedArrayOrArrayBuffer() ||
        this == BooleanObject || this == DataView ||
        this == ErrorInstance || this == FinalObject ||
        this == GlobalObject || this == InternalFunction ||
        this == JSArrayIterator || this == AsyncGenerator ||
        this == JSDate || this == JSFunction ||
        this == Generator || this == Map || this == MapIterator ||
        this == JSPromise || this == Set || this == SetIterator ||
        this == IteratorHelper || this == Iterator || this == StringIterator ||
        this == WeakMap || this == WeakSet || this == ModuleNamespaceObject ||
        this == NumberObject || this == Object || this == ProxyObject ||
        this == RegExpObject || this == StringObject ||
        this == Event || this == DOMWrapper
    }

    // 严格翻译自 JSType.isIndexable
    public func isIndexable() -> Bool {
        this == Object || this == FinalObject || isArray() ||
        this == ErrorInstance || this == JSFunction || this == InternalFunction ||
        isTypedArrayOrArrayBuffer()
    }
}

// ========== JSRuntimeType 枚举 ==========
// 严格翻译自 JSRuntimeType.zig
// 表示 JavaScript 运行时值类型 (位标志)
public enum JSRuntimeType {
}

// ========== JSErrorCode 枚举 ==========
// 严格翻译自 JSErrorCode.zig
// 表示 JavaScript 错误类型
public enum JSErrorCode {
}

// ========== DOMExceptionCode 枚举 ==========
// 严格翻译自 JSErrorCode.zig DOMExceptionCode
public enum DOMExceptionCode {
}

// ========== JSPromiseRejectionOperation 枚举 ==========
// 严格翻译自 JSPromiseRejectionOperation.zig
public enum JSPromiseRejectionOperation {
}
