// 严格翻译自: src/boringssl_sys/boringssl.zig
package bao_boringssl_sys

// ============================================================================
// BoringSSL SSL/TLS FFI 函数声明
// 严格翻译自: boringssl.zig 中 SSL_*, SSL_CTX_* 函数
// ============================================================================

// --- SSL 方法 ---
foreign func TLS_method(): CPointer<Unit>
foreign func TLS_server_method(): CPointer<Unit>
foreign func TLS_client_method(): CPointer<Unit>
foreign func SSLv23_method(): CPointer<Unit>
foreign func SSLv23_server_method(): CPointer<Unit>
foreign func SSLv23_client_method(): CPointer<Unit>
foreign func TLS_with_buffers_method(): CPointer<Unit>
foreign func DTLS_method(): CPointer<Unit>
foreign func DTLS_server_method(): CPointer<Unit>
foreign func DTLS_client_method(): CPointer<Unit>
foreign func DTLSv1_method(): CPointer<Unit>
foreign func DTLSv1_server_method(): CPointer<Unit>
foreign func DTLSv1_client_method(): CPointer<Unit>
foreign func DTLSv1_2_method(): CPointer<Unit>
foreign func DTLSv1_2_server_method(): CPointer<Unit>
foreign func DTLSv1_2_client_method(): CPointer<Unit>

// --- SSL_CTX 创建/释放 ---
foreign func SSL_CTX_new(method: CPointer<Unit>): CPointer<Unit>
foreign func SSL_CTX_free(ctx: CPointer<Unit>): Unit
foreign func SSL_CTX_up_ref(ctx: CPointer<Unit>): Int32

// --- SSL 创建/释放 ---
foreign func SSL_new(ctx: CPointer<Unit>): CPointer<Unit>
foreign func SSL_free(ssl: CPointer<Unit>): Unit
foreign func SSL_up_ref(ssl: CPointer<Unit>): Int32

// --- SSL 连接 ---
foreign func SSL_clear(ssl: CPointer<Unit>): Int32
foreign func SSL_set_fd(ssl: CPointer<Unit>, fd: Int32): Int32
foreign func SSL_set_bio(ssl: CPointer<Unit>, rbio: CPointer<Unit>, wbio: CPointer<Unit>): Unit
foreign func SSL_get_rbio(ssl: CPointer<Unit>): CPointer<Unit>
foreign func SSL_get_wbio(ssl: CPointer<Unit>): CPointer<Unit>
foreign func SSL_connect(ssl: CPointer<Unit>): Int32
foreign func SSL_accept(ssl: CPointer<Unit>): Int32
foreign func SSL_shutdown(ssl: CPointer<Unit>): Int32
foreign func SSL_read(ssl: CPointer<Unit>, buf: CPointer<Unit>, num: Int32): Int32
foreign func SSL_write(ssl: CPointer<Unit>, buf: CPointer<Unit>, num: Int32): Int32
foreign func SSL_peek(ssl: CPointer<Unit>, buf: CPointer<Unit>, num: Int32): Int32

// --- SSL 选项 ---
foreign func SSL_CTX_set_options(ctx: CPointer<Unit>, options: UInt64): UInt64
foreign func SSL_CTX_clear_options(ctx: CPointer<Unit>, options: UInt64): UInt64
foreign func SSL_CTX_get_options(ctx: CPointer<Unit>): UInt64
foreign func SSL_set_options(ssl: CPointer<Unit>, options: UInt64): UInt64
foreign func SSL_clear_options(ssl: CPointer<Unit>, options: UInt64): UInt64
foreign func SSL_get_options(ssl: CPointer<Unit>): UInt64
foreign func SSL_CTX_set_mode(ctx: CPointer<Unit>, mode: UInt64): UInt64
foreign func SSL_CTX_clear_mode(ctx: CPointer<Unit>, mode: UInt64): UInt64
foreign func SSL_CTX_get_mode(ctx: CPointer<Unit>): UInt64
foreign func SSL_set_mode(ssl: CPointer<Unit>, mode: UInt64): UInt64
foreign func SSL_clear_mode(ssl: CPointer<Unit>, mode: UInt64): UInt64
foreign func SSL_get_mode(ssl: CPointer<Unit>): UInt64

// --- SSL 证书/密钥 ---
foreign func SSL_CTX_use_certificate(ctx: CPointer<Unit>, x: CPointer<Unit>): Int32
foreign func SSL_CTX_use_PrivateKey(ctx: CPointer<Unit>, pkey: CPointer<Unit>): Int32
foreign func SSL_CTX_use_certificate_file(ctx: CPointer<Unit>, file: CString, type_: Int32): Int32
foreign func SSL_CTX_use_PrivateKey_file(ctx: CPointer<Unit>, file: CString, type_: Int32): Unit
foreign func SSL_CTX_use_certificate_chain_file(ctx: CPointer<Unit>, file: CString): Int32
foreign func SSL_CTX_use_PrivateKey_ASN1(pk: Int32, ctx: CPointer<Unit>, d: CPointer<UInt8>, len: Int64): Int32
foreign func SSL_CTX_use_RSAPrivateKey_file(ctx: CPointer<Unit>, file: CString, type_: Int32): Int32
foreign func SSL_CTX_use_RSAPrivateKey_ASN1(ctx: CPointer<Unit>, d: CPointer<UInt8>, len: Int64): Int32
foreign func SSL_use_certificate(ssl: CPointer<Unit>, x: CPointer<Unit>): Int32
foreign func SSL_use_PrivateKey(ssl: CPointer<Unit>, pkey: CPointer<Unit>): Int32

// --- SSL 验证 ---
foreign func SSL_CTX_set_verify(ctx: CPointer<Unit>, mode: Int32, callback: CPointer<Unit>): Unit
foreign func SSL_CTX_set_verify_depth(ctx: CPointer<Unit>, depth: Int32): Unit
foreign func SSL_set_verify(ssl: CPointer<Unit>, mode: Int32, callback: CPointer<Unit>): Unit
foreign func SSL_set_verify_depth(ssl: CPointer<Unit>, depth: Int32): Unit
foreign func SSL_CTX_set_custom_verify(ctx: CPointer<Unit>, mode: Int32, callback: CPointer<Unit>): Unit
foreign func SSL_set_custom_verify(ssl: CPointer<Unit>, mode: Int32, callback: CPointer<Unit>): Unit
foreign func SSL_CTX_set_retain_only_sha256_of_client_certs(ctx: CPointer<Unit>, enabled: Int32): Unit
foreign func SSL_set_retain_only_sha256_of_client_certs(ssl: CPointer<Unit>, enabled: Int32): Unit

// --- SSL 会话 ---
foreign func SSL_get_session(ssl: CPointer<Unit>): CPointer<Unit>
foreign func SSL_get1_session(ssl: CPointer<Unit>): CPointer<Unit>
foreign func SSL_set_session(ssl: CPointer<Unit>, session: CPointer<Unit>): Int32
foreign func SSL_SESSION_free(session: CPointer<Unit>): Unit
foreign func SSL_SESSION_up_ref(session: CPointer<Unit>): Int32
foreign func SSL_get_default_timeout(ssl: CPointer<Unit>): Int64
foreign func SSL_CTX_add_session(ctx: CPointer<Unit>, session: CPointer<Unit>): Int32
foreign func SSL_CTX_remove_session(ctx: CPointer<Unit>, session: CPointer<Unit>): Int32
foreign func SSL_CTX_set_session_cache_mode(ctx: CPointer<Unit>, mode: Int32): Int64
foreign func SSL_CTX_sess_set_cache_size(ctx: CPointer<Unit>, size: Int64): Int64
foreign func SSL_CTX_sess_get_cache_size(ctx: CPointer<Unit>): Int64

// --- SSL 信息 ---
foreign func SSL_get_version(ssl: CPointer<Unit>): CString
foreign func SSL_get_cipher(ssl: CPointer<Unit>): CPointer<Unit>
foreign func SSL_get_cipher_name(ssl: CPointer<Unit>): CString
foreign func SSL_get_cipher_list(ssl: CPointer<Unit>, n: Int32): CString
foreign func SSL_get_certificate(ssl: CPointer<Unit>): CPointer<Unit>
foreign func SSL_get_privatekey(ssl: CPointer<Unit>): CPointer<Unit>
foreign func SSL_get_peer_certificate(ssl: CPointer<Unit>): CPointer<Unit>
foreign func SSL_get_peer_cert_chain(ssl: CPointer<Unit>): CPointer<Unit>
foreign func SSL_get_verify_result(ssl: CPointer<Unit>): Int64
foreign func SSL_get_error(ssl: CPointer<Unit>, ret: Int32): Int32
foreign func SSL_get_shutdown(ssl: CPointer<Unit>): Int32
foreign func SSL_set_shutdown(ssl: CPointer<Unit>, mode: Int32): Unit
foreign func SSL_state(ssl: CPointer<Unit>): Int32
foreign func SSL_state_string(ssl: CPointer<Unit>): CString
foreign func SSL_want(ssl: CPointer<Unit>): Int32
foreign func SSL_is_server(ssl: CPointer<Unit>): Int32
foreign func SSL_is_init_finished(ssl: CPointer<Unit>): Int32
foreign func SSL_in_init(ssl: CPointer<Unit>): Int32
foreign func SSL_in_before(ssl: CPointer<Unit>): Int32
foreign func SSL_get_current_cipher(ssl: CPointer<Unit>): CPointer<Unit>
foreign func SSL_get_shared_ciphers(ssl: CPointer<Unit>, buf: CPointer<UInt8>, len: Int32): CPointer<UInt8>

// --- SSL 主机名/SNI ---
foreign func SSL_set_tlsext_host_name(ssl: CPointer<Unit>, name: CString): Int32
foreign func SSL_get_servername(ssl: CPointer<Unit>, type_: Int32): CString
foreign func SSL_CTX_set_tlsext_servername_callback(ctx: CPointer<Unit>, cb: CPointer<Unit>): Unit
foreign func SSL_CTX_set_tlsext_servername_arg(ctx: CPointer<Unit>, arg: CPointer<Unit>): Unit

// --- SSL ALPN ---
foreign func SSL_CTX_set_alpn_protos(ctx: CPointer<Unit>, protos: CPointer<UInt8>, protos_len: UIntNative): Int32
foreign func SSL_set_alpn_protos(ssl: CPointer<Unit>, protos: CPointer<UInt8>, protos_len: UIntNative): Int32
foreign func SSL_CTX_set_alpn_select_cb(ctx: CPointer<Unit>, cb: CPointer<Unit>, arg: CPointer<Unit>): Unit
foreign func SSL_get0_alpn_selected(ssl: CPointer<Unit>, out: CPointer<CPointer<UInt8>>, out_len: CPointer<UInt32>): Unit

// --- SSL OCSP ---
foreign func SSL_set_tlsext_status_type(ssl: CPointer<Unit>, type_: Int32): Int32
foreign func SSL_get_tlsext_status_type(ssl: CPointer<Unit>): Int32
foreign func SSL_set_tlsext_status_ocsp_resp(ssl: CPointer<Unit>, resp: CPointer<UInt8>, resp_len: UIntNative): Int32
foreign func SSL_get_tlsext_status_ocsp_resp(ssl: CPointer<Unit>, out: CPointer<CPointer<UInt8>>): UIntNative
foreign func SSL_CTX_set_tlsext_status_cb(ctx: CPointer<Unit>, callback: CPointer<Unit>): Int32
foreign func SSL_CTX_set_tlsext_status_arg(ctx: CPointer<Unit>, arg: CPointer<Unit>): Int32

// --- SSL CTX 验证 ---
foreign func SSL_CTX_load_verify_locations(ctx: CPointer<Unit>, ca_file: CString, ca_path: CString): Int32
foreign func SSL_CTX_set_default_verify_paths(ctx: CPointer<Unit>): Int32
foreign func SSL_CTX_set_default_verify_dir(ctx: CPointer<Unit>): Int32
foreign func SSL_CTX_set_default_verify_file(ctx: CPointer<Unit>): Int32
foreign func SSL_CTX_get_verify_chain(ctx: CPointer<Unit>): CPointer<Unit>

// --- SSL 其他 ---
foreign func SSL_set_connect_state(ssl: CPointer<Unit>): Unit
foreign func SSL_set_accept_state(ssl: CPointer<Unit>): Unit
foreign func SSL_do_handshake(ssl: CPointer<Unit>): Int32
foreign func SSL_renegotiate(ssl: CPointer<Unit>): Int32
foreign func SSL_renegotiate_pending(ssl: CPointer<Unit>): Int32
foreign func SSL_get_finished(ssl: CPointer<Unit>, buf: CPointer<Unit>, count: UIntNative): UIntNative
foreign func SSL_get_peer_finished(ssl: CPointer<Unit>, buf: CPointer<Unit>, count: UIntNative): UIntNative
foreign func SSL_alert_type_string(value: Int32): CString
foreign func SSL_alert_desc_string(value: Int32): CString
foreign func SSL_cache_hit(ssl: CPointer<Unit>): Int32
foreign func SSL_num_renegotiations(ssl: CPointer<Unit>): Int32
foreign func SSL_CTX_set_info_callback(ctx: CPointer<Unit>, cb: CPointer<Unit>): Unit
foreign func SSL_set_info_callback(ssl: CPointer<Unit>, cb: CPointer<Unit>): Unit
foreign func SSL_CTX_set_msg_callback(ctx: CPointer<Unit>, cb: CPointer<Unit>): Unit
foreign func SSL_set_msg_callback(ssl: CPointer<Unit>, cb: CPointer<Unit>): Unit
foreign func SSL_CTX_set_keylog_callback(ctx: CPointer<Unit>, cb: CPointer<Unit>): Unit
foreign func SSL_CTX_set_max_proto_version(ctx: CPointer<Unit>, version: UInt16): Int32
foreign func SSL_CTX_set_min_proto_version(ctx: CPointer<Unit>, version: UInt16): Int32
foreign func SSL_set_max_proto_version(ssl: CPointer<Unit>, version: UInt16): Int32
foreign func SSL_set_min_proto_version(ssl: CPointer<Unit>, version: UInt16): Int32
foreign func SSL_CTX_get_max_proto_version(ctx: CPointer<Unit>): Int32
foreign func SSL_CTX_get_min_proto_version(ctx: CPointer<Unit>): Int32
foreign func SSL_set_mtu(ssl: CPointer<Unit>, mtu: UIntNative): Unit
foreign func SSL_set_enforce_rsa_key_usage(ssl: CPointer<Unit>, enabled: Int32): Unit
foreign func SSL_CTX_set_ciphersuites(ctx: CPointer<Unit>, str: CString): Int32
foreign func SSL_set_ciphersuites(ssl: CPointer<Unit>, str: CString): Int32
foreign func SSL_CTX_set_cipher_list(ctx: CPointer<Unit>, str: CString): Int32
foreign func SSL_set_cipher_list(ssl: CPointer<Unit>, str: CString): Int32
foreign func SSL_CTX_set_compliance_policy(ctx: CPointer<Unit>, policy: Int32): Int32
foreign func SSL_set_compliance_policy(ssl: CPointer<Unit>, policy: Int32): Int32
foreign func SSL_CTX_set_tmp_ecdh(ctx: CPointer<Unit>, ec_key: CPointer<Unit>): Int32
foreign func SSL_set_tmp_ecdh(ssl: CPointer<Unit>, ec_key: CPointer<Unit>): Int32
foreign func SSL_enable_tls_channel_id(ssl: CPointer<Unit>): Int32
foreign func SSL_CTX_enable_tls_channel_id(ctx: CPointer<Unit>): Int32
foreign func SSL_set_tls_channel_id(ssl: CPointer<Unit>, private_key: CPointer<Unit>): Int32
foreign func SSL_CTX_set_tls_channel_id_cb(ctx: CPointer<Unit>, cb: CPointer<Unit>): Unit
foreign func SSL_get_tls_channel_id(ssl: CPointer<Unit>, out: CPointer<UInt8>, out_len: CPointer<UIntNative>): UIntNative

// --- BIO+SSL ---
foreign func BIO_f_ssl(): CPointer<BioMethodSt>
foreign func BIO_set_ssl(bio: CPointer<Unit>, ssl: CPointer<Unit>, take_ownership: Int32): Int64
foreign func BIO_new_ssl(ctx: CPointer<Unit>, client: Int32): CPointer<Unit>
foreign func BIO_new_ssl_connect(ctx: CPointer<Unit>): CPointer<Unit>
foreign func BIO_new_buffer_ssl_connect(ctx: CPointer<Unit>): CPointer<Unit>

// --- SSL 加载错误字符串 ---
foreign func ERR_load_SSL_strings(): Unit
foreign func SSL_load_error_strings(): Unit

// --- SSL 统计 ---
foreign func SSL_CTX_sess_connect(ctx: CPointer<Unit>): Int32
foreign func SSL_CTX_sess_connect_good(ctx: CPointer<Unit>): Int32
foreign func SSL_CTX_sess_connect_renegotiate(ctx: CPointer<Unit>): Int32
foreign func SSL_CTX_sess_accept(ctx: CPointer<Unit>): Int32
foreign func SSL_CTX_sess_accept_renegotiate(ctx: CPointer<Unit>): Int32
foreign func SSL_CTX_sess_accept_good(ctx: CPointer<Unit>): Int32
foreign func SSL_CTX_sess_hits(ctx: CPointer<Unit>): Int32
foreign func SSL_CTX_sess_cb_hits(ctx: CPointer<Unit>): Int32
foreign func SSL_CTX_sess_misses(ctx: CPointer<Unit>): Int32
foreign func SSL_CTX_sess_timeouts(ctx: CPointer<Unit>): Int32
foreign func SSL_CTX_sess_cache_full(ctx: CPointer<Unit>): Int32
