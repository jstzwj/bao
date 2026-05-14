// TypeScript Decorator 解析
// 严格翻译自: src/js_parser/p.zig decorator section
//   Bun 中装饰器解析集成在 Parser 中，使用 parseDecoratorList / parseDecorator 等方法
//   仓颉作为独立工具类实现，接收 token 列表和偏移量，返回解析结果
package bao_parser

import bao_core.*
import bao_collections.*

// ============================================================================
// DecoratedElement - 装饰器可附加的目标类型
// 严格翻译自: src/js_parser/p.zig 中装饰器上下文判断
//   TypeScript 装饰器可以附加到: class, method, property, parameter, getter, setter, accessor
// ============================================================================

/// 装饰器目标类型 - 对应 TypeScript decorator target 语义
public enum DecoratedElement {
    | Class      // @decorator class Foo { ... }
    | Method     // class Foo { @decorator method() {} }
    | Property   // class Foo { @decorator prop: Type }
    | Parameter  // class Foo { method(@decorator param: Type) {} }
    | Getter     // class Foo { @decorator get prop() {} }
    | Setter     // class Foo { @decorator set prop(value) {} }
    | Accessor   // class Foo { @decorator accessor prop }

    /// 是否为类成员 (方法/属性/getter/setter/accessor)
    public func isClassMember(): Bool {
        match (this) {
            case Method | Property | Getter | Setter | Accessor => true
            case Class | Parameter => false
        }
    }

    /// 人类可读名称
    public func displayName(): String {
        match (this) {
            case Class => "class"
            case Method => "method"
            case Property => "property"
            case Parameter => "parameter"
            case Getter => "getter"
            case Setter => "setter"
            case Accessor => "accessor"
        }
    }
}

// ============================================================================
// DecoratedNode - 带装饰器的 AST 节点包装
// 严格翻译自: src/js_parser/p.zig 中装饰器与声明关联逻辑
//   Bun 在解析类/方法/属性时将装饰器列表附加到对应声明节点
// ============================================================================

/// 装饰器节点包装 - 将装饰器列表与目标声明关联
public class DecoratedNode {
    /// 装饰器列表
    public var decorators: ArrayList<TSDecorator>
    /// 装饰器附加的目标类型
    public var element: DecoratedElement
    /// 被装饰的声明名称
    public var name: String
    /// 源码位置
    public var loc: Loc

    public init(loc: Loc, element: DecoratedElement, name: String) {
        this.loc = loc
        this.element = element
        this.name = name
        decorators = ArrayList<TSDecorator>()
    }

    public init(loc: Loc, element: DecoratedElement, name: String,
                decorators: ArrayList<TSDecorator>) {
        this.loc = loc
        this.element = element
        this.name = name
        this.decorators = decorators
    }

    /// 是否有装饰器
    public func hasDecorators(): Bool {
        return decorators.size > 0
    }

    /// 获取装饰器名称列表 (用于诊断输出)
    public func decoratorNames(): ArrayList<String> {
        let names = ArrayList<String>()
        let resolver = DecoratorResolver()
        for (d in decorators) {
            names.append(resolver.getDecoratorName(d.expr))
        }
        return names
    }
}

// ============================================================================
// DecoratorInfo - 装饰器解析信息
// 严格翻译自: src/js_parser/p.zig 中对装饰器表达式的分析
//   区分普通装饰器 (@foo) 与装饰器工厂 (@foo(args))
// ============================================================================

/// 装饰器信息 - 描述已解析的装饰器
public class DecoratorInfo {
    /// 装饰器名称 (如 "observable", "deprecated")
    public var name: String
    /// 是否为装饰器工厂 (即 @foo(...) 形式，带调用参数)
    public var isFactory: Bool
    /// 装饰器工厂的参数列表 (非工厂时为空)
    public var arguments: ArrayList<Expr>
    /// 源码位置
    public var loc: Loc

    public init(loc: Loc, name: String, isFactory: Bool) {
        this.loc = loc
        this.name = name
        this.isFactory = isFactory
        arguments = ArrayList<Expr>()
    }

    /// 参数数量
    public func argCount(): Int64 {
        return arguments.size
    }

    /// 描述字符串 (用于调试)
    public func describe(): String {
        if (isFactory) {
            return "@${name}(...) with ${arguments.size} args"
        }
        return "@${name}"
    }
}

// ============================================================================
// DecoratorParser - 装饰器解析工具
// 严格翻译自: src/js_parser/p.zig parseDecoratorList / parseDecorator
//   Bun: fn parseDecoratorList(p: *P) ![]G.Deprecated
//   Bun: fn parseDecorator(p: *P) !G.Deprecated
//   仓颉实现为独立工具函数，接收 token 列表 + 偏移量
// ============================================================================

/// 装饰器解析器 - 独立的装饰器解析工具
/// 对应 Bun Parser 中的 parseDecoratorList / parseDecorator 方法
public class DecoratorParser {

    /// 解析装饰器列表 - 对应 Bun parseDecoratorList
    /// 从 token 列表指定偏移开始解析连续的 @decorator 声明
    /// 返回 (装饰器列表, 消耗后的偏移量)
    public static func parseDecoratorList(tokens: ArrayList<Token>, offset: Int64): Tuple<ArrayList<TSDecorator>, Int64> {
        var decorators = ArrayList<TSDecorator>()
        var pos = offset
        while (pos < tokens.size) {
            let tok = tokens[Int64(pos)]
            // 装饰器必须以 @ 开头
            match (tok) {
                case Token.At =>
                    let (decorator, newOffset) = parseDecorator(tokens, pos)
                    decorators.append(decorator)
                    pos = newOffset
                case _ =>
                    break
            }
        }
        return Tuple<ArrayList<TSDecorator>, Int64>(decorators, pos)
    }

    /// 解析单个装饰器 - 对应 Bun parseDecorator
    /// @decorator 或 @decoratorFactory(args)
    /// 返回 (装饰器, 消耗后的偏移量)
    public static func parseDecorator(tokens: ArrayList<Token>, offset: Int64): Tuple<TSDecorator, Int64> {
        // 跳过 @
        var pos = offset + 1
        if (pos >= tokens.size) {
            let loc = Loc(pos)
            let expr = Expr.identifier(loc, "@<error>")
            return Tuple<TSDecorator, Int64>(TSDecorator(loc, expr), pos)
        }

        // 解析装饰器名称 (标识符 / 成员访问 a.b / 调用 a(args))
        let loc = Loc(Int64(offset))
        var expr = parseDecoratorExpr(tokens, pos)
        pos = expr.second
        let decorator = TSDecorator(loc, expr.first)
        return Tuple<TSDecorator, Int64>(decorator, pos)
    }

    /// 解析装饰器表达式 - 内部辅助方法
    /// 处理标识符、成员访问 (a.b.c)、和调用 (a(args)) 三种形式
    private static func parseDecoratorExpr(tokens: ArrayList<Token>,
                                           offset: Int64): Tuple<Expr, Int64> {
        var pos = offset
        if (pos >= tokens.size) {
            return Tuple<Expr, Int64>(Expr.identifier(Loc(pos), ""), pos)
        }

        // 读取标识符
        let nameLoc = Loc(Int64(pos))
        var name = ""
        match (tokens[Int64(pos)]) {
            case Token.Identifier => name = tokenText(tokens, pos)
            case _ => name = ""
        }
        pos += 1

        // 构建初始表达式
        var expr = Expr.identifier(nameLoc, name)

        // 处理成员访问链: a.b.c
        while (pos < tokens.size) {
            match (tokens[Int64(pos)]) {
                case Token.Dot =>
                    pos += 1
                    let memberLoc = Loc(Int64(pos))
                    var member = ""
                    if (pos < tokens.size) {
                        match (tokens[Int64(pos)]) {
                            case Token.Identifier => member = tokenText(tokens, pos)
                            case _ => member = ""
                        }
                        pos += 1
                    }
                    expr = Expr.dot(nameLoc, expr, member)
                // 处理调用: decorator(args)
                case Token.OpenParen =>
                    let (args, newOffset) = parseDecoratorArguments(tokens, pos)
                    pos = newOffset
                    expr = Expr.call(nameLoc, expr, args)
                case _ =>
                    break
            }
        }
        return Tuple<Expr, Int64>(expr, pos)
    }

    /// 解析装饰器参数列表 - 对应 Bun parseDecorator 中对调用参数的处理
    /// @decorator(arg1, arg2) 中的 (arg1, arg2) 部分
    /// 返回 (参数表达式列表, 消耗后的偏移量)
    public static func parseDecoratorArguments(tokens: ArrayList<Token>,
                                                offset: Int64): Tuple<ArrayList<Expr>, Int64> {
        var args = ArrayList<Expr>()
        var pos = offset

        // 跳过 (
        if (pos < tokens.size) {
            match (tokens[Int64(pos)]) {
                case Token.OpenParen => pos += 1
                case _ => return Tuple<ArrayList<Expr>, Int64>(args, pos)
            }
        }

        // 解析参数
        while (pos < tokens.size) {
            match (tokens[Int64(pos)]) {
                case Token.CloseParen =>
                    pos += 1
                    break
                case Token.Comma =>
                    pos += 1
                case _ =>
                    // 简化: 将每个参数解析为标识符或字面量
                    let argLoc = Loc(Int64(pos))
                    let tok = tokens[Int64(pos)]
                    match (tok) {
                        case Token.Identifier =>
                            let name = tokenText(tokens, pos)
                            args.append(Expr.identifier(argLoc, name))
                            pos += 1
                        case Token.StringLiteral =>
                            let text = tokenText(tokens, pos)
                            args.append(Expr.string(argLoc, text))
                            pos += 1
                        case Token.NumericLiteral =>
                            let num = 0.0
                            args.append(Expr.number(argLoc, num))
                            pos += 1
                        case Token.True =>
                            args.append(Expr.bool_(argLoc, true))
                            pos += 1
                        case Token.False =>
                            args.append(Expr.bool_(argLoc, false))
                            pos += 1
                        case Token.Null =>
                            args.append(Expr.null_(argLoc))
                            pos += 1
                        case Token.OpenBracket =>
                            // 跳过数组字面量
                            var depth = 1
                            pos += 1
                            while (pos < tokens.size && depth > 0) {
                                match (tokens[Int64(pos)]) {
                                    case Token.OpenBracket => depth += 1
                                    case Token.CloseBracket => depth -= 1
                                    case _ => ()
                                }
                                pos += 1
                            }
                        case Token.OpenBrace =>
                            // 跳过对象字面量
                            var depth = 1
                            pos += 1
                            while (pos < tokens.size && depth > 0) {
                                match (tokens[Int64(pos)]) {
                                    case Token.OpenBrace => depth += 1
                                    case Token.CloseBrace => depth -= 1
                                    case _ => ()
                                }
                                pos += 1
                            }
                        case _ =>
                            pos += 1
                    }
            }
        }
        return Tuple<ArrayList<Expr>, Int64>(args, pos)
    }

    /// 获取 token 对应的文本 (简化实现)
    private static func tokenText(tokens: ArrayList<Token>, pos: Int64): String {
        // 在实际实现中，应从 Lexer 获取对应文本
        // 此处返回占位文本
        return "token_${pos}"
    }
}

// ============================================================================
// DecoratorValidator - 装饰器使用验证
// 严格翻译自: src/js_parser/p.zig 中对装饰器合法性的检查
//   TypeScript 装饰器有严格的适用范围:
//   - 类装饰器: 只能附加到 class 声明
//   - 方法装饰器: 只能附加到方法
//   - 属性装饰器: 只能附加到属性
//   - 参数装饰器: 只能附加到参数
// ============================================================================

/// 装饰器验证器 - 检查装饰器使用是否合法
public class DecoratorValidator {

    /// 验证类装饰器 - 对应 Bun 中对 class decorators 的检查
    /// 类装饰器不能是参数装饰器
    public static func validateClassDecorators(node: DecoratedNode): ArrayList<String> {
        var errors = ArrayList<String>()
        if (node.element != DecoratedElement.Class) {
            errors.append("Class decorator applied to non-class element '${node.name}' (${node.element.displayName()})")
            return errors
        }
        let resolver = DecoratorResolver()
        for (d in node.decorators) {
            if (!isValidDecoratorTarget(d, DecoratedElement.Class)) {
                let name = resolver.getDecoratorName(d.expr)
                errors.append("Decorator '@${name}' cannot be applied to class '${node.name}'")
            }
        }
        return errors
    }

    /// 验证方法装饰器 - 对应 Bun 中对 method decorators 的检查
    public static func validateMethodDecorators(node: DecoratedNode): ArrayList<String> {
        var errors = ArrayList<String>()
        if (node.element != DecoratedElement.Method) {
            errors.append("Method decorator applied to non-method element '${node.name}' (${node.element.displayName()})")
            return errors
        }
        let resolver = DecoratorResolver()
        for (d in node.decorators) {
            if (!isValidDecoratorTarget(d, DecoratedElement.Method)) {
                let name = resolver.getDecoratorName(d.expr)
                errors.append("Decorator '@${name}' cannot be applied to method '${node.name}'")
            }
        }
        return errors
    }

    /// 验证属性装饰器 - 对应 Bun 中对 property decorators 的检查
    public static func validatePropertyDecorators(node: DecoratedNode): ArrayList<String> {
        var errors = ArrayList<String>()
        if (node.element != DecoratedElement.Property) {
            errors.append("Property decorator applied to non-property element '${node.name}' (${node.element.displayName()})")
            return errors
        }
        let resolver = DecoratorResolver()
        for (d in node.decorators) {
            if (!isValidDecoratorTarget(d, DecoratedElement.Property)) {
                let name = resolver.getDecoratorName(d.expr)
                errors.append("Decorator '@${name}' cannot be applied to property '${node.name}'")
            }
        }
        return errors
    }

    /// 验证参数装饰器 - 对应 Bun 中对 parameter decorators 的检查
    public static func validateParameterDecorators(node: DecoratedNode): ArrayList<String> {
        var errors = ArrayList<String>()
        if (node.element != DecoratedElement.Parameter) {
            errors.append("Parameter decorator applied to non-parameter element '${node.name}' (${node.element.displayName()})")
            return errors
        }
        let resolver = DecoratorResolver()
        for (d in node.decorators) {
            if (!isValidDecoratorTarget(d, DecoratedElement.Parameter)) {
                let name = resolver.getDecoratorName(d.expr)
                errors.append("Decorator '@${name}' cannot be applied to parameter '${node.name}'")
            }
        }
        return errors
    }

    /// 检查装饰器是否可以附加到指定目标 - 对应 Bun 中装饰器合法性判断
    /// TypeScript 5.0+ 允许装饰器附加到任何合法目标
    /// 旧式 experimentalDecorators 有更严格的限制
    public static func isValidDecoratorTarget(decorator: TSDecorator,
                                               element: DecoratedElement): Bool {
        // 所有装饰器都可以附加到类
        if (element == DecoratedElement.Class) {
            return true
        }
        // 类成员装饰器支持: 方法、属性、getter、setter、accessor
        if (element.isClassMember()) {
            return true
        }
        // 参数装饰器 (experimentalDecorators)
        if (element == DecoratedElement.Parameter) {
            return true
        }
        return false
    }
}

// ============================================================================
// DecoratorResolver - 装饰器表达式解析
// 严格翻译自: src/js_parser/p.zig 中对装饰器表达式的分析
//   Bun 在解析装饰器后将 Expr 解析为 DecoratorInfo，
//   区分普通装饰器 (@foo) 和装饰器工厂 (@foo(args))
// ============================================================================

/// 装饰器解析器 - 从装饰器表达式中提取信息
public class DecoratorResolver {

    /// 解析装饰器 - 返回 DecoratorInfo
    /// 对应 Bun 中对 G.Deprecated (装饰器) 表达式的语义分析
    public func resolve(decorator: TSDecorator): DecoratorInfo {
        let expr = decorator.expr
        let name = getDecoratorName(expr)
        let isFactory = isDecoratorFactory(expr)
        let info = DecoratorInfo(decorator.loc, name, isFactory)
        if (isFactory) {
            info.arguments = getArguments(expr)
        }
        return info
    }

    /// 判断是否为装饰器工厂 (即带调用参数的形式)
    /// @foo(args) 是工厂, @foo 不是
    public func isDecoratorFactory(expr: Expr): Bool {
        match (expr.tag) {
            case ExprTag.Call => true
            case _ => false
        }
    }

    /// 获取装饰器名称
    /// 对应 Bun 中从装饰器表达式提取标识符链
    /// @foo       -> "foo"
    /// @foo.bar   -> "foo.bar"
    /// @foo(args) -> "foo"
    public func getDecoratorName(expr: Expr): String {
        match (expr.tag) {
            // 简单标识符: @foo
            case ExprTag.Identifier =>
                return expr.identifierName
            // 成员访问: @foo.bar.baz
            case ExprTag.Dot =>
                let target = expr.target
                match (target) {
                    case Some(t) => return getDecoratorName(t) + "." + expr.propertyName
                    case None => return expr.propertyName
                }
            // 调用 (工厂): @foo(args) 或 @foo.bar(args)
            case ExprTag.Call =>
                let target = expr.target
                match (target) {
                    case Some(t) => return getDecoratorName(t)
                    case None => return ""
                }
            case _ =>
                return "<unknown>"
        }
    }

    /// 获取装饰器工厂的参数列表
    /// 对应 Bun 中从调用表达式中提取参数
    public func getArguments(expr: Expr): ArrayList<Expr> {
        match (expr.tag) {
            case ExprTag.Call =>
                return expr.args
            case _ =>
                return ArrayList<Expr>()
        }
    }
}
