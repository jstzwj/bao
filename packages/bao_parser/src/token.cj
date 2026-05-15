// Token - JavaScript 词法单元类型
// 严格翻译自: src/js_parser/lexer_tables.zig
//   pub const T = enum(u8) { t_end_of_file, t_close_brace, ... }
//   pub const Keywords = ComptimeStringMap(T, .{ ... })
//   pub const StrictModeReservedWords = ComptimeStringMap(void, .{ ... })
package bao_parser

// ============================================================================
// Token - JavaScript 词法单元
// 严格翻译自: src/js_parser/lexer_tables.zig:1-150
//   pub const T = enum(u8) { ... }
// 按照原始顺序严格排列，保持 ordinal 值与 Bun 一致
// ============================================================================

/// JavaScript 词法单元 - 严格对应 Bun T (Token)
/// Bun: enum(u8) 包含所有 JS/TS 词法单元
public enum Token {
    // 特殊
    | EndOfFile        // t_end_of_file
    | CloseBrace       // t_close_brace - 紧跟 EOF 以便一次比较
    | SyntaxError      // t_syntax_error
    | Hashbang         // t_hashbang - "#!/usr/bin/env node"

    // 字面量 (literals)
    | NoSubstitutionTemplateLiteral // t_no_substitution_template_literal
    | NumericLiteral   // t_numeric_literal - 值在 lexer.number
    | StringLiteral    // t_string_literal - 值在 lexer.stringLiteral
    | BigIntegerLiteral // t_big_integer_literal - 值在 lexer.identifier

    // 模板字面量 (pseudo-literals)
    | TemplateHead     // t_template_head
    | TemplateMiddle   // t_template_middle
    | TemplateTail     // t_template_tail

    // 标点符号 (punctuation)
    | Ampersand        // &
    | AmpersandAmpersand // &&
    | Asterisk         // *
    | AsteriskAsterisk // **
    | At               // @
    | Bar              // |
    | BarBar           // ||
    | Caret            // ^
    | CloseBracket     // ]
    | CloseParen       // )
    | Colon            // :
    | Comma            // ,
    | Dot              // .
    | DotDotDot        // ...
    | EqualsEquals     // ==
    | EqualsEqualsEquals // ===
    | EqualsGreaterThan // =>
    | Exclamation      // !
    | ExclamationEquals // !=
    | ExclamationEqualsEquals // !=
    | GreaterThan      // >
    | GreaterThanEquals // >=
    | GreaterThanGreaterThan // >>
    | GreaterThanGreaterThanGreaterThan // >>>
    | LessThan         // <
    | LessThanEquals   // <=
    | LessThanLessThan // <<
    | Minus            // -
    | MinusMinus       // --
    | OpenBrace        // {
    | OpenBracket      // [
    | OpenParen        // (
    | Percent          // %
    | Plus             // +
    | PlusPlus         // ++
    | Question         // ?
    | QuestionDot      // ?.
    | QuestionQuestion // ??
    | Semicolon        // ;
    | Slash            // /
    | Tilde            // ~

    // 赋值操作符 (assignments) - 与 isAssign() 保持同步
    | AmpersandAmpersandEquals // &&=
    | AmpersandEquals  // &=
    | AsteriskAsteriskEquals // **=
    | AsteriskEquals   // *=
    | BarBarEquals     // ||=
    | BarEquals        // |=
    | CaretEquals      // ^=
    | Equals           // =
    | GreaterThanGreaterThanEquals // >>=
    | GreaterThanGreaterThanGreaterThanEquals // >>>=
    | LessThanLessThanEquals // <<=
    | MinusEquals      // -=
    | PercentEquals    // %=
    | PlusEquals       // +=
    | QuestionQuestionEquals // ??=
    | SlashEquals      // /=

    // 私有标识符
    | PrivateIdentifier // #foo

    // 标识符
    | Identifier       // 标识符内容在 lexer.identifier
    | EscapedKeyword   // 被转义的关键字 (如 \u0069f)

    // 保留字 (reserved words)
    | Break            // break
    | Case             // case
    | Catch            // catch
    | Class            // class
    | Const            // const
    | Continue         // continue
    | Debugger         // debugger
    | Default          // default
    | Delete           // delete
    | Do               // do
    | Else             // else
    | Enum             // enum
    | Export           // export
    | Extends          // extends
    | False            // false
    | Finally          // finally
    | For              // for
    | Function         // function
    | If               // if
    | Import           // import
    | In               // in
    | Instanceof       // instanceof
    | New              // new
    | Null             // null
    | Return           // return
    | Super            // super
    | Switch           // switch
    | This             // this
    | Throw            // throw
    | True             // true
    | Try              // try
    | Typeof           // typeof
    | Var              // var
    | Void             // void
    | While            // while
    | With             // with

    /// 是否为赋值操作符 - 对应 Bun T.isAssign()
    /// Bun: @intFromEnum(self) >= t_ampersand_ampersand_equals and <= t_slash_equals
    public func isAssign(): Bool {
        match (this) {
            case AmpersandAmpersandEquals | AmpersandEquals | AsteriskAsteriskEquals |
                 AsteriskEquals | BarBarEquals | BarEquals | CaretEquals | Equals |
                 GreaterThanGreaterThanEquals | GreaterThanGreaterThanGreaterThanEquals |
                 LessThanLessThanEquals | MinusEquals | PercentEquals | PlusEquals |
                 QuestionQuestionEquals | SlashEquals => true
            case _ => false
        }
    }

    /// 是否为保留字 - 对应 Bun T.isReservedWord()
    /// Bun: @intFromEnum(self) >= t_break and <= t_with
    public func isReservedWord(): Bool {
        match (this) {
            case Break | Case | Catch | Class | Const | Continue | Debugger |
                 Default | Delete | Do | Else | Enum | Export | Extends |
                 False | Finally | For | Function | If | Import | In |
                 Instanceof | New | Null | Return | Super | Switch | This |
                 Throw | True | Try | Typeof | Var | Void | While | With => true
            case _ => false
        }
    }

    /// 是否为字符串类 token - 对应 Bun T.isString()
    public func isString(): Bool {
        match (this) {
            case NoSubstitutionTemplateLiteral | StringLiteral |
                 TemplateHead | TemplateMiddle | TemplateTail => true
            case _ => false
        }
    }

    /// 是否为 } 或 EOF - 对应 Bun T.isCloseBraceOrEOF()
    public func isCloseBraceOrEOF(): Bool {
        match (this) {
            case CloseBrace | EndOfFile => true
            case _ => false
        }
    }

    /// 是否为标识符或关键字 - 对应 Bun Lexer.isIdentifierOrKeyword()
    public func isIdentifierOrKeyword(): Bool {
        match (this) {
            case Identifier | EscapedKeyword | Break | Case | Catch | Class |
                 Const | Continue | Debugger | Default | Delete | Do | Else |
                 Enum | Export | Extends | False | Finally | For | Function |
                 If | Import | In | Instanceof | New | Null | Return | Super |
                 Switch | This | Throw | True | Try | Typeof | Var | Void |
                 While | With => true
            case _ => false
        }
    }

    /// Token 文本描述 - 对应 Bun tokenToString
    public func toString(): String {
        match (this) {
            case EndOfFile => "end of file"
            case CloseBrace => "}"
            case SyntaxError => "syntax error"
            case Hashbang => "#!"
            case NoSubstitutionTemplateLiteral => "template literal"
            case NumericLiteral => "numeric literal"
            case StringLiteral => "string literal"
            case BigIntegerLiteral => "bigint literal"
            case TemplateHead => "template head"
            case TemplateMiddle => "template middle"
            case TemplateTail => "template tail"
            case Ampersand => "&"
            case AmpersandAmpersand => "&&"
            case Asterisk => "*"
            case AsteriskAsterisk => "**"
            case At => "@"
            case Bar => "|"
            case BarBar => "||"
            case Caret => "^"
            case CloseBracket => "]"
            case CloseParen => ")"
            case Colon => ":"
            case Comma => ","
            case Dot => "."
            case DotDotDot => "..."
            case EqualsEquals => "=="
            case EqualsEqualsEquals => "==="
            case EqualsGreaterThan => "=>"
            case Exclamation => "!"
            case ExclamationEquals => "!="
            case ExclamationEqualsEquals => "!="
            case GreaterThan => ">"
            case GreaterThanEquals => ">="
            case GreaterThanGreaterThan => ">>"
            case GreaterThanGreaterThanGreaterThan => ">>>"
            case LessThan => "<"
            case LessThanEquals => "<="
            case LessThanLessThan => "<<"
            case Minus => "-"
            case MinusMinus => "--"
            case OpenBrace => "{"
            case OpenBracket => "["
            case OpenParen => "("
            case Percent => "%"
            case Plus => "+"
            case PlusPlus => "++"
            case Question => "?"
            case QuestionDot => "?."
            case QuestionQuestion => "??"
            case Semicolon => ";"
            case Slash => "/"
            case Tilde => "~"
            case AmpersandAmpersandEquals => "&&="
            case AmpersandEquals => "&="
            case AsteriskAsteriskEquals => "**="
            case AsteriskEquals => "*="
            case BarBarEquals => "||="
            case BarEquals => "|="
            case CaretEquals => "^="
            case Equals => "="
            case GreaterThanGreaterThanEquals => ">>="
            case GreaterThanGreaterThanGreaterThanEquals => ">>>="
            case LessThanLessThanEquals => "<<="
            case MinusEquals => "-="
            case PercentEquals => "%="
            case PlusEquals => "+="
            case QuestionQuestionEquals => "??="
            case SlashEquals => "/="
            case PrivateIdentifier => "private identifier"
            case Identifier => "identifier"
            case EscapedKeyword => "escaped keyword"
            case Break => "break"
            case Case => "case"
            case Catch => "catch"
            case Class => "class"
            case Const => "const"
            case Continue => "continue"
            case Debugger => "debugger"
            case Default => "default"
            case Delete => "delete"
            case Do => "do"
            case Else => "else"
            case Enum => "enum"
            case Export => "export"
            case Extends => "extends"
            case False => "false"
            case Finally => "finally"
            case For => "for"
            case Function => "function"
            case If => "if"
            case Import => "import"
            case In => "in"
            case Instanceof => "instanceof"
            case New => "new"
            case Null => "null"
            case Return => "return"
            case Super => "super"
            case Switch => "switch"
            case This => "this"
            case Throw => "throw"
            case True => "true"
            case Try => "try"
            case Typeof => "typeof"
            case Var => "var"
            case Void => "void"
            case While => "while"
            case With => "with"
        }
    }
}

// ============================================================================
// 关键字查找表 - 对应 Bun Keywords
// 严格翻译自: src/js_parser/lexer_tables.zig:152-189
//   pub const Keywords = ComptimeStringMap(T, .{ ... })
// ============================================================================

/// 关键字映射 - 对应 Bun Keywords
/// Bun 使用编译时字符串映射，仓颉使用 HashMap
public class Keywords {
    private static var map: HashMap<String, Token> = initMap()

    private static func initMap(): HashMap<String, Token> {
        let m = HashMap<String, Token>()
        m.put("break", Token.Break)
        m.put("case", Token.Case)
        m.put("catch", Token.Catch)
        m.put("class", Token.Class)
        m.put("const", Token.Const)
        m.put("continue", Token.Continue)
        m.put("debugger", Token.Debugger)
        m.put("default", Token.Default)
        m.put("delete", Token.Delete)
        m.put("do", Token.Do)
        m.put("else", Token.Else)
        m.put("enum", Token.Enum)
        m.put("export", Token.Export)
        m.put("extends", Token.Extends)
        m.put("false", Token.False)
        m.put("finally", Token.Finally)
        m.put("for", Token.For)
        m.put("function", Token.Function)
        m.put("if", Token.If)
        m.put("import", Token.Import)
        m.put("in", Token.In)
        m.put("instanceof", Token.Instanceof)
        m.put("new", Token.New)
        m.put("null", Token.Null)
        m.put("return", Token.Return)
        m.put("super", Token.Super)
        m.put("switch", Token.Switch)
        m.put("this", Token.This)
        m.put("throw", Token.Throw)
        m.put("true", Token.True)
        m.put("try", Token.Try)
        m.put("typeof", Token.Typeof)
        m.put("var", Token.Var)
        m.put("void", Token.Void)
        m.put("while", Token.While)
        m.put("with", Token.With)
        return m
    }

    /// 查找关键字 - 对应 Bun Keywords.get(str)
    /// 返回对应 Token，如果不是关键字则返回 None
    public static func get(keyword: String): ?Token {
        return map.get(keyword)
    }

    /// 是否为关键字
    public static func isKeyword(word: String): Bool {
        return map.contains(word)
    }
}

// ============================================================================
// 严格模式保留字 - 对应 Bun StrictModeReservedWords
// 严格翻译自: src/js_parser/lexer_tables.zig:191-201
//   pub const StrictModeReservedWords = ComptimeStringMap(void, .{
//       .{ "implements", {} }, .{ "interface", {} }, ...
//   })
// ============================================================================

/// 严格模式保留字集合 - 对应 Bun StrictModeReservedWords
public class StrictModeReservedWords {
    private static var set: HashSet<String> = initSet()

    private static func initSet(): HashSet<String> {
        let s = HashSet<String>()
        s.put("implements")
        s.put("interface")
        s.put("let")
        s.put("package")
        s.put("private")
        s.put("protected")
        s.put("public")
        s.put("static")
        s.put("yield")
        return s
    }

    public static func contains(word: String): Bool {
        return set.contains(word)
    }
}

// ============================================================================
// 严格模式保留字重映射 - 对应 Bun StrictModeReservedWordsRemap
// 严格翻译自: src/js_parser/lexer_tables.zig:203-213
// ============================================================================

/// 严格模式保留字重映射 - 对应 Bun StrictModeReservedWordsRemap
public class StrictModeReservedWordsRemap {
    private static var map: HashMap<String, String> = initMap()

    private static func initMap(): HashMap<String, String> {
        let m = HashMap<String, String>()
        m.put("implements", "_implements")
        m.put("interface", "_interface")
        m.put("let", "_let")
        m.put("package", "_package")
        m.put("private", "_private")
        m.put("protected", "_protected")
        m.put("public", "_public")
        m.put("static", "_static")
        m.put("yield", "_yield")
        return m
    }

    public static func get(word: String): ?String {
        return map.get(word)
    }
}

// ============================================================================
// 属性修饰符关键字 - 对应 Bun PropertyModifierKeyword
// 严格翻译自: src/js_parser/lexer_tables.zig:215-243
//   pub const PropertyModifierKeyword = enum { ... }
// ============================================================================

/// 属性修饰符关键字 - 对应 Bun PropertyModifierKeyword
public enum PropertyModifierKeyword {
    | Abstract   // abstract
    | Accessor   // accessor
    | Async      // async
    | Declare    // declare
    | Get        // get
    | Override   // override
    | Private    // private
    | Protected  // protected
    | Public     // public
    | Readonly   // readonly
    | Set        // set
    | Static     // static

    public func name(): String {
        match (this) {
            case Abstract => "abstract"
            case Accessor => "accessor"
            case Async => "async"
            case Declare => "declare"
            case Get => "get"
            case Override => "override"
            case Private => "private"
            case Protected => "protected"
            case Public => "public"
            case Readonly => "readonly"
            case Set => "set"
            case Static => "static"
        }
    }
}

/// 属性修饰符关键字查找表 - 对应 Bun PropertyModifierKeyword.List
public class PropertyModifierKeywords {
    private static var map: HashMap<String, PropertyModifierKeyword> = initMap()

    private static func initMap(): HashMap<String, PropertyModifierKeyword> {
        let m = HashMap<String, PropertyModifierKeyword>()
        m.put("abstract", PropertyModifierKeyword.Abstract)
        m.put("accessor", PropertyModifierKeyword.Accessor)
        m.put("async", PropertyModifierKeyword.Async)
        m.put("declare", PropertyModifierKeyword.Declare)
        m.put("get", PropertyModifierKeyword.Get)
        m.put("override", PropertyModifierKeyword.Override)
        m.put("private", PropertyModifierKeyword.Private)
        m.put("protected", PropertyModifierKeyword.Protected)
        m.put("public", PropertyModifierKeyword.Public)
        m.put("readonly", PropertyModifierKeyword.Readonly)
        m.put("set", PropertyModifierKeyword.Set)
        m.put("static", PropertyModifierKeyword.Static)
        return m
    }

    public static func get(keyword: String): ?PropertyModifierKeyword {
        return map.get(keyword)
    }
}

// ============================================================================
// TypeScript 语句关键字 - 对应 Bun TypescriptStmtKeyword
// 严格翻译自: src/js_parser/lexer_tables.zig
// ============================================================================

/// TypeScript 语句关键字 - 对应 Bun TypescriptStmtKeyword
public enum TypescriptStmtKeyword {
    | Abstract
    | Accessor
    | As
    | Asserts
    | Assert
    | Async
    | Await
    | Declare
    | From
    | Get
    | Global
    | Infer
    | Is
    | Keyof
    | Namespace
    | Override
    | Out
    | Readonly
    | Require
    | Satisfies
    | Set
    | Static
    | Type

    public func name(): String {
        match (this) {
            case Abstract => "abstract"
            case Accessor => "accessor"
            case As => "as"
            case Asserts => "asserts"
            case Assert => "assert"
            case Async => "async"
            case Await => "await"
            case Declare => "declare"
            case From => "from"
            case Get => "get"
            case Global => "global"
            case Infer => "infer"
            case Is => "is"
            case Keyof => "keyof"
            case Namespace => "namespace"
            case Override => "override"
            case Out => "out"
            case Readonly => "readonly"
            case Require => "require"
            case Satisfies => "satisfies"
            case Set => "set"
            case Static => "static"
            case Type => "type"
        }
    }
}

// ============================================================================
// TypeScript 可访问性修饰符 - 对应 Bun TypeScriptAccessibilityModifier
// ============================================================================

/// TypeScript 可访问性修饰符 - 对应 Bun TypeScriptAccessibilityModifier
public class TypeScriptAccessibilityModifiers {
    private static var set: HashSet<String> = initSet()

    private static func initSet(): HashSet<String> {
        let s = HashSet<String>()
        s.put("override")
        s.put("private")
        s.put("protected")
        s.put("public")
        s.put("readonly")
        return s
    }

    public static func contains(word: String): Bool {
        return set.contains(word)
    }
}
