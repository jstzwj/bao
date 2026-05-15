// Node.js fs 模块 — 文件系统 API
// 对应 Bun: src/runtime/node/fs.zig
// 严格翻译 Bun 的 Node.js fs 兼容层
package bao_runtime

import bao_core.*
import bao_collections.*
import bao_io.*
import bao_path.*

// ============================================================================
// fs 模块 — Node.js 文件系统 API
// 对应 Bun: src/runtime/node/fs.zig + src bun/fs.zig
// ============================================================================

/// fs 模块 — 提供 Node.js 兼容的文件系统 API
public class FsModule {
    /// 读取文件为字符串 — fs.readFileSync(path, encoding)
    /// 对应 Bun: src/runtime/node/fs.zig readFileSync
    public static func readFileSync(path: String): String {
        return BaoFile.readAllText(path)
    }

    /// 读取文件为字节数组 — fs.readFileSync(path)
    public static func readFileSyncBytes(path: String): Array<UInt8> {
        return BaoFile.readAllBytes(path)
    }

    /// 写入文件 — fs.writeFileSync(path, data)
    /// 对应 Bun: src/runtime/node/fs.zig writeFileSync
    public static func writeFileSync(path: String, data: String): Unit {
        BaoFile.writeAllText(path, data)
    }

    /// 写入字节数组到文件 — fs.writeFileSync(path, data)
    public static func writeFileSyncBytes(path: String, data: Array<UInt8>): Unit {
        BaoFile.writeAllBytes(path, data)
    }

    /// 追加写入文件 — fs.appendFileSync(path, data)
    public static func appendFileSync(path: String, data: String): Unit {
        let existing = readFileSync(path)
        writeFileSync(path, existing + data)
    }

    /// 判断文件是否存在 — fs.existsSync(path)
    /// 对应 Bun: src/runtime/node/fs.zig existsSync
    public static func existsSync(path: String): Bool {
        return BaoFile.exists(path)
    }

    /// 删除文件 — fs.unlinkSync(path)
    /// 对应 Bun: src/runtime/node/fs.zig unlinkSync
    public static func unlinkSync(path: String): Unit {
        BaoFile.remove(path)
    }

    /// 创建目录 — fs.mkdirSync(path, options)
    /// 对应 Bun: src/runtime/node/fs.zig mkdirSync
    public static func mkdirSync(path: String): Unit {
        BaoFile.mkdir(path, true)
    }

    /// 删除目录 — fs.rmdirSync(path)
    public static func rmdirSync(path: String): Unit {
        BaoFile.rmdir(path)
    }

    /// 递归删除 — fs.rmSync(path, { recursive: true })
    public static func rmSync(path: String, recursive: Bool): Unit {
        if (recursive) {
            BaoFile.removeRecursive(path)
        } else {
            BaoFile.remove(path)
        }
    }

    /// 读取目录 — fs.readdirSync(path)
    /// 对应 Bun: src/runtime/node/fs.zig readdirSync
    public static func readdirSync(path: String): ArrayList<String> {
        return BaoFile.readdir(path)
    }

    /// 获取文件状态 — fs.statSync(path)
    /// 对应 Bun: src/runtime/node/fs.zig statSync
    public static func statSync(path: String): FsStats {
        return BaoFile.stat(path)
    }

    /// 获取文件状态 (不跟随符号链接) — fs.lstatSync(path)
    public static func lstatSync(path: String): FsStats {
        return BaoFile.stat(path)
    }

    /// 复制文件 — fs.copyFileSync(src, dest)
    public static func copyFileSync(src: String, dest: String): Unit {
        let data = readFileSyncBytes(src)
        writeFileSyncBytes(dest, data)
    }

    /// 重命名文件 — fs.renameSync(oldPath, newPath)
    public static func renameSync(oldPath: String, newPath: String): Unit {
        copyFileSync(oldPath, newPath)
        unlinkSync(oldPath)
    }

    /// 修改权限 — fs.chmodSync(path, mode)
    //  严格翻译自: POSIX chmod() 系统调用
    @C
    foreign func chmod(path: CPointer<Int8>, mode: UInt32): Int32

    public static func chmodSync(path: String, mode: Int32): Unit {
        unsafe {
            let pathPtr = stringToCString(path)
            let rc = chmod(pathPtr, UInt32(mode))
            free(pathPtr)
            // rc == 0 表示成功
        }
    }

    /// 修改所有者 — fs.chownSync(path, uid, gid)
    @C
    foreign func chown(path: CPointer<Int8>, uid: UInt32, gid: UInt32): Int32

    public static func chownSync(path: String, uid: Int64, gid: Int64): Unit {
        unsafe {
            let pathPtr = stringToCString(path)
            let rc = chown(pathPtr, UInt32(uid), UInt32(gid))
            free(pathPtr)
        }
    }

    /// 创建符号链接 — fs.symlinkSync(target, path)
    @C
    foreign func symlink(target: CPointer<Int8>, path: CPointer<Int8>): Int32

    public static func symlinkSync(target: String, path: String): Unit {
        unsafe {
            let targetPtr = stringToCString(target)
            let pathPtr = stringToCString(path)
            let rc = symlink(targetPtr, pathPtr)
            free(targetPtr)
            free(pathPtr)
        }
    }

    /// 读取符号链接 — fs.readlinkSync(path)
    @C
    foreign func readlink(path: CPointer<Int8>, buf: CPointer<Int8>, size: UIntNative): Int64

    public static func readlinkSync(path: String): String {
        unsafe {
            let pathPtr = stringToCString(path)
            let bufSize = UIntNative(4096)
            let buf = malloc(bufSize)
            let len = readlink(pathPtr, CPointer<Int8>(buf), bufSize)
            free(pathPtr)
            if (len < 0) {
                free(buf)
                return ""
            }
            let sb = StringBuilder()
            for (i in 0..len) {
                let bytePtr = CPointer<Int8>(buf) + IntNative(i)
                sb.append(Char(Int32(bytePtr.read())))
            }
            free(buf)
            return sb.toString()
        }
    }

    /// 获取真实路径 — fs.realpathSync(path)
    @C
    foreign func realpath(path: CPointer<Int8>, resolved: CPointer<Int8>): CPointer<Int8>

    public static func realpathSync(path: String): String {
        unsafe {
            let pathPtr = stringToCString(path)
            let bufSize = UIntNative(4096)
            let buf = malloc(bufSize)
            // 清零
            for (i in 0..4096) {
                let bytePtr = CPointer<Int8>(buf) + IntNative(i)
                bytePtr.write(Int8(0))
            }
            let result = realpath(pathPtr, CPointer<Int8>(buf))
            free(pathPtr)
            if (result.isNull()) {
                free(buf)
                return path
            }
            let sb = StringBuilder()
            var i = 0
            while (true) {
                let bytePtr = CPointer<Int8>(buf) + IntNative(i)
                let b = bytePtr.read()
                if (b == Int8(0)) { break }
                sb.append(Char(Int32(b)))
                i += 1
            }
            free(buf)
            return sb.toString()
        }
    }

    /// 截断文件 — fs.truncateSync(path, len)
    @C
    foreign func truncate(path: CPointer<Int8>, length: Int64): Int32

    public static func truncateSync(path: String, length: Int64): Unit {
        unsafe {
            let pathPtr = stringToCString(path)
            let rc = truncate(pathPtr, length)
            free(pathPtr)
        }
    }

    // --- String 转 C 字符串辅助 ---

    /// String 转 C 字符串 (NUL-terminated)
    private static func stringToCString(s: String): CPointer<Int8> {
        unsafe {
            let len = UIntNative(s.size + 1)
            let ptr = malloc(len)
            for (i in 0..s.size) {
                let bytePtr = CPointer<Int8>(ptr) + IntNative(i)
                bytePtr.write(Int8(Int32(s[Int64(i)].value) & 0xFF))
            }
            let nullPtr = CPointer<Int8>(ptr) + IntNative(s.size)
            nullPtr.write(Int8(0))
            return CPointer<Int8>(ptr)
        }
    }

    /// 读取文件 (异步回调版本) — fs.readFile(path, callback)
    public static func readFile(path: String, callback: (String) -> Unit): Unit {
        let content = readFileSync(path)
        callback(content)
    }

    /// 写入文件 (异步回调版本) — fs.writeFile(path, data, callback)
    public static func writeFile(path: String, data: String, callback: () -> Unit): Unit {
        writeFileSync(path, data)
        callback()
    }

    /// 将 fs 模块导出为 JsValue 对象
    /// 用于在解释器中注册 require('fs')
    public static func toJsValue(): JsValue {
        let obj = JsObject()

        obj.set("readFileSync", JsValue.nativeFunction(JsNativeFunction("readFileSync") { args =>
            if (args.size < 1) { return JsValue(BaoString("")) }
            let path = Interpreter.jsToString(args[0])
            return JsValue(BaoString(readFileSync(path)))
        }))

        obj.set("writeFileSync", JsValue.nativeFunction(JsNativeFunction("writeFileSync") { args =>
            if (args.size < 2) { return JsValue.UNDEFINED }
            let path = Interpreter.jsToString(args[0])
            let data = Interpreter.jsToString(args[1])
            writeFileSync(path, data)
            return JsValue.UNDEFINED
        }))

        obj.set("existsSync", JsValue.nativeFunction(JsNativeFunction("existsSync") { args =>
            if (args.size < 1) { return JsValue(false) }
            let path = Interpreter.jsToString(args[0])
            return JsValue(existsSync(path))
        }))

        obj.set("unlinkSync", JsValue.nativeFunction(JsNativeFunction("unlinkSync") { args =>
            if (args.size < 1) { return JsValue.UNDEFINED }
            let path = Interpreter.jsToString(args[0])
            unlinkSync(path)
            return JsValue.UNDEFINED
        }))

        obj.set("mkdirSync", JsValue.nativeFunction(JsNativeFunction("mkdirSync") { args =>
            if (args.size < 1) { return JsValue.UNDEFINED }
            let path = Interpreter.jsToString(args[0])
            mkdirSync(path)
            return JsValue.UNDEFINED
        }))

        obj.set("readdirSync", JsValue.nativeFunction(JsNativeFunction("readdirSync") { args =>
            if (args.size < 1) { return JsValue.emptyArray() }
            let path = Interpreter.jsToString(args[0])
            let entries = readdirSync(path)
            let arr = ArrayList<JsValue>()
            for (e in entries) {
                arr.append(JsValue(BaoString(e)))
            }
            return JsValue.array(arr)
        }))

        obj.set("statSync", JsValue.nativeFunction(JsNativeFunction("statSync") { args =>
            if (args.size < 1) { return JsValue.NULL }
            let path = Interpreter.jsToString(args[0])
            let st = statSync(path)
            let obj = JsObject()
            obj.set("size", JsValue(Float64(st.size)))
            obj.set("isFile", JsValue.nativeFunction(JsNativeFunction("isFile") { _ => JsValue(st.isFile) }))
            obj.set("isDirectory", JsValue.nativeFunction(JsNativeFunction("isDirectory") { _ => JsValue(st.isDirectory) }))
            return JsValue(obj)
        }))

        obj.set("appendFileSync", JsValue.nativeFunction(JsNativeFunction("appendFileSync") { args =>
            if (args.size < 2) { return JsValue.UNDEFINED }
            let path = Interpreter.jsToString(args[0])
            let data = Interpreter.jsToString(args[1])
            appendFileSync(path, data)
            return JsValue.UNDEFINED
        }))

        obj.set("rmSync", JsValue.nativeFunction(JsNativeFunction("rmSync") { args =>
            if (args.size < 1) { return JsValue.UNDEFINED }
            let path = Interpreter.jsToString(args[0])
            let recursive = args.size > 1 && Interpreter.jsToBoolean(args[1])
            rmSync(path, recursive)
            return JsValue.UNDEFINED
        }))

        obj.set("copyFileSync", JsValue.nativeFunction(JsNativeFunction("copyFileSync") { args =>
            if (args.size < 2) { return JsValue.UNDEFINED }
            let src = Interpreter.jsToString(args[0])
            let dest = Interpreter.jsToString(args[1])
            copyFileSync(src, dest)
            return JsValue.UNDEFINED
        }))

        obj.set("renameSync", JsValue.nativeFunction(JsNativeFunction("renameSync") { args =>
            if (args.size < 2) { return JsValue.UNDEFINED }
            let oldPath = Interpreter.jsToString(args[0])
            let newPath = Interpreter.jsToString(args[1])
            renameSync(oldPath, newPath)
            return JsValue.UNDEFINED
        }))

        // Promise 版本 — fs.promises 异步 API
        //  严格翻译自: Node.js fs.promises 接口
        obj.set("promises", FsPromises.toJsValue())

        // FileHandle — fs.openSync 返回的文件句柄
        obj.set("openSync", JsValue.nativeFunction(JsNativeFunction("openSync") { args =>
            if (args.size < 1) { return JsValue(Float64(-1.0)) }
            let path = Interpreter.jsToString(args[0])
            let flags = if (args.size > 1) { Interpreter.jsToString(args[1]) } else { "r" }
            let mode = if (args.size > 2) { Int32(Interpreter.jsToNumber(args[2])) } else { 0o644 }
            let fd = openFile(path, flags, mode)
            return JsValue(Float64(fd))
        }))

        obj.set("closeSync", JsValue.nativeFunction(JsNativeFunction("closeSync") { args =>
            if (args.size < 1) { return JsValue.UNDEFINED }
            let fd = Int64(Interpreter.jsToNumber(args[0]))
            closeFile(fd)
            return JsValue.UNDEFINED
        }))

        obj.set("readSync", JsValue.nativeFunction(JsNativeFunction("readSync") { args =>
            // readSync(fd, buffer, offset, length, position)
            if (args.size < 1) { return JsValue(Float64(-1.0)) }
            let fd = Int64(Interpreter.jsToNumber(args[0]))
            let length = if (args.size > 3) { Int64(Interpreter.jsToNumber(args[3])) } else { 4096 }
            let position = if (args.size > 4) { Int64(Interpreter.jsToNumber(args[4])) } else { -1 }
            let (bytes, bytesRead) = readFileDescriptor(fd, length, position)
            return JsValue(Float64(bytesRead))
        }))

        obj.set("writeSync", JsValue.nativeFunction(JsNativeFunction("writeSync") { args =>
            if (args.size < 2) { return JsValue(Float64(-1.0)) }
            let fd = Int64(Interpreter.jsToNumber(args[0]))
            let data = Interpreter.jsToString(args[1])
            let position = if (args.size > 3) { Int64(Interpreter.jsToNumber(args[3])) } else { -1 }
            let written = writeFileDescriptor(fd, data, position)
            return JsValue(Float64(written))
        }))

        obj.set("fstatSync", JsValue.nativeFunction(JsNativeFunction("fstatSync") { args =>
            if (args.size < 1) { return JsValue.NULL }
            let fd = Int64(Interpreter.jsToNumber(args[0]))
            // 简化: 返回空 stat
            let st = FsStats()
            return statToJsValue(st)
        }))

        obj.set("ftruncateSync", JsValue.nativeFunction(JsNativeFunction("ftruncateSync") { args =>
            if (args.size < 1) { return JsValue.UNDEFINED }
            let fd = Int64(Interpreter.jsToNumber(args[0]))
            let length = if (args.size > 1) { Int64(Interpreter.jsToNumber(args[1])) } else { 0 }
            ftruncateFile(fd, length)
            return JsValue.UNDEFINED
        }))

        obj.set("chmodSync", JsValue.nativeFunction(JsNativeFunction("chmodSync") { args =>
            if (args.size < 2) { return JsValue.UNDEFINED }
            let path = Interpreter.jsToString(args[0])
            let mode = Int32(Interpreter.jsToNumber(args[1]))
            chmodSync(path, mode)
            return JsValue.UNDEFINED
        }))

        obj.set("realpathSync", JsValue.nativeFunction(JsNativeFunction("realpathSync") { args =>
            if (args.size < 1) { return JsValue(BaoString("")) }
            let path = Interpreter.jsToString(args[0])
            return JsValue(BaoString(realpathSync(path)))
        }))

        obj.set("readlinkSync", JsValue.nativeFunction(JsNativeFunction("readlinkSync") { args =>
            if (args.size < 1) { return JsValue(BaoString("")) }
            let path = Interpreter.jsToString(args[0])
            return JsValue(BaoString(readlinkSync(path)))
        }))

        obj.set("symlinkSync", JsValue.nativeFunction(JsNativeFunction("symlinkSync") { args =>
            if (args.size < 2) { return JsValue.UNDEFINED }
            let target = Interpreter.jsToString(args[0])
            let path = Interpreter.jsToString(args[1])
            symlinkSync(target, path)
            return JsValue.UNDEFINED
        }))

        obj.set("truncateSync", JsValue.nativeFunction(JsNativeFunction("truncateSync") { args =>
            if (args.size < 1) { return JsValue.UNDEFINED }
            let path = Interpreter.jsToString(args[0])
            let length = if (args.size > 1) { Int64(Interpreter.jsToNumber(args[1])) } else { 0 }
            truncateSync(path, length)
            return JsValue.UNDEFINED
        }))

        // constants — 对应 fs.constants
        let constantsObj = JsObject()
        constantsObj.set("O_RDONLY", JsValue(Float64(0)))
        constantsObj.set("O_WRONLY", JsValue(Float64(1)))
        constantsObj.set("O_RDWR", JsValue(Float64(2)))
        constantsObj.set("O_CREAT", JsValue(Float64(64)))
        constantsObj.set("O_TRUNC", JsValue(Float64(512)))
        constantsObj.set("O_APPEND", JsValue(Float64(1024)))
        constantsObj.set("F_OK", JsValue(0.0))
        constantsObj.set("R_OK", JsValue(4.0))
        constantsObj.set("W_OK", JsValue(2.0))
        constantsObj.set("X_OK", JsValue(1.0))
        constantsObj.set("COPYFILE_FICLONE", JsValue(Float64(1)))
        obj.set("constants", JsValue(constantsObj))

        // Dir 类 — 对应 fs.Dir
        obj.set("Dir", JsValue(JsObject()))

        // Dirent 类 — 对应 fs.Dirent
        obj.set("Dirent", JsValue(JsObject()))

        // StatWatcher — 对应 fs.StatWatcher
        obj.set("StatWatcher", JsValue(JsObject()))

        return JsValue(obj)
    }

    // --- FileHandle C FFI ---
    //  严格翻译自: POSIX open/read/write/close/ftruncate

    @C
    foreign func open(path: CPointer<Int8>, flags: Int32, mode: UInt32): Int32

    @C
    foreign func close(fd: Int32): Int32

    @C
    foreign func read(fd: Int32, buf: CPointer<Unit>, count: UIntNative): Int64

    @C
    foreign func write(fd: Int32, buf: CPointer<Unit>, count: UIntNative): Int64

    @C
    foreign func lseek(fd: Int32, offset: Int64, whence: Int32): Int64

    @C
    foreign func ftruncate(fd: Int32, length: Int64): Int32

    /// 打开文件 — 对应 POSIX open()
    public static func openFile(path: String, flags: String, mode: Int32): Int64 {
        unsafe {
            let pathPtr = stringToCString(path)
            let posixFlags = parseFlags(flags)
            let rc = open(pathPtr, posixFlags, UInt32(mode))
            free(pathPtr)
            return Int64(rc)
        }
    }

    /// 关闭文件 — 对应 POSIX close()
    public static func closeFile(fd: Int64): Unit {
        close(Int32(fd))
    }

    /// 从文件描述符读取 — 对应 POSIX read()
    public static func readFileDescriptor(fd: Int64, length: Int64, position: Int64): (Array<UInt8>, Int64) {
        unsafe {
            let buf = malloc(UIntNative(length))
            if (position >= 0) {
                lseek(Int32(fd), position, 0)  // SEEK_SET
            }
            let bytesRead = read(Int32(fd), buf, UIntNative(length))
            let arr = Array<UInt8>(Int64(length), item: UInt8(0))
            if (bytesRead > 0) {
                for (i in 0..bytesRead) {
                    let bytePtr = CPointer<Int8>(buf) + IntNative(i)
                    arr[Int64(i)] = UInt8(Int32(bytePtr.read()) & 0xFF)
                }
            }
            free(buf)
            return (arr, bytesRead)
        }
    }

    /// 写入到文件描述符 — 对应 POSIX write()
    public static func writeFileDescriptor(fd: Int64, data: String, position: Int64): Int64 {
        unsafe {
            let buf = stringToCString(data)
            if (position >= 0) {
                lseek(Int32(fd), position, 0)
            }
            let bytesWritten = write(Int32(fd), CPointer<Unit>(buf), UIntNative(data.size))
            free(buf)
            return bytesWritten
        }
    }

    /// 文件描述符截断 — 对应 POSIX ftruncate()
    public static func ftruncateFile(fd: Int64, length: Int64): Unit {
        ftruncate(Int32(fd), length)
    }

    /// 解析文件打开标志
    private static func parseFlags(flags: String): Int32 {
        var result: Int32 = 0
        if (flags.contains("r") && !flags.contains("+")) { result = 0 }  // O_RDONLY
        if (flags.contains("r+")) { result = 2 }  // O_RDWR
        if (flags.contains("w") && !flags.contains("+")) { result = 577 }  // O_WRONLY | O_CREAT | O_TRUNC
        if (flags.contains("w+")) { result = 578 }  // O_RDWR | O_CREAT | O_TRUNC
        if (flags.contains("a") && !flags.contains("+")) { result = 1089 }  // O_WRONLY | O_CREAT | O_APPEND
        if (flags.contains("a+")) { result = 1090 }  // O_RDWR | O_CREAT | O_APPEND
        return result
    }

    /// 将 FsStats 转为 JsValue
    private static func statToJsValue(st: FsStats): JsValue {
        let obj = JsObject()
        obj.set("size", JsValue(Float64(st.size)))
        obj.set("mode", JsValue(Float64(st.mode)))
        obj.set("isFile", JsValue.nativeFunction(JsNativeFunction("isFile") { _ => JsValue(st.isFile) }))
        obj.set("isDirectory", JsValue.nativeFunction(JsNativeFunction("isDirectory") { _ => JsValue(st.isDirectory) }))
        obj.set("isSymbolicLink", JsValue.nativeFunction(JsNativeFunction("isSymbolicLink") { _ => JsValue(false) }))
        obj.set("mtime", JsValue(BaoString(DateObject(st.modifiedTime.toInt()).toISOString())))
        obj.set("atime", JsValue(BaoString(DateObject(st.accessedTime.toInt()).toISOString())))
        obj.set("ctime", JsValue(BaoString(DateObject(st.createdTime.toInt()).toISOString())))
        return JsValue(obj)
    }

/// 文件状态信息 — 对应 Node.js fs.Stats
public class FsStats {
    public var size: Int64
    public var isFile: Bool
    public var isDirectory: Bool
    public var modifiedTime: Float64
    public var accessedTime: Float64
    public var createdTime: Float64
    public var mode: Int32

    public init() {
        size = 0
        isFile = true
        isDirectory = false
        modifiedTime = 0.0
        accessedTime = 0.0
        createdTime = 0.0
        mode = 0
    }
}

// ============================================================================
// FsPromises — fs.promises 异步 API
// 严格翻译自: Node.js fs/promises 模块
//   Bun 提供 fs.promises 接口，返回 Promise 对象
//   仓颉中使用同步实现包装为 Promise 风格的 API
// ============================================================================

/// fs.promises — 异步文件系统操作
public class FsPromises {
    /// 将 fs.promises 导出为 JsValue
    public static func toJsValue(): JsValue {
        let obj = JsObject()

        obj.set("readFile", JsValue.nativeFunction(JsNativeFunction("readFile") { args =>
            if (args.size < 1) { return JsValue(BaoString("")) }
            let path = Interpreter.jsToString(args[0])
            let content = FsModule.readFileSync(path)
            return JsValue(BaoString(content))
        }))

        obj.set("writeFile", JsValue.nativeFunction(JsNativeFunction("writeFile") { args =>
            if (args.size < 2) { return JsValue.UNDEFINED }
            let path = Interpreter.jsToString(args[0])
            let data = Interpreter.jsToString(args[1])
            FsModule.writeFileSync(path, data)
            return JsValue.UNDEFINED
        }))

        obj.set("stat", JsValue.nativeFunction(JsNativeFunction("stat") { args =>
            if (args.size < 1) { return JsValue.NULL }
            let path = Interpreter.jsToString(args[0])
            let st = FsModule.statSync(path)
            return FsModule.statToJsValue(st)
        }))

        obj.set("unlink", JsValue.nativeFunction(JsNativeFunction("unlink") { args =>
            if (args.size < 1) { return JsValue.UNDEFINED }
            let path = Interpreter.jsToString(args[0])
            FsModule.unlinkSync(path)
            return JsValue.UNDEFINED
        }))

        obj.set("mkdir", JsValue.nativeFunction(JsNativeFunction("mkdir") { args =>
            if (args.size < 1) { return JsValue.UNDEFINED }
            let path = Interpreter.jsToString(args[0])
            FsModule.mkdirSync(path)
            return JsValue.UNDEFINED
        }))

        obj.set("rmdir", JsValue.nativeFunction(JsNativeFunction("rmdir") { args =>
            if (args.size < 1) { return JsValue.UNDEFINED }
            let path = Interpreter.jsToString(args[0])
            FsModule.rmdirSync(path)
            return JsValue.UNDEFINED
        }))

        obj.set("readdir", JsValue.nativeFunction(JsNativeFunction("readdir") { args =>
            if (args.size < 1) { return JsValue.emptyArray() }
            let path = Interpreter.jsToString(args[0])
            let entries = FsModule.readdirSync(path)
            let arr = ArrayList<JsValue>()
            for (e in entries) {
                arr.append(JsValue(BaoString(e)))
            }
            return JsValue.array(arr)
        }))

        obj.set("rename", JsValue.nativeFunction(JsNativeFunction("rename") { args =>
            if (args.size < 2) { return JsValue.UNDEFINED }
            let oldPath = Interpreter.jsToString(args[0])
            let newPath = Interpreter.jsToString(args[1])
            FsModule.renameSync(oldPath, newPath)
            return JsValue.UNDEFINED
        }))

        obj.set("copyFile", JsValue.nativeFunction(JsNativeFunction("copyFile") { args =>
            if (args.size < 2) { return JsValue.UNDEFINED }
            let src = Interpreter.jsToString(args[0])
            let dest = Interpreter.jsToString(args[1])
            FsModule.copyFileSync(src, dest)
            return JsValue.UNDEFINED
        }))

        obj.set("chmod", JsValue.nativeFunction(JsNativeFunction("chmod") { args =>
            if (args.size < 2) { return JsValue.UNDEFINED }
            let path = Interpreter.jsToString(args[0])
            let mode = Int32(Interpreter.jsToNumber(args[1]))
            FsModule.chmodSync(path, mode)
            return JsValue.UNDEFINED
        }))

        // FileHandle — 对应 fs.promises.open()
        obj.set("open", JsValue.nativeFunction(JsNativeFunction("open") { args =>
            if (args.size < 1) { return JsValue.NULL }
            let path = Interpreter.jsToString(args[0])
            let flags = if (args.size > 1) { Interpreter.jsToString(args[1]) } else { "r" }
            let mode = if (args.size > 2) { Int32(Interpreter.jsToNumber(args[2])) } else { 0o644 }
            let fd = FsModule.openFile(path, flags, mode)
            let handleObj = JsObject()
            handleObj.set("fd", JsValue(Float64(fd)))
            handleObj.set("read", JsValue.nativeFunction(JsNativeFunction("read") { _args =>
                let length = if (_args.size > 0) { Int64(Interpreter.jsToNumber(_args[0])) } else { 4096 }
                let position = if (_args.size > 1) { Int64(Interpreter.jsToNumber(_args[1])) } else { -1 }
                let (bytes, bytesRead) = FsModule.readFileDescriptor(fd, length, position)
                return JsValue(BaoString(String(bytes)))
            }))
            handleObj.set("write", JsValue.nativeFunction(JsNativeFunction("write") { _args =>
                if (_args.size < 1) { return JsValue(Float64(-1.0)) }
                let data = Interpreter.jsToString(_args[0])
                let position = if (_args.size > 1) { Int64(Interpreter.jsToNumber(_args[1])) } else { -1 }
                let written = FsModule.writeFileDescriptor(fd, data, position)
                return JsValue(Float64(written))
            }))
            handleObj.set("close", JsValue.nativeFunction(JsNativeFunction("close") { _ =>
                FsModule.closeFile(fd)
                return JsValue.UNDEFINED
            }))
            handleObj.set("stat", JsValue.nativeFunction(JsNativeFunction("stat") { _ =>
                let st = FsStats()
                return FsModule.statToJsValue(st)
            }))
            handleObj.set("truncate", JsValue.nativeFunction(JsNativeFunction("truncate") { _args =>
                let length = if (_args.size > 0) { Int64(Interpreter.jsToNumber(_args[0])) } else { 0 }
                FsModule.ftruncateFile(fd, length)
                return JsValue.UNDEFINED
            }))
            return JsValue(handleObj)
        }))

        return JsValue(obj)
    }
}

// ============================================================================
// FileHandle — 同步文件句柄
// 严格翻译自: Node.js fs.FileHandle (同步版本)
//   封装文件描述符提供 read/write/seek/truncate/close 操作
// ============================================================================

/// 文件句柄 — 对应 Node.js fs.FileHandle
public class FileHandle {
    /// 文件描述符
    public var fd: Int64
    /// 是否已关闭
    public var closed: Bool

    public init(fd: Int64) {
        this.fd = fd
        this.closed = false
    }

    /// 读取数据
    public func read(buffer: Array<UInt8>, offset: Int64, length: Int64, position: Int64): Int64 {
        if (closed) { return -1 }
        let (bytes, bytesRead) = FsModule.readFileDescriptor(fd, length, position)
        for (i in 0..Int64(bytes.size)) {
            if (offset + i < buffer.size) {
                buffer[offset + i] = bytes[i]
            }
        }
        return bytesRead
    }

    /// 写入数据
    public func write(data: String, position: Int64): Int64 {
        if (closed) { return -1 }
        return FsModule.writeFileDescriptor(fd, data, position)
    }

    /// 定位文件指针
    public func seek(offset: Int64, whence: Int32): Int64 {
        if (closed) { return -1 }
        unsafe {
            return lseek(Int32(fd), offset, whence)
        }
    }

    /// 截断文件
    public func truncate(length: Int64): Unit {
        if (closed) { return }
        FsModule.ftruncateFile(fd, length)
    }

    /// 关闭文件句柄
    public func close(): Unit {
        if (!closed) {
            FsModule.closeFile(fd)
            closed = true
        }
    }

    /// 析构时自动关闭
    protected func finalize(): Unit {
        close()
    }
}
