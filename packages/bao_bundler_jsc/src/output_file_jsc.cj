// 严格翻译自: src/bundler_jsc/output_file_jsc.zig
//! `toJS`/`toBlob` bridges for bundler output files.
package bao_bundler_jsc

import bao_jsc.*
import bao_core.*

// ============================================================================
// OutputFileJSC - OutputFile 的 JSC 桥接
// ============================================================================

/// SavedFile JS 桥接
public class SavedFileJSC {
    public static func toJS(globalThis: JSGlobalObject, path: String, byteSize: Int64): JsValue {
        return BuildArtifactJSC.toJS(globalThis, path, byteSize, "file", "file", true)
    }
}

/// OutputFile JS 桥接
public class OutputFileJSC {
    public static func toJS(globalThis: JSGlobalObject, path: String, content: Array<UInt8>): JsValue {
        let obj = JsObject.make()
        obj.set("path", JsValue(path))
        obj.set("size", JsValue(Int64(content.size)))
        obj.set("kind", JsValue("entry-point"))
        obj.set("loader", JsValue(loaderFromPath(path)))
        obj.set("type", JsValue(mimeTypeFromPath(path)))
        obj.set("text", JsValue(String.fromUtf8(content)))
        return JsValue(obj)
    }
}

/// BuildArtifact JS 桥接
public class BuildArtifactJSC {
    public static func toJS(globalThis: JSGlobalObject): JsValue {
        return toJS(globalThis, "", 0, "file", "entry-point", false)
    }

    public static func toJS(globalThis: JSGlobalObject, path: String, byteSize: Int64, loader: String, kind: String, saved: Bool): JsValue {
        let obj = JsObject.make()
        obj.set("path", JsValue(path))
        obj.set("size", JsValue(byteSize))
        obj.set("loader", JsValue(loader))
        obj.set("kind", JsValue(kind))
        obj.set("type", JsValue(mimeTypeFromPath(path)))
        obj.set("saved", JsValue(saved))
        return JsValue(obj)
    }
}

private func loaderFromPath(path: String): String {
    if (path.endsWith(".js") || path.endsWith(".mjs") || path.endsWith(".cjs")) { return "js" }
    if (path.endsWith(".jsx")) { return "jsx" }
    if (path.endsWith(".ts") || path.endsWith(".mts") || path.endsWith(".cts")) { return "ts" }
    if (path.endsWith(".tsx")) { return "tsx" }
    if (path.endsWith(".css")) { return "css" }
    if (path.endsWith(".json")) { return "json" }
    if (path.endsWith(".html")) { return "html" }
    if (path.endsWith(".wasm")) { return "wasm" }
    return "file"
}

private func mimeTypeFromPath(path: String): String {
    if (path.endsWith(".js") || path.endsWith(".mjs") || path.endsWith(".cjs")) { return "text/javascript;charset=utf-8" }
    if (path.endsWith(".css")) { return "text/css;charset=utf-8" }
    if (path.endsWith(".json")) { return "application/json;charset=utf-8" }
    if (path.endsWith(".html")) { return "text/html;charset=utf-8" }
    if (path.endsWith(".wasm")) { return "application/wasm" }
    if (path.endsWith(".txt")) { return "text/plain;charset=utf-8" }
    return "application/octet-stream"
}
