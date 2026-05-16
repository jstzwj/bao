// 翻译自 Bun: src/runtime/bake/hmr-runtime-client.ts
// HMR 客户端运行时入口点。
// 在浏览器中，使用 WebSocket 与 bundler 通信。

package bao_runtime.bake

import bao_collections.*

// ============================================================================
// HMR 客户端运行时
// 对应 Bun: hmr-runtime-client.ts
// ============================================================================

/// HMR 客户端配置 — 由 DevServer 注入
public class HmrClientConfig {
    public var version: String
    public var generation: UInt64
    public var main: String
    public var refresh: ?String = None
    public var console_: Bool = false
    public var bun: String = ""

    public init(version: String, generation: UInt64, main: String) {
        this.version = version
        this.generation = generation
        this.main = main
    }
}

/// HMR 客户端运行时
/// 管理 WebSocket 连接、热更新处理和服务器端代码重载
public class HmrRuntimeClient {
    /// 是否正在执行路由重载
    private var isPerformingRouteReload: Bool = false
    /// 是否需要再执行一次路由重载
    private var shouldPerformAnotherRouteReload: Bool = false
    /// 当前路由索引
    private var currentRouteIndex: Int64 = -1
    /// 是否为首次运行
    private var isFirstRun: Bool = true
    /// 配置
    private var config: HmrClientConfig

    public init(config: HmrClientConfig) {
        this.config = config
    }

    // ========================================================================
    // 路由重载
    // ========================================================================

    /// 执行路由重载
    /// 对应 Bun: hmr-runtime-client.ts performRouteReload()
    public func performRouteReload(): Promise<Unit> {
        console.info("[Bun] Server-side code changed, reloading!")
        if (isPerformingRouteReload) {
            shouldPerformAnotherRouteReload = true
            return Promise.unit()
        }

        if (onServerSideReload != None) {
            isPerformingRouteReload = true
            return onServerSideReload.get()().then({ (_) =>
                var shouldContinue = true
                while (shouldContinue) {
                    shouldContinue = shouldPerformAnotherRouteReload
                    shouldPerformAnotherRouteReload = false
                    if (shouldContinue) {
                        return onServerSideReload.get()()
                    }
                }
                isPerformingRouteReload = false
                Promise.unit()
            }).catch({ (err) =>
                console.error("Failed to perform Server-side reload.")
                console.error(err.toString())
                console.error("The page will hard-reload now.")
                fullReload()
                Promise.unit()
            })
        }

        // 后备方案：当重载失败或框架未实现时，完全重载
        fullReload()
        return Promise.unit()
    }

    // ========================================================================
    // 版本消息处理
    // 对应 Bun: hmr-runtime-client.ts handlers[MessageId.version]
    // ========================================================================

    /// 处理版本消息
    public func onVersionMessage(view: Array<Byte>): Unit {
        let versionStr = td.decode(view.slice(1))
        if (versionStr != config.version) {
            console.error("Version mismatch, hard-reloading")
            fullReload()
            return
        }

        if (isFirstRun) {
            isFirstRun = false
        } else {
            // 重新连接时完全重载
            fullReload()
            return
        }
    }

    // ========================================================================
    // 热更新消息处理
    // 对应 Bun: hmr-runtime-client.ts handlers[MessageId.hot_update]
    // ========================================================================

    /// 处理热更新消息
    public func onHotUpdateMessage(view: Array<Byte>): Unit {
        let reader = DataViewReader(view, 1)

        // List 1: 服务器端路由更新
        let serverSideRoutesUpdated: HashSet<Int64> = HashSet<Int64>()
        var routeId = reader.i32()
        while (routeId != -1) {
            serverSideRoutesUpdated.add(routeId)
            routeId = reader.i32()
        }

        // List 2: 路由特定更新
        var isServerSideRouteUpdate = false
        routeId = reader.i32()
        while (routeId != -1) {
            if (routeId == currentRouteIndex) {
                isServerSideRouteUpdate = serverSideRoutesUpdated.contains(routeId)
                let cssCount = reader.i32()
                if (cssCount != -1) {
                    var cssArray: Array<String> = []
                    for (_ in 0..cssCount) {
                        cssArray.append(reader.stringWithLength(16))
                    }
                    // editCssArray(cssArray) — CSS 热重载
                }
                break
            } else {
                // 跳到下一个路由
                let cssCount = reader.i32()
                if (cssCount > 0) {
                    reader.skip(cssCount * 16)
                }
            }
            routeId = reader.i32()
        }

        // List 3: CSS 内容更新
        var cssUpdateCount = reader.u32()
        while (cssUpdateCount > 0) {
            cssUpdateCount -= 1
            let identifier = reader.stringWithLength(16)
            let code = reader.string32()
            // editCssContent(identifier, code) — CSS 内容更新
        }

        if (isServerSideRouteUpdate) {
            performRouteReload()
            return
        }

        // JavaScript 模块更新
        if (reader.hasMoreData()) {
            let sourceMapSize = reader.u32()
            // 处理 source map 和模块替换
        }
    }

    // ========================================================================
    // 设置 URL 响应
    // ========================================================================

    /// 处理设置 URL 响应
    public func onSetUrlResponse(view: Array<Byte>): Unit {
        let reader = DataViewReader(view, 1)
        currentRouteIndex = reader.u32()
    }

    // ========================================================================
    // 错误处理
    // ========================================================================

    /// 处理 HMR 加载错误
    public func onHmrLoadError(event: Any, source: ?String = None, lineno: ?Int64 = None, colno: ?Int64 = None, error: ?Any = None): Unit {
        if (error != None) {
            console.error(error.get().toString())
        } else {
            console.error("Failed to load HMR script")
        }
        fullReload()
    }

    // ========================================================================
    // 初始化
    // ========================================================================

    /// 初始化并加载用户代码
    public func start(): Promise<Unit> {
        // 加载刷新运行时
        if (config.refresh != None) {
            let refreshModule = loadModuleAsync(config.refresh.get(), false, None)
            // 设置刷新运行时
        }

        // 加载主模块
        let mainLoad = loadModuleAsync(config.main, false, None)
        emitEvent("bun:ready", None)

        return Promise.unit()
    }
}

// ============================================================================
// DataViewReader — 二进制数据读取器
// 对应 Bun: client/data-view.ts DataViewReader
// ============================================================================

/// 二进制数据读取器
public class DataViewReader {
    private var view: Array<Byte>
    public var cursor: Int64

    public init(view: Array<Byte>, cursor: Int64 = 0) {
        this.view = view
        this.cursor = cursor
    }

    /// 读取 UInt32 (小端序)
    public func u32(): UInt32 {
        let value = UInt32(view[cursor])
            | (UInt32(view[cursor + 1]) << 8)
            | (UInt32(view[cursor + 2]) << 16)
            | (UInt32(view[cursor + 3]) << 24)
        cursor += 4
        return value
    }

    /// 读取 Int32 (小端序)
    public func i32(): Int32 {
        let value = Int32(view[cursor])
            | (Int32(view[cursor + 1]) << 8)
            | (Int32(view[cursor + 2]) << 16)
            | (Int32(view[cursor + 3]) << 24)
        cursor += 4
        return value
    }

    /// 读取 UInt16 (小端序)
    public func u16(): UInt16 {
        let value = UInt16(view[cursor]) | (UInt16(view[cursor + 1]) << 8)
        cursor += 2
        return value
    }

    /// 读取 UInt8
    public func u8(): UInt8 {
        let value = view[cursor]
        cursor += 1
        return value
    }

    /// 读取指定长度的字符串
    public func stringWithLength(byteLength: Int64): String {
        let bytes = view.slice(cursor, cursor + byteLength)
        cursor += byteLength
        return td.decode(bytes)
    }

    /// 读取以长度前缀的字符串
    public func string32(): String {
        return stringWithLength(u32())
    }

    /// 是否还有更多数据
    public func hasMoreData(): Bool {
        return cursor < view.length
    }

    /// 获取剩余数据
    public func rest(): Array<Byte> {
        return view.slice(cursor)
    }

    /// 跳过指定字节数
    public func skip(count: Int64): Unit {
        cursor += count
    }
}

// ============================================================================
// DataViewWriter — 二进制数据写入器
// 对应 Bun: client/data-view.ts DataViewWriter
// ============================================================================

/// 二进制数据写入器
public class DataViewWriter {
    private var view: Array<Byte>
    public var cursor: Int64
    private var capacity: Int64

    public static func initCapacity(capacity: Int64): DataViewWriter {
        return DataViewWriter(view: Array<Byte>(capacity), cursor: 0, capacity: capacity)
    }

    public init(view: Array<Byte>, cursor: Int64, capacity: Int64) {
        this.view = view
        this.cursor = cursor
        this.capacity = capacity
    }

    /// 写入 UInt8
    public func u8(value: UInt8): Unit {
        view[cursor] = value
        cursor += 1
    }

    /// 写入 UInt32 (小端序)
    public func u32(value: UInt32): Unit {
        view[cursor] = Byte(value & 0xFF)
        view[cursor + 1] = Byte((value >> 8) & 0xFF)
        view[cursor + 2] = Byte((value >> 16) & 0xFF)
        view[cursor + 3] = Byte((value >> 24) & 0xFF)
        cursor += 4
    }

    /// 写入 Int32 (小端序)
    public func i32(value: Int32): Unit {
        u32(UInt32(value))
    }

    /// 写入字符串
    public func string(value: String): Unit {
        if (value.isEmpty()) {
            return
        }
        let bytes = te.encode(value)
        for (b in bytes) {
            view[cursor] = b
            cursor += 1
        }
    }

    /// 写入以长度前缀的字符串
    public func stringWithLength(value: String): Unit {
        let savedCursor = cursor
        u32(0) // 占位
        string(value)
        let length = cursor - savedCursor - 4
        view[savedCursor] = Byte(length & 0xFF)
        view[savedCursor + 1] = Byte((length >> 8) & 0xFF)
        view[savedCursor + 2] = Byte((length >> 16) & 0xFF)
        view[savedCursor + 3] = Byte((length >> 24) & 0xFF)
    }

    /// 获取底层缓冲区
    public func buffer(): Array<Byte> {
        return view.slice(0, cursor)
    }
}
