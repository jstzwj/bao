// AST 节点类型
// 严格翻译自:
//   src/js_parser/ast/E.zig - Expression 数据类型
//   src/js_parser/ast/S.zig - Statement 数据类型
//   src/js_parser/ast/G.zig - 全局类型 (Fn, Class, Property, Arg, Decl)
//   src/js_parser/ast/B.zig - Binding 数据类型
//   src/js_parser/ast/Expr.zig - Expression 包装器
//   src/js_parser/ast/Stmt.zig - Statement 包装器
//   src/js_parser/ast/Binding.zig - Binding 包装器
//   src/js_parser/ast/Scope.zig - 作用域
//   src/js_parser/ast/Symbol.zig - 符号
package bao_parser

import bao_core.*
import bao_collections.*

// ============================================================================
// Expr (Expression) - 表达式节点
// 严格翻译自: src/js_parser/ast/Expr.zig
//   pub const Expr = struct { loc: Loc, data: Data }
//   pub const Data = union(enum) {
//       e_missing, e_undefined, e_null, e_bool, e_number, e_big_int,
//       e_string, e_regex, e_identifier, e_import_identifier, e_this,
//       e_super, e_new, e_call, e_dot, e_index, e_array, e_object,
//       e_spread, e_arrow, e_function, e_class, e_template, e_unary,
//       e_binary, e_ternary, e_assign, e_postfix, eAwait, e_yield, ...
//   }
//
// Bun 核心设计:
//   "Everything in JavaScript is either an Expression, a Binding, or a Statement"
//   "p.e" allocates a new Expr
//   "p.b" allocates a new Binding
//   "p.s" allocates a new Stmt
// ============================================================================

/// 表达式数据类型标签 - 对应 Bun Expr.Data 联合体标签
public enum ExprTag {
    | Missing           // e_missing - 缺失表达式
    | Undefined         // e_undefined
    | Null              // e_null
    | Boolean           // e_bool - E.Boolean { value: bool }
    | Number            // e_number - E.Number { value: f64 }
    | BigInt            // e_big_int
    | String            // e_string - E.String { data, prefer_template, ... }
    | Regex             // e_regex - E.Regex { pattern, flags }
    | Identifier        // e_identifier - E.Identifier { ref, ... }
    | ImportIdentifier  // e_import_identifier
    | ThisExpr              // e_this
    | Super             // e_super
    | New               // e_new - E.New { target, args, ... }
    | Call              // e_call - E.Call { target, args, ... }
    | Dot               // e_dot - E.Dot { target, name, ... }
    | Index             // e_index - E.Index { target, index, ... }
    | Array             // e_array - E.Array { items, ... }
    | Object            // e_object - E.Object { properties, ... }
    | Spread            // e_spread - E.Spread { value }
    | Arrow             // e_arrow - E.Arrow { args, body, is_async, ... }
    | Function          // e_function - E.Function { func }
    | Class             // e_class - E.Class { class }
    | Template          // e_template - E.Template { tag, parts, ... }
    | Unary             // e_unary - E.Unary { op, value, ... }
    | Binary            // e_binary - E.Binary { left, right, op }
    | Ternary           // e_ternary / e_if - E.If { test, yes, no }
    | Assign            // e_assign - E.Assign { target, value }
    | Postfix           // e_postfix - E.Postfix { op, operand }
    | Await             // eAwait
    | Yield             // e_yield
    | TypeCast          // TypeScript 类型断言
    | JsxElement        // JSX 元素
    | JsxFragment       // JSX 片段

    public operator func ==(right: ExprTag): Bool {
        match (this) {
            case Missing => match (right) { case Missing => true case _ => false }
            case Undefined => match (right) { case Undefined => true case _ => false }
            case Null => match (right) { case Null => true case _ => false }
            case Boolean => match (right) { case Boolean => true case _ => false }
            case Number => match (right) { case Number => true case _ => false }
            case BigInt => match (right) { case BigInt => true case _ => false }
            case String => match (right) { case String => true case _ => false }
            case Regex => match (right) { case Regex => true case _ => false }
            case Object => match (right) { case Object => true case _ => false }
            case Array => match (right) { case Array => true case _ => false }
            case Function => match (right) { case Function => true case _ => false }
            case Class => match (right) { case Class => true case _ => false }
            case Identifier => match (right) { case Identifier => true case _ => false }
            case ImportIdentifier => match (right) { case ImportIdentifier => true case _ => false }
            case ThisExpr => match (right) { case ThisExpr => true case _ => false }
            case Super => match (right) { case Super => true case _ => false }
            case Spread => match (right) { case Spread => true case _ => false }
            case New => match (right) { case New => true case _ => false }
            case Call => match (right) { case Call => true case _ => false }
            case Dot => match (right) { case Dot => true case _ => false }
            case Index => match (right) { case Index => true case _ => false }
            case Arrow => match (right) { case Arrow => true case _ => false }
            case Template => match (right) { case Template => true case _ => false }
            case Unary => match (right) { case Unary => true case _ => false }
            case Binary => match (right) { case Binary => true case _ => false }
            case Ternary => match (right) { case Ternary => true case _ => false }
            case Assign => match (right) { case Assign => true case _ => false }
            case Postfix => match (right) { case Postfix => true case _ => false }
            case Await => match (right) { case Await => true case _ => false }
            case Yield => match (right) { case Yield => true case _ => false }
            case TypeCast => match (right) { case TypeCast => true case _ => false }
            case JsxElement => match (right) { case JsxElement => true case _ => false }
            case JsxFragment => match (right) { case JsxFragment => true case _ => false }
        }
    }

    public operator func !=(right: ExprTag): Bool {
        return !(this == right)
    }
}

/// 表达式节点 - 对应 Bun Expr
/// Bun: struct { loc: logger.Loc, data: Data }
/// Data 是 union(enum)，仓颉用 ExprTag + 各自的数据字段
public class Expr {
    /// 源码位置 - 对应 Bun Expr.loc
    public var loc: Loc
    /// 表达式类型标签 - 对应 Bun Expr.Data 标签
    public var tag: ExprTag

    // --- 字面量字段 ---
    /// 布尔值 - 对应 E.Boolean.value
    public var boolValue: Bool
    /// 数字值 - 对应 E.Number.value
    public var numberValue: Float64
    /// 字符串值 - 对应 E.String
    public var stringValue: BaoString
    /// 正则模式 - 对应 E.Regex.pattern
    public var regexPattern: String
    /// 正则标志 - 对应 E.Regex.flags
    public var regexFlags: String

    // --- 标识符字段 ---
    /// 标识符引用 - 对应 E.Identifier.ref
    public var ref: Ref
    /// 标识符名称 - 内部使用
    public var identifierName: String

    // --- 运算符字段 ---
    /// 操作符 - 用于 Unary, Binary, Postfix, Assign
    public var op: OpCode

    // --- 子表达式 ---
    /// 一元操作数 / 后缀操作数 / await / yield - 对应 E.Unary.value
    public var value: ?Expr
    /// 二元左操作数 - 对应 E.Binary.left
    public var left: ?Expr
    /// 二元右操作数 - 对应 E.Binary.right
    public var right: ?Expr
    /// 三元条件 - 对应 E.If.test
    public var test: ?Expr
    /// 三元真值 - 对应 E.If.yes
    public var yes: ?Expr
    /// 三元假值 - 对应 E.If.no
    public var no: ?Expr

    // --- 成员访问字段 ---
    /// 属性名 - 对应 E.Dot.name
    public var propertyName: String
    /// 目标表达式 - 对应 E.Dot.target / E.Call.target / E.New.target
    public var target: ?Expr
    /// 索引表达式 - 对应 E.Index.index
    public var indexExpr: ?Expr
    /// 可选链 - 对应 E.Dot.optional_chain
    public var optionalChain: ?OptionalChain

    // --- 调用字段 ---
    /// 调用参数 - 对应 E.Call.args
    public var args: ArrayList<Expr>

    // --- 数组/对象字段 ---
    /// 数组元素 - 对应 E.Array.items
    public var items: ArrayList<Expr>
    /// 对象属性 - 对应 E.Object.properties
    public var properties: ArrayList<GProperty>

    // --- 模板字段 ---
    /// 模板标签 - 对应 E.Template.tag
    public var templateTag: ?Expr
    /// 模板部分 - 对应 E.Template.parts (交替: 字符串, 表达式)
    public var templateParts: ArrayList<Expr>

    // --- 函数/类字段 ---
    /// 函数数据 - 对应 E.Function.func / E.Arrow
    public var fn: ?GFn
    /// 类数据 - 对应 E.Class.class
    public var classData: ?GClass

    // --- JSX 字段 ---
    public var jsxTag: ?Expr
    public var jsxProps: ArrayList<GProperty>
    public var jsxChildren: ArrayList<Expr>

    // --- Side-effect analysis flags ---
    /// 是否可以在未使用时安全移除 - 对应 Bun E.Dot.can_be_removed_if_unused
    public var canBeRemovedIfUnused: Bool
    /// with 语句中是否必须保留 - 对应 Bun E.Identifier.must_keep_due_to_with_stmt
    public var mustKeepDueToWithStmt: Bool
    /// typeof 标识符标记 - 对应 Bun E.Unary.was_originally_typeof_identifier
    public var wasOriginallyTypeofIdentifier: Bool
    /// __PURE__ 标注 - 对应 Bun E.Call.can_be_unwrapped_if_unused
    public var canBeUnwrappedIfUnused: CanBeUnwrapped

    public init(loc: Loc, tag: ExprTag) {
        this.loc = loc
        this.tag = tag
        boolValue = false
        numberValue = 0.0
        stringValue = BaoString("")
        regexPattern = ""
        regexFlags = ""
        ref = Ref.NONE
        identifierName = ""
        op = OpCode.Comma
        value = None
        left = None
        right = None
        test = None
        yes = None
        no = None
        propertyName = ""
        target = None
        indexExpr = None
        optionalChain = None
        args = ArrayList<Expr>()
        items = ArrayList<Expr>()
        properties = ArrayList<GProperty>()
        templateTag = None
        templateParts = ArrayList<Expr>()
        fn = None
        classData = None
        jsxTag = None
        jsxProps = ArrayList<GProperty>()
        jsxChildren = ArrayList<Expr>()
        canBeRemovedIfUnused = false
        mustKeepDueToWithStmt = false
        wasOriginallyTypeofIdentifier = false
        canBeUnwrappedIfUnused = CanBeUnwrapped.Never
    }

    public init() {
        this(Loc.EMPTY, ExprTag.Missing)
    }

    // === 工厂方法 (对应 Bun 中 p.e 的各种分配方法) ===

    /// 创建布尔表达式 - 对应 Bun Expr(E.Boolean, .{ .value = v }, loc)
    public static func bool_(loc: Loc, value: Bool): Expr {
        let e = Expr(loc, ExprTag.Boolean)
        e.boolValue = value
        return e
    }

    /// 创建数字表达式
    public static func number(loc: Loc, value: Float64): Expr {
        let e = Expr(loc, ExprTag.Number)
        e.numberValue = value
        return e
    }

    /// 创建字符串表达式
    public static func string(loc: Loc, value: String): Expr {
        let e = Expr(loc, ExprTag.String)
        e.stringValue = BaoString(value)
        return e
    }

    /// 创建 null 表达式
    public static func null_(loc: Loc): Expr {
        return Expr(loc, ExprTag.Null)
    }

    /// 创建 undefined 表达式
    public static func undefined(loc: Loc): Expr {
        return Expr(loc, ExprTag.Undefined)
    }

    /// 创建标识符表达式 - 对应 Bun E.Identifier
    public static func identifier(loc: Loc, name: String, ref: Ref): Expr {
        let e = Expr(loc, ExprTag.Identifier)
        e.identifierName = name
        e.ref = ref
        return e
    }

    /// 创建标识符 (无引用) - 便捷方法
    public static func identifier(loc: Loc, name: String): Expr {
        let e = Expr(loc, ExprTag.Identifier)
        e.identifierName = name
        return e
    }

    /// 创建 this 表达式
    public static func this_(loc: Loc): Expr {
        return Expr(loc, ExprTag.ThisExpr)
    }

    /// 创建一元表达式 - 对应 Bun E.Unary
    public static func unary(loc: Loc, op: OpCode, value: Expr): Expr {
        let e = Expr(loc, ExprTag.Unary)
        e.op = op
        e.value = Some(value)
        return e
    }

    /// 创建二元表达式 - 对应 Bun E.Binary
    public static func binary(loc: Loc, left: Expr, right: Expr, op: OpCode): Expr {
        let e = Expr(loc, ExprTag.Binary)
        e.left = Some(left)
        e.right = Some(right)
        e.op = op
        return e
    }

    /// 创建三元表达式 - 对应 Bun E.If
    public static func ternary(loc: Loc, test: Expr, yes: Expr, no: Expr): Expr {
        let e = Expr(loc, ExprTag.Ternary)
        e.test = Some(test)
        e.yes = Some(yes)
        e.no = Some(no)
        return e
    }

    /// 创建赋值表达式 - 对应 Bun E.Assign
    public static func assign(loc: Loc, target: Expr, value: Expr): Expr {
        let e = Expr(loc, ExprTag.Assign)
        e.target = Some(target)
        e.value = Some(value)
        return e
    }

    /// 创建点访问表达式 - 对应 Bun E.Dot
    public static func dot(loc: Loc, target: Expr, name: String): Expr {
        let e = Expr(loc, ExprTag.Dot)
        e.target = Some(target)
        e.propertyName = name
        return e
    }

    /// 创建索引访问表达式 - 对应 Bun E.Index
    public static func index(loc: Loc, target: Expr, index: Expr): Expr {
        let e = Expr(loc, ExprTag.Index)
        e.target = Some(target)
        e.indexExpr = Some(index)
        return e
    }

    /// 创建调用表达式 - 对应 Bun E.Call
    public static func call(loc: Loc, target: Expr, args: ArrayList<Expr>): Expr {
        let e = Expr(loc, ExprTag.Call)
        e.target = Some(target)
        e.args = args
        return e
    }

    /// 创建 new 表达式 - 对应 Bun E.New
    public static func new_(loc: Loc, target: Expr, args: ArrayList<Expr>): Expr {
        let e = Expr(loc, ExprTag.New)
        e.target = Some(target)
        e.args = args
        return e
    }

    /// 创建数组表达式 - 对应 Bun E.Array
    public static func array(loc: Loc, items: ArrayList<Expr>): Expr {
        let e = Expr(loc, ExprTag.Array)
        e.items = items
        return e
    }

    /// 创建展开表达式 - 对应 Bun E.Spread
    public static func spread(loc: Loc, value: Expr): Expr {
        let e = Expr(loc, ExprTag.Spread)
        e.value = Some(value)
        return e
    }

    /// 创建 super 表达式
    public static func super_(loc: Loc): Expr {
        return Expr(loc, ExprTag.Super)
    }

    /// 创建 import() 表达式 - 对应 Bun E.ImportCall
    public static func import_(loc: Loc, path: Expr): Expr {
        let e = Expr(loc, ExprTag.Call)
        e.identifierName = "import"
        e.args = ArrayList<Expr>()
        e.args.append(path)
        return e
    }

    /// 创建函数表达式 - 对应 Bun E.Function
    public static func fn_(loc: Loc, fn: GFn): Expr {
        let e = Expr(loc, ExprTag.Function)
        e.fn = Some(fn)
        return e
    }

    /// 创建对象表达式 - 对应 Bun E.Object
    public static func object(loc: Loc, properties: ArrayList<GProperty>): Expr {
        let e = Expr(loc, ExprTag.Object)
        e.properties = properties
        return e
    }

    /// 创建模板表达式 - 对应 Bun E.Template
    public static func template(loc: Loc, parts: Array<String>): Expr {
        let e = Expr(loc, ExprTag.Template)
        // 简化: 存储第一个部分
        if (parts.size > 0) {
            e.stringValue = BaoString(parts[0])
        }
        return e
    }

    /// 创建 BigInt 表达式
    public static func bigInt(loc: Loc, text: String): Expr {
        let e = Expr(loc, ExprTag.BigInt)
        e.stringValue = BaoString(text)
        return e
    }

    /// 创建 await 表达式
    public static func await_(loc: Loc, value: Expr): Expr {
        let e = Expr(loc, ExprTag.Await)
        e.value = Some(value)
        return e
    }

    /// 创建前缀表达式 (++/--)
    public static func prefix(loc: Loc, op: OpCode, value: Expr): Expr {
        let e = Expr(loc, ExprTag.Unary)
        e.op = op
        e.value = Some(value)
        return e
    }

    /// 创建后缀表达式 (++/--)
    public static func postfix(loc: Loc, value: Expr): Expr {
        let e = Expr(loc, ExprTag.Postfix)
        e.value = Some(value)
        return e
    }

    /// 创建点访问 (带名称位置) - 对应 Bun E.Dot
    public static func dot(loc: Loc, target: Expr, name: String, nameLoc: Loc): Expr {
        let e = Expr(loc, ExprTag.Dot)
        e.target = Some(target)
        e.propertyName = name
        return e
    }

    /// 创建赋值 (带操作符) - 对应 Bun E.Assign
    public static func assign(loc: Loc, target: Expr, op: OpCode, value: Expr): Expr {
        let e = Expr(loc, ExprTag.Assign)
        e.target = Some(target)
        e.op = op
        e.value = Some(value)
        return e
    }

    /// 创建缺失表达式 - 对应 Bun E.Missing
    public static func missing(loc: Loc): Expr {
        return Expr(loc, ExprTag.Missing)
    }
}

// ============================================================================
// Stmt (Statement) - 语句节点
// 严格翻译自: src/js_parser/ast/S.zig + Stmt.zig
//   pub const Stmt = struct { loc: Loc, data: Data }
//   pub const Data = union(enum) {
//       s_block, s_expr, s_if, s_for, s_for_in, s_for_of, s_while, s_do_while,
//       s_function, s_class, s_import, s_local, s_return, s_throw, s_try,
//       s_switch, s_break, s_continue, s_debugger, s_empty, ...
//   }
// ============================================================================

/// 语句数据类型标签 - 对应 Bun Stmt.Data 联合体标签
public enum StmtTag {
    | Block          // s_block - S.Block { stmts }
    | Expr           // s_expr - S.SExpr { value }
    | If             // s_if - S.If { test_, yes, no }
    | For            // s_for - S.For { init, test_, update, body }
    | ForIn          // s_for_in - S.ForIn { init, value, body }
    | ForOf          // s_for_of - S.ForOf { init, value, body }
    | While          // s_while - S.While { test_, body }
    | DoWhile        // s_do_while - S.DoWhile { test_, body }
    | Function       // s_function - S.Function { func }
    | Class          // s_class - S.Class { class, is_export }
    | Import         // s_import - S.Import { namespace_ref, default_name, items }
    | Export         // s_export - export clause
    | ExportDefault  // s_export - export default
    | ExportStar     // s_export - export * from
    | ExportFrom     // s_export - export { } from
    | Local          // s_local - S.Local { kind, decls, is_export }
    | Return         // s_return - S.Return { value }
    | Throw          // s_throw - S.Throw { value }
    | Try            // s_try - S.Try { body, catch_, finally }
    | Switch         // s_switch - S.Switch { test_, cases }
    | Break          // s_break
    | Continue       // s_continue
    | Debugger       // s_debugger
    | Empty          // s_empty
    | Directive      // directive (string literal statement)
    | Comment        // comment
    | With           // s_with
    | Labeled        // s_label
    | Type           // TypeScript 类型声明
    | Enum           // TypeScript enum

    public operator func ==(rhs: StmtTag): Bool {
        match (this) {
            case Block => match (rhs) { case Block => true case _ => false }
            case Expr => match (rhs) { case Expr => true case _ => false }
            case If => match (rhs) { case If => true case _ => false }
            case For => match (rhs) { case For => true case _ => false }
            case ForIn => match (rhs) { case ForIn => true case _ => false }
            case ForOf => match (rhs) { case ForOf => true case _ => false }
            case While => match (rhs) { case While => true case _ => false }
            case DoWhile => match (rhs) { case DoWhile => true case _ => false }
            case Function => match (rhs) { case Function => true case _ => false }
            case Class => match (rhs) { case Class => true case _ => false }
            case Import => match (rhs) { case Import => true case _ => false }
            case Export => match (rhs) { case Export => true case _ => false }
            case ExportDefault => match (rhs) { case ExportDefault => true case _ => false }
            case ExportStar => match (rhs) { case ExportStar => true case _ => false }
            case ExportFrom => match (rhs) { case ExportFrom => true case _ => false }
            case Local => match (rhs) { case Local => true case _ => false }
            case Return => match (rhs) { case Return => true case _ => false }
            case Throw => match (rhs) { case Throw => true case _ => false }
            case Try => match (rhs) { case Try => true case _ => false }
            case Switch => match (rhs) { case Switch => true case _ => false }
            case Break => match (rhs) { case Break => true case _ => false }
            case Continue => match (rhs) { case Continue => true case _ => false }
            case Debugger => match (rhs) { case Debugger => true case _ => false }
            case Empty => match (rhs) { case Empty => true case _ => false }
            case Directive => match (rhs) { case Directive => true case _ => false }
            case Comment => match (rhs) { case Comment => true case _ => false }
            case With => match (rhs) { case With => true case _ => false }
            case Labeled => match (rhs) { case Labeled => true case _ => false }
            case Type => match (rhs) { case Type => true case _ => false }
            case Enum => match (rhs) { case Enum => true case _ => false }
        }
    }

    public operator func !=(rhs: StmtTag): Bool {
        return !(this == rhs)
    }
}

/// 语句节点 - 对应 Bun Stmt
public class Stmt {
    public var loc: Loc
    public var tag: StmtTag

    // --- 通用字段 ---
    /// 子语句列表 - 用于 Block, Try body, Switch case body
    public var stmts: ArrayList<Stmt>
    /// 表达式 - 用于 Expr, Return, Throw, If test, While test, etc.
    public var expr: ?Expr

    // --- 条件字段 ---
    /// if-then - 用于 If, Ternary
    public var yes: ?Stmt
    /// if-else
    public var no: ?Stmt

    // --- 循环字段 ---
    /// for init - 用于 For, ForIn, ForOf
    public var `init`: ?Stmt
    /// for update
    public var update: ?Expr
    /// for-in/for-of value
    public var iterValue: ?Expr
    /// 循环体
    public var body: ?Stmt

    // --- 声明字段 ---
    /// 变量声明类型 - 对应 S.Local.kind
    public var declKind: DeclKind
    /// 声明绑定列表
    public var decls: ArrayList<GDecl>
    /// 是否导出
    public var isExport: Bool

    // --- 函数/类 ---
    public var fn: ?GFn
    public var classData: ?GClass

    // --- 导入/导出 ---
    /// 导入项 - 对应 S.Import.items
    public var importItems: ArrayList<ClauseItem>
    /// 导入路径
    public var importPath: String
    /// 导入默认名称
    public var defaultName: String
    /// 默认名称引用 - 对应 S.Import.default_name_ref
    public var defaultNameRef: Ref

    // --- 异常处理 ---
    /// catch 子句 - 对应 S.Try.catch_
    public var catchBody: ?Stmt
    public var catchBinding: ?Binding
    /// finally 子句 - 对应 S.Try.finally
    public var finallyBody: ?Stmt

    // --- switch ---
    public var cases: ArrayList<SwitchCase>
    public var label: String

    // --- js_printer 额外字段 (从 js_printer_stmt.cj 合并) ---
    public var blockStmts: ArrayList<Stmt>
    public var closeBraceLoc: ?Loc
    public var valueExpr: ?Expr
    public var testExpr: ?Expr
    public var yesExpr: ?Expr
    public var noExpr: ?Expr
    public var updateExpr: ?Expr
    public var yesStmt: ?Stmt
    public var noStmt: ?Stmt
    public var hasNoBranch: Bool
    public var hasTest: Bool
    public var hasInit: Bool
    public var hasUpdate: Bool
    public var initStmt: ?Stmt
    public var isAwait: Bool
    public var hasImportStar: Bool
    public var importRecordIndex: Int64
    public var namespaceRef: Ref
    public var clauseItems: ArrayList<ClauseItem>
    public var isSingleLine: Bool
    public var starNameLoc: ?Loc
    public var defaultNameLoc: ?LocRef
    public var localKind: LocalKind
    public var funcNameRef: Ref
    public var funcNameLoc: Loc
    public var classNameRef: Ref
    public var classNameLoc: Loc
    public var labelRef: ?Ref
    public var exportStarAlias: ?String
    public var innerStmt: ?Stmt
    public var bodyLoc: Loc
    public var bodyStmts: ArrayList<Stmt>
    public var hasCatch: Bool
    public var catchLoc: Loc
    public var hasCatchBinding: Bool
    public var catchBodyLoc: Loc
    public var catchBodyStmts: ArrayList<Stmt>
    public var hasFinally: Bool
    public var finallyLoc: Loc
    public var finallyStmts: ArrayList<Stmt>
    public var commentText: String
    public var directiveValue: String
    public var innerStmtVal: ?Stmt
    public var isAsync: Bool
    public var isGenerator: Bool

    // --- scan_imports / visit_stmt 兼容字段 ---
    /// 导出项 (clauseItems 的别名) - 用于 export/export_from
    public var exportItems: ArrayList<ClauseItem>
    /// 是否为 TS import-equals - 对应 S.Local.was_ts_import_equals
    public var wasTsImportEquals: Bool
    /// 函数开括号位置 - 对应 S.Function.open_parens_loc
    public var funcOpenParensLoc: Loc
    /// 类体位置 - 对应 S.Class.body_loc
    public var classBodyLoc: Loc
    /// 表达式值 - 用于 ExportDefault
    public var exprValue: ?Expr
    /// 函数数据 (fn 别名) - 用于 visit_stmt
    public var functionValue: ?GFn
    /// 类数据 (classData 别名) - 用于 visit_stmt
    public var classValue: ?GClass
    /// 函数名 (fn.name 的快捷方式)
    public var funcName: String
    /// 函数引用 (funcNameRef 别名)
    public var funcRef: Ref
    /// 函数位置 (funcNameLoc 别名)
    public var funcLoc: Loc
    /// 类名 (classData.name 的快捷方式)
    public var className: String
    /// 类引用 (classNameRef 别名)
    public var classRef: Ref
    /// 类位置 (classNameLoc 别名)
    public var classLoc: Loc

    public init(loc: Loc, tag: StmtTag) {
        this.loc = loc
        this.tag = tag
        stmts = ArrayList<Stmt>()
        expr = None
        yes = None
        no = None
        `init` = None
        update = None
        iterValue = None
        body = None
        declKind = DeclKind.Var
        decls = ArrayList<GDecl>()
        isExport = false
        fn = None
        classData = None
        importItems = ArrayList<ClauseItem>()
        importPath = ""
        defaultName = ""
        defaultNameRef = Ref.NONE
        catchBody = None
        catchBinding = None
        finallyBody = None
        cases = ArrayList<SwitchCase>()
        label = ""
        blockStmts = ArrayList<Stmt>()
        closeBraceLoc = None
        valueExpr = None
        testExpr = None
        yesExpr = None
        noExpr = None
        updateExpr = None
        yesStmt = None
        noStmt = None
        hasNoBranch = false
        hasTest = false
        hasInit = false
        hasUpdate = false
        initStmt = None
        isAwait = false
        hasImportStar = false
        importRecordIndex = 0
        namespaceRef = Ref.NONE
        clauseItems = ArrayList<ClauseItem>()
        isSingleLine = true
        starNameLoc = None
        defaultNameLoc = None
        localKind = LocalKind.Var
        funcNameRef = Ref.NONE
        funcNameLoc = Loc.EMPTY
        classNameRef = Ref.NONE
        classNameLoc = Loc.EMPTY
        labelRef = None
        exportStarAlias = None
        innerStmt = None
        bodyLoc = Loc.EMPTY
        bodyStmts = ArrayList<Stmt>()
        hasCatch = false
        catchLoc = Loc.EMPTY
        hasCatchBinding = false
        catchBodyLoc = Loc.EMPTY
        catchBodyStmts = ArrayList<Stmt>()
        hasFinally = false
        finallyLoc = Loc.EMPTY
        finallyStmts = ArrayList<Stmt>()
        commentText = ""
        directiveValue = ""
        innerStmtVal = None
        isAsync = false
        isGenerator = false
        exportItems = ArrayList<ClauseItem>()
        wasTsImportEquals = false
        funcOpenParensLoc = Loc.EMPTY
        classBodyLoc = Loc.EMPTY
        exprValue = None
        functionValue = None
        classValue = None
        funcName = ""
        funcRef = Ref.NONE
        funcLoc = Loc.EMPTY
        className = ""
        classRef = Ref.NONE
        classLoc = Loc.EMPTY
    }

    public init() {
        this(Loc.EMPTY, StmtTag.Empty)
    }

    // === 工厂方法 ===

    public static func block(loc: Loc, stmts: ArrayList<Stmt>): Stmt {
        let s = Stmt(loc, StmtTag.Block)
        s.stmts = stmts
        return s
    }

    public static func expr_(loc: Loc, value: Expr): Stmt {
        let s = Stmt(loc, StmtTag.Expr)
        s.expr = Some(value)
        return s
    }


    public static func if_(loc: Loc, test: Expr, yes: Stmt, no: ?Stmt): Stmt {
        let s = Stmt(loc, StmtTag.If)
        s.expr = Some(test)
        s.yes = Some(yes)
        s.no = no
        return s
    }

    public static func return_(loc: Loc, value: ?Expr): Stmt {
        let s = Stmt(loc, StmtTag.Return)
        s.expr = value
        return s
    }

    public static func throw_(loc: Loc, value: Expr): Stmt {
        let s = Stmt(loc, StmtTag.Throw)
        s.expr = Some(value)
        return s
    }

    public static func local(loc: Loc, kind: DeclKind, decls: ArrayList<GDecl>): Stmt {
        let s = Stmt(loc, StmtTag.Local)
        s.declKind = kind
        s.decls = decls
        return s
    }

    public static func empty(loc: Loc): Stmt {
        return Stmt(loc, StmtTag.Empty)
    }

    public static func debugger(loc: Loc): Stmt {
        return Stmt(loc, StmtTag.Debugger)
    }

    public static func fn_(loc: Loc, fn: GFn): Stmt {
        let s = Stmt(loc, StmtTag.Function)
        s.fn = Some(fn)
        return s
    }

    public static func `class`(loc: Loc, classData: GClass): Stmt {
        let s = Stmt(loc, StmtTag.Class)
        s.classData = Some(classData)
        return s
    }

    public static func local(loc: Loc, kind: DeclKind, binding: Binding, `init`: ?Expr): Stmt {
        let s = Stmt(loc, StmtTag.Local)
        s.declKind = kind
        let decl = GDecl(binding)
        if (`init`.isSome()) {
            decl.value = `init`
        }
        s.decls = ArrayList<GDecl>()
        s.decls.append(decl)
        return s
    }

    public static func for_(loc: Loc, `init`: ?Expr, test: Expr, update: Expr, body: Stmt): Stmt {
        let s = Stmt(loc, StmtTag.For)
        match (`init`) {
            case Some(e) => s.`init` = Some(Stmt.expr_(e.loc, e))
            case None => s.`init` = None
        }
        s.expr = Some(test)
        s.update = Some(update)
        s.body = Some(body)
        return s
    }

    public static func forWithInit(loc: Loc, initStmt: ?Stmt, test: Expr, update: Expr, body: Stmt): Stmt {
        let s = Stmt(loc, StmtTag.For)
        s.`init` = initStmt
        s.expr = Some(test)
        s.update = Some(update)
        s.body = Some(body)
        return s
    }

    public static func forIn(loc: Loc, kind: DeclKind, binding: Binding, value: Expr, body: Stmt): Stmt {
        let s = Stmt(loc, StmtTag.ForIn)
        s.iterValue = Some(value)
        s.body = Some(body)
        s.declKind = kind
        s.decls = ArrayList<GDecl>()
        s.decls.append(GDecl(binding))
        return s
    }

    public static func forOf(loc: Loc, kind: DeclKind, binding: Binding, value: Expr, body: Stmt): Stmt {
        let s = Stmt(loc, StmtTag.ForOf)
        s.iterValue = Some(value)
        s.body = Some(body)
        s.declKind = kind
        s.decls = ArrayList<GDecl>()
        s.decls.append(GDecl(binding))
        return s
    }

    public static func while_(loc: Loc, test: Expr, body: Stmt): Stmt {
        let s = Stmt(loc, StmtTag.While)
        s.expr = Some(test)
        s.body = Some(body)
        return s
    }

    public static func doWhile(loc: Loc, body: Stmt, test: Expr): Stmt {
        let s = Stmt(loc, StmtTag.DoWhile)
        s.body = Some(body)
        s.expr = Some(test)
        return s
    }

    public static func switch_(loc: Loc, test: Expr, cases: ArrayList<SwitchCase>): Stmt {
        let s = Stmt(loc, StmtTag.Switch)
        s.expr = Some(test)
        s.cases = cases
        return s
    }

    public static func try_(loc: Loc, body: ArrayList<Stmt>, catchBody: ?Stmt, finallyBody: ?Stmt): Stmt {
        let s = Stmt(loc, StmtTag.Try)
        s.stmts = body
        s.catchBody = catchBody
        s.finallyBody = finallyBody
        return s
    }

    public static func with_(loc: Loc, value: Expr, body: Stmt): Stmt {
        let s = Stmt(loc, StmtTag.With)
        s.expr = Some(value)
        s.body = Some(body)
        return s
    }

    public static func break_(loc: Loc, label: String): Stmt {
        let s = Stmt(loc, StmtTag.Break)
        s.label = label
        return s
    }

    public static func continue_(loc: Loc, label: String): Stmt {
        let s = Stmt(loc, StmtTag.Continue)
        s.label = label
        return s
    }

    public static func import_(loc: Loc, recordIndex: Int64): Stmt {
        let s = Stmt(loc, StmtTag.Import)
        return s
    }

    public static func importClause(loc: Loc, defaultImport: ?ClauseItem, starImport: ?ClauseItem,
                                     items: ArrayList<ClauseItem>, recordIndex: Int64): Stmt {
        let s = Stmt(loc, StmtTag.Import)
        s.importItems = items
        return s
    }

    public static func exportDefault(loc: Loc, value: Stmt): Stmt {
        let s = Stmt(loc, StmtTag.Export)
        s.isExport = true
        s.`init` = Some(value)
        return s
    }

    public static func exportDefault(loc: Loc, value: Expr): Stmt {
        let s = Stmt(loc, StmtTag.Export)
        s.isExport = true
        s.expr = Some(value)
        return s
    }

    public static func exportStar(loc: Loc, recordIndex: Int64): Stmt {
        let s = Stmt(loc, StmtTag.Export)
        s.isExport = true
        return s
    }

    public static func exportClause(loc: Loc, items: ArrayList<ClauseItem>, recordIndex: Int64): Stmt {
        let s = Stmt(loc, StmtTag.Export)
        s.isExport = true
        s.importItems = items
        return s
    }

    public static func catch_(loc: Loc, binding: ?Binding, body: ArrayList<Stmt>): Stmt {
        let s = Stmt(loc, StmtTag.Block)
        s.stmts = body
        s.catchBinding = binding
        return s
    }
}

// ============================================================================
// Binding - 绑定模式
// 严格翻译自: src/js_parser/ast/Binding.zig
//   pub const Binding = struct { loc: Loc, data: Data }
//   pub const Data = union(enum) {
//       b_identifier, b_array, b_object, b_missing
//   }
// ============================================================================

/// 绑定类型标签 - 对应 Bun Binding.Data
public enum BindingTag {
    | Identifier    // b_identifier
    | Array         // b_array
    | Object        // b_object
    | Missing       // b_missing

    public operator func ==(right: BindingTag): Bool {
        match (this) {
            case Identifier => match (right) { case Identifier => true case _ => false }
            case Array => match (right) { case Array => true case _ => false }
            case Object => match (right) { case Object => true case _ => false }
            case Missing => match (right) { case Missing => true case _ => false }
        }
    }
}

/// 绑定节点 - 对应 Bun Binding
public class Binding {
    public var loc: Loc
    public var tag: BindingTag

    /// 标识符名称 - 用于 Identifier
    public var name: String
    public var ref: Ref

    /// 数组元素 - 用于 Array binding
    public var arrayItems: ArrayList<Binding>
    /// 对象属性 - 用于 Object binding
    public var objectProperties: ArrayList<BindingProperty>

    /// 默认值
    public var defaultValue: ?Expr

    /// rest 元素
    public var isRest: Bool

    public init(loc: Loc, tag: BindingTag) {
        this.loc = loc
        this.tag = tag
        name = ""
        ref = Ref.NONE
        arrayItems = ArrayList<Binding>()
        objectProperties = ArrayList<BindingProperty>()
        defaultValue = None
        isRest = false
    }

    public static func identifier(loc: Loc, name: String): Binding {
        let b = Binding(loc, BindingTag.Identifier)
        b.name = name
        return b
    }

    /// 创建标识符绑定 (带引用) - 对应 Bun B.Identifier
    public static func identifier(loc: Loc, name: String, ref: Ref): Binding {
        let b = Binding(loc, BindingTag.Identifier)
        b.name = name
        b.ref = ref
        return b
    }

    /// 创建对象绑定 - 对应 Bun B.Object
    public static func object_(loc: Loc, properties: ArrayList<BindingProperty>): Binding {
        let b = Binding(loc, BindingTag.Object)
        b.objectProperties = properties
        return b
    }

    /// 创建数组绑定 - 对应 Bun B.Array
    public static func array_(loc: Loc, items: ArrayList<Binding>): Binding {
        let b = Binding(loc, BindingTag.Array)
        b.arrayItems = items
        return b
    }
}

/// 绑定属性 - 对应 Bun B.Object.Property
public class BindingProperty {
    public var loc: Loc
    public var key: String
    public var value: ?Binding
    public var defaultValue: ?Expr
    public var isComputed: Bool
    public var isShorthand: Bool

    public init(loc: Loc, key: String, value: ?Binding, defaultValue: ?Expr) {
        this.loc = loc
        this.key = key
        this.value = value
        this.defaultValue = defaultValue
        isComputed = false
        isShorthand = false
    }

    public init(key: String, value: Binding) {
        this.loc = Loc.EMPTY
        this.key = key
        this.value = Some(value)
        this.defaultValue = None
        isComputed = false
        isShorthand = false
    }
}

// ============================================================================
// G (Global) - 共享类型
// 严格翻译自: src/js_parser/ast/G.zig
// ============================================================================

/// 函数参数 - 对应 Bun G.Arg
public class GArg {
    public var name: String
    public var loc: Loc
    public var ref: Ref
    public var binding: Binding
    public var default_: ?Expr
    public var isRest: Bool
    public var decorators: ArrayList<Expr>

    public init(binding: Binding) {
        this.binding = binding
        this.name = binding.name
        this.loc = binding.loc
        this.ref = binding.ref
        default_ = None
        isRest = false
        decorators = ArrayList<Expr>()
    }

    public init(name: String, loc: Loc, ref: Ref, default_: ?Expr, isRest: Bool) {
        this.name = name
        this.loc = loc
        this.ref = ref
        this.binding = Binding.identifier(loc, name, ref)
        this.default_ = default_
        this.isRest = isRest
        decorators = ArrayList<Expr>()
    }
}

/// 函数体 - 对应 Bun G.FnBody
public enum GFnBody {
    | StmtBody(Stmt)              // { ... }
    | ExprBody(Expr)              // => expr
    | StmtsBody(ArrayList<Stmt>)  // 多语句
}

/// 函数数据 - 对应 Bun G.Fn
public class GFn {
    public var name: String
    public var args: ArrayList<GArg>
    public var body: GFnBody
    public var isAsync: Bool
    public var isGenerator: Bool
    public var loc: Loc

    public init(loc: Loc) {
        this.loc = loc
        name = ""
        args = ArrayList<GArg>()
        body = GFnBody.StmtsBody(ArrayList<Stmt>())
        isAsync = false
        isGenerator = false
    }

    public init(name: String, args: ArrayList<GArg>, body: GFnBody, loc: Loc) {
        this.name = name
        this.args = args
        this.body = body
        this.loc = loc
        isAsync = false
        isGenerator = false
    }
}

/// 属性类型 - 对应 Bun G.Property.Kind
public enum GPropertyKind {
    | Getter
    | Setter
    | Method
    | Field
    | Spread

    public func toInt(): Int64 {
        match (this) {
            case Getter => 0
            case Setter => 1
            case Method => 2
            case Field => 3
            case Spread => 4
        }
    }

    public operator func ==(right: GPropertyKind): Bool {
        this.toInt() == right.toInt()
    }
}

/// 属性标志 - 对应 Bun Flags.Property
public class GPropertyFlags {
    public var isComputed: Bool
    public var isMethod: Bool
    public var isStatic: Bool
    public var wasShorthand: Bool
    public var isSpread: Bool

    public init() {
        isComputed = false
        isMethod = false
        isStatic = false
        wasShorthand = false
        isSpread = false
    }
}

/// 属性 - 对应 Bun G.Property
public class GProperty {
    public var key: String
    public var keyExpr: ?Expr   // computed property
    public var value: ?Expr
    public var kind: GPropertyKind
    public var flags: GPropertyFlags
    public var loc: Loc
    public var decorators: ArrayList<Expr>
    public var ref: Ref
    public var initializer: ?Expr

    public init(loc: Loc, key: String, value: ?Expr) {
        this.loc = loc
        this.key = key
        this.keyExpr = None
        this.value = value
        kind = GPropertyKind.Field
        flags = GPropertyFlags()
        decorators = ArrayList<Expr>()
        ref = Ref.NONE
        initializer = None
    }

    /// 创建方法属性
    public static func method(loc: Loc, name: String, fn: GFn, isStatic: Bool,
                               isGet: Bool, isSet: Bool, isAsync: Bool): GProperty {
        let p = GProperty(loc, name, Option<Expr>.None)
        p.kind = GPropertyKind.Method
        p.flags.isStatic = isStatic
        p.flags.isMethod = true
        return p
    }

    /// 创建字段属性
    public static func field(loc: Loc, name: String, value: ?Expr, isStatic: Bool): GProperty {
        let p = GProperty(loc, name, value)
        p.kind = GPropertyKind.Field
        p.flags.isStatic = isStatic
        return p
    }
}

/// 声明 - 对应 Bun G.Decl
public class GDecl {
    public var binding: Binding
    public var value: ?Expr

    public init(binding: Binding) {
        this.binding = binding
        value = None
    }

    public init(binding: Binding, value: Expr) {
        this.binding = binding
        this.value = Some(value)
    }
}

/// 类数据 - 对应 Bun G.Class
public class GClass {
    public var name: String
    public var extends_: ?Expr
    public var properties: ArrayList<GProperty>
    public var decorators: ArrayList<Expr>
    public var isExport: Bool
    public var loc: Loc

    public init(loc: Loc) {
        this.loc = loc
        name = ""
        extends_ = None
        properties = ArrayList<GProperty>()
        decorators = ArrayList<Expr>()
        isExport = false
    }

    public init(name: String, extends_: ?Expr, properties: ArrayList<GProperty>, loc: Loc) {
        this.name = name
        this.extends_ = extends_
        this.properties = properties
        this.loc = loc
        decorators = ArrayList<Expr>()
        isExport = false
    }
}

// ============================================================================
// ClauseItem - 导入/导出条目
// 严格翻译自: src/js_parser/js_parser.zig:118-142
//   pub const ClauseItem = struct { alias, alias_loc, name, original_name }
// ============================================================================

/// 导入/导出条目 - 对应 Bun ClauseItem
public class ClauseItem {
    /// 别名 - 对应 ClauseItem.alias
    public var alias: String
    /// 名称引用 - 对应 ClauseItem.name: LocRef
    public var name: String
    /// 原始名称 - 对应 ClauseItem.original_name
    public var originalName: String
    /// 位置
    public var loc: Loc
    /// 引用
    public var ref: Ref
    /// 别名位置
    public var aliasLoc: Loc
    /// 名称位置
    public var nameLoc: Loc
    /// 名称引用
    public var nameRef: Ref
    /// 默认别名 - 对应 Bun ClauseItem.default_alias
    public static let defaultAlias: String = "default"

    public init() {
        alias = ""
        name = ""
        originalName = ""
        loc = Loc.EMPTY
        ref = Ref.NONE
        aliasLoc = Loc.EMPTY
        nameLoc = Loc.EMPTY
        nameRef = Ref.NONE
    }

    public init(alias: String, name: String, loc: Loc) {
        this.alias = alias
        this.name = name
        this.originalName = name
        this.loc = loc
        ref = Ref.NONE
        aliasLoc = Loc.EMPTY
        nameLoc = Loc.EMPTY
        nameRef = Ref.NONE
    }

    public init(originalName: String, alias: String, loc: Loc, ref: Ref) {
        this.originalName = originalName
        this.alias = alias
        this.name = alias
        this.loc = loc
        this.ref = ref
        aliasLoc = Loc.EMPTY
        nameLoc = Loc.EMPTY
        nameRef = Ref.NONE
    }

    public init(originalName: String, alias: String, aliasLoc: Loc, nameLoc: Loc, nameRef: Ref) {
        this.originalName = originalName
        this.alias = alias
        this.name = alias
        this.loc = aliasLoc
        this.ref = nameRef
        this.aliasLoc = aliasLoc
        this.nameLoc = nameLoc
        this.nameRef = nameRef
    }

    /// 是否为默认导入/导出
    public func isDefault(): Bool {
        return alias == "default" || originalName == "default"
    }
}

/// Switch case - 对应 Bun Case
public class SwitchCase {
    public var loc: Loc
    public var value: ?Expr    // None = default
    public var body: ArrayList<Stmt>
    public var valueExpr: ?Expr  // alias used by js_printer

    public init(loc: Loc) {
        this.loc = loc
        value = None
        body = ArrayList<Stmt>()
        valueExpr = None
    }

    public init(value: ?Expr, body: ArrayList<Stmt>) {
        this.loc = Loc.EMPTY
        this.value = value
        this.body = body
        valueExpr = value
    }
}

// ============================================================================
// Scope - 作用域
// 严格翻译自: src/js_parser/ast/Scope.zig
// ============================================================================

/// 作用域类型 - 对应 Bun Scope.Kind
public enum ScopeKind {
    | Block
    | With
    | Label
    | ClassName
    | ClassBody
    | ClassStaticInit  // 静态初始化块
    | CatchBinding     // catch 绑定
    | FunctionArgs     // 函数参数
    | FunctionBody     // 函数体
    | Function
    | ArrowFunction
    | Module
    | Entry            // 命名空间/枚举入口
    | EntryBlock       // 模块入口块

    public operator func ==(right: ScopeKind): Bool {
        match (this) {
            case Block => match (right) { case Block => true case _ => false }
            case With => match (right) { case With => true case _ => false }
            case Label => match (right) { case Label => true case _ => false }
            case ClassName => match (right) { case ClassName => true case _ => false }
            case ClassBody => match (right) { case ClassBody => true case _ => false }
            case ClassStaticInit => match (right) { case ClassStaticInit => true case _ => false }
            case CatchBinding => match (right) { case CatchBinding => true case _ => false }
            case FunctionArgs => match (right) { case FunctionArgs => true case _ => false }
            case FunctionBody => match (right) { case FunctionBody => true case _ => false }
            case Function => match (right) { case Function => true case _ => false }
            case ArrowFunction => match (right) { case ArrowFunction => true case _ => false }
            case Module => match (right) { case Module => true case _ => false }
            case Entry => match (right) { case Entry => true case _ => false }
            case EntryBlock => match (right) { case EntryBlock => true case _ => false }
        }
    }

    public operator func !=(right: ScopeKind): Bool {
        return !(this == right)
    }
}

/// 作用域成员
public class ScopeMember {
    public var name: String
    public var ref: Ref

    public init(name: String, ref: Ref) {
        this.name = name
        this.ref = ref
    }
}

/// 作用域 - 对应 Bun Scope
public class Scope {
    /// 作用域 ID
    public var id: Int64
    /// 作用域类型
    public var kind: ScopeKind
    /// 父作用域列表 (parser.cj 使用 ArrayList)
    public var parent: ArrayList<Scope>
    /// 子作用域
    public var children: ArrayList<Scope>
    /// 成员列表
    public var members: ArrayList<ScopeMember>
    /// 成员映射 (快速查找)
    public var memberMap: HashMap<String, Ref>
    /// 是否包含直接 eval
    public var containsDirectEval: Bool
    /// 严格模式
    public var strictMode: StrictModeKind
    /// 是否在 const local prefix 之后 - 对应 Bun Scope.is_after_const_local_prefix
    public var isAfterConstLocalPrefix: Bool

    public init(id: Int64, kind: ScopeKind) {
        this.id = id
        this.kind = kind
        parent = ArrayList<Scope>()
        children = ArrayList<Scope>()
        members = ArrayList<ScopeMember>()
        memberMap = HashMap<String, Ref>()
        containsDirectEval = false
        strictMode = StrictModeKind.SloppyMode
        isAfterConstLocalPrefix = false
    }

    public init(kind: ScopeKind, parent: ArrayList<Scope>) {
        this.id = 0
        this.kind = kind
        this.parent = parent
        children = ArrayList<Scope>()
        members = ArrayList<ScopeMember>()
        memberMap = HashMap<String, Ref>()
        containsDirectEval = false
        strictMode = StrictModeKind.SloppyMode
        isAfterConstLocalPrefix = false
    }

    /// 兼容 scan_symbols - 计算成员名称哈希
    public static func getMemberHash(name: String): UInt64 {
        // 简单 DJB2 哈希
        var hash: UInt64 = 5381
        for (i in 0..name.size) {
            hash = hash * UInt64(33) + UInt64(name[i])
        }
        return hash
    }
}

// ============================================================================
// Symbol - 符号
// 严格翻译自: src/js_parser/ast/Symbol.zig
// ============================================================================

/// 符号类型 - 对应 Bun Symbol.Kind
public enum SymbolKind {
    | Unbound            // 未绑定 (全局变量)
    | Import             // 导入符号
    | Export             // 导出符号
    | Resolved           // 已解析
    | Constant           // const 声明
    | Let                // let 声明
    | Var                // var 声明
    | Hoisted            // 提升的声明
    | HoistedFunction    // 提升的函数声明
    | Class              // 类名
    | Label              // 标签
    | Other              // 其他
    | Private            // 私有字段
    | PrivateStatic      // 静态私有字段
    | PrivateMethod      // 私有方法
    | PrivateStaticMethod // 静态私有方法
    | PrivateGet         // 私有 getter
    | PrivateSet         // 私有 setter
    | PrivateStaticGet   // 静态私有 getter
    | PrivateStaticSet   // 静态私有 setter
    | Ref

    public func toInt(): Int64 {
        match (this) {
            case Unbound => 0
            case Import => 1
            case Export => 2
            case Resolved => 3
            case Constant => 4
            case Let => 5
            case Var => 6
            case Hoisted => 7
            case HoistedFunction => 8
            case Class => 9
            case Label => 10
            case Other => 11
            case Private => 12
            case PrivateStatic => 13
            case PrivateMethod => 14
            case PrivateStaticMethod => 15
            case PrivateGet => 16
            case PrivateSet => 17
            case PrivateStaticGet => 18
            case PrivateStaticSet => 19
            case Ref => 20
        }
    }

    public operator func ==(right: SymbolKind): Bool {
        return this.toInt() == right.toInt()
    }

    public operator func !=(right: SymbolKind): Bool {
        return !(this == right)
    }

    /// 是否为私有成员类型
    public func isPrivate(): Bool {
        match (this) {
            case Private | PrivateStatic | PrivateMethod |
                 PrivateStaticMethod | PrivateGet | PrivateSet |
                 PrivateStaticGet | PrivateStaticSet =>
                return true
            case _ =>
                return false
        }
    }
}

/// 符号 - 对应 Bun Symbol
public class Symbol {
    /// 原始名称
    public var originalName: String
    /// 引用
    public var ref: Ref
    /// 使用计数估算
    public var useCountEstimate: Int64
    /// 符号类型
    public var kind: SymbolKind
    /// 链接引用 - 对应 Bun Symbol.link
    public var link: Ref
    /// 是否已被赋值 - 对应 Bun Symbol.has_been_assigned_to
    public var hasBeenAssignedTo: Bool
    /// 命名空间别名引用 - 对应 Bun Symbol.namespace_alias.namespace_ref
    public var namespaceAliasRef: Ref
    /// 命名空间别名导入记录索引 - 对应 Bun Symbol.namespace_alias.import_record_index
    public var namespaceAliasImportRecordIndex: UInt32

    public init(name: String, ref: Ref) {
        this.originalName = name
        this.ref = ref
        useCountEstimate = 0
        kind = SymbolKind.Other
        namespaceAliasRef = Ref.NONE
        namespaceAliasImportRecordIndex = 0
        link = Ref.NONE
        hasBeenAssignedTo = false
    }

    public init(kind: SymbolKind, name: String, ref: Ref) {
        this.kind = kind
        this.originalName = name
        this.ref = ref
        useCountEstimate = 0
        namespaceAliasRef = Ref.NONE
        namespaceAliasImportRecordIndex = 0
        link = Ref.NONE
        hasBeenAssignedTo = false
    }
}
