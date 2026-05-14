// TypeScript 解析器扩展
// 严格翻译自: src/js_parser/p.ts.zig
//   Bun 的 TypeScript 解析器扩展了基础 Parser，添加了完整的类型解析能力
//   包括: 类型表达式解析, 接口/枚举/命名空间声明, 类型检查辅助
//   约 5000 行 Zig，仓颉使用独立工具类实现
package bao_parser

import bao_core.*
import bao_collections.*

// ============================================================================
// TokenStream - 词法单元流
// 严格翻译自: src/js_parser/p.ts.zig 中 Parser 的 token 消费方法
//   提供 Token 级别的前瞻、消费、匹配操作
//   作为 TSParser 和主 Parser 之间的抽象层
// ============================================================================

/// 词法单元流 - 包装 Token 数组提供游标访问
/// 对应 Bun Parser 中直接操作 lexer 的 token 序列
public class TokenStream {
    /// Token 序列 - 对应 Bun Lexer 产生的 token 流
    public var tokens: ArrayList<Token>
    /// Token 字符串值 - 对应 Bun Lexer 的 identifier/stringLiteral
    public var tokenStrings: ArrayList<String>
    /// Token 位置 - 对应 Bun Lexer 的 loc
    public var tokenLocs: ArrayList<Loc>
    /// 当前位置游标
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

    /// 当前 Token - 对应 Bun Lexer.token
    public func current(): Token {
        if (pos < tokens.size) {
            return tokens[pos]
        }
        return Token.EndOfFile
    }

    /// 当前 Token 字符串 - 对应 Bun Lexer.identifier / stringLiteral
    public func currentString(): String {
        if (pos < tokenStrings.size) {
            return tokenStrings[pos]
        }
        return ""
    }

    /// 当前 Token 位置 - 对应 Bun Lexer.loc
    public func currentLoc(): Loc {
        if (pos < tokenLocs.size) {
            return tokenLocs[pos]
        }
        return Loc.EMPTY
    }

    /// 前进一步 - 对应 Bun Lexer.next()
    public func advance(): Unit {
        pos += 1
    }

    /// 期望指定 Token - 对应 Bun p.expect()
    /// 如果匹配则消费并返回 true，否则返回 false
    public func expect(token: Token): Bool {
        if (current() == token) {
            advance()
            return true
        }
        return false
    }

    /// 匹配但不消费 - 对应 Bun p.peek() == token
    public func match(token: Token): Bool {
        return current() == token
    }

    /// 看下一个 Token - 对应 Bun Lexer.lookahead
    public func peek(): Token {
        let next = pos + 1
        if (next < tokens.size) {
            return tokens[next]
        }
        return Token.EndOfFile
    }

    /// 消费匹配的 Token - 对应 Bun p.eat()
    /// 如果当前 Token 匹配则消费并返回 true
    public func eat(token: Token): Bool {
        if (current() == token) {
            advance()
            return true
        }
        return false
    }

    /// 前看 n 步 - 对应 Bun Lexer.lookahead(n)
    public func lookahead(n: Int64): Token {
        let idx = pos + n
        if (idx >= 0 && idx < tokens.size) {
            return tokens[idx]
        }
        return Token.EndOfFile
    }

    /// 是否已到达末尾 - 对应 Bun Lexer.isEOF()
    public func isEof(): Bool {
        return pos >= tokens.size || current() == Token.EndOfFile
    }
}

// ============================================================================
// TSParser - TypeScript 类型解析工具
// 严格翻译自: src/js_parser/p.ts.zig
//   Bun 中 TypeScript 解析作为 Parser 的 comptime 扩展
//   仓颉实现为独立工具类，提供静态解析方法
//   主 Parser 通过组合方式调用这些方法
// ============================================================================

/// TypeScript 类型解析工具 - 对应 Bun p.ts.* 系列方法
/// 不继承 Parser，而是提供可以被任何解析器调用的静态工具方法
public class TSParser {

    // =========================================================================
    // 类型表达式解析
    // 严格翻译自: src/js_parser/p.ts.zig:parseType
    //   pub fn parseType(self: *Self) !TSType { ... }
    //   入口: 解析一个完整的类型表达式
    // =========================================================================

    /// 解析类型表达式 - 对应 Bun p.parseType()
    /// 处理联合类型和条件类型（优先级最低）
    public static func parseType(loc: Loc, tokens: TokenStream): TSType {
        // 解析交叉类型 (比联合类型优先级高)
        var type_ = parseIntersectionTypeOrHigher(loc, tokens)

        // 处理联合类型: A | B | C
        if (tokens.match(Token.Bar)) {
            let types = ArrayList<TSType>()
            types.append(type_)
            while (tokens.eat(Token.Bar)) {
                types.append(parseIntersectionTypeOrHigher(tokens.currentLoc(), tokens))
            }
            return TSType.union(loc, types)
        }

        return type_
    }

    /// 带前缀的类型解析 - 处理 keyof/readonly/unique/infer 前缀
    public static func parseTypeWithPrefix(loc: Loc, tokens: TokenStream, prefix: String): TSType {
        let inner = parseType(loc, tokens)
        match (prefix) {
            case "keyof" =>
                return TSType.typeOperator(loc, TSTypeOperatorKind.Keyof, inner)
            case "readonly" =>
                return TSType.typeOperator(loc, TSTypeOperatorKind.Readonly, inner)
            case "unique" =>
                return TSType.typeOperator(loc, TSTypeOperatorKind.Unique, inner)
            case "infer" =>
                // infer T 在条件类型中使用，返回类型引用
                return inner
            case _ =>
                return inner
        }
    }

    /// 解析交叉类型或更高优先级 - 对应 Bun p.parseIntersectionTypeOrHigher()
    private static func parseIntersectionTypeOrHigher(loc: Loc, tokens: TokenStream): TSType {
        var type_ = parsePostfixTypeOrHigher(tokens.currentLoc(), tokens)

        // 处理交叉类型: A & B & C
        if (tokens.match(Token.Ampersand)) {
            let types = ArrayList<TSType>()
            types.append(type_)
            while (tokens.eat(Token.Ampersand)) {
                types.append(parsePostfixTypeOrHigher(tokens.currentLoc(), tokens))
            }
            return TSType.intersection(loc, types)
        }

        return type_
    }

    /// 解析联合类型 - 对应 Bun TSUnion 构造
    public static func parseUnionType(loc: Loc, types: ArrayList<TSType>): TSType {
        if (types.size == 1) {
            return types[0]
        }
        return TSType.union(loc, types)
    }

    /// 解析交叉类型 - 对应 Bun TSIntersection 构造
    public static func parseIntersectionType(loc: Loc, types: ArrayList<TSType>): TSType {
        if (types.size == 1) {
            return types[0]
        }
        return TSType.intersection(loc, types)
    }

    /// 解析条件类型剩余部分 - 对应 Bun p.parseConditionalTypeRest()
    /// checkType extends extendsType ? trueType : falseType
    public static func parseConditionalTypeRest(loc: Loc, checkType: TSType, tokens: TokenStream): TSType {
        // 消费 extends
        tokens.advance()

        let extendsType = parseType(tokens.currentLoc(), tokens)

        // 期望 ?
        tokens.expect(Token.Question)

        let trueType = parseType(tokens.currentLoc(), tokens)

        // 期望 :
        tokens.expect(Token.Colon)

        let falseType = parseType(tokens.currentLoc(), tokens)

        return TSType.conditional(loc, checkType, extendsType, trueType, falseType)
    }

    /// 解析后缀类型 - 对应 Bun p.parsePostfixType()
    /// 处理数组后缀 T[] 和非空断言 T!
    private static func parsePostfixTypeOrHigher(loc: Loc, tokens: TokenStream): TSType {
        var type_ = parseNonArrayType(tokens.currentLoc(), tokens)

        // 处理 T[]
        while (tokens.match(Token.OpenBracket) && tokens.peek() == Token.CloseBracket) {
            tokens.advance() // [
            tokens.advance() // ]
            type_ = TSType.array(type_.loc, type_)
        }

        // 处理 T! (非空)
        if (tokens.match(Token.Exclamation)) {
            tokens.advance()
        }

        return type_
    }

    /// 解析后缀类型 (公开接口)
    public static func parsePostfixType(loc: Loc, tokens: TokenStream): TSType {
        return parsePostfixTypeOrHigher(loc, tokens)
    }

    /// 解析非数组类型 - 对应 Bun p.parseNonArrayType()
    /// 处理: 关键字类型, 引用类型, 函数类型, 构造器类型,
    ///       类型字面量, 元组类型, 模板字面量类型, typeof, import, this
    public static func parseNonArrayType(loc: Loc, tokens: TokenStream): TSType {
        let tok = tokens.current()
        let str = tokens.currentString()

        // 关键字类型
        if (tok == Token.Identifier) {
            let keywordType = parseKeywordType(loc, str)
            match (keywordType) {
                case Some(t) =>
                    tokens.advance()
                    return t
                case None => ()
            }

            // 特殊关键字: keyof, readonly, unique, infer
            if (str == "keyof" || str == "readonly" || str == "unique" || str == "infer") {
                tokens.advance()
                return parseTypeWithPrefix(loc, tokens, str)
            }

            // 类型引用: T, Foo<T>, A.B
            tokens.advance()
            return parseTypeReference(loc, str, tokens)
        }

        // 圆括号类型: (Type) 或函数类型 (params) => ReturnType
        if (tok == Token.OpenParen) {
            return parseParenthesizedType(loc, tokens)
        }

        // 元组类型: [string, number]
        if (tok == Token.OpenBracket) {
            return parseTupleType(loc, tokens)
        }

        // 模板字面量类型: `hello ${string}`
        if (tok == Token.NoSubstitutionTemplateLiteral || tok == Token.TemplateHead) {
            return parseTemplateLiteralType(loc, tokens)
        }

        // typeof 类型查询
        if (tok == Token.Typeof) {
            return parseTypeQuery(loc, tokens)
        }

        // import 类型
        if (tok == Token.Import) {
            return parseImportType(loc, tokens)
        }

        // this 类型
        if (tok == Token.This) {
            tokens.advance()
            return TSType.this_(loc)
        }

        // null / true / false 字面量类型
        if (tok == Token.Null) {
            tokens.advance()
            return TSType.null_(loc)
        }
        if (tok == Token.True) {
            tokens.advance()
            let t = TSType(loc, TSTypeTag.TSLiteral)
            t.boolValue = true
            return t
        }
        if (tok == Token.False) {
            tokens.advance()
            let t = TSType(loc, TSTypeTag.TSLiteral)
            t.boolValue = false
            return t
        }

        // 字符串字面量类型
        if (tok == Token.StringLiteral) {
            tokens.advance()
            let t = TSType(loc, TSTypeTag.TSLiteral)
            t.stringValue = str
            return t
        }

        // 数字字面量类型
        if (tok == Token.NumericLiteral) {
            tokens.advance()
            let t = TSType(loc, TSTypeTag.TSLiteral)
            t.numberValue = Float64.parse(str).getOr(0.0)
            return t
        }

        // void 关键字
        if (tok == Token.Void) {
            tokens.advance()
            return TSType.void_(loc)
        }

        // new (构造器类型)
        if (tok == Token.New) {
            return parseConstructorTypeFromTokens(loc, tokens)
        }

        // ... (rest 类型)
        if (tok == Token.DotDotDot) {
            tokens.advance()
            let inner = parseType(tokens.currentLoc(), tokens)
            return TSType.rest(loc, inner)
        }

        // 缺失/未知 - 返回 any 作为回退
        return TSType.any(loc)
    }

    /// 解析圆括号类型 - 对应 Bun p.parseParenthesizedType()
    /// 可能是: (Type) 或 (params) => ReturnType 或 new (params) => ReturnType
    public static func parseParenthesizedType(loc: Loc, tokens: TokenStream): TSType {
        tokens.expect(Token.OpenParen)

        // 尝试检测是否为函数类型: (params) => ReturnType
        // 简单回退: 如果紧跟 ) 或包含 : 则可能是函数类型
        let params = ArrayList<TSFnParam>()
        var isFunctionType = false

        // 检测函数类型: ( ... ) => ...
        // 简单启发式: 扫描到匹配 ) 看是否有 =>
        let savedPos = tokens.pos
        var depth = 1
        var foundArrow = false
        while (tokens.pos < tokens.tokens.size && depth > 0) {
            let t = tokens.current()
            if (t == Token.OpenParen) {
                depth += 1
            } else if (t == Token.CloseParen) {
                depth -= 1
            } else if (t == Token.EqualsGreaterThan && depth == 1) {
                foundArrow = true
                break
            }
            tokens.advance()
        }
        tokens.pos = savedPos

        if (foundArrow) {
            // 函数类型: (params) => ReturnType
            return parseFunctionTypeFromParams(loc, tokens)
        }

        // 简单圆括号类型: (Type)
        let inner = parseType(tokens.currentLoc(), tokens)
        tokens.expect(Token.CloseParen)

        return TSType.parenthesized(loc, inner)
    }

    // =========================================================================
    // 关键字类型解析
    // 严格翻译自: src/js_parser/p.ts.zig 中关键字类型判断
    //   Bun 使用 comptime 查找表，仓颉使用条件分支
    // =========================================================================

    /// 解析关键字类型 - 对应 Bun TSType 关键字映射
    /// 返回对应的 TSType，如果不是类型关键字则返回 None
    public static func parseKeywordType(loc: Loc, keyword: String): ?TSType {
        match (keyword) {
            case "any" => Some(TSType.any(loc))
            case "unknown" => Some(TSType.unknown(loc))
            case "number" => Some(TSType.number(loc))
            case "string" => Some(TSType.string(loc))
            case "boolean" => Some(TSType.boolean(loc))
            case "undefined" => Some(TSType.undefined(loc))
            case "null" => Some(TSType.null_(loc))
            case "never" => Some(TSType.never(loc))
            case "object" => Some(TSType.object_(loc))
            case "symbol" => Some(TSType.symbol(loc))
            case "bigint" => Some(TSType.bigInt(loc))
            case "void" => Some(TSType.void_(loc))
            case _ => None
        }
    }

    /// 是否为类型关键字 - 对应 Bun isTypeKeyword()
    public static func isTypeKeyword(keyword: String): Bool {
        match (keyword) {
            case "any" | "unknown" | "number" | "string" | "boolean" |
                 "undefined" | "null" | "never" | "object" | "symbol" |
                 "bigint" | "void" => true
            case _ => false
        }
    }

    // =========================================================================
    // 类型引用解析
    // 严格翻译自: src/js_parser/p.ts.zig:parseTypeReference
    //   T, Foo<T>, A.B<T>, A.B.C
    // =========================================================================

    /// 解析类型引用 - 对应 Bun p.parseTypeReference()
    public static func parseTypeReference(loc: Loc, name: String, tokens: TokenStream): TSType {
        var currentName = name
        var typeArgs = ArrayList<TSType>()

        // 处理限定名称: A.B.C
        while (tokens.match(Token.Dot)) {
            tokens.advance() // .
            let nextName = tokens.currentString()
            tokens.advance()
            currentName = currentName + "." + nextName
        }

        // 处理类型参数: <T, U>
        if (tokens.match(Token.LessThan)) {
            typeArgs = parseTypeArguments(tokens)
        }

        return TSType.reference(loc, currentName, typeArgs)
    }

    // =========================================================================
    // 类型参数解析
    // 严格翻译自: src/js_parser/p.ts.zig:parseTypeParameters
    //   <T, T extends U, T = V>
    // =========================================================================

    /// 解析类型参数声明 - 对应 Bun p.parseTypeParameters()
    /// <T, T extends U, T extends U = V>
    public static func parseTypeParameters(tokens: TokenStream): ArrayList<TSTypeParameterDecl> {
        let params = ArrayList<TSTypeParameterDecl>()
        if (!tokens.eat(Token.LessThan)) {
            return params
        }

        while (!tokens.match(Token.GreaterThan) && !tokens.isEof()) {
            let param = parseTypeParameter(tokens)
            params.append(param)
            if (!tokens.eat(Token.Comma)) {
                break
            }
        }

        tokens.expect(Token.GreaterThan)
        return params
    }

    /// 解析单个类型参数 - 对应 Bun p.parseTypeParameter()
    /// T, T extends U, T extends U = V
    public static func parseTypeParameter(tokens: TokenStream): TSTypeParameterDecl {
        let loc = tokens.currentLoc()
        let name = tokens.currentString()
        tokens.advance() // identifier

        var constraint: ?TSType = None
        var default_: ?TSType = None

        // extends U
        if (tokens.currentString() == "extends") {
            tokens.advance()
            constraint = Some(parseType(tokens.currentLoc(), tokens))
        }

        // = V (默认类型)
        if (tokens.eat(Token.Equals)) {
            default_ = Some(parseType(tokens.currentLoc(), tokens))
        }

        return TSTypeParameterDecl(loc, name, constraint, default_)
    }

    /// 解析类型实参 - 对应 Bun p.parseTypeArguments()
    /// <T, U, V>
    public static func parseTypeArguments(tokens: TokenStream): ArrayList<TSType> {
        let args = ArrayList<TSType>()
        if (!tokens.eat(Token.LessThan)) {
            return args
        }

        while (!tokens.match(Token.GreaterThan) && !tokens.isEof()) {
            args.append(parseType(tokens.currentLoc(), tokens))
            if (!tokens.eat(Token.Comma)) {
                break
            }
        }

        tokens.expect(Token.GreaterThan)
        return args
    }

    // =========================================================================
    // 函数/构造器类型解析
    // 严格翻译自: src/js_parser/p.ts.zig 中函数类型解析
    //   (params) => ReturnType
    //   new (params) => ReturnType
    // =========================================================================

    /// 解析函数类型 - 对应 Bun p.parseFunctionType()
    public static func parseFunctionType(loc: Loc, params: ArrayList<TSFnParam>, tokens: TokenStream): TSType {
        // 消费 =>
        tokens.expect(Token.EqualsGreaterThan)

        let returnType = parseType(tokens.currentLoc(), tokens)

        return TSType.function(loc, params, returnType, ArrayList<TSTypeParameterDecl>())
    }

    /// 从 token 流解析函数类型 - 包含参数解析
    private static func parseFunctionTypeFromParams(loc: Loc, tokens: TokenStream): TSType {
        let params = ArrayList<TSFnParam>()
        tokens.expect(Token.OpenParen)

        while (!tokens.match(Token.CloseParen) && !tokens.isEof()) {
            params.append(parseFnParamType(tokens))
            if (!tokens.eat(Token.Comma)) {
                break
            }
        }
        tokens.expect(Token.CloseParen)

        // =>
        tokens.expect(Token.EqualsGreaterThan)

        let returnType = parseType(tokens.currentLoc(), tokens)
        return TSType.function(loc, params, returnType, ArrayList<TSTypeParameterDecl>())
    }

    /// 解析构造器类型 - 对应 Bun p.parseConstructorType()
    public static func parseConstructorType(loc: Loc, params: ArrayList<TSFnParam>, tokens: TokenStream): TSType {
        // 消费 =>
        tokens.expect(Token.EqualsGreaterThan)

        let returnType = parseType(tokens.currentLoc(), tokens)
        return TSType.constructor(loc, params, returnType)
    }

    /// 从 token 流解析构造器类型 - new (params) => ReturnType
    private static func parseConstructorTypeFromTokens(loc: Loc, tokens: TokenStream): TSType {
        tokens.advance() // new

        let params = ArrayList<TSFnParam>()
        tokens.expect(Token.OpenParen)

        while (!tokens.match(Token.CloseParen) && !tokens.isEof()) {
            params.append(parseFnParamType(tokens))
            if (!tokens.eat(Token.Comma)) {
                break
            }
        }
        tokens.expect(Token.CloseParen)

        // =>
        tokens.expect(Token.EqualsGreaterThan)

        let returnType = parseType(tokens.currentLoc(), tokens)
        return TSType.constructor(loc, params, returnType)
    }

    // =========================================================================
    // 对象类型字面量解析
    // 严格翻译自: src/js_parser/p.ts.zig:parseTypeLiteral
    //   { prop: Type; method(): Type; [key: string]: Type; ... }
    // =========================================================================

    /// 解析类型字面量 - 对应 Bun p.parseTypeLiteral()
    public static func parseTypeLiteral(loc: Loc, tokens: TokenStream): TSType {
        let members = ArrayList<TSTypeElement>()
        tokens.expect(Token.OpenBrace)

        while (!tokens.match(Token.CloseBrace) && !tokens.isEof()) {
            members.append(parseTypeElement(tokens))
            // 分号或逗号分隔
            if (!tokens.eat(Token.Semicolon) && !tokens.eat(Token.Comma)) {
                if (tokens.match(Token.CloseBrace)) {
                    break
                }
            }
        }

        tokens.expect(Token.CloseBrace)
        return TSType.typeLiteral(loc, members)
    }

    /// 解析类型元素 - 对应 Bun p.parseTypeElement()
    /// 分发到具体的成员解析方法
    public static func parseTypeElement(tokens: TokenStream): TSTypeElement {
        let loc = tokens.currentLoc()

        // 检测成员类型
        let tok = tokens.current()
        let str = tokens.currentString()

        // call signature: (params) => Type
        if (tok == Token.OpenParen) {
            return parseCallSignature(tokens)
        }

        // construct signature: new (params) => Type
        if (tok == Token.New && tokens.peek() == Token.OpenParen) {
            return parseConstructSignature(tokens)
        }

        // get/set accessor
        if (tok == Token.Identifier && str == "get") {
            tokens.advance()
            return parseGetSetAccessor(tokens, true)
        }
        if (tok == Token.Identifier && str == "set") {
            tokens.advance()
            return parseGetSetAccessor(tokens, false)
        }

        // index signature: [key: string]: Type
        if (tok == Token.OpenBracket) {
            return parseIndexSignature(tokens)
        }

        // method signature 或 property signature
        let name = tokens.currentString()
        tokens.advance()

        // method signature: name(params): Type
        if (tokens.match(Token.OpenParen) || tokens.match(Token.LessThan)) {
            // 回退名称位置，交给 method signature 解析
            tokens.pos -= 1
            return parseMethodSignature(tokens)
        }

        // property signature: name: Type 或 name?: Type
        return parsePropertySignatureWithName(tokens, name)
    }

    /// 解析属性签名 - 对应 Bun p.parsePropertySignature()
    public static func parsePropertySignature(tokens: TokenStream): TSTypeElement {
        let name = tokens.currentString()
        tokens.advance()
        return parsePropertySignatureWithName(tokens, name)
    }

    /// 解析属性签名 (已知名称) - 内部辅助
    private static func parsePropertySignatureWithName(tokens: TokenStream, name: String): TSTypeElement {
        let loc = tokens.currentLoc()
        let elem = TSTypeElement(loc, TSTypeElementTag.PropertySignature)
        elem.name = name

        // 可选: ?
        if (tokens.eat(Token.Question)) {
            elem.isOptional = true
        }

        // 类型注解: : Type
        if (tokens.eat(Token.Colon)) {
            elem.type_ = Some(parseType(tokens.currentLoc(), tokens))
        }

        return elem
    }

    /// 解析方法签名 - 对应 Bun p.parseMethodSignature()
    public static func parseMethodSignature(tokens: TokenStream): TSTypeElement {
        let loc = tokens.currentLoc()
        let elem = TSTypeElement(loc, TSTypeElementTag.MethodSignature)
        elem.name = tokens.currentString()
        tokens.advance()

        // 可选: ?
        if (tokens.eat(Token.Question)) {
            elem.isOptional = true
        }

        // 类型参数: <T, U>
        if (tokens.match(Token.LessThan)) {
            elem.typeParams = parseTypeParameters(tokens)
        }

        // 参数: (params)
        tokens.expect(Token.OpenParen)
        while (!tokens.match(Token.CloseParen) && !tokens.isEof()) {
            elem.params.append(parseFnParamType(tokens))
            if (!tokens.eat(Token.Comma)) {
                break
            }
        }
        tokens.expect(Token.CloseParen)

        // 返回类型: : Type
        if (tokens.eat(Token.Colon)) {
            elem.returnType = Some(parseType(tokens.currentLoc(), tokens))
        }

        return elem
    }

    /// 解析索引签名 - 对应 Bun p.parseIndexSignature()
    /// [key: string]: Type 或 [key: string, ...]: Type
    public static func parseIndexSignature(tokens: TokenStream): TSTypeElement {
        let loc = tokens.currentLoc()
        let elem = TSTypeElement(loc, TSTypeElementTag.IndexSignature)

        tokens.expect(Token.OpenBracket)

        // 索引参数名
        elem.name = tokens.currentString()
        tokens.advance()

        // : Type (索引类型)
        tokens.expect(Token.Colon)
        let indexType = parseType(tokens.currentLoc(), tokens)

        tokens.expect(Token.CloseBracket)

        // : Type (值类型)
        if (tokens.eat(Token.Colon)) {
            elem.type_ = Some(parseType(tokens.currentLoc(), tokens))
        }

        return elem
    }

    /// 解析调用签名 - 对应 Bun p.parseCallSignature()
    /// (params): Type
    public static func parseCallSignature(tokens: TokenStream): TSTypeElement {
        let loc = tokens.currentLoc()
        let elem = TSTypeElement(loc, TSTypeElementTag.CallSignature)

        // 类型参数: <T, U>
        if (tokens.match(Token.LessThan)) {
            elem.typeParams = parseTypeParameters(tokens)
        }

        // 参数: (params)
        tokens.expect(Token.OpenParen)
        while (!tokens.match(Token.CloseParen) && !tokens.isEof()) {
            elem.params.append(parseFnParamType(tokens))
            if (!tokens.eat(Token.Comma)) {
                break
            }
        }
        tokens.expect(Token.CloseParen)

        // 返回类型: : Type
        if (tokens.eat(Token.Colon)) {
            elem.returnType = Some(parseType(tokens.currentLoc(), tokens))
        }

        return elem
    }

    /// 解析构造签名 - 对应 Bun p.parseConstructSignature()
    /// new (params): Type
    public static func parseConstructSignature(tokens: TokenStream): TSTypeElement {
        let loc = tokens.currentLoc()
        let elem = TSTypeElement(loc, TSTypeElementTag.ConstructSignature)

        tokens.advance() // new

        // 类型参数: <T, U>
        if (tokens.match(Token.LessThan)) {
            elem.typeParams = parseTypeParameters(tokens)
        }

        // 参数: (params)
        tokens.expect(Token.OpenParen)
        while (!tokens.match(Token.CloseParen) && !tokens.isEof()) {
            elem.params.append(parseFnParamType(tokens))
            if (!tokens.eat(Token.Comma)) {
                break
            }
        }
        tokens.expect(Token.CloseParen)

        // 返回类型: : Type
        if (tokens.eat(Token.Colon)) {
            elem.returnType = Some(parseType(tokens.currentLoc(), tokens))
        }

        return elem
    }

    /// 解析 get/set 访问器签名 - 对应 Bun p.parseGetSetAccessor()
    public static func parseGetSetAccessor(tokens: TokenStream, isGet: Bool): TSTypeElement {
        let loc = tokens.currentLoc()
        let elem = TSTypeElement(loc, if (isGet) {
            TSTypeElementTag.GetAccessor
        } else {
            TSTypeElementTag.SetAccessor
        })

        elem.name = tokens.currentString()
        tokens.advance()

        // 参数: (params)
        tokens.expect(Token.OpenParen)
        while (!tokens.match(Token.CloseParen) && !tokens.isEof()) {
            elem.params.append(parseFnParamType(tokens))
            if (!tokens.eat(Token.Comma)) {
                break
            }
        }
        tokens.expect(Token.CloseParen)

        // 返回类型 (get): : Type
        if (tokens.eat(Token.Colon)) {
            elem.returnType = Some(parseType(tokens.currentLoc(), tokens))
        }

        return elem
    }

    // =========================================================================
    // 元组类型解析
    // 严格翻译自: src/js_parser/p.ts.zig:parseTupleType
    //   [string, number, ...T]
    // =========================================================================

    /// 解析元组类型 - 对应 Bun p.parseTupleType()
    public static func parseTupleType(loc: Loc, tokens: TokenStream): TSType {
        let elements = ArrayList<TSType>()
        tokens.expect(Token.OpenBracket)

        while (!tokens.match(Token.CloseBracket) && !tokens.isEof()) {
            // rest 元素: ...T
            if (tokens.eat(Token.DotDotDot)) {
                let inner = parseType(tokens.currentLoc(), tokens)
                elements.append(TSType.rest(loc, inner))
            } else {
                // 可选元素: name? 或普通类型
                elements.append(parseType(tokens.currentLoc(), tokens))
            }

            if (!tokens.eat(Token.Comma)) {
                break
            }
        }

        tokens.expect(Token.CloseBracket)
        return TSType.tuple(loc, elements)
    }

    // =========================================================================
    // 模板字面量类型解析
    // 严格翻译自: src/js_parser/p.ts.zig:parseTemplateLiteralType
    //   `hello ${string}`
    // =========================================================================

    /// 解析模板字面量类型 - 对应 Bun p.parseTemplateLiteralType()
    public static func parseTemplateLiteralType(loc: Loc, tokens: TokenStream): TSType {
        let parts = ArrayList<TSTemplateLiteralPart>()
        let tok = tokens.current()

        if (tok == Token.NoSubstitutionTemplateLiteral) {
            parts.append(TSTemplateLiteralPart(tokens.currentString()))
            tokens.advance()
            return TSType.templateLiteral(loc, parts)
        }

        // TemplateHead ... TemplateMiddle ... TemplateTail
        // 简化处理: 收集文本和表达式部分
        parts.append(TSTemplateLiteralPart(tokens.currentString()))
        tokens.advance() // template head

        while (true) {
            // 解析表达式类型
            let type_ = parseType(tokens.currentLoc(), tokens)
            parts.append(TSTemplateLiteralPart(type_))

            let next = tokens.current()
            if (next == Token.TemplateTail) {
                parts.append(TSTemplateLiteralPart(tokens.currentString()))
                tokens.advance()
                break
            } else if (next == Token.TemplateMiddle) {
                parts.append(TSTemplateLiteralPart(tokens.currentString()))
                tokens.advance()
            } else {
                break
            }
        }

        return TSType.templateLiteral(loc, parts)
    }

    // =========================================================================
    // 映射类型解析
    // 严格翻译自: src/js_parser/p.ts.zig:parseMappedType
    //   { [K in keyof T]: V }
    //   { -readonly [K in keyof T]?: V }
    // =========================================================================

    /// 解析映射类型 - 对应 Bun p.parseMappedType()
    public static func parseMappedType(loc: Loc, tokens: TokenStream): TSType {
        var readonly = TSReadonlyModifier.None
        var optional = TSOptionalModifier.None

        tokens.expect(Token.OpenBrace)

        // readonly 修饰符: readonly / +readonly / -readonly
        if (tokens.currentString() == "readonly") {
            readonly = TSReadonlyModifier.Readonly
            tokens.advance()
            if (tokens.eat(Token.Plus)) {
                readonly = TSReadonlyModifier.Readonly
            } else if (tokens.eat(Token.Minus)) {
                readonly = TSReadonlyModifier.Mutable
            }
        }

        tokens.expect(Token.OpenBracket)

        // 类型参数名
        let paramName = tokens.currentString()
        tokens.advance()

        // in 关键字
        var isIn = false
        if (tokens.currentString() == "in") {
            isIn = true
            tokens.advance()
        }

        // 约束类型
        var constraint: ?TSType = None
        if (isIn) {
            constraint = Some(parseType(tokens.currentLoc(), tokens))
        }

        let typeParam = TSTypeParameterDecl(loc, paramName, constraint, None)
        typeParam.isIn = isIn

        tokens.expect(Token.CloseBracket)

        // 可选修饰符: ? / +? / -?
        if (tokens.match(Token.Question)) {
            optional = TSOptionalModifier.Optional
            tokens.advance()
        } else if (tokens.match(Token.Plus) && tokens.peek() == Token.Question) {
            optional = TSOptionalModifier.Optional
            tokens.advance() // +
            tokens.advance() // ?
        } else if (tokens.match(Token.Minus) && tokens.peek() == Token.Question) {
            optional = TSOptionalModifier.Required
            tokens.advance() // -
            tokens.advance() // ?
        }

        // 结果类型: : Type
        var resultType: ?TSType = None
        if (tokens.eat(Token.Colon)) {
            resultType = Some(parseType(tokens.currentLoc(), tokens))
        }

        tokens.expect(Token.CloseBrace)

        return TSType.mapped(loc, typeParam, readonly, optional, resultType)
    }

    // =========================================================================
    // 类型查询 (typeof) 解析
    // 严格翻译自: src/js_parser/p.ts.zig:parseTypeQuery
    //   typeof x, typeof x.y, typeof import("module")
    // =========================================================================

    /// 解析类型查询 - 对应 Bun p.parseTypeQuery()
    public static func parseTypeQuery(loc: Loc, tokens: TokenStream): TSType {
        tokens.advance() // typeof

        var name = tokens.currentString()
        tokens.advance()

        // 限定名称: x.y.z
        while (tokens.match(Token.Dot)) {
            tokens.advance()
            name = name + "." + tokens.currentString()
            tokens.advance()
        }

        let expr = Expr.identifier(loc, name)
        return TSType.typeQuery(loc, expr)
    }

    // =========================================================================
    // 导入类型解析
    // 严格翻译自: src/js_parser/p.ts.zig:parseImportType
    //   import("module").Type
    // =========================================================================

    /// 解析导入类型 - 对应 Bun p.parseImportType()
    public static func parseImportType(loc: Loc, tokens: TokenStream): TSType {
        tokens.advance() // import
        tokens.expect(Token.OpenParen)

        let path = tokens.currentString()
        tokens.advance() // string literal

        tokens.expect(Token.CloseParen)

        var qualifier = ""
        // .Type 限定符
        if (tokens.eat(Token.Dot)) {
            qualifier = tokens.currentString()
            tokens.advance()

            // 嵌套限定符: .A.B
            while (tokens.match(Token.Dot)) {
                tokens.advance()
                qualifier = qualifier + "." + tokens.currentString()
                tokens.advance()
            }
        }

        return TSType.importType(loc, path, qualifier)
    }

    // =========================================================================
    // 声明解析
    // 严格翻译自: src/js_parser/p.ts.zig 中声明解析
    //   interface, enum, type alias, module, declare class/function
    // =========================================================================

    /// 解析接口声明 - 对应 Bun p.parseInterfaceDecl()
    public static func parseInterfaceDecl(loc: Loc, name: String, tokens: TokenStream): TSInterfaceDecl {
        let decl = TSInterfaceDecl(loc, name)

        // 类型参数: <T, U>
        if (tokens.match(Token.LessThan)) {
            decl.typeParams = parseTypeParameters(tokens)
        }

        // extends 子句: extends A, B
        if (tokens.currentString() == "extends") {
            tokens.advance()
            decl.extends_.append(parseType(tokens.currentLoc(), tokens))
            while (tokens.eat(Token.Comma)) {
                decl.extends_.append(parseType(tokens.currentLoc(), tokens))
            }
        }

        // 体: { members }
        tokens.expect(Token.OpenBrace)
        while (!tokens.match(Token.CloseBrace) && !tokens.isEof()) {
            decl.body.append(parseTypeElement(tokens))
            if (!tokens.eat(Token.Semicolon) && !tokens.eat(Token.Comma)) {
                if (tokens.match(Token.CloseBrace)) {
                    break
                }
            }
        }
        tokens.expect(Token.CloseBrace)

        return decl
    }

    /// 解析枚举声明 - 对应 Bun p.parseEnumDecl()
    public static func parseEnumDecl(loc: Loc, name: String, tokens: TokenStream): TSEnumDecl {
        let decl = TSEnumDecl(loc, name)

        tokens.expect(Token.OpenBrace)

        while (!tokens.match(Token.CloseBrace) && !tokens.isEof()) {
            let memberLoc = tokens.currentLoc()
            let memberName = tokens.currentString()
            let member = TSEnumMember(memberLoc, memberName)
            tokens.advance()

            // 初始值: = expr
            if (tokens.eat(Token.Equals)) {
                member.value = Some(parseEnumInitializer(tokens))
            }

            decl.members.append(member)
            if (!tokens.eat(Token.Comma)) {
                break
            }
        }

        tokens.expect(Token.CloseBrace)
        return decl
    }

    /// 解析枚举初始值表达式 (简化版)
    private static func parseEnumInitializer(tokens: TokenStream): Expr {
        let tok = tokens.current()
        let loc = tokens.currentLoc()

        if (tok == Token.NumericLiteral) {
            let val = tokens.currentString()
            tokens.advance()
            return Expr.number(loc, Float64.parse(val).getOr(0.0))
        }
        if (tok == Token.StringLiteral) {
            let val = tokens.currentString()
            tokens.advance()
            return Expr.string(loc, val)
        }
        if (tok == Token.Identifier) {
            let name = tokens.currentString()
            tokens.advance()
            return Expr.identifier(loc, name)
        }

        tokens.advance()
        return Expr.missing(loc)
    }

    /// 解析类型别名声明 - 对应 Bun p.parseTypeAliasDecl()
    public static func parseTypeAliasDecl(loc: Loc, name: String, tokens: TokenStream): TSTypeAliasDecl {
        // 类型参数: <T, U>
        let typeParams = ArrayList<TSTypeParameterDecl>()
        if (tokens.match(Token.LessThan)) {
            typeParams.appendAll(parseTypeParameters(tokens))
        }

        // = Type
        tokens.expect(Token.Equals)
        let type_ = parseType(tokens.currentLoc(), tokens)

        let decl = TSTypeAliasDecl(loc, name, type_)
        decl.typeParams = typeParams
        return decl
    }

    /// 解析命名空间/模块声明 - 对应 Bun p.parseModuleDecl()
    public static func parseModuleDecl(loc: Loc, name: String, tokens: TokenStream): TSModuleDecl {
        let decl = TSModuleDecl(loc, name)

        // 检测是否为外部模块 (引号括起的名称)
        if (name.startsWith("\"") && name.endsWith("\"")) {
            decl.isExternal = true
        }

        // 体: { ... }
        if (tokens.eat(Token.OpenBrace)) {
            while (!tokens.match(Token.CloseBrace) && !tokens.isEof()) {
                // 简化: 跳到匹配的 }
                tokens.advance()
            }
            tokens.expect(Token.CloseBrace)
        }

        return decl
    }

    /// 解析 declare class - 对应 Bun p.parseDeclareClass()
    public static func parseDeclareClass(loc: Loc, name: String, tokens: TokenStream): TSDeclare {
        let decl = TSDeclare(loc, TSDeclareTag.Class)
        decl.name = name

        // 类型参数: <T, U>
        if (tokens.match(Token.LessThan)) {
            decl.typeParams = parseTypeParameters(tokens)
        }

        // extends 和 implements 在 class 体之前
        // 简化: 直接解析体
        if (tokens.eat(Token.OpenBrace)) {
            while (!tokens.match(Token.CloseBrace) && !tokens.isEof()) {
                tokens.advance()
            }
            tokens.expect(Token.CloseBrace)
        }

        return decl
    }

    /// 解析 declare function - 对应 Bun p.parseDeclareFunction()
    public static func parseDeclareFunction(loc: Loc, name: String, tokens: TokenStream): TSDeclare {
        let decl = TSDeclare(loc, TSDeclareTag.Function)
        decl.name = name

        // 类型参数: <T, U>
        if (tokens.match(Token.LessThan)) {
            decl.typeParams = parseTypeParameters(tokens)
        }

        // 参数: (params)
        tokens.expect(Token.OpenParen)
        let params = ArrayList<TSFnParam>()
        while (!tokens.match(Token.CloseParen) && !tokens.isEof()) {
            params.append(parseFnParamType(tokens))
            if (!tokens.eat(Token.Comma)) {
                break
            }
        }
        tokens.expect(Token.CloseParen)

        // 返回类型: : Type
        if (tokens.eat(Token.Colon)) {
            decl.type_ = Some(parseType(tokens.currentLoc(), tokens))
        }

        // 创建 GFn 用于存储
        let fn = GFn(loc)
        fn.name = name
        for (p in params) {
            let arg = GArg(Binding.identifier(p.loc, p.name))
            fn.args.append(arg)
        }
        decl.fn = Some(fn)

        // 分号
        tokens.eat(Token.Semicolon)

        return decl
    }

    // =========================================================================
    // 修饰符解析
    // 严格翻译自: src/js_parser/p.ts.zig 中修饰符处理
    //   abstract, declare, override, private, protected, public,
    //   readonly, static, async, out, accessor
    // =========================================================================

    /// 解析修饰符 - 对应 Bun p.parseModifiers()
    /// 消费连续的修饰符关键字，返回修饰符集合
    public static func parseModifiers(tokens: TokenStream): TSModifiers {
        let mods = TSModifiers()

        while (tokens.current() == Token.Identifier) {
            let str = tokens.currentString()
            match (str) {
                case "abstract" =>
                    mods.isAbstract = true
                    tokens.advance()
                case "declare" =>
                    mods.isDeclare = true
                    tokens.advance()
                case "override" =>
                    mods.isOverride = true
                    tokens.advance()
                case "private" =>
                    mods.isPrivate = true
                    tokens.advance()
                case "protected" =>
                    mods.isProtected = true
                    tokens.advance()
                case "public" =>
                    mods.isPublic = true
                    tokens.advance()
                case "readonly" =>
                    mods.isReadonly = true
                    tokens.advance()
                case "static" =>
                    mods.isStatic = true
                    tokens.advance()
                case "async" =>
                    mods.isAsync = true
                    tokens.advance()
                case "out" =>
                    mods.isOut = true
                    tokens.advance()
                case "accessor" =>
                    mods.isAccessor = true
                    tokens.advance()
                case "const" =>
                    mods.isConst = true
                    tokens.advance()
                case _ =>
                    break // 不是修饰符，停止
            }
        }

        return mods
    }

    /// 解析可访问性修饰符 - 对应 Bun p.parseAccessibility()
    public static func parseAccessibility(tokens: TokenStream): TSAccessibility {
        if (tokens.currentString() == "private") {
            tokens.advance()
            return TSAccessibility.Private
        }
        if (tokens.currentString() == "protected") {
            tokens.advance()
            return TSAccessibility.Protected
        }
        if (tokens.currentString() == "public") {
            tokens.advance()
            return TSAccessibility.Public
        }
        return TSAccessibility.None
    }

    // =========================================================================
    // 类型注解与参数类型解析
    // 严格翻译自: src/js_parser/p.ts.zig 中类型注解处理
    //   : Type (类型注解)
    //   param: Type (函数参数类型)
    // =========================================================================

    /// 解析类型注解 - 对应 Bun p.parseTypeAnnotation()
    /// 消费 : 并解析后续类型，如果没有 : 返回 None
    public static func parseTypeAnnotation(tokens: TokenStream): ?TSType {
        if (tokens.eat(Token.Colon)) {
            return Some(parseType(tokens.currentLoc(), tokens))
        }
        return None
    }

    /// 解析函数参数类型 - 对应 Bun p.parseFnParamType()
    /// name?: Type 或 ...name: Type 或 name: Type = default
    public static func parseFnParamType(tokens: TokenStream): TSFnParam {
        let loc = tokens.currentLoc()
        var isRest = false

        // rest 参数: ...name
        if (tokens.eat(Token.DotDotDot)) {
            isRest = true
        }

        let name = tokens.currentString()
        tokens.advance()

        let param = TSFnParam(loc, name)
        param.isRest = isRest

        // 可选: ?
        if (tokens.eat(Token.Question)) {
            param.isOptional = true
        }

        // 类型注解: : Type
        if (tokens.eat(Token.Colon)) {
            param.type_ = Some(parseType(tokens.currentLoc(), tokens))
        }

        // 默认值: = expr
        if (tokens.eat(Token.Equals)) {
            param.initializer = Some(parseDefaultValue(tokens))
        }

        return param
    }

    /// 解析默认值表达式 (简化版)
    private static func parseDefaultValue(tokens: TokenStream): Expr {
        let tok = tokens.current()
        let loc = tokens.currentLoc()

        if (tok == Token.NumericLiteral) {
            let val = tokens.currentString()
            tokens.advance()
            return Expr.number(loc, Float64.parse(val).getOr(0.0))
        }
        if (tok == Token.StringLiteral) {
            let val = tokens.currentString()
            tokens.advance()
            return Expr.string(loc, val)
        }
        if (tok == Token.True) {
            tokens.advance()
            return Expr.bool_(loc, true)
        }
        if (tok == Token.False) {
            tokens.advance()
            return Expr.bool_(loc, false)
        }
        if (tok == Token.Null) {
            tokens.advance()
            return Expr.null_(loc)
        }
        if (tok == Token.Identifier) {
            let name = tokens.currentString()
            tokens.advance()
            return Expr.identifier(loc, name)
        }

        tokens.advance()
        return Expr.missing(loc)
    }

    // =========================================================================
    // 辅助判断方法
    // 严格翻译自: src/js_parser/p.ts.zig 中前瞻判断
    // =========================================================================

    /// 是否在类型起始位置 - 对应 Bun p.isTypeStart()
    /// 检查当前位置是否可能是类型表达式的开始
    public static func isTypeStart(tokens: TokenStream): Bool {
        let tok = tokens.current()
        let str = tokens.currentString()

        // 标识符可能是类型关键字或类型引用
        if (tok == Token.Identifier) {
            return isTypeKeyword(str) || str == "keyof" || str == "readonly" ||
                   str == "unique" || str == "infer" || str == "asserts" ||
                   str == "abstract"
        }

        // 各种类型起始 token
        match (tok) {
            case Token.OpenParen | Token.OpenBracket | Token.OpenBrace |
                 Token.Typeof | Token.Import | Token.This |
                 Token.Null | Token.Void | Token.StringLiteral |
                 Token.NumericLiteral | Token.NoSubstitutionTemplateLiteral |
                 Token.LessThan | Token.New => true
            case _ => false
        }
    }

    // =========================================================================
    // 类型到表达式转换
    // 严格翻译自: src/js_parser/p.ts.zig 中类型擦除
    //   在运行时类型信息被擦除，转换为对应表达式
    // =========================================================================

    /// 类型转表达式 - 对应 Bun typeToExpr()
    /// 将简单类型转换为对应的表达式节点
    public static func typeToExpr(type_: TSType): Expr {
        let loc = type_.loc

        match (type_.tag) {
            // 关键字类型 -> 标识符引用
            case TSTypeTag.TSAnyKeyword =>
                return Expr.identifier(loc, "any")
            case TSTypeTag.TSUnknownKeyword =>
                return Expr.identifier(loc, "unknown")
            case TSTypeTag.TSNumberKeyword =>
                return Expr.identifier(loc, "number")
            case TSTypeTag.TSStringKeyword =>
                return Expr.identifier(loc, "string")
            case TSTypeTag.TSBooleanKeyword =>
                return Expr.identifier(loc, "boolean")
            case TSTypeTag.TSVoidKeyword =>
                return Expr.identifier(loc, "void")
            case TSTypeTag.TSUndefinedKeyword =>
                return Expr.identifier(loc, "undefined")
            case TSTypeTag.TSNeverKeyword =>
                return Expr.identifier(loc, "never")
            case TSTypeTag.TSObjectKeyword =>
                return Expr.identifier(loc, "object")
            case TSTypeTag.TSSymbolKeyword =>
                return Expr.identifier(loc, "symbol")
            case TSTypeTag.TSBigIntKeyword =>
                return Expr.identifier(loc, "bigint")
            case TSTypeTag.TSNullKeyword =>
                return Expr.null_(loc)
            case TSTypeTag.TSThisType =>
                return Expr.this_(loc)
            // 类型引用 -> 标识符
            case TSTypeTag.TSReference =>
                return Expr.identifier(loc, type_.typeName)
            // 字面量类型
            case TSTypeTag.TSLiteral =>
                if (type_.stringValue != "") {
                    return Expr.string(loc, type_.stringValue)
                }
                if (type_.boolValue) {
                    return Expr.bool_(loc, true)
                }
                return Expr.number(loc, type_.numberValue)
            // 默认: any
            case _ =>
                return Expr.identifier(loc, "any")
        }
    }
}

// ============================================================================
// TSTypePrinter - TypeScript 类型打印器
// 严格翻译自: src/js_printer/js_printer.zig 中类型打印部分
//   将 TSType AST 节点转换回 TypeScript 类型文本
//   用于错误信息、声明文件生成等
// ============================================================================

/// TypeScript 类型打印器 - 对应 Bun Printer 中类型输出方法
public class TSTypePrinter {

    /// 打印类型 - 入口方法
    public static func print(type_: TSType): String {
        match (type_.tag) {
            // 关键字类型
            case TSTypeTag.TSAnyKeyword => "any"
            case TSTypeTag.TSUnknownKeyword => "unknown"
            case TSTypeTag.TSNumberKeyword => "number"
            case TSTypeTag.TSStringKeyword => "string"
            case TSTypeTag.TSBooleanKeyword => "boolean"
            case TSTypeTag.TSVoidKeyword => "void"
            case TSTypeTag.TSUndefinedKeyword => "undefined"
            case TSTypeTag.TSNullKeyword => "null"
            case TSTypeTag.TSNeverKeyword => "never"
            case TSTypeTag.TSObjectKeyword => "object"
            case TSTypeTag.TSSymbolKeyword => "symbol"
            case TSTypeTag.TSBigIntKeyword => "bigint"
            case TSTypeTag.TSThisType => "this"

            // 类型引用
            case TSTypeTag.TSReference => {
                var s = type_.typeName
                if (type_.typeParams.size > 0) {
                    s = s + printTypeArgs(type_.typeParams)
                }
                return s
            }

            // 联合类型
            case TSTypeTag.TSUnion => {
                var parts = ArrayList<String>()
                for (t in type_.types) {
                    parts.append(print(t))
                }
                return join(parts, " | ")
            }

            // 交叉类型
            case TSTypeTag.TSIntersection => {
                var parts = ArrayList<String>()
                for (t in type_.types) {
                    parts.append(print(t))
                }
                return join(parts, " & ")
            }

            // 条件类型
            case TSTypeTag.TSConditional => {
                var s = print(type_.checkType.get())
                s = s + " extends " + print(type_.extendsType.get())
                s = s + " ? " + print(type_.trueType.get())
                s = s + " : " + print(type_.falseType.get())
                return s
            }

            // 数组类型
            case TSTypeTag.TSArray => {
                let elem = type_.elementType.get()
                let elemStr = print(elem)
                // 如果元素类型是联合/交叉/条件，需要括号
                if (needsParen(elem)) {
                    return "(" + elemStr + ")[]"
                }
                return elemStr + "[]"
            }

            // 元组类型
            case TSTypeTag.TSTuple => {
                var parts = ArrayList<String>()
                for (e in type_.elements) {
                    parts.append(print(e))
                }
                return "[" + join(parts, ", ") + "]"
            }

            // 函数类型
            case TSTypeTag.TSFunction => {
                var s = "("
                var paramStrs = ArrayList<String>()
                for (p in type_.params) {
                    paramStrs.append(printFnParam(p))
                }
                s = s + join(paramStrs, ", ")
                s = s + ") => " + print(type_.returnType.get())
                return s
            }

            // 构造器类型
            case TSTypeTag.TSConstructor => {
                var s = "new ("
                var paramStrs = ArrayList<String>()
                for (p in type_.params) {
                    paramStrs.append(printFnParam(p))
                }
                s = s + join(paramStrs, ", ")
                s = s + ") => " + print(type_.returnType.get())
                return s
            }

            // 类型字面量
            case TSTypeTag.TSTypeLiteral => {
                var parts = ArrayList<String>()
                for (m in type_.members) {
                    parts.append(printTypeElement(m))
                }
                return "{ " + join(parts, "; ") + " }"
            }

            // 类型操作符
            case TSTypeTag.TSTypeOperator => {
                var op = ""
                match (type_.operator) {
                    case TSTypeOperatorKind.Keyof => op = "keyof "
                    case TSTypeOperatorKind.Readonly => op = "readonly "
                    case TSTypeOperatorKind.Unique => op = "unique "
                    case TSTypeOperatorKind.Infer => op = "infer "
                }
                return op + print(type_.operand.get())
            }

            // 类型查询
            case TSTypeTag.TSTypeQuery => {
                let expr = type_.queryExpr.get()
                return "typeof " + expr.identifierName
            }

            // 索引访问
            case TSTypeTag.TSIndexedAccess => {
                return print(type_.objectType.get()) + "[" + print(type_.indexType.get()) + "]"
            }

            // 映射类型
            case TSTypeTag.TSMapped => {
                var s = "{ "
                match (type_.mappedReadonly) {
                    case TSReadonlyModifier.Readonly => s = s + "readonly "
                    case TSReadonlyModifier.Mutable => s = s + "-readonly "
                    case TSReadonlyModifier.None => ()
                }
                let param = type_.typeParam.get()
                s = s + "[" + param.name + " in " + print(param.constraint.get()) + "]"
                match (type_.mappedOptional) {
                    case TSOptionalModifier.Optional => s = s + "?"
                    case TSOptionalModifier.Required => s = s + "-?"
                    case TSOptionalModifier.None => ()
                }
                match (type_.returnType) {
                    case Some(t) => s = s + ": " + print(t)
                    case None => ()
                }
                s = s + " }"
                return s
            }

            // 圆括号类型
            case TSTypeTag.TSParenthesized => {
                return "(" + print(type_.wrappedType.get()) + ")"
            }

            // 字面量类型
            case TSTypeTag.TSLiteral => {
                if (type_.stringValue != "") {
                    return "\"" + type_.stringValue + "\""
                }
                if (type_.boolValue) {
                    return "true"
                }
                return type_.numberValue.toString()
            }

            // 枚举名称
            case TSTypeTag.TSEnumName => type_.typeName

            // 导入类型
            case TSTypeTag.TSImport => {
                var s = "import(\"" + type_.importPath + "\")"
                if (type_.importQualifier != "") {
                    s = s + "." + type_.importQualifier
                }
                return s
            }

            // 模板字面量类型
            case TSTypeTag.TSTemplateLiteral => {
                var s = "`"
                for (part in type_.templateParts) {
                    if (part.text != "") {
                        s = s + part.text
                    }
                    match (part.type_) {
                        case Some(t) => s = s + "${" + print(t) + "}"
                        case None => ()
                    }
                }
                s = s + "`"
                return s
            }

            // 类型谓词
            case TSTypeTag.TSTypePredicate => {
                var s = ""
                if (type_.predicateIsAsserts) {
                    s = "asserts " + type_.predicateName
                } else {
                    s = type_.predicateName + " is "
                }
                match (type_.returnType) {
                    case Some(t) =>
                        if (!type_.predicateIsAsserts) {
                            s = s + print(t)
                        } else {
                            s = s + " is " + print(t)
                        }
                    case None => ()
                }
                return s
            }

            // 命名元组成员
            case TSTypeTag.TSNamedTupleMember => {
                var s = type_.typeName
                if (type_.mappedOptional == TSOptionalModifier.Optional) {
                    s = s + "?: "
                } else {
                    s = s + ": "
                }
                return s + print(type_.elementType.get())
            }

            // rest 类型
            case TSTypeTag.TSRest => {
                return "..." + print(type_.restType.get())
            }

            // optional 类型
            case TSTypeTag.TSOptional => {
                return print(type_.wrappedType.get()) + "?"
            }

            // 其他
            case _ => "any"
        }
    }

    /// 打印类型实参 - <T, U>
    private static func printTypeArgs(args: ArrayList<TSType>): String {
        var parts = ArrayList<String>()
        for (a in args) {
            parts.append(print(a))
        }
        return "<" + join(parts, ", ") + ">"
    }

    /// 打印类型元素 - 属性签名/方法签名等
    public static func printTypeElement(elem: TSTypeElement): String {
        match (elem.tag) {
            case TSTypeElementTag.PropertySignature => {
                var s = ""
                if (elem.isReadonly) { s = s + "readonly " }
                s = s + elem.name
                if (elem.isOptional) { s = s + "?" }
                match (elem.type_) {
                    case Some(t) => s = s + ": " + print(t)
                    case None => ()
                }
                return s
            }
            case TSTypeElementTag.MethodSignature => {
                var s = elem.name
                if (elem.isOptional) { s = s + "?" }
                if (elem.typeParams.size > 0) {
                    s = s + printTypeParamDecls(elem.typeParams)
                }
                var paramStrs = ArrayList<String>()
                for (p in elem.params) {
                    paramStrs.append(printFnParam(p))
                }
                s = s + "(" + join(paramStrs, ", ") + ")"
                match (elem.returnType) {
                    case Some(t) => s = s + ": " + print(t)
                    case None => ()
                }
                return s
            }
            case TSTypeElementTag.CallSignature => {
                var paramStrs = ArrayList<String>()
                for (p in elem.params) {
                    paramStrs.append(printFnParam(p))
                }
                var s = "(" + join(paramStrs, ", ") + ")"
                match (elem.returnType) {
                    case Some(t) => s = s + ": " + print(t)
                    case None => ()
                }
                return s
            }
            case TSTypeElementTag.ConstructSignature => {
                var paramStrs = ArrayList<String>()
                for (p in elem.params) {
                    paramStrs.append(printFnParam(p))
                }
                var s = "new (" + join(paramStrs, ", ") + ")"
                match (elem.returnType) {
                    case Some(t) => s = s + ": " + print(t)
                    case None => ()
                }
                return s
            }
            case TSTypeElementTag.IndexSignature => {
                var s = "[" + elem.name + ": "
                // 索引类型需要在 elementType 中
                match (elem.type_) {
                    case Some(t) => s = s + print(t)
                    case None => s = s + "string"
                }
                s = s + "]"
                return s
            }
            case TSTypeElementTag.GetAccessor => {
                var paramStrs = ArrayList<String>()
                for (p in elem.params) {
                    paramStrs.append(printFnParam(p))
                }
                var s = "get " + elem.name + "(" + join(paramStrs, ", ") + ")"
                match (elem.returnType) {
                    case Some(t) => s = s + ": " + print(t)
                    case None => ()
                }
                return s
            }
            case TSTypeElementTag.SetAccessor => {
                var paramStrs = ArrayList<String>()
                for (p in elem.params) {
                    paramStrs.append(printFnParam(p))
                }
                return "set " + elem.name + "(" + join(paramStrs, ", ") + ")"
            }
        }
    }

    /// 打印类型参数声明
    public static func printTypeParam(param: TSTypeParameterDecl): String {
        var s = param.name
        match (param.constraint) {
            case Some(t) => s = s + " extends " + print(t)
            case None => ()
        }
        match (param.default_) {
            case Some(t) => s = s + " = " + print(t)
            case None => ()
        }
        return s
    }

    /// 打印类型参数声明列表
    private static func printTypeParamDecls(params: ArrayList<TSTypeParameterDecl>): String {
        var parts = ArrayList<String>()
        for (p in params) {
            parts.append(printTypeParam(p))
        }
        return "<" + join(parts, ", ") + ">"
    }

    /// 打印修饰符
    public static func printModifiers(mods: TSModifiers): String {
        var parts = ArrayList<String>()
        if (mods.isAbstract) { parts.append("abstract") }
        if (mods.isDeclare) { parts.append("declare") }
        if (mods.isOverride) { parts.append("override") }
        if (mods.isPrivate) { parts.append("private") }
        if (mods.isProtected) { parts.append("protected") }
        if (mods.isPublic) { parts.append("public") }
        if (mods.isReadonly) { parts.append("readonly") }
        if (mods.isStatic) { parts.append("static") }
        if (mods.isAsync) { parts.append("async") }
        if (mods.isOut) { parts.append("out") }
        if (mods.isAccessor) { parts.append("accessor") }
        if (mods.isConst) { parts.append("const") }
        return join(parts, " ")
    }

    /// 打印函数参数
    public static func printFnParam(param: TSFnParam): String {
        var s = ""
        if (param.isRest) { s = s + "..." }
        s = s + param.name
        if (param.isOptional) { s = s + "?" }
        match (param.type_) {
            case Some(t) => s = s + ": " + print(t)
            case None => ()
        }
        return s
    }

    /// 判断类型是否需要括号包裹
    private static func needsParen(type_: TSType): Bool {
        match (type_.tag) {
            case TSTypeTag.TSUnion | TSTypeTag.TSIntersection |
                 TSTypeTag.TSConditional | TSTypeTag.TSFunction => true
            case _ => false
        }
    }

    /// 拼接字符串列表
    private static func join(parts: ArrayList<String>, sep: String): String {
        if (parts.size == 0) {
            return ""
        }
        var sb = StringBuilder()
        sb.append(parts[0])
        for (i in 1..parts.size) {
            sb.append(sep)
            sb.append(parts[Int64(i)])
        }
        return sb.toString()
    }
}

// ============================================================================
// TSTypeChecker - TypeScript 类型兼容性检查
// 严格翻译自: src/js_parser/p.ts.zig 中类型检查辅助
//   提供基础的类型兼容性和等价性判断
//   用于类型收窄、类型擦除等场景
// ============================================================================

/// TypeScript 类型检查器 - 对应 Bun 中类型系统辅助方法
public class TSTypeChecker {

    /// 是否可赋值 - 对应 TypeScript assignability
    /// target = source 是否合法
    public static func isAssignableFrom(target: TSType, source: TSType): Bool {
        let t = target.unwrap()
        let s = source.unwrap()

        // any 兼容一切
        if (t.tag == TSTypeTag.TSAnyKeyword || s.tag == TSTypeTag.TSAnyKeyword) {
            return true
        }

        // never 可赋值给任何类型
        if (s.tag == TSTypeTag.TSNeverKeyword) {
            return true
        }

        // 相同类型
        if (isIdentical(t, s)) {
            return true
        }

        // 子类型关系
        if (isSubtypeOf(s, t)) {
            return true
        }

        // undefined/null 可赋值给联合类型中包含它们的类型
        if (s.tag == TSTypeTag.TSUndefinedKeyword || s.tag == TSTypeTag.TSNullKeyword) {
            // 在严格模式下不允许，简化实现中允许
            return true
        }

        // 联合类型: source 可赋值给 target 如果 target 是 source 联合成员之一
        if (t.tag == TSTypeTag.TSUnion) {
            for (member in t.types) {
                if (isAssignableFrom(member, s)) {
                    return true
                }
            }
        }

        return false
    }

    /// 是否为子类型 - 对应 TypeScript subtype relation
    public static func isSubtypeOf(sub: TSType, super_: TSType): Bool {
        let s = sub.unwrap()
        let sp = super_.unwrap()

        // 相同类型
        if (isIdentical(s, sp)) {
            return true
        }

        // 关键字类型子类型关系
        // undefined, null 是所有类型的子类型 (非严格模式)
        match (s.tag) {
            case TSTypeTag.TSUndefinedKeyword =>
                return true
            case TSTypeTag.TSNullKeyword =>
                return true
            case TSTypeTag.TSNeverKeyword =>
                return true // never 是所有类型的子类型
            case _ => ()
        }

        // 联合类型: sub 是 super 的子类型如果 sub 是 super 联合的成员
        if (sp.tag == TSTypeTag.TSUnion) {
            for (member in sp.types) {
                if (isSubtypeOf(s, member)) {
                    return true
                }
            }
            return false
        }

        // 交叉类型: sub 是所有成员的子类型
        if (sp.tag == TSTypeTag.TSIntersection) {
            for (member in sp.types) {
                if (!isSubtypeOf(s, member)) {
                    return false
                }
            }
            return true
        }

        // 数组类型: T[] 是 (泛型) Array<T> 的子类型
        if (s.tag == TSTypeTag.TSArray && sp.tag == TSTypeTag.TSReference) {
            if (sp.typeName == "Array" && sp.typeParams.size == 1) {
                return isSubtypeOf(s.elementType.get(), sp.typeParams[0])
            }
        }

        return false
    }

    /// 类型是否完全相同 - 对应 TypeScript type identity
    public static func isIdentical(a: TSType, b: TSType): Bool {
        let ta = a.unwrap()
        let tb = b.unwrap()

        // 标签不同则不等
        if (ta.tag != tb.tag) {
            return false
        }

        match (ta.tag) {
            // 关键字类型: 标签相同即相等
            case TSTypeTag.TSAnyKeyword | TSTypeTag.TSUnknownKeyword |
                 TSTypeTag.TSNumberKeyword | TSTypeTag.TSStringKeyword |
                 TSTypeTag.TSBooleanKeyword | TSTypeTag.TSVoidKeyword |
                 TSTypeTag.TSUndefinedKeyword | TSTypeTag.TSNullKeyword |
                 TSTypeTag.TSNeverKeyword | TSTypeTag.TSObjectKeyword |
                 TSTypeTag.TSSymbolKeyword | TSTypeTag.TSBigIntKeyword |
                 TSTypeTag.TSThisType => true

            // 类型引用: 名称和类型参数相同
            case TSTypeTag.TSReference =>
                if (ta.typeName != tb.typeName) { return false }
                if (ta.typeParams.size != tb.typeParams.size) { return false }
                for (i in 0..ta.typeParams.size) {
                    if (!isIdentical(ta.typeParams[Int64(i)], tb.typeParams[Int64(i)])) {
                        return false
                    }
                }
                return true

            // 联合/交叉类型: 成员相同 (不考虑顺序)
            case TSTypeTag.TSUnion | TSTypeTag.TSIntersection =>
                if (ta.types.size != tb.types.size) { return false }
                for (t in ta.types) {
                    var found = false
                    for (u in tb.types) {
                        if (isIdentical(t, u)) {
                            found = true
                            break
                        }
                    }
                    if (!found) { return false }
                }
                return true

            // 数组类型: 元素类型相同
            case TSTypeTag.TSArray =>
                return isIdentical(ta.elementType.get(), tb.elementType.get())

            // 元组类型: 元素逐一相同
            case TSTypeTag.TSTuple =>
                if (ta.elements.size != tb.elements.size) { return false }
                for (i in 0..ta.elements.size) {
                    if (!isIdentical(ta.elements[Int64(i)], tb.elements[Int64(i)])) {
                        return false
                    }
                }
                return true

            // 字面量类型: 值相同
            case TSTypeTag.TSLiteral =>
                return ta.stringValue == tb.stringValue &&
                       ta.numberValue == tb.numberValue &&
                       ta.boolValue == tb.boolValue

            // 函数类型: 参数和返回类型相同
            case TSTypeTag.TSFunction =>
                if (ta.params.size != tb.params.size) { return false }
                for (i in 0..ta.params.size) {
                    let pa = ta.params[Int64(i)]
                    let pb = tb.params[Int64(i)]
                    match (pa.type_) {
                        case Some(ta_) =>
                            match (pb.type_) {
                                case Some(tb_) =>
                                    if (!isIdentical(ta_, tb_)) { return false }
                                case None => return false
                            }
                        case None =>
                            if (pb.type_.isSome()) { return false }
                    }
                }
                match (ta.returnType) {
                    case Some(rtA) =>
                        match (tb.returnType) {
                            case Some(rtB) => return isIdentical(rtA, rtB)
                            case None => return false
                        }
                    case None => return tb.returnType.isNone()
                }

            // 其他类型: 简单比较
            case _ =>
                return true
        }
    }

    /// 去除可选标记 - 对应 TypeScript strip optional
    /// T? -> T
    public static func stripOptional(type_: TSType): TSType {
        match (type_.tag) {
            case TSTypeTag.TSOptional =>
                match (type_.wrappedType) {
                    case Some(t) => return t
                    case None => return type_
                }
            case _ => return type_
        }
    }

    /// 去除 null 和 undefined - 对应 TypeScript NonNullable<T>
    public static func stripNullUndefined(type_: TSType): TSType {
        match (type_.tag) {
            case TSTypeTag.TSNullKeyword | TSTypeTag.TSUndefinedKeyword =>
                return TSType.never(type_.loc)
            case TSTypeTag.TSUnion => {
                let filtered = ArrayList<TSType>()
                for (t in type_.types) {
                    let stripped = stripNullUndefined(t)
                    if (stripped.tag != TSTypeTag.TSNeverKeyword) {
                        filtered.append(stripped)
                    }
                }
                if (filtered.size == 0) {
                    return TSType.never(type_.loc)
                }
                if (filtered.size == 1) {
                    return filtered[0]
                }
                return TSType.union(type_.loc, filtered)
            }
            case _ => return type_
        }
    }

    /// 获取类型约束 - 对应 Bun getConstraint()
    /// 对于类型参数，返回其约束类型
    public static func getConstraint(type_: TSType): ?TSType {
        match (type_.tag) {
            case TSTypeTag.TSReference => {
                // 简化: 返回 null，实际需要查找类型参数表
                None
            }
            case TSTypeTag.TSArray => {
                // T[] 约束为 Array<T>
                Some(TSType.reference(type_.loc, "Array", ArrayList<TSType>()))
            }
            case _ => None
        }
    }
}
