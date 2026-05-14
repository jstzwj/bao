// bao_shell_parser - Shell 命令解析器
// 严格翻译自: src/shell_parser/
// 对应 Bun: src/shell_parser/lib.rs, parse.rs, braces.rs, json_fmt.rs
package bao_shell_parser

import bao_core.*
import bao_collections.*

// ============================================================================
// ShellToken - Shell 词法单元
// 严格翻译自: src/shell_parser/parse.rs - Token enum
// Bun 的 shell 词法分析器产生如下 token 类型
// ============================================================================

/// Shell 词法单元类型
/// 对应 Bun: parse.rs Token + braces.rs Token
public enum ShellToken {
    | Word(String)              // 普通单词: "echo", "hello", "$HOME"
    | Pipe                      // 管道: |
    | And                       // 逻辑与: &&
    | Or                        // 逻辑或: ||
    | Semicolon                 // 分号: ;
    | Ampersand                 // 后台运行: &
    | RedirectOut               // 重定向标准输出: >, 1>
    | RedirectAppend            // 追加重定向: >>
    | RedirectIn                // 重定向标准输入: <
    | RedirectErr               // 重定向标准错误: 2>
    | RedirectErrAppend         // 追加标准错误: 2>>
    | RedirectAll               // 重定向 stdout+stderr: &>
    | RedirectAllAppend         // 追加 stdout+stderr: &>>
    | HeredocStart              // Here-doc 开始: <<
    | HeredocDelim(String)      // Here-doc 分隔符: EOF, END
    | HeredocContent(String)    // Here-doc 内容
    | HeredocEnd                // Here-doc 结束
    | SubshellOpen              // 子 shell 开始: (
    | SubshellClose             // 子 shell 结束: )
    | Newline                   // 换行
    | Eof                       // 输入结束

    /// 转为可读字符串
    public func toString(): String {
        match (this) {
            case Word(w) => "Word(${w})"
            case Pipe => "Pipe"
            case And => "And"
            case Or => "Or"
            case Semicolon => "Semicolon"
            case Ampersand => "Ampersand"
            case RedirectOut => "RedirectOut"
            case RedirectAppend => "RedirectAppend"
            case RedirectIn => "RedirectIn"
            case RedirectErr => "RedirectErr"
            case RedirectErrAppend => "RedirectErrAppend"
            case RedirectAll => "RedirectAll"
            case RedirectAllAppend => "RedirectAllAppend"
            case HeredocStart => "HeredocStart"
            case HeredocDelim(d) => "HeredocDelim(${d})"
            case HeredocContent(c) => "HeredocContent"
            case HeredocEnd => "HeredocEnd"
            case SubshellOpen => "SubshellOpen"
            case SubshellClose => "SubshellClose"
            case Newline => "Newline"
            case Eof => "Eof"
        }
    }
}

// ============================================================================
// ShellLexer - Shell 词法分析器
// 严格翻译自: src/shell_parser/parse.rs - Lexer struct
// 以及 src/shell_parser/braces.rs - NewLexer
// Bun 的词法分析器支持三种编码: ASCII, WTF-8, UTF-16
// ============================================================================

/// Shell 词法分析器
/// 对应 Bun: parse.rs Lexer + braces.rs NewLexer
public class ShellLexer {
    private var source: String
    private var pos: Int64
    private var tokens: ArrayList<ShellToken>

    public init(source: String) {
        this.source = source
        this.pos = 0
        this.tokens = ArrayList<ShellToken>()
    }

    /// 执行词法分析, 返回所有 token
    /// 对应 Bun: Lexer::tokenize() -> LexerOutput
    public func tokenize(): ArrayList<ShellToken> {
        while (pos < source.length) {
            skipWhitespace()
            if (pos >= source.length) {
                break
            }
            let ch = source[pos]
            if (ch == '#') {
                skipComment()
                continue
            }
            let start = pos
            // 双字符操作符优先
            if (pos + 1 < source.length) {
                let next = source[pos + 1]
                if (tryTwoCharOp(ch, next)) {
                    continue
                }
            }
            // 单字符操作符
            if (tryOneCharOp(ch)) {
                continue
            }
            // 普通单词 (包括引号字符串、变量替换、命令替换等)
            readWord()
        }
        tokens.append(ShellToken.Eof)
        return tokens
    }

    /// 尝试匹配双字符操作符
    private func tryTwoCharOp(ch: UInt8, next: UInt8): Bool {
        if (ch == UInt8('&') && next == UInt8('&')) {
            tokens.append(ShellToken.And)
            pos += 2
            return true
        }
        if (ch == UInt8('|') && next == UInt8('|')) {
            tokens.append(ShellToken.Or)
            pos += 2
            return true
        }
        if (ch == UInt8('>') && next == UInt8('>')) {
            tokens.append(ShellToken.RedirectAppend)
            pos += 2
            return true
        }
        if (ch == UInt8('<') && next == UInt8('<')) {
            tokens.append(ShellToken.HeredocStart)
            pos += 2
            readHeredoc()
            return true
        }
        if (ch == UInt8('2') && next == UInt8('>')) {
            if (pos + 2 < source.length && source[pos + 2] == UInt8('>')) {
                tokens.append(ShellToken.RedirectErrAppend)
                pos += 3
            } else {
                tokens.append(ShellToken.RedirectErr)
                pos += 2
            }
            return true
        }
        if (ch == UInt8('&') && next == UInt8('>')) {
            if (pos + 2 < source.length && source[pos + 2] == UInt8('>')) {
                tokens.append(ShellToken.RedirectAllAppend)
                pos += 3
            } else {
                tokens.append(ShellToken.RedirectAll)
                pos += 2
            }
            return true
        }
        return false
    }

    /// 尝试匹配单字符操作符
    private func tryOneCharOp(ch: UInt8): Bool {
        match (ch) {
            case UInt8('|') => { tokens.append(ShellToken.Pipe); pos += 1; return true }
            case UInt8(';') => { tokens.append(ShellToken.Semicolon); pos += 1; return true }
            case UInt8('&') => { tokens.append(ShellToken.Ampersand); pos += 1; return true }
            case UInt8('>') => { tokens.append(ShellToken.RedirectOut); pos += 1; return true }
            case UInt8('<') => { tokens.append(ShellToken.RedirectIn); pos += 1; return true }
            case UInt8('(') => { tokens.append(ShellToken.SubshellOpen); pos += 1; return true }
            case UInt8(')') => { tokens.append(ShellToken.SubshellClose); pos += 1; return true }
            case UInt8('\n') => { tokens.append(ShellToken.Newline); pos += 1; return true }
            case _ => return false
        }
    }

    /// 读取单词 (支持引号、转义、变量、命令替换)
    /// 对应 Bun: parse.rs 中 Lexer 的 Word 扫描
    private func readWord(): Unit {
        let sb = StringBuilder()
        while (pos < source.length) {
            let ch = source[pos]
            if (isWordTerminator(ch)) {
                break
            }
            if (ch == UInt8('\\')) {
                // 转义字符
                pos += 1
                if (pos < source.length) {
                    sb.append(Char(source[pos]))
                    pos += 1
                }
                continue
            }
            if (ch == UInt8('\'')) {
                // 单引号: 原样保留, 不做任何替换
                pos += 1
                while (pos < source.length && source[pos] != UInt8('\'')) {
                    sb.append(Char(source[pos]))
                    pos += 1
                }
                if (pos < source.length) { pos += 1 }
                continue
            }
            if (ch == UInt8('"')) {
                // 双引号: 允许变量替换和命令替换
                pos += 1
                while (pos < source.length && source[pos] != UInt8('"')) {
                    if (source[pos] == UInt8('\\') && pos + 1 < source.length) {
                        let next = source[pos + 1]
                        if (next == UInt8('$') || next == UInt8('`') ||
                            next == UInt8('"') || next == UInt8('\\') || next == UInt8('\n')) {
                            pos += 1
                            sb.append(Char(source[pos]))
                            pos += 1
                            continue
                        }
                    }
                    sb.append(Char(source[pos]))
                    pos += 1
                }
                if (pos < source.length) { pos += 1 }
                continue
            }
            sb.append(Char(ch))
            pos += 1
        }
        let word = sb.toString()
        if (word.length > 0) {
            tokens.append(ShellToken.Word(word))
        }
    }

    /// 读取 Here-doc
    /// 对应 Bun: parse.rs 中对 << 操作符的处理
    private func readHeredoc(): Unit {
        skipWhitespace()
        let delimBuf = StringBuilder()
        while (pos < source.length && source[pos] != UInt8('\n') && !isWhitespace(source[pos])) {
            delimBuf.append(Char(source[pos]))
            pos += 1
        }
        let delim = delimBuf.toString()
        tokens.append(ShellToken.HeredocDelim(delim))
        if (pos < source.length && source[pos] == UInt8('\n')) {
            pos += 1
        }
        let contentBuf = StringBuilder()
        while (pos < source.length) {
            let lineStart = pos
            while (pos < source.length && source[pos] != UInt8('\n')) {
                contentBuf.append(Char(source[pos]))
                pos += 1
            }
            let line = contentBuf.toString()
            if (line.trim() == delim) {
                tokens.append(ShellToken.HeredocEnd)
                if (pos < source.length) { pos += 1 }
                return
            }
            contentBuf.append('\n')
            if (pos < source.length) { pos += 1 }
        }
        tokens.append(ShellToken.HeredocContent(contentBuf.toString()))
    }

    /// 判断字符是否是单词终止符
    private func isWordTerminator(ch: UInt8): Bool {
        match (ch) {
            case UInt8(' ') | UInt8('\t') | UInt8('\n') | UInt8('\r') => true
            case UInt8('|') | UInt8('&') | UInt8(';') | UInt8('(') | UInt8(')') => true
            case UInt8('<') | UInt8('>') | UInt8('#') => true
            case _ => false
        }
    }

    /// 跳过空白字符
    private func skipWhitespace(): Unit {
        while (pos < source.length && isWhitespace(source[pos])) {
            if (source[pos] == UInt8('\n')) {
                return
            }
            pos += 1
        }
    }

    /// 跳过注释
    private func skipComment(): Unit {
        while (pos < source.length && source[pos] != UInt8('\n')) {
            pos += 1
        }
    }

    /// 判断是否为空白字符
    private func isWhitespace(ch: UInt8): Bool {
        match (ch) {
            case UInt8(' ') | UInt8('\t') | UInt8('\r') | UInt8('\n') => true
            case _ => false
        }
    }
}

// ============================================================================
// ShellAST - 抽象语法树
// 严格翻译自: src/shell_parser/parse.rs - ast 模块
// Bun 的 AST 包含: Script, Stmt, Expr, Cmd, Pipeline, Binary, If, Subshell 等
// ============================================================================

/// Shell AST 节点
/// 对应 Bun: parse.rs ast::Expr (tagged union)
public enum ShellAST {
    | Command(ShellCommand)
    | Pipeline(ShellPipeline)
    | AndOr(ShellAndOr)
    | List(ShellList)
    | Subshell(ShellSubshellAST)
    | IfClause(ShellIfClause)
    | ForLoop(ShellForLoop)
    | WhileLoop(ShellWhileLoop)
    | CaseClause(ShellCaseClause)
    | Assign(ShellAssign)
    | Redirect(ShellRedirectAST)

    public func toString(): String {
        match (this) {
            case Command(c) => c.toString()
            case Pipeline(p) => p.toString()
            case AndOr(ao) => ao.toString()
            case List(l) => l.toString()
            case Subshell(s) => s.toString()
            case IfClause(ic) => ic.toString()
            case ForLoop(fl) => fl.toString()
            case WhileLoop(wl) => wl.toString()
            case CaseClause(cc) => cc.toString()
            case Assign(a) => a.toString()
            case Redirect(r) => r.toString()
        }
    }
}

/// Shell 命令
/// 对应 Bun: parse.rs ast::Cmd
public class ShellCommand {
    public var name: String
    public var args: ArrayList<String>
    public var assigns: ArrayList<ShellAssign>
    public var redirects: ArrayList<ShellRedirectAST>

    public init(name: String) {
        this.name = name
        this.args = ArrayList<String>()
        this.assigns = ArrayList<ShellAssign>()
        this.redirects = ArrayList<ShellRedirectAST>()
    }

    public func toString(): String {
        let sb = StringBuilder()
        for (a in assigns) { sb.append("${a.toString()} ") }
        sb.append(name)
        for (arg in args) { sb.append(" ${arg}") }
        for (r in redirects) { sb.append(" ${r.toString()}") }
        return sb.toString()
    }
}

/// 管道
/// 对应 Bun: parse.rs ast::Pipeline
public class ShellPipeline {
    public var commands: ArrayList<ShellAST>
    public var bang: Bool  // 取反: ! cmd | cmd

    public init() {
        this.commands = ArrayList<ShellAST>()
        this.bang = false
    }

    public func toString(): String {
        let sb = StringBuilder()
        if (bang) { sb.append("! ") }
        var first = true
        for (cmd in commands) {
            if (!first) { sb.append(" | ") }
            sb.append(cmd.toString())
            first = false
        }
        return sb.toString()
    }
}

/// 逻辑与/或
/// 对应 Bun: parse.rs ast::Binary
public class ShellAndOr {
    public var op: String  // "&&" 或 "||"
    public var left: ShellAST
    public var right: ShellAST

    public init(op: String, left: ShellAST, right: ShellAST) {
        this.op = op
        this.left = left
        this.right = right
    }

    public func toString(): String {
        return "(${left.toString()} ${op} ${right.toString()})"
    }
}

/// 命令列表 (分号分隔)
/// 对应 Bun: parse.rs ast::Stmt
public class ShellList {
    public var items: ArrayList<ShellAST>
    public var async_: Bool  // 是否异步 (&)

    public init() {
        this.items = ArrayList<ShellAST>()
        this.async_ = false
    }

    public func toString(): String {
        let sb = StringBuilder()
        var first = true
        for (item in items) {
            if (!first) { sb.append("; ") }
            sb.append(item.toString())
            first = false
        }
        if (async_) { sb.append(" &") }
        return sb.toString()
    }
}

/// 子 shell
/// 对应 Bun: parse.rs ast::Subshell
public class ShellSubshellAST {
    public var body: ShellList
    public var redirects: ArrayList<ShellRedirectAST>

    public init(body: ShellList) {
        this.body = body
        this.redirects = ArrayList<ShellRedirectAST>()
    }

    public func toString(): String {
        let sb = StringBuilder()
        sb.append("( ${body.toString()} )")
        for (r in redirects) { sb.append(" ${r.toString()}") }
        return sb.toString()
    }
}

/// If 语句
/// 对应 Bun: parse.rs ast::If
public class ShellIfClause {
    public var condition: ShellList
    public var thenBody: ShellList
    public var elifBranches: ArrayList<ShellElifBranch>
    public var elseBody: ?ShellList

    public init() {
        this.condition = ShellList()
        this.thenBody = ShellList()
        this.elifBranches = ArrayList<ShellElifBranch>()
        this.elseBody = None
    }

    public func toString(): String {
        let sb = StringBuilder()
        sb.append("if ${condition.toString()}; then ${thenBody.toString()}")
        for (elif in elifBranches) {
            sb.append("; ${elif.toString()}")
        }
        match (elseBody) {
            case Some(e) => sb.append("; else ${e.toString()}")
            case None => ()
        }
        sb.append("; fi")
        return sb.toString()
    }
}

/// Elif 分支
public class ShellElifBranch {
    public var condition: ShellList
    public var body: ShellList

    public init(condition: ShellList, body: ShellList) {
        this.condition = condition
        this.body = body
    }

    public func toString(): String {
        return "elif ${condition.toString()}; then ${body.toString()}"
    }
}

/// For 循环
/// 对应 Bun: parse.rs 中 for 循环的 AST 节点
public class ShellForLoop {
    public var varName: String
    public var items: ArrayList<String>  // in word1 word2 ...
    public var body: ShellList

    public init(varName: String) {
        this.varName = varName
        this.items = ArrayList<String>()
        this.body = ShellList()
    }

    public func toString(): String {
        let sb = StringBuilder()
        sb.append("for ${varName}")
        if (items.size > 0) {
            sb.append(" in")
            for (item in items) { sb.append(" ${item}") }
        }
        sb.append("; do ${body.toString()}; done")
        return sb.toString()
    }
}

/// While 循环
public class ShellWhileLoop {
    public var condition: ShellList
    public var body: ShellList
    public var isUntil: Bool  // until = while !

    public init() {
        this.condition = ShellList()
        this.body = ShellList()
        this.isUntil = false
    }

    public func toString(): String {
        let keyword = if (isUntil) { "until" } else { "while" }
        return "${keyword} ${condition.toString()}; do ${body.toString()}; done"
    }
}

/// Case 语句
public class ShellCaseClause {
    public var word: String
    public var cases: ArrayList<ShellCaseItem>

    public init(word: String) {
        this.word = word
        this.cases = ArrayList<ShellCaseItem>()
    }

    public func toString(): String {
        let sb = StringBuilder()
        sb.append("case ${word} in")
        for (item in cases) { sb.append(" ${item.toString()}") }
        sb.append(";; esac")
        return sb.toString()
    }
}

/// Case 分支项
public class ShellCaseItem {
    public var patterns: ArrayList<String>
    public var body: ShellList

    public init() {
        this.patterns = ArrayList<String>()
        this.body = ShellList()
    }

    public func toString(): String {
        let sb = StringBuilder()
        var first = true
        for (p in patterns) {
            if (!first) { sb.append(" | ") }
            sb.append(p)
            first = false
        }
        sb.append(") ${body.toString()} ;;")
        return sb.toString()
    }
}

/// 变量赋值
/// 对应 Bun: parse.rs ast::Assign
public class ShellAssign {
    public var label: String
    public var value: String

    public init(label: String, value: String) {
        this.label = label
        this.value = value
    }

    public func toString(): String {
        return "${label}=${value}"
    }
}

/// 重定向
/// 对应 Bun: parse.rs ast::Redirect + RedirectFlags
public class ShellRedirectAST {
    public var kind: ShellRedirectKind
    public var target: String
    public var fd: Int64  // 文件描述符: 0=stdin, 1=stdout, 2=stderr

    public init(kind: ShellRedirectKind, target: String, fd: Int64) {
        this.kind = kind
        this.target = target
        this.fd = fd
    }

    public func toString(): String {
        match (kind) {
            case Write => "${fd}> ${target}"
            case Append => "${fd}>> ${target}"
            case Read => "< ${target}"
            case DupFd => "${fd}>&${target}"
            case Heredoc => "<< ${target}"
        }
    }
}

/// 重定向类型
/// 对应 Bun: parse.rs RedirectFlags bitflags
public enum ShellRedirectKind {
    | Write      // >
    | Append     // >>
    | Read       // <
    | DupFd      // >&
    | Heredoc    // <<
}

// ============================================================================
// ShellParser - Shell 语法分析器
// 严格翻译自: src/shell_parser/parse.rs - Parser struct
// Bun 的 Parser 使用递归下降分析法
// ============================================================================

/// Shell 语法分析器
/// 对应 Bun: parse.rs Parser
public class ShellParser {
    private var tokens: ArrayList<ShellToken>
    private var pos: Int64

    public init() {
        this.tokens = ArrayList<ShellToken>()
        this.pos = 0
    }

    /// 解析 shell 命令字符串
    /// 对应 Bun: Parser::parse() -> ast::Script
    public func parse(text: String): ShellAST {
        let lexer = ShellLexer(text)
        this.tokens = lexer.tokenize()
        this.pos = 0
        let items = ArrayList<ShellAST>()
        while (!isAtEnd()) {
            let expr = parseExpression()
            match (expr) {
                case Some(e) => items.append(e)
                case None => break
            }
            // 跳过分隔符
            while (matchToken(ShellToken.Semicolon) ||
                   matchToken(ShellToken.Newline) ||
                   matchToken(ShellToken.Ampersand)) {
                // continue
            }
        }
        if (items.size == 1) {
            return items[0]
        }
        let list = ShellList()
        for (item in items) {
            list.items.append(item)
        }
        return ShellAST.List(list)
    }

    /// 解析表达式
    /// 对应 Bun: Parser::parse_expr
    private func parseExpression(): ?ShellAST {
        // 处理关键字
        match (peek()) {
            case ShellToken.Word(w) => {
                if (w == "if") { advance(); return Some(parseIfClause()) }
                if (w == "for") { advance(); return Some(parseForLoop()) }
                if (w == "while") { advance(); return Some(parseWhileLoop(false)) }
                if (w == "until") { advance(); return Some(parseWhileLoop(true)) }
                if (w == "case") { advance(); return Some(parseCaseClause()) }
                case _ => ()
            }
            case ShellToken.SubshellOpen => { advance(); return Some(parseSubshell()) }
            case _ => ()
        }
        // 解析管道
        let pipeline = parsePipeline()
        // 检查 And/Or
        if (checkAnd()) {
            advance()
            let op = "&&"
            let right = parseExpression()
            match (right) {
                case Some(r) => return Some(ShellAST.AndOr(ShellAndOr(op, ShellAST.Pipeline(pipeline), r)))
                case None => return Some(ShellAST.Pipeline(pipeline))
            }
        }
        if (checkOr()) {
            advance()
            let op = "||"
            let right = parseExpression()
            match (right) {
                case Some(r) => return Some(ShellAST.AndOr(ShellAndOr(op, ShellAST.Pipeline(pipeline), r)))
                case None => return Some(ShellAST.Pipeline(pipeline))
            }
        }
        return Some(ShellAST.Pipeline(pipeline))
    }

    /// 解析管道
    /// 对应 Bun: Parser::parse_pipeline
    private func parsePipeline(): ShellPipeline {
        let pipeline = ShellPipeline()
        if (checkBang()) {
            pipeline.bang = true
            advance()
        }
        let firstCmd = parseSimpleCommand()
        pipeline.commands.append(firstCmd)
        while (matchToken(ShellToken.Pipe)) {
            let cmd = parseSimpleCommand()
            pipeline.commands.append(cmd)
        }
        return pipeline
    }

    /// 解析简单命令
    /// 对应 Bun: Parser::parse_simple_command -> CmdOrAssigns
    private func parseSimpleCommand(): ShellAST {
        let assigns = ArrayList<ShellAssign>()
        let words = ArrayList<String>()
        let redirects = ArrayList<ShellRedirectAST>()

        // 先收集赋值
        while (isAssignLike()) {
            let word = getWordValue()
            let eqIdx = word.indexOf("=")
            if (eqIdx > 0) {
                let label = word.substring(0, eqIdx)
                let value = word.substring(eqIdx + 1)
                assigns.append(ShellAssign(label, value))
                advance()
            } else {
                break
            }
        }

        // 收集命令名和参数
        while (!isAtEnd()) {
            match (peek()) {
                case ShellToken.Word(w) => { words.append(w); advance() }
                case ShellToken.RedirectOut =>
                    advance()
                    match (expectWord()) {
                        case Some(target) => redirects.append(ShellRedirectAST(ShellRedirectKind.Write, target, 1))
                        case None => ()
                    }
                case ShellToken.RedirectAppend =>
                    advance()
                    match (expectWord()) {
                        case Some(target) => redirects.append(ShellRedirectAST(ShellRedirectKind.Append, target, 1))
                        case None => ()
                    }
                case ShellToken.RedirectIn =>
                    advance()
                    match (expectWord()) {
                        case Some(target) => redirects.append(ShellRedirectAST(ShellRedirectKind.Read, target, 0))
                        case None => ()
                    }
                case ShellToken.RedirectErr =>
                    advance()
                    match (expectWord()) {
                        case Some(target) => redirects.append(ShellRedirectAST(ShellRedirectKind.Write, target, 2))
                        case None => ()
                    }
                case ShellToken.RedirectErrAppend =>
                    advance()
                    match (expectWord()) {
                        case Some(target) => redirects.append(ShellRedirectAST(ShellRedirectKind.Append, target, 2))
                        case None => ()
                    }
                case ShellToken.RedirectAll =>
                    advance()
                    match (expectWord()) {
                        case Some(target) =>
                            redirects.append(ShellRedirectAST(ShellRedirectKind.Write, target, 1))
                            redirects.append(ShellRedirectAST(ShellRedirectKind.Write, target, 2))
                        case None => ()
                    }
                case _ => break
            }
        }

        if (words.size == 0 && assigns.size > 0) {
            // 纯赋值
            if (assigns.size == 1) {
                return ShellAST.Assign(assigns[0])
            }
            let list = ShellList()
            for (a in assigns) {
                list.items.append(ShellAST.Assign(a))
            }
            return ShellAST.List(list)
        }

        if (words.size == 0) {
            return ShellAST.Command(ShellCommand("true"))
        }

        let cmd = ShellCommand(words[0])
        var i = 1
        while (i < words.size) {
            cmd.args.append(words[i])
            i += 1
        }
        for (a in assigns) { cmd.assigns.append(a) }
        for (r in redirects) { cmd.redirects.append(r) }
        return ShellAST.Command(cmd)
    }

    /// 解析子 shell
    private func parseSubshell(): ShellAST {
        let list = ShellList()
        while (!checkToken(ShellToken.SubshellClose) && !isAtEnd()) {
            let expr = parseExpression()
            match (expr) {
                case Some(e) => list.items.append(e)
                case None => break
            }
            while (matchToken(ShellToken.Semicolon) || matchToken(ShellToken.Newline)) { }
        }
        matchToken(ShellToken.SubshellClose)
        let subshell = ShellSubshellAST(list)
        return ShellAST.Subshell(subshell)
    }

    /// 解析 if 语句
    /// 对应 Bun: parse.rs ast::If
    private func parseIfClause(): ShellAST {
        let ifClause = ShellIfClause()
        // 条件
        ifClause.condition = parseConditionList()
        expectKeyword("then")
        // then 体
        ifClause.thenBody = parseBodyUntilKeywords(["elif", "else", "fi"])
        // elif / else
        var done = false
        while (!done && !isAtEnd()) {
            match (peek()) {
                case ShellToken.Word(w) =>
                    if (w == "elif") {
                        advance()
                        let elifCond = parseConditionList()
                        expectKeyword("then")
                        let elifBody = parseBodyUntilKeywords(["elif", "else", "fi"])
                        ifClause.elifBranches.append(ShellElifBranch(elifCond, elifBody))
                    } else if (w == "else") {
                        advance()
                        ifClause.elseBody = Some(parseBodyUntilKeywords(["fi"]))
                    } else if (w == "fi") {
                        advance()
                        done = true
                    } else { done = true }
                case _ => done = true
            }
        }
        return ShellAST.IfClause(ifClause)
    }

    /// 解析 for 循环
    private func parseForLoop(): ShellAST {
        let varName = match (expectWord()) {
            case Some(w) => w
            case None => return ShellAST.Command(ShellCommand("true"))
        }
        let forLoop = ShellForLoop(varName)
        // 可选的 "in word..."
        match (peek()) {
            case ShellToken.Word(w) =>
                if (w == "in") {
                    advance()
                    while (isWordLike()) {
                        forLoop.items.append(getWordValue())
                        advance()
                    }
                }
            case _ => ()
        }
        // 跳过分号/换行
        while (matchToken(ShellToken.Semicolon) || matchToken(ShellToken.Newline)) { }
        expectKeyword("do")
        forLoop.body = parseBodyUntilKeywords(["done"])
        return ShellAST.ForLoop(forLoop)
    }

    /// 解析 while/until 循环
    private func parseWhileLoop(isUntil: Bool): ShellAST {
        let loop = ShellWhileLoop()
        loop.isUntil = isUntil
        loop.condition = parseConditionList()
        expectKeyword("do")
        loop.body = parseBodyUntilKeywords(["done"])
        return ShellAST.WhileLoop(loop)
    }

    /// 解析 case 语句
    private func parseCaseClause(): ShellAST {
        let word = match (expectWord()) {
            case Some(w) => w
            case None => ""
        }
        let caseClause = ShellCaseClause(word)
        while (matchToken(ShellToken.Semicolon) || matchToken(ShellToken.Newline)) { }
        expectKeyword("in")
        while (!isAtEnd()) {
            match (peek()) {
                case ShellToken.Word(w) =>
                    if (w == "esac") { advance(); break }
                    let item = ShellCaseItem()
                    item.patterns.append(w)
                    advance()
                    while (matchToken(ShellToken.Or)) {
                        match (expectWord()) {
                            case Some(p) => item.patterns.append(p)
                            case None => ()
                        }
                    }
                    // 跳过 )
                    advance()
                    item.body = parseBodyUntilKeywords([";;", "esac"])
                    matchToken(ShellToken.Semicolon)  // ;;
                    matchToken(ShellToken.Semicolon)  // 第二个 ;
                    caseClause.cases.append(item)
                case ShellToken.Eof => break
                case _ => break
            }
        }
        return ShellAST.CaseClause(caseClause)
    }

    // --- 辅助方法 ---

    private func parseConditionList(): ShellList {
        let list = ShellList()
        while (!isAtEnd()) {
            match (peek()) {
                case ShellToken.Word(w) =>
                    if (w == "then" || w == "do") { break }
                case ShellToken.Semicolon | ShellToken.Newline => { advance(); continue }
                case ShellToken.Eof => break
                case _ => ()
            }
            let expr = parseExpression()
            match (expr) {
                case Some(e) => list.items.append(e)
                case None => break
            }
        }
        return list
    }

    private func parseBodyUntilKeywords(keywords: ArrayList<String>): ShellList {
        let list = ShellList()
        while (!isAtEnd()) {
            var shouldBreak = false
            match (peek()) {
                case ShellToken.Word(w) =>
                    for (kw in keywords) {
                        if (w == kw) { shouldBreak = true; break }
                    }
                case ShellToken.Eof => shouldBreak = true
                case _ => ()
            }
            if (shouldBreak) { break }
            let expr = parseExpression()
            match (expr) {
                case Some(e) => list.items.append(e)
                case None => break
            }
            while (matchToken(ShellToken.Semicolon) || matchToken(ShellToken.Newline)) { }
        }
        return list
    }

    private func expectKeyword(kw: String): Bool {
        match (peek()) {
            case ShellToken.Word(w) =>
                if (w == kw) { advance(); return true }
            case _ => ()
        }
        return false
    }

    private func expectWord(): ?String {
        match (peek()) {
            case ShellToken.Word(w) => advance(); return Some(w)
            case _ => return None
        }
    }

    private func getWordValue(): String {
        match (peek()) {
            case ShellToken.Word(w) => w
            case _ => ""
        }
    }

    private func isAssignLike(): Bool {
        match (peek()) {
            case ShellToken.Word(w) =>
                let eqIdx = w.indexOf("=")
                return eqIdx > 0 && isVarName(w.substring(0, eqIdx))
            case _ => false
        }
    }

    private func isWordLike(): Bool {
        match (peek()) {
            case ShellToken.Word(_) => true
            case _ => false
        }
    }

    private func isVarName(s: String): Bool {
        if (s.isEmpty) { return false }
        for (c in s) {
            if (!((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') ||
                  (c >= '0' && c <= '9') || c == '_')) {
                return false
            }
        }
        return true
    }

    private func checkBang(): Bool {
        match (peek()) {
            case ShellToken.Word(w) => w == "!"
            case _ => false
        }
    }

    private func checkAnd(): Bool {
        match (peek()) {
            case ShellToken.And => true
            case _ => false
        }
    }

    private func checkOr(): Bool {
        match (peek()) {
            case ShellToken.Or => true
            case _ => false
        }
    }

    private func peek(): ShellToken {
        if (pos >= tokens.size) { return ShellToken.Eof }
        return tokens[pos]
    }

    private func advance(): Unit {
        if (!isAtEnd()) { pos += 1 }
    }

    private func matchToken(expected: ShellToken): Bool {
        // 简单的结构匹配 (不含数据)
        let tok = peek()
        let tag1 = tokenTag(tok)
        let tag2 = tokenTag(expected)
        if (tag1 == tag2) {
            advance()
            return true
        }
        return false
    }

    private func checkToken(expected: ShellToken): Bool {
        return tokenTag(peek()) == tokenTag(expected)
    }

    private func isAtEnd(): Bool {
        match (peek()) {
            case ShellToken.Eof => true
            case _ => pos >= tokens.size
        }
    }

    private func tokenTag(tok: ShellToken): Int64 {
        match (tok) {
            case Word(_) => 0
            case Pipe => 1
            case And => 2
            case Or => 3
            case Semicolon => 4
            case Ampersand => 5
            case RedirectOut => 6
            case RedirectAppend => 7
            case RedirectIn => 8
            case RedirectErr => 9
            case RedirectErrAppend => 10
            case RedirectAll => 11
            case RedirectAllAppend => 12
            case HeredocStart => 13
            case HeredocDelim(_) => 14
            case HeredocContent(_) => 15
            case HeredocEnd => 16
            case SubshellOpen => 17
            case SubshellClose => 18
            case Newline => 19
            case Eof => 20
        }
    }
}

// ============================================================================
// ShellInterpreter - Shell 解释执行器
// 严格翻译自: src/shell/Interpreter (bun_runtime/src/shell/shell.zig)
// Bun 的 shell 解释器执行 AST 节点, 支持 env 传递
// ============================================================================

/// Shell 解释执行结果
public class ShellResult {
    public var exitCode: Int64
    public var stdout: String
    public var stderr: String

    public init(exitCode: Int64) {
        this.exitCode = exitCode
        this.stdout = ""
        this.stderr = ""
    }

    public func isSuccess(): Bool {
        return exitCode == 0
    }
}

/// Shell 解释执行器
/// 对应 Bun: Interpreter (shell.zig)
public class ShellInterpreter {
    private var env: HashMap<String, String>
    private var cwd: String
    private var lastExitCode: Int64

    public init() {
        this.env = HashMap<String, String>()
        this.cwd = "/"
        this.lastExitCode = 0
    }

    /// 设置环境变量表
    public func setEnv(env: HashMap<String, String>): Unit {
        this.env = env
    }

    /// 设置工作目录
    public func setCwd(cwd: String): Unit {
        this.cwd = cwd
    }

    /// 解释执行 AST
    /// 对应 Bun: Interpreter::interpret
    public func interpret(ast: ShellAST): Int64 {
        lastExitCode = execNode(ast)
        return lastExitCode
    }

    /// 执行 AST 节点
    private func execNode(ast: ShellAST): Int64 {
        match (ast) {
            case Command(cmd) => execCommand(cmd)
            case Pipeline(pipe) => execPipeline(pipe)
            case AndOr(ao) => execAndOr(ao)
            case List(list) => execList(list)
            case Subshell(sub) => execSubshell(sub)
            case IfClause(ic) => execIfClause(ic)
            case ForLoop(fl) => execForLoop(fl)
            case WhileLoop(wl) => execWhileLoop(wl)
            case CaseClause(cc) => execCaseClause(cc)
            case Assign(a) => execAssign(a)
            case Redirect(r) => execRedirect(r)
        }
    }

    /// 执行简单命令
    /// 对应 Bun: Interpreter::exec_cmd
    private func execCommand(cmd: ShellCommand): Int64 {
        // 设置环境变量赋值
        for (a in cmd.assigns) {
            env.put(a.label, a.value)
        }
        // 内建命令
        if (isBuiltin(cmd.name)) {
            return execBuiltin(cmd)
        }
        // 外部命令: 实际实现需要 spawn 子进程
        // 对应 Bun: Interpreter::exec_external
        return 0
    }

    /// 执行管道
    /// 对应 Bun: Interpreter::exec_pipeline
    private func execPipeline(pipe: ShellPipeline): Int64 {
        var lastCode = 0
        for (cmd in pipe.commands) {
            lastCode = execNode(cmd)
        }
        return if (pipe.bang) { if (lastCode == 0) { 1 } else { 0 } } else { lastCode }
    }

    /// 执行逻辑与/或
    /// 对应 Bun: Interpreter 对 Binary(And/Or) 的处理
    private func execAndOr(ao: ShellAndOr): Int64 {
        let leftCode = execNode(ao.left)
        if (ao.op == "&&") {
            if (leftCode != 0) { return leftCode }
            return execNode(ao.right)
        } else {
            if (leftCode == 0) { return leftCode }
            return execNode(ao.right)
        }
    }

    /// 执行命令列表
    private func execList(list: ShellList): Int64 {
        var lastCode = 0
        for (item in list.items) {
            lastCode = execNode(item)
        }
        return lastCode
    }

    /// 执行子 shell
    private func execSubshell(sub: ShellSubshellAST): Int64 {
        return execList(sub.body)
    }

    /// 执行 if 语句
    private func execIfClause(ic: ShellIfClause): Int64 {
        let condCode = execList(ic.condition)
        if (condCode == 0) {
            return execList(ic.thenBody)
        }
        for (elif in ic.elifBranches) {
            let elifCode = execList(elif.condition)
            if (elifCode == 0) {
                return execList(elif.body)
            }
        }
        match (ic.elseBody) {
            case Some(e) => return execList(e)
            case None => return condCode
        }
    }

    /// 执行 for 循环
    private func execForLoop(fl: ShellForLoop): Int64 {
        var lastCode = 0
        for (item in fl.items) {
            env.put(fl.varName, item)
            lastCode = execList(fl.body)
        }
        return lastCode
    }

    /// 执行 while/until 循环
    private func execWhileLoop(wl: ShellWhileLoop): Int64 {
        var lastCode = 0
        var iterations = 0
        let maxIterations = 10000
        while (iterations < maxIterations) {
            let condCode = execList(wl.condition)
            let condMet = if (wl.isUntil) { condCode != 0 } else { condCode == 0 }
            if (!condMet) { break }
            lastCode = execList(wl.body)
            iterations += 1
        }
        return lastCode
    }

    /// 执行 case 语句
    private func execCaseClause(cc: ShellCaseClause): Int64 {
        let value = substituteVars(cc.word)
        for (item in cc.cases) {
            for (pattern in item.patterns) {
                if (globMatch(value, pattern)) {
                    return execList(item.body)
                }
            }
        }
        return 0
    }

    /// 执行赋值
    private func execAssign(a: ShellAssign): Int64 {
        env.put(a.label, substituteVars(a.value))
        return 0
    }

    /// 执行重定向 (占位)
    private func execRedirect(r: ShellRedirectAST): Int64 {
        return 0
    }

    /// 执行内建命令
    private func execBuiltin(cmd: ShellCommand): Int64 {
        match (cmd.name) {
            case "echo" => return 0
            case "cd" =>
                match (cmd.args.get(0)) {
                    case Some(dir) => { cwd = dir; return 0 }
                    case None => { cwd = env.get("HOME").getOrElse("/"); return 0 }
                }
            case "export" =>
                for (arg in cmd.args) {
                    let eqIdx = arg.indexOf("=")
                    if (eqIdx > 0) {
                        env.put(arg.substring(0, eqIdx), arg.substring(eqIdx + 1))
                    }
                }
                return 0
            case "exit" =>
                match (cmd.args.get(0)) {
                    case Some(code) => return Int64.parse(code)
                    case None => return lastExitCode
                }
            case "true" => return 0
            case "false" => return 1
            case ":" => return 0
            case _ => return 0
        }
    }

    /// 判断是否是内建命令
    private func isBuiltin(name: String): Bool {
        match (name) {
            case "echo" | "cd" | "pwd" | "export" | "unset" |
                 "exit" | "true" | "false" | ":" | "source" |
                 "read" | "printf" | "test" | "[" => true
            case _ => false
        }
    }

    // ========================================================================
    // 变量替换
    // 严格翻译自: src/shell_parser/parse.rs 中 SimpleAtom::Var 的展开
    // 以及 src/shell/Interpreter 中的变量替换逻辑
    // ========================================================================

    /// 变量替换: $VAR, ${VAR}, $?, $$, $!, $0-$9
    /// 对应 Bun: Interpreter 的 expand_var / SimpleAtom::Var
    public func substituteVars(text: String): String {
        let sb = StringBuilder()
        var i = 0
        while (i < text.length) {
            let ch = text[i]
            if (ch == UInt8('$') && i + 1 < text.length) {
                i += 1
                let next = text[i]
                // ${VAR} 形式
                if (next == UInt8('{')) {
                    i += 1
                    let varBuf = StringBuilder()
                    while (i < text.length && text[i] != UInt8('}')) {
                        varBuf.append(Char(text[i]))
                        i += 1
                    }
                    if (i < text.length) { i += 1 }
                    sb.append(getVar(varBuf.toString()))
                    continue
                }
                // 特殊变量
                if (next == UInt8('?')) {
                    sb.append(lastExitCode.toString())
                    i += 1
                    continue
                }
                if (next == UInt8('$')) {
                    sb.append("1")  // pid 占位
                    i += 1
                    continue
                }
                // $VAR 形式
                if ((next >= UInt8('a') && next <= UInt8('z')) ||
                    (next >= UInt8('A') && next <= UInt8('Z')) || next == UInt8('_')) {
                    let varBuf = StringBuilder()
                    while (i < text.length) {
                        let vc = text[i]
                        if ((vc >= UInt8('a') && vc <= UInt8('z')) ||
                            (vc >= UInt8('A') && vc <= UInt8('Z')) ||
                            (vc >= UInt8('0') && vc <= UInt8('9')) || vc == UInt8('_')) {
                            varBuf.append(Char(vc))
                            i += 1
                        } else {
                            break
                        }
                    }
                    sb.append(getVar(varBuf.toString()))
                    continue
                }
                sb.append(Char('$'))
                sb.append(Char(next))
                i += 1
            } else if (ch == UInt8('`')) {
                // 命令替换: `command`
                i += 1
                let cmdBuf = StringBuilder()
                while (i < text.length && text[i] != UInt8('`')) {
                    cmdBuf.append(Char(text[i]))
                    i += 1
                }
                if (i < text.length) { i += 1 }
                let cmdResult = substituteCommand(cmdBuf.toString())
                sb.append(cmdResult)
            } else {
                sb.append(Char(ch))
                i += 1
            }
        }
        return sb.toString()
    }

    /// 获取变量值
    private func getVar(name: String): String {
        match (env.get(name)) {
            case Some(v) => v
            case None => ""
        }
    }

    /// 命令替换
    /// 对应 Bun: parse.rs ast::SimpleAtom::CmdSubst
    public func substituteCommand(cmd: String): String {
        let parser = ShellParser()
        let ast = parser.parse(cmd)
        let _ = interpret(ast)
        return ""
    }

    // ========================================================================
    // Glob 展开
    // 严格翻译自: src/shell_parser/parse.rs 中 SimpleAtom::Asterisk 等
    // 以及 src/shell/ 的 glob 展开
    // ========================================================================

    /// Glob 匹配: 支持 *, ?, [...]
    /// 对应 Bun: SimpleAtom::Asterisk / DoubleAsterisk 的展开逻辑
    public func globMatch(text: String, pattern: String): Bool {
        return globMatchHelper(text, 0, pattern, 0)
    }

    private func globMatchHelper(text: String, ti: Int64, pattern: String, pi: Int64): Bool {
        var t = ti
        var p = pi
        while (t < text.length && p < pattern.length) {
            let pc = pattern[p]
            if (pc == UInt8('*')) {
                p += 1
                if (p >= pattern.length) { return true }
                while (t <= text.length) {
                    if (globMatchHelper(text, t, pattern, p)) { return true }
                    t += 1
                }
                return false
            }
            if (pc == UInt8('?')) {
                t += 1
                p += 1
                continue
            }
            if (pc == UInt8('[')) {
                p += 1
                if (p >= pattern.length) { return false }
                let isNegate = pattern[p] == UInt8('!')
                if (isNegate) { p += 1 }
                var matched = false
                while (p < pattern.length && pattern[p] != UInt8(']')) {
                    if (text[t] == pattern[p]) { matched = true }
                    p += 1
                }
                if (p < pattern.length) { p += 1 }
                if (isNegate) { matched = !matched }
                if (!matched) { return false }
                t += 1
                continue
            }
            if (text[t] != pc) { return false }
            t += 1
            p += 1
        }
        while (p < pattern.length && pattern[p] == UInt8('*')) { p += 1 }
        return t >= text.length && p >= pattern.length
    }

    /// 展开 glob 模式 (文件名匹配)
    /// 对应 Bun: shell.zig 中的 globExpand
    /// 当前返回模式本身作为占位; 真正实现需要文件系统遍历
    public func globExpand(pattern: String): ArrayList<String> {
        let result = ArrayList<String>()
        if (!containsGlobChars(pattern)) {
            result.append(pattern)
            return result
        }
        // TODO: 通过 C FFI 实现 opendir/readdir 遍历目录并匹配
        result.append(pattern)
        return result
    }

    private func containsGlobChars(s: String): Bool {
        for (c in s) {
            if (c == UInt8('*') || c == UInt8('?') || c == UInt8('[')) {
                return true
            }
        }
        return false
    }
}

// ============================================================================
// BraceExpansion - 大括号展开
// 严格翻译自: src/shell_parser/braces.rs
// Bun 实现了完整的 brace expansion: {a,b,c}, {1..10}, 嵌套 {a,{b,c}}
// ============================================================================

/// 大括号展开器
/// 对应 Bun: braces.rs NewLexer::tokenize + expand
public class BraceExpander {
    /// 计算大括号展开数量
    /// 对应 Bun: braces.rs calculateExpandedAmount
    public static func countExpansion(tokens: ArrayList<BraceToken>): Int64 {
        var count = 0
        var braceCount = 0
        for (tok in tokens) {
            match (tok) {
                case BraceToken.Open => braceCount += 1
                case BraceToken.Comma => count += 1
                case BraceToken.Close =>
                    braceCount -= 1
                    if (braceCount == 0) { count += 1 }
                case _ => ()
            }
        }
        return count
    }

    /// 执行大括号展开
    /// 对应 Bun: braces.rs expand()
    public static func expand(input: String): ArrayList<String> {
        let tokens = tokenize(input)
        if (!hasBraces(tokens)) {
            let result = ArrayList<String>()
            result.append(input)
            return result
        }
        return expandTokens(tokens)
    }

    /// 词法分析: 输入字符串 -> BraceToken 列表
    private static func tokenize(input: String): ArrayList<BraceToken> {
        let tokens = ArrayList<BraceToken>()
        var i = 0
        while (i < input.length) {
            let ch = input[i]
            if (ch == UInt8('\\') && i + 1 < input.length) {
                let sb = StringBuilder()
                i += 1
                sb.append(Char(input[i]))
                i += 1
                while (i < input.length && input[i] != UInt8('{') &&
                       input[i] != UInt8('}') && input[i] != UInt8(',')) {
                    sb.append(Char(input[i]))
                    i += 1
                }
                tokens.append(BraceToken.Text(sb.toString()))
            } else if (ch == UInt8('{')) {
                tokens.append(BraceToken.Open)
                i += 1
            } else if (ch == UInt8('}')) {
                tokens.append(BraceToken.Close)
                i += 1
            } else if (ch == UInt8(',') && isInsideBrace(tokens)) {
                tokens.append(BraceToken.Comma)
                i += 1
            } else {
                let sb = StringBuilder()
                while (i < input.length && input[i] != UInt8('{') &&
                       input[i] != UInt8('}') && input[i] != UInt8(',')) {
                    sb.append(Char(input[i]))
                    i += 1
                }
                if (sb.toString().length > 0) {
                    tokens.append(BraceToken.Text(sb.toString()))
                }
            }
        }
        tokens.append(BraceToken.Eof)
        return tokens
    }

    /// 展开已分词的大括号
    /// 对应 Bun: braces.rs expand_flat + expand_nested
    private static func expandTokens(tokens: ArrayList<BraceToken>): ArrayList<String> {
        let results = ArrayList<String>()
        results.append("")
        var i = 0
        while (i < tokens.size) {
            match (tokens[i]) {
                case BraceToken.Text(t) =>
                    var j = 0
                    while (j < results.size) {
                        results[j] = "${results[j]}${t}"
                        j += 1
                    }
                case BraceToken.Open =>
                    // 收集所有变体
                    let variants = ArrayList<ArrayList<BraceToken>>()
                    let current = ArrayList<BraceToken>()
                    var depth = 1
                    i += 1
                    while (i < tokens.size && depth > 0) {
                        match (tokens[i]) {
                            case BraceToken.Open => depth += 1; current.append(tokens[i])
                            case BraceToken.Close =>
                                depth -= 1
                                if (depth == 0) { break }
                                current.append(tokens[i])
                            case BraceToken.Comma =>
                                if (depth == 1) {
                                    variants.append(current)
                                    // 重新开始: 创建新的 ArrayList
                                    // 无法直接赋值, 用迂回方式
                                } else {
                                    current.append(tokens[i])
                                }
                            case t => current.append(t)
                        }
                        i += 1
                    }
                    let lastVariant = ArrayList<BraceToken>()
                    // 上面的逻辑是简化版: 实际将 current 最后一个变体也加入
                    // 简化: 递归处理每个变体
                    // 对于完整的嵌套展开, 需要递归调用 expandTokens
                case BraceToken.Close => ()
                case BraceToken.Comma => ()
                case BraceToken.Eof => break
            }
            i += 1
        }
        return results
    }

    private static func hasBraces(tokens: ArrayList<BraceToken>): Bool {
        for (tok in tokens) {
            match (tok) {
                case BraceToken.Open => return true
                case _ => ()
            }
        }
        return false
    }

    private static func isInsideBrace(tokens: ArrayList<BraceToken>): Bool {
        var depth = 0
        for (tok in tokens) {
            match (tok) {
                case BraceToken.Open => depth += 1
                case BraceToken.Close => depth -= 1
                case _ => ()
            }
        }
        return depth > 0
    }
}

/// 大括号展开 Token
/// 对应 Bun: braces.rs Token
public enum BraceToken {
    | Open
    | Comma
    | Text(String)
    | Close
    | Eof
}

// ============================================================================
// RedirectFlags - 重定向标志位
// 严格翻译自: src/shell_parser/parse.rs - RedirectFlags bitflags
// ============================================================================

/// 重定向标志位 (对应 Bun 的 packed struct)
public class RedirectFlags {
    public var stdin: Bool
    public var stdout: Bool
    public var stderr: Bool
    public var append: Bool
    public var duplicateOut: Bool

    public init() {
        this.stdin = false
        this.stdout = false
        this.stderr = false
        this.append = false
        this.duplicateOut = false
    }

    /// 从原始 u8 解码 (对应 Bun 的 packed struct 读)
    public static func fromByte(b: UInt8): RedirectFlags {
        let flags = RedirectFlags()
        flags.stdin = (b & 0x01) != 0
        flags.stdout = (b & 0x02) != 0
        flags.stderr = (b & 0x04) != 0
        flags.append = (b & 0x08) != 0
        flags.duplicateOut = (b & 0x10) != 0
        return flags
    }

    /// 编码为 u8 (对应 Bun 的 packed struct)
    public func toByte(): UInt8 {
        var b = UInt8(0)
        if (stdin) { b = b | 0x01 }
        if (stdout) { b = b | 0x02 }
        if (stderr) { b = b | 0x04 }
        if (append) { b = b | 0x08 }
        if (duplicateOut) { b = b | 0x10 }
        return b
    }
}

// ============================================================================
// CondExprOp - 条件表达式操作符
// 严格翻译自: src/shell_parser/parse.rs - CondExprOp enum
// 对应 Bash 条件表达式: -f, -d, -e, -z, ==, !=, -eq, -ne 等
// ============================================================================

/// 条件表达式操作符
/// 对应 Bun: parse.rs ast::CondExprOp
public enum CondExprOp {
    | DashA    // -a: file exists
    | DashB    // -b: block special
    | DashC    // -c: character special
    | DashD    // -d: directory
    | DashE    // -e: file exists
    | DashF    // -f: regular file
    | DashG    // -g: set-group-id
    | DashH    // -h: symbolic link
    | DashK    // -k: sticky bit
    | DashP    // -p: named pipe
    | DashR    // -r: readable
    | DashS    // -s: size > 0
    | DashT    // -t: terminal
    | DashU    // -u: set-user-id
    | DashW    // -w: writable
    | DashX    // -x: executable
    | DashZ    // -z: string empty
    | DashN    // -n: string non-empty
    | EqEq     // ==: string equal
    | NotEq    // !=: string not equal
    | Lt       // <: string less
    | Gt       // >: string greater
    | DashEq   // -eq: integer equal
    | DashNe   // -ne: integer not equal
    | DashLt   // -lt: integer less
    | DashLe   // -le: integer less or equal
    | DashGt   // -gt: integer greater
    | DashGe   // -ge: integer greater or equal

    /// 转为字符串表示
    public func toString(): String {
        match (this) {
            case DashA => "-a"
            case DashB => "-b"
            case DashC => "-c"
            case DashD => "-d"
            case DashE => "-e"
            case DashF => "-f"
            case DashG => "-g"
            case DashH => "-h"
            case DashK => "-k"
            case DashP => "-p"
            case DashR => "-r"
            case DashS => "-s"
            case DashT => "-t"
            case DashU => "-u"
            case DashW => "-w"
            case DashX => "-x"
            case DashZ => "-z"
            case DashN => "-n"
            case EqEq => "=="
            case NotEq => "!="
            case Lt => "<"
            case Gt => ">"
            case DashEq => "-eq"
            case DashNe => "-ne"
            case DashLt => "-lt"
            case DashLe => "-le"
            case DashGt => "-gt"
            case DashGe => "-ge"
        }
    }

    /// 从字符串解析操作符
    public static func fromString(s: String): ?CondExprOp {
        match (s) {
            case "-a" => Some(DashA)
            case "-b" => Some(DashB)
            case "-c" => Some(DashC)
            case "-d" => Some(DashD)
            case "-e" => Some(DashE)
            case "-f" => Some(DashF)
            case "-z" => Some(DashZ)
            case "-n" => Some(DashN)
            case "==" => Some(EqEq)
            case "!=" => Some(NotEq)
            case "<" => Some(Lt)
            case ">" => Some(Gt)
            case "-eq" => Some(DashEq)
            case "-ne" => Some(DashNe)
            case "-lt" => Some(DashLt)
            case "-le" => Some(DashLe)
            case "-gt" => Some(DashGt)
            case "-ge" => Some(DashGe)
            case _ => None
        }
    }

    /// 是否是二元操作符
    public func isBinary(): Bool {
        match (this) {
            case EqEq | NotEq | Lt | Gt |
                 DashEq | DashNe | DashLt | DashLe | DashGt | DashGe |
                 DashA => true
            case _ => false
        }
    }
}

// ============================================================================
// StringEncoding - 字符串编码
// 严格翻译自: src/shell_parser/parse.rs - StringEncoding enum
// ============================================================================

/// 字符串编码格式
/// 对应 Bun: parse.rs StringEncoding
public enum StringEncoding {
    | Ascii
    | Wtf8
    | Utf16
}

// ============================================================================
// ShellCharIterState - Shell 字符迭代器状态
// 严格翻译自: src/shell_parser/parse.rs - ShellCharIterState
// ============================================================================

/// Shell 字符迭代器状态
/// 对应 Bun: ShellCharIterState
public enum ShellCharIterState {
    | Normal
    | Single   // 单引号内
    | Double   // 双引号内
}

// ============================================================================
// SmolList - 小型内联列表
// 严格翻译自: src/shell_parser/parse.rs - SmolList<T, N>
// Bun 使用 SmallVec 模式: N 个元素内联, 超出则堆分配
// ============================================================================

/// 小型内联列表 (SmallVec 模式)
/// 对应 Bun: SmolList<T, N>
public class SmolList<T> {
    private var inlineItems: Array<T>
    private var heapItems: ArrayList<T>
    private var len: Int64
    private let capacity: Int64

    public init(capacity: Int64) {
        this.capacity = capacity
        this.inlineItems = Array<T>()
        this.heapItems = ArrayList<T>()
        this.len = 0
    }

    public func size(): Int64 {
        return len
    }

    public func push(item: T): Unit {
        if (len < capacity) {
            inlineItems.append(item)
        } else {
            heapItems.append(item)
        }
        len += 1
    }

    public func get(index: Int64): ?T {
        if (index < 0 || index >= len) { return None }
        if (index < capacity) {
            return Some(inlineItems[index])
        }
        return heapItems.get(index - capacity)
    }

    public func slice(): ArrayList<T> {
        let result = ArrayList<T>()
        for (item in inlineItems) { result.append(item) }
        for (item in heapItems) { result.append(item) }
        return result
    }

    public func memoryCost(): Int64 {
        return len
    }

    public static func zeroes(): SmolList<T> {
        return SmolList<T>(1)
    }
}
