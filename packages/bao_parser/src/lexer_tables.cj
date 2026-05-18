// 词法分析器查找表
// 严格翻译自: src/js_parser/lexer_tables.zig (809 lines)
//   Bun 的词法分析器查找表包含:
//   - Token 到字符串的映射 (tokenToString)
//   - 关键字到 Token 的映射 (Keywords)
//   - 严格模式保留字 (StrictModeReservedWords)
//   - 严格模式保留字重映射 (StrictModeReservedWordsRemap)
//   - 属性修饰符关键字 (PropertyModifierKeyword)
//   - TypeScript 可访问性修饰符 (TypeScriptAccessibilityModifier)
package bao_parser

import bao_collections.*

// ============================================================================
// LexerTables - 词法分析器查找表
// 严格翻译自: src/js_parser/lexer_tables.zig
//   pub const Keywords = ComptimeStringMap(T, .{ ... })
//   pub const StrictModeReservedWords = ComptimeStringMap(void, .{ ... })
//   pub const tokenToString = ...
// ============================================================================

/// 词法分析器查找表 - 对应 Bun lexer_tables 模块
/// 提供关键字查找、Token 字符串表示、保留字检查等静态方法
public class LexerTables {

    // ========================================================================
    // 关键字映射 - 对应 Bun Keywords
    // 严格翻译自: lexer_tables.zig:152-189
    //   pub const Keywords = ComptimeStringMap(T, .{ ... })
    // ========================================================================

    /// 关键字到 Token 的映射表
    private static var keywords_: ?HashMap<String, Token> = None

    /// 获取关键字映射
    public static func keywords(): HashMap<String, Token> {
        if (let Some(kw) <- keywords_) {
            return kw
        }
        let kw = HashMap<String, Token>()
        kw.put("break", Token.Break)
        kw.put("case", Token.Case)
        kw.put("catch", Token.Catch)
        kw.put("class", Token.Class)
        kw.put("const", Token.Const)
        kw.put("continue", Token.Continue)
        kw.put("debugger", Token.Debugger)
        kw.put("default", Token.Default)
        kw.put("delete", Token.Delete)
        kw.put("do", Token.Do)
        kw.put("else", Token.Else)
        kw.put("enum", Token.Enum)
        kw.put("export", Token.Export)
        kw.put("extends", Token.Extends)
        kw.put("false", Token.False)
        kw.put("finally", Token.Finally)
        kw.put("for", Token.For)
        kw.put("function", Token.Function)
        kw.put("if", Token.If)
        kw.put("import", Token.Import)
        kw.put("in", Token.In)
        kw.put("instanceof", Token.Instanceof)
        kw.put("new", Token.New)
        kw.put("null", Token.Null)
        kw.put("return", Token.Return)
        kw.put("super", Token.Super)
        kw.put("switch", Token.Switch)
        kw.put("this", Token.`This`)
        kw.put("throw", Token.Throw)
        kw.put("true", Token.True)
        kw.put("try", Token.Try)
        kw.put("typeof", Token.Typeof)
        kw.put("var", Token.Var)
        kw.put("void", Token.Void)
        kw.put("while", Token.While)
        kw.put("with", Token.With)
        keywords_ = Some(kw)
        return kw
    }

    // ========================================================================
    // Token 字符串表示 - 对应 Bun tokenToString
    // 严格翻译自: lexer_tables.zig:253-518
    //   pub const tokenToString = brk: { ... }
    // ========================================================================

    /// 获取 Token 的字符串表示
    /// 对应 Bun tokenToString
    public static func tokenToString(token: Token): String {
        match (token) {
            // 特殊
            case Token.EndOfFile => "end of file"
            case Token.CloseBrace => "\"}\""
            case Token.SyntaxError => "syntax error"
            case Token.Hashbang => "hashbang comment"

            // 字面量
            case Token.NoSubstitutionTemplateLiteral => "template literal"
            case Token.NumericLiteral => "number"
            case Token.StringLiteral => "string"
            case Token.BigIntegerLiteral => "bigint"

            // 伪字面量
            case Token.TemplateHead => "template literal"
            case Token.TemplateMiddle => "template literal"
            case Token.TemplateTail => "template literal"

            // 标点符号
            case Token.Ampersand => "\"&\""
            case Token.AmpersandAmpersand => "\"&&\""
            case Token.Asterisk => "\"*\""
            case Token.AsteriskAsterisk => "\"**\""
            case Token.At => "\"@\""
            case Token.Bar => "\"|\""
            case Token.BarBar => "\"||\""
            case Token.Caret => "\"^\""
            case Token.CloseBracket => "\"]\""
            case Token.CloseParen => "\")\""
            case Token.Colon => "\":\""
            case Token.Comma => "\",\""
            case Token.Dot => "\".\""
            case Token.DotDotDot => "\"...\""
            case Token.EqualsEquals => "\"==\""
            case Token.EqualsEqualsEquals => "\"===\""
            case Token.EqualsGreaterThan => "\"=>\""
            case Token.Exclamation => "\"!\""
            case Token.ExclamationEquals => "\"!=\""
            case Token.ExclamationEqualsEquals => "\"!==\""
            case Token.GreaterThan => "\">\""
            case Token.GreaterThanEquals => "\">=\""
            case Token.GreaterThanGreaterThan => "\">>\""
            case Token.GreaterThanGreaterThanGreaterThan => "\">>>\""
            case Token.LessThan => "\"<\""
            case Token.LessThanEquals => "\"<=\""
            case Token.LessThanLessThan => "\"<<\""
            case Token.Minus => "\"-\""
            case Token.MinusMinus => "\"--\""
            case Token.OpenBrace => "\"{\""
            case Token.OpenBracket => "\"[\""
            case Token.OpenParen => "\"(\""
            case Token.Percent => "\"%\""
            case Token.Plus => "\"+\""
            case Token.PlusPlus => "\"++\""
            case Token.Question => "\"?\""
            case Token.QuestionDot => "\"?.\""
            case Token.QuestionQuestion => "\"??\""
            case Token.Semicolon => "\";\""
            case Token.Slash => "\"/\""
            case Token.Tilde => "\"~\""

            // 赋值运算符
            case Token.AmpersandAmpersandEquals => "\"&&=\""
            case Token.AmpersandEquals => "\"&=\""
            case Token.AsteriskAsteriskEquals => "\"**=\""
            case Token.AsteriskEquals => "\"*=\""
            case Token.BarBarEquals => "\"||=\""
            case Token.BarEquals => "\"|=\""
            case Token.CaretEquals => "\"^=\""
            case Token.Equals => "\"=\""
            case Token.GreaterThanGreaterThanEquals => "\">>=\""
            case Token.GreaterThanGreaterThanGreaterThanEquals => "\">>>=\""
            case Token.LessThanLessThanEquals => "\"<<=\""
            case Token.MinusEquals => "\"-=\""
            case Token.PercentEquals => "\"%=\""
            case Token.PlusEquals => "\"+=\""
            case Token.QuestionQuestionEquals => "\"??=\""
            case Token.SlashEquals => "\"/=\""

            // 私有标识符
            case Token.PrivateIdentifier => "private identifier"

            // 标识符
            case Token.Identifier => "identifier"
            case Token.EscapedKeyword => "escaped keyword"

            // 保留字
            case Token.Break => "\"break\""
            case Token.Case => "\"case\""
            case Token.Catch => "\"catch\""
            case Token.Class => "\"class\""
            case Token.Const => "\"const\""
            case Token.Continue => "\"continue\""
            case Token.Debugger => "\"debugger\""
            case Token.Default => "\"default\""
            case Token.Delete => "\"delete\""
            case Token.Do => "\"do\""
            case Token.Else => "\"else\""
            case Token.Enum => "\"enum\""
            case Token.Export => "\"export\""
            case Token.Extends => "\"extends\""
            case Token.False => "\"false\""
            case Token.Finally => "\"finally\""
            case Token.For => "\"for\""
            case Token.Function => "\"function\""
            case Token.If => "\"if\""
            case Token.Import => "\"import\""
            case Token.In => "\"in\""
            case Token.Instanceof => "\"instanceof\""
            case Token.New => "\"new\""
            case Token.Null => "\"null\""
            case Token.Return => "\"return\""
            case Token.Super => "\"super\""
            case Token.Switch => "\"switch\""
            case Token.`This` => "\"this\""
            case Token.Throw => "\"throw\""
            case Token.True => "\"true\""
            case Token.Try => "\"try\""
            case Token.Typeof => "\"typeof\""
            case Token.Var => "\"var\""
            case Token.Void => "\"void\""
            case Token.While => "\"while\""
            case Token.With => "\"with\""
            case _ => "unknown token"
        }
    }

    // ========================================================================
    // 严格模式保留字 - 对应 Bun StrictModeReservedWords
    // 严格翻译自: lexer_tables.zig:191-201
    //   pub const StrictModeReservedWords = ComptimeStringMap(void, .{ ... })
    // ========================================================================

    /// 严格模式保留字集合
    private static var strictModeReservedWords_: ?HashMap<String, Bool> = None

    /// 检查是否为严格模式保留字
    public static func isStrictModeReservedWord(word: String): Bool {
        let set = strictModeReservedWords()
        return set.contains(word)
    }

    /// 获取严格模式保留字集合
    public static func strictModeReservedWords(): HashMap<String, Bool> {
        if (let Some(s) <- strictModeReservedWords_) {
            return s
        }
        let s = HashMap<String, Bool>()
        s.put("implements", true)
        s.put("interface", true)
        s.put("let", true)
        s.put("package", true)
        s.put("private", true)
        s.put("protected", true)
        s.put("public", true)
        s.put("static", true)
        s.put("yield", true)
        strictModeReservedWords_ = Some(s)
        return s
    }

    // ========================================================================
    // 严格模式保留字重映射 - 对应 Bun StrictModeReservedWordsRemap
    // 严格翻译自: lexer_tables.zig:203-213
    // ========================================================================

    /// 严格模式保留字重映射表
    /// 当在严格模式下遇到这些保留字时，将标识符重命名为带下划线前缀
    private static var strictModeRemap_: ?HashMap<String, String> = None

    /// 获取严格模式保留字的重映射名称
    public static func strictModeRemap(word: String): ?String {
        let map = strictModeRemapMap()
        if (map.contains(word)) {
            return map.get(word)
        }
        return None
    }

    /// 获取重映射表
    public static func strictModeRemapMap(): HashMap<String, String> {
        if (let Some(m) <- strictModeRemap_) {
            return m
        }
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
        strictModeRemap_ = Some(m)
        return m
    }

    // ========================================================================
    // 关键字查找 - 对应 Bun Keywords.get
    // ========================================================================

    /// 查找关键字对应的 Token
    /// 对应 Bun: Keywords.get(name)
    public static func lookupKeyword(name: String): ?Token {
        let kw = keywords()
        if (kw.contains(name)) {
            return kw.get(name)
        }
        return None
    }

    // ========================================================================
    // Token 分类方法 - 对应 Bun T 的方法
    // 严格翻译自: lexer_tables.zig:128-150
    //   pub fn isAssign(self: T) bool
    //   pub fn isReservedWord(self: T) bool
    //   pub fn isString(self: T) bool
    //   pub fn isCloseBraceOrEOF(self: T) bool
    // ========================================================================

    /// 判断是否为赋值运算符
    /// 对应 Bun T.isAssign()
    /// 赋值运算符从 AmpersandAmpersandEquals 到 SlashEquals
    public static func isAssign(token: Token): Bool {
        match (token) {
            case Token.AmpersandAmpersandEquals |
                 Token.AmpersandEquals |
                 Token.AsteriskAsteriskEquals |
                 Token.AsteriskEquals |
                 Token.BarBarEquals |
                 Token.BarEquals |
                 Token.CaretEquals |
                 Token.Equals |
                 Token.GreaterThanGreaterThanEquals |
                 Token.GreaterThanGreaterThanGreaterThanEquals |
                 Token.LessThanLessThanEquals |
                 Token.MinusEquals |
                 Token.PercentEquals |
                 Token.PlusEquals |
                 Token.QuestionQuestionEquals |
                 Token.SlashEquals => true
            case _ => false
        }
    }

    /// 判断是否为保留字
    /// 对应 Bun T.isReservedWord()
    public static func isReservedWord(token: Token): Bool {
        match (token) {
            case Token.Break | Token.Case | Token.Catch | Token.Class |
                 Token.Const | Token.Continue | Token.Debugger | Token.Default |
                 Token.Delete | Token.Do | Token.Else | Token.Enum |
                 Token.Export | Token.Extends | Token.False | Token.Finally |
                 Token.For | Token.Function | Token.If | Token.Import |
                 Token.In | Token.Instanceof | Token.New | Token.Null |
                 Token.Return | Token.Super | Token.Switch | Token.`This` |
                 Token.Throw | Token.True | Token.Try | Token.Typeof |
                 Token.Var | Token.Void | Token.While | Token.With => true
            case _ => false
        }
    }

    /// 判断是否为字符串类 Token
    /// 对应 Bun T.isString()
    public static func isString(token: Token): Bool {
        match (token) {
            case Token.NoSubstitutionTemplateLiteral |
                 Token.StringLiteral |
                 Token.TemplateHead |
                 Token.TemplateMiddle |
                 Token.TemplateTail => true
            case _ => false
        }
    }

    /// 判断是否为 } 或 EOF
    /// 对应 Bun T.isCloseBraceOrEOF()
    public static func isCloseBraceOrEOF(token: Token): Bool {
        match (token) {
            case Token.EndOfFile | Token.CloseBrace => true
            case _ => false
        }
    }
}

// ============================================================================
// PropertyModifierKeyword - 属性修饰符关键字
// 严格翻译自: lexer_tables.zig:215-243
//   pub const PropertyModifierKeyword = enum { ... }
// ============================================================================

/// 属性修饰符关键字 - 对应 Bun PropertyModifierKeyword
/// 用于 TypeScript 类属性的修饰符解析
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

    /// 从字符串查找属性修饰符关键字
    /// 对应 Bun PropertyModifierKeyword.List.get()
    public static func lookup(name: String): ?PropertyModifierKeyword {
        match (name) {
            case "abstract" => Some(Abstract)
            case "accessor" => Some(Accessor)
            case "async" => Some(Async)
            case "declare" => Some(Declare)
            case "get" => Some(Get)
            case "override" => Some(Override)
            case "private" => Some(Private)
            case "protected" => Some(Protected)
            case "public" => Some(Public)
            case "readonly" => Some(Readonly)
            case "set" => Some(Set)
            case "static" => Some(Static)
            case _ => None
        }
    }

    /// 所有属性修饰符关键字列表
    public static func allKeywords(): ArrayList<String> {
        let list = ArrayList<String>()
        list.append("abstract")
        list.append("accessor")
        list.append("async")
        list.append("declare")
        list.append("get")
        list.append("override")
        list.append("private")
        list.append("protected")
        list.append("public")
        list.append("readonly")
        list.append("set")
        list.append("static")
        return list
    }
}

// ============================================================================
// TypeScriptAccessibilityModifier - TypeScript 可访问性修饰符
// 严格翻译自: lexer_tables.zig:245-251
//   pub const TypeScriptAccessibilityModifier = ComptimeStringMap(void, .{ ... })
// ============================================================================

/// TypeScript 可访问性修饰符检查 - 对应 Bun TypeScriptAccessibilityModifier
/// 检查给定的名称是否为 TypeScript 的可访问性修饰符
public class TypeScriptAccessibilityModifier {

    /// 可访问性修饰符集合
    private static var modifiers_: ?HashMap<String, Bool> = None

    /// 检查是否为可访问性修饰符
    public static func isModifier(name: String): Bool {
        let m = modifiers()
        return m.contains(name)
    }

    /// 获取修饰符集合
    public static func modifiers(): HashMap<String, Bool> {
        if (let Some(m) <- modifiers_) {
            return m
        }
        let m = HashMap<String, Bool>()
        m.put("override", true)
        m.put("private", true)
        m.put("protected", true)
        m.put("public", true)
        m.put("readonly", true)
        modifiers_ = Some(m)
        return m
    }
}
