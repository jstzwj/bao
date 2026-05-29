// bao_io - IO package entry and lightweight compatibility types
package bao_io

import bao_core.*
import bao_sys.*
import bao_collections.*

public let MIN_READ_SIZE: Int64 = 4096

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
        return SysMaybe<String>.Ok("")
    }

    public static func writeAllText(path: String, data: String): SysMaybe<Unit> {
        return SysMaybe<Unit>.Ok(())
    }

    public static func exists(path: String): Bool {
        return false
    }

    public static func isDirectory(path: String): Bool {
        return false
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

    public static func readdir(path: String): Array<String> {
        return []
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
