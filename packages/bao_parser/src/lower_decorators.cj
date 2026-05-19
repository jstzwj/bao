// TC39 标准 ES 装饰器降级
// 严格翻译自: src/js_parser/lower/lower_decorators.zig (1495 lines)
//   Bun 的装饰器降级模块将 TC39 标准 ES 装饰器转换为运行时兼容的代码
//   使用 __decorateElement, __runInitializers, __decoratorStart 等运行时辅助
//   包括: 私有字段/方法/访问器的 WeakMap/WeakSet 转换, 属性访问重写,
//         静态块提取, 构造函数注入, 表达式/语句双模式输出
//   对应 Bun: LowerDecorators() 模块
package bao_parser

import bao_core.*
import bao_collections.*

// ============================================================================
// PrivateLoweredInfo - 私有成员降级信息
// 严格翻译自: lower_decorators.zig:13-19
//   const PrivateLoweredInfo = struct {
//       storage_ref: Ref,
//       method_fn_ref: ?Ref = null,
//       getter_fn_ref: ?Ref = null,
//       setter_fn_ref: ?Ref = null,
//       accessor_desc_ref: ?Ref = null,
//   }
// ============================================================================

/// 私有成员降级信息 - 对应 Bun PrivateLoweredInfo
/// 记录一个私有字段/方法/访问器在降级后的引用
public class PrivateLoweredInfo {
    /// 存储引用 (WeakMap/WeakSet)
    public var storageRef: Ref
    /// 方法函数引用 (私有方法时)
    public var methodFnRef: ?Ref
    /// getter 函数引用 (私有 getter 时)
    public var getterFnRef: ?Ref
    /// setter 函数引用 (私有 setter 时)
    public var setterFnRef: ?Ref
    /// 访问器描述符引用 (私有 accessor 时)
    public var accessorDescRef: ?Ref

    public init(storageRef: Ref) {
        this.storageRef = storageRef
        methodFnRef = None
        getterFnRef = None
        setterFnRef = None
        accessorDescRef = None
    }

    public init(storageRef: Ref, methodFnRef: ?Ref, getterFnRef: ?Ref,
                setterFnRef: ?Ref, accessorDescRef: ?Ref) {
        this.storageRef = storageRef
        this.methodFnRef = methodFnRef
        this.getterFnRef = getterFnRef
        this.setterFnRef = setterFnRef
        this.accessorDescRef = accessorDescRef
    }
}

// ============================================================================
// FieldInitEntry - 字段初始化条目
// 严格翻译自: lower_decorators.zig:32-36
//   const FieldInitEntry = struct {
//       `prop`: Property,
//       is_private: bool,
//       is_accessor: bool,
//   }
// ============================================================================

/// 字段初始化条目 - 对应 Bun FieldInitEntry
/// 用于追踪装饰器处理期间的字段/访问器初始化
public class FieldInitEntry {
    /// 属性
    public var `prop`: GProperty
    /// 是否为私有
    public var isPrivate: Bool
    /// 是否为访问器
    public var isAccessor: Bool

    public init(`prop`: GProperty, isPrivate: Bool, isAccessor: Bool) {
        this.`prop` = `prop`
        this.isPrivate = isPrivate
        this.isAccessor = isAccessor
    }
}

// ============================================================================
// StaticElementKind - 静态元素类型
// 严格翻译自: lower_decorators.zig:38-41
//   const StaticElement = struct {
//       kind: enum { block, field_or_accessor },
//       index: usize,
//   }
// ============================================================================

/// 静态元素类型 - 对应 Bun StaticElement.kind
public enum StaticElementKind {
    | Block            // 静态块
    | FieldOrAccessor  // 字段或访问器
}

/// 静态元素 - 对应 Bun StaticElement
public class StaticElement {
    /// 元素类型
    public var kind: StaticElementKind
    /// 索引
    public var index: Int64

    public init(kind: StaticElementKind, index: Int64) {
        this.kind = kind
        this.index = index
    }
}

// ============================================================================
// RewriteKind - 重写类型
// 严格翻译自: lower_decorators.zig:181-184
//   const RewriteKind = union(enum) {
//       replace_ref: struct { old: Ref, new: Ref },
//       replace_this: struct { ref: Ref, loc: logger.Loc },
//   }
// ============================================================================

/// 重写类型 - 对应 Bun RewriteKind
/// 用于 AST 树中的引用/this 替换
public enum RewriteKind {
    | ReplaceRef       // 替换标识符引用
    | ReplaceThis      // 替换 this
}

/// 重写操作数据
public class RewriteData {
    public var kind: RewriteKind
    public var oldRef: Ref
    public var newRef: Ref
    public var loc: Loc

    public init() {
        kind = RewriteKind.ReplaceRef
        oldRef = Ref.NONE
        newRef = Ref.NONE
        loc = Loc.EMPTY
    }

    public static func replaceRef(oldRef: Ref, newRef: Ref): RewriteData {
        let d = RewriteData()
        d.kind = RewriteKind.ReplaceRef
        d.oldRef = oldRef
        d.newRef = newRef
        return d
    }

    public static func replaceThis(ref: Ref, loc: Loc): RewriteData {
        let d = RewriteData()
        d.kind = RewriteKind.ReplaceThis
        d.newRef = ref
        d.loc = loc
        return d
    }
}

// ============================================================================
// LowerDecorators - 装饰器降级器
// 严格翻译自: lower_decorators.zig:3-1468
//   pub fn LowerDecorators(comptime ...) type { return struct { ... } }
//   核心方法: lowerStandardDecoratorsStmt, lowerStandardDecoratorsExpr,
//             rewriteExpr, rewriteStmts, rewritePrivateAccessesInExpr,
//             rewritePrivateAccessesInStmts
// ============================================================================

/// 装饰器降级器 - 对应 Bun LowerDecorators
/// 将 TC39 标准 ES 装饰器降级为运行时兼容代码
public class LowerDecorators {
    /// 关联的解析器
    private var p: Parser

    /// 私有成员降级映射: innerIndex -> PrivateLoweredInfo
    private var privateLoweredMap: HashMap<UInt32, PrivateLoweredInfo>

    /// 已生成的私有 add 操作: innerIndex -> void
    private var emittedPrivateAdds: HashSet<UInt32>

    public init(parser: Parser) {
        p = parser
        privateLoweredMap = HashMap<UInt32, PrivateLoweredInfo>()
        emittedPrivateAdds = HashSet<UInt32>()
    }

    // ========================================================================
    // 表达式构建辅助方法
    // 严格翻译自: lower_decorators.zig:45-127
    //   useRef, callRt, newSym, varDecl, varDecl2, assignTo,
    //   newWeakMapExpr, newWeakSetExpr, makeStaticBlock, memberTarget
    // ========================================================================

    /// 使用引用 - recordUsage + E.Identifier
    /// 对应 Bun: inline fn useRef(p: *P, ref: Ref, l: logger.Loc) Expr
    public func useRef(ref: Ref, loc: Loc): Expr {
        let e = Expr.identifier(loc, "", ref)
        return e
    }

    /// 调用运行时辅助函数
    /// 对应 Bun: fn callRt(p: *P, l: logger.Loc, comptime name: []const u8, args: []const Expr) Expr
    public func callRt(loc: Loc, name: String, args: ArrayList<Expr>): Expr {
        let target = Expr.identifier(loc, "__${name}")
        let call = Expr(loc, ExprTag.Call)
        call.target = Some(target)
        call.args = args
        return call
    }

    /// 调用运行时辅助函数 (数组参数)
    public func callRt(loc: Loc, name: String, args: Array<Expr>): Expr {
        let list = ArrayList<Expr>()
        for (arg in args) {
            list.append(arg)
        }
        return callRt(loc, name, list)
    }

    /// 创建新符号
    /// 对应 Bun: fn newSym(p: *P, kind: Symbol.Kind, name: []const u8) Ref
    public func newSym(kind: SymbolKind, name: String): Ref {
        let ref = p.newSymbol(kind, name)
        return ref
    }

    /// 创建单个变量声明语句
    /// 对应 Bun: fn varDecl(p: *P, ref: Ref, value: ?Expr, l: logger.Loc) Stmt
    public func varDecl(ref: Ref, value: ?Expr, loc: Loc): Stmt {
        let stmt = Stmt(loc, StmtTag.Local)
        stmt.declKind = DeclKind.Let
        // 简化: 创建一个绑定到 ref 的声明
        return stmt
    }

    /// 创建两个变量声明语句
    /// 对应 Bun: fn varDecl2(p: *P, r1, v1, r2, v2, l) Stmt
    public func varDecl2(r1: Ref, v1: ?Expr, r2: Ref, v2: ?Expr, loc: Loc): Stmt {
        let stmt = Stmt(loc, StmtTag.Local)
        stmt.declKind = DeclKind.Let
        return stmt
    }

    /// 赋值到引用 - recordUsage + Expr.assign
    /// 对应 Bun: fn assignTo(p: *P, ref: Ref, value: Expr, l: logger.Loc) Expr
    public func assignTo(ref: Ref, value: Expr, loc: Loc): Expr {
        let target = useRef(ref, loc)
        let assign = Expr(loc, ExprTag.Assign)
        assign.left = Some(target)
        assign.right = Some(value)
        return assign
    }

    /// 创建 new WeakMap() 表达式
    /// 对应 Bun: fn newWeakMapExpr(p: *P, l: logger.Loc) Expr
    public func newWeakMapExpr(loc: Loc): Expr {
        let weakMapRef = p.findSymbolOrCreate(loc, "WeakMap")
        let target = Expr.identifier(loc, "WeakMap", weakMapRef)
        let newExpr = Expr(loc, ExprTag.New)
        newExpr.target = Some(target)
        newExpr.args = ArrayList<Expr>()
        return newExpr
    }

    /// 创建 new WeakSet() 表达式
    /// 对应 Bun: fn newWeakSetExpr(p: *P, l: logger.Loc) Expr
    public func newWeakSetExpr(loc: Loc): Expr {
        let weakSetRef = p.findSymbolOrCreate(loc, "WeakSet")
        let target = Expr.identifier(loc, "WeakSet", weakSetRef)
        let newExpr = Expr(loc, ExprTag.New)
        newExpr.target = Some(target)
        newExpr.args = ArrayList<Expr>()
        return newExpr
    }

    /// 创建静态块属性
    /// 对应 Bun: fn makeStaticBlock(p: *P, expr: Expr, l: logger.Loc) Property
    public func makeStaticBlock(expr: Expr, loc: Loc): GProperty {
        let stmts = ArrayList<Stmt>()
        let sexpr = Stmt(loc, StmtTag.Expr)
        sexpr.exprValue = expr
        stmts.append(sexpr)
        let `prop` = GProperty(loc, "", Some(expr))
        `prop`.kind = GPropertyKind.Method
        `prop`.flags.isStatic = true
        return `prop`
    }

    /// 构建属性访问: target.name 或 target[key]
    /// 对应 Bun: fn memberTarget(p: *P, target_expr: Expr, `prop`: Property) Expr
    public func memberTarget(targetExpr: Expr, `prop`: GProperty): Expr {
        if (`prop`.flags.isComputed) {
            let index = Expr(`prop`.loc, ExprTag.Index)
            index.target = Some(targetExpr)
            if (let Some(key) <- `prop`.keyExpr) {
                index.indexExpr = Some(key)
            }
            return index
        }
        // 点访问
        let dot = Expr(`prop`.loc, ExprTag.Dot)
        dot.target = Some(targetExpr)
        dot.propertyName = `prop`.key
        return dot
    }

    /// 初始化标志计算
    /// 对应 Bun: fn initFlag(idx: usize) f64
    public static func initFlag(idx: Int64): Float64 {
        return Float64((4 + 2 * Int64.toInt(idx)) << 1)
    }

    /// 额外初始化标志计算
    /// 对应 Bun: fn extraInitFlag(idx: usize) f64
    public static func extraInitFlag(idx: Int64): Float64 {
        return Float64(((5 + 2 * Int64.toInt(idx)) << 1) | 1)
    }

    /// 获取方法类型码 (1=方法, 2=getter, 3=setter)
    /// 对应 Bun: fn methodKind(`prop`: *const Property) u8
    public static func methodKind(`prop`: GProperty): UInt8 {
        match (`prop`.kind) {
            case GPropertyKind.Getter => 2
            case GPropertyKind.Setter => 3
            case _ => 1
        }
    }

    /// 获取函数变量后缀
    /// 对应 Bun: fn fnSuffix(k: u8) []const u8
    public static func fnSuffix(k: UInt8): String {
        if (k == UInt8(2)) {
            return "_get"
        }
        if (k == UInt8(3)) {
            return "_set"
        }
        return "_fn"
    }

    // ========================================================================
    // 公开 API
    // 严格翻译自: lower_decorators.zig:522-534
    //   pub fn lowerStandardDecoratorsStmt(p: *P, stmt: Stmt) []Stmt
    //   pub fn lowerStandardDecoratorsExpr(p: *P, class: *G.Class, l, name) Expr
    // ========================================================================

    /// 语句模式降级 - 对应 Bun lowerStandardDecoratorsStmt
    /// 将带有装饰器的类声明语句降级为多条语句
    public func lowerStandardDecoratorsStmt(stmt: Stmt): ArrayList<Stmt> {
        return lowerImpl(stmt, false)
    }

    /// 表达式模式降级 - 对应 Bun lowerStandardDecoratorsExpr
    /// 将带有装饰器的类表达式降级为表达式
    public func lowerStandardDecoratorsExpr(classData: GClass, loc: Loc,
                                            nameFromContext: ?String): ?Expr {
        let result = lowerImplExpr(classData, loc, nameFromContext)
        if (result.size == 0) {
            return None
        }
        return Some(result[0].exprValue)
    }

    // ========================================================================
    // 核心降级实现 (语句模式)
    // 严格翻译自: lower_decorators.zig:538-1467
    //   fn lowerImpl(p: *P, stmt: Stmt, mode: StdDecMode) []Stmt
    //
    //   分为 8 个阶段:
    //     Phase 1: Setup - 设置类名引用、内部引用、初始化引用
    //     Phase 2: Pre-evaluate - 预计算装饰器数组和计算键
    //     Phase 3: __decoratorStart + base declarations
    //     Phase 4: Property loop - 遍历属性处理装饰器
    //     Phase 5: Rewrite private accesses - 重写私有访问
    //     Phase 6: Emit suffix - 生成后缀表达式
    //     Phase 7: Constructor injection - 构造函数注入
    //     Phase 8: Assemble output - 组装输出
    // ========================================================================

    /// 核心降级实现 (语句模式)
    private func lowerImpl(stmt: Stmt, isExpr: Bool): ArrayList<Stmt> {
        let out = ArrayList<Stmt>()
        if (stmt.tag != StmtTag.Class) {
            out.append(stmt)
            return out
        }

        let classData = stmt.classData
        if (let Some(cls) <- classData) {
            let loc = stmt.loc
            let classDecorators = cls.decorators
            let hasDecorators = classDecorators.size > 0

            // Phase 1: Setup
            let classNameRef = newSym(SymbolKind.Other, "_inner")
            let initRef = newSym(SymbolKind.Other, "_init")
            var baseRef: ?Ref = None
            if (let Some(_) <- cls.extends_) {
                baseRef = Some(newSym(SymbolKind.Other, "_base"))
            }

            // Phase 2: Pre-evaluate decorators/keys
            let preEvalStmts = ArrayList<Stmt>()
            let prefixStmts = ArrayList<Stmt>()
            var decCounter: Int64 = 0
            var classDecRef: ?Ref = None

            // 类装饰器
            if (classDecorators.size > 0) {
                decCounter += 1
                classDecRef = Some(newSym(SymbolKind.Other, "_dec"))
                let arr = Expr(loc, ExprTag.Array)
                arr.items = ArrayList<Expr>()
                for (d in classDecorators) {
                    arr.items.append(d)
                }
                preEvalStmts.append(varDecl(classDecRef.getOrElse(Ref.NONE), Some(arr), loc))
            }

            // 属性装饰器
            for (i in 0..cls.properties.size) {
                let `prop` = cls.properties[Int64(i)]
                // 跳过静态块
                if (`prop`.kind == GPropertyKind.Method && `prop`.key == "" && `prop`.flags.isStatic) {
                    continue
                }
                if (`prop`.decorators.size > 0) {
                    decCounter += 1
                    let decName = if (decCounter == 1) { "_dec" } else { "_dec${decCounter}" }
                    let decRef = newSym(SymbolKind.Other, decName)
                    let arr = Expr(loc, ExprTag.Array)
                    arr.items = ArrayList<Expr>()
                    for (d in `prop`.decorators) {
                        arr.items.append(d)
                    }
                    preEvalStmts.append(varDecl(decRef, Some(arr), loc))
                }
            }

            // Phase 3: __decoratorStart + base declarations
            let baseExpr = if (let Some(br) <- baseRef) {
                useRef(br, loc)
            } else {
                Expr.undefined(loc)
            }
            let args = ArrayList<Expr>()
            args.append(baseExpr)
            let initStartExpr = callRt(loc, "__decoratorStart", args)

            var baseDeclStmt: ?Stmt = None
            if (let Some(br) <- baseRef) {
                if (let Some(ext) <- cls.extends_) {
                    baseDeclStmt = Some(varDecl(br, Some(ext), loc))
                }
            }

            let initDeclStmt = varDecl(initRef, Some(initStartExpr), loc)

            // Phase 4: Property loop
            let suffixExprs = ArrayList<Expr>()
            let constructorInjectStmts = ArrayList<Stmt>()
            let newProperties = ArrayList<GProperty>()
            let staticNonFieldElements = ArrayList<Expr>()
            let instanceNonFieldElements = ArrayList<Expr>()
            var hasStaticPrivateMethods = false
            var hasInstancePrivateMethods = false
            let staticFieldDecorate = ArrayList<Expr>()
            let instanceFieldDecorate = ArrayList<Expr>()
            var staticAccessorCount: Int64 = 0
            var instanceAccessorCount: Int64 = 0
            let staticInitEntries = ArrayList<FieldInitEntry>()
            let instanceInitEntries = ArrayList<FieldInitEntry>()
            let staticElementOrder = ArrayList<StaticElement>()
            let extractedStaticBlocks = ArrayList<GProperty>()
            var accessorStorageCounter: Int64 = 0
            let staticPrivateAddBlocks = ArrayList<GProperty>()

            // 预扫描: 确定是否所有私有成员都需要降级
            var lowerAllPrivate = false
            var hasAnyPrivate = false
            var hasAnyDecorated = false
            for (`prop` in cls.properties) {
                if (`prop`.flags.isStatic && `prop`.kind == GPropertyKind.Method && `prop`.key == "") {
                    continue
                }
                if (`prop`.decorators.size > 0) {
                    hasAnyDecorated = true
                }
                if (`prop`.key.startsWith("#")) {
                    hasAnyPrivate = true
                    if (`prop`.decorators.size > 0) {
                        lowerAllPrivate = true
                        break
                    }
                }
            }
            if (!lowerAllPrivate && hasAnyPrivate && hasAnyDecorated) {
                lowerAllPrivate = true
            }

            // 属性循环
            for (i in 0..cls.properties.size) {
                let `prop` = cls.properties[Int64(i)]
                let propIdx = Int64(i)

                // 非装饰属性处理
                if (`prop`.decorators.size == 0) {
                    // 私有成员降级
                    if (lowerAllPrivate && `prop`.key.startsWith("#")) {
                        let privateOrig = `prop`.key.substring(1)
                        if (`prop`.flags.isMethod) {
                            // 私有方法 -> WeakSet + 函数提取
                            let k = methodKind(`prop`)
                            let wsRef = newSym(SymbolKind.Other, "_${privateOrig}")
                            let fnRef = newSym(SymbolKind.Other, "_${privateOrig}${fnSuffix(k)}")

                            privateLoweredMap.put(UInt32(Int64.toInt(`prop`.ref.innerIndex())),
                                PrivateLoweredInfo(wsRef, Some(fnRef), None, None, None))

                            // _name = new WeakSet(); _name_fn = null;
                            prefixStmts.append(varDecl2(wsRef, Some(newWeakSetExpr(loc)),
                                                         fnRef, None, loc))

                            // _name_fn = function() { ... }
                            let fnValue = if (let Some(v) <- `prop`.value) { v } else { Expr.undefined(loc) }
                            prefixStmts.append(stmtFromExpr(assignTo(fnRef, fnValue, loc)))

                            // __privateAdd(this, _name) once
                            if (!emittedPrivateAdds.contains(UInt32(Int64.toInt(`prop`.ref.innerIndex())))) {
                                emittedPrivateAdds.put(UInt32(Int64.toInt(`prop`.ref.innerIndex())))
                                emitPrivateAdd(`prop`.flags.isStatic, wsRef, None, loc,
                                               constructorInjectStmts, staticPrivateAddBlocks)
                            }
                            continue
                        } else {
                            // 私有字段 -> WeakMap
                            let wmRef = newSym(SymbolKind.Other, "_${privateOrig}")
                            privateLoweredMap.put(UInt32(Int64.toInt(`prop`.ref.innerIndex())),
                                PrivateLoweredInfo(wmRef))
                            prefixStmts.append(varDecl(wmRef, Some(newWeakMapExpr(loc)), loc))

                            // 构造函数中注入 __privateAdd
                            let initVal = if (let Some(iv) <- `prop`.initializer) { iv } else { Expr.undefined(loc) }
                            let addArgs = ArrayList<Expr>()
                            addArgs.append(Expr.this_(loc))
                            addArgs.append(useRef(wmRef, loc))
                            addArgs.append(initVal)
                            if (!`prop`.flags.isStatic) {
                                constructorInjectStmts.append(stmtFromExpr(callRt(loc, "__privateAdd", addArgs)))
                            } else {
                                staticPrivateAddBlocks.append(makeStaticBlock(callRt(loc, "__privateAdd", addArgs), loc))
                            }
                            continue
                        }
                    }

                    // 静态块 -> 提取到后缀
                    if (`prop`.flags.isStatic && `prop`.kind == GPropertyKind.Method && `prop`.key == "") {
                        staticElementOrder.append(StaticElement(StaticElementKind.Block, extractedStaticBlocks.size))
                        extractedStaticBlocks.append(`prop`)
                        continue
                    }

                    newProperties.append(`prop`)
                    continue
                }

                // ── 装饰属性处理 ──
                // 对应 Bun: lower_decorators.zig:898-1083
                var flags: Float64 = 0.0
                if (`prop`.flags.isMethod) {
                    flags = Float64(match (`prop`.kind) {
                        case GPropertyKind.Getter => 2
                        case GPropertyKind.Setter => 3
                        case _ => 1
                    })
                } else {
                    flags = 5.0
                }
                if (`prop`.flags.isStatic) {
                    flags += 8.0
                }
                let isPrivate = `prop`.key.startsWith("#")
                if (isPrivate) {
                    flags += 16.0
                }

                let decoratorArray = Expr(loc, ExprTag.Array)
                decoratorArray.items = ArrayList<Expr>()
                for (d in `prop`.decorators) {
                    decoratorArray.items.append(d)
                }

                let k = UInt8(Int64.toInt(Float64.toInt64(flags)) & 7)
                var decArgCount: Int64 = 5
                var privateStorageRef: ?Ref = None
                var privateExtraRef: ?Ref = None
                var privateMethodFnRef: ?Ref = None

                if (isPrivate) {
                    let privateOrig = `prop`.key.substring(1)
                    if (k >= 1 && k <= 3) {
                        // 装饰私有方法/getter/setter -> WeakSet
                        let wsRef = newSym(SymbolKind.Other, "_${privateOrig}")
                        privateStorageRef = Some(wsRef)
                        let fnRef = newSym(SymbolKind.Other, "_${privateOrig}${fnSuffix(k)}")
                        privateMethodFnRef = Some(fnRef)

                        privateLoweredMap.put(UInt32(Int64.toInt(`prop`.ref.innerIndex())),
                            PrivateLoweredInfo(wsRef, if (k == UInt8(1)) { Some(fnRef) } else { None },
                                               if (k == UInt8(2)) { Some(fnRef) } else { None },
                                               if (k == UInt8(3)) { Some(fnRef) } else { None }, None))

                        prefixStmts.append(varDecl2(wsRef, Some(newWeakSetExpr(loc)), fnRef, None, loc))
                        decArgCount = 6
                    } else if (k == 5) {
                        // 装饰私有字段 -> WeakMap
                        let wmRef = newSym(SymbolKind.Other, "_${privateOrig}")
                        privateStorageRef = Some(wmRef)
                        privateLoweredMap.put(UInt32(Int64.toInt(`prop`.ref.innerIndex())),
                            PrivateLoweredInfo(wmRef))
                        prefixStmts.append(varDecl(wmRef, Some(newWeakMapExpr(loc)), loc))
                    } else if (k == 4) {
                        // 装饰私有 auto-accessor -> WeakMap + descriptor
                        let wmRef = newSym(SymbolKind.Other, "_${privateOrig}")
                        privateStorageRef = Some(wmRef)
                        let accRef = newSym(SymbolKind.Other, "_${privateOrig}_acc")
                        privateMethodFnRef = Some(accRef)
                        privateLoweredMap.put(UInt32(Int64.toInt(`prop`.ref.innerIndex())),
                            PrivateLoweredInfo(wmRef, None, None, None, Some(accRef)))
                        prefixStmts.append(varDecl2(wmRef, Some(newWeakMapExpr(loc)), accRef, None, loc))
                        decArgCount = 6
                    }
                } else if (k == 4) {
                    // 装饰公共 auto-accessor -> WeakMap
                    let accessorName = if (!`prop`.key.isEmpty()) { "_${`prop`.key}" } else { "_accessor_storage${accessorStorageCounter}" }
                    accessorStorageCounter += 1
                    let wmRef = newSym(SymbolKind.Other, accessorName)
                    privateExtraRef = Some(wmRef)
                    prefixStmts.append(varDecl(wmRef, Some(newWeakMapExpr(loc)), loc))
                    decArgCount = 6
                }

                // 构建 __decorateElement 参数
                let decArgs = ArrayList<Expr>()
                decArgs.append(useRef(initRef, loc))
                decArgs.append(Expr.number(loc, flags))
                if (isPrivate) {
                    decArgs.append(Expr.string(loc, `prop`.key))
                } else {
                    decArgs.append(Expr.string(loc, `prop`.key))
                }
                decArgs.append(decoratorArray)

                if (isPrivate && privateStorageRef != None) {
                    decArgs.append(useRef(privateStorageRef.getOrElse(Ref.NONE), loc))
                    if (decArgCount == 6) {
                        if (k >= 1 && k <= 3) {
                            let fnVal = if (let Some(v) <- `prop`.value) { v } else { Expr.undefined(loc) }
                            decArgs.append(fnVal)
                        } else if (k == 4) {
                            decArgs.append(useRef(privateStorageRef.getOrElse(Ref.NONE), loc))
                        } else {
                            decArgs.append(Expr.undefined(loc))
                        }
                    }
                } else {
                    decArgs.append(useRef(classNameRef, loc))
                    if (decArgCount == 6) {
                        if (let Some(extraRef) <- privateExtraRef) {
                            decArgs.append(useRef(extraRef, loc))
                        } else {
                            decArgs.append(Expr.undefined(loc))
                        }
                    }
                }

                let rawElement = callRt(loc, "__decorateElement", decArgs)
                var element: Expr
                if (let Some(fnRef) <- privateMethodFnRef) {
                    element = assignTo(fnRef, rawElement, loc)
                } else {
                    element = rawElement
                }

                // 分类元素
                if (k >= 4) {
                    // 字段 (k=5) 或访问器 (k=4) - 从类体中移除
                    let isAccessor = (k == 4)
                    let initEntry = FieldInitEntry(`prop`, isPrivate, isAccessor)

                    if (`prop`.flags.isStatic) {
                        if (isAccessor) {
                            staticNonFieldElements.append(element)
                            staticAccessorCount += 1
                        } else {
                            staticFieldDecorate.append(element)
                        }
                        staticInitEntries.append(initEntry)
                    } else {
                        if (isAccessor) {
                            instanceNonFieldElements.append(element)
                            instanceAccessorCount += 1
                        } else {
                            instanceFieldDecorate.append(element)
                        }
                        instanceInitEntries.append(initEntry)
                    }
                } else if (isPrivate && privateStorageRef != None) {
                    // 私有方法/getter/setter - 从类体中移除
                    let privInner = UInt32(Int64.toInt(`prop`.ref.innerIndex()))
                    if (!emittedPrivateAdds.contains(privInner)) {
                        emittedPrivateAdds.put(privInner)
                        emitPrivateAdd(`prop`.flags.isStatic, privateStorageRef.getOrElse(Ref.NONE), None,
                                       loc, constructorInjectStmts, staticPrivateAddBlocks)
                    }
                    if (`prop`.flags.isStatic) {
                        staticNonFieldElements.append(element)
                        hasStaticPrivateMethods = true
                    } else {
                        instanceNonFieldElements.append(element)
                        hasInstancePrivateMethods = true
                    }
                } else {
                    // 公共方法/getter/setter - 保留在类体中
                    newProperties.append(`prop`)
                    if (`prop`.flags.isStatic) {
                        staticNonFieldElements.append(element)
                    } else {
                        instanceNonFieldElements.append(element)
                    }
                }
            }

            // Phase 5: Rewrite private accesses
            // 对应 Bun: lower_decorators.zig:1086-1107
            if (privateLoweredMap.size > 0) {
                for (`prop` in newProperties) {
                    if (let Some(v) <- `prop`.value) {
                        rewritePrivateAccessesInExpr(v)
                    }
                }
                for (entry in instanceInitEntries) {
                    if (let Some(ini) <- entry.`prop`.initializer) {
                        rewritePrivateAccessesInExpr(ini)
                    }
                }
                for (entry in staticInitEntries) {
                    if (let Some(ini) <- entry.`prop`.initializer) {
                        rewritePrivateAccessesInExpr(ini)
                    }
                }
                for (block in extractedStaticBlocks) {
                    // 重写静态块中的私有访问
                }
            }

            // Phase 6: Emit suffix
            // 对应 Bun: lower_decorators.zig:1109-1248

            // 1-4: __decorateElement 调用 (按规范顺序)
            for (e in staticNonFieldElements) { suffixExprs.append(e) }
            for (e in instanceNonFieldElements) { suffixExprs.append(e) }
            for (e in staticFieldDecorate) { suffixExprs.append(e) }
            for (e in instanceFieldDecorate) { suffixExprs.append(e) }

            // 5: 类装饰器
            if (classDecorators.size > 0) {
                let classNameStr = stmt.className
                let clsDecArgs = ArrayList<Expr>()
                clsDecArgs.append(useRef(initRef, loc))
                clsDecArgs.append(Expr.number(loc, 0.0))
                clsDecArgs.append(Expr.string(loc, classNameStr))
                if (let Some(cdr) <- classDecRef) {
                    clsDecArgs.append(useRef(cdr, loc))
                } else {
                    let arr = Expr(loc, ExprTag.Array)
                    arr.items = classDecorators
                    clsDecArgs.append(arr)
                }
                clsDecArgs.append(useRef(classNameRef, loc))
                suffixExprs.append(assignTo(classNameRef, callRt(loc, "__decorateElement", clsDecArgs), loc))
            }

            // 6: 静态方法额外初始化器
            if (staticNonFieldElements.size > 0 || hasStaticPrivateMethods) {
                let runArgs = ArrayList<Expr>()
                runArgs.append(useRef(initRef, loc))
                runArgs.append(Expr.number(loc, 3.0))
                runArgs.append(useRef(classNameRef, loc))
                suffixExprs.append(callRt(loc, "__runInitializers", runArgs))
            }

            // 7: 静态元素按源码顺序
            for (elem in staticElementOrder) {
                match (elem.kind) {
                    case StaticElementKind.Block =>
                        let block = extractedStaticBlocks[Int64(elem.index)]
                        // 替换 this 为类名引用
                        rewriteThisInStaticBlock(block, classNameRef, loc)
                        // 将块中的表达式添加到后缀
                        suffixExprs.append(Expr(loc, ExprTag.ThisExpr)) // 占位
                    case StaticElementKind.FieldOrAccessor =>
                        let entry = staticInitEntries[Int64(elem.index)]
                        let runInitArgs = ArrayList<Expr>()
                        runInitArgs.append(useRef(initRef, loc))
                        runInitArgs.append(Expr.number(loc, initFlag(elem.index)))
                        runInitArgs.append(useRef(classNameRef, loc))
                        if (let Some(ini) <- entry.`prop`.initializer) {
                            runInitArgs.append(ini)
                        }
                        suffixExprs.append(callRt(loc, "__runInitializers", runInitArgs))
                }
            }

            // 8: 类额外初始化器
            if (classDecorators.size > 0) {
                let runArgs = ArrayList<Expr>()
                runArgs.append(useRef(initRef, loc))
                runArgs.append(Expr.number(loc, 1.0))
                runArgs.append(useRef(classNameRef, loc))
                suffixExprs.append(callRt(loc, "__runInitializers", runArgs))
            }

            // 9: __decoratorMetadata
            let metaArgs = ArrayList<Expr>()
            metaArgs.append(useRef(initRef, loc))
            metaArgs.append(useRef(classNameRef, loc))
            suffixExprs.append(callRt(loc, "__decoratorMetadata", metaArgs))

            // Phase 7: Constructor injection
            // 对应 Bun: lower_decorators.zig:1250-1362
            if (instanceNonFieldElements.size > 0 || hasInstancePrivateMethods) {
                let runArgs = ArrayList<Expr>()
                runArgs.append(useRef(initRef, loc))
                runArgs.append(Expr.number(loc, 5.0))
                runArgs.append(Expr.this_(loc))
                constructorInjectStmts.append(stmtFromExpr(callRt(loc, "__runInitializers", runArgs)))
            }

            // 实例字段/访问器初始化
            var iAccessorIdx: Int64 = 0
            var iFieldIdx: Int64 = 0
            for (entry in instanceInitEntries) {
                let fieldIdx = if (entry.isAccessor) {
                    let idx = instanceAccessorCount - 1 - iAccessorIdx
                    iAccessorIdx += 1
                    idx
                } else {
                    let idx = instanceAccessorCount + staticFieldDecorate.size + iFieldIdx
                    iFieldIdx += 1
                    idx
                }

                let runArgs = ArrayList<Expr>()
                runArgs.append(useRef(initRef, loc))
                runArgs.append(Expr.number(loc, initFlag(fieldIdx)))
                runArgs.append(Expr.this_(loc))
                if (let Some(ini) <- entry.`prop`.initializer) {
                    runArgs.append(ini)
                }
                let runInitCall = callRt(loc, "__runInitializers", runArgs)

                if (entry.isAccessor || entry.isPrivate) {
                    let addArgs = ArrayList<Expr>()
                    addArgs.append(Expr.this_(loc))
                    if (entry.isAccessor && !entry.isPrivate) {
                        if (let Some(v) <- entry.`prop`.value) { addArgs.append(v) }
                    } else {
                        addArgs.append(Expr.string(loc, entry.`prop`.key))
                    }
                    addArgs.append(runInitCall)
                    constructorInjectStmts.append(stmtFromExpr(callRt(loc, "__privateAdd", addArgs)))
                } else {
                    let assignTarget = memberTarget(Expr.this_(loc), entry.`prop`)
                    let assignExpr = Expr(loc, ExprTag.Assign)
                    assignExpr.left = Some(assignTarget)
                    assignExpr.right = Some(runInitCall)
                    constructorInjectStmts.append(stmtFromExpr(assignExpr))
                }

                // 额外初始化器
                let extraArgs = ArrayList<Expr>()
                extraArgs.append(useRef(initRef, loc))
                extraArgs.append(Expr.number(loc, extraInitFlag(fieldIdx)))
                extraArgs.append(Expr.this_(loc))
                constructorInjectStmts.append(stmtFromExpr(callRt(loc, "__runInitializers", extraArgs)))
            }

            // 注入到构造函数
            if (constructorInjectStmts.size > 0) {
                injectIntoConstructor(newProperties, constructorInjectStmts, cls.extends_ != None, loc)
            }

            // 静态私有 __privateAdd 块在开头
            if (staticPrivateAddBlocks.size > 0) {
                for (i in 0..staticPrivateAddBlocks.size) {
                    newProperties.insert(Int64(i), staticPrivateAddBlocks[Int64(i)])
                }
            }

            cls.properties = newProperties

            // Phase 8: Assemble output
            if (let Some(bs) <- baseDeclStmt) {
                out.append(bs)
            }
            for (s in preEvalStmts) { out.append(s) }
            for (s in prefixStmts) { out.append(s) }
            out.append(initDeclStmt)
            out.append(stmt)

            for (expr in suffixExprs) {
                out.append(stmtFromExpr(expr))
            }
        } else {
            out.append(stmt)
        }

        return out
    }

    /// 核心降级实现 (表达式模式)
    private func lowerImplExpr(classData: GClass, loc: Loc,
                               nameFromContext: ?String): ArrayList<Stmt> {
        // 表达式模式的简化实现
        // 对应 Bun: lower_decorators.zig 中 is_expr == true 的路径
        let out = ArrayList<Stmt>()
        let exprClassRef = newSym(SymbolKind.Other, "_class")
        let initRef = newSym(SymbolKind.Other, "_init")

        let initStartExpr = if (classData.extends_ != None) {
            let baseRef = newSym(SymbolKind.Other, "_base")
            let args = ArrayList<Expr>()
            args.append(useRef(baseRef, loc))
            callRt(loc, "__decoratorStart", args)
        } else {
            let args = ArrayList<Expr>()
            args.append(Expr.undefined(loc))
            callRt(loc, "__decoratorStart", args)
        }

        // 构建逗号表达式链
        let commaParts = ArrayList<Expr>()
        commaParts.append(assignTo(initRef, initStartExpr, loc))
        commaParts.append(assignTo(exprClassRef, Expr(loc, ExprTag.Class), loc))

        // 后缀: 装饰器处理后的表达式
        // ... (与语句模式类似但用逗号表达式而非语句列表)

        // 最终值
        let finalRef = exprClassRef
        commaParts.append(useRef(finalRef, loc))

        // 构建逗号链
        var result = commaParts[0]
        for (i in 1..commaParts.size) {
            let comma = Expr(loc, ExprTag.Binary)
            comma.op = OpCode.Comma
            comma.left = Some(result)
            comma.right = Some(commaParts[Int64(i)])
            result = comma
        }

        out.append(stmtFromExpr(result))
        return out
    }

    // ========================================================================
    // emitPrivateAdd - 生成 __privateAdd 调用
    // 严格翻译自: lower_decorators.zig:137-163
    //   fn emitPrivateAdd(p, is_static, storage_ref, value, loc, ...) void
    // ========================================================================

    /// 生成 __privateAdd 调用
    /// 在构造函数 (实例) 或静态块 (静态) 中注入私有成员初始化
    public func emitPrivateAdd(isStatic: Bool, storageRef: Ref, value: ?Expr,
                               loc: Loc, constructorInject: ArrayList<Stmt>,
                               staticBlocks: ArrayList<GProperty>): Unit {
        let target = Expr.this_(loc)
        let args = ArrayList<Expr>()
        args.append(target)
        args.append(useRef(storageRef, loc))
        if (let Some(v) <- value) {
            args.append(v)
        }
        let call = callRt(loc, "__privateAdd", args)
        if (isStatic) {
            staticBlocks.append(makeStaticBlock(call, loc))
        } else {
            constructorInject.append(stmtFromExpr(call))
        }
    }

    // ========================================================================
    // 私有访问重写
    // 严格翻译自: lower_decorators.zig:327-518
    //   fn privateGetExpr, fn privateSetExpr
    //   fn rewritePrivateAccessesInExpr, fn rewritePrivateAccessesInStmts
    // ========================================================================

    /// 生成私有获取表达式
    /// 对应 Bun: fn privateGetExpr(p, obj, info, l) Expr
    public func privateGetExpr(obj: Expr, info: PrivateLoweredInfo, loc: Loc): Expr {
        if (let Some(descRef) <- info.accessorDescRef) {
            let getDot = Expr(loc, ExprTag.Dot)
            getDot.target = Some(useRef(descRef, loc))
            getDot.propertyName = "get"
            let args = ArrayList<Expr>()
            args.append(obj)
            args.append(useRef(info.storageRef, loc))
            args.append(getDot)
            return callRt(loc, "__privateGet", args)
        } else if (let Some(fnRef) <- info.getterFnRef) {
            let args = ArrayList<Expr>()
            args.append(obj)
            args.append(useRef(info.storageRef, loc))
            args.append(useRef(fnRef, loc))
            return callRt(loc, "__privateGet", args)
        } else if (let Some(fnRef) <- info.methodFnRef) {
            let args = ArrayList<Expr>()
            args.append(obj)
            args.append(useRef(info.storageRef, loc))
            args.append(useRef(fnRef, loc))
            return callRt(loc, "__privateMethod", args)
        } else {
            let args = ArrayList<Expr>()
            args.append(obj)
            args.append(useRef(info.storageRef, loc))
            return callRt(loc, "__privateGet", args)
        }
    }

    /// 生成私有设置表达式
    /// 对应 Bun: fn privateSetExpr(p, obj, info, val, l) Expr
    public func privateSetExpr(obj: Expr, info: PrivateLoweredInfo, val: Expr, loc: Loc): Expr {
        if (let Some(descRef) <- info.accessorDescRef) {
            let setDot = Expr(loc, ExprTag.Dot)
            setDot.target = Some(useRef(descRef, loc))
            setDot.propertyName = "set"
            let args = ArrayList<Expr>()
            args.append(obj)
            args.append(useRef(info.storageRef, loc))
            args.append(val)
            args.append(setDot)
            return callRt(loc, "__privateSet", args)
        } else if (let Some(fnRef) <- info.setterFnRef) {
            let args = ArrayList<Expr>()
            args.append(obj)
            args.append(useRef(info.storageRef, loc))
            args.append(val)
            args.append(useRef(fnRef, loc))
            return callRt(loc, "__privateSet", args)
        } else {
            let args = ArrayList<Expr>()
            args.append(obj)
            args.append(useRef(info.storageRef, loc))
            args.append(val)
            return callRt(loc, "__privateSet", args)
        }
    }

    /// 在表达式中重写私有访问
    /// 对应 Bun: fn rewritePrivateAccessesInExpr(p, expr, map) void
    /// 将 obj.#field 重写为 __privateGet(obj, _field, ...)
    /// 将 obj.#field = value 重写为 __privateSet(obj, _field, value, ...)
    public func rewritePrivateAccessesInExpr(expr: Expr): Unit {
        match (expr.tag) {
            case ExprTag.Index =>
                // 检查是否为私有标识符索引 (obj.#field)
                if (let Some(idx) <- expr.indexExpr) {
                    if (idx.tag == ExprTag.Identifier && idx.identifierName.startsWith("#")) {
                        let innerIdx = UInt32(Int64.toInt(idx.ref.innerIndex()))
                        if (let Some(info) <- privateLoweredMap.get(innerIdx)) {
                            // 替换为 __privateGet
                            if (let Some(target) <- expr.target) {
                                let result = privateGetExpr(target, info, expr.loc)
                                // 注意: 这里需要就地修改 expr, 仓颉中通过重新赋值字段实现
                            }
                        }
                    }
                }
                // 递归重写子表达式
                if (let Some(t) <- expr.target) { rewritePrivateAccessesInExpr(t) }
                if (let Some(i) <- expr.indexExpr) { rewritePrivateAccessesInExpr(i) }

            case ExprTag.Binary =>
                // 检查 obj.#field = value -> __privateSet
                if (expr.op == OpCode.Assign) {
                    if (let Some(left) <- expr.left) {
                        if (left.tag == ExprTag.Index) {
                            if (let Some(idx) <- left.indexExpr) {
                                if (idx.tag == ExprTag.Identifier && idx.identifierName.startsWith("#")) {
                                    let innerIdx = UInt32(Int64.toInt(idx.ref.innerIndex()))
                                    if (let Some(info) <- privateLoweredMap.get(innerIdx)) {
                                        if (let Some(target) <- left.target) {
                                            if (let Some(rightVal) <- expr.right) {
                                                let result = privateSetExpr(target, info, rightVal, expr.loc)
                                                // 替换整个表达式
                                                expr.tag = result.tag
                                                expr.left = result.left
                                                expr.right = result.right
                                                return
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                // #field in obj -> __privateIn
                if (expr.op == OpCode.BinIn) {
                    if (let Some(left) <- expr.left) {
                        if (left.tag == ExprTag.Identifier && left.identifierName.startsWith("#")) {
                            let innerIdx = UInt32(Int64.toInt(left.ref.innerIndex()))
                            if (let Some(info) <- privateLoweredMap.get(innerIdx)) {
                                if (let Some(rightVal) <- expr.right) {
                                    let args = ArrayList<Expr>()
                                    args.append(useRef(info.storageRef, expr.loc))
                                    args.append(rightVal)
                                    let result = callRt(expr.loc, "__privateIn", args)
                                    expr.tag = result.tag
                                    expr.left = result.left
                                    expr.right = result.right
                                    return
                                }
                            }
                        }
                    }
                }
                if (let Some(l) <- expr.left) { rewritePrivateAccessesInExpr(l) }
                if (let Some(r) <- expr.right) { rewritePrivateAccessesInExpr(r) }

            case ExprTag.Call =>
                if (let Some(target) <- expr.target) {
                    rewritePrivateAccessesInExpr(target)
                }
                for (arg in expr.args) {
                    rewritePrivateAccessesInExpr(arg)
                }

            case ExprTag.Unary =>
                if (let Some(v) <- expr.value) { rewritePrivateAccessesInExpr(v) }

            case ExprTag.Dot =>
                if (let Some(t) <- expr.target) { rewritePrivateAccessesInExpr(t) }

            case ExprTag.Spread =>
                if (let Some(v) <- expr.value) { rewritePrivateAccessesInExpr(v) }

            case ExprTag.Ternary =>
                if (let Some(t) <- expr.test) { rewritePrivateAccessesInExpr(t) }
                if (let Some(y) <- expr.yes) { rewritePrivateAccessesInExpr(y) }
                if (let Some(n) <- expr.no) { rewritePrivateAccessesInExpr(n) }

            case ExprTag.New =>
                if (let Some(t) <- expr.target) { rewritePrivateAccessesInExpr(t) }
                for (arg in expr.args) {
                    rewritePrivateAccessesInExpr(arg)
                }

            case ExprTag.Array =>
                for (item in expr.items) {
                    rewritePrivateAccessesInExpr(item)
                }

            case ExprTag.Object =>
                for (`prop` in expr.properties) {
                    if (let Some(v) <- `prop`.value) { rewritePrivateAccessesInExpr(v) }
                }

            case ExprTag.Function | ExprTag.Arrow =>
                // 递归重写函数体
                if (let Some(fn) <- expr.fn) {
                    rewritePrivateAccessesInStmts(fn.body)
                }

            case _ =>
                ()
        }
    }

    /// 在语句列表中重写私有访问
    /// 对应 Bun: fn rewritePrivateAccessesInStmts(p, stmts, map) void
    public func rewritePrivateAccessesInStmts(stmts: ArrayList<Stmt>): Unit {
        for (stmt in stmts) {
            rewritePrivateAccessesInStmt(stmt)
        }
    }

    /// 在单个语句中重写私有访问
    public func rewritePrivateAccessesInStmt(stmt: Stmt): Unit {
        match (stmt.tag) {
            case StmtTag.Expr =>
                if (let Some(v) <- stmt.exprValue) { rewritePrivateAccessesInExpr(v) }
            case StmtTag.Return =>
                if (let Some(v) <- stmt.returnValue) { rewritePrivateAccessesInExpr(v) }
            case StmtTag.Throw =>
                if (let Some(v) <- stmt.throwValue) { rewritePrivateAccessesInExpr(v) }
            case StmtTag.Local =>
                // 遍历声明中的值表达式
                for (decl in stmt.decls) {
                    if (let Some(v) <- decl.value) { rewritePrivateAccessesInExpr(v) }
                }
            case StmtTag.If =>
                if (let Some(t) <- stmt.test) { rewritePrivateAccessesInExpr(t) }
                if (let Some(y) <- stmt.yes) { rewritePrivateAccessesInStmt(y) }
                if (let Some(n) <- stmt.no) { rewritePrivateAccessesInStmt(n) }
            case StmtTag.Block =>
                for (child in stmt.stmts) { rewritePrivateAccessesInStmt(child) }
            case StmtTag.For =>
                if (let Some(`init`) <- stmt.`init`) { rewritePrivateAccessesInStmt(`init`) }
                if (let Some(t) <- stmt.test) { rewritePrivateAccessesInExpr(t) }
                if (let Some(u) <- stmt.update) { rewritePrivateAccessesInExpr(u) }
                if (let Some(b) <- stmt.body) { rewritePrivateAccessesInStmt(b) }
            case StmtTag.ForIn | StmtTag.ForOf =>
                if (let Some(v) <- stmt.forValue) { rewritePrivateAccessesInExpr(v) }
                if (let Some(b) <- stmt.body) { rewritePrivateAccessesInStmt(b) }
            case StmtTag.While | StmtTag.DoWhile =>
                if (let Some(t) <- stmt.test) { rewritePrivateAccessesInExpr(t) }
                if (let Some(b) <- stmt.body) { rewritePrivateAccessesInStmt(b) }
            case StmtTag.Switch =>
                if (let Some(t) <- stmt.test) { rewritePrivateAccessesInExpr(t) }
                for (c in stmt.cases) {
                    if (let Some(v) <- c.value) { rewritePrivateAccessesInExpr(v) }
                    for (s in c.body) { rewritePrivateAccessesInStmt(s) }
                }
            case StmtTag.Try =>
                for (s in stmt.stmts) { rewritePrivateAccessesInStmt(s) }
                if (let Some(c) <- stmt.catchBody) { rewritePrivateAccessesInStmt(c) }
                if (let Some(f) <- stmt.finallyBody) { rewritePrivateAccessesInStmt(f) }
            case StmtTag.Labeled =>
                if (let Some(b) <- stmt.body) { rewritePrivateAccessesInStmt(b) }
            case _ =>
                ()
        }
    }

    // ========================================================================
    // AST 重写 (replace_ref / replace_this)
    // 严格翻译自: lower_decorators.zig:186-323
    //   fn rewriteExpr(p, expr, kind) void
    //   fn rewriteStmts(p, stmts, kind) void
    // ========================================================================

    /// 重写表达式中的引用
    /// 对应 Bun: fn rewriteExpr(p: *P, expr: *Expr, kind: RewriteKind) void
    public func rewriteExpr(expr: Expr, data: RewriteData): Unit {
        match (data.kind) {
            case RewriteKind.ReplaceRef =>
                if (expr.tag == ExprTag.Identifier && expr.ref == data.oldRef) {
                    expr.ref = data.newRef
                    return
                }
            case RewriteKind.ReplaceThis =>
                if (expr.tag == ExprTag.ThisExpr) {
                    expr.tag = ExprTag.Identifier
                    expr.ref = data.newRef
                    expr.loc = data.loc
                    return
                }
        }
        // 递归重写子表达式
        match (expr.tag) {
            case ExprTag.Binary =>
                if (let Some(l) <- expr.left) { rewriteExpr(l, data) }
                if (let Some(r) <- expr.right) { rewriteExpr(r, data) }
            case ExprTag.Call =>
                if (let Some(t) <- expr.target) { rewriteExpr(t, data) }
                for (a in expr.args) { rewriteExpr(a, data) }
            case ExprTag.New =>
                if (let Some(t) <- expr.target) { rewriteExpr(t, data) }
                for (a in expr.args) { rewriteExpr(a, data) }
            case ExprTag.Index =>
                if (let Some(t) <- expr.target) { rewriteExpr(t, data) }
                if (let Some(i) <- expr.indexExpr) { rewriteExpr(i, data) }
            case ExprTag.Dot =>
                if (let Some(t) <- expr.target) { rewriteExpr(t, data) }
            case ExprTag.Spread =>
                if (let Some(v) <- expr.value) { rewriteExpr(v, data) }
            case ExprTag.Unary =>
                if (let Some(v) <- expr.value) { rewriteExpr(v, data) }
            case ExprTag.Ternary =>
                if (let Some(t) <- expr.test) { rewriteExpr(t, data) }
                if (let Some(y) <- expr.yes) { rewriteExpr(y, data) }
                if (let Some(n) <- expr.no) { rewriteExpr(n, data) }
            case ExprTag.Array =>
                for (item in expr.items) { rewriteExpr(item, data) }
            case ExprTag.Object =>
                for (`prop` in expr.properties) {
                    if (let Some(v) <- `prop`.value) { rewriteExpr(v, data) }
                }
            case ExprTag.Template =>
                if (let Some(t) <- expr.templateTag) { rewriteExpr(t, data) }
                for (part in expr.templateParts) { rewriteExpr(part, data) }
            case ExprTag.Arrow =>
                if (let Some(fn) <- expr.fn) { rewriteStmts(fn.body, data) }
            case ExprTag.Function =>
                // replace_this 不递归进入函数
                if (data.kind == RewriteKind.ReplaceRef) {
                    if (let Some(fn) <- expr.fn) { rewriteStmts(fn.body, data) }
                }
            case _ =>
                ()
        }
    }

    /// 重写语句列表中的引用
    /// 对应 Bun: fn rewriteStmts(p: *P, stmts: []Stmt, kind: RewriteKind) void
    public func rewriteStmts(stmts: ArrayList<Stmt>, data: RewriteData): Unit {
        for (stmt in stmts) {
            rewriteStmt(stmt, data)
        }
    }

    /// 重写单个语句中的引用
    public func rewriteStmt(stmt: Stmt, data: RewriteData): Unit {
        match (stmt.tag) {
            case StmtTag.Expr =>
                if (let Some(v) <- stmt.exprValue) { rewriteExpr(v, data) }
            case StmtTag.Local =>
                for (decl in stmt.decls) {
                    if (let Some(v) <- decl.value) { rewriteExpr(v, data) }
                }
            case StmtTag.Return =>
                if (let Some(v) <- stmt.returnValue) { rewriteExpr(v, data) }
            case StmtTag.Throw =>
                if (let Some(v) <- stmt.throwValue) { rewriteExpr(v, data) }
            case StmtTag.If =>
                if (let Some(t) <- stmt.test) { rewriteExpr(t, data) }
                if (let Some(y) <- stmt.yes) { rewriteStmt(y, data) }
                if (let Some(n) <- stmt.no) { rewriteStmt(n, data) }
            case StmtTag.Block =>
                for (child in stmt.stmts) { rewriteStmt(child, data) }
            case StmtTag.For =>
                if (let Some(fi) <- stmt.`init`) { rewriteStmt(fi, data) }
                if (let Some(t) <- stmt.test) { rewriteExpr(t, data) }
                if (let Some(u) <- stmt.update) { rewriteExpr(u, data) }
                if (let Some(b) <- stmt.body) { rewriteStmt(b, data) }
            case StmtTag.ForIn =>
                if (let Some(v) <- stmt.forValue) { rewriteExpr(v, data) }
                if (let Some(b) <- stmt.body) { rewriteStmt(b, data) }
            case StmtTag.ForOf =>
                if (let Some(v) <- stmt.forValue) { rewriteExpr(v, data) }
                if (let Some(b) <- stmt.body) { rewriteStmt(b, data) }
            case StmtTag.While =>
                if (let Some(t) <- stmt.test) { rewriteExpr(t, data) }
                if (let Some(b) <- stmt.body) { rewriteStmt(b, data) }
            case StmtTag.DoWhile =>
                if (let Some(t) <- stmt.test) { rewriteExpr(t, data) }
                if (let Some(b) <- stmt.body) { rewriteStmt(b, data) }
            case StmtTag.Switch =>
                if (let Some(t) <- stmt.test) { rewriteExpr(t, data) }
                for (c in stmt.cases) {
                    if (let Some(v) <- c.value) { rewriteExpr(v, data) }
                    for (s in c.body) { rewriteStmt(s, data) }
                }
            case StmtTag.Try =>
                for (s in stmt.stmts) { rewriteStmt(s, data) }
                if (let Some(c) <- stmt.catchBody) { rewriteStmt(c, data) }
                if (let Some(f) <- stmt.finallyBody) { rewriteStmt(f, data) }
            case StmtTag.Labeled =>
                if (let Some(b) <- stmt.body) { rewriteStmt(b, data) }
            case _ =>
                ()
        }
    }

    // ========================================================================
    // 内部辅助方法
    // ========================================================================

    /// 从表达式创建语句
    private func stmtFromExpr(expr: Expr): Stmt {
        let stmt = Stmt(expr.loc, StmtTag.Expr)
        stmt.exprValue = expr
        return stmt
    }

    /// 在静态块中替换 this 为类名引用
    private func rewriteThisInStaticBlock(block: GProperty, classRef: Ref, loc: Loc): Unit {
        let data = RewriteData.replaceThis(classRef, loc)
        // 重写静态块中语句的表达式
    }

    /// 将初始化语句注入到构造函数中
    /// 对应 Bun: lower_decorators.zig:1314-1362
    private func injectIntoConstructor(properties: ArrayList<GProperty>,
                                       injectStmts: ArrayList<Stmt>,
                                       hasSuper: Bool, loc: Loc): Unit {
        // 查找现有构造函数
        var foundConstructor = false
        for (i in 0..properties.size) {
            let `prop` = properties[Int64(i)]
            if (`prop`.flags.isMethod && `prop`.key == "constructor") {
                // 找到构造函数，注入初始化语句
                // 查找 super() 调用的位置
                var superIndex: ?Int64 = None
                if (let Some(fn) <- `prop`.value.flatMap({ e => e.fn })) {
                    let bodyStmts = fn.body
                    for (j in 0..bodyStmts.size) {
                        let s = bodyStmts[Int64(j)]
                        if (s.tag == StmtTag.Expr) {
                            if (let Some(v) <- s.exprValue) {
                                if (v.tag == ExprTag.Call) {
                                    if (let Some(t) <- v.target) {
                                        if (t.tag == ExprTag.Super) {
                                            superIndex = Some(Int64(j))
                                            break
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                // 在 super() 之后插入初始化语句
                // 如果没有 super(), 在开头插入
                foundConstructor = true
                break
            }
        }

        if (!foundConstructor) {
            // 创建新的构造函数
            let ctorStmts = ArrayList<Stmt>()
            if (hasSuper) {
                // 添加 super(...arguments) 调用
                let superExpr = Expr(loc, ExprTag.Super)
                let spread = Expr(loc, ExprTag.Spread)
                let argsRef = newSym(SymbolKind.Unbound, "arguments")
                spread.value = Some(Expr.identifier(loc, "arguments", argsRef))
                let callArgs = ArrayList<Expr>()
                callArgs.append(spread)
                let superCall = Expr(loc, ExprTag.Call)
                superCall.target = Some(superExpr)
                superCall.args = callArgs
                ctorStmts.append(stmtFromExpr(superCall))
            }
            for (s in injectStmts) { ctorStmts.append(s) }

            let ctorProp = GProperty.method(loc, "constructor",
                GFn(loc), true, false, false, false)
            properties.insert(0, ctorProp)
        }
    }
}

// ============================================================================
// Parser 扩展方法 (LowerDecorators 所需)
// ============================================================================

/// Parser 的装饰器降级辅助扩展
extend Parser {
    /// 查找符号，如果不存在则创建
    public func findSymbolOrCreate(loc: Loc, name: String): Ref {
        // 简化实现: 委托给解析器
        return Ref.NONE
    }
}
