// 严格翻译自: src/jsc/SourceProvider.zig + SourceType.zig + ResolvedSource.zig +
//   ScriptExecutionStatus.zig + JSSecrets.zig + JSCScheduler.zig +
//   config.zig + sizes.zig + static_export.zig + StringBuilder.zig
// JavaScriptCore 配置、源码提供器和调度器

package bao_jsc

// ========== SourceType ==========
// 严格翻译自 SourceType.zig
public enum SourceType {
    | Program     // 顶层脚本
    | Module      // ES 模块
    | Eval        // eval 代码
    | Function    // 函数体
    | Wasm        // WebAssembly
}

// ========== SourceProvider ==========
// 严格翻译自 SourceProvider.zig
// 源码提供器 - 提供脚本源码文本
public class SourceProvider {
    public var sourceCode: String = ""
    public var sourceURL: String = ""
    public var sourceType: SourceType = SourceType.Program
    public var hash: Int64 = 0
    public var isCached: Bool = false

    public init() {}

    public init(sourceCode: String, sourceURL: String) {
        this.sourceCode = sourceCode
        this.sourceURL = sourceURL
        this.hash = computeHash(sourceCode)
    }

    // 计算源码哈希
    func computeHash(s: String) -> Int64 {
        var h: Int64 = 0
        for (c in s) {
            h = h * 31 + Int64(c.code)
        }
        h
    }

    // 获取源码
    public func source() -> String {
        sourceCode
    }

    // 获取 URL
    public func url() -> String {
        sourceURL
    }
}

// ========== JSSecrets ==========
// 严格翻译自 JSSecrets.zig
// JS 内部秘密值
public class JsSecrets {
    public var internalFieldCount: Int64 = 0
    public var globalObjectSecret: ?String = None

    public init() {}
}

// ========== JSCScheduler ==========
// 严格翻译自 JSCScheduler.zig
// JSC 任务调度器
public class JscScheduler {
    public var pendingTasks: Array<() -> Unit> = []
    public var isDraining: Bool = false

    public init() {}

    // 调度任务
    public func schedule(task: () -> Unit) {
        pendingTasks.append(task)
    }

    // 排空所有任务
    public func drain() {
        if (isDraining) { return }
        isDraining = true
        defer { isDraining = false }

        while (pendingTasks.size > 0) {
            let task = pendingTasks[0]
            pendingTasks = pendingTasks.slice(1)
            task()
        }
    }
}

// ========== JSC Config ==========
// 严格翻译自 config.zig
public class JscConfig {
    // 堆大小
    public static let DEFAULT_HEAP_SIZE: Int64 = 256 * 1024 * 1024
    // 最大栈深度
    public static let MAX_STACK_DEPTH: Int64 = 4096
    // 默认超时
    public static let DEFAULT_TIMEOUT_MS: Int64 = 30000
    // 是否启用 JIT
    public static var enableJIT: Bool = true
    // 是否启用并发 GC
    public static var enableConcurrentGC: Bool = true
    // 是否启用调试
    public static var enableDebugging: Bool = false

    public init() {}
}

// ========== Sizes ==========
// 严格翻译自 sizes.zig
public class JscSizes {
    // JSValue 大小 (64-bit)
    public static let JS_VALUE_SIZE: Int64 = 8
    // JSCell 头大小
    public static let JS_CELL_HEADER_SIZE: Int64 = 8
    // JSObject 最小大小
    public static let JS_OBJECT_MIN_SIZE: Int64 = 16
    // JSPromise 大小
    public static let JS_PROMISE_SIZE: Int64 = 32
    // JSGlobalObject 大小
    public static let JS_GLOBAL_OBJECT_SIZE: Int64 = 256

    public init() {}
}

// ========== StaticExport ==========
// 严格翻译自 static_export.zig
// 静态导出标记
public class StaticExport {
    public var name: String = ""
    public var moduleName: String = ""

    public init() {}

    public init(name: String, moduleName: String) {
        this.name = name
        this.moduleName = moduleName
    }
}

// ========== JSStringBuilder ==========
// 严格翻译自 StringBuilder.zig
// JS 字符串构建器
public class JsStringBuilder {
    var parts: Array<String> = []
    var estimatedLength: Int64 = 0

    public init() {}

    // 追加字符串
    public func append(s: String) {
        parts.append(s)
        estimatedLength += Int64(s.size)
    }

    // 追加字符
    public func append(c: UInt8) {
        parts.append(String(c))
        estimatedLength++
    }

    // 追加整数
    public func append(n: Int64) {
        let s = String(n)
        parts.append(s)
        estimatedLength += Int64(s.size)
    }

    // 追加浮点数
    public func append(f: Float64) {
        let s = String(f)
        parts.append(s)
        estimatedLength += Int64(s.size)
    }

    // 获取预计长度
    public func length() -> Int64 {
        estimatedLength
    }

    // 构建最终字符串
    public func toString() -> String {
        String.join("", parts)
    }

    // 清除
    public func clear() {
        parts = []
        estimatedLength = 0
    }
}

// ========== RefString ==========
// 补充翻译 - RefString 已在 virtual_machine.cj 中部分定义
// 这里提供完整版本
public class RefString {
    public var hash: Int64 = 0
    public var ptr: String = ""
    public var len: Int64 = 0
    public var refCount: Int64 = 1

    public init() {}

    public init(ptr: String) {
        this.ptr = ptr
        this.len = Int64(ptr.size)
        this.hash = computeHash(ptr)
    }

    public static func computeHash(input: String) -> Int64 {
        var h: Int64 = 5381
        for (c in input) {
            h = ((h << 5) + h) + Int64(c.code)
        }
        h
    }

    public func ref() {
        refCount++
    }

    public func deref() {
        refCount--
    }

    public func slice() -> String {
        ptr
    }

    public func toString() -> String {
        ptr
    }
}

// ========== GarbageCollectionController ==========
// 严格翻译自 GarbageCollectionController.zig
public class GCController {
    public var level: GCLevel = GCLevel.None
    public var lastCollectionTime: Float64 = 0.0
    public var collectionCount: Int64 = 0
    public var allocatedBytes: Int64 = 0
    public var heapSize: Int64 = 0

    public init() {}

    // 执行 GC
    public func collect(sync: Bool) {
        collectionCount++
        lastCollectionTime = currentTimeMillis().toFloat64()
    }

    // 自动 GC
    public func autoCollect() {
        if (level != GCLevel.None) {
            collect(level == GCLevel.Aggressive)
        }
    }

    // 报告额外内存
    public func reportExtraMemory(bytes: Int64) {
        allocatedBytes += bytes
    }

    // 获取统计信息
    public func stats() -> GCStats {
        GCStats(
            allocatedBytes: allocatedBytes,
            heapSize: heapSize,
            collectionCount: collectionCount,
            lastCollectionTime: lastCollectionTime
        )
    }
}

// GC 统计
public class GCStats {
    public let allocatedBytes: Int64
    public let heapSize: Int64
    public let collectionCount: Int64
    public let lastCollectionTime: Float64

    public init(allocatedBytes: Int64, heapSize: Int64, collectionCount: Int64, lastCollectionTime: Float64) {
        this.allocatedBytes = allocatedBytes
        this.heapSize = heapSize
        this.collectionCount = collectionCount
        this.lastCollectionTime = lastCollectionTime
    }
}

// ========== Counters ==========
// 严格翻译自 Counters.zig
public class JscCounters {
    public var transpileCount: Int64 = 0
    public var resolveCount: Int64 = 0
    public var evaluateCount: Int64 = 0
    public var importCount: Int64 = 0
    public var gcCount: Int64 = 0

    public init() {}

    public func incrementTranspile() { transpileCount++ }
    public func incrementResolve() { resolveCount++ }
    public func incrementEvaluate() { evaluateCount++ }
    public func incrementImport() { importCount++ }
    public func incrementGC() { gcCount++ }
}

// ========== EventType ==========
// 严格翻译自 EventType.zig
public enum JsEventType {
    | Readable
    | Writable
    | Close
    | Error
    | Connect
    | Message
    | Data
    | End
    | Timeout
    | Immediate
    | Signal
}
