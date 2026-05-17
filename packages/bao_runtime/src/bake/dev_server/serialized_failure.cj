// 翻译自 Bun: src/runtime/bake/DevServer/SerializedFailure.zig
// 发送到浏览器中 HMR 客户端的错误是序列化的。
// 相同的格式用于抛出的 JavaScript 异常以及 bundler 错误。
// 序列化失败包含文件或路由来源的句柄，
// 允许 bundler 通过索引消除或更新过期的失败，而不是重新发送新的载荷。

package bao_runtime.bake.dev_server

/// 序列化失败 - 发送到 HMR 客户端的序列化错误
public struct Packed {
    public var value: UInt32
    public var data: UInt30
    public var kind: SerializedFailureOwnerKind
}

public enum SerializedFailureOwnerKind {
    | none
    | route
    | client
    | server
}

public class ArrayHashContextViaSerializedFailureOwner {
    public static func hash(k: SerializedFailure): UInt32 {
        return std.hash.int(bitCast<UInt32>(k.getSerializedFailureOwner().encode()))
    }

    public static func eql(a: SerializedFailure, b: SerializedFailure): Bool {
        return bitCast<UInt32>(a.getSerializedFailureOwner().encode()) == bitCast<UInt32>(b.getSerializedFailureOwner().encode())
    }
}

public class ArrayHashAdapter {
    public static func hash(own: SerializedFailureOwner): UInt32 {
        return std.hash.int(bitCast<UInt32>(own.encode()))
    }

    public static func eql(a: SerializedFailureOwner, b: SerializedFailure): Bool {
        return bitCast<UInt32>(a.encode()) == bitCast<UInt32>(b.getSerializedFailureOwner().encode())
    }
}

public enum ErrorKind {
    | None
}

public enum SerializedFailureOwner {
    | none
    | route(RouteBundle.Index)
    | client(IncrementalGraphClientFileIndex)
    | server(IncrementalGraphServerFileIndex)

    public func encode(): Packed {
        return match (this) {
            case none => Packed(kind: SerializedFailureOwnerKind.none, data: 0)
            case client(data) => Packed(kind: SerializedFailureOwnerKind.client, data: data.get())
            case server(data) => Packed(kind: SerializedFailureOwnerKind.server, data: data.get())
            case route(data) => Packed(kind: SerializedFailureOwnerKind.route, data: data.get())
        }
    }
}

public class SerializedFailure {
    /// 序列化数据始终由 dev.allocator() 拥有
    /// 前 32 位包含所有者信息
    public var data: Array<Byte>

    /// 析构
    public func deinit(dev: DevServer): Unit {
        dev.allocator().free(data)
    }


    /// 打包的所有者信息

    /// 所有者种类

    /// 获取所有者
    public func getSerializedFailureOwner(): SerializedFailureOwner {
        let packed: Packed = bitCast<Packed>(data[0..4])
        return match (packed.kind) {
            case none => SerializedFailureOwner.none
            case client => SerializedFailureOwner.client(IncrementalGraphClientFileIndex.`init`(packed.data))
            case server => SerializedFailureOwner.server(IncrementalGraphServerFileIndex.`init`(packed.data))
            case route => SerializedFailureOwner.route(RouteBundle.Index.`init`(packed.data))
        }
    }

    /// 通过所有者的数组哈希上下文

    /// 通过所有者的数组哈希适配器

    /// 错误种类

    /// 从日志初始化
    public static func initFromLog(
        dev: DevServer,
        owner: SerializedFailureOwner,
        owner_display_name: String,
        messages: Array<LogMsg>
    ): SerializedFailure {
        assert(messages.length > 0)

        var payload: ArrayList<Byte> = ArrayList<Byte>.initCapacity(dev.allocator(), 65536)
        let w = payload.writer()

        // 写入所有者
        w.writeInt(bitCast<UInt32>(owner.encode()))
        // 写入显示名称
        writeString32(owner_display_name, w)
        // 写入消息数量
        w.writeInt(messages.length)
        // 写入每条消息
        for (msg in messages) {
            writeLogMsg(msg, w)
        }

        let result_data = payload.items
        return SerializedFailure(data: result_data)
    }

    /// 写入日志消息
    static func writeLogMsg(msg: LogMsg, w: Writer): Unit {
        w.writeByte(match (msg.kind) {
            case err => ErrorKind.bundler_log_err
            case warn => ErrorKind.bundler_log_warn
            case note => ErrorKind.bundler_log_note
            case debug => ErrorKind.bundler_log_debug
            case verbose => ErrorKind.bundler_log_verbose
        })
        writeLogData(msg.data, w)
        w.writeInt(msg.notes.length)
        for (note in msg.notes) {
            writeLogData(note, w)
        }
    }

    /// 写入日志数据
    static func writeLogData(data: LogData, w: Writer): Unit {
        writeString32(data.text, w)
        if (let Some(loc) <- data.location) {
            if (loc.line < 0) {
                w.writeInt(0)
                return
            }
            w.writeInt(loc.line)
            w.writeInt(loc.column)
            w.writeInt(loc.length)
            writeString32(loc.line_text ?? "", w)
        } else {
            w.writeInt(0)
        }
    }

    /// 写入长度前缀字符串
    static func writeString32(data: String, w: Writer): Unit {
        w.writeInt(data.length)
        w.writeAll(data)
    }
}

// 类型别名
public type ArrayList<T> = std.ArrayList<T>
public type Writer = std.ArrayList<Byte>.Writer
public type IncrementalGraphServerFileIndex = FileIndex
public type LogMsg = bun.logger.Msg
public type LogData = bun.logger.Data
