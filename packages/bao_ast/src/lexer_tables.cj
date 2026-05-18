// 词法分析器查找表
// 严格翻译自: src/ast/lexer_tables.rs (1044行)
//   JS 词法分析器的 token 枚举、关键字查找表、属性修饰符查找表等。
//   包含:
//     - T: Token 枚举 (所有 JS token)
//     - keyword(): 快速关键字查找
//     - PropertyModifierKeyword: 属性修饰符关键字
//     - TypescriptStmtKeyword: TypeScript 语句关键字
//     - TOKEN_TO_STRING: Token 到字符串映射
//     - JSX_ENTITY: JSX 实体映射
//     - 标识符判断函数
package bao_ast

import bao_core.*

// ============================================================================
// T - Token 枚举
// 严格翻译自: lexer_tables.rs:7-133
//   pub enum T { TEndOfFile, TCloseBrace, TSyntaxError, ... }
// ============================================================================

/// JS Token 类型 - 对应 Bun T
public enum Token {
    | EndOfFile
    | CloseBrace

    | SyntaxError

    // #!/usr/bin/env node
    | Hashbang

    // 字面量
    | NoSubstitutionTemplateLiteral
    | NumericLiteral
    | StringLiteral
    | BigIntegerLiteral

    // 伪字面量
    | TemplateHead
    | TemplateMiddle
    | TemplateTail

    // 标点符号
    | Ampersand
    | AmpersandAmpersand
    | Asterisk
    | AsteriskAsterisk
    | At
    | Bar
    | BarBar
    | Caret
    | CloseBracket
    | CloseParen
    | Colon
    | Comma
    | Dot
    | DotDotDot
    | EqualsEquals
    | EqualsEqualsEquals
    | EqualsGreaterThan
    | Exclamation
    | ExclamationEquals
    | ExclamationEqualsEquals
    | GreaterThan
    | GreaterThanEquals
    | GreaterThanGreaterThan
    | GreaterThanGreaterThanGreaterThan
    | LessThan
    | LessThanEquals
    | LessThanLessThan
    | Minus
    | MinusMinus
    | OpenBrace
    | OpenBracket
    | OpenParen
    | Percent
    | Plus
    | PlusPlus
    | Question
    | QuestionDot
    | QuestionQuestion
    | Semicolon
    | Slash
    | Tilde

    // 赋值运算符
    | AmpersandAmpersandEquals
    | AmpersandEquals
    | AsteriskAsteriskEquals
    | AsteriskEquals
    | BarBarEquals
    | BarEquals
    | CaretEquals
    | Equals
    | GreaterThanGreaterThanEquals
    | GreaterThanGreaterThanGreaterThanEquals
    | LessThanLessThanEquals
    | MinusEquals
    | PercentEquals
    | PlusEquals
    | QuestionQuestionEquals
    | SlashEquals

    // 类私有字段和方法
    | PrivateIdentifier

    // 标识符
    | Identifier
    | EscapedKeyword

    // 保留字
    | Break
    | Case
    | Catch
    | Class
    | Const
    | Continue
    | Debugger
    | Default
    | Delete
    | Do
    | Else
    | Enum
    | Export
    | Extends
    | False
    | Finally
    | For
    | Function
    | If
    | Import
    | In
    | Instanceof
    | New
    | Null
    | Return
    | Super
    | Switch
    | This
    | Throw
    | True
    | Try
    | Typeof
    | Var
    | Void
    | While
    | With

    public func ordinal(): Int64 {
        match (this) {
            case EndOfFile => 0
            case CloseBrace => 1
            case SyntaxError => 2
            case Hashbang => 3
            case NoSubstitutionTemplateLiteral => 4
            case NumericLiteral => 5
            case StringLiteral => 6
            case BigIntegerLiteral => 7
            case TemplateHead => 8
            case TemplateMiddle => 9
            case TemplateTail => 10
            case Ampersand => 11
            case AmpersandAmpersand => 12
            case Asterisk => 13
            case AsteriskAsterisk => 14
            case At => 15
            case Bar => 16
            case BarBar => 17
            case Caret => 18
            case CloseBracket => 19
            case CloseParen => 20
            case Colon => 21
            case Comma => 22
            case Dot => 23
            case DotDotDot => 24
            case EqualsEquals => 25
            case EqualsEqualsEquals => 26
            case EqualsGreaterThan => 27
            case Exclamation => 28
            case ExclamationEquals => 29
            case ExclamationEqualsEquals => 30
            case GreaterThan => 31
            case GreaterThanEquals => 32
            case GreaterThanGreaterThan => 33
            case GreaterThanGreaterThanGreaterThan => 34
            case LessThan => 35
            case LessThanEquals => 36
            case LessThanLessThan => 37
            case Minus => 38
            case MinusMinus => 39
            case OpenBrace => 40
            case OpenBracket => 41
            case OpenParen => 42
            case Percent => 43
            case Plus => 44
            case PlusPlus => 45
            case Question => 46
            case QuestionDot => 47
            case QuestionQuestion => 48
            case Semicolon => 49
            case Slash => 50
            case Tilde => 51
            case AmpersandAmpersandEquals => 52
            case AmpersandEquals => 53
            case AsteriskAsteriskEquals => 54
            case AsteriskEquals => 55
            case BarBarEquals => 56
            case BarEquals => 57
            case CaretEquals => 58
            case Equals => 59
            case GreaterThanGreaterThanEquals => 60
            case GreaterThanGreaterThanGreaterThanEquals => 61
            case LessThanLessThanEquals => 62
            case MinusEquals => 63
            case PercentEquals => 64
            case PlusEquals => 65
            case QuestionQuestionEquals => 66
            case SlashEquals => 67
            case PrivateIdentifier => 68
            case Identifier => 69
            case EscapedKeyword => 70
            case Break => 71
            case Case => 72
            case Catch => 73
            case Class => 74
            case Const => 75
            case Continue => 76
            case Debugger => 77
            case Default => 78
            case Delete => 79
            case Do => 80
            case Else => 81
            case Enum => 82
            case Export => 83
            case Extends => 84
            case False => 85
            case Finally => 86
            case For => 87
            case Function => 88
            case If => 89
            case Import => 90
            case In => 91
            case Instanceof => 92
            case New => 93
            case Null => 94
            case Return => 95
            case Super => 96
            case Switch => 97
            case This => 98
            case Throw => 99
            case True => 100
            case Try => 101
            case Typeof => 102
            case Var => 103
            case Void => 104
            case While => 105
            case With => 106
        }
    }

    /// 是否为赋值运算符 - 对应 T.is_assign()
    public func isAssign(): Bool {
        ordinal() >= 52 && ordinal() <= 67
    }

    /// 是否为保留字 - 对应 T.is_reserved_word()
    public func isReservedWord(): Bool {
        ordinal() >= 71 && ordinal() <= 106
    }

    /// 是否为字符串类型 - 对应 T.is_string()
    public func isString(): Bool {
        match (this) {
            case NoSubstitutionTemplateLiteral | StringLiteral |
                 TemplateHead | TemplateMiddle | TemplateTail => true
            case _ => false
        }
    }

    /// 是否为 } 或 EOF - 对应 T.is_close_brace_or_eof()
    public func isCloseBraceOrEof(): Bool {
        ordinal() <= 1
    }

    public operator func ==(right: Token): Bool {
        ordinal() == right.ordinal()
    }

    public operator func !=(right: Token): Bool {
        !(this == right)
    }
}

// ============================================================================
// keyword() - 快速关键字查找
// 严格翻译自: lexer_tables.rs:214-289
//   pub fn keyword(s: &[u8]) -> Option<T>
//   按长度分桶，然后一次宽整数比较匹配关键字
// ============================================================================

/// 快速关键字查找 - 对应 Bun keyword()
/// 按字符串长度分桶，避免哈希计算。
/// 所有 JS 关键字长度在 2-10 之间。
public func keyword(s: String): ?Token {
    match (s.size) {
        case 2 =>
            match (s) {
                case "do" => Token.Do
                case "if" => Token.If
                case "in" => Token.In
                case _ => None
            }
        case 3 =>
            match (s) {
                case "for" => Token.For
                case "new" => Token.New
                case "try" => Token.Try
                case "var" => Token.Var
                case _ => None
            }
        case 4 =>
            match (s) {
                case "case" => Token.Case
                case "else" => Token.Else
                case "enum" => Token.Enum
                case "null" => Token.Null
                case "this" => Token.This
                case "true" => Token.True
                case "void" => Token.Void
                case "with" => Token.With
                case _ => None
            }
        case 5 =>
            match (s) {
                case "break" => Token.Break
                case "catch" => Token.Catch
                case "class" => Token.Class
                case "const" => Token.Const
                case "false" => Token.False
                case "super" => Token.Super
                case "throw" => Token.Throw
                case "while" => Token.While
                case _ => None
            }
        case 6 =>
            match (s) {
                case "delete" => Token.Delete
                case "export" => Token.Export
                case "import" => Token.Import
                case "return" => Token.Return
                case "switch" => Token.Switch
                case "typeof" => Token.Typeof
                case _ => None
            }
        case 7 =>
            match (s) {
                case "default" => Token.Default
                case "extends" => Token.Extends
                case "finally" => Token.Finally
                case _ => None
            }
        case 8 =>
            match (s) {
                case "continue" => Token.Continue
                case "debugger" => Token.Debugger
                case "function" => Token.Function
                case _ => None
            }
        case 10 =>
            match (s) {
                case "instanceof" => Token.Instanceof
                case _ => None
            }
        case _ => None
    }
}

// ============================================================================
// PropertyModifierKeyword - 属性修饰符关键字
// 严格翻译自: lexer_tables.rs:340-416
// ============================================================================

/// 属性修饰符关键字 - 对应 Bun PropertyModifierKeyword
/// 类属性/方法声明中的修饰符关键字
public enum PropertyModifierKeyword {
    | Abstract
    | Accessor
    | Async
    | Declare
    | Get
    | Override
    | Private
    | Protected
    | Public
    | Readonly
    | Set
    | Static

    public operator func ==(right: PropertyModifierKeyword): Bool {
        ordinal() == right.ordinal()
    }

    public func ordinal(): Int64 {
        match (this) {
            case Abstract => 0
            case Accessor => 1
            case Async => 2
            case Declare => 3
            case Get => 4
            case Override => 5
            case Private => 6
            case Protected => 7
            case Public => 8
            case Readonly => 9
            case Set => 10
            case Static => 11
        }
    }
}

/// 查找属性修饰符关键字 - 对应 PropertyModifierKeyword.find()
public func propertyModifierKeywordFind(s: String): ?PropertyModifierKeyword {
    match (s.size) {
        case 3 =>
            match (s) {
                case "get" => PropertyModifierKeyword.Get
                case "set" => PropertyModifierKeyword.Set
                case _ => None
            }
        case 5 =>
            match (s) {
                case "async" => PropertyModifierKeyword.Async
                case _ => None
            }
        case 6 =>
            match (s) {
                case "public" => PropertyModifierKeyword.Public
                case "static" => PropertyModifierKeyword.Static
                case _ => None
            }
        case 7 =>
            match (s) {
                case "declare" => PropertyModifierKeyword.Declare
                case "private" => PropertyModifierKeyword.Private
                case _ => None
            }
        case 8 =>
            match (s) {
                case "abstract" => PropertyModifierKeyword.Abstract
                case "accessor" => PropertyModifierKeyword.Accessor
                case "override" => PropertyModifierKeyword.Override
                case "readonly" => PropertyModifierKeyword.Readonly
                case _ => None
            }
        case 9 =>
            match (s) {
                case "protected" => PropertyModifierKeyword.Protected
                case _ => None
            }
        case _ => None
    }
}

// ============================================================================
// TypescriptStmtKeyword - TypeScript 语句关键字
// 严格翻译自: lexer_tables.rs:592-641
// ============================================================================

/// TypeScript 语句关键字 - 对应 Bun TypescriptStmtKeyword
public enum TypescriptStmtKeyword {
    | TsStmtType
    | TsStmtNamespace
    | TsStmtModule
    | TsStmtInterface
    | TsStmtAbstract
    | TsStmtGlobal
    | TsStmtDeclare

    public operator func ==(right: TypescriptStmtKeyword): Bool {
        ordinal() == right.ordinal()
    }

    public func ordinal(): Int64 {
        match (this) {
            case TsStmtType => 0
            case TsStmtNamespace => 1
            case TsStmtModule => 2
            case TsStmtInterface => 3
            case TsStmtAbstract => 4
            case TsStmtGlobal => 5
            case TsStmtDeclare => 6
        }
    }
}

/// 查找 TypeScript 语句关键字 - 对应 TypescriptStmtKeyword.from_bytes()
public func typescriptStmtKeyword(s: String): ?TypescriptStmtKeyword {
    match (s.size) {
        case 4 =>
            match (s) {
                case "type" => TypescriptStmtKeyword.TsStmtType
                case _ => None
            }
        case 6 =>
            match (s) {
                case "module" => TypescriptStmtKeyword.TsStmtModule
                case "global" => TypescriptStmtKeyword.TsStmtGlobal
                case _ => None
            }
        case 7 =>
            match (s) {
                case "declare" => TypescriptStmtKeyword.TsStmtDeclare
                case _ => None
            }
        case 8 =>
            match (s) {
                case "abstract" => TypescriptStmtKeyword.TsStmtAbstract
                case _ => None
            }
        case 9 =>
            match (s) {
                case "namespace" => TypescriptStmtKeyword.TsStmtNamespace
                case "interface" => TypescriptStmtKeyword.TsStmtInterface
                case _ => None
            }
        case _ => None
    }
}

// ============================================================================
// 严格模式保留字
// 严格翻译自: lexer_tables.rs 引用的 bun_core::lexer_tables
// ============================================================================

/// 严格模式保留字列表 - 对应 Bun STRICT_MODE_RESERVED_WORDS
public let STRICT_MODE_RESERVED_WORDS: Array<String> = [
    "implements", "interface", "let", "package", "private",
    "protected", "public", "static", "yield"
]

/// 是否为严格模式保留字 - 对应 is_strict_mode_reserved_word()
public func isStrictModeReservedWord(s: String): Bool {
    for (word in STRICT_MODE_RESERVED_WORDS) {
        if (s == word) {
            return true
        }
    }
    false
}

// ============================================================================
// 标识符判断
// 严格翻译自: lexer_tables.rs:980-1044
// ============================================================================

/// 是否为标识符起始字符 - 对应 is_identifier_start()
public func isIdentifierStart(codepoint: Int32): Bool {
    if (codepoint >= 0x61 && codepoint <= 0x7A) { return true }  // a-z
    if (codepoint >= 0x41 && codepoint <= 0x5A) { return true }  // A-Z
    if (codepoint == 0x24 || codepoint == 0x5F) { return true }  // $ _
    false
}

/// 是否为标识符延续字符 - 对应 is_identifier_continue()
public func isIdentifierContinue(codepoint: Int32): Bool {
    if (isIdentifierStart(codepoint)) { return true }
    if (codepoint >= 0x30 && codepoint <= 0x39) { return true }  // 0-9
    false
}

/// 是否为 Latin1 标识符 - 对应 is_latin1_identifier()
public func isLatin1Identifier(name: String): Bool {
    if (name.size == 0) { return false }
    val c0 = name[0]
    if (!((c0 >= 0x61 && c0 <= 0x7A) || (c0 >= 0x41 && c0 <= 0x5A) ||
          c0 == 0x24 || c0 == 0x5F)) {
        return false
    }
    for (i in 1..name.size) {
        val c = name[i]
        if (!((c >= 0x30 && c <= 0x39) || (c >= 0x61 && c <= 0x7A) ||
              (c >= 0x41 && c <= 0x5A) || c == 0x24 || c == 0x5F)) {
            return false
        }
    }
    true
}

// ============================================================================
// Token 到字符串映射
// 严格翻译自: lexer_tables.rs:464-590
//   pub static TOKEN_TO_STRING: TokenEnumType
// ============================================================================

/// Token 到字符串名称
public func tokenToString(token: Token): String {
    match (token) {
        case EndOfFile => "end of file"
        case SyntaxError => "syntax error"
        case Hashbang => "hashbang comment"
        case NoSubstitutionTemplateLiteral => "template literal"
        case NumericLiteral => "number"
        case StringLiteral => "string"
        case BigIntegerLiteral => "bigint"
        case TemplateHead | TemplateMiddle | TemplateTail => "template literal"
        case Ampersand => "\"&\""
        case AmpersandAmpersand => "\"&&\""
        case Asterisk => "\"*\""
        case AsteriskAsterisk => "\"**\""
        case At => "\"@\""
        case Bar => "\"|\""
        case BarBar => "\"||\""
        case Caret => "\"^\""
        case CloseBrace => "\"}\""
        case CloseBracket => "\"]\""
        case CloseParen => "\")\""
        case Colon => "\":\""
        case Comma => "\",\""
        case Dot => "\".\""
        case DotDotDot => "\"...\""
        case EqualsEquals => "\"==\""
        case EqualsEqualsEquals => "\"===\""
        case EqualsGreaterThan => "\"=>\""
        case Exclamation => "\"!\""
        case ExclamationEquals => "\"!=\""
        case ExclamationEqualsEquals => "\"!==\""
        case GreaterThan => "\">\""
        case GreaterThanEquals => "\">=\""
        case GreaterThanGreaterThan => "\">>\""
        case GreaterThanGreaterThanGreaterThan => "\">>>\""
        case LessThan => "\"<\""
        case LessThanEquals => "\"<=\""
        case LessThanLessThan => "\"<<\""
        case Minus => "\"-\""
        case MinusMinus => "\"--\""
        case OpenBrace => "\"{\""
        case OpenBracket => "\"[\""
        case OpenParen => "\"(\""
        case Percent => "\"%\""
        case Plus => "\"+\""
        case PlusPlus => "\"++\""
        case Question => "\"?\""
        case QuestionDot => "\"?.\""
        case QuestionQuestion => "\"??\""
        case Semicolon => "\";\""
        case Slash => "\"/\""
        case Tilde => "\"~\""
        case Equals => "\"=\""
        case PrivateIdentifier => "private identifier"
        case Identifier => "identifier"
        case EscapedKeyword => "escaped keyword"
        case _ => token.ordinal().toString()
    }
}
