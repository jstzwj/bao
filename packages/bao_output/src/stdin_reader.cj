// 严格翻译自: src/bun_core/output.rs:2898-2926
//   pub struct StdinReader { fd: Fd }
//   impl StdinReader {
//       pub fn take_byte(&mut self) -> Result<u8, Error> { ... }
//       pub fn read_byte(&mut self) -> Result<u8, Error> { ... }
//   }
//   pub fn stdin_reader() -> StdinReader { StdinReader { fd: Fd::stdin() } }
package bao_output

import bao_core.*

import std.console.*

// ============================================================================
// BaoStdinReader - 非缓冲标准输入读取器
// 严格翻译自: src/bun_core/output.rs:2898-2926
//   pub struct StdinReader { fd: Fd }
//   impl StdinReader {
//       pub fn take_byte(&mut self) -> Result<u8, Error> { ... }
//       pub fn read_byte(&mut self) -> Result<u8, Error> { ... }
//   }
// ============================================================================

/// 非缓冲标准输入读取器 - 对应 Bun StdinReader
/// pub struct StdinReader { fd: Fd }
/// std.fs.File.stdin().readerStreaming(&buf) — fresh, unbuffered stdin reader.
public class BaoStdinReader {

    public init() {}

    /// 取一个字节 - 对应 Bun StdinReader.takeByte()
    /// pub fn take_byte(&mut self) -> Result<u8, Error> {
    ///     let mut one = [0u8; 1];
    ///     match output_sink().read(self.fd, &mut one)? {
    ///         0 => Err(crate::err!(EndOfStream)),
    ///         _ => Ok(one[0]),
    ///     }
    /// }
    public func takeByte(): UInt8 {
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

    /// 读取一个字节 - 对应 Bun StdinReader.readByte()
    /// Alias for callers that spell it read_byte.
    public func readByte(): UInt8 {
        return takeByte()
    }

    /// 读取一行 - 仓颉扩展
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
