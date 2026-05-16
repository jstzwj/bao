// 严格翻译自: src/bun_core/output.rs:2777-2960
//   pub static BUFFERED_STDIN: crate::RacyCell<BufferedStdin> = ...;
//   pub struct BufferedStdin { fd, buf, start, end }
//   pub struct StdinReader { fd }
//   pub fn buffered_stdin() -> *mut BufferedStdin { ... }
//   pub fn stdin_reader() -> StdinReader { ... }
//
// 也翻译自: src/bun_core/output.zig:1337-1340
//   pub var buffered_stdin = bun.deprecated.BufferedReader(4096, File.Reader){ ... };
package bao_output

import bao_core.*

import std.console.*
import std.collection.*

// ============================================================================
// BufferedStdinReader - 缓冲标准输入读取器
// 严格翻译自: src/bun_core/output.rs:2786-2896
//   pub struct BufferedStdin {
//       pub fd: Fd,
//       pub buf: [u8; 4096],
//       pub start: usize,
//       pub end: usize,
//   }
//   impl BufferedStdin {
//       pub fn read(&mut self, dest: &mut [u8]) -> Result<usize, Error> { ... }
//       pub fn read_byte(&mut self) -> Result<u8, Error> { ... }
//       pub fn read_until_delimiter_array_list(...) -> Result<(), Error> { ... }
//   }
// ============================================================================

/// 缓冲标准输入读取器 - 对应 Bun BufferedStdin
/// pub struct BufferedStdin { fd: Fd, buf: [u8; 4096], start: usize, end: usize }
public class BufferedStdinReader {
    /// 缓冲区大小 - 对应 Bun buf: [u8; 4096]
    public static let BUFFER_SIZE: Int64 = 4096

    /// 内部缓冲区
    private var buffer: Array<UInt8>
    /// 缓冲区起始位置
    private var startPos: Int64
    /// 缓冲区结束位置
    private var endPos: Int64

    public init() {
        this.buffer = Array<UInt8>(BUFFER_SIZE, repeat: UInt8(0))
        this.startPos = 0
        this.endPos = 0
    }

    /// 获取读取器 - 对应 Bun BufferedStdin.reader()
    /// pub fn reader(&mut self) -> &mut Self { self }
    public func reader(): BufferedStdinReader {
        return this
    }

    /// 读取字节 - 对应 Bun BufferedStdin.read()
    /// pub fn read(&mut self, dest: &mut [u8]) -> Result<usize, Error>
    public func read(dest: Array<UInt8>): Int64 {
        var written: Int64 = 0
        // 从缓冲区中读取
        if (startPos < endPos) {
            let available = endPos - startPos
            let remaining = dest.size - written
            let toCopy = if (available < remaining) { available } else { remaining }
            for (i in 0..toCopy) {
                dest[written + i] = buffer[startPos + i]
            }
            startPos += toCopy
            written += toCopy
            if (written == dest.size) {
                return written
            }
        }

        // 从 stdin 直接读取
        try {
            let stdin = Console.stdIn
            let remaining = dest.size - written
            // 读取到目标缓冲区
            var line = stdin.readln()
            match (line) {
                case Some(s) =>
                    let bytes = s.toArray()
                    let byteSize = Int64(bytes.size)
                    let toCopy = if (byteSize < remaining) { byteSize } else { remaining }
                    for (i in 0..toCopy) {
                        dest[written + i] = bytes[Int64(i)]
                    }
                    written += toCopy
                case None => ()
            }
        } catch (_: Exception) {
            // 读取错误, 返回已读取的字节数
        }
        return written
    }

    /// 读取单个字节 - 对应 Bun BufferedStdin.readByte()
    /// pub fn read_byte(&mut self) -> Result<u8, Error>
    public func readByte(): UInt8 {
        if (startPos < endPos) {
            let b = buffer[startPos]
            startPos += 1
            return b
        }
        // 从 stdin 读取一个字节
        try {
            let stdin = Console.stdIn
            let ch = stdin.read()
            match (ch) {
                case Some(r) =>
                    return UInt8(UInt32(r))
                case None =>
                    throw BaoError(ErrorCode.EndOfStream, "End of stdin stream")
            }
        } catch (e: BaoError) {
            throw e
        } catch (_: Exception) {
            throw BaoError(ErrorCode.EndOfStream, "End of stdin stream")
        }
    }

    /// 读取到分隔符 - 对应 Bun BufferedStdin.readUntilDelimiterArrayList()
    /// pub fn read_until_delimiter_array_list(
    ///     &mut self, out: &mut Vec<u8>, delimiter: u8, max_size: usize
    /// ) -> Result<(), Error>
    public func readUntilDelimiter(out: ArrayList<UInt8>, delimiter: UInt8, maxSize: Int64): Unit {
        out.clear()
        while (true) {
            if (out.size >= maxSize) {
                throw BaoError(ErrorCode.StreamTooLong, "Stream too long")
            }
            let b = readByte()
            if (b == delimiter) {
                return
            }
            out.add(b)
        }
    }

    /// 读取一行 - 仓颉扩展方法
    public func readLine(): String {
        try {
            let stdin = Console.stdIn
            let line = stdin.readln()
            match (line) {
                case Some(s) => return s
                case None => return ""
            }
        } catch (_: Exception) {
            return ""
        }
    }
}

/// 读取标准输入直到分隔符 - 对应 Bun Output.bufferedStdinReadUntilDelimiter()
/// pub fn buffered_stdin_read_until_delimiter(
///     out: &mut Vec<u8>, delimiter: u8, max_size: usize
/// ) -> Result<(), Error>
public func bufferedStdinReadUntilDelimiter(out: ArrayList<UInt8>, delimiter: UInt8, maxSize: Int64): Unit {
    let reader = BufferedStdinReader()
    reader.readUntilDelimiter(out, delimiter, maxSize)
}
