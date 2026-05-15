// 翻译自 Bun: src/runtime/bake/DevServer/PackedMap.zig
// 单个文件的打包源映射数据。
// 由一个 IncrementalGraph 文件和/或多个 SourceMapStore 条目拥有。

package bao_runtime

/// PackedMap - 单个文件的打包源映射数据。
/// 由一个 IncrementalGraph 文件和/或多个 SourceMapStore 条目拥有。
public class PackedMap {
    /// 由 dev.allocator() 分配。使用 .vlq() 访问。
    /// 存储以允许懒构建源映射文件。
    public var vlq_: OwnedIn<Array<Byte>, DevAllocator>
    /// bundler 在多线程上运行引用，因此保留该努力用于连接是合理的。
    public var escaped_source: Owned<Array<Byte>>
    /// 用于跟踪源映射 chunk 的最后状态
    public var end_state: EndState

    /// 结束状态
    public class EndState {
        public var original_line: Int32
        public var original_column: Int32
    }

    /// 创建非空的 PackedMap
    public static func newNonEmpty(chunk: SourceMapChunk, escaped_source: Owned<Array<Byte>>): Shared<PackedMap> {
        var buffer = chunk.buffer
        assert(!buffer.isEmpty())
        let dev_allocator = DevAllocator.downcast(buffer.allocator)
        return Shared<PackedMap>.new(PackedMap(
            vlq_: OwnedIn.fromRawIn(buffer.toOwnedSlice(), dev_allocator),
            escaped_source: escaped_source,
            end_state: EndState(
                original_line: chunk.end_state.original_line,
                original_column: chunk.end_state.original_column,
            ),
        ))
    }

    /// 析构
    public func deinit(): Unit {
        vlq_.deinit()
        escaped_source.deinit()
    }

    /// 内存成本
    public func memoryCost(): UInt64 {
        return vlq().length + quotedContents().length + sizeOf<PackedMap>()
    }

    /// 获取 VLQ 数据
    public func vlq(): String {
        return vlq_.get()
    }

    /// 获取引用内容（转义源）
    public func quotedContents(): String {
        return escaped_source.get()
    }

    /// LineCount - 行数索引类型
    public struct LineCount <: UInt32 {}

    /// Shared - 源映射数据的共享引用
    /// HTML、CSS、资产和失败的文件没有源映射。
    /// 这些情况不应分配对象。但仍有一些相关状态需要编码。
    public enum Shared {
        | some(Shared<PackedMap>)  // 有完整的 PackedMap
        | none                     // 无源映射
        | line_count(LineCount)    // 仅行数

        /// 获取 PackedMap 指针
        public func get(): ?PackedMap {
            return match (this) {
                case some(let ptr) => ptr.get()
                case _ => None
            }
        }

        /// 取出共享引用
        public mutating func take(): ?Shared<PackedMap> {
            match (this) {
                case some(let ptr) =>
                    this = Shared.none
                    return ptr
                case _ => None
            }
        }

        /// 克隆
        public func clone(): Shared {
            return match (this) {
                case some(let ptr) => Shared.some(ptr.clone())
                case _ => this
            }
        }

        /// 析构
        public mutating func deinit(): Unit {
            match (this) {
                case some(let ptr) => ptr.deinit()
                case _ => ()
            }
        }

        /// 摊销内存成本
        public func memoryCost(): UInt64 {
            return match (this) {
                case some(let ptr) => ptr.get().memoryCost() / max(ptr.strongCount(), 1)
                case _ => 0
            }
        }
    }
}

// 类型别名
public type DevAllocator = dev_server.DevAllocator
public type OwnedIn<T, A> = bun.ptr.OwnedIn<T, A>
public type Owned<T> = bun.ptr.Owned<T>
public type Shared<T> = bun.ptr.Shared<T>
public type SourceMapChunk = bun.SourceMap.Chunk
