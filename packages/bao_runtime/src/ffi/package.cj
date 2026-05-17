// FFI 模块入口
// 对应 Bun: src/runtime/ffi/mod.rs
// 汇总导出所有 FFI 相关类型
package bao_runtime.ffi

// ============================================================================
// ABI 类型 (来自 abi_type.cj)
// ============================================================================

/// ABI 类型枚举
public type FfiAbiType = AbiType

/// 枚举映射格式化器
public type FfiEnumMapFormatter = EnumMapFormatter

// ============================================================================
// FFI 函数类型 (来自 ffi_body.cj)
// ============================================================================

/// FFI 函数描述
public type FfiFn = FfiFunction

/// FFI 编译步骤
public type FfiFnStep = FfiStep

/// FFI 已编译函数
public type FfiCompiledFn = FfiCompiled

/// FFI C 源文件
public type FfiSourceFile = FfiSource

/// FFI 字符串数组
public type FfiStringArrayRef = FfiStringArray

/// FFI 符号映射
public type FfiSymbolsMapRef = FfiSymbolsMap

/// FFI 编译器
public type FfiCompiler = CompileC

/// FFI 编译器运行时
public type FfiCompilerRT = CompilerRT

// ============================================================================
// FFI 模块 (来自 ffi_body.cj)
// ============================================================================

/// FFI 模块主体 (dlopen, cc, callback, linkSymbols 等)
public type FfiModuleRef = FfiModule

// ============================================================================
// FFI 对象 (来自 ffi_object.cj)
// ============================================================================

/// FFI 对象 (指针操作、Reader、Buffer 转换)
public type FfiPtr = FfiObject

/// FFI ArrayBuffer 视图
public type FfiArrayBufferView = ArrayBufferView

/// FFI 指针切片结果
public type FfiSliceResultRef = FfiSliceResult

// ============================================================================
// FFI 类定义 (来自 ffi_classes.cj)
// ============================================================================

/// FFI JS 类定义
public type FfiClassDef = FfiClassDefinition

/// FFI 原型方法定义
public type FfiProtoMethodDef = FfiPrototypeMethodDef

/// FFI 原型属性定义
public type FfiProtoPropertyDef = FfiPrototypePropertyDef

/// FFI 方法定义
public type FfiMethodDefRef = FfiMethodDef

// ============================================================================
// FFI 宿主函数 (来自 host_fns.cj)
// ============================================================================

/// FFI 字段入口
public type FfiFieldEntryRef = FfiFieldEntry

/// DOM Call 慢路径
public type FfiDomCallSlowPath = DomCallSlowPath

// ============================================================================
// 动态库 (来自 ffi.cj)
// ============================================================================

/// 动态库
public type DynLib = DynamicLibrary

