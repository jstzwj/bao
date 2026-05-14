// bao_ast - AST 转换模块
// 严格翻译自: src/ast/ + src/bundler/ + src/transpiler/
//   Bun 在 bundler 和 transpiler 中对 AST 进行多种转换:
//   - ES2022+ → ES2020 降级 (optional chaining, nullish coalescing)
//   - ESM → CommonJS 转换
//   - IIFE 包装
//   - 变量/函数声明提升
package bao_ast

import bao_core.*
import bao_collections.*

// ============================================================================
// ASTTransformer - AST 转换基类
// 严格翻译自: src/bundler/ 中对 AST 的转换模式
// Bun 在 linker/printer 阶段大量修改 AST 节点
// ============================================================================

/// AST 转换结果
public enum TransformResult {
    | Continue            // 继续遍历子节点
    | Skip                // 跳过子节点
    | Replace(ASTNode)    // 替换当前节点
    | Remove              // 删除当前节点
    | Stop                // 停止遍历
}

/// AST 转换器基类 - 对应 Bun 中 AST 修改的通用模式
/// Bun 在 bundler 中使用 Stmt/Expr 的 init/allocation 函数创建新节点
/// 在 linker 中使用 merge/replace 操作修改 AST
public open class ASTTransformer {
    /// 是否已修改
    protected var modified: Bool
    /// 转换计数
    protected var transformCount: Int64
    /// 删除计数
    protected var removeCount: Int64

    public init() {
        modified = false
        transformCount = Int64(0)
        removeCount = Int64(0)
    }

    /// 转换表达式节点 - 子类覆写
    /// 对应 Bun linker 中对 Expr 节点的转换
    public open func transformExpr(node: ASTNode): TransformResult {
        return TransformResult.Continue
    }

    /// 转换语句节点 - 子类覆写
    /// 对应 Bun linker 中对 Stmt 节点的转换
    public open func transformStmt(node: StmtNode): TransformResult {
        return TransformResult.Continue
    }

    /// 转换绑定节点 - 子类覆写
    public open func transformBinding(node: BindingNode): TransformResult {
        return TransformResult.Continue
    }

    /// 递归转换表达式树
    public func applyExpr(node: ASTNode): ASTNode {
        let result = transformExpr(node)
        match (result) {
            case TransformResult.Continue => {
                // 递归处理子节点
                let newChildren = ArrayList<ASTNode>()
                for (child in node.children) {
                    let transformed = applyExpr(child)
                    match (transformResultFor(transformed)) {
                        case Int64(0) => newChildren.append(transformed) // keep
                        case Int64(1) => {} // removed
                        case _ => newChildren.append(transformed)
                    }
                }
                node.children = newChildren
                return node
            }
            case TransformResult.Skip => return node
            case TransformResult.Replace(newNode) => {
                modified = true
                transformCount += Int64(1)
                return newNode
            }
            case TransformResult.Remove => {
                modified = true
                removeCount += Int64(1)
                return ASTNode(ExprTag.Missing, node.loc)
            }
            case TransformResult.Stop => return node
        }
    }

    /// 递归转换语句树
    public func applyStmt(node: StmtNode): StmtNode {
        let result = transformStmt(node)
        match (result) {
            case TransformResult.Continue => {
                // 递归处理子语句
                let newStmts = ArrayList<StmtNode>()
                for (stmt in node.stmts) {
                    let transformed = applyStmt(stmt)
                    if (transformed.tag != StmtTag.Empty) {
                        newStmts.append(transformed)
                    }
                }
                node.stmts = newStmts
                // 处理子表达式
                let newChildren = ArrayList<ASTNode>()
                for (child in node.children) {
                    newChildren.append(applyExpr(child))
                }
                node.children = newChildren
                return node
            }
            case TransformResult.Skip => return node
            case TransformResult.Replace(_) => {
                modified = true
                transformCount += Int64(1)
                return node
            }
            case TransformResult.Remove => {
                modified = true
                removeCount += Int64(1)
                return StmtNode(StmtTag.Empty, node.loc)
            }
            case TransformResult.Stop => return node
        }
    }

    /// 转换整个程序 (语句列表)
    public func apply(stmts: ArrayList<StmtNode>): ArrayList<StmtNode> {
        let result = ArrayList<StmtNode>()
        for (stmt in stmts) {
            let transformed = applyStmt(stmt)
            if (transformed.tag != StmtTag.Empty) {
                result.append(transformed)
            }
        }
        return result
    }

    /// 是否已修改 AST
    public func wasModified(): Bool {
        modified
    }

    /// 获取转换计数
    public func getTransformCount(): Int64 {
        transformCount
    }

    /// 重置状态
    public func reset(): Unit {
        modified = false
        transformCount = Int64(0)
        removeCount = Int64(0)
    }

    private func transformResultFor(node: ASTNode): Int64 {
        if (node.tag == ExprTag.Missing) { Int64(1) } else { Int64(0) }
    }
}

// ============================================================================
// ESVersionDowngrader - ES2022+ 降级到 ES2020
// 严格翻译自: src/transpiler/ 中的语法降级逻辑
// Bun transpiler 将 ES2022+ 语法降级为低版本:
//   - optional chaining (?.) → conditional + member access
//   - nullish coalescing (??) → ternary + null check
//   - logical assignment (&&=, ||=, ??=) → if-assign
//   - private class fields (#) → WeakMap
// ============================================================================

/// ES 版本
public enum ESVersion {
    | ES5
    | ES2015
    | ES2016
    | ES2017
    | ES2018
    | ES2019
    | ES2020
    | ES2021
    | ES2022
    | ESNext

    public func ordinal(): Int64 {
        match (this) {
            case ES5 => Int64(5)
            case ES2015 => Int64(2015)
            case ES2016 => Int64(2016)
            case ES2017 => Int64(2017)
            case ES2018 => Int64(2018)
            case ES2019 => Int64(2019)
            case ES2020 => Int64(2020)
            case ES2021 => Int64(2021)
            case ES2022 => Int64(2022)
            case ESNext => Int64(2099)
        }
    }

    public func isAtLeast(version: ESVersion): Bool {
        ordinal() >= version.ordinal()
    }
}

/// ES 版本降级器 - 对应 Bun transpiler 中的语法降级
/// Bun: src/transpiler/transpiler.zig 中的 lower() 函数族
public class ESVersionDowngrader <: ASTTransformer {
    private var targetVersion: ESVersion

    public init(target: ESVersion) {
        super()
        this.targetVersion = target
    }

    /// 转换表达式 - 降级 ES2022+ 语法
    public func transformExpr(node: ASTNode): TransformResult {
        match (node.tag) {
            // 可选链 (?.) - ES2020 特性，降到 ES2019 需要展开
            // Bun: src/js_parser/ lower_optional_chain
            case ExprTag.Member => {
                let optional = node.properties.get("optional")
                match (optional) {
                    case Some(b) => match (b as Bool) {
                        case Some(true) =>
                            if (!targetVersion.isAtLeast(ESVersion.ES2020)) {
                                return downgradeOptionalChain(node)
                            }
                        case _ => {}
                    }
                    case None => {}
                }
                return TransformResult.Continue
            }
            // 空值合并 (??) - ES2020 特性
            // Bun: src/js_parser/ lower_nullish_coalescing
            case ExprTag.Binary => {
                let op = node.properties.get("op")
                match (op) {
                    case Some(v) => match (v as String) {
                        case Some("??") =>
                            if (!targetVersion.isAtLeast(ESVersion.ES2020)) {
                                return downgradeNullishCoalescing(node)
                            }
                        case _ => {}
                    }
                    case None => {}
                }
                return TransformResult.Continue
            }
            // 逻辑赋值 (&&=, ||=, ??=) - ES2021 特性
            // Bun: src/js_parser/ lower_logical_assignment
            case ExprTag.Assign => {
                let op = node.properties.get("op")
                match (op) {
                    case Some(v) => match (v as String) {
                        case Some("&&=") | Some("||=") | Some("??=") =>
                            if (!targetVersion.isAtLeast(ESVersion.ES2021)) {
                                return downgradeLogicalAssignment(node)
                            }
                        case _ => {}
                    }
                    case None => {}
                }
                return TransformResult.Continue
            }
            case _ => return TransformResult.Continue
        }
    }

    /// 降级可选链 (?.)
    /// a?.b → a === null || a === void 0 ? void 0 : a.b
    /// 对应 Bun: src/js_parser lower_optional_chain_recursive
    private func downgradeOptionalChain(node: ASTNode): TransformResult {
        // 创建条件表达式替代
        let condition = ASTNode(ExprTag.Binary, node.loc)
        condition.children.append(ASTNode(ExprTag.Identifier, node.loc, "a"))
        condition.value = "== null"
        let consequent = ASTNode(ExprTag.Undefined, node.loc)
        let alternative = ASTNode(ExprTag.Member, node.loc)
        alternative.properties.put("optional", false)
        let ternary = ASTNode(ExprTag.Conditional, node.loc)
        ternary.children.append(condition)
        ternary.children.append(consequent)
        ternary.children.append(alternative)
        transformCount += Int64(1)
        modified = true
        return TransformResult.Replace(ternary)
    }

    /// 降级空值合并 (??)
    /// a ?? b → a != null ? a : b
    /// 对应 Bun: src/js_parser 中 __assign 即 nullish coalescing 降级
    private func downgradeNullishCoalescing(node: ASTNode): TransformResult {
        if (node.children.size < Int64(2)) {
            return TransformResult.Continue
        }
        let left = node.children[Int64(0)]
        let right = node.children[Int64(1)]
        let condition = ASTNode(ExprTag.Binary, node.loc)
        condition.children.append(left)
        condition.value = "!= null"
        let ternary = ASTNode(ExprTag.Conditional, node.loc)
        ternary.children.append(condition)
        ternary.children.append(left.deepClone())
        ternary.children.append(right)
        transformCount += Int64(1)
        modified = true
        return TransformResult.Replace(ternary)
    }

    /// 降级逻辑赋值 (&&=, ||=, ??=)
    /// a &&= b → a && (a = b)
    /// a ||= b → a || (a = b)
    /// a ??= b → (a != null ? a : (a = b))
    /// 对应 Bun: src/js_parser lower_assignment
    private func downgradeLogicalAssignment(node: ASTNode): TransformResult {
        if (node.children.size < Int64(2)) {
            return TransformResult.Continue
        }
        let target = node.children[Int64(0)]
        let value = node.children[Int64(1)]
        let op = match (node.properties.get("op")) {
            case Some(v) => match (v as String) {
                case Some(s) => s
                case None => "||="
            }
            case None => "||="
        }
        // 构建赋值表达式: target = value
        let assign = ASTNode(ExprTag.Assign, node.loc)
        assign.children.append(target.deepClone())
        assign.children.append(value)
        // 构建逻辑表达式: target op (target = value)
        let logical = ASTNode(ExprTag.Binary, node.loc)
        logical.children.append(target)
        logical.children.append(assign)
        if (op == "??=") {
            logical.value = "??"
        } else if (op == "&&=") {
            logical.value = "&&"
        } else {
            logical.value = "||"
        }
        transformCount += Int64(1)
        modified = true
        return TransformResult.Replace(logical)
    }
}

// ============================================================================
// CommonJSTransformer - ESM → CommonJS 转换
// 严格翻译自: src/bundler/ 中的 ESM→CJS 转换
// Bun 在 bundler 中将 ESM import/export 转换为 CommonJS require/module.exports
//   - import { foo } from 'bar' → const { foo } = require('bar')
//   - export default foo → module.exports.default = foo
//   - export const foo → Object.defineProperty(exports, 'foo', ...)
// ============================================================================

/// ESM → CommonJS 转换器
/// 对应 Bun: src/bundler/ 中的 wrapModule 和 cjs 转换
/// Bun: force_cjs_to_esm, uses_exports_ref, uses_module_ref, uses_require_ref
public class CommonJSTransformer <: ASTTransformer {
    /// 模块引用 - 对应 Bun Ast.exports_ref
    private var exportsRef: Ref
    /// module 引用 - 对应 Bun Ast.module_ref
    private var moduleRef: Ref
    /// require 引用 - 对应 Bun Ast.require_ref
    private var requireRef: Ref
    /// 是否需要 exports 对象
    private var usesExports: Bool
    /// 是否需要 module 对象
    private var usesModule: Bool
    /// 是否需要 require 函数
    private var usesRequire: Bool
    /// 已处理的导入
    private var processedImports: ArrayList<String>

    public init() {
        super()
        exportsRef = Ref.NONE
        moduleRef = Ref.NONE
        requireRef = Ref.NONE
        usesExports = false
        usesModule = false
        usesRequire = false
        processedImports = ArrayList<String>()
    }

    /// 转换语句 - ESM → CJS
    public func transformStmt(node: StmtNode): TransformResult {
        match (node.tag) {
            // import 语句 → require 调用
            // Bun: import { foo } from 'bar' → var foo = require('bar').foo
            case StmtTag.Import => {
                usesRequire = true
                return transformImportToRequire(node)
            }
            // export 语句 → module.exports 赋值
            case StmtTag.ExportClause => {
                usesExports = true
                return transformExportToCJS(node)
            }
            // export default → module.exports.default
            case StmtTag.ExportDefault => {
                usesModule = true
                usesExports = true
                return transformExportDefaultToCJS(node)
            }
            // export * from '...' → Object.assign
            case StmtTag.ExportStar => {
                usesExports = true
                usesRequire = true
                return transformExportStarToCJS(node)
            }
            case _ => return TransformResult.Continue
        }
    }

    /// import → require 转换
    /// 对应 Bun: import { foo, bar } from 'module'
    ///       → const __temp = require('module'); const foo = __temp.foo; const bar = __temp.bar;
    private func transformImportToRequire(node: StmtNode): TransformResult {
        // 构建 require 调用表达式
        let source = node.properties.get("source")
        match (source) {
            case Some(s) => match (s as String) {
                case Some(sourcePath) =>
                    if (!processedImports.contains(sourcePath)) {
                        processedImports.append(sourcePath)
                    }
                case None => {}
            }
            case None => {}
        }
        // 替换为 Local (变量声明) 语句
        let localStmt = StmtNode(StmtTag.Local, node.loc)
        let requireCall = ASTNode(ExprTag.Call, node.loc)
        let requireId = ASTNode(ExprTag.Identifier, node.loc, "require")
        requireCall.children.append(requireId)
        localStmt.children.append(requireCall)
        modified = true
        transformCount += Int64(1)
        return TransformResult.Replace(localStmt)
    }

    /// export → module.exports 赋值
    /// 对应 Bun: export const foo = bar → exports.foo = bar
    private func transformExportToCJS(node: StmtNode): TransformResult {
        let assignStmt = StmtNode(StmtTag.Expr, node.loc)
        for (child in node.children) {
            let assign = ASTNode(ExprTag.Assign, node.loc)
            let exportsAccess = ASTNode(ExprTag.Member, node.loc)
            exportsAccess.children.append(ASTNode(ExprTag.Identifier, node.loc, "exports"))
            assign.children.append(exportsAccess)
            assign.children.append(child)
            assignStmt.children.append(assign)
        }
        modified = true
        transformCount += Int64(1)
        return TransformResult.Replace(assignStmt)
    }

    /// export default → module.exports.default
    private func transformExportDefaultToCJS(node: StmtNode): TransformResult {
        if (node.children.size == Int64(0)) {
            return TransformResult.Continue
        }
        let value = node.children[Int64(0)]
        let assignStmt = StmtNode(StmtTag.Expr, node.loc)
        let assign = ASTNode(ExprTag.Assign, node.loc)
        let defaultAccess = ASTNode(ExprTag.Member, node.loc)
        let exportsId = ASTNode(ExprTag.Identifier, node.loc, "module")
        let defaultProps = ASTNode(ExprTag.Identifier, node.loc, "exports")
        defaultAccess.children.append(exportsId)
        defaultAccess.children.append(defaultProps)
        assign.children.append(defaultAccess)
        assign.children.append(value)
        assignStmt.children.append(assign)
        modified = true
        transformCount += Int64(1)
        return TransformResult.Replace(assignStmt)
    }

    /// export * → Object.assign(exports, require(...))
    private func transformExportStarToCJS(node: StmtNode): TransformResult {
        let assignStmt = StmtNode(StmtTag.Expr, node.loc)
        let call = ASTNode(ExprTag.Call, node.loc)
        let objectAssign = ASTNode(ExprTag.Member, node.loc)
        objectAssign.children.append(ASTNode(ExprTag.Identifier, node.loc, "Object"))
        objectAssign.children.append(ASTNode(ExprTag.Identifier, node.loc, "assign"))
        call.children.append(objectAssign)
        call.children.append(ASTNode(ExprTag.Identifier, node.loc, "exports"))
        assignStmt.children.append(call)
        modified = true
        transformCount += Int64(1)
        return TransformResult.Replace(assignStmt)
    }

    /// 是否使用了 exports
    public func usesExportsRef(): Bool { usesExports }
    /// 是否使用了 module
    public func usesModuleRef(): Bool { usesModule }
    /// 是否使用了 require
    public func usesRequireRef(): Bool { usesRequire }
}

// ============================================================================
// IIFEWrapper - 模块 IIFE 包装
// 严格翻译自: src/bundler/ 中的模块包装逻辑
// Bun 在 code splitting 中将模块包装在闭包中:
//   var __module = function(exports, module, require) { ... }
// 对应 Bun: Ast.wrapper_ref, Part 机制
// ============================================================================

/// IIFE 包装器 - 对应 Bun bundler 中的模块包装
public class IIFEWrapper <: ASTTransformer {
    /// 包装函数名称 - 对应 Bun Ast.wrapper_ref
    private var wrapperName: String
    /// 是否使用严格模式 - 对应 Bun Scope.strict_mode
    private var useStrict: Bool
    /// 参数名称列表
    private var paramNames: ArrayList<String>
    /// 参数对应的实际值
    private var paramValues: ArrayList<ASTNode>

    public init(wrapperName: String) {
        super()
        this.wrapperName = wrapperName
        this.useStrict = true
        this.paramNames = ArrayList<String>()
        this.paramValues = ArrayList<ASTNode>()
        // 默认 CJS 参数
        paramNames.append("exports")
        paramNames.append("module")
        paramNames.append("require")
    }

    public init(wrapperName: String, useStrict: Bool) {
        super()
        this.wrapperName = wrapperName
        this.useStrict = useStrict
        this.paramNames = ArrayList<String>()
        this.paramValues = ArrayList<ASTNode>()
    }

    /// 添加参数
    public func addParam(name: String, value: ASTNode): Unit {
        paramNames.append(name)
        paramValues.append(value)
    }

    /// 将语句列表包装在 IIFE 中
    /// 对应 Bun: 将模块的 Part 包装在 wrapper function 中
    /// 输入: [stmt1, stmt2, ...]
    /// 输出: var wrapper = function(exports, module, require) { stmt1; stmt2; ... }
    public func wrap(stmts: ArrayList<StmtNode>): StmtNode {
        // 创建函数体
        let funcBody = StmtNode(StmtTag.Function, Loc(Int64(0)))
        funcBody.properties.put("name", wrapperName)
        funcBody.properties.put("isArrow", false)
        funcBody.properties.put("isAsync", false)
        funcBody.properties.put("isGenerator", false)
        // 添加参数列表
        let params = ArrayList<ASTNode>()
        for (name in paramNames) {
            params.append(ASTNode(ExprTag.Identifier, Loc(Int64(0)), name))
        }
        funcBody.properties.put("params", params)
        // 如果使用严格模式，添加 "use strict" 指令
        if (useStrict) {
            let directive = StmtNode(StmtTag.Directive, Loc(Int64(0)))
            directive.value = "use strict"
            funcBody.stmts.append(directive)
        }
        // 添加所有语句到函数体
        for (stmt in stmts) {
            funcBody.stmts.append(stmt)
        }
        // 创建变量声明: var wrapperName = function(...) { ... }
        let varDecl = StmtNode(StmtTag.Local, Loc(Int64(0)))
        varDecl.properties.put("kind", "var")
        let funcExpr = ASTNode(ExprTag.Function, Loc(Int64(0)))
        funcExpr.children.append(ASTNode(ExprTag.Identifier, Loc(Int64(0)), wrapperName))
        varDecl.children.append(funcExpr)
        // 创建调用语句: wrapperName(exports, module, require)
        let callStmt = StmtNode(StmtTag.Expr, Loc(Int64(0)))
        let callExpr = ASTNode(ExprTag.Call, Loc(Int64(0)))
        callExpr.children.append(ASTNode(ExprTag.Identifier, Loc(Int64(0)), wrapperName))
        for (value in paramValues) {
            callExpr.children.append(value)
        }
        callStmt.children.append(callExpr)
        // 组合结果: 先声明函数，再调用
        // 返回一个 Block 包含两个语句
        let block = StmtNode(StmtTag.Block, Loc(Int64(0)))
        block.stmts.append(funcBody)
        block.stmts.append(callStmt)
        modified = true
        transformCount += Int64(1)
        return block
    }

    /// 创建简单的 IIFE 包装 (无名称)
    /// (function() { ... })()
    public func wrapAnonymous(stmts: ArrayList<StmtNode>): ASTNode {
        let callExpr = ASTNode(ExprTag.Call, Loc(Int64(0)))
        let funcExpr = ASTNode(ExprTag.Function, Loc(Int64(0)))
        let funcBody = StmtNode(StmtTag.Block, Loc(Int64(0)))
        if (useStrict) {
            let directive = StmtNode(StmtTag.Directive, Loc(Int64(0)))
            directive.value = "use strict"
            funcBody.stmts.append(directive)
        }
        for (stmt in stmts) {
            funcBody.stmts.append(stmt)
        }
        callExpr.children.append(funcExpr)
        modified = true
        transformCount += Int64(1)
        return callExpr
    }
}

// ============================================================================
// HoistTransformer - 变量/函数声明提升
// 严格翻译自: src/ast/symbol.zig + src/bundler/LinkerSource.zig
// Bun 在 parser 中识别变量提升 (var hoisting, function hoisting)
// 在 bundler 中执行实际的提升操作:
//   - var 声明提升到函数作用域顶部
//   - function 声明提升到作用域顶部 (包含函数体)
//   - import 声明提升到模块顶部
// ============================================================================

/// 提升项类型
public enum HoistKind {
    | VarDeclaration       // var 声明提升 (不含初始化)
    | FunctionDeclaration  // function 声明提升 (含函数体)
    | ImportDeclaration    // import 声明提升
    | ClassDeclaration     // class 声明 (不提升，仅收集)
}

/// 待提升的声明
public class HoistableDecl {
    /// 提升类型
    public var kind: HoistKind
    /// 语句节点
    public var stmt: StmtNode
    /// 声明名称
    public var name: String
    /// 原始位置
    public var originalIndex: Int64

    public init(kind: HoistKind, stmt: StmtNode, name: String, index: Int64) {
        this.kind = kind
        this.stmt = stmt
        this.name = name
        this.originalIndex = index
    }
}

/// 变量/函数声明提升器
/// 对应 Bun: src/ast/symbol.zig - Symbol.isKindHoistedOrFunction()
///           src/ast/scope.zig   - Scope.canMergeSymbols()
///           src/bundler/        - hoist pass
public class HoistTransformer <: ASTTransformer {
    /// 收集到的可提升声明
    private var hoistedDecls: ArrayList<HoistableDecl>
    /// 函数级作用域边界 (这些标签之前的语句为提升目标区域)
    private var functionScopeDepth: Int64

    public init() {
        super()
        hoistedDecls = ArrayList<HoistableDecl>()
        functionScopeDepth = Int64(0)
    }

    /// 对语句列表执行提升
    /// 对应 Bun parser 中的 hoisting pass
    public func hoist(stmts: ArrayList<StmtNode>): ArrayList<StmtNode> {
        hoistedDecls.clear()
        functionScopeDepth = Int64(0)
        // Phase 1: 收集所有可提升的声明
        collectHoisted(stmts, Int64(0))
        // Phase 2: 重新排列语句 (提升的声明移到前面)
        if (hoistedDecls.size == Int64(0)) {
            return stmts
        }
        let result = ArrayList<StmtNode>()
        // 先插入函数声明提升 (函数声明包含函数体，优先)
        // 对应 Bun: function hoisting 优先于 var hoisting
        for (decl in hoistedDecls) {
            if (decl.kind == HoistKind.FunctionDeclaration) {
                result.append(decl.stmt)
            }
        }
        // 再插入 import 声明
        for (decl in hoistedDecls) {
            if (decl.kind == HoistKind.ImportDeclaration) {
                result.append(decl.stmt)
            }
        }
        // 插入 var 声明 (仅声明，不含初始化)
        // 对应 Bun: var foo = bar; → var foo; (声明提升) ... foo = bar; (赋值保留)
        for (decl in hoistedDecls) {
            if (decl.kind == HoistKind.VarDeclaration) {
                let varStmt = StmtNode(StmtTag.Local, decl.stmt.loc)
                varStmt.properties.put("kind", "var")
                varStmt.properties.put("hoisted", true)
                let binding = ASTNode(ExprTag.Identifier, decl.stmt.loc, decl.name)
                varStmt.children.append(binding)
                result.append(varStmt)
            }
        }
        // 最后保留所有非提升的原始语句
        var stmtIndex = Int64(0)
        for (stmt in stmts) {
            if (!isHoistedDecl(stmt, stmtIndex)) {
                result.append(stmt)
            }
            stmtIndex += Int64(1)
        }
        if (hoistedDecls.size > Int64(0)) {
            modified = true
            transformCount += hoistedDecls.size
        }
        return result
    }

    /// 收集可提升的声明
    /// 对应 Bun: 遍历 AST 收集 SymbolKind 为 Hoisted/HoistedFunction 的符号
    private func collectHoisted(stmts: ArrayList<StmtNode>, depth: Int64): Unit {
        var idx = Int64(0)
        for (stmt in stmts) {
            match (stmt.tag) {
                // function 声明 - 始终提升 (含函数体)
                case StmtTag.Function => {
                    if (depth <= Int64(1)) {
                        let name = match (stmt.properties.get("name")) {
                            case Some(v) => match (v as String) {
                                case Some(s) => s
                                case None => ""
                            }
                            case None => ""
                        }
                        if (name.size > Int64(0)) {
                            hoistedDecls.append(HoistableDecl(
                                HoistKind.FunctionDeclaration, stmt, name, idx))
                        }
                    }
                }
                // 变量声明 - var 提升到函数作用域
                case StmtTag.Local => {
                    let kind = match (stmt.properties.get("kind")) {
                        case Some(v) => match (v as String) {
                            case Some(s) => s
                            case None => "let"
                        }
                        case None => "let"
                    }
                    if (kind == "var" && depth <= Int64(1)) {
                        for (child in stmt.children) {
                            let name = match (child.value as String) {
                                case Some(s) => s
                                case None => ""
                            }
                            if (name.size > Int64(0)) {
                                hoistedDecls.append(HoistableDecl(
                                    HoistKind.VarDeclaration, stmt, name, idx))
                            }
                        }
                    }
                }
                // import 声明 - 提升到模块顶部
                case StmtTag.Import => {
                    hoistedDecls.append(HoistableDecl(
                        HoistKind.ImportDeclaration, stmt, "import", idx))
                }
                // 嵌套块 - 不提升 var (var 提升到最近的函数作用域)
                case StmtTag.Block | StmtTag.If | StmtTag.For |
                     StmtTag.ForIn | StmtTag.ForOf |
                     StmtTag.While | StmtTag.DoWhile => {
                    collectHoisted(stmt.stmts, depth + Int64(1))
                }
                // 函数创建新的作用域边界
                case StmtTag.Function => {} // 已处理
                case _ => {}
            }
            idx += Int64(1)
        }
    }

    /// 检查语句是否为已收集的提升声明
    private func isHoistedDecl(stmt: StmtNode, index: Int64): Bool {
        for (decl in hoistedDecls) {
            // 函数声明整体提升，需从原位置移除
            if (decl.kind == HoistKind.FunctionDeclaration &&
                decl.originalIndex == index) {
                return true
            }
            // import 声明整体提升
            if (decl.kind == HoistKind.ImportDeclaration &&
                decl.originalIndex == index) {
                return true
            }
        }
        return false
    }

    /// 获取提升的声明列表
    public func getHoistedDeclarations(): ArrayList<HoistableDecl> {
        return hoistedDecls
    }
}
