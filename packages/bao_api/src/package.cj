// bao_api - API facade: schema types re-exports, npm registry parser, schema codec
// Strict translation from: bun/src/api/
//   lib.rs            -> re-exports from bao_options::schema, npm_registry::Parser
//   schema.d.ts       -> enum & interface type definitions
//   schema.js         -> encode/decode functions (peechy generated)
//   schema.peechy     -> original peechy IDL (reference only)
//
// LAYERING: canonical data shapes (NpmRegistry, BunInstall, etc.) live in
// bao_options::schema. This package re-exports them so existing bao_api::*
// import paths keep working. Encode/decode logic lives here alongside the
// peechy-style ByteBuffer codec.
package bao_api

import bao_options.*
import bao_options.*
import bao_core.*
import bao_collections.*
import bao_url.*
