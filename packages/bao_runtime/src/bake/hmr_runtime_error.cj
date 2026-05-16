// 翻译自 Bun: src/runtime/bake/hmr-runtime-error.ts
// 当发生 bundling 错误时，无法加载任何用户代码，
// 因为这些代码期望 SSR 步骤成功。
// 此版本的客户端仅打开一个 WebSocket 并仅监听错误解决事件，
// 然后重新加载页面。

package bao_runtime.bake

// ============================================================================
// HMR 错误运行时
// 对应 Bun: hmr-runtime-error.ts
// ============================================================================

/// 错误运行时配置 — 由 DevServer 注入
public class ErrorRuntimeConfig {
    public init() {}
}

/// 初始化错误运行时
/// 此运行时仅用于显示 bundling 错误和监听错误解决事件。
/// 对应 Bun: hmr-runtime-error.ts 中的立即执行代码块
public func initErrorRuntime(error: Array<Byte>): Unit {
    // 解析错误数据
    let reader = DataViewReader(error, 0)
    while (reader.hasMoreData()) {
        try {
            decodeAndAppendServerError(reader)
        } catch (e) {
            console.error(e.toString())
            break
        }
    }
    // updateErrorOverlay()
}

/// 处理版本消息
/// 对应 Bun: hmr-runtime-error.ts 中的版本消息处理
public func onVersionMessage(firstVersionPacket: Bool): Unit {
    // 首次版本包不需要重新加载
    // 后续版本包意味着服务器可能已重启，需要重新加载
    if (!firstVersionPacket) {
        // location.reload()
    }
}

/// 处理错误消息
/// 对应 Bun: hmr-runtime-error.ts 中的错误消息处理
public func onErrorRuntimePayload(view: Array<Byte>): Unit {
    let reader = DataViewReader(view, 1)
    let removedCount = reader.u32()

    for (_ in 0..removedCount) {
        let removed = reader.u32()
        // 从构建错误列表中移除
    }

    while (reader.hasMoreData()) {
        try {
            decodeAndAppendServerError(reader)
        } catch (e) {
            console.error(e.toString())
            break
        }
    }

    // updateErrorOverlay()
}

/// 解码并追加服务器端错误
func decodeAndAppendServerError(r: DataViewReader): Unit {
    let owner = r.u32()
    let file = r.string32()
    let messageCount = r.u32()

    var messages: Array<BundlerMessage> = []
    for (_ in 0..messageCount) {
        messages.append(decodeSerializedError(r))
    }

    // 存储到构建错误列表
}

/// 解码序列化错误
func decodeSerializedError(reader: DataViewReader): BundlerMessage {
    let kind = reader.u8()
    if (kind <= 4) {
        return readLogMsg(reader, BundlerMessageLevel.fromInt(kind))
    }
    // JS 错误的简化处理
    return BundlerMessage(
        kind: "bundler",
        level: BundlerMessageLevel.err,
        message: "Unknown error",
        location: None,
        notes: [],
    )
}

/// 读取日志消息
func readLogMsg(r: DataViewReader, level: BundlerMessageLevel): BundlerMessage {
    let message = r.string32()
    let location = readBundlerMessageLocationOrNull(r)
    let noteCount = r.u32()
    var notes: Array<BundlerNote> = []
    for (_ in 0..noteCount) {
        notes.append(readLogData(r))
    }
    return BundlerMessage(
        kind: "bundler",
        level: level,
        message: message,
        location: location,
        notes: notes,
    )
}

/// 读取日志数据
func readLogData(r: DataViewReader): BundlerNote {
    return BundlerNote(
        message: r.string32(),
        location: readBundlerMessageLocationOrNull(r),
    )
}

/// 读取 BundlerMessageLocation 或 null
func readBundlerMessageLocationOrNull(r: DataViewReader): ?BundlerMessageLocation {
    let line = r.u32()
    if (line == 0) {
        return None
    }
    let column = r.u32()
    let length = r.u32()
    let lineText = r.string32()
    return Some(BundlerMessageLocation(
        line: line,
        column: column,
        length: length,
        lineText: lineText,
    ))
}

// ============================================================================
// 类型定义
// ============================================================================

/// Bundler 消息
public class BundlerMessage {
    public var kind: String
    public var level: BundlerMessageLevel
    public var message: String
    public var location: ?BundlerMessageLocation
    public var notes: Array<BundlerNote>

    public init(kind: String, level: BundlerMessageLevel, message: String, location: ?BundlerMessageLocation, notes: Array<BundlerNote>) {
        this.kind = kind
        this.level = level
        this.message = message
        this.location = location
        this.notes = notes
    }
}

/// Bundler 消息位置
public class BundlerMessageLocation {
    /// 行号 (1-based)
    public var line: UInt32
    /// 列号 (1-based)
    public var column: UInt32
    /// 长度 (字节)
    public var length: UInt32
    /// 行文本
    public var lineText: String

    public init(line: UInt32, column: UInt32, length: UInt32, lineText: String) {
        this.line = line
        this.column = column
        this.length = length
        this.lineText = lineText
    }
}

/// Bundler 注释
public class BundlerNote {
    public var message: String
    public var location: ?BundlerMessageLocation

    public init(message: String, location: ?BundlerMessageLocation) {
        this.message = message
        this.location = location
    }
}

/// 反序列化的失败信息
public class DeserializedFailure {
    /// 如果未指定，则为客户端错误
    public var file: ?String
    public var messages: Array<BundlerMessage>

    public init(file: ?String, messages: Array<BundlerMessage>) {
        this.file = file
        this.messages = messages
    }
}

/// DataViewReader 类型引用
public type DataViewReader = hmr_runtime_client.DataViewReader
