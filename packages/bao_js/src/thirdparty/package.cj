// bao_js.thirdparty - one-to-one Bun src/js/thirdparty resource manifest
package bao_js.thirdparty

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
        SourceResource("isomorphic-fetch", "bun/src/js/thirdparty/isomorphic-fetch.ts", "resources/thirdparty/isomorphic-fetch.ts", "typescript", true),
        SourceResource("node-fetch", "bun/src/js/thirdparty/node-fetch.ts", "resources/thirdparty/node-fetch.ts", "typescript", true),
        SourceResource("undici", "bun/src/js/thirdparty/undici.js", "resources/thirdparty/undici.js", "javascript", true),
        SourceResource("vercel_fetch", "bun/src/js/thirdparty/vercel_fetch.js", "resources/thirdparty/vercel_fetch.js", "javascript", true),
        SourceResource("ws", "bun/src/js/thirdparty/ws.js", "resources/thirdparty/ws.js", "javascript", true)
    ]
}

public const RESOURCE_COUNT: Int64 = 5
