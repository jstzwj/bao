// 严格翻译自: src/runtime/socket/tls_socket_functions.zig
// TLS Socket 函数 — TLS 连接的各种属性和方法
package bao_runtime.socket

import bao_core.*
import bao_collections.*

// ============================================================================
// TLS Socket 函数
// 对应 Bun: tls_socket_functions.zig
// 提供所有 TLS/TLS Socket 的 JS 可调用方法
// ============================================================================

/// TLS Socket 函数集合
/// 对应 Zig 中的 pub fn getXxx / setXxx 函数集合
public class TlsSocketFunctions {
    private var socket: TLSSocket

    public init(socket: TLSSocket) {
        this.socket = socket
    }

    /// 获取服务器名称 (SNI)
    /// 对应 Zig: pub fn getServername
    public func getServername(globalObject: JsGlobalObject, callFrame: JsCallFrame): JsValue {
        let sslPtr = socket.ssl()
        if (sslPtr == None) {
            return JsValue.jsUndefined()
        }

        let servername = BoringSSL.sslGetServername(sslPtr, BoringSSL.TLSEXT_NAMETYPE_HOST_NAME)
        if (servername == None) {
            return JsValue.jsUndefined()
        }
        return ZigString.fromUTF8(servername).toJS(globalObject)
    }

    /// 设置服务器名称 (SNI)
    /// 对应 Zig: pub fn setServername
    public func setServername(globalObject: JsGlobalObject, callFrame: JsCallFrame): JsValue {
        if (socket.isServer()) {
            return globalObject.throw("Cannot issue SNI from a TLS server-side socket")
        }

        let args = callFrame.argumentsOld(1)
        if (args.size < 1) {
            return globalObject.throw("Expected 1 argument")
        }

        let serverName = args[0]
        if (!serverName.isString()) {
            return globalObject.throw("Expected \"serverName\" to be a string")
        }

        let slice = serverName.getZigString(globalObject).toOwnedSlice()
        let old = socket.serverName
        socket.serverName = slice
        if (old != None) {
            defaultAllocator.free(old)
        }

        let host = slice
        if (host.size > 0) {
            let sslPtr = socket.ssl()
            if (sslPtr == None) {
                return JsValue.jsUndefined()
            }

            if (sslPtr.isInitFinished()) {
                // 匹配 node.js 异常
                return globalObject.throw("Already started.")
            }
            let hostZ = defaultAllocator.dupeZ(host)
            sslPtr.setHostname(hostZ)
            defaultAllocator.free(hostZ)
        }

        return JsValue.jsUndefined()
    }

    /// 获取对端 X509 证书
    /// 对应 Zig: pub fn getPeerX509Certificate
    public func getPeerX509Certificate(globalObject: JsGlobalObject, callFrame: JsCallFrame): JsValue {
        let sslPtr = socket.ssl()
        if (sslPtr == None) {
            return JsValue.jsUndefined()
        }
        let cert = BoringSSL.sslGetPeerCertificate(sslPtr)
        if (cert != None) {
            return X509Wrapper.toJSObject(cert, globalObject)
        }
        return JsValue.jsUndefined()
    }

    /// 获取本地 X509 证书
    /// 对应 Zig: pub fn getX509Certificate
    public func getX509Certificate(globalObject: JsGlobalObject, callFrame: JsCallFrame): JsValue {
        let sslPtr = socket.ssl()
        if (sslPtr == None) {
            return JsValue.jsUndefined()
        }
        let cert = BoringSSL.sslGetCertificate(sslPtr)
        if (cert != None) {
            return X509Wrapper.toJSObject(cert.ref(), globalObject)
        }
        return JsValue.jsUndefined()
    }

    /// 获取 TLS 版本
    /// 对应 Zig: pub fn getTLSVersion
    public func getTLSVersion(globalObject: JsGlobalObject, callFrame: JsCallFrame): JsValue {
        let sslPtr = socket.ssl()
        if (sslPtr == None) {
            return JsValue.jsNull()
        }
        let version = BoringSSL.sslGetVersion(sslPtr)
        if (version == None) {
            return JsValue.jsNull()
        }
        let versionLen = version.len()
        if (versionLen == 0) {
            return JsValue.jsNull()
        }
        return ZigString.fromUTF8(version).toJS(globalObject)
    }

    /// 设置最大发送分片大小
    /// 对应 Zig: pub fn setMaxSendFragment
    public func setMaxSendFragment(globalObject: JsGlobalObject, callFrame: JsCallFrame): JsValue {
        let args = callFrame.argumentsOld(1)

        if (args.size < 1) {
            return globalObject.throw("Expected size to be a number")
        }

        let arg = args[0]
        if (!arg.isNumber()) {
            return globalObject.throw("Expected size to be a number")
        }
        let size = arg.coerceToInt64(globalObject)
        if (size < 1) {
            return globalObject.throw("Expected size to be greater than 1")
        }
        if (size > 16384) {
            return globalObject.throw("Expected size to be less than 16385")
        }

        let sslPtr = socket.ssl()
        if (sslPtr == None) {
            return JsValue.jsFalse()
        }
        let result = BoringSSL.sslSetMaxSendFragment(sslPtr, size)
        return JsValue.jsBoolean(result == 1)
    }

    /// 获取对端证书
    /// 对应 Zig: pub fn getPeerCertificate
    public func getPeerCertificate(globalObject: JsGlobalObject, callFrame: JsCallFrame): JsValue {
        let args = callFrame.argumentsOld(1)
        var abbreviated: Bool = true
        if (args.size > 0) {
            let arg = args[0]
            if (!arg.isBoolean()) {
                return globalObject.throw("Expected abbreviated to be a boolean")
            }
            abbreviated = arg.toBoolean()
        }

        let sslPtr = socket.ssl()
        if (sslPtr == None) {
            return JsValue.jsUndefined()
        }

        if (abbreviated) {
            if (socket.isServer()) {
                // SSL_get_peer_certificate 返回 +1 引用，需要释放
                let cert = BoringSSL.sslGetPeerCertificate(sslPtr)
                if (cert != None) {
                    return X509Wrapper.toJS(cert, globalObject)
                }
            }

            let certChain = BoringSSL.sslGetPeerCertChain(sslPtr)
            if (certChain == None) {
                return JsValue.jsUndefined()
            }
            let cert = BoringSSL.skX509Value(certChain, 0)
            if (cert == None) {
                return JsValue.jsUndefined()
            }
            return X509Wrapper.toJS(cert, globalObject)
        }

        var cert: ?X509 = None
        if (socket.isServer()) {
            cert = BoringSSL.sslGetPeerCertificate(sslPtr)
        }

        let certChain = BoringSSL.sslGetPeerCertChain(sslPtr)
        let firstCert = if (cert != None) { cert } else if (certChain != None) { BoringSSL.skX509Value(certChain, 0) } else { None }

        if (firstCert == None) {
            return JsValue.jsUndefined()
        }

        // TODO: 需要支持非缩写版本
        return JsValue.jsUndefined()
    }

    /// 获取本地证书
    /// 对应 Zig: pub fn getCertificate
    public func getCertificate(globalObject: JsGlobalObject, callFrame: JsCallFrame): JsValue {
        let sslPtr = socket.ssl()
        if (sslPtr == None) {
            return JsValue.jsUndefined()
        }
        let cert = BoringSSL.sslGetCertificate(sslPtr)
        if (cert != None) {
            return X509Wrapper.toJS(cert, globalObject)
        }
        return JsValue.jsUndefined()
    }

    /// 获取 TLS Finished 消息
    /// 对应 Zig: pub fn getTLSFinishedMessage
    public func getTLSFinishedMessage(globalObject: JsGlobalObject, callFrame: JsCallFrame): JsValue {
        let sslPtr = socket.ssl()
        if (sslPtr == None) {
            return JsValue.jsUndefined()
        }
        // 不能传递 nullptr 给 SSL_get_finished() 因为会传播到 memcpy()
        // 违反 ISO/IEC 9899:2011 7.21.2.1, 7.21.1.2, 和 7.1.4 的标准要求
        // 因此使用一个虚拟字节
        var dummy = Array<Byte>(1)
        let size = BoringSSL.sslGetFinished(sslPtr, dummy, 1)
        if (size == 0) {
            return JsValue.jsUndefined()
        }

        let bufferSize = size
        var buffer = JsValue.createBufferFromLength(globalObject, bufferSize)
        let bufferPtr = buffer.asArrayBuffer(globalObject).ptr

        let resultSize = BoringSSL.sslGetFinished(sslPtr, bufferPtr, bufferSize)
        return buffer
    }

    /// 获取共享的签名算法
    /// 对应 Zig: pub fn getSharedSigalgs
    public func getSharedSigalgs(globalObject: JsGlobalObject, callFrame: JsCallFrame): JsValue {
        let sslPtr = socket.ssl()
        if (sslPtr == None) {
            return JsValue.jsNull()
        }

        let nsig = BoringSSL.sslGetSharedSigalgs(sslPtr, 0, None, None, None, None, None)
        let array = JsValue.createEmptyArray(globalObject, nsig)

        for (i in 0..nsig) {
            var hashNid: Int32 = 0
            var signNid: Int32 = 0
            var sigWithMd: String = ""

            BoringSSL.sslGetSharedSigalgs(sslPtr, i, signNid, hashNid, None, None, None)
            match (signNid) {
                case BoringSSL.EVP_PKEY_RSA =>
                    sigWithMd = "RSA"
                case BoringSSL.EVP_PKEY_RSA_PSS =>
                    sigWithMd = "RSA-PSS"
                case BoringSSL.EVP_PKEY_DSA =>
                    sigWithMd = "DSA"
                case BoringSSL.EVP_PKEY_EC =>
                    sigWithMd = "ECDSA"
                case BoringSSL.NID_ED25519 =>
                    sigWithMd = "Ed25519"
                case BoringSSL.NID_ED448 =>
                    sigWithMd = "Ed448"
                case BoringSSL.NID_id_GostR3410_2001 =>
                    sigWithMd = "gost2001"
                case BoringSSL.NID_id_GostR3410_2012_256 =>
                    sigWithMd = "gost2012_256"
                case BoringSSL.NID_id_GostR3410_2012_512 =>
                    sigWithMd = "gost2012_512"
                case _ => {
                    let snStr = BoringSSL.objNid2sn(signNid)
                    if (snStr != None) {
                        sigWithMd = snStr
                    } else {
                        sigWithMd = "UNDEF"
                    }
                }
            }

            let hashStr = BoringSSL.objNid2sn(hashNid)
            if (hashStr != None) {
                let hashStrLen = hashStr.len()
                var buffer = sigWithMd + "+" + hashStr
                array.putIndex(globalObject, i, ZigString.fromUTF8(buffer).toJS(globalObject))
            } else {
                var buffer = sigWithMd + "+UNDEF"
                array.putIndex(globalObject, i, ZigString.fromUTF8(buffer).toJS(globalObject))
            }
        }
        return array
    }

    /// 获取密码套件信息
    /// 对应 Zig: pub fn getCipher
    public func getCipher(globalObject: JsGlobalObject, callFrame: JsCallFrame): JsValue {
        let sslPtr = socket.ssl()
        if (sslPtr == None) {
            return JsValue.jsUndefined()
        }
        let cipher = BoringSSL.sslGetCurrentCipher(sslPtr)
        var result = JsValue.createEmptyObject(globalObject, 0)

        if (cipher == None) {
            result.put(globalObject, ZigString.static("name"), JsValue.jsNull())
            result.put(globalObject, ZigString.static("standardName"), JsValue.jsNull())
            result.put(globalObject, ZigString.static("version"), JsValue.jsNull())
            return result
        }

        let name = BoringSSL.sslCipherGetName(cipher)
        if (name == None) {
            result.put(globalObject, ZigString.static("name"), JsValue.jsNull())
        } else {
            result.put(globalObject, ZigString.static("name"), ZigString.fromUTF8(name).toJS(globalObject))
        }

        let standardName = BoringSSL.sslCipherStandardName(cipher)
        if (standardName == None) {
            result.put(globalObject, ZigString.static("standardName"), JsValue.jsNull())
        } else {
            result.put(globalObject, ZigString.static("standardName"), ZigString.fromUTF8(standardName).toJS(globalObject))
        }

        let version = BoringSSL.sslCipherGetVersion(cipher)
        if (version == None) {
            result.put(globalObject, ZigString.static("version"), JsValue.jsNull())
        } else {
            result.put(globalObject, ZigString.static("version"), ZigString.fromUTF8(version).toJS(globalObject))
        }

        return result
    }

    /// 获取 TLS 对端 Finished 消息
    /// 对应 Zig: pub fn getTLSPeerFinishedMessage
    public func getTLSPeerFinishedMessage(globalObject: JsGlobalObject, callFrame: JsCallFrame): JsValue {
        let sslPtr = socket.ssl()
        if (sslPtr == None) {
            return JsValue.jsUndefined()
        }
        var dummy = Array<Byte>(1)
        let size = BoringSSL.sslGetPeerFinished(sslPtr, dummy, 1)
        if (size == 0) {
            return JsValue.jsUndefined()
        }

        let bufferSize = size
        var buffer = JsValue.createBufferFromLength(globalObject, bufferSize)
        let bufferPtr = buffer.asArrayBuffer(globalObject).ptr

        let resultSize = BoringSSL.sslGetPeerFinished(sslPtr, bufferPtr, bufferSize)
        return buffer
    }

    /// 导出密钥材料
    /// 对应 Zig: pub fn exportKeyingMaterial
    public func exportKeyingMaterial(globalObject: JsGlobalObject, callFrame: JsCallFrame): JsValue {
        if (socket.isDetached()) {
            return JsValue.jsUndefined()
        }

        let args = callFrame.argumentsOld(3)
        if (args.size < 2) {
            return globalObject.throw("Expected length and label to be provided")
        }
        let lengthArg = args[0]
        if (!lengthArg.isNumber()) {
            return globalObject.throw("Expected length to be a number")
        }

        let length = lengthArg.coerceToInt64(globalObject)
        if (length < 0) {
            return globalObject.throw("Expected length to be a positive number")
        }

        let labelArg = args[1]
        if (!labelArg.isString()) {
            return globalObject.throw("Expected label to be a string")
        }

        let label = labelArg.toSliceOrNull(globalObject)
        let labelSlice = label.slice()
        let sslPtr = socket.ssl()
        if (sslPtr == None) {
            return JsValue.jsUndefined()
        }

        if (args.size > 2) {
            let contextArg = args[2]
            let sb = NodeStringOrBuffer.fromJS(globalObject, contextArg)
            if (sb != None) {
                let contextSlice = sb.slice()
                let bufferSize = length
                var buffer = JsValue.createBufferFromLength(globalObject, bufferSize)
                let bufferPtr = buffer.asArrayBuffer(globalObject).ptr

                let result = BoringSSL.sslExportKeyingMaterial(
                    sslPtr, bufferPtr, bufferSize,
                    labelSlice.ptr, labelSlice.size,
                    contextSlice.ptr, contextSlice.size, 1
                )
                if (result != 1) {
                    return globalObject.throwValue(getSSLException(globalObject, "Failed to export keying material"))
                }
                return buffer
            } else {
                return globalObject.throw("Expected context to be a string, Buffer or TypedArray")
            }
        } else {
            let bufferSize = length
            var buffer = JsValue.createBufferFromLength(globalObject, bufferSize)
            let bufferPtr = buffer.asArrayBuffer(globalObject).ptr

            let result = BoringSSL.sslExportKeyingMaterial(
                sslPtr, bufferPtr, bufferSize,
                labelSlice.ptr, labelSlice.size,
                None, 0, 0
            )
            if (result != 1) {
                return globalObject.throwValue(getSSLException(globalObject, "Failed to export keying material"))
            }
            return buffer
        }
    }

    /// 获取临时密钥信息
    /// 对应 Zig: pub fn getEphemeralKeyInfo
    public func getEphemeralKeyInfo(globalObject: JsGlobalObject, callFrame: JsCallFrame): JsValue {
        // 仅对客户端可用
        if (socket.isServer()) {
            return JsValue.jsNull()
        }

        let sslPtr = socket.ssl()
        if (sslPtr == None) {
            return JsValue.jsNull()
        }
        var result = JsValue.createEmptyObject(globalObject, 0)

        let rawKey = BoringSSL.sslGetPrivatekey(sslPtr)
        if (rawKey == None) {
            return result
        }

        let kid = BoringSSL.evpPkeyId(rawKey)
        let bits = BoringSSL.evpPkeyBits(rawKey)

        match (kid) {
            case BoringSSL.EVP_PKEY_DH => {
                result.put(globalObject, ZigString.static("type"), BunString.static("DH").toJS(globalObject))
                result.put(globalObject, ZigString.static("size"), JsValue.jsNumber(bits))
            }
            case BoringSSL.EVP_PKEY_EC | BoringSSL.EVP_PKEY_X25519 | BoringSSL.EVP_PKEY_X448 => {
                var curveName = ""
                if (kid == BoringSSL.EVP_PKEY_EC) {
                    let ec = BoringSSL.evpPkeyGet1ECKey(rawKey)
                    let nid = BoringSSL.ecGroupGetCurveName(BoringSSL.ecKeyGet0Group(ec))
                    let nidStr = BoringSSL.objNid2sn(nid)
                    if (nidStr != None) {
                        curveName = nidStr
                    } else {
                        curveName = ""
                    }
                } else {
                    let kidStr = BoringSSL.objNid2sn(kid)
                    if (kidStr != None) {
                        curveName = kidStr
                    } else {
                        curveName = ""
                    }
                }
                result.put(globalObject, ZigString.static("type"), BunString.static("ECDH").toJS(globalObject))
                result.put(globalObject, ZigString.static("name"), ZigString.fromUTF8(curveName).toJS(globalObject))
                result.put(globalObject, ZigString.static("size"), JsValue.jsNumber(bits))
            }
            case _ => ()
        }
        return result
    }

    /// 获取 ALPN 协议
    /// 对应 Zig: pub fn getALPNProtocol
    public func getALPNProtocol(globalObject: JsGlobalObject): JsValue {
        var alpnProto: ?String = None
        var alpnProtoLen: UInt32 = 0

        let sslPtr = socket.ssl()
        if (sslPtr == None) {
            return JsValue.jsFalse()
        }

        BoringSSL.sslGet0AlpnSelected(sslPtr, alpnProto, alpnProtoLen)
        if (alpnProto == None || alpnProtoLen == 0) {
            return JsValue.jsFalse()
        }

        if (alpnProto == "h2") {
            return BunString.static("h2").toJS(globalObject)
        }
        if (alpnProto == "http/1.1") {
            return BunString.static("http/1.1").toJS(globalObject)
        }
        return ZigString.fromUTF8(alpnProto).toJS(globalObject)
    }

    /// 获取会话
    /// 对应 Zig: pub fn getSession
    public func getSession(globalObject: JsGlobalObject, callFrame: JsCallFrame): JsValue {
        let sslPtr = socket.ssl()
        if (sslPtr == None) {
            return JsValue.jsUndefined()
        }
        let session = BoringSSL.sslGetSession(sslPtr)
        if (session == None) {
            return JsValue.jsUndefined()
        }
        let size = BoringSSL.i2dSslSession(session, None)
        if (size <= 0) {
            return JsValue.jsUndefined()
        }

        let bufferSize = size
        var buffer = JsValue.createBufferFromLength(globalObject, bufferSize)
        var bufferPtr = buffer.asArrayBuffer(globalObject).ptr

        let resultSize = BoringSSL.i2dSslSession(session, bufferPtr)
        return buffer
    }

    /// 设置会话
    /// 对应 Zig: pub fn setSession
    public func setSession(globalObject: JsGlobalObject, callFrame: JsCallFrame): JsValue {
        if (socket.isDetached()) {
            return JsValue.jsUndefined()
        }

        let args = callFrame.argumentsOld(1)
        if (args.size < 1) {
            return globalObject.throw("Expected session to be a string, Buffer or TypedArray")
        }

        let sessionArg = args[0]
        let sb = NodeStringOrBuffer.fromJS(globalObject, sessionArg)
        if (sb != None) {
            let sessionSlice = sb.slice()
            let sslPtr = socket.ssl()
            var tmp = sessionSlice.ptr
            let session = BoringSSL.d2iSslSession(None, tmp, sessionSlice.size)
            if (session == None) {
                return JsValue.jsUndefined()
            }
            // SSL_set_session 获取自己的引用
            defer BoringSSL.sslSessionFree(session)
            if (BoringSSL.sslSetSession(sslPtr, session) != 1) {
                return globalObject.throwValue(getSSLException(globalObject, "SSL_set_session error"))
            }
            return JsValue.jsUndefined()
        } else {
            return globalObject.throw("Expected session to be a string, Buffer or TypedArray")
        }
    }

    /// 获取 TLS 票据
    /// 对应 Zig: pub fn getTLSTicket
    public func getTLSTicket(globalObject: JsGlobalObject, callFrame: JsCallFrame): JsValue {
        let sslPtr = socket.ssl()
        if (sslPtr == None) {
            return JsValue.jsUndefined()
        }
        let session = BoringSSL.sslGetSession(sslPtr)
        if (session == None) {
            return JsValue.jsUndefined()
        }
        var ticket: ?String = None
        var length: Int64 = 0
        BoringSSL.sslSessionGet0Ticket(session, ticket, length)

        if (ticket == None || length == 0) {
            return JsValue.jsUndefined()
        }

        return JsArrayBuffer.createBuffer(globalObject, ticket[0..length])
    }

    /// 重协商
    /// 对应 Zig: pub fn renegotiate
    public func renegotiate(globalObject: JsGlobalObject, callFrame: JsCallFrame): JsValue {
        let sslPtr = socket.ssl()
        if (sslPtr == None) {
            return JsValue.jsUndefined()
        }
        BoringSSL.errClearError()
        if (BoringSSL.sslRenegotiate(sslPtr) != 1) {
            return globalObject.throwValue(getSSLException(globalObject, "SSL_renegotiate error"))
        }
        return JsValue.jsUndefined()
    }

    /// 禁用重协商
    /// 对应 Zig: pub fn disableRenegotiation
    public func disableRenegotiation(globalObject: JsGlobalObject, callFrame: JsCallFrame): JsValue {
        let sslPtr = socket.ssl()
        if (sslPtr == None) {
            return JsValue.jsUndefined()
        }
        BoringSSL.sslSetRenegotiateMode(sslPtr, SSLRenegotiateMode.NEVER)
        return JsValue.jsUndefined()
    }

    /// 是否会话重用
    /// 对应 Zig: pub fn isSessionReused
    public func isSessionReused(globalObject: JsGlobalObject, callFrame: JsCallFrame): JsValue {
        let sslPtr = socket.ssl()
        if (sslPtr == None) {
            return JsValue.jsFalse()
        }
        return JsValue.jsBoolean(BoringSSL.sslSessionReused(sslPtr) == 1)
    }

    /// 设置验证模式
    /// 对应 Zig: pub fn setVerifyMode
    public func setVerifyMode(globalObject: JsGlobalObject, callFrame: JsCallFrame): JsValue {
        if (socket.isDetached()) {
            return JsValue.jsUndefined()
        }

        let args = callFrame.argumentsOld(2)
        if (args.size < 2) {
            return globalObject.throw("Expected requestCert and rejectUnauthorized arguments")
        }
        let requestCertJs = args[0]
        let rejectUnauthorizedJs = args[1]
        if (!requestCertJs.isBoolean() || !rejectUnauthorizedJs.isBoolean()) {
            return globalObject.throw("Expected requestCert and rejectUnauthorized arguments to be boolean")
        }

        let requestCert = requestCertJs.toBoolean()
        let rejectUnauthorized = rejectUnauthorizedJs.toBoolean()
        var verifyMode: Int32 = BoringSSL.SSL_VERIFY_NONE
        if (socket.isServer()) {
            if (requestCert) {
                verifyMode = BoringSSL.SSL_VERIFY_PEER
                if (rejectUnauthorized) {
                    verifyMode = verifyMode | BoringSSL.SSL_VERIFY_FAIL_IF_NO_PEER_CERT
                }
            }
        }
        let sslPtr = socket.ssl()
        // 我们总是允许并在握手或重协商后检查 SSL 证书
        BoringSSL.sslSetVerify(sslPtr, verifyMode, alwaysAllowSSLVerifyCallback)
        return JsValue.jsUndefined()
    }

    /// SSL 验证回调 — 总是允许
    static func alwaysAllowSSLVerifyCallback(ok: Int32, x509StoreCtx: ?X509StoreCtx): Int32 {
        return 1
    }
}

/// 获取 SSL 异常
/// 对应 Zig: noinline fn getSSLException
func getSSLException(globalObject: JsGlobalObject, defaultMessage: String): JsValue {
    var zigStr = ZigString.init("")
    var outputBuf = Array<Byte>(4096)

    var written: Int64 = 0
    var sslError = BoringSSL.errGetError()
    while (sslError != 0 && written < outputBuf.size) {
        if (written > 0) {
            outputBuf[written.toInt()] = '\n'.toByte()
            written += 1
        }

        let reasonPtr = BoringSSL.errReasonErrorString(sslError)
        if (reasonPtr != None) {
            let reason = reasonPtr
            if (reason.size == 0) {
                break
            }
            reason.copyTo(outputBuf, written.toInt())
            written += reason.size
        }

        let funcPtr = BoringSSL.errFuncErrorString(sslError)
        if (funcPtr != None) {
            let reason = funcPtr
            if (reason.size > 0) {
                " via ".copyTo(outputBuf, written.toInt())
                written += " via ".size
                reason.copyTo(outputBuf, written.toInt())
                written += reason.size
            }
        }

        let libPtr = BoringSSL.errLibErrorString(sslError)
        if (libPtr != None) {
            let reason = libPtr
            if (reason.size > 0) {
                outputBuf[written.toInt()] = ' '.toByte()
                written += 1
                reason.copyTo(outputBuf, written.toInt())
                written += reason.size
            }
        }

        sslError = BoringSSL.errGetError()
    }

    if (written > 0) {
        let message = outputBuf[0:written.toInt()]
        zigStr = ZigString.init("OpenSSL " + message)

        // 清除错误
        BoringSSL.errClearError()
    }

    if (zigStr.len() == 0) {
        zigStr = ZigString.init(defaultMessage)
    }

    // 将异常存储在这里
    let exception = zigStr.toErrorInstance(globalObject)
    return exception
}

// FFI 类型别名
let defaultAllocator = DefaultAllocator.instance
