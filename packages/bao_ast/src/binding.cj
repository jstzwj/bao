// 严格翻译自: src/ast/binding.zig
// Binding 联合类型: B.Identifier, B.Array, B.Object, B.Missing
package bao_ast

import bao_core.*
import bao_collections.*
import bao_parser.*

// ============================================================================
// Binding - 绑定节点
// 严格翻译自: src/ast/binding.zig:1-172
// Bun: pub const Binding = struct { loc: logger.Loc, data: Data }
//   Binding 是变量声明左侧的解构绑定模式
//   let { foo: [ bar ] } = ...
//       -----B.Object----
//            --B.Array--
//               -B.Identifier
// ============================================================================

/// 数组绑定项 - 对应 Bun ArrayBinding
/// Bun: pub const ArrayBinding = struct { binding: Binding, default_value: ?Expr = null }
public class ArrayBinding {
    public var binding: Binding
    public var defaultValue: ?ASTNode

    public init(binding: Binding, defaultValue: ?ASTNode) {
        this.binding = binding
        this.defaultValue = defaultValue
    }

    public init(binding: Binding) {
        this.binding = binding
        this.defaultValue = None
    }
}

/// 绑定属性标志 - 对应 Bun Flags.Property
public class BindingPropertyFlags {
    public var isSpread: Bool
    public var isComputed: Bool
    public var isMethod: Bool
    public var isStatic: Bool

    public init() {
        isSpread = false
        isComputed = false
        isMethod = false
        isStatic = false
    }

    public static let NONE: BindingPropertyFlags = BindingPropertyFlags()
}

/// 绑定属性 - 对应 Bun B.Property
/// Bun: pub const Property = struct { flags, key: ExprNodeIndex, value: Binding, default_value: ?Expr }
public class BindingProperty {
    public var flags: BindingPropertyFlags
    public var key: ASTNode
    public var value: Binding
    public var defaultValue: ?ASTNode

    public init(flags: BindingPropertyFlags, key: ASTNode, value: Binding,
                defaultValue: ?ASTNode) {
        this.flags = flags
        this.key = key
        this.value = value
        this.defaultValue = defaultValue
    }

    public init(key: ASTNode, value: Binding) {
        this.flags = BindingPropertyFlags()
        this.key = key
        this.value = value
        this.defaultValue = None
    }
}

/// B 标识符绑定 - 对应 Bun B.Identifier
/// Bun: pub const Identifier = struct { ref: Ref }
public class BIdentifier {
    public var ref: Ref

    public init(ref: Ref) {
        this.ref = ref
    }
}

/// B 数组绑定 - 对应 Bun B.Array
/// Bun: pub const Array = struct { items: []ArrayBinding, has_spread, is_single_line }
public class BArray {
    public var items: ArrayList<ArrayBinding>
    public var hasSpread: Bool
    public var isSingleLine: Bool

    public init(items: ArrayList<ArrayBinding>, hasSpread: Bool, isSingleLine: Bool) {
        this.items = items
        this.hasSpread = hasSpread
        this.isSingleLine = isSingleLine
    }

    public init() {
        items = ArrayList<ArrayBinding>()
        hasSpread = false
        isSingleLine = false
    }
}

/// B 对象绑定 - 对应 Bun B.Object
/// Bun: pub const Object = struct { properties: []B.Property, is_single_line }
public class BObject {
    public var properties: ArrayList<BindingProperty>
    public var isSingleLine: Bool

    public init(properties: ArrayList<BindingProperty>, isSingleLine: Bool) {
        this.properties = properties
        this.isSingleLine = isSingleLine
    }

    public init() {
        properties = ArrayList<BindingProperty>()
        isSingleLine = false
    }
}

/// Binding - 绑定节点
/// 严格翻译自 Bun Binding
/// Bun: pub const Binding = struct { loc: logger.Loc, data: Data }
/// Data 是 B.Identifier | B.Array | B.Object | B.Missing 的 tagged union
public class Binding {
    /// 绑定标签
    public var tag: BindingTag
    /// 源码位置
    public var loc: ASTLoc
    /// B.Identifier 数据
    public var identifierData: ?BIdentifier
    /// B.Array 数据
    public var arrayBindingData: ?BArray
    /// B.Object 数据
    public var objectBindingData: ?BObject

    public init(tag: BindingTag, loc: ASTLoc) {
        this.tag = tag
        this.loc = loc
        this.identifierData = None
        this.arrayBindingData = None
        this.objectBindingData = None
    }

    /// 创建标识符绑定 - 对应 Bun Binding.init(*B.Identifier, loc)
    public static func identifier(ref: Ref, loc: ASTLoc): Binding {
        let b = Binding(BindingTag.Identifier, loc)
        b.identifierData = BIdentifier(ref)
        return b
    }

    /// 创建数组绑定 - 对应 Bun Binding.init(*B.Array, loc)
    public static func arrayBinding(items: ArrayList<ArrayBinding>, hasSpread: Bool,
                                     isSingleLine: Bool, loc: ASTLoc): Binding {
        let b = Binding(BindingTag.Array, loc)
        b.arrayBindingData = BArray(items, hasSpread, isSingleLine)
        return b
    }

    /// 创建对象绑定 - 对应 Bun Binding.init(*B.Object, loc)
    public static func objectBinding(properties: ArrayList<BindingProperty>,
                                      isSingleLine: Bool, loc: ASTLoc): Binding {
        let b = Binding(BindingTag.Object, loc)
        b.objectBindingData = BObject(properties, isSingleLine)
        return b
    }

    /// 创建缺失绑定 - 对应 Bun Binding.init(B.Missing, loc)
    public static func missing(loc: ASTLoc): Binding {
        return Binding(BindingTag.Missing, loc)
    }

    /// 转换为表达式 - 对应 Bun Binding.toExpr()
    /// Bun: pub fn toExpr(binding: *const Binding, wrapper: anytype) Expr
    public func toExpr(): ASTNode {
        match (tag) {
            case Missing =>
                return ASTNode(ExprTag.Missing, loc)
            case Identifier =>
                if (let Some(id) <- identifierData) {
                    return ASTNode(ExprTag.Identifier, loc, id.ref)
                }
                return ASTNode(ExprTag.Missing, loc)
            case Array =>
                if (let Some(arr) <- arrayBindingData) {
                    let node = ASTNode(ExprTag.Array, loc)
                    for (item in arr.items) {
                        node.addChild(item.binding.toExpr())
                    }
                    return node
                }
                return ASTNode(ExprTag.Array, loc)
            case Object =>
                if (let Some(obj) <- objectBindingData) {
                    let node = ASTNode(ExprTag.Object, loc)
                    for (`prop` in obj.properties) {
                        node.addChild(`prop`.value.toExpr())
                    }
                    return node
                }
                return ASTNode(ExprTag.Object, loc)
        }
    }

    /// 写入哈希 - 对应 Bun B.writeToHasher()
    /// 用于 React Fast Refresh 哈希计算
    public func writeToHasher(hasher: Hasher, symbolTable: SymbolList): Unit {
        match (tag) {
            case Identifier =>
                if (let Some(id) <- identifierData) {
                    hasher.update(Int64(tag.ordinal()))
                    hasher.update(Int64(id.ref.innerIndex))
                }
            case Array =>
                if (let Some(arr) <- arrayBindingData) {
                    hasher.update(Int64(tag.ordinal()))
                    hasher.update(arr.hasSpread)
                    hasher.update(Int64(arr.items.size))
                    for (item in arr.items) {
                        hasher.update(item.defaultValue.isSome())
                        if (item.defaultValue.isSome()) {
                            // item.defaultValue.orElse(ASTNode(...)).writeToHasher(hasher, symbolTable)
                        }
                        item.binding.writeToHasher(hasher, symbolTable)
                    }
                }
            case Object =>
                if (let Some(obj) <- objectBindingData) {
                    hasher.update(Int64(tag.ordinal()))
                    hasher.update(Int64(obj.properties.size))
                    for (`prop` in obj.properties) {
                        hasher.update(`prop`.defaultValue.isSome())
                        `prop`.value.writeToHasher(hasher, symbolTable)
                    }
                }
            case Missing => ()
        }
    }
}

/// 简单哈希器 - 用于 writeToHasher
public class Hasher {
    private var state: UInt64

    public init() {
        state = UInt64(0)
    }

    public func update(value: Int64): Unit {
        state = state * UInt64(31) + UInt64(value)
    }

    public func update(value: Bool): Unit {
        state = state * UInt64(31) + (if (value) { UInt64(1) } else { UInt64(0) })
    }

    public func update(bytes: String): Unit {
        for (c in bytes) {
            state = state * UInt64(31) + UInt64(UInt32(c))
        }
    }

    public func finalize(): UInt64 {
        return state
    }
}
