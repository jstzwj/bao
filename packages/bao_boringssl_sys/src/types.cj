// 严格翻译自: src/boringssl_sys/boringssl.zig
package bao_boringssl_sys

// ============================================================================
// BoringSSL 基础类型和结构体定义
// 严格翻译自: boringssl.zig 中的类型定义 (前 500 行)
// ============================================================================

// ============================================================================
// ASN1 类型 (opaque 和 extern struct)
// 严格翻译自: boringssl.zig ASN1_* 类型
// ============================================================================

/// ASN1_BOOLEAN
public type ASN1_BOOLEAN = Int32

/// ASN1_STRING / ASN1_OCTET_STRING / ASN1_INTEGER 等
/// 严格翻译自: struct_asn1_string_st
@C
public struct Asn1StringSt {
    public var length: Int32 = 0
    public var type_: Int32 = 0
    public var data: CPointer<UInt8> = CPointer<UInt8>()
    public var flags: Int64 = 0
}

// ASN1 string 子类型别名
public type ASN1_BIT_STRING = Asn1StringSt
public type ASN1_BMPSTRING = Asn1StringSt
public type ASN1_ENUMERATED = Asn1StringSt
public type ASN1_GENERALIZEDTIME = Asn1StringSt
public type ASN1_GENERALSTRING = Asn1StringSt
public type ASN1_IA5STRING = Asn1StringSt
public type ASN1_INTEGER = Asn1StringSt
public type ASN1_OCTET_STRING = Asn1StringSt
public type ASN1_PRINTABLESTRING = Asn1StringSt
public type ASN1_STRING = Asn1StringSt
public type ASN1_T61STRING = Asn1StringSt
public type ASN1_TIME = Asn1StringSt
public type ASN1_UNIVERSALSTRING = Asn1StringSt
public type ASN1_UTCTIME = Asn1StringSt
public type ASN1_UTF8STRING = Asn1StringSt
public type ASN1_VISIBLESTRING = Asn1StringSt

/// ASN1_TYPE
/// 严格翻译自: struct_asn1_type_st
@C
public struct Asn1TypeSt {
    public var type_: Int32 = 0
    public var value: Int64 = 0  // union, 用最大成员的尺寸
}

public type ASN1_TYPE = Asn1TypeSt

/// X509_ALGOR
/// 严格翻译自: struct_X509_algor_st
@C
public struct X509Algor {
    public var algorithm: CPointer<Unit> = CPointer<Unit>()  // *ASN1_OBJECT
    public var parameter: CPointer<Asn1TypeSt> = CPointer<Asn1TypeSt>()
}

public type X509_ALGOR = X509Algor

/// NETSCAPE_SPKAC
/// 严格翻译自: struct_Netscape_spkac_st
@C
public struct NetscapeSpkac {
    public var pubkey: CPointer<Unit> = CPointer<Unit>()  // *X509_PUBKEY
    public var challenge: CPointer<Asn1StringSt> = CPointer<Asn1StringSt>()
}

public type NETSCAPE_SPKAC = NetscapeSpkac

/// NETSCAPE_SPKI
/// 严格翻译自: struct_Netscape_spki_st
@C
public struct NetscapeSpki {
    public var spkac: CPointer<NETSCAPE_SPKAC> = CPointer<NETSCAPE_SPKAC>()
    public var sig_algor: CPointer<X509Algor> = CPointer<X509Algor>()
    public var signature: CPointer<Asn1StringSt> = CPointer<Asn1StringSt>()
}

public type NETSCAPE_SPKI = NetscapeSpki

/// BIGNUM
/// 严格翻译自: struct_bignum_st
@C
public struct BigNumSt {
    public var d: CPointer<UInt64> = CPointer<UInt64>()
    public var width: Int32 = 0
    public var dmax: Int32 = 0
    public var neg: Int32 = 0
    public var flags: Int32 = 0
}

public type BIGNUM = BigNumSt
public type BN_ULONG = UInt64

/// DSA_SIG
/// 严格翻译自: struct_DSA_SIG_st
@C
public struct DsaSigSt {
    public var r: CPointer<BigNumSt> = CPointer<BigNumSt>()
    public var s: CPointer<BigNumSt> = CPointer<BigNumSt>()
}

public type DSA_SIG = DsaSigSt

/// CRYPTO_refcount_t
public type CRYPTO_refcount_t = UInt32

/// CRYPTO_EX_DATA
/// 严格翻译自: struct_crypto_ex_data_st
@C
public struct CryptoExData {
    public var sk: CPointer<Unit> = CPointer<Unit>()
}

public type CRYPTO_EX_DATA = CryptoExData

/// BN_MONT_CTX
/// 严格翻译自: struct_bn_mont_ctx_st
@C
public struct BnMontCtxSt {
    public var RR: BigNumSt = BigNumSt()
    public var N: BigNumSt = BigNumSt()
    public var n0: VArray<UInt64, $2> = VArray<UInt64, $2>(repeat: 0)
}

public type BN_MONT_CTX = BnMontCtxSt

/// DSA
/// 严格翻译自: struct_dsa_st
@C
public struct DSA {
    public var version: Int64 = 0
    public var p: CPointer<BigNumSt> = CPointer<BigNumSt>()
    public var q: CPointer<BigNumSt> = CPointer<BigNumSt>()
    public var g: CPointer<BigNumSt> = CPointer<BigNumSt>()
    public var pub_key: CPointer<BigNumSt> = CPointer<BigNumSt>()
    public var priv_key: CPointer<BigNumSt> = CPointer<BigNumSt>()
    public var flags: Int32 = 0
    public var method_mont_lock: UInt64 = 0  // CRYPTO_MUTEX (pthread_rwlock_t)
    public var method_mont_p: CPointer<BnMontCtxSt> = CPointer<BnMontCtxSt>()
    public var method_mont_q: CPointer<BnMontCtxSt> = CPointer<BnMontCtxSt>()
    public var references: CRYPTO_refcount_t = 0
    public var ex_data: CryptoExData = CryptoExData()
}

/// EVP_PKEY
/// 严格翻译自: struct_evp_pkey_st
@C
public struct EvpPkeySt {
    public var references: CRYPTO_refcount_t = 0
    public var type_: Int32 = 0
    public var pkey: CPointer<Unit> = CPointer<Unit>()  // union
    public var ameth: CPointer<Unit> = CPointer<Unit>()  // *const EVP_PKEY_ASN1_METHOD
}

public type EVP_PKEY = EvpPkeySt

/// EVP_CIPHER_INFO
/// 严格翻译自: struct_evp_cipher_info_st
@C
public struct EvpCipherInfo {
    public var cipher: CPointer<Unit> = CPointer<Unit>()  // *const EVP_CIPHER
    public var iv: VArray<UInt8, $16> = VArray<UInt8, $16>(repeat: 0)
}

public type EVP_CIPHER_INFO = EvpCipherInfo

/// X509_PKEY
/// 严格翻译自: struct_private_key_st
@C
public struct X509Pkey {
    public var version: Int32 = 0
    public var enc_algor: CPointer<X509Algor> = CPointer<X509Algor>()
    public var enc_pkey: CPointer<Asn1StringSt> = CPointer<Asn1StringSt>()
    public var dec_pkey: CPointer<EvpPkeySt> = CPointer<EvpPkeySt>()
    public var key_length: Int32 = 0
    public var key_data: CPointer<UInt8> = CPointer<UInt8>()
    public var key_free: Int32 = 0
    public var cipher: EvpCipherInfo = EvpCipherInfo()
}

public type X509_PKEY = X509Pkey

/// X509_INFO
/// 严格翻译自: struct_X509_info_st
@C
public struct X509Info {
    public var x509: CPointer<Unit> = CPointer<Unit>()  // *X509
    public var crl: CPointer<Unit> = CPointer<Unit>()  // *X509_CRL
    public var x_pkey: CPointer<X509Pkey> = CPointer<X509Pkey>()
    public var enc_cipher: EvpCipherInfo = EvpCipherInfo()
    public var enc_len: Int32 = 0
    public var enc_data: CPointer<UInt8> = CPointer<UInt8>()
}

public type X509_INFO = X509Info

/// BUF_MEM
/// 严格翻译自: struct_buf_mem_st
@C
public struct BufMem {
    public var length: UIntNative = 0
    public var data: CPointer<UInt8> = CPointer<UInt8>()
    public var max: UIntNative = 0
}

public type BUF_MEM = BufMem

/// BN_GENCB
/// 严格翻译自: struct_bn_gencb_st
@C
public struct BnGencb {
    public var arg: CPointer<Unit> = CPointer<Unit>()
    public var callback: CPointer<Unit> = CPointer<Unit>()  // function pointer
}

public type BN_GENCB = BnGencb

/// bio_info_cb 函数类型
public type BioInfoCb = CFunc<(CPointer<Unit>, Int32, CPointer<UInt8>, Int32, Int64, Int64) -> Int64>

/// BIO_METHOD
/// 严格翻译自: struct_bio_method_st
@C
public struct BioMethodSt {
    public var type_: Int32 = 0
    public var name: CString = CString(CPointer<UInt8>())
    public var bwrite: CPointer<Unit> = CPointer<Unit>()
    public var bread: CPointer<Unit> = CPointer<Unit>()
    public var bputs: CPointer<Unit> = CPointer<Unit>()
    public var bgets: CPointer<Unit> = CPointer<Unit>()
    public var ctrl: CPointer<Unit> = CPointer<Unit>()
    public var create: CPointer<Unit> = CPointer<Unit>()
    public var destroy: CPointer<Unit> = CPointer<Unit>()
    public var callback_ctrl: CPointer<Unit> = CPointer<Unit>()
}

public type BIO_METHOD = BioMethodSt

/// CBS (Const Byte String)
/// 严格翻译自: struct_cbs_st
@C
public struct CbsSt {
    public var data: CPointer<UInt8> = CPointer<UInt8>()
    public var len: UIntNative = 0
}

public type CBS = CbsSt

/// HMAC_CTX
/// 严格翻译自: struct_hmac_ctx_st
@C
public struct HmacCtxSt {
    public var md: CPointer<Unit> = CPointer<Unit>()  // *const EVP_MD
    public var md_ctx: VArray<UInt8, $312> = VArray<UInt8, $312>(repeat: 0)  // EVP_MD_CTX (large)
    public var i_ctx: VArray<UInt8, $312> = VArray<UInt8, $312>(repeat: 0)
    public var o_ctx: VArray<UInt8, $312> = VArray<UInt8, $312>(repeat: 0)
}

public type HMAC_CTX = HmacCtxSt

/// SHA_CTX
/// 严格翻译自: struct_sha_state_st
@C
public struct ShaCtx {
    public var h0: UInt32 = 0
    public var h1: UInt32 = 0
    public var h2: UInt32 = 0
    public var h3: UInt32 = 0
    public var h4: UInt32 = 0
    public var Nl: UInt32 = 0
    public var Nh: UInt32 = 0
    public var data: VArray<UInt8, $64> = VArray<UInt8, $64>(repeat: 0)
    public var num: UInt32 = 0
}

public type SHA_CTX = ShaCtx

/// SHA256_CTX
/// 严格翻译自: struct_sha256_state_st
@C
public struct Sha256Ctx {
    public var h: VArray<UInt32, $8> = VArray<UInt32, $8>(repeat: 0)
    public var Nl: UInt32 = 0
    public var Nh: UInt32 = 0
    public var data: VArray<UInt8, $64> = VArray<UInt8, $64>(repeat: 0)
    public var num: UInt32 = 0
    public var md_len: UInt32 = 0
}

public type SHA256_CTX = Sha256Ctx

/// SHA512_CTX
/// 严格翻译自: struct_sha512_state_st
@C
public struct Sha512Ctx {
    public var h: VArray<UInt64, $8> = VArray<UInt64, $8>(repeat: 0)
    public var num: UInt16 = 0
    public var md_len: UInt16 = 0
    public var bytes_so_far_high: UInt32 = 0
    public var bytes_so_far_low: UInt64 = 0
    public var p: VArray<UInt8, $128> = VArray<UInt8, $128>(repeat: 0)
}

public type SHA512_CTX = Sha512Ctx

/// SRTP_PROTECTION_PROFILE
/// 严格翻译自: struct_srtp_protection_profile_st
@C
public struct SrtpProtectionProfile {
    public var name: CString = CString(CPointer<UInt8>())
    public var id: UInt64 = 0
}

public type SRTP_PROTECTION_PROFILE = SrtpProtectionProfile

/// SSL early callback context
/// 严格翻译自: struct_ssl_early_callback_ctx
@C
public struct SslEarlyCallbackCtx {
    public var ssl: CPointer<Unit> = CPointer<Unit>()
    public var client_hello: CPointer<UInt8> = CPointer<UInt8>()
    public var client_hello_len: UIntNative = 0
    public var version: UInt16 = 0
    public var random: CPointer<UInt8> = CPointer<UInt8>()
    public var random_len: UIntNative = 0
    public var session_id: CPointer<UInt8> = CPointer<UInt8>()
    public var session_id_len: UIntNative = 0
    public var cipher_suites: CPointer<UInt8> = CPointer<UInt8>()
    public var cipher_suites_len: UIntNative = 0
    public var compression_methods: CPointer<UInt8> = CPointer<UInt8>()
    public var compression_methods_len: UIntNative = 0
    public var extensions: CPointer<UInt8> = CPointer<UInt8>()
    public var extensions_len: UIntNative = 0
}

/// EVP_ENCODE_CTX
/// 严格翻译自: struct_evp_encode_ctx_st
@C
public struct EvpEncodeCtx {
    public var data_used: UInt32 = 0
    public var data: VArray<UInt8, $48> = VArray<UInt8, $48>(repeat: 0)
    public var eof_seen: UInt8 = 0
    public var error_encountered: UInt8 = 0
}

public type EVP_ENCODE_CTX = EvpEncodeCtx

/// RSA_PSS_PARAMS
/// 严格翻译自: struct_rsa_pss_params_st
@C
public struct RsaPssParams {
    public var hashAlgorithm: CPointer<X509Algor> = CPointer<X509Algor>()
    public var maskGenAlgorithm: CPointer<X509Algor> = CPointer<X509Algor>()
    public var saltLength: CPointer<Asn1StringSt> = CPointer<Asn1StringSt>()
    public var trailerField: CPointer<Asn1StringSt> = CPointer<Asn1StringSt>()
    public var maskHash: CPointer<X509Algor> = CPointer<X509Algor>()
}

public type RSA_PSS_PARAMS = RsaPssParams

/// EVP_CIPHER_CTX
/// 严格翻译自: struct_evp_cipher_ctx_st
@C
public struct EvpCipherCtx {
    public var cipher: CPointer<Unit> = CPointer<Unit>()
    public var app_data: CPointer<Unit> = CPointer<Unit>()
    public var cipher_data: CPointer<Unit> = CPointer<Unit>()
    public var key_len: UInt32 = 0
    public var encrypt: Int32 = 0
    public var flags: UInt32 = 0
    public var oiv: VArray<UInt8, $16> = VArray<UInt8, $16>(repeat: 0)
    public var iv: VArray<UInt8, $16> = VArray<UInt8, $16>(repeat: 0)
    public var buf: VArray<UInt8, $32> = VArray<UInt8, $32>(repeat: 0)
    public var buf_len: Int32 = 0
    public var num: UInt32 = 0
    public var final_used: Int32 = 0
    public var final_: VArray<UInt8, $32> = VArray<UInt8, $32>(repeat: 0)
    public var poisoned: Int32 = 0
}

public type EVP_CIPHER_CTX = EvpCipherCtx

/// EVP_AEAD_CTX
/// 严格翻译自: struct_evp_aead_ctx_st
@C
public struct EvpAeadCtx {
    public var aead: CPointer<Unit> = CPointer<Unit>()
    public var state: VArray<UInt8, $560> = VArray<UInt8, $560>(repeat: 0)
    public var tag_len: UInt8 = 0
}

public type EVP_AEAD_CTX = EvpAeadCtx

/// RSA_METHOD
/// 严格翻译自: struct_rsa_meth_st
@C
public struct RsaMethod {
    public var common: VArray<UInt8, $16> = VArray<UInt8, $16>(repeat: 0)  // struct_openssl_method_common_st
    public var app_data: CPointer<Unit> = CPointer<Unit>()
    public var `init`: CPointer<Unit> = CPointer<Unit>()
    public var finish: CPointer<Unit> = CPointer<Unit>()
    public var size: CPointer<Unit> = CPointer<Unit>()
    public var sign: CPointer<Unit> = CPointer<Unit>()
    public var sign_raw: CPointer<Unit> = CPointer<Unit>()
    public var decrypt: CPointer<Unit> = CPointer<Unit>()
    public var private_transform: CPointer<Unit> = CPointer<Unit>()
    public var flags: Int32 = 0
}

public type RSA_METHOD = RsaMethod

/// ECDSA_METHOD
/// 严格翻译自: struct_ecdsa_method_st
@C
public struct EcdsaMethod {
    public var common: VArray<UInt8, $16> = VArray<UInt8, $16>(repeat: 0)  // struct_openssl_method_common_st
    public var app_data: CPointer<Unit> = CPointer<Unit>()
    public var `init`: CPointer<Unit> = CPointer<Unit>()
    public var finish: CPointer<Unit> = CPointer<Unit>()
    public var group_order_size: CPointer<Unit> = CPointer<Unit>()
    public var sign: CPointer<Unit> = CPointer<Unit>()
    public var flags: Int32 = 0
}

public type ECDSA_METHOD = EcdsaMethod

/// ECDSA_SIG
/// 严格翻译自: struct_ecdsa_sig_st
@C
public struct EcdsaSig {
    public var r: CPointer<BigNumSt> = CPointer<BigNumSt>()
    public var s: CPointer<BigNumSt> = CPointer<BigNumSt>()
}

public type ECDSA_SIG = EcdsaSig
