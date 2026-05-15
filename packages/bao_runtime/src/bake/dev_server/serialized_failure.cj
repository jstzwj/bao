// 翻译自 Bun: src/runtime/bake/DevServer/SerializedFailure.zig
// 发送到浏览器中 HMR 客户端的错误是序列化的。
// 相同的格式用于抛出的 JavaScript 异常以及 bundler 错误。
// 序列化失败包含文件或路由来源的句柄，
// 允许 bundler 通过索引消除或更新过期的失败，而不是重新发送新的载荷。

package bao_runtime.bake.dev_server

/// 序列化失败 - 发送到 HMR 客户端的序列化错误
public struct Packed <: UInt32 {
    public var data: UInt30
    public var kind: OwnerKind
}

public enum OwnerKind <: UInt2 {
    | none
    | route
    | client
    | server
}

public class ArrayHashContextViaOwner {
    public static func hash(k: SerializedFailure): UInt32 {
        return std.hash.int(bitCast<UInt32>(k.getOwner().encode()))
    }

    public static func eql(a: SerializedFailure, b: SerializedFailure): Bool {
        return bitCast<UInt32>(a.getOwner().encode()) == bitCast<UInt32>(b.getOwner().encode())
    }
}

public class ArrayHashAdapter {
    public static func hash(own: Owner): UInt32 {
        return std.hash.int(bitCast<UInt32>(own.encode()))
    }

    public static func eql(a: Owner, b: SerializedFailure): Bool {
        return bitCast<UInt32>(a.encode()) == bitCast<UInt32>(b.getOwner().encode())
    }
}

public enum ErrorKind {
    | None
}

public class SerializedFailure {
    /// 序列化数据始终由 dev.allocator() 拥有
    /// 前 32 位包含所有者信息
    public var data: Array<Byte>

    /// 析构
    public func deinit(dev: DevServer): Unit {
        dev.allocator().free(data)
    }

    /// 增量文件错误的隐喻所有者。打包变体作为不透明句柄给 HMR 运行时。
    public enum Owner {
        | none
        | route(RouteBundle.Index)
        | client(IncrementalGraphClientFileIndex)
        | server(IncrementalGraphServerFileIndex)

        /// 编码为 Packed
        public func encode(): Packed {
            return match (this) {
                | none => Packed(kind: OwnerKind.none, data: 0)
                | client(let data) => Packed(kind: OwnerKind.client, data: data.get())
                | server(let data) => Packed(kind: OwnerKind.server, data: data.get())
                | route(let data) => Packed(kind: OwnerKind.route, data: data.get())
            }
        }
    }

    /// 打包的所有者信息

    /// 所有者种类

    /// 获取所有者
    public func getOwner(): Owner {
        let packed: Packed = bitCast<Packed>(data[0..4])
        return match (packed.kind) {
            | none => Owner.none
            | client => Owner.client(IncrementalGraphClientFileIndex.init(packed.data))
            | server => Owner.server(IncrementalGraphServerFileIndex.init(packed.data))
            | route => Owner.route(RouteBundle.Index.init(packed.data))
        }
    }

    /// 通过所有者的数组哈希上下文

    /// 通过所有者的数组哈希适配器

    /// 错误种类

    /// 从日志初始化
    public static func initFromLog(
        dev: DevServer,
        owner: Owner,
        owner_display_name: String,
        messages: Array<LogMsg>,
    ): SerializedFailure {
        assert(messages.length > 0)

        var payload: ArrayList<Byte> = ArrayList<Byte>.initCapacity(dev.allocator(), 65536)
        let w = payload.writer()

        // 写入所有者
        w.writeInt(UInt32, bitCast<UInt32>(owner.encode()))
        // 写入显示名称
        writeString32(owner_display_name, w)
        // 写入消息数量
        w.writeInt(UInt32, messages.length)
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
            | err => ErrorKind.bundler_log_err
            | warn => ErrorKind.bundler_log_warn
            | note => ErrorKind.bundler_log_note
            | debug => ErrorKind.bundler_log_debug
            | verbose => ErrorKind.bundler_log_verbose
        })
        writeLogData(msg.data, w)
        w.writeInt(UInt32, msg.notes.length)
        for (note in msg.notes) {
            writeLogData(note, w)
        }
    }

    /// 写入日志数据
    static func writeLogData(data: LogData, w: Writer): Unit {
        writeString32(data.text, w)
        if (let Some(loc) = data.location) {
            if (loc.line < 0) {
                w.writeInt(UInt32, 0)
                return
            }
            w.writeInt(Int32, loc.line)
            w.writeInt(UInt32, loc.column)
            w.writeInt(UInt32, loc.length)
            writeString32(loc.line_text ?? "", w)
        } else {
            w.writeInt(UInt32, 0)
        }
    }

    /// 写入长度前缀字符串
    static func writeString32(data: String, w: Writer): Unit {
        w.writeInt(UInt32, data.length)
        w.writeAll(data)
    }
}

// 类型别名
public type ArrayList<T> = std.ArrayList<T>
public type Writer = std.ArrayList<Byte>.Writer
public type RouteBundle = dev_server.RouteBundle
public type IncrementalGraphClientFileIndex = incremental_graph.IncrementalGraph(.client).FileIndex
public type IncrementalGraphServerFileIndex = incremental_graph.IncrementalGraph(.server).FileIndex
public type LogMsg = bun.logger.Msg
public type LogData = bun.logger.Data
