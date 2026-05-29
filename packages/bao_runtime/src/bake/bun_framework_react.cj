// 翻译自 Bun: src/runtime/bake/bun-framework-react/index.ts
// Bun 内置 React 框架预设配置
// 此文件供框架开发者在不编译 Bun 本身的情况下开发 bun-framework-react。
// 如果对此文件进行了更改，请更新 bake.zig 中的 'pub fn react'。

package bao_runtime.bake

/// 返回 React 框架配置
/// 对应 Bun: bun-framework-react/index.ts react()
public func bunFrameworkReactConfig(): Framework {
    let routerType = FileSystemRouterType()
    routerType.root = "pages"
    routerType.prefix = "/"
    routerType.entry_client = Option<String>.Some("bun-framework-react/client.tsx")
    routerType.entry_server = "bun-framework-react/server.tsx"
    routerType.ignore_underscores = true
    routerType.ignore_dirs = [".git", "node_modules"]
    routerType.extensions = [".jsx", ".tsx"]
    routerType.style = FrameworkRouterStyle.nextjs_pages
    routerType.allow_layouts = true

    let fw = Framework(true, [routerType])

    let sc = ServerComponents()
    sc.separate_ssr_graph = true
    sc.server_runtime_import = "react-server-dom-webpack/server"
    sc.server_register_client_reference = "registerClientReference"
    sc.server_register_server_reference = "registerServerReference"
    sc.client_register_server_reference = "registerServerReference"
    fw.serverComponents = Option<ServerComponents>.Some(sc)

    let rfr = ReactFastRefresh()
    rfr.import_source = "react-refresh/runtime"
    fw.reactFastRefresh = Option<ReactFastRefresh>.Some(rfr)

    fw.built_in_modules = StringArrayHashMap<BuiltInModule>.fromEntries([
        ("bun-framework-react/client.tsx", BuiltInModule.`import`("bun-framework-react/client.tsx")),
        ("bun-framework-react/server.tsx", BuiltInModule.`import`("bun-framework-react/server.tsx")),
        ("bun-framework-react/ssr.tsx", BuiltInModule.`import`("bun-framework-react/ssr.tsx"))
    ])

    return fw
}
