// node_api_napi.cj - Node-API C ABI declarations
// 翻译自 Bun 源文件: src/runtime/napi/js_native_api_types.h, js_native_api.h,
// src/runtime/napi/node_api_types.h, node_api.h
//
// 本文件保留 C 头文件层的 ABI 形状：opaque handle、@C struct、常量、foreign func
// 声明。高层 Cangjie 包装实现仍位于 js_native_api.cj / node_api.cj / napi.cj。

package bao_runtime.napi

// ============================================================================
// C ABI opaque handles
// 对应 Bun: js_native_api_types.h / node_api_types.h forward declarations
// ============================================================================

@C
public struct NapiEnvOpaque { var _opaque: UInt64 }
@C
public struct NapiValueOpaque { var _opaque: UInt64 }
@C
public struct NapiRefOpaque { var _opaque: UInt64 }
@C
public struct NapiHandleScopeOpaque { var _opaque: UInt64 }
@C
public struct NapiEscapableHandleScopeOpaque { var _opaque: UInt64 }
@C
public struct NapiCallbackInfoOpaque { var _opaque: UInt64 }
@C
public struct NapiDeferredOpaque { var _opaque: UInt64 }
@C
public struct NapiCallbackScopeOpaque { var _opaque: UInt64 }
@C
public struct NapiAsyncContextOpaque { var _opaque: UInt64 }
@C
public struct NapiAsyncWorkOpaque { var _opaque: UInt64 }
@C
public struct NapiThreadsafeFunctionOpaque { var _opaque: UInt64 }
@C
public struct NapiAsyncCleanupHookHandleOpaque { var _opaque: UInt64 }
@C
public struct UvLoopOpaque { var _opaque: UInt64 }

public type napi_env = CPointer<NapiEnvOpaque>
public type napi_value = CPointer<NapiValueOpaque>
public type napi_ref = CPointer<NapiRefOpaque>
public type napi_handle_scope = CPointer<NapiHandleScopeOpaque>
public type napi_escapable_handle_scope = CPointer<NapiEscapableHandleScopeOpaque>
public type napi_callback_info = CPointer<NapiCallbackInfoOpaque>
public type napi_deferred = CPointer<NapiDeferredOpaque>
public type napi_callback_scope = CPointer<NapiCallbackScopeOpaque>
public type napi_async_context = CPointer<NapiAsyncContextOpaque>
public type napi_async_work = CPointer<NapiAsyncWorkOpaque>
public type napi_threadsafe_function = CPointer<NapiThreadsafeFunctionOpaque>
public type napi_async_cleanup_hook_handle = CPointer<NapiAsyncCleanupHookHandleOpaque>
public type uv_loop_s = UvLoopOpaque

public type napi_status = UInt32
public type napi_property_attributes = UInt32
public type napi_valuetype = UInt32
public type napi_typedarray_type = UInt32
public type napi_key_collection_mode = UInt32
public type napi_key_filter = UInt32
public type napi_key_conversion = UInt32
public type napi_threadsafe_function_release_mode = UInt32
public type napi_threadsafe_function_call_mode = UInt32

// Function-pointer typedefs from headers. Cangjie cannot express a raw C function
// pointer typedef portably in the current codebase style, so callbacks are stored
// and passed as opaque pointers at the ABI boundary.
public type napi_callback = CPointer<Unit>
public type napi_finalize = CPointer<Unit>
public type napi_async_execute_callback = CPointer<Unit>
public type napi_async_complete_callback = CPointer<Unit>
public type napi_threadsafe_function_call_js = CPointer<Unit>
public type napi_async_cleanup_hook = CPointer<Unit>
public type napi_addon_register_func = CPointer<Unit>
public type napi_env_cleanup_hook = CPointer<Unit>

// ============================================================================
// Constants / enum values from js_native_api_types.h and node_api_types.h
// ============================================================================

public let NAPI_VERSION_EXPERIMENTAL_C: Int32 = 2147483647
public let NAPI_VERSION_C: UInt32 = 10
public let NAPI_AUTO_LENGTH_C: UIntNative = UIntNative(-1)
public let NAPI_MODULE_VERSION_C: Int32 = 1

public let napi_default: UInt32 = 0
public let napi_writable: UInt32 = 1
public let napi_enumerable: UInt32 = 2
public let napi_configurable: UInt32 = 4
public let napi_static: UInt32 = 1024
public let napi_default_method: UInt32 = napi_writable | napi_configurable
public let napi_default_jsproperty: UInt32 = napi_writable | napi_enumerable | napi_configurable

public let napi_undefined: UInt32 = 0
public let napi_null: UInt32 = 1
public let napi_boolean: UInt32 = 2
public let napi_number: UInt32 = 3
public let napi_string: UInt32 = 4
public let napi_symbol: UInt32 = 5
public let napi_object: UInt32 = 6
public let napi_function: UInt32 = 7
public let napi_external: UInt32 = 8
public let napi_bigint: UInt32 = 9

public let napi_int8_array: UInt32 = 0
public let napi_uint8_array: UInt32 = 1
public let napi_uint8_clamped_array: UInt32 = 2
public let napi_int16_array: UInt32 = 3
public let napi_uint16_array: UInt32 = 4
public let napi_int32_array: UInt32 = 5
public let napi_uint32_array: UInt32 = 6
public let napi_float32_array: UInt32 = 7
public let napi_float64_array: UInt32 = 8
public let napi_bigint64_array: UInt32 = 9
public let napi_biguint64_array: UInt32 = 10

public let napi_ok: UInt32 = 0
public let napi_invalid_arg: UInt32 = 1
public let napi_object_expected: UInt32 = 2
public let napi_string_expected: UInt32 = 3
public let napi_name_expected: UInt32 = 4
public let napi_function_expected: UInt32 = 5
public let napi_number_expected: UInt32 = 6
public let napi_boolean_expected: UInt32 = 7
public let napi_array_expected: UInt32 = 8
public let napi_generic_failure: UInt32 = 9
public let napi_pending_exception: UInt32 = 10
public let napi_cancelled: UInt32 = 11
public let napi_escape_called_twice: UInt32 = 12
public let napi_handle_scope_mismatch: UInt32 = 13
public let napi_callback_scope_mismatch: UInt32 = 14
public let napi_queue_full: UInt32 = 15
public let napi_closing: UInt32 = 16
public let napi_bigint_expected: UInt32 = 17
public let napi_date_expected: UInt32 = 18
public let napi_arraybuffer_expected: UInt32 = 19
public let napi_detachable_arraybuffer_expected: UInt32 = 20
public let napi_would_deadlock: UInt32 = 21
public let napi_no_external_buffers_allowed: UInt32 = 22
public let napi_cannot_run_js: UInt32 = 23

public let napi_key_include_prototypes: UInt32 = 0
public let napi_key_own_only: UInt32 = 1
public let napi_key_all_properties: UInt32 = 0
public let napi_key_writable: UInt32 = 1
public let napi_key_enumerable: UInt32 = 2
public let napi_key_configurable: UInt32 = 4
public let napi_key_skip_strings: UInt32 = 8
public let napi_key_skip_symbols: UInt32 = 16
public let napi_key_keep_numbers: UInt32 = 0
public let napi_key_numbers_to_strings: UInt32 = 1

public let napi_tsfn_release: UInt32 = 0
public let napi_tsfn_abort: UInt32 = 1
public let napi_tsfn_nonblocking: UInt32 = 0
public let napi_tsfn_blocking: UInt32 = 1

// ============================================================================
// @C structs from public headers
// ============================================================================

@C
public struct napi_property_descriptor {
    var utf8name: CPointer<Byte>
    var name: napi_value
    var method: napi_callback
    var getter: napi_callback
    var setter: napi_callback
    var value: napi_value
    var attributes: napi_property_attributes
    var data: CPointer<Unit>
}

@C
public struct napi_extended_error_info {
    var error_message: CPointer<Byte>
    var engine_reserved: CPointer<Unit>
    var engine_error_code: UInt32
    var error_code: napi_status
}

@C
public struct napi_type_tag {
    var lower: UInt64
    var upper: UInt64
}

@C
public struct napi_node_version {
    var major: UInt32
    var minor: UInt32
    var patch: UInt32
    var release: CPointer<Byte>
}

@C
public struct napi_module {
    var nm_version: Int32
    var nm_flags: UInt32
    var nm_filename: CPointer<Byte>
    var nm_register_func: napi_addon_register_func
    var nm_modname: CPointer<Byte>
    var nm_priv: CPointer<Unit>
    var reserved0: CPointer<Unit>
    var reserved1: CPointer<Unit>
    var reserved2: CPointer<Unit>
    var reserved3: CPointer<Unit>
}

// ============================================================================
// js_native_api.h foreign declarations
// ============================================================================

@C foreign func napi_get_last_error_info(env: napi_env, result: CPointer<CPointer<napi_extended_error_info>>): napi_status
@C foreign func napi_get_undefined(env: napi_env, result: CPointer<napi_value>): napi_status
@C foreign func napi_get_null(env: napi_env, result: CPointer<napi_value>): napi_status
@C foreign func napi_get_global(env: napi_env, result: CPointer<napi_value>): napi_status
@C foreign func napi_get_boolean(env: napi_env, value: Bool, result: CPointer<napi_value>): napi_status
@C foreign func napi_create_object(env: napi_env, result: CPointer<napi_value>): napi_status
@C foreign func napi_create_array(env: napi_env, result: CPointer<napi_value>): napi_status
@C foreign func napi_create_array_with_length(env: napi_env, length: UIntNative, result: CPointer<napi_value>): napi_status
@C foreign func napi_create_double(env: napi_env, value: Float64, result: CPointer<napi_value>): napi_status
@C foreign func napi_create_int32(env: napi_env, value: Int32, result: CPointer<napi_value>): napi_status
@C foreign func napi_create_uint32(env: napi_env, value: UInt32, result: CPointer<napi_value>): napi_status
@C foreign func napi_create_int64(env: napi_env, value: Int64, result: CPointer<napi_value>): napi_status
@C foreign func napi_create_string_latin1(env: napi_env, str: CPointer<Byte>, length: UIntNative, result: CPointer<napi_value>): napi_status
@C foreign func napi_create_string_utf8(env: napi_env, str: CPointer<Byte>, length: UIntNative, result: CPointer<napi_value>): napi_status
@C foreign func napi_create_string_utf16(env: napi_env, str: CPointer<UInt16>, length: UIntNative, result: CPointer<napi_value>): napi_status
@C foreign func napi_create_symbol(env: napi_env, description: napi_value, result: CPointer<napi_value>): napi_status
@C foreign func node_api_symbol_for(env: napi_env, utf8description: CPointer<Byte>, length: UIntNative, result: CPointer<napi_value>): napi_status
@C foreign func napi_create_function(env: napi_env, utf8name: CPointer<Byte>, length: UIntNative, cb: napi_callback, data: CPointer<Unit>, result: CPointer<napi_value>): napi_status
@C foreign func napi_create_error(env: napi_env, code: napi_value, msg: napi_value, result: CPointer<napi_value>): napi_status
@C foreign func napi_create_type_error(env: napi_env, code: napi_value, msg: napi_value, result: CPointer<napi_value>): napi_status
@C foreign func napi_create_range_error(env: napi_env, code: napi_value, msg: napi_value, result: CPointer<napi_value>): napi_status
@C foreign func node_api_create_syntax_error(env: napi_env, code: napi_value, msg: napi_value, result: CPointer<napi_value>): napi_status
@C foreign func napi_typeof(env: napi_env, value: napi_value, result: CPointer<napi_valuetype>): napi_status
@C foreign func napi_get_value_double(env: napi_env, value: napi_value, result: CPointer<Float64>): napi_status
@C foreign func napi_get_value_int32(env: napi_env, value: napi_value, result: CPointer<Int32>): napi_status
@C foreign func napi_get_value_uint32(env: napi_env, value: napi_value, result: CPointer<UInt32>): napi_status
@C foreign func napi_get_value_int64(env: napi_env, value: napi_value, result: CPointer<Int64>): napi_status
@C foreign func napi_get_value_bool(env: napi_env, value: napi_value, result: CPointer<Bool>): napi_status
@C foreign func napi_get_value_string_latin1(env: napi_env, value: napi_value, buf: CPointer<Byte>, bufsize: UIntNative, result: CPointer<UIntNative>): napi_status
@C foreign func napi_get_value_string_utf8(env: napi_env, value: napi_value, buf: CPointer<Byte>, bufsize: UIntNative, result: CPointer<UIntNative>): napi_status
@C foreign func napi_get_value_string_utf16(env: napi_env, value: napi_value, buf: CPointer<UInt16>, bufsize: UIntNative, result: CPointer<UIntNative>): napi_status
@C foreign func napi_coerce_to_bool(env: napi_env, value: napi_value, result: CPointer<napi_value>): napi_status
@C foreign func napi_coerce_to_number(env: napi_env, value: napi_value, result: CPointer<napi_value>): napi_status
@C foreign func napi_coerce_to_object(env: napi_env, value: napi_value, result: CPointer<napi_value>): napi_status
@C foreign func napi_coerce_to_string(env: napi_env, value: napi_value, result: CPointer<napi_value>): napi_status
@C foreign func napi_get_prototype(env: napi_env, object: napi_value, result: CPointer<napi_value>): napi_status
@C foreign func napi_get_property_names(env: napi_env, object: napi_value, result: CPointer<napi_value>): napi_status
@C foreign func napi_set_property(env: napi_env, object: napi_value, key: napi_value, value: napi_value): napi_status
@C foreign func napi_has_property(env: napi_env, object: napi_value, key: napi_value, result: CPointer<Bool>): napi_status
@C foreign func napi_get_property(env: napi_env, object: napi_value, key: napi_value, result: CPointer<napi_value>): napi_status
@C foreign func napi_delete_property(env: napi_env, object: napi_value, key: napi_value, result: CPointer<Bool>): napi_status
@C foreign func napi_has_own_property(env: napi_env, object: napi_value, key: napi_value, result: CPointer<Bool>): napi_status
@C foreign func napi_set_named_property(env: napi_env, object: napi_value, utf8name: CPointer<Byte>, value: napi_value): napi_status
@C foreign func napi_has_named_property(env: napi_env, object: napi_value, utf8name: CPointer<Byte>, result: CPointer<Bool>): napi_status
@C foreign func napi_get_named_property(env: napi_env, object: napi_value, utf8name: CPointer<Byte>, result: CPointer<napi_value>): napi_status
@C foreign func napi_set_element(env: napi_env, object: napi_value, index: UInt32, value: napi_value): napi_status
@C foreign func napi_has_element(env: napi_env, object: napi_value, index: UInt32, result: CPointer<Bool>): napi_status
@C foreign func napi_get_element(env: napi_env, object: napi_value, index: UInt32, result: CPointer<napi_value>): napi_status
@C foreign func napi_delete_element(env: napi_env, object: napi_value, index: UInt32, result: CPointer<Bool>): napi_status
@C foreign func napi_define_properties(env: napi_env, object: napi_value, property_count: UIntNative, properties: CPointer<napi_property_descriptor>): napi_status
@C foreign func napi_is_array(env: napi_env, value: napi_value, result: CPointer<Bool>): napi_status
@C foreign func napi_get_array_length(env: napi_env, value: napi_value, result: CPointer<UInt32>): napi_status
@C foreign func napi_strict_equals(env: napi_env, lhs: napi_value, rhs: napi_value, result: CPointer<Bool>): napi_status
@C foreign func napi_call_function(env: napi_env, recv: napi_value, func_: napi_value, argc: UIntNative, argv: CPointer<napi_value>, result: CPointer<napi_value>): napi_status
@C foreign func napi_new_instance(env: napi_env, constructor: napi_value, argc: UIntNative, argv: CPointer<napi_value>, result: CPointer<napi_value>): napi_status
@C foreign func napi_instanceof(env: napi_env, object: napi_value, constructor: napi_value, result: CPointer<Bool>): napi_status
@C foreign func napi_get_cb_info(env: napi_env, cbinfo: napi_callback_info, argc: CPointer<UIntNative>, argv: CPointer<napi_value>, this_arg: CPointer<napi_value>, data: CPointer<CPointer<Unit>>): napi_status
@C foreign func napi_get_new_target(env: napi_env, cbinfo: napi_callback_info, result: CPointer<napi_value>): napi_status
@C foreign func napi_define_class(env: napi_env, utf8name: CPointer<Byte>, length: UIntNative, constructor: napi_callback, data: CPointer<Unit>, property_count: UIntNative, properties: CPointer<napi_property_descriptor>, result: CPointer<napi_value>): napi_status
@C foreign func napi_wrap(env: napi_env, js_object: napi_value, native_object: CPointer<Unit>, finalize_cb: napi_finalize, finalize_hint: CPointer<Unit>, result: CPointer<napi_ref>): napi_status
@C foreign func napi_unwrap(env: napi_env, js_object: napi_value, result: CPointer<CPointer<Unit>>): napi_status
@C foreign func napi_remove_wrap(env: napi_env, js_object: napi_value, result: CPointer<CPointer<Unit>>): napi_status
@C foreign func napi_create_external(env: napi_env, data: CPointer<Unit>, finalize_cb: napi_finalize, finalize_hint: CPointer<Unit>, result: CPointer<napi_value>): napi_status
@C foreign func napi_get_value_external(env: napi_env, value: napi_value, result: CPointer<CPointer<Unit>>): napi_status
@C foreign func napi_create_reference(env: napi_env, value: napi_value, initial_refcount: UInt32, result: CPointer<napi_ref>): napi_status
@C foreign func napi_delete_reference(env: napi_env, ref: napi_ref): napi_status
@C foreign func napi_reference_ref(env: napi_env, ref: napi_ref, result: CPointer<UInt32>): napi_status
@C foreign func napi_reference_unref(env: napi_env, ref: napi_ref, result: CPointer<UInt32>): napi_status
@C foreign func napi_get_reference_value(env: napi_env, ref: napi_ref, result: CPointer<napi_value>): napi_status
@C foreign func napi_open_handle_scope(env: napi_env, result: CPointer<napi_handle_scope>): napi_status
@C foreign func napi_close_handle_scope(env: napi_env, scope: napi_handle_scope): napi_status
@C foreign func napi_open_escapable_handle_scope(env: napi_env, result: CPointer<napi_escapable_handle_scope>): napi_status
@C foreign func napi_close_escapable_handle_scope(env: napi_env, scope: napi_escapable_handle_scope): napi_status
@C foreign func napi_escape_handle(env: napi_env, scope: napi_escapable_handle_scope, escapee: napi_value, result: CPointer<napi_value>): napi_status
@C foreign func napi_throw(env: napi_env, error: napi_value): napi_status
@C foreign func napi_throw_error(env: napi_env, code: CPointer<Byte>, msg: CPointer<Byte>): napi_status
@C foreign func napi_throw_type_error(env: napi_env, code: CPointer<Byte>, msg: CPointer<Byte>): napi_status
@C foreign func napi_throw_range_error(env: napi_env, code: CPointer<Byte>, msg: CPointer<Byte>): napi_status
@C foreign func node_api_throw_syntax_error(env: napi_env, code: CPointer<Byte>, msg: CPointer<Byte>): napi_status
@C foreign func napi_is_error(env: napi_env, value: napi_value, result: CPointer<Bool>): napi_status
@C foreign func napi_is_exception_pending(env: napi_env, result: CPointer<Bool>): napi_status
@C foreign func napi_get_and_clear_last_exception(env: napi_env, result: CPointer<napi_value>): napi_status
@C foreign func napi_is_arraybuffer(env: napi_env, value: napi_value, result: CPointer<Bool>): napi_status
@C foreign func napi_create_arraybuffer(env: napi_env, byte_length: UIntNative, data: CPointer<CPointer<Unit>>, result: CPointer<napi_value>): napi_status
@C foreign func napi_create_external_arraybuffer(env: napi_env, external_data: CPointer<Unit>, byte_length: UIntNative, finalize_cb: napi_finalize, finalize_hint: CPointer<Unit>, result: CPointer<napi_value>): napi_status
@C foreign func napi_get_arraybuffer_info(env: napi_env, arraybuffer: napi_value, data: CPointer<CPointer<Unit>>, byte_length: CPointer<UIntNative>): napi_status
@C foreign func napi_is_typedarray(env: napi_env, value: napi_value, result: CPointer<Bool>): napi_status
@C foreign func napi_create_typedarray(env: napi_env, type_: napi_typedarray_type, length: UIntNative, arraybuffer: napi_value, byte_offset: UIntNative, result: CPointer<napi_value>): napi_status
@C foreign func napi_get_typedarray_info(env: napi_env, typedarray: napi_value, type_: CPointer<napi_typedarray_type>, length: CPointer<UIntNative>, data: CPointer<CPointer<Unit>>, arraybuffer: CPointer<napi_value>, byte_offset: CPointer<UIntNative>): napi_status
@C foreign func napi_create_dataview(env: napi_env, length: UIntNative, arraybuffer: napi_value, byte_offset: UIntNative, result: CPointer<napi_value>): napi_status
@C foreign func napi_is_dataview(env: napi_env, value: napi_value, result: CPointer<Bool>): napi_status
@C foreign func napi_get_dataview_info(env: napi_env, dataview: napi_value, bytelength: CPointer<UIntNative>, data: CPointer<CPointer<Unit>>, arraybuffer: CPointer<napi_value>, byte_offset: CPointer<UIntNative>): napi_status
@C foreign func napi_get_version(env: napi_env, result: CPointer<UInt32>): napi_status
@C foreign func napi_create_promise(env: napi_env, deferred: CPointer<napi_deferred>, promise: CPointer<napi_value>): napi_status
@C foreign func napi_resolve_deferred(env: napi_env, deferred: napi_deferred, resolution: napi_value): napi_status
@C foreign func napi_reject_deferred(env: napi_env, deferred: napi_deferred, rejection: napi_value): napi_status
@C foreign func napi_is_promise(env: napi_env, value: napi_value, is_promise: CPointer<Bool>): napi_status
@C foreign func napi_run_script(env: napi_env, script: napi_value, result: CPointer<napi_value>): napi_status
@C foreign func napi_adjust_external_memory(env: napi_env, change_in_bytes: Int64, adjusted_value: CPointer<Int64>): napi_status
@C foreign func napi_create_date(env: napi_env, time: Float64, result: CPointer<napi_value>): napi_status
@C foreign func napi_is_date(env: napi_env, value: napi_value, is_date: CPointer<Bool>): napi_status
@C foreign func napi_get_date_value(env: napi_env, value: napi_value, result: CPointer<Float64>): napi_status
@C foreign func napi_add_finalizer(env: napi_env, js_object: napi_value, native_object: CPointer<Unit>, finalize_cb: napi_finalize, finalize_hint: CPointer<Unit>, result: CPointer<napi_ref>): napi_status
@C foreign func napi_create_bigint_int64(env: napi_env, value: Int64, result: CPointer<napi_value>): napi_status
@C foreign func napi_create_bigint_uint64(env: napi_env, value: UInt64, result: CPointer<napi_value>): napi_status
@C foreign func napi_create_bigint_words(env: napi_env, sign_bit: Int32, word_count: UIntNative, words: CPointer<UInt64>, result: CPointer<napi_value>): napi_status
@C foreign func napi_get_value_bigint_int64(env: napi_env, value: napi_value, result: CPointer<Int64>, lossless: CPointer<Bool>): napi_status
@C foreign func napi_get_value_bigint_uint64(env: napi_env, value: napi_value, result: CPointer<UInt64>, lossless: CPointer<Bool>): napi_status
@C foreign func napi_get_value_bigint_words(env: napi_env, value: napi_value, sign_bit: CPointer<Int32>, word_count: CPointer<UIntNative>, words: CPointer<UInt64>): napi_status
@C foreign func napi_get_all_property_names(env: napi_env, object: napi_value, key_mode: napi_key_collection_mode, key_filter: napi_key_filter, key_conversion: napi_key_conversion, result: CPointer<napi_value>): napi_status
@C foreign func napi_set_instance_data(env: napi_env, data: CPointer<Unit>, finalize_cb: napi_finalize, finalize_hint: CPointer<Unit>): napi_status
@C foreign func napi_get_instance_data(env: napi_env, data: CPointer<CPointer<Unit>>): napi_status
@C foreign func napi_detach_arraybuffer(env: napi_env, arraybuffer: napi_value): napi_status
@C foreign func napi_is_detached_arraybuffer(env: napi_env, value: napi_value, result: CPointer<Bool>): napi_status
@C foreign func napi_type_tag_object(env: napi_env, value: napi_value, type_tag: CPointer<napi_type_tag>): napi_status
@C foreign func napi_check_object_type_tag(env: napi_env, value: napi_value, type_tag: CPointer<napi_type_tag>, result: CPointer<Bool>): napi_status
@C foreign func napi_object_freeze(env: napi_env, object: napi_value): napi_status
@C foreign func napi_object_seal(env: napi_env, object: napi_value): napi_status
@C foreign func node_api_create_external_string_latin1(env: napi_env, str: CPointer<Byte>, length: UIntNative, finalize_callback: napi_finalize, finalize_hint: CPointer<Unit>, result: CPointer<napi_value>, copied: CPointer<Bool>): napi_status
@C foreign func node_api_create_external_string_utf16(env: napi_env, str: CPointer<UInt16>, length: UIntNative, finalize_callback: napi_finalize, finalize_hint: CPointer<Unit>, result: CPointer<napi_value>, copied: CPointer<Bool>): napi_status
@C foreign func node_api_create_property_key_latin1(env: napi_env, str: CPointer<Byte>, length: UIntNative, result: CPointer<napi_value>): napi_status
@C foreign func node_api_create_property_key_utf8(env: napi_env, str: CPointer<Byte>, length: UIntNative, result: CPointer<napi_value>): napi_status
@C foreign func node_api_create_property_key_utf16(env: napi_env, str: CPointer<UInt16>, length: UIntNative, result: CPointer<napi_value>): napi_status

// ============================================================================
// node_api.h foreign declarations
// ============================================================================

@C foreign func napi_module_register(mod: CPointer<napi_module>): Unit
@C foreign func napi_fatal_error(location: CPointer<Byte>, location_len: UIntNative, message: CPointer<Byte>, message_len: UIntNative): Unit
@C foreign func napi_async_init(env: napi_env, async_resource: napi_value, async_resource_name: napi_value, result: CPointer<napi_async_context>): napi_status
@C foreign func napi_async_destroy(env: napi_env, async_context: napi_async_context): napi_status
@C foreign func napi_make_callback(env: napi_env, async_context: napi_async_context, recv: napi_value, func_: napi_value, argc: UIntNative, argv: CPointer<napi_value>, result: CPointer<napi_value>): napi_status
@C foreign func napi_create_buffer(env: napi_env, length: UIntNative, data: CPointer<CPointer<Unit>>, result: CPointer<napi_value>): napi_status
@C foreign func napi_create_external_buffer(env: napi_env, length: UIntNative, data: CPointer<Unit>, finalize_cb: napi_finalize, finalize_hint: CPointer<Unit>, result: CPointer<napi_value>): napi_status
@C foreign func napi_create_buffer_copy(env: napi_env, length: UIntNative, data: CPointer<Unit>, result_data: CPointer<CPointer<Unit>>, result: CPointer<napi_value>): napi_status
@C foreign func napi_is_buffer(env: napi_env, value: napi_value, result: CPointer<Bool>): napi_status
@C foreign func napi_get_buffer_info(env: napi_env, value: napi_value, data: CPointer<CPointer<Unit>>, length: CPointer<UIntNative>): napi_status
@C foreign func napi_create_async_work(env: napi_env, async_resource: napi_value, async_resource_name: napi_value, execute: napi_async_execute_callback, complete: napi_async_complete_callback, data: CPointer<Unit>, result: CPointer<napi_async_work>): napi_status
@C foreign func napi_delete_async_work(env: napi_env, work: napi_async_work): napi_status
@C foreign func napi_queue_async_work(env: napi_env, work: napi_async_work): napi_status
@C foreign func napi_cancel_async_work(env: napi_env, work: napi_async_work): napi_status
@C foreign func napi_get_node_version(env: napi_env, version: CPointer<CPointer<napi_node_version>>): napi_status
@C foreign func napi_get_uv_event_loop(env: napi_env, loop: CPointer<CPointer<uv_loop_s>>): napi_status
@C foreign func napi_fatal_exception(env: napi_env, err: napi_value): napi_status
@C foreign func napi_add_env_cleanup_hook(env: napi_env, fun: napi_env_cleanup_hook, arg: CPointer<Unit>): napi_status
@C foreign func napi_remove_env_cleanup_hook(env: napi_env, fun: napi_env_cleanup_hook, arg: CPointer<Unit>): napi_status
@C foreign func napi_open_callback_scope(env: napi_env, resource_object: napi_value, context: napi_async_context, result: CPointer<napi_callback_scope>): napi_status
@C foreign func napi_close_callback_scope(env: napi_env, scope: napi_callback_scope): napi_status
@C foreign func napi_create_threadsafe_function(env: napi_env, func_: napi_value, async_resource: napi_value, async_resource_name: napi_value, max_queue_size: UIntNative, initial_thread_count: UIntNative, thread_finalize_data: CPointer<Unit>, thread_finalize_cb: napi_finalize, context: CPointer<Unit>, call_js_cb: napi_threadsafe_function_call_js, result: CPointer<napi_threadsafe_function>): napi_status
@C foreign func napi_get_threadsafe_function_context(func_: napi_threadsafe_function, result: CPointer<CPointer<Unit>>): napi_status
@C foreign func napi_call_threadsafe_function(func_: napi_threadsafe_function, data: CPointer<Unit>, is_blocking: napi_threadsafe_function_call_mode): napi_status
@C foreign func napi_acquire_threadsafe_function(func_: napi_threadsafe_function): napi_status
@C foreign func napi_release_threadsafe_function(func_: napi_threadsafe_function, mode: napi_threadsafe_function_release_mode): napi_status
@C foreign func napi_unref_threadsafe_function(env: napi_env, func_: napi_threadsafe_function): napi_status
@C foreign func napi_ref_threadsafe_function(env: napi_env, func_: napi_threadsafe_function): napi_status
@C foreign func napi_add_async_cleanup_hook(env: napi_env, hook: napi_async_cleanup_hook, arg: CPointer<Unit>, remove_handle: CPointer<napi_async_cleanup_hook_handle>): napi_status
@C foreign func napi_remove_async_cleanup_hook(remove_handle: napi_async_cleanup_hook_handle): napi_status
@C foreign func node_api_get_module_file_name(env: napi_env, result: CPointer<CPointer<Byte>>): napi_status
