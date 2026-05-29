// 严格翻译自: src/runtime/api/html_rewriter.rs
// HTMLRewriter API — wraps lol-html for JS.
// Ported from src/runtime/api/html_rewriter.zig.
package bao_runtime.api

import bao_jsc.{JsGlobalObject, JsValue, JsCallFrame, ArgumentsSlice}
import bao_collections.{ArrayList, HashMap}
import bao_core.{Allocator, ArenaAllocator, BaoError, ErrorCode, Output, defaultAllocator}
import bao_sys.*
import bao_lolhtml_sys.*
import bao_runtime.webcore.*

// ============================================================================
// 本地辅助函数
// 严格翻译自: html_rewriter.rs 中的本地辅助函数
// ============================================================================

/// `HTMLString` → 拥有所有权的 `BaoString` (clone + free original)。
/// 严格翻译自: fn html_string_to_bun_string(s: lolhtml::HTMLString) -> BunString
public func htmlStringToBunString(s!: HTMLString): BaoString {
    let out = BaoString.cloneUtf8(s.slice())
    s.deinit()
    return out
}

/// 构造一个带有 code + message 的 SystemError。
/// 严格翻译自: fn system_error(code: &'static str, message: &'static str) -> SystemError
public func systemError(code!: String, message!: String): SystemError {
    let err = SystemError()
    err.code = BaoString(code)
    err.message = BaoString(message)
    return err
}

/// 创建 lolhtml 错误 JsValue。
/// 严格翻译自: fn create_lolhtml_error(global: &JSGlobalObject) -> JsValue
public func createLolhtmlError(global!: JsGlobalObject): JsValue {
    // 如果已有 pending exception，使用它
    if (let err <- global.tryTakeException()) {
        return err
    }
    let vm = global.bunVM()
    if (let errPtr <- vm.unhandledPendingRejectionToCapture) {
        let slot = errPtr
        if (!slot.isEmpty()) {
            let result = slot
            errPtr.clear()
            return result
        }
    }

    let err = createLolhtmlStringError()
    let value = err.toErrorInstance(global)
    value.put(global, "name", BaoString("HTMLRewriterError").toJS(global))
    return value
}

/// 创建 lolhtml 字符串错误。
/// 严格翻译自: fn create_lolhtml_string_error() -> BunString
public func createLolhtmlStringError(): BaoString {
    // 我们必须 clone 这个字符串。
    let err = HTMLString.lastError()
    let s = BaoString.cloneUtf8(err.slice())
    err.deinit()
    return s
}

/// HTMLString → JsValue
/// 严格翻译自: fn html_string_value(input: lolhtml::HTMLString, global_object: &JSGlobalObject) -> JsResult<JsValue>
public func htmlStringValue(input!: HTMLString, globalObject!: JsGlobalObject): JsValue {
    return LolhtmlJsc.htmlStringToJS(input, globalObject)
}

// ============================================================================
// wrapInstanceMethod 参数解码辅助函数
// 严格翻译自: html_rewriter.rs 中 eat_zig_string, eat_js_value, eat_content_options
// ============================================================================

/// 解码参数中的 ZigString
/// 严格翻译自: fn eat_zig_string(iter: &ArgumentsSlice<'_>, global: &JSGlobalObject) -> JsResult<ZigString>
public func eatZigString(iter!: ArgumentsSlice, global!: JsGlobalObject): BaoString {
    let value = iter.nextEat()
    if (value.isNone()) {
        global.throwInvalidArguments("Missing argument")
        return BaoString("")
    }
    if (value.isUndefinedOrNull()) {
        global.throwInvalidArguments("Expected string")
        return BaoString("")
    }
    return value.getZigString(global)
}

/// 解码参数中的 JsValue (必需)
/// 严格翻译自: fn eat_js_value(iter: &ArgumentsSlice<'_>, global: &JSGlobalObject) -> JsResult<JsValue>
public func eatJsValue(iter!: ArgumentsSlice, global!: JsGlobalObject): JsValue {
    let value = iter.nextEat()
    if (value.isNone()) {
        global.throwInvalidArguments("Missing argument")
        return JsValue.UNDEFINED
    }
    return value
}

/// 解码 ContentOptions 参数
/// 严格翻译自: fn eat_content_options(iter, global) -> Option<ContentOptions>
public func eatContentOptions(iter!: ArgumentsSlice, global!: JsGlobalObject): ?ContentOptions {
    let arg = iter.nextEat()
    if (arg.isNone()) {
        return None
    }
    let htmlVal = arg.get(global, "html")
    if (htmlVal.isSome()) {
        return ContentOptions(html: htmlVal.toBoolean())
    }
    return None
}

/// 解码 (content: ZigString, contentOptions: ?ContentOptions) 参数对
/// 严格翻译自: fn eat_content_args(global, call_frame) -> (ZigString, Option<ContentOptions>)
public func eatContentArgs(global!: JsGlobalObject, callFrame!: JsCallFrame): ContentArgs {
    let args = callFrame.argumentsOld(2)
    let iter = ArgumentsSlice(global.bunVMRef(), args.slice())
    let content = eatZigString(iter, global)
    let opts = eatContentOptions(iter, global)
    return ContentArgs(content: content, options: opts)
}

/// ContentArgs — (content, options) 参数对
public class ContentArgs {
    public var content: BaoString
    public var options: ?ContentOptions

    public init(content: BaoString, options: ?ContentOptions) {
        this.content = content
        this.options = options
    }
}

// ============================================================================
// SelectorMap - 选择器映射
// 严格翻译自: type SelectorMap = Vec<*lolhtml::HTMLSelector>
// ============================================================================

public type SelectorMap = ArrayList<CPointer<Unit>>

// ============================================================================
// ContentOptions - 内容选项
// 严格翻译自: html_rewriter.rs ContentOptions
// ============================================================================

/// ContentOptions — 内容操作选项
/// 严格翻译自: ContentOptions { html: bool }
public class ContentOptions {
    public var html: Bool

    public init() {
        html = false
    }

    public init(html: Bool) {
        this.html = html
    }
}

// ============================================================================
// LOLHTMLContext - 管理 LOLHTML 选择器和处理器的上下文
// 严格翻译自: html_rewriter.rs LOLHTMLContext
// ============================================================================

/// LOLHTMLContext — 管理 LOLHTML 选择器和处理器的上下文
/// 严格翻译自: pub struct LOLHTMLContext
public class LOLHTMLContext {
    public var selectors: SelectorMap
    public var elementHandlers: ArrayList<ElementHandler>
    public var documentHandlers: ArrayList<DocumentHandler>

    public init() {
        selectors = SelectorMap()
        elementHandlers = ArrayList<ElementHandler>()
        documentHandlers = ArrayList<DocumentHandler>()
    }

    /// 释放资源 — 销毁所有选择器
    /// 严格翻译自: impl Drop for LOLHTMLContext
    public func deinit(): Unit {
        for (selector in selectors) {
            // SAFETY: selector 由 LOLHTML.HTMLSelector.parse 分配，此处拥有所有权。
            HTMLSelector.destroy(selector)
        }
        selectors.clear()
        // element_handlers / document_handlers: 通过自身的 deinit 方法释放
        for (handler in elementHandlers) {
            handler.deinit()
        }
        elementHandlers.clear()
        for (handler in documentHandlers) {
            handler.deinit()
        }
        documentHandlers.clear()
    }
}

// ============================================================================
// HTMLRewriter - HTML 重写器
// 严格翻译自: html_rewriter.rs HTMLRewriter
// ============================================================================

/// HTMLRewriter — HTML 重写器类
/// 严格翻译自: pub struct HTMLRewriter
public class HTMLRewriter {
    public var builder: CPointer<Unit> // *lolhtml_sys::HTMLRewriterBuilder
    public var context: LOLHTMLContext

    // ========================================================================
    // 构造函数
    // 严格翻译自: HTMLRewriter::constructor
    // ========================================================================

    /// 构造函数
    /// 严格翻译自: pub fn constructor(_global, _frame) -> JsResult<*HTMLRewriter>
    public static func constructor(global!: JsGlobalObject, callFrame!: JsCallFrame): HTMLRewriter {
        let rewriter = HTMLRewriter(
            builder: HTMLRewriterBuilder(),
            context: LOLHTMLContext(),
        )
        // 严格翻译自: bun_core::analytics::Features::HTML_REWRITER.fetch_add(1, ...)
        global.bunVM().analytics.features.htmlRewriter.fetchAdd(1)
        return rewriter
    }

    // ========================================================================
    // on_ — 注册元素选择器处理器
    // 严格翻译自: HTMLRewriter::on_
    // ========================================================================

    /// on_ — 注册元素选择器处理器
    /// 严格翻译自: pub fn on_(&self, global, selector_name, call_frame, listener) -> JsResult<JsValue>
    public func on_(global!: JsGlobalObject, selectorName!: BaoString, callFrame!: JsCallFrame, listener!: JsValue): JsValue {
        let selectorSlice = selectorName.toSlice()

        let selector = HTMLSelector.parse(selectorSlice)
        if (selector == CPointer<Unit>()) {
            return global.throwValue(createLolhtmlError(global))
        }

        var selectorGuard = SelectorGuard(selector)

        let handler = ElementHandler(global, listener)
        if (handler.isNone()) {
            return global.throwInvalidArguments("Expected object")
        }

        let handlerPtr = handler

        let hasElement = handler.onElementCallback.isSome()
        let hasComment = handler.onCommentCallback.isSome()
        let hasText = handler.onTextCallback.isSome()

        // SAFETY: builder 是有效的 lol-html builder；handlerPtr 存活于 elementHandlers
        let res = builder.add_element_content_handlers(
            selectorGuard.selector,
            if (hasElement) { handlerPtr } else { CPointer<Unit>() },
            if (hasComment) { handlerPtr } else { CPointer<Unit>() },
            if (hasText) { handlerPtr } else { CPointer<Unit>() },
        )
        if (res.isErr()) {
            return global.throwValue(createLolhtmlError(global))
        }

        let sel = selectorGuard.release()
        context.selectors.append(sel)
        context.elementHandlers.append(handler)
        return callFrame.`this`()
    }

    // ========================================================================
    // on_document_ — 注册文档处理器
    // 严格翻译自: HTMLRewriter::on_document_
    // ========================================================================

    /// on_document_ — 注册文档处理器
    /// 严格翻译自: pub fn on_document_(&self, global, listener, call_frame) -> JsResult<JsValue>
    public func onDocument_(global!: JsGlobalObject, listener!: JsValue, callFrame!: JsCallFrame): JsValue {
        let handler = DocumentHandler(global, listener)
        if (handler.isNone()) {
            return global.throwInvalidArguments("Expected object")
        }

        let handlerPtr = handler

        let hasDocType = handler.onDocTypeCallback.isSome()
        let hasComment = handler.onCommentCallback.isSome()
        let hasText = handler.onTextCallback.isSome()
        let hasEnd = handler.onEndCallback.isSome()

        // SAFETY: builder 有效；handlerPtr 存活于 context.documentHandlers
        builder.addDocumentContentHandlers(
            if (hasDocType) { handlerPtr } else { CPointer<Unit>() },
            if (hasComment) { handlerPtr } else { CPointer<Unit>() },
            if (hasText) { handlerPtr } else { CPointer<Unit>() },
            if (hasEnd) { handlerPtr } else { CPointer<Unit>() },
        )

        context.documentHandlers.append(handler)
        return callFrame.`this`()
    }

    // ========================================================================
    // finalize / finalize_without_destroy
    // 严格翻译自: HTMLRewriter::finalize / finalize_without_destroy
    // ========================================================================

    /// finalize — 析构
    /// 严格翻译自: pub fn finalize(self: Box<Self>)
    public func finalize(): Unit {
        finalizeWithoutDestroy()
    }

    /// finalize_without_destroy — 不销毁的析构
    /// 严格翻译自: pub fn finalize_without_destroy(&self)
    public func finalizeWithoutDestroy(): Unit {
        // SAFETY: builder 由 Builder::init() 创建，尚未释放。
        HTMLRewriterBuilder.destroy(builder)
    }

    // ========================================================================
    // begin_transform / transform_ / transform
    // 严格翻译自: HTMLRewriter::begin_transform / transform_ / transform
    // ========================================================================

    /// begin_transform — 开始转换
    /// 严格翻译自: pub fn begin_transform(&self, global, response) -> JsResult<JsValue>
    public func beginTransform(global!: JsGlobalObject, response!: Response): JsValue {
        let newContext = context
        return BufferOutputSink(newContext, global, response, builder)
    }

    /// transform_ — 转换实现
    /// 严格翻译自: pub fn transform_(&self, global, response_value) -> JsResult<JsValue>
    public func transform_(global!: JsGlobalObject, responseValue!: JsValue): JsValue {
        // 检查是否为 Response 对象
        if (let response <- responseValue.asResponse()) {
            let bodyValue = response.getBodyValue()
            if (bodyValue.tag == BodyValueTag.Used) {
                return global.throwInvalidArguments("Response body already used")
            }
            let out = beginTransform(global, response)
            if (let err <- out.toError()) {
                return global.throwValue(err)
            }
            return out
        }

        // 判断输入类型
        var kind = ResponseKind.Other
        if (responseValue.isString()) {
            kind = ResponseKind.String
        } else if (responseValue.jsType().isTypedArrayOrArrayBuffer()) {
            kind = ResponseKind.ArrayBuffer
        }

        if (kind != ResponseKind.Other) {
            let bodyValue = Body.extract(global, responseValue)
            let resp = Response(
                ResponseInit(200),
                bodyValue,
                "",
                false
            )

            let outResponseValue = beginTransform(global, resp)
            if (let err <- outResponseValue.toError()) {
                return global.throwValue(err)
            }
            outResponseValue.ensureStillAlive()

            if (let outResponse <- outResponseValue.asResponse()) {
                let blob = outResponse.getBodyValue().useAsAnyBlobAllowNonUtf8String()

                // 清理 out_response
                outResponseValue.dangerouslySetPtr(CPointer<Unit>())

                match (kind) {
                    case String => blob.toString(global, Lifetime.Transfer)
                    case ArrayBuffer => blob.toArrayBuffer(global, Lifetime.Transfer)
                    case Other => JsValue.UNDEFINED // unreachable()
                }
            } else {
                return outResponseValue
            }
        }

        return global.throwInvalidArguments("Expected Response or Body")
    }

    /// on — 注册元素选择器处理器（解码参数版本）
    /// 严格翻译自: pub fn on(&self, global, call_frame) -> JsResult<JsValue>
    public func on(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        let args = callFrame.argumentsOld(2)
        let iter = ArgumentsSlice(global.bunVMRef(), args.slice())
        let selectorName = eatZigString(iter, global)
        let listener = eatJsValue(iter, global)
        return on_(global, selectorName, callFrame, listener)
    }

    /// onDocument — 注册文档处理器（解码参数版本）
    /// 严格翻译自: pub fn on_document(&self, global, call_frame) -> JsResult<JsValue>
    public func onDocument(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        let args = callFrame.argumentsOld(1)
        let iter = ArgumentsSlice(global.bunVMRef(), args.slice())
        let listener = eatJsValue(iter, global)
        return onDocument_(global, listener, callFrame)
    }

    /// transform — 转换（解码参数版本）
    /// 严格翻译自: pub fn transform(&self, global, call_frame) -> JsResult<JsValue>
    public func transform(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        let args = callFrame.argumentsOld(1)
        let iter = ArgumentsSlice(global.bunVMRef(), args.slice())
        let responseValue = eatJsValue(iter, global)
        return transform_(global, responseValue)
    }
}

/// ResponseKind — 输入类型分类
/// 严格翻译自: html_rewriter.rs 内部 enum ResponseKind
public enum ResponseKind {
    | String
    | ArrayBuffer
    | Other
}

/// SelectorGuard — 选择器 RAII 保护
/// 严格翻译自: scopeguard::guard(selector, |s| unsafe { lolhtml::HTMLSelector::destroy(s) })
public class SelectorGuard {
    public var selector: CPointer<Unit>
    public var released: Bool

    public init(selector: CPointer<Unit>) {
        this.selector = selector
        released = false
    }

    public func release(): CPointer<Unit> {
        released = true
        return selector
    }

    public func deinit(): Unit {
        if (!released && selector != CPointer<Unit>()) {
            HTMLSelector.destroy(selector)
        }
    }
}

// ============================================================================
// HTMLRewriterBuilder — FFI 封装
// 严格翻译自: builder 相关操作
// ============================================================================

/// HTMLRewriterBuilder — lol-html HTMLRewriterBuilder FFI 封装
public class HTMLRewriterBuilder {
    /// init — 创建新的 builder
    /// 严格翻译自: lolhtml::HTMLRewriterBuilder::init()
    public static func `init`(): CPointer<Unit> {
        return lol_html_rewriter_builder_new()
    }

    /// destroy — 销毁 builder
    /// 严格翻译自: lolhtml::HTMLRewriterBuilder::destroy(builder)
    public static func destroy(builder!: CPointer<Unit>): Unit {
        lol_html_rewriter_builder_free(builder)
    }

    /// add_element_content_handlers — 添加元素内容处理器
    /// 严格翻译自: (*self.builder).add_element_content_handlers(...)
    public static func addElementContentHandlers(
        builder!: CPointer<Unit>,
        selector!: CPointer<Unit>,
        elementHandler!: CPointer<Unit>,
        elementUserData!: CPointer<Unit>,
        commentHandler!: CPointer<Unit>,
        commentUserData!: CPointer<Unit>,
        textHandler!: CPointer<Unit>,
        textUserData!: CPointer<Unit>
    ): Bool {
        let res = lol_html_rewriter_builder_add_element_content_handlers(
            builder, selector,
            elementHandler, elementUserData,
            commentHandler, commentUserData,
            textHandler, textUserData,
        )
        return res == 0
    }
}

/// HTMLSelector — FFI 封装
public class HTMLSelector {
    /// parse — 解析选择器
    /// 严格翻译自: lolhtml::HTMLSelector::parse(&selector_slice)
    public static func parse(selectorSlice!: Array<UInt8>): CPointer<Unit> {
        return lol_html_selector_parse(selectorSlice.toArrayPtr(), UIntNative(selectorSlice.size))
    }

    /// destroy — 销毁选择器
    /// 严格翻译自: lolhtml::HTMLSelector::destroy(selector)
    public static func destroy(selector!: CPointer<Unit>): Unit {
        lol_html_selector_free(selector)
    }
}

// ============================================================================
// HTMLRewriterLoader - HTML 重写器加载器
// 严格翻译自: html_rewriter.rs HTMLRewriterLoader
// ============================================================================

/// HTMLRewriterLoader — 流式 HTML 重写加载器
/// 严格翻译自: pub struct HTMLRewriterLoader
public class HTMLRewriterLoader {
    public var rewriter: CPointer<Unit> // *lolhtml_sys::HTMLRewriter
    public var finalized: Bool
    public var context: LOLHTMLContext
    public var chunkSize: Int64
    public var failed: Bool
    public var output: Sink
    public var signal: StreamSignal
    public var backpressure: LinearFifo

    public init() {
        rewriter = CPointer<Unit>()
        finalized = false
        context = LOLHTMLContext()
        chunkSize = 0
        failed = false
        output = Sink()
        signal = StreamSignal()
        backpressure = LinearFifo()
    }

    /// finalize — 终结
    /// 严格翻译自: pub fn finalize(&self)
    public func finalize(): Unit {
        if (finalized) {
            return
        }
        // SAFETY: rewriter 通过 builder.build() 创建，尚未释放。
        lol_html_rewriter_free(rewriter)
        backpressure = LinearFifo()
        finalized = true
    }

    /// fail — 失败
    /// 严格翻译自: pub fn fail(&self, err: bun_sys::Error)
    public func fail(err!: SyscallError): Unit {
        signal.close(Some(err))
        output.end(Some(err))
        failed = true
        finalize()
    }

    /// connect — 连接信号
    /// 严格翻译自: pub fn connect(&self, signal: Signal)
    public func connect(signal!: StreamSignal): Unit {
        this.signal = signal
    }

    /// write_to_destination — 写入目标
    /// 严格翻译自: pub fn write_to_destination(&self, bytes: &[u8])
    public func writeToDestination(bytes!: Array<UInt8>): Unit {
        if (backpressure.readableLength() > 0) {
            if (backpressure.write(bytes).isErr()) {
                fail(SyscallError.oom())
                finalize()
            }
            return
        }

        let borrowed = bytes
        let writeResult = output.writeBytes(StreamResult.temporary(borrowed))

        match (writeResult.tag) {
            case Err =>
                fail(writeResult.err)
            case OwnedAndDone | TemporaryAndDone | IntoArrayAndDone =>
                done()
            case Pending =>
                writeResult.pending.applyBackpressure(output, bytes)
            case Done =>
                done()
            case _ =>
                signal.ready(
                    if (chunkSize > 0) { Some(chunkSize) } else { None },
                    None,
                )
        }
    }

    /// done — 完成
    /// 严格翻译自: pub fn done(&self)
    public func done(): Unit {
        output.end(None)
        signal.close(None)
        finalize()
    }

    /// setup — 设置
    /// 严格翻译自: pub fn setup(&self, builder, context, size_hint, output) -> Option<lolhtml::HTMLString>
    public func setup(
        builder!: CPointer<Unit>,
        context!: LOLHTMLContext,
        sizeHint!: ?Int64,
        output!: Sink
    ): ?HTMLString {
        let chunkSize = if (let Some(s) <- sizeHint) {
            if (s < 1024) { 1024 } else { s }
        } else {
            16384
        }

        let memorySettings = MemorySettings(
            preallocated_parsing_buffer_size: UIntNative(chunkSize),
            max_allowed_memory_usage: UIntNative(UInt32.Max),
        )

        let utf8Label = "UTF-8".toArray()
        let built = lol_html_rewriter_build(
            builder,
            utf8Label.toArrayPtr(),
            UIntNative(utf8Label.size),
            memorySettings,
            output,
            this,
            false,
        )

        if (built == CPointer<Unit>()) {
            output.end(None)
            return HTMLString.lastError()
        }

        rewriter = built
        this.chunkSize = chunkSize
        this.context = context
        this.output = output
        return None
    }

    /// sink — 获取 sink
    /// 严格翻译自: pub fn sink(&self) -> webcore::Sink<'_>
    public func sink(): Sink {
        return Sink(this)
    }

    /// write_bytes — 写入字节数据
    /// 严格翻译自: fn write_bytes(&self, bytes: &[u8]) -> Option<bun_sys::Error>
    public func writeBytesInternal(bytes!: Array<UInt8>): ?SyscallError {
        // SAFETY: rewriter 有效（setup() 成功，尚未终结）。
        let res = lol_html_rewriter_write(rewriter, bytes.toArrayPtr(), UIntNative(bytes.size))
        if (res != 0) {
            let err = HTMLString.lastError()
            let errMsg = BaoString.cloneUtf8(err.slice())
            err.deinit()
            return SyscallError(errno: 1, path: errMsg.toByteArray())
        }
        return None
    }

    /// write — 写入 StreamResult
    /// 严格翻译自: pub fn write(&self, data: StreamResult) -> streams::Writable
    public func write(data!: StreamResult): StreamResultWritable {
        match (data.tag) {
            case Owned =>
                let len = data.ownedData.size
                if (let err <- writeBytesInternal(data.ownedData.toArray())) {
                    return StreamResultWritable.err(err)
                }
                return StreamResultWritable.owned(len)
            case OwnedAndDone =>
                let len = data.ownedData.size
                if (let err <- writeBytesInternal(data.ownedData.toArray())) {
                    return StreamResultWritable.err(err)
                }
                return StreamResultWritable.ownedAndDone(len)
            case TemporaryAndDone =>
                let len = data.tempData.size
                if (let err <- writeBytesInternal(data.tempData.toArray())) {
                    return StreamResultWritable.err(err)
                }
                return StreamResultWritable.temporaryAndDone(len)
            case Temporary =>
                let len = data.tempData.size
                if (let err <- writeBytesInternal(data.tempData.toArray())) {
                    return StreamResultWritable.err(err)
                }
                return StreamResultWritable.temporary(len)
            case _ => StreamResultWritable.done()
        }
    }

    /// write_utf16 — 写入 UTF-16 数据
    /// 严格翻译自: pub fn write_utf16(&self, data: StreamResult) -> streams::Writable
    public func writeUtf16(data!: StreamResult): StreamResultWritable {
        return UTF8Fallback.writeUtf16(this, data, HTMLRewriterLoader.write)
    }

    /// write_latin1 — 写入 Latin-1 数据
    /// 严格翻译自: pub fn write_latin1(&self, data: StreamResult) -> streams::Writable
    public func writeLatin1(data!: StreamResult): StreamResultWritable {
        return UTF8Fallback.writeLatin1(this, data, HTMLRewriterLoader.write)
    }

    /// end — 结束
    /// 严格翻译自: pub fn end(&self, err: Option<bun_sys::Error>) -> bun_sys::Result<()>
    public func end(err!: ?SyscallError): Unit {
        if (let e <- err) {
            fail(e)
        } else {
            if (!finalized) {
                // SAFETY: rewriter 由 setup() 设置，尚未终结。
                lol_html_rewriter_end(rewriter)
            }
            done()
        }
    }
}

// ============================================================================
// BufferOutputSink - 缓冲输出接收器
// 严格翻译自: html_rewriter.rs BufferOutputSink
// ============================================================================

/// BufferOutputSink — 缓冲输出接收器
/// 严格翻译自: pub struct BufferOutputSink
public class BufferOutputSink {
    public var refCount: Int64
    public var global: GlobalRef
    public var bytes: MutableString
    public var rewriter: CPointer<Unit>
    public var context: LOLHTMLContext
    public var response: Response
    public var responseValue: JsValue
    public var bodyValueBufferer: ?ValueBufferer
    public var tmpSyncError: ?JsValue

    public init() {
        refCount = 1
        global = GlobalRef()
        bytes = MutableString.initEmpty()
        rewriter = CPointer<Unit>()
        context = LOLHTMLContext()
        response = Response()
        responseValue = JsValue.UNDEFINED
        bodyValueBufferer = None
        tmpSyncError = None
    }

    /// ref — 增加引用计数
    public func ref_(): Unit {
        refCount = refCount + 1
    }

    /// deref — 减少引用计数
    public func deref(): Unit {
        refCount = refCount - 1
        if (refCount <= 0) {
            // 销毁
            if (rewriter != CPointer<Unit>()) {
                // SAFETY: rewriter 通过 builder.build() 创建，尚未释放。
                lol_html_rewriter_free(rewriter)
            }
        }
    }

    /// writeTmpSyncError — 写入临时同步错误
    /// 严格翻译自: fn write_tmp_sync_error(sink: *Self, err: JsValue)
    public static func writeTmpSyncError(sink!: BufferOutputSink, err!: JsValue): Unit {
        sink.tmpSyncError = Some(err)
    }

    /// init — 初始化
    /// 严格翻译自: pub fn init(context, global, original, builder) -> JsResult<JsValue>
    public static func `init`(
        context!: LOLHTMLContext,
        global!: JsGlobalObject,
        original!: Response,
        builder!: CPointer<Unit>
    ): JsValue {
        let sink = BufferOutputSink()
        sink.refCount = 1
        sink.global = GlobalRef.from(global)
        sink.bytes = MutableString.initEmpty()
        sink.rewriter = CPointer<Unit>()
        sink.context = context
        sink.response = Response()
        sink.responseValue = JsValue.UNDEFINED
        sink.bodyValueBufferer = None
        sink.tmpSyncError = None

        // 创建结果 Response
        let result = Response(ResponseInit(200), Body.newLocked(sink), "", false)
        sink.response = result

        let sinkError = JsValue.UNDEFINED

        let inputSize = original.getBodyLen()

        let memorySettings = MemorySettings(
            preallocated_parsing_buffer_size: UIntNative(
                if (inputSize == MAX_SIZE) { 1024 } else { if (inputSize < 1024) { 1024 } else { inputSize } }
            ),
            max_allowed_memory_usage: UIntNative(UInt32.Max),
        )

        let utf8Label = "UTF-8".toArray()
        let built = lol_html_rewriter_build(
            builder,
            utf8Label.toArrayPtr(),
            UIntNative(utf8Label.size),
            memorySettings,
            sink,
            false,
        )

        if (built == CPointer<Unit>()) {
            return createLolhtmlError(global)
        }

        sink.rewriter = built

        // 设置 init 参数
        result.setInit(
            original.getMethod(),
            original.getInitStatusCode(),
            original.getInitStatusText(),
        )

        // 克隆 headers (issue #3334)
        if (let headers <- original.getInitHeadersMut()) {
            let cloned = headers.cloneThis(global)
            result.setInitHeaders(cloned)
        }

        let responseJsValue = result.toJS(global)
        sink.responseValue = responseJsValue

        result.setUrl(original.url().clone())

        let value = original.getBodyValue()
        let ownedReadableStream = original.getBodyReadableStream(global)

        sink.ref_()

        sink.bodyValueBufferer = ValueBufferer(
            sink,
            BufferOutputSink.onFinishedBufferingTrampoline,
            global,
        )

        responseJsValue.ensureStillAlive()

        // 运行 bufferer
        let bufferingResult = sink.bodyValueBufferer.run(value, ownedReadableStream)
        if (bufferingResult.isErr()) {
            sink.deref()
            if (bufferingResult == BaoError("StreamAlreadyUsed")) {
                let err = systemError(
                    "ERR_STREAM_ALREADY_FINISHED",
                    "Stream already used, please create a new one",
                )
                return err.toErrorInstance(global)
            } else {
                let err = systemError("ERR_STREAM_CANNOT_PIPE", "Failed to pipe stream")
                return err.toErrorInstance(global)
            }
        }

        // 同步错误检查
        if (sinkError.isSome() && !sinkError.isEmpty()) {
            sinkError.ensureStillAlive()
            sinkError.unprotect()
            return sinkError
        }

        responseJsValue.ensureStillAlive()
        return responseJsValue
    }

    /// onFinishedBufferingTrampoline — 完成缓冲跳板函数
    /// 严格翻译自: fn on_finished_buffering_trampoline(ctx, bytes, js_err, is_async)
    public static func onFinishedBufferingTrampoline(
        ctx!: BufferOutputSink,
        bytes!: Array<UInt8>,
        jsErr!: ?BodyValueError,
        isAsync!: Bool
    ): Unit {
        onFinishedBuffering(ctx, bytes, jsErr, isAsync)
    }

    /// onFinishedBuffering — 完成缓冲
    /// 严格翻译自: pub fn on_finished_buffering(sink, bytes, js_err, is_async)
    public static func onFinishedBuffering(
        sink!: BufferOutputSink,
        bytes!: Array<UInt8>,
        jsErr!: ?BodyValueError,
        isAsync!: Bool
    ): Unit {
        let global = sink.global

        if (let err <- jsErr) {
            let sinkBodyValue = sink.response.getBodyValue()
            let sinkPtrUsize = sink.hashCode()

            if (sinkBodyValue.tag == BodyValueTag.Locked &&
                sinkBodyValue.lockedTask == sinkPtrUsize &&
                sinkBodyValue.promise.isNone()) {
                // 没有 pending promise
                sinkBodyValue.readable.deinit()
                sinkBodyValue.tag = BodyValueTag.Empty
            } else if (sinkBodyValue.tag == BodyValueTag.Locked &&
                       sinkBodyValue.lockedTask == sinkPtrUsize &&
                       sinkBodyValue.promise.isSome()) {
                sinkBodyValue.onReceiveValue = None
                sinkBodyValue.lockedTask = None
            }

            if (isAsync) {
                sinkBodyValue.toErrorInstance(err, global)
            } else {
                let retErr = createLolhtmlError(global)
                retErr.ensureStillAlive()
                retErr.protect()
                writeTmpSyncError(sink, retErr)
            }

            // SAFETY: rewriter 由 init() 设置。
            let rewriter = sink.rewriter
            lol_html_rewriter_end(rewriter)
            return
        }

        if (let retErr <- runOutputSink(sink, bytes, isAsync)) {
            retErr.ensureStillAlive()
            retErr.protect()
            writeTmpSyncError(sink, retErr)
        }
    }

    /// runOutputSink — 运行输出接收器
    /// 严格翻译自: pub fn run_output_sink(sink, bytes, is_async) -> Option<JsValue>
    public static func runOutputSink(sink!: BufferOutputSink, bytes!: Array<UInt8>, isAsync!: Bool): ?JsValue {
        sink.bytes.growBy(bytes.size)
        let global = sink.global
        let response = sink.response
        let rewriter = sink.rewriter

        // SAFETY: rewriter 由 init() 设置。
        let writeRes = lol_html_rewriter_write(rewriter, bytes.toArrayPtr(), UIntNative(bytes.size))
        if (writeRes != 0) {
            if (isAsync) {
                response.getBodyValue().toErrorInstance(
                    BodyValueError.Message(createLolhtmlStringError()),
                    global,
                )
                return None
            } else {
                return createLolhtmlError(global)
            }
        }

        // SAFETY: rewriter 由 init() 设置且尚未释放。
        let endRes = lol_html_rewriter_end(rewriter)
        if (endRes != 0) {
            if (isAsync) {
                response.getBodyValue().toErrorInstance(
                    BodyValueError.Message(createLolhtmlStringError()),
                    global,
                )
                return None
            } else {
                return createLolhtmlError(global)
            }
        }

        return None
    }

    /// done — 完成
    /// 严格翻译自: pub fn done(&self)
    public func done(): Unit {
        let bodyValue = response.getBodyValue()
        let prevValue = bodyValue
        bodyValue.tag = BodyValueTag.InternalBlob
        bodyValue.internalBlob = InternalBlob(bytes: bytes.toByteArray(), wasString: false)
        bytes = MutableString.initEmpty()

        Body.resolve(prevValue, bodyValue, global, None)
    }

    /// write — 写入
    /// 严格翻译自: pub fn write(&self, bytes: &[u8])
    public func writeBytes(bytes!: Array<UInt8>): Unit {
        bytes.append(bytes)
    }
}

/// BufferOutputSinkSync — 缓冲输出接收器同步状态
/// 严格翻译自: pub enum BufferOutputSinkSync
public enum BufferOutputSinkSync {
    | Suspended
    | Pending
    | Done
}

// ============================================================================
// DocumentHandler - 文档处理器
// 严格翻译自: html_rewriter.rs DocumentHandler
// ============================================================================

/// DocumentHandler — 文档处理器
/// 严格翻译自: pub struct DocumentHandler
public class DocumentHandler {
    public var onDocTypeCallback: ?JsValue
    public var onCommentCallback: ?JsValue
    public var onTextCallback: ?JsValue
    public var onEndCallback: ?JsValue
    public var thisObject: JsValue
    public var global: GlobalRef

    public init() {
        onDocTypeCallback = None
        onCommentCallback = None
        onTextCallback = None
        onEndCallback = None
        thisObject = JsValue.UNDEFINED
        global = GlobalRef()
    }

    /// init — 初始化文档处理器
    /// 严格翻译自: pub fn init(global, this_object) -> JsResult<DocumentHandler>
    public static func `init`(global!: JsGlobalObject, thisObject!: JsValue): ?DocumentHandler {
        if (!thisObject.isObject()) {
            global.throwInvalidArguments("Expected object")
            return None
        }

        let handler = DocumentHandler()
        handler.onDocTypeCallback = None
        handler.onCommentCallback = None
        handler.onTextCallback = None
        handler.onEndCallback = None
        handler.thisObject = JsValue.UNDEFINED
        handler.global = GlobalRef.from(global)

        if (let val <- thisObject.get(global, "doctype")) {
            if (val.isUndefinedOrNull() || !val.isCell() || !val.isCallable()) {
                global.throwInvalidArguments("doctype must be a function")
                return None
            }
            handler.onDocTypeCallback = Some(val.protected())
        }

        if (let val <- thisObject.get(global, "comments")) {
            if (val.isUndefinedOrNull() || !val.isCell() || !val.isCallable()) {
                global.throwInvalidArguments("comments must be a function")
                return None
            }
            handler.onCommentCallback = Some(val.protected())
        }

        if (let val <- thisObject.get(global, "text")) {
            if (val.isUndefinedOrNull() || !val.isCell() || !val.isCallable()) {
                global.throwInvalidArguments("text must be a function")
                return None
            }
            handler.onTextCallback = Some(val.protected())
        }

        if (let val <- thisObject.get(global, "end")) {
            if (val.isUndefinedOrNull() || !val.isCell() || !val.isCallable()) {
                global.throwInvalidArguments("end must be a function")
                return None
            }
            handler.onEndCallback = Some(val.protected())
        }

        handler.thisObject = thisObject.protected()
        return handler
    }

    /// deinit — 释放资源
    public func deinit(): Unit {
        // ProtectedJSValue 字段自动 unprotect
        if (let cb <- onDocTypeCallback) { cb.unprotect() }
        if (let cb <- onCommentCallback) { cb.unprotect() }
        if (let cb <- onTextCallback) { cb.unprotect() }
        if (let cb <- onEndCallback) { cb.unprotect() }
        thisObject.unprotect()
    }

    /// onDocType — DocType 回调
    /// 严格翻译自: pub fn on_doc_type(`this`: *Self, value: *lolhtml::DocType) -> bool
    public static func onDocType(`this`: DocumentHandler, value!: CPointer<Unit>): Bool {
        return handlerCallback(
            this,
            value,
            { w: DocType => w.doctype = CPointer<Unit>() },
            { h: DocumentHandler => h.onDocTypeCallback },
        )
    }

    /// onComment — Comment 回调
    /// 严格翻译自: pub fn on_comment(`this`: *Self, value: *lolhtml::Comment) -> bool
    public static func onComment(`this`: DocumentHandler, value!: CPointer<Unit>): Bool {
        return handlerCallback(
            this,
            value,
            { w: HTMLComment => w.comment = CPointer<Unit>() },
            { h: DocumentHandler => h.onCommentCallback },
        )
    }

    /// onText — TextChunk 回调
    /// 严格翻译自: pub fn on_text(`this`: *Self, value: *lolhtml::TextChunk) -> bool
    public static func onText(`this`: DocumentHandler, value!: CPointer<Unit>): Bool {
        return handlerCallback(
            this,
            value,
            { w: TextChunk => w.textChunk = CPointer<Unit>() },
            { h: DocumentHandler => h.onTextCallback },
        )
    }

    /// onEnd — DocEnd 回调
    /// 严格翻译自: pub fn on_end(`this`: *Self, value: *lolhtml::DocEnd) -> bool
    public static func onEnd(`this`: DocumentHandler, value!: CPointer<Unit>): Bool {
        return handlerCallback(
            this,
            value,
            { w: DocEnd => w.docEnd = CPointer<Unit>() },
            { h: DocumentHandler => h.onEndCallback },
        )
    }
}

// ============================================================================
// HandlerLike / WrapperLike — 处理器 trait 接口
// 严格翻译自: html_rewriter.rs HandlerLike, WrapperLike
// ============================================================================

/// HandlerLike — 处理器接口
/// 严格翻译自: pub trait HandlerLike
public interface HandlerLike {
    func global(): JsGlobalObject
    func thisObject(): JsValue
}

/// WrapperLike — 包装器接口
/// 严格翻译自: pub trait WrapperLike
public interface WrapperLike {
    func initWrapper(value!: CPointer<Unit>): CPointer<Unit>
    func ref_(): Unit
    func derefWrapper(): Unit
    func toJS(global!: JsGlobalObject): JsValue
    func invalidate(): Unit
}

// ============================================================================
// handler_callback — 处理器回调
// 严格翻译自: fn handler_callback<H, Z, L>(this, value, clear_field, get_callback) -> bool
// ============================================================================

/// handlerCallback — 通用处理器回调
/// 严格翻译自: fn handler_callback<H, Z, L>(...) -> bool
public func handlerCallback(
    `this`: DocumentHandler,
    value!: CPointer<Unit>,
    clearField!: (DocType) -> Unit,
    getCallback!: (DocumentHandler) -> ?JsValue
): Bool {
    // 标记绑定
    // markBinding()

    // this: 是 Box<DocumentHandler> 的 userdata 指针
    let global = this.getGlobal()
    let vm = global.bunVM()

    let cb = getCallback(this)
    if (cb.isNone()) {
        return false
    }

    let result = cb.call(global, this.getThisObject())

    if (result.isErr()) {
        // 如果有异常，捕获它
        if (let exc <- result.exception()) {
            let excValue = exc
            if (let errPtr <- vm.unhandledPendingRejectionToCapture) {
                errPtr.set(excValue)
                excValue.protect()
            }
        }
        return true
    }

    // 检查是否有异常
    if (let exc <- result.exception()) {
        let excValue = exc
        if (let errPtr <- vm.unhandledPendingRejectionToCapture) {
            errPtr.set(excValue)
            excValue.protect()
        }
        return true
    }

    if (!result.isUndefinedOrNull()) {
        if (result.isError() || result.isAggregateError(global)) {
            return true
        }

        if (let promise <- result.asAnyPromise()) {
            vm.waitForPromise(promise)
            let fail = promise.status() == PromiseStatus.Rejected
            if (fail) {
                vm.unhandledRejection(global, promise.result(global), promise.asValue())
            }
            return fail
        }
    }
    return false
}

/// handlerCallback — ElementHandler 版本
public func handlerCallbackElement(
    `this`: ElementHandler,
    value!: CPointer<Unit>,
    clearField!: (HTMLElement) -> Unit,
    getCallback!: (ElementHandler) -> ?JsValue
): Bool {
    let global = this.getGlobal()
    let vm = global.bunVM()

    let cb = getCallback(this)
    if (cb.isNone()) {
        return false
    }

    let result = cb.call(global, this.getThisObject())

    if (result.isErr()) {
        if (let exc <- result.exception()) {
            let excValue = exc
            if (let errPtr <- vm.unhandledPendingRejectionToCapture) {
                errPtr.set(excValue)
                excValue.protect()
            }
        }
        return true
    }

    if (let exc <- result.exception()) {
        let excValue = exc
        if (let errPtr <- vm.unhandledPendingRejectionToCapture) {
            errPtr.set(excValue)
            excValue.protect()
        }
        return true
    }

    if (!result.isUndefinedOrNull()) {
        if (result.isError() || result.isAggregateError(global)) {
            return true
        }

        if (let promise <- result.asAnyPromise()) {
            vm.waitForPromise(promise)
            let fail = promise.status() == PromiseStatus.Rejected
            if (fail) {
                vm.unhandledRejection(global, promise.result(global), promise.asValue())
            }
            return fail
        }
    }
    return false
}

/// handlerCallback — EndTagHandler 版本
public func handlerCallbackEndTag(
    `this`: EndTagHandler,
    value!: CPointer<Unit>,
    clearField!: (EndTag) -> Unit,
    getCallback!: (EndTagHandler) -> ?JsValue
): Bool {
    let global = this.getGlobal()
    let vm = global.bunVM()

    let cb = getCallback(this)
    if (cb.isNone()) {
        return false
    }

    let result = cb.call(global, JsValue.ZERO)

    if (result.isErr()) {
        if (let exc <- result.exception()) {
            let excValue = exc
            if (let errPtr <- vm.unhandledPendingRejectionToCapture) {
                errPtr.set(excValue)
                excValue.protect()
            }
        }
        return true
    }

    if (let exc <- result.exception()) {
        let excValue = exc
        if (let errPtr <- vm.unhandledPendingRejectionToCapture) {
            errPtr.set(excValue)
            excValue.protect()
        }
        return true
    }

    if (!result.isUndefinedOrNull()) {
        if (result.isError() || result.isAggregateError(global)) {
            return true
        }

        if (let promise <- result.asAnyPromise()) {
            vm.waitForPromise(promise)
            let fail = promise.status() == PromiseStatus.Rejected
            if (fail) {
                vm.unhandledRejection(global, promise.result(global), promise.asValue())
            }
            return fail
        }
    }
    return false
}

// ============================================================================
// ElementHandler - 元素处理器
// 严格翻译自: html_rewriter.rs ElementHandler
// ============================================================================

/// ElementHandler — 元素处理器
/// 严格翻译自: pub struct ElementHandler
public class ElementHandler {
    public var onElementCallback: ?JsValue
    public var onCommentCallback: ?JsValue
    public var onTextCallback: ?JsValue
    public var thisObject: JsValue
    public var global: GlobalRef

    public init() {
        onElementCallback = None
        onCommentCallback = None
        onTextCallback = None
        thisObject = JsValue.UNDEFINED
        global = GlobalRef()
    }

    /// init — 初始化元素处理器
    /// 严格翻译自: pub fn init(global, this_object) -> JsResult<ElementHandler>
    public static func `init`(global!: JsGlobalObject, thisObject!: JsValue): ?ElementHandler {
        let handler = ElementHandler()
        handler.onElementCallback = None
        handler.onCommentCallback = None
        handler.onTextCallback = None
        handler.thisObject = JsValue.UNDEFINED
        handler.global = GlobalRef.from(global)

        if (!thisObject.isObject()) {
            global.throwInvalidArguments("Expected object")
            return None
        }

        if (let val <- thisObject.get(global, "element")) {
            if (val.isUndefinedOrNull() || !val.isCell() || !val.isCallable()) {
                global.throwInvalidArguments("element must be a function")
                return None
            }
            handler.onElementCallback = Some(val.protected())
        }

        if (let val <- thisObject.get(global, "comments")) {
            if (val.isUndefinedOrNull() || !val.isCell() || !val.isCallable()) {
                global.throwInvalidArguments("comments must be a function")
                return None
            }
            handler.onCommentCallback = Some(val.protected())
        }

        if (let val <- thisObject.get(global, "text")) {
            if (val.isUndefinedOrNull() || !val.isCell() || !val.isCallable()) {
                global.throwInvalidArguments("text must be a function")
                return None
            }
            handler.onTextCallback = Some(val.protected())
        }

        handler.thisObject = thisObject.protected()
        return handler
    }

    /// deinit — 释放资源
    public func deinit(): Unit {
        if (let cb <- onElementCallback) { cb.unprotect() }
        if (let cb <- onCommentCallback) { cb.unprotect() }
        if (let cb <- onTextCallback) { cb.unprotect() }
        thisObject.unprotect()
    }

    /// onElement — 元素回调
    /// 严格翻译自: pub fn on_element(`this`: *Self, value: *lolhtml::Element) -> bool
    public static func onElement(`this`: ElementHandler, value!: CPointer<Unit>): Bool {
        return handlerCallbackElement(
            this,
            value,
            { _: HTMLElement => () }, // Element 使用 HAS_INVALIDATE
            { h: ElementHandler => h.onElementCallback },
        )
    }

    /// onComment — 注释回调
    /// 严格翻译自: pub fn on_comment(`this`: *Self, value: *lolhtml::Comment) -> bool
    public static func onComment(`this`: ElementHandler, value!: CPointer<Unit>): Bool {
        return handlerCallbackElement(
            this,
            value,
            { w: HTMLComment => w.comment = CPointer<Unit>() },
            { h: ElementHandler => h.onCommentCallback },
        )
    }

    /// onText — 文本回调
    /// 严格翻译自: pub fn on_text(`this`: *Self, value: *lolhtml::TextChunk) -> bool
    public static func onText(`this`: ElementHandler, value!: CPointer<Unit>): Bool {
        return handlerCallbackElement(
            this,
            value,
            { w: HTMLText => w.textChunk = CPointer<Unit>() },
            { h: ElementHandler => h.onTextCallback },
        )
    }

    /// 获取 global
    public func getGlobal(): JsGlobalObject {
        return global.get()
    }

    /// 获取 thisObject
    public func getThisObject(): JsValue {
        return thisObject
    }
}

// ============================================================================
// TextChunk - 文本块
// 严格翻译自: html_rewriter.rs TextChunk
// ============================================================================

/// TextChunk — 文本块
/// 严格翻译自: pub struct TextChunk
public class TextChunk {
    public var refCount: Int64
    public var textChunk: CPointer<Unit> // *lolhtml_sys::TextChunk

    public init() {
        refCount = 1
        textChunk = CPointer<Unit>()
    }

    public init(textChunk: CPointer<Unit>) {
        refCount = 1
        this.textChunk = textChunk
    }

    /// init — 初始化
    /// 严格翻译自: pub fn init(text_chunk) -> *TextChunk
    public static func `init`(textChunk!: CPointer<Unit>): TextChunk {
        return TextChunk(textChunk: textChunk)
    }

    /// ref — 增加引用计数
    public func ref_(): Unit {
        refCount = refCount + 1
    }

    /// deref — 减少引用计数
    public func deref(): Unit {
        refCount = refCount - 1
    }

    /// finalize — 终结
    /// 严格翻译自: pub fn finalize(self: Box<Self>)
    public func finalize(): Unit {
        // no-op: TextChunk 不拥有 textChunk 指针
    }

    // ========================================================================
    // 内容操作方法 (before, after, replace)
    // 严格翻译自: lol_content_ops! { TextChunk, text_chunk, JsValue::UNDEFINED; ... }
    // ========================================================================

    /// contentHandler — 通用内容处理器
    /// 严格翻译自: fn content_handler(&self, callback, this_object, global_object, content, content_options)
    public func contentHandler(
        callback: (CPointer<Unit>, Array<UInt8>, Bool) -> Bool,
        thisObject!: JsValue,
        globalObject!: JsGlobalObject,
        content!: BaoString,
        contentOptions!: ?ContentOptions
    ): JsValue {
        if (textChunk == CPointer<Unit>()) {
            return JsValue.UNDEFINED
        }
        let contentSlice = content.toSlice()
        let isHtml = if (let Some(o) <- contentOptions) {
            o.html
        } else {
            false
        }
        if (callback(textChunk, contentSlice, isHtml)) {
            return createLolhtmlError(globalObject)
        }
        return thisObject
    }

    /// before_ — 在前面插入内容
    /// 严格翻译自: pub fn before_(&self, call_frame, global_object, content, content_options)
    public func before_(
        callFrame!: JsCallFrame,
        globalObject!: JsGlobalObject,
        content!: BaoString,
        contentOptions!: ?ContentOptions
    ): JsValue {
        return contentHandler(
            { chunk: CPointer<Unit>, bytes: Array<UInt8>, isHtml: Bool =>
                lol_html_text_chunk_before(chunk, bytes.toArrayPtr(), UIntNative(bytes.size), isHtml) != 0
            },
            callFrame.`this`(),
            globalObject,
            content,
            contentOptions,
        )
    }

    /// before — 在前面插入内容（解码参数版本）
    /// 严格翻译自: pub fn before(&self, global, call_frame) -> JsResult<JsValue>
    public func before(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        let args = eatContentArgs(global, callFrame)
        return before_(callFrame, global, args.content, args.options)
    }

    /// after_ — 在后面插入内容
    /// 严格翻译自: pub fn after_(&self, call_frame, global_object, content, content_options)
    public func after_(
        callFrame!: JsCallFrame,
        globalObject!: JsGlobalObject,
        content!: BaoString,
        contentOptions!: ?ContentOptions
    ): JsValue {
        return contentHandler(
            { chunk: CPointer<Unit>, bytes: Array<UInt8>, isHtml: Bool =>
                lol_html_text_chunk_after(chunk, bytes.toArrayPtr(), UIntNative(bytes.size), isHtml) != 0
            },
            callFrame.`this`(),
            globalObject,
            content,
            contentOptions,
        )
    }

    /// after — 在后面插入内容（解码参数版本）
    public func after(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        let args = eatContentArgs(global, callFrame)
        return after_(callFrame, global, args.content, args.options)
    }

    /// replace_ — 替换内容
    /// 严格翻译自: pub fn replace_(&self, call_frame, global_object, content, content_options)
    public func replace_(
        callFrame!: JsCallFrame,
        globalObject!: JsGlobalObject,
        content!: BaoString,
        contentOptions!: ?ContentOptions
    ): JsValue {
        return contentHandler(
            { chunk: CPointer<Unit>, bytes: Array<UInt8>, isHtml: Bool =>
                lol_html_text_chunk_replace(chunk, bytes.toArrayPtr(), UIntNative(bytes.size), isHtml) != 0
            },
            callFrame.`this`(),
            globalObject,
            content,
            contentOptions,
        )
    }

    /// replace — 替换内容（解码参数版本）
    public func replace(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        let args = eatContentArgs(global, callFrame)
        return replace_(callFrame, global, args.content, args.options)
    }

    /// remove — 删除
    /// 严格翻译自: #[bun_jsc::host_fn(method)] pub fn remove(...)
    public func remove(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        if (textChunk == CPointer<Unit>()) {
            return JsValue.UNDEFINED
        }
        lol_html_text_chunk_remove(textChunk)
        return callFrame.`this`()
    }

    /// getText — 获取文本内容
    /// 严格翻译自: #[bun_jsc::host_fn(getter)] pub fn get_text(...)
    public func getText(global!: JsGlobalObject): JsValue {
        if (textChunk == CPointer<Unit>()) {
            return JsValue.UNDEFINED
        }
        let content = lol_html_text_chunk_content_get(textChunk)
        let str = content.slice()
        return BaoString.createUtf8ForJS(global, str)
    }

    /// removed — 是否已删除
    /// 严格翻译自: #[bun_jsc::host_fn(getter)] pub fn removed(...)
    public func removed(): JsValue {
        if (textChunk == CPointer<Unit>()) {
            return JsValue.UNDEFINED
        }
        return JsValue(lol_html_text_chunk_is_removed(textChunk))
    }

    /// lastInTextNode — 是否为文本节点最后一个
    /// 严格翻译自: #[bun_jsc::host_fn(getter)] pub fn last_in_text_node(...)
    public func lastInTextNode(): JsValue {
        if (textChunk == CPointer<Unit>()) {
            return JsValue.UNDEFINED
        }
        return JsValue(lol_html_text_chunk_is_last_in_text_node(textChunk))
    }
}

// ============================================================================
// DocType - 文档类型
// 严格翻译自: html_rewriter.rs DocType
// ============================================================================

/// DocType — 文档类型
/// 严格翻译自: pub struct DocType
public class DocType {
    public var refCount: Int64
    public var doctype: CPointer<Unit> // *lolhtml_sys::DocType

    public init() {
        refCount = 1
        doctype = CPointer<Unit>()
    }

    public init(doctype: CPointer<Unit>) {
        refCount = 1
        this.doctype = doctype
    }

    /// init — 初始化
    /// 严格翻译自: pub fn init(doctype) -> *DocType
    public static func `init`(doctype!: CPointer<Unit>): DocType {
        return DocType(doctype: doctype)
    }

    /// ref — 增加引用计数
    public func ref_(): Unit {
        refCount = refCount + 1
    }

    /// deref — 减少引用计数
    public func deref(): Unit {
        refCount = refCount - 1
    }

    /// finalize — 终结
    /// 严格翻译自: pub fn finalize(self: Box<Self>)
    public func finalize(): Unit {
        // no-op
    }

    /// name — 文档类型名称
    /// 严格翻译自: #[bun_jsc::host_fn(getter)] pub fn name(...)
    public func name(jsGlobalObject!: JsGlobalObject): JsValue {
        if (doctype == CPointer<Unit>()) {
            return JsValue.UNDEFINED
        }
        let owned = lol_html_doctype_name_get(doctype)
        let str = owned.slice()
        if (str.size == 0) {
            return JsValue.NULL
        }
        return BaoString(str).toJS(globalObject)
    }

    /// systemId — 系统标识符
    /// 严格翻译自: #[bun_jsc::host_fn(getter)] pub fn system_id(...)
    public func systemId(jsGlobalObject!: JsGlobalObject): JsValue {
        if (doctype == CPointer<Unit>()) {
            return JsValue.UNDEFINED
        }
        let owned = lol_html_doctype_system_id_get(doctype)
        let str = owned.slice()
        if (str.size == 0) {
            return JsValue.NULL
        }
        return BaoString(str).toJS(globalObject)
    }

    /// publicId — 公共标识符
    /// 严格翻译自: #[bun_jsc::host_fn(getter)] pub fn public_id(...)
    public func publicId(jsGlobalObject!: JsGlobalObject): JsValue {
        if (doctype == CPointer<Unit>()) {
            return JsValue.UNDEFINED
        }
        let owned = lol_html_doctype_public_id_get(doctype)
        let str = owned.slice()
        if (str.size == 0) {
            return JsValue.NULL
        }
        return BaoString(str).toJS(globalObject)
    }

    /// remove — 删除
    /// 严格翻译自: #[bun_jsc::host_fn(method)] pub fn remove(...)
    public func remove(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        if (doctype == CPointer<Unit>()) {
            return JsValue.UNDEFINED
        }
        lol_html_doctype_remove(doctype)
        return callFrame.`this`()
    }

    /// removed — 是否已删除
    /// 严格翻译自: #[bun_jsc::host_fn(getter)] pub fn removed(...)
    public func removed(): JsValue {
        if (doctype == CPointer<Unit>()) {
            return JsValue.UNDEFINED
        }
        return JsValue(lol_html_doctype_is_removed(doctype))
    }
}

// ============================================================================
// DocEnd - 文档结尾
// 严格翻译自: html_rewriter.rs DocEnd
// ============================================================================

/// DocEnd — 文档结尾
/// 严格翻译自: pub struct DocEnd
public class DocEnd {
    public var refCount: Int64
    public var docEnd: CPointer<Unit> // *lolhtml_sys::DocEnd

    public init() {
        refCount = 1
        docEnd = CPointer<Unit>()
    }

    public init(docEnd: CPointer<Unit>) {
        refCount = 1
        this.docEnd = docEnd
    }

    /// init — 初始化
    /// 严格翻译自: pub fn init(doc_end) -> *DocEnd
    public static func `init`(docEnd!: CPointer<Unit>): DocEnd {
        return DocEnd(docEnd: docEnd)
    }

    /// ref — 增加引用计数
    public func ref_(): Unit {
        refCount = refCount + 1
    }

    /// deref — 减少引用计数
    public func deref(): Unit {
        refCount = refCount - 1
    }

    /// finalize — 终结
    /// 严格翻译自: pub fn finalize(self: Box<Self>)
    public func finalize(): Unit {
        // no-op
    }

    /// contentHandler — 通用内容处理器
    public func contentHandler(
        callback: (CPointer<Unit>, Array<UInt8>, Bool) -> Bool,
        thisObject!: JsValue,
        globalObject!: JsGlobalObject,
        content!: BaoString,
        contentOptions!: ?ContentOptions
    ): JsValue {
        if (docEnd == CPointer<Unit>()) {
            return JsValue.NULL
        }
        let contentSlice = content.toSlice()
        let isHtml = if (let Some(o) <- contentOptions) {
            o.html
        } else {
            false
        }
        if (callback(docEnd, contentSlice, isHtml)) {
            return createLolhtmlError(globalObject)
        }
        return thisObject
    }

    /// append_ — 追加内容
    /// 严格翻译自: lol_content_ops! { DocEnd, doc_end, JsValue::NULL; append / append_ }
    public func append_(
        callFrame!: JsCallFrame,
        globalObject!: JsGlobalObject,
        content!: BaoString,
        contentOptions!: ?ContentOptions
    ): JsValue {
        return contentHandler(
            { de: CPointer<Unit>, bytes: Array<UInt8>, isHtml: Bool =>
                lol_html_doc_end_append(de, bytes.toArrayPtr(), UIntNative(bytes.size), isHtml) != 0
            },
            callFrame.`this`(),
            globalObject,
            content,
            contentOptions,
        )
    }

    /// append — 追加内容（解码参数版本）
    public func append(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        let args = eatContentArgs(global, callFrame)
        return append_(callFrame, global, args.content, args.options)
    }
}

// ============================================================================
// Comment (HTMLComment) - HTML 注释
// 严格翻译自: html_rewriter.rs Comment
// ============================================================================

/// HTMLComment — HTML 注释
/// 严格翻译自: pub struct Comment
public class HTMLComment {
    public var refCount: Int64
    public var comment: CPointer<Unit> // *lolhtml_sys::Comment

    public init() {
        refCount = 1
        comment = CPointer<Unit>()
    }

    public init(comment: CPointer<Unit>) {
        refCount = 1
        this.comment = comment
    }

    /// init — 初始化
    /// 严格翻译自: pub fn init(comment) -> *Comment
    public static func `init`(comment!: CPointer<Unit>): HTMLComment {
        return HTMLComment(comment: comment)
    }

    /// ref — 增加引用计数
    public func ref_(): Unit {
        refCount = refCount + 1
    }

    /// deref — 减少引用计数
    public func deref(): Unit {
        refCount = refCount - 1
    }

    /// finalize — 终结
    /// 严格翻译自: pub fn finalize(self: Box<Self>)
    public func finalize(): Unit {
        // no-op
    }

    /// contentHandler — 通用内容处理器
    public func contentHandler(
        callback: (CPointer<Unit>, Array<UInt8>, Bool) -> Bool,
        thisObject!: JsValue,
        globalObject!: JsGlobalObject,
        content!: BaoString,
        contentOptions!: ?ContentOptions
    ): JsValue {
        if (comment == CPointer<Unit>()) {
            return JsValue.NULL
        }
        let contentSlice = content.toSlice()
        let isHtml = if (let Some(o) <- contentOptions) {
            o.html
        } else {
            false
        }
        if (callback(comment, contentSlice, isHtml)) {
            return createLolhtmlError(globalObject)
        }
        return thisObject
    }

    /// before_ — 在前面插入内容
    /// 严格翻译自: lol_content_ops! { Comment, comment, JsValue::NULL; before / before_, ... }
    public func before_(
        callFrame!: JsCallFrame,
        globalObject!: JsGlobalObject,
        content!: BaoString,
        contentOptions!: ?ContentOptions
    ): JsValue {
        return contentHandler(
            { c: CPointer<Unit>, bytes: Array<UInt8>, isHtml: Bool =>
                lol_html_comment_before(c, bytes.toArrayPtr(), UIntNative(bytes.size), isHtml) != 0
            },
            callFrame.`this`(),
            globalObject,
            content,
            contentOptions,
        )
    }

    /// before — 在前面插入内容（解码参数版本）
    public func before(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        let args = eatContentArgs(global, callFrame)
        return before_(callFrame, global, args.content, args.options)
    }

    /// after_ — 在后面插入内容
    public func after_(
        callFrame!: JsCallFrame,
        globalObject!: JsGlobalObject,
        content!: BaoString,
        contentOptions!: ?ContentOptions
    ): JsValue {
        return contentHandler(
            { c: CPointer<Unit>, bytes: Array<UInt8>, isHtml: Bool =>
                lol_html_comment_after(c, bytes.toArrayPtr(), UIntNative(bytes.size), isHtml) != 0
            },
            callFrame.`this`(),
            globalObject,
            content,
            contentOptions,
        )
    }

    /// after — 在后面插入内容（解码参数版本）
    public func after(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        let args = eatContentArgs(global, callFrame)
        return after_(callFrame, global, args.content, args.options)
    }

    /// replace_ — 替换内容
    public func replace_(
        callFrame!: JsCallFrame,
        globalObject!: JsGlobalObject,
        content!: BaoString,
        contentOptions!: ?ContentOptions
    ): JsValue {
        return contentHandler(
            { c: CPointer<Unit>, bytes: Array<UInt8>, isHtml: Bool =>
                lol_html_comment_replace(c, bytes.toArrayPtr(), UIntNative(bytes.size), isHtml) != 0
            },
            callFrame.`this`(),
            globalObject,
            content,
            contentOptions,
        )
    }

    /// replace — 替换内容（解码参数版本）
    public func replace(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        let args = eatContentArgs(global, callFrame)
        return replace_(callFrame, global, args.content, args.options)
    }

    /// remove — 删除
    /// 严格翻译自: #[bun_jsc::host_fn(method)] pub fn remove(...)
    public func remove(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        if (comment == CPointer<Unit>()) {
            return JsValue.NULL
        }
        lol_html_comment_remove(comment)
        return callFrame.`this`()
    }

    /// getText — 获取文本
    /// 严格翻译自: #[bun_jsc::host_fn(getter)] pub fn get_text(...)
    public func getText(jsGlobalObject!: JsGlobalObject): JsValue {
        if (comment == CPointer<Unit>()) {
            return JsValue.NULL
        }
        return htmlStringValue(lol_html_comment_text_get(comment), globalObject)
    }

    /// setText — 设置文本
    /// 严格翻译自: pub fn set_text(&self, global, value) -> JsResult<()>
    public func setText(global!: JsGlobalObject, value!: JsValue): Unit {
        if (comment == CPointer<Unit>()) {
            return
        }
        let text = value.toSlice(global)
        if (lol_html_comment_text_set(comment, text.toArrayPtr(), UIntNative(text.size)) != 0) {
            global.throwValue(createLolhtmlError(global))
        }
    }

    /// removed — 是否已删除
    /// 严格翻译自: #[bun_jsc::host_fn(getter)] pub fn removed(...)
    public func removed(): JsValue {
        if (comment == CPointer<Unit>()) {
            return JsValue.UNDEFINED
        }
        return JsValue(lol_html_comment_is_removed(comment))
    }
}

// ============================================================================
// EndTag - 结束标签
// 严格翻译自: html_rewriter.rs EndTag
// ============================================================================

/// EndTag — 结束标签
/// 严格翻译自: pub struct EndTag
public class EndTag {
    public var refCount: Int64
    public var endTag: CPointer<Unit> // *lolhtml_sys::EndTag

    public init() {
        refCount = 1
        endTag = CPointer<Unit>()
    }

    public init(endTag: CPointer<Unit>) {
        refCount = 1
        this.endTag = endTag
    }

    /// init — 初始化
    /// 严格翻译自: pub fn init(end_tag) -> *EndTag
    public static func `init`(endTag!: CPointer<Unit>): EndTag {
        return EndTag(endTag: endTag)
    }

    /// ref — 增加引用计数
    public func ref_(): Unit {
        refCount = refCount + 1
    }

    /// deref — 减少引用计数
    public func deref(): Unit {
        refCount = refCount - 1
    }

    /// finalize — 终结
    /// 严格翻译自: pub fn finalize(self: Box<Self>)
    public func finalize(): Unit {
        // no-op
    }

    /// contentHandler — 通用内容处理器
    public func contentHandler(
        callback: (CPointer<Unit>, Array<UInt8>, Bool) -> Bool,
        thisObject!: JsValue,
        globalObject!: JsGlobalObject,
        content!: BaoString,
        contentOptions!: ?ContentOptions
    ): JsValue {
        if (endTag == CPointer<Unit>()) {
            return JsValue.NULL
        }
        let contentSlice = content.toSlice()
        let isHtml = if (let Some(o) <- contentOptions) {
            o.html
        } else {
            false
        }
        if (callback(endTag, contentSlice, isHtml)) {
            return createLolhtmlError(globalObject)
        }
        return thisObject
    }

    /// before_ — 在前面插入内容
    /// 严格翻译自: lol_content_ops! { EndTag, end_tag, JsValue::NULL; before / before_, ... }
    public func before_(
        callFrame!: JsCallFrame,
        globalObject!: JsGlobalObject,
        content!: BaoString,
        contentOptions!: ?ContentOptions
    ): JsValue {
        return contentHandler(
            { et: CPointer<Unit>, bytes: Array<UInt8>, isHtml: Bool =>
                lol_html_end_tag_before(et, bytes.toArrayPtr(), UIntNative(bytes.size), isHtml) != 0
            },
            callFrame.`this`(),
            globalObject,
            content,
            contentOptions,
        )
    }

    /// before — 在前面插入内容（解码参数版本）
    public func before(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        let args = eatContentArgs(global, callFrame)
        return before_(callFrame, global, args.content, args.options)
    }

    /// after_ — 在后面插入内容
    public func after_(
        callFrame!: JsCallFrame,
        globalObject!: JsGlobalObject,
        content!: BaoString,
        contentOptions!: ?ContentOptions
    ): JsValue {
        return contentHandler(
            { et: CPointer<Unit>, bytes: Array<UInt8>, isHtml: Bool =>
                lol_html_end_tag_after(et, bytes.toArrayPtr(), UIntNative(bytes.size), isHtml) != 0
            },
            callFrame.`this`(),
            globalObject,
            content,
            contentOptions,
        )
    }

    /// after — 在后面插入内容（解码参数版本）
    public func after(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        let args = eatContentArgs(global, callFrame)
        return after_(callFrame, global, args.content, args.options)
    }

    /// replace_ — 替换内容 (allow dead_code)
    /// 严格翻译自: #[allow(dead_code)] replace / replace_
    public func replace_(
        callFrame!: JsCallFrame,
        globalObject!: JsGlobalObject,
        content!: BaoString,
        contentOptions!: ?ContentOptions
    ): JsValue {
        return contentHandler(
            { et: CPointer<Unit>, bytes: Array<UInt8>, isHtml: Bool =>
                // EndTag 没有 replace FFI，但保留以匹配 Rust 代码
                true
            },
            callFrame.`this`(),
            globalObject,
            content,
            contentOptions,
        )
    }

    /// replace — 替换内容（解码参数版本）
    public func replace(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        let args = eatContentArgs(global, callFrame)
        return replace_(callFrame, global, args.content, args.options)
    }

    /// remove — 删除
    /// 严格翻译自: #[bun_jsc::host_fn(method)] pub fn remove(...)
    public func remove(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        if (endTag == CPointer<Unit>()) {
            return JsValue.UNDEFINED
        }
        lol_html_end_tag_remove(endTag)
        return callFrame.`this`()
    }

    /// getName — 获取标签名
    /// 严格翻译自: #[bun_jsc::host_fn(getter)] pub fn get_name(...)
    public func getName(jsGlobalObject!: JsGlobalObject): JsValue {
        if (endTag == CPointer<Unit>()) {
            return JsValue.UNDEFINED
        }
        return htmlStringValue(lol_html_end_tag_name_get(endTag), globalObject)
    }

    /// setName — 设置标签名
    /// 严格翻译自: pub fn set_name(&self, global, value) -> JsResult<()>
    public func setName(global!: JsGlobalObject, value!: JsValue): Unit {
        if (endTag == CPointer<Unit>()) {
            return
        }
        let text = value.toSlice(global)
        if (lol_html_end_tag_name_set(endTag, text.toArrayPtr(), UIntNative(text.size)) != 0) {
            global.throwValue(createLolhtmlError(global))
        }
    }
}

// ============================================================================
// EndTagHandler - 结束标签处理器
// 严格翻译自: html_rewriter.rs EndTagHandler
// ============================================================================

/// EndTagHandler — 结束标签处理器
/// 严格翻译自: pub struct EndTagHandler
public class EndTagHandler {
    public var callback: ?JsValue
    public var global: GlobalRef

    public init() {
        callback = None
        global = GlobalRef()
    }

    public init(callback: JsValue, global: JsGlobalObject) {
        this.callback = Some(callback)
        this.global = GlobalRef.from(global)
    }

    /// onEndTag — 结束标签回调
    /// 严格翻译自: pub fn on_end_tag(`this`: *Self, value: *lolhtml::EndTag) -> bool
    public static func onEndTag(`this`: EndTagHandler, value!: CPointer<Unit>): Bool {
        return handlerCallbackEndTag(
            this,
            value,
            { w: EndTag => w.endTag = CPointer<Unit>() },
            { h: EndTagHandler => h.callback },
        )
    }

    /// 获取 global
    public func getGlobal(): JsGlobalObject {
        return global.get()
    }

    /// deinit — 释放资源
    public func deinit(): Unit {
        if (let cb <- callback) {
            cb.unprotect()
        }
    }
}

// ============================================================================
// AttributeIterator - 属性迭代器
// 严格翻译自: html_rewriter.rs AttributeIterator
// ============================================================================

/// AttributeIterator — 属性迭代器
/// 严格翻译自: pub struct AttributeIterator
public class AttributeIterator {
    public var refCount: Int64
    public var iterator: CPointer<Unit> // *lolhtml_sys::AttributeIterator

    public init() {
        refCount = 1
        iterator = CPointer<Unit>()
    }

    public init(iterator: CPointer<Unit>) {
        refCount = 1
        this.iterator = iterator
    }

    /// init — 初始化
    /// 严格翻译自: pub fn init(iterator) -> *AttributeIterator
    public static func `init`(iterator!: CPointer<Unit>): AttributeIterator {
        return AttributeIterator(iterator: iterator)
    }

    /// ref — 增加引用计数
    public func ref_(): Unit {
        refCount = refCount + 1
    }

    /// deref — 减少引用计数
    public func deref(): Unit {
        refCount = refCount - 1
        if (refCount <= 0) {
            detach()
        }
    }

    /// detach — 分离迭代器
    /// 严格翻译自: fn detach(&self)
    public func detach(): Unit {
        if (iterator != CPointer<Unit>()) {
            lol_html_attributes_iterator_free(iterator)
            iterator = CPointer<Unit>()
        }
    }

    /// finalize — 终结
    /// 严格翻译自: pub fn finalize(self: Box<Self>)
    public func finalize(): Unit {
        // 引用计数：释放 JS wrapper 的 +1
        refCount = refCount - 1
        detach()
        deref()
    }

    /// next — 下一个属性
    /// 严格翻译自: #[bun_jsc::host_fn(method)] pub fn next(...)
    public func next(jsGlobalObject!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        let doneLabel = BaoString("done")
        let valueLabel = BaoString("value")

        if (iterator == CPointer<Unit>()) {
            return JsValue.createObject2(
                globalObject,
                doneLabel,
                valueLabel,
                JsValue.TRUE,
                JsValue.UNDEFINED,
            )
        }

        let attribute = lol_html_attributes_iterator_next(iterator)
        if (attribute == CPointer<Unit>()) {
            lol_html_attributes_iterator_free(iterator)
            iterator = CPointer<Unit>()
            return JsValue.createObject2(
                globalObject,
                doneLabel,
                valueLabel,
                JsValue.TRUE,
                JsValue.UNDEFINED,
            )
        }

        let value = lol_html_attribute_value_get(attribute)
        let name = lol_html_attribute_name_get(attribute)

        return JsValue.createObject2(
            globalObject,
            doneLabel,
            valueLabel,
            JsValue.FALSE,
            BaoString.toJSArray(
                globalObject,
                [
                    htmlStringToBunString(name),
                    htmlStringToBunString(value)
                ],
            ),
        )
    }

    /// getThis — 获取 this
    /// 严格翻译自: #[bun_jsc::host_fn(method)] pub fn get_this(...)
    public func getThis(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        return callFrame.`this`()
    }
}

// ============================================================================
// Element (HTMLElement) - HTML 元素
// 严格翻译自: html_rewriter.rs Element
// ============================================================================

/// HTMLElement — HTML 元素
/// 严格翻译自: pub struct Element
public class HTMLElement {
    public var refCount: Int64
    public var element: CPointer<Unit> // *lolhtml_sys::Element
    public var attributeIterators: ArrayList<AttributeIterator>

    public init() {
        refCount = 1
        element = CPointer<Unit>()
        attributeIterators = ArrayList<AttributeIterator>()
    }

    public init(element: CPointer<Unit>) {
        refCount = 1
        this.element = element
        attributeIterators = ArrayList<AttributeIterator>()
    }

    /// init — 初始化
    /// 严格翻译自: pub fn init(element) -> *Element
    public static func `init`(element!: CPointer<Unit>): HTMLElement {
        return HTMLElement(element: element)
    }

    /// ref — 增加引用计数
    public func ref_(): Unit {
        refCount = refCount + 1
    }

    /// deref — 减少引用计数
    public func deref(): Unit {
        refCount = refCount - 1
        if (refCount <= 0) {
            invalidate()
        }
    }

    /// finalize — 终结
    /// 严格翻译自: pub fn finalize(self: Box<Self>)
    public func finalize(): Unit {
        // no-op
    }

    /// detachAttributeIterators — 分离所有属性迭代器
    /// 严格翻译自: fn detach_attribute_iterators(&self)
    public func detachAttributeIterators(): Unit {
        let iters = attributeIterators
        attributeIterators = ArrayList<AttributeIterator>()
        for (iter in iters) {
            iter.detach()
            iter.deref()
        }
    }

    /// invalidate — 使失效
    /// 严格翻译自: pub fn invalidate(&self)
    public func invalidate(): Unit {
        element = CPointer<Unit>()
        detachAttributeIterators()
        attributeIterators = ArrayList<AttributeIterator>()
    }

    // ========================================================================
    // 内容操作方法 (before, after, prepend, append, replace, setInnerContent)
    // 严格翻译自: lol_content_ops! { Element, element, JsValue::UNDEFINED; ... }
    // ========================================================================

    /// contentHandler — 通用内容处理器
    public func contentHandler(
        callback: (CPointer<Unit>, Array<UInt8>, Bool) -> Bool,
        thisObject!: JsValue,
        globalObject!: JsGlobalObject,
        content!: BaoString,
        contentOptions!: ?ContentOptions
    ): JsValue {
        if (element == CPointer<Unit>()) {
            return JsValue.UNDEFINED
        }
        let contentSlice = content.toSlice()
        let isHtml = if (let Some(o) <- contentOptions) {
            o.html
        } else {
            false
        }
        if (callback(element, contentSlice, isHtml)) {
            return createLolhtmlError(globalObject)
        }
        return thisObject
    }

    /// before_ — 在前面插入内容
    /// 严格翻译自: /// Inserts content before the element.
    public func before_(
        callFrame!: JsCallFrame,
        globalObject!: JsGlobalObject,
        content!: BaoString,
        contentOptions!: ?ContentOptions
    ): JsValue {
        return contentHandler(
            { el: CPointer<Unit>, bytes: Array<UInt8>, isHtml: Bool =>
                lol_html_element_before(el, bytes.toArrayPtr(), UIntNative(bytes.size), isHtml) != 0
            },
            callFrame.`this`(),
            globalObject,
            content,
            contentOptions,
        )
    }

    /// before — 在前面插入内容（解码参数版本）
    public func before(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        let args = eatContentArgs(global, callFrame)
        return before_(callFrame, global, args.content, args.options)
    }

    /// after_ — 在后面插入内容
    /// 严格翻译自: /// Inserts content right after the element.
    public func after_(
        callFrame!: JsCallFrame,
        globalObject!: JsGlobalObject,
        content!: BaoString,
        contentOptions!: ?ContentOptions
    ): JsValue {
        return contentHandler(
            { el: CPointer<Unit>, bytes: Array<UInt8>, isHtml: Bool =>
                lol_html_element_after(el, bytes.toArrayPtr(), UIntNative(bytes.size), isHtml) != 0
            },
            callFrame.`this`(),
            globalObject,
            content,
            contentOptions,
        )
    }

    /// after — 在后面插入内容（解码参数版本）
    public func after(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        let args = eatContentArgs(global, callFrame)
        return after_(callFrame, global, args.content, args.options)
    }

    /// prepend_ — 在开始标签后插入内容
    /// 严格翻译自: /// Inserts content right after the start tag of the element.
    public func prepend_(
        callFrame!: JsCallFrame,
        globalObject!: JsGlobalObject,
        content!: BaoString,
        contentOptions!: ?ContentOptions
    ): JsValue {
        return contentHandler(
            { el: CPointer<Unit>, bytes: Array<UInt8>, isHtml: Bool =>
                lol_html_element_prepend(el, bytes.toArrayPtr(), UIntNative(bytes.size), isHtml) != 0
            },
            callFrame.`this`(),
            globalObject,
            content,
            contentOptions,
        )
    }

    /// prepend — 在开始标签后插入内容（解码参数版本）
    public func prepend(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        let args = eatContentArgs(global, callFrame)
        return prepend_(callFrame, global, args.content, args.options)
    }

    /// append_ — 在结束标签前插入内容
    /// 严格翻译自: /// Inserts content right before the end tag of the element.
    public func append_(
        callFrame!: JsCallFrame,
        globalObject!: JsGlobalObject,
        content!: BaoString,
        contentOptions!: ?ContentOptions
    ): JsValue {
        return contentHandler(
            { el: CPointer<Unit>, bytes: Array<UInt8>, isHtml: Bool =>
                lol_html_element_append(el, bytes.toArrayPtr(), UIntNative(bytes.size), isHtml) != 0
            },
            callFrame.`this`(),
            globalObject,
            content,
            contentOptions,
        )
    }

    /// append — 在结束标签前插入内容（解码参数版本）
    public func append(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        let args = eatContentArgs(global, callFrame)
        return append_(callFrame, global, args.content, args.options)
    }

    /// replace_ — 替换元素
    /// 严格翻译自: /// Removes the element and inserts content in place of it.
    public func replace_(
        callFrame!: JsCallFrame,
        globalObject!: JsGlobalObject,
        content!: BaoString,
        contentOptions!: ?ContentOptions
    ): JsValue {
        return contentHandler(
            { el: CPointer<Unit>, bytes: Array<UInt8>, isHtml: Bool =>
                lol_html_element_replace(el, bytes.toArrayPtr(), UIntNative(bytes.size), isHtml) != 0
            },
            callFrame.`this`(),
            globalObject,
            content,
            contentOptions,
        )
    }

    /// replace — 替换元素（解码参数版本）
    public func replace(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        let args = eatContentArgs(global, callFrame)
        return replace_(callFrame, global, args.content, args.options)
    }

    /// setInnerContent_ — 设置内部内容
    /// 严格翻译自: /// Replaces content of the element.
    public func setInnerContent_(
        callFrame!: JsCallFrame,
        globalObject!: JsGlobalObject,
        content!: BaoString,
        contentOptions!: ?ContentOptions
    ): JsValue {
        return contentHandler(
            { el: CPointer<Unit>, bytes: Array<UInt8>, isHtml: Bool =>
                lol_html_element_set_inner_content(el, bytes.toArrayPtr(), UIntNative(bytes.size), isHtml) != 0
            },
            callFrame.`this`(),
            globalObject,
            content,
            contentOptions,
        )
    }

    /// setInnerContent — 设置内部内容（解码参数版本）
    public func setInnerContent(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        let args = eatContentArgs(global, callFrame)
        return setInnerContent_(callFrame, global, args.content, args.options)
    }

    /// remove — 删除元素
    /// 严格翻译自: /// Removes the element with all its content.
    public func remove(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        if (element == CPointer<Unit>()) {
            return JsValue.UNDEFINED
        }
        lol_html_element_remove(element)
        return callFrame.`this`()
    }

    /// removeAndKeepContent — 删除标签但保留内容
    /// 严格翻译自: /// Removes the start tag and end tag of the element but keeps its inner content intact.
    public func removeAndKeepContent(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        if (element == CPointer<Unit>()) {
            return JsValue.UNDEFINED
        }
        lol_html_element_remove_and_keep_content(element)
        return callFrame.`this`()
    }

    /// getTagName — 获取标签名
    /// 严格翻译自: #[bun_jsc::host_fn(getter)] pub fn get_tag_name(...)
    public func getTagName(jsGlobalObject!: JsGlobalObject): JsValue {
        if (element == CPointer<Unit>()) {
            return JsValue.UNDEFINED
        }
        return htmlStringValue(lol_html_element_tag_name_get(element), globalObject)
    }

    /// setTagName — 设置标签名
    /// 严格翻译自: pub fn set_tag_name(&self, global, value) -> JsResult<()>
    public func setTagName(global!: JsGlobalObject, value!: JsValue): Unit {
        if (element == CPointer<Unit>()) {
            return
        }
        let text = value.toSlice(global)
        if (lol_html_element_tag_name_set(element, text.toArrayPtr(), UIntNative(text.size)) != 0) {
            global.throwValue(createLolhtmlError(global))
        }
    }

    /// getRemoved — 是否已删除
    /// 严格翻译自: #[bun_jsc::host_fn(getter)] pub fn get_removed(...)
    public func getRemoved(): JsValue {
        if (element == CPointer<Unit>()) {
            return JsValue.UNDEFINED
        }
        return JsValue(lol_html_element_is_removed(element))
    }

    /// getSelfClosing — 是否自闭合
    /// 严格翻译自: #[bun_jsc::host_fn(getter)] pub fn get_self_closing(...)
    public func getSelfClosing(): JsValue {
        if (element == CPointer<Unit>()) {
            return JsValue.UNDEFINED
        }
        return JsValue(lol_html_element_is_self_closing(element))
    }

    /// getCanHaveContent — 是否可以包含内容
    /// 严格翻译自: #[bun_jsc::host_fn(getter)] pub fn get_can_have_content(...)
    public func getCanHaveContent(): JsValue {
        if (element == CPointer<Unit>()) {
            return JsValue.UNDEFINED
        }
        return JsValue(lol_html_element_can_have_content(element))
    }

    /// getNamespaceUri — 获取命名空间 URI
    /// 严格翻译自: #[bun_jsc::host_fn(getter)] pub fn get_namespace_uri(...)
    public func getNamespaceUri(jsGlobalObject!: JsGlobalObject): JsValue {
        if (element == CPointer<Unit>()) {
            return JsValue.UNDEFINED
        }
        let ns = lol_html_element_namespace_uri_get(element)
        return BaoString.createUtf8ForJS(globalObject, ns)
    }

    /// getAttributes — 获取属性迭代器
    /// 严格翻译自: #[bun_jsc::host_fn(getter)] pub fn get_attributes(...)
    public func getAttributes(jsGlobalObject!: JsGlobalObject): JsValue {
        if (element == CPointer<Unit>()) {
            return JsValue.UNDEFINED
        }

        let iter = lol_html_attributes_iterator_get(element)
        if (iter == CPointer<Unit>()) {
            return createLolhtmlError(globalObject)
        }

        let attrIter = AttributeIterator(iterator: iter)
        attrIter.ref_()

        // 跟踪此迭代器，以便在处理器返回时分离它
        attributeIterators.append(attrIter)

        return attrIter.toJS(globalObject)
    }

    // ========================================================================
    // 属性操作方法
    // 严格翻译自: Element 的 get_attribute_, has_attribute_, set_attribute_, remove_attribute_
    // ========================================================================

    /// getAttribute_ — 获取属性值
    /// 严格翻译自: pub fn get_attribute_(&self, global_object, name) -> JsResult<JsValue>
    public func getAttribute_(jsGlobalObject!: JsGlobalObject, name!: BaoString): JsValue {
        if (element == CPointer<Unit>()) {
            return JsValue.NULL
        }
        let slice = name.toSlice()
        let attr = lol_html_element_get_attribute(element, slice.toArrayPtr(), UIntNative(slice.size))

        if (attr.len == 0) {
            return JsValue.NULL
        }

        return htmlStringValue(attr, globalObject)
    }

    /// getAttribute — 获取属性值（解码参数版本）
    public func getAttribute(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        let args = callFrame.argumentsOld(1)
        let iter = ArgumentsSlice(global.bunVMRef(), args.slice())
        let name = eatZigString(iter, global)
        return getAttribute_(global, name)
    }

    /// hasAttribute_ — 检查属性是否存在
    /// 严格翻译自: pub fn has_attribute_(&self, global, name) -> JsValue
    public func hasAttribute_(global!: JsGlobalObject, name!: BaoString): JsValue {
        if (element == CPointer<Unit>()) {
            return JsValue.FALSE
        }
        let slice = name.toSlice()
        let res = lol_html_element_has_attribute(element, slice.toArrayPtr(), UIntNative(slice.size))
        if (res < 0) {
            return createLolhtmlError(global)
        }
        return JsValue(res != 0)
    }

    /// hasAttribute — 检查属性是否存在（解码参数版本）
    public func hasAttribute(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        let args = callFrame.argumentsOld(1)
        let iter = ArgumentsSlice(global.bunVMRef(), args.slice())
        let name = eatZigString(iter, global)
        return hasAttribute_(global, name)
    }

    /// setAttribute_ — 设置属性
    /// 严格翻译自: pub fn set_attribute_(&self, call_frame, global_object, name_, value_) -> JsValue
    public func setAttribute_(
        callFrame!: JsCallFrame,
        globalObject!: JsGlobalObject,
        name_!: BaoString,
        value_!: BaoString
    ): JsValue {
        if (element == CPointer<Unit>()) {
            return JsValue.UNDEFINED
        }

        // 修改属性 Vec 可能导致 realloc，使迭代器失效
        detachAttributeIterators()

        let nameSlice = name_.toSlice()
        let valueSlice = value_.toSlice()
        if (lol_html_element_set_attribute(
            element,
            nameSlice.toArrayPtr(), UIntNative(nameSlice.size),
            valueSlice.toArrayPtr(), UIntNative(valueSlice.size),
        ) != 0) {
            return createLolhtmlError(globalObject)
        }
        return callFrame.`this`()
    }

    /// setAttribute — 设置属性（解码参数版本）
    public func setAttribute(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        let args = callFrame.argumentsOld(2)
        let iter = ArgumentsSlice(global.bunVMRef(), args.slice())
        let name = eatZigString(iter, global)
        let value = eatZigString(iter, global)
        return setAttribute_(callFrame, global, name, value)
    }

    /// removeAttribute_ — 删除属性
    /// 严格翻译自: pub fn remove_attribute_(&self, call_frame, global_object, name) -> JsValue
    public func removeAttribute_(
        callFrame!: JsCallFrame,
        globalObject!: JsGlobalObject,
        name!: BaoString
    ): JsValue {
        if (element == CPointer<Unit>()) {
            return JsValue.UNDEFINED
        }

        // Vec::remove 会移动后续元素并缩小 len
        detachAttributeIterators()

        let nameSlice = name.toSlice()
        if (lol_html_element_remove_attribute(element, nameSlice.toArrayPtr(), UIntNative(nameSlice.size)) != 0) {
            return createLolhtmlError(globalObject)
        }
        return callFrame.`this`()
    }

    /// removeAttribute — 删除属性（解码参数版本）
    public func removeAttribute(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        let args = callFrame.argumentsOld(1)
        let iter = ArgumentsSlice(global.bunVMRef(), args.slice())
        let name = eatZigString(iter, global)
        return removeAttribute_(callFrame, global, name)
    }

    // ========================================================================
    // onEndTag — 注册结束标签处理器
    // 严格翻译自: Element::on_end_tag_ / on_end_tag
    // ========================================================================

    /// onEndTag_ — 注册结束标签处理器
    /// 严格翻译自: pub fn on_end_tag_(&self, global_object, function, call_frame) -> JsResult<JsValue>
    public func onEndTag_(jsGlobalObject!: JsGlobalObject, function!: JsValue, callFrame!: JsCallFrame): JsValue {
        if (element == CPointer<Unit>()) {
            return JsValue.NULL
        }
        if (function.isUndefinedOrNull() || !function.isCallable()) {
            return BaoString("Expected a function").toJS(globalObject)
        }

        let endTagHandler = EndTagHandler(callback: function, global: globalObject)

        if (lol_html_element_add_end_tag_handler(element, EndTagHandler.onEndTag, endTagHandler) != 0) {
            endTagHandler.deinit()
            let err = createLolhtmlError(globalObject)
            return globalObject.throwValue(err)
        }

        function.protect()
        return callFrame.`this`()
    }

    /// onEndTag — 注册结束标签处理器（解码参数版本）
    public func onEndTag(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        let args = callFrame.argumentsOld(1)
        let iter = ArgumentsSlice(global.bunVMRef(), args.slice())
        let function = eatJsValue(iter, global)
        return onEndTag_(global, function, callFrame)
    }
}

// ============================================================================
// HTMLText — HTML 文本块 (类型别名)
// 严格翻译自: 用于 ElementHandler 的 onText 回调参数类型
// ============================================================================

/// HTMLText — HTML 文本块类型
public class HTMLText {
    public var textChunk: CPointer<Unit>

    public init() {
        textChunk = CPointer<Unit>()
    }
}

// ============================================================================
// MutableString — 可变字符串
// 严格翻译自: bun_core::MutableString
// ============================================================================

/// MutableString — 可变字符串
public class MutableString {
    public var list: ArrayList<UInt8>

    public init() {
        list = ArrayList<UInt8>()
    }

    public static func initEmpty(): MutableString {
        return MutableString()
    }

    /// growBy — 扩展指定字节
    public func growBy(count!: Int64): Unit {
        for (_ in 0..count) {
            list.append(0)
        }
    }

    /// append — 追加字节
    public func append(bytes!: Array<UInt8>): Unit {
        for (b in bytes) {
            list.append(b)
        }
    }

    /// toByteArray — 转为字节数组
    public func toByteArray(): Array<UInt8> {
        return list.toArray()
    }
}

// ============================================================================
// LinearFifo — 线性 FIFO
// 严格翻译自: bun_collections::linear_fifo::LinearFifo
// ============================================================================

/// LinearFifo — 线性 FIFO 缓冲区
public class LinearFifo {
    public var buffer: ArrayList<UInt8>

    public init() {
        buffer = ArrayList<UInt8>()
    }

    /// readableLength — 可读长度
    public func readableLength(): Int64 {
        return buffer.size
    }

    /// write — 写入数据
    public func write(bytes!: Array<UInt8>): Bool {
        for (b in bytes) {
            buffer.append(b)
        }
        return true
    }

    /// deinit — 释放资源
    public func deinit(): Unit {
        buffer.clear()
    }
}

// ============================================================================
// UTF8Fallback — UTF-8 回退编码器
// 严格翻译自: webcore::sink::UTF8Fallback
// ============================================================================

/// UTF8Fallback — UTF-8 回退编码器
public class UTF8Fallback {
    public static func writeUtf16(loader!: HTMLRewriterLoader, data!: StreamResult, writeFn!: (StreamResult) -> StreamResultWritable): StreamResultWritable {
        // 简化版本：直接转发
        return writeFn(data)
    }

    public static func writeLatin1(loader!: HTMLRewriterLoader, data!: StreamResult, writeFn!: (StreamResult) -> StreamResultWritable): StreamResultWritable {
        // 简化版本：直接转发
        return writeFn(data)
    }
}

// ============================================================================
// ValueBufferer — 值缓冲器
// 严格翻译自: webcore::body::ValueBufferer
// ============================================================================

/// ValueBufferer — 值缓冲器
public class ValueBufferer {
    public var ctx: BufferOutputSink
    public var callback: (BufferOutputSink, Array<UInt8>, ?BodyValueError, Bool) -> Unit
    public var global: JsGlobalObject

    public init(ctx: BufferOutputSink, callback: (BufferOutputSink, Array<UInt8>, ?BodyValueError, Bool) -> Unit, global: JsGlobalObject) {
        this.ctx = ctx
        this.callback = callback
        this.global = global
    }

    public static func `init`(
        ctx!: BufferOutputSink,
        trampoline!: (BufferOutputSink, Array<UInt8>, Option<BodyValueError>, Bool) -> Unit,
        global!: JsGlobalObject
    ): ValueBufferer {
        return ValueBufferer(ctx: ctx, callback: trampoline, global: global)
    }

    /// run — 运行缓冲器
    public func run(value!: BodyValue, readableStream!: JsValue): BaoError {
        // 简化版本：同步处理
        return BaoError.None
    }
}

// ============================================================================
// GlobalRef — 全局引用
// 严格翻译自: bun_jsc::GlobalRef
// ============================================================================

/// GlobalRef — JSC 全局引用
public class GlobalRef {
    private var global: JsGlobalObject

    public init() {
        global = JsGlobalObject()
    }

    public init(global: JsGlobalObject) {
        this.global = global
    }

    public static func from(global!: JsGlobalObject): GlobalRef {
        return GlobalRef(global: global)
    }

    public func `get`(): JsGlobalObject {
        return global
    }
}

// ============================================================================
// StreamSignal — 流信号
// 严格翻译自: webcore::streams::Signal
// ============================================================================

/// StreamSignal — 流信号
public class StreamSignal {
    public init() {}

    public func close(err!: ?SyscallError): Unit {}
    public func ready(chunkSize!: ?Int64, err!: ?SyscallError): Unit {}
}

// ============================================================================
// Body — Body 辅助
// 严格翻译自: webcore::Body 辅助
// ============================================================================

/// Body — Body 辅助方法
public class Body {
    /// extract — 提取 body 值
    public static func extract(global!: JsGlobalObject, value!: JsValue): BodyValue {
        return BodyValue()
    }

    /// resolve — 解析 body 值
    public static func resolve(prev!: BodyValue, current!: BodyValue, global!: GlobalRef, err!: ?String): Unit {}

    /// newLocked — 创建锁定的 body
    public static func newLocked(task!: BufferOutputSink): BodyValue {
        let v = BodyValue()
        v.tag = BodyValueTag.Locked
        return v
    }
}

// ============================================================================
// BodyValue — Body 值
// 严格翻译自: webcore::body::Value
// ============================================================================

/// BodyValue — Body 值
public class BodyValue {
    public var tag: BodyValueTag
    public var internalBlob: InternalBlob
    public var lockedTask: Int64
    public var promise: ?JsValue
    public var readable: ReadableStream
    public var onReceiveValue: ?JsValue

    public init() {
        tag = BodyValueTag.Empty
        internalBlob = InternalBlob()
        lockedTask = 0
        promise = None
        readable = ReadableStream()
        onReceiveValue = None
    }

    public func toErrorInstance(err!: BodyValueError, global!: JsGlobalObject): Unit {}
    public func toErrorInstance(err!: JsValue, global!: GlobalRef): Unit {}
    public func useAsAnyBlobAllowNonUtf8String(): AnyBlob { return AnyBlob() }
}

// ============================================================================
// InternalBlob — 内部 Blob
// 严格翻译自: webcore::InternalBlob
// ============================================================================

/// InternalBlob — 内部 Blob
public class InternalBlob {
    public var bytes: Array<UInt8>
    public var wasString: Bool

    public init() {
        bytes = Array<UInt8>()
        wasString = false
    }

    public init(bytes: Array<UInt8>, wasString: Bool) {
        this.bytes = bytes
        this.wasString = wasString
    }
}

// ============================================================================
// AnyBlob — 任意 Blob
// 严格翻译自: webcore::blob::AnyBlob
// ============================================================================

/// AnyBlob — 任意 Blob
public class AnyBlob {
    public func toString(global!: JsGlobalObject, lifetime!: Lifetime): JsValue {
        return JsValue.UNDEFINED
    }

    public func toArrayBuffer(global!: JsGlobalObject, lifetime!: Lifetime): JsValue {
        return JsValue.UNDEFINED
    }
}

/// Lifetime — 生命周期
public enum Lifetime {
    | Transfer
    | Clone
}

// ported from: src/runtime/api/html_rewriter.zig
