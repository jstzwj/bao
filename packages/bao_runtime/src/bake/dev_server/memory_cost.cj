// 翻译自 Bun: src/runtime/bake/DevServer/memory_cost.zig
// DevServer 内存成本估算工具

package bao_runtime.bake.dev_server

/// 内存成本分类
public class MemoryCost {
    public var incremental_graph_client: UInt64
    public var incremental_graph_server: UInt64
    public var js_code: UInt64
    public var source_maps: UInt64
    public var assets: UInt64
    public var other: UInt64

    public init() {
        incremental_graph_client = 0
        incremental_graph_server = 0
        js_code = 0
        source_maps = 0
        assets = 0
        other = 0
    }

    public init(incremental_graph_client: UInt64, incremental_graph_server: UInt64,
                js_code: UInt64, source_maps: UInt64, assets: UInt64, other: UInt64) {
        this.incremental_graph_client = incremental_graph_client
        this.incremental_graph_server = incremental_graph_server
        this.js_code = js_code
        this.source_maps = source_maps
        this.assets = assets
        this.other = other
    }

    /// 返回 DevServer 明确知道的字节数估算
    public static func memoryCostDetailed(dev: DevServer): MemoryCost {
        var other_bytes: UInt64 = 0
        var incremental_graph_client: UInt64 = 0
        var incremental_graph_server: UInt64 = 0
        var js_code: UInt64 = 0
        var source_maps: UInt64 = 0
        var assets: UInt64 = 0

        // 计算根路径
        other_bytes += UInt64(dev.root.size)
        // 路由器
        // other_bytes += dev.router.memoryCost()
        // 路由 bundle
        // 服务器图
        let server_cost = dev.server_graph.memoryCostDetailed()
        incremental_graph_server += server_cost.graph
        js_code += server_cost.code
        source_maps += server_cost.source_maps
        // 客户端图
        let client_cost = dev.client_graph.memoryCostDetailed()
        incremental_graph_client += client_cost.graph
        js_code += client_cost.code
        source_maps += client_cost.source_maps
        // 资产
        assets += dev.assets.memoryCost()

        return MemoryCost(
            incremental_graph_client,
            incremental_graph_server,
            js_code,
            source_maps,
            assets,
            other_bytes
        )
    }

    /// 总内存成本
    public static func memoryCost(dev: DevServer): UInt64 {
        let cost = memoryCostDetailed(dev)
        return cost.incremental_graph_client +
               cost.incremental_graph_server +
               cost.js_code +
               cost.source_maps +
               cost.assets +
               cost.other
    }

    /// ArrayList 的内存成本
    public static func memoryCostArrayList<T>(slice: Array<T>): UInt64 {
        return UInt64(slice.size) * sizeOf<T>()
    }

    /// 切片的内存成本
    public static func memoryCostSlice<T>(slice: Array<T>): UInt64 {
        return UInt64(slice.size) * sizeOf<T>()
    }

    /// ArrayHashMap 的内存成本
    public static func memoryCostArrayHashMap<K, V>(map: HashMap<K, V>): UInt64 {
        return UInt64(map.count()) * (sizeOf<K>() + sizeOf<V>())
    }
}

/// MemoryCostResult - 返回内存成本的三个维度
public struct MemoryCostResult {
    public var graph: UInt64
    public var code: UInt64
    public var source_maps: UInt64
    public init() { graph = 0; code = 0; source_maps = 0 }
    public init(graph: UInt64, code: UInt64, source_maps: UInt64) {
        this.graph = graph; this.code = code; this.source_maps = source_maps
    }
}
