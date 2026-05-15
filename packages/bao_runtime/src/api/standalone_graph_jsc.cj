// 严格翻译自: src/runtime/api/standalone_graph_jsc.zig
package bao_runtime

import bao_jsc.*
import bao_core.*

// ============================================================================
// standalone_graph_jsc - StandaloneModuleGraph.File 的 JSC 桥接
// 对应 Bun: src/runtime/api/standalone_graph_jsc.zig
// ============================================================================

/// StandaloneModuleGraph.File 的 Blob 访问器
/// 图本身在 standalone_graph/ 中, 只有需要 JSGlobalObject 的 Blob 访问器在此处
public class StandaloneGraphJsc {

    /// 获取文件的 Blob 对象
    /// 如果尚未缓存, 创建 Blob 并缓存
    public static func fileBlob(file: StandaloneModuleGraphFile, globalObject: JsGlobalObject): Blob {
        if (file.cachedBlob == null) {
            let store = BlobStore.init(file.contents, default_allocator)
            store.ref() // 永不释放

            let b = Blob.initWithStore(store, globalObject).new()

            // 设置 MIME 类型
            if (let mime = MimeType.byExtensionNoDefault(file.name.extension().trimLeading('.'))) {
                store.mimeType = mime
                b.contentType = mime.value
                b.contentTypeWasSet = true
                b.contentTypeAllocated = false
            }

            // 设置真实名称
            store.data.bytes.storedName = PathString.init(file.name)

            // 设置显示名称
            if (file.name.hasPrefix(StandaloneModuleGraph.basePublicPathWithDefaultSuffix)) {
                b.name = BunString.cloneUTF8(file.name.substring(StandaloneModuleGraph.basePublicPathWithDefaultSuffix.count))
            } else if (file.name.count > 0) {
                b.name = BunString.cloneUTF8(file.name)
            }

            file.cachedBlob = b
        }

        return file.cachedBlob!
    }
}
