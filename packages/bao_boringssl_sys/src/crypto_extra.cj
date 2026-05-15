// 严格翻译自: src/boringssl_sys/boringssl.zig
package bao_boringssl_sys

// ============================================================================
// BoringSSL 额外 BN, RSA, DSA, DH, EC, ECDSA, ECDH, ENGINE FFI 函数声明
// 严格翻译自: boringssl.zig 中补充的 BN_*, RSA_*, DSA_*, DH_*, EC_*, ECDSA_*, ECDH_*, ENGINE_* 函数
// ============================================================================

// --- BN 补充 ---
foreign func BN_init(bn: CPointer<BigNumSt>): Unit
foreign func BN_zero(bn: CPointer<BigNumSt>): Unit
foreign func BN_one(bn: CPointer<BigNumSt>): Int32
foreign func BN_set_u64(bn: CPointer<BigNumSt>, value: UInt64): Int32
foreign func BN_set_negative(bn: CPointer<BigNumSt>, sign: Int32): Unit
foreign func BN_is_negative(bn: CPointer<BigNumSt>): Int32
foreign func BN_le2bn(in_: CPointer<UInt8>, len: UIntNative, ret: CPointer<BigNumSt>): CPointer<BigNumSt>
foreign func BN_bn2le_padded(out: CPointer<UInt8>, len: UIntNative, in_: CPointer<BigNumSt>): Int32
foreign func BN_bn2bin_padded(out: CPointer<UInt8>, len: UIntNative, in_: CPointer<BigNumSt>): Int32
foreign func BN_bn2cbb_padded(out: CPointer<Unit>, len: UIntNative, in_: CPointer<BigNumSt>): Int32
foreign func BN_asc2bn(outp: CPointer<CPointer<BigNumSt>>, in_: CString): Int32
foreign func BN_print(bio: CPointer<Unit>, a: CPointer<BigNumSt>): Int32
foreign func BN_get_word(bn: CPointer<BigNumSt>): UInt64
foreign func BN_get_u64(bn: CPointer<BigNumSt>, out: CPointer<UInt64>): Int32
foreign func BN_parse_asn1_unsigned(cbs: CPointer<CbsSt>, ret: CPointer<BigNumSt>): Int32
foreign func BN_marshal_asn1(cbb: CPointer<Unit>, bn: CPointer<BigNumSt>): Int32
foreign func BN_CTX_start(ctx: CPointer<Unit>): Unit
foreign func BN_CTX_get(ctx: CPointer<Unit>): CPointer<BigNumSt>
foreign func BN_CTX_end(ctx: CPointer<Unit>): Unit
foreign func BN_uadd(r: CPointer<BigNumSt>, a: CPointer<BigNumSt>, b: CPointer<BigNumSt>): Int32
foreign func BN_add_word(a: CPointer<BigNumSt>, w: UInt64): Int32
foreign func BN_usub(r: CPointer<BigNumSt>, a: CPointer<BigNumSt>, b: CPointer<BigNumSt>): Int32
foreign func BN_sub_word(a: CPointer<BigNumSt>, w: UInt64): Int32
foreign func BN_mul_word(bn: CPointer<BigNumSt>, w: UInt64): Int32
foreign func BN_sqr(r: CPointer<BigNumSt>, a: CPointer<BigNumSt>, ctx: CPointer<Unit>): Int32
foreign func BN_div_word(numerator: CPointer<BigNumSt>, divisor: UInt64): UInt64
foreign func BN_sqrt(out_sqrt: CPointer<BigNumSt>, in_: CPointer<BigNumSt>, ctx: CPointer<Unit>): Int32
foreign func BN_cmp(a: CPointer<BigNumSt>, b: CPointer<BigNumSt>): Int32
foreign func BN_cmp_word(a: CPointer<BigNumSt>, b: UInt64): Int32
foreign func BN_ucmp(a: CPointer<BigNumSt>, b: CPointer<BigNumSt>): Int32
foreign func BN_equal_consttime(a: CPointer<BigNumSt>, b: CPointer<BigNumSt>): Int32
foreign func BN_abs_is_word(bn: CPointer<BigNumSt>, w: UInt64): Int32
foreign func BN_is_zero(bn: CPointer<BigNumSt>): Int32
foreign func BN_is_one(bn: CPointer<BigNumSt>): Int32
foreign func BN_is_word(bn: CPointer<BigNumSt>, w: UInt64): Int32
foreign func BN_is_odd(bn: CPointer<BigNumSt>): Int32
foreign func BN_is_pow2(a: CPointer<BigNumSt>): Int32
foreign func BN_lshift(r: CPointer<BigNumSt>, a: CPointer<BigNumSt>, n: Int32): Int32
foreign func BN_lshift1(r: CPointer<BigNumSt>, a: CPointer<BigNumSt>): Int32
foreign func BN_rshift(r: CPointer<BigNumSt>, a: CPointer<BigNumSt>, n: Int32): Int32
foreign func BN_rshift1(r: CPointer<BigNumSt>, a: CPointer<BigNumSt>): Int32
foreign func BN_set_bit(a: CPointer<BigNumSt>, n: Int32): Int32
foreign func BN_clear_bit(a: CPointer<BigNumSt>, n: Int32): Int32
foreign func BN_is_bit_set(a: CPointer<BigNumSt>, n: Int32): Int32
foreign func BN_mask_bits(a: CPointer<BigNumSt>, n: Int32): Int32
foreign func BN_count_low_zero_bits(bn: CPointer<BigNumSt>): Int32
foreign func BN_mod_word(a: CPointer<BigNumSt>, w: UInt64): UInt64
foreign func BN_mod_pow2(r: CPointer<BigNumSt>, a: CPointer<BigNumSt>, e: UIntNative): Int32
foreign func BN_nnmod_pow2(r: CPointer<BigNumSt>, a: CPointer<BigNumSt>, e: UIntNative): Int32
foreign func BN_nnmod(rem: CPointer<BigNumSt>, numerator: CPointer<BigNumSt>, divisor: CPointer<BigNumSt>, ctx: CPointer<Unit>): Int32
foreign func BN_mod_add(r: CPointer<BigNumSt>, a: CPointer<BigNumSt>, b: CPointer<BigNumSt>, m: CPointer<BigNumSt>, ctx: CPointer<Unit>): Int32
foreign func BN_mod_add_quick(r: CPointer<BigNumSt>, a: CPointer<BigNumSt>, b: CPointer<BigNumSt>, m: CPointer<BigNumSt>): Int32
foreign func BN_mod_sub(r: CPointer<BigNumSt>, a: CPointer<BigNumSt>, b: CPointer<BigNumSt>, m: CPointer<BigNumSt>, ctx: CPointer<Unit>): Int32
foreign func BN_mod_sub_quick(r: CPointer<BigNumSt>, a: CPointer<BigNumSt>, b: CPointer<BigNumSt>, m: CPointer<BigNumSt>): Int32
foreign func BN_mod_sqr(r: CPointer<BigNumSt>, a: CPointer<BigNumSt>, m: CPointer<BigNumSt>, ctx: CPointer<Unit>): Int32
foreign func BN_mod_lshift(r: CPointer<BigNumSt>, a: CPointer<BigNumSt>, n: Int32, m: CPointer<BigNumSt>, ctx: CPointer<Unit>): Int32
foreign func BN_mod_lshift_quick(r: CPointer<BigNumSt>, a: CPointer<BigNumSt>, n: Int32, m: CPointer<BigNumSt>): Int32
foreign func BN_mod_lshift1(r: CPointer<BigNumSt>, a: CPointer<BigNumSt>, m: CPointer<BigNumSt>, ctx: CPointer<Unit>): Int32
foreign func BN_mod_lshift1_quick(r: CPointer<BigNumSt>, a: CPointer<BigNumSt>, m: CPointer<BigNumSt>): Int32
foreign func BN_mod_sqrt(in_: CPointer<BigNumSt>, a: CPointer<BigNumSt>, p: CPointer<BigNumSt>, ctx: CPointer<Unit>): CPointer<BigNumSt>
foreign func BN_pseudo_rand(rnd: CPointer<BigNumSt>, bits: Int32, top: Int32, bottom: Int32): Int32
foreign func BN_rand_range_ex(r: CPointer<BigNumSt>, min_inclusive: UInt64, max_exclusive: CPointer<BigNumSt>): Int32
foreign func BN_pseudo_rand_range(rnd: CPointer<BigNumSt>, range: CPointer<BigNumSt>): Int32
foreign func BN_GENCB_new(): CPointer<BnGencb>
foreign func BN_GENCB_free(callback: CPointer<BnGencb>): Unit
foreign func BN_GENCB_set(callback: CPointer<BnGencb>, f: CPointer<Unit>, arg: CPointer<Unit>): Unit
foreign func BN_GENCB_call(callback: CPointer<BnGencb>, event: Int32, n: Int32): Int32
foreign func BN_GENCB_get_arg(callback: CPointer<BnGencb>): CPointer<Unit>
foreign func BN_to_ASN1_INTEGER(bn: CPointer<BigNumSt>, ai: CPointer<Asn1StringSt>): CPointer<Asn1StringSt>
foreign func BN_to_ASN1_ENUMERATED(bn: CPointer<BigNumSt>, ai: CPointer<Asn1StringSt>): CPointer<Asn1StringSt>
foreign func BN_get_rfc3526_prime_1536(ret: CPointer<BigNumSt>): CPointer<BigNumSt>
foreign func BN_get_rfc3526_prime_2048(ret: CPointer<BigNumSt>): CPointer<BigNumSt>
foreign func BN_get_rfc3526_prime_3072(ret: CPointer<BigNumSt>): CPointer<BigNumSt>
foreign func BN_get_rfc3526_prime_4096(ret: CPointer<BigNumSt>): CPointer<BigNumSt>
foreign func BN_get_rfc3526_prime_6144(ret: CPointer<BigNumSt>): CPointer<BigNumSt>
foreign func BN_get_rfc3526_prime_8192(ret: CPointer<BigNumSt>): CPointer<BigNumSt>

// --- RSA 补充 ---
foreign func RSA_new_method(engine: CPointer<Unit>): CPointer<Unit>
foreign func RSA_get0_key(rsa: CPointer<Unit>, out_n: CPointer<CPointer<BigNumSt>>, out_e: CPointer<CPointer<BigNumSt>>, out_d: CPointer<CPointer<BigNumSt>>): Unit
foreign func RSA_get0_factors(rsa: CPointer<Unit>, out_p: CPointer<CPointer<BigNumSt>>, out_q: CPointer<CPointer<BigNumSt>>): Unit
foreign func RSA_get0_crt_params(rsa: CPointer<Unit>, out_dmp1: CPointer<CPointer<BigNumSt>>, out_dmq1: CPointer<CPointer<BigNumSt>>, out_iqmp: CPointer<CPointer<BigNumSt>>): Unit
foreign func RSA_set0_key(rsa: CPointer<Unit>, n: CPointer<BigNumSt>, e: CPointer<BigNumSt>, d: CPointer<BigNumSt>): Int32
foreign func RSA_set0_factors(rsa: CPointer<Unit>, p: CPointer<BigNumSt>, q: CPointer<BigNumSt>): Int32
foreign func RSA_set0_crt_params(rsa: CPointer<Unit>, dmp1: CPointer<BigNumSt>, dmq1: CPointer<BigNumSt>, iqmp: CPointer<BigNumSt>): Int32
foreign func RSA_generate_key_fips(rsa: CPointer<Unit>, bits: Int32, cb: CPointer<BnGencb>): Int32
foreign func RSA_encrypt(rsa: CPointer<Unit>, out_len: CPointer<UIntNative>, out: CPointer<UInt8>, max_out: UIntNative, in_: CPointer<UInt8>, in_len: UIntNative, padding: Int32): Int32
foreign func RSA_decrypt(rsa: CPointer<Unit>, out_len: CPointer<UIntNative>, out: CPointer<UInt8>, max_out: UIntNative, in_: CPointer<UInt8>, in_len: UIntNative, padding: Int32): Int32
foreign func RSA_sign_pss_mgf1(rsa: CPointer<Unit>, out_len: CPointer<UIntNative>, out: CPointer<UInt8>, max_out: UIntNative, digest: CPointer<UInt8>, digest_len: UIntNative, md: CPointer<Unit>, mgf1_md: CPointer<Unit>, salt_len: Int32): Int32
foreign func RSA_sign_raw(rsa: CPointer<Unit>, out_len: CPointer<UIntNative>, out: CPointer<UInt8>, max_out: UIntNative, in_: CPointer<UInt8>, in_len: UIntNative, padding: Int32): Int32
foreign func RSA_verify_pss_mgf1(rsa: CPointer<Unit>, digest: CPointer<UInt8>, digest_len: UIntNative, md: CPointer<Unit>, mgf1_md: CPointer<Unit>, salt_len: Int32, sig: CPointer<UInt8>, sig_len: UIntNative): Int32
foreign func RSA_verify_raw(rsa: CPointer<Unit>, out_len: CPointer<UIntNative>, out: CPointer<UInt8>, max_out: UIntNative, in_: CPointer<UInt8>, in_len: UIntNative, padding: Int32): Int32
foreign func RSA_is_opaque(rsa: CPointer<Unit>): Int32
foreign func RSA_check_key(rsa: CPointer<Unit>): Int32
foreign func RSA_check_fips(key: CPointer<Unit>): Int32
foreign func RSA_verify_PKCS1_PSS_mgf1(rsa: CPointer<Unit>, mHash: CPointer<UInt8>, Hash: CPointer<Unit>, mgf1Hash: CPointer<Unit>, EM: CPointer<UInt8>, sLen: Int32): Int32
foreign func RSA_padding_add_PKCS1_PSS_mgf1(rsa: CPointer<Unit>, EM: CPointer<UInt8>, mHash: CPointer<UInt8>, Hash: CPointer<Unit>, mgf1Hash: CPointer<Unit>, sLen: Int32): Int32
foreign func RSA_padding_add_PKCS1_OAEP_mgf1(to: CPointer<UInt8>, to_len: UIntNative, from: CPointer<UInt8>, from_len: UIntNative, param: CPointer<UInt8>, param_len: UIntNative, md: CPointer<Unit>, mgf1md: CPointer<Unit>): Int32
foreign func RSA_add_pkcs1_prefix(out_msg: CPointer<CPointer<UInt8>>, out_msg_len: CPointer<UIntNative>, is_alloced: CPointer<Int32>, hash_nid: Int32, digest: CPointer<UInt8>, digest_len: UIntNative): Int32
foreign func RSA_parse_public_key(cbs: CPointer<CbsSt>): CPointer<Unit>
foreign func RSA_public_key_from_bytes(in_: CPointer<UInt8>, in_len: UIntNative): CPointer<Unit>
foreign func RSA_marshal_public_key(cbb: CPointer<Unit>, rsa: CPointer<Unit>): Int32
foreign func RSA_public_key_to_bytes(out_bytes: CPointer<CPointer<UInt8>>, out_len: CPointer<UIntNative>, rsa: CPointer<Unit>): Int32
foreign func RSA_parse_private_key(cbs: CPointer<CbsSt>): CPointer<Unit>
foreign func RSA_private_key_from_bytes(in_: CPointer<UInt8>, in_len: UIntNative): CPointer<Unit>
foreign func RSA_marshal_private_key(cbb: CPointer<Unit>, rsa: CPointer<Unit>): Int32
foreign func RSA_private_key_to_bytes(out_bytes: CPointer<CPointer<UInt8>>, out_len: CPointer<UIntNative>, rsa: CPointer<Unit>): Int32
foreign func RSA_get_ex_new_index(argl: Int64, argp: CPointer<Unit>, unused: CPointer<Unit>, dup_unused: CPointer<Unit>, free_func: CPointer<Unit>): Int32
foreign func RSA_set_ex_data(rsa: CPointer<Unit>, idx: Int32, arg: CPointer<Unit>): Int32
foreign func RSA_get_ex_data(rsa: CPointer<Unit>, idx: Int32): CPointer<Unit>
foreign func RSA_flags(rsa: CPointer<Unit>): Int32
foreign func RSA_test_flags(rsa: CPointer<Unit>, flags: Int32): Int32
foreign func RSA_blinding_on(rsa: CPointer<Unit>, ctx: CPointer<Unit>): Int32
foreign func RSA_padding_add_PKCS1_PSS(rsa: CPointer<Unit>, EM: CPointer<UInt8>, mHash: CPointer<UInt8>, Hash: CPointer<Unit>, sLen: Int32): Int32
foreign func RSA_verify_PKCS1_PSS(rsa: CPointer<Unit>, mHash: CPointer<UInt8>, Hash: CPointer<Unit>, EM: CPointer<UInt8>, sLen: Int32): Int32
foreign func RSA_padding_add_PKCS1_OAEP(to: CPointer<UInt8>, to_len: UIntNative, from: CPointer<UInt8>, from_len: UIntNative, param: CPointer<UInt8>, param_len: UIntNative): Int32
foreign func RSA_print(bio: CPointer<Unit>, rsa: CPointer<Unit>, indent: Int32): Int32
foreign func RSA_get0_pss_params(rsa: CPointer<Unit>): CPointer<RsaPssParams>
foreign func RSA_PSS_PARAMS_new(): CPointer<RsaPssParams>
foreign func RSA_PSS_PARAMS_free(a: CPointer<RsaPssParams>): Unit
foreign func RSAPrivateKey_dup(rsa: CPointer<Unit>): CPointer<Unit>
foreign func RSAPublicKey_dup(rsa: CPointer<Unit>): CPointer<Unit>

// --- DSA ---
foreign func DSA_new(): CPointer<DSA>
foreign func DSA_free(dsa: CPointer<DSA>): Unit
foreign func DSA_up_ref(dsa: CPointer<DSA>): Int32
foreign func DSA_bits(dsa: CPointer<DSA>): UInt32
foreign func DSA_get0_pub_key(dsa: CPointer<DSA>): CPointer<BigNumSt>
foreign func DSA_get0_priv_key(dsa: CPointer<DSA>): CPointer<BigNumSt>
foreign func DSA_get0_p(dsa: CPointer<DSA>): CPointer<BigNumSt>
foreign func DSA_get0_q(dsa: CPointer<DSA>): CPointer<BigNumSt>
foreign func DSA_get0_g(dsa: CPointer<DSA>): CPointer<BigNumSt>
foreign func DSA_get0_key(dsa: CPointer<DSA>, out_pub_key: CPointer<CPointer<BigNumSt>>, out_priv_key: CPointer<CPointer<BigNumSt>>): Unit
foreign func DSA_get0_pqg(dsa: CPointer<DSA>, out_p: CPointer<CPointer<BigNumSt>>, out_q: CPointer<CPointer<BigNumSt>>, out_g: CPointer<CPointer<BigNumSt>>): Unit
foreign func DSA_set0_key(dsa: CPointer<DSA>, pub_key: CPointer<BigNumSt>, priv_key: CPointer<BigNumSt>): Int32
foreign func DSA_set0_pqg(dsa: CPointer<DSA>, p: CPointer<BigNumSt>, q: CPointer<BigNumSt>, g: CPointer<BigNumSt>): Int32
foreign func DSA_generate_parameters_ex(dsa: CPointer<DSA>, bits: UInt32, seed: CPointer<UInt8>, seed_len: UIntNative, out_counter: CPointer<Int32>, out_h: CPointer<UInt64>, cb: CPointer<BnGencb>): Int32
foreign func DSA_generate_key(dsa: CPointer<DSA>): Int32
foreign func DSA_SIG_new(): CPointer<DsaSigSt>
foreign func DSA_SIG_free(sig: CPointer<DsaSigSt>): Unit
foreign func DSA_SIG_get0(sig: CPointer<DsaSigSt>, out_r: CPointer<CPointer<BigNumSt>>, out_s: CPointer<CPointer<BigNumSt>>): Unit
foreign func DSA_SIG_set0(sig: CPointer<DsaSigSt>, r: CPointer<BigNumSt>, s: CPointer<BigNumSt>): Int32
foreign func DSA_do_sign(digest: CPointer<UInt8>, digest_len: UIntNative, dsa: CPointer<DSA>): CPointer<DsaSigSt>
foreign func DSA_do_verify(digest: CPointer<UInt8>, digest_len: UIntNative, sig: CPointer<DsaSigSt>, dsa: CPointer<DSA>): Int32
foreign func DSA_do_check_signature(out_valid: CPointer<Int32>, digest: CPointer<UInt8>, digest_len: UIntNative, sig: CPointer<DsaSigSt>, dsa: CPointer<DSA>): Int32
foreign func DSA_sign(type_: Int32, digest: CPointer<UInt8>, digest_len: UIntNative, out_sig: CPointer<UInt8>, out_siglen: CPointer<UInt32>, dsa: CPointer<DSA>): Int32
foreign func DSA_verify(type_: Int32, digest: CPointer<UInt8>, digest_len: UIntNative, sig: CPointer<UInt8>, sig_len: UIntNative, dsa: CPointer<DSA>): Int32
foreign func DSA_check_signature(out_valid: CPointer<Int32>, digest: CPointer<UInt8>, digest_len: UIntNative, sig: CPointer<UInt8>, sig_len: UIntNative, dsa: CPointer<DSA>): Int32
foreign func DSA_size(dsa: CPointer<DSA>): Int32
foreign func DSA_SIG_parse(cbs: CPointer<CbsSt>): CPointer<DsaSigSt>
foreign func DSA_SIG_marshal(cbb: CPointer<Unit>, sig: CPointer<DsaSigSt>): Int32
foreign func DSA_parse_public_key(cbs: CPointer<CbsSt>): CPointer<DSA>
foreign func DSA_marshal_public_key(cbb: CPointer<Unit>, dsa: CPointer<DSA>): Int32
foreign func DSA_parse_private_key(cbs: CPointer<CbsSt>): CPointer<DSA>
foreign func DSA_marshal_private_key(cbb: CPointer<Unit>, dsa: CPointer<DSA>): Int32
foreign func DSA_parse_parameters(cbs: CPointer<CbsSt>): CPointer<DSA>
foreign func DSA_marshal_parameters(cbb: CPointer<Unit>, dsa: CPointer<DSA>): Int32
foreign func DSA_dup_DH(dsa: CPointer<DSA>): CPointer<Unit>
foreign func DSA_get_ex_new_index(argl: Int64, argp: CPointer<Unit>, unused: CPointer<Unit>, dup_unused: CPointer<Unit>, free_func: CPointer<Unit>): Int32
foreign func DSA_set_ex_data(dsa: CPointer<DSA>, idx: Int32, arg: CPointer<Unit>): Int32
foreign func DSA_get_ex_data(dsa: CPointer<DSA>, idx: Int32): CPointer<Unit>
foreign func DSA_generate_parameters(bits: Int32, seed: CPointer<UInt8>, seed_len: Int32, counter_ret: CPointer<Int32>, h_ret: CPointer<UInt64>, callback: CPointer<Unit>, cb_arg: CPointer<Unit>): CPointer<DSA>
foreign func DSAparams_dup(dsa: CPointer<Unit>): CPointer<Unit>
foreign func i2o_ECPublicKey(key: CPointer<Unit>, outp: CPointer<CPointer<UInt8>>): Int32
foreign func o2i_ECPublicKey(key: CPointer<CPointer<Unit>>, pp: CPointer<CPointer<UInt8>>, length: Int64): CPointer<Unit>

// --- DH 补充 ---
foreign func DH_up_ref(dh: CPointer<Unit>): Int32
foreign func DH_bits(dh: CPointer<Unit>): UInt32
foreign func DH_get0_pub_key(dh: CPointer<Unit>): CPointer<BigNumSt>
foreign func DH_get0_priv_key(dh: CPointer<Unit>): CPointer<BigNumSt>
foreign func DH_get0_p(dh: CPointer<Unit>): CPointer<BigNumSt>
foreign func DH_get0_q(dh: CPointer<Unit>): CPointer<BigNumSt>
foreign func DH_get0_g(dh: CPointer<Unit>): CPointer<BigNumSt>
foreign func DH_get0_key(dh: CPointer<Unit>, out_pub_key: CPointer<CPointer<BigNumSt>>, out_priv_key: CPointer<CPointer<BigNumSt>>): Unit
foreign func DH_set0_key(dh: CPointer<Unit>, pub_key: CPointer<BigNumSt>, priv_key: CPointer<BigNumSt>): Int32
foreign func DH_get0_pqg(dh: CPointer<Unit>, out_p: CPointer<CPointer<BigNumSt>>, out_q: CPointer<CPointer<BigNumSt>>, out_g: CPointer<CPointer<BigNumSt>>): Unit
foreign func DH_set0_pqg(dh: CPointer<Unit>, p: CPointer<BigNumSt>, q: CPointer<BigNumSt>, g: CPointer<BigNumSt>): Int32
foreign func DH_set_length(dh: CPointer<Unit>, priv_length: UInt32): Int32
foreign func DH_get_rfc7919_2048(): CPointer<Unit>
foreign func DH_generate_parameters_ex(dh: CPointer<Unit>, prime_bits: Int32, generator: Int32, cb: CPointer<BnGencb>): Int32
foreign func DH_compute_key_padded(out: CPointer<UInt8>, peers_key: CPointer<BigNumSt>, dh: CPointer<Unit>): Int32
foreign func DH_compute_key_hashed(dh: CPointer<Unit>, out: CPointer<UInt8>, out_len: CPointer<UIntNative>, max_out_len: UIntNative, peers_key: CPointer<BigNumSt>, digest: CPointer<Unit>): Int32
foreign func DH_size(dh: CPointer<Unit>): Int32
foreign func DH_num_bits(dh: CPointer<Unit>): UInt32
foreign func DH_check(dh: CPointer<Unit>, out_flags: CPointer<Int32>): Int32
foreign func DH_check_pub_key(dh: CPointer<Unit>, pub_key: CPointer<BigNumSt>, out_flags: CPointer<Int32>): Int32
foreign func DH_parse_parameters(cbs: CPointer<CbsSt>): CPointer<Unit>
foreign func DH_marshal_parameters(cbb: CPointer<Unit>, dh: CPointer<Unit>): Int32
foreign func DH_generate_parameters(prime_len: Int32, generator: Int32, callback: CPointer<Unit>, cb_arg: CPointer<Unit>): CPointer<Unit>
foreign func DHparams_dup(dh: CPointer<Unit>): CPointer<Unit>

// --- EC 补充 ---
foreign func EC_GROUP_dup(a: CPointer<Unit>): CPointer<Unit>
foreign func EC_GROUP_cmp(a: CPointer<Unit>, b: CPointer<Unit>, ignored: CPointer<Unit>): Int32
foreign func EC_GROUP_get0_generator(group: CPointer<Unit>): CPointer<Unit>
foreign func EC_GROUP_get0_order(group: CPointer<Unit>): CPointer<BigNumSt>
foreign func EC_GROUP_order_bits(group: CPointer<Unit>): Int32
foreign func EC_GROUP_get_cofactor(group: CPointer<Unit>, cofactor: CPointer<BigNumSt>, ctx: CPointer<Unit>): Int32
foreign func EC_GROUP_get_curve_GFp(group: CPointer<Unit>, out_p: CPointer<BigNumSt>, out_a: CPointer<BigNumSt>, out_b: CPointer<BigNumSt>, ctx: CPointer<Unit>): Int32
foreign func EC_curve_nid2nist(nid: Int32): CString
foreign func EC_curve_nist2nid(name: CString): Int32
foreign func EC_GROUP_new_curve_GFp(p: CPointer<BigNumSt>, a: CPointer<BigNumSt>, b: CPointer<BigNumSt>, ctx: CPointer<Unit>): CPointer<Unit>
foreign func EC_GROUP_method_of(group: CPointer<Unit>): CPointer<Unit>
foreign func EC_GROUP_get_asn1_flag(group: CPointer<Unit>): Int32
foreign func EC_GROUP_set_asn1_flag(group: CPointer<Unit>, flag: Int32): Unit
foreign func EC_GROUP_set_generator(group: CPointer<Unit>, generator: CPointer<Unit>, order: CPointer<BigNumSt>, cofactor: CPointer<BigNumSt>): Int32
foreign func EC_GROUP_set_point_conversion_form(group: CPointer<Unit>, form: Int32): Unit
foreign func EC_METHOD_get_field_type(method: CPointer<Unit>): Int32
foreign func EC_get_builtin_curves(r: CPointer<Unit>, n: UIntNative): UIntNative
foreign func EC_POINT_copy(dest: CPointer<Unit>, src: CPointer<Unit>): Int32
foreign func EC_POINT_dup(src: CPointer<Unit>, group: CPointer<Unit>): CPointer<Unit>
foreign func EC_POINT_set_to_infinity(group: CPointer<Unit>, point: CPointer<Unit>): Int32
foreign func EC_POINT_is_at_infinity(group: CPointer<Unit>, point: CPointer<Unit>): Int32
foreign func EC_POINT_is_on_curve(group: CPointer<Unit>, point: CPointer<Unit>, ctx: CPointer<Unit>): Int32
foreign func EC_POINT_cmp(group: CPointer<Unit>, a: CPointer<Unit>, b: CPointer<Unit>, ctx: CPointer<Unit>): Int32
foreign func EC_POINT_get_affine_coordinates_GFp(group: CPointer<Unit>, point: CPointer<Unit>, x: CPointer<BigNumSt>, y: CPointer<BigNumSt>, ctx: CPointer<Unit>): Int32
foreign func EC_POINT_get_affine_coordinates(group: CPointer<Unit>, point: CPointer<Unit>, x: CPointer<BigNumSt>, y: CPointer<BigNumSt>, ctx: CPointer<Unit>): Int32
foreign func EC_POINT_set_affine_coordinates_GFp(group: CPointer<Unit>, point: CPointer<Unit>, x: CPointer<BigNumSt>, y: CPointer<BigNumSt>, ctx: CPointer<Unit>): Int32
foreign func EC_POINT_set_affine_coordinates(group: CPointer<Unit>, point: CPointer<Unit>, x: CPointer<BigNumSt>, y: CPointer<BigNumSt>, ctx: CPointer<Unit>): Int32
foreign func EC_POINT_point2buf(group: CPointer<Unit>, point: CPointer<Unit>, form: Int32, out_buf: CPointer<CPointer<UInt8>>, ctx: CPointer<Unit>): UIntNative
foreign func EC_POINT_point2cbb(out: CPointer<Unit>, group: CPointer<Unit>, point: CPointer<Unit>, form: Int32, ctx: CPointer<Unit>): Int32
foreign func EC_POINT_set_compressed_coordinates_GFp(group: CPointer<Unit>, point: CPointer<Unit>, x: CPointer<BigNumSt>, y_bit: Int32, ctx: CPointer<Unit>): Int32
foreign func EC_POINT_add(group: CPointer<Unit>, r: CPointer<Unit>, a: CPointer<Unit>, b: CPointer<Unit>, ctx: CPointer<Unit>): Int32
foreign func EC_POINT_dbl(group: CPointer<Unit>, r: CPointer<Unit>, a: CPointer<Unit>, ctx: CPointer<Unit>): Int32
foreign func EC_POINT_invert(group: CPointer<Unit>, point: CPointer<Unit>, ctx: CPointer<Unit>): Int32
foreign func EC_POINT_mul(group: CPointer<Unit>, r: CPointer<Unit>, n: CPointer<BigNumSt>, q: CPointer<Unit>, m: CPointer<BigNumSt>, ctx: CPointer<Unit>): Int32
foreign func EC_POINT_clear_free(point: CPointer<Unit>): Unit
foreign func EC_KEY_new_method(engine: CPointer<Unit>): CPointer<Unit>
foreign func EC_KEY_get0_private_key(key: CPointer<Unit>): CPointer<BigNumSt>
foreign func EC_KEY_set_private_key(key: CPointer<Unit>, priv: CPointer<BigNumSt>): Int32
foreign func EC_KEY_get_enc_flags(key: CPointer<Unit>): UInt32
foreign func EC_KEY_set_enc_flags(key: CPointer<Unit>, flags: UInt32): Unit
foreign func EC_KEY_get_conv_form(key: CPointer<Unit>): Int32
foreign func EC_KEY_set_conv_form(key: CPointer<Unit>, cform: Int32): Unit
foreign func EC_KEY_check_fips(key: CPointer<Unit>): Int32
foreign func EC_KEY_set_public_key_affine_coordinates(key: CPointer<Unit>, x: CPointer<BigNumSt>, y: CPointer<BigNumSt>): Int32
foreign func EC_KEY_oct2key(key: CPointer<Unit>, in_: CPointer<UInt8>, len: UIntNative, ctx: CPointer<Unit>): Int32
foreign func EC_KEY_key2buf(key: CPointer<Unit>, form: Int32, out_buf: CPointer<CPointer<UInt8>>, ctx: CPointer<Unit>): UIntNative
foreign func EC_KEY_oct2priv(key: CPointer<Unit>, in_: CPointer<UInt8>, len: UIntNative): Int32
foreign func EC_KEY_priv2oct(key: CPointer<Unit>, out: CPointer<UInt8>, max_out: UIntNative): UIntNative
foreign func EC_KEY_priv2buf(key: CPointer<Unit>, out_buf: CPointer<CPointer<UInt8>>): UIntNative
foreign func EC_KEY_generate_key_fips(key: CPointer<Unit>): Int32
foreign func EC_KEY_derive_from_secret(group: CPointer<Unit>, secret: CPointer<UInt8>, secret_len: UIntNative): CPointer<Unit>
foreign func EC_KEY_parse_private_key(cbs: CPointer<CbsSt>, group: CPointer<Unit>): CPointer<Unit>
foreign func EC_KEY_marshal_private_key(cbb: CPointer<Unit>, key: CPointer<Unit>, enc_flags: UInt32): Int32
foreign func EC_KEY_parse_curve_name(cbs: CPointer<CbsSt>): CPointer<Unit>
foreign func EC_KEY_marshal_curve_name(cbb: CPointer<Unit>, group: CPointer<Unit>): Int32
foreign func EC_KEY_parse_parameters(cbs: CPointer<CbsSt>): CPointer<Unit>
foreign func EC_KEY_get_ex_new_index(argl: Int64, argp: CPointer<Unit>, unused: CPointer<Unit>, dup_unused: CPointer<Unit>, free_func: CPointer<Unit>): Int32
foreign func EC_KEY_set_ex_data(r: CPointer<Unit>, idx: Int32, arg: CPointer<Unit>): Int32
foreign func EC_KEY_get_ex_data(r: CPointer<Unit>, idx: Int32): CPointer<Unit>
foreign func EC_KEY_set_asn1_flag(key: CPointer<Unit>, flag: Int32): Unit
foreign func EC_KEY_is_opaque(key: CPointer<Unit>): Int32

// --- ECDSA 补充 ---
foreign func ECDSA_SIG_get0_r(sig: CPointer<EcdsaSig>): CPointer<BigNumSt>
foreign func ECDSA_SIG_get0_s(sig: CPointer<EcdsaSig>): CPointer<BigNumSt>
foreign func ECDSA_SIG_get0(sig: CPointer<EcdsaSig>, out_r: CPointer<CPointer<BigNumSt>>, out_s: CPointer<CPointer<BigNumSt>>): Unit
foreign func ECDSA_SIG_parse(cbs: CPointer<CbsSt>): CPointer<EcdsaSig>
foreign func ECDSA_SIG_from_bytes(in_: CPointer<UInt8>, in_len: UIntNative): CPointer<EcdsaSig>
foreign func ECDSA_SIG_marshal(cbb: CPointer<Unit>, sig: CPointer<EcdsaSig>): Int32
foreign func ECDSA_SIG_to_bytes(out_bytes: CPointer<CPointer<UInt8>>, out_len: CPointer<UIntNative>, sig: CPointer<EcdsaSig>): Int32
foreign func ECDSA_SIG_max_len(order_len: UIntNative): UIntNative
foreign func ECDSA_size(key: CPointer<Unit>): UIntNative
foreign func ECDSA_sign_with_nonce_and_leak_private_key_for_testing(digest: CPointer<UInt8>, digest_len: UIntNative, eckey: CPointer<Unit>, nonce: CPointer<UInt8>, nonce_len: UIntNative): CPointer<EcdsaSig>

// --- ECDH ---
foreign func ECDH_compute_key(out: CPointer<Unit>, outlen: UIntNative, pub_key: CPointer<Unit>, priv_key: CPointer<Unit>, kdf: CPointer<Unit>): Int32
foreign func ECDH_compute_key_fips(out: CPointer<UInt8>, out_len: UIntNative, pub_key: CPointer<Unit>, priv_key: CPointer<Unit>): Int32

// --- ENGINE ---
foreign func ENGINE_new(): CPointer<Unit>
foreign func ENGINE_free(engine: CPointer<Unit>): Int32
foreign func ENGINE_load_builtin_engines(): Unit
foreign func ENGINE_register_all_complete(): Int32
foreign func ENGINE_set_RSA_method(engine: CPointer<Unit>, method: CPointer<RsaMethod>, method_size: UIntNative): Int32
foreign func ENGINE_set_ECDSA_method(engine: CPointer<Unit>, method: CPointer<EcdsaMethod>, method_size: UIntNative): Int32
foreign func ENGINE_get_RSA_method(engine: CPointer<Unit>): CPointer<Unit>
foreign func ENGINE_get_ECDSA_method(engine: CPointer<Unit>): CPointer<Unit>
