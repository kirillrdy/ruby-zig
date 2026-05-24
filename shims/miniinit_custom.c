#include "ruby/ruby.h"
#include "ruby/encoding.h"

/* localeinit.c */
VALUE
rb_locale_charmap(VALUE klass)
{
    /* never used */
    return Qnil;
}

int
rb_locale_charmap_index(void)
{
    return -1;
}

int
Init_enc_set_filesystem_encoding(void)
{
    return rb_enc_to_index(rb_default_external_encoding());
}

void rb_encdb_declare(const char *name);
int rb_encdb_alias(const char *alias, const char *orig);
void
Init_enc(void)
{
    rb_encdb_declare("ASCII-8BIT");
    rb_encdb_declare("US-ASCII");
    rb_encdb_declare("UTF-8");
    rb_encdb_declare("EUC-JP");
    rb_encdb_alias("BINARY", "ASCII-8BIT");
    rb_encdb_alias("ASCII", "US-ASCII");
}

void Init_monitor(void);
void Init_etc(void);
void Init_stringio(void);
void Init_strscan(void);
void Init_fcntl(void);
void Init_date_core(void);
void Init_ripper(void);
void Init_console(void);
void Init_wait(void);
void Init_nonblock(void);

static VALUE
stub_try_activate(VALUE self, VALUE path)
{
    rb_require("rubygems");
    return rb_funcall(self, rb_intern("try_activate"), 1, path);
}

/* miniruby does not support dynamic loading. */
void
Init_ext(void)
{
    Init_monitor();
    Init_etc();
    Init_stringio();
    Init_strscan();
    Init_fcntl();
    Init_date_core();
    Init_ripper();
    Init_console();
    Init_wait();
    Init_nonblock();

    VALUE mGem = rb_define_module("Gem");
    rb_define_singleton_method(mGem, "try_activate", stub_try_activate, 1);

    VALUE loaded = rb_gv_get("$LOADED_FEATURES");
    if (RB_TYPE_P(loaded, T_ARRAY)) {
        rb_ary_push(loaded, rb_str_new_cstr("monitor.so"));
        rb_ary_push(loaded, rb_str_new_cstr("etc.so"));
        rb_ary_push(loaded, rb_str_new_cstr("stringio.so"));
        rb_ary_push(loaded, rb_str_new_cstr("strscan.so"));
        rb_ary_push(loaded, rb_str_new_cstr("fcntl.so"));
        rb_ary_push(loaded, rb_str_new_cstr("date_core.so"));
        rb_ary_push(loaded, rb_str_new_cstr("ripper.so"));
        rb_ary_push(loaded, rb_str_new_cstr("io/console.so"));
        rb_ary_push(loaded, rb_str_new_cstr("io/wait.so"));
        rb_ary_push(loaded, rb_str_new_cstr("io/nonblock.so"));
    }
}

static void builtin_loaded(const char *feature_name, VALUE iseq);
#define BUILTIN_LOADED(feature_name, iseq) builtin_loaded(feature_name, (VALUE)(iseq))

#include "mini_builtin.c"

static struct st_table *loaded_builtin_table;

static void
builtin_loaded(const char *feature_name, VALUE iseq)
{
    st_insert(loaded_builtin_table, (st_data_t)feature_name, (st_data_t)iseq);
    rb_vm_register_global_object(iseq);
}

static int
each_builtin_i(st_data_t key, st_data_t val, st_data_t dmy)
{
    const char *feature = (const char *)key;
    const rb_iseq_t *iseq = (const rb_iseq_t *)val;

    rb_yield_values(2, rb_str_new2(feature), rb_iseqw_new(iseq));

    return ST_CONTINUE;
}

/* :nodoc: */
static VALUE
each_builtin(VALUE self)
{
    st_foreach(loaded_builtin_table, each_builtin_i, 0);
    return Qnil;
}

void
Init_builtin(void)
{
    rb_define_singleton_method(rb_cRubyVM, "each_builtin", each_builtin, 0);
    loaded_builtin_table = st_init_strtable();
}

void
Init_builtin_features(void)
{
    // register for ruby
    builtin_iseq_load("gem_prelude", NULL);
}

void
rb_free_loaded_builtin_table(void)
{
    if (loaded_builtin_table)
        st_free_table(loaded_builtin_table);
}

#ifdef HAVE_DLADDR
#undef dladdr
#include <dlfcn.h>
#include <string.h>
#include <stdlib.h>

int custom_dladdr(const void *addr, Dl_info *info) {
    int ret = dladdr(addr, info);
    if (ret && info && info->dli_fname) {
        const char *p = strstr(info->dli_fname, "/.zig-cache/o/");
        if (p) {
            size_t prefix_len = p - info->dli_fname;
            const char *hash_slash = strchr(p + 14, '/');
            if (hash_slash) {
                size_t suffix_len = strlen(hash_slash);
                size_t new_len = prefix_len + 12 + suffix_len + 1; // 12 for "/zig-out/lib"
                char *new_path = malloc(new_len);
                if (new_path) {
                    memcpy(new_path, info->dli_fname, prefix_len);
                    memcpy(new_path + prefix_len, "/zig-out/lib", 12);
                    memcpy(new_path + prefix_len + 12, hash_slash, suffix_len);
                    new_path[new_len - 1] = '\0';
                    info->dli_fname = new_path;
                }
            }
        }
    }
    return ret;
}
#endif
