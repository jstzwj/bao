// bao_bunfig — bunfig.toml parser and Arguments.loadConfig entrypoints.
// Strict port of: src/bunfig/lib.rs
//
// Original Rust module comment:
//   `bun_bunfig` — bunfig.toml parser and `Arguments::loadConfig` entrypoints.
//   that `bun_install::PackageManager::init` can call
//   `bun.cli.Arguments.loadConfig(_, cli.config, ctx, .InstallCommand)`
//   (PackageManager.zig:801) without a tier-6 dependency or fn-pointer hook.
//   Every dependency of this crate was already a transitive dependency of
//   `bun_install` (via `bun_transpiler` -> `bun_bundler`), so no cycle is
//   introduced; this only makes the existing edge direct.
package bao_bunfig

// ============================================================================
// Module structure — mirrors Bun src/bunfig/lib.rs:
//   pub mod arguments;
//   pub mod bunfig;
//   pub use arguments::{load_config, load_config_path, load_config_with_cmd_args};
//   pub use bunfig::Bunfig;
// ============================================================================

// Re-export from arguments.cj
// Corresponds to Bun: pub use arguments::{load_config, load_config_path, load_config_with_cmd_args}
// Re-export from bunfig.cj
// Corresponds to Bun: pub use bunfig::Bunfig
