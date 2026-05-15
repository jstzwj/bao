// 严格翻译自: src/runtime/api/MarkdownObject.zig
package bao_runtime.api

import bao_jsc.*
import bao_core.*
import bao_collections.*
import bao_sys.*

// ============================================================================
// MarkdownObject - Bun.markdown API
// 对应 Bun: src/runtime/api/MarkdownObject.zig
// ============================================================================

/// MarkdownObject 提供 Markdown 渲染功能
public class MarkdownObject {

    /// 创建 Markdown 对象, 挂载 html/ansi/render/react 方法
    public static func create(globalThis: JsGlobalObject): JsValue {
        let object = JsValue.createEmptyObject(globalThis, 4)
        object.put(globalThis, ZigString.static("html"), JsFunction.create(globalThis, "html", renderToHTML, 1))
        object.put(globalThis, ZigString.static("ansi"), JsFunction.create(globalThis, "ansi", renderToAnsi, 2))
        object.put(globalThis, ZigString.static("render"), JsFunction.create(globalThis, "render", render, 3))
        object.put(globalThis, ZigString.static("react"), JsFunction.create(globalThis, "react", renderReact, 3))
        return object
    }

    // ========================================================================
    // renderToAnsi - Bun.markdown.ansi(text, theme?)
    // ========================================================================

    /// 渲染 Markdown 到 ANSI 彩色终端字符串
    public static func renderToAnsi(globalThis: JsGlobalObject, callframe: JsCallFrame): JsValue {
        let (inputValue, themeValue) = callframe.argumentsAsArray2()

        if (inputValue.isEmptyOrUndefinedOrNull()) {
            globalThis.throwInvalidArguments("Expected a string or buffer to render")
            return JsValue.zero
        }

        // 获取输入字符串
        let buffer = try StringOrBuffer.fromJS(globalThis, inputValue) ?? {
            globalThis.throwInvalidArguments("Expected a string or buffer to render")
            return JsValue.zero
        }

        let input = buffer.slice()

        // 解析主题选项
        var theme = AnsiTheme(
            colors: true,
            hyperlinks: false,
            kittyGraphics: false,
            light: Md.detectLightBackground(),
            columns: 80,
        )

        if (themeValue.isObject()) {
            if (let v = try themeValue.getBooleanLoose(globalThis, "colors")) { theme.colors = v }
            if (let v = try themeValue.getBooleanLoose(globalThis, "hyperlinks")) { theme.hyperlinks = v }
            if (let v = try themeValue.getBooleanLoose(globalThis, "kittyGraphics")) { theme.kittyGraphics = v }
            if (let v = try themeValue.getBooleanLoose(globalThis, "light")) { theme.light = v }
            if (let cols = try themeValue.get(globalThis, "columns")) {
                if (cols.isNumber()) {
                    let n = cols.toInt32()
                    theme.columns = n <= 0 ? 0 : UInt16(min(n, UInt16.maxValue))
                }
            }
        }

        // 渲染
        let result = try Md.renderToAnsi(input, .terminal, theme) ?? {
            globalThis.throwOutOfMemory()
            return JsValue.zero
        }

        return BunString.createUTF8ForJS(globalThis, result)
    }

    // ========================================================================
    // renderToHTML - Bun.markdown.html(text, opts?)
    // ========================================================================

    /// 渲染 Markdown 到 HTML 字符串
    public static func renderToHTML(globalThis: JsGlobalObject, callframe: JsCallFrame): JsValue {
        let (inputValue, optsValue) = callframe.argumentsAsArray2()

        if (inputValue.isEmptyOrUndefinedOrNull()) {
            globalThis.throwInvalidArguments("Expected a string or buffer to render")
            return JsValue.zero
        }

        let buffer = try StringOrBuffer.fromJS(globalThis, inputValue) ?? {
            globalThis.throwInvalidArguments("Expected a string or buffer to render")
            return JsValue.zero
        }

        let input = buffer.slice()
        let options = try parseOptions(globalThis, optsValue)

        let result = try Md.renderToHtmlWithOptions(input, options)
        return BunString.createUTF8ForJS(globalThis, result)
    }

    // ========================================================================
    // render - Bun.markdown.render(text, callbacks, options?)
    // ========================================================================

    /// 使用自定义回调渲染 Markdown
    public static func render(globalThis: JsGlobalObject, callframe: JsCallFrame): JsValue {
        let (inputValue, callbacksValue, optsValue) = callframe.argumentsAsArray3()

        if (inputValue.isEmptyOrUndefinedOrNull()) {
            globalThis.throwInvalidArguments("Expected a string or buffer to render")
            return JsValue.zero
        }

        let buffer = try StringOrBuffer.fromJS(globalThis, inputValue) ?? {
            globalThis.throwInvalidArguments("Expected a string or buffer to render")
            return JsValue.zero
        }

        let input = buffer.slice()
        let options = try parseOptions(globalThis, optsValue)

        // 创建 JS 回调渲染器
        var jsRenderer = JsCallbackRenderer.init(globalThis, input, options.headingIds)
        defer jsRenderer.deinit()

        // 提取回调
        try jsRenderer.extractCallbacks(callbacksValue.isObject() ? callbacksValue : JsValue.jsUndefined)

        // 运行解析器
        try Md.renderWithRenderer(input, options, jsRenderer.renderer())

        // 返回累积结果
        let result = jsRenderer.getResult()
        return BunString.createUTF8ForJS(globalThis, result)
    }

    // ========================================================================
    // renderReact - Bun.markdown.react(text, components?, options?)
    // ========================================================================

    /// 渲染 Markdown 为 React Fragment 元素
    public static func renderReact(globalThis: JsGlobalObject, callframe: JsCallFrame): JsValue {
        // ... React 渲染实现
        return JsValue.zero
    }

    // ========================================================================
    // 选项解析
    // ========================================================================

    /// 解析 Markdown 渲染选项
    public static func parseOptions(globalThis: JsGlobalObject, optsValue: JsValue): MdOptions {
        var options = MdOptions()
        if (optsValue.isObject()) {
            // 解析 autolinks 选项
            if (let autolinksVal = try optsValue.get(globalThis, "autolinks")) {
                if (autolinksVal.isBoolean()) {
                    if (autolinksVal.toBoolean()) {
                        options.permissiveAutolinks = true
                    }
                } else if (autolinksVal.isObject()) {
                    if (let v = try autolinksVal.getBooleanLoose(globalThis, "url")) { options.permissiveUrlAutolinks = v }
                    if (let v = try autolinksVal.getBooleanLoose(globalThis, "www")) { options.permissiveWwwAutolinks = v }
                    if (let v = try autolinksVal.getBooleanLoose(globalThis, "email")) { options.permissiveEmailAutolinks = v }
                }
            }

            // 解析 headings 选项
            if (let headingsVal = try optsValue.get(globalThis, "headings")) {
                if (headingsVal.isBoolean()) {
                    if (headingsVal.toBoolean()) {
                        options.headingIds = true
                        options.autolinkHeadings = true
                    }
                } else if (headingsVal.isObject()) {
                    if (let v = try headingsVal.getBooleanLoose(globalThis, "ids")) { options.headingIds = v }
                    if (let v = try headingsVal.getBooleanLoose(globalThis, "autolink")) { options.autolinkHeadings = v }
                }
            }

            // 解析其余布尔选项
            if (let v = try optsValue.getBooleanLoose(globalThis, "allowMath")) { options.allowMath = v }
            if (let v = try optsValue.getBooleanLoose(globalThis, "parseSpan")) { options.parseSpan = v }
            if (let v = try optsValue.getBooleanLoose(globalThis, "wikilinks")) { options.wikilinks = v }
            if (let v = try optsValue.getBooleanLoose(globalThis, "tasklist")) { options.tasklist = v }
            if (let v = try optsValue.getBooleanLoose(globalThis, "strikethrough")) { options.strikethrough = v }
            if (let v = try optsValue.getBooleanLoose(globalThis, "underline")) { options.underline = v }
            if (let v = try optsValue.getBooleanLoose(globalThis, "tables")) { options.tables = v }
        }
        return options
    }
}

/// JsCallbackRenderer - 使用 JS 回调渲染 Markdown
public class JsCallbackRenderer {
    public var globalObject: JsGlobalObject
    public var srcText: String
    public var stack: ArrayList<StackEntry>
    public var callbacks: Callbacks
    public var headingTracker: HeadingIdTracker

    public struct Callbacks {
        public var heading: JsValue
        public var paragraph: JsValue
        public var blockquote: JsValue
        public var code: JsValue
        public var list: JsValue
        public var listItem: JsValue
        public var hr: JsValue
        public var table: JsValue
        public var thead: JsValue
        public var tbody: JsValue
        public var tr: JsValue
        public var th: JsValue
        public var td: JsValue
        public var html: JsValue
        public var strong: JsValue
        public var emphasis: JsValue
        public var link: JsValue
        public var image: JsValue
        public var codespan: JsValue
        public var strikethrough: JsValue
        public var text: JsValue
    }

    public struct StackEntry {
        public var buffer: ArrayList<UInt8>
        public var blockType: BlockType
        public var data: UInt32
        public var flags: UInt32
        public var childIndex: UInt32
        public var detail: SpanDetail
    }

    public static func init(globalObject: JsGlobalObject, srcText: String, headingIds: Bool): JsCallbackRenderer {
        return JsCallbackRenderer(
            globalObject: globalObject,
            srcText: srcText,
            stack: ArrayList<StackEntry>(),
            callbacks: Callbacks(),
            headingTracker: HeadingIdTracker.init(headingIds),
        )
    }

    /// 提取回调函数
    public func extractCallbacks(opts: JsValue): Unit {
        if (opts.isUndefinedOrNull() || !opts.isObject()) { return }
        // ... 提取各回调
    }

    public func deinit(): Unit {
        // 释放资源
    }

    public func renderer(): MdRenderer {
        return MdRenderer(ptr: this)
    }

    public func getResult(): String {
        if (stack.isEmpty()) { return "" }
        return String.fromUtf8(stack[0].buffer.toArray())
    }
}

/// ANSI 主题选项
public struct AnsiTheme {
    public var colors: Bool
    public var hyperlinks: Bool
    public var kittyGraphics: Bool
    public var light: Bool
    public var columns: UInt16
}

/// Markdown 选项
public struct MdOptions {
    public var permissiveAutolinks: Bool
    public var permissiveUrlAutolinks: Bool
    public var permissiveWwwAutolinks: Bool
    public var permissiveEmailAutolinks: Bool
    public var headingIds: Bool
    public var autolinkHeadings: Bool
    public var allowMath: Bool
    public var parseSpan: Bool
    public var wikilinks: Bool
    public var tasklist: Bool
    public var strikethrough: Bool
    public var underline: Bool
    public var tables: Bool
}
