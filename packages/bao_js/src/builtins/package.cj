// bao_js.builtins - one-to-one Bun src/js/builtins resource manifest
package bao_js.builtins

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
        SourceResource("Bake", "bun/src/js/builtins/Bake.ts", "resources/builtins/Bake.ts", "typescript", true),
        SourceResource("BakeSSRResponse", "bun/src/js/builtins/BakeSSRResponse.ts", "resources/builtins/BakeSSRResponse.ts", "typescript", true),
        SourceResource("BunBuiltinNames", "bun/src/js/builtins/BunBuiltinNames.h", "resources/builtins/BunBuiltinNames.h", "native-header", true),
        SourceResource("BundlerPlugin", "bun/src/js/builtins/BundlerPlugin.ts", "resources/builtins/BundlerPlugin.ts", "typescript", true),
        SourceResource("ByteLengthQueuingStrategy", "bun/src/js/builtins/ByteLengthQueuingStrategy.ts", "resources/builtins/ByteLengthQueuingStrategy.ts", "typescript", true),
        SourceResource("CommonJS", "bun/src/js/builtins/CommonJS.ts", "resources/builtins/CommonJS.ts", "typescript", true),
        SourceResource("CompressionStream", "bun/src/js/builtins/CompressionStream.ts", "resources/builtins/CompressionStream.ts", "typescript", true),
        SourceResource("ConsoleObject", "bun/src/js/builtins/ConsoleObject.ts", "resources/builtins/ConsoleObject.ts", "typescript", true),
        SourceResource("CountQueuingStrategy", "bun/src/js/builtins/CountQueuingStrategy.ts", "resources/builtins/CountQueuingStrategy.ts", "typescript", true),
        SourceResource("DecompressionStream", "bun/src/js/builtins/DecompressionStream.ts", "resources/builtins/DecompressionStream.ts", "typescript", true),
        SourceResource("Glob", "bun/src/js/builtins/Glob.ts", "resources/builtins/Glob.ts", "typescript", true),
        SourceResource("ImportMetaObject", "bun/src/js/builtins/ImportMetaObject.ts", "resources/builtins/ImportMetaObject.ts", "typescript", true),
        SourceResource("Ipc", "bun/src/js/builtins/Ipc.ts", "resources/builtins/Ipc.ts", "typescript", true),
        SourceResource("JSBufferConstructor", "bun/src/js/builtins/JSBufferConstructor.ts", "resources/builtins/JSBufferConstructor.ts", "typescript", true),
        SourceResource("JSBufferPrototype", "bun/src/js/builtins/JSBufferPrototype.ts", "resources/builtins/JSBufferPrototype.ts", "typescript", true),
        SourceResource("NodeModuleObject", "bun/src/js/builtins/NodeModuleObject.ts", "resources/builtins/NodeModuleObject.ts", "typescript", true),
        SourceResource("Peek", "bun/src/js/builtins/Peek.ts", "resources/builtins/Peek.ts", "typescript", true),
        SourceResource("ProcessObjectInternals", "bun/src/js/builtins/ProcessObjectInternals.ts", "resources/builtins/ProcessObjectInternals.ts", "typescript", true),
        SourceResource("ReadableByteStreamController", "bun/src/js/builtins/ReadableByteStreamController.ts", "resources/builtins/ReadableByteStreamController.ts", "typescript", true),
        SourceResource("ReadableByteStreamInternals", "bun/src/js/builtins/ReadableByteStreamInternals.ts", "resources/builtins/ReadableByteStreamInternals.ts", "typescript", true),
        SourceResource("ReadableStream", "bun/src/js/builtins/ReadableStream.ts", "resources/builtins/ReadableStream.ts", "typescript", true),
        SourceResource("ReadableStreamBYOBReader", "bun/src/js/builtins/ReadableStreamBYOBReader.ts", "resources/builtins/ReadableStreamBYOBReader.ts", "typescript", true),
        SourceResource("ReadableStreamBYOBRequest", "bun/src/js/builtins/ReadableStreamBYOBRequest.ts", "resources/builtins/ReadableStreamBYOBRequest.ts", "typescript", true),
        SourceResource("ReadableStreamDefaultController", "bun/src/js/builtins/ReadableStreamDefaultController.ts", "resources/builtins/ReadableStreamDefaultController.ts", "typescript", true),
        SourceResource("ReadableStreamDefaultReader", "bun/src/js/builtins/ReadableStreamDefaultReader.ts", "resources/builtins/ReadableStreamDefaultReader.ts", "typescript", true),
        SourceResource("ReadableStreamInternals", "bun/src/js/builtins/ReadableStreamInternals.ts", "resources/builtins/ReadableStreamInternals.ts", "typescript", true),
        SourceResource("StreamInternals", "bun/src/js/builtins/StreamInternals.ts", "resources/builtins/StreamInternals.ts", "typescript", true),
        SourceResource("TextDecoderStream", "bun/src/js/builtins/TextDecoderStream.ts", "resources/builtins/TextDecoderStream.ts", "typescript", true),
        SourceResource("TextEncoderStream", "bun/src/js/builtins/TextEncoderStream.ts", "resources/builtins/TextEncoderStream.ts", "typescript", true),
        SourceResource("TransformStream", "bun/src/js/builtins/TransformStream.ts", "resources/builtins/TransformStream.ts", "typescript", true),
        SourceResource("TransformStreamDefaultController", "bun/src/js/builtins/TransformStreamDefaultController.ts", "resources/builtins/TransformStreamDefaultController.ts", "typescript", true),
        SourceResource("TransformStreamInternals", "bun/src/js/builtins/TransformStreamInternals.ts", "resources/builtins/TransformStreamInternals.ts", "typescript", true),
        SourceResource("UtilInspect", "bun/src/js/builtins/UtilInspect.ts", "resources/builtins/UtilInspect.ts", "typescript", true),
        SourceResource("WasmStreaming", "bun/src/js/builtins/WasmStreaming.ts", "resources/builtins/WasmStreaming.ts", "typescript", true),
        SourceResource("WritableStreamDefaultController", "bun/src/js/builtins/WritableStreamDefaultController.ts", "resources/builtins/WritableStreamDefaultController.ts", "typescript", true),
        SourceResource("WritableStreamDefaultWriter", "bun/src/js/builtins/WritableStreamDefaultWriter.ts", "resources/builtins/WritableStreamDefaultWriter.ts", "typescript", true),
        SourceResource("WritableStreamInternals", "bun/src/js/builtins/WritableStreamInternals.ts", "resources/builtins/WritableStreamInternals.ts", "typescript", true),
        SourceResource("shell", "bun/src/js/builtins/shell.ts", "resources/builtins/shell.ts", "typescript", true)
    ]
}

public const RESOURCE_COUNT: Int64 = 38
