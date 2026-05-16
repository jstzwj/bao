// node_api_types.cj - Node API 扩展类型定义
// 翻译自 Bun 源文件: src/runtime/napi/node_api_types.h
// 定义 Node.js 扩展的 N-API 类型，包括异步上下文、线程安全函数、模块版本等。

package bao_runtime.napi

// ============================================================================
// 不透明指针类型 (Node API 扩展)
// 对应 Bun: node_api_types.h 中的 struct 前向声明
// ============================================================================

/// N-API 回调作用域
/// 对应 C: typedef struct napi_callback_scope__* napi_callback_scope
public class NapiCallbackScopeHandle {}

/// N-API 异步上下文
/// 对应 C: typedef struct napi_async_context__* napi_async_context
public class NapiAsyncContextHandle {}

/// N-API 异步工作
/// 对应 C: typedef struct napi_async_work__* napi_async_work
public class NapiAsyncWorkHandle {}

/// N-API 线程安全函数
/// 对应 C: typedef struct napi_threadsafe_function__* napi_threadsafe_function
public class NapiThreadsafeFunctionHandle {}

/// N-API 异步清理钩子句柄
/// 对应 C: typedef struct napi_async_cleanup_hook_handle__* napi_async_cleanup_hook_handle
public class NapiAsyncCleanupHookHandleHandle {}

// ============================================================================
// napi_threadsafe_function_release_mode - 线程安全函数释放模式
// 对应 Bun: node_api_types.h - napi_threadsafe_function_release_mode (NAPI_VERSION >= 4)
// ============================================================================

/// 线程安全函数释放模式
/// 对应 C: napi_threadsafe_function_release_mode enum
public enum NapiThreadsafeFunctionReleaseMode {
    | napiTsfnRelease // 0
    | napiTsfnAbort   // 1

    public func toInt(): UInt32 {
        match (this) {
            case napiTsfnRelease => 0
            case napiTsfnAbort => 1
        }
    }
}

// ============================================================================
// napi_threadsafe_function_call_mode - 线程安全函数调用模式
// 对应 Bun: node_api_types.h - napi_threadsafe_function_call_mode (NAPI_VERSION >= 4)
// ============================================================================

/// 线程安全函数调用模式
/// 对应 C: napi_threadsafe_function_call_mode
/// 值为 c_uint: napi_tsfn_nonblocking = 0, napi_tsfn_blocking = 1
public enum NapiThreadsafeFunctionCallMode {
    | napiTsfnNonblocking // 0
    | napiTsfnBlocking    // 1

    public func toInt(): UInt32 {
        match (this) {
            case napiTsfnNonblocking => 0
            case napiTsfnBlocking => 1
        }
    }
}

// ============================================================================
// 回调函数类型 (Node API 扩展)
// 对应 Bun: node_api_types.h 中的回调类型定义
// ============================================================================

/// 异步执行回调
/// 对应 C: typedef void (*napi_async_execute_callback)(napi_env env, void* data)
public type NapiAsyncExecuteCallback = (NapiEnv, ?Any) -> Unit

/// 异步完成回调
/// 对应 C: typedef void (*napi_async_complete_callback)(napi_env env, napi_status status, void* data)
public type NapiAsyncCompleteCallback = (NapiEnv, UInt32, ?Any) -> Unit

/// 线程安全函数 JS 调用回调
/// 对应 C: typedef void (*napi_threadsafe_function_call_js)(napi_env env, napi_value js_callback, void* context, void* data)
public type NapiThreadsafeFunctionCallJs = (NapiEnv, NapiValue, ?Any, ?Any) -> Unit

/// 异步清理钩子回调
/// 对应 C: typedef void (*napi_async_cleanup_hook)(napi_async_cleanup_hook_handle handle, void* data)
public type NapiAsyncCleanupHook = (NapiAsyncCleanupHookHandleHandle, ?Any) -> Unit

/// 环境清理钩子回调
/// 对应 C: void (*fun)(void* arg)
public type NapiEnvCleanupHook = (?Any) -> Unit

// ============================================================================
// napi_node_version - Node.js 版本信息
// 对应 Bun: node_api_types.h - napi_node_version
// ============================================================================

/// Node.js 版本信息
/// 对应 C: napi_node_version struct
/// 对应 Bun: napi_node_version (napi.zig)
public class NapiNodeVersion {
    /// 主版本号
    public var major: UInt32
    /// 次版本号
    public var minor: UInt32
    /// 补丁版本号
    public var patch: UInt32
    /// 发布名称
    public var release: String

    public init(major: UInt32, minor: UInt32, patch: UInt32, release: String) {
        this.major = major
        this.minor = minor
        this.patch = patch
        this.release = release
    }

    /// 全局版本信息
/// 对应 Bun: napi_node_version.global
/// Bun 报告自身兼容的 Node.js 版本
    public static func globalVersion(): NapiNodeVersion {
        // 对应 Bun: bun.Environment.reported_nodejs_version
        return NapiNodeVersion(
            major: 20,
            minor: 11,
            patch: 0,
            release: "node"
        )
    }

    public func toString(): String {
        return "${major}.${minor}.${patch}"
    }
}

// ============================================================================
// napi_module - 模块注册结构
// 对应 Bun: napi.zig - struct_napi_module
// ============================================================================

/// N-API 模块结构
/// 对应 C: napi_module struct
/// 对应 Bun: struct_napi_module (napi.zig)
public class NapiModule {
    /// 模块版本号
    public var nmVersion: Int32
    /// 模块标志
    public var nmFlags: UInt32
    /// 模块文件名
    public var nmFilename: ?String = None
    /// 模块注册函数
    public var nmRegisterFunc: ?NapiAddonRegisterFunc = None
    /// 模块名称
    public var nmModname: ?String = None
    /// 模块私有数据
    public var nmPriv: ?Any = None
    /// 保留字段
    public var reserved: Array<?Any> = Array<?Any>(4, item: None)

    public init() {
        this.nmVersion = NapiModule.NAPI_MODULE_VERSION
        this.nmFlags = 0
    }

    /// NAPI_MODULE_VERSION 常量
/// 对应 C: #define NAPI_MODULE_VERSION 1
    public static let NAPI_MODULE_VERSION: Int32 = 1
}

/// 模块注册函数类型
/// 对应 C: typedef napi_value (*napi_addon_register_func)(napi_env env, napi_value exports)
/// 对应 Bun: napi_addon_register_func (napi.zig)
public type NapiAddonRegisterFunc = (NapiEnv, NapiValue) -> NapiValue
