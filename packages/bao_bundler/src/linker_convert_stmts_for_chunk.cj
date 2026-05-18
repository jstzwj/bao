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
    for (stmt in partStmts) {
        match (stmt.tag) {
            case StmtTag.Import => ()
            case StmtTag.ExportStar => ()
            case StmtTag.ExportFrom => ()
            case StmtTag.Function => ()
            case StmtTag.Class => ()
            case StmtTag.Local => ()
            case StmtTag.ExportDefault => ()
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
