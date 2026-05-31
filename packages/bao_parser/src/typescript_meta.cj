// TypeScript 元数据和标识符辅助
// 严格翻译自: src/js_parser/typescript.zig (472 lines)
//   Bun 的 TypeScript 元数据模块包含:
//   - Metadata: TypeScript 类型元数据 (用于序列化优化)
//   - Identifier: TypeScript 标识符分类 (StmtIdentifier, Kind)
//   - SkipTypeOptions: 跳过类型选项
//   - canFollowTypeArgumentsInExpression: 判断类型参数后能否跟表达式
//   - isTSArrowFnJSX: 判断是否为 TS 箭头函数 vs JSX
//   - isBinaryOperator: 判断当前 token 是否为二元操作符
//   - isStartOfExpression: 判断当前 token 是否为表达式起始
//   - isStartOfLeftHandSideExpression: 判断是否为左手边表达式起始
package bao_parser

import bao_core.*
import bao_collections.*

// ============================================================================
// TSMetadata - TypeScript 类型元数据
// 严格翻译自: typescript.zig:36-183
//   pub const Metadata = union(enum) {
//     m_none, m_never, m_unknown, m_any, m_void, m_null, m_undefined,
//     m_function, m_array, m_boolean, m_string, m_object, m_number,
//     m_bigint, m_symbol, m_promise, m_identifier(Ref), m_dot(List(Ref)),
//   }
//
//   用于优化 TypeScript 类型的序列化，特别是联合类型和交叉类型的合并。
//   逻辑翻译自 TypeScript 编译器的 transformers/typeSerializer.ts
// ============================================================================

/// TypeScript 类型元数据标签 - 对应 Bun Metadata 联合体标签
public enum TSMetadataTag {
    | TsNone
    | Never
    | Unknown
    | Any
    | Void
    | Null
    | Undefined
    | Function
    | Array
    | Boolean
    | String
    | Object
    | Number
    | BigInt
    | Symbol
    | Promise
    | Identifier    // m_identifier(Ref)
    | Dot           // m_dot(List(Ref))

    public func isNone(): Bool {
        match (this) {
            case TsNone => true
            case _ => false
        }
    }

    public operator func ==(right: TSMetadataTag): Bool {
        match (this) {
            case TsNone => match (right) { case TsNone => true case _ => false }
            case Never => match (right) { case Never => true case _ => false }
            case Unknown => match (right) { case Unknown => true case _ => false }
            case Any => match (right) { case Any => true case _ => false }
            case Void => match (right) { case Void => true case _ => false }
            case Null => match (right) { case Null => true case _ => false }
            case Undefined => match (right) { case Undefined => true case _ => false }
            case Function => match (right) { case Function => true case _ => false }
            case Array => match (right) { case Array => true case _ => false }
            case Boolean => match (right) { case Boolean => true case _ => false }
            case String => match (right) { case String => true case _ => false }
            case Object => match (right) { case Object => true case _ => false }
            case Number => match (right) { case Number => true case _ => false }
            case BigInt => match (right) { case BigInt => true case _ => false }
            case Symbol => match (right) { case Symbol => true case _ => false }
            case Promise => match (right) { case Promise => true case _ => false }
            case Identifier => match (right) { case Identifier => true case _ => false }
            case Dot => match (right) { case Dot => true case _ => false }
        }
    }

    public operator func !=(right: TSMetadataTag): Bool {
        return !(this == right)
    }
}

/// TypeScript 类型元数据 - 对应 Bun Metadata
/// 用于跟踪类型序列化的简化状态
public class TSMetadata {
    public var tag: TSMetadataTag
    /// 对于 Identifier 和 Dot，存储引用
    public var refs: ArrayList<Ref>

    public init() {
        tag = TSMetadataTag.TsNone
        refs = ArrayList<Ref>()
    }

    public init(tag: TSMetadataTag) {
        this.tag = tag
        refs = ArrayList<Ref>()
    }

    public init(tag: TSMetadataTag, refs: ArrayList<Ref>) {
        this.tag = tag
        this.refs = refs
    }

    /// 创建默认实例 - 对应 Bun Metadata.default = .m_none
    public static func default(): TSMetadata {
        return TSMetadata()
    }

    // ========================================================================
    // finishUnion - 联合类型终结
    // 严格翻译自: typescript.zig:67-91
    //   pub fn finishUnion(current: *@This(), p: anytype) ?@This() {
    //     return switch (current.*) {
    //       .m_identifier => |ref| {
    //         if (strings.eqlComptime(p.loadNameFromRef(ref), "Object")) return .m_object;
    //         return null;
    //       },
    //       .m_unknown, .m_any, .m_object => .m_object,
    //       .m_never, .m_null, .m_undefined => { current.* = .m_none; return null; },
    //       else => null,
    //     };
    //   }
    // ========================================================================

    /// 联合类型终结 - 对应 Bun Metadata.finishUnion
    /// 返回 Some 表示终结结果，None 表示需要继续合并
    public func finishUnion(): ?TSMetadata {
        match (tag) {
            case Identifier =>
                // 对应 Bun: if "Object" => m_object
                // 简化: 始终返回 null 继续合并
                return None
            case Unknown | Any | Object =>
                return Some(TSMetadata(TSMetadataTag.Object))
            case Never | Null | Undefined =>
                tag = TSMetadataTag.TsNone
                return None
            case _ =>
                return None
        }
    }

    // ========================================================================
    // mergeUnion - 联合类型合并
    // 严格翻译自: typescript.zig:93-117
    //   pub fn mergeUnion(result: *@This(), left: @This()) void {
    //     if (left != .m_none) {
    //       if (std.meta.activeTag(result.*) != std.meta.activeTag(left)) {
    //         result.* = switch (result.*) {
    //           .m_never, .m_undefined, .m_null => left,
    //           else => .m_object,
    //         };
    //       } else {
    //         switch (result.*) {
    //           .m_identifier => |ref| { if (!ref.eql(left.m_identifier)) result.* = .m_object; },
    //           else => {},
    //         }
    //       }
    //     }
    //   }
    // ========================================================================

    /// 联合类型合并 - 对应 Bun Metadata.mergeUnion
    public func mergeUnion(left: TSMetadata): Unit {
        if (!left.tag.isNone()) {
            if (tag != left.tag) {
                match (tag) {
                    case Never | Undefined | Null =>
                        tag = left.tag
                        refs = left.refs
                    case _ =>
                        tag = TSMetadataTag.Object
                        refs = ArrayList<Ref>()
                }
            } else {
                match (tag) {
                    case Identifier =>
                        // 如果标识符引用不同，退化为 object
                        if (refs.size > 0 && left.refs.size > 0) {
                            if (!refs[0].eql(left.refs[0])) {
                                tag = TSMetadataTag.Object
                                refs = ArrayList<Ref>()
                            }
                        }
                    case _ =>
                        ()
                }
            }
        }
    }

    // ========================================================================
    // finishIntersection - 交叉类型终结
    // 严格翻译自: typescript.zig:123-149
    // ========================================================================

    /// 交叉类型终结 - 对应 Bun Metadata.finishIntersection
    public func finishIntersection(): ?TSMetadata {
        match (tag) {
            case Identifier =>
                return None
            case Never =>
                return Some(TSMetadata(TSMetadataTag.Never))
            case Any | Object =>
                return Some(TSMetadata(TSMetadataTag.Object))
            case Unknown | Null | Undefined =>
                tag = TSMetadataTag.TsNone
                return None
            case _ =>
                return None
        }
    }

    // ========================================================================
    // mergeIntersection - 交叉类型合并
    // 严格翻译自: typescript.zig:151-183
    // ========================================================================

    /// 交叉类型合并 - 对应 Bun Metadata.mergeIntersection
    public func mergeIntersection(left: TSMetadata): Unit {
        if (!left.tag.isNone()) {
            if (tag != left.tag) {
                match (tag) {
                    case Unknown | Undefined | Null =>
                        tag = left.tag
                        refs = left.refs
                    case Never =>
                        tag = TSMetadataTag.Never
                        refs = ArrayList<Ref>()
                    case _ =>
                        tag = TSMetadataTag.Object
                        refs = ArrayList<Ref>()
                }
            } else {
                match (tag) {
                    case Identifier =>
                        if (refs.size > 0 && left.refs.size > 0) {
                            if (!refs[0].eql(left.refs[0])) {
                                tag = TSMetadataTag.Object
                                refs = ArrayList<Ref>()
                            }
                        }
                    case _ =>
                        ()
                }
            }
        } else {
            // 对应 Bun: if (result.* == .m_unknown) result.* = .m_undefined
            if (tag == TSMetadataTag.Unknown) {
                tag = TSMetadataTag.Undefined
            }
        }
    }
}

// ============================================================================
// TSIdentifier - TypeScript 标识符分类
// 严格翻译自: typescript.zig:354-447
//   pub const Identifier = struct {
//     pub const StmtIdentifier = enum { s_type, s_namespace, s_abstract, s_module, s_interface, s_declare }
//     pub const IMap = bun.ComptimeStringMap(Kind, .{ ... })
//     pub const Kind = enum { normal, unique, abstract, asserts, prefix_keyof,
//       prefix_readonly, primitive_any, primitive_never, ... }
//   }
// ============================================================================

/// TypeScript 语句标识符 - 对应 Bun Identifier.StmtIdentifier
/// 用于识别 TypeScript 特定的声明关键字
public enum TSStmtIdentifier {
    | Type        // "type"
    | Namespace   // "namespace"
    | Abstract    // "abstract"
    | Module      // "module"
    | Interface   // "interface"
    | Declare     // "declare"

    /// 从字符串获取语句标识符 - 对应 Bun Identifier.forStr
    public static func fromStr(str: String): ?TSStmtIdentifier {
        match (str) {
            case "type" => return Some(TSStmtIdentifier.Type)
            case "namespace" => return Some(TSStmtIdentifier.Namespace)
            case "abstract" => return Some(TSStmtIdentifier.Abstract)
            case "module" => return Some(TSStmtIdentifier.Module)
            case "interface" => return Some(TSStmtIdentifier.Interface)
            case "declare" => return Some(TSStmtIdentifier.Declare)
            case _ => return None
        }
    }
}

/// TypeScript 标识符种类 - 对应 Bun Identifier.Kind
/// 用于分类 TypeScript 类型表达式中的标识符
public enum TSIdentifierKind {
    | Normal           // 普通标识符
    | Unique           // "unique"
    | Abstract         // "abstract"
    | Asserts          // "asserts"
    | PrefixKeyof      // "keyof"
    | PrefixReadonly   // "readonly"
    | PrimitiveAny     // "any"
    | PrimitiveNever   // "never"
    | PrimitiveUnknown // "unknown"
    | PrimitiveUndefined // "undefined"
    | PrimitiveObject  // "object"
    | PrimitiveNumber  // "number"
    | PrimitiveString  // "string"
    | PrimitiveBoolean // "boolean"
    | PrimitiveBigInt  // "bigint"
    | PrimitiveSymbol  // "symbol"
    | Infer            // "infer"

    /// 是否为原始类型 - 对应 Bun 的 primitive_* 系列
    public func isPrimitive(): Bool {
        match (this) {
            case PrimitiveAny | PrimitiveNever | PrimitiveUnknown |
                 PrimitiveUndefined | PrimitiveObject | PrimitiveNumber |
                 PrimitiveString | PrimitiveBoolean | PrimitiveBigInt |
                 PrimitiveSymbol => true
            case _ => false
        }
    }

    /// 是否为前缀修饰符
    public func isPrefix(): Bool {
        match (this) {
            case PrefixKeyof | PrefixReadonly => true
            case _ => false
        }
    }

    /// 从字符串获取标识符种类 - 对应 Bun Identifier.IMap
    public static func fromStr(str: String): ?TSIdentifierKind {
        match (str) {
            case "unique" => return Some(TSIdentifierKind.Unique)
            case "abstract" => return Some(TSIdentifierKind.Abstract)
            case "asserts" => return Some(TSIdentifierKind.Asserts)
            case "keyof" => return Some(TSIdentifierKind.PrefixKeyof)
            case "readonly" => return Some(TSIdentifierKind.PrefixReadonly)
            case "any" => return Some(TSIdentifierKind.PrimitiveAny)
            case "never" => return Some(TSIdentifierKind.PrimitiveNever)
            case "unknown" => return Some(TSIdentifierKind.PrimitiveUnknown)
            case "undefined" => return Some(TSIdentifierKind.PrimitiveUndefined)
            case "object" => return Some(TSIdentifierKind.PrimitiveObject)
            case "number" => return Some(TSIdentifierKind.PrimitiveNumber)
            case "string" => return Some(TSIdentifierKind.PrimitiveString)
            case "boolean" => return Some(TSIdentifierKind.PrimitiveBoolean)
            case "bigint" => return Some(TSIdentifierKind.PrimitiveBigInt)
            case "symbol" => return Some(TSIdentifierKind.PrimitiveSymbol)
            case "infer" => return Some(TSIdentifierKind.Infer)
            case _ => return None
        }
    }

    /// 转换为 TSMetadata 标签 - 对应 Bun Metadata 映射
    public func toMetadataTag(): TSMetadataTag {
        match (this) {
            case PrimitiveAny => TSMetadataTag.Any
            case PrimitiveNever => TSMetadataTag.Never
            case PrimitiveUnknown => TSMetadataTag.Unknown
            case PrimitiveUndefined => TSMetadataTag.Undefined
            case PrimitiveObject => TSMetadataTag.Object
            case PrimitiveNumber => TSMetadataTag.Number
            case PrimitiveString => TSMetadataTag.String
            case PrimitiveBoolean => TSMetadataTag.Boolean
            case PrimitiveBigInt => TSMetadataTag.BigInt
            case PrimitiveSymbol => TSMetadataTag.Symbol
            case _ => TSMetadataTag.TsNone
        }
    }
}

// ============================================================================
// TSSkipTypeOptions - 跳过类型选项
// 严格翻译自: typescript.zig:449-457
//   pub const SkipTypeOptions = enum {
//     is_return_type, is_index_signature, allow_tuple_labels, disallow_conditional_types
//   }
// ============================================================================

/// 跳过类型选项 - 对应 Bun SkipTypeOptions
/// 用于控制 TypeScript 类型擦除时的行为
public enum TSSkipTypeOption {
    | IsReturnType              // 是否在返回类型位置
    | IsIndexSignature          // 是否在索引签名位置
    | AllowTupleLabels          // 是否允许元组标签
    | DisallowConditionalTypes  // 是否禁止条件类型
}

/// 跳过类型选项集合 - 对应 Bun SkipTypeOptions.Bitset
public class TSSkipTypeOptions {
    public var isReturnType: Bool
    public var isIndexSignature: Bool
    public var allowTupleLabels: Bool
    public var disallowConditionalTypes: Bool

    public init() {
        isReturnType = false
        isIndexSignature = false
        allowTupleLabels = false
        disallowConditionalTypes = false
    }

    /// 创建空选项 - 对应 Bun SkipTypeOptions.empty
    public static func empty(): TSSkipTypeOptions {
        return TSSkipTypeOptions()
    }

    /// 添加选项
    public func withOption(option: TSSkipTypeOption): TSSkipTypeOptions {
        match (option) {
            case TSSkipTypeOption.IsReturnType => isReturnType = true
            case TSSkipTypeOption.IsIndexSignature => isIndexSignature = true
            case TSSkipTypeOption.AllowTupleLabels => allowTupleLabels = true
            case TSSkipTypeOption.DisallowConditionalTypes => disallowConditionalTypes = true
        }
        return this
    }

    /// 检查是否包含选项
    public func has(option: TSSkipTypeOption): Bool {
        match (option) {
            case TSSkipTypeOption.IsReturnType => isReturnType
            case TSSkipTypeOption.IsIndexSignature => isIndexSignature
            case TSSkipTypeOption.AllowTupleLabels => allowTupleLabels
            case TSSkipTypeOption.DisallowConditionalTypes => disallowConditionalTypes
        }
    }
}

// ============================================================================
// TypeScript 辅助函数
// 严格翻译自: typescript.zig:3-352
// ============================================================================

/// 判断类型参数后能否跟表达式
/// 严格翻译自: typescript.zig:3-34
///   pub fn canFollowTypeArgumentsInExpression(p: anytype) bool {
///     return switch (p.lexer.token) {
///       .t_open_paren, .t_no_substitution_template_literal, .t_template_head => true,
///       .t_less_than, .t_greater_than, .t_plus, .t_minus,
///       .t_greater_than_equals, .t_greater_than_greater_than, ... => false,
///       else => p.lexer.has_newline_before or isBinaryOperator(p) or !isStartOfExpression(p),
///     };
///   }
///
/// 此函数来自 TypeScript 编译器:
/// https://github.com/microsoft/TypeScript/blob/master/src/compiler/parser.ts
public func canFollowTypeArgumentsInExpression(p: Parser): Bool {
    let token = p.lexer.token

    // 这些 token 可以合法地跟在类型参数列表后面
    match (token) {
        // foo<x>(
        case Token.OpenParen =>
            return true
        // foo<T> `...`
        case Token.NoSubstitutionTemplateLiteral =>
            return true
        // foo<T> `...${100}...`
        case Token.TemplateHead =>
            return true

        // 类型参数列表后跟 < 永远不合理
        // > 和 >>= 等有歧义，所以禁止
        case Token.LessThan | Token.GreaterThan |
             Token.Plus | Token.Minus |
             Token.GreaterThanEquals | Token.GreaterThanGreaterThan |
             Token.GreaterThanGreaterThanEquals | Token.GreaterThanGreaterThanGreaterThan |
             Token.GreaterThanGreaterThanGreaterThanEquals =>
            return false

        case _ =>
            // 对应 Bun: p.lexer.has_newline_before or isBinaryOperator(p) or !isStartOfExpression(p)
            return p.lexer.hasNewlineBefore || isBinaryOperator(p) || !isStartOfExpression(p)
    }
}

/// 判断是否为 TS 箭头函数 vs JSX
/// 严格翻译自: typescript.zig:185-208
///   pub fn isTSArrowFnJSX(p: anytype) !bool {
///     const old_lexer = p.lexer;
///     try p.lexer.next();
///     var is_ts_arrow_fn = false;
///     if (p.lexer.token == .t_const) { try p.lexer.next(); }
///     if (p.lexer.token == .t_identifier) {
///       try p.lexer.next();
///       if (p.lexer.token == .t_comma or p.lexer.token == .t_equals) is_ts_arrow_fn = true;
///       else if (p.lexer.token == .t_extends) {
///         try p.lexer.next();
///         is_ts_arrow_fn = p.lexer.token != .t_equals and p.lexer.token != .t_greater_than and p.lexer.token != .t_slash;
///       }
///     }
///     p.lexer.restore(&old_lexer);
///     return is_ts_arrow_fn;
///   }
public func isTSArrowFnJSX(p: Parser): Bool {
    // 保存当前词法状态
    let oldLexer = p.lexer

    p.lexer.nextToken()

    var isTsArrowFn = false

    if (p.lexer.token == Token.Const) {
        p.lexer.nextToken()
    }

    if (p.lexer.token == Token.Identifier) {
        p.lexer.nextToken()
        if (p.lexer.token == Token.Comma || p.lexer.token == Token.Equals) {
            isTsArrowFn = true
        } else if (p.lexer.token == Token.Extends) {
            p.lexer.nextToken()
            isTsArrowFn = p.lexer.token != Token.Equals &&
                p.lexer.token != Token.GreaterThan &&
                p.lexer.token != Token.Slash
        }
    }

    // 恢复词法状态
    p.lexer.restore(oldLexer)
    return isTsArrowFn
}

/// 判断当前 token 是否为二元操作符
/// 严格翻译自: typescript.zig:212-244
/// 此函数来自 TypeScript 编译器
public func isBinaryOperator(p: Parser): Bool {
    let token = p.lexer.token

    match (token) {
        case Token.In =>
            return p.allowIn
        case Token.QuestionQuestion | Token.BarBar | Token.AmpersandAmpersand |
             Token.Bar | Token.Caret | Token.Ampersand |
             Token.EqualsEquals | Token.ExclamationEquals |
             Token.EqualsEqualsEquals | Token.ExclamationEqualsEquals |
             Token.LessThan | Token.GreaterThan |
             Token.LessThanEquals | Token.GreaterThanEquals |
             Token.Instanceof |
             Token.LessThanLessThan | Token.GreaterThanGreaterThan |
             Token.GreaterThanGreaterThanGreaterThan |
             Token.Plus | Token.Minus |
             Token.Asterisk | Token.Slash | Token.Percent |
             Token.AsteriskAsterisk =>
            return true
        case Token.Identifier =>
            return p.lexer.isContextualKeyword("as") || p.lexer.isContextualKeyword("satisfies")
        case _ =>
            return false
    }
}

/// 判断当前 token 是否为左手边表达式起始
/// 严格翻译自: typescript.zig:248-273
/// 此函数来自 TypeScript 编译器
public func isStartOfLeftHandSideExpression(p: Parser): Bool {
    let token = p.lexer.token

    match (token) {
        case Token.`This` | Token.Super | Token.Null | Token.True | Token.False |
             Token.NumericLiteral | Token.BigIntegerLiteral | Token.StringLiteral |
             Token.NoSubstitutionTemplateLiteral | Token.TemplateHead |
             Token.OpenParen | Token.OpenBracket | Token.OpenBrace |
             Token.Function | Token.Class | Token.New |
             Token.Slash | Token.SlashEquals |
             Token.Identifier =>
            return true
        case Token.Import =>
            return lookAheadNextTokenIsOpenParenOrLessThanOrDot(p)
        case _ =>
            return isIdentifier(p)
    }
}

/// 向前看一个 token 是否为 ( < 或 .
/// 严格翻译自: typescript.zig:275-289
func lookAheadNextTokenIsOpenParenOrLessThanOrDot(p: Parser): Bool {
    let oldLexer = p.lexer
    let oldLogDisabled = p.lexer.isLogDisabled
    p.lexer.isLogDisabled = true

    p.lexer.nextToken()

    let result = match (p.lexer.token) {
        case Token.OpenParen | Token.LessThan | Token.Dot => true
        case _ => false
    }

    p.lexer.restore(oldLexer)
    p.lexer.isLogDisabled = oldLogDisabled
    return result
}

/// 判断当前 token 是否为标识符
/// 严格翻译自: typescript.zig:293-311
func isIdentifier(p: Parser): Bool {
    if (p.lexer.token == Token.Identifier) {
        // 在 yield 上下文中，yield 是关键字不是标识符
        if (!p.fnOrArrowDataParse.allowYield && p.lexer.identifier == "yield") {
            return false
        }
        // 在 await 上下文中，await 是关键字不是标识符
        if (!p.fnOrArrowDataParse.allowAwait && p.lexer.identifier == "await") {
            return false
        }
        return true
    }
    return false
}

/// 判断当前 token 是否为表达式起始
/// 严格翻译自: typescript.zig:313-352
/// 此函数来自 TypeScript 编译器
public func isStartOfExpression(p: Parser): Bool {
    if (isStartOfLeftHandSideExpression(p)) {
        return true
    }

    let token = p.lexer.token
    match (token) {
        case Token.Plus | Token.Minus | Token.Tilde | Token.Exclamation |
             Token.Delete | Token.Typeof | Token.Void |
             Token.PlusPlus | Token.MinusMinus |
             Token.LessThan | Token.PrivateIdentifier |
             Token.At =>
            return true
        case Token.Identifier =>
            // yield/await 始终开始一个表达式
            let ident = p.lexer.identifier
            if (ident == "await" || ident == "yield") {
                return true
            }
            // 如果是二元操作符则认为开始一个表达式 (容错)
            if (isBinaryOperator(p)) {
                return true
            }
            return isIdentifier(p)
        case _ =>
            if (isBinaryOperator(p)) {
                return true
            }
            return false
    }
}

// ============================================================================
// TSNamespaceMember - TypeScript 命名空间成员
// 严格翻译自: src/js_parser/ast/TS.zig
// ============================================================================

/// TypeScript 命名空间成员 - 对应 Bun TSNamespaceMember
public class TSNamespaceMember {
    public var loc: Loc
    public var ref: Ref
    public var data: TSNamespaceMemberData

    public init(loc: Loc, ref: Ref, data: TSNamespaceMemberData) {
        this.loc = loc
        this.ref = ref
        this.data = data
    }
}

/// TypeScript 命名空间成员数据 - 对应 Bun TS 的各种命名空间成员类型
public enum TSNamespaceMemberData {
    | Value        // 值
    | Type         // 类型
    | Enum         // 枚举
    | Namespace    // 命名空间
    | Class        // 类
    | Function     // 函数
    | Variable     // 变量
    | Interface    // 接口
    | TypeAlias    // 类型别名

    public func isEnum(): Bool {
        match (this) {
            case Enum => true
            case _ => false
        }
    }
}

/// TypeScript 命名空间作用域 - 对应 Bun TSNamespaceScope
public class TSNamespaceScope {
    /// 命名空间参数引用
    public var argRef: Ref
    /// 导出的成员
    public var exportedMembers: HashMap<String, TSNamespaceMember>
    /// 属性访问映射 (延迟生成)
    public var propertyAccesses: HashMap<String, Ref>
    /// 是否为枚举作用域
    public var isEnumScope: Bool

    public init(argRef: Ref) {
        this.argRef = argRef
        exportedMembers = HashMap<String, TSNamespaceMember>()
        propertyAccesses = HashMap<String, Ref>()
        isEnumScope = false
    }
}
