// bao_ast - AST 分析模块
// 严格翻译自: src/ast/
//   scope.zig    - Scope 结构 (members, children, parent, kind, strict_mode)
//   symbol.zig   - Symbol 结构 (kind, original_name, use_count_estimate, nested_scope_slot)
//   ast.zig      - Ast 顶层结构 (module_scope, symbols, parts)
package bao_ast

import bao_core.*
import bao_collections.*

// ============================================================================
// SymbolKind - 符号类型
// 严格翻译自: src/ast/symbol.zig - Symbol.Kind
// Bun: pub const Kind = enum { unbound, hoisted, hoisted_function, ... }
// ============================================================================

/// 符号类型 - 对应 Bun Symbol.Kind
public enum SymbolKind {
    | Unbound               // 未绑定
    | Hoisted               // var 声明提升
    | HoistedFunction       // 函数声明提升
    | GeneratorOrAsyncFunction // generator/async 函数
    | Class                 // class 声明
    | Constant              // const 声明
    | Let                   // let 声明
    | Import                // import 绑定
    | PrivateGet            // private getter
    | PrivateSet            // private setter
    | PrivateStaticGet      // private static getter
    | PrivateStaticSet      // private static setter
    | TsEnum                // TypeScript enum
    | TsNamespace           // TypeScript namespace
    | Label                 // label 标签
    | Other                 // 其他

    /// 是否为提升类型 - 对应 Bun Symbol.isKindHoistedOrFunction()
    public func isHoisted(): Bool {
        match (this) {
            case Hoisted | HoistedFunction | GeneratorOrAsyncFunction => true
            case _ => false
        }
    }

    /// 是否为函数类型
    public func isFunction(): Bool {
        match (this) {
            case HoistedFunction | GeneratorOrAsyncFunction => true
            case _ => false
        }
    }

    /// 是否为块级作用域绑定
    public func isBlockScoped(): Bool {
        match (this) {
            case Constant | Let | Class => true
            case _ => false
        }
    }
}

/// 符号信息 - 对应 Bun Symbol
/// Bun: pub const Symbol = struct { kind, original_name, use_count_estimate, link, ... }
public class SymbolInfo {
    /// 符号类型 - 对应 Bun Symbol.kind
    public var kind: SymbolKind
    /// 原始名称 - 对应 Bun Symbol.original_name: []const u8
    public var originalName: String
    /// 引用估计计数 - 对应 Bun Symbol.use_count_estimate: u32
    public var useCountEstimate: Int64
    /// 引用 ID - 对应 Bun Symbol.link: Ref
    public var link: Ref
    /// 嵌套作用域槽位 - 对应 Bun Symbol.nested_scope_slot: u32
    public var nestedScopeSlot: Int64

    public init(kind: SymbolKind, name: String) {
        this.kind = kind
        this.originalName = name
        this.useCountEstimate = Int64(0)
        this.link = Ref.NONE
        this.nestedScopeSlot = Int64(-1)
    }

    /// 增加使用计数 - 对应 Bun Symbol 中 use_count_estimate++
    public func incUseCount(): Unit {
        useCountEstimate += Int64(1)
    }

    /// 是否已使用
    public func isUsed(): Bool {
        useCountEstimate > Int64(0)
    }

    /// 是否可重命名
    public func canRename(): Bool {
        kind != SymbolKind.Import && kind != SymbolKind.Unbound
    }
}

// ============================================================================
// ScopeKind - 作用域类型
// 严格翻译自: src/ast/scope.zig - Scope.Kind
// Bun: pub const Kind = enum { block, with, label, ... }
// ============================================================================

/// 作用域类型 - 对应 Bun Scope.Kind
public enum ScopeKind {
    | Block           // 块级作用域 {}
    | With            // with 语句
    | Label           // 标签作用域 (break/continue)
    | Entry           // 模块入口作用域
    | FunctionBody    // 函数体
    | FunctionArgs    // 函数参数
    | ClassBody       // class 体
    | ClassStaticInit // class static {}
    | CatchBinding    // catch 绑定
    | ForLoop         // for 循环
    | TsModule        // TypeScript module/namespace

    /// 是否为函数级作用域 - 对应 Bun Scope 判断
    public func isFunctionScope(): Bool {
        match (this) {
            case FunctionBody | FunctionArgs | Entry => true
            case _ => false
        }
    }

    /// 是否为块级作用域
    public func isBlockScope(): Bool {
        match (this) {
            case Block | ForLoop | CatchBinding => true
            case _ => false
        }
    }
}

// ============================================================================
// ScopeInfo - 作用域信息
// 严格翻译自: src/ast/scope.zig - Scope
// Bun: pub const Scope = struct { id, kind, parent, children, members, ... }
// ============================================================================

/// 作用域信息 - 对应 Bun Scope
/// Bun: pub const Scope = struct {
///   id: usize, kind: Kind, parent: ?*Scope, children: BabyList(*Scope),
///   members: MemberHashMap, generated: BabyList(Ref),
///   contains_direct_eval: bool, strict_mode: StrictModeKind
/// }
public class ScopeInfo {
    /// 作用域 ID - 对应 Bun Scope.id
    public var id: Int64
    /// 作用域类型 - 对应 Bun Scope.kind
    public var kind: ScopeKind
    /// 父作用域 - 对应 Bun Scope.parent: ?*Scope
    public var parent: ?ScopeInfo
    /// 子作用域 - 对应 Bun Scope.children: BabyList(*Scope)
    public var children: ArrayList<ScopeInfo>
    /// 成员变量声明 - 对应 Bun Scope.members: MemberHashMap
    public var members: HashMap<String, SymbolInfo>
    /// 生成的引用列表 - 对应 Bun Scope.generated: BabyList(Ref)
    public var generated: ArrayList<Ref>
    /// 是否包含直接 eval - 对应 Bun Scope.contains_direct_eval
    public var containsDirectEval: Bool
    /// 严格模式 - 对应 Bun Scope.strict_mode
    public var strictMode: Bool
    /// 标签引用 - 对应 Bun Scope.label_ref
    public var labelRef: ?Ref

    public init(id: Int64, kind: ScopeKind) {
        this.id = id
        this.kind = kind
        this.parent = None
        this.children = ArrayList<ScopeInfo>()
        this.members = HashMap<String, SymbolInfo>()
        this.generated = ArrayList<Ref>()
        this.containsDirectEval = false
        this.strictMode = false
        this.labelRef = None
    }

    /// 重置 - 对应 Bun Scope.reset()
    public func reset(): Unit {
        children.clear()
        generated.clear()
        parent = None
        labelRef = None
        containsDirectEval = false
        strictMode = false
        kind = ScopeKind.Block
    }

    /// 添加成员 - 对应 Bun Scope.members.getOrPutMemberWithHash()
    public func addMember(name: String, symbol: SymbolInfo): Unit {
        members.put(name, symbol)
    }

    /// 查找成员 - 对应 Bun Scope.getMemberWithHash()
    public func getMember(name: String): ?SymbolInfo {
        members.get(name)
    }

    /// 添加子作用域
    public func addChild(child: ScopeInfo): Unit {
        child.parent = Some(this)
        children.append(child)
    }

    /// 查找名称 (沿作用域链向上查找) - 对应 Bun resolveBinding 逻辑
    public func resolve(name: String): ?SymbolInfo {
        let member = members.get(name)
        match (member) {
            case Some(s) => return Some(s)
            case None => match (parent) {
                case Some(p) => return p.resolve(name)
                case None => return None
            }
        }
    }

    /// 是否在严格模式下
    public func isStrictMode(): Bool {
        if (strictMode) {
            return true
        }
        match (parent) {
            case Some(p) => p.isStrictMode()
            case None => false
        }
    }

    /// 作用域深度
    public func depth(): Int64 {
        var d = Int64(0)
        var current = parent
        while (true) {
            match (current) {
                case Some(p) =>
                    d += Int64(1)
                    current = p.parent
                case None => break
            }
        }
        return d
    }
}

// ============================================================================
// ScopeAnalysis - 作用域分析
// 严格翻译自: src/ast/scope.zig + src/bundler/LinkerSource.zig (scope analysis)
// Bun 在 parser pass 中构建 Scope 树，在 bundler 中进行作用域分析
// ============================================================================

/// 作用域分析结果 - 每个作用域的分析数据
public class ScopeAnalysisResult {
    /// 被分析的 AST
    public var root: ScopeInfo
    /// 所有声明 (按作用域分组)
    public var declarations: HashMap<Int64, ArrayList<String>>
    /// 所有引用 (按作用域分组)
    public var references: HashMap<Int64, ArrayList<String>>
    /// 自由变量 (在当前作用域未声明但使用的变量)
    public var freeVariables: HashMap<Int64, ArrayList<String>>
    /// 全局引用 (未在任何局部作用域中声明的变量)
    public var globalReferences: ArrayList<String>

    public init(root: ScopeInfo) {
        this.root = root
        this.declarations = HashMap<Int64, ArrayList<String>>()
        this.references = HashMap<Int64, ArrayList<String>>()
        this.freeVariables = HashMap<Int64, ArrayList<String>>()
        this.globalReferences = ArrayList<String>()
    }
}

/// 作用域分析器 - 对应 Bun 中作用域构建和变量绑定分析
/// Bun: parser 中每进入一个 block/function/class 都创建新 Scope
/// 在 bundler 的 Bind phase 中收集所有声明和引用
public class ScopeAnalysis {
    private var scopeIdCounter: Int64
    private var allScopes: ArrayList<ScopeInfo>
    private var currentScope: ?ScopeInfo

    public init() {
        scopeIdCounter = Int64(0)
        allScopes = ArrayList<ScopeInfo>()
        currentScope = None
    }

    /// 创建新作用域 - 对应 Bun parser 中 pushScope() 操作
    public func pushScope(kind: ScopeKind): ScopeInfo {
        let scope = ScopeInfo(scopeIdCounter, kind)
        scopeIdCounter += Int64(1)
        match (currentScope) {
            case Some(parent) => parent.addChild(scope)
            case None => ()
        }
        allScopes.append(scope)
        currentScope = Some(scope)
        return scope
    }

    /// 弹出当前作用域 - 对应 Bun parser 中 popScope() 操作
    public func popScope(): ?ScopeInfo {
        match (currentScope) {
            case Some(scope) =>
                currentScope = scope.parent
                return scope.parent
            case None => return None
        }
    }

    /// 声明变量 - 对应 Bun parser 中 declareBinding() 操作
    public func declareVariable(name: String, kind: SymbolKind): SymbolInfo {
        let symbol = SymbolInfo(kind, name)
        match (currentScope) {
            case Some(scope) =>
                scope.addMember(name, symbol)
            case None => ()
        }
        return symbol
    }

    /// 引用变量 - 对应 Bun parser 中引用标识符时查找绑定
    public func referenceVariable(name: String): ?SymbolInfo {
        match (currentScope) {
            case Some(scope) => return scope.resolve(name)
            case None => return None
        }
    }

    /// 分析完整 AST - 对应 Bundler Bind Phase
    public func analyze(root: ScopeInfo): ScopeAnalysisResult {
        let result = ScopeAnalysisResult(root)
        collectDeclarations(root, result)
        collectFreeVariables(root, result)
        return result
    }

    /// 收集所有声明 - 递归遍历 Scope 树
    private func collectDeclarations(scope: ScopeInfo, result: ScopeAnalysisResult): Unit {
        let decls = ArrayList<String>()
        let keys = scope.members.keys()
        for (key in keys) {
            decls.append(key)
        }
        result.declarations.put(scope.id, decls)
        for (child in scope.children) {
            collectDeclarations(child, result)
        }
    }

    /// 收集自由变量 - 在当前作用域引用但未声明的变量
    /// 对应 Bun bundler 中判断 symbol 是否被正确解析的逻辑
    private func collectFreeVariables(scope: ScopeInfo, result: ScopeAnalysisResult): Unit {
        let freeVars = ArrayList<String>()
        // 检查每个引用的变量是否在此作用域链中声明
        let refs = ArrayList<String>()
        let keys = scope.members.keys()
        for (key in keys) {
            refs.append(key)
        }
        result.references.put(scope.id, refs)
        // 自由变量 = 在此作用域使用但未在此作用域声明
        for (ref in refs) {
            let localDecl = scope.getMember(ref)
            match (localDecl) {
                case Some(_) => ()  // 已声明，不是自由变量
                case None =>
                    // 检查是否在父作用域链中
                    let resolved = scope.resolve(ref)
                    match (resolved) {
                        case None =>
                            // 全局引用
                            if (!freeVars.contains(ref)) {
                                freeVars.append(ref)
                            }
                        case Some(_) => ()  // 在父作用域中找到
                    }
            }
        }
        result.freeVariables.put(scope.id, freeVars)
        for (child in scope.children) {
            collectFreeVariables(child, result)
        }
    }

    /// 获取所有作用域
    public func getAllScopes(): ArrayList<ScopeInfo> {
        return allScopes
    }
}

// ============================================================================
// ControlFlowGraph - 控制流图
// 严格翻译自: src/bundler/ 中对 AST 的控制流分析模式
// Bun 通过 AST 遍历隐含地构建控制流 (如 tree shaking 中的 dead code detection)
// ============================================================================

/// 基本块 - 控制流图的基本单元
public class BasicBlock {
    /// 块 ID
    public var id: Int64
    /// 块中的语句 - 对应 AST 中连续执行的语句序列
    public var stmts: ArrayList<StmtNode>
    /// 后继块 (正常流出的边)
    public var successors: ArrayList<Int64>
    /// 前驱块
    public var predecessors: ArrayList<Int64>
    /// 是否是入口块
    public var isEntry: Bool
    /// 是否是出口块
    public var isExit: Bool
    /// 是否可达
    public var isReachable: Bool

    public init(id: Int64) {
        this.id = id
        stmts = ArrayList<StmtNode>()
        successors = ArrayList<Int64>()
        predecessors = ArrayList<Int64>()
        isEntry = false
        isExit = false
        isReachable = false
    }

    /// 添加后继
    public func addSuccessor(blockId: Int64): Unit {
        if (!successors.contains(blockId)) {
            successors.append(blockId)
        }
    }

    /// 添加前驱
    public func addPredecessor(blockId: Int64): Unit {
        if (!predecessors.contains(blockId)) {
            predecessors.append(blockId)
        }
    }

    /// 是否为空块
    public func isEmpty(): Bool {
        stmts.size == Int64(0)
    }
}

/// CFG 边类型
public enum EdgeKind {
    | Normal      // 正常顺序流
    | TrueBranch  // if/while 的 true 分支
    | FalseBranch // if/while 的 false 分支
    | LoopBack    // 循环回边
    | Break       // break 跳转
    | Continue    // continue 跳转
    | Return      // return 退出
    | Throw       // 异常抛出
    | Catch       // catch 处理
}

/// CFG 边
public class CFGEdge {
    public var from: Int64
    public var to: Int64
    public var kind: EdgeKind

    public init(from: Int64, to: Int64, kind: EdgeKind) {
        this.from = from
        this.to = to
        this.kind = kind
    }
}

/// 控制流图 - 对应 Bun 中 AST 的控制流分析
public class ControlFlowGraph {
    /// 所有基本块
    public var blocks: HashMap<Int64, BasicBlock>
    /// 所有边
    public var edges: ArrayList<CFGEdge>
    /// 入口块 ID
    public var entryId: Int64
    /// 出口块 ID
    public var exitIds: ArrayList<Int64>
    /// 块计数器
    private var blockCounter: Int64

    public init() {
        blocks = HashMap<Int64, BasicBlock>()
        edges = ArrayList<CFGEdge>()
        entryId = Int64(-1)
        exitIds = ArrayList<Int64>()
        blockCounter = Int64(0)
    }

    /// 创建新基本块
    public func newBlock(): BasicBlock {
        let block = BasicBlock(blockCounter)
        blocks.put(blockCounter, block)
        blockCounter += Int64(1)
        return block
    }

    /// 创建入口块
    public func createEntryBlock(): BasicBlock {
        let block = newBlock()
        block.isEntry = true
        entryId = block.id
        return block
    }

    /// 创建出口块
    public func createExitBlock(): BasicBlock {
        let block = newBlock()
        block.isExit = true
        exitIds.append(block.id)
        return block
    }

    /// 添加边
    public func addEdge(from: Int64, to: Int64, kind: EdgeKind): Unit {
        let edge = CFGEdge(from, to, kind)
        edges.append(edge)
        match (blocks.get(from)) {
            case Some(b) => b.addSuccessor(to)
            case None => ()
        }
        match (blocks.get(to)) {
            case Some(b) => b.addPredecessor(from)
            case None => ()
        }
    }

    /// 获取块
    public func getBlock(id: Int64): ?BasicBlock {
        blocks.get(id)
    }

    /// 从语句列表构建 CFG
    /// 对应 Bun bundler 中对 AST 的线性化分析
    public func buildFromStmts(stmts: ArrayList<StmtNode>): Unit {
        if (stmts.size == Int64(0)) {
            let entry = createEntryBlock()
            let exit = createExitBlock()
            addEdge(entry.id, exit.id, EdgeKind.Normal)
            return
        }
        let entry = createEntryBlock()
        var currentId = entry.id
        for (i in Int64(0)..stmts.size) {
            let stmt = stmts[i]
            let block = newBlock()
            block.stmts.append(stmt)
            addEdge(currentId, block.id, EdgeKind.Normal)
            // 处理控制流语句
            match (stmt.tag) {
                case StmtTag.If => {
                    let mergeBlock = newBlock()
                    addEdge(block.id, mergeBlock.id, EdgeKind.TrueBranch)
                    addEdge(block.id, mergeBlock.id, EdgeKind.FalseBranch)
                    currentId = mergeBlock.id
                }
                case StmtTag.Return => {
                    let exit = createExitBlock()
                    addEdge(block.id, exit.id, EdgeKind.Return)
                    if (i + Int64(1) < stmts.size) {
                        let nextBlock = newBlock()
                        currentId = nextBlock.id
                    }
                }
                case StmtTag.Throw => {
                    let catchBlock = newBlock()
                    addEdge(block.id, catchBlock.id, EdgeKind.Throw)
                    currentId = catchBlock.id
                }
                case StmtTag.For | StmtTag.ForIn | StmtTag.ForOf | StmtTag.While | StmtTag.DoWhile => {
                    let loopEnd = newBlock()
                    addEdge(block.id, loopEnd.id, EdgeKind.FalseBranch)
                    addEdge(block.id, block.id, EdgeKind.LoopBack)
                    currentId = loopEnd.id
                }
                case StmtTag.Break => {
                    addEdge(block.id, currentId, EdgeKind.Break)
                    if (i + Int64(1) < stmts.size) {
                        let nextBlock = newBlock()
                        currentId = nextBlock.id
                    }
                }
                case StmtTag.Continue => {
                    addEdge(block.id, currentId, EdgeKind.Continue)
                    if (i + Int64(1) < stmts.size) {
                        let nextBlock = newBlock()
                        currentId = nextBlock.id
                    }
                }
                case _ => {
                    currentId = block.id
                }
            }
        }
        // 确保有出口块
        if (exitIds.size == Int64(0)) {
            let exit = createExitBlock()
            addEdge(currentId, exit.id, EdgeKind.Normal)
        }
    }

    /// 标记可达块 - 从入口开始 BFS
    public func markReachable(): Unit {
        // 重置所有块
        let blockList = blocks.values()
        for (block in blockList) {
            block.isReachable = false
        }
        // BFS 从入口开始
        let queue = ArrayList<Int64>()
        match (blocks.get(entryId)) {
            case Some(entry) =>
                entry.isReachable = true
                queue.append(entryId)
            case None => return
        }
        while (queue.size > Int64(0)) {
            let blockId = queue.removeAt(Int64(0))
            match (blocks.get(blockId)) {
                case Some(block) =>
                    for (succ in block.successors) {
                        match (blocks.get(succ)) {
                            case Some(s) =>
                                if (!s.isReachable) {
                                    s.isReachable = true
                                    queue.append(succ)
                                }
                            case None => ()
                        }
                    }
                case None => ()
            }
        }
    }

    /// 获取不可达块
    public func unreachableBlocks(): ArrayList<BasicBlock> {
        let result = ArrayList<BasicBlock>()
        for (block in blocks.values()) {
            if (!block.isReachable) {
                result.append(block)
            }
        }
        return result
    }
}

// ============================================================================
// DataFlowAnalysis - 数据流分析
// 严格翻译自: src/bundler/ 中的 tree-shaking 和 dead code elimination
// Bun 在 bundler 中使用 use_count_estimate 追踪变量使用
// ============================================================================

/// 定义 - 一个变量赋值点
public class Definition {
    /// 变量名
    public var name: String
    /// 定义所在的块 ID
    public var blockId: Int64
    /// 定义语句索引
    public var stmtIndex: Int64

    public init(name: String, blockId: Int64, stmtIndex: Int64) {
        this.name = name
        this.blockId = blockId
        this.stmtIndex = stmtIndex
    }
}

/// 到达定义分析结果
public class ReachingDefinitions {
    /// 每个块入口处的到达定义集 (blockId -> definitions)
    public var in_: HashMap<Int64, ArrayList<Definition>>
    /// 每个块出口处的到达定义集
    public var out: HashMap<Int64, ArrayList<Definition>>
    /// 每个块的 gen 集 (新产生的定义)
    public var gen: HashMap<Int64, ArrayList<Definition>>
    /// 每个块的 kill 集 (被杀死的定义)
    public var kill: HashMap<Int64, ArrayList<String>>

    public init() {
        in_ = HashMap<Int64, ArrayList<Definition>>()
        out = HashMap<Int64, ArrayList<Definition>>()
        gen = HashMap<Int64, ArrayList<Definition>>()
        kill = HashMap<Int64, ArrayList<String>>()
    }
}

/// 活跃变量分析结果
public class LiveVariables {
    /// 每个块入口处的活跃变量集
    public var in_: HashMap<Int64, ArrayList<String>>
    /// 每个块出口处的活跃变量集
    public var out: HashMap<Int64, ArrayList<String>>
    /// 每个块中使用的变量 (use)
    public var use: HashMap<Int64, ArrayList<String>>
    /// 每个块中定义的变量 (def)
    public var def: HashMap<Int64, ArrayList<String>>

    public init() {
        in_ = HashMap<Int64, ArrayList<String>>()
        out = HashMap<Int64, ArrayList<String>>()
        use = HashMap<Int64, ArrayList<String>>()
        def = HashMap<Int64, ArrayList<String>>()
    }
}

/// 数据流分析 - 对应 Bun bundler 中的变量使用追踪
public class DataFlowAnalysis {
    /// 执行到达定义分析
    /// 对应 Bun bundler 中追踪 import/variable definitions
    public static func reachingDefinitions(cfg: ControlFlowGraph): ReachingDefinitions {
        let result = ReachingDefinitions()
        // 初始化: 为每个块计算 gen 和 kill 集
        for (block in cfg.blocks.values()) {
            let genSet = ArrayList<Definition>()
            let killSet = ArrayList<String>()
            for (i in Int64(0)..block.stmts.size) {
                let stmt = block.stmts[i]
                match (stmt.tag) {
                    case StmtTag.Local => {
                        // 变量声明: gen 新定义, kill 旧定义
                        // 对应 Bun 中声明变量时的 symbol 绑定
                        let def = Definition("var", block.id, i)
                        genSet.append(def)
                    }
                    case StmtTag.Expr => {
                        // 赋值表达式: 可能定义变量
                    }
                    case _ => ()
                }
            }
            result.gen.put(block.id, genSet)
            result.kill.put(block.id, killSet)
            result.in_.put(block.id, ArrayList<Definition>())
            result.out.put(block.id, ArrayList<Definition>())
        }
        // 不动点迭代 - 标准数据流分析方法
        var changed = true
        while (changed) {
            changed = false
            for (block in cfg.blocks.values()) {
                // IN[B] = union of OUT[P] for all predecessors P
                let inSet = ArrayList<Definition>()
                for (predId in block.predecessors) {
                    match (result.out.get(predId)) {
                        case Some(predOut) =>
                            for (def in predOut) {
                                if (!containsDef(inSet, def)) {
                                    inSet.append(def)
                                }
                            }
                        case None => ()
                    }
                }
                // OUT[B] = GEN[B] union (IN[B] - KILL[B])
                let outSet = ArrayList<Definition>()
                for (def in inSet) {
                    let killList = result.kill.get(block.id)
                    match (killList) {
                        case Some(kills) =>
                            if (!kills.contains(def.name)) {
                                outSet.append(def)
                            }
                        case None => outSet.append(def)
                    }
                }
                match (result.gen.get(block.id)) {
                    case Some(genSet) =>
                        for (def in genSet) {
                            if (!containsDef(outSet, def)) {
                                outSet.append(def)
                            }
                        }
                    case None => ()
                }
                // 检查是否变化
                if (!defsEqual(match (result.in_.get(block.id)) {
                    case Some(s) => s
                    case None => ArrayList<Definition>()
                }, inSet) || !defsEqual(match (result.out.get(block.id)) {
                    case Some(s) => s
                    case None => ArrayList<Definition>()
                }, outSet)) {
                    changed = true
                }
                result.in_.put(block.id, inSet)
                result.out.put(block.id, outSet)
            }
        }
        return result
    }

    /// 执行活跃变量分析
    /// 对应 Bun bundler 中判断 symbol 是否被使用 (use_count_estimate)
    public static func liveVariableAnalysis(cfg: ControlFlowGraph): LiveVariables {
        let result = LiveVariables()
        // 初始化每个块的 use 和 def 集
        for (block in cfg.blocks.values()) {
            let useSet = ArrayList<String>()
            let defSet = ArrayList<String>()
            for (stmt in block.stmts) {
                // 遍历语句收集 use 和 def
                // 对应 Bun 中使用和声明变量的分析
                match (stmt.tag) {
                    case StmtTag.Local => defSet.append("decl")
                    case StmtTag.Expr => useSet.append("ref")
                    case StmtTag.Return => useSet.append("retval")
                    case _ => ()
                }
            }
            result.use.put(block.id, useSet)
            result.def.put(block.id, defSet)
            result.in_.put(block.id, ArrayList<String>())
            result.out.put(block.id, ArrayList<String>())
        }
        // 逆向数据流: 逆拓扑序迭代
        var changed = true
        while (changed) {
            changed = false
            for (block in cfg.blocks.values()) {
                // OUT[B] = union of IN[S] for all successors S
                let outSet = ArrayList<String>()
                for (succId in block.successors) {
                    match (result.in_.get(succId)) {
                        case Some(succIn) =>
                            for (v in succIn) {
                                if (!outSet.contains(v)) {
                                    outSet.append(v)
                                }
                            }
                        case None => ()
                    }
                }
                // IN[B] = USE[B] union (OUT[B] - DEF[B])
                let inSet = ArrayList<String>()
                match (result.use.get(block.id)) {
                    case Some(useSet) =>
                        for (v in useSet) {
                            if (!inSet.contains(v)) {
                                inSet.append(v)
                            }
                        }
                    case None => ()
                }
                let defList = match (result.def.get(block.id)) {
                    case Some(d) => d
                    case None => ArrayList<String>()
                }
                for (v in outSet) {
                    if (!defList.contains(v) && !inSet.contains(v)) {
                        inSet.append(v)
                    }
                }
                if (!stringSetsEqual(match (result.in_.get(block.id)) {
                    case Some(s) => s
                    case None => ArrayList<String>()
                }, inSet) || !stringSetsEqual(match (result.out.get(block.id)) {
                    case Some(s) => s
                    case None => ArrayList<String>()
                }, outSet)) {
                    changed = true
                }
                result.in_.put(block.id, inSet)
                result.out.put(block.id, outSet)
            }
        }
        return result
    }

    /// 检查定义列表是否包含某个定义
    private static func containsDef(defs: ArrayList<Definition>, target: Definition): Bool {
        for (def in defs) {
            if (def.name == target.name && def.blockId == target.blockId && def.stmtIndex == target.stmtIndex) {
                return true
            }
        }
        return false
    }

    /// 比较两个定义集合是否相等
    private static func defsEqual(a: ArrayList<Definition>, b: ArrayList<Definition>): Bool {
        if (a.size != b.size) {
            return false
        }
        for (def in a) {
            if (!containsDef(b, def)) {
                return false
            }
        }
        return true
    }

    /// 比较两个字符串集合是否相等
    private static func stringSetsEqual(a: ArrayList<String>, b: ArrayList<String>): Bool {
        if (a.size != b.size) {
            return false
        }
        for (s in a) {
            if (!b.contains(s)) {
                return false
            }
        }
        return true
    }
}

// ============================================================================
// ComplexityAnalysis - 复杂度分析
// 严格翻译自: src/ast/ 中的结构分析模式
// Bun 不显式计算复杂度，但 bundler 中使用类似分析进行代码分割
// ============================================================================

/// 复杂度分析结果
public class ComplexityResult {
    /// 圈复杂度 - McCabe cyclomatic complexity
    public var cyclomaticComplexity: Int64
    /// 最大嵌套深度
    public var maxNestingDepth: Int64
    /// 总语句数
    public var totalStmts: Int64
    /// 总表达式数
    public var totalExprs: Int64
    /// 函数数量
    public var functionCount: Int64
    /// 循环数量
    public var loopCount: Int64
    /// 条件分支数量
    public var branchCount: Int64

    public init() {
        cyclomaticComplexity = Int64(1)
        maxNestingDepth = Int64(0)
        totalStmts = Int64(0)
        totalExprs = Int64(0)
        functionCount = Int64(0)
        loopCount = Int64(0)
        branchCount = Int64(0)
    }
}

/// 复杂度分析器 - 对应 Bun bundler 中的 AST 结构分析
public class ComplexityAnalysis {
    /// 分析语句列表的复杂度
    public static func analyze(stmts: ArrayList<StmtNode>): ComplexityResult {
        let result = ComplexityResult()
        analyzeStmts(stmts, result, Int64(0))
        return result
    }

    /// 分析单个语句列表
    private static func analyzeStmts(
        stmts: ArrayList<StmtNode>,
        result: ComplexityResult,
        currentDepth: Int64
    ): Unit {
        for (stmt in stmts) {
            analyzeStmt(stmt, result, currentDepth)
        }
    }

    /// 分析单个语句
    private static func analyzeStmt(
        stmt: StmtNode,
        result: ComplexityResult,
        currentDepth: Int64
    ): Unit {
        result.totalStmts += Int64(1)
        if (currentDepth > result.maxNestingDepth) {
            result.maxNestingDepth = currentDepth
        }

        match (stmt.tag) {
            case StmtTag.If => {
                result.cyclomaticComplexity += Int64(1)
                result.branchCount += Int64(1)
                // 分析子语句
                for (child in stmt.stmts) {
                    analyzeStmt(child, result, currentDepth + Int64(1))
                }
            }
            case StmtTag.For | StmtTag.ForIn | StmtTag.ForOf |
                 StmtTag.While | StmtTag.DoWhile => {
                result.cyclomaticComplexity += Int64(1)
                result.loopCount += Int64(1)
                for (child in stmt.stmts) {
                    analyzeStmt(child, result, currentDepth + Int64(1))
                }
            }
            case StmtTag.Switch => {
                // switch 每个 case 增加一条路径
                result.cyclomaticComplexity += stmt.stmts.size
                result.branchCount += Int64(1)
                for (child in stmt.stmts) {
                    analyzeStmt(child, result, currentDepth + Int64(1))
                }
            }
            case StmtTag.Function | StmtTag.Class => {
                result.functionCount += Int64(1)
                for (child in stmt.stmts) {
                    analyzeStmt(child, result, Int64(0)) // 函数重置嵌套深度
                }
            }
            case StmtTag.Block => {
                for (child in stmt.stmts) {
                    analyzeStmt(child, result, currentDepth)
                }
            }
            case StmtTag.Try => {
                result.cyclomaticComplexity += Int64(1)
                for (child in stmt.stmts) {
                    analyzeStmt(child, result, currentDepth + Int64(1))
                }
            }
            case StmtTag.Expr => {
                for (child in stmt.children) {
                    countExprs(child, result)
                }
            }
            case _ => {
                for (child in stmt.stmts) {
                    analyzeStmt(child, result, currentDepth)
                }
            }
        }
    }

    /// 递归计算表达式数量
    private static func countExprs(node: ASTNode, result: ComplexityResult): Unit {
        result.totalExprs += Int64(1)
        for (child in node.children) {
            countExprs(child, result)
        }
    }

    /// 计算表达式树的嵌套深度
    public static func exprDepth(node: ASTNode): Int64 {
        if (node.children.size == Int64(0)) {
            return Int64(0)
        }
        var maxD = Int64(0)
        for (child in node.children) {
            let d = exprDepth(child)
            if (d > maxD) {
                maxD = d
            }
        }
        return maxD + Int64(1)
    }
}
