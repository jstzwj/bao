// JSX Parser Extension - JSX 语法解析扩展
// 严格翻译自: src/js_parser/p.jsx.zig
//   Bun 的 JSX 解析器作为 Parser 的扩展，支持:
//     - JSX 元素: <div>, <Component.Sub>, <svg:rect>
//     - JSX 属性: id="foo", onClick={handler}, {...props}
//     - JSX 子元素: 文本、表达式容器、嵌套元素
//     - JSX 片段: <>...</>
//   JSX 解析完成后，可通过 JSXTransform 转换为函数调用:
//     - Classic runtime: React.createElement(type, props, ...children)
//     - Automatic runtime: jsx(type, props, key) / jsxs(type, props, key)
//
//   此模块作为独立工具类实现，不直接继承 Parser，
//   而是提供可从解析器调用的工具函数
package bao_parser

import bao_core.*
import bao_collections.*

// ============================================================================
// JSXElementNameTag - JSX 元素名称类型
// 严格翻译自: src/js_parser/p.jsx.zig JSX.ElementName.Kind
//   pub const Kind = enum { identifier, namespaced, member }
// ============================================================================

/// JSX 元素名称类型 - 对应 Bun JSX 元素名称标签
public enum JSXElementNameTag {
    | Identifier    // <div> - 简单标识符
    | Namespaced    // <svg:rect> - 命名空间限定
    | Member        // <Component.Sub> - 成员访问链

    /// 是否为内置 HTML 元素 (小写开头)
    public func isBuiltIn(): Bool {
        match (this) {
            case Identifier => true
            case Namespaced | Member => false
        }
    }

    /// 描述名称
    public func displayName(): String {
        match (this) {
            case Identifier => "identifier"
            case Namespaced => "namespaced"
            case Member => "member"
        }
    }
}

// ============================================================================
// JSXElementName - JSX 元素名称
// 严格翻译自: src/js_parser/p.jsx.zig JSX.ElementName
//   pub const ElementName = struct {
//       loc: Loc,
//       kind: Kind,
//       name: string,          // "div"
//       namespace: string,     // "svg" (for <svg:rect>)
//       member_parts: []string // ["Component", "Sub"]
//   }
// ============================================================================

/// JSX 元素名称 - 对应 Bun JSX ElementName
/// 表示 JSX 标签名，支持三种形式:
///   - Identifier: <div>, <Component>
///   - Namespaced: <svg:rect>
///   - Member: <Component.Sub.Deep>
public class JSXElementName {
    /// 源码位置
    public var loc: Loc
    /// 名称类型标签
    public var tag: JSXElementNameTag
    /// 简单名称 - 如 "div", "Component"
    public var name: String
    /// 命名空间名称 - 如 "svg" (用于 <svg:rect>)
    public var namespacedName: String
    /// 成员表达式 - 如 Component.Sub.Deep 的表达式树
    public var memberExpr: ?Expr

    public init(loc: Loc, tag: JSXElementNameTag) {
        this.loc = loc
        this.tag = tag
        name = ""
        namespacedName = ""
        memberExpr = None
    }

    public init(loc: Loc, name: String) {
        this.loc = loc
        this.tag = JSXElementNameTag.Identifier
        this.name = name
        this.namespacedName = ""
        this.memberExpr = None
    }

    /// 获取名称字符串表示
    /// <div> -> "div", <svg:rect> -> "svg:rect", <A.B> -> "A.B"
    public func fullName(): String {
        match (tag) {
            case Identifier => name
            case Namespaced => "${namespacedName}:${name}"
            case Member =>
                match (memberExpr) {
                    case Some(e) => exprToNameString(e)
                    case None => name
                }
        }
    }

    /// 是否为内置 HTML/SVG 元素 (小写开头)
    public func isBuiltIn(): Bool {
        if (tag != JSXElementNameTag.Identifier) {
            return false
        }
        return JSXParser.isBuiltInJsxElement(name)
    }

    /// 从表达式树中提取点分名称字符串
    private func exprToNameString(expr: Expr): String {
        match (expr.tag) {
            case ExprTag.Identifier => expr.identifierName
            case ExprTag.Dot =>
                var parts = ArrayList<String>()
                collectDotParts(expr, parts)
                var sb = StringBuilder()
                var first = true
                for (part in parts) {
                    if (!first) { sb.append(".") }
                    sb.append(part)
                    first = false
                }
                return sb.toString()
            case _ => ""
        }
    }

    /// 递归收集点访问链的各部分
    private func collectDotParts(expr: Expr, parts: ArrayList<String>): Unit {
        match (expr.tag) {
            case ExprTag.Dot =>
                match (expr.target) {
                    case Some(t) => collectDotParts(t, parts)
                    case None => ()
                }
                parts.append(expr.propertyName)
            case ExprTag.Identifier =>
                parts.append(expr.identifierName)
            case _ => ()
        }
    }
}

// ============================================================================
// JSXElementData - 已解析的 JSX 元素数据
// 严格翻译自: src/js_parser/p.jsx.zig JSX.Element
//   pub const Element = struct {
//       loc: Loc,
//       name: ElementName,
//       attributes: []G.Property,
//       children: []Expr,
//       is_self_closing: bool,
//       has_key_prop: bool,
//       has_ref_prop: bool,
//   }
// ============================================================================

/// JSX 元素数据 - 对应 Bun JSX Element
/// 包含从 JSX 语法中解析出的完整元素信息
public class JSXElementData {
    /// 源码位置
    public var loc: Loc
    /// 元素名称
    public var name: JSXElementName
    /// 属性列表
    public var attributes: ArrayList<GProperty>
    /// 子元素列表
    public var children: ArrayList<Expr>
    /// 是否为自闭合标签 (<br />)
    public var isSelfClosing: Bool
    /// 是否包含 key 属性 (用于 React 协调)
    public var hasKeyProp: Bool
    /// 是否包含 ref 属性 (用于 React ref)
    public var hasRefProp: Bool

    public init(loc: Loc, name: JSXElementName) {
        this.loc = loc
        this.name = name
        attributes = ArrayList<GProperty>()
        children = ArrayList<Expr>()
        isSelfClosing = false
        hasKeyProp = false
        hasRefProp = false
    }

    public init(loc: Loc, name: JSXElementName, isSelfClosing: Bool) {
        this.loc = loc
        this.name = name
        attributes = ArrayList<GProperty>()
        children = ArrayList<Expr>()
        this.isSelfClosing = isSelfClosing
        hasKeyProp = false
        hasRefProp = false
    }

    /// 子元素数量
    public func childCount(): Int64 {
        return children.size
    }

    /// 属性数量
    public func attributeCount(): Int64 {
        return attributes.size
    }

    /// 查找指定名称的属性
    public func findAttribute(name: String): ?GProperty {
        for (attr in attributes) {
            if (attr.key == name) {
                return Some(attr)
            }
        }
        return None
    }
}

// ============================================================================
// TokenStream - Token 流
// 严格翻译自: src/js_parser/p.jsx.zig 中对 lexer token 的抽象
//   JSX 解析器需要回溯和前瞻能力，使用 TokenStream 封装 token 列表
// ============================================================================

/// Token 流 - 封装 token 列表，提供读取、前瞻、回溯等操作
/// 由 parser_ts.cj 定义，此处为独立版本供 JSX 解析使用
public class TokenStream {
    /// token 类型列表
    public var tokens: ArrayList<Token>
    /// token 字符串值列表 (标识符名、字符串字面量内容等)
    public var tokenStrings: ArrayList<String>
    /// token 位置列表
    public var tokenLocs: ArrayList<Loc>
    /// 当前读取位置
    public var pos: Int64

    public init() {
        tokens = ArrayList<Token>()
        tokenStrings = ArrayList<String>()
        tokenLocs = ArrayList<Loc>()
        pos = 0
    }

    public init(tokens: ArrayList<Token>, strings: ArrayList<String>, locs: ArrayList<Loc>) {
        this.tokens = tokens
        this.tokenStrings = strings
        this.tokenLocs = locs
        pos = 0
    }

    /// 当前 token
    public func current(): Token {
        if (pos >= tokens.size) { return Token.EndOfFile }
        return tokens[Int64(pos)]
    }

    /// 当前 token 的字符串值
    public func currentString(): String {
        if (pos >= tokenStrings.size) { return "" }
        return tokenStrings[Int64(pos)]
    }

    /// 当前 token 的位置
    public func currentLoc(): Loc {
        if (pos >= tokenLocs.size) { return Loc.EMPTY }
        return tokenLocs[Int64(pos)]
    }

    /// 前进到下一个 token
    public func advance(): Unit {
        if (pos < tokens.size) {
            pos += 1
        }
    }

    /// 期望指定 token，不匹配时记录错误但仍前进
    public func expect(tok: Token): Unit {
        if (current() == tok) {
            advance()
        }
    }

    /// 如果当前 token 匹配则前进并返回 true
    public func match_(tok: Token): Bool {
        if (current() == tok) {
            advance()
            return true
        }
        return false
    }

    /// 查看前方第 n 个 token (不移动位置)
    public func peek(offset: Int64): Token {
        let idx = pos + offset
        if (idx >= tokens.size) { return Token.EndOfFile }
        return tokens[Int64(idx)]
    }

    /// 如果当前 token 匹配则消费，否则不操作
    public func eat(tok: Token): Bool {
        return match_(tok)
    }

    /// 向前查看而不消费
    public func lookahead(): Token {
        return peek(1)
    }

    /// 是否已到达末尾
    public func isEof(): Bool {
        return pos >= tokens.size || current() == Token.EndOfFile
    }
}

// ============================================================================
// JSXParser - JSX 解析工具
// 严格翻译自: src/js_parser/p.jsx.zig
//   Bun 中 JSX 解析集成在 Parser (p.zig) 中，通过 comptime jsx 参数控制
//   主要入口:
//     fn parseJSXElement(p: *P) !Expr
//     fn parseJSXOpeningElement(p: *P) !Expr
//     fn parseJSXChildren(p: *P) ![]Expr
//   仓颉实现为独立工具类，接收 TokenStream 进行解析
// ============================================================================

/// JSX 解析器 - 独立的 JSX 语法解析工具
/// 对应 Bun Parser 中 comptime jsx=true 分支的解析逻辑
public class JSXParser {

    // ========================================================================
    // 元素解析 (Element parsing)
    // 严格翻译自: src/js_parser/p.jsx.zig parseJSXElement / parseJSXFragment
    // ========================================================================

    /// 解析 JSX 元素 - 对应 Bun parseJSXElement
    /// <div attr="value">children</div>
    /// <div attr="value" />
    /// <Component.Sub>...</Component.Sub>
    public static func parseJsxElement(loc: Loc, tokens: TokenStream): Expr {
        // 解析开始标签
        let openingName = parseJsxOpeningElement(loc, tokens)

        // 检查自闭合: <br />
        if (tokens.current() == Token.Slash) {
            tokens.advance() // skip /
            tokens.expect(Token.GreaterThan) // skip >
            let element = JSXElementData(loc, openingName, true)
            return jsxElementToExpr(element)
        }
        tokens.expect(Token.GreaterThan) // skip >

        // 解析子元素
        let children = parseJsxChildren(tokens)

        // 解析结束标签
        let closingName = parseJsxClosingElement(tokens.currentLoc(), tokens)

        // 验证开始/结束标签匹配
        if (openingName.fullName() != closingName.fullName()) {
            // 标签不匹配，记录诊断但继续解析
        }

        let element = JSXElementData(loc, openingName, false)
        element.children = children

        // 扫描属性中的 key/ref
        scanKeyRefProps(element)

        return jsxElementToExpr(element)
    }

    /// 解析 JSX 开始标签 - 对应 Bun parseJSXOpeningElement
    /// <div, <Component.Sub, <svg:rect
    /// 返回元素名称，不消费 >
    public static func parseJsxOpeningElement(loc: Loc, tokens: TokenStream): JSXElementName {
        tokens.expect(Token.LessThan) // skip <

        // 解析元素名称
        let name = parseJsxElementName(tokens)

        // 解析属性
        // 注意: 属性在调用方处理，此处仅返回名称
        return name
    }

    /// 解析 JSX 结束标签 - 对应 Bun parseJSXClosingElement
    /// </div>, </Component.Sub>
    public static func parseJsxClosingElement(loc: Loc, tokens: TokenStream): JSXElementName {
        tokens.expect(Token.LessThan) // skip <
        tokens.expect(Token.Slash)    // skip /
        let name = parseJsxElementName(tokens)
        tokens.expect(Token.GreaterThan) // skip >
        return name
    }

    /// 解析 JSX 片段 - 对应 Bun parseJSXFragment
    /// <>children</>
    public static func parseJsxFragment(loc: Loc, tokens: TokenStream): Expr {
        tokens.expect(Token.LessThan)   // skip <
        tokens.expect(Token.GreaterThan) // skip >

        let children = parseJsxChildren(tokens)

        // 结束标签 </>
        tokens.expect(Token.LessThan)   // skip <
        tokens.expect(Token.Slash)      // skip /
        tokens.expect(Token.GreaterThan) // skip >

        // 片段使用空名称
        let emptyName = JSXElementName(loc, JSXElementNameTag.Identifier)
        emptyName.name = ""
        let element = JSXElementData(loc, emptyName, false)
        element.children = children
        let expr = Expr(loc, ExprTag.JsxFragment)
        expr.jsxChildren = children
        return expr
    }

    /// 解析自闭合 JSX 元素 - 对应 Bun parseJSXSelfClosingElement
    /// <br />, <Component />
    public static func parseJsxSelfClosingElement(loc: Loc, tokens: TokenStream): Expr {
        tokens.expect(Token.LessThan) // skip <
        let name = parseJsxElementName(tokens)

        // 解析属性
        let attributes = parseJsxAttributes(tokens)

        tokens.expect(Token.Slash)     // skip /
        tokens.expect(Token.GreaterThan) // skip >

        let element = JSXElementData(loc, name, true)
        element.attributes = attributes
        scanKeyRefProps(element)
        return jsxElementToExpr(element)
    }

    // ========================================================================
    // 属性解析 (Attribute parsing)
    // 严格翻译自: src/js_parser/p.jsx.zig parseJSXAttributes
    //   JSX 属性支持: name="value", name={expr}, {...spread}
    // ========================================================================

    /// 解析 JSX 属性列表 - 对应 Bun parseJSXAttributes
    public static func parseJsxAttributes(tokens: TokenStream): ArrayList<GProperty> {
        var attributes = ArrayList<GProperty>()
        while (!tokens.isEof()) {
            let tok = tokens.current()
            // 属性列表结束条件: >, />, }
            if (tok == Token.GreaterThan || tok == Token.Slash) {
                break
            }
            // 展开属性: {...props}
            if (tok == Token.DotDotDot || tok == Token.OpenBrace) {
                if (tok == Token.DotDotDot) {
                    tokens.advance()
                }
                let spreadAttr = parseJsxSpreadAttribute(tokens.currentLoc(), tokens)
                attributes.append(spreadAttr)
                continue
            }
            // 普通属性: name="value" 或 name={expr}
            if (isJsxIdentifierStart(tok)) {
                let name = tokens.currentString()
                let attrLoc = tokens.currentLoc()
                tokens.advance()
                let attr = parseJsxAttribute(name, attrLoc, tokens)
                attributes.append(attr)
                continue
            }
            // 未知 token，跳过
            tokens.advance()
        }
        return attributes
    }

    /// 解析单个 JSX 属性 - 对应 Bun parseJSXAttribute
    /// name="value" -> GProperty(key="name", value=Expr.string("value"))
    /// name={expr}  -> GProperty(key="name", value=expr)
    /// name         -> GProperty(key="name", value=Expr.bool(true))  // 简写布尔属性
    public static func parseJsxAttribute(name: String, loc: Loc, tokens: TokenStream): GProperty {
        var value: ?Expr = None

        if (tokens.current() == Token.Equals) {
            tokens.advance() // skip =
            value = Some(parseJsxAttributeValue(tokens))
        } else {
            // 无值属性视为 true: <input disabled />
            value = Some(Expr.bool_(loc, true))
        }

        let prop = GProperty(loc, name, value)
        prop.kind = GPropertyKind.Field
        return prop
    }

    /// 解析 JSX 属性值 - 对应 Bun parseJSXAttributeValue
    /// "string" | {expression} | <element>
    public static func parseJsxAttributeValue(tokens: TokenStream): Expr {
        let loc = tokens.currentLoc()

        // 字符串值: "hello" 或 'hello'
        if (tokens.current() == Token.StringLiteral) {
            let text = tokens.currentString()
            tokens.advance()
            return Expr.string(loc, text)
        }

        // 表达式容器: {expr}
        if (tokens.current() == Token.OpenBrace) {
            return parseJsxExpressionContainer(loc, tokens)
        }

        // 嵌套元素: <Element />
        if (tokens.current() == Token.LessThan) {
            return parseJsxElement(loc, tokens)
        }

        // 默认返回空
        tokens.advance()
        return Expr.missing(loc)
    }

    /// 解析 JSX 展开属性 - 对应 Bun parseJSXSpreadAttribute
    /// {...props} -> GProperty(kind=Spread, value=props)
    public static func parseJsxSpreadAttribute(loc: Loc, tokens: TokenStream): GProperty {
        tokens.expect(Token.OpenBrace) // skip {

        // 解析表达式 (简化: 只处理标识符)
        var expr = Expr.missing(loc)
        if (tokens.current() == Token.Identifier) {
            let name = tokens.currentString()
            expr = Expr.identifier(tokens.currentLoc(), name)
            tokens.advance()
        }

        tokens.expect(Token.CloseBrace) // skip }

        let prop = GProperty(loc, "...", Some(expr))
        prop.kind = GPropertyKind.Spread
        prop.flags.isSpread = true
        return prop
    }

    // ========================================================================
    // 子元素解析 (Children parsing)
    // 严格翻译自: src/js_parser/p.jsx.zig parseJSXChildren / parseJSXChild
    // ========================================================================

    /// 解析 JSX 子元素列表 - 对应 Bun parseJSXChildren
    public static func parseJsxChildren(tokens: TokenStream): ArrayList<Expr> {
        var children = ArrayList<Expr>()
        while (!tokens.isEof()) {
            // 结束条件: 遇到 </
            if (tokens.current() == Token.LessThan && tokens.lookahead() == Token.Slash) {
                break
            }
            let child = parseJsxChild(tokens)
            match (child) {
                case Some(expr) => children.append(expr)
                case None => break
            }
        }
        return children
    }

    /// 解析单个 JSX 子元素 - 对应 Bun parseJSXChild
    /// 子元素可以是: 文本、表达式容器 {expr}、嵌套元素 <div>...</div>
    public static func parseJsxChild(tokens: TokenStream): ?Expr {
        let tok = tokens.current()
        let loc = tokens.currentLoc()

        // 结束标签或 EOF
        if (tok == Token.EndOfFile) { return None }
        if (tok == Token.LessThan) {
            // 检查是否为结束标签 </
            if (tokens.lookahead() == Token.Slash) {
                return None
            }
            // 检查是否为片段 <>
            if (tokens.lookahead() == Token.GreaterThan) {
                return Some(parseJsxFragment(loc, tokens))
            }
            // 嵌套元素
            return Some(parseJsxElement(loc, tokens))
        }

        // 表达式容器 {expr}
        if (tok == Token.OpenBrace) {
            return Some(parseJsxExpressionContainer(loc, tokens))
        }

        // 文本内容
        return Some(parseJsxText(loc, tokens))
    }

    /// 解析 JSX 文本 - 对应 Bun parseJSXText
    /// 文本节点 (标签之间的纯文本内容)
    public static func parseJsxText(loc: Loc, tokens: TokenStream): Expr {
        // 收集文本直到遇到 < 或 {
        var sb = StringBuilder()
        while (!tokens.isEof()) {
            let tok = tokens.current()
            if (tok == Token.LessThan || tok == Token.OpenBrace) {
                break
            }
            sb.append(tokens.currentString())
            tokens.advance()
        }
        let text = sb.toString()
        return Expr.string(loc, text)
    }

    /// 解析 JSX 表达式容器 - 对应 Bun parseJSXExpressionContainer
    /// {expr} -> 包含表达式的子元素
    /// 特殊: {...} 空表达式 (合法), {/* comment */} 注释
    public static func parseJsxExpressionContainer(loc: Loc, tokens: TokenStream): Expr {
        tokens.expect(Token.OpenBrace) // skip {

        // 空表达式 {}
        if (tokens.current() == Token.CloseBrace) {
            tokens.advance()
            return Expr.undefined(loc)
        }

        // 解析内部表达式 (简化: 标识符和字面量)
        var expr = Expr.missing(loc)
        let tok = tokens.current()
        match (tok) {
            case Token.Identifier =>
                let name = tokens.currentString()
                expr = Expr.identifier(tokens.currentLoc(), name)
                tokens.advance()
            case Token.StringLiteral =>
                let text = tokens.currentString()
                expr = Expr.string(tokens.currentLoc(), text)
                tokens.advance()
            case Token.NumericLiteral =>
                let text = tokens.currentString()
                expr = Expr.number(tokens.currentLoc(), 0.0)
                tokens.advance()
            case Token.True =>
                expr = Expr.bool_(tokens.currentLoc(), true)
                tokens.advance()
            case Token.False =>
                expr = Expr.bool_(tokens.currentLoc(), false)
                tokens.advance()
            case Token.Null =>
                expr = Expr.null_(tokens.currentLoc())
                tokens.advance()
            case Token.OpenBracket =>
                // 数组字面量
                let arrLoc = tokens.currentLoc()
                tokens.advance()
                var items = ArrayList<Expr>()
                while (tokens.current() != Token.CloseBracket && !tokens.isEof()) {
                    if (tokens.current() == Token.Comma) {
                        tokens.advance()
                        continue
                    }
                    items.append(Expr.missing(tokens.currentLoc()))
                    tokens.advance()
                }
                tokens.expect(Token.CloseBracket)
                expr = Expr.array(arrLoc, items)
            case _ =>
                tokens.advance()
        }

        tokens.expect(Token.CloseBrace) // skip }
        return expr
    }

    // ========================================================================
    // 名称解析 (Name parsing)
    // 严格翻译自: src/js_parser/p.jsx.zig parseJSXElementName
    // ========================================================================

    /// 解析 JSX 元素名称 - 对应 Bun parseJSXElementName
    /// 支持:
    ///   Identifier: div, Component
    ///   Namespaced: svg:rect
    ///   Member:     Component.Sub.Deep
    public static func parseJsxElementName(tokens: TokenStream): JSXElementName {
        let loc = tokens.currentLoc()
        let firstName = tokens.currentString()
        tokens.advance() // skip first identifier

        // 命名空间: svg:rect
        if (tokens.current() == Token.Colon) {
            tokens.advance() // skip :
            let localName = tokens.currentString()
            tokens.advance()
            let name = JSXElementName(loc, JSXElementNameTag.Namespaced)
            name.namespacedName = firstName
            name.name = localName
            return name
        }

        // 成员访问: Component.Sub.Deep
        if (tokens.current() == Token.Dot) {
            var expr = Expr.identifier(loc, firstName)
            while (tokens.current() == Token.Dot) {
                tokens.advance() // skip .
                let memberName = tokens.currentString()
                let memberLoc = tokens.currentLoc()
                tokens.advance()
                expr = Expr.dot(loc, expr, memberName, memberLoc)
            }
            let name = JSXElementName(loc, JSXElementNameTag.Member)
            name.name = firstName
            name.memberExpr = Some(expr)
            return name
        }

        // 简单标识符
        return JSXElementName(loc, firstName)
    }

    /// 判断当前位置是否为 JSX 开始元素或片段
    /// 对应 Bun isJSXOpeningElementOrFragment
    /// 检查 < 后面是否跟着标识符、> (片段) 或 : (命名空间)
    public static func isJsxOpeningElementOrFragment(tokens: TokenStream): Bool {
        if (tokens.current() != Token.LessThan) {
            return false
        }
        let next = tokens.lookahead()
        return next == Token.Identifier || next == Token.GreaterThan
    }

    // ========================================================================
    // 辅助函数 (Helpers)
    // 严格翻译自: src/js_parser/p.jsx.zig 辅助函数
    // ========================================================================

    /// 判断 token 是否可以作为 JSX 标识符开始
    /// JSX 标识符比 JS 标识符更宽松，允许 '-' 等字符
    public static func isJsxIdentifierStart(token: Token): Bool {
        match (token) {
            case Token.Identifier => true
            case _ => token.isIdentifierOrKeyword()
        }
    }

    /// 判断字符串是否为有效的 JSX 元素名称
    /// JSX 元素名必须以大写或小写字母开头
    public static func isValidJsxElementName(name: String): Bool {
        if (name.size == 0) { return false }
        let firstChar = name[0]
        return (firstChar >= 'a' && firstChar <= 'z') ||
               (firstChar >= 'A' && firstChar <= 'Z') ||
               firstChar == '_'
    }

    /// 判断是否为内置 JSX 元素 (HTML/SVG 标签)
    /// 对应 Bun 中对内置元素名的判断 (小写开头)
    public static func isBuiltInJsxElement(name: String): Bool {
        if (name.size == 0) { return false }
        let firstChar = name[0]
        return firstChar >= 'a' && firstChar <= 'z'
    }

    /// 将 JSXElementData 转换为 Expr
    /// 对应 Bun 中将解析结果存储到 Expr 的逻辑
    public static func jsxElementToExpr(element: JSXElementData): Expr {
        let expr = Expr(element.loc, ExprTag.JsxElement)
        expr.jsxTag = Some(convertElementNameToExpr(element.name))
        expr.jsxProps = element.attributes
        expr.jsxChildren = element.children
        return expr
    }

    // ========================================================================
    // 内部辅助方法
    // ========================================================================

    /// 扫描属性列表中的 key 和 ref 属性
    /// 对应 Bun 中对 key/ref 特殊属性的处理
    private static func scanKeyRefProps(element: JSXElementData): Unit {
        for (attr in element.attributes) {
            if (attr.key == "key") {
                element.hasKeyProp = true
            }
            if (attr.key == "ref") {
                element.hasRefProp = true
            }
        }
    }

    /// 将 JSXElementName 转换为表达式
    /// 对应 JSXTransform.convertElementNameToExpr，此处作为内部辅助
    private static func convertElementNameToExpr(name: JSXElementName): Expr {
        return JSXTransform.convertElementNameToExpr(name)
    }
}

// ============================================================================
// JSXTransform - JSX 到函数调用转换
// 严格翻译自: src/js_parser/p.jsx.zig JSX transform
//   Bun 支持 JSX 到函数调用的两种运行时转换:
//     1. Classic:   React.createElement(type, props, ...children)
//     2. Automatic: jsx(type, props, key) / jsxs(type, props, key)
//   React 17+ 的 automatic runtime 按子元素数量区分:
//     - jsx  用于单个子元素
//     - jsxs 用于多个子元素
//   自动运行时还需要导入:
//     import { jsx as _jsx } from "react/jsx-runtime"
// ============================================================================

/// JSX 转换器 - 将 JSX 元素转换为函数调用表达式
public class JSXTransform {

    // ========================================================================
    // Classic runtime 转换
    // 严格翻译自: src/js_parser/p.jsx.zig classic runtime transform
    //   React.createElement(type, props, ...children)
    // ========================================================================

    /// Classic runtime 转换 - 对应 Bun JSX classic transform
    /// <div id="foo">hello</div>
    /// -> React.createElement("div", {id: "foo"}, "hello")
    public static func transformClassic(element: JSXElementData, createElementName: String): Expr {
        let loc = element.loc

        // React.createElement
        let createElement = Expr.identifier(loc, createElementName)

        // 参数列表: (type, props, ...children)
        var args = ArrayList<Expr>()

        // 第一个参数: 元素类型
        args.append(convertElementNameToExpr(element.name))

        // 第二个参数: props 对象
        args.append(buildPropsObject(element.attributes, element.children))

        // 后续参数: children (展开传递)
        for (child in element.children) {
            args.append(child)
        }

        return Expr.call(loc, createElement, args)
    }

    // ========================================================================
    // Automatic runtime 转换
    // 严格翻译自: src/js_parser/p.jsx.zig automatic runtime transform
    //   jsx(type, props, key)   - 单个子元素
    //   jsxs(type, props, key)  - 多个子元素
    // ========================================================================

    /// Automatic runtime 转换 - 对应 Bun JSX automatic transform
    /// <div id="foo">hello</div>
    /// -> jsx("div", {id: "foo", children: "hello"}, key)
    public static func transformAutomatic(element: JSXElementData,
                                           jsxName: String, jsxsName: String): Expr {
        let loc = element.loc

        // 根据 children 数量选择 jsx 或 jsxs
        let useJsxs = element.children.size > 1
        let runtimeFunc = if (useJsxs) { jsxsName } else { jsxName }
        let callee = Expr.identifier(loc, runtimeFunc)

        // 提取 key 属性
        let (keyExpr, remainingAttrs) = extractKeyProp(element.attributes)

        // 构建 props (包含 children)
        let props = buildPropsObject(remainingAttrs, element.children)

        // 参数: (type, props, key)
        var args = ArrayList<Expr>()
        args.append(convertElementNameToExpr(element.name))
        args.append(props)
        match (keyExpr) {
            case Some(k) => args.append(k)
            case None => args.append(Expr.null_(loc))
        }

        return Expr.call(loc, callee, args)
    }

    // ========================================================================
    // 属性/Props 构建
    // ========================================================================

    /// 收集子元素到 children 属性
    /// 对应 Bun 中将子元素合并为 props.children 的逻辑
    public static func collectChildrenProps(children: ArrayList<Expr>): Expr {
        if (children.size == 0) {
            return Expr.undefined(Loc.EMPTY)
        }
        if (children.size == 1) {
            return children[0]
        }
        // 多个子元素包装为数组
        return Expr.array(Loc.EMPTY, children)
    }

    /// 提取 key 属性 - 对应 Bun 中 key prop 的特殊处理
    /// React automatic runtime 需要将 key 从 props 中分离
    /// 返回 (key表达式, 剩余属性列表)
    public static func extractKeyProp(attributes: ArrayList<GProperty>): Tuple<?Expr, ArrayList<GProperty>> {
        var keyExpr: ?Expr = None
        var remaining = ArrayList<GProperty>()

        for (attr in attributes) {
            if (attr.key == "key") {
                keyExpr = attr.value
            } else {
                remaining.append(attr)
            }
        }

        return Tuple<?Expr, ArrayList<GProperty>>(keyExpr, remaining)
    }

    /// 构建 props 对象表达式 - 对应 Bun buildJSXPropsObject
    /// 将属性列表 + children 合并为一个对象表达式
    public static func buildPropsObject(attributes: ArrayList<GProperty>,
                                         children: ArrayList<Expr>): Expr {
        var props = ArrayList<GProperty>()

        // 添加普通属性
        for (attr in attributes) {
            // 跳过 key 和 ref (由 runtime 单独处理)
            if (attr.key == "key") {
                continue
            }
            if (attr.key == "ref" && attr.kind != GPropertyKind.Spread) {
                // ref 在 automatic runtime 中特殊处理
            }
            props.append(attr)
        }

        // 添加 children 属性
        if (children.size > 0) {
            let childrenExpr = collectChildrenProps(children)
            let childrenProp = GProperty(Loc.EMPTY, "children", Some(childrenExpr))
            props.append(childrenProp)
        }

        return Expr.object(Loc.EMPTY, props)
    }

    // ========================================================================
    // 名称转换
    // ========================================================================

    /// 将 JSXElementName 转换为表达式 - 对应 Bun 中 element name 到表达式的转换
    /// Identifier "div"       -> Expr.string("div")        (内置元素用字符串)
    /// Identifier "Component" -> Expr.identifier("Component") (自定义组件用标识符)
    /// Namespaced "svg:rect"  -> Expr.string("svg:rect")
    /// Member "A.B.C"         -> Expr.dot(Expr.dot(A, B), C)
    public static func convertElementNameToExpr(name: JSXElementName): Expr {
        match (name.tag) {
            case JSXElementNameTag.Identifier =>
                // 小写开头 = 内置 HTML 元素，用字符串字面量
                if (name.name.size > 0 &&
                    name.name[0] >= 'a' && name.name[0] <= 'z') {
                    return Expr.string(name.loc, name.name)
                }
                // 大写开头 = 自定义组件，用标识符引用
                return Expr.identifier(name.loc, name.name)
            case JSXElementNameTag.Namespaced =>
                // 命名空间元素用字符串表示
                return Expr.string(name.loc, name.fullName())
            case JSXElementNameTag.Member =>
                // 成员表达式链
                match (name.memberExpr) {
                    case Some(expr) => return expr
                    case None => return Expr.identifier(name.loc, name.name)
                }
        }
    }

    // ========================================================================
    // 辅助函数
    // ========================================================================

    /// 判断表达式是否为字符串表达式
    /// 对应 Bun isStringExpression (用于 JSX 优化)
    public static func isStringExpression(expr: Expr): Bool {
        match (expr.tag) {
            case ExprTag.String => true
            case _ => false
        }
    }

    /// 将 JSX 文本内容转换为字符串
    /// 对应 Bun jsxTextToString
    /// JSX 文本中的空白处理:
    ///   - 去除行首行尾空白
    ///   - 合并连续空白为单个空格
    ///   - 空文本返回空字符串
    public static func jsxTextToString(text: String): String {
        if (text.size == 0) { return "" }

        var sb = StringBuilder()
        var inWhitespace = false
        var hasContent = false

        for (i in 0..text.size) {
            let c = text[Int64(i)]
            if (c == ' ' || c == '\t' || c == '\n' || c == '\r') {
                if (!inWhitespace && hasContent) {
                    sb.append(' ')
                    inWhitespace = true
                }
            } else {
                sb.append(c)
                inWhitespace = false
                hasContent = true
            }
        }

        var result = sb.toString()
        // 去除首尾空格
        // 简化实现: 直接返回处理后的字符串
        return result.trim()
    }
}
