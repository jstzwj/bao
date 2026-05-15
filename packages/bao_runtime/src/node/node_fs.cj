// 文件系统操作模块（主入口）
// 对应 Bun: src/runtime/node/node_fs.zig
// 严格翻译自: src/runtime/node/node_fs.zig
package bao_runtime

import bao_core.*
import bao_sys.*

// ============================================================================
// NodeFS — Node.js 文件系统 API 兼容层
// 对应 Bun: src/runtime/node/node_fs.zig - NodeFS
// ============================================================================
public class NodeFs {
    // ========================================================================
    // 同步 API
    // ========================================================================

    // 打开文件
    public static func openSync(path: String, flags: Int32, mode: UInt32 = 438): Int32 {
        return System.open(path, flags: flags, mode: mode)
    }

    // 关闭文件
    public static func closeSync(fd: Int32): Unit {
        System.close(fd)
    }

    // 读取文件
    public static func readSync(fd: Int32, buffer: Array<UInt8>, offset: Int64, length: Int64, position: Int64): Int64 {
        return System.readFd(fd, buffer: buffer, offset: offset, length: length, position: position)
    }

    // 写入文件
    public static func writeSync(fd: Int32, buffer: Array<UInt8>, offset: Int64, length: Int64, position: Int64): Int64 {
        return System.writeFd(fd, buffer: buffer, offset: offset, length: length, position: position)
    }

    // 读取整个文件
    public static func readFileSync(path: String): Array<UInt8> {
        return System.readFile(path)
    }

    // 写入整个文件
    public static func writeFileSync(path: String, data: Array<UInt8>): Unit {
        System.writeFile(path, data: data)
    }

    // 追加文件
    public static func appendFileSync(path: String, data: Array<UInt8>): Unit {
        System.appendFile(path, data: data)
    }

    // 获取文件状态
    public static func statSync(path: String, bigint: Bool = false): Stats {
        let result = System.stat(path)
        if (result == None) {
            throw NodeError(code: "ENOENT", message: "ENOENT: no such file or directory, stat '${path}'")
        }
        return result!
    }

    // 获取文件描述符状态
    public static func fstatSync(fd: Int32, bigint: Bool = false): Stats {
        let result = System.fstat(fd)
        if (result == None) {
            throw NodeError(code: "EBADF", message: "EBADF: bad file descriptor, fstat")
        }
        return result!
    }

    // 获取符号链接状态
    public static func lstatSync(path: String, bigint: Bool = false): Stats {
        let result = System.lstat(path)
        if (result == None) {
            throw NodeError(code: "ENOENT", message: "ENOENT: no such file or directory, lstat '${path}'")
        }
        return result!
    }

    // 读取目录
    public static func readdirSync(path: String, recursive: Bool = false): Array<String> {
        return System.readdir(path)
    }

    // 读取目录（带详细信息）
    public static func readdirSyncWithTypes(path: String, recursive: Bool = false): Array<Dirent> {
        return System.readdirWithTypes(path)
    }

    // 创建目录
    public static func mkdirSync(path: String, mode: UInt32 = 511, recursive: Bool = false): ?String {
        if (recursive) {
            return System.mkdirRecursive(path, mode: mode)
        }
        let ok = System.mkdir(path, mode: mode)
        if (!ok) {
            throw NodeError(code: "EEXIST", message: "EEXIST: file already exists, mkdir '${path}'")
        }
        return None
    }

    // 删除目录
    public static func rmdirSync(path: String): Unit {
        let ok = System.rmdir(path)
        if (!ok) {
            throw NodeError(code: "ENOENT", message: "ENOENT: no such file or directory, rmdir '${path}'")
        }
    }

    // 删除文件
    public static func unlinkSync(path: String): Unit {
        let ok = System.unlink(path)
        if (!ok) {
            throw NodeError(code: "ENOENT", message: "ENOENT: no such file or directory, unlink '${path}'")
        }
    }

    // 重命名
    public static func renameSync(oldPath: String, newPath: String): Unit {
        let ok = System.rename(oldPath, to: newPath)
        if (!ok) {
            throw NodeError(code: "ENOENT", message: "ENOENT: no such file or directory, rename '${oldPath}' -> '${newPath}'")
        }
    }

    // 复制文件
    public static func copyFileSync(src: String, dest: String, mode: Int32 = 0): Unit {
        let ok = System.copyFile(src, to: dest)
        if (!ok) {
            throw NodeError(code: "ENOENT", message: "ENOENT: no such file or directory, copyfile '${src}' -> '${dest}'")
        }
    }

    // 检查文件访问权限
    public static func accessSync(path: String, mode: Int32 = 0): Unit {
        let ok = System.access(path, mode: UInt32(mode))
        if (!ok) {
            throw NodeError(code: "EACCES", message: "EACCES: permission denied, access '${path}'")
        }
    }

    // 修改权限
    public static func chmodSync(path: String, mode: UInt32): Unit {
        let ok = System.chmod(path, mode: mode)
        if (!ok) {
            throw NodeError(code: "EPERM", message: "EPERM: operation not permitted, chmod '${path}'")
        }
    }

    // 读取符号链接
    public static func readlinkSync(path: String): String {
        let target = System.readlink(path)
        if (target == None) {
            throw NodeError(code: "ENOENT", message: "ENOENT: no such file or directory, readlink '${path}'")
        }
        return target!
    }

    // 创建符号链接
    public static func symlinkSync(target: String, path: String, type: String = "file"): Unit {
        let ok = System.symlink(target, to: path)
        if (!ok) {
            throw NodeError(code: "EPERM", message: "EPERM: operation not permitted, symlink '${target}' -> '${path}'")
        }
    }

    // 获取真实路径
    public static func realpathSync(path: String): String {
        let resolved = System.realpath(path)
        if (resolved == None) {
            throw NodeError(code: "ENOENT", message: "ENOENT: no such file or directory, realpath '${path}'")
        }
        return resolved!
    }

    // 截断文件
    public static func truncateSync(path: String, len: Int64 = 0): Unit {
        let ok = System.truncate(path, length: len)
        if (!ok) {
            throw NodeError(code: "ENOENT", message: "ENOENT: no such file or directory, truncate '${path}'")
        }
    }

    // 检查文件是否存在
    public static func existsSync(path: String): Bool {
        return System.access(path, mode: 0)
    }
}
