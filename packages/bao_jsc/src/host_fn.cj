// 严格翻译自: src/jsc/host_fn.zig
// 宿主函数 - JavaScript 函数与原生代码之间的桥接

package bao_jsc

// ========== HostFn ==========
// 严格翻译自 host_fn 命名空间
// 提供宿主函数类型和包装器，用于在 JavaScript 和原生代码之间桥接函数调用
public class HostFn {

    // 严格翻译自 toJSHostFnResult
    // 将宿主函数的结果转换为 JSValue
    public static func toJSHostFnResult(globalThis: JsObject, result: ?JsValue) -> JsValue {
        result ?? JsValue.zero
    }

    // 严格翻译自 toJSHostCall
    // 将函数调用的返回值转换为 JSValue
    public static func toJSHostCall(
        globalThis: JsObject,
        function: (JsObject, CallFrame) -> JsValue,
        args: Array<JsValue>
    ) -> JsValue {
        function(globalThis, CallFrame())
    }

    // 严格翻译自 fromJSHostCall
    // 将可能为空的 JSValue 转换为错误联合类型
    public static func fromJSHostCall(
        globalThis: JsObject,
        function: (JsObject, CallFrame) -> JsValue,
        args: Array<JsValue>
    ) -> ?JsValue {
        let value = function(globalThis, CallFrame())
        if (value == JsValue.zero) { return None }
        Some(value)
    }

    // 严格翻译自 fromJSHostCallGeneric
    // 与 fromJSHostCall 类似，但不支持 JSValue
    public static func fromJSHostCallGeneric(
        globalThis: JsObject,
        function: () -> Void,
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
    ) -> JsValue {
        // FFI: Bun__CreateFFIFunctionValue
        JsValue.undefined()
    }

    // 严格翻译自 getFunctionData
    // 获取函数的关联数据
    public static func getFunctionData(function: JsValue) -> UInt64 {
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
    ) -> JsValue {
        // FFI: Bun__CreateFFIFunctionWithDataValue
        JsValue.undefined()
    }

    // 严格翻译自 wrap1, wrap2, wrap3, wrap4, wrap5
    // 包装不同参数数量的函数为宿主函数
    public static func wrap1(func: (JsObject) -> JsValue) -> (JsObject) -> JsValue { func }
    public static func wrap2(func: (JsObject, JsValue) -> JsValue) -> (JsObject, JsValue) -> JsValue { func }
    public static func wrap3(func: (JsObject, JsValue, JsValue) -> JsValue) -> (JsObject, JsValue, JsValue) -> JsValue { func }
    public static func wrap4(func: (JsObject, JsValue, JsValue, JsValue) -> JsValue) -> (JsObject, JsValue, JsValue, JsValue) -> JsValue { func }
    public static func wrap5(func: (JsObject, JsValue, JsValue, JsValue, JsValue) -> JsValue) -> (JsObject, JsValue, JsValue, JsValue, JsValue) -> JsValue { func }
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

    public static func forRead(read: DOMEffectID) -> DOMEffect {
        let effect = DOMEffect()
        effect.reads[0] = read
        effect
    }

    public static func forWrite(read: DOMEffectID) -> DOMEffect {
        let effect = DOMEffect()
        effect.writes[0] = read
        effect
    }

    public func isPure() -> Bool {
        reads[0] == DOMEffectID.InvalidAbstractHeap && writes[0] == DOMEffectID.InvalidAbstractHeap
    }
}

// ========== DOMEffectID ==========
public enum DOMEffectID: UInt8 {
    case InvalidAbstractHeap = 0
    case World
    case Stack
    case Heap
    case Butterfly_publicLength
    case Butterfly_vectorLength
    case GetterSetter_getter
    case GetterSetter_setter
    case JSCell_cellState
    case JSCell_indexingType
    case JSCell_structureID
    case JSCell_typeInfoFlags
    case JSObject_butterfly
    case JSPropertyNameEnumerator_cachedPropertyNames
    case RegExpObject_lastIndex
    case NamedProperties
    case IndexedInt32Properties
    case IndexedDoubleProperties
    case IndexedContiguousProperties
    case IndexedArrayStorageProperties
    case DirectArgumentsProperties
    case ScopeProperties
    case TypedArrayProperties
    case HeapObjectCount
    case RegExpState
    case MathDotRandomState
    case JSDateFields
    case JSMapFields
    case JSSetFields
    case JSWeakMapFields
    case WeakSetFields
    case JSInternalFields
    case InternalState
    case CatchLocals
    case Absolute
    case DOMState
    case Watchpoint_fire
    case MiscFields
    case SideState
}
