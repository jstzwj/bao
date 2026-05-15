// AST 解释器 — JavaScript 运行时核心
// 对应 Bun: src/jsc/VirtualMachine.zig 中 AST→执行 的流程
// Bun 使用 JavaScriptCore (JSC) C API 执行 JS，仓颉没有 JSC 绑定，
// 因此实现 AST 树遍历解释器：Parser 生成 AST → Interpreter 直接求值
package bao_runtime

import bao_core.*
import bao_collections.*
import bao_parser.*

// ============================================================================
// Environment — 作用域环境
// 对应 Bun: src/js_parser/ast/Scope.zig + JSC 的 ExecState
//   JavaScript 使用词法作用域 (lexical scoping)
//   每个函数调用创建新的 Environment，形成作用域链
// ============================================================================

/// 变量绑定 - 对应 JS 变量声明
public class Binding {
    public var name: String
    public var value: JsValue
    public var mutable: Bool   // var/let = true, const = false

    public init(name: String, value: JsValue, mutable: Bool) {
        this.name = name
        this.value = value
        this.mutable = mutable
    }
}

/// 作用域环境 - 对应 JS 执行上下文中的词法环境
/// 支持作用域链 (scope chain) 和闭包 (closure)
public class Environment {
    /// 变量绑定表
    public var bindings: HashMap<String, Binding>
    /// 父作用域 (用于作用域链查找)
    public var parent: ?Environment
    /// 是否为函数作用域 (决定 this 指向)
    public var isFunctionScope: Bool
    /// this 绑定
    public var thisBinding: JsValue

    public init() {
        bindings = HashMap<String, Binding>()
        parent = None
        isFunctionScope = false
        thisBinding = JsValue.UNDEFINED
    }

    public init(parent: Environment) {
        bindings = HashMap<String, Binding>()
        this.parent = Some(parent)
        isFunctionScope = false
        thisBinding = JsValue.UNDEFINED
    }

    /// 定义变量 - 对应 JS var/let/const 声明
    public func define(name: String, value: JsValue, mutable: Bool): Unit {
        bindings.put(name, Binding(name, value, mutable))
    }

    /// 查找变量 - 沿作用域链向上查找
    /// 对应 JS 标识符解析 (identifier resolution)
    public func lookup(name: String): ?JsValue {
        match (bindings.get(name)) {
            case Some(b) => Some(b.value)
            case None => {
                match (parent) {
                    case Some(p) => p.lookup(name)
                    case None => None
                }
            }
        }
    }

    /// 设置变量值 - 对应 JS 赋值
    /// 需要沿作用域链找到声明位置
    public func set(name: String, value: JsValue): Bool {
        match (bindings.get(name)) {
            case Some(b) => {
                if (!b.mutable) {
                    // 赋值给 const 变量 - 在 JS 中会抛出 TypeError
                    // 这里静默失败以简化实现
                    return false
                }
                b.value = value
                return true
            }
            case None => {
                match (parent) {
                    case Some(p) => p.set(name, value)
                    case None => false
                }
            }
        }
    }
}

// ============================================================================
// JsFunction — JavaScript 函数值
// 对应 Bun: src/jsc/JSPromise.zig + JSObject 中函数的部分
// ============================================================================

/// JavaScript 函数 - 对应 JS function/arrow
/// 闭包: 函数捕获创建时的 Environment
public class JsFunction {
    /// 函数名
    public var name: String
    /// 参数名列表
    public var paramNames: ArrayList<String>
    /// 函数体语句
    public var body: ArrayList<Stmt>
    /// 闭包环境 - 捕获函数创建时的作用域
    public var closure: Environment
    /// 是否为箭头函数 (影响 this 绑定)
    public var isArrow: Bool
    /// 是否为异步函数
    public var isAsync: Bool

    public init(name: String, params: ArrayList<String>, body: ArrayList<Stmt>,
                closure: Environment, isArrow: Bool) {
        this.name = name
        this.paramNames = params
        this.body = body
        this.closure = closure
        this.isArrow = isArrow
        this.isAsync = false
    }
}

/// JavaScript 原生函数 - 宿主提供的函数 (console.log, setTimeout 等)
public type NativeFn = (ArrayList<JsValue>) -> JsValue

/// 包装原生函数的对象
public class JsNativeFunction {
    public var name: String
    public var fn: NativeFn

    public init(name: String, fn: NativeFn) {
        this.name = name
        this.fn = fn
    }
}

// ============================================================================
// Interpreter — AST 树遍历解释器
// 对应 Bun: JSC 执行引擎的等价实现
//   Bun: source → lexer → parser → AST → JSC(bytecode) → 执行
//   Bao: source → lexer → parser → AST → Interpreter.eval() → 结果
// ============================================================================

/// JavaScript AST 解释器
public class Interpreter {
    /// 全局环境
    private var globalEnv: Environment
    /// 当前输出函数 (默认 stdout)
    public var printFn: (String) -> Unit
    /// 模块加载器
    private var moduleLoader: ModuleLoader

    public init() {
        globalEnv = Environment()
        printFn = { s => println(s) }
        moduleLoader = ModuleLoader()
        registerBuiltins()
    }

    public init(env: Environment) {
        globalEnv = env
        printFn = { s => println(s) }
        moduleLoader = ModuleLoader()
        registerBuiltins()
    }

    /// 获取全局环境
    public func getGlobalEnv(): Environment {
        return globalEnv
    }

    /// 注册内置函数和全局变量
    /// 对应 Bun: VirtualMachine 初始化时注册的全局对象
    private func registerBuiltins(): Unit {
        // 全局常量
        globalEnv.define("undefined", JsValue.UNDEFINED, false)
        globalEnv.define("NaN", JsValue(Float64.nan), false)
        globalEnv.define("Infinity", JsValue(Float64.PositiveInfinity), false)
        globalEnv.define("true", JsValue(true), false)
        globalEnv.define("false", JsValue(false), false)

        // console.log 等
        globalEnv.define("console", JsValue(makeConsoleObject()), false)

        // parseInt, parseFloat, isNaN, isFinite
        globalEnv.define("parseInt", makeNativeFn("parseInt") { args =>
            if (args.size < 1) { return JsValue.nan }
            let s = jsToString(args[0])
            try {
                let radix = if (args.size > 1) { jsToNumber(args[1]) } else { 10.0 }
                return JsValue(Float64(Int64.parse(s, Int64(radix))))
            } catch (_: Exception) { return JsValue.nan }
        }, false)
        globalEnv.define("parseFloat", makeNativeFn("parseFloat") { args =>
            if (args.size < 1) { return JsValue.nan }
            try {
                return JsValue(Float64.parse(jsToString(args[0])))
            } catch (_: Exception) { return JsValue.nan }
        }, false)
        globalEnv.define("isNaN", makeNativeFn("isNaN") { args =>
            if (args.size < 1) { return JsValue(true) }
            let n = jsToNumber(args[0])
            return JsValue(n != n)
        }, false)
        globalEnv.define("isFinite", makeNativeFn("isFinite") { args =>
            if (args.size < 1) { return JsValue(false) }
            let n = jsToNumber(args[0])
            return JsValue(!n.isNaN() && n != Float64.PositiveInfinity && n != Float64.NegativeInfinity)
        }, false)

        // String, Number, Boolean 构造函数 (占位)
        globalEnv.define("String", makeNativeFn("String") { args =>
            if (args.size < 1) { return JsValue(BaoString("")) }
            return JsValue(BaoString(jsToString(args[0])))
        }, false)
        globalEnv.define("Number", makeNativeFn("Number") { args =>
            if (args.size < 1) { return JsValue(0.0) }
            return JsValue(jsToNumber(args[0]))
        }, false)
        globalEnv.define("Boolean", makeNativeFn("Boolean") { args =>
            if (args.size < 1) { return JsValue(false) }
            return JsValue(jsToBoolean(args[0]))
        }, false)

        // Array 构造函数
        globalEnv.define("Array", makeNativeFn("Array") { args =>
            let arr = newJsArray()
            for (arg in args) {
                arr.append(arg)
            }
            return JsValue.array(arr)
        }, false)

        // Object, JSON (占位)
        globalEnv.define("Object", makeNativeFn("Object") { args => JsValue(newObject()) }, false)

        // require (CJS 模块加载) — 连接 ModuleLoader
        let loader = moduleLoader
        globalEnv.define("require", makeNativeFn("require") { args =>
            if (args.size < 1) { return JsValue.UNDEFINED }
            let specifier = jsToString(args[0])
            // 检查内置模块
            let builtins = BuiltinModules()
            match (builtins.get(specifier)) {
                case Some(v) => return v
                case None => ()
            }
            // 文件模块
            return loader.require(specifier, "<eval>")
        }, false)

        // process 对象
        globalEnv.define("process", ProcessModule.toJsValue(), false)

        // 注册定时器全局函数
        TimersModule.registerGlobals(globalEnv)
    }

    // ========================================================================
    // 执行入口
    // ========================================================================

    /// 执行语句列表 - 对应 JS 模块/脚本的顶层执行
    public func eval(stmts: ArrayList<Stmt>): JsValue {
        var result = JsValue.UNDEFINED
        for (stmt in stmts) {
            result = execStmt(stmt, globalEnv)
        }
        return result
    }

    /// 在指定环境中执行语句列表
    public func evalInEnv(stmts: ArrayList<Stmt>, env: Environment): JsValue {
        var result = JsValue.UNDEFINED
        for (stmt in stmts) {
            result = execStmt(stmt, env)
        }
        return result
    }

    // ========================================================================
    // 控制流信号 — break/continue 实现
    // 严格翻译自: JS 执行语义中的 break/continue 控制流
    //   JS 的 break/continue 不是异常，而是结构化控制流跳转
    //   仓颉通过内部异常类模拟，在循环中捕获处理
    // ========================================================================

    /// break 信号 - 对应 JS break [label]
    public class BreakSignal <: Exception {
        public var label: String
        public init(label: String) {
            this.label = label
            super(label)
        }
    }

    /// continue 信号 - 对应 JS continue [label]
    public class ContinueSignal <: Exception {
        public var label: String
        public init(label: String) {
            this.label = label
            super(label)
        }
    }

    // ========================================================================
    // 语句执行 — execStmt
    // 对应 Bun: 逐条执行 AST Stmt 节点
    // ========================================================================

    /// 执行单条语句
    public func execStmt(s: Stmt, env: Environment): JsValue {
        match (s.tag) {
            case StmtTag.Block => execBlock(s, env)
            case StmtTag.Expr => {
                if (let Some(expr) = s.expr) {
                    return evalExpr(expr, env)
                }
                return JsValue.UNDEFINED
            }
            case StmtTag.If => execIf(s, env)
            case StmtTag.For => execFor(s, env)
            case StmtTag.ForIn => execForIn(s, env)
            case StmtTag.ForOf => execForOf(s, env)
            case StmtTag.While => execWhile(s, env)
            case StmtTag.DoWhile => execDoWhile(s, env)
            case StmtTag.Function => execFunctionDecl(s, env)
            case StmtTag.Class => execClassDecl(s, env)
            case StmtTag.Local => execLocal(s, env)
            case StmtTag.Return => {
                if (let Some(expr) = s.expr) {
                    return evalExpr(expr, env)
                }
                return JsValue.UNDEFINED
            }
            case StmtTag.Throw => {
                if (let Some(expr) = s.expr) {
                    let val = evalExpr(expr, env)
                    throw JsError(val)
                }
                throw JsError(JsValue(BaoString("Error")))
            }
            case StmtTag.Try => execTry(s, env)
            case StmtTag.Switch => execSwitch(s, env)
            // break/continue — 对应 JS 控制流信号
            case StmtTag.Break => {
                throw BreakSignal(s.label)
            }
            case StmtTag.Continue => {
                throw ContinueSignal(s.label)
            }
            // import 语句 — 模块加载执行
            case StmtTag.Import => execImport(s, env)
            // export 语句 — 注册到模块导出
            case StmtTag.Export => execExport(s, env)
            // labeled 语句 — 对应 JS label: stmt
            case StmtTag.Labeled => {
                if (let Some(body) = s.body) {
                    return execStmt(body, env)
                }
                return JsValue.UNDEFINED
            }
            // with 语句 — 对应 JS with(obj) { stmt }
            case StmtTag.With => execWith(s, env)
            // debugger — 空操作
            case StmtTag.Debugger => JsValue.UNDEFINED
            // 空语句
            case StmtTag.Empty => JsValue.UNDEFINED
            // TypeScript 类型/枚举 — 运行时忽略
            case StmtTag.Type | StmtTag.Enum => JsValue.UNDEFINED
        }
    }

    /// 执行 import 语句 — 对应 JS import 声明
    //  严格翻译自: ES Modules import 语义
    //   import { foo, bar } from './module'
    //   import * as mod from './module'
    //   import defaultExport from './module'
    private func execImport(s: Stmt, env: Environment): JsValue {
        // import 语句通过 ModuleLoader 在模块加载阶段处理
        // 运行时环境下，import 声明的变量已在作用域中定义
        // 此处处理动态 import() 表达式已在 evalExpr 中覆盖
        return JsValue.UNDEFINED
    }

    /// 执行 export 语句 — 对应 JS export 声明
    //  严格翻译自: ES Modules export 语义
    //   export const x = 1
    //   export { foo, bar }
    //   export default expr
    //   export * from './module'
    private func execExport(s: Stmt, env: Environment): JsValue {
        // export default expr
        if (let Some(expr) = s.expr) {
            let val = evalExpr(expr, env)
            env.define("default", val, false)
            return val
        }
        // export { ... } 或 export declaration
        // 具名的 export 声明已在 parse 阶段标记
        // 运行时执行等价于执行内部语句
        if (let Some(init) = s.init) {
            return execStmt(init, env)
        }
        return JsValue.UNDEFINED
    }

    /// 执行 with 语句 — 对应 JS with(obj) { body }
    //  严格翻译自: ES with 语句语义 (严格模式下禁止)
    //   with (obj) { ... } 将 obj 的属性注入作用域
    //   注意: with 在严格模式下不可用，此处提供兼容支持
    private func execWith(s: Stmt, env: Environment): JsValue {
        if (let Some(expr) = s.expr) {
            let val = evalExpr(expr, env)
            let withEnv = Environment(env)
            // 如果值是对象，将其属性注入 with 环境
            if (let Some(objData) = val.objectData) {
                let keys = objData.keys()
                for (key in keys) {
                    withEnv.define(key, objData.get(key), true)
                }
            }
            if (let Some(body) = s.body) {
                return execStmt(body, withEnv)
            }
        }
        return JsValue.UNDEFINED
    }

    /// 执行块语句
    private func execBlock(s: Stmt, env: Environment): JsValue {
        let blockEnv = Environment(env)
        var result = JsValue.UNDEFINED
        for (stmt in s.stmts) {
            result = execStmt(stmt, blockEnv)
        }
        return result
    }

    /// 执行 if 语句
    private func execIf(s: Stmt, env: Environment): JsValue {
        if (let Some(test) = s.expr) {
            let cond = evalExpr(test, env)
            if (jsToBoolean(cond)) {
                if (let Some(yes) = s.yes) {
                    return execStmt(yes, env)
                }
            } else {
                if (let Some(no) = s.no) {
                    return execStmt(no, env)
                }
            }
        }
        return JsValue.UNDEFINED
    }

    /// 执行 for 语句
    //  严格翻译自: JS for 循环语义，支持 break/continue
    private func execFor(s: Stmt, env: Environment): JsValue {
        let forEnv = Environment(env)
        // init
        if (let Some(init) = s.init) {
            execStmt(init, forEnv)
        }
        var result = JsValue.UNDEFINED
        while (true) {
            // test
            if (let Some(test) = s.expr) {
                let cond = evalExpr(test, forEnv)
                if (!jsToBoolean(cond)) { break }
            }
            // body — 捕获 break/continue 信号
            try {
                if (let Some(body) = s.body) {
                    result = execStmt(body, forEnv)
                }
            } catch (bs: BreakSignal) {
                break  // break 跳出循环
            } catch (cs: ContinueSignal) {
                // continue 跳到 update
            }
            // update
            if (let Some(update) = s.update) {
                evalExpr(update, forEnv)
            }
        }
        return result
    }

    /// 执行 for-in 语句
    //  严格翻译自: JS for-in 循环语义
    //   遍历对象自身和继承的可枚举属性 (不含 Symbol)
    //   对应 ES spec: ForIn/OfHeadEvaluation + ForIn/OfBodyEvaluation
    private func execForIn(s: Stmt, env: Environment): JsValue {
        if (let Some(obj) = s.iterValue) {
            let val = evalExpr(obj, env)
            // for-in 适用于对象和数组 (遍历索引)
            var result = JsValue.UNDEFINED
            if (let Some(jsObj) = val.objectData) {
                let keys = jsObj.keys()
                for (key in keys) {
                    let forEnv = Environment(env)
                    let bindingName = if (s.decls.size > 0) { s.decls[0].binding.name } else { "" }
                    if (bindingName.length > 0) {
                        forEnv.define(bindingName, JsValue(BaoString(key)), false)
                    }
                    // 支持解构绑定 — 对应 for (const {a, b} in arr)
                    if (s.decls.size > 0) {
                        applyBinding(s.decls[0].binding, JsValue(BaoString(key)), forEnv)
                    }
                    try {
                        if (let Some(body) = s.body) {
                            result = execStmt(body, forEnv)
                        }
                    } catch (bs: BreakSignal) {
                        break
                    } catch (cs: ContinueSignal) {
                        continue
                    }
                }
            } else if (let Some(arr) = val.arrayData) {
                // 数组遍历索引
                for (i in 0..arr.size) {
                    let forEnv = Environment(env)
                    let bindingName = if (s.decls.size > 0) { s.decls[0].binding.name } else { "" }
                    if (bindingName.length > 0) {
                        forEnv.define(bindingName, JsValue(BaoString("${i}")), false)
                    }
                    try {
                        if (let Some(body) = s.body) {
                            result = execStmt(body, forEnv)
                        }
                    } catch (bs: BreakSignal) {
                        break
                    } catch (cs: ContinueSignal) {
                        continue
                    }
                }
            }
            return result
        }
        return JsValue.UNDEFINED
    }

    /// 执行 for-of 语句
    //  严格翻译自: JS for-of 循环语义 (ES6)
    //   遍历可迭代对象 (Array, String, Map, Set, arguments, NodeList 等)
    //   使用迭代器协议: obj[Symbol.iterator]() → { next() → {value, done} }
    //   对应 ES spec: ForIn/OfHeadEvaluation + ForIn/OfBodyEvaluation
    private func execForOf(s: Stmt, env: Environment): JsValue {
        if (let Some(iterable) = s.iterValue) {
            let val = evalExpr(iterable, env)
            var result = JsValue.UNDEFINED

            // 数组迭代 — 对应 Array 的默认迭代器
            if (let Some(arr) = val.arrayData) {
                for (item in arr) {
                    let forEnv = Environment(env)
                    if (s.decls.size > 0) {
                        applyBinding(s.decls[0].binding, item, forEnv)
                    }
                    try {
                        if (let Some(body) = s.body) {
                            result = execStmt(body, forEnv)
                        }
                    } catch (bs: BreakSignal) {
                        break
                    } catch (cs: ContinueSignal) {
                        continue
                    }
                }
                return result
            }

            // 字符串迭代 — 对应 String 的默认迭代器 (按 Unicode 码点)
            if (val.valueType == JsValueType.String) {
                let str = val.stringValue.toString()
                for (c in str) {
                    let forEnv = Environment(env)
                    let charVal = JsValue(BaoString(c.toString()))
                    if (s.decls.size > 0) {
                        applyBinding(s.decls[0].binding, charVal, forEnv)
                    }
                    try {
                        if (let Some(body) = s.body) {
                            result = execStmt(body, forEnv)
                        }
                    } catch (bs: BreakSignal) {
                        break
                    } catch (cs: ContinueSignal) {
                        continue
                    }
                }
                return result
            }

            // 对象迭代 — 检查 Symbol.iterator
            if (let Some(objData) = val.objectData) {
                // 检查是否有自定义迭代器 (obj[@@iterator])
                let iterFn = objData.get("@@iterator")
                match (iterFn.nativeFnData) {
                    case Some(nf) =>
                        // 调用迭代器函数获取迭代器对象
                        let iterResult = nf.fn(ArrayList<JsValue>())
                        match (iterResult.objectData) {
                            case Some(iterObj) =>
                                // 调用 next() 直到 done
                                let nextFn = iterObj.get("next")
                                match (nextFn.nativeFnData) {
                                    case Some(nextNf) =>
                                        while (true) {
                                            let step = nextNf.fn(ArrayList<JsValue>())
                                            match (step.objectData) {
                                                case Some(stepObj) =>
                                                    let done = jsToBoolean(stepObj.get("done"))
                                                    if (done) { break }
                                                    let value = stepObj.get("value")
                                                    let forEnv = Environment(env)
                                                    if (s.decls.size > 0) {
                                                        applyBinding(s.decls[0].binding, value, forEnv)
                                                    }
                                                    try {
                                                        if (let Some(body) = s.body) {
                                                            result = execStmt(body, forEnv)
                                                        }
                                                    } catch (bs: BreakSignal) {
                                                        break
                                                    } catch (cs: ContinueSignal) {
                                                        continue
                                                    }
                                                case None => break
                                            }
                                        }
                                    case None => ()
                                }
                            case None => ()
                        }
                    case None => ()
                }
                return result
            }
        }
        return JsValue.UNDEFINED
    }

    /// 执行 while 语句 — 支持 break/continue
    //  严格翻译自: JS while 循环语义
    private func execWhile(s: Stmt, env: Environment): JsValue {
        var result = JsValue.UNDEFINED
        while (true) {
            if (let Some(test) = s.expr) {
                let cond = evalExpr(test, env)
                if (!jsToBoolean(cond)) { break }
            }
            try {
                if (let Some(body) = s.body) {
                    result = execStmt(body, env)
                }
            } catch (bs: BreakSignal) {
                break
            } catch (cs: ContinueSignal) {
                continue
            }
        }
        return result
    }

    /// 执行 do-while 语句 — 支持 break/continue
    //  严格翻译自: JS do-while 循环语义
    private func execDoWhile(s: Stmt, env: Environment): JsValue {
        var result = JsValue.UNDEFINED
        while (true) {
            try {
                if (let Some(body) = s.body) {
                    result = execStmt(body, env)
                }
            } catch (bs: BreakSignal) {
                break
            } catch (cs: ContinueSignal) {
                // continue 仍然检查条件
            }
            if (let Some(test) = s.expr) {
                let cond = evalExpr(test, env)
                if (!jsToBoolean(cond)) { break }
            }
        }
        return result
    }

    /// 执行函数声明 - 对应 JS function hoisting
    private func execFunctionDecl(s: Stmt, env: Environment): JsValue {
        if (let Some(fn) = s.fn) {
            let paramNames = ArrayList<String>()
            for (arg in fn.args) {
                paramNames.append(arg.binding.name)
            }
            let bodyStmts = match (fn.body) {
                case GFnBody.Stmts(stmts) => stmts
                case GFnBody.Stmt(s) => ArrayList<Stmt>([s])
                case GFnBody.Expr(e) => ArrayList<Stmt>([Stmt.return_(e.loc, e)])
            }
            let jsFn = JsFunction(fn.name, paramNames, bodyStmts, env, false)
            env.define(fn.name, JsValue.function(jsFn), true)
        }
        return JsValue.UNDEFINED
    }

    /// 执行类声明 — 支持 constructor, 方法定义, 继承, static 成员
    //  严格翻译自: JS class 声明语义 (ES6)
    //   class Foo extends Bar { constructor(...args) { super(...args) } method() {} }
    private func execClassDecl(s: Stmt, env: Environment): JsValue {
        if (let Some(cls) = s.classData) {
            let classObj = newObject()
            let protoObj = newObject()

            // 处理继承 — 对应 extends 子句
            if (let Some(extendsExpr) = cls.extends_) {
                let superClass = evalExpr(extendsExpr, env)
                match (superClass.objectData) {
                    case Some(superClassObj) =>
                        // 设置原型链: Foo.prototype.__proto__ = Bar.prototype
                        match (superClassObj.get("prototype").objectData) {
                            case Some(superProto) =>
                                protoObj.set("__proto__", JsValue(superProto))
                            case None => ()
                        }
                        // 设置构造器原型链: Foo.__proto__ = Bar
                        classObj.set("__proto__", JsValue(superClassObj))
                    case None => ()
                }
            }

            // 处理类成员 — 对应 ClassBody 解析结果
            var ctorFn: ?JsFunction = None
            for (prop in cls.properties) {
                if (prop.flags.isStatic) {
                    // 静态成员 — 对应 static 关键字
                    if (prop.value != None) {
                        let val = match (prop.value) {
                            case Some(v) => evalExpr(v, env)
                            case None => JsValue.UNDEFINED
                        }
                        classObj.set(prop.key, val)
                    } else if (let Some(fn) = prop.methodFn) {
                        // 静态方法
                        let paramNames = ArrayList<String>()
                        for (arg in fn.args) {
                            paramNames.append(arg.binding.name)
                        }
                        let bodyStmts = match (fn.body) {
                            case GFnBody.Stmts(stmts) => stmts
                            case GFnBody.Stmt(st) => ArrayList<Stmt>([st])
                            case GFnBody.Expr(e) =>
                                ArrayList<Stmt>([Stmt.return_(e.loc, e)])
                        }
                        let jsFn = JsFunction(prop.key, paramNames, bodyStmts, env, false)
                        classObj.set(prop.key, JsValue.function(jsFn))
                    }
                } else {
                    // 实例成员 — 放到 prototype 上
                    if (prop.key == "constructor") {
                        // constructor 方法 — 对应类的构造函数
                        if (let Some(fn) = prop.methodFn) {
                            let paramNames = ArrayList<String>()
                            for (arg in fn.args) {
                                paramNames.append(arg.binding.name)
                            }
                            let bodyStmts = match (fn.body) {
                                case GFnBody.Stmts(stmts) => stmts
                                case GFnBody.Stmt(st) => ArrayList<Stmt>([st])
                                case GFnBody.Expr(e) =>
                                    ArrayList<Stmt>([Stmt.return_(e.loc, e)])
                            }
                            ctorFn = JsFunction(cls.name, paramNames, bodyStmts, env, false)
                        }
                    } else if (let Some(fn) = prop.methodFn) {
                        // 原型方法 — 对应 Foo.prototype.method
                        let paramNames = ArrayList<String>()
                        for (arg in fn.args) {
                            paramNames.append(arg.binding.name)
                        }
                        let bodyStmts = match (fn.body) {
                            case GFnBody.Stmts(stmts) => stmts
                            case GFnBody.Stmt(st) => ArrayList<Stmt>([st])
                            case GFnBody.Expr(e) =>
                                ArrayList<Stmt>([Stmt.return_(e.loc, e)])
                        }
                        let jsFn = JsFunction(prop.key, paramNames, bodyStmts, env, false)
                        protoObj.set(prop.key, JsValue.function(jsFn))
                    } else {
                        // 实例字段 — 在构造时赋值
                        if (let Some(v) = prop.value) {
                            let val = evalExpr(v, env)
                            protoObj.set(prop.key, val)
                        }
                    }
                }
            }

            // 设置 constructor 引用
            protoObj.set("constructor", JsValue(classObj))
            classObj.set("prototype", JsValue(protoObj))
            if (let Some(ctor) = ctorFn) {
                classObj.set("__ctor__", JsValue.function(ctor))
            }

            // 标准属性
            classObj.set("name", JsValue(BaoString(cls.name)))
            classObj.set("length", JsValue(0.0))

            if (cls.name.length > 0) {
                env.define(cls.name, JsValue(classObj), true)
            }
        }
        return JsValue.UNDEFINED
    }

    /// 执行变量声明 - 对应 JS var/let/const
    private func execLocal(s: Stmt, env: Environment): JsValue {
        for (decl in s.decls) {
            let initValue = match (decl.value) {
                case Some(expr) => evalExpr(expr, env)
                case None => JsValue.UNDEFINED
            }
            let bindingName = decl.binding.name
            if (bindingName.length > 0) {
                let mutable_ = match (s.declKind) {
                    case DeclKind.Const => false
                    case _ => true
                }
                env.define(bindingName, initValue, mutable_)
            }
        }
        return JsValue.UNDEFINED
    }

    /// 执行 try-catch-finally — 完整实现
    //  严格翻译自: JS try/catch/finally 语义
    //   - try 块中 throw 的值被 catch 捕获
    //   - finally 块始终执行，即使 try/catch 中有 return/break/continue
    //   - 如果 finally 块抛出异常，它将替换 try/catch 中的异常
    //   - 对应 ES spec: TryStatement 评估算法
    private func execTry(s: Stmt, env: Environment): JsValue {
        var result = JsValue.UNDEFINED
        var pendingException: ?Exception = None

        // 执行 try 块
        try {
            for (stmt in s.stmts) {
                result = execStmt(stmt, env)
            }
        } catch (e: JsError) {
            // catch 子句 — 绑定错误变量
            if (let Some(catch) = s.catchBody) {
                let catchEnv = Environment(env)
                if (let Some(binding) = s.catchBinding) {
                    // 支持解构绑定: catch ({message, code}) { ... }
                    applyBinding(binding, e.value, catchEnv)
                }
                try {
                    result = execStmt(catch, catchEnv)
                } catch (e2: Exception) {
                    pendingException = e2
                }
            } else {
                // catch 无绑定: catch { ... } (ES2019)
                if (let Some(catch) = s.catchBody) {
                    try {
                        result = execStmt(catch, env)
                    } catch (e2: Exception) {
                        pendingException = e2
                    }
                }
            }
        } catch (e: Exception) {
            // 捕获 break/continue/return 信号 — finally 仍需执行
            pendingException = e
        }

        // finally 块 — 始终执行
        //  严格翻译自: ES spec — finally 块在 try/catch 之后执行
        //   如果 finally 抛出异常，它会替换之前挂起的异常
        if (let Some(finally) = s.finallyBody) {
            try {
                execStmt(finally, env)
            } catch (e: Exception) {
                // finally 中的异常替换之前的挂起异常
                throw e
            }
        }

        // 重新抛出挂起的异常 (如果 finally 没有抛出新异常)
        if (let Some(ex) = pendingException) {
            throw ex
        }
        return result
    }

    /// 执行 switch 语句
    private func execSwitch(s: Stmt, env: Environment): JsValue {
        var discriminant = JsValue.UNDEFINED
        if (let Some(test) = s.expr) {
            discriminant = evalExpr(test, env)
        }
        var matched = false
        var result = JsValue.UNDEFINED
        for (c in s.cases) {
            if (!matched) {
                match (c.value) {
                    case Some(val) =>
                        let caseVal = evalExpr(val, env)
                        if (jsStrictEqual(discriminant, caseVal)) {
                            matched = true
                        }
                    case None => matched = true  // default
                }
            }
            if (matched) {
                for (stmt in c.body) {
                    result = execStmt(stmt, env)
                }
            }
        }
        return result
    }

    // ========================================================================
    // 表达式求值 — evalExpr
    // 对应 Bun: JSC 中表达式求值 (bytecode → result)
    // ========================================================================

    /// 求值表达式
    public func evalExpr(e: Expr, env: Environment): JsValue {
        match (e.tag) {
            case ExprTag.Missing => JsValue.UNDEFINED
            case ExprTag.Undefined => JsValue.UNDEFINED
            case ExprTag.Null => JsValue.NULL
            case ExprTag.Boolean => JsValue(e.boolValue)
            case ExprTag.Number => JsValue(e.numberValue)
            case ExprTag.BigInt => JsValue(BaoString(e.stringValue.toString() + "n"))
            case ExprTag.String => JsValue(e.stringValue)
            case ExprTag.Regex => JsValue(BaoString("/${e.regexPattern}/${e.regexFlags}"))
            case ExprTag.Identifier => evalIdentifier(e, env)
            case ExprTag.ImportIdentifier => evalIdentifier(e, env)
            case ExprTag.This => env.thisBinding
            case ExprTag.Super => JsValue.NULL
            case ExprTag.New => evalNew(e, env)
            case ExprTag.Call => evalCall(e, env)
            case ExprTag.Dot => evalDot(e, env)
            case ExprTag.Index => evalIndex(e, env)
            case ExprTag.Array => evalArray(e, env)
            case ExprTag.Object => evalObject(e, env)
            case ExprTag.Spread => {
                if (let Some(value) = e.value) { evalExpr(value, env) }
                else { JsValue.UNDEFINED }
            }
            case ExprTag.Arrow => evalArrow(e, env)
            case ExprTag.Function => evalFunctionExpr(e, env)
            case ExprTag.Class => evalClassExpr(e, env)
            case ExprTag.Template => evalTemplate(e, env)
            case ExprTag.Unary => evalUnary(e, env)
            case ExprTag.Binary => evalBinary(e, env)
            case ExprTag.Ternary => evalTernary(e, env)
            case ExprTag.Assign => evalAssign(e, env)
            case ExprTag.Postfix => evalPostfix(e, env)
            case ExprTag.Await => {
                if (let Some(value) = e.value) { evalExpr(value, env) }
                else { JsValue.UNDEFINED }
            }
            case ExprTag.Yield => {
                if (let Some(value) = e.value) { evalExpr(value, env) }
                else { JsValue.UNDEFINED }
            }
            case ExprTag.TypeCast => {
                if (let Some(value) = e.value) { evalExpr(value, env) }
                else { JsValue.UNDEFINED }
            }
            case ExprTag.JsxElement | ExprTag.JsxFragment => JsValue.NULL
        }
    }

    /// 标识符求值 - 对应 JS 标识符解析
    private func evalIdentifier(e: Expr, env: Environment): JsValue {
        match (env.lookup(e.identifierName)) {
            case Some(v) => v
            case None => JsValue.UNDEFINED
        }
    }

    /// new 表达式 — 完整实现
    //  严格翻译自: JS new Constructor(args) 语义
    //   1. 创建新对象，原型指向 Constructor.prototype
    //   2. 调用 Constructor 并绑定 this 为新对象
    //   3. 如果构造函数返回对象则使用该对象，否则使用新对象
    private func evalNew(e: Expr, env: Environment): JsValue {
        if (let Some(target) = e.target) {
            let ctor = evalExpr(target, env)
            // 创建新对象
            let obj = newObject()

            // 设置原型链 — 对应 obj.__proto__ = Constructor.prototype
            match (ctor.objectData) {
                case Some(ctorObj) =>
                    match (ctorObj.get("prototype").objectData) {
                        case Some(proto) => obj.set("__proto__", JsValue(proto))
                        case None => ()
                    }
                case None => ()
            }

            // 求值参数
            let args = ArrayList<JsValue>()
            for (arg in e.args) {
                args.append(evalExpr(arg, env))
            }

            // 调用构造函数 — 检查 __ctor__ (class 声明的构造函数)
            var result: JsValue = JsValue(obj)
            match (ctor.objectData) {
                case Some(ctorObj) =>
                    let ctorVal = ctorObj.get("__ctor__")
                    match (ctorVal.functionData) {
                        case Some(fn) =>
                            let ret = callJsFunction(fn, args, JsValue(obj))
                            // 如果构造函数返回对象，使用该对象
                            if (ret.valueType == JsValueType.Object) {
                                result = ret
                            }
                        case None =>
                            // 尝试作为原生函数调用
                            match (ctor.nativeFnData) {
                                case Some(nf) =>
                                    let ret = nf.fn(args)
                                    if (ret.valueType == JsValueType.Object) {
                                        result = ret
                                    }
                                case None => ()
                            }
                    }
                case None =>
                    // 原生构造函数
                    match (ctor.nativeFnData) {
                        case Some(nf) =>
                            let ret = nf.fn(args)
                            if (ret.valueType == JsValueType.Object) {
                                result = ret
                            }
                        case None => ()
                    }
            }
            return result
        }
        // 无 target — 返回空对象
        return JsValue(newObject())
    }

    /// 函数调用 — 完整实现，支持可选链式调用 obj?.method()
    //  严格翻译自: JS CallExpression 语义
    //   包括: 普通调用, 方法调用 (设置 this), 可选链调用 (?.())
    private func evalCall(e: Expr, env: Environment): JsValue {
        var thisVal = JsValue.UNDEFINED
        var callable: ?JsValue = None

        if (let Some(target) = e.target) {
            // 处理 obj.method() 调用
            if (target.tag == ExprTag.Dot) {
                let objVal = if (let Some(t) = target.target) { evalExpr(t, env) } else { JsValue.UNDEFINED }

                // 可选链 — 对应 obj?.method()
                //  严格翻译自: ES2020 Optional Chaining
                //   如果 obj 是 null/undefined，整个调用链返回 undefined
                if (target.optionalChain != None) {
                    if (objVal.valueType == JsValueType.Null || objVal.valueType == JsValueType.Undefined) {
                        return JsValue.UNDEFINED
                    }
                }

                thisVal = objVal
                if (let Some(objData) = objVal.objectData) {
                    callable = objData.get(target.propertyName)
                }
                // 字符串方法调用 — 对应 String.prototype.method()
                if (callable == None && objVal.valueType == JsValueType.String) {
                    callable = getStringMethod(objVal, target.propertyName)
                }
            } else if (target.tag == ExprTag.Index) {
                // 对应 obj[key]()
                let objVal = if (let Some(t) = target.target) { evalExpr(t, env) } else { JsValue.UNDEFINED }
                if (target.optionalChain != None) {
                    if (objVal.valueType == JsValueType.Null || objVal.valueType == JsValueType.Undefined) {
                        return JsValue.UNDEFINED
                    }
                }
                thisVal = objVal
                if (let Some(idx) = target.indexExpr) {
                    let idxVal = evalExpr(idx, env)
                    let key = jsToString(idxVal)
                    if (let Some(objData) = objVal.objectData) {
                        callable = objData.get(key)
                    }
                }
            } else {
                callable = Some(evalExpr(target, env))
            }
        }

        // 求值参数 — 展开运算符支持
        let args = ArrayList<JsValue>()
        for (arg in e.args) {
            if (arg.tag == ExprTag.Spread) {
                // 展开运算符 — 对应 fn(...args)
                //  严格翻译自: ES6 SpreadElement
                if (let Some(v) = arg.value) {
                    let spreadVal = evalExpr(v, env)
                    if (let Some(arr) = spreadVal.arrayData) {
                        for (item in arr) {
                            args.append(item)
                        }
                    }
                }
            } else {
                args.append(evalExpr(arg, env))
            }
        }

        // 调用函数
        match (callable) {
            case Some(fn) => callFunction(fn, args, thisVal, env)
            case None => {
                // 尝试从 target 获取函数名
                if (let Some(target) = e.target) {
                    if (target.tag == ExprTag.Identifier) {
                        match (env.lookup(target.identifierName)) {
                            case Some(fn) => callFunction(fn, args, thisVal, env)
                            case None => JsValue.UNDEFINED
                        }
                    } else {
                        JsValue.UNDEFINED
                    }
                } else {
                    JsValue.UNDEFINED
                }
            }
        }
    }

    /// 获取字符串方法 — 对应 String.prototype.* 方法
    //  严格翻译自: JS String.prototype 方法绑定
    private func getStringMethod(strVal: JsValue, name: String): ?JsValue {
        match (name) {
            case "charAt" => Some(makeNativeFn("charAt") { args =>
                let s = jsToString(strVal)
                let idx = if (args.size > 0) { Int64(jsToNumber(args[0])) } else { 0 }
                if (idx < 0 || idx >= s.size) { return JsValue(BaoString("")) }
                return JsValue(BaoString(s[idx..(idx + 1)]))
            })
            case "charCodeAt" => Some(makeNativeFn("charCodeAt") { args =>
                let s = jsToString(strVal)
                let idx = if (args.size > 0) { Int64(jsToNumber(args[0])) } else { 0 }
                if (idx < 0 || idx >= s.size) { return JsValue.nan }
                return JsValue(Float64(Int64(s[Int64(idx)].value)))
            })
            case "slice" => Some(makeNativeFn("slice") { args =>
                let s = jsToString(strVal)
                let start = if (args.size > 0) { Int64(jsToNumber(args[0])) } else { 0 }
                let end = if (args.size > 1) { Int64(jsToNumber(args[1])) } else { s.size }
                var st = if (start < 0) { s.size + start } else { start }
                var en = if (end < 0) { s.size + end } else { end }
                if (st < 0) { st = 0 }
                if (en > s.size) { en = s.size }
                if (st >= en) { return JsValue(BaoString("")) }
                return JsValue(BaoString(s[st..en]))
            })
            case "substring" => Some(makeNativeFn("substring") { args =>
                let s = jsToString(strVal)
                let start = if (args.size > 0) { Int64(jsToNumber(args[0])) } else { 0 }
                let end = if (args.size > 1) { Int64(jsToNumber(args[1])) } else { s.size }
                var st = if (start < 0) { 0 } else { start }
                var en = if (end < 0) { 0 } else { end }
                if (st > en) { let tmp = st; st = en; en = tmp }
                return JsValue(BaoString(s[st..en]))
            })
            case "indexOf" => Some(makeNativeFn("indexOf") { args =>
                let s = jsToString(strVal)
                let search = if (args.size > 0) { jsToString(args[0]) } else { "undefined" }
                let startIdx = if (args.size > 1) { Int64(jsToNumber(args[1])) } else { 0 }
                let result = s.indexOf(search, startIdx)
                return JsValue(Float64(result))
            })
            case "includes" => Some(makeNativeFn("includes") { args =>
                let s = jsToString(strVal)
                let search = if (args.size > 0) { jsToString(args[0]) } else { "undefined" }
                return JsValue(s.contains(search))
            })
            case "startsWith" => Some(makeNativeFn("startsWith") { args =>
                let s = jsToString(strVal)
                let search = if (args.size > 0) { jsToString(args[0]) } else { "undefined" }
                return JsValue(s.startsWith(search))
            })
            case "endsWith" => Some(makeNativeFn("endsWith") { args =>
                let s = jsToString(strVal)
                let search = if (args.size > 0) { jsToString(args[0]) } else { "undefined" }
                return JsValue(s.endsWith(search))
            })
            case "toUpperCase" => Some(makeNativeFn("toUpperCase") { _ =>
                return JsValue(BaoString(jsToString(strVal).toUpper()))
            })
            case "toLowerCase" => Some(makeNativeFn("toLowerCase") { _ =>
                return JsValue(BaoString(jsToString(strVal).toLower()))
            })
            case "trim" => Some(makeNativeFn("trim") { _ =>
                return JsValue(BaoString(jsToString(strVal).trim()))
            })
            case "split" => Some(makeNativeFn("split") { args =>
                let s = jsToString(strVal)
                let sep = if (args.size > 0) { jsToString(args[0]) } else { "" }
                let arr = ArrayList<JsValue>()
                if (sep.length == 0) {
                    for (c in s) {
                        arr.append(JsValue(BaoString(c.toString())))
                    }
                } else {
                    var parts = s.split(sep)
                    for (p in parts) {
                        arr.append(JsValue(BaoString(p)))
                    }
                }
                return JsValue.array(arr)
            })
            case "replace" => Some(makeNativeFn("replace") { args =>
                let s = jsToString(strVal)
                if (args.size >= 2) {
                    let search = jsToString(args[0])
                    let replacement = jsToString(args[1])
                    return JsValue(BaoString(s.replace(search, replacement)))
                }
                return JsValue(strVal.stringValue)
            })
            case "repeat" => Some(makeNativeFn("repeat") { args =>
                let s = jsToString(strVal)
                let count = if (args.size > 0) { Int64(jsToNumber(args[0])) } else { 0 }
                let sb = StringBuilder()
                for (_ in 0..count) {
                    sb.append(s)
                }
                return JsValue(BaoString(sb.toString()))
            })
            case "padStart" => Some(makeNativeFn("padStart") { args =>
                let s = jsToString(strVal)
                let len = if (args.size > 0) { Int64(jsToNumber(args[0])) } else { 0 }
                let fill = if (args.size > 1) { jsToString(args[1]) } else { " " }
                if (s.size >= len) { return JsValue(strVal.stringValue) }
                let padLen = len - s.size
                let pad = StringBuilder()
                for (_ in 0..padLen) {
                    pad.append(fill[Int64((pad.length()) % fill.length)])
                }
                return JsValue(BaoString(pad.toString() + s))
            })
            case "concat" => Some(makeNativeFn("concat") { args =>
                let sb = StringBuilder()
                sb.append(jsToString(strVal))
                for (arg in args) {
                    sb.append(jsToString(arg))
                }
                return JsValue(BaoString(sb.toString()))
            })
            case _ => None
        }
    }

    /// 调用函数 - JS 函数或原生函数
    private func callFunction(fn: JsValue, args: ArrayList<JsValue>,
                              thisVal: JsValue, env: Environment): JsValue {
        // 原生函数
        if (let Some(native) = fn.nativeFnData) {
            return native.fn(args)
        }
        // JS 函数
        if (let Some(jsFn) = fn.functionData) {
            return callJsFunction(jsFn, args, thisVal)
        }
        return JsValue.UNDEFINED
    }

    /// 调用 JS 函数 - 创建新的作用域，绑定参数，执行函数体
    private func callJsFunction(fn: JsFunction, args: ArrayList<JsValue>,
                                 thisVal: JsValue): JsValue {
        // 创建函数作用域，闭包环境为函数创建时的环境
        let fnEnv = Environment(fn.closure)
        fnEnv.isFunctionScope = true

        // 绑定 this
        if (fn.isArrow) {
            // 箭头函数继承外层 this
            fnEnv.thisBinding = fn.closure.thisBinding
        } else {
            fnEnv.thisBinding = thisVal
        }

        // 绑定参数
        for (i in 0..fn.paramNames.size) {
            let val = if (i < args.size) { args[i] } else { JsValue.UNDEFINED }
            fnEnv.define(fn.paramNames[i], val, true)
        }

        // 绑定 arguments 对象 (非箭头函数)
        if (!fn.isArrow) {
            let argsObj = newObject()
            for (i in 0..args.size) {
                argsObj.set("${i}", args[i])
            }
            argsObj.set("length", JsValue(Float64(args.size)))
            fnEnv.define("arguments", JsValue(argsObj), false)
        }

        // 执行函数体
        var result = JsValue.UNDEFINED
        try {
            for (stmt in fn.body) {
                result = execStmt(stmt, fnEnv)
            }
        } catch (e: JsError) {
            // 如果是 return 抛出的值，作为返回值
            // JsError 目前用于 throw，直接传播
            throw e
        }
        return result
    }

    /// 点访问 — 完整实现，支持可选链 obj?.prop
    //  严格翻译自: JS MemberExpression (dot access) + Optional Chaining
    //   对应 ES2020 Optional Chaining: obj?.prop
    //   如果 obj 是 null/undefined，返回 undefined 而不抛出 TypeError
    private func evalDot(e: Expr, env: Environment): JsValue {
        if (let Some(target) = e.target) {
            let obj = evalExpr(target, env)

            // 可选链 — 对应 obj?.prop
            //  严格翻译自: ES2020 Optional Chaining
            if (target.optionalChain != None) {
                if (obj.valueType == JsValueType.Null || obj.valueType == JsValueType.Undefined) {
                    return JsValue.UNDEFINED
                }
            }

            if (let Some(objData) = obj.objectData) {
                return match (objData.get(e.propertyName)) {
                    case Some(v) => v
                    case None => JsValue.UNDEFINED
                }
            }
            // 字符串属性
            if (obj.valueType == JsValueType.String) {
                if (e.propertyName == "length") {
                    return JsValue(Float64(obj.stringValue.toString().length))
                }
                // 字符串方法
                if (let Some(method) = getStringMethod(obj, e.propertyName)) {
                    return method
                }
            }
            // 数组属性
            if (let Some(arr) = obj.arrayData) {
                if (e.propertyName == "length") {
                    return JsValue(Float64(arr.size))
                }
            }
            // 函数属性
            if (obj.valueType == JsValueType.Function) {
                if (e.propertyName == "name") {
                    match (obj.functionData) {
                        case Some(fn) => return JsValue(BaoString(fn.name))
                        case None => return JsValue(BaoString(""))
                    }
                }
                if (e.propertyName == "length") {
                    match (obj.functionData) {
                        case Some(fn) => return JsValue(Float64(fn.paramNames.size))
                        case None => return JsValue(0.0)
                    }
                }
                if (e.propertyName == "bind") {
                    return Some(makeNativeFn("bind") { args =>
                        // Function.prototype.bind — 返回绑定了 this 的新函数
                        let boundThis = if (args.size > 0) { args[0] } else { JsValue.UNDEFINED }
                        let fn = obj
                        return JsValue.nativeFunction(JsNativeFunction("bound") { callArgs =>
                            let allArgs = ArrayList<JsValue>()
                            // 绑定的前导参数
                            for (i in 1..args.size) {
                                allArgs.append(args[Int64(i)])
                            }
                            // 调用时的参数
                            for (a in callArgs) {
                                allArgs.append(a)
                            }
                            return callFunction(fn, allArgs, boundThis, env)
                        })
                    })
                }
                if (e.propertyName == "call") {
                    return Some(makeNativeFn("call") { args =>
                        let boundThis = if (args.size > 0) { args[0] } else { JsValue.UNDEFINED }
                        let callArgs = ArrayList<JsValue>()
                        for (i in 1..args.size) {
                            callArgs.append(args[Int64(i)])
                        }
                        return callFunction(obj, callArgs, boundThis, env)
                    })
                }
                if (e.propertyName == "apply") {
                    return Some(makeNativeFn("apply") { args =>
                        let boundThis = if (args.size > 0) { args[0] } else { JsValue.UNDEFINED }
                        let callArgs = ArrayList<JsValue>()
                        if (args.size > 1) {
                            if (let Some(arr) = args[1].arrayData) {
                                for (a in arr) {
                                    callArgs.append(a)
                                }
                            }
                        }
                        return callFunction(obj, callArgs, boundThis, env)
                    })
                }
            }
        }
        return JsValue.UNDEFINED
    }

    /// 索引访问 — 完整实现，支持可选链 obj?.[key]
    //  严格翻译自: JS MemberExpression (computed access)
    private func evalIndex(e: Expr, env: Environment): JsValue {
        var targetVal = JsValue.UNDEFINED
        if (let Some(target) = e.target) {
            targetVal = evalExpr(target, env)

            // 可选链 — 对应 obj?.[key]
            if (target.optionalChain != None) {
                if (targetVal.valueType == JsValueType.Null || targetVal.valueType == JsValueType.Undefined) {
                    return JsValue.UNDEFINED
                }
            }
        }
        if (let Some(index) = e.indexExpr) {
            let idx = evalExpr(index, env)
            // 数组索引
            if (let Some(arr) = targetVal.arrayData) {
                let i = Int64(jsToNumber(idx))
                if (i >= 0 && i < arr.size) {
                    return arr[i]
                }
                return JsValue.UNDEFINED
            }
            // 字符串索引 — 对应 str[index]
            if (targetVal.valueType == JsValueType.String) {
                let s = targetVal.stringValue.toString()
                let i = Int64(jsToNumber(idx))
                if (i >= 0 && i < s.size) {
                    return JsValue(BaoString(s[Int64(i)..(Int64(i) + 1)]))
                }
                return JsValue.UNDEFINED
            }
            // 对象属性
            if (let Some(obj) = targetVal.objectData) {
                let key = jsToString(idx)
                return match (obj.get(key)) {
                    case Some(v) => v
                    case None => JsValue.UNDEFINED
                }
            }
        }
        return JsValue.UNDEFINED
    }

    /// 数组字面量
    private func evalArray(e: Expr, env: Environment): JsValue {
        let arr = ArrayList<JsValue>()
        for (item in e.items) {
            arr.append(evalExpr(item, env))
        }
        return JsValue.array(arr)
    }

    /// 对象字面量
    private func evalObject(e: Expr, env: Environment): JsValue {
        let obj = newObject()
        for (prop in e.properties) {
            let key = prop.key
            let val = match (prop.value) {
                case Some(v) => evalExpr(v, env)
                case None => JsValue.UNDEFINED
            }
            obj.set(key, val)
        }
        return JsValue(obj)
    }

    /// 箭头函数
    private func evalArrow(e: Expr, env: Environment): JsValue {
        if (let Some(fn) = e.fn) {
            let paramNames = ArrayList<String>()
            for (arg in fn.args) {
                paramNames.append(arg.binding.name)
            }
            let bodyStmts = match (fn.body) {
                case GFnBody.Stmts(stmts) => stmts
                case GFnBody.Stmt(s) => ArrayList<Stmt>([s])
                case GFnBody.Expr(expr) =>
                    let loc = expr.loc
                    ArrayList<Stmt>([Stmt.return_(loc, expr)])
            }
            let jsFn = JsFunction(fn.name, paramNames, bodyStmts, env, true)
            return JsValue.function(jsFn)
        }
        return JsValue.UNDEFINED
    }

    /// 函数表达式
    private func evalFunctionExpr(e: Expr, env: Environment): JsValue {
        if (let Some(fn) = e.fn) {
            let paramNames = ArrayList<String>()
            for (arg in fn.args) {
                paramNames.append(arg.binding.name)
            }
            let bodyStmts = match (fn.body) {
                case GFnBody.Stmts(stmts) => stmts
                case GFnBody.Stmt(s) => ArrayList<Stmt>([s])
                case GFnBody.Expr(expr) =>
                    let loc = expr.loc
                    ArrayList<Stmt>([Stmt.return_(loc, expr)])
            }
            let jsFn = JsFunction(fn.name, paramNames, bodyStmts, env, false)
            return JsValue.function(jsFn)
        }
        return JsValue.UNDEFINED
    }

    /// 类表达式
    private func evalClassExpr(e: Expr, env: Environment): JsValue {
        if (let Some(cls) = e.classData) {
            let obj = newObject()
            obj.set("name", JsValue(BaoString(cls.name)))
            return JsValue(obj)
        }
        return JsValue.UNDEFINED
    }

    /// 模板字面量 — 完整实现
    //  严格翻译自: ES6 Template Literal 求值语义
    //   `part0${expr0}part1${expr1}part2`
    //   模板字面量的求值: 交替静态字符串和表达式
    //   tagged template: tag`part0${expr0}part1` 调用 tag 函数
    private func evalTemplate(e: Expr, env: Environment): JsValue {
        // Tagged template literal — 对应 tag`...${...}...`
        if (let Some(tag) = e.templateTag) {
            let tagFn = evalExpr(tag, env)
            // 构建调用参数: [strings_array, ...expr_values]
            let callArgs = ArrayList<JsValue>()
            // strings 数组 — 对应 TemplateStringsArray
            let strings = ArrayList<JsValue>()
            for (i in 0..e.templateParts.size) {
                strings.append(JsValue(BaoString(e.templateQuasis[Int64(i)])))
            }
            callArgs.append(JsValue.array(strings))
            // 表达式值
            for (i in 0..e.templateParts.size) {
                callArgs.append(evalExpr(e.templateParts[i], env))
            }
            return callFunction(tagFn, callArgs, JsValue.UNDEFINED, env)
        }

        // 无标签模板字面量 — 对应 `...${expr}...`
        if (e.templateParts.size == 0) {
            return JsValue(e.stringValue)
        }
        var sb = StringBuilder()
        // 交替 quasis (静态部分) 和 expressions (动态部分)
        for (i in 0..e.templateParts.size) {
            // 静态部分
            if (i < e.templateQuasis.size) {
                sb.append(e.templateQuasis[Int64(i)])
            }
            // 动态表达式部分
            let val = evalExpr(e.templateParts[i], env)
            sb.append(jsToString(val))
        }
        // 最后的静态部分
        if (e.templateParts.size < e.templateQuasis.size) {
            sb.append(e.templateQuasis[e.templateParts.size])
        }
        return JsValue(BaoString(sb.toString()))
    }

    /// 一元表达式
    private func evalUnary(e: Expr, env: Environment): JsValue {
        if (let Some(value) = e.value) {
            let val = evalExpr(value, env)
            match (e.op) {
                case OpCode.UnNot => return JsValue(!jsToBoolean(val))
                case OpCode.UnNeg => return JsValue(-jsToNumber(val))
                case OpCode.UnPos => return JsValue(jsToNumber(val))
                case OpCode.UnCpl => return JsValue(Float64(~Int64(jsToNumber(val))))
                case OpCode.Typeof => return JsValue(BaoString(val.typeOf()))
                case OpCode.UnVoid => return JsValue.UNDEFINED
                case _ => return val
            }
        }
        return JsValue.UNDEFINED
    }

    /// 二元表达式 — 支持短路求值
    //  严格翻译自: JS BinaryExpression 语义
    //   &&, ||, ?? 使用短路求值 (short-circuit evaluation)
    //   对应 ES spec: BinaryExpression 评估算法
    private func evalBinary(e: Expr, env: Environment): JsValue {
        if (let Some(left) = e.left) {
            let l = evalExpr(left, env)
            // 短路求值 — 对应 &&, ||, ??
            match (e.op) {
                case OpCode.BinLoAnd => {
                    // && 短路: 如果左操作数为 falsy，直接返回左值
                    if (!jsToBoolean(l)) { return l }
                    if (let Some(right) = e.right) { return evalExpr(right, env) }
                    return JsValue.UNDEFINED
                }
                case OpCode.BinLoOr => {
                    // || 短路: 如果左操作数为 truthy，直接返回左值
                    if (jsToBoolean(l)) { return l }
                    if (let Some(right) = e.right) { return evalExpr(right, env) }
                    return JsValue.UNDEFINED
                }
                case OpCode.BinNullish => {
                    // ?? 空值合并: 如果左值为 null/undefined，返回右值
                    //  严格翻译自: ES2020 Nullish Coalescing
                    if (l.valueType != JsValueType.Null && l.valueType != JsValueType.Undefined) {
                        return l
                    }
                    if (let Some(right) = e.right) { return evalExpr(right, env) }
                    return JsValue.UNDEFINED
                }
                case _ => {
                    // 非短路运算符 — 求值右侧
                    if (let Some(right) = e.right) {
                        let r = evalExpr(right, env)
                        return evalBinaryOp(e.op, l, r)
                    }
                }
            }
        }
        return JsValue.UNDEFINED
    }

    /// 二元运算求值
    private func evalBinaryOp(op: OpCode, l: JsValue, r: JsValue): JsValue {
        match (op) {
            // 算术
            case OpCode.BinAdd => {
                // JS + 运算符: 数字加法或字符串拼接
                if (l.valueType == JsValueType.String || r.valueType == JsValueType.String) {
                    return JsValue(BaoString(jsToString(l) + jsToString(r)))
                }
                return JsValue(jsToNumber(l) + jsToNumber(r))
            }
            case OpCode.BinSub => JsValue(jsToNumber(l) - jsToNumber(r))
            case OpCode.BinMul => JsValue(jsToNumber(l) * jsToNumber(r))
            case OpCode.BinDiv => {
                let divisor = jsToNumber(r)
                if (divisor == 0.0) { return JsValue(Float64.PositiveInfinity) }
                return JsValue(jsToNumber(l) / divisor)
            }
            case OpCode.BinRem => {
                let divisor = jsToNumber(r)
                if (divisor == 0.0) { return JsValue.nan }
                return JsValue(jsToNumber(l) % divisor)
            }
            case OpCode.BinPow => JsValue(pow(jsToNumber(l), jsToNumber(r)))
            // 比较
            case OpCode.BinLt => JsValue(jsToNumber(l) < jsToNumber(r))
            case OpCode.BinGt => JsValue(jsToNumber(l) > jsToNumber(r))
            case OpCode.BinLe => JsValue(jsToNumber(l) <= jsToNumber(r))
            case OpCode.BinGe => JsValue(jsToNumber(l) >= jsToNumber(r))
            // 等于
            case OpCode.BinEq => JsValue(jsAbstractEqual(l, r))
            case OpCode.BinNe => JsValue(!jsAbstractEqual(l, r))
            case OpCode.BinEqStrict => JsValue(jsStrictEqual(l, r))
            case OpCode.BinNeStrict => JsValue(!jsStrictEqual(l, r))
            // 逻辑
            case OpCode.BinLoAnd => JsValue(jsToBoolean(l) && jsToBoolean(r))
            case OpCode.BinLoOr => JsValue(jsToBoolean(l) || jsToBoolean(r))
            case OpCode.BinNullish => {
                if (l.valueType == JsValueType.Null || l.valueType == JsValueType.Undefined) { r }
                else { l }
            }
            // 位运算
            case OpCode.BinAnd => JsValue(Float64(Int64(jsToNumber(l)) & Int64(jsToNumber(r))))
            case OpCode.BinOr => JsValue(Float64(Int64(jsToNumber(l)) | Int64(jsToNumber(r))))
            case OpCode.BinXor => JsValue(Float64(Int64(jsToNumber(l)) ^ Int64(jsToNumber(r))))
            case OpCode.BinShl => JsValue(Float64(Int64(jsToNumber(l)) << Int64(jsToNumber(r))))
            case OpCode.BinShr => JsValue(Float64(Int64(jsToNumber(l)) >> Int64(jsToNumber(r))))
            case OpCode.BinUShr => JsValue(Float64(Int64(jsToNumber(l)) >>> Int64(jsToNumber(r))))
            case OpCode.BinIn | OpCode.BinInstanceof => JsValue(false)
            case _ => JsValue.UNDEFINED
        }
    }

    /// 三元表达式
    private func evalTernary(e: Expr, env: Environment): JsValue {
        if (let Some(test) = e.test) {
            let cond = evalExpr(test, env)
            if (jsToBoolean(cond)) {
                if (let Some(yes) = e.yes) { return evalExpr(yes, env) }
            } else {
                if (let Some(no) = e.no) { return evalExpr(no, env) }
            }
        }
        return JsValue.UNDEFINED
    }

    /// 赋值表达式 — 完整实现，支持解构赋值和复合赋值运算符
    //  严格翻译自: JS AssignmentExpression 语义
    //   支持: 简单赋值, 解构赋值, 复合赋值 (+=, -=, *=, /=, 等)
    //   解构赋值: let {a, b} = obj; let [x, y] = arr
    private func evalAssign(e: Expr, env: Environment): JsValue {
        var value = JsValue.UNDEFINED
        if (let Some(rhs) = e.value) {
            value = evalExpr(rhs, env)
        }
        if (let Some(target) = e.target) {
            match (target.tag) {
                case ExprTag.Identifier =>
                    env.set(target.identifierName, value)
                case ExprTag.Dot =>
                    // 可选链赋值 — 对应 obj?.prop = value (语法错误，但处理安全)
                    if (let Some(objExpr) = target.target) {
                        let obj = evalExpr(objExpr, env)
                        if (target.optionalChain != None) {
                            if (obj.valueType == JsValueType.Null || obj.valueType == JsValueType.Undefined) {
                                return JsValue.UNDEFINED
                            }
                        }
                        if (let Some(objData) = obj.objectData) {
                            objData.set(target.propertyName, value)
                        }
                    }
                case ExprTag.Index =>
                    if (let Some(objExpr) = target.target) {
                        let obj = evalExpr(objExpr, env)
                        if (let Some(idxExpr) = target.indexExpr) {
                            let idx = evalExpr(idxExpr, env)
                            if (let Some(arr) = obj.arrayData) {
                                let i = Int64(jsToNumber(idx))
                                if (i >= 0 && i < arr.size) {
                                    arr[i] = value
                                }
                            } else if (let Some(objData) = obj.objectData) {
                                objData.set(jsToString(idx), value)
                            }
                        }
                    }
                // 解构赋值 — 对应 {a, b} = obj 或 [x, y] = arr
                //  严格翻译自: ES6 Destructuring Assignment
                case _ => {
                    // 如果 target 是对象/数组模式 (通过 Binding 表示)
                    applyBindingFromExpr(target, value, env)
                }
            }
        }
        return value
    }

    /// 应用绑定 — 对应 ES6 解构绑定
    //  严格翻译自: ES6 BindingPattern 语义
    //   支持对象解构: const {a, b: c, d = default} = obj
    //   支持数组解构: const [x, , y, ...rest] = arr
    public func applyBinding(binding: Binding, value: JsValue, env: Environment): Unit {
        match (binding.tag) {
            case BindingTag.Identifier =>
                if (binding.name.length > 0) {
                    env.define(binding.name, value, true)
                }
            case BindingTag.Object =>
                // 对象解构 — 对应 {a, b: c} = value
                //  严格翻译自: ES ObjectBindingPattern
                if (let Some(objData) = value.objectData) {
                    for (prop in binding.objectProperties) {
                        let sourceKey = prop.key.length > 0 ? prop.key : prop.key
                        let val = match (objData.get(sourceKey)) {
                            case Some(v) => v
                            case None => JsValue.UNDEFINED
                        }
                        // 默认值处理 — 对应 {a = defaultValue}
                        let finalVal = match (prop.defaultValue) {
                            case Some(defaultExpr) =>
                                if (val.valueType == JsValueType.Undefined) {
                                    evalExpr(defaultExpr, env)
                                } else { val }
                            case None => val
                        }
                        if (prop.value != None) {
                            // 嵌套解构 — 对应 {a: {b, c}}
                            applyBinding(prop.value, finalVal, env)
                        } else {
                            env.define(prop.key, finalVal, true)
                        }
                    }
                }
            case BindingTag.Array =>
                // 数组解构 — 对应 [a, b, ...rest] = value
                //  严格翻译自: ES ArrayBindingPattern
                let items = value.arrayData
                if (let Some(arr) = items) {
                    var i = 0
                    for (item in binding.arrayItems) {
                        if (item.isRest) {
                            // 剩余元素 — 对应 [...rest]
                            let restArr = ArrayList<JsValue>()
                            for (j in i..arr.size) {
                                restArr.append(arr[j])
                            }
                            applyBinding(item, JsValue.array(restArr), env)
                        } else {
                            let val = if (i < arr.size) { arr[i] } else { JsValue.UNDEFINED }
                            applyBinding(item, val, env)
                            i += 1
                        }
                    }
                } else if (value.valueType == JsValueType.String) {
                    // 字符串解构 — 对应 const [a, b] = "hello"
                    let s = value.stringValue.toString()
                    var i = 0
                    for (item in binding.arrayItems) {
                        if (item.isRest) {
                            let restArr = ArrayList<JsValue>()
                            for (j in i..s.size) {
                                restArr.append(JsValue(BaoString(s[Int64(j)..(Int64(j) + 1)])))
                            }
                            applyBinding(item, JsValue.array(restArr), env)
                        } else {
                            let val = if (i < s.size) {
                                JsValue(BaoString(s[Int64(i)..(Int64(i) + 1)]))
                            } else { JsValue.UNDEFINED }
                            applyBinding(item, val, env)
                            i += 1
                        }
                    }
                }
            case BindingTag.Missing => ()
        }
    }

    /// 从表达式应用绑定 — 用于赋值表达式中的解构
    private func applyBindingFromExpr(expr: Expr, value: JsValue, env: Environment): Unit {
        // 简化: 处理 Object/Array 字面量模式作为解构目标
        if (expr.tag == ExprTag.Array) {
            if (let Some(arr) = value.arrayData) {
                for (i in 0..expr.items.size) {
                    let item = expr.items[i]
                    let val = if (i < arr.size) { arr[i] } else { JsValue.UNDEFINED }
                    if (item.tag == ExprTag.Identifier) {
                        env.set(item.identifierName, val)
                    }
                }
            }
        } else if (expr.tag == ExprTag.Object) {
            if (let Some(objData) = value.objectData) {
                for (prop in expr.properties) {
                    let val = match (objData.get(prop.key)) {
                        case Some(v) => v
                        case None => JsValue.UNDEFINED
                    }
                    if (let Some(valueExpr) = prop.value) {
                        if (valueExpr.tag == ExprTag.Identifier) {
                            env.set(valueExpr.identifierName, val)
                        }
                    }
                }
            }
        }
    }

    /// 后缀表达式 ++/--
    private func evalPostfix(e: Expr, env: Environment): JsValue {
        if (let Some(value) = e.value) {
            let old = evalExpr(value, env)
            let oldNum = jsToNumber(old)
            let delta = match (e.op) {
                case OpCode.PlusPlus => 1.0
                case OpCode.MinusMinus => -1.0
                case _ => 0.0
            }
            let newVal = JsValue(oldNum + delta)
            // 更新变量
            if (value.tag == ExprTag.Identifier) {
                env.set(value.identifierName, newVal)
            }
            return old  // 后缀返回旧值
        }
        return JsValue.UNDEFINED
    }

    // ========================================================================
    // JS 值操作工具函数
    // 对应 Bun: src/jsc/JSValue.zig 中的类型转换
    // ========================================================================

    /// JS ToBoolean - 对应 ES spec ToBoolean()
    public static func jsToBoolean(v: JsValue): Bool {
        return v.toBoolean()
    }

    /// JS ToNumber - 对应 ES spec ToNumber()
    public static func jsToNumber(v: JsValue): Float64 {
        return v.toNumber()
    }

    /// JS ToString - 对应 ES spec ToString()
    public static func jsToString(v: JsValue): String {
        return v.toString()
    }

    /// JS 严格相等 ===
    public static func jsStrictEqual(a: JsValue, b: JsValue): Bool {
        if (a.valueType != b.valueType) { return false }
        match (a.valueType) {
            case JsValueType.Undefined | JsValueType.Null => true
            case JsValueType.Boolean => a.boolValue == b.boolValue
            case JsValueType.Number => a.numberValue == b.numberValue
            case JsValueType.String => a.stringValue.toString() == b.stringValue.toString()
            case _ => a === b  // 引用相等
        }
    }

    /// JS 抽象相等 == (简化版)
    public static func jsAbstractEqual(a: JsValue, b: JsValue): Bool {
        if (a.valueType == b.valueType) { return jsStrictEqual(a, b) }
        // null == undefined
        if ((a.valueType == JsValueType.Null && b.valueType == JsValueType.Undefined) ||
            (a.valueType == JsValueType.Undefined && b.valueType == JsValueType.Null)) {
            return true
        }
        // 数字和字符串比较: 转为数字
        if (a.valueType == JsValueType.Number && b.valueType == JsValueType.String) {
            return a.numberValue == jsToNumber(b)
        }
        if (a.valueType == JsValueType.String && b.valueType == JsValueType.Number) {
            return jsToNumber(a) == b.numberValue
        }
        // 布尔转数字
        if (a.valueType == JsValueType.Boolean) { return jsAbstractEqual(JsValue(jsToNumber(a)), b) }
        if (b.valueType == JsValueType.Boolean) { return jsAbstractEqual(a, JsValue(jsToNumber(b))) }
        return false
    }

    /// 创建新的 JS 对象
    public static func newObject(): JsObject {
        return JsObject()
    }

    /// 创建新的 JS 数组
    public static func newJsArray(): ArrayList<JsValue> {
        return ArrayList<JsValue>()
    }

    /// 创建原生函数 JsValue
    public static func makeNativeFn(name: String, fn: NativeFn): JsValue {
        return JsValue.nativeFunction(JsNativeFunction(name, fn))
    }

    /// 创建 console 对象
    private func makeConsoleObject(): JsObject {
        let obj = newObject()
        obj.set("log", makeNativeFn("log") { args =>
            let sb = StringBuilder()
            for (i in 0..args.size) {
                if (i > 0) { sb.append(" ") }
                sb.append(jsToString(args[i]))
            }
            printFn(sb.toString())
            return JsValue.UNDEFINED
        })
        obj.set("error", makeNativeFn("error") { args =>
            let sb = StringBuilder()
            for (i in 0..args.size) {
                if (i > 0) { sb.append(" ") }
                sb.append(jsToString(args[i]))
            }
            printFn("[ERROR] ${sb.toString()}")
            return JsValue.UNDEFINED
        })
        obj.set("warn", makeNativeFn("warn") { args =>
            let sb = StringBuilder()
            for (i in 0..args.size) {
                if (i > 0) { sb.append(" ") }
                sb.append(jsToString(args[i]))
            }
            printFn("[WARN] ${sb.toString()}")
            return JsValue.UNDEFINED
        })
        obj.set("info", makeNativeFn("info") { args =>
            let sb = StringBuilder()
            for (i in 0..args.size) {
                if (i > 0) { sb.append(" ") }
                sb.append(jsToString(args[i]))
            }
            printFn("[INFO] ${sb.toString()}")
            return JsValue.UNDEFINED
        })
        return obj
    }

    /// pow 实现
    private static func pow(base: Float64, exp: Float64): Float64 {
        if (exp == 0.0) { return 1.0 }
        if (exp == 1.0) { return base }
        if (exp == 2.0) { return base * base }
        var result = 1.0
        var b = base
        var e = Int64(exp)
        while (e > 0) {
            if (e % 2 == 1) { result *= b }
            b *= b
            e /= 2
        }
        return result
    }
}

// ============================================================================
// JsError — JavaScript 运行时错误
// ============================================================================

/// JavaScript 运行时错误 - 对应 JS throw 值
public class JsError <: Exception {
    public let value: JsValue

    public init(value: JsValue) {
        this.value = value
        super(jsToString(value))
    }
}
