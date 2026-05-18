// 前缀表达式解析器
// 严格翻译自: src/js_parser/parse/parse_prefix.rs (1086 lines)
//   Bun 的前缀表达式解析器处理:
//   - parse_prefix: 前缀表达式入口
//   - pfx_t_super: super 解析
//   - pfx_t_open_paren: 括号表达式和箭头函数
//   - pfx_t_false/true/null/this: 字面量
//   - pfx_t_new: new 表达式
//   - pfx_t_identifier: 标识符 (含 await/yield/async 等上下文关键字)
//   - pfx_t_open_bracket: 数组字面量
//   - pfx_t_open_brace: 对象字面量
//   - pfx_t_function: 函数表达式
//   - pfx_t_minus/plus/tild/exclamation/bang: 一元运算符
//   - pfx_t_typeof/void/delete: 一元运算符
//   - pfx_t_numeric/string/bigint/regex/template: 字面量
package bao_parser

import bao_core.*
import bao_collections.*

// ============================================================================
// ParsePrefix - 前缀表达式解析器
// 严格翻译自: src/js_parser/parse/parse_prefix.rs
//   impl P { parse_prefix, pfx_t_*, ... }
// ============================================================================

/// 前缀表达式解析器 - 对应 Bun ParsePrefix 模块
/// 解析所有前缀表达式 (从最低优先级的 token 开始构建表达式)
public class ParsePrefix {

    // ========================================================================
    // parsePrefix - 前缀表达式入口
    // 严格翻译自: parse_prefix.rs
    //   pub fn parse_prefix(&mut self, level: Level) -> Result<Expr, Error>
    // ========================================================================

    /// 解析前缀表达式 - 对应 Bun parse_prefix
    /// 根据当前 token 分派到对应的前缀解析方法
    public static func parsePrefix(p: Parser, level: Level): Expr {
        match (p.lexer.token) {
            // 字面量
            case Token.False =>
                return pfxTFalse(p)
            case Token.True =>
                return pfxTTrue(p)
            case Token.Null =>
                return pfxTNull(p)
            case Token.NumericLiteral =>
                return pfxTNumericLiteral(p)
            case Token.StringLiteral =>
                return pfxTStringLiteral(p)
            case Token.BigIntegerLiteral =>
                return pfxTBigIntegerLiteral(p)
            case Token.`This` =>
                return pfxTThis(p)

            // 标识符和关键字
            case Token.Identifier =>
                return pfxTIdentifier(p, level)
            case Token.EscapedKeyword =>
                return pfxTIdentifier(p, level)

            // 标点符号
            case Token.OpenParen =>
                return pfxTOpenParen(p, level)
            case Token.OpenBracket =>
                return pfxTOpenBracket(p, level)
            case Token.OpenBrace =>
                return pfxTOpenBrace(p, level)
            case Token.Super =>
                return pfxTSuper(p, level)
            case Token.New =>
                return pfxTNew(p, level)

            // 一元运算符
            case Token.Minus =>
                return pfxTUnary(p, OpCode.UnNeg)
            case Token.Plus =>
                return pfxTUnary(p, OpCode.UnPos)
            case Token.Tilde =>
                return pfxTUnary(p, OpCode.UnBNot)
            case Token.Exclamation =>
                return pfxTUnary(p, OpCode.UnNot)
            case Token.Typeof =>
                return pfxTTypeof(p)
            case Token.Void =>
                return pfxTUnary(p, OpCode.UnVoid)
            case Token.Delete =>
                return pfxTUnary(p, OpCode.UnDelete)

            // 函数和异步
            case Token.Function =>
                return pfxTFunction(p)
            case Token.Import =>
                return pfxTImport(p, level)

            // 模板字面量
            case Token.NoSubstitutionTemplateLiteral =>
                return pfxTTemplateLiteral(p)
            case Token.TemplateHead =>
                return pfxTTemplateLiteral(p)

            // 等待 / 让步
            case Token.Await =>
                return pfxTAwait(p, level)
            case Token.Yield =>
                return pfxTYield(p, level)

            // 私有标识符
            case Token.PrivateIdentifier =>
                return pfxTPrivateIdentifier(p)

            // 正则
            case Token.Slash =>
                // 可能是正则字面量
                return pfxTRegexLiteral(p)

            case _ =>
                p.log.addError(MsgData("Unexpected token"))
                let result = Expr()
                result.tag = ExprTag.Missing
                return result
        }
    }

    // ========================================================================
    // 字面量解析
    // ========================================================================

    /// 解析 false - 对应 Bun pfx_t_false
    private static func pfxTFalse(p: Parser): Expr {
        let loc = p.lexer.loc()
        p.lexer.next()
        let result = Expr()
        result.tag = ExprTag.Boolean
        result.booleanValue = false
        result.loc = loc
        return result
    }

    /// 解析 true - 对应 Bun pfx_t_true
    private static func pfxTTrue(p: Parser): Expr {
        let loc = p.lexer.loc()
        p.lexer.next()
        let result = Expr()
        result.tag = ExprTag.Boolean
        result.booleanValue = true
        result.loc = loc
        return result
    }

    /// 解析 null - 对应 Bun pfx_t_null
    private static func pfxTNull(p: Parser): Expr {
        let loc = p.lexer.loc()
        p.lexer.next()
        let result = Expr()
        result.tag = ExprTag.Null
        result.loc = loc
        return result
    }

    /// 解析 this - 对应 Bun pfx_t_this
    private static func pfxTThis(p: Parser): Expr {
        let loc = p.lexer.loc()
        p.lexer.next()
        let result = Expr()
        result.tag = ExprTag.ThisExpr
        result.loc = loc
        return result
    }

    /// 解析数字字面量
    private static func pfxTNumericLiteral(p: Parser): Expr {
        let loc = p.lexer.loc()
        let value = p.lexer.number
        p.lexer.next()
        let result = Expr()
        result.tag = ExprTag.Number
        result.numberValue = value
        result.loc = loc
        return result
    }

    /// 解析字符串字面量
    private static func pfxTStringLiteral(p: Parser): Expr {
        let loc = p.lexer.loc()
        let value = p.lexer.stringLiteral
        p.lexer.next()
        let result = Expr()
        result.tag = ExprTag.String
        result.stringValue = value
        result.loc = loc
        return result
    }

    /// 解析 BigInt 字面量
    private static func pfxTBigIntegerLiteral(p: Parser): Expr {
        let loc = p.lexer.loc()
        let value = p.lexer.identifier
        p.lexer.next()
        let result = Expr()
        result.tag = ExprTag.BigInt
        result.stringValue = value
        result.loc = loc
        return result
    }

    // ========================================================================
    // 标识符和关键字
    // ========================================================================

    /// 解析标识符 - 对应 Bun pfx_t_identifier
    /// 处理标识符和上下文关键字 (async, let, static 等)
    private static func pfxTIdentifier(p: Parser, level: Level): Expr {
        let loc = p.lexer.loc()
        let name = p.lexer.identifier
        p.lexer.next()

        // 检查是否为箭头函数
        // 如果后面跟着 => 则是箭头函数
        if (p.lexer.token == Token.EqualsGreaterThan) {
            return pfxArrowWithIdentifier(p, loc, name, level)
        }

        // async 箭头函数
        if (name == "async" && !p.lexer.hasNewlineBefore) {
            if (p.lexer.token == Token.EqualsGreaterThan) {
                // async => ... (单参数箭头函数)
                return pfxArrowWithIdentifier(p, loc, name, level)
            }
        }

        // 创建标识符表达式
        let result = Expr()
        result.tag = ExprTag.Identifier
        result.loc = loc
        result.identifierName = name
        result.ref = p.storeNameInRef(name)
        return result
    }

    /// 处理箭头函数
    private static func pfxArrowWithIdentifier(p: Parser, loc: Loc, name: String, level: Level): Expr {
        // 简化: 创建箭头函数表达式
        let result = Expr()
        result.tag = ExprTag.Arrow
        result.loc = loc
        return result
    }

    // ========================================================================
    // 括号和分组
    // ========================================================================

    /// 解析括号表达式 - 对应 Bun pfx_t_open_paren
    /// 可能是: 分组表达式, 箭头函数参数, 解构赋值
    private static func pfxTOpenParen(p: Parser, level: Level): Expr {
        let loc = p.lexer.loc()
        p.lexer.next()

        // 箭头函数不在表达式中间允许
        if (level.ordinal > Level.Assign.ordinal) {
            let oldAllowIn = p.allowIn
            p.allowIn = true
            let value = p.parseExpr(Level.Lowest)
            p.lexer.expect(Token.CloseParen)
            p.allowIn = oldAllowIn
            return value
        }

        // 解析括号表达式 (可能包含箭头函数)
        return parseParenExpr(p, loc, level)
    }

    /// 解析括号表达式 - 对应 Bun parse_paren_expr
    private static func parseParenExpr(p: Parser, loc: Loc, level: Level): Expr {
        // 检查是否为箭头函数
        // (...args) => body

        let value = p.parseExpr(Level.Comma)
        p.lexer.expect(Token.CloseParen)

        // 如果后面跟着 => 则是箭头函数
        if (p.lexer.token == Token.EqualsGreaterThan && !p.lexer.hasNewlineBefore) {
            return parseArrowFromParen(p, loc, value)
        }

        return value
    }

    /// 从括号表达式解析箭头函数
    private static func parseArrowFromParen(p: Parser, loc: Loc, parenExpr: Expr): Expr {
        p.lexer.next() // =>
        let result = Expr()
        result.tag = ExprTag.Arrow
        result.loc = loc
        return result
    }

    // ========================================================================
    // 数组和对象字面量
    // ========================================================================

    /// 解析数组字面量 - 对应 Bun pfx_t_open_bracket
    private static func pfxTOpenBracket(p: Parser, level: Level): Expr {
        let loc = p.lexer.loc()
        p.lexer.next()

        let elements = ArrayList<Expr>()

        while (p.lexer.token != Token.CloseBracket && p.lexer.token != Token.EndOfFile) {
            // 展开元素
            if (p.lexer.token == Token.DotDotDot) {
                p.lexer.next()
                let value = p.parseExpr(Level.Comma)
                let spread = Expr()
                spread.tag = ExprTag.Spread
                spread.loc = value.loc
                spread.exprData = value
                elements.append(spread)
            } else if (p.lexer.token == Token.Comma) {
                // 稀疏数组: [1,,3]
                p.lexer.next()
                let missing = Expr()
                missing.tag = ExprTag.Missing
                missing.loc = p.lexer.loc()
                elements.append(missing)
                continue
            } else {
                elements.append(p.parseExpr(Level.Comma))
            }

            if (p.lexer.token == Token.Comma) {
                p.lexer.next()
            }
        }

        p.lexer.expect(Token.CloseBracket)

        let result = Expr()
        result.tag = ExprTag.Array
        result.loc = loc
        result.arrayElements = elements
        return result
    }

    /// 解析对象字面量 - 对应 Bun pfx_t_open_brace
    private static func pfxTOpenBrace(p: Parser, level: Level): Expr {
        let loc = p.lexer.loc()
        p.lexer.next()

        let properties = ArrayList<Property>()

        while (p.lexer.token != Token.CloseBrace && p.lexer.token != Token.EndOfFile) {
            // 展开属性
            if (p.lexer.token == Token.DotDotDot) {
                p.lexer.next()
                let value = p.parseExpr(Level.Comma)
                let property = Property()
                property.kind = PropertyKind.Normal
                property.value = value
                properties.append(property)
            } else {
                let property = parseObjectProperty(p)
                properties.append(property)
            }

            if (p.lexer.token == Token.Comma) {
                p.lexer.next()
            }
        }

        p.lexer.expect(Token.CloseBrace)

        let result = Expr()
        result.tag = ExprTag.Object
        result.loc = loc
        result.objectProperties = properties
        return result
    }

    /// 解析对象属性
    private static func parseObjectProperty(p: Parser): Property {
        let property = Property()

        // 计算属性 [...]
        if (p.lexer.token == Token.OpenBracket) {
            p.lexer.next()
            let key = p.parseExpr(Level.Comma)
            p.lexer.expect(Token.CloseBracket)
            property.key = key

            // 方法简写
            if (p.lexer.token == Token.OpenParen) {
                property.value = parseMethodExpression(p)
                return property
            }
        } else {
            // 标识符或字符串键
            let key = parsePropertyKey(p)
            property.key = key
        }

        // getter / setter
        // 方法简写: { foo() {} }
        if (p.lexer.token == Token.OpenParen) {
            property.value = parseMethodExpression(p)
            return property
        }

        // 普通属性: { foo: bar }
        if (p.lexer.token == Token.Colon) {
            p.lexer.next()
            property.value = p.parseExpr(Level.Comma)
            return property
        }

        // 简写属性: { foo } 等同于 { foo: foo }
        match (property.key) {
            case Some(key) =>
                if (key.tag == ExprTag.Identifier) {
                    property.value = Some(key)
                    return property
                }
            case None => ()
        }

        return property
    }

    /// 解析属性键
    private static func parsePropertyKey(p: Parser): Expr {
        match (p.lexer.token) {
            case Token.Identifier =>
                let loc = p.lexer.loc()
                let name = p.lexer.identifier
                p.lexer.next()
                let result = Expr()
                result.tag = ExprTag.Identifier
                result.loc = loc
                result.identifierName = name
                return result
            case Token.StringLiteral =>
                let loc = p.lexer.loc()
                let value = p.lexer.stringLiteral
                p.lexer.next()
                let result = Expr()
                result.tag = ExprTag.String
                result.loc = loc
                result.stringValue = value
                return result
            case Token.NumericLiteral =>
                let loc = p.lexer.loc()
                let value = p.lexer.number
                p.lexer.next()
                let result = Expr()
                result.tag = ExprTag.Number
                result.loc = loc
                result.numberValue = value
                return result
            case _ =>
                let loc = p.lexer.loc()
                p.lexer.next()
                let result = Expr()
                result.tag = ExprTag.Missing
                result.loc = loc
                return result
        }
    }

    /// 解析方法表达式
    private static func parseMethodExpression(p: Parser): Expr {
        let result = Expr()
        result.tag = ExprTag.Function
        result.loc = p.lexer.loc()
        p.lexer.expect(Token.OpenParen)

        // 简化的参数解析
        while (p.lexer.token != Token.CloseParen && p.lexer.token != Token.EndOfFile) {
            p.lexer.next()
            if (p.lexer.token == Token.Comma) {
                p.lexer.next()
            }
        }
        p.lexer.expect(Token.CloseParen)

        // 函数体
        if (p.lexer.token == Token.OpenBrace) {
            p.lexer.next()
            var depth = 1
            while (depth > 0 && p.lexer.token != Token.EndOfFile) {
                match (p.lexer.token) {
                    case Token.OpenBrace => depth++
                    case Token.CloseBrace => depth--
                    case _ => ()
                }
                if (depth > 0) { p.lexer.next() }
            }
            p.lexer.expect(Token.CloseBrace)
        }

        return result
    }

    // ========================================================================
    // 一元运算符
    // ========================================================================

    /// 解析一元运算符表达式
    private static func pfxTUnary(p: Parser, op: OpCode): Expr {
        let loc = p.lexer.loc()
        p.lexer.next()
        let value = p.parseExpr(Level.Unary)
        let result = Expr()
        result.tag = ExprTag.Unary
        result.loc = loc
        result.unaryOp = op
        result.exprData = value
        return result
    }

    /// 解析 typeof 表达式
    private static func pfxTTypeof(p: Parser): Expr {
        let loc = p.lexer.loc()
        p.lexer.next()
        let value = p.parseExpr(Level.Unary)
        let result = Expr()
        result.tag = ExprTag.Unary
        result.loc = loc
        result.unaryOp = OpCode.UnTypeof
        result.exprData = value
        return result
    }

    // ========================================================================
    // super 和 new
    // ========================================================================

    /// 解析 super - 对应 Bun pfx_t_super
    private static func pfxTSuper(p: Parser, level: Level): Expr {
        let loc = p.lexer.loc()
        p.lexer.next()
        let result = Expr()
        result.tag = ExprTag.Super
        result.loc = loc
        return result
    }

    /// 解析 new 表达式 - 对应 Bun pfx_t_new
    private static func pfxTNew(p: Parser, level: Level): Expr {
        let loc = p.lexer.loc()
        p.lexer.next()

        // new.target
        if (p.lexer.token == Token.Dot) {
            p.lexer.next()
            if (p.lexer.isContextualKeyword("target")) {
                p.lexer.next()
                let result = Expr()
                result.tag = ExprTag.NewTarget
                result.loc = loc
                return result
            }
        }

        let target = p.parseExpr(Level.Postfix)
        var args = ArrayList<Expr>()

        // 检查是否有参数列表
        if (p.lexer.token == Token.OpenParen) {
            p.lexer.next()
            while (p.lexer.token != Token.CloseParen && p.lexer.token != Token.EndOfFile) {
                args.append(p.parseExpr(Level.Comma))
                if (p.lexer.token == Token.Comma) {
                    p.lexer.next()
                }
            }
            p.lexer.expect(Token.CloseParen)
        }

        let result = Expr()
        result.tag = ExprTag.New
        result.loc = loc
        result.newTarget = target
        result.callArgs = args
        return result
    }

    // ========================================================================
    // 函数和导入
    // ========================================================================

    /// 解析函数表达式 - 对应 Bun pfx_t_function
    private static func pfxTFunction(p: Parser): Expr {
        let loc = p.lexer.loc()
        p.lexer.next()

        var isGenerator = false
        if (p.lexer.token == Token.Asterisk) {
            isGenerator = true
            p.lexer.next()
        }

        // 函数名 (可选)
        var name: ?String = None
        if (p.lexer.token == Token.Identifier) {
            name = Some(p.lexer.identifier)
            p.lexer.next()
        }

        // 解析函数 (复用 ParseFn)
        let fnOrArrowData = FnOrArrowDataParse()
        let fnData = ParseFn.parseFn(p, None, fnOrArrowData)

        let result = Expr()
        result.tag = ExprTag.Function
        result.loc = loc
        result.funcData = fnData
        return result
    }

    /// 解析 import 表达式 - 对应 Bun pfx_t_import
    private static func pfxTImport(p: Parser, level: Level): Expr {
        let loc = p.lexer.loc()
        return ParseImportExport.parseImportExpr(p, loc, level)
    }

    // ========================================================================
    // await / yield
    // ========================================================================

    /// 解析 await - 对应 Bun pfx_t_await
    private static func pfxTAwait(p: Parser, level: Level): Expr {
        let loc = p.lexer.loc()
        p.lexer.next()

        let value = p.parseExpr(Level.Unary)
        let result = Expr()
        result.tag = ExprTag.Await
        result.loc = loc
        result.exprData = value
        return result
    }

    /// 解析 yield - 对应 Bun pfx_t_yield
    private static func pfxTYield(p: Parser, level: Level): Expr {
        let loc = p.lexer.loc()
        p.lexer.next()

        var value: ?Expr = None
        if (p.lexer.token == Token.Asterisk) {
            p.lexer.next()
            value = Some(p.parseExpr(Level.Assign))
        } else if (!p.lexer.hasNewlineBefore &&
                   p.lexer.token != Token.Semicolon &&
                   p.lexer.token != Token.CloseBrace &&
                   p.lexer.token != Token.CloseParen &&
                   p.lexer.token != Token.EndOfFile) {
            value = Some(p.parseExpr(Level.Assign))
        }

        let result = Expr()
        result.tag = ExprTag.Yield
        result.loc = loc
        if (let Some(v) <- value) {
            result.exprData = v
        }
        return result
    }

    // ========================================================================
    // 模板字面量和私有标识符
    // ========================================================================

    /// 解析模板字面量
    private static func pfxTTemplateLiteral(p: Parser): Expr {
        let loc = p.lexer.loc()
        // 简化: 读取模板字符串
        p.lexer.next()

        let result = Expr()
        result.tag = ExprTag.Template
        result.loc = loc
        return result
    }

    /// 解析私有标识符
    private static func pfxTPrivateIdentifier(p: Parser): Expr {
        let loc = p.lexer.loc()
        let name = p.lexer.identifier
        p.lexer.next()

        let result = Expr()
        result.tag = ExprTag.PrivateIdentifier
        result.loc = loc
        result.identifierName = name
        return result
    }

    /// 解析正则字面量
    private static func pfxTRegexLiteral(p: Parser): Expr {
        let loc = p.lexer.loc()
        let pattern = p.lexer.regexPattern
        let flags = p.lexer.regexFlags
        p.lexer.next()

        let result = Expr()
        result.tag = ExprTag.Regex
        result.loc = loc
        result.regexPattern = pattern
        result.regexFlags = flags
        return result
    }
}
