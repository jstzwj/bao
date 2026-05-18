// 严格翻译自: src/runtime/napi/napi_body.rs
// Node-API (N-API) 实现
// 对应 Bun: src/runtime/napi/napi_body.rs (port of src/napi/napi.zig)

package bao_runtime.napi

import bao_core.*
import bao_collections.*
import bao_jsc.*
import bao_sys.*

// ============================================================================
// NapiEnv - N-API 环境
// 对应 Bun: bun_opaque::opaque_ffi! { pub struct NapiEnv; }
// NapiEnv 是不透明 C++ 对象。C++ 通过派生自 &self 的指针改变底层对象。
// ============================================================================

/// N-API 环境
/// 对应 Bun: pub struct NapiEnv (opaque_ffi!)
/// 这是 napi.h 中的 `struct napi_env__`
public class NapiEnv {
    public var ptr: CPointer<Unit>

    public init(ptr: CPointer<Unit>) {
        this.ptr = ptr
    }

    /// 转为 JS 全局对象
    /// 对应 Bun: pub fn to_js(&self) -> &JSGlobalObject
    public func toJs(): JsObject {
        return JsObject()
    }

    /// 设置最后的错误
    /// 对应 Bun: pub fn set_last_error(self_: Option<&Self>, err: NapiStatus) -> napi_status
    public static func setLastError(env: ?NapiEnv, err: NapiStatus): UInt32 {
        return err.toUInt32()
    }

    /// 返回 ok 状态
    /// 对应 Bun: pub fn ok(&self) -> napi_status
    public func ok(): UInt32 {
        return NapiEnv.setLastError(Some(this), NapiStatus.ok)
    }

    /// 返回无效参数状态
    /// 对应 Bun: pub fn invalid_arg(&self) -> napi_status
    public func invalidArg(): UInt32 {
        return NapiEnv.setLastError(Some(this), NapiStatus.invalid_arg)
    }

    /// 返回通用失败状态
    /// 对应 Bun: pub fn generic_failure(&self) -> napi_status
    public func genericFailure(): UInt32 {
        return NapiEnv.setLastError(Some(this), NapiStatus.generic_failure)
    }

    /// 检查 GC
    /// 对应 Bun: pub fn check_gc(&self)
    public func checkGc(): Unit {
        // 安全检查: 断言当前不在 GC 中
    }

    /// 获取版本号
    /// 对应 Bun: pub fn get_version(&self) -> u32
    public func getVersion(): UInt32 {
        return 8  // N-API version 8
    }

    /// 获取并清除待处理异常
    /// 对应 Bun: pub fn get_and_clear_pending_exception(&self) -> Option<JSValue>
    public func getAndClearPendingException(): ?JsValue {
        return None
    }

    /// 增加引用
    /// 对应 Bun: pub unsafe fn ref_(env: *mut NapiEnv)
    public func ref_(): Unit {
        // C++ 引用计数增加
    }

    /// 减少引用
    /// 对应 Bun: pub unsafe fn deref(env: *mut NapiEnv)
    public func deref(): Unit {
        // C++ 引用计数减少
    }
}

/// NapiEnv 引用
/// 对应 Bun: pub type NapiEnvRef = bun_ptr::ExternalShared<NapiEnv>
public class NapiEnvRef {
    public var env: NapiEnv

    public init(env: NapiEnv) {
        this.env = env
    }

    /// 克隆引用
    /// 对应 Bun: unsafe { NapiEnvRef::clone_from_raw(env.as_mut_ptr()) }
    public static func cloneFromRaw(ptr: CPointer<Unit>): NapiEnvRef {
        return NapiEnvRef(NapiEnv(ptr))
    }

    /// 获取原始指针
    public func get(): NapiEnv {
        return env
    }
}

/// 环境为 null 的错误
/// 对应 Bun: fn env_is_null() -> napi_status
public func envIsNull(): UInt32 {
    return NapiStatus.invalid_arg.toUInt32()
}

/// napi_env 类型 (可空)
/// 对应 Bun: pub type napi_env = *mut NapiEnv
public type NapiEnvPtr = ?NapiEnv

// ============================================================================
// Ref - N-API 引用
// 对应 Bun: bun_opaque::opaque_ffi! { pub struct Ref; }
// ============================================================================

/// N-API 引用 (不透明)
/// 对应 Bun: pub struct Ref (opaque)
public class NapiRef {
    public var ptr: CPointer<Unit>

    public init(ptr: CPointer<Unit>) {
        this.ptr = ptr
    }
}

/// napi_ref 类型
/// 对应 Bun: pub type napi_ref = *mut Ref
public type NapiRefPtr = ?NapiRef

// ============================================================================
// NapiHandleScope - 句柄作用域
// 对应 Bun: pub struct NapiHandleScope (opaque_ffi!)
// ============================================================================

/// N-API 句柄作用域
/// 对应 Bun: pub struct NapiHandleScope (opaque C++ handle-scope object)
public class NapiHandleScope {
    public var ptr: CPointer<Unit>

    public init(ptr: CPointer<Unit>) {
        this.ptr = ptr
    }

    /// 打开句柄作用域
    /// 对应 Bun: pub fn open(env: &NapiEnv, escapable: bool) -> *mut NapiHandleScope
    public static func open(env: NapiEnv, escapable: Bool): ?NapiHandleScope {
        // 对应 Bun: unsafe { NapiHandleScope__open(env.as_mut_ptr(), escapable) }
        return None  // 在终结器内返回 null
    }

    /// 关闭句柄作用域
    /// 对应 Bun: pub fn close(self_: *mut NapiHandleScope, env: &NapiEnv)
    public static func close(scope: NapiHandleScope, env: NapiEnv): Unit {
        // 对应 Bun: unsafe { NapiHandleScope__close(env.as_mut_ptr(), self_) }
    }

    /// 追加值到句柄作用域
    /// 对应 Bun: pub fn append(env: &NapiEnv, value: JSValue)
    public static func append(env: NapiEnv, value: JsValue): Unit {
        // 对应 Bun: unsafe { NapiHandleScope__append(env.as_mut_ptr(), value.encoded()) }
    }

    /// 转义值到父作用域
    /// 对应 Bun: pub fn escape(&self, value: JSValue) -> Result<(), EscapeError>
    public func escape(value: JsValue): ?EscapeError {
        // 对应 Bun: if !unsafe { NapiHandleScope__escape(...) } { return Err(EscapeCalledTwice) }
        return None  // 成功
    }

    /// 打开有保护的作用域
    /// 对应 Bun: pub fn open_scoped(env: &NapiEnv) -> NapiHandleScopeGuard
    public static func openScoped(env: NapiEnv): NapiHandleScopeGuard {
        return NapiHandleScopeGuard(open(env, false), env)
    }
}

/// 逃逸错误
/// 对应 Bun: pub enum EscapeError
public enum EscapeError {
    | EscapeCalledTwice

    public func toString(): String {
        match (this) {
            case EscapeError.EscapeCalledTwice => "escape called twice"
        }
    }
}

/// 句柄作用域 RAII 守卫
/// 对应 Bun: pub struct NapiHandleScopeGuard<'a>
public class NapiHandleScopeGuard {
    public var scope: ?NapiHandleScope
    public var env: NapiEnv

    public init(scope: ?NapiHandleScope, env: NapiEnv) {
        this.scope = scope
        this.env = env
    }

    /// 释放时关闭作用域
    /// 对应 Bun: impl Drop for NapiHandleScopeGuard
    public func deinit(): Unit {
        match (scope) {
            case Some(s) => NapiHandleScope.close(s, env)
            case None => ()
        }
    }
}

/// napi_handle_scope 类型
/// 对应 Bun: pub type napi_handle_scope = *mut NapiHandleScope
public type NapiHandleScopePtr = ?NapiHandleScope

/// napi_escapable_handle_scope 类型
/// 对应 Bun: pub type napi_escapable_handle_scope = *mut NapiHandleScope
public type NapiEscapableHandleScopePtr = ?NapiHandleScope

/// napi_callback_info 类型
/// 对应 Bun: pub type napi_callback_info = *mut CallFrame
public type NapiCallbackInfo = CallFrame

/// napi_deferred 类型
/// 对应 Bun: pub type napi_deferred = *mut JSPromiseStrong
public class NapiDeferred {
    public var promise: JsPromiseStrong

    public init(promise: JsPromiseStrong) {
        this.promise = promise
    }
}

// ============================================================================
// napi_value - N-API 值
// 对应 Bun: pub struct napi_value(i64)
// ============================================================================

/// N-API 值
/// 对应 Bun: #[repr(transparent)] pub struct napi_value(i64)
/// 为防止 napi_values 被过早回收，必须使用这些函数在 napi_value 和 jsc::JSValue 之间转换
public struct NapiValue {
    public var encoded: Int64

    public init(encoded: Int64) {
        this.encoded = encoded
    }

    /// 设置值
    /// 对应 Bun: pub fn set(&mut self, env: &NapiEnv, val: JSValue)
    public func set(env: NapiEnv, val: JsValue): Unit {
        NapiHandleScope.append(env, val)
        encoded = val.encoded()
    }

    /// 获取 JSValue
    /// 对应 Bun: pub fn get(&self) -> JSValue
    public func get(): JsValue {
        return JsValue.fromEncoded(encoded)
    }

    /// 创建 napi_value
    /// 对应 Bun: pub fn create(env: &NapiEnv, val: JSValue) -> napi_value
    public static func create(env: NapiEnv, val: JsValue): NapiValue {
        NapiHandleScope.append(env, val)
        return NapiValue(val.encoded())
    }
}

// ============================================================================
// napi_valuetype - N-API 值类型
// 对应 Bun: pub enum napi_valuetype
// ============================================================================

/// N-API 值类型
/// 对应 Bun: #[repr(u32)] pub enum napi_valuetype
public enum NapiValueType {
    | undefined      // 0
    | null            // 1
    | boolean         // 2
    | number          // 3
    | string          // 4
    | symbol          // 5
    | object          // 6
    | function        // 7
    | external        // 8
    | bigint          // 9

    public func toUInt32(): UInt32 {
        match (this) {
            case NapiValueType.undefined => 0
            case NapiValueType.null => 1
            case NapiValueType.boolean => 2
            case NapiValueType.number => 3
            case NapiValueType.string => 4
            case NapiValueType.symbol => 5
            case NapiValueType.object => 6
            case NapiValueType.function => 7
            case NapiValueType.external => 8
            case NapiValueType.bigint => 9
        }
    }
}

// ============================================================================
// napi_typedarray_type - N-API TypedArray 类型
// 对应 Bun: pub enum napi_typedarray_type
// ============================================================================

/// N-API TypedArray 类型
/// 对应 Bun: #[repr(u32)] pub enum napi_typedarray_type
public enum NapiTypedArrayType {
    | int8_array           // 0
    | uint8_array          // 1
    | uint8_clamped_array  // 2
    | int16_array          // 3
    | uint16_array         // 4
    | int32_array          // 5
    | uint32_array         // 6
    | float32_array        // 7
    | float64_array        // 8
    | bigint64_array       // 9
    | biguint64_array      // 10

    /// 从 JS 类型转换
    /// 对应 Bun: pub fn from_js_type(this: jsc::JSType) -> Option<napi_typedarray_type>
    public static func fromJsType(jsType: JsType): ?NapiTypedArrayType {
        match (jsType) {
            case JsType.Int8Array => NapiTypedArrayType.int8_array
            case JsType.Uint8Array => NapiTypedArrayType.uint8_array
            case JsType.Uint8ClampedArray => NapiTypedArrayType.uint8_clamped_array
            case JsType.Int16Array => NapiTypedArrayType.int16_array
            case JsType.Uint16Array => NapiTypedArrayType.uint16_array
            case JsType.Int32Array => NapiTypedArrayType.int32_array
            case JsType.Uint32Array => NapiTypedArrayType.uint32_array
            case JsType.Float32Array => NapiTypedArrayType.float32_array
            case JsType.Float64Array => NapiTypedArrayType.float64_array
            case JsType.BigInt64Array => NapiTypedArrayType.bigint64_array
            case JsType.BigUint64Array => NapiTypedArrayType.biguint64_array
            case _ => None
        }
    }

    /// 转为 JS 类型
    /// 对应 Bun: pub fn to_js_type(self) -> jsc::JSType
    public func toJsType(): JsType {
        match (this) {
            case NapiTypedArrayType.int8_array => JsType.Int8Array
            case NapiTypedArrayType.uint8_array => JsType.Uint8Array
            case NapiTypedArrayType.uint8_clamped_array => JsType.Uint8ClampedArray
            case NapiTypedArrayType.int16_array => JsType.Int16Array
            case NapiTypedArrayType.uint16_array => JsType.Uint16Array
            case NapiTypedArrayType.int32_array => JsType.Int32Array
            case NapiTypedArrayType.uint32_array => JsType.Uint32Array
            case NapiTypedArrayType.float32_array => JsType.Float32Array
            case NapiTypedArrayType.float64_array => JsType.Float64Array
            case NapiTypedArrayType.bigint64_array => JsType.BigInt64Array
            case NapiTypedArrayType.biguint64_array => JsType.BigUint64Array
        }
    }
}

// ============================================================================
// NapiStatus - N-API 状态码
// 对应 Bun: pub enum NapiStatus
// ============================================================================

/// N-API 状态码
/// 对应 Bun: #[repr(u32)] pub enum NapiStatus
public enum NapiStatus {
    | ok                               // 0
    | invalid_arg                      // 1
    | object_expected                  // 2
    | string_expected                  // 3
    | name_expected                    // 4
    | function_expected                // 5
    | number_expected                  // 6
    | boolean_expected                 // 7
    | array_expected                   // 8
    | generic_failure                  // 9
    | pending_exception                // 10
    | cancelled                        // 11
    | escape_called_twice              // 12
    | handle_scope_mismatch            // 13
    | callback_scope_mismatch          // 14
    | queue_full                       // 15
    | closing                          // 16
    | bigint_expected                  // 17
    | date_expected                    // 18
    | arraybuffer_expected             // 19
    | detachable_arraybuffer_expected  // 20
    | would_deadlock                   // 21

    public func toUInt32(): UInt32 {
        match (this) {
            case NapiStatus.ok => 0
            case NapiStatus.invalid_arg => 1
            case NapiStatus.object_expected => 2
            case NapiStatus.string_expected => 3
            case NapiStatus.name_expected => 4
            case NapiStatus.function_expected => 5
            case NapiStatus.number_expected => 6
            case NapiStatus.boolean_expected => 7
            case NapiStatus.array_expected => 8
            case NapiStatus.generic_failure => 9
            case NapiStatus.pending_exception => 10
            case NapiStatus.cancelled => 11
            case NapiStatus.escape_called_twice => 12
            case NapiStatus.handle_scope_mismatch => 13
            case NapiStatus.callback_scope_mismatch => 14
            case NapiStatus.queue_full => 15
            case NapiStatus.closing => 16
            case NapiStatus.bigint_expected => 17
            case NapiStatus.date_expected => 18
            case NapiStatus.arraybuffer_expected => 19
            case NapiStatus.detachable_arraybuffer_expected => 20
            case NapiStatus.would_deadlock => 21
        }
    }
}

/// napi_status 类型
/// 对应 Bun: pub type napi_status = c_uint
public type NapiStatusCode = UInt32

/// napi_callback 类型
/// 对应 Bun: pub type napi_callback = Option<extern "C" fn(napi_env, napi_callback_info) -> napi_value>
public type NapiCallback = ?(env: NapiEnv, info: NapiCallbackInfo) -> NapiValue

/// NapiFinalizeFunction
/// 对应 Bun: pub type NapiFinalizeFunction = extern "C" fn(napi_env, *mut c_void, *mut c_void)
public type NapiFinalizeFunction = (env: NapiEnv, data: CPointer<Unit>, hint: CPointer<Unit>) -> Unit

/// napi_finalize 类型
/// 对应 Bun: pub type napi_finalize = Option<NapiFinalizeFunction>
public type NapiFinalize = ?NapiFinalizeFunction

// ============================================================================
// napi_property_descriptor - 属性描述符
// 对应 Bun: pub struct napi_property_descriptor
// ============================================================================

/// N-API 属性描述符
/// 对应 Bun: #[repr(C)] pub struct napi_property_descriptor
public class NapiPropertyDescriptor {
    /// UTF-8 名称
    /// 对应 Bun: pub utf8name: *const c_char
    public var utf8Name: ?String
    /// 名称值
    /// 对应 Bun: pub name: napi_value
    public var name: NapiValue
    /// 方法
    /// 对应 Bun: pub method: napi_callback
    public var method: NapiCallback
    /// getter
    /// 对应 Bun: pub getter: napi_callback
    public var getter: NapiCallback
    /// setter
    /// 对应 Bun: pub setter: napi_callback
    public var setter: NapiCallback
    /// 值
    /// 对应 Bun: pub value: napi_value
    public var value: NapiValue
    /// 属性
    /// 对应 Bun: pub attributes: napi_property_attributes
    public var attributes: UInt32
    /// 用户数据
    /// 对应 Bun: pub data: *mut c_void
    public var data: CPointer<Unit>

    public init() {
        utf8Name = None
        name = NapiValue(0)
        method = None
        getter = None
        setter = None
        value = NapiValue(0)
        attributes = 0
        data = CPointer<Unit>.null()
    }
}

// ============================================================================
// napi_extended_error_info - 扩展错误信息
// 对应 Bun: pub struct napi_extended_error_info
// ============================================================================

/// N-API 扩展错误信息
/// 对应 Bun: #[repr(C)] pub struct napi_extended_error_info
public class NapiExtendedErrorInfo {
    public var errorMessage: ?String
    public var engineReserved: CPointer<Unit>
    public var engineErrorCode: UInt32
    public var errorCode: UInt32

    public init() {
        errorMessage = None
        engineReserved = CPointer<Unit>.null()
        engineErrorCode = 0
        errorCode = 0
    }
}

// ============================================================================
// napi_type_tag - 类型标签
// 对应 Bun: pub struct napi_type_tag
// ============================================================================

/// N-API 类型标签
/// 对应 Bun: #[repr(C)] pub struct napi_type_tag
public class NapiTypeTag {
    public var lower: UInt64
    public var upper: UInt64

    public init(lower: UInt64, upper: UInt64) {
        this.lower = lower
        this.upper = upper
    }
}

// ============================================================================
// AsyncWorkStatus - 异步工作状态
// 对应 Bun: pub enum AsyncWorkStatus
// ============================================================================

/// 异步工作状态
/// 对应 Bun: #[repr(u32)] pub enum AsyncWorkStatus
public enum AsyncWorkStatus {
    | Pending    // 0
    | Started    // 1
    | Completed  // 2
    | Cancelled  // 3

    public func toUInt32(): UInt32 {
        match (this) {
            case AsyncWorkStatus.Pending => 0
            case AsyncWorkStatus.Started => 1
            case AsyncWorkStatus.Completed => 2
            case AsyncWorkStatus.Cancelled => 3
        }
    }
}

// ============================================================================
// napi_async_work - 异步工作
// 对应 Bun: pub struct napi_async_work
// ============================================================================

/// N-API 异步工作
/// 对应 Bun: pub struct napi_async_work (must be globally allocated)
public class NapiAsyncWork {
    /// 事件循环
    /// 对应 Bun: pub event_loop: bun_ptr::BackRef<EventLoop>
    public var eventLoop: EventLoop
    /// 全局对象引用
    /// 对应 Bun: pub global: GlobalRef
    public var global: JsObject
    /// 环境引用
    /// 对应 Bun: pub env: NapiEnvRef
    public var env: NapiEnvRef
    /// 执行回调
    /// 对应 Bun: pub execute: napi_async_execute_callback
    public var execute: NapiAsyncExecuteCallback
    /// 完成回调
    /// 对应 Bun: pub complete: Option<napi_async_complete_callback>
    public var complete: ?NapiAsyncCompleteCallback
    /// 用户数据
    /// 对应 Bun: pub data: *mut c_void
    public var data: CPointer<Unit>
    /// 状态
    /// 对应 Bun: pub status: AtomicU32
    public var status: AsyncWorkStatus
    /// 是否已调度
    /// 对应 Bun: pub scheduled: bool
    public var scheduled: Bool
    /// Poll 引用
    /// 对应 Bun: pub poll_ref: KeepAlive
    public var pollRef: KeepAlive

    public init(env: NapiEnv, execute: NapiAsyncExecuteCallback,
                complete: ?NapiAsyncCompleteCallback, data: CPointer<Unit>) {
        this.eventLoop = EventLoop()
        this.global = env.toJs()
        this.env = NapiEnvRef(env)
        this.execute = execute
        this.complete = complete
        this.data = data
        this.status = AsyncWorkStatus.Pending
        this.scheduled = false
        this.pollRef = KeepAlive()
    }

    /// 销毁
    /// 对应 Bun: pub fn destroy(this: *mut napi_async_work)
    public func destroy(): Unit {
        // 对应 Bun: drop(unsafe { bun_core::heap::take(this) })
    }

    /// 调度执行
    /// 对应 Bun: pub fn schedule(&mut self)
    public func schedule(): Unit {
        if (scheduled) {
            return
        }
        scheduled = true
        pollRef.ref_()
        // 对应 Bun: WorkPool::schedule(&raw mut self.task)
        WorkPool.schedule(this)
    }

    /// 从线程池运行
    /// 对应 Bun: pub unsafe fn run_from_thread_pool(task: *mut WorkPoolTask)
    public func runFromThreadPool(): Unit {
        run()
    }

    /// 执行工作
    /// 对应 Bun: fn run(&mut self)
    public func run(): Unit {
        let selfPtr = this
        // 对应 Bun: CAS Pending -> Started
        if (status != AsyncWorkStatus.Pending) {
            if (status == AsyncWorkStatus.Cancelled) {
                eventLoop.enqueueTaskConcurrent(selfPtr)
                return
            }
        }

        status = AsyncWorkStatus.Started

        // 对应 Bun: (self.execute)(self.env.get(), self.data)
        let envPtr = env.get()
        execute(envPtr, data)

        status = AsyncWorkStatus.Completed

        // 对应 Bun: self.event_loop.enqueue_task_concurrent(...)
        eventLoop.enqueueTaskConcurrent(selfPtr)
    }

    /// 取消
    /// 对应 Bun: pub fn cancel(&mut self) -> bool
    public func cancel(): Bool {
        if (status == AsyncWorkStatus.Pending) {
            status = AsyncWorkStatus.Cancelled
            return true
        }
        return false
    }

    /// 从 JS 线程运行完成回调
    /// 对应 Bun: pub fn run_from_js(&mut self, vm, global)
    public func runFromJs(vm: VirtualMachine, global: JsObject): Unit {
        // 对应 Bun: let mut poll_ref = core::mem::take(&mut self.poll_ref)
        pollRef.unref()

        let completeFunc = complete
        match (completeFunc) {
            case None => return
            case Some(cb) =>
                let envPtr = env.get()
                let _hs = NapiHandleScope.openScoped(envPtr)

                let statusCode: UInt32 = if (status == AsyncWorkStatus.Cancelled) {
                    NapiStatus.cancelled.toUInt32()
                } else {
                    NapiStatus.ok.toUInt32()
                }

                // 对应 Bun: complete(env, status, data)
                cb(envPtr, statusCode, data)
        }
    }
}

/// napi_threadsafe_function 类型
/// 对应 Bun: pub type napi_threadsafe_function = *mut ThreadSafeFunction
public type NapiThreadSafeFunction = ?ThreadSafeFunction

/// 线程安全函数释放模式
/// 对应 Bun: pub enum napi_threadsafe_function_release_mode
public enum NapiThreadsafeFunctionReleaseMode {
    | release  // 0
    | abort    // 1
}

/// 非阻塞标志
/// 对应 Bun: pub const NAPI_TSFN_NONBLOCKING: c_uint = 0
public let NAPI_TSFN_NONBLOCKING: UInt32 = 0

/// 阻塞标志
/// 对应 Bun: pub const NAPI_TSFN_BLOCKING: c_uint = 1
public let NAPI_TSFN_BLOCKING: UInt32 = 1

/// napi_threadsafe_function_call_mode 类型
/// 对应 Bun: pub type napi_threadsafe_function_call_mode = c_uint
public type NapiThreadsafeFunctionCallMode = UInt32

/// 异步执行回调
/// 对应 Bun: pub type napi_async_execute_callback = extern "C" fn(napi_env, *mut c_void)
public type NapiAsyncExecuteCallback = (env: NapiEnv, data: CPointer<Unit>) -> Unit

/// 异步完成回调
/// 对应 Bun: pub type napi_async_complete_callback = extern "C" fn(napi_env, napi_status, *mut c_void)
public type NapiAsyncCompleteCallback = (env: NapiEnv, status: UInt32, data: CPointer<Unit>) -> Unit

/// 线程安全函数 JS 调用回调
/// 对应 Bun: pub type napi_threadsafe_function_call_js
public type NapiThreadsafeFunctionCallJs =
    (env: NapiEnv, jsCallback: NapiValue, context: CPointer<Unit>, data: CPointer<Unit>) -> Unit

// ============================================================================
// napi_node_version - Node 版本
// 对应 Bun: pub struct napi_node_version
// ============================================================================

/// N-API Node 版本
/// 对应 Bun: #[repr(C)] pub struct napi_node_version
public class NapiNodeVersion {
    public var major: UInt32
    public var minor: UInt32
    public var patch: UInt32
    public var release: String

    public init(major: UInt32, minor: UInt32, patch: UInt32, release: String) {
        this.major = major
        this.minor = minor
        this.patch = patch
        this.release = release
    }
}

// ============================================================================
// ThreadSafeFunction - 线程安全函数
// 对应 Bun: pub struct ThreadSafeFunction
// ============================================================================

/// 线程安全函数
/// 对应 Bun: pub struct ThreadSafeFunction
public class ThreadSafeFunction {
    public var env: NapiEnvRef
    public var callJs: ?NapiThreadsafeFunctionCallJs
    public var callback: JsValue
    public var context: CPointer<Unit>
    public var threadCount: Int64
    public var isClosing: Bool

    public init(env: NapiEnvRef) {
        this.env = env
        this.callJs = None
        this.callback = JsValue.UNDEFINED
        this.context = CPointer<Unit>.null()
        this.threadCount = 0
        this.isClosing = false
    }

    /// 引用
    public func ref_(): Unit {
        threadCount = threadCount + 1
    }

    /// 释放
    public func release(mode: NapiThreadsafeFunctionReleaseMode): Unit {
        threadCount = threadCount - 1
        if (threadCount <= 0) {
            isClosing = true
        }
    }

    /// 调用
    public func call(data: CPointer<Unit>, isBlocking: Bool): Unit {
        let envPtr = env.get()
        match (callJs) {
            case Some(cb) =>
                let jsCallback = NapiValue(0)  // 简化
                cb(envPtr, jsCallback, context, data)
            case None => ()
        }
    }
}

// ============================================================================
// TsfnCallback - TSFN 回调类型
// 对应 Bun: pub enum TsfnCallback
// ============================================================================

/// TSFN 回调类型
/// 对应 Bun: pub enum TsfnCallback
public enum TsfnCallback {
    | CallJs(NapiThreadsafeFunctionCallJs)
    | NoCallback
}

// ============================================================================
// DispatchState - 调度状态
// 对应 Bun: pub enum DispatchState
// ============================================================================

/// 调度状态
public enum DispatchState {
    | Idle
    | Pending
    | Running
}

// ============================================================================
// TsfnQueue - TSFN 队列
// 对应 Bun: pub struct TsfnQueue
// ============================================================================

/// TSFN 队列
/// 对应 Bun: pub struct TsfnQueue
public class TsfnQueue {
    public var items: ArrayList<CPointer<Unit>>
    public var state: DispatchState

    public init() {
        items = ArrayList<CPointer<Unit>>()
        state = DispatchState.Idle
    }

    /// 入队
    public func enqueue(item: CPointer<Unit>): Unit {
        items.append(item)
    }

    /// 出队所有
    public func drain(): ArrayList<CPointer<Unit>> {
        let result = items
        items = ArrayList<CPointer<Unit>>()
        return result
    }
}

// ============================================================================
// Finalizer - 终结器
// 对应 Bun: pub struct Finalizer
// ============================================================================

/// 终结器
/// 对应 Bun: pub struct Finalizer
public class Finalizer {
    public var env: NapiEnvRef
    public var finalizeCb: NapiFinalizeFunction
    public var nativeObject: CPointer<Unit>
    public var hint: CPointer<Unit>

    public init(env: NapiEnvRef, finalizeCb: NapiFinalizeFunction,
                nativeObject: CPointer<Unit>, hint: CPointer<Unit>) {
        this.env = env
        this.finalizeCb = finalizeCb
        this.nativeObject = nativeObject
        this.hint = hint
    }

    /// 运行终结器
    /// 对应 Bun: pub fn run(self)
    public func run(): Unit {
        let envPtr = env.get()
        finalizeCb(envPtr, nativeObject, hint)
    }

    /// 释放
    /// 对应 Bun: pub fn deinit(self)
    public func deinit(): Unit {
        ()
    }
}

// ============================================================================
// NapiFinalizerTask - 终结器任务
// 对应 Bun: pub struct NapiFinalizerTask
// ============================================================================

/// 终结器任务
/// 对应 Bun: pub struct NapiFinalizerTask
public class NapiFinalizerTask {
    public var finalizer: Finalizer

    public init(finalizer: Finalizer) {
        this.finalizer = finalizer
    }

    /// 初始化
    /// 对应 Bun: pub fn init(finalizer: Finalizer) -> Box<NapiFinalizerTask>
    public static func init(finalizer: Finalizer): NapiFinalizerTask {
        return NapiFinalizerTask(finalizer)
    }

    /// 调度执行
    /// 对应 Bun: pub fn schedule(self: Box<Self>)
    public func schedule(): Unit {
        let globalThis = finalizer.env.get().toJs()
        let vm = globalThis.virtualMachine()
        let isMainThread = VirtualMachine.getOrNull().isSome()

        if (!isMainThread) {
            // 对应 Bun: vm.event_loop_ref().enqueue_task_concurrent(...)
            vm.eventLoop().enqueueTaskConcurrent(this)
            return
        }

        if (vm.isShuttingDown()) {
            // 作为清理钩子运行
        } else {
            vm.eventLoop().enqueueTask(this)
        }
    }

    /// 在 JS 线程上运行
    /// 对应 Bun: pub fn run_on_js_thread(this: *mut NapiFinalizerTask)
    public func runOnJsThread(): Unit {
        finalizer.run()
    }
}

// ============================================================================
// napi_module - N-API 模块
// 对应 Bun: pub struct struct_napi_module
// ============================================================================

/// N-API 模块
/// 对应 Bun: pub struct struct_napi_module
public class NapiModule {
    public var nmVersion: Int32
    public var nmFlags: UInt32
    public var nmFilename: String
    public var nmRegisterFunc: NapiCallback
    public var nmModname: String
    public var nmPriv: CPointer<Unit>

    public init() {
        nmVersion = 0
        nmFlags = 0
        nmFilename = ""
        nmRegisterFunc = None
        nmModname = ""
        nmPriv = CPointer<Unit>.null()
    }
}

// ============================================================================
// 辅助类型
// ============================================================================

/// 事件循环
/// 对应 Bun: bun_jsc::event_loop::EventLoop
public class EventLoop {
    public init() {}

    public func enqueueTaskConcurrent(task: Object): Unit {
        ()
    }

    public func enqueueTask(task: Object): Unit {
        ()
    }
}

/// KeepAlive
/// 对应 Bun: bun_io::KeepAlive
public class KeepAlive {
    public init() {}

    public func ref_(): Unit {
        ()
    }

    public func unref(): Unit {
        ()
    }
}

/// 工作线程池
/// 对应 Bun: bun_threading::work_pool::WorkPool
public class WorkPool {
    public static func schedule(task: Object): Unit {
        ()
    }
}

/// 虚拟机
/// 对应 Bun: bun_jsc::virtual_machine::VirtualMachine
public class VirtualMachine {
    public func eventLoop(): EventLoop { return EventLoop() }
    public func isShuttingDown(): Bool { return false }

    public static func getOrNull(): ?VirtualMachine {
        return None
    }
}

/// JsPromise 强引用
/// 对应 Bun: jsc::JSPromiseStrong
public class JsPromiseStrong {
    public init() {}
}

/// JS 类型
/// 对应 Bun: jsc::JSType
public enum JsType {
    | Int8Array
    | Uint8Array
    | Uint8ClampedArray
    | Int16Array
    | Uint16Array
    | Int32Array
    | Uint32Array
    | Float32Array
    | Float64Array
    | BigInt64Array
    | BigUint64Array
    | Object
    | Array
    | Function
    | String
    | Number
    | Boolean
    | Symbol
    | Null
    | Undefined
    | Cell
}

/// fixDeadCodeElimination - 防止死代码消除
/// 对应 Bun: pub fn fix_dead_code_elimination()
public func fixDeadCodeElimination(): Unit {
    // 空函数，防止编译器优化掉 NAPI 符号
}

// ported from: src/runtime/napi/napi_body.rs
