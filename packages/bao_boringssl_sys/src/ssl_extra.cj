// 严格翻译自: src/boringssl_sys/boringssl.zig
package bao_boringssl_sys

// ============================================================================
// BoringSSL 额外 SSL/TLS FFI 函数声明
// 严格翻译自: boringssl.zig 中补充的 SSL_*, SSL_CTX_*, SSL_SESSION_*, DTLS_*, TLSv1_* 函数
// ============================================================================

// --- SSL_CTX 补充 ---
foreign func SSL_CTX_add0_chain_cert(ctx: CPointer<Unit>, x: CPointer<Unit>): Int32
foreign func SSL_CTX_add1_chain_cert(ctx: CPointer<Unit>, x: CPointer<Unit>): Int32
foreign func SSL_CTX_add_cert_compression_alg(ctx: CPointer<Unit>, alg_id: UInt16, compress: CPointer<Unit>, decompress: CPointer<Unit>): Int32
foreign func SSL_CTX_add_client_CA(ctx: CPointer<Unit>, x: CPointer<Unit>): Int32
foreign func SSL_CTX_add_extra_chain_cert(ctx: CPointer<Unit>, x: CPointer<Unit>): Int32
foreign func SSL_CTX_check_private_key(ctx: CPointer<Unit>): Int32
foreign func SSL_CTX_cipher_in_group(ctx: CPointer<Unit>, cipher_id: UInt16): Int32
foreign func SSL_CTX_clear_chain_certs(ctx: CPointer<Unit>): Unit
foreign func SSL_CTX_clear_extra_chain_certs(ctx: CPointer<Unit>): Unit
foreign func SSL_CTX_enable_ocsp_stapling(ctx: CPointer<Unit>): Unit
foreign func SSL_CTX_enable_signed_cert_timestamps(ctx: CPointer<Unit>): Unit
foreign func SSL_CTX_flush_sessions(ctx: CPointer<Unit>, tm: Int64): Unit
foreign func SSL_CTX_get0_certificate(ctx: CPointer<Unit>): CPointer<Unit>
foreign func SSL_CTX_get0_chain(ctx: CPointer<Unit>): CPointer<Unit>
foreign func SSL_CTX_get0_chain_certs(ctx: CPointer<Unit>, out: CPointer<CPointer<Unit>>): Int32
foreign func SSL_CTX_get0_param(ctx: CPointer<Unit>): CPointer<Unit>
foreign func SSL_CTX_get0_privatekey(ctx: CPointer<Unit>): CPointer<EvpPkeySt>
foreign func SSL_CTX_get_cert_store(ctx: CPointer<Unit>): CPointer<Unit>
foreign func SSL_CTX_get_ciphers(ctx: CPointer<Unit>): CPointer<Unit>
foreign func SSL_CTX_get_client_CA_list(ctx: CPointer<Unit>): CPointer<Unit>
foreign func SSL_CTX_get_default_passwd_cb(ctx: CPointer<Unit>): CPointer<Unit>
foreign func SSL_CTX_get_default_passwd_cb_userdata(ctx: CPointer<Unit>): CPointer<Unit>
foreign func SSL_CTX_get_ex_data(ctx: CPointer<Unit>, idx: Int32): CPointer<Unit>
foreign func SSL_CTX_get_ex_new_index(argl: Int64, argp: CPointer<Unit>, unused: CPointer<Unit>, dup_unused: CPointer<Unit>, free_func: CPointer<Unit>): Int32
foreign func SSL_CTX_get_extra_chain_certs(ctx: CPointer<Unit>, out: CPointer<CPointer<Unit>>): Int32
foreign func SSL_CTX_get_info_callback(ctx: CPointer<Unit>): CPointer<Unit>
foreign func SSL_CTX_get_keylog_callback(ctx: CPointer<Unit>): CPointer<Unit>
foreign func SSL_CTX_get_max_cert_list(ctx: CPointer<Unit>): UInt32
foreign func SSL_CTX_get_num_tickets(ctx: CPointer<Unit>): UIntNative
foreign func SSL_CTX_get_quiet_shutdown(ctx: CPointer<Unit>): Int32
foreign func SSL_CTX_get_read_ahead(ctx: CPointer<Unit>): Int32
foreign func SSL_CTX_get_session_cache_mode(ctx: CPointer<Unit>): Int32
foreign func SSL_CTX_get_timeout(ctx: CPointer<Unit>): Int64
foreign func SSL_CTX_get_tlsext_ticket_keys(ctx: CPointer<Unit>, keys: CPointer<UInt8>, keys_len: UIntNative): Int32
foreign func SSL_CTX_get_verify_callback(ctx: CPointer<Unit>): CPointer<Unit>
foreign func SSL_CTX_get_verify_depth(ctx: CPointer<Unit>): Int32
foreign func SSL_CTX_get_verify_mode(ctx: CPointer<Unit>): Int32
foreign func SSL_CTX_need_tmp_RSA(ctx: CPointer<Unit>): Int32
foreign func SSL_CTX_sess_get_get_cb(ctx: CPointer<Unit>): CPointer<Unit>
foreign func SSL_CTX_sess_get_new_cb(ctx: CPointer<Unit>): CPointer<Unit>
foreign func SSL_CTX_sess_get_remove_cb(ctx: CPointer<Unit>): CPointer<Unit>
foreign func SSL_CTX_sess_number(ctx: CPointer<Unit>): Int64
foreign func SSL_CTX_sess_set_get_cb(ctx: CPointer<Unit>, cb: CPointer<Unit>): Unit
foreign func SSL_CTX_sess_set_new_cb(ctx: CPointer<Unit>, cb: CPointer<Unit>): Unit
foreign func SSL_CTX_sess_set_remove_cb(ctx: CPointer<Unit>, cb: CPointer<Unit>): Unit
foreign func SSL_CTX_set0_buffer_pool(ctx: CPointer<Unit>, pool: CPointer<Unit>): Int32
foreign func SSL_CTX_set0_chain(ctx: CPointer<Unit>, sk: CPointer<Unit>): Unit
foreign func SSL_CTX_set0_client_CAs(ctx: CPointer<Unit>, name_list: CPointer<Unit>): Unit
foreign func SSL_CTX_set0_verify_cert_store(ctx: CPointer<Unit>, st: CPointer<Unit>): Int32
foreign func SSL_CTX_set1_chain(ctx: CPointer<Unit>, sk: CPointer<Unit>): Int32
foreign func SSL_CTX_set1_curves(ctx: CPointer<Unit>, curves: CPointer<Int32>, num_curves: UIntNative): Int32
foreign func SSL_CTX_set1_curves_list(ctx: CPointer<Unit>, curves: CString): Int32
foreign func SSL_CTX_set1_ech_keys(ctx: CPointer<Unit>, keys: CPointer<Unit>): Int32
foreign func SSL_CTX_set1_groups(ctx: CPointer<Unit>, groups: CPointer<Int32>, num_groups: UIntNative): Int32
foreign func SSL_CTX_set1_groups_list(ctx: CPointer<Unit>, groups: CString): Int32
foreign func SSL_CTX_set1_param(ctx: CPointer<Unit>, pm: CPointer<Unit>): Int32
foreign func SSL_CTX_set1_sigalgs(ctx: CPointer<Unit>, sigalgs: CPointer<Int32>, num_sigalgs: UIntNative): Int32
foreign func SSL_CTX_set1_sigalgs_list(ctx: CPointer<Unit>, sigalgs: CString): Int32
foreign func SSL_CTX_set1_tls_channel_id(ctx: CPointer<Unit>, private_key: CPointer<Unit>): Int32
foreign func SSL_CTX_set1_verify_cert_store(ctx: CPointer<Unit>, st: CPointer<Unit>): Int32
foreign func SSL_CTX_set_allow_unknown_alpn_protos(ctx: CPointer<Unit>, enabled: Int32): Unit
foreign func SSL_CTX_set_cert_cb(ctx: CPointer<Unit>, cb: CPointer<Unit>, arg: CPointer<Unit>): Unit
foreign func SSL_CTX_set_cert_store(ctx: CPointer<Unit>, store: CPointer<Unit>): Unit
foreign func SSL_CTX_set_cert_verify_callback(ctx: CPointer<Unit>, cb: CPointer<Unit>, arg: CPointer<Unit>): Unit
foreign func SSL_CTX_set_chain_and_key(ctx: CPointer<Unit>, certs: CPointer<Unit>, key: CPointer<Unit>): Int32
foreign func SSL_CTX_set_client_CA_list(ctx: CPointer<Unit>, name_list: CPointer<Unit>): Unit
foreign func SSL_CTX_set_client_cert_cb(ctx: CPointer<Unit>, cb: CPointer<Unit>): Unit
foreign func SSL_CTX_set_current_time_cb(ctx: CPointer<Unit>, cb: CPointer<Unit>): Unit
foreign func SSL_CTX_set_default_passwd_cb(ctx: CPointer<Unit>, cb: CPointer<Unit>): Unit
foreign func SSL_CTX_set_default_passwd_cb_userdata(ctx: CPointer<Unit>, data: CPointer<Unit>): Unit
foreign func SSL_CTX_set_dos_protection_cb(ctx: CPointer<Unit>, cb: CPointer<Unit>): Unit
foreign func SSL_CTX_set_early_data_enabled(ctx: CPointer<Unit>, enabled: Int32): Unit
foreign func SSL_CTX_set_ex_data(ctx: CPointer<Unit>, idx: Int32, data: CPointer<Unit>): Int32
foreign func SSL_CTX_set_false_start_allowed_without_alpn(ctx: CPointer<Unit>, enabled: Int32): Unit
foreign func SSL_CTX_set_grease_enabled(ctx: CPointer<Unit>, enabled: Int32): Unit
foreign func SSL_CTX_set_max_cert_list(ctx: CPointer<Unit>, size: UInt32): UInt32
foreign func SSL_CTX_set_max_send_fragment(ctx: CPointer<Unit>, max_send_fragment: UInt32): UInt32
foreign func SSL_CTX_set_msg_callback_arg(ctx: CPointer<Unit>, arg: CPointer<Unit>): Unit
foreign func SSL_CTX_set_next_protos_advertised_cb(ctx: CPointer<Unit>, cb: CPointer<Unit>, arg: CPointer<Unit>): Unit
foreign func SSL_CTX_set_next_proto_select_cb(ctx: CPointer<Unit>, cb: CPointer<Unit>, arg: CPointer<Unit>): Unit
foreign func SSL_CTX_set_num_tickets(ctx: CPointer<Unit>, num_tickets: UIntNative): Int32
foreign func SSL_CTX_set_ocsp_response(ctx: CPointer<Unit>, response: CPointer<UInt8>, response_len: UIntNative): Int32
foreign func SSL_CTX_set_permute_extensions(ctx: CPointer<Unit>, enabled: Int32): Unit
foreign func SSL_CTX_set_private_key_method(ctx: CPointer<Unit>, key_method: CPointer<Unit>): Unit
foreign func SSL_CTX_set_psk_client_callback(ctx: CPointer<Unit>, cb: CPointer<Unit>): Unit
foreign func SSL_CTX_set_psk_server_callback(ctx: CPointer<Unit>, cb: CPointer<Unit>): Unit
foreign func SSL_CTX_set_purpose(ctx: CPointer<Unit>, purpose: Int32): Int32
foreign func SSL_CTX_set_quic_method(ctx: CPointer<Unit>, quic_method: CPointer<Unit>): Int32
foreign func SSL_CTX_set_quiet_shutdown(ctx: CPointer<Unit>, mode: Int32): Unit
foreign func SSL_CTX_set_read_ahead(ctx: CPointer<Unit>, yes: Int32): Unit
foreign func SSL_CTX_set_record_protocol_version(ctx: CPointer<Unit>, version: Int32): Int32
foreign func SSL_CTX_set_reverify_on_resume(ctx: CPointer<Unit>, enabled: Int32): Unit
foreign func SSL_CTX_set_select_certificate_cb(ctx: CPointer<Unit>, cb: CPointer<Unit>): Unit
foreign func SSL_CTX_set_session_id_context(ctx: CPointer<Unit>, sid_ctx: CPointer<UInt8>, sid_ctx_len: UInt32): Int32
foreign func SSL_CTX_set_session_psk_dhe_timeout(ctx: CPointer<Unit>, seconds: UInt32): Int32
foreign func SSL_CTX_set_signed_cert_timestamp_list(ctx: CPointer<Unit>, list: CPointer<UInt8>, list_len: UIntNative): Int32
foreign func SSL_CTX_set_signing_algorithm_prefs(ctx: CPointer<Unit>, prefs: CPointer<UInt16>, num_prefs: UIntNative): Int32
foreign func SSL_CTX_set_strict_cipher_list(ctx: CPointer<Unit>, str: CString): Int32
foreign func SSL_CTX_set_ticket_aead_method(ctx: CPointer<Unit>, method: CPointer<Unit>): Unit
foreign func SSL_CTX_set_timeout(ctx: CPointer<Unit>, seconds: Int64): Int64
foreign func SSL_CTX_set_tls_channel_id_enabled(ctx: CPointer<Unit>, enabled: Int32): Unit
foreign func SSL_CTX_set_tlsext_ticket_key_cb(ctx: CPointer<Unit>, cb: CPointer<Unit>): Int32
foreign func SSL_CTX_set_tlsext_ticket_keys(ctx: CPointer<Unit>, keys: CPointer<UInt8>, keys_len: UIntNative): Int32
foreign func SSL_CTX_set_tmp_dh(ctx: CPointer<Unit>, dh: CPointer<Unit>): Int32
foreign func SSL_CTX_set_tmp_dh_callback(ctx: CPointer<Unit>, cb: CPointer<Unit>): Unit
foreign func SSL_CTX_set_tmp_rsa(ctx: CPointer<Unit>, rsa: CPointer<Unit>): Int32
foreign func SSL_CTX_set_tmp_rsa_callback(ctx: CPointer<Unit>, cb: CPointer<Unit>): Unit
foreign func SSL_CTX_set_trust(ctx: CPointer<Unit>, trust: Int32): Int32
foreign func SSL_CTX_set_verify_algorithm_prefs(ctx: CPointer<Unit>, prefs: CPointer<UInt16>, num_prefs: UIntNative): Int32
foreign func SSL_CTX_use_certificate_ASN1(ctx: CPointer<Unit>, len: Int32, d: CPointer<UInt8>): Int32
foreign func SSL_CTX_use_psk_identity_hint(ctx: CPointer<Unit>, hint: CString): Int32
foreign func SSL_CTX_use_RSAPrivateKey(ctx: CPointer<Unit>, rsa: CPointer<Unit>): Int32

// --- SSL 补充 ---
foreign func SSL_add0_chain_cert(ssl: CPointer<Unit>, x: CPointer<Unit>): Int32
foreign func SSL_add1_chain_cert(ssl: CPointer<Unit>, x: CPointer<Unit>): Int32
foreign func SSL_add_application_settings(ssl: CPointer<Unit>, peer_algos: CPointer<UInt16>, num_peer_algos: UIntNative, local_algos: CPointer<UInt16>, num_local_algos: UIntNative): Int32
foreign func SSL_add_bio_cert_subjects_to_stack(stack: CPointer<Unit>, bio: CPointer<Unit>): Int32
foreign func SSL_add_client_CA(ssl: CPointer<Unit>, x: CPointer<Unit>): Int32
foreign func SSL_add_dir_cert_subjects_to_stack(stack: CPointer<Unit>, dir: CString): Int32
foreign func SSL_can_release_private_key(ssl: CPointer<Unit>): Int32
foreign func SSL_certs_clear(ssl: CPointer<Unit>): Unit
foreign func SSL_check_private_key(ssl: CPointer<Unit>): Int32
foreign func SSL_cutthrough_complete(ssl: CPointer<Unit>): Int32
foreign func SSL_delegated_credential_used(ssl: CPointer<Unit>): Int32
foreign func SSL_early_callback_ctx_extension_get(ctx: CPointer<SslEarlyCallbackCtx>, extension_type: UInt16, out: CPointer<CPointer<UInt8>>, out_len: CPointer<UIntNative>): Int32
foreign func SSL_early_data_accepted(ssl: CPointer<Unit>): Int32
foreign func SSL_early_data_reason_string(reason: Int32): CString
foreign func SSL_ech_accepted(ssl: CPointer<Unit>): Int32
foreign func SSL_enable_ocsp_stapling(ssl: CPointer<Unit>): Unit
foreign func SSL_enable_signed_cert_timestamps(ssl: CPointer<Unit>): Unit
foreign func SSL_error_description(err: Int32): CString
foreign func SSL_export_keying_material(ssl: CPointer<Unit>, out: CPointer<UInt8>, out_len: UIntNative, label: CString, label_len: UIntNative, context: CPointer<UInt8>, context_len: UIntNative, use_context: Int32): Int32
foreign func SSL_generate_key_block(ssl: CPointer<Unit>, out: CPointer<UInt8>, out_len: UIntNative): Int32
foreign func SSL_get0_certificate_types(ssl: CPointer<Unit>, out_types: CPointer<CPointer<UInt8>>): UIntNative
foreign func SSL_get0_chain_certs(ssl: CPointer<Unit>, out: CPointer<CPointer<Unit>>): Int32
foreign func SSL_get0_ech_name_override(ssl: CPointer<Unit>): CPointer<CString>
foreign func SSL_get0_ech_retry_configs(ssl: CPointer<Unit>): CPointer<UInt8>
foreign func SSL_get0_next_proto_negotiated(ssl: CPointer<Unit>, out: CPointer<CPointer<UInt8>>, out_len: CPointer<UInt32>): Unit
foreign func SSL_get0_ocsp_response(ssl: CPointer<Unit>, out: CPointer<CPointer<UInt8>>): UIntNative
foreign func SSL_get0_param(ssl: CPointer<Unit>): CPointer<Unit>
foreign func SSL_get0_peer_application_settings(ssl: CPointer<Unit>, out: CPointer<CPointer<UInt8>>, out_len: CPointer<UInt16>): Int32
foreign func SSL_get0_peer_certificates(ssl: CPointer<Unit>): CPointer<Unit>
foreign func SSL_get0_peer_delegation_algorithms(ssl: CPointer<Unit>, out: CPointer<CPointer<UInt16>>, out_len: CPointer<UIntNative>): Int32
foreign func SSL_get0_peer_verify_algorithms(ssl: CPointer<Unit>, out: CPointer<CPointer<UInt16>>, out_len: CPointer<UIntNative>): Int32
foreign func SSL_get0_server_requested_CAs(ssl: CPointer<Unit>, out: CPointer<CPointer<Unit>>): UIntNative
foreign func SSL_get0_session_id_context(ssl: CPointer<Unit>, out: CPointer<CPointer<UInt8>>, out_len: CPointer<UInt32>): Unit
foreign func SSL_get0_signed_cert_timestamp_list(ssl: CPointer<Unit>, out: CPointer<CPointer<UInt8>>): UIntNative
foreign func SSL_get_cipher_by_value(value: UInt16): CPointer<Unit>
foreign func SSL_get_ciphers(ssl: CPointer<Unit>): CPointer<Unit>
foreign func SSL_get_client_CA_list(ssl: CPointer<Unit>): CPointer<Unit>
foreign func SSL_get_client_random(ssl: CPointer<Unit>, out: CPointer<UInt8>, max_out: UIntNative): UIntNative
foreign func SSL_get_curve_id(ssl: CPointer<Unit>): UInt32
foreign func SSL_get_curve_name(curve_id: UInt32): CString
foreign func SSL_get_early_data_reason(ssl: CPointer<Unit>): Int32
foreign func SSL_get_ex_data(ssl: CPointer<Unit>, idx: Int32): CPointer<Unit>
foreign func SSL_get_ex_data_X509_STORE_CTX_idx(): Int32
foreign func SSL_get_ex_new_index(argl: Int64, argp: CPointer<Unit>, unused: CPointer<Unit>, dup_unused: CPointer<Unit>, free_func: CPointer<Unit>): Int32
foreign func SSL_get_extms_support(ssl: CPointer<Unit>): Int32
foreign func SSL_get_fd(ssl: CPointer<Unit>): Int32
foreign func SSL_get_info_callback(ssl: CPointer<Unit>): CPointer<Unit>
foreign func SSL_get_ivs(ssl: CPointer<Unit>, out_iv: CPointer<UInt8>, out_iv_len: CPointer<UIntNative>, out_key_block: CPointer<CPointer<UInt8>>, out_key_block_len: CPointer<UIntNative>): Int32
foreign func SSL_get_key_block_len(ssl: CPointer<Unit>): UIntNative
foreign func SSL_get_max_cert_list(ssl: CPointer<Unit>): UInt32
foreign func SSL_get_max_proto_version(ssl: CPointer<Unit>): Int32
foreign func SSL_get_min_proto_version(ssl: CPointer<Unit>): Int32
foreign func SSL_get_peer_full_cert_chain(ssl: CPointer<Unit>): CPointer<Unit>
foreign func SSL_get_peer_quic_transport_params(ssl: CPointer<Unit>, out: CPointer<CPointer<UInt8>>, out_len: CPointer<UIntNative>): Unit
foreign func SSL_get_peer_signature_algorithm(ssl: CPointer<Unit>): UInt16
foreign func SSL_get_pending_cipher(ssl: CPointer<Unit>): CPointer<Unit>
foreign func SSL_get_psk_identity(ssl: CPointer<Unit>): CString
foreign func SSL_get_psk_identity_hint(ssl: CPointer<Unit>): CString
foreign func SSL_get_quiet_shutdown(ssl: CPointer<Unit>): Int32
foreign func SSL_get_read_ahead(ssl: CPointer<Unit>): Int32
foreign func SSL_get_read_sequence(ssl: CPointer<Unit>): UIntNative
foreign func SSL_get_rfd(ssl: CPointer<Unit>): Int32
foreign func SSL_get_secure_renegotiation_support(ssl: CPointer<Unit>): Int32
foreign func SSL_get_servername_type(ssl: CPointer<Unit>): Int32
foreign func SSL_get_server_random(ssl: CPointer<Unit>, out: CPointer<UInt8>, max_out: UIntNative): UIntNative
foreign func SSL_get_server_tmp_key(ssl: CPointer<Unit>, out: CPointer<Unit>): Int32
foreign func SSL_get_shared_sigalgs(ssl: CPointer<Unit>, idx: Int32, psign: CPointer<Int32>, phash: CPointer<Int32>, psignhash: CPointer<Int32>, rsig: CPointer<CString>, rhash: CPointer<CString>): Int32
foreign func SSL_get_signature_algorithm_digest(alg: UInt16): CPointer<Unit>
foreign func SSL_get_signature_algorithm_key_type(alg: UInt16): Int32
foreign func SSL_get_signature_algorithm_name(alg: UInt16, is_signature: Int32): CString
foreign func SSL_get_SSL_CTX(ssl: CPointer<Unit>): CPointer<Unit>
foreign func SSL_get_ticket_age_skew(ssl: CPointer<Unit>): Int32
foreign func SSL_get_tls_unique(ssl: CPointer<Unit>, out: CPointer<UInt8>, max_out: CPointer<UIntNative>): Int32
foreign func SSL_get_verify_callback(ssl: CPointer<Unit>): CPointer<Unit>
foreign func SSL_get_verify_depth(ssl: CPointer<Unit>): Int32
foreign func SSL_get_verify_mode(ssl: CPointer<Unit>): Int32
foreign func SSL_get_wfd(ssl: CPointer<Unit>): Int32
foreign func SSL_get_write_sequence(ssl: CPointer<Unit>): UIntNative
foreign func SSL_has_application_settings(ssl: CPointer<Unit>): Int32
foreign func SSL_has_pending(ssl: CPointer<Unit>): Int32
foreign func SSL_in_early_data(ssl: CPointer<Unit>): Int32
foreign func SSL_in_false_start(ssl: CPointer<Unit>): Int32
foreign func SSL_is_dtls(ssl: CPointer<Unit>): Int32
foreign func SSL_is_signature_algorithm_rsa_pss(alg: UInt16): Int32
foreign func SSL_key_update(ssl: CPointer<Unit>, request_type: Int32): Int32
foreign func SSL_library_init(): Int32
foreign func SSL_magic_pending_session_ptr(): CPointer<Unit>
foreign func SSL_marshal_ech_config(out: CPointer<CPointer<UInt8>>, out_len: CPointer<UIntNative>, config_id: UInt8, public_name: CString, max_name_len: UIntNative, kem_id: UInt16): Int32
foreign func SSL_max_seal_overhead(ssl: CPointer<Unit>): UIntNative
foreign func SSL_need_tmp_RSA(ssl: CPointer<Unit>): Int32
foreign func SSL_pending(ssl: CPointer<Unit>): Int32
foreign func SSL_process_quic_post_handshake(ssl: CPointer<Unit>): Int32
foreign func SSL_process_tls13_new_session_ticket(ssl: CPointer<Unit>): Int32
foreign func SSL_provide_quic_data(ssl: CPointer<Unit>, level: Int32, data: CPointer<UInt8>, len: UIntNative): Int32
foreign func SSL_quic_max_handshake_flight_len(ssl: CPointer<Unit>, level: Int32): UIntNative
foreign func SSL_quic_read_level(ssl: CPointer<Unit>): Int32
foreign func SSL_quic_write_level(ssl: CPointer<Unit>): Int32
foreign func SSL_request_handshake_hints(ssl: CPointer<Unit>): Int32
foreign func SSL_reset_early_data_reject(ssl: CPointer<Unit>): Unit
foreign func SSL_select_next_proto(out: CPointer<CPointer<UInt8>>, out_len: CPointer<UInt8>, server: CPointer<UInt8>, server_len: UInt32, client: CPointer<UInt8>, client_len: UInt32): Int32
foreign func SSL_send_fatal_alert(ssl: CPointer<Unit>, alert: UInt8): Int32
foreign func SSL_serialize_capabilities(ssl: CPointer<Unit>, out: CPointer<CPointer<UInt8>>, out_len: CPointer<UIntNative>): Int32
foreign func SSL_serialize_handshake_hints(ssl: CPointer<Unit>, out: CPointer<CPointer<UInt8>>, out_len: CPointer<UIntNative>): Int32
foreign func SSL_set0_chain(ssl: CPointer<Unit>, sk: CPointer<Unit>): Unit
foreign func SSL_set0_client_CAs(ssl: CPointer<Unit>, name_list: CPointer<Unit>): Unit
foreign func SSL_set0_rbio(ssl: CPointer<Unit>, rbio: CPointer<Unit>): Unit
foreign func SSL_set0_verify_cert_store(ssl: CPointer<Unit>, st: CPointer<Unit>): Int32
foreign func SSL_set0_wbio(ssl: CPointer<Unit>, wbio: CPointer<Unit>): Unit
foreign func SSL_set1_chain(ssl: CPointer<Unit>, sk: CPointer<Unit>): Int32
foreign func SSL_set1_curves(ssl: CPointer<Unit>, curves: CPointer<Int32>, num_curves: UIntNative): Int32
foreign func SSL_set1_curves_list(ssl: CPointer<Unit>, curves: CString): Int32
foreign func SSL_set1_delegated_credential(ssl: CPointer<Unit>, dc: CPointer<UInt8>, dc_len: UIntNative, pkey: CPointer<EvpPkeySt>): Int32
foreign func SSL_set1_ech_config_list(ssl: CPointer<Unit>, list: CPointer<UInt8>, list_len: UIntNative): Int32
foreign func SSL_set1_groups(ssl: CPointer<Unit>, groups: CPointer<Int32>, num_groups: UIntNative): Int32
foreign func SSL_set1_groups_list(ssl: CPointer<Unit>, groups: CString): Int32
foreign func SSL_set1_host(ssl: CPointer<Unit>, host: CString): Int32
foreign func SSL_set1_param(ssl: CPointer<Unit>, pm: CPointer<Unit>): Int32
foreign func SSL_set1_sigalgs(ssl: CPointer<Unit>, sigalgs: CPointer<Int32>, num_sigalgs: UIntNative): Int32
foreign func SSL_set1_sigalgs_list(ssl: CPointer<Unit>, sigalgs: CString): Int32
foreign func SSL_set1_tls_channel_id(ssl: CPointer<Unit>, private_key: CPointer<Unit>): Int32
foreign func SSL_set1_verify_cert_store(ssl: CPointer<Unit>, st: CPointer<Unit>): Int32
foreign func SSL_set_cert_cb(ssl: CPointer<Unit>, cb: CPointer<Unit>, arg: CPointer<Unit>): Unit
foreign func SSL_set_chain_and_key(ssl: CPointer<Unit>, certs: CPointer<Unit>, key: CPointer<Unit>): Int32
foreign func SSL_set_client_CA_list(ssl: CPointer<Unit>, name_list: CPointer<Unit>): Unit
foreign func SSL_set_early_data_enabled(ssl: CPointer<Unit>, enabled: Int32): Unit
foreign func SSL_set_enable_ech_grease(ssl: CPointer<Unit>, enabled: Int32): Unit
foreign func SSL_set_ex_data(ssl: CPointer<Unit>, idx: Int32, data: CPointer<Unit>): Int32
foreign func SSL_set_handshake_hints(ssl: CPointer<Unit>, hints: CPointer<UInt8>, hints_len: UIntNative): Int32
foreign func SSL_set_hostflags(ssl: CPointer<Unit>, flags: UInt32): Unit
foreign func SSL_set_jdk11_workaround(ssl: CPointer<Unit>, enabled: Int32): Unit
foreign func SSL_set_max_cert_list(ssl: CPointer<Unit>, size: UInt32): UInt32
foreign func SSL_set_max_send_fragment(ssl: CPointer<Unit>, max_send_fragment: UInt32): UInt32
foreign func SSL_set_msg_callback_arg(ssl: CPointer<Unit>, arg: CPointer<Unit>): Unit
foreign func SSL_set_ocsp_response(ssl: CPointer<Unit>, response: CPointer<UInt8>, response_len: UIntNative): Int32
foreign func SSL_set_permute_extensions(ssl: CPointer<Unit>, enabled: Int32): Unit
foreign func SSL_set_private_key_method(ssl: CPointer<Unit>, key_method: CPointer<Unit>): Unit
foreign func SSL_set_psk_client_callback(ssl: CPointer<Unit>, cb: CPointer<Unit>): Unit
foreign func SSL_set_psk_server_callback(ssl: CPointer<Unit>, cb: CPointer<Unit>): Unit
foreign func SSL_set_purpose(ssl: CPointer<Unit>, purpose: Int32): Int32
foreign func SSL_set_quic_early_data_context(ssl: CPointer<Unit>, context: CPointer<UInt8>, context_len: UIntNative): Int32
foreign func SSL_set_quic_method(ssl: CPointer<Unit>, quic_method: CPointer<Unit>): Int32
foreign func SSL_set_quic_transport_params(ssl: CPointer<Unit>, params: CPointer<UInt8>, params_len: UIntNative): Int32
foreign func SSL_set_quic_use_legacy_codepoint(ssl: CPointer<Unit>, use_legacy: Int32): Unit
foreign func SSL_set_quiet_shutdown(ssl: CPointer<Unit>, mode: Int32): Unit
foreign func SSL_set_read_ahead(ssl: CPointer<Unit>, yes: Int32): Unit
foreign func SSL_set_renegotiate_mode(ssl: CPointer<Unit>, mode: Int32): Unit
foreign func SSL_set_rfd(ssl: CPointer<Unit>, fd: Int32): Unit
foreign func SSL_set_session_id_context(ssl: CPointer<Unit>, sid_ctx: CPointer<UInt8>, sid_ctx_len: UInt32): Int32
foreign func SSL_set_shed_handshake_config(ssl: CPointer<Unit>, config: Int32): Unit
foreign func SSL_set_signed_cert_timestamp_list(ssl: CPointer<Unit>, list: CPointer<UInt8>, list_len: UIntNative): Int32
foreign func SSL_set_signing_algorithm_prefs(ssl: CPointer<Unit>, prefs: CPointer<UInt16>, num_prefs: UIntNative): Int32
foreign func SSL_set_SSL_CTX(ssl: CPointer<Unit>, ctx: CPointer<Unit>): CPointer<Unit>
foreign func SSL_set_state(ssl: CPointer<Unit>, state: Int32): Unit
foreign func SSL_set_strict_cipher_list(ssl: CPointer<Unit>, str: CString): Int32
foreign func SSL_set_tls_channel_id_enabled(ssl: CPointer<Unit>, enabled: Int32): Unit
foreign func SSL_set_tmp_dh(ssl: CPointer<Unit>, dh: CPointer<Unit>): Int32
foreign func SSL_set_tmp_dh_callback(ssl: CPointer<Unit>, cb: CPointer<Unit>): Unit
foreign func SSL_set_tmp_rsa(ssl: CPointer<Unit>, rsa: CPointer<Unit>): Int32
foreign func SSL_set_tmp_rsa_callback(ssl: CPointer<Unit>, cb: CPointer<Unit>): Unit
foreign func SSL_set_trust(ssl: CPointer<Unit>, trust: Int32): Int32
foreign func SSL_set_verify_algorithm_prefs(ssl: CPointer<Unit>, prefs: CPointer<UInt16>, num_prefs: UIntNative): Int32
foreign func SSL_set_wfd(ssl: CPointer<Unit>, fd: Int32): Unit
foreign func SSL_state_string_long(ssl: CPointer<Unit>): CString
foreign func SSL_total_renegotiations(ssl: CPointer<Unit>): Int32
foreign func SSL_use_certificate_ASN1(ssl: CPointer<Unit>, len: Int32, d: CPointer<UInt8>): Int32
foreign func SSL_used_hello_retry_request(ssl: CPointer<Unit>): Int32
foreign func SSL_use_PrivateKey_ASN1(pk: Int32, ssl: CPointer<Unit>, d: CPointer<UInt8>, len: Int64): Int32
foreign func SSL_use_psk_identity_hint(ssl: CPointer<Unit>, hint: CString): Int32
foreign func SSL_use_RSAPrivateKey(ssl: CPointer<Unit>, rsa: CPointer<Unit>): Int32
foreign func SSL_use_RSAPrivateKey_ASN1(ssl: CPointer<Unit>, d: CPointer<UInt8>, len: Int64): Int32
foreign func SSL_version(ssl: CPointer<Unit>): Int32
foreign func SSL_was_key_usage_invalid(ssl: CPointer<Unit>): Int32

// --- SSL_SESSION 补充 ---
foreign func SSL_SESSION_copy_without_early_data(session: CPointer<Unit>): CPointer<Unit>
foreign func SSL_SESSION_early_data_capable(session: CPointer<Unit>): Int32
foreign func SSL_SESSION_from_bytes(data: CPointer<UInt8>, data_len: UIntNative, ctx: CPointer<Unit>): CPointer<Unit>
foreign func SSL_SESSION_get0_cipher(session: CPointer<Unit>): CPointer<Unit>
foreign func SSL_SESSION_get0_id_context(session: CPointer<Unit>, out: CPointer<CPointer<UInt8>>, out_len: CPointer<UInt32>): Unit
foreign func SSL_SESSION_get0_ocsp_response(session: CPointer<Unit>, out: CPointer<CPointer<UInt8>>): UIntNative
foreign func SSL_SESSION_get0_peer(session: CPointer<Unit>): CPointer<Unit>
foreign func SSL_SESSION_get0_peer_certificates(session: CPointer<Unit>): CPointer<Unit>
foreign func SSL_SESSION_get0_peer_sha256(session: CPointer<Unit>): CPointer<UInt8>
foreign func SSL_SESSION_get0_signed_cert_timestamp_list(session: CPointer<Unit>, out: CPointer<CPointer<UInt8>>): UIntNative
foreign func SSL_SESSION_get0_ticket(session: CPointer<Unit>, out: CPointer<CPointer<UInt8>>, out_len: CPointer<UIntNative>): Unit
foreign func SSL_SESSION_get_ex_data(session: CPointer<Unit>, idx: Int32): CPointer<Unit>
foreign func SSL_SESSION_get_ex_new_index(argl: Int64, argp: CPointer<Unit>, unused: CPointer<Unit>, dup_unused: CPointer<Unit>, free_func: CPointer<Unit>): Int32
foreign func SSL_SESSION_get_id(session: CPointer<Unit>, out_len: CPointer<UInt32>): CPointer<UInt8>
foreign func SSL_SESSION_get_master_key(session: CPointer<Unit>, out: CPointer<UInt8>, max_out: UIntNative): UIntNative
foreign func SSL_SESSION_get_protocol_version(session: CPointer<Unit>): UInt16
foreign func SSL_SESSION_get_ticket_lifetime_hint(session: CPointer<Unit>): Int64
foreign func SSL_SESSION_get_time(session: CPointer<Unit>): Int64
foreign func SSL_SESSION_get_timeout(session: CPointer<Unit>): Int64
foreign func SSL_SESSION_get_version(session: CPointer<Unit>): CString
foreign func SSL_SESSION_has_peer_sha256(session: CPointer<Unit>): Int32
foreign func SSL_SESSION_has_ticket(session: CPointer<Unit>): Int32
foreign func SSL_SESSION_is_resumable(session: CPointer<Unit>): Int32
foreign func SSL_SESSION_new(): CPointer<Unit>
foreign func SSL_session_reused(ssl: CPointer<Unit>): Int32
foreign func SSL_SESSION_set1_id(session: CPointer<Unit>, sid: CPointer<UInt8>, sid_len: UInt32): Int32
foreign func SSL_SESSION_set1_id_context(session: CPointer<Unit>, sid_ctx: CPointer<UInt8>, sid_ctx_len: UInt32): Int32
foreign func SSL_SESSION_set_ex_data(session: CPointer<Unit>, idx: Int32, data: CPointer<Unit>): Int32
foreign func SSL_SESSION_set_protocol_version(session: CPointer<Unit>, version: UInt16): Int32
foreign func SSL_SESSION_set_ticket(session: CPointer<Unit>, ticket: CPointer<UInt8>, ticket_len: UIntNative): Int32
foreign func SSL_SESSION_set_time(session: CPointer<Unit>, time: Int64): Int64
foreign func SSL_SESSION_set_timeout(session: CPointer<Unit>, seconds: Int64): Int64
foreign func SSL_SESSION_should_be_single_use(session: CPointer<Unit>): Int32
foreign func SSL_SESSION_to_bytes(session: CPointer<Unit>, out: CPointer<CPointer<UInt8>>, out_len: CPointer<UIntNative>): Int32
foreign func SSL_SESSION_to_bytes_for_ticket(session: CPointer<Unit>, out: CPointer<CPointer<UInt8>>, out_len: CPointer<UIntNative>): Int32

// --- SSL_CIPHER 补充 ---
foreign func SSL_CIPHER_description(cipher: CPointer<Unit>, buf: CPointer<UInt8>, size: Int32): CPointer<UInt8>
foreign func SSL_CIPHER_get_auth_nid(cipher: CPointer<Unit>): Int32
foreign func SSL_CIPHER_get_bits(cipher: CPointer<Unit>, out_bits: CPointer<Int32>): Int32
foreign func SSL_CIPHER_get_cipher_nid(cipher: CPointer<Unit>): Int32
foreign func SSL_CIPHER_get_digest_nid(cipher: CPointer<Unit>): Int32
foreign func SSL_CIPHER_get_id(cipher: CPointer<Unit>): UInt64
foreign func SSL_CIPHER_get_kx_name(cipher: CPointer<Unit>): CString
foreign func SSL_CIPHER_get_kx_nid(cipher: CPointer<Unit>): Int32
foreign func SSL_CIPHER_get_max_version(cipher: CPointer<Unit>): UInt16
foreign func SSL_CIPHER_get_min_version(cipher: CPointer<Unit>): UInt16
foreign func SSL_CIPHER_get_name(cipher: CPointer<Unit>): CString
foreign func SSL_CIPHER_get_prf_nid(cipher: CPointer<Unit>): Int32
foreign func SSL_CIPHER_get_protocol_id(cipher: CPointer<Unit>): UInt16
foreign func SSL_CIPHER_get_rfc_name(cipher: CPointer<Unit>): CString
foreign func SSL_CIPHER_get_value(cipher: CPointer<Unit>): UInt16
foreign func SSL_CIPHER_get_version(cipher: CPointer<Unit>): CString
foreign func SSL_CIPHER_is_aead(cipher: CPointer<Unit>): Int32
foreign func SSL_CIPHER_is_block_cipher(cipher: CPointer<Unit>): Int32
foreign func SSL_CIPHER_standard_name(cipher: CPointer<Unit>): CString

// --- SSL ECH ---
foreign func SSL_ECH_KEYS_add(keys: CPointer<Unit>, overwrite_existing: Int32, ctx: CPointer<Unit>): Int32
foreign func SSL_ECH_KEYS_free(keys: CPointer<Unit>): Unit
foreign func SSL_ECH_KEYS_has_duplicate_config_id(keys: CPointer<Unit>): Int32
foreign func SSL_ECH_KEYS_marshal_retry_configs(keys: CPointer<Unit>, out: CPointer<CPointer<UInt8>>, out_len: CPointer<UIntNative>): Int32
foreign func SSL_ECH_KEYS_new(): CPointer<Unit>
foreign func SSL_ECH_KEYS_up_ref(keys: CPointer<Unit>): Unit

// --- SSL_COMP ---
foreign func SSL_COMP_add_compression_method(id: Int32, cm: CPointer<Unit>): Int32
foreign func SSL_COMP_free_compression_methods(): Unit
foreign func SSL_COMP_get0_name(comp: CPointer<Unit>): CString
foreign func SSL_COMP_get_compression_methods(): CPointer<Unit>
foreign func SSL_COMP_get_id(comp: CPointer<Unit>): Int32
foreign func SSL_COMP_get_name(comp: CPointer<Unit>): CString

// --- DTLS ---
foreign func DTLSv1_get_timeout(ssl: CPointer<Unit>, out: CPointer<Unit>): Int32
foreign func DTLSv1_handle_timeout(ssl: CPointer<Unit>): Int32
foreign func DTLSv1_set_initial_timeout_duration(ssl: CPointer<Unit>, duration_ms: UInt32): Unit
foreign func DTLS_with_buffers_method(): CPointer<Unit>

// --- TLSv1 ---
foreign func TLSv1_1_client_method(): CPointer<Unit>
foreign func TLSv1_1_method(): CPointer<Unit>
foreign func TLSv1_1_server_method(): CPointer<Unit>
foreign func TLSv1_2_client_method(): CPointer<Unit>
foreign func TLSv1_2_method(): CPointer<Unit>
foreign func TLSv1_2_server_method(): CPointer<Unit>
foreign func TLSv1_client_method(): CPointer<Unit>
foreign func TLSv1_method(): CPointer<Unit>
foreign func TLSv1_server_method(): CPointer<Unit>

// --- SSLeay ---
foreign func SSLeay(): UInt64
foreign func SSLeay_version(type_: Int32): CString
foreign func SSL_alert_desc_string_long(value: Int32): CString
foreign func SSL_alert_from_verify_result(result: Int64): Int32
foreign func SSL_alert_type_string_long(value: Int32): CString
foreign func SSL_clear_chain_certs(ssl: CPointer<Unit>): Unit
foreign func SSL_dup_CA_list(sk: CPointer<Unit>): CPointer<Unit>
foreign func SSL_get_current_compression(ssl: CPointer<Unit>): CPointer<Unit>
foreign func SSL_get_current_expansion(ssl: CPointer<Unit>): CPointer<Unit>
