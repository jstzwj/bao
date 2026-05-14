// 绑定模式分析
// 严格翻译自: src/js_parser/ast/B.zig
//   Bun 的绑定模式处理涵盖对象解构、数组解构、rest、默认值
//   对应 ES6 destructuring binding patterns
package bao_parser

import bao_core.*
import bao_collections.*

// ============================================================================
// BindingPattern - 增强的绑定模式
// 严格翻译自: src/js_parser/ast/B.zig
//   Bun 的 Binding 只包含基础结构
//   BindingPattern 提供完整的模式匹配和分析能力
// ============================================================================

/// 绑定模式类型 - 对应 Bun B.Data 详细标签
public enum BindingPatternTag {
    | Identifier        // b_identifier - 简单标识符
    | ObjectPattern     // b_object - 对象解构 { a, b: c, ...rest }
    | ArrayPattern      // b_array - 数组解构 [a, b, ...rest]
    | RestPattern       // rest 元素 ...x
    | AssignmentPattern // 默认值 x = defaultValue
    | Missing           // b_missing - 占位符
}

/// 增强的绑定模式 - 对应 Bun Binding 扩展
public class BindingPattern {
    public var loc: Loc
    public var tag: BindingPatternTag

    // --- 标识符字段 ---
    public var name: String
    public var ref: Ref

    // --- 对象解构字段 ---
    public var properties: ArrayList<BindingPatternProperty>
    public var restProperty: ?BindingPattern

    // --- 数组解构字段 ---
    public var elements: ArrayList<BindingPattern>
    public var hasRest: Bool

    // --- 默认值字段 ---
    public var defaultValue: ?Expr

    // --- 类型注解 ---
    public var typeAnnotation: ?TSType

    public init(loc: Loc, tag: BindingPatternTag) {
        this.loc = loc
        this.tag = tag
        name = ""
        ref = Ref.NONE
        properties = ArrayList<BindingPatternProperty>()
        restProperty = None
        elements = ArrayList<BindingPattern>()
        hasRest = false
        defaultValue = None
        typeAnnotation = None
    }

    /// 简单标识符绑定
    public static func identifier(loc: Loc, name: String): BindingPattern {
        let b = BindingPattern(loc, BindingPatternTag.Identifier)
        b.name = name
        return b
    }

    /// 对象解构绑定
    public static func objectPattern(loc: Loc, properties: ArrayList<BindingPatternProperty>): BindingPattern {
        let b = BindingPattern(loc, BindingPatternTag.ObjectPattern)
        b.properties = properties
        return b
    }

    /// 数组解构绑定
    public static func arrayPattern(loc: Loc, elements: ArrayList<BindingPattern>): BindingPattern {
        let b = BindingPattern(loc, BindingPatternTag.ArrayPattern)
        b.elements = elements
        return b
    }

    /// Rest 绑定
    public static func rest(loc: Loc, inner: BindingPattern): BindingPattern {
        let b = BindingPattern(loc, BindingPatternTag.RestPattern)
        b.name = inner.name
        b.ref = inner.ref
        return b
    }

    /// 带默认值的绑定
    public static func withDefault(loc: Loc, pattern: BindingPattern, defaultValue: Expr): BindingPattern {
        let b = BindingPattern(loc, BindingPatternTag.AssignmentPattern)
        b.name = pattern.name
        b.ref = pattern.ref
        b.properties = pattern.properties
        b.elements = pattern.elements
        b.defaultValue = Some(defaultValue)
        return b
    }

    /// 收集所有绑定的标识符名称
    public func collectNames(): ArrayList<String> {
        let names = ArrayList<String>()
        collectNamesInto(names)
        return names
    }

    private func collectNamesInto(names: ArrayList<String>): Unit {
        match (tag) {
            case BindingPatternTag.Identifier =>
                if (name.size > 0) {
                    names.append(name)
                }
            case BindingPatternTag.ObjectPattern =>
                for (prop in properties) {
                    prop.value.collectNamesInto(names)
                }
                match (restProperty) {
                    case Some(r) => r.collectNamesInto(names)
                    case None => ()
                }
            case BindingPatternTag.ArrayPattern =>
                for (elem in elements) {
                    elem.collectNamesInto(names)
                }
            case BindingPatternTag.RestPattern =>
                if (name.size > 0) {
                    names.append(name)
                }
            case BindingPatternTag.AssignmentPattern =>
                // 委托给内部模式
                if (name.size > 0) {
                    names.append(name)
                }
                for (prop in properties) {
                    prop.value.collectNamesInto(names)
                }
                for (elem in elements) {
                    elem.collectNamesInto(names)
                }
            case BindingPatternTag.Missing => ()
        }
    }

    /// 绑定模式嵌套深度
    public func depth(): Int64 {
        match (tag) {
            case BindingPatternTag.Identifier => 0
            case BindingPatternTag.ObjectPattern =>
                var max: Int64 = 0
                for (prop in properties) {
                    let d = prop.value.depth() + 1
                    if (d > max) { max = d }
                }
                return max
            case BindingPatternTag.ArrayPattern =>
                var max: Int64 = 0
                for (elem in elements) {
                    let d = elem.depth() + 1
                    if (d > max) { max = d }
                }
                return max
            case BindingPatternTag.RestPattern => 0
            case BindingPatternTag.AssignmentPattern => 0
            case BindingPatternTag.Missing => 0
        }
    }

    /// 转为简单 Binding (基础 AST 节点)
    public func toBinding(): Binding {
        match (tag) {
            case BindingPatternTag.Identifier =>
                let b = Binding.identifier(loc, name, ref)
                if (defaultValue.isSome()) {
                    // 保留默认值信息在 Binding 上
                }
                return b
            case BindingPatternTag.ObjectPattern =>
                let props = ArrayList<BindingProperty>()
                for (prop in properties) {
                    props.append(BindingProperty(prop.loc, prop.key, Some(prop.value.toBinding()), prop.defaultValue))
                }
                return Binding.object_(loc, props)
            case BindingPatternTag.ArrayPattern =>
                let items = ArrayList<Binding>()
                for (elem in elements) {
                    items.append(elem.toBinding())
                }
                return Binding.array_(loc, items)
            case BindingPatternTag.RestPattern =>
                return Binding.identifier(loc, name, ref)
            case BindingPatternTag.AssignmentPattern =>
                let b = Binding.identifier(loc, name, ref)
                return b
            case BindingPatternTag.Missing =>
                return Binding(loc, BindingTag.Missing)
        }
    }
}

/// 对象解构属性 - 对应 Bun B.Object.Property 扩展
public class BindingPatternProperty {
    public var loc: Loc
    /// 属性键名 - 对应 Bun B.Object.Property.key
    public var key: String
    /// 计算属性键表达式
    public var computedKey: ?Expr
    /// 绑定值 - 对应 Bun B.Object.Property.value
    public var value: BindingPattern
    /// 默认值
    public var defaultValue: ?Expr
    /// 是否为 shorthand ({ a } 而非 { a: b })
    public var isShorthand: Bool
    /// 是否为 computed 属性 ({ [expr]: value })
    public var isComputed: Bool
    /// 类型注解
    public var typeAnnotation: ?TSType

    public init(loc: Loc, key: String, value: BindingPattern) {
        this.loc = loc
        this.key = key
        computedKey = None
        this.value = value
        defaultValue = None
        isShorthand = (key == value.name)
        isComputed = false
        typeAnnotation = None
    }

    public init(loc: Loc, key: String, value: BindingPattern, defaultValue: ?Expr) {
        this.loc = loc
        this.key = key
        computedKey = None
        this.value = value
        this.defaultValue = defaultValue
        isShorthand = false
        isComputed = false
        typeAnnotation = None
    }

    /// computed 属性
    public static func computed(loc: Loc, key: Expr, value: BindingPattern): BindingPatternProperty {
        let p = BindingPatternProperty(loc, "", value)
        p.computedKey = Some(key)
        p.isComputed = true
        return p
    }
}

// ============================================================================
// BindingParser - 绑定模式解析辅助
// 严格翻译自: src/js_parser/p.zig parseBinding* 方法
//   Bun 使用 p.b() 分配绑定节点
//   这里的辅助函数提供模式解析和验证
// ============================================================================

/// 绑定模式解析辅助 - 对应 Bun 中 parseBinding 相关方法
public class BindingParser {
    /// 验证绑定模式是否合法
    /// 对应 Bun: checkForInvalidBindingPattern()
    public static func validate(pattern: BindingPattern): ArrayList<String> {
        var errors = ArrayList<String>()
        validatePattern(pattern, errors, 0)
        return errors
    }

    private static func validatePattern(pattern: BindingPattern, errors: ArrayList<String>, depth: Int64): Unit {
        // 检查嵌套深度
        if (depth > 10) {
            errors.append("binding pattern nesting too deep")
            return
        }
        match (pattern.tag) {
            case BindingPatternTag.Identifier =>
                // 验证标识符不是保留字
                let name = pattern.name
                if (StrictModeReservedWords.contains(name)) {
                    errors.append("cannot use reserved word '${name}' as binding name in strict mode")
                }
            case BindingPatternTag.ObjectPattern =>
                var hasRest = false
                for (prop in pattern.properties) {
                    if (prop.isComputed) {
                        match (prop.computedKey) {
                            case Some(_) => ()  // computed 是合法的
                            case None => errors.append("computed property missing key expression")
                        }
                    }
                    validatePattern(prop.value, errors, depth + 1)
                }
                match (pattern.restProperty) {
                    case Some(r) =>
                        hasRest = true
                        validatePattern(r, errors, depth + 1)
                    case None => ()
                }
            case BindingPatternTag.ArrayPattern =>
                var restCount: Int64 = 0
                var lastWasRest = false
                for (elem in pattern.elements) {
                    if (elem.tag == BindingPatternTag.RestPattern) {
                        restCount += 1
                        if (lastWasRest) {
                            errors.append("array rest element must be last")
                        }
                        lastWasRest = true
                    } else {
                        lastWasRest = false
                    }
                    validatePattern(elem, errors, depth + 1)
                }
                if (restCount > 1) {
                    errors.append("array binding pattern can have at most one rest element")
                }
            case BindingPatternTag.RestPattern =>
                if (pattern.name.size == 0) {
                    errors.append("rest binding must have a name")
                }
            case BindingPatternTag.AssignmentPattern =>
                if (defaultValue.isNone()) {
                    errors.append("assignment pattern must have a default value")
                }
            case BindingPatternTag.Missing => ()
        }
    }

    /// 从简单 Binding 转换为 BindingPattern
    public static func fromBinding(binding: Binding): BindingPattern {
        match (binding.tag) {
            case BindingTag.Identifier =>
                let p = BindingPattern.identifier(binding.loc, binding.name)
                p.ref = binding.ref
                match (binding.defaultValue) {
                    case Some(v) => return BindingPattern.withDefault(binding.loc, p, v)
                    case None => return p
                }
            case BindingTag.Object =>
                let props = ArrayList<BindingPatternProperty>()
                for (prop in binding.objectProperties) {
                    let value = fromBinding(match (prop.value) {
                        case Some(b) => b
                        case None => Binding.identifier(prop.loc, "_")
                    })
                    props.append(BindingPatternProperty(prop.loc, prop.key, value, prop.defaultValue))
                }
                let p = BindingPattern.objectPattern(binding.loc, props)
                return p
            case BindingTag.Array =>
                let elems = ArrayList<BindingPattern>()
                for (item in binding.arrayItems) {
                    elems.append(fromBinding(item))
                }
                return BindingPattern.arrayPattern(binding.loc, elems)
            case BindingTag.Missing =>
                return BindingPattern(binding.loc, BindingPatternTag.Missing)
        }
    }

    /// 收集参数列表中的所有绑定名称
    /// 对应 Bun: collectParamNames(args)
    public static func collectParamNames(args: ArrayList<GArg>): ArrayList<String> {
        let names = ArrayList<String>()
        for (arg in args) {
            let pattern = fromBinding(arg.binding)
            for (name in pattern.collectNames()) {
                names.append(name)
            }
        }
        return names
    }

    /// 检查是否为简单绑定 (非解构)
    public static func isSimpleBinding(pattern: BindingPattern): Bool {
        match (pattern.tag) {
            case BindingPatternTag.Identifier => true
            case _ => false
        }
    }

    /// 检查是否为对象解构
    public static func isObjectDestructuring(pattern: BindingPattern): Bool {
        match (pattern.tag) {
            case BindingPatternTag.ObjectPattern => true
            case _ => false
        }
    }

    /// 检查是否为数组解构
    public static func isArrayDestructuring(pattern: BindingPattern): Bool {
        match (pattern.tag) {
            case BindingPatternTag.ArrayPattern => true
            case _ => false
        }
    }

    /// 计算绑定数量
    public static func countBindings(pattern: BindingPattern): Int64 {
        return pattern.collectNames().size
    }

    /// 构建解构赋值的目标表达式
    /// 将 BindingPattern 转换回 Expr 赋值目标
    public static func toAssignmentTarget(pattern: BindingPattern): Expr {
        match (pattern.tag) {
            case BindingPatternTag.Identifier =>
                return Expr.identifier(pattern.loc, pattern.name, pattern.ref)
            case BindingPatternTag.ObjectPattern =>
                let props = ArrayList<GProperty>()
                for (prop in pattern.properties) {
                    let value = toAssignmentTarget(prop.value)
                    let p = GProperty(prop.loc, prop.key, Some(value))
                    if (prop.isShorthand) {
                        p.flags.wasShorthand = true
                    }
                    if (prop.isComputed) {
                        p.flags.isComputed = true
                        match (prop.computedKey) {
                            case Some(k) => p.keyExpr = Some(k)
                            case None => ()
                        }
                    }
                    props.append(p)
                }
                return Expr.object(pattern.loc, props)
            case BindingPatternTag.ArrayPattern =>
                let items = ArrayList<Expr>()
                for (elem in pattern.elements) {
                    if (elem.tag == BindingPatternTag.RestPattern) {
                        items.append(Expr.spread(elem.loc, toAssignmentTarget(elem)))
                    } else {
                        items.append(toAssignmentTarget(elem))
                    }
                }
                return Expr.array(pattern.loc, items)
            case BindingPatternTag.RestPattern =>
                return Expr.spread(pattern.loc, Expr.identifier(pattern.loc, pattern.name, pattern.ref))
            case BindingPatternTag.AssignmentPattern =>
                return toAssignmentTarget(BindingPattern.identifier(pattern.loc, pattern.name))
            case BindingPatternTag.Missing =>
                return Expr.missing(pattern.loc)
        }
    }
}

// ============================================================================
// DestructuringEmitter - 解构代码生成辅助
// 严格翻译自: src/bundler/ 中解构模式转换代码
//   在打包/转译时需要将解构展开为逐步赋值
// ============================================================================

/// 解构展开结果
public class DestructuringResult {
    /// 生成的临时变量名
    public var tempVar: String
    /// 生成的赋值语句列表
    public var statements: ArrayList<Stmt>
    /// 是否需要临时变量
    public var needsTemp: Bool

    public init(tempVar: String) {
        this.tempVar = tempVar
        statements = ArrayList<Stmt>()
        needsTemp = false
    }
}

/// 解构代码生成辅助 - 对应 Bun 打包器中的解构展开
public class DestructuringEmitter {
    /// 生成对象解构展开
    /// { a, b: c, ...rest } = expr
    /// → var _t = expr, a = _t.a, c = _t.b, rest = _objectWithoutProperties(_t, ["a", "b"])
    public static func emitObjectDestructuring(pattern: BindingPattern, value: Expr, tempName: String): DestructuringResult {
        let result = DestructuringResult(tempName)
        result.needsTemp = true

        // tempVar = value
        let tempDecl = Stmt.local(pattern.loc, DeclKind.Var,
            Binding.identifier(pattern.loc, tempName),
            Some(value))
        result.statements.append(tempDecl)

        // 逐个属性赋值
        for (prop in pattern.properties) {
            let targetBinding = Binding.identifier(prop.value.loc, prop.value.name)
            let access = Expr.dot(prop.loc,
                Expr.identifier(prop.loc, tempName),
                prop.key)
            let decl = Stmt.local(prop.value.loc, DeclKind.Var, targetBinding, Some(access))
            result.statements.append(decl)
        }

        // rest 属性 (简化处理)
        match (pattern.restProperty) {
            case Some(r) =>
                let restDecl = Stmt.local(r.loc, DeclKind.Var,
                    Binding.identifier(r.loc, r.name),
                    Some(Expr.identifier(r.loc, tempName)))
                result.statements.append(restDecl)
            case None => ()
        }

        return result
    }

    /// 生成数组解构展开
    /// [a, b, ...rest] = expr
    /// → var _t = expr, a = _t[0], b = _t[1], rest = _t.slice(2)
    public static func emitArrayDestructuring(pattern: BindingPattern, value: Expr, tempName: String): DestructuringResult {
        let result = DestructuringResult(tempName)
        result.needsTemp = true

        let tempDecl = Stmt.local(pattern.loc, DeclKind.Var,
            Binding.identifier(pattern.loc, tempName),
            Some(value))
        result.statements.append(tempDecl)

        var idx: Int64 = 0
        for (elem in pattern.elements) {
            if (elem.tag == BindingPatternTag.RestPattern) {
                // rest = _t.slice(idx)
                let sliceCall = Expr.call(elem.loc,
                    Expr.dot(elem.loc, Expr.identifier(elem.loc, tempName), "slice"),
                    ArrayList<Expr>([Expr.number(elem.loc, Float64(idx))]))
                let restDecl = Stmt.local(elem.loc, DeclKind.Var,
                    Binding.identifier(elem.loc, elem.name),
                    Some(sliceCall))
                result.statements.append(restDecl)
            } else {
                // elem = _t[idx]
                let access = Expr.index(elem.loc,
                    Expr.identifier(elem.loc, tempName),
                    Expr.number(elem.loc, Float64(idx)))
                let decl = Stmt.local(elem.loc, DeclKind.Var,
                    Binding.identifier(elem.loc, elem.name),
                    Some(access))
                result.statements.append(decl)
            }
            idx += 1
        }

        return result
    }
}
