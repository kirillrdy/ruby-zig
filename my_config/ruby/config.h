#ifndef RUBY_CONFIG_H
#define RUBY_CONFIG_H 1

#include <stdio.h>
#include <stdarg.h>

#define STDC_HEADERS 1
#define HAVE_STDLIB_H 1
#define HAVE_STRING_H 1
#define HAVE_MEMORY_H 1
#define HAVE_STDINT_H 1
#define HAVE_INTTYPES_H 1
#define HAVE_LIMITS_H 1
#define HAVE_FLOAT_H 1
#define HAVE_FCNTL_H 1
#define HAVE_TIME_H 1

#define HAVE_MEMMOVE 1
#define HAVE_GETCWD 1
#define HAVE_STRCHR 1
#define HAVE_STRERROR 1
#define HAVE_STRSTR 1
#define HAVE_TZSET 1
#define HAVE_SHUTDOWN 1
#define HAVE_EXECVE 1
#define HAVE_EXECL 1
#define HAVE_EXECLE 1
#define HAVE_DUP 1
#define HAVE_DUP2 1
#define HAVE_SYSTEM 1
#define HAVE_WAITPID 1
#define HAVE_GETUID 1
#define HAVE_GETEGID 1
#define HAVE_GETGID 1
#define HAVE_CHOWN 1

#ifndef _WIN32
#define HAVE_STRINGS_H 1
#define HAVE_UNISTD_H 1
#define HAVE_SYS_TYPES_H 1
#define HAVE_SYS_STAT_H 1
#define HAVE_SYS_FCNTL_H 1
#define HAVE_SYS_IOCTL_H 1
#define HAVE_SYS_PARAM_H 1
#define HAVE_SYS_SELECT_H 1
#define HAVE_SYS_TIME_H 1
#define HAVE_SYS_TIMES_H 1
#define HAVE_SYS_UIO_H 1
#define HAVE_SYS_WAIT_H 1
#define HAVE_UTIME_H 1
#define HAVE_DIRENT_H 1
#define HAVE_SYS_RESOURCE_H 1
#define HAVE_SYS_SOCKET_H 1
#define HAVE_ARPA_INET_H 1
#define HAVE_POLL 1
#define HAVE_CLOCK_GETTIME 1
#define HAVE_CLOCK_GETRES 1
#define HAVE_PTHREAD_H 1
#define THREAD_IMPL_H "thread_pthread.h"
#define THREAD_IMPL_SRC "thread_pthread.c"
#define DLEXT ".bundle"
#define rb_pid_t pid_t
#define rb_uid_t uid_t
#define rb_gid_t gid_t
#define rb_off_t off_t
#define SIZEOF_LONG 8
#define RB_THREAD_LOCAL_SPECIFIER __thread
#define PRI_LL_PREFIX "l"
#define PRI_PIDT_PREFIX ""
#define PRI_PTRDIFF_PREFIX "l"
#define PRI_SIZE_PREFIX "z"
#define GETGROUPS_T gid_t
#define HAVE_STRUCT_TIMESPEC 1
#define HAVE_STRUCT_TIMEZONE 1
#define HAVE_STRUCT_STAT_ST_BLKSIZE 1
#define HAVE_STRUCT_STAT_ST_BLOCKS 1
#define HAVE_GETTIMEOFDAY 1
#ifdef __APPLE__
#define HAVE_STRLCPY 1
#define HAVE_STRLCAT 1
#endif
#define HAVE_UMASK 1
#define HAVE_CHMOD 1
#define HAVE_LCHOWN 1
#define HAVE_FCHOWN 1
#define HAVE_FCHMOD 1
#define HAVE_LSTAT 1
#define HAVE_LINK 1
#define HAVE_SYMLINK 1
#define HAVE_READLINK 1
#define HAVE_REALPATH 1
#define HAVE_GETEUID 1
#define HAVE_GETPPID 1
#define HAVE_FLOCK 1
#define HAVE_GETPGRP 1
#define HAVE_SETPGRP 1
#define HAVE_GETPGID 1
#define HAVE_SETPGID 1
#define HAVE_GETSID 1
#define HAVE_SETSID 1
#define HAVE_GETPRIORITY 1
#define HAVE_GETRLIMIT 1
#define HAVE_SETRLIMIT 1
#define HAVE_CHROOT 1
#define HAVE_TRUNCATE 1
#define HAVE_FTRUNCATE 1
#define HAVE_STRUCT_STAT_ST_RDEV 1
#else
#define HAVE_DIRECT_H 1
#define HAVE_MALLOC_H 1
#define THREAD_IMPL_H "thread_win32.h"
#define THREAD_IMPL_SRC "thread_win32.c"
#define DLEXT ".dll"
#define rb_pid_t int
#define rb_uid_t int
#define rb_gid_t int
#define rb_off_t __int64
#define SIZEOF_LONG 4
#define HAVE_STRUCT_TIMESPEC 1
#define HAVE_STRUCT_TIMEZONE 1
#define PRI_LL_PREFIX "I64"
#define PRI_PIDT_PREFIX ""
#define PRI_PTRDIFF_PREFIX "I64"
#define PRI_SIZE_PREFIX "I64"
#define HAVE_UMASK 1
#define HAVE_CHMOD 1
#define HAVE_ACOSH 1
#define HAVE_ASINH 1
#define HAVE_ATANH 1
#define HAVE_CBRT 1
#define HAVE_ERF 1
#define HAVE_ROUND 1
#define HAVE_TGAMMA 1
#define HAVE_HYPOT 1
#define HAVE_NAN 1
#define HAVE_NEXTAFTER 1
#define HAVE_POPEN 1
#define HAVE_PCLOSE 1
#define EXECUTABLE_EXTS ".exe",".com",".cmd",".bat"
#define GETGROUPS_T int
#define HAVE_GETEUID 1
#define HAVE_CLOCK_GETTIME 1
#define HAVE_CLOCK_GETRES 1
#define HAVE_GETTIMEOFDAY 1
#define HAVE_TYPE_NET_LUID 1
#define HAVE_LSTAT 1
#endif

#define HAVE_STDBOOL_H 1
#define HAVE__BOOL 1

#undef __LZCNT__
#undef __BMI__
#undef __BMI2__

#define __EXTENSIONS__ 1
#define _DARWIN_C_SOURCE 1
#define _GNU_SOURCE 1

#define HAVE_LONG_LONG 1
#define rb_mode_t mode_t

#define SIZEOF_INT 4
#define SIZEOF_SHORT 2
#define SIZEOF_LONG_LONG 8
#define SIZEOF_VOIDP 8
#define SIZEOF_SIZE_T 8
#define SIZEOF_TIME_T 8
#define SIZEOF_UINTPTR_T 8
#define SIZEOF_OFF_T 8

#define HAVE_PROTOTYPES 1
#ifndef TOKEN_PASTE
#define TOKEN_PASTE(x,y) x##y
#endif
#define HAVE_STDARG_PROTOTYPES 1
#define HAVE_TYPEOF 1
#define HAVE_STRUCT_TIMEVAL 1

#define HAVE_VA_ARGS_MACRO 1
#define HAVE_STMT_AND_DECL_IN_EXPR 1

#ifndef RUBY_PLATFORM
#define RUBY_PLATFORM "arm64-darwin"
#endif
#ifndef RUBY_ARCH
#define RUBY_ARCH "arm64-darwin"
#endif

#ifndef _WIN32
#ifdef __APPLE__
#define HAVE_BACKTRACE 1
#endif
#endif
#define HAVE_GCC_ATOMIC_BUILTINS 1
#define HAVE_GCC_SYNC_BUILTINS 1
#define HAVE_STDATOMIC_H 1

#ifndef COROUTINE_H
#define COROUTINE_H "coroutine/arm64/Context.h"
#endif
#ifndef RUBY_JMP_BUF
#define RUBY_JMP_BUF jmp_buf
#endif

#define DLEXT2 ".so"

#ifndef RSHIFT
#define RSHIFT(x,y) ((x)>>(int)(y))
#endif

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

#ifndef STATIC_ASSERT
#define STATIC_ASSERT(name, expr) _Static_assert(expr, #name)
#endif

#define UINT64T2NUM(v) ULL2NUM(v)

// Force Ruby's xmalloc globally to avoid conflicts with Onigmo
#ifndef xmalloc
#define xmalloc ruby_xmalloc
#endif
#ifndef xcalloc
#define xcalloc ruby_xcalloc
#endif
#ifndef xrealloc
#define xrealloc ruby_xrealloc
#endif
#ifndef xfree
#define xfree ruby_xfree
#endif

#define NDEBUG 1
#ifndef is_power_of_two
#define is_power_of_two(x) (((x) & ((x) - 1)) == 0)
#endif

#ifdef __APPLE__
#define HAVE_STRUCT_STAT_ST_ATIMESPEC 1
#define HAVE_STRUCT_STAT_ST_MTIMESPEC 1
#define HAVE_STRUCT_STAT_ST_CTIMESPEC 1
#elif !defined(_WIN32)
#define HAVE_STRUCT_STAT_ST_ATIM 1
#define HAVE_STRUCT_STAT_ST_MTIM 1
#define HAVE_STRUCT_STAT_ST_CTIM 1
#define HAVE_MEMRCHR 1
#endif

#endif
