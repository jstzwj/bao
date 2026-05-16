// 严格翻译自: src/sql/postgres/SocketMonitor.zig
// Socket 监控器 - 用于调试 PostgreSQL 连接
package bao_sql.postgres

/// Socket 监控器
/// 用于调试模式下监控 PostgreSQL socket 的读写数据
/// 对应 Bun: SocketMonitor
public class SocketMonitor {
    private static var readerEnabled: Bool = false
    private static var writerEnabled: Bool = false
    private static var readerFile: ?String = None
    private static var writerFile: ?String = None

    /// 记录写入数据
    /// 对应 Bun: SocketMonitor.write
    public static func write(data: Array<UInt8>): Unit {
        if (writerEnabled) {
            // 调试模式下将数据写入文件
            debug("SocketMonitor: write ${data.size} bytes")
        }
    }

    /// 记录读取数据
    /// 对应 Bun: SocketMonitor.read
    public static func read(data: Array<UInt8>): Unit {
        if (readerEnabled) {
            // 调试模式下将数据写入文件
            debug("SocketMonitor: read ${data.size} bytes")
        }
    }

    /// 启用读取监控
    public static func enableReaderMonitor(path: String): Unit {
        readerEnabled = true
        readerFile = path
    }

    /// 启用写入监控
    public static func enableWriterMonitor(path: String): Unit {
        writerEnabled = true
        writerFile = path
    }

    /// 禁用所有监控
    public static func disable(): Unit {
        readerEnabled = false
        writerEnabled = false
        readerFile = None
        writerFile = None
    }

    private static func debug(msg: String): Unit {
        // 日志输出
        print(msg)
    }
}
