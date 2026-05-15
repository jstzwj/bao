// bao_css - CSS Printer (CSS 序列化打印器)
// 严格翻译自: bun/src/css/printer.zig
//   对应: Printer struct - CSS 输出目标 (管理缩进/换行/源码位置)
//   对应: PrinterOptions - 打印选项 (minify, targets, source_map, etc.)
//   对应: PseudoClasses - 伪类替换映射 (用于 polyfill)
//   对应: Targets - 目标浏览器
//   对应: ImportInfo - 导入记录信息
//   对应: StyleContext - 样式上下文 (用于嵌套规则)
package bao_css

import bao_core.*
import bao_collections.*

// ============================================================================
// 伪类替换映射
// 严格翻译自: printer.zig PseudoClasses
// ============================================================================

/// 伪类到类名的替换映射
/// 严格翻译自 PseudoClasses struct
/// 用于将 :hover, :focus 等替换为 JavaScript 可控制的类名
public class CssPseudoClasses {
    /// 替换 :hover 的类名
    public var hover: ?String
    /// 替换 :active 的类名
    public var active: ?String
    /// 替换 :focus 的类名
    public var focus: ?String
    /// 替换 :focus-visible 的类名
    public var focusVisible: ?String
    /// 替换 :focus-within 的类名
    public var focusWithin: ?String

    public init() {
        this.hover = None
        this.active = None
        this.focus = None
        this.focusVisible = None
        this.focusWithin = None
    }
}

// ============================================================================
// 打印选项
// 严格翻译自: printer.zig PrinterOptions
// ============================================================================

/// CSS 打印选项
/// 严格翻译自 PrinterOptions struct
public class CssPrinterOptions {
    /// 是否压缩 (移除空白)
    public var minify: Bool
    /// 项目根路径 (用于 CSS Modules hash)
    public var projectRoot: ?String
    /// 公共路径前缀
    public var publicPath: String
    /// 是否分析依赖 (@import, url())
    public var analyzeDependencies: Bool
    /// CSS Modules 配置
    public var cssModules: ?CssModulesConfig
    /// 目标浏览器
    public var targets: CssTargets
    /// 伪类替换映射
    public var pseudoClasses: ?CssPseudoClasses

    public init() {
        this.minify = false
        this.projectRoot = None
        this.publicPath = ""
        this.analyzeDependencies = false
        this.cssModules = None
        this.targets = CssTargets()
        this.pseudoClasses = None
    }

    public static func default(): CssPrinterOptions {
        CssPrinterOptions()
    }

    public static func withMinify(minify: Bool): CssPrinterOptions {
        let opts = CssPrinterOptions()
        opts.minify = minify
        return opts
    }
}

// ============================================================================
// CSS 打印器
// 严格翻译自: printer.zig Printer
// ============================================================================

/// CSS 打印器
/// 严格翻译自 Printer struct
/// 管理 CSS 输出, 缩进, 换行等
public class CssPrinter {
    /// 输出缓冲
    private var output: StringBuilder
    /// 打印选项
    public var options: CssPrinterOptions
    /// 当前缩进级别
    private var indentLevel: Int64
    /// 是否在行首
    private var atLineStart: Bool
    /// 当前行号
    public var line: Int64
    /// 当前列号
    public var column: Int64

    public init() {
        this.output = StringBuilder()
        this.options = CssPrinterOptions()
        this.indentLevel = 0
        this.atLineStart = true
        this.line = 1
        this.column = 1
        this.vendorPrefix = VendorPrefix()
        this.cssModule = None
        this.context = None
        this.removeImports = false
    }

    public init(options: CssPrinterOptions) {
        this.output = StringBuilder()
        this.options = options
        this.indentLevel = 0
        this.atLineStart = true
        this.line = 1
        this.column = 1
        this.vendorPrefix = VendorPrefix()
        this.cssModule = None
        this.context = None
        this.removeImports = options.analyzeDependencies
    }

    // ========================================================================
    // 写入方法
    // 严格翻译自: Printer 中的各 write 方法
    // ========================================================================

    /// 写入字符串
    /// 严格翻译自 Printer.writeStr
    public func writeStr(s: String): Unit {
        output.append(s)
        column += s.length
        atLineStart = false
    }

    /// 写入字符
    /// 严格翻译自 Printer.writeChar
    public func writeChar(c: UInt8): Unit {
        output.append(c)
        column += 1
        atLineStart = false
    }

    /// 写入换行 (如果未压缩)
    /// 严格翻译自 Printer.newline
    public func newline(): Unit {
        if (!options.minify) {
            output.append('\n')
            line += 1
            column = 1
            atLineStart = true
        } else {
            // 压缩模式下用空格分隔
            output.append(' ')
            column += 1
        }
    }

    /// 写入空白 (如果未压缩)
    /// 严格翻译自 Printer.whitespace
    public func whitespace(): Unit {
        if (!options.minify) {
            output.append(' ')
            column += 1
        }
    }

    /// 写入分隔符后跟空白
    /// 严格翻译自 Printer.delim
    public func delim(c: UInt8, wsBefore: Bool): Unit {
        if (wsBefore) {
            whitespace()
        }
        writeChar(c)
        whitespace()
    }

    /// 写入缩进
    public func writeIndent(): Unit {
        if (!options.minify) {
            var i: Int64 = 0
            while (i < indentLevel) {
                output.append("  ")
                column += 2
                i++
            }
        }
    }

    /// 增加缩进
    public func indent(): Unit {
        indentLevel += 1
    }

    /// 减少缩进
    public func dedent(): Unit {
        if (indentLevel > 0) {
            indentLevel -= 1
        }
    }

    /// 是否嵌套 (缩进级别 > 1)
    /// 严格翻译自 Printer.isNested
    public func isNested(): Bool {
        indentLevel > 1
    }

    /// 当前供应商前缀
    /// 严格翻译自 Printer.vendor_prefix
    public var vendorPrefix: VendorPrefix

    /// CSS Modules 上下文 (用于打印时处理 composes 等)
    /// 严格翻译自 Printer.css_module
    public var cssModule: ?CssModule

    /// 样式上下文 (用于嵌套规则)
    /// 严格翻译自 Printer.ctx
    public var context: ?CssStyleContext

    /// 是否移除 @import 规则 (收集依赖时)
    /// 严格翻译自 Printer.remove_imports
    public var removeImports: Bool

    // ========================================================================
    // 样式表序列化
    // ========================================================================

    /// 打印样式表
    public func printStylesheet(rules: CssRuleList): String {
        var first = true
        for (rule in rules.rules) {
            if (!first && !options.minify) {
                newline()
            }
            printRule(rule)
            first = false
        }
        return output.toString()
    }

    /// 打印单个规则
    public func printRule(rule: CssRule): Unit {
        let css = rule.toCss("")
        if (css.length > 0) {
            writeIndent()
            writeStr(css)
        }
    }

    /// 打印声明块
    public func printDeclarationBlock(block: CssDeclarationBlock): Unit {
        if (block.isEmpty()) { return }

        whitespace()
        writeChar('{')
        indent()

        let length = block.len()
        var i: Int64 = 0

        for (decl in block.declarations) {
            newline()
            writeIndent()
            writeStr(decl.toString())
            i++
            if (i < length || !options.minify) {
                writeChar(';')
            }
        }

        for (decl in block.importantDeclarations) {
            newline()
            writeIndent()
            writeStr(decl.toString())
            i++
            if (i < length || !options.minify) {
                writeChar(';')
            }
        }

        dedent()
        newline()
        writeIndent()
        writeChar('}')
    }

    /// 打印选择器列表 + 声明块
    public func printStyleRule(selectors: CssSelectorList, declarations: CssDeclarationBlock): Unit {
        writeStr(selectors.toString())
        printDeclarationBlock(declarations)
    }

    /// 写入注释
    /// 严格翻译自 Printer.writeComment
    public func writeComment(comment: String): Unit {
        output.append(comment)
        let newlines = countNewlines(comment)
        line += newlines
        if (newlines > 0) {
            let lastNewline = comment.lastIndexOf('\n')
            if (lastNewline >= 0) {
                column = Int64(comment.length - lastNewline - 1)
            } else {
                column = 0
            }
        } else {
            column += Int64(comment.length)
        }
    }

    /// 获取当前源文件名
    /// 严格翻译自 Printer.filename
    public func filename(): String {
        "<input>"
    }

    /// 获取当前上下文
    /// 严格翻译自 Printer.context
    public func getStyleContext(): ?CssStyleContext {
        context
    }

    /// 带上下文执行闭包
    /// 严格翻译自 Printer.withContext
    public func withContext(selectors: CssSelectorList, fn: () -> Unit): Unit {
        let parent = context
        let ctx = CssStyleContext(selectors)
        if (parent != None) {
            match (parent) {
                case Some(p) => ctx.parent = Some(p)
                case None => {}
            }
        }
        context = Some(ctx)
        fn()
        context = parent
    }

    /// 统计字符串中的换行数
    private static func countNewlines(s: String): Int64 {
        var count: Int64 = 0
        for (c in s) {
            if (c == '\n') { count++ }
        }
        return count
    }

    // ========================================================================
    // CSS 标识符序列化
    // 严格翻译自: serializer.zig serializeIdentifier
    // ========================================================================

    /// 序列化 CSS 标识符 (处理需要转义的字符)
    public static func serializeIdentifier(ident: String): String {
        let sb = StringBuilder()
        var i: Int64 = 0
        let chars = ident.toArray()

        while (i < chars.length) {
            let c = chars[i]
            if (i == 0) {
                // 第一个字符的特殊处理
                if (c >= '0' && c <= '9') {
                    sb.append("\\${c}")
                } else if (c == '-') {
                    if (i + 1 < chars.length && chars[i + 1] >= '0' && chars[i + 1] <= '9') {
                        sb.append("\\-")
                    } else {
                        sb.append(c)
                    }
                } else {
                    sb.append(serializeIdentChar(c))
                }
            } else {
                sb.append(serializeIdentChar(c))
            }
            i++
        }

        return sb.toString()
    }

    private static func serializeIdentChar(c: UInt8): String {
        if (c == '\0') { return "\u{FFFD}" }
        if (c >= 'a' && c <= 'z') { return "${c}" }
        if (c >= 'A' && c <= 'Z') { return "${c}" }
        if (c >= '0' && c <= '9') { return "${c}" }
        if (c == '-' || c == '_' ) { return "${c}" }
        // 需要转义
        return "\\${c}"
    }

    // ========================================================================
    // 获取输出
    // ========================================================================

    /// 获取输出字符串
    public func getOutput(): String {
        output.toString()
    }

    /// 清空输出
    public func clear(): Unit {
        output.clear()
        indentLevel = 0
        atLineStart = true
        line = 1
        column = 1
    }
}

// ============================================================================
// CSS 序列化工具
// 严格翻译自: serializer.zig
// ============================================================================

/// CSS 序列化工具函数
public class CssSerializer {
    /// 将 CSS AST 规则列表序列化为字符串
    public static func toCss(rules: CssRuleList, minify: Bool): String {
        let printer = CssPrinter(CssPrinterOptions.withMinify(minify))
        printer.printStylesheet(rules)
        return printer.getOutput()
    }

    /// 序列化样式表 (默认格式化)
    public static func toCssPretty(rules: CssRuleList): String {
        toCss(rules, false)
    }

    /// 序列化样式表 (压缩)
    public static func toCssMinified(rules: CssRuleList): String {
        toCss(rules, true)
    }

    /// 序列化标识符
    public static func serializeIdentifier(ident: String): String {
        CssPrinter.serializeIdentifier(ident)
    }
}
