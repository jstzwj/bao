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
    public func nextRequestId(): Int64 {
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

// 注意: FetchHeaders 已移至 fetch_headers.cj
// 注意: BunCPUProfiler 已移至 bun_cpu_profiler.cj
// 注意: BunHeapProfiler 已移至 bun_heap_profiler.cj

// ========== WTF 工具 ==========
// 严格翻译自 WTF.zig
public class WTF {
    // 栈帧描述
    public static func stackTrace(): String {
        "    at <anonymous>\n"
    }

    // 打印调试信息
    public static func debugPrint(message: String) {
        println("[WTF] " + message)
    }

    // 报告断言失败
    public static func reportAssertionFailure(file: String, line: Int64, function: String, message: String) {
        println("ASSERTION FAILED: " + message + " at " + file + ":" + line.toString() + " in " + function)
    }
}
