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

    /// 返回 DevServer 明确知道的字节数估算
    public static func memoryCostDetailed(dev: DevServer): MemoryCost {
        var other_bytes: UInt64 = sizeOf<DevServer>()
        var incremental_graph_client: UInt64 = 0
        var incremental_graph_server: UInt64 = 0
        var js_code: UInt64 = 0
        var source_maps: UInt64 = 0
        var assets: UInt64 = 0

        // 计算根路径
        other_bytes += dev.root.length
        // 路由器
        other_bytes += dev.router.memoryCost()
        // 路由 bundle
        for (bundle in dev.route_bundles.items) {
            other_bytes += bundle.memoryCost()
        }
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
        // WebSocket 连接
        other_bytes += dev.active_websocket_connections.capacity() * sizeOf<HmrSocket>()
        // 源映射
        for (entry in dev.source_maps.entries.values()) {
            source_maps += entry.files.memoryCost()
            let files = entry.files.slice()
            for (i in 0..files.length) {
                source_maps += files.get(i).memoryCost()
            }
        }
        // 增量结果
        other_bytes += memoryCostArrayList(dev.incremental_result.client_components_added)
        other_bytes += memoryCostArrayList(dev.incremental_result.framework_routes_affected)
        other_bytes += memoryCostArrayList(dev.incremental_result.client_components_removed)
        other_bytes += memoryCostArrayList(dev.incremental_result.failures_removed)
        other_bytes += memoryCostArrayList(dev.incremental_result.client_components_affected)
        other_bytes += memoryCostArrayList(dev.incremental_result.failures_added)
        other_bytes += memoryCostArrayList(dev.incremental_result.html_routes_soft_affected)
        other_bytes += memoryCostArrayList(dev.incremental_result.html_routes_hard_affected)
        // 目录监控器
        other_bytes += memoryCostArrayList(dev.directory_watchers.dependencies)
        other_bytes += memoryCostArrayList(dev.directory_watchers.dependencies_free_list)
        other_bytes += memoryCostArrayHashMap(dev.directory_watchers.watches)
        for (dep in dev.directory_watchers.dependencies.items) {
            other_bytes += dep.specifier.length
        }
        for (dir_name in dev.directory_watchers.watches.keys()) {
            other_bytes += dir_name.length
        }
        // 绑定失败
        other_bytes += memoryCostSlice(dev.bundling_failures.keys())
        for (failure in dev.bundling_failures.keys()) {
            other_bytes += failure.data.length
        }

        return MemoryCost(
            assets: assets,
            incremental_graph_client: incremental_graph_client,
            incremental_graph_server: incremental_graph_server,
            js_code: js_code,
            other: other_bytes,
            source_maps: source_maps,
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
    public static func memoryCostArrayList<T>(slice: ArrayListUnmanaged<T>): UInt64 {
        return slice.capacity * sizeOf<T>()
    }

    /// 切片的内存成本
    public static func memoryCostSlice<T>(slice: Array<T>): UInt64 {
        return slice.length * sizeOf<T>()
    }

    /// ArrayHashMap 的内存成本
    public static func memoryCostArrayHashMap<K, V>(map: StringArrayHashMapUnmanaged<V>): UInt64 {
        return StringArrayHashMapUnmanaged<V>.capacityInBytes(map.entries.capacity)
    }
}

// 类型别名
public type ArrayListUnmanaged<T> = std.ArrayListUnmanaged<T>
public type StringArrayHashMapUnmanaged<V> = std.StringArrayHashMapUnmanaged<V>
public type HmrSocket = dev_server.HmrSocket
