// 严格翻译自: src/boringssl_sys/boringssl.zig
package bao_boringssl_sys

// ============================================================================
// BoringSSL BUF/ERR/SK/CRYPTO/BIO FFI 函数声明
// 严格翻译自: boringssl.zig 中 BUF_*, ERR_*, sk_*, CRYPTO_*, BIO_* 函数
// ============================================================================

// --- BUF 函数 ---
foreign func BUF_MEM_new(): CPointer<BufMem>
foreign func BUF_MEM_free(buf: CPointer<BufMem>): Unit
foreign func BUF_MEM_reserve(buf: CPointer<BufMem>, cap: UIntNative): Int32
foreign func BUF_MEM_grow(buf: CPointer<BufMem>, len: UIntNative): UIntNative
foreign func BUF_MEM_grow_clean(buf: CPointer<BufMem>, len: UIntNative): UIntNative
foreign func BUF_MEM_append(buf: CPointer<BufMem>, input: CPointer<Unit>, len: UIntNative): Int32
foreign func BUF_strdup(str: CString): CPointer<UInt8>
foreign func BUF_strnlen(str: CString, max_len: UIntNative): UIntNative
foreign func BUF_strndup(str: CString, size: UIntNative): CPointer<UInt8>
foreign func BUF_memdup(data: CPointer<Unit>, size: UIntNative): CPointer<Unit>
foreign func BUF_strlcpy(dst: CPointer<UInt8>, src: CString, dst_size: UIntNative): UIntNative
foreign func BUF_strlcat(dst: CPointer<UInt8>, src: CString, dst_size: UIntNative): UIntNative

// --- ERR 函数 ---
foreign func ERR_load_BIO_strings(): Unit
foreign func ERR_load_ERR_strings(): Unit
foreign func ERR_load_crypto_strings(): Unit
foreign func ERR_load_RAND_strings(): Unit
foreign func ERR_free_strings(): Unit
foreign func ERR_get_error(): UInt32
foreign func ERR_peek_error(): UInt32
foreign func ERR_peek_last_error(): UInt32
foreign func ERR_error_string_n(packed_error: UInt32, buf: CPointer<UInt8>, len: UIntNative): CPointer<UInt8>
foreign func ERR_lib_error_string(packed_error: UInt32): CString
foreign func ERR_reason_error_string(packed_error: UInt32): CString
foreign func ERR_remove_state(pid: UInt64): Unit
foreign func ERR_remove_thread_state(tid: CPointer<Int32>): Unit
foreign func ERR_func_error_string(packed_error: UInt32): CString
foreign func ERR_error_string(packed_error: UInt32, buf: CPointer<UInt8>): CPointer<UInt8>
foreign func ERR_clear_system_error(): Unit
foreign func ERR_put_error(library: Int32, unused: Int32, reason: Int32, file: CString, line: UInt32): Unit
foreign func ERR_add_error_data(count: UInt32, ...): Unit
foreign func ERR_add_error_dataf(format: CString, ...): Unit
foreign func ERR_set_error_data(data: CPointer<UInt8>, flags: Int32): Unit
foreign func ERR_clear_error(): Unit
foreign func ERR_set_mark(): Int32
foreign func ERR_pop_to_mark(): Int32
foreign func ERR_get_next_error_library(): Int32

// --- sk (stack) 函数 ---
foreign func sk_new(comp: CPointer<Unit>): CPointer<Unit>
foreign func sk_new_null(): CPointer<Unit>
foreign func sk_num(sk: CPointer<Unit>): UIntNative
foreign func sk_zero(sk: CPointer<Unit>): Unit
foreign func sk_value(sk: CPointer<Unit>, i: UIntNative): CPointer<Unit>
foreign func sk_set(sk: CPointer<Unit>, i: UIntNative, p: CPointer<Unit>): CPointer<Unit>
foreign func sk_free(sk: CPointer<Unit>): Unit
foreign func sk_pop_free_ex(sk: CPointer<Unit>, call_free_func: CPointer<Unit>, free_func: CPointer<Unit>): Unit
foreign func sk_insert(sk: CPointer<Unit>, p: CPointer<Unit>, where_: UIntNative): UIntNative
foreign func sk_delete(sk: CPointer<Unit>, where_: UIntNative): CPointer<Unit>
foreign func sk_delete_ptr(sk: CPointer<Unit>, p: CPointer<Unit>): CPointer<Unit>
foreign func sk_find(sk: CPointer<Unit>, out_index: CPointer<UIntNative>, p: CPointer<Unit>, call_cmp_func: CPointer<Unit>): Int32
foreign func sk_shift(sk: CPointer<Unit>): CPointer<Unit>
foreign func sk_push(sk: CPointer<Unit>, p: CPointer<Unit>): UIntNative
foreign func sk_pop(sk: CPointer<Unit>): CPointer<Unit>
foreign func sk_dup(sk: CPointer<Unit>): CPointer<Unit>
foreign func sk_sort(sk: CPointer<Unit>, call_cmp_func: CPointer<Unit>): Unit
foreign func sk_is_sorted(sk: CPointer<Unit>): Int32
foreign func sk_set_cmp_func(sk: CPointer<Unit>, comp: CPointer<Unit>): CPointer<Unit>
foreign func sk_deep_copy(sk: CPointer<Unit>, call_copy_func: CPointer<Unit>, copy_func: CPointer<Unit>, call_free_func: CPointer<Unit>, free_func: CPointer<Unit>): CPointer<Unit>
foreign func sk_pop_free(sk: CPointer<Unit>, free_func: CPointer<Unit>): Unit

// --- CRYPTO 函数 ---
foreign func CRYPTO_cleanup_all_ex_data(): Unit
foreign func CRYPTO_num_locks(): Int32
foreign func CRYPTO_THREADID_set_callback(threadid_func: CPointer<Unit>): Int32
foreign func CRYPTO_THREADID_set_numeric(id: CPointer<Int32>, val: UInt64): Unit
foreign func CRYPTO_THREADID_set_pointer(id: CPointer<Int32>, ptr: CPointer<Unit>): Unit
foreign func CRYPTO_THREADID_current(id: CPointer<Int32>): Unit
foreign func CRYPTO_set_id_callback(`func`: CPointer<Unit>): Unit

// --- BIO 函数 ---
foreign func BIO_new(method: CPointer<BioMethodSt>): CPointer<Unit>
foreign func BIO_free(bio: CPointer<Unit>): Int32
foreign func BIO_vfree(bio: CPointer<Unit>): Unit
foreign func BIO_up_ref(bio: CPointer<Unit>): Int32
foreign func BIO_read(bio: CPointer<Unit>, data: CPointer<Unit>, len: Int32): Int32
foreign func BIO_gets(bio: CPointer<Unit>, buf: CPointer<UInt8>, size: Int32): Int32
foreign func BIO_write(bio: CPointer<Unit>, data: CPointer<Unit>, len: Int32): Int32
foreign func BIO_write_all(bio: CPointer<Unit>, data: CPointer<Unit>, len: UIntNative): Int32
foreign func BIO_puts(bio: CPointer<Unit>, buf: CString): Int32
foreign func BIO_flush(bio: CPointer<Unit>): Int32
foreign func BIO_ctrl(bio: CPointer<Unit>, cmd: Int32, larg: Int64, parg: CPointer<Unit>): Int64
foreign func BIO_ptr_ctrl(bp: CPointer<Unit>, cmd: Int32, larg: Int64): CPointer<UInt8>
foreign func BIO_int_ctrl(bp: CPointer<Unit>, cmd: Int32, larg: Int64, iarg: Int32): Int64
foreign func BIO_reset(bio: CPointer<Unit>): Int32
foreign func BIO_eof(bio: CPointer<Unit>): Int32
foreign func BIO_set_flags(bio: CPointer<Unit>, flags: Int32): Unit
foreign func BIO_test_flags(bio: CPointer<Unit>, flags: Int32): Int32
foreign func BIO_should_read(bio: CPointer<Unit>): Int32
foreign func BIO_should_write(bio: CPointer<Unit>): Int32
foreign func BIO_should_retry(bio: CPointer<Unit>): Int32
foreign func BIO_should_io_special(bio: CPointer<Unit>): Int32
foreign func BIO_get_retry_reason(bio: CPointer<Unit>): Int32
foreign func BIO_set_retry_reason(bio: CPointer<Unit>, reason: Int32): Unit
foreign func BIO_clear_flags(bio: CPointer<Unit>, flags: Int32): Unit
foreign func BIO_set_retry_read(bio: CPointer<Unit>): Unit
foreign func BIO_set_retry_write(bio: CPointer<Unit>): Unit
foreign func BIO_get_retry_flags(bio: CPointer<Unit>): Int32
foreign func BIO_clear_retry_flags(bio: CPointer<Unit>): Unit
foreign func BIO_method_type(bio: CPointer<Unit>): Int32
foreign func BIO_callback_ctrl(bio: CPointer<Unit>, cmd: Int32, fp: CPointer<Unit>): Int64
foreign func BIO_new_mem_buf(buf: CPointer<Unit>, len: Int32): CPointer<Unit>
foreign func BIO_s_file(): CPointer<BioMethodSt>
foreign func BIO_new_file(filename: CString, mode: CString): CPointer<Unit>
foreign func BIO_new_fp(stream: CPointer<Unit>, close_flag: Int32): CPointer<Unit>
foreign func BIO_s_mem(): CPointer<BioMethodSt>
foreign func BIO_s_socket(): CPointer<BioMethodSt>
foreign func BIO_new_socket(sock: Int32, close_flag: Int32): CPointer<Unit>
foreign func BIO_new_connect(host: CString): CPointer<Unit>
foreign func BIO_new_accept(host: CString): CPointer<Unit>
foreign func BIO_new_fd(fd: Int32, close_flag: Int32): CPointer<Unit>
foreign func BIO_new_bio_pair(bio1: CPointer<CPointer<Unit>>, writebuf1: UIntNative, bio2: CPointer<CPointer<Unit>>, writebuf2: UIntNative): Int32
foreign func BIO_set_bio(bio: CPointer<Unit>, accepted: CPointer<Unit>, chain: CPointer<Unit>): Unit
foreign func BIO_set_nbio(bio: CPointer<Unit>, n: Int32): Int64
foreign func BIO_get_fd(bio: CPointer<Unit>, fd: CPointer<Int32>): Int64
foreign func BIO_get_mem_ptr(bio: CPointer<Unit>, ptr: CPointer<CPointer<BufMem>>): Int64
foreign func BIO_set_mem_buf(bio: CPointer<Unit>, b: CPointer<BufMem>, c: Int32): Int64
foreign func BIO_set_mem_eof_return(bio: CPointer<Unit>, v: Int32): Int64
foreign func BIO_set_close(bio: CPointer<Unit>, close_flag: Int64): Int64
foreign func BIO_get_close(bio: CPointer<Unit>): Int64
foreign func BIO_pending(bio: CPointer<Unit>): Int32
foreign func BIO_ctrl_pending(bio: CPointer<Unit>): UIntNative
foreign func BIO_wpending(bio: CPointer<Unit>): Int32
foreign func BIO_get_info_callback(bio: CPointer<Unit>, cb: CPointer<Unit>): Int64
foreign func BIO_set_info_callback(bio: CPointer<Unit>, cb: CPointer<Unit>): Int64
foreign func BIO_snprintf(buf: CPointer<UInt8>, n: UIntNative, format: CString, ...): Int32
foreign func BIO_vsnprintf(buf: CPointer<UInt8>, n: UIntNative, format: CString, args: CPointer<Unit>): Int32
foreign func BIO_read_filename(bio: CPointer<Unit>, filename: CString): Int32
foreign func BIO_write_filename(bio: CPointer<Unit>, filename: CString): Int32
foreign func BIO_append_filename(bio: CPointer<Unit>, filename: CString): Int32
foreign func BIO_rw_filename(bio: CPointer<Unit>, filename: CString): Int32
foreign func BIO_sock_error(): Int32
foreign func BIO_sock_non_fatal_error(): Int32
foreign func BIO_socket_ioctl(fd: Int32, cmd: UInt64, argp: CPointer<Unit>): Int32
foreign func BIO_set_tcp_ndelay(fd: Int32, turn_on: Int32): Int32

// --- EVP 摘要函数 ---
foreign func EVP_md4(): CPointer<Unit>
foreign func EVP_md5(): CPointer<Unit>
foreign func EVP_sha1(): CPointer<Unit>
foreign func EVP_sha224(): CPointer<Unit>
foreign func EVP_sha256(): CPointer<Unit>
foreign func EVP_sha384(): CPointer<Unit>
foreign func EVP_sha512(): CPointer<Unit>
foreign func EVP_sha512_224(): CPointer<Unit>
foreign func EVP_sha512_256(): CPointer<Unit>
foreign func EVP_sha3_224(): CPointer<Unit>
foreign func EVP_sha3_256(): CPointer<Unit>
foreign func EVP_sha3_384(): CPointer<Unit>
foreign func EVP_sha3_512(): CPointer<Unit>
foreign func EVP_blake2b256(): CPointer<Unit>
foreign func EVP_blake2b512(): CPointer<Unit>

// --- RAND 函数 ---
foreign func RAND_bytes(buf: CPointer<UInt8>, len: UIntNative): Int32
foreign func RAND_enable_fork_unsafe_buffering(fd: Int32): Unit

// --- OpenSSL 初始化 ---
foreign func OPENSSL_init_ssl(opts: UInt64, settings: CPointer<Unit>): Int32
foreign func OPENSSL_init_crypto(opts: UInt64, settings: CPointer<Unit>): Int32

// --- SHA 函数 ---
foreign func SHA1(data: CPointer<UInt8>, len: UIntNative, out: CPointer<UInt8>): CPointer<UInt8>
foreign func SHA224(data: CPointer<UInt8>, len: UIntNative, out: CPointer<UInt8>): CPointer<UInt8>
foreign func SHA256(data: CPointer<UInt8>, len: UIntNative, out: CPointer<UInt8>): CPointer<UInt8>
foreign func SHA384(data: CPointer<UInt8>, len: UIntNative, out: CPointer<UInt8>): CPointer<UInt8>
foreign func SHA512(data: CPointer<UInt8>, len: UIntNative, out: CPointer<UInt8>): CPointer<UInt8>
foreign func SHA1_Init(sha: CPointer<ShaCtx>): Int32
foreign func SHA1_Update(sha: CPointer<ShaCtx>, data: CPointer<Unit>, len: UIntNative): Int32
foreign func SHA1_Final(out: CPointer<UInt8>, sha: CPointer<ShaCtx>): Int32
foreign func SHA256_Init(sha: CPointer<Sha256Ctx>): Int32
foreign func SHA256_Update(sha: CPointer<Sha256Ctx>, data: CPointer<Unit>, len: UIntNative): Int32
foreign func SHA256_Final(out: CPointer<UInt8>, sha: CPointer<Sha256Ctx>): Int32
foreign func SHA384_Init(sha: CPointer<Sha512Ctx>): Int32
foreign func SHA384_Update(sha: CPointer<Sha512Ctx>, data: CPointer<Unit>, len: UIntNative): Int32
foreign func SHA384_Final(out: CPointer<UInt8>, sha: CPointer<Sha512Ctx>): Int32
foreign func SHA512_Init(sha: CPointer<Sha512Ctx>): Int32
foreign func SHA512_Update(sha: CPointer<Sha512Ctx>, data: CPointer<Unit>, len: UIntNative): Int32
foreign func SHA512_Final(out: CPointer<UInt8>, sha: CPointer<Sha512Ctx>): Int32

// --- HMAC 函数 ---
foreign func HMAC(evp_md: CPointer<Unit>, key: CPointer<Unit>, key_len: UIntNative, data: CPointer<Unit>, data_len: UIntNative, out: CPointer<UInt8>, out_len: CPointer<UIntNative>): CPointer<UInt8>
foreign func HMAC_CTX_init(ctx: CPointer<HmacCtxSt>): Unit
foreign func HMAC_CTX_cleanup(ctx: CPointer<HmacCtxSt>): Unit
foreign func HMAC_Init_ex(ctx: CPointer<HmacCtxSt>, key: CPointer<Unit>, len: UIntNative, md: CPointer<Unit>, engine: CPointer<Unit>): Int32
foreign func HMAC_Update(ctx: CPointer<HmacCtxSt>, data: CPointer<Unit>, len: UIntNative): Int32
foreign func HMAC_Final(ctx: CPointer<HmacCtxSt>, out: CPointer<UInt8>, out_len: CPointer<UIntNative>): Int32
foreign func HMAC_CTX_copy(dst: CPointer<HmacCtxSt>, src: CPointer<HmacCtxSt>): Int32
foreign func HMAC_CTX_reset(ctx: CPointer<HmacCtxSt>): Int32
