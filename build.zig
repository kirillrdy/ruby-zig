const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const ruby_src = b.dependency("ruby", .{}).path("");
    const macos_sdk = fetchMacosSdk(b);

    const exe = buildRuby(b, target, optimize, ruby_src, macos_sdk);
    b.installArtifact(exe);

    const all_step = b.step("all", "Build Ruby for macOS, Linux, and Windows");
    const all_targets = [_]struct { query: std.Target.Query, install_dir: []const u8 }{
        .{ .query = .{ .cpu_arch = .aarch64, .os_tag = .macos }, .install_dir = "macos" },
        .{ .query = .{ .cpu_arch = .x86_64, .os_tag = .linux, .abi = .gnu }, .install_dir = "linux" },
        .{ .query = .{ .cpu_arch = .x86_64, .os_tag = .windows, .abi = .gnu }, .install_dir = "windows" },
    };
    for (all_targets) |target_spec| {
        const resolved_target = b.resolveTargetQuery(target_spec.query);
        const target_exe = buildRuby(b, resolved_target, optimize, ruby_src, macos_sdk);
        const install_step = b.addInstallArtifact(target_exe, .{
            .dest_dir = .{ .override = .{ .custom = target_spec.install_dir } },
        });
        all_step.dependOn(&install_step.step);
    }
}

// URL mirrors nixpkgs apple-sdk_14
// (pkgs/by-name/ap/apple-sdk/metadata/versions.json, version 14.4).
fn fetchMacosSdk(b: *std.Build) std.Build.LazyPath {
    const sdk_url = "https://swcdn.apple.com/content/downloads/14/48/052-59890-A_I0F5YGAY0Y/p9n40hio7892gou31o1v031ng6fnm9sb3c/CLTools_macOSNMOS_SDK.pkg";

    const curl = b.addSystemCommand(&.{ "curl", "-fsSL", "-o" });
    const pkg_file = curl.addOutputFileArg("sdk.pkg");
    curl.addArg(sdk_url);

    const extract = b.addSystemCommand(&.{ "sh", "-c" });
    extract.addArg(
        \\set -e
        \\pkg="$1"; out="$2"
        \\tmp=$(mktemp -d)
        \\trap 'rm -rf "$tmp"' EXIT
        \\pkgutil --expand-full "$pkg" "$tmp/expanded"
        \\sdk_src=$(find "$tmp/expanded" -type d -name "MacOSX*.sdk" -print -quit)
        \\test -n "$sdk_src" || { echo "MacOSX*.sdk not found in pkg payload" >&2; exit 1; }
        \\cp -R "$sdk_src/." "$out/"
        \\# Apple's SDK ships Ruby.framework; its headers shadow our own ruby/*.h via
        \\# clang's framework lookup. We're building Ruby ourselves, so drop it.
        \\rm -rf "$out/System/Library/Frameworks/Ruby.framework"
    );
    extract.addArg("sh");
    extract.addFileArg(pkg_file);
    return extract.addOutputDirectoryArg("macos-sdk");
}

fn buildRuby(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    ruby_src: std.Build.LazyPath,
    macos_sdk: std.Build.LazyPath,
) *std.Build.Step.Compile {
    const is_darwin = target.result.os.tag == .macos;
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
        exe.root_module.addSystemIncludePath(macos_sdk.path(b, "usr/include"));
        exe.root_module.addFrameworkPath(macos_sdk.path(b, "System/Library/Frameworks"));
        exe.root_module.addLibraryPath(macos_sdk.path(b, "usr/lib"));
    }

    const common_sources = &[_][]const u8{
        "array.c", "ast.c", "bignum.c", "class.c", "compar.c", "compile.c", "complex.c", "cont.c", "debug.c", "debug_counter.c", "dir.c", "dln_find.c", "encoding.c", "enum.c", "enumerator.c", "error.c", "eval.c", "file.c", "gc.c", "hash.c", "inits.c", "imemo.c", "io.c", "io_buffer.c", "iseq.c", "load.c", "marshal.c", "math.c", "memory_view.c", "concurrent_set.c", "box.c", "node.c", "node_dump.c", "numeric.c", "object.c", "pack.c", "parse.c", "parser_st.c", "proc.c", "process.c", "ractor.c", "random.c", "range.c", "rational.c", "re.c", "regcomp.c", "regenc.c", "regerror.c", "regexec.c", "regparse.c", "regsyntax.c", "ruby.c", "ruby_parser.c", "scheduler.c", "shape.c", "signal.c", "sprintf.c", "st.c", "strftime.c", "string.c", "struct.c", "symbol.c", "thread.c", "time.c", "transcode.c", "util.c", "variable.c", "version.c", "vm.c", "vm_backtrace.c", "vm_dump.c", "vm_sync.c", "vm_trace.c", "weakmap.c", "miniinit.c", "dmydln.c", "main.c", "set.c", "pathname.c",
    };

    const base_flags = &[_][]const u8{
        "-D_REENTRANT",                       "-std=gnu11",              "-fcommon",
        "-Wno-implicit-function-declaration", "-Wno-int-conversion",     "-Wno-incompatible-pointer-types",
        "-Wno-error=invalid-constexpr",       "-fno-sanitize=undefined", "-Wno-error",
        "-DUSE_ZJIT=0",                       "-DUSE_JIT=0",
    };

    const darwin_flags = base_flags ++ &[_][]const u8{
        "-DRUBY_EXPORT",        "-D_XOPEN_SOURCE", "-D_DARWIN_C_SOURCE", "-D_DARWIN_UNLIMITED_SELECT",
        "-Wno-error=#warnings",
    };

    const linux_flags = base_flags ++ &[_][]const u8{
        "-DRUBY_EXPORT", "-D_XOPEN_SOURCE", "-D_GNU_SOURCE",
    };

    const windows_flags = base_flags ++ &[_][]const u8{
        "-DRUBY_EXPORT",
        "-DWIN32_LEAN_AND_MEAN",
        "-D_NO_OLDNAMES",
        "-D_CRT_DECLARE_NONSTDC_NAMES=0",
        "-Wno-pointer-sign",
        "-Wno-error=pointer-sign",
        "-Wno-inconsistent-dllimport",
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
    if (!is_darwin) {
        exe.root_module.addCSourceFile(.{ .file = ruby_src.path(b, "missing/strlcpy.c"), .flags = common_flags });
        exe.root_module.addCSourceFile(.{ .file = ruby_src.path(b, "missing/strlcat.c"), .flags = common_flags });
    }
    exe.root_module.addCSourceFile(.{ .file = ruby_src.path(b, "enc/ascii.c"), .flags = common_flags });
    exe.root_module.addCSourceFile(.{ .file = ruby_src.path(b, "enc/us_ascii.c"), .flags = common_flags });
    exe.root_module.addCSourceFile(.{ .file = ruby_src.path(b, "enc/utf_8.c"), .flags = common_flags });
    exe.root_module.addCSourceFile(.{ .file = ruby_src.path(b, "enc/unicode.c"), .flags = common_flags });
    exe.root_module.addCSourceFile(.{ .file = ruby_src.path(b, "enc/trans/newline.c"), .flags = common_flags });

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
                .flags = &[_][]const u8{"-DPREFIXED_SYMBOL(name)=_##name"},
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
                .flags = &[_][]const u8{"-DPREFIXED_SYMBOL(name)=_##name"},
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

    return exe;
}
