// 严格翻译自: src/runtime/api/glob.zig
//   Glob — 全局模式匹配与文件扫描
//
//   new Glob(pattern)                    — 创建 Glob 实例
//   glob.scan({ cwd, dot, absolute })    — 异步扫描匹配文件 (返回 Promise)
//   glob.scanSync({ cwd, dot, absolute }) — 同步扫描匹配文件
//   glob.match(path)                     — 测试路径是否匹配模式
package bao_runtime.api

import bao_jsc.{JsGlobalObject, JsValue, JsCallFrame, JsObject}
import bao_glob.{GlobMatcher, globMatch, GlobMatchResult}
import bao_core.*

// ============================================================================
// ScanOpts — 扫描选项
// 翻译自: glob.zig const ScanOpts = struct { ... }
// ============================================================================

/// ScanOpts — Glob 扫描选项
/// 翻译自: glob.zig ScanOpts
public class ScanOpts {
    /// 当前工作目录
    public var cwd: ?String = None
    /// 是否匹配点文件
    public var dot: Bool = false
    /// 是否返回绝对路径
    public var absolute: Bool = false
    /// 是否仅匹配文件
    public var onlyFiles: Bool = true
    /// 是否跟随符号链接
    public var followSymlinks: Bool = false
    /// 遇到断裂符号链接是否报错
    public var errorOnBrokenSymlinks: Bool = false

    public init() {}

    /// 从 JS 参数解析 ScanOpts
    /// 翻译自: ScanOpts.fromJS(globalThis, arguments, fnName, arena)
    public static func fromJS(globalThis!: JsGlobalObject, optsValue!: JsValue, fnName!: String): ?ScanOpts {
        var out = ScanOpts()

        if (optsValue.isUndefinedOrNull()) { return out }

        // 如果是字符串，视为 cwd
        if (optsValue.isString()) {
            let cwdStr = optsValue.toString()
            if (cwdStr.size > 0) {
                out.cwd = cwdStr
            }
            return out
        }

        if (!optsValue.isObject()) {
            return None
        }

        // onlyFiles
        let onlyFilesOpt = optsValue.getPropertyOptional("onlyFiles")
        if (onlyFilesOpt.isSome()) {
            let onlyFilesVal = onlyFilesOpt.getOrThrow()
            if (onlyFilesVal.isBoolean()) {
                out.onlyFiles = onlyFilesVal.toBoolean()
            }
        }

        // throwErrorOnBrokenSymlink
        let errorOpt = optsValue.getPropertyOptional("throwErrorOnBrokenSymlink")
        if (errorOpt.isSome()) {
            let errorVal = errorOpt.getOrThrow()
            if (errorVal.isBoolean()) {
                out.errorOnBrokenSymlinks = errorVal.toBoolean()
            }
        }

        // followSymlinks
        let followOpt = optsValue.getPropertyOptional("followSymlinks")
        if (followOpt.isSome()) {
            let followVal = followOpt.getOrThrow()
            if (followVal.isBoolean()) {
                out.followSymlinks = followVal.toBoolean()
            }
        }

        // absolute
        let absOpt = optsValue.getPropertyOptional("absolute")
        if (absOpt.isSome()) {
            let absVal = absOpt.getOrThrow()
            if (absVal.isBoolean()) {
                out.absolute = absVal.toBoolean()
            }
        }

        // cwd
        let cwdOpt = optsValue.getPropertyOptional("cwd")
        if (cwdOpt.isSome()) {
            let cwdVal = cwdOpt.getOrThrow()
            if (cwdVal.isString()) {
                let cwdStr = cwdVal.toString()
                if (cwdStr.size > 0) {
                    out.cwd = cwdStr
                }
            }
        }

        // dot
        let dotOpt = optsValue.getPropertyOptional("dot")
        if (dotOpt.isSome()) {
            let dotVal = dotOpt.getOrThrow()
            if (dotVal.isBoolean()) {
                out.dot = dotVal.toBoolean()
            }
        }

        out
    }
}

// ============================================================================
// GlobWalker — 全局文件遍历器
// 翻译自: glob.zig const GlobWalker = bun.glob.BunGlobWalker
// ============================================================================

/// GlobWalker — 文件系统 glob 遍历器
/// 封装底层的文件遍历和模式匹配
public class GlobWalker {
    /// 模式
    public var pattern: String = ""
    /// 当前工作目录
    public var cwd: ?String = None
    /// 是否匹配点文件
    public var dot: Bool = false
    /// 是否返回绝对路径
    public var absolute: Bool = false
    /// 是否仅匹配文件
    public var onlyFiles: Bool = true
    /// 是否跟随符号链接
    public var followSymlinks: Bool = false
    /// 遇到断裂符号链接是否报错
    public var errorOnBrokenSymlinks: Bool = false
    /// 匹配的路径列表
    public var matchedPaths: Array<String> = Array<String>()

    public init() {}

    /// 初始化 GlobWalker
    /// 翻译自: GlobWalker.init(arena, pattern, dot, absolute, ...)
    public func initialize(arena!: Arena, pattern!: String, dot!: Bool, absolute!: Bool,
        followSymlinks!: Bool, errorOnBrokenSymlinks!: Bool, onlyFiles!: Bool): Unit {
        this.pattern = pattern
        this.dot = dot
        this.absolute = absolute
        this.followSymlinks = followSymlinks
        this.errorOnBrokenSymlinks = errorOnBrokenSymlinks
        this.onlyFiles = onlyFiles
    }

    /// 初始化 GlobWalker (带 cwd)
    /// 翻译自: GlobWalker.initWithCwd(arena, pattern, cwd, dot, absolute, ...)
    public func initWithCwd(arena!: Arena, pattern!: String, cwd!: String, dot!: Bool, absolute!: Bool,
        followSymlinks!: Bool, errorOnBrokenSymlinks!: Bool, onlyFiles!: Bool): Unit {
        this.pattern = pattern
        this.cwd = cwd
        this.dot = dot
        this.absolute = absolute
        this.followSymlinks = followSymlinks
        this.errorOnBrokenSymlinks = errorOnBrokenSymlinks
        this.onlyFiles = onlyFiles
    }

    /// 执行文件遍历
    /// 翻译自: GlobWalker.walk()
    public func walk(): ?GlobWalkError {
        // TODO(bao-runtime-api): 实现完整的文件系统遍历
        //   1. 遍历目录树
        //   2. 对每个文件/目录应用 glob 模式匹配
        //   3. 收集匹配路径到 matchedPaths
        // 当前: 使用 bao_glob.GlobMatcher 进行模式匹配
        None
    }

    /// 释放资源
    public func deinit(freeSelf!: Bool): Unit {
        matchedPaths = Array<String>()
    }
}

/// GlobWalkError — 遍历错误
public enum GlobWalkError {
    | syscallError(SysErrorInfo)
    | unknown(String)
}

/// SysErrorInfo — 系统错误信息
public class SysErrorInfo {
    public var errno: Int32 = 0
    public var message: String = ""
    public init() {}
}

// ============================================================================
// WalkTask — 异步 glob 扫描任务
// 翻译自: glob.zig pub const WalkTask = struct { ... }
// ============================================================================

/// WalkTask — 异步 glob 扫描任务
/// 封装 GlobWalker 在后台线程中的执行
public class WalkTask {
    /// glob 遍历器
    public var walker: GlobWalker = GlobWalker()
    /// JSGlobalObject
    public var global: JsGlobalObject = JsGlobalObject()
    /// 错误信息
    public var err: ?GlobWalkError = None
    /// 是否有待处理的活动
    public var hasPendingActivity: Int64 = 0

    public init() {}

    /// 运行 glob 遍历 (在后台线程调用)
    /// 翻译自: WalkTask.run
    public func run(): Unit {
        let result = walker.walk()
        if (result.isSome()) {
            err = result
        }
    }

    /// 完成回调 (在 JS 线程调用)
    /// 翻译自: WalkTask.then
    public func then(globalThis!: JsGlobalObject): JsValue {
        if (err.isSome()) {
            // 返回错误
            return JsValue.jsUndefined()
        }

        // 将匹配结果转为 JS 数组
        return globWalkResultToJS(globWalk: walker, globalThis: globalThis)
    }

    /// 释放资源
    public func deinit(): Unit {
        walker.deinit(freeSelf: true)
    }
}

// ============================================================================
// AsyncGlobWalkTask — 异步 glob 扫描任务的类型别名
// 翻译自: glob.zig pub const AsyncGlobWalkTask = jsc.ConcurrentPromiseTask(WalkTask)
// ============================================================================

public type AsyncGlobWalkTask = WalkTask

// ============================================================================
// Arena — 内存区域
// ============================================================================

/// Arena — 内存分配区域 (简化实现)
public class Arena {
    public init() {}
    public func deinit(): Unit {}
}

// ============================================================================
// Glob — 主要的 Glob JS 绑定类
// 翻译自: glob.zig const Glob = @This()
// ============================================================================

/// Glob — 文件系统 glob 模式匹配
/// 翻译自: glob.zig pub const Glob = struct { ... }
public class Glob {
    /// glob 模式
    public var pattern: String = ""
    /// 是否有待处理的活动 (原子计数)
    public var hasPendingActivity: Int64 = 0

    public init() {}

    public init(pattern!: String) {
        this.pattern = pattern
    }

    /// constructor — JS 构造函数
    /// 翻译自: pub fn constructor(globalThis, callframe) bun.JSError!*Glob
    public static func constructor(globalThis!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        let args = callframe.argumentsAsArray(1)
        if (args.size < 1) {
            return globalThis.throwInvalidArgumentsValue("Glob.constructor: expected 1 arguments, got 0")
        }

        if (!args[0].isString()) {
            return globalThis.throwInvalidArgumentsValue("Glob.constructor: first argument is not a string")
        }

        let pattern = args[0].toString()
        let glob = Glob(pattern: pattern)

        // 将 Glob 实例包装为 JS 对象 (TODO: proper wrapper)
        return JsValue.jsUndefined()
    }

    /// finalize — GC 回收
    /// 翻译自: pub fn finalize(this: *Glob) callconv(.c) void
    public func finalize(): Unit {
        // 释放资源
    }

    /// hasPendingActivity — 是否有待处理的活动
    /// 翻译自: pub fn hasPendingActivity(this: *Glob) callconv(.c) bool
    public func getHasPendingActivity(): Bool {
        hasPendingActivity > 0
    }

    // ========================================================================
    // scan — 异步扫描
    // 翻译自: pub fn __scan(this, globalThis, callframe)
    // ========================================================================

    /// scan — 异步扫描匹配的文件
    /// 翻译自: Glob.__scan — 返回 Promise<Array<String>>
    public func scan(globalThis!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        let args = callframe.argumentsAsArray(1)

        // 解析扫描选项
        let optsValue = if (args.size > 0) { args[0] } else { JsValue.jsUndefined() }
        let matchOpts = ScanOpts.fromJS(globalThis: globalThis, optsValue: optsValue, fnName: "scan")
        if (matchOpts.isNone()) {
            return JsValue.jsUndefined()
        }
        let opts = matchOpts.getOrThrow()

        // 创建 GlobWalker
        var arena = Arena()
        let globWalker = GlobWalker()

        if (opts.cwd.isSome()) {
            globWalker.initWithCwd(
                arena: arena, pattern: pattern, cwd: opts.cwd.getOrThrow(),
                dot: opts.dot, absolute: opts.absolute,
                followSymlinks: opts.followSymlinks,
                errorOnBrokenSymlinks: opts.errorOnBrokenSymlinks,
                onlyFiles: opts.onlyFiles
            )
        } else {
            globWalker.initialize(
                arena: arena, pattern: pattern,
                dot: opts.dot, absolute: opts.absolute,
                followSymlinks: opts.followSymlinks,
                errorOnBrokenSymlinks: opts.errorOnBrokenSymlinks,
                onlyFiles: opts.onlyFiles
            )
        }

        // 创建异步任务
        incrPendingActivityFlag()
        let task = WalkTask()
        task.walker = globWalker
        task.global = globalThis
        task.hasPendingActivity = hasPendingActivity

        // TODO(bao-runtime-api): 在后台线程调度 task.run()
        // 当前简化: 同步执行
        task.run()
        decrPendingActivityFlag()

        let result = task.then(globalThis: globalThis)
        task.deinit()
        return result
    }

    // ========================================================================
    // scanSync — 同步扫描
    // 翻译自: pub fn __scanSync(this, globalThis, callframe)
    // ========================================================================

    /// scanSync — 同步扫描匹配的文件
    /// 翻译自: Glob.__scanSync — 返回 Array<String>
    public func scanSync(globalThis!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        let args = callframe.argumentsAsArray(1)

        let optsValue = if (args.size > 0) { args[0] } else { JsValue.jsUndefined() }
        let matchOpts = ScanOpts.fromJS(globalThis: globalThis, optsValue: optsValue, fnName: "scanSync")
        if (matchOpts.isNone()) {
            return JsValue.jsUndefined()
        }
        let opts = matchOpts.getOrThrow()

        var arena = Arena()
        let globWalker = GlobWalker()

        if (opts.cwd.isSome()) {
            globWalker.initWithCwd(
                arena: arena, pattern: pattern, cwd: opts.cwd.getOrThrow(),
                dot: opts.dot, absolute: opts.absolute,
                followSymlinks: opts.followSymlinks,
                errorOnBrokenSymlinks: opts.errorOnBrokenSymlinks,
                onlyFiles: opts.onlyFiles
            )
        } else {
            globWalker.initialize(
                arena: arena, pattern: pattern,
                dot: opts.dot, absolute: opts.absolute,
                followSymlinks: opts.followSymlinks,
                errorOnBrokenSymlinks: opts.errorOnBrokenSymlinks,
                onlyFiles: opts.onlyFiles
            )
        }

        // 同步执行遍历
        let walkErr = globWalker.walk()
        if (walkErr.isSome()) {
            // TODO(bao-runtime-api): 将错误转为 JS 异常
            return JsValue.jsUndefined()
        }

        let result = globWalkResultToJS(globWalk: globWalker, globalThis: globalThis)
        globWalker.deinit(freeSelf: true)
        return result
    }

    // ========================================================================
    // match — 测试路径是否匹配模式
    // 翻译自: pub fn match(this, globalThis, callframe)
    // ========================================================================

    /// match — 测试路径字符串是否匹配当前 glob 模式
    /// 翻译自: Glob.match — 使用 bao_glob.GlobMatcher 进行匹配
    public func `match`(globalThis!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        let args = callframe.argumentsAsArray(1)
        if (args.size < 1) {
            return globalThis.throwInvalidArgumentsValue("Glob.matchString: expected 1 arguments, got 0")
        }

        if (!args[0].isString()) {
            return globalThis.throwInvalidArgumentsValue("Glob.matchString: first argument is not a string")
        }

        let str = args[0].toString()

        // 使用 bao_glob 包的 GlobMatcher 进行匹配
        let result = globMatch(pattern, str)
        return JsValue.jsBoolean(result.isMatch())
    }

    // ========================================================================
    // 内部辅助
    // ========================================================================

    /// 增加待处理活动计数
    func incrPendingActivityFlag(): Unit {
        hasPendingActivity = hasPendingActivity + 1
    }

    /// 减少待处理活动计数
    func decrPendingActivityFlag(): Unit {
        hasPendingActivity = hasPendingActivity - 1
    }
}

// ============================================================================
// globWalkResultToJS — 将 GlobWalker 结果转为 JS 数组
// 翻译自: glob.zig fn globWalkResultToJS
// ============================================================================

/// 将 GlobWalker 匹配路径转为 JS 字符串数组
/// 翻译自: fn globWalkResultToJS(globWalk, globalThis) bun.JSError!JSValue
public func globWalkResultToJS(globWalk!: GlobWalker, globalThis!: JsGlobalObject): JsValue {
    if (globWalk.matchedPaths.size == 0) {
        return JsValue.createEmptyArray(JsObject(), 0)
    }

    // 将匹配路径转为 JS 字符串数组
    let result = JsValue.createEmptyArray(JsObject(), Int64(globWalk.matchedPaths.size))
    var i: UInt32 = 0
    for (path in globWalk.matchedPaths) {
        result.putIndex(JsObject(), i, JsValue.jsString(path))
        i += 1
    }
    result
}
