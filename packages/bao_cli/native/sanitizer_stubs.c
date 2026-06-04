// Stubs for bmalloc's asan/tsan references
void __asan_init(void) {}
void __asan_unpoison_memory_region(void *p, unsigned long s) { (void)p;(void)s; }
void __asan_poison_memory_region(void *p, unsigned long s) { (void)p;(void)s; }
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
void __asan_report_load_n(void *p, unsigned long s) { (void)p;(void)s; }
void __asan_report_store_n(void *p, unsigned long s) { (void)p;(void)s; }
void __tsan_init(void) {}
void __tsan_read1(void *p) { (void)p; }
void __tsan_write1(void *p) { (void)p; }
void __tsan_read4(void *p) { (void)p; }
void __tsan_write4(void *p) { (void)p; }
void __tsan_read8(void *p) { (void)p; }
void __tsan_write8(void *p) { (void)p; }
void __tsan_read_range(void *p, unsigned long s) { (void)p;(void)s; }
void __tsan_write_range(void *p, unsigned long s) { (void)p;(void)s; }
void __tsan_func_entry(void *p) { (void)p; }
void __tsan_func_exit(void) {}
void __tsan_acquire(void *p) { (void)p; }
void __tsan_release(void *p) { (void)p; }
