// wasm_streaming - WebAssembly 流式编译
// 严格翻译自: src/runtime/webcore/wasm_streaming.rs
//   Bun 的 wasm_streaming 模块:
//   - getBodyStreamOrBytesForWasmStreaming: 从 Response 中提取 wasm 字节
//   - Zig__GlobalObject__getBodyStreamOrBytesForWasmStreaming: C ABI 入口
//   验证 Response 的 MIME type 必须是 application/wasm, 然后推送字节到 StreamingCompiler
//   仓颉: 提供兼容的 WebAssembly 流式编译接口
package bao_runtime.webcore

import bao_core.*
import bao_jsc.*

// ============================================================================
// C FFI 声明
// 严格翻译自: wasm_streaming.rs 中的 extern "C"
//   `streaming_compiler` is the opaque C++ `StreamingCompiler*` handed in by
//   the host; `bytes_ptr`/`bytes_len` are the ptr/len of a byte slice.
// ============================================================================

@C
foreign func JSC__Wasm__StreamingCompiler__addBytes(
    streamingCompiler: CPointer<Unit>,
    bytesPtr: CPointer<UInt8>,
    bytesLen: UIntNative
): Unit

// ============================================================================
// WasmStreaming - WebAssembly 流式编译器
// 严格翻译自: src/runtime/webcore/wasm_streaming.rs
//   `Zig__GlobalObject__getBodyStreamOrBytesForWasmStreaming` — moved UP from
//   `jsc::JSGlobalObject` because the body inspects `Response`/`Body`/
//   `Blob`/`ReadableStream`, which are `runtime` types (forward-dep of `jsc`).
// ============================================================================

/// WebAssembly 流式编译辅助
/// 对应 Bun: get_body_stream_or_bytes_for_wasm_streaming
///
/// Spec `JSGlobalObject.zig:871 getBodyStreamOrBytesForWasmStreaming`.
/// Validates the Response has MIME type "application/wasm", then pushes bytes
/// into the StreamingCompiler via C FFI.
public class WasmStreaming {
    /// 从 Response 中提取 wasm 字节流或字节数据
    /// 对应 Bun: pub fn get_body_stream_or_bytes_for_wasm_streaming(
    ///     this: &JSGlobalObject,
    ///     response_value: JSValue,
    ///     streaming_compiler: *mut c_void,
    /// ) -> JsResult<JSValue>
    ///
    /// 步骤:
    ///   1. 验证 response_value 是 Response 实例
    ///   2. 验证 content-type 为 "application/wasm"
    ///   3. 验证 status code 为 2xx
    ///   4. 验证 body 未被使用
    ///   5. 处理 body value 的各种变体:
    ///      - Error: 抛出错误
    ///      - Locked: 尝试获取 ReadableStream
    ///      - Blob/Bytes: 推送字节到 StreamingCompiler
    ///      - File/S3: 创建 ReadableStream (异步读取)
    public static func getBodyStreamOrBytesForWasmStreaming(
        global: JSGlobalObject,
        responseValue: JSValue,
        streamingCompiler: CPointer<Unit>
    ): Result<JSValue> {
        // 1. 从 JSValue 中提取 Response
        let responseOpt = Response.fromJs(responseValue)
        match (responseOpt) {
            case Some(respRef) => {
                let response = respRef
                return processResponse(global, response, streamingCompiler)
            }
            case None => {
                return Result<JSValue>.Err(
                    BaoError(
                        ErrorCode.TypeError,
                        "source is not an instance of Response or a Promise resolving to Response"
                    )
                )
            }
        }
    }

    /// C ABI 入口函数
    /// 对应 Bun: #[unsafe(no_mangle)]
    ///   pub extern "C" fn Zig__GlobalObject__getBodyStreamOrBytesForWasmStreaming(
    ///     this: *mut JSGlobalObject,
    ///     response_value: JSValue,
    ///     streaming_compiler: *mut c_void,
    ///   ) -> JSValue
    ///
    /// jsc.host_fn.wrap3(getBodyStreamOrBytesForWasmStreaming) — plain C ABI
    /// shim: returns .zero on thrown exception (matches wrapN semantics).
    public static func zigEntryPoint(
        global: JSGlobalObject,
        responseValue: JSValue,
        streamingCompiler: CPointer<Unit>
    ): JSValue {
        let result = getBodyStreamOrBytesForWasmStreaming(global, responseValue, streamingCompiler)
        match (result) {
            case Ok(v) => v
            case Err(_) => JSValue.zero
        }
    }

    /// 处理 Response, 验证并提取 body
    private static func processResponse(
        global: JSGlobalObject,
        response: Response,
        streamingCompiler: CPointer<Unit>
    ): Result<JSValue> {
        // 2. 验证 content-type
        let contentTypeSlice = response.getContentType()
        let contentType: Array<UInt8> = match (contentTypeSlice) {
            case Some(ct) => ct
            case None => Array<UInt8>()  // "null"
        }

        let wasmMime = stringToBytes("application/wasm")
        if (!bytesEqual(contentType, wasmMime)) {
            let ctStr = bytesToString(contentType)
            return Result<JSValue>.Err(
                BaoError(
                    ErrorCode.WebAssemblyResponse,
                    "WebAssembly response has unsupported MIME type '${ctStr}'"
                )
            )
        }

        // 3. 验证 status code
        if (!response.isOk()) {
            let statusCode = response.statusCode()
            return Result<JSValue>.Err(
                BaoError(
                    ErrorCode.WebAssemblyResponse,
                    "WebAssembly response has status code ${statusCode}"
                )
            )
        }

        // 4. 验证 body 未被使用
        if (response.getBodyUsed().toBoolean()) {
            return Result<JSValue>.Err(
                BaoError(
                    ErrorCode.WebAssemblyResponse,
                    "WebAssembly response body has already been used"
                )
            )
        }

        // 5. 处理 body
        let body = response.getBodyValue()

        // 检查是否是 Error body
        if (body.isError()) {
            return Result<JSValue>.Err(
                BaoError(ErrorCode.WebAssemblyResponse, "Response body is an error")
            )
        }

        // 尝试将 body 转换为 blob
        body.toBlobIfPossible()

        // 处理 Locked 状态 — 返回 ReadableStream
        if (body.isLocked()) {
            let streamOpt = response.getBodyReadableStream(global)
            match (streamOpt) {
                case Some(stream) => return Result<JSValue>.Ok(stream.value)
                case None => ()
            }
        }

        // 重新获取 body value (可能在 toBlobIfPossible 后变化)
        let bodyValue = response.getBodyValue()
        let anyBlob = match (bodyValue.tryUseAsAnyBlob()) {
            case Some(b) => b
            case None => {
                // Body 无法转换为 AnyBlob, 尝试转 ReadableStream
                return bodyValue.toReadableStream(global)
            }
        }

        // 检查是否是文件/S3 存储 (需要异步读取)
        let storeOpt = anyBlob.getStore()
        match (storeOpt) {
            case Some(store) => {
                if (!store.isBytesData()) {
                    // 这是文件或 S3 对象, 不能同步读取
                    // 创建 ReadableStream (使用 blob copy)
                    let blob = anyBlob.getBlob()
                    blob.resolveSize()
                    let size = blob.getSize()
                    return Result<JSValue>.Ok(
                        ReadableStream.fromBlobCopyRef(global, blob, size)
                    )
                }
            }
            case None => ()
        }

        // 推送字节到 StreamingCompiler
        let slice = anyBlob.slice()
        unsafe {
            JSC__Wasm__StreamingCompiler__addBytes(
                streamingCompiler,
                CPointer<UInt8>(unsafeRefToPtr(slice)),
                UIntNative(slice.size)
            )
        }

        // 释放 anyBlob
        anyBlob.detach()

        // 返回 null (表示已推送到 StreamingCompiler)
        return Result<JSValue>.Ok(JSValue.null)
    }

    // ========================================================================
    // 内部工具函数
    // ========================================================================

    /// 字符串转字节数组
    private static func stringToBytes(s: String): Array<UInt8> {
        let arr = Array<UInt8>()
        for (i in 0..s.size) {
            arr.append(UInt8(s[Int64(i)].value))
        }
        return arr
    }

    /// 字节数组转字符串
    private static func bytesToString(bytes: Array<UInt8>): String {
        let sb = StringBuilder()
        for (b in bytes) {
            sb.append(Char(Int32(b)))
        }
        return sb.toString()
    }

    /// 比较两个字节数组是否相等
    private static func bytesEqual(a: Array<UInt8>, b: Array<UInt8>): Bool {
        if (a.size != b.size) { return false }
        for (i in 0..a.size) {
            if (a[i] != b[i]) { return false }
        }
        return true
    }
}
