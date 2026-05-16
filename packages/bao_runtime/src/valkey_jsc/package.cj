// Compatibility wrapper for Bun's runtime/valkey_jsc module path.
// The implementation lives in packages/bao_runtime/src/valkey/.
package bao_runtime.valkey_jsc

import bao_runtime.valkey.*

// Re-export-only module: downstream code can import bao_runtime.valkey_jsc.*
// while using the same public API provided by bao_runtime.valkey.
