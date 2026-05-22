// 严格翻译自: src/bundler_jsc/output_file_jsc.zig
//! `toJS`/`toBlob` bridges - stub implementation.
package bao_bundler_jsc

import bao_jsc.*
import bao_core.*

// ============================================================================
// OutputFileJSC - OutputFile 的 JSC 桥接 (stub)
// ============================================================================

/// SavedFile JS 桥接 - stub
public class SavedFileJSC {
    public static func toJS(globalThis: JSGlobalObject, path: String, byteSize: Int64): JsValue {
        return JsValue.jsUndefined()
    }
}

/// OutputFile JS 桥接 - stub
public class OutputFileJSC {
    public static func toJS(globalThis: JSGlobalObject, path: String, content: Array<UInt8>): JsValue {
        return JsValue.jsUndefined()
    }
}

/// BuildArtifact JS 桥接 - stub
public class BuildArtifactJSC {
    public static func toJS(globalThis: JSGlobalObject): JsValue {
        return JsValue.jsUndefined()
    }
}
