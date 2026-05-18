// 词法分析器日志
// 严格翻译自: src/ast/lexer_log.rs (114行)
//   Shared lexer -> Log error-reporting cluster.
//   js_parser, json, toml 词法分析器共享的错误报告模式。
//   包含:
//     - LexerLog trait: 词法分析器日志接口
//     - 默认实现中的 add_error, add_range_error, syntax_error 等方法
package bao_ast

import bao_core.*
import bao_collections.*

// ============================================================================
// LexerLog - 词法分析器日志接口
// 严格翻译自: lexer_log.rs:19-114
//   pub trait LexerLog<'s> { type Err; fn log_mut, fn source, ... }
// ============================================================================

/// 词法分析器日志 - 对应 Bun LexerLog trait
/// 所有词法分析器 (JS, JSON, TOML) 共享的错误报告模式。
/// 将 is_log_disabled 检查、去重和日志推送统一到一个 trait 中。
public interface LexerLog {
    /// 获取可变日志
    func getLog(): Log
    /// 设置日志
    func setLog(log: Log): Unit
    /// 获取源文件
    func getSource(): Source
    /// 获取上一个错误位置
    func getPrevErrorLoc(): ASTLoc
    /// 设置上一个错误位置
    func setPrevErrorLoc(loc: ASTLoc): Unit
    /// 获取起始位置
    func getStart(): Int64
    /// 是否禁用日志
    func isLogDisabled(): Bool
}

// ============================================================================
// LexerLogHelper - 词法分析器日志辅助方法
// 严格翻译自: lexer_log.rs:47-114
//   LexerLog trait 的 provided 方法
// ============================================================================

/// 词法分析器日志辅助
public class LexerLogHelper {

    /// 添加错误 - 对应 LexerLog.add_error()
    /// 检查 is_log_disabled，与前一个错误位置去重，然后添加到日志
    public static func addError(lexer: LexerLog, loc: Int64, message: String): Unit {
        if (lexer.isLogDisabled()) {
            return
        }
        let l = ASTLoc(Int32(loc))
        if (l.start == lexer.getPrevErrorLoc().start) {
            return
        }
        let log = lexer.getLog()
        log.addError(message, lexer.getSource(), l)
        lexer.setPrevErrorLoc(l)
    }

    /// 添加范围错误 - 对应 LexerLog.add_range_error()
    public static func addRangeError(lexer: LexerLog, r: ASTRange, message: String): Bool {
        if (lexer.isLogDisabled()) {
            return true
        }
        if (r.loc.start == lexer.getPrevErrorLoc().start) {
            return true
        }
        let log = lexer.getLog()
        log.addError(message, lexer.getSource(), r.loc)
        lexer.setPrevErrorLoc(r.loc)
        true
    }

    /// 语法错误 - 对应 LexerLog.syntax_error()
    /// 仅在没有已存在错误时添加 "Syntax Error"
    public static func syntaxError(lexer: LexerLog): String {
        let log = lexer.getLog()
        if (!log.hasErrors()) {
            addError(lexer, lexer.getStart(), "Syntax Error")
        }
        "SyntaxError"
    }

    /// 添加默认错误 - 对应 LexerLog.add_default_error()
    public static func addDefaultError(lexer: LexerLog, msg: String): String {
        addError(lexer, lexer.getStart(), msg)
        "SyntaxError"
    }

    /// 添加语法错误 - 对应 LexerLog.add_syntax_error()
    public static func addSyntaxError(lexer: LexerLog, loc: Int64, message: String): String {
        addError(lexer, loc, message)
        "SyntaxError"
    }
}

// ============================================================================
// Log - 日志
// ============================================================================

/// 日志 - 对应 Bun Log
/// 编译器日志，收集警告和错误信息
public class Log {
    public var errors: ArrayList<LogEntry>
    public var warnings: ArrayList<LogEntry>

    public init() {
        errors = ArrayList<LogEntry>()
        warnings = ArrayList<LogEntry>()
    }

    /// 是否有错误
    public func hasErrors(): Bool {
        errors.size > 0
    }

    /// 添加错误
    public func addError(message: String, source: Source, loc: ASTLoc): Unit {
        errors.append(LogEntry(message, source, loc))
    }

    /// 添加警告
    public func addWarning(message: String, source: Source, loc: ASTLoc): Unit {
        warnings.append(LogEntry(message, source, loc))
    }
}

/// 日志条目
public class LogEntry {
    public var message: String
    public var source: Source
    public var loc: ASTLoc

    public init(message: String, source: Source, loc: ASTLoc) {
        this.message = message
        this.source = source
        this.loc = loc
    }
}

// ============================================================================
// Source - 源文件
// ============================================================================

/// 源文件 - 对应 Bun Source
public class Source {
    public var path: String
    public var contents: String
    public var key: String

    public init(path: String, contents: String) {
        this.path = path
        this.contents = contents
        this.key = path
    }
}
