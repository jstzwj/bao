// 严格翻译自: src/runtime/api/glob.zig
package bao_runtime.api

import bao_jsc.*
import bao_core.*
import bao_sys.*
import bao_io.*
import bao_collections.*

// ============================================================================
// Glob - 文件模式匹配
// 对应 Bun: src/runtime/api/glob.zig
// ============================================================================

/// Glob 对象，用于文件模式匹配
public class Glob {
    var pattern: String
    var hasPendingActivity: AtomicUInt64 = AtomicUInt64.init(0)

    // ========================================================================
    // ScanOpts - 扫描选项
    // ========================================================================

    public class ScanOpts {
        var cwd: String = null
        var dot: Bool = false
        var absolute: Bool = false
        var onlyFiles: Bool = true
        var followSymlinks: Bool = false
        var errorOnBrokenSymlinks: Bool = false

        /// 解析 CWD 路径
        public static func parseCWD(globalThis: JsGlobalObject, allocator: Allocator, cwdVal: JsValue, absolute: Bool, fnName: String): String {
            let cwdString = try BunString.fromJS(cwdVal, globalThis)
            defer cwdString.deref()
            if (cwdString.isEmpty()) { return "" }

            let cwdStr = {
                let cwdUtf8 = cwdString.toUTF8WithoutRef(allocator)

                // 如果是绝对路径，直接返回
                if (ResolvePath.Platform.auto.isAbsolute(cwdUtf8.slice())) {
                    return (try cwdUtf8.cloneIfBorrowed(allocator)).slice()
                }

                defer cwdUtf8.deinit()
                var pathBuf2 = PathBuffer()

                if (!absolute) {
                    let parts = [cwdUtf8.slice()]
                    let cwdStr = ResolvePath.joinStringBuf(pathBuf2, parts, .auto)
                    return try allocator.dupe(UInt8, cwdStr)
                }

                // 转换为绝对路径
                var pathBuf = PathBuffer()
                let cwd = switch (Sys.getcwd(pathBuf)) {
                    case .result(let cwd) => cwd
                    case .err(let err) => {
                        let errJs = try err.toJS(globalThis)
                        return globalThis.throwValue(errJs)
                    }
                }

                let cwdStr = ResolvePath.joinStringBuf(pathBuf2, [cwd, cwdUtf8.slice()], .auto)
                return try allocator.dupe(UInt8, cwdStr)
            }

            if (cwdStr.len > MAX_PATH_BYTES) {
                return globalThis.throw("\{fnName}: invalid `cwd`, longer than \{MAX_PATH_BYTES} bytes")
            }

            return cwdStr
        }

        /// 从 JS 参数解析扫描选项
        public static func fromJS(globalThis: JsGlobalObject, arguments: ArgumentsSlice, fnName: String, arena: Arena): ScanOpts {
            let optsObj = arguments.nextEat() ?? return null
            var out = ScanOpts{
                cwd = null,
                dot = false,
                absolute = false,
                followSymlinks = false,
                errorOnBrokenSymlinks = false,
                onlyFiles = true,
            }
            if (optsObj.isUndefinedOrNull()) { return out }
            if (!optsObj.isObject()) {
                if (optsObj.isString()) {
                    let result = try parseCWD(globalThis, arena.allocator(), optsObj, out.absolute, fnName)
                    if (result.len > 0) {
                        out.cwd = result
                    }
                    return out
                }
                return globalThis.throw("\{fnName}: expected first argument to be an object")
            }

            if (let onlyFiles = try optsObj.getTruthy(globalThis, "onlyFiles")) {
                out.onlyFiles = if (onlyFiles.isBoolean()) onlyFiles.asBoolean() else false
            }

            if (let errorOnBroken = try optsObj.getTruthy(globalThis, "throwErrorOnBrokenSymlink")) {
                out.errorOnBrokenSymlinks = if (errorOnBroken.isBoolean()) errorOnBroken.asBoolean() else false
            }

            if (let followSymlinksVal = try optsObj.getTruthy(globalThis, "followSymlinks")) {
                out.followSymlinks = if (followSymlinksVal.isBoolean()) followSymlinksVal.asBoolean() else false
            }

            if (let absoluteVal = try optsObj.getTruthy(globalThis, "absolute")) {
                out.absolute = if (absoluteVal.isBoolean()) absoluteVal.asBoolean() else false
            }

            if (let cwdVal = try optsObj.getTruthy(globalThis, "cwd")) {
                if (!cwdVal.isString()) {
                    return globalThis.throw("\{fnName}: invalid `cwd`, not a string")
                }

                let result = try parseCWD(globalThis, arena.allocator(), cwdVal, out.absolute, fnName)
                if (result.len > 0) {
                    out.cwd = result
                }
            }

            if (let dot = try optsObj.getTruthy(globalThis, "dot")) {
                out.dot = if (dot.isBoolean()) dot.asBoolean() else false
            }

            return out
        }
    }

    // ========================================================================
    // WalkTask - 异步扫描任务
    // ========================================================================

    public class WalkTask {
        var walker: GlobWalker
        var alloc: Allocator
        var err: Err = null
        var global: JsGlobalObject
        var hasPendingActivity: AtomicUInt64

        /// 错误类型
        public enum Err {
            case syscall(SyscallError)
            case unknown(Error)

            public func toJS(globalThis: JsGlobalObject): JsValue {
                return switch (this) {
                    case .syscall(let err) => try err.toJS(globalThis)
                    case .unknown(let err) => ZigString.fromBytes(err.name).toJS(globalThis)
                }
            }
        }

        /// 创建异步扫描任务
        public static func create(
            globalThis: JsGlobalObject,
            alloc: Allocator,
            globWalker: GlobWalker,
            hasPendingActivity: AtomicUInt64,
        ): AsyncGlobWalkTask {
            let walkTask = try alloc.create(WalkTask)
            walkTask = WalkTask{
                walker = globWalker,
                global = globalThis,
                alloc = alloc,
                hasPendingActivity = hasPendingActivity,
            }
            return AsyncGlobWalkTask.createOnJSThread(alloc, globalThis, walkTask)
        }

        /// 执行扫描
        public func run() {
            defer decrPendingActivityFlag(this.hasPendingActivity)
            let result = this.walker.walk() catch { err =>
                this.err = Err.unknown(err)
                return
            }
            switch (result) {
                case .err(let err) => {
                    this.err = Err.syscall(err)
                }
                case .result => ()
            }
        }

        /// 扫描完成后的回调
        public func then(promise: JsPromise) {
            defer this.deinit()

            if (let err = this.err) {
                try promise.rejectWithAsyncStack(this.global, err.toJS(this.global))
                return
            }

            let jsStrings = globWalkResultToJS(this.walker, this.global) catch {
                return promise.reject(this.global, Error.JSError)
            }
            try promise.resolve(this.global, jsStrings)
        }

        /// 释放资源
        func deinit() {
            this.walker.deinit(true)
            this.alloc.destroy(this.walker)
            this.alloc.destroy(this)
        }
    }

    // ========================================================================
    // Glob 的方法
    // ========================================================================

    /// 构造函数
    public static func constructor(globalThis: JsGlobalObject, callframe: JsCallFrame): Glob {
        let arguments = callframe.argumentsOld(1)
        var arguments = ArgumentsSlice.init(globalThis.bunVM(), arguments.slice())
        defer arguments.deinit()

        let patArg = arguments.nextEat() ?? {
            return globalThis.throw("Glob.constructor: expected 1 arguments, got 0")
        }

        if (!patArg.isString()) {
            return globalThis.throw("Glob.constructor: first argument is not a string")
        }

        let patStr = (try patArg.toSliceClone(globalThis)).slice()

        return new Glob{ pattern = patStr }
    }

    /// 终结化
    public func finalize() {
        default_allocator.free(this.pattern)
        destroy(this)
    }

    /// 是否有待处理活动
    public func hasPendingActivity(): Bool {
        return this.hasPendingActivity.load(.seq_cst) > 0
    }

    /// scan - 异步扫描匹配文件
    public func scan(globalThis: JsGlobalObject, callframe: JsCallFrame): JsValue {
        let alloc = default_allocator

        let arguments = callframe.argumentsOld(1)
        var arguments = ArgumentsSlice.init(globalThis.bunVM(), arguments.slice())
        defer arguments.deinit()

        var arena = ArenaAllocator.init(alloc)
        let globWalker = this.makeGlobWalker(globalThis, arguments, "scan", alloc, arena) catch { err =>
            arena.deinit()
            throw err
        } ?? {
            arena.deinit()
            return JsValue.jsUndefined()
        }

        incrPendingActivityFlag(this.hasPendingActivity)
        var task = WalkTask.create(globalThis, alloc, globWalker, this.hasPendingActivity) catch {
            decrPendingActivityFlag(this.hasPendingActivity)
            globWalker.deinit(true)
            alloc.destroy(globWalker)
            return globalThis.throwOutOfMemory()
        }
        task.schedule()

        return task.promise.value()
    }

    /// scanSync - 同步扫描匹配文件
    public func scanSync(globalThis: JsGlobalObject, callframe: JsCallFrame): JsValue {
        let alloc = default_allocator

        let arguments = callframe.argumentsOld(1)
        var arguments = ArgumentsSlice.init(globalThis.bunVM(), arguments.slice())
        defer arguments.deinit()

        var arena = ArenaAllocator.init(alloc)
        var globWalker = this.makeGlobWalker(globalThis, arguments, "scanSync", alloc, arena) catch { err =>
            arena.deinit()
            throw err
        } ?? {
            arena.deinit()
            return JsValue.jsUndefined()
        }
        defer {
            globWalker.deinit(true)
            alloc.destroy(globWalker)
        }

        switch (try globWalker.walk()) {
            case .err(let err) => {
                return globalThis.throwValue(try err.toJS(globalThis))
            }
            case .result => ()
        }

        let matchedPaths = globWalkResultToJS(globWalker, globalThis)
        return matchedPaths
    }

    /// match - 测试字符串是否匹配模式
    public func match(globalThis: JsGlobalObject, callframe: JsCallFrame): JsValue {
        let alloc = default_allocator
        var arena = Arena.init(alloc)
        defer arena.deinit()

        let arguments = callframe.argumentsOld(1)
        var arguments = ArgumentsSlice.init(globalThis.bunVM(), arguments.slice())
        defer arguments.deinit()

        let strArg = arguments.nextEat() ?? {
            return globalThis.throw("Glob.matchString: expected 1 arguments, got 0")
        }

        if (!strArg.isString()) {
            return globalThis.throw("Glob.matchString: first argument is not a string")
        }

        var str = try strArg.toSlice(globalThis, arena.allocator())
        defer str.deinit()

        return JsValue.jsBoolean(BunGlob.match(this.pattern, str.slice()).matches())
    }

    // ========================================================================
    // 私有辅助
    // ========================================================================

    /// 创建 GlobWalker
    func makeGlobWalker(
        globalThis: JsGlobalObject,
        arguments: ArgumentsSlice,
        fnName: String,
        alloc: Allocator,
        arena: Arena,
    ): GlobWalker {
        let matchOpts = try ScanOpts.fromJS(globalThis, arguments, fnName, arena) ?? return null
        let cwd = matchOpts.cwd
        let dot = matchOpts.dot
        let absolute = matchOpts.absolute
        let followSymlinks = matchOpts.followSymlinks
        let errorOnBrokenSymlinks = matchOpts.errorOnBrokenSymlinks
        let onlyFiles = matchOpts.onlyFiles

        var globWalker = try alloc.create(GlobWalker)
        globWalker = GlobWalker{}

        if (cwd != null) {
            switch (try globWalker.initWithCwd(
                arena,
                this.pattern,
                cwd,
                dot,
                absolute,
                followSymlinks,
                errorOnBrokenSymlinks,
                onlyFiles,
            )) {
                case .err(let err) => {
                    return globalThis.throwValue(try err.toJS(globalThis))
                }
                else => {}
            }
            return globWalker
        }

        switch (try globWalker.init(
            arena,
            this.pattern,
            dot,
            absolute,
            followSymlinks,
            errorOnBrokenSymlinks,
            onlyFiles,
        )) {
            case .err(let err) => {
                return globalThis.throwValue(try err.toJS(globalThis))
            }
            else => {}
        }
        return globWalker
    }

    /// 增加待处理活动计数
    static func incrPendingActivityFlag(hasPendingActivity: AtomicUInt64) {
        _ = hasPendingActivity.fetchAdd(1, .seq_cst)
    }

    /// 减少待处理活动计数
    static func decrPendingActivityFlag(hasPendingActivity: AtomicUInt64) {
        _ = hasPendingActivity.fetchSub(1, .seq_cst)
    }
}

/// 将 GlobWalker 结果转换为 JS 数组
func globWalkResultToJS(globWalk: GlobWalker, globalThis: JsGlobalObject): JsValue {
    if (globWalk.matchedPaths.keys().len == 0) {
        return JsValue.createEmptyArray(globalThis, 0)
    }

    return BunString.toJSArray(globalThis, globWalk.matchedPaths.keys())
}

// ============================================================================
// 类型别名
// ========================================================================

public typealias AsyncGlobWalkTask = ConcurrentPromiseTask(WalkTask)
public let default_allocator = default_allocator
