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
    | This              // e_this
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
    }

    // === 工厂方法 (对应 Bun 中 p.e 的各种分配方法) ===

    /// 创建布尔表达式 - 对应 Bun Expr.init(E.Boolean, .{ .value = v }, loc)
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
        return Expr(loc, ExprTag.This)
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
    | Block         // s_block - S.Block { stmts }
    | Expr          // s_expr - S.SExpr { value }
    | If            // s_if - S.If { test_, yes, no }
    | For           // s_for - S.For { init, test_, update, body }
    | ForIn         // s_for_in - S.ForIn { init, value, body }
    | ForOf         // s_for_of - S.ForOf { init, value, body }
    | While         // s_while - S.While { test_, body }
    | DoWhile       // s_do_while - S.DoWhile { test_, body }
    | Function      // s_function - S.Function { func }
    | Class         // s_class - S.Class { class, is_export }
    | Import        // s_import - S.Import { namespace_ref, default_name, items }
    | Export        // s_export - 多种导出
    | Local         // s_local - S.Local { kind, decls, is_export }
    | Return        // s_return - S.Return { value }
    | Throw         // s_throw - S.Throw { value }
    | Try           // s_try - S.Try { body, catch_, finally }
    | Switch        // s_switch - S.Switch { test_, cases }
    | Break         // s_break
    | Continue      // s_continue
    | Debugger      // s_debugger
    | Empty         // s_empty
    | With          // s_with
    | Labeled       // s_label
    | Type          // TypeScript 类型声明
    | Enum          // TypeScript enum
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
    public var init: ?Stmt
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

    // --- 异常处理 ---
    /// catch 子句 - 对应 S.Try.catch_
    public var catchBody: ?Stmt
    public var catchBinding: ?Binding
    /// finally 子句 - 对应 S.Try.finally
    public var finallyBody: ?Stmt

    // --- switch ---
    public var cases: ArrayList<SwitchCase>
    public var label: String

    public init(loc: Loc, tag: StmtTag) {
        this.loc = loc
        this.tag = tag
        stmts = ArrayList<Stmt>()
        expr = None
        yes = None
        no = None
        init = None
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
        catchBody = None
        catchBinding = None
        finallyBody = None
        cases = ArrayList<SwitchCase>()
        label = ""
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

    /// 表达式语句 (别名)
    public static func expr(loc: Loc, value: Expr): Stmt {
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

    public static func fn(loc: Loc, fn: GFn): Stmt {
        let s = Stmt(loc, StmtTag.Function)
        s.fn = Some(fn)
        return s
    }

    public static func class(loc: Loc, classData: GClass): Stmt {
        let s = Stmt(loc, StmtTag.Class)
        s.classData = Some(classData)
        return s
    }

    public static func local(loc: Loc, kind: DeclKind, binding: Binding, init: ?Expr): Stmt {
        let s = Stmt(loc, StmtTag.Local)
        s.declKind = kind
        let decl = GDecl(binding)
        if (init.isSome()) {
            decl.value = init
        }
        s.decls = ArrayList<GDecl>()
        s.decls.append(decl)
        return s
    }

    public static func for_(loc: Loc, init: ?Expr, test: Expr, update: Expr, body: Stmt): Stmt {
        let s = Stmt(loc, StmtTag.For)
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
        s.init = Some(value)
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
    | Stmt(Stmt)              // { ... }
    | Expr(Expr)              // => expr
    | Stmts(ArrayList<Stmt>)  // 多语句
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
        body = GFnBody.Stmts(ArrayList<Stmt>())
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

    public init(loc: Loc, key: String, value: ?Expr) {
        this.loc = loc
        this.key = key
        this.keyExpr = None
        this.value = value
        kind = GPropertyKind.Field
        flags = GPropertyFlags()
    }

    /// 创建方法属性
    public static func method(loc: Loc, name: String, fn: GFn, isStatic: Bool,
                               isGet: Bool, isSet: Bool, isAsync: Bool): GProperty {
        let p = GProperty(loc, name, None)
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

    public init(alias: String, name: String, loc: Loc) {
        this.alias = alias
        this.name = name
        this.originalName = name
        this.loc = loc
        ref = Ref.NONE
    }

    public init(originalName: String, alias: String, loc: Loc, ref: Ref) {
        this.originalName = originalName
        this.alias = alias
        this.name = alias
        this.loc = loc
        this.ref = ref
    }
}

/// Switch case - 对应 Bun Case
public class SwitchCase {
    public var loc: Loc
    public var value: ?Expr    // None = default
    public var body: ArrayList<Stmt>

    public init(loc: Loc) {
        this.loc = loc
        value = None
        body = ArrayList<Stmt>()
    }

    public init(value: ?Expr, body: ArrayList<Stmt>) {
        this.loc = Loc.EMPTY
        this.value = value
        this.body = body
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
    | Function
    | ArrowFunction
    | Module
    | EntryBlock  // 模块入口块
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

    public init(id: Int64, kind: ScopeKind) {
        this.id = id
        this.kind = kind
        parent = ArrayList<Scope>()
        children = ArrayList<Scope>()
        members = ArrayList<ScopeMember>()
        memberMap = HashMap<String, Ref>()
        containsDirectEval = false
        strictMode = StrictModeKind.SloppyMode
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
    }
}

// ============================================================================
// Symbol - 符号
// 严格翻译自: src/js_parser/ast/Symbol.zig
// ============================================================================

/// 符号类型 - 对应 Bun Symbol.Kind
public enum SymbolKind {
    | Other
    | Unbound
    | Hoisted
    | HoistedFunction
    | Import
    | Ref
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

    public init(name: String, ref: Ref) {
        this.originalName = name
        this.ref = ref
        useCountEstimate = 0
        kind = SymbolKind.Other
    }

    public init(kind: SymbolKind, name: String, ref: Ref) {
        this.kind = kind
        this.originalName = name
        this.ref = ref
        useCountEstimate = 0
    }
}
