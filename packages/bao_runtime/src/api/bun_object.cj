// 严格翻译自: src/runtime/api/BunObject.zig
package bao_runtime

import bao_jsc.*
import bao_core.*
import bao_collections.*
import bao_sys.*
import bao_io.*
import bao_event_loop.*

// ============================================================================
// BunObject - Bun 全局对象的属性和方法注册表
// 对应 Bun: src/runtime/api/BunObject.zig
// ============================================================================

/// BunObject 定义了所有挂载在 Bun 全局对象上的回调函数和惰性属性
public class BunObject {

    // ========================================================================
    // 回调函数 (Callbacks)
    // ========================================================================

    /// allocUnsafe - 分配未初始化的 Uint8Array
    public static func allocUnsafe(globalThis: JsGlobalObject, callframe: JsCallFrame): JsValue {
        let arguments = callframe.argumentsOld(1)
        let size = arguments.ptr[0]
        if (!size.isUInt32AsAnyInt()) {
            return globalThis.throwInvalidArguments("Expected a positive number")
        }
        return JsValue.createUninitializedUint8Array(globalThis, size.toUInt64NoTruncate())
    }

    /// shellEscape - Shell 转义字符串
    public static func shellEscape(globalThis: JsGlobalObject, callframe: JsCallFrame): JsValue {
        let arguments = callframe.argumentsOld(1)
        if (arguments.len < 1) {
            return globalThis.throw("shell escape expected at least 1 argument")
        }

        let jsval = arguments.ptr[0]
        let bunstr = try jsval.toBunString(globalThis)
        if (globalThis.hasException()) { return JsValue.zero }
        defer bunstr.deref()

        var outbuf = ArrayList<UInt8>.init(default_allocator)
        defer outbuf.deinit()

        if (Shell.needsEscapeBunstr(bunstr)) {
            let result = try Shell.escapeBunStr(bunstr, outbuf, true)
            if (!result) {
                return globalThis.throw("String has invalid utf-16: \{bunstr.byteSlice()}")
            }
            var str = BunString.cloneUTF8(outbuf.items)
            return str.transferToJS(globalThis)
        }

        return jsval
    }

    /// which - 查找可执行文件路径
    public static func which(globalThis: JsGlobalObject, callframe: JsCallFrame): JsValue {
        let arguments = callframe.argumentsOld(2)
        let pathBuf = PathBufferPool.get()
        defer PathBufferPool.put(pathBuf)
        var arguments = JsCallFrame.ArgumentsSlice.init(globalThis.bunVM(), arguments.slice())
        defer arguments.deinit()

        let pathArg = arguments.nextEat() ?? {
            return globalThis.throw("which: expected 1 argument, got 0")
        }

        if (pathArg.isEmptyOrUndefinedOrNull()) {
            return JsValue.jsNull()
        }

        var binStr = try pathArg.toSlice(globalThis, globalThis.bunVM().allocator)
        if (globalThis.hasException()) { return JsValue.zero }

        if (binStr.len >= MAX_PATH_BYTES) {
            return globalThis.throw("bin path is too long")
        }

        if (binStr.len == 0) {
            return JsValue.jsNull()
        }

        let pathStr = ZigString.Slice.fromUTF8NeverFree(
            globalThis.bunVM().transpiler.env.get("PATH") ?? "",
        )
        let cwdStr = ZigString.Slice.fromUTF8NeverFree(
            globalThis.bunVM().transpiler.fs.top_level_dir,
        )

        if (let arg = arguments.nextEat()) {
            if (!arg.isEmptyOrUndefinedOrNull() && arg.isObject()) {
                if (let str = try arg.get(globalThis, "PATH")) {
                    pathStr = try str.toSlice(globalThis, globalThis.bunVM().allocator)
                }
                if (let str = try arg.get(globalThis, "cwd")) {
                    cwdStr = try str.toSlice(globalThis, globalThis.bunVM().allocator)
                }
            }
        }

        if (let binPath = Which.which(pathBuf, pathStr.slice(), cwdStr.slice(), binStr.slice())) {
            return ZigString.init(binPath).withEncoding().toJS(globalThis)
        }

        return JsValue.jsNull()
    }

    /// sleepSync - 同步休眠
    public static func sleepSync(globalObject: JsGlobalObject, callframe: JsCallFrame): JsValue {
        let arguments = callframe.argumentsOld(1)

        if (arguments.len < 1) {
            return globalObject.throwNotEnoughArguments("sleepSync", 1, 0)
        }
        let arg = arguments.slice()[0]

        if (!arg.isNumber()) {
            return globalObject.throwInvalidArgumentType("sleepSync", "milliseconds", "number")
        }

        let milliseconds = try arg.coerceInt32(globalObject)
        if (milliseconds < 0) {
            return globalObject.throwInvalidArguments("argument to sleepSync must not be negative, got \{milliseconds}")
        }

        Thread.sleep(UInt64(milliseconds) * NS_PER_MS)
        return JsValue.jsUndefined()
    }

    /// nanoseconds - 获取高精度纳秒时间戳
    public static func nanoseconds(globalThis: JsGlobalObject, callframe: JsCallFrame): JsValue {
        let ns = globalThis.bunVM().origin_timer.read()
        return JsValue.jsNumberFromUint64(ns)
    }

    /// shrink - 缩小内存占用
    public static func shrink(globalObject: JsGlobalObject, callframe: JsCallFrame): JsValue {
        globalObject.vm().shrinkFootprint()
        return JsValue.jsUndefined()
    }

    /// gc - 垃圾回收
    public static func gc(vm: VirtualMachine, sync: Bool): Int64 {
        return vm.garbageCollect(sync)
    }

    /// stringWidth - 获取字符串的显示宽度
    public static func stringWidth(globalObject: JsGlobalObject, callFrame: JsCallFrame): JsValue {
        return BunString.jsGetStringWidth(globalObject, callFrame)
    }

    /// indexOfLine - 在缓冲区中查找行索引
    public static func indexOfLine(globalThis: JsGlobalObject, callframe: JsCallFrame): JsValue {
        let arguments = callframe.argumentsOld(2).slice()
        if (arguments.len == 0) {
            return JsValue.jsNumberFromInt32(-1)
        }

        var buffer = arguments[0].asArrayBuffer(globalThis) ?? {
            return JsValue.jsNumberFromInt32(-1)
        }

        var offset: Int64 = 0
        if (arguments.len > 1) {
            let offsetValue = try arguments[1].coerceInt64(globalThis)
            offset = Int64(Math.max(offsetValue, 0))
        }

        let bytes = buffer.byteSlice()
        var currentOffset = offset
        let end = UInt32(bytes.len)

        while (currentOffset < end) {
            if (let i = Strings.indexOfNewlineOrNonASCII(bytes, UInt32(currentOffset))) {
                let byte = bytes[i]
                if (byte > 0x7F) {
                    currentOffset += Int64(Math.max(Strings.wtf8ByteSequenceLength(byte), 1))
                    continue
                }

                if (byte == '\n') {
                    return JsValue.jsNumber(i)
                }

                currentOffset = i + 1
            } else {
                break
            }
        }

        return JsValue.jsNumberFromInt32(-1)
    }

    /// inspect - 检查值并返回字符串表示
    public static func inspect(globalThis: JsGlobalObject, callframe: JsCallFrame): JsValue {
        let arguments = callframe.argumentsOld(4).slice()
        if (arguments.len == 0) {
            return BunString.empty.toJS(globalThis)
        }

        for (arg in arguments) { arg.protect() }
        defer {
            for (arg in arguments) { arg.unprotect() }
        }

        var formatOptions = ConsoleObject.FormatOptions{
            enable_colors = false,
            add_newline = false,
            flush = false,
            max_depth = 8,
            quote_strings = true,
            ordered_properties = false,
        }
        if (arguments.len > 1) {
            try formatOptions.fromJS(globalThis, arguments[1..])
        }

        var array = IoWriter.Allocating.init(default_allocator)
        defer array.deinit()
        let writer = array.writer

        try ConsoleObject.format2(
            .Debug,
            globalThis,
            arguments.ptr,
            1,
            writer,
            formatOptions,
        )
        if (globalThis.hasException()) { return Error.JSError }
        writer.flush() catch { return globalThis.throwOutOfMemory() }

        var out = ZigString.init(array.written()).withEncoding()
        let ret = out.toJS(globalThis)
        return ret
    }

    /// resolveSync - 同步解析模块路径
    public static func resolveSync(globalObject: JsGlobalObject, callframe: JsCallFrame): JsValue {
        return try doResolve(globalObject, callframe.arguments())
    }

    /// resolve - 异步解析模块路径 (返回 Promise)
    public static func resolve(globalObject: JsGlobalObject, callframe: JsCallFrame): JsValue {
        let arguments = callframe.argumentsOld(3)
        let value = doResolve(globalObject, arguments.slice()) catch { e =>
            let err = globalObject.takeError(e)
            return JsPromise.dangerouslyCreateRejectedPromiseValueWithoutNotifyingVM(globalObject, err)
        }
        return JsPromise.resolvedPromiseValue(globalObject, value)
    }

    /// openInEditor - 在编辑器中打开文件
    public static func openInEditor(globalThis: JsGlobalObject, callframe: JsCallFrame): JsValue {
        var edit = globalThis.bunVM().rareData().editor_context
        let args = callframe.argumentsOld(4)
        var arguments = JsCallFrame.ArgumentsSlice.init(globalThis.bunVM(), args.slice())
        defer arguments.deinit()
        var path: String = ""
        var editorChoice: Editor = null
        var line: String = null
        var column: String = null

        if (let filePath = arguments.nextEat()) {
            path = (try filePath.toSlice(globalThis, arguments.arena.allocator())).slice()
        }

        if (let opts = arguments.nextEat()) {
            if (!opts.isUndefinedOrNull()) {
                if (let editorVal = try opts.getTruthy(globalThis, "editor")) {
                    var sliced = try editorVal.toSlice(globalThis, arguments.arena.allocator())
                    let prevName = edit.name

                    if (!Strings.eqlLong(prevName, sliced.slice(), true)) {
                        let prev = edit
                        edit.name = sliced.slice()
                        edit.detectEditor(globalThis.bunVM().transpiler.env)
                        editorChoice = edit.editor
                        if (editorChoice == null) {
                            edit = prev
                            return globalThis.throw("Could not find editor \"\{sliced.slice()}\"")
                        }
                    }
                }

                if (let line_ = try opts.getTruthy(globalThis, "line")) {
                    line = (try line_.toSlice(globalThis, arguments.arena.allocator())).slice()
                }

                if (let column_ = try opts.getTruthy(globalThis, "column")) {
                    column = (try column_.toSlice(globalThis, arguments.arena.allocator())).slice()
                }
            }
        }

        let editor = editorChoice ?? edit.editor ?? {
            edit.autoDetectEditor(globalThis.bunVM().transpiler.env)
            if (edit.editor == null) {
                return globalThis.throw("Failed to auto-detect editor")
            }
            return edit.editor
        }

        if (path.len == 0) {
            return globalThis.throw("No file path specified")
        }

        editor.open(edit.path, path, line, column, arguments.arena.allocator()) catch { err =>
            return globalThis.throw("Opening editor failed \{err}")
        }

        return JsValue.jsUndefined()
    }

    /// serve - 启动 HTTP/HTTPS 服务器
    public static func serve(globalObject: JsGlobalObject, callframe: JsCallFrame): JsValue {
        let arguments = callframe.argumentsOld(2).slice()
        var config = {
            var args = JsCallFrame.ArgumentsSlice.init(globalObject.bunVM(), arguments)
            var config = ServerConfig()

            try ServerConfig.fromJS(
                globalObject,
                config,
                args,
                ServerConfigOptions{
                    allow_bake_config = FeatureFlags.bake(),
                    is_fetch_required = true,
                    has_user_routes = false,
                },
            )

            if (globalObject.hasException()) {
                config.deinit()
                return JsValue.zero
            }

            return config
        }

        let vm = globalObject.bunVM()

        if (config.allow_hot) {
            if (let hot = vm.hotMap()) {
                if (config.id.len == 0) {
                    config.id = config.computeID(globalObject.allocator())
                }

                if (let entry = hot.getEntry(config.id)) {
                    switch (entry.tag()) {
                        case "HTTPServer" => {
                            let server = entry.as(HTTPServer)
                            server.onReloadFromZig(config, globalObject)
                            return server.js_value.tryGet() ?? JsValue.jsUndefined()
                        }
                        case "DebugHTTPServer" => {
                            let server = entry.as(DebugHTTPServer)
                            server.onReloadFromZig(config, globalObject)
                            return server.js_value.tryGet() ?? JsValue.jsUndefined()
                        }
                        case "DebugHTTPSServer" => {
                            let server = entry.as(DebugHTTPSServer)
                            server.onReloadFromZig(config, globalObject)
                            return server.js_value.tryGet() ?? JsValue.jsUndefined()
                        }
                        case "HTTPSServer" => {
                            let server = entry.as(HTTPSServer)
                            server.onReloadFromZig(config, globalObject)
                            return server.js_value.tryGet() ?? JsValue.jsUndefined()
                        }
                        else => {}
                    }
                }
            }
        }

        let hasSSLConfig = config.ssl_config != null
        let development = config.isDevelopment()

        // 根据 SSL 和开发模式选择服务器类型
        let server = try ServerType.init(config, globalObject)
        if (globalObject.hasException()) { return JsValue.zero }
        let routeListObject = server.listen()
        if (globalObject.hasException()) { return JsValue.zero }
        let obj = server.toJS(globalObject)
        if (routeListObject != JsValue.zero) {
            server.js.routeListSetCached(obj, globalObject, routeListObject)
        }
        server.js_value.setStrong(obj, globalObject)

        if (config.allow_hot) {
            if (let hot = globalObject.bunVM().hotMap()) {
                hot.insert(config.id, server)
            }
        }

        if (let debugger = vm.debugger) {
            debugger.http_server_agent.notifyServerStarted(AnyServer.from(server))
            debugger.http_server_agent.notifyServerRoutesUpdated(AnyServer.from(server)) catch { err =>
                handleOom(err)
            }
        }

        return obj
    }

    // ========================================================================
    // 惰性属性 Getter
    // ========================================================================

    /// getCWD - 获取当前工作目录
    public static func getCWD(globalThis: JsGlobalObject, object: JsObject): JsValue {
        return ZigString.init(VirtualMachine.get().transpiler.fs.top_level_dir).toJS(globalThis)
    }

    /// getOrigin - 获取服务器来源
    public static func getOrigin(globalThis: JsGlobalObject, object: JsObject): JsValue {
        return ZigString.init(VirtualMachine.get().origin.origin).toJS(globalThis)
    }

    /// enableANSIColors - 是否启用 ANSI 颜色
    public static func enableANSIColors(globalThis: JsGlobalObject, object: JsObject): JsValue {
        return JsValue.jsBoolean(Output.enable_ansi_colors_stdout || Output.enable_ansi_colors_stderr)
    }

    /// getArgv - 获取命令行参数
    public static func getArgv(globalThis: JsGlobalObject, object: JsObject): JsValue {
        return NodeProcess.getArgv(globalThis)
    }

    /// getInspect - 获取 inspect 函数对象
    public static func getInspect(globalObject: JsGlobalObject, object: JsObject): JsValue {
        let fun = JsFunction.create(globalObject, "inspect", inspect, 2)
        var str = ZigString.init("nodejs.util.inspect.custom")
        fun.put(globalObject, ZigString.static("custom"), JsValue.symbolFor(globalObject, str))
        fun.put(globalObject, ZigString.static("table"), JsFunction.create(globalObject, "table", inspectTable, 3))
        return fun
    }

    /// getTranspilerConstructor
    public static func getTranspilerConstructor(globalThis: JsGlobalObject, object: JsObject): JsValue {
        return JSTranspiler.js.getConstructor(globalThis)
    }

    /// getFileSystemRouter
    public static func getFileSystemRouter(globalThis: JsGlobalObject, object: JsObject): JsValue {
        return FileSystemRouter.js.getConstructor(globalThis)
    }

    /// getGlobConstructor
    public static func getGlobConstructor(globalThis: JsGlobalObject, object: JsObject): JsValue {
        return Glob.js.getConstructor(globalThis)
    }

    /// getImageConstructor
    public static func getImageConstructor(globalThis: JsGlobalObject, object: JsObject): JsValue {
        return Image.js.getConstructor(globalThis)
    }

    /// getArchiveConstructor
    public static func getArchiveConstructor(globalThis: JsGlobalObject, object: JsObject): JsValue {
        return Archive.js.getConstructor(globalThis)
    }

    /// getHashObject
    public static func getHashObject(globalThis: JsGlobalObject, object: JsObject): JsValue {
        return HashObject.create(globalThis)
    }

    /// getJSONCObject
    public static func getJSONCObject(globalThis: JsGlobalObject, object: JsObject): JsValue {
        return JSONCObject.create(globalThis)
    }

    /// getMarkdownObject
    public static func getMarkdownObject(globalThis: JsGlobalObject, object: JsObject): JsValue {
        return MarkdownObject.create(globalThis)
    }

    /// getTOMLObject
    public static func getTOMLObject(globalThis: JsGlobalObject, object: JsObject): JsValue {
        return TOMLObject.create(globalThis)
    }

    /// getJSON5Object
    public static func getJSON5Object(globalThis: JsGlobalObject, object: JsObject): JsValue {
        return JSON5Object.create(globalThis)
    }

    /// getYAMLObject
    public static func getYAMLObject(globalThis: JsGlobalObject, object: JsObject): JsValue {
        return YAMLObject.create(globalThis)
    }

    /// getSemver
    public static func getSemver(globalThis: JsGlobalObject, object: JsObject): JsValue {
        return SemverObject.create(globalThis)
    }

    /// getUnsafe
    public static func getUnsafe(globalThis: JsGlobalObject, object: JsObject): JsValue {
        return UnsafeObject.create(globalThis)
    }

    /// getCSRFObject
    public static func getCSRFObject(globalObject: JsGlobalObject, object: JsObject): JsValue {
        return CSRFObject.create(globalObject)
    }

    /// getS3ClientConstructor
    public static func getS3ClientConstructor(globalThis: JsGlobalObject, object: JsObject): JsValue {
        return S3Client.js.getConstructor(globalThis)
    }

    /// getS3DefaultClient
    public static func getS3DefaultClient(globalThis: JsGlobalObject, object: JsObject): JsValue {
        return globalThis.bunVM().rareData().s3DefaultClient(globalThis)
    }

    /// getValkeyClientConstructor
    public static func getValkeyClientConstructor(globalThis: JsGlobalObject, object: JsObject): JsValue {
        return Valkey.js.getConstructor(globalThis)
    }

    /// getValkeyDefaultClient
    public static func getValkeyDefaultClient(globalThis: JsGlobalObject, object: JsObject): JsValue {
        var valkey = try Valkey.createNoJsNoPubsub(globalThis, [JsValue.jsUndefined()])
        let asJs = valkey.toJS(globalThis)
        valkey.this_value = JsRef.initWeak(asJs)
        valkey._subscription_ctx = SubscriptionCtx.init(valkey) catch { err =>
            if (err != Error.JSError) {
                _ = globalThis.throwError(err, "Failed to create Redis client") catch {}
                return JsValue.zero
            }
            return JsValue.zero
        }
        return asJs
    }

    /// getTerminalConstructor
    public static func getTerminalConstructor(globalThis: JsGlobalObject, object: JsObject): JsValue {
        return Terminal.js.getConstructor(globalThis)
    }

    /// getEmbeddedFiles
    public static func getEmbeddedFiles(globalThis: JsGlobalObject, object: JsObject): JsValue {
        let vm = globalThis.bunVM()
        let graph = vm.standalone_module_graph ?? return try JsValue.createEmptyArray(globalThis, 0)

        let unsortedFiles = graph.files.values()
        var sortIndices = handleOom(ArrayList<UInt32>.initCapacity(default_allocator, unsortedFiles.len))
        defer sortIndices.deinit()
        for (index in 0..<unsortedFiles.len) {
            if (!unsortedFiles[index].appearsInEmbeddedFilesArray()) { continue }
            sortIndices.appendAssumeCapacity(UInt32(index))
        }

        var i: UInt32 = 0
        var array = try JsValue.createEmptyArray(globalThis, sortIndices.items.len)
        sort(sortIndices.items, unsortedFiles, StandaloneModuleGraph.File.lessThanByIndex)
        for (index in sortIndices.items) {
            let file = unsortedFiles[index]
            let inputBlob = file.blob(globalThis)
            let blob = Blob.new(inputBlob.dupeWithContentType(true))
            blob.name = inputBlob.name.dupeRef()
            try array.putIndex(globalThis, i, blob.toJS(globalThis))
            i += 1
        }

        return array
    }

    // ========================================================================
    // Getter / Setter
    // ========================================================================

    /// main getter
    public static func getMain(globalThis: JsGlobalObject): JsValue {
        let vm = globalThis.bunVM()
        if (let overriddenMain = vm.overridden_main.get()) { return overriddenMain }

        // 尝试使用已解析的文件路径
        if (!vm.main_resolved_path.isEmpty()) {
            return vm.main_resolved_path.toJS(globalThis) catch JsValue.zero
        }

        return ZigString.init(vm.main).toJS(globalThis)
    }

    /// main setter
    public static func setMain(globalThis: JsGlobalObject, newValue: JsValue): Bool {
        globalThis.bunVM().overridden_main.set(globalThis, newValue)
        return true
    }

    // ========================================================================
    // Stdin/Stdout/Stderr 创建
    // ========================================================================

    /// 创建 Bun.stdin 的惰性属性值
    public static func createBunStdin(globalThis: JsGlobalObject): JsValue {
        var rareData = globalThis.bunVM().rareData()
        var store = rareData.stdin()
        store.ref()
        var blob = Blob.new(Blob.initWithStore(store, globalThis))
        return blob.toJS(globalThis)
    }

    /// 创建 Bun.stderr 的惰性属性值
    public static func createBunStderr(globalThis: JsGlobalObject): JsValue {
        var rareData = globalThis.bunVM().rareData()
        var store = rareData.stderr()
        store.ref()
        var blob = Blob.new(Blob.initWithStore(store, globalThis))
        return blob.toJS(globalThis)
    }

    /// 创建 Bun.stdout 的惰性属性值
    public static func createBunStdout(globalThis: JsGlobalObject): JsValue {
        var rareData = globalThis.bunVM().rareData()
        var store = rareData.stdout()
        store.ref()
        var blob = Blob.new(Blob.initWithStore(store, globalThis))
        return blob.toJS(globalThis)
    }

    // ========================================================================
    // 私有辅助函数
    // ========================================================================

    /// 内部路径解析实现
    static func doResolve(globalThis: JsGlobalObject, arguments: Array<JsValue>): JsValue {
        var args = JsCallFrame.ArgumentsSlice.init(globalThis.bunVM(), arguments)
        defer args.deinit()

        let specifier = args.protectEatNext() ?? {
            return globalThis.throwInvalidArguments("Expected a specifier and a from path")
        }

        if (specifier.isUndefinedOrNull()) {
            return globalThis.throwInvalidArguments("specifier must be a string")
        }

        let from = args.protectEatNext() ?? {
            return globalThis.throwInvalidArguments("Expected a from path")
        }

        if (from.isUndefinedOrNull()) {
            return globalThis.throwInvalidArguments("from must be a string")
        }

        var isEsm = true
        if (let next = args.nextEat()) {
            if (next.isBoolean()) {
                isEsm = next.toBoolean()
            } else {
                return globalThis.throwInvalidArguments("esm must be a boolean")
            }
        }

        let specifierStr = try specifier.toBunString(globalThis)
        defer specifierStr.deref()
        let fromStr = try from.toBunString(globalThis)
        defer fromStr.deref()

        return doResolveWithArgs(globalThis, specifierStr, fromStr, isEsm, false, false)
    }

    /// 带参数的路径解析
    static func doResolveWithArgs(
        ctx: JsGlobalObject,
        specifier: BunString,
        from: BunString,
        isEsm: Bool,
        isFilePath: Bool,
        isUserRequireResolve: Bool,
    ): JsValue {
        var errorable: ErrorableString
        var queryString = BunString.empty
        defer queryString.deref()

        let specifierDecoded = if (specifier.hasPrefixComptime("file://")) {
            URL.pathFromFileURL(specifier)
        } else {
            specifier.dupeRef()
        }
        defer specifierDecoded.deref()

        try VirtualMachine.resolveMaybeNeedsTrailingSlash(
            errorable,
            ctx,
            specifierDecoded,
            from,
            queryString,
            isEsm,
            isFilePath,
            isUserRequireResolve,
        )

        if (!errorable.success) {
            return ctx.throwValue(errorable.result.err.value)
        }
        defer errorable.result.value.deref()

        if (!queryString.isEmpty()) {
            var stack = StackFallback(1024, ctx.allocator())
            let allocator = stack.get()
            var arraylist = ArrayList<UInt8>.initCapacity(allocator, 1024) catch { unreachable }
            defer arraylist.deinit()
            try arraylist.writer().print("\{errorable.result.value}\{queryString}")
            return ZigString.initUTF8(arraylist.items).toJS(ctx)
        }

        return errorable.result.value.toJS(ctx)
    }

    /// inspectTable - 生成表格形式的检查输出
    public static func inspectTable(globalThis: JsGlobalObject, callframe: JsCallFrame): JsValue {
        var argsBuf = callframe.argumentsUndef(5)
        var allArguments = argsBuf.mut()
        if (allArguments[0].isUndefinedOrNull() || !allArguments[0].isObject()) {
            return BunString.empty.toJS(globalThis)
        }

        for (arg in allArguments) { arg.protect() }
        defer {
            for (arg in allArguments) { arg.unprotect() }
        }

        var arguments = allArguments[0..]
        let value = arguments[0]

        if (!arguments[1].isArray()) {
            arguments[2] = arguments[1]
            arguments[1] = JsValue.jsUndefined()
        }

        var formatOptions = ConsoleObject.FormatOptions{
            enable_colors = false,
            add_newline = false,
            flush = false,
            max_depth = 5,
            quote_strings = true,
            ordered_properties = false,
            single_line = true,
        }
        if (arguments[2].isObject()) {
            try formatOptions.fromJS(globalThis, arguments[2..])
        }

        var array = IoWriter.Allocating.init(default_allocator)
        defer array.deinit()
        let writer = array.writer

        let properties = if (arguments[1].jsType().isArray()) arguments[1] else JsValue.jsUndefined()
        var tablePrinter = try ConsoleObject.TablePrinter.init(globalThis, .Log, value, properties)
        tablePrinter.value_formatter.depth = formatOptions.max_depth
        tablePrinter.value_formatter.ordered_properties = formatOptions.ordered_properties
        tablePrinter.value_formatter.single_line = formatOptions.single_line

        tablePrinter.printTable(writer, formatOptions.enable_colors) catch {
            if (!globalThis.hasException()) {
                return globalThis.throwOutOfMemory()
            }
            return JsValue.zero
        }

        writer.flush() catch { return Error.OutOfMemory }

        return BunString.createUTF8ForJS(globalThis, array.written())
    }

    /// mmapFile - 内存映射文件
    public static func mmapFile(globalThis: JsGlobalObject, callframe: JsCallFrame): JsValue {
        if (Environment.isWindows) {
            return globalThis.throwTODO("mmapFile is not supported on Windows")
        }

        let arguments = callframe.argumentsOld(2)
        var args = JsCallFrame.ArgumentsSlice.init(globalThis.bunVM(), arguments.slice())
        defer args.deinit()

        var buf = PathBuffer()
        let path = {
            if (let path = args.nextEat()) {
                if (path.isString()) {
                    let pathStr = try path.toSlice(globalThis, args.arena.allocator())
                    if (pathStr.len > MAX_PATH_BYTES) {
                        return globalThis.throwInvalidArguments("Path too long")
                    }
                    let paths = [pathStr.slice()]
                    return Path.joinAbsStringBuf(Fs.FileSystem.instance.top_level_dir, buf, paths, .auto)
                }
            }
            return globalThis.throwInvalidArguments("Expected a path")
        }

        buf[path.len] = 0

        var flags = MMapFlags{ TYPE = .SHARED }
        var offset: Int64 = 0
        var mapSize: Int64 = null

        if (let opts = args.nextEat()) {
            if (opts.isObject()) {
                flags.TYPE = if ((try opts.getBooleanLoose(globalThis, "shared")) ?? true) .SHARED else .PRIVATE

                if (try opts.get(globalThis, "size")) {
                    let sizeValue = try value.coerceToInt64(globalThis)
                    if (sizeValue < 0) {
                        return globalThis.throwInvalidArguments("size must be a non-negative integer")
                    }
                    mapSize = UInt64(sizeValue)
                }

                if (let value = try opts.get(globalThis, "offset")) {
                    let offsetValue = try value.coerceToInt64(globalThis)
                    if (offsetValue < 0) {
                        return globalThis.throwInvalidArguments("offset must be a non-negative integer")
                    }
                    offset = UInt64(offsetValue)
                    offset = Math.alignBackwardAnyAlign(offset, PageSize)
                }
            } else if (!opts.isUndefinedOrNull()) {
                return globalThis.throwInvalidArguments("Expected options to be an object")
            }
        }

        let map = switch (Sys.mmapFile(buf, flags, mapSize, offset)) {
            case .result(let map) => map
            case .err(let err) => {
                return globalThis.throwValue(try err.toJS(globalThis))
            }
        }

        return ArrayBuffer.makeTypedArrayWithBytesNoCopy(globalThis, .TypeUint8, map.ptr, map.len, munmapCallback, Int64(map.len))
    }
}

// ============================================================================
// 环境变量操作
// ============================================================================

/// Bun__reportError - 报告未捕获的异常
public func reportError(globalObject: JsGlobalObject, err: JsValue) {
    _ = VirtualMachine.get().uncaughtException(globalObject, err, false)
}

/// EnvironmentVariables - 进程环境变量操作
public class EnvironmentVariables {

    /// 获取环境变量数量
    public static func getEnvCount(globalObject: JsGlobalObject, ptr: UnsafeRawPointer): Int64 {
        let bunVM = globalObject.bunVM()
        ptr = bunVM.transpiler.env.map.map.keys().ptr
        return bunVM.transpiler.env.map.map.unmanaged.entries.len
    }

    /// 获取环境变量键
    public static func getEnvKey(ptr: UnsafeRawPointer, i: Int64, dataPtr: UnsafeRawPointer): Int64 {
        let item = ptr[i]
        dataPtr = item.ptr
        return item.len
    }

    /// 获取环境变量值
    public static func getEnvValue(globalObject: JsGlobalObject, name: ZigString, value: ZigString): Bool {
        if (let val = getEnvValueImpl(globalObject, name)) {
            value = val
            return true
        }
        return false
    }

    /// 获取环境变量值 (BunString 版本)
    public static func getEnvValueBunString(globalObject: JsGlobalObject, name: BunString, value: BunString): Bool {
        let vm = globalObject.bunVM()
        var nameSlice = name.toUTF8(default_allocator)
        defer nameSlice.deinit()
        let val = vm.transpiler.env.get(nameSlice.slice()) ?? return false
        value = BunString.borrowUTF8(val)
        return true
    }

    /// 设置环境变量值
    public static func setEnvValue(globalObject: JsGlobalObject, name: BunString, value: BunString) {
        let vm = globalObject.bunVM()
        var nameSlice = name.toUTF8(default_allocator)
        defer nameSlice.deinit()

        let storage = vm.proxy_env_storage
        storage.lock.lock()
        defer storage.lock.unlock()

        let slot = storage.slot(nameSlice.slice()) ?? return

        if (let old = slot.ptr) {
            old.deref()
            slot.ptr = null
        }

        if (value.isEmpty()) {
            handleOom(vm.transpiler.env.map.put(slot.key, ""))
            return
        }

        var valueSlice = value.toUTF8(default_allocator)
        defer valueSlice.deinit()
        let newVal = RareData.RefCountedEnvValue.create(valueSlice.slice())
        slot.ptr = newVal
        handleOom(vm.transpiler.env.map.put(slot.key, newVal.bytes))
    }

    /// 获取环境变量名称列表
    public static func getEnvNames(globalObject: JsGlobalObject, names: Array<ZigString>): Int64 {
        var vm = globalObject.bunVM()
        let keys = vm.transpiler.env.map.map.keys()
        let len = Math.min(names.len, keys.len)
        for ((key, name) in keys[0..len].zip(names[0..len])) {
            name = ZigString.initUTF8(key)
        }
        return len
    }

    /// 获取环境变量值实现
    static func getEnvValueImpl(globalObject: JsGlobalObject, name: ZigString): ZigString {
        var vm = globalObject.bunVM()
        var sliced = name.toSlice(vm.allocator)
        defer sliced.deinit()
        let value = vm.transpiler.env.get(sliced.slice()) ?? return null
        return ZigString.initUTF8(value)
    }
}

// ============================================================================
// 常量
// ========================================================================

/// 每毫秒的纳秒数
public let NS_PER_MS: UInt64 = 1_000_000

// ============================================================================
// 类型别名
// ============================================================================

public typealias BunString = BunString
public let default_allocator = default_allocator
