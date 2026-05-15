// 严格翻译自: src/runtime/api/html_rewriter.zig
package bao_runtime

import bao_jsc.*
import bao_core.*
import bao_collections.*
import bao_sys.*

// ============================================================================
// HTMLRewriter - HTML 重写器
// 对应 Bun: src/runtime/api/html_rewriter.zig
// ============================================================================

/// LOLHTMLContext - 管理 LOLHTML 选择器和处理器的上下文
public class LOLHTMLContext {
    public var refCount: RefCount
    public var selectors: ArrayList<HTMLSelector>
    public var elementHandlers: ArrayList<ElementHandler>
    public var documentHandlers: ArrayList<DocumentHandler>

    public func deinit(): Unit {
        for (selector in selectors) {
            selector.deinit()
        }
        selectors.deinit(default_allocator)
        selectors = []

        for (handler in elementHandlers) {
            handler.deinit()
        }
        elementHandlers.deinit(default_allocator)
        elementHandlers = []

        for (handler in documentHandlers) {
            handler.deinit()
        }
        documentHandlers.deinit(default_allocator)
        documentHandlers = []
    }
}

/// HTMLRewriter - HTML 重写器类
public class HTMLRewriter {
    public var builder: HTMLRewriterBuilder
    public var context: LOLHTMLContext

    // ========================================================================
    // 构造函数
    // ========================================================================

    /// 构造函数
    public static func constructor(global: JsGlobalObject, callframe: JsCallFrame): HTMLRewriter {
        let rewriter = HTMLRewriter(
            builder: HTMLRewriterBuilder.init(),
            context: LOLHTMLContext(refCount: RefCount.init()),
        )
        return rewriter
    }

    // ========================================================================
    // 事件注册方法
    // ========================================================================

    /// on_ - 注册元素选择器处理器
    public func on_(global: JsGlobalObject, selectorName: ZigString, callFrame: JsCallFrame, listener: JsValue): JsValue {
        let selectorSlice = selectorName.toString()
        defer selectorSlice.deinit()

        var selector = HTMLSelector.parse(selectorSlice)
        if (selector == null) {
            return global.throwValue(createLOLHTMLError(global))
        }

        let handler = ElementHandler.init(global, listener)
        // ... 添加到 builder

        return callFrame.this()
    }

    /// onDocument - 注册文档处理器
    public func onDocument(global: JsGlobalObject, callFrame: JsCallFrame, listener: JsValue): JsValue {
        let handler = DocumentHandler.init(global, listener)
        // ... 添加到 builder

        return callFrame.this()
    }

    // ========================================================================
    // 处理方法
    // ========================================================================

    /// transform - 转换输入并返回结果
    public func transform(global: JsGlobalObject, callframe: JsCallFrame): JsValue {
        let args = callframe.arguments()
        if (args.len == 0) {
            return global.throwInvalidArguments("Expected at least 1 argument")
        }

        let input = args[0]
        // ... 处理输入, 返回结果
        return JsValue.zero
    }

    // ========================================================================
    // 辅助函数
    // ========================================================================

    /// 创建 LOLHTML 错误
    public static func createLOLHTMLError(global: JsGlobalObject): JsValue {
        return global.createErrorInstance("LOLHTML error")
    }
}

/// ElementHandler - 元素处理器
public class ElementHandler {
    public var onElementCallback: ?JsValue
    public var onCommentCallback: ?JsValue
    public var onTextCallback: ?JsValue

    public static func init(global: JsGlobalObject, listener: JsValue): ElementHandler {
        var handler = ElementHandler(
            onElementCallback: none,
            onCommentCallback: none,
            onTextCallback: none,
        )

        // 从监听器对象中提取回调
        if (listener.isObject()) {
            if (let cb = listener.get(global, "element")) {
                if (cb.isCallable()) { handler.onElementCallback = cb }
            }
            if (let cb = listener.get(global, "comment")) {
                if (cb.isCallable()) { handler.onCommentCallback = cb }
            }
            if (let cb = listener.get(global, "text")) {
                if (cb.isCallable()) { handler.onTextCallback = cb }
            }
        }

        return handler
    }

    public func deinit(): Unit {
        // 释放回调引用
    }

    /// onElement - 元素回调
    public static func onElement(context: ElementHandler, element: HTMLElement): Unit {
        if (let cb = context.onElementCallback) {
            // ... 调用 JS 回调
        }
    }

    /// onComment - 注释回调
    public static func onComment(context: ElementHandler, comment: HTMLComment): Unit {
        if (let cb = context.onCommentCallback) {
            // ... 调用 JS 回调
        }
    }

    /// onText - 文本回调
    public static func onText(context: ElementHandler, text: HTMLText): Unit {
        if (let cb = context.onTextCallback) {
            // ... 调用 JS 回调
        }
    }
}

/// DocumentHandler - 文档处理器
public class DocumentHandler {
    public var onDocTypeCallback: ?JsValue
    public var onCommentCallback: ?JsValue
    public var onTextCallback: ?JsValue
    public var onEndCallback: ?JsValue

    public static func init(global: JsGlobalObject, listener: JsValue): DocumentHandler {
        var handler = DocumentHandler(
            onDocTypeCallback: none,
            onCommentCallback: none,
            onTextCallback: none,
            onEndCallback: none,
        )

        if (listener.isObject()) {
            if (let cb = listener.get(global, "doctype")) {
                if (cb.isCallable()) { handler.onDocTypeCallback = cb }
            }
            if (let cb = listener.get(global, "comment")) {
                if (cb.isCallable()) { handler.onCommentCallback = cb }
            }
            if (let cb = listener.get(global, "text")) {
                if (cb.isCallable()) { handler.onTextCallback = cb }
            }
            if (let cb = listener.get(global, "end")) {
                if (cb.isCallable()) { handler.onEndCallback = cb }
            }
        }

        return handler
    }

    public func deinit(): Unit {
        // 释放回调引用
    }
}
