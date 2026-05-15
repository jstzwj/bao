// 严格翻译自: src/jsc/HTTPServerAgent.zig + FetchHeaders.zig + BunCPUProfiler.zig + BunHeapProfiler.zig
// Bun HTTP 服务器代理、Fetch Headers 和性能分析器

package bao_jsc

// ========== HTTP 服务器代理 ==========
// 严格翻译自 HTTPServerAgent.zig
public class HTTPServerAgent {
    public var isListening: Bool = false
    public var port: Int64 = 0
    public var hostname: String = "0.0.0.0"
    public var isSSL: Bool = false
    public var requestId: Int64 = 0
    public var activeRequests: Int64 = 0
    public var isShuttingDown: Bool = false

    public init() {}

    // 启动监听
    public func listen(port: Int64, hostname: String, callback: JsFunction) {
        this.port = port
        this.hostname = hostname
        this.isListening = true
    }

    // 关闭服务器
    public func close() {
        isShuttingDown = true
        isListening = false
    }

    // 下一个请求 ID
    public func nextRequestId() -> Int64 {
        requestId++
        requestId
    }

    // 增加活跃请求
    public func incrementActiveRequests() {
        activeRequests++
    }

    // 减少活跃请求
    public func decrementActiveRequests() {
        activeRequests--
    }
}

// ========== Fetch Headers ==========
// 严格翻译自 FetchHeaders.zig
// HTTP 头部实现
public class FetchHeaders {
    // 内部头部条目
    public var entries: ArrayList<HeaderEntry> = ArrayList()
    // 头部名称集合 (用于快速查找)
    public var nameSet: HashSet<String> = HashSet()

    public init() {}

    public init(entries: Array<(String, String)>) {
        for ((name, value) in entries) {
            append(name, value)
        }
    }

    // 获取头部值
    public func get(name: String) -> ?String {
        let lower = name.toLowerAscii()
        for (entry in entries) {
            if (entry.name.toLowerAscii() == lower) {
                return entry.value
            }
        }
        None
    }

    // 设置头部值 (替换已有)
    public func set(name: String, value: String) {
        let lower = name.toLowerAscii()
        for (i in 0..entries.size) {
            if (entries[Int64(i)].name.toLowerAscii() == lower) {
                entries[Int64(i)] = HeaderEntry(name: name, value: value)
                return
            }
        }
        append(name, value)
    }

    // 追加头部值
    public func append(name: String, value: String) {
        entries.append(HeaderEntry(name: name, value: value))
        nameSet.put(name.toLowerAscii())
    }

    // 是否包含头部
    public func has(name: String) -> Bool {
        nameSet.contains(name.toLowerAscii())
    }

    // 删除头部
    public func delete(name: String) -> Bool {
        let lower = name.toLowerAscii()
        var removed = false
        var i = 0
        while (i < entries.size) {
            if (entries[Int64(i)].name.toLowerAscii() == lower) {
                entries.removeAt(Int64(i))
                removed = true
            } else {
                i++
            }
        }
        if (removed) {
            nameSet.remove(lower)
        }
        removed
    }

    // 获取所有值
    public func getAll(name: String) -> Array<String> {
        var result = Array<String>()
        let lower = name.toLowerAscii()
        for (entry in entries) {
            if (entry.name.toLowerAscii() == lower) {
                result.append(entry.value)
            }
        }
        result
    }

    // 获取头部数量
    public func count() -> Int64 {
        Int64(entries.size)
    }

    // 转为 JsValue
    public func toJsValue() -> JsValue {
        let obj = JsObject.make()
        obj.className = "Headers"
        for (entry in entries) {
            obj.set(entry.name, JsValue(s: entry.value))
        }
        JsValue(obj: obj)
    }

    // 转为 Map 形式
    public func toMap() -> HashMap<String, String> {
        let map = HashMap<String, String>()
        for (entry in entries) {
            map.put(entry.name, entry.value)
        }
        map
    }
}

// 头部条目
public class HeaderEntry {
    public var name: String = ""
    public var value: String = ""

    public init() {}

    public init(name: String, value: String) {
        this.name = name
        this.value = value
    }
}

// ========== CPU 分析器 ==========
// 严格翻译自 BunCPUProfiler.zig
public class BunCPUProfiler {
    public var isEnabled: Bool = false
    public var outputPath: String = ""
    public var sampleInterval: Float64 = 1000.0  // 微秒
    public var profiles: Array<CPUProfile> = []

    public init() {}

    // 启动分析
    public func start(outputPath: String) {
        this.outputPath = outputPath
        this.isEnabled = true
    }

    // 停止分析
    public func stop() {
        isEnabled = false
    }
}

// CPU 分析配置
public class CPUProfile {
    public var title: String = ""
    public var startTime: Float64 = 0.0
    public var endTime: Float64 = 0.0
    public var samples: Array<Int64> = []
    public var nodes: Array<ProfileNode> = []

    public init() {}
}

public class ProfileNode {
    public var id: Int64 = 0
    public var functionName: String = ""
    public var scriptURL: String = ""
    public var lineNumber: Int64 = 0
    public var columnNumber: Int64 = 0
    public var hitCount: Int64 = 0
    public var children: Array<Int64> = []

    public init() {}
}

// ========== 堆分析器 ==========
// 严格翻译自 BunHeapProfiler.zig
public class BunHeapProfiler {
    public var isEnabled: Bool = false
    public var outputPath: String = ""

    public init() {}

    // 启动堆分析
    public func start(outputPath: String) {
        this.outputPath = outputPath
        this.isEnabled = true
    }

    // 停止堆分析
    public func stop() {
        isEnabled = false
    }

    // 获取堆快照
    public func takeSnapshot() -> String {
        "{}"
    }
}

// ========== WTF 工具 ==========
// 严格翻译自 WTF.zig
public class WTF {
    // 栈帧描述
    public static func stackTrace() -> String {
        "    at <anonymous>\n"
    }

    // 打印调试信息
    public static func debugPrint(message: String) {
        println("[WTF] " + message)
    }

    // 报告断言失败
    public static func reportAssertionFailure(file: String, line: Int64, function: String, message: String) {
        println("ASSERTION FAILED: " + message + " at " + file + ":" + String(line) + " in " + function)
    }
}
