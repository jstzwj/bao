// NpmRegistry parser - registry URL string parser
// Strict translation from: bun/src/api/lib.rs - npm_registry module
//   pub mod npm_registry {
//       pub use super::NpmRegistry;
//       pub struct Parser<'a, L, S> { pub log: &'a mut L, pub source: &'a S }
//       impl Parser { pub fn parse_registry_url_string_impl(&mut self, str: &[u8]) -> Result<NpmRegistry, AllocError> }
//   }
//
// PORT NOTE: Parser stays generic over L (Log) / S (Source) in Rust so this
// leaf schema crate doesn't need to name bun_logger. In Cangjie we keep the
// same structure but simplify the generics since Cangjie uses interface-based
// generics. The parse function only needs the URL string input.

package bao_api

import bao_options.*
import bao_options.*
import bao_core.*
import bao_collections.*
import bao_url.*

// ============================================================================
// NpmRegistryParser - registry URL parser
// Strict translation from: lib.rs - npm_registry::Parser<'a, L, S>
//   pub struct Parser<'a, L, S> {
//       pub log: &'a mut L,
//       pub source: &'a S,
//   }
// ============================================================================

/// NPM registry URL parser
/// Corresponding to Bun bun_api::npm_registry::Parser
/// Parses a registry URL string into an NpmRegistry struct
public class NpmRegistryParser {
    // No-op logger/source placeholders - the parse_registry_url_string_impl
    // body doesn't touch log/source, only the not-yet-ported
    // parse_registry_object / parse_registry paths need js_ast::Expr

    public init() {}
}

// ============================================================================
// parseRegistryUrlStringImpl - parse registry URL string
// Strict translation from: lib.rs - npm_registry::Parser::parse_registry_url_string_impl
//   pub fn parse_registry_url_string_impl(&mut self, str: &[u8])
//       -> Result<NpmRegistry, bun_alloc::AllocError>
//   {
//       let url = URL::parse(str);
//       let mut registry = NpmRegistry::default();
//       if url.username.is_empty() && !url.password.is_empty() {
//           registry.token = Box::<[u8]>::from(url.password);
//           registry.url = url.href_without_auth();
//       } else if !url.username.is_empty() && !url.password.is_empty() {
//           registry.username = Box::<[u8]>::from(url.username);
//           registry.password = Box::<[u8]>::from(url.password);
//           registry.url = url.href_without_auth();
//       } else {
//           registry.url = Box::<[u8]>::from(url.href);
//       }
//       Ok(registry)
//   }
// ============================================================================

/// Parse a registry URL string into an NpmRegistry
/// Corresponding to Bun bun_api::npm_registry::Parser::parse_registry_url_string_impl
///
/// Rules:
///   - If URL has no username but has password: password is the token
///   - If URL has both username and password: use as credentials
///   - Otherwise: use the full href as the registry URL
public func parseRegistryUrlString(str: String): NpmRegistry {
    let url = URL.parse(str)
    let registry = NpmRegistry()

    if (url.username.isEmpty && !url.password.isEmpty) {
        registry.token = url.password
        registry.url = url.hrefWithoutAuth()
    } else if (!url.username.isEmpty && !url.password.isEmpty) {
        registry.username = url.username
        registry.password = url.password
        registry.url = url.hrefWithoutAuth()
    } else {
        // Do not include a trailing slash. There might be parameters at the end.
        registry.url = url.href
    }

    return registry
}
