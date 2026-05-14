// bao_parser - JavaScript/TypeScript 解析器
// 严格翻译自:
//   src/js_parser/js_parser.zig - Parser 顶层 API
//   src/js_parser/parser.zig - Parser 结构体、AST 类型
//   src/js_parser/p.zig - Parser 核心实现 (~7000行)
//   src/js_parser/lexer.zig - 词法分析器
//   src/js_parser/lexer_tables.zig - Token 定义和查找表
//   src/js_parser/ast/ - AST 节点类型 (E, S, G, B, Expr, Stmt, Binding)
package bao_parser

import bao_core.*
import bao_collections.*
import bao_unicode.*

// ============================================================================
// Logger - 日志和源码位置
// 严格翻译自: src/logger/logger.zig
//   pub const Loc = struct { start: i32 = -1 }
//   pub const Range = struct { loc: Loc, len: i32 }
//   pub const Log = struct { msgs, warnings, errors, level }
//   pub const Source = struct { path, contents, index }
// ============================================================================

/// 源码位置 - 严格对应 Bun logger.Loc
/// Bun: pub const Loc = struct { start: i32 = -1 }
/// 使用字节偏移量表示位置
public class Loc {
    /// 字节偏移 - 对应 Bun Loc.start: i32
    public var start: Int64

    /// 空位置 - 对应 Bun Loc.Empty = Loc{ .start = -1 }
    public static let EMPTY: Loc = Loc(-1)

    public init() {
        start = -1
    }

    public init(start: Int64) {
        this.start = start
    }

    /// 是否为空 - 对应 Bun Loc.isEmpty()
    public func isEmpty(): Bool {
        return start == -1
    }

    /// 转为无符号索引 - 对应 Bun Loc.i() -> usize
    public func i(): Int64 {
        return if (start < 0) { Int64(0) } else { start }
    }

    /// 相等比较 - 对应 Bun Loc.eql()
    public func eql(other: Loc): Bool {
        return start == other.start
    }
}

/// 源码范围 - 严格对应 Bun logger.Range
/// Bun: pub const Range = struct { loc: Loc = Loc.Empty, len: i32 = 0 }
public class Range {
    public var loc: Loc
    public var len: Int64

    /// 空范围 - 对应 Bun Range.none
    public static let NONE: Range = Range()

    public init() {
        loc = Loc.EMPTY
        len = 0
    }

    public init(loc: Loc, len: Int64) {
        this.loc = loc
        this.len = len
    }

    public init(start: Int64, len: Int64) {
        this.loc = Loc(start)
        this.len = len
    }

    /// 获取范围内的文本 - 对应 Bun Range.in(buf)
    public func inBuf(buf: Array<UInt8>): Array<UInt8> {
        if (loc.start < 0 || len <= 0) {
            return []
        }
        let s = loc.i()
        let e = if (s + len > buf.size) { buf.size } else { s + len }
        var result = Array<UInt8>()
        for (i in s..e) {
            result.append(buf[Int64(i)])
        }
        return result
    }

    /// 是否包含偏移 - 对应 Bun Range.contains(k)
    public func contains(k: Int64): Bool {
        return k >= loc.start && k < loc.start + len
    }

    /// 是否为空
    public func isEmpty(): Bool {
        return len == 0 && loc.start == Loc.EMPTY.start
    }

    /// 结束位置 - 对应 Bun Range.end()
    public func end(): Loc {
        return Loc(loc.start + len)
    }
}

/// 日志级别 - 对应 Bun Log.Level
public enum LogLevel {
    | Verbose  // 0
    | Debug    // 1
    | Info     // 2
    | Warn     // 3
    | Error    // 4

    public func atLeast(other: LogLevel): Bool {
        return this.ordinal() <= other.ordinal()
    }
}

/// 日志消息 - 对应 Bun logger.Msg
public class LogMsg {
    public var level: LogLevel
    public var data: MsgData

    public init(level: LogLevel, data: MsgData) {
        this.level = level
        this.data = data
    }
}

/// 消息数据 - 对应 Bun MsgData
public class MsgData {
    public var text: String
    public var location: ?SourceLoc

    public init(text: String) {
        this.text = text
        this.location = None
    }

    public init(text: String, location: SourceLoc) {
        this.text = text
        this.location = Some(location)
    }
}

/// 源码定位信息 - 对应 Bun logger.Location
public class SourceLoc {
    public var file: String
    public var line: Int64
    public var column: Int64
    public var lineText: String

    public init() {
        file = ""
        line = 0
        column = 0
        lineText = ""
    }

    public init(file: String, line: Int64, column: Int64) {
        this.file = file
        this.line = line
        this.column = column
        this.lineText = ""
    }
}

/// 日志 - 严格对应 Bun logger.Log
/// Bun: pub const Log = struct { msgs, warnings: u32, errors: u32, level }
public class Log {
    public var msgs: ArrayList<LogMsg>
    public var warnings: Int64
    public var errors: Int64
    public var level: LogLevel

    public init() {
        msgs = ArrayList<LogMsg>()
        warnings = 0
        errors = 0
        level = LogLevel.Warn
    }

    /// 是否有错误 - 对应 Bun Log.hasErrors()
    public func hasErrors(): Bool {
        return errors > 0
    }

    /// 添加错误 - 对应 Bun Log.addError()
    public func addError(data: MsgData): Unit {
        msgs.append(LogMsg(LogLevel.Error, data))
        errors += 1
    }

    /// 添加警告
    public func addWarning(data: MsgData): Unit {
        msgs.append(LogMsg(LogLevel.Warn, data))
        warnings += 1
    }

    /// 重置 - 对应 Bun Log.reset()
    public func reset(): Unit {
        msgs.clear()
        warnings = 0
        errors = 0
    }
}

/// 源文件 - 严格对应 Bun logger.Source
/// Bun: pub const Source = struct { path, contents, index }
public class Source {
    /// 文件路径 - 对应 Bun Source.path
    public var path: String
    /// 文件内容 - 对应 Bun Source.contents: string
    public var contents: Array<UInt8>
    /// 源文件索引 - 对应 Bun Source.index: Index
    public var index: Int64

    public init(path: String, contents: String) {
        this.path = path
        this.contents = Array<UInt8>()
        for (c in contents) {
            this.contents.append(UInt8(c.value))
        }
        this.index = 0
    }

    public init(path: String, contents: Array<UInt8>) {
        this.path = path
        this.contents = contents
        this.index = 0
    }

    /// 获取范围内的文本
    public func textForRange(r: Range): String {
        let bytes = r.inBuf(contents)
        var sb = StringBuilder()
        for (b in bytes) {
            sb.append(Char(Int32(b)))
        }
        return sb.toString()
    }

    /// 获取指定位置的行文本
    public func textForLoc(loc: Loc): String {
        if (loc.start < 0) {
            return ""
        }
        // 找到行首
        var lineStart = Int64(loc.start)
        while (lineStart > 0 && contents[lineStart - 1] != UInt8('\n')) {
            lineStart -= 1
        }
        // 找到行尾
        var lineEnd = Int64(loc.start)
        while (lineEnd < contents.size && contents[lineEnd] != UInt8('\n')) {
            lineEnd += 1
        }
        var sb = StringBuilder()
        for (i in lineStart..lineEnd) {
            sb.append(Char(Int32(contents[Int64(i)])))
        }
        return sb.toString()
    }
}

// ============================================================================
// Ref 和 Index - AST 引用和索引
// 严格翻译自: src/js_parser/ast/base.zig
//   pub const Ref = packed struct(u64) { inner_index: u31, tag: enum(u2), source_index: u31 }
//   pub const Index = packed struct(u32) { value: u32 }
// ============================================================================

/// 引用标记 - 对应 Bun Ref.tag
public enum RefTag {
    | Invalid        // 0
    | AllocatedName  // 1
    | SourceSlice    // 2
    | Symbol         // 3
}

/// 符号引用 - 严格对应 Bun Ref
/// Bun: packed struct(u64) { inner_index: u31, tag: enum(u2), source_index: u31 }
/// 仓颉使用 class 实现
public class Ref {
    /// 内部索引 - 对应 Bun Ref.inner_index: u31
    public var innerIndex: Int64
    /// 标签 - 对应 Bun Ref.tag
    public var tag: RefTag
    /// 源索引 - 对应 Bun Ref.source_index: u31
    public var sourceIndex: Int64

    /// 空引用 - 对应 Bun Ref.None
    public static let NONE: Ref = Ref(0, RefTag.Invalid, 0)

    public init(innerIndex: Int64, tag: RefTag, sourceIndex: Int64) {
        this.innerIndex = innerIndex
        this.tag = tag
        this.sourceIndex = sourceIndex
    }

    /// 是否为空 - 对应 Bun Ref.isNull()
    public func isNull(): Bool {
        return tag == RefTag.Invalid
    }

    /// 是否有效
    public func isValid(): Bool {
        return tag != RefTag.Invalid
    }

    /// 相等比较
    public func eql(other: Ref): Bool {
        return innerIndex == other.innerIndex && tag == other.tag && sourceIndex == other.sourceIndex
    }
}

/// AST 索引 - 对应 Bun Index
/// Bun: packed struct(u32) { value: u32 }
public class AstIndex {
    public var value: UInt32

    /// 无效索引 - 对应 Bun Index.invalid
    public static let INVALID: AstIndex = AstIndex(UInt32(0x7FFFFFFF))

    public init(value: UInt32) {
        this.value = value
    }

    public func isValid(): Bool {
        return value != AstIndex.INVALID.value
    }
}

// ============================================================================
// Op - 操作符
// 严格翻译自: src/js_parser/ast/Op.zig
//   pub const Code = enum(u8) { un_pos, un_neg, ..., bin_add, bin_sub, ... }
//   pub const Level = enum(comma, spread, yield, assign, ..., lowest)
// ============================================================================

/// 操作符代码 - 对应 Bun Op.Code
/// Bun: enum(u8) 包含一元、二元、赋值操作符
public enum OpCode {
    // 一元操作符
    | UnPos          // +x
    | UnNeg          // -x
    | UnCpl          // ~x
    | UnNot          // !x
    | UnVoid         // void x
    | UnDelete       // delete x
    | Typeof         // typeof x

    // 二元操作符
    | BinAdd         // +
    | BinSub         // -
    | BinMul         // *
    | BinDiv         // /
    | BinRem         // %
    | BinPow         // **
    | BinLt          // <
    | BinGt          // >
    | BinLe          // <=
    | BinGe          // >=
    | BinIn          // in
    | BinInstanceof  // instanceof
    | BinShl         // <<
    | BinShr         // >>
    | BinUShr        // >>>
    | BinEq          // ==
    | BinNe          // !=
    | BinEqStrict    // ===
    | BinNeStrict    // !==
    | BinAnd         // &
    | BinOr          // |
    | BinXor         // ^
    | BinLoAnd       // &&
    | BinLoOr        // ||
    | BinNullish     // ??

    // 赋值操作符
    | BinAssign      // =
    | BinAddAssign   // +=
    | BinSubAssign   // -=
    | BinMulAssign   // *=
    | BinDivAssign   // /=
    | BinRemAssign   // %=
    | BinPowAssign   // **=
    | BinShlAssign   // <<=
    | BinShrAssign   // >>=
    | BinUShrAssign  // >>>=
    | BinAndAssign   // &=
    | BinOrAssign    // |=
    | BinXorAssign   // ^=
    | BinLoAndAssign // &&=
    | BinLoOrAssign  // ||=
    | BinNullishAssign // ??=

    // 特殊
    | Comma          // ,
    | Spread         // ...

    /// 是否为赋值操作符
    public func isAssign(): Bool {
        match (this) {
            case BinAssign | BinAddAssign | BinSubAssign | BinMulAssign |
                 BinDivAssign | BinRemAssign | BinPowAssign | BinShlAssign |
                 BinShrAssign | BinUShrAssign | BinAndAssign | BinOrAssign |
                 BinXorAssign | BinLoAndAssign | BinLoOrAssign | BinNullishAssign => true
            case _ => false
        }
    }

    /// 获取操作符文本
    public func text(): String {
        match (this) {
            case UnPos => "+"
            case UnNeg => "-"
            case UnCpl => "~"
            case UnNot => "!"
            case UnVoid => "void"
            case UnDelete => "delete"
            case Typeof => "typeof"
            case BinAdd => "+"
            case BinSub => "-"
            case BinMul => "*"
            case BinDiv => "/"
            case BinRem => "%"
            case BinPow => "**"
            case BinLt => "<"
            case BinGt => ">"
            case BinLe => "<="
            case BinGe => ">="
            case BinIn => "in"
            case BinInstanceof => "instanceof"
            case BinEq => "=="
            case BinNe => "!="
            case BinEqStrict => "==="
            case BinNeStrict => "!=="
            case BinAnd => "&"
            case BinOr => "|"
            case BinXor => "^"
            case BinLoAnd => "&&"
            case BinLoOr => "||"
            case BinNullish => "??"
            case BinAssign => "="
            case BinAddAssign => "+="
            case BinSubAssign => "-="
            case BinMulAssign => "*="
            case BinDivAssign => "/="
            case BinRemAssign => "%="
            case BinPowAssign => "**="
            case BinShlAssign => "<<="
            case BinShrAssign => ">>="
            case BinUShrAssign => ">>>="
            case BinAndAssign => "&="
            case BinOrAssign => "|="
            case BinXorAssign => "^="
            case BinLoAndAssign => "&&="
            case BinLoOrAssign => "||="
            case BinNullishAssign => "??="
            case Comma => ","
            case Spread => "..."
            case _ => "??"
        }
    }
}

/// 操作符优先级 - 对应 Bun Op.Level
/// 从低到高排列，用于表达式解析的 Pratt 解析器
public enum OpLevel {
    | Comma       // ,
    | Spread      // ...
    | Yield       // yield
    | Assign      // = += -= ...
    | Conditional // ?:
    | NullishCoalescing // ??
    | LogicalOr   // ||
    | LogicalAnd  // &&
    | BitwiseOr   // |
    | BitwiseXor  // ^
    | BitwiseAnd  // &
    | Equality    // == != === !==
    | Relational  // < > <= >= in instanceof
    | Shift       // << >> >>>
    | Additive    // + -
    | Multiplicative // * / %
    | Exponentiation // **
    | Unary       // ! ~ + - typeof void delete
    | Update      // ++ --
    | Member      // . [] ?.
    | Call        // f() new f()
    | Primary     // literals, identifiers

    public func ordinal(): Int64 {
        match (this) {
            case Comma => 0
            case Spread => 1
            case Yield => 2
            case Assign => 3
            case Conditional => 4
            case NullishCoalescing => 5
            case LogicalOr => 6
            case LogicalAnd => 7
            case BitwiseOr => 8
            case BitwiseXor => 9
            case BitwiseAnd => 10
            case Equality => 11
            case Relational => 12
            case Shift => 13
            case Additive => 14
            case Multiplicative => 15
            case Exponentiation => 16
            case Unary => 17
            case Update => 18
            case Member => 19
            case Call => 20
            case Primary => 21
        }
    }
}

// ============================================================================
// ExportsKind - 模块导出类型
// 严格翻译自: src/js_parser/js_parser.zig:300-360
//   pub const ExportsKind = enum { none, cjs, esm, esm_with_dynamic_fallback, ... }
// ============================================================================

/// 模块导出类型 - 对应 Bun ExportsKind
public enum ExportsKind {
    | None                           // 无导出
    | Cjs                            // CommonJS
    | Esm                            // ES Module
    | EsmWithDynamicFallback         // ESM + 动态回退
    | EsmWithDynamicFallbackFromCjs  // 从 CJS 转换的 ESM

    public func isDynamic(): Bool {
        match (this) {
            case Cjs | EsmWithDynamicFallback | EsmWithDynamicFallbackFromCjs => true
            case None | Esm => false
        }
    }
}

/// 严格模式类型 - 对应 Bun StrictModeKind
public enum StrictModeKind {
    | SloppyMode
    | ExplicitStrictMode
    | ImplicitStrictModeImport
    | ImplicitStrictModeExport
    | ImplicitStrictModeTopLevelAwait
    | ImplicitStrictModeClass
}

/// 变量声明类型 - 对应 Bun S.Local.Kind
public enum DeclKind {
    | Var         // var
    | Let         // let
    | Const       // const
    | Using       // using
    | AwaitUsing  // await using
}

/// 可选链 - 对应 Bun OptionalChain
public enum OptionalChain {
    | Start       // a?.b
    | Continuation // a?.b.c 中的 .c
}

/// 赋值目标 - 对应 Bun AssignTarget
public enum AssignTarget {
    | None      // 0
    | Replace   // a = b
    | Update    // a += b
}
