// TypeScript AST 类型扩展
// 严格翻译自: src/js_parser/ast_types.zig
//   Bun 的 TypeScript 解析器扩展了基础 AST，添加了完整的类型系统节点
//   包括: TSType 系列, TSInterfaceDecl, TSEnumDecl, TSModuleDecl, TSDeclare 等
package bao_parser

import bao_core.*
import bao_collections.*

// ============================================================================
// TSType - TypeScript 类型节点
// 严格翻译自: src/js_parser/ast_types.zig
//   Bun 使用 TSType 联合体表示所有 TypeScript 类型表达式
//   对应 TypeScript compiler 的 TypeNode 体系
// ============================================================================

/// TypeScript 类型标签 - 对应 Bun TSType.Data 联合体标签
public enum TSTypeTag {
    // 关键字类型 (keyword types)
    | TSAnyKeyword           // any
    | TSUnknownKeyword       // unknown
    | TSNumberKeyword        // number
    | TSStringKeyword        // string
    | TSBooleanKeyword       // boolean
    | TSVoidKeyword          // void
    | TSUndefinedKeyword     // undefined
    | TSNullKeyword          // null
    | TSNeverKeyword         // never
    | TSObjectKeyword        // object
    | TSSymbolKeyword        // symbol
    | TSBigIntKeyword        // bigint

    // 复合类型
    | TSReference            // T, Foo<T>, A.B
    | TSUnion                // A | B | C
    | TSIntersection         // A & B & C
    | TSConditional          // T extends U ? X : Y
    | TSMapped               // { [K in keyof T]: V }
    | TSIndexedAccess        // T[K]
    | TSTypeOperator         // keyof T, readonly T, unique T
    | TSTypeQuery            // typeof x
    | TSTypeLiteral          // { a: string; b: number }
    | TSTuple                // [string, number]
    | TSNamedTupleMember     // [name: string]
    | TSArray                // T[]
    | TSFunction             // (a: string) => number
    | TSConstructor          // new (a: string) => Foo
    | TSTypePredicate        // x is string
    | TSThisType             // this
    | TSImport               // import("module").Type
    | TSParenthesized        // (T)
    | TSTemplateLiteral      // `hello ${string}`
    | TSRest                 // ...T (tuple rest)
    | TSOptional             // T? (tuple optional)
    | TSLiteral              // 字面量类型
    | TSEnumName             // 枚举名称引用

    // 类型表达式
    | TSTypeAnnotation       // : Type
    | TSTypeParameter        // T extends U = V
    | TSTypeParameterInstantiation // <T, U>
}

/// TypeScript 类型节点 - 对应 Bun TSType
/// Bun: struct { loc: Loc, data: Data }
/// Data 是 union(enum)，仓颉用 TSTypeTag + 各自数据字段
public class TSType {
    public var loc: Loc
    public var tag: TSTypeTag

    // --- 字面量字段 ---
    /// 字符串值 - 用于 TSStringKeyword, TSLiteral (字符串字面量)
    public var stringValue: String
    /// 数字值 - 用于 TSNumberKeyword, TSLiteral (数字字面量)
    public var numberValue: Float64
    /// 布尔值 - 用于 TSBooleanKeyword, TSLiteral (布尔字面量)
    public var boolValue: Bool

    // --- 引用字段 ---
    /// 类型名称 - 用于 TSReference, TSEnumName
    public var typeName: String
    /// 类型表达式名称 (带命名空间, 如 "A.B") - 对应 Bun TSReference.typeName
    public var typeNameExpr: ?Expr

    // --- 类型参数字段 ---
    /// 类型参数列表 - 用于 TSReference<...>, TSFunction, TSConstructor
    public var typeParams: ArrayList<TSType>
    /// 类型参数声明列表 - 用于泛型 <T extends U>
    public var typeParamDecls: ArrayList<TSTypeParameterDecl>

    // --- 联合/交叉类型字段 ---
    /// 联合/交叉类型成员 - 用于 TSUnion, TSIntersection
    public var types: ArrayList<TSType>

    // --- 条件类型字段 ---
    /// 条件类型: T extends U ? X : Y
    public var checkType: ?TSType    // T
    public var extendsType: ?TSType  // U
    public var trueType: ?TSType     // X
    public var falseType: ?TSType    // Y

    // --- 映射类型字段 ---
    /// 映射类型: { [K in keyof T]: V }
    public var typeParam: ?TSTypeParameterDecl  // K in keyof T
    public var mappedReadonly: TSReadonlyModifier  // +/-readonly
    public var mappedOptional: TSOptionalModifier // +/-?
    public var mappedConstraint: ?TSType        // keyof T (constraint)

    // --- 索引访问类型字段 ---
    /// 索引访问: T[K]
    public var objectType: ?TSType    // T
    public var indexType: ?TSType     // K

    // --- 类型操作符字段 ---
    /// keyof T, readonly T, unique T, infer T
    public var operator: TSTypeOperatorKind
    public var operand: ?TSType

    // --- 类型查询字段 ---
    /// typeof x - 查询表达式
    public var queryExpr: ?Expr

    // --- 函数/构造器类型字段 ---
    /// 函数参数列表
    public var params: ArrayList<TSFnParam>
    /// 返回类型
    public var returnType: ?TSType

    // --- 元组类型字段 ---
    /// 元组元素类型
    public var elements: ArrayList<TSType>

    // --- 数组类型字段 ---
    /// 数组元素类型 - T[]
    public var elementType: ?TSType

    // --- 类型字面量字段 ---
    /// 对象类型成员
    public var members: ArrayList<TSTypeElement>

    // --- 模板字面量类型字段 ---
    /// 模板字面量: `hello ${string}`
    public var templateParts: ArrayList<TSTemplateLiteralPart>

    // --- 类型谓词字段 ---
    /// x is string
    public var predicateName: String
    public var predicateIsAsserts: Bool

    // --- 导入类型字段 ---
    /// import("module").Type
    public var importPath: String
    public var importQualifier: String

    // --- 圆括号字段 ---
    /// (T) 包装的类型
    public var wrappedType: ?TSType

    // --- rest/optional ---
    /// ...T
    public var restType: ?TSType

    public init(loc: Loc, tag: TSTypeTag) {
        this.loc = loc
        this.tag = tag
        stringValue = ""
        numberValue = 0.0
        boolValue = false
        typeName = ""
        typeNameExpr = None
        typeParams = ArrayList<TSType>()
        typeParamDecls = ArrayList<TSTypeParameterDecl>()
        types = ArrayList<TSType>()
        checkType = None
        extendsType = None
        trueType = None
        falseType = None
        typeParam = None
        mappedReadonly = TSReadonlyModifier.None
        mappedOptional = TSOptionalModifier.None
        mappedConstraint = None
        objectType = None
        indexType = None
        operator = TSTypeOperatorKind.Keyof
        operand = None
        queryExpr = None
        params = ArrayList<TSFnParam>()
        returnType = None
        elements = ArrayList<TSType>()
        elementType = None
        members = ArrayList<TSTypeElement>()
        templateParts = ArrayList<TSTemplateLiteralPart>()
        predicateName = ""
        predicateIsAsserts = false
        importPath = ""
        importQualifier = ""
        wrappedType = None
        restType = None
    }

    // === 工厂方法 ===

    /// any - 对应 Bun TSAnyKeyword
    public static func any(loc: Loc): TSType {
        return TSType(loc, TSTypeTag.TSAnyKeyword)
    }

    /// unknown
    public static func unknown(loc: Loc): TSType {
        return TSType(loc, TSTypeTag.TSUnknownKeyword)
    }

    /// number
    public static func number(loc: Loc): TSType {
        return TSType(loc, TSTypeTag.TSNumberKeyword)
    }

    /// string
    public static func string(loc: Loc): TSType {
        return TSType(loc, TSTypeTag.TSStringKeyword)
    }

    /// boolean
    public static func boolean(loc: Loc): TSType {
        return TSType(loc, TSTypeTag.TSBooleanKeyword)
    }

    /// void
    public static func void_(loc: Loc): TSType {
        return TSType(loc, TSTypeTag.TSVoidKeyword)
    }

    /// undefined
    public static func undefined(loc: Loc): TSType {
        return TSType(loc, TSTypeTag.TSUndefinedKeyword)
    }

    /// null
    public static func null_(loc: Loc): TSType {
        return TSType(loc, TSTypeTag.TSNullKeyword)
    }

    /// never
    public static func never(loc: Loc): TSType {
        return TSType(loc, TSTypeTag.TSNeverKeyword)
    }

    /// object
    public static func object_(loc: Loc): TSType {
        return TSType(loc, TSTypeTag.TSObjectKeyword)
    }

    /// symbol
    public static func symbol(loc: Loc): TSType {
        return TSType(loc, TSTypeTag.TSSymbolKeyword)
    }

    /// bigint
    public static func bigInt(loc: Loc): TSType {
        return TSType(loc, TSTypeTag.TSBigIntKeyword)
    }

    /// this
    public static func this_(loc: Loc): TSType {
        return TSType(loc, TSTypeTag.TSThisType)
    }

    /// 类型引用 - 对应 Bun TSReference
    /// T 或 Foo<T> 或 A.B<T>
    public static func reference(loc: Loc, name: String, typeArgs: ArrayList<TSType>): TSType {
        let t = TSType(loc, TSTypeTag.TSReference)
        t.typeName = name
        t.typeParams = typeArgs
        return t
    }

    /// 命名空间限定类型引用 - A.B<T>
    public static func qualifiedReference(loc: Loc, expr: Expr, typeArgs: ArrayList<TSType>): TSType {
        let t = TSType(loc, TSTypeTag.TSReference)
        t.typeNameExpr = Some(expr)
        t.typeParams = typeArgs
        return t
    }

    /// 联合类型 - 对应 Bun TSUnion
    /// A | B | C
    public static func union(loc: Loc, types: ArrayList<TSType>): TSType {
        let t = TSType(loc, TSTypeTag.TSUnion)
        t.types = types
        return t
    }

    /// 交叉类型 - 对应 Bun TSIntersection
    /// A & B & C
    public static func intersection(loc: Loc, types: ArrayList<TSType>): TSType {
        let t = TSType(loc, TSTypeTag.TSIntersection)
        t.types = types
        return t
    }

    /// 条件类型 - 对应 Bun TSConditional
    /// T extends U ? X : Y
    public static func conditional(loc: Loc, checkType: TSType, extendsType: TSType,
                                    trueType: TSType, falseType: TSType): TSType {
        let t = TSType(loc, TSTypeTag.TSConditional)
        t.checkType = Some(checkType)
        t.extendsType = Some(extendsType)
        t.trueType = Some(trueType)
        t.falseType = Some(falseType)
        return t
    }

    /// 映射类型 - 对应 Bun TSMapped
    /// { [K in keyof T]: V }
    public static func mapped(loc: Loc, param: TSTypeParameterDecl, readonly: TSReadonlyModifier,
                               optional: TSOptionalModifier, resultType: ?TSType): TSType {
        let t = TSType(loc, TSTypeTag.TSMapped)
        t.typeParam = Some(param)
        t.mappedReadonly = readonly
        t.mappedOptional = optional
        t.returnType = resultType
        return t
    }

    /// 索引访问类型 - 对应 Bun TSIndexedAccess
    /// T[K]
    public static func indexedAccess(loc: Loc, objectType: TSType, indexType: TSType): TSType {
        let t = TSType(loc, TSTypeTag.TSIndexedAccess)
        t.objectType = Some(objectType)
        t.indexType = Some(indexType)
        return t
    }

    /// 类型操作符 - 对应 Bun TSTypeOperator
    /// keyof T, readonly T, unique T
    public static func typeOperator(loc: Loc, op: TSTypeOperatorKind, operand: TSType): TSType {
        let t = TSType(loc, TSTypeTag.TSTypeOperator)
        t.operator = op
        t.operand = Some(operand)
        return t
    }

    /// 类型查询 - 对应 Bun TSTypeQuery
    /// typeof x
    public static func typeQuery(loc: Loc, expr: Expr): TSType {
        let t = TSType(loc, TSTypeTag.TSTypeQuery)
        t.queryExpr = Some(expr)
        return t
    }

    /// 类型字面量 - 对应 Bun TSTypeLiteral
    /// { a: string; b: number }
    public static func typeLiteral(loc: Loc, members: ArrayList<TSTypeElement>): TSType {
        let t = TSType(loc, TSTypeTag.TSTypeLiteral)
        t.members = members
        return t
    }

    /// 元组类型 - 对应 Bun TSTuple
    /// [string, number]
    public static func tuple(loc: Loc, elements: ArrayList<TSType>): TSType {
        let t = TSType(loc, TSTypeTag.TSTuple)
        t.elements = elements
        return t
    }

    /// 命名元组成员 - 对应 Bun TSNamedTupleMember
    /// [name: string]
    public static func namedTupleMember(loc: Loc, name: String, elementType: TSType, optional: Bool): TSType {
        let t = TSType(loc, TSTypeTag.TSNamedTupleMember)
        t.typeName = name
        t.elementType = Some(elementType)
        t.mappedOptional = if (optional) { TSOptionalModifier.Optional } else { TSOptionalModifier.None }
        return t
    }

    /// 数组类型 - 对应 Bun TSArray
    /// T[]
    public static func array(loc: Loc, elementType: TSType): TSType {
        let t = TSType(loc, TSTypeTag.TSArray)
        t.elementType = Some(elementType)
        return t
    }

    /// 函数类型 - 对应 Bun TSFunction
    /// (a: string) => number
    public static func function(loc: Loc, params: ArrayList<TSFnParam>, returnType: TSType,
                                 typeParams: ArrayList<TSTypeParameterDecl>): TSType {
        let t = TSType(loc, TSTypeTag.TSFunction)
        t.params = params
        t.returnType = Some(returnType)
        t.typeParamDecls = typeParams
        return t
    }

    /// 构造器类型 - 对应 Bun TSConstructor
    /// new (a: string) => Foo
    public static func constructor(loc: Loc, params: ArrayList<TSFnParam>, returnType: TSType): TSType {
        let t = TSType(loc, TSTypeTag.TSConstructor)
        t.params = params
        t.returnType = Some(returnType)
        return t
    }

    /// 类型谓词 - 对应 Bun TSTypePredicate
    /// x is string / asserts x is string
    public static func typePredicate(loc: Loc, name: String, type: ?TSType, asserts: Bool): TSType {
        let t = TSType(loc, TSTypeTag.TSTypePredicate)
        t.predicateName = name
        t.returnType = type
        t.predicateIsAsserts = asserts
        return t
    }

    /// 导入类型 - 对应 Bun TSImport
    /// import("module").Type
    public static func importType(loc: Loc, path: String, qualifier: String): TSType {
        let t = TSType(loc, TSTypeTag.TSImport)
        t.importPath = path
        t.importQualifier = qualifier
        return t
    }

    /// 圆括号类型 - 对应 Bun TSParenthesized
    /// (T)
    public static func parenthesized(loc: Loc, wrapped: TSType): TSType {
        let t = TSType(loc, TSTypeTag.TSParenthesized)
        t.wrappedType = Some(wrapped)
        return t
    }

    /// 模板字面量类型 - 对应 Bun TSTemplateLiteral
    /// `hello ${string}`
    public static func templateLiteral(loc: Loc, parts: ArrayList<TSTemplateLiteralPart>): TSType {
        let t = TSType(loc, TSTypeTag.TSTemplateLiteral)
        t.templateParts = parts
        return t
    }

    /// Rest 类型 - 对应 Bun TSRest
    /// ...T
    public static func rest(loc: Loc, inner: TSType): TSType {
        let t = TSType(loc, TSTypeTag.TSRest)
        t.restType = Some(inner)
        return t
    }

    /// Optional 类型 - 对应 Bun TSOptional
    /// T?
    public static func optional(loc: Loc, inner: TSType): TSType {
        let t = TSType(loc, TSTypeTag.TSOptional)
        t.wrappedType = Some(inner)
        return t
    }

    /// 字面量类型 - 对应 Bun TSLiteral
    /// "hello" | 42 | true
    public static func literal(loc: Loc, value: Expr): TSType {
        let t = TSType(loc, TSTypeTag.TSLiteral)
        // 根据表达式确定值
        match (value.tag) {
            case ExprTag.String =>
                t.stringValue = value.stringValue.toString()
            case ExprTag.Number =>
                t.numberValue = value.numberValue
            case ExprTag.Boolean =>
                t.boolValue = value.boolValue
            case _ => ()
        }
        return t
    }

    /// 枚举名称引用 - 对应 Bun TSEnumName
    public static func enumName(loc: Loc, name: String): TSType {
        let t = TSType(loc, TSTypeTag.TSEnumName)
        t.typeName = name
        return t
    }

    /// 类型注解 - 对应 Bun TSTypeAnnotation
    /// : Type
    public static func annotation(loc: Loc, type: TSType): TSType {
        let t = TSType(loc, TSTypeTag.TSTypeAnnotation)
        t.wrappedType = Some(type)
        return t
    }

    /// 类型参数实例化 - 对应 Bun TSTypeParameterInstantiation
    /// <T, U>
    public static func typeParamInstantiation(loc: Loc, params: ArrayList<TSType>): TSType {
        let t = TSType(loc, TSTypeTag.TSTypeParameterInstantiation)
        t.typeParams = params
        return t
    }

    /// 获取被包装的实际类型 (跳过圆括号)
    public func unwrap(): TSType {
        match (tag) {
            case TSTypeTag.TSParenthesized =>
                match (wrappedType) {
                    case Some(t) => return t.unwrap()
                    case None => return this
                }
            case _ => return this
        }
    }

    /// 类型描述字符串 (用于调试)
    public func describe(): String {
        match (tag) {
            case TSTypeTag.TSAnyKeyword => "any"
            case TSTypeTag.TSUnknownKeyword => "unknown"
            case TSTypeTag.TSNumberKeyword => "number"
            case TSTypeTag.TSStringKeyword => "string"
            case TSTypeTag.TSBooleanKeyword => "boolean"
            case TSTypeTag.TSVoidKeyword => "void"
            case TSTypeTag.TSUndefinedKeyword => "undefined"
            case TSTypeTag.TSNullKeyword => "null"
            case TSTypeTag.TSNeverKeyword => "never"
            case TSTypeTag.TSObjectKeyword => "object"
            case TSTypeTag.TSSymbolKeyword => "symbol"
            case TSTypeTag.TSBigIntKeyword => "bigint"
            case TSTypeTag.TSThisType => "this"
            case TSTypeTag.TSReference => typeName
            case TSTypeTag.TSUnion => "union"
            case TSTypeTag.TSIntersection => "intersection"
            case TSTypeTag.TSConditional => "conditional"
            case TSTypeTag.TSMapped => "mapped"
            case TSTypeTag.TSIndexedAccess => "indexed_access"
            case TSTypeTag.TSTypeOperator => "type_operator"
            case TSTypeTag.TSTypeQuery => "typeof"
            case TSTypeTag.TSTypeLiteral => "type_literal"
            case TSTypeTag.TSTuple => "tuple"
            case TSTypeTag.TSNamedTupleMember => "named_tuple_member"
            case TSTypeTag.TSArray => "array"
            case TSTypeTag.TSFunction => "function_type"
            case TSTypeTag.TSConstructor => "constructor_type"
            case TSTypeTag.TSTypePredicate => "type_predicate"
            case TSTypeTag.TSImport => "import_type"
            case TSTypeTag.TSParenthesized => "parenthesized"
            case TSTypeTag.TSTemplateLiteral => "template_literal"
            case TSTypeTag.TSRest => "rest"
            case TSTypeTag.TSOptional => "optional"
            case TSTypeTag.TSLiteral => "literal"
            case TSTypeTag.TSEnumName => "enum"
            case TSTypeTag.TSTypeAnnotation => "annotation"
            case TSTypeTag.TSTypeParameter => "type_param"
            case TSTypeTag.TSTypeParameterInstantiation => "type_param_instantiation"
        }
    }
}

// ============================================================================
// TypeScript 辅助类型
// 严格翻译自: src/js_parser/ast_types.zig 辅助结构
// ============================================================================

/// 类型操作符类型 - 对应 Bun TSTypeOperator.Kind
public enum TSTypeOperatorKind {
    | Keyof     // keyof T
    | Readonly  // readonly T
    | Unique    // unique symbol
    | Infer     // infer T (条件类型中)
}

/// 映射类型 readonly 修饰符 - 对应 Bun TSReadonlyModifier
public enum TSReadonlyModifier {
    | None       // 无修饰
    | Readonly   // +readonly
    | Mutable    // -readonly
}

/// 映射类型 optional 修饰符 - 对应 Bun TSOptionalModifier
public enum TSOptionalModifier {
    | None       // 无修饰
    | Optional   // +?
    | Required   // -? (去除可选)
}

/// 函数类型参数 - 对应 Bun TSFnParam
public class TSFnParam {
    public var loc: Loc
    public var name: String
    public var type_: ?TSType
    public var isRest: Bool
    public var isOptional: Bool
    public var initializer: ?Expr

    public init(loc: Loc, name: String) {
        this.loc = loc
        this.name = name
        type_ = None
        isRest = false
        isOptional = false
        initializer = None
    }

    public init(loc: Loc, name: String, type_: TSType) {
        this.loc = loc
        this.name = name
        this.type_ = Some(type_)
        isRest = false
        isOptional = false
        initializer = None
    }
}

/// 类型参数声明 - 对应 Bun TSTypeParameter
/// T extends U = V
public class TSTypeParameterDecl {
    public var loc: Loc
    public var name: String
    public var constraint: ?TSType     // extends U
    public var default_: ?TSType       // = V
    public var isIn: Bool              // in (映射类型)

    public init(loc: Loc, name: String) {
        this.loc = loc
        this.name = name
        constraint = None
        default_ = None
        isIn = false
    }

    public init(loc: Loc, name: String, constraint: ?TSType, default_: ?TSType) {
        this.loc = loc
        this.name = name
        this.constraint = constraint
        this.default_ = default_
        isIn = false
    }
}

/// 模板字面量类型部分 - 对应 Bun TSTemplateLiteralPart
public class TSTemplateLiteralPart {
    /// 文本部分 (非表达式)
    public var text: String
    /// 表达式部分 (类型)
    public var type_: ?TSType

    public init(text: String) {
        this.text = text
        type_ = None
    }

    public init(type_: TSType) {
        this.text = ""
        this.type_ = Some(type_)
    }

    public init(text: String, type_: ?TSType) {
        this.text = text
        this.type_ = type_
    }
}

/// 类型元素 (对象类型字面量成员) - 对应 Bun TSTypeElement
public class TSTypeElement {
    public var loc: Loc
    public var tag: TSTypeElementTag
    public var name: String
    public var nameExpr: ?Expr
    public var type_: ?TSType
    public var params: ArrayList<TSFnParam>
    public var returnType: ?TSType
    public var typeParams: ArrayList<TSTypeParameterDecl>
    public var isOptional: Bool
    public var isReadonly: Bool
    public var isStatic: Bool
    public var isAbstract: Bool
    public var isComputed: Bool
    public var accessibility: TSAccessibility
    public var initializer: ?Expr

    public init(loc: Loc, tag: TSTypeElementTag) {
        this.loc = loc
        this.tag = tag
        name = ""
        nameExpr = None
        type_ = None
        params = ArrayList<TSFnParam>()
        returnType = None
        typeParams = ArrayList<TSTypeParameterDecl>()
        isOptional = false
        isReadonly = false
        isStatic = false
        isAbstract = false
        isComputed = false
        accessibility = TSAccessibility.None
        initializer = None
    }
}

/// 类型元素标签 - 对应 Bun TSTypeElement.Kind
public enum TSTypeElementTag {
    | PropertySignature    // prop: Type
    | MethodSignature      // method(): Type
    | CallSignature        // (params): Type
    | ConstructSignature   // new (params): Type
    | IndexSignature       // [key: string]: Type
    | GetAccessor          // get prop(): Type
    | SetAccessor          // set prop(value: Type)
}

/// 可访问性修饰符 - 对应 Bun TSAccessibility
public enum TSAccessibility {
    | None
    | Public
    | Protected
    | Private
}

// ============================================================================
// TSInterfaceDecl - TypeScript 接口声明
// 严格翻译自: src/js_parser/p.ts.zig TSInterface
//   pub const TSType = struct { ... interface: ?Interface }
//   pub const Interface = struct { name, body, extends, type_params }
// ============================================================================

/// TypeScript 接口声明 - 对应 Bun TSInterface
public class TSInterfaceDecl {
    public var loc: Loc
    public var name: String
    public var nameRef: Ref
    public var typeParams: ArrayList<TSTypeParameterDecl>
    public var extends_: ArrayList<TSType>
    public var body: ArrayList<TSTypeElement>
    public var decorators: ArrayList<Expr>
    public var isExport: Bool
    public var isDefault: Bool
    public var isDeclare: Bool

    public init(loc: Loc, name: String) {
        this.loc = loc
        this.name = name
        nameRef = Ref.NONE
        typeParams = ArrayList<TSTypeParameterDecl>()
        extends_ = ArrayList<TSType>()
        body = ArrayList<TSTypeElement>()
        decorators = ArrayList<Expr>()
        isExport = false
        isDefault = false
        isDeclare = false
    }
}

// ============================================================================
// TSEnumDecl - TypeScript 枚举声明
// 严格翻译自: src/js_parser/p.ts.zig TSEnum
//   pub const Enum = struct { name, members, is_const, ... }
// ============================================================================

/// TypeScript 枚举成员 - 对应 Bun TSEnumMember
public class TSEnumMember {
    public var loc: Loc
    public var name: String
    public var nameExpr: ?Expr     // computed name
    public var value: ?Expr        // 初始值
    public var isComputed: Bool    // computed property name

    public init(loc: Loc, name: String) {
        this.loc = loc
        this.name = name
        nameExpr = None
        value = None
        isComputed = false
    }

    public init(loc: Loc, name: String, value: Expr) {
        this.loc = loc
        this.name = name
        nameExpr = None
        this.value = Some(value)
        isComputed = false
    }
}

/// TypeScript 枚举声明 - 对应 Bun TSEnum
public class TSEnumDecl {
    public var loc: Loc
    public var name: String
    public var nameRef: Ref
    public var members: ArrayList<TSEnumMember>
    public var isConst: Bool
    public var isExport: Bool
    public var isDeclare: Bool
    public var isAmbient: Bool

    public init(loc: Loc, name: String) {
        this.loc = loc
        this.name = name
        nameRef = Ref.NONE
        members = ArrayList<TSEnumMember>()
        isConst = false
        isExport = false
        isDeclare = false
        isAmbient = false
    }
}

// ============================================================================
// TSModuleDecl - TypeScript 命名空间/模块声明
// 严格翻译自: src/js_parser/p.ts.zig TSModuleDecl
//   declare namespace Foo { ... }
//   declare module "foo" { ... }
// ============================================================================

/// TypeScript 命名空间/模块声明 - 对应 Bun TSModuleDecl
public class TSModuleDecl {
    public var loc: Loc
    public var name: String
    public var nameRef: Ref
    /// 是否为外部模块 (引号括起的名称, 如 "foo")
    public var isExternal: Bool
    /// 命名空间体
    public var body: ArrayList<Stmt>
    public var isExport: Bool
    public var isDeclare: Bool
    public var isGlobal: Bool

    public init(loc: Loc, name: String) {
        this.loc = loc
        this.name = name
        nameRef = Ref.NONE
        isExternal = false
        body = ArrayList<Stmt>()
        isExport = false
        isDeclare = false
        isGlobal = false
    }
}

// ============================================================================
// TSDeclare - TypeScript 声明节点
// 严格翻译自: src/js_parser/p.ts.zig declare 声明
//   declare class Foo { ... }
//   declare function foo(): void
//   declare var x: string
//   declare const x: string
// ============================================================================

/// TypeScript 声明 - 对应 Bun TSDeclare
public class TSDeclare {
    public var loc: Loc
    public var tag: TSDeclareTag
    public var name: String
    public var nameRef: Ref
    public var type_: ?TSType
    public var fn: ?GFn
    public var classData: ?GClass
    public var interfaceDecl: ?TSInterfaceDecl
    public var enumDecl: ?TSEnumDecl
    public var moduleDecl: ?TSModuleDecl
    public var typeParams: ArrayList<TSTypeParameterDecl>
    public var isExport: Bool
    public var isDefault: Bool

    public init(loc: Loc, tag: TSDeclareTag) {
        this.loc = loc
        this.tag = tag
        name = ""
        nameRef = Ref.NONE
        type_ = None
        fn = None
        classData = None
        interfaceDecl = None
        enumDecl = None
        moduleDecl = None
        typeParams = ArrayList<TSTypeParameterDecl>()
        isExport = false
        isDefault = false
    }
}

/// TypeScript 声明类型标签 - 对应 Bun TSDeclare.Kind
public enum TSDeclareTag {
    | Class       // declare class
    | Function    // declare function
    | Variable    // declare var
    | Const       // declare const
    | Let         // declare let
    | Interface   // declare interface
    | Enum        // declare enum
    | Module      // declare module / namespace
    | Type        // declare type
    | Global      // declare global
}

// ============================================================================
// TSTypeAliasDecl - TypeScript 类型别名声明
// 严格翻译自: src/js_parser/p.ts.zig TSTypeAlias
//   type T = ...
// ============================================================================

/// TypeScript 类型别名声明 - 对应 Bun TSTypeAlias
public class TSTypeAliasDecl {
    public var loc: Loc
    public var name: String
    public var nameRef: Ref
    public var typeParams: ArrayList<TSTypeParameterDecl>
    public var type_: TSType
    public var isExport: Bool
    public var isDeclare: Bool

    public init(loc: Loc, name: String, type_: TSType) {
        this.loc = loc
        this.name = name
        nameRef = Ref.NONE
        typeParams = ArrayList<TSTypeParameterDecl>()
        this.type_ = type_
        isExport = false
        isDeclare = false
    }
}

// ============================================================================
// TSSatisfiesExpr - TypeScript satisfies 表达式
// 严格翻译自: src/js_parser/p.ts.zig satisfies
//   expr satisfies Type
// ============================================================================

/// TypeScript satisfies 表达式 - 对应 Bun TSSatisfies
public class TSSatisfiesExpr {
    public var loc: Loc
    public var expr: Expr
    public var type_: TSType

    public init(loc: Loc, expr: Expr, type_: TSType) {
        this.loc = loc
        this.expr = expr
        this.type_ = type_
    }
}

// ============================================================================
// TSAsExpr - TypeScript as 表达式
// 严格翻译自: src/js_parser/p.ts.zig as
//   expr as Type
// ============================================================================

/// TypeScript as 表达式 - 对应 Bun TSAs
public class TSAsExpr {
    public var loc: Loc
    public var expr: Expr
    public var type_: TSType

    public init(loc: Loc, expr: Expr, type_: TSType) {
        this.loc = loc
        this.expr = expr
        this.type_ = type_
    }
}

// ============================================================================
// TSTypeAssertion - TypeScript 尖括号类型断言
// 严格翻译自: src/js_parser/p.ts.zig type assertion
//   <Type>expr
// ============================================================================

/// TypeScript 尖括号类型断言 - 对应 Bun TSTypeAssertion
public class TSTypeAssertion {
    public var loc: Loc
    public var expr: Expr
    public var type_: TSType

    public init(loc: Loc, expr: Expr, type_: TSType) {
        this.loc = loc
        this.expr = expr
        this.type_ = type_
    }
}

// ============================================================================
// TSNonNullExpr - TypeScript 非空断言
// 严格翻译自: src/js_parser/p.ts.zig non-null assertion
//   expr.getOrThrow()
// ============================================================================

/// TypeScript 非空断言 - 对应 Bun TSNonNull
public class TSNonNullExpr {
    public var loc: Loc
    public var expr: Expr

    public init(loc: Loc, expr: Expr) {
        this.loc = loc
        this.expr = expr
    }
}

// ============================================================================
// TSDecorator - TypeScript 装饰器
// 严格翻译自: src/js_parser/p.ts.zig decorators
//   @decorator
//   @decoratorFactory(args)
// ============================================================================

/// TypeScript 装饰器 - 对应 Bun Decorator
public class TSDecorator {
    public var loc: Loc
    public var expr: Expr

    public init(loc: Loc, expr: Expr) {
        this.loc = loc
        this.expr = expr
    }
}

// ============================================================================
// TSModifiers - TypeScript 修饰符集合
// 严格翻译自: src/js_parser/p.ts.zig modifiers
//   组合: abstract, declare, override, private, protected, public,
//         readonly, static, async, out, accessor
// ============================================================================

/// TypeScript 修饰符集合 - 对应 Bun TSModifiers
public class TSModifiers {
    public var isAbstract: Bool
    public var isDeclare: Bool
    public var isOverride: Bool
    public var isPrivate: Bool
    public var isProtected: Bool
    public var isPublic: Bool
    public var isReadonly: Bool
    public var isStatic: Bool
    public var isAsync: Bool
    public var isOut: Bool
    public var isAccessor: Bool
    public var isConst: Bool

    public init() {
        isAbstract = false
        isDeclare = false
        isOverride = false
        isPrivate = false
        isProtected = false
        isPublic = false
        isReadonly = false
        isStatic = false
        isAsync = false
        isOut = false
        isAccessor = false
        isConst = false
    }

    /// 从关键字列表解析修饰符
    public static func parse(keywords: ArrayList<String>): TSModifiers {
        let m = TSModifiers()
        for (kw in keywords) {
            match (kw) {
                case "abstract" => m.isAbstract = true
                case "declare" => m.isDeclare = true
                case "override" => m.isOverride = true
                case "private" => m.isPrivate = true
                case "protected" => m.isProtected = true
                case "public" => m.isPublic = true
                case "readonly" => m.isReadonly = true
                case "static" => m.isStatic = true
                case "async" => m.isAsync = true
                case "out" => m.isOut = true
                case "accessor" => m.isAccessor = true
                case "const" => m.isConst = true
                case _ => ()
            }
        }
        return m
    }

    /// 获取可访问性
    public func accessibility(): TSAccessibility {
        if (isPrivate) { return TSAccessibility.Private }
        if (isProtected) { return TSAccessibility.Protected }
        if (isPublic) { return TSAccessibility.Public }
        return TSAccessibility.None
    }

    /// 是否有任何修饰符
    public func hasAny(): Bool {
        return isAbstract || isDeclare || isOverride || isPrivate ||
               isProtected || isPublic || isReadonly || isStatic ||
               isAsync || isOut || isAccessor || isConst
    }
}

// ============================================================================
// TSImportSpecifier - TypeScript import 类型说明符
// 严格翻译自: src/js_parser/p.ts.zig import type
//   import type { Foo, Bar as Baz } from "module"
//   import { type Foo, type Bar as Baz } from "module"
// ============================================================================

/// TypeScript import type 说明符 - 对应 Bun TSImportSpecifier
public class TSImportSpecifier {
    public var loc: Loc
    public var name: String
    public var alias: String
    public var isType: Bool     // import { type Foo }

    public init(loc: Loc, name: String) {
        this.loc = loc
        this.name = name
        alias = name
        isType = false
    }

    public init(loc: Loc, name: String, alias: String, isType: Bool) {
        this.loc = loc
        this.name = name
        this.alias = alias
        this.isType = isType
    }
}

// ============================================================================
// TSExportAssignment - TypeScript export assignment
// 严格翻译自: src/js_parser/p.ts.zig export assignment
//   export = expr
//   export default expr
//   export as namespace name
// ============================================================================

/// TypeScript export 赋值 - 对应 Bun TSExportAssignment
public class TSExportAssignment {
    public var loc: Loc
    public var tag: TSExportAssignmentTag
    public var expr: ?Expr
    public var name: String

    public init(loc: Loc, tag: TSExportAssignmentTag) {
        this.loc = loc
        this.tag = tag
        expr = None
        name = ""
    }
}

/// export 赋值类型 - 对应 Bun TSExportAssignment.Kind
public enum TSExportAssignmentTag {
    | Default       // export default
    | Equals        // export =
    | Namespace     // export as namespace
}

// ============================================================================
// TSPropertySignature - TypeScript 属性签名扩展 (用于 GProperty)
// 严格翻译自: src/js_parser/p.ts.zig class property with TS extensions
// ============================================================================

/// TypeScript 类属性扩展 - 对应 Bun TSProperty
public class TSPropertyExtension {
    public var typeAnnotation: ?TSType
    public var isAbstract: Bool
    public var isDeclare: Bool
    public var isOptional: Bool
    public var isReadonly: Bool
    public var isOverride: Bool
    public var accessibility: TSAccessibility
    public var decorators: ArrayList<TSDecorator>

    public init() {
        typeAnnotation = None
        isAbstract = false
        isDeclare = false
        isOptional = false
        isReadonly = false
        isOverride = false
        accessibility = TSAccessibility.None
        decorators = ArrayList<TSDecorator>()
    }
}

// ============================================================================
// TSFunctionExtension - TypeScript 函数扩展
// 严格翻译自: src/js_parser/p.ts.zig function with TS extensions
// ============================================================================

/// TypeScript 函数扩展 - 对应 Bun TSFunctionExtension
public class TSFunctionExtension {
    public var returnType: ?TSType
    public var typeParams: ArrayList<TSTypeParameterDecl>
    public var paramTypes: ArrayList<TSType>
    public var isAbstract: Bool
    public var isDeclare: Bool
    public var isOverride: Bool
    public var accessibility: TSAccessibility
    public var decorators: ArrayList<TSDecorator>

    public init() {
        returnType = None
        typeParams = ArrayList<TSTypeParameterDecl>()
        paramTypes = ArrayList<TSType>()
        isAbstract = false
        isDeclare = false
        isOverride = false
        accessibility = TSAccessibility.None
        decorators = ArrayList<TSDecorator>()
    }
}

// ============================================================================
// TSClassExtension - TypeScript 类扩展
// 严格翻译自: src/js_parser/p.ts.zig class with TS extensions
// ============================================================================

/// TypeScript 类扩展 - 对应 Bun TSClassExtension
public class TSClassExtension {
    public var typeParams: ArrayList<TSTypeParameterDecl>
    public var implements_: ArrayList<TSType>
    public var isAbstract: Bool
    public var isDeclare: Bool
    public var decorators: ArrayList<TSDecorator>
    public var propertyExtensions: HashMap<String, TSPropertyExtension>
    public var methodExtensions: HashMap<String, TSFunctionExtension>

    public init() {
        typeParams = ArrayList<TSTypeParameterDecl>()
        implements_ = ArrayList<TSType>()
        isAbstract = false
        isDeclare = false
        decorators = ArrayList<TSDecorator>()
        propertyExtensions = HashMap<String, TSPropertyExtension>()
        methodExtensions = HashMap<String, TSFunctionExtension>()
    }
}
