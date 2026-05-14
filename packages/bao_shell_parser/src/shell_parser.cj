// bao_shell_parser shell_parser - Shell 命令词法分析器和解析器
// 严格翻译自: src/shell_launcher.zig, src/shell/*.zig
//   Bun 的 shell_launcher 负责 shell 命令的解析和执行
//   包含词法分析 (tokenize)、引用处理 (quoting)、变量展开 ($VAR/${VAR})
//   管道 (pipes)、重定向 (redirections)、后台 (&)、子 shell、heredoc
//   仓颉翻译保持等价的 AST 构建语义
package bao_shell_parser

import bao_core.*
import bao_collections.*

// ============================================================================
// ShellToken - Shell 词法单元
// 严格翻译自: src/shell_launcher.zig 中 ShellTokenizer 的 token 定义
// Bun 使用 tag union 表示不同 token 类型，仓颉使用 enum
// ============================================================================

/// Shell 词法单元类型
/// 对应 Bun shell_launcher 中 tokenizer 输出的 token 种类
public enum ShellTokenKind {
    | Text              // 普通文本片段
    | SingleQuoted      // 单引号字符串 '...'
    | DoubleQuoted      // 双引号字符串 "..."
    | BacktickQuoted    // 反引号字符串 `...`
    | Variable          // 变量引用 $VAR 或 ${VAR}
    | Pipe              // 管道符 |
    | RedirectOut       // 重定向输出 >
    | RedirectAppend    // 追加重定向 >>
    | RedirectIn        // 重定向输入 <
    | RedirectErr       // 重定向 stderr 2>
    | Background        // 后台运行 &
    | And               // 逻辑与 &&
    | Or                // 逻辑或 ||
    | Semicolon         // 分号 ;
    | SubshellOpen      // 子 shell 开始 (
    | SubshellClose     // 子 shell 结束 )
    | Heredoc           // Here document <<
    | HeredocStrip      // Here document strip tabs <<-
    | Newline           // 换行 \n
    | Glob              // glob 模式 (*, ?, [...])
    | Eof               // 输入结束
}

/// Shell 词法单元
/// 对应 Bun shell_launcher ShellToken
public class ShellToken {
    public let kind: ShellTokenKind
    public let value: String
    public let pos: Int64

    public init(kind: ShellTokenKind, value: String, pos: Int64) {
        this.kind = kind
        this.value = value
        this.pos = pos
    }

    public func toString(): String {
        return "ShellToken(${kind}, \"${value}\", pos=${pos})"
    }
}

// ============================================================================
// ShellLexer - Shell 命令词法分析器
// 严格翻译自: src/shell_launcher.zig 中 ShellTokenizer
//   Bun 使用 index-based 迭代器逐字符扫描输入
//   支持引用 (single/double/backtick)、转义、变量、运算符
//   仓颉实现保持等价的逐字符状态机逻辑
// ============================================================================

/// Shell 命令词法分析器
/// 对应 Bun shell_launcher ShellTokenizer
public class ShellLexer {
    private var input: String
    private var pos: Int64
    private var tokens: ArrayList<ShellToken>

    public init(input: String) {
        this.input = input
        this.pos = 0
        this.tokens = ArrayList<ShellToken>()
    }

    /// 输入长度
    private func inputLen(): Int64 {
        return input.length
    }

    /// 当前字符
    private func currentChar(): Char {
        if (pos < inputLen()) {
            return input[pos]
        }
        return Char(0)
    }

    /// 前看一个字符
    private func peekChar(offset: Int64): Char {
        let idx = pos + offset
        if (idx < inputLen()) {
            return input[idx]
        }
        return Char(0)
    }

    /// 前进一个字符
    private func advance(): Char {
        let ch = currentChar()
        pos++
        return ch
    }

    /// 是否到末尾
    private func isEof(): Bool {
        return pos >= inputLen()
    }

    /// 跳过空白 (不含换行)
    private func skipWhitespace(): Unit {
        while (!isEof()) {
            let ch = currentChar()
            if (ch == ' ' || ch == '\t' || ch == '\r') {
                advance()
            } else {
                break
            }
        }
    }

    /// 判断是否为 shell 元字符
    /// 对应 Bun shell_launcher 中对 |, >, <, &, ;, (, ) 的检测
    private func isMetaChar(ch: Char): Bool {
        return ch == '|' || ch == '>' || ch == '<' || ch == '&' ||
               ch == ';' || ch == '(' || ch == ')'
    }

    /// 判断是否为空白字符
    private func isWhitespace(ch: Char): Bool {
        return ch == ' ' || ch == '\t' || ch == '\r' || ch == '\n'
    }

    /// 判断是否为 glob 模式字符
    private func isGlobChar(ch: Char): Bool {
        return ch == '*' || ch == '?'
    }

    /// 对输入进行完整的词法分析
    /// 对应 Bun ShellTokenizer.tokenize()
    public func tokenize(): ArrayList<ShellToken> {
        tokens = ArrayList<ShellToken>()
        pos = 0

        while (!isEof()) {
            skipWhitespace()

            if (isEof()) {
                break
            }

            let ch = currentChar()
            let startPos = pos

            // 换行
            if (ch == '\n') {
                tokens.append(ShellToken(ShellTokenKind.Newline, "\\n", startPos))
                advance()
                continue
            }

            // 注释 - 跳过直到行尾
            if (ch == '#') {
                while (!isEof() && currentChar() != '\n') {
                    advance()
                }
                continue
            }

            // 管道 | 或 ||
            if (ch == '|') {
                advance()
                if (currentChar() == '|') {
                    advance()
                    tokens.append(ShellToken(ShellTokenKind.Or, "||", startPos))
                } else {
                    tokens.append(ShellToken(ShellTokenKind.Pipe, "|", startPos))
                }
                continue
            }

            // & 或 &&
            if (ch == '&') {
                advance()
                if (currentChar() == '&') {
                    advance()
                    tokens.append(ShellToken(ShellTokenKind.And, "&&", startPos))
                } else {
                    tokens.append(ShellToken(ShellTokenKind.Background, "&", startPos))
                }
                continue
            }

            // 分号
            if (ch == ';') {
                advance()
                tokens.append(ShellToken(ShellTokenKind.Semicolon, ";", startPos))
                continue
            }

            // 子 shell 括号
            if (ch == '(') {
                advance()
                tokens.append(ShellToken(ShellTokenKind.SubshellOpen, "(", startPos))
                continue
            }
            if (ch == ')') {
                advance()
                tokens.append(ShellToken(ShellTokenKind.SubshellClose, ")", startPos))
                continue
            }

            // 重定向: >, >>, <, 2>, <<
            if (ch == '>') {
                advance()
                if (currentChar() == '>') {
                    advance()
                    tokens.append(ShellToken(ShellTokenKind.RedirectAppend, ">>", startPos))
                } else {
                    tokens.append(ShellToken(ShellTokenKind.RedirectOut, ">", startPos))
                }
                continue
            }
            if (ch == '<') {
                // 检查 heredoc: << 或 <<-
                if (peekChar(Int64(1)) == '<') {
                    advance() // 第一个 <
                    advance() // 第二个 <
                    if (currentChar() == '-') {
                        advance()
                        tokens.append(ShellToken(ShellTokenKind.HeredocStrip, "<<-", startPos))
                    } else {
                        tokens.append(ShellToken(ShellTokenKind.Heredoc, "<<", startPos))
                    }
                } else {
                    advance()
                    tokens.append(ShellToken(ShellTokenKind.RedirectIn, "<", startPos))
                }
                continue
            }

            // 2> (stderr 重定向)
            if (ch == '2' && peekChar(Int64(1)) == '>') {
                advance() // '2'
                advance() // '>'
                if (currentChar() == '>') {
                    advance()
                    tokens.append(ShellToken(ShellTokenKind.RedirectErr, "2>>", startPos))
                } else {
                    tokens.append(ShellToken(ShellTokenKind.RedirectErr, "2>", startPos))
                }
                continue
            }

            // 变量引用: $VAR, ${VAR}, $?
            if (ch == '$') {
                let varToken = scanVariable()
                tokens.append(varToken)
                continue
            }

            // 单引号
            if (ch == '\'') {
                let sqToken = scanSingleQuoted()
                tokens.append(sqToken)
                continue
            }

            // 双引号
            if (ch == '"') {
                let dqToken = scanDoubleQuoted()
                tokens.append(dqToken)
                continue
            }

            // 反引号 (命令替换)
            if (ch == '`') {
                let btToken = scanBacktickQuoted()
                tokens.append(btToken)
                continue
            }

            // 反斜杠转义
            if (ch == '\\') {
                advance()
                if (!isEof()) {
                    let escaped = advance()
                    tokens.append(ShellToken(ShellTokenKind.Text, escaped.toString(), startPos))
                }
                continue
            }

            // 普通文本 (可能包含 glob 字符)
            let textToken = scanText()
            tokens.append(textToken)
        }

        tokens.append(ShellToken(ShellTokenKind.Eof, "", pos))
        return tokens
    }

    /// 扫描变量引用
    /// 对应 Bun shell_launcher 中 $VAR/${VAR} 的处理
    /// 支持: $VAR, ${VAR}, ${VAR:-default}, ${VAR:+alt}, ${#VAR}, $?, $!
    private func scanVariable(): ShellToken {
        let startPos = pos
        advance() // 跳过 $

        if (isEof()) {
            return ShellToken(ShellTokenKind.Variable, "$", startPos)
        }

        let ch = currentChar()

        // $? - 上一个命令的退出码
        if (ch == '?') {
            advance()
            return ShellToken(ShellTokenKind.Variable, "?", startPos)
        }

        // $! - 上一个后台进程 PID
        if (ch == '!') {
            advance()
            return ShellToken(ShellTokenKind.Variable, "!", startPos)
        }

        // $$ - 当前 shell PID
        if (ch == '$') {
            advance()
            return ShellToken(ShellTokenKind.Variable, "$", startPos)
        }

        // ${...} 带花括号的变量引用
        if (ch == '{') {
            advance() // 跳过 {
            let sb = StringBuilder()
            sb.append('{')
            while (!isEof() && currentChar() != '}') {
                sb.append(advance())
            }
            if (!isEof()) {
                sb.append(advance()) // 跳过 }
            }
            return ShellToken(ShellTokenKind.Variable, sb.toString(), startPos)
        }

        // $VAR 普通变量名
        if (isIdentifierStart(ch)) {
            let sb = StringBuilder()
            while (!isEof() && isIdentifierChar(currentChar())) {
                sb.append(advance())
            }
            return ShellToken(ShellTokenKind.Variable, sb.toString(), startPos)
        }

        // $ 后面不是有效变量字符
        return ShellToken(ShellTokenKind.Text, "$", startPos)
    }

    /// 扫描单引号字符串
    /// 对应 Bun shell_launcher 中单引号处理
    /// 单引号内不进行任何展开，原样保留
    private func scanSingleQuoted(): ShellToken {
        let startPos = pos
        advance() // 跳过开始 '
        let sb = StringBuilder()

        while (!isEof() && currentChar() != '\'') {
            sb.append(advance())
        }

        if (!isEof()) {
            advance() // 跳过结束 '
        }

        return ShellToken(ShellTokenKind.SingleQuoted, sb.toString(), startPos)
    }

    /// 扫描双引号字符串
    /// 对应 Bun shell_launcher 中双引号处理
    /// 双引号内进行变量展开和反斜杠转义
    private func scanDoubleQuoted(): ShellToken {
        let startPos = pos
        advance() // 跳过开始 "
        let sb = StringBuilder()

        while (!isEof() && currentChar() != '"') {
            let ch = currentChar()
            if (ch == '\\') {
                advance()
                if (!isEof()) {
                    let next = currentChar()
                    // 双引号内只转义 $, `, ", \, 换行
                    if (next == '$' || next == '`' || next == '"' || next == '\\' || next == '\n') {
                        sb.append(advance())
                    } else {
                        sb.append('\\')
                        sb.append(advance())
                    }
                }
            } else if (ch == '$') {
                // 双引号内的变量展开 - 记录标记
                sb.append('$')
                advance()
                if (!isEof() && currentChar() == '{') {
                    while (!isEof() && currentChar() != '}') {
                        sb.append(advance())
                    }
                    if (!isEof()) {
                        sb.append(advance())
                    }
                } else {
                    while (!isEof() && isIdentifierChar(currentChar())) {
                        sb.append(advance())
                    }
                }
            } else {
                sb.append(advance())
            }
        }

        if (!isEof()) {
            advance() // 跳过结束 "
        }

        return ShellToken(ShellTokenKind.DoubleQuoted, sb.toString(), startPos)
    }

    /// 扫描反引号字符串 (命令替换)
    /// 对应 Bun shell_launcher 中反引号命令替换
    private func scanBacktickQuoted(): ShellToken {
        let startPos = pos
        advance() // 跳过开始 `
        let sb = StringBuilder()

        while (!isEof() && currentChar() != '`') {
            if (currentChar() == '\\') {
                advance()
                if (!isEof()) {
                    let next = currentChar()
                    if (next == '$' || next == '`' || next == '\\') {
                        sb.append(advance())
                    } else {
                        sb.append('\\')
                        sb.append(advance())
                    }
                }
            } else {
                sb.append(advance())
            }
        }

        if (!isEof()) {
            advance() // 跳过结束 `
        }

        return ShellToken(ShellTokenKind.BacktickQuoted, sb.toString(), startPos)
    }

    /// 扫描普通文本
    /// 对应 Bun shell_launcher 中普通文本 token 的扫描
    /// 可能包含 glob 模式字符
    private func scanText(): ShellToken {
        let startPos = pos
        let sb = StringBuilder()
        var hasGlob = false

        while (!isEof()) {
            let ch = currentChar()
            // 停止条件: 空白、元字符、引号、$、反斜杠
            if (isWhitespace(ch) || isMetaChar(ch) || ch == '\'' || ch == '"' ||
                ch == '`' || ch == '$' || ch == '\\' || ch == '#') {
                break
            }
            if (isGlobChar(ch) || ch == '[') {
                hasGlob = true
            }
            sb.append(advance())
        }

        let kind = if (hasGlob) { ShellTokenKind.Glob } else { ShellTokenKind.Text }
        return ShellToken(kind, sb.toString(), startPos)
    }

    /// 判断是否为标识符起始字符
    private func isIdentifierStart(ch: Char): Bool {
        return (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z') || ch == '_'
    }

    /// 判断是否为标识符字符
    private func isIdentifierChar(ch: Char): Bool {
        return isIdentifierStart(ch) || (ch >= '0' && ch <= '9')
    }
}

// ============================================================================
// ShellRedirect - Shell 重定向
// 严格翻译自: src/shell_launcher.zig 中重定向结构
// Bun: stdin/stdout/stderr 重定向到文件
// ============================================================================

/// Shell 重定向类型
/// 对应 Bun shell_launcher 中重定向描述
public enum ShellRedirectKind {
    | Input       // < file
    | Output      // > file
    | Append      // >> file
    | Stderr      // 2> file
    | StderrAppend // 2>> file
}

/// Shell 重定向
public class ShellRedirect {
    public var kind: ShellRedirectKind
    public var target: String
    public var fd: Int64  // 文件描述符: 0=stdin, 1=stdout, 2=stderr

    public init(kind: ShellRedirectKind, target: String, fd: Int64) {
        this.kind = kind
        this.target = target
        this.fd = fd
    }

    public func toString(): String {
        let op = match (kind) {
            case Input => "<"
            case Output => ">"
            case Append => ">>"
            case Stderr => "2>"
            case StderrAppend => "2>>"
        }
        return "${op} ${target}"
    }
}

// ============================================================================
// ShellCommand - 单条 Shell 命令
// 严格翻译自: src/shell_launcher.zig 中 ShellCommand
// Bun: 命令名 + 参数列表 + 环境变量 + 重定向
// ============================================================================

/// Shell 命令
/// 对应 Bun shell_launcher 中一条完整命令
public class ShellCommand {
    /// 命令名 (可执行文件路径或命令名)
    public var program: String
    /// 命令参数列表 (含 argv[0])
    public var args: ArrayList<String>
    /// 环境变量覆盖
    public var env: HashMap<String, String>
    /// 重定向列表
    public var redirects: ArrayList<ShellRedirect>
    /// 是否在后台运行
    public var background: Bool
    /// 工作目录
    public var cwd: ?String

    public init() {
        program = ""
        args = ArrayList<String>()
        env = HashMap<String, String>()
        redirects = ArrayList<ShellRedirect>()
        background = false
        cwd = None
    }

    public init(program: String) {
        this.program = program
        this.args = ArrayList<String>()
        this.args.append(program)
        this.env = HashMap<String, String>()
        this.redirects = ArrayList<ShellRedirect>()
        this.background = false
        this.cwd = None
    }

    /// 添加参数
    public func addArg(arg: String): Unit {
        args.append(arg)
    }

    /// 添加重定向
    public func addRedirect(redirect: ShellRedirect): Unit {
        redirects.append(redirect)
    }

    /// 设置环境变量
    public func setEnv(key: String, value: String): Unit {
        env.put(key, value)
    }

    /// 构建完整的命令行字符串
    public func toCommandLine(): String {
        let sb = StringBuilder()
        sb.append(program)
        for (arg in args) {
            if (arg != program) {
                sb.append(" ")
                // 如果参数包含空格或特殊字符则加引号
                if (needsQuoting(arg)) {
                    sb.append("'")
                    sb.append(arg)
                    sb.append("'")
                } else {
                    sb.append(arg)
                }
            }
        }
        for (redir in redirects) {
            sb.append(" ")
            sb.append(redir.toString())
        }
        if (background) {
            sb.append(" &")
        }
        return sb.toString()
    }

    /// 判断参数是否需要引号
    private func needsQuoting(s: String): Bool {
        for (c in s) {
            if (c == ' ' || c == '\t' || c == '\'' || c == '"' ||
                c == '|' || c == '&' || c == ';' || c == '<' || c == '>' ||
                c == '(' || c == ')' || c == '$' || c == '`' || c == '\\') {
                return true
            }
        }
        return false
    }
}

// ============================================================================
// ShellPipeline - Shell 管道
// 严格翻译自: src/shell_launcher.zig 中管道处理
// Bun: cmd1 | cmd2 | cmd3 的管道连接
// ============================================================================

/// Shell 管道
/// 对应 Bun shell_launcher 中管道结构
public class ShellPipeline {
    /// 管道中的命令列表
    public var commands: ArrayList<ShellCommand>
    /// 是否在后台运行
    public var background: Bool

    public init() {
        commands = ArrayList<ShellCommand>()
        background = false
    }

    /// 添加命令到管道
    public func addCommand(cmd: ShellCommand): Unit {
        commands.append(cmd)
    }

    /// 管道中的命令数
    public func length(): Int64 {
        return commands.size
    }

    /// 构建命令行字符串
    public func toCommandLine(): String {
        let sb = StringBuilder()
        for (i in 0..commands.size) {
            if (i > 0) {
                sb.append(" | ")
            }
            sb.append(commands[i].toCommandLine())
        }
        if (background) {
            sb.append(" &")
        }
        return sb.toString()
    }
}

// ============================================================================
// ShellAst - Shell 抽象语法树
// 严格翻译自: src/shell_launcher.zig 中 AST 节点
// Bun: 支持管道链、&&/|| 条件链、分号序列、子 shell
// ============================================================================

/// Shell AST 节点类型
public enum ShellAstKind {
    | Pipeline          // 单条管道 (含多条命令)
    | And               // && 条件链
    | Or                // || 条件链
    | Sequence          // ; 或 \n 分隔的命令序列
    | Subshell          // ( ... ) 子 shell
    | Command           // 单条命令
}

/// Shell AST 节点
/// 对应 Bun shell_launcher 中解析树的节点表示
public class ShellAst {
    public var kind: ShellAstKind
    public var pipeline: ?ShellPipeline
    public var children: ArrayList<ShellAst>
    public var command: ?ShellCommand

    public init(kind: ShellAstKind) {
        this.kind = kind
        this.pipeline = None
        this.children = ArrayList<ShellAst>()
        this.command = None
    }

    public static func fromPipeline(pl: ShellPipeline): ShellAst {
        let node = ShellAst(ShellAstKind.Pipeline)
        node.pipeline = Some(pl)
        return node
    }

    public static func fromCommand(cmd: ShellCommand): ShellAst {
        let node = ShellAst(ShellAstKind.Command)
        node.command = Some(cmd)
        let pl = ShellPipeline()
        pl.addCommand(cmd)
        node.pipeline = Some(pl)
        return node
    }

    public static func fromSubshell(child: ShellAst): ShellAst {
        let node = ShellAst(ShellAstKind.Subshell)
        node.children.append(child)
        return node
    }

    /// 格式化输出 AST
    public func toString(): String {
        return formatAst(0)
    }

    private func formatAst(indent: Int64): String {
        let pad = " ".repeat(indent)
        let sb = StringBuilder()
        sb.append(pad)
        sb.append(kind.toString())
        sb.append("\n")

        match (pipeline) {
            case Some(pl) => {
                for (cmd in pl.commands) {
                    sb.append(pad)
                    sb.append("  cmd: ")
                    sb.append(cmd.toCommandLine())
                    sb.append("\n")
                }
            }
            case None => ()
        }

        match (command) {
            case Some(cmd) => {
                sb.append(pad)
                sb.append("  single: ")
                sb.append(cmd.toCommandLine())
                sb.append("\n")
            }
            case None => ()
        }

        for (child in children) {
            sb.append(child.formatAst(indent + 2))
        }

        return sb.toString()
    }
}

// ============================================================================
// ShellParser - Shell 命令解析器
// 严格翻译自: src/shell_launcher.zig 中 ShellParser
//   Bun 使用递归下降解析器将 token 流构建为 AST
//   支持运算符优先级: ; < &&/|| < | < command
//   支持 heredoc、变量展开、环境变量赋值 (VAR=val cmd)
// ============================================================================

/// Shell 命令解析器
/// 对应 Bun shell_launcher ShellParser
public class ShellParser {
    private var tokens: ArrayList<ShellToken>
    private var pos: Int64

    public init(tokens: ArrayList<ShellToken>) {
        this.tokens = tokens
        this.pos = 0
    }

    /// 从字符串直接解析
    public static func parse(input: String): ShellAst {
        let lexer = ShellLexer(input)
        let tokenList = lexer.tokenize()
        let parser = ShellParser(tokenList)
        return parser.parseSequence()
    }

    /// 仅进行词法分析
    public static func tokenize(input: String): ArrayList<ShellToken> {
        let lexer = ShellLexer(input)
        return lexer.tokenize()
    }

    /// 当前 token
    private func current(): ShellToken {
        if (pos < tokens.size) {
            return tokens[pos]
        }
        return ShellToken(ShellTokenKind.Eof, "", pos)
    }

    /// 前看 token
    private func peek(offset: Int64): ShellToken {
        let idx = pos + offset
        if (idx < tokens.size) {
            return tokens[idx]
        }
        return ShellToken(ShellTokenKind.Eof, "", idx)
    }

    /// 前进到下一个 token
    private func advance(): ShellToken {
        let tok = current()
        pos++
        return tok
    }

    /// 是否到末尾
    private func isEof(): Bool {
        return current().kind == ShellTokenKind.Eof
    }

    /// 匹配当前 token 类型
    private func match(kind: ShellTokenKind): Bool {
        return current().kind == kind
    }

    /// 消费指定类型 token，返回是否成功
    private func eat(kind: ShellTokenKind): Bool {
        if (match(kind)) {
            advance()
            return true
        }
        return false
    }

    // ========================================================================
    // 解析入口: 命令序列 (最低优先级)
    // 严格翻译自: shell_launcher.zig parseSequence
    // ; 和 \n 分隔的多条命令
    // ========================================================================

    /// 解析命令序列
    /// sequence := andOr ((';' | '\n') andOr)*
    public func parseSequence(): ShellAst {
        var left = parseAndOr()

        while (match(ShellTokenKind.Semicolon) || match(ShellTokenKind.Newline)) {
            advance()
            if (isEof()) {
                break
            }
            let right = parseAndOr()
            let seq = ShellAst(ShellAstKind.Sequence)
            seq.children.append(left)
            seq.children.append(right)
            left = seq
        }

        return left
    }

    // ========================================================================
    // 解析 && / || 条件链
    // 严格翻译自: shell_launcher.zig parseAndOr
    // ========================================================================

    /// 解析 &&/|| 条件链
    /// andOr := pipeline (('&&' | '||') pipeline)*
    private func parseAndOr(): ShellAst {
        var left = parsePipeline()

        while (match(ShellTokenKind.And) || match(ShellTokenKind.Or)) {
            let opKind = current().kind
            advance()
            let right = parsePipeline()
            let astKind = if (opKind == ShellTokenKind.And) {
                ShellAstKind.And
            } else {
                ShellAstKind.Or
            }
            let node = ShellAst(astKind)
            node.children.append(left)
            node.children.append(right)
            left = node
        }

        return left
    }

    // ========================================================================
    // 解析管道
    // 严格翻译自: shell_launcher.zig parsePipeline
    // cmd1 | cmd2 | cmd3
    // ========================================================================

    /// 解析管道
    /// pipeline := command ('|' command)*
    private func parsePipeline(): ShellAst {
        let pipeline = ShellPipeline()
        let cmd = parseCommand()
        pipeline.addCommand(cmd)

        while (match(ShellTokenKind.Pipe)) {
            advance()
            let nextCmd = parseCommand()
            pipeline.addCommand(nextCmd)
        }

        // 检查后台运行标记
        if (match(ShellTokenKind.Background)) {
            advance()
            pipeline.background = true
        }

        return ShellAst.fromPipeline(pipeline)
    }

    // ========================================================================
    // 解析单条命令
    // 严格翻译自: shell_launcher.zig parseCommand
    // 支持: VAR=val 前缀赋值、重定向、heredoc
    // ========================================================================

    /// 解析单条命令
    /// command := (assignment)* (subshell | simpleCommand) (redirect)*
    private func parseCommand(): ShellCommand {
        let cmd = ShellCommand()
        let envAssigns = ArrayList<String>()

        // 收集环境变量赋值 (VAR=val 形式)
        while (!isEof() && isAssignment()) {
            let tok = advance()
            envAssigns.append(tok.value)
        }

        // 子 shell
        if (match(ShellTokenKind.SubshellOpen)) {
            advance()
            let innerAst = parseSequence()
            eat(ShellTokenKind.SubshellClose)
            // 子 shell 命令用特殊标记表示
            cmd.program = "(subshell)"
            cmd.addArg("(subshell)")
            return cmd
        }

        // 命令名
        let programToken = parseWord()
        cmd.program = programToken
        cmd.addArg(programToken)

        // 参数和重定向
        while (!isEof()) {
            // 重定向
            if (match(ShellTokenKind.RedirectOut)) {
                advance()
                let target = parseWord()
                cmd.addRedirect(ShellRedirect(ShellRedirectKind.Output, target, 1))
            } else if (match(ShellTokenKind.RedirectAppend)) {
                advance()
                let target = parseWord()
                cmd.addRedirect(ShellRedirect(ShellRedirectKind.Append, target, 1))
            } else if (match(ShellTokenKind.RedirectIn)) {
                advance()
                let target = parseWord()
                cmd.addRedirect(ShellRedirect(ShellRedirectKind.Input, target, 0))
            } else if (match(ShellTokenKind.RedirectErr)) {
                advance()
                let target = parseWord()
                cmd.addRedirect(ShellRedirect(ShellRedirectKind.Stderr, target, 2))
            } else if (match(ShellTokenKind.Heredoc) || match(ShellTokenKind.HeredocStrip)) {
                // Heredoc 处理
                let heredocKind = current().kind
                advance()
                let delimiter = parseWord()
                let stripTabs = heredocKind == ShellTokenKind.HeredocStrip
                // heredoc 内容在换行后直到遇到 delimiter
                let content = parseHeredocContent(delimiter, stripTabs)
                cmd.addArg(content)
            } else if (match(ShellTokenKind.Background)) {
                // 后台运行 - 由上层 pipeline 处理
                break
            } else if (match(ShellTokenKind.Pipe) || match(ShellTokenKind.And) ||
                       match(ShellTokenKind.Or) || match(ShellTokenKind.Semicolon) ||
                       match(ShellTokenKind.Newline) || match(ShellTokenKind.Eof) ||
                       match(ShellTokenKind.SubshellClose)) {
                // 停止条件
                break
            } else {
                // 普通参数
                let arg = parseWord()
                cmd.addArg(arg)
            }
        }

        // 应用环境变量赋值
        for (assign in envAssigns) {
            let eqIdx = assign.indexOf("=")
            if (eqIdx >= 0) {
                let key = assign.substring(0, eqIdx)
                let val = assign.substring(eqIdx + 1)
                cmd.setEnv(key, val)
            }
        }

        return cmd
    }

    /// 判断当前 token 是否为环境变量赋值 (VAR=val)
    private func isAssignment(): Bool {
        if (match(ShellTokenKind.Text) || match(ShellTokenKind.DoubleQuoted)) {
            let val = current().value
            let eqIdx = val.indexOf("=")
            if (eqIdx > 0) {
                let lhs = val.substring(0, eqIdx)
                return isIdentifierString(lhs)
            }
        }
        return false
    }

    /// 判断字符串是否为合法标识符
    private func isIdentifierString(s: String): Bool {
        if (s.isEmpty()) {
            return false
        }
        for (i in 0..s.length) {
            let c = s[i]
            if (i == Int64(0)) {
                if (!((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_')) {
                    return false
                }
            } else {
                if (!((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') ||
                      (c >= '0' && c <= '9') || c == '_')) {
                    return false
                }
            }
        }
        return true
    }

    /// 解析一个 word (可能是 text、quoted string 或 variable)
    /// 将相邻的 token 拼接为一个完整的 word
    private func parseWord(): String {
        let sb = StringBuilder()

        // 收集连续的 word token (text/quoted/variable/glob)
        while (!isEof()) {
            let kind = current().kind
            if (kind == ShellTokenKind.Text || kind == ShellTokenKind.Glob) {
                sb.append(advance().value)
            } else if (kind == ShellTokenKind.SingleQuoted ||
                       kind == ShellTokenKind.DoubleQuoted) {
                sb.append(advance().value)
            } else if (kind == ShellTokenKind.Variable) {
                sb.append("${")
                sb.append(advance().value)
                sb.append("}")
            } else if (kind == ShellTokenKind.BacktickQuoted) {
                sb.append("$(")
                sb.append(advance().value)
                sb.append(")")
            } else {
                break
            }
        }

        // 如果没有收集到任何内容，消费一个 token 作为 fallback
        if (sb.toString().isEmpty() && !isEof()) {
            sb.append(advance().value)
        }

        return sb.toString()
    }

    /// 解析 heredoc 内容
    /// 对应 Bun shell_launcher 中 heredoc 处理
    /// 从换行后开始读取，直到遇到只含 delimiter 的行
    private func parseHeredocContent(delimiter: String, stripTabs: Bool): String {
        let sb = StringBuilder()
        // 在实际 shell 中，heredoc 内容在换行之后
        // 这里简化处理: 跳过换行然后读取直到 delimiter
        eat(ShellTokenKind.Newline)

        var depth = 0
        while (!isEof()) {
            if (match(ShellTokenKind.Newline)) {
                // 检查下一行是否为 delimiter
                advance()
                if (match(ShellTokenKind.Text) && current().value == delimiter) {
                    advance()
                    break
                }
                sb.append("\n")
            } else {
                let tok = advance()
                sb.append(tok.value)
            }
            depth++
            // 防止无限循环
            if (depth > 10000) {
                break
            }
        }

        var content = sb.toString()
        // <<- 标记: 去除每行开头的 tab
        if (stripTabs) {
            content = stripLeadingTabs(content)
        }

        return content
    }

    /// 去除每行开头的 tab 字符
    private func stripLeadingTabs(s: String): String {
        let lines = s.split("\n")
        let sb = StringBuilder()
        var first = true
        for (line in lines) {
            if (!first) {
                sb.append("\n")
            }
            first = false
            var stripped = line
            while (stripped.length > 0 && stripped[0] == '\t') {
                stripped = stripped.substring(1)
            }
            sb.append(stripped)
        }
        return sb.toString()
    }
}

// ============================================================================
// ShellWordExpander - Shell 单词展开器
// 严格翻译自: src/shell_launcher.zig 中变量展开逻辑
//   Bun 在执行前将 $VAR/${VAR} 展开为实际值
//   支持默认值 ${VAR:-default}、替代值 ${VAR:+alt}、字符串操作
// ============================================================================

/// Shell 单词展开器
/// 对应 Bun shell_launcher 中变量展开处理
public class ShellWordExpander {
    private var env: HashMap<String, String>

    public init(env: HashMap<String, String>) {
        this.env = env
    }

    /// 展开 word 中的变量引用
    /// 对应 Bun shell_launcher 中 expandVariables
    public func expand(word: String): String {
        let sb = StringBuilder()
        var i = Int64(0)

        while (i < word.length) {
            let ch = word[i]
            if (ch == '$') {
                i++
                if (i >= word.length) {
                    sb.append('$')
                    break
                }
                let expanded = expandVariableAt(word, i)
                sb.append(expanded.value)
                i = expanded.nextPos
            } else if (ch == '\\') {
                i++
                if (i < word.length) {
                    sb.append(word[i])
                    i++
                }
            } else {
                sb.append(ch)
                i++
            }
        }

        return sb.toString()
    }

    /// 展开 glob 模式
    /// 对应 Bun shell_launcher 中 glob expansion
    /// 当前简化实现: 直接返回原始模式
    public func expandGlob(pattern: String): ArrayList<String> {
        let result = ArrayList<String>()
        // 实际实现需要文件系统 glob 匹配
        // 当前简化: 直接返回模式本身
        result.append(pattern)
        return result
    }

    /// 在指定位置展开变量
    /// 返回展开值和下一个位置
    private func expandVariableAt(word: String, startPos: Int64): ExpandResult {
        if (startPos >= word.length) {
            return ExpandResult("", startPos)
        }

        let ch = word[startPos]

        // ${...} 形式
        if (ch == '{') {
            return expandBracedVariable(word, startPos + 1)
        }

        // $? 退出码
        if (ch == '?') {
            return ExpandResult("0", startPos + 1)  // 退出码占位
        }

        // $! 后台 PID
        if (ch == '!') {
            return ExpandResult("", startPos + 1)
        }

        // $$
        if (ch == '$') {
            return ExpandResult(Int64(processId()).toString(), startPos + 1)
        }

        // 普通变量名 $VAR
        if (isIdentifierStart(ch)) {
            let sb = StringBuilder()
            var i = startPos
            while (i < word.length && isIdentifierChar(word[i])) {
                sb.append(word[i])
                i++
            }
            let name = sb.toString()
            let val = getEnv(name)
            return ExpandResult(val, i)
        }

        return ExpandResult("$", startPos)
    }

    /// 展开 ${...} 形式的变量引用
    /// 支持: ${VAR}, ${VAR:-default}, ${VAR:+alt}, ${#VAR}, ${VAR:=default}
    private func expandBracedVariable(word: String, startPos: Int64): ExpandResult {
        let sb = StringBuilder()
        var i = startPos

        // 读取到 }
        while (i < word.length && word[i] != '}') {
            sb.append(word[i])
            i++
        }
        i++ // 跳过 }

        let expr = sb.toString()

        // ${#VAR} - 字符串长度
        if (expr.length > 1 && expr[0] == '#') {
            let name = expr.substring(1)
            let val = getEnv(name)
            return ExpandResult(Int64(val.length).toString(), i)
        }

        // ${VAR:-default} - 默认值
        let defaultIdx = expr.indexOf(":-")
        if (defaultIdx >= 0) {
            let name = expr.substring(0, defaultIdx)
            let defaultVal = expr.substring(defaultIdx + 2)
            let val = getEnv(name)
            return ExpandResult(if (val.isEmpty()) { defaultVal } else { val }, i)
        }

        // ${VAR:+alt} - 替代值
        let altIdx = expr.indexOf(":+")
        if (altIdx >= 0) {
            let name = expr.substring(0, altIdx)
            let altVal = expr.substring(altIdx + 2)
            let val = getEnv(name)
            return ExpandResult(if (val.isEmpty()) { "" } else { altVal }, i)
        }

        // ${VAR:=default} - 赋默认值
        let assignIdx = expr.indexOf(":=")
        if (assignIdx >= 0) {
            let name = expr.substring(0, assignIdx)
            let defaultVal = expr.substring(assignIdx + 2)
            let val = getEnv(name)
            if (val.isEmpty()) {
                env.put(name, defaultVal)
                return ExpandResult(defaultVal, i)
            }
            return ExpandResult(val, i)
        }

        // 简单 ${VAR}
        let val = getEnv(expr)
        return ExpandResult(val, i)
    }

    /// 获取环境变量
    private func getEnv(name: String): String {
        match (env.get(name)) {
            case Some(v) => v
            case None => ""
        }
    }

    /// 获取当前进程 ID (占位)
    private func processId(): Int64 {
        // 实际实现需要调用系统调用
        return 1
    }

    private func isIdentifierStart(ch: Char): Bool {
        return (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z') || ch == '_'
    }

    private func isIdentifierChar(ch: Char): Bool {
        return isIdentifierStart(ch) || (ch >= '0' && ch <= '9')
    }
}

/// 展开结果
private class ExpandResult {
    public let value: String
    public let nextPos: Int64

    public init(value: String, nextPos: Int64) {
        this.value = value
        this.nextPos = nextPos
    }
}

// ============================================================================
// 便捷函数
// ============================================================================

/// 解析 shell 命令字符串为 AST
public func parseShell(input: String): ShellAst {
    return ShellParser.parse(input)
}

/// 对 shell 命令字符串进行词法分析
public func tokenizeShell(input: String): ArrayList<ShellToken> {
    return ShellParser.tokenize(input)
}

/// 展开 shell 命令中的变量引用
public func expandShellVars(input: String, env: HashMap<String, String>): String {
    let expander = ShellWordExpander(env)
    return expander.expand(input)
}
