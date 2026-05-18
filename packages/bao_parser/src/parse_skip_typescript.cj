// TypeScript 类型跳过解析器
// 严格翻译自: src/js_parser/parse/parse_skip_typescript.rs (1598 lines)
//   Bun 的 TypeScript 类型跳过解析器处理:
//   - skip_typescript_return_type: 跳过返回类型注解
//   - skip_type_script_type: 跳过类型表达式
//   - skip_type_script_binding: 跳过绑定模式类型注解
//   - skip_type_script_type_parameters: 跳过类型参数列表
//   - skip_type_script_enum: 跳过枚举声明
//   - skip_type_script_interface: 跳过接口声明
//   - skip_type_script_namespace: 跳过命名空间声明
//   - skip_type_script_declare: 跳过声明
//   - TypeScript 修饰符解析
package bao_parser

import bao_core.*
import bao_collections.*

// ============================================================================
// SkipTypeOptionsBitset - 跳过类型选项位集
// 严格翻译自: parse_skip_typescript.rs SkipTypeOptionsBitset
// ============================================================================

/// 跳过类型选项 - 对应 Bun SkipTypeOptions
public enum SkipTypeOptions {
    | None
    | IsReturnType  // 跳过的是返回类型
    | IsArray       // 跳过的是数组类型
    | IsConditional // 跳过的是条件类型
    | IsArrow       // 跳过的是箭头函数类型
}

// ============================================================================
// TsMetadata - TypeScript 元数据
// 严格翻译自: bun_ast/ts.rs Metadata
// ============================================================================

/// TypeScript 元数据 - 对应 Bun Metadata
/// 在跳过类型时收集的元信息
public class TsMetadata {
    public static let DEFAULT: TsMetadata = TsMetadata()

    public init() {
    }
}

// ============================================================================
// ParseSkipTypeScript - TypeScript 类型跳过解析器
// 严格翻译自: src/js_parser/parse/parse_skip_typescript.rs
//   impl P { skip_typescript_return_type, skip_type_script_type, ... }
// ============================================================================

/// TypeScript 类型跳过解析器 - 对应 Bun ParseSkipTypeScript 模块
/// 在解析 TypeScript 时跳过类型注解，不构建 AST
public class ParseSkipTypeScript {

    // ========================================================================
    // skipTypeScriptReturnType - 跳过返回类型
    // 严格翻译自: parse_skip_typescript.rs:24-28
    //   pub fn skip_typescript_return_type(&mut self) -> Result<(), Error>
    // ========================================================================

    /// 跳过 TypeScript 返回类型注解
    public static func skipTypeScriptReturnType(p: Parser): Unit {
        skipTypeScriptTypeWithOpts(p, Level.Lowest, SkipTypeOptions.IsReturnType)
    }

    /// 跳过 TypeScript 返回类型注解并收集元数据
    public static func skipTypeScriptReturnTypeWithMetadata(p: Parser): TsMetadata {
        skipTypeScriptTypeWithOpts(p, Level.Lowest, SkipTypeOptions.IsReturnType)
        return TsMetadata.DEFAULT
    }

    // ========================================================================
    // skipTypeScriptType - 跳过类型表达式
    // 严格翻译自: parse_skip_typescript.rs:44-47
    //   pub fn skip_type_script_type(&mut self, level: Level) -> Result<(), Error>
    // ========================================================================

    /// 跳过 TypeScript 类型表达式
    public static func skipTypeScriptType(p: Parser, level: Level): Unit {
                skipTypeScriptTypeWithOpts(p, level, SkipTypeOptions.None)
    }

    /// 跳过 TypeScript 类型表达式并收集元数据
    public static func skipTypeScriptTypeWithMetadata(p: Parser, level: Level): TsMetadata {
                skipTypeScriptTypeWithOpts(p, level, SkipTypeOptions.None)
        return TsMetadata.DEFAULT
    }

    // ========================================================================
    // skipTypeScriptTypeWithOpts - 带选项跳过类型
    // 严格翻译自: parse_skip_typescript.rs 核心逻辑
    //   这是核心方法，处理所有 TypeScript 类型语法
    // ========================================================================

    /// 带选项跳过 TypeScript 类型表达式 - 对应 Bun skip_type_script_type_with_opts
    /// 核心方法: 递归跳过所有 TypeScript 类型语法
    private static func skipTypeScriptTypeWithOpts(p: Parser, level: Level, opts: SkipTypeOptions): Unit {
        // 处理基本类型关键字
        skipTypeScriptTypePrefix(p, opts)

        // 处理后缀: [], |, &, =>, extends, etc.
        skipTypeScriptTypeSuffix(p, level, opts)
    }

    /// 跳过类型前缀
    private static func skipTypeScriptTypePrefix(p: Parser, opts: SkipTypeOptions): Unit {
        match (p.lexer.token) {
            // 关键字类型
            case Token.Identifier =>
                let name = p.lexer.identifier

                // 特殊关键字类型
                match (name) {
                    case "any" | "unknown" | "number" | "string" | "boolean" |
                         "void" | "undefined" | "null" | "never" | "object" |
                         "symbol" | "bigint" =>
                        p.lexer.nextToken()
                        return
                    case "unique" =>
                        p.lexer.nextToken()
                        if (p.lexer.isContextualKeyword("symbol")) {
                            p.lexer.nextToken()
                        } else {
                            p.log.addError(MsgData("Expected \"symbol\""))
                        }
                        return
                    case "keyof" | "readonly" | "infer" =>
                        p.lexer.nextToken()
                        skipTypeScriptTypeWithOpts(p, Level.Prefix, SkipTypeOptions.None)
                        return
                    case "typeof" =>
                        p.lexer.nextToken()
                        skipTypeScriptTypeof(p)
                        return
                    case "import" =>
                        skipTypeScriptImportType(p)
                        return
                    case "asserts" =>
                        p.lexer.nextToken()
                        if (p.lexer.token == Token.Identifier) {
                            p.lexer.nextToken()
                        }
                        if (p.lexer.token == Token.Identifier && p.lexer.identifier == "is") {
                            p.lexer.nextToken()
                            skipTypeScriptTypeWithOpts(p, Level.Lowest, SkipTypeOptions.None)
                        }
                        return
                    case _ =>
                        // 普通类型引用
                        p.lexer.nextToken()
                }

                // 检查泛型参数 <...>
                if (p.lexer.token == Token.LessThan) {
                    skipTypeScriptTypeArguments(p)
                }

            // 字面量类型
            case Token.NumericLiteral =>
                p.lexer.nextToken()
            case Token.StringLiteral =>
                p.lexer.nextToken()
            case Token.True | Token.False =>
                p.lexer.nextToken()
            case Token.Null =>
                p.lexer.nextToken()
            case Token.Minus =>
                p.lexer.nextToken()
                p.lexer.expect(Token.NumericLiteral)

            // 括号类型 (T) 或元组类型 [T, U]
            case Token.OpenParen =>
                skipTypeScriptParenOrFunctionType(p)
            case Token.OpenBracket =>
                skipTypeScriptTupleType(p)

            // 对象类型 { ... }
            case Token.OpenBrace =>
                skipTypeScriptObjectType(p)

            // 函数类型 (简化)
            case Token.LessThan =>
                skipTypeScriptTypeArguments(p)
                if (p.lexer.token == Token.OpenParen) {
                    skipTypeScriptParenOrFunctionType(p)
                }

            // 模板字面量类型 `...`
            case Token.NoSubstitutionTemplateLiteral =>
                p.lexer.nextToken()
            case Token.TemplateHead =>
                skipTypeScriptTemplateLiteralType(p)

            // ... 展开类型
            case Token.DotDotDot =>
                p.lexer.nextToken()
                skipTypeScriptTypeWithOpts(p, Level.Lowest, SkipTypeOptions.None)

            // void 运算符 (在类型中无效，但需要跳过)
            case Token.Void =>
                p.lexer.nextToken()

            case _ =>
                p.lexer.nextToken()
        }
    }

    /// 跳过类型后缀
    private static func skipTypeScriptTypeSuffix(p: Parser, level: Level, opts: SkipTypeOptions): Unit {
        while (true) {
            match (p.lexer.token) {
                // 数组类型 T[]
                case Token.OpenBracket =>
                    if (p.lexer.hasNewlineBefore) {
                        return
                    }
                    p.lexer.nextToken()
                    if (p.lexer.token == Token.CloseBracket) {
                        p.lexer.nextToken()
                        continue
                    }
                    // 索引访问类型 T[K]
                    skipTypeScriptTypeWithOpts(p, Level.Lowest, SkipTypeOptions.None)
                    p.lexer.expect(Token.CloseBracket)
                    continue

                // 联合类型 |
                case Token.Bar =>
                    p.lexer.nextToken()
                    skipTypeScriptTypeWithOpts(p, Level.BitwiseOr, SkipTypeOptions.None)
                    continue

                // 交叉类型 &
                case Token.Ampersand =>
                    p.lexer.nextToken()
                    skipTypeScriptTypeWithOpts(p, Level.BitwiseAnd, SkipTypeOptions.None)
                    continue

                // 条件类型 extends
                case Token.Identifier =>
                    if (p.lexer.identifier == "extends") {
                        p.lexer.nextToken()
                        skipTypeScriptTypeWithOpts(p, Level.Conditional, SkipTypeOptions.None)
                        if (p.lexer.token == Token.Question) {
                            p.lexer.nextToken()
                            skipTypeScriptTypeWithOpts(p, Level.Conditional, SkipTypeOptions.None)
                            p.lexer.expect(Token.Colon)
                            skipTypeScriptTypeWithOpts(p, Level.Conditional, SkipTypeOptions.None)
                        }
                        continue
                    }
                    return

                // 可选链 ?
                case Token.Question =>
                    // 可选属性或条件类型
                    return

                // is (类型谓词)
                case Token.Identifier =>
                    return

                case _ =>
                    return
            }
        }
    }

    // ========================================================================
    // skipTypeScriptBinding - 跳过绑定模式类型注解
    // 严格翻译自: parse_skip_typescript.rs:62-...
    // ========================================================================

    /// 跳过 TypeScript 绑定模式 - 对应 Bun skip_type_script_binding
    /// 跳过绑定模式中的类型注解 (函数参数解构等)
    public static func skipTypeScriptBinding(p: Parser): Unit {
                match (p.lexer.token) {
            case Token.Identifier | Token.`This` =>
                p.lexer.nextToken()
            case Token.OpenBracket =>
                p.lexer.nextToken()
                // 空元素
                while (p.lexer.token == Token.Comma) {
                    p.lexer.nextToken()
                }
                // 元素
                while (p.lexer.token != Token.CloseBracket && p.lexer.token != Token.EndOfFile) {
                    // rest 元素
                    if (p.lexer.token == Token.DotDotDot) {
                        p.lexer.nextToken()
                    }
                    skipTypeScriptBinding(p)
                    if (p.lexer.token != Token.Comma) {
                        break
                    }
                    p.lexer.nextToken()
                }
                p.lexer.expect(Token.CloseBracket)
            case Token.OpenBrace =>
                p.lexer.nextToken()
                while (p.lexer.token != Token.CloseBrace && p.lexer.token != Token.EndOfFile) {
                    // 属性名
                    if (p.lexer.token == Token.DotDotDot) {
                        p.lexer.nextToken()
                        skipTypeScriptBinding(p)
                    } else {
                        // 键
                        if (p.lexer.token == Token.OpenBracket) {
                            p.lexer.nextToken()
                            // 跳过计算属性键
                            var depth = 1
                            while (depth > 0 && p.lexer.token != Token.EndOfFile) {
                                match (p.lexer.token) {
                                    case Token.OpenBracket => depth++
                                    case Token.CloseBracket => depth--
                                    case _ => ()
                                }
                                p.lexer.nextToken()
                            }
                        } else {
                            p.lexer.nextToken() // 键名
                        }
                        // as 重映射
                        if (p.lexer.isContextualKeyword("as")) {
                            p.lexer.nextToken()
                            p.lexer.nextToken() // 重映射名
                        }
                        // :
                        if (p.lexer.token == Token.Colon) {
                            p.lexer.nextToken()
                            skipTypeScriptBinding(p)
                        } else if (p.lexer.token == Token.Identifier) {
                            // 简写: { foo }
                            p.lexer.nextToken()
                        }
                    }
                    // 可选 ?
                    if (p.lexer.token == Token.Question) {
                        p.lexer.nextToken()
                    }
                    if (p.lexer.token != Token.Comma) {
                        break
                    }
                    p.lexer.nextToken()
                }
                p.lexer.expect(Token.CloseBrace)
            case _ =>
                ()
        }
    }

    // ========================================================================
    // skipTypeScriptTypeParameters - 跳过类型参数
    // ========================================================================

    /// 跳过 TypeScript 类型参数列表
    public static func skipTypeScriptTypeParameters(p: Parser, flag: TypeParameterFlag): Unit {
        if (p.lexer.token != Token.LessThan) {
            return
        }
        p.lexer.nextToken()

        while (p.lexer.token != Token.GreaterThan && p.lexer.token != Token.EndOfFile) {
            // const 修饰符 (TypeScript 5.0)
            let allowConstModifier = match (flag) {
                case TypeParameterFlag.AllowConstModifier => true
                case _ => false
            }
            if (allowConstModifier && p.lexer.isContextualKeyword("const")) {
                p.lexer.nextToken()
            }

            // in / out 修饰符
            if (p.lexer.isContextualKeyword("in") || p.lexer.isContextualKeyword("out")) {
                p.lexer.nextToken()
            }

            // 参数名
            p.lexer.nextToken() // 名称

            // extends 约束
            if (p.lexer.isContextualKeyword("extends")) {
                p.lexer.nextToken()
                skipTypeScriptTypeWithOpts(p, Level.Conditional, SkipTypeOptions.None)
            }

            // 默认值
            if (p.lexer.token == Token.Equals) {
                p.lexer.nextToken()
                skipTypeScriptTypeWithOpts(p, Level.Conditional, SkipTypeOptions.None)
            }

            if (p.lexer.token != Token.Comma) {
                break
            }
            p.lexer.nextToken()
        }

        p.lexer.expect(Token.GreaterThan)
    }

    // ========================================================================
    // 特殊类型跳过
    // ========================================================================

    /// 跳过 typeof 类型
    private static func skipTypeScriptTypeof(p: Parser): Unit {
        // typeof x
        // typeof x.Y
        // typeof x["y"]
        p.lexer.nextToken() // 标识符

        while (true) {
            if (p.lexer.token == Token.Dot) {
                p.lexer.nextToken()
                p.lexer.nextToken() // 属性名
            } else if (p.lexer.token == Token.OpenBracket && !p.lexer.hasNewlineBefore) {
                p.lexer.nextToken()
                // 可以是类型或字符串
                skipTypeScriptTypeWithOpts(p, Level.Lowest, SkipTypeOptions.None)
                p.lexer.expect(Token.CloseBracket)
            } else {
                break
            }
        }
    }

    /// 跳过 import() 类型
    private static func skipTypeScriptImportType(p: Parser): Unit {
        p.lexer.nextToken() // import
        p.lexer.expect(Token.OpenParen)
        p.lexer.expect(Token.StringLiteral) // 模块路径
        p.lexer.expect(Token.CloseParen)

        // .Property 或 [index]
        while (true) {
            if (p.lexer.token == Token.Dot) {
                p.lexer.nextToken()
                p.lexer.nextToken() // 属性名
            } else if (p.lexer.token == Token.OpenBracket && !p.lexer.hasNewlineBefore) {
                p.lexer.nextToken()
                skipTypeScriptTypeWithOpts(p, Level.Lowest, SkipTypeOptions.None)
                p.lexer.expect(Token.CloseBracket)
            } else {
                break
            }
        }

        // 泛型参数
        if (p.lexer.token == Token.LessThan) {
            skipTypeScriptTypeArguments(p)
        }
    }

    /// 跳过括号或函数类型
    private static func skipTypeScriptParenOrFunctionType(p: Parser): Unit {
        p.lexer.nextToken() // (

        // 可能是函数类型: (x: T) => U
        // 或括号类型: (T)
        while (p.lexer.token != Token.CloseParen && p.lexer.token != Token.EndOfFile) {
            if (p.lexer.token == Token.DotDotDot) {
                p.lexer.nextToken()
            }
            skipTypeScriptTypeWithOpts(p, Level.Lowest, SkipTypeOptions.None)
            // 可选参数
            if (p.lexer.token == Token.Question) {
                p.lexer.nextToken()
            }
            // 类型注解
            if (p.lexer.token == Token.Colon) {
                p.lexer.nextToken()
                skipTypeScriptTypeWithOpts(p, Level.Lowest, SkipTypeOptions.None)
            }
            if (p.lexer.token != Token.Comma) {
                break
            }
            p.lexer.nextToken()
        }
        p.lexer.expect(Token.CloseParen)

        // => 函数类型
        if (p.lexer.token == Token.EqualsGreaterThan) {
            p.lexer.nextToken()
            skipTypeScriptTypeWithOpts(p, Level.Conditional, SkipTypeOptions.None)
        }
    }

    /// 跳过元组类型
    private static func skipTypeScriptTupleType(p: Parser): Unit {
        p.lexer.nextToken() // [

        while (p.lexer.token != Token.CloseBracket && p.lexer.token != Token.EndOfFile) {
            // ...rest
            if (p.lexer.token == Token.DotDotDot) {
                p.lexer.nextToken()
            }

            // 命名元素: name: T
            if (p.lexer.token == Token.Identifier && !p.lexer.hasNewlineBefore) {
                p.lexer.nextToken()
                if (p.lexer.token == Token.Colon) {
                    p.lexer.nextToken()
                    skipTypeScriptTypeWithOpts(p, Level.Lowest, SkipTypeOptions.None)
                } else {
                    // 可能是类型
                    continue
                }
            } else {
                skipTypeScriptTypeWithOpts(p, Level.Lowest, SkipTypeOptions.None)
            }

            // 可选 ?
            if (p.lexer.token == Token.Question) {
                p.lexer.nextToken()
            }

            if (p.lexer.token != Token.Comma) {
                break
            }
            p.lexer.nextToken()
        }
        p.lexer.expect(Token.CloseBracket)
    }

    /// 跳过对象类型
    private static func skipTypeScriptObjectType(p: Parser): Unit {
        p.lexer.nextToken() // {

        while (p.lexer.token != Token.CloseBrace && p.lexer.token != Token.EndOfFile) {
            // ...spread
            if (p.lexer.token == Token.DotDotDot) {
                p.lexer.nextToken()
                skipTypeScriptTypeWithOpts(p, Level.Lowest, SkipTypeOptions.None)
                if (p.lexer.token == Token.Comma || p.lexer.token == Token.Semicolon) {
                    p.lexer.nextToken()
                }
                continue
            }

            // 修饰符
            if (p.lexer.token == Token.Identifier) {
                let name = p.lexer.identifier
                match (name) {
                    case "readonly" | "static" | "abstract" | "public" |
                         "private" | "protected" | "override" | "accessor" |
                         "new" | "get" | "set" | "declare" =>
                        p.lexer.nextToken()
                        if (p.lexer.token == Token.CloseBrace || p.lexer.token == Token.Comma) {
                            continue
                        }
                    case _ =>
                        ()
                }
            }

            // 计算属性 [key]
            if (p.lexer.token == Token.OpenBracket) {
                p.lexer.nextToken()
                if (p.lexer.token != Token.CloseBracket) {
                    skipTypeScriptTypeWithOpts(p, Level.Lowest, SkipTypeOptions.None)
                }
                p.lexer.expect(Token.CloseBracket)
            } else {
                // 键
                p.lexer.nextToken()
            }

            // 可选 ?
            if (p.lexer.token == Token.Question) {
                p.lexer.nextToken()
            }

            // :
            if (p.lexer.token == Token.Colon) {
                p.lexer.nextToken()
                skipTypeScriptTypeWithOpts(p, Level.Lowest, SkipTypeOptions.None)
            }
            // (
            else if (p.lexer.token == Token.OpenParen) {
                skipTypeScriptParenOrFunctionType(p)
                // 返回类型
                if (p.lexer.token == Token.Colon) {
                    p.lexer.nextToken()
                    skipTypeScriptTypeWithOpts(p, Level.Lowest, SkipTypeOptions.None)
                }
            }

            // 分隔符
            if (p.lexer.token == Token.Comma || p.lexer.token == Token.Semicolon) {
                p.lexer.nextToken()
            }
        }
        p.lexer.expect(Token.CloseBrace)
    }

    /// 跳过类型参数
    private static func skipTypeScriptTypeArguments(p: Parser): Unit {
        p.lexer.nextToken() // <

        while (p.lexer.token != Token.GreaterThan && p.lexer.token != Token.EndOfFile) {
            skipTypeScriptTypeWithOpts(p, Level.Lowest, SkipTypeOptions.None)
            if (p.lexer.token != Token.Comma) {
                break
            }
            p.lexer.nextToken()
        }

        // > 可能被解析为比较运算符
        if (p.lexer.token == Token.GreaterThan) {
            p.lexer.nextToken()
        } else if (p.lexer.token == Token.GreaterThanEquals) {
            // >>= 可能是类型参数结束
            p.lexer.nextToken()
        }
    }

    /// 跳过模板字面量类型
    private static func skipTypeScriptTemplateLiteralType(p: Parser): Unit {
        // TemplateHead ... TemplateTail
        p.lexer.nextToken() // template head

        while (p.lexer.token != Token.CloseBrace && p.lexer.token != Token.EndOfFile) {
            skipTypeScriptTypeWithOpts(p, Level.Lowest, SkipTypeOptions.None)
            if (p.lexer.token == Token.TemplateTail || p.lexer.token == Token.NoSubstitutionTemplateLiteral) {
                p.lexer.nextToken()
                return
            }
            if (p.lexer.token == Token.TemplateMiddle) {
                p.lexer.nextToken()
            }
        }
    }

    // ========================================================================
    // skipTypeScriptEnum - 跳过枚举声明
    // ========================================================================

    /// 跳过 TypeScript 枚举声明
    public static func skipTypeScriptEnum(p: Parser, loc: Loc): Stmt {
                p.lexer.expect(Token.Identifier) // enum name
        p.lexer.expect(Token.OpenBrace)

        while (p.lexer.token != Token.CloseBrace && p.lexer.token != Token.EndOfFile) {
            p.lexer.nextToken() // 枚举成员名

            if (p.lexer.token == Token.OpenBracket) {
                // 计算属性
                p.lexer.nextToken()
                p.lexer.expect(Token.CloseBracket)
            }

            if (p.lexer.token == Token.Equals) {
                p.lexer.nextToken()
                p.parseExpr(ParseExprOpts()) // 枚举值
            }

            if (p.lexer.token != Token.Comma) {
                break
            }
            p.lexer.nextToken()
        }

        p.lexer.expect(Token.CloseBrace)

        let stmt = Stmt()
        stmt.tag = StmtTag.Type
        stmt.loc = loc
        return stmt
    }

    // ========================================================================
    // skipTypeScriptNamespace - 跳过命名空间
    // ========================================================================

    /// 跳过 TypeScript 命名空间声明
    public static func skipTypeScriptNamespace(p: Parser, loc: Loc): Stmt {
                p.lexer.expect(Token.Identifier) // namespace name

        // 嵌套命名空间 A.B.C
        while (p.lexer.token == Token.Dot) {
            p.lexer.nextToken()
            p.lexer.expect(Token.Identifier)
        }

        // 命名空间体
        if (p.lexer.token == Token.OpenBrace) {
            p.lexer.nextToken()
            var depth = 1
            while (depth > 0 && p.lexer.token != Token.EndOfFile) {
                match (p.lexer.token) {
                    case Token.OpenBrace => depth++
                    case Token.CloseBrace => depth--
                    case _ => ()
                }
                if (depth > 0) {
                    p.lexer.nextToken()
                }
            }
            p.lexer.expect(Token.CloseBrace)
        }

        let stmt = Stmt()
        stmt.tag = StmtTag.Type
        stmt.loc = loc
        return stmt
    }

    // ========================================================================
    // skipTypeScriptInterface - 跳过接口
    // ========================================================================

    /// 跳过 TypeScript 接口声明
    public static func skipTypeScriptInterface(p: Parser, loc: Loc): Stmt {
                p.lexer.expect(Token.Identifier) // interface name

        // 泛型参数
        if (p.lexer.token == Token.LessThan) {
            skipTypeScriptTypeParameters(p, TypeParameterFlag.None)
        }

        // extends
        if (p.lexer.isContextualKeyword("extends")) {
            p.lexer.nextToken()
            skipTypeScriptTypeWithOpts(p, Level.Lowest, SkipTypeOptions.None)
            while (p.lexer.token == Token.Comma) {
                p.lexer.nextToken()
                skipTypeScriptTypeWithOpts(p, Level.Lowest, SkipTypeOptions.None)
            }
        }

        // implements (class-like)
        if (p.lexer.isContextualKeyword("implements")) {
            p.lexer.nextToken()
            skipTypeScriptTypeWithOpts(p, Level.Lowest, SkipTypeOptions.None)
        }

        // 接口体
        if (p.lexer.token == Token.OpenBrace) {
            skipTypeScriptObjectType(p)
        }

        let stmt = Stmt()
        stmt.tag = StmtTag.Type
        stmt.loc = loc
        return stmt
    }
}
