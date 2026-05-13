const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const ruby_version = "4.0.4";
    const ruby_url = "https://cache.ruby-lang.org/pub/ruby/4.0/ruby-" ++ ruby_version ++ ".tar.gz";

    const fetch_ruby = b.addSystemCommand(&.{ "sh", "-c" });
    fetch_ruby.addArg(
        \\set -e
        \\curl -fsSL "$1" | tar xz -C "$2" --strip-components=1
    );
    fetch_ruby.addArg("sh");
    fetch_ruby.addArg(ruby_url);
    const ruby_src = fetch_ruby.addOutputDirectoryArg("ruby-src");

    const is_darwin = target.result.os.tag.isDarwin();
    const is_windows = target.result.os.tag == .windows;

    const ruby_platform = if (is_darwin)
        (if (target.result.cpu.arch == .aarch64) "arm64-darwin" else "x86_64-darwin")
    else if (is_windows)
        "x64-mingw32"
    else
        "x86_64-linux";

    const coroutine_h = if (target.result.cpu.arch == .aarch64)
        "coroutine/arm64/Context.h"
    else
        "coroutine/amd64/Context.h";

    const sdk_path = "/nix/store/rcqgjj8hphkhqark1ibiwfaa7yrzniz3-apple-sdk-14.4/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk";

    const exe = b.addExecutable(.{
        .name = "ruby",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });

    exe.root_module.addCMacro("RUBY_PLATFORM", b.fmt("\"{s}\"", .{ruby_platform}));
    exe.root_module.addCMacro("RUBY_ARCH", b.fmt("\"{s}\"", .{ruby_platform}));
    exe.root_module.addCMacro("COROUTINE_H", b.fmt("\"{s}\"", .{coroutine_h}));

    exe.root_module.addIncludePath(b.path("my_config"));
    exe.root_module.addIncludePath(b.path("my_config/ruby"));
    exe.root_module.addIncludePath(ruby_src.path(b, "include"));
    exe.root_module.addIncludePath(ruby_src.path(b, "."));
    exe.root_module.addIncludePath(ruby_src.path(b, "prism"));
    exe.root_module.addIncludePath(ruby_src.path(b, "enc/unicode/17.0.0"));
    exe.root_module.addIncludePath(b.path("shims"));

    if (is_darwin) {
        // Add SDK paths
        exe.root_module.addSystemIncludePath(.{ .cwd_relative = sdk_path ++ "/usr/include" });
        exe.root_module.addFrameworkPath(.{ .cwd_relative = sdk_path ++ "/System/Library/Frameworks" });
        exe.root_module.addLibraryPath(.{ .cwd_relative = sdk_path ++ "/usr/lib" });
    }

    const common_sources = &[_][]const u8{
        "array.c", "ast.c", "bignum.c", "class.c", "compar.c", "compile.c", "complex.c", "cont.c", "debug.c", "debug_counter.c", "dir.c", "dln_find.c", "encoding.c", "enum.c", "enumerator.c", "error.c", "eval.c", "file.c", "gc.c", "hash.c", "inits.c", "imemo.c", "io.c", "io_buffer.c", "iseq.c", "load.c", "marshal.c", "math.c", "memory_view.c", "concurrent_set.c", "box.c", "node.c", "node_dump.c", "numeric.c", "object.c", "pack.c", "parse.c", "parser_st.c", "proc.c", "process.c", "ractor.c", "random.c", "range.c", "rational.c", "re.c", "regcomp.c", "regenc.c", "regerror.c", "regexec.c", "regparse.c", "regsyntax.c", "ruby.c", "ruby_parser.c", "scheduler.c", "shape.c", "signal.c", "sprintf.c", "st.c", "strftime.c", "string.c", "struct.c", "symbol.c", "thread.c", "time.c", "transcode.c", "util.c", "variable.c", "version.c", "vm.c", "vm_backtrace.c", "vm_dump.c", "vm_sync.c", "vm_trace.c", "weakmap.c", "miniinit.c", "dmydln.c", "main.c", "set.c", "pathname.c",
    };

    const base_flags = &[_][]const u8{
        "-D_REENTRANT", "-std=gnu11", "-fcommon", "-DHAVE_CONFIG_H",
        "-Wno-implicit-function-declaration", "-Wno-int-conversion", "-Wno-incompatible-pointer-types", "-Wno-error=invalid-constexpr",
        "-fno-sanitize=undefined",
        "-Wno-error",
        "-DUSE_ZJIT=0", "-DUSE_JIT=0",
    };

    const darwin_flags = base_flags ++ &[_][]const u8{
        "-DRUBY_EXPORT", "-D_XOPEN_SOURCE", "-D_DARWIN_C_SOURCE", "-D_DARWIN_UNLIMITED_SELECT", "-isysroot", sdk_path, "-DHAVE_WORKING_FORK=1", "-DHAVE_FORK=1",
        "-DHAVE_LONG_LONG=1", "-DSIZEOF_LONG=8", "-DSIZEOF_VOIDP=8", "-DSIZEOF_VOID_P=8", "-DSIZEOF_SIZE_T=8",
        "-Wno-error=#warnings",
    };

    const linux_flags = base_flags ++ &[_][]const u8{
        "-DRUBY_EXPORT", "-D_XOPEN_SOURCE", "-D_GNU_SOURCE", "-DHAVE_WORKING_FORK=1", "-DHAVE_FORK=1",
        "-DHAVE_LONG_LONG=1", "-DSIZEOF_LONG=8", "-DSIZEOF_VOIDP=8", "-DSIZEOF_VOID_P=8", "-DSIZEOF_SIZE_T=8",
    };

    const windows_flags = base_flags ++ &[_][]const u8{
        "-DRUBY_EXPORT",
        "-DWIN32_LEAN_AND_MEAN", "-D_NO_OLDNAMES", "-D_CRT_DECLARE_NONSTDC_NAMES=0",
        "-DHAVE_LONG_LONG=1", "-DSIZEOF_LONG=4", "-DSIZEOF_VOIDP=8", "-DSIZEOF_VOID_P=8", "-DSIZEOF_SIZE_T=8",
        "-Wno-pointer-sign", "-Wno-error=pointer-sign", "-Wno-inconsistent-dllimport",
    };

    const common_flags = if (is_darwin) darwin_flags else if (is_windows) windows_flags else linux_flags;

    exe.root_module.addCSourceFiles(.{
        .root = ruby_src,
        .files = common_sources,
        .flags = common_flags,
    });

    // Missing/Enc sources from dependency
    exe.root_module.addCSourceFile(.{ .file = ruby_src.path(b, "missing/crypt.c"), .flags = common_flags });
    exe.root_module.addCSourceFile(.{ .file = ruby_src.path(b, "missing/explicit_bzero.c"), .flags = common_flags });
    exe.root_module.addCSourceFile(.{ .file = ruby_src.path(b, "missing/setproctitle.c"), .flags = common_flags });
    exe.root_module.addCSourceFile(.{ .file = ruby_src.path(b, "enc/ascii.c"), .flags = common_flags });
    exe.root_module.addCSourceFile(.{ .file = ruby_src.path(b, "enc/us_ascii.c"), .flags = common_flags });
    exe.root_module.addCSourceFile(.{ .file = ruby_src.path(b, "enc/utf_8.c"), .flags = common_flags });
    exe.root_module.addCSourceFile(.{ .file = ruby_src.path(b, "enc/unicode.c"), .flags = common_flags });
    exe.root_module.addCSourceFile(.{ .file = ruby_src.path(b, "enc/trans/newline.c"), .flags = common_flags });

    // Local shims
    exe.root_module.addCSourceFile(.{ .file = b.path("shims/dmy_symbols.c"), .flags = common_flags });

    const prism_sources = &[_][]const u8{
        "prism/api_node.c", "prism/api_pack.c", "prism/diagnostic.c", "prism/encoding.c", "prism/extension.c", "prism/node.c", "prism/options.c", "prism/pack.c", "prism/prettyprint.c", "prism/regexp.c", "prism/serialize.c", "prism/static_literals.c", "prism/token_type.c", "prism/util/pm_buffer.c", "prism/util/pm_char.c", "prism/util/pm_constant_pool.c", "prism/util/pm_integer.c", "prism/util/pm_list.c", "prism/util/pm_memchr.c", "prism/util/pm_newline_list.c", "prism/util/pm_string.c", "prism/util/pm_strncasecmp.c", "prism/util/pm_strpbrk.c", "prism/prism.c", "prism_init.c",
    };

    exe.root_module.addCSourceFiles(.{
        .root = ruby_src,
        .files = prism_sources,
        .flags = common_flags,
    });

    // Handle coroutine
    if (target.result.cpu.arch == .aarch64) {
         if (is_darwin) {
             exe.root_module.addCSourceFile(.{
                 .file = ruby_src.path(b, "coroutine/arm64/Context.S"),
                 .flags = &[_][]const u8{"-DPREFIXED_SYMBOL(name)=_##name", "-isysroot", sdk_path},
             });
         } else {
             exe.root_module.addCSourceFile(.{
                 .file = ruby_src.path(b, "coroutine/arm64/Context.S"),
                 .flags = &[_][]const u8{"-DPREFIXED_SYMBOL(name)=name"},
             });
         }
    } else if (target.result.cpu.arch == .x86_64) {
         if (is_darwin) {
             exe.root_module.addCSourceFile(.{
                 .file = ruby_src.path(b, "coroutine/amd64/Context.S"),
                 .flags = &[_][]const u8{"-DPREFIXED_SYMBOL(name)=_##name", "-isysroot", sdk_path},
             });
         } else {
             exe.root_module.addCSourceFile(.{
                 .file = ruby_src.path(b, "coroutine/amd64/Context.S"),
                 .flags = &[_][]const u8{"-DPREFIXED_SYMBOL(name)=name"},
             });
         }
    }

    if (is_darwin) {
        exe.root_module.linkFramework("CoreFoundation", .{});
    }

    if (is_windows) {
        const windows_sources = &[_][]const u8{
            "win32/win32.c",
            "win32/file.c",
            "win32/winmain.c",
            "missing/strlcat.c",
            "missing/strlcpy.c",
            "missing/ffs.c",
            "missing/lgamma_r.c",
        };
        exe.root_module.addCSourceFiles(.{
            .root = ruby_src,
            .files = windows_sources,
            .flags = common_flags,
        });
        exe.root_module.linkSystemLibrary("ws2_32", .{});
        exe.root_module.linkSystemLibrary("bcrypt", .{});
        exe.root_module.linkSystemLibrary("advapi32", .{});
        exe.root_module.linkSystemLibrary("iphlpapi", .{});
        exe.root_module.linkSystemLibrary("imagehlp", .{});
        exe.root_module.linkSystemLibrary("shlwapi", .{});
    }

    b.installArtifact(exe);
}
