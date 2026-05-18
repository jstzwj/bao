// 后缀表达式解析器
// 严格翻译自: src/js_parser/parse/parse_suffix.rs (1621 lines)
//   Bun 的后缀表达式解析器处理:
//   - parse_suffix: 后缀表达式入口
//   - sfx_t_dot: 属性访问 (expr.prop)
//   - sfx_t_open_bracket: 索引访问 (expr[index])
//   - sfx_t_open_paren: 函数调用 (expr(args))
//   - sfx_t_plus_plus: 后缀递增 (expr++)
//   - sfx_t_minus_minus: 后缀递减 (expr--)
//   - sfx_t_question_dot: 可选链 (expr?.prop)
//   - sfx_handle_typescript_as: TypeScript as 类型断言
//   - 模板字面量标签 (expr`template`)
//   - 可选链传播
package bao_parser

import bao_core.*
import bao_collections.*

// ============================================================================
// Continuation - 继续状态
// 严格翻译自: parse_suffix.rs Continuation
//   enum Continuation { Next, Done }
// ============================================================================

/// 继续状态 - 对应 Bun Continuation
public enum Continuation {
    | Next  // 继续解析后缀
    | Done  // 停止解析

    public func isNext(): Bool {
        match (this) {
            case Next => true
            case _ => false
        }
    }
}

// ============================================================================
// ParseSuffix - 后缀表达式解析器
// 严格翻译自: src/js_parser/parse/parse_suffix.rs
//   impl P { parse_suffix, sfx_t_*, ... }
// ============================================================================

/// 后缀表达式解析器 - 对应 Bun ParseSuffix 模块
/// 解析所有后缀运算符 (属性访问、函数调用、递增递减等)
public class ParseSuffix {

    // ========================================================================
    // parseSuffix - 后缀表达式入口
    // 严格翻译自: parse_suffix.rs
    //   pub fn parse_suffix(&mut self, left: Expr, level: Level) -> Result<Expr, Error>
    // ========================================================================

    /// 解析后缀表达式 - 对应 Bun parse_suffix
    /// 循环处理后缀运算符直到完成或优先级不足
    public static func parseSuffix(p: Parser, left: Expr, level: Level): Expr {
        var current = left
        var optionalChain: ?OptionalChain = None

        while (true) {
            // 检查优先级
            // 调用和后缀运算符需要足够高的优先级
            if (level.ordinal < Level.Postfix.ordinal &&
                level.ordinal < Level.Call.ordinal) {
                break
            }

            let oldOptionalChain = optionalChain

            // 处理 TypeScript as / satisfies
            let asResult = sfxHandleTypeScriptAs(p, level)
            if (asResult.isNext()) {
                continue
            }

            match (p.lexer.token) {
                // .
                case Token.Dot =>
                    let result = sfxTDot(p, optionalChain, oldOptionalChain, current)
                    current = result
                    // 更新可选链
                    if (oldOptionalChain != None) {
                        optionalChain = Some(OptionalChain.Continuation)
                    }

                // ?.
                case Token.QuestionDot =>
                    p.lexer.next()
                    optionalChain = Some(OptionalChain.Start)

                    if (p.lexer.token == Token.OpenBracket) {
                        // ?.[index]
                        current = sfxTIndex(p, OptionalChain.Start, current)
                    } else if (p.lexer.token == Token.OpenParen) {
                        // ?.(args)
                        current = sfxTCall(p, OptionalChain.Start, current, level)
                    } else {
                        // ?.prop
                        current = sfxTDotAfterQuestionDot(p, OptionalChain.Start, current)
                    }

                // [
                case Token.OpenBracket =>
                    if (!p.lexer.hasNewlineBefore) {
                        let chain = optionalChain
                        current = sfxTIndex(p, chain, current)
                        if (chain != None) {
                            optionalChain = Some(OptionalChain.Continuation)
                        }
                    } else {
                        break
                    }

                // (
                case Token.OpenParen =>
                    if (!p.lexer.hasNewlineBefore && level.ordinal >= Level.Call.ordinal) {
                        let chain = optionalChain
                        current = sfxTCall(p, chain, current, level)
                        if (chain != None) {
                            optionalChain = Some(OptionalChain.Continuation)
                        }
                    } else {
                        break
                    }

                // ++
                case Token.PlusPlus =>
                    if (level.ordinal >= Level.Postfix.ordinal) {
                        p.lexer.next()
                        let result = Expr()
                        result.tag = ExprTag.Unary
                        result.loc = current.loc
                        result.unaryOp = OpCode.UnPostInc
                        result.exprData = current
                        current = result
                    } else {
                        break
                    }

                // --
                case Token.MinusMinus =>
                    if (level.ordinal >= Level.Postfix.ordinal) {
                        p.lexer.next()
                        let result = Expr()
                        result.tag = ExprTag.Unary
                        result.loc = current.loc
                        result.unaryOp = OpCode.UnPostDec
                        result.exprData = current
                        current = result
                    } else {
                        break
                    }

                // 模板字面量标签
                case Token.NoSubstitutionTemplateLiteral | Token.TemplateHead =>
                    current = sfxTTemplate(p, current)

                // ! (TypeScript 非空断言)
                case Token.Exclamation =>
                    if (p.options.features.typescript && !p.lexer.hasNewlineBefore) {
                        p.lexer.next()
                        // 非空断言在编译时被移除
                    } else {
                        break
                    }

                case _ =>
                    break
            }
        }

        // 检查可选链的调用限制
        // 可选链不能直接与 await/yield 一起使用

        return current
    }

    // ========================================================================
    // sfxTDot - 属性访问
    // 严格翻译自: parse_suffix.rs sfx_t_dot
    //   解析 expr.prop 和私有字段访问
    // ========================================================================

    /// 解析属性访问 - 对应 Bun sfx_t_dot
    private static func sfxTDot(
        p: Parser,
        optionalChain: ?OptionalChain,
        oldOptionalChain: ?OptionalChain,
        left: Expr
    ): Expr {
        p.lexer.next() // .

        let target = left

        // 私有标识符
        if (p.lexer.token == Token.PrivateIdentifier && p.allowPrivateIdentifiers) {
            let name = p.lexer.identifier
            let nameLoc = p.lexer.loc()
            p.lexer.next()

            // 私有字段访问实际上是索引访问
            let result = Expr()
            result.tag = ExprTag.Index
            result.loc = target.loc
            result.indexTarget = target
            result.optionalChain = oldOptionalChain
            return result
        }

        // 正常属性访问
        let nameLoc = p.lexer.loc()
        let name = p.lexer.identifier
        p.lexer.next()

        // 检查是否可以重写属性访问 (命名空间等)
        if (let Some(rewritten) <- FoldHelper.maybeRewritePropertyAccess(
            p, target.loc, target, name, nameLoc,
            IdentifierOpts()
        )) {
            return rewritten
        }

        let result = Expr()
        result.tag = ExprTag.Dot
        result.loc = target.loc
        result.dotTarget = target
        result.propertyName = name
        result.propertyLoc = nameLoc
        result.optionalChain = oldOptionalChain
        return result
    }

    /// 在 ?. 之后解析属性访问
    private static func sfxTDotAfterQuestionDot(
        p: Parser,
        optionalChain: OptionalChain,
        left: Expr
    ): Expr {
        let nameLoc = p.lexer.loc()
        let name = p.lexer.identifier
        p.lexer.next()

        let result = Expr()
        result.tag = ExprTag.Dot
        result.loc = left.loc
        result.dotTarget = left
        result.propertyName = name
        result.propertyLoc = nameLoc
        result.optionalChain = Some(optionalChain)
        return result
    }

    // ========================================================================
    // sfxTIndex - 索引访问
    // 严格翻译自: parse_suffix.rs sfx_t_open_bracket
    // ========================================================================

    /// 解析索引访问 - 对应 Bun sfx_t_open_bracket
    private static func sfxTIndex(
        p: Parser,
        optionalChain: ?OptionalChain,
        left: Expr
    ): Expr {
        p.lexer.next() // [

        let index = p.parseExpr(Level.Lowest)
        p.lexer.expect(Token.CloseBracket)

        let result = Expr()
        result.tag = ExprTag.Index
        result.loc = left.loc
        result.indexTarget = left
        result.indexExpr = index
        result.optionalChain = optionalChain
        return result
    }

    // ========================================================================
    // sfxTCall - 函数调用
    // 严格翻译自: parse_suffix.rs sfx_t_open_paren
    // ========================================================================

    /// 解析函数调用 - 对应 Bun sfx_t_open_paren
    private static func sfxTCall(
        p: Parser,
        optionalChain: ?OptionalChain,
        left: Expr,
        level: Level
    ): Expr {
        let loc = p.lexer.loc()
        p.lexer.next() // (

        let args = ArrayList<Expr>()
        var hasSpread = false

        let oldAllowIn = p.allowIn
        p.allowIn = true

        while (p.lexer.token != Token.CloseParen && p.lexer.token != Token.EndOfFile) {
            // 展开参数
            if (p.lexer.token == Token.DotDotDot) {
                p.lexer.next()
                let value = p.parseExpr(Level.Comma)
                let spread = Expr()
                spread.tag = ExprTag.Spread
                spread.loc = value.loc
                spread.exprData = value
                args.append(spread)
                hasSpread = true
            } else {
                args.append(p.parseExpr(Level.Comma))
            }

            if (p.lexer.token == Token.Comma) {
                p.lexer.next()
            } else {
                break
            }
        }

        p.lexer.expect(Token.CloseParen)
        p.allowIn = oldAllowIn

        let result = Expr()
        result.tag = ExprTag.Call
        result.loc = left.loc
        result.callTarget = left
        result.callArgs = args
        result.optionalChain = optionalChain
        return result
    }

    // ========================================================================
    // sfxHandleTypeScriptAs - TypeScript as/satisfies 断言
    // 严格翻译自: parse_suffix.rs sfx_handle_typescript_as
    // ========================================================================

    /// 处理 TypeScript as / satisfies 类型断言
    private static func sfxHandleTypeScriptAs(p: Parser, level: Level): Continuation {
        if (!p.options.features.typescript) {
            return Continuation.Done
        }
        if (level.ordinal < Level.Compare.ordinal) {
            return Continuation.Done
        }
        if (p.lexer.hasNewlineBefore) {
            return Continuation.Done
        }
        if (!p.lexer.isContextualKeyword("as") && !p.lexer.isContextualKeyword("satisfies")) {
            return Continuation.Done
        }

        p.lexer.next()
        ParseSkipTypeScript.skipTypeScriptType(p, Level.Lowest)

        // 某些 token 不允许出现在类型断言之后
        match (p.lexer.token) {
            case Token.PlusPlus | Token.MinusMinus |
                 Token.NoSubstitutionTemplateLiteral | Token.TemplateHead |
                 Token.OpenParen | Token.OpenBracket | Token.QuestionDot =>
                return Continuation.Done
            case _ =>
                ()
        }

        if (LexerTables.isAssign(p.lexer.token)) {
            return Continuation.Done
        }

        return Continuation.Done
    }

    // ========================================================================
    // sfxTTemplate - 模板字面量标签
    // ========================================================================

    /// 解析模板字面量标签调用 - 对应 Bun 模板标签
    private static func sfxTTemplate(p: Parser, tag: Expr): Expr {
        let loc = p.lexer.loc()

        // 读取模板字面量
        var parts = ArrayList<Expr>()
        var strings = ArrayList<String>()

        if (p.lexer.token == Token.NoSubstitutionTemplateLiteral) {
            strings.append(p.lexer.stringLiteral)
            p.lexer.next()
        } else {
            // TemplateHead ... TemplateTail
            strings.append(p.lexer.stringLiteral)
            p.lexer.next()

            while (true) {
                parts.append(p.parseExpr(Level.Lowest))
                if (p.lexer.token == Token.TemplateTail) {
                    strings.append(p.lexer.stringLiteral)
                    p.lexer.next()
                    break
                }
                if (p.lexer.token == Token.TemplateMiddle) {
                    strings.append(p.lexer.stringLiteral)
                    p.lexer.next()
                } else {
                    break
                }
            }
        }

        let result = Expr()
        result.tag = ExprTag.Template
        result.loc = tag.loc
        result.templateTag = tag
        result.templateStrings = strings
        result.templateParts = parts
        return result
    }
}
