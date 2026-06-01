// 严格翻译自:
//   src/bundler/linker_context/LegacyMetafileBuilder.zig (1085行)
//   src/bundler/linker_context/postProcessJSChunk.zig (1125行, metafile 部分)
// bao_bundler - Metafile 生成: esbuild 兼容的 metafile JSON 输出
package bao_bundler

import bao_core.*
import bao_collections.*
import bao_parser.*
import bao_io.*
import bao_path.*
import bao_sys.*
import bao_string.*

// ============================================================================
// Metafile 构建器
// 严格翻译自: linker_context/LegacyMetafileBuilder.zig (1085行)
//
// 生成与 esbuild 格式兼容的 metafile JSON:
// {
//   "inputs": {
//     "path/to/file.js": {
//       "bytes": 1234,
//       "imports": [
//         { "path": "dependency.js", "kind": "import-statement" },
//         { "path": "external", "kind": "require-call", "external": true }
//       ],
//       "format": "esm"
//     }
//   },
//   "outputs": {
//     "path/to/output.js": {
//       "bytes": 5678,
//       "inputs": {
//         "path/to/file.js": { "bytesInOutput": 1200 }
//       },
//       "imports": [
//         { "path": "chunk.js", "kind": "import-statement" }
//       ],
//       "exports": ["default", "foo"],
//       "entryPoint": "path/to/file.js"
//     }
//   }
// }
// ============================================================================

/// Metafile 构建器
// 严格翻译自: LegacyMetafileBuilder.zig:31 LegacyMetafileBuilder
public class LegacyMetafileBuilder {

    /// 生成单个 chunk 的 JSON 片段
    // 严格翻译自: LegacyMetafileBuilder.zig:36 generateChunkJson()
    // 在并行 chunk 生成期间调用，结果存储在 chunk.metafile_chunk_json 中
    public static func generateChunkJson(
        linker: LinkerContext,
        chunk: Chunk,
        allChunks: ArrayList<Chunk>
    ): String {
        // 委托给 MetafileBuilder.generateChunkJson
        return MetafileBuilder.generateChunkJson(linker, chunk, allChunks)
    }

    public static func generate(linker: LinkerContext, chunks: ArrayList<Chunk>): String {
        // 委托给 MetafileBuilder.generate
        return MetafileBuilder.generate(linker, chunks)
    }

    public static func writeJSONString(sb: StringBuilder, value: String): Unit {
        sb.append(MetafileBuilder.jsonEncodeString(value))
    }
}

// ============================================================================
// 辅助类型 (Metafile 相关)
// ============================================================================

/// Metafile 输入信息
// 严格翻译自: LegacyMetafileBuilder.zig 中 MetafileInput
public class MetafileInput {
    /// 文件路径
    public var path: String
    /// 文件大小 (字节)
    public var bytes: Int64
    /// 导入列表
    public var imports: ArrayList<MetafileImport>
    /// 模块格式
    public var format: String

    public init(path: String) {
        this.path = path
        bytes = 0
        imports = ArrayList<MetafileImport>()
        format = "esm"
    }
}

/// Metafile 导入信息
// 严格翻译自: LegacyMetafileBuilder.zig 中 MetafileImport
public class MetafileImport {
    /// 导入路径
    public var path: String
    /// 导入类型标签
    public var kind: String
    /// 是否是外部导入
    public var external: Bool

    public init(path: String, kind: String) {
        this.path = path
        this.kind = kind
        external = false
    }
}

/// Metafile 输出信息
// 严格翻译自: LegacyMetafileBuilder.zig 中 MetafileOutput
public class MetafileOutput {
    /// 输出路径
    public var path: String
    /// 输出大小 (字节)
    public var bytes: Int64
    /// 输入文件及其在输出中的大小
    public var inputs: HashMap<String, Int64>
    /// 导入列表
    public var imports: ArrayList<MetafileImport>
    /// 导出名称列表
    public var exports: ArrayList<String>
    /// 入口点路径 (如果是入口 chunk)
    public var entryPoint: ?String
    /// 关联的 CSS bundle 路径
    public var cssBundle: ?String

    public init(path: String) {
        this.path = path
        bytes = 0
        inputs = HashMap<String, Int64>()
        imports = ArrayList<MetafileImport>()
        exports = ArrayList<String>()
        entryPoint = None
        cssBundle = None
    }

    /// 转换为 JSON
    public func toJson(): String {
        let sb = StringBuilder()

        sb.append("{\n      \"bytes\": ")
        sb.append(bytes.toString())

        // Write inputs (bytesInOutput map)
        sb.append(",\n      \"inputs\": {")
        var firstInput = true
        let inputEntries = inputs.allEntries()
        for (entry in inputEntries) {
            if (!firstInput) {
                sb.append(",")
            }
            firstInput = false

            sb.append("\n        ")
            sb.append(MetafileBuilder.jsonEncodeString(entry[0]))
            sb.append(": {\n          \"bytesInOutput\": ")
            sb.append(entry[1].toString())
            sb.append("\n        }")
        }
        if (!firstInput) {
            sb.append("\n      ")
        }
        sb.append("}")

        // Write imports
        sb.append(",\n      \"imports\": [")
        var firstImport = true
        for (imp in imports) {
            if (!firstImport) {
                sb.append(",")
            }
            firstImport = false

            sb.append("\n        {\n          \"path\": ")
            sb.append(MetafileBuilder.jsonEncodeString(imp.path))
            sb.append(",\n          \"kind\": \"")
            sb.append(imp.kind)
            sb.append("\"")
            if (imp.external) {
                sb.append(",\n          \"external\": true")
            }
            sb.append("\n        }")
        }
        if (!firstImport) {
            sb.append("\n      ")
        }
        sb.append("]")

        // Write exports
        sb.append(",\n      \"exports\": [")
        var firstExport = true
        for (exp in exports) {
            if (!firstExport) {
                sb.append(",")
            }
            firstExport = false
            sb.append("\n        ")
            sb.append(MetafileBuilder.jsonEncodeString(exp))
        }
        if (!firstExport) {
            sb.append("\n      ")
        }
        sb.append("]")

        // Write entryPoint if present
        match (entryPoint) {
            case Some(ep) =>
                if (ep.size > 0) {
                    sb.append(",\n      \"entryPoint\": ")
                    sb.append(MetafileBuilder.jsonEncodeString(ep))
                }
            case None => ()
        }

        // Write cssBundle if present
        match (cssBundle) {
            case Some(css) =>
                if (css.size > 0) {
                    sb.append(",\n      \"cssBundle\": ")
                    sb.append(MetafileBuilder.jsonEncodeString(css))
                }
            case None => ()
        }

        sb.append("\n    }")
        return sb.toString()
    }
}

/// 完整的 Metafile
// 严格翻译自: LegacyMetafileBuilder.zig 中完整 metafile 结构
public class Metafile {
    /// 输入文件
    public var inputs: HashMap<String, MetafileInput>
    /// 输出文件
    public var outputs: HashMap<String, MetafileOutput>

    public init() {
        inputs = HashMap<String, MetafileInput>()
        outputs = HashMap<String, MetafileOutput>()
    }

    /// 添加输入文件
    public func addInput(input: MetafileInput): Unit {
        inputs.put(input.path, input)
    }

    /// 添加输出文件
    public func addOutput(output: MetafileOutput): Unit {
        outputs.put(output.path, output)
    }

    /// 生成完整 JSON
    public func toJson(): String {
        let sb = StringBuilder()

        sb.append("{\n  \"inputs\": {")

        // Write inputs
        var firstInput = true
        let inputEntries2 = inputs.allEntries()
        for (entry in inputEntries2) {
            let inputKey = entry[0]
            let inputValue = entry[1]

            if (!firstInput) {
                sb.append(",")
            }
            firstInput = false

            sb.append("\n    ")
            sb.append(MetafileBuilder.jsonEncodeString(inputKey))
            sb.append(": {\n      \"bytes\": ")
            sb.append(inputValue.bytes.toString())

            // Write imports
            sb.append(",\n      \"imports\": [")
            var firstImport = true
            for (imp in inputValue.imports) {
                if (!firstImport) {
                    sb.append(",")
                }
                firstImport = false

                sb.append("\n        {\n          \"path\": ")
                sb.append(MetafileBuilder.jsonEncodeString(imp.path))
                sb.append(",\n          \"kind\": \"")
                sb.append(imp.kind)
                sb.append("\"")
                if (imp.external) {
                    sb.append(",\n          \"external\": true")
                }
                sb.append("\n        }")
            }
            if (!firstImport) {
                sb.append("\n      ")
            }
            sb.append("]")

            // Write format
            if (inputValue.format.size > 0) {
                sb.append(",\n      \"format\": \"")
                sb.append(inputValue.format)
                sb.append("\"")
            }

            sb.append("\n    }")
        }

        sb.append("\n  },\n  \"outputs\": {")

        // Write outputs
        var firstOutput = true
        let outputEntries = outputs.allEntries()
        for (entry in outputEntries) {
            let outputKey = entry[0]
            let outputValue = entry[1]

            if (!firstOutput) {
                sb.append(",")
            }
            firstOutput = false

            sb.append("\n    ")
            sb.append(MetafileBuilder.jsonEncodeString(outputKey))
            sb.append(": ")
            sb.append(outputValue.toJson())
        }

        sb.append("\n  }\n}\n")

        return sb.toString()
    }
}
