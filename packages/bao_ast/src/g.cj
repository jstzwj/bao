// AST 全局结构
// 严格翻译自: src/ast/g.zig (232行)
//   AST 中的全局结构定义:
//     - Decl: 变量声明 (binding + value)
//     - NamespaceAlias: 命名空间别名
//     - ExportStarAlias: export * 别名
//     - Class: 类定义
//     - Comment: 注释
//     - ClassStaticBlock: 类静态块
//     - Property: 属性 (类成员)
//     - FnBody/Fn/Arg: 函数定义
package bao_ast

import bao_core.*
import bao_collections.*

// ============================================================================
// Decl - 变量声明
// 严格翻译自: g.zig:1-6
//   pub const Decl = struct { binding: BindingNodeIndex, value: ?ExprNodeIndex }
// ============================================================================

/// 变量声明 - 对应 Bun Decl
public class Decl {
    public var binding: BindingNode
    public var value: ?ASTNode

    public init(binding: BindingNode) {
        this.binding = binding
        this.value = None
    }

    public init(binding: BindingNode, value: ?ASTNode) {
        this.binding = binding
        this.value = value
    }
}

/// 声明列表
public class DeclList {
    public var items: ArrayList<Decl>

    public init() {
        items = ArrayList<Decl>()
    }
}

// ============================================================================
// ExportStarAlias - export * 别名
// 严格翻译自: g.zig:17-24
//   pub const ExportStarAlias = struct { loc, original_name }
// ============================================================================

/// export * 别名 - 对应 Bun ExportStarAlias
public class ExportStarAlias {
    public var loc: ASTLoc
    public var originalName: String

    public init(loc: ASTLoc, originalName: String) {
        this.loc = loc
        this.originalName = originalName
    }
}

// ============================================================================
// Class - 类定义
// 严格翻译自: g.zig:26-74
//   pub const Class = struct { class_keyword, ts_decorators, class_name, extends, ... }
// ============================================================================

/// 类定义 - 对应 Bun Class
public class Class {
    public var classKeyword: ASTRange
    public var tsDecorators: ArrayList<ASTNode>
    public var className: ?LocRef
    public var extends: ?ASTNode
    public var bodyLoc: ASTLoc
    public var closeBraceLoc: ASTLoc
    public var properties: ArrayList<Property>
    public var hasDecorators: Bool
    public var shouldLowerStandardDecorators: Bool

    public init() {
        classKeyword = ASTRange()
        tsDecorators = ArrayList<ASTNode>()
        className = None
        extends = None
        bodyLoc = ASTLoc()
        closeBraceLoc = ASTLoc()
        properties = ArrayList<Property>()
        hasDecorators = false
        shouldLowerStandardDecorators = false
    }

    /// 是否可以移动 - 对应 Bun Class.canBeMoved()
    public func canBeMoved(): Bool {
        if (extends.isSome()) {
            return false
        }
        if (hasDecorators) {
            return false
        }
        true
    }
}

// ============================================================================
// Comment - 注释
// 严格翻译自: g.zig:77
//   pub const Comment = struct { loc, text }
// ============================================================================

/// 注释 - 对应 Bun Comment
public class Comment {
    public var loc: ASTLoc
    public var text: String

    public init(loc: ASTLoc, text: String) {
        this.loc = loc
        this.text = text
    }
}

// ============================================================================
// ClassStaticBlock - 类静态块
// 严格翻译自: g.zig:79-82
//   pub const ClassStaticBlock = struct { stmts, loc }
// ============================================================================

/// 类静态块 - 对应 Bun ClassStaticBlock
public class ClassStaticBlock {
    public var stmts: ArrayList<StmtNode>
    public var loc: ASTLoc

    public init() {
        stmts = ArrayList<StmtNode>()
        loc = ASTLoc()
    }
}

// ============================================================================
// Property - 属性
// 严格翻译自: g.zig:84-143
//   pub const Property = struct { initializer, kind, flags, key, value, ... }
// ============================================================================

/// 属性类型 - 对应 Bun Property.Kind
public enum PropertyKind {
    | Normal           // 常规属性
    | Get              // getter
    | Set              // setter
    | Spread           // 展开运算符
    | Declare          // TypeScript declare
    | Abstract         // TypeScript abstract
    | ClassStaticBlock // 类静态块
    | AutoAccessor     // auto accessor

    public operator func ==(right: PropertyKind): Bool {
        ordinal() == right.ordinal()
    }

    public func ordinal(): Int64 {
        match (this) {
            case Normal => 0
            case Get => 1
            case Set => 2
            case Spread => 3
            case Declare => 4
            case Abstract => 5
            case ClassStaticBlock => 6
            case AutoAccessor => 7
        }
    }
}

/// 属性 - 对应 Bun Property
/// 用于对象字面量和类定义中的属性
public class Property {
    /// 初始化器 - 对应 Bun Property.initializer
    public var initializer: ?ASTNode
    /// 属性类型
    public var kind: PropertyKind
    /// 属性标志
    public var flags: PropertyFlags
    /// 类静态块 (当 kind == ClassStaticBlock)
    public var classStaticBlock: ?ClassStaticBlock
    /// TypeScript 装饰器
    public var tsDecorators: ArrayList<ASTNode>
    /// 键 (属性名) - 展开运算符时可为 null
    public var key: ?ASTNode
    /// 值 - 类字段时省略
    public var value: ?ASTNode

    public init() {
        initializer = None
        kind = PropertyKind.Normal
        flags = PropertyFlags()
        classStaticBlock = None
        tsDecorators = ArrayList<ASTNode>()
        key = None
        value = None
    }
}

/// 属性标志 - 对应 Bun Flags.Property.Set
public class PropertyFlags {
    public var isComputed: Bool
    public var isStatic: Bool
    public var isSpread: Bool
    public var isMethod: Bool
    public var isPrivate: Bool
    public var isOverride: Bool
    public var isAbstract: Bool
    public var isDeclare: Bool
    public var isReadonly: Bool
    public var isAccessor: Bool

    public init() {
        isComputed = false
        isStatic = false
        isSpread = false
        isMethod = false
        isPrivate = false
        isOverride = false
        isAbstract = false
        isDeclare = false
        isReadonly = false
        isAccessor = false
    }
}

// ============================================================================
// FnBody - 函数体
// 严格翻译自: g.zig:146-158
// ============================================================================

/// 函数体 - 对应 Bun FnBody
public class FnBody {
    public var loc: ASTLoc
    public var stmts: ArrayList<StmtNode>

    public init() {
        loc = ASTLoc()
        stmts = ArrayList<StmtNode>()
    }
}

// ============================================================================
// Fn - 函数定义
// 严格翻译自: g.zig:160-191
//   pub const Fn = struct { name, open_parens_loc, args, body, flags, ... }
// ============================================================================

/// 函数定义 - 对应 Bun Fn
public class Fn {
    public var name: ?LocRef
    public var openParensLoc: ASTLoc
    public var args: ArrayList<Arg>
    public var body: FnBody
    public var argumentsRef: ?Ref
    public var flags: FunctionFlags
    public var returnTsMetadata: String

    public init() {
        name = None
        openParensLoc = ASTLoc()
        args = ArrayList<Arg>()
        body = FnBody()
        argumentsRef = None
        flags = FunctionFlags()
        returnTsMetadata = ""
    }
}

// ============================================================================
// Arg - 函数参数
// 严格翻译自: g.zig:192-211
//   pub const Arg = struct { ts_decorators, binding, default, ... }
// ============================================================================

/// 函数参数 - 对应 Bun Arg
public class Arg {
    public var tsDecorators: ArrayList<ASTNode>
    public var binding: BindingNode
    public var default: ?ASTNode
    public var isTypescriptCtorField: Bool
    public var tsMetadata: String

    public init(binding: BindingNode) {
        tsDecorators = ArrayList<ASTNode>()
        this.binding = binding
        this.default = None
        isTypescriptCtorField = false
        tsMetadata = ""
    }
}

/// 函数标志 - 对应 Bun Flags.Function.Set
public class FunctionFlags {
    public var isAsync: Bool
    public var isGenerator: Bool
    public var isExport: Bool
    public var isDefault: Bool
    public var hasRestArgument: Bool

    public init() {
        isAsync = false
        isGenerator = false
        isExport = false
        isDefault = false
        hasRestArgument = false
    }
}

// ============================================================================
// 辅助类型引用
// ============================================================================

/// 绑定节点 - 在 binding.cj 中定义
public typealias BindingNode = BindingNode

/// AST 节点 - 在 package.cj 中定义
public typealias ASTNode = ASTNode
