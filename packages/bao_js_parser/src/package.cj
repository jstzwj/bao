// Compatibility wrapper for Bun's src/js_parser crate name.
// The implementation lives in packages/bao_parser/src/.
package bao_js_parser

import bao_parser.*

// Re-export-only package: downstream code can import bao_js_parser.*
// while using the same public API provided by bao_parser.
