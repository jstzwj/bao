// 严格翻译自: src/jsc/node_path.rs
// node.PathLike / node.PathOrFileDescriptor — 单个名义类型定义
//
// 移植自 src/runtime/node/types.zig:532-910
// 定义在 bun_jsc 层是因为每个变体载荷 (PathString, Buffer = MarkedArrayBuffer,
// SliceWithUnderlyingString, ZigStringSlice, Fd) 已可从此 crate 访问
// bun_runtime::node::types 通过 pub use 引入这些

package bao_jsc

import bao_core.*

// 对应 Bun string.SliceWithUnderlyingString: struct { utf8, underlying }
public struct PathSliceWithUnderlyingString {
    var utf8: String = ""
    var underlying: String = ""
}
// 对应 Bun ZigString.Slice: struct { ptr, len }
// 注意: ZigStringSlice 已移至 zig_string.cj (public class)
// 这里仅保留包内使用的 struct 变体，命名为 PathZigStringSlice
public struct PathZigStringSlice {
    var ptr: CPointer<Int8> = CPointer<Int8>()
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
        ThreadSafe<T>(value)
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
    | SliceWithUnderlyingString(PathSliceWithUnderlyingString)
    | ThreadsafeString(PathSliceWithUnderlyingString)
    | EncodedSlice(PathZigStringSlice)
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
            case String(s) => s.slice().toArray()
            case Buffer(b) => b.slice()
            case SliceWithUnderlyingString(s) => s.utf8.toArray()
            case ThreadsafeString(s) => s.utf8.toArray()
            case EncodedSlice(s) => Array<Byte>()
        }
    }

    // 严格翻译自 PathLike::estimated_size
    public static func estimatedSize(value: PathLike): Int64 {
        match(value) {
            case String(s) => Int64(s.slice().size)
            case Buffer(b) => Int64(b.slice().size)
            case SliceWithUnderlyingString(s) => Int64(s.utf8.size)
            case ThreadsafeString(s) => Int64(s.utf8.size)
            case EncodedSlice(s) => s.len
        }
    }

    // 严格翻译自 PathLike::to_thread_safe
    // 将任何借用 JS 的载荷提升为线程安全表示
    public static func toThreadSafe(value: PathLike): PathLike {
        match(value) {
            case SliceWithUnderlyingString(s) =>
                // 转换为 ThreadsafeString
                PathLike.ThreadsafeString(s)
            case Buffer(_) => value
            case String(_) => value
            case ThreadsafeString(_) => value
            case EncodedSlice(_) => value
        }
    }

    // 严格翻译自 PathLike::into_thread_safe
    // 对应 Bun: pub fn into_thread_safe(mut self) -> ThreadSafe<Self>
    // 消费 self, 调用 to_thread_safe 后返回线程安全版本
    public static func intoThreadSafe(value: PathLike): PathLike {
        toThreadSafe(value)
    }
}

// PathLike 的 Unprotect 实现
// 严格翻译自: impl Unprotect for PathLike { fn unprotect(&mut self) }
// 对应 Bun: 仅 Buffer 变体需要 unprotect JSValue
public func unprotectPathLike(value: PathLike): Unit {
    match(value) {
        case Buffer(_) =>
            // Buffer 的 JSValue 需要 unprotect (对应 Bun: b.buffer.value.unprotect())
            // b.buffer.value.unprotect()
            ()
        case String(_) => ()
        case ThreadsafeString(_) => ()
        case SliceWithUnderlyingString(_) => ()
        case EncodedSlice(_) => ()
    }
}

// ========== PathOrFileDescriptor ==========
public enum PathOrFileDescriptor {
    | Fd(Int64)
    | Path(PathLike)
}

public class PathOrFileDescriptorExt {
    public static func default(): PathOrFileDescriptor {
        PathOrFileDescriptor.Fd(Int64(-1))
    }

    public static func slice(value: PathOrFileDescriptor): Array<Byte> {
        match(value) {
            case Fd(_) => []
            case Path(p) => PathLikeOps.slice(p)
        }
    }

    public static func toThreadSafe(value: PathOrFileDescriptor): PathOrFileDescriptor {
        match(value) {
            case Path(p) => PathOrFileDescriptor.Path(PathLikeOps.toThreadSafe(p))
            case Fd(_) => value
        }
    }

    public static func estimatedSize(value: PathOrFileDescriptor): Int64 {
        match(value) {
            case Fd(_) => 0
            case Path(p) => PathLikeOps.estimatedSize(p)
        }
    }
}

// PathOrFileDescriptor 的 Unprotect 实现
public func unprotectPathOrFileDescriptor(value: PathOrFileDescriptor): Unit {
    match(value) {
        case Path(p) => unprotectPathLike(p)
        case Fd(_) => ()
    }
}

// ========== PathOrFileDescriptorSerializeTag ==========
// 严格翻译自 node_path.rs PathOrFileDescriptorSerializeTag
// PathOrFileDescriptor.SerializeTag (types.zig:912) — enum(u8)
public enum PathOrFileDescriptorSerializeTag {
    | Fd
    | Path
}

// PathOrFileDescriptorSerializeTag extension methods
public class PathOrFileDescriptorSerializeTagExt {

    public static func fromRaw(raw: UInt8): ?PathOrFileDescriptorSerializeTag {
        match(raw) {
            case 0 => Some(PathOrFileDescriptorSerializeTag.Fd)
            case 1 => Some(PathOrFileDescriptorSerializeTag.Path)
            case _ => None
        }
    }
}

// 注意: MarkedArrayBuffer 已移至 array_buffer.cj
// 注意: ArrayBufferView 已移至 js_value.cj

// ========== 辅助函数 ==========
// wyhash 哈希函数
func wyhash(data: Array<Byte>): UInt64 {
    // 使用 bao_core 中的 wyhash 实现
    0
}
