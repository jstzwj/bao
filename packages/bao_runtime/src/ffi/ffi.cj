// FFI — 外部函数接口
// 对应 Bun: src/runtime/ffi/ffi.zig
// 提供动态库加载 (dlopen)、C 函数绑定、指针操作、内存读写等 FFI 能力
package bao_runtime.ffi

import bao_core.*
import bao_collections.*

// ============================================================================
// ABI 类型枚举
// 对应 Bun: FFI.ABIType
// ============================================================================

/// FFI 值类型 (与 C ABI 对应)
/// 对应 Zig: pub const ABIType = enum(i32) { ... }
public enum AbiType {
    | Char       // 0  - char
    | Int8       // 1  - int8_t
    | UInt8      // 2  - uint8_t
    | Int16      // 3  - int16_t
    | UInt16     // 4  - uint16_t
    | Int32      // 5  - int32_t
    | UInt32     // 6  - uint32_t
    | Int64      // 7  - int64_t
    | UInt64     // 8  - uint64_t
    | Double     // 9  - double
    | Float      // 10 - float
    | Bool       // 11 - bool
    | Ptr        // 12 - void*
    | Void       // 13 - void
    | CString    // 14 - char* (null-terminated)
    | I64Fast    // 15 - i64 (fast path)
    | U64Fast    // 16 - u64 (fast path)
    | Function   // 17 - function pointer
    | NapiEnv    // 18 - napi_env
    | NapiValue  // 19 - napi_value
    | Buffer     // 20 - buffer (typed array)

    /// 是否为浮点类型
    public func isFloatingPoint(): Bool {
        match (this) {
            case Double | Float => true
            case _ => false
        }
    }

    /// 是否需要在 C 中进行类型转换
    public func needsACastInC(): Bool {
        match (this) {
            case Char | Int8 | UInt8 | Int16 | UInt16 | Int32 | UInt32 => false
            case _ => true
        }
    }

    /// 获取 C 类型名
    public func typenameLabel(): String {
        match (this) {
            case Char => "char"
            case Int8 => "int8_t"
            case UInt8 => "uint8_t"
            case Int16 => "int16_t"
            case UInt16 => "uint16_t"
            case Int32 => "int32_t"
            case UInt32 => "uint32_t"
            case Int64 | I64Fast => "int64_t"
            case UInt64 | U64Fast => "uint64_t"
            case Double => "double"
            case Float => "float"
            case Bool => "bool"
            case Ptr | CString | Function | Buffer => "void*"
            case Void => "void"
            case NapiEnv => "napi_env"
            case NapiValue => "napi_value"
        }
    }

    /// 从字符串解析 ABI 类型
    public static func fromString(name: String): ?AbiType {
        match (name) {
            case "bool" => AbiType.Bool
            case "c_int" => AbiType.Int32
            case "c_uint" => AbiType.UInt32
            case "char" => AbiType.Char
            case "double" => AbiType.Double
            case "f32" => AbiType.Float
            case "f64" => AbiType.Double
            case "float" => AbiType.Float
            case "i16" => AbiType.Int16
            case "i32" => AbiType.Int32
            case "i64" => AbiType.Int64
            case "i8" => AbiType.Int8
            case "int" => AbiType.Int32
            case "int8_t" => AbiType.Int8
            case "int16_t" => AbiType.Int16
            case "int32_t" => AbiType.Int32
            case "int64_t" => AbiType.Int64
            case "isize" => AbiType.Int64
            case "u16" => AbiType.UInt16
            case "u32" => AbiType.UInt32
            case "u64" => AbiType.UInt64
            case "u8" => AbiType.UInt8
            case "uint8_t" => AbiType.UInt8
            case "uint16_t" => AbiType.UInt16
            case "uint32_t" => AbiType.UInt32
            case "uint64_t" => AbiType.UInt64
            case "usize" => AbiType.UInt64
            case "size_t" => AbiType.UInt64
            case "buffer" => AbiType.Buffer
            case "void*" => AbiType.Ptr
            case "ptr" => AbiType.Ptr
            case "pointer" => AbiType.Ptr
            case "void" => AbiType.Void
            case "cstring" => AbiType.CString
            case "i64_fast" => AbiType.I64Fast
            case "u64_fast" => AbiType.U64Fast
            case "function" | "callback" | "fn" => AbiType.Function
            case "napi_env" => AbiType.NapiEnv
            case "napi_value" => AbiType.NapiValue
            case _ => None
        }
    }

    /// 从数值解析 ABI 类型
    public static func fromInt(value: Int32): ?AbiType {
        match (value) {
            case 0 => AbiType.Char
            case 1 => AbiType.Int8
            case 2 => AbiType.UInt8
            case 3 => AbiType.Int16
            case 4 => AbiType.UInt16
            case 5 => AbiType.Int32
            case 6 => AbiType.UInt32
            case 7 => AbiType.Int64
            case 8 => AbiType.UInt64
            case 9 => AbiType.Double
            case 10 => AbiType.Float
            case 11 => AbiType.Bool
            case 12 => AbiType.Ptr
            case 13 => AbiType.Void
            case 14 => AbiType.CString
            case 15 => AbiType.I64Fast
            case 16 => AbiType.U64Fast
            case 17 => AbiType.Function
            case 18 => AbiType.NapiEnv
            case 19 => AbiType.NapiValue
            case 20 => AbiType.Buffer
            case _ => None
        }
    }
}

// ============================================================================
// FFI 函数编译步骤
// 对应 Bun: FFI.Function.Step
// ============================================================================

/// FFI 函数的编译/加载状态
public enum FfiStep {
    /// 待编译
    | Pending
    /// 已编译
    | Compiled(FfiCompiledFunction)
    /// 失败
    | Failed(String)

    public func isCompiled(): Bool {
        match (this) {
            case Compiled(_) => true
            case _ => false
        }
    }
}

/// 已编译的 FFI 函数
public class FfiCompiledFunction {
    /// 函数指针地址
    public var ptr: Int64
    /// JS 函数包装
    public var jsFunction: JsValue
    /// JS 上下文
    public var jsContext: ?JsObject
    /// FFI 回调包装器
    public var ffiCallbackWrapper: ?Int64

    public init(ptr: Int64) {
        this.ptr = ptr
        this.jsFunction = JsValue.UNDEFINED
        this.jsContext = None
        this.ffiCallbackWrapper = None
    }
}

// ============================================================================
// FFI 函数描述
// 对应 Bun: FFI.Function
// ============================================================================

/// FFI 函数描述与绑定
/// 对应 Zig: pub const Function = struct { ... }
public class FfiFunction {
    /// 从动态库加载的符号地址
    public var symbolFromDynlib: Int64
    /// 函数基名
    public var baseName: ?String
    /// 返回类型
    public var returnType: AbiType
    /// 参数类型列表
    public var argTypes: ArrayList<AbiType>
    /// 编译步骤
    public var step: FfiStep
    /// 是否线程安全
    public var threadsafe: Bool

    public init() {
        symbolFromDynlib = 0
        baseName = None
        returnType = AbiType.Void
        argTypes = ArrayList<AbiType>()
        step = FfiStep.Pending
        threadsafe = false
    }

    /// 是否需要 NAPI 环境
    /// 对应 Zig: needsNapiEnv
    public func needsNapiEnv(): Bool {
        for (arg in argTypes) {
            match (arg) {
                case NapiEnv | NapiValue => return true
                case _ => ()
            }
        }
        return false
    }

    /// 是否需要 HandleScope
    /// 对应 Zig: needsHandleScope
    public func needsHandleScope(): Bool {
        for (arg in argTypes) {
            match (arg) {
                case NapiEnv | NapiValue => return true
                case _ => ()
            }
        }
        match (returnType) {
            case NapiValue => return true
            case _ => ()
        }
        return false
    }

    /// 释放资源
    /// 对应 Zig: deinit
    public func deinit(): Unit {
        baseName = None
        argTypes.clear()
        step = FfiStep.Pending
    }
}

// ============================================================================
// FFI 模块 — 动态库加载与符号绑定
// 对应 Bun: FFI struct
// ============================================================================

/// FFI 模块
/// 对应 Zig: pub const FFI = struct { ... }
/// 管理动态库 (dlopen/dlsym)、C 函数编译、回调创建等
public class Ffi {
    /// 动态库句柄
    public var dylib: ?DynamicLibrary
    /// 已注册的函数映射
    public var functions: HashMap<String, FfiFunction>
    /// 是否已关闭
    public var closed: Bool

    public init() {
        dylib = None
        functions = HashMap<String, FfiFunction>()
        closed = false
    }

    /// GC finalize
    /// 对应 Zig: finalize
    public func finalize(): Unit {
        // 无操作 — close 负责清理
    }

    // ========================================================================
    // dlopen — 打开动态库
    // 对应 Zig: FFI.open
    // ========================================================================

    /// 打开动态库并解析符号
    /// 对应 Zig: pub fn open(global, name_str, object_value)
    public static func open(globalObject: JsObject, name: String, objectValue: JsValue): JsValue {
        if (name.isEmpty()) {
            return JsValue("Invalid library name")
        }

        if (objectValue.valueType != JsValueType.Object) {
            return JsValue("Expected an options object with symbol names")
        }

        // 生成符号映射
        let symbols = generateSymbols(globalObject, objectValue)
        match (symbols) {
            case Some(symMap) => {
                if (symMap.size == 0) {
                    return JsValue("Expected at least one symbol")
                }

                // 加载动态库
                let lib = DynamicLibrary.open(name)
                match (lib) {
                    case Some(dylib) => {
                        let ffi = Ffi()
                        ffi.dylib = Some(dylib)

                        // 解析并编译每个符号
                        var resultObj = JsObject()
                        for ((symName, func) in symMap) {
                            // 从动态库查找符号
                            let addr = dylib.lookup(symName)
                            if (addr == 0) {
                                dylib.close()
                                return JsValue("Symbol \"${symName}\" not found in \"${name}\"")
                            }
                            func.symbolFromDynlib = addr

                            // 编译 FFI 函数
                            func.compile()
                            match (func.step) {
                                case FfiStep.Compiled(compiled) => {
                                    resultObj.set(symName, JsValue("FFI function: ${symName}"))
                                }
                                case FfiStep.Failed(msg) => {
                                    dylib.close()
                                    return JsValue(msg)
                                }
                                case FfiStep.Pending => {
                                    dylib.close()
                                    return JsValue("Failed to compile (nothing happened!)")
                                }
                            }
                        }

                        ffi.functions = symMap
                        return JsValue(resultObj)
                    }
                    case None => {
                        return JsValue("Failed to open library \"${name}\"")
                    }
                }
            }
            case None => {
                return JsValue("Invalid symbols object")
            }
        }
    }

    // ========================================================================
    // linkSymbols — 链接已知符号
    // 对应 Zig: FFI.linkSymbols
    // ========================================================================

    /// 链接已知符号 (无需动态库)
    /// 对应 Zig: pub fn linkSymbols(global, object_value)
    public static func linkSymbols(globalObject: JsObject, objectValue: JsValue): JsValue {
        if (objectValue.valueType != JsValueType.Object) {
            return JsValue("Expected an options object with symbol names")
        }

        let symbols = generateSymbols(globalObject, objectValue)
        match (symbols) {
            case Some(symMap) => {
                if (symMap.size == 0) {
                    return JsValue("Expected at least one symbol")
                }

                // 验证每个符号都有 ptr 字段
                for ((symName, func) in symMap) {
                    if (func.symbolFromDynlib == 0) {
                        return JsValue("Symbol \"${symName}\" is missing a \"ptr\" field")
                    }

                    func.compile()
                    match (func.step) {
                        case FfiStep.Failed(msg) => {
                            return JsValue(msg)
                        }
                        case FfiStep.Pending => {
                            return JsValue("Failed to compile (nothing happened!)")
                        }
                        case FfiStep.Compiled(_) => ()
                    }
                }

                let ffi = Ffi()
                ffi.functions = symMap
                return JsValue.UNDEFINED  // 实际返回 JS 包装器
            }
            case None => {
                return JsValue("Invalid symbols object")
            }
        }
    }

    // ========================================================================
    // callback — 创建 FFI 回调
    // 对应 Zig: FFI.callback
    // ========================================================================

    /// 创建 FFI 回调函数
    /// 对应 Zig: pub fn callback(global, interface, js_callback)
    public static func createCallback(globalObject: JsObject, interface: JsValue, jsCallback: JsValue): JsValue {
        if (interface.valueType != JsValueType.Object) {
            return JsValue("Expected object")
        }

        if (jsCallback.valueType != JsValueType.Function) {
            return JsValue("Expected callback function")
        }

        // 生成函数描述
        let func = generateSymbolForFunction(globalObject, interface)
        match (func) {
            case Some(f) => {
                // 编译回调
                f.compileCallback(jsCallback)
                match (f.step) {
                    case FfiStep.Compiled(compiled) => {
                        // 返回 { ptr, ctx } 对象
                        let result = JsObject()
                        result.set("ptr", JsValue(Float64(Int64(compiled.ptr).toFloat64())))
                        return JsValue(result)
                    }
                    case FfiStep.Failed(msg) => {
                        return JsValue(msg)
                    }
                    case FfiStep.Pending => {
                        return JsValue("Failed to compile callback")
                    }
                }
            }
            case None => {
                return JsValue("Failed to generate symbol")
            }
        }
    }

    // ========================================================================
    // close — 关闭 FFI 实例
    // 对应 Zig: FFI.close
    // ========================================================================

    /// 关闭 FFI 实例, 释放动态库和函数
    /// 对应 Zig: pub fn close
    public func close(): JsValue {
        if (closed) {
            return JsValue.UNDEFINED
        }
        closed = true

        // 关闭动态库
        match (dylib) {
            case Some(lib) => {
                lib.close()
                dylib = None
            }
            case None => ()
        }

        // 释放函数
        for ((_, func) in functions) {
            func.deinit()
        }
        functions.clear()

        return JsValue.UNDEFINED
    }

    // ========================================================================
    // print — 打印 FFI 绑定源代码
    // 对应 Zig: FFI.print
    // ========================================================================

    /// 打印 FFI 函数的 C 源代码
    /// 对应 Zig: pub fn print(global, object, is_callback_val)
    public static func print(globalObject: JsObject, obj: JsValue, isCallback: Bool): JsValue {
        if (isCallback) {
            return printCallback(globalObject, obj)
        }

        if (obj.valueType != JsValueType.Object) {
            return JsValue("Expected an options object with symbol names")
        }

        // 生成符号, 打印每个函数的 C 包装代码
        let symbols = generateSymbols(globalObject, obj)
        match (symbols) {
            case Some(symMap) => {
                var sources = ArrayList<String>()
                for ((name, func) in symMap) {
                    let source = printFunctionSource(name, func)
                    sources.append(source)
                }
                return JsValue(sources.join("\n"))
            }
            case None => {
                return JsValue("Invalid symbols object")
            }
        }
    }

    /// 打印回调函数源代码
    private static func printCallback(globalObject: JsObject, obj: JsValue): JsValue {
        return JsValue("// FFI callback source code")
    }

    // ========================================================================
    // 辅助方法
    // ========================================================================

    /// 从 JS 对象生成符号映射
    /// 对应 Zig: generateSymbols
    private static func generateSymbols(globalObject: JsObject, value: JsValue): ?HashMap<String, FfiFunction> {
        if (value.valueType != JsValueType.Object) {
            return None
        }

        var symbols = HashMap<String, FfiFunction>()

        match (value.objectData) {
            case Some(obj) => {
                let keys = obj.keys()
                for (key in keys) {
                    let propValue = obj.get(key)
                    if (propValue.valueType != JsValueType.Object) {
                        continue
                    }

                    let func = generateSymbolForFunction(globalObject, propValue)
                    match (func) {
                        case Some(f) => {
                            f.baseName = Some(key)
                            symbols.put(key, f)
                        }
                        case None => return None
                    }
                }
            }
            case None => return None
        }

        return symbols
    }

    /// 从 JS 对象生成单个函数描述
    /// 对应 Zig: generateSymbolForFunction
    private static func generateSymbolForFunction(globalObject: JsObject, value: JsValue): ?FfiFunction {
        let func = FfiFunction()

        match (value.objectData) {
            case Some(obj) => {
                // 解析参数类型
                let args = obj.get("args")
                if (args.valueType == JsValueType.Array) {
                    // 遍历参数数组
                    match (args.arrayData) {
                        case Some(arr) => {
                            for (arg in arr) {
                                let abiType = resolveAbiType(arg)
                                match (abiType) {
                                    case Some(t) => func.argTypes.append(t)
                                    case None => return None
                                }
                            }
                        }
                        case None => ()
                    }
                }

                // 解析返回类型
                let returns = obj.get("returns")
                if (returns.valueType != JsValueType.Undefined) {
                    let retType = resolveAbiType(returns)
                    match (retType) {
                        case Some(t) => func.returnType = t
                        case None => return None
                    }
                }

                // 读取 threadsafe 标志
                let threadsafe = obj.get("threadsafe")
                if (threadsafe.valueType == JsValueType.Boolean) {
                    func.threadsafe = threadsafe.toBoolean()
                }

                // 读取 ptr (已知函数地址)
                let ptr = obj.get("ptr")
                if (ptr.valueType == JsValueType.Number) {
                    func.symbolFromDynlib = Int64(ptr.toNumber())
                }
            }
            case None => return None
        }

        return func
    }

    /// 解析单个 ABI 类型 (从 JS 值)
    private static func resolveAbiType(value: JsValue): ?AbiType {
        if (value.valueType == JsValueType.Number) {
            return AbiType.fromInt(Int32(value.toNumber()))
        }
        if (value.valueType == JsValueType.String) {
            return AbiType.fromString(value.toString())
        }
        return None
    }

    /// 打印函数的 C 包装源代码
    private static func printFunctionSource(name: String, func: FfiFunction): String {
        var sb = StringBuilder()
        sb.append("// FFI wrapper for ${name}\n")

        // 返回类型
        sb.append(func.returnType.typenameLabel())
        sb.append(" ${name}(")

        // 参数列表
        var first = true
        var i: Int64 = 0
        for (arg in func.argTypes) {
            if (!first) {
                sb.append(", ")
            }
            first = false
            sb.append("${arg.typenameLabel()} arg${i}")
            i += 1
        }
        sb.append(");\n")

        return sb.toString()
    }
}

// ============================================================================
// 动态库
// 对应 Bun: std.DynLib
// ============================================================================

/// 动态库 (dlopen/dlsym/dlclose)
/// 对应 Zig: std.DynLib
public class DynamicLibrary {
    /// 库句柄 (dlopen 返回的 void*)
    private var handle: Int64
    /// 库文件名
    private var name: String

    private init(handle: Int64, name: String) {
        this.handle = handle
        this.name = name
    }

    /// 打开动态库
    /// 对应 Zig: std.DynLib.open
    /// 对应 C: dlopen(path, RTLD_LAZY)
    public static func open(path: String): ?DynamicLibrary {
        // FFI 声明:
        // @C foreign func dlopen(filename: CPointer<UInt8>, flags: Int32): CPointer<Unit>
        let handle = dlopen(path)
        if (handle == 0) {
            return None
        }
        return Some(DynamicLibrary(handle, path))
    }

    /// 查找符号
    /// 对应 Zig: std.DynLib.lookup
    /// 对应 C: dlsym(handle, name)
    public func lookup(symbol: String): Int64 {
        // FFI 声明:
        // @C foreign func dlsym(handle: CPointer<Unit>, symbol: CPointer<UInt8>): CPointer<Unit>
        return dlsym(handle, symbol)
    }

    /// 关闭动态库
    /// 对应 Zig: std.DynLib.close
    /// 对应 C: dlclose(handle)
    public func close(): Unit {
        if (handle != 0) {
            dlclose(handle)
            handle = 0
        }
    }

    // ========================================================================
    // FFI 声明 — 通过 foreign 关键字对接 C 动态链接接口
    // ========================================================================

    // dlopen — 打开动态库
    // @C foreign func dlopen(filename: CPointer<UInt8>, flags: Int32): Int64
    private static func dlopen(path: String): Int64 {
        // 占位: 实际通过仓颉 FFI 调用 C dlopen
        return 0
    }

    // dlsym — 查找符号
    // @C foreign func dlsym(handle: Int64, symbol: CPointer<UInt8>): Int64
    private static func dlsym(handle: Int64, symbol: String): Int64 {
        // 占位: 实际通过仓颉 FFI 调用 C dlsym
        return 0
    }

    // dlclose — 关闭动态库
    // @C foreign func dlclose(handle: Int64): Int32
    private static func dlclose(handle: Int64): Int32 {
        // 占位: 实际通过仓颉 FFI 调用 C dlclose
        return 0
    }

    // dlerror — 获取错误信息
    // @C foreign func dlerror(): CPointer<UInt8>
    private static func dlerror(): String {
        // 占位: 实际通过仓颉 FFI 调用 C dlerror
        return ""
    }
}
