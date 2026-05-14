// bao_sys - 系统绑定
// 对应 Bun: src/sys/, src/spawn/
package bao_sys

import bao_core.*

// ============================================================================
// C FFI 系统调用绑定
// 对应 Bun: src/sys/lib.rs, src/spawn_sys/
// ============================================================================

// POSIX 系统调用 C FFI
@C
foreign func getenv(name: CPointer<Int8>): CPointer<Int8>
@C
foreign func setenv(name: CPointer<Int8>, value: CPointer<Int8>, overwrite: Int32): Int32
@C
foreign func unsetenv(name: CPointer<Int8>): Int32
@C
foreign func getcwd(buf: CPointer<Int8>, size: UIntNative): CPointer<Int8>
@C
foreign func chdir(path: CPointer<Int8>): Int32
@C
foreign func getpid(): Int32
@C
foreign func getppid(): Int32
@C
foreign func getuid(): UInt32
@C
foreign func getgid(): UInt32
@C
foreign func geteuid(): UInt32
@C
foreign func getegid(): UInt32
@C
foreign func kill(pid: Int32, sig: Int32): Int32
@C
foreign func fork(): Int32
@C
foreign func execvp(file: CPointer<Int8>, argv: CPointer<CPointer<Int8>>): Int32
@C
foreign func waitpid(pid: Int32, status: CPointer<Int32>, options: Int32): Int32
@C
foreign func pipe(fds: CPointer<Int32>): Int32
@C
foreign func dup2(oldfd: Int32, newfd: Int32): Int32
@C
foreign func close(fd: Int32): Int32
@C
foreign func read(fd: Int32, buf: CPointer<Unit>, count: UIntNative): UIntNative
@C
foreign func write(fd: Int32, buf: CPointer<Unit>, count: UIntNative): UIntNative
@C
foreign func open(path: CPointer<Int8>, flags: Int32, mode: UInt32): Int32
@C
foreign func stat(path: CPointer<Int8>, buf: CPointer<Unit>): Int32
@C
foreign func lstat(path: CPointer<Int8>, buf: CPointer<Unit>): Int32
@C
foreign func mkdir(path: CPointer<Int8>, mode: UInt32): Int32
@C
foreign func rmdir(path: CPointer<Int8>): Int32
@C
foreign func unlink(path: CPointer<Int8>): Int32
@C
foreign func rename(oldpath: CPointer<Int8>, newpath: CPointer<Int8>): Int32
@C
foreign func symlink(target: CPointer<Int8>, linkpath: CPointer<Int8>): Int32
@C
foreign func readlink(path: CPointer<Int8>, buf: CPointer<Int8>, size: UIntNative): UIntNative
@C
foreign func chmod(path: CPointer<Int8>, mode: UInt32): Int32
@C
foreign func chown(path: CPointer<Int8>, uid: UInt32, gid: UInt32): Int32
@C
foreign func access(path: CPointer<Int8>, mode: Int32): Int32
@C
foreign func errno_location(): CPointer<Int32>

// ============================================================================
// OS 接口
// 对应 Bun: src/sys/os.zig
// ============================================================================

/// 操作系统接口
public class OS {
    /// 获取环境变量
    public static func getEnv(name: String): ?String {
        unsafe {
            let namePtr = unsafeNewCString(name)
            let valuePtr = getenv(namePtr)
            if (valuePtr.isNull()) {
                return None
            }
            return Some(unsafeCStringToString(valuePtr))
        }
    }

    /// 设置环境变量
    public static func setEnv(name: String, value: String): Unit {
        unsafe {
            let namePtr = unsafeNewCString(name)
            let valuePtr = unsafeNewCString(value)
            setenv(namePtr, valuePtr, 1)
        }
    }

    /// 删除环境变量
    public static func unsetEnv(name: String): Unit {
        unsafe {
            let namePtr = unsafeNewCString(name)
            unsetenv(namePtr)
        }
    }

    /// 获取当前工作目录
    public static func cwd(): String {
        unsafe {
            let buf = malloc(4096)
            let result = getcwd(buf, UIntNative(4096))
            let str = unsafeCStringToString(result)
            free(buf)
            return str
        }
    }

    /// 改变工作目录
    public static func chdir(path: String): Unit {
        unsafe {
            let pathPtr = unsafeNewCString(path)
            let result = chdir(pathPtr)
            if (result != 0) {
                throw IoError(errno, "chdir failed: ${path}")
            }
        }
    }

    /// 获取进程 ID
    public static func pid(): Int64 {
        return Int64(getpid())
    }

    /// 获取父进程 ID
    public static func ppid(): Int64 {
        return Int64(getppid())
    }

    /// 获取用户 ID
    public static func uid(): UInt64 {
        return UInt64(getuid())
    }

    /// 获取组 ID
    public static func gid(): UInt64 {
        return UInt64(getgid())
    }

    /// 获取错误码
    public static func errno(): Int64 {
        unsafe {
            let ptr = errno_location()
            return Int64(ptr.read())
        }
    }

    /// 获取主机名
    public static func hostname(): String {
        unsafe {
            let buf = malloc(256)
            let namePtr = buf
            // foreign func gethostname(name: CPointer<Int8>, size: UIntNative): Int32
            // 简化: 通过环境变量获取
            let host = getEnv("HOSTNAME")
            free(buf)
            return host.getOrElse { "localhost" }
        }
    }
}

// ============================================================================
// 进程管理
// 对应 Bun: src/spawn/spawn.zig
// ============================================================================

/// 进程退出码
public enum ExitStatus {
    | Exited(Int64)
    | Signaled(Int64)
    | Running
}

/// 子进程结果
public class ChildProcess {
    public let pid: Int64
    public let stdin: ?Fd
    public let stdout: ?Fd
    public let stderr: ?Fd

    public init(pid: Int64, stdin: ?Fd, stdout: ?Fd, stderr: ?Fd) {
        this.pid = pid
        this.stdin = stdin
        this.stdout = stdout
        this.stderr = stderr
    }

    /// 等待进程完成
    public func wait(): ExitStatus {
        unsafe {
            var status: Int32 = 0
            let result = waitpid(Int32(pid), &status, 0)
            if (result < 0) {
                throw IoError(errno, "waitpid failed")
            }
            if ((status & 0x7F) == 0) {
                // 正常退出
                return ExitStatus.Exited(Int64((status >> 8) & 0xFF))
            }
            // 被信号终止
            return ExitStatus.Signaled(Int64(status & 0x7F))
        }
    }
}

/// 进程创建选项
public class SpawnOptions {
    public var args: Array<String>
    public var env: HashMap<String, String>
    public var cwd: ?String
    public var stdin: Stdio
    public var stdout: Stdio
    public var stderr: Stdio

    public init() {
        args = []
        env = HashMap<String, String>()
        cwd = None
        stdin = Stdio.Inherit
        stdout = Stdio.Inherit
        stderr = Stdio.Inherit
    }
}

/// 标准 IO 配置
public enum Stdio {
    | Inherit
    | Pipe
    | Null
}

/// 进程创建器
public class ProcessSpawner {
    /// 创建子进程
    public static func spawn(command: String, options: SpawnOptions): ChildProcess {
        unsafe {
            let pid = fork()
            if (pid < 0) {
                throw IoError(errno, "fork failed")
            }
            if (pid == 0) {
                // 子进程
                let pathPtr = unsafeNewCString(command)
                // 构建 argv
                var argv = Array<CPointer<Int8>>()
                argv.append(unsafeNewCString(command))
                for (arg in options.args) {
                    argv.append(unsafeNewCString(arg))
                }
                argv.append(CPointer<Int8>())  // NULL 结尾

                execvp(pathPtr, argv.toArray())
                // execvp 失败
                exit(127)
            }
            // 父进程
            return ChildProcess(
                pid: Int64(pid),
                stdin: None,
                stdout: None,
                stderr: None
            )
        }
    }
}

// ============================================================================
// C 字符串工具函数
// ============================================================================

/// 创建 C 字符串 (内部使用)
internal func unsafeNewCString(s: String): CPointer<Int8> {
    unsafe {
        let len = s.size
        let ptr = malloc(UIntNative(len + 1))
        let bytes = s.toArray()
        for (i in 0..len) {
            (ptr + IntNative(i)).write(Int8(bytes[i]))
        }
        (ptr + IntNative(len)).write(Int8(0))  // null 终止符
        return ptr
    }
}

/// C 字符串转仓颉字符串 (内部使用)
internal func unsafeCStringToString(ptr: CPointer<Int8>): String {
    unsafe {
        var len = 0
        while (!(ptr + IntNative(len)).read() == Int8(0)) {
            len += 1
        }
        var sb = StringBuilder()
        for (i in 0..len) {
            sb.append(Char(Int32((ptr + IntNative(i)).read())))
        }
        return sb.toString()
    }
}
