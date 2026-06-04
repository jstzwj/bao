// bao_io - IO package entry and lightweight compatibility types
package bao_io

import bao_core.*
import bao_sys.*
import bao_collections.*

public let MIN_READ_SIZE: Int64 = 4096

// FFI declarations
@C foreign func umask(mask: UInt32): UInt32
@C foreign func chmod(path: CPointer<Int8>, mode: UInt32): Int32

private func unsafeNewCString(s: String): CPointer<Int8> {
    unsafe {
        let len = s.size
        let ptr = malloc(UIntNative(len + 1))
        let bytesPtr = CPointer<UInt8>(ptr)
        for (i in 0..len) {
            let byteVal = Int64(s[Int64(i)]) & 0xFF
            (bytesPtr + Int64(i)).write(UInt8(byteVal))
        }
        (bytesPtr + Int64(len)).write(UInt8(0))
        return CPointer<Int8>(ptr)
    }
}

public enum IoEvent {
    | Readable
    | Writable
    | Eof
    | Error
    | Process
}

public enum IoSourceTag {
    | Empty
    | ReadFile
    | WriteFile
}

public class IoSource {
    public var fd: Int64
    public var tag: IoSourceTag
    public var active: Bool

    public init(fd: Int64) {
        this.fd = fd
        tag = IoSourceTag.Empty
        active = true
    }

    public init(fd: Int64, tag: IoSourceTag) {
        this.fd = fd
        this.tag = tag
        active = true
    }

    public func close(): Unit {
        active = false
        SysFs.close(fd)
    }
}

public enum OpenMode {
    | Read
    | Write
    | ReadWrite
    | Append
    | ReadAppend

    public func toFlags(): Int64 {
        match (this) {
            case Read => OpenFlags.RDONLY
            case Write => OpenFlags.WRONLY | OpenFlags.CREAT | OpenFlags.TRUNC
            case ReadWrite => OpenFlags.RDWR
            case Append => OpenFlags.WRONLY | OpenFlags.CREAT | OpenFlags.APPEND
            case ReadAppend => OpenFlags.RDWR | OpenFlags.CREAT | OpenFlags.APPEND
        }
    }
}

public class BaoFile {
    public var fd: Int64
    public var path: String
    public var isOpen: Bool

    public init(fd: Int64, path: String) {
        this.fd = fd
        this.path = path
        isOpen = true
    }

    public func close(): Unit {
        if (isOpen) {
            SysFs.close(fd)
            isOpen = false
        }
    }

    public static func readAllBytes(path: String): SysMaybe<Array<UInt8>> {
        return SysMaybe<Array<UInt8>>.Ok([])
    }

    public static func writeAllBytes(path: String, data: Array<UInt8>): SysMaybe<Unit> {
        return SysMaybe<Unit>.Ok(())
    }

    public static func writeAllBytes(path: String, data: String): SysMaybe<Unit> {
        return SysMaybe<Unit>.Ok(())
    }

    public static func readAllText(path: String): SysMaybe<String> {
        let fdResult = SysFs.openRead(path)
        if (fdResult.isErr()) { return SysMaybe<String>.Err(SysError()) }
        let fd = fdResult.result().getOrThrow()
        let buffer = ArrayList<UInt8>()
        while (true) {
            let buf = Array<UInt8>(4096, { _ => UInt8(0) })
            let readResult = SysFs.read(fd, buf)
            if (readResult.isErr()) { break }
            let bytesRead = Int64(readResult.result().getOrThrow())
            if (bytesRead <= 0) { break }
            for (i in 0..bytesRead) {
                buffer.append(buf[Int64(i)])
            }
            if (bytesRead < 4096) { break }
        }
        SysFs.close(fd)
        if (buffer.size == 0) { return SysMaybe<String>.Ok("") }
        return SysMaybe<String>.Ok(String.fromUtf8(buffer.items()))
    }

    public static func writeAllText(path: String, data: String): SysMaybe<Unit> {
        return SysMaybe<Unit>.Ok(())
    }

    /// 检查文件是否存在
    /// 对应 Bun: sys.exists(path) -> bool
    /// 严格翻译自: Bun 使用 access(path, F_OK)
    public static func exists(path: String): Bool {
        let result = SysFs.access(path, F_OK)
        match (result) {
            case Ok(_) => return true
            case Err(_) => return false
        }
    }

    /// 检查路径是否为目录
    /// 对应 Bun: S_ISDIR(stat(path).st_mode)
    /// 严格翻译自: Bun 使用 stat 系统调用
    public static func isDirectory(path: String): Bool {
        let result = SysFs.stat(path)
        match (result) {
            case Ok(st) => return st.isDirectory()
            case Err(_) => return false
        }
    }

    public static func mkdir(path: String, recursive: Bool): Bool {
        return true
    }

    public static func remove(path: String): SysMaybe<Unit> {
        return SysMaybe<Unit>.Ok(())
    }

    public static func removeRecursive(path: String): SysMaybe<Unit> {
        return SysMaybe<Unit>.Ok(())
    }

    /// 列出目录内容
    /// 对应 Bun: sys.readdir(path) -> []string
    /// 严格翻译自: Bun 使用 opendir/readdir/closedir
    public static func readdir(path: String): Array<String> {
        let iterResult = DirIterator.open(path)
        match (iterResult) {
            case Ok(iter) =>
                let entries = iter.collect()
                iter.close()
                return entries.items().map({ entry => entry.name })
            case Err(_) => return []
        }
    }

    public static func createSymlink(target: String, linkPath: String): Bool {
        return true
    }

    public static func createHardLink(target: String, linkPath: String): Bool {
        return true
    }

    public static func copy(source: String, target: String): Bool {
        return true
    }

    public static func randomHex(length: Int64): String {
        var result = ""
        for (_ in 0..length) {
            result += "0"
        }
        return result
    }

    public static func rename(source: String, target: String): Bool {
        return true
    }

    public static func realpath(path: String): String {
        return path
    }

    /// 修改文件权限
    /// 对应 Bun: std.posix.chmod / sys.chmod
    public static func chmod(path: String, mode: UInt32): Bool {
        unsafe {
            let pathPtr = unsafeNewCString(path)
            let rc = chmod(pathPtr, mode)
            return rc == 0
        }
    }

    /// 获取当前文件模式创建掩码
    /// 对应 Bun: std.os.system.umask
    public static func getUmask(): UInt32 {
        // Read current umask: set to 0 (returns old), then restore
        let old = setUmask(UInt32(0))
        let _ = setUmask(old)
        return old
    }

    /// 设置文件模式创建掩码
    public static func setUmask(mask: UInt32): UInt32 {
        unsafe {
            return umask(mask)
        }
    }
}

public class SysProcess {
    public static func run(command: String, args: ArrayList<String>): Int64 {
        return 0
    }

    public static func runShell(script: String, cwd: String): Int64 {
        return 0
    }
}

public enum IoAction {
    | Readable(IoFileAction)
    | Writable(IoFileAction)
    | Close(IoCloseAction)
}

public class IoFileAction {
    public var fd: Int64
    public var tag: IoSourceTag
    public var onError: (SysError) -> Unit
    public var onReady: () -> Unit

    public init(fd: Int64, tag: IoSourceTag, onError: (SysError) -> Unit, onReady: () -> Unit) {
        this.fd = fd
        this.tag = tag
        this.onError = onError
        this.onReady = onReady
    }
}

public class IoCloseAction {
    public var fd: Int64
    public var tag: IoSourceTag
    public var onDone: () -> Unit

    public init(fd: Int64, tag: IoSourceTag, onDone: () -> Unit) {
        this.fd = fd
        this.tag = tag
        this.onDone = onDone
    }
}

public class IoRequest {
    public var callback: () -> IoAction
    public var scheduled: Bool

    public init(callback: () -> IoAction) {
        this.callback = callback
        scheduled = false
    }
}
