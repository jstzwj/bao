// meta - 指针类型元信息工具
// 严格翻译自: src/ptr/meta.zig
// 私有工具: 智能指针实现中使用的指针类型解析和操作
package bao_core.ptr

// ============================================================================
// PointerInfo - 指针类型元信息
// 对应 Bun: pub const PointerInfo = struct { Pointer, NonOptionalPointer, Child }
//
// 在 Zig 中这是编译时类型反射, 在仓颉中通过类和方法模拟
// ============================================================================

/// 指针种类
// 对应 Bun: pub fn kind(self: Self) enum { single, slice }
public enum PointerKind {
    | Single   // 单项指针: *T
    | Slice    // 切片: []T

    public operator func ==(right: PointerKind): Bool {
        match (this) {
            case Single => match (right) { case Single => true case Slice => false }
            case Slice => match (right) { case Single => false case Slice => true }
        }
    }
}

/// 指针类型信息
// 对应 Bun: pub const PointerInfo = struct { Pointer, NonOptionalPointer, Child }
public class PointerInfo {
    /// 指针类型 (可能可选)
    public let pointerType: String
    /// 非可选指针类型
    public let nonOptionalPointerType: String
    /// 指向的子类型
    public let childType: String
    /// 是否可选
    public let isOptional: Bool
    /// 是否 const
    public let isConst: Bool
    /// 指针种类
    public let kind: PointerKind

    public init(
        pointerType: String,
        nonOptionalPointerType: String,
        childType: String,
        isOptional: Bool,
        isConst: Bool,
        kind: PointerKind
    ) {
        this.pointerType = pointerType
        this.nonOptionalPointerType = nonOptionalPointerType
        this.childType = childType
        this.isOptional = isOptional
        this.isConst = isConst
        this.kind = kind
    }

    /// 解析选项
    // 对应 Bun: pub const ParseOptions = struct { allow_const, allow_slices }
    public static func parse(
        typeName: String,
        allowConst: Bool,
        allowSlices: Bool
    ): ?PointerInfo {
        var optional = false
        var currentType = typeName

        // 检查是否可选 (以 "?" 开头或 "Option<" 包含)
        if (currentType.startsWith("?") || currentType.startsWith("Option<")) {
            optional = true
            if (currentType.startsWith("?")) {
                currentType = currentType[1..currentType.size]
            }
        }

        var constness = false
        var ptrKind = PointerKind.Single
        var child = currentType

        // 检查是否是切片类型
        if (currentType.startsWith("[]") || currentType.startsWith("Array<")) {
            ptrKind = PointerKind.Slice
        }

        // 检查是否是 const
        if (currentType.contains("const ") || currentType.contains("Const")) {
            constness = true
        }

        // 提取子类型
        if (currentType.startsWith("CPointer<")) {
            let prefixLen = Int64("CPointer<".size)
            child = currentType[prefixLen..currentType.size]
            if (child.endsWith(">")) {
                child = child[0..(child.size - 1)]
            }
        } else if (currentType.startsWith("Array<")) {
            ptrKind = PointerKind.Slice
            let prefixLen = Int64("Array<".size)
            child = currentType[prefixLen..currentType.size]
            if (child.endsWith(">")) {
                child = child[0..(child.size - 1)]
            }
        }

        if (!allowConst && constness) {
            return None
        }

        if (!allowSlices && ptrKind == PointerKind.Slice) {
            return None
        }

        return PointerInfo(
            typeName,
            currentType,
            child,
            optional,
            constness,
            ptrKind
        )
    }
}

// ============================================================================
// AddConst - 给指针类型添加 const 限定
// 对应 Bun: pub fn AddConst(Pointer: type) type
// 在仓颉中通过字符串操作模拟类型变换
// ============================================================================

/// 给类型名添加 const 限定
// 对应 Bun: AddConst(Pointer) 在编译时给指针类型加 const
public func addConstToTypeName(typeName: String): String {
    if (typeName.startsWith("CPointer<")) {
        return "Const" + typeName
    }
    if (typeName.startsWith("?CPointer<") || typeName.startsWith("Option<CPointer<")) {
        // 可选指针: 在内部指针上加 const
        let prefix = if (typeName.startsWith("?")) { "?" } else { "Option<" }
        let prefixLen = Int64(prefix.size)
        let rest = typeName[prefixLen..typeName.size]
        return prefix + "Const" + rest
    }
    return typeName
}
