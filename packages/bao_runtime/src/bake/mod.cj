// 严格翻译自: src/runtime/bake/mod.rs
// Bake 模块入口。Rust 源文件负责重新导出 FrameworkRouter、生产构建、DevServer 及共享类型。
// Bake 是 Bun 用于构建客户端+服务器 Web 应用的工具包。
// 它结合了 Bun.build 和 Bun.serve，提供热重载开发服务器、服务器组件和其他集成。
// Bake 不是框架本身，而是框架构建的工具。

package bao_runtime.bake

// 导入子模块
// 对应 Bun: pub const production = @import("./production.zig")
// 对应 Bun: pub const DevServer = @import("./DevServer.zig")
// 对应 Bun: pub const FrameworkRouter = @import("./FrameworkRouter.zig")

/// export default { app: ... };
public const api_name: String = "app"
