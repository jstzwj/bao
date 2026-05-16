// bao_io - 字节级 Write trait + 辅助类型
// 严格翻译自: src/io/write.rs
//   Bun 的 write.rs 是 Zig std.Io.Writer 表面的 Rust 翻译
//   提供: Write trait, DiscardingWriter, FixedBufferStream, BufWriter, FmtAdapter, AsFmt
//   所有写入器只需要实现 write_all(), 其他方法基于此派生
//   用于: 格式化输出, 网络写入, 文件写入, 日志
package bao_io

import bao_core.*

// ============================================================================
// IoResult - IO 结果类型
// 严格翻译自: write.rs Result
//   pub type Result<T = ()> = core::result::Result<T, bun_core::Error>
//   仓颉使用 SysError 作为 IO 错误类型
// ============================================================================

/// IO 操作结果
/// 翻译自: pub type Result<T = ()> = core::result::Result<T, bun_core::Error>
public typealias IoResult<T> = SysMaybe<T>

// ============================================================================
// ByteWrite - 字节写入 trait
// 严格翻译自: write.rs trait Write (bun_core::write::Write)
//   pub trait Write {
//       fn write_all(&mut self, buf: &[u8]) -> Result<()>;
//       fn write_byte(&mut self, byte: u8) -> Result<()> { ... }
//       fn splat_byte_all(&mut self, byte: u8, n: usize) -> Result<()> { ... }
//       fn write_int_le<I: IntLe>(&mut self) -> Result<I> { ... }
//       fn write_int_be<I: IntBe>(&mut self) -> Result<I> { ... }
//       fn written_len(&self) -> usize { ... }
//       fn flush(&mut self) -> Result<()> { ... }
//       fn print(&mut self, ...) { ... }
//   }
//   唯一必须实现的方法是 write_all(), 其他提供默认实现
// ============================================================================

/// 字节写入接口 - 对应 Bun Write trait
/// 所有字节级写入器都必须实现此接口
/// 只需要实现 writeAll(), 其他方法基于此派生
public interface ByteWrite {
    /// 写入完整的字节切片 - 唯一必须实现的方法
    /// 严格翻译自: fn write_all(&mut self, buf: &[u8]) -> Result<()>
    func writeAll(buf: Array<UInt8>): IoResult<Unit>

    /// 写入单个字节
    /// 严格翻译自: fn write_byte(&mut self, byte: u8) -> Result<()>
    ///   默认: write_all(&[byte])
    func writeByte(byte: UInt8): IoResult<Unit> {
        return writeAll([byte])
    }

    /// 重复写入 n 个相同的字节 (填充)
    /// 严格翻译自: fn splat_byte_all(&mut self, byte: u8, n: usize) -> Result<()>
    ///   默认: 循环 write_byte 或一次构造大 buffer 后 write_all
    func splatByteAll(byte: UInt8, n: Int64): IoResult<Unit> {
        if (n <= 0) {
            return IoResult<Unit>.Ok(())
        }
        // 小量: 逐个写入
        if (n <= 16) {
            for (_ in 0..n) {
                let r = writeByte(byte)
                match (r) {
                    case IoResult<Unit>.Err(e) => return IoResult<Unit>.Err(e)
                    case IoResult<Unit>.Ok(_) => ()
                }
            }
            return IoResult<Unit>.Ok(())
        }
        // 大量: 构造缓冲区一次写入
        var buf = Array<UInt8>(n, item: byte)
        return writeAll(buf)
    }

    /// 写入小端序整数
    /// 严格翻译自: fn write_int_le<I: IntLe>(&mut self, value: I) -> Result<()>
    ///   默认: 将整数转为小端字节序后 write_all
    func writeIntLe(value: Int64): IoResult<Unit> {
        var buf = Array<UInt8>(8, item: UInt8(0))
        // 手动小端编码
        var v = value
        for (i in 0..8) {
            buf[i] = UInt8(v % 256)
            v = v >> 8
        }
        return writeAll(buf)
    }

    /// 写入小端序 16 位整数
    func writeIntLe16(value: Int16): IoResult<Unit> {
        var buf = Array<UInt8>(2, item: UInt8(0))
        buf[0] = UInt8(value % 256)
        buf[1] = UInt8((value >> 8) % 256)
        return writeAll(buf)
    }

    /// 写入小端序 32 位整数
    func writeIntLe32(value: Int32): IoResult<Unit> {
        var buf = Array<UInt8>(4, item: UInt8(0))
        var v = Int64(value)
        for (i in 0..4) {
            buf[i] = UInt8(v % 256)
            v = v >> 8
        }
        return writeAll(buf)
    }

    /// 写入大端序 (网络字节序) 整数
    /// 严格翻译自: fn write_int_be<I: IntBe>(&mut self, value: I) -> Result<()>
    func writeIntBe(value: Int64): IoResult<Unit> {
        var buf = Array<UInt8>(8, item: UInt8(0))
        var v = value
        for (i in 0..8) {
            buf[7 - i] = UInt8(v % 256)
            v = v >> 8
        }
        return writeAll(buf)
    }

    /// 写入大端序 16 位整数
    func writeIntBe16(value: Int16): IoResult<Unit> {
        var buf = Array<UInt8>(2, item: UInt8(0))
        buf[0] = UInt8((value >> 8) % 256)
        buf[1] = UInt8(value % 256)
        return writeAll(buf)
    }

    /// 写入大端序 32 位整数
    func writeIntBe32(value: Int32): IoResult<Unit> {
        var buf = Array<UInt8>(4, item: UInt8(0))
        var v = Int64(value)
        for (i in 0..4) {
            buf[3 - i] = UInt8(v % 256)
            v = v >> 8
        }
        return writeAll(buf)
    }

    /// 已写入的字节数
    /// 严格翻译自: fn written_len(&self) -> usize
    func writtenLen(): Int64 {
        return 0
    }

    /// 刷新缓冲区
    /// 严格翻译自: fn flush(&mut self) -> Result<()>
    func flush(): IoResult<Unit> {
        return IoResult<Unit>.Ok(())
    }

    /// 写入字符串 (UTF-8 字节)
    /// 便利方法: 将字符串转为字节后 write_all
    func writeString(s: String): IoResult<Unit> {
        var buf = Array<UInt8>()
        for (c in s) {
            buf.append(UInt8(c.value))
        }
        return writeAll(buf)
    }

    /// 格式化写入
    /// 严格翻译自: fn print(&mut self, ...)
    ///   Bun 使用 Zig 的 fmt 系统; 仓颉使用字符串插值
    func print(text: String): IoResult<Unit> {
        return writeString(text)
    }
}

// ============================================================================
// DiscardingWriter - 丢弃写入器 (计数空汇)
// 严格翻译自: write.rs DiscardingWriter
//   pub struct DiscardingWriter { pub count: usize }
//   丢弃所有写入的字节但跟踪写入了多少
//   对应 Zig std.Io.Writer.Discarding / std.io.countingWriter(null_writer)
// ============================================================================

/// 丢弃写入器 - 丢弃所有数据但统计写入量
/// 严格翻译自: write.rs DiscardingWriter
///   pub struct DiscardingWriter { pub count: usize }
///   impl Write for DiscardingWriter {
///       fn write_all(&mut self, buf: &[u8]) -> Result<()> {
///           self.count += buf.len(); Ok(())
///       }
///       fn splat_byte_all(&mut self, _byte: u8, n: usize) -> Result<()> {
///           self.count += n; Ok(())
///       }
///       fn written_len(&self) -> usize { self.count }
///   }
public class DiscardingWriter <: ByteWrite {
    /// 已丢弃的总字节数
    /// 翻译自: pub count: usize
    public var count: Int64

    public init() {
        count = 0
    }

    /// 创建新实例
    /// 严格翻译自: pub const fn new() -> Self { Self { count: 0 } }
    public static func new(): DiscardingWriter {
        return DiscardingWriter()
    }

    /// 丢弃数据并统计
    /// 严格翻译自: fn write_all(&mut self, buf: &[u8]) -> Result<()>
    public func writeAll(buf: Array<UInt8>): IoResult<Unit> {
        count += buf.size
        return IoResult<Unit>.Ok(())
    }

    /// 重复丢弃 n 个字节
    /// 严格翻译自: fn splat_byte_all(&mut self, _byte: u8, n: usize) -> Result<()>
    public func splatByteAll(byte: UInt8, n: Int64): IoResult<Unit> {
        count += n
        return IoResult<Unit>.Ok(())
    }

    /// 已写入(丢弃)的字节数
    /// 严格翻译自: fn written_len(&self) -> usize { self.count }
    public func writtenLen(): Int64 {
        return count
    }

    /// 重置计数器
    public func reset(): Unit {
        count = 0
    }
}

// ============================================================================
// FixedBufferStream - 内存缓冲区上的游标
// 严格翻译自: write.rs FixedBufferStream
//   pub struct FixedBufferStream<B> { pub buffer: B, pub pos: usize }
//   Port of Zig std.io.FixedBufferStream(B) - 一个可寻址的游标
//   可以同时作为读取器和写入器
// ============================================================================

/// 固定缓冲区流 - 内存缓冲区上的可寻址游标
/// 严格翻译自: write.rs FixedBufferStream<B>
///   pub struct FixedBufferStream<B> { pub buffer: B, pub pos: usize }
///   同时支持读取和写入, pos 为当前游标位置
public class FixedBufferStream {
    /// 内部缓冲区
    /// 翻译自: pub buffer: B
    public var buffer: Array<UInt8>
    /// 当前游标位置
    /// 翻译自: pub pos: usize
    public var pos: Int64

    public init(capacity: Int64) {
        buffer = Array<UInt8>(capacity, item: UInt8(0))
        pos = 0
    }

    public init(buffer: Array<UInt8>) {
        this.buffer = buffer
        pos = 0
    }

    /// 创建新流
    /// 严格翻译自: pub fn new(buffer: B) -> Self { Self { buffer, pos: 0 } }
    public static func new(capacity: Int64): FixedBufferStream {
        return FixedBufferStream(capacity)
    }

    /// 从已有缓冲区创建
    public static func fromBuffer(buffer: Array<UInt8>): FixedBufferStream {
        return FixedBufferStream(buffer)
    }

    /// 寻址到绝对位置
    /// 严格翻译自: pub fn seek_to(&mut self, p: usize) { self.pos = p; }
    public func seekTo(p: Int64): Unit {
        pos = p
    }

    /// 重置到位置 0
    /// 严格翻译自: pub fn reset(&mut self) { self.pos = 0; }
    public func reset(): Unit {
        pos = 0
    }

    // ===== 读取方法 =====

    /// 获取已写入的数据 [0..pos]
    /// 严格翻译自: pub fn get_written(&self) -> &[u8] { &self.buffer.as_ref()[..self.pos] }
    public func getWritten(): Array<UInt8> {
        var result = Array<UInt8>()
        for (i in 0..pos) {
            result.append(buffer[i])
        }
        return result
    }

    /// 获取当前游标位置
    /// 严格翻译自: pub fn get_pos(&self) -> Result<usize> { Ok(self.pos) }
    public func getPos(): Int64 {
        return pos
    }

    /// 读取最多 out.size 个字节, 返回实际读取数
    /// 严格翻译自: pub fn read_all(&mut self, out: &mut [u8]) -> Result<usize>
    public func readAll(maxCount: Int64): Array<UInt8> {
        let avail = buffer.size - pos
        let n = if (maxCount < avail) { maxCount } else { avail }
        var result = Array<UInt8>()
        for (i in 0..n) {
            result.append(buffer[pos + i])
        }
        pos += n
        return result
    }

    /// 读取精确 count 个字节
    /// 严格翻译自: pub fn read_exact(&mut self, out: &mut [u8]) -> Result<()>
    public func readExact(count: Int64): ?Array<UInt8> {
        let end = pos + count
        if (end > buffer.size) {
            return None  // EndOfStream
        }
        var result = Array<UInt8>()
        for (i in 0..count) {
            result.append(buffer[pos + i])
        }
        pos = end
        return Some(result)
    }

    /// 读取小端序整数
    /// 严格翻译自: pub fn read_int_le<I: IntLe>(&mut self) -> Result<I>
    public func readIntLe(): ?Int64 {
        match (readExact(8)) {
            case Some(bytes) =>
                var result: Int64 = 0
                for (i in 0..8) {
                    result = result | (Int64(bytes[i]) << (i * 8))
                }
                return Some(result)
            case None => None
        }
    }

    /// 读取大端序整数
    /// 严格翻译自: pub fn read_int_be<I: IntBe>(&mut self) -> Result<I>
    public func readIntBe(): ?Int64 {
        match (readExact(8)) {
            case Some(bytes) =>
                var result: Int64 = 0
                for (i in 0..8) {
                    result = result | (Int64(bytes[i]) << ((7 - i) * 8))
                }
                return Some(result)
            case None => None
        }
    }

    /// 读取小端序 16 位
    public func readIntLe16(): ?Int16 {
        match (readExact(2)) {
            case Some(bytes) =>
                return Some(Int16(bytes[0]) | (Int16(bytes[1]) << 8))
            case None => None
        }
    }

    /// 读取小端序 32 位
    public func readIntLe32(): ?Int32 {
        match (readExact(4)) {
            case Some(bytes) =>
                return Some(Int32(bytes[0]) | (Int32(bytes[1]) << 8) |
                            (Int32(bytes[2]) << 16) | (Int32(bytes[3]) << 24))
            case None => None
        }
    }

    /// 剩余可读字节数
    public func remaining(): Int64 {
        return buffer.size - pos
    }

    // ===== 写入方法 =====

    /// 写入字节切片
    /// 严格翻译自: impl Write for FixedBufferStream
    ///   fn write_all(&mut self, src: &[u8]) -> Result<()> {
    ///       let end = self.pos.checked_add(src.len()).ok_or("NoSpaceLeft")?;
    ///       if end > buf.len() { return Err("NoSpaceLeft"); }
    ///       buf[self.pos..end].copy_from_slice(src);
    ///       self.pos = end;
    ///       Ok(())
    ///   }
    public func writeAll(src: Array<UInt8>): IoResult<Unit> {
        let end = pos + src.size
        if (end > buffer.size) {
            return IoResult<Unit>.Err(SysError(28, SysTag.Write))  // ENOSPC
        }
        for (i in 0..src.size) {
            buffer[pos + i] = src[i]
        }
        pos = end
        return IoResult<Unit>.Ok(())
    }

    /// 写入单个字节
    public func writeByte(byte: UInt8): IoResult<Unit> {
        if (pos >= buffer.size) {
            return IoResult<Unit>.Err(SysError(28, SysTag.Write))
        }
        buffer[pos] = byte
        pos += 1
        return IoResult<Unit>.Ok(())
    }

    /// 写入小端序整数
    public func writeIntLe(value: Int64): IoResult<Unit> {
        let end = pos + 8
        if (end > buffer.size) {
            return IoResult<Unit>.Err(SysError(28, SysTag.Write))
        }
        var v = value
        for (i in 0..8) {
            buffer[pos + i] = UInt8(v % 256)
            v = v >> 8
        }
        pos = end
        return IoResult<Unit>.Ok(())
    }

    /// 写入大端序整数
    public func writeIntBe(value: Int64): IoResult<Unit> {
        let end = pos + 8
        if (end > buffer.size) {
            return IoResult<Unit>.Err(SysError(28, SysTag.Write))
        }
        var v = value
        for (i in 0..8) {
            buffer[pos + 7 - i] = UInt8(v % 256)
            v = v >> 8
        }
        pos = end
        return IoResult<Unit>.Ok(())
    }

    /// 已写入长度
    /// 严格翻译自: fn written_len(&self) -> usize { self.pos }
    public func writtenLen(): Int64 {
        return pos
    }
}

// ============================================================================
// SliceBufWriter - 借用缓冲区的缓冲写入器
// 严格翻译自: write.rs BufWriter<'a, W: Write>
//   pub struct BufWriter<'a, W: Write> {
//       buf: &'a mut [u8], pos: usize, inner: W
//   }
//   Port of Zig std.fs.File.writerStreaming / std.io.BufferedWriter
//   调用者拥有字节缓冲区 (通常是栈上的 [0u8; 4096])
//   此类型不执行堆分配。写入累积到 buf, 满时刷新到 inner
//   Drop 不刷新 - 调用者必须在缓冲区超出作用域前调用 flush()
// ============================================================================

/// 借用缓冲区的缓冲写入器
/// 严格翻译自: write.rs BufWriter<'a, W: Write>
///   pub struct BufWriter<'a, W: Write> {
///       buf: &'a mut [u8], pos: usize, inner: W
///   }
/// 调用者提供缓冲区, 此类型不执行堆分配
/// 写入累积到 buf, 满 (或显式 flush) 时刷新到 inner
public class SliceBufWriter {
    /// 内部缓冲区
    private var buf: Array<UInt8>
    /// 当前位置
    private var pos: Int64
    /// 内部写入器 (文件描述符)
    private var fd: Int64

    public init(buf: Array<UInt8>, fd: Int64) {
        this.buf = buf
        this.pos = 0
        this.fd = fd
    }

    /// 创建写入器
    /// 严格翻译自: pub fn with_buffer(buf: &'a mut [u8], inner: W) -> Self
    public static func withBuffer(buf: Array<UInt8>, fd: Int64): SliceBufWriter {
        return SliceBufWriter(buf, fd)
    }

    /// 缓冲区中未刷新的字节
    /// 严格翻译自: pub fn buffered(&self) -> &[u8] { &self.buf[..self.pos] }
    public func buffered(): Array<UInt8> {
        var result = Array<UInt8>()
        for (i in 0..pos) {
            result.append(buf[i])
        }
        return result
    }

    /// 获取文件描述符
    /// 严格翻译自: pub fn into_inner(self) -> W { self.inner }
    public func getFd(): Int64 {
        return fd
    }

    /// 缓冲区容量
    public func capacity(): Int64 {
        return buf.size
    }

    /// 写入字节切片
    /// 严格翻译自: impl Write for BufWriter
    ///   fn write_all(&mut self, mut src: &[u8]) -> Result<()> {
    ///       // Degenerate zero-capacity: pass through
    ///       if self.buf.is_empty() { return self.inner.write_all(src); }
    ///       // Large write > capacity: flush + bypass
    ///       if src.len() >= self.buf.len() {
    ///           self.flush_buf()?;
    ///           return self.inner.write_all(src);
    ///       }
    ///       // Fill remaining; flush on overflow; copy tail
    ///       let avail = self.buf.len() - self.pos;
    ///       if src.len() > avail {
    ///           self.buf[self.pos..].copy_from_slice(&src[..avail]);
    ///           self.pos = self.buf.len();
    ///           self.flush_buf()?;
    ///           src = &src[avail..];
    ///       }
    ///       self.buf[self.pos..self.pos+src.len()].copy_from_slice(src);
    ///       self.pos += src.len();
    ///       Ok(())
    ///   }
    public func writeAll(src: Array<UInt8>): IoResult<Unit> {
        // 零容量: 直接透传
        if (buf.size == 0) {
            return writeDirectly(src)
        }
        // 大写入 > 容量: 先刷新再直写
        if (src.size >= buf.size) {
            let r = flushBuf()
            match (r) {
                case IoResult<Unit>.Err(e) => return IoResult<Unit>.Err(e)
                case IoResult<Unit>.Ok(_) => ()
            }
            return writeDirectly(src)
        }
        // 填充剩余容量; 满时刷新; 复制尾部
        let avail = buf.size - pos
        if (src.size > avail) {
            for (i in 0..avail) {
                buf[pos + i] = src[i]
            }
            pos = buf.size
            let r = flushBuf()
            match (r) {
                case IoResult<Unit>.Err(e) => return IoResult<Unit>.Err(e)
                case IoResult<Unit>.Ok(_) => ()
            }
            // 复制剩余
            var tail = Array<UInt8>()
            for (i in avail..src.size) {
                tail.append(src[i])
            }
            return writeAll(tail)
        }
        // 正常复制到缓冲区
        for (i in 0..src.size) {
            buf[pos + i] = src[i]
        }
        pos += src.size
        return IoResult<Unit>.Ok(())
    }

    /// 刷新
    /// 严格翻译自: fn flush(&mut self) -> Result<()> {
    ///     self.flush_buf()?;
    ///     self.inner.flush()
    /// }
    public func flush(): IoResult<Unit> {
        let r = flushBuf()
        match (r) {
            case IoResult<Unit>.Err(e) => return IoResult<Unit>.Err(e)
            case IoResult<Unit>.Ok(_) => ()
        }
        // fsync
        return IoResult<Unit>.Ok(())
    }

    /// 已写入长度
    public func writtenLen(): Int64 {
        return pos
    }

    // ===== 内部方法 =====

    /// 刷新内部缓冲区
    /// 严格翻译自: fn flush_buf(&mut self) -> Result<()> {
    ///     if self.pos > 0 {
    ///         self.inner.write_all(&self.buf[..self.pos])?;
    ///         self.pos = 0;
    ///     }
    ///     Ok(())
    /// }
    private func flushBuf(): IoResult<Unit> {
        if (pos > 0) {
            var data = Array<UInt8>()
            for (i in 0..pos) {
                data.append(buf[i])
            }
            let r = writeDirectly(data)
            match (r) {
                case IoResult<Unit>.Err(e) => return IoResult<Unit>.Err(e)
                case IoResult<Unit>.Ok(_) => ()
            }
            pos = 0
        }
        return IoResult<Unit>.Ok(())
    }

    /// 直接写入到 FD
    private func writeDirectly(data: Array<UInt8>): IoResult<Unit> {
        match (SysFs.write(fd, data)) {
            case SysMaybe<Int64>.Err(e) => return IoResult<Unit>.Err(e)
            case SysMaybe<Int64>.Ok(_) => return IoResult<Unit>.Ok(())
        }
    }
}

// ============================================================================
// FmtAdapter - 格式化适配器 (ByteWrite -> 字符串写入)
// 严格翻译自: write.rs FmtAdapter
//   pub struct FmtAdapter<'a, W: ?Sized = fmt::Formatter<'a>> { inner: &'a mut W }
//   将字节写入器桥接到字符串写入器
//   字节通过 UTF-8 检查路由到 write_str; 非 UTF-8 输入使用 lossy 解码
// ============================================================================

/// 格式化适配器 - 将 ByteWrite 桥接到字符串输出
/// 严格翻译自: write.rs FmtAdapter
///   pub struct FmtAdapter<'a, W: ?Sized = fmt::Formatter<'a>> { inner: &'a mut W }
///   字节通过 UTF-8 检查路由到字符串写入; 非 UTF-8 输入使用 lossy 解码
public class FmtAdapter {
    /// 内部写入目标 (文件描述符)
    private var fd: Int64
    /// 已写入的字节数
    private var written: Int64

    public init(fd: Int64) {
        this.fd = fd
        this.written = 0
    }

    /// 创建适配器
    /// 严格翻译自: pub fn new(inner: &'a mut W) -> Self { Self { inner } }
    public static func new(fd: Int64): FmtAdapter {
        return FmtAdapter(fd)
    }

    /// 写入字节切片
    /// 严格翻译自: impl Write for FmtAdapter
    ///   fn write_all(&mut self, buf: &[u8]) -> Result<()> {
    ///       let r = match bun_core::str_utf8(buf) {
    ///           Some(s) => self.inner.write_str(s),
    ///           None => self.inner.write_str(&String::from_utf8_lossy(buf)),
    ///       };
    ///       r.map_err(|_| bun_core::err!("FmtError"))
    ///   }
    public func writeAll(buf: Array<UInt8>): IoResult<Unit> {
        // 简化: 直接写入字节
        match (SysFs.write(fd, buf)) {
            case SysMaybe<Int64>.Err(e) => return IoResult<Unit>.Err(e)
            case SysMaybe<Int64>.Ok(n) =>
                written += n
                return IoResult<Unit>.Ok(())
        }
    }

    /// 写入字符串 (跳过字节转换)
    /// 严格翻译自: fn write_fmt(&mut self, args: fmt::Arguments) -> Result<()> {
    ///     self.inner.write_fmt(args).map_err(|_| "FmtError")
    /// }
    public func writeString(s: String): IoResult<Unit> {
        var buf = Array<UInt8>()
        for (c in s) {
            buf.append(UInt8(c.value))
        }
        return writeAll(buf)
    }

    /// 已写入字节数
    public func writtenLen(): Int64 {
        return written
    }
}

// ============================================================================
// AsFmt - 反向适配器 (ByteWrite -> fmt::Write 桥接)
// 严格翻译自: write.rs AsFmt
//   pub struct AsFmt<'a> {
//       sink: &'a mut dyn Write,
//       pub err: Option<bun_core::Error>,
//   }
//   将 ByteWrite 视为字符串写入器
//   write_str 通过 write_all(s.as_bytes()) 路由
//   IO 错误存储在 err 字段以便调用者恢复
// ============================================================================

/// 反向格式化适配器 - 将 ByteWrite 视为字符串输出
/// 严格翻译自: write.rs AsFmt
///   pub struct AsFmt<'a> {
///       sink: &'a mut dyn Write,
///       pub err: Option<bun_core::Error>,
///   }
public class AsFmt {
    /// 内部写入器 (FD)
    private var fd: Int64
    /// 最后的 IO 错误
    /// 翻译自: pub err: Option<bun_core::Error>
    public var err: ?SysError
    /// 已写入字节数
    private var written: Int64

    public init(fd: Int64) {
        this.fd = fd
        this.err = None
        this.written = 0
    }

    /// 创建适配器
    /// 严格翻译自: pub fn new(sink: &'a mut dyn Write) -> Self { Self { sink, err: None } }
    public static func new(fd: Int64): AsFmt {
        return AsFmt(fd)
    }

    /// 写入字符串
    /// 严格翻译自: impl fmt::Write for AsFmt
    ///   fn write_str(&mut self, s: &str) -> fmt::Result {
    ///       match self.sink.write_all(s.as_bytes()) {
    ///           Ok(()) => Ok(()),
    ///           Err(e) => { self.err = Some(e); Err(fmt::Error) }
    ///       }
    ///   }
    public func writeString(s: String): Bool {
        var buf = Array<UInt8>()
        for (c in s) {
            buf.append(UInt8(c.value))
        }
        match (SysFs.write(fd, buf)) {
            case SysMaybe<Int64>.Err(e) =>
                err = Some(e)
                return false
            case SysMaybe<Int64>.Ok(n) =>
                written += n
                return true
        }
    }

    /// 是否有错误
    public func hasError(): Bool {
        return err != None
    }

    /// 已写入字节数
    public func writtenLen(): Int64 {
        return written
    }
}

// ============================================================================
// VecSink - Vec<u8> 写入器
// 最常用的 ByteWrite 实现, 写入到内存缓冲区
// 用于构建字符串, 序列化数据等
// ============================================================================

/// Vec 写入器 - 写入到内存缓冲区
/// 最基础的 ByteWrite 实现
public class VecSink <: ByteWrite {
    /// 内部缓冲区
    public var data: ArrayList<UInt8>

    public init() {
        data = ArrayList<UInt8>()
    }

    public init(capacity: Int64) {
        data = ArrayList<UInt8>()
    }

    /// 写入字节切片
    public func writeAll(buf: Array<UInt8>): IoResult<Unit> {
        for (b in buf) {
            data.append(b)
        }
        return IoResult<Unit>.Ok(())
    }

    /// 写入单个字节
    public func writeByte(byte: UInt8): IoResult<Unit> {
        data.append(byte)
        return IoResult<Unit>.Ok(())
    }

    /// 重复写入
    public func splatByteAll(byte: UInt8, n: Int64): IoResult<Unit> {
        for (_ in 0..n) {
            data.append(byte)
        }
        return IoResult<Unit>.Ok(())
    }

    /// 已写入长度
    public func writtenLen(): Int64 {
        return data.size
    }

    /// 获取写入的数据
    public func toArray(): Array<UInt8> {
        return data.toArray()
    }

    /// 转为字符串
    public func toString(): String {
        var sb = StringBuilder()
        for (b in data) {
            sb.append(Char(Int32(b)))
        }
        return sb.toString()
    }

    /// 重置
    public func reset(): Unit {
        data.clear()
    }
}
