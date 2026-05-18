// 属性解析器
// 严格翻译自: src/js_parser/parse/parse_propertyerty.rs (815 lines)
//   Bun 的属性解析器处理:
//   - parse_propertyerty: 属性解析入口
//   - parse_method_expression: 方法表达式解析
//   - 类属性、对象属性、getter/setter 解析
//   - TypeScript 属性修饰符处理
//   - 计算属性、简写属性、展开属性
package bao_parser

import bao_core.*
import bao_collections.*

// ============================================================================
// ParseProperty - 属性解析器
// 严格翻译自: src/js_parser/parse/parse_propertyerty.rs
//   impl P { parse_propertyerty, parse_method_expression, ... }
// ============================================================================

/// 属性解析器 - 对应 Bun ParseProperty 模块
/// 解析对象字面量和类中的属性定义
public class ParseProperty {

    // ========================================================================
    // parseProperty - 属性解析入口
    // 严格翻译自: parse_propertyerty.rs
    //   解析对象/类属性，包括标识符键、字符串键、计算键等
    // ========================================================================

    /// 解析属性 - 对应 Bun parse_propertyerty
    ///
    /// - p: 解析器实例
    /// - opts: 属性选项 (是否类属性、静态、计算等)
    /// - 返回: 解析后的属性
    public static func parseProperty(p: Parser, opts: PropertyOpts): GProperty {
        let property = GProperty()

        // 解析属性修饰符 (TypeScript)
        var isStatic = opts.isStatic
        var isAsync = opts.isAsync
        var isGenerator = opts.isGenerator
        var kind: PropertyKind = PropertyKind.Normal

        // 解析属性键
        var key: Expr
        var isComputed = opts.isComputed

        if (isComputed) {
            // 计算属性 [expr]
            p.lexer.expect(Token.OpenBracket)
            key = p.parseExpr(Level.Comma)
            p.lexer.expect(Token.CloseBracket)
        } else {
            key = parsePropertyKey(p)
        }

        // 检查是否为 getter/setter
        if (!isComputed) {
            if (key.tag == ExprTag.Identifier) {
                if (key.identifierName == "get" && p.lexer.token != Token.Colon &&
                    p.lexer.token != Token.Comma && p.lexer.token != Token.CloseBrace &&
                    p.lexer.token != Token.EndOfFile) {
                    kind = PropertyKind.Get
                    key = parsePropertyKey(p)
                } else if (key.identifierName == "set" && p.lexer.token != Token.Colon &&
                           p.lexer.token != Token.Comma && p.lexer.token != Token.CloseBrace &&
                           p.lexer.token != Token.EndOfFile) {
                    kind = PropertyKind.Set
                    key = parsePropertyKey(p)
                }
            }
            if (key.tag == ExprTag.String) {
                if (key.stringValue == "get" && p.lexer.token != Token.Colon &&
                    p.lexer.token != Token.Comma && p.lexer.token != Token.CloseBrace) {
                    kind = PropertyKind.Get
                    key = parsePropertyKey(p)
                } else if (key.stringValue == "set" && p.lexer.token != Token.Colon &&
                           p.lexer.token != Token.Comma && p.lexer.token != Token.CloseBrace) {
                    kind = PropertyKind.Set
                    key = parsePropertyKey(p)
                }
            }
        }

        property.key = key
        property.kind = kind
        property.isComputed = isComputed
        property.isStatic = isStatic

        let keyRange = p.lexer.range()

        // 检查是否为方法 (后面跟着括号)
        if (p.lexer.token == Token.OpenParen) {
            // 方法或 getter/setter
            let methodResult = parseMethodExpression(p, kind, opts, isComputed, key, keyRange)
            if (let Some(m) <- methodResult) {
                return m
            }
        }

        // TypeScript 类型注解
        if (p.options.features.typescript && p.lexer.token == Token.Colon) {
            p.lexer.next()
            // 跳过类型
            var depth = 0
            while (depth > 0 || (p.lexer.token != Token.Semicolon &&
                   p.lexer.token != Token.Comma && p.lexer.token != Token.CloseBrace &&
                   p.lexer.token != Token.EndOfFile && p.lexer.token != Token.Equals)) {
                match (p.lexer.token) {
                    case Token.OpenParen | Token.OpenBracket | Token.OpenBrace | Token.LessThan =>
                        depth++
                    case Token.CloseParen | Token.CloseBracket | Token.CloseBrace | Token.GreaterThan =>
                        depth--
                    case _ => ()
                }
                p.lexer.next()
            }
        }

        // 属性值
        if (p.lexer.token == Token.Equals) {
            // 类字段初始化器: foo = value
            p.lexer.next()
            property.value = p.parseExpr(Level.Comma)
        } else if (p.lexer.token == Token.Colon) {
            // 对象属性值: foo: value
            p.lexer.next()
            property.value = p.parseExpr(Level.Comma)
        } else {
            // 简写属性: { foo } 等同于 { foo: foo }
            if (key.tag == ExprTag.Identifier) {
                property.value = key
                property.isShorthand = true
            }
        }

        return property
    }

    // ========================================================================
    // parseMethodExpression - 解析方法表达式
    // 严格翻译自: parse_propertyerty.rs:33-...
    //   解析对象/类中的方法定义
    // ========================================================================

    /// 解析方法表达式 - 对应 Bun parse_method_expression
    ///
    /// - p: 解析器实例
    /// - kind: 属性类型 (Normal/Get/Set)
    /// - opts: 属性选项
    /// - isComputed: 是否为计算属性
    /// - key: 属性键
    /// - keyRange: 属性键范围
    public static func parseMethodExpression(
        p: Parser,
        kind: PropertyKind,
        opts: PropertyOpts,
        isComputed: Bool,
        key: Expr,
        keyRange: Range
    ): ?GProperty {
        if (p.lexer.token != Token.OpenParen) {
            return None
        }
        if (kind != PropertyKind.Normal && kind != PropertyKind.Get && kind != PropertyKind.Set) {
            return None
        }

        let loc = p.lexer.loc()

        // 进入函数参数作用域
        let scopeIndex = p.pushScopeForParsePass(ScopeKind.FunctionArgs, loc)
        var isConstructor = false

        // 检查 constructor 和 prototype 限制
        if (opts.isClass && !isComputed) {
            if (key.tag == ExprTag.String) {
                if (!opts.isStatic && key.stringValue == "constructor") {
                    if (kind == PropertyKind.Get) {
                        p.log.addError(MsgData("Class constructor cannot be a getter"))
                    } else if (kind == PropertyKind.Set) {
                        p.log.addError(MsgData("Class constructor cannot be a setter"))
                    } else if (opts.isAsync) {
                        p.log.addError(MsgData("Class constructor cannot be an async fnDatation"))
                    } else if (opts.isGenerator) {
                        p.log.addError(MsgData("Class constructor cannot be a generator fnDatation"))
                    } else {
                        isConstructor = true
                    }
                } else if (opts.isStatic && key.stringValue == "prototype") {
                    p.log.addError(MsgData("Invalid static method name \"prototype\""))
                }
            }
        }

        // 解析函数
        let fnOrArrowData = FnOrArrowDataParse()
        fnOrArrowData.asyncRange = opts.asyncRange
        fnOrArrowData.hasAsyncRange = opts.isAsync
        fnOrArrowData.allowAwait = if (opts.isAsync) {
            AwaitOrYield.AllowExpr
        } else {
            AwaitOrYield.AllowIdent
        }
        fnOrArrowData.allowYield = if (opts.isGenerator) {
            AwaitOrYield.AllowExpr
        } else {
            AwaitOrYield.AllowIdent
        }

        var fnData = ParseFn.parseFn(p, None, fnOrArrowData)
        p.popScope()

        // 声明函数符号
        if (isConstructor) {
            fnData.isConstructor = true
        }

        let property = GProperty()
        property.key = key
        property.kind = kind
        property.isComputed = isComputed
        property.isStatic = opts.isStatic
        property.isMethod = true
        property.fnData = fnData

        return Some(property)
    }

    // ========================================================================
    // parseClassPropertyName - 解析类属性名
    // 处理 TypeScript 修饰符
    // ========================================================================

    /// 解析类属性名 (包含 TypeScript 修饰符处理)
    /// 对应 Bun 中类属性解析的修饰符处理
    public static func parseClassPropertyName(p: Parser): PropertyParseResult {
        let result = PropertyParseResult()

        // 解析 TypeScript 修饰符
        while (true) {
            if (p.lexer.token == Token.Identifier) {
                let name = p.lexer.identifier
                if (PropertyModifierKeyword.lookup(name) != None) {
                    match (name) {
                        case "static" =>
                            result.isStatic = true
                            p.lexer.next()
                            continue
                        case "async" =>
                            result.isAsync = true
                            p.lexer.next()
                            continue
                        case "abstract" =>
                            result.isAbstract = true
                            p.lexer.next()
                            continue
                        case "declare" =>
                            result.isDeclare = true
                            p.lexer.next()
                            continue
                        case "readonly" =>
                            result.isReadonly = true
                            p.lexer.next()
                            continue
                        case "private" =>
                            result.accessibility = Some(Accessibility.Private)
                            p.lexer.next()
                            continue
                        case "protected" =>
                            result.accessibility = Some(Accessibility.Protected)
                            p.lexer.next()
                            continue
                        case "public" =>
                            result.accessibility = Some(Accessibility.Public)
                            p.lexer.next()
                            continue
                        case "override" =>
                            result.isOverride = true
                            p.lexer.next()
                            continue
                        case "accessor" =>
                            result.isAccessor = true
                            p.lexer.next()
                            continue
                        case _ =>
                            break
                    }
                }
            }
            break
        }

        // 检查 * (generator)
        if (p.lexer.token == Token.Asterisk) {
            result.isGenerator = true
            p.lexer.next()
        }

        // 检查 # (private field)
        if (p.lexer.token == Token.PrivateIdentifier) {
            result.isPrivate = true
            result.keyName = p.lexer.identifier
            p.lexer.next()
            result.key = createKeyExpr(p, result.keyName, result.isPrivate)
            return result
        }

        // 检查 [ (computed propertyerty)
        if (p.lexer.token == Token.OpenBracket) {
            result.isComputed = true
            p.lexer.next()
            result.key = p.parseExpr(Level.Comma)
            p.lexer.expect(Token.CloseBracket)
            return result
        }

        // 正常键
        result.key = parsePropertyKey(p)
        if (let Some(k) <- result.key) {
            if (k.tag == ExprTag.Identifier) {
                result.keyName = k.identifierName
            } else if (k.tag == ExprTag.String) {
                result.keyName = k.stringValue
            }
        }

        return result
    }

    // ========================================================================
    // 辅助方法
    // ========================================================================

    /// 解析属性键
    private static func parsePropertyKey(p: Parser): ?Expr {
        match (p.lexer.token) {
            case Token.Identifier =>
                let loc = p.lexer.loc()
                let name = p.lexer.identifier
                p.lexer.next()
                let result = Expr()
                result.tag = ExprTag.Identifier
                result.loc = loc
                result.identifierName = name
                return Some(result)
            case Token.StringLiteral =>
                let loc = p.lexer.loc()
                let value = p.lexer.stringLiteral
                p.lexer.next()
                let result = Expr()
                result.tag = ExprTag.String
                result.loc = loc
                result.stringValue = value
                return Some(result)
            case Token.NumericLiteral =>
                let loc = p.lexer.loc()
                let value = p.lexer.number
                p.lexer.next()
                let result = Expr()
                result.tag = ExprTag.Number
                result.loc = loc
                result.numberValue = value
                return Some(result)
            case Token.BigIntegerLiteral =>
                let loc = p.lexer.loc()
                let value = p.lexer.identifier
                p.lexer.next()
                let result = Expr()
                result.tag = ExprTag.BigInt
                result.loc = loc
                result.stringValue = value
                return Some(result)
            case _ =>
                // 保留字作为属性键
                if (LexerTables.isReservedWord(p.lexer.token)) {
                    let loc = p.lexer.loc()
                    let name = LexerTables.tokenToString(p.lexer.token)
                    p.lexer.next()
                    let result = Expr()
                    result.tag = ExprTag.Identifier
                    result.loc = loc
                    result.identifierName = name
                    return Some(result)
                }
                return None
        }
    }

    /// 创建键表达式
    private static func createKeyExpr(p: Parser, name: String, isPrivate: Bool): Expr {
        let result = Expr()
        if (isPrivate) {
            result.tag = ExprTag.PrivateIdentifier
        } else {
            result.tag = ExprTag.Identifier
        }
        result.loc = p.lexer.loc()
        result.identifierName = name
        return result
    }
}

// ============================================================================
// 辅助类型
// ============================================================================

/// GProperty - 属性 AST 节点 - 对应 Bun G.Property
public class GProperty {
    public var key: ?Expr
    public var value: ?Expr
    public var kind: PropertyKind
    public var isComputed: Bool
    public var isStatic: Bool
    public var isMethod: Bool
    public var isShorthand: Bool
    public var isSpread: Bool
    public var fnData: ?GFN

    public init() {
        key = None
        value = None
        kind = PropertyKind.Normal
        isComputed = false
        isStatic = false
        isMethod = false
        isShorthand = false
        isSpread = false
        fnData = None
    }
}

/// PropertyParseResult - 属性解析结果
public class PropertyParseResult {
    public var key: ?Expr
    public var keyName: String
    public var isStatic: Bool
    public var isAsync: Bool
    public var isGenerator: Bool
    public var isComputed: Bool
    public var isPrivate: Bool
    public var isAbstract: Bool
    public var isDeclare: Bool
    public var isReadonly: Bool
    public var isOverride: Bool
    public var isAccessor: Bool
    public var accessibility: ?Accessibility

    public init() {
        key = None
        keyName = ""
        isStatic = false
        isAsync = false
        isGenerator = false
        isComputed = false
        isPrivate = false
        isAbstract = false
        isDeclare = false
        isReadonly = false
        isOverride = false
        isAccessor = false
        accessibility = None
    }
}

/// Accessibility - 可访问性 - 对应 Bun TypeScript 可访问性修饰符
public enum Accessibility {
    | Public
    | Protected
    | Private
}
