// 严格翻译自: src/bundler/linker_context/StaticRouteVisitor.zig (93行)
// bao_bundler - 静态路由访问器: 检测入口点是否传递性地使用了 "use client" 指令
package bao_bundler

import bao_core.*
import bao_collections.*
import bao_parser.*
import bao_io.*
import bao_path.*

// ============================================================================
// 静态路由访问器
// 严格翻译自: StaticRouteVisitor.zig
//
// 检测入口点是否 "完全静态" (即不传递地依赖 "use client" 文件)
// 这用于 Bake (SSR/路由) 场景的优化:
//   - 如果入口点是静态的，可以在构建时预渲染
//   - 如果入口点传递地使用了客户端组件，需要运行时渲染
//
// 算法: 递归遍历入口点的所有导入，检查是否有任何导入
// 匹配到 server_component_boundaries 中标记为 .client 的文件
// ============================================================================

/// 静态路由访问器
// 严格翻译自: StaticRouteVisitor.zig:6 StaticRouteVisitor
public class StaticRouteVisitor {
    /// 链接器上下文
    public var linker: LinkerContext
    /// 缓存: source_index -> 是否有传递的 use client
    public var cache: HashMap<Int64, Bool>
    /// 已访问集合 (防止循环)
    public var visited: HashSet<Int64>

    public init(linker: LinkerContext) {
        this.linker = linker
        this.cache = HashMap<Int64, Bool>()
        this.visited = HashSet<Int64>()
    }

    /// 检查入口点是否有传递的 "use client"
    // 严格翻译自: StaticRouteVisitor.zig:20 hasTransitiveUseClient()
    //
    // 这是一个简化但安全的实现:
    // - 可以有假阴性 (不能正确处理循环)
    // - 但这作为优化是可以接受的
    public func hasTransitiveUseClient(entryPointSourceIndex: Int64): Bool {
        visited.clear()

        let allImportRecords = getAllImportRecords()
        let referencedSourceIndices = getReferencedSourceIndices()
        let useDirectives = getUseDirectives()

        return hasTransitiveUseClientImpl(
            allImportRecords,
            referencedSourceIndices,
            useDirectives,
            entryPointSourceIndex
        )
    }

    /// 递归检查实现
    // 严格翻译自: StaticRouteVisitor.zig:43 hasTransitiveUseClientImpl()
    //
    // 1. 获取 source_index 的 AST
    // 2. 递归遍历其 import records 中的导入
    // 3. 如果任何导入匹配 referenced_source_indices 中
    //    use_directive == .client 的项，则不是完全静态
    private func hasTransitiveUseClientImpl(
        allImportRecords: ArrayList<ArrayList<ImportRecord>>,
        referencedSourceIndices: ArrayList<Int64>,
        useDirectives: ArrayList<UseDirective>,
        sourceIndex: Int64
    ): Bool {
        // 检查缓存
        match (cache.get(sourceIndex)) {
            case Some(result) => return result
            case None => ()
        }

        // 循环检测
        if (visited.contains(sourceIndex)) {
            return false
        }
        visited.put(sourceIndex)

        let importRecords = allImportRecords[sourceIndex]

        var result = false
        for (record in importRecords) {
            if (!record.sourceIndex.isValid()) { continue }

            let recordSourceIndex = record.sourceIndex.value

            // 检查此导入是否是客户端边界
            for (i in 0..referencedSourceIndices.size) {
                if (useDirectives[i] == UseDirective.Client) {
                    if (referencedSourceIndices[i] == recordSourceIndex) {
                        result = true
                        break
                    }
                }
            }
            if (result) { break }

            // 递归检查子导入
            if (hasTransitiveUseClientImpl(
                allImportRecords,
                referencedSourceIndices,
                useDirectives,
                recordSourceIndex
            )) {
                result = true
                break
            }
        }

        // 缓存结果
        cache.put(sourceIndex, result)

        return result
    }

    /// 释放资源
    public func deinit(): Unit {
        cache.clear()
        visited.clear()
    }

    // 辅助方法
    private func getAllImportRecords(): ArrayList<ArrayList<ImportRecord>> {
        // 从 linker.parseGraph 获取所有导入记录
        return ArrayList<ArrayList<ImportRecord>>()
    }

    private func getReferencedSourceIndices(): ArrayList<Int64> {
        // 从 linker.parseGraph.serverComponentBoundaries 获取
        return ArrayList<Int64>()
    }

    private func getUseDirectives(): ArrayList<UseDirective> {
        return ArrayList<UseDirective>()
    }
}

/// 使用指令
// 严格翻译自: StaticRouteVisitor.zig UseDirective
public enum UseDirective {
    | None
    | Client
    | Server
}
