// FFI 模块入口
// 对应 Bun: src/runtime/ffi/mod.rs
// 汇总导出所有 FFI 相关类型
package bao_runtime.ffi

// ============================================================================
// ABI 类型 (来自 abi_type.cj)
// ============================================================================

/// ABI 类型枚举
public typealias FfiAbiType = AbiType

/// 枚举映射格式化器
public typealias FfiEnumMapFormatter = EnumMapFormatter

// ============================================================================
// FFI 函数类型 (来自 ffi_body.cj)
// ============================================================================

/// FFI 函数描述
public typealias FfiFn = FfiFunction

/// FFI 编译步骤
public typealias FfiFnStep = FfiStep

/// FFI 已编译函数
public typealias FfiCompiledFn = FfiCompiled

/// FFI C 源文件
public typealias FfiSourceFile = FfiSource

/// FFI 字符串数组
public typealias FfiStringArrayRef = FfiStringArray

/// FFI 符号映射
public typealias FfiSymbolsMapRef = FfiSymbolsMap

/// FFI 编译器
public typealias FfiCompiler = CompileC

/// FFI 编译器运行时
public typealias FfiCompilerRT = CompilerRT

// ============================================================================
// FFI 模块 (来自 ffi_body.cj)
// ============================================================================

/// FFI 模块主体 (dlopen, cc, callback, linkSymbols 等)
public typealias FfiModuleRef = FfiModule

// ============================================================================
// FFI 对象 (来自 ffi_object.cj)
// ============================================================================

/// FFI 对象 (指针操作、Reader、Buffer 转换)
public typealias FfiPtr = FfiObject

/// FFI Reader (内存读取器)
public typealias FfiReader = FfiObject.Reader

/// FFI ArrayBuffer 视图
public typealias FfiArrayBufferView = ArrayBufferView

/// FFI 指针切片结果
public typealias FfiSliceResultRef = FfiSliceResult

// ============================================================================
// FFI 类定义 (来自 ffi_classes.cj)
// ============================================================================

/// FFI JS 类定义
public typealias FfiClassDef = FfiClassDefinition

/// FFI 原型方法定义
public typealias FfiProtoMethodDef = FfiPrototypeMethodDef

/// FFI 原型属性定义
public typealias FfiProtoPropertyDef = FfiPrototypePropertyDef

/// FFI 方法定义
public typealias FfiMethodDefRef = FfiMethodDef

// ============================================================================
// FFI 宿主函数 (来自 host_fns.cj)
// ============================================================================

/// FFI 字段入口
public typealias FfiFieldEntryRef = FfiFieldEntry

/// DOM Call 慢路径
public typealias FfiDomCallSlowPath = DomCallSlowPath

// ============================================================================
// 动态库 (来自 ffi.cj)
// ============================================================================

/// 动态库
public typealias DynLib = DynamicLibrary

// ============================================================================
// 结果类型 (来自 ffi_object.cj)
// ============================================================================

/// FFI 切片结果
public typealias FfiSliceResult = FfiSliceResult
