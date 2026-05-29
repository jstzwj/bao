// 严格翻译自: src/runtime/api/html_rewriter.rs
// TODO: 恢复完整 HTMLRewriter/lol-html 流式转换实现。
package bao_runtime.api

import bao_jsc.{ArgumentsSlice, JsGlobalObject, JsValue}

public func htmlStringToBunString(s!: HTMLString): String { return "" }
public func systemError(code!: String, message!: String): SystemError { return SystemError() }
public func createLolhtmlError(global!: JsGlobalObject): JsValue { return JsValue.jsUndefined() }
public func createLolhtmlStringError(): String { return "" }
public func htmlStringValue(input!: HTMLString, globalObject!: JsGlobalObject): JsValue { return JsValue.jsUndefined() }
public func eatZigString(iter!: ArgumentsSlice, global!: JsGlobalObject): String { return "" }
public func eatJsValue(iter!: ArgumentsSlice, global!: JsGlobalObject): JsValue { return JsValue.jsUndefined() }
public func eatContentOptions(iter!: ArgumentsSlice, global!: JsGlobalObject): ?ContentOptions { return None }
public func eatContentArgs(global!: JsGlobalObject, callFrame!: JsCallFrame): ContentArgs { return ContentArgs() }

public class SystemError {
    public var code: String = ""
    public var message: String = ""
    public init() {}
}

public class ContentArgs {
    public var content: String = ""
    public var options: ?ContentOptions = None
    public init() {}
}

public class ContentOptions {
    public var html: Bool = false
    public init() {}
    public init(html: Bool) { this.html = html }
}

public class LOLHTMLContext { public init() {} }

public class HTMLRewriter {
    public init() {}
    public static func constructor(global!: JsGlobalObject, callFrame!: JsCallFrame): HTMLRewriter { return HTMLRewriter() }
    public func on_(global!: JsGlobalObject, selectorName!: String, listener!: JsValue, callFrame!: JsCallFrame): JsValue { return JsValue.jsUndefined() }
    public func on(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue { return JsValue.jsUndefined() }
    public func onDocument_(global!: JsGlobalObject, listener!: JsValue, callFrame!: JsCallFrame): JsValue { return JsValue.jsUndefined() }
    public func onDocument(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue { return JsValue.jsUndefined() }
    public func transform(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue { return JsValue.jsUndefined() }
    public func finalize(): Unit {}
}

public enum ResponseKind { | unknown }
public class SelectorGuard { public init() {} }
public class HTMLRewriterBuilder { public init() {}; public static func destroy(builder!: HTMLRewriterBuilder): Unit {} }
public class HTMLSelector { public init() {}; public static func parse(selector!: String): ?HTMLSelector { return Some(HTMLSelector()) }; public static func destroy(selector!: HTMLSelector): Unit {} }
public class HTMLRewriterLoader { public init() {}; public func deinit(): Unit {} }
public class BufferOutputSink { public init() {} }
public enum BufferOutputSinkSync { | SinkNone }

public class DocumentHandler {
    public var onDocTypeCallback: ?JsValue = None
    public init() {}
    public init(global: JsGlobalObject, thisObject: JsValue) {}
    public static func `init`(global!: JsGlobalObject, thisObject!: JsValue): ?DocumentHandler { return Some(DocumentHandler()) }
    public static func onDocType(`this`: DocumentHandler, value!: Any): Bool { return true }
    public static func onComment(`this`: DocumentHandler, value!: Any): Bool { return true }
    public static func onText(`this`: DocumentHandler, value!: Any): Bool { return true }
    public static func onEnd(`this`: DocumentHandler, value!: Any): Bool { return true }
    public func deinit(): Unit {}
}

public class ElementHandler {
    public init() {}
    public init(global: JsGlobalObject, thisObject: JsValue) {}
    public static func `init`(global!: JsGlobalObject, thisObject!: JsValue): ?ElementHandler { return Some(ElementHandler()) }
    public static func onElement(`this`: ElementHandler, value!: Any): Bool { return true }
    public static func onComment(`this`: ElementHandler, value!: Any): Bool { return true }
    public static func onText(`this`: ElementHandler, value!: Any): Bool { return true }
    public func deinit(): Unit {}
}

public class TextChunk {
    public init() {}
    public static func `init`(textChunk!: Any): TextChunk { return TextChunk() }
    public func before(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue { return JsValue.jsUndefined() }
    public func after(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue { return JsValue.jsUndefined() }
    public func replace(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue { return JsValue.jsUndefined() }
    public func remove(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue { return JsValue.jsUndefined() }
    public func getText(globalObject!: JsGlobalObject): JsValue { return JsValue.jsString("") }
    public func removed(globalObject!: JsGlobalObject): JsValue { return JsValue.jsBoolean(false) }
    public func finalize(): Unit {}
}

public class DocType {
    public init() {}
    public static func `init`(doctype!: Any): DocType { return DocType() }
    public func getName(globalObject!: JsGlobalObject): JsValue { return JsValue.jsString("") }
    public func getPublicId(globalObject!: JsGlobalObject): JsValue { return JsValue.jsString("") }
    public func getSystemId(globalObject!: JsGlobalObject): JsValue { return JsValue.jsString("") }
    public func remove(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue { return JsValue.jsUndefined() }
    public func removed(globalObject!: JsGlobalObject): JsValue { return JsValue.jsBoolean(false) }
    public func finalize(): Unit {}
}

public class DocEnd {
    public init() {}
    public static func `init`(docEnd!: Any): DocEnd { return DocEnd() }
    public func append(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue { return JsValue.jsUndefined() }
    public func finalize(): Unit {}
}

public class HTMLComment {
    public init() {}
    public static func `init`(comment!: Any): HTMLComment { return HTMLComment() }
    public func before(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue { return JsValue.jsUndefined() }
    public func after(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue { return JsValue.jsUndefined() }
    public func replace(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue { return JsValue.jsUndefined() }
    public func remove(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue { return JsValue.jsUndefined() }
    public func getText(globalObject!: JsGlobalObject): JsValue { return JsValue.jsString("") }
    public func setText(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue { return JsValue.jsUndefined() }
    public func removed(globalObject!: JsGlobalObject): JsValue { return JsValue.jsBoolean(false) }
    public func finalize(): Unit {}
}

public class EndTag {
    public init() {}
    public static func `init`(endTag!: Any): EndTag { return EndTag() }
    public func before(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue { return JsValue.jsUndefined() }
    public func after(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue { return JsValue.jsUndefined() }
    public func remove(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue { return JsValue.jsUndefined() }
    public func getName(globalObject!: JsGlobalObject): JsValue { return JsValue.jsString("") }
    public func setName(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue { return JsValue.jsUndefined() }
    public func finalize(): Unit {}
}

public class EndTagHandler {
    public init() {}
    public init(callback: JsValue, global: JsGlobalObject) {}
    public static func onEndTag(`this`: EndTagHandler, value!: Any): Bool { return true }
    public func deinit(): Unit {}
}

public class AttributeIterator {
    public init() {}
    public static func `init`(iterator!: Any): AttributeIterator { return AttributeIterator() }
    public func next(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue { return JsValue.jsUndefined() }
    public func getThis(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue { return JsValue.jsUndefined() }
    public func finalize(): Unit {}
}

public class HTMLElement {
    public init() {}
    public static func `init`(element!: Any): HTMLElement { return HTMLElement() }
    public func detachAttributeIterators(): Unit {}
    public func before(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue { return JsValue.jsUndefined() }
    public func after(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue { return JsValue.jsUndefined() }
    public func replace(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue { return JsValue.jsUndefined() }
    public func prepend(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue { return JsValue.jsUndefined() }
    public func append(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue { return JsValue.jsUndefined() }
    public func setInnerContent(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue { return JsValue.jsUndefined() }
    public func remove(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue { return JsValue.jsUndefined() }
    public func removeAndKeepContent(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue { return JsValue.jsUndefined() }
    public func getTagName(globalObject!: JsGlobalObject): JsValue { return JsValue.jsString("") }
    public func setTagName(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue { return JsValue.jsUndefined() }
    public func getAttribute(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue { return JsValue.jsNull() }
    public func hasAttribute(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue { return JsValue.jsBoolean(false) }
    public func setAttribute(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue { return JsValue.jsUndefined() }
    public func removeAttribute(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue { return JsValue.jsUndefined() }
    public func getAttributes(globalObject!: JsGlobalObject): JsValue { return JsValue.jsUndefined() }
    public func onEndTag(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue { return JsValue.jsUndefined() }
    public func getRemoved(globalObject!: JsGlobalObject): JsValue { return JsValue.jsBoolean(false) }
    public func getSelfClosing(globalObject!: JsGlobalObject): JsValue { return JsValue.jsBoolean(false) }
    public func getCanHaveContent(globalObject!: JsGlobalObject): JsValue { return JsValue.jsBoolean(true) }
    public func getNamespaceURI(globalObject!: JsGlobalObject): JsValue { return JsValue.jsString("") }
    public func finalize(): Unit {}
}

public class HTMLText {
    public init() {}
    public static func `init`(textChunk!: Any): HTMLText { return HTMLText() }
}

public class MutableString { public init() {} }
public class LinearFifo { public init() {} }
public class UTF8Fallback { public init() {} }
public class ValueBufferer { public init() {} }
public class GlobalRef { public init() {} }
public class StreamSignal { public init() {} }
public class Body { public init() {} }
public class BodyValue { public init() {} }
public class InternalBlob { public init() {} }
public class AnyBlob { public init() {} }
public enum Lifetime { | temporary | owned }

public func handlerCallback(`this`: DocumentHandler, value!: Any, clearField!: (DocType) -> Unit, getCallback!: (DocumentHandler) -> ?JsValue): Bool { return true }
public func handlerCallbackElement(`this`: ElementHandler, value!: Any, clearField!: (HTMLElement) -> Unit, getCallback!: (ElementHandler) -> ?JsValue): Bool { return true }
public func handlerCallbackEndTag(`this`: EndTagHandler, value!: Any, clearField!: (EndTag) -> Unit, getCallback!: (EndTagHandler) -> ?JsValue): Bool { return true }
