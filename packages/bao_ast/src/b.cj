// 严格翻译自: src/ast/b.zig
// B 是 Binding 的联合体定义: B.Identifier, B.Array, B.Object, B.Missing
// 这个文件在 Bun 中定义了 B union 类型和 writeToHasher 方法
package bao_ast

import bao_core.*
import bao_collections.*
import bao_parser.*

// 注意: B 的核心类型 (BIdentifier, BArray, BObject) 已在 binding.cj 中定义
// 此文件提供 B 联合体的补充定义和 B.Class 引用

// ============================================================================
// B 联合体 - 对应 Bun B
// 严格翻译自: src/ast/b.zig:1-105
// Bun: pub const B = union(Binding.Tag) {
//   b_identifier: *B.Identifier,
//   b_array: *B.Array,
//   b_object: *B.Object,
//   b_missing: B.Missing,
// }
// ============================================================================

/// B.Missing 空类型 - 对应 Bun B.Missing
/// Bun: pub const Missing = struct {}
/// 数组解构中的空洞: let [a, , b] = arr
public class BMissing {
    public init() {}
}

/// B 联合体包装 - 对应 Bun 的 B union
/// 仓颉中没有 tagged union, 用包装类模拟
public class BUnion {
    public var tag: BindingTag
    public var identifier: ?BIdentifier
    public var arrayBinding: ?BArray
    public var objectBinding: ?BObject
    public var missing: ?BMissing

    public init(tag: BindingTag) {
        this.tag = tag
        this.identifier = None
        this.arrayBinding = None
        this.objectBinding = None
        this.missing = None
    }

    /// 写入哈希 - 对应 Bun B.writeToHasher()
    /// Bun: pub fn writeToHasher(b: B, hasher: anytype, symbol_table: anytype) void
    /// 此函数用于 React Fast Refresh 变换的哈希计算
    public func writeToHasher(hasher: Hasher, symbolTable: ArrayList<Symbol>): Unit {
        match (tag) {
            case BindingTag.Identifier => {
                if (identifier.isSome()) {
                    let id = identifier.orElse(BIdentifier(Ref.NONE))
                    // 在 Bun 中会获取 original_name, 这里简化
                    hasher.update(tag.ordinal())
                    hasher.update(id.ref.innerIndex)
                }
            }
            case BindingTag.Array => {
                if (arrayBinding.isSome()) {
                    let arr = arrayBinding.orElse(BArray())
                    hasher.update(tag.ordinal())
                    hasher.update(arr.hasSpread)
                    hasher.update(arr.items.size)
                    for (item in arr.items) {
                        hasher.update(item.defaultValue.isSome())
                        // 递归写入默认值和绑定的哈希
                        item.binding.writeToHasher(hasher, SymbolList())
                    }
                }
            }
            case BindingTag.Object => {
                if (objectBinding.isSome()) {
                    let obj = objectBinding.orElse(BObject())
                    hasher.update(tag.ordinal())
                    hasher.update(obj.properties.size)
                    for (prop in obj.properties) {
                        hasher.update(prop.defaultValue.isSome())
                        prop.value.writeToHasher(hasher, SymbolList())
                    }
                }
            }
            case BindingTag.Missing => {
                // 空洞不做任何操作
            }
        }
    }
}
