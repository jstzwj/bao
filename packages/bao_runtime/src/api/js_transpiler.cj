// 严格翻译自: src/runtime/api/JSTranspiler.zig
package bao_runtime.api

import bao_jsc.*
import bao_core.*
import bao_collections.*

// ============================================================================
// JSTranspiler - JS 转译器
// 对应 Bun: src/runtime/api/JSTranspiler.zig
// ============================================================================

/// JSTranspiler - JavaScript/TypeScript 转译器
public class JSTranspiler {
    public var transpiler: Transpiler
    public var config: Config
    public var scanPassResult: ScanPassResult
    public var bufferWriter: ?JsPrinterBufferWriter
    public var logLevel: LoggerLogLevel
    public var arena: ArenaAllocator
    public var refCount: RefCount

    // ========================================================================
    // Config - 转译器配置
    // ========================================================================

    /// Config - 转译配置
    public class Config {
        public var transform: TransformOptions
        public var defaultLoader: Loader
        public var macroMap: MacroMap
        public var tsconfig: ?TSConfigJSON
        public var tsconfigBuf: String
        public var macrosBuf: String
        public var log: LoggerLog
        public var runtime: RuntimeFeatures
        public var treeShaking: Bool
        public var trimUnusedImports: ?Bool
        public var inlining: Bool
        public var deadCodeElimination: Bool
        public var minifyWhitespace: Bool
        public var minifyIdentifiers: Bool
        public var minifySyntax: Bool
        public var noMacros: Bool
        public var replMode: Bool

        public init() {
            transform = defaultTransformOptions
            defaultLoader = Loader.jsx
            macroMap = MacroMap()
            tsconfig = None
            tsconfigBuf = ""
            macrosBuf = ""
            log = LoggerLog.init()
            runtime = RuntimeFeatures(topLevelAwait: true)
            treeShaking = false
            trimUnusedImports = None
            inlining = false
            deadCodeElimination = true
            minifyWhitespace = false
            minifyIdentifiers = false
            minifySyntax = false
            noMacros = false
            replMode = false
        }

        /// 从 JS 对象解析配置
        /// 对应 Bun: Config.fromJS
        public static func fromJS(config: Config, globalThis: JsGlobalObject, object: JsValue, allocator: Allocator): Unit {
            if (object.isUndefinedOrNull()) {
                return
            }

            if (!object.isObject()) {
                globalThis.throwInvalidArguments("Expected an object")
                return
            }

            // 解析 define 选项
            if (let define = try object.getTruthy(globalThis, "define")) {
                if (!define.isUndefinedOrNull()) {
                    let defineObj = define.getObject() ?? {
                        globalThis.throwInvalidArguments("define must be an object")
                        return
                    }

                    var defineIter = try JsPropertyIterator(
                        skipEmptyName: true,
                        includeValue: true,
                    ).init(globalThis, defineObj)
                    defer defineIter.deinit()

                    var names = ArrayList<String>(allocator)
                    var values = ArrayList<String>(allocator)
                    names.ensureTotalCapacity(defineIter.len)
                    values.ensureTotalCapacity(defineIter.len)

                    while (let prop = try defineIter.next()) {
                        let propertyValue = defineIter.value
                        let valueType = propertyValue.jsType()

                        if (!valueType.isStringLike()) {
                            globalThis.throwInvalidArguments("define \"{}\" must be a JSON string", [prop])
                            return
                        }

                        names.append(prop.toOwnedSlice(allocator))
                        var val = propertyValue.toZigString(globalThis)
                        if (val.len == 0) {
                            val = ZigString.init("\"\"")
                        }
                        values.append(val.toString())
                    }

                    config.transform.define = StringMap(keys: names.items, values: values.items)
                }
            }

            // 解析 external
            if (let external = try object.get(globalThis, "external")) {
                if (!external.isUndefinedOrNull()) {
                    let toplevelType = external.jsType()
                    if (toplevelType.isStringLike()) {
                        let zigStr = external.toZigString(globalThis)
                        if (zigStr.len > 0) {
                            config.transform.external = [zigStr.toString()]
                        }
                    } else if (toplevelType.isArray()) {
                        let count = try external.getLength(globalThis)
                        if (count > 0) {
                            var externals = ArrayList<String>(allocator)
                            var iter = try external.arrayIterator(globalThis)
                            while (let entry = try iter.next()) {
                                if (!entry.jsType().isStringLike()) {
                                    globalThis.throwInvalidArguments("external must be a string or string[]")
                                    return
                                }
                                let zigStr = entry.toZigString(globalThis)
                                if (zigStr.len > 0) {
                                    externals.append(zigStr.toString())
                                }
                            }
                            config.transform.external = externals.items
                        }
                    } else {
                        globalThis.throwInvalidArguments("external must be a string or string[]")
                        return
                    }
                }
            }

            // 解析 loader
            if (let loader = try object.get(globalThis, "loader")) {
                if (let resolved = try Loader.fromJS(globalThis, loader)) {
                    if (!resolved.isJavaScriptLike()) {
                        globalThis.throwInvalidArguments("only JavaScript-like loaders supported for now")
                        return
                    }
                    config.defaultLoader = resolved
                }
            }

            // 解析 target
            if (let target = try object.get(globalThis, "target")) {
                if (let resolved = try Target.fromJS(globalThis, target)) {
                    config.transform.target = resolved.toApi()
                }
            }

            // 解析 tsconfig
            if (let tsconfig = try object.get(globalThis, "tsconfig")) {
                if (!tsconfig.isUndefinedOrNull()) {
                    let kind = tsconfig.jsType()
                    if (kind.isArray()) {
                        globalThis.throwInvalidArguments("tsconfig must be a string or object")
                        return
                    }

                    var out = BunString.empty
                    defer out.deref()

                    if (!kind.isStringLike()) {
                        try tsconfig.jsonStringifyFast(globalThis, out)
                    } else {
                        out = try tsconfig.toBunString(globalThis)
                    }

                    if (!out.isEmpty()) {
                        config.tsconfigBuf = out.toOwnedSlice(allocator)
                        if (let parsed = TSConfigJSON.parse(
                            allocator,
                            config.log,
                            LoggerSource.initPathString("tsconfig.json", config.tsconfigBuf),
                            VirtualMachine.get().transpiler.resolver.caches.json,
                        )) {
                            config.tsconfig = parsed
                        }
                    }
                }
            }

            config.runtime.allowRuntime = false

            // 解析 macro
            if (let macros = try object.getTruthy(globalThis, "macro")) {
                if (!macros.isUndefinedOrNull()) {
                    if (macros.isBoolean()) {
                        config.noMacros = !macros.asBoolean()
                    } else {
                        let kind = macros.jsType()
                        let isObject = kind.isObject()
                        if (!(kind.isStringLike() || isObject)) {
                            globalThis.throwInvalidArguments("macro must be an object")
                            return
                        }

                        var out = BunString.empty
                        defer out.deref()
                        if (isObject) {
                            try macros.jsonStringifyFast(globalThis, out)
                        } else {
                            out = try macros.toBunString(globalThis)
                        }

                        if (!out.isEmpty()) {
                            config.macrosBuf = out.toOwnedSlice(allocator)
                            let source = LoggerSource.initPathString("macros.json", config.macrosBuf)
                            if (let json = VirtualMachine.get().transpiler.resolver.caches.json.parseJson(
                                config.log,
                                source,
                                allocator,
                                JsonParseMode.json,
                                false,
                            )) {
                                config.macroMap = PackageJson.parseMacrosJson(allocator, json, config.log, source)
                            }
                        }
                    }
                }
            }

            // 解析布尔选项
            if (let flag = try object.getBooleanLoose(globalThis, "autoImportJSX")) {
                config.runtime.autoImportJsx = flag
            }
            if (let flag = try object.getBooleanLoose(globalThis, "allowBunRuntime")) {
                config.runtime.allowRuntime = flag
            }
            if (let flag = try object.getBooleanLoose(globalThis, "inline")) {
                config.runtime.inlining = flag
            }
            if (let flag = try object.getBooleanLoose(globalThis, "minifyWhitespace")) {
                config.minifyWhitespace = flag
            }
            if (let flag = try object.getBooleanLoose(globalThis, "deadCodeElimination")) {
                config.deadCodeElimination = flag
            }
            if (let flag = try object.getBooleanLoose(globalThis, "replMode")) {
                config.replMode = flag
            }

            // 解析 minify
            if (let minify = try object.getTruthy(globalThis, "minify")) {
                if (minify.isBoolean()) {
                    config.minifyWhitespace = minify.toBoolean()
                    config.minifySyntax = config.minifyWhitespace
                    config.minifyIdentifiers = config.minifySyntax
                } else if (minify.isObject()) {
                    if (let whitespace = try minify.getBooleanLoose(globalThis, "whitespace")) {
                        config.minifyWhitespace = whitespace
                    }
                    if (let syntax = try minify.getBooleanLoose(globalThis, "syntax")) {
                        config.minifySyntax = syntax
                    }
                    if (let identifiers = try minify.getBooleanLoose(globalThis, "identifiers")) {
                        config.minifyIdentifiers = identifiers
                    }
                } else {
                    globalThis.throwInvalidArguments("Expected minify to be a boolean or an object")
                    return
                }
            }

            // 解析 sourcemap
            if (let flag = try object.get(globalThis, "sourcemap")) {
                if (flag.isBoolean() || flag.isUndefinedOrNull()) {
                    if (flag.toBoolean()) {
                        config.transform.sourceMap = SourceMapOption.inline
                    } else {
                        config.transform.sourceMap = SourceMapOption.none
                    }
                } else {
                    if (let source = try SourceMapOption.fromJS(globalThis, flag)) {
                        config.transform.sourceMap = source
                    } else {
                        globalThis.throwInvalidArguments("sourcemap must be one of \"inline\", \"linked\", \"external\", or \"none\"")
                        return
                    }
                }
            }

            // 解析 packages
            if (let packages = try object.getOptionalEnum(globalThis, "packages", PackagesOption)) {
                config.transform.packages = packages.toApi()
            }

            // 解析 treeShaking
            var treeShaking: ?Bool = None
            if (let treeShakingVal = try object.getBooleanLoose(globalThis, "treeShaking")) {
                treeShaking = treeShakingVal
            }

            var trimUnusedImports: ?Bool = None
            if (let trimUnusedImportsVal = try object.getBooleanLoose(globalThis, "trimUnusedImports")) {
                trimUnusedImports = trimUnusedImportsVal
            }

            // 解析 exports
            if (let exports = try object.getTruthy(globalThis, "exports")) {
                if (!exports.isObject()) {
                    globalThis.throwInvalidArguments("exports must be an object")
                    return
                }

                var replacements = ReplaceableExportMap()

                if (let eliminate = try exports.getTruthy(globalThis, "eliminate")) {
                    if (!eliminate.jsType().isArray()) {
                        globalThis.throwInvalidArguments("exports.eliminate must be an array")
                        return
                    }

                    var iter = try JsArrayIterator.init(eliminate, globalThis)
                    while (let value = try iter.next()) {
                        if (value.isString()) {
                            let str = try value.getZigString(globalThis)
                            if (str.len > 0) {
                                replacements.put(str.toString(), ReplaceableExport.delete())
                            }
                        }
                    }
                }

                if (let replace = try exports.getTruthy(globalThis, "replace")) {
                    let replaceObj = replace.getObject() ?? {
                        globalThis.throwInvalidArguments("replace must be an object")
                        return
                    }

                    var iter = try JsPropertyIterator(
                        skipEmptyName: true,
                        includeValue: true,
                    ).init(globalThis, replaceObj)
                    defer iter.deinit()

                    while (let key = try iter.next()) {
                        let value = iter.value
                        if (value == JsValue.zero) {
                            continue
                        }

                        if (!JsLexer.isIdentifier(key)) {
                            globalThis.throwInvalidArguments("\"{}\" is not a valid ECMAScript identifier", [key])
                            return
                        }

                        if (let expr = try exportReplacementValue(value, globalThis, allocator)) {
                            replacements.put(key, ReplaceableExport.replace(expr))
                            continue
                        }

                        if (value.isObject() && try value.getLength(globalThis) == 2) {
                            let replacementValue = try value.getIndex(globalThis, 1)
                            if (let toReplace = try exportReplacementValue(replacementValue, globalThis, allocator)) {
                                let replacementKey = try value.getIndex(globalThis, 0)
                                let replacementName = replacementKey.toSliceCloneWithAllocator(globalThis, allocator)

                                if (!JsLexer.isIdentifier(replacementName)) {
                                    globalThis.throwInvalidArguments("\"{}\" is not a valid ECMAScript identifier", [replacementName])
                                    return
                                }

                                replacements.put(key, ReplaceableExport.inject(replacementName, toReplace))
                                continue
                            }
                        }

                        globalThis.throwInvalidArguments("exports.replace values can only be string, null, undefined, number or boolean")
                        return
                    }
                }

                treeShaking = treeShaking ?? (replacements.count() > 0)
                config.runtime.replaceExports = replacements
            }

            // 解析 logLevel
            if (let logLevel = try object.getTruthy(globalThis, "logLevel")) {
                if (let level = try LoggerLogLevel.Map.fromJS(globalThis, logLevel)) {
                    config.log.level = level
                } else {
                    globalThis.throwInvalidArguments("logLevel must be one of \"verbose\", \"debug\", \"info\", \"warn\", or \"error\"")
                    return
                }
            }

            config.treeShaking = treeShaking ?? false
            config.trimUnusedImports = trimUnusedImports ?? config.treeShaking
        }
    }

    // ========================================================================
    // 默认选项
    // ========================================================================

    public static let defaultTransformOptions: TransformOptions = {
        var opts = TransformOptions()
        opts.disableHmr = true
        opts.target = Target.browser
        return opts
    }()

    // ========================================================================
    // 构造器
    // ========================================================================

    /// JS 构造器
    public static func constructor(globalThis: JsGlobalObject, callframe: JsCallFrame): JSTranspiler {
        let arguments = callframe.argumentsOld(3)
        var this = JSTranspiler()
        this.config = Config()
        this.arena = ArenaAllocator.init()
        this.scanPassResult = ScanPassResult.init()
        this.refCount = RefCount.initExactRefs(1)

        let configArg = if (arguments.len > 0) arguments.ptr[0] else JsValue.jsUndefined
        let allocator = this.arena.allocator()

        try Config.fromJS(this.config, globalThis, configArg, allocator)
        let config = this.config

        if (globalThis.hasException()) {
            return Error.JsError
        }

        if ((config.log.warnings + config.log.errors) > 0) {
            return globalThis.throwValue(try config.log.toJS(globalThis, "Failed to create transpiler"))
        }

        this.transpiler = Transpiler.init(
            config.transform,
            config.log,
            VirtualMachine.get().transpiler.env,
        ) catch {
            err =>
                if ((config.log.warnings + config.log.errors) > 0) {
                    return globalThis.throwValue(try config.log.toJS(globalThis, "Failed to create transpiler"))
                }
                return globalThis.throwError(err, "Error creating transpiler")
        }

        this.transpiler.options.noMacros = config.noMacros
        this.transpiler.configureLinkerWithAutoJSX(false)
        this.transpiler.options.env.behavior = DotEnvBehavior.disable
        this.transpiler.configureDefines() catch {
            err =>
                if ((config.log.warnings + config.log.errors) > 0) {
                    return globalThis.throwValue(try config.log.toJS(globalThis, "Failed to load define"))
                }
                return globalThis.throwError(err, "Failed to load define")
        }

        if (config.macroMap.count() > 0) {
            this.transpiler.options.macroRemap = config.macroMap
        }

        // REPL 模式禁用 DCE 以保留表达式
        this.transpiler.options.deadCodeElimination = config.deadCodeElimination && !config.replMode
        this.transpiler.options.minifyWhitespace = config.minifyWhitespace

        if (config.minifySyntax) {
            this.transpiler.options.minifySyntax = true
        }
        if (config.minifyIdentifiers) {
            this.transpiler.options.minifyIdentifiers = true
        }

        this.transpiler.options.transformOnly = !this.transpiler.options.allowRuntime
        this.transpiler.options.treeShaking = config.treeShaking
        this.transpiler.options.trimUnusedImports = config.trimUnusedImports ?? false
        this.transpiler.options.allowRuntime = config.runtime.allowRuntime
        this.transpiler.options.autoImportJsx = config.runtime.autoImportJsx
        this.transpiler.options.inlining = config.runtime.inlining
        this.transpiler.options.hotModuleReloading = config.runtime.hotModuleReloading
        this.transpiler.options.reactFastRefresh = false
        this.transpiler.options.replMode = config.replMode

        return this
    }

    // ========================================================================
    // JS 方法
    // ========================================================================

    /// transform - JS 入口: transpiler.transform(code)
    /// 对应 Bun: JSTranspiler.transform
    public func transform(globalThis: JsGlobalObject, callframe: JsCallFrame): JsValue {
        let arguments = callframe.argumentsOld(3)
        var args = CallFrame.ArgumentsSlice.init(globalThis.bunVM(), arguments.slice())
        defer args.deinit()

        let codeArg = args.next() ?? {
            return globalThis.throwInvalidArgumentType("transform", "code", "string or Uint8Array")
        }

        let allowStringObject: Bool = true
        var code = try StringOrBuffer.fromJSWithEncodingMaybeAsync(
            globalThis, default_allocator, codeArg, Utf8Encoding, true, allowStringObject,
        ) ?? {
            return globalThis.throwInvalidArgumentType("transform", "code", "string or Uint8Array")
        }
        defer code.deinitAndUnprotect()

        args.eat()
        let loader: ?Loader = {
            if (let arg = args.next()) {
                args.eat()
                return try Loader.fromJS(globalThis, arg)
            }
            return None
        }

        let task = TransformTask.create(
            this,
            code,
            globalThis,
            loader ?? config.defaultLoader,
        )
        task.schedule()
        return task.promise.value()
    }

    /// transformSync - 同步转译
    /// 对应 Bun: JSTranspiler.transformSync
    public func transformSync(globalThis: JsGlobalObject, callframe: JsCallFrame): JsValue {
        let arguments = callframe.argumentsOld(3)
        var args = CallFrame.ArgumentsSlice.init(globalThis.bunVM(), arguments.slice())
        defer args.arena.deinit()

        let codeArg = args.next() ?? {
            return globalThis.throwInvalidArgumentType("transformSync", "code", "string or Uint8Array")
        }

        var arena = MimallocArena.init()
        defer arena.deinit()

        let codeHolder = try StringOrBuffer.fromJS(globalThis, arena.allocator(), codeArg) ?? {
            return globalThis.throwInvalidArgumentType("transformSync", "code", "string or Uint8Array")
        }
        defer codeHolder.deinit()
        let code = codeHolder.slice()
        arguments.ptr[0].ensureStillAlive()
        defer arguments.ptr[0].ensureStillAlive()

        args.eat()
        var jsCtxValue: JsValue = JsValue.zero
        let loader: ?Loader = {
            if (let arg = args.next()) {
                args.eat()
                if (arg.isNumber() || arg.isString()) {
                    return try Loader.fromJS(globalThis, arg)
                }
                if (arg.isObject()) {
                    jsCtxValue = arg
                    return None
                }
            }
            return None
        }

        if (let arg = args.nextEat()) {
            if (arg.isObject()) {
                jsCtxValue = arg
            } else {
                return globalThis.throwInvalidArgumentType("transformSync", "context", "object or loader")
            }
        }
        if (jsCtxValue != JsValue.zero) {
            jsCtxValue.ensureStillAlive()
        }

        defer {
            if (jsCtxValue != JsValue.zero) {
                jsCtxValue.ensureStillAlive()
            }
        }

        let allocator = arena.allocator()

        var astMemoryAllocator = handleOom(allocator.create(ASTMemoryAllocator))
        var astScope = astMemoryAllocator.enter(allocator)
        defer astScope.exit()

        let prevBundler = transpiler
        transpiler.setAllocator(allocator)
        transpiler.macroContext = None
        var log = LoggerLog.init(arena.backingAllocator())
        log.level = config.log.level
        transpiler.setLog(log)

        defer {
            transpiler = prevBundler
        }

        let parseResult = getParseResult(
            allocator, code, loader, jsCtxValue,
        ) ?? {
            if ((transpiler.log.warnings + transpiler.log.errors) > 0) {
                return globalThis.throwValue(try transpiler.log.toJS(globalThis, globalThis.allocator(), "Parse error"))
            }
            return globalThis.throw("Failed to parse code")
        }

        if ((transpiler.log.warnings + transpiler.log.errors) > 0) {
            return globalThis.throwValue(try transpiler.log.toJS(globalThis, globalThis.allocator(), "Parse error"))
        }

        var bufferWriter = this.bufferWriter ?? {
            var writer = JsPrinterBufferWriter.init(arena.backingAllocator())
            writer.buffer.growIfNeeded(code.len)
            writer.buffer.list.expandToCapacity()
            return writer
        }

        defer {
            this.bufferWriter = bufferWriter
        }

        bufferWriter.reset()
        var printer = JsPrinterBufferPrinter.init(bufferWriter)
        let _ = transpiler.print(parseResult, printer, PrintFormat.esmAscii) catch {
            err => return globalThis.throwError(err, "Failed to print code")
        }

        bufferWriter = printer.ctx
        var out = ZigString.init(bufferWriter.written)
        out.setOutputEncoding()

        return out.toJS(globalThis)
    }

    /// scan - 扫描代码
    /// 对应 Bun: JSTranspiler.scan
    public func scan(globalThis: JsGlobalObject, callframe: JsCallFrame): JsValue {
        let arguments = callframe.argumentsOld(3)
        var args = CallFrame.ArgumentsSlice.init(globalThis.bunVM(), arguments.slice())
        defer args.deinit()

        let codeArg = args.next() ?? {
            return globalThis.throwInvalidArgumentType("scan", "code", "string or Uint8Array")
        }

        let codeHolder = try StringOrBuffer.fromJS(globalThis, args.arena.allocator(), codeArg) ?? {
            return globalThis.throwInvalidArgumentType("scan", "code", "string or Uint8Array")
        }
        defer codeHolder.deinit()
        let code = codeHolder.slice()
        args.eat()

        let loader: ?Loader = {
            if (let arg = args.next()) {
                args.eat()
                return try Loader.fromJS(globalThis, arg)
            }
            return None
        }

        if (globalThis.hasException()) {
            return JsValue.zero
        }

        var arena = MimallocArena.init()
        let prevAllocator = transpiler.allocator
        let allocator = arena.allocator()
        transpiler.setAllocator(allocator)
        var log = LoggerLog.init(arena.backingAllocator())
        defer log.deinit()
        transpiler.setLog(log)
        defer {
            transpiler.setLog(config.log)
            transpiler.setAllocator(prevAllocator)
            arena.deinit()
        }

        var astMemoryAllocator = handleOom(allocator.create(ASTMemoryAllocator))
        var astScope = astMemoryAllocator.enter(allocator)
        defer astScope.exit()

        var parseResult = getParseResult(allocator, code, loader, MacroJSCtx.zero) ?? {
            if ((transpiler.log.warnings + transpiler.log.errors) > 0) {
                return globalThis.throwValue(try transpiler.log.toJS(globalThis, globalThis.allocator(), "Parse error"))
            }
            return globalThis.throw("Failed to parse")
        }

        if ((transpiler.log.warnings + transpiler.log.errors) > 0) {
            return globalThis.throwValue(try transpiler.log.toJS(globalThis, globalThis.allocator(), "Parse error"))
        }

        let namedImportsValue = try namedImportsToJS(
            globalThis,
            parseResult.ast.importRecords.slice(),
            config.trimUnusedImports ?? false,
        )

        let namedExportsValue = try namedExportsToJS(
            globalThis,
            parseResult.ast.namedExports,
        )

        return JsValue.createObject2(
            globalThis,
            ZigString.static("imports"),
            ZigString.static("exports"),
            namedImportsValue,
            namedExportsValue,
        )
    }

    /// scanImports - 扫描导入
    /// 对应 Bun: JSTranspiler.scanImports
    public func scanImports(globalThis: JsGlobalObject, callframe: JsCallFrame): JsValue {
        let arguments = callframe.argumentsOld(2)
        var args = CallFrame.ArgumentsSlice.init(globalThis.bunVM(), arguments.slice())
        defer args.deinit()

        let codeArg = args.next() ?? {
            return globalThis.throwInvalidArgumentType("scanImports", "code", "string or Uint8Array")
        }

        let codeHolder = try StringOrBuffer.fromJS(globalThis, args.arena.allocator(), codeArg) ?? {
            if (!globalThis.hasException()) {
                return globalThis.throwInvalidArgumentType("scanImports", "code", "string or Uint8Array")
            }
            return JsValue.zero
        }
        args.eat()
        defer codeHolder.deinit()
        let code = codeHolder.slice()

        var loader: Loader = config.defaultLoader
        if (let arg = args.next()) {
            if (let loader_ = try Loader.fromJS(globalThis, arg)) {
                loader = loader_
            }
            args.eat()
        }

        if (!loader.isJavaScriptLike()) {
            return globalThis.throwInvalidArguments("Only JavaScript-like files support this fast path")
        }

        var arena = MimallocArena.init()
        let prevAllocator = transpiler.allocator
        let allocator = arena.allocator()
        var astMemoryAllocator = handleOom(allocator.create(ASTMemoryAllocator))
        var astScope = astMemoryAllocator.enter(allocator)
        defer astScope.exit()

        transpiler.setAllocator(allocator)
        var log = LoggerLog.init(arena.backingAllocator())
        defer log.deinit()
        transpiler.setLog(log)
        defer {
            transpiler.setLog(config.log)
            transpiler.setAllocator(prevAllocator)
            arena.deinit()
        }

        let source = LoggerSource.initPathString(loader.stdinName(), code)
        var transpiler_ = transpiler
        let jsx = if (config.tsconfig != None) {
            config.tsconfig.getOrThrow().mergeJSX(transpiler.options.jsx)
        } else {
            transpiler.options.jsx
        }

        var opts = ParserOptions.init(jsx, loader)
        if (transpiler.macroContext == None) {
            transpiler.macroContext = MacroContext.init(transpiler)
        }
        opts.macroContext = transpiler.macroContext.getOrThrow()

        transpiler_.resolver.caches.js.scan(
            transpiler.allocator,
            scanPassResult,
            opts,
            transpiler.options.define,
            log,
            source,
        ) catch {
            err =>
                defer scanPassResult.reset()
                if ((log.warnings + log.errors) > 0) {
                    return globalThis.throwValue(try log.toJS(globalThis, globalThis.allocator(), "Failed to scan imports"))
                }
                return globalThis.throwError(err, "Failed to scan imports")
        }

        defer scanPassResult.reset()

        if ((log.warnings + log.errors) > 0) {
            return globalThis.throwValue(try log.toJS(globalThis, globalThis.allocator(), "Failed to scan imports"))
        }

        let namedImportsValue = try namedImportsToJS(
            globalThis,
            scanPassResult.importRecords.items,
            config.trimUnusedImports ?? false,
        )
        return namedImportsValue
    }

    // ========================================================================
    // 辅助方法
    // ========================================================================

    /// 检查代码是否看起来像会被误解为块的对象字面量
    /// 返回 true 如果代码以 { 开头 (跳过空白后) 且不以 ; 结尾
    /// 这与 Node.js REPL 行为匹配
    func isLikelyObjectLiteral(code: String): Bool {
        // 跳过前导空白
        var start: Int = 0
        while (start < code.length && (code[start] == ' ' || code[start] == '\t' || code[start] == '\n' || code[start] == '\r')) {
            start += 1
        }

        // 检查是否以 { 开头
        if (start >= code.length || code[start] != '{') {
            return false
        }

        // 跳过尾部空白
        var end: Int = code.length
        while (end > 0 && (code[end - 1] == ' ' || code[end - 1] == '\t' || code[end - 1] == '\n' || code[end - 1] == '\r')) {
            end -= 1
        }

        // 检查是否以分号结尾 — 如果是, 可能是块语句
        if (end > 0 && code[end - 1] == ';') {
            return false
        }

        return true
    }

    /// 获取解析结果
    func getParseResult(allocator: Allocator, code: String, loader: ?Loader, macroJsCtx: MacroJSCtx): ?ParseResult {
        let name = config.defaultLoader.stdinName()

        // 在 REPL 模式下，将可能是对象字面量的代码包裹在括号中
        let processedCode: String = if (config.replMode && isLikelyObjectLiteral(code)) {
            "(" + code + ")"
        } else {
            code
        }

        let source = LoggerSource.initPathString(name, processedCode)

        let jsx = if (config.tsconfig != None) {
            config.tsconfig.getOrThrow().mergeJSX(transpiler.options.jsx)
        } else {
            transpiler.options.jsx
        }

        let parseOptions = ParseOptions(
            allocator: allocator,
            macroRemappings: config.macroMap,
            dirnameFd: Fd.invalid,
            fileDescriptor: None,
            loader: loader ?? config.defaultLoader,
            jsx: jsx,
            path: source.path,
            virtualSource: source,
            replaceExports: config.runtime.replaceExports,
            macroJsCtx: macroJsCtx,
            experimentalDecorators: if (let ts = config.tsconfig) ts.experimentalDecorators else false,
            emitDecoratorMetadata: if (let ts = config.tsconfig) ts.emitDecoratorMetadata else false,
        )

        return transpiler.parse(parseOptions, None)
    }

    /// 引用计数
    public func ref(): Unit {
        refCount.ref()
    }

    public func deref(): Unit {
        refCount.deref()
    }

    /// GC 终结器
    public func finalize(): Unit {
        deref()
    }

    /// 释放资源
    public func deinit(): Unit {
        transpiler.log.clearAndFree()
        scanPassResult.namedImports.deinit(scanPassResult.importRecords.allocator)
        scanPassResult.importRecords.deinit()
        scanPassResult.usedSymbols.deinit()
        if (let bw = bufferWriter) {
            bw.buffer.deinit()
        }
        if (let tsconfig = config.tsconfig) {
            tsconfig.deinit()
        }
        arena.deinit()
    }

    // ========================================================================
    // TransformTask - 异步转译任务
    // ========================================================================

    /// TransformTask - 异步转译任务
    /// 对应 Bun: JSTranspiler.TransformTask
    public class TransformTask {
        public var inputCode: StringOrBuffer
        public var outputCode: BunString
        public var transpiler: Transpiler
        public var jsInstance: JSTranspiler
        public var log: LoggerLog
        public var err: ?Error
        public var macroMap: MacroMap
        public var tsconfig: ?TSConfigJSON
        public var loader: Loader
        public var global_: JSGlobalObject
        public var replaceExports: ReplaceableExportMap

        /// 创建异步转译任务
        public static func create(
            transpiler: JSTranspiler,
            inputCode: StringOrBuffer,
            globalThis: JSGlobalObject,
            loader: Loader,
        ): AsyncTransformTask {
            var transformTask = TransformTask(
                inputCode: inputCode,
                transpiler: transpiler.transpiler,
                global_: globalThis,
                macroMap: transpiler.config.macroMap,
                tsconfig: transpiler.config.tsconfig,
                log: LoggerLog.init(),
                loader: loader,
                replaceExports: transpiler.config.runtime.replaceExports,
                jsInstance: transpiler,
            )

            transformTask.log.level = transpiler.config.log.level
            transformTask.transpiler = transpiler.transpiler
            transformTask.transpiler.linker.resolver = transformTask.transpiler.resolver

            transformTask.transpiler.setLog(transformTask.log)
            transformTask.transpiler.setAllocator(default_allocator)

            transpiler.ref()
            return AsyncTransformTask.createOnJSThread(default_allocator, globalThis, transformTask)
        }

        /// 在工作线程上运行转译
        public func run(): Unit {
            let name = loader.stdinName()
            let source = LoggerSource.initPathString(name, inputCode.slice())

            var arena = MimallocArena.init()
            defer arena.deinit()

            let allocator = arena.allocator()
            var astMemoryAllocator = handleOom(allocator.create(ASTMemoryAllocator))
            var astScope = astMemoryAllocator.enter(allocator)
            defer astScope.exit()

            transpiler.setAllocator(allocator)
            transpiler.setLog(log)
            log.msgs.allocator = default_allocator

            let jsx = if (tsconfig != None) {
                tsconfig.getOrThrow().mergeJSX(transpiler.options.jsx)
            } else {
                transpiler.options.jsx
            }

            let parseOptions = ParseOptions(
                allocator: allocator,
                macroRemappings: macroMap,
                dirnameFd: Fd.invalid,
                fileDescriptor: None,
                loader: loader,
                jsx: jsx,
                path: source.path,
                virtualSource: source,
                replaceExports: replaceExports,
                experimentalDecorators: if (let ts = tsconfig) ts.experimentalDecorators else false,
                emitDecoratorMetadata: if (let ts = tsconfig) ts.emitDecoratorMetadata else false,
            )

            let parseResult = transpiler.parse(parseOptions, None) ?? {
                err = Error.parseError
                return
            }

            if (parseResult.empty) {
                outputCode = BunString.empty
                return
            }

            var bufferWriter = JsPrinterBufferWriter.init(allocator)
            bufferWriter.buffer.list.ensureTotalCapacity(allocator, 512)
            bufferWriter.reset()

            var printer = JsPrinterBufferPrinter.init(bufferWriter)
            let printed = transpiler.print(parseResult, printer, PrintFormat.esmAscii) catch {
                err => err
                return
            }

            if (printed > 0) {
                bufferWriter = printer.ctx
                bufferWriter.buffer.list.items = bufferWriter.written
                outputCode = BunString.cloneUTF8(bufferWriter.written)
            } else {
                outputCode = BunString.empty
            }
        }

        /// 完成回调
        public func then(promise: JsPromise): Unit {
            defer deinit()

            if (log.hasAny() || err != None) {
                if (let e = err) {
                    if (!log.hasAny()) {
                        let errorValue = BuildMessage.create(
                            global_,
                            default_allocator,
                            LoggerMsg(data: LoggerData(text: e.name())),
                        )
                        try promise.rejectWithAsyncStack(global_, errorValue)
                        return
                    }
                }

                try promise.rejectWithAsyncStack(global_, log.toJS(global_, default_allocator, "Transform failed"))
                return
            }

            // 成功
            let value = outputCode.transferToJS(global_) catch {
                e => return promise.reject(global_, global_.takeException(e))
            }
            return promise.resolve(global_, value)
        }

        /// 释放资源
        public func deinit(): Unit {
            log.deinit()
            inputCode.deinitAndUnprotect()
            outputCode.deref()
            // tsconfig 由 JSTranspiler 拥有，不在此释放
            jsInstance.deref()
        }
    }
}

// ============================================================================
// 辅助函数
// ============================================================================

/// 导出替换值 — 将 JS 值转换为 AST 表达式
/// 对应 Bun: exportReplacementValue
func exportReplacementValue(value: JsValue, globalThis: JsGlobalObject, allocator: Allocator): ?Expr {
    if (value.isBoolean()) {
        return Expr(
            data: ExprData.eBoolean(BoolValue(value: value.toBoolean())),
            loc: Loc.empty,
        )
    }

    if (value.isNumber()) {
        return Expr(
            data: ExprData.eNumber(NumberValue(value: value.asNumber())),
            loc: Loc.empty,
        )
    }

    if (value.isNull()) {
        return Expr(
            data: ExprData.eNull(),
            loc: Loc.empty,
        )
    }

    if (value.isUndefined()) {
        return Expr(
            data: ExprData.eUndefined(),
            loc: Loc.empty,
        )
    }

    if (value.isString()) {
        let str = EString(data: value.getZigString(globalThis).toString())
        let out = allocator.alloc(str)
        return Expr(
            data: ExprData.eString(out),
            loc: Loc.empty,
        )
    }

    return None
}

/// 将命名导出转换为 JS 值
/// 对应 Bun: namedExportsToJS
func namedExportsToJS(global: JsGlobalObject, namedExports: NamedExports): JsValue {
    if (namedExports.count() == 0) {
        return JsValue.createEmptyArray(global, 0)
    }

    var names = Array<BunString>()
    var namedExportsIter = namedExports.iterator()
    while (let entry = namedExportsIter.next()) {
        names.append(BunString.fromBytes(entry.key))
    }
    return BunString.toJSArray(global, names)
}

/// 将命名导入转换为 JS 值
/// 对应 Bun: namedImportsToJS
func namedImportsToJS(global: JsGlobalObject, importRecords: Array<ImportRecord>, trimUnusedImports: Bool): JsValue {
    let pathLabel = ZigString.static("path")
    let kindLabel = ZigString.static("kind")

    var count: UInt32 = 0
    for (record in importRecords) {
        if (record.flags.isInternal) {
            continue
        }
        if (trimUnusedImports && record.flags.isUnused) {
            continue
        }
        count += 1
    }

    let array = try JsValue.createEmptyArray(global, count)
    array.ensureStillAlive()

    var i: UInt32 = 0
    for (record in importRecords) {
        if (record.flags.isInternal) {
            continue
        }
        if (trimUnusedImports && record.flags.isUnused) {
            continue
        }

        array.ensureStillAlive()
        let path = ZigString.init(record.path.text).toJS(global)
        let kind = ZigString.init(record.kind.label()).toJS(global)
        try array.putIndex(global, i, try JsValue.createObject2(global, pathLabel, kindLabel, path, kind))
        i += 1
    }

    return array
}
