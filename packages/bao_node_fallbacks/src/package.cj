// bao_node_fallbacks - one-to-one manifest for Bun src/node-fallbacks resources
// JavaScript fallback modules are runtime resources. The build script and package
// metadata are build/reference resources preserved verbatim.
package bao_node_fallbacks

/// Describes a Bun source file preserved as a Bao runtime/build resource.
/// JS/TS resources are intentionally not translated to Cangjie because Bun loads
/// them as JavaScript modules or build-time generator scripts.
public struct SourceResource {
    public let moduleName: String
    public let bunPath: String
    public let resourcePath: String
    public let kind: String
    public let runtimeResource: Bool

    public init(moduleName: String, bunPath: String, resourcePath: String, kind: String, runtimeResource: Bool) {
        this.moduleName = moduleName
        this.bunPath = bunPath
        this.resourcePath = resourcePath
        this.kind = kind
        this.runtimeResource = runtimeResource
    }
}

public func listResources(): Array<SourceResource> {
    return [
        SourceResource("", "bun/src/node-fallbacks/.gitignore", "resources/.gitignore", "ignore-config", false),
        SourceResource("Cargo", "bun/src/node-fallbacks/Cargo.toml", "resources/Cargo.toml", "toml-config", false),
        SourceResource("README", "bun/src/node-fallbacks/README.md", "resources/README.md", "documentation", false),
        SourceResource("assert", "bun/src/node-fallbacks/assert.js", "resources/assert.js", "javascript", true),
        SourceResource("buffer", "bun/src/node-fallbacks/buffer.js", "resources/buffer.js", "javascript", true),
        SourceResource("build-fallbacks", "bun/src/node-fallbacks/build-fallbacks.ts", "resources/build-fallbacks.ts", "typescript", false),
        SourceResource("bun", "bun/src/node-fallbacks/bun.lock", "resources/bun.lock", "lockfile", false),
        SourceResource("console", "bun/src/node-fallbacks/console.js", "resources/console.js", "javascript", true),
        SourceResource("constants", "bun/src/node-fallbacks/constants.js", "resources/constants.js", "javascript", true),
        SourceResource("crypto", "bun/src/node-fallbacks/crypto.js", "resources/crypto.js", "javascript", true),
        SourceResource("domain", "bun/src/node-fallbacks/domain.js", "resources/domain.js", "javascript", true),
        SourceResource("events", "bun/src/node-fallbacks/events.js", "resources/events.js", "javascript", true),
        SourceResource("http", "bun/src/node-fallbacks/http.js", "resources/http.js", "javascript", true),
        SourceResource("https", "bun/src/node-fallbacks/https.js", "resources/https.js", "javascript", true),
        SourceResource("lib", "bun/src/node-fallbacks/lib.rs", "resources/lib.rs", "rust-source", false),
        SourceResource("net", "bun/src/node-fallbacks/net.js", "resources/net.js", "javascript", true),
        SourceResource("os", "bun/src/node-fallbacks/os.js", "resources/os.js", "javascript", true),
        SourceResource("package", "bun/src/node-fallbacks/package.json", "resources/package.json", "json-config", false),
        SourceResource("path", "bun/src/node-fallbacks/path.js", "resources/path.js", "javascript", true),
        SourceResource("process", "bun/src/node-fallbacks/process.js", "resources/process.js", "javascript", true),
        SourceResource("punycode", "bun/src/node-fallbacks/punycode.js", "resources/punycode.js", "javascript", true),
        SourceResource("querystring", "bun/src/node-fallbacks/querystring.js", "resources/querystring.js", "javascript", true),
        SourceResource("stream", "bun/src/node-fallbacks/stream.js", "resources/stream.js", "javascript", true),
        SourceResource("string_decoder", "bun/src/node-fallbacks/string_decoder.js", "resources/string_decoder.js", "javascript", true),
        SourceResource("sys", "bun/src/node-fallbacks/sys.js", "resources/sys.js", "javascript", true),
        SourceResource("timers", "bun/src/node-fallbacks/timers.js", "resources/timers.js", "javascript", true),
        SourceResource("timers/promises", "bun/src/node-fallbacks/timers.promises.js", "resources/timers.promises.js", "javascript", true),
        SourceResource("tsconfig", "bun/src/node-fallbacks/tsconfig.json", "resources/tsconfig.json", "json-config", false),
        SourceResource("tty", "bun/src/node-fallbacks/tty.js", "resources/tty.js", "javascript", true),
        SourceResource("url", "bun/src/node-fallbacks/url.js", "resources/url.js", "javascript", true),
        SourceResource("util", "bun/src/node-fallbacks/util.js", "resources/util.js", "javascript", true),
        SourceResource("vendor/base64-js", "bun/src/node-fallbacks/vendor/base64-js.js", "resources/vendor/base64-js.js", "javascript", true),
        SourceResource("vendor/ieee754", "bun/src/node-fallbacks/vendor/ieee754.js", "resources/vendor/ieee754.js", "javascript", true),
        SourceResource("zlib", "bun/src/node-fallbacks/zlib.js", "resources/zlib.js", "javascript", true)
    ]
}

public func bunSourceRoot(): String { "bun/src/node-fallbacks" }
public func baoResourceRoot(): String { "packages/bao_node_fallbacks/resources" }
public const RESOURCE_COUNT: Int64 = 34
