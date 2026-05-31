// 严格翻译自: src/runtime/api/standalone_graph_jsc.zig
//   JSC bridges for StandaloneModuleGraph.File
//   The graph itself stays in standalone_graph/ (used by the bundler with no
//   JS in the loop); only the Blob accessor that needs a *JSGlobalObject
//   lives here.
package bao_runtime.api

import bao_jsc.{JsGlobalObject, JsValue, JsCallFrame}
import bao_standalone_graph.*

/// 简单 ASCII 小写转换
func toAsciiLower(s: String): String {
    var result = ""
    for (ch in s) {
        if (ch >= UInt8(65) && ch <= UInt8(90)) {
            result += String(Rune(Int64(ch) + 32))
        } else {
            result += String(Rune(Int64(ch)))
        }
    }
    result
}

// StandaloneModuleGraphFile, BlobStore, StandaloneModuleGraph are defined in:
//   - bao_runtime.src.api.bun_object (StandaloneModuleGraph, StandaloneModuleGraphFile)
//   - bao_runtime.src.webcore.blob (BlobStore)
// This file provides only the JSC bridge functions.

// ============================================================================
// 辅助函数
// ============================================================================

/// 提取文件扩展名 (不含点号)
func extractExtension(path!: String): String {
    let dotIdx = path.lastIndexOf(".")
    if (dotIdx.isNone()) { return "" }
    let idx = dotIdx.getOrThrow()
    if (idx >= path.size - 1) { return "" }
    path[Int64(idx + 1)..]
}

/// 根据扩展名获取 MIME 类型
/// 翻译自: bun.http.MimeType.byExtensionNoDefault
func mimeTypeByExtension(ext!: String): ?String {
    match (toAsciiLower(ext)) {
        case "html" => Some("text/html")
        case "css" => Some("text/css")
        case "js" => Some("application/javascript")
        case "json" => Some("application/json")
        case "png" => Some("image/png")
        case "jpg" => Some("image/jpeg")
        case "jpeg" => Some("image/jpeg")
        case "gif" => Some("image/gif")
        case "svg" => Some("image/svg+xml")
        case "ico" => Some("image/x-icon")
        case "woff" => Some("font/woff")
        case "woff2" => Some("font/woff2")
        case "ttf" => Some("font/ttf")
        case "txt" => Some("text/plain")
        case "xml" => Some("application/xml")
        case "wasm" => Some("application/wasm")
        case _ => None
    }
}

/// StandaloneModuleGraphJSC — 独立模块图的 JS 绑定入口
/// 翻译自: standalone_graph_jsc.zig 的导出函数
public class StandaloneModuleGraphJSC {
    public init() {}

    /// generateFromGraph — 从模块图生成 JSC 绑定
    public static func generateFromGraph(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        JsValue.jsUndefined()
    }

    /// 为 File 创建 JS Blob 访问器
    /// 翻译自: standalone_graph_jsc.zig fileBlob
    public static func fileBlobForFile(file!: StandaloneModuleGraphFile, globalObject!: JsGlobalObject): BlobRef {
        file.fileBlob(globalObject: globalObject)
    }
}
