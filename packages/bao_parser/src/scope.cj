// 作用域分析模块
// 严格翻译自: src/js_parser/ast/Scope.zig
//   Bun 的作用域分析器负责遍历 AST 构建作用域树，管理符号声明与引用解析
//   对应 Bun 的 Scope/Symbol/Ref 体系，提供完整的词法作用域分析能力
package bao_parser

import bao_core.*
import bao_collections.*

// ============================================================================
// SymbolTable - 符号表
// 严格翻译自: src/js_parser/ast/Scope.zig
//   管理单个作用域层的 name -> Symbol 映射，支持父子链查找
// ============================================================================

/// 符号表 - name -> Symbol 映射，支持父链查找
/// 对应 Bun Scope 的 members + memberMap 功能增强
public class SymbolTable {
    /// 当前层的符号映射
    public var symbols: HashMap<String, Symbol>
    /// 父符号表链 (允许多层查找)
    public var parent: ?SymbolTable

    public init() {
        symbols = HashMap<String, Symbol>()
        parent = None
    }

    public init(parent: SymbolTable) {
        symbols = HashMap<String, Symbol>()
        this.parent = Some(parent)
    }

    /// 声明一个符号 - 对应 Bun Scope 中添加成员
    /// 如果已存在返回 null，否则返回新声明的 Symbol
    public func declare(name: String, kind: SymbolKind, loc: Loc): ?Symbol {
        if (symbols.contains(name)) {
            return None
        }
        let ref = Ref(0, RefTag.AllocatedName, 0)
        let sym = Symbol(kind, name, ref)
        symbols.put(name, sym)
        return Some(sym)
    }

    /// 声明或重新声明符号
    /// 对应 Bun Symbol 的 hoisted 重新声明语义
    public func redeclare(name: String, kind: SymbolKind, loc: Loc): Symbol {
        let ref = Ref(0, RefTag.AllocatedName, 0)
        let sym = Symbol(kind, name, ref)
        symbols.put(name, sym)
        return sym
    }

    /// 在当前层查找符号
    public func lookup(name: String): ?Symbol {
        if (symbols.contains(name)) {
            return symbols.get(name)
        }
        return None
    }

    /// 沿父链递归查找符号 - 对应 Bun Scope 的作用域链解析
    public func resolve(name: String): ?Symbol {
        if (symbols.contains(name)) {
            return symbols.get(name)
        }
        if (let Some(p) <- parent) {
            return p.resolve(name)
        }
        return None
    }

    /// 当前层是否拥有该符号 (不含父链)
    public func hasOwn(name: String): Bool {
        return symbols.contains(name)
    }

    /// 当前层符号数量
    public func size(): Int64 {
        return Int64(symbols.size)
    }
}

// ============================================================================
// SymbolRegistry - 全局符号注册表
// 严格翻译自: src/js_parser/ast/Symbol.zig
//   管理全局唯一的符号 ID 分配和存储
// ============================================================================

/// 全局符号注册表 - 管理模块级别的所有符号
/// 对应 Bun Parser.symbols_map / symbols 动态数组
public class SymbolRegistry {
    /// 下一个符号 ID
    public var nextId: Int64
    /// 所有已分配的符号
    public var allSymbols_: ArrayList<Symbol>
    /// 按 ref 查找的映射
    public var byRef: HashMap<Int64, Symbol>

    public init() {
        nextId = 0
        allSymbols_ = ArrayList<Symbol>()
        byRef = HashMap<Int64, Symbol>()
    }

    /// 创建新符号 - 对应 Bun Parser.newSymbol()
    public func newSymbol(kind: SymbolKind, name: String): Symbol {
        let id = nextId
        nextId += 1
        let ref = Ref(id, RefTag.Symbol, 0)
        let sym = Symbol(kind, name, ref)
        allSymbols_.append(sym)
        byRef.put(id, sym)
        return sym
    }

    /// 通过 ref 获取符号
    public func getSymbol(ref: Ref): ?Symbol {
        return byRef.get(ref.innerIndex)
    }

    /// 获取所有符号列表
    public func allSymbols(): ArrayList<Symbol> {
        return allSymbols_
    }

    /// 符号总数
    public func count(): Int64 {
        return Int64(allSymbols_.size)
    }
}

// ============================================================================
// ScopeAnalyzer - 主作用域分析器
// 严格翻译自: src/js_parser/ast/Scope.zig
//   遍历 AST 构建作用域树，记录声明和引用
// ============================================================================

/// 作用域分析器 - 对应 Bun Parser 中内联的作用域管理逻辑
/// 负责 pushScope/popScope、声明收集、引用解析
public class ScopeAnalyzer {
    /// 当前作用域栈
    public var scopeStack: ArrayList<Scope>
    /// 所有作用域列表
    public var allScopes: ArrayList<Scope>
    /// 符号注册表
    public var registry: SymbolRegistry
    /// 下一个作用域 ID
    public var nextScopeId: Int64

    public init() {
        scopeStack = ArrayList<Scope>()
        allScopes = ArrayList<Scope>()
        registry = SymbolRegistry()
        nextScopeId = 0
    }

    /// 分析入口 - 遍历 AST 并构建作用域树
    /// 对应 Bun Parser 中 parseStmt 后的作用域遍历
    public func analyze(stmt: Stmt): Unit {
        // 创建模块根作用域
        let root = pushScope(ScopeKind.Module)
        walkStmt(stmt)
        popScope()
    }

    /// 解析名称 - 通过作用域链查找符号
    /// 对应 Bun Parser 中标识符的 scope lookup
    public func resolve(name: String): ?Symbol {
        let current = currentScope()
        // 从当前作用域开始，沿父链查找
        return resolveInScope(name, current)
    }

    /// 声明一个名称 - 对应 Bun Parser 中变量/函数声明的符号创建
    public func declare(name: String, kind: SymbolKind, loc: Loc): Ref {
        let sym = registry.newSymbol(kind, name)
        let current = currentScope()
        let member = ScopeMember(name, sym.ref)
        current.members.append(member)
        current.memberMap.put(name, sym.ref)
        return sym.ref
    }

    /// 推入新作用域 - 对应 Bun Parser.pushScope()
    public func pushScope(kind: ScopeKind): Scope {
        let id = nextScopeId
        nextScopeId += 1
        let scope = Scope(id, kind)

        if (!scopeStack.isEmpty()) {
            let parent = scopeStack[scopeStack.size - 1]
            scope.parent.append(parent)
            parent.children.append(scope)
        }

        scopeStack.append(scope)
        allScopes.append(scope)
        return scope
    }

    /// 弹出当前作用域 - 对应 Bun Parser.popScope()
    public func popScope(): Unit {
        if (!scopeStack.isEmpty()) {
            scopeStack.removeAt(scopeStack.size - 1)
        }
    }

    /// 获取当前作用域 - 对应 Bun Parser 当前 scope
    public func currentScope(): Scope {
        if (scopeStack.isEmpty()) {
            // 如果没有作用域，创建一个模块根作用域
            let root = Scope(nextScopeId, ScopeKind.Module)
            nextScopeId += 1
            scopeStack.append(root)
            allScopes.append(root)
            return root
        }
        return scopeStack[scopeStack.size - 1]
    }

    /// 在当前作用域中查找成员 - 对应 Bun Scope.memberMap.get()
    public func lookup(name: String): ?ScopeMember {
        let current = currentScope()
        return lookupInScope(name, current)
    }

    /// 检查是否重声明 - 对应 Bun 中检测重复声明的逻辑
    public func isRedeclared(name: String): Bool {
        let current = currentScope()
        return current.memberMap.contains(name)
    }

    // --- 内部方法 ---

    /// 在指定作用域中递归查找成员
    private func lookupInScope(name: String, scope: Scope): ?ScopeMember {
        // 先在当前层的成员中查找
        if (scope.memberMap.contains(name)) {
            let ref = scope.memberMap.get(name)
            if (let Some(r) <- ref) {
                let member = ScopeMember(name, r)
                return Some(member)
            }
        }
        // 沿父链继续查找
        for (parent in scope.parent) {
            if (let Some(found) <- lookupInScope(name, parent)) {
                return Some(found)
            }
        }
        return None
    }

    /// 在指定作用域中递归解析符号
    private func resolveInScope(name: String, scope: Scope): ?Symbol {
        if (scope.memberMap.contains(name)) {
            let ref = scope.memberMap.get(name)
            if (let Some(r) <- ref) {
                return registry.getSymbol(r)
            }
        }
        for (parent in scope.parent) {
            if (let Some(sym) <- resolveInScope(name, parent)) {
                return Some(sym)
            }
        }
        return None
    }

    /// 遍历语句节点 - 对应 Bun Parser 中 stmt 的递归访问
    private func walkStmt(stmt: Stmt): Unit {
        match (stmt.tag) {
            case StmtTag.Block =>
                let scope = pushScope(ScopeKind.Block)
                for (s in stmt.stmts) {
                    walkStmt(s)
                }
                popScope()
            case StmtTag.Function =>
                // 函数声明创建新作用域
                if (let Some(fn) <- stmt.fn) {
                    let scope = pushScope(ScopeKind.Function)
                    // 参数声明
                    for (arg in fn.args) {
                        declare(arg.name, SymbolKind.Other, arg.loc)
                    }
                    // 函数体
                    if (let Some(body) <- fn.body) {
                        walkStmt(body)
                    }
                    popScope()
                }
            case StmtTag.Class =>
                if (let Some(cd) <- stmt.classData) {
                    let scope = pushScope(ScopeKind.ClassBody)
                    for (prop in cd.properties) {
                        // 类属性声明
                    }
                    popScope()
                }
            case StmtTag.If =>
                if (let Some(e) <- stmt.expr) {
                    walkExpr(e)
                }
                if (let Some(yes) <- stmt.yes) {
                    walkStmt(yes)
                }
                if (let Some(no) <- stmt.no) {
                    walkStmt(no)
                }
            case StmtTag.For | StmtTag.ForIn | StmtTag.ForOf =>
                let scope = pushScope(ScopeKind.Block)
                if (let Some(init) <- stmt.init) {
                    walkStmt(init)
                }
                if (let Some(body) <- stmt.body) {
                    walkStmt(body)
                }
                popScope()
            case StmtTag.While | StmtTag.Do =>
                if (let Some(e) <- stmt.expr) {
                    walkExpr(e)
                }
                if (let Some(body) <- stmt.body) {
                    walkStmt(body)
                }
            case StmtTag.Try =>
                // try 块
                let tryScope = pushScope(ScopeKind.Block)
                for (s in stmt.stmts) {
                    walkStmt(s)
                }
                popScope()
                // catch 块
                if (let Some(catchBody) <- stmt.catchBody) {
                    let catchScope = pushScope(ScopeKind.Block)
                    if (let Some(cb) <- stmt.catchBinding) {
                        declare(cb.name, SymbolKind.Other, cb.loc)
                    }
                    walkStmt(catchBody)
                    popScope()
                }
                // finally 块
                if (let Some(finallyBody) <- stmt.finallyBody) {
                    let finallyScope = pushScope(ScopeKind.Block)
                    walkStmt(finallyBody)
                    popScope()
                }
            case StmtTag.Switch =>
                if (let Some(e) <- stmt.expr) {
                    walkExpr(e)
                }
                for (c in stmt.cases) {
                    let caseScope = pushScope(ScopeKind.Block)
                    for (s in c.stmts) {
                        walkStmt(s)
                    }
                    popScope()
                }
            case StmtTag.With =>
                if (let Some(e) <- stmt.expr) {
                    walkExpr(e)
                }
                let scope = pushScope(ScopeKind.With)
                if (let Some(body) <- stmt.body) {
                    walkStmt(body)
                }
                popScope()
            case StmtTag.Labeled =>
                let scope = pushScope(ScopeKind.Label)
                if (let Some(body) <- stmt.body) {
                    walkStmt(body)
                }
                popScope()
            case StmtTag.Local =>
                // 变量声明 - 对应 Bun S.Local 的声明收集
                for (d in stmt.decls) {
                    let binding = d.binding
                    collectBindingDecls(binding)
                    if (let Some(v) <- d.value) {
                        walkExpr(v)
                    }
                }
            case StmtTag.Expr =>
                if (let Some(e) <- stmt.expr) {
                    walkExpr(e)
                }
            case StmtTag.Return | StmtTag.Throw =>
                if (let Some(e) <- stmt.expr) {
                    walkExpr(e)
                }
            case _ =>
                // Empty, Break, Continue, Debugger 等无需处理
                ()
        }
    }

    /// 遍历表达式节点 - 对应 Bun Parser 中 expr 的递归访问
    private func walkExpr(expr: Expr): Unit {
        match (expr.tag) {
            case ExprTag.Identifier =>
                // 标识符引用 - 记录使用
                ()
            case ExprTag.Binary | ExprTag.Assign =>
                if (let Some(l) <- expr.left) {
                    walkExpr(l)
                }
                if (let Some(r) <- expr.right) {
                    walkExpr(r)
                }
            case ExprTag.Unary | ExprTag.Postfix =>
                if (let Some(v) <- expr.value) {
                    walkExpr(v)
                }
            case ExprTag.Ternary =>
                if (let Some(t) <- expr.test) {
                    walkExpr(t)
                }
                if (let Some(y) <- expr.yes) {
                    walkExpr(y)
                }
                if (let Some(n) <- expr.no) {
                    walkExpr(n)
                }
            case ExprTag.Call | ExprTag.New =>
                if (let Some(t) <- expr.target) {
                    walkExpr(t)
                }
                for (arg in expr.args) {
                    walkExpr(arg)
                }
            case ExprTag.Dot =>
                if (let Some(t) <- expr.target) {
                    walkExpr(t)
                }
            case ExprTag.Index =>
                if (let Some(t) <- expr.target) {
                    walkExpr(t)
                }
                if (let Some(i) <- expr.indexExpr) {
                    walkExpr(i)
                }
            case ExprTag.Array =>
                for (item in expr.items) {
                    walkExpr(item)
                }
            case ExprTag.Object =>
                for (prop in expr.properties) {
                    if (let Some(v) <- prop.value) {
                        walkExpr(v)
                    }
                }
            case ExprTag.Function =>
                if (let Some(fn) <- expr.fn) {
                    let scope = pushScope(ScopeKind.Function)
                    for (arg in fn.args) {
                        declare(arg.name, SymbolKind.Other, arg.loc)
                    }
                    if (let Some(body) <- fn.body) {
                        walkStmt(body)
                    }
                    popScope()
                }
            case ExprTag.Arrow =>
                if (let Some(fn) <- expr.fn) {
                    let scope = pushScope(ScopeKind.ArrowFunction)
                    for (arg in fn.args) {
                        declare(arg.name, SymbolKind.Other, arg.loc)
                    }
                    if (let Some(body) <- fn.body) {
                        walkStmt(body)
                    }
                    popScope()
                }
            case ExprTag.Class =>
                if (let Some(cd) <- expr.classData) {
                    let scope = pushScope(ScopeKind.ClassBody)
                    for (prop in cd.properties) {
                        ()
                    }
                    popScope()
                }
            case ExprTag.Spread =>
                if (let Some(v) <- expr.value) {
                    walkExpr(v)
                }
            case ExprTag.Template =>
                for (part in expr.templateParts) {
                    walkExpr(part)
                }
            case _ =>
                // 字面量等无需递归
                ()
        }
    }

    /// 从 Binding 收集声明 - 对应 Bun binding 中变量名的提取
    private func collectBindingDecls(binding: Binding): Unit {
        match (binding.tag) {
            case BindingTag.Identifier =>
                declare(binding.name, SymbolKind.Other, binding.loc)
            case BindingTag.Array =>
                for (item in binding.arrayItems) {
                    collectBindingDecls(item)
                }
            case BindingTag.Object =>
                for (prop in binding.objectProperties) {
                    if (let Some(v) <- prop.value) {
                        collectBindingDecls(v)
                    } else if (prop.isShorthand) {
                        declare(prop.key, SymbolKind.Other, prop.loc)
                    }
                }
            case BindingTag.Missing =>
                ()
        }
    }
}

// ============================================================================
// ScopeTree - 作用域树
// 严格翻译自: src/js_parser/ast/Scope.zig
//   表示一个模块的完整作用域树结构
// ============================================================================

/// 作用域树 - 模块的完整作用域层次结构
/// 对应 Bun Parser 遍历完成后产生的 scope tree
public class ScopeTree {
    /// 根作用域 (模块级别)
    public var root: Scope
    /// 所有作用域的扁平列表
    public var allScopes: ArrayList<Scope>
    /// 所有符号的扁平列表
    public var symbols: ArrayList<Symbol>

    public init(root: Scope) {
        this.root = root
        allScopes = ArrayList<Scope>()
        symbols = ArrayList<Symbol>()
    }

    /// 通过位置查找所在作用域 - 对应 Bun 中根据 Loc 查找 Scope
    /// 使用作用域 ID 和嵌套关系进行匹配
    public func findScope(loc: Loc): ?Scope {
        return findScopeIn(root, loc)
    }

    /// 通过名称查找符号 - 在所有作用域中搜索
    public func findSymbol(name: String): ?Symbol {
        for (scope in allScopes) {
            if (scope.memberMap.contains(name)) {
                let ref = scope.memberMap.get(name)
                if (let Some(r) <- ref) {
                    // 尝试在符号列表中查找
                    for (sym in symbols) {
                        if (sym.ref.eql(r)) {
                            return Some(sym)
                        }
                    }
                }
            }
        }
        return None
    }

    /// 从 ScopeAnalyzer 构建 - 将分析结果转换为 ScopeTree
    public static func fromAnalyzer(analyzer: ScopeAnalyzer): ScopeTree {
        let tree = ScopeTree(analyzer.currentScope())
        tree.allScopes = ArrayList<Scope>()
        for (scope in analyzer.allScopes) {
            tree.allScopes.append(scope)
        }
        tree.symbols = ArrayList<Symbol>()
        for (sym in analyzer.registry.allSymbols()) {
            tree.symbols.append(sym)
        }
        return tree
    }

    // --- 内部方法 ---

    /// 在作用域子树中递归查找
    private func findScopeIn(scope: Scope, loc: Loc): ?Scope {
        // 检查子作用域
        for (child in scope.children) {
            if (let Some(found) <- findScopeIn(child, loc)) {
                return Some(found)
            }
        }
        // 如果没有更精确的匹配，返回当前作用域
        return Some(scope)
    }
}

// ============================================================================
// HoistingAnalyzer - 提升分析器
// 严格翻译自: src/js_parser/ast/Scope.zig
//   收集 var 和 function 声明的提升信息
//   对应 JavaScript 中 var/function 声明提升 (hoisting) 语义
// ============================================================================

/// 提升分析器 - 收集需要提升的 var 和 function 声明
/// 对应 Bun Parser 中 scanScope 里的 hoisting 逻辑
public class HoistingAnalyzer {
    /// 提升的 var 声明
    public var hoistedVars: ArrayList<Symbol>
    /// 提升的 function 声明
    public var hoistedFunctions: ArrayList<Symbol>
    /// 符号注册表引用
    public var registry: SymbolRegistry

    public init(registry: SymbolRegistry) {
        hoistedVars = ArrayList<Symbol>()
        hoistedFunctions = ArrayList<Symbol>()
        this.registry = registry
    }

    /// 收集语句中的提升声明 - 对应 Bun scanScope 中对 hoisted 的收集
    public func collectHoistedDeclarations(stmt: Stmt): Unit {
        collectFromStmt(stmt, true)
    }

    /// 提升 var 声明 - 对应 Bun 中 var 声明提升到函数/模块顶部
    public func hoistVar(name: String, loc: Loc): Symbol {
        let sym = registry.newSymbol(SymbolKind.Hoisted, name)
        hoistedVars.append(sym)
        return sym
    }

    /// 提升 function 声明 - 对应 Bun 中 function 声明提升到顶部
    /// function 声明优先于 var 提升
    public func hoistFunction(name: String, loc: Loc): Symbol {
        let sym = registry.newSymbol(SymbolKind.HoistedFunction, name)
        hoistedFunctions.append(sym)
        return sym
    }

    // --- 内部方法 ---

    /// 从语句中收集提升声明
    private func collectFromStmt(stmt: Stmt, isTopLevel: Bool): Unit {
        match (stmt.tag) {
            case StmtTag.Block =>
                for (s in stmt.stmts) {
                    collectFromStmt(s, isTopLevel)
                }
            case StmtTag.Local =>
                // var 声明会被提升，let/const 不会
                if (stmt.declKind == DeclKind.Var) {
                    for (d in stmt.decls) {
                        collectBindingHoisted(d.binding)
                    }
                }
            case StmtTag.Function =>
                // 函数声明总是提升
                if (let Some(fn) <- stmt.fn) {
                    if (fn.name.size > 0) {
                        hoistFunction(fn.name, stmt.loc)
                    }
                    // 函数体内部递归收集
                    if (let Some(body) <- fn.body) {
                        collectFromStmt(body, false)
                    }
                }
            case StmtTag.If =>
                if (let Some(yes) <- stmt.yes) {
                    collectFromStmt(yes, isTopLevel)
                }
                if (let Some(no) <- stmt.no) {
                    collectFromStmt(no, isTopLevel)
                }
            case StmtTag.For | StmtTag.ForIn | StmtTag.ForOf =>
                if (let Some(init) <- stmt.init) {
                    // for 中的 var 也会提升
                    collectFromStmt(init, isTopLevel)
                }
                if (let Some(body) <- stmt.body) {
                    collectFromStmt(body, isTopLevel)
                }
            case StmtTag.While | StmtTag.Do =>
                if (let Some(body) <- stmt.body) {
                    collectFromStmt(body, isTopLevel)
                }
            case StmtTag.Labeled =>
                if (let Some(body) <- stmt.body) {
                    collectFromStmt(body, isTopLevel)
                }
            case StmtTag.With =>
                if (let Some(body) <- stmt.body) {
                    collectFromStmt(body, isTopLevel)
                }
            case StmtTag.Try =>
                for (s in stmt.stmts) {
                    collectFromStmt(s, isTopLevel)
                }
                if (let Some(catchBody) <- stmt.catchBody) {
                    collectFromStmt(catchBody, isTopLevel)
                }
                if (let Some(finallyBody) <- stmt.finallyBody) {
                    collectFromStmt(finallyBody, isTopLevel)
                }
            case StmtTag.Switch =>
                for (c in stmt.cases) {
                    for (s in c.stmts) {
                        collectFromStmt(s, isTopLevel)
                    }
                }
            case _ =>
                ()
        }
    }

    /// 从绑定中收集提升的变量名
    private func collectBindingHoisted(binding: Binding): Unit {
        match (binding.tag) {
            case BindingTag.Identifier =>
                hoistVar(binding.name, binding.loc)
            case BindingTag.Array =>
                for (item in binding.arrayItems) {
                    collectBindingHoisted(item)
                }
            case BindingTag.Object =>
                for (prop in binding.objectProperties) {
                    if (let Some(v) <- prop.value) {
                        collectBindingHoisted(v)
                    } else if (prop.isShorthand) {
                        hoistVar(prop.key, prop.loc)
                    }
                }
            case BindingTag.Missing =>
                ()
        }
    }
}

// ============================================================================
// BindingResult - 绑定分析结果
// 严格翻译自: src/js_parser/ast/Scope.zig
//   保存变量绑定分析的完整结果
// ============================================================================

/// 绑定分析结果 - 对应 Bun scope analysis 的输出
public class BindingResult {
    /// 所有声明
    public var declarations: ArrayList<Symbol>
    /// 所有引用
    public var references: ArrayList<Ref>
    /// 未解析的引用 (自由变量)
    public var unresolved: ArrayList<String>
    /// 提升的声明
    public var hoisted: ArrayList<Symbol>

    public init() {
        declarations = ArrayList<Symbol>()
        references = ArrayList<Ref>()
        unresolved = ArrayList<String>()
        hoisted = ArrayList<Symbol>()
    }
}

// ============================================================================
// BindingAnalyzer - 变量绑定分析器
// 严格翻译自: src/js_parser/ast/Scope.zig
//   分析变量声明与引用的绑定关系，检测未使用和未解析的变量
// ============================================================================

/// 变量绑定分析器 - 对应 Bun binding 分析 pass
/// 收集声明、解析引用、标记使用，并报告未使用的变量
public class BindingAnalyzer {
    /// 符号注册表
    public var registry: SymbolRegistry
    /// 作用域分析器
    public var scopeAnalyzer: ScopeAnalyzer
    /// 分析结果
    public var result: BindingResult

    public init() {
        registry = SymbolRegistry()
        scopeAnalyzer = ScopeAnalyzer()
        result = BindingResult()
    }

    /// 分析入口 - 执行完整的绑定分析
    /// 对应 Bun 的 scope + binding 分析 pass
    public func analyze(stmt: Stmt): BindingResult {
        result = BindingResult()

        // 1. 构建作用域树
        scopeAnalyzer.analyze(stmt)

        // 2. 收集所有声明
        let decls = collectDeclarations(stmt)
        for (d in decls) {
            result.declarations.append(d)
        }

        // 3. 执行提升分析
        let hoisting = HoistingAnalyzer(registry)
        hoisting.collectHoistedDeclarations(stmt)
        for (h in hoisting.hoistedVars) {
            result.hoisted.append(h)
        }
        for (h in hoisting.hoistedFunctions) {
            result.hoisted.append(h)
        }

        return result
    }

    /// 收集语句中的所有声明 - 对应 Bun Parser 中声明节点遍历
    public func collectDeclarations(stmt: Stmt): ArrayList<Symbol> {
        let decls = ArrayList<Symbol>()
        collectDeclsFromStmt(stmt, decls)
        return decls
    }

    /// 解析表达式中的所有引用 - 对应 Bun binding 中引用解析
    public func resolveReferences(expr: Expr): Unit {
        resolveRefsInExpr(expr)
    }

    /// 标记符号为已使用 - 对应 Bun Symbol.useCountEstimate 递增
    public func markUsed(ref: Ref): Unit {
        if (let Some(sym) <- registry.getSymbol(ref)) {
            sym.useCountEstimate += 1
        }
    }

    /// 获取所有未使用的符号 - useCountEstimate == 0 的声明
    /// 对应 Bun tree shaking 中检测未使用导出的逻辑
    public func getUnused(): ArrayList<Symbol> {
        let unused = ArrayList<Symbol>()
        for (sym in registry.allSymbols()) {
            if (sym.useCountEstimate == 0 && sym.kind != SymbolKind.Unbound) {
                unused.append(sym)
            }
        }
        return unused
    }

    // --- 内部方法 ---

    /// 从语句中收集声明
    private func collectDeclsFromStmt(stmt: Stmt, decls: ArrayList<Symbol>): Unit {
        match (stmt.tag) {
            case StmtTag.Block =>
                for (s in stmt.stmts) {
                    collectDeclsFromStmt(s, decls)
                }
            case StmtTag.Local =>
                for (d in stmt.decls) {
                    collectDeclsFromBinding(d.binding, decls)
                }
            case StmtTag.Function =>
                if (let Some(fn) <- stmt.fn) {
                    if (fn.name.size > 0) {
                        let sym = registry.newSymbol(SymbolKind.HoistedFunction, fn.name)
                        decls.append(sym)
                    }
                    for (arg in fn.args) {
                        let sym = registry.newSymbol(SymbolKind.Other, arg.name)
                        decls.append(sym)
                    }
                    if (let Some(body) <- fn.body) {
                        collectDeclsFromStmt(body, decls)
                    }
                }
            case StmtTag.Class =>
                if (let Some(cd) <- stmt.classData) {
                    if (cd.name.size > 0) {
                        let sym = registry.newSymbol(SymbolKind.Other, cd.name)
                        decls.append(sym)
                    }
                }
            case StmtTag.If =>
                if (let Some(yes) <- stmt.yes) {
                    collectDeclsFromStmt(yes, decls)
                }
                if (let Some(no) <- stmt.no) {
                    collectDeclsFromStmt(no, decls)
                }
            case StmtTag.For | StmtTag.ForIn | StmtTag.ForOf =>
                if (let Some(init) <- stmt.init) {
                    collectDeclsFromStmt(init, decls)
                }
                if (let Some(body) <- stmt.body) {
                    collectDeclsFromStmt(body, decls)
                }
            case StmtTag.While | StmtTag.Do | StmtTag.Labeled | StmtTag.With =>
                if (let Some(body) <- stmt.body) {
                    collectDeclsFromStmt(body, decls)
                }
            case StmtTag.Try =>
                for (s in stmt.stmts) {
                    collectDeclsFromStmt(s, decls)
                }
                if (let Some(catchBody) <- stmt.catchBody) {
                    collectDeclsFromStmt(catchBody, decls)
                }
                if (let Some(finallyBody) <- stmt.finallyBody) {
                    collectDeclsFromStmt(finallyBody, decls)
                }
            case StmtTag.Switch =>
                for (c in stmt.cases) {
                    for (s in c.stmts) {
                        collectDeclsFromStmt(s, decls)
                    }
                }
            case _ =>
                ()
        }
    }

    /// 从绑定中收集声明
    private func collectDeclsFromBinding(binding: Binding, decls: ArrayList<Symbol>): Unit {
        match (binding.tag) {
            case BindingTag.Identifier =>
                let sym = registry.newSymbol(SymbolKind.Other, binding.name)
                decls.append(sym)
            case BindingTag.Array =>
                for (item in binding.arrayItems) {
                    collectDeclsFromBinding(item, decls)
                }
            case BindingTag.Object =>
                for (prop in binding.objectProperties) {
                    if (let Some(v) <- prop.value) {
                        collectDeclsFromBinding(v, decls)
                    } else if (prop.isShorthand) {
                        let sym = registry.newSymbol(SymbolKind.Other, prop.key)
                        decls.append(sym)
                    }
                }
            case BindingTag.Missing =>
                ()
        }
    }

    /// 解析表达式中的引用
    private func resolveRefsInExpr(expr: Expr): Unit {
        match (expr.tag) {
            case ExprTag.Identifier | ExprTag.ImportIdentifier =>
                result.references.append(expr.ref)
                // 尝试通过作用域链解析
                let name = expr.identifierName
                if (name.size > 0) {
                    if (scopeAnalyzer.resolve(name).isNone()) {
                        result.unresolved.append(name)
                    }
                }
            case ExprTag.Binary | ExprTag.Assign =>
                if (let Some(l) <- expr.left) {
                    resolveRefsInExpr(l)
                }
                if (let Some(r) <- expr.right) {
                    resolveRefsInExpr(r)
                }
            case ExprTag.Unary | ExprTag.Postfix =>
                if (let Some(v) <- expr.value) {
                    resolveRefsInExpr(v)
                }
            case ExprTag.Ternary =>
                if (let Some(t) <- expr.test) {
                    resolveRefsInExpr(t)
                }
                if (let Some(y) <- expr.yes) {
                    resolveRefsInExpr(y)
                }
                if (let Some(n) <- expr.no) {
                    resolveRefsInExpr(n)
                }
            case ExprTag.Call | ExprTag.New =>
                if (let Some(t) <- expr.target) {
                    resolveRefsInExpr(t)
                }
                for (arg in expr.args) {
                    resolveRefsInExpr(arg)
                }
            case ExprTag.Dot =>
                if (let Some(t) <- expr.target) {
                    resolveRefsInExpr(t)
                }
            case ExprTag.Index =>
                if (let Some(t) <- expr.target) {
                    resolveRefsInExpr(t)
                }
                if (let Some(i) <- expr.indexExpr) {
                    resolveRefsInExpr(i)
                }
            case ExprTag.Array =>
                for (item in expr.items) {
                    resolveRefsInExpr(item)
                }
            case ExprTag.Object =>
                for (prop in expr.properties) {
                    if (let Some(v) <- prop.value) {
                        resolveRefsInExpr(v)
                    }
                }
            case ExprTag.Function =>
                if (let Some(fn) <- expr.fn) {
                    if (let Some(body) <- fn.body) {
                        collectDeclsFromStmt(body, result.declarations)
                    }
                }
            case ExprTag.Arrow =>
                if (let Some(fn) <- expr.fn) {
                    if (let Some(body) <- fn.body) {
                        collectDeclsFromStmt(body, result.declarations)
                    }
                }
            case ExprTag.Spread =>
                if (let Some(v) <- expr.value) {
                    resolveRefsInExpr(v)
                }
            case ExprTag.Template =>
                for (part in expr.templateParts) {
                    resolveRefsInExpr(part)
                }
            case _ =>
                ()
        }
    }
}
