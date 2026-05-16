// 翻译自 Bun: src/runtime/bake/bun-framework-react/index.ts
// Bun 内置 React 框架预设配置
// 此文件供框架开发者在不编译 Bun 本身的情况下开发 bun-framework-react。
// 如果对此文件进行了更改，请更新 bake.zig 中的 'pub fn react'。

package bao_runtime.bake

/// 返回 React 框架配置
/// 对应 Bun: bun-framework-react/index.ts react()
public func bunFrameworkReactConfig(): Framework {
    return Framework(
        is_built_in_react: true,
        file_system_router_types: [
            Framework.FileSystemRouterType(
                root: "pages",
                prefix: "/",
                entry_client: Some("bun-framework-react/client.tsx"),
                entry_server: "bun-framework-react/server.tsx",
                ignore_underscores: true,
                ignore_dirs: [".git", "node_modules"],
                extensions: [".jsx", ".tsx"],
                style: FrameworkRouterStyle.nextjs_pages,
                allow_layouts: true,
            ),
        ],
        server_components: Some(ServerComponents(
            separate_ssr_graph: true,
            server_runtime_import: "react-server-dom-webpack/server",
            server_register_client_reference: "registerClientReference",
            server_register_server_reference: "registerServerReference",
            client_register_server_reference: "registerServerReference",
        )),
        react_fast_refresh: Some(ReactFastRefresh(
            import_source: "react-refresh/runtime",
        )),
        built_in_modules: StringArrayHashMap<BuiltInModule>.fromEntries([
            ("bun-framework-react/client.tsx", BuiltInModule.`import`("bun-framework-react/client.tsx")),
            ("bun-framework-react/server.tsx", BuiltInModule.`import`("bun-framework-react/server.tsx")),
            ("bun-framework-react/ssr.tsx", BuiltInModule.`import`("bun-framework-react/ssr.tsx")),
        ]),
    )
}
