// 翻译自 Bun: src/runtime/bake/client/css-reloader.ts
// CSS 热重载运行时。框架负责 <link> 管理，Bake 通过可替换 CSSStyleSheet 与 DOM 观察器保持样式同步。

package bao_runtime.bake.client

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

let cssStore: Map<String, CSS> = Map<String, CSS>()
let registeredLinkTags: Map<HTMLLinkElement, String> = Map<HTMLLinkElement, String>()

func validateCssId(id: String): Unit {
    if (!Regex("^[a-f0-9]{16}$").matches(id)) {
        throw Error("Invalid CSS id: ${id}")
    }
}

func deactivateCss(css: CSS): Unit {
    if (css.active) {
        css.active = false
        if (let Some(sheet) = css.sheet) {
            sheet.disabled = true
        } else if (let Some(link) = css.link) {
            if (let Some(linkSheet) = link.sheet) { linkSheet.disabled = true }
        }
    }
}

func activateCss(css: CSS): Unit {
    if (!css.active) {
        css.active = true
        if (let Some(sheet) = css.sheet) {
            sheet.disabled = false
        } else if (let Some(link) = css.link) {
            if (let Some(linkSheet) = link.sheet) { linkSheet.disabled = false }
        }
    }
}

func maybeAddCssLink(link: HTMLLinkElement): Unit {
    let pathname = URL(link.href).pathname
    if (pathname.startsWith("/_bun/asset/")) {
        let id = pathname.slice("/_bun/asset/".length).slice(0, 16)
        if (!Regex("^[a-f0-9]{16}$").matches(id)) { return }
        if (let Some(existing) = cssStore.get(id)) {
            if (let Some(sheet) = existing.sheet) {
                sheet.disabled = false
                if (let Some(linkSheet) = link.sheet) { linkSheet.disabled = true }
            }
            existing.link = Some(link)
        } else {
            cssStore.set(id, CSS(None, Some(link), true))
        }
        registeredLinkTags.set(link, id)
    }
}

/// 初始化 head 观察器；对应源文件顶层 MutationObserver 与 querySelectorAll 调用。
public func initCssReloader(document: Document): MutationObserver {
    let headObserver = MutationObserver({ (list) =>
        for (mutation in list) {
            if (mutation.type == "childList") {
                for (node in mutation.removedNodes) {
                    if (let Some(link) = node.asHTMLLinkElement()) {
                        if (let Some(id) = registeredLinkTags.get(link)) {
                            if (let Some(existingSheet) = cssStore.get(id)) { deactivateCss(existingSheet) }
                            registeredLinkTags.delete(link)
                        }
                    }
                }
                for (node in mutation.addedNodes) {
                    if (let Some(link) = node.asHTMLLinkElement()) { maybeAddCssLink(link) }
                }
            } else if (mutation.type == "attributes") {
                if (let Some(target) = mutation.target.asHTMLLinkElement()) {
                    if (target.tagName == "LINK" && target.rel == "stylesheet") {
                        if (let Some(id) = registeredLinkTags.get(target)) {
                            if (let Some(existing) = cssStore.get(id)) {
                                if (target.disabled) { deactivateCss(existing) } else { activateCss(existing) }
                            }
                        }
                    }
                }
            }
        }
    })
    headObserver.observe(document.head, MutationObserverInit(childList: true, subtree: true, attributes: true, attributeFilter: ["disabled"]))
    document.querySelectorAll("head>link[rel=stylesheet]").forEach({ (link) => maybeAddCssLink(link) })
    return headObserver
}

public func editCssArray(array: Array<String>): Unit {
    var removedCssKeys = Set<String>(cssStore.keys())
    for (css in array) {
        if (IS_BUN_DEVELOPMENT) { validateCssId(css) }
        if (let Some(existing) = cssStore.get(css)) {
            removedCssKeys.delete(css)
            activateCss(existing)
        } else {
            removedCssKeys.delete(css)
            cssStore.set(css, CSS(None, None, true))
        }
    }
    for (css in removedCssKeys) {
        if (let Some(entry) = cssStore.get(css)) { deactivateCss(entry) }
    }
}

public func editCssContent(id: String, newContent: String): Bool {
    let entry = cssStore.get(id) ?? return false
    if (entry.sheet.isNone()) {
        let sheet = CSSStyleSheet()
        entry.sheet = Some(sheet)
        sheet.replace(newContent)
        document.adoptedStyleSheets.push(sheet)
        if (let Some(link) = entry.link) {
            if (let Some(linkSheet) = link.sheet) { linkSheet.disabled = true }
        }
        return false
    }
    let sheet = entry.sheet.get()
    sheet.replace(newContent)
    return !sheet.disabled
}
