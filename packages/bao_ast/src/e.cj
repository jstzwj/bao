// 严格翻译自: src/ast/e.zig
// E 是 Expression 的联合体类型定义: E.Array, E.String, E.Object, E.Call, etc.
package bao_ast

import bao_core.*
import bao_collections.*
import bao_parser.*

// ============================================================================
// E 命名空间中的所有表达式数据类型
// 严格翻译自: src/ast/e.zig:1-1471
// Bun 使用 union enum, 仓颉用独立类表示
// ============================================================================

/// 调用解包标志 - 对应 Bun E.CallUnwrap
/// Bun: pub const CallUnwrap = enum(u2) { never, if_unused, if_unused_and_toString_safe }
public enum CallUnwrap {
    | Never
    | IfUnused
    | IfUnusedAndToStringSafe

    public operator func ==(right: CallUnwrap): Bool {
        return ordinal() == right.ordinal()
    }

    public operator func !=(right: CallUnwrap): Bool {
        return !(this == right)
    }

    public func ordinal(): Int64 {
        match (this) {
            case Never => 0
            case IfUnused => 1
            case IfUnusedAndToStringSafe => 2
        }
    }

    public func name(): String {
        match (this) {
            case Never => "never"
            case IfUnused => "if_unused"
            case IfUnusedAndToStringSafe => "if_unused_and_toString_safe"
        }
    }
}

/// 可选链类型 - 对应 Bun OptionalChain
/// Bun: pub const OptionalChain = enum { start, inner, nullish_start, nullish_inner }
public enum OptionalChain {
    | Start          // ?. 开始
    | Inner          // 后续 ?.
    | NullishStart   // ???. 开始
    | NullishInner   // 后续 ???.

    public operator func ==(right: OptionalChain): Bool {
        return ordinal() == right.ordinal()
    }

    public operator func !=(right: OptionalChain): Bool {
        return !(this == right)
    }

    public func ordinal(): Int64 {
        match (this) {
            case Start => 0
            case Inner => 1
            case NullishStart => 2
            case NullishInner => 3
        }
    }

    public func name(): String {
        match (this) {
            case Start => "start"
            case Inner => "inner"
            case NullishStart => "nullish_start"
            case NullishInner => "nullish_inner"
        }
    }
}

/// 一元运算标志 - 对应 Bun E.Unary.Flags
/// Bun: packed struct(u8) { was_originally_typeof_identifier, was_originally_delete_of_identifier_or_property_access }
private func sameExprTag(left: ExprTag, right: ExprTag): Bool {
    return left.name() == right.name()
}

private func stringLessThan(left: String, right: String): Bool {
    var i = Int64(0)
    while (i < left.size && i < right.size) {
        let l = UInt32(left[i])
        let r = UInt32(right[i])
        if (l != r) {
            return l < r
        }
        i += Int64(1)
    }
    return left.size < right.size
}

private func stringValueOrEmpty(node: ?ASTNode): String {
    if (let Some(n) <- node) {
        if (let Some(s) <- n.stringValue()) {
            return s
        }
    }
    return ""
}

private func sameOptionalChain(left: ?OptionalChain, right: ?OptionalChain): Bool {
    match (left) {
        case Some(l) =>
            match (right) {
                case Some(r) => l == r
                case None => false
            }
        case None =>
            match (right) {
                case Some(_) => false
                case None => true
            }
    }
}

public class UnaryFlags {
    public var wasOriginallyTypeofIdentifier: Bool
    public var wasOriginallyDeleteOfIdentifierOrPropertyAccess: Bool

    public init() {
        wasOriginallyTypeofIdentifier = false
        wasOriginallyDeleteOfIdentifierOrPropertyAccess = false
    }
}

/// E.NameOfSymbol - 对应 Bun E.NameOfSymbol
/// Bun: 内部属性名, 可以被 mangled
public class ENameOfSymbol {
    public var ref: Ref
    public var hasPropertyKeyComment: Bool

    public init(ref: Ref, hasPropertyKeyComment: Bool) {
        this.ref = ref
        this.hasPropertyKeyComment = hasPropertyKeyComment
    }

    public init(ref: Ref) {
        this.ref = ref
        this.hasPropertyKeyComment = false
    }
}

/// E.Array - 对应 Bun E.Array
/// Bun: pub const Array = struct { items: ExprNodeList, comma_after_spread, is_single_line, ... }
public class EArray {
    public var items: ArrayList<ASTNode>
    public var commaAfterSpread: ?ASTLoc
    public var isSingleLine: Bool
    public var isParenthesized: Bool
    public var wasOriginallyMacro: Bool
    public var closeBracketLoc: ASTLoc

    public init() {
        items = ArrayList<ASTNode>()
        commaAfterSpread = None
        isSingleLine = false
        isParenthesized = false
        wasOriginallyMacro = false
        closeBracketLoc = ASTLoc.EMPTY
    }

    /// 添加元素 - 对应 Bun E.Array.push()
    public func push(item: ASTNode): Unit {
        items.append(item)
    }

    /// 内联展开数组字面量中的 spread - 对应 Bun E.Array.inlineSpreadOfArrayLiterals()
    public func inlineSpreadOfArrayLiterals(estimatedCount: Int64): ArrayList<ASTNode> {
        let out = ArrayList<ASTNode>()
        for (item in items) {
            if (sameExprTag(item.tag, ExprTag.Spread)) {
                // 展开的值如果是数组, 则内联
                let spreadValue: ?ASTNode = if (item.children.size > Int64(0)) { Some(item.children[Int64(0)]) } else { Option<ASTNode>.None }
                if (let Some(innerArray) <- spreadValue) {
                    if (!sameExprTag(innerArray.tag, ExprTag.Array)) {
                        out.append(item)
                        continue
                    }
                    for (innerItem in innerArray.children) {
                        if (sameExprTag(innerItem.tag, ExprTag.Missing)) {
                            out.append(ASTNode(ExprTag.Undefined, innerItem.loc))
                        } else {
                            out.append(innerItem)
                        }
                    }
                    continue
                }
            }
            out.append(item)
        }
        return out
    }

    /// 按字母排序字符串 - 对应 Bun E.Array.alphabetizeStrings()
    public func alphabetizeStrings(): Unit {
        var changed = true
        while (changed) {
            changed = false
            var i = Int64(1)
            while (i < items.size) {
                let sa = items[i - Int64(1)].stringValue()
                let sb = items[i].stringValue()
                if (let Some(va) <- sa) {
                    if (let Some(vb) <- sb) {
                        if (stringLessThan(vb, va)) {
                            let tmp = items[i - Int64(1)]
                            items[i - Int64(1)] = items[i]
                            items[i] = tmp
                            changed = true
                        }
                    }
                }
                i += Int64(1)
            }
        }
    }
}

/// E.Unary - 一元表达式
public class EUnary {
    public var op: OpCode
    public var value: ASTNode
    public var flags: UnaryFlags

    public init(op: OpCode, value: ASTNode, flags: UnaryFlags) {
        this.op = op
        this.value = value
        this.flags = flags
    }

    public init(op: OpCode, value: ASTNode) {
        this.op = op
        this.value = value
        this.flags = UnaryFlags()
    }
}

/// E.Binary - 二元表达式
public class EBinary {
    public var left: ASTNode
    public var right: ASTNode
    public var op: OpCode

    public init(left: ASTNode, right: ASTNode, op: OpCode) {
        this.left = left
        this.right = right
        this.op = op
    }
}

/// E.Boolean - 布尔字面量
public class EBoolean {
    public var value: Bool

    public init(value: Bool) {
        this.value = value
    }
}

/// E.Super - super 关键字
public class ESuper {
    public init() {}
}

/// E.Null - null 字面量
public class ENull {
    public init() {}
}

/// E.This - this 关键字
public class EThis {
    public init() {}
}

/// E.Undefined - undefined 字面量
public class EUndefined {
    public init() {}
}

/// E.New - new 表达式
public class ENew {
    public var target: ASTNode
    public var args: ArrayList<ASTNode>
    public var canBeUnwrappedIfUnused: CallUnwrap
    public var closeParensLoc: ASTLoc

    public init(target: ASTNode, args: ArrayList<ASTNode>) {
        this.target = target
        this.args = args
        this.canBeUnwrappedIfUnused = CallUnwrap.Never
        this.closeParensLoc = ASTLoc.EMPTY
    }
}

/// E.NewTarget - new.target
public class ENewTarget {
    public var range: ASTRange

    public init(range: ASTRange) {
        this.range = range
    }
}

/// E.ImportMeta - import.meta
public class EImportMeta {
    public init() {}
}

/// E.ImportMetaMain - import.meta.main
public class EImportMetaMain {
    public var inverted: Bool

    public init(inverted: Bool) {
        this.inverted = inverted
    }
}

/// E.Special - 特殊表达式
public enum SpecialKind {
    | ModuleExports
    | HotEnabled
    | HotDisabled
    | HotData
    | HotAccept
    | HotAcceptVisited
    | ResolvedSpecifierString

    public func name(): String {
        match (this) {
            case ModuleExports => "module_exports"
            case HotEnabled => "hot_enabled"
            case HotDisabled => "hot_disabled"
            case HotData => "hot_data"
            case HotAccept => "hot_accept"
            case HotAcceptVisited => "hot_accept_visited"
            case ResolvedSpecifierString => "resolved_specifier_string"
        }
    }
}

public class ESpecial {
    public var kind: SpecialKind
    public var importRecordIndex: UInt32

    public init(kind: SpecialKind, importRecordIndex: UInt32) {
        this.kind = kind
        this.importRecordIndex = importRecordIndex
    }
}

/// E.Call - 函数调用表达式
public class ECall {
    public var target: ASTNode
    public var args: ArrayList<ASTNode>
    public var optionalChain: ?OptionalChain
    public var isDirectEval: Bool
    public var closeParenLoc: ASTLoc
    public var canBeUnwrappedIfUnused: CallUnwrap
    public var wasJsxElement: Bool

    public init(target: ASTNode, args: ArrayList<ASTNode>) {
        this.target = target
        this.args = args
        this.optionalChain = None
        this.isDirectEval = false
        this.closeParenLoc = ASTLoc.EMPTY
        this.canBeUnwrappedIfUnused = CallUnwrap.Never
        this.wasJsxElement = false
    }

    /// 比较标志是否相同 - 对应 Bun E.Call.hasSameFlagsAs()
    public func hasSameFlagsAs(other: ECall): Bool {
        return sameOptionalChain(optionalChain, other.optionalChain) &&
               isDirectEval == other.isDirectEval &&
               canBeUnwrappedIfUnused == other.canBeUnwrappedIfUnused
    }
}

/// E.Dot - 属性访问表达式 (a.b)
public class EDot {
    public var target: ASTNode
    public var name: String
    public var nameLoc: ASTLoc
    public var optionalChain: ?OptionalChain
    public var canBeRemovedIfUnused: Bool
    public var callCanBeUnwrappedIfUnused: CallUnwrap

    public init(target: ASTNode, name: String, nameLoc: ASTLoc) {
        this.target = target
        this.name = name
        this.nameLoc = nameLoc
        this.optionalChain = None
        this.canBeRemovedIfUnused = false
        this.callCanBeUnwrappedIfUnused = CallUnwrap.Never
    }

    public func hasSameFlagsAs(other: EDot): Bool {
        return sameOptionalChain(optionalChain, other.optionalChain) &&
               canBeRemovedIfUnused == other.canBeRemovedIfUnused &&
               callCanBeUnwrappedIfUnused == other.callCanBeUnwrappedIfUnused
    }
}

/// E.Index - 索引访问表达式 (a[b])
public class EIndex {
    public var index: ASTNode
    public var target: ASTNode
    public var optionalChain: ?OptionalChain

    public init(index: ASTNode, target: ASTNode) {
        this.index = index
        this.target = target
        this.optionalChain = None
    }

    public func hasSameFlagsAs(other: EIndex): Bool {
        return sameOptionalChain(optionalChain, other.optionalChain)
    }
}

/// E.Arrow - 箭头函数
public class EArrow {
    public var args: ArrayList<GArg>
    public var body: GFnBody
    public var isAsync: Bool
    public var hasRestArg: Bool
    public var preferExpr: Bool

    public init(args: ArrayList<GArg>, body: GFnBody, isAsync: Bool) {
        this.args = args
        this.body = body
        this.isAsync = isAsync
        this.hasRestArg = false
        this.preferExpr = false
    }

    /// 空的返回 undefined 箭头函数 - 对应 Bun E.Arrow.noop_return_undefined
    public static let NOOP_RETURN_UNDEFINED: EArrow = EArrow(
        ArrayList<GArg>(),
        GFnBody(ASTLoc.EMPTY, ArrayList<StmtNode>()),
        false
    )
}

/// E.Function - 函数表达式
public class EFunction {
    public var `func`: GFn

    public init(`func`: GFn) {
        this.`func` = `func`
    }
}

/// E.Identifier - 标识符表达式
public class EIdentifier {
    public var ref: Ref
    public var mustKeepDueToWithStmt: Bool
    public var canBeRemovedIfUnused: Bool
    public var callCanBeUnwrappedIfUnused: Bool

    public init(ref: Ref, mustKeepDueToWithStmt: Bool, canBeRemovedIfUnused: Bool,
                callCanBeUnwrappedIfUnused: Bool) {
        this.ref = ref
        this.mustKeepDueToWithStmt = mustKeepDueToWithStmt
        this.canBeRemovedIfUnused = canBeRemovedIfUnused
        this.callCanBeUnwrappedIfUnused = callCanBeUnwrappedIfUnused
    }

    public init(ref: Ref) {
        this.ref = ref
        this.mustKeepDueToWithStmt = false
        this.canBeRemovedIfUnused = false
        this.callCanBeUnwrappedIfUnused = false
    }
}

/// E.ImportIdentifier - ES6 导入标识符
public class EImportIdentifier {
    public var ref: Ref
    public var wasOriginallyIdentifier: Bool

    public init(ref: Ref, wasOriginallyIdentifier: Bool) {
        this.ref = ref
        this.wasOriginallyIdentifier = wasOriginallyIdentifier
    }
}

/// E.CommonJSExportIdentifier - CommonJS 导出标识符
public enum ExportBase {
    | Exports       // exports.xxx
    | ModuleExports // module.exports.xxx

    public func name(): String {
        match (this) {
            case Exports => "exports"
            case ModuleExports => "module_dot_exports"
        }
    }
}

public class ECommonJSExportIdentifier {
    public var ref: Ref
    public var base: ExportBase

    public init(ref: Ref, base: ExportBase) {
        this.ref = ref
        this.base = base
    }

    public init(ref: Ref) {
        this.ref = ref
        this.base = ExportBase.Exports
    }
}

/// E.PrivateIdentifier - 私有标识符 (#xxx)
public class EPrivateIdentifier {
    public var ref: Ref

    public init(ref: Ref) {
        this.ref = ref
    }
}

/// E.JSXElement - JSX 元素
public enum SpecialProp {
    | Self_
    | Source
    | Key
    | Ref
    | Any

    public func name(): String {
        match (this) {
            case Self_ => "__self"
            case Source => "__source"
            case Key => "key"
            case Ref => "ref"
            case Any => "any"
        }
    }
}

public class EJSXElement {
    public var tag: ?ASTNode
    public var properties: ArrayList<GProperty>
    public var children: ArrayList<ASTNode>
    public var keyPropIndex: Int32
    public var flags: Int32
    public var closeTagLoc: ASTLoc

    public init() {
        tag = None
        properties = ArrayList<GProperty>()
        children = ArrayList<ASTNode>()
        keyPropIndex = Int32(-1)
        flags = Int32(0)
        closeTagLoc = ASTLoc.EMPTY
    }
}

/// E.Missing - 缺失表达式
public class EMissing {
    public init() {}
}

/// E.Number - 数字字面量
public class ENumber {
    public var value: Float64

    // 预计算的双位数字符串 - 对应 Bun double_digit / neg_double_digit
    private static let DOUBLE_DIGIT: Array<String> = [
        "0", "1", "2", "3", "4", "5", "6", "7", "8", "9",
        "10", "11", "12", "13", "14", "15", "16", "17", "18", "19",
        "20", "21", "22", "23", "24", "25", "26", "27", "28", "29",
        "30", "31", "32", "33", "34", "35", "36", "37", "38", "39",
        "40", "41", "42", "43", "44", "45", "46", "47", "48", "49",
        "50", "51", "52", "53", "54", "55", "56", "57", "58", "59",
        "60", "61", "62", "63", "64", "65", "66", "67", "68", "69",
        "70", "71", "72", "73", "74", "75", "76", "77", "78", "79",
        "80", "81", "82", "83", "84", "85", "86", "87", "88", "89",
        "90", "91", "92", "93", "94", "95", "96", "97", "98", "99", "100"
    ]

    private static let NEG_DOUBLE_DIGIT: Array<String> = [
        "-0", "-1", "-2", "-3", "-4", "-5", "-6", "-7", "-8", "-9",
        "-10", "-11", "-12", "-13", "-14", "-15", "-16", "-17", "-18", "-19",
        "-20", "-21", "-22", "-23", "-24", "-25", "-26", "-27", "-28", "-29",
        "-30", "-31", "-32", "-33", "-34", "-35", "-36", "-37", "-38", "-39",
        "-40", "-41", "-42", "-43", "-44", "-45", "-46", "-47", "-48", "-49",
        "-50", "-51", "-52", "-53", "-54", "-55", "-56", "-57", "-58", "-59",
        "-60", "-61", "-62", "-63", "-64", "-65", "-66", "-67", "-68", "-69",
        "-70", "-71", "-72", "-73", "-74", "-75", "-76", "-77", "-78", "-79",
        "-80", "-81", "-82", "-83", "-84", "-85", "-86", "-87", "-88", "-89",
        "-90", "-91", "-92", "-93", "-94", "-95", "-96", "-97", "-98", "-99", "-100"
    ]

    public init(value: Float64) {
        this.value = value
    }

    /// 转为字符串 - 对应 Bun E.Number.toString()
    public func toString(): ?String {
        return toStringFromF64(value)
    }

    /// 从 Float64 转字符串 - 对应 Bun E.Number.toStringFromF64()
    public static func toStringFromF64(value: Float64): ?String {
        let intValue = Int64(value)
        // 检查是否为整数
        if (value == Float64(intValue) &&
            value < Float64(2147483647.0) && value > Float64(-2147483648.0)) {
            let absValue = Int64(if (value < Float64(0)) { -value } else { value })
            if (absValue < Int64(101)) {
                if (intValue < Int64(0)) {
                    return NEG_DOUBLE_DIGIT[Int64(absValue)]
                }
                return DOUBLE_DIGIT[Int64(absValue)]
            }
            return intValue.toString()
        }
        // 特殊值
        if (value != value) {  // NaN
            return "NaN"
        }
        if (value < Float64(-1.7976931348623157e308)) {
            return "-Infinity"
        }
        if (value > Float64(1.7976931348623157e308)) {
            return "Infinity"
        }
        return value.toString()
    }

    /// 转为 UInt64 - 对应 Bun E.Number.toU64()
    public func toUInt64(): UInt64 {
        return UInt64(Int64(value))
    }

    /// 转为 UInt32 - 对应 Bun E.Number.toU32()
    public func toUInt32(): UInt32 {
        return UInt32(Int64(value))
    }
}

/// E.BigInt - BigInt 字面量
public class EBigInt {
    public var value: String

    public init(value: String) {
        this.value = value
    }

    public static let EMPTY: EBigInt = EBigInt("")
}

/// Rope 链 - 对应 Bun E.Object.Rope
/// 用于 TOML 解析器的属性合并
public class Rope {
    public var head: ASTNode
    public var next: ?Rope

    public init(head: ASTNode, next: ?Rope) {
        this.head = head
        this.next = next
    }

    public func append(expr: ASTNode): Rope {
        if (let Some(existing) <- next) {
            return existing.append(expr)
        }
        let rope = Rope(expr, Option<Rope>.None)
        this.next = Some(rope)
        return rope
    }
}

/// E.Object - 对象字面量
public class EObject {
    public var properties: ArrayList<GProperty>
    public var commaAfterSpread: ?ASTLoc
    public var isSingleLine: Bool
    public var isParenthesized: Bool
    public var wasOriginallyMacro: Bool
    public var closeBraceLoc: ASTLoc

    public init() {
        properties = ArrayList<GProperty>()
        commaAfterSpread = None
        isSingleLine = false
        isParenthesized = false
        wasOriginallyMacro = false
        closeBraceLoc = ASTLoc.EMPTY
    }

    /// 获取属性 - 对应 Bun E.Object.get()
    public func get(key: String): ?ASTNode {
        if (let Some(query) <- asProperty(key)) {
            return Some(query.expr)
        }
        return None
    }

    /// 设置属性 - 对应 Bun E.Object.put()
    public func put(key: String, expr: ASTNode): Unit {
        if (let Some(q) <- asProperty(key)) {
            properties[Int64(q.i)] = GProperty(ASTNode(ExprTag.StringExpr, q.loc, key), expr)
        } else {
            properties.append(GProperty(
                ASTNode(ExprTag.StringExpr, expr.loc, key),
                expr
            ))
        }
    }

    /// 是否有属性 - 对应 Bun E.Object.hasProperty()
    public func hasProperty(name: String): Bool {
        for (`prop` in properties) {
            if (let Some(keyNode) <- `prop`.key) {
                if (sameExprTag(keyNode.tag, ExprTag.StringExpr)) {
                    if (let Some(keyStr) <- keyNode.stringValue()) {
                        if (keyStr == name) {
                            return true
                        }
                    }
                }
            }
        }
        return false
    }

    /// 查找属性 - 对应 Bun E.Object.asProperty()
    public func asProperty(name: String): ?PropertyQuery {
        var i = Int64(0)
        for (`prop` in properties) {
            if (let Some(keyNode) <- `prop`.key) {
                if (sameExprTag(keyNode.tag, ExprTag.StringExpr)) {
                    if (let Some(keyStr) <- keyNode.stringValue()) {
                        if (keyStr == name) {
                            if (let Some(valueNode) <- `prop`.value) {
                                return Some(PropertyQuery(valueNode, keyNode.loc, UInt32(i)))
                            }
                        }
                    }
                }
            }
            i += Int64(1)
        }
        return None
    }

    /// 按字母排序属性 - 对应 Bun E.Object.alphabetizeProperties()
    public func alphabetizeProperties(): Unit {
        var changed = true
        while (changed) {
            changed = false
            var i = Int64(1)
            while (i < properties.size) {
                let ka = stringValueOrEmpty(properties[i - Int64(1)].key)
                let kb = stringValueOrEmpty(properties[i].key)
                if (stringLessThan(kb, ka)) {
                    let tmp = properties[i - Int64(1)]
                    properties[i - Int64(1)] = properties[i]
                    properties[i] = tmp
                    changed = true
                }
                i += Int64(1)
            }
        }
    }
}

/// 属性查询结果 - 对应 Bun Expr.Query
public class PropertyQuery {
    public var expr: ASTNode
    public var loc: ASTLoc
    public var i: UInt32

    public init(expr: ASTNode, loc: ASTLoc, i: UInt32) {
        this.expr = expr
        this.loc = loc
        this.i = i
    }
}

/// E.Spread - 展开运算符
public class ESpread {
    public var value: ASTNode

    public init(value: ASTNode) {
        this.value = value
    }
}

/// E.String - 字符串字面量
public class EString {
    public var data: String
    public var preferTemplate: Bool
    // Rope 链实现
    public var next: ?EString
    public var end: ?EString
    public var ropeLen: UInt32
    public var isUtf16: Bool

    public init(data: String) {
        this.data = data
        preferTemplate = false
        next = None
        end = None
        ropeLen = UInt32(0)
        isUtf16 = false
    }

    public init() {
        data = ""
        preferTemplate = false
        next = None
        end = None
        ropeLen = UInt32(0)
        isUtf16 = false
    }

    /// 静态常量 - 对应 Bun E.String.class
    public static let CLASS: EString = EString("class")
    public static let EMPTY: EString = EString("")
    public static let TRUE: EString = EString("true")
    public static let FALSE: EString = EString("false")
    public static let NULL: EString = EString("null")
    public static let UNDEFINED: EString = EString("undefined")

    /// 是否 UTF-8 - 对应 Bun E.String.isUTF8()
    public func isUTF8(): Bool {
        return !isUtf16
    }

    /// 获取长度 - 对应 Bun E.String.len()
    public func len(): Int64 {
        if (ropeLen > UInt32(0)) {
            return Int64(ropeLen)
        }
        return data.size
    }

    /// 是否为空 - 对应 Bun E.String.isBlank()
    public func isBlank(): Bool {
        return len() == Int64(0)
    }

    /// 是否存在 - 对应 Bun E.String.isPresent()
    public func isPresent(): Bool {
        return len() > Int64(0)
    }

    /// 相等比较 - 对应 Bun E.String.eql()
    public func eql(other: EString): Bool {
        if (isUTF8() && other.isUTF8()) {
            return data == other.data
        }
        return data == other.data
    }

    /// 推入 rope 节点 - 对应 Bun E.String.push()
    public func push(other: EString): Unit {
        if (other.ropeLen == UInt32(0)) {
            other.ropeLen = UInt32(other.data.size)
        }
        if (ropeLen == UInt32(0)) {
            ropeLen = UInt32(data.size)
        }
        ropeLen = ropeLen + other.ropeLen
        if (next.isNone()) {
            next = Some(other)
            end = Some(other)
        } else {
            if (let Some(endNode) <- end) {
                endNode.next = Some(other)
            }
            this.end = Some(other)
        }
    }

    /// 解析 rope 为字符串 - 对应 Bun E.String.resolveRopeIfNeeded()
    public func resolveRopeIfNeeded(): Unit {
        if (next.isNone() || !isUTF8()) {
            return
        }
        let sb = StringBuilder()
        sb.append(data)
        var current = next
        while (let Some(part) <- current) {
            sb.append(part.data)
            current = part.next
        }
        data = sb.toString()
        next = None
    }

    /// 克隆 - 对应 Bun E.String.clone()
    public func clone(): EString {
        let s = EString(data)
        s.preferTemplate = preferTemplate
        s.isUtf16 = isUtf16
        return s
    }

    /// 克隆 Rope 节点 - 对应 Bun E.String.cloneRopeNodes()
    public func cloneRopeNodes(): EString {
        var root = EString(data)
        root.preferTemplate = preferTemplate
        root.isUtf16 = isUtf16
        root.ropeLen = ropeLen
        // 简化: 仓颉 GC 管理内存, 不需要深拷贝
        root.next = next
        root.end = end
        return root
    }
}

/// 模板部分 - 对应 Bun E.TemplatePart
public class ETemplatePart {
    public var value: ASTNode
    public var tailLoc: ASTLoc
    public var tail: TemplateContents

    public init(value: ASTNode, tailLoc: ASTLoc, tail: TemplateContents) {
        this.value = value
        this.tailLoc = tailLoc
        this.tail = tail
    }
}

/// 模板内容 - 对应 Bun E.Template.Contents
public enum TemplateTag {
    | Cooked
    | Raw

    public func name(): String {
        match (this) {
            case Cooked => "cooked"
            case Raw => "raw"
        }
    }

    public operator func ==(right: TemplateTag): Bool {
        match (this) {
            case Cooked => match (right) { case Cooked => true case _ => false }
            case Raw => match (right) { case Raw => true case _ => false }
        }
    }

    public operator func !=(right: TemplateTag): Bool {
        return !(this == right)
    }
}

public class TemplateContents {
    public var tag: TemplateTag
    public var cooked: ?EString
    public var raw: ?String

    public init(tag: TemplateTag) {
        this.tag = tag
        this.cooked = None
        this.raw = None
    }

    public init(cooked: EString) {
        this.tag = TemplateTag.Cooked
        this.cooked = cooked
        this.raw = None
    }

    public init(raw: String) {
        this.tag = TemplateTag.Raw
        this.raw = raw
        this.cooked = None
    }

    /// 是否 UTF-8 - 对应 Bun E.Template.Contents.isUTF8()
    public func isUTF8(): Bool {
        return tag == TemplateTag.Cooked && cooked.isSome() && cooked.getOrDefault({ => EString() }).isUTF8()
    }
}

/// E.Template - 模板字面量
public class ETemplate {
    public var tag: ?ASTNode
    public var parts: ArrayList<ETemplatePart>
    public var head: TemplateContents

    public init(tag: ?ASTNode, parts: ArrayList<ETemplatePart>, head: TemplateContents) {
        this.tag = tag
        this.parts = parts
        this.head = head
    }

    public init() {
        tag = None
        parts = ArrayList<ETemplatePart>()
        head = TemplateContents(TemplateTag.Cooked)
    }

    /// 折叠模板 - 对应 Bun E.Template.fold()
    /// 将模板中的常量部分合并为字符串
    public func fold(loc: ASTLoc): ASTNode {
        if (tag.isSome()) {
            return ASTNode(ExprTag.Template, loc, this)
        }
        if (head.tag != TemplateTag.Cooked) {
            return ASTNode(ExprTag.Template, loc, this)
        }
        if (parts.size == Int64(0)) {
            // 无插值的模板 -> 纯字符串
            let cooked = head.cooked.getOrDefault({ => EString() })
            return ASTNode(ExprTag.StringExpr, loc, cooked)
        }
        return ASTNode(ExprTag.Template, loc, this)
    }
}

/// E.RegExp - 正则表达式字面量
public class ERegExp {
    public var value: String
    public var flagsOffset: ?UInt16

    public init(value: String, flagsOffset: ?UInt16) {
        this.value = value
        this.flagsOffset = flagsOffset
    }

    public init(value: String) {
        this.value = value
        this.flagsOffset = None
    }

    public static let EMPTY: ERegExp = ERegExp("")

    /// 获取 pattern - 对应 Bun E.RegExp.pattern()
    public func pattern(): String {
        if (flagsOffset.isSome()) {
            var i = Int64(flagsOffset.getOrDefault({ => UInt16(0) }))
            while (i > Int64(0) && value[Int64(i)] != UInt8(47)) {  // '/' = 47
                i -= Int64(1)
            }
            return value[Int64(1)..i]
        }
        return value[Int64(1)..(value.size - Int64(1))]
    }

    /// 获取 flags - 对应 Bun E.RegExp.flags()
    public func flags(): String {
        if (flagsOffset.isSome()) {
            return value[Int64(flagsOffset.getOrDefault({ => UInt16(0) }))..value.size]
        }
        return ""
    }
}

/// E.Await - await 表达式
public class EAwait {
    public var value: ASTNode

    public init(value: ASTNode) {
        this.value = value
    }
}

/// E.Yield - yield 表达式
public class EYield {
    public var value: ?ASTNode
    public var isStar: Bool

    public init(value: ?ASTNode, isStar: Bool) {
        this.value = value
        this.isStar = isStar
    }
}

/// E.If - 三元条件表达式
public class EIf {
    public var test_: ASTNode
    public var yes: ASTNode
    public var no: ASTNode

    public init(test_: ASTNode, yes: ASTNode, no: ASTNode) {
        this.test_ = test_
        this.yes = yes
        this.no = no
    }
}

/// E.RequireString - require('...') 字符串
public class ERequireString {
    public var importRecordIndex: UInt32
    public var unwrappedId: UInt32

    public init(importRecordIndex: UInt32, unwrappedId: UInt32) {
        this.importRecordIndex = importRecordIndex
        this.unwrappedId = unwrappedId
    }
}

/// E.RequireResolveString - require.resolve('...')
public class ERequireResolveString {
    public var importRecordIndex: UInt32

    public init(importRecordIndex: UInt32) {
        this.importRecordIndex = importRecordIndex
    }
}

/// E.InlinedEnum - 内联枚举
public class EInlinedEnum {
    public var value: ASTNode
    public var comment: String

    public init(value: ASTNode, comment: String) {
        this.value = value
        this.comment = comment
    }
}

/// E.Import - 动态 import() 表达式
public class EImport {
    public var expr: ASTNode
    public var options: ASTNode
    public var importRecordIndex: UInt32

    public init(expr: ASTNode, options: ASTNode, importRecordIndex: UInt32) {
        this.expr = expr
        this.options = options
        this.importRecordIndex = importRecordIndex
    }

    /// 导入记录是否为空 - 对应 Bun E.Import.isImportRecordNull()
    public func isImportRecordNull(): Bool {
        return importRecordIndex == UInt32(0x7FFFFFFF)
    }
}

// ============================================================================
// G 命名空间的共享类型
// ============================================================================

/// 函数参数 - 对应 Bun G.Arg
public class GArg {
    public var binding: Binding
    public var default_: ?ASTNode
    public var isRest: Bool
    public var decorator: ?ASTNode
    public var typeAnnotation: ?ASTNode

    public init(binding: Binding) {
        this.binding = binding
        this.default_ = None
        this.isRest = false
        this.decorator = None
        this.typeAnnotation = None
    }

    public func deepClone(): GArg {
        let arg = GArg(binding)
        arg.default_ = default_
        arg.isRest = isRest
        return arg
    }
}

/// 函数体 - 对应 Bun G.FnBody
public class GFnBody {
    public var loc: ASTLoc
    public var stmts: ArrayList<StmtNode>

    public init(loc: ASTLoc, stmts: ArrayList<StmtNode>) {
        this.loc = loc
        this.stmts = stmts
    }
}

/// 函数声明 - 对应 Bun G.Fn
public class GFn {
    public var name: ?LocRef
    public var args: ArrayList<GArg>
    public var body: GFnBody
    public var isAsync: Bool
    public var isGenerator: Bool
    public var hasRestArg: Bool
    public var openParenLoc: ASTLoc
    public var closeParenLoc: ASTLoc

    public init(name: ?LocRef, args: ArrayList<GArg>, body: GFnBody,
                isAsync: Bool, isGenerator: Bool) {
        this.name = name
        this.args = args
        this.body = body
        this.isAsync = isAsync
        this.isGenerator = isGenerator
        this.hasRestArg = false
        this.openParenLoc = ASTLoc.EMPTY
        this.closeParenLoc = ASTLoc.EMPTY
    }

    public func deepClone(): GFn {
        let args = ArrayList<GArg>()
        for (arg in this.args) {
            args.append(arg.deepClone())
        }
        return GFn(name, args, body, isAsync, isGenerator)
    }
}

/// 属性 - 对应 Bun G.Property
public enum PropertyKind {
    | Normal
    | Spread
    | Getter
    | Setter

    public func name(): String {
        match (this) {
            case Normal => "normal"
            case Spread => "spread"
            case Getter => "getter"
            case Setter => "setter"
        }
    }
}

public class GProperty {
    public var key: ?ASTNode
    public var value: ?ASTNode
    public var kind: PropertyKind
    public var flags: BindingPropertyFlags
    public var decorator: ?ASTNode
    public var initializer: ?ASTNode

    public init(key: ASTNode, value: ASTNode) {
        this.key = key
        this.value = value
        this.kind = PropertyKind.Normal
        this.flags = BindingPropertyFlags()
        this.decorator = None
        this.initializer = None
    }

    public init(key: ASTNode, value: ASTNode, kind: PropertyKind) {
        this.key = key
        this.value = value
        this.kind = kind
        this.flags = BindingPropertyFlags()
        this.decorator = None
        this.initializer = None
    }
}

/// 声明 - 对应 Bun G.Decl
public class GDecl {
    public var binding: Binding
    public var value: ?ASTNode

    public init(binding: Binding, value: ?ASTNode) {
        this.binding = binding
        this.value = value
    }
}

/// ExportStar 别名 - 对应 Bun G.ExportStarAlias
public class GExportStarAlias {
    public var name: String
    public var loc: ASTLoc
    public var originalName: String

    public init(name: String, loc: ASTLoc) {
        this.name = name
        this.loc = loc
        this.originalName = name
    }
}

/// 类声明 - 对应 Bun G.Class
public class GClass {
    public var classKeyword: ASTLoc
    public var tsDecorators: ArrayList<ASTNode>
    public var className: ?LocRef
    public var extends_: ?ASTNode
    public var bodyLoc: ASTLoc
    public var closeBraceLoc: ASTLoc
    public var properties: ArrayList<GProperty>
    public var hasDecorators: Bool

    public init() {
        classKeyword = ASTLoc.EMPTY
        tsDecorators = ArrayList<ASTNode>()
        className = None
        extends_ = None
        bodyLoc = ASTLoc.EMPTY
        closeBraceLoc = ASTLoc.EMPTY
        properties = ArrayList<GProperty>()
        hasDecorators = false
    }

    public func canBeMoved(): Bool {
        return true
    }
}

/// LocRef - 位置引用 - 对应 Bun LocRef
public class LocRef {
    public var loc: ASTLoc
    public var ref: Ref

    public init(loc: ASTLoc, ref: Ref) {
        this.loc = loc
        this.ref = ref
    }
}

