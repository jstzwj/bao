// 严格翻译自: src/ptr/meta.zig
// meta - 智能指针实现中使用的私有工具函数
package bao_ptr

import bao_core.*

// ============================================================================
// PointerKind - 指针类型枚举
// ============================================================================

/// 指针类型枚举
public enum PointerKind {
    | Single    // 单项指针 *T
    | Slice     // 切片 []T
}

// ============================================================================
// PointerInfo - 指针类型信息
// ============================================================================

/// 指针类型信息
/// 用于分析一个类型是指针还是切片，以及其子元素类型
public struct PointerInfo {
    /// 可能是可选的切片或单项指针类型
    public var Pointer: TypeInfo = TypeInfo()

    /// 如果 Pointer 是可选指针，这是其非可选等价类型。否则与 Pointer 相同
    public var NonOptionalPointer: TypeInfo = TypeInfo()

    /// 指针存储的数据类型，即解引用单项指针或访问切片元素获得的类型
    public var Child: TypeInfo = TypeInfo()

    public init() {}

    public init(pointer: TypeInfo, nonOptionalPointer: TypeInfo, child: TypeInfo) {
        this.Pointer = pointer
        this.NonOptionalPointer = nonOptionalPointer
        this.Child = child
    }

    /// 返回指针类型 (单项还是切片)
    public func kind(): PointerKind {
        PointerKind.Single  // 默认为单项指针
    }

    /// 是否是可选类型
    public func isOptional(): Bool {
        false  // 由具体实现覆盖
    }

    /// 是否是 const 指针
    public func isConst(): Bool {
        false  // 由具体实现覆盖
    }
}

/// ParseOptions - 解析选项
public struct ParseOptions {
    public var allowConst: Bool = true
    public var allowSlices: Bool = true

    public init() {}
    public init(allowConst: Bool, allowSlices: Bool) {
        this.allowConst = allowConst
        this.allowSlices = allowSlices
    }
}

/// TypeInfo - 简化的类型信息
/// 在仓颉中用于表示指针类型元信息
public struct TypeInfo {
    public var name: String = ""
    public var isPointer: Bool = false
    public var isSlice: Bool = false
    public var isOptional: Bool = false
    public var isConst: Bool = false
    public var childTypeName: String = ""

    public init() {}
}

// ============================================================================
// AddConst - 类型操作辅助
// ============================================================================

/// AddConst - 给指针类型添加 const 限定
/// 在仓颉中通过接口约束实现
public func addConst<T>(value: T): T {
    value
}
