// 严格翻译自: src/css/error.zig
package bao_css

import bao_core.*

// ============================================================================
// PrinterErrorKind - 打印器错误类型
// 严格翻译自: error.zig PrinterErrorKind
// ============================================================================

/// 打印器错误类型
/// 严格翻译自 PrinterErrorKind union(enum)
public enum PrinterErrorKind {
    | ambiguous_url_in_custom_property(String) // 自定义属性中的模糊相对 url()
    | fmt_error                                 // 底层格式化错误
    | invalid_composes_nesting                  // composes 不能用于嵌套规则
    | invalid_composes_selector                 // composes 需要简单类选择器
    | invalid_css_modules_pattern_in_grid       // CSS modules 模式必须以 [local] 结尾
    | no_import_records                         // 无导入记录

    public func toString(): String {
        match (this) {
            case ambiguous_url_in_custom_property(url) =>
                "Ambiguous relative URL '${url}' in custom property declaration"
            case fmt_error =>
                "Formatting error occurred"
            case invalid_composes_nesting =>
                "The 'composes' property cannot be used within nested rules"
            case invalid_composes_selector =>
                "The 'composes' property can only be used with a simple class selector"
            case invalid_css_modules_pattern_in_grid =>
                "CSS modules pattern must end with '[local]' when used in CSS grid"
            case no_import_records =>
                "No import records found"
        }
    }
}

// ============================================================================
// PrinterError - 带位置的打印器错误
// 严格翻译自: error.zig Err(PrinterErrorKind)
// ============================================================================

/// 带源码位置的打印器错误
/// 严格翻译自 Err(T) struct
public class PrinterError {
    public var kind: PrinterErrorKind
    public var loc: ?ErrorLocation

    public init(kind: PrinterErrorKind, loc: ?ErrorLocation) {
        this.kind = kind
        this.loc = loc
    }

    public func toString(): String {
        match (loc) {
            case Some(l) => "${kind.toString()} at ${l.toString()}"
            case None => kind.toString()
        }
    }
}

/// 创建一个 fmt 错误
/// 严格翻译自 fmtPrinterError()
public func fmtPrinterError(): PrinterError {
    return PrinterError(PrinterErrorKind.fmt_error, None)
}

// ============================================================================
// ParserError - 解析器错误
// 严格翻译自: error.zig ParserError
// ============================================================================

/// 解析器错误
/// 严格翻译自 ParserError union(enum)
public enum ParserError {
    | at_rule_body_invalid                                             // at 规则体无效
    | at_rule_prelude_invalid                                         // at 规则前导无效
    | at_rule_invalid(String)                                         // 未知或不支持的 at 规则
    | end_of_input                                                    // 输入意外结束
    | invalid_declaration                                             // 声明无效
    | invalid_media_query                                             // 媒体查询无效
    | invalid_nesting                                                 // 无效的 CSS 嵌套
    | deprecated_nest_rule                                           // @nest 规则已弃用
    | invalid_page_selector                                           // @page 选择器无效
    | invalid_value                                                   // 无效值
    | qualified_rule_invalid                                          // 无效的限定规则
    | selector_error(SelectorError)                                   // 选择器错误
    | unexpected_import_rule                                          // @import 规则位置错误
    | unexpected_namespace_rule                                       // @namespace 规则位置错误
    | unexpected_token(Token)                                         // 遇到意外的 token
    | maximum_nesting_depth                                           // 超过最大嵌套深度
    | unexpected_value(String, String)                                // (expected, received) 意外的值

    public func toString(): String {
        match (this) {
            case at_rule_body_invalid => "Invalid at-rule body"
            case at_rule_prelude_invalid => "Invalid at-rule prelude"
            case at_rule_invalid(name) => "Unknown at-rule @${name}"
            case end_of_input => "Unexpected end of input"
            case invalid_declaration => "Invalid declaration"
            case invalid_media_query => "Invalid media query"
            case invalid_nesting => "Invalid CSS nesting"
            case deprecated_nest_rule =>
                "The @nest rule is deprecated, use standard CSS nesting instead"
            case invalid_page_selector => "Invalid @page selector"
            case invalid_value => "Invalid value"
            case qualified_rule_invalid => "Invalid qualified rule"
            case selector_error(err) => "Invalid selector. ${err.toString()}"
            case unexpected_import_rule =>
                "@import rules must come before any other rules except @charset and @layer"
            case unexpected_namespace_rule =>
                "@namespace rules must come before any other rules except @charset, @import, and @layer"
            case unexpected_token(token) => "Unexpected token: ${token.toString()}"
            case maximum_nesting_depth => "Maximum CSS nesting depth exceeded"
            case unexpected_value(expected, received) =>
                "Expected ${expected}, received ${received}"
        }
    }
}

// ============================================================================
// BasicParseErrorKind - 基础解析错误类型
// 严格翻译自: error.zig BasicParseErrorKind
// ============================================================================

/// 基础解析错误类型
/// 严格翻译自 BasicParseErrorKind union(enum)
public enum BasicParseErrorKind {
    | unexpected_token(Token)    // 意外的 token
    | end_of_input               // 输入意外结束
    | at_rule_invalid(String)    // 无效的 @ 规则
    | at_rule_body_invalid       // @ 规则体无效
    | qualified_rule_invalid     // 限定规则无效

    public func toString(): String {
        match (this) {
            case unexpected_token(token) =>
                "unexpected token: ${token.toString()}"
            case end_of_input =>
                "unexpected end of input"
            case at_rule_invalid(rule) =>
                "invalid @ rule encountered: '@${rule}'"
            case at_rule_body_invalid =>
                "invalid @ body rule encountered"
            case qualified_rule_invalid =>
                "invalid qualified rule encountered"
        }
    }
}

// ============================================================================
// ErrorLocation - 错误位置
// 严格翻译自: error.zig ErrorLocation
// ============================================================================

/// 源码错误位置
/// 严格翻译自 ErrorLocation struct
public class ErrorLocation {
    /// 文件名
    public var filename: String

    /// 行号 (从 0 开始)
    public var line: UInt32

    /// 列号 (从 1 开始)
    public var column: UInt32

    public init(filename: String, line: UInt32, column: UInt32) {
        this.filename = filename
        this.line = line
        this.column = column
    }

    /// 使用新文件名创建副本
    /// 严格翻译自 ErrorLocation.withFilename()
    public func withFilename(new_filename: String): ErrorLocation {
        return ErrorLocation(new_filename, this.line, this.column)
    }

    public func toString(): String {
        "${filename}:${line}:${column}"
    }
}

// ============================================================================
// SelectorError - 选择器错误
// 严格翻译自: error.zig SelectorError
// ============================================================================

/// 选择器解析错误
/// 严格翻译自 SelectorError union(enum)
public enum SelectorError {
    | bad_value_in_attr(Token)                                    // 属性选择器中的无效值
    | class_needs_ident(Token)                                    // 类选择器缺少标识符
    | dangling_combinator                                         // 悬空组合器
    | empty_selector                                             // 空选择器
    | expected_bar_in_attr(Token)                                // 属性选择器中缺少 |
    | expected_namespace(String)                                  // 缺少命名空间
    | explicit_namespace_unexpected_token(Token)                  // 命名空间中遇到意外 token
    | invalid_pseudo_class_after_pseudo_element                   // 伪元素后的伪类无效
    | invalid_pseudo_class_after_webkit_scrollbar                 // -webkit-scrollbar 后的伪类无效
    | invalid_pseudo_class_before_webkit_scrollbar                // -webkit-scrollbar 状态在伪元素前
    | invalid_qual_name_in_attr(Token)                           // 属性选择器中的限定名无效
    | invalid_state                                              // 当前状态不允许此 token
    | missing_nesting_prefix                                     // 选择器必须以 & 开头
    | missing_nesting_selector                                   // 缺少 & 嵌套选择器
    | no_qualified_name_in_attribute_selector(Token)             // 属性选择器中缺少限定名
    | pseudo_element_expected_ident(Token)                       // 伪元素中缺少标识符
    | unexpected_ident(String)                                   // 意外的标识符
    | unexpected_token_in_attribute_selector(Token)              // 属性选择器中的意外 token
    | unsupported_pseudo_class_or_element(String)                // 不支持的伪类或伪元素
    | unexpected_selector_after_pseudo_element(Token)            // 伪元素后的意外选择器
    | ambiguous_css_module_class(String)                         // CSS module class 不支持

    public func toString(): String {
        match (this) {
            case dangling_combinator =>
                "Found a dangling combinator with no selector"
            case empty_selector =>
                "Empty selector is not allowed"
            case invalid_state =>
                "Token is not allowed in this state"
            case missing_nesting_prefix =>
                "Selector must start with the '&' nesting selector"
            case missing_nesting_selector =>
                "Missing '&' nesting selector"
            case invalid_pseudo_class_after_pseudo_element =>
                "Invalid pseudo-class after pseudo-element"
            case invalid_pseudo_class_after_webkit_scrollbar =>
                "Invalid pseudo-class after -webkit-scrollbar"
            case invalid_pseudo_class_before_webkit_scrollbar =>
                "-webkit-scrollbar state found before -webkit-scrollbar pseudo-element"
            case expected_namespace(str) =>
                "Expected namespace '${str}'"
            case unexpected_ident(str) =>
                "Unexpected identifier '${str}'"
            case unsupported_pseudo_class_or_element(str) =>
                "Unsupported pseudo-class or pseudo-element '${str}'"
            case bad_value_in_attr(tok) =>
                "Invalid value in attribute selector: ${tok.toString()}"
            case class_needs_ident(tok) =>
                "Expected identifier after '.' in class selector, found: ${tok.toString()}"
            case expected_bar_in_attr(tok) =>
                "Expected '|' in attribute selector, found: ${tok.toString()}"
            case explicit_namespace_unexpected_token(tok) =>
                "Unexpected token in namespace: ${tok.toString()}"
            case invalid_qual_name_in_attr(tok) =>
                "Invalid qualified name in attribute selector: ${tok.toString()}"
            case no_qualified_name_in_attribute_selector(tok) =>
                "Missing qualified name in attribute selector: ${tok.toString()}"
            case pseudo_element_expected_ident(tok) =>
                "Expected identifier in pseudo-element, found: ${tok.toString()}"
            case unexpected_token_in_attribute_selector(tok) =>
                "Unexpected token in attribute selector: ${tok.toString()}"
            case unexpected_selector_after_pseudo_element(tok) =>
                "Unexpected selector after pseudo-element: ${tok.toString()}"
            case ambiguous_css_module_class(name) =>
                "CSS module class: '${name}' is currently not supported."
        }
    }
}

// ============================================================================
// MinifyErrorKind - 压缩/变换错误
// 严格翻译自: error.zig MinifyErrorKind
// ============================================================================

/// 压缩/变换错误类型
/// 严格翻译自 MinifyErrorKind union(enum)
public enum MinifyErrorKind {
    | circular_custom_media(String)                          // 循环的 @custom-media 规则
    | custom_media_not_defined(String)                       // 引用了不存在的 custom media 规则
    | unsupported_custom_media_boolean_logic(Location)       // @custom-media 中不支持的布尔逻辑

    public func toString(): String {
        match (this) {
            case circular_custom_media(name) =>
                "Circular @custom-media rule: \"${name}\""
            case custom_media_not_defined(name) =>
                "Custom media rule \"${name}\" not defined"
            case unsupported_custom_media_boolean_logic(loc) =>
                "Unsupported boolean logic in custom media rule at line ${loc.line}, column ${loc.column}"
        }
    }
}

/// 带位置的压缩错误
/// 严格翻译自 MinifyErr / ErrorWithLocation(MinifyErrorKind)
public class MinifyError {
    public var kind: MinifyErrorKind
    public var loc: Location

    public init(kind: MinifyErrorKind, loc: Location) {
        this.kind = kind
        this.loc = loc
    }
}

// ============================================================================
// Location - 源码位置 (行号 + 列号)
// 严格翻译自: error.zig Location (from dependencies.zig)
// ============================================================================

/// 源码行/列位置
/// 严格翻译自 Location struct
public class Location {
    /// 行号，从 1 开始
    public var line: UInt32

    /// 列号，从 1 开始
    public var column: UInt32

    public init(line: UInt32, column: UInt32) {
        this.line = line
        this.column = column
    }
}

// ============================================================================
// BasicParseError - 基础解析错误 (带位置)
// 严格翻译自: error.zig BasicParseError
// ============================================================================

/// 基础解析错误
/// 严格翻译自 BasicParseError struct
public class BasicParseError {
    public var kind: BasicParseErrorKind
    public var location: SourceLocation

    public init(kind: BasicParseErrorKind, location: SourceLocation) {
        this.kind = kind
        this.location = location
    }
}

// ============================================================================
// ParseError - 带位置和类型的解析错误
// 严格翻译自: error.zig ParseError(T)
// ============================================================================

/// 带位置的解析错误
/// 严格翻译自 ParseError(ParserError) struct
public class ParseError {
    public var kind: ParserError
    public var location: SourceLocation

    public init(kind: ParserError, location: SourceLocation) {
        this.kind = kind
        this.location = location
    }
}
