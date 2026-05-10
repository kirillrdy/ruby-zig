#include <ruby.h>

// DTrace dummies
void RUBY_DTRACE_FIND_REQUIRE_ENTRY(const char *a, const char *b, int c) {}
int RUBY_DTRACE_FIND_REQUIRE_ENTRY_ENABLED(void) { return 0; }
void RUBY_DTRACE_FIND_REQUIRE_RETURN(const char *a, const char *b, int c) {}
int RUBY_DTRACE_FIND_REQUIRE_RETURN_ENABLED(void) { return 0; }
void RUBY_DTRACE_GC_MARK_BEGIN(void) {}
int RUBY_DTRACE_GC_MARK_BEGIN_ENABLED(void) { return 0; }
void RUBY_DTRACE_GC_MARK_END(void) {}
int RUBY_DTRACE_GC_MARK_END_ENABLED(void) { return 0; }
void RUBY_DTRACE_GC_SWEEP_BEGIN(void) {}
int RUBY_DTRACE_GC_SWEEP_BEGIN_ENABLED(void) { return 0; }
void RUBY_DTRACE_GC_SWEEP_END(void) {}
int RUBY_DTRACE_GC_SWEEP_END_ENABLED(void) { return 0; }
void RUBY_DTRACE_STRING_CREATE(const char *a, const char *b, int c) {}
int RUBY_DTRACE_STRING_CREATE_ENABLED(void) { return 0; }
void RUBY_DTRACE_SYMBOL_CREATE(const char *a, const char *b, int c) {}
int RUBY_DTRACE_SYMBOL_CREATE_ENABLED(void) { return 0; }
