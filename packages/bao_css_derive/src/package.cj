// No-op compatibility package for Bun's Rust derive macro crate css_derive.
// Cangjie does not require this Rust macro crate at runtime; keep this package
// so one-to-one translated dependency names can resolve cleanly.
package bao_css_derive

/// Marker for the no-op compatibility package.
public const COMPAT_PACKAGE: String = "bao_css_derive"
