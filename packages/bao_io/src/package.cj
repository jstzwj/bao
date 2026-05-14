// bao_io - IO 操作
// 对应 Bun: src/io/
package bao_io

import bao_core.*
import bao_sys.*

// ============================================================================
// 文件 IO
// 对应 Bun: src/io/io.zig
// ============================================================================

/// 文件打开选项
public enum OpenMode {
    | Read           // "r"
    | Write          // "w"
    | ReadWrite      // "rw"
    | Append         // "a"
    | ReadAppend     // "ra"
}

/// 文件类
public class BaoFile {
    private var fd: Fd
    private var path: String
    private var isOpen: Bool

    public init(fd: Fd, path: String) {
        this.fd = fd
        this.path = path
        this.isOpen = true
    }

    /// 打开文件
    public static func open(path: String, mode: OpenMode): BaoFile {
        // 使用仓颉标准库
        let file = try {
            return BaoFile(fd: 0, path: path)
        }
    }

    /// 读取整个文件到字节数组
    public static func readAllBytes(path: String): Array<UInt8> {
        try {
            let content = std.fs.File(path, OpenOption.Read).readToEnd()
            return content
        } catch (e: Exception) {
            throw IoError(2, "Failed to read file: ${path}")
        }
    }

    /// 读取整个文件到字符串
    public static func readAllText(path: String): String {
        let bytes = readAllBytes(path)
        var sb = StringBuilder()
        for (b in bytes) {
            sb.append(Char(Int32(b)))
        }
        return sb.toString()
    }

    /// 写入字节数组到文件
    public static func writeAllBytes(path: String, data: Array<UInt8>): Unit {
        try {
            // 使用仓颉标准库写入
            let file = std.fs.File(path, OpenOption.Create(true))
            file.write(data)
        } catch (e: Exception) {
            throw IoError(errno, "Failed to write file: ${path}")
        }
    }

    /// 写入字符串到文件
    public static func writeAllText(path: String, text: String): Unit {
        var bytes = Array<UInt8>()
        for (c in text) {
            bytes.append(UInt8(c.value))
        }
        writeAllBytes(path, bytes)
    }

    /// 关闭文件
    public func close(): Unit {
        if (isOpen) {
            close(Int32(fd))
            isOpen = false
        }
    }

    /// 获取文件路径
    public func getPath(): String {
        return path
    }

    /// 获取文件描述符
    public func getFd(): Fd {
        return fd
    }
}

// ============================================================================
// 缓冲读取器
// 对应 Bun: BufferedReader 模式
// ============================================================================

/// 缓冲读取器
public class BufferedReader {
    private var buffer: Array<UInt8>
    private var pos: Int64
    private var limit: Int64
    private var capacity: Int64

    public init(capacity: Int64) {
        this.capacity = capacity
        this.buffer = Array<UInt8>(capacity, item: 0)
        this.pos = 0
        this.limit = 0
    }

    /// 读取一行
    public func readLine(): ?String {
        if (pos >= limit) {
            return None
        }
        var sb = StringBuilder()
        while (pos < limit) {
            let b = buffer[pos]
            pos += 1
            if (b == UInt8('\n')) {
                break
            }
            sb.append(Char(Int32(b)))
        }
        return Some(sb.toString())
    }

    /// 填充缓冲区
    public func fill(data: Array<UInt8>): Int64 {
        let toRead = if (data.size < (capacity - limit)) {
            data.size
        } else {
            Int64(capacity - limit)
        }
        for (i in 0..toRead) {
            buffer[limit + i] = data[i]
        }
        limit += toRead
        return toRead
    }
}

// ============================================================================
// 缓冲写入器
// ============================================================================

/// 缓冲写入器
public class BufferedWriter {
    private var buffer: ArrayBuffer
    private var fd: Fd

    public init(fd: Fd) {
        this.buffer = ArrayBuffer()
        this.fd = fd
    }

    /// 写入字节
    public func write(b: UInt8): Unit {
        buffer.append(b)
    }

    /// 写入字节数组
    public func writeBytes(data: Array<UInt8>): Unit {
        buffer.appendBytes(data)
    }

    /// 写入字符串
    public func writeString(s: String): Unit {
        buffer.appendString(s)
    }

    /// 刷新到文件
    public func flush(): Unit {
        let data = buffer.slice()
        unsafe {
            write(Int32(fd), data.toArray().unsafePtr(), UIntNative(data.size))
        }
        buffer.clear()
    }

    /// 获取缓冲区大小
    public func bufferSize(): Int64 {
        return buffer.len()
    }
}
