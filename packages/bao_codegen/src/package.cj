// bao_codegen - one-to-one manifest for Bun src/codegen resources
// TypeScript/Rust/Ruby/Zig codegen inputs are build-time resources. They are
// preserved verbatim so generated binding behavior can match Bun.
package bao_codegen

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
        SourceResource("Cargo", "bun/src/codegen/Cargo.toml", "resources/Cargo.toml", "toml-config", false),
        SourceResource("bake-codegen", "bun/src/codegen/bake-codegen.ts", "resources/bake-codegen.ts", "typescript", false),
        SourceResource("bindgen-lib-internal", "bun/src/codegen/bindgen-lib-internal.ts", "resources/bindgen-lib-internal.ts", "typescript", false),
        SourceResource("bindgen-lib", "bun/src/codegen/bindgen-lib.ts", "resources/bindgen-lib.ts", "typescript", false),
        SourceResource("bindgen", "bun/src/codegen/bindgen.ts", "resources/bindgen.ts", "typescript", false),
        SourceResource("bindgenv2/internal/any", "bun/src/codegen/bindgenv2/internal/any.ts", "resources/bindgenv2/internal/any.ts", "typescript", false),
        SourceResource("bindgenv2/internal/array", "bun/src/codegen/bindgenv2/internal/array.ts", "resources/bindgenv2/internal/array.ts", "typescript", false),
        SourceResource("bindgenv2/internal/base", "bun/src/codegen/bindgenv2/internal/base.ts", "resources/bindgenv2/internal/base.ts", "typescript", false),
        SourceResource("bindgenv2/internal/dictionary", "bun/src/codegen/bindgenv2/internal/dictionary.ts", "resources/bindgenv2/internal/dictionary.ts", "typescript", false),
        SourceResource("bindgenv2/internal/enumeration", "bun/src/codegen/bindgenv2/internal/enumeration.ts", "resources/bindgenv2/internal/enumeration.ts", "typescript", false),
        SourceResource("bindgenv2/internal/interfaces", "bun/src/codegen/bindgenv2/internal/interfaces.ts", "resources/bindgenv2/internal/interfaces.ts", "typescript", false),
        SourceResource("bindgenv2/internal/optional", "bun/src/codegen/bindgenv2/internal/optional.ts", "resources/bindgenv2/internal/optional.ts", "typescript", false),
        SourceResource("bindgenv2/internal/primitives", "bun/src/codegen/bindgenv2/internal/primitives.ts", "resources/bindgenv2/internal/primitives.ts", "typescript", false),
        SourceResource("bindgenv2/internal/string", "bun/src/codegen/bindgenv2/internal/string.ts", "resources/bindgenv2/internal/string.ts", "typescript", false),
        SourceResource("bindgenv2/internal/union", "bun/src/codegen/bindgenv2/internal/union.ts", "resources/bindgenv2/internal/union.ts", "typescript", false),
        SourceResource("bindgenv2/lib", "bun/src/codegen/bindgenv2/lib.ts", "resources/bindgenv2/lib.ts", "typescript", false),
        SourceResource("bindgenv2/script", "bun/src/codegen/bindgenv2/script.ts", "resources/bindgenv2/script.ts", "typescript", false),
        SourceResource("bindgenv2/tsconfig", "bun/src/codegen/bindgenv2/tsconfig.json", "resources/bindgenv2/tsconfig.json", "json-config", false),
        SourceResource("builtin-parser", "bun/src/codegen/builtin-parser.ts", "resources/builtin-parser.ts", "typescript", false),
        SourceResource("bundle-functions", "bun/src/codegen/bundle-functions.ts", "resources/bundle-functions.ts", "typescript", false),
        SourceResource("bundle-modules", "bun/src/codegen/bundle-modules.ts", "resources/bundle-modules.ts", "typescript", false),
        SourceResource("ci_info", "bun/src/codegen/ci_info.ts", "resources/ci_info.ts", "typescript", false),
        SourceResource("class-definitions", "bun/src/codegen/class-definitions.ts", "resources/class-definitions.ts", "typescript", false),
        SourceResource("client-js", "bun/src/codegen/client-js.ts", "resources/client-js.ts", "typescript", false),
        SourceResource("cppbind", "bun/src/codegen/cppbind.ts", "resources/cppbind.ts", "typescript", false),
        SourceResource("create-hash-table", "bun/src/codegen/create-hash-table.ts", "resources/create-hash-table.ts", "typescript", false),
        SourceResource("create_hash_table", "bun/src/codegen/create_hash_table", "resources/create_hash_table", "resource", false),
        SourceResource("generate-classes", "bun/src/codegen/generate-classes.ts", "resources/generate-classes.ts", "typescript", false),
        SourceResource("generate-compact-string-table", "bun/src/codegen/generate-compact-string-table.ts", "resources/generate-compact-string-table.ts", "typescript", false),
        SourceResource("generate-host-exports", "bun/src/codegen/generate-host-exports.ts", "resources/generate-host-exports.ts", "typescript", false),
        SourceResource("generate-js2native", "bun/src/codegen/generate-js2native.ts", "resources/generate-js2native.ts", "typescript", false),
        SourceResource("generate-jssink", "bun/src/codegen/generate-jssink.ts", "resources/generate-jssink.ts", "typescript", false),
        SourceResource("generate-node-errors", "bun/src/codegen/generate-node-errors.ts", "resources/generate-node-errors.ts", "typescript", false),
        SourceResource("generate-string-map", "bun/src/codegen/generate-string-map.ts", "resources/generate-string-map.ts", "typescript", false),
        SourceResource("generate-unified-source-bundles", "bun/src/codegen/generate-unified-source-bundles.rb", "resources/generate-unified-source-bundles.rb", "ruby-script", false),
        SourceResource("helpers", "bun/src/codegen/helpers.ts", "resources/helpers.ts", "typescript", false),
        SourceResource("internal-module-registry-scanner", "bun/src/codegen/internal-module-registry-scanner.ts", "resources/internal-module-registry-scanner.ts", "typescript", false),
        SourceResource("lib", "bun/src/codegen/lib.rs", "resources/lib.rs", "rust-source", false),
        SourceResource("process_windows_translate_c", "bun/src/codegen/process_windows_translate_c.rs", "resources/process_windows_translate_c.rs", "rust-source", false),
        SourceResource("process_windows_translate_c", "bun/src/codegen/process_windows_translate_c.zig", "resources/process_windows_translate_c.zig", "zig-source", false),
        SourceResource("replacements", "bun/src/codegen/replacements.ts", "resources/replacements.ts", "typescript", false),
        SourceResource("shared-types", "bun/src/codegen/shared-types.ts", "resources/shared-types.ts", "typescript", false)
    ]
}

public func bunSourceRoot(): String { "bun/src/codegen" }
public func baoResourceRoot(): String { "packages/bao_codegen/resources" }
public const RESOURCE_COUNT: Int64 = 42
