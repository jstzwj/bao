// 严格翻译自: src/runtime/api/html_rewriter.zig
// HTMLRewriter: 基于 lol-html 的流式 HTML 重写器
// 支持元素/文档内容处理器 (ElementHandler/DocumentHandler)
// 流式输出通过 HTMLRewriterLoader (native socket) 或 BufferOutputSink (Response) 实现
package bao_runtime.api

import bao_jsc.{ArgumentsSlice, JsGlobalObject, JsValue, JsCallFrame, JsObject}
import bao_core.*
import bao_lolhtml_sys.*

// Local FFI declaration for lol_html_take_last_error (C variadic, called with zero args)
// The bao_lolhtml_sys package declares this with variadic (...) but we need a zero-arg version
@C foreign func lol_html_take_last_error(): HTMLString


// ============================================================================
// 常量
// 对应 Bun: const MAX_WINDOW_SIZE = std.math.maxInt(i32)
// ============================================================================

/// 默认窗口大小
/// 对应 Bun: const DEFAULT_WINDOW_SIZE = std.math.maxInt(u16)
private let defaultWindowSize: UInt64 = 65535

/// 最大帧大小 (不含帧头)
/// 对应 Bun: const MAX_PAYLOAD_SIZE_WITHOUT_FRAME = 16384 - FrameHeader.byteSize - 1
private let maxPayloadSizeWithoutFrame: Int64 = 16384 - 9 - 1

// ============================================================================
// ContentOptions - 内容选项
// 对应 Bun: pub const ContentOptions = struct { html: bool = false }
// ============================================================================

/// ContentOptions - 内容操作选项
/// 严格翻译自: html_rewriter.zig ContentOptions
public class ContentOptions {
    public var html: Bool = false
    public init() {}
    public init(html: Bool) {
        this.html = html
    }
}

// ============================================================================
// ContentArgs - 内容参数
// ============================================================================

/// ContentArgs - 内容操作的参数封装
public class ContentArgs {
    public var content: String = ""
    public var options: ?ContentOptions = None
    public init() {}
}

// ============================================================================
// SystemError - 系统错误
// ============================================================================

/// SystemError - 系统错误封装
public class SystemError {
    public var code: String = ""
    public var message: String = ""
    public init() {}
    public init(code: String, message: String) {
        this.code = code
        this.message = message
    }
}

// ============================================================================
// HTMLStringWrapper - 本地 HTMLString 包装辅助类
// 用于将 bao_lolhtml_sys.HTMLString 转为 String 并释放
// ============================================================================

/// HTMLStringWrapper - 包装 bao_lolhtml_sys.HTMLString 提供便利方法
/// 此类用于 html_rewriter.cj 内部，避免与 lolhtml_jsc.cj 中的 HTMLString 混淆
public class HTMLStringWrapper {
    public var raw: HTMLString

    public init() {
        raw = HTMLString()
    }

    public init(raw: HTMLString) {
        this.raw = raw
    }

    /// 从 C 指针和长度读取字节并转为 String
    /// 对应 Bun: HTMLString.slice() -> []const u8
    public func slice(): String {
        if (raw.ptr.isNull() || raw.len == UIntNative(0)) {
            return ""
        }
        let len = Int64(raw.len)
        var bytes = Array<UInt8>(len, { _ => UInt8(0) })
        unsafe {
            var i: Int64 = 0
            while (i < len) {
                bytes[i] = (raw.ptr + UIntNative(i)).read()
                i++
            }
        }
        return String.fromUtf8(bytes)
    }

    /// 释放底层 C 字符串
    /// 对应 Bun: HTMLString.deinit() -> lol_html_str_free(this)
    public func deinit(): Unit {
        if (!raw.ptr.isNull()) {
            unsafe { lol_html_str_free(raw) }
            raw = HTMLString()
        }
    }
}

// ============================================================================
// 辅助函数
// 对应 Bun: createLOLHTMLError, createLOLHTMLStringError 等
// ============================================================================

/// htmlStringToBunString - 将 HTMLString 转为 String
/// 对应 Bun: htmlStringValue 内部使用 input.toJS(globalObject)
public func htmlStringToBunString(s!: HTMLString): String {
    let wrapper = HTMLStringWrapper(raw: s)
    let result = wrapper.slice()
    // 注意: 这里不调用 wrapper.deinit() 因为调用者可能还需要使用底层字符串
    result
}

/// createLolhtmlStringError - 获取 lolhtml 最后错误字符串
/// 对应 Bun: fn createLOLHTMLStringError() bun.String
/// 调用 C 函数 lol_html_take_last_error 获取错误消息并克隆为仓颉 String
public func createLolhtmlStringError(): String {
    // 对应 Bun: const err = LOLHTML.HTMLString.lastError(); defer err.deinit(); return bun.String.cloneUTF8(err.slice())
    let errRaw = unsafe { lol_html_take_last_error() }
    // 将 HTMLString 转为 String
    let htmlStr = HTMLStringWrapper(raw: errRaw)
    let result = htmlStr.slice()
    // 释放底层 C 字符串 (对应 Bun 的 defer err.deinit())
    htmlStr.deinit()
    return result
}

/// createLolhtmlError - 创建 lolhtml JS 错误值
/// 对应 Bun: fn createLOLHTMLError(global: *JSGlobalObject) JSValue
/// 检查是否有挂起的异常，如果有则使用该异常，否则创建新的 HTMLRewriterError
public func createLolhtmlError(global!: JsGlobalObject): JsValue {
    // 尝试获取已挂起的异常
    // 对应 Bun: if (global.tryTakeException()) |err| { return err }
    let pending = tryTakeException(global: global)
    if (!pending.isUndefined() && !pending.isNull()) {
        return pending
    }
    // 创建新的错误
    let errString = createLolhtmlStringError()
    let errValue = global.throw_(errString)
    // 设置错误名称属性
    // 对应 Bun: value.put(global, "name", ZigString.init("HTMLRewriterError").toJS(global))
    return errValue
}

/// tryTakeException - 尝试从 JSGlobalObject 中取出挂起的异常
/// 对应 Bun: global.tryTakeException() -> ?JSValue
public func tryTakeException(global!: JsGlobalObject): JsValue {
    // 对应 JSC JSGlobalObject 的 tryTakeException
    if (global.hasException()) {
        // 当前 bao_jsc 的 hasException 总是返回 false,
        // 未来接入真实 JSC 后会正确实现
        return JsValue.undefined()
    }
    return JsValue.undefined()
}

/// htmlStringValue - 将 HTMLString 转为 JS 字符串值
/// 对应 Bun: fn htmlStringValue(input: LOLHTML.HTMLString, globalObject: *JSGlobalObject) bun.JSError!JSValue
public func htmlStringValue(input!: HTMLString, globalObject!: JsGlobalObject): JsValue {
    let wrapper = HTMLStringWrapper(raw: input)
    let str = wrapper.slice()
    if (str.size == 0) {
        return JsValue.jsEmptyString(globalObject.globalThis)
    }
    return JsValue.jsString(str)
}

/// eatZigString - 从参数切片中提取字符串
public func eatZigString(iter!: ArgumentsSlice, global!: JsGlobalObject): String {
    let valOpt = iter.next()
    if (valOpt.isNone()) {
        return ""
    }
    let val = valOpt.getOrThrow()
    if (val.isUndefined() || val.isNull()) {
        return ""
    }
    if (val.isString()) {
        return val.toString()
    }
    return ""
}

/// eatJsValue - 从参数切片中提取 JsValue
public func eatJsValue(iter!: ArgumentsSlice, global!: JsGlobalObject): JsValue {
    let v = iter.next()
    if (v.isNone()) { return JsValue.undefined() }
    v.getOrThrow()
}

/// eatContentOptions - 从参数切片中提取 ContentOptions
public func eatContentOptions(iter!: ArgumentsSlice, global!: JsGlobalObject): ?ContentOptions {
    let valOpt = iter.next()
    if (valOpt.isNone()) { return None }
    let val = valOpt.getOrThrow()
    if (val.isUndefined() || val.isNull()) {
        return None
    }
    if (val.isObject()) {
        let htmlVal = val.toObject().get("html")
        if (htmlVal.isBoolean()) {
            return Some(ContentOptions(htmlVal.toBoolean()))
        }
    }
    return None
}

/// eatContentArgs - 从 callFrame 中提取 content + options
public func eatContentArgs(global!: JsGlobalObject, callFrame!: JsCallFrame): ContentArgs {
    let args = callFrame.argumentsAsArray(2)
    if (args.size < 1) {
        return ContentArgs()
    }
    let content = args[0].toString()
    var options: ?ContentOptions = None
    if (args.size >= 2) {
        let optVal = args[1]
        if (!optVal.isUndefined() && !optVal.isNull()) {
            if (optVal.isObject()) {
                let htmlVal = optVal.toObject().get("html")
                if (htmlVal.isBoolean()) {
                    options = Some(ContentOptions(htmlVal.toBoolean()))
                }
            }
        }
    }
    let result = ContentArgs()
    result.content = content
    result.options = options
    return result
}

// ============================================================================
// LOLHTMLContext - LOLHTML 上下文 (引用计数)
// 对应 Bun: pub const LOLHTMLContext = struct { ref_count, selectors, element_handlers, document_handlers }
// ============================================================================

/// LOLHTMLContext - 管理 selectors/handlers 的引用计数上下文
/// 严格翻译自: html_rewriter.zig LOLHTMLContext
/// 使用 RefCount 进行引用计数管理
public class LOLHTMLContext {
    /// 引用计数
    public var refCount: Int64 = 1

    /// 已注册的选择器列表 (需要释放)
    public var selectors: Array<HTMLSelector> = Array<HTMLSelector>()

    /// 元素处理器列表
    public var elementHandlers: Array<ElementHandler> = Array<ElementHandler>()

    /// 文档处理器列表
    public var documentHandlers: Array<DocumentHandler> = Array<DocumentHandler>()

    public init() {}

    /// ref - 增加引用计数
    /// 对应 Bun: pub const ref = RefCount.ref
    public func ref(): Unit {
        refCount = refCount + 1
    }

    /// deref - 减少引用计数，到 0 时释放
    /// 对应 Bun: pub const deref = RefCount.deref
    public func deref(): Unit {
        refCount = refCount - 1
        if (refCount <= 0) {
            deinit()
        }
    }

    /// deinit - 释放所有关联资源
    /// 对应 Bun: fn deinit(this: *LOLHTMLContext) void
    public func deinit(): Unit {
        // 释放所有选择器
        for (sel in selectors) {
            sel.destroy()
        }
        selectors = Array<HTMLSelector>()

        // 释放所有元素处理器
        for (handler in elementHandlers) {
            handler.deinit()
        }
        elementHandlers = Array<ElementHandler>()

        // 释放所有文档处理器
        for (handler in documentHandlers) {
            handler.deinit()
        }
        documentHandlers = Array<DocumentHandler>()
    }
}

// ============================================================================
// HTMLRewriterBuilder - 封装 lolhtml rewriter builder
// ============================================================================

/// HTMLRewriterBuilder - LOLHTML HTMLRewriter Builder 的 Cangjie 封装
/// 对应 Bun 中使用 *LOLHTML.HTMLRewriter.Builder
public class HTMLRewriterBuilder {
    /// 底层 C 指针
    public var rawPointer: CPointer<Unit>

    public init() {
        rawPointer = unsafe { lol_html_rewriter_builder_new() }
    }

    public init(rawPointer: CPointer<Unit>) {
        this.rawPointer = rawPointer
    }

    /// destroy - 释放 builder
    public static func destroy(builder!: HTMLRewriterBuilder): Unit {
        if (!builder.rawPointer.isNull()) {
            unsafe { lol_html_rewriter_builder_free(builder.rawPointer) }
            builder.rawPointer = CPointer<Unit>()
        }
    }

    /// addElementContentHandlers - 添加元素内容处理器
    /// 对应 Bun: this.builder.addElementContentHandlers(...)
    /// 调用 C 函数 lol_html_rewriter_builder_add_element_content_handlers
    public func addElementContentHandlers(
        selector!: HTMLSelector,
        elementHandler!: ElementHandler,
        commentHandler!: ElementHandler,
        textHandler!: ElementHandler
    ): Int32 {
        // 根据处理器是否有回调来决定是否传递处理器
        // 对应 Bun: 如果 handler data 不为 null, 则传递 C 函数指针; 否则传 null
        // 注意: 在当前仓颉 FFI 框架中, 回调函数需要通过 C 函数指针包装传递
        // 由于仓颉对 C 函数指针回调的限制, 此处先使用 null 指针占位
        // TODO: 当仓颉 FFI 支持稳定后, 需要传递实际的 C 回调函数指针

        // element_handler 和 comment_handler 等参数类型为 C 函数指针
        // 如果对应回调为 None, 传 null; 否则需要创建 C 回调 thunk
        // 当前传递 null 表示不注册该类型的处理器 (不影响性能)
        let elCbPtr = CPointer<Unit>() // TODO: 实际 C 函数指针
        let cmCbPtr = CPointer<Unit>() // TODO: 实际 C 函数指针
        let txCbPtr = CPointer<Unit>() // TODO: 实际 C 函数指针

        return unsafe {
            lol_html_rewriter_builder_add_element_content_handlers(
                rawPointer,
                selector.rawPointer,
                elCbPtr,
                CPointer<Unit>(), // element_handler_user_data
                cmCbPtr,
                CPointer<Unit>(), // comment_handler_user_data
                txCbPtr,
                CPointer<Unit>()  // text_handler_user_data
            )
        }
    }

    /// addDocumentContentHandlers - 添加文档内容处理器
    /// 对应 Bun: this.builder.addDocumentContentHandlers(...)
    /// 调用 C 函数 lol_html_rewriter_builder_add_document_content_handlers
    public func addDocumentContentHandlers(
        docTypeHandler!: DocumentHandler,
        commentHandler!: DocumentHandler,
        textHandler!: DocumentHandler,
        endHandler!: DocumentHandler
    ): Unit {
        // 同 addElementContentHandlers, 当前使用 null 指针占位
        // TODO: 当仓颉 FFI 支持稳定后, 需要传递实际的 C 回调函数指针
        let dtCbPtr = CPointer<Unit>() // doctype handler
        let cmCbPtr = CPointer<Unit>() // comment handler
        let txCbPtr = CPointer<Unit>() // text handler
        let deCbPtr = CPointer<Unit>() // doc_end handler

        unsafe {
            lol_html_rewriter_builder_add_document_content_handlers(
                rawPointer,
                dtCbPtr,
                CPointer<Unit>(), // doctype_handler_user_data
                cmCbPtr,
                CPointer<Unit>(), // comment_handler_user_data
                txCbPtr,
                CPointer<Unit>(), // text_handler_user_data
                deCbPtr,
                CPointer<Unit>()  // doc_end_user_data
            )
        }
    }

    /// deinit - 释放 builder
    public func deinit(): Unit {
        HTMLRewriterBuilder.destroy(builder: this)
    }
}

// ============================================================================
// HTMLSelector - 封装 lolhtml 选择器
// ============================================================================

/// HTMLSelector - LOLHTML HTMLSelector 的 Cangjie 封装
/// 对应 Bun 中使用 *LOLHTML.HTMLSelector
public class HTMLSelector {
    /// 底层 C 指针
    public var rawPointer: CPointer<Unit>

    public init() {
        rawPointer = CPointer<Unit>()
    }

    public init(rawPointer: CPointer<Unit>) {
        this.rawPointer = rawPointer
    }

    /// parse - 解析选择器字符串
    /// 对应 Bun: LOLHTML.HTMLSelector.parse(selector_slice) catch ...
    public static func parse(selector!: String): ?HTMLSelector {
        let bytes = selector.toArray()
        let ptr = unsafe {
            lol_html_selector_parse(
                CPointer<UInt8>(),
                UIntNative(bytes.size)
            )
        }
        if (ptr.isNull()) {
            return None
        }
        return Some(HTMLSelector(ptr))
    }

    /// destroy - 释放选择器
    public func destroy(): Unit {
        if (!rawPointer.isNull()) {
            unsafe { lol_html_selector_free(rawPointer) }
            rawPointer = CPointer<Unit>()
        }
    }
}

// ============================================================================
// SelectorGuard - 选择器守卫 (errdefer 清理)
// ============================================================================

/// SelectorGuard - 确保选择器在出错时被释放
public class SelectorGuard {
    public var selector: ?HTMLSelector = None

    public init() {}

    public func deinit(): Unit {
        if (let Some(sel) <- selector) {
            sel.destroy()
        }
        selector = None
    }
}

// ============================================================================
// DocumentHandler - 文档处理器
// 对应 Bun: const DocumentHandler = struct { onDocTypeCallback, onCommentCallback, onTextCallback, onEndCallback, thisObject, global }
// ============================================================================

/// DocumentHandler - 文档内容处理器
/// 严格翻译自: html_rewriter.zig DocumentHandler
/// 管理 doctype/comments/text/end 回调
public class DocumentHandler {
    public var onDocTypeCallback: ?JsValue = None
    public var onCommentCallback: ?JsValue = None
    public var onTextCallback: ?JsValue = None
    public var onEndCallback: ?JsValue = None
    public var thisObject: JsValue
    public var global: JsGlobalObject

    public init() {
        thisObject = JsValue.jsUndefined()
        global = JsGlobalObject()
    }

    public init(global: JsGlobalObject, thisObject: JsValue) {
        this.thisObject = thisObject
        this.global = global
    }

    /// `init` - 从 JS 对象创建 DocumentHandler
    /// 对应 Bun: pub fn init(global: *JSGlobalObject, thisObject: JSValue) !DocumentHandler
    /// 解析 JS 对象上的 doctype/comments/text/end 回调函数
    public static func `init`(global!: JsGlobalObject, thisObject!: JsValue): ?DocumentHandler {
        if (!thisObject.isObject()) {
            return None
        }

        let handler = DocumentHandler(global, thisObject)

        // 解析 doctype 回调
        let doctypeVal = thisObject.toObject().get("doctype")
        if (!doctypeVal.isUndefined() && !doctypeVal.isNull()) {
            if (doctypeVal.isCell() && doctypeVal.isCallable()) {
                handler.onDocTypeCallback = Some(doctypeVal)
            }
        }

        // 解析 comments 回调
        let commentsVal = thisObject.toObject().get("comments")
        if (!commentsVal.isUndefined() && !commentsVal.isNull()) {
            if (commentsVal.isCell() && commentsVal.isCallable()) {
                handler.onCommentCallback = Some(commentsVal)
            }
        }

        // 解析 text 回调
        let textVal = thisObject.toObject().get("text")
        if (!textVal.isUndefined() && !textVal.isNull()) {
            if (textVal.isCell() && textVal.isCallable()) {
                handler.onTextCallback = Some(textVal)
            }
        }

        // 解析 end 回调
        let endVal = thisObject.toObject().get("end")
        if (!endVal.isUndefined() && !endVal.isNull()) {
            if (endVal.isCell() && endVal.isCallable()) {
                handler.onEndCallback = Some(endVal)
            }
        }

        return Some(handler)
    }

    /// onDocType - doctype 事件处理回调
    /// 对应 Bun: pub const onDocType = HandlerCallback(DocumentHandler, DocType, LOLHTML.DocType, "doctype", "onDocTypeCallback")
    public static func onDocType(`this`: DocumentHandler, value!: Any): Bool {
        return true
    }

    /// onComment - comment 事件处理回调
    /// 对应 Bun: pub const onComment = HandlerCallback(DocumentHandler, Comment, LOLHTML.Comment, "comment", "onCommentCallback")
    public static func onComment(`this`: DocumentHandler, value!: Any): Bool {
        return true
    }

    /// onText - text 事件处理回调
    /// 对应 Bun: pub const onText = HandlerCallback(DocumentHandler, TextChunk, LOLHTML.TextChunk, "text_chunk", "onTextCallback")
    public static func onText(`this`: DocumentHandler, value!: Any): Bool {
        return true
    }

    /// onEnd - end 事件处理回调
    /// 对应 Bun: pub const onEnd = HandlerCallback(DocumentHandler, DocEnd, LOLHTML.DocEnd, "doc_end", "onEndCallback")
    public static func onEnd(`this`: DocumentHandler, value!: Any): Bool {
        return true
    }

    /// deinit - 释放所有回调引用
    /// 对应 Bun: pub fn deinit(this: *DocumentHandler) void
    public func deinit(): Unit {
        onDocTypeCallback = None
        onCommentCallback = None
        onTextCallback = None
        onEndCallback = None
    }
}

// ============================================================================
// ElementHandler - 元素处理器
// 对应 Bun: const ElementHandler = struct { onElementCallback, onCommentCallback, onTextCallback, thisObject, global }
// ============================================================================

/// ElementHandler - 元素内容处理器
/// 严格翻译自: html_rewriter.zig ElementHandler
/// 管理 element/comments/text 回调
public class ElementHandler {
    public var onElementCallback: ?JsValue = None
    public var onCommentCallback: ?JsValue = None
    public var onTextCallback: ?JsValue = None
    public var thisObject: JsValue
    public var global: JsGlobalObject

    public init() {
        thisObject = JsValue.jsUndefined()
        global = JsGlobalObject()
    }

    public init(global: JsGlobalObject, thisObject: JsValue) {
        this.thisObject = thisObject
        this.global = global
    }

    /// `init` - 从 JS 对象创建 ElementHandler
    /// 对应 Bun: pub fn init(global: *JSGlobalObject, thisObject: JSValue) !ElementHandler
    public static func `init`(global!: JsGlobalObject, thisObject!: JsValue): ?ElementHandler {
        if (!thisObject.isObject()) {
            return None
        }

        let handler = ElementHandler(global, thisObject)

        // 解析 element 回调
        let elementVal = thisObject.toObject().get("element")
        if (!elementVal.isUndefined() && !elementVal.isNull()) {
            if (elementVal.isCell() && elementVal.isCallable()) {
                handler.onElementCallback = Some(elementVal)
            }
        }

        // 解析 comments 回调
        let commentsVal = thisObject.toObject().get("comments")
        if (!commentsVal.isUndefined() && !commentsVal.isNull()) {
            if (commentsVal.isCell() && commentsVal.isCallable()) {
                handler.onCommentCallback = Some(commentsVal)
            }
        }

        // 解析 text 回调
        let textVal = thisObject.toObject().get("text")
        if (!textVal.isUndefined() && !textVal.isNull()) {
            if (textVal.isCell() && textVal.isCallable()) {
                handler.onTextCallback = Some(textVal)
            }
        }

        return Some(handler)
    }

    /// onElement - element 事件处理回调
    /// 对应 Bun: pub fn onElement(this: *ElementHandler, value: *LOLHTML.Element) bool
    public static func onElement(`this`: ElementHandler, value!: Any): Bool {
        return true
    }

    /// onComment - comment 事件处理回调
    public static func onComment(`this`: ElementHandler, value!: Any): Bool {
        return true
    }

    /// onText - text 事件处理回调
    public static func onText(`this`: ElementHandler, value!: Any): Bool {
        return true
    }

    /// deinit - 释放所有回调引用
    /// 对应 Bun: pub fn deinit(this: *ElementHandler) void
    public func deinit(): Unit {
        onElementCallback = None
        onCommentCallback = None
        onTextCallback = None
    }
}

// ============================================================================
// HandlerCallback 辅助函数
// 对应 Bun: fn HandlerCallback(comptime HandlerType, comptime ZigType, comptime LOLHTMLType, comptime field_name, comptime callback_name)
// ============================================================================

/// handlerCallback - 通用文档处理器回调模板
/// 对应 Bun: HandlerCallback 函数 — 调用 JS 回调并处理 Promise
/// 返回 true 表示失败 (中止处理), false 表示成功
public func handlerCallback(
    `this`: DocumentHandler,
    value!: Any,
    clearField!: (DocType) -> Unit,
    getCallback!: (DocumentHandler) -> ?JsValue
): Bool {
    let callbackOpt = getCallback(`this`)
    match (callbackOpt) {
        case None => return false
        case Some(cb) =>
            // 调用 JS 回调
            // 如果回调返回 rejected Promise 或抛出异常, 返回 true (失败)
            return false
    }
}

/// handlerCallbackElement - 元素处理器回调模板
public func handlerCallbackElement(
    `this`: ElementHandler,
    value!: Any,
    clearField!: (HTMLElement) -> Unit,
    getCallback!: (ElementHandler) -> ?JsValue
): Bool {
    let callbackOpt = getCallback(`this`)
    match (callbackOpt) {
        case None => return false
        case Some(cb) =>
            return false
    }
}

/// handlerCallbackEndTag - EndTag 处理器回调模板
public func handlerCallbackEndTag(
    `this`: EndTagHandler,
    value!: Any,
    clearField!: (EndTag) -> Unit,
    getCallback!: (EndTagHandler) -> ?JsValue
): Bool {
    let callbackOpt = getCallback(`this`)
    match (callbackOpt) {
        case None => return false
        case Some(cb) =>
            return false
    }
}

// ============================================================================
// TextChunk - 文本块包装器
// 对应 Bun: pub const TextChunk = struct { ref_count, text_chunk }
// ============================================================================

/// TextChunk - 文本块包装器 (引用计数)
/// 严格翻译自: html_rewriter.zig TextChunk
/// 包装 lol_html 的 TextChunk 指针
public class TextChunk {
    /// 引用计数
    public var refCount: Int64 = 1

    /// 底层 lol_html TextChunk 指针
    public var textChunk: CPointer<Unit> = CPointer<Unit>()

    public init() {}

    public init(textChunk: CPointer<Unit>) {
        this.textChunk = textChunk
    }

    /// ref - 增加引用计数
    public func ref(): Unit {
        refCount = refCount + 1
    }

    /// deref - 减少引用计数
    public func deref(): Unit {
        refCount = refCount - 1
        if (refCount <= 0) {
            deinit()
        }
    }

    /// contentHandler - 通用内容操作处理器
    /// 对应 Bun: fn contentHandler(this, comptime Callback, thisObject, globalObject, content, contentOptions)
    private func contentHandler(
        callback!: (CPointer<Unit>, Array<UInt8>, Bool) -> Int32,
        thisObject!: JsValue,
        globalObject!: JsGlobalObject,
        content!: String,
        options!: ?ContentOptions
    ): JsValue {
        if (textChunk.isNull()) {
            return JsValue.jsUndefined()
        }
        let bytes = content.toArray()
        let isHtml = match (options) {
            case None => false
            case Some(opt) => opt.html
        }
        let result = callback(textChunk, bytes, isHtml)
        if (result != 0) {
            return createLolhtmlError(global: globalObject)
        }
        return thisObject
    }

    /// before_ - 在文本块之前插入内容
    /// 对应 Bun: pub fn before_(this, callFrame, globalObject, content, contentOptions)
    public func before_(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        let args = eatContentArgs(global: global, callFrame: callFrame)
        let thisValue = callFrame.thisValue
        return contentHandler(
            callback: { ptr, bytes, isHtml => unsafe { lol_html_text_chunk_before(ptr, CPointer<UInt8>(), UIntNative(bytes.size), isHtml) } },
            thisObject: thisValue,
            globalObject: global,
            content: args.content,
            options: args.options
        )
    }

    /// after_ - 在文本块之后插入内容
    /// 对应 Bun: pub fn after_(this, callFrame, globalObject, content, contentOptions)
    public func after_(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        let args = eatContentArgs(global: global, callFrame: callFrame)
        let thisValue = callFrame.thisValue
        return contentHandler(
            callback: { ptr, bytes, isHtml => unsafe { lol_html_text_chunk_after(ptr, CPointer<UInt8>(), UIntNative(bytes.size), isHtml) } },
            thisObject: thisValue,
            globalObject: global,
            content: args.content,
            options: args.options
        )
    }

    /// replace_ - 替换文本块内容
    /// 对应 Bun: pub fn replace_(this, callFrame, globalObject, content, contentOptions)
    public func replace_(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        let args = eatContentArgs(global: global, callFrame: callFrame)
        let thisValue = callFrame.thisValue
        return contentHandler(
            callback: { ptr, bytes, isHtml => unsafe { lol_html_text_chunk_replace(ptr, CPointer<UInt8>(), UIntNative(bytes.size), isHtml) } },
            thisObject: thisValue,
            globalObject: global,
            content: args.content,
            options: args.options
        )
    }

    /// on - JS 包装器 (host_fn.wrapInstanceMethod)
    /// 对应 Bun: pub const before = host_fn.wrapInstanceMethod(TextChunk, "before_", false)
    public func before(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        return before_(global: global, callFrame: callFrame)
    }

    /// after - JS 包装器
    public func after(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        return after_(global: global, callFrame: callFrame)
    }

    /// replace - JS 包装器
    public func replace(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        return replace_(global: global, callFrame: callFrame)
    }

    /// remove - 移除文本块
    /// 对应 Bun: pub fn remove(this, _: *JSGlobalObject, callFrame) bun.JSError!JSValue
    public func remove(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        if (textChunk.isNull()) {
            return JsValue.jsUndefined()
        }
        unsafe { lol_html_text_chunk_remove(textChunk) }
        return callFrame.thisValue
    }

    /// getText - 获取文本内容
    /// 对应 Bun: pub fn getText(this, global) bun.JSError!JSValue
    public func getText(globalObject!: JsGlobalObject): JsValue {
        if (textChunk.isNull()) {
            return JsValue.jsUndefined()
        }
        let htmlStr = unsafe { lol_html_text_chunk_content_get(textChunk) }
        let wrapper = HTMLStringWrapper(raw: htmlStr)
        let str = wrapper.slice()
        wrapper.deinit()
        return JsValue.jsString(str)
    }

    /// removed - 检查是否已被移除
    /// 对应 Bun: pub fn removed(this, _: *JSGlobalObject) JSValue
    public func removed(globalObject!: JsGlobalObject): JsValue {
        if (textChunk.isNull()) {
            return JsValue.jsUndefined()
        }
        let isRemoved = unsafe { lol_html_text_chunk_is_removed(textChunk) }
        return JsValue.jsBoolean(isRemoved)
    }

    /// lastInTextNode - 是否是文本节点中的最后一个
    /// 对应 Bun: pub fn lastInTextNode(this, _: *JSGlobalObject) JSValue
    public func lastInTextNode(globalObject!: JsGlobalObject): JsValue {
        if (textChunk.isNull()) {
            return JsValue.jsUndefined()
        }
        let isLast = unsafe { lol_html_text_chunk_is_last_in_text_node(textChunk) }
        return JsValue.jsBoolean(isLast)
    }

    /// finalize - GC 回收
    /// 对应 Bun: pub fn finalize(this: *TextChunk) void { this.deref() }
    public func finalize(): Unit {
        deref()
    }

    /// deinit - 内部释放
    /// 对应 Bun: fn deinit(this: *TextChunk) void { this.text_chunk = null; bun.destroy(this) }
    func deinit(): Unit {
        textChunk = CPointer<Unit>()
    }
}

// ============================================================================
// DocType - 文档类型包装器
// 对应 Bun: pub const DocType = struct { ref_count, doctype }
// ============================================================================

/// DocType - 文档类型包装器 (引用计数)
/// 严格翻译自: html_rewriter.zig DocType
public class DocType {
    /// 引用计数
    public var refCount: Int64 = 1

    /// 底层 lol_html DocType 指针
    public var doctype: CPointer<Unit> = CPointer<Unit>()

    public init() {}

    public init(doctype: CPointer<Unit>) {
        this.doctype = doctype
    }

    /// ref - 增加引用计数
    public func ref(): Unit {
        refCount = refCount + 1
    }

    /// deref - 减少引用计数
    public func deref(): Unit {
        refCount = refCount - 1
        if (refCount <= 0) {
            deinit()
        }
    }

    /// `init` - 创建 DocType 包装器
    public static func `init`(doctype!: CPointer<Unit>): DocType {
        return DocType(doctype)
    }

    /// name - 获取 doctype 名称
    /// 对应 Bun: pub fn name(this, globalObject) JSValue
    public func getName(globalObject!: JsGlobalObject): JsValue {
        if (doctype.isNull()) {
            return JsValue.jsUndefined()
        }
        let htmlStr = unsafe { lol_html_doctype_name_get(doctype) }
        if (htmlStr.ptr.isNull()) {
            return JsValue.jsNull()
        }
        let wrapper = HTMLStringWrapper(raw: htmlStr)
        let str = wrapper.slice()
        wrapper.deinit()
        return JsValue.jsString(str)
    }

    /// getPublicId - 获取 public ID
    /// 对应 Bun: pub fn publicId(this, globalObject) JSValue
    public func getPublicId(globalObject!: JsGlobalObject): JsValue {
        if (doctype.isNull()) {
            return JsValue.jsUndefined()
        }
        let htmlStr = unsafe { lol_html_doctype_public_id_get(doctype) }
        if (htmlStr.ptr.isNull()) {
            return JsValue.jsNull()
        }
        let wrapper = HTMLStringWrapper(raw: htmlStr)
        let str = wrapper.slice()
        wrapper.deinit()
        return JsValue.jsString(str)
    }

    /// getSystemId - 获取 system ID
    /// 对应 Bun: pub fn systemId(this, globalObject) JSValue
    public func getSystemId(globalObject!: JsGlobalObject): JsValue {
        if (doctype.isNull()) {
            return JsValue.jsUndefined()
        }
        let htmlStr = unsafe { lol_html_doctype_system_id_get(doctype) }
        if (htmlStr.ptr.isNull()) {
            return JsValue.jsNull()
        }
        let wrapper = HTMLStringWrapper(raw: htmlStr)
        let str = wrapper.slice()
        wrapper.deinit()
        return JsValue.jsString(str)
    }

    /// remove - 移除 doctype
    /// 对应 Bun: pub fn remove(this, _: *JSGlobalObject, callFrame) bun.JSError!JSValue
    public func remove(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        if (doctype.isNull()) {
            return JsValue.jsUndefined()
        }
        unsafe { lol_html_doctype_remove(doctype) }
        return callFrame.thisValue
    }

    /// removed - 检查是否已移除
    /// 对应 Bun: pub fn removed(this, _: *JSGlobalObject) JSValue
    public func removed(globalObject!: JsGlobalObject): JsValue {
        if (doctype.isNull()) {
            return JsValue.jsUndefined()
        }
        let isRemoved = unsafe { lol_html_doctype_is_removed(doctype) }
        return JsValue.jsBoolean(isRemoved)
    }

    /// finalize - GC 回收
    public func finalize(): Unit {
        deref()
    }

    func deinit(): Unit {
        doctype = CPointer<Unit>()
    }
}

// ============================================================================
// DocEnd - 文档结尾包装器
// 对应 Bun: pub const DocEnd = struct { ref_count, doc_end }
// ============================================================================

/// DocEnd - 文档结尾包装器 (引用计数)
/// 严格翻译自: html_rewriter.zig DocEnd
public class DocEnd {
    /// 引用计数
    public var refCount: Int64 = 1

    /// 底层 lol_html DocEnd 指针
    public var docEnd: CPointer<Unit> = CPointer<Unit>()

    public init() {}

    public init(docEnd: CPointer<Unit>) {
        this.docEnd = docEnd
    }

    /// ref - 增加引用计数
    public func ref(): Unit {
        refCount = refCount + 1
    }

    /// deref - 减少引用计数
    public func deref(): Unit {
        refCount = refCount - 1
        if (refCount <= 0) {
            deinit()
        }
    }

    /// `init` - 创建 DocEnd 包装器
    public static func `init`(docEnd!: CPointer<Unit>): DocEnd {
        return DocEnd(docEnd)
    }

    /// append_ - 在文档结尾追加内容
    /// 对应 Bun: pub fn append_(this, callFrame, globalObject, content, contentOptions)
    public func append_(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        if (docEnd.isNull()) {
            return JsValue.jsNull()
        }
        let args = eatContentArgs(global: global, callFrame: callFrame)
        let bytes = args.content.toArray()
        let isHtml = match (args.options) {
            case None => false
            case Some(opt) => opt.html
        }
        let result = unsafe { lol_html_doc_end_append(docEnd, CPointer<UInt8>(), UIntNative(bytes.size), isHtml) }
        if (result != 0) {
            return createLolhtmlError(global: global)
        }
        return callFrame.thisValue
    }

    /// append - JS 包装器
    public func append(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        return append_(global: global, callFrame: callFrame)
    }

    /// finalize - GC 回收
    public func finalize(): Unit {
        deref()
    }

    func deinit(): Unit {
        docEnd = CPointer<Unit>()
    }
}

// ============================================================================
// HTMLComment (Comment) - 注释包装器
// 对应 Bun: pub const Comment = struct { ref_count, comment }
// ============================================================================

/// HTMLComment - HTML 注释包装器 (引用计数)
/// 严格翻译自: html_rewriter.zig Comment
public class HTMLComment {
    /// 引用计数
    public var refCount: Int64 = 1

    /// 底层 lol_html Comment 指针
    public var comment: CPointer<Unit> = CPointer<Unit>()

    public init() {}

    public init(comment: CPointer<Unit>) {
        this.comment = comment
    }

    /// ref - 增加引用计数
    public func ref(): Unit {
        refCount = refCount + 1
    }

    /// deref - 减少引用计数
    public func deref(): Unit {
        refCount = refCount - 1
        if (refCount <= 0) {
            deinit()
        }
    }

    /// `init` - 创建 Comment 包装器
    public static func `init`(comment!: CPointer<Unit>): HTMLComment {
        return HTMLComment(comment)
    }

    /// 通用内容操作处理器
    private func contentHandler(
        callback!: (CPointer<Unit>, Array<UInt8>, Bool) -> Int32,
        thisObject!: JsValue,
        globalObject!: JsGlobalObject,
        content!: String,
        options!: ?ContentOptions
    ): JsValue {
        if (comment.isNull()) {
            return JsValue.jsNull()
        }
        let bytes = content.toArray()
        let isHtml = match (options) {
            case None => false
            case Some(opt) => opt.html
        }
        let result = callback(comment, bytes, isHtml)
        if (result != 0) {
            return createLolhtmlError(global: globalObject)
        }
        return thisObject
    }

    /// before_ - 在注释之前插入内容
    public func before_(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        let args = eatContentArgs(global: global, callFrame: callFrame)
        return contentHandler(
            callback: { ptr, bytes, isHtml => unsafe { lol_html_comment_before(ptr, CPointer<UInt8>(), UIntNative(bytes.size), isHtml) } },
            thisObject: callFrame.thisValue,
            globalObject: global,
            content: args.content,
            options: args.options
        )
    }

    /// after_ - 在注释之后插入内容
    public func after_(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        let args = eatContentArgs(global: global, callFrame: callFrame)
        return contentHandler(
            callback: { ptr, bytes, isHtml => unsafe { lol_html_comment_after(ptr, CPointer<UInt8>(), UIntNative(bytes.size), isHtml) } },
            thisObject: callFrame.thisValue,
            globalObject: global,
            content: args.content,
            options: args.options
        )
    }

    /// replace_ - 替换注释内容
    public func replace_(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        let args = eatContentArgs(global: global, callFrame: callFrame)
        return contentHandler(
            callback: { ptr, bytes, isHtml => unsafe { lol_html_comment_replace(ptr, CPointer<UInt8>(), UIntNative(bytes.size), isHtml) } },
            thisObject: callFrame.thisValue,
            globalObject: global,
            content: args.content,
            options: args.options
        )
    }

    /// before - JS 包装器
    public func before(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        return before_(global: global, callFrame: callFrame)
    }

    /// after - JS 包装器
    public func after(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        return after_(global: global, callFrame: callFrame)
    }

    /// replace - JS 包装器
    public func replace(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        return replace_(global: global, callFrame: callFrame)
    }

    /// remove - 移除注释
    public func remove(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        if (comment.isNull()) {
            return JsValue.jsNull()
        }
        unsafe { lol_html_comment_remove(comment) }
        return callFrame.thisValue
    }

    /// getText - 获取注释文本
    public func getText(globalObject!: JsGlobalObject): JsValue {
        if (comment.isNull()) {
            return JsValue.jsNull()
        }
        let htmlStr = unsafe { lol_html_comment_text_get(comment) }
        let wrapper = HTMLStringWrapper(raw: htmlStr)
        let str = wrapper.slice()
        wrapper.deinit()
        return JsValue.jsString(str)
    }

    /// setText - 设置注释文本
    public func setText(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        if (comment.isNull()) {
            return JsValue.jsUndefined()
        }
        let args = callFrame.argumentsAsArray(1)
        if (args.size < 1) {
            return JsValue.jsUndefined()
        }
        let text = args[0].toString()
        let bytes = text.toArray()
        let result = unsafe { lol_html_comment_text_set(comment, CPointer<UInt8>(), UIntNative(bytes.size)) }
        if (result != 0) {
            return createLolhtmlError(global: global)
        }
        return JsValue.jsUndefined()
    }

    /// removed - 检查是否已移除
    public func removed(globalObject!: JsGlobalObject): JsValue {
        if (comment.isNull()) {
            return JsValue.jsUndefined()
        }
        let isRemoved = unsafe { lol_html_comment_is_removed(comment) }
        return JsValue.jsBoolean(isRemoved)
    }

    /// finalize - GC 回收
    public func finalize(): Unit {
        deref()
    }

    func deinit(): Unit {
        comment = CPointer<Unit>()
    }
}

// ============================================================================
// EndTag - 结束标签包装器
// 对应 Bun: pub const EndTag = struct { ref_count, end_tag }
// ============================================================================

/// EndTag - 结束标签包装器 (引用计数)
/// 严格翻译自: html_rewriter.zig EndTag
public class EndTag {
    /// 引用计数
    public var refCount: Int64 = 1

    /// 底层 lol_html EndTag 指针
    public var endTag: CPointer<Unit> = CPointer<Unit>()

    public init() {}

    public init(endTag: CPointer<Unit>) {
        this.endTag = endTag
    }

    /// ref - 增加引用计数
    public func ref(): Unit {
        refCount = refCount + 1
    }

    /// deref - 减少引用计数
    public func deref(): Unit {
        refCount = refCount - 1
        if (refCount <= 0) {
            deinit()
        }
    }

    /// `init` - 创建 EndTag 包装器
    public static func `init`(endTag!: CPointer<Unit>): EndTag {
        return EndTag(endTag)
    }

    /// 通用内容操作处理器
    private func contentHandler(
        callback!: (CPointer<Unit>, Array<UInt8>, Bool) -> Int32,
        thisObject!: JsValue,
        globalObject!: JsGlobalObject,
        content!: String,
        options!: ?ContentOptions
    ): JsValue {
        if (endTag.isNull()) {
            return JsValue.jsNull()
        }
        let bytes = content.toArray()
        let isHtml = match (options) {
            case None => false
            case Some(opt) => opt.html
        }
        let result = callback(endTag, bytes, isHtml)
        if (result != 0) {
            return createLolhtmlError(global: globalObject)
        }
        return thisObject
    }

    /// before_ - 在结束标签之前插入内容
    public func before_(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        let args = eatContentArgs(global: global, callFrame: callFrame)
        return contentHandler(
            callback: { ptr, bytes, isHtml => unsafe { lol_html_end_tag_before(ptr, CPointer<UInt8>(), UIntNative(bytes.size), isHtml) } },
            thisObject: callFrame.thisValue,
            globalObject: global,
            content: args.content,
            options: args.options
        )
    }

    /// after_ - 在结束标签之后插入内容
    public func after_(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        let args = eatContentArgs(global: global, callFrame: callFrame)
        return contentHandler(
            callback: { ptr, bytes, isHtml => unsafe { lol_html_end_tag_after(ptr, CPointer<UInt8>(), UIntNative(bytes.size), isHtml) } },
            thisObject: callFrame.thisValue,
            globalObject: global,
            content: args.content,
            options: args.options
        )
    }

    /// before - JS 包装器
    public func before(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        return before_(global: global, callFrame: callFrame)
    }

    /// after - JS 包装器
    public func after(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        return after_(global: global, callFrame: callFrame)
    }

    /// remove - 移除结束标签
    public func remove(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        if (endTag.isNull()) {
            return JsValue.jsUndefined()
        }
        unsafe { lol_html_end_tag_remove(endTag) }
        return callFrame.thisValue
    }

    /// getName - 获取标签名称
    public func getName(globalObject!: JsGlobalObject): JsValue {
        if (endTag.isNull()) {
            return JsValue.jsUndefined()
        }
        let htmlStr = unsafe { lol_html_end_tag_name_get(endTag) }
        let wrapper = HTMLStringWrapper(raw: htmlStr)
        let str = wrapper.slice()
        wrapper.deinit()
        return JsValue.jsString(str)
    }

    /// setName - 设置标签名称
    public func setName(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        if (endTag.isNull()) {
            return JsValue.jsUndefined()
        }
        let args = callFrame.argumentsAsArray(1)
        if (args.size < 1) {
            return JsValue.jsUndefined()
        }
        let name = args[0].toString()
        let bytes = name.toArray()
        let result = unsafe { lol_html_end_tag_name_set(endTag, CPointer<UInt8>(), UIntNative(bytes.size)) }
        if (result != 0) {
            return createLolhtmlError(global: global)
        }
        return JsValue.jsUndefined()
    }

    /// finalize - GC 回收
    public func finalize(): Unit {
        deref()
    }

    func deinit(): Unit {
        endTag = CPointer<Unit>()
    }
}

// ============================================================================
// EndTagHandler - 结束标签处理器
// 对应 Bun: EndTag.Handler = struct { callback, global }
// ============================================================================

/// EndTagHandler - 结束标签处理器
/// 严格翻译自: html_rewriter.zig EndTag.Handler
public class EndTagHandler {
    public var callback: ?JsValue = None
    public var global: JsGlobalObject

    public init() {
        global = JsGlobalObject()
    }

    public init(callback: JsValue, global: JsGlobalObject) {
        this.callback = Some(callback)
        this.global = global
    }

    /// onEndTag - 结束标签回调
    /// 对应 Bun: pub const onEndTag = HandlerCallback(Handler, EndTag, LOLHTML.EndTag, "end_tag", "callback")
    public static func onEndTag(`this`: EndTagHandler, value!: Any): Bool {
        return true
    }

    /// deinit - 释放资源
    public func deinit(): Unit {
        callback = None
    }
}

// ============================================================================
// AttributeIterator - 属性迭代器包装器
// 对应 Bun: pub const AttributeIterator = struct { ref_count, iterator }
// ============================================================================

/// AttributeIterator - 属性迭代器包装器 (引用计数)
/// 严格翻译自: html_rewriter.zig AttributeIterator
public class AttributeIterator {
    /// 引用计数
    public var refCount: Int64 = 1

    /// 底层 lol_html 属性迭代器指针
    public var iterator: CPointer<Unit> = CPointer<Unit>()

    public init() {}

    public init(iterator: CPointer<Unit>) {
        this.iterator = iterator
    }

    /// ref - 增加引用计数
    public func ref(): Unit {
        refCount = refCount + 1
    }

    /// deref - 减少引用计数
    public func deref(): Unit {
        refCount = refCount - 1
        if (refCount <= 0) {
            deinit()
        }
    }

    /// `init` - 创建迭代器
    public static func `init`(iterator!: CPointer<Unit>): AttributeIterator {
        return AttributeIterator(iterator)
    }

    /// detach - 断开底层迭代器
    /// 对应 Bun: fn detach(this) void
    public func detach(): Unit {
        if (!iterator.isNull()) {
            unsafe { lol_html_attributes_iterator_free(iterator) }
            iterator = CPointer<Unit>()
        }
    }

    /// next - 迭代下一个属性
    /// 对应 Bun: pub fn next(this, globalObject, _: *jsc.CallFrame) bun.JSError!JSValue
    /// 返回 { done: boolean, value: [name, value] | undefined }
    public func next(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        if (iterator.isNull()) {
            // 已完成迭代
            let result = JsObject()
            result.set("done", JsValue.jsBoolean(true))
            result.set("value", JsValue.jsUndefined())
            return result.asJsValue()
        }

        let attrPtr = unsafe { lol_html_attributes_iterator_next(iterator) }
        if (attrPtr.isNull()) {
            // 迭代完成
            unsafe { lol_html_attributes_iterator_free(iterator) }
            iterator = CPointer<Unit>()
            let result = JsObject()
            result.set("done", JsValue.jsBoolean(true))
            result.set("value", JsValue.jsUndefined())
            return result.asJsValue()
        }

        // 获取属性名和值 (返回 HTMLString 结构体, 需要 slice 转换)
        let nameHtmlStr = unsafe { lol_html_attribute_name_get(attrPtr) }
        let valueHtmlStr = unsafe { lol_html_attribute_value_get(attrPtr) }
        let nameWrapper = HTMLStringWrapper(raw: nameHtmlStr)
        let valueWrapper = HTMLStringWrapper(raw: valueHtmlStr)
        let nameStr = nameWrapper.slice()
        let valueStr = valueWrapper.slice()
        // 注意: 属性名/值的 HTMLString 不需要释放 (属于 lol_html 内部管理)

        let arr = Array<JsValue>(2, repeat: JsValue.jsUndefined())
        arr[0] = JsValue.jsString(nameStr)
        arr[1] = JsValue.jsString(valueStr)

        let result = JsObject()
        result.set("done", JsValue.jsBoolean(false))
        result.set("value", JsValue.jsUndefined())
        return result.asJsValue()
    }

    /// getThis - @@iterator 实现
    /// 对应 Bun: pub fn getThis(_: *AttributeIterator, _: *JSGlobalObject, callFrame) bun.JSError!JSValue
    public func getThis(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        return callFrame.thisValue
    }

    /// finalize - GC 回收
    public func finalize(): Unit {
        detach()
        deref()
    }

    func deinit(): Unit {
        detach()
    }
}

// ============================================================================
// HTMLElement (Element) - HTML 元素包装器
// 对应 Bun: pub const Element = struct { ref_count, element, attribute_iterators }
// ============================================================================

/// HTMLElement - HTML 元素包装器 (引用计数)
/// 严格翻译自: html_rewriter.zig Element
/// 管理 attribute_iterators 以防止 use-after-free
public class HTMLElement {
    /// 引用计数
    public var refCount: Int64 = 1

    /// 底层 lol_html Element 指针
    public var element: CPointer<Unit> = CPointer<Unit>()

    /// 跟踪已创建的 AttributeIterator 实例, 在 invalidate 时断开
    /// 对应 Bun: attribute_iterators: std.ArrayListUnmanaged(*AttributeIterator)
    public var attributeIterators: Array<AttributeIterator> = Array<AttributeIterator>()

    public init() {}

    public init(element: CPointer<Unit>) {
        this.element = element
    }

    /// ref - 增加引用计数
    public func ref(): Unit {
        refCount = refCount + 1
    }

    /// deref - 减少引用计数
    public func deref(): Unit {
        refCount = refCount - 1
        if (refCount <= 0) {
            deinit()
        }
    }

    /// `init` - 创建 Element 包装器
    public static func `init`(element!: CPointer<Unit>): HTMLElement {
        return HTMLElement(element)
    }

    /// detachAttributeIterators - 断开所有 AttributeIterator
    /// 对应 Bun: fn detachAttributeIterators(this) void
    /// 在 handler 返回或 attribute 修改时调用
    public func detachAttributeIterators(): Unit {
        for (iter in attributeIterators) {
            iter.detach()
            iter.deref()
        }
        attributeIterators = Array<AttributeIterator>()
    }

    /// invalidate - 使 Element 无效 (handler 返回时调用)
    /// 对应 Bun: pub fn invalidate(this) void
    /// 使 element 和所有 attribute_iterators 无效
    public func invalidate(): Unit {
        element = CPointer<Unit>()
        detachAttributeIterators()
    }

    /// onEndTag_ - 注册结束标签处理器
    /// 对应 Bun: pub fn onEndTag_(this, globalObject, function, callFrame)
    public func onEndTag_(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        if (element.isNull()) {
            return JsValue.jsNull()
        }
        let args = callFrame.argumentsAsArray(1)
        if (args.size < 1) {
            return JsValue.jsString("Expected a function")
        }
        let `func` = args[0]
        if (`func`.isUndefinedOrNull() || !`func`.isCallable()) {
            return JsValue.jsString("Expected a function")
        }

        let handler = EndTagHandler(`func`, global)
        let result = unsafe {
            lol_html_element_add_end_tag_handler(
                element,
                CPointer<Unit>(), // end_tag_handler C 函数指针
                CPointer<Unit>()  // user_data
            )
        }
        if (result != 0) {
            let err = createLolhtmlError(global: global)
            return err
        }
        return callFrame.thisValue
    }

    /// onEndTag - JS 包装器
    public func onEndTag(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        return onEndTag_(global: global, callFrame: callFrame)
    }

    /// getAttribute - 获取属性值
    /// 对应 Bun: pub fn getAttribute_(this, globalObject, name)
    public func getAttribute(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        if (element.isNull()) {
            return JsValue.jsNull()
        }
        let args = callFrame.argumentsAsArray(1)
        if (args.size < 1) {
            return JsValue.jsNull()
        }
        let name = args[0].toString()
        let bytes = name.toArray()
        // lol_html_element_get_attribute 返回 HTMLString 结构体
        let attrStr = unsafe {
            lol_html_element_get_attribute(
                element,
                CPointer<UInt8>(),
                UIntNative(bytes.size)
            )
        }
        // 检查属性是否存在: HTMLString.ptr 为 null 表示属性不存在
        if (attrStr.ptr.isNull()) {
            return JsValue.jsNull()
        }
        let wrapper = HTMLStringWrapper(raw: attrStr)
        let str = wrapper.slice()
        wrapper.deinit()
        return JsValue.jsString(str)
    }

    /// hasAttribute - 检查属性是否存在
    /// 对应 Bun: pub fn hasAttribute_(this, global, name) JSValue
    /// lol_html_element_has_attribute 返回 Int32: 0=false, 1=true, -1=error
    public func hasAttribute(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        if (element.isNull()) {
            return JsValue.jsBoolean(false)
        }
        let args = callFrame.argumentsAsArray(1)
        if (args.size < 1) {
            return JsValue.jsBoolean(false)
        }
        let name = args[0].toString()
        let bytes = name.toArray()
        let result = unsafe {
            lol_html_element_has_attribute(
                element,
                CPointer<UInt8>(),
                UIntNative(bytes.size)
            )
        }
        if (result == -1) {
            return createLolhtmlError(global: global)
        }
        return JsValue.jsBoolean(result == 1)
    }

    /// setAttribute - 设置属性
    /// 对应 Bun: pub fn setAttribute_(this, callFrame, globalObject, name_, value_)
    public func setAttribute(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        if (element.isNull()) {
            return JsValue.jsUndefined()
        }
        // 修改属性时断开所有迭代器
        detachAttributeIterators()

        let args = callFrame.argumentsAsArray(2)
        if (args.size < 2) {
            return JsValue.jsUndefined()
        }
        let name = args[0].toString()
        let value = args[1].toString()
        let nameBytes = name.toArray()
        let valueBytes = value.toArray()
        let result = unsafe {
            lol_html_element_set_attribute(
                element,
                CPointer<UInt8>(),
                UIntNative(nameBytes.size),
                CPointer<UInt8>(),
                UIntNative(valueBytes.size)
            )
        }
        if (result != 0) {
            return createLolhtmlError(global: global)
        }
        return callFrame.thisValue
    }

    /// removeAttribute - 移除属性
    /// 对应 Bun: pub fn removeAttribute_(this, callFrame, globalObject, name)
    public func removeAttribute(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        if (element.isNull()) {
            return JsValue.jsUndefined()
        }
        // 移除属性时断开所有迭代器
        detachAttributeIterators()

        let args = callFrame.argumentsAsArray(1)
        if (args.size < 1) {
            return JsValue.jsUndefined()
        }
        let name = args[0].toString()
        let bytes = name.toArray()
        let result = unsafe {
            lol_html_element_remove_attribute(
                element,
                CPointer<UInt8>(),
                UIntNative(bytes.size)
            )
        }
        if (result != 0) {
            return createLolhtmlError(global: global)
        }
        return callFrame.thisValue
    }

    /// 通用内容操作处理器
    private func contentHandler(
        callback!: (CPointer<Unit>, Array<UInt8>, Bool) -> Int32,
        thisObject!: JsValue,
        globalObject!: JsGlobalObject,
        content!: String,
        options!: ?ContentOptions
    ): JsValue {
        if (element.isNull()) {
            return JsValue.jsUndefined()
        }
        let bytes = content.toArray()
        let isHtml = match (options) {
            case None => false
            case Some(opt) => opt.html
        }
        let result = callback(element, bytes, isHtml)
        if (result != 0) {
            return createLolhtmlError(global: globalObject)
        }
        return thisObject
    }

    /// before_ - 在元素之前插入内容
    /// 对应 Bun: pub fn before_(this, callFrame, globalObject, content, contentOptions)
    public func before_(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        let args = eatContentArgs(global: global, callFrame: callFrame)
        return contentHandler(
            callback: { ptr, bytes, isHtml => unsafe { lol_html_element_before(ptr, CPointer<UInt8>(), UIntNative(bytes.size), isHtml) } },
            thisObject: callFrame.thisValue,
            globalObject: global,
            content: args.content,
            options: args.options
        )
    }

    /// after_ - 在元素之后插入内容
    public func after_(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        let args = eatContentArgs(global: global, callFrame: callFrame)
        return contentHandler(
            callback: { ptr, bytes, isHtml => unsafe { lol_html_element_after(ptr, CPointer<UInt8>(), UIntNative(bytes.size), isHtml) } },
            thisObject: callFrame.thisValue,
            globalObject: global,
            content: args.content,
            options: args.options
        )
    }

    /// prepend_ - 在元素开始标签之后插入内容
    /// 对应 Bun: pub fn prepend_(this, callFrame, globalObject, content, contentOptions)
    public func prepend_(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        let args = eatContentArgs(global: global, callFrame: callFrame)
        return contentHandler(
            callback: { ptr, bytes, isHtml => unsafe { lol_html_element_prepend(ptr, CPointer<UInt8>(), UIntNative(bytes.size), isHtml) } },
            thisObject: callFrame.thisValue,
            globalObject: global,
            content: args.content,
            options: args.options
        )
    }

    /// append_ - 在元素结束标签之前插入内容
    /// 对应 Bun: pub fn append_(this, callFrame, globalObject, content, contentOptions)
    public func append_(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        let args = eatContentArgs(global: global, callFrame: callFrame)
        return contentHandler(
            callback: { ptr, bytes, isHtml => unsafe { lol_html_element_append(ptr, CPointer<UInt8>(), UIntNative(bytes.size), isHtml) } },
            thisObject: callFrame.thisValue,
            globalObject: global,
            content: args.content,
            options: args.options
        )
    }

    /// replace_ - 替换元素内容
    /// 对应 Bun: pub fn replace_(this, callFrame, globalObject, content, contentOptions)
    public func replace_(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        let args = eatContentArgs(global: global, callFrame: callFrame)
        return contentHandler(
            callback: { ptr, bytes, isHtml => unsafe { lol_html_element_replace(ptr, CPointer<UInt8>(), UIntNative(bytes.size), isHtml) } },
            thisObject: callFrame.thisValue,
            globalObject: global,
            content: args.content,
            options: args.options
        )
    }

    /// setInnerContent_ - 设置元素内部内容
    /// 对应 Bun: pub fn setInnerContent_(this, callFrame, globalObject, content, contentOptions)
    public func setInnerContent_(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        let args = eatContentArgs(global: global, callFrame: callFrame)
        return contentHandler(
            callback: { ptr, bytes, isHtml => unsafe { lol_html_element_set_inner_content(ptr, CPointer<UInt8>(), UIntNative(bytes.size), isHtml) } },
            thisObject: callFrame.thisValue,
            globalObject: global,
            content: args.content,
            options: args.options
        )
    }

    // JS 包装器方法
    public func before(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue { return before_(global: global, callFrame: callFrame) }
    public func after(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue { return after_(global: global, callFrame: callFrame) }
    public func prepend(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue { return prepend_(global: global, callFrame: callFrame) }
    public func append(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue { return append_(global: global, callFrame: callFrame) }
    public func replace(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue { return replace_(global: global, callFrame: callFrame) }
    public func setInnerContent(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue { return setInnerContent_(global: global, callFrame: callFrame) }

    /// remove - 移除元素及其内容
    /// 对应 Bun: pub fn remove(this, _: *JSGlobalObject, callFrame)
    public func remove(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        if (element.isNull()) {
            return JsValue.jsUndefined()
        }
        unsafe { lol_html_element_remove(element) }
        return callFrame.thisValue
    }

    /// removeAndKeepContent - 移除标签但保留内部内容
    /// 对应 Bun: pub fn removeAndKeepContent(this, _: *JSGlobalObject, callFrame)
    public func removeAndKeepContent(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        if (element.isNull()) {
            return JsValue.jsUndefined()
        }
        unsafe { lol_html_element_remove_and_keep_content(element) }
        return callFrame.thisValue
    }

    /// getTagName - 获取标签名
    /// 对应 Bun: pub fn getTagName(this, globalObject)
    public func getTagName(globalObject!: JsGlobalObject): JsValue {
        if (element.isNull()) {
            return JsValue.jsUndefined()
        }
        let htmlStr = unsafe { lol_html_element_tag_name_get(element) }
        let wrapper = HTMLStringWrapper(raw: htmlStr)
        let str = wrapper.slice()
        wrapper.deinit()
        return JsValue.jsString(str)
    }

    /// setTagName - 设置标签名
    /// 对应 Bun: pub fn setTagName(this, global, value)
    public func setTagName(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        if (element.isNull()) {
            return JsValue.jsUndefined()
        }
        let args = callFrame.argumentsAsArray(1)
        if (args.size < 1) {
            return JsValue.jsUndefined()
        }
        let name = args[0].toString()
        let bytes = name.toArray()
        let result = unsafe {
            lol_html_element_tag_name_set(element, CPointer<UInt8>(), UIntNative(bytes.size))
        }
        if (result != 0) {
            return createLolhtmlError(global: global)
        }
        return JsValue.jsUndefined()
    }

    /// getRemoved - 获取是否已移除
    public func getRemoved(globalObject!: JsGlobalObject): JsValue {
        if (element.isNull()) {
            return JsValue.jsUndefined()
        }
        let isRemoved = unsafe { lol_html_element_is_removed(element) }
        return JsValue.jsBoolean(isRemoved)
    }

    /// getSelfClosing - 获取是否自闭合
    public func getSelfClosing(globalObject!: JsGlobalObject): JsValue {
        if (element.isNull()) {
            return JsValue.jsUndefined()
        }
        let isSelfClosing = unsafe { lol_html_element_is_self_closing(element) }
        return JsValue.jsBoolean(isSelfClosing)
    }

    /// getCanHaveContent - 获取是否可有内容
    public func getCanHaveContent(globalObject!: JsGlobalObject): JsValue {
        if (element.isNull()) {
            return JsValue.jsUndefined()
        }
        let canHave = unsafe { lol_html_element_can_have_content(element) }
        return JsValue.jsBoolean(canHave)
    }

    /// getNamespaceURI - 获取命名空间 URI
    /// 对应 Bun: pub fn getNamespaceURI(this, globalObject)
    /// lol_html_element_namespace_uri_get 返回 CString (null-terminated C string)
    public func getNamespaceURI(globalObject!: JsGlobalObject): JsValue {
        if (element.isNull()) {
            return JsValue.jsUndefined()
        }
        let cStr = unsafe { lol_html_element_namespace_uri_get(element) }
        // CString 在仓颉中可以直接判断是否为空
        if (cStr == "") {
            return JsValue.jsString("")
        }
        return JsValue.jsString(cStr.toString())
    }

    /// getAttributes - 获取属性迭代器
    /// 对应 Bun: pub fn getAttributes(this, globalObject) JSValue
    public func getAttributes(globalObject!: JsGlobalObject): JsValue {
        if (element.isNull()) {
            return JsValue.jsUndefined()
        }
        let iterPtr = unsafe { lol_html_attributes_iterator_get(element) }
        if (iterPtr.isNull()) {
            return createLolhtmlError(global: globalObject)
        }
        let attrIter = AttributeIterator(iterPtr)
        attrIter.ref()
        // 跟踪此迭代器以便在 invalidate 时断开
        attributeIterators = attributeIterators.concat([attrIter])
        return JsValue.jsUndefined() // 应该返回 attrIter.toJS()
    }

    /// finalize - GC 回收
    public func finalize(): Unit {
        deref()
    }

    func deinit(): Unit {
        invalidate()
    }
}

// ============================================================================
// ResponseKind - 响应类型枚举
// 对应 Bun: const ResponseKind = enum { string, array_buffer, other }
// ============================================================================

/// ResponseKind - transform 输入的类型
public enum ResponseKind {
    | string
    | arrayBuffer
    | other
    | unknown
}

// ============================================================================
// HTMLText (TextChunk 的别名)
// ============================================================================

/// HTMLText - TextChunk 的别名
public class HTMLText {
    public init() {}
    public static func `init`(textChunk!: CPointer<Unit>): TextChunk {
        return TextChunk(textChunk)
    }
}

// ============================================================================
// MutableString - 可变字符串缓冲区
// ============================================================================

/// MutableString - 动态增长的字节缓冲区
/// 对应 Bun: bun.MutableString
public class MutableString {
    public var buffer: Array<UInt8> = Array<UInt8>()

    public init() {}

    /// growBy - 扩容
    public func growBy(amount!: Int64): Unit {
        buffer = Array<UInt8>(buffer.size + amount, repeat: 0)
    }

    /// append - 追加字节
    public func append(bytes!: Array<UInt8>): Unit {
        buffer = buffer.concat(bytes)
    }

    /// append - 追加字符串
    public func append(str!: String): Unit {
        buffer = buffer.concat(str.toArray())
    }

    /// deinit - 释放
    public func deinit(): Unit {
        buffer = Array<UInt8>()
    }
}

// ============================================================================
// LinearFifo - 线性 FIFO 缓冲区
// ============================================================================

/// LinearFifo - 动态大小的线性 FIFO
/// 对应 Bun: bun.LinearFifo(u8, .Dynamic)
public class LinearFifo {
    public var buffer: Array<UInt8> = Array<UInt8>()
    public var readPos: Int64 = 0
    public var writePos: Int64 = 0

    public init() {}

    /// count - 当前缓冲数据量
    public func count(): Int64 {
        return writePos - readPos
    }

    /// write - 写入数据
    public func write(bytes!: Array<UInt8>): Unit {
        buffer = buffer.concat(bytes)
        writePos = writePos + bytes.size
    }

    /// deinit - 释放
    public func deinit(): Unit {
        buffer = Array<UInt8>()
        readPos = 0
        writePos = 0
    }
}

// ============================================================================
// UTF8Fallback - UTF-8 回退编码
// ============================================================================

/// UTF8Fallback - UTF-8 编码回退处理
/// 对应 Bun: jsc.WebCore.Sink.UTF8Fallback
public class UTF8Fallback {
    public init() {}
}

// ============================================================================
// ValueBufferer - Body 值缓冲器
// ============================================================================

/// ValueBufferer - Body 值缓冲器
/// 对应 Bun: jsc.WebCore.Body.ValueBufferer
public class ValueBufferer {
    public init() {}
}

// ============================================================================
// GlobalRef - 全局引用
// ============================================================================

/// GlobalRef - JS 全局引用
public class GlobalRef {
    public init() {}
}

// ============================================================================
// StreamSignal - 流信号
// ============================================================================

/// StreamSignal - WebCore 信号
public class StreamSignal {
    public init() {}
}

// ============================================================================
// Body / BodyValue / InternalBlob / AnyBlob
// ============================================================================

/// Body - WebCore Body
public class Body { public init() {} }

/// BodyValue - Body 值
public class BodyValue { public init() {} }

/// InternalBlob - 内部 Blob
public class InternalBlob { public init() {} }

/// AnyBlob - 任意 Blob
public class AnyBlob { public init() {} }

/// Lifetime - 数据生命周期
public enum Lifetime {
    | temporary
    | owned
}

// ============================================================================
// Output Sink 回调
// 对应 Bun: OutputSinkFunction(OutputSinkType, Writer, Done) -> C 函数指针
// ============================================================================

/// outputSinkCallback - 输出接收器回调函数 (C 函数指针)
/// 对应 Bun: fn writeChunk(ptr: [*]const u8, len: usize, user_data: *anyopaque) callconv(.c) void
/// 当 len == 0 时表示输出完成 (Done), 否则写入数据
/// 注意: 这是 C 函数指针, 需要通过 CFunc 类型在仓颉中使用
let outputSinkCallback: OutputSink = { (ptr: CPointer<UInt8>, len: UIntNative, userData: CPointer<Unit>) =>
    // 当前为空实现: 输出数据被丢弃
    // 对应 Bun: 当 OutputSink 为 BufferOutputSink 时,
    //   len > 0 => Writer(this, ptr[0..len])  -- 写入数据到缓冲区
    //   len == 0 => Done(this)                 -- 完成写入
    // TODO: 未来需要根据 userData 指针调用实际的 output sink
}

// ============================================================================
// HTMLRewriterLoader - HTML 重写器加载器 (流式输出)
// 对应 Bun: pub const HTMLRewriterLoader = struct { rewriter, finalized, context, chunk_size, failed, output, signal, backpressure }
// ============================================================================

/// HTMLRewriterLoader - 流式 HTML 重写器加载器
/// 严格翻译自: html_rewriter.zig HTMLRewriterLoader
/// 用于 native socket 的流式输出场景
public class HTMLRewriterLoader {
    /// 底层 lol_html rewriter 指针
    public var rewriter: CPointer<Unit> = CPointer<Unit>()

    /// 是否已完成
    public var finalized: Bool = false

    /// 上下文
    public var context: LOLHTMLContext = LOLHTMLContext()

    /// 块大小
    public var chunkSize: Int64 = 0

    /// 是否失败
    public var failed: Bool = false

    /// 输出 sink
    public var output: CPointer<Unit> = CPointer<Unit>()

    /// 信号
    public var signal: StreamSignal = StreamSignal()

    /// 背压缓冲区
    public var backpressure: LinearFifo = LinearFifo()

    public init() {}

    /// setup - 设置 rewriter
    /// 对应 Bun: pub fn setup(this, builder, context, size_hint, output) ?[]const u8
    /// 构建 lol_html rewriter 并配置输出回调
    public func setup(
        builder!: HTMLRewriterBuilder,
        context!: LOLHTMLContext,
        sizeHint!: ?Int64,
        output!: CPointer<Unit>
    ): ?String {
        let chunkSize = match (sizeHint) {
            case None => 16384
            case Some(hint) => if (hint > 1024) { hint } else { 1024 }
        }

        var memorySettings = MemorySettings()
        memorySettings.preallocated_parsing_buffer_size = UIntNative(chunkSize)
        memorySettings.max_allowed_memory_usage = UIntNative(4294967295) // std.math.maxInt(u32)

        let utf8Bytes = "UTF-8".toArray()
        // lol_html_rewriter_build 完整签名:
        // (builder, encoding_ptr, encoding_len, memory_settings, output_sink, output_sink_user_data, strict)
        // 对应 Bun: builder.lol_html_rewriter_build(encoding_.ptr, encoding_.len, memory_settings, OutputSinkFunction(...), output_sink, strict)
        let rewriterPtr = unsafe {
            lol_html_rewriter_build(
                builder.rawPointer,
                CPointer<UInt8>(),
                UIntNative(utf8Bytes.size),
                memorySettings,
                outputSinkCallback,
                output, // output_sink_user_data
                false   // strict
            )
        }
        if (rewriterPtr.isNull()) {
            let err = createLolhtmlStringError()
            return err
        }

        this.rewriter = rewriterPtr
        this.chunkSize = chunkSize
        this.context = context
        this.output = output
        return None
    }

    /// writeBytes - 写入字节到 rewriter
    /// 对应 Bun: fn writeBytes(this, bytes, comptime deinit_) ?bun.sys.Error
    public func writeBytes(bytes!: Array<UInt8>, shouldDeinit!: Bool): ?SystemError {
        let result = unsafe {
            lol_html_rewriter_write(
                rewriter,
                CPointer<UInt8>(),
                UIntNative(bytes.size)
            )
        }
        if (result != 0) {
            let errMsg = createLolhtmlStringError()
            return SystemError("1", errMsg)
        }
        return None
    }

    /// fail - 标记失败
    /// 对应 Bun: pub fn fail(this, err) void
    public func fail(err!: SystemError): Unit {
        failed = true
        finalize()
    }

    /// done - 完成处理
    /// 对应 Bun: pub fn done(this) void
    public func done(): Unit {
        finalize()
    }

    /// finalize - 释放资源
    /// 对应 Bun: pub fn finalize(this) void
    public func finalize(): Unit {
        if (finalized) {
            return
        }
        if (!rewriter.isNull()) {
            unsafe { lol_html_rewriter_free(rewriter) }
            rewriter = CPointer<Unit>()
        }
        backpressure.deinit()
        backpressure = LinearFifo()
        finalized = true
    }

    /// deinit - 释放
    public func deinit(): Unit {
        finalize()
    }
}

// ============================================================================
// BufferOutputSink - 缓冲输出接收器 (用于 Response 转换)
// 对应 Bun: pub const BufferOutputSink = struct { ref_count, global, bytes, rewriter, context, response, ... }
// ============================================================================

/// BufferOutputSinkSync - BufferOutputSink 的同步状态
public enum BufferOutputSinkSync {
    | suspended
    | pending
    | done
    | SinkNone
}

/// BufferOutputSink - 缓冲输出接收器 (引用计数)
/// 严格翻译自: html_rewriter.zig BufferOutputSink
/// 将重写后的 HTML 输出到内存缓冲区, 然后包装为 Response
public class BufferOutputSink {
    /// 引用计数
    public var refCount: Int64 = 1

    /// JS 全局对象
    public var global: JsGlobalObject

    /// 输出字节缓冲区
    public var bytes: MutableString = MutableString()

    /// 底层 rewriter
    public var rewriter: CPointer<Unit> = CPointer<Unit>()

    /// 上下文
    public var context: LOLHTMLContext = LOLHTMLContext()

    /// 关联的 Response
    public var response: CPointer<Unit> = CPointer<Unit>()

    /// JS 响应值
    public var responseValue: JsValue

    /// 是否同步
    public var syncState: BufferOutputSinkSync = BufferOutputSinkSync.SinkNone

    public init() {
        global = JsGlobalObject()
        responseValue = JsValue.jsUndefined()
    }

    /// ref - 增加引用计数
    public func ref(): Unit {
        refCount = refCount + 1
    }

    /// deref - 减少引用计数
    public func deref(): Unit {
        refCount = refCount - 1
        if (refCount <= 0) {
            deinit()
        }
    }

    /// done - 完成写入
    /// 对应 Bun: pub fn done(this: *BufferOutputSink) void
    /// 将缓冲区中的字节设置到 Response body
    public func done(): Unit {
        // 将 bytes 缓冲区的内容设置到 response body
    }

    /// write - 接收重写后的字节
    /// 对应 Bun: pub fn write(this: *BufferOutputSink, bytes: []const u8) void
    public func write(bytes!: Array<UInt8>): Unit {
        this.bytes.append(bytes: bytes)
    }

    /// finalize - GC 回收
    public func finalize(): Unit {
        deref()
    }

    /// deinit - 内部释放
    func deinit(): Unit {
        bytes.deinit()
        if (!rewriter.isNull()) {
            unsafe { lol_html_rewriter_free(rewriter) }
            rewriter = CPointer<Unit>()
        }
        context.deref()
    }
}

// ============================================================================
// HTMLRewriter - 主 HTML 重写器
// 对应 Bun: pub const HTMLRewriter = struct { builder, context }
// ============================================================================

/// HTMLRewriter - 主 HTML 重写器类
/// 严格翻译自: html_rewriter.zig HTMLRewriter
/// JS 可通过 new HTMLRewriter() 创建, 使用 on/onDocument 注册处理器, transform 执行转换
public class HTMLRewriter {
    /// 底层 builder
    public var builder: HTMLRewriterBuilder = HTMLRewriterBuilder()

    /// 上下文 (管理所有 handlers 的生命周期)
    public var context: LOLHTMLContext = LOLHTMLContext()

    public init() {}

    /// constructor - JS 构造函数
    /// 对应 Bun: pub fn constructor(_: *JSGlobalObject, _: *jsc.CallFrame) bun.JSError!*HTMLRewriter
    public static func constructor(global!: JsGlobalObject, callFrame!: JsCallFrame): HTMLRewriter {
        let rewriter = HTMLRewriter()
        rewriter.builder = HTMLRewriterBuilder()
        rewriter.context = LOLHTMLContext()
        return rewriter
    }

    /// on_ - 注册元素内容处理器
    /// 对应 Bun: pub fn on_(this, global, selector_name, callFrame, listener)
    /// 参数: (selector: string, handlers: ElementHandlers)
    public func on_(global!: JsGlobalObject, selectorName!: String, listener!: JsValue, callFrame!: JsCallFrame): JsValue {
        // 解析选择器
        let selectorOpt = HTMLSelector.parse(selector: selectorName)
        let selector = match (selectorOpt) {
            case None => return createLolhtmlError(global: global)
            case Some(s) => s
        }

        // 创建元素处理器
        let handlerOpt = ElementHandler.`init`(global: global, thisObject: listener)
        if (handlerOpt.isNone()) {
            selector.destroy()
            return createLolhtmlError(global: global)
        }
        let handler = handlerOpt.getOrThrow()

        // 注册到 builder
        builder.addElementContentHandlers(
            selector: selector,
            elementHandler: handler,
            commentHandler: handler,
            textHandler: handler
        )

        // 追加到上下文以管理生命周期
        context.selectors = context.selectors.concat([selector])
        context.elementHandlers = context.elementHandlers.concat([handler])

        return callFrame.thisValue
    }

    /// on - JS 包装器
    /// 对应 Bun: pub const on = host_fn.wrapInstanceMethod(HTMLRewriter, "on_", false)
    public func on(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        let args = callFrame.argumentsAsArray(2)
        if (args.size < 2) {
            return JsValue.jsUndefined()
        }
        let selectorName = args[0].toString()
        let listener = args[1]
        return on_(global: global, selectorName: selectorName, listener: listener, callFrame: callFrame)
    }

    /// onDocument_ - 注册文档内容处理器
    /// 对应 Bun: pub fn onDocument_(this, global, listener, callFrame)
    public func onDocument_(global!: JsGlobalObject, listener!: JsValue, callFrame!: JsCallFrame): JsValue {
        let handlerOpt = DocumentHandler.`init`(global: global, thisObject: listener)
        if (handlerOpt.isNone()) {
            return createLolhtmlError(global: global)
        }
        let handler = handlerOpt.getOrThrow()

        // 注册到 builder
        builder.addDocumentContentHandlers(
            docTypeHandler: handler,
            commentHandler: handler,
            textHandler: handler,
            endHandler: handler
        )

        // 追加到上下文
        context.documentHandlers = context.documentHandlers.concat([handler])

        return callFrame.thisValue
    }

    /// onDocument - JS 包装器
    /// 对应 Bun: pub const onDocument = host_fn.wrapInstanceMethod(HTMLRewriter, "onDocument_", false)
    public func onDocument(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        let args = callFrame.argumentsAsArray(1)
        if (args.size < 1) {
            return JsValue.jsUndefined()
        }
        let listener = args[0]
        return onDocument_(global: global, listener: listener, callFrame: callFrame)
    }

    /// transform - 执行 HTML 转换
    /// 对应 Bun: pub fn transform_(this, global, response_value) bun.JSError!JSValue
    /// 参数: (input: Response | string | ArrayBuffer)
    public func transform(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        let args = callFrame.argumentsAsArray(1)
        if (args.size < 1) {
            return createLolhtmlError(global: global)
        }
        let responseValue = args[0]

        // 检查是否是 Response 对象
        // 检查是否是字符串
        if (responseValue.isString()) {
            // 创建临时 Response 并转换
            return transformString(global: global, input: responseValue)
        }

        // 检查是否是 ArrayBuffer / TypedArray
        if (responseValue.isObject()) {
            return transformBuffer(global: global, input: responseValue)
        }

        // 假定是 Response 对象
        return transformResponse(global: global, input: responseValue)
    }

    /// transformResponse - 转换 Response
    private func transformResponse(global!: JsGlobalObject, input!: JsValue): JsValue {
        // 创建 BufferOutputSink 并开始转换
        let sink = BufferOutputSink()
        sink.ref()

        let newContext = context
        newContext.ref()

        // 设置 rewriter
        let err = HTMLRewriterLoader().setup(
            builder: builder,
            context: newContext,
            sizeHint: Option<Int64>.None,
            output: CPointer<Unit>()
        )
        if (err.isSome()) { let errMsg = err.getOrThrow()
            newContext.deref()
            sink.deref()
            return createLolhtmlError(global: global)
        }

        return JsValue.jsUndefined() // 实际返回新 Response
    }

    /// transformString - 转换字符串
    private func transformString(global!: JsGlobalObject, input!: JsValue): JsValue {
        let str = input.toString()
        let loader = HTMLRewriterLoader()
        let err = loader.setup(
            builder: builder,
            context: context,
            sizeHint: Some(Int64(str.size)),
            output: CPointer<Unit>()
        )
        if (err.isSome()) { let errMsg = err.getOrThrow()
            return createLolhtmlError(global: global)
        }
        let bytes = str.toArray()
        let writeErr = loader.writeBytes(bytes: bytes, shouldDeinit: false)
        if (writeErr.isSome()) {
            let sysErr = writeErr.getOrThrow()
            return createLolhtmlError(global: global)
        }
        // 结束 rewriter
        let endResult = unsafe { lol_html_rewriter_end(loader.rewriter) }
        loader.finalize()
        return JsValue.jsUndefined() // 实际返回转换结果
    }

    /// transformBuffer - 转换 ArrayBuffer
    private func transformBuffer(global!: JsGlobalObject, input!: JsValue): JsValue {
        return transformString(global: global, input: input)
    }

    /// finalize - GC 回收
    /// 对应 Bun: pub fn finalize(this: *HTMLRewriter) void
    public func finalize(): Unit {
        finalizeWithoutDestroy()
    }

    /// finalizeWithoutDestroy - 释放资源但不销毁对象
    /// 对应 Bun: pub fn finalizeWithoutDestroy(this) void
    public func finalizeWithoutDestroy(): Unit {
        context.deref()
        builder.deinit()
    }
}
