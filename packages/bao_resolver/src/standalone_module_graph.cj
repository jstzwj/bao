// 独立模块图接口
// 严格翻译自: src/resolver/standalone_module_graph.rs (30行)
//   Resolver's view of a compiled-standalone-binary module graph.
//   此 trait 定义了解析器对独立模块图的只读视图,
//   使解析器能持有 trait 对象而不依赖更高层级的 bun_bundler/bun_standalone_graph 包.
package bao_resolver

import bao_core.*

// ============================================================================
// StandaloneModuleGraph - 独立模块图接口
// 严格翻译自: standalone_module_graph.rs:12-30
//   pub trait StandaloneModuleGraph: Send + Sync {
//       fn find_assume_standalone_path(&self, name: &[u8]) -> Option<&[u8]>;
//       fn find(&self, name: &[u8]) -> Option<&[u8]>;
//       fn base_public_path_with_default_suffix(&self) -> &'static [u8];
//       fn compile_exec_argv(&self) -> &[u8];
//   }
// ============================================================================

/// 独立模块图接口 - 对应 Bun StandaloneModuleGraph trait
/// 解析器对编译后的独立二进制文件中嵌入模块图的只读视图。
/// 具体实现在 bun_standalone_graph 中 (依赖 bun_bundler)，
/// 解析器持有此接口对象以保持在依赖图的低层。
public interface StandaloneModuleGraph {
    /// 查找假设为独立路径的模块 - 对应 find_assume_standalone_path()
    /// 在已知路径在独立虚拟根目录下的情况下查找嵌入文件
    func findAssumeStandalonePath(name: String): ?String

    /// 查找任意路径 - 对应 find()
    /// 先检查独立虚拟根前缀，再查找嵌入文件
    func find(name: String): ?String

    /// 基础公共路径 - 对应 base_public_path_with_default_suffix()
    /// 嵌入模块的虚拟根前缀 (如 "/$bunfs/root/")
    func basePublicPathWithDefaultSuffix(): String

    /// 编译执行参数 - 对应 compile_exec_argv()
    /// bun build --compile 二进制中内置的 --compile-exec-argv 字符串
    func compileExecArgv(): String
}
