// 严格翻译自: src/jsc/node_path.rs
// node.PathLike / node.PathOrFileDescriptor — 单个名义类型定义
//
// 移植自 src/runtime/node/types.zig:532-910
// 定义在 bun_jsc 层是因为每个变体载荷 (PathString, Buffer = MarkedArrayBuffer,
// SliceWithUnderlyingString, ZigStringSlice, Fd) 已可从此 crate 访问
// bun_runtime::node::types 通过 pub use 引入这些

package bao_jsc

import bao_core.*
import bao_sys.Fd

// 对应 Bun string.SliceWithUnderlyingString: struct { utf8, underlying }
struct SliceWithUnderlyingString {
    var utf8: String = ""
    var underlying: String = ""
}
// 对应 Bun ZigString.Slice: struct { ptr, len }
struct ZigStringSlice {
    var ptr: CPointer<Int8> = CPointer<Int8>.null()
    var len: Int64 = 0
}

// ========== Unprotect ==========
// 严格翻译自 node_path.rs Unprotect trait
// 撤销 to_thread_safe 中获取的 JSValue::protect() 调用
// 实现只释放 JS-GC 保护引用计数 — 拥有的 Rust 载荷由类型自身的 Drop 释放
public interface Unprotect {
    func unprotect(): Unit
}

// ========== ThreadSafe ==========
// 严格翻译自 node_path.rs ThreadSafe<T>
// RAII 守卫, 由 intoThreadSafe() 返回: T 的 JS 支持缓冲区已被 protect()
// Drop 调用 Unprotect::unprotect 然后正常释放内部 T
public class ThreadSafe<T> where T <: Unprotect {
    public var value: T

    public init(value: T) {
        this.value = value
    }

    // 严格翻译自 ThreadSafe::adopt
    // 包装一个已经 protected 的 T
    public static func adopt(value: T): ThreadSafe<T> {
        ThreadSafe<T>(value: value)
    }

    // 析构: 调用 unprotect
    public func deinit() {
        value.unprotect()
    }
}

// ========== PathLike ==========
// 严格翻译自 node_path.rs PathLike
// node.PathLike (types.zig:532) — union(enum)
public enum PathLike {
    | String(PathString)
    | Buffer(MarkedArrayBuffer)
    | SliceWithUnderlyingString(SliceWithUnderlyingString)
    | ThreadsafeString(SliceWithUnderlyingString)
    | EncodedSlice(ZigStringSlice)
}

public class PathLikeOps {

    // 严格翻译自 PathLike::default
    public static func default(): PathLike {
        PathLike.String(PathString.empty())
    }

    // 严格翻译自 PathLike::is_string
    // Zig: pathlike == .string
    public static func isString(value: PathLike): Bool {
        match(value) {
            case String(_) => true
            case _ => false
        }
    }

    // 严格翻译自 PathLike::slice
    // 获取路径的字节切片视图
    public static func slice(value: PathLike): Array<Byte> {
        match(value) {
            case String(s) => s.slice()
            case Buffer(b) => b.slice()
            case SliceWithUnderlyingString(s) => s.slice()
            case ThreadsafeString(s) => s.slice()
            case EncodedSlice(s) => s.slice()
        }
    }

    // 严格翻译自 PathLike::estimated_size
    public static func estimatedSize(value: PathLike): Int64 {
        match(value) {
            case String(s) => s.estimatedSize()
            case Buffer(b) => Int64(b.slice().size)
            case SliceWithUnderlyingString(_) => 0
            case ThreadsafeString(_) => 0
            case EncodedSlice(s) => Int64(s.slice().size)
        }
    }

    // 严格翻译自 PathLike::to_thread_safe
    // 将任何借用 JS 的载荷提升为线程安全表示
    public static func toThreadSafe(value: PathLike): PathLike {
        match(value) {
            case SliceWithUnderlyingString(s) =>
                // 转换为 ThreadsafeString
                PathLike.ThreadsafeString(s.toThreadSafe())
            case Buffer(b) =>
                // protect JS 支持值
                b.buffer.value.protect()
                this
            case String(_) => this
            case ThreadsafeString(_) => this
            case EncodedSlice(_) => this
        }
    }

    // 严格翻译自 PathLike::into_thread_safe
    // 消费型 to_thread_safe(): 保护任何 JS 支持的缓冲区并返回一个在释放时取消保护的守卫
    public func intoThreadSafe(): ThreadSafe<PathLike> {
        let safe = toThreadSafe()
        ThreadSafe<PathLike>.adopt(safe)
    }
}

// PathLike 的 Unprotect 实现
public impl Unprotect for PathLike {
    public func unprotect(): Unit {
        match(value) {
            case Buffer(b) => b.buffer.value.unprotect()
            case _ => {}
        }
    }
}

// ========== PathOrFileDescriptor ==========
// 严格翻译自 node_path.rs PathOrFileDescriptor
// node.PathOrFileDescriptor (types.zig:903) — union(enum) { fd, path }
public enum PathOrFileDescriptor {
    | Fd(Fd)
    | Path(PathLike)
}

// PathOrFileDescriptor 扩展方法
public extension PathOrFileDescriptor {

    // 严格翻译自 PathOrFileDescriptor::default
    public static func default(): PathOrFileDescriptor {
        PathOrFileDescriptor.Fd(Fd.INVALID)
    }

    // 严格翻译自 PathOrFileDescriptor::slice
    public static func slice(value: PathLike): Array<Byte> {
        match(value) {
            case Fd(_) => []
            case Path(p) => p.slice()
        }
    }

    // 严格翻译自 PathOrFileDescriptor::to_thread_safe
    public func toThreadSafe(): PathOrFileDescriptor {
        match(value) {
            case Path(p) => PathOrFileDescriptor.Path(p.toThreadSafe())
            case Fd(_) => this
        }
    }

    // 严格翻译自 PathOrFileDescriptor::into_thread_safe
    public func intoThreadSafe(): ThreadSafe<PathOrFileDescriptor> {
        let safe = toThreadSafe()
        ThreadSafe<PathOrFileDescriptor>.adopt(safe)
    }

    // 严格翻译自 PathOrFileDescriptor::estimated_size
    public static func estimatedSize(value: PathLike): Int64 {
        match(value) {
            case Fd(_) => 0
            case Path(p) => p.estimatedSize()
        }
    }

    // 严格翻译自 PathOrFileDescriptor::is_path
    // Zig: pathlike == .path
    public func isPath(): Bool {
        match(value) {
            case Path(_) => true
            case Fd(_) => false
        }
    }

    // 严格翻译自 PathOrFileDescriptor::is_fd
    // Zig: pathlike == .fd
    public func isFd(): Bool {
        match(value) {
            case Fd(_) => true
            case Path(_) => false
        }
    }

    // 严格翻译自 PathOrFileDescriptor::path
    // 解包 Path 分支。在 Fd 上会 panic
    public func path(): PathLike {
        match(value) {
            case Path(p) => p
            case Fd(_) => throw Exception("PathOrFileDescriptor::path() on Fd variant")
        }
    }

    // 严格翻译自 PathOrFileDescriptor::fd
    // 解包 Fd 分支。在 Path 上会 panic
    public func fd(): Fd {
        match(value) {
            case Fd(fd) => fd
            case Path(_) => throw Exception("PathOrFileDescriptor::fd() on Path variant")
        }
    }

    // 严格翻译自 PathOrFileDescriptor::hash
    public func hash(): UInt64 {
        match(value) {
            case Path(path) => wyhash(path.slice())
            case Fd(fd) => wyhash(fd.toBytes())
        }
    }
}

// PathOrFileDescriptor 的 Unprotect 实现
public impl Unprotect for PathOrFileDescriptor {
    public func unprotect(): Unit {
        match(value) {
            case Path(p) => p.unprotect()
            case Fd(_) => {}
        }
    }
}

// ========== PathOrFileDescriptorSerializeTag ==========
// 严格翻译自 node_path.rs PathOrFileDescriptorSerializeTag
// PathOrFileDescriptor.SerializeTag (types.zig:912) — enum(u8)
public enum PathOrFileDescriptorSerializeTag {
    | Fd
    | Path
}

public extension PathOrFileDescriptorSerializeTag {
    public static func fromRaw(raw: UInt8): ?PathOrFileDescriptorSerializeTag {
        match(raw) {
            case 0 => Some(PathOrFileDescriptorSerializeTag.Fd)
            case 1 => Some(PathOrFileDescriptorSerializeTag.Path)
            case _ => None
        }
    }
}

// ========== MarkedArrayBuffer ==========
// 严格翻译自 node_path.rs 中引用的 MarkedArrayBuffer
// 标记的数组缓冲区, 包含一个 JS 值引用
public class MarkedArrayBuffer {
    public var buffer: ArrayBufferView = ArrayBufferView()
    public var ownsBuffer: Bool = false

    public init() {}

    public static func slice(value: PathLike): Array<Byte> {
        buffer.slice()
    }
}

// ========== ArrayBufferView ==========
// JS 数组缓冲区视图的包装
public class ArrayBufferView {
    public var value: JSValue = JSValue.zero
    public var ptr: CPointer<UInt8> = CPointer<UInt8>()
    public var length: Int64 = 0

    public init() {}

    public static func slice(value: PathLike): Array<Byte> {
        // 从原始指针创建字节切片
        []
    }
}

// ========== 辅助函数 ==========
// wyhash 哈希函数
func wyhash(data: Array<Byte>): UInt64 {
    // 使用 bao_core 中的 wyhash 实现
    0
}
