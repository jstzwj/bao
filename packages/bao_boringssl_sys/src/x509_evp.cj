// 严格翻译自: src/boringssl_sys/boringssl.zig
package bao_boringssl_sys

// ============================================================================
// BoringSSL X509, EVP, BN, DH, EC, RSA FFI 函数声明
// 严格翻译自: boringssl.zig 中 X509_*, EVP_*, BN_*, DH_*, EC_*, RSA_* 函数
// ============================================================================

// --- X509 函数 ---
foreign func X509_new(): CPointer<Unit>
foreign func X509_free(x: CPointer<Unit>): Unit
foreign func X509_up_ref(x: CPointer<Unit>): Int32
foreign func X509_dup(x: CPointer<Unit>): CPointer<Unit>
foreign func X509_parse_parameters(buf: CPointer<CbsSt>): CPointer<Unit>
foreign func X509_get_subject_name(x: CPointer<Unit>): CPointer<Unit>
foreign func X509_get_issuer_name(x: CPointer<Unit>): CPointer<Unit>
foreign func X509_get_serialNumber(x: CPointer<Unit>): CPointer<Unit>
foreign func X509_get0_extensions(x: CPointer<Unit>): CPointer<Unit>
foreign func X509_get_pubkey(x: CPointer<Unit>): CPointer<EvpPkeySt>
foreign func X509_get0_pubkey(x: CPointer<Unit>): CPointer<EvpPkeySt>
foreign func X509_set_pubkey(x: CPointer<Unit>, pkey: CPointer<EvpPkeySt>): Int32
foreign func X509_get_ext_d2i(x: CPointer<Unit>, nid: Int32, out_critical: CPointer<Int32>, out_idx: CPointer<Int32>): CPointer<Unit>
foreign func X509_get_version(x: CPointer<Unit>): Int64
foreign func X509_get_signature_nid(x: CPointer<Unit>): Int32
foreign func X509_get_signature_algorithm(x: CPointer<Unit>): CPointer<Unit>
foreign func X509_get_notBefore(x: CPointer<Unit>): CPointer<Asn1StringSt>
foreign func X509_get_notAfter(x: CPointer<Unit>): CPointer<Asn1StringSt>
foreign func X509_set1_notBefore(x: CPointer<Unit>, tm: CPointer<Asn1StringSt>): Int32
foreign func X509_set1_notAfter(x: CPointer<Unit>, tm: CPointer<Asn1StringSt>): Int32
foreign func X509_sign(x: CPointer<Unit>, pkey: CPointer<EvpPkeySt>, md: CPointer<Unit>): Int32
foreign func X509_verify(x: CPointer<Unit>, pkey: CPointer<EvpPkeySt>): Int32
foreign func X509_print(bio: CPointer<Unit>, x: CPointer<Unit>): Int32
foreign func X509_REQ_new(): CPointer<Unit>
foreign func X509_REQ_free(req: CPointer<Unit>): Unit
foreign func X509_REQ_set_subject_name(req: CPointer<Unit>, name: CPointer<Unit>): Int32
foreign func X509_REQ_set_pubkey(req: CPointer<Unit>, pkey: CPointer<EvpPkeySt>): Int32
foreign func X509_REQ_sign(req: CPointer<Unit>, pkey: CPointer<EvpPkeySt>, md: CPointer<Unit>): Int32
foreign func X509_REQ_verify(req: CPointer<Unit>, pkey: CPointer<EvpPkeySt>): Int32

// --- X509_NAME 函数 ---
foreign func X509_NAME_new(): CPointer<Unit>
foreign func X509_NAME_free(name: CPointer<Unit>): Unit
foreign func X509_NAME_dup(name: CPointer<Unit>): CPointer<Unit>
foreign func X509_NAME_add_entry_by_txt(name: CPointer<Unit>, field: CString, type_: Int32, bytes: CPointer<UInt8>, len: Int32, loc: Int32, set_: Int32): Int32
foreign func X509_NAME_get_index_by_NID(name: CPointer<Unit>, nid: Int32, lastpos: Int32): Int32
foreign func X509_NAME_get_entry(name: CPointer<Unit>, loc: Int32): CPointer<Unit>
foreign func X509_NAME_ENTRY_get_data(ne: CPointer<Unit>): CPointer<Asn1StringSt>
foreign func X509_NAME_oneline(name: CPointer<Unit>, buf: CPointer<UInt8>, len: Int32): CPointer<UInt8>
foreign func X509_NAME_cmp(a: CPointer<Unit>, b: CPointer<Unit>): Int32
foreign func X509_NAME_print_ex(bio: CPointer<Unit>, name: CPointer<Unit>, indent: UInt32, flags: UInt32): Int32

// --- X509_EXTENSION ---
foreign func X509_EXTENSION_new(): CPointer<Unit>
foreign func X509_EXTENSION_free(ext: CPointer<Unit>): Unit
foreign func X509_EXTENSION_create_by_NID(ex: CPointer<CPointer<Unit>>, nid: Int32, crit: Int32, data: CPointer<Asn1StringSt>): CPointer<Unit>
foreign func X509_EXTENSION_get_object(ext: CPointer<Unit>): CPointer<Unit>
foreign func X509_EXTENSION_get_data(ext: CPointer<Unit>): CPointer<Asn1StringSt>
foreign func X509_EXTENSION_get_critical(ext: CPointer<Unit>): Int32
foreign func X509_add_ext(x: CPointer<Unit>, ext: CPointer<Unit>, loc: Int32): Int32

// --- X509_STORE ---
foreign func X509_STORE_new(): CPointer<Unit>
foreign func X509_STORE_free(store: CPointer<Unit>): Unit
foreign func X509_STORE_add_cert(store: CPointer<Unit>, x: CPointer<Unit>): Int32
foreign func X509_STORE_add_crl(store: CPointer<Unit>, x: CPointer<Unit>): Int32
foreign func X509_STORE_set_flags(store: CPointer<Unit>, flags: UInt64): Int32
foreign func X509_STORE_set_purpose(store: CPointer<Unit>, purpose: Int32): Int32
foreign func X509_STORE_set_trust(store: CPointer<Unit>, trust: Int32): Int32
foreign func X509_STORE_set1_param(store: CPointer<Unit>, pm: CPointer<Unit>): Int32
foreign func X509_STORE_get0_objects(store: CPointer<Unit>): CPointer<Unit>

// --- X509_VERIFY_PARAM ---
foreign func X509_VERIFY_PARAM_new(): CPointer<Unit>
foreign func X509_VERIFY_PARAM_free(param: CPointer<Unit>): Unit
foreign func X509_VERIFY_PARAM_set_flags(param: CPointer<Unit>, flags: UInt64): Unit
foreign func X509_VERIFY_PARAM_clear_flags(param: CPointer<Unit>, flags: UInt64): Unit
foreign func X509_VERIFY_PARAM_get_flags(param: CPointer<Unit>): UInt64
foreign func X509_VERIFY_PARAM_set_purpose(param: CPointer<Unit>, purpose: Int32): Int32
foreign func X509_VERIFY_PARAM_set_trust(param: CPointer<Unit>, trust: Int32): Int32
foreign func X509_VERIFY_PARAM_set_time(param: CPointer<Unit>, t: UInt64): Unit
foreign func X509_VERIFY_PARAM_set_depth(param: CPointer<Unit>, depth: Int32): Unit
foreign func X509_VERIFY_PARAM_set1_host(param: CPointer<Unit>, name: CString, namelen: UIntNative): Int32
foreign func X509_VERIFY_PARAM_set1_email(param: CPointer<Unit>, email: CString, emaillen: UIntNative): Int32
foreign func X509_VERIFY_PARAM_set1_ip(param: CPointer<Unit>, ip: CPointer<UInt8>, iplen: UIntNative): Int32
foreign func X509_VERIFY_PARAM_set1_ip_asc(param: CPointer<Unit>, ipasc: CString): Int32

// --- X509_CRL ---
foreign func X509_CRL_new(): CPointer<Unit>
foreign func X509_CRL_free(crl: CPointer<Unit>): Unit
foreign func X509_CRL_dup(crl: CPointer<Unit>): CPointer<Unit>
foreign func X509_CRL_sign(crl: CPointer<Unit>, pkey: CPointer<EvpPkeySt>, md: CPointer<Unit>): Int32
foreign func X509_CRL_verify(crl: CPointer<Unit>, pkey: CPointer<EvpPkeySt>): Int32
foreign func X509_CRL_get0_extensions(crl: CPointer<Unit>): CPointer<Unit>

// --- EVP_PKEY ---
foreign func EVP_PKEY_new(): CPointer<EvpPkeySt>
foreign func EVP_PKEY_free(pkey: CPointer<EvpPkeySt>): Unit
foreign func EVP_PKEY_up_ref(pkey: CPointer<EvpPkeySt>): Unit
foreign func EVP_PKEY_dup(pkey: CPointer<EvpPkeySt>): CPointer<EvpPkeySt>
foreign func EVP_PKEY_copy_parameters(to_: CPointer<EvpPkeySt>, from: CPointer<EvpPkeySt>): Int32
foreign func EVP_PKEY_missing_parameters(pkey: CPointer<EvpPkeySt>): Int32
foreign func EVP_PKEY_size(pkey: CPointer<EvpPkeySt>): Int32
foreign func EVP_PKEY_bits(pkey: CPointer<EvpPkeySt>): Int32
foreign func EVP_PKEY_security_bits(pkey: CPointer<EvpPkeySt>): Int32
foreign func EVP_PKEY_id(pkey: CPointer<EvpPkeySt>): Int32
foreign func EVP_PKEY_type(type_: Int32): Int32
foreign func EVP_PKEY_get0_RSA(pkey: CPointer<EvpPkeySt>): CPointer<Unit>
foreign func EVP_PKEY_get0_DSA(pkey: CPointer<EvpPkeySt>): CPointer<DSA>
foreign func EVP_PKEY_get0_DH(pkey: CPointer<EvpPkeySt>): CPointer<Unit>
foreign func EVP_PKEY_get0_EC_KEY(pkey: CPointer<EvpPkeySt>): CPointer<Unit>
foreign func EVP_PKEY_assign_RSA(pkey: CPointer<EvpPkeySt>, rsa: CPointer<Unit>): Int32
foreign func EVP_PKEY_assign_DSA(pkey: CPointer<EvpPkeySt>, dsa: CPointer<DSA>): Int32
foreign func EVP_PKEY_assign_EC_KEY(pkey: CPointer<EvpPkeySt>, ec_key: CPointer<Unit>): Int32
foreign func EVP_PKEY_set1_RSA(pkey: CPointer<EvpPkeySt>, rsa: CPointer<Unit>): Int32
foreign func EVP_PKEY_set1_DSA(pkey: CPointer<EvpPkeySt>, dsa: CPointer<DSA>): Int32
foreign func EVP_PKEY_set1_EC_KEY(pkey: CPointer<EvpPkeySt>, ec_key: CPointer<Unit>): Int32
foreign func EVP_PKEY_CTX_new(pkey: CPointer<EvpPkeySt>, engine: CPointer<Unit>): CPointer<Unit>
foreign func EVP_PKEY_CTX_new_id(id: Int32, engine: CPointer<Unit>): CPointer<Unit>
foreign func EVP_PKEY_CTX_free(ctx: CPointer<Unit>): Unit
foreign func EVP_PKEY_keygen_init(ctx: CPointer<Unit>): Int32
foreign func EVP_PKEY_keygen(ctx: CPointer<Unit>, ppkey: CPointer<CPointer<EvpPkeySt>>): Int32
foreign func EVP_PKEY_derive_init(ctx: CPointer<Unit>): Int32
foreign func EVP_PKEY_derive(ctx: CPointer<Unit>, key: CPointer<UInt8>, keylen: CPointer<UIntNative>): Int32
foreign func EVP_PKEY_derive_set_peer(ctx: CPointer<Unit>, peer: CPointer<EvpPkeySt>): Int32

// --- EVP 加密/解密 ---
foreign func EVP_EncryptInit_ex(ctx: CPointer<EvpCipherCtx>, cipher: CPointer<Unit>, engine: CPointer<Unit>, key: CPointer<UInt8>, iv: CPointer<UInt8>): Int32
foreign func EVP_EncryptUpdate(ctx: CPointer<EvpCipherCtx>, out: CPointer<UInt8>, outl: CPointer<Int32>, in_: CPointer<UInt8>, inl: Int32): Int32
foreign func EVP_EncryptFinal_ex(ctx: CPointer<EvpCipherCtx>, out: CPointer<UInt8>, outl: CPointer<Int32>): Int32
foreign func EVP_DecryptInit_ex(ctx: CPointer<EvpCipherCtx>, cipher: CPointer<Unit>, engine: CPointer<Unit>, key: CPointer<UInt8>, iv: CPointer<UInt8>): Int32
foreign func EVP_DecryptUpdate(ctx: CPointer<EvpCipherCtx>, out: CPointer<UInt8>, outl: CPointer<Int32>, in_: CPointer<UInt8>, inl: Int32): Int32
foreign func EVP_DecryptFinal_ex(ctx: CPointer<EvpCipherCtx>, out: CPointer<UInt8>, outl: CPointer<Int32>): Int32
foreign func EVP_CipherInit_ex(ctx: CPointer<EvpCipherCtx>, cipher: CPointer<Unit>, engine: CPointer<Unit>, key: CPointer<UInt8>, iv: CPointer<UInt8>, enc: Int32): Int32
foreign func EVP_CipherUpdate(ctx: CPointer<EvpCipherCtx>, out: CPointer<UInt8>, outl: CPointer<Int32>, in_: CPointer<UInt8>, inl: Int32): Int32
foreign func EVP_CipherFinal_ex(ctx: CPointer<EvpCipherCtx>, out: CPointer<UInt8>, outl: CPointer<Int32>): Int32
foreign func EVP_CIPHER_CTX_new(): CPointer<EvpCipherCtx>
foreign func EVP_CIPHER_CTX_free(ctx: CPointer<EvpCipherCtx>): Unit
foreign func EVP_CIPHER_CTX_reset(ctx: CPointer<EvpCipherCtx>): Int32
foreign func EVP_CIPHER_CTX_set_padding(ctx: CPointer<EvpCipherCtx>, pad: Int32): Int32
foreign func EVP_CIPHER_CTX_set_key_length(ctx: CPointer<EvpCipherCtx>, keylen: Int32): Int32
foreign func EVP_CIPHER_CTX_ctrl(ctx: CPointer<EvpCipherCtx>, type_: Int32, arg: Int32, ptr: CPointer<Unit>): Int32
foreign func EVP_CIPHER_key_length(cipher: CPointer<Unit>): Int32
foreign func EVP_CIPHER_iv_length(cipher: CPointer<Unit>): Int32
foreign func EVP_CIPHER_block_size(cipher: CPointer<Unit>): Int32
foreign func EVP_CIPHER_nid(cipher: CPointer<Unit>): Int32
foreign func EVP_CIPHER_CTX_key_length(ctx: CPointer<EvpCipherCtx>): Int32
foreign func EVP_CIPHER_CTX_iv_length(ctx: CPointer<EvpCipherCtx>): Int32
foreign func EVP_CIPHER_CTX_get_cipher(ctx: CPointer<EvpCipherCtx>): CPointer<Unit>

// --- EVP 签名/验签 ---
foreign func EVP_DigestSignInit(ctx: CPointer<Unit>, pctx: CPointer<CPointer<Unit>>, type_: CPointer<Unit>, engine: CPointer<Unit>, pkey: CPointer<EvpPkeySt>): Int32
foreign func EVP_DigestSignUpdate(ctx: CPointer<Unit>, data: CPointer<Unit>, dataSize: UIntNative): Int32
foreign func EVP_DigestSignFinal(ctx: CPointer<Unit>, sig: CPointer<UInt8>, sigLen: CPointer<UIntNative>): Int32
foreign func EVP_DigestVerifyInit(ctx: CPointer<Unit>, pctx: CPointer<CPointer<Unit>>, type_: CPointer<Unit>, engine: CPointer<Unit>, pkey: CPointer<EvpPkeySt>): Int32
foreign func EVP_DigestVerifyUpdate(ctx: CPointer<Unit>, data: CPointer<Unit>, dataSize: UIntNative): Int32
foreign func EVP_DigestVerifyFinal(ctx: CPointer<Unit>, sig: CPointer<UInt8>, sigLen: UIntNative): Int32
foreign func EVP_DigestSign(ctx: CPointer<Unit>, sig: CPointer<UInt8>, sigLen: CPointer<UIntNative>, data: CPointer<UInt8>, dataSize: UIntNative): Int32
foreign func EVP_DigestVerify(ctx: CPointer<Unit>, sig: CPointer<UInt8>, sigLen: UIntNative, data: CPointer<UInt8>, dataSize: UIntNative): Int32

// --- EVP 摘要 ---
foreign func EVP_DigestInit_ex(ctx: CPointer<Unit>, type_: CPointer<Unit>, engine: CPointer<Unit>): Int32
foreign func EVP_DigestUpdate(ctx: CPointer<Unit>, data: CPointer<Unit>, count: UIntNative): Int32
foreign func EVP_DigestFinal_ex(ctx: CPointer<Unit>, md: CPointer<UInt8>, size: CPointer<UInt32>): Int32
foreign func EVP_Digest(data: CPointer<Unit>, count: UIntNative, md: CPointer<UInt8>, size: CPointer<UInt32>, type_: CPointer<Unit>, engine: CPointer<Unit>): Int32
foreign func EVP_DigestInit(ctx: CPointer<Unit>, type_: CPointer<Unit>): Int32
foreign func EVP_DigestFinal(ctx: CPointer<Unit>, md: CPointer<UInt8>, size: CPointer<UInt32>): Int32
foreign func EVP_DigestFinalXOF(ctx: CPointer<Unit>, md: CPointer<UInt8>, size: UIntNative): Int32
foreign func EVP_MD_CTX_new(): CPointer<Unit>
foreign func EVP_MD_CTX_free(ctx: CPointer<Unit>): Unit
foreign func EVP_MD_CTX_copy_ex(out: CPointer<Unit>, in_: CPointer<Unit>): Int32
foreign func EVP_MD_CTX_reset(ctx: CPointer<Unit>): Int32
foreign func EVP_MD_size(md: CPointer<Unit>): Int32
foreign func EVP_MD_block_size(md: CPointer<Unit>): Int32
foreign func EVP_MD_type(md: CPointer<Unit>): Int32
foreign func EVP_MD_nid(md: CPointer<Unit>): Int32
foreign func EVP_MD_name(md: CPointer<Unit>): CString
foreign func EVP_MD_flags(md: CPointer<Unit>): UInt64
foreign func EVP_get_digestbyname(name: CString): CPointer<Unit>

// --- BN (大数) ---
foreign func BN_new(): CPointer<BigNumSt>
foreign func BN_free(a: CPointer<BigNumSt>): Unit
foreign func BN_clear_free(a: CPointer<BigNumSt>): Unit
foreign func BN_dup(a: CPointer<BigNumSt>): CPointer<BigNumSt>
foreign func BN_copy(a: CPointer<BigNumSt>, b: CPointer<BigNumSt>): CPointer<BigNumSt>
foreign func BN_clear(a: CPointer<BigNumSt>): Unit
foreign func BN_value_one(): CPointer<BigNumSt>
foreign func BN_num_bits(a: CPointer<BigNumSt>): Int32
foreign func BN_num_bytes(a: CPointer<BigNumSt>): Int32
foreign func BN_set_word(a: CPointer<BigNumSt>, w: UInt64): Int32
foreign func BN_add(r: CPointer<BigNumSt>, a: CPointer<BigNumSt>, b: CPointer<BigNumSt>): Int32
foreign func BN_sub(r: CPointer<BigNumSt>, a: CPointer<BigNumSt>, b: CPointer<BigNumSt>): Int32
foreign func BN_mul(r: CPointer<BigNumSt>, a: CPointer<BigNumSt>, b: CPointer<BigNumSt>, ctx: CPointer<Unit>): Int32
foreign func BN_div(dv: CPointer<BigNumSt>, rem: CPointer<BigNumSt>, a: CPointer<BigNumSt>, b: CPointer<BigNumSt>, ctx: CPointer<Unit>): Int32
foreign func BN_mod(rem: CPointer<BigNumSt>, a: CPointer<BigNumSt>, b: CPointer<BigNumSt>, ctx: CPointer<Unit>): Int32
foreign func BN_mod_mul(r: CPointer<BigNumSt>, a: CPointer<BigNumSt>, b: CPointer<BigNumSt>, m: CPointer<BigNumSt>, ctx: CPointer<Unit>): Int32
foreign func BN_mod_exp(r: CPointer<BigNumSt>, a: CPointer<BigNumSt>, p: CPointer<BigNumSt>, m: CPointer<BigNumSt>, ctx: CPointer<Unit>): Int32
foreign func BN_bin2bn(s: CPointer<UInt8>, size: Int32, ret: CPointer<BigNumSt>): CPointer<BigNumSt>
foreign func BN_bn2bin(a: CPointer<BigNumSt>, to: CPointer<UInt8>): Int32
foreign func BN_bn2hex(a: CPointer<BigNumSt>): CPointer<UInt8>
foreign func BN_bn2dec(a: CPointer<BigNumSt>): CPointer<UInt8>
foreign func BN_hex2bn(a: CPointer<CPointer<BigNumSt>>, str: CString): Int32
foreign func BN_dec2bn(a: CPointer<CPointer<BigNumSt>>, str: CString): Int32
foreign func BN_CTX_new(): CPointer<Unit>
foreign func BN_CTX_free(ctx: CPointer<Unit>): Unit
foreign func BN_rand(r: CPointer<BigNumSt>, bits: Int32, top: Int32, bottom: Int32): Int32
foreign func BN_rand_range(r: CPointer<BigNumSt>, range: CPointer<BigNumSt>): Int32
foreign func BN_generate_prime_ex(r: CPointer<BigNumSt>, bits: Int32, safe: Int32, add: CPointer<BigNumSt>, rem: CPointer<BigNumSt>, cb: CPointer<BnGencb>): Int32
foreign func BN_is_prime_ex(a: CPointer<BigNumSt>, checks: Int32, ctx: CPointer<Unit>, cb: CPointer<BnGencb>): Int32

// --- RSA ---
foreign func RSA_new(): CPointer<Unit>
foreign func RSA_free(rsa: CPointer<Unit>): Unit
foreign func RSA_up_ref(rsa: CPointer<Unit>): Int32
foreign func RSA_bits(rsa: CPointer<Unit>): Int32
foreign func RSA_size(rsa: CPointer<Unit>): Int32
foreign func RSA_generate_key(bits: Int32, e_value: UInt64, cb: CPointer<Unit>, cb_arg: CPointer<Unit>): CPointer<Unit>
foreign func RSA_generate_key_ex(rsa: CPointer<Unit>, bits: Int32, e: CPointer<BigNumSt>, cb: CPointer<BnGencb>): Int32
foreign func RSA_public_encrypt(flen: Int32, from: CPointer<UInt8>, to: CPointer<UInt8>, rsa: CPointer<Unit>, padding: Int32): Int32
foreign func RSA_private_encrypt(flen: Int32, from: CPointer<UInt8>, to: CPointer<UInt8>, rsa: CPointer<Unit>, padding: Int32): Int32
foreign func RSA_public_decrypt(flen: Int32, from: CPointer<UInt8>, to: CPointer<UInt8>, rsa: CPointer<Unit>, padding: Int32): Int32
foreign func RSA_private_decrypt(flen: Int32, from: CPointer<UInt8>, to: CPointer<UInt8>, rsa: CPointer<Unit>, padding: Int32): Int32
foreign func RSA_sign(nid: Int32, message: CPointer<UInt8>, message_len: UInt32, sig: CPointer<UInt8>, sig_len: CPointer<UInt32>, rsa: CPointer<Unit>): Int32
foreign func RSA_verify(nid: Int32, message: CPointer<UInt8>, message_len: UInt32, sig: CPointer<UInt8>, sig_len: UInt32, rsa: CPointer<Unit>): Int32
foreign func RSA_get0_n(rsa: CPointer<Unit>): CPointer<BigNumSt>
foreign func RSA_get0_e(rsa: CPointer<Unit>): CPointer<BigNumSt>
foreign func RSA_get0_d(rsa: CPointer<Unit>): CPointer<BigNumSt>
foreign func RSA_get0_p(rsa: CPointer<Unit>): CPointer<BigNumSt>
foreign func RSA_get0_q(rsa: CPointer<Unit>): CPointer<BigNumSt>
foreign func RSA_get0_dmp1(rsa: CPointer<Unit>): CPointer<BigNumSt>
foreign func RSA_get0_dmq1(rsa: CPointer<Unit>): CPointer<BigNumSt>
foreign func RSA_get0_iqmp(rsa: CPointer<Unit>): CPointer<BigNumSt>

// --- EC ---
foreign func EC_GROUP_new_by_curve_name(nid: Int32): CPointer<Unit>
foreign func EC_GROUP_free(group: CPointer<Unit>): Unit
foreign func EC_GROUP_get_curve_name(group: CPointer<Unit>): Int32
foreign func EC_GROUP_get_degree(group: CPointer<Unit>): UInt32
foreign func EC_GROUP_get_order(group: CPointer<Unit>, order: CPointer<BigNumSt>, ctx: CPointer<Unit>): Int32
foreign func EC_KEY_new(): CPointer<Unit>
foreign func EC_KEY_new_by_curve_name(nid: Int32): CPointer<Unit>
foreign func EC_KEY_free(key: CPointer<Unit>): Unit
foreign func EC_KEY_up_ref(key: CPointer<Unit>): Int32
foreign func EC_KEY_dup(key: CPointer<Unit>): CPointer<Unit>
foreign func EC_KEY_get0_group(key: CPointer<Unit>): CPointer<Unit>
foreign func EC_KEY_get0_public_key(key: CPointer<Unit>): CPointer<Unit>
foreign func EC_KEY_set_group(key: CPointer<Unit>, group: CPointer<Unit>): Int32
foreign func EC_KEY_set_public_key(key: CPointer<Unit>, pub: CPointer<Unit>): Int32
foreign func EC_KEY_generate_key(key: CPointer<Unit>): Int32
foreign func EC_KEY_check_key(key: CPointer<Unit>): Int32
foreign func EC_POINT_new(group: CPointer<Unit>): CPointer<Unit>
foreign func EC_POINT_free(point: CPointer<Unit>): Unit
foreign func EC_POINT_point2oct(group: CPointer<Unit>, point: CPointer<Unit>, form: Int32, buf: CPointer<UInt8>, len: UIntNative, ctx: CPointer<Unit>): UIntNative
foreign func EC_POINT_oct2point(group: CPointer<Unit>, point: CPointer<Unit>, buf: CPointer<UInt8>, len: UIntNative, ctx: CPointer<Unit>): Int32
foreign func ECDSA_SIG_new(): CPointer<EcdsaSig>
foreign func ECDSA_SIG_free(sig: CPointer<EcdsaSig>): Unit
foreign func ECDSA_SIG_set0(sig: CPointer<EcdsaSig>, r: CPointer<BigNumSt>, s: CPointer<BigNumSt>): Unit
foreign func ECDSA_do_sign(digest: CPointer<UInt8>, digest_len: UIntNative, key: CPointer<Unit>): CPointer<EcdsaSig>
foreign func ECDSA_do_verify(digest: CPointer<UInt8>, digest_len: UIntNative, sig: CPointer<EcdsaSig>, key: CPointer<Unit>): Int32
foreign func ECDSA_sign(type_: Int32, digest: CPointer<UInt8>, digest_len: UIntNative, sig: CPointer<UInt8>, sig_len: CPointer<UInt32>, key: CPointer<Unit>): Int32
foreign func ECDSA_verify(type_: Int32, digest: CPointer<UInt8>, digest_len: UIntNative, sig: CPointer<UInt8>, sig_len: Int32, key: CPointer<Unit>): Int32

// --- DH ---
foreign func DH_new(): CPointer<Unit>
foreign func DH_free(dh: CPointer<Unit>): Unit
foreign func DH_generate_parameters_prime(dh: CPointer<Unit>, prime_len: Int32, generator: Int32, cb: CPointer<Unit>): Int32
foreign func DH_generate_key(dh: CPointer<Unit>): Int32
foreign func DH_compute_key(key: CPointer<UInt8>, pub: CPointer<Unit>, dh: CPointer<Unit>): Int32

// --- EVP_AEAD ---
foreign func EVP_aead_aes_128_gcm(): CPointer<Unit>
foreign func EVP_aead_aes_256_gcm(): CPointer<Unit>
foreign func EVP_aead_chacha20_poly1305(): CPointer<Unit>
foreign func EVP_aead_aes_128_ctr_hmac_sha256(): CPointer<Unit>
foreign func EVP_aead_aes_256_ctr_hmac_sha256(): CPointer<Unit>
foreign func EVP_AEAD_key_length(aead: CPointer<Unit>): UIntNative
foreign func EVP_AEAD_nonce_length(aead: CPointer<Unit>): UIntNative
foreign func EVP_AEAD_max_overhead(aead: CPointer<Unit>): UIntNative
foreign func EVP_AEAD_max_tag_len(aead: CPointer<Unit>): UIntNative
foreign func EVP_AEAD_CTX_init(ctx: CPointer<EvpAeadCtx>, aead: CPointer<Unit>, key: CPointer<UInt8>, key_len: UIntNative, tag_len: UIntNative, engine: CPointer<Unit>): Int32
foreign func EVP_AEAD_CTX_seal(ctx: CPointer<EvpAeadCtx>, out: CPointer<UInt8>, out_len: CPointer<UIntNative>, max_out: UIntNative, nonce: CPointer<UInt8>, nonce_len: UIntNative, in_: CPointer<UInt8>, in_len: UIntNative, ad: CPointer<UInt8>, ad_len: UIntNative): Int32
foreign func EVP_AEAD_CTX_open(ctx: CPointer<EvpAeadCtx>, out: CPointer<UInt8>, out_len: CPointer<UIntNative>, max_out: UIntNative, nonce: CPointer<UInt8>, nonce_len: UIntNative, in_: CPointer<UInt8>, in_len: UIntNative, ad: CPointer<UInt8>, ad_len: UIntNative): Int32
foreign func EVP_AEAD_CTX_cleanup(ctx: CPointer<EvpAeadCtx>): Unit

// --- d2i/i2d 序列化/反序列化 ---
foreign func d2i_X509(a: CPointer<CPointer<Unit>>, pp: CPointer<CPointer<UInt8>>, length: Int64): CPointer<Unit>
foreign func i2d_X509(x: CPointer<Unit>, pp: CPointer<CPointer<UInt8>>): Int32
foreign func d2i_X509_bio(bio: CPointer<Unit>, x: CPointer<CPointer<Unit>>): CPointer<Unit>
foreign func i2d_X509_bio(bio: CPointer<Unit>, x: CPointer<Unit>): Int32
foreign func d2i_X509_REQ_bio(bio: CPointer<Unit>, x: CPointer<CPointer<Unit>>): CPointer<Unit>
foreign func i2d_X509_REQ_bio(bio: CPointer<Unit>, x: CPointer<Unit>): Int32
foreign func d2i_PrivateKey_bio(bio: CPointer<Unit>, x: CPointer<CPointer<EvpPkeySt>>): CPointer<EvpPkeySt>
foreign func i2d_PrivateKey_bio(bio: CPointer<Unit>, x: CPointer<EvpPkeySt>): Int32
foreign func d2i_PUBKEY_bio(bio: CPointer<Unit>, x: CPointer<CPointer<EvpPkeySt>>): CPointer<EvpPkeySt>
foreign func i2d_PUBKEY_bio(bio: CPointer<Unit>, x: CPointer<EvpPkeySt>): Int32
foreign func d2i_PKCS12_bio(bio: CPointer<Unit>, p12: CPointer<CPointer<Unit>>): CPointer<Unit>
foreign func i2d_PKCS12_bio(bio: CPointer<Unit>, p12: CPointer<Unit>): Int32
foreign func PKCS12_parse(p12: CPointer<Unit>, pass: CString, out_key: CPointer<CPointer<EvpPkeySt>>, out_cert: CPointer<CPointer<Unit>>, out_certs: CPointer<CPointer<Unit>>): Int32
foreign func PKCS12_free(p12: CPointer<Unit>): Unit
foreign func d2i_SSL_SESSION(a: CPointer<CPointer<Unit>>, pp: CPointer<CPointer<UInt8>>, length: Int64): CPointer<Unit>
foreign func i2d_SSL_SESSION(in_: CPointer<Unit>, pp: CPointer<CPointer<UInt8>>): Int32
foreign func d2i_SSL_SESSION_bio(bio: CPointer<Unit>, out: CPointer<CPointer<Unit>>): CPointer<Unit>
foreign func i2d_SSL_SESSION_bio(bio: CPointer<Unit>, session: CPointer<Unit>): Int32

// --- PEM 函数 ---
foreign func PEM_read_bio_X509(bp: CPointer<Unit>, x: CPointer<CPointer<Unit>>, cb: CPointer<Unit>, u: CPointer<Unit>): CPointer<Unit>
foreign func PEM_write_bio_X509(bp: CPointer<Unit>, x: CPointer<Unit>): Int32
foreign func PEM_read_bio_X509_AUX(bp: CPointer<Unit>, x: CPointer<CPointer<Unit>>, cb: CPointer<Unit>, u: CPointer<Unit>): CPointer<Unit>
foreign func PEM_write_bio_X509_AUX(bp: CPointer<Unit>, x: CPointer<Unit>): Int32
foreign func PEM_read_bio_X509_REQ(bp: CPointer<Unit>, x: CPointer<CPointer<Unit>>, cb: CPointer<Unit>, u: CPointer<Unit>): CPointer<Unit>
foreign func PEM_write_bio_X509_REQ(bp: CPointer<Unit>, x: CPointer<Unit>): Int32
foreign func PEM_read_bio_PrivateKey(bp: CPointer<Unit>, x: CPointer<CPointer<EvpPkeySt>>, cb: CPointer<Unit>, u: CPointer<Unit>): CPointer<EvpPkeySt>
foreign func PEM_write_bio_PrivateKey(bp: CPointer<Unit>, x: CPointer<EvpPkeySt>, enc: CPointer<Unit>, kstr: CPointer<UInt8>, klen: Int32, cb: CPointer<Unit>, u: CPointer<Unit>): Int32
foreign func PEM_read_bio_PUBKEY(bp: CPointer<Unit>, x: CPointer<CPointer<EvpPkeySt>>, cb: CPointer<Unit>, u: CPointer<Unit>): CPointer<EvpPkeySt>
foreign func PEM_write_bio_PUBKEY(bp: CPointer<Unit>, x: CPointer<EvpPkeySt>): Int32
foreign func PEM_read_bio_PKCS7(bp: CPointer<Unit>, x: CPointer<CPointer<Unit>>, cb: CPointer<Unit>, u: CPointer<Unit>): CPointer<Unit>
foreign func PEM_write_bio_PKCS7(bp: CPointer<Unit>, x: CPointer<Unit>): Int32
foreign func PEM_read_bio_PKCS8(bp: CPointer<Unit>, x: CPointer<CPointer<EvpPkeySt>>, cb: CPointer<Unit>, u: CPointer<Unit>): CPointer<EvpPkeySt>
foreign func PEM_write_bio_PKCS8PrivateKey(bp: CPointer<Unit>, x: CPointer<EvpPkeySt>, enc: CPointer<Unit>, kstr: CPointer<UInt8>, klen: Int32, cb: CPointer<Unit>, u: CPointer<Unit>): Int32
foreign func PEM_read_bio_CRL(bp: CPointer<Unit>, x: CPointer<CPointer<Unit>>, cb: CPointer<Unit>, u: CPointer<Unit>): CPointer<Unit>
foreign func PEM_write_bio_X509_CRL(bp: CPointer<Unit>, x: CPointer<Unit>): Int32
foreign func PEM_read_bio_DHparams(bp: CPointer<Unit>, x: CPointer<CPointer<Unit>>, cb: CPointer<Unit>, u: CPointer<Unit>): CPointer<Unit>
foreign func PEM_write_bio_DHparams(bp: CPointer<Unit>, x: CPointer<Unit>): Int32
foreign func PEM_read_bio_ECPrivateKey(bp: CPointer<Unit>, x: CPointer<CPointer<Unit>>, cb: CPointer<Unit>, u: CPointer<Unit>): CPointer<Unit>
foreign func PEM_write_bio_ECPrivateKey(bp: CPointer<Unit>, x: CPointer<Unit>, enc: CPointer<Unit>, kstr: CPointer<UInt8>, klen: Int32, cb: CPointer<Unit>, u: CPointer<Unit>): Int32
foreign func PEM_read_bio_RSAPrivateKey(bp: CPointer<Unit>, x: CPointer<CPointer<Unit>>, cb: CPointer<Unit>, u: CPointer<Unit>): CPointer<Unit>
foreign func PEM_write_bio_RSAPrivateKey(bp: CPointer<Unit>, x: CPointer<Unit>, enc: CPointer<Unit>, kstr: CPointer<UInt8>, klen: Int32, cb: CPointer<Unit>, u: CPointer<Unit>): Int32

// --- OBJ_nid 和 OBJ_txt 函数 ---
foreign func OBJ_nid2sn(n: Int32): CString
foreign func OBJ_nid2ln(n: Int32): CString
foreign func OBJ_sn2nid(s: CString): Int32
foreign func OBJ_ln2nid(s: CString): Int32
foreign func OBJ_txt2nid(s: CString): Int32
foreign func OBJ_nid2obj(n: Int32): CPointer<Unit>
foreign func OBJ_obj2nid(o: CPointer<Unit>): Int32
foreign func OBJ_cmp(a: CPointer<Unit>, b: CPointer<Unit>): Int32
