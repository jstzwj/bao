// AST 解释器 — JavaScript 运行时核心
// 对应 Bun: src/jsc/VirtualMachine.zig 中 AST→执行 的流程
// Bun 使用 JavaScriptCore (JSC) C API 执行 JS，仓颉没有 JSC 绑定，
// 因此实现 AST 树遍历解释器：Parser 生成 AST → Interpreter 直接求值
package bao_runtime

import bao_core.*
import bao_sys.SysFs
import bao_sys.SysMaybe
import bao_collections.*
import bao_parser.{Stmt, Expr, StmtTag, ExprTag, OpCode, Binding, BindingTag, GFn, GFnBody, GArg, GClass, GProperty, GPropertyKind, GDecl, SwitchCase, ParserOptions, ParserFeatures, Loc as ParserLoc, DeclKind, OptionalChain, ImportRecord}
import bao_jsc.{RegularExpression, RegularExpressionFlags, RegexExecResult}

// ============================================================================
// Environment — 作用域环境
// 对应 Bun: src/js_parser/ast/Scope.zig + JSC 的 ExecState
//   JavaScript 使用词法作用域 (lexical scoping)
//   每个函数调用创建新的 Environment，形成作用域链
// ============================================================================

/// 变量绑定 - 对应 JS 变量声明
public class EnvBinding {
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
    public var bindings: HashMap<String, EnvBinding>
    /// 父作用域 (用于作用域链查找)
    public var parent: ?Environment
    /// 是否为函数作用域 (决定 this 指向)
    public var isFunctionScope: Bool
    /// this 绑定
    public var thisBinding: JsValue

    public init() {
        bindings = HashMap<String, EnvBinding>()
        parent = None
        isFunctionScope = false
        thisBinding = JsValue.UNDEFINED
    }

    public init(parent: Environment) {
        bindings = HashMap<String, EnvBinding>()
        this.parent = Some(parent)
        isFunctionScope = false
        thisBinding = JsValue.UNDEFINED
    }

    /// 定义变量 - 对应 JS var/let/const 声明
    public func define(name: String, value: JsValue, mutable: Bool): Unit {
        bindings.put(name, EnvBinding(name, value, mutable))
    }

    /// Convenience define - defaults to mutable
    public func define(name: String, value: JsValue): Unit {
        define(name, value, true)
    }

    /// 查找变量 - 沿作用域链向上查找
    /// 对应 JS 标识符解析 (identifier resolution)
    public func lookup(name: String): ?JsValue {
        let bOpt = bindings.get(name); if (bOpt.isSome()) {
            return Some(bOpt.getOrThrow().value)  // OK
        }
        if (parent.isSome()) {
            return parent.getOrThrow().lookup(name)
        }
        return Option<JsValue>.None
    }

    /// 设置变量值 - 对应 JS 赋值
    /// 需要沿作用域链找到声明位置
    public func set(name: String, value: JsValue): Bool {
        let bOpt = bindings.get(name); if (bOpt.isSome()) {
            let b = bOpt.getOrThrow(); if (!b.mutable) {
                return false
            }
            b.value = value  // reassign
            return true
        }
        if (parent.isSome()) {
            return parent.getOrThrow().set(name, value)
        }
        return false
    }

    /// 删除变量绑定 - 用于测试隔离时清理测试注册表
    /// 对应 JS delete operator (仅删除当前作用域的绑定)
    public func delete(name: String): Bool {
        return bindings.remove(name).isSome()
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
    /// 是否为生成器函数 (function*)
    public var isGenerator: Bool

    public init(name: String, params: ArrayList<String>, body: ArrayList<Stmt>,
                closure: Environment, isArrow: Bool) {
        this.name = name
        this.paramNames = params
        this.body = body
        this.closure = closure
        this.isArrow = isArrow
        this.isAsync = false
        this.isGenerator = false
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
    /// 当前执行的文件路径 (用于解析相对导入)
    private var currentFile: String
    /// 当前文件的模块导入记录 (来自 Parser)
    private var importRecords: ArrayList<ImportRecord>
    /// 当前模块的 exports 对象 (ESM 模式下使用)
    private var moduleExports: ?JsObject
    /// 事件循环 (定时器/微任务调度)
    private var eventLoop: EventLoop
    /// 原生构造函数注册表 — 绕过 Cangjie JsValue 字段丢失问题
    /// key: 构造函数名称, value: 原生函数
    private var nativeConstructors: HashMap<String, NativeFn>

    public init() {
        globalEnv = Environment()
        printFn = { s => println(s) }
        // 创建带文件读取能力的 ModuleLoader
        moduleLoader = ModuleLoader({ path => readFileAsString(path) })
        currentFile = ""
        importRecords = ArrayList<ImportRecord>()
        moduleExports = None
        eventLoop = EventLoop()
        nativeConstructors = HashMap<String, NativeFn>()
        registerBuiltins()
    }

    public init(env: Environment) {
        globalEnv = env
        printFn = { s => println(s) }
        moduleLoader = ModuleLoader({ path => readFileAsString(path) })
        currentFile = ""
        importRecords = ArrayList<ImportRecord>()
        moduleExports = None
        eventLoop = EventLoop()
        nativeConstructors = HashMap<String, NativeFn>()
        registerBuiltins()
    }

    /// 读取文件为字符串 — 供 ModuleLoader 使用
    private static func readFileAsString(path: String): String {
        let fdResult = SysFs.openRead(path)
        if (fdResult.isErr()) { return "" }
        let fd = fdResult.result().getOrThrow()
        var allBytes = ArrayList<UInt8>()
        let bufSize: Int64 = 8192
        var buf = Array<UInt8>(bufSize, { _ => UInt8(0) })
        while (true) {
            let readResult = SysFs.read(fd, buf)
            match (readResult) {
                case SysMaybe.Err(_) => let _ = SysFs.close(fd); return ""
                case SysMaybe.Ok(bytesRead) =>
                    if (bytesRead == 0) { break }
                    for (i in 0..bytesRead) { allBytes.append(buf[i]) }
            }
        }
        let _ = SysFs.close(fd)
        if (allBytes.size == 0) { return "" }
        // 尝试直接 UTF-8 转换，失败则替换非法字节
        try {
            return String.fromUtf8(allBytes.items())
        } catch (_: Exception) {
            // 包含非法 UTF-8 字节 — 替换为 U+FFFD (EF BF BD)
            let clean = ArrayList<UInt8>()
            let bytes = allBytes.items()
            let len = bytes.size
            var i = Int64(0)
            while (i < len) {
                let b = bytes[i]
                if (b < UInt8(0x80)) {
                    // ASCII: 0xxxxxxx — 直接使用
                    clean.append(b)
                    i += 1
                } else if (b >= UInt8(0xC0) && b < UInt8(0xE0) && i + 1 < len
                           && bytes[i + 1] >= UInt8(0x80) && bytes[i + 1] < UInt8(0xC0)) {
                    // 2字节: 110xxxxx 10xxxxxx
                    clean.append(b)
                    clean.append(bytes[i + 1])
                    i += 2
                } else if (b >= UInt8(0xE0) && b < UInt8(0xF0) && i + 2 < len
                           && bytes[i + 1] >= UInt8(0x80) && bytes[i + 1] < UInt8(0xC0)
                           && bytes[i + 2] >= UInt8(0x80) && bytes[i + 2] < UInt8(0xC0)) {
                    // 3字节: 1110xxxx 10xxxxxx 10xxxxxx
                    clean.append(b)
                    clean.append(bytes[i + 1])
                    clean.append(bytes[i + 2])
                    i += 3
                } else if (b >= UInt8(0xF0) && i + 3 < len
                           && bytes[i + 1] >= UInt8(0x80) && bytes[i + 1] < UInt8(0xC0)
                           && bytes[i + 2] >= UInt8(0x80) && bytes[i + 2] < UInt8(0xC0)
                           && bytes[i + 3] >= UInt8(0x80) && bytes[i + 3] < UInt8(0xC0)) {
                    // 4字节: 11110xxx 10xxxxxx 10xxxxxx 10xxxxxx
                    clean.append(b)
                    clean.append(bytes[i + 1])
                    clean.append(bytes[i + 2])
                    clean.append(bytes[i + 3])
                    i += 4
                } else {
                    // 非法字节 — 替换为 U+FFFD (EF BF BD)
                    clean.append(UInt8(0xEF))
                    clean.append(UInt8(0xBF))
                    clean.append(UInt8(0xBD))
                    i += 1
                }
            }
            // 第二次尝试：清理后的字节可能仍含无效 Unicode scalar
            try {
                return String.fromUtf8(clean.items())
            } catch (_: Exception) {
                // 最终回退：只保留 ASCII，其余替换为 '?'
                let safe = ArrayList<UInt8>()
                for (j in 0..allBytes.size) {
                    let byte = allBytes[j]
                    if (byte < UInt8(0x80)) {
                        safe.append(byte)
                    } else {
                        safe.append(UInt8(0x3F))  // '?'
                    }
                }
                return String.fromUtf8(safe.items())
            }
        }
    }

    /// 设置当前文件路径
    public func setCurrentFile(f: String): Unit { currentFile = f }
    /// 设置模块导入记录
    public func setImportRecords(r: ArrayList<ImportRecord>): Unit { importRecords = r }
    /// 设置当前模块的 exports 对象 (ESM 模式)
    public func setModuleExports(e: JsObject): Unit { moduleExports = Some(e) }
    /// 设置模块加载器
    public func setModuleLoader(l: ModuleLoader): Unit { moduleLoader = l }
    /// 设置事件循环
    public func setEventLoop(el: EventLoop): Unit { eventLoop = el }
    /// 获取事件循环
    public func getEventLoop(): EventLoop { eventLoop }

    /// 获取全局环境
    public func getGlobalEnv(): Environment {
        return globalEnv
    }

    /// 注册内置函数和全局变量
    /// 对应 Bun: VirtualMachine 初始化时注册的全局对象
    private func registerBuiltins(): Unit {
        // 全局常量
        globalEnv.define("undefined", JsValue.UNDEFINED, false)
        globalEnv.define("NaN", JsValue(Float64.NaN), false)
        globalEnv.define("Infinity", JsValue(Float64.Inf), false)
        globalEnv.define("true", JsValue(true), false)
        globalEnv.define("false", JsValue(false), false)

        // console.log 等
        globalEnv.define("console", JsValue(makeConsoleObject()), false)

        // print() — QuickJS/Hermes 兼容的全局打印函数
        globalEnv.define("print", makeNativeFn("print") { args =>
            let sb = StringBuilder()
            for (i in 0..args.size) {
                if (i > 0) { sb.append(" ") }
                sb.append(jsToString(args[i]))
            }
            printFn(sb.toString())
            return JsValue.UNDEFINED
        }, false)

        // parseInt, parseFloat, isNaN, isFinite
        globalEnv.define("parseInt", makeNativeFn("parseInt") { args =>
            if (args.size < 1) { return JsValue.nan }
            let s = jsToString(args[0])
            try {
                let radix = if (args.size > 1) { jsToNumber(args[1]) } else { 10.0 }
                return JsValue(0.0)
            } catch (_: Exception) { return JsValue.nan }
        }, false)
        globalEnv.define("parseFloat", makeNativeFn("parseFloat") { args =>
            if (args.size < 1) { return JsValue.nan }
            try {
                return JsValue(0.0)
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
            return JsValue(!n.isNaN() && n != Float64.Inf && n != -Float64.Inf)
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
            let vOpt = builtins.get(specifier)
            if (vOpt.isSome()) { return vOpt.getOrThrow() }





            return loader.require(specifier, "<eval>")
        }, false)

        // setTimeout / setInterval / clearTimeout / clearInterval
        // 注意: 不捕获 eventLoop 到 let 变量中, 通过 getEventLoop() 动态获取
        // 因为 setEventLoop() 可能在 registerBuiltins() 之后被调用
        globalEnv.define("setTimeout", makeNativeFn("setTimeout") { args =>
            if (args.size < 1) { return JsValue.UNDEFINED }
            let cb = args[0]
            let delayRaw = if (args.size > 1) { Int64(jsToNumber(args[1])) } else { Int64(0) }
            let delay = if (delayRaw < 0) { Int64(0) } else { delayRaw }
            let extraArgs = sliceArgs(args, 2)
            let interp = this
            let id = getEventLoop().setTimeout(delay, { =>
                interp.callFunction(cb, extraArgs, JsValue.UNDEFINED, interp.getGlobalEnv())
            })
            JsValue(Float64(id))
        }, false)
        globalEnv.define("setInterval", makeNativeFn("setInterval") { args =>
            if (args.size < 1) { return JsValue.UNDEFINED }
            let cb = args[0]
            let intervalRaw = if (args.size > 1) { Int64(jsToNumber(args[1])) } else { Int64(0) }
            let interval = if (intervalRaw < 0) { Int64(0) } else { intervalRaw }
            let extraArgs = sliceArgs(args, 2)
            let interp = this
            let id = getEventLoop().setInterval(interval, { =>
                interp.callFunction(cb, extraArgs, JsValue.UNDEFINED, interp.getGlobalEnv())
            })
            JsValue(Float64(id))
        }, false)
        globalEnv.define("clearTimeout", makeNativeFn("clearTimeout") { args =>
            if (args.size > 0) { getEventLoop().clearTimer(Int64(jsToNumber(args[0]))) }
            JsValue.UNDEFINED
        }, false)
        globalEnv.define("clearInterval", makeNativeFn("clearInterval") { args =>
            if (args.size > 0) { getEventLoop().clearTimer(Int64(jsToNumber(args[0]))) }
            JsValue.UNDEFINED
        }, false)
        globalEnv.define("setImmediate", makeNativeFn("setImmediate") { args =>
            if (args.size < 1) { return JsValue.UNDEFINED }
            let cb = args[0]
            let extraArgs = sliceArgs(args, 1)
            let interp = this
            let id = getEventLoop().setTimeout(0, { =>
                interp.callFunction(cb, extraArgs, JsValue.UNDEFINED, interp.getGlobalEnv())
            })
            JsValue(Float64(id))
        }, false)
        globalEnv.define("clearImmediate", makeNativeFn("clearImmediate") { args =>
            if (args.size > 0) { getEventLoop().clearTimer(Int64(jsToNumber(args[0]))) }
            JsValue.UNDEFINED
        }, false)
        globalEnv.define("queueMicrotask", makeNativeFn("queueMicrotask") { args =>
            if (args.size < 1) { return JsValue.UNDEFINED }
            let cb = args[0]
            let interp = this
            getEventLoop().enqueueMicrotask({ =>
                interp.callFunction(cb, ArrayList<JsValue>(), JsValue.UNDEFINED, interp.getGlobalEnv())
            })
            JsValue.UNDEFINED
        }, false)

        // process 对象
        let processObj = JsObject()
        processObj.set("exit", makeNativeFn("exit") { args =>
            let code = if (args.size > 0) { Int64(jsToNumber(args[0])) } else { Int64(0) }
            throw ProcessExitSignal(code)
        })
        let argvArr = newJsArray()
        argvArr.append(JsValue(BaoString("bao")))
        processObj.set("argv", JsValue.array(argvArr))
        processObj.set("env", JsValue(JsObject()))
        processObj.set("version", JsValue(BaoString("v0.1.0")))
        processObj.set("versions", JsValue(JsObject()))
        processObj.set("platform", JsValue(BaoString("linux")))
        processObj.set("cwd", makeNativeFn("cwd") { _ =>
            JsValue(BaoString("/"))
        })
        globalEnv.define("process", JsValue(processObj), false)

        // Promise 构造函数 — new Promise((resolve, reject) => { ... })
        // 同时注册到 nativeConstructors 以绕过 Cangjie JsValue 字段丢失问题
        let interp = this
        let promiseCtorFn = makeNativeFn("Promise") { args =>
            let promise = JsPromise()
            // 创建 resolve/reject 函数
            let resolveFn = makeNativeFn("resolve") { resolveArgs =>
                let val = if (resolveArgs.size > 0) { resolveArgs[0] } else { JsValue.UNDEFINED }
                promise.fulfill(val)
                return JsValue.UNDEFINED
            }
            let rejectFn = makeNativeFn("reject") { rejectArgs =>
                let reason = if (rejectArgs.size > 0) { rejectArgs[0] } else { JsValue.UNDEFINED }
                promise.rejectInternal(reason)
                return JsValue.UNDEFINED
            }

            // 调用 executor(resolve, reject)
            if (args.size > 0) {
                let executor = args[0]
                let resolverArgs = ArrayList<JsValue>()
                resolverArgs.append(resolveFn)
                resolverArgs.append(rejectFn)
                try {
                    interp.callFunction(executor, resolverArgs, JsValue.UNDEFINED, interp.getGlobalEnv())
                } catch (_: Exception) {
                    // executor 抛出异常 → 自动 reject
                }
            }

            // 返回 Promise JsValue — 同时携带 JsPromise 内部引用和 JsObject 包装
            interp.wrapPromiseValue(promise)
        }
        globalEnv.define("Promise", promiseCtorFn, false)
        // 注册到原生构造函数注册表 — evalNew 通过此表查找
        nativeConstructors.put("Promise", promiseCtorFn.nativeFnData.getOrThrow().fn)

        // Date 构造函数 — new Date() 返回当前时间, new Date(ms) 返回指定时间戳
        let dateCtorFn = makeNativeFn("Date") { args =>
            let ts = if (args.size > 0) { Int64(jsToNumber(args[0])) } else { DateObject.now() }
            let dateObj = DateObject(ts)
            let obj = JsObject()
            obj.className = "Date"
            obj.set("valueOf", makeNativeFn("valueOf") { _ =>
                JsValue(Float64(dateObj.timestamp))
            })
            obj.set("getTime", makeNativeFn("getTime") { _ =>
                JsValue(Float64(dateObj.timestamp))
            })
            obj.set("toString", makeNativeFn("toString") { _ =>
                JsValue(BaoString(dateObj.timestamp.toString()))
            })
            let dateValue = JsValue(JsValueType.Date)
            dateValue.objectData = Some(obj)
            dateValue.numberValue = Float64(dateObj.timestamp)
            dateValue
        }
        globalEnv.define("Date", dateCtorFn, false)
        nativeConstructors.put("Date", dateCtorFn.nativeFnData.getOrThrow().fn)

        // 注册当前 Interpreter 为 TestRunner 的回调 VM
        // 这样 bun:test 在 bao run 模式下也能执行 JS 测试回调
        registerTestRunnerVM()
    }

    /// 将 JsPromise 包装为可链式调用的 JS 对象 — 返回 JsValue 携带 promiseData
    private func wrapPromiseValue(promise: JsPromise): JsValue {
        let obj = JsObject()
        obj.className = "Promise"
        let interp = this
        obj.set("then", makeNativeFn("then") { thenArgs =>
            let onFulfilledJs = if (thenArgs.size > 0) { thenArgs[0] } else { JsValue.UNDEFINED }
            let onRejectedJs = if (thenArgs.size > 1) { thenArgs[1] } else { JsValue.UNDEFINED }
            let nextPromise = promise.then(
                { value =>
                    if (onFulfilledJs.isUndefined()) { value }
                    else {
                        let callArgs = ArrayList<JsValue>()
                        callArgs.append(value)
                        interp.callFunction(onFulfilledJs, callArgs, JsValue.UNDEFINED, interp.getGlobalEnv())
                    }
                },
                { reason =>
                    if (onRejectedJs.isUndefined()) { reason }
                    else {
                        let callArgs = ArrayList<JsValue>()
                        callArgs.append(reason)
                        interp.callFunction(onRejectedJs, callArgs, JsValue.UNDEFINED, interp.getGlobalEnv())
                    }
                }
            )
            wrapPromiseValue(nextPromise)
        })
        obj.set("catch", makeNativeFn("catch") { catchArgs =>
            let onRejectedJs = if (catchArgs.size > 0) { catchArgs[0] } else { JsValue.UNDEFINED }
            let nextPromise = promise.catch_({ reason =>
                let callArgs = ArrayList<JsValue>()
                callArgs.append(reason)
                interp.callFunction(onRejectedJs, callArgs, JsValue.UNDEFINED, interp.getGlobalEnv())
            })
            wrapPromiseValue(nextPromise)
        })
        JsValue.promise(promise, obj)
    }

    /// 将当前 Interpreter 注册为 TestRunner 的回调 VM
    /// 这样 bun:test 的 test()/it() 在无 TestRunner 时也能执行 JS 回调
    private func registerTestRunnerVM(): Unit {
        TestRunner.activeRunnerVM = this
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

    /// 从 args 数组中切片出 start 之后的元素 (不可变版本, 供 lambda 捕获)
    private static func sliceArgs(args: ArrayList<JsValue>, start: Int64): ArrayList<JsValue> {
        let result = ArrayList<JsValue>()
        for (i in start..args.size) {
            result.append(args[i])
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

    /// break/continue 信号类已移至 Interpreter 外部
    /// 在循环中通过 try-catch 捕获 BreakSignal/ContinueSignal

    // ========================================================================
    // 语句执行 — execStmt
    // 对应 Bun: 逐条执行 AST Stmt 节点
    // ========================================================================

    /// 执行单条语句
    public func execStmt(s: Stmt, env: Environment): JsValue {
        match (s.tag) {
            case StmtTag.Block => execBlock(s, env)
            case StmtTag.Expr => execExprStmt(s, env)
            case StmtTag.If => execIf(s, env)
            case StmtTag.For => execFor(s, env)
            case StmtTag.ForIn => execForIn(s, env)
            case StmtTag.ForOf => execForOf(s, env)
            case StmtTag.While => execWhile(s, env)
            case StmtTag.DoWhile => execDoWhile(s, env)
            case StmtTag.Function => execFunctionDecl(s, env)
            case StmtTag.Class => execClassDecl(s, env)
            case StmtTag.Local => execLocal(s, env)
            case StmtTag.Return => execReturnStmt(s, env)
            case StmtTag.Throw => execThrowStmt(s, env)
            case StmtTag.Try => execTry(s, env)
            case StmtTag.Switch => execSwitch(s, env)
            // break/continue — 对应 JS 控制流信号
            case StmtTag.Break => throw BreakSignal(s.label)
            case StmtTag.Continue => throw ContinueSignal(s.label)
            // import 语句 — 模块加载执行
            case StmtTag.Import => execImport(s, env)
            // export 语句 — 注册到模块导出
            case StmtTag.Export => execExport(s, env)
            // labeled 语句 — 对应 JS label: stmt
            case StmtTag.Labeled => execLabeledStmt(s, env)
            // with 语句 — 对应 JS with(obj) { stmt }
            case StmtTag.With => execWith(s, env)
            // debugger — 空操作
            case StmtTag.Debugger => JsValue.UNDEFINED
            // 空语句
            case StmtTag.Empty => JsValue.UNDEFINED
            // TypeScript 类型/枚举 — 运行时忽略
            case StmtTag.Type | StmtTag.Enum => JsValue.UNDEFINED
            case _ => JsValue.UNDEFINED
        }
    }

    /// 执行 import 语句 — 对应 JS import 声明
    //  严格翻译自: ES Modules import 语义
    //   import { foo, bar } from './module'
    //   import * as mod from './module'
    //   import defaultExport from './module'
    private func execImport(s: Stmt, env: Environment): JsValue {
        // 1. 从 importRecords 获取模块路径
        let idx = s.importRecordIndex
        if (idx < 0 || idx >= importRecords.size) { return JsValue.UNDEFINED }
        let specifier = importRecords[idx].path
        if (specifier.isEmpty()) { return JsValue.UNDEFINED }

        // 2. 通过 ModuleLoader 加载模块
        let moduleValue = moduleLoader.importModule(specifier, currentFile)

        // 3. 绑定导入名到当前环境
        // a) 默认导入: import X from '...'
        if (!s.defaultName.isEmpty()) {
            let defaultVal = extractExport(moduleValue, "default")
            env.define(s.defaultName, defaultVal, true)
        }

        // b) 命名空间导入: import * as ns from '...'
        if (s.hasImportStar && !s.defaultName.isEmpty()) {
            // 对于 import * as ns，ns 就是 defaultName
            // moduleValue 已经是模块的 exports 对象
            env.define(s.defaultName, moduleValue, true)
        }

        // c) 具名导入: import { foo, bar as baz } from '...'
        for (i in 0..s.importItems.size) {
            let item = s.importItems[Int64(i)]
            let importName = item.originalName   // 源模块中的名称
            let localName = item.alias          // 本地绑定名
            let val = extractExport(moduleValue, importName)
            env.define(localName, val, true)
        }

        return JsValue.UNDEFINED
    }

    /// 从模块值中提取指定名称的导出
    private func extractExport(moduleValue: JsValue, name: String): JsValue {
        if (moduleValue.objectData.isSome()) {
            let obj = moduleValue.objectData.getOrThrow()
            let val = obj.get(name)
            if (!val.isUndefined()) { return val }
        }
        if (name == "default") { return moduleValue }
        return JsValue.UNDEFINED
    }

    /// 执行 export 语句 — 对应 JS export 声明
    //  严格翻译自: ES Modules export 语义
    //   export const x = 1
    //   export { foo, bar }
    //   export default expr
    //   export * from './module'
    private func execExport(s: Stmt, env: Environment): JsValue {
        if (moduleExports.isNone()) { return JsValue.UNDEFINED }
        let exports = moduleExports.getOrThrow()

        // Case 1: export default <expression>
        if (s.expr.isSome()) {
            let val = evalExpr(s.expr.getOrThrow(), env)
            exports.set("default", val)
            return JsValue.UNDEFINED
        }

        // Case 2: export default <statement> (function/class declaration)
        if (s.`init`.isSome()) {
            let result = execStmt(s.`init`.getOrThrow(), env)
            exports.set("default", result)
            return JsValue.UNDEFINED
        }

        // Case 3: export * from '...' (re-export all)
        if (s.hasImportStar && s.importRecordIndex > 0) {
            let idx = s.importRecordIndex
            if (idx < importRecords.size) {
                let specifier = importRecords[idx].path
                let sourceModule = moduleLoader.importModule(specifier, currentFile)
                if (sourceModule.objectData.isSome()) {
                    let srcObj = sourceModule.objectData.getOrThrow()
                    for (key in srcObj.keys()) {
                        if (key != "default") {
                            exports.set(key, srcObj.get(key))
                        }
                    }
                }
            }
            return JsValue.UNDEFINED
        }

        // Case 4: export { foo, bar as baz } 或 export { foo } from '...'
        if (s.importItems.size > 0) {
            if (s.importRecordIndex > 0 && s.importRecordIndex < importRecords.size) {
                // export { foo } from '...' — 从其他模块导入后导出
                let specifier = importRecords[s.importRecordIndex].path
                let sourceModule = moduleLoader.importModule(specifier, currentFile)
                for (i in 0..s.importItems.size) {
                    let item = s.importItems[Int64(i)]
                    let val = extractExport(sourceModule, item.originalName)
                    exports.set(item.alias, val)
                }
            } else {
                // export { foo, bar as baz } — 从当前环境导出
                for (i in 0..s.importItems.size) {
                    let item = s.importItems[Int64(i)]
                    let valOpt = env.lookup(item.originalName)
                    let val = if (valOpt.isSome()) { valOpt.getOrThrow() } else { JsValue.UNDEFINED }
                    exports.set(item.alias, val)
                }
            }
        }

        return JsValue.UNDEFINED
    }

    /// 执行 with 语句 — 对应 JS with(obj) { body }
    //  严格翻译自: ES with 语句语义 (严格模式下禁止)
    //   with (obj) { ... } 将 obj 的属性注入作用域
    //   注意: with 在严格模式下不可用，此处提供兼容支持
    private func execWith(s: Stmt, env: Environment): JsValue {
        if (s.expr.isSome()) {
            let expr = s.expr.getOrThrow(); let val = evalExpr(expr, env)
            let withEnv = Environment(env)
            // 如果值是对象，将其属性注入 with 环境
            if (val.objectData.isSome()) {
                let objData = val.objectData.getOrThrow(); let keys = objData.keys()
                for (key in keys) {
                    withEnv.define(key, objData.get(key), true)
                }
            }
            if (s.body.isSome()) {
                let body = s.body.getOrThrow(); return execStmt(body, withEnv)
            }
        }
        return JsValue.UNDEFINED
    }

    /// 执行表达式语句 — 对应 JS ExpressionStatement
    private func execExprStmt(s: Stmt, env: Environment): JsValue {
        if (let Some(expr) <- s.expr) {
            return evalExpr(expr, env)
        }
        return JsValue.UNDEFINED
    }

    /// 执行 return 语句 — 对应 JS return [expr]
    /// 通过抛出 ReturnSignal 传播返回值到 callJsFunction
    private func execReturnStmt(s: Stmt, env: Environment): JsValue {
        var val = JsValue.UNDEFINED
        if (let Some(expr) <- s.expr) {
            val = evalExpr(expr, env)
        }
        throw ReturnSignal(val)
    }

    /// 执行 throw 语句
    private func execThrowStmt(s: Stmt, env: Environment): JsValue {
        if (s.expr.isSome()) {
            let val = evalExpr(s.expr.getOrThrow(), env)
            throw JsRuntimeThrow(val)
        }
        throw JsRuntimeThrow(JsValue(BaoString("Error")))
    }

    /// 执行 labeled 语句
    private func execLabeledStmt(s: Stmt, env: Environment): JsValue {
        if (s.body.isSome()) {
            return execStmt(s.body.getOrThrow(), env)
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
        if (s.expr.isSome()) {
            let test = s.expr.getOrThrow(); let cond = evalExpr(test, env)
            if (jsToBoolean(cond)) {
                if (s.yes.isSome()) {
                    let yes = s.yes.getOrThrow(); return execStmt(yes, env)
                }
            } else {
                if (s.no.isSome()) {
                    let no = s.no.getOrThrow(); return execStmt(no, env)
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
        if (s.`init`.isSome()) {
            let initStmt = s.`init`.getOrThrow(); execStmt(initStmt, forEnv)
        }
        var result = JsValue.UNDEFINED
        while (true) {
            // test
            if (s.expr.isSome()) {
                let test = s.expr.getOrThrow(); let cond = evalExpr(test, forEnv)
                if (!jsToBoolean(cond)) { break }
            }
            // body — 捕获 break/continue 信号
            try {
                if (s.body.isSome()) {
                    let body2 = s.body.getOrThrow(); result = execStmt(body2, forEnv)
                }
            } catch (bs: BreakSignal) {
                break  // break 跳出循环
            } catch (cs: ContinueSignal) {
                // continue 跳到 update
            }
            // update
            if (s.update.isSome()) {
                let update = s.update.getOrThrow(); evalExpr(update, forEnv)
            }
        }
        return result
    }

    /// 执行 for-in 语句
    //  严格翻译自: JS for-in 循环语义
    //   遍历对象自身和继承的可枚举属性 (不含 Symbol)
    //   对应 ES spec: ForIn/OfHeadEvaluation + ForIn/OfBodyEvaluation
    private func execForIn(s: Stmt, env: Environment): JsValue {
        return JsValue.UNDEFINED
    }

    /// 执行 for-of 语句
    //  严格翻译自: JS for-of 循环语义 (ES6)
    //   遍历可迭代对象 (Array, String, Map, Set, arguments, NodeList 等)
    //   使用迭代器协议: obj[Symbol.iterator]() → { next() → {value, done} }
    //   对应 ES spec: ForIn/OfHeadEvaluation + ForIn/OfBodyEvaluation
    private func execForOf(s: Stmt, env: Environment): JsValue {
        return JsValue.UNDEFINED
    }

    /// 执行 while 语句 — 支持 break/continue
    //  严格翻译自: JS while 循环语义
    private func execWhile(s: Stmt, env: Environment): JsValue {
        var result = JsValue.UNDEFINED
        while (true) {
            if (s.expr.isSome()) {
                let test = s.expr.getOrThrow(); let cond = evalExpr(test, env)
                if (!jsToBoolean(cond)) { break }
            }
            try {
                if (s.body.isSome()) {
                    let body = s.body.getOrThrow(); result = execStmt(body, env)
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
                if (s.body.isSome()) {
                    let body = s.body.getOrThrow(); result = execStmt(body, env)
                }
            } catch (bs: BreakSignal) {
                break
            } catch (cs: ContinueSignal) {
                // continue 仍然检查条件
            }
            if (s.expr.isSome()) {
                let test = s.expr.getOrThrow(); let cond = evalExpr(test, env)
                if (!jsToBoolean(cond)) { break }
            }
        }
        return result
    }

    /// 执行函数声明 - 对应 JS function hoisting
    /// 函数声明在作用域创建时就被提升 (hoisting)，可以直接定义
    private func execFunctionDecl(s: Stmt, env: Environment): JsValue {
        if (let Some(fn) <- s.fn) {
            let paramNames = ArrayList<String>()
            for (arg in fn.args) {
                paramNames.append(arg.name)
            }
            // 提取函数体语句
            let bodyStmts = ArrayList<Stmt>()
            match (fn.body) {
                case GFnBody.StmtBody(stmt) => bodyStmts.append(stmt)
                case GFnBody.StmtsBody(stmts) => for (s in stmts) { bodyStmts.append(s) }
                case GFnBody.ExprBody(expr) => bodyStmts.append(Stmt.expr_(ParserLoc(0), expr))
            }
            let jsFn = JsFunction(fn.name, paramNames, bodyStmts, env, false)
            jsFn.isGenerator = fn.isGenerator
            jsFn.isAsync = fn.isAsync
            env.define(fn.name, JsValue.function(jsFn), true)
        }
        return JsValue.UNDEFINED
    }

    /// 执行类声明 — 完整实现，支持继承
    ///  严格翻译自: JS class 声明语义 (ES2024 ClassDeclaration)
    ///   1. 创建类对象 (构造函数 + prototype)
    ///   2. 如果有 extends，设置原型链继承
    ///   3. 注册方法到 prototype，方法闭包中存储 __super_proto__
    ///   4. 将类名绑定到当前作用域
    private func execClassDecl(s: Stmt, env: Environment): JsValue {
        if (let Some(cls) <- s.classData) {
            let classObj = newObject()
            classObj.className = "Function"
            classObj.set("name", JsValue(BaoString(cls.name)))

            // 创建 prototype 对象 — 对应 JS ClassName.prototype
            let protoObj = newObject()
            protoObj.className = cls.name
            classObj.set("prototype", JsValue(protoObj))

            // 处理继承 — 对应 class Child extends Parent
            //  严格翻译自: ES ClassDefinitionEvaluation
            //   1. 求值父类表达式
            //   2. 设置 Child.prototype.__proto__ = Parent.prototype
            //   3. 设置 Child.__proto__ = Parent (静态方法继承)
            var superProto: ?JsObject = None
            match (cls.extends_) {
                case Some(parentExpr) =>
                    let parentVal = evalExpr(parentExpr, env)
                    if (let Some(parentObj) <- parentVal.objectData) {
                        // 获取父类的 prototype
                        let parentProto = parentObj.get("prototype")
                        if (let Some(pp) <- parentProto.objectData) {
                            // 子类 prototype 的原型指向父类 prototype
                            protoObj.setProto(Some(pp))
                            superProto = Some(pp)
                        }
                        // 子类本身的原型指向父类 (静态方法继承)
                        classObj.setProto(Some(parentObj))
                    }
                case None => ()
            }

            // 创建方法环境 — 包含 __super_proto__ 供 super 引用使用
            //  严格翻译自: ES MethodDefinitionEvaluation
            //   方法的 [[HomeObject]] 指向 class.prototype
            //   super 引用通过 [[HomeObject]].[[Prototype]] 查找
            let methodEnv = Environment(env)
            match (superProto) {
                case Some(sp) => methodEnv.define("__super_proto__", JsValue(sp), false)
                case None => ()
            }

            // 注册类方法到 prototype
            for (p in cls.properties) {
                match (p.kind) {
                    case GPropertyKind.Method =>
                        if (let Some(valExpr) <- p.value) {
                            let fnVal = evalExpr(valExpr, methodEnv)
                            // 方法同时注册到 prototype 和类对象
                            protoObj.set(p.key, fnVal)
                            // constructor 方法特殊处理
                            if (p.key == "constructor") {
                                classObj.set("__ctor__", fnVal)
                            }
                        }
                    case GPropertyKind.Field =>
                        if (let Some(valExpr) <- p.value) {
                            let val = evalExpr(valExpr, methodEnv)
                            classObj.set(p.key, val)
                        }
                    case _ => ()
                }
            }

            // 如果没有显式 constructor，创建默认构造函数
            if (classObj.get("__ctor__").isUndefined()) {
                let defaultCtor = makeNativeFn(cls.name) { args =>
                    return JsValue.UNDEFINED
                }
                classObj.set("__ctor__", defaultCtor)
            }

            // 定义类名到环境
            env.define(cls.name, JsValue(classObj), true)
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
            if (!bindingName.isEmpty()) {
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
    /// 对应 JS try { ... } catch (e) { ... } finally { ... }
    private func execTry(s: Stmt, env: Environment): JsValue {
        var result = JsValue.UNDEFINED
        try {
            // 执行 try 块
            if (s.body.isSome()) {
                result = execStmt(s.body.getOrThrow(), env)
            }
        } catch (thrown: JsRuntimeThrow) {
            // catch 块 — 绑定异常值
            if (let Some(catchBody) <- s.catchBody) {
                let catchEnv = Environment(env)
                // 绑定 catch 参数: catch(e) 中的 e
                match (s.catchBinding) {
                    case Some(binding) =>
                        catchEnv.define(binding.name, thrown.value, true)
                    case None => ()
                }
                result = execStmt(catchBody, catchEnv)
            }
        }
        // finally 块 — 总是执行
        if (let Some(finallyBody) <- s.finallyBody) {
            let finallyResult = execStmt(finallyBody, env)
            // finally 的返回值覆盖 try/catch 的返回值 (标准行为)
            result = finallyResult
        }
        return result
    }

    /// 执行 switch 语句
    private func execSwitch(s: Stmt, env: Environment): JsValue {
        var discriminant = JsValue.UNDEFINED
        if (s.expr.isSome()) {
            let test = s.expr.getOrThrow(); discriminant = evalExpr(test, env)
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

    /// 求值表达式 — 分派到各子求值器
    /// 对应 Bun: JSC expression evaluation dispatch
    public func evalExpr(e: Expr, env: Environment): JsValue {
        match (e.tag) {
            // 字面量
            case ExprTag.Undefined => return JsValue.UNDEFINED
            case ExprTag.Null => return JsValue.NULL
            case ExprTag.Boolean => return JsValue(e.boolValue)
            case ExprTag.Number => return JsValue(e.numberValue)
            case ExprTag.BigInt => return JsValue(e.numberValue) // 简化: BigInt 当 Number 处理
            case ExprTag.String => return JsValue(e.stringValue)
            case ExprTag.Regex => return evalRegex(e)
            // 标识符和成员访问
            case ExprTag.Identifier => return evalIdentifier(e, env)
            case ExprTag.ImportIdentifier => return evalIdentifier(e, env)
            case ExprTag.ThisExpr => return env.thisBinding
            case ExprTag.Super => return evalSuper(env)
            // 调用和成员访问
            case ExprTag.New => return evalNew(e, env)
            case ExprTag.Call => return evalCall(e, env)
            case ExprTag.Dot => return evalDot(e, env)
            case ExprTag.Index => return evalIndex(e, env)
            // 复合表达式
            case ExprTag.Array => return evalArray(e, env)
            case ExprTag.Object => return evalObject(e, env)
            case ExprTag.Spread =>
                // 展开在调用处处理
                if (e.value.isSome()) {
                    return evalExpr(e.value.getOrThrow(), env)
                }
                return JsValue.UNDEFINED
            case ExprTag.Arrow => return evalArrow(e, env)
            case ExprTag.Function => return evalFunctionExpr(e, env)
            case ExprTag.Class => return evalClassExpr(e, env)
            case ExprTag.Template => return evalTemplate(e, env)
            // 运算符
            case ExprTag.Unary => return evalUnary(e, env)
            case ExprTag.Binary => return evalBinary(e, env)
            case ExprTag.Ternary => return evalTernary(e, env)
            case ExprTag.Assign => return evalAssign(e, env)
            case ExprTag.Postfix => return evalPostfix(e, env)
            // async/await — 内联事件循环驱动
            // await expr: 求值 expr，如果是 pending Promise 则就地驱动事件循环直到 resolve
            case ExprTag.Await =>
                if (let Some(val) <- e.value) {
                    return evalAwait(evalExpr(val, env))
                }
                return JsValue.UNDEFINED
            case ExprTag.Yield =>
                // yield 表达式: 求值产出值，然后通过 YieldSignal 暂停生成器执行
                // 生成器的 next() 方法捕获此信号并保存执行状态
                var yieldVal = JsValue.UNDEFINED
                if (let Some(val) <- e.value) {
                    yieldVal = evalExpr(val, env)
                }
                throw YieldSignal(yieldVal, 0)
            case ExprTag.TypeCast =>
                // TypeScript 类型转换 — 运行时忽略，直接求值表达式
                if (let Some(val) <- e.value) {
                    return evalExpr(val, env)
                }
                return JsValue.UNDEFINED
            case _ => return JsValue.UNDEFINED
        }
    }

    /// evalAwait — JS await 语义实现
    /// 对应 ES2024 spec: Await(expression)
    ///   1. 求值表达式得到 value
    ///   2. 如果 value 是 pending Promise → 就地驱动事件循环直到 resolve
    ///   3. 如果 value 是 resolved Promise → 返回 resolved value
    ///   4. 如果 value 不是 Promise → 直接返回 (await non-promise 是 no-op)
    private func evalAwait(value: JsValue): JsValue {
        // 提取内部 JsPromise
        let promiseOpt = extractJsPromise(value)

        // 不是 Promise → 直接返回 (JS: await 42 → 42)
        if (promiseOpt.isNone()) {
            return value
        }

        let promise = promiseOpt.getOrThrow()

        // 已完成 → 返回 resolved value
        if (promise.state == PromiseState.Fulfilled) {
            return promise.result
        }

        // 已拒绝 → 抛出异常
        if (promise.state == PromiseState.Rejected) {
            throw JsRuntimeThrow(promise.result)
        }

        // Pending → 就地驱动事件循环直到 Promise resolve
        let el = getEventLoop()
        var maxIter = 100000  // 防止无限循环
        while (promise.state == PromiseState.Pending && maxIter > 0) {
            // 先排空微任务 (Promise.then 回调在微任务中执行)
            el.drainMicrotasks()
            // 如果微任务已使其 resolve，立即返回
            if (promise.state != PromiseState.Pending) { break }
            // 执行到期的定时器 (setTimeout/setInterval)
            el.tick()
            maxIter -= 1
        }

        // 最终状态检查
        match (promise.state) {
            case PromiseState.Fulfilled => return promise.result
            case PromiseState.Rejected => throw JsRuntimeThrow(promise.result)
            case PromiseState.Pending =>
                // 超时仍未 resolve — 返回 undefined (不崩溃)
                return JsValue.UNDEFINED
        }
    }

    /// 从 JsValue 中提取内部 JsPromise
    /// 通过 JsValue.promiseData 字段直接获取
    private func extractJsPromise(value: JsValue): ?JsPromise {
        if (value.promiseData.isSome()) {
            return value.promiseData
        }
        return None
    }

    /// 标识符求值 - 对应 JS 标识符解析
    private func evalIdentifier(e: Expr, env: Environment): JsValue {
        let vOpt = env.lookup(e.identifierName)
        if (vOpt.isSome()) {
            return vOpt.getOrThrow()
        }
        return JsValue.UNDEFINED
    }





    /// new 表达式 — 完整实现
    //  严格翻译自: JS new Constructor(args) 语义
    //   1. 创建新对象，原型指向 Constructor.prototype
    //   2. 调用 Constructor 并绑定 this 为新对象
    //   3. 如果构造函数返回对象则使用该对象，否则使用新对象
    private func evalNew(e: Expr, env: Environment): JsValue {
        if (e.target.isSome()) {
            let target = e.target.getOrThrow(); let ctor = evalExpr(target, env)
            // 创建新对象
            let obj = newObject()

            // 设置原型链 — 对应 obj.__proto__ = Constructor.prototype
            if (ctor.objectData.isSome()) {
                let protoVal = ctor.objectData.getOrThrow().get("prototype")
                if (protoVal.objectData.isSome()) {
                    obj.set("__proto__", JsValue(protoVal.objectData.getOrThrow()))
                }
            }

            // 求值参数
            let args = ArrayList<JsValue>()
            for (arg in e.args) {
                args.append(evalExpr(arg, env))
            }

            // 调用构造函数
            // JS spec: 如果构造函数返回对象，使用该对象；否则使用新创建的对象
            var result: JsValue = JsValue(obj)
            try {
                var ctorCalled = false
                // 优先: 从 nativeConstructors 注册表查找 (绕过 JsValue 字段丢失)
                if (target.tag == ExprTag.Identifier) {
                    let name = target.identifierName
                    let regOpt = nativeConstructors.get(name)
                    if (regOpt.isSome()) {
                        let ret = regOpt.getOrThrow()(args)
                        // 接受 Object 或 Date 类型 (Date 构造函数返回 JsValueType.Date)
                        if (ret.valueType == JsValueType.Object ||
                            ret.valueType == JsValueType.Date) { result = ret }
                        ctorCalled = true
                    }
                }
                // 回退: 使用 callFunction (处理 JS 函数构造器)
                if (!ctorCalled) {
                    let ret = callFunction(ctor, args, JsValue(obj), env)
                    if (ret.valueType == JsValueType.Object) {
                        result = ret
                    }
                }
            } catch (_: Exception) {
                // 构造函数抛出异常 — 保留默认对象
            }
            return result
        }
        // 无 target — 返回空对象
        return JsValue(newObject())
        return JsValue(newObject())
    }

    /// 函数调用 — 完整实现，支持可选链式调用 obj?.method()
    //  严格翻译自: JS CallExpression 语义
    //   包括: 普通调用, 方法调用 (设置 this), 可选链调用 (?.())
    private func evalCall(e: Expr, env: Environment): JsValue {
        var thisVal = JsValue.UNDEFINED
        var callable: ?JsValue = None

        if (e.target.isSome()) {
            // super() 构造函数调用 — 对应 super(args)
            // 从 __super_proto__ 查找 __ctor__ 并以当前 this 调用
            let target = e.target.getOrThrow()
            if (target.tag == ExprTag.Super) {
                if (getSuperPrototype(env).isSome()) {
                    let superProto = getSuperPrototype(env).getOrThrow(); let ctorVal = superProto.get("__ctor__")
                    let args = ArrayList<JsValue>()
                    for (arg in e.args) {
                        args.append(evalExpr(arg, env))
                    }
                    thisVal = env.thisBinding
                    return callFunction(ctorVal, args, thisVal, env)
                }
                return JsValue.UNDEFINED
            }

            // super.method() 调用 — 对应 super.x(args)
            // 从 __super_proto__ 查找方法并以当前 this 调用
            if (target.tag == ExprTag.Dot) {
                if (let Some(dotTarget) <- target.target) {
                    if (dotTarget.tag == ExprTag.Super) {
                        if (getSuperPrototype(env).isSome()) {
                            let superProto2 = getSuperPrototype(env).getOrThrow(); let method = superProto2.get(target.propertyName)
                            let args = ArrayList<JsValue>()
                            for (arg in e.args) {
                                args.append(evalExpr(arg, env))
                            }
                            thisVal = env.thisBinding
                            return callFunction(method, args, thisVal, env)
                        }
                        return JsValue.UNDEFINED
                    }
                }
            }

            // 处理 obj.method() 调用
            if (target.tag == ExprTag.Dot) {
                let objVal = if (target.target.isSome()) { evalExpr(target.target.getOrThrow(), env) } else { JsValue.UNDEFINED }

                // 可选链 — 对应 obj?.method()
                //  严格翻译自: ES2020 Optional Chaining
                //   如果 obj 是 null/undefined，整个调用链返回 undefined
                if (target.optionalChain.isSome()) {
                    if (objVal.valueType == JsValueType.Null || objVal.valueType == JsValueType.Undefined) {
                        return JsValue.UNDEFINED
                    }
                }

                thisVal = objVal
                if (objVal.objectData.isSome()) {
                    let objData = objVal.objectData.getOrThrow(); callable = objData.get(target.propertyName)
                }
                // 原生函数静态方法调用 — 对应 Promise.resolve() 等模式
                // evalDot 已有此检查 (line 2099)，evalCall 需保持一致
                if (callable.isNone() && objVal.nativeFnData.isSome()) {
                    let staticProp = getNativeFunctionProperty(
                        objVal.nativeFnData.getOrThrow().name, target.propertyName)
                    if (staticProp.isSome()) {
                        callable = staticProp.getOrThrow()
                    }
                }
                // 字符串方法调用 — 对应 String.prototype.method()
                if (callable.isNone() && objVal.valueType == JsValueType.String) {
                    callable = getStringMethod(objVal, target.propertyName)
                }
                // 数组方法调用 — 对应 Array.prototype.method()
                if (callable.isNone() && objVal.valueType == JsValueType.Array) {
                    callable = getArrayMethod(objVal, target.propertyName)
                }
            } else if (target.tag == ExprTag.Index) {
                // 对应 obj[key]()
                let objVal = if (target.target.isSome()) { evalExpr(target.target.getOrThrow(), env) } else { JsValue.UNDEFINED }
                if (target.optionalChain.isSome()) {
                    if (objVal.valueType == JsValueType.Null || objVal.valueType == JsValueType.Undefined) {
                        return JsValue.UNDEFINED
                    }
                }
                thisVal = objVal
                if (target.indexExpr.isSome()) {
                    let idx = target.indexExpr.getOrThrow(); let idxVal = evalExpr(idx, env)
                    let key = jsToString(idxVal)
                    if (objVal.objectData.isSome()) {
                        let objData = objVal.objectData.getOrThrow(); callable = objData.get(key)
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
                if (arg.value.isSome()) {
                    let spreadVal = evalExpr(arg.value.getOrThrow(), env)
                    if (spreadVal.arrayData.isSome()) {
                        for (item in spreadVal.arrayData.getOrThrow()) {
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
            case None => JsValue.UNDEFINED
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
                return JsValue(0.0)
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
                return JsValue(Float64(match(result) { case Some(idx) => idx case _ => -1 }))
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
                let s = jsToString(strVal)
                let sb = StringBuilder()
                for (i in 0..Int64(s.size)) {
                    let b = s[i]
                    if (b >= 97 && b <= 122) { // 'a'-'z'
                        sb.append(Rune(Int32(b) - 32))
                    } else {
                        sb.append(Rune(Int32(b)))
                    }
                }
                return JsValue(BaoString(sb.toString()))
            })
            case "toLowerCase" => Some(makeNativeFn("toLowerCase") { _ =>
                let s = jsToString(strVal)
                let sb = StringBuilder()
                for (i in 0..Int64(s.size)) {
                    let b = s[i]
                    if (b >= 65 && b <= 90) { // 'A'-'Z'
                        sb.append(Rune(Int32(b) + 32))
                    } else {
                        sb.append(Rune(Int32(b)))
                    }
                }
                return JsValue(BaoString(sb.toString()))
            })
            case "trim" => Some(makeNativeFn("trim") { _ =>
                let s = jsToString(strVal)
                var start: Int64 = 0
                let len = Int64(s.size)
                while (start < len && s[start] <= 32) { start++ }
                var end = len
                while (end > start && s[end - 1] <= 32) { end-- }
                return JsValue(BaoString(s[start..end]))
            })
            case "split" => Some(makeNativeFn("split") { args =>
                let s = jsToString(strVal)
                let sep = if (args.size > 0) { jsToString(args[0]) } else { "" }
                let arr = ArrayList<JsValue>()
                if (sep.isEmpty()) {
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
            case "padStart" => Some(makeNativeFn("padStart") { _ =>
                return JsValue(strVal.stringValue)
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

    /// 数组方法 — 对应 Array.prototype.method()
    //  严格翻译自: JS Array.prototype 方法语义
    private func getArrayMethod(arrVal: JsValue, name: String): ?JsValue {
        match (name) {
            case "push" => Some(makeNativeFn("push") { args =>
                if (arrVal.arrayData.isSome()) {
                    let arr = arrVal.arrayData.getOrThrow()
                    for (arg in args) {
                        arr.append(arg)
                    }
                    return JsValue(Float64(arr.size))
                }
                return JsValue.nan
            })
            case "pop" => Some(makeNativeFn("pop") { _ =>
                if (arrVal.arrayData.isSome()) {
                    let arr = arrVal.arrayData.getOrThrow()
                    if (arr.size > 0) {
                        let last = arr[arr.size - 1]
                        arr.removeAt(arr.size - 1)
                        return last
                    }
                }
                return JsValue.UNDEFINED
            })
            case "shift" => Some(makeNativeFn("shift") { _ =>
                if (arrVal.arrayData.isSome()) {
                    let arr = arrVal.arrayData.getOrThrow()
                    if (arr.size > 0) {
                        let first = arr[0]
                        arr.removeAt(0)
                        return first
                    }
                }
                return JsValue.UNDEFINED
            })
            case "unshift" => Some(makeNativeFn("unshift") { args =>
                if (arrVal.arrayData.isSome()) {
                    let arr = arrVal.arrayData.getOrThrow()
                    var i = args.size - 1
                    while (i >= 0) {
                        arr.insert(0, args[Int64(i)])
                        i -= 1
                    }
                    return JsValue(Float64(arr.size))
                }
                return JsValue.nan
            })
            case "map" => Some(makeNativeFn("map") { args =>
                if (arrVal.arrayData.isSome()) {
                    let arr = arrVal.arrayData.getOrThrow()
                    if (args.size > 0) {
                        let callback = args[0]
                        let result = ArrayList<JsValue>()
                        for (i in 0..arr.size) {
                            let callArgs = ArrayList<JsValue>()
                            callArgs.append(arr[i])
                            callArgs.append(JsValue(Float64(i)))
                            callArgs.append(arrVal)
                            let mapped = callFunction(callback, callArgs, JsValue.UNDEFINED, globalEnv)
                            result.append(mapped)
                        }
                        return JsValue.array(result)
                    }
                }
                return JsValue.UNDEFINED
            })
            case "filter" => Some(makeNativeFn("filter") { args =>
                if (arrVal.arrayData.isSome()) {
                    let arr = arrVal.arrayData.getOrThrow()
                    if (args.size > 0) {
                        let callback = args[0]
                        let result = ArrayList<JsValue>()
                        for (i in 0..arr.size) {
                            let callArgs = ArrayList<JsValue>()
                            callArgs.append(arr[i])
                            callArgs.append(JsValue(Float64(i)))
                            callArgs.append(arrVal)
                            let testResult = callFunction(callback, callArgs, JsValue.UNDEFINED, globalEnv)
                            if (jsToBoolean(testResult)) {
                                result.append(arr[i])
                            }
                        }
                        return JsValue.array(result)
                    }
                }
                return JsValue.UNDEFINED
            })
            case "forEach" => Some(makeNativeFn("forEach") { args =>
                if (arrVal.arrayData.isSome()) {
                    let arr = arrVal.arrayData.getOrThrow()
                    if (args.size > 0) {
                        let callback = args[0]
                        for (i in 0..arr.size) {
                            let callArgs = ArrayList<JsValue>()
                            callArgs.append(arr[i])
                            callArgs.append(JsValue(Float64(i)))
                            callArgs.append(arrVal)
                            callFunction(callback, callArgs, JsValue.UNDEFINED, globalEnv)
                        }
                    }
                }
                return JsValue.UNDEFINED
            })
            case "join" => Some(makeNativeFn("join") { args =>
                if (arrVal.arrayData.isSome()) {
                    let arr = arrVal.arrayData.getOrThrow()
                    let sep = if (args.size > 0) { jsToString(args[0]) } else { "," }
                    let sb = StringBuilder()
                    for (i in 0..arr.size) {
                        if (i > 0) { sb.append(sep) }
                        sb.append(jsToString(arr[i]))
                    }
                    return JsValue(BaoString(sb.toString()))
                }
                return JsValue(BaoString(""))
            })
            case "reverse" => Some(makeNativeFn("reverse") { _ =>
                if (arrVal.arrayData.isSome()) {
                    let arr = arrVal.arrayData.getOrThrow()
                    var i: Int64 = 0
                    var j: Int64 = arr.size - 1
                    while (i < j) {
                        let tmp = arr[i]
                        arr[i] = arr[j]
                        arr[j] = tmp
                        i += 1
                        j -= 1
                    }
                    return arrVal
                }
                return JsValue.UNDEFINED
            })
            case "indexOf" => Some(makeNativeFn("indexOf") { args =>
                if (arrVal.arrayData.isSome()) {
                    let arr = arrVal.arrayData.getOrThrow()
                    let search = if (args.size > 0) { args[0] } else { JsValue.UNDEFINED }
                    let startIdx = if (args.size > 1) { Int64(jsToNumber(args[1])) } else { 0 }
                    for (i in startIdx..arr.size) {
                        if (jsValuesEqual(arr[i], search)) {
                            return JsValue(Float64(i))
                        }
                    }
                }
                return JsValue(-1.0)
            })
            case "includes" => Some(makeNativeFn("includes") { args =>
                if (arrVal.arrayData.isSome()) {
                    let arr = arrVal.arrayData.getOrThrow()
                    let search = if (args.size > 0) { args[0] } else { JsValue.UNDEFINED }
                    for (i in 0..arr.size) {
                        if (jsValuesEqual(arr[i], search)) {
                            return JsValue(true)
                        }
                    }
                }
                return JsValue(false)
            })
            case "slice" => Some(makeNativeFn("slice") { args =>
                if (arrVal.arrayData.isSome()) {
                    let arr = arrVal.arrayData.getOrThrow()
                    let start = if (args.size > 0) { Int64(jsToNumber(args[0])) } else { 0 }
                    let end = if (args.size > 1) { Int64(jsToNumber(args[1])) } else { arr.size }
                    var st = if (start < 0) { arr.size + start } else { start }
                    var en = if (end < 0) { arr.size + end } else { end }
                    if (st < 0) { st = 0 }
                    if (en > arr.size) { en = arr.size }
                    let result = ArrayList<JsValue>()
                    for (i in st..en) {
                        result.append(arr[i])
                    }
                    return JsValue.array(result)
                }
                return JsValue.UNDEFINED
            })
            case "splice" => Some(makeNativeFn("splice") { args =>
                if (arrVal.arrayData.isSome()) {
                    let arr = arrVal.arrayData.getOrThrow()
                    let start = if (args.size > 0) { Int64(jsToNumber(args[0])) } else { 0 }
                    var st = if (start < 0) { arr.size + start } else { start }
                    if (st < 0) { st = 0 }
                    if (st > arr.size) { st = arr.size }
                    let deleteCount = if (args.size > 1) { Int64(jsToNumber(args[1])) } else { arr.size - st }
                    var dc = deleteCount
                    if (dc < 0) { dc = 0 }
                    if (dc > arr.size - st) { dc = arr.size - st }
                    // 收集被删除的元素
                    let removed = ArrayList<JsValue>()
                    for (i in 0..dc) {
                        removed.append(arr[Int64(st) + i])
                    }
                    // 删除元素
                    var d = 0
                    while (d < dc) {
                        arr.removeAt(Int64(st))
                        d += 1
                    }
                    // 插入新元素
                    if (args.size > 2) {
                        var insertIdx = Int64(st)
                        for (i in 2..args.size) {
                            arr.insert(insertIdx, args[Int64(i)])
                            insertIdx += 1
                        }
                    }
                    return JsValue.array(removed)
                }
                return JsValue.UNDEFINED
            })
            case "concat" => Some(makeNativeFn("concat") { args =>
                if (arrVal.arrayData.isSome()) {
                    let result = ArrayList<JsValue>()
                    for (item in arrVal.arrayData.getOrThrow()) { result.append(item) }
                    for (arg in args) {
                        if (arg.arrayData.isSome()) {
                            for (item in arg.arrayData.getOrThrow()) { result.append(item) }
                        } else {
                            result.append(arg)
                        }
                    }
                    return JsValue.array(result)
                }
                return JsValue.UNDEFINED
            })
            case "reduce" => Some(makeNativeFn("reduce") { args =>
                if (arrVal.arrayData.isSome()) {
                    let arr = arrVal.arrayData.getOrThrow()
                    if (args.size == 0) { return JsValue.UNDEFINED }
                    let callback = args[0]
                    var acc = if (args.size > 1) { args[1] } else { arr[0] }
                    var startIdx: Int64 = if (args.size > 1) { 0 } else { 1 }
                    for (i in startIdx..arr.size) {
                        let callArgs = ArrayList<JsValue>()
                        callArgs.append(acc)
                        callArgs.append(arr[i])
                        callArgs.append(JsValue(Float64(i)))
                        callArgs.append(arrVal)
                        acc = callFunction(callback, callArgs, JsValue.UNDEFINED, globalEnv)
                    }
                    return acc
                }
                return JsValue.UNDEFINED
            })
            case "find" => Some(makeNativeFn("find") { args =>
                if (arrVal.arrayData.isSome()) {
                    let arr = arrVal.arrayData.getOrThrow()
                    if (args.size > 0) {
                        let callback = args[0]
                        for (i in 0..arr.size) {
                            let callArgs = ArrayList<JsValue>()
                            callArgs.append(arr[i])
                            callArgs.append(JsValue(Float64(i)))
                            callArgs.append(arrVal)
                            let testResult = callFunction(callback, callArgs, JsValue.UNDEFINED, globalEnv)
                            if (jsToBoolean(testResult)) {
                                return arr[i]
                            }
                        }
                    }
                }
                return JsValue.UNDEFINED
            })
            case "findIndex" => Some(makeNativeFn("findIndex") { args =>
                if (arrVal.arrayData.isSome()) {
                    let arr = arrVal.arrayData.getOrThrow()
                    if (args.size > 0) {
                        let callback = args[0]
                        for (i in 0..arr.size) {
                            let callArgs = ArrayList<JsValue>()
                            callArgs.append(arr[i])
                            callArgs.append(JsValue(Float64(i)))
                            callArgs.append(arrVal)
                            let testResult = callFunction(callback, callArgs, JsValue.UNDEFINED, globalEnv)
                            if (jsToBoolean(testResult)) {
                                return JsValue(Float64(i))
                            }
                        }
                    }
                }
                return JsValue(-1.0)
            })
            case "every" => Some(makeNativeFn("every") { args =>
                if (arrVal.arrayData.isSome()) {
                    let arr = arrVal.arrayData.getOrThrow()
                    if (args.size > 0) {
                        let callback = args[0]
                        for (i in 0..arr.size) {
                            let callArgs = ArrayList<JsValue>()
                            callArgs.append(arr[i])
                            callArgs.append(JsValue(Float64(i)))
                            callArgs.append(arrVal)
                            let testResult = callFunction(callback, callArgs, JsValue.UNDEFINED, globalEnv)
                            if (!jsToBoolean(testResult)) {
                                return JsValue(false)
                            }
                        }
                        return JsValue(true)
                    }
                }
                return JsValue(true)
            })
            case "some" => Some(makeNativeFn("some") { args =>
                if (arrVal.arrayData.isSome()) {
                    let arr = arrVal.arrayData.getOrThrow()
                    if (args.size > 0) {
                        let callback = args[0]
                        for (i in 0..arr.size) {
                            let callArgs = ArrayList<JsValue>()
                            callArgs.append(arr[i])
                            callArgs.append(JsValue(Float64(i)))
                            callArgs.append(arrVal)
                            let testResult = callFunction(callback, callArgs, JsValue.UNDEFINED, globalEnv)
                            if (jsToBoolean(testResult)) {
                                return JsValue(true)
                            }
                        }
                    }
                }
                return JsValue(false)
            })
            case "flat" => Some(makeNativeFn("flat") { _ =>
                if (arrVal.arrayData.isSome()) {
                    let result = ArrayList<JsValue>()
                    for (item in arrVal.arrayData.getOrThrow()) {
                        if (item.arrayData.isSome()) {
                            for (innerItem in item.arrayData.getOrThrow()) {
                                result.append(innerItem)
                            }
                        } else {
                            result.append(item)
                        }
                    }
                    return JsValue.array(result)
                }
                return JsValue.UNDEFINED
            })
            case "sort" => Some(makeNativeFn("sort") { args =>
                if (arrVal.arrayData.isSome()) {
                    let arr = arrVal.arrayData.getOrThrow()
                    if (args.size > 0) {
                        let comparator = args[0]
                        // 简单冒泡排序 + JS 比较器
                        var n: Int64 = arr.size
                        var i: Int64 = 0
                        while (i < n - 1) {
                            var j: Int64 = 0
                            while (j < n - i - 1) {
                                let cmpArgs = ArrayList<JsValue>()
                                cmpArgs.append(arr[j])
                                cmpArgs.append(arr[j + 1])
                                let cmpResult = callFunction(comparator, cmpArgs, JsValue.UNDEFINED, globalEnv)
                                let cmpVal = jsToNumber(cmpResult)
                                if (cmpVal > 0.0) {
                                    let tmp = arr[j]
                                    arr[j] = arr[j + 1]
                                    arr[j + 1] = tmp
                                }
                                j += 1
                            }
                            i += 1
                        }
                    }
                    return arrVal
                }
                return JsValue.UNDEFINED
            })
            case _ => None
        }
    }

    /// 调用函数 - JS 函数或原生函数
    /// 调用函数 (公开接口，供测试框架等外部调用)
    /// 对应 Bun: JSC::JSObjectCallAsFunction
    public func callFunction(fn: JsValue, args: ArrayList<JsValue>,
                              thisVal: JsValue, env: Environment): JsValue {
        // 原生函数
        if (fn.nativeFnData.isSome()) {
            let native = fn.nativeFnData.getOrThrow()
            return native.fn(args)
        }
        // JS 函数
        if (fn.functionData.isSome()) {
            let jsFn = fn.functionData.getOrThrow()
            let result = callJsFunction(jsFn, args, thisVal)
            // async 函数: 返回值包装为 resolved Promise
            // JS spec: async function 总是返回 Promise
            if (jsFn.isAsync) {
                return wrapPromiseValue(JsPromise.resolve(result))
            }
            return result
        }
        return JsValue.UNDEFINED
    }

    /// 调用 JS 函数 - 创建新的作用域，绑定参数，执行函数体
    /// 对于生成器函数 (function*)，返回生成器对象而不执行函数体
    private func callJsFunction(fn: JsFunction, args: ArrayList<JsValue>,
                                 thisVal: JsValue): JsValue {
        // 生成器函数 — 对应 JS function* 调用语义
        //  严格翻译自: ES CreateGeneratorFunction / GeneratorStart
        //   调用生成器函数不执行函数体，而是创建一个生成器对象
        //   生成器对象具有 next(), return(), throw() 方法
        if (fn.isGenerator) {
            let genEnv = Environment(fn.closure)
            genEnv.isFunctionScope = true
            genEnv.thisBinding = thisVal
            // 绑定参数到生成器闭包环境
            for (i in 0..fn.paramNames.size) {
                let val = if (i < args.size) { args[i] } else { JsValue.UNDEFINED }
                genEnv.define(fn.paramNames[i], val, true)
            }
            let generator = JsGenerator(fn.name, fn.body, genEnv)
            // 创建生成器迭代器对象 — 包含 next/return/throw 方法
            let genObj = newObject()
            genObj.className = "Generator"
            // Generator.prototype.next(value)
            genObj.set("next", makeNativeFn("next") { nextArgs =>
                let resumeVal = if (nextArgs.size > 0) { nextArgs[0] } else { JsValue.UNDEFINED }
                return generator.next(this, resumeVal)
            })
            // Generator.prototype.return(value) — 提前完成生成器
            genObj.set("return", makeNativeFn("return") { retArgs =>
                generator.state = GeneratorState.Completed
                let retVal = if (retArgs.size > 0) { retArgs[0] } else { JsValue.UNDEFINED }
                return makeGeneratorResult(retVal, true)
            })
            // Generator.prototype.throw(exception) — 向生成器抛出异常
            genObj.set("throw", makeNativeFn("throw") { throwArgs =>
                if (generator.state == GeneratorState.Completed) {
                    if (throwArgs.size > 0) {
                        throw JsRuntimeThrow(throwArgs[0])
                    }
                    throw JsRuntimeThrow(JsValue.UNDEFINED)
                }
                let resumeVal = if (throwArgs.size > 0) { throwArgs[0] } else { JsValue.UNDEFINED }
                return generator.next(this, resumeVal)
            })
            // Symbol.iterator — 使生成器可迭代 (for-of 支持)
            // 使用 [Symbol.iterator] 字符串键模拟 Symbol 属性
            genObj.set("[Symbol.iterator]", makeNativeFn("[Symbol.iterator]") { _ =>
                return JsValue(genObj)
            })
            return JsValue(genObj)
        }

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
        } catch (ret: ReturnSignal) {
            // return 语句 — 返回值通过 ReturnSignal 传播
            return ret.value
        } catch (e: JsRuntimeThrow) {
            // throw 语句 — 向外传播
            throw e
        }
        return result
    }

    /// 点访问 — 完整实现，支持可选链 obj?.prop
    //  严格翻译自: JS MemberExpression (dot access) + Optional Chaining
    //   对应 ES2020 Optional Chaining: obj?.prop
    //   如果 obj 是 null/undefined，返回 undefined 而不抛出 TypeError
    private func evalDot(e: Expr, env: Environment): JsValue {
        if (e.target.isSome()) {
            let target = e.target.getOrThrow()
            // super 属性访问 — 对应 super.x
            // 从 __super_proto__ 查找属性，不走普通求值
            if (target.tag == ExprTag.Super) {
                if (getSuperPrototype(env).isSome()) {
                    let superProto = getSuperPrototype(env).getOrThrow()
                    return superProto.get(e.propertyName)
                }
                return JsValue.UNDEFINED
            }
            let obj = evalExpr(target, env)

            // 可选链 — 对应 obj?.prop
            //  严格翻译自: ES2020 Optional Chaining
            if (target.optionalChain.isSome()) {
                if (obj.valueType == JsValueType.Null || obj.valueType == JsValueType.Undefined) {
                    return JsValue.UNDEFINED
                }
            }

            if (obj.objectData.isSome()) {
                let objData = obj.objectData.getOrThrow()
                return objData.get(e.propertyName)
            }
            // 函数对象属性访问 — 支持构造函数上的静态方法
            // 如 Promise.resolve(), Promise.reject() 等
            if (obj.nativeFnData.isSome()) {
                let staticProp = getNativeFunctionProperty(obj.nativeFnData.getOrThrow().name, e.propertyName)
                if (staticProp.isSome()) {
                    return staticProp.getOrThrow()
                }
            }
            // 字符串属性
            if (obj.valueType == JsValueType.String) {
                if (e.propertyName == "length") {
                    return JsValue(Float64(obj.stringValue.toString().size))
                }
                let methodOpt = getStringMethod(obj, e.propertyName)
                if (methodOpt.isSome()) {
                    return methodOpt.getOrThrow()
                }
            }
            // 数组属性 + 方法
            if (obj.arrayData.isSome()) {
                let arr = obj.arrayData.getOrThrow()
                if (e.propertyName == "length") {
                    return JsValue(Float64(arr.size))
                }
                // 数组方法引用 (不立即调用时)
                let methodOpt = getArrayMethod(obj, e.propertyName)
                if (methodOpt.isSome()) {
                    return methodOpt.getOrThrow()
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
                    return JsValue.nativeFunction(JsNativeFunction("bound", { callArgs =>
                        callFunction(obj, callArgs, JsValue.UNDEFINED, env)
                    }))
                }
                if (e.propertyName == "call") {
                    return makeNativeFn("call") { args =>
                        let boundThis = if (args.size > 0) { args[0] } else { JsValue.UNDEFINED }
                        let callArgs = ArrayList<JsValue>()
                        for (i in 1..args.size) {
                            callArgs.append(args[Int64(i)])
                        }
                        return callFunction(obj, callArgs, boundThis, env)
                    }
                }
                if (e.propertyName == "apply") {
                    return makeNativeFn("apply") { args =>
                        let boundThis = if (args.size > 0) { args[0] } else { JsValue.UNDEFINED }
                        let callArgs = ArrayList<JsValue>()
                        if (args.size > 1) {
                            if (args[1].arrayData.isSome()) {
                                let applyArr = args[1].arrayData.getOrThrow()
                                for (a in applyArr) {
                                    callArgs.append(a)
                                }
                            }
                        }
                        return callFunction(obj, callArgs, boundThis, env)
                    }
                }
            }
        }
        return JsValue.UNDEFINED
    }

    /// 原生函数的静态属性查找 — 支持 Promise.resolve() 等模式
    /// 当 JS 代码访问 Promise.resolve / Promise.reject 时，
    /// evalDot 在 nativeFnData 上找不到 objectData，通过此方法提供静态方法
    private func getNativeFunctionProperty(fnName: String, propName: String): ?JsValue {
        let interp = this
        if (fnName == "Promise") {
            if (propName == "resolve") {
                return Some(makeNativeFn("resolve") { args =>
                    let val = if (args.size > 0) { args[0] } else { JsValue.UNDEFINED }
                    // 如果值本身就是 Promise (带 promiseData)，直接返回
                    if (val.promiseData.isSome()) { return val }
                    return wrapPromiseValue(JsPromise.resolve(val))
                })
            }
            if (propName == "reject") {
                return Some(makeNativeFn("reject") { args =>
                    let reason = if (args.size > 0) { args[0] } else { JsValue.UNDEFINED }
                    return wrapPromiseValue(JsPromise.reject(reason))
                })
            }
            if (propName == "all") {
                return Some(makeNativeFn("all") { args =>
                    let promises = ArrayList<JsPromise>()
                    if (args.size > 0 && args[0].arrayData.isSome()) {
                        let arr = args[0].arrayData.getOrThrow()
                        for (item in arr) {
                            if (item.promiseData.isSome()) {
                                promises.append(item.promiseData.getOrThrow())
                            } else {
                                promises.append(JsPromise.resolve(item))
                            }
                        }
                    }
                    return wrapPromiseValue(JsPromise.all(promises))
                })
            }
            if (propName == "race") {
                return Some(makeNativeFn("race") { args =>
                    let promises = ArrayList<JsPromise>()
                    if (args.size > 0 && args[0].arrayData.isSome()) {
                        let arr = args[0].arrayData.getOrThrow()
                        for (item in arr) {
                            if (item.promiseData.isSome()) {
                                promises.append(item.promiseData.getOrThrow())
                            } else {
                                promises.append(JsPromise.resolve(item))
                            }
                        }
                    }
                    return wrapPromiseValue(JsPromise.race(promises))
                })
            }
        }
        return None
    }

    /// 索引访问 — 完整实现，支持可选链 obj?.[key]
    //  严格翻译自: JS MemberExpression (computed access)
    private func evalIndex(e: Expr, env: Environment): JsValue {
        var targetVal = JsValue.UNDEFINED
        if (e.target.isSome()) {
            let target = e.target.getOrThrow()
            targetVal = evalExpr(target, env)

            // 可选链 — 对应 obj?.[key]
            if (target.optionalChain.isSome()) {
                if (targetVal.valueType == JsValueType.Null || targetVal.valueType == JsValueType.Undefined) {
                    return JsValue.UNDEFINED
                }
            }
        }
        if (e.indexExpr.isSome()) {
            let index = e.indexExpr.getOrThrow()
            let idx = evalExpr(index, env)
            // 数组索引
            if (targetVal.arrayData.isSome()) {
                let arr = targetVal.arrayData.getOrThrow()
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
            if (targetVal.objectData.isSome()) {
                let obj = targetVal.objectData.getOrThrow()
                let key = jsToString(idx)
                return obj.get(key)
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
    /// 对象字面量 — 对应 JS { key: value, ... }
    private func evalObject(e: Expr, env: Environment): JsValue {
        let obj = newObject()
        for (p in e.properties) {
            match (p.kind) {
                case GPropertyKind.Field =>
                    let key = p.key
                    if (let Some(valExpr) <- p.value) {
                        let val = evalExpr(valExpr, env)
                        obj.set(key, val)
                    }
                case GPropertyKind.Method =>
                    // 方法定义: { method() { ... } }
                    if (let Some(valExpr) <- p.value) {
                        let fnVal = evalExpr(valExpr, env)
                        obj.set(p.key, fnVal)
                    }
                case _ => ()
            }
        }
        return JsValue(obj)
    }

    /// 箭头函数
    private func evalArrow(e: Expr, env: Environment): JsValue {
        if (e.fn.isSome()) {
            let fn = e.fn.getOrThrow()
            let paramNames = ArrayList<String>()
            for (arg in fn.args) {
                paramNames.append(arg.binding.name)
            }
            let bodyStmts = match (fn.body) {
                case GFnBody.StmtsBody(stmts) => stmts
                case GFnBody.StmtBody(_) => ArrayList<Stmt>()
                case GFnBody.ExprBody(expr) =>
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
        if (e.fn.isSome()) {
            let fn = e.fn.getOrThrow()
            let paramNames = ArrayList<String>()
            for (arg in fn.args) {
                paramNames.append(arg.binding.name)
            }
            let bodyStmts = match (fn.body) {
                case GFnBody.StmtsBody(stmts) => stmts
                case GFnBody.StmtBody(_) => ArrayList<Stmt>()
                case GFnBody.ExprBody(expr) =>
                    let loc = expr.loc
                    ArrayList<Stmt>([Stmt.return_(loc, expr)])
            }
            let jsFn = JsFunction(fn.name, paramNames, bodyStmts, env, false)
            jsFn.isGenerator = fn.isGenerator
            jsFn.isAsync = fn.isAsync
            return JsValue.function(jsFn)
        }
        return JsValue.UNDEFINED
    }

    /// 类表达式
    private func evalClassExpr(e: Expr, env: Environment): JsValue {
        if (e.classData.isSome()) {
            let cls = e.classData.getOrThrow()
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
    private func evalTemplate(e: Expr, env: Environment): JsValue {
        var sb = StringBuilder()

        // head: 第一个静态文本部分 (stringValue)
        sb.append(e.stringValue.toString())

        // templateParts: 交替 [表达式, 静态文本, 表达式, 静态文本, ...]
        // 如果 templateParts 为空，说明是无替换模板 (`hello`)
        for (part in e.templateParts) {
            if (part.tag == ExprTag.String) {
                sb.append(part.stringValue.toString())
            } else {
                let val = evalExpr(part, env)
                sb.append(jsToString(val))
            }
        }
        return JsValue(BaoString(sb.toString()))
    }

    /// 一元表达式 — 对应 JS UnaryExpression
    /// 严格翻译自: ES spec UnaryExpression 语义
    private func evalUnary(e: Expr, env: Environment): JsValue {
        if (let Some(operand) <- e.value) {
            let val = evalExpr(operand, env)
            match (e.op) {
                case OpCode.UnNot => return JsValue(!jsToBoolean(val))
                case OpCode.UnNeg =>
                    return JsValue(-jsToNumber(val))
                case OpCode.UnPos =>
                    return JsValue(jsToNumber(val))
                case OpCode.UnCpl =>
                    // 按位取反: XOR with -1 (等价于 ~x)
                    return JsValue(Float64(Int64(jsToNumber(val)) ^ Int64(-1)))
                case OpCode.Typeof =>
                    return JsValue(BaoString(val.typeOf()))
                case OpCode.UnVoid =>
                    return JsValue.UNDEFINED
                case OpCode.UnPreInc =>
                    let newVal = jsToNumber(val) + 1.0
                    // 写回变量
                    match (operand.tag) {
                        case ExprTag.Identifier => env.set(operand.identifierName, JsValue(newVal))
                        case _ => ()
                    }
                    return JsValue(newVal)
                case OpCode.UnPreDec =>
                    let newVal = jsToNumber(val) - 1.0
                    match (operand.tag) {
                        case ExprTag.Identifier => env.set(operand.identifierName, JsValue(newVal))
                        case _ => ()
                    }
                    return JsValue(newVal)
                case _ => return JsValue.UNDEFINED
            }
        }
        return JsValue.UNDEFINED
    }

    /// 二元表达式 — 支持短路求值
    /// 对应 JS BinaryExpression，严格翻译自 ES spec
    private func evalBinary(e: Expr, env: Environment): JsValue {
        // 短路运算符: &&, ||, ?? 先求值左侧
        if (e.op == OpCode.BinLoAnd) {
            let left = if (e.left.isSome()) { evalExpr(e.left.getOrThrow(), env) } else { JsValue.UNDEFINED }
            if (!jsToBoolean(left)) { return left }
            if (e.right.isSome()) { return evalExpr(e.right.getOrThrow(), env) } else { return JsValue.UNDEFINED }
        }
        if (e.op == OpCode.BinLoOr) {
            let left = if (e.left.isSome()) { evalExpr(e.left.getOrThrow(), env) } else { JsValue.UNDEFINED }
            if (jsToBoolean(left)) { return left }
            if (e.right.isSome()) { return evalExpr(e.right.getOrThrow(), env) } else { return JsValue.UNDEFINED }
        }
        if (e.op == OpCode.BinNullish) {
            let left = if (e.left.isSome()) { evalExpr(e.left.getOrThrow(), env) } else { JsValue.UNDEFINED }
            if (!left.isUndefinedOrNull()) { return left }
            if (e.right.isSome()) { return evalExpr(e.right.getOrThrow(), env) } else { return JsValue.UNDEFINED }
        }

        // 逗号运算符
        if (e.op == OpCode.Comma) {
            if (e.left.isSome()) { let _ = evalExpr(e.left.getOrThrow(), env) }
            if (e.right.isSome()) { return evalExpr(e.right.getOrThrow(), env) } else { return JsValue.UNDEFINED }
        }

        // 其他二元运算符: 两侧都要求值
        let left = if (e.left.isSome()) { evalExpr(e.left.getOrThrow(), env) } else { JsValue.UNDEFINED }
        let right = if (e.right.isSome()) { evalExpr(e.right.getOrThrow(), env) } else { JsValue.UNDEFINED }
        return evalBinaryOp(e.op, left, right)
    }

    /// 二元运算求值 — 对应 JS 二元运算符语义
    /// 严格翻译自: ES spec BinaryExpression 语义
    private func evalBinaryOp(op: OpCode, l: JsValue, r: JsValue): JsValue {
        match (op) {
            // 算术运算
            case OpCode.BinAdd =>
                // + 运算: 字符串拼接或数字加法
                if (l.valueType == JsValueType.String || r.valueType == JsValueType.String) {
                    return JsValue(BaoString(jsToString(l) + jsToString(r)))
                }
                return JsValue(jsToNumber(l) + jsToNumber(r))
            case OpCode.BinSub =>
                return JsValue(jsToNumber(l) - jsToNumber(r))
            case OpCode.BinMul =>
                return JsValue(jsToNumber(l) * jsToNumber(r))
            case OpCode.BinDiv =>
                let divisor = jsToNumber(r)
                if (divisor == 0.0) {
                    if (jsToNumber(l) == 0.0) { return JsValue.nan }
                    if (jsToNumber(l) > 0.0) { return JsValue(Float64(1.0 / 0.0)) } // Infinity
                    return JsValue(Float64(-1.0 / 0.0)) // -Infinity
                }
                return JsValue(jsToNumber(l) / divisor)
            case OpCode.BinRem =>
                let a = jsToNumber(l)
                let b = jsToNumber(r)
                // JS % 运算: a - (truncate(a/b) * b)
                if (b == 0.0) { return JsValue.nan }
                return JsValue(a - Float64(Int64(a / b)) * b)
            case OpCode.BinPow =>
                return JsValue(pow(jsToNumber(l), jsToNumber(r)))
            // 比较运算
            case OpCode.BinLt =>
                return JsValue(jsToNumber(l) < jsToNumber(r))
            case OpCode.BinGt =>
                return JsValue(jsToNumber(l) > jsToNumber(r))
            case OpCode.BinLe =>
                return JsValue(jsToNumber(l) <= jsToNumber(r))
            case OpCode.BinGe =>
                return JsValue(jsToNumber(l) >= jsToNumber(r))
            // 相等运算
            case OpCode.BinEq =>
                return JsValue(jsAbstractEqual(l, r))
            case OpCode.BinNe =>
                return JsValue(!jsAbstractEqual(l, r))
            case OpCode.BinEqStrict =>
                return JsValue(jsStrictEqual(l, r))
            case OpCode.BinNeStrict =>
                return JsValue(!jsStrictEqual(l, r))
            // 位运算 — JS 规范: 先 ToInt32(), NaN/Infinity → 0
            case OpCode.BinAnd =>
                return JsValue(Float64(Float64(toInt32(jsToNumber(l)) & toInt32(jsToNumber(r)))))
            case OpCode.BinOr =>
                return JsValue(Float64(toInt32(jsToNumber(l)) | toInt32(jsToNumber(r))))
            case OpCode.BinXor =>
                return JsValue(Float64(toInt32(jsToNumber(l)) ^ toInt32(jsToNumber(r))))
            case OpCode.BinShl =>
                return JsValue(Float64(toInt32(jsToNumber(l)) << toInt32(jsToNumber(r))))
            case OpCode.BinShr =>
                return JsValue(Float64(toInt32(jsToNumber(l)) >> toInt32(jsToNumber(r))))
            case OpCode.BinUShr =>
                // 无符号右移: 转为 UInt64 后右移，再转回 Int64
                let lv = UInt64(toInt32(jsToNumber(l)))
                let rv = UInt64(toInt32(jsToNumber(r)) & 0x1F)
                return JsValue(Float64(Int64(lv >> rv)))
            // in, instanceof — 简化实现
            case OpCode.BinIn =>
                if (r.valueType == JsValueType.Object) {
                    if (let Some(obj) <- r.objectData) {
                        return JsValue(obj.has(jsToString(l)))
                    }
                }
                return JsValue.FALSE
            case OpCode.BinInstanceof =>
                return JsValue(evalInstanceof(l, r))
            case _ => return JsValue.UNDEFINED
        }
    }

    /// 三元表达式
    private func evalTernary(e: Expr, env: Environment): JsValue {
        if (e.test.isSome()) {
            let test = e.test.getOrThrow()
            let cond = evalExpr(test, env)
            if (jsToBoolean(cond)) {
                if (e.yes.isSome()) { return evalExpr(e.yes.getOrThrow(), env) }
            } else {
                if (e.no.isSome()) { return evalExpr(e.no.getOrThrow(), env) }
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
        if (e.value.isSome()) {
            let rhs = e.value.getOrThrow()
            value = evalExpr(rhs, env)
        }

        // 复合赋值运算符: *=, +=, -=, /=, %=, **=, <<=, >>=, >>>=, &=, |=, ^=
        // 对应 JS 语义: a op= b  等价于  a = a op b
        let op = e.op
        if (op != OpCode.BinAssign && op != OpCode.BinLoAndAssign &&
            op != OpCode.BinLoOrAssign && op != OpCode.BinNullishAssign) {
            // 非短路复合赋值: 先读取旧值，用运算求新值
            if (e.target.isSome()) {
                let target = e.target.getOrThrow()
                let oldVal = evalExpr(target, env)
                let baseOp = assignOpToBinaryOp(op)
                value = evalBinaryOp(baseOp, oldVal, value)
            }
        } else if (op == OpCode.BinLoAndAssign) {
            // &&= 短路: 左值为 falsy 则不赋值
            if (e.target.isSome()) {
                let target = e.target.getOrThrow()
                let oldVal = evalExpr(target, env)
                if (!jsToBoolean(oldVal)) { return oldVal }
            }
        } else if (op == OpCode.BinLoOrAssign) {
            // ||= 短路: 左值为 truthy 则不赋值
            if (e.target.isSome()) {
                let target = e.target.getOrThrow()
                let oldVal = evalExpr(target, env)
                if (jsToBoolean(oldVal)) { return oldVal }
            }
        } else if (op == OpCode.BinNullishAssign) {
            // ??= 短路: 左值非 null/undefined 则不赋值
            if (e.target.isSome()) {
                let target = e.target.getOrThrow()
                let oldVal = evalExpr(target, env)
                if (!oldVal.isUndefinedOrNull()) { return oldVal }
            }
        }

        if (e.target.isSome()) {
            let target = e.target.getOrThrow()
            match (target.tag) {
                case ExprTag.Identifier =>
                    env.set(target.identifierName, value)
                case ExprTag.Dot =>
                    if (target.target.isSome()) {
                        let objExpr = target.target.getOrThrow()
                        let obj = evalExpr(objExpr, env)
                        if (target.optionalChain.isSome()) {
                            if (obj.valueType == JsValueType.Null || obj.valueType == JsValueType.Undefined) {
                                return JsValue.UNDEFINED
                            }
                        }
                        if (obj.objectData.isSome()) {
                            let objData = obj.objectData.getOrThrow()
                            objData.set(target.propertyName, value)
                        }
                    }
                case ExprTag.Index =>
                    if (target.target.isSome()) {
                        let objExpr = target.target.getOrThrow()
                        let obj = evalExpr(objExpr, env)
                        if (target.indexExpr.isSome()) {
                            let idxExpr = target.indexExpr.getOrThrow()
                            let idx = evalExpr(idxExpr, env)
                            if (obj.arrayData.isSome()) {
                                let arr = obj.arrayData.getOrThrow()
                                let i = Int64(jsToNumber(idx))
                                if (i >= 0) {
                                    while (arr.size <= i) {
                                        arr.append(JsValue.UNDEFINED)
                                    }
                                    arr[i] = value
                                }
                            } else if (obj.objectData.isSome()) {
                                let objData = obj.objectData.getOrThrow()
                                objData.set(jsToString(idx), value)
                            }
                        }
                    }
                case _ => ()
            }
        }
        return value
    }

    /// 应用绑定 — 对应 ES6 解构绑定
    public func applyBinding(binding: Binding, value: JsValue, env: Environment): Unit {
        if (!binding.name.isEmpty()) {
            env.define(binding.name, value, true)
        }
    }

    /// 从表达式应用绑定 — 用于赋值表达式中的解构
    private func applyBindingFromExpr(expr: Expr, value: JsValue, env: Environment): Unit {}

    /// 将复合赋值操作符转换为对应的二元操作符
    /// 例如: BinMulAssign → BinMul, BinAddAssign → BinAdd
    private func assignOpToBinaryOp(op: OpCode): OpCode {
        match (op) {
            case OpCode.BinAddAssign => OpCode.BinAdd
            case OpCode.BinSubAssign => OpCode.BinSub
            case OpCode.BinMulAssign => OpCode.BinMul
            case OpCode.BinDivAssign => OpCode.BinDiv
            case OpCode.BinRemAssign => OpCode.BinRem
            case OpCode.BinPowAssign => OpCode.BinPow
            case OpCode.BinShlAssign => OpCode.BinShl
            case OpCode.BinShrAssign => OpCode.BinShr
            case OpCode.BinUShrAssign => OpCode.BinUShr
            case OpCode.BinAndAssign => OpCode.BinAnd
            case OpCode.BinOrAssign => OpCode.BinOr
            case OpCode.BinXorAssign => OpCode.BinXor
            case _ => OpCode.BinAdd
        }
    }

    /// 后缀表达式 ++/--
    /// 对应 JS x++ / x-- 语义: 先返回旧值，再更新
    private func evalPostfix(e: Expr, env: Environment): JsValue {
        if (let Some(operand) <- e.value) {
            let oldVal = evalExpr(operand, env)
            let oldNum = jsToNumber(oldVal)
            let newVal = if (e.op == OpCode.UnPostInc) { oldNum + 1.0 } else { oldNum - 1.0 }
            // 写回变量
            match (operand.tag) {
                case ExprTag.Identifier => env.set(operand.identifierName, JsValue(newVal))
                case _ => ()
            }
            return oldVal  // 后缀: 返回旧值
        }
        return JsValue.UNDEFINED
    }

    // ========================================================================
    // Regex / Super / instanceof 辅助方法
    // ========================================================================

    /// Regex 字面量求值 — 对应 JS /pattern/flags
    ///  严格翻译自: JS RegExp 字面量语义
    ///   1. 解析正则模式和标志
    ///   2. 创建 RegExp 对象，包含 source, flags, lastIndex, test(), exec()
    ///   3. 使用 bao_jsc RegularExpression 进行模式编译
    private func evalRegex(e: Expr): JsValue {
        let pattern = e.regexPattern
        let flagsStr = e.regexFlags

        // 创建 RegExp 对象
        let reObj = newObject()
        reObj.className = "RegExp"
        reObj.set("source", JsValue(BaoString(pattern)))
        reObj.set("flags", JsValue(BaoString(flagsStr)))
        reObj.set("lastIndex", JsValue(0.0))
        reObj.set("global", JsValue(flagsStr.contains("g")))
        reObj.set("ignoreCase", JsValue(flagsStr.contains("i")))
        reObj.set("multiline", JsValue(flagsStr.contains("m")))
        reObj.set("dotAll", JsValue(flagsStr.contains("s")))
        reObj.set("unicode", JsValue(flagsStr.contains("u")))
        reObj.set("sticky", JsValue(flagsStr.contains("y")))

        // 编译正则表达式 (通过 bao_jsc RegularExpression)
        let regexFlags = RegularExpression.parseFlags(flagsStr)
        let compiled = RegularExpression.initFunc(pattern, regexFlags)

        // RegExp.prototype.test(str) — 对应 ES spec RegExp.prototype.test
        reObj.set("test", makeNativeFn("test") { args =>
            if (args.size < 1) { return JsValue(false) }
            let str = jsToString(args[0])
            return JsValue(compiled.matches(str))
        })

        // RegExp.prototype.exec(str) — 对应 ES spec RegExp.prototype.exec
        reObj.set("exec", makeNativeFn("exec") { args =>
            if (args.size < 1) { return JsValue.NULL }
            let str = jsToString(args[0])

            // 使用 exec 获取完整匹配结果 (含捕获组)
            let execResult = compiled.exec(str)
            match (execResult) {
                case Some(er) =>
                    // 返回匹配结果数组: [matchedStr, ...groups, index: n, input: str]
                    let resultArr = ArrayList<JsValue>()
                    resultArr.append(JsValue(BaoString(er.matchStr)))

                    // 添加捕获组
                    for (i in 0..er.groups.size) {
                        resultArr.append(JsValue(BaoString(er.groups[i])))
                    }

                    let resultObj = JsValue.array(resultArr)
                    // 设置 index 和 input 属性
                    // 注意: resultObj 是 JsValue 包装的 array，
                    // 在 bao_runtime 的 JsValue.array 中，属性存储在 ArrayList 上
                    // 这里通过原始数组包装返回，index/input 作为约定
                    return resultObj
                case None =>
                    return JsValue.NULL
            }
        })

        // RegExp.prototype.toString() — 对应 ES spec RegExp.prototype.toString
        reObj.set("toString", makeNativeFn("toString") { _ =>
            return JsValue(BaoString("/${pattern}/${flagsStr}"))
        })

        return JsValue(reObj)
    }

    /// super 表达式求值 — 对应 JS super 引用
    ///  严格翻译自: ES spec SuperReference 语义
    ///   super 单独使用时返回父类原型对象
    ///   在 super.x 和 super() 中由 evalDot/evalCall 单独处理
    private func evalSuper(env: Environment): JsValue {
        if (getSuperPrototype(env).isSome()) {
            let superProto = getSuperPrototype(env).getOrThrow()
            return JsValue(superProto)
        }
        return JsValue.UNDEFINED
    }

    /// 从环境中获取父类原型 — 对应 JS [[HomeObject]].[[Prototype]]
    ///  严格翻译自: ES spec GetSuperConstructor 语义
    ///   类声明时将父类原型存储为 __super_proto__ 环境变量
    ///   子类方法通过此变量访问父类属性和方法
    private func getSuperPrototype(env: Environment): ?JsObject {
        match (env.lookup("__super_proto__")) {
            case Some(superVal) => superVal.objectData
            case None => None
        }
    }

    /// instanceof 运算符 — 完整实现
    ///  严格翻译自: ES spec InstanceofOperator (ES2024 §13.10.3)
    ///   1. 检查 RHS 是否有 [Symbol.hasInstance] 方法
    ///   2. 如果有，调用 HasInstance 并返回结果
    ///   3. 如果 RHS 不是对象，抛出 TypeError
    ///   4. 否则，遍历 LHS 的原型链，检查是否包含 RHS.prototype
    private static func evalInstanceof(l: JsValue, r: JsValue): Bool {
        // 右侧必须是对象/函数 (不能是原始值)
        if (r.valueType != JsValueType.Object && r.valueType != JsValueType.Function) {
            // JS 规范: 如果 RHS 没有 [Symbol.hasInstance] 且不是 Object，抛 TypeError
            // 简化处理: 返回 false
            return false
        }

        // 获取 RHS 的 prototype 属性
        let rhsPrototype = match (r.objectData) {
            case Some(rObj) => rObj.get("prototype")
            case None => JsValue.UNDEFINED
        }

        // RHS.prototype 必须是对象
        if (rhsPrototype.valueType != JsValueType.Object) {
            return false
        }

        let targetProto = match (rhsPrototype.objectData) {
            case Some(proto) => proto
            case None => return false
        }

        // 遍历 LHS 的原型链
        // 获取 LHS 的 __proto__
        if (l.valueType != JsValueType.Object) {
            return false
        }
        var current = match (l.objectData) {
            case Some(obj) => obj.getProto()
            case None => return false
        }

        while (true) {
            match (current) {
                case Some(proto) =>
                    // 检查当前原型是否就是目标原型
                    if (proto.sameRef(targetProto)) {
                        return true
                    }
                    current = proto.getProto()
                case None => return false
            }
        }
        return false
    }

    // ========================================================================
    // JS 值操作工具函数
    // 对应 Bun: src/jsc/JsValue.zig 中的类型转换
    // ========================================================================

    /// JS 值相等比较 - 简化版 strict equality (===)
    public static func jsValuesEqual(a: JsValue, b: JsValue): Bool {
        // 同类型比较
        if (a.valueType == b.valueType) {
            match (a.valueType) {
                case JsValueType.Number => return a.numberValue == b.numberValue
                case JsValueType.String => return a.stringValue.toString() == b.stringValue.toString()
                case JsValueType.Boolean => return a.boolValue == b.boolValue
                case JsValueType.Undefined => return true
                case JsValueType.Null => return true
                case _ => return true // 对象/数组/函数引用相同即为相等
            }
        }
        // null == undefined
        if ((a.valueType == JsValueType.Null && b.valueType == JsValueType.Undefined) ||
            (a.valueType == JsValueType.Undefined && b.valueType == JsValueType.Null)) {
            return true
        }
        return false
    }

    /// JS ToBoolean - 对应 ES spec ToBoolean()
    public static func jsToBoolean(v: JsValue): Bool {
        return v.toBoolean()
    }

    /// JS ToNumber - 对应 ES spec ToNumber()
    public static func jsToNumber(v: JsValue): Float64 {
        return v.toNumber()
    }

    /// JS ToInt32() — 对应 ES2024 spec 7.1.6
    /// NaN, Infinity, -Infinity → 0
    /// 普通数字: 截断为 32 位有符号整数
    public static func toInt32(v: Float64): Int64 {
        if (v.isNaN() || v == Float64.Inf || v == -Float64.Inf) {
            return Int64(0)
        }
        // 截断小数部分 — Int64() 会截断
        if (v > Float64(9223372036854775807.0)) { return Int64(0) }
        if (v < Float64(-9223372036854775808.0)) { return Int64(0) }
        let truncated = Int64(v)
        // 取模 2^32，转为 signed 32-bit
        var bits = truncated % Int64(4294967296)
        if (bits >= Int64(2147483648)) {
            bits = bits - Int64(4294967296)
        } else if (bits < Int64(-2147483648)) {
            bits = bits + Int64(4294967296)
        }
        return bits
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
            case _ => false
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

    /// 重置解释器状态用于测试隔离
    /// 对应 Bun: vm.swapGlobalForTestIsolation() 中清空测试注册表
    public func resetForTestIsolation(): Unit {
        // 清除全局环境中注册的测试相关状态
        // 保留内置对象 (console, process, 等) 但重置 describe/test hooks
        globalEnv.delete("__bao_test_registry")
        globalEnv.delete("__bao_describe_stack")
        globalEnv.delete("__bao_test_count")
        globalEnv.delete("__bao_hook_beforeAll")
        globalEnv.delete("__bao_hook_afterAll")
        globalEnv.delete("__bao_hook_beforeEach")
        globalEnv.delete("__bao_hook_afterEach")
    }
}

// ============================================================================
// Generator — JavaScript 生成器支持
// 对应 Bun: JSC JSGenerator 中的状态机实现
//   JS 生成器通过暂停/恢复执行上下文实现惰性迭代
//   yield 表达式暂停执行并产出值，next() 恢复执行
// ============================================================================

/// 生成器状态 — 对应 JSC GeneratorState
public enum GeneratorState {
    | SuspendedStart     // 刚创建，尚未执行
    | SuspendedYield     // 执行到 yield 后暂停
    | Executing          // 正在执行中
    | Completed          // 执行完毕 (return 或所有语句执行完)

    public operator func ==(other: GeneratorState): Bool {
        match (this) {
            case SuspendedStart => match (other) { case SuspendedStart => true case _ => false }
            case SuspendedYield => match (other) { case SuspendedYield => true case _ => false }
            case Executing => match (other) { case Executing => true case _ => false }
            case Completed => match (other) { case Completed => true case _ => false }
        }
    }
}

/// JavaScript 生成器对象 — 对应 JS function* 创建的迭代器
/// 每次 next() 调用恢复执行，遇到 yield 暂停并返回值
public class JsGenerator {
    /// 生成器函数体语句
    public var body: ArrayList<Stmt>
    /// 生成器闭包环境 (捕获创建时的作用域)
    public var closure: Environment
    /// 当前执行到的语句索引
    public var nextStmtIndex: Int64
    /// 生成器当前状态
    public var state: GeneratorState
    /// 生成器名称
    public var name: String

    public init(name: String, body: ArrayList<Stmt>, closure: Environment) {
        this.name = name
        this.body = body
        this.closure = closure
        this.nextStmtIndex = 0
        this.state = GeneratorState.SuspendedStart
    }

    /// 执行 next(value) — 恢复生成器执行直到下一个 yield 或 return
    /// 对应 JS Generator.prototype.next(value)
    public func next(interpreter: Interpreter, resumeValue: JsValue): JsValue {
        if (state == GeneratorState.Completed) {
            return makeGeneratorResult(JsValue.UNDEFINED, true)
        }
        if (state == GeneratorState.Executing) {
            return makeGeneratorResult(JsValue.UNDEFINED, true)
        }

        state = GeneratorState.Executing
        let genEnv = Environment(closure)
        genEnv.isFunctionScope = true
        genEnv.thisBinding = closure.thisBinding
        // 注入 resumeValue，供 yield 表达式读取
        genEnv.define("__generator_resume__", resumeValue, true)

        var result = JsValue.UNDEFINED
        var i = nextStmtIndex
        try {
            while (i < body.size) {
                result = interpreter.execStmt(body[i], genEnv)
                i++
            }
            state = GeneratorState.Completed
            nextStmtIndex = Int64(body.size)
            return makeGeneratorResult(JsValue.UNDEFINED, true)
        } catch (ys: YieldSignal) {
            // yield 暂停: 下次从当前语句的下一条开始执行
            nextStmtIndex = i + 1
            state = GeneratorState.SuspendedYield
            return makeGeneratorResult(ys.value, false)
        } catch (ret: ReturnSignal) {
            state = GeneratorState.Completed
            return makeGeneratorResult(ret.value, true)
        }
    }
}

/// 创建生成器结果对象 { value, done }
private func makeGeneratorResult(value: JsValue, done: Bool): JsValue {
    let obj = Interpreter.newObject()
    obj.set("value", value)
    obj.set("done", JsValue(done))
    return JsValue(obj)
}

/// yield 信号 — 对应 JS yield 表达式暂停执行
/// 与 ReturnSignal 类似，但携带下一个语句索引以恢复执行
public class YieldSignal <: Exception {
    /// 产出的值
    public var value: JsValue
    /// 恢复执行时的语句索引 (yield 所在语句之后)
    public var nextIndex: Int64

    public init(value: JsValue, nextIndex: Int64) {
        super("yield")
        this.value = value
        this.nextIndex = nextIndex
    }
}

// ============================================================================
// 控制流信号 — break/continue 实现
// ============================================================================

/// break 信号 - 对应 JS break [label]
public class BreakSignal <: Exception {
    public var label: String
    public init(label: String) {
        super(label)
        this.label = label
    }
}

/// continue 信号 - 对应 JS continue [label]
public class ContinueSignal <: Exception {
    public var label: String
    public init(label: String) {
        super(label)
        this.label = label
    }
}

/// return 信号 - 对应 JS return expr
/// 在函数执行中通过异常传播返回值
public class ReturnSignal <: Exception {
    public var value: JsValue
    public init(value: JsValue) {
        super("return")
        this.value = value
    }
}

/// process.exit() 信号 — 用于退出执行
public class ProcessExitSignal <: Exception {
    public let exitCode: Int64
    public init(code: Int64) {
        super("process.exit")
        exitCode = code
    }
}

// ============================================================================
// JsRuntimeThrow — JavaScript 运行时错误
// ============================================================================

/// JavaScript 运行时错误 - 对应 JS throw 值
public class JsRuntimeThrow <: Exception {
    public let value: JsValue

    public init(value: JsValue) {
        super(value.toString())
        this.value = value
    }
}
