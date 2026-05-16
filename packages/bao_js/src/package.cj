// bao_js - one-to-one manifest for Bun src/js resources
// JS/TS files are preserved as runtime resources for the JS engine/preprocessor,
// not rewritten as partial Cangjie stubs. Native headers remain native resources.
package bao_js

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

public func listRootResources(): Array<SourceResource> {
    return [
        SourceResource("", "bun/src/js/.gitignore", "resources/.gitignore", "ignore-config", false),
        SourceResource("AGENTS", "bun/src/js/AGENTS.md", "resources/AGENTS.md", "documentation", false),
        SourceResource("CLAUDE", "bun/src/js/CLAUDE.md", "resources/CLAUDE.md", "documentation", false),
        SourceResource("Cargo", "bun/src/js/Cargo.toml", "resources/Cargo.toml", "toml-config", false),
        SourceResource("README", "bun/src/js/README.md", "resources/README.md", "documentation", false),
        SourceResource("builtins", "bun/src/js/builtins.d.ts", "resources/builtins.d.ts", "typescript-declaration", true),
        SourceResource("internal-for-testing", "bun/src/js/internal-for-testing.ts", "resources/internal-for-testing.ts", "typescript", true),
        SourceResource("lib", "bun/src/js/lib.rs", "resources/lib.rs", "rust-source", false),
        SourceResource("private", "bun/src/js/private.d.ts", "resources/private.d.ts", "typescript-declaration", true),
        SourceResource("tsconfig", "bun/src/js/tsconfig.json", "resources/tsconfig.json", "json-config", false),
        SourceResource("wasi-runner", "bun/src/js/wasi-runner.js", "resources/wasi-runner.js", "javascript", true)
    ]
}

public func bunSourceRoot(): String { "bun/src/js" }
public func baoResourceRoot(): String { "packages/bao_js/resources" }
public const ROOT_RESOURCE_COUNT: Int64 = 11
public const TOTAL_RESOURCE_COUNT: Int64 = 191
