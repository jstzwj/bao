/*
 * Sanitizer stubs — Bun's bmalloc.a was compiled with sanitizer support.
 * These stubs provide the required symbols without the full sanitizer runtime.
 */

/* ASan stubs */
void __asan_init(void) {}
void __asan_report_load1(void *p) { (void)p; }
void __asan_report_load2(void *p) { (void)p; }
void __asan_report_load4(void *p) { (void)p; }
void __asan_report_load8(void *p) { (void)p; }
void __asan_report_load16(void *p) { (void)p; }
void __asan_report_store1(void *p) { (void)p; }
void __asan_report_store2(void *p) { (void)p; }
void __asan_report_store4(void *p) { (void)p; }
void __asan_report_store8(void *p) { (void)p; }
void __asan_report_store16(void *p) { (void)p; }
void __asan_load1(void *p) { (void)p; }
void __asan_load2(void *p) { (void)p; }
void __asan_load4(void *p) { (void)p; }
void __asan_load8(void *p) { (void)p; }
void __asan_load16(void *p) { (void)p; }
void __asan_store1(void *p) { (void)p; }
void __asan_store2(void *p) { (void)p; }
void __asan_store4(void *p) { (void)p; }
void __asan_store8(void *p) { (void)p; }
void __asan_store16(void *p) { (void)p; }
void __asan_report_load_n(void *p, unsigned long size) { (void)p; (void)size; }
void __asan_report_store_n(void *p, unsigned long size) { (void)p; (void)size; }
void __asan_loadN(void *p, unsigned long size) { (void)p; (void)size; }
void __asan_storeN(void *p, unsigned long size) { (void)p; (void)size; }
void *__asan_region_is_poisoned(void *p, unsigned long size) { (void)p; (void)size; return 0; }
void __asan_unpoison_memory_region(void *p, unsigned long size) { (void)p; (void)size; }
void __asan_poison_memory_region(void *p, unsigned long size) { (void)p; (void)size; }
void __asan_unpoison_stack_memory(void *p, unsigned long size) { (void)p; (void)size; }
void __asan_poison_stack_memory(void *p, unsigned long size) { (void)p; (void)size; }
void __asan_handle_no_return(void) {}
void __asan_before_dynamic_init(void *module) { (void)module; }
void __asan_after_dynamic_init(void) {}
void __asan_register_globals(void *globals, unsigned long n) { (void)globals; (void)n; }
void __asan_unregister_globals(void *globals, unsigned long n) { (void)globals; (void)n; }

/* TSan stubs */
void __tsan_init(void) {}
void __tsan_func_entry(void *call_pc) { (void)call_pc; }
void __tsan_func_exit(void) {}
void __tsan_read1(void *p) { (void)p; }
void __tsan_read2(void *p) { (void)p; }
void __tsan_read4(void *p) { (void)p; }
void __tsan_read8(void *p) { (void)p; }
void __tsan_write1(void *p) { (void)p; }
void __tsan_write2(void *p) { (void)p; }
void __tsan_write4(void *p) { (void)p; }
void __tsan_write8(void *p) { (void)p; }
void __tsan_read_range(void *p, unsigned long size) { (void)p; (void)size; }
void __tsan_write_range(void *p, unsigned long size) { (void)p; (void)size; }
