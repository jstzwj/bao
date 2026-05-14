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
            case StmtTag.Break | StmtTag.Continue | StmtTag.Debugger |
                 StmtTag.Empty | StmtTag.Import | StmtTag.Export |
                 StmtTag.With | StmtTag.Labeled | StmtTag.Type | StmtTag.Enum =>
                return JsValue.UNDEFINED
        }
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
            // body
            if (let Some(body) = s.body) {
                result = execStmt(body, forEnv)
            }
            // update
            if (let Some(update) = s.update) {
                evalExpr(update, forEnv)
            }
        }
        return result
    }

    /// 执行 for-in 语句
    private func execForIn(s: Stmt, env: Environment): JsValue {
        if (let Some(obj) = s.iterValue) {
            let val = evalExpr(obj, env)
            if (val.valueType != JsValueType.Object) { return JsValue.UNDEFINED }
            let objData = val.objectData
            var result = JsValue.UNDEFINED
            if (let Some(jsObj) = objData) {
                let keys = jsObj.keys()
                for (key in keys) {
                    let forEnv = Environment(env)
                    let bindingName = if (s.decls.size > 0) { s.decls[0].binding.name } else { "" }
                    if (bindingName.length > 0) {
                        forEnv.define(bindingName, JsValue(BaoString(key)), false)
                    }
                    if (let Some(body) = s.body) {
                        result = execStmt(body, forEnv)
                    }
                }
            }
            return result
        }
        return JsValue.UNDEFINED
    }

    /// 执行 for-of 语句
    private func execForOf(s: Stmt, env: Environment): JsValue {
        if (let Some(iterable) = s.iterValue) {
            let val = evalExpr(iterable, env)
            let items = val.arrayData
            var result = JsValue.UNDEFINED
            if (let Some(arr) = items) {
                for (item in arr) {
                    let forEnv = Environment(env)
                    let bindingName = if (s.decls.size > 0) { s.decls[0].binding.name } else { "" }
                    if (bindingName.length > 0) {
                        forEnv.define(bindingName, item, false)
                    }
                    if (let Some(body) = s.body) {
                        result = execStmt(body, forEnv)
                    }
                }
            }
            return result
        }
        return JsValue.UNDEFINED
    }

    /// 执行 while 语句
    private func execWhile(s: Stmt, env: Environment): JsValue {
        var result = JsValue.UNDEFINED
        while (true) {
            if (let Some(test) = s.expr) {
                let cond = evalExpr(test, env)
                if (!jsToBoolean(cond)) { break }
            }
            if (let Some(body) = s.body) {
                result = execStmt(body, env)
            }
        }
        return result
    }

    /// 执行 do-while 语句
    private func execDoWhile(s: Stmt, env: Environment): JsValue {
        var result = JsValue.UNDEFINED
        while (true) {
            if (let Some(body) = s.body) {
                result = execStmt(body, env)
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

    /// 执行类声明
    private func execClassDecl(s: Stmt, env: Environment): JsValue {
        if (let Some(cls) = s.classData) {
            let classObj = newObject()
            let protoObj = newObject()
            for (prop in cls.properties) {
                if (prop.flags.isStatic) {
                    classObj.set(prop.key, JsValue.UNDEFINED)
                } else {
                    protoObj.set(prop.key, JsValue.UNDEFINED)
                }
            }
            classObj.set("prototype", JsValue(protoObj))
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

    /// 执行 try-catch
    private func execTry(s: Stmt, env: Environment): JsValue {
        var result = JsValue.UNDEFINED
        try {
            for (stmt in s.stmts) {
                result = execStmt(stmt, env)
            }
        } catch (e: JsError) {
            if (let Some(catch) = s.catchBody) {
                let catchEnv = Environment(env)
                if (let Some(binding) = s.catchBinding) {
                    if (binding.name.length > 0) {
                        catchEnv.define(binding.name, e.value, true)
                    }
                }
                result = execStmt(catch, catchEnv)
            }
        }
        if (let Some(finally) = s.finallyBody) {
            execStmt(finally, env)
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

    /// new 表达式
    private func evalNew(e: Expr, env: Environment): JsValue {
        // 简化: 创建空对象
        let obj = newObject()
        if (let Some(target) = e.target) {
            let ctor = evalExpr(target, env)
            // 如果构造函数是原生函数或 JS 函数，调用它
            _ = ctor  // 简化处理
        }
        return JsValue(obj)
    }

    /// 函数调用 - 对应 JS 函数调用表达式
    private func evalCall(e: Expr, env: Environment): JsValue {
        var thisVal = JsValue.UNDEFINED
        var callable: ?JsValue = None

        if (let Some(target) = e.target) {
            // 处理 obj.method() 调用
            if (target.tag == ExprTag.Dot) {
                let objVal = if (let Some(t) = target.target) { evalExpr(t, env) } else { JsValue.UNDEFINED }
                thisVal = objVal
                if (let Some(objData) = objVal.objectData) {
                    callable = objData.get(target.propertyName)
                }
            } else {
                callable = Some(evalExpr(target, env))
            }
        }

        // 求值参数
        let args = ArrayList<JsValue>()
        for (arg in e.args) {
            args.append(evalExpr(arg, env))
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

    /// 点访问 - 对应 JS obj.prop
    private func evalDot(e: Expr, env: Environment): JsValue {
        if (let Some(target) = e.target) {
            let obj = evalExpr(target, env)
            if (let Some(objData) = obj.objectData) {
                return match (objData.get(e.propertyName)) {
                    case Some(v) => v
                    case None => JsValue.UNDEFINED
                }
            }
            // 字符串的 length 等属性
            if (obj.valueType == JsValueType.String && e.propertyName == "length") {
                return JsValue(Float64(obj.stringValue.toString().length))
            }
        }
        return JsValue.UNDEFINED
    }

    /// 索引访问 - 对应 JS obj[key]
    private func evalIndex(e: Expr, env: Environment): JsValue {
        var targetVal = JsValue.UNDEFINED
        if (let Some(target) = e.target) {
            targetVal = evalExpr(target, env)
        }
        if (let Some(index) = e.indexExpr) {
            let idx = evalExpr(index, env)
            // 数组索引
            if (let Some(arr) = targetVal.arrayData) {
                let i = Int64(jsToNumber(idx))
                if (i >= 0 && i < arr.size) {
                    return arr[i]
                }
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

    /// 模板字面量
    private func evalTemplate(e: Expr, env: Environment): JsValue {
        if (e.templateParts.size == 0) {
            return JsValue(e.stringValue)
        }
        var sb = StringBuilder()
        for (i in 0..e.templateParts.size) {
            let val = evalExpr(e.templateParts[i], env)
            sb.append(jsToString(val))
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

    /// 二元表达式
    private func evalBinary(e: Expr, env: Environment): JsValue {
        if (let Some(left) = e.left) {
            if (let Some(right) = e.right) {
                let l = evalExpr(left, env)
                let r = evalExpr(right, env)
                return evalBinaryOp(e.op, l, r)
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

    /// 赋值表达式
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
                    if (let Some(objExpr) = target.target) {
                        let obj = evalExpr(objExpr, env)
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
                case _ => ()
            }
        }
        return value
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
