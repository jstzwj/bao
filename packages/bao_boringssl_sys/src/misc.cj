// 严格翻译自: src/boringssl_sys/boringssl.zig
package bao_boringssl_sys

// ============================================================================
// BoringSSL 额外 BIO, PEM, OPENSSL, FIPS, HMAC, CRYPTO, OBJ, SHA FFI 函数声明
// 严格翻译自: boringssl.zig 中补充的 BIO_*, PEM_*, OPENSSL_*, FIPS_*, HMAC_CTX_*,
//   CRYPTO_BUFFER_*, CRYPTO_*, OBJ_*, SHA*_Transform, SHA512_256*, ERR_print* 函数
// ============================================================================

// --- BIO 补充 ---
foreign func BIO_copy_next_retry(bio: CPointer<Unit>): Unit
foreign func BIO_f_base64(): CPointer<BioMethodSt>
foreign func BIO_find_type(bio: CPointer<Unit>, type_: Int32): CPointer<Unit>
foreign func BIO_free_all(bio: CPointer<Unit>): Unit
foreign func BIO_get_data(bio: CPointer<Unit>): CPointer<Unit>
foreign func BIO_get_init(bio: CPointer<Unit>): Int32
foreign func BIO_get_mem_data(bio: CPointer<Unit>): CPointer<CPointer<BufMem>>
foreign func BIO_get_new_index(): Int32
foreign func BIO_get_shutdown(bio: CPointer<Unit>): Int32
foreign func BIO_hexdump(bio: CPointer<Unit>, data: CPointer<Unit>, len: UIntNative, indent: UInt32): Int32
foreign func BIO_indent(bio: CPointer<Unit>, indent: UInt32, max: UInt32): Int32
foreign func BIO_meth_new(type_: Int32, name: CString): CPointer<BioMethodSt>
foreign func BIO_meth_free(biom: CPointer<BioMethodSt>): Unit
foreign func BIO_meth_set_create(biom: CPointer<BioMethodSt>, create: CPointer<Unit>): Int32
foreign func BIO_meth_set_ctrl(biom: CPointer<BioMethodSt>, ctrl: CPointer<Unit>): Int32
foreign func BIO_meth_set_destroy(biom: CPointer<BioMethodSt>, destroy: CPointer<Unit>): Int32
foreign func BIO_meth_set_gets(biom: CPointer<BioMethodSt>, gets: CPointer<Unit>): Int32
foreign func BIO_meth_set_puts(biom: CPointer<BioMethodSt>, puts: CPointer<Unit>): Int32
foreign func BIO_meth_set_read(biom: CPointer<BioMethodSt>, read: CPointer<Unit>): Int32
foreign func BIO_meth_set_write(biom: CPointer<BioMethodSt>, write: CPointer<Unit>): Int32
foreign func BIO_next(bio: CPointer<Unit>): CPointer<Unit>
foreign func BIO_number_read(bio: CPointer<Unit>): UInt64
foreign func BIO_number_written(bio: CPointer<Unit>): UInt64
foreign func BIO_pop(bio: CPointer<Unit>): CPointer<Unit>
foreign func BIO_printf(bio: CPointer<Unit>, format: CString): Int32
foreign func BIO_push(bio: CPointer<Unit>, append: CPointer<Unit>): CPointer<Unit>
foreign func BIO_read_asn1(bio: CPointer<Unit>, out: CPointer<CPointer<Unit>>, out_len: CPointer<UIntNative>, max_len: UIntNative): Int32
foreign func BIO_set_data(bio: CPointer<Unit>, data: CPointer<Unit>): Unit
foreign func BIO_set_fd(bio: CPointer<Unit>, fd: Int32, close_flag: Int32): Int64
foreign func BIO_set_init(bio: CPointer<Unit>, `init`: Int32): Unit
foreign func BIO_set_retry_special(bio: CPointer<Unit>): Unit
foreign func BIO_set_shutdown(bio: CPointer<Unit>, shutdown: Int32): Unit
foreign func BIO_set_write_buffer_size(bio: CPointer<Unit>, size: UIntNative): Int64
foreign func BIO_s_fd(): CPointer<BioMethodSt>

// --- PEM 补充 ---
foreign func PEM_ASN1_read_bio(d2i: CPointer<Unit>, name: CString, bp: CPointer<Unit>, x: CPointer<CPointer<Unit>>, cb: CPointer<Unit>, u: CPointer<Unit>): CPointer<Unit>
foreign func PEM_ASN1_write_bio(i2d: CPointer<Unit>, name: CString, bp: CPointer<Unit>, x: CPointer<Unit>, enc: CPointer<Unit>, kstr: CPointer<UInt8>, klen: Int32, cb: CPointer<Unit>, u: CPointer<Unit>): Int32
foreign func PEM_bytes_read_bio(pdata: CPointer<CPointer<UInt8>>, plen: CPointer<UIntNative>, pnm: CPointer<CPointer<CString>>, name: CString, bp: CPointer<Unit>, cb: CPointer<Unit>, u: CPointer<Unit>): Int32
foreign func PEM_def_callback(buf: CPointer<UInt8>, size: Int32, rwflag: Int32, userdata: CPointer<Unit>): Int32
foreign func PEM_dek_info(buf: CPointer<UInt8>, type_: CString, len: Int32, str: CPointer<UInt8>): Unit
foreign func PEM_do_header(cipher: CPointer<EvpCipherInfo>, data: CPointer<CPointer<UInt8>>, plen: CPointer<UIntNative>, cb: CPointer<Unit>, u: CPointer<Unit>): Int32
foreign func PEM_get_EVP_CIPHER_INFO(header: CPointer<UInt8>, cipher: CPointer<EvpCipherInfo>): Int32
foreign func PEM_proc_type(buf: CPointer<UInt8>, type_: Int32): Unit
foreign func PEM_read_bio(bp: CPointer<Unit>, name: CPointer<CString>, header: CPointer<CPointer<UInt8>>, data: CPointer<CPointer<UInt8>>): Int32
foreign func PEM_write_bio(bp: CPointer<Unit>, name: CString, header: CString, data: CPointer<UInt8>, len: UIntNative): Int32
foreign func PEM_read_bio_DSAparams(bp: CPointer<Unit>, x: CPointer<CPointer<Unit>>, cb: CPointer<Unit>, u: CPointer<Unit>): CPointer<Unit>
foreign func PEM_write_bio_DSAparams(bp: CPointer<Unit>, x: CPointer<Unit>): Int32
foreign func PEM_read_bio_DSAPrivateKey(bp: CPointer<Unit>, x: CPointer<CPointer<Unit>>, cb: CPointer<Unit>, u: CPointer<Unit>): CPointer<Unit>
foreign func PEM_write_bio_DSAPrivateKey(bp: CPointer<Unit>, x: CPointer<Unit>, enc: CPointer<Unit>, kstr: CPointer<UInt8>, klen: Int32, cb: CPointer<Unit>, u: CPointer<Unit>): Int32
foreign func PEM_read_bio_DSA_PUBKEY(bp: CPointer<Unit>, x: CPointer<CPointer<Unit>>, cb: CPointer<Unit>, u: CPointer<Unit>): CPointer<Unit>
foreign func PEM_write_bio_DSA_PUBKEY(bp: CPointer<Unit>, x: CPointer<Unit>): Int32
foreign func PEM_read_bio_EC_PUBKEY(bp: CPointer<Unit>, x: CPointer<CPointer<Unit>>, cb: CPointer<Unit>, u: CPointer<Unit>): CPointer<Unit>
foreign func PEM_write_bio_EC_PUBKEY(bp: CPointer<Unit>, x: CPointer<Unit>): Int32
foreign func PEM_read_bio_PKCS8_PRIV_KEY_INFO(bp: CPointer<Unit>, x: CPointer<CPointer<Unit>>, cb: CPointer<Unit>, u: CPointer<Unit>): CPointer<Unit>
foreign func PEM_write_bio_PKCS8_PRIV_KEY_INFO(bp: CPointer<Unit>, x: CPointer<Unit>): Int32
foreign func PEM_read_bio_RSA_PUBKEY(bp: CPointer<Unit>, x: CPointer<CPointer<Unit>>, cb: CPointer<Unit>, u: CPointer<Unit>): CPointer<Unit>
foreign func PEM_write_bio_RSA_PUBKEY(bp: CPointer<Unit>, x: CPointer<Unit>): Int32
foreign func PEM_read_bio_RSAPublicKey(bp: CPointer<Unit>, x: CPointer<CPointer<Unit>>, cb: CPointer<Unit>, u: CPointer<Unit>): CPointer<Unit>
foreign func PEM_write_bio_RSAPublicKey(bp: CPointer<Unit>, x: CPointer<Unit>): Int32
foreign func PEM_read_bio_SSL_SESSION(bp: CPointer<Unit>, x: CPointer<CPointer<Unit>>, cb: CPointer<Unit>, u: CPointer<Unit>): CPointer<Unit>
foreign func PEM_write_bio_SSL_SESSION(bp: CPointer<Unit>, x: CPointer<Unit>): Int32
foreign func PEM_read_bio_X509_CRL(bp: CPointer<Unit>, x: CPointer<CPointer<Unit>>, cb: CPointer<Unit>, u: CPointer<Unit>): CPointer<Unit>
foreign func PEM_write_bio_X509_REQ_NEW(bp: CPointer<Unit>, x: CPointer<Unit>): Int32
foreign func PEM_write_bio_PKCS8(bp: CPointer<Unit>, x: CPointer<EvpPkeySt>): Int32
foreign func PEM_write_bio_PKCS8PrivateKey_nid(bp: CPointer<Unit>, x: CPointer<EvpPkeySt>, nid: Int32, kstr: CPointer<UInt8>, klen: Int32, cb: CPointer<Unit>, u: CPointer<Unit>): Int32
foreign func PEM_X509_INFO_read_bio(bp: CPointer<Unit>, sk: CPointer<Unit>, cb: CPointer<Unit>, u: CPointer<Unit>): CPointer<Unit>

// --- OPENSSL 工具函数 ---
foreign func OPENSSL_add_all_algorithms_conf(): Unit
foreign func OPENSSL_cleanse(ptr: CPointer<Unit>, len: UIntNative): Unit
foreign func OPENSSL_cleanup(): Unit
foreign func OPENSSL_clear_free(ptr: CPointer<Unit>, len: UIntNative): Unit
foreign func OPENSSL_free(ptr: CPointer<Unit>): Unit
foreign func OPENSSL_hash32(buf: CPointer<Unit>, len: UIntNative): UInt32
foreign func OPENSSL_load_builtin_modules(): Unit
foreign func OPENSSL_malloc(size: UIntNative): CPointer<Unit>
foreign func OPENSSL_malloc_init(): Int32
foreign func OPENSSL_memdup(data: CPointer<Unit>, size: UIntNative): CPointer<Unit>
foreign func OPENSSL_realloc(ptr: CPointer<Unit>, size: UIntNative): CPointer<Unit>
foreign func OPENSSL_secure_clear_free(ptr: CPointer<Unit>, size: UIntNative): Unit
foreign func OPENSSL_secure_malloc(size: UIntNative): CPointer<Unit>
foreign func OPENSSL_strcasecmp(a: CString, b: CString): Int32
foreign func OPENSSL_strdup(str: CString): CString
foreign func OPENSSL_strhash(str: CString): UInt32
foreign func OPENSSL_strlcat(dst: CPointer<UInt8>, src: CString, dst_size: UIntNative): UIntNative
foreign func OPENSSL_strlcpy(dst: CPointer<UInt8>, src: CString, dst_size: UIntNative): UIntNative
foreign func OPENSSL_strncasecmp(a: CString, b: CString, n: UIntNative): Int32
foreign func OPENSSL_strndup(str: CString, size: UIntNative): CString
foreign func OPENSSL_strnlen(str: CString, maxlen: UIntNative): UIntNative
foreign func OPENSSL_tolower(c: Int32): Int32
foreign func OpenSSL_add_all_algorithms(): Unit
foreign func OpenSSL_add_all_ciphers(): Unit
foreign func OpenSSL_add_all_digests(): Unit
foreign func OpenSSL_version(type_: Int32): CString
foreign func OpenSSL_version_num(): UInt64

// --- FIPS ---
foreign func FIPS_mode(): Int32
foreign func FIPS_mode_set(onoff: Int32): Int32
foreign func FIPS_module_name(): CString
foreign func FIPS_query_algorithm_status(algorithm: CString): Int32
foreign func FIPS_read_counter(counter: Int32): UInt64
foreign func FIPS_version(): Int32

// --- HMAC_CTX 补充 ---
foreign func HMAC_CTX_cleanse(ctx: CPointer<HmacCtxSt>): Unit
foreign func HMAC_CTX_copy_ex(dst: CPointer<HmacCtxSt>, src: CPointer<HmacCtxSt>): Int32
foreign func HMAC_CTX_free(ctx: CPointer<HmacCtxSt>): Unit
foreign func HMAC_CTX_get_md(ctx: CPointer<HmacCtxSt>): CPointer<Unit>
foreign func HMAC_CTX_new(): CPointer<HmacCtxSt>
foreign func HMAC_Init(ctx: CPointer<HmacCtxSt>, key: CPointer<Unit>, len: UIntNative, md: CPointer<Unit>): Int32
foreign func HMAC_size(evp_md: CPointer<Unit>): UIntNative

// --- CRYPTO_BUFFER ---
foreign func CRYPTO_BUFFER_alloc(out: CPointer<CPointer<Unit>>, len: UIntNative): Int32
foreign func CRYPTO_BUFFER_data(buf: CPointer<Unit>): CPointer<UInt8>
foreign func CRYPTO_BUFFER_free(buf: CPointer<Unit>): Unit
foreign func CRYPTO_BUFFER_init_CBS(buf: CPointer<Unit>, cbs: CPointer<CbsSt>): Unit
foreign func CRYPTO_BUFFER_len(buf: CPointer<Unit>): UIntNative
foreign func CRYPTO_BUFFER_new(data: CPointer<UInt8>, len: UIntNative, pool: CPointer<Unit>): CPointer<Unit>
foreign func CRYPTO_BUFFER_new_from_CBS(cbs: CPointer<CbsSt>, pool: CPointer<Unit>): CPointer<Unit>
foreign func CRYPTO_BUFFER_new_from_static_data_unsafe(data: CPointer<Unit>, len: UIntNative, pool: CPointer<Unit>): CPointer<Unit>
foreign func CRYPTO_BUFFER_POOL_free(pool: CPointer<Unit>): Unit
foreign func CRYPTO_BUFFER_POOL_new(): CPointer<Unit>
foreign func CRYPTO_BUFFER_up_ref(buf: CPointer<Unit>): Unit

// --- CRYPTO 补充 ---
foreign func CRYPTO_get_dynlock_create_callback(): CPointer<Unit>
foreign func CRYPTO_get_dynlock_destroy_callback(): CPointer<Unit>
foreign func CRYPTO_get_dynlock_lock_callback(): CPointer<Unit>
foreign func CRYPTO_get_locking_callback(): CPointer<Unit>
foreign func CRYPTO_get_lock_name(lock_num: Int32): CString
foreign func CRYPTO_has_asm(): Int32
foreign func CRYPTO_is_confidential_build(): Int32
foreign func CRYPTO_library_init(): Int32
foreign func CRYPTO_malloc_init(): Int32
foreign func CRYPTO_memcmp(a: CPointer<Unit>, b: CPointer<Unit>, len: UIntNative): Int32
foreign func CRYPTO_pre_sandbox_init(): Unit
foreign func CRYPTO_secure_malloc_init(fd: Int32, size: UIntNative): Int32
foreign func CRYPTO_secure_malloc_initialized(): Int32
foreign func CRYPTO_secure_used(): UIntNative
foreign func CRYPTO_set_locking_callback(`func`: CPointer<Unit>): Unit
foreign func CRYPTO_set_add_lock_callback(`func`: CPointer<Unit>): Unit
foreign func CRYPTO_set_dynlock_create_callback(`func`: CPointer<Unit>): Unit
foreign func CRYPTO_set_dynlock_destroy_callback(`func`: CPointer<Unit>): Unit
foreign func CRYPTO_set_dynlock_lock_callback(`func`: CPointer<Unit>): Unit

// --- OBJ 补充 ---
foreign func OBJ_cbs2nid(cbs: CPointer<CbsSt>): Int32
foreign func OBJ_cleanup(): Unit
foreign func OBJ_create(oid: CString, sn: CString, ln: CString): Int32
foreign func OBJ_dup(o: CPointer<Unit>): CPointer<Unit>
foreign func OBJ_find_sigid_algs(signid: Int32, pdig_nid: CPointer<Int32>, ppkey_nid: CPointer<Int32>): Int32
foreign func OBJ_find_sigid_by_algs(psignid: CPointer<Int32>, dig_nid: Int32, pkey_nid: Int32): Int32
foreign func OBJ_get0_data(obj: CPointer<Unit>): CPointer<UInt8>
foreign func OBJ_length(obj: CPointer<Unit>): Int32
foreign func OBJ_NAME_do_all(type_: Int32, fn_: CPointer<Unit>, arg: CPointer<Unit>): Unit
foreign func OBJ_NAME_do_all_sorted(type_: Int32, fn_: CPointer<Unit>, arg: CPointer<Unit>): Unit
foreign func OBJ_nid2cbb(cbb: CPointer<Unit>, nid: Int32): Int32
foreign func OBJ_obj2txt(buf: CPointer<UInt8>, buf_len: Int32, a: CPointer<Unit>, no_name: Int32): Int32
foreign func OBJ_txt2obj(s: CString, no_name: Int32): CPointer<Unit>

// --- ERR 补充 ---
foreign func ERR_print_errors(bio: CPointer<Unit>): Unit

// --- SHA 补充 ---
foreign func SHA1_Transform(sha: CPointer<ShaCtx>, data: CPointer<UInt8>): Unit
foreign func SHA224_Init(sha: CPointer<Sha256Ctx>): Int32
foreign func SHA224_Update(sha: CPointer<Sha256Ctx>, data: CPointer<Unit>, len: UIntNative): Int32
foreign func SHA224_Final(out: CPointer<UInt8>, sha: CPointer<Sha256Ctx>): Int32
foreign func SHA256_Transform(sha: CPointer<Sha256Ctx>, data: CPointer<UInt8>): Unit
foreign func SHA256_TransformBlocks(sha: CPointer<Sha256Ctx>, data: CPointer<UInt8>, num_blocks: UIntNative): Unit
foreign func SHA512_Transform(sha: CPointer<Sha512Ctx>, data: CPointer<UInt8>): Unit
foreign func SHA512_256(data: CPointer<UInt8>, len: UIntNative, out: CPointer<UInt8>): CPointer<UInt8>
foreign func SHA512_256_Init(sha: CPointer<Sha512Ctx>): Int32
foreign func SHA512_256_Update(sha: CPointer<Sha512Ctx>, data: CPointer<Unit>, len: UIntNative): Int32
foreign func SHA512_256_Final(out: CPointer<UInt8>, sha: CPointer<Sha512Ctx>): Int32

// --- METHOD_ref / METHOD_unref ---
foreign func METHOD_ref(method: CPointer<Unit>, method_size: UIntNative): Unit
foreign func METHOD_unref(method: CPointer<Unit>, method_size: UIntNative): Unit

// --- BoringSSL 自测试 ---
foreign func BORINGSSL_integrity_test(): Int32
foreign func BORINGSSL_self_test(): Int32
