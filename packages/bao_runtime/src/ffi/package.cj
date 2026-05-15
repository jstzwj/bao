// FFI 模块入口
// 对应 Bun: src/runtime/ffi/mod.rs
// 汇总导出所有 FFI 相关类型
package bao_runtime

// ABI 类型
public typealias FfiAbiType = AbiType

// FFI 函数
public typealias FfiFn = FfiFunction
public typealias FfiFnStep = FfiStep
public typealias FfiCompiledFn = FfiCompiledFunction

// FFI 对象 (指针操作)
public typealias FfiPtr = FfiObject
public typealias FfiReader = FfiObject.Reader

// 动态库
public typealias DynLib = DynamicLibrary

// 结果类型
public typealias FfiSliceResult = FfiSliceResult

// ArrayBuffer 视图
public typealias ArrayBufferView = ArrayBufferView
