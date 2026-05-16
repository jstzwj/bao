// bao_sys - 文件操作封装
// 严格翻译自: src/sys/file.rs (以及 src/sys/File.zig)
//   Bun 的 File 是对 Fd 的高层封装，提供 read/write/seek/stat 等操作
//   与 std::fs::File 不同，File 是 Copy 且不会在 Drop 时自动关闭
//   调用者必须显式调用 close()
package bao_sys

import bao_core.*

// ============================================================================
// ReadToEndResult - 读取到末尾的结果
// 严格翻译自: src/sys/file.rs:18-30
//   pub struct ReadToEndResult { bytes: Vec<u8>, err: Option<Error> }
//   Zig 版本总是返回 buffer，即使有错误也保留部分读取的数据
// ============================================================================

/// 读取到末尾的结果 - 对应 Bun ReadToEndResult
/// 保留部分读取的数据，即使发生错误
public class ReadToEndResult {
    /// 读取到的字节
    public var bytes: Array<UInt8>
    /// 可能的错误
    public var err: ?SysError

    public init() {
        bytes = []
        err = None
    }

    public init(bytes: Array<UInt8>) {
        this.bytes = bytes
        this.err = None
    }

    public init(bytes: Array<UInt8>, err: SysError) {
        this.bytes = bytes
        this.err = Some(err)
    }

    /// 解包结果 - 对应 Bun ReadToEndResult.unwrap()
    /// 有错误时抛出，无错误时返回字节
    public func unwrap(): Array<UInt8> {
        if (let Some(e) = err) {
            throw BaoError(Int64(e.errno), e.toString())
        }
        return bytes
    }
}

// ============================================================================
// SizeHint - 读取大小提示
// 严格翻译自: src/sys/file.rs
//   File.zig 中 readToEndWithArrayList 接受大小提示
//   ProbablySmall: 保留 64 字节
//   UnknownSize: 通过 fstat 预分配
// ============================================================================

/// 读取大小提示 - 对应 Bun SizeHint
public enum SizeHint {
    | ProbablySmall   // 小文件，预分配 64 字节
    | UnknownSize     // 未知大小，通过 fstat 预分配
}

// ============================================================================
// SysFile - 文件句柄
// 严格翻译自: src/sys/file.rs:12-418
//   pub struct File { pub handle: Fd }
//   File 是 Copy 的薄封装，不在 Drop 时关闭
//   所有方法通过 Fd 委托到底层系统调用
// ============================================================================

/// 文件句柄 - 严格对应 Bun sys.File
/// Bun: #[repr(transparent)] pub struct File { pub handle: Fd }
/// 薄封装 Fd，不自动关闭，调用者必须显式 close()
public class SysFile {
    /// 底层文件描述符 - 对应 Bun File.handle: Fd
    public var handle: Int64

    public init(handle: Int64) {
        this.handle = handle
    }

    /// 从 FD 构造 - 对应 Bun File.from_fd(fd)
    public static func fromFd(fd: Int64): SysFile {
        return SysFile(fd)
    }

    /// 获取句柄 - 对应 Bun File.handle()
    public func fd(): Int64 {
        return handle
    }

    // ── 标准流 ──────────────────────────────────────────────────────

    /// 标准输入 - 对应 Bun File.stdin()
    public static func stdin(): SysFile {
        return SysFile(FdUtils.stdin())
    }

    /// 标准输出 - 对应 Bun File.stdout()
    public static func stdout(): SysFile {
        return SysFile(FdUtils.stdout())
    }

    /// 标准错误 - 对应 Bun File.stderr()
    public static func stderr(): SysFile {
        return SysFile(FdUtils.stderr())
    }

    // ── 打开文件 ──────────────────────────────────────────────────

    /// 打开文件 - 对应 Bun File.open(path, flags, mode)
    /// sys.zig: pub fn open(path, flags, mode) Maybe(File)
    public static func open(path: String, flags: Int64, mode: UInt32): SysMaybe<SysFile> {
        let result = SysFs.open(path, flags, mode)
        match (result) {
            case Ok(fd) => return SysMaybe<SysFile>.Ok(SysFile(fd))
            case Err(e) => return SysMaybe<SysFile>.Err(e)
        }
    }

    /// 打开文件读取 - 对应 Bun File.openat(dir, path, O.RDONLY, 0)
    public static func openRead(path: String): SysMaybe<SysFile> {
        return open(path, OpenFlags.RDONLY, FileMode.DEFAULT)
    }

    /// 创建文件 - 对应 Bun File.create(dir, path, truncate)
    /// File.zig: flags = O.WRONLY | O.CREAT | O.CLOEXEC | (truncate ? O.TRUNC : 0)
    public static func create(path: String, truncate: Bool): SysMaybe<SysFile> {
        var flags = OpenFlags.WRONLY | OpenFlags.CREAT | OpenFlags.CLOEXEC
        if (truncate) {
            flags = flags | OpenFlags.TRUNC
        }
        return open(path, flags, 0o666)
    }

    // ── 读取 ──────────────────────────────────────────────────────

    /// 读取 - 对应 Bun File.read(buf)
    /// sys.zig: pub fn read(fd, buf) Maybe(usize)
    public func read(buf: Array<UInt8>): SysMaybe<Int64> {
        return SysFs.read(handle, buf)
    }

    /// 写入 - 对应 Bun File.write(buf)
    /// sys.zig: pub fn write(fd, buf) Maybe(usize)
    public func write(data: Array<UInt8>): SysMaybe<Int64> {
        return SysFs.write(handle, data)
    }

    /// 全部写入 - 对应 Bun File.writeAll(buf)
    /// File.zig:118-133 - 循环写入直到全部完成
    public func writeAll(data: Array<UInt8>): SysMaybe<Unit> {
        var offset = 0
        while (offset < data.size) {
            // 构建剩余数据的子数组
            var remaining = Array<UInt8>(data.size - offset, item: 0)
            for (i in 0..remaining.size) {
                remaining[i] = data[offset + i]
            }
            let result = write(remaining)
            match (result) {
                case Err(e) => return SysMaybe<Unit>.Err(e)
                case Ok(n) =>
                    if (n == 0) {
                        // File.zig:118 - amt == 0 => return success
                        return SysMaybe<Unit>.Ok(())
                    }
                    offset += Int64(n)
            }
        }
        return SysMaybe<Unit>.Ok(())
    }

    /// 读取全部到缓冲区 - 对应 Bun File.readAll(buf)
    /// 循环读取直到缓冲区满或 EOF
    public func readAll(buf: Array<UInt8>): SysMaybe<Int64> {
        var totalRead: Int64 = 0
        while (Int64(buf.size) > totalRead) {
            // 创建从 totalRead 开始的子缓冲区
            var subBuf = Array<UInt8>(Int64(buf.size) - totalRead, item: 0)
            let result = read(subBuf)
            match (result) {
                case Err(e) => return SysMaybe<Int64>.Err(e)
                case Ok(n) =>
                    if (n == 0) { break }
                    // 复制读取到的数据
                    for (i in 0..n) {
                        buf[totalRead + i] = subBuf[i]
                    }
                    totalRead += n
            }
        }
        return SysMaybe<Int64>.Ok(totalRead)
    }

    /// 读取到末尾 - 对应 Bun File.readToEnd()
    /// File.zig: readToEnd - fstat 预分配大小
    public func readToEnd(): SysMaybe<Array<UInt8>> {
        var buf = ArrayList<UInt8>()
        // 8KB 初始缓冲区
        var chunk = Array<UInt8>(8192, item: 0)
        while (true) {
            let result = read(chunk)
            match (result) {
                case Err(e) => return SysMaybe<Array<UInt8>>.Err(e)
                case Ok(n) =>
                    if (n == 0) { break }
                    for (i in 0..n) {
                        buf.append(chunk[i])
                    }
            }
        }
        return SysMaybe<Array<UInt8>>.Ok(buf.toArray())
    }

    /// 读取小文件 - 对应 Bun File.readToEndSmall()
    /// File.zig:298 - probably_small，初始 64 字节
    public func readToEndSmall(): SysMaybe<Array<UInt8>> {
        var buf = ArrayList<UInt8>()
        var chunk = Array<UInt8>(64, item: 0)
        while (true) {
            let result = read(chunk)
            match (result) {
                case Err(e) => return SysMaybe<Array<UInt8>>.Err(e)
                case Ok(n) =>
                    if (n == 0) { break }
                    for (i in 0..n) {
                        buf.append(chunk[i])
                    }
                    // 下次使用更大的缓冲区
                    chunk = Array<UInt8>(16 * 1024, item: 0)
            }
        }
        return SysMaybe<Array<UInt8>>.Ok(buf.toArray())
    }

    // ── 定位 ──────────────────────────────────────────────────────

    /// 定位 - 对应 Bun File.seekTo(offset)
    /// std.fs.File.seekTo — lseek(SEEK_SET)
    public func seekTo(offset: UInt64): SysMaybe<Unit> {
        let result = SysFs.lseek(handle, Int64(offset), 0)  // SEEK_SET = 0
        match (result) {
            case Err(e) => return SysMaybe<Unit>.Err(e)
            case _ => return SysMaybe<Unit>.Ok(())
        }
    }

    /// 获取当前位置 - 对应 Bun File.getPos()
    /// std.fs.File.getPos — lseek(0, SEEK_CUR)
    public func getPos(): SysMaybe<UInt64> {
        let result = SysFs.lseek(handle, 0, 1)  // SEEK_CUR = 1
        match (result) {
            case Err(e) => return SysMaybe<UInt64>.Err(e)
            case Ok(pos) => return SysMaybe<UInt64>.Ok(UInt64(pos))
        }
    }

    /// 获取文件大小 - 对应 Bun File.getEndPos()
    /// File.zig:209 — getFileSize(self.handle)
    public func getEndPos(): SysMaybe<Int64> {
        // 通过 lseek 到末尾获取大小
        let currentPos = SysFs.lseek(handle, 0, 1)  // SEEK_CUR
        match (currentPos) {
            case Err(e) => return SysMaybe<Int64>.Err(e)
            case Ok(cur) =>
                let endPos = SysFs.lseek(handle, 0, 2)  // SEEK_END
                match (endPos) {
                    case Err(e) => return SysMaybe<Int64>.Err(e)
                    case Ok(end) =>
                        // 恢复原位置
                        let _ = SysFs.lseek(handle, cur, 0)
                        return SysMaybe<Int64>.Ok(end)
                }
        }
    }

    /// 获取 stat - 对应 Bun File.stat()
    /// sys.zig: pub fn fstat(fd) Maybe(Stat)
    public func stat(): SysMaybe<PosixStat> {
        unsafe {
            let statBuf = malloc(UIntNative(144))
            let rc = bao_sys.fstat(Int32(handle), statBuf)
            if (rc != 0) {
                free(statBuf)
                return SysMaybe<PosixStat>.Err(
                    SysError(UInt16(Int64(OS.errno())), SysTag.Fstat, handle)
                )
            }
            // 解析 struct stat 字段
            let stat = parseStatFromBuffer(statBuf)
            free(statBuf)
            return SysMaybe<PosixStat>.Ok(stat)
        }
    }

    /// 获取文件类型 - 对应 Bun File.kind()
    /// File.zig:220 — 通过 fstat 获取文件类型
    public func kind(): SysMaybe<FileKind> {
        let statResult = stat()
        match (statResult) {
            case Err(e) => return SysMaybe<FileKind>.Err(e)
            case Ok(s) =>
                let k = kindFromMode(s.mode)
                // File.zig:258 - 未识别的类型回退为 File
                match (k) {
                    case FileKind.Unknown => return SysMaybe<FileKind>.Ok(FileKind.File)
                    case _ => return SysMaybe<FileKind>.Ok(k)
                }
        }
    }

    /// 关闭 - 对应 Bun File.close()
    public func close(): SysMaybe<Unit> {
        return SysFs.close(handle)
    }

    /// 关闭并移动 - 对应 Bun File.closeAndMoveTo(src, dest)
    /// File.zig: 关闭后重命名文件
    public func closeAndMoveTo(src: String, dest: String): SysMaybe<Unit> {
        let renameResult = SysFs.rename(src, dest)
        let closeResult = close()
        match (renameResult) {
            case Err(e) => return SysMaybe<Unit>.Err(e)
            case _ => return closeResult
        }
    }

    // ── 一次性路径辅助 (open + io + close) ─────────────────────────

    /// 从文件路径读取 - 对应 Bun File.readFrom(dir, path)
    /// File.zig: open + read + close
    public static func readFrom(path: String): SysMaybe<Array<UInt8>> {
        let file = openRead(path)
        match (file) {
            case Err(e) => return SysMaybe<Array<UInt8>>.Err(e)
            case Ok(f) =>
                let bytes = f.readToEnd()
                let _ = f.close()
                return bytes
        }
    }

    /// 写入文件 - 对应 Bun File.writeFile(dir, path, data)
    /// File.zig:141 — mode 0o664; defer file.close()
    public static func writeFile(path: String, data: Array<UInt8>): SysMaybe<Unit> {
        let file = create(path, true)
        match (file) {
            case Err(e) => return SysMaybe<Unit>.Err(e)
            case Ok(f) =>
                let result = f.writeAll(data)
                let _ = f.close()
                return result
        }
    }

    /// 写入字符串到文件
    public static func writeFileString(path: String, text: String): SysMaybe<Unit> {
        var data = Array<UInt8>(text.size, item: 0)
        for (i in 0..text.size) {
            data[Int64(i)] = UInt8(Int32(text[Int64(i)].value) & 0xFF)
        }
        return writeFile(path, data)
    }
}

// ============================================================================
// FileKind - 文件类型
// 严格翻译自: src/sys/file.rs (kind_from_mode)
//   对应 std.fs.File.Kind
// ============================================================================

/// 文件类型 - 对应 Bun FileKind
/// 从 stat.st_mode 的 S_IFMT 位域解析
public enum FileKind {
    | File          // S_IFREG - 普通文件
    | Directory     // S_IFDIR - 目录
    | SymLink       // S_IFLNK - 符号链接
    | Block         // S_IFBLK - 块设备
    | Char          // S_IFCHR - 字符设备
    | Fifo          // S_IFIFO - 管道
    | Socket        // S_IFSOCK - 套接字
    | NamedPipe     // 命名管道 (Windows)
    | CharacterDevice  // 字符设备 (Windows)
    | Unknown       // 未识别

    /// 是否为普通文件
    public func isFile(): Bool {
        match (this) {
            case File => true
            case _ => false
        }
    }

    /// 是否为目录
    public func isDirectory(): Bool {
        match (this) {
            case Directory => true
            case _ => false
        }
    }
}

/// 从 st_mode 解析文件类型 - 对应 Bun kind_from_mode(mode)
/// sys.zig: S_ISREG/S_ISDIR/S_ISLNK/...
public func kindFromMode(mode: UInt32): FileKind {
    let kindBits = mode & 0xF000  // S_IFMT
    if (kindBits == 0x8000) { return FileKind.File }       // S_IFREG
    if (kindBits == 0x4000) { return FileKind.Directory }   // S_IFDIR
    if (kindBits == 0xA000) { return FileKind.SymLink }     // S_IFLNK
    if (kindBits == 0x6000) { return FileKind.Block }       // S_IFBLK
    if (kindBits == 0x2000) { return FileKind.Char }        // S_IFCHR
    if (kindBits == 0x1000) { return FileKind.Fifo }        // S_IFIFO
    if (kindBits == 0xC000) { return FileKind.Socket }      // S_IFSOCK
    return FileKind.Unknown
}

// ============================================================================
// 内部辅助函数
// ============================================================================

/// 从 malloc 分配的 stat buffer 解析 PosixStat
/// 在 Linux x86_64 上 struct stat 的布局:
///   st_dev (8), st_ino (8), st_nlink (8), st_mode (4), ...
///   实际偏移因平台不同而变化
internal func parseStatFromBuffer(buf: CPointer<Unit>): PosixStat {
    unsafe {
        let stat = PosixStat()
        // Linux x86_64 struct stat 布局:
        // st_dev:     offset 0,  8 bytes
        // st_ino:     offset 8,  8 bytes
        // st_nlink:   offset 16, 8 bytes
        // st_mode:    offset 24, 4 bytes
        // st_uid:     offset 28, 4 bytes
        // st_gid:     offset 32, 4 bytes
        // st_rdev:    offset 40, 8 bytes (pad before)
        // st_size:    offset 48, 8 bytes
        // st_blksize: offset 56, 8 bytes (actually long)
        // st_blocks:  offset 64, 8 bytes
        // st_atime:   offset 72, 16 bytes (sec + nsec)
        // st_mtime:   offset 88, 16 bytes
        // st_ctime:   offset 104, 16 bytes

        let base = CPointer<Int8>(buf)

        // st_dev - offset 0
        stat.dev = UInt64(CPointer<Int64>(buf).read())

        // st_ino - offset 8
        stat.ino = UInt64((CPointer<Int64>(buf) + IntNative(1)).read())

        // st_nlink - offset 16
        stat.nlink = UInt64((CPointer<Int64>(buf) + IntNative(2)).read())

        // st_mode - offset 24
        let modePtr = CPointer<Int32>(base + IntNative(24))
        stat.mode = UInt32(modePtr.read())

        // st_uid - offset 28
        let uidPtr = CPointer<Int32>(base + IntNative(28))
        stat.uid = UInt32(uidPtr.read())

        // st_gid - offset 32
        let gidPtr = CPointer<Int32>(base + IntNative(32))
        stat.gid = UInt32(gidPtr.read())

        // st_rdev - offset 40
        let rdevPtr = CPointer<Int64>(base + IntNative(40))
        stat.rdev = UInt64(rdevPtr.read())

        // st_size - offset 48
        let sizePtr = CPointer<Int64>(base + IntNative(48))
        stat.size = UInt64(sizePtr.read())

        // st_blksize - offset 56
        let blksizePtr = CPointer<Int64>(base + IntNative(56))
        stat.blksize = UInt64(blksizePtr.read())

        // st_blocks - offset 64
        let blocksPtr = CPointer<Int64>(base + IntNative(64))
        stat.blocks = UInt64(blocksPtr.read())

        // st_atime - offset 72 (sec: 8, nsec: 8)
        let atimeSecPtr = CPointer<Int64>(base + IntNative(72))
        stat.atimeSec = atimeSecPtr.read()
        let atimeNsecPtr = CPointer<Int64>(base + IntNative(80))
        stat.atimeNsec = atimeNsecPtr.read()

        // st_mtime - offset 88
        let mtimeSecPtr = CPointer<Int64>(base + IntNative(88))
        stat.mtimeSec = mtimeSecPtr.read()
        let mtimeNsecPtr = CPointer<Int64>(base + IntNative(96))
        stat.mtimeNsec = mtimeNsecPtr.read()

        // st_ctime - offset 104
        let ctimeSecPtr = CPointer<Int64>(base + IntNative(104))
        stat.ctimeSec = ctimeSecPtr.read()
        let ctimeNsecPtr = CPointer<Int64>(base + IntNative(112))
        stat.ctimeNsec = ctimeNsecPtr.read()

        return stat
    }
}
