// 严格翻译自: src/boringssl_sys/boringssl.zig
package bao_boringssl_sys

// ============================================================================
// BoringSSL 额外 X509 FFI 函数声明
// 严格翻译自: boringssl.zig 中补充的 X509_*, X509_NAME_*, X509_STORE_*, X509_REQ_*,
//   X509_CRL_*, X509_REVOKED_*, X509_EXTENSION_*, X509_ATTRIBUTE_*, X509_ALGOR_*,
//   X509_PUBKEY_*, X509_VERIFY_PARAM_*, X509_TRUST_*, X509V3_*, X509at_* 函数
// ============================================================================

// --- X509 补充 ---
foreign func X509_add1_ext_i2d(x: CPointer<Unit>, nid: Int32, value: CPointer<Unit>, crit: Int32, flags: UInt64): Int32
foreign func X509_add1_reject_object(x: CPointer<Unit>, obj: CPointer<Unit>): Int32
foreign func X509_add1_trust_object(x: CPointer<Unit>, obj: CPointer<Unit>): Int32
foreign func X509_alias_get0(x: CPointer<Unit>, out_len: CPointer<Int32>): CPointer<UInt8>
foreign func X509_alias_set1(x: CPointer<Unit>, name: CPointer<UInt8>, len: Int32): Int32
foreign func X509_chain_up_ref(chain: CPointer<Unit>): Int32
foreign func X509_check_ca(x: CPointer<Unit>): Int32
foreign func X509_check_private_key(x: CPointer<Unit>, pkey: CPointer<EvpPkeySt>): Int32
foreign func X509_check_trust(x: CPointer<Unit>, id: Int32, flags: Int32): Int32
foreign func X509_cmp(a: CPointer<Unit>, b: CPointer<Unit>): Int32
foreign func X509_cmp_current_time(asn1_time: CPointer<Asn1StringSt>): Int32
foreign func X509_cmp_time(asn1_time: CPointer<Asn1StringSt>, cmp_time: CPointer<Int64>): Int32
foreign func X509_delete_ext(x: CPointer<Unit>, loc: Int32): CPointer<Unit>
foreign func X509_digest(x: CPointer<Unit>, md: CPointer<Unit>, buf: CPointer<UInt8>, len: CPointer<UInt32>): Int32
foreign func X509_get0_notAfter(x: CPointer<Unit>): CPointer<Asn1StringSt>
foreign func X509_get0_notBefore(x: CPointer<Unit>): CPointer<Asn1StringSt>
foreign func X509_get0_pubkey_bitstr(x: CPointer<Unit>): CPointer<Asn1StringSt>
foreign func X509_get0_serialNumber(x: CPointer<Unit>): CPointer<Asn1StringSt>
foreign func X509_get0_signature(x: CPointer<Unit>): CPointer<Asn1StringSt>
foreign func X509_get0_tbs_sigalg(x: CPointer<Unit>): CPointer<X509Algor>
foreign func X509_get0_uids(x: CPointer<Unit>, out_issuer_uid: CPointer<CPointer<Asn1StringSt>>, out_subject_uid: CPointer<CPointer<Asn1StringSt>>): Unit
foreign func X509_get_default_cert_area(): CString
foreign func X509_get_default_cert_dir(): CString
foreign func X509_get_default_cert_dir_env(): CString
foreign func X509_get_default_private_dir(): CString
foreign func X509_get_ext(x: CPointer<Unit>, loc: Int32): CPointer<Unit>
foreign func X509_get_ext_by_critical(x: CPointer<Unit>, crit: Int32, lastpos: Int32): Int32
foreign func X509_get_ext_by_NID(x: CPointer<Unit>, nid: Int32, lastpos: Int32): Int32
foreign func X509_get_ext_by_OBJ(x: CPointer<Unit>, obj: CPointer<Unit>, lastpos: Int32): Int32
foreign func X509_get_ext_count(x: CPointer<Unit>): Int32
foreign func X509_getm_notAfter(x: CPointer<Unit>): CPointer<Asn1StringSt>
foreign func X509_getm_notBefore(x: CPointer<Unit>): CPointer<Asn1StringSt>
foreign func X509_get_pathlen(x: CPointer<Unit>): Int64
foreign func X509_get_X509_PUBKEY(x: CPointer<Unit>): CPointer<Unit>
foreign func X509_gmtime_adj(asn1_time: CPointer<Asn1StringSt>, offset: Int64): CPointer<Asn1StringSt>
foreign func X509_INFO_free(info: CPointer<Unit>): Unit
foreign func X509_INFO_new(): CPointer<Unit>
foreign func X509_issuer_name_cmp(a: CPointer<Unit>, b: CPointer<Unit>): Int32
foreign func X509_issuer_name_hash(x: CPointer<Unit>): UInt64
foreign func X509_issuer_name_hash_old(x: CPointer<Unit>): UInt64
foreign func X509_keyid_get0(x: CPointer<Unit>, out_len: CPointer<Int32>): CPointer<UInt8>
foreign func X509_keyid_set1(x: CPointer<Unit>, id: CPointer<UInt8>, len: Int32): Int32
foreign func X509_parse_from_buffer(buf: CPointer<Unit>): CPointer<Unit>
foreign func X509_PKEY_free(pkey: CPointer<Unit>): Unit
foreign func X509_PKEY_new(): CPointer<Unit>
foreign func X509_print_ex(bio: CPointer<Unit>, x: CPointer<Unit>, nmflags: UInt32, certflags: UInt32): Int32
foreign func X509_pubkey_digest(x: CPointer<Unit>, md: CPointer<Unit>, buf: CPointer<UInt8>, len: CPointer<UInt32>): Int32
foreign func X509_reject_clear(x: CPointer<Unit>): Unit
foreign func X509_set1_signature_algo(x: CPointer<Unit>, algo: CPointer<X509Algor>): Int32
foreign func X509_set1_signature_value(x: CPointer<Unit>, sig: CPointer<UInt8>, sig_len: UIntNative): Int32
foreign func X509_set_issuer_name(x: CPointer<Unit>, name: CPointer<Unit>): Int32
foreign func X509_set_notAfter(x: CPointer<Unit>, tm: CPointer<Asn1StringSt>): Int32
foreign func X509_set_notBefore(x: CPointer<Unit>, tm: CPointer<Asn1StringSt>): Int32
foreign func X509_set_serialNumber(x: CPointer<Unit>, serial: CPointer<Asn1StringSt>): Int32
foreign func X509_set_subject_name(x: CPointer<Unit>, name: CPointer<Unit>): Int32
foreign func X509_set_version(x: CPointer<Unit>, version: Int64): Int32
foreign func X509_sign_ctx(x: CPointer<Unit>, ctx: CPointer<Unit>): Int32
foreign func X509_subject_name_cmp(a: CPointer<Unit>, b: CPointer<Unit>): Int32
foreign func X509_subject_name_hash(x: CPointer<Unit>): UInt64
foreign func X509_subject_name_hash_old(x: CPointer<Unit>): UInt64
foreign func X509_time_adj(asn1_time: CPointer<Asn1StringSt>, offset: Int64, in_tm: CPointer<Int64>): CPointer<Asn1StringSt>
foreign func X509_time_adj_ex(asn1_time: CPointer<Asn1StringSt>, offset_day: Int32, offset_sec: Int64, in_tm: CPointer<Int64>): CPointer<Asn1StringSt>
foreign func X509_trust_clear(x: CPointer<Unit>): Unit
foreign func X509_verify_cert(x509_ctx: CPointer<Unit>): Int32
foreign func X509_verify_cert_error_string(n: Int64): CString

// --- X509_ALGOR ---
foreign func X509_ALGOR_cmp(a: CPointer<X509Algor>, b: CPointer<X509Algor>): Int32
foreign func X509_ALGOR_dup(alg: CPointer<X509Algor>): CPointer<X509Algor>
foreign func X509_ALGOR_free(alg: CPointer<X509Algor>): Unit
foreign func X509_ALGOR_get0(aobj: CPointer<CPointer<Unit>>, atype: CPointer<Int32>, aval: CPointer<CPointer<Unit>>, alg: CPointer<X509Algor>): Unit
foreign func X509_ALGOR_new(): CPointer<X509Algor>
foreign func X509_ALGOR_set0(alg: CPointer<X509Algor>, aobj: CPointer<Unit>, atype: Int32, aval: CPointer<Unit>): Int32
foreign func X509_ALGOR_set_md(alg: CPointer<X509Algor>, md: CPointer<Unit>): Unit

// --- X509_NAME 补充 ---
foreign func X509_NAME_add_entry(name: CPointer<Unit>, entry: CPointer<Unit>, loc: Int32, set_: Int32): Int32
foreign func X509_NAME_add_entry_by_NID(name: CPointer<Unit>, nid: Int32, type_: Int32, bytes: CPointer<UInt8>, len: Int32, loc: Int32, set_: Int32): Int32
foreign func X509_NAME_add_entry_by_OBJ(name: CPointer<Unit>, obj: CPointer<Unit>, type_: Int32, bytes: CPointer<UInt8>, len: Int32, loc: Int32, set_: Int32): Int32
foreign func X509_NAME_delete_entry(name: CPointer<Unit>, loc: Int32): CPointer<Unit>
foreign func X509_NAME_digest(name: CPointer<Unit>, md: CPointer<Unit>, buf: CPointer<UInt8>, len: CPointer<UInt32>): Int32
foreign func X509_NAME_entry_count(name: CPointer<Unit>): Int32
foreign func X509_NAME_ENTRY_create_by_NID(ne: CPointer<CPointer<Unit>>, nid: Int32, type_: Int32, bytes: CPointer<UInt8>, len: Int32): CPointer<Unit>
foreign func X509_NAME_ENTRY_create_by_OBJ(ne: CPointer<CPointer<Unit>>, obj: CPointer<Unit>, type_: Int32, bytes: CPointer<UInt8>, len: Int32): CPointer<Unit>
foreign func X509_NAME_ENTRY_create_by_txt(ne: CPointer<CPointer<Unit>>, field: CString, type_: Int32, bytes: CPointer<UInt8>, len: Int32): CPointer<Unit>
foreign func X509_NAME_ENTRY_dup(ne: CPointer<Unit>): CPointer<Unit>
foreign func X509_NAME_ENTRY_free(ne: CPointer<Unit>): Unit
foreign func X509_NAME_ENTRY_get_object(ne: CPointer<Unit>): CPointer<Unit>
foreign func X509_NAME_ENTRY_new(): CPointer<Unit>
foreign func X509_NAME_ENTRY_set(ne: CPointer<Unit>, set_: Int32): Int32
foreign func X509_NAME_ENTRY_set_data(ne: CPointer<Unit>, type_: Int32, bytes: CPointer<UInt8>, len: Int32): Int32
foreign func X509_NAME_ENTRY_set_object(ne: CPointer<Unit>, obj: CPointer<Unit>): Int32
foreign func X509_NAME_get0_der(name: CPointer<Unit>, out_der: CPointer<CPointer<UInt8>>, out_der_len: CPointer<UIntNative>): Int32
foreign func X509_NAME_get_index_by_OBJ(name: CPointer<Unit>, obj: CPointer<Unit>, lastpos: Int32): Int32
foreign func X509_NAME_get_text_by_NID(name: CPointer<Unit>, nid: Int32, buf: CPointer<UInt8>, len: Int32): Int32
foreign func X509_NAME_get_text_by_OBJ(name: CPointer<Unit>, obj: CPointer<Unit>, buf: CPointer<UInt8>, len: Int32): Int32
foreign func X509_NAME_hash(name: CPointer<Unit>): UInt64
foreign func X509_NAME_hash_old(name: CPointer<Unit>): UInt64
foreign func X509_NAME_print(bio: CPointer<Unit>, name: CPointer<Unit>, obase: Int32): Int32
foreign func X509_NAME_set(name: CPointer<CPointer<Unit>>, n: CPointer<Unit>): Int32

// --- X509_EXTENSION 补充 ---
foreign func X509_EXTENSION_create_by_OBJ(ex: CPointer<CPointer<Unit>>, obj: CPointer<Unit>, crit: Int32, data: CPointer<Asn1StringSt>): CPointer<Unit>
foreign func X509_EXTENSION_dup(ex: CPointer<Unit>): CPointer<Unit>
foreign func X509_EXTENSION_set_critical(ex: CPointer<Unit>, crit: Int32): Int32
foreign func X509_EXTENSION_set_data(ex: CPointer<Unit>, data: CPointer<Asn1StringSt>): Int32
foreign func X509_EXTENSION_set_object(ex: CPointer<Unit>, obj: CPointer<Unit>): Int32

// --- X509_PUBKEY ---
foreign func X509_PUBKEY_free(x: CPointer<Unit>): Unit
foreign func X509_PUBKEY_get(x: CPointer<Unit>): CPointer<EvpPkeySt>
foreign func X509_PUBKEY_get0_param(pk: CPointer<Unit>, ppkalg: CPointer<CPointer<Unit>>, ppk: CPointer<CPointer<Asn1StringSt>>, pa: CPointer<CPointer<X509Algor>>, ppkey: CPointer<CPointer<EvpPkeySt>>): Unit
foreign func X509_PUBKEY_get0_public_key(x: CPointer<Unit>): CPointer<Asn1StringSt>
foreign func X509_PUBKEY_new(): CPointer<Unit>
foreign func X509_PUBKEY_set(x: CPointer<Unit>, pkey: CPointer<EvpPkeySt>): Int32
foreign func X509_PUBKEY_set0_param(pub: CPointer<Unit>, aobj: CPointer<Unit>, atype: Int32, aval: CPointer<Unit>, pkey: CPointer<UInt8>, pkeylen: Int32): Int32

// --- X509_ATTRIBUTE ---
foreign func X509_ATTRIBUTE_count(attr: CPointer<Unit>): Int32
foreign func X509_ATTRIBUTE_create(nid: Int32, atype: Int32, value: CPointer<Unit>): CPointer<Unit>
foreign func X509_ATTRIBUTE_create_by_NID(attr: CPointer<CPointer<Unit>>, nid: Int32, atype: Int32, data: CPointer<Unit>, len: Int32): CPointer<Unit>
foreign func X509_ATTRIBUTE_create_by_OBJ(attr: CPointer<CPointer<Unit>>, obj: CPointer<Unit>, atype: Int32, data: CPointer<Unit>, len: Int32): CPointer<Unit>
foreign func X509_ATTRIBUTE_create_by_txt(attr: CPointer<CPointer<Unit>>, attrname: CString, atype: Int32, data: CPointer<Unit>, len: Int32): CPointer<Unit>
foreign func X509_ATTRIBUTE_dup(attr: CPointer<Unit>): CPointer<Unit>
foreign func X509_ATTRIBUTE_free(attr: CPointer<Unit>): Unit
foreign func X509_ATTRIBUTE_get0_data(attr: CPointer<Unit>, idx: Int32, atype: Int32, data: CPointer<Unit>): CPointer<Unit>
foreign func X509_ATTRIBUTE_get0_object(attr: CPointer<Unit>): CPointer<Unit>
foreign func X509_ATTRIBUTE_get0_type(attr: CPointer<Unit>, idx: Int32): CPointer<Asn1TypeSt>
foreign func X509_ATTRIBUTE_new(): CPointer<Unit>
foreign func X509_ATTRIBUTE_set1_data(attr: CPointer<Unit>, atype: Int32, data: CPointer<Unit>, len: Int32): Int32
foreign func X509_ATTRIBUTE_set1_object(attr: CPointer<Unit>, obj: CPointer<Unit>): Int32

// --- X509at ---
foreign func X509at_add1_attr(sk: CPointer<CPointer<Unit>>, attr: CPointer<Unit>): CPointer<Unit>
foreign func X509at_add1_attr_by_NID(sk: CPointer<CPointer<Unit>>, nid: Int32, type_: Int32, bytes: CPointer<UInt8>, len: Int32): CPointer<Unit>
foreign func X509at_add1_attr_by_OBJ(sk: CPointer<CPointer<Unit>>, obj: CPointer<Unit>, type_: Int32, bytes: CPointer<UInt8>, len: Int32): CPointer<Unit>
foreign func X509at_add1_attr_by_txt(sk: CPointer<CPointer<Unit>>, attrname: CString, type_: Int32, bytes: CPointer<UInt8>, len: Int32): CPointer<Unit>
foreign func X509at_delete_attr(sk: CPointer<Unit>, loc: Int32): CPointer<Unit>
foreign func X509at_get_attr(sk: CPointer<Unit>, loc: Int32): CPointer<Unit>
foreign func X509at_get_attr_by_NID(sk: CPointer<Unit>, nid: Int32, lastpos: Int32): Int32
foreign func X509at_get_attr_by_OBJ(sk: CPointer<Unit>, obj: CPointer<Unit>, lastpos: Int32): Int32
foreign func X509at_get_attr_count(sk: CPointer<Unit>): Int32

// --- X509_STORE 补充 ---
foreign func X509_STORE_add_lookup(store: CPointer<Unit>, method: CPointer<Unit>): CPointer<Unit>
foreign func X509_STORE_CTX_cleanup(ctx: CPointer<Unit>): Unit
foreign func X509_STORE_CTX_free(ctx: CPointer<Unit>): Unit
foreign func X509_STORE_CTX_get0_cert(ctx: CPointer<Unit>): CPointer<Unit>
foreign func X509_STORE_CTX_get0_chain(ctx: CPointer<Unit>): CPointer<Unit>
foreign func X509_STORE_CTX_get0_current_crl(ctx: CPointer<Unit>): CPointer<Unit>
foreign func X509_STORE_CTX_get0_current_issuer(ctx: CPointer<Unit>): CPointer<Unit>
foreign func X509_STORE_CTX_get0_param(ctx: CPointer<Unit>): CPointer<Unit>
foreign func X509_STORE_CTX_get0_parent_ctx(ctx: CPointer<Unit>): CPointer<Unit>
foreign func X509_STORE_CTX_get0_store(ctx: CPointer<Unit>): CPointer<Unit>
foreign func X509_STORE_CTX_get0_untrusted(ctx: CPointer<Unit>): CPointer<Unit>
foreign func X509_STORE_CTX_get1_chain(ctx: CPointer<Unit>): CPointer<Unit>
foreign func X509_STORE_CTX_get1_issuer(ctx: CPointer<Unit>, issuer: CPointer<CPointer<Unit>>, x: CPointer<Unit>): Int32
foreign func X509_STORE_CTX_get_chain(ctx: CPointer<Unit>): CPointer<Unit>
foreign func X509_STORE_CTX_get_current_cert(ctx: CPointer<Unit>): CPointer<Unit>
foreign func X509_STORE_CTX_get_error(ctx: CPointer<Unit>): Int32
foreign func X509_STORE_CTX_get_error_depth(ctx: CPointer<Unit>): Int32
foreign func X509_STORE_CTX_init(ctx: CPointer<Unit>, store: CPointer<Unit>, x509: CPointer<Unit>, chain: CPointer<Unit>): Int32
foreign func X509_STORE_CTX_new(): CPointer<Unit>
foreign func X509_STORE_CTX_purpose_inherit(ctx: CPointer<Unit>, def_purpose: Int32, purpose: Int32, trust: Int32): Int32
foreign func X509_STORE_CTX_set0_crls(ctx: CPointer<Unit>, crls: CPointer<Unit>): Unit
foreign func X509_STORE_CTX_set0_param(ctx: CPointer<Unit>, param: CPointer<Unit>): Unit
foreign func X509_STORE_CTX_set0_trusted_stack(ctx: CPointer<Unit>, sk: CPointer<Unit>): Unit
foreign func X509_STORE_CTX_set_cert(ctx: CPointer<Unit>, x: CPointer<Unit>): Unit
foreign func X509_STORE_CTX_set_chain(ctx: CPointer<Unit>, sk: CPointer<Unit>): Unit
foreign func X509_STORE_CTX_set_default(ctx: CPointer<Unit>, name: CString): Int32
foreign func X509_STORE_CTX_set_depth(ctx: CPointer<Unit>, depth: Int32): Unit
foreign func X509_STORE_CTX_set_error(ctx: CPointer<Unit>, error: Int32): Unit
foreign func X509_STORE_CTX_set_flags(ctx: CPointer<Unit>, flags: UInt64): Unit
foreign func X509_STORE_CTX_set_purpose(ctx: CPointer<Unit>, purpose: Int32): Int32
foreign func X509_STORE_CTX_set_time(ctx: CPointer<Unit>, flags: UInt64, t: Int64): Unit
foreign func X509_STORE_CTX_set_trust(ctx: CPointer<Unit>, trust: Int32): Int32
foreign func X509_STORE_CTX_set_verify(ctx: CPointer<Unit>, verify: CPointer<Unit>): Unit
foreign func X509_STORE_CTX_set_verify_cb(ctx: CPointer<Unit>, verify_cb: CPointer<Unit>): Unit
foreign func X509_STORE_CTX_trusted_stack(ctx: CPointer<Unit>, sk: CPointer<Unit>): Unit
foreign func X509_STORE_CTX_zero(ctx: CPointer<Unit>): Unit
foreign func X509_STORE_get0_param(store: CPointer<Unit>): CPointer<Unit>
foreign func X509_STORE_get1_certs(out: CPointer<CPointer<Unit>>, store: CPointer<Unit>, x: CPointer<Unit>): Int32
foreign func X509_STORE_get1_crls(out: CPointer<CPointer<Unit>>, store: CPointer<Unit>, x: CPointer<Unit>): Int32
foreign func X509_STORE_get_by_subject(vs: CPointer<Unit>, type_: Int32, name: CPointer<Unit>, ret: CPointer<Unit>): Int32
foreign func X509_STORE_get_cert_crl(store: CPointer<Unit>): CPointer<Unit>
foreign func X509_STORE_get_check_crl(store: CPointer<Unit>): CPointer<Unit>
foreign func X509_STORE_get_check_issued(store: CPointer<Unit>): CPointer<Unit>
foreign func X509_STORE_get_check_revocation(store: CPointer<Unit>): CPointer<Unit>
foreign func X509_STORE_get_cleanup(store: CPointer<Unit>): CPointer<Unit>
foreign func X509_STORE_get_get_crl(store: CPointer<Unit>): CPointer<Unit>
foreign func X509_STORE_get_get_issuer(store: CPointer<Unit>): CPointer<Unit>
foreign func X509_STORE_get_lookup_certs(store: CPointer<Unit>): CPointer<Unit>
foreign func X509_STORE_get_lookup_crls(store: CPointer<Unit>): CPointer<Unit>
foreign func X509_STORE_get_verify(store: CPointer<Unit>): CPointer<Unit>
foreign func X509_STORE_get_verify_cb(store: CPointer<Unit>): CPointer<Unit>
foreign func X509_STORE_set_cert_crl(store: CPointer<Unit>, cert_crl: CPointer<Unit>): Int32
foreign func X509_STORE_set_check_crl(store: CPointer<Unit>, check_crl: CPointer<Unit>): Int32
foreign func X509_STORE_set_check_issued(store: CPointer<Unit>, check_issued: CPointer<Unit>): Int32
foreign func X509_STORE_set_check_revocation(store: CPointer<Unit>, check_revocation: CPointer<Unit>): Int32
foreign func X509_STORE_set_cleanup(store: CPointer<Unit>, cleanup: CPointer<Unit>): Int32
foreign func X509_STORE_set_default_paths(store: CPointer<Unit>): Int32
foreign func X509_STORE_set_depth(store: CPointer<Unit>, depth: Int32): Unit
foreign func X509_STORE_set_get_crl(store: CPointer<Unit>, get_crl: CPointer<Unit>): Int32
foreign func X509_STORE_set_get_issuer(store: CPointer<Unit>, get_issuer: CPointer<Unit>): Int32
foreign func X509_STORE_set_lookup_certs(store: CPointer<Unit>, lookup_certs: CPointer<Unit>): Int32
foreign func X509_STORE_set_lookup_crls(store: CPointer<Unit>, lookup_crls: CPointer<Unit>): Int32
foreign func X509_STORE_set_verify(store: CPointer<Unit>, verify: CPointer<Unit>): Int32
foreign func X509_STORE_set_verify_cb(store: CPointer<Unit>, verify_cb: CPointer<Unit>): Int32
foreign func X509_STORE_up_ref(store: CPointer<Unit>): Int32

// --- X509_LOOKUP ---
foreign func X509_LOOKUP_by_subject(ctx: CPointer<Unit>, type_: Int32, name: CPointer<Unit>, ret: CPointer<Unit>): Int32
foreign func X509_LOOKUP_ctrl(ctx: CPointer<Unit>, cmd: Int32, argc: CString, argl: Int64, ret: CPointer<CPointer<Unit>>): Int32
foreign func X509_LOOKUP_free(ctx: CPointer<Unit>): Unit
foreign func X509_LOOKUP_hash_dir(): CPointer<Unit>
foreign func X509_LOOKUP_init(ctx: CPointer<Unit>): Int32
foreign func X509_LOOKUP_new(method: CPointer<Unit>): CPointer<Unit>
foreign func X509_LOOKUP_shutdown(ctx: CPointer<Unit>): Int32

// --- X509_REQ 补充 ---
foreign func X509_REQ_add1_attr(req: CPointer<Unit>, attr: CPointer<Unit>): Int32
foreign func X509_REQ_add1_attr_by_NID(req: CPointer<Unit>, nid: Int32, type_: Int32, bytes: CPointer<UInt8>, len: Int32): Int32
foreign func X509_REQ_add1_attr_by_OBJ(req: CPointer<Unit>, obj: CPointer<Unit>, type_: Int32, bytes: CPointer<UInt8>, len: Int32): Int32
foreign func X509_REQ_add1_attr_by_txt(req: CPointer<Unit>, attrname: CString, type_: Int32, bytes: CPointer<UInt8>, len: Int32): Int32
foreign func X509_REQ_add_extensions(req: CPointer<Unit>, exts: CPointer<Unit>): Int32
foreign func X509_REQ_add_extensions_nid(req: CPointer<Unit>, exts: CPointer<Unit>, nid: Int32): Int32
foreign func X509_REQ_check_private_key(req: CPointer<Unit>, pkey: CPointer<EvpPkeySt>): Int32
foreign func X509_REQ_delete_attr(req: CPointer<Unit>, loc: Int32): CPointer<Unit>
foreign func X509_REQ_digest(req: CPointer<Unit>, md: CPointer<Unit>, buf: CPointer<UInt8>, len: CPointer<UInt32>): Int32
foreign func X509_REQ_dup(req: CPointer<Unit>): CPointer<Unit>
foreign func X509_REQ_extension_nid(nid: Int32): Int32
foreign func X509_REQ_get0_signature(req: CPointer<Unit>): CPointer<Asn1StringSt>
foreign func X509_REQ_get_attr(req: CPointer<Unit>, loc: Int32): CPointer<Unit>
foreign func X509_REQ_get_attr_by_NID(req: CPointer<Unit>, nid: Int32, lastpos: Int32): Int32
foreign func X509_REQ_get_attr_by_OBJ(req: CPointer<Unit>, obj: CPointer<Unit>, lastpos: Int32): Int32
foreign func X509_REQ_get_attr_count(req: CPointer<Unit>): Int32
foreign func X509_REQ_get_extensions(req: CPointer<Unit>): CPointer<Unit>
foreign func X509_REQ_get_pubkey(req: CPointer<Unit>): CPointer<EvpPkeySt>
foreign func X509_REQ_get_signature_nid(req: CPointer<Unit>): Int32
foreign func X509_REQ_get_subject_name(req: CPointer<Unit>): CPointer<Unit>
foreign func X509_REQ_get_version(req: CPointer<Unit>): Int64
foreign func X509_REQ_print(bio: CPointer<Unit>, req: CPointer<Unit>): Int32
foreign func X509_REQ_print_ex(bio: CPointer<Unit>, req: CPointer<Unit>, nmflags: UInt32, certflags: UInt32): Int32
foreign func X509_REQ_set1_signature_algo(req: CPointer<Unit>, algo: CPointer<X509Algor>): Int32
foreign func X509_REQ_set1_signature_value(req: CPointer<Unit>, sig: CPointer<UInt8>, sig_len: UIntNative): Int32
foreign func X509_REQ_set_version(req: CPointer<Unit>, version: Int64): Int32
foreign func X509_REQ_sign_ctx(req: CPointer<Unit>, ctx: CPointer<Unit>): Int32

// --- X509_CRL 补充 ---
foreign func X509_CRL_add0_revoked(crl: CPointer<Unit>, rev: CPointer<Unit>): Int32
foreign func X509_CRL_add1_ext_i2d(crl: CPointer<Unit>, nid: Int32, value: CPointer<Unit>, crit: Int32, flags: UInt64): Int32
foreign func X509_CRL_add_ext(crl: CPointer<Unit>, ext: CPointer<Unit>, loc: Int32): Int32
foreign func X509_CRL_cmp(a: CPointer<Unit>, b: CPointer<Unit>): Int32
foreign func X509_CRL_delete_ext(crl: CPointer<Unit>, loc: Int32): CPointer<Unit>
foreign func X509_CRL_diff(base: CPointer<Unit>, newer: CPointer<Unit>, skey: CPointer<EvpPkeySt>, md: CPointer<Unit>): CPointer<Unit>
foreign func X509_CRL_digest(crl: CPointer<Unit>, md: CPointer<Unit>, buf: CPointer<UInt8>, len: CPointer<UInt32>): Int32
foreign func X509_CRL_get0_by_cert(crl: CPointer<Unit>, ret: CPointer<Unit>, cert: CPointer<Unit>): Int32
foreign func X509_CRL_get0_by_serial(crl: CPointer<Unit>, ret: CPointer<Unit>, serial: CPointer<Asn1StringSt>): Int32
foreign func X509_CRL_get0_lastUpdate(crl: CPointer<Unit>): CPointer<Asn1StringSt>
foreign func X509_CRL_get0_nextUpdate(crl: CPointer<Unit>): CPointer<Asn1StringSt>
foreign func X509_CRL_get0_signature(crl: CPointer<Unit>): CPointer<Asn1StringSt>
foreign func X509_CRL_get_ext(crl: CPointer<Unit>, loc: Int32): CPointer<Unit>
foreign func X509_CRL_get_ext_by_critical(crl: CPointer<Unit>, crit: Int32, lastpos: Int32): Int32
foreign func X509_CRL_get_ext_by_NID(crl: CPointer<Unit>, nid: Int32, lastpos: Int32): Int32
foreign func X509_CRL_get_ext_by_OBJ(crl: CPointer<Unit>, obj: CPointer<Unit>, lastpos: Int32): Int32
foreign func X509_CRL_get_ext_count(crl: CPointer<Unit>): Int32
foreign func X509_CRL_get_ext_d2i(crl: CPointer<Unit>, nid: Int32, out_critical: CPointer<Int32>, out_idx: CPointer<Int32>): CPointer<Unit>
foreign func X509_CRL_get_issuer(crl: CPointer<Unit>): CPointer<Unit>
foreign func X509_CRL_get_REVOKED(crl: CPointer<Unit>): CPointer<Unit>
foreign func X509_CRL_get_signature_nid(crl: CPointer<Unit>): Int32
foreign func X509_CRL_get_version(crl: CPointer<Unit>): Int64
foreign func X509_CRL_match(a: CPointer<Unit>, b: CPointer<Unit>): Int32
foreign func X509_CRL_print(bio: CPointer<Unit>, crl: CPointer<Unit>): Int32
foreign func X509_CRL_set1_lastUpdate(crl: CPointer<Unit>, tm: CPointer<Asn1StringSt>): Int32
foreign func X509_CRL_set1_nextUpdate(crl: CPointer<Unit>, tm: CPointer<Asn1StringSt>): Int32
foreign func X509_CRL_set1_signature_algo(crl: CPointer<Unit>, algo: CPointer<X509Algor>): Int32
foreign func X509_CRL_set1_signature_value(crl: CPointer<Unit>, sig: CPointer<UInt8>, sig_len: UIntNative): Int32
foreign func X509_CRL_set_issuer_name(crl: CPointer<Unit>, name: CPointer<Unit>): Int32
foreign func X509_CRL_set_version(crl: CPointer<Unit>, version: Int64): Int32
foreign func X509_CRL_sign_ctx(crl: CPointer<Unit>, ctx: CPointer<Unit>): Int32
foreign func X509_CRL_sort(crl: CPointer<Unit>): Int32
foreign func X509_CRL_up_ref(crl: CPointer<Unit>): Int32

// --- X509_REVOKED ---
foreign func X509_REVOKED_add1_ext_i2d(rev: CPointer<Unit>, nid: Int32, value: CPointer<Unit>, crit: Int32, flags: UInt64): Int32
foreign func X509_REVOKED_add_ext(rev: CPointer<Unit>, ext: CPointer<Unit>, loc: Int32): Int32
foreign func X509_REVOKED_delete_ext(rev: CPointer<Unit>, loc: Int32): CPointer<Unit>
foreign func X509_REVOKED_dup(rev: CPointer<Unit>): CPointer<Unit>
foreign func X509_REVOKED_free(rev: CPointer<Unit>): Unit
foreign func X509_REVOKED_get0_extensions(rev: CPointer<Unit>): CPointer<Unit>
foreign func X509_REVOKED_get0_revocationDate(rev: CPointer<Unit>): CPointer<Asn1StringSt>
foreign func X509_REVOKED_get0_serialNumber(rev: CPointer<Unit>): CPointer<Asn1StringSt>
foreign func X509_REVOKED_get_ext(rev: CPointer<Unit>, loc: Int32): CPointer<Unit>
foreign func X509_REVOKED_get_ext_by_critical(rev: CPointer<Unit>, crit: Int32, lastpos: Int32): Int32
foreign func X509_REVOKED_get_ext_by_NID(rev: CPointer<Unit>, nid: Int32, lastpos: Int32): Int32
foreign func X509_REVOKED_get_ext_by_OBJ(rev: CPointer<Unit>, obj: CPointer<Unit>, lastpos: Int32): Int32
foreign func X509_REVOKED_get_ext_count(rev: CPointer<Unit>): Int32
foreign func X509_REVOKED_get_ext_d2i(rev: CPointer<Unit>, nid: Int32, out_critical: CPointer<Int32>, out_idx: CPointer<Int32>): CPointer<Unit>
foreign func X509_REVOKED_new(): CPointer<Unit>
foreign func X509_REVOKED_set_revocationDate(rev: CPointer<Unit>, tm: CPointer<Asn1StringSt>): Int32
foreign func X509_REVOKED_set_serialNumber(rev: CPointer<Unit>, serial: CPointer<Asn1StringSt>): Int32

// --- X509_SIG ---
foreign func X509_SIG_free(sig: CPointer<Unit>): Unit
foreign func X509_SIG_get0(sig: CPointer<Unit>, out_alg: CPointer<CPointer<X509Algor>>, out_digest: CPointer<CPointer<Asn1StringSt>>): Unit
foreign func X509_SIG_getm(sig: CPointer<Unit>, out_alg: CPointer<CPointer<X509Algor>>, out_digest: CPointer<CPointer<Asn1StringSt>>): Unit
foreign func X509_SIG_new(): CPointer<Unit>
foreign func X509_signature_dump(bio: CPointer<Unit>, sig: CPointer<Asn1StringSt>, indent: Int32): Int32
foreign func X509_signature_print(bio: CPointer<Unit>, alg: CPointer<X509Algor>, sig: CPointer<Asn1StringSt>): Int32

// --- X509_OBJECT ---
foreign func X509_OBJECT_free_contents(obj: CPointer<Unit>): Unit
foreign func X509_OBJECT_get0_X509(obj: CPointer<Unit>): CPointer<Unit>
foreign func X509_OBJECT_get_type(obj: CPointer<Unit>): Int32
foreign func X509_OBJECT_idx_by_subject(sk: CPointer<Unit>, type_: Int32, name: CPointer<Unit>): Int32
foreign func X509_OBJECT_retrieve_by_subject(sk: CPointer<Unit>, type_: Int32, name: CPointer<Unit>): CPointer<Unit>
foreign func X509_OBJECT_retrieve_match(sk: CPointer<Unit>, obj: CPointer<Unit>): CPointer<Unit>
foreign func X509_OBJECT_up_ref_count(obj: CPointer<Unit>): Unit

// --- X509_VERIFY_PARAM 补充 ---
foreign func X509_VERIFY_PARAM_add0_policy(param: CPointer<Unit>, oid: CPointer<Unit>): Int32
foreign func X509_VERIFY_PARAM_add0_table(param: CPointer<Unit>): Int32
foreign func X509_VERIFY_PARAM_add1_host(param: CPointer<Unit>, name: CString, namelen: UIntNative): Int32
foreign func X509_VERIFY_PARAM_get0(index: Int32): CPointer<Unit>
foreign func X509_VERIFY_PARAM_get0_name(param: CPointer<Unit>): CString
foreign func X509_VERIFY_PARAM_get0_peername(param: CPointer<Unit>): CString
foreign func X509_VERIFY_PARAM_get_count(): Int32
foreign func X509_VERIFY_PARAM_get_depth(param: CPointer<Unit>): Int32
foreign func X509_VERIFY_PARAM_inherit(to_: CPointer<Unit>, from: CPointer<Unit>): Int32
foreign func X509_VERIFY_PARAM_lookup(name: CString): CPointer<Unit>
foreign func X509_VERIFY_PARAM_set1(to_: CPointer<Unit>, from: CPointer<Unit>): Int32
foreign func X509_VERIFY_PARAM_set1_name(param: CPointer<Unit>, name: CString): Int32
foreign func X509_VERIFY_PARAM_set1_policies(param: CPointer<Unit>, policies: CPointer<Unit>): Int32
foreign func X509_VERIFY_PARAM_set_hostflags(param: CPointer<Unit>, flags: UInt32): Unit
foreign func X509_VERIFY_PARAM_table_cleanup(): Unit

// --- X509_TRUST ---
foreign func X509_TRUST_add(id: Int32, flags: Int32, ck: CPointer<Unit>, name: CString, arg1: Int32, arg2: CPointer<Unit>): Int32
foreign func X509_TRUST_cleanup(): Unit
foreign func X509_TRUST_get0(index: Int32): CPointer<Unit>
foreign func X509_TRUST_get0_name(trust: CPointer<Unit>): CString
foreign func X509_TRUST_get_by_id(id: Int32): Int32
foreign func X509_TRUST_get_count(): Int32
foreign func X509_TRUST_get_flags(trust: CPointer<Unit>): Int32
foreign func X509_TRUST_get_trust(trust: CPointer<Unit>): Int32
foreign func X509_TRUST_set(trust: CPointer<Unit>, id: Int32): Int32

// --- X509v3 ---
foreign func X509v3_add_ext(sk: CPointer<CPointer<Unit>>, ext: CPointer<Unit>, loc: Int32): CPointer<Unit>
foreign func X509v3_delete_ext(sk: CPointer<Unit>, loc: Int32): CPointer<Unit>
foreign func X509V3_EXT_d2i(ext: CPointer<Unit>): CPointer<Unit>
foreign func X509V3_EXT_get(ext: CPointer<Unit>): CPointer<Unit>
foreign func X509V3_EXT_get_nid(nid: Int32): CPointer<Unit>
foreign func X509v3_get_ext(sk: CPointer<Unit>, loc: Int32): CPointer<Unit>
foreign func X509v3_get_ext_by_critical(sk: CPointer<Unit>, crit: Int32, lastpos: Int32): Int32
foreign func X509v3_get_ext_by_NID(sk: CPointer<Unit>, nid: Int32, lastpos: Int32): Int32
foreign func X509v3_get_ext_by_OBJ(sk: CPointer<Unit>, obj: CPointer<Unit>, lastpos: Int32): Int32
foreign func X509v3_get_ext_count(sk: CPointer<Unit>): Int32
