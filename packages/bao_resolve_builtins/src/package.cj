// Package entry for bao_resolve_builtins
// Strictly translated from: bun/src/resolve_builtins/lib.rs
//
// Bun's lib.rs re-exports:
//   pub mod HardcodedModule;
//   pub use HardcodedModule::{Alias, Cfg, HardcodedModule as Module};
//   pub mod node_builtins;
//
// In Cangjie, all files in src/ are implicitly part of the package,
// so this file serves as the package entry point and re-exports
// the key public symbols for convenient access.
package bao_resolve_builtins

// All public types are automatically accessible from other packages
// that depend on bao_resolve_builtins. Key exports:
//
// From hardcoded_module.cj:
//   HardcodedModule   - enum of all known built-in/override modules
//   HardcodedModule.MAP / lookup()  - specifier -> enum lookup
//   Alias             - struct describing how a specifier resolves
//   Cfg               - configuration for alias lookup
//   Target            - compilation target enum (isBun/isNode)
//   NODE_ALIASES      - node target alias table
//   BUN_ALIASES       - bun target alias table
//   BUN_TEST_ALIASES  - bun+test target alias table
//   aliasGet()        - Alias.get(name, target, cfg)
//   aliasHas()        - Alias.has(name, target, cfg)
//
// From node_builtins.cj:
//   NODE_BUILTIN_PATTERNS_RAW       - 57 bare Node.js core module names
//   NODE_BUILTIN_PATTERNS           - 114 entries (bare + "node:" prefixed)
//   BUN_NODE_BUILTIN_PATTERNS_COMPAT - 52 Bun-compat subset
//   NODE_BUILTIN_NODE_ONLY          - 5 Bun-excluded modules
