const std = @import("std");

// Single source of truth for Ruby version identifiers.
// Bumping these here propagates to verconf.h, rbconfig.rb, install paths,
// library name, wrapper scripts, and the pkg-config file.
const ruby_base_name = "ruby";
const ruby_version = "4.0.4"; // full version (RUBY_VERSION, RUBY_SO_NAME suffix)
const ruby_lib_version = "4.0.0"; // RUBY_LIB_VERSION — used for lib/ruby/<ver> paths
const ruby_api_version = "4.0"; // RUBY_API_VERSION major.minor — used in RUBY_VERSION_NAME

const ruby_so_name = ruby_base_name ++ "-" ++ ruby_version; // "ruby-4.0.4"
const ruby_version_name = ruby_base_name ++ "-" ++ ruby_api_version; // "ruby-4.0"
const ruby_header_dir = ruby_base_name ++ "-" ++ ruby_lib_version; // "ruby-4.0.0"
const ruby_lib_subdir = ruby_base_name ++ "/" ++ ruby_lib_version; // "ruby/4.0.0"
const ruby_site_lib_subdir = ruby_base_name ++ "/site_" ++ ruby_base_name ++ "/" ++ ruby_lib_version;
const ruby_vendor_lib_subdir = ruby_base_name ++ "/vendor_" ++ ruby_base_name ++ "/" ++ ruby_lib_version;

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const ruby_src = b.dependency("ruby", .{}).path("");
    const macos_sdk = fetchMacosSdk(b);

    const ruby_build = buildRuby(b, target, optimize, ruby_src, macos_sdk);
    installRuby(b, b.getInstallStep(), ruby_build, null, ruby_src, target);

    const all_step = b.step("all", "Build Ruby for macOS, Linux, and Windows");
    const all_targets = [_]struct { query: std.Target.Query, install_dir: []const u8 }{
        .{ .query = .{ .cpu_arch = .aarch64, .os_tag = .macos }, .install_dir = "macos" },
        .{ .query = .{ .cpu_arch = .x86_64, .os_tag = .linux, .abi = .gnu }, .install_dir = "linux" },
        .{ .query = .{ .cpu_arch = .x86_64, .os_tag = .windows, .abi = .gnu }, .install_dir = "windows" },
    };
    for (all_targets) |target_spec| {
        const resolved_target = b.resolveTargetQuery(target_spec.query);
        const target_build = buildRuby(b, resolved_target, optimize, ruby_src, macos_sdk);
        installRuby(b, all_step, target_build, target_spec.install_dir, ruby_src, resolved_target);
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

const RubyBuild = struct {
    exe: *std.Build.Step.Compile,
    lib: *std.Build.Step.Compile,
    platform: []const u8,
};

fn buildRuby(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    ruby_src: std.Build.LazyPath,
    macos_sdk: std.Build.LazyPath,
) RubyBuild {
    const is_darwin = target.result.os.tag == .macos;
    const is_windows = target.result.os.tag == .windows;

    const ruby_platform = if (is_darwin)
        (if (target.result.cpu.arch == .aarch64) "arm64-darwin" else "x86_64-darwin")
    else if (is_windows)
        "x64-mingw32"
    else
        "x86_64-linux";

    const coroutine_arch = if (target.result.cpu.arch == .aarch64) "arm64" else "amd64";
    const coroutine_h = b.fmt("coroutine/{s}/Context.h", .{coroutine_arch});

    const lib = b.addLibrary(.{
        .name = ruby_so_name,
        .linkage = .dynamic,
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });

    lib.root_module.addCMacro("RUBY_PLATFORM", b.fmt("\"{s}\"", .{ruby_platform}));
    lib.root_module.addCMacro("RUBY_ARCH", b.fmt("\"{s}\"", .{ruby_platform}));
    lib.root_module.addCMacro("COROUTINE_H", b.fmt("\"{s}\"", .{coroutine_h}));
    lib.root_module.addCMacro("LOAD_RELATIVE", "1");

    // Generate verconf.h (consumed by loadpath.c). With LOAD_RELATIVE=1
    // the leading "/" paths are resolved relative to the binary at runtime,
    // so RUBY_EXEC_PREFIX is left empty.
    const verconf_content = b.fmt(
        \\/* Auto-generated by build.zig. Do not edit. */
        \\#define RUBY_BASE_NAME                  "{0s}"
        \\#define RUBY_VERSION_NAME               "{1s}"
        \\#define RUBY_LIB_VERSION_STYLE          3
        \\#define RUBY_EXEC_PREFIX                ""
        \\#define RUBY_LIB_PREFIX                 "/lib/{0s}"
        \\#define RUBY_ARCH_PREFIX_FOR(arch)      "/lib/{2s}/" arch
        \\#define RUBY_SITEARCH_PREFIX_FOR(arch)  "/lib/{3s}/" arch
        \\#define RUBY_LIB                        "/lib/{2s}"
        \\#define RUBY_ARCH_LIB_FOR(arch)         "/lib/{2s}/" arch
        \\#define RUBY_SITE_LIB                   "/lib/{0s}/site_{0s}"
        \\#define RUBY_SITE_ARCH_LIB_FOR(arch)    "/lib/{3s}/" arch
        \\#define RUBY_VENDOR_LIB                 "/lib/{0s}/vendor_{0s}"
        \\#define RUBY_VENDOR_ARCH_LIB_FOR(arch)  "/lib/{4s}/" arch
        \\
    , .{ ruby_base_name, ruby_version_name, ruby_lib_subdir, ruby_site_lib_subdir, ruby_vendor_lib_subdir });

    const verconf_wf = b.addWriteFiles();
    _ = verconf_wf.add("verconf.h", verconf_content);

    lib.root_module.addIncludePath(verconf_wf.getDirectory());
    addBasePaths(b, lib.root_module, ruby_src, macos_sdk, is_darwin);
    lib.root_module.addIncludePath(ruby_src.path(b, "prism"));
    lib.root_module.addIncludePath(ruby_src.path(b, "enc/unicode/17.0.0"));
    lib.root_module.addIncludePath(ruby_src.path(b, "ext/etc"));
    lib.root_module.addIncludePath(ruby_src.path(b, "ext/date"));
    lib.root_module.addIncludePath(ruby_src.path(b, "ext/ripper"));
    lib.root_module.addIncludePath(ruby_src.path(b, "ext/io/console"));

    const common_sources = &[_][]const u8{
        // Core
        "array.c",         "ast.c",                    "bignum.c",               "class.c",     "compar.c",       "compile.c",   "complex.c",     "cont.c",              "debug.c",               "debug_counter.c", "dir.c",                   "dln_find.c",            "encoding.c",        "enum.c",               "enumerator.c",          "error.c",                  "eval.c",                   "file.c",                   "gc.c",               "hash.c",                     "inits.c",          "imemo.c",          "io.c",               "io_buffer.c",      "iseq.c",            "load.c",       "marshal.c",       "math.c",       "memory_view.c",       "concurrent_set.c", "box.c",             "node.c",                  "node_dump.c",        "numeric.c",              "object.c",             "pack.c",                        "parse.c",                 "parser_st.c",          "proc.c",                 "process.c",                    "ractor.c",               "random.c",                    "range.c",                 "rational.c",    "re.c",         "regcomp.c", "regenc.c", "regerror.c", "regexec.c", "regparse.c", "regsyntax.c", "ruby.c", "ruby_parser.c", "scheduler.c", "shape.c", "signal.c", "sprintf.c", "st.c", "strftime.c", "string.c", "struct.c", "symbol.c", "thread.c", "time.c", "transcode.c", "util.c", "variable.c", "version.c", "vm.c", "vm_backtrace.c", "vm_dump.c", "vm_sync.c", "vm_trace.c", "weakmap.c", "loadpath.c", "dmydln.c", "set.c", "pathname.c",
        // Missing/Enc
        "missing/crypt.c", "missing/explicit_bzero.c", "missing/setproctitle.c", "enc/ascii.c", "enc/us_ascii.c", "enc/utf_8.c", "enc/unicode.c", "enc/trans/newline.c",
        // Core extensions
        "ext/monitor/monitor.c", "ext/etc/etc.c",   "ext/stringio/stringio.c", "ext/strscan/strscan.c", "ext/fcntl/fcntl.c", "ext/date/date_core.c", "ext/date/date_parse.c", "ext/date/date_strftime.c", "ext/date/date_strptime.c", "ext/io/console/console.c", "ext/io/wait/wait.c", "ext/io/nonblock/nonblock.c",
        // Prism
        "prism/api_node.c", "prism/api_pack.c", "prism/diagnostic.c", "prism/encoding.c", "prism/extension.c", "prism/node.c", "prism/options.c", "prism/pack.c", "prism/prettyprint.c", "prism/regexp.c",   "prism/serialize.c", "prism/static_literals.c", "prism/token_type.c", "prism/util/pm_buffer.c", "prism/util/pm_char.c", "prism/util/pm_constant_pool.c", "prism/util/pm_integer.c", "prism/util/pm_list.c", "prism/util/pm_memchr.c", "prism/util/pm_newline_list.c", "prism/util/pm_string.c", "prism/util/pm_strncasecmp.c", "prism/util/pm_strpbrk.c", "prism/prism.c", "prism_init.c",
    };

    const base_flags = &[_][]const u8{
        "-D_REENTRANT",                       "-std=gnu11",              "-fcommon",
        "-Wno-implicit-function-declaration", "-Wno-int-conversion",     "-Wno-incompatible-pointer-types",
        "-Wno-error=invalid-constexpr",       "-fno-sanitize=undefined", "-Wno-error",
        "-Wno-deprecated-declarations",       "-DUSE_ZJIT=0",            "-DUSE_JIT=0",
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

    lib.root_module.addCSourceFiles(.{
        .root = ruby_src,
        .files = common_sources,
        .flags = common_flags,
    });

    lib.root_module.addCSourceFile(.{
        .file = b.path("shims/miniinit_custom.c"),
        .flags = common_flags,
    });

    if (!is_darwin) {
        lib.root_module.addCSourceFiles(.{
            .root = ruby_src,
            .files = &.{ "missing/strlcpy.c", "missing/strlcat.c" },
            .flags = common_flags,
        });
    }

    const ripper_flags = std.mem.concat(b.allocator, []const u8, &.{
        common_flags, &.{"-DRIPPER"},
    }) catch unreachable;

    lib.root_module.addCSourceFiles(.{
        .root = ruby_src,
        .files = &.{ "ext/ripper/ripper.c", "ext/ripper/ripper_init.c", "ext/ripper/eventids1.c", "ext/ripper/eventids2.c" },
        .flags = ripper_flags,
    });

    // Darwin's assembler mangles C symbols with a leading underscore.
    lib.root_module.addCSourceFile(.{
        .file = ruby_src.path(b, b.fmt("coroutine/{s}/Context.S", .{coroutine_arch})),
        .flags = if (is_darwin)
            &[_][]const u8{"-DPREFIXED_SYMBOL(name)=_##name"}
        else
            &[_][]const u8{"-DPREFIXED_SYMBOL(name)=name"},
    });

    if (is_darwin) {
        lib.root_module.linkFramework("CoreFoundation", .{});
    }

    if (is_windows) {
        const windows_sources = &[_][]const u8{
            "win32/win32.c",
            "win32/file.c",
            "missing/ffs.c",
            "missing/lgamma_r.c",
        };
        lib.root_module.addCSourceFiles(.{
            .root = ruby_src,
            .files = windows_sources,
            .flags = common_flags,
        });
        lib.root_module.linkSystemLibrary("ws2_32", .{});
        lib.root_module.linkSystemLibrary("bcrypt", .{});
        lib.root_module.linkSystemLibrary("advapi32", .{});
        lib.root_module.linkSystemLibrary("iphlpapi", .{});
        lib.root_module.linkSystemLibrary("imagehlp", .{});
        lib.root_module.linkSystemLibrary("shlwapi", .{});
    }

    const exe = b.addExecutable(.{
        .name = "ruby",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });

    exe.root_module.addCSourceFile(.{
        .file = ruby_src.path(b, "main.c"),
        .flags = common_flags,
    });

    exe.root_module.addCMacro("LOAD_RELATIVE", "1");

    if (is_windows) {
        exe.root_module.addCSourceFile(.{
            .file = ruby_src.path(b, "win32/winmain.c"),
            .flags = common_flags,
        });
    }

    addBasePaths(b, exe.root_module, ruby_src, macos_sdk, is_darwin);

    exe.root_module.linkLibrary(lib);

    if (is_darwin) {
        exe.root_module.addRPathSpecial("@loader_path/../lib");
    } else if (!is_windows) {
        exe.root_module.addRPathSpecial("$ORIGIN/../lib");
    }

    return .{ .exe = exe, .lib = lib, .platform = ruby_platform };
}

// Include and SDK search paths shared by the library and executable modules.
fn addBasePaths(
    b: *std.Build,
    module: *std.Build.Module,
    ruby_src: std.Build.LazyPath,
    macos_sdk: std.Build.LazyPath,
    is_darwin: bool,
) void {
    module.addIncludePath(b.path("my_config"));
    module.addIncludePath(b.path("my_config/ruby"));
    module.addIncludePath(ruby_src.path(b, "include"));
    module.addIncludePath(ruby_src.path(b, "."));
    module.addIncludePath(b.path("shims"));

    if (is_darwin) {
        module.addSystemIncludePath(macos_sdk.path(b, "usr/include"));
        module.addFrameworkPath(macos_sdk.path(b, "System/Library/Frameworks"));
        module.addLibraryPath(macos_sdk.path(b, "usr/lib"));
    }
}

// Maps an install subpath into target_subdir when cross-installing (the "all"
// step), otherwise into `default` (or `subpath` itself when default is null).
fn installDir(
    b: *std.Build,
    target_subdir: ?[]const u8,
    subpath: []const u8,
    default: ?std.Build.InstallDir,
) std.Build.InstallDir {
    if (target_subdir) |sub| return .{ .custom = b.fmt("{s}/{s}", .{ sub, subpath }) };
    return default orelse .{ .custom = subpath };
}

fn installRuby(
    b: *std.Build,
    step: *std.Build.Step,
    ruby: RubyBuild,
    target_subdir: ?[]const u8,
    ruby_src: std.Build.LazyPath,
    target: std.Build.ResolvedTarget,
) void {
    const is_darwin = target.result.os.tag == .macos;
    const is_windows = target.result.os.tag == .windows;
    const ruby_platform = ruby.platform;

    const bin_dir = installDir(b, target_subdir, "bin", .bin);
    const lib_dir = installDir(b, target_subdir, "lib", .lib);
    const include_dir = installDir(b, target_subdir, "include", .header);

    // Install executable
    const install_exe = b.addInstallArtifact(ruby.exe, .{
        .dest_dir = .{ .override = bin_dir },
    });
    step.dependOn(&install_exe.step);

    // Install shared library
    const install_lib = b.addInstallArtifact(ruby.lib, .{
        .dest_dir = .{ .override = lib_dir },
    });
    step.dependOn(&install_lib.step);

    // Create shared library symlink (not needed on Windows)
    if (!is_windows) {
        const ext = if (is_darwin) "dylib" else "so";
        const lib_symlink_name = b.fmt("lib{s}.{s}", .{ ruby_base_name, ext });
        const lib_shared_name = b.fmt("lib{s}.{s}", .{ ruby_so_name, ext });
        const symlink = b.addSystemCommand(&.{ "ln", "-sf", lib_shared_name, b.getInstallPath(lib_dir, lib_symlink_name) });
        symlink.step.dependOn(&install_lib.step);
        step.dependOn(&symlink.step);
    }

    // Install headers from dependency's include/ to include/ruby-4.0.0
    const install_headers = b.addInstallDirectory(.{
        .source_dir = ruby_src.path(b, "include"),
        .install_dir = include_dir,
        .install_subdir = ruby_header_dir,
    });
    step.dependOn(&install_headers.step);

    // Install configuration header to include/ruby-4.0.0/<ruby_platform>/ruby/config.h
    const config_dest_path = b.fmt("{s}/{s}/ruby/config.h", .{ ruby_header_dir, ruby_platform });
    const install_config = b.addInstallFileWithDir(
        b.path("my_config/ruby/config.h"),
        include_dir,
        config_dest_path,
    );
    step.dependOn(&install_config.step);

    // Install standard library .rb files from dependency's lib/ to lib/ruby/4.0.0
    const install_libs = b.addInstallDirectory(.{
        .source_dir = ruby_src.path(b, "lib"),
        .install_dir = lib_dir,
        .install_subdir = ruby_lib_subdir,
    });
    step.dependOn(&install_libs.step);

    const ext_libs = &[_][]const u8{
        "ext/monitor/lib",
        "ext/strscan/lib",
        "ext/date/lib",
        "ext/digest/lib",
        "ext/json/lib",
        "ext/openssl/lib",
        "ext/psych/lib",
        "ext/ripper/lib",
        "ext/socket/lib",
        "ext/io/console/lib",
    };
    for (ext_libs) |ext_lib| {
        const install_ext_libs = b.addInstallDirectory(.{
            .source_dir = ruby_src.path(b, ext_lib),
            .install_dir = lib_dir,
            .install_subdir = ruby_lib_subdir,
        });
        step.dependOn(&install_ext_libs.step);
    }

    const install_gems_cmd = b.addSystemCommand(&.{ "sh", "-c" });
    install_gems_cmd.addArg(
        \\set -e
        \\gems_dir="$1"; libexec_dir="$2"; bin_src_dir="$3"; target_lib_dir="$4"
        \\target_bin_dir="$target_lib_dir/bin"
        \\mkdir -p "$target_bin_dir"
        \\
        \\# 1. Copy libexec files to target bin
        \\if [ -d "$libexec_dir" ]; then
        \\  chmod -R +w "$target_bin_dir" 2>/dev/null || true
        \\  cp -Rf "$libexec_dir/." "$target_bin_dir/"
        \\fi
        \\
        \\# 2. Copy bin files to target bin
        \\if [ -d "$bin_src_dir" ]; then
        \\  chmod -R +w "$target_bin_dir" 2>/dev/null || true
        \\  cp -Rf "$bin_src_dir/." "$target_bin_dir/"
        \\fi
        \\
        \\# 3. Unpack all .gem files
        \\for gem in "$gems_dir"/*.gem; do
        \\  tmp_dir=$(mktemp -d)
        \\  tar -xOf "$gem" data.tar.gz | tar -xzf - -C "$tmp_dir"
        \\  if [ -d "$tmp_dir/lib" ]; then
        \\    chmod -R +w "$target_lib_dir" 2>/dev/null || true
        \\    cp -Rf "$tmp_dir/lib/." "$target_lib_dir/"
        \\  fi
        \\  if [ -d "$tmp_dir/bin" ]; then
        \\    chmod -R +w "$target_bin_dir" 2>/dev/null || true
        \\    cp -Rf "$tmp_dir/bin/." "$target_bin_dir/"
        \\  elif [ -d "$tmp_dir/exe" ]; then
        \\    chmod -R +w "$target_bin_dir" 2>/dev/null || true
        \\    cp -Rf "$tmp_dir/exe/." "$target_bin_dir/"
        \\  fi
        \\  rm -rf "$tmp_dir"
        \\done
    );
    install_gems_cmd.addArg("sh");
    install_gems_cmd.addFileArg(ruby_src.path(b, "gems"));
    install_gems_cmd.addFileArg(ruby_src.path(b, "libexec"));
    install_gems_cmd.addFileArg(ruby_src.path(b, "bin"));
    install_gems_cmd.addArg(b.getInstallPath(lib_dir, ruby_lib_subdir));
    install_gems_cmd.step.dependOn(&install_libs.step);
    step.dependOn(&install_gems_cmd.step);

    // Generate and install rbconfig.rb
    const dl_ext = if (is_darwin) ".bundle" else if (is_windows) ".dll" else ".so";
    const so_ext = if (is_darwin) "dylib" else if (is_windows) "dll" else "so";
    const exe_ext = if (is_windows) ".exe" else "";
    const path_sep = if (is_windows) ";" else ":";
    const zig_target = b.fmt("{s}-{s}", .{ @tagName(target.result.cpu.arch), @tagName(target.result.os.tag) });

    const rbconfig_template =
        \\# encoding: ascii-8bit
        \\# frozen-string-literal: false
        \\#
        \\# The module storing Ruby interpreter configurations on building.
        \\#
        \\# This file was created by custom build.zig generator.
        \\
        \\module RbConfig
        \\  RUBY_VERSION_NAME = "@RUBY_VERSION_NAME@" unless defined? RUBY_VERSION_NAME
        \\  RUBY_VERSION = "@RUBY_VERSION@" unless defined? RUBY_VERSION
        \\
        \\  # Ruby installed directory.
        \\  TOPDIR = File.dirname(__FILE__).chomp!("/lib/@RUBY_LIB_SUBDIR@/@RUBY_PLATFORM@")
        \\  # DESTDIR on make install.
        \\  DESTDIR = '' unless defined? DESTDIR
        \\
        \\  CONFIG = {}
        \\  CONFIG["DESTDIR"] = DESTDIR
        \\  CONFIG["MAJOR"], CONFIG["MINOR"], CONFIG["TEENY"] = RUBY_VERSION.split(".", 3)
        \\  CONFIG["PATCHLEVEL"] = "0"
        \\  CONFIG["ruby_version"] = "@RUBY_LIB_VERSION@"
        \\  CONFIG["prefix"] = TOPDIR
        \\  CONFIG["exec_prefix"] = "$(prefix)"
        \\  CONFIG["bindir"] = "$(exec_prefix)/bin"
        \\  CONFIG["libdir"] = "$(exec_prefix)/lib"
        \\  CONFIG["includedir"] = "$(exec_prefix)/include"
        \\  CONFIG["datarootdir"] = "$(prefix)/share"
        \\  CONFIG["datadir"] = "$(datarootdir)"
        \\  CONFIG["mandir"] = "$(datarootdir)/man"
        \\  CONFIG["sysconfdir"] = "$(prefix)/etc"
        \\  CONFIG["localstatedir"] = "$(prefix)/var"
        \\  CONFIG["sharedstatedir"] = "$(prefix)/com"
        \\  CONFIG["sbindir"] = "$(exec_prefix)/sbin"
        \\  CONFIG["libexecdir"] = "$(exec_prefix)/libexec"
        \\
        \\  CONFIG["arch"] = "@RUBY_PLATFORM@"
        \\  CONFIG["sitearch"] = "$(arch)"
        \\  CONFIG["ruby_install_name"] = "@RUBY_BASE_NAME@"
        \\  CONFIG["RUBY_INSTALL_NAME"] = "@RUBY_BASE_NAME@"
        \\  CONFIG["RUBY_SO_NAME"] = "@RUBY_SO_NAME@"
        \\  CONFIG["EXEEXT"] = "@EXEEXT@"
        \\  CONFIG["DLEXT"] = "@DLEXT@"
        \\  CONFIG["SOEXT"] = "@SOEXT@"
        \\
        \\  CONFIG["rubyhdrdir"] = "$(includedir)/@RUBY_BASE_NAME@-@RUBY_LIB_VERSION@"
        \\  CONFIG["rubyarchhdrdir"] = "$(rubyhdrdir)/$(arch)"
        \\  CONFIG["sitehdrdir"] = "$(rubyhdrdir)/site_ruby"
        \\  CONFIG["sitearchhdrdir"] = "$(sitehdrdir)/$(arch)"
        \\  CONFIG["vendorhdrdir"] = "$(rubyhdrdir)/vendor_ruby"
        \\  CONFIG["vendorarchhdrdir"] = "$(vendorhdrdir)/$(arch)"
        \\
        \\  CONFIG["rubylibdir"] = "$(libdir)/ruby/$(ruby_version)"
        \\  CONFIG["archdir"] = "$(rubylibdir)/$(arch)"
        \\  CONFIG["sitelibdir"] = "$(libdir)/ruby/site_ruby/$(ruby_version)"
        \\  CONFIG["sitearchdir"] = "$(sitelibdir)/$(sitearch)"
        \\  CONFIG["vendorlibdir"] = "$(libdir)/ruby/vendor_ruby/$(ruby_version)"
        \\  CONFIG["vendorarchdir"] = "$(vendorlibdir)/$(sitearch)"
        \\
        \\  CONFIG["rubyarchdir"] = "$(archdir)"
        \\  CONFIG["rubylibprefix"] = "$(libdir)/ruby"
        \\
        \\  CONFIG["PATH_SEPARATOR"] = "@PATH_SEPARATOR@"
        \\  CONFIG["SHELL"] = "/bin/sh"
        \\  CONFIG["CC"] = "zig cc -target @ZIG_TARGET@"
        \\  CONFIG["CPP"] = "zig cc -E -target @ZIG_TARGET@"
        \\  CONFIG["LDSHARED"] = "zig cc -shared -target @ZIG_TARGET@"
        \\  CONFIG["LDFLAGS"] = ""
        \\  CONFIG["DLDFLAGS"] = ""
        \\  CONFIG["LIBS"] = ""
        \\
        \\  MAKEFILE_CONFIG = {}
        \\  CONFIG.each{|k,v| MAKEFILE_CONFIG[k] = v.dup}
        \\
        \\  def RbConfig.expand(val, config = CONFIG)
        \\    newval = val.gsub(/\$\$|\$\(([^()]+)\)|\$\{([^{}]+)\}/) {
        \\      var = $&
        \\      if !(v = $1 || $2)
        \\        '$'
        \\      elsif key = config[v = v[/\A[^:]+(?=(?::(.*?)=(.*))?\z)/]]
        \\        pat, sub = $1, $2
        \\        config[v] = false
        \\        config[v] = RbConfig::expand(key, config)
        \\        key = key.gsub(/#{Regexp.quote(pat)}/n) {sub} if pat
        \\        key
        \\      else
        \\        var
        \\      end
        \\    }
        \\    val.replace(newval) unless newval == val
        \\    val
        \\  end
        \\
        \\  CONFIG.each_value do |val|
        \\    RbConfig::expand(val)
        \\  end
        \\
        \\  def RbConfig.ruby
        \\    File.join(
        \\      RbConfig::CONFIG["bindir"],
        \\      RbConfig::CONFIG["ruby_install_name"] + RbConfig::CONFIG["EXEEXT"]
        \\    )
        \\  end
        \\end
        \\CROSS_COMPILING = nil unless defined? CROSS_COMPILING
        \\
    ;

    const rbconfig_content = replaceAll(b, rbconfig_template, &.{
        .{ .pat = "@RUBY_PLATFORM@", .val = ruby_platform },
        .{ .pat = "@RUBY_BASE_NAME@", .val = ruby_base_name },
        .{ .pat = "@RUBY_VERSION@", .val = ruby_version },
        .{ .pat = "@RUBY_VERSION_NAME@", .val = ruby_version_name },
        .{ .pat = "@RUBY_LIB_VERSION@", .val = ruby_lib_version },
        .{ .pat = "@RUBY_LIB_SUBDIR@", .val = ruby_lib_subdir },
        .{ .pat = "@RUBY_SO_NAME@", .val = ruby_so_name },
        .{ .pat = "@EXEEXT@", .val = exe_ext },
        .{ .pat = "@DLEXT@", .val = dl_ext },
        .{ .pat = "@SOEXT@", .val = so_ext },
        .{ .pat = "@PATH_SEPARATOR@", .val = path_sep },
        .{ .pat = "@ZIG_TARGET@", .val = zig_target },
    });

    const rbconfig_wf = b.addWriteFiles();
    const rbconfig_file = rbconfig_wf.add("rbconfig.rb", rbconfig_content);
    const rbconfig_dest_path = b.fmt("{s}/{s}/rbconfig.rb", .{ ruby_lib_subdir, ruby_platform });
    const install_rbconfig = b.addInstallFileWithDir(rbconfig_file, lib_dir, rbconfig_dest_path);
    step.dependOn(&install_rbconfig.step);

    // Install setup-hook to nix-support/setup-hook
    const resolved_hook_content = b.fmt(
        \\addGemPath() {{
        \\  addToSearchPath GEM_PATH $1/lib/{0s}/gems/{1s}
        \\}}
        \\addRubyLibPath() {{
        \\  addToSearchPath RUBYLIB $1/lib/{0s}/site_{0s}
        \\  addToSearchPath RUBYLIB $1/lib/{2s}
        \\  addToSearchPath RUBYLIB $1/lib/{2s}/{3s}
        \\}}
        \\
        \\addEnvHooks "" addGemPath
        \\addEnvHooks "" addRubyLibPath
        \\
    , .{ ruby_base_name, ruby_lib_version, ruby_site_lib_subdir, ruby_platform });

    const hook_dir = installDir(b, target_subdir, "nix-support", null);

    const hook_wf = b.addWriteFiles();
    const hook_file = hook_wf.add("setup-hook", resolved_hook_content);
    const install_hook = b.addInstallFileWithDir(hook_file, hook_dir, "setup-hook");
    step.dependOn(&install_hook.step);

    // Create empty directories (.keep)
    const keep_wf = b.addWriteFiles();
    const keep_file = keep_wf.add(".keep", "");

    const keep_subdirs = [_][]const u8{
        b.fmt("lib/{s}/gems/{s}", .{ ruby_base_name, ruby_lib_version }),
        "lib/" ++ ruby_site_lib_subdir,
        "lib/" ++ ruby_vendor_lib_subdir,
    };
    for (keep_subdirs) |subdir| {
        const install_keep = b.addInstallFileWithDir(keep_file, installDir(b, target_subdir, subdir, null), ".keep");
        step.dependOn(&install_keep.step);
    }

    // Install pkgconfig/ruby-4.0.pc
    const pc_content = b.fmt(
        \\ruby_version={0s}
        \\prefix=${{pcfiledir}}/../..
        \\exec_prefix=${{prefix}}
        \\bindir=${{exec_prefix}}/bin
        \\libdir=${{exec_prefix}}/lib
        \\includedir=${{exec_prefix}}/include
        \\arch={1s}
        \\sitearch=${{arch}}
        \\rubyarchhdrdir=${{includedir}}/{2s}-${{ruby_version}}/${{arch}}
        \\rubyhdrdir=${{includedir}}/{2s}-${{ruby_version}}
        \\
        \\Name: Ruby
        \\Description: Object Oriented Script Language
        \\Version: {3s}
        \\URL: https://www.ruby-lang.org
        \\Cflags: -I${{rubyarchhdrdir}} -I${{rubyhdrdir}}
        \\Libs: -L${{libdir}} -l{4s} -lpthread -ldl
        \\
    , .{ ruby_lib_version, ruby_platform, ruby_base_name, ruby_version, ruby_so_name });

    const pc_dir = installDir(b, target_subdir, "lib/pkgconfig", null);

    const pc_wf = b.addWriteFiles();
    const pc_filename = b.fmt("{s}-{s}.pc", .{ ruby_base_name, ruby_api_version });
    const pc_file = pc_wf.add(pc_filename, pc_content);
    const install_pc = b.addInstallFileWithDir(pc_file, pc_dir, pc_filename);
    step.dependOn(&install_pc.step);

    // Install wrapper scripts in bin/. Each loads the same-named script
    // installed under lib/ruby/<ver>/bin by the gem-unpacking step above.
    const ruby_exe_path = b.getInstallPath(bin_dir, ruby_base_name);

    const wrapper_wf = b.addWriteFiles();
    var chmod_cmd: ?*std.Build.Step.Run = null;
    if (!is_windows) {
        chmod_cmd = b.addSystemCommand(&.{ "chmod", "+x" });
        step.dependOn(&chmod_cmd.?.step);
    }

    const wrappers = [_][]const u8{
        "irb", "erb", "ri", "rdoc", "rake", "racc", "rbs", "rdbg", "syntax_suggest", "typeprof", "bundle", "bundler",
    };
    for (wrappers) |name| {
        const content = b.fmt(
            \\#!{0s}
            \\load File.expand_path('../lib/{1s}/bin/{2s}', __dir__)
            \\
        , .{ ruby_exe_path, ruby_lib_subdir, name });
        installBinScript(b, step, wrapper_wf, bin_dir, chmod_cmd, name, content);
    }

    // gem has no script under lib/ruby/<ver>/bin; invoke RubyGems directly.
    const gem_content = b.fmt(
        \\#!{s}
        \\# frozen_string_literal: true
        \\require "rubygems/gem_runner"
        \\Gem::GemRunner.new.run ARGV.clone
        \\
    , .{ruby_exe_path});
    installBinScript(b, step, wrapper_wf, bin_dir, chmod_cmd, "gem", gem_content);
}

fn installBinScript(
    b: *std.Build,
    step: *std.Build.Step,
    wf: *std.Build.Step.WriteFile,
    bin_dir: std.Build.InstallDir,
    chmod_cmd: ?*std.Build.Step.Run,
    name: []const u8,
    content: []const u8,
) void {
    const file = wf.add(name, content);
    const install = b.addInstallFileWithDir(file, bin_dir, name);
    step.dependOn(&install.step);
    if (chmod_cmd) |cc| {
        cc.step.dependOn(&install.step);
        cc.addArg(b.getInstallPath(bin_dir, name));
    }
}

const Replacement = struct { pat: []const u8, val: []const u8 };

fn replaceAll(b: *std.Build, template: []const u8, pairs: []const Replacement) []const u8 {
    var current = template;
    for (pairs) |p| {
        const size = std.mem.replacementSize(u8, current, p.pat, p.val);
        const buf = b.allocator.alloc(u8, size) catch unreachable;
        _ = std.mem.replace(u8, current, p.pat, p.val, buf);
        current = buf;
    }
    return current;
}
