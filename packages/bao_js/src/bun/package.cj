// bao_js.bun - one-to-one Bun src/js/bun resource manifest
package bao_js.bun

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
        SourceResource("ffi", "bun/src/js/bun/ffi.ts", "resources/bun/ffi.ts", "typescript", true),
        SourceResource("sql", "bun/src/js/bun/sql.ts", "resources/bun/sql.ts", "typescript", true),
        SourceResource("sqlite", "bun/src/js/bun/sqlite.ts", "resources/bun/sqlite.ts", "typescript", true)
    ]
}

public const RESOURCE_COUNT: Int64 = 3
