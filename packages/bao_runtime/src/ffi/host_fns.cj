// FFI 宿主函数 — dlopen/close/compile/generate_symbols 的入口点
// 对应 Bun: src/runtime/ffi/host_fns.rs
// 提供 FFI 宿主函数的未门控实现:
//   - generate_symbol_for_function: 从 JS 值解析单个 FFI 函数描述
//   - generate_symbols: 从 JS 对象解析所有符号映射
//   - Function.compile: 编译 FFI 函数
//   - Function.print_source_code: 生成 C trampoline 源码
//   - Function.print_callback_source_code: 生成回调 C trampoline 源码
//   - make_napi_env_if_needed: 按需创建 NAPI 环境
package bao_runtime.ffi

import bao_core.*
import bao_collections.*

// ============================================================================
// 符号解析 — generate_symbol_for_function
// 对应 Bun: host_fns.rs:65 — FFI.generateSymbolForFunction
// ============================================================================

/// 从 JS 值解析单个 FFI 函数描述
/// 解析 { args, returns, threadsafe, ptr } 规格为 FfiFunction
/// 对应 Rust: pub fn generate_symbol_for_function(global, value, function)
///
/// 参数:
///   globalObject - JS 全局对象
///   value - 包含函数描述的 JS 值 (对象)
///   function - 输出的函数描述 (会被重置并填充)
///
/// 返回:
///   None - 解析成功
///   Some(JsValue) - 解析失败，返回错误 JS 值
public func generateSymbolForFunction(globalObject: JsObject, value: JsValue, function: FfiFunction): ?JsValue {
    var abiTypes = ArrayList<AbiType>()

    // 解析 args 参数类型数组
    // 对应 Rust: if let Some(args) = get_own(value, global, b"args")?
    let argsValue = value.getOwn("args")
    if (argsValue.valueType == JsValueType.Array) {
        // 对应 Rust: if args.is_empty_or_undefined_or_null() || !args.js_type().is_array()
        let args = argsValue.toArray()
        match (args) {
            case Some(arr) => {
                for (arg in arr) {
                    // 空值检查
                    if (arg.valueType == JsValueType.Null || arg.valueType == JsValueType.Undefined) {
                        return Some(JsValue("param must be a string (type name) or number"))
                    }

                    // 整数类型索引
                    if (arg.valueType == JsValueType.Number) {
                        let int = Int32(arg.toNumber())
                        // Zig: 0...ABIType.max — 拒绝 Buffer (20); 仅字符串标签路径接受它
                        let t = AbiType.fromInt(int)
                        match (t) {
                            case Some(abi) => {
                                if (int <= AbiType.MAX) {
                                    abiTypes.append(abi)
                                    continue
                                } else {
                                    return Some(JsValue("invalid ABI type"))
                                }
                            }
                            case None => return Some(JsValue("invalid ABI type"))
                        }
                    }

                    // 字符串类型名
                    if (arg.valueType != JsValueType.String) {
                        return Some(JsValue("param must be a string (type name) or number"))
                    }

                    let typeName = arg.toString()
                    let abi = AbiType.fromLabel(typeName)
                    match (abi) {
                        case Some(t) => abiTypes.append(t)
                        case None => return Some(JsValue("Unknown type ${typeName}"))
                    }
                }
            }
            case None => ()
        }
    }

    // 解析返回类型
    var returnType = AbiType.Void
    var threadsafe = false

    // 解析 threadsafe 标志
    // 对应 Rust: if let Some(threadsafe_value) = value.get_truthy(global, b"threadsafe")?
    let threadsafeValue = value.getTruthy("threadsafe")
    match (threadsafeValue) {
        case Some(tv) => threadsafe = tv.toBoolean()
        case None => ()
    }

    // 解析 returns 返回类型
    // 对应 Rust: if let Some(ret_value) = value.get_truthy(global, b"returns")?
    let returnsValue = value.getTruthy("returns")
    if (let Some(rv) <- returnsValue) {
        // 整数类型索引
        if (rv.valueType == JsValueType.Number) {
            let int = Int32(rv.toNumber())
            let t = AbiType.fromInt(int)
            match (t) {
                case Some(abi) => {
                    if (int <= AbiType.MAX) {
                        returnType = abi
                    } else {
                        return Some(JsValue("invalid ABI type"))
                    }
                }
                case None => return Some(JsValue("invalid ABI type"))
            }
        } else if (rv.valueType == JsValueType.String) {
            let retSlice = rv.toString()
            let retType = AbiType.fromLabel(retSlice)
            match (retType) {
                case Some(t) => returnType = t
                case None => return Some(JsValue("Unknown return type ${retSlice}"))
            }
        }
    }

    // 验证返回类型约束
    if (returnType == AbiType.NapiEnv) {
        return Some(JsValue("Cannot return napi_env to JavaScript"))
    }
    if (returnType == AbiType.Buffer) {
        return Some(JsValue("Cannot return a buffer to JavaScript (since byteLength and byteOffset are unknown)"))
    }
    if (threadsafe && returnType != AbiType.Void) {
        return Some(JsValue("Threadsafe functions must return void"))
    }

    // 重置并填充函数描述
    // 对应 Rust: *function = Function::default()
    function.reset()
    function.argTypes = abiTypes
    function.returnType = returnType
    function.threadsafe = threadsafe

    // 解析 ptr (已知函数地址)
    // 对应 Rust: if let Some(ptr) = value.get(global, b"ptr")?
    let ptrValue = value.get("ptr")
    if (ptrValue.valueType == JsValueType.Number) {
        let num = ptrValue.toNumber().toInt64()
        if (num > 0) {
            function.symbolFromDynamicLibrary = Some(num)
        }
    } else if (ptrValue.isBigInt()) {
        let num = ptrValue.toUInt64NoTruncate()
        if (num > 0) {
            function.symbolFromDynamicLibrary = Some(Int64(num))
        }
    }

    return None
}

// ============================================================================
// 符号映射生成 — generate_symbols
// 对应 Bun: host_fns.rs:202 — FFI.generateSymbols
// ============================================================================

/// 从 JS 对象迭代自身属性, 解析每个值作为 FfiFunction 描述
/// 对应 Rust: pub fn generate_symbols(global, symbols, object)
///
/// 参数:
///   globalObject - JS 全局对象
///   symbols - 输出的符号映射 (会被追加)
///   object - 包含符号定义的 JS 对象
///
/// 返回:
///   None - 解析成功
///   Some(JsValue) - 解析失败，返回错误 JS 值
public func generateSymbolsInto(globalObject: JsObject, symbols: HashMap<String, FfiFunction>, object: JsObject): ?JsValue {
    // 对应 Rust: JSPropertyIterator::init with skip_empty_name, include_value, own_properties_only
    let keys = object.keys()

    for (key in keys) {
        let propValue = object.get(key)

        // 跳过非对象值
        if (propValue.valueType == JsValueType.Null ||
            propValue.valueType == JsValueType.Undefined ||
            propValue.valueType != JsValueType.Object) {
            return Some(JsValue("Expected an object for key \"${key}\""))
        }

        // 解析单个函数描述
        var func = FfiFunction()
        let err = generateSymbolForFunction(globalObject, propValue, func)
        match (err) {
            case Some(errVal) => return Some(errVal)
            case None => ()
        }

        func.baseName = Some(key)
        symbols.put(key, func)
    }

    return None
}

/// 从 JS 值生成符号映射 (便利包装)
/// 对应 Rust: pub fn generate_symbols(global, symbols, object: impl IntoIterObject)
public func generateSymbols(globalObject: JsObject, value: JsValue): ?HashMap<String, FfiFunction> {
    if (value.valueType != JsValueType.Object) {
        return None
    }

    let obj = value.toObject()
    match (obj) {
        case Some(jsObj) => {
            var symbols = HashMap<String, FfiFunction>()
            let err = generateSymbolsInto(globalObject, symbols, jsObj)
            match (err) {
                case Some(_) => return None
                case None => return symbols
            }
        }
        case None => return None
    }
}

// ============================================================================
// ABI 类型解析辅助
// 对应 Bun: host_fns.rs 中的内联解析逻辑
// ============================================================================

/// 从 JS 值解析单个 ABI 类型
/// 支持整数索引和字符串标签两种形式
public func resolveAbiType(value: JsValue): ?AbiType {
    // 整数索引路径
    if (value.valueType == JsValueType.Number) {
        let int = Int32(value.toNumber())
        let t = AbiType.fromInt(int)
        match (t) {
            case Some(abi) => {
                if (int <= AbiType.MAX) {
                    return abi
                } else {
                    return None
                }
            }
            case None => return None
        }
    }
    // 字符串标签路径
    if (value.valueType == JsValueType.String) {
        return AbiType.fromLabel(value.toString())
    }
    return None
}

// ============================================================================
// NAPI 环境创建
// 对应 Bun: host_fns.rs:545 — make_napi_env_if_needed
// ============================================================================

/// 如果函数集合中有任何函数需要 napi_env/napi_value 参数,
/// 则分配一个 NapiEnv
///
/// 对应 Rust: pub(super) fn make_napi_env_if_needed(functions, global_this)
///
/// 参数:
///   functions - FFI 函数集合
///   globalObject - JS 全局对象
///
/// 返回:
///   Some(Int64) - NapiEnv 指针
///   None - 不需要 NapiEnv
public func makeNapiEnvIfNeeded(functions: HashMap<String, FfiFunction>, globalObject: JsObject): ?Int64 {
    for ((_, func) in functions) {
        if (func.needsNapiEnv()) {
            // 实际实现: 调用 JSGlobalObject::makeNapiEnvForFFI
            // 返回堆分配的 NapiEnv 指针，由 VM 拥有
            return Some(1) // 占位: 实际通过 FFI 获取
        }
    }
    return None
}

// ============================================================================
// FFI 宿主函数入口 — 字段表中的函数
// 对应 Bun: FFIObject.rs 中的 fields 模块
// ============================================================================

/// FFI 宿主函数: viewSource
/// 对应 Rust: fields::view_source -> FfiImpl::print(global, object, is_callback)
public func hostViewSource(globalObject: JsObject, callframe: JsCallFrame): JsValue {
    let args = callframe.arguments(2)
    let object = args.getOrElse(0, { => JsValue.UNDEFINED })
    let isCallback = if (args.size > 1) { Some(args[1]) } else { None }
    // 委托给 FfiModule.print
    return FfiModule.print(globalObject, object, isCallback)
}

/// FFI 宿主函数: dlopen
/// 对应 Rust: fields::dlopen -> FfiImpl::open(global, name, object)
public func hostDlopen(globalObject: JsObject, callframe: JsCallFrame): JsValue {
    let args = callframe.arguments(2)
    if (args.size < 2) {
        return JsValue("Missing argument")
    }
    let name = args[0].toString()
    let object = args[1]
    return FfiModule.open(globalObject, name, object)
}

/// FFI 宿主函数: callback
/// 对应 Rust: fields::callback -> FfiImpl::callback(global, interface, js_callback)
public func hostCallback(globalObject: JsObject, callframe: JsCallFrame): JsValue {
    let args = callframe.arguments(2)
    if (args.size < 2) {
        return JsValue("Missing argument")
    }
    let interface = args[0]
    let jsCallback = args[1]
    return FfiModule.callback(globalObject, interface, jsCallback)
}

/// FFI 宿主函数: linkSymbols
/// 对应 Rust: fields::link_symbols -> FfiImpl::link_symbols(global, object)
public func hostLinkSymbols(globalObject: JsObject, callframe: JsCallFrame): JsValue {
    let args = callframe.arguments(1)
    if (args.size < 1) {
        return JsValue("Missing argument")
    }
    let object = args[0]
    return FfiModule.linkSymbols(globalObject, object)
}

/// FFI 宿主函数: toBuffer
/// 对应 Rust: fields::to_buffer -> FfiObject.to_buffer
public func hostToBuffer(globalObject: JsObject, callframe: JsCallFrame): JsValue {
    let args = callframe.arguments(5)
    let value = args.getOrElse(0, { => JsValue.UNDEFINED })
    let byteOffset = if (args.size > 1) { Some(args[1]) } else { None }
    let length = if (args.size > 2) { Some(args[2]) } else { None }
    let finalCtx = if (args.size > 3) { Some(args[3]) } else { None }
    let finalCb = if (args.size > 4) { Some(args[4]) } else { None }
    return FfiObject.toBuffer(globalObject, value, byteOffset, length, finalCtx, finalCb)
}

/// FFI 宿主函数: toArrayBuffer
/// 对应 Rust: fields::to_array_buffer -> FfiObject.to_array_buffer
public func hostToArrayBuffer(globalObject: JsObject, callframe: JsCallFrame): JsValue {
    let args = callframe.arguments(5)
    let value = args.getOrElse(0, { => JsValue.UNDEFINED })
    let byteOffset = if (args.size > 1) { Some(args[1]) } else { None }
    let length = if (args.size > 2) { Some(args[2]) } else { None }
    let finalCtx = if (args.size > 3) { Some(args[3]) } else { None }
    let finalCb = if (args.size > 4) { Some(args[4]) } else { None }
    return FfiObject.toArrayBuffer(globalObject, value, byteOffset, length, finalCtx, finalCb)
}

/// FFI 宿主函数: closeCallback
/// 对应 Rust: fields::close_callback -> FfiImpl::close_callback(global, ctx)
public func hostCloseCallback(globalObject: JsObject, callframe: JsCallFrame): JsValue {
    let args = callframe.arguments(1)
    if (args.size < 1) {
        return JsValue("Missing argument")
    }
    let ctx = args[0]
    return FfiModule.closeCallback(globalObject, ctx)
}

/// FFI 宿主函数: CString
/// 对应 Rust: fields::cstring -> FfiObject.new_cstring
public func hostCString(globalObject: JsObject, callframe: JsCallFrame): JsValue {
    let args = callframe.arguments(3)
    let value = args.getOrElse(0, { => JsValue.UNDEFINED })
    let byteOffset = if (args.size > 1) { Some(args[1]) } else { None }
    let length = if (args.size > 2) { Some(args[2]) } else { None }
    return FfiObject.newCString(globalObject, value, byteOffset, length)
}

// ============================================================================
// FFI 字段注册表
// 对应 Bun: FFIObject.rs 中的 FIELDS() 函数
// ============================================================================

/// FFI 字段描述
/// 对应 Rust 中 wrap_host_fn! 宏生成的 (name, JSHostFn) 对
public class FfiFieldEntry {
    /// 字段名 (JS 侧属性名)
    public var name: String
    /// 对应的宿主函数
    public var hostFn: (JsObject, JsCallFrame) -> JsValue

    public init(name: String, hostFn: (JsObject, JsCallFrame) -> JsValue) {
        this.name = name
        this.hostFn = hostFn
    }
}

/// FFI 字段表 — 注册所有 FFI 暴露给 JS 的函数
/// 对应 Rust: fn FIELDS() -> [(&'static str, jsc::JSHostFn); 8]
///
/// 字段顺序与 Bun 中 toJS 函数的 inline for 循环一致:
/// viewSource, dlopen, callback, linkSymbols, toBuffer,
/// toArrayBuffer, closeCallback, CString
public func ffiFields(): ArrayList<FfiFieldEntry> {
    let fields = ArrayList<FfiFieldEntry>()
    fields.append(FfiFieldEntry("viewSource", hostViewSource))
    fields.append(FfiFieldEntry("dlopen", hostDlopen))
    fields.append(FfiFieldEntry("callback", hostCallback))
    fields.append(FfiFieldEntry("linkSymbols", hostLinkSymbols))
    fields.append(FfiFieldEntry("toBuffer", hostToBuffer))
    fields.append(FfiFieldEntry("toArrayBuffer", hostToArrayBuffer))
    fields.append(FfiFieldEntry("closeCallback", hostCloseCallback))
    fields.append(FfiFieldEntry("CString", hostCString))
    return fields
}

// ============================================================================
// DOM Call 慢路径辅助
// 对应 Bun: mod.rs 中的 dom_call_slowpath 模块
// ============================================================================

/// DOM Call 慢路径注册表
/// 对应 Rust: dom_call_slowpath! 宏生成的 @export 函数
/// 为每种 Reader 类型提供 JIT 慢路径入口
public class DomCallSlowPath {
    /// Reader 类型与对应的慢路径函数名映射
    public static let READER_SLOWPATHS: ArrayList<(String, String)> = {
        let list = ArrayList<(String, String)>()
        list.append(("Reader__u8__slowpath", "u8"))
        list.append(("Reader__u16__slowpath", "u16"))
        list.append(("Reader__u32__slowpath", "u32"))
        list.append(("Reader__ptr__slowpath", "ptr"))
        list.append(("Reader__i8__slowpath", "i8"))
        list.append(("Reader__i16__slowpath", "i16"))
        list.append(("Reader__i32__slowpath", "i32"))
        list.append(("Reader__i64__slowpath", "i64"))
        list.append(("Reader__u64__slowpath", "u64"))
        list.append(("Reader__intptr__slowpath", "intptr"))
        list.append(("Reader__f32__slowpath", "f32"))
        list.append(("Reader__f64__slowpath", "f64"))
        return list
    }()
}

// ============================================================================
// dlerror 辅助
// 对应 Bun: mod.rs — get_dl_error()
// ============================================================================

/// 获取最后一次动态库加载错误信息 (跨平台)
/// 对应 Rust: pub(crate) fn get_dl_error() -> Box<[u8]>
/// POSIX: 调用 dlerror()
/// Windows: 使用 GetLastError() 格式化错误码
public func getDlError(): String {
    // 实际实现通过 FFI 调用 C dlerror() 或 Windows GetLastError()
    // 占位: 委托给 DynamicLibrary
    return DynamicLibrary.getLastError()
}
