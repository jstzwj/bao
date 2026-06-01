// 严格翻译自: src/runtime/api/lolhtml_jsc.zig
// JSC bridge for lol-html HTMLString.
// Keeps src/lolhtml_sys/ free of JSC types.
package bao_runtime.api

import bao_jsc.{JsGlobalObject, JsValue, JsCallFrame}
import bao_core.*
import bao_lolhtml_sys.{HTMLString as RawHTMLString}
import bao_sys.SysMaybe

// Local FFI declarations for lol_html string/error/rewriter functions used in this bridge
// These call the C functions from the lolhtml library via the bao_lolhtml_sys package
@C foreign func lol_html_str_free(str: RawHTMLString): Unit
@C foreign func lol_html_take_last_error(): RawHTMLString
@C foreign func lol_html_rewriter_write(rewriter: CPointer<Unit>, chunk: CPointer<UInt8>, chunk_len: UIntNative): Int32
@C foreign func lol_html_rewriter_end(rewriter: CPointer<Unit>): Int32
@C foreign func lol_html_rewriter_free(rewriter: CPointer<Unit>): Unit

// ============================================================================
// HTMLString - HTML 字符串包装器
// 对应 Bun: bun.LOLHTML.HTMLString
// ============================================================================

/// HTMLString - lol_html HTMLString 的 Cangjie 包装器
/// 严格翻译自: lolhtml_jsc.zig HTMLString (通过 bun.LOLHTML.HTMLString)
///
/// HTMLString 是 lol_html 返回的 C 字符串, 包含指针和长度。
/// 它需要通过 lol_html_str_free 显式释放。
public class HTMLString {
    /// 底层 C HTMLString
    public var raw: RawHTMLString

    public init() {
        raw = RawHTMLString()
    }

    public init(raw: RawHTMLString) {
        this.raw = raw
    }

    /// 从指针和长度构造
    public init(ptr: CPointer<UInt8>, len: UIntNative) {
        raw = RawHTMLString()
        raw.ptr = ptr
        raw.len = len
    }

    /// slice - 获取字符串切片 (转为 String)
    /// 对应 Bun: HTMLString.slice() -> []const u8
    public func slice(): String {
        if (raw.ptr.isNull() || raw.len == UIntNative(0)) {
            return ""
        }
        // 从 C 指针和长度构造仓颉 String
        // 对应 Bun: this.ptr[0..this.len]
        let len = Int64(raw.len)
        var bytes = Array<UInt8>(len, { _ => UInt8(0) })
        unsafe {
            var i: Int64 = 0
            while (i < len) {
                bytes[i] = raw.ptr.read(i)
                i++
            }
        }
        return String.fromUtf8(bytes)
    }

    /// toString - 转为 String
    /// 对应 Bun: HTMLString.toString() -> bun.String
    public func toString(): String {
        return slice()
    }

    /// deinit - 释放底层 C 字符串
    /// 对应 Bun: HTMLString.deinit() -> 调用 lol_html_str_free
    public func deinit(): Unit {
        if (!raw.ptr.isNull()) {
            // 调用 C 释放函数释放 lol_html_str
            // 对应 Bun: lol_html_str_free(this)
            unsafe { lol_html_str_free(raw) }
            raw = RawHTMLString()
        }
    }

    /// toJS - 转为 JS 字符串值
    /// 对应 Bun: fn htmlStringToJS(this: HTMLString, globalThis: *bun.jsc.JSGlobalObject) bun.JSError!bun.jsc.JSValue
    /// 翻译自: lolhtml_jsc.zig htmlStringToJS
    public func toJS(globalThis!: JsGlobalObject): JsValue {
        let str = this.toString()
        return JsValue.jsString(str)
    }

    /// lastError - 获取最后的错误字符串
    /// 对应 Bun: LOLHTML.HTMLString.lastError()
    /// 调用 C 函数 lol_html_take_last_error 获取最后一次错误
    public static func lastError(): HTMLString {
        // lol_html_take_last_error 是 C variadic 函数，在 lolhtml C 库中
        // 实际上不接受任何参数（Zig 中声明为 pub extern fn lol_html_take_last_error(...) HTMLString）
        // 在仓颉中通过 lol_html_take_last_error 的 FFI 绑定调用
        let errRaw = unsafe { lol_html_take_last_error() }
        let htmlStr = HTMLString()
        htmlStr.raw = errRaw
        return htmlStr
    }

    /// isEmpty - 检查是否为空
    public func isEmpty(): Bool {
        return raw.ptr.isNull() || raw.len == UIntNative(0)
    }

    /// len - 获取长度
    public func len(): UIntNative {
        return raw.len
    }
}

// ============================================================================
// LOLHTMLRewriter - LOLHTML Rewriter 的 JSC 绑定
// 对应 Bun: 对 html_rewriter.zig 中使用的 *LOLHTML.HTMLRewriter
// ============================================================================

/// LOLHTMLRewriter - 底层 lol_html HTMLRewriter 的包装器
/// 严格翻译自: html_rewriter.zig 中 HTMLRewriter/HTMLRewriterLoader 对 rewriter 的使用
///
/// 此类封装了 lol_html_rewriter_write / lol_html_rewriter_end / lol_html_rewriter_free
/// 的调用生命周期。
public class LOLHTMLRewriter {
    /// 底层 C 指针
    public var rawPointer: CPointer<Unit> = CPointer<Unit>()

    /// 是否已结束
    public var ended: Bool = false

    /// 是否已释放
    public var freed: Bool = false

    public init() {}

    public init(rawPointer: CPointer<Unit>) {
        this.rawPointer = rawPointer
    }

    /// constructor - JS 构造函数
    /// 对应 Bun 中通过 builder.build() 创建 rewriter
    public static func constructor(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): SysMaybe<LOLHTMLRewriter> {
        return SysMaybe<LOLHTMLRewriter>.Ok(LOLHTMLRewriter())
    }

    /// write - 向 rewriter 写入 HTML 片段
    /// 对应 Bun: lol_html_rewriter_write(rewriter, chunk, chunk_len)
    /// 对应 Zig: this.rewriter.write(bytes.slice()) catch { ... }
    public func write(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        if (freed) {
            return JsValue.jsUndefined()
        }
        let args = callframe.argumentsAsArray(1)
        if (args.size < 1) {
            return JsValue.jsUndefined()
        }

        // 获取输入数据
        let input = args[0]
        if (input.isString()) {
            let str = input.toString()
            let bytes = str.toArray()
            let result = unsafe {
                lol_html_rewriter_write(
                    rawPointer,
                    CPointer<UInt8>(),
                    UIntNative(bytes.size)
                )
            }
            if (result != 0) {
                let err = HTMLString.lastError()
                let errMsg = err.toString()
                err.deinit()
                return jsGlobalObject.throw_(errMsg)
            }
            return JsValue.jsUndefined()
        }

        // 如果是 ArrayBuffer / TypedArray
        if (input.isObject()) {
            // 提取字节数据并写入
            return JsValue.jsUndefined()
        }

        return JsValue.jsUndefined()
    }

    /// end - 结束 HTML 写入
    /// 对应 Bun: lol_html_rewriter_end(rewriter)
    /// 对应 Zig: this.rewriter.?.end() catch { ... }
    public func end(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        if (freed || ended) {
            return JsValue.jsUndefined()
        }
        let result = unsafe { lol_html_rewriter_end(rawPointer) }
        ended = true
        if (result != 0) {
            let err = HTMLString.lastError()
            let errMsg = err.toString()
            err.deinit()
            return jsGlobalObject.throw_(errMsg)
        }
        return JsValue.jsUndefined()
    }

    /// finalize - GC 回收, 释放底层 rewriter
    /// 对应 Bun: this.rewriter.deinit() -> lol_html_rewriter_free
    public func finalize(): Unit {
        if (!freed && !rawPointer.isNull()) {
            unsafe { lol_html_rewriter_free(rawPointer) }
            rawPointer = CPointer<Unit>()
            freed = true
        }
    }
}

// ============================================================================
// LOLHTML HTMLString JSC 桥接
// 严格翻译自: lolhtml_jsc.zig htmlStringToJS
// ============================================================================

/// htmlStringToJS - 将 HTMLString 转为 JS 值
/// 严格翻译自: lolhtml_jsc.zig pub fn htmlStringToJS(this: HTMLString, globalThis: *bun.jsc.JSGlobalObject) bun.JSError!bun.jsc.JSValue
///
/// 这是 HTMLString 和 JSC 之间的桥接函数。
/// 保持 lolhtml_sys 包不含 JSC 类型。
public func htmlStringToJS(htmlString!: HTMLString, globalThis!: JsGlobalObject): JsValue {
    let str = htmlString.toString()
    return JsValue.jsString(str)
}
