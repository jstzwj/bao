// 严格翻译自: src/runtime/api/BunObject.rs
// `globalThis.Bun` — 顶层宿主函数和惰性属性 getter。
package bao_runtime.api

import bao_jsc.*
import bao_collections.ArrayList
import bao_core.*
import bao_collections.*
import bao_sys.*
import bao_io.*
import bao_event_loop.*
import bao_path.*
import bao_zlib.*
import bao_zstd.*
import bao_shell_parser.braces

// ============================================================================
// 公共路径工具
// ============================================================================

/// 构建公共路径字符串，将 `to` 相对于 `dir` 解析，并加上 `origin` 前缀
/// （当 `origin` 为绝对路径时，还会加上 `asset_prefix`）。
/// 被 bundler dev-server 和 `Bun.FileSystemRouter` 的 `scriptSrc` getter 调用。
public func getPublicPathWithAssetPrefix(
    to: Array<UInt8>,
    dir: Array<UInt8>,
    origin: URL,
    assetPrefix: Array<UInt8>,
    writer: IoWriter,
    platform: Platform,
): Unit {
    var relativePath: Array<UInt8> = if (Strings.hasPrefix(to, dir)) {
        Strings.withoutTrailingSlash(to[dir.len..])
    } else {
        // 根据 platform 分发到不同的路径解析实现
        match (platform) {
            case Posix => ResolvePath.relativePlatformPosix(dir, to, false)
            case Windows => ResolvePath.relativePlatformWindows(dir, to, false)
            case Loose => ResolvePath.relativePlatformLoose(dir, to, false)
            case Nt => ResolvePath.relativePlatformNt(dir, to, false)
        }
    }

    if (origin.isAbsolute()) {
        if (Strings.hasPrefix(relativePath, "..") || Strings.hasPrefix(relativePath, "./")) {
            writer.write(origin.origin) catch { return }
            writer.write("/abs:") catch { return }
            if (Path.isAbsolute(to)) {
                writer.write(to) catch { return }
            } else {
                let fs = VirtualMachine.get().fs()
                writer.write(fs.abs([to])) catch { return }
            }
        } else {
            var buf = ArrayList<UInt8>()
            origin.joinWrite(buf, assetPrefix, "", relativePath, "")
            writer.write(buf.items) catch { return }
        }
    } else {
        writer.write(Strings.trimLeft(relativePath, "/")) catch { return }
    }
}

/// `Bun.getPublicPath` — 使用 VM 的顶级目录、无 asset prefix 和 loose 平台的封装。
public func getPublicPath(to: Array<UInt8>, origin: URL, writer: IoWriter): Unit {
    getPublicPathWithAssetPrefix(
        to,
        VirtualMachine.get().topLevelDir(),
        origin,
        [],
        writer,
        Platform.Loose,
    )
}

// ============================================================================
// 静态适配器 (Static Adapters)
// ============================================================================

/// 静态方法适配器 — 手动解码 CallFrame 参数的薄封装层。
public class StaticAdapters {

    /// Bun.connect 适配器
    public static func listenerConnect(global: JsGlobalObject, callFrame: JsCallFrame): JsValue {
        let args = callFrame.argumentsOld(1)
        let opts = if (args.len >= 1) { args.ptr[0] } else { JsValue.UNDEFINED }
        return Listener.connect(global, opts)
    }

    /// Bun.listen 适配器
    public static func listenerListen(global: JsGlobalObject, callFrame: JsCallFrame): JsValue {
        let args = callFrame.argumentsOld(1)
        let opts = if (args.len >= 1) { args.ptr[0] } else { JsValue.UNDEFINED }
        return Listener.listen(global, opts)
    }

    /// Bun.udpSocket 适配器
    public static func udpSocket(global: JsGlobalObject, callFrame: JsCallFrame): JsValue {
        let args = callFrame.argumentsOld(1)
        let opts = if (args.len >= 1) { args.ptr[0] } else { JsValue.UNDEFINED }
        return UDPSocket.udpSocket(global, opts)
    }

    /// Bun.spawn 适配器
    public static func subprocessSpawn(global: JsGlobalObject, callFrame: JsCallFrame): JsValue {
        let args = callFrame.argumentsOld(2)
        let a0 = if (args.len >= 1) { args.ptr[0] } else { JsValue.UNDEFINED }
        let a1 = if (args.len >= 2) { Some(args.ptr[1]) } else { None }
        return Spawn.spawn(global, a0, a1)
    }

    /// Bun.spawnSync 适配器
    public static func subprocessSpawnSync(global: JsGlobalObject, callFrame: JsCallFrame): JsValue {
        let args = callFrame.argumentsOld(2)
        let a0 = if (args.len >= 1) { args.ptr[0] } else { JsValue.UNDEFINED }
        let a1 = if (args.len >= 2) { Some(args.ptr[1]) } else { None }
        return Spawn.spawnSync(global, a0, a1)
    }

    /// Bun.build 适配器
    public static func jsBundlerBuild(global: JsGlobalObject, callFrame: JsCallFrame): JsValue {
        return JSBundler.buildFn(global, callFrame)
    }

    /// Bun.\$ 解析脚本构造器适配器
    public static func parsedShellScriptCreate(global: JsGlobalObject, callFrame: JsCallFrame): JsValue {
        return ParsedShellScript.create(global, callFrame)
    }

    /// Bun.shell 解释器构造器适配器
    public static func shellInterpreterCreate(global: JsGlobalObject, callFrame: JsCallFrame): JsValue {
        return ShellInterpreter.create(global, callFrame)
    }

    /// Bun.sha(input, output?) — SHA512_256 哈希封装。
    public static func sha(global: JsGlobalObject, callFrame: JsCallFrame): JsValue {
        let args = callFrame.argumentsOld(2)
        let a0 = if (args.len >= 1) { args.ptr[0] } else { JsValue.UNDEFINED }
        let a1 = if (args.len >= 2) { args.ptr[1] } else { JsValue.UNDEFINED }
        // auto_protect = true
        a0.protect()
        a1.protect()
        defer {
            a0.unprotect()
            a1.unprotect()
        }

        let input = BlobOrStringOrBuffer.fromJS(global, a0) ?? {
            return global.throwInvalidArguments("expected string, buffer, TypedArray, or Blob")
        }
        let output = if (a1.isUndefinedOrNull()) { None } else { StringOrBuffer.fromJS(global, a1) }
        return Crypto.SHA512_256.hash(global, input, output)
    }
}

// ============================================================================
// BunObject - Bun 全局对象的属性和方法注册表
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
            return globalThis.`throw`("shell escape expected at least 1 argument")
        }

        let jsval = arguments.ptr[0]
        let bunstr = try jsval.toBunString(globalThis)
        if (globalThis.hasException()) { return JsValue.jsUndefined() }
        defer bunstr.deref()

        var outbuf = ArrayList<UInt8>()
        if (Shell.needsEscapeBunstr(bunstr)) {
            let result = try Shell.escapeBunStr(bunstr, outbuf, true)
            if (!result) {
                return globalThis.`throw`("String has invalid utf-16: ${bunstr.byteSlice()}")
            }
            var str = BunString.cloneUTF8(outbuf.items)
            return str.transferToJS(globalThis)
        }

        return jsval
    }

    /// braces - 大括号展开
    public static func braces(global: JsGlobalObject, braceStr: BunString, opts: BracesOptions): JsValue {
        let braceSlice = braceStr.toUTF8()

        var arena = Arena.new()

        var lexerOutput = if (Strings.isAllASCII(braceSlice.slice())) {
            match (Braces.Lexer.tokenize(braceSlice.slice())) {
                case Ok(v) => v
                case Err(err) => return global.throwError(err.into(), "failed to tokenize braces")
            }
        } else {
            match (Braces.NewLexerWtf8.tokenize(braceSlice.slice())) {
                case Ok(v) => v
                case Err(err) => return global.throwError(err.into(), "failed to tokenize braces")
            }
        }

        let expansionCount = Braces.calculateExpandedAmount(lexerOutput.tokens)

        if (opts.tokenize) {
            let str = Braces.tokensToJSON(lexerOutput.tokens)
            let bunStr = BunString.fromBytes(str)
            return bunStr.toJS(global)
        }
        if (opts.parse) {
            var parser = Braces.Parser(lexerOutput.tokens, arena)
            let astNode = match (parser.parse()) {
                case Ok(v) => v
                case Err(err) => return global.throwError(err.into(), "failed to parse braces")
            }
            let str = Braces.astToJSON(astNode)
            let bunStr = BunString.fromBytes(str)
            return bunStr.toJS(global)
        }

        if (expansionCount == 0) {
            return BunString.toJSArray(global, [braceStr])
        }

        var expandedStrings = ArrayList<ArrayList<UInt8>>(expansionCount)
        for (_ in 0..<expansionCount) {
            expandedStrings.append(ArrayList<UInt8>())
        }

        match (Braces.expand(arena, lexerOutput.tokens, expandedStrings, lexerOutput.containsNested)) {
            case Ok(()) => ()
            case Err(Braces.ParserError.OutOfMemory) => return JsError.outOfMemory
            case Err(Braces.ParserError.UnexpectedToken) =>
                return global.throwPretty("Unexpected token while expanding braces")
        }

        var outStrings = ArrayList<BunString>(expansionCount)
        for (i in 0..<expansionCount) {
            outStrings.append(BunString.fromBytes(expandedStrings[i].items))
        }

        return BunString.toJSArray(global, outStrings.items)
    }

    /// which - 查找可执行文件路径
    public static func which(globalThis: JsGlobalObject, callframe: JsCallFrame): JsValue {
        let arguments = callframe.argumentsOld(2)
        let pathBuf = PathBufferPool.get()
        defer PathBufferPool.put(pathBuf)
        var arguments = JsCallFrame.ArgumentsSlice(globalThis.bunVM(), arguments.slice())
        defer arguments.deinit()

        let pathArg = arguments.nextEat() ?? {
            return globalThis.`throw`("which: expected 1 argument, got 0")
        }

        if (pathArg.isEmptyOrUndefinedOrNull()) {
            return JsValue.jsNull()
        }

        var binStr = try pathArg.toSlice(globalThis, globalThis.bunVM().allocator)
        if (globalThis.hasException()) { return JsValue.jsUndefined() }

        if (binStr.len >= MAX_PATH_BYTES) {
            return globalThis.`throw`("bin path is too long")
        }

        if (binStr.len == 0) {
            return JsValue.jsNull()
        }

        var pathStr = ZigString.Slice.fromUTF8NeverFree(
            globalThis.bunVM().transpiler.env.get("PATH") ?? "",
        )
        var cwdStr = ZigString.Slice.fromUTF8NeverFree(
            globalThis.bunVM().transpiler.fs.top_level_dir,
        )

        if (let arg <- arguments.nextEat()) {
            if (!arg.isEmptyOrUndefinedOrNull() && arg.isObject()) {
                if (let str <- try arg.get(globalThis, "PATH")) {
                    pathStr = try str.toSlice(globalThis, globalThis.bunVM().allocator)
                }
                if (let str <- try arg.get(globalThis, "cwd")) {
                    cwdStr = try str.toSlice(globalThis, globalThis.bunVM().allocator)
                }
            }
        }

        if (let binPath <- Which.which(pathBuf, pathStr.slice(), cwdStr.slice(), binStr.slice())) {
            return ZigString(binPath).withEncoding().toJS(globalThis)
        }

        return JsValue.jsNull()
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

        var array = IoWriter.Allocating(default_allocator)
        defer array.deinit()
        let writer = array.writer

        let properties = if (arguments[1].jsType().isArray()) arguments[1] else JsValue.jsUndefined()
        var tablePrinter = try ConsoleObject.TablePrinter(globalThis, .Log, value, properties)
        tablePrinter.value_formatter.depth = formatOptions.max_depth
        tablePrinter.value_formatter.ordered_properties = formatOptions.ordered_properties
        tablePrinter.value_formatter.single_line = formatOptions.single_line

        let printResult = tablePrinter.printTable(writer, formatOptions.enable_colors)
        if (printResult.isErr()) {
            if (!globalThis.hasException()) {
                return globalThis.throwOutOfMemory()
            }
            return JsValue.jsUndefined()
        }

        return BunString.createUTF8ForJS(globalThis, array.written())
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

        var array = IoWriter.Allocating(default_allocator)
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

        var out = ZigString(array.written()).withEncoding()
        let ret = out.toJS(globalThis)
        return ret
    }

    /// bunInspect - C API 级别的 inspect
    public static func bunInspect(globalThis: JsGlobalObject, value: JsValue): BunString {
        var array = ArrayList<UInt8>()

        var formatter = ConsoleObject.Formatter.new(globalThis)
        formatter.format(array, value) catch {
            return BunString.empty
        }
        return BunString.cloneUTF8(array.items)
    }

    /// bunInspectSingleline - C API 级别的单行 inspect
    public static func bunInspectSingleline(globalThis: JsGlobalObject, value: JsValue): BunString {
        var array = ArrayList<UInt8>()
        let result = ConsoleObject.format2(
            .Debug,
            globalThis,
            [value].ptr,
            1,
            array.writer(),
            ConsoleObject.FormatOptions{
                enable_colors = false,
                add_newline = false,
                flush = false,
                max_depth = UInt16.MAX,
                quote_strings = true,
                ordered_properties = false,
                single_line = true,
            },
        )
        if (result.isErr() || globalThis.hasException()) {
            return BunString.empty
        }
        return BunString.cloneUTF8(array.items)
    }

    /// sleepSync - 同步休眠
    public static func sleepSync(JsGlobalObject, callframe: JsCallFrame): JsValue {
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
            return globalObject.throwInvalidArguments("argument to sleepSync must not be negative, got ${milliseconds}")
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
    public static func shrink(JsGlobalObject, callframe: JsCallFrame): JsValue {
        globalObject.vm().shrinkFootprint()
        return JsValue.jsUndefined()
    }

    /// gc - 垃圾回收
    public static func gc(vm: VirtualMachine, sync: Bool): Int64 {
        return vm.garbageCollect(sync)
    }

    /// stringWidth - 获取字符串的显示宽度
    public static func stringWidth(JsGlobalObject, callFrame: JsCallFrame): JsValue {
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
            if (let i <- Strings.indexOfNewlineOrNonASCII(bytes, UInt32(currentOffset))) {
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

    /// resolveSync - 同步解析模块路径
    public static func resolveSync(JsGlobalObject, callframe: JsCallFrame): JsValue {
        return try doResolve(globalObject, callframe.arguments())
    }

    /// resolve - 异步解析模块路径 (返回 Promise)
    public static func resolve(JsGlobalObject, callframe: JsCallFrame): JsValue {
        let arguments = callframe.argumentsOld(3)
        let value = doResolve(globalObject, arguments.slice()) catch { e =>
            let err = globalObject.takeError(e)
            return JsPromise.dangerouslyCreateRejectedPromiseValueWithoutNotifyingVM(globalObject, err)
        }
        return JsPromise.resolvedPromiseValue(globalObject, value)
    }

    /// bunResolve - C API 级别的 resolve (用于 HOST_EXPORT)
    public static func bunResolve(
        global: JsGlobalObject,
        specifier: JsValue,
        source: JsValue,
        isEsm: Bool,
    ): JsValue {
        let specifierStr = try specifier.toBunString(global) ?? return JsValue.jsUndefined()
        defer specifierStr.deref()

        let sourceStr = try source.toBunString(global) ?? return JsValue.jsUndefined()
        defer sourceStr.deref()

        let value = match (doResolveWithArgs(global, specifierStr, sourceStr, isEsm, false, true)) {
            case Ok(v) => v
            case Err(_) =>
                let err = global.tryTakeException()
                return JsPromise.dangerouslyCreateRejectedPromiseValueWithoutNotifyingVM(global, err)
        }

        return JsPromise.resolvedPromiseValue(global, value)
    }

    /// bunResolveSync - C API 级别的同步 resolve
    public static func bunResolveSync(
        global: JsGlobalObject,
        specifier: JsValue,
        source: JsValue,
        isEsm: Bool,
        isUserRequireResolve: Bool,
    ): JsValue {
        let specifierStr = try specifier.toBunString(global) ?? return JsValue.jsUndefined()
        defer specifierStr.deref()

        if (specifierStr.size() == 0) {
            global.err(JsErrorCode.InvalidArgValue, "The argument 'id' must be a non-empty string. Received ''").`throw`()
            return JsValue.jsUndefined()
        }

        let sourceStr = try source.toBunString(global) ?? return JsValue.jsUndefined()
        defer sourceStr.deref()

        return doResolveWithArgs(global, specifierStr, sourceStr, isEsm, isUserRequireResolve, true)
    }

    /// bunResolveSyncWithPaths - C API 级别的带路径同步 resolve
    public static func bunResolveSyncWithPaths(
        global: JsGlobalObject,
        specifier: JsValue,
        source: JsValue,
        isEsm: Bool,
        isUserRequireResolve: Bool,
        paths: Array<BunString>,
    ): JsValue {
        let specifierStr = try specifier.toBunString(global) ?? return JsValue.jsUndefined()
        defer specifierStr.deref()

        if (specifierStr.size() == 0) {
            global.err(JsErrorCode.InvalidArgValue, "The argument 'id' must be a non-empty string. Received ''").`throw`()
            return JsValue.jsUndefined()
        }

        let sourceStr = try source.toBunString(global) ?? return JsValue.jsUndefined()
        defer sourceStr.deref()

        let bunVM = global.bunVM()
        bunVM.transpiler.resolver.custom_dir_paths = paths
        defer {
            bunVM.transpiler.resolver.custom_dir_paths = None
        }

        return doResolveWithArgs(global, specifierStr, sourceStr, isEsm, isUserRequireResolve, true)
    }

    /// bunResolveSyncWithStrings - C API 级别的直接使用 BunString 的同步 resolve
    public static func bunResolveSyncWithStrings(
        global: JsGlobalObject,
        specifier: BunString,
        source: BunString,
        isEsm: Bool,
    ): JsValue {
        return doResolveWithArgs(global, specifier, source, isEsm, false, true)
    }

    /// bunResolveSyncWithSource - C API 级别的带 BunString source 的同步 resolve
    public static func bunResolveSyncWithSource(
        global: JsGlobalObject,
        specifier: JsValue,
        source: BunString,
        isEsm: Bool,
        isUserRequireResolve: Bool,
    ): JsValue {
        let specifierStr = try specifier.toBunString(global) ?? return JsValue.jsUndefined()
        defer specifierStr.deref()

        if (specifierStr.size() == 0) {
            global.err(JsErrorCode.InvalidArgValue, "The argument 'id' must be a non-empty string. Received ''").`throw`()
            return JsValue.jsUndefined()
        }

        return doResolveWithArgs(global, specifierStr, source, isEsm, isUserRequireResolve, true)
    }

    /// registerMacro - 注册宏
    public static func registerMacro(JsGlobalObject, callframe: JsCallFrame): JsValue {
        let arguments = callframe.argumentsOld(2).slice()
        if (arguments.len != 2 || !arguments[0].isNumber()) {
            return globalObject.throwInvalidArguments("Internal error registering macros: invalid args")
        }
        let id = arguments[0].toInt32()
        if (id == -1 || id == 0) {
            return globalObject.throwInvalidArguments("Internal error registering macros: invalid id")
        }

        if (!arguments[1].isCell() || !arguments[1].isCallable()) {
            return globalObject.`throw`("Macro must be a function")
        }

        let getOrPutResult = VirtualMachine.get().macros.getOrPut(id)
        if (getOrPutResult.foundExisting) {
            getOrPutResult.valuePtr.unprotect()
        }

        arguments[1].protect()
        getOrPutResult.valuePtr = arguments[1].asObjectRef()

        return JsValue.jsUndefined()
    }

    /// openInEditor - 在编辑器中打开文件
    public static func openInEditor(globalThis: JsGlobalObject, callframe: JsCallFrame): JsValue {
        var edit = EDITOR_CONTEXT.ctx
        let args = callframe.argumentsOld(4)
        var arguments = JsCallFrame.ArgumentsSlice(globalThis.bunVM(), args.slice())
        defer arguments.deinit()
        var path: String = ""
        var editorChoice: ?Editor = None
        var line: ?String = None
        var column: ?String = None

        if (let filePath <- arguments.nextEat()) {
            path = (try filePath.toSlice(globalThis, arguments.arena.allocator())).slice()
        }

        if (let opts <- arguments.nextEat()) {
            if (!opts.isUndefinedOrNull()) {
                if (let editorVal <- try opts.getTruthy(globalThis, "editor")) {
                    var sliced = try editorVal.toSlice(globalThis, arguments.arena.allocator())
                    let prevName = edit.name

                    if (!Strings.eqlLong(prevName, sliced.slice(), true)) {
                        let prev = edit
                        EDITOR_CONTEXT.nameStorage = sliced.slice().toArrayList()
                        edit.name = EDITOR_CONTEXT.nameStorage.items
                        edit.detectEditor(globalThis.bunVM().transpiler.env)
                        editorChoice = edit.editor
                        if (editorChoice.isNone()) {
                            edit = prev
                            return globalThis.`throw`("Could not find editor \"${sliced.slice()}\"")
                        }
                    }
                }

                if (let line_ <- try opts.getTruthy(globalThis, "line")) {
                    line = (try line_.toSlice(globalThis, arguments.arena.allocator())).slice()
                }

                if (let column_ <- try opts.getTruthy(globalThis, "column")) {
                    column = (try column_.toSlice(globalThis, arguments.arena.allocator())).slice()
                }
            }
        }

        let editor = editorChoice ?? edit.editor ?? {
            edit.autoDetectEditor(globalThis.bunVM().transpiler.env)
            if (edit.editor.isNone()) {
                return globalThis.`throw`("Failed to auto-detect editor")
            }
            return edit.editor
        }

        if (path.len == 0) {
            return globalThis.`throw`("No file path specified")
        }

        editor.open(edit.path, path, line, column, arguments.arena.allocator()) catch { err =>
            return globalThis.`throw`("Opening editor failed ${err}")
        }

        return JsValue.jsUndefined()
    }

    /// serve - 启动 HTTP/HTTPS 服务器
    public static func serve(JsGlobalObject, callframe: JsCallFrame): JsValue {
        let arguments = callframe.argumentsOld(2).slice()
        var config = {
            var args = JsCallFrame.ArgumentsSlice(globalObject.bunVM(), arguments)
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
                return JsValue.jsUndefined()
            }

            return config
        }

        let vm = globalObject.bunVM()

        if (config.allow_hot) {
            if (let hot <- vm.hotMap()) {
                if (config.id.len == 0) {
                    config.id = config.computeID(globalObject.allocator())
                }

                if (let entry <- hot.getEntry(config.id)) {
                    match (entry.tag()) {
                        case "HTTPServer" =>
                            let server = entry.as(HTTPServer)
                            server.onReloadFromZig(config, globalObject)
                            return server.js_value.tryGet() ?? JsValue.jsUndefined()
                        case "DebugHTTPServer" =>
                            let server = entry.as(DebugHTTPServer)
                            server.onReloadFromZig(config, globalObject)
                            return server.js_value.tryGet() ?? JsValue.jsUndefined()
                        case "DebugHTTPSServer" =>
                            let server = entry.as(DebugHTTPSServer)
                            server.onReloadFromZig(config, globalObject)
                            return server.js_value.tryGet() ?? JsValue.jsUndefined()
                        case "HTTPSServer" =>
                            let server = entry.as(HTTPSServer)
                            server.onReloadFromZig(config, globalObject)
                            return server.js_value.tryGet() ?? JsValue.jsUndefined()
                        else => ()
                    }
                }
            }
        }

        let hasSSLConfig = config.ssl_config.isSome()
        let development = config.isDevelopment()

        // 根据 SSL 和开发模式选择服务器类型
        let server = try ServerType(config, globalObject)
        if (globalObject.hasException()) { return JsValue.jsUndefined() }
        let routeListObject = server.listen()
        if (globalObject.hasException()) { return JsValue.jsUndefined() }
        let obj = server.toJS(globalObject)
        if (routeListObject != JsValue.jsUndefined()) {
            server.js.routeListSetCached(obj, globalObject, routeListObject)
        }
        server.js_value.setStrong(obj, globalObject)

        if (config.allow_hot) {
            if (let hot <- globalObject.bunVM().hotMap()) {
                hot.insert(config.id, server)
            }
        }

        if (let debugger <- vm.debugger) {
            debugger.http_server_agent.notifyServerStarted(AnyServer.from(server))
            debugger.http_server_agent.notifyServerRoutesUpdated(AnyServer.from(server)) catch { err =>
                handleOom(err)
            }
        }

        return obj
    }

    /// mmapFile - 内存映射文件
    public static func mmapFile(globalThis: JsGlobalObject, callframe: JsCallFrame): JsValue {
        if (Environment.isWindows) {
            return globalThis.throwUnsupported("mmapFile is not supported on Windows")
        }

        let arguments = callframe.argumentsOld(2)
        var args = JsCallFrame.ArgumentsSlice(globalThis.bunVM(), arguments.slice())
        defer args.deinit()

        var buf = PathBuffer()
        let path = {
            if (let path <- args.nextEat()) {
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
        var mapSize: ?Int64 = None

        if (let opts <- args.nextEat()) {
            if (opts.isObject()) {
                flags.TYPE = if ((try opts.getBooleanLoose(globalThis, "shared")) ?? true) .SHARED else .PRIVATE

                if (try opts.get(globalThis, "size")) {
                    let sizeValue = try value.coerceToInt64(globalThis)
                    if (sizeValue < 0) {
                        return globalThis.throwInvalidArguments("size must be a non-negative integer")
                    }
                    mapSize = UInt64(sizeValue)
                }

                if (let value <- try opts.get(globalThis, "offset")) {
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

        let map = match (Sys.mmapFile(buf, flags, mapSize, offset)) {
            case result(map) => map
            case err(err) =>
                return globalThis.throwValue(try err.toJS(globalThis))
        }

        return ArrayBuffer.makeTypedArrayWithBytesNoCopy(globalThis, .TypeUint8, map.ptr, map.len, munmapCallback, Int64(map.len))
    }

    /// escapeHTML16 - 转义 HTML (UTF-16 输入)
    public static func escapeHTML16(
        JsGlobalObject,
        inputValue: JsValue,
        ptr: UnsafePointer<UInt16>,
        len: UInt64,
    ): JsValue {
        let inputSlice = ptr.toArray(len)
        let escaped = match (EscapeHTML.escapeForUTF16Input(inputSlice)) {
            case Ok(v) => v
            case Err(_) =>
                globalObject.throwValue(ZigString("Out of memory").toErrorInstance(globalObject))
                return JsValue.jsUndefined()
        }

        return match (escaped) {
            case Static(val) => ZigString(val).toJS(globalObject)
            case Original => inputValue
            case Allocated(escapedHTML) =>
                ZigString.toExternalU16(escapedHTML.ptr, escapedHTML.len, globalObject)
        }
    }

    /// escapeHTML8 - 转义 HTML (Latin-1 输入)
    public static func escapeHTML8(
        JsGlobalObject,
        inputValue: JsValue,
        ptr: UnsafePointer<UInt8>,
        len: UInt64,
    ): JsValue {
        let inputSlice = ptr.toArray(len)

        let escaped = match (EscapeHTML.escapeForLatin1Input(inputSlice)) {
            case Ok(v) => v
            case Err(_) =>
                globalObject.throwValue(ZigString("Out of memory").toErrorInstance(globalObject))
                return JsValue.jsUndefined()
        }

        return match (escaped) {
            case Static(val) => ZigString(val).toJS(globalObject)
            case Original => inputValue
            case Allocated(escapedHTML) =>
                if (inputSlice.len <= 32) {
                    let zigStr = ZigString(escapedHTML)
                    return zigStr.toAtomicValue(globalObject)
                }

                // 所有权转移给 JSC 外部字符串终结器
                return ZigString(escapedHTML).toExternalValue(globalObject)
        }
    }

    // ========================================================================
    // 惰性属性 Getter
    // ========================================================================

    /// getCWD - 获取当前工作目录
    public static func getCWD(globalThis: JsGlobalObject, object: JsObject): JsValue {
        return ZigString(VirtualMachine.get().transpiler.fs.top_level_dir).toJS(globalThis)
    }

    /// getOrigin - 获取服务器来源
    public static func getOrigin(globalThis: JsGlobalObject, object: JsObject): JsValue {
        return ZigString(VirtualMachine.get().origin.origin).toJS(globalThis)
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
    public static func getInspect(JsGlobalObject, object: JsObject): JsValue {
        let fun = JsFunction.create(globalObject, "inspect", inspect, 2)
        var str = ZigString("nodejs.util.inspect.custom")
        fun.put(globalObject, ZigString.`static`("custom"), JsValue.symbolFor(globalObject, str))
        fun.put(globalObject, ZigString.`static`("table"), JsFunction.create(globalObject, "table", inspectTable, 3))
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
    public static func getCSRFObject(JsGlobalObject, object: JsObject): JsValue {
        return CSRFObject.create(globalObject)
    }

    /// getCronObject
    public static func getCronObject(globalThis: JsGlobalObject, object: JsObject): JsValue {
        return Cron.getCronObject(globalThis, object)
    }

    /// getS3ClientConstructor
    public static func getS3ClientConstructor(globalThis: JsGlobalObject, object: JsObject): JsValue {
        return S3Client.js.getConstructor(globalThis)
    }

    /// getS3DefaultClient
    public static func getS3DefaultClient(globalThis: JsGlobalObject, object: JsObject): JsValue {
        let vm = globalThis.bunVM()
        let envPtr = vm.transpiler.env
        let rare = vm.rareData()
        if (let v <- rare.s3DefaultClient.get()) {
            return v
        }
        let envCreds = S3Credentials.s3CredentialsFromEnv(envPtr.getS3Credentials())
        let awsOptions = match (S3Credentials.getCredentialsWithOptions(
            envCreds,
            S3Options.default(),
            None, None, None,
            false,
            globalThis,
        )) {
            case Ok(v) => v
            case Err(JsError.OutOfMemory) => handleOom()
            case Err(err) =>
                globalThis.reportActiveExceptionAsUnhandled(err)
                return JsValue.jsUndefined()
        }
        let client = S3Client{
            credentials = awsOptions.credentials.dupe(),
            options = awsOptions.options,
            acl = awsOptions.acl,
            storageClass = awsOptions.storageClass,
            requestPayer = awsOptions.requestPayer,
        }
        let jsClient = S3Client.toJS(client, globalThis)
        jsClient.ensureStillAlive()
        rare.s3DefaultClient = StrongOptional.create(jsClient, globalThis)
        return jsClient
    }

    /// getTLSDefaultCiphers - 获取默认 TLS 密码套件
    public static func getTLSDefaultCiphers(globalThis: JsGlobalObject, object: JsObject): JsValue {
        let vm = globalThis.bunVM()
        let bytes: Array<UInt8> = if (let Some(c) <- vm.rareData().tlsDefaultCiphers()) {
            c
        } else {
            UWS.getDefaultCiphers().toBytes()
        }
        return BunString.createUTF8ForJS(globalThis, bytes) ?? JsValue.jsUndefined()
    }

    /// setTLSDefaultCiphers - 设置默认 TLS 密码套件
    public static func setTLSDefaultCiphers(globalThis: JsGlobalObject, object: JsObject, ciphers: JsValue): JsValue {
        let vm = globalThis.bunVM()
        let sliced = try ciphers.toSlice(globalThis) ?? return JsValue.jsUndefined()
        vm.rareData().setTLSDefaultCiphers(sliced.slice())
        return JsValue.jsUndefined()
    }

    /// getValkeyClientConstructor
    public static func getValkeyClientConstructor(globalThis: JsGlobalObject, object: JsObject): JsValue {
        return Valkey.js.getConstructor(globalThis)
    }

    /// getValkeyDefaultClient
    public static func getValkeyDefaultClient(globalThis: JsGlobalObject, object: JsObject): JsValue {
        var valkey = try Valkey.createNoJsNoPubsub(globalThis, [JsValue.jsUndefined()]) ?? return JsValue.jsUndefined()
        let asJs = valkey.toJS(globalThis)
        valkey.this_value = JsRef.initWeak(asJs)
        valkey._subscription_ctx = SubscriptionCtx(valkey) catch { err =>
            if (err != Error.JSError) {
                _ = globalThis.throwError(err, "Failed to create Redis client") catch {}
                return JsValue.jsUndefined()
            }
            return JsValue.jsUndefined()
        }
        return asJs
    }

    /// getTerminalConstructor
    public static func getTerminalConstructor(globalThis: JsGlobalObject, object: JsObject): JsValue {
        return Terminal.js.getConstructor(globalThis)
    }

    /// getEmbeddedFiles - 获取嵌入的文件列表
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
            let inputBlob = standaloneFileBlob(file, globalThis)
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
        if (let overriddenMain <- vm.overridden_main.get()) { return overriddenMain }

        // 尝试使用已解析的文件路径
        if (!vm.main_resolved_path.isEmpty()) {
            return vm.main_resolved_path.toJS(globalThis) catch JsValue.jsUndefined()
        }

        // 如果是 eval 或 stdin，不尝试解析
        if (Strings.endsWith(vm.main, "[eval]") || Strings.endsWith(vm.main, "[stdin]")) {
            // 跳过文件路径解析
        } else {
            // 尝试通过打开文件描述符获取真实路径
            let fd = Sys.openat(
                if (Environment.isWindows) Fd.INVALID else Fd.cwd(),
                vm.main,
                if (Environment.isLinux || Environment.isAndroid) Sys.O.PATH else Sys.O.RDONLY,
                0,
            )
            if (fd.isOk()) {
                defer fd.value.close()
                var pathBuf = PathBuffer()
                let fdPath = Sys.getFdPath(fd.value, pathBuf)
                if (fdPath.isOk()) {
                    // 尝试创建原子字符串
                    if (let atom <- BunString.tryCreateAtom(fdPath.value)) {
                        vm.main_resolved_path = atom
                    } else {
                        vm.main_resolved_path = BunString.cloneUTF8(fdPath.value)
                    }
                    return vm.main_resolved_path.toJS(globalThis) catch JsValue.jsUndefined()
                }
            }
        }

        return ZigString(vm.main).toJS(globalThis)
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
        return StdioStores.stdin(globalThis)
    }

    /// 创建 Bun.stderr 的惰性属性值
    public static func createBunStderr(globalThis: JsGlobalObject): JsValue {
        return StdioStores.stderr(globalThis)
    }

    /// 创建 Bun.stdout 的惰性属性值
    public static func createBunStdout(globalThis: JsGlobalObject): JsValue {
        return StdioStores.stdout(globalThis)
    }

    // ========================================================================
    // 私有辅助函数
    // ========================================================================

    /// 内部路径解析实现
    static func doResolve(globalThis: JsGlobalObject, arguments: Array<JsValue>): JsValue {
        var args = JsCallFrame.ArgumentsSlice(globalThis.bunVM(), arguments)
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
        if (let next <- args.nextEat()) {
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
            try arraylist.writer().print("${errorable.result.value}${queryString}")
            return ZigString.initUTF8(arraylist.items).toJS(ctx)
        }

        return errorable.result.value.toJS(ctx)
    }

    /// standaloneFileBlob - 为独立模块图文件创建 Blob
    static func standaloneFileBlob(file: StandaloneModuleGraph.File, global: JsGlobalObject): Blob {
        if (let cached <- file.cached_blob) {
            return cached
        }
        let store = Store(file.contents.asBytes().toArrayList())
        var blobBody = Blob.initWithStore(store, global)
        let mime = MimeType.byLoader(file.loader, Path.extension(file.name))
        blobBody.content_type = mime.value
        blobBody.name = BunString.cloneUTF8(Path.basename(file.name))
        let blob = Blob.new(blobBody)
        file.cached_blob = blob
        return blob
    }
}

// ============================================================================
// CSRFObject - CSRF 令牌对象
// ============================================================================

/// CSRFObject 提供 generate 和 verify 方法
public class CSRFObject {
    /// 创建 CSRF 对象
    public static func create(globalThis: JsGlobalObject): JsValue {
        let object = JsValue.createEmptyObject(globalThis, 2)

        object.put(
            globalThis,
            "generate",
            JsFunction.create(globalThis, "generate", CSRFJsc.csrfGenerate, 1),
        )

        object.put(
            globalThis,
            "verify",
            JsFunction.create(globalThis, "verify", CSRFJsc.csrfVerify, 1),
        )

        return object
    }
}

// ============================================================================
// 环境变量操作
// ============================================================================

/// Bun__reportError - 报告未捕获的异常
public func reportError(JsGlobalObject, err: JsValue) {
    _ = VirtualMachine.get().uncaughtException(globalObject, err, false)
}

/// EnvironmentVariables - 进程环境变量操作
public class EnvironmentVariables {

    /// 获取环境变量数量
    public static func getEnvCount(JsGlobalObject, ptr: UnsafeRawPointer): Int64 {
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
    public static func getEnvValue(JsGlobalObject, name: ZigString, value: ZigString): Bool {
        if (let val <- getEnvValueImpl(globalObject, name)) {
            value = val
            return true
        }
        return false
    }

    /// 获取环境变量值 (BunString 版本)
    public static func getEnvValueBunString(JsGlobalObject, name: BunString, value: BunString): Bool {
        let vm = globalObject.bunVM()
        var nameSlice = name.toUTF8(default_allocator)
        defer nameSlice.deinit()
        let val = vm.transpiler.env.get(nameSlice.slice()) ?? return false
        value = BunString.borrowUTF8(val)
        return true
    }

    /// 设置环境变量值
    public static func setEnvValue(JsGlobalObject, name: BunString, value: BunString) {
        let vm = globalObject.bunVM()
        var nameSlice = name.toUTF8(default_allocator)
        defer nameSlice.deinit()

        let storage = vm.proxy_env_storage
        storage.lock.lock()
        defer storage.lock.unlock()

        let slot = storage.slot(nameSlice.slice()) ?? return

        if (let old <- slot.ptr) {
            old.deref()
            slot.ptr = None
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
    public static func getEnvNames(JsGlobalObject, names: Array<ZigString>): Int64 {
        var vm = globalObject.bunVM()
        let keys = vm.transpiler.env.map.map.keys()
        let len = Math.min(names.len, keys.len)
        for ((key, name) in keys[0..len].zip(names[0..len])) {
            name = ZigString.initUTF8(key)
        }
        return len
    }

    /// 获取环境变量值实现
    static func getEnvValueImpl(JsGlobalObject, name: ZigString): ZigString {
        var vm = globalObject.bunVM()
        var sliced = name.toSlice(vm.allocator)
        defer sliced.deinit()
        let value = vm.transpiler.env.get(sliced.slice()) ?? return None
        return ZigString.initUTF8(value)
    }
}

// ============================================================================
// 压缩参数解析
// ============================================================================

/// 解析压缩函数的参数前缀 (gzip/gunzip/deflate/inflate/zstd compress/decompress)
/// 返回 (bufferValue, optionsValue)
public func parseCompressArgs(
    global: JsGlobalObject,
    callFrame: JsCallFrame,
): (JsValue, ?JsValue) {
    let arguments = callFrame.arguments()
    let bufferValue: JsValue = if (arguments.len > 0) { arguments[0] } else { JsValue.UNDEFINED }
    let optionsVal: ?JsValue = if (arguments.len > 1 && arguments[1].isObject()) {
        Some(arguments[1])
    } else if (arguments.len > 1 && !arguments[1].isUndefined()) {
        return global.throwInvalidArguments("Expected options to be an object")
    } else {
        None
    }
    return (bufferValue, optionsVal)
}

/// parseCompressArgs + 同步的 StringOrBuffer 转换
public func parseCompressBufferAndOptions(
    global: JsGlobalObject,
    callFrame: JsCallFrame,
): (StringOrBuffer, ?JsValue) {
    let (bufferValue, optionsVal) = parseCompressArgs(global, callFrame)
    if (let buffer <- StringOrBuffer.fromJS(global, bufferValue)) {
        return (buffer, optionsVal)
    }
    return global.throwInvalidArguments("Expected buffer to be a string or buffer")
}

// ============================================================================
// JSZlib - Zlib 压缩/解压缩操作
// ============================================================================

/// JSZlib 模块提供 gzip/gunzip/deflate/inflate 的同步操作
public class JSZlib {

    /// 全局释放器
    public static let globalDeallocator = MiFreeCtx.miFreeCtx

    /// 压缩库类型
    public enum Library {
        | Zlib
        | Libdeflate
    }

    /// 库名称映射
    public static let LIBRARY_MAP: HashMap<Array<UInt8>, Library> = HashMap<Array<UInt8>, Library>.from([
        ("zlib".toBytes(), Library.Zlib),
        ("libdeflate".toBytes(), Library.Libdeflate)
    ])

    /// gzipSync - 同步 gzip 压缩
    public static func gzipSync(globalThis: JsGlobalObject, callframe: JsCallFrame): JsValue {
        let (buffer, optionsVal) = parseCompressBufferAndOptions(globalThis, callframe)
        return gzipOrDeflateSync(globalThis, buffer, optionsVal, true)
    }

    /// inflateSync - 同步 inflate 解压
    public static func inflateSync(globalThis: JsGlobalObject, callframe: JsCallFrame): JsValue {
        let (buffer, optionsVal) = parseCompressBufferAndOptions(globalThis, callframe)
        return gunzipOrInflateSync(globalThis, buffer, optionsVal, false)
    }

    /// deflateSync - 同步 deflate 压缩
    public static func deflateSync(globalThis: JsGlobalObject, callframe: JsCallFrame): JsValue {
        let (buffer, optionsVal) = parseCompressBufferAndOptions(globalThis, callframe)
        return gzipOrDeflateSync(globalThis, buffer, optionsVal, false)
    }

    /// gunzipSync - 同步 gunzip 解压
    public static func gunzipSync(globalThis: JsGlobalObject, callframe: JsCallFrame): JsValue {
        let (buffer, optionsVal) = parseCompressBufferAndOptions(globalThis, callframe)
        return gunzipOrInflateSync(globalThis, buffer, optionsVal, true)
    }

    /// gunzip 或 inflate 同步操作
    public static func gunzipOrInflateSync(
        globalThis: JsGlobalObject,
        buffer: StringOrBuffer,
        optionsVal: ?JsValue,
        isGzip: Bool,
    ): JsValue {
        var opts = Zlib.Options{
            gzip = isGzip,
            windowBits = if (isGzip) 31 else -15,
        }
        var library = Library.Zlib

        if (let optionsValue <- optionsVal) {
            if (let window <- try optionsValue.get(globalThis, "windowBits")) {
                opts.windowBits = try window.coerceInt32(globalThis)
                library = Library.Zlib
            }

            if (let level <- try optionsValue.get(globalThis, "level")) {
                opts.level = try level.coerceInt32(globalThis)
            }

            if (let memLevel <- try optionsValue.get(globalThis, "memLevel")) {
                opts.memLevel = try memLevel.coerceInt32(globalThis)
                library = Library.Zlib
            }

            if (let strategy <- try optionsValue.get(globalThis, "strategy")) {
                opts.strategy = try strategy.coerceInt32(globalThis)
                library = Library.Zlib
            }

            if (let libraryValue <- try optionsValue.getTruthy(globalThis, "library")) {
                if (!libraryValue.isString()) {
                    return globalThis.throwInvalidArguments("Expected library to be a string")
                }

                library = if (let Some(v) <- LIBRARY_MAP.fromJS(globalThis, libraryValue)) {
                    v
                } else {
                    return globalThis.throwInvalidArguments("Expected library to be one of 'zlib' or 'libdeflate'")
                }
            }
        }

        if (globalThis.hasException()) { return JsValue.jsUndefined() }

        let compressed = buffer.slice()

        var list: ArrayList<UInt8> = if (isGzip && compressed.len > 64) {
            // 从 gzip 尾部读取 ISIZE 字段来估算解压大小
            let estimatedSize: UInt32 = UInt32.fromNeBytes(compressed[compressed.len - 4..])
            if (estimatedSize > 0 && estimatedSize < 256 * 1024 * 1024) {
                ArrayList<UInt8>.initCapacity(Math.max(estimatedSize, 64))
            } else if (compressed.len > 512) {
                ArrayList<UInt8>.initCapacity(compressed.len)
            } else {
                ArrayList<UInt8>.initCapacity(32)
            }
        } else {
            if (compressed.len > 512) {
                ArrayList<UInt8>.initCapacity(compressed.len)
            } else {
                ArrayList<UInt8>.initCapacity(32)
            }
        }

        return match (library) {
            case Library.Zlib =>
                var reader = match (ZlibReaderArrayList.initWithOptions(
                    compressed,
                    list,
                    Zlib.Options{ windowBits = opts.windowBits, level = opts.level },
                )) {
                    case Ok(r) => r
                    case Err(err) =>
                        if (err == ZlibError.InvalidArgument) {
                            return globalThis.`throw`("Zlib error: Invalid argument")
                        }
                        return globalThis.throwError(err, "Zlib error")
                }

                if (reader.readAll(true).isErr()) {
                    let msg = reader.errorMessage() ?? "Zlib returned an error"
                    return globalThis.throwValue(ZigString(msg).toErrorInstance(globalThis))
                }

                list.shrinkToFit()
                let leaked = list.leak()
                let arrayBuffer = ArrayBuffer.fromBytes(leaked, JSType.Uint8Array)
                return arrayBuffer.toJSWithContext(globalThis, leaked.ptr, Some(globalDeallocator))
            case Library.Libdeflate =>
                let decompressorPtr = Libdeflate.Decompressor.alloc()
                if (decompressorPtr.isNull()) {
                    return globalThis.throwOutOfMemory()
                }
                defer Libdeflate.Decompressor.destroy(decompressorPtr)

                let encoding = if (isGzip) Libdeflate.Encoding.Gzip else Libdeflate.Encoding.Deflate
                let result = decompressorPtr.decompressToVecGrow(
                    compressed,
                    list,
                    encoding,
                    1024 * 1024 * 1024,
                )
                match (result.status) {
                    case Libdeflate.Status.Success => ()
                    case Libdeflate.Status.InsufficientSpace => return globalThis.throwOutOfMemory()
                    case _ => return globalThis.`throw`("libdeflate returned an error: ${result.status}")
                }

                let leaked = list.leak()
                let arrayBuffer = ArrayBuffer.fromBytes(leaked, JSType.Uint8Array)
                return arrayBuffer.toJSWithContext(globalThis, leaked.ptr, Some(globalDeallocator))
        }
    }

    /// gzip 或 deflate 同步操作
    public static func gzipOrDeflateSync(
        globalThis: JsGlobalObject,
        buffer: StringOrBuffer,
        optionsVal: ?JsValue,
        isGzip: Bool,
    ): JsValue {
        var level: ?Int32 = None
        var library = Library.Zlib
        var windowBits: Int32 = 0

        if (let optionsValue <- optionsVal) {
            if (let window <- try optionsValue.get(globalThis, "windowBits")) {
                windowBits = try window.coerceInt32(globalThis)
                library = Library.Zlib
            }

            if (let libraryValue <- try optionsValue.getTruthy(globalThis, "library")) {
                if (!libraryValue.isString()) {
                    return globalThis.throwInvalidArguments("Expected library to be a string")
                }

                library = if (let Some(v) <- LIBRARY_MAP.fromJS(globalThis, libraryValue)) {
                    v
                } else {
                    return globalThis.throwInvalidArguments("Expected library to be one of 'zlib' or 'libdeflate'")
                }
            }

            if (let levelValue <- try optionsValue.get(globalThis, "level")) {
                level = try levelValue.coerceInt32(globalThis)
                if (globalThis.hasException()) { return JsValue.jsUndefined() }
            }
        }

        if (globalThis.hasException()) { return JsValue.jsUndefined() }

        let compressed = buffer.slice()
        // windowBits 在 Zig 中也未使用

        return match (library) {
            case Library.Zlib =>
                var list = ArrayList<UInt8>.initCapacity(if (compressed.len > 512) compressed.len else 32)

                var reader = match (ZlibCompressorArrayList(
                    compressed,
                    list,
                    Zlib.Options{ windowBits = 15, gzip = isGzip, level = level ?? 6 },
                )) {
                    case Ok(r) => r
                    case Err(err) =>
                        if (err == ZlibError.InvalidArgument) {
                            return globalThis.`throw`("Zlib error: Invalid argument")
                        }
                        return globalThis.throwError(err, "Zlib error")
                }

                if (reader.readAll().isErr()) {
                    let msg = reader.errorMessage() ?? "Zlib returned an error"
                    return globalThis.throwValue(ZigString(msg).toErrorInstance(globalThis))
                }

                list.shrinkToFit()
                let leaked = list.leak()
                let arrayBuffer = ArrayBuffer.fromBytes(leaked, JSType.Uint8Array)
                return arrayBuffer.toJSWithContext(globalThis, leaked.ptr, Some(globalDeallocator))
            case Library.Libdeflate =>
                let compressorPtr = Libdeflate.Compressor.alloc(level ?? 6)
                if (compressorPtr.isNull()) {
                    return globalThis.throwOutOfMemory()
                }
                defer Libdeflate.Compressor.destroy(compressorPtr)

                let encoding = if (isGzip) Libdeflate.Encoding.Gzip else Libdeflate.Encoding.Deflate

                var list = ArrayList<UInt8>.initCapacity(
                    compressorPtr.maxBytesNeeded(compressed, encoding),
                )

                let result = compressorPtr.compressToVec(compressed, list, encoding)
                if (result.status != Libdeflate.Status.Success) {
                    return globalThis.`throw`("libdeflate error: ${result.status}")
                }

                let leaked = list.leak()
                let arrayBuffer = ArrayBuffer.fromBytes(leaked, JSType.Uint8Array)
                return arrayBuffer.toJSWithContext(globalThis, leaked.ptr, Some(globalDeallocator))
        }
    }
}

// ============================================================================
// JSZstd - Zstd 压缩/解压缩操作
// ============================================================================

/// JSZstd 模块提供 zstd 压缩和解压缩的同步和异步操作
public class JSZstd {

    /// 释放器
    public static let deallocator = MiFreeCtx.miFreeCtx

    /// 获取压缩级别
    static func getLevel(globalThis: JsGlobalObject, optionsVal: ?JsValue): Int32 {
        if (let optionObj <- optionsVal) {
            if (let levelVal <- try optionObj.get(globalThis, "level")) {
                let value = try levelVal.coerceInt32(globalThis)
                if (globalThis.hasException()) { return 3 }

                if (value < 1 || value > 22) {
                    globalThis.throwInvalidArguments("Compression level must be between 1 and 22")
                    return 3
                }

                return value
            }
        }
        return 3
    }

    /// 获取异步操作选项
    static func getOptionsAsync(
        globalThis: JsGlobalObject,
        callFrame: JsCallFrame,
    ): (StringOrBuffer, ?JsValue, Int32) {
        let (bufferValue, optionsVal) = parseCompressArgs(globalThis, callFrame)
        let level = getLevel(globalThis, optionsVal)

        let allowStringObject = true
        if (let buffer <- StringOrBuffer.fromJSMaybeAsync(globalThis, bufferValue, true, allowStringObject)) {
            return (buffer, optionsVal, level)
        }

        globalThis.throwInvalidArguments("Expected buffer to be a string or buffer")
        return (StringOrBuffer.default(), None, 3)
    }

    /// compressSync - 同步 zstd 压缩
    public static func compressSync(globalThis: JsGlobalObject, callFrame: JsCallFrame): JsValue {
        let (buffer, optionsVal) = parseCompressBufferAndOptions(globalThis, callFrame)
        let level = getLevel(globalThis, optionsVal)

        let input = buffer.slice()

        // 计算最大压缩大小
        let maxSize = Zstd.compressBound(input.len)
        var output = ArrayList<UInt8>(maxSize)

        // 执行压缩
        let compressedSize = match (Zstd.compress(output, input, Some(level))) {
            case Zstd.Result.Success(size) => size
            case Zstd.Result.Err(err) =>
                return globalThis.err(JsErrorCode.ZSTD, "${err}").`throw`()
        }

        // 调整到实际压缩大小
        if (compressedSize < output.len) {
            output.truncate(compressedSize)
            output.shrinkToFit()
        }

        return JsValue.createBuffer(globalThis, output.leak())
    }

    /// decompressSync - 同步 zstd 解压
    public static func decompressSync(globalThis: JsGlobalObject, callFrame: JsCallFrame): JsValue {
        let (buffer, _) = parseCompressBufferAndOptions(globalThis, callFrame)

        let input = buffer.slice()

        let output = match (Zstd.decompressAlloc(input)) {
            case Ok(v) => v
            case Err(err) =>
                return globalThis.err(JsErrorCode.ZSTD, "Decompression failed: ${err}").`throw`()
        }

        return JsValue.createBuffer(globalThis, output.leak())
    }

    // --- 异步版本 ---

    /// ZstdCtx - zstd 异步任务的上下文
    public class ZstdCtx : AnyTaskJobCtx {
        public var buffer: ThreadSafe<StringOrBuffer>
        public var isCompress: Bool
        public var level: Int32
        public var output: ArrayList<UInt8>
        public var errorMessage: ?String
        public var promise: JsPromiseStrong

        public func run(global: UnsafeRawPointer): Unit {
            let input = self.buffer.slice()

            if (self.isCompress) {
                // 压缩路径
                let maxSize = Zstd.compressBound(input.len)
                self.output = ArrayList<UInt8>(maxSize)

                self.output = match (Zstd.compress(self.output, input, Some(self.level))) {
                    case Zstd.Result.Success(size) =>
                        if (size < self.output.len) {
                            var out = self.output
                            out.truncate(size)
                            out.shrinkToFit()
                            out
                        } else {
                            self.output
                        }
                    case Zstd.Result.Err(err) =>
                        self.output = ArrayList<UInt8>()
                        self.errorMessage = err
                        return
                }
            } else {
                // 解压路径
                self.output = match (Zstd.decompressAlloc(input)) {
                    case Ok(v) => v
                    case Err(_) =>
                        self.errorMessage = "Decompression failed"
                        return
                }
            }
        }

        public func then(globalThis: JsGlobalObject): Unit {
            let promise = self.promise.swap()

            if (let errMsg <- self.errorMessage) {
                promise.rejectWithAsyncStack(
                    globalThis,
                    globalThis.err(JsErrorCode.ZSTD, "${errMsg}").toJS(),
                )
                return
            }

            let outputSlice = self.output
            self.output = ArrayList<UInt8>()
            let bufferValue = JsValue.createBuffer(globalThis, outputSlice.leak())
            promise.resolve(globalThis, bufferValue)
        }
    }

    /// 创建异步 zstd 任务
    static func createJob(
        globalThis: JsGlobalObject,
        buffer: StringOrBuffer,
        isCompress: Bool,
        level: Int32,
    ): JsValue {
        let promise = JsPromiseStrong(globalThis)
        let promiseValue = promise.value()
        let job = AnyTaskJob.create(
            globalThis,
            ZstdCtx{
                buffer = ThreadSafe.adopt(buffer),
                isCompress = isCompress,
                level = level,
                output = ArrayList<UInt8>(),
                errorMessage = None,
                promise = promise,
            },
        )
        AnyTaskJob.schedule(job)
        return promiseValue
    }

    /// compress - 异步 zstd 压缩
    public static func compress(globalThis: JsGlobalObject, callFrame: JsCallFrame): JsValue {
        let (buffer, _, level) = getOptionsAsync(globalThis, callFrame)
        return createJob(globalThis, buffer, true, level)
    }

    /// decompress - 异步 zstd 解压
    public static func decompress(globalThis: JsGlobalObject, callFrame: JsCallFrame): JsValue {
        let (buffer, _, _) = getOptionsAsync(globalThis, callFrame)
        return createJob(globalThis, buffer, false, 0) // 解压时忽略 level
    }
}

// ============================================================================
// 编辑器上下文 (线程本地存储)
// ============================================================================

/// 编辑器上下文槽位
public class EditorContextSlot {
    public var ctx: EditorContext
    public var nameStorage: ArrayList<UInt8>

    public init() {
        ctx = EditorContext{ editor = None, name = "", path = "" }
        nameStorage = ArrayList<UInt8>()
    }
}

/// 线程本地的编辑器上下文
public let EDITOR_CONTEXT = ThreadLocal<EditorContextSlot>(() => EditorContextSlot())

// ============================================================================
// Stdio 存储模块
// ============================================================================

/// StdioStores - 管理 stdin/stdout/stderr 的 Blob 存储
public class StdioStores {

    static let STDIN = ThreadLocal(?StoreRef>(() => None)
    static let STDOUT = ThreadLocal(?StoreRef>(() => None)
    static let STDERR = ThreadLocal(?StoreRef>(() => None)

    /// 构建一个 Blob Store
    static func buildStore(uvFd: Int32, isAtty: Bool): StoreRef {
        let fd = Fd.fromUv(uvFd)
        let mode: UInt32 = match (Sys.fstat(fd)) {
            case Ok(stat) => UInt32.tryFrom(stat.st_mode) ?? 0
            case Err(_) => 0
        }
        let store = Store.new(Store{
            data = Data.File(FileStore{
                pathlike = PathOrFileDescriptor.Fd(fd),
                is_atty = Some(isAtty),
                mode = mode,
            }),
            mime_type = MimeType.NONE,
            ref_count = ThreadSafeRefCount(),
            is_all_ascii = None,
        })
        return StoreRef.from(store)
    }

    /// 创建 Blob 的通用方法
    static func makeBlob(
        globalThis: JsGlobalObject,
        slot: ThreadLocal(?StoreRef>,
        uvFd: Int32,
        isAtty: Bool,
        feature: AtomicUInt64,
    ): JsValue {
        // 分析特性计数
        feature.fetchAdd(1, MemoryOrder.Relaxed)

        let store = slot.with(func(cell: RefCell(?StoreRef)): StoreRef {
            var s = cell.borrowMut()
            if (s.isNone()) {
                s = Some(buildStore(uvFd, isAtty))
            }
            return s.get().clone()
        })
        let blob = Blob.new(Blob.initWithStore(store, globalThis))
        return blob.toJS(globalThis)
    }

    /// 创建 stdin Blob
    public static func stdin(globalThis: JsGlobalObject): JsValue {
        let isAtty = Sys.isatty(Fd.fromUv(0))
        return makeBlob(globalThis, STDIN, 0, isAtty, Features.BUN_STDIN)
    }

    /// 创建 stdout Blob
    public static func stdout(globalThis: JsGlobalObject): JsValue {
        let isAtty = Output.stdoutDescriptorType() == OutputStreamDescriptor.Terminal
        return makeBlob(globalThis, STDOUT, 1, isAtty, Features.BUN_STDOUT)
    }

    /// 创建 stderr Blob
    public static func stderr(globalThis: JsGlobalObject): JsValue {
        let isAtty = Output.stderrDescriptorType() == OutputStreamDescriptor.Terminal
        return makeBlob(globalThis, STDERR, 2, isAtty, Features.BUN_STDERR)
    }
}

// ============================================================================
// BunObject 回调/属性注册表
// ============================================================================

/// BunObject 回调注册表 - 包含所有 Bun 全局对象的回调函数名称到实现的映射
public class BunObjectRegistry {

    // --- 回调函数注册表 ---
    public static let CALLBACKS: HashMap<String, (JsGlobalObject, JsCallFrame) -> JsValue> = HashMap<String, (JsGlobalObject, JsCallFrame) -> JsValue>.from([
        ("allocUnsafe", (global, cf) => BunObject.allocUnsafe(global, cf)),
        ("build", (global, cf) => StaticAdapters.jsBundlerBuild(global, cf)),
        ("color", (global, cf) => CssJs.jsFunctionColor(global, cf)),
        ("connect", (global, cf) => StaticAdapters.listenerConnect(global, cf)),
        ("deflateSync", (global, cf) => JSZlib.deflateSync(global, cf)),
        ("file", (global, cf) => Blob.constructBunFile(global, cf)),
        ("gunzipSync", (global, cf) => JSZlib.gunzipSync(global, cf)),
        ("gzipSync", (global, cf) => JSZlib.gzipSync(global, cf)),
        ("indexOfLine", (global, cf) => BunObject.indexOfLine(global, cf)),
        ("inflateSync", (global, cf) => JSZlib.inflateSync(global, cf)),
        ("jest", (global, cf) => Jest.call(global, cf)),
        ("listen", (global, cf) => StaticAdapters.listenerListen(global, cf)),
        ("mmap", (global, cf) => BunObject.mmapFile(global, cf)),
        ("nanoseconds", (global, cf) => BunObject.nanoseconds(global, cf)),
        ("openInEditor", (global, cf) => BunObject.openInEditor(global, cf)),
        ("registerMacro", (global, cf) => BunObject.registerMacro(global, cf)),
        ("resolve", (global, cf) => BunObject.resolve(global, cf)),
        ("resolveSync", (global, cf) => BunObject.resolveSync(global, cf)),
        ("serve", (global, cf) => BunObject.serve(global, cf)),
        ("sha", (global, cf) => StaticAdapters.sha(global, cf)),
        ("shellEscape", (global, cf) => BunObject.shellEscape(global, cf)),
        ("shrink", (global, cf) => BunObject.shrink(global, cf)),
        ("stringWidth", (global, cf) => BunObject.stringWidth(global, cf)),
        ("sleepSync", (global, cf) => BunObject.sleepSync(global, cf)),
        ("spawn", (global, cf) => StaticAdapters.subprocessSpawn(global, cf)),
        ("spawnSync", (global, cf) => StaticAdapters.subprocessSpawnSync(global, cf)),
        ("udpSocket", (global, cf) => StaticAdapters.udpSocket(global, cf)),
        ("which", (global, cf) => BunObject.which(global, cf)),
        ("write", (global, cf) => Blob.writeFile(global, cf)),
        ("zstdCompressSync", (global, cf) => JSZstd.compressSync(global, cf)),
        ("zstdDecompressSync", (global, cf) => JSZstd.decompressSync(global, cf)),
        ("zstdCompress", (global, cf) => JSZstd.compress(global, cf)),
        ("zstdDecompress", (global, cf) => JSZstd.decompress(global, cf)),
        ("createParsedShellScript", (global, cf) => StaticAdapters.parsedShellScriptCreate(global, cf)),
        ("createShellInterpreter", (global, cf) => StaticAdapters.shellInterpreterCreate(global, cf))
    ])

    // --- 惰性属性回调注册表 ---
    public static let LAZY_PROPERTIES: HashMap<String, (JsGlobalObject, JsObject) -> JsValue> = HashMap<String, (JsGlobalObject, JsObject) -> JsValue>.from([
        ("Archive", (global, obj) => BunObject.getArchiveConstructor(global, obj)),
        ("CryptoHasher", (global, obj) => Crypto.CryptoHasher.getter(global, obj)),
        ("CSRF", (global, obj) => BunObject.getCSRFObject(global, obj)),
        ("FFI", (global, obj) => FFIObject.getter(global, obj)),
        ("FileSystemRouter", (global, obj) => BunObject.getFileSystemRouter(global, obj)),
        ("Glob", (global, obj) => BunObject.getGlobConstructor(global, obj)),
        ("Image", (global, obj) => BunObject.getImageConstructor(global, obj)),
        ("MD4", (global, obj) => Crypto.MD4.getter(global, obj)),
        ("MD5", (global, obj) => Crypto.MD5.getter(global, obj)),
        ("SHA1", (global, obj) => Crypto.SHA1.getter(global, obj)),
        ("SHA224", (global, obj) => Crypto.SHA224.getter(global, obj)),
        ("SHA256", (global, obj) => Crypto.SHA256.getter(global, obj)),
        ("SHA384", (global, obj) => Crypto.SHA384.getter(global, obj)),
        ("SHA512", (global, obj) => Crypto.SHA512.getter(global, obj)),
        ("SHA512_256", (global, obj) => Crypto.SHA512_256.getter(global, obj)),
        ("JSONC", (global, obj) => BunObject.getJSONCObject(global, obj)),
        ("markdown", (global, obj) => BunObject.getMarkdownObject(global, obj)),
        ("TOML", (global, obj) => BunObject.getTOMLObject(global, obj)),
        ("JSON5", (global, obj) => BunObject.getJSON5Object(global, obj)),
        ("YAML", (global, obj) => BunObject.getYAMLObject(global, obj)),
        ("Transpiler", (global, obj) => BunObject.getTranspilerConstructor(global, obj)),
        ("argv", (global, obj) => BunObject.getArgv(global, obj)),
        ("cron", (global, obj) => BunObject.getCronObject(global, obj)),
        ("cwd", (global, obj) => BunObject.getCWD(global, obj)),
        ("embeddedFiles", (global, obj) => BunObject.getEmbeddedFiles(global, obj)),
        ("enableANSIColors", (global, obj) => BunObject.enableANSIColors(global, obj)),
        ("hash", (global, obj) => BunObject.getHashObject(global, obj)),
        ("inspect", (global, obj) => BunObject.getInspect(global, obj)),
        ("origin", (global, obj) => BunObject.getOrigin(global, obj)),
        ("semver", (global, obj) => BunObject.getSemver(global, obj)),
        ("unsafe", (global, obj) => BunObject.getUnsafe(global, obj)),
        ("S3Client", (global, obj) => BunObject.getS3ClientConstructor(global, obj)),
        ("s3", (global, obj) => BunObject.getS3DefaultClient(global, obj)),
        ("ValkeyClient", (global, obj) => BunObject.getValkeyClientConstructor(global, obj)),
        ("valkey", (global, obj) => BunObject.getValkeyDefaultClient(global, obj)),
        ("Terminal", (global, obj) => BunObject.getTerminalConstructor(global, obj))
    ])

    // --- Getter / Setter ---
    public static func mainGetter(globalThis: JsGlobalObject): JsValue {
        return BunObject.getMain(globalThis)
    }

    public static func mainSetter(globalThis: JsGlobalObject, newValue: JsValue): Bool {
        return BunObject.setMain(globalThis, newValue)
    }

    // --- 惰性属性初始化器 ---
    public static func createBunStdin(globalThis: JsGlobalObject): JsValue {
        return BunObject.createBunStdin(globalThis)
    }

    public static func createBunStderr(globalThis: JsGlobalObject): JsValue {
        return BunObject.createBunStderr(globalThis)
    }

    public static func createBunStdout(globalThis: JsGlobalObject): JsValue {
        return BunObject.createBunStdout(globalThis)
    }
}

// ============================================================================
// 常量
// ============================================================================

/// 每毫秒的纳秒数
public let NS_PER_MS: UInt64 = 1_000_000

/// 默认分配器
public let default_allocator = default_allocator

/// 最大路径长度
public let MAX_PATH_BYTES: Int64 = MAX_PATH_BYTES

// ============================================================================
// 类型别名
// ============================================================================

public type BunString = BunString
