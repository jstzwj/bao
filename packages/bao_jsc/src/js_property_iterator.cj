// 严格翻译自: src/jsc/SourceProvider.zig + SourceType.zig + ResolvedSource.zig +
//   ScriptExecutionStatus.zig + JSSecrets.zig + JSCScheduler.zig +
//   config.zig + sizes.zig + static_export.zig + StringBuilder.zig
// JavaScriptCore 配置、源码提供器和调度器

package bao_jsc

// 注意: SourceType 已移至 source_type.cj

// 注意: SourceProvider 已移至 zig_stack_trace.cj

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
        pendingTasks = pendingTasks.concat([task])
    }

    // 排空所有任务
    public func drain() {
        if (isDraining) { return }
        isDraining = true
        // defer: { isDraining = false }

        while (pendingTasks.size > 0) {
            let task = pendingTasks[0]
            pendingTasks = pendingTasks.slice(1, pendingTasks.size)
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
        parts = parts.concat([s])
        estimatedLength += Int64(s.size)
    }

    // 追加字符
    public func append(c: UInt8) {
        parts = parts.concat([String(Rune(c))])
        estimatedLength++
    }

    // 追加整数
    public func append(n: Int64) {
        let s = n.toString()
        parts = parts.concat([s])
        estimatedLength += Int64(s.size)
    }

    // 追加浮点数
    public func append(f: Float64) {
        let s = f.toString()
        parts = parts.concat([s])
        estimatedLength += Int64(s.size)
    }

    // 获取预计长度
    public func length(): Int64 {
        estimatedLength
    }

    // 构建最终字符串
    public func toString(): String {
        var result = ""
        for (p in parts) {
            result = result + p
        }
        result
    }

    // 清除
    public func clear() {
        parts = []
        estimatedLength = 0
    }
}

// 注意: RefString 已移至 ref_string.cj

// 注意: GCController 已移至 gc_controller.cj (or virtual_machine.cj)

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

// 注意: JscCounters 已移至 package.cj (type alias to Counters)

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
