// 严格翻译自: src/boringssl_sys/boringssl.zig
package bao_boringssl_sys

// ============================================================================
// BoringSSL 额外 EVP, PKCS5, PKCS7, PKCS8 FFI 函数声明
// 严格翻译自: boringssl.zig 中补充的 EVP_* cipher/encode/decode/PKEY,
//   PKCS5_*, PKCS7_*, PKCS8_PRIV_KEY_INFO_* 函数
// ============================================================================

// --- EVP 密码算法 ---
foreign func EVP_aes_128_cbc(): CPointer<Unit>
foreign func EVP_aes_128_cfb(): CPointer<Unit>
foreign func EVP_aes_128_cfb128(): CPointer<Unit>
foreign func EVP_aes_128_ctr(): CPointer<Unit>
foreign func EVP_aes_128_ecb(): CPointer<Unit>
foreign func EVP_aes_128_gcm(): CPointer<Unit>
foreign func EVP_aes_128_ofb(): CPointer<Unit>
foreign func EVP_aes_192_cbc(): CPointer<Unit>
foreign func EVP_aes_192_cfb(): CPointer<Unit>
foreign func EVP_aes_192_cfb128(): CPointer<Unit>
foreign func EVP_aes_192_ctr(): CPointer<Unit>
foreign func EVP_aes_192_ecb(): CPointer<Unit>
foreign func EVP_aes_192_gcm(): CPointer<Unit>
foreign func EVP_aes_192_ofb(): CPointer<Unit>
foreign func EVP_aes_256_cbc(): CPointer<Unit>
foreign func EVP_aes_256_cfb(): CPointer<Unit>
foreign func EVP_aes_256_cfb128(): CPointer<Unit>
foreign func EVP_aes_256_ctr(): CPointer<Unit>
foreign func EVP_aes_256_ecb(): CPointer<Unit>
foreign func EVP_aes_256_gcm(): CPointer<Unit>
foreign func EVP_aes_256_ofb(): CPointer<Unit>
foreign func EVP_aes_256_xts(): CPointer<Unit>
foreign func EVP_bf_cbc(): CPointer<Unit>
foreign func EVP_bf_cfb(): CPointer<Unit>
foreign func EVP_bf_ecb(): CPointer<Unit>
foreign func EVP_cast5_cbc(): CPointer<Unit>
foreign func EVP_cast5_ecb(): CPointer<Unit>
foreign func EVP_des_cbc(): CPointer<Unit>
foreign func EVP_des_ecb(): CPointer<Unit>
foreign func EVP_des_ede(): CPointer<Unit>
foreign func EVP_des_ede3(): CPointer<Unit>
foreign func EVP_des_ede3_cbc(): CPointer<Unit>
foreign func EVP_des_ede3_ecb(): CPointer<Unit>
foreign func EVP_des_ede_cbc(): CPointer<Unit>
foreign func EVP_enc_null(): CPointer<Unit>
foreign func EVP_rc2_40_cbc(): CPointer<Unit>
foreign func EVP_rc2_cbc(): CPointer<Unit>
foreign func EVP_rc4(): CPointer<Unit>
foreign func EVP_ripemd160(): CPointer<Unit>
foreign func EVP_md5_sha1(): CPointer<Unit>
foreign func EVP_dss1(): CPointer<Unit>
foreign func EVP_get_cipherbyname(name: CString): CPointer<Unit>
foreign func EVP_get_cipherbynid(nid: Int32): CPointer<Unit>
foreign func EVP_get_digestbynid(nid: Int32): CPointer<Unit>
foreign func EVP_get_digestbyobj(obj: CPointer<Unit>): CPointer<Unit>
foreign func EVP_add_cipher_alias(name: CString, alias: CString): Int32
foreign func EVP_add_digest(digest: CPointer<Unit>): Unit
foreign func EVP_cleanup(): Unit
foreign func EVP_has_aes_hardware(): Int32

// --- EVP AEAD 补充 ---
foreign func EVP_aead_aes_128_cbc_sha1_tls(): CPointer<Unit>
foreign func EVP_aead_aes_128_cbc_sha1_tls_implicit_iv(): CPointer<Unit>
foreign func EVP_aead_aes_128_ccm_bluetooth(): CPointer<Unit>
foreign func EVP_aead_aes_128_ccm_bluetooth_8(): CPointer<Unit>
foreign func EVP_aead_aes_128_ccm_matter(): CPointer<Unit>
foreign func EVP_aead_aes_128_gcm_randnonce(): CPointer<Unit>
foreign func EVP_aead_aes_128_gcm_siv(): CPointer<Unit>
foreign func EVP_aead_aes_128_gcm_tls12(): CPointer<Unit>
foreign func EVP_aead_aes_128_gcm_tls13(): CPointer<Unit>
foreign func EVP_aead_aes_192_gcm(): CPointer<Unit>
foreign func EVP_aead_aes_256_cbc_sha1_tls(): CPointer<Unit>
foreign func EVP_aead_aes_256_cbc_sha1_tls_implicit_iv(): CPointer<Unit>
foreign func EVP_aead_aes_256_gcm_randnonce(): CPointer<Unit>
foreign func EVP_aead_aes_256_gcm_siv(): CPointer<Unit>
foreign func EVP_aead_aes_256_gcm_tls12(): CPointer<Unit>
foreign func EVP_aead_aes_256_gcm_tls13(): CPointer<Unit>
foreign func EVP_aead_des_ede3_cbc_sha1_tls(): CPointer<Unit>
foreign func EVP_aead_des_ede3_cbc_sha1_tls_implicit_iv(): CPointer<Unit>
foreign func EVP_aead_null_sha1_tls(): CPointer<Unit>
foreign func EVP_aead_xchacha20_poly1305(): CPointer<Unit>
foreign func EVP_AEAD_CTX_aead(ctx: CPointer<EvpAeadCtx>): CPointer<Unit>
foreign func EVP_AEAD_CTX_free(ctx: CPointer<EvpAeadCtx>): Unit
foreign func EVP_AEAD_CTX_get_iv(ctx: CPointer<EvpAeadCtx>, out_iv: CPointer<UInt8>, max_out: UIntNative): Int32
foreign func EVP_AEAD_CTX_init_with_direction(ctx: CPointer<EvpAeadCtx>, aead: CPointer<Unit>, key: CPointer<UInt8>, key_len: UIntNative, tag_len: UIntNative, direction: Int32): Int32
foreign func EVP_AEAD_CTX_new(): CPointer<EvpAeadCtx>
foreign func EVP_AEAD_CTX_open_gather(ctx: CPointer<EvpAeadCtx>, out: CPointer<UInt8>, out_len: CPointer<UIntNative>, max_out: UIntNative, nonce: CPointer<UInt8>, nonce_len: UIntNative, in_: CPointer<UInt8>, in_len: UIntNative, extra_in: CPointer<UInt8>, extra_in_len: UIntNative, ad: CPointer<UInt8>, ad_len: UIntNative): Int32
foreign func EVP_AEAD_CTX_seal_scatter(ctx: CPointer<EvpAeadCtx>, out: CPointer<UInt8>, out_tag: CPointer<UInt8>, out_len: CPointer<UIntNative>, max_out: UIntNative, out_tag_len: CPointer<UIntNative>, max_out_tag: UIntNative, nonce: CPointer<UInt8>, nonce_len: UIntNative, in_: CPointer<UInt8>, in_len: UIntNative, extra_in: CPointer<UInt8>, extra_in_len: UIntNative, ad: CPointer<UInt8>, ad_len: UIntNative): Int32
foreign func EVP_AEAD_CTX_tag_len(ctx: CPointer<EvpAeadCtx>): UIntNative
foreign func EVP_AEAD_CTX_zero(ctx: CPointer<EvpAeadCtx>): Unit

// --- EVP Cipher Context 补充 ---
foreign func EVP_CIPHER_CTX_block_size(ctx: CPointer<EvpCipherCtx>): Int32
foreign func EVP_CIPHER_CTX_cipher(ctx: CPointer<EvpCipherCtx>): CPointer<Unit>
foreign func EVP_CIPHER_CTX_cleanup(ctx: CPointer<EvpCipherCtx>): Int32
foreign func EVP_CIPHER_CTX_copy(out: CPointer<EvpCipherCtx>, in_: CPointer<EvpCipherCtx>): Int32
foreign func EVP_CIPHER_CTX_encrypting(ctx: CPointer<EvpCipherCtx>): Int32
foreign func EVP_CIPHER_CTX_flags(ctx: CPointer<EvpCipherCtx>): UInt32
foreign func EVP_CIPHER_CTX_get_app_data(ctx: CPointer<EvpCipherCtx>): CPointer<Unit>
foreign func EVP_CIPHER_CTX_init(ctx: CPointer<EvpCipherCtx>): Unit
foreign func EVP_CIPHER_CTX_mode(ctx: CPointer<EvpCipherCtx>): UInt32
foreign func EVP_CIPHER_CTX_nid(ctx: CPointer<EvpCipherCtx>): Int32
foreign func EVP_CIPHER_CTX_set_app_data(ctx: CPointer<EvpCipherCtx>, data: CPointer<Unit>): Unit
foreign func EVP_CIPHER_CTX_set_flags(ctx: CPointer<EvpCipherCtx>, flags: UInt32): Unit
foreign func EVP_CIPHER_do_all_sorted(fn_: CPointer<Unit>, arg: CPointer<Unit>): Unit
foreign func EVP_CIPHER_flags(cipher: CPointer<Unit>): UInt64
foreign func EVP_CIPHER_mode(cipher: CPointer<Unit>): UInt64

// --- EVP Encode/Decode ---
foreign func EVP_DecodeBase64(out: CPointer<UInt8>, out_len: CPointer<Int32>, max_out: Int32, in_: CPointer<UInt8>, in_len: UIntNative): Int32
foreign func EVP_DecodeBlock(out: CPointer<UInt8>, in_: CPointer<UInt8>, in_len: Int32): Int32
foreign func EVP_DecodedLength(out_len: CPointer<UIntNative>, max_out: UIntNative, in_len: UIntNative): Int32
foreign func EVP_DecodeFinal(ctx: CPointer<EvpEncodeCtx>, out: CPointer<UInt8>, outl: CPointer<Int32>): Int32
foreign func EVP_DecodeInit(ctx: CPointer<EvpEncodeCtx>): Unit
foreign func EVP_DecodeUpdate(ctx: CPointer<EvpEncodeCtx>, out: CPointer<UInt8>, outl: CPointer<Int32>, in_: CPointer<UInt8>, inl: Int32): Int32
foreign func EVP_EncodeBlock(out: CPointer<UInt8>, in_: CPointer<UInt8>, in_len: Int32): Int32
foreign func EVP_ENCODE_CTX_free(ctx: CPointer<EvpEncodeCtx>): Unit
foreign func EVP_ENCODE_CTX_new(): CPointer<EvpEncodeCtx>
foreign func EVP_EncodedLength(out_len: CPointer<UIntNative>, in_len: UIntNative): Int32
foreign func EVP_EncodeFinal(ctx: CPointer<EvpEncodeCtx>, out: CPointer<UInt8>, outl: CPointer<Int32>): Int32
foreign func EVP_EncodeInit(ctx: CPointer<EvpEncodeCtx>): Unit
foreign func EVP_EncodeUpdate(ctx: CPointer<EvpEncodeCtx>, out: CPointer<UInt8>, outl: CPointer<Int32>, in_: CPointer<UInt8>, inl: Int32): Int32

// --- EVP 高级别加密/解密 ---
foreign func EVP_Cipher(ctx: CPointer<EvpCipherCtx>, out: CPointer<UInt8>, in_: CPointer<UInt8>, inl: Int32): Int32
foreign func EVP_CipherFinal(ctx: CPointer<EvpCipherCtx>, out: CPointer<UInt8>, outl: CPointer<Int32>): Int32
foreign func EVP_CipherInit(ctx: CPointer<EvpCipherCtx>, cipher: CPointer<Unit>, key: CPointer<UInt8>, iv: CPointer<UInt8>, enc: Int32): Int32
foreign func EVP_DecryptFinal(ctx: CPointer<EvpCipherCtx>, out: CPointer<UInt8>, outl: CPointer<Int32>): Int32
foreign func EVP_DecryptInit(ctx: CPointer<EvpCipherCtx>, cipher: CPointer<Unit>, key: CPointer<UInt8>, iv: CPointer<UInt8>): Int32
foreign func EVP_EncryptFinal(ctx: CPointer<EvpCipherCtx>, out: CPointer<UInt8>, outl: CPointer<Int32>): Int32
foreign func EVP_EncryptInit(ctx: CPointer<EvpCipherCtx>, cipher: CPointer<Unit>, key: CPointer<UInt8>, iv: CPointer<UInt8>): Int32
foreign func EVP_BytesToKey(cipher: CPointer<Unit>, md: CPointer<Unit>, salt: CPointer<UInt8>, data: CPointer<UInt8>, datal: Int32, count: Int32, key: CPointer<UInt8>, iv: CPointer<UInt8>): Int32

// --- EVP MD Context 补充 ---
foreign func EVP_MD_CTX_block_size(ctx: CPointer<Unit>): Int32
foreign func EVP_MD_CTX_cleanse(ctx: CPointer<Unit>): Unit
foreign func EVP_MD_CTX_cleanup(ctx: CPointer<Unit>): Int32
foreign func EVP_MD_CTX_copy(out: CPointer<Unit>, in_: CPointer<Unit>): Int32
foreign func EVP_MD_CTX_create(): CPointer<Unit>
foreign func EVP_MD_CTX_destroy(ctx: CPointer<Unit>): Unit
foreign func EVP_MD_CTX_init(ctx: CPointer<Unit>): Unit
foreign func EVP_MD_CTX_md(ctx: CPointer<Unit>): CPointer<Unit>
foreign func EVP_MD_CTX_move(out: CPointer<Unit>, in_: CPointer<Unit>): Int32
foreign func EVP_MD_CTX_set_flags(ctx: CPointer<Unit>, flags: Int32): Unit
foreign func EVP_MD_CTX_size(ctx: CPointer<Unit>): Int32
foreign func EVP_MD_CTX_type(ctx: CPointer<Unit>): Int32
foreign func EVP_MD_do_all(fn_: CPointer<Unit>, arg: CPointer<Unit>): Unit
foreign func EVP_MD_do_all_sorted(fn_: CPointer<Unit>, arg: CPointer<Unit>): Unit
foreign func EVP_MD_meth_get_flags(md: CPointer<Unit>): UInt64

// --- EVP 签名/验签 (旧式) ---
foreign func EVP_SignFinal(ctx: CPointer<Unit>, sig: CPointer<UInt8>, sig_len: CPointer<UInt32>, pkey: CPointer<EvpPkeySt>): Int32
foreign func EVP_SignInit(ctx: CPointer<Unit>, type_: CPointer<Unit>): Int32
foreign func EVP_SignInit_ex(ctx: CPointer<Unit>, type_: CPointer<Unit>, engine: CPointer<Unit>): Int32
foreign func EVP_SignUpdate(ctx: CPointer<Unit>, data: CPointer<Unit>, count: UIntNative): Int32
foreign func EVP_VerifyFinal(ctx: CPointer<Unit>, sig: CPointer<UInt8>, sig_len: UInt32, pkey: CPointer<EvpPkeySt>): Int32
foreign func EVP_VerifyInit(ctx: CPointer<Unit>, type_: CPointer<Unit>): Int32
foreign func EVP_VerifyInit_ex(ctx: CPointer<Unit>, type_: CPointer<Unit>, engine: CPointer<Unit>): Int32
foreign func EVP_VerifyUpdate(ctx: CPointer<Unit>, data: CPointer<Unit>, count: UIntNative): Int32

// --- EVP PKEY 补充 ---
foreign func EVP_PKEY_assign(pkey: CPointer<EvpPkeySt>, type_: Int32, key: CPointer<Unit>): Int32
foreign func EVP_PKEY_base_id(pkey: CPointer<EvpPkeySt>): Int32
foreign func EVP_PKEY_cmp(a: CPointer<EvpPkeySt>, b: CPointer<EvpPkeySt>): Int32
foreign func EVP_PKEY_cmp_parameters(a: CPointer<EvpPkeySt>, b: CPointer<EvpPkeySt>): Int32
foreign func EVP_PKEY_CTX_dup(ctx: CPointer<Unit>): CPointer<Unit>
foreign func EVP_PKEY_CTX_get0_pkey(ctx: CPointer<Unit>): CPointer<EvpPkeySt>
foreign func EVP_PKEY_CTX_get0_rsa_oaep_label(ctx: CPointer<Unit>, out_len: CPointer<UIntNative>): CPointer<UInt8>
foreign func EVP_PKEY_CTX_get_rsa_mgf1_md(ctx: CPointer<Unit>): CPointer<Unit>
foreign func EVP_PKEY_CTX_get_rsa_oaep_md(ctx: CPointer<Unit>): CPointer<Unit>
foreign func EVP_PKEY_CTX_get_rsa_padding(ctx: CPointer<Unit>): Int32
foreign func EVP_PKEY_CTX_get_rsa_pss_saltlen(ctx: CPointer<Unit>): Int32
foreign func EVP_PKEY_CTX_get_signature_md(ctx: CPointer<Unit>): CPointer<Unit>
foreign func EVP_PKEY_CTX_set0_rsa_oaep_label(ctx: CPointer<Unit>, label: CPointer<UInt8>, len: UIntNative): Int32
foreign func EVP_PKEY_CTX_set_dsa_paramgen_bits(ctx: CPointer<Unit>, bits: UInt32): Int32
foreign func EVP_PKEY_CTX_set_dsa_paramgen_q_bits(ctx: CPointer<Unit>, q_bits: UInt32): Int32
foreign func EVP_PKEY_CTX_set_ec_param_enc(ctx: CPointer<Unit>, flag: Int32): Int32
foreign func EVP_PKEY_CTX_set_ec_paramgen_curve_nid(ctx: CPointer<Unit>, nid: Int32): Int32
foreign func EVP_PKEY_CTX_set_rsa_keygen_bits(ctx: CPointer<Unit>, bits: UInt32): Int32
foreign func EVP_PKEY_CTX_set_rsa_keygen_pubexp(ctx: CPointer<Unit>, pubexp: CPointer<BigNumSt>): Int32
foreign func EVP_PKEY_CTX_set_rsa_mgf1_md(ctx: CPointer<Unit>, md: CPointer<Unit>): Int32
foreign func EVP_PKEY_CTX_set_rsa_oaep_md(ctx: CPointer<Unit>, md: CPointer<Unit>): Int32
foreign func EVP_PKEY_CTX_set_rsa_padding(ctx: CPointer<Unit>, padding: Int32): Int32
foreign func EVP_PKEY_CTX_set_rsa_pss_keygen_md(ctx: CPointer<Unit>, md: CPointer<Unit>): Int32
foreign func EVP_PKEY_CTX_set_rsa_pss_keygen_mgf1_md(ctx: CPointer<Unit>, md: CPointer<Unit>): Int32
foreign func EVP_PKEY_CTX_set_rsa_pss_keygen_saltlen(ctx: CPointer<Unit>, salt_len: Int32): Int32
foreign func EVP_PKEY_CTX_set_rsa_pss_saltlen(ctx: CPointer<Unit>, salt_len: Int32): Int32
foreign func EVP_PKEY_CTX_set_signature_md(ctx: CPointer<Unit>, md: CPointer<Unit>): Int32
foreign func EVP_PKEY_decrypt(ctx: CPointer<Unit>, out: CPointer<UInt8>, out_len: CPointer<UIntNative>, in_: CPointer<UInt8>, in_len: UIntNative): Int32
foreign func EVP_PKEY_decrypt_init(ctx: CPointer<Unit>): Int32
foreign func EVP_PKEY_encrypt(ctx: CPointer<Unit>, out: CPointer<UInt8>, out_len: CPointer<UIntNative>, in_: CPointer<UInt8>, in_len: UIntNative): Int32
foreign func EVP_PKEY_encrypt_init(ctx: CPointer<Unit>): Int32
foreign func EVP_PKEY_get0(pkey: CPointer<EvpPkeySt>): CPointer<Unit>
foreign func EVP_PKEY_get1_DH(pkey: CPointer<EvpPkeySt>): CPointer<Unit>
foreign func EVP_PKEY_get1_DSA(pkey: CPointer<EvpPkeySt>): CPointer<DSA>
foreign func EVP_PKEY_get1_EC_KEY(pkey: CPointer<EvpPkeySt>): CPointer<Unit>
foreign func EVP_PKEY_get1_RSA(pkey: CPointer<EvpPkeySt>): CPointer<Unit>
foreign func EVP_PKEY_get1_tls_encodedpoint(pkey: CPointer<EvpPkeySt>, out: CPointer<CPointer<UInt8>>, out_len: CPointer<UIntNative>): Int32
foreign func EVP_PKEY_get_raw_private_key(pkey: CPointer<EvpPkeySt>, out: CPointer<UInt8>, out_len: CPointer<UIntNative>): Int32
foreign func EVP_PKEY_get_raw_public_key(pkey: CPointer<EvpPkeySt>, out: CPointer<UInt8>, out_len: CPointer<UIntNative>): Int32
foreign func EVP_PKEY_is_opaque(pkey: CPointer<EvpPkeySt>): Int32
foreign func EVP_PKEY_new_raw_private_key(type_: Int32, engine: CPointer<Unit>, priv_key: CPointer<UInt8>, len: UIntNative): CPointer<EvpPkeySt>
foreign func EVP_PKEY_new_raw_public_key(type_: Int32, engine: CPointer<Unit>, pub_key: CPointer<UInt8>, len: UIntNative): CPointer<EvpPkeySt>
foreign func EVP_PKEY_paramgen(ctx: CPointer<Unit>, ppkey: CPointer<CPointer<EvpPkeySt>>): Int32
foreign func EVP_PKEY_paramgen_init(ctx: CPointer<Unit>): Int32
foreign func EVP_PKEY_print_params(out: CPointer<Unit>, pkey: CPointer<EvpPkeySt>, indent: Int32, pctx: CPointer<Unit>): Int32
foreign func EVP_PKEY_print_private(out: CPointer<Unit>, pkey: CPointer<EvpPkeySt>, indent: Int32, pctx: CPointer<Unit>): Int32
foreign func EVP_PKEY_print_public(out: CPointer<Unit>, pkey: CPointer<EvpPkeySt>, indent: Int32, pctx: CPointer<Unit>): Int32
foreign func EVP_PKEY_set1_tls_encodedpoint(pkey: CPointer<EvpPkeySt>, points: CPointer<UInt8>, len: UIntNative): Int32
foreign func EVP_PKEY_set_type(pkey: CPointer<EvpPkeySt>, type_: Int32): Int32
foreign func EVP_PKEY_sign(ctx: CPointer<Unit>, sig: CPointer<UInt8>, sig_len: CPointer<UIntNative>, tbs: CPointer<UInt8>, tbs_len: UIntNative): Int32
foreign func EVP_PKEY_sign_init(ctx: CPointer<Unit>): Int32
foreign func EVP_PKEY_verify(ctx: CPointer<Unit>, sig: CPointer<UInt8>, sig_len: UIntNative, tbs: CPointer<UInt8>, tbs_len: UIntNative): Int32
foreign func EVP_PKEY_verify_init(ctx: CPointer<Unit>): Int32
foreign func EVP_PKEY_verify_recover(ctx: CPointer<Unit>, out: CPointer<UInt8>, out_len: CPointer<UIntNative>, sig: CPointer<UInt8>, sig_len: UIntNative): Int32
foreign func EVP_PKEY_verify_recover_init(ctx: CPointer<Unit>): Int32
foreign func EVP_marshal_digest_algorithm(cbb: CPointer<Unit>, md: CPointer<Unit>): Int32
foreign func EVP_marshal_private_key(cbb: CPointer<Unit>, key: CPointer<EvpPkeySt>): Int32
foreign func EVP_marshal_public_key(cbb: CPointer<Unit>, key: CPointer<EvpPkeySt>): Int32
foreign func EVP_parse_digest_algorithm(cbs: CPointer<CbsSt>): CPointer<Unit>
foreign func EVP_parse_private_key(cbs: CPointer<CbsSt>): CPointer<EvpPkeySt>
foreign func EVP_parse_public_key(cbs: CPointer<CbsSt>): CPointer<EvpPkeySt>
foreign func EVP_PKCS82PKEY(p8: CPointer<Unit>): CPointer<EvpPkeySt>
foreign func EVP_PKEY2PKCS8(pkey: CPointer<EvpPkeySt>): CPointer<Unit>

// --- RIPEMD160 ---
foreign func RIPEMD160(data: CPointer<UInt8>, len: UIntNative, out: CPointer<UInt8>): CPointer<UInt8>
foreign func RIPEMD160_Init(ctx: CPointer<Unit>): Int32
foreign func RIPEMD160_Update(ctx: CPointer<Unit>, data: CPointer<Unit>, len: UIntNative): Int32
foreign func RIPEMD160_Final(out: CPointer<UInt8>, ctx: CPointer<Unit>): Int32

// --- EVP_MAX_MD_SIZE ---
foreign func EVP_MAX_MD_SIZE(): UIntNative

// --- PKCS5 ---
foreign func PKCS5_PBKDF2_HMAC(password: CString, password_len: UIntNative, salt: CPointer<UInt8>, salt_len: UIntNative, iterations: UInt32, digest: CPointer<Unit>, key_len: UIntNative, out: CPointer<UInt8>): Int32
foreign func PKCS5_PBKDF2_HMAC_SHA1(password: CString, password_len: UIntNative, salt: CPointer<UInt8>, salt_len: UIntNative, iterations: UInt32, key_len: UIntNative, out: CPointer<UInt8>): Int32
foreign func EVP_PBE_scrypt(password: CString, password_len: UIntNative, salt: CPointer<UInt8>, salt_len: UIntNative, N: UInt64, r: UInt64, p: UInt64, max_mem: UInt64, out: CPointer<UInt8>, key_len: UIntNative): Int32
foreign func EVP_PBE_validate_scrypt_params(N: UInt64, r: UInt64, p: UInt64, max_mem: UInt64): Int32

// --- PKCS7 ---
foreign func PKCS7_bundle_certificates(certs: CPointer<Unit>): CPointer<Unit>
foreign func PKCS7_bundle_CRLs(crls: CPointer<Unit>): CPointer<Unit>
foreign func PKCS7_bundle_raw_certificates(certs: CPointer<Unit>): CPointer<Unit>
foreign func PKCS7_free(p7: CPointer<Unit>): Unit
foreign func PKCS7_get_certificates(p7: CPointer<Unit>): CPointer<Unit>
foreign func PKCS7_get_CRLs(p7: CPointer<Unit>): CPointer<Unit>
foreign func PKCS7_get_PEM_certificates(p7: CPointer<Unit>): CPointer<Unit>
foreign func PKCS7_get_PEM_CRLs(p7: CPointer<Unit>): CPointer<Unit>
foreign func PKCS7_get_raw_certificates(p7: CPointer<Unit>): CPointer<Unit>
foreign func PKCS7_sign(sign_cert: CPointer<Unit>, pkey: CPointer<EvpPkeySt>, certs: CPointer<Unit>, data: CPointer<Unit>, flags: Int32): CPointer<Unit>
foreign func PKCS7_type_is_data(p7: CPointer<Unit>): Int32
foreign func PKCS7_type_is_digest(p7: CPointer<Unit>): Int32
foreign func PKCS7_type_is_encrypted(p7: CPointer<Unit>): Int32
foreign func PKCS7_type_is_enveloped(p7: CPointer<Unit>): Int32
foreign func PKCS7_type_is_signed(p7: CPointer<Unit>): Int32
foreign func PKCS7_type_is_signedAndEnveloped(p7: CPointer<Unit>): Int32

// --- PKCS8 ---
foreign func PKCS8_PRIV_KEY_INFO_free(p8: CPointer<Unit>): Unit
foreign func PKCS8_PRIV_KEY_INFO_new(): CPointer<Unit>
