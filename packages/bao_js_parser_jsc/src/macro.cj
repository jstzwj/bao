// 严格翻译自: src/js_parser_jsc/Macro.zig
//! Runtime macro system — call, coerce, and resolve build-time macros.
package bao_js_parser_jsc

import bao_jsc.*
import bao_core.*
import bao_parser.*

// ============================================================================
// 宏模块常量 - 严格翻译自: src/js_parser_jsc/Macro.zig:1-6
// ============================================================================

/// 宏命名空间前缀
public let MACRO_NAMESPACE: String = "macro"
public let MACRO_NAMESPACE_WITH_COLON: String = "macro:"

/// 判断是否是宏路径 - 严格对应 Bun isMacroPath
/// Zig: pub fn isMacroPath(str: string) bool
public func isMacroPath(str: String): Bool {
    return strings.hasPrefixComptime(str, MACRO_NAMESPACE_WITH_COLON)
}

// ============================================================================
// MacroContext - 宏上下文
// 严格翻译自: src/js_parser_jsc/Macro.zig:8-149
// ============================================================================

/// 宏上下文 - 严格对应 Bun MacroContext
public class MacroContext {
    public var resolver: Resolver
    public var env: DotEnvLoader
    public var macros: MacroMap
    public var remap: MacroRemap
    public var javascriptObject: JSValue

    public init() {
        resolver = Resolver()
        env = DotEnvLoader()
        macros = MacroMap()
        remap = MacroRemap()
        javascriptObject = JSValue.zero
    }

    /// 获取宏重映射 - 严格对应 Bun MacroContext.getRemap
    /// Zig: pub fn getRemap(this: MacroContext, path: string) ?MacroRemapEntry
    public func getRemap(path: String): ?MacroRemapEntry {
        if (remap.entries.length == 0) {
            return None
        }
        return remap.get(path)
    }

    /// 初始化宏上下文 - 严格对应 Bun MacroContext.init
    /// Zig: pub fn init(transpiler: *Transpiler) MacroContext
    public static func init(transpiler: Transpiler): MacroContext {
        let ctx = MacroContext()
        ctx.macros = MacroMap.init(Allocator.default)
        ctx.resolver = transpiler.resolver
        ctx.env = transpiler.env
        ctx.remap = transpiler.options.macroRemap
        return ctx
    }

    /// 调用宏 - 严格对应 Bun MacroContext.call
    /// Zig: pub fn call(this: *MacroContext, import_record_path, source_dir, log, source, import_range, caller, function_name) anyerror!Expr
    public func call(
        importRecordPath: String,
        sourceDir: String,
        log: LoggerLog,
        source: LoggerSource,
        importRange: LoggerRange,
        caller: Expr,
        functionName: String
    ): ?Expr {
        ExprDataStore.disableReset = true
        StmtDataStore.disableReset = true
        defer {
            ExprDataStore.disableReset = false
            StmtDataStore.disableReset = false
        }

        let importRecordPathWithoutMacroPrefix = if (isMacroPath(importRecordPath)) {
            importRecordPath[MACRO_NAMESPACE_WITH_COLON.length..]
        } else {
            importRecordPath
        }

        let inputSpecifier: String = if (let replacement = ModuleLoader.HardcodedModule.Alias.get(importRecordPath, .bun)) {
            replacement.path
        } else {
            let resolveResult = resolver.resolve(sourceDir, importRecordPathWithoutMacroPrefix, .stmt)
            if (resolveResult.isErr) {
                let err = resolveResult.errorValue
                match (err) {
                    case .ModuleNotFound =>
                        log.addResolveError(
                            source,
                            importRange,
                            log.msgs.allocator,
                            "Macro \"${importRecordPath}\" not found",
                            .stmt,
                            err
                        )
                        return None
                    default =>
                        log.addRangeErrorFmt(
                            source,
                            importRange,
                            log.msgs.allocator,
                            "${err} resolving macro \"${importRecordPath}\""
                        )
                        return None
                }
            }
            resolveResult.value.pathPair.primary.text
        }

        var specifierBuf: Array<UInt8> = Array<UInt8>(64, item: 0)
        var specifierBufLen: UInt32 = 0
        let hash = MacroEntryPoint.generateID(
            inputSpecifier,
            functionName,
            specifierBuf,
            specifierBufLen
        )

        let macroEntry = macros.getOrPut(hash)
        if (!macroEntry.foundExisting) {
            macroEntry.value = Macro.init(
                Allocator.default,
                resolver,
                inputSpecifier,
                log,
                env,
                functionName,
                specifierBuf[0..specifierBufLen],
                hash
            )
            if (macroEntry.value == None) {
                return None
            }
            Output.flush()
        }

        let macro = macroEntry.value
        if (macro.disabled) {
            return caller
        }
        macro.vm.enableMacroMode()
        defer {
            macro.vm.disableMacroMode()
        }
        macro.vm.eventLoop().ensureWaker()

        let result = MacroRunner.run(
            macro,
            log,
            Allocator.default,
            functionName,
            caller,
            source,
            hash,
            javascriptObject
        )
        return result
    }
}

// ============================================================================
// MacroResult - 宏结果
// 严格翻译自: src/js_parser_jsc/Macro.zig:151-154
// ============================================================================

/// 宏结果 - 严格对应 Bun MacroResult
public class MacroResult {
    public var importStatements: Array<SImport>
    public var replacement: Expr

    public init() {
        importStatements = []
        replacement = Expr()
    }
}

// ============================================================================
// Macro - 宏实例
// 严格翻译自: src/js_parser_jsc/Macro.zig:156-214
// ============================================================================

/// 宏实例 - 严格对应 Bun Macro
public class Macro {
    public var resolver: Resolver
    public var vm: JavaScriptVirtualMachine
    public var resolved: ResolveResult
    public var disabled: Bool

    public init() {
        resolver = Resolver()
        vm = JavaScriptVirtualMachine()
        resolved = ResolveResult()
        disabled = false
    }

    /// 初始化宏 - 严格对应 Bun Macro.init
    /// Zig: pub fn init(_: std.mem.Allocator, resolver, input_specifier, log, env, function_name, specifier, hash) !Macro
    public static func init(
        allocator: Allocator,
        resolver: Resolver,
        inputSpecifier: String,
        log: LoggerLog,
        env: DotEnvLoader,
        functionName: String,
        specifier: String,
        hash: Int32
    ): ?Macro {
        var vm: JavaScriptVirtualMachine = if (JavaScriptVirtualMachine.isLoaded()) {
            JavaScriptVirtualMachine.get()
        } else {
            let oldTransformOptions = resolver.opts.transformOptions
            defer {
                resolver.opts.transformOptions = oldTransformOptions
            }

            // JSC needs to be initialized if building from CLI
            jsc.initialize(false)

            var newVm = JavaScriptVirtualMachine.init(
                allocator,
                resolver.opts.transformOptions,
                log,
                false,
                env
            )

            newVm.enableMacroMode()
            newVm.eventLoop().ensureWaker()

            newVm.transpiler.configureDefines()
            newVm
        }

        vm.enableMacroMode()
        vm.eventLoop().ensureWaker()

        let loadedResult = vm.loadMacroEntryPoint(inputSpecifier, functionName, specifier, hash)

        match (loadedResult.unwrap(vm.jscVM, .leave_unhandled)) {
            case .rejected => result =>
                vm.unhandledRejection(vm.global, result, loadedResult.toJS())
                vm.disableMacroMode()
                return None
            default =>
        }

        let macro = Macro()
        macro.vm = vm
        macro.resolver = resolver
        return macro
    }

    // ============================================================================
    // Macro.Runner - 宏运行器
    // 严格翻译自: src/js_parser_jsc/Macro.zig:216-605
    // ============================================================================

    /// 宏运行器 - 严格对应 Bun Macro.Runner
    public class Runner {
        public var caller: Expr
        public var functionName: String
        public var macro: Macro
        public var global: JSGlobalObject
        public var allocator: Allocator
        public var id: Int32
        public var log: LoggerLog
        public var source: LoggerSource
        public var visited: VisitMap
        public var isTopLevel: Bool

        public init() {
            caller = Expr()
            functionName = ""
            macro = Macro()
            global = JSGlobalObject()
            allocator = Allocator.default
            id = 0
            log = LoggerLog()
            source = LoggerSource()
            visited = VisitMap()
            isTopLevel = false
        }

        /// 异步运行宏 - 严格对应 Bun Macro.Runner.Run.runAsync
        /// Zig: pub fn runAsync(macro, log, allocator, function_name, caller, args, source, id) MacroError!Expr
        public static func runAsync(
            macro: Macro,
            log: LoggerLog,
            allocator: Allocator,
            functionName: String,
            caller: Expr,
            args: Array<JSValue>,
            source: LoggerSource,
            id: Int32
        ): ?Expr {
            let macroCallback = macro.vm.macros.get(id)
            if (macroCallback == None) {
                return caller
            }

            let result = JSObjectCallAsFunctionReturnValueHoldingAPILock(
                macro.vm.global,
                macroCallback,
                None,
                args.length,
                args
            )

            var runner = Runner()
            runner.caller = caller
            runner.functionName = functionName
            runner.macro = macro
            runner.allocator = allocator
            runner.global = macro.vm.global
            runner.id = id
            runner.log = log
            runner.source = source
            runner.visited = VisitMap()

            defer {
                runner.visited.deinit(allocator)
            }

            return runner.run(result)
        }

        /// 运行宏 - 严格对应 Bun Macro.Runner.Run.run
        /// Zig: pub fn run(this: *Run, value: jsc.JSValue) MacroError!Expr
        public func run(value: JSValue): ?Expr {
            let tagResult = ConsoleObjectFormatterTag.get(value, global)
            if (tagResult == None) {
                log.addErrorFmt(
                    source,
                    caller.loc,
                    allocator,
                    "cannot coerce unknown to Bun's AST. Please return a simpler type"
                )
                return None
            }

            let tag = tagResult.tag
            return match (tag) {
                case .Error => coerce(value, .Error)
                case .Undefined => coerce(value, .Undefined)
                case .Null => coerce(value, .Null)
                case .Private => coerce(value, .Private)
                case .Boolean => coerce(value, .Boolean)
                case .Array => coerce(value, .Array)
                case .Object => coerce(value, .Object)
                case .toJSON => coerce(value, .JSON)
                case .JSON => coerce(value, .JSON)
                case .Integer => coerce(value, .Integer)
                case .Double => coerce(value, .Double)
                case .String => coerce(value, .String)
                case .Promise => coerce(value, .Promise)
                default =>
                    let name = value.getClassInfoName() ?? "unknown"
                    log.addErrorFmt(
                        source,
                        caller.loc,
                        allocator,
                        "cannot coerce ${name} (${value.jsType()}) to Bun's AST. Please return a simpler type"
                    )
                    None
            }
        }

        /// 强制转换 JS 值为 AST Expr - 严格对应 Bun Macro.Runner.Run.coerce
        /// Zig: pub fn coerce(this: *Run, value: jsc.JSValue, comptime tag: jsc.ConsoleObject.Formatter.Tag) MacroError!Expr
        public func coerce(value: JSValue, tag: ConsoleObjectFormatterTag): ?Expr {
            match (tag) {
                case .Error =>
                    macro.vm.uncaughtException(global, value, false)
                    return caller
                case .Undefined =>
                    if (isTopLevel) {
                        return caller
                    } else {
                        return Expr.init(EUndefined, EUndefined(), caller.loc)
                    }
                case .Null =>
                    return Expr.init(ENull, ENull(), caller.loc)
                case .Private =>
                    isTopLevel = false
                    if (let cached = visited.get(value)) {
                        return cached
                    }

                    var blob: ?Blob = None
                    let mimeType: ?MimeType = None

                    if (value.jsType() == JSType.DOMWrapper) {
                        if (let resp = value.as(WebCoreResponse)) {
                            return run(resp.getBlobWithoutCallFrame(global))
                        } else if (let resp = value.as(WebCoreRequest)) {
                            return run(resp.getBlobWithoutCallFrame(global))
                        } else if (let resp = value.as(WebCoreBlob)) {
                            blob = resp
                        } else if (value.as(ResolveMessage) != None || value.as(BuildMessage) != None) {
                            macro.vm.uncaughtException(global, value, false)
                            return None
                        }
                    }

                    if (let b = blob) {
                        let result = Expr.fromBlob(
                            b,
                            allocator,
                            mimeType,
                            log,
                            caller.loc
                        )
                        if (result == None) {
                            return None
                        }
                        return result
                    }

                    return Expr.init(EString, EString.empty, caller.loc)

                case .Boolean =>
                    return Expr( data: ExprData.e_boolean(EBoolean(value: value.toBoolean())), loc: caller.loc )

                case .Array =>
                    isTopLevel = false

                    let entry = visited.getOrPut(allocator, value)
                    if (entry.foundExisting) {
                        return entry.value
                    }

                    let iter = JSArrayIterator.init(value, global)

                    // 处理所有数组项
                    var array = allocator.alloc<Expr>(iter.length)
                    let expr = Expr.init(
                        EArray,
                        EArray(items: ExprNodeList.empty, wasOriginallyMacro: true),
                        caller.loc
                    )
                    entry.value = expr
                    var i: Int64 = 0
                    for (item in iter) {
                        array[i] = run(item) ?? continue
                        if (array[i].isMissing()) {
                            continue
                        }
                        i += 1
                    }

                    expr.data.eArray.items = ExprNodeList.fromOwnedSlice(array)
                    expr.data.eArray.items.length = UInt32(i)
                    return expr

                case .Object =>
                    isTopLevel = false
                    let entry = visited.getOrPut(allocator, value)
                    if (entry.foundExisting) {
                        return entry.value
                    }

                    // 预留占位符以打破循环
                    let expr = Expr.init(
                        EObject,
                        EObject(properties: GPropertyList(), wasOriginallyMacro: true),
                        caller.loc
                    )
                    entry.value = expr

                    // tag 确保 value 是一个对象
                    let obj = value.getObject()!
                    let objectIter = JSPropertyIterator.init(global, obj, false, true)
                    defer {
                        objectIter.deinit()
                    }

                    // 构建属性列表
                    var properties = GPropertyList.initCapacity(allocator, objectIter.length)

                    for (prop in objectIter) {
                        let objectValue = run(objectIter.value)

                        properties.append(allocator, GProperty(
                            key: Expr.init(
                                EString,
                                EString.init(prop.toOwnedSlice(allocator)),
                                caller.loc
                            ),
                            value: objectValue
                        ))
                    }

                    expr.data.eObject.properties = properties
                    return expr

                case .JSON =>
                    isTopLevel = false
                    // JSON 处理 - 待完善

                case .Integer =>
                    return Expr.init(ENumber, ENumber(value: Float64(value.toInt32())), caller.loc)

                case .Double =>
                    return Expr.init(ENumber, ENumber(value: value.asNumber()), caller.loc)

                case .String =>
                    let bunStr = value.toBunString(global)
                    defer {
                        bunStr.deref()
                    }

                    // 编码为 utf16 以便打印机正确转义字符串
                    let utf16Bytes = allocator.alloc<UInt16>(bunStr.length())
                    let outSlice = utf16Bytes[0..(bunStr.encodeInto(utf16Bytes, .utf16le) / 2)]
                    return Expr.init(EString, EString.init(outSlice), caller.loc)

                case .Promise =>
                    if (let cached = visited.get(value)) {
                        return cached
                    }

                    let promise = value.asAnyPromise()!

                    macro.vm.waitForPromise(promise)

                    let promiseResult = promise.result(macro.vm.jscVM)
                    let rejected = promise.status() == .rejected

                    if (promiseResult.isUndefined() && isTopLevel) {
                        isTopLevel = false
                        return caller
                    }

                    if (rejected || promiseResult.isError() || promiseResult.isAggregateError(global) || promiseResult.isException(global.vm())) {
                        macro.vm.unhandledRejection(global, promiseResult, promise.asValue())
                        return None
                    }
                    isTopLevel = false
                    let result = run(promiseResult)

                    visited.put(allocator, value, result)
                    return result

                default =>
            }

            log.addErrorFmt(
                source,
                caller.loc,
                allocator,
                "cannot coerce ${value.jsType()} to Bun's AST. Please return a simpler type"
            )
            return None
        }
    }

    /// 运行宏 - 严格对应 Bun Macro.Runner.run
    /// Zig: pub fn run(macro, log, allocator, function_name, caller, source, id, javascript_object) MacroError!Expr
    public static func run(
        macro: Macro,
        log: LoggerLog,
        allocator: Allocator,
        functionName: String,
        caller: Expr,
        source: LoggerSource,
        id: Int32,
        javascriptObject: JSValue
    ): ?Expr {
        let exceptionHolder = ZigExceptionHolder.init()
        var jsArgs: Array<JSValue> = []
        var jsProcessedArgsLen: UInt64 = 0
        defer {
            for (i in 0..jsProcessedArgsLen - UInt64(if (javascriptObject != JSValue.zero) 1 else 0)) {
                jsArgs[i].unprotect()
            }
        }

        let globalObject = VirtualMachine.get().global

        match (caller.data) {
            case .e_call => call =>
                let callArgs: Array<Expr> = call.args.slice()
                jsArgs = allocator.alloc<JSValue>(callArgs.length + UInt64(if (javascriptObject != JSValue.zero) 1 else 0))
                jsProcessedArgsLen = jsArgs.length

                for (i in 0..callArgs.length) {
                    let value = exprToJS(callArgs[i], allocator, globalObject)
                    if (value == None) {
                        jsProcessedArgsLen = UInt64(i)
                        return None
                    }
                    value.protect()
                    jsArgs[i] = value
                }
            case .e_template =>
                // TODO: support template literals in macros
            default =>
        }

        if (javascriptObject != JSValue.zero) {
            if (jsArgs.length == 0) {
                jsArgs = allocator.alloc<JSValue>(1)
            }
            jsArgs[jsArgs.length - 1] = javascriptObject
        }

        return Runner.runAsync(
            macro,
            log,
            allocator,
            functionName,
            caller,
            jsArgs,
            source,
            id
        )
    }
}

/// MacroRunner 是 Macro.Runner 的别名
public typealias MacroRunner = Macro.Runner
