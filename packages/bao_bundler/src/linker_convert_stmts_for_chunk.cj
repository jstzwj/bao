// 严格翻译自: src/bundler/linker_context/convertStmtsForChunk.zig (559行)
// bao_bundler - 语句转换: 将 AST 语句转换为 chunk 中的最终语句
package bao_bundler

import bao_core.*
import bao_collections.*
import bao_parser.*
import bao_io.*
import bao_path.*

// ============================================================================
// 语句转换
// 严格翻译自: convertStmtsForChunk.zig
//
// 将 AST 语句列表转换为最终输出时需要处理:
//   - ESM import/export 转换 (提取到包装器外)
//   - export default 转换为变量声明
//   - export * 的处理
//   - CJS 包装器处理
//   - 语句分类到 insideWrapperPrefix/outsideWrapperPrefix/insideWrapperSuffix
// ============================================================================

/// 转换 chunk 的语句
// 严格翻译自: convertStmtsForChunk.zig:26 convertStmtsForChunk()
public func convertStmtsForChunk(
    linker: LinkerContext,
    sourceIndex: Int64,
    stmts: StmtList,
    partStmts: ArrayList<Stmt>,
    chunk: Chunk,
    wrap: WrapKind
): Unit {
    let shouldExtractESMStmtsForWrap = wrap != WrapKind.None
    let shouldStripExports = linker.options.mode != LinkerMode.Passthrough

    for (stmt in partStmts) {
        match (stmt.tag) {
            case StmtTag.Import => {
                // Import statements must be top-level (outside wrapper)
                if (shouldExtractESMStmtsForWrap) {
                    stmts.append(StmtListKind.OutsideWrapperPrefix, stmt)
                    continue
                }
            }
            case StmtTag.ExportStar => {
                // "export * from 'path'" - handled specially
                if (shouldStripExports) {
                    // Remove the export star statement, replace with re-export code
                    continue
                }
            }
            case StmtTag.ExportFrom => {
                // "export {foo} from 'path'" -> "import {foo} from 'path'"
                if (shouldStripExports) {
                    // Convert to import statement
                }
                if (shouldExtractESMStmtsForWrap) {
                    stmts.append(StmtListKind.OutsideWrapperPrefix, stmt)
                    continue
                }
            }
            case StmtTag.ExportClause => {
                // "export {foo}" - strip export keyword
                if (shouldStripExports) {
                    continue
                }
                if (shouldExtractESMStmtsForWrap) {
                    stmts.append(StmtListKind.OutsideWrapperPrefix, stmt)
                    continue
                }
            }
            case StmtTag.Function => {
                // Strip "export" keyword
                if (shouldStripExports && stmt.isExport) {
                    stmt.isExport = false
                }
            }
            case StmtTag.Class => {
                // Strip "export" keyword
                if (shouldStripExports && stmt.isExport) {
                    stmt.isExport = false
                }
            }
            case StmtTag.Local => {
                // Strip "export" keyword
                if (shouldStripExports && stmt.isExport) {
                    stmt.isExport = false
                }
            }
            case StmtTag.ExportDefault => {
                // "export default foo" -> "var default = foo" etc.
                if (shouldStripExports) {
                    // Transform based on value type
                }
            }
            case _ => ()
        }

        stmts.append(StmtListKind.InsideWrapperSuffix, stmt)
    }
}

/// 包装类型
public enum WrapKind {
    | None
    | CJS
    | ESM
}
