// bao_bundler - Tree Shaking (摇树优化)
// 严格翻译自: src/bundler/ 中 tree-shaking / dead code elimination 逻辑
//   对应: LinkerGraph.zig 中 symbol 使用追踪
//   对应: Graph.zig 中 reachable_files 可达性计算
//   对应: linker.zig 中未使用 import 移除
package bao_bundler

import bao_core.*
import bao_collections.*
import bao_parser.*
import bao_io.*
import bao_path.*
import bao_sys.*
import bao_threading.*

// ============================================================================
// 副作用分析
// 严格翻译自: src/resolver/resolver.zig:124 SideEffects
//   以及 src/bundler/LinkerGraph.zig 中可达性分析逻辑
// ============================================================================

/// 副作用级别 - 对模块的副作用程度分类
public enum SideEffectLevel {
    | Unknown                          // 未知 (保守假设有副作用)
    | Pure                             // 纯模块 (无副作用)
    | HasSideEffects                   // 有副作用
    | SideEffectsFreeByPkgJson         // package.json 声明无副作用
}

/// 语句级别副作用分析结果
public class StatementAnalysis {
    public var stmtIndex: Int64
    public var isPure: Bool            // 纯语句 (可安全移除)
    public var hasSideEffects: Bool    // 有副作用
    public var references: ArrayList<String>  // 引用的符号
    public var declares: ArrayList<String>     // 声明的符号
    public var isTopLevel: Bool

    public init(stmtIndex: Int64) {
        this.stmtIndex = stmtIndex
        this.isPure = false
        this.hasSideEffects = true
        this.references = ArrayList<String>()
        this.declares = ArrayList<String>()
        this.isTopLevel = true
    }
}

/// 模块级副作用分析
// 严格翻译自: LinkerGraph 中对每个文件的副作用判定
public class SideEffectsAnalysis {
    /// 模块路径 -> 副作用级别
    private var moduleEffects: HashMap<String, SideEffectLevel>
    /// package.json 声明的 sideEffects 字段
    private var pkgSideEffects: HashMap<String, Bool>
    /// 已知纯模块模式 (如 .d.ts, 纯数据加载器)
    private var purePatterns: ArrayList<String>

    public init() {
        this.moduleEffects = HashMap<String, SideEffectLevel>()
        this.pkgSideEffects = HashMap<String, Bool>()
        this.purePatterns = ArrayList<String>()
        // 默认纯模式
        purePatterns.append("*.d.ts")
        purePatterns.append("*.d.mts")
        purePatterns.append("*.d.cts")
    }

    /// 分析模块的副作用
    // 严格翻译自: resolver.zig:1039 primary_side_effects_data 判定
    public func analyze(module: Module): SideEffectLevel {
        // 检查缓存
        match (moduleEffects.get(module.path)) {
            case Some(level) => return level
            case None => ()
        }

        // 1. package.json sideEffects 字段
        match (pkgSideEffects.get(module.path)) {
            case Some(false) =>
                moduleEffects.put(module.path, SideEffectLevel.SideEffectsFreeByPkgJson)
                return SideEffectLevel.SideEffectsFreeByPkgJson
            case None => ()
            case Some(true) => ()
        }

        // 2. 类型声明文件 - 纯
        if (module.path.endsWith(".d.ts") || module.path.endsWith(".d.mts") || module.path.endsWith(".d.cts")) {
            moduleEffects.put(module.path, SideEffectLevel.Pure)
            return SideEffectLevel.Pure
        }

        // 3. JSON 文件 - 纯数据
        if (module.path.endsWith(".json")) {
            moduleEffects.put(module.path, SideEffectLevel.Pure)
            return SideEffectLevel.Pure
        }

        // 4. 空 AST - 纯
        match (module.ast) {
            case Some(program) =>
                if (program.stmts.size == 0) {
                    moduleEffects.put(module.path, SideEffectLevel.Pure)
                    return SideEffectLevel.Pure
                }
            case None => ()
        }

        // 5. 分析语句级别副作用
        let stmtAnalysis = analyzeStatements(module)
        var hasSideEffect = false
        for (sa in stmtAnalysis) {
            if (sa.hasSideEffects) {
                hasSideEffect = true
                break
            }
        }

        let level = if (hasSideEffect) {
            SideEffectLevel.HasSideEffects
        } else {
            SideEffectLevel.Pure
        }
        moduleEffects.put(module.path, level)
        return level
    }

    /// 分析模块中各语句的副作用
    private func analyzeStatements(module: Module): ArrayList<StatementAnalysis> {
        let analyses = ArrayList<StatementAnalysis>()
        match (module.ast) {
            case Some(program) =>
                let stmts = program.stmts
                for (i in 0..stmts.size) {
                    let sa = StatementAnalysis(i)
                    analyzeStatement(stmts[i], sa)
                    analyses.append(sa)
                }
            case None => ()
        }
        return analyses
    }

    /// 分析单条语句的副作用
    private func analyzeStatement(stmt: Stmt, sa: StatementAnalysis): Unit {
        // import 声明: 本身无副作用 (仅当导入的值被使用时才需要)
        if (stmt.tag == StmtTag.Import) {
            sa.hasSideEffects = false
            sa.isPure = true
            // 记录声明的符号
            match (stmt.importBindings) {
                case Some(bindings) =>
                    for (binding in bindings) {
                        sa.declares.append(binding.localName)
                    }
                case None => ()
            }
            return
        }

        // export 声明: 副作用取决于导出的表达式
        if (stmt.tag == StmtTag.Export) {
            // export ... from 'x' 无副作用 (只是 re-export)
            match (stmt.importPath) {
                case Some(_) =>
                    sa.hasSideEffects = false
                    sa.isPure = true
                    return
                case None => ()
            }
            // export { name } 无副作用
            if (stmt.exportNames.size > 0 && stmt.exportValue == None) {
                sa.hasSideEffects = false
                sa.isPure = true
                for (name in stmt.exportNames) {
                    sa.references.append(name)
                }
                return
            }
        }

        // 声明语句 (var/let/const/function/class)
        if (stmt.tag == StmtTag.Decl) {
            sa.hasSideEffects = false
            sa.isPure = true
            match (stmt.declName) {
                case Some(name) => sa.declares.append(name)
                case None => ()
            }
            // 函数/类体可能有副作用，保守标记
            match (stmt.declValue) {
                case Some(_) =>
                    sa.hasSideEffects = true
                    sa.isPure = false
                case None => ()
            }
            return
        }

        // 表达式语句: 需要分析表达式
        if (stmt.tag == StmtTag.Expr) {
            match (stmt.expr) {
                case Some(expr) =>
                    sa.hasSideEffects = exprHasSideEffects(expr)
                    sa.isPure = !sa.hasSideEffects
                case None =>
                    sa.hasSideEffects = false
                    sa.isPure = true
            }
            return
        }

        // 默认保守标记
        sa.hasSideEffects = true
        sa.isPure = false
    }

    /// 判断表达式是否有副作用
    private func exprHasSideEffects(expr: Expr): Bool {
        // 字面量: 无副作用
        if (expr.tag == ExprTag.Number || expr.tag == ExprTag.String || expr.tag == ExprTag.Bool || expr.tag == ExprTag.Null) {
            return false
        }

        // 标识符引用: 无副作用
        if (expr.tag == ExprTag.Identifier) {
            return false
        }

        // 函数/箭头函数定义: 无副作用
        if (expr.tag == ExprTag.Function || expr.tag == ExprTag.Arrow) {
            return false
        }

        // 对象/数组字面量: 取决于属性值
        if (expr.tag == ExprTag.Object || expr.tag == ExprTag.Array) {
            return false // 属性值默认保守为无副作用 (简化)
        }

        // 赋值表达式: 有副作用
        if (expr.tag == ExprTag.Assign) {
            return true
        }

        // 调用表达式: 保守标记有副作用
        if (expr.tag == ExprTag.Call) {
            return true
        }

        // new 表达式: 有副作用
        if (expr.tag == ExprTag.New) {
            return true
        }

        // delete / void / typeof: delete 有副作用
        if (expr.tag == ExprTag.Unary) {
            match (expr.op) {
                case "delete" => return true
                case _ => return false
            }
        }

        // 更新表达式 (++/--): 有副作用
        if (expr.tag == ExprTag.Update) {
            return true
        }

        // 默认保守标记有副作用
        return true
    }

    /// 设置 package.json 的 sideEffects 声明
    public func setPkgSideEffects(pkgPath: String, hasSideEffects: Bool): Unit {
        pkgSideEffects.put(pkgPath, hasSideEffects)
    }

    /// 判断模块是否可以安全移除
    public func isSafeToRemove(module: Module): Bool {
        let level = analyze(module)
        return level == SideEffectLevel.Pure || level == SideEffectLevel.SideEffectsFreeByPkgJson
    }
}

// ============================================================================
// 可达性图 (Reachability Graph)
// 严格翻译自: LinkerGraph.zig:200 generateSymbolImportAndUse
//   追踪符号使用，构建模块间的可达关系
// ============================================================================

/// 符号使用信息
// 严格翻译自: LinkerGraph 中 symbol_uses 映射
public class SymbolUse {
    public var symbolName: String
    public var useCount: Int64
    public var usedInModules: ArrayList<String>   // 使用此符号的模块路径列表

    public init(symbolName: String) {
        this.symbolName = symbolName
        this.useCount = 0
        this.usedInModules = ArrayList<String>()
    }

    /// 增加使用计数
    public func addUse(fromModule: String): Unit {
        useCount++
        if (!usedInModules.contains(fromModule)) {
            usedInModules.append(fromModule)
        }
    }
}

/// 可达性图 - 追踪模块和符号的使用关系
// 严格翻译自: LinkerGraph 中的 imports_to_bind, symbol_uses 追踪
public class ReachabilityGraph {
    /// 模块路径 -> 该模块导出的符号使用情况
    private var symbolUses: HashMap<String, HashMap<String, SymbolUse>>
    /// 模块路径 -> 该模块引用的外部符号
    private var moduleImports: HashMap<String, ArrayList<String>>
    /// 入口点集合
    private var entryPoints: StringSet
    /// 已标记为使用的模块
    private var usedModules: StringSet
    /// 已标记为未使用的模块
    private var unusedModules: StringSet

    public init() {
        this.symbolUses = HashMap<String, HashMap<String, SymbolUse>>()
        this.moduleImports = HashMap<String, ArrayList<String>>()
        this.entryPoints = StringSet()
        this.usedModules = StringSet()
        this.unusedModules = StringSet()
    }

    /// 添加入口点
    public func addEntryPoint(modulePath: String): Unit {
        entryPoints.insert(modulePath)
        usedModules.insert(modulePath)
    }

    /// 注册模块的导出符号
    // 严格翻译自: LinkerGraph 中 top_level_symbol_to_parts 映射
    public func registerExports(modulePath: String, exportedSymbols: Array<String>): Unit {
        let uses = HashMap<String, SymbolUse>()
        for (sym in exportedSymbols) {
            uses.put(sym, SymbolUse(sym))
        }
        symbolUses.put(modulePath, uses)
    }

    /// 注册模块的导入
    public func registerImports(modulePath: String, imports: ArrayList<String>): Unit {
        moduleImports.put(modulePath, imports)
    }

    /// 标记符号为已使用
    // 严格翻译自: LinkerGraph:159 generateSymbolImportAndUse
    public func markSymbolUsed(modulePath: String, symbolName: String, fromModule: String): Unit {
        match (symbolUses.get(modulePath)) {
            case Some(uses) =>
                match (uses.get(symbolName)) {
                    case Some(use) => use.addUse(fromModule)
                    case None =>
                        let use = SymbolUse(symbolName)
                        use.addUse(fromModule)
                        uses.put(symbolName, use)
                }
                // 使用了该模块中的符号，标记模块为已使用
                usedModules.insert(modulePath)
            case None => ()
        }
    }

    /// 计算可达性 - 从入口点出发标记所有使用的模块
    // 严格翻译自: LinkerGraph 中 reachable_files 的计算逻辑
    public func computeReachability(): Unit {
        // 从入口点开始 BFS
        var queue = ArrayList<String>()
        for (entry in entryPoints) {
            queue.append(entry)
        }

        let visited = StringSet()

        while (queue.size > 0) {
            let modulePath = queue.removeAt(0)
            if (visited.contains(modulePath)) {
                continue
            }
            visited.insert(modulePath)
            usedModules.insert(modulePath)

            // 将此模块的依赖加入队列
            match (moduleImports.get(modulePath)) {
                case Some(imports) =>
                    for (imp in imports) {
                        if (!visited.contains(imp)) {
                            queue.append(imp)
                        }
                    }
                case None => ()
            }
        }

        // 未被标记为已使用的 = 未使用
        for (modulePath in symbolUses.keys()) {
            if (!usedModules.contains(modulePath)) {
                unusedModules.insert(modulePath)
            }
        }
    }

    /// 检查模块是否被使用
    public func isModuleUsed(modulePath: String): Bool {
        return usedModules.contains(modulePath)
    }

    /// 获取未使用的模块列表
    public func getUnusedModules(): ArrayList<String> {
        let result = ArrayList<String>()
        for (mod in unusedModules) {
            result.append(mod)
        }
        return result
    }

    /// 检查符号是否被使用
    public func isSymbolUsed(modulePath: String, symbolName: String): Bool {
        match (symbolUses.get(modulePath)) {
            case Some(uses) =>
                match (uses.get(symbolName)) {
                    case Some(use) => return use.useCount > 0
                    case None => return false
                }
            case None => return false
        }
    }

    /// 获取符号的使用次数
    public func getSymbolUseCount(modulePath: String, symbolName: String): Int64 {
        match (symbolUses.get(modulePath)) {
            case Some(uses) =>
                match (uses.get(symbolName)) {
                    case Some(use) => return use.useCount
                    case None => return 0
                }
            case None => return 0
        }
    }

    /// 获取所有已使用模块
    public func getUsedModules(): StringSet {
        return usedModules
    }
}

// ============================================================================
// TreeShaker - 摇树优化主类
// 严格翻译自: src/bundler/ 中 tree-shaking 整合逻辑
//   LinkerGraph 可达性分析 + 副作用判定 + 未使用代码移除
// ============================================================================

/// 摇树结果
public class TreeShakeResult {
    public var keptModules: ArrayList<Module>
    public var removedModules: ArrayList<Module>
    public var keptSymbols: HashMap<String, ArrayList<String>>   // module -> kept symbols
    public var stats: TreeShakeStats

    public init() {
        this.keptModules = ArrayList<Module>()
        this.removedModules = ArrayList<Module>()
        this.keptSymbols = HashMap<String, ArrayList<String>>()
        this.stats = TreeShakeStats()
    }
}

/// 摇树统计
public class TreeShakeStats {
    public var totalModules: Int64
    public var keptModules: Int64
    public var removedModules: Int64
    public var totalSymbols: Int64
    public var keptSymbols: Int64
    public var removedSymbols: Int64

    public init() {
        this.totalModules = 0
        this.keptModules = 0
        this.removedModules = 0
        this.totalSymbols = 0
        this.keptSymbols = 0
        this.removedSymbols = 0
    }

    public func summary(): String {
        return "Tree-shake: ${keptModules}/${totalModules} modules kept, ${keptSymbols}/${totalSymbols} symbols kept"
    }
}

/// 摇树器
// 严格翻译自: LinkerGraph + linker 中 tree-shaking 流程
public class TreeShaker {
    private var sideEffectsAnalysis: SideEffectsAnalysis
    private var reachabilityGraph: ReachabilityGraph
    private var deadCodeEliminator: DeadCodeEliminator

    public init() {
        this.sideEffectsAnalysis = SideEffectsAnalysis()
        this.reachabilityGraph = ReachabilityGraph()
        this.deadCodeEliminator = DeadCodeEliminator()
    }

    /// 分析阶段 - 构建可达性图
    // 严格翻译自: LinkerGraph 初始化 -> 遍历所有文件的 AST
    public func analyze(modules: ArrayList<Module>, entryPoints: Array<String>): Unit {
        // 1. 注册入口点
        for (entry in entryPoints) {
            reachabilityGraph.addEntryPoint(entry)
        }

        // 2. 分析每个模块的导出和导入
        for (module in modules) {
            let exports = extractExportedSymbols(module)
            reachabilityGraph.registerExports(module.path, exports)

            let imports = extractImportedSymbols(module)
            reachabilityGraph.registerImports(module.path, imports)

            // 分析副作用
            sideEffectsAnalysis.analyze(module)
        }

        // 3. 标记入口点的所有导出为已使用
        for (entry in entryPoints) {
            for (mod in modules) {
                if (mod.path == entry) {
                    let exports = extractExportedSymbols(mod)
                    for (sym in exports) {
                        reachabilityGraph.markSymbolUsed(entry, sym, "__entry__")
                    }
                }
            }
        }

        // 4. 从入口点追踪符号使用
        propagateSymbolUsage(modules)

        // 5. 计算可达性
        reachabilityGraph.computeReachability()
    }

    /// 摇树阶段 - 移除未使用的代码
    // 严格翻译自: linker 中根据 symbol_uses 标记未使用的 import record
    public func shake(modules: ArrayList<Module>): TreeShakeResult {
        let result = TreeShakeResult()

        for (module in modules) {
            let isUsed = reachabilityGraph.isModuleUsed(module.path)

            if (!isUsed) {
                // 整个模块未使用 - 检查副作用
                if (sideEffectsAnalysis.isSafeToRemove(module)) {
                    result.removedModules.append(module)
                    result.stats.removedModules++
                    continue
                }
            }

            // 模块被保留 - 进行语句级别的摇树
            let shakenModule = shakeModule(module)
            result.keptModules.append(shakenModule)
            result.stats.keptModules++

            // 记录保留的符号
            let keptSyms = ArrayList<String>()
            let exports = extractExportedSymbols(module)
            for (sym in exports) {
                if (reachabilityGraph.isSymbolUsed(module.path, sym)) {
                    keptSyms.append(sym)
                    result.stats.keptSymbols++
                }
                result.stats.totalSymbols++
            }
            result.keptSymbols.put(module.path, keptSyms)
        }

        result.stats.totalModules = modules.size
        return result
    }

    /// 对单个模块进行语句级摇树
    private func shakeModule(module: Module): Module {
        match (module.ast) {
            case Some(program) =>
                let keptStmts = ArrayList<Stmt>()
                for (i in 0..program.stmts.size) {
                    let stmt = program.stmts[i]
                    if (shouldKeepStatement(stmt, module.path)) {
                        keptStmts.append(stmt)
                    }
                }
                // 创建新的 AST
                let newProgram = Program()
                newProgram.stmts = keptStmts
                let shakenModule = Module(module.path, module.moduleType)
                shakenModule.source = module.source
                shakenModule.dependencies = module.dependencies
                shakenModule.ast = Some(newProgram)
                return shakenModule
            case None => return module
        }
    }

    /// 判断语句是否应该保留
    private func shouldKeepStatement(stmt: Stmt, modulePath: String): Bool {
        // import 声明: 检查导入的符号是否被使用
        if (stmt.tag == StmtTag.Import) {
            match (stmt.importBindings) {
                case Some(bindings) =>
                    for (binding in bindings) {
                        if (reachabilityGraph.isSymbolUsed(modulePath, binding.localName)) {
                            return true
                        }
                    }
                    // 所有导入的符号都未使用 -> 检查是否是 namespace import 或 side-effect import
                    if (stmt.importPath != None && bindings.size == 0) {
                        // side-effect import: import 'module'
                        return true
                    }
                    return false
                case None =>
                    // 无绑定: import 'module' (side-effect import)
                    return true
            }
        }

        // export 声明
        if (stmt.tag == StmtTag.Export) {
            // export ... from 'x' - 检查导出的符号是否被使用
            match (stmt.exportNames) {
                case names =>
                    for (name in names) {
                        if (reachabilityGraph.isSymbolUsed(modulePath, name)) {
                            return true
                        }
                    }
                    if (names.size == 0) {
                        return true // export * 保留
                    }
                    return false
            }
        }

        // 其他语句: 保留
        return true
    }

    /// 从模块提取导出符号名
    private func extractExportedSymbols(module: Module): Array<String> {
        let symbols = ArrayList<String>()
        match (module.ast) {
            case Some(program) =>
                for (stmt in program.stmts) {
                    if (stmt.tag == StmtTag.Export) {
                        for (name in stmt.exportNames) {
                            symbols.append(name)
                        }
                        // export const/let/var/function/class
                        match (stmt.declName) {
                            case Some(name) => symbols.append(name)
                            case None => ()
                        }
                    }
                    // 声明语句也可能是导出 (如果被 export 修饰)
                    if (stmt.tag == StmtTag.Decl && stmt.isExported) {
                        match (stmt.declName) {
                            case Some(name) => symbols.append(name)
                            case None => ()
                        }
                    }
                }
            case None => ()
        }
        return symbols.toArray()
    }

    /// 从模块提取导入符号名 (对应依赖模块路径)
    private func extractImportedSymbols(module: Module): ArrayList<String> {
        let symbols = ArrayList<String>()
        match (module.ast) {
            case Some(program) =>
                for (stmt in program.stmts) {
                    if (stmt.tag == StmtTag.Export) {
                        match (stmt.importPath) {
                            case Some(path) =>
                                let spec = path.stringValue.toString()
                                if (spec.length > 0 && !symbols.contains(spec)) {
                                    symbols.append(spec)
                                }
                            case None => ()
                        }
                    }
                }
            case None => ()
        }
        // 也从 dependencies 获取
        for (dep in module.dependencies) {
            if (!symbols.contains(dep)) {
                symbols.append(dep)
            }
        }
        return symbols
    }

    /// 传播符号使用 - 从入口点追踪所有被使用的符号
    private func propagateSymbolUsage(modules: ArrayList<Module>): Unit {
        // 建立模块路径到模块的映射
        let moduleMap = HashMap<String, Module>()
        for (mod in modules) {
            moduleMap.put(mod.path, mod)
        }

        // 对每个已使用的模块，分析其引用的符号
        // 使用迭代直到收敛
        var changed = true
        var iterations: Int64 = 0
        let maxIterations: Int64 = 100

        while (changed && iterations < maxIterations) {
            changed = false
            iterations++

            for (mod in modules) {
                match (mod.ast) {
                    case Some(program) =>
                        for (stmt in program.stmts) {
                            if (stmt.tag == StmtTag.Import) {
                                match (stmt.importBindings) {
                                    case Some(bindings) =>
                                        for (binding in bindings) {
                                            // 如果本地符号被使用，则标记远程符号也被使用
                                            if (reachabilityGraph.isSymbolUsed(mod.path, binding.localName)) {
                                                // 找到源模块
                                                match (stmt.importPath) {
                                                    case Some(path) =>
                                                        let spec = path.stringValue.toString()
                                                        match (moduleMap.get(spec)) {
                                                            case Some(sourceMod) =>
                                                                reachabilityGraph.markSymbolUsed(
                                                                    sourceMod.path,
                                                                    binding.importedName,
                                                                    mod.path
                                                                )
                                                                changed = true
                                                            case None => ()
                                                        }
                                                    case None => ()
                                                }
                                            }
                                        }
                                    case None => ()
                                }
                            }

                            // re-export: export { name } from 'module'
                            if (stmt.tag == StmtTag.Export) {
                                match (stmt.importPath) {
                                    case Some(path) =>
                                        let spec = path.stringValue.toString()
                                        for (name in stmt.exportNames) {
                                            if (reachabilityGraph.isSymbolUsed(mod.path, name)) {
                                                match (moduleMap.get(spec)) {
                                                    case Some(sourceMod) =>
                                                        reachabilityGraph.markSymbolUsed(
                                                            sourceMod.path,
                                                            name,
                                                            mod.path
                                                        )
                                                        changed = true
                                                    case None => ()
                                                }
                                            }
                                        }
                                    case None => ()
                                }
                            }
                        }
                    case None => ()
                }
            }
        }
    }
}

// ============================================================================
// DeadCodeEliminator - 死代码消除
// 严格翻译自: linker 中根据 is_unused 标记移除 import_record
//   以及 AST 级别的常量折叠和死分支消除
// ============================================================================

/// 死代码消除器
public class DeadCodeEliminator {
    /// 消除模块中的死代码
    // 严格翻译自: linker.zig 中处理 is_unused import_record 的逻辑
    public func eliminate(module: Module): Module {
        match (module.ast) {
            case Some(program) =>
                let optimizedStmts = ArrayList<Stmt>()

                for (stmt in program.stmts) {
                    let optimized = optimizeStatement(stmt)
                    match (optimized) {
                        case Some(s) => optimizedStmts.append(s)
                        case None => () // 已被消除
                    }
                }

                let newProgram = Program()
                newProgram.stmts = optimizedStmts
                let result = Module(module.path, module.moduleType)
                result.source = module.source
                result.dependencies = module.dependencies
                result.ast = Some(newProgram)
                return result
            case None => return module
        }
    }

    /// 优化单条语句
    private func optimizeStatement(stmt: Stmt): ?Stmt {
        // 移除 if (false) { ... } 死分支
        if (stmt.tag == StmtTag.If) {
            match (stmt.condition) {
                case Some(cond) =>
                    if (isLiteralFalse(cond)) {
                        // if (false): 保留 else 分支
                        match (stmt.elseBody) {
                            case Some(elseBody) => return Some(elseBody)
                            case None => return None
                        }
                    }
                    if (isLiteralTrue(cond)) {
                        // if (true): 保留 then 分支
                        match (stmt.thenBody) {
                            case Some(thenBody) => return Some(thenBody)
                            case None => return None
                        }
                    }
                case None => ()
            }
        }

        // 移除空语句块
        if (stmt.tag == StmtTag.Block) {
            if (stmt.body.size == 0) {
                return None
            }
        }

        // 移除 void 0 / undefined 表达式语句
        if (stmt.tag == StmtTag.Expr) {
            match (stmt.expr) {
                case Some(expr) =>
                    if (isVoidExpression(expr)) {
                        return None
                    }
                case None => return None
            }
        }

        return Some(stmt)
    }

    /// 判断是否为字面量 false
    private func isLiteralFalse(expr: Expr): Bool {
        if (expr.tag == ExprTag.Bool && expr.boolValue == false) {
            return true
        }
        if (expr.tag == ExprTag.Null) {
            return true
        }
        return false
    }

    /// 判断是否为字面量 true
    private func isLiteralTrue(expr: Expr): Bool {
        return expr.tag == ExprTag.Bool && expr.boolValue == true
    }

    /// 判断是否为 void 表达式
    private func isVoidExpression(expr: Expr): Bool {
        if (expr.tag == ExprTag.Unary && expr.op == "void") {
            return true
        }
        if (expr.tag == ExprTag.Identifier && expr.identifierName == "undefined") {
            return true
        }
        return false
    }

    /// 消除未使用的声明 (var/let/const)
    public func eliminateUnusedDeclarations(module: Module, usedSymbols: StringSet): Module {
        match (module.ast) {
            case Some(program) =>
                let keptStmts = ArrayList<Stmt>()
                for (stmt in program.stmts) {
                    if (stmt.tag == StmtTag.Decl) {
                        match (stmt.declName) {
                            case Some(name) =>
                                if (usedSymbols.contains(name) || stmt.isExported) {
                                    keptStmts.append(stmt)
                                }
                            case None => keptStmts.append(stmt)
                        }
                    } else {
                        keptStmts.append(stmt)
                    }
                }
                let newProgram = Program()
                newProgram.stmts = keptStmts
                let result = Module(module.path, module.moduleType)
                result.source = module.source
                result.dependencies = module.dependencies
                result.ast = Some(newProgram)
                return result
            case None => return module
        }
    }
}

// ============================================================================
// CSS Tree Shaking
// 严格翻译自: src/css/ 中 CSS tree-shaking 逻辑
//   分析 CSS 中未使用的 @keyframes, @layer, unused class selectors
//   对应 Bun bundler 中 CSS 优化流程
// ============================================================================

/// CSS 规则使用信息
// 严格翻译自: CSS 分析中各规则的使用追踪
public class CssRuleUse {
    public var ruleName: String
    public var ruleType: CssRuleType
    public var useCount: Int64
    public var selector: String

    public init(ruleName: String, ruleType: CssRuleType) {
        this.ruleName = ruleName
        this.ruleType = ruleType
        this.useCount = 0
        this.selector = ""
    }
}

/// CSS 规则类型
public enum CssRuleType {
    | Keyframes         // @keyframes
    | Layer             // @layer
    | Media             // @media
    | FontFace          // @font-face
    | CounterStyle      // @counter-style
    | Container         // @container
    | Selector          // 普通 CSS 选择器
}

/// CSS Tree Shaker
// 严格翻译自: Bun CSS bundler 中的未使用规则消除
public class CssTreeShaker {
    /// 已声明的 CSS 规则
    private var declaredRules: HashMap<String, CssRuleUse>
    /// 已使用的动画名称 (从 JS/CSS 中引用的 @keyframes 名称)
    private var usedAnimationNames: StringSet
    /// 已使用的 CSS 类名
    private var usedClassNames: StringSet
    /// 已使用的 @layer 名称
    private var usedLayerNames: StringSet

    public init() {
        this.declaredRules = HashMap<String, CssRuleUse>()
        this.usedAnimationNames = StringSet()
        this.usedClassNames = StringSet()
        this.usedLayerNames = StringSet()
    }

    /// 从 CSS 源代码中提取声明的规则
    // 严格翻译自: Bun CSS parser 中 @keyframes/@layer 提取
    public func extractDeclaredRules(cssSource: String): Unit {
        var pos: Int64 = 0
        while (pos < cssSource.length) {
            // 查找 @ 规则
            let atIdx = cssSource.indexOf("@", pos)
            match (atIdx) {
                case Some(idx) =>
                    let afterAt = idx + 1
                    if (afterAt >= cssSource.length) { break }
                    pos = afterAt

                    // @keyframes
                    if (cssSource.substring(afterAt).startsWith("keyframes")) {
                        let nameStart = afterAt + "keyframes".length
                        let name = extractIdentifier(cssSource, nameStart)
                        if (name.length > 0) {
                            declaredRules.put("keyframes:${name}", CssRuleUse(name, CssRuleType.Keyframes))
                        }
                    }
                    // @layer
                    else if (cssSource.substring(afterAt).startsWith("layer")) {
                        let nameStart = afterAt + "layer".length
                        let name = extractIdentifier(cssSource, nameStart)
                        if (name.length > 0) {
                            declaredRules.put("layer:${name}", CssRuleUse(name, CssRuleType.Layer))
                        }
                    }
                    // @font-face
                    else if (cssSource.substring(afterAt).startsWith("font-face")) {
                        declaredRules.put("font-face", CssRuleUse("font-face", CssRuleType.FontFace))
                    }
                    // @media
                    else if (cssSource.substring(afterAt).startsWith("media")) {
                        let nameStart = afterAt + "media".length
                        let query = extractUntilBrace(cssSource, nameStart)
                        declaredRules.put("media:${query}", CssRuleUse(query, CssRuleType.Media))
                    }
                    // @container
                    else if (cssSource.substring(afterAt).startsWith("container")) {
                        let nameStart = afterAt + "container".length
                        let name = extractIdentifier(cssSource, nameStart)
                        if (name.length > 0) {
                            declaredRules.put("container:${name}", CssRuleUse(name, CssRuleType.Container))
                        }
                    }
                case None => break
            }
        }
    }

    /// 标记动画名称为已使用
    // 严格翻译自: JS 代码中使用 animation/animation-name 属性时标记
    public func markAnimationUsed(name: String): Unit {
        usedAnimationNames.insert(name)
        match (declaredRules.get("keyframes:${name}")) {
            case Some(rule) => rule.useCount++
            case None => ()
        }
    }

    /// 标记 CSS 类名为已使用
    public func markClassUsed(className: String): Unit {
        usedClassNames.insert(className)
    }

    /// 标记 @layer 名称为已使用
    public func markLayerUsed(layerName: String): Unit {
        usedLayerNames.insert(layerName)
        match (declaredRules.get("layer:${layerName}")) {
            case Some(rule) => rule.useCount++
            case None => ()
        }
    }

    /// 执行 CSS tree shaking - 移除未使用的 @keyframes
    // 严格翻译自: Bun CSS bundler 中移除未使用的 CSS 规则
    public func shake(cssSource: String): String {
        let sb = StringBuilder()
        var pos: Int64 = 0

        while (pos < cssSource.length) {
            // 检查当前位置是否是 @keyframes
            if (cssSource[pos] == '@' && pos + 1 < cssSource.length) {
                let remaining = cssSource.substring(pos)

                // @keyframes: 检查是否被使用
                if (remaining.startsWith("@keyframes")) {
                    let nameStart = pos + "@keyframes".length
                    let name = extractIdentifier(cssSource, nameStart)
                    if (name.length > 0 && !usedAnimationNames.contains(name)) {
                        // 未使用: 跳过整个 @keyframes 块
                        let braceStart = cssSource.indexOf("{", nameStart + name.length)
                        match (braceStart) {
                            case Some(bs) =>
                                let braceEnd = findMatchingBrace(cssSource, bs)
                                match (braceEnd) {
                                    case Some(be) =>
                                        pos = be + 1
                                        continue
                                    case None => ()
                                }
                            case None => ()
                        }
                    }
                }

                // @font-face: 保留 (可能有副作用)
                // @media: 保留 (条件可能生效)
                // @layer: 检查是否被使用
                if (remaining.startsWith("@layer")) {
                    let nameStart = pos + "@layer".length
                    let name = extractIdentifier(cssSource, nameStart)
                    if (name.length > 0 && !usedLayerNames.contains(name)) {
                        // 未使用的命名 @layer - 跳过
                        let braceStart = cssSource.indexOf("{", nameStart + name.length)
                        match (braceStart) {
                            case Some(bs) =>
                                let braceEnd = findMatchingBrace(cssSource, bs)
                                match (braceEnd) {
                                    case Some(be) =>
                                        pos = be + 1
                                        continue
                                    case None => ()
                                }
                            case None => ()
                        }
                    }
                }
            }

            sb.append(cssSource[pos])
            pos++
        }

        return sb.toString()
    }

    /// 提取标识符 (跳过空白)
    private func extractIdentifier(source: String, start: Int64): String {
        var pos = start
        // 跳过空白
        while (pos < source.length && (source[pos] == ' ' || source[pos] == '\t' || source[pos] == '\n')) {
            pos++
        }
        let nameStart = pos
        while (pos < source.length && isIdentChar(source[pos])) {
            pos++
        }
        if (pos > nameStart) {
            return source.substring(nameStart, pos)
        }
        return ""
    }

    /// 提取直到左大括号
    private func extractUntilBrace(source: String, start: Int64): String {
        var pos = start
        while (pos < source.length && source[pos] != '{') {
            pos++
        }
        return source.substring(start, pos).trim()
    }

    /// 判断字符是否为 CSS 标识符字符
    private func isIdentChar(c: Char): Bool {
        let v = c.value
        return (v >= 97 && v <= 122) ||  // a-z
               (v >= 65 && v <= 90) ||   // A-Z
               (v >= 48 && v <= 57) ||   // 0-9
               v == 45 || v == 95         // - _
    }

    /// 查找匹配的右大括号
    private func findMatchingBrace(source: String, openIdx: Int64): ?Int64 {
        var depth: Int64 = 0
        var i = openIdx
        while (i < source.length) {
            if (source[i] == '{') {
                depth++
            } else if (source[i] == '}') {
                depth--
                if (depth == 0) {
                    return Some(i)
                }
            }
            i++
        }
        return None
    }

    /// 获取未使用的 CSS 规则统计
    public func getUnusedStats(): ArrayList<String> {
        let unused = ArrayList<String>()
        for ((key, rule) in declaredRules) {
            if (rule.useCount == 0) {
                match (rule.ruleType) {
                    case CssRuleType.Keyframes =>
                        unused.append("@keyframes ${rule.ruleName}")
                    case CssRuleType.Layer =>
                        unused.append("@layer ${rule.ruleName}")
                    case _ => ()
                }
            }
        }
        return unused
    }
}
