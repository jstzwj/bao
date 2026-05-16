package bao_boringssl

import bao_core.*
import bao_boringssl_sys.*
import bao_cares_sys.*

public enum BoringSSLSource {
    | cargoToml
    | rustWrapper
    | zigWrapper
}

public struct BoringSSLModuleFile {
    public let source: BoringSSLSource
    public let bunPath: String

    public init(source: BoringSSLSource, bunPath: String) {
        this.source = source
        this.bunPath = bunPath
    }
}

public func moduleFiles(): Array<BoringSSLModuleFile> {
    [
        BoringSSLModuleFile(BoringSSLSource.cargoToml, "src/boringssl/Cargo.toml"),
        BoringSSLModuleFile(BoringSSLSource.rustWrapper, "src/boringssl/lib.rs"),
        BoringSSLModuleFile(BoringSSLSource.zigWrapper, "src/boringssl/boringssl.zig")
    ]
}

public func isSafeAltName(name: Array<UInt8>, utf8: Bool): Bool {
    for (byte in name) {
        if (byte == UInt8(34) || byte == UInt8(92) || byte == UInt8(44) || byte == UInt8(39)) {
            return false
        }
        if (utf8) {
            if (byte < UInt8(32) || byte == UInt8(127)) {
                return false
            }
        } else if (byte < UInt8(32) || byte > UInt8(126)) {
            return false
        }
    }
    true
}

public func canonicalizeIP(addrStr: Array<UInt8>, outIP: CPointer<UInt8>): ?Array<UInt8> {
    bao_core.canonicalizeIP(addrStr, outIP)
}

public func checkX509ServerIdentity(x509: CPointer<Unit>, hostname: Array<UInt8>): Bool {
    bao_core.checkX509ServerIdentity(x509, hostname)
}

public func checkServerIdentity(sslPtr: CPointer<Unit>, hostname: Array<UInt8>): Bool {
    bao_core.checkServerIdentity(sslPtr, hostname)
}
