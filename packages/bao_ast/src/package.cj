// bao_ast - AST 扩展分析
// 严格翻译自: src/ast/
//   ast.zig           - Ast 顶层结构 (parts, symbols, scopes, import_records)
//   expr.zig          - Expr 联合类型 (E.Boolean, E.String, E.Array, E.Object, ...)
//   stmt.zig          - Stmt 联合类型 (S.Block, S.If, S.For, S.Function, ...)
//   binding.zig       - Binding 联合类型 (B.Identifier, B.Array, B.Object)
//   scope.zig         - Scope 结构 (members, children, parent, kind)
//   symbol.zig        - Symbol 结构 (kind, original_name, use_count_estimate)
//   base.zig          - Ref, Index 基础引用类型
package bao_ast

import bao_core.*
import bao_collections.*
import bao_parser.*

// ============================================================================
// AST 节点类型标签
// 严格翻译自: src/ast/expr.zig (Expr.Tag), src/ast/stmt.zig (Stmt.Tag),
//             src/ast/binding.zig (Binding.Tag)
// ============================================================================

/// 表达式标签 - 对应 Bun Expr.Tag (expr.zig)
public enum ExprTag {
    | Missing        // e_missing
    | Boolean        // e_boolean
    | Null           // e_null
    | Undefined      // e_undefined
    | Number         // e_number
    | BigInt         // e_big_int
    | String         // e_string
    | Template       // e_template
    | RegExp         // e_reg_exp
    | Identifier     // e_identifier
    | ImportIdentifier // e_import_identifier
    | This           // e_this
    | Super          // e_super
    | Array          // e_array
    | Object         // e_object
    | Arrow          // e_arrow
    | Function       // e_function
    | Class          // e_class
    | Call           // e_call
    | New            // e_new
    | Member         // e_member
    | Index          // e_index
    | TaggedTemplate // e_tagged_template
    | Spread         // e_spread
    | Binary         // e_binary
    | Unary          // e_unary
    | Await          // e_await
    | Yield          // e_yield
    | Conditional    // e_conditional  (ternary)
    | Assign         // e_assign
    | Sequence       // e_sequence
    | TypeCast       // e_type_cast
    | JsxElement     // e_jsx
    | JsxFragment    // e_jsx_fragment
    | InlinedEnum    // e_inlined_enum
    | RequireString  // e_require_string
    | ImportRecord   // e_import_record

    public func name(): String {
        match (this) {
            case Missing => "Missing"
            case Boolean => "Boolean"
            case Null => "Null"
            case Undefined => "Undefined"
            case Number => "Number"
            case BigInt => "BigInt"
            case String => "String"
            case Template => "Template"
            case RegExp => "RegExp"
            case Identifier => "Identifier"
            case ImportIdentifier => "ImportIdentifier"
            case This => "This"
            case Super => "Super"
            case Array => "Array"
            case Object => "Object"
            case Arrow => "Arrow"
            case Function => "Function"
            case Class => "Class"
            case Call => "Call"
            case New => "New"
            case Member => "Member"
            case Index => "Index"
            case TaggedTemplate => "TaggedTemplate"
            case Spread => "Spread"
            case Binary => "Binary"
            case Unary => "Unary"
            case Await => "Await"
            case Yield => "Yield"
            case Conditional => "Conditional"
            case Assign => "Assign"
            case Sequence => "Sequence"
            case TypeCast => "TypeCast"
            case JsxElement => "JsxElement"
            case JsxFragment => "JsxFragment"
            case InlinedEnum => "InlinedEnum"
            case RequireString => "RequireString"
            case ImportRecord => "ImportRecord"
        }
    }
}

/// 语句标签 - 对应 Bun Stmt.Tag (stmt.zig)
public enum StmtTag {
    | Empty          // s_empty
    | Block          // s_block
    | Expr           // s_expr (expression statement)
    | If             // s_if
    | For            // s_for
    | ForIn          // s_for_in
    | ForOf          // s_for_of
    | While          // s_while
    | DoWhile        // s_do_while
    | Switch         // s_switch
    | Break          // s_break
    | Continue       // s_continue
    | Return         // s_return
    | Throw          // s_throw
    | Try            // s_try
    | With           // s_with
    | Function       // s_function
    | Class          // s_class
    | Debugger       // s_debugger
    | Label          // s_label
    | Import         // s_import
    | ExportClause   // s_export_clause
    | ExportDefault  // s_export_default
    | ExportStar     // s_export_star
    | ExportEquals   // s_export_equals
    | ExportFrom     // s_export_from
    | Local          // s_local (variable declarations)
    | Directive      // s_directive ("use strict")
    | Namespace      // s_namespace (TS namespace)
    | Enum           // s_enum (TS enum)
    | TypeScript     // s_type_script (TS-specific)
    | Comment        // s_comment

    public func name(): String {
        match (this) {
            case Empty => "Empty"
            case Block => "Block"
            case Expr => "Expr"
            case If => "If"
            case For => "For"
            case ForIn => "ForIn"
            case ForOf => "ForOf"
            case While => "While"
            case DoWhile => "DoWhile"
            case Switch => "Switch"
            case Break => "Break"
            case Continue => "Continue"
            case Return => "Return"
            case Throw => "Throw"
            case Try => "Try"
            case With => "With"
            case Function => "Function"
            case Class => "Class"
            case Debugger => "Debugger"
            case Label => "Label"
            case Import => "Import"
            case ExportClause => "ExportClause"
            case ExportDefault => "ExportDefault"
            case ExportStar => "ExportStar"
            case ExportEquals => "ExportEquals"
            case ExportFrom => "ExportFrom"
            case Local => "Local"
            case Directive => "Directive"
            case Namespace => "Namespace"
            case Enum => "Enum"
            case TypeScript => "TypeScript"
            case Comment => "Comment"
        }
    }
}

/// 绑定标签 - 对应 Bun Binding.Tag (binding.zig)
public enum BindingTag {
    | Identifier     // b_identifier
    | Array          // b_array  (array destructuring)
    | Object         // b_object (object destructuring)
    | Missing        // b_missing

    public func name(): String {
        match (this) {
            case Identifier => "Identifier"
            case Array => "Array"
            case Object => "Object"
            case Missing => "Missing"
        }
    }
}

/// 模式标签 - 用于模式匹配分析
public enum PatternTag {
    | Identifier
    | Rest
    | ObjectProperty
    | ArrayElement
    | Assignment
    | Default
}

// ============================================================================
// ASTNode - 通用 AST 节点包装器
// 严格翻译自: src/ast/expr.zig (Expr), src/ast/stmt.zig (Stmt)
// Bun 使用 tagged union (Expr = struct { loc, data: Data })
// 仓颉使用带类型标签的包装类
// ============================================================================

/// 通用 AST 节点 - 对应 Bun Expr/Stmt 的统一包装
/// Bun: pub const Expr = struct { loc: logger.Loc, data: Data }
/// Bun: pub const Stmt = struct { loc: logger.Loc, data: Data }
/// 仓颉用通用节点类包装所有 AST 节点类型
public class ASTNode {
    /// 节点类型 - 对应 Bun tag 字段
    public var tag: ExprTag
    /// 源码位置 - 对应 Bun loc: logger.Loc
    public var loc: Loc
    /// 子节点 - 对应 Bun 嵌套结构 (如 E.Block.stmts, E.Array.items)
    public var children: ArrayList<ASTNode>
    /// 节点数据 - 泛化存储 (如字符串值、数字值)
    public var value: Any
    /// 附加属性 - 用于存储额外信息 (如 E.Object.properties)
    public var properties: HashMap<String, Any>

    public init(tag: ExprTag, loc: Loc) {
        this.tag = tag
        this.loc = loc
        this.children = ArrayList<ASTNode>()
        this.value = None
        this.properties = HashMap<String, Any>()
    }

    public init(tag: ExprTag, loc: Loc, value: Any) {
        this.tag = tag
        this.loc = loc
        this.children = ArrayList<ASTNode>()
        this.value = value
        this.properties = HashMap<String, Any>()
    }

    /// 添加子节点
    public func addChild(child: ASTNode): Unit {
        children.append(child)
    }

    /// 获取子节点数量
    public prop childCount: Int64 {
        get() { children.size }
    }

    /// 是否为表达式节点
    public func isExpr(): Bool {
        match (tag) {
            case ExprTag.Missing | ExprTag.Boolean | ExprTag.Null | ExprTag.Undefined |
                 ExprTag.Number | ExprTag.BigInt | ExprTag.String | ExprTag.Template |
                 ExprTag.RegExp | ExprTag.Identifier | ExprTag.ImportIdentifier |
                 ExprTag.This | ExprTag.Super | ExprTag.Array | ExprTag.Object |
                 ExprTag.Arrow | ExprTag.Function | ExprTag.Class | ExprTag.Call |
                 ExprTag.New | ExprTag.Member | ExprTag.Index | ExprTag.TaggedTemplate |
                 ExprTag.Spread | ExprTag.Binary | ExprTag.Unary | ExprTag.Await |
                 ExprTag.Yield | ExprTag.Conditional | ExprTag.Assign | ExprTag.Sequence |
                 ExprTag.TypeCast | ExprTag.JsxElement | ExprTag.JsxFragment |
                 ExprTag.InlinedEnum | ExprTag.RequireString | ExprTag.ImportRecord => true
        }
    }

    /// 是否为字面量 - 对应 Bun Expr.canBeConstValue()
    public func isLiteral(): Bool {
        match (tag) {
            case ExprTag.Boolean | ExprTag.Null | ExprTag.Undefined |
                 ExprTag.Number | ExprTag.BigInt | ExprTag.String | ExprTag.RegExp => true
            case _ => false
        }
    }

    /// 获取字符串值 (如果是 String 节点)
    public func stringValue(): ?String {
        match (tag) {
            case ExprTag.String => value as String
            case _ => None
        }
    }

    /// 获取数字值 (如果是 Number 节点)
    public func numberValue(): ?Float64 {
        match (tag) {
            case ExprTag.Number => value as Float64
            case _ => None
        }
    }

    /// 获取布尔值 (如果是 Boolean 节点)
    public func boolValue(): ?Bool {
        match (tag) {
            case ExprTag.Boolean => value as Bool
            case _ => None
        }
    }

    /// 深度 - 从此节点到最深叶节点的路径长度
    public func depth(): Int64 {
        if (children.size == 0) {
            return Int64(0)
        }
        var maxChild = Int64(0)
        for (child in children) {
            let d = child.depth()
            if (d > maxChild) {
                maxChild = d
            }
        }
        return maxChild + Int64(1)
    }

    /// 克隆节点 (浅拷贝) - 对应 Bun Expr.clone()
    public func clone(): ASTNode {
        let node = ASTNode(tag, loc)
        node.value = value
        for (child in children) {
            node.children.append(child)
        }
        return node
    }

    /// 深度克隆 - 对应 Bun Expr.deepClone()
    public func deepClone(): ASTNode {
        let node = ASTNode(tag, loc)
        node.value = value
        for (child in children) {
            node.children.append(child.deepClone())
        }
        return node
    }
}

/// 语句 AST 节点 - 对应 Bun Stmt
public class StmtNode {
    public var tag: StmtTag
    public var loc: Loc
    public var children: ArrayList<ASTNode>
    public var stmts: ArrayList<StmtNode>
    public var value: Any
    public var properties: HashMap<String, Any>

    public init(tag: StmtTag, loc: Loc) {
        this.tag = tag
        this.loc = loc
        this.children = ArrayList<ASTNode>()
        this.stmts = ArrayList<StmtNode>()
        this.value = None
        this.properties = HashMap<String, Any>()
    }

    /// 是否为 TypeScript 专用语句 - 对应 Bun Stmt.isTypeScript()
    public func isTypeScript(): Bool {
        tag == StmtTag.TypeScript
    }

    /// 是否为空语句 - 对应 Bun Stmt.empty()
    public func isEmpty(): Bool {
        tag == StmtTag.Empty
    }

    /// 添加子语句
    public func addStmt(stmt: StmtNode): Unit {
        stmts.append(stmt)
    }

    /// 添加子表达式节点
    public func addChild(child: ASTNode): Unit {
        children.append(child)
    }
}

/// 绑定 AST 节点 - 对应 Bun Binding
/// Bun: pub const Binding = struct { loc: logger.Loc, data: Data }
public class BindingNode {
    public var tag: BindingTag
    public var loc: Loc
    public var children: ArrayList<BindingNode>
    public var name: String
    public var defaultValue: ?ASTNode
    public var isSpread: Bool

    public init(tag: BindingTag, loc: Loc) {
        this.tag = tag
        this.loc = loc
        this.children = ArrayList<BindingNode>()
        this.name = ""
        this.defaultValue = None
        this.isSpread = false
    }

    public init(tag: BindingTag, loc: Loc, name: String) {
        this.tag = tag
        this.loc = loc
        this.children = ArrayList<BindingNode>()
        this.name = name
        this.defaultValue = None
        this.isSpread = false
    }
}

// ============================================================================
// ASTVisitor - 通用访问者模式
// 严格翻译自: src/ast/ 中的遍历模式
// Bun 在 js_parser 和 bundler 中使用 switch(tag) 遍历 AST
// 仓颉用 Visitor 接口 + 泛型返回值实现 GoF Visitor 模式
// ============================================================================

/// AST 访问者接口 - 对应 Bun 中对 AST 节点的 switch 遍历模式
/// Bun 中没有显式 Visitor trait，但在 bundler/linker 中反复使用
/// switch(expr.data) { .e_array => ..., .e_object => ..., } 模式
public interface ASTVisitor<T> {
    /// 访问表达式节点 - 对应 switch(expr.data) 中的各 case
    func visitExpr(node: ASTNode): T
    /// 访问语句节点 - 对应 switch(stmt.data) 中的各 case
    func visitStmt(node: StmtNode): T
    /// 访问绑定节点 - 对应 switch(binding.data) 中的各 case
    func visitBinding(node: BindingNode): T
    /// 访问模式节点 - 用于解构模式分析
    func visitPattern(node: ASTNode): T

    /// 访问前的钩子 - 用于预处理
    func preVisit(node: ASTNode): Unit {}
    /// 访问后的钩子 - 用于后处理
    func postVisit(node: ASTNode, result: T): Unit {}
}

/// 默认访问者实现 - 提供空操作的基类
public class DefaultVisitor<T> <: ASTVisitor<T> {
    protected var result: T

    public init(defaultValue: T) {
        this.result = defaultValue
    }

    public func visitExpr(node: ASTNode): T {
        for (child in node.children) {
            visitExpr(child)
        }
        return result
    }

    public func visitStmt(node: StmtNode): T {
        for (stmt in node.stmts) {
            visitStmt(stmt)
        }
        for (child in node.children) {
            visitExpr(child)
        }
        return result
    }

    public func visitBinding(node: BindingNode): T {
        for (child in node.children) {
            visitBinding(child)
        }
        return result
    }

    public func visitPattern(node: ASTNode): T {
        for (child in node.children) {
            visitPattern(child)
        }
        return result
    }

    public func preVisit(node: ASTNode): Unit {}
    public func postVisit(node: ASTNode, result: T): Unit {}
}

// ============================================================================
// ASTWalker - 递归遍历器 (前序/后序)
// 严格翻译自: src/ast/ 中隐含的深度优先遍历
// Bun 在 printer/bundler 中使用递归函数遍历 AST 树
// ============================================================================

/// 遍历顺序
public enum WalkOrder {
    | PreOrder   // 先访问父节点，再递归子节点
    | PostOrder  // 先递归子节点，再访问父节点
}

/// AST 递归遍历器 - 对应 Bun 中 AST 的递归遍历逻辑
/// Bun 使用递归函数: traverseExpr(expr) { switch(expr.data) { ... traverseExpr(child) ... } }
public class ASTWalker {
    /// 前序遍历表达式节点
    /// 对应 Bun bundler 中对 AST 节点的深度优先遍历
    public static func walkExpr(node: ASTNode, visitor: (ASTNode) -> Bool): Unit {
        if (!visitor(node)) {
            return
        }
        for (child in node.children) {
            walkExpr(child, visitor)
        }
    }

    /// 后序遍历表达式节点
    public static func walkExprPost(node: ASTNode, visitor: (ASTNode) -> Unit): Unit {
        for (child in node.children) {
            walkExprPost(child, visitor)
        }
        visitor(node)
    }

    /// 前序遍历语句节点
    public static func walkStmt(node: StmtNode, visitor: (StmtNode) -> Bool): Unit {
        if (!visitor(node)) {
            return
        }
        for (child in node.children) {
            walkExpr(child, { n =>
                visitor(StmtNode(StmtTag.Expr, n.loc))
                true
            })
        }
        for (stmt in node.stmts) {
            walkStmt(stmt, visitor)
        }
    }

    /// 后序遍历语句节点
    public static func walkStmtPost(node: StmtNode, visitor: (StmtNode) -> Unit): Unit {
        for (child in node.children) {
            walkExprPost(child, { n =>
                visitor(StmtNode(StmtTag.Expr, n.loc))
            })
        }
        for (stmt in node.stmts) {
            walkStmtPost(stmt, visitor)
        }
        visitor(node)
    }

    /// 遍历绑定节点
    public static func walkBinding(node: BindingNode, visitor: (BindingNode) -> Bool): Unit {
        if (!visitor(node)) {
            return
        }
        for (child in node.children) {
            walkBinding(child, visitor)
        }
    }

    /// 通用遍历 (可配置前序/后序)
    public static func walk(
        node: ASTNode,
        order: WalkOrder,
        preVisitor: (ASTNode) -> Bool,
        postVisitor: (ASTNode) -> Unit
    ): Unit {
        if (order == WalkOrder.PreOrder) {
            if (!preVisitor(node)) {
                return
            }
        }
        for (child in node.children) {
            walk(child, order, preVisitor, postVisitor)
        }
        if (order == WalkOrder.PostOrder) {
            postVisitor(node)
        }
    }

    /// 收集所有匹配的节点 - 对应 Bun 中 AST 查询模式
    public static func collect(node: ASTNode, predicate: (ASTNode) -> Bool): ArrayList<ASTNode> {
        let result = ArrayList<ASTNode>()
        walkExpr(node, { n =>
            if (predicate(n)) {
                result.append(n)
            }
            true
        })
        return result
    }

    /// 查找第一个匹配节点
    public static func findFirst(node: ASTNode, predicate: (ASTNode) -> Bool): ?ASTNode {
        var found: ?ASTNode = None
        walkExpr(node, { n =>
            if (predicate(n)) {
                found = Some(n)
                return false  // 停止遍历
            }
            true
        })
        return found
    }

    /// 统计节点数量
    public static func count(node: ASTNode, predicate: (ASTNode) -> Bool): Int64 {
        var total = Int64(0)
        walkExpr(node, { n =>
            if (predicate(n)) {
                total += Int64(1)
            }
            true
        })
        return total
    }
}

// ============================================================================
// ASTPrinter - AST 美化打印
// 严格翻译自: src/js_printer/ 中的 AST 打印逻辑
// Bun 使用 js_printer 将 AST 重新打印为 JS 代码
// 仓颉实现通用的 AST 结构打印器
// ============================================================================

/// AST 美化打印器 - 对应 Bun js_printer 的 AST 输出功能
/// Bun: pub fn printAst(tree: *const Ast, opts: PrintOptions) []const u8
public class ASTPrinter {
    private var sb: StringBuilder
    private var indent: Int64
    private var indentStr: String
    private var maxDepth: Int64
    private var showLoc: Bool
    private var showValues: Bool

    public init() {
        sb = StringBuilder()
        indent = Int64(0)
        indentStr = "  "
        maxDepth = Int64(100)
        showLoc = false
        showValues = true
    }

    public init(showLoc: Bool, showValues: Bool) {
        sb = StringBuilder()
        indent = Int64(0)
        indentStr = "  "
        maxDepth = Int64(100)
        this.showLoc = showLoc
        this.showValues = showValues
    }

    /// 打印表达式节点为字符串
    public func printExpr(node: ASTNode): String {
        sb = StringBuilder()
        indent = Int64(0)
        doPrintExpr(node, Int64(0))
        return sb.toString()
    }

    /// 打印语句节点为字符串
    public func printStmt(node: StmtNode): String {
        sb = StringBuilder()
        indent = Int64(0)
        doPrintStmt(node, Int64(0))
        return sb.toString()
    }

    /// 打印绑定节点为字符串
    public func printBinding(node: BindingNode): String {
        sb = StringBuilder()
        indent = Int64(0)
        doPrintBinding(node, Int64(0))
        return sb.toString()
    }

    /// 打印完整 AST 树 (含多个根语句)
    public func printTree(stmts: ArrayList<StmtNode>): String {
        sb = StringBuilder()
        indent = Int64(0)
        for (stmt in stmts) {
            doPrintStmt(stmt, Int64(0))
        }
        return sb.toString()
    }

    private func doPrintExpr(node: ASTNode, depth: Int64): Unit {
        if (depth > maxDepth) {
            writeIndent()
            sb.append("...(max depth exceeded)\n")
            return
        }
        writeIndent()
        sb.append(node.tag.name())
        if (showLoc) {
            sb.append(" @")
            sb.append(node.loc.start.toString())
        }
        if (showValues) {
            match (node.tag) {
                case ExprTag.String => {
                    let v = node.stringValue()
                    match (v) {
                        case Some(s) => sb.append(" \"").append(s).append("\"")
                        case None => ()
                    }
                }
                case ExprTag.Number => {
                    let v = node.numberValue()
                    match (v) {
                        case Some(n) => sb.append(" ").append(n.toString())
                        case None => ()
                    }
                }
                case ExprTag.Boolean => {
                    let v = node.boolValue()
                    match (v) {
                        case Some(b) => sb.append(" ").append(b.toString())
                        case None => ()
                    }
                }
                case ExprTag.Null => sb.append(" null")
                case ExprTag.Undefined => sb.append(" undefined")
                case ExprTag.Identifier => {
                    let v = node.value as String
                    match (v) {
                        case Some(s) => sb.append(" ").append(s)
                        case None => ()
                    }
                }
                case _ => ()
            }
        }
        if (node.children.size > Int64(0)) {
            sb.append(" {\n")
            indent += Int64(1)
            for (child in node.children) {
                doPrintExpr(child, depth + Int64(1))
            }
            indent -= Int64(1)
            writeIndent()
            sb.append("}\n")
        } else {
            sb.append("\n")
        }
    }

    private func doPrintStmt(node: StmtNode, depth: Int64): Unit {
        if (depth > maxDepth) {
            writeIndent()
            sb.append("...(max depth exceeded)\n")
            return
        }
        writeIndent()
        sb.append(node.tag.name())
        if (showLoc) {
            sb.append(" @")
            sb.append(node.loc.start.toString())
        }
        let hasContent = node.children.size > Int64(0) || node.stmts.size > Int64(0)
        if (hasContent) {
            sb.append(" {\n")
            indent += Int64(1)
            for (stmt in node.stmts) {
                doPrintStmt(stmt, depth + Int64(1))
            }
            for (child in node.children) {
                doPrintExpr(child, depth + Int64(1))
            }
            indent -= Int64(1)
            writeIndent()
            sb.append("}\n")
        } else {
            sb.append("\n")
        }
    }

    private func doPrintBinding(node: BindingNode, depth: Int64): Unit {
        if (depth > maxDepth) {
            writeIndent()
            sb.append("...(max depth exceeded)\n")
            return
        }
        writeIndent()
        sb.append(node.tag.name())
        if (node.name.size > Int64(0)) {
            sb.append(" ").append(node.name)
        }
        if (node.isSpread) {
            sb.append(" ...")
        }
        if (node.children.size > Int64(0)) {
            sb.append(" {\n")
            indent += Int64(1)
            for (child in node.children) {
                doPrintBinding(child, depth + Int64(1))
            }
            indent -= Int64(1)
            writeIndent()
            sb.append("}\n")
        } else {
            sb.append("\n")
        }
    }

    private func writeIndent(): Unit {
        var i = Int64(0)
        while (i < indent) {
            sb.append(indentStr)
            i += Int64(1)
        }
    }
}

// ============================================================================
// ASTComparer - AST 节点比较
// 严格翻译自: src/ast/expr.zig 中的 eql 比较, src/ast/symbol.zig 中的 Symbol 比较
// Bun 通过字段逐个比较来判断 AST 节点是否相等
// ============================================================================

/// AST 比较器 - 对应 Bun 中 AST 节点的结构相等比较
/// Bun: Expr.eql() 通过比较 tag 和数据字段判断相等
public class ASTComparer {
    /// 比较两个表达式节点是否结构相等
    /// 对应 Bun 中对 Expr 的深度比较
    public static func compareExpr(a: ASTNode, b: ASTNode): Bool {
        if (a.tag != b.tag) {
            return false
        }
        if (a.children.size != b.children.size) {
            return false
        }
        // 比较值
        match (a.tag) {
            case ExprTag.String => {
                let va = a.stringValue()
                let vb = b.stringValue()
                match (va) {
                    case Some(sa) => match (vb) {
                        case Some(sb) => if (sa != sb) { return false }
                        case None => return false
                    }
                    case None => if (vb.isSome()) { return false }
                }
            }
            case ExprTag.Number => {
                let va = a.numberValue()
                let vb = b.numberValue()
                match (va) {
                    case Some(na) => match (vb) {
                        case Some(nb) => if (na != nb) { return false }
                        case None => return false
                    }
                    case None => if (vb.isSome()) { return false }
                }
            }
            case ExprTag.Boolean => {
                let va = a.boolValue()
                let vb = b.boolValue()
                match (va) {
                    case Some(ba) => match (vb) {
                        case Some(bb) => if (ba != bb) { return false }
                        case None => return false
                    }
                    case None => if (vb.isSome()) { return false }
                }
            }
            case ExprTag.Null | ExprTag.Undefined => () // 标签匹配即可
            case _ => ()
        }
        // 递归比较子节点
        let aChildren = a.children
        let bChildren = b.children
        for (i in Int64(0)..aChildren.size) {
            if (!compareExpr(aChildren[i], bChildren[i])) {
                return false
            }
        }
        return true
    }

    /// 比较两个语句节点是否结构相等
    public static func compareStmt(a: StmtNode, b: StmtNode): Bool {
        if (a.tag != b.tag) {
            return false
        }
        if (a.stmts.size != b.stmts.size) {
            return false
        }
        if (a.children.size != b.children.size) {
            return false
        }
        for (i in Int64(0)..a.stmts.size) {
            if (!compareStmt(a.stmts[i], b.stmts[i])) {
                return false
            }
        }
        for (i in Int64(0)..a.children.size) {
            if (!compareExpr(a.children[i], b.children[i])) {
                return false
            }
        }
        return true
    }

    /// 比较两个绑定节点是否结构相等
    public static func compareBinding(a: BindingNode, b: BindingNode): Bool {
        if (a.tag != b.tag) {
            return false
        }
        if (a.name != b.name) {
            return false
        }
        if (a.children.size != b.children.size) {
            return false
        }
        for (i in Int64(0)..a.children.size) {
            if (!compareBinding(a.children[i], b.children[i])) {
                return false
            }
        }
        return true
    }

    /// 计算两个 AST 的差异数量
    public static func diffCount(a: ASTNode, b: ASTNode): Int64 {
        var diffs = Int64(0)
        if (a.tag != b.tag) {
            return Int64(1)
        }
        let maxLen = if (a.children.size > b.children.size) {
            a.children.size
        } else {
            b.children.size
        }
        for (i in Int64(0)..maxLen) {
            let ac = if (i < a.children.size) {
                Some(a.children[i])
            } else {
                None
            }
            let bc = if (i < b.children.size) {
                Some(b.children[i])
            } else {
                None
            }
            match (ac) {
                case Some(aChild) => match (bc) {
                    case Some(bChild) => diffs += diffCount(aChild, bChild)
                    case None => diffs += Int64(1)
                }
                case None => diffs += Int64(1)
            }
        }
        return diffs
    }
}
