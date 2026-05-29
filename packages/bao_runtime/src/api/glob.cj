// 严格翻译自: src/runtime/api/glob.zig
package bao_runtime.api

import bao_jsc.*
import bao_core.*
import bao_sys.*
import bao_io.*
import bao_collections.*
import bao_ptr.AtomicUInt64

/// Arena stub for Glob - corresponds to Bun Arena allocator
public class Arena {
    private let alloc: Allocator
    public init(alloc: Allocator) { this.alloc = alloc }
    public func allocator(): Allocator { alloc }
    public func deinit(): Unit {}
}

/// GlobWalker stub for Glob traversal
public class GlobWalker {
    public init() {}
}

// ============================================================================
// Glob - 文件模式匹配
// 对应 Bun: src/runtime/api/glob.zig
// ============================================================================

/// Glob 对象，用于文件模式匹配
public class Glob {
    var pattern: String
    var hasPendingActivity: AtomicUInt64 = AtomicUInt64(0)

    // ========================================================================
    // ScanOpts - 扫描选项
    // ========================================================================

//    public class ScanOpts {
//        var cwd: String = none
//        var dot: Bool = false
//        var absolute: Bool = false
//        var onlyFiles: Bool = true
//        var followSymlinks: Bool = false
//        var errorOnBrokenSymlinks: Bool = false

//        /// 解析 CWD 路径
//        public static func parseCWD(globalThis!: JsGlobalObject, allocator!: Allocator, cwdVal!: JsValue, absolute!: Bool, fnName!: String): String {
//            let cwdString = BunString.fromJS(cwdVal, globalThis) 
//            if (cwdString.isEmpty()) { return "" 

//            let cwdStr = {
//                let cwdUtf8 = cwdString.toUTF8WithoutRef(allocator)

//                // 如果是绝对路径，直接返回
//                if (ResolvePath.Platform.auto.isAbsolute(cwdUtf8.slice())) {
//                    return (cwdUtf8.cloneIfBorrowed(allocator) ).slice()
//                }

//                var pathBuf2 = PathBuffer()

//                if (!absolute) {
//                    let parts = [cwdUtf8.slice()]
//                    let cwdStr = ResolvePath.joinStringBuf(pathBuf2, parts, .auto)
//                    return allocator.dupe(UInt8, cwdStr) 
                

//                // 转换为绝对路径
//                var pathBuf = PathBuffer()
//                let cwd = match (Sys.getcwd(pathBuf)) {
//                    case result(cwd) => cwd
//                    case err(err) =>
//                        let errJs = err.toJS(globalThis) 
//                        return globalThis.throwValue(errJs)
//                }

//                let cwdStr = ResolvePath.joinStringBuf(pathBuf2, [cwd, cwdUtf8.slice()], .auto)
//                return allocator.dupe(UInt8, cwdStr) 
//
//                    cwdUtf8.deinit()
//            }

//            if (cwdStr.len > MAX_PATH_BYTES) {
//                return globalThis.`throw`("${fnName}: invalid `cwd`, longer than ${MAX_PATH_BYTES} bytes")
//            }

//            return cwdStr
//
//                cwdString.deref()
//        }

//        /// 从 JS 参数解析扫描选项
//        public static func fromJS(globalThis!: JsGlobalObject, arguments!: ArgumentsSlice, fnName!: String, arena!: Arena): ScanOpts {
//            let optsObj = arguments.nextEat() ?? return none
//            var out = ScanOpts{
//                cwd = null,
//                dot = false,
//                absolute = false,
//                followSymlinks = false,
//                errorOnBrokenSymlinks = false,
//                onlyFiles = true,
//            }
//            if (optsObj.isUndefinedOrNull()) { return out }
//            if (!optsObj.isObject()) {
//                if (optsObj.isString()) {
//                    let result = parseCWD(globalThis, arena.allocator() , optsObj, out.absolute, fnName)
//                    if (result.len > 0) {
//                        out.cwd = result
//                    }
//                    return out
//                }
//                return globalThis.`throw`("${fnName}: expected first argument to be an object")
//            }

//            if (let onlyFiles <- optsObj.getTruthy(globalThis, "onlyFiles") ) {
//                out.onlyFiles = if (onlyFiles.isBoolean()) onlyFiles.asBoolean() else false
//            }

//            if (let errorOnBroken <- optsObj.getTruthy(globalThis, "throwErrorOnBrokenSymlink") ) {
//                out.errorOnBrokenSymlinks = if (errorOnBroken.isBoolean()) errorOnBroken.asBoolean() else false
//            }

//            if (let followSymlinksVal <- optsObj.getTruthy(globalThis, "followSymlinks") ) {
//                out.followSymlinks = if (followSymlinksVal.isBoolean()) followSymlinksVal.asBoolean() else false
//            }

//            if (let absoluteVal <- optsObj.getTruthy(globalThis, "absolute") ) {
//                out.absolute = if (absoluteVal.isBoolean()) absoluteVal.asBoolean() else false
//            }

//            if (let cwdVal <- optsObj.getTruthy(globalThis, "cwd") ) {
//                if (!cwdVal.isString()) {
//                    return globalThis.`throw`("${fnName}: invalid `cwd`, not a string")
//                }

//                let result = parseCWD(globalThis, arena.allocator() , cwdVal, out.absolute, fnName)
//                if (result.len > 0) {
//                    out.cwd = result
//                }
//            }

//            if (let dot <- optsObj.getTruthy(globalThis, "dot") ) {
//                out.dot = if (dot.isBoolean()) dot.asBoolean() else false
//            }

//            return out
//        }
//    }

    // ========================================================================
    // WalkTask - 异步扫描任务
    // ========================================================================

//    public class WalkTask {
//        var walker: GlobWalker
//        var alloc: Allocator
//        var err: Err = none
//        var global: JsGlobalObject
//        var hasPendingActivity: AtomicUInt64

//        /// 错误类型
//        public enum Err {
//            | syscall(SyscallError)
//            | unknown(Error)

//            public func toJS(globalThis!: JsGlobalObject): JsValue {
//                return match (this) {
//                    | syscall(err) => err.toJS(globalThis) 
//                    case unknown(err) => ZigString.fromBytes(err.name).toJS(globalThis)
//                }
//            }
//        }

//        /// 创建异步扫描任务
//        public static func create(
//            globalThis!: JsGlobalObject,
//            alloc!: Allocator,
//            globWalker!: GlobWalker,
//            hasPendingActivity!: AtomicUInt64,
//        ): AsyncGlobWalkTask {
//            let walkTask = alloc.create(WalkTask) 
//            walkTask = WalkTask{
//                walker = globWalker,
//                global = globalThis,
//                alloc = alloc,
//                hasPendingActivity = hasPendingActivity,
//            }
//            return AsyncGlobWalkTask.createOnJSThread(alloc, globalThis, walkTask)
//        }

//        /// 执行扫描
//        public func run() {
//            let result = this.walker.walk() catch { err =>
//                this.err = Err.unknown(err)
//                return
            
//            match (result) {
//                case err(err) =>
//                    this.err = Err.syscall(err)
//                case result => ()
//            }
//
//                decrPendingActivityFlag(this.hasPendingActivity)
//        }

//        /// 扫描完成后的回调
//        public func then(promise!: JsPromise) {
//            if (let err <- this.err) {
//                promise.rejectWithAsyncStack(this.global, err.toJS(this.global) )
//                return
            

//            let jsStrings = globWalkResultToJS(this.walker, this.global) catch {
//                return promise.reject(this.global, Error.JSError)
//            }
//            promise.resolve(this.global, jsStrings) 
//
//                this.deinit()
//        }

//        /// 释放资源
//        func deinit() {
//            this.walker.deinit(true)
//            this.alloc.destroy(this.walker)
//            this.alloc.destroy(this)
//        }
//    }

    // ========================================================================
    // Glob 的方法
    // ========================================================================

    /// 构造函数
    public static func constructor(globalThis!: JsGlobalObject, callframe!: JsCallFrame): Glob {
        let rawArgs = callframe.argumentsOld(1)
        var arguments = ArgumentsSlice(globalThis.bunVM(), rawArgs.slice())
        let patArgOpt = arguments.nextEat()
        if (patArgOpt.isNone()) {
            arguments.deinit()
            return globalThis.`throw`("Glob.constructor: expected 1 arguments, got 0")
        }

        let patArg = patArgOpt.get()

        if (!patArg.isString()) {
            arguments.deinit()
            return globalThis.`throw`("Glob.constructor: first argument is not a string")
        }

        let patStr = (patArg.toSliceClone(globalThis)).slice()

        arguments.deinit()
        return Glob{ pattern = patStr }
    }

    /// 终结化
    public func finalize() {
        default_allocator.free(this.pattern)
        destroy(this)
    }

    /// 是否有待处理活动
    public func getHasPendingActivity(): Bool {
        return this.hasPendingActivity.load(MemoryOrderMemoryOrder.seq_cst) > 0
    }

    /// scan - 异步扫描匹配文件
    public func scan(globalThis!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        let alloc = default_allocator

        let rawArgs = callframe.argumentsOld(1)
        var arguments = ArgumentsSlice(globalThis.bunVM(), rawArgs.slice())
        var arena = ArenaAllocator(alloc)
        let globWalkerOpt = try {
            this.makeGlobWalker(globalThis, arguments, "scan", alloc, arena)
        } catch(err: Exception) {
            arena.deinit()
            throw err
        }
        if (globWalkerOpt.isNone()) {
            arena.deinit()
            return JsValue.jsUndefined()
        }
        let globWalker = globWalkerOpt.get()

        incrPendingActivityFlag(this.hasPendingActivity)
        var task = try {
            WalkTask.create(globalThis, alloc, globWalker, this.hasPendingActivity)
        } catch(_: Exception) {
            decrPendingActivityFlag(this.hasPendingActivity)
            globWalker.deinit(true)
            alloc.destroy(globWalker)
            return globalThis.throwOutOfMemory()
        }
        task.schedule()

        arguments.deinit()
        return task.promise.getValue()
    }

    /// scanSync - 同步扫描匹配文件
    public func scanSync(globalThis!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        let alloc = default_allocator

        let rawArgs = callframe.argumentsOld(1)
        var arguments = ArgumentsSlice(globalThis.bunVM(), rawArgs.slice())
        var arena = ArenaAllocator(alloc)
        let globWalkerOpt = try {
            this.makeGlobWalker(globalThis, arguments, "scanSync", alloc, arena)
        } catch(err: Exception) {
            arena.deinit()
            throw err
        }
        if (globWalkerOpt.isNone()) {
            arena.deinit()
            return JsValue.jsUndefined()
        }
        let globWalker = globWalkerOpt.get()
        let walkResult = globWalker.walk()
        match (walkResult) {
            case err(err) =>
                return globalThis.throwValue(err.toJS(globalThis) )
            case result => ()
        }

        let matchedPaths = globWalkResultToJS(globWalker, globalThis)
        globWalker.deinit(true)
        alloc.destroy(globWalker)
        arguments.deinit()
        return matchedPaths
    }

    /// match - 测试字符串是否匹配模式
    public func `match`(globalThis!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        let alloc = default_allocator
        var arena = Arena(alloc)
        let rawArgs = callframe.argumentsOld(1)
        var arguments = ArgumentsSlice(globalThis.bunVM(), rawArgs.slice())

        let strArgOpt = arguments.nextEat()
        if (strArgOpt.isNone()) {
            arguments.deinit()
            arena.deinit()
            return globalThis.`throw`("Glob.matchString: expected 1 arguments, got 0")
        }

        let strArg = strArgOpt.get()

        if (!strArg.isString()) {
            arguments.deinit()
            arena.deinit()
            return globalThis.`throw`("Glob.matchString: first argument is not a string")
        }

        var str = strArg.toSlice(globalThis, arena.allocator())
        let result = JsValue.jsBoolean(BunGlob.`match`(this.pattern, str.slice()).matches())
        str.deinit()
        arguments.deinit()
        arena.deinit()
        return result
    }

    // ========================================================================
    // 私有辅助
    // ========================================================================

    /// 创建 GlobWalker
    func makeGlobWalker(
        globalThis!: JsGlobalObject,
        arguments!: ArgumentsSlice,
        fnName!: String,
        alloc!: Allocator,
        arena!: Arena
    ): GlobWalker {
        let matchOpts = ScanOpts.fromJS(globalThis, arguments, fnName, arena)  ?? return none
        let cwd = matchOpts.cwd
        let dot = matchOpts.dot
        let absolute = matchOpts.absolute
        let followSymlinks = matchOpts.followSymlinks
        let errorOnBrokenSymlinks = matchOpts.errorOnBrokenSymlinks
        let onlyFiles = matchOpts.onlyFiles

        var globWalker = alloc.create(GlobWalker) 
        globWalker = GlobWalker{}

        if (cwd != none) {
            match (globWalker.initWithCwd (
                arena,
                this.pattern,
                cwd,
                dot,
                absolute,
                followSymlinks,
                errorOnBrokenSymlinks,
                onlyFiles,
            )) {
                case err(err) =>
                    return globalThis.throwValue(err.toJS(globalThis) )
                case _ => ()
            }
            return globWalker
        }

        match (globWalker (
            arena,
            this.pattern,
            dot,
            absolute,
            followSymlinks,
            errorOnBrokenSymlinks,
            onlyFiles,
        )) {
            case err(err) =>
                return globalThis.throwValue(err.toJS(globalThis) )
            case _ => ()
        }
        return globWalker
    }

    /// 增加待处理活动计数
    static func incrPendingActivityFlag(hasPendingActivity!: AtomicUInt64) {
        _ = hasPendingActivity.fetchAdd(1, MemoryOrder.seq_cst)
    }

    /// 减少待处理活动计数
    static func decrPendingActivityFlag(hasPendingActivity!: AtomicUInt64) {
        _ = hasPendingActivity.fetchSub(1, MemoryOrder.seq_cst)
    }
}

/// 将 GlobWalker 结果转换为 JS 数组
func globWalkResultToJS(globWalk!: GlobWalker, globalThis!: JsGlobalObject): JsValue {
    if (globWalk.matchedPaths.keys().len == 0) {
        return JsValue.createEmptyArray(globalThis, 0)
    }

    return BunString.toJSArray(globalThis, globWalk.matchedPaths.keys())
}

// ============================================================================
// 类型别名
// ========================================================================

public type AsyncGlobWalkTask = ConcurrentPromiseTaskGeneric
// default_allocator 已通过 import 导入，无需重复定义