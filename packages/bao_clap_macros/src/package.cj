// No-op compatibility package for Bun's Rust proc-macro crate clap_macros.
// Cangjie does not require this Rust macro crate at runtime; keep this package
// so one-to-one translated dependency names can resolve cleanly.
package bao_clap_macros

/// Marker for the no-op compatibility package.
public const COMPAT_PACKAGE: String = "bao_clap_macros"
