// bao_ast - TypeScript 特定 AST
// 严格翻译自: src/ast/ts.zig (140L)
//   TSNamespaceScope - TypeScript 命名空间/枚举作用域
//   TSNamespaceMemberMap - 命名空间成员映射
//   TSNamespaceMember - 命名空间成员 (loc + data)
//   TSNamespaceMember.Data - 成员数据 (property/namespace/enum_*)
//   Class - 类声明 (引用 G.Class)
//
// 注意: TSNamespaceScope 和相关类型已在 scope.cj 中定义
// 本文件包含 TypeScript 特定的 AST 节点和辅助类型
package bao_ast

import bao_core.*
import bao_collections.*

// ============================================================================
// TSTypeKind - TypeScript 类型种类
// 严格翻译自: src/ast/ 中的 TypeScript 相关类型
// Bun 使用 TypeScript 特定的 AST 节点来表示 TS 语法
// 这些在解析器中被解析，在转译/打包时被处理或移除
// ============================================================================

/// TypeScript 类型种类 - 对应 Bun 中 TS 类型注解的类型
public enum TSTypeKind {
    | Any            // any
    | Unknown        // unknown
    | Number         // number
    | Boolean        // boolean
    | String         // string
    | Void           // void
    | Undefined      // undefined
    | Null           // null
    | Never          // never
    | Object         // object
    | Symbol         // symbol
    | BigInt         // bigint
    | This           // this (类型)
    | Literal        // 字面量类型 (字符串/数字/布尔)
    | Array          // T[]
    | Tuple          // [T, U, ...]
    | Union          // T | U
    | Intersection   // T & U
    | Conditional    // T extends U ? X : Y
    | Parenthesized  // (T)
    | Function       // (args) => T
    | Constructor    // new (args) => T
    | TypeReference  // TypeName
    | TypeQuery      // typeof x
    | TypeOperator   // keyof T, readonly T, unique T
    | IndexedAccess  // T[K]
    | Mapped         // { [K in keyof T]: U }
    | TemplateLiteral // `${T}`
    | Rest           // ...T
    | Optional       // T?
    | Enum           // enum 类型引用
    | Class          // class 类型引用
    | Namespace      // namespace 类型引用
    | ImportType     // import('...').Type
    | Infer          // infer T
    | Extends        // T extends U
    | Typeof         // typeof 类型查询

    public func name(): String {
        match (this) {
            case Any => "any"
            case Unknown => "unknown"
            case Number => "number"
            case Boolean => "boolean"
            case String => "string"
            case Void => "void"
            case Undefined => "undefined"
            case Null => "null"
            case Never => "never"
            case Object => "object"
            case Symbol => "symbol"
            case BigInt => "bigint"
            case This => "this"
            case Literal => "literal"
            case Array => "array"
            case Tuple => "tuple"
            case Union => "union"
            case Intersection => "intersection"
            case Conditional => "conditional"
            case Parenthesized => "parenthesized"
            case Function => "function"
            case Constructor => "constructor"
            case TypeReference => "type_reference"
            case TypeQuery => "type_query"
            case TypeOperator => "type_operator"
            case IndexedAccess => "indexed_access"
            case Mapped => "mapped"
            case TemplateLiteral => "template_literal"
            case Rest => "rest"
            case Optional => "optional"
            case Enum => "enum"
            case Class => "class"
            case Namespace => "namespace"
            case ImportType => "import_type"
            case Infer => "infer"
            case Extends => "extends"
            case Typeof => "typeof"
        }
    }
}

// ============================================================================
// TSTypeAnnotation - TypeScript 类型注解
// 对应 Bun 中 TS 类型注解节点
// Bun: 解析器解析 TS 类型，转译时作为类型擦除处理
// ============================================================================

/// TypeScript 类型注解 - 对应 Bun AST 中的类型注解
/// 用于变量声明、函数参数、返回类型等的类型标注
public class TSTypeAnnotation {
    /// 类型种类
    public var kind: TSTypeKind
    /// 类型文本 (用于简单类型)
    public var typeName: String
    /// 子类型 (用于复合类型如 Array<T>, Union, Intersection 等)
    public var children: ArrayList<TSTypeAnnotation>
    /// 源码位置
    public var loc: ASTLoc

    public init(kind: TSTypeKind, typeName: String, loc: ASTLoc) {
        this.kind = kind
        this.typeName = typeName
        this.children = ArrayList<TSTypeAnnotation>()
        this.loc = loc
    }

    public init(kind: TSTypeKind, loc: ASTLoc) {
        this.kind = kind
        this.typeName = ""
        this.children = ArrayList<TSTypeAnnotation>()
        this.loc = loc
    }

    /// 添加子类型
    public func addChild(child: TSTypeAnnotation): Unit {
        children.append(child)
    }

    /// 是否为简单类型 (无子类型)
    public func isSimple(): Bool {
        return children.size == 0
    }

    /// 格式化类型为字符串
    public func toString(): String {
        if (children.size == 0) {
            return if (typeName.size > 0) { typeName } else { kind.name() }
        }
        var sb = StringBuilder()
        match (kind) {
            case Array =>
                sb.append(children[0].toString())
                sb.append("[]")
            case Union =>
                var first = true
                for (child in children) {
                    if (!first) { sb.append(" | ") }
                    sb.append(child.toString())
                    first = false
                }
            case Intersection =>
                var first = true
                for (child in children) {
                    if (!first) { sb.append(" & ") }
                    sb.append(child.toString())
                    first = false
                }
            case Tuple =>
                sb.append("[")
                var first = true
                for (child in children) {
                    if (!first) { sb.append(", ") }
                    sb.append(child.toString())
                    first = false
                }
                sb.append("]")
            case Function =>
                sb.append("(")
                var first = true
                for (i in Int64(0)..children.size - 1) {
                    if (!first) { sb.append(", ") }
                    sb.append(children[i].toString())
                    first = false
                }
                sb.append(") => ")
                if (children.size > 0) {
                    sb.append(children[children.size - 1].toString())
                }
            case _ =>
                if (typeName.size > 0) {
                    sb.append(typeName)
                    if (children.size > 0) {
                        sb.append("<")
                        var first = true
                        for (child in children) {
                            if (!first) { sb.append(", ") }
                            sb.append(child.toString())
                            first = false
                        }
                        sb.append(">")
                    }
                } else {
                    sb.append(kind.name())
                }
        }
        return sb.toString()
    }
}

// ============================================================================
// TSDecorator - TypeScript 装饰器
// 对应 Bun AST 中的装饰器节点
// Bun: 装饰器在解析器中解析，在转译时处理
// ============================================================================

/// TypeScript 装饰器 - 对应 Bun AST 中的装饰器
/// @decorator 或 @decorator(args)
public class TSDecorator {
    /// 装饰器表达式 (标识符或调用表达式)
    public var expression: ASTNode
    /// 源码位置
    public var loc: ASTLoc

    public init(expression: ASTNode, loc: ASTLoc) {
        this.expression = expression
        this.loc = loc
    }
}

// ============================================================================
// TSInterface - TypeScript 接口
// 对应 Bun AST 中的接口声明
// ============================================================================

/// TypeScript 接口属性 - 对应 Bun AST 接口成员
public class TSInterfaceProperty {
    /// 属性名称
    public var name: String
    /// 是否可选
    public var isOptional: Bool
    /// 是否只读
    public var isReadonly: Bool
    /// 是否为方法 (vs 属性)
    public var isMethod: Bool
    /// 是否为静态
    public var isStatic: Bool
    /// 类型注解
    public var typeAnnotation: ?TSTypeAnnotation
    /// 源码位置
    public var loc: ASTLoc

    public init(name: String, loc: ASTLoc) {
        this.name = name
        this.isOptional = false
        this.isReadonly = false
        this.isMethod = false
        this.isStatic = false
        this.typeAnnotation = None
        this.loc = loc
    }
}

/// TypeScript 接口声明 - 对应 Bun AST 接口声明
public class TSInterface {
    /// 接口名称
    public var name: String
    /// 泛型参数
    public var typeParameters: ArrayList<TSTypeAnnotation>
    /// 继承的接口
    public var extendsList: ArrayList<String>
    /// 属性列表
    public var properties: ArrayList<TSTypeProperty>
    /// 源码位置
    public var loc: ASTLoc
    /// 装饰器
    public var decorators: ArrayList<TSDecorator>

    public init(name: String, loc: ASTLoc) {
        this.name = name
        this.typeParameters = ArrayList<TSTypeAnnotation>()
        this.extendsList = ArrayList<String>()
        this.properties = ArrayList<TSTypeProperty>()
        this.loc = loc
        this.decorators = ArrayList<TSDecorator>()
    }

    /// 添加属性
    public func addProperty(prop: TSInterfaceProperty): Unit {
        properties.append(TSTypeProperty.fromInterfaceProperty(prop))
    }

    /// 添加继承
    public func addExtends(name: String): Unit {
        extendsList.append(name)
    }
}

// ============================================================================
// TSPropertyEntry - TypeScript 属性/方法条目 (统一类型)
// 用于接口、类型别名、类等
// ============================================================================

/// TypeScript 属性类型
public enum TSPropertyKind {
    | Property    // 普通属性
    | Method      // 方法
    | Constructor // 构造函数
    | Getter      // getter
    | Setter      // setter
    | IndexSignature // 索引签名 [key: string]: T
    | CallSignature  // 调用签名 (args) => T
}

/// TypeScript 属性条目 - 统一的属性/方法表示
public class TSTypeProperty {
    /// 属性名称
    public var name: String
    /// 属性类型
    public var kind: TSPropertyKind
    /// 是否可选
    public var isOptional: Bool
    /// 是否只读
    public var isReadonly: Bool
    /// 是否静态
    public var isStatic: Bool
    /// 类型注解
    public var typeAnnotation: ?TSTypeAnnotation
    /// 参数列表 (方法/构造函数)
    public var parameters: ArrayList<TSParameter>
    /// 返回类型 (方法)
    public var returnType: ?TSTypeAnnotation
    /// 源码位置
    public var loc: ASTLoc

    public init(name: String, kind: TSPropertyKind, loc: ASTLoc) {
        this.name = name
        this.kind = kind
        this.isOptional = false
        this.isReadonly = false
        this.isStatic = false
        this.typeAnnotation = None
        this.parameters = ArrayList<TSParameter>()
        this.returnType = None
        this.loc = loc
    }

    /// 从 TSInterfaceProperty 创建
    public static func fromInterfaceProperty(prop: TSInterfaceProperty): TSTypeProperty {
        let p = TSTypeProperty(
            prop.name,
            if (prop.isMethod) { TSPropertyKind.Method } else { TSPropertyKind.Property },
            prop.loc
        )
        p.isOptional = prop.isOptional
        p.isReadonly = prop.isReadonly
        p.isStatic = prop.isStatic
        p.typeAnnotation = prop.typeAnnotation
        return p
    }
}

// ============================================================================
// TSParameter - TypeScript 函数/方法参数
// ============================================================================

/// TypeScript 参数 - 对应 Bun AST 中的函数参数
public class TSParameter {
    /// 参数名称
    public var name: String
    /// 是否可选
    public var isOptional: Bool
    /// 是否 rest 参数
    public var isRest: Bool
    /// 类型注解
    public var typeAnnotation: ?TSTypeAnnotation
    /// 默认值
    public var defaultValue: ?ASTNode
    /// 源码位置
    public var loc: ASTLoc

    public init(name: String, loc: ASTLoc) {
        this.name = name
        this.isOptional = false
        this.isRest = false
        this.typeAnnotation = None
        this.defaultValue = None
        this.loc = loc
    }
}

// ============================================================================
// TSTypeAlias - TypeScript 类型别名
// ============================================================================

/// TypeScript 类型别名 - 对应 Bun AST 中的类型别名声明
public class TSTypeAlias {
    /// 别名名称
    public var name: String
    /// 泛型参数
    public var typeParameters: ArrayList<TSTypeAnnotation>
    /// 类型定义
    public var type: TSTypeAnnotation
    /// 源码位置
    public var loc: ASTLoc

    public init(name: String, type: TSTypeAnnotation, loc: ASTLoc) {
        this.name = name
        this.typeParameters = ArrayList<TSTypeAnnotation>()
        this.type = type
        this.loc = loc
    }
}

// ============================================================================
// TSEnumMember - TypeScript 枚举成员
// 对应 Bun ts.zig 中 TSNamespaceMember.Data 的枚举相关变体
// ============================================================================

/// TypeScript 枚举成员 - 对应 Bun AST 枚举成员
public class TSEnumMember {
    /// 成员名称
    public var name: String
    /// 成员值 (数字)
    public var numberValue: ?Float64
    /// 成员值 (字符串)
    public var stringValue: ?String
    /// 成员值 (表达式引用)
    public var isComputed: Bool
    /// 源码位置
    public var loc: ASTLoc
    /// 引用 - 对应 Bun Ref
    public var ref: Ref

    public init(name: String, loc: ASTLoc) {
        this.name = name
        this.numberValue = None
        this.stringValue = None
        this.isComputed = false
        this.loc = loc
        this.ref = Ref.NONE
    }

    /// 数字枚举成员
    public static func number(name: String, value: Float64, loc: ASTLoc): TSEnumMember {
        let m = TSEnumMember(name, loc)
        m.numberValue = Some(value)
        return m
    }

    /// 字符串枚举成员
    public static func string(name: String, value: String, loc: ASTLoc): TSEnumMember {
        let m = TSEnumMember(name, loc)
        m.stringValue = Some(value)
        return m
    }

    /// 计算值枚举成员
    public static func computed(name: String, loc: ASTLoc): TSEnumMember {
        let m = TSEnumMember(name, loc)
        m.isComputed = true
        return m
    }
}

// ============================================================================
// TSEnumDeclaration - TypeScript 枚举声明
// ============================================================================

/// TypeScript 枚举声明 - 对应 Bun AST 枚举声明
public class TSEnumDeclaration {
    /// 枚举名称
    public var name: String
    /// 成员列表
    public var members: ArrayList<TSEnumMember>
    /// 是否为 const 枚举
    public var isConst: Bool
    /// 源码位置
    public var loc: ASTLoc
    /// 枚举符号引用
    public var ref: Ref

    public init(name: String, loc: ASTLoc) {
        this.name = name
        this.members = ArrayList<TSEnumMember>()
        this.isConst = false
        this.loc = loc
        this.ref = Ref.NONE
    }

    /// 添加成员
    public func addMember(member: TSEnumMember): Unit {
        members.append(member)
    }
}

// ============================================================================
// TSNamespaceDeclaration - TypeScript 命名空间声明
// ============================================================================

/// TypeScript 命名空间声明 - 对应 Bun AST 命名空间声明
public class TSNamespaceDeclaration {
    /// 命名空间名称
    public var name: String
    /// 命名空间体 (语句列表)
    public var body: ArrayList<StmtNode>
    /// 是否有 export
    public var hasExport: Bool
    /// 源码位置
    public var loc: ASTLoc
    /// 关联的 TSNamespaceScope
    public var namespaceScope: ?TSNamespaceScope
    /// 命名空间符号引用
    public var ref: Ref

    public init(name: String, loc: ASTLoc) {
        this.name = name
        this.body = ArrayList<StmtNode>()
        this.hasExport = false
        this.loc = loc
        this.namespaceScope = None
        this.ref = Ref.NONE
    }

    /// 添加语句
    public func addStmt(stmt: StmtNode): Unit {
        body.append(stmt)
    }
}

// ============================================================================
// TSModuleDeclaration - TypeScript 模块声明 (declare module ...)
// ============================================================================

/// TypeScript 模块声明 - 对应 Bun AST 模块声明
public class TSModuleDeclaration {
    /// 模块名称
    public var name: String
    /// 是否为全局增强 (declare global)
    public var isGlobalAugmentation: Bool
    /// 模块体 (语句列表)
    public var body: ArrayList<StmtNode>
    /// 源码位置
    public var loc: ASTLoc

    public init(name: String, loc: ASTLoc) {
        this.name = name
        this.isGlobalAugmentation = (name == "global")
        this.body = ArrayList<StmtNode>()
        this.loc = loc
    }
}

// ============================================================================
// TSImportEqualsDeclaration - TypeScript import = 声明
// ============================================================================

/// TypeScript import equals 声明
/// import foo = require('bar') 或 import foo = ns.bar
public class TSImportEqualsDeclaration {
    /// 导入名称
    public var name: String
    /// 模块路径或命名空间引用
    public var modulePath: String
    /// 是否为 require 导入 (vs 命名空间导入)
    public var isRequire: Bool
    /// 源码位置
    public var loc: ASTLoc
    /// 引用
    public var ref: Ref

    public init(name: String, modulePath: String, isRequire: Bool, loc: ASTLoc) {
        this.name = name
        this.modulePath = modulePath
        this.isRequire = isRequire
        this.loc = loc
        this.ref = Ref.NONE
    }
}
