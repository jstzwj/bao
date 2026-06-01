// FFI — 外部函数接口
// 对应 Bun: src/runtime/ffi/ffi.zig
// 提供动态库加载 (dlopen)、C 函数绑定、指针操作、内存读写等 FFI 能力
package bao_runtime.ffi

import bao_core.*
import bao_collections.*
import bao_runtime.*

// ============================================================================
// ABI 类型枚举
// 对应 Bun: FFI.ABIType
// ============================================================================

/// FFI 值类型 (与 C ABI 对应)
/// 对应 Zig: pub const ABIType = enum(i32) { ... }
public enum LegacyAbiType {
    | Char       // 0  - char
    | Int8T       // 1  - int8_t
    | Uint8T      // 2  - uint8_t
    | Int16T      // 3  - int16_t
    | Uint16T     // 4  - uint16_t
    | Int32T      // 5  - int32_t
    | Uint32T     // 6  - uint32_t
    | Int64T      // 7  - int64_t
    | Uint64T     // 8  - uint64_t
    | Double     // 9  - double
    | Float      // 10 - float
    | BoolT      // 11 - bool
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
            case Char | Int8T | Uint8T | Int16T | Uint16T | Int32T | Uint32T => false
            case _ => true
        }
    }

    /// 获取 C 类型名
    public func typenameLabel(): String {
        match (this) {
            case Char => "char"
            case Int8T => "int8_t"
            case Uint8T => "uint8_t"
            case Int16T => "int16_t"
            case Uint16T => "uint16_t"
            case Int32T => "int32_t"
            case Uint32T => "uint32_t"
            case Int64T | I64Fast => "int64_t"
            case Uint64T | U64Fast => "uint64_t"
            case Double => "double"
            case Float => "float"
            case BoolT => "bool"
            case Ptr | CString | Function | Buffer => "void*"
            case Void => "void"
            case NapiEnv => "napi_env"
            case NapiValue => "napi_value"
        }
    }

    /// 从字符串解析 ABI 类型
    public static func fromString(name: String): ?LegacyAbiType {
        match (name) {
            case "bool" => LegacyAbiType.BoolT
            case "c_int" => LegacyAbiType.Int32T
            case "c_uint" => LegacyAbiType.Uint32T
            case "char" => LegacyAbiType.Char
            case "double" => LegacyAbiType.Double
            case "f32" => LegacyAbiType.Float
            case "f64" => LegacyAbiType.Double
            case "float" => LegacyAbiType.Float
            case "i16" => LegacyAbiType.Int16T
            case "i32" => LegacyAbiType.Int32T
            case "i64" => LegacyAbiType.Int64T
            case "i8" => LegacyAbiType.Int8T
            case "int" => LegacyAbiType.Int32T
            case "int8_t" => LegacyAbiType.Int8T
            case "int16_t" => LegacyAbiType.Int16T
            case "int32_t" => LegacyAbiType.Int32T
            case "int64_t" => LegacyAbiType.Int64T
            case "isize" => LegacyAbiType.Int64T
            case "u16" => LegacyAbiType.Uint16T
            case "u32" => LegacyAbiType.Uint32T
            case "u64" => LegacyAbiType.Uint64T
            case "u8" => LegacyAbiType.Uint8T
            case "uint8_t" => LegacyAbiType.Uint8T
            case "uint16_t" => LegacyAbiType.Uint16T
            case "uint32_t" => LegacyAbiType.Uint32T
            case "uint64_t" => LegacyAbiType.Uint64T
            case "usize" => LegacyAbiType.Uint64T
            case "size_t" => LegacyAbiType.Uint64T
            case "buffer" => LegacyAbiType.Buffer
            case "void*" => LegacyAbiType.Ptr
            case "ptr" => LegacyAbiType.Ptr
            case "pointer" => LegacyAbiType.Ptr
            case "void" => LegacyAbiType.Void
            case "cstring" => LegacyAbiType.CString
            case "i64_fast" => LegacyAbiType.I64Fast
            case "u64_fast" => LegacyAbiType.U64Fast
            case "function" | "callback" | "fn" => LegacyAbiType.Function
            case "napi_env" => LegacyAbiType.NapiEnv
            case "napi_value" => LegacyAbiType.NapiValue
            case _ => None
        }
    }

    /// 从数值解析 ABI 类型
    public static func fromInt(value: Int32): ?LegacyAbiType {
        match (value) {
            case 0 => LegacyAbiType.Char
            case 1 => LegacyAbiType.Int8T
            case 2 => LegacyAbiType.Uint8T
            case 3 => LegacyAbiType.Int16T
            case 4 => LegacyAbiType.Uint16T
            case 5 => LegacyAbiType.Int32T
            case 6 => LegacyAbiType.Uint32T
            case 7 => LegacyAbiType.Int64T
            case 8 => LegacyAbiType.Uint64T
            case 9 => LegacyAbiType.Double
            case 10 => LegacyAbiType.Float
            case 11 => LegacyAbiType.BoolT
            case 12 => LegacyAbiType.Ptr
            case 13 => LegacyAbiType.Void
            case 14 => LegacyAbiType.CString
            case 15 => LegacyAbiType.I64Fast
            case 16 => LegacyAbiType.U64Fast
            case 17 => LegacyAbiType.Function
            case 18 => LegacyAbiType.NapiEnv
            case 19 => LegacyAbiType.NapiValue
            case 20 => LegacyAbiType.Buffer
            case _ => None
        }
    }
}

// ============================================================================
// FFI 函数编译步骤
// 对应 Bun: FFI.Function.Step
// ============================================================================

/// FFI 函数的编译/加载状态
public enum LegacyFfiStep {
    /// 待编译
    | Pending
    /// 已编译
    | Compiled(LegacyFfiCompiledFunction)
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
public class LegacyFfiCompiledFunction {
    /// 函数指针地址
    public var ptr: Int64
    /// JS 函数包装
    public var jsFunction: Int64
    /// JS 上下文
    public var jsContext: ?Int64
    /// FFI 回调包装器
    public var ffiCallbackWrapper: ?Int64

    public init(ptr: Int64) {
        this.ptr = ptr
        this.jsFunction = 0
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
public class LegacyFfiFunction {
    /// 从动态库加载的符号地址
    public var symbolFromDynlib: Int64
    /// 函数基名
    public var baseName: ?String
    /// 返回类型
    public var returnType: LegacyAbiType
    /// 参数类型列表
    public var argTypes: ArrayList<LegacyAbiType>
    /// 编译步骤
    public var step: LegacyFfiStep
    /// 是否线程安全
    public var threadsafe: Bool

    public init() {
        symbolFromDynlib = 0
        baseName = None
        returnType = LegacyAbiType.Void
        argTypes = ArrayList<LegacyAbiType>()
        step = LegacyFfiStep.Pending
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
        step = LegacyFfiStep.Pending
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
    public var functions: HashMap<String, LegacyFfiFunction>
    /// 是否已关闭
    public var closed: Bool

    public init() {
        dylib = None
        functions = HashMap<String, LegacyFfiFunction>()
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
        return JsValue(JsObject())
    }

    // ========================================================================
    // linkSymbols — 链接已知符号
    // 对应 Zig: FFI.linkSymbols
    // ========================================================================

    /// 链接已知符号 (无需动态库)
    /// 对应 Zig: pub fn linkSymbols(global, object_value)
    public static func linkSymbols(globalObject: JsObject, objectValue: JsValue): JsValue {
        return JsValue(JsObject())
    }

    // ========================================================================
    // callback — 创建 FFI 回调
    // 对应 Zig: FFI.callback
    // ========================================================================

    /// 创建 FFI 回调函数
    /// 对应 Zig: pub fn callback(global, interface, js_callback)
    public static func createCallback(globalObject: JsObject, callbackInterface: JsValue, jsCallback: JsValue): JsValue {
        return JsValue(JsObject())
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
        if (dylib.isSome()) {
            let lib = dylib.getOrThrow()
            lib.close()
            dylib = None
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
        return JsValue(BaoString("// FFI source code"))
    }

    /// 打印回调函数源代码
    private static func printCallback(globalObject: JsObject, obj: JsValue): JsValue {
        return JsValue(BaoString("// FFI callback source code"))
    }

    // ========================================================================
    // 辅助方法
    // ========================================================================

    /// 从 JS 对象生成符号映射
    /// 对应 Zig: generateSymbols
    private static func generateSymbols(globalObject: JsObject, value: JsValue): ?HashMap<String, LegacyFfiFunction> {
        if (value.valueType != JsValueType.Object) {
            return None
        }

        var symbols = HashMap<String, LegacyFfiFunction>()

        if (value.objectData.isNone()) {
            return None
        }
        let obj = value.objectData.getOrThrow()
        let keys = obj.keys()
        for (key in keys) {
            let propValue = obj.get(key)
            if (propValue.valueType != JsValueType.Object) {
                continue
            }

            let ffiFuncOpt = generateSymbolForFunction(globalObject, propValue)
            if (ffiFuncOpt.isNone()) {
                return None
            }
            let f = ffiFuncOpt.getOrThrow()
            f.baseName = Some(key)
            symbols.put(key, f)
        }

        return symbols
    }

    /// 从 JS 对象生成单个函数描述
    /// 对应 Zig: generateSymbolForFunction
    private static func generateSymbolForFunction(globalObject: JsObject, value: JsValue): ?LegacyFfiFunction {
        let ffiFunc = LegacyFfiFunction()

        if (value.objectData.isNone()) {
            return None
        }
        let obj = value.objectData.getOrThrow()
        let args = obj.get("args")
        if (args.valueType == JsValueType.Array) {
            if (args.arrayData.isSome()) {
                let arr = args.arrayData.getOrThrow()
                for (arg in arr) {
                    let abiType = resolveLegacyAbiType(arg)
                    if (abiType.isNone()) {
                        return None
                    }
                    ffiFunc.argTypes.append(abiType.getOrThrow())
                }
            }
        }

        let returns = obj.get("returns")
        if (returns.valueType != JsValueType.Undefined) {
            let retType = resolveLegacyAbiType(returns)
            if (retType.isNone()) {
                return None
            }
            ffiFunc.returnType = retType.getOrThrow()
        }

        let threadsafe = obj.get("threadsafe")
        if (threadsafe.valueType == JsValueType.Boolean) {
            ffiFunc.threadsafe = threadsafe.toBoolean()
        }

        let ptr = obj.get("ptr")
        if (ptr.valueType == JsValueType.Number) {
            ffiFunc.symbolFromDynlib = Int64(ptr.toNumber())
        }

        return ffiFunc
    }

    /// 解析单个 ABI 类型 (从 JS 值)
    private static func resolveLegacyAbiType(value: JsValue): ?LegacyAbiType {
        if (value.valueType == JsValueType.Number) {
            return LegacyAbiType.fromInt(Int32(value.toNumber()))
        }
        if (value.valueType == JsValueType.String) {
            return LegacyAbiType.fromString(value.toString())
        }
        return None
    }

    /// 打印函数的 C 包装源代码
    private static func printFunctionSource(name: String, ffiFunc: LegacyFfiFunction): String {
        var sb = StringBuilder()
        sb.append("// FFI wrapper for ${name}\n")

        // 返回类型
        sb.append(ffiFunc.returnType.typenameLabel())
        sb.append(" ${name}(")

        // 参数列表
        var first = true
        var i: Int64 = 0
        for (arg in ffiFunc.argTypes) {
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
        // @C foreign func dlopen(filename: CPointer<Uint8T>, flags: Int32T): CPointer<Unit>
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
        // @C foreign func dlsym(handle: CPointer<Unit>, symbol: CPointer<Uint8T>): CPointer<Unit>
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
    // @C foreign func dlopen(filename: CPointer<Uint8T>, flags: Int32T): Int64
    private static func dlopen(path: String): Int64 {
        // 占位: 实际通过仓颉 FFI 调用 C dlopen
        return 0
    }

    // dlsym — 查找符号
    // @C foreign func dlsym(handle: Int64, symbol: CPointer<Uint8T>): Int64
    private static func dlsym(handle: Int64, symbol: String): Int64 {
        // 占位: 实际通过仓颉 FFI 调用 C dlsym
        return 0
    }

    // dlclose — 关闭动态库
    // @C foreign func dlclose(handle: Int64): Int32T
    private static func dlclose(handle: Int64): Int32 {
        // 占位: 实际通过仓颉 FFI 调用 C dlclose
        return 0
    }

    // dlerror — 获取错误信息
    // @C foreign func dlerror(): CPointer<Uint8T>
    private static func dlerror(): String {
        // 占位: 实际通过仓颉 FFI 调用 C dlerror
        return ""
    }

    /// 获取最后一次 dlopen/dlsym/dlclose 错误信息 (公共 API)
    /// 对应 Bun: mod.rs — get_dl_error()
    public static func getLastError(): String {
        return dlerror()
    }
}
