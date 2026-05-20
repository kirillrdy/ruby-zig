#ifndef RUBY_CONFIG_H
#define RUBY_CONFIG_H 1

#include <stdio.h>

#define STDC_HEADERS 1
#define HAVE_STRING_H 1
#define HAVE_STDINT_H 1
#define HAVE_LIMITS_H 1
#define HAVE_FLOAT_H 1
#define HAVE_FCNTL_H 1
#if defined(__x86_64__) || defined(__i386__)
#define HAVE_X86INTRIN_H 1
#endif

#define HAVE_MEMMOVE 1
#define HAVE_GETCWD 1
#define HAVE_STRCHR 1
#define HAVE_STRSTR 1
#define HAVE_SHUTDOWN 1
#define HAVE_CLOCK_GETTIME 1
#define HAVE_CLOCK_GETRES 1
#define HAVE_STRUCT_TIMESPEC 1
#define HAVE_STRUCT_TIMEZONE 1
#define HAVE_UMASK 1
#define HAVE_CHMOD 1
#define HAVE_LSTAT 1

#ifndef _WIN32
#define HAVE_UNISTD_H 1
#define HAVE_DIRENT_H 1
#define HAVE_POLL 1
#define HAVE_PTHREAD_H 1
#define HAVE_WORKING_FORK 1
#define THREAD_IMPL_H "thread_pthread.h"
#define THREAD_IMPL_SRC "thread_pthread.c"
#ifdef __APPLE__
#define DLEXT ".bundle"
#else
#define DLEXT ".so"
#endif
#define rb_pid_t pid_t
#define rb_uid_t uid_t
#define rb_gid_t gid_t
#define rb_off_t off_t
#define SIZEOF_LONG 8
#define RB_THREAD_LOCAL_SPECIFIER __thread
#define PRI_LL_PREFIX "l"
#define PRI_PTRDIFF_PREFIX "l"
#define GETGROUPS_T gid_t
#ifdef __APPLE__
#define HAVE_STRLCPY 1
#define HAVE_STRLCAT 1
#endif
#else
#define THREAD_IMPL_H "thread_win32.h"
#define THREAD_IMPL_SRC "thread_win32.c"
#define DLEXT ".dll"
#define rb_pid_t int
#define rb_uid_t int
#define rb_gid_t int
#define rb_off_t __int64
#define SIZEOF_LONG 4
#define PRI_LL_PREFIX "I64"
#define PRI_PTRDIFF_PREFIX "I64"
#define EXECUTABLE_EXTS ".exe",".com",".cmd",".bat"
#define GETGROUPS_T int
#define HAVE_TYPE_NET_LUID 1
#endif

#define HAVE_LONG_LONG 1

#define SIZEOF_INT 4
#define SIZEOF_SHORT 2
#define SIZEOF_LONG_LONG 8
#define SIZEOF_VOIDP 8
#define SIZEOF_SIZE_T 8
#define SIZEOF_TIME_T 8
#define SIZEOF_UINTPTR_T 8

#define HAVE_STRUCT_TIMEVAL 1

#define HAVE_STDATOMIC_H 1

#define RUBY_JMP_BUF jmp_buf

#define RSHIFT(x,y) ((x)>>(int)(y))

#define TIMET_MAX LONG_MAX
#define TIMET_MIN LONG_MIN
#define TIMET2NUM(v) LONG2NUM(v)
#define NUM2TIMET(v) NUM2LONG(v)

#ifdef _WIN32
#define RUBY_SETJMP(env) setjmp(env)
#define RUBY_LONGJMP(env,val) longjmp(env,val)
#else
#define RUBY_SETJMP(env) _setjmp(env)
#define RUBY_LONGJMP(env,val) _longjmp(env,val)
#endif

#define RUBY_FUNCTION_NAME_STRING __func__
#define ruby_posix_signal signal

typedef unsigned long unsigned_clock_t;

#define UINT64T2NUM(v) ULL2NUM(v)

#define NDEBUG 1

#ifdef __APPLE__
#define HAVE_STRUCT_STAT_ST_ATIMESPEC 1
#elif !defined(_WIN32)
#define HAVE_STRUCT_STAT_ST_ATIM 1
#define HAVE_MEMRCHR 1
#endif

#endif
