// 翻译自 Bun: src/runtime/bake/client/css-reloader.ts
// CSS 热重载运行时。框架负责 <link> 管理，Bake 通过可替换 CSSStyleSheet 与 DOM 观察器保持样式同步。

package bao_runtime.bake.client

import bao_collections.*

// 浏览器 DOM 类型存根
public class CSSStyleSheet {
    public var disabled: Bool = false
    public init() {}
    public func replace(content: String): Unit {}
}

public class HTMLLinkElement {
    public var href: String = ""
    public var sheet: ?CSSStyleSheet = None
    public var tagName: String = ""
    public var rel: String = ""
    public var disabled: Bool = false
    public init() {}
}

public class Document {
    public var head: HTMLLinkElement = HTMLLinkElement()
    public var adoptedStyleSheets: ArrayList<CSSStyleSheet> = ArrayList<CSSStyleSheet>()
    public func querySelectorAll(selector: String): ArrayList<HTMLLinkElement> { ArrayList<HTMLLinkElement>() }
}

public class MutationObserverInit {
    public var childList: Bool = false
    public var subtree: Bool = false
    public var attributes: Bool = false
    public var attributeFilter: Array<String> = []
    public init(childList: Bool, subtree: Bool, attributes: Bool, attributeFilter: Array<String>) {
        this.childList = childList
        this.subtree = subtree
        this.attributes = attributes
        this.attributeFilter = attributeFilter
    }
}

public class MutationRecord {
    public var `type`: String = ""
    public var removedNodes: ArrayList<HTMLLinkElement> = ArrayList<HTMLLinkElement>()
    public var addedNodes: ArrayList<HTMLLinkElement> = ArrayList<HTMLLinkElement>()
    public var target: HTMLLinkElement = HTMLLinkElement()
}

public class MutationObserver {
    public init(callback: (ArrayList<MutationRecord>) -> Unit) {}
    public func observe(target: HTMLLinkElement, options: MutationObserverInit): Unit {}
}

public class CSS {
    public var sheet: ?CSSStyleSheet
    public var link: ?HTMLLinkElement
    public var active: Bool

    public init(sheet: ?CSSStyleSheet, link: ?HTMLLinkElement, active: Bool) {
        this.sheet = sheet
        this.link = link
        this.active = active
    }
}

var cssStore: HashMap<String, CSS> = HashMap<String, CSS>()
var registeredLinkTags: HashMap<String, String> = HashMap<String, String>()

func validateCssId(id: String): Unit {
    if (id.size != 16) {
        throw Exception("Invalid CSS id: ${id}")
    }
}

func deactivateCss(css: CSS): Unit {
    if (css.active) {
        css.active = false
        if (css.sheet.isSome()) {
            css.sheet.getOrThrow().disabled = true
        } else if (css.link.isSome()) {
            let link = css.link.getOrThrow()
            if (link.sheet.isSome()) { link.sheet.getOrThrow().disabled = true }
        }
    }
}

func activateCss(css: CSS): Unit {
    if (!css.active) {
        css.active = true
        if (css.sheet.isSome()) {
            css.sheet.getOrThrow().disabled = false
        } else if (css.link.isSome()) {
            let link = css.link.getOrThrow()
            if (link.sheet.isSome()) { link.sheet.getOrThrow().disabled = false }
        }
    }
}

func maybeAddCssLink(link: HTMLLinkElement): Unit {
    let pathname = link.href
    if (pathname.startsWith("/_bun/asset/")) {
        let startIdx = "/_bun/asset/".size
        let id = if (pathname.size >= startIdx + 16) { pathname[startIdx..startIdx + 16] } else { "" }
        if (id.size != 16) { return }
        if (cssStore.contains(id)) {
            let existing = cssStore.get(id).getOrThrow()
            if (existing.sheet.isSome()) {
                existing.sheet.getOrThrow().disabled = false
                if (link.sheet.isSome()) { link.sheet.getOrThrow().disabled = true }
            }
            existing.link = Some(link)
        } else {
            cssStore.put(id, CSS(None, Some(link), true))
        }
        registeredLinkTags.put(link.href, id)
    }
}

/// 初始化 head 观察器；对应源文件顶层 MutationObserver 与 querySelectorAll 调用。
public func initCssReloader(document: Document): MutationObserver {
    let headObserver = MutationObserver({ list =>
        for (mutation in list) {
            if (mutation.`type` == "childList") {
                for (node in mutation.removedNodes) {
                    if (registeredLinkTags.contains(node.href)) {
                        let id = registeredLinkTags.get(node.href).getOrThrow()
                        if (cssStore.contains(id)) { deactivateCss(cssStore.get(id).getOrThrow()) }
                        registeredLinkTags.remove(node.href)
                    }
                }
                for (node in mutation.addedNodes) {
                    maybeAddCssLink(node)
                }
            } else if (mutation.`type` == "attributes") {
                let target = mutation.target
                if (target.tagName == "LINK" && target.rel == "stylesheet") {
                    if (registeredLinkTags.contains(target.href)) {
                        let id = registeredLinkTags.get(target.href).getOrThrow()
                        if (cssStore.contains(id)) {
                            let existing = cssStore.get(id).getOrThrow()
                            if (target.disabled) { deactivateCss(existing) } else { activateCss(existing) }
                        }
                    }
                }
            }
        }
    })
    headObserver.observe(document.head, MutationObserverInit(true, true, true, ["disabled"]))
    return headObserver
}

public func editCssArray(array: Array<String>): Unit {
    var removedCssKeys = ArrayList<String>()
    for (k in cssStore.keys()) { removedCssKeys.append(k) }
    for (css in array) {
        var newKeys = ArrayList<String>()
        for (k in removedCssKeys) { if (k != css) { newKeys.append(k) } }
        removedCssKeys = newKeys
        if (cssStore.contains(css)) {
            activateCss(cssStore.get(css).getOrThrow())
        } else {
            cssStore.put(css, CSS(None, None, true))
        }
    }
    for (i in 0..removedCssKeys.size) {
        let css = removedCssKeys[i]
        if (cssStore.contains(css)) { deactivateCss(cssStore.get(css).getOrThrow()) }
    }
}

public func editCssContent(id: String, newContent: String): Bool {
    if (!cssStore.contains(id)) { return false }
    let entry = cssStore.get(id).getOrThrow()
    if (entry.sheet.isNone()) {
        let sheet = CSSStyleSheet()
        entry.sheet = Some(sheet)
        sheet.replace(newContent)
        return false
    }
    let sheet = entry.sheet.getOrThrow()
    sheet.replace(newContent)
    return !sheet.disabled
}
