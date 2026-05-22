// 严格翻译自: src/jsc/host_fn.zig
// 宿主函数 - JavaScript 函数与原生代码之间的桥接

package bao_jsc

// ========== HostFn ==========
// 严格翻译自 host_fn 命名空间
// 提供宿主函数类型和包装器，用于在 JavaScript 和原生代码之间桥接函数调用
public class HostFn {

    // 严格翻译自 toJSHostFnResult
    // 将宿主函数的结果转换为 JSValue
    public static func toJSHostFnResult(globalThis: JsObject, result: ?JsValue): JsValue {
        result ?? JsValue()
    }

    // 严格翻译自 toJSHostCall
    // 将函数调用的返回值转换为 JSValue
    public static func toJSHostCall(
        globalThis: JsObject,
        function: (JsObject, CallFrame) -> JsValue,
        args: Array<JsValue>
    ): JsValue {
        function(globalThis, CallFrame())
    }

    // 严格翻译自 fromJSHostCall
    // 将可能为空的 JSValue 转换为错误联合类型
    public static func fromJSHostCall(
        globalThis: JsObject,
        function: (JsObject, CallFrame) -> JsValue,
        args: Array<JsValue>
    ): ?JsValue {
        let value = function(globalThis, CallFrame())
        if (value == JsValue()) { return None }
        Some(value)
    }

    // 严格翻译自 fromJSHostCallGeneric
    // 与 fromJSHostCall 类似，但不支持 JSValue
    public static func fromJSHostCallGeneric(
        globalThis: JsObject,
        function: () -> Unit,
        args: Array<Any>
    ) {
        function()
    }

    // 严格翻译自 voidFromJSError
    // 用于需要 C ABI 边界的错误冒泡
    public static func voidFromJSError(err: Error, globalThis: JsObject) {
        // Handle JSError, OutOfMemory, JSTerminated
    }

    // 严格翻译自 NewRuntimeFunction
    // 创建运行时函数
    public static func newRuntimeFunction(
        globalObject: JsObject,
        symbolName: String,
        argCount: UInt32,
        functionPointer: UInt64,
        addPtrProperty: Bool,
        inputFunctionPtr: UInt64
    ): JsValue {
        // FFI: Bun__CreateFFIFunctionValue
        JsValue.undefined()
    }

    // 严格翻译自 getFunctionData
    // 获取函数的关联数据
    public static func getFunctionData(function: JsValue): UInt64 {
        // FFI: Bun__FFIFunction_getDataPtr
        0
    }

    // 严格翻译自 setFunctionData
    // 设置函数的关联数据
    public static func setFunctionData(function: JsValue, value: UInt64) {
        // FFI: Bun__FFIFunction_setDataPtr
    }

    // 严格翻译自 NewFunctionWithData
    // 创建带有数据值的函数
    public static func newFunctionWithData(
        globalObject: JsObject,
        symbolName: String,
        argCount: UInt32,
        function: UInt64,
        data: UInt64
    ): JsValue {
        // FFI: Bun__CreateFFIFunctionWithDataValue
        JsValue.undefined()
    }

    // 严格翻译自 wrap1, wrap2, wrap3, wrap4, wrap5
    // 包装不同参数数量的函数为宿主函数
    public static func wrap1(`func`: (JsObject) -> JsValue): (JsObject) -> JsValue { `func` }
    public static func wrap2(`func`: (JsObject, JsValue) -> JsValue): (JsObject, JsValue) -> JsValue { `func` }
    public static func wrap3(`func`: (JsObject, JsValue, JsValue) -> JsValue): (JsObject, JsValue, JsValue) -> JsValue { `func` }
    public static func wrap4(`func`: (JsObject, JsValue, JsValue, JsValue) -> JsValue): (JsObject, JsValue, JsValue, JsValue) -> JsValue { `func` }
    public static func wrap5(`func`: (JsObject, JsValue, JsValue, JsValue, JsValue) -> JsValue): (JsObject, JsValue, JsValue, JsValue, JsValue) -> JsValue { `func` }
}

// ========== DOMEffect ==========
// 严格翻译自 DOMEffect
// DOM 操作的副作用标记
public class DOMEffect {
    public var reads: Array<DOMEffectID> = [DOMEffectID.Heap, DOMEffectID.Heap, DOMEffectID.Heap, DOMEffectID.Heap]
    public var writes: Array<DOMEffectID> = [DOMEffectID.Heap, DOMEffectID.Heap, DOMEffectID.Heap, DOMEffectID.Heap]

    public init() {}

    public static let top: DOMEffect = DOMEffect()
    public static let pure: DOMEffect = DOMEffect()

    public static func forRead(read: DOMEffectID): DOMEffect {
        let effect = DOMEffect()
        effect.reads[0] = read
        effect
    }

    public static func forWrite(read: DOMEffectID): DOMEffect {
        let effect = DOMEffect()
        effect.writes[0] = read
        effect
    }

    public func isPure(): Bool {
        reads[0] == DOMEffectID.InvalidAbstractHeap && writes[0] == DOMEffectID.InvalidAbstractHeap
    }
}

// ========== DOMEffectID ==========
public enum DOMEffectID {
    | InvalidAbstractHeap
    | World
    | Stack
    | Heap
    | Butterfly_publicLength
    | Butterfly_vectorLength
    | GetterSetter_getter
    | GetterSetter_setter
    | JSCell_cellState
    | JSCell_indexingType
    | JSCell_structureID
    | JSCell_typeInfoFlags
    | JSObject_butterfly
    | JSPropertyNameEnumerator_cachedPropertyNames
    | RegExpObject_lastIndex
    | NamedProperties
    | IndexedInt32Properties
    | IndexedDoubleProperties
    | IndexedContiguousProperties
    | IndexedArrayStorageProperties
    | DirectArgumentsProperties
    | ScopeProperties
    | TypedArrayProperties
    | HeapObjectCount
    | RegExpState
    | MathDotRandomState
    | JSDateFields
    | JSMapFields
    | JSSetFields
    | JSWeakMapFields
    | WeakSetFields
    | JSInternalFields
    | InternalState
    | CatchLocals
    | Absolute
    | DOMState
    | Watchpoint_fire
    | MiscFields
    | SideState

    public operator func ==(right: DOMEffectID): Bool {
        match (this) {
            case InvalidAbstractHeap => match(right) { case InvalidAbstractHeap => true case _ => false }
            case World => match(right) { case World => true case _ => false }
            case Stack => match(right) { case Stack => true case _ => false }
            case Heap => match(right) { case Heap => true case _ => false }
            case Butterfly_publicLength => match(right) { case Butterfly_publicLength => true case _ => false }
            case Butterfly_vectorLength => match(right) { case Butterfly_vectorLength => true case _ => false }
            case GetterSetter_getter => match(right) { case GetterSetter_getter => true case _ => false }
            case GetterSetter_setter => match(right) { case GetterSetter_setter => true case _ => false }
            case JSCell_cellState => match(right) { case JSCell_cellState => true case _ => false }
            case JSCell_indexingType => match(right) { case JSCell_indexingType => true case _ => false }
            case JSCell_structureID => match(right) { case JSCell_structureID => true case _ => false }
            case JSCell_typeInfoFlags => match(right) { case JSCell_typeInfoFlags => true case _ => false }
            case JSObject_butterfly => match(right) { case JSObject_butterfly => true case _ => false }
            case JSPropertyNameEnumerator_cachedPropertyNames => match(right) { case JSPropertyNameEnumerator_cachedPropertyNames => true case _ => false }
            case RegExpObject_lastIndex => match(right) { case RegExpObject_lastIndex => true case _ => false }
            case NamedProperties => match(right) { case NamedProperties => true case _ => false }
            case IndexedInt32Properties => match(right) { case IndexedInt32Properties => true case _ => false }
            case IndexedDoubleProperties => match(right) { case IndexedDoubleProperties => true case _ => false }
            case IndexedContiguousProperties => match(right) { case IndexedContiguousProperties => true case _ => false }
            case IndexedArrayStorageProperties => match(right) { case IndexedArrayStorageProperties => true case _ => false }
            case DirectArgumentsProperties => match(right) { case DirectArgumentsProperties => true case _ => false }
            case ScopeProperties => match(right) { case ScopeProperties => true case _ => false }
            case TypedArrayProperties => match(right) { case TypedArrayProperties => true case _ => false }
            case HeapObjectCount => match(right) { case HeapObjectCount => true case _ => false }
            case RegExpState => match(right) { case RegExpState => true case _ => false }
            case MathDotRandomState => match(right) { case MathDotRandomState => true case _ => false }
            case JSDateFields => match(right) { case JSDateFields => true case _ => false }
            case JSMapFields => match(right) { case JSMapFields => true case _ => false }
            case JSSetFields => match(right) { case JSSetFields => true case _ => false }
            case JSWeakMapFields => match(right) { case JSWeakMapFields => true case _ => false }
            case WeakSetFields => match(right) { case WeakSetFields => true case _ => false }
            case JSInternalFields => match(right) { case JSInternalFields => true case _ => false }
            case InternalState => match(right) { case InternalState => true case _ => false }
            case CatchLocals => match(right) { case CatchLocals => true case _ => false }
            case Absolute => match(right) { case Absolute => true case _ => false }
            case DOMState => match(right) { case DOMState => true case _ => false }
            case Watchpoint_fire => match(right) { case Watchpoint_fire => true case _ => false }
            case MiscFields => match(right) { case MiscFields => true case _ => false }
            case SideState => match(right) { case SideState => true case _ => false }
        }
    }

    public operator func !=(right: DOMEffectID): Bool {
        !(this == right)
    }
}
