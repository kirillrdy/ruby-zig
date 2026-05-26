#ifndef RUBY_VERCONF_H
#define RUBY_VERCONF_H

#define RUBY_BASE_NAME			"ruby"
#define RUBY_VERSION_NAME		"ruby-4.0"
#define RUBY_LIB_VERSION_STYLE		3	/* full */

#define RUBY_EXEC_PREFIX		""
#define RUBY_LIB_PREFIX 		"/lib/ruby"

#define RUBY_ARCH_PREFIX_FOR(arch)	"/lib/ruby/" arch
#define RUBY_SITEARCH_PREFIX_FOR(arch)	"/lib/ruby/site_ruby/" arch
#define RUBY_LIB			"/lib/ruby/4.0.0"
#define RUBY_ARCH_LIB_FOR(arch) 	"/lib/ruby/4.0.0/" arch

#define RUBY_SITE_LIB			"/lib/ruby/site_ruby"
#define RUBY_SITE_ARCH_LIB_FOR(arch)	"/lib/ruby/site_ruby/4.0.0/" arch

#define RUBY_VENDOR_LIB 		"/lib/ruby/vendor_ruby"
#define RUBY_VENDOR_ARCH_LIB_FOR(arch)	"/lib/ruby/vendor_ruby/4.0.0/" arch

#endif /* RUBY_VERCONF_H */
