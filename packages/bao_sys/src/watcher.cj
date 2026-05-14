// bao_sys - 文件监视
// 严格翻译自: src/watcher/ (Bun 的文件监视模块)
//   Bun 使用 inotify (Linux) / kqueue (macOS) 监视文件变化
//   仓颉通过 C FFI 调用 inotify
package bao_sys

import bao_core.*

// ============================================================================
// inotify C FFI 声明 (Linux)
// ============================================================================

@C
foreign func inotify_init(): Int32
@C
foreign func inotify_init1(flags: Int32): Int32
@C
foreign func inotify_add_watch(fd: Int32, pathname: CPointer<Int8>, mask: UInt32): Int32
@C
foreign func inotify_rm_watch(fd: Int32, wd: Int32): Int32

// ============================================================================
// inotify 常量
// ============================================================================

/// inotify 事件掩码 - 对应 inotify.h
public class InotifyMask {
    public static let IN_ACCESS: UInt32 = 0x00000001
    public static let IN_MODIFY: UInt32 = 0x00000002
    public static let IN_ATTRIB: UInt32 = 0x00000004
    public static let IN_CLOSE_WRITE: UInt32 = 0x00000008
    public static let IN_CLOSE_NOWRITE: UInt32 = 0x00000010
    public static let IN_CLOSE: UInt32 = 0x00000018
    public static let IN_OPEN: UInt32 = 0x00000020
    public static let IN_MOVED_FROM: UInt32 = 0x00000040
    public static let IN_MOVED_TO: UInt32 = 0x00000080
    public static let IN_MOVE: UInt32 = 0x000000C0
    public static let IN_CREATE: UInt32 = 0x00000100
    public static let IN_DELETE: UInt32 = 0x00000200
    public static let IN_DELETE_SELF: UInt32 = 0x00000400
    public static let IN_MOVE_SELF: UInt32 = 0x00000800
    public static let IN_ISDIR: UInt32 = 0x40000000
    public static let IN_NONBLOCK: UInt32 = 0x00000800
    public static let IN_CLOEXEC: UInt32 = 0x02000000
}

// ============================================================================
// FileWatchEvent - 文件监视事件
// ============================================================================

/// 文件变化类型
public enum FileChangeType {
    | Created     // 文件创建
    | Modified    // 文件修改
    | Deleted     // 文件删除
    | Renamed     // 文件重命名 (新名称)
    | RenamedFrom // 文件重命名 (旧名称)
    | AttributeChanged  // 属性变化
}

/// 文件监视事件
public class FileWatchEvent {
    /// 事件类型
    public var changeType: FileChangeType
    /// 文件名
    public var fileName: String
    /// 是否为目录
    public var isDirectory: Bool

    public init(changeType: FileChangeType, fileName: String, isDirectory: Bool) {
        this.changeType = changeType
        this.fileName = fileName
        this.isDirectory = isDirectory
    }
}

// ============================================================================
// FileWatcher - 文件监视器
// 严格翻译自: src/watcher/
// ============================================================================

/// 文件监视器 - 对应 Bun FileWatcher
/// 使用 Linux inotify 监视文件系统变化
public class FileWatcher {
    /// inotify 文件描述符
    private var inotifyFd: Int64
    /// 监视描述符到路径的映射
    private var watchDescriptors: HashMap<Int32, String>
    /// 路径到监视描述符的映射
    private var pathToWd: HashMap<String, Int32>
    /// 是否已关闭
    private var closed: Bool

    private init(fd: Int64) {
        this.inotifyFd = fd
        this.watchDescriptors = HashMap<Int32, String>()
        this.pathToWd = HashMap<String, Int32>()
        this.closed = false
    }

    /// 创建文件监视器
    /// 对应 Bun: watcher 创建
    public static func create(): SysMaybe<FileWatcher> {
        let fd = inotify_init1(Int32(InotifyMask.IN_NONBLOCK | InotifyMask.IN_CLOEXEC))
        if (fd < 0) {
            return SysMaybe<FileWatcher>.Err(
                SysError(UInt16(Int64(OS.errno())), SysTag.Open))
        }
        return SysMaybe<FileWatcher>.Ok(FileWatcher(Int64(fd)))
    }

    /// 添加监视路径
    /// 对应 Bun: FileWatcher.watch(path)
    public func watch(path: String): SysMaybe<Unit> {
        return watch(path, InotifyMask.IN_MODIFY | InotifyMask.IN_CREATE |
                         InotifyMask.IN_DELETE | InotifyMask.IN_MOVED_FROM |
                         InotifyMask.IN_MOVED_TO | InotifyMask.IN_ATTRIB)
    }

    /// 添加监视路径 (自定义事件掩码)
    public func watch(path: String, mask: UInt32): SysMaybe<Unit> {
        if (closed) {
            return SysMaybe<Unit>.Err(SysError(9, SysTag.Open))
        }
        // 已经在监视
        if (pathToWd.contains(path)) {
            return SysMaybe<Unit>.Ok(())
        }
        unsafe {
            let pathPtr = unsafeNewCString(path)
            let wd = inotify_add_watch(Int32(inotifyFd), pathPtr, mask)
            if (wd < 0) {
                return SysMaybe<Unit>.Err(
                    SysError(UInt16(Int64(OS.errno())), SysTag.Open, path))
            }
            watchDescriptors.put(wd, path)
            pathToWd.put(path, wd)
            return SysMaybe<Unit>.Ok(())
        }
    }

    /// 移除监视路径
    public func unwatch(path: String): SysMaybe<Unit> {
        let wd = pathToWd.get(path)
        if (let Some(wdVal) = wd) {
            let rc = inotify_rm_watch(Int32(inotifyFd), wdVal)
            watchDescriptors.remove(wdVal)
            pathToWd.remove(path)
            if (rc != 0) {
                return SysMaybe<Unit>.Err(
                    SysError(UInt16(Int64(OS.errno())), SysTag.Unlink, path))
            }
        }
        return SysMaybe<Unit>.Ok(())
    }

    /// 读取事件 (非阻塞)
    /// 对应 Bun: FileWatcher.getPendingEvents()
    public func readEvents(): ArrayList<FileWatchEvent> {
        var events = ArrayList<FileWatchEvent>()
        if (closed) { return events }
        unsafe {
            // inotify_event 大小: 16 + name (动态)
            // 读取多个事件
            let bufSize = 4096
            let buf = malloc(UIntNative(bufSize))
            let bytesRead = bao_sys.read(Int32(inotifyFd), buf, UIntNative(bufSize))
            if (Int64(bytesRead) < 0) {
                free(buf)
                return events
            }
            var offset: Int64 = 0
            while (offset + 16 <= Int64(bytesRead)) {
                // 解析 inotify_event:
                // wd: i32 (0-3), mask: u32 (4-7), cookie: u32 (8-11), len: u32 (12-15), name: [len]i8
                let wdPtr = CPointer<Int32>(buf) + IntNative(offset / 4)
                let wd = wdPtr.read()
                let maskPtr = CPointer<UInt32>(buf) + IntNative(offset / 4 + 1)
                let mask = maskPtr.read()
                let lenPtr = CPointer<UInt32>(buf) + IntNative(offset / 4 + 3)
                let nameLen = Int64(lenPtr.read())

                // 读取文件名
                var fileName = ""
                if (nameLen > 0) {
                    var sb = StringBuilder()
                    for (i in 0..nameLen) {
                        let bytePtr = CPointer<Int8>(buf) + IntNative(offset + 16 + i)
                        let b = Int32(bytePtr.read())
                        if (b == 0) { break }
                        sb.append(Char(b))
                    }
                    fileName = sb.toString()
                }

                let isDir = (mask & InotifyMask.IN_ISDIR) != 0
                let basePath = watchDescriptors.get(wd).getOrElse { "" }
                let fullPath = if (fileName.isEmpty) { basePath } else {
                    Path.join([basePath, fileName])
                }

                // 转换为 FileChangeType
                if (mask & InotifyMask.IN_CREATE != 0) {
                    events.append(FileWatchEvent(FileChangeType.Created, fullPath, isDir))
                } else if (mask & InotifyMask.IN_MODIFY != 0) {
                    events.append(FileWatchEvent(FileChangeType.Modified, fullPath, isDir))
                } else if (mask & InotifyMask.IN_DELETE != 0) {
                    events.append(FileWatchEvent(FileChangeType.Deleted, fullPath, isDir))
                } else if (mask & InotifyMask.IN_MOVED_TO != 0) {
                    events.append(FileWatchEvent(FileChangeType.Renamed, fullPath, isDir))
                } else if (mask & InotifyMask.IN_MOVED_FROM != 0) {
                    events.append(FileWatchEvent(FileChangeType.RenamedFrom, fullPath, isDir))
                } else if (mask & InotifyMask.IN_ATTRIB != 0) {
                    events.append(FileWatchEvent(FileChangeType.AttributeChanged, fullPath, isDir))
                }

                offset += 16 + nameLen
            }
            free(buf)
        }
        return events
    }

    /// 获取 inotify FD (用于 epoll 集成)
    public func fd(): Int64 {
        return inotifyFd
    }

    /// 关闭监视器
    public func close(): Unit {
        if (!closed) {
            bao_sys.close(Int32(inotifyFd))
            watchDescriptors.clear()
            pathToWd.clear()
            closed = true
        }
    }
}
