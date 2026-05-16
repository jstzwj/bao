// Schema codec - encode/decode functions for peechy binary format
// Strict translation from: bun/src/api/schema.js
//   Each decodeXxx(bb) function reads from a ByteBuffer and returns a struct
//   Each encodeXxx(message, bb) function writes a struct to a ByteBuffer
//   ByteBuffer wraps a byte array with a position cursor

package bao_api

import bao_options.*
import bao_options.*
import bao_core.*
import bao_collections.*

// ============================================================================
// ByteBuffer - peechy-style byte buffer reader/writer
// Strict translation from: schema.js implicit ByteBuffer protocol
//   readByte, readString, readInt32, readUint16, readUint32,
//   readVarUint, readByteArray, writeByte, writeString, writeInt32,
//   writeUint16, writeUint32, writeVarUint, writeByteArray
// ============================================================================

/// Peecy-style byte buffer for schema serialization
public class ByteBuffer {
    private var data: Array<UInt8>
    private var pos: Int64

    public init() {
        data = Array<UInt8>()
        pos = 0
    }

    public init(data: Array<UInt8>) {
        this.data = data
        pos = 0
    }

    // -- Reading --

    public func readByte(): UInt8 {
        if (pos >= data.size) {
            return 0
        }
        let v = data[pos]
        pos = pos + 1
        return v
    }

    public func readUint16(): UInt16 {
        let lo = UInt16(readByte())
        let hi = UInt16(readByte())
        return lo | (hi << 8)
    }

    public func readInt32(): Int32 {
        let b0 = Int32(readByte())
        let b1 = Int32(readByte())
        let b2 = Int32(readByte())
        let b3 = Int32(readByte())
        return b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
    }

    public func readUint32(): UInt32 {
        let b0 = UInt32(readByte())
        let b1 = UInt32(readByte())
        let b2 = UInt32(readByte())
        let b3 = UInt32(readByte())
        return b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
    }

    public func readVarUint(): UInt64 {
        var result: UInt64 = 0
        var shift: UInt64 = 0
        var byte: UInt8 = 0
        do {
            byte = readByte()
            result = result | (UInt64(byte & 0x7F) << shift)
            shift = shift + 7
        } while (byte & 0x80) != 0
        return result
    }

    public func readString(): String {
        let len = readVarUint()
        if (len == 0) {
            return ""
        }
        var sb = StringBuilder()
        var i: UInt64 = 0
        while (i < len) {
            sb.append(Char(readByte()))
            i++
        }
        return sb.toString()
    }

    public func readByteArray(): Array<UInt8> {
        let len = readVarUint()
        var result = Array<UInt8>()
        var i: UInt64 = 0
        while (i < len) {
            result.append(readByte())
            i++
        }
        return result
    }

    // -- Writing --

    public func writeByte(b: UInt8): Unit {
        data.append(b)
    }

    public func writeUint16(v: UInt16): Unit {
        writeByte(UInt8(v & 0xFF))
        writeByte(UInt8((v >> 8) & 0xFF))
    }

    public func writeInt32(v: Int32): Unit {
        writeByte(UInt8(v & 0xFF))
        writeByte(UInt8((v >> 8) & 0xFF))
        writeByte(UInt8((v >> 16) & 0xFF))
        writeByte(UInt8((v >> 24) & 0xFF))
    }

    public func writeUint32(v: UInt32): Unit {
        writeByte(UInt8(v & 0xFF))
        writeByte(UInt8((v >> 8) & 0xFF))
        writeByte(UInt8((v >> 16) & 0xFF))
        writeByte(UInt8((v >> 24) & 0xFF))
    }

    public func writeVarUint(v: UInt64): Unit {
        var value = v
        while (value > 0x7F) {
            writeByte(UInt8((value & 0x7F) | 0x80))
            value = value >> 7
        }
        writeByte(UInt8(value & 0x7F))
    }

    public func writeString(s: String): Unit {
        writeVarUint(UInt64(s.size))
        for (c in s) {
            writeByte(UInt8(c.value))
        }
    }

    public func writeByteArray(arr: Array<UInt8>): Unit {
        writeVarUint(UInt64(arr.size))
        for (b in arr) {
            writeByte(b)
        }
    }

    // -- Utility --

    public func getBytes(): Array<UInt8> {
        data
    }

    public func getPosition(): Int64 {
        pos
    }

    public func remaining(): Int64 {
        data.size - pos
    }

    public func reset(): Unit {
        pos = 0
    }
}

// ============================================================================
// decodeStackFramePosition / encodeStackFramePosition
// Strict translation from: schema.js - decodeStackFramePosition / encodeStackFramePosition
// ============================================================================

public func decodeStackFramePosition(bb: ByteBuffer): StackFramePosition {
    let result = StackFramePosition()
    result.line = bb.readInt32()
    result.column = bb.readInt32()
    return result
}

public func encodeStackFramePosition(message: StackFramePosition, bb: ByteBuffer): Unit {
    bb.writeInt32(message.line)
    bb.writeInt32(message.column)
}

// ============================================================================
// decodeStackFrame / encodeStackFrame
// Strict translation from: schema.js - decodeStackFrame / encodeStackFrame
// ============================================================================

public func decodeStackFrame(bb: ByteBuffer): StackFrame {
    let result = StackFrame()
    result.functionName = bb.readString()
    result.file = bb.readString()
    result.position = decodeStackFramePosition(bb)
    result.scope = StackFrameScope.fromRaw(bb.readByte())
    return result
}

public func encodeStackFrame(message: StackFrame, bb: ByteBuffer): Unit {
    bb.writeString(message.functionName)
    bb.writeString(message.file)
    encodeStackFramePosition(message.position, bb)
    bb.writeByte(message.scope.toRaw())
}

// ============================================================================
// decodeSourceLine / encodeSourceLine
// Strict translation from: schema.js - decodeSourceLine / encodeSourceLine
// ============================================================================

public func decodeSourceLine(bb: ByteBuffer): SourceLine {
    let result = SourceLine()
    result.line = bb.readInt32()
    result.text = bb.readString()
    return result
}

public func encodeSourceLine(message: SourceLine, bb: ByteBuffer): Unit {
    bb.writeInt32(message.line)
    bb.writeString(message.text)
}

// ============================================================================
// decodeStackTrace / encodeStackTrace
// Strict translation from: schema.js - decodeStackTrace / encodeStackTrace
// ============================================================================

public func decodeStackTrace(bb: ByteBuffer): StackTrace {
    let result = StackTrace()
    let sourceLen = bb.readVarUint()
    var i: UInt64 = 0
    while (i < sourceLen) {
        result.sourceLines.append(decodeSourceLine(bb))
        i++
    }
    let frameLen = bb.readVarUint()
    i = 0
    while (i < frameLen) {
        result.frames.append(decodeStackFrame(bb))
        i++
    }
    return result
}

public func encodeStackTrace(message: StackTrace, bb: ByteBuffer): Unit {
    bb.writeVarUint(UInt64(message.sourceLines.size))
    for (sl in message.sourceLines) {
        encodeSourceLine(sl, bb)
    }
    bb.writeVarUint(UInt64(message.frames.size))
    for (f in message.frames) {
        encodeStackFrame(f, bb)
    }
}

// ============================================================================
// decodeApiJsException / encodeApiJsException
// Strict translation from: schema.js - decodeJSException / encodeJSException
// ============================================================================

public func decodeApiJsException(bb: ByteBuffer): ApiJsException {
    let result = ApiJsException()
    var done = false
    while (!done) {
        let tag = bb.readByte()
        match (tag) {
            case 0 => done = true
            case 1 => result.name = Some(bb.readString())
            case 2 => result.message = Some(bb.readString())
            case 3 => result.runtimeType = Some(bb.readUint16())
            case 4 => result.code = Some(bb.readByte())
            case 5 => result.stack = Some(decodeStackTrace(bb))
            case _ => done = true
        }
    }
    return result
}

public func encodeApiJsException(message: ApiJsException, bb: ByteBuffer): Unit {
    match (message.name) {
        case Some(v) =>
            bb.writeByte(1)
            bb.writeString(v)
        case None => {}
    }
    match (message.message) {
        case Some(v) =>
            bb.writeByte(2)
            bb.writeString(v)
        case None => {}
    }
    match (message.runtimeType) {
        case Some(v) =>
            bb.writeByte(3)
            bb.writeUint16(v)
        case None => {}
    }
    match (message.code) {
        case Some(v) =>
            bb.writeByte(4)
            bb.writeByte(v)
        case None => {}
    }
    match (message.stack) {
        case Some(v) =>
            bb.writeByte(5)
            encodeStackTrace(v, bb)
        case None => {}
    }
    bb.writeByte(0)
}

// ============================================================================
// decodeApiLog / encodeApiLog
// Strict translation from: schema.js - decodeLog / encodeLog
// ============================================================================

public func decodeApiLog(bb: ByteBuffer): ApiLog {
    let result = ApiLog()
    result.warnings = bb.readUint32()
    result.errors = bb.readUint32()
    let len = bb.readVarUint()
    var i: UInt64 = 0
    while (i < len) {
        result.msgs.append(decodeApiMessage(bb))
        i++
    }
    return result
}

public func encodeApiLog(message: ApiLog, bb: ByteBuffer): Unit {
    bb.writeUint32(message.warnings)
    bb.writeUint32(message.errors)
    bb.writeVarUint(UInt64(message.msgs.size))
    for (m in message.msgs) {
        encodeApiMessage(m, bb)
    }
}

// ============================================================================
// decodeApiProblems / encodeApiProblems
// Strict translation from: schema.js - decodeProblems / encodeProblems
// ============================================================================

public func decodeApiProblems(bb: ByteBuffer): ApiProblems {
    let result = ApiProblems()
    result.code = bb.readUint16()
    result.name = bb.readString()
    let exLen = bb.readVarUint()
    var i: UInt64 = 0
    while (i < exLen) {
        result.exceptions.append(decodeApiJsException(bb))
        i++
    }
    result.build = decodeApiLog(bb)
    return result
}

public func encodeApiProblems(message: ApiProblems, bb: ByteBuffer): Unit {
    bb.writeUint16(message.code)
    bb.writeString(message.name)
    bb.writeVarUint(UInt64(message.exceptions.size))
    for (ex in message.exceptions) {
        encodeApiJsException(ex, bb)
    }
    encodeApiLog(message.build, bb)
}

// ============================================================================
// decodeStringMap / encodeStringMap
// Strict translation from: schema.js - decodeStringMap / encodeStringMap
// ============================================================================

public func decodeStringMap(bb: ByteBuffer): StringMap {
    let keysLen = bb.readVarUint()
    var keys = Array<String>()
    var i: UInt64 = 0
    while (i < keysLen) {
        keys.append(bb.readString())
        i++
    }
    let valsLen = bb.readVarUint()
    var values = Array<String>()
    i = 0
    while (i < valsLen) {
        values.append(bb.readString())
        i++
    }
    return StringMap(keys, values)
}

public func encodeStringMap(message: StringMap, bb: ByteBuffer): Unit {
    bb.writeVarUint(UInt64(message.keys.size))
    for (k in message.keys) {
        bb.writeString(k)
    }
    bb.writeVarUint(UInt64(message.values.size))
    for (v in message.values) {
        bb.writeString(v)
    }
}

// ============================================================================
// decodeApiRouter / encodeApiRouter
// Strict translation from: schema.js - decodeRouter / encodeRouter
// ============================================================================

public func decodeApiRouter(bb: ByteBuffer): ApiRouter {
    let result = ApiRouter()
    result.routes = decodeStringMap(bb)
    result.route = bb.readInt32()
    result.params = decodeStringMap(bb)
    return result
}

public func encodeApiRouter(message: ApiRouter, bb: ByteBuffer): Unit {
    encodeStringMap(message.routes, bb)
    bb.writeInt32(message.route)
    encodeStringMap(message.params, bb)
}

// ============================================================================
// decodeApiFallbackMessageContainer / encodeApiFallbackMessageContainer
// Strict translation from: schema.js - decodeFallbackMessageContainer / encodeFallbackMessageContainer
// ============================================================================

public func decodeApiFallbackMessageContainer(bb: ByteBuffer): ApiFallbackMessageContainer {
    let result = ApiFallbackMessageContainer()
    var done = false
    while (!done) {
        let tag = bb.readByte()
        match (tag) {
            case 0 => done = true
            case 1 => result.message = Some(bb.readString())
            case 2 => result.router = Some(decodeApiRouter(bb))
            case 3 => result.reason = Some(FallbackStep.fromRaw(bb.readByte()))
            case 4 => result.problems = Some(decodeApiProblems(bb))
            case 5 => result.cwd = Some(bb.readString())
            case _ => done = true
        }
    }
    return result
}

public func encodeApiFallbackMessageContainer(message: ApiFallbackMessageContainer, bb: ByteBuffer): Unit {
    match (message.message) {
        case Some(v) =>
            bb.writeByte(1)
            bb.writeString(v)
        case None => {}
    }
    match (message.router) {
        case Some(v) =>
            bb.writeByte(2)
            encodeApiRouter(v, bb)
        case None => {}
    }
    match (message.reason) {
        case Some(v) =>
            bb.writeByte(3)
            bb.writeByte(v.toRaw())
        case None => {}
    }
    match (message.problems) {
        case Some(v) =>
            bb.writeByte(4)
            encodeApiProblems(v, bb)
        case None => {}
    }
    match (message.cwd) {
        case Some(v) =>
            bb.writeByte(5)
            bb.writeString(v)
        case None => {}
    }
    bb.writeByte(0)
}

// ============================================================================
// decodeApiJsx / encodeApiJsx
// Strict translation from: schema.js - decodeJSX / encodeJSX
// ============================================================================

public func decodeApiJsx(bb: ByteBuffer): ApiJsx {
    let result = ApiJsx()
    result.factory = bb.readString()
    result.runtime = ApiJsxRuntime.fromRaw(bb.readByte())
    result.fragment = bb.readString()
    result.development = bb.readByte() != 0
    result.importSource = bb.readString()
    result.reactFastRefresh = bb.readByte() != 0
    return result
}

public func encodeApiJsx(message: ApiJsx, bb: ByteBuffer): Unit {
    bb.writeString(message.factory)
    bb.writeByte(message.runtime.toRaw())
    bb.writeString(message.fragment)
    bb.writeByte(if (message.development) 1 else 0)
    bb.writeString(message.importSource)
    bb.writeByte(if (message.reactFastRefresh) 1 else 0)
}

// ============================================================================
// decodeStringPointer / encodeStringPointer
// Strict translation from: schema.js - decodeStringPointer / encodeStringPointer
// ============================================================================

public func decodeStringPointer(bb: ByteBuffer): StringPointer {
    StringPointer(offset: bb.readUint32(), length: bb.readUint32())
}

public func encodeStringPointer(message: StringPointer, bb: ByteBuffer): Unit {
    bb.writeUint32(message.offset)
    bb.writeUint32(message.length)
}

// ============================================================================
// decodeJavascriptBundledModule / encodeJavascriptBundledModule
// Strict translation from: schema.js - decodeJavascriptBundledModule / encodeJavascriptBundledModule
// ============================================================================

public func decodeJavascriptBundledModule(bb: ByteBuffer): JavascriptBundledModule {
    let result = JavascriptBundledModule()
    result.path = decodeStringPointer(bb)
    result.code = decodeStringPointer(bb)
    result.packageId = bb.readUint32()
    result.id = bb.readUint32()
    result.pathExtnameLength = bb.readByte()
    return result
}

public func encodeJavascriptBundledModule(message: JavascriptBundledModule, bb: ByteBuffer): Unit {
    encodeStringPointer(message.path, bb)
    encodeStringPointer(message.code, bb)
    bb.writeUint32(message.packageId)
    bb.writeUint32(message.id)
    bb.writeByte(message.pathExtnameLength)
}

// ============================================================================
// decodeJavascriptBundledPackage / encodeJavascriptBundledPackage
// Strict translation from: schema.js - decodeJavascriptBundledPackage / encodeJavascriptBundledPackage
// ============================================================================

public func decodeJavascriptBundledPackage(bb: ByteBuffer): JavascriptBundledPackage {
    let result = JavascriptBundledPackage()
    result.name = decodeStringPointer(bb)
    result.version = decodeStringPointer(bb)
    result.hash = bb.readUint32()
    result.modulesOffset = bb.readUint32()
    result.modulesLength = bb.readUint32()
    return result
}

public func encodeJavascriptBundledPackage(message: JavascriptBundledPackage, bb: ByteBuffer): Unit {
    encodeStringPointer(message.name, bb)
    encodeStringPointer(message.version, bb)
    bb.writeUint32(message.hash)
    bb.writeUint32(message.modulesOffset)
    bb.writeUint32(message.modulesLength)
}

// ============================================================================
// decodeJavascriptBundle / encodeJavascriptBundle
// Strict translation from: schema.js - decodeJavascriptBundle / encodeJavascriptBundle
// ============================================================================

public func decodeJavascriptBundle(bb: ByteBuffer): JavascriptBundle {
    let result = JavascriptBundle()
    let modLen = bb.readVarUint()
    var i: UInt64 = 0
    while (i < modLen) {
        result.modules.append(decodeJavascriptBundledModule(bb))
        i++
    }
    let pkgLen = bb.readVarUint()
    i = 0
    while (i < pkgLen) {
        result.packages.append(decodeJavascriptBundledPackage(bb))
        i++
    }
    result.etag = bb.readByteArray()
    result.generatedAt = bb.readUint32()
    result.appPackageJsonDependenciesHash = bb.readByteArray()
    result.importFromName = bb.readByteArray()
    result.manifestString = bb.readByteArray()
    return result
}

public func encodeJavascriptBundle(message: JavascriptBundle, bb: ByteBuffer): Unit {
    bb.writeVarUint(UInt64(message.modules.size))
    for (m in message.modules) {
        encodeJavascriptBundledModule(m, bb)
    }
    bb.writeVarUint(UInt64(message.packages.size))
    for (p in message.packages) {
        encodeJavascriptBundledPackage(p, bb)
    }
    bb.writeByteArray(message.etag)
    bb.writeUint32(message.generatedAt)
    bb.writeByteArray(message.appPackageJsonDependenciesHash)
    bb.writeByteArray(message.importFromName)
    bb.writeByteArray(message.manifestString)
}

// ============================================================================
// decodeApiLoadedRouteConfig / encodeApiLoadedRouteConfig
// Strict translation from: schema.js - decodeLoadedRouteConfig / encodeLoadedRouteConfig
// ============================================================================

public func decodeApiLoadedRouteConfig(bb: ByteBuffer): ApiLoadedRouteConfig {
    let result = ApiLoadedRouteConfig()
    result.dir = bb.readString()
    let extLen = bb.readVarUint()
    var i: UInt64 = 0
    while (i < extLen) {
        result.extensions.append(bb.readString())
        i++
    }
    result.staticDir = bb.readString()
    result.assetPrefix = bb.readString()
    return result
}

public func encodeApiLoadedRouteConfig(message: ApiLoadedRouteConfig, bb: ByteBuffer): Unit {
    bb.writeString(message.dir)
    bb.writeVarUint(UInt64(message.extensions.size))
    for (e in message.extensions) {
        bb.writeString(e)
    }
    bb.writeString(message.staticDir)
    bb.writeString(message.assetPrefix)
}

// ============================================================================
// decodeLoadedFramework / encodeLoadedFramework
// Strict translation from: schema.js - decodeLoadedFramework / encodeLoadedFramework
//   Uses FrameworkEntryPointMap from bao_options.schema, and CssInJsBehavior
// ============================================================================

public func decodeLoadedFramework(bb: ByteBuffer): LoadedFramework {
    let result = LoadedFramework()
    result.packageName = bb.readString()
    result.displayName = bb.readString()
    result.development = bb.readByte() != 0

    result.entryPoints = decodeFrameworkEntryPointMap(bb)
    result.clientCssInJs = CssInJsBehavior.fromRaw(bb.readByte())
    result.overrideModules = decodeStringMap(bb)
    return result
}

public func encodeLoadedFramework(message: LoadedFramework, bb: ByteBuffer): Unit {
    bb.writeString(message.packageName)
    bb.writeString(message.displayName)
    bb.writeByte(if (message.development) 1 else 0)

    encodeFrameworkEntryPointMap(message.entryPoints, bb)

    bb.writeByte(message.clientCssInJs.toRaw())
    encodeStringMap(message.overrideModules, bb)
}

// Helper: decode/encode FrameworkEntryPoint (struct-style, from bao_options.schema)
public func decodeFrameworkEntryPoint(bb: ByteBuffer): FrameworkEntryPoint {
    let result = FrameworkEntryPoint()
    result.kind = FrameworkEntryPointType.fromRaw(bb.readByte())
    result.path = bb.readString()
    result.env = decodeLoadedEnvConfig(bb)
    return result
}

public func encodeFrameworkEntryPoint(message: FrameworkEntryPoint, bb: ByteBuffer): Unit {
    bb.writeByte(message.kind.toRaw())
    bb.writeString(message.path)
    encodeLoadedEnvConfig(message.env, bb)
}

// ============================================================================
// decodeFrameworkEntryPointMap / encodeFrameworkEntryPointMap
// Strict translation from: schema.js - decodeFrameworkEntryPointMap / encodeFrameworkEntryPointMap
// ============================================================================

public func decodeFrameworkEntryPointMap(bb: ByteBuffer): FrameworkEntryPointMap {
    let result = FrameworkEntryPointMap()
    var done = false
    while (!done) {
        let tag = bb.readByte()
        match (tag) {
            case 0 => done = true
            case 1 => result.client = Some(decodeFrameworkEntryPoint(bb))
            case 2 => result.server = Some(decodeFrameworkEntryPoint(bb))
            case 3 => result.fallback = Some(decodeFrameworkEntryPoint(bb))
            case _ => done = true
        }
    }
    return result
}

public func encodeFrameworkEntryPointMap(message: FrameworkEntryPointMap, bb: ByteBuffer): Unit {
    match (message.client) {
        case Some(v) =>
            bb.writeByte(1)
            encodeFrameworkEntryPoint(v, bb)
        case None => {}
    }
    match (message.server) {
        case Some(v) =>
            bb.writeByte(2)
            encodeFrameworkEntryPoint(v, bb)
        case None => {}
    }
    match (message.fallback) {
        case Some(v) =>
            bb.writeByte(3)
            encodeFrameworkEntryPoint(v, bb)
        case None => {}
    }
    bb.writeByte(0)
}

// Helper: decode/encode LoadedEnvConfig (struct-style)
public func decodeLoadedEnvConfig(bb: ByteBuffer): LoadedEnvConfig {
    let result = LoadedEnvConfig()
    result.dotenv = DotEnvBehavior.fromRaw(bb.readByte())
    result.defaults = decodeStringMap(bb)
    result.prefix = bb.readString()
    return result
}

public func encodeLoadedEnvConfig(message: LoadedEnvConfig, bb: ByteBuffer): Unit {
    bb.writeByte(message.dotenv.toRaw())
    encodeStringMap(message.defaults, bb)
    bb.writeString(message.prefix)
}

// ============================================================================
// decodeJavascriptBundleContainer / encodeJavascriptBundleContainer
// Strict translation from: schema.js - decodeJavascriptBundleContainer / encodeJavascriptBundleContainer
// ============================================================================

public func decodeJavascriptBundleContainer(bb: ByteBuffer): JavascriptBundleContainer {
    let result = JavascriptBundleContainer()
    var done = false
    while (!done) {
        let tag = bb.readByte()
        match (tag) {
            case 0 => done = true
            case 1 => result.bundleFormatVersion = Some(bb.readUint32())
            case 2 => result.framework = Some(decodeLoadedFramework(bb))
            case 3 => result.routes = Some(decodeApiLoadedRouteConfig(bb))
            case 4 => result.bundle = Some(decodeJavascriptBundle(bb))
            case 5 => result.codeLength = Some(bb.readUint32())
            case _ => done = true
        }
    }
    return result
}

public func encodeJavascriptBundleContainer(message: JavascriptBundleContainer, bb: ByteBuffer): Unit {
    match (message.bundleFormatVersion) {
        case Some(v) =>
            bb.writeByte(1)
            bb.writeUint32(v)
        case None => {}
    }
    match (message.framework) {
        case Some(v) =>
            bb.writeByte(2)
            encodeLoadedFramework(v, bb)
        case None => {}
    }
    match (message.routes) {
        case Some(v) =>
            bb.writeByte(3)
            encodeApiLoadedRouteConfig(v, bb)
        case None => {}
    }
    match (message.bundle) {
        case Some(v) =>
            bb.writeByte(4)
            encodeJavascriptBundle(v, bb)
        case None => {}
    }
    match (message.codeLength) {
        case Some(v) =>
            bb.writeByte(5)
            bb.writeUint32(v)
        case None => {}
    }
    bb.writeByte(0)
}

// ============================================================================
// decodeApiModuleImportRecord / encodeApiModuleImportRecord
// Strict translation from: schema.js - decodeModuleImportRecord / encodeModuleImportRecord
// ============================================================================

public func decodeApiModuleImportRecord(bb: ByteBuffer): ApiModuleImportRecord {
    let result = ApiModuleImportRecord()
    result.kind = ModuleImportType.fromRaw(bb.readByte())
    result.path = bb.readString()
    result.dynamic = bb.readByte() != 0
    return result
}

public func encodeApiModuleImportRecord(message: ApiModuleImportRecord, bb: ByteBuffer): Unit {
    bb.writeByte(message.kind.toRaw())
    bb.writeString(message.path)
    bb.writeByte(if (message.dynamic) 1 else 0)
}

// ============================================================================
// decodeApiModule / encodeApiModule
// Strict translation from: schema.js - decodeModule / encodeModule
// ============================================================================

public func decodeApiModule(bb: ByteBuffer): ApiModule {
    let result = ApiModule()
    result.path = bb.readString()
    let len = bb.readVarUint()
    var i: UInt64 = 0
    while (i < len) {
        result.imports.append(decodeApiModuleImportRecord(bb))
        i++
    }
    return result
}

public func encodeApiModule(message: ApiModule, bb: ByteBuffer): Unit {
    bb.writeString(message.path)
    bb.writeVarUint(UInt64(message.imports.size))
    for (imp in message.imports) {
        encodeApiModuleImportRecord(imp, bb)
    }
}

// ============================================================================
// decodeLoaderMap / encodeLoaderMap
// Strict translation from: schema.js - decodeLoaderMap / encodeLoaderMap
// ============================================================================

public func decodeLoaderMap(bb: ByteBuffer): LoaderMap {
    let result = LoaderMap()
    let extLen = bb.readVarUint()
    var i: UInt64 = 0
    while (i < extLen) {
        result.extensions.append(bb.readString())
        i++
    }
    let ldrLen = bb.readVarUint()
    i = 0
    while (i < ldrLen) {
        result.loaders.append(Loader.fromRaw(bb.readByte()))
        i++
    }
    return result
}

public func encodeLoaderMap(message: LoaderMap, bb: ByteBuffer): Unit {
    bb.writeVarUint(UInt64(message.extensions.size))
    for (e in message.extensions) {
        bb.writeString(e)
    }
    bb.writeVarUint(UInt64(message.loaders.size))
    for (l in message.loaders) {
        bb.writeByte(l.toRaw())
    }
}

// ============================================================================
// decodeEnvConfig / encodeEnvConfig (message-style)
// Strict translation from: schema.js - decodeEnvConfig / encodeEnvConfig
// ============================================================================

public func decodeEnvConfig(bb: ByteBuffer): EnvConfig {
    let result = EnvConfig()
    var done = false
    while (!done) {
        let tag = bb.readByte()
        match (tag) {
            case 0 => done = true
            case 1 => result.prefix = Some(bb.readString())
            case 2 => result.defaults = Some(decodeStringMap(bb))
            case _ => done = true
        }
    }
    return result
}

public func encodeEnvConfig(message: EnvConfig, bb: ByteBuffer): Unit {
    match (message.prefix) {
        case Some(v) =>
            bb.writeByte(1)
            bb.writeString(v)
        case None => {}
    }
    match (message.defaults) {
        case Some(v) =>
            bb.writeByte(2)
            encodeStringMap(v, bb)
        case None => {}
    }
    bb.writeByte(0)
}

// ============================================================================
// decodeFrameworkEntryPointMessage / encodeFrameworkEntryPointMessage
// Strict translation from: schema.js - decodeFrameworkEntryPointMessage / encodeFrameworkEntryPointMessage
// ============================================================================

public func decodeFrameworkEntryPointMessage(bb: ByteBuffer): FrameworkEntryPointMessage {
    let result = FrameworkEntryPointMessage()
    var done = false
    while (!done) {
        let tag = bb.readByte()
        match (tag) {
            case 0 => done = true
            case 1 => result.path = Some(bb.readString())
            case 2 => result.env = Some(decodeEnvConfig(bb))
            case _ => done = true
        }
    }
    return result
}

public func encodeFrameworkEntryPointMessage(message: FrameworkEntryPointMessage, bb: ByteBuffer): Unit {
    match (message.path) {
        case Some(v) =>
            bb.writeByte(1)
            bb.writeString(v)
        case None => {}
    }
    match (message.env) {
        case Some(v) =>
            bb.writeByte(2)
            encodeEnvConfig(v, bb)
        case None => {}
    }
    bb.writeByte(0)
}

// ============================================================================
// decodeApiFrameworkConfig / encodeApiFrameworkConfig
// Strict translation from: schema.js - decodeFrameworkConfig / encodeFrameworkConfig
// ============================================================================

public func decodeApiFrameworkConfig(bb: ByteBuffer): ApiFrameworkConfig {
    let result = ApiFrameworkConfig()
    var done = false
    while (!done) {
        let tag = bb.readByte()
        match (tag) {
            case 0 => done = true
            case 1 => result.packageName = Some(bb.readString())
            case 2 => result.client = Some(decodeFrameworkEntryPointMessage(bb))
            case 3 => result.server = Some(decodeFrameworkEntryPointMessage(bb))
            case 4 => result.fallback = Some(decodeFrameworkEntryPointMessage(bb))
            case 5 => result.development = Some(bb.readByte() != 0)
            case 6 => result.clientCssInJs = Some(CssInJsBehavior.fromRaw(bb.readByte()))
            case 7 => result.displayName = Some(bb.readString())
            case 8 => result.overrideModules = Some(decodeStringMap(bb))
            case _ => done = true
        }
    }
    return result
}

public func encodeApiFrameworkConfig(message: ApiFrameworkConfig, bb: ByteBuffer): Unit {
    match (message.packageName) {
        case Some(v) =>
            bb.writeByte(1)
            bb.writeString(v)
        case None => {}
    }
    match (message.client) {
        case Some(v) =>
            bb.writeByte(2)
            encodeFrameworkEntryPointMessage(v, bb)
        case None => {}
    }
    match (message.server) {
        case Some(v) =>
            bb.writeByte(3)
            encodeFrameworkEntryPointMessage(v, bb)
        case None => {}
    }
    match (message.fallback) {
        case Some(v) =>
            bb.writeByte(4)
            encodeFrameworkEntryPointMessage(v, bb)
        case None => {}
    }
    match (message.development) {
        case Some(v) =>
            bb.writeByte(5)
            bb.writeByte(if (v) 1 else 0)
        case None => {}
    }
    match (message.clientCssInJs) {
        case Some(v) =>
            bb.writeByte(6)
            bb.writeByte(v.toRaw())
        case None => {}
    }
    match (message.displayName) {
        case Some(v) =>
            bb.writeByte(7)
            bb.writeString(v)
        case None => {}
    }
    match (message.overrideModules) {
        case Some(v) =>
            bb.writeByte(8)
            encodeStringMap(v, bb)
        case None => {}
    }
    bb.writeByte(0)
}

// ============================================================================
// decodeApiRouteConfig / encodeApiRouteConfig
// Strict translation from: schema.js - decodeRouteConfig / encodeRouteConfig
// ============================================================================

public func decodeApiRouteConfig(bb: ByteBuffer): ApiRouteConfig {
    let result = ApiRouteConfig()
    var done = false
    while (!done) {
        let tag = bb.readByte()
        match (tag) {
            case 0 => done = true
            case 1 =>
                var arr = Array<String>()
                let len = bb.readVarUint()
                var i: UInt64 = 0
                while (i < len) {
                    arr.append(bb.readString())
                    i++
                }
                result.dir = Some(arr)
            case 2 =>
                var arr = Array<String>()
                let len = bb.readVarUint()
                var i: UInt64 = 0
                while (i < len) {
                    arr.append(bb.readString())
                    i++
                }
                result.extensions = Some(arr)
            case 3 => result.staticDir = Some(bb.readString())
            case 4 => result.assetPrefix = Some(bb.readString())
            case _ => done = true
        }
    }
    return result
}

public func encodeApiRouteConfig(message: ApiRouteConfig, bb: ByteBuffer): Unit {
    match (message.dir) {
        case Some(arr) =>
            bb.writeByte(1)
            bb.writeVarUint(UInt64(arr.size))
            for (s in arr) {
                bb.writeString(s)
            }
        case None => {}
    }
    match (message.extensions) {
        case Some(arr) =>
            bb.writeByte(2)
            bb.writeVarUint(UInt64(arr.size))
            for (s in arr) {
                bb.writeString(s)
            }
        case None => {}
    }
    match (message.staticDir) {
        case Some(v) =>
            bb.writeByte(3)
            bb.writeString(v)
        case None => {}
    }
    match (message.assetPrefix) {
        case Some(v) =>
            bb.writeByte(4)
            bb.writeString(v)
        case None => {}
    }
    bb.writeByte(0)
}

// ============================================================================
// decodeApiTransformOptions / encodeApiTransformOptions
// Strict translation from: schema.js - decodeTransformOptions / encodeTransformOptions
// ============================================================================

public func decodeApiTransformOptions(bb: ByteBuffer): ApiTransformOptions {
    let result = ApiTransformOptions()
    var done = false
    while (!done) {
        let tag = bb.readByte()
        match (tag) {
            case 0 => done = true
            case 1 => result.jsx = Some(decodeApiJsx(bb))
            case 2 => result.tsconfigOverride = Some(bb.readString())
            case 3 => result.resolve = Some(ResolveMode.fromRaw(bb.readByte()))
            case 4 => result.origin = Some(bb.readString())
            case 5 => result.absoluteWorkingDir = Some(bb.readString())
            case 6 => result.define = Some(decodeStringMap(bb))
            case 7 => result.preserveSymlinks = Some(bb.readByte() != 0)
            case 8 =>
                var arr = Array<String>()
                let len = bb.readVarUint()
                var i: UInt64 = 0
                while (i < len) {
                    arr.append(bb.readString())
                    i++
                }
                result.entryPoints = Some(arr)
            case 9 => result.write = Some(bb.readByte() != 0)
            case 10 =>
                var arr = Array<String>()
                let len = bb.readVarUint()
                var i: UInt64 = 0
                while (i < len) {
                    arr.append(bb.readString())
                    i++
                }
                result.inject = Some(arr)
            case 11 => result.outputDir = Some(bb.readString())
            case 12 =>
                var arr = Array<String>()
                let len = bb.readVarUint()
                var i: UInt64 = 0
                while (i < len) {
                    arr.append(bb.readString())
                    i++
                }
                result.external = Some(arr)
            case 13 => result.loaders = Some(decodeLoaderMap(bb))
            case 14 =>
                var arr = Array<String>()
                let len = bb.readVarUint()
                var i: UInt64 = 0
                while (i < len) {
                    arr.append(bb.readString())
                    i++
                }
                result.mainFields = Some(arr)
            case 15 => result.target = Some(SchemaTarget.fromRaw(bb.readByte()))
            case 16 => result.serve = Some(bb.readByte() != 0)
            case 17 =>
                var arr = Array<String>()
                let len = bb.readVarUint()
                var i: UInt64 = 0
                while (i < len) {
                    arr.append(bb.readString())
                    i++
                }
                result.envFiles = Some(arr)
            case 18 =>
                var arr = Array<String>()
                let len = bb.readVarUint()
                var i: UInt64 = 0
                while (i < len) {
                    arr.append(bb.readString())
                    i++
                }
                result.extensionOrder = Some(arr)
            case 19 => result.framework = Some(decodeApiFrameworkConfig(bb))
            case 20 => result.router = Some(decodeApiRouteConfig(bb))
            case 21 => result.noSummary = Some(bb.readByte() != 0)
            case 22 => result.disableHmr = Some(bb.readByte() != 0)
            case 23 => result.port = Some(bb.readUint16())
            case 24 => result.logLevel = Some(MessageLevel.fromRaw(bb.readByte()))
            case 25 => result.sourceMap = Some(SourceMapMode.fromRaw(bb.readByte()))
            case _ => done = true
        }
    }
    return result
}

public func encodeApiTransformOptions(message: ApiTransformOptions, bb: ByteBuffer): Unit {
    match (message.jsx) {
        case Some(v) =>
            bb.writeByte(1)
            encodeApiJsx(v, bb)
        case None => {}
    }
    match (message.tsconfigOverride) {
        case Some(v) =>
            bb.writeByte(2)
            bb.writeString(v)
        case None => {}
    }
    match (message.resolve) {
        case Some(v) =>
            bb.writeByte(3)
            bb.writeByte(v.toRaw())
        case None => {}
    }
    match (message.origin) {
        case Some(v) =>
            bb.writeByte(4)
            bb.writeString(v)
        case None => {}
    }
    match (message.absoluteWorkingDir) {
        case Some(v) =>
            bb.writeByte(5)
            bb.writeString(v)
        case None => {}
    }
    match (message.define) {
        case Some(v) =>
            bb.writeByte(6)
            encodeStringMap(v, bb)
        case None => {}
    }
    match (message.preserveSymlinks) {
        case Some(v) =>
            bb.writeByte(7)
            bb.writeByte(if (v) 1 else 0)
        case None => {}
    }
    match (message.entryPoints) {
        case Some(arr) =>
            bb.writeByte(8)
            bb.writeVarUint(UInt64(arr.size))
            for (s in arr) {
                bb.writeString(s)
            }
        case None => {}
    }
    match (message.write) {
        case Some(v) =>
            bb.writeByte(9)
            bb.writeByte(if (v) 1 else 0)
        case None => {}
    }
    match (message.inject) {
        case Some(arr) =>
            bb.writeByte(10)
            bb.writeVarUint(UInt64(arr.size))
            for (s in arr) {
                bb.writeString(s)
            }
        case None => {}
    }
    match (message.outputDir) {
        case Some(v) =>
            bb.writeByte(11)
            bb.writeString(v)
        case None => {}
    }
    match (message.external) {
        case Some(arr) =>
            bb.writeByte(12)
            bb.writeVarUint(UInt64(arr.size))
            for (s in arr) {
                bb.writeString(s)
            }
        case None => {}
    }
    match (message.loaders) {
        case Some(v) =>
            bb.writeByte(13)
            encodeLoaderMap(v, bb)
        case None => {}
    }
    match (message.mainFields) {
        case Some(arr) =>
            bb.writeByte(14)
            bb.writeVarUint(UInt64(arr.size))
            for (s in arr) {
                bb.writeString(s)
            }
        case None => {}
    }
    match (message.target) {
        case Some(v) =>
            bb.writeByte(15)
            bb.writeByte(v.toRaw())
        case None => {}
    }
    match (message.serve) {
        case Some(v) =>
            bb.writeByte(16)
            bb.writeByte(if (v) 1 else 0)
        case None => {}
    }
    match (message.envFiles) {
        case Some(arr) =>
            bb.writeByte(17)
            bb.writeVarUint(UInt64(arr.size))
            for (s in arr) {
                bb.writeString(s)
            }
        case None => {}
    }
    match (message.extensionOrder) {
        case Some(arr) =>
            bb.writeByte(18)
            bb.writeVarUint(UInt64(arr.size))
            for (s in arr) {
                bb.writeString(s)
            }
        case None => {}
    }
    match (message.framework) {
        case Some(v) =>
            bb.writeByte(19)
            encodeApiFrameworkConfig(v, bb)
        case None => {}
    }
    match (message.router) {
        case Some(v) =>
            bb.writeByte(20)
            encodeApiRouteConfig(v, bb)
        case None => {}
    }
    match (message.noSummary) {
        case Some(v) =>
            bb.writeByte(21)
            bb.writeByte(if (v) 1 else 0)
        case None => {}
    }
    match (message.disableHmr) {
        case Some(v) =>
            bb.writeByte(22)
            bb.writeByte(if (v) 1 else 0)
        case None => {}
    }
    match (message.port) {
        case Some(v) =>
            bb.writeByte(23)
            bb.writeUint16(v)
        case None => {}
    }
    match (message.logLevel) {
        case Some(v) =>
            bb.writeByte(24)
            bb.writeByte(v.toRaw())
        case None => {}
    }
    match (message.sourceMap) {
        case Some(v) =>
            bb.writeByte(25)
            bb.writeByte(v.toRaw())
        case None => {}
    }
    bb.writeByte(0)
}

// ============================================================================
// decodeFileHandle / encodeFileHandle
// Strict translation from: schema.js - decodeFileHandle / encodeFileHandle
// ============================================================================

public func decodeFileHandle(bb: ByteBuffer): FileHandle {
    let result = FileHandle()
    result.path = bb.readString()
    result.size = bb.readVarUint()
    result.fd = bb.readVarUint()
    return result
}

public func encodeFileHandle(message: FileHandle, bb: ByteBuffer): Unit {
    bb.writeString(message.path)
    bb.writeVarUint(message.size)
    bb.writeVarUint(message.fd)
}

// ============================================================================
// decodeApiTransform / encodeApiTransform
// Strict translation from: schema.js - decodeTransform / encodeTransform
// ============================================================================

public func decodeApiTransform(bb: ByteBuffer): ApiTransform {
    let result = ApiTransform()
    var done = false
    while (!done) {
        let tag = bb.readByte()
        match (tag) {
            case 0 => done = true
            case 1 => result.handle = Some(decodeFileHandle(bb))
            case 2 => result.path = Some(bb.readString())
            case 3 => result.contents = Some(bb.readByteArray())
            case 4 => result.loader = Some(Loader.fromRaw(bb.readByte()))
            case 5 => result.options = Some(decodeApiTransformOptions(bb))
            case _ => done = true
        }
    }
    return result
}

public func encodeApiTransform(message: ApiTransform, bb: ByteBuffer): Unit {
    match (message.handle) {
        case Some(v) =>
            bb.writeByte(1)
            encodeFileHandle(v, bb)
        case None => {}
    }
    match (message.path) {
        case Some(v) =>
            bb.writeByte(2)
            bb.writeString(v)
        case None => {}
    }
    match (message.contents) {
        case Some(v) =>
            bb.writeByte(3)
            bb.writeByteArray(v)
        case None => {}
    }
    match (message.loader) {
        case Some(v) =>
            bb.writeByte(4)
            bb.writeByte(v.toRaw())
        case None => {}
    }
    match (message.options) {
        case Some(v) =>
            bb.writeByte(5)
            encodeApiTransformOptions(v, bb)
        case None => {}
    }
    bb.writeByte(0)
}

// ============================================================================
// decodeApiScan / encodeApiScan
// Strict translation from: schema.js - decodeScan / encodeScan
// ============================================================================

public func decodeApiScan(bb: ByteBuffer): ApiScan {
    let result = ApiScan()
    var done = false
    while (!done) {
        let tag = bb.readByte()
        match (tag) {
            case 0 => done = true
            case 1 => result.path = Some(bb.readString())
            case 2 => result.contents = Some(bb.readByteArray())
            case 3 => result.loader = Some(Loader.fromRaw(bb.readByte()))
            case _ => done = true
        }
    }
    return result
}

public func encodeApiScan(message: ApiScan, bb: ByteBuffer): Unit {
    match (message.path) {
        case Some(v) =>
            bb.writeByte(1)
            bb.writeString(v)
        case None => {}
    }
    match (message.contents) {
        case Some(v) =>
            bb.writeByte(2)
            bb.writeByteArray(v)
        case None => {}
    }
    match (message.loader) {
        case Some(v) =>
            bb.writeByte(3)
            bb.writeByte(v.toRaw())
        case None => {}
    }
    bb.writeByte(0)
}

// ============================================================================
// decodeScannedImport / encodeScannedImport
// Strict translation from: schema.js - decodeScannedImport / encodeScannedImport
// ============================================================================

public func decodeScannedImport(bb: ByteBuffer): ScannedImport {
    let result = ScannedImport()
    result.path = bb.readString()
    result.kind = SchemaImportKind.fromRaw(bb.readByte())
    return result
}

public func encodeScannedImport(message: ScannedImport, bb: ByteBuffer): Unit {
    bb.writeString(message.path)
    bb.writeByte(message.kind.toRaw())
}

// ============================================================================
// decodeApiLocation / encodeApiLocation
// Strict translation from: schema.js - decodeLocation / encodeLocation
// ============================================================================

public func decodeApiLocation(bb: ByteBuffer): ApiLocation {
    let result = ApiLocation()
    result.file = bb.readString()
    result.namespace = bb.readString()
    result.line = bb.readInt32()
    result.column = bb.readInt32()
    result.lineText = bb.readString()
    result.suggestion = bb.readString()
    result.offset = bb.readVarUint()
    return result
}

public func encodeApiLocation(message: ApiLocation, bb: ByteBuffer): Unit {
    bb.writeString(message.file)
    bb.writeString(message.namespace)
    bb.writeInt32(message.line)
    bb.writeInt32(message.column)
    bb.writeString(message.lineText)
    bb.writeString(message.suggestion)
    bb.writeVarUint(message.offset)
}

// ============================================================================
// decodeApiMessageData / encodeApiMessageData
// Strict translation from: schema.js - decodeMessageData / encodeMessageData
// ============================================================================

public func decodeApiMessageData(bb: ByteBuffer): ApiMessageData {
    let result = ApiMessageData()
    var done = false
    while (!done) {
        let tag = bb.readByte()
        match (tag) {
            case 0 => done = true
            case 1 => result.text = Some(bb.readString())
            case 2 => result.location = Some(decodeApiLocation(bb))
            case _ => done = true
        }
    }
    return result
}

public func encodeApiMessageData(message: ApiMessageData, bb: ByteBuffer): Unit {
    match (message.text) {
        case Some(v) =>
            bb.writeByte(1)
            bb.writeString(v)
        case None => {}
    }
    match (message.location) {
        case Some(v) =>
            bb.writeByte(2)
            encodeApiLocation(v, bb)
        case None => {}
    }
    bb.writeByte(0)
}

// ============================================================================
// decodeApiMessageMeta / encodeApiMessageMeta
// Strict translation from: schema.js - decodeMessageMeta / encodeMessageMeta
// ============================================================================

public func decodeApiMessageMeta(bb: ByteBuffer): ApiMessageMeta {
    let result = ApiMessageMeta()
    var done = false
    while (!done) {
        let tag = bb.readByte()
        match (tag) {
            case 0 => done = true
            case 1 => result.resolve = Some(bb.readString())
            case 2 => result.build = Some(bb.readByte() != 0)
            case _ => done = true
        }
    }
    return result
}

public func encodeApiMessageMeta(message: ApiMessageMeta, bb: ByteBuffer): Unit {
    match (message.resolve) {
        case Some(v) =>
            bb.writeByte(1)
            bb.writeString(v)
        case None => {}
    }
    match (message.build) {
        case Some(v) =>
            bb.writeByte(2)
            bb.writeByte(if (v) 1 else 0)
        case None => {}
    }
    bb.writeByte(0)
}

// ============================================================================
// decodeApiMessage / encodeApiMessage
// Strict translation from: schema.js - decodeMessage / encodeMessage
// ============================================================================

public func decodeApiMessage(bb: ByteBuffer): ApiMessage {
    let result = ApiMessage()
    result.level = MessageLevel.fromRaw(bb.readByte())
    result.data = decodeApiMessageData(bb)
    let notesLen = bb.readVarUint()
    var i: UInt64 = 0
    while (i < notesLen) {
        result.notes.append(decodeApiMessageData(bb))
        i++
    }
    result.on = decodeApiMessageMeta(bb)
    return result
}

public func encodeApiMessage(message: ApiMessage, bb: ByteBuffer): Unit {
    bb.writeByte(message.level.toRaw())
    encodeApiMessageData(message.data, bb)
    bb.writeVarUint(UInt64(message.notes.size))
    for (n in message.notes) {
        encodeApiMessageData(n, bb)
    }
    encodeApiMessageMeta(message.on, bb)
}

// ============================================================================
// decodeScanResult / encodeScanResult
// Strict translation from: schema.js - decodeScanResult / encodeScanResult
// ============================================================================

public func decodeScanResult(bb: ByteBuffer): ScanResult {
    let result = ScanResult()
    let expLen = bb.readVarUint()
    var i: UInt64 = 0
    while (i < expLen) {
        result.exports.append(bb.readString())
        i++
    }
    let impLen = bb.readVarUint()
    i = 0
    while (i < impLen) {
        result.imports.append(decodeScannedImport(bb))
        i++
    }
    let errLen = bb.readVarUint()
    i = 0
    while (i < errLen) {
        result.errors.append(decodeApiMessage(bb))
        i++
    }
    return result
}

public func encodeScanResult(message: ScanResult, bb: ByteBuffer): Unit {
    bb.writeVarUint(UInt64(message.exports.size))
    for (e in message.exports) {
        bb.writeString(e)
    }
    bb.writeVarUint(UInt64(message.imports.size))
    for (imp in message.imports) {
        encodeScannedImport(imp, bb)
    }
    bb.writeVarUint(UInt64(message.errors.size))
    for (err in message.errors) {
        encodeApiMessage(err, bb)
    }
}

// ============================================================================
// decodeOutputFile / encodeOutputFile
// Strict translation from: schema.js - decodeOutputFile / encodeOutputFile
// ============================================================================

public func decodeOutputFile(bb: ByteBuffer): OutputFile {
    let result = OutputFile()
    result.data = bb.readByteArray()
    result.path = bb.readString()
    return result
}

public func encodeOutputFile(message: OutputFile, bb: ByteBuffer): Unit {
    bb.writeByteArray(message.data)
    bb.writeString(message.path)
}

// ============================================================================
// decodeTransformResponse / encodeTransformResponse
// Strict translation from: schema.js - decodeTransformResponse / encodeTransformResponse
// ============================================================================

public func decodeTransformResponse(bb: ByteBuffer): TransformResponse {
    let result = TransformResponse()
    result.status = TransformResponseStatus.fromRaw(UInt32(bb.readVarUint()))
    let filesLen = bb.readVarUint()
    var i: UInt64 = 0
    while (i < filesLen) {
        result.files.append(decodeOutputFile(bb))
        i++
    }
    let errLen = bb.readVarUint()
    i = 0
    while (i < errLen) {
        result.errors.append(decodeApiMessage(bb))
        i++
    }
    return result
}

public func encodeTransformResponse(message: TransformResponse, bb: ByteBuffer): Unit {
    bb.writeVarUint(UInt64(message.status.toRaw()))
    bb.writeVarUint(UInt64(message.files.size))
    for (f in message.files) {
        encodeOutputFile(f, bb)
    }
    bb.writeVarUint(UInt64(message.errors.size))
    for (e in message.errors) {
        encodeApiMessage(e, bb)
    }
}

// ============================================================================
// decodeWebsocketMessage / encodeWebsocketMessage
// Strict translation from: schema.js - decodeWebsocketMessage / encodeWebsocketMessage
// ============================================================================

public func decodeWebsocketMessage(bb: ByteBuffer): WebsocketMessage {
    let result = WebsocketMessage()
    result.timestamp = bb.readUint32()
    result.kind = WebsocketMessageKind.fromRaw(bb.readByte())
    return result
}

public func encodeWebsocketMessage(message: WebsocketMessage, bb: ByteBuffer): Unit {
    bb.writeUint32(message.timestamp)
    bb.writeByte(message.kind.toRaw())
}

// ============================================================================
// decodeWebsocketMessageWelcome / encodeWebsocketMessageWelcome
// Strict translation from: schema.js - decodeWebsocketMessageWelcome / encodeWebsocketMessageWelcome
// ============================================================================

public func decodeWebsocketMessageWelcome(bb: ByteBuffer): WebsocketMessageWelcome {
    let result = WebsocketMessageWelcome()
    result.epoch = bb.readUint32()
    result.javascriptReloader = Reloader.fromRaw(bb.readByte())
    result.cwd = bb.readString()
    result.assetPrefix = bb.readString()
    return result
}

public func encodeWebsocketMessageWelcome(message: WebsocketMessageWelcome, bb: ByteBuffer): Unit {
    bb.writeUint32(message.epoch)
    bb.writeByte(message.javascriptReloader.toRaw())
    bb.writeString(message.cwd)
    bb.writeString(message.assetPrefix)
}

// ============================================================================
// decodeWebsocketMessageFileChangeNotification / encodeWebsocketMessageFileChangeNotification
// Strict translation from: schema.js - decodeWebsocketMessageFileChangeNotification / encodeWebsocketMessageFileChangeNotification
// ============================================================================

public func decodeWebsocketMessageFileChangeNotification(bb: ByteBuffer): WebsocketMessageFileChangeNotification {
    let result = WebsocketMessageFileChangeNotification()
    result.id = bb.readUint32()
    result.loader = Loader.fromRaw(bb.readByte())
    return result
}

public func encodeWebsocketMessageFileChangeNotification(message: WebsocketMessageFileChangeNotification, bb: ByteBuffer): Unit {
    bb.writeUint32(message.id)
    bb.writeByte(message.loader.toRaw())
}

// ============================================================================
// decodeWebsocketCommand / encodeWebsocketCommand
// Strict translation from: schema.js - decodeWebsocketCommand / encodeWebsocketCommand
// ============================================================================

public func decodeWebsocketCommand(bb: ByteBuffer): WebsocketCommand {
    let result = WebsocketCommand()
    result.kind = WebsocketCommandKind.fromRaw(bb.readByte())
    result.timestamp = bb.readUint32()
    return result
}

public func encodeWebsocketCommand(message: WebsocketCommand, bb: ByteBuffer): Unit {
    bb.writeByte(message.kind.toRaw())
    bb.writeUint32(message.timestamp)
}

// ============================================================================
// decodeWebsocketCommandBuild / encodeWebsocketCommandBuild
// Strict translation from: schema.js - decodeWebsocketCommandBuild / encodeWebsocketCommandBuild
// ============================================================================

public func decodeWebsocketCommandBuild(bb: ByteBuffer): WebsocketCommandBuild {
    let result = WebsocketCommandBuild()
    result.id = bb.readUint32()
    return result
}

public func encodeWebsocketCommandBuild(message: WebsocketCommandBuild, bb: ByteBuffer): Unit {
    bb.writeUint32(message.id)
}

// ============================================================================
// decodeWebsocketCommandManifest / encodeWebsocketCommandManifest
// Strict translation from: schema.js - decodeWebsocketCommandManifest / encodeWebsocketCommandManifest
// ============================================================================

public func decodeWebsocketCommandManifest(bb: ByteBuffer): WebsocketCommandManifest {
    let result = WebsocketCommandManifest()
    result.id = bb.readUint32()
    return result
}

public func encodeWebsocketCommandManifest(message: WebsocketCommandManifest, bb: ByteBuffer): Unit {
    bb.writeUint32(message.id)
}

// ============================================================================
// decodeWebsocketMessageBuildSuccess / encodeWebsocketMessageBuildSuccess
// Strict translation from: schema.js - decodeWebsocketMessageBuildSuccess / encodeWebsocketMessageBuildSuccess
// ============================================================================

public func decodeWebsocketMessageBuildSuccess(bb: ByteBuffer): WebsocketMessageBuildSuccess {
    let result = WebsocketMessageBuildSuccess()
    result.id = bb.readUint32()
    result.fromTimestamp = bb.readUint32()
    result.loader = Loader.fromRaw(bb.readByte())
    result.modulePath = bb.readString()
    result.blobLength = bb.readUint32()
    return result
}

public func encodeWebsocketMessageBuildSuccess(message: WebsocketMessageBuildSuccess, bb: ByteBuffer): Unit {
    bb.writeUint32(message.id)
    bb.writeUint32(message.fromTimestamp)
    bb.writeByte(message.loader.toRaw())
    bb.writeString(message.modulePath)
    bb.writeUint32(message.blobLength)
}

// ============================================================================
// decodeWebsocketMessageBuildFailure / encodeWebsocketMessageBuildFailure
// Strict translation from: schema.js - decodeWebsocketMessageBuildFailure / encodeWebsocketMessageBuildFailure
// ============================================================================

public func decodeWebsocketMessageBuildFailure(bb: ByteBuffer): WebsocketMessageBuildFailure {
    let result = WebsocketMessageBuildFailure()
    result.id = bb.readUint32()
    result.fromTimestamp = bb.readUint32()
    result.loader = Loader.fromRaw(bb.readByte())
    result.modulePath = bb.readString()
    result.log = decodeApiLog(bb)
    return result
}

public func encodeWebsocketMessageBuildFailure(message: WebsocketMessageBuildFailure, bb: ByteBuffer): Unit {
    bb.writeUint32(message.id)
    bb.writeUint32(message.fromTimestamp)
    bb.writeByte(message.loader.toRaw())
    bb.writeString(message.modulePath)
    encodeApiLog(message.log, bb)
}

// ============================================================================
// decodeWebsocketCommandBuildWithFilePath / encodeWebsocketCommandBuildWithFilePath
// Strict translation from: schema.js - decodeWebsocketCommandBuildWithFilePath / encodeWebsocketCommandBuildWithFilePath
// ============================================================================

public func decodeWebsocketCommandBuildWithFilePath(bb: ByteBuffer): WebsocketCommandBuildWithFilePath {
    let result = WebsocketCommandBuildWithFilePath()
    result.id = bb.readUint32()
    result.filePath = bb.readString()
    return result
}

public func encodeWebsocketCommandBuildWithFilePath(message: WebsocketCommandBuildWithFilePath, bb: ByteBuffer): Unit {
    bb.writeUint32(message.id)
    bb.writeString(message.filePath)
}

// ============================================================================
// decodeWebsocketMessageResolveID / encodeWebsocketMessageResolveID
// Strict translation from: schema.js - decodeWebsocketMessageResolveID / encodeWebsocketMessageResolveID
// ============================================================================

public func decodeWebsocketMessageResolveID(bb: ByteBuffer): WebsocketMessageResolveID {
    let result = WebsocketMessageResolveID()
    result.id = bb.readUint32()
    return result
}

public func encodeWebsocketMessageResolveID(message: WebsocketMessageResolveID, bb: ByteBuffer): Unit {
    bb.writeUint32(message.id)
}

// ============================================================================
// decodeApiNpmRegistry / encodeApiNpmRegistry
// Strict translation from: schema.js - decodeNPMRegistry / encodeNPMRegistry
// ============================================================================

public func decodeApiNpmRegistry(bb: ByteBuffer): ApiNpmRegistry {
    let result = ApiNpmRegistry()
    result.url = bb.readString()
    result.username = bb.readString()
    result.password = bb.readString()
    result.token = bb.readString()
    return result
}

public func encodeApiNpmRegistry(message: ApiNpmRegistry, bb: ByteBuffer): Unit {
    bb.writeString(message.url)
    bb.writeString(message.username)
    bb.writeString(message.password)
    bb.writeString(message.token)
}

// ============================================================================
// decodeApiNpmRegistryMap / encodeApiNpmRegistryMap
// Strict translation from: schema.js - decodeNPMRegistryMap / encodeNPMRegistryMap
// ============================================================================

public func decodeApiNpmRegistryMap(bb: ByteBuffer): ApiNpmRegistryMap {
    let result = ApiNpmRegistryMap()
    let scopesLen = bb.readVarUint()
    var i: UInt64 = 0
    while (i < scopesLen) {
        result.scopes.append(bb.readString())
        i++
    }
    let regsLen = bb.readVarUint()
    i = 0
    while (i < regsLen) {
        result.registries.append(decodeApiNpmRegistry(bb))
        i++
    }
    return result
}

public func encodeApiNpmRegistryMap(message: ApiNpmRegistryMap, bb: ByteBuffer): Unit {
    bb.writeVarUint(UInt64(message.scopes.size))
    for (s in message.scopes) {
        bb.writeString(s)
    }
    bb.writeVarUint(UInt64(message.registries.size))
    for (r in message.registries) {
        encodeApiNpmRegistry(r, bb)
    }
}

// ============================================================================
// decodeApiBunInstall / encodeApiBunInstall
// Strict translation from: schema.js - decodeBunInstall / encodeBunInstall
// ============================================================================

public func decodeApiBunInstall(bb: ByteBuffer): ApiBunInstall {
    let result = ApiBunInstall()
    var done = false
    while (!done) {
        let tag = bb.readByte()
        match (tag) {
            case 0 => done = true
            case 1 => result.defaultRegistry = Some(decodeApiNpmRegistry(bb))
            case 2 => result.scoped = Some(decodeApiNpmRegistryMap(bb))
            case 3 => result.lockfilePath = Some(bb.readString())
            case 4 => result.saveLockfilePath = Some(bb.readString())
            case 5 => result.cacheDirectory = Some(bb.readString())
            case 6 => result.dryRun = Some(bb.readByte() != 0)
            case 7 => result.force = Some(bb.readByte() != 0)
            case 8 => result.saveDev = Some(bb.readByte() != 0)
            case 9 => result.saveOptional = Some(bb.readByte() != 0)
            case 10 => result.savePeer = Some(bb.readByte() != 0)
            case 11 => result.saveLockfile = Some(bb.readByte() != 0)
            case 12 => result.production = Some(bb.readByte() != 0)
            case 13 => result.saveYarnLockfile = Some(bb.readByte() != 0)
            case 14 =>
                var arr = Array<String>()
                let len = bb.readVarUint()
                var i: UInt64 = 0
                while (i < len) {
                    arr.append(bb.readString())
                    i++
                }
                result.nativeBinLinks = Some(arr)
            case 15 => result.disableCache = Some(bb.readByte() != 0)
            case 16 => result.disableManifestCache = Some(bb.readByte() != 0)
            case 17 => result.globalDir = Some(bb.readString())
            case 18 => result.globalBinDir = Some(bb.readString())
            case 19 => result.frozenLockfile = Some(bb.readByte() != 0)
            case 20 => result.exact = Some(bb.readByte() != 0)
            case 21 => result.concurrentScripts = Some(bb.readUint32())
            case _ => done = true
        }
    }
    return result
}

public func encodeApiBunInstall(message: ApiBunInstall, bb: ByteBuffer): Unit {
    match (message.defaultRegistry) {
        case Some(v) =>
            bb.writeByte(1)
            encodeApiNpmRegistry(v, bb)
        case None => {}
    }
    match (message.scoped) {
        case Some(v) =>
            bb.writeByte(2)
            encodeApiNpmRegistryMap(v, bb)
        case None => {}
    }
    match (message.lockfilePath) {
        case Some(v) =>
            bb.writeByte(3)
            bb.writeString(v)
        case None => {}
    }
    match (message.saveLockfilePath) {
        case Some(v) =>
            bb.writeByte(4)
            bb.writeString(v)
        case None => {}
    }
    match (message.cacheDirectory) {
        case Some(v) =>
            bb.writeByte(5)
            bb.writeString(v)
        case None => {}
    }
    match (message.dryRun) {
        case Some(v) =>
            bb.writeByte(6)
            bb.writeByte(if (v) 1 else 0)
        case None => {}
    }
    match (message.force) {
        case Some(v) =>
            bb.writeByte(7)
            bb.writeByte(if (v) 1 else 0)
        case None => {}
    }
    match (message.saveDev) {
        case Some(v) =>
            bb.writeByte(8)
            bb.writeByte(if (v) 1 else 0)
        case None => {}
    }
    match (message.saveOptional) {
        case Some(v) =>
            bb.writeByte(9)
            bb.writeByte(if (v) 1 else 0)
        case None => {}
    }
    match (message.savePeer) {
        case Some(v) =>
            bb.writeByte(10)
            bb.writeByte(if (v) 1 else 0)
        case None => {}
    }
    match (message.saveLockfile) {
        case Some(v) =>
            bb.writeByte(11)
            bb.writeByte(if (v) 1 else 0)
        case None => {}
    }
    match (message.production) {
        case Some(v) =>
            bb.writeByte(12)
            bb.writeByte(if (v) 1 else 0)
        case None => {}
    }
    match (message.saveYarnLockfile) {
        case Some(v) =>
            bb.writeByte(13)
            bb.writeByte(if (v) 1 else 0)
        case None => {}
    }
    match (message.nativeBinLinks) {
        case Some(arr) =>
            bb.writeByte(14)
            bb.writeVarUint(UInt64(arr.size))
            for (s in arr) {
                bb.writeString(s)
            }
        case None => {}
    }
    match (message.disableCache) {
        case Some(v) =>
            bb.writeByte(15)
            bb.writeByte(if (v) 1 else 0)
        case None => {}
    }
    match (message.disableManifestCache) {
        case Some(v) =>
            bb.writeByte(16)
            bb.writeByte(if (v) 1 else 0)
        case None => {}
    }
    match (message.globalDir) {
        case Some(v) =>
            bb.writeByte(17)
            bb.writeString(v)
        case None => {}
    }
    match (message.globalBinDir) {
        case Some(v) =>
            bb.writeByte(18)
            bb.writeString(v)
        case None => {}
    }
    match (message.frozenLockfile) {
        case Some(v) =>
            bb.writeByte(19)
            bb.writeByte(if (v) 1 else 0)
        case None => {}
    }
    match (message.exact) {
        case Some(v) =>
            bb.writeByte(20)
            bb.writeByte(if (v) 1 else 0)
        case None => {}
    }
    match (message.concurrentScripts) {
        case Some(v) =>
            bb.writeByte(21)
            bb.writeUint32(v)
        case None => {}
    }
    bb.writeByte(0)
}

// ============================================================================
// decodeClientServerModule / encodeClientServerModule
// Strict translation from: schema.js - decodeClientServerModule / encodeClientServerModule
// ============================================================================

public func decodeClientServerModule(bb: ByteBuffer): ClientServerModule {
    let result = ClientServerModule()
    result.moduleId = bb.readUint32()
    result.inputName = decodeStringPointer(bb)
    result.assetName = decodeStringPointer(bb)
    result.exportNames = decodeStringPointer(bb)
    return result
}

public func encodeClientServerModule(message: ClientServerModule, bb: ByteBuffer): Unit {
    bb.writeUint32(message.moduleId)
    encodeStringPointer(message.inputName, bb)
    encodeStringPointer(message.assetName, bb)
    encodeStringPointer(message.exportNames, bb)
}

// ============================================================================
// decodeClientServerModuleManifest / encodeClientServerModuleManifest
// Strict translation from: schema.js - decodeClientServerModuleManifest / encodeClientServerModuleManifest
// ============================================================================

public func decodeClientServerModuleManifest(bb: ByteBuffer): ClientServerModuleManifest {
    let result = ClientServerModuleManifest()
    result.version = bb.readUint32()
    let clientLen = bb.readVarUint()
    var i: UInt64 = 0
    while (i < clientLen) {
        result.clientModules.append(decodeClientServerModule(bb))
        i++
    }
    let serverLen = bb.readVarUint()
    i = 0
    while (i < serverLen) {
        result.serverModules.append(decodeClientServerModule(bb))
        i++
    }
    let ssrLen = bb.readVarUint()
    i = 0
    while (i < ssrLen) {
        result.ssrModules.append(decodeClientServerModule(bb))
        i++
    }
    let expLen = bb.readVarUint()
    i = 0
    while (i < expLen) {
        result.exportNames.append(decodeStringPointer(bb))
        i++
    }
    result.contents = bb.readByteArray()
    return result
}

public func encodeClientServerModuleManifest(message: ClientServerModuleManifest, bb: ByteBuffer): Unit {
    bb.writeUint32(message.version)
    bb.writeVarUint(UInt64(message.clientModules.size))
    for (m in message.clientModules) {
        encodeClientServerModule(m, bb)
    }
    bb.writeVarUint(UInt64(message.serverModules.size))
    for (m in message.serverModules) {
        encodeClientServerModule(m, bb)
    }
    bb.writeVarUint(UInt64(message.ssrModules.size))
    for (m in message.ssrModules) {
        encodeClientServerModule(m, bb)
    }
    bb.writeVarUint(UInt64(message.exportNames.size))
    for (e in message.exportNames) {
        encodeStringPointer(e, bb)
    }
    bb.writeByteArray(message.contents)
}

// ============================================================================
// decodeGetTestsRequest / encodeGetTestsRequest
// Strict translation from: schema.js - decodeGetTestsRequest / encodeGetTestsRequest
// ============================================================================

public func decodeGetTestsRequest(bb: ByteBuffer): GetTestsRequest {
    let result = GetTestsRequest()
    result.path = bb.readString()
    result.contents = bb.readByteArray()
    return result
}

public func encodeGetTestsRequest(message: GetTestsRequest, bb: ByteBuffer): Unit {
    bb.writeString(message.path)
    bb.writeByteArray(message.contents)
}

// ============================================================================
// decodeTestResponseItem / encodeTestResponseItem
// Strict translation from: schema.js - decodeTestResponseItem / encodeTestResponseItem
// ============================================================================

public func decodeTestResponseItem(bb: ByteBuffer): TestResponseItem {
    let result = TestResponseItem()
    result.byteOffset = bb.readInt32()
    result.label = decodeStringPointer(bb)
    result.kind = TestKind.fromRaw(bb.readByte())
    return result
}

public func encodeTestResponseItem(message: TestResponseItem, bb: ByteBuffer): Unit {
    bb.writeInt32(message.byteOffset)
    encodeStringPointer(message.label, bb)
    bb.writeByte(message.kind.toRaw())
}

// ============================================================================
// decodeGetTestsResponse / encodeGetTestsResponse
// Strict translation from: schema.js - decodeGetTestsResponse / encodeGetTestsResponse
// ============================================================================

public func decodeGetTestsResponse(bb: ByteBuffer): GetTestsResponse {
    let result = GetTestsResponse()
    let testsLen = bb.readVarUint()
    var i: UInt64 = 0
    while (i < testsLen) {
        result.tests.append(decodeTestResponseItem(bb))
        i++
    }
    result.contents = bb.readByteArray()
    return result
}

public func encodeGetTestsResponse(message: GetTestsResponse, bb: ByteBuffer): Unit {
    bb.writeVarUint(UInt64(message.tests.size))
    for (t in message.tests) {
        encodeTestResponseItem(t, bb)
    }
    bb.writeByteArray(message.contents)
}
