// FFI 主体实现 — FFI 结构体、CompileC、Function 及宿主函数
// 对应 Bun: src/runtime/ffi/ffi_body.rs
// 包含 FFI 类定义、CompileC 编译器封装、Function 编译/源码生成、
// dlopen/dlsym 动态库加载、回调函数创建等核心逻辑
package bao_runtime.ffi

import bao_core.*
import bao_collections.*
import bao_runtime.*

// ============================================================================
// FFI 步骤 (编译/加载状态)
// 对应 Bun: FFI.Step (ffi_body.rs:2583)
// ============================================================================

/// FFI 函数的编译/加载状态
/// 对应 Rust: pub enum Step { Pending, Compiled(Compiled), Failed }
public enum FfiStep {
    | Pending
    | Compiled(FfiCompiled)
    | Failed(String, Bool)

    /// 获取已编译的函数指针 (如果已编译)
    /// 对应 Rust: Step::compiled_ptr
    public func compiledPtr(): Int64 {
        // Workaround for FirstLetter pattern matching issue
        match (this) {
            case FfiStep.Compiled(compiledVal) =>
                // compiledVal is bound here
                let compiled = compiledVal
                return compiled.ptr
            case _ => return 0
        }
    }

    public func isCompiled(): Bool {
        match (this) {
            case FfiStep.Pending => false
            case FfiStep.Failed(_, _) => false
            case FfiStep.Compiled(_) => true
        }
    }
}

// ============================================================================
// 已编译的 FFI 函数
// 对应 Bun: FFI.Compiled (ffi_body.rs:2589)
// ============================================================================

/// 已编译的 FFI 函数结果
/// 对应 Rust: pub struct Compiled { ptr, js_function, js_context, ffi_callback_function_wrapper }
public class FfiCompiled {
    /// 编译后的函数指针 (void*)
    public var ptr: Int64
    /// 对应的 JS 函数
    public var jsFunction: JsValue
    /// JS 上下文指针 (JSGlobalObject*)
    public var jsContext: ?Int64
    /// FFI 回调函数包装器指针
    public var ffiCallbackFunctionWrapper: ?Int64

    public init() {
        ptr = 0
        jsFunction = JsValue.UNDEFINED
        jsContext = None
        ffiCallbackFunctionWrapper = None
    }

    public init(ptr: Int64) {
        this.ptr = ptr
        this.jsFunction = JsValue.UNDEFINED
        this.jsContext = None
        this.ffiCallbackFunctionWrapper = None
    }
}

// ============================================================================
// FFI 函数描述
// 对应 Bun: FFI.Function (ffi_body.rs:1923)
// ============================================================================

/// FFI 函数描述与绑定
/// 对应 Rust: pub struct Function { symbol_from_dynamic_library, base_name, state,
///   return_type, arg_types, step, threadsafe }
public class FfiFunction {
    /// 从动态库加载的符号地址 (void*)
    public var symbolFromDynamicLibrary: ?Int64
    /// 函数基名
    public var baseName: ?String
    /// TCC 状态指针
    public var state: ?Int64
    /// 返回类型
    public var returnType: AbiType
    /// 参数类型列表
    public var argTypes: ArrayList<AbiType>
    /// 编译步骤
    public var step: FfiStep
    /// 是否线程安全
    public var threadsafe: Bool

    public init() {
        symbolFromDynamicLibrary = None
        baseName = None
        state = None
        returnType = AbiType.Void
        argTypes = ArrayList<AbiType>()
        step = FfiStep.Pending
        threadsafe = false
    }

    /// 是否需要 HandleScope (含 napi_env/napi_value 参数或返回值)
    /// 对应 Rust: Function::needs_handle_scope (ffi_body.rs:1977)
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

    /// 是否需要 NAPI 环境
    /// 对应 Rust: Function::needs_napi_env (ffi_body.rs:2056)
    public func needsNapiEnv(): Bool {
        for (arg in argTypes) {
            match (arg) {
                case NapiEnv | NapiValue => return true
                case _ => ()
            }
        }
        return false
    }

    /// 重置函数描述到默认状态
    /// 对应 Rust: *function = Function::default() (host_fns.rs:178)
    /// 在 generateSymbolForFunction 中重置字段前调用
    public func reset(): Unit {
        symbolFromDynamicLibrary = None
        baseName = None
        state = None
        returnType = AbiType.Void
        argTypes = ArrayList<AbiType>()
        step = FfiStep.Pending
        threadsafe = false
    }

    /// 标记编译失败
    /// 对应 Rust: Function::fail (ffi_body.rs:1986)
    public func fail(msg: String): Unit {
        match (step) {
            case FfiStep.Failed(_, _) => () // 不覆盖已有失败
            case _ => step = FfiStep.Failed(msg, false)
        }
    }

    // ========================================================================
    // 编译函数
    // 对应 Rust: Function::compile (host_fns.rs:262 / ffi_body.rs:2037)
    // ========================================================================

    /// 编译 FFI 函数
    /// 对应 Rust: pub fn compile(&mut self, _napi_env) -> Result<(), Error>
    /// 目前返回失败 (TinyCC 不可用)
    /// FFI (b2-blocked): 需要集成 TinyCC (C 编译器) 才能实现运行时编译。
    /// TinyCC 负责将生成的 C 源码编译为机器码并重定位到可执行内存。
    /// 在仓颉中实现此功能需要: 1) TinyCC C FFI 绑定 或 2) 使用 LLVM/其他 JIT
    public func compile(napiEnv: ?Int64): ?String {
        let sourceCode = printSourceCode()
        fail("TinyCC is not available in this build of Bao")
        return None
    }

    /// 编译回调函数
    /// 对应 Rust: pub fn compile_callback(&mut self, js_context, js_function, is_threadsafe)
    /// 目前返回失败 (TinyCC 不可用)
    /// FFI (b2-blocked): 同 compile(), 需要 TinyCC 集成
    public func compileCallback(globalObject: JsObject, jsCallback: JsValue, isThreadsafe: Bool): ?String {
        fail("TinyCC is not available in this build of Bao")
        return None
    }

    /// 获取 FFI 头文件内容
    /// 对应 Rust: Function::ffi_header (ffi_body.rs:1996)
    public static func ffiHeader(): String {
        // 对应 Bun FFI.h 的内容摘要
        // 完整内容在 FFI.h 中定义
        return "#define ZIG_REPR_TYPE int64_t\n" +
            "#define DoubleEncodeOffsetBit 49\n" +
            "#define DoubleEncodeOffset (1ll << DoubleEncodeOffsetBit)\n" +
            "#define OtherTag 0x2ll\n" +
            "#define BoolTag 0x4ll\n" +
            "#define UndefinedTag 0x8ll\n" +
            "#define NumberTag 0xfffe000000000000ll\n" +
            "#define NotCellMask (int64_t)(NumberTag | OtherTag)\n" +
            "#define MAX_INT32 2147483648\n" +
            "#define MAX_INT52 9007199254740991\n" +
            "#define LOAD_ARGUMENTS_FROM_CALL_FRAME \\\n" +
            "  int64_t *argsPtr = (int64_t*)((size_t*)callFrame + Bun_FFI_PointerOffsetToArgumentsList)\n"
    }

    // ========================================================================
    // 源码生成 — C trampoline 代码
    // 对应 Rust: Function::print_source_code (ffi_body.rs:2276)
    // ========================================================================

    /// 打印 FFI 函数的 C trampoline 源代码
    /// 对应 Rust: pub fn print_source_code(&self, writer)
    public func printSourceCode(): String {
        var sb = StringBuilder()

        // 参数存在时定义 HAS_ARGUMENTS
        if (!argTypes.isEmpty()) {
            sb.append("#define HAS_ARGUMENTS\n")
        }

        // 浮点检测
        if (returnType.isFloatingPoint()) {
            sb.append("#define USES_FLOAT 1\n")
        } else {
            for (arg in argTypes) {
                if (arg.isFloatingPoint()) {
                    sb.append("#define USES_FLOAT 1\n")
                    break
                }
            }
        }

        // FFI 头文件
        sb.append(FfiFunction.ffiHeader())

        // 函数声明
        sb.append("/* --- The Function To Call */\n")
        sb.append(returnType.typenameLabel())
        sb.append(" ")
        sb.append(if (baseName.isSome()) { baseName.getOrThrow() } else { "" })
        sb.append("(")
        var first = true
        var i: Int64 = 0
        for (arg in argTypes) {
            if (!first) {
                sb.append(", ")
            }
            first = false
            sb.append(arg.paramTypenameLabel())
            sb.append(" arg${i}")
            i += 1
        }
        sb.append(");\n\n")

        // Wrapper 函数
        sb.append("/* ---- Your Wrapper Function ---- */\n")
        sb.append("ZIG_REPR_TYPE JSFunctionCall(void* JS_GLOBAL_OBJECT, void* callFrame) {\n")

        // HandleScope
        if (needsHandleScope()) {
            sb.append("  void* handleScope = NapiHandleScope__open(&Bun__thisFFIModuleNapiEnv, false);\n")
        }

        // 参数加载
        if (!argTypes.isEmpty()) {
            sb.append("  LOAD_ARGUMENTS_FROM_CALL_FRAME;\n")
            var j: Int64 = 0
            while (j < argTypes.size) {
                let arg = argTypes[j]
                match (arg) {
                    case NapiEnv =>
                        sb.append("  napi_env arg${j} = (napi_env)&Bun__thisFFIModuleNapiEnv;\n")
                        sb.append("  argsPtr++;\n")
                    case NapiValue =>
                        sb.append("  EncodedJSValue arg${j} = { .asInt64 = *argsPtr++ };\n")
                    case _ =>
                        if (arg.needsACastInC()) {
                            if (j < argTypes.size - 1) {
                                sb.append("  EncodedJSValue arg${j} = { .asInt64 = *argsPtr++ };\n")
                            } else {
                                sb.append("  EncodedJSValue arg${j};\n")
                                sb.append("  arg${j}.asInt64 = *argsPtr;\n")
                            }
                        } else {
                            if (j < argTypes.size - 1) {
                                sb.append("  int64_t arg${j} = *argsPtr++;\n")
                            } else {
                                sb.append("  int64_t arg${j} = *argsPtr;\n")
                            }
                        }
                }
                j += 1
            }
        }

        // 调用目标函数
        sb.append("    ")
        let hasReturnValue = match (returnType) {
            case AbiType.Void => false
            case _ => true
        }
        if (hasReturnValue) {
            sb.append(returnType.typenameLabel())
            sb.append(" return_value = ")
        }
        sb.append(if (baseName.isSome()) { baseName.getOrThrow() } else { "" })
        sb.append("(")
        first = true
        var k: Int64 = 0
        while (k < argTypes.size) {
            let arg = argTypes[k]
            if (!first) {
                sb.append(", ")
            }
            first = false
            sb.append("    ")
            let argName = "arg${k}"
            if (arg.needsACastInC()) {
                sb.append(arg.toCFormatter(argName, false))
            } else {
                sb.append(argName)
            }
            k += 1
        }
        sb.append(");\n")

        if (!first) {
            sb.append("\n")
        }

        sb.append("    ")

        // 关闭 HandleScope
        if (needsHandleScope()) {
            sb.append("  NapiHandleScope__close(&Bun__thisFFIModuleNapiEnv, handleScope);\n")
        }

        // 返回值
        sb.append("return ")
        if (hasReturnValue) {
            sb.append(returnType.toJSFormatter("return_value"))
            sb.append(".asZigRepr")
        } else {
            sb.append("ValueUndefined.asZigRepr")
        }
        sb.append(";\n}\n\n")

        return sb.toString()
    }

    // ========================================================================
    // 回调源码生成
    // 对应 Rust: Function::print_callback_source_code (ffi_body.rs:2432)
    // ========================================================================

    /// 打印回调函数的 C trampoline 源代码
    /// 对应 Rust: pub fn print_callback_source_code
    public func printCallbackSourceCode(globalObjectPtr: Int64, contextPtr: Int64): String {
        var sb = StringBuilder()

        sb.append("#define JS_GLOBAL_OBJECT (void*)0x${int64FormatHex(globalObjectPtr)}ULL\n")
        sb.append("#define IS_CALLBACK 1\n")

        // 浮点检测
        if (returnType.isFloatingPoint()) {
            sb.append("#define USES_FLOAT 1\n")
        } else {
            for (arg in argTypes) {
                if (arg.isFloatingPoint()) {
                    sb.append("#define USES_FLOAT 1\n")
                    break
                }
            }
        }

        sb.append(FfiFunction.ffiHeader())

        // 回调函数声明
        sb.append("\n \n/* --- The Callback Function */\n")
        sb.append(returnType.typenameLabel())
        sb.append(" my_callback_function(")
        var first = true
        var i: Int64 = 0
        for (arg in argTypes) {
            if (!first) {
                sb.append(", ")
            }
            first = false
            sb.append(arg.typenameLabel())
            sb.append(" arg${i}")
            i += 1
        }
        sb.append(") {\n")

        // 参数转 JS 值
        if (!argTypes.isEmpty()) {
            sb.append(" ZIG_REPR_TYPE arguments[${argTypes.size}];\n")
            var j: Int64 = 0
            while (j < argTypes.size) {
                let arg = argTypes[j]
                let argName = "arg${j}"
                sb.append("arguments[${j}] = ${arg.toJSFormatter(argName)}.asZigRepr;\n")
                j += 1
            }
        }

        sb.append("  ")

        // 调用 FFI_Callback_call
        let innerCall = if (!argTypes.isEmpty()) {
            "FFI_Callback_call((void*)0x${int64FormatHex(contextPtr)}ULL, ${argTypes.size}, arguments)"
        } else {
            "FFI_Callback_call((void*)0x${int64FormatHex(contextPtr)}ULL, 0, (ZIG_REPR_TYPE*)0)"
        }

        match (returnType) {
            case AbiType.Void => sb.append(innerCall)
            case _ => sb.append("return ${returnType.toCFormatter("_" + innerCall, true)}")
        }

        sb.append(";\n}\n\n")

        return sb.toString()
    }
}

// ============================================================================
// CompileC — C 代码即时编译器封装
// 对应 Bun: FFI.CompileC (ffi_body.rs:262)
// ============================================================================

/// C 源文件 (单文件或多文件)
/// 对应 Rust: enum Source { File(ZBox), Files(Vec<ZBox>) }
public enum FfiSource {
    | File(String)
    | Files(ArrayList<String>)

    public func first(): String {
        match (this) {
            case FfiSource.File(fileStr) =>
                let result = fileStr
                return result
            case FfiSource.Files(fileList) =>
                let files = fileList
                return if (files.isEmpty()) { "" } else { files[0] }
        }
    }
}

/// 字符串数组 (用于库路径、包含路径等)
/// 对应 Rust: struct StringArray { items: Vec<ZBox> }
public class FfiStringArray {
    public var items: ArrayList<String>

    public init() {
        items = ArrayList<String>()
    }

    /// 从 JS 数组构建
    public static func fromJsArray(globalObject: JsObject, value: JsValue, property: String): ?FfiStringArray {
        let arr = FfiStringArray()
        // 简化: 从 JS 数组中读取字符串
        // 实际实现需要遍历 JS 数组
        return arr
    }
}

/// C 编译错误
/// 对应 Rust: enum DeferredError (ffi_body.rs:461)
public class FfiDeferredError {
    public var message: String

    public init(message: String) {
        this.message = message
    }
}

/// 编译符号映射
/// 对应 Rust: struct SymbolsMap { map: StringArrayHashMap<Function> }
public class FfiSymbolsMap {
    public var map: HashMap<String, FfiFunction>

    public init() {
        map = HashMap<String, FfiFunction>()
    }
}

/// C 即时编译封装 (TinyCC)
/// 对应 Rust: struct CompileC (ffi_body.rs:262)
public class CompileC {
    /// 源文件 (单文件或多文件)
    public var source: FfiSource
    /// 当前错误报告文件名
    public var currentFileForErrors: String
    /// 链接库名列表
    public var libraries: FfiStringArray
    /// 库搜索路径
    public var libraryDirs: FfiStringArray
    /// 头文件搜索路径
    public var includeDirs: FfiStringArray
    /// 符号映射
    public var symbols: FfiSymbolsMap
    /// 预定义宏
    public var defines: ArrayList<(String, String)>
    /// 编译选项 (覆盖默认)
    public var flags: ?String
    /// 延迟错误列表
    public var deferredErrors: ArrayList<String>

    /// 默认 TCC 编译选项
    /// 对应 Rust: CompileC::DEFAULT_TCC_OPTIONS
    public static let DEFAULT_TCC_OPTIONS: String = "-std=c11 -Wl,--export-all-symbols -g -O2"

    public init() {
        source = FfiSource.File("")
        currentFileForErrors = ""
        libraries = FfiStringArray()
        libraryDirs = FfiStringArray()
        includeDirs = FfiStringArray()
        symbols = FfiSymbolsMap()
        defines = ArrayList<(String, String)>()
        flags = None
        deferredErrors = ArrayList<String>()
    }

    /// 是否有延迟错误
    /// 对应 Rust: CompileC::has_deferred_errors
    public func hasDeferredErrors(): Bool {
        return !deferredErrors.isEmpty()
    }

    /// 错误检查
    /// 对应 Rust: CompileC::error_check
    public func errorCheck(): ?FfiDeferredError {
        if (hasDeferredErrors()) {
            return FfiDeferredError("DeferredErrors")
        }
        return None
    }

    /// 编译错误回调 (从 TCC 回调)
    /// 对应 Rust: CompileC::handle_compilation_error (ffi_body.rs:480)
    public func handleCompilationError(message: String): Unit {
        if (message.isEmpty()) {
            return
        }
        // 跳过前导空白/控制字符
        var offset = 0
        while (offset < message.size) {
            let ch = message[offset]
            if (ch > 0x20 && ch < 0x7f) {
                break
            }
            offset += 1
        }
        if (offset < message.size) {
            deferredErrors.append(message[offset..])
        }
    }
}

// ============================================================================
// CompilerRT — 编译器运行时辅助
// 对应 Bun: FFI.CompilerRT (ffi_body.rs:2624)
// ============================================================================

/// 编译器运行时 (为 TCC 提供基础 C 运行时函数)
/// 对应 Rust: struct CompilerRT
public class CompilerRT {
    /// 编译器运行时头文件列表
    /// 对应 Rust: CompilerRtSources::SOURCES
    public static let SOURCES: ArrayList<(String, String)> = createSources()

    private static func createSources(): ArrayList<(String, String)> {
        let list = ArrayList<(String, String)>()
        list.append(("stdbool.h", """
#ifndef _STDBOOL_H
#define _STDBOOL_H
#define bool _Bool
#define true 1
#define false 0
#define __bool_true_false_are_defined 1
#endif /* _STDBOOL_H */
"""))
        list.append(("stdarg.h", """
#ifndef _STDARG_H
#define _STDARG_H
typedef __builtin_va_list va_list;
#define va_start __builtin_va_start
#define va_arg __builtin_va_arg
#define va_copy __builtin_va_copy
#define va_end __builtin_va_end
typedef va_list __gnuc_va_list;
#define _VA_LIST_DEFINED
#endif /* _STDARG_H */
"""))
        list.append(("stdnoreturn.h", """
#ifndef _STDNORETURN_H
#define _STDNORETURN_H
#define noreturn _Noreturn
#endif /* _STDNORETURN_H */
"""))
        list.append(("stdalign.h", """
#ifndef _STDALIGN_H
#define _STDALIGN_H
#if __STDC_VERSION__ < 201112L && (defined(__GNUC__) || defined(__TINYC__))
#define _Alignas(t) __attribute__((__aligned__(t)))
#define _Alignof(t) __alignof__(t)
#endif
#define alignas _Alignas
#define alignof _Alignof
#define __alignas_is_defined 1
#define __alignof_is_defined 1
#endif /* _STDALIGN_H */
"""))
        list.append(("tgmath.h", """
#ifndef _TGMATH_H
#define _TGMATH_H
#include <math.h>
#ifndef __cplusplus
#define __tgmath_real(x, F) _Generic((x), float: F##f, long double: F##l, default: F)(x)
#define __tgmath_real_2_1(x, y, F) _Generic((x), float: F##f, long double: F##l, default: F)(x, y)
#define __tgmath_real_2(x, y, F) _Generic((x) + (y), float: F##f, long double: F##l, default: F)(x, y)
#define __tgmath_real_3_2(x, y, z, F) _Generic((x) + (y), float: F##f, long double: F##l, default: F)(x, y, z)
#define __tgmath_real_3(x, y, z, F) _Generic((x) + (y) + (z), float: F##f, long double: F##l, default: F)(x, y, z)
#define acos(z) __tgmath_real(z, acos)
#define asin(z) __tgmath_real(z, asin)
#define atan(z) __tgmath_real(z, atan)
#define cos(z) __tgmath_real(z, cos)
#define sin(z) __tgmath_real(z, sin)
#define tan(z) __tgmath_real(z, tan)
#define exp(z) __tgmath_real(z, exp)
#define log(z) __tgmath_real(z, log)
#define pow(z1, z2) __tgmath_real_2(z1, z2, pow)
#define sqrt(z) __tgmath_real(z, sqrt)
#define fabs(z) __tgmath_real(z, fabs)
#define atan2(x, y) __tgmath_real_2(x, y, atan2)
#define ceil(x) __tgmath_real(x, ceil)
#define floor(x) __tgmath_real(x, floor)
#define fmax(x, y) __tgmath_real_2(x, y, fmax)
#define fmin(x, y) __tgmath_real_2(x, y, fmin)
#define fmod(x, y) __tgmath_real_2(x, y, fmod)
#define round(x) __tgmath_real(x, round)
#define trunc(x) __tgmath_real(x, trunc)
#endif /* __cplusplus */
#endif /* _TGMATH_H */
"""))
        list.append(("stddef.h", """
#ifndef _STDDEF_H
#define _STDDEF_H
typedef __SIZE_TYPE__ size_t;
typedef __PTRDIFF_TYPE__ ssize_t;
typedef __WCHAR_TYPE__ wchar_t;
typedef __PTRDIFF_TYPE__ ptrdiff_t;
typedef __PTRDIFF_TYPE__ intptr_t;
typedef __SIZE_TYPE__ uintptr_t;
#if __STDC_VERSION__ >= 201112L
typedef union { long long __ll; long double __ld; } max_align_t;
#endif
#ifndef NULL
#define NULL ((void*)0)
#endif
#undef offsetof
#define offsetof(type, field) ((size_t)&((type*)0)->field)
#if defined __i386__ || defined __x86_64__
void* alloca(size_t size);
#endif
#endif
#if defined(__need_wint_t)
#ifndef _WINT_T
#define _WINT_T
typedef __WINT_TYPE__ wint_t;
#endif
#undef __need_wint_t
#endif
"""))
        list.append(("varargs.h", "// empty"))
        return list
    }

    /// memset 实现 (供 TCC 编译的代码调用)
    /// 对应 Rust: CompilerRT::memset (ffi_body.rs:2688)
    public static func memset(dest: Int64, c: UInt8, byteCount: Int64): Unit {
        // 通过 FFI 调用 C memset
        // 实际实现: foreign func memset
    }

    /// memcpy 实现 (供 TCC 编译的代码调用)
    /// 对应 Rust: CompilerRT::memcpy (ffi_body.rs:2694)
    public static func memcpy(dest: Int64, source: Int64, byteCount: Int64): Unit {
        // 通过 FFI 调用 C memcpy
        // 实际实现: foreign func memcpy
    }
}

// ============================================================================
// FFI 模块 — 核心宿主函数
// 对应 Bun: FFI (ffi_body.rs:230)
// ============================================================================

/// FFI 模块主体
/// 对应 Rust: #[bun_jsc::JsClass] pub struct FFI
/// 管理 dlopen 句柄、函数映射、TCC 共享状态
public class FfiModule {
    /// 动态库句柄
    public var dylib: ?DynamicLibrary
    /// 已注册的函数映射
    public var functions: HashMap<String, FfiFunction>
    /// 是否已关闭
    public var closed: Bool
    /// TCC 共享状态指针
    public var sharedState: ?Int64

    public init() {
        dylib = None
        functions = HashMap<String, FfiFunction>()
        closed = false
        sharedState = None
    }

    // ========================================================================
    // GC finalize
    // 对应 Rust: FFI::finalize (ffi_body.rs:250)
    // ========================================================================

    /// GC 终结器 — 无操作 (清理由 close() 负责)
    /// 对应 Rust: pub fn finalize(self: Box<Self>)
    public func finalize(): Unit {
        // 刻意为空 — 编译后的 trampoline 和 dlopen 符号可能在 GC 后仍被引用
    }

    // ========================================================================
    // cc — 即时编译 C 代码
    // 对应 Rust: FFI::bun_ffi_cc (ffi_body.rs:1001)
    // ========================================================================

    /// cc() 宿主函数 — 从 JS 端调用即时编译 C 代码
    /// 对应 Rust: pub fn bun_ffi_cc(global_this, callframe)
    public static func cc(globalObject: JsObject, arguments: ArrayList<JsValue>): JsValue {
        // 1. 验证参数
        if (arguments.isEmpty()) {
            return JsValue(BaoString("Expected object"))
        }
        let object = arguments[0]
        if (object.valueType != JsValueType.Object) {
            return JsValue(BaoString("Expected object"))
        }

        // 2. 构建 CompileC
        var compileC = CompileC()

        // 3. 解析 symbols
        let objOpt = object.objectData
        if (objOpt.isNone()) {
            return JsValue(BaoString("Expected object"))
        }
        let obj = objOpt.getOrThrow()
        let symbolsObject = obj.get("symbols")
        if (symbolsObject.valueType != JsValueType.Object) {
            return JsValue(BaoString("Expected object for symbols"))
        }

        let symbolsMap = generateSymbols(globalObject, symbolsObject)
        if (symbolsMap.isNone()) {
            return JsValue(BaoString("Failed to generate symbols"))
        }
        let map = symbolsMap.getOrThrow()
        compileC.symbols.map = map
        if (map.size == 0) {
            return JsValue(BaoString("Expected at least one exported symbol"))
        }

        // 4. 解析 library, flags, define, include, source
        let libraryValue = obj.get("library")
        if (libraryValue.valueType != JsValueType.Undefined) {
            // 解析库路径
        }

        let flagsValue = obj.get("flags")
        if (flagsValue.valueType == JsValueType.String) {
            compileC.flags = Some(flagsValue.toString())
        }

        // 5. 编译 (需要 TinyCC 支持)
        // 目前返回未实现错误
        return JsValue(BaoString("TinyCC is not available in this build of Bao"))
    }

    // ========================================================================
    // open — dlopen 打开动态库
    // 对应 Rust: FFI::open (ffi_body.rs:1456)
    // ========================================================================

    /// dlopen 打开动态库并绑定符号
    /// 对应 Rust: pub fn open(global, name_str, object_value)
    public static func open(globalObject: JsObject, name: String, objectValue: JsValue): JsValue {
        if (name.isEmpty()) {
            return JsValue(BaoString("Invalid library name"))
        }

        if (objectValue.valueType != JsValueType.Object) {
            return JsValue(BaoString("Expected an options object with symbol names"))
        }

        // 生成符号映射
        let symbolsResult = generateSymbols(globalObject, objectValue)
        if (symbolsResult.isNone()) {
            return JsValue(BaoString("Failed to generate symbols"))
        }
        let symbols = symbolsResult.getOrThrow()
        if (symbols.size == 0) {
            return JsValue(BaoString("Expected at least one symbol"))
        }

        // 尝试打开动态库
        let libOpt = DynamicLibrary.open(name)
        if (libOpt.isNone()) {
            let dlError = DynamicLibrary.getLastError()
            return JsValue(BaoString("Failed to open library \"${name}\": ${dlError}"))
        }
        let dylib = libOpt.getOrThrow()
        var resultObj = JsObject()
        var ffi = FfiModule()
        ffi.dylib = Some(dylib)
        ffi.functions = symbols

        // 解析每个符号
        let symKeys = symbols.keys()
        for (symName in symKeys) {
            let ffiFuncOpt = symbols.get(symName)
            if (ffiFuncOpt.isNone()) { continue }
            let ffiFunc = ffiFuncOpt.getOrThrow()
            let addr = dylib.lookup(symName)
            if (addr == 0) {
                dylib.close()
                return JsValue(BaoString("Symbol not found in library"))
            }
            ffiFunc.symbolFromDynamicLibrary = Some(addr)

            // 编译 FFI wrapper
            let compileErr = ffiFunc.compile(Option<Int64>.None)
            if (compileErr.isSome()) {
                dylib.close()
                return JsValue(BaoString("Error when compiling symbol in library"))
            }
            match (ffiFunc.step) {
                case FfiStep.Compiled(compiled) =>
                    resultObj.set(symName, JsValue(BaoString("FFI function: ${symName}")))
                case FfiStep.Failed(msg, _) =>
                    dylib.close()
                    return JsValue(BaoString(msg))
                case FfiStep.Pending =>
                    dylib.close()
                    return JsValue(BaoString("Failed to compile (nothing happened)"))
            }
        }

        return JsValue(resultObj)
    }

    // ========================================================================
    // close — 关闭 FFI 实例
    // 对应 Rust: FFI::close (ffi_body.rs:1351)
    // ========================================================================

    /// 关闭 FFI 实例, 释放动态库和函数
    /// 对应 Rust: pub fn close(&self, _global_this, _)
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

        // 释放 TCC 共享状态
        if (sharedState.isSome()) {
            // tcc_delete(sharedState.getOrThrow())
            sharedState = None
        }

        // 清空函数映射
        functions.clear()

        return JsValue.UNDEFINED
    }

    // ========================================================================
    // callback — 创建 FFI 回调
    // 对应 Rust: FFI::callback (ffi_body.rs:1287)
    // ========================================================================

    /// 创建 FFI 回调函数
    /// 对应 Rust: pub fn callback(global_this, interface, js_callback)
    public static func callback(globalObject: JsObject, callbackInterface: JsValue, jsCallback: JsValue): JsValue {
        if (callbackInterface.valueType != JsValueType.Object) {
            return JsValue(BaoString("Expected object"))
        }

        if (jsCallback.valueType != JsValueType.Function) {
            return JsValue(BaoString("Expected callback function"))
        }

        // 生成函数描述
        var ffiFunc = FfiFunction()
        if (generateSymbolForFunction(globalObject, callbackInterface, ffiFunc).isSome()) {
            return generateSymbolForFunction(globalObject, callbackInterface, ffiFunc).getOrThrow()
        }

        ffiFunc.baseName = Some("")

        // 编译回调 (需要 TinyCC)
        if (ffiFunc.compileCallback(globalObject, jsCallback, ffiFunc.threadsafe).isSome()) {
            return JsValue(BaoString("Out of memory"))
        }

        match (ffiFunc.step) {
            case FfiStep.Compiled(compiled) =>
                let result = JsObject()
                result.set("ptr", JsValue(Float64(compiled.ptr)))
                return JsValue(result)
            case FfiStep.Failed(msg, _) => JsValue(BaoString(msg))
            case FfiStep.Pending => JsValue(BaoString("Failed to compile, but not sure why"))
        }
    }

    // ========================================================================
    // closeCallback — 关闭回调
    // 对应 Rust: FFI::close_callback (ffi_body.rs:1281)
    // ========================================================================

    /// 关闭回调函数 (释放堆上的 Function)
    /// 对应 Rust: pub fn close_callback(_global_this, ctx)
    public static func closeCallback(globalObject: JsObject, ctx: JsValue): JsValue {
        // 释放通过 callback() 创建的堆上 FfiFunction
        // 对应 Rust: drop(unsafe { bun_core::heap::take(ctx.as_ptr_address() as *mut Function) })
        return JsValue.UNDEFINED
    }

    // ========================================================================
    // linkSymbols — 链接已知符号
    // 对应 Rust: FFI::link_symbols (ffi_body.rs:1646)
    // ========================================================================

    /// 链接已知符号 (无需动态库)
    /// 对应 Rust: pub fn link_symbols(global, object_value)
    public static func linkSymbols(globalObject: JsObject, objectValue: JsValue): JsValue {
        if (objectValue.valueType != JsValueType.Object) {
            return JsValue(BaoString("Expected an options object with symbol names"))
        }

        let symbolsResult = generateSymbols(globalObject, objectValue)
        if (symbolsResult.isSome()) {
            let symbols = symbolsResult.getOrThrow()
            if (symbols.size == 0) {
                return JsValue(BaoString("Expected at least one symbol"))
            }

            // 验证每个符号都有 ptr 字段
            let symKeys2 = symbols.keys()
            for (symName in symKeys2) {
                let ffiFuncOpt = symbols.get(symName)
                if (ffiFuncOpt.isNone()) { continue }
                let ffiFunc = ffiFuncOpt.getOrThrow()
                if (ffiFunc.symbolFromDynamicLibrary.isNone()) {
                    return JsValue(BaoString("Symbol is missing a ptr field. " +
                        "When using linkSymbols() or CFunction(), you must provide a ptr " +
                        "field with the memory address of the native function."))
                }

                // 编译 FFI wrapper
                let compileResult = ffiFunc.compile(Option<Int64>.None)
                if (compileResult.isSome()) {
                    return JsValue(BaoString("Error when compiling symbol"))
                }
                match (ffiFunc.step) {
                    case FfiStep.Failed(msg, _) => return JsValue(BaoString(msg))
                    case FfiStep.Pending => return JsValue(BaoString("Failed to compile (nothing happened)"))
                    case FfiStep.Compiled(_) => ()
                }
            }

            var ffi = FfiModule()
            ffi.functions = symbols
            return JsValue.UNDEFINED
        } else {
            return JsValue(BaoString("Invalid symbols object"))
        }
    }

    // ========================================================================
    // print — 打印 FFI 绑定源代码
    // 对应 Rust: FFI::print (ffi_body.rs:1399)
    // ========================================================================

    /// 打印 FFI 函数的 C 源代码
    /// 对应 Rust: pub fn print(global, object, is_callback_val)
    public static func print(globalObject: JsObject, object: JsValue, isCallback: ?JsValue): JsValue {
        // 检查是否为回调模式
        if (isCallback.isSome()) {
            let v = isCallback.getOrThrow()
            if (v.toBoolean()) {
                return printCallback(globalObject, object)
            }
        }

        if (object.valueType != JsValueType.Object) {
            return JsValue(BaoString("Expected an options object with symbol names"))
        }

        let symbolsResult = generateSymbols(globalObject, object)
        if (symbolsResult.isSome()) {
            let symbols = symbolsResult.getOrThrow()
            var sources = ArrayList<String>()
            let symKeys3 = symbols.keys()
            for (name in symKeys3) {
                let ffiFuncOpt = symbols.get(name)
                if (ffiFuncOpt.isNone()) { continue }
                let ffiFunc = ffiFuncOpt.getOrThrow()
                ffiFunc.baseName = Some(name)
                let source = ffiFunc.printSourceCode()
                sources.append(source)
            }
            let jsSources = ArrayList<JsValue>()
            for (s in sources) {
                jsSources.append(JsValue(BaoString(s)))
            }
            return JsValue.array(jsSources)
        } else {
            return JsValue(BaoString("Invalid symbols object"))
        }
    }

    /// 打印回调函数源代码
    /// 对应 Rust: FFI::print_callback (ffi_body.rs:1372)
    private static func printCallback(globalObject: JsObject, object: JsValue): JsValue {
        if (object.valueType != JsValueType.Object) {
            return JsValue(BaoString("Expected an object"))
        }

        var ffiFunc = FfiFunction()
        let genResult = generateSymbolForFunction(globalObject, object, ffiFunc)
        if (genResult.isSome()) { return genResult.getOrThrow() }

        ffiFunc.baseName = Some("my_callback_function")
        let source = ffiFunc.printCallbackSourceCode(0, 0)
        return JsValue(BaoString(source))
    }

    // ========================================================================
    // getSymbols — 获取符号 (缓存 getter)
    // 对应 Rust: FFI::get_symbols (ffi_body.rs:1641)
    // ========================================================================

    /// 获取已注册的符号 (不应被直接调用, 使用缓存值)
    /// 对应 Rust: pub fn get_symbols(_this, _)
    public static func getSymbols(): JsValue {
        return JsValue.UNDEFINED
    }
}

// ============================================================================
// Int64 辅助扩展
// ============================================================================

/// Int64 十六进制格式化
public func int64FormatHex(input: Int64): String {
    var result = ""
    var value = input
    if (value == 0) {
        return "0"
    }
    let hexChars = "0123456789ABCDEF"
    while (value > 0) {
        let digit = value % 16
        result = hexChars[digit..digit + 1] + result
        value = value / 16
    }
    return result
}
