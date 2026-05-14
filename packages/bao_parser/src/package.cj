// bao_parser - JavaScript/TypeScript 解析器
// 对应 Bun: src/js_parser/, src/ast/, src/js_printer/
package bao_parser

import bao_core.*
import bao_collections.*
import bao_unicode.*

// ============================================================================
// AST 节点定义
// 对应 Bun: src/ast/ast.zig
// ============================================================================

/// AST 节点类型
public enum AstKind {
    | Program
    | FunctionDeclaration
    | VariableDeclaration
    | ClassDeclaration
    | ImportDeclaration
    | ExportDeclaration
    | ExpressionStatement
    | BlockStatement
    | IfStatement
    | ForStatement
    | WhileStatement
    | DoWhileStatement
    | SwitchStatement
    | TryStatement
    | ReturnStatement
    | ThrowStatement
    | BreakStatement
    | ContinueStatement
    | Identifier
    | NumericLiteral
    | StringLiteral
    | BooleanLiteral
    | NullLiteral
    | UndefinedLiteral
    | BigIntLiteral
    | RegExpLiteral
    | ArrayExpression
    | ObjectExpression
    | FunctionExpression
    | ArrowFunctionExpression
    | ClassExpression
    | MemberExpression
    | CallExpression
    | NewExpression
    | UnaryExpression
    | BinaryExpression
    | LogicalExpression
    | AssignmentExpression
    | ConditionalExpression
    | TemplateLiteral
    | SpreadElement
    | JSXElement
    | JSXFragment
    | TSAsExpression
    | TSTypeAnnotation
    | TSTypeReference
    | TSInterfaceDeclaration
    | TSTypeAliasDeclaration
    | TSEnumDeclaration
    | Comment
    | Empty
    | Unknown
}

/// 源码位置
public class SourceLocation {
    public let start: Int64
    public let end: Int64
    public let line: Int64
    public let column: Int64

    public init(start: Int64, end: Int64, line: Int64, column: Int64) {
        this.start = start
        this.end = end
        this.line = line
        this.column = column
    }
}

/// AST 基础节点
public class AstNode {
    public let kind: AstKind
    public let loc: SourceLocation
    public var children: ArrayList<AstNode>

    public init(kind: AstKind, loc: SourceLocation) {
        this.kind = kind
        this.loc = loc
        this.children = ArrayList<AstNode>()
    }

    /// 添加子节点
    public func addChild(node: AstNode): Unit {
        children.append(node)
    }

    /// 获取节点类型名
    public func kindName(): String {
        return kind.toString()
    }
}

/// 程序根节点
public class Program <: AstNode {
    public var sourceFile: String
    public var body: ArrayList<AstNode>
    public var comments: ArrayList<AstNode>

    public init(loc: SourceLocation, sourceFile: String) {
        this.sourceFile = sourceFile
        this.body = ArrayList<AstNode>()
        this.comments = ArrayList<AstNode>()
        super(AstKind.Program, loc)
    }
}

/// 标识符节点
public class Identifier <: AstNode {
    public let name: BaoString

    public init(name: BaoString, loc: SourceLocation) {
        this.name = name
        super(AstKind.Identifier, loc)
    }
}

/// 字符串字面量
public class StringLiteral <: AstNode {
    public let value: BaoString

    public init(value: BaoString, loc: SourceLocation) {
        this.value = value
        super(AstKind.StringLiteral, loc)
    }
}

/// 数值字面量
public class NumericLiteral <: AstNode {
    public let value: Float64
    public let raw: BaoString

    public init(value: Float64, raw: BaoString, loc: SourceLocation) {
        this.value = value
        this.raw = raw
        super(AstKind.NumericLiteral, loc)
    }
}

/// 函数声明
public class FunctionDeclaration <: AstNode {
    public var name: ?Identifier
    public var params: ArrayList<AstNode>
    public var body: ?AstNode
    public var isAsync: Bool
    public var isGenerator: Bool

    public init(loc: SourceLocation) {
        name = None
        params = ArrayList<AstNode>()
        body = None
        isAsync = false
        isGenerator = false
        super(AstKind.FunctionDeclaration, loc)
    }
}

// ============================================================================
// 解析器
// 对应 Bun: src/js_parser/p.zig
// ============================================================================

/// 解析器选项
public class ParserOptions {
    public var ts: Bool            // 是否为 TypeScript
    public var jsx: Bool           // 是否支持 JSX
    public var decorators: Bool    // 是否支持装饰器
    public var sourceFile: String  // 源文件名

    public init() {
        ts = false
        jsx = false
        decorators = false
        sourceFile = ""
    }
}

/// 解析结果
public class ParseResult {
    public let program: Program
    public let errors: ArrayList<ParseError>

    public init(program: Program, errors: ArrayList<ParseError>) {
        this.program = program
        this.errors = errors
    }

    /// 是否有错误
    public func hasErrors(): Bool {
        return errors.size > 0
    }
}

/// 解析错误
public class ParseError {
    public let loc: SourceLocation
    public let message: String

    public init(loc: SourceLocation, message: String) {
        this.loc = loc
        this.message = message
    }
}

/// JavaScript/TypeScript 解析器
/// 对应 Bun: src/js_parser/p.zig (~7000行)
public class JsParser {
    private var source: Array<UInt8>
    private var pos: Int64
    private var line: Int64
    private var column: Int64
    private var options: ParserOptions
    private var errors: ArrayList<ParseError>

    public init() {
        source = []
        pos = 0
        line = 1
        column = 0
        options = ParserOptions()
        errors = ArrayList<ParseError>()
    }

    /// 解析源代码字符串
    public func parse(source: String, options: ParserOptions): ParseResult {
        this.options = options
        this.source = Array<UInt8>()
        this.pos = 0
        this.line = 1
        this.column = 0
        this.errors = ArrayList<ParseError>()

        // 将字符串转为字节数组
        for (c in source) {
            this.source.append(UInt8(c.value))
        }

        let loc = SourceLocation(0, 0, 1, 0)
        let program = Program(loc, options.sourceFile)

        // 主解析循环 (骨架)
        while (pos < source.size) {
            skipWhitespaceAndComments()
            if (pos >= source.size) {
                break
            }

            let stmt = parseStatement()
            match (stmt) {
                case Some(node) => program.body.append(node)
                case None => {}
            }
        }

        program.loc = SourceLocation(0, pos, 1, 0)
        return ParseResult(program, errors)
    }

    /// 解析语句
    private func parseStatement(): ?AstNode {
        // TODO: 完整实现需要翻译 Bun 的 ~7000 行解析器
        let loc = currentLoc()

        if (matchKeyword("function")) {
            return parseFunctionDeclaration(loc)
        }
        if (matchKeyword("const") || matchKeyword("let") || matchKeyword("var")) {
            return parseVariableDeclaration(loc)
        }
        if (matchKeyword("if")) {
            return parseIfStatement(loc)
        }
        if (matchKeyword("return")) {
            return parseReturnStatement(loc)
        }
        if (matchKeyword("import")) {
            return parseImportDeclaration(loc)
        }
        if (matchKeyword("export")) {
            return parseExportDeclaration(loc)
        }

        // 表达式语句
        let expr = parseExpression()
        match (expr) {
            case Some(node) => {
                let stmt = AstNode(AstKind.ExpressionStatement, loc)
                stmt.addChild(node)
                return Some(stmt)
            }
            case None => {}
        }

        advance()
        return None
    }

    private func parseFunctionDeclaration(loc: SourceLocation): ?AstNode {
        // TODO: 完整实现
        return Some(FunctionDeclaration(loc))
    }

    private func parseVariableDeclaration(loc: SourceLocation): ?AstNode {
        // TODO: 完整实现
        return Some(AstNode(AstKind.VariableDeclaration, loc))
    }

    private func parseIfStatement(loc: SourceLocation): ?AstNode {
        // TODO: 完整实现
        return Some(AstNode(AstKind.IfStatement, loc))
    }

    private func parseReturnStatement(loc: SourceLocation): ?AstNode {
        // TODO: 完整实现
        return Some(AstNode(AstKind.ReturnStatement, loc))
    }

    private func parseImportDeclaration(loc: SourceLocation): ?AstNode {
        // TODO: 完整实现
        return Some(AstNode(AstKind.ImportDeclaration, loc))
    }

    private func parseExportDeclaration(loc: SourceLocation): ?AstNode {
        // TODO: 完整实现
        return Some(AstNode(AstKind.ExportDeclaration, loc))
    }

    private func parseExpression(): ?AstNode {
        // TODO: 完整实现 (最复杂的部分)
        return None
    }

    private func skipWhitespaceAndComments(): Unit {
        while (pos < source.size) {
            let ch = source[pos]
            if (ch == UInt8(' ') || ch == UInt8('\t') || ch == UInt8('\r')) {
                pos += 1
                column += 1
            } else if (ch == UInt8('\n')) {
                pos += 1
                line += 1
                column = 0
            } else if (ch == UInt8('/') && pos + 1 < source.size) {
                if (source[pos + 1] == UInt8('/')) {
                    // 单行注释
                    while (pos < source.size && source[pos] != UInt8('\n')) {
                        pos += 1
                    }
                } else if (source[pos + 1] == UInt8('*')) {
                    // 多行注释
                    pos += 2
                    while (pos + 1 < source.size) {
                        if (source[pos] == UInt8('*') && source[pos + 1] == UInt8('/')) {
                            pos += 2
                            break
                        }
                        if (source[pos] == UInt8('\n')) {
                            line += 1
                            column = 0
                        }
                        pos += 1
                    }
                } else {
                    break
                }
            } else {
                break
            }
        }
    }

    private func matchKeyword(keyword: String): Bool {
        let kwBytes = keyword.toArray()
        if (pos + kwBytes.size > source.size) {
            return false
        }
        for (i in 0..kwBytes.size) {
            if (source[pos + i] != UInt8(kwBytes[i])) {
                return false
            }
        }
        // 确保关键字后不是标识符字符
        let nextPos = pos + kwBytes.size
        if (nextPos < source.size) {
            let next = source[nextPos]
            if ((next >= UInt8('a') && next <= UInt8('z')) ||
                (next >= UInt8('A') && next <= UInt8('Z')) ||
                (next >= UInt8('0') && next <= UInt8('9')) ||
                next == UInt8('_')) {
                return false
            }
        }
        pos = nextPos
        return true
    }

    private func advance(): Unit {
        if (pos < source.size) {
            if (source[pos] == UInt8('\n')) {
                line += 1
                column = 0
            } else {
                column += 1
            }
            pos += 1
        }
    }

    private func currentLoc(): SourceLocation {
        return SourceLocation(pos, pos, line, column)
    }

    private func addError(message: String): Unit {
        errors.append(ParseError(currentLoc(), message))
    }
}

// ============================================================================
// 代码打印器 (代码生成)
// 对应 Bun: src/js_printer/js_printer.zig
// ============================================================================

/// 代码打印器 - 将 AST 转回源代码
public class JsPrinter {
    private var builder: BaoStringBuilder
    private var indent: Int64
    private var indentStr: String

    public init() {
        builder = BaoStringBuilder()
        indent = 0
        indentStr = "  "
    }

    /// 将 AST 打印为源代码
    public func print(program: Program): BaoString {
        printProgram(program)
        return builder.build()
    }

    private func printProgram(program: Program): Unit {
        for (node in program.body) {
            printNode(node)
            builder.newline()
        }
    }

    private func printNode(node: AstNode): Unit {
        match (node.kind) {
            case AstKind.ExpressionStatement => {
                if (node.children.size > 0) {
                    printNode(node.children[0])
                }
                builder.append(";")
            }
            case AstKind.VariableDeclaration => {
                builder.append("var ")
                for (child in node.children) {
                    printNode(child)
                }
                builder.append(";")
            }
            case AstKind.FunctionDeclaration => {
                let fn = node as FunctionDeclaration
                builder.append("function ")
                match (fn.name) {
                    case Some(id) => builder.append((id as Identifier).name.toString())
                    case None => {}
                }
                builder.append("(")
                builder.append(") ")
                printBlock(fn.body)
            }
            case AstKind.ReturnStatement => {
                builder.append("return")
                if (node.children.size > 0) {
                    builder.append(" ")
                    printNode(node.children[0])
                }
                builder.append(";")
            }
            case AstKind.StringLiteral => {
                let lit = node as StringLiteral
                builder.append("\"")
                builder.append(lit.value)
                builder.append("\"")
            }
            case AstKind.NumericLiteral => {
                let lit = node as NumericLiteral
                builder.append(lit.raw)
            }
            case AstKind.Identifier => {
                let id = node as Identifier
                builder.append(id.name)
            }
            case _ => {
                builder.append("/* unknown: ${node.kindName()} */")
            }
        }
    }

    private func printBlock(body: ?AstNode): Unit {
        builder.append("{")
        indent += 1
        match (body) {
            case Some(node) => {
                builder.newline()
                printNode(node)
            }
            case None => {}
        }
        indent -= 1
        builder.newline()
        writeIndent()
        builder.append("}")
    }

    private func writeIndent(): Unit {
        for (_ in 0..indent) {
            builder.append(indentStr)
        }
    }
}
