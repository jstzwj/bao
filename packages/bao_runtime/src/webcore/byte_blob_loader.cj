// ByteBlobLoader - 字节 Blob 加载器
// 对应 Bun: src/runtime/webcore/ByteBlobLoader.zig
// 严格翻译自: src/runtime/webcore/ByteBlobLoader.zig
package bao_runtime.webcore

import bao_core.*
import bao_collections.*

// ============================================================================
// ByteBlobLoader - 字节 Blob 加载器
// 对应 Bun: src/runtime/webcore/ByteBlobLoader.zig ByteBlobLoader
// ============================================================================

/// ByteBlobLoader — 从 Blob 加载数据的字节流源
/// 对应 Bun: src/runtime/webcore/ByteBlobLoader.zig ByteBlobLoader
public class ByteBlobLoader {
    /// 当前偏移
    /// 对应 Bun: ByteBlobLoader.offset
    public var offset: BlobSizeType
    /// Blob 存储
    /// 对应 Bun: ByteBlobLoader.store
    public var store: ?BlobStore
    /// 块大小
    /// 对应 Bun: ByteBlobLoader.chunk_size
    public var chunkSize: BlobSizeType
    /// 剩余字节
    /// 对应 Bun: ByteBlobLoader.remain
    public var remain: BlobSizeType
    /// 是否完成
    /// 对应 Bun: ByteBlobLoader.done
    public var done: Bool
    /// 是否已拉取
    /// 对应 Bun: ByteBlobLoader.pulled
    public var pulled: Bool
    /// 内容类型
    /// 对应 Bun: ByteBlobLoader.content_type
    public var contentType: String

    public init() {
        offset = 0
        store = None
        chunkSize = 1024 * 1024 * 2  // 2 MB
        remain = 1024 * 1024 * 2
        done = false
        pulled = false
        contentType = ""
    }

    /// 从 Blob 初始化加载器
    /// 对应 Bun: ByteBlobLoader.setup()
    public func setup(blob: Blob, userChunkSize: BlobSizeType): Unit {
        match (blob.store) {
            case Some(s) => {
                s.ref()
                store = Some(s)
                offset = blob.offset
                let blobSize = blob.getSizeForBindings()
                chunkSize = min(
                    if (userChunkSize > 0) { min(userChunkSize, blobSize) } else { blobSize },
                    1024 * 1024 * 2
                )
                remain = blobSize
                done = false
                contentType = blob.contentType
            }
            case None => ()
        }
    }

    /// 启动回调
    /// 对应 Bun: ByteBlobLoader.onStart()
    public func onStart(): StreamStartResult {
        return StreamStartResult.ChunkSize(chunkSize)
    }

    /// 拉取数据回调
    /// 对应 Bun: ByteBlobLoader.onPull()
    public func onPull(buffer: Array<UInt8>): StreamResult {
        pulled = true
        match (store) {
            case Some(s) => {
                if (done) {
                    return StreamResult.Done(Array<UInt8>())
                }
                let view = s.sharedView()
                if (offset >= view.size) {
                    done = true
                    return StreamResult.Done(Array<UInt8>())
                }
                // 计算本次读取大小
                let readSize = min(chunkSize, remain)
                let end = min(offset + readSize, view.size)
                let result = ArrayList<UInt8>()
                for (i in offset..end) {
                    if (i < view.size) {
                        result.append(view[Int64(i)])
                    }
                }
                offset = end
                remain -= result.size

                if (remain <= 0 || offset >= view.size) {
                    done = true
                    return StreamResult.OwnedAndDone(result.toArray())
                }
                return StreamResult.Owned(result.toArray())
            }
            case None => return StreamResult.Done(Array<UInt8>())
        }
    }

    /// 取消回调
    /// 对应 Bun: ByteBlobLoader.onCancel()
    public func onCancel(): Unit {
        done = true
        match (store) {
            case Some(s) => s.deref()
            case None => ()
        }
        store = None
    }

    /// 释放资源
    /// 对应 Bun: ByteBlobLoader.deinit()
    public func deinit(): Unit {
        onCancel()
    }

    /// 转为缓冲值
    /// 对应 Bun: ByteBlobLoader.toBufferedValue()
    public func toBufferedValue(): ?Blob {
        if (offset > 0 && match (store) { case Some(_) => true case None => false }) {
            let bytes = ArrayList<UInt8>()
            match (store) {
                case Some(s) => {
                    let view = s.sharedView()
                    for (i in offset..view.size) {
                        if (i < view.size) {
                            bytes.append(view[Int64(i)])
                        }
                    }
                }
                case None => ()
            }
            return Some(Blob(bytes.toArray(), contentType))
        }
        return None
    }

    /// 内存开销
    /// 对应 Bun: ByteBlobLoader.memoryCost()
    public func memoryCost(): Int64 {
        return remain
    }

    /// 获取流标签
    /// 对应 Bun: ByteBlobLoader.tag
    public func tag(): ReadableStreamTag {
        return ReadableStreamTag.Blob
    }
}
