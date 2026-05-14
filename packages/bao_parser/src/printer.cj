// Printer - JavaScript 代码生成器
// 严格翻译自: src/js_printer/js_printer.zig
//   pub const Printer = struct {
//       import_records: []const ImportRecord,
//       ast: *const Ast,
//       symbols: []const Symbol,
//       options: Options,
//       builder: std.ArrayList(u8),
//       ...
//   }
//
// Bun 的 Printer 设计:
//   - 遍历 AST 节点，按类型输出对应 JavaScript 代码
//   - 支持 minify 模式（去除空白）
//   - 保留注释和源码位置
//   - 通过 StringBuilder 高效拼接输出
package bao_parser

import bao_core.*
import bao_collections.*

// ============================================================================
// PrintOptions - 打印选项
// 严格翻译自: src/js_printer/js_printer.zig:21-40
//   pub const Options = struct {
//       minify: bool = false,
//       indent: u8 = 0,
//       ...
//   }
// ============================================================================

/// 打印选项 - 对应 Bun Printer.Options
public class PrintOptions {
    /// 是否压缩输出 - 对应 Bun minify
    public var minify: Bool
    /// 缩进级别
    public var indent: Int64
    /// 缩进字符串
    public var indentStr: String
    /// 换行符
    public var newline: String
    /// 是否输出 TypeScript 类型注解
    public var outputTypescript: Bool

    public init() {
        minify = false
        indent = 0
        indentStr = "  "
        newline = "\n"
        outputTypescript = false
    }

    public static func minified(): PrintOptions {
        let opts = PrintOptions()
        opts.minify = true
        opts.indentStr = ""
        opts.newline = ""
        return opts
    }
}

// ============================================================================
// Printer - 代码生成器
// 严格翻译自: src/js_printer/js_printer.zig:42-200
//   核心: printStmt(stmt) 和 printExpr(expr) 遍历 AST 生成代码
// ============================================================================

/// JavaScript 代码生成器 - 严格对应 Bun Printer
/// Bun: 遍历 AST 节点，通过 StringBuilder 生成输出代码
public class Printer {
    /// 输出缓冲区 - 对应 Bun builder: std.ArrayList(u8)
    private var sb: StringBuilder
    /// 打印选项
    private var opts: PrintOptions
    /// 当前缩进级别
    private var indentLevel: Int64

    public init() {
        sb = StringBuilder()
        opts = PrintOptions()
        indentLevel = 0
    }

    public init(opts: PrintOptions) {
        sb = StringBuilder()
        this.opts = opts
        indentLevel = 0
    }

    // ========================================================================
    // 公共 API
    // ========================================================================

    /// 打印 AST 程序 (语句列表) - 对应 Bun printAst
    /// Bun: 遍历 ast stmts 数组，逐个调用 printStmt
    public func printProgram(stmts: ArrayList<Stmt>): String {
        sb = StringBuilder()
        indentLevel = 0
        for (i in 0..stmts.size) {
            printStmt(stmts[i])
            if (i < stmts.size - 1) {
                writeNewline()
            }
        }
        return sb.toString()
    }

    /// 打印单条语句 - 对应 Bun printStmt
    public func printStmtToString(stmt: Stmt): String {
        sb = StringBuilder()
        printStmt(stmt)
        return sb.toString()
    }

    /// 打印单个表达式 - 对应 Bun printExpr
    public func printExprToString(expr: Expr): String {
        sb = StringBuilder()
        printExpr(expr, Precedence.Lowest)
        return sb.toString()
    }

    // ========================================================================
    // 语句打印 - 严格对应 Bun printStmt
    // Bun: fn printStmt(self: *Printer, s: Stmt) anyerror!void
    //   switch (s.data) { .s_block => ..., .s_expr => ..., ... }
    // ========================================================================

    /// 打印语句 - 对应 Bun Printer.printStmt
    private func printStmt(s: Stmt): Unit {
        match (s.tag) {
            case StmtTag.Block => printBlock(s)
            case StmtTag.Expr => printExprStmt(s)
            case StmtTag.If => printIf(s)
            case StmtTag.For => printFor(s)
            case StmtTag.ForIn => printForIn(s)
            case StmtTag.ForOf => printForOf(s)
            case StmtTag.While => printWhile(s)
            case StmtTag.DoWhile => printDoWhile(s)
            case StmtTag.Function => printFunctionDecl(s)
            case StmtTag.Class => printClassDecl(s)
            case StmtTag.Import => printImport(s)
            case StmtTag.Export => printExport(s)
            case StmtTag.Local => printLocal(s)
            case StmtTag.Return => printReturn(s)
            case StmtTag.Throw => printThrow(s)
            case StmtTag.Try => printTry(s)
            case StmtTag.Switch => printSwitch(s)
            case StmtTag.Break => printBreak(s)
            case StmtTag.Continue => printContinue(s)
            case StmtTag.Debugger => printDebugger(s)
            case StmtTag.Empty => () // 空语句不输出
            case StmtTag.With => printWith(s)
            case StmtTag.Labeled => printLabeled(s)
            case StmtTag.Type => printTypeDecl(s)
            case StmtTag.Enum => printEnumDecl(s)
        }
    }

    /// 打印块语句 - 对应 Bun S.Block
    /// { stmt1; stmt2; ... }
    private func printBlock(s: Stmt): Unit {
        write("{")
        indentLevel += 1
        for (stmt in s.stmts) {
            writeNewline()
            writeIndent()
            printStmt(stmt)
        }
        indentLevel -= 1
        writeNewline()
        writeIndent()
        write("}")
    }

    /// 打印表达式语句 - 对应 Bun S.SExpr
    /// expr;
    private func printExprStmt(s: Stmt): Unit {
        if (let Some(expr) = s.expr) {
            printExpr(expr, Precedence.Lowest)
            write(";")
        }
    }

    /// 打印 if 语句 - 对应 Bun S.If
    /// if (test) { yes } else { no }
    private func printIf(s: Stmt): Unit {
        write("if (")
        if (let Some(test) = s.expr) {
            printExpr(test, Precedence.Lowest)
        }
        write(") ")
        if (let Some(yes) = s.yes) {
            printStmt(yes)
        }
        if (let Some(no) = s.no) {
            write(" else ")
            printStmt(no)
        }
    }

    /// 打印 for 语句 - 对应 Bun S.For
    /// for (init; test; update) { body }
    private func printFor(s: Stmt): Unit {
        write("for (")
        if (let Some(init) = s.init) {
            printStmt(init)
        } else {
            write(";")
        }
        write(" ")
        if (let Some(test) = s.expr) {
            printExpr(test, Precedence.Lowest)
        }
        write("; ")
        if (let Some(update) = s.update) {
            printExpr(update, Precedence.Lowest)
        }
        write(") ")
        if (let Some(body) = s.body) {
            printStmt(body)
        }
    }

    /// 打印 for-in 语句 - 对应 Bun S.ForIn
    /// for (var x in obj) { body }
    private func printForIn(s: Stmt): Unit {
        write("for (")
        writeDeclKind(s.declKind)
        if (s.decls.size > 0) {
            let binding = s.decls[0].binding
            printBinding(binding)
        }
        write(" in ")
        if (let Some(value) = s.iterValue) {
            printExpr(value, Precedence.Lowest)
        }
        write(") ")
        if (let Some(body) = s.body) {
            printStmt(body)
        }
    }

    /// 打印 for-of 语句 - 对应 Bun S.ForOf
    /// for (const x of iterable) { body }
    private func printForOf(s: Stmt): Unit {
        write("for (")
        writeDeclKind(s.declKind)
        if (s.decls.size > 0) {
            let binding = s.decls[0].binding
            printBinding(binding)
        }
        write(" of ")
        if (let Some(value) = s.iterValue) {
            printExpr(value, Precedence.Lowest)
        }
        write(") ")
        if (let Some(body) = s.body) {
            printStmt(body)
        }
    }

    /// 打印 while 语句 - 对应 Bun S.While
    /// while (test) { body }
    private func printWhile(s: Stmt): Unit {
        write("while (")
        if (let Some(test) = s.expr) {
            printExpr(test, Precedence.Lowest)
        }
        write(") ")
        if (let Some(body) = s.body) {
            printStmt(body)
        }
    }

    /// 打印 do-while 语句 - 对应 Bun S.DoWhile
    /// do { body } while (test)
    private func printDoWhile(s: Stmt): Unit {
        write("do ")
        if (let Some(body) = s.body) {
            printStmt(body)
        }
        write(" while (")
        if (let Some(test) = s.expr) {
            printExpr(test, Precedence.Lowest)
        }
        write(");")
    }

    /// 打印函数声明 - 对应 Bun S.Function
    /// function name(args) { body }
    private func printFunctionDecl(s: Stmt): Unit {
        if (let Some(fn) = s.fn) {
            printFunctionHeader(fn)
            // 打印函数体
            write(" ")
            match (fn.body) {
                case GFnBody.Stmt(body) => printStmt(body)
                case GFnBody.Stmts(body) =>
                    write("{")
                    indentLevel += 1
                    for (stmt in body) {
                        writeNewline()
                        writeIndent()
                        printStmt(stmt)
                    }
                    indentLevel -= 1
                    writeNewline()
                    writeIndent()
                    write("}")
                case GFnBody.Expr(_) => write("{}") // 函数声明不可能用表达式体
            }
        }
    }

    /// 打印类声明 - 对应 Bun S.Class
    /// class Name extends Base { ... }
    private func printClassDecl(s: Stmt): Unit {
        write("class")
        if (let Some(cls) = s.classData) {
            if (cls.name.length > 0) {
                write(" ")
                write(cls.name)
            }
            if (let Some(ext) = cls.extends_) {
                write(" extends ")
                printExpr(ext, Precedence.Lowest)
            }
            write(" {")
            indentLevel += 1
            for (prop in cls.properties) {
                writeNewline()
                writeIndent()
                printProperty(prop)
            }
            indentLevel -= 1
            writeNewline()
            writeIndent()
            write("}")
        }
    }

    /// 打印 import 语句 - 对应 Bun S.Import
    /// import { foo, bar } from 'module'
    private func printImport(s: Stmt): Unit {
        write("import ")
        if (s.defaultName.length > 0) {
            write(s.defaultName)
            if (s.importItems.size > 0) {
                write(", ")
            }
        }
        if (s.importItems.size > 0) {
            write("{ ")
            for (i in 0..s.importItems.size) {
                let item = s.importItems[i]
                if (item.alias.length > 0 && item.alias != item.originalName) {
                    write(item.originalName)
                    write(" as ")
                    write(item.alias)
                } else {
                    write(item.alias)
                }
                if (i < s.importItems.size - 1) {
                    write(", ")
                }
            }
            write(" }")
        }
        write(" from '")
        write(s.importPath)
        write("';")
    }

    /// 打印 export 语句 - 对应 Bun S.Export
    private func printExport(s: Stmt): Unit {
        write("export ")
        if (let Some(init) = s.init) {
            // export default ...
            write("default ")
            printStmt(init)
        } else if (s.importItems.size > 0) {
            // export { foo, bar }
            write("{ ")
            for (i in 0..s.importItems.size) {
                let item = s.importItems[i]
                if (item.alias.length > 0 && item.alias != item.originalName) {
                    write(item.originalName)
                    write(" as ")
                    write(item.alias)
                } else {
                    write(item.alias)
                }
                if (i < s.importItems.size - 1) {
                    write(", ")
                }
            }
            write(" }")
            if (s.importPath.length > 0) {
                write(" from '")
                write(s.importPath)
                write("'")
            }
            write(";")
        } else if (let Some(expr) = s.expr) {
            // export default expression
            write("default ")
            printExpr(expr, Precedence.Assign)
            write(";")
        }
    }

    /// 打印变量声明 - 对应 Bun S.Local
    /// var/let/const a = 1, b = 2;
    private func printLocal(s: Stmt): Unit {
        writeDeclKind(s.declKind)
        write(" ")
        for (i in 0..s.decls.size) {
            let decl = s.decls[i]
            printBinding(decl.binding)
            if (let Some(value) = decl.value) {
                write(" = ")
                printExpr(value, Precedence.Assign)
            }
            if (i < s.decls.size - 1) {
                write(", ")
            }
        }
        write(";")
    }

    /// 打印 return 语句 - 对应 Bun S.Return
    /// return expr;
    private func printReturn(s: Stmt): Unit {
        write("return")
        if (let Some(value) = s.expr) {
            write(" ")
            printExpr(value, Precedence.Lowest)
        }
        write(";")
    }

    /// 打印 throw 语句 - 对应 Bun S.Throw
    /// throw expr;
    private func printThrow(s: Stmt): Unit {
        write("throw ")
        if (let Some(value) = s.expr) {
            printExpr(value, Precedence.Lowest)
        }
        write(";")
    }

    /// 打印 try 语句 - 对应 Bun S.Try
    /// try { ... } catch (e) { ... } finally { ... }
    private func printTry(s: Stmt): Unit {
        write("try ")
        // body
        write("{")
        indentLevel += 1
        for (stmt in s.stmts) {
            writeNewline()
            writeIndent()
            printStmt(stmt)
        }
        indentLevel -= 1
        writeNewline()
        writeIndent()
        write("}")
        // catch
        if (let Some(catch) = s.catchBody) {
            write(" catch ")
            if (let Some(binding) = s.catchBinding) {
                write("(")
                printBinding(binding)
                write(") ")
            }
            printStmt(catch)
        }
        // finally
        if (let Some(finally) = s.finallyBody) {
            write(" finally ")
            printStmt(finally)
        }
    }

    /// 打印 switch 语句 - 对应 Bun S.Switch
    private func printSwitch(s: Stmt): Unit {
        write("switch (")
        if (let Some(test) = s.expr) {
            printExpr(test, Precedence.Lowest)
        }
        write(") {")
        indentLevel += 1
        for (c in s.cases) {
            writeNewline()
            writeIndent()
            if (let Some(value) = c.value) {
                write("case ")
                printExpr(value, Precedence.Lowest)
                write(":")
            } else {
                write("default:")
            }
            indentLevel += 1
            for (stmt in c.body) {
                writeNewline()
                writeIndent()
                printStmt(stmt)
            }
            indentLevel -= 1
        }
        indentLevel -= 1
        writeNewline()
        writeIndent()
        write("}")
    }

    /// 打印 break 语句
    private func printBreak(s: Stmt): Unit {
        write("break")
        if (s.label.length > 0) {
            write(" ")
            write(s.label)
        }
        write(";")
    }

    /// 打印 continue 语句
    private func printContinue(s: Stmt): Unit {
        write("continue")
        if (s.label.length > 0) {
            write(" ")
            write(s.label)
        }
        write(";")
    }

    /// 打印 debugger 语句
    private func printDebugger(s: Stmt): Unit {
        write("debugger;")
    }

    /// 打印 with 语句
    private func printWith(s: Stmt): Unit {
        write("with (")
        if (let Some(expr) = s.expr) {
            printExpr(expr, Precedence.Lowest)
        }
        write(") ")
        if (let Some(body) = s.body) {
            printStmt(body)
        }
    }

    /// 打印标签语句
    private func printLabeled(s: Stmt): Unit {
        write(s.label)
        write(": ")
        if (let Some(body) = s.body) {
            printStmt(body)
        }
    }

    /// 打印 TypeScript 类型声明
    private func printTypeDecl(s: Stmt): Unit {
        if (opts.outputTypescript) {
            write("// @ts-type ")
            if (let Some(expr) = s.expr) {
                printExpr(expr, Precedence.Lowest)
            }
        }
        // 非 TS 输出模式下跳过类型声明
    }

    /// 打印 TypeScript enum 声明
    private func printEnumDecl(s: Stmt): Unit {
        if (opts.outputTypescript) {
            write("enum ")
            write(s.label)
            write(" {")
            indentLevel += 1
            for (stmt in s.stmts) {
                writeNewline()
                writeIndent()
                printStmt(stmt)
                write(",")
            }
            indentLevel -= 1
            writeNewline()
            writeIndent()
            write("}")
        }
    }

    // ========================================================================
    // 表达式打印 - 严格对应 Bun printExpr
    // Bun: fn printExpr(self: *Printer, e: Expr, level: Level) anyerror!void
    //   使用 Pratt 解析器优先级决定是否加括号
    // ========================================================================

    /// 表达式优先级 - 对应 Bun Op.Level (从低到高)
    private enum Precedence {
        | Lowest        // 0
        | Comma         // 1
        | Assign        // 2
        | Conditional   // 3
        | Nullish       // 4
        | LogicalOr     // 5
        | LogicalAnd    // 6
        | BitwiseOr     // 7
        | BitwiseXor    // 8
        | BitwiseAnd    // 9
        | Equality      // 10
        | Relational    // 11
        | Shift         // 12
        | Additive      // 13
        | Multiplicative // 14
        | Exponentiation // 15
        | Unary         // 16
        | Postfix       // 17
        | Call          // 18
        | Member        // 19
        | Primary       // 20

        public func ordinal(): Int64 {
            match (this) {
                case Lowest => 0
                case Comma => 1
                case Assign => 2
                case Conditional => 3
                case Nullish => 4
                case LogicalOr => 5
                case LogicalAnd => 6
                case BitwiseOr => 7
                case BitwiseXor => 8
                case BitwiseAnd => 9
                case Equality => 10
                case Relational => 11
                case Shift => 12
                case Additive => 13
                case Multiplicative => 14
                case Exponentiation => 15
                case Unary => 16
                case Postfix => 17
                case Call => 18
                case Member => 19
                case Primary => 20
            }
        }
    }

    /// 打印表达式 - 对应 Bun Printer.printExpr
    /// level 参数用于决定是否需要括号包裹
    private func printExpr(e: Expr, level: Precedence): Unit {
        match (e.tag) {
            case ExprTag.Missing => () // 缺失表达式不输出
            case ExprTag.Undefined => write("undefined")
            case ExprTag.Null => write("null")
            case ExprTag.Boolean => write(if (e.boolValue) { "true" } else { "false" })
            case ExprTag.Number => printNumber(e.numberValue)
            case ExprTag.BigInt => write(e.stringValue.toString() + "n")
            case ExprTag.String => printStringLiteral(e.stringValue.toString())
            case ExprTag.Regex => printRegex(e)
            case ExprTag.Identifier => write(e.identifierName)
            case ExprTag.ImportIdentifier => write(e.identifierName)
            case ExprTag.This => write("this")
            case ExprTag.Super => write("super")
            case ExprTag.New => printNew(e, level)
            case ExprTag.Call => printCall(e, level)
            case ExprTag.Dot => printDot(e, level)
            case ExprTag.Index => printIndex(e, level)
            case ExprTag.Array => printArray(e)
            case ExprTag.Object => printObject(e)
            case ExprTag.Spread => printSpread(e)
            case ExprTag.Arrow => printArrow(e, level)
            case ExprTag.Function => printFunctionExpr(e)
            case ExprTag.Class => printClassExpr(e)
            case ExprTag.Template => printTemplate(e)
            case ExprTag.Unary => printUnary(e, level)
            case ExprTag.Binary => printBinary(e, level)
            case ExprTag.Ternary => printTernary(e, level)
            case ExprTag.Assign => printAssign(e, level)
            case ExprTag.Postfix => printPostfix(e)
            case ExprTag.Await => printAwait(e, level)
            case ExprTag.Yield => printYield(e, level)
            case ExprTag.TypeCast => printTypeCast(e, level)
            case ExprTag.JsxElement => printJsxElement(e)
            case ExprTag.JsxFragment => printJsxFragment(e)
        }
    }

    /// 打印数字 - 对应 Bun E.Number
    /// 特殊值处理: NaN, Infinity, -Infinity, 十六进制等
    private func printNumber(value: Float64): Unit {
        if (value != value) {
            write("NaN")
        } else if (value == Float64.PositiveInfinity) {
            write("Infinity")
        } else if (value == Float64.NegativeInfinity) {
            write("(-Infinity)")
        } else if (value == 0.0) {
            // 区分 +0 和 -0
            if (1.0 / value < 0.0) {
                write("-0")
            } else {
                write("0")
            }
        } else {
            // 格式化数字
            var str = value.toString()
            // 确保小数点前有数字
            if (str.startsWith(".")) {
                str = "0" + str
            } else if (str.startsWith("-.")) {
                str = "-0" + str.substring(1)
            }
            write(str)
        }
    }

    /// 打印字符串字面量 - 对应 Bun E.String
    /// Bun: 根据内容选择单引号或双引号，处理转义
    private func printStringLiteral(s: String): Unit {
        write("'")
        for (c in s) {
            match (c) {
                case '\'' => write("\\'")
                case '\\' => write("\\\\")
                case '\n' => write("\\n")
                case '\r' => write("\\r")
                case '\t' => write("\\t")
                case _ =>
                    if (c.value < 0x20) {
                        write("\\x")
                        write(byteToHex(UInt8(c.value)))
                    } else {
                        write(c.toString())
                    }
            }
        }
        write("'")
    }

    /// 打印正则表达式 - 对应 Bun E.Regex
    private func printRegex(e: Expr): Unit {
        write("/")
        write(e.regexPattern)
        write("/")
        write(e.regexFlags)
    }

    /// 打印 new 表达式 - 对应 Bun E.New
    /// new Target(args)
    private func printNew(e: Expr, level: Precedence): Unit {
        // new 具有较高优先级
        if (level.ordinal() > Precedence.Member.ordinal()) {
            write("(")
        }
        write("new ")
        if (let Some(target) = e.target) {
            printExpr(target, Precedence.Member)
        }
        write("(")
        for (i in 0..e.args.size) {
            printExpr(e.args[i], Precedence.Comma)
            if (i < e.args.size - 1) {
                write(", ")
            }
        }
        write(")")
        if (level.ordinal() > Precedence.Member.ordinal()) {
            write(")")
        }
    }

    /// 打印调用表达式 - 对应 Bun E.Call
    /// target(args)
    private func printCall(e: Expr, level: Precedence): Unit {
        if (level.ordinal() > Precedence.Postfix.ordinal()) {
            write("(")
        }
        if (let Some(target) = e.target) {
            printExpr(target, Precedence.Call)
        }
        if (let Some(chain) = e.optionalChain) {
            // 已包含在 target 中
        }
        write("(")
        for (i in 0..e.args.size) {
            printExpr(e.args[i], Precedence.Comma)
            if (i < e.args.size - 1) {
                write(", ")
            }
        }
        write(")")
        if (level.ordinal() > Precedence.Postfix.ordinal()) {
            write(")")
        }
    }

    /// 打印点访问表达式 - 对应 Bun E.Dot
    /// target.name
    private func printDot(e: Expr, level: Precedence): Unit {
        if (level.ordinal() > Precedence.Member.ordinal()) {
            write("(")
        }
        if (let Some(target) = e.target) {
            printExpr(target, Precedence.Member)
        }
        if (let Some(chain) = e.optionalChain) {
            match (chain) {
                case OptionalChain.Start => write("?.")
                case OptionalChain.Continuation => write(".")
            }
        } else {
            write(".")
        }
        write(e.propertyName)
        if (level.ordinal() > Precedence.Member.ordinal()) {
            write(")")
        }
    }

    /// 打印索引访问表达式 - 对应 Bun E.Index
    /// target[index]
    private func printIndex(e: Expr, level: Precedence): Unit {
        if (level.ordinal() > Precedence.Member.ordinal()) {
            write("(")
        }
        if (let Some(target) = e.target) {
            printExpr(target, Precedence.Member)
        }
        write("[")
        if (let Some(index) = e.indexExpr) {
            printExpr(index, Precedence.Lowest)
        }
        write("]")
        if (level.ordinal() > Precedence.Member.ordinal()) {
            write(")")
        }
    }

    /// 打印数组表达式 - 对应 Bun E.Array
    /// [item1, item2, ...]
    private func printArray(e: Expr): Unit {
        write("[")
        for (i in 0..e.items.size) {
            printExpr(e.items[i], Precedence.Comma)
            if (i < e.items.size - 1) {
                write(", ")
            }
        }
        write("]")
    }

    /// 打印对象表达式 - 对应 Bun E.Object
    /// { key: value, ... }
    private func printObject(e: Expr): Unit {
        write("{")
        if (e.properties.size > 0) {
            write(" ")
            for (i in 0..e.properties.size) {
                printProperty(e.properties[i])
                if (i < e.properties.size - 1) {
                    write(", ")
                }
            }
            write(" ")
        }
        write("}")
    }

    /// 打印属性 - 对应 Bun G.Property
    /// key: value 或 method() { ... }
    private func printProperty(p: GProperty): Unit {
        match (p.kind) {
            case GPropertyKind.Spread =>
                write("...")
                if (let Some(value) = p.value) {
                    printExpr(value, Precedence.Assign)
                }
            case GPropertyKind.Getter =>
                write("get ")
                printPropertyKey(p)
                write("() ")
                if (let Some(value) = p.value) {
                    printExpr(value, Precedence.Assign)
                }
            case GPropertyKind.Setter =>
                write("set ")
                printPropertyKey(p)
                if (let Some(value) = p.value) {
                    printExpr(value, Precedence.Assign)
                }
            case GPropertyKind.Method =>
                if (p.flags.isStatic) { write("static ") }
                if (p.flags.isAsync) { write("async ") }
                printPropertyKey(p)
                // 如果 value 是函数表达式
                if (let Some(value) = p.value) {
                    if (value.tag == ExprTag.Function) {
                        if (let Some(fn) = value.fn) {
                            printFunctionArgs(fn)
                            write(" ")
                            printFunctionBody(fn)
                        }
                    } else {
                        write(": ")
                        printExpr(value, Precedence.Assign)
                    }
                }
            case GPropertyKind.Field =>
                if (p.flags.isStatic) { write("static ") }
                printPropertyKey(p)
                if (let Some(value) = p.value) {
                    write(" = ")
                    printExpr(value, Precedence.Assign)
                }
        }
    }

    /// 打印属性键
    private func printPropertyKey(p: GProperty): Unit {
        if (p.flags.isComputed) {
            write("[")
            if (let Some(keyExpr) = p.keyExpr) {
                printExpr(keyExpr, Precedence.Comma)
            }
            write("]")
        } else {
            // 检查是否是合法标识符
            if (isValidIdentifier(p.key)) {
                write(p.key)
            } else {
                printStringLiteral(p.key)
            }
        }
    }

    /// 打印展开表达式 - 对应 Bun E.Spread
    /// ...value
    private func printSpread(e: Expr): Unit {
        write("...")
        if (let Some(value) = e.value) {
            printExpr(value, Precedence.Assign)
        }
    }

    /// 打印箭头函数 - 对应 Bun E.Arrow
    /// (args) => body
    private func printArrow(e: Expr, level: Precedence): Unit {
        if (level.ordinal() >= Precedence.Assign.ordinal()) {
            write("(")
        }
        if (let Some(fn) = e.fn) {
            if (fn.isAsync) { write("async ") }
            printFunctionArgs(fn)
            write(" => ")
            match (fn.body) {
                case GFnBody.Expr(body) =>
                    // 单表达式箭头函数: x => x + 1
                    // 如果是对象字面量需要加括号
                    if (body.tag == ExprTag.Object) {
                        write("(")
                        printExpr(body, Precedence.Assign)
                        write(")")
                    } else {
                        printExpr(body, Precedence.Assign)
                    }
                case GFnBody.Stmt(body) =>
                    printStmt(body)
                case GFnBody.Stmts(body) =>
                    write("{")
                    indentLevel += 1
                    for (stmt in body) {
                        writeNewline()
                        writeIndent()
                        printStmt(stmt)
                    }
                    indentLevel -= 1
                    writeNewline()
                    writeIndent()
                    write("}")
            }
        }
        if (level.ordinal() >= Precedence.Assign.ordinal()) {
            write(")")
        }
    }

    /// 打印函数表达式 - 对应 Bun E.Function
    /// function name(args) { body }
    private func printFunctionExpr(e: Expr): Unit {
        if (let Some(fn) = e.fn) {
            printFunctionHeader(fn)
            write(" ")
            printFunctionBody(fn)
        }
    }

    /// 打印类表达式 - 对应 Bun E.Class
    private func printClassExpr(e: Expr): Unit {
        if (let Some(cls) = e.classData) {
            write("class")
            if (cls.name.length > 0) {
                write(" ")
                write(cls.name)
            }
            if (let Some(ext) = cls.extends_) {
                write(" extends ")
                printExpr(ext, Precedence.Assign)
            }
            write(" {")
            for (prop in cls.properties) {
                writeNewline()
                writeIndent()
                printProperty(prop)
            }
            writeNewline()
            writeIndent()
            write("}")
        }
    }

    /// 打印模板字面量 - 对应 Bun E.Template
    /// `string ${expr} string`
    private func printTemplate(e: Expr): Unit {
        if (let Some(tag) = e.templateTag) {
            printExpr(tag, Precedence.Member)
        }
        write("`")
        // 简化: 如果只有 stringValue
        if (e.templateParts.size == 0) {
            write(e.stringValue.toString())
        } else {
            for (i in 0..e.templateParts.size) {
                printExpr(e.templateParts[i], Precedence.Lowest)
                if (i < e.templateParts.size - 1) {
                    write("${")  // 模板表达式分隔
                }
            }
        }
        write("`")
    }

    /// 打印一元表达式 - 对应 Bun E.Unary
    /// op value 或 value op
    private func printUnary(e: Expr, level: Precedence): Unit {
        if (level.ordinal() > Precedence.Unary.ordinal()) {
            write("(")
        }
        let op = e.op
        let opText = op.text()
        // 判断是否为前缀操作符
        match (op) {
            case OpCode.UnPos | OpCode.UnNeg | OpCode.UnCpl | OpCode.UnNot =>
                write(opText)
                if (let Some(value) = e.value) {
                    printExpr(value, Precedence.Unary)
                }
            case OpCode.UnVoid | OpCode.UnDelete | OpCode.Typeof =>
                write(opText)
                write(" ")
                if (let Some(value) = e.value) {
                    printExpr(value, Precedence.Unary)
                }
            case _ =>
                write(opText)
                if (let Some(value) = e.value) {
                    printExpr(value, Precedence.Unary)
                }
        }
        if (level.ordinal() > Precedence.Unary.ordinal()) {
            write(")")
        }
    }

    /// 打印二元表达式 - 对应 Bun E.Binary
    /// left op right
    private func printBinary(e: Expr, level: Precedence): Unit {
        let opLevel = opCodeToPrecedence(e.op)
        let needParens = level.ordinal() > opLevel.ordinal()
        if (needParens) {
            write("(")
        }
        if (let Some(left) = e.left) {
            printExpr(left, opLevel)
        }
        write(" ")
        write(e.op.text())
        write(" ")
        if (let Some(right) = e.right) {
            // 右操作数可能需要更高优先级
            printExpr(right, opLevel)
        }
        if (needParens) {
            write(")")
        }
    }

    /// 打印三元表达式 - 对应 Bun E.If
    /// test ? yes : no
    private func printTernary(e: Expr, level: Precedence): Unit {
        if (level.ordinal() >= Precedence.Conditional.ordinal()) {
            write("(")
        }
        if (let Some(test) = e.test) {
            printExpr(test, Precedence.Conditional)
        }
        write(" ? ")
        if (let Some(yes) = e.yes) {
            printExpr(yes, Precedence.Assign)
        }
        write(" : ")
        if (let Some(no) = e.no) {
            printExpr(no, Precedence.Assign)
        }
        if (level.ordinal() >= Precedence.Conditional.ordinal()) {
            write(")")
        }
    }

    /// 打印赋值表达式 - 对应 Bun E.Assign
    /// target = value
    private func printAssign(e: Expr, level: Precedence): Unit {
        if (level.ordinal() > Precedence.Assign.ordinal()) {
            write("(")
        }
        if (let Some(target) = e.target) {
            printExpr(target, Precedence.Assign)
        }
        write(" ")
        write(e.op.text())
        write(" ")
        if (let Some(value) = e.value) {
            printExpr(value, Precedence.Assign)
        }
        if (level.ordinal() > Precedence.Assign.ordinal()) {
            write(")")
        }
    }

    /// 打印后缀表达式 - 对应 Bun E.Postfix
    /// value++ / value--
    private func printPostfix(e: Expr): Unit {
        if (let Some(value) = e.value) {
            printExpr(value, Precedence.Postfix)
        }
        write(e.op.text())
    }

    /// 打印 await 表达式 - 对应 Bun eAwait
    /// await value
    private func printAwait(e: Expr, level: Precedence): Unit {
        if (level.ordinal() > Precedence.Unary.ordinal()) {
            write("(")
        }
        write("await ")
        if (let Some(value) = e.value) {
            printExpr(value, Precedence.Unary)
        }
        if (level.ordinal() > Precedence.Unary.ordinal()) {
            write(")")
        }
    }

    /// 打印 yield 表达式 - 对应 Bun e_yield
    /// yield value 或 yield* value
    private func printYield(e: Expr, level: Precedence): Unit {
        if (level.ordinal() > Precedence.Assign.ordinal()) {
            write("(")
        }
        write("yield")
        if (let Some(value) = e.value) {
            write(" ")
            printExpr(value, Precedence.Assign)
        }
        if (level.ordinal() > Precedence.Assign.ordinal()) {
            write(")")
        }
    }

    /// 打印类型断言 - 对应 TypeScript as/<> 断言
    private func printTypeCast(e: Expr, level: Precedence): Unit {
        if (let Some(value) = e.value) {
            printExpr(value, level)
        }
        if (opts.outputTypescript) {
            write(" as ")
            write(e.propertyName)
        }
    }

    /// 打印 JSX 元素 - 对应 Bun E.JsxElement
    /// <Tag props>children</Tag>
    private func printJsxElement(e: Expr): Unit {
        write("<")
        if (let Some(tag) = e.jsxTag) {
            printExpr(tag, Precedence.Member)
        }
        // 属性
        for (prop in e.jsxProps) {
            write(" ")
            write(prop.key)
            if (let Some(value) = prop.value) {
                write("=")
                if (value.tag == ExprTag.String) {
                    write("\"")
                    write(value.stringValue.toString())
                    write("\"")
                } else {
                    write("{")
                    printExpr(value, Precedence.Comma)
                    write("}")
                }
            }
        }
        if (e.jsxChildren.size == 0) {
            write(" />")
        } else {
            write(">")
            for (child in e.jsxChildren) {
                printExpr(child, Precedence.Lowest)
            }
            write("</")
            if (let Some(tag) = e.jsxTag) {
                printExpr(tag, Precedence.Member)
            }
            write(">")
        }
    }

    /// 打印 JSX 片段 - 对应 Bun E.JsxFragment
    /// <>children</>
    private func printJsxFragment(e: Expr): Unit {
        write("<>")
        for (child in e.jsxChildren) {
            printExpr(child, Precedence.Lowest)
        }
        write("</>")
    }

    // ========================================================================
    // 绑定打印 - 对应 Bun printBinding
    // ========================================================================

    /// 打印绑定模式 - 对应 Bun Binding print
    private func printBinding(b: Binding): Unit {
        match (b.tag) {
            case BindingTag.Identifier =>
                write(b.name)
            case BindingTag.Array =>
                write("[")
                for (i in 0..b.arrayItems.size) {
                    let item = b.arrayItems[i]
                    if (item.isRest) { write("...") }
                    printBinding(item)
                    if (i < b.arrayItems.size - 1) { write(", ") }
                }
                write("]")
            case BindingTag.Object =>
                write("{")
                for (i in 0..b.objectProperties.size) {
                    let prop = b.objectProperties[i]
                    if (prop.isShorthand) {
                        write(prop.key)
                    } else {
                        write(prop.key)
                        write(": ")
                        if (let Some(value) = prop.value) {
                            printBinding(value)
                        }
                    }
                    if (i < b.objectProperties.size - 1) { write(", ") }
                }
                write("}")
            case BindingTag.Missing => () // 缺失绑定不输出
        }
    }

    // ========================================================================
    // 辅助函数
    // ========================================================================

    /// 打印函数头 - function [async] [name](args)
    private func printFunctionHeader(fn: GFn): Unit {
        if (fn.isAsync) { write("async ") }
        if (fn.isGenerator) { write("function* ") } else { write("function ") }
        if (fn.name.length > 0) {
            write(fn.name)
        }
        printFunctionArgs(fn)
    }

    /// 打印函数参数
    private func printFunctionArgs(fn: GFn): Unit {
        write("(")
        for (i in 0..fn.args.size) {
            let arg = fn.args[i]
            if (arg.isRest) { write("...") }
            printBinding(arg.binding)
            if (let Some(default_) = arg.default_) {
                write(" = ")
                printExpr(default_, Precedence.Assign)
            }
            if (i < fn.args.size - 1) {
                write(", ")
            }
        }
        write(")")
    }

    /// 打印函数体
    private func printFunctionBody(fn: GFn): Unit {
        match (fn.body) {
            case GFnBody.Stmt(body) => printStmt(body)
            case GFnBody.Stmts(body) =>
                write("{")
                indentLevel += 1
                for (stmt in body) {
                    writeNewline()
                    writeIndent()
                    printStmt(stmt)
                }
                indentLevel -= 1
                writeNewline()
                writeIndent()
                write("}")
            case GFnBody.Expr(body) =>
                write("{ return ")
                printExpr(body, Precedence.Lowest)
                write("; }")
        }
    }

    /// OpCode 映射到优先级
    private func opCodeToPrecedence(op: OpCode): Precedence {
        match (op) {
            case OpCode.Comma => Precedence.Comma
            case OpCode.BinLoOr => Precedence.LogicalOr
            case OpCode.BinLoAnd => Precedence.LogicalAnd
            case OpCode.BinOr => Precedence.BitwiseOr
            case OpCode.BinXor => Precedence.BitwiseXor
            case OpCode.BinAnd => Precedence.BitwiseAnd
            case OpCode.BinEq | OpCode.BinNe | OpCode.BinEqStrict | OpCode.BinNeStrict =>
                Precedence.Equality
            case OpCode.BinLt | OpCode.BinGt | OpCode.BinLe | OpCode.BinGe |
                 OpCode.BinIn | OpCode.BinInstanceof =>
                Precedence.Relational
            case OpCode.BinShl | OpCode.BinShr | OpCode.BinUShr =>
                Precedence.Shift
            case OpCode.BinAdd | OpCode.BinSub =>
                Precedence.Additive
            case OpCode.BinMul | OpCode.BinDiv | OpCode.BinRem =>
                Precedence.Multiplicative
            case OpCode.BinPow =>
                Precedence.Exponentiation
            case OpCode.BinNullish =>
                Precedence.Nullish
            case _ => Precedence.Lowest
        }
    }

    /// 写入声明类型关键字
    private func writeDeclKind(kind: DeclKind): Unit {
        match (kind) {
            case DeclKind.Var => write("var")
            case DeclKind.Let => write("let")
            case DeclKind.Const => write("const")
            case DeclKind.Using => write("using")
            case DeclKind.AwaitUsing => write("await using")
        }
    }

    /// 检查是否为合法 JS 标识符
    private func isValidIdentifier(s: String): Bool {
        if (s.length == 0) { return false }
        let first = s[0]
        if (!((first >= 'a' && first <= 'z') || (first >= 'A' && first <= 'Z') || first == '_' || first == '$')) {
            return false
        }
        for (c in s) {
            if (!((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') ||
                  (c >= '0' && c <= '9') || c == '_' || c == '$')) {
                return false
            }
        }
        return true
    }

    /// 字节转十六进制
    private func byteToHex(b: UInt8): String {
        let hex = "0123456789abcdef"
        let hi = Int32(b >> 4)
        let lo = Int32(b & 0x0F)
        return "${hex[hi]}${hex[lo]}"
    }

    /// 写入字符串
    private func write(s: String): Unit {
        sb.append(s)
    }

    /// 写入缩进
    private func writeIndent(): Unit {
        if (!opts.minify) {
            for (i in 0..indentLevel) {
                sb.append(opts.indentStr)
            }
        }
    }

    /// 写入换行
    private func writeNewline(): Unit {
        if (!opts.minify) {
            sb.append(opts.newline)
        }
    }
}
