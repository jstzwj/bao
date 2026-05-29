// 严格翻译自: src/runtime/api/html_rewriter.classes.ts
package bao_runtime.api

import bao_jsc.*

// ============================================================================
// html_rewriter.classes.ts 类绑定定义
// Bun: HTMLRewriter, TextChunk, DocType, DocEnd, Comment, EndTag,
//      AttributeIterator, Element 的 JSC 绑定
// ============================================================================

// ============================================================================
// HTMLRewriter - HTML 重写器
// 严格翻译自: define({ name: "HTMLRewriter", sharedThis: true, construct: true, finalize: true })
// configurable: false
// ============================================================================

/// HTMLRewriter JSC 绑定
public class HTMLRewriterClasses {

    /// on fn
    /// 严格翻译自: proto.on { fn: "on", length: 2 }
    /// 参数: (selector: string, handlers: ElementHandlers)
    public static func on(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// onDocument fn
    /// 严格翻译自: proto.onDocument { fn: "onDocument", length: 1 }
    /// 参数: (handlers: DocumentHandlers)
    public static func onDocument(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// transform fn
    /// 严格翻译自: proto.transform { fn: "transform", length: 1 }
    /// 参数: (input: Response | ReadableStream)
    /// 返回: Response | ReadableStream
    public static func transform(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        return JsValue.jsUndefined()
    }
}

// ============================================================================
// TextChunk - 文本块
// 严格翻译自: define({ name: "TextChunk", sharedThis: true, noConstructor: true })
// ============================================================================

/// TextChunk JSC 绑定
public class TextChunkClasses {

    /// before fn
    /// 严格翻译自: proto.before { fn: "before", length: 1 }
    public static func before(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// after fn
    /// 严格翻译自: proto.after { fn: "after", length: 1 }
    public static func after(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// replace fn
    /// 严格翻译自: proto.replace { fn: "replace", length: 1 }
    public static func replace(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// remove fn
    /// 严格翻译自: proto.remove { fn: "remove", length: 0 }
    public static func remove(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// removed getter
    /// 严格翻译自: proto.removed { getter: "removed" }
    public static func getRemoved(jsGlobalObject!: JsGlobalObject, thisValue!: JsValue): JsValue {
        return JsValue.jsBoolean(false)
    }

    /// lastInTextNode getter (cached)
    /// 严格翻译自: proto.lastInTextNode { getter: "lastInTextNode", cache: true }
    public static func getLastInTextNode(jsGlobalObject!: JsGlobalObject, thisValue!: JsValue): JsValue {
        return JsValue.jsBoolean(false)
    }

    /// text getter
    /// 严格翻译自: proto.text { getter: "getText" }
    public static func getText(jsGlobalObject!: JsGlobalObject, thisValue!: JsValue): JsValue {
        return JsValue.jsString("")
    }
}

// ============================================================================
// DocType - 文档类型
// 严格翻译自: define({ name: "DocType", sharedThis: true, noConstructor: true })
// ============================================================================

/// DocType JSC 绑定
public class DocTypeClasses {

    /// name getter (cached)
    /// 严格翻译自: proto.name { getter: "name", cache: true }
    public static func getName(jsGlobalObject!: JsGlobalObject, thisValue!: JsValue): JsValue {
        return JsValue.jsString("")
    }

    /// systemId getter (cached)
    /// 严格翻译自: proto.systemId { getter: "systemId", cache: true }
    public static func getSystemId(jsGlobalObject!: JsGlobalObject, thisValue!: JsValue): JsValue {
        return JsValue.jsString("")
    }

    /// publicId getter (cached)
    /// 严格翻译自: proto.publicId { getter: "publicId", cache: true }
    public static func getPublicId(jsGlobalObject!: JsGlobalObject, thisValue!: JsValue): JsValue {
        return JsValue.jsString("")
    }

    /// remove fn
    /// 严格翻译自: proto.remove { fn: "remove", length: 0 }
    public static func remove(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// removed getter
    /// 严格翻译自: proto.removed { getter: "removed" }
    public static func getRemoved(jsGlobalObject!: JsGlobalObject, thisValue!: JsValue): JsValue {
        return JsValue.jsBoolean(false)
    }
}

// ============================================================================
// DocEnd - 文档结尾
// 严格翻译自: define({ name: "DocEnd", sharedThis: true, noConstructor: true })
// ============================================================================

/// DocEnd JSC 绑定
public class DocEndClasses {

    /// append fn
    /// 严格翻译自: proto.append { fn: "append", length: 1 }
    public static func append(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        return JsValue.jsUndefined()
    }
}

// ============================================================================
// Comment - 注释节点
// 严格翻译自: define({ name: "Comment", sharedThis: true, noConstructor: true })
// ============================================================================

/// Comment JSC 绑定
public class CommentClasses {

    /// before fn
    /// 严格翻译自: proto.before { fn: "before", length: 1 }
    public static func before(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// after fn
    /// 严格翻译自: proto.after { fn: "after", length: 1 }
    public static func after(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// replace fn
    /// 严格翻译自: proto.replace { fn: "replace", length: 1 }
    public static func replace(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// remove fn
    /// 严格翻译自: proto.remove { fn: "remove", length: 0 }
    public static func remove(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// removed getter
    /// 严格翻译自: proto.removed { getter: "removed" }
    public static func getRemoved(jsGlobalObject!: JsGlobalObject, thisValue!: JsValue): JsValue {
        return JsValue.jsBoolean(false)
    }

    /// text getter/setter
    /// 严格翻译自: proto.text { getter: "getText", setter: "setText" }
    public static func getText(jsGlobalObject!: JsGlobalObject, thisValue!: JsValue): JsValue {
        return JsValue.jsString("")
    }

    /// setText setter
    public static func setText(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        return JsValue.jsUndefined()
    }
}

// ============================================================================
// EndTag - 结束标签
// 严格翻译自: define({ name: "EndTag", sharedThis: true, noConstructor: true })
// ============================================================================

/// EndTag JSC 绑定
public class EndTagClasses {

    /// before fn
    /// 严格翻译自: proto.before { fn: "before", length: 1 }
    public static func before(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// after fn
    /// 严格翻译自: proto.after { fn: "after", length: 1 }
    public static func after(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// remove fn
    /// 严格翻译自: proto.remove { fn: "remove", length: 0 }
    public static func remove(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// name getter/setter
    /// 严格翻译自: proto.name { getter: "getName", setter: "setName" }
    public static func getName(jsGlobalObject!: JsGlobalObject, thisValue!: JsValue): JsValue {
        return JsValue.jsString("")
    }

    /// setName setter
    public static func setName(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        return JsValue.jsUndefined()
    }
}

// ============================================================================
// AttributeIterator - 属性迭代器
// 严格翻译自: define({ name: "AttributeIterator", sharedThis: true, noConstructor: true })
// ============================================================================

/// AttributeIterator JSC 绑定
public class AttributeIteratorClasses {

    /// next fn
    /// 严格翻译自: proto.next { fn: "next", length: 0 }
    public static func next(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// @@iterator fn
    /// 严格翻译自: proto["@@iterator"] { fn: "getThis", length: 0 }
    public static func getThis(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        return thisValue
    }
}

// ============================================================================
// Element - HTML 元素
// 严格翻译自: define({ name: "Element", sharedThis: true, noConstructor: true })
// ============================================================================

/// Element JSC 绑定
public class ElementClasses {

    /// getAttribute fn
    /// 严格翻译自: proto.getAttribute { fn: "getAttribute", length: 1 }
    public static func getAttribute(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        return JsValue.jsNull()
    }

    /// hasAttribute fn
    /// 严格翻译自: proto.hasAttribute { fn: "hasAttribute", length: 1 }
    public static func hasAttribute(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        return JsValue.jsBoolean(false)
    }

    /// setAttribute fn
    /// 严格翻译自: proto.setAttribute { fn: "setAttribute", length: 2 }
    public static func setAttribute(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// removeAttribute fn
    /// 严格翻译自: proto.removeAttribute { fn: "removeAttribute", length: 1 }
    public static func removeAttribute(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// before fn
    /// 严格翻译自: proto.before { fn: "before", length: 1 }
    public static func before(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// after fn
    /// 严格翻译自: proto.after { fn: "after", length: 1 }
    public static func after(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// replace fn
    /// 严格翻译自: proto.replace { fn: "replace", length: 1 }
    public static func replace(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// prepend fn
    /// 严格翻译自: proto.prepend { fn: "prepend", length: 1 }
    public static func prepend(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// append fn
    /// 严格翻译自: proto.append { fn: "append", length: 1 }
    public static func append(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// setInnerContent fn
    /// 严格翻译自: proto.setInnerContent { fn: "setInnerContent", length: 1 }
    public static func setInnerContent(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// remove fn
    /// 严格翻译自: proto.remove { fn: "remove", length: 0 }
    public static func remove(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// removeAndKeepContent fn
    /// 严格翻译自: proto.removeAndKeepContent { fn: "removeAndKeepContent", length: 0 }
    public static func removeAndKeepContent(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// onEndTag fn
    /// 严格翻译自: proto.onEndTag { fn: "onEndTag", length: 1 }
    public static func onEndTag(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// tagName getter/setter
    /// 严格翻译自: proto.tagName { getter: "getTagName", setter: "setTagName" }
    public static func getTagName(jsGlobalObject!: JsGlobalObject, thisValue!: JsValue): JsValue {
        return JsValue.jsString("")
    }

    /// setTagName setter
    public static func setTagName(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// removed getter
    /// 严格翻译自: proto.removed { getter: "getRemoved" }
    public static func getRemoved(jsGlobalObject!: JsGlobalObject, thisValue!: JsValue): JsValue {
        return JsValue.jsBoolean(false)
    }

    /// selfClosing getter
    /// 严格翻译自: proto.selfClosing { getter: "getSelfClosing" }
    public static func getSelfClosing(jsGlobalObject!: JsGlobalObject, thisValue!: JsValue): JsValue {
        return JsValue.jsBoolean(false)
    }

    /// canHaveContent getter
    /// 严格翻译自: proto.canHaveContent { getter: "getCanHaveContent" }
    public static func getCanHaveContent(jsGlobalObject!: JsGlobalObject, thisValue!: JsValue): JsValue {
        return JsValue.jsBoolean(true)
    }

    /// namespaceURI getter (cached)
    /// 严格翻译自: proto.namespaceURI { getter: "getNamespaceURI", cache: true }
    public static func getNamespaceURI(jsGlobalObject!: JsGlobalObject, thisValue!: JsValue): JsValue {
        return JsValue.jsString("")
    }

    /// attributes getter
    /// 严格翻译自: proto.attributes { getter: "getAttributes" }
    public static func getAttributes(jsGlobalObject!: JsGlobalObject, thisValue!: JsValue): JsValue {
        // 返回 AttributeIterator
        return JsValue.jsUndefined()
    }
}
