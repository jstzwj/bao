// 严格翻译自: src/jsc/JSType.zig (840行)
// JavaScriptCore JSType 类型枚举 - JS 值类型系统

package bao_jsc

// ========== JSType 枚举 ==========
// 严格翻译自 JSType.zig JSType
// JSType 是 JavaScriptCore 中的关键性能优化，实现 O(1) 类型识别
// 该枚举提供了 JavaScript 运行时类型的完整分类
public enum JSType {
    | Unknown
    | Cell
    | Structure
    | String
    | HeapBigInt
    | HeapDouble
    | HeapInt32
    | Symbol
    | StringObject
    | DerivedStringObject
    | JSFunction
    | FunctionExecutable
    | InternalFunction
    | Array
    | DerivedArray
    | ArrayBuffer
    | Int8Array
    | Uint8Array
    | Uint8ClampedArray
    | Int16Array
    | Uint16Array
    | Int32Array
    | Uint32Array
    | Float16Array
    | Float32Array
    | Float64Array
    | BigInt64Array
    | BigUint64Array
    | Set
    | WeakSet
    | Map
    | WeakMap
    | DirectArguments
    | ClonedArguments
    | ScopedArguments
    | DataView
    | Object
    | ProxyObject
    | DOMWrapper
    | GlobalObject
    | RegExpObject
    | BooleanObject
    | NumberObject
    | MapIterator
    | SetIterator
    | Date
    | Promise
    | Event
    | APIValueWrapper
    | NativeExecutable
    | ProgramExecutable
    | ModuleProgramExecutable
    | EvalExecutable
    | CodeBlock
    | JSCellButterfly
    | JSSourceCode
    | SlimPromiseReaction
    | FullPromiseReaction
    | PromiseAllContext
    | PromiseAllGlobalContext
    | ErrorInstance
    | FinalObject
    | JSArrayIterator
    | AsyncGenerator
    | JSDate
    | JSPromise
    | Generator
    | IteratorHelper
    | Iterator
    | StringIterator
    | ModuleNamespaceObject
    | None

    public operator func ==(right: JSType): Bool {
        match (this) {
            case Unknown => match(right) { case Unknown => true case _ => false }
            case Cell => match(right) { case Cell => true case _ => false }
            case Structure => match(right) { case Structure => true case _ => false }
            case String => match(right) { case String => true case _ => false }
            case HeapBigInt => match(right) { case HeapBigInt => true case _ => false }
            case HeapDouble => match(right) { case HeapDouble => true case _ => false }
            case HeapInt32 => match(right) { case HeapInt32 => true case _ => false }
            case Symbol => match(right) { case Symbol => true case _ => false }
            case StringObject => match(right) { case StringObject => true case _ => false }
            case DerivedStringObject => match(right) { case DerivedStringObject => true case _ => false }
            case JSFunction => match(right) { case JSFunction => true case _ => false }
            case FunctionExecutable => match(right) { case FunctionExecutable => true case _ => false }
            case InternalFunction => match(right) { case InternalFunction => true case _ => false }
            case Array => match(right) { case Array => true case _ => false }
            case DerivedArray => match(right) { case DerivedArray => true case _ => false }
            case ArrayBuffer => match(right) { case ArrayBuffer => true case _ => false }
            case Int8Array => match(right) { case Int8Array => true case _ => false }
            case Uint8Array => match(right) { case Uint8Array => true case _ => false }
            case Uint8ClampedArray => match(right) { case Uint8ClampedArray => true case _ => false }
            case Int16Array => match(right) { case Int16Array => true case _ => false }
            case Uint16Array => match(right) { case Uint16Array => true case _ => false }
            case Int32Array => match(right) { case Int32Array => true case _ => false }
            case Uint32Array => match(right) { case Uint32Array => true case _ => false }
            case Float16Array => match(right) { case Float16Array => true case _ => false }
            case Float32Array => match(right) { case Float32Array => true case _ => false }
            case Float64Array => match(right) { case Float64Array => true case _ => false }
            case BigInt64Array => match(right) { case BigInt64Array => true case _ => false }
            case BigUint64Array => match(right) { case BigUint64Array => true case _ => false }
            case Set => match(right) { case Set => true case _ => false }
            case WeakSet => match(right) { case WeakSet => true case _ => false }
            case Map => match(right) { case Map => true case _ => false }
            case WeakMap => match(right) { case WeakMap => true case _ => false }
            case DirectArguments => match(right) { case DirectArguments => true case _ => false }
            case ClonedArguments => match(right) { case ClonedArguments => true case _ => false }
            case ScopedArguments => match(right) { case ScopedArguments => true case _ => false }
            case DataView => match(right) { case DataView => true case _ => false }
            case Object => match(right) { case Object => true case _ => false }
            case ProxyObject => match(right) { case ProxyObject => true case _ => false }
            case DOMWrapper => match(right) { case DOMWrapper => true case _ => false }
            case GlobalObject => match(right) { case GlobalObject => true case _ => false }
            case RegExpObject => match(right) { case RegExpObject => true case _ => false }
            case BooleanObject => match(right) { case BooleanObject => true case _ => false }
            case NumberObject => match(right) { case NumberObject => true case _ => false }
            case MapIterator => match(right) { case MapIterator => true case _ => false }
            case SetIterator => match(right) { case SetIterator => true case _ => false }
            case Date => match(right) { case Date => true case _ => false }
            case Promise => match(right) { case Promise => true case _ => false }
            case Event => match(right) { case Event => true case _ => false }
            case None => match(right) { case None => true case _ => false }
            case _ => match(right) { case _ => false }
        }
    }

    public operator func !=(right: JSType): Bool {
        match (this == right) {
            case true => false
            case false => true
        }
    }

    // ========== 类型检查方法 ==========

    // Helper for equality comparison
    public func equals(other: JSType): Bool {
        this == other
    }

    public func notEquals(other: JSType): Bool {
        !equals(other)
    }

    // 严格翻译自 JSType.isObject
    public func isObject(): Bool {
        this != Cell && this != Structure && this != String && this != HeapBigInt &&
        this != HeapDouble && this != HeapInt32 && this != Symbol
    }

    // 严格翻译自 JSType.isString
    public func isString(): Bool {
        this == String
    }

    // 严格翻译自 JSType.isStringObject
    public func isStringObject(): Bool {
        this == StringObject
    }

    // 严格翻译自 JSType.isDerivedStringObject
    public func isDerivedStringObject(): Bool {
        this == DerivedStringObject
    }

    // 严格翻译自 JSType.isStringLike
    public func isStringLike(): Bool {
        this == String || this == StringObject || this == DerivedStringObject
    }

    // 严格翻译自 JSType.isFunction
    public func isFunction(): Bool {
        this == JSFunction || this == FunctionExecutable || this == InternalFunction
    }

    // 严格翻译自 JSType.isArray
    public func isArray(): Bool {
        this == Array || this == DerivedArray
    }

    // 严格翻译自 JSType.isArrayLike
    public func isArrayLike(): Bool {
        isArray() || isTypedArrayOrArrayBuffer()
    }

    // 严格翻译自 JSType.isSet
    public func isSet(): Bool {
        this == Set || this == WeakSet
    }

    // 严格翻译自 JSType.isMap
    public func isMap(): Bool {
        this == Map || this == WeakMap
    }

    // 严格翻译自 JSType.isArguments
    public func isArguments(): Bool {
        this == DirectArguments || this == ClonedArguments || this == ScopedArguments
    }

    // 严格翻译自 JSType.isTypedArrayOrArrayBuffer
    public func isTypedArrayOrArrayBuffer(): Bool {
        this == ArrayBuffer ||
        this == Int8Array || this == Uint8Array || this == Uint8ClampedArray ||
        this == Int16Array || this == Uint16Array ||
        this == Int32Array || this == Uint32Array ||
        this == Float16Array || this == Float32Array || this == Float64Array ||
        this == BigInt64Array || this == BigUint64Array
    }

    // 严格翻译自 JSType.isArrayBufferLike
    public func isArrayBufferLike(): Bool {
        isTypedArrayOrArrayBuffer() || this == DataView
    }

    // 严格翻译自 JSType.isHidden
    public func isHidden(): Bool {
        this == APIValueWrapper ||
        this == NativeExecutable || this == ProgramExecutable ||
        this == ModuleProgramExecutable || this == EvalExecutable ||
        this == FunctionExecutable || this == CodeBlock ||
        this == JSCellButterfly || this == JSSourceCode ||
        this == SlimPromiseReaction || this == FullPromiseReaction ||
        this == PromiseAllContext || this == PromiseAllGlobalContext
    }

    // 严格翻译自 JSType.canGet
    public func canGet(): Bool {
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
    public func isIndexable(): Bool {
        this == Object || this == FinalObject || isArray() ||
        this == ErrorInstance || this == JSFunction || this == InternalFunction ||
        isTypedArrayOrArrayBuffer()
    }

    // 严格翻译自 JSType.toTypedArrayType
    public func toTypedArrayType(): TypedArrayType {
        match (this) {
            case Int8Array => TypedArrayType.TypeInt8
            case Uint8Array => TypedArrayType.TypeUint8
            case Uint8ClampedArray => TypedArrayType.TypeUint8Clamped
            case Int16Array => TypedArrayType.TypeInt16
            case Uint16Array => TypedArrayType.TypeUint16
            case Int32Array => TypedArrayType.TypeInt32
            case Uint32Array => TypedArrayType.TypeUint32
            case Float16Array => TypedArrayType.TypeFloat16
            case Float32Array => TypedArrayType.TypeFloat32
            case Float64Array => TypedArrayType.TypeFloat64
            case BigInt64Array => TypedArrayType.TypeBigInt64
            case BigUint64Array => TypedArrayType.TypeBigUint64
            case DataView => TypedArrayType.TypeDataView
            case _ => TypedArrayType.TypeNone
        }
    }
}

// 注意: JSRuntimeType 已移至 js_runtime_type.cj
// 注意: JSErrorCode 已移至 js_error_code.cj
// 注意: DOMExceptionCode 已移至 js_error_code.cj
// 注意: JSPromiseRejectionOperation 已移至 js_promise_rejection_operation.cj
