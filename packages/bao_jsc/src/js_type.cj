// 严格翻译自: src/jsc/JSType.zig (840行)
// JavaScriptCore JSType 类型枚举 - JS 值类型系统

package bao_jsc

// ========== JSType 枚举 ==========
// 严格翻译自 JSType.zig JSType
// JSType 是 JavaScriptCore 中的关键性能优化，实现 O(1) 类型识别
// 该枚举提供了 JavaScript 运行时类型的完整分类
public enum JSType <: UInt8 {
    // ---- 基础类型 ----
    | Cell(0)                    // 所有堆分配 JS 值的基类型
    | Structure(1)               // 描述 JS 对象布局和属性的元数据
    | String(2)                  // JS 字符串原始类型
    | HeapBigInt(3)              // BigInt 堆分配值
    | HeapDouble(4)              // 堆分配的 double 值
    | HeapInt32(5)               // 堆分配的 int32 值
    | Symbol(6)                  // Symbol 原始类型
    | GetterSetter(7)            // getter/setter 访问器属性描述符
    | CustomGetterSetter(8)      // 自定义原生 getter/setter
    | APIValueWrapper(9)         // 原生 API 值包装器
    | NativeExecutable(10)       // 内置函数的编译原生代码
    | ProgramExecutable(11)      // 顶层程序代码的编译可执行文件
    | ModuleProgramExecutable(12) // ES6 模块代码的编译可执行文件
    | EvalExecutable(13)         // eval() 表达式的编译可执行文件
    | FunctionExecutable(14)     // 函数体的编译可执行文件

    // ---- 未链接编译单元 ----
    | UnlinkedFunctionExecutable(15)
    | UnlinkedProgramCodeBlock(16)
    | UnlinkedModuleProgramCodeBlock(17)
    | UnlinkedEvalCodeBlock(18)
    | UnlinkedFunctionCodeBlock(19)
    | CodeBlock(20)              // 编译的字节码块

    // ---- 内部类型 ----
    | JSCellButterfly(21)
    | JSSourceCode(22)
    | SlimPromiseReaction(23)    // 精简 promise 反应
    | FullPromiseReaction(24)    // 完整 promise 反应
    | PromiseAllContext(25)      // Promise.all 上下文
    | PromiseAllGlobalContext(26)
    | JSMicrotaskDispatcher(27)  // 微任务调度器
    | ModuleRegistryEntry(28)    // 模块注册条目
    | ModuleLoadingContext(29)   // 模块加载上下文
    | ModuleLoaderPayload(30)    // 模块加载器负载
    | ModuleGraphLoadingState(31) // 模块图加载状态
    | JSModuleLoader(32)         // JS 模块加载器单元格类型

    // ---- 对象类型 ----
    | Object(33)                 // 基础 JS 对象
    | FinalObject(34)            // 优化过的固定属性对象字面量
    | JSCallee(35)
    | JSFunction(36)             // JS 源码创建的函数
    | InternalFunction(37)       // 原生代码实现的内置函数
    | NullSetterFunction(38)
    | BooleanObject(39)          // 布尔包装对象
    | NumberObject(40)           // 数字包装对象
    | ErrorInstance(41)          // 错误对象
    | GlobalProxy(42)
    | DirectArguments(43)        // 直接参数对象
    | ScopedArguments(44)        // 作用域参数对象
    | ClonedArguments(45)        // 克隆参数对象

    // ---- 数组类型 ----
    | Array(46)                  // JS 数组
    | DerivedArray(47)           // 数组子类
    | ArrayBuffer(48)            // ArrayBuffer
    | Int8Array(49)
    | Uint8Array(50)
    | Uint8ClampedArray(51)
    | Int16Array(52)
    | Uint16Array(53)
    | Int32Array(54)
    | Uint32Array(55)
    | Float16Array(56)
    | Float32Array(57)
    | Float64Array(58)
    | BigInt64Array(59)
    | BigUint64Array(60)
    | DataView(61)

    // ---- 环境/作用域类型 ----
    | GlobalObject(62)           // 全局对象
    | GlobalLexicalEnvironment(63)
    | LexicalEnvironment(64)
    | ModuleEnvironment(65)
    | StrictEvalActivation(66)
    | WithScope(67)              // with 语句作用域

    // ---- 其他 JS 类型 ----
    | AsyncDisposableStack(68)
    | DisposableStack(69)
    | ModuleNamespaceObject(70)  // ES6 模块命名空间对象
    | ShadowRealm(71)
    | RegExpObject(72)           // 正则表达式对象
    | JSDate(73)                 // 日期对象
    | ProxyObject(74)            // Proxy 对象
    | Generator(75)              // 生成器对象
    | AsyncGenerator(76)         // 异步生成器对象
    | JSArrayIterator(77)        // 数组迭代器
    | Iterator(78)               // 通用迭代器
    | IteratorHelper(79)
    | MapIterator(80)            // Map 迭代器
    | SetIterator(81)            // Set 迭代器
    | StringIterator(82)         // 字符串迭代器
    | WrapForValidIterator(83)
    | RegExpStringIterator(84)   // 正则字符串迭代器
    | AsyncFromSyncIterator(85)  // 异步转同步迭代器
    | JSPromise(86)              // Promise 对象
    | Map(87)                    // Map 对象
    | Set(88)                    // Set 对象
    | WeakMap(89)                // WeakMap 对象
    | WeakSet(90)                // WeakSet 对象
    | WebAssemblyModule(91)
    | WebAssemblyInstance(92)
    | WebAssemblyGCObject(93)
    | StringObject(94)           // 字符串包装对象
    | DerivedStringObject(95)
    | InternalFieldTuple(96)

    // ---- 特殊标记 ----
    | MaxJS(255)
    | Event(239)
    | DOMWrapper(238)
    | EmbedderArrayLike(237)
    | JSAsJSONType(241)

    public init(value: UInt8) {
        // 从数值创建
        match (value) {
            case 0 => this = Cell
            case 1 => this = Structure
            case 2 => this = String
            case 3 => this = HeapBigInt
            case 4 => this = HeapDouble
            case 5 => this = HeapInt32
            case 6 => this = Symbol
            case 33 => this = Object
            case 34 => this = FinalObject
            case 36 => this = JSFunction
            case 37 => this = InternalFunction
            case 41 => this = ErrorInstance
            case 46 => this = Array
            case 47 => this = DerivedArray
            case 48 => this = ArrayBuffer
            case 62 => this = GlobalObject
            case 72 => this = RegExpObject
            case 73 => this = JSDate
            case 74 => this = ProxyObject
            case 75 => this = Generator
            case 76 => this = AsyncGenerator
            case 86 => this = JSPromise
            case 87 => this = Map
            case 88 => this = Set
            case 89 => this = WeakMap
            case 90 => this = WeakSet
            case _ => this = Cell
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
public enum JSRuntimeType <: UInt16 {
    | Nothing(0x0)
    | Function(0x1)
    | Undefined(0x2)
    | Null(0x4)
    | Boolean(0x8)
    | AnyInt(0x10)
    | Number(0x20)
    | String(0x40)
    | Object(0x80)
    | Symbol(0x100)
    | BigInt(0x200)
}

// ========== JSErrorCode 枚举 ==========
// 严格翻译自 JSErrorCode.zig
// 表示 JavaScript 错误类型
public enum JSErrorCode <: UInt8 {
    | Error(0)
    | EvalError(1)
    | RangeError(2)
    | ReferenceError(3)
    | SyntaxError(4)
    | TypeError(5)
    | URIError(6)
    | AggregateError(7)
    | OutOfMemoryError(8)
    | BundlerError(252)
    | StackOverflow(253)
    | UserErrorCode(254)
}

// ========== DOMExceptionCode 枚举 ==========
// 严格翻译自 JSErrorCode.zig DOMExceptionCode
public enum DOMExceptionCode <: UInt8 {
    | IndexSizeError
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
    | InvalidAccessError
    | TypeMismatchError
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
    | DOMRangeError
    | DOMTypeError
    | JSSyntaxError
    | StackOverflowError
    | OutOfMemoryError
    | ExistingExceptionError
    | InvalidThisError
    | InvalidURLError
    | CryptoOperationFailedError
}

// ========== JSPromiseRejectionOperation 枚举 ==========
// 严格翻译自 JSPromiseRejectionOperation.zig
public enum JSPromiseRejectionOperation <: UInt32 {
    | Reject(0)
    | Handle(1)
}
