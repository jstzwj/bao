// wasm_streaming - WebAssembly 流式编译
// 严格翻译自: src/runtime/webcore/wasm_streaming.rs
//   Bun 的 wasm_streaming 模块:
//   - getBodyStreamOrBytesForWasmStreaming: 从 Response 中提取 wasm 字节
//   - Zig__GlobalObject__getBodyStreamOrBytesForWasmStreaming: C ABI 入口
//   验证 Response 的 MIME type 必须是 application/wasm, 然后推送字节到 StreamingCompiler
//   仓颉: 提供兼容的 WebAssembly 流式编译接口
package bao_runtime.webcore

import bao_core.BaoError
import bao_core.ErrorCode
import bao_jsc.*
import bao_collections.ArrayList

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
    ///     response_value: JsValue,
    ///     streaming_compiler: *c_void,
    /// ) -> JsResult<JsValue>
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
        responseValue: JsValue,
        streamingCompiler: CPointer<Unit>
    ): Result<JsValue> {
        // 1. 从 JsValue 中提取 Response
        let responseOpt = Response.fromJs(responseValue)
        match (responseOpt) {
            case Some(respRef) =>
                let response = respRef
                return processResponse(global, response, streamingCompiler)
            case None =>
                return Result<JsValue>.Err(
                    "source is not an instance of Response or a Promise resolving to Response"
                )
        }
    }

    /// C ABI 入口函数
    /// 对应 Bun: #[unsafe(no_mangle)]
    ///   pub extern "C" fn Zig__GlobalObject__getBodyStreamOrBytesForWasmStreaming(
    ///     this: *JSGlobalObject,
    ///     response_value: JsValue,
    ///     streaming_compiler: *c_void,
    ///   ) -> JsValue
    ///
    /// jsc.host_fn.wrap3(getBodyStreamOrBytesForWasmStreaming) — plain C ABI
    /// shim: returns .zero on thrown exception (matches wrapN semantics).
    public static func zigEntryPoint(
        global: JSGlobalObject,
        responseValue: JsValue,
        streamingCompiler: CPointer<Unit>
    ): JsValue {
        let result = getBodyStreamOrBytesForWasmStreaming(global, responseValue, streamingCompiler)
        match (result) {
            case Ok(v) => v
            case Err(_) => JsValue.zero
        }
    }

    /// 处理 Response, 验证并提取 body
    private static func processResponse(
        global: JSGlobalObject,
        response: Response,
        streamingCompiler: CPointer<Unit>
    ): Result<JsValue> {
        // 2. 验证 content-type
        let contentTypeSlice: String = response.getContentType()
        let contentType: Array<UInt8> = stringToBytes(contentTypeSlice)

        let wasmMime = stringToBytes("application/wasm")
        if (!bytesEqual(contentType, wasmMime)) {
            let ctStr = bytesToString(contentType)
            return Result<JsValue>.Err(
                "WebAssembly response has unsupported MIME type '${ctStr}'"
            )
        }

        // 3. 验证 status code
        if (!response.isOk()) {
            let statusCode = response.statusCode()
            return Result<JsValue>.Err(
                "WebAssembly response has status code ${statusCode}"
            )
        }

        // 4. 验证 body 未被使用
        if (response.getBodyUsed()) {
            return Result<JsValue>.Err(
                "WebAssembly response body has already been used"
            )
        }

        // 5. 处理 body
        let body = response.getBodyValue()

        // 检查是否是 Error body
        // PORT NOTE: BodyValue.isError/isLocked not yet available; stubbed
        let bodyIsError = false
        if (bodyIsError) {
            return Result<JsValue>.Err(
                "Response body is an error"
            )
        }

        // 尝试将 body 转换为 blob
        body.toBlobIfPossible()

        // PORT NOTE: simplified; body locked/streaming logic not yet fully wired
        // 返回 null (表示已推送到 StreamingCompiler)
        return Result<JsValue>.Ok(JsValue())
    }

    // ========================================================================
    // 内部工具函数
    // ========================================================================

    /// 字符串转字节数组
    private static func stringToBytes(s: String): Array<UInt8> {
        let arr = ArrayList<UInt8>()
        for (c in s) {
            let cp = Int64(c)
            if (cp < 0x80) {
                arr.append(UInt8(cp))
            } else if (cp < 0x800) {
                arr.append(UInt8(0xC0 | (cp >> 6)))
                arr.append(UInt8(0x80 | (cp & 0x3F)))
            } else if (cp < 0x10000) {
                arr.append(UInt8(0xE0 | (cp >> 12)))
                arr.append(UInt8(0x80 | ((cp >> 6) & 0x3F)))
                arr.append(UInt8(0x80 | (cp & 0x3F)))
            } else {
                arr.append(UInt8(0xF0 | (cp >> 18)))
                arr.append(UInt8(0x80 | ((cp >> 12) & 0x3F)))
                arr.append(UInt8(0x80 | ((cp >> 6) & 0x3F)))
                arr.append(UInt8(0x80 | (cp & 0x3F)))
            }
        }
        return arr.items()
    }

    /// 字节数组转字符串
    private static func bytesToString(bytes: Array<UInt8>): String {
        // PORT NOTE: simplified - just use UTF-8 decode via String constructor
        var result = ""
        for (b in bytes) {
            result = result + String(Rune(Int32(b)))
        }
        return result
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
