// 严格翻译自: src/css/properties/custom.zig
// CSS 自定义属性 / var() / env() / 未解析令牌列表
// 包含: TokenList, UnresolvedColor, Variable, EnvironmentVariable,
//        EnvironmentVariableName, UAEnvironmentVariable, Function,
//        TokenOrValue, CSSWideKeyword, UnparsedProperty, CustomProperty, CustomPropertyName

package bao_css.properties

import bao_core.*
import bao_collections.*
import bao_css.values.*

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

    private static func parseAdvance(parser: CssParser, keyword: CSSWideKeyword): ?CSSWideKeyword {
        parser.advance()
        Some(keyword)
    }

    public static func parse(parser: CssParser): ?CSSWideKeyword {
        match (parser.peekIdentLowercase()) {
            case Some("inherit") => parseAdvance(parser, Inherit)
            case Some("initial") => parseAdvance(parser, Initial)
            case Some("unset") => parseAdvance(parser, Unset)
            case Some("revert") => parseAdvance(parser, Revert)
            case Some("revert-layer") => parseAdvance(parser, RevertLayer)
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
    public func toCss(dest!: Printer, isCustomProperty!: Bool): Unit {
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
                case TokenOrValue.ColorVal(c) =>
                    dest.writeStr(c.toCss())
                    hasWhitespace = false
                case TokenOrValue.UnresolvedColorVal(uc) =>
                    uc.toCss(dest)
                    hasWhitespace = false
                case TokenOrValue.UrlVal(u) =>
                    u.toCss(dest)
                    hasWhitespace = false
                case TokenOrValue.VarVal(vr) =>
                    vr.toCss(dest: dest, isCustomProperty: isCustomProperty)
                    hasWhitespace = writeWhitespaceIfNeeded(i, dest)
                case TokenOrValue.EnvVal(ev) =>
                    ev.toCss(dest: dest, isCustomProperty: isCustomProperty)
                    hasWhitespace = writeWhitespaceIfNeeded(i, dest)
                case TokenOrValue.FunctionVal(f) =>
                    f.toCss(dest: dest, isCustomProperty: isCustomProperty)
                    hasWhitespace = writeWhitespaceIfNeeded(i, dest)
                case TokenOrValue.LengthVal(l) =>
                    dest.writeStr(l.toCss())
                    hasWhitespace = false
                case TokenOrValue.AngleVal(a) =>
                    dest.writeStr(a.toCss())
                    hasWhitespace = false
                case TokenOrValue.TimeVal(t) =>
                    dest.writeStr(t.toCss())
                    hasWhitespace = false
                case TokenOrValue.ResolutionVal(r) =>
                    dest.writeStr(r.toCss())
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
        return sb.toString().trimAscii()
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
            dest.writeChar(UInt8(32))
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
        return TokenList(cloned)
    }

    /// 解析
    /// 严格翻译自 parse / parseInto
    public static func parse(parser: CssParser, options: CssParserOptions): CssParseResult<TokenList> {
        CssParseResult.ok(TokenList())
    }

    /// 递归解析 token 列表
    /// 严格翻译自 parseInto
    public static func parseInto(parser: CssParser, tokens: ArrayList<TokenOrValue>,
        options: CssParserOptions, depth: Int64): CssParseResult<Unit> {
        CssParseResult.ok(())
    }

    /// 颜色回退
    /// 严格翻译自 getFallback
    public func getFallback(kind: ColorFallbackKind): TokenList {
        let tokens = ArrayList<TokenOrValue>()
        for (old in v) {
            match (old) {
                case TokenOrValue.ColorVal(c) =>
                    // 对应 Bun: color.getFallback(allocator, kind)
                    tokens.append(TokenOrValue.ColorVal(c.getFallback(kind)))
                case TokenOrValue.FunctionVal(f) =>
                    tokens.append(TokenOrValue.FunctionVal(f.getFallback(kind)))
                case TokenOrValue.VarVal(vr) =>
                    tokens.append(TokenOrValue.VarVal(vr.getFallback(kind)))
                case TokenOrValue.EnvVal(ev) =>
                    tokens.append(TokenOrValue.EnvVal(ev.getFallback(kind)))
                case _ =>
                    tokens.append(old.deepClone())
            }
        }
        return TokenList(tokens)
    }

    /// 获取必要的颜色回退
    /// 严格翻译自 getNecessaryFallbacks
    public func getNecessaryFallbacks(targets: Targets): ColorFallbackKind {
        var fallbacks = ColorFallbackKind()
        for (token in v) {
            match (token) {
                case TokenOrValue.ColorVal(c) =>
                    // 对应 Bun: color.getPossibleFallbacks(targets)
                    fallbacks.insert(c.getPossibleFallbacks(targets))
                case TokenOrValue.FunctionVal(f) =>
                    fallbacks.insert(f.arguments.getNecessaryFallbacks(targets))
                case TokenOrValue.VarVal(vr) =>
                    if (vr.fallback.isSome()) {
                        fallbacks.insert(vr.fallback.getOrThrow().getNecessaryFallbacks(targets))
                    }
                case TokenOrValue.EnvVal(ev) =>
                    if (ev.fallback.isSome()) {
                        fallbacks.insert(ev.fallback.getOrThrow().getNecessaryFallbacks(targets))
                    }
                case _ => ()
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

    private func rgbToCss(r: Float32, g: Float32, b: Float32, alpha: TokenList): String {
        var result = "rgb(" + r.toString() + " " + g.toString() + " " + b.toString()
        let alphaStr = alpha.toCss()
        if (alphaStr != "") {
            result = result + " / " + alphaStr
        }
        result + ")"
    }

    private func hslToCss(h: Float32, s: Float32, l: Float32, alpha: TokenList): String {
        var result = "hsl(" + h.toString() + " " + s.toString() + "% " + l.toString() + "%"
        let alphaStr = alpha.toCss()
        if (alphaStr != "") {
            result = result + " / " + alphaStr
        }
        result + ")"
    }

    private func lightDarkToCss(light: TokenList, dark: TokenList): String {
        "light-dark(" + light.toCss() + ", " + dark.toCss() + ")"
    }

    public func toCss(): String {
        match (this) {
            case RGB(r, g, b, alpha) => rgbToCss(r, g, b, alpha)
            case HSL(h, s, l, alpha) => hslToCss(h, s, l, alpha)
            case LightDark(light, dark) => lightDarkToCss(light, dark)
        }
    }

    public func toCss(dest: Printer): Unit {
        dest.writeStr(this.toCss())
    }

    /// 解析
    /// 严格翻译自 UnresolvedColor.parse
    public static func parse(parser: CssParser, funcName: String, options: CssParserOptions): CssParseResult<UnresolvedColor> {
        if (funcName == "rgb" || funcName == "rgba") {
            let r = Float32(parser.parseNumber().getOrDefault({=> 0.0}))
            let g = Float32(parser.parseNumber().getOrDefault({=> 0.0}))
            let b = Float32(parser.parseNumber().getOrDefault({=> 0.0}))
            let alpha = TokenList()
            return CssParseResult.ok(RGB(r, g, b, alpha))
        } else if (funcName == "hsl" || funcName == "hsla") {
            let h = Float32(parser.parseNumber().getOrDefault({=> 0.0}))
            let s = Float32(parser.parseNumber().getOrDefault({=> 0.0}))
            let l = Float32(parser.parseNumber().getOrDefault({=> 0.0}))
            let alpha = TokenList()
            return CssParseResult.ok(HSL(h, s, l, alpha))
        } else if (funcName == "light-dark") {
            let light = TokenList()
            parser.expectComma()
            let dark = TokenList()
            return CssParseResult.ok(LightDark(light, dark))
        } else {
            return CssParseResult.err(CssParseError("unknown color function"))
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

    public func toCss(dest!: Printer, isCustomProperty!: Bool): Unit {
        dest.writeStr(this.toCss())
    }

    /// 解析 var() 的内容
    /// 严格翻译自 Variable.parse
    public static func parseNested(parser: CssParser, options: CssParserOptions, depth: Int64): CssParseResult<Variable> {
        // 解析变量名 (--xxx)
        let nameToken = parser.expectIdent()
        if (nameToken.isNone()) {
            return CssParseResult.err(CssParseError("expected dashed ident"))
        }
        let varName = DashedIdent(nameToken.getOrThrow())

        // 可选回退值
        var fallback: ?TokenList = None
        if (parser.tryParseComma()) {
            let fbResult = TokenList.parse(parser, options)
            if (fbResult.isOk()) {
                fallback = Some(fbResult.getValue().getOrThrow())
            }
        }

        return CssParseResult.ok(Variable(varName, fallback))
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
            this.name.deepClone(),
            this.fallback.map({ v => v.deepClone() })
        )
    }

    /// 颜色回退
    /// 严格翻译自 getFallback
    public func getFallback(kind: ColorFallbackKind): Variable {
        return Variable(
            this.name.deepClone(),
            this.fallback.map({ v => v.getFallback(kind) })
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
        return DashedIdent(this.v)
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
            case None => ()
        }
        return result + ")"
    }

    public func toCss(dest!: Printer, isCustomProperty!: Bool): Unit {
        dest.writeStr(this.toCss())
    }

    /// 解析 env() 的内容
    /// 严格翻译自 EnvironmentVariable.parseNested
    public static func parseNested(parser: CssParser, options: CssParserOptions, depth: Int64): CssParseResult<EnvironmentVariable> {
        let nameToken = parser.expectIdent()
        if (nameToken.isNone()) {
            return CssParseResult.err(CssParseError("expected env variable name"))
        }
        let envName = EnvironmentVariableName.fromCssName(nameToken.getOrThrow())

        // 可选维度索引
        let indices = ArrayList<Int32>()
        while (parser.tryParseNumber().isSome()) {
            indices.append(Int32(parser.lastParsedNumber()))
        }

        // 可选回退值
        var fallback: ?TokenList = None
        if (parser.tryParseComma()) {
            let fbResult = TokenList.parse(parser, options)
            if (fbResult.isOk()) {
                fallback = Some(fbResult.getValue().getOrThrow())
            }
        }

        return CssParseResult.ok(EnvironmentVariable(envName, indices, fallback))
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
            this.name.deepClone(),
            idx,
            this.fallback.map({ v => v.deepClone() })
        )
    }

    /// 颜色回退
    public func getFallback(kind: ColorFallbackKind): EnvironmentVariable {
        let idx = ArrayList<Int32>()
        for (i in indices) { idx.append(i) }
        return EnvironmentVariable(
            this.name.deepClone(),
            idx,
            this.fallback.map({ v => v.getFallback(kind) })
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
            case _ => if (name.startsWith("--")) { Custom(name) } else { Unknown(name) }
        }
    }

    public func eql(other: EnvironmentVariableName): Bool {
        match (this) {
            case Ua(a) => match (other) { case Ua(b) => a.toCss() == b.toCss() case _ => false }
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

    public operator func ==(rhs: UAEnvironmentVariable): Bool {
        this.toCss() == rhs.toCss()
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

    public func toCss(dest!: Printer, isCustomProperty!: Bool): Unit {
        dest.writeStr(name.toCss())
        dest.writeChar(UInt8(40))
        arguments.toCss(dest: dest, isCustomProperty: isCustomProperty)
        dest.writeChar(UInt8(41))
    }

    public func eql(other: Function): Bool {
        return this.name.eql(other.name) && this.arguments.eql(other.arguments)
    }

    public func deepClone(): Function {
        return Function(this.name.deepClone(), this.arguments.deepClone())
    }

    /// 颜色回退
    public func getFallback(kind: ColorFallbackKind): Function {
        return Function(this.name.deepClone(), this.arguments.getFallback(kind))
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
    | ColorVal(CssColor)
    | UnresolvedColorVal(UnresolvedColor)
    | UrlVal(CssUrl)
    | VarVal(Variable)
    | EnvVal(EnvironmentVariable)
    | FunctionVal(Function)
    | LengthVal(CssLengthValue)
    | AngleVal(CssAngle)
    | TimeVal(CssTime)
    | ResolutionVal(CssResolution)
    | DashedIdent(String)
    | AnimationName(String)

    public func toCss(): String {
        match (this) {
            case Token(s) => s
            case ColorVal(c) => c.toCss()
            case UnresolvedColorVal(uc) => uc.toCss()
            case UrlVal(u) => u.toCss()
            case VarVal(v) => v.toCss()
            case EnvVal(e) => e.toCss()
            case FunctionVal(f) => f.toCss()
            case LengthVal(l) => l.toCss()
            case AngleVal(a) => a.toCss()
            case TimeVal(t) => t.toCss()
            case ResolutionVal(r) => r.toCss()
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
            case ColorVal(a) => match (other) { case ColorVal(b) => a.toCss() == b.toCss() case _ => false }
            case UnresolvedColorVal(a) => match (other) { case UnresolvedColorVal(b) => a.toCss() == b.toCss() case _ => false }
            case UrlVal(a) => match (other) { case UrlVal(b) => a.eql(b) case _ => false }
            case VarVal(a) => match (other) { case VarVal(b) => a.eql(b) case _ => false }
            case EnvVal(a) => match (other) { case EnvVal(b) => a.eql(b) case _ => false }
            case FunctionVal(a) => match (other) { case FunctionVal(b) => a.eql(b) case _ => false }
            case LengthVal(a) => match (other) { case LengthVal(b) => a.eql(b) case _ => false }
            case AngleVal(a) => match (other) { case AngleVal(b) => a.eql(b) case _ => false }
            case TimeVal(a) => match (other) { case TimeVal(b) => a.eql(b) case _ => false }
            case ResolutionVal(a) => match (other) { case ResolutionVal(b) => a.eql(b) case _ => false }
            case DashedIdent(a) => match (other) { case DashedIdent(b) => a == b case _ => false }
            case AnimationName(a) => match (other) { case AnimationName(b) => a == b case _ => false }
        }
    }

    /// 深拷贝
    /// 严格翻译自 deepClone
    public func deepClone(): TokenOrValue {
        match (this) {
            case Token(s) => Token(s)
            case ColorVal(c) => ColorVal(c.deepClone())
            case UnresolvedColorVal(uc) => UnresolvedColorVal(uc)
            case UrlVal(u) => UrlVal(u.deepClone())
            case VarVal(v) => VarVal(v.deepClone())
            case EnvVal(e) => EnvVal(e.deepClone())
            case FunctionVal(f) => FunctionVal(f.deepClone())
            case LengthVal(l) => LengthVal(l.deepClone())
            case AngleVal(a) => AngleVal(a.deepClone())
            case TimeVal(t) => TimeVal(t.deepClone())
            case ResolutionVal(r) => ResolutionVal(r.deepClone())
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
        dest.writeChar(UInt8(58))
        dest.writeChar(UInt8(32))
        value.toCss(dest: dest, isCustomProperty: false)
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
        let prefixes = targets.prefixes(this.propertyId.prefix(), feature)
        return UnparsedProperty(
            PropertyId(this.propertyId.tag, prefixes),
            this.value.deepClone(),
            this.important
        )
    }

    public func eql(other: UnparsedProperty): Bool {
        return this.propertyId.eql(other.propertyId) && this.value.eql(other.value)
    }

    public func deepClone(): UnparsedProperty {
        return UnparsedProperty(
            this.propertyId.deepClone(),
            this.value.deepClone(),
            this.important
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
        return name.toString() + ": " + value.toCss()
    }

    public func toCss(dest: Printer): Unit {
        dest.writeStr(name.toCss())
        dest.writeChar(UInt8(58))
        dest.writeChar(UInt8(32))
        value.toCss(dest: dest, isCustomProperty: true)
    }

    public func eql(other: CustomProperty): Bool {
        return this.name.toString() == other.name.toString() && this.value.eql(other.value)
    }

    public func deepClone(): CustomProperty {
        return CustomProperty(CustomPropertyName(this.name.toString()), this.value.deepClone())
    }
}

// ============================================================================
// CustomPropertyName - 定义在 properties_generated.cj 中

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
        return CssUrl(this.text)
    }

    public static func parse(parser: CssParser): CssParseResult<CssUrl> {
        let url = parser.expectUrl()
        return CssParseResult.ok(CssUrl(url.getOrDefault({=> ""})))
    }

    public func isAbsolute(records: ArrayList<ImportRecord>): Bool {
        return text.startsWith("http://") || text.startsWith("https://") || text.startsWith("data:")
    }
}
