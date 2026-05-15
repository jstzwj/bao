// 严格翻译自: src/css/properties/custom.zig
// CSS 自定义属性 / var() / env() / 未解析令牌列表
// 包含: TokenList, UnresolvedColor, Variable, EnvironmentVariable,
//        EnvironmentVariableName, UAEnvironmentVariable, Function,
//        TokenOrValue, CSSWideKeyword, UnparsedProperty, CustomProperty, CustomPropertyName

package bao_css.properties

import bao_core.*
import bao_collections.*

// ============================================================================
// CSSWideKeyword
// 严格翻译自 CSSWideKeyword
// ============================================================================

/// CSS 宽关键字 (inherit, initial, unset, revert, revert-layer)
/// 严格翻译自 CSSWideKeyword enum
public enum CSSWideKeyword {
    | Inherit
    | Initial
    | Unset
    | Revert
    | RevertLayer

    public func toCss(): String {
        match (this) {
            case Inherit => "inherit"
            case Initial => "initial"
            case Unset => "unset"
            case Revert => "revert"
            case RevertLayer => "revert-layer"
        }
    }

    public static func parse(parser: CssParser): ?CSSWideKeyword {
        match (parser.peekIdentLowercase()) {
            case "inherit" => { parser.advance(); return Inherit }
            case "initial" => { parser.advance(); return Initial }
            case "unset" => { parser.advance(); return Unset }
            case "revert" => { parser.advance(); return Revert }
            case "revert-layer" => { parser.advance(); return RevertLayer }
            case _ => None
        }
    }
}

// ============================================================================
// TokenList
// 严格翻译自 TokenList struct { v: ArrayList(TokenOrValue) }
// ============================================================================

/// CSS 令牌列表（自定义属性值）
/// 严格翻译自 TokenList
public class TokenList {
    public var v: ArrayList<TokenOrValue>

    public init() {
        this.v = ArrayList<TokenOrValue>()
    }

    public init(v: ArrayList<TokenOrValue>) {
        this.v = v
    }

    /// 序列化为 CSS
    /// 严格翻译自 toCss (完整版)
    public func toCss(dest: Printer, isCustomProperty: Bool): Unit {
        // 如果只有一个空白 token 且非压缩模式，跳过
        if (!dest.minify && v.size == 1 && v[0].isWhitespace()) {
            return
        }

        var hasWhitespace = false
        for (i in 0..v.size) {
            let token = v[i]
            match (token) {
                case TokenOrValue.Token(s) =>
                    dest.writeStr(s)
                    hasWhitespace = false
                case TokenOrValue.Color(c) =>
                    c.toCss(dest)
                    hasWhitespace = false
                case TokenOrValue.UnresolvedColor(uc) =>
                    uc.toCss(dest)
                    hasWhitespace = false
                case TokenOrValue.Url(u) =>
                    u.toCss(dest)
                    hasWhitespace = false
                case TokenOrValue.Var(vr) =>
                    vr.toCss(dest, isCustomProperty: isCustomProperty)
                    hasWhitespace = writeWhitespaceIfNeeded(i, dest: dest)
                case TokenOrValue.Env(ev) =>
                    ev.toCss(dest, isCustomProperty: isCustomProperty)
                    hasWhitespace = writeWhitespaceIfNeeded(i, dest: dest)
                case TokenOrValue.Function(f) =>
                    f.toCss(dest, isCustomProperty: isCustomProperty)
                    hasWhitespace = writeWhitespaceIfNeeded(i, dest: dest)
                case TokenOrValue.Length(l) =>
                    l.toCss(dest)
                    hasWhitespace = false
                case TokenOrValue.Angle(a) =>
                    a.toCss(dest)
                    hasWhitespace = false
                case TokenOrValue.Time(t) =>
                    t.toCss(dest)
                    hasWhitespace = false
                case TokenOrValue.Resolution(r) =>
                    r.toCss(dest)
                    hasWhitespace = false
                case TokenOrValue.DashedIdent(d) =>
                    dest.writeStr(d)
                    hasWhitespace = false
                case TokenOrValue.AnimationName(n) =>
                    dest.writeStr(n)
                    hasWhitespace = false
            }
        }
    }

    /// 简化版 toCss - 返回字符串
    public func toCss(): String {
        if (v.isEmpty()) {
            return ""
        }
        let sb = StringBuilder()
        for (item in v) {
            sb.append(item.toCss())
        }
        return sb.toString().trim()
    }

    /// 原始 CSS 输出 (仅 token 类型)
    /// 严格翻译自 toCssRaw
    public func toCssRaw(dest: Printer): Unit {
        for (item in v) {
            match (item) {
                case TokenOrValue.Token(s) => dest.writeStr(s)
                case _ => return dest.addFmtError()
            }
        }
    }

    /// 需要时写入空白
    /// 严格翻译自 writeWhitespaceIfNeeded
    private func writeWhitespaceIfNeeded(i: Int64, dest: Printer): Bool {
        if (!dest.minify &&
            i != v.size - 1 &&
            !isCommaOrCloseParen(v[i + 1])) {
            dest.writeChar(' ')
            return true
        }
        return false
    }

    private func isCommaOrCloseParen(token: TokenOrValue): Bool {
        match (token) {
            case TokenOrValue.Token(s) => s == "," || s == ")" || s == "]" || s == "}"
            case _ => false
        }
    }

    /// 判断相等
    /// 严格翻译自 eql
    public func eql(other: TokenList): Bool {
        if (this.v.size != other.v.size) { return false }
        for (i in 0..v.size) {
            if (!this.v[i].eql(other.v[i])) { return false }
        }
        return true
    }

    /// 深拷贝
    /// 严格翻译自 deepClone
    public func deepClone(): TokenList {
        let cloned = ArrayList<TokenOrValue>()
        for (item in v) {
            cloned.append(item.deepClone())
        }
        return TokenList(v: cloned)
    }

    /// 解析
    /// 严格翻译自 parse / parseInto
    public static func parse(parser: CssParser, options: CssParserOptions): CssParseResult<TokenList> {
        let tokens = ArrayList<TokenOrValue>()
        let result = parseInto(parser, tokens: tokens, options: options, depth: 0)
        if (result.isErr()) {
            return CssParseResult.err(result.error.getOrThrow())
        }

        // 去除首尾空白 (如果 token 数 >= 2)
        if (tokens.size >= 2) {
            var start: Int64 = 0
            var end: Int64 = tokens.size
            if (tokens.size > 0 && tokens[0].isWhitespace()) {
                start = 1
            }
            if (tokens.size > 0 && tokens[tokens.size - 1].isWhitespace()) {
                end = end - 1
            }
            let sliced = ArrayList<TokenOrValue>()
            for (i in start..end) {
                sliced.append(tokens[i])
            }
            return CssParseResult.ok(TokenList(v: sliced))
        }

        return CssParseResult.ok(TokenList(v: tokens))
    }

    /// 递归解析 token 列表
    /// 严格翻译自 parseInto
    public static func parseInto(parser: CssParser, tokens: ArrayList<TokenOrValue>,
        options: CssParserOptions, depth: Int64): CssParseResult<Unit> {
        if (depth > 500) {
            return CssParseResult.err(CssParseError(
                kind: CssParseErrorKind.CustomError,
                line: 0, column: 0, message: "maximum nesting depth exceeded"
            ))
        }

        var lastIsDelim = false
        var lastIsWhitespace = false

        while (true) {
            let tok = parser.nextIncludingWhitespace()
            if (tok.isNone()) { break }
            let token = tok.getOrThrow()

            match (token.kind) {
                case CssTokenKind.Whitespace | CssTokenKind.Comment =>
                    if (!lastIsDelim) {
                        tokens.append(TokenOrValue.Token(" "))
                        lastIsWhitespace = true
                    }
                case CssTokenKind.Function =>
                    let funcName = token.text.toLowerCase()
                    if (funcName == "var") {
                        let vr = Variable.parseNested(parser, options: options, depth: depth + 1)
                        if (vr.isOk()) {
                            tokens.append(TokenOrValue.Var(vr.unwrap()))
                        }
                        lastIsDelim = true
                        lastIsWhitespace = false
                    } else if (funcName == "env") {
                        let ev = EnvironmentVariable.parseNested(parser, options: options, depth: depth + 1)
                        if (ev.isOk()) {
                            tokens.append(TokenOrValue.Env(ev.unwrap()))
                        }
                        lastIsDelim = true
                        lastIsWhitespace = false
                    } else if (funcName == "url") {
                        // URL 函数
                        tokens.append(TokenOrValue.Url(CssUrl.parse(parser).unwrapOr(CssUrl())))
                        lastIsDelim = false
                        lastIsWhitespace = false
                    } else {
                        // 其他函数 - 解析参数
                        let argsResult = TokenList.parse(parser, options: options)
                        if (argsResult.isOk()) {
                            tokens.append(TokenOrValue.Function(
                                Function(name: funcName, arguments: argsResult.unwrap())
                            ))
                        }
                        lastIsDelim = true
                        lastIsWhitespace = false
                    }
                case CssTokenKind.Hash =>
                    // 尝试解析为颜色
                    let colorStr = token.text
                    let parsedColor = CssColor.parseHash(colorStr)
                    if (parsedColor.isSome()) {
                        tokens.append(TokenOrValue.Color(parsedColor.getOrThrow()))
                    } else {
                        tokens.append(TokenOrValue.Token("#" + colorStr))
                    }
                    lastIsDelim = false
                    lastIsWhitespace = false
                case CssTokenKind.Url =>
                    tokens.append(TokenOrValue.Url(CssUrl(text: token.text)))
                    lastIsDelim = false
                    lastIsWhitespace = false
                case CssTokenKind.Ident =>
                    let name = token.text
                    if (name.startsWith("--")) {
                        tokens.append(TokenOrValue.DashedIdent(name))
                        lastIsDelim = false
                        lastIsWhitespace = false
                    } else {
                        tokens.append(TokenOrValue.Token(name))
                        lastIsDelim = false
                        lastIsWhitespace = false
                    }
                case CssTokenKind.LParen | CssTokenKind.LBracket | CssTokenKind.LBrace =>
                    tokens.append(TokenOrValue.Token(token.text))
                    // 解析嵌套块
                    let nestedResult = parseInto(parser, tokens: tokens, options: options, depth: depth + 1)
                    if (nestedResult.isErr()) { return nestedResult }
                    let closeChar = match (token.kind) {
                        case CssTokenKind.LParen => ")"
                        case CssTokenKind.LBracket => "]"
                        case _ => "}"
                    }
                    tokens.append(TokenOrValue.Token(closeChar))
                    lastIsDelim = true
                    lastIsWhitespace = false
                case CssTokenKind.Dimension =>
                    // 尝试解析为具体维度
                    let dimToken = token
                    if (LengthValue.tryFromToken(dimToken).isSome()) {
                        tokens.append(TokenOrValue.Length(LengthValue.fromToken(dimToken).getOrThrow()))
                    } else if (Angle.tryFromToken(dimToken).isSome()) {
                        tokens.append(TokenOrValue.Angle(Angle.fromToken(dimToken).getOrThrow()))
                    } else if (Time.tryFromToken(dimToken).isSome()) {
                        tokens.append(TokenOrValue.Time(Time.fromToken(dimToken).getOrThrow()))
                    } else if (Resolution.tryFromToken(dimToken).isSome()) {
                        tokens.append(TokenOrValue.Resolution(Resolution.fromToken(dimToken).getOrThrow()))
                    } else {
                        tokens.append(TokenOrValue.Token(dimToken.toString()))
                    }
                    lastIsDelim = false
                    lastIsWhitespace = false
                case _ =>
                    // 默认处理
                    lastIsDelim = match (token.kind) {
                        case CssTokenKind.Delim | CssTokenKind.Comma => true
                        case _ => false
                    }

                    // 如果前一个 token 是空白，当前是分隔符，替换空白
                    if (lastIsDelim && lastIsWhitespace) {
                        tokens[tokens.size - 1] = TokenOrValue.Token(token.toString())
                    } else {
                        tokens.append(TokenOrValue.Token(token.toString()))
                    }
                    lastIsWhitespace = false
            }
        }

        return CssParseResult.ok(())
    }

    /// 颜色回退
    /// 严格翻译自 getFallback
    public func getFallback(kind: ColorFallbackKind): TokenList {
        let tokens = ArrayList<TokenOrValue>()
        for (old in v) {
            match (old) {
                case TokenOrValue.Color(c) =>
                    tokens.append(TokenOrValue.Color(c.getFallback(kind: kind)))
                case TokenOrValue.Function(f) =>
                    tokens.append(TokenOrValue.Function(f.getFallback(kind: kind)))
                case TokenOrValue.Var(vr) =>
                    tokens.append(TokenOrValue.Var(vr.getFallback(kind: kind)))
                case TokenOrValue.Env(ev) =>
                    tokens.append(TokenOrValue.Env(ev.getFallback(kind: kind)))
                case _ =>
                    tokens.append(old.deepClone())
            }
        }
        return TokenList(v: tokens)
    }

    /// 获取必要的颜色回退
    /// 严格翻译自 getNecessaryFallbacks
    public func getNecessaryFallbacks(targets: Targets): ColorFallbackKind {
        var fallbacks = ColorFallbackKind()
        for (token in v) {
            match (token) {
                case TokenOrValue.Color(c) =>
                    fallbacks.insert(c.getPossibleFallbacks(targets: targets))
                case TokenOrValue.Function(f) =>
                    fallbacks.insert(f.arguments.getNecessaryFallbacks(targets: targets))
                case TokenOrValue.Var(vr) =>
                    if (vr.fallback.isSome()) {
                        fallbacks.insert(vr.fallback.getOrThrow().getNecessaryFallbacks(targets: targets))
                    }
                case TokenOrValue.Env(ev) =>
                    if (ev.fallback.isSome()) {
                        fallbacks.insert(ev.fallback.getOrThrow().getNecessaryFallbacks(targets: targets))
                    }
                case _ => {}
            }
        }
        return fallbacks
    }
}

// ============================================================================
// UnresolvedColor
// 严格翻译自 UnresolvedColor
// ============================================================================

/// 具有未解析 alpha 的颜色值
/// 严格翻译自 UnresolvedColor
public enum UnresolvedColor {
    | RGB(Float32, Float32, Float32, TokenList)
    | HSL(Float32, Float32, Float32, TokenList)
    | LightDark(TokenList, TokenList)

    public func toCss(): String {
        match (this) {
            case RGB(r, g, b, alpha) => {
                var result = "rgb(" + r.toString() + " " + g.toString() + " " + b.toString()
                let alphaStr = alpha.toCss()
                if (alphaStr != "") {
                    result = result + " / " + alphaStr
                }
                return result + ")"
            }
            case HSL(h, s, l, alpha) => {
                var result = "hsl(" + h.toString() + " " + s.toString() + "% " + l.toString() + "%"
                let alphaStr = alpha.toCss()
                if (alphaStr != "") {
                    result = result + " / " + alphaStr
                }
                return result + ")"
            }
            case LightDark(light, dark) => {
                return "light-dark(" + light.toCss() + ", " + dark.toCss() + ")"
            }
        }
    }

    public func toCss(dest: Printer): Unit {
        dest.writeStr(this.toCss())
    }

    /// 解析
    /// 严格翻译自 UnresolvedColor.parse
    public static func parse(parser: CssParser, funcName: String, options: CssParserOptions): CssParseResult<UnresolvedColor> {
        match (funcName) {
            case "rgb" | "rgba" =>
                // rgb(r g b / alpha)
                let r = parser.parseNumber().getOr(0.0f)
                let g = parser.parseNumber().getOr(0.0f)
                let b = parser.parseNumber().getOr(0.0f)
                let alpha = TokenList.parse(parser, options: options).unwrapOr(TokenList())
                return CssParseResult.ok(RGB(r, g, b, alpha))
            case "hsl" | "hsla" =>
                let h = parser.parseNumber().getOr(0.0f)
                let s = parser.parseNumber().getOr(0.0f)
                let l = parser.parseNumber().getOr(0.0f)
                let alpha = TokenList.parse(parser, options: options).unwrapOr(TokenList())
                return CssParseResult.ok(HSL(h, s, l, alpha))
            case "light-dark" =>
                let light = TokenList.parse(parser, options: options).unwrapOr(TokenList())
                parser.expectComma()
                let dark = TokenList.parse(parser, options: options).unwrapOr(TokenList())
                return CssParseResult.ok(LightDark(light, dark))
            case _ => return CssParseResult.err(CssParseError(
                kind: CssParseErrorKind.InvalidValue, line: 0, column: 0, message: "unknown color function"
            ))
        }
    }
}

// ============================================================================
// Variable
// 严格翻译自 Variable
// ============================================================================

/// CSS var() 引用
/// 严格翻译自 Variable struct { name, fallback, ... }
public class Variable {
    public var name: DashedIdent
    public var fallback: ?TokenList

    public init(name: DashedIdent) {
        this.name = name
        this.fallback = None
    }

    public init(name: DashedIdent, fallback: ?TokenList) {
        this.name = name
        this.fallback = fallback
    }

    public func toCss(): String {
        match (fallback) {
            case Some(fb) => "var(" + name.toCss() + ", " + fb.toCss() + ")"
            case None => "var(" + name.toCss() + ")"
        }
    }

    public func toCss(dest: Printer, isCustomProperty: Bool): Unit {
        dest.writeStr(this.toCss())
    }

    /// 解析 var() 的内容
    /// 严格翻译自 Variable.parse
    public static func parseNested(parser: CssParser, options: CssParserOptions, depth: Int64): CssParseResult<Variable> {
        // 解析变量名 (--xxx)
        let nameToken = parser.expectIdent()
        if (nameToken.isNone()) {
            return CssParseResult.err(CssParseError(
                kind: CssParseErrorKind.InvalidValue, line: 0, column: 0, message: "expected dashed ident"
            ))
        }
        let varName = DashedIdent(nameToken.getOrThrow())

        // 可选回退值
        var fallback: ?TokenList = None
        if (parser.tryParseComma()) {
            let fbResult = TokenList.parse(parser, options: options)
            if (fbResult.isOk()) {
                fallback = Some(fbResult.unwrap())
            }
        }

        return CssParseResult.ok(Variable(name: varName, fallback: fallback))
    }

    public func eql(other: Variable): Bool {
        if (!this.name.eql(other.name)) { return false }
        match (this.fallback) {
            case Some(fb1) => match (other.fallback) {
                case Some(fb2) => fb1.eql(fb2)
                case None => false
            }
            case None => other.fallback.isNone()
        }
    }

    public func deepClone(): Variable {
        return Variable(
            name: this.name.deepClone(),
            fallback: this.fallback.map({ v => v.deepClone() })
        )
    }

    /// 颜色回退
    /// 严格翻译自 getFallback
    public func getFallback(kind: ColorFallbackKind): Variable {
        return Variable(
            name: this.name.deepClone(),
            fallback: this.fallback.map({ v => v.getFallback(kind: kind) })
        )
    }
}

// ============================================================================
// DashedIdent
// 严格翻译自 DashedIdent
// ============================================================================

/// 虚线标识符 (--*)
/// 严格翻译自 DashedIdent struct { v: string }
public class DashedIdent {
    public var v: String

    public init(v: String) {
        this.v = v
    }

    public func toCss(): String {
        return v
    }

    public func toCss(dest: Printer): Unit {
        dest.writeStr(v)
    }

    public func eql(other: DashedIdent): Bool {
        return this.v == other.v
    }

    public func deepClone(): DashedIdent {
        return DashedIdent(v: this.v)
    }
}

// ============================================================================
// EnvironmentVariable
// 严格翻译自 EnvironmentVariable
// ============================================================================

/// CSS env() 引用
/// 严格翻译自 EnvironmentVariable struct { name, indices, fallback }
public class EnvironmentVariable {
    public var name: EnvironmentVariableName
    public var indices: ArrayList<Int32>
    public var fallback: ?TokenList

    public init(name: EnvironmentVariableName, indices: ArrayList<Int32>, fallback: ?TokenList) {
        this.name = name
        this.indices = indices
        this.fallback = fallback
    }

    public func toCss(): String {
        var result = "env(" + name.toCss()
        for (idx in indices) {
            result = result + " " + idx.toString()
        }
        match (fallback) {
            case Some(fb) => result = result + ", " + fb.toCss()
            case None => {}
        }
        return result + ")"
    }

    public func toCss(dest: Printer, isCustomProperty: Bool): Unit {
        dest.writeStr(this.toCss())
    }

    /// 解析 env() 的内容
    /// 严格翻译自 EnvironmentVariable.parseNested
    public static func parseNested(parser: CssParser, options: CssParserOptions, depth: Int64): CssParseResult<EnvironmentVariable> {
        let nameToken = parser.expectIdent()
        if (nameToken.isNone()) {
            return CssParseResult.err(CssParseError(
                kind: CssParseErrorKind.InvalidValue, line: 0, column: 0, message: "expected env variable name"
            ))
        }
        let envName = EnvironmentVariableName.fromCssName(nameToken.getOrThrow())

        // 可选维度索引
        let indices = ArrayList<Int32>()
        while (parser.tryParseNumber().isSome()) {
            indices.append(parser.lastParsedNumber().toInt32())
        }

        // 可选回退值
        var fallback: ?TokenList = None
        if (parser.tryParseComma()) {
            let fbResult = TokenList.parse(parser, options: options)
            if (fbResult.isOk()) {
                fallback = Some(fbResult.unwrap())
            }
        }

        return CssParseResult.ok(EnvironmentVariable(name: envName, indices: indices, fallback: fallback))
    }

    public func eql(other: EnvironmentVariable): Bool {
        if (!this.name.eql(other.name)) { return false }
        if (this.indices.size != other.indices.size) { return false }
        for (i in 0..indices.size) {
            if (this.indices[i] != other.indices[i]) { return false }
        }
        match (this.fallback) {
            case Some(fb1) => match (other.fallback) {
                case Some(fb2) => fb1.eql(fb2)
                case None => false
            }
            case None => other.fallback.isNone()
        }
    }

    public func deepClone(): EnvironmentVariable {
        let idx = ArrayList<Int32>()
        for (i in indices) { idx.append(i) }
        return EnvironmentVariable(
            name: this.name.deepClone(),
            indices: idx,
            fallback: this.fallback.map({ v => v.deepClone() })
        )
    }

    /// 颜色回退
    public func getFallback(kind: ColorFallbackKind): EnvironmentVariable {
        let idx = ArrayList<Int32>()
        for (i in indices) { idx.append(i) }
        return EnvironmentVariable(
            name: this.name.deepClone(),
            indices: idx,
            fallback: this.fallback.map({ v => v.getFallback(kind: kind) })
        )
    }
}

// ============================================================================
// EnvironmentVariableName
// 严格翻译自 EnvironmentVariableName
// ============================================================================

/// 环境变量名
/// 严格翻译自 EnvironmentVariableName
public enum EnvironmentVariableName {
    | Ua(UAEnvironmentVariable)
    | Custom(String)
    | Unknown(String)

    public func toCss(): String {
        match (this) {
            case Ua(ua) => ua.toCss()
            case Custom(s) => s
            case Unknown(s) => s
        }
    }

    public static func fromCssName(name: String): EnvironmentVariableName {
        match (name) {
            case "safe-area-inset-top" => Ua(UAEnvironmentVariable.SafeAreaInsetTop)
            case "safe-area-inset-right" => Ua(UAEnvironmentVariable.SafeAreaInsetRight)
            case "safe-area-inset-bottom" => Ua(UAEnvironmentVariable.SafeAreaInsetBottom)
            case "safe-area-inset-left" => Ua(UAEnvironmentVariable.SafeAreaInsetLeft)
            case "viewport-segment-width" => Ua(UAEnvironmentVariable.ViewportSegmentWidth)
            case "viewport-segment-height" => Ua(UAEnvironmentVariable.ViewportSegmentHeight)
            case "viewport-segment-top" => Ua(UAEnvironmentVariable.ViewportSegmentTop)
            case "viewport-segment-left" => Ua(UAEnvironmentVariable.ViewportSegmentLeft)
            case "viewport-segment-bottom" => Ua(UAEnvironmentVariable.ViewportSegmentBottom)
            case "viewport-segment-right" => Ua(UAEnvironmentVariable.ViewportSegmentRight)
            case _ => {
                if (name.startsWith("--")) {
                    Custom(name)
                } else {
                    Unknown(name)
                }
            }
        }
    }

    public func eql(other: EnvironmentVariableName): Bool {
        match (this) {
            case Ua(a) => match (other) { case Ua(b) => a == b case _ => false }
            case Custom(a) => match (other) { case Custom(b) => a == b case _ => false }
            case Unknown(a) => match (other) { case Unknown(b) => a == b case _ => false }
        }
    }

    public func deepClone(): EnvironmentVariableName {
        match (this) {
            case Ua(ua) => Ua(ua)
            case Custom(s) => Custom(s)
            case Unknown(s) => Unknown(s)
        }
    }
}

// ============================================================================
// UAEnvironmentVariable
// 严格翻译自 UAEnvironmentVariable
// ============================================================================

/// UA 定义的环境变量名
public enum UAEnvironmentVariable {
    | SafeAreaInsetTop
    | SafeAreaInsetRight
    | SafeAreaInsetBottom
    | SafeAreaInsetLeft
    | ViewportSegmentWidth
    | ViewportSegmentHeight
    | ViewportSegmentTop
    | ViewportSegmentLeft
    | ViewportSegmentBottom
    | ViewportSegmentRight

    public func toCss(): String {
        match (this) {
            case SafeAreaInsetTop => "safe-area-inset-top"
            case SafeAreaInsetRight => "safe-area-inset-right"
            case SafeAreaInsetBottom => "safe-area-inset-bottom"
            case SafeAreaInsetLeft => "safe-area-inset-left"
            case ViewportSegmentWidth => "viewport-segment-width"
            case ViewportSegmentHeight => "viewport-segment-height"
            case ViewportSegmentTop => "viewport-segment-top"
            case ViewportSegmentLeft => "viewport-segment-left"
            case ViewportSegmentBottom => "viewport-segment-bottom"
            case ViewportSegmentRight => "viewport-segment-right"
        }
    }
}

// ============================================================================
// Function
// 严格翻译自 Function struct { name, arguments }
// ============================================================================

/// 自定义 CSS 函数
/// 严格翻译自 Function
public class Function {
    public var name: DashedIdent
    public var arguments: TokenList

    public init(name: DashedIdent, arguments: TokenList) {
        this.name = name
        this.arguments = arguments
    }

    public init(name: String, arguments: TokenList) {
        this.name = DashedIdent(name)
        this.arguments = arguments
    }

    public func toCss(): String {
        return name.toCss() + "(" + arguments.toCss() + ")"
    }

    public func toCss(dest: Printer, isCustomProperty: Bool): Unit {
        dest.writeStr(name.toCss())
        dest.writeChar('(')
        arguments.toCss(dest, isCustomProperty: isCustomProperty)
        dest.writeChar(')')
    }

    public func eql(other: Function): Bool {
        return this.name.eql(other.name) && this.arguments.eql(other.arguments)
    }

    public func deepClone(): Function {
        return Function(name: this.name.deepClone(), arguments: this.arguments.deepClone())
    }

    /// 颜色回退
    public func getFallback(kind: ColorFallbackKind): Function {
        return Function(name: this.name.deepClone(), arguments: this.arguments.getFallback(kind: kind))
    }
}

// ============================================================================
// TokenOrValue
// 严格翻译自 TokenOrValue union(enum)
// ============================================================================

/// CSS 令牌或已解析值
/// 严格翻译自 TokenOrValue
public enum TokenOrValue {
    | Token(String)
    | Color(CssColor)
    | UnresolvedColor(UnresolvedColor)
    | Url(CssUrl)
    | Var(Variable)
    | Env(EnvironmentVariable)
    | Function(Function)
    | Length(LengthValue)
    | Angle(Angle)
    | Time(Time)
    | Resolution(Resolution)
    | DashedIdent(String)
    | AnimationName(String)

    public func toCss(): String {
        match (this) {
            case Token(s) => s
            case Color(c) => c.toCss()
            case UnresolvedColor(uc) => uc.toCss()
            case Url(u) => u.toCss()
            case Var(v) => v.toCss()
            case Env(e) => e.toCss()
            case Function(f) => f.toCss()
            case Length(l) => l.toCss()
            case Angle(a) => a.toCss()
            case Time(t) => t.toCss()
            case Resolution(r) => r.toCss()
            case DashedIdent(d) => d
            case AnimationName(n) => n
        }
    }

    /// 判断是否是空白
    /// 严格翻译自 isWhitespace
    public func isWhitespace(): Bool {
        match (this) {
            case Token(s) => s == " "
            case _ => false
        }
    }

    /// 判断相等
    /// 严格翻译自 eql
    public func eql(other: TokenOrValue): Bool {
        match (this) {
            case Token(a) => match (other) { case Token(b) => a == b case _ => false }
            case Color(a) => match (other) { case Color(b) => a.eql(b) case _ => false }
            case UnresolvedColor(a) => match (other) { case UnresolvedColor(b) => a == b case _ => false }
            case Url(a) => match (other) { case Url(b) => a.eql(b) case _ => false }
            case Var(a) => match (other) { case Var(b) => a.eql(b) case _ => false }
            case Env(a) => match (other) { case Env(b) => a.eql(b) case _ => false }
            case Function(a) => match (other) { case Function(b) => a.eql(b) case _ => false }
            case Length(a) => match (other) { case Length(b) => a.eql(b) case _ => false }
            case Angle(a) => match (other) { case Angle(b) => a.eql(b) case _ => false }
            case Time(a) => match (other) { case Time(b) => a.eql(b) case _ => false }
            case Resolution(a) => match (other) { case Resolution(b) => a.eql(b) case _ => false }
            case DashedIdent(a) => match (other) { case DashedIdent(b) => a == b case _ => false }
            case AnimationName(a) => match (other) { case AnimationName(b) => a == b case _ => false }
        }
    }

    /// 深拷贝
    /// 严格翻译自 deepClone
    public func deepClone(): TokenOrValue {
        match (this) {
            case Token(s) => Token(s)
            case Color(c) => Color(c.deepClone())
            case UnresolvedColor(uc) => UnresolvedColor(uc)
            case Url(u) => Url(u.deepClone())
            case Var(v) => Var(v.deepClone())
            case Env(e) => Env(e.deepClone())
            case Function(f) => Function(f.deepClone())
            case Length(l) => Length(l.deepClone())
            case Angle(a) => Angle(a.deepClone())
            case Time(t) => Time(t.deepClone())
            case Resolution(r) => Resolution(r.deepClone())
            case DashedIdent(s) => DashedIdent(s)
            case AnimationName(s) => AnimationName(s)
        }
    }
}

// ============================================================================
// UnparsedProperty
// 严格翻译自 UnparsedProperty struct { property_id, value }
// ============================================================================

/// 未解析的已知属性值（例如包含 var() 引用）
/// 严格翻译自 UnparsedProperty
public class UnparsedProperty {
    public var propertyId: PropertyId
    public var value: TokenList
    /// CSS 重要标记
    public var important: Bool

    public init(propertyId: PropertyId, value: TokenList) {
        this.propertyId = propertyId
        this.value = value
        this.important = false
    }

    public init(propertyId: PropertyId, value: TokenList, important: Bool) {
        this.propertyId = propertyId
        this.value = value
        this.important = important
    }

    public func toCss(dest: Printer): Unit {
        propertyId.toCss(dest)
        dest.writeChar(':')
        dest.writeChar(' ')
        value.toCss(dest, isCustomProperty: false)
        if (important) {
            dest.writeStr(" !important")
        }
    }

    public func toCss(): String {
        let sb = StringBuilder()
        sb.append(propertyId.name())
        sb.append(": ")
        sb.append(value.toCss())
        if (important) {
            sb.append(" !important")
        }
        return sb.toString()
    }

    /// 获取带前缀的版本
    /// 严格翻译自 getPrefixed
    public func getPrefixed(targets: Targets, feature: Feature): UnparsedProperty {
        let prefixes = targets.prefixes(this.propertyId.prefix(), feature: feature)
        return UnparsedProperty(
            propertyId: PropertyId(tag: this.propertyId.tag, vendorPrefix: prefixes),
            value: this.value.deepClone(),
            important: this.important
        )
    }

    public func eql(other: UnparsedProperty): Bool {
        return this.propertyId.eql(other.propertyId) && this.value.eql(other.value)
    }

    public func deepClone(): UnparsedProperty {
        return UnparsedProperty(
            propertyId: this.propertyId.deepClone(),
            value: this.value.deepClone(),
            important: this.important
        )
    }
}

// ============================================================================
// CustomProperty
// 严格翻译自 CustomProperty struct { name, value }
// ============================================================================

/// CSS 自定义属性
/// 严格翻译自 CustomProperty
public class CustomProperty {
    public var name: CustomPropertyName
    public var value: TokenList

    public init(name: CustomPropertyName, value: TokenList) {
        this.name = name
        this.value = value
    }

    public func toCss(): String {
        return name.toCss() + ": " + value.toCss()
    }

    public func toCss(dest: Printer): Unit {
        dest.writeStr(name.toCss())
        dest.writeChar(':')
        dest.writeChar(' ')
        value.toCss(dest, isCustomProperty: true)
    }

    public func eql(other: CustomProperty): Bool {
        return this.name.eql(other.name) && this.value.eql(other.value)
    }

    public func deepClone(): CustomProperty {
        return CustomProperty(name: this.name.deepClone(), value: this.value.deepClone())
    }
}

// ============================================================================
// CustomPropertyName
// 严格翻译自 CustomPropertyName
// ============================================================================

/// CSS 自定义属性名
/// 严格翻译自 CustomPropertyName struct { v: string }
public class CustomPropertyName {
    public var v: String

    public init(v: String) {
        this.v = v
    }

    public func toCss(): String {
        return v
    }

    public func asStr(): String {
        return v
    }

    public func eql(other: CustomPropertyName): Bool {
        return this.v == other.v
    }

    public func deepClone(): CustomPropertyName {
        return CustomPropertyName(v: this.v)
    }
}

// ============================================================================
// 辅助类型引用 (外部模块)
// ============================================================================

/// 颜色回退类型
/// 严格翻译自 ColorFallbackKind packed struct
public class ColorFallbackKind {
    public var srgb: Bool = false
    public var p3: Bool = false
    public var lab: Bool = false

    public init() {}

    public func isEmpty(): Bool {
        return !srgb && !p3 && !lab
    }

    public func insert(other: ColorFallbackKind): Unit {
        this.srgb = this.srgb || other.srgb
        this.p3 = this.p3 || other.p3
        this.lab = this.lab || other.lab
    }

    public func lowest(): ColorFallbackKind {
        let r = ColorFallbackKind()
        if (this.lab) { r.lab = true }
        else if (this.p3) { r.p3 = true }
        else { r.srgb = true }
        return r
    }
}

/// CSS URL 值
/// 严格翻译自 Url
public class CssUrl {
    public var text: String
    public var importRecordIdx: Int64

    public init() {
        this.text = ""
        this.importRecordIdx = -1
    }

    public init(text: String) {
        this.text = text
        this.importRecordIdx = -1
    }

    public func toCss(): String {
        return "url(" + text + ")"
    }

    public func toCss(dest: Printer): Unit {
        dest.writeStr(this.toCss())
    }

    public func eql(other: CssUrl): Bool {
        return this.text == other.text
    }

    public func deepClone(): CssUrl {
        return CssUrl(text: this.text)
    }

    public static func parse(parser: CssParser): CssParseResult<CssUrl> {
        let url = parser.expectUrl()
        return CssParseResult.ok(CssUrl(text: url.getOr("")))
    }

    public func isAbsolute(records: ArrayList<ImportRecord>): Bool {
        return text.startsWith("http://") || text.startsWith("https://") || text.startsWith("data:")
    }
}
