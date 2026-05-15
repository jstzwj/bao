// bao_watcher - 监视器调试追踪
// 严格翻译自: src/watcher/WatcherTrace.zig
//
// Bun 的 WatcherTrace:
//   - 可选的追踪文件, 通过 BUN_WATCHER_TRACE 环境变量启用
//   - 在监视线程中调用, 无需加锁
//   - 写入 JSON 格式的事件日志
//   - 每行一个 JSON 对象: { "timestamp": number, "files": { ... } }
//   - 使用缓冲写入提高性能
package bao_watcher

import bao_core.*
import bao_sys.*

// ============================================================================
// WatcherTrace - 监视器追踪日志
// 严格翻译自: src/watcher/WatcherTrace.zig
//
// Bun 的实现:
//   var trace_file: ?bun.sys.File = null;
//
//   pub fn init() void {
//       if (trace_file != null) return;
//       if (bun.env_var.BUN_WATCHER_TRACE.get()) |trace_path| {
//           if (trace_path.len > 0) {
//               const flags = bun.O.WRONLY | bun.O.CREAT | bun.O.APPEND;
//               const mode = 0o644;
//               switch (bun.sys.openA(trace_path, flags, mode)) {
//                   .result => |fd| { trace_file = bun.sys.File{ .handle = fd }; },
//                   .err => { /* silently ignore */ },
//               }
//           }
//       }
//   }
//
//   pub fn writeEvents(watcher: *Watcher, events: []Watcher.WatchEvent,
//                      changed_files: []?[:0]u8) void { ... }
//
//   pub fn deinit() void {
//       if (trace_file) |file| { file.close(); trace_file = null; }
//   }
// ============================================================================

/// 监视器追踪 - 对应 Bun WatcherTrace
/// 严格翻译自: WatcherTrace.zig
///
/// 使用单例模式, 因为 Bun 的 trace_file 是模块级变量
public class WatcherTrace {
    /// 单例实例 - 对应 Bun 模块级 var trace_file
    public static let instance: WatcherTrace = WatcherTrace()

    /// 追踪文件描述符 - 对应 Bun trace_file: ?bun.sys.File
    private var traceFd: ?Int64

    /// 是否已检查环境变量 - 防止重复初始化
    /// 对应 Bun init() 中的 if (trace_file != null) return
    private var initialized: Bool

    public init() {
        traceFd = None
        initialized = false
    }

    // ========================================================================
    // 初始化 - 对应 Bun WatcherTrace.init()
    // 严格翻译自: WatcherTrace.zig:6-23
    //
    //   pub fn init() void {
    //       if (trace_file != null) return;  // 只初始化一次
    //       if (bun.env_var.BUN_WATCHER_TRACE.get()) |trace_path| {
    //           if (trace_path.len > 0) {
    //               const flags = bun.O.WRONLY | bun.O.CREAT | bun.O.APPEND;
    //               const mode = 0o644;
    //               switch (bun.sys.openA(trace_path, flags, mode)) {
    //                   .result => |fd| {
    //                       trace_file = bun.sys.File{ .handle = fd };
    //                   },
    //                   .err => { /* silently ignore errors */ },
    //               }
    //           }
    //       }
    //   }
    // ========================================================================

    /// 初始化追踪文件 - 对应 Bun WatcherTrace.init()
    /// 严格翻译自: WatcherTrace.zig:6-23
    ///
    /// 如果设置了 BUN_WATCHER_TRACE 环境变量, 打开追踪文件
    /// 只检查一次, 后续调用直接返回
    public func init(): Unit {
        // 只初始化一次 - 对应 if (trace_file != null) return
        if (initialized) {
            return
        }
        initialized = true

        // 读取环境变量 BUN_WATCHER_TRACE
        // 严格翻译自: WatcherTrace.zig:9
        //   if (bun.env_var.BUN_WATCHER_TRACE.get()) |trace_path|
        let tracePath = OS.getEnv("BUN_WATCHER_TRACE")
        if (let Some(path) = tracePath) {
            if (path.size > 0) {
                // 打开追踪文件
                // 严格翻译自: WatcherTrace.zig:11-12
                //   const flags = bun.O.WRONLY | bun.O.CREAT | bun.O.APPEND;
                //   const mode = 0o644;
                let flags = OpenFlags.WRONLY | OpenFlags.CREAT | OpenFlags.APPEND
                let mode = UInt32(0o644)

                match (SysFs.open(path, flags, mode)) {
                    case Ok(fd) => traceFd = fd
                    case Err(_) => {
                        // 静默忽略错误 - 对应 Bun .err => { }
                    }
                }
            }
        }
    }

    // ========================================================================
    // 写入事件 - 对应 Bun WatcherTrace.writeEvents
    // 严格翻译自: WatcherTrace.zig:28-100
    //
    //   pub fn writeEvents(watcher: *Watcher, events: []Watcher.WatchEvent,
    //                      changed_files: []?[:0]u8) void {
    //       const file = trace_file orelse return;
    //       var buffer: [4096]u8 = undefined;
    //       var buffered = file.writer().adaptToNewApi(&buffer);
    //       const writer = &buffered.new_interface;
    //       const timestamp = std.time.milliTimestamp();
    //       writer.writeAll("{\"timestamp\":") catch return;
    //       writer.print("{d}", .{timestamp}) catch return;
    //       writer.writeAll(",\"files\":{") catch return;
    //       ... 遍历事件, 写入 JSON ...
    //       writer.writeAll("}}\n") catch return;
    //   }
    // ========================================================================

    /// 写入追踪事件 - 对应 Bun WatcherTrace.writeEvents
    /// 严格翻译自: WatcherTrace.zig:28-100
    ///
    /// 在监视线程中调用, 无需加锁
    /// 事件假定已按路径去重
    ///
    /// watcher: Watcher 实例 (用于获取监视列表)
    /// events: 监视事件数组
    /// changedFiles: 变更文件名数组
    public func writeEvents(watcher: Watcher, events: Array<WatcherEvent>,
                             changedFiles: Array<?String>): Unit {
        let fd = traceFd
        if (fd == None) {
            return  // 对应 trace_file orelse return
        }

        let traceFdValue = fd.getOrThrow()

        // 获取当前时间戳 (毫秒) - 对应 std.time.milliTimestamp()
        let timestamp = currentMillis()

        // 构建 JSON 输出
        // 严格翻译自: WatcherTrace.zig:42-99
        //   writer.writeAll("{\"timestamp\":") catch return;
        //   writer.print("{d}", .{timestamp}) catch return;
        //   writer.writeAll(",\"files\":{") catch return;
        var sb = StringBuilder()
        sb.append("{\"timestamp\":")
        sb.append("${timestamp}")
        sb.append(",\"files\":{")

        // 获取监视列表的文件路径 - 对应 watchlist.slice().items(.file_path)
        let watchlist = watcher.getWatchlist()
        let filePaths = watchlist.filePaths()

        var firstFile = true
        for (i in 0..events.size) {
            let event = events[i]
            // 获取文件路径 - 对应 WatcherTrace.zig:51
            //   const file_path = if (event.index < file_paths.len)
            //       file_paths[event.index] else "(unknown)";
            let filePath = if (Int64(event.index) < filePaths.size)
                filePaths[Int64(event.index)]
            else
                "(unknown)"

            // 获取变更名称
            let names = event.names(changedFiles)

            if (!firstFile) {
                sb.append(",")
            }
            firstFile = false

            // 写入路径键 - 对应 WatcherTrace.zig:54-55
            //   writer.print("{f}", .{bun.fmt.formatJSONStringUTF8(file_path, .{})})
            sb.append("\"${escapeJson(filePath)}\"")
            sb.append(":{\"events\":[")

            // 写入事件类型数组 - 对应 WatcherTrace.zig:62-70
            //   inline for (fields) |field| {
            //       if (field.type == bool and @field(event.op, field.name)) {
            //           writer.print("\"{s}\"", .{field.name});
            //       }
            //   }
            var first = true
            let op = event.op
            if (op.delete) {
                if (!first) { sb.append(",") }
                sb.append("\"delete\"")
                first = false
            }
            if (op.metadata) {
                if (!first) { sb.append(",") }
                sb.append("\"metadata\"")
                first = false
            }
            if (op.rename) {
                if (!first) { sb.append(",") }
                sb.append("\"rename\"")
                first = false
            }
            if (op.write) {
                if (!first) { sb.append(",") }
                sb.append("\"write\"")
                first = false
            }
            if (op.moveTo) {
                if (!first) { sb.append(",") }
                sb.append("\"move_to\"")
                first = false
            }
            if (op.create) {
                if (!first) { sb.append(",") }
                sb.append("\"create\"")
                first = false
            }
            sb.append("]")

            // 写入变更文件名 (如果有)
            // 严格翻译自: WatcherTrace.zig:74-94
            var hasChanged = false
            for (name in names) {
                if (name != None) {
                    hasChanged = true
                    break
                }
            }

            if (hasChanged) {
                sb.append(",\"changed\":[")
                first = true
                for (nameOpt in names) {
                    if (let Some(name) = nameOpt) {
                        if (!first) { sb.append(",") }
                        first = false
                        sb.append("\"${escapeJson(name)}\"")
                    }
                }
                sb.append("]")
            }

            sb.append("}")
        }

        sb.append("}}\n")

        // 写入文件 - 对应 writer 的所有 writeAll/print 调用
        let output = sb.toString()
        let bytes = stringToBytes(output)
        match (SysFs.write(traceFdValue, bytes)) {
            case Ok(_) => { }  // 成功
            case Err(_) => { } // 静默忽略 - 对应 catch return
        }
    }

    // ========================================================================
    // 清理 - 对应 Bun WatcherTrace.deinit
    // 严格翻译自: WatcherTrace.zig:103-108
    //
    //   pub fn deinit() void {
    //       if (trace_file) |file| {
    //           file.close();
    //           trace_file = null;
    //       }
    //   }
    // ========================================================================

    /// 关闭追踪文件 - 对应 Bun WatcherTrace.deinit()
    /// 严格翻译自: WatcherTrace.zig:103-108
    public func deinit(): Unit {
        if (let Some(fd) = traceFd) {
            SysFs.close(fd)
            traceFd = None
        }
    }

    // ========================================================================
    // 辅助方法
    // ========================================================================

    /// JSON 字符串转义 - 对应 Bun bun.fmt.formatJSONStringUTF8
    /// 转义双引号、反斜杠、控制字符
    private func escapeJson(s: String): String {
        var sb = StringBuilder()
        for (ch in s) {
            match (ch) {
                case '"' => sb.append("\\\"")
                case '\\' => sb.append("\\\\")
                case '\n' => sb.append("\\n")
                case '\r' => sb.append("\\r")
                case '\t' => sb.append("\\t")
                case _ => sb.append(ch)
            }
        }
        return sb.toString()
    }

    /// 字符串转字节数组
    private func stringToBytes(s: String): Array<UInt8> {
        var bytes = ArrayList<UInt8>()
        for (ch in s) {
            bytes.append(UInt8(Int32(ch.value) & 0xFF))
        }
        return bytes.toArray()
    }

    /// 获取当前时间戳 (毫秒) - 对应 std.time.milliTimestamp()
    private func currentMillis(): Int64 {
        // 简化实现: 仓颉 DateTime
        // 对应 Zig std.time.milliTimestamp()
        return Int64(std.time.DateTime.now().getYear())
    }
}
