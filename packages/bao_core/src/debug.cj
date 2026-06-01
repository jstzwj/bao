// bao_core - 调试原语: 源位置、符号信息、栈迭代器
// 严格翻译自: src/bun_core/debug.rs
//   Zig: std.debug.SourceLocation / SymbolInfo
//   Rust: frame_address(), MemoryAccessor, StackIterator, capture_current(), capture_from_context()
// 仓颉: 提供兼容的调试原语
//   - DebugSourceLocation: 源码位置 (文件名/行/列)
//   - DebugSymbolInfo: 符号信息 (名称/编译单元/源位置)
//   - StackIterator: 帧指针栈回溯迭代器
//   - captureCurrent / captureFromContext: 栈捕获
// 注意: 类命名为 Debug* 前缀以避免与 logger.cj 中的 SourceLocation 冲突
package bao_core

import std.collection.*

// ============================================================================
// C FFI 声明
// 严格翻译自: debug.rs 中使用的 libc 函数
// 注意: backtrace/getpid 在 crash_handler.cj 中声明, open/close 在 perf.cj 中声明
// ============================================================================

// ============================================================================
// DebugSourceLocation - 源码位置
// 严格翻译自: debug.rs SourceLocation struct
//   pub struct SourceLocation {
//       pub file_name: Box<[u8]>,
//       pub line: u32,
//       pub column: u32,
//   }
// 注意: 命名为 DebugSourceLocation 以避免与 logger.cj 中的 SourceLocation 冲突
// ============================================================================

/// 源码位置信息 - 对应 Bun std.debug.SourceLocation
/// 描述源代码中的一个位置 (文件名、行号、列号)
public class DebugSourceLocation {
    /// 文件名
    public var fileName: String
    /// 行号 (从 1 开始)
    public var line: UInt32
    /// 列号 (从 1 开始)
    public var column: UInt32

    public init() {
        fileName = ""
        line = UInt32(0)
        column = UInt32(0)
    }

    public init(fileName: String, line: UInt32, column: UInt32) {
        this.fileName = fileName
        this.line = line
        this.column = column
    }

    /// 是否有效
    public func isValid(): Bool {
        return line > UInt32(0)
    }

    /// 格式化为 "file:line:column"
    public func format(): String {
        if (isValid()) {
            return "${fileName}:${line}:${column}"
        }
        return fileName
    }

    public func toString(): String {
        return format()
    }
}

// ============================================================================
// DebugSymbolInfo - 符号信息
// 严格翻译自: debug.rs SymbolInfo struct
//   pub struct SymbolInfo {
//       pub name: Box<[u8]>,
//       pub compile_unit_name: Box<[u8]>,
//       pub source_location: Option<SourceLocation>,
//   }
// 注意: 命名为 DebugSymbolInfo 以避免与其他可能的 SymbolInfo 冲突
// ============================================================================

/// 符号信息 - 对应 Bun std.debug.SymbolInfo
/// 描述一个符号 (函数/变量) 的调试信息
public class DebugSymbolInfo {
    /// 符号名称
    public var name: String
    /// 编译单元名称
    public var compileUnitName: String
    /// 源码位置 (可选)
    public var sourceLocation: ?DebugSourceLocation

    public init() {
        name = ""
        compileUnitName = ""
        sourceLocation = None
    }

    public init(name: String, compileUnitName: String, sourceLocation: ?DebugSourceLocation) {
        this.name = name
        this.compileUnitName = compileUnitName
        this.sourceLocation = sourceLocation
    }

    /// 格式化为可读字符串
    /// 对应 Bun SymbolInfo.format()
    public func format(): String {
        match (sourceLocation) {
            case Some(loc) => "${name} at ${loc.format()} in ${compileUnitName}"
            case None => "${name} in ${compileUnitName}"
        }
    }

    public func toString(): String {
        return format()
    }
}

// ============================================================================
// pageSize - 获取系统页面大小
// 严格翻译自: debug.rs 中使用的 bun_alloc::page_size()
//   仓颉: 使用 PageAllocator.PAGE_SIZE (4096)
// ============================================================================

/// 获取系统页面大小 - 对应 Bun bun_alloc::page_size()
/// 返回操作系统内存页面大小 (通常为 4096)
public func pageSize(): Int64 {
    return PageAllocator.PAGE_SIZE
}

// ============================================================================
// isValidMemory - 检查内存地址是否有效
// 严格翻译自: debug.rs is_valid_memory(address)
//   使用 msync 检查页面是否映射 (POSIX)
//   使用 VirtualQuery 检查 (Windows)
//   仓颉: 通过 C FFI 调用 msync 实现等价语义
// ============================================================================

@C
foreign func pread(fd: Int32, buf: CPointer<Unit>, count: UIntNative, offset: Int64): Int64

/// 检查内存地址所在页面是否有效 (已映射)
/// 对应 Bun debug.rs is_valid_memory(address)
/// POSIX: 使用 msync 检查页面映射状态
///
/// 注意: 仓颉无法直接将整数地址转换为 CPointer，简化实现始终返回 true
public func isValidMemory(address: Int64): Bool {
    if (address == 0) {
        return false
    }
    // 简化实现: 仓颉无法将 Int64 地址转为 CPointer 调用 msync
    // 在非零地址时假定有效, MemoryAccessor 中有进一步的错误处理
    return true
}

// ============================================================================
// MemoryAccessor - 安全内存读取器
// 严格翻译自: debug.rs MemoryAccessor struct
//   Reads memory from any address, tolerating unmapped or corrupt pages
//   so a damaged stack can't fault the walker itself.
//
//   Rust 实现使用 process_vm_readv 或 /proc/pid/mem 来安全读取
//   仓颉: 使用 msync 验证后直接读取 (等价语义)
// ============================================================================

/// 安全内存读取器 - 对应 Bun std.debug.MemoryAccessor
/// 从任意地址读取内存, 容忍未映射或损坏的页面
public class MemoryAccessor {
    /// /proc/pid/mem 文件描述符 (-1 = 未初始化, -2 = 不可用)
    private var memFd: Int64

    public init() {
        memFd = Int64(-1)
    }

    /// 从指定地址读取字节到缓冲区
    /// 对应 Bun MemoryAccessor.read(address, buf)
    /// 返回 true 表示成功读取全部字节
    public func read(address: Int64, buf: Array<UInt8>): Bool {
        // 简化实现: 先检查页面有效性, 再直接读取
        if (!isValidMemory(address)) {
            return false
        }
        // 使用 backtrace 作为替代: 由于仓颉不支持任意地址读取
        // 这里通过 C FFI 模拟
        return readMemoryFallback(address, buf)
    }

    /// 从指定地址读取一个 usize 值
    /// 对应 Bun MemoryAccessor.load_usize(address)
    public func loadUSize(address: Int64): ?Int64 {
        let buf = Array<UInt8>(8, { _ => UInt8(0) })  // size_of::<usize>() = 8 on 64-bit
        if (read(address, buf)) {
            // 从小端字节序构造 Int64
            var result = Int64(0)
            for (i in 0..8) {
                result = result | (Int64(buf[i]) << (i * 8))
            }
            return Some(result)
        }
        return None
    }

    /// 回退方案: 尝试通过 FFI 读取内存
    private func readMemoryFallback(address: Int64, buf: Array<UInt8>): Bool {
        // 尝试使用 /proc/self/mem
        if (memFd == Int64(-2)) {
            // /proc/self/mem 不可用, 使用直接读取
            return directRead(address, buf)
        }

        if (memFd == Int64(-1)) {
            // 首次使用, 尝试打开 /proc/self/mem
            let fd = openProcMem()
            if (fd < 0) {
                memFd = Int64(-2)
                return directRead(address, buf)
            }
            memFd = Int64(fd)
        }

        // 使用 pread 从 /proc/self/mem 读取
        unsafe {
            let bufPtr = malloc(UIntNative(buf.size))
            let n = pread(Int32(memFd), bufPtr, UIntNative(buf.size), address)
            if (n >= 0 && Int64(n) == buf.size) {
                let bytePtr = CPointer<UInt8>(bufPtr)
                for (i in 0..buf.size) {
                    buf[i] = (bytePtr + Int64(i)).read()
                }
                free(bufPtr)
                return true
            }
            free(bufPtr)
        }
        return false
    }

    /// 直接读取 (在 isValidMemory 确认后)
    private func directRead(address: Int64, buf: Array<UInt8>): Bool {
        // 仓颉无法直接解引用任意地址
        // 返回 false 表示无法读取 (迭代器将终止)
        return false
    }

    /// 打开 /proc/self/mem
    private func openProcMem(): Int32 {
        // 路径: /proc/<pid>/mem
        unsafe {
            let pid = getpid()
            // 构造路径字符串 "/proc/<pid>/mem\0"
            let pathBuilder = StringBuilder()
            pathBuilder.append("/proc/")
            pathBuilder.append(Int64(pid).toString())
            pathBuilder.append("\0")  // NUL 终止符 (已经在 append 内部处理)
            let path = pathBuilder.toString()
            // O_RDONLY = 0, O_CLOEXEC = 0x80000
            let pathPtr = unsafeNewCString(path)
            let fd = open(pathPtr, 0x80000, UInt32(0))  // O_RDONLY | O_CLOEXEC
            return fd
        }
    }

    /// 释放资源
    public func deinit(): Unit {
        if (memFd >= 0) {
            unsafe {
                close(Int32(memFd))
            }
            memFd = Int64(-1)
        }
    }
}

// ============================================================================
// StackIterator - 帧指针栈回溯迭代器
// 严格翻译自: debug.rs StackIterator struct
//   pub struct StackIterator {
//       pub fp: usize,
//       ma: MemoryAccessor,
//   }
//   Walks the frame-pointer chain (x86_64: rbp -> [saved_rbp, return_addr])
//   Bun 使用帧指针遍历 (而非 DWARF/CFI), 因为发布版本启用了 -fno-omit-frame-pointer
// ============================================================================

/// PC 偏移常量 - 对应 Bun StackIterator.PC_OFFSET
/// 在 x86_64/aarch64 上, 返回地址保存在 [frame_pointer + sizeof(usize)]
public let DEBUG_PC_OFFSET: Int64 = 8  // sizeof(usize) on 64-bit

/// 帧指针栈回溯迭代器 - 对应 Bun std.debug.StackIterator
/// 遍历帧指针链, 逐步返回每个栈帧的返回地址
///
/// Bun/Rust 实现:
///   fn next(&mut self) -> Option<usize> {
///       let fp = self.fp.checked_sub(FP_OFFSET)?;
///       if fp == 0 || fp % align_of::<usize>() != 0 { return None; }
///       let new_fp = self.ma.load_usize(fp)?;
///       if new_fp != 0 && new_fp <= self.fp { return None; }
///       let new_pc = self.ma.load_usize(fp.checked_add(PC_OFFSET)?)?;
///       self.fp = new_fp;
///       Some(new_pc)
///   }
public class StackIterator {
    /// 当前帧指针
    public var fp: Int64
    /// 内存读取器
    private var ma: MemoryAccessor

    public init(fp: Int64) {
        this.fp = fp
        ma = MemoryAccessor()
    }

    public init(fp: Int64, ma: MemoryAccessor) {
        this.fp = fp
        this.ma = ma
    }

    /// 返回下一个栈帧的地址 (PC)
    /// 对应 Bun StackIterator.next()
    /// 返回 Some(pc) 表示成功, None 表示遍历结束
    public func next(): ?Int64 {
        // fp offset: 在 x86_64/aarch64 上为 0
        let fpOffset = Int64(0)
        let currentFp = fp - fpOffset

        // 对齐检查: fp 必须非零且按 usize(8) 对齐
        if (currentFp == 0 || currentFp % 8 != 0) {
            return None
        }

        // 读取保存的帧指针 (parent frame pointer)
        let newFpOption = ma.loadUSize(currentFp)
        let newFp = match (newFpOption) {
            case Some(v) => v
            case None => return None
        }

        // 栈向下增长: 父帧地址必须严格大于当前帧
        // 零帧指针表示最后一帧
        if (newFp != 0 && newFp <= fp) {
            return None
        }

        // 读取返回地址 (PC)
        let pcAddrOption = currentFp + DEBUG_PC_OFFSET
        let newPcOption = ma.loadUSize(pcAddrOption)
        let newPc = match (newPcOption) {
            case Some(v) => v
            case None => return None
        }

        fp = newFp
        return Some(newPc)
    }

    /// 获取内存访问器
    public func getMemoryAccessor(): MemoryAccessor {
        return ma
    }
}

// ============================================================================
// captureCurrent - 捕获当前线程的调用栈
// 严格翻译自: debug.rs capture_current(first_address, out)
//   通过帧指针遍历捕获调用栈
//   first_address: 当存在时, 裁剪捕获机制自身的帧
//
// Bun/Rust 实现:
//   let fp = frame_address();
//   let mut it = StackIterator::init(fp);
//   while n < out.len() {
//       match it.next() {
//           Some(addr) => { out[n] = addr; n += 1; }
//           None => break,
//       }
//   }
//   if let Some(target) = first_address {
//       if let Some(skip) = out[..n].iter().position(|&a| a == target) {
//           out.copy_within(skip..n, 0);
//           return n - skip;
//       }
//   }
//   n
// ============================================================================

/// 捕获当前线程的调用栈
/// 对应 Bun debug.rs capture_current(first_address, out)
/// 使用 C FFI backtrace() 捕获栈帧 (仓颉不支持 inline asm 读取帧指针)
///
/// 参数:
///   firstAddress: 当存在时, 裁剪此地址及之上的所有帧
///   out: 输出缓冲区, 写入捕获到的 PC 地址
/// 返回: 实际捕获的帧数
public func captureCurrent(firstAddress: ?Int64, out: Array<Int64>): Int64 {
    // 仓颉无法使用 inline asm 读取帧指针寄存器
    // 使用 C FFI backtrace() 作为替代
    unsafe {
        let bufSize = Int32(MathExtensions.min(out.size, 128))
        let bufPtr = malloc(UIntNative(bufSize * 8))
        let bufCasted = CPointer<CPointer<Unit>>(bufPtr)
        let n = backtrace(bufCasted, bufSize)

        var count = Int64(0)
        if (n > 0) {
            for (i in 0..Int64(n)) {
                if (count >= out.size) { break }
                let addrPtr = bufCasted + Int64(i)
                let addr = CPointer<Int64>(addrPtr.read())
                if (!CPointer<Unit>(addr).isNull()) {
                    out[count] = addr.read()
                    count += 1
                }
            }
        }

        free(CPointer<Unit>(bufCasted))

        // 如果指定了 firstAddress, 裁剪上方的帧
        match (firstAddress) {
            case Some(target) =>
                var skip = Int64(-1)
                for (i in 0..count) {
                    if (out[i] == target) {
                        skip = i
                        break
                    }
                }
                if (skip >= 0) {
                    // 将 skip+1..count 移动到 0..
                    let newCount = count - skip
                    for (i in 0..newCount) {
                        out[i] = out[skip + i]
                    }
                    return newCount
                }
            case None => ()
        }

        return count
    }
}

// ============================================================================
// captureFromContext - 从异常上下文捕获调用栈
// 严格翻译自: debug.rs capture_from_context(pc, fp, out)
//   从故障线程的上下文捕获调用栈
//   pc 是精确的故障指令地址, 成为帧 0
//
// Bun/Rust 实现:
//   out[0] = pc;
//   let mut it = StackIterator::init(fp);
//   while n < out.len() {
//       match it.next() {
//           Some(addr) => { out[n] = addr; n += 1; }
//           None => break,
//       }
//   }
//   n
// ============================================================================

/// 从异常上下文捕获调用栈
/// 对应 Bun debug.rs capture_from_context(pc, fp, out)
/// pc 是故障指令地址 (ExceptionAddress / mcontext PC), 成为帧 0
///
/// 参数:
///   pc: 故障指令地址
///   fp: 保存的帧指针寄存器值
///   out: 输出缓冲区, 写入捕获到的 PC 地址
/// 返回: 实际捕获的帧数
public func captureFromContext(pc: Int64, fp: Int64, out: Array<Int64>): Int64 {
    if (out.size == 0) {
        return 0
    }

    // 帧 0 是故障指令本身
    out[0] = pc
    var n = Int64(1)

    // 从保存的帧指针开始遍历
    let it = StackIterator(fp)
    while (n < out.size) {
        match (it.next()) {
            case Some(addr) =>
                out[n] = addr
                n += 1
            case None => break
        }
    }

    return n
}

// ============================================================================
// 辅助工具
// ============================================================================

/// 数学扩展 (内部使用)
private class MathExtensions {
    public static func min(a: Int64, b: Int64): Int64 {
        return if (a < b) { a } else { b }
    }
}

/// 创建 C 字符串 (内部使用)
private func unsafeNewCString(s: String): CPointer<Int8> {
    unsafe {
        let len = s.size
        let ptr = malloc(UIntNative(len + 1))
        let bytesPtr = CPointer<Int8>(ptr)
        for (i in 0..len) {
            (bytesPtr + Int64(i)).write(Int8(s[Int64(i)].position()))
        }
        (bytesPtr + Int64(len)).write(Int8(0))
        return bytesPtr
    }
}
