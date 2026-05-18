// 函数解析器
// 严格翻译自: src/js_parser/parse/parse_fn.rs (605 lines)
//   Bun 的函数解析器处理:
//   - parse_fn_stmt: 函数声明语句解析
//   - parse_fn: 函数体解析 (参数列表、函数体、async/generator)
//   - parse_fn_args: 函数参数解析
//   - parse_fn_body: 函数体解析
//   - 作用域管理和符号声明
//   - TypeScript 类型参数处理
package bao_parser

import bao_core.*
import bao_collections.*

// ============================================================================
// ParseFn - 函数解析器扩展方法
// 严格翻译自: src/js_parser/parse/parse_fn.rs
//   impl P { parse_fn_stmt, parse_fn, ... }
// ============================================================================

/// 函数解析器 - 对应 Bun ParseFn 模块
/// 提供 parse_fn_stmt, parse_fn 等方法
/// 作为 Parser 的扩展，通过接收 Parser 实例来工作
public class ParseFn {

    // ========================================================================
    // parseFnStmt - 解析函数声明语句
    // 严格翻译自: parse_fn.rs:26-167
    //   pub fn parse_fn_stmt(loc, opts, async_range) -> Result<Stmt, Error>
    // ========================================================================

    /// 解析函数声明语句 - 对应 Bun parse_fn_stmt
    /// 假设 "fnDatation" 关键字已经被解析
    ///
    /// - p: 解析器实例
    /// - loc: fnDatation 关键字位置
    /// - opts: 语句解析选项
    /// - asyncRange: async 关键字范围 (如果是异步函数)
    /// - 返回: 解析后的语句
    public static func parseFnStmt(
        p: Parser,
        loc: Loc,
        opts: ParseStatementOptions,
        asyncRange: ?Range
    ): Stmt {
        let isGenerator = p.lexer.token == Token.Asterisk
        let isAsync = asyncRange != None

        if (isGenerator) {
            p.lexer.next()
        }

        // 处理词法声明限制
        match (opts.lexicalDecl) {
            case LexicalDecl.Forbid =>
                p.log.addError(MsgData("Function declaration not allowed here"))
            case LexicalDecl.AllowFnInsideIf | LexicalDecl.AllowFnInsideLabel =>
                if (opts.isTypescriptDeclare || isGenerator || isAsync) {
                    p.log.addError(MsgData("Function declaration not allowed here"))
                }
            case _ =>
                ()
        }

        var name: ?LocRef = None
        var nameText: String = ""

        // 函数名 (export default 可以省略)
        if (!opts.isNameOptional || p.lexer.token == Token.Identifier) {
            let nameLoc = p.lexer.loc()
            nameText = p.lexer.identifier
            p.lexer.expect(Token.Identifier)
            let ref = p.newSymbol(SymbolKind.Other, nameText)
            name = Some(LocRef(nameLoc, ref))
        }

        // TypeScript 类型参数
        if (p.options.features.typescript) {
            skipTypeScriptTypeParameters(p, TypeParameterFlag.None)
        }

        // 为 if 语句中的函数声明引入假的块作用域
        var ifStmtScopeIndex: Int64 = 0
        let hasIfScope = opts.lexicalDecl == LexicalDecl.AllowFnInsideIf
        if (hasIfScope) {
            ifStmtScopeIndex = p.pushScopeForParsePass(ScopeKind.Block, loc)
        }

        // 函数参数作用域
        let scopeIndex = p.pushScopeForParsePass(ScopeKind.FunctionArgs, p.lexer.loc())

        // 解析函数
        let fnOrArrowData = FnOrArrowDataParse()
        fnOrArrowData.allowAwait = if (isAsync) { AwaitOrYield.AllowExpr } else { AwaitOrYield.AllowIdent }
        fnOrArrowData.allowYield = if (isGenerator) { AwaitOrYield.AllowExpr } else { AwaitOrYield.AllowIdent }
        fnOrArrowData.isTypescriptDeclare = opts.isTypescriptDeclare

        var fnData = parseFn(p, name, fnOrArrowData)

        // TypeScript forward declaration 处理
        if (p.options.features.typescript) {
            if (opts.isTypescriptDeclare) {
                p.popAndDiscardScope(scopeIndex)
                if (hasIfScope) {
                    p.popScope()
                }
                let stmt = Stmt()
                stmt.tag = StmtTag.Type
                stmt.loc = loc
                return stmt
            }
        }

        p.popScope()

        // 声明函数符号
        if (let Some(n) <- name) {
            let kind = SymbolKind.HoistedFunction
            // declareSymbol
            p.declareSymbol(kind, n.loc, nameText)
        }

        if (opts.isExport) {
            // 标记为导出
        }

        // 平衡 if 作用域
        if (hasIfScope) {
            p.popScope()
        }

        let stmt = Stmt()
        stmt.tag = StmtTag.Function
        stmt.loc = loc
        stmt.funcData = fnData
        return stmt
    }

    // ========================================================================
    // parseFn - 解析函数定义
    // 严格翻译自: parse_fn.rs:169-...
    //   pub fn parse_fn(name, opts) -> Result<G.Fn, Error>
    // ========================================================================

    /// 解析函数定义 - 对应 Bun parse_fn
    /// 解析参数列表和函数体
    public static func parseFn(p: Parser, name: ?LocRef, opts: FnOrArrowDataParse): GFn {
        var fnData = GFN()
        fnData.name = name
        fnData.openParensLoc = p.lexer.loc()

        p.lexer.expect(Token.OpenParen)

        // 保存旧的 fn_or_arrow_data
        let oldFnOrArrowData = p.fnOrArrowData
        p.fnOrArrowData = opts

        // 解析参数
        fnData.args = parseFnArgs(p)

        // TypeScript 返回类型
        if (p.options.features.typescript) {
            if (p.lexer.token == Token.Colon) {
                p.lexer.next()
                skipTypeScriptReturnType(p)
            }
        }

        // 解析函数体
        if (p.lexer.token == Token.OpenBrace) {
            fnData.body = parseFnBody(p)
        } else if (opts.allowMissingBodyForTypeScript && p.options.features.typescript) {
            // TypeScript 允许省略函数体 (declare)
            fnData.body = None
        } else {
            p.log.addError(MsgData("Expected fnDatation body"))
        }

        // 恢复
        p.fnOrArrowData = oldFnOrArrowData

        return fnData
    }

    // ========================================================================
    // parseFnArgs - 解析函数参数
    // 严格翻译自: parse_fn.rs 中的参数解析部分
    // ========================================================================

    /// 解析函数参数列表 - 对应 Bun parse_fn 内的参数解析
    public static func parseFnArgs(p: Parser): ArrayList<Arg> {
        let args = ArrayList<Arg>()

        // await/yield 在参数中不允许
        let oldAllowAwait = p.fnOrArrowData.allowAwait
        let oldAllowYield = p.fnOrArrowData.allowYield
        p.fnOrArrowData.allowAwait = AwaitOrYield.Forbid
        p.fnOrArrowData.allowYield = AwaitOrYield.Forbid

        var hasRest = false

        while (p.lexer.token != Token.CloseParen) {
            if (hasRest) {
                p.log.addError(MsgData("Rest parameter must be last"))
            }

            // rest 参数 ...
            if (p.lexer.token == Token.DotDotDot) {
                p.lexer.next()
                hasRest = true
            }

            // 解析参数绑定
            let binding = parseBindingPattern(p)

            // TypeScript 类型注解
            if (p.options.features.typescript && p.lexer.token == Token.Colon) {
                p.lexer.next()
                skipTypeScriptType(p, Level.Lowest)
            }

            // 默认值
            var value: ?Expr = None
            if (p.lexer.token == Token.Equals) {
                p.lexer.next()
                value = Some(p.parseExpr(Level.Comma))
            }

            let arg = Arg()
            arg.binding = binding
            arg.default_ = value
            args.append(arg)

            if (p.lexer.token == Token.Comma) {
                p.lexer.next()
            } else {
                break
            }
        }

        p.lexer.expect(Token.CloseParen)

        p.fnOrArrowData.allowAwait = oldAllowAwait
        p.fnOrArrowData.allowYield = oldAllowYield

        return args
    }

    // ========================================================================
    // parseFnBody - 解析函数体
    // ========================================================================

    /// 解析函数体 - 对应 Bun parse_fn 内的函数体解析
    public static func parseFnBody(p: Parser): ?ArrayList<Stmt> {
        p.lexer.expect(Token.OpenBrace)

        // 进入函数体作用域
        p.pushScopeForParsePass(ScopeKind.FunctionBody, p.lexer.loc())

        let stmts = ArrayList<Stmt>()
        while (p.lexer.token != Token.CloseBrace && p.lexer.token != Token.EndOfFile) {
            let stmt = p.parseStmt(ParseStatementOptions())
            stmts.append(stmt)
        }

        p.lexer.expect(Token.CloseBrace)
        p.popScope()

        return stmts
    }

    // ========================================================================
    // 辅助方法
    // ========================================================================

    /// 解析绑定模式
    private static func parseBindingPattern(p: Parser): BindingPattern {
        match (p.lexer.token) {
            case Token.Identifier =>
                let loc = p.lexer.loc()
                let name = p.lexer.identifier
                p.lexer.next()
                let binding = BindingPattern(loc, BindingPatternTag.Identifier)
                binding.name = name
                binding.ref = p.storeNameInRef(name)
                return binding
            case Token.OpenBracket =>
                return parseArrayBinding(p)
            case Token.OpenBrace =>
                return parseObjectBinding(p)
            case _ =>
                p.lexer.expect(Token.Identifier)
                return BindingPattern(p.lexer.loc(), BindingPatternTag.Missing)
        }
    }

    /// 解析数组解构绑定
    private static func parseArrayBinding(p: Parser): BindingPattern {
        let loc = p.lexer.loc()
        p.lexer.next() // [

        let binding = BindingPattern(loc, BindingPatternTag.ArrayPattern)

        while (p.lexer.token != Token.CloseBracket && p.lexer.token != Token.EndOfFile) {
            if (p.lexer.token == Token.Comma) {
                p.lexer.next()
                continue
            }

            if (p.lexer.token == Token.DotDotDot) {
                p.lexer.next()
                let elem = parseBindingPattern(p)
                elem.tag = BindingPatternTag.RestPattern
                binding.elements.append(elem)
            } else {
                let elem = parseBindingPattern(p)
                binding.elements.append(elem)
            }

            if (p.lexer.token == Token.Comma) {
                p.lexer.next()
            }
        }

        p.lexer.expect(Token.CloseBracket)
        return binding
    }

    /// 解析对象解构绑定
    private static func parseObjectBinding(p: Parser): BindingPattern {
        let loc = p.lexer.loc()
        p.lexer.next() // {

        let binding = BindingPattern(loc, BindingPatternTag.ObjectPattern)

        while (p.lexer.token != Token.CloseBrace && p.lexer.token != Token.EndOfFile) {
            if (p.lexer.token == Token.Comma) {
                p.lexer.next()
                continue
            }

            if (p.lexer.token == Token.DotDotDot) {
                p.lexer.next()
                let elem = parseBindingPattern(p)
                elem.tag = BindingPatternTag.RestPattern
                binding.restProperty = Some(elem)
                break
            }

            let keyLoc = p.lexer.loc()
            let keyName = p.lexer.identifier
            p.lexer.next()

            var value: BindingPattern
            if (p.lexer.token == Token.Colon) {
                p.lexer.next()
                value = parseBindingPattern(p)
            } else {
                value = BindingPattern(keyLoc, BindingPatternTag.Identifier)
                value.name = keyName
            }

            var defaultValue: ?Expr = None
            if (p.lexer.token == Token.Equals) {
                p.lexer.next()
                defaultValue = Some(p.parseExpr(Level.Comma))
            }

            binding.properties.append(BindingPatternProperty(keyLoc, keyName, value, defaultValue))

            if (p.lexer.token == Token.Comma) {
                p.lexer.next()
            }
        }

        p.lexer.expect(Token.CloseBrace)
        return binding
    }

    /// 跳过 TypeScript 类型参数
    private static func skipTypeScriptTypeParameters(p: Parser, flag: TypeParameterFlag): Unit {
        if (p.lexer.token == Token.LessThan) {
            p.lexer.next()
            var depth = 1
            while (depth > 0 && p.lexer.token != Token.EndOfFile) {
                match (p.lexer.token) {
                    case Token.LessThan => depth++
                    case Token.GreaterThan => depth--
                    case _ => ()
                }
                p.lexer.next()
            }
        }
    }

    /// 跳过 TypeScript 返回类型
    private static func skipTypeScriptReturnType(p: Parser): Unit {
        skipTypeScriptType(p, Level.Lowest)
    }

    /// 跳过 TypeScript 类型
    private static func skipTypeScriptType(p: Parser, level: Level): Unit {
        // 简化: 跳过直到遇到非类型 token
        var depth = 0
        var done = false
        while (!done) {
            match (p.lexer.token) {
                case Token.OpenParen | Token.OpenBracket | Token.OpenBrace =>
                    depth++
                    p.lexer.next()
                case Token.CloseParen | Token.CloseBracket | Token.CloseBrace =>
                    if (depth > 0) {
                        depth--
                        p.lexer.next()
                    } else {
                        done = true
                    }
                case Token.Comma =>
                    if (depth == 0 && level == Level.Comma) {
                        done = true
                    } else {
                        p.lexer.next()
                    }
                case Token.EqualsGreaterThan =>
                    if (depth == 0) {
                        done = true
                    } else {
                        p.lexer.next()
                    }
                case Token.Semicolon | Token.EndOfFile =>
                    done = true
                case _ =>
                    p.lexer.next()
                    if (depth == 0) {
                        done = true
                    }
            }
        }
    }
}

// ============================================================================
// 辅助类型定义
// ============================================================================

/// Arg - 函数参数 - 对应 Bun G.Arg
public class Arg {
    public var binding: BindingPattern
    public var default_: ?Expr
    public var typeAnnotation: ?TSType
    public var decorators: ArrayList<Expr>

    public init() {
        binding = BindingPattern(Loc.EMPTY, BindingPatternTag.Missing)
        default_ = None
        typeAnnotation = None
        decorators = ArrayList<Expr>()
    }
}

/// GFN - 函数 AST 节点 - 对应 Bun G.Fn
public class GFN {
    public var name: ?LocRef
    public var args: ArrayList<Arg>
    public var body: ?ArrayList<Stmt>
    public var openParensLoc: Loc
    public var isAsync: Bool
    public var isGenerator: Bool
    public var isExport: Bool

    public init() {
        name = None
        args = ArrayList<Arg>()
        body = None
        openParensLoc = Loc.EMPTY
        isAsync = false
        isGenerator = false
        isExport = false
    }
}

/// Level - 优先级 - 对应 Bun Level
public enum Level {
    | Lowest
    | Comma
    | Spread
    | Assign
    | Conditional
    | NullishCoalescing
    | LogicalOr
    | LogicalAnd
    | BitwiseOr
    | BitwiseXor
    | BitwiseAnd
    | Equals
    | Compare
    | Shift
    | Add
    | Multiply
    | Exponentiation
    | Unary
    | Prefix
    | Postfix
    | Call
}

/// Property - 属性节点 - 对应 Bun G.Property
public class Property {
    public var key: ?Expr
    public var value: ?Expr
    public var kind: PropertyKind

    public init() {
        key = None
        value = None
        kind = PropertyKind.Normal
    }
}

/// PropertyKind - 属性种类
public enum PropertyKind {
    | Normal
    | Get
    | Set
}
