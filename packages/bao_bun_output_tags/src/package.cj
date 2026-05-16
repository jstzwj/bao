// Compatibility wrapper for Bun's src/bun_output_tags crate name.
// The implementation lives in packages/bao_output_tags/src/.
package bao_bun_output_tags

import bao_output_tags.*

// Re-export-only package: downstream code can import bao_bun_output_tags.*
// while using the same public API provided by bao_output_tags.
