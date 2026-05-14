// JSX 转换器
// 严格翻译自: src/bundler/transpiler.zig 中 JSX 处理部分
// 以及 esbuild 的 JSX 转换实现
//
// Bun 支持三种 JSX 运行时:
//   1. Classic (React.createElement):
//      <div id="foo">Hello</div>
//      -> React.createElement("div", {id: "foo"}, "Hello")
//
//   2. Automatic (React 17+ jsx-runtime):
//      <div id="foo">Hello</div>
//      -> import {jsx as _jsx} from "react/jsx-runtime"
//         _jsx("div", {id: "foo", children: "Hello"}, undefined)
//
//   3. Solid (Solid.js):
//      <div id="foo">Hello</div>
//      -> import {createElement as _createElement} from "solid-js"
//         _createElement("div", {id: "foo"}, "Hello")
//
// 参考:
//   src/bundler/options.zig - JSX options (factory, fragment, runtime, import_source)
//   src/resolver/tsconfig_json.zig - TSConfig JSX 配置解析
package bao_transpiler

import bao_core.*
import bao_collections.*

// ============================================================================
// JSXTransformer - JSX 转换器
// 严格翻译自: esbuild/bun 的 JSX 转换管线
// ============================================================================

/// JSX 转换器 - 对应 Bun/esbuild 的 JSX 转换
public class JSXTransformer {
    private var source: String
    private var pos: Int64
    private var output: StringBuilder
    private var options: TranspilerOptions
    private var needsJsxImport: Bool
    private var needsJsxsImport: Bool
    private var needsFragmentImport: Bool
    private var generatedImports: StringSet

    public init(options: TranspilerOptions) {
        source = ""
        pos = 0
        output = StringBuilder()
        this.options = options
        needsJsxImport = false
        needsJsxsImport = false
        needsFragmentImport = false
        generatedImports = StringSet()
    }

    /// 转换 JSX - 主入口
    public func transform(source: String): String {
        this.source = source
        this.pos = 0
        this.output = StringBuilder()
        needsJsxImport = false
        needsJsxsImport = false
        needsFragmentImport = false

        // 第一遍: 收集 JSX 元素并转换
        var result = StringBuilder()
        while (pos < source.length) {
            if (source[Int64(pos)] == Char('<')) {
                // 检测 JSX 元素开始
                let nextPos = pos + 1
                if (nextPos < source.length) {
                    let nextCh = source[Int64(nextPos)]
                    // JSX 元素: <Identifier, <>, 或 </
                    if (isJSXElementStart(nextCh)) {
                        let jsxElem = parseJSXElement()
                        let jsCode = generateJSXCode(jsxElem)
                        result.append(jsCode)
                        continue
                    }
                }
            }
            result.append(source[Int64(pos)])
            pos += 1
        }

        // 生成运行时导入
        let imports = generateRuntimeImports()
        if (imports.length > 0) {
            return imports + "\n" + result.toString()
        }
        return result.toString()
    }

    /// 检测字符是否为 JSX 元素开始
    private func isJSXElementStart(ch: Char): Bool {
        let v = ch.value
        // 标识符开始, 或 Fragment <>
        return (v >= 97 && v <= 122) || (v >= 65 && v <= 90) ||
               v == 95 || v == 36 || v == 62  // '>' for <>
    }

    // ========================================================================
    // JSX 解析 - 解析 JSX 为 JSXElement 结构
    // ========================================================================

    /// 解析 JSX 元素
    private func parseJSXElement(): JSXElement {
        pos += 1  // skip '<'

        // Fragment: <>
        if (pos < source.length && source[Int64(pos)] == Char('>')) {
            pos += 1  // skip '>'
            let children = parseJSXChildren("</>")
            // skip closing </>
            if (pos + 2 < source.length &&
                source[Int64(pos)] == Char('<') &&
                source[Int64(pos + 1)] == Char('/')) {
                pos += 4  // skip "</>"
            }
            return JSXElement("<>", ArrayList<JSXAttribute>(), children, true)
        }

        // 自闭合标签
        let isClosing = pos < source.length && source[Int64(pos)] == Char('/')
        if (isClosing) {
            // 这是关闭标签，不应该在这里出现
            pos += 1
            let tagName = readJSXIdentifier()
            skipWhitespace()
            if (pos < source.length && source[Int64(pos)] == Char('>')) {
                pos += 1
            }
            return JSXElement(tagName, ArrayList<JSXAttribute>(), ArrayList<JSXChild>(), false)
        }

        // 读取标签名
        let tagName = readJSXIdentifier()
        skipWhitespace()

        // 读取属性
        let attrs = ArrayList<JSXAttribute>()
        var selfClosing = false

        while (pos < source.length) {
            let ch = source[Int64(pos)]
            if (ch == Char('>')) {
                pos += 1
                break
            }
            if (ch == Char('/') && pos + 1 < source.length && source[Int64(pos + 1)] == Char('>')) {
                pos += 2
                selfClosing = true
                break
            }
            if (ch == Char('{') || ch == Char('}')) {
                pos += 1
                continue
            }

            // 解析属性
            let attr = parseJSXAttribute()
            attrs.append(attr)
            skipWhitespace()
        }

        // 解析子元素
        let children = ArrayList<JSXChild>()
        if (!selfClosing) {
            let closeTag = "</${tagName}>"
            children.addAll(parseJSXChildren(closeTag))
        }

        return JSXElement(tagName, attrs, children, tagName == "<>")
    }

    /// 读取 JSX 标识符 (支持 member expression: Foo.Bar.Baz)
    private func readJSXIdentifier(): String {
        let sb = StringBuilder()
        while (pos < source.length) {
            let ch = source[Int64(pos)]
            let v = ch.value
            if ((v >= 97 && v <= 122) || (v >= 65 && v <= 90) ||
                v == 95 || v == 36 || (v >= 48 && v <= 57) || v == 46) {
                sb.append(ch)
                pos += 1
            } else {
                break
            }
        }
        return sb.toString()
    }

    /// 解析 JSX 属性
    private func parseJSXAttribute(): JSXAttribute {
        skipWhitespace()

        // 处理 spread 属性: {...obj}
        if (source[Int64(pos)] == Char('{')) {
            pos += 1  // skip '{'
            if (pos < source.length && source[Int64(pos)] == Char('.')) {
                pos += 3  // skip "..."
            }
            let value = readJSXExpressionValue()
            if (pos < source.length && source[Int64(pos)] == Char('}')) {
                pos += 1
            }
            return JSXAttribute("__spread__", value, true)
        }

        // 普通属性: name="value" 或 name={expr}
        let name = readJSXAttributeName()
        skipWhitespace()

        var value = ""
        var isExpression = false

        if (pos < source.length && source[Int64(pos)] == Char('=')) {
            pos += 1  // skip '='
            skipWhitespace()

            if (pos < source.length && source[Int64(pos)] == Char('"')) {
                // 字符串值: name="value"
                value = readJSXStringValue()
            } else if (pos < source.length && source[Int64(pos)] == Char('\'')) {
                value = readJSXSingleQuoteValue()
            } else if (pos < source.length && source[Int64(pos)] == Char('{')) {
                // 表达式值: name={expr}
                pos += 1  // skip '{'
                value = readJSXExpressionValue()
                if (pos < source.length && source[Int64(pos)] == Char('}')) {
                    pos += 1  // skip '}'
                }
                isExpression = true
            }
        } else {
            // 布尔属性: <input disabled />
            value = "true"
        }

        return JSXAttribute(name, value, isExpression)
    }

    /// 读取属性名 (支持 data-*, aria-*, on* 等)
    private func readJSXAttributeName(): String {
        let sb = StringBuilder()
        while (pos < source.length) {
            let ch = source[Int64(pos)]
            let v = ch.value
            if ((v >= 97 && v <= 122) || (v >= 65 && v <= 90) ||
                (v >= 48 && v <= 57) || v == 45 || v == 95 ||
                v == 58 || v == 46) {
                sb.append(ch)
                pos += 1
            } else {
                break
            }
        }
        return sb.toString()
    }

    /// 读取字符串值 (双引号)
    private func readJSXStringValue(): String {
        pos += 1  // skip opening "
        let sb = StringBuilder()
        while (pos < source.length && source[Int64(pos)] != Char('"')) {
            let ch = source[Int64(pos)]
            if (ch == Char('\\') && pos + 1 < source.length) {
                sb.append(ch)
                pos += 1
                sb.append(source[Int64(pos)])
                pos += 1
            } else {
                sb.append(ch)
                pos += 1
            }
        }
        if (pos < source.length) {
            pos += 1  // skip closing "
        }
        return sb.toString()
    }

    /// 读取字符串值 (单引号)
    private func readJSXSingleQuoteValue(): String {
        pos += 1  // skip opening '
        let sb = StringBuilder()
        while (pos < source.length && source[Int64(pos)] != Char('\'')) {
            let ch = source[Int64(pos)]
            if (ch == Char('\\') && pos + 1 < source.length) {
                sb.append(ch)
                pos += 1
                sb.append(source[Int64(pos)])
                pos += 1
            } else {
                sb.append(ch)
                pos += 1
            }
        }
        if (pos < source.length) {
            pos += 1  // skip closing '
        }
        return sb.toString()
    }

    /// 读取 JSX 表达式值
    private func readJSXExpressionValue(): String {
        let sb = StringBuilder()
        var depth = 0
        while (pos < source.length) {
            let ch = source[Int64(pos)]
            if (ch == Char('{')) { depth += 1 }
            else if (ch == Char('}')) {
                if (depth == 0) { break }
                depth -= 1
            }
            sb.append(ch)
            pos += 1
        }
        return sb.toString().trim()
    }

    /// 解析 JSX 子元素
    private func parseJSXChildren(closeTag: String): ArrayList<JSXChild> {
        let children = ArrayList<JSXChild>()
        let textBuffer = StringBuilder()

        while (pos < source.length) {
            // 检查关闭标签
            if (startsWithAt(source, pos, closeTag)) {
                pos += closeTag.length
                break
            }

            // 检查嵌套 JSX 元素
            if (source[Int64(pos)] == Char('<')) {
                // 刷新文本缓冲
                if (textBuffer.length > 0) {
                    let text = textBuffer.toString().trim()
                    if (text.length > 0) {
                        children.append(JSXChild.textChild(text))
                    }
                    textBuffer.clearBuffer()
                }

                let child = parseJSXElement()
                children.append(JSXChild.elementChild(child))
                continue
            }

            // JSX 表达式子元素: {expression}
            if (source[Int64(pos)] == Char('{')) {
                // 刷新文本缓冲
                if (textBuffer.length > 0) {
                    let text = textBuffer.toString().trim()
                    if (text.length > 0) {
                        children.append(JSXChild.textChild(text))
                    }
                    textBuffer.clearBuffer()
                }

                pos += 1  // skip '{'
                let expr = readJSXExpressionValue()
                if (pos < source.length && source[Int64(pos)] == Char('}')) {
                    pos += 1
                }
                children.append(JSXChild.expressionChild(expr))
                continue
            }

            // 文本内容
            textBuffer.append(source[Int64(pos)])
            pos += 1
        }

        // 刷新剩余文本
        if (textBuffer.length > 0) {
            let text = textBuffer.toString().trim()
            if (text.length > 0) {
                children.append(JSXChild.textChild(text))
            }
        }

        return children
    }

    // ========================================================================
    // JSX 代码生成 - 根据运行时模式生成不同代码
    // ========================================================================

    /// 根据 JSX 元素生成 JavaScript 代码
    private func generateJSXCode(elem: JSXElement): String {
        match (options.jsxRuntime) {
            case Classic => generateClassicCode(elem)
            case Automatic => generateAutomaticCode(elem)
            case Solid => generateSolidCode(elem)
        }
    }

    /// Classic 运行时: React.createElement(type, props, ...children)
    /// 对应 Bun options.jsx.runtime = .classic
    /// React.createElement(type, props, ...children)
    private func generateClassicCode(elem: JSXElement): String {
        let sb = StringBuilder()
        let factory = options.jsxFactory
        let fragment = options.jsxFragment

        // 确定类型参数
        let typeArg = if (elem.isFragment) {
            fragment
        } else if (isUserComponent(elem.tagName)) {
            elem.tagName
        } else {
            "\"${elem.tagName}\""
        }

        sb.append("${factory}(${typeArg}, ")

        // 生成 props
        sb.append(generatePropsObject(elem))

        // 生成 children 作为额外参数
        for (child in elem.children) {
            sb.append(", ")
            sb.append(generateChildCode(child, JSXRuntime.Classic))
        }

        sb.append(")")
        return sb.toString()
    }

    /// Automatic 运行时: jsx(type, props, key) / jsxs(type, props, key)
    /// 对应 Bun options.jsx.runtime = .automatic
    /// 使用 react/jsx-runtime 或 react/jsx-dev-runtime
    private func generateAutomaticCode(elem: JSXElement): String {
        let sb = StringBuilder()
        let hasStaticChildren = hasOnlyStaticChildren(elem)

        // 使用 jsx (动态子元素) 或 jsxs (静态子元素)
        let funcName = if (hasStaticChildren) { "_jsxs" } else { "_jsx" }
        if (hasStaticChildren) {
            needsJsxsImport = true
        } else {
            needsJsxImport = true
        }

        // 确定类型参数
        let typeArg = if (elem.isFragment) {
            needsFragmentImport = true
            "_Fragment"
        } else if (isUserComponent(elem.tagName)) {
            elem.tagName
        } else {
            "\"${elem.tagName}\""
        }

        sb.append("${funcName}(${typeArg}, ")

        // 生成 props (包含 children)
        sb.append(generateAutomaticProps(elem))

        // key 参数 (简化: 总是 undefined)
        sb.append(", undefined)")

        return sb.toString()
    }

    /// Solid 运行时: 模板编译模式
    /// 对应 Bun options.jsx.runtime = .solid
    private func generateSolidCode(elem: JSXElement): String {
        let sb = StringBuilder()
        sb.append("_createElement(")

        // 类型
        let typeArg = if (elem.isFragment) {
            "\"\""
        } else if (isUserComponent(elem.tagName)) {
            elem.tagName
        } else {
            "\"${elem.tagName}\""
        }
        sb.append(typeArg)

        // Props
        sb.append(", ")
        if (elem.attrs.size == 0 && elem.children.size == 0) {
            sb.append("null")
        } else {
            sb.append(generatePropsObject(elem))
        }

        // Children 作为额外参数
        for (child in elem.children) {
            sb.append(", ")
            sb.append(generateChildCode(child, JSXRuntime.Solid))
        }

        sb.append(")")
        return sb.toString()
    }

    /// 生成 props 对象 (Classic/Solid 模式)
    private func generatePropsObject(elem: JSXElement): String {
        let sb = StringBuilder()
        sb.append("{")

        var first = true
        for (attr in elem.attrs) {
            if (!first) {
                sb.append(", ")
            }
            first = false

            if (attr.isSpread) {
                sb.append("...${attr.value}")
            } else {
                // 处理属性名中的特殊字符
                let propName = normalizePropName(attr.name)
                if (attr.isExpression) {
                    sb.append("${propName}: ${attr.value}")
                } else {
                    sb.append("${propName}: \"${escapeString(attr.value)}\"")
                }
            }
        }

        sb.append("}")
        return sb.toString()
    }

    /// 生成 Automatic 模式的 props 对象 (包含 children)
    private func generateAutomaticProps(elem: JSXElement): String {
        let sb = StringBuilder()
        sb.append("{")

        var first = true
        for (attr in elem.attrs) {
            if (!first) {
                sb.append(", ")
            }
            first = false

            if (attr.isSpread) {
                sb.append("...${attr.value}")
            } else {
                let propName = normalizePropName(attr.name)
                if (attr.isExpression) {
                    sb.append("${propName}: ${attr.value}")
                } else {
                    sb.append("${propName}: \"${escapeString(attr.value)}\"")
                }
            }
        }

        // 添加 children 到 props
        if (elem.children.size > 0) {
            if (!first) {
                sb.append(", ")
            }
            sb.append("children: ")
            if (elem.children.size == 1) {
                sb.append(generateChildCode(elem.children[0], JSXRuntime.Automatic))
            } else {
                sb.append("[")
                for (i in 0..elem.children.size) {
                    if (i > 0) { sb.append(", ") }
                    sb.append(generateChildCode(elem.children[Int64(i)], JSXRuntime.Automatic))
                }
                sb.append("]")
            }
        }

        sb.append("}")
        return sb.toString()
    }

    /// 生成子元素代码
    private func generateChildCode(child: JSXChild, runtime: JSXRuntime): String {
        match (child.kind) {
            case JSXChildKind.Text => "\"${escapeString(child.textValue)}\""
            case JSXChildKind.Expression => child.textValue
            case JSXChildKind.Element => generateJSXCode(child.elementValue)
        }
    }

    /// 检查是否只有静态子元素
    private func hasOnlyStaticChildren(elem: JSXElement): Bool {
        // 如果子元素中没有表达式，就是静态的
        for (child in elem.children) {
            if (child.kind == JSXChildKind.Expression) {
                return false
            }
            if (child.kind == JSXChildKind.Element) {
                if (!hasOnlyStaticChildren(child.elementValue)) {
                    return false
                }
            }
        }
        return true
    }

    /// 是否是用户自定义组件 (大写开头)
    private func isUserComponent(tagName: String): Bool {
        if (tagName.length == 0) { return false }
        let first = tagName[Int64(0)].value
        return first >= 65 && first <= 90  // A-Z
    }

    // ========================================================================
    // 运行时导入生成
    // ========================================================================

    /// 生成运行时导入语句
    private func generateRuntimeImports(): String {
        let sb = StringBuilder()

        match (options.jsxRuntime) {
            case Classic => {
                // Classic 模式不需要自动导入
                // React 通常由用户手动导入
            }
            case Automatic => {
                // Automatic 模式: 从 jsx-runtime 导入
                let importSource = options.jsxImportSource
                let devSuffix = if (options.jsxDevelopment) { "/jsx-dev-runtime" } else { "/jsx-runtime" }
                let runtimePath = "${importSource}${devSuffix}"

                var imports = ArrayList<String>()
                if (needsJsxImport) {
                    imports.append("import { jsx as _jsx } from \"${runtimePath}\"")
                }
                if (needsJsxsImport) {
                    if (needsJsxImport) {
                        // 合并导入
                        imports.clear()
                        imports.append("import { jsx as _jsx, jsxs as _jsxs } from \"${runtimePath}\"")
                    } else {
                        imports.append("import { jsxs as _jsxs } from \"${runtimePath}\"")
                    }
                }
                if (needsFragmentImport) {
                    // Fragment 需要从 React 导入
                    if (!imports.contains("import { Fragment as _Fragment } from \"${importSource}\"")) {
                        imports.append("import { Fragment as _Fragment } from \"${importSource}\"")
                    }
                }

                for (i in 0..imports.size) {
                    if (i > 0) { sb.append("\n") }
                    sb.append(imports[Int64(i)])
                }
            }
            case Solid => {
                // Solid 模式: 从 solid-js 导入
                let importSource = options.jsxImportSource
                if (importSource == "react") {
                    sb.append("import { createElement as _createElement } from \"solid-js\"")
                } else {
                    sb.append("import { createElement as _createElement } from \"${importSource}\"")
                }
            }
        }

        return sb.toString()
    }

    // ========================================================================
    // 工具方法
    // ========================================================================

    /// 标准化属性名 (className -> class, htmlFor -> for, 等)
    private func normalizePropName(name: String): String {
        match (name) {
            case "className" => "\"class\""
            case "htmlFor" => "\"for\""
            case "tabIndex" => "\"tabindex\""
            case "readOnly" => "\"readonly\""
            case "autoComplete" => "\"autocomplete\""
            case "autoFocus" => "\"autofocus\""
            case "autoPlay" => "\"autoplay\""
            case "colSpan" => "\"colspan\""
            case "rowSpan" => "\"rowspan\""
            case "defaultValue" => "\"defaultvalue\""
            case _ => name
        }
    }

    /// 转义字符串
    private func escapeString(s: String): String {
        var result = s
        result = result.replace("\\", "\\\\")
        result = result.replace("\"", "\\\"")
        result = result.replace("\n", "\\n")
        result = result.replace("\r", "\\r")
        result = result.replace("\t", "\\t")
        return result
    }

    private func skipWhitespace(): Unit {
        while (pos < source.length) {
            let ch = source[Int64(pos)]
            if (ch == Char(' ') || ch == Char('\t') || ch == Char('\n') || ch == Char('\r')) {
                pos += 1
            } else {
                break
            }
        }
    }

    private static func startsWithAt(s: String, index: Int64, prefix: String): Bool {
        if (index + prefix.length > s.length) {
            return false
        }
        for (i in 0..prefix.length) {
            if (s[Int64(index + i)] != prefix[Int64(i)]) {
                return false
            }
        }
        return true
    }
}

// ============================================================================
// JSX AST 节点类型
// ============================================================================

/// JSX 元素 - 对应 AST 中的 JSXElement 节点
public class JSXElement {
    /// 标签名 (如 "div", "Component", "<>" for Fragment)
    public var tagName: String
    /// 属性列表
    public var attrs: ArrayList<JSXAttribute>
    /// 子元素列表
    public var children: ArrayList<JSXChild>
    /// 是否是 Fragment
    public var isFragment: Bool

    public init(tagName: String, attrs: ArrayList<JSXAttribute>,
                children: ArrayList<JSXChild>, isFragment: Bool) {
        this.tagName = tagName
        this.attrs = attrs
        this.children = children
        this.isFragment = isFragment
    }
}

/// JSX 属性
public class JSXAttribute {
    /// 属性名 (或 "__spread__" 表示 spread)
    public var name: String
    /// 属性值
    public var value: String
    /// 是否是表达式值 ({...})
    public var isExpression: Bool
    /// 是否是 spread 属性
    public var isSpread: Bool

    public init(name: String, value: String, isSpread: Bool) {
        this.name = name
        this.value = value
        this.isExpression = !isSpread && !value.startsWith("\"")
        this.isSpread = isSpread
    }
}

/// JSX 子元素类型
public enum JSXChildKind {
    | Text        // 文本内容
    | Expression  // 表达式 {expr}
    | Element     // 嵌套元素
}

/// JSX 子元素
public class JSXChild {
    public var kind: JSXChildKind
    public var textValue: String
    public var elementValue: JSXElement

    private init(kind: JSXChildKind, text: String, element: JSXElement) {
        this.kind = kind
        this.textValue = text
        this.elementValue = element
    }

    public static func textChild(text: String): JSXChild {
        return JSXChild(JSXChildKind.Text, text, JSXElement("", ArrayList<JSXAttribute>(), ArrayList<JSXChild>(), false))
    }

    public static func expressionChild(expr: String): JSXChild {
        return JSXChild(JSXChildKind.Expression, expr, JSXElement("", ArrayList<JSXAttribute>(), ArrayList<JSXChild>(), false))
    }

    public static func elementChild(elem: JSXElement): JSXChild {
        return JSXChild(JSXChildKind.Element, "", elem)
    }
}
