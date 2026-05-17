// Valkey/Redis client — JSC bindings.
//
// Module layout mirrors Bun's src/runtime/valkey_jsc/:
//   - Protocol state machine lives in ValkeyClient
//   - JS wrapper in JSValkeyClient
//   - ~200 prototype methods in ValkeyFunctions
//   - RESP wire-format JSC conversions in ProtocolJsc
//
// This module re-exports the public API from bao_runtime.valkey so that
// downstream code can import via either bao_runtime.valkey_jsc.* or
// bao_runtime.valkey.* interchangeably (matching Bun's module aliasing).
//
// In Cangjie, `import bao_runtime.valkey.*` brings all public types and
// functions into scope directly, so no explicit type aliases are needed.
// Downstream code can use `import bao_runtime.valkey_jsc.*` to access
// everything from bao_runtime.valkey through this re-export module.
package bao_runtime.valkey_jsc

import bao_runtime.valkey.*

// All public types and functions from bao_runtime.valkey are available
// via the wildcard import above, including:
//
// Types: JSValkeyClient, ValkeyClient, SubscriptionCtx, ValkeySocketHandler,
//   ValkeyProtocol, ConnectionStatus, ConnectionFlags, TLSConfig, TLSMode,
//   ValkeyAddress, ValkeyOptions, ValkeyCommand, CommandArgs, CommandMeta,
//   CommandEntry, ValkeyPromise, PromisePair, JsArgument, Slice, ToJSOptions,
//   ProtocolJsc, RedisErrorCode, ValkeyContext, ValkeyFunctions,
//   RedisClientClass, KeepAlive, EventLoopTimer, TimerState, SslContext,
//   SslVerifyError, ParsedUrl, ByteBuffer
//
// Functions: protocolFromString, jsArgumentFromJS, ...

// ported from: bun/src/runtime/valkey_jsc/mod.rs
