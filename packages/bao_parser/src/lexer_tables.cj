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
        kw.put("let", Token.Let)
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

// ============================================================================
// JSX 实体查找表 - 对应 Bun jsxEntity
// 严格翻译自: lexer_tables.zig:547-801
//   pub const jsxEntity = ComptimeStringMap(CodePoint, .{ ... })
// HTML 命名实体到 Unicode 码点的映射
// ============================================================================

/// JSX 实体查找表 - 对应 Bun jsxEntity ComptimeStringMap
/// 将 HTML 命名实体 (如 "amp", "lt", "gt") 映射到 Unicode 码点
public class JsxEntityMap {
    /// JSX 实体缓存
    private static var jsxEntityMap_: ?HashMap<String, Int64> = None

    /// 获取 JSX 实体映射
    public static func jsxEntityMap(): HashMap<String, Int64> {
        if (let Some(m) <- jsxEntityMap_) {
            return m
        }
        let m = HashMap<String, Int64>()
        // 严格翻译自 lexer_tables.zig:547-801
        // 常用实体
        m.put("amp", 0x0026)       // & Ampersand
        m.put("apos", 0x0027)      // ' Apostrophe
        m.put("gt", 0x003E)        // > Greater-than
        m.put("lt", 0x003C)        // < Less-than
        m.put("quot", 0x0022)      // " Quotation mark
        // 拉丁字母变体
        m.put("Aacute", 0x00C1)
        m.put("aacute", 0x00E1)
        m.put("Acirc", 0x00C2)
        m.put("acirc", 0x00E2)
        m.put("acute", 0x00B4)
        m.put("AElig", 0x00C6)
        m.put("aelig", 0x00E6)
        m.put("Agrave", 0x00C0)
        m.put("agrave", 0x00E0)
        m.put("Aring", 0x00C5)
        m.put("aring", 0x00E5)
        m.put("Atilde", 0x00C3)
        m.put("atilde", 0x00E3)
        m.put("Auml", 0x00C4)
        m.put("auml", 0x00E4)
        m.put("Ccedil", 0x00C7)
        m.put("ccedil", 0x00E7)
        m.put("Eacute", 0x00C9)
        m.put("eacute", 0x00E9)
        m.put("Ecirc", 0x00CA)
        m.put("ecirc", 0x00EA)
        m.put("Egrave", 0x00C8)
        m.put("egrave", 0x00E8)
        m.put("ETH", 0x00D0)
        m.put("eth", 0x00F0)
        m.put("Euml", 0x00CB)
        m.put("euml", 0x00EB)
        m.put("Iacute", 0x00CD)
        m.put("iacute", 0x00ED)
        m.put("Icirc", 0x00CE)
        m.put("icirc", 0x00EE)
        m.put("iexcl", 0x00A1)
        m.put("Igrave", 0x00CC)
        m.put("igrave", 0x00EC)
        m.put("Iuml", 0x00CF)
        m.put("iuml", 0x00EF)
        m.put("Ntilde", 0x00D1)
        m.put("ntilde", 0x00F1)
        m.put("Oacute", 0x00D3)
        m.put("oacute", 0x00F3)
        m.put("Ocirc", 0x00D4)
        m.put("ocirc", 0x00F4)
        m.put("Ograve", 0x00D2)
        m.put("ograve", 0x00F2)
        m.put("Oslash", 0x00D8)
        m.put("oslash", 0x00F8)
        m.put("Otilde", 0x00D5)
        m.put("otilde", 0x00F5)
        m.put("Ouml", 0x00D6)
        m.put("ouml", 0x00F6)
        m.put("Uacute", 0x00DA)
        m.put("uacute", 0x00FA)
        m.put("Ucirc", 0x00DB)
        m.put("ucirc", 0x00FB)
        m.put("Ugrave", 0x00D9)
        m.put("ugrave", 0x00F9)
        m.put("Uuml", 0x00DC)
        m.put("uuml", 0x00FC)
        m.put("Yacute", 0x00DD)
        m.put("yacute", 0x00FD)
        m.put("yuml", 0x00FF)
        m.put("Yuml", 0x0178)
        // 特殊符号
        m.put("brvbar", 0x00A6)
        m.put("cedil", 0x00B8)
        m.put("cent", 0x00A2)
        m.put("copy", 0x00A9)
        m.put("curren", 0x00A4)
        m.put("deg", 0x00B0)
        m.put("divide", 0x00F7)
        m.put("euro", 0x20AC)
        m.put("frac12", 0x00BD)
        m.put("frac14", 0x00BC)
        m.put("frac34", 0x00BE)
        m.put("iquest", 0x00BF)
        m.put("macr", 0x00AF)
        m.put("micro", 0x00B5)
        m.put("middot", 0x00B7)
        m.put("not", 0x00AC)
        m.put("para", 0x00B6)
        m.put("plusmn", 0x00B1)
        m.put("pound", 0x00A3)
        m.put("reg", 0x00AE)
        m.put("sect", 0x00A7)
        m.put("shy", 0x00AD)
        m.put("sup1", 0x00B9)
        m.put("sup2", 0x00B2)
        m.put("sup3", 0x00B3)
        m.put("szlig", 0x00DF)
        m.put("times", 0x00D7)
        m.put("trade", 0x2122)
        m.put("yen", 0x00A5)
        // 标点和排版
        m.put("bdquo", 0x201E)
        m.put("bull", 0x2022)
        m.put("circ", 0x02C6)
        m.put("dagger", 0x2020)
        m.put("Dagger", 0x2021)
        m.put("dblAgrave", 0x00C0)
        m.put("emsp", 0x2003)
        m.put("ensp", 0x2002)
        m.put("hellip", 0x2026)
        m.put("laquo", 0x00AB)
        m.put("ldquo", 0x201C)
        m.put("lrm", 0x200E)
        m.put("lsaquo", 0x2039)
        m.put("lsquo", 0x2018)
        m.put("mdash", 0x2014)
        m.put("ndash", 0x2013)
        m.put("nbsp", 0x00A0)
        m.put("oline", 0x203E)
        m.put("ordf", 0x00AA)
        m.put("ordm", 0x00BA)
        m.put("raquo", 0x00BB)
        m.put("rdquo", 0x201D)
        m.put("rlm", 0x200F)
        m.put("rsaquo", 0x203A)
        m.put("rsquo", 0x2019)
        m.put("sbquo", 0x201A)
        m.put("Scaron", 0x0160)
        m.put("scaron", 0x0161)
        m.put("thinsp", 0x2009)
        m.put("THORN", 0x00DE)
        m.put("thorn", 0x00FE)
        m.put("tilde", 0x02DC)
        m.put("zwnj", 0x200C)
        m.put("zwj", 0x200D)
        // 箭头
        m.put("darr", 0x2193)
        m.put("dArr", 0x21D3)
        m.put("harr", 0x2194)
        m.put("hArr", 0x21D4)
        m.put("larr", 0x2190)
        m.put("lArr", 0x21D0)
        m.put("rarr", 0x2192)
        m.put("rArr", 0x21D2)
        m.put("uarr", 0x2191)
        m.put("uArr", 0x21D1)
        m.put("crarr", 0x21B5)
        // 数学符号
        m.put("and", 0x2227)
        m.put("ang", 0x2220)
        m.put("asymp", 0x2248)
        m.put("cap", 0x2229)
        m.put("cong", 0x2245)
        m.put("cup", 0x222A)
        m.put("empty", 0x2205)
        m.put("equiv", 0x2261)
        m.put("exist", 0x2203)
        m.put("forall", 0x2200)
        m.put("ge", 0x2265)
        m.put("infin", 0x221E)
        m.put("int", 0x222B)
        m.put("isin", 0x2208)
        m.put("le", 0x2264)
        m.put("lowast", 0x2217)
        m.put("minus", 0x2212)
        m.put("nabla", 0x2207)
        m.put("ne", 0x2260)
        m.put("ni", 0x220B)
        m.put("notin", 0x2209)
        m.put("nsub", 0x2284)
        m.put("or", 0x2228)
        m.put("oplus", 0x2295)
        m.put("otimes", 0x2297)
        m.put("part", 0x2202)
        m.put("perp", 0x22A5)
        m.put("plusmn", 0x00B1)
        m.put("prod", 0x220F)
        m.put("prop", 0x221D)
        m.put("radic", 0x221A)
        m.put("sdot", 0x22C5)
        m.put("sim", 0x223C)
        m.put("sub", 0x2282)
        m.put("sube", 0x2286)
        m.put("sum", 0x2211)
        m.put("sup", 0x2283)
        m.put("supe", 0x2287)
        m.put("there4", 0x2234)
        m.put("frasl", 0x2044)
        m.put("lang", 0x2329)
        m.put("rang", 0x232A)
        m.put("lceil", 0x2308)
        m.put("lfloor", 0x230A)
        m.put("rceil", 0x2309)
        m.put("rfloor", 0x230B)
        m.put("permil", 0x2030)
        // 希腊字母
        m.put("Alpha", 0x0391)
        m.put("alpha", 0x03B1)
        m.put("Beta", 0x0392)
        m.put("beta", 0x03B2)
        m.put("Gamma", 0x0393)
        m.put("gamma", 0x03B3)
        m.put("Delta", 0x0394)
        m.put("delta", 0x03B4)
        m.put("Epsilon", 0x0395)
        m.put("epsilon", 0x03B5)
        m.put("Zeta", 0x0396)
        m.put("zeta", 0x03B6)
        m.put("Eta", 0x0397)
        m.put("eta", 0x03B7)
        m.put("Theta", 0x0398)
        m.put("theta", 0x03B8)
        m.put("thetasym", 0x03D1)
        m.put("Iota", 0x0399)
        m.put("iota", 0x03B9)
        m.put("Kappa", 0x039A)
        m.put("kappa", 0x03BA)
        m.put("Lambda", 0x039B)
        m.put("lambda", 0x03BB)
        m.put("Mu", 0x039C)
        m.put("mu", 0x03BC)
        m.put("Nu", 0x039D)
        m.put("nu", 0x03BD)
        m.put("Xi", 0x039E)
        m.put("xi", 0x03BE)
        m.put("Omicron", 0x039F)
        m.put("omicron", 0x03BF)
        m.put("Pi", 0x03A0)
        m.put("pi", 0x03C0)
        m.put("piv", 0x03D6)
        m.put("Rho", 0x03A1)
        m.put("rho", 0x03C1)
        m.put("Sigma", 0x03A3)
        m.put("sigma", 0x03C3)
        m.put("sigmaf", 0x03C2)
        m.put("Tau", 0x03A4)
        m.put("tau", 0x03C4)
        m.put("Upsilon", 0x03A5)
        m.put("upsilon", 0x03C5)
        m.put("upsih", 0x03D2)
        m.put("Phi", 0x03A6)
        m.put("phi", 0x03C6)
        m.put("Chi", 0x03A7)
        m.put("chi", 0x03C7)
        m.put("Psi", 0x03A8)
        m.put("psi", 0x03C8)
        m.put("Omega", 0x03A9)
        m.put("omega", 0x03C9)
        // 花色符号
        m.put("spades", 0x2660)
        m.put("clubs", 0x2663)
        m.put("hearts", 0x2665)
        m.put("diams", 0x2666)
        // 其他
        m.put("alefsym", 0x2135)
        m.put("image", 0x2111)
        m.put("lceil", 0x2308)
        m.put("loz", 0x25CA)
        m.put("OElig", 0x0152)
        m.put("oelig", 0x0153)
        m.put("prime", 0x2032)
        m.put("Prime", 0x2033)
        m.put("real", 0x211C)
        m.put("fnof", 0x0192)
        m.put("weierp", 0x2118)
        jsxEntityMap_ = Some(m)
        return m
    }

    /// 获取 JSX 实体码点 - 对应 Bun jsxEntity.get()
    /// 返回实体的 Unicode 码点，如果不存在返回 -1
    public static func getJsxEntity(entity: String): Int64 {
        let m = jsxEntityMap()
        match (m.get(entity)) {
            case Some(cp) => cp
            case None => -1
        }
    }
}
